"""Hermes adapter: routes normalized events and commits outbound frames before delivery."""
import asyncio
from datetime import datetime, timezone
import logging
import uuid
from hermes_constants import get_hermes_home
from gateway.config import Platform
from gateway.platforms.base import BasePlatformAdapter, SendResult
from gateway.platforms.event import MessageEvent
from .auth import AuthStore
from .journal import Journal, HejoJournalError
from . import roster
from .server import GateServer, LIMITS

log = logging.getLogger(__name__)
REPLY_STATES = {"asked", "answered", "closed"}


class HejoAdapter(BasePlatformAdapter):
    MAX_MESSAGE_LENGTH = 65536
    supports_code_blocks = True

    def __init__(self, config):
        super().__init__(config, Platform("hejo"))
        self.journal = None
        self.auth = None
        self.server = None
        self._publish_lock = asyncio.Lock()
        self._edit_lock = asyncio.Lock()
        self._pending_edits = {}
        self._edit_tasks = {}
        self._typing_threads = {}
        self._click_handlers = {}

    def employees(self):
        runner = self.gateway_runner
        multiplex = getattr(getattr(runner, "config", None), "multiplex_profiles", True)
        return roster.employees(multiplex is not False)

    async def connect(self, *, is_reconnect=False):
        if getattr(self, "_owner_profile", None) not in {None, "default"}:
            self._set_fatal_error("secondary_disabled", "hejo secondary adapter is disabled", retryable=False)
            return False
        self.journal = Journal(get_hermes_home())
        try:
            self.journal.open()
            self.auth = AuthStore(get_hermes_home())
            self.server = GateServer(self)
            await self.server.start(self.config.extra.get("listen", ["127.0.0.1"]),
                                    self.config.extra.get("port", 47820))
        except (OSError, ValueError, HejoJournalError):
            if self.server:
                await self.server.stop()
            self.journal.close()
            self._set_fatal_error("hejo_start_failed", "hejo listener or journal unavailable", retryable=False)
            return False
        self._wire_plugin_handlers(self.server)
        self._mark_connected()
        return True

    async def disconnect(self):
        for task in tuple(self._edit_tasks.values()):
            task.cancel()
        await asyncio.gather(*self._edit_tasks.values(), return_exceptions=True)
        self._edit_tasks.clear()
        self._pending_edits.clear()
        if self.server:
            await self.server.stop()
        if self.journal:
            self.journal.close()
        self._mark_disconnected()

    async def _record(self, frame, internal=None):
        # Keep journal commit and publication in the same ordered lane.
        async with self._publish_lock:
            try:
                saved = await self.journal.append(dict(frame, v=1), internal)
            except HejoJournalError:
                await self.server.error("journal_write_failed")
                raise
            await self.server.broadcast(saved)
            return saved

    def _buttons(self, metadata, context):
        buttons, mappings = [], {}
        for entry in (metadata or {}).get("hejo_buttons", []):
            if len(buttons) == 5:
                raise ValueError("too_many_buttons")
            label, style = entry["label"], entry["style"]
            if not isinstance(label, str) or not 1 <= len(label) <= 30 or style not in {"primary", "danger", "default"}:
                raise ValueError("invalid_button")
            button_id = str(uuid.uuid4())
            buttons.append({"id": button_id, "label": label, "kind": "reply", "style": style})
            mappings[button_id] = dict(context, button_id=button_id, label=label, kind="reply")
        return buttons, {"buttons": mappings} if mappings else None

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        metadata = metadata or {}
        if len(content.encode()) > LIMITS["text_bytes"]:
            return SendResult(success=False, error="too_large", error_kind="too_long")
        employee = metadata.get("hermes_profile") or chat_id
        thread = metadata.get("thread_id")
        if not thread and reply_to:
            previous = self.journal.message(reply_to)
            thread = previous.get("thread") if previous else None
        thread = thread or str(uuid.uuid4())
        msg_id = str(uuid.uuid4())
        context = dict(msg_id=msg_id, employee=employee, thread=thread, message_text=content)
        try:
            buttons, internal = self._buttons(metadata, context)
            state = metadata.get("hejo_reply_state")
            if state is not None and state not in REPLY_STATES:
                raise ValueError("invalid_reply_state")
            await self._record({"type": "message", "msg_id": msg_id, "employee": employee,
                                "thread": thread, "role": "employee", "text": content, "files": [],
                                "buttons": buttons, "reply_state": state,
                                "ts": datetime.now(timezone.utc).isoformat()}, internal)
            return SendResult(success=True, message_id=msg_id)
        except (HejoJournalError, ValueError) as exc:
            return SendResult(success=False, error=str(exc))

    async def edit_message(self, chat_id, message_id, content, *, finalize=False, metadata=None):
        if len(content.encode()) > LIMITS["text_bytes"]:
            return SendResult(success=False, error="too_large", error_kind="too_long")
        previous = self.journal.message(message_id)
        if not previous or previous.get("employee") != chat_id:
            return SendResult(success=False, error="message_not_found", error_kind="not_found")
        frame = {"type": "edit", "msg_id": message_id, "text": content, "final": finalize}
        internal = None
        if metadata and "hejo_buttons" in metadata:
            try:
                frame["buttons"], internal = self._buttons(metadata, dict(
                    msg_id=message_id, employee=previous["employee"], thread=previous["thread"], message_text=content))
            except ValueError as exc:
                return SendResult(success=False, error=str(exc))
        async with self._edit_lock:
            self._pending_edits[message_id] = (frame, internal)
            if finalize:
                task = self._edit_tasks.pop(message_id, None)
                if task:
                    task.cancel()
                try:
                    await self._flush_edit(message_id)
                except HejoJournalError as exc:
                    return SendResult(success=False, error=str(exc))
            elif message_id not in self._edit_tasks:
                self._edit_tasks[message_id] = asyncio.create_task(self._deferred_edit(message_id))
        return SendResult(success=True, message_id=message_id)

    async def _flush_edit(self, msg_id):
        frame, internal = self._pending_edits.pop(msg_id)
        await self._record(frame, internal)

    async def _deferred_edit(self, msg_id):
        try:
            await asyncio.sleep(0.5)
            async with self._edit_lock:
                await self._flush_edit(msg_id)
        except HejoJournalError:
            log.error("stream_edit_journal_failed")
        finally:
            if self._edit_tasks.get(msg_id) is asyncio.current_task():
                self._edit_tasks.pop(msg_id, None)

    async def set_reply_state(self, msg_id, state):
        if state not in REPLY_STATES:
            raise ValueError("invalid_reply_state")
        if not self.journal.message(msg_id):
            raise ValueError("message_not_found")
        await self._record({"type": "state", "msg_id": msg_id, "reply_state": state})

    def register_click_handler(self, kind, handler):
        if kind != "reply" or not callable(handler):
            raise ValueError("invalid_click_handler")
        self._click_handlers[kind] = handler

    async def click(self, frame, conn):
        message = self.journal.message(frame["msg_id"])
        button = (message or {}).get("_meta", {}).get("buttons", {}).get(frame["button_id"])
        if not button or not any(b["id"] == frame["button_id"] for b in message.get("buttons", [])):
            await self.server.error("button_expired", frame.get("id"), conn)
            return
        click = {key: button[key] for key in
                 ("msg_id", "button_id", "label", "employee", "thread", "message_text")}
        click["message_text"] = message["text"]
        handler = self._click_handlers.get("reply")
        if handler and await handler(click):
            return
        await self.receive({"employee": click["employee"], "thread": click["thread"],
                            "text": click["label"], "client_msg_id": str(uuid.uuid4()),
                            "id": frame.get("id")}, conn,
                           raw={"_hermes_button": {"label": click["label"], "message_id": click["msg_id"],
                                                   "message_text": click["message_text"]}})

    async def receive(self, frame, conn, raw=None):
        employee = frame["employee"]
        if employee not in {e["id"] for e in self.employees()}:
            await self.server.error("unknown_employee", frame.get("id"), conn)
            return
        if frame.get("files"):
            # Attachment transport is added by TASK-03b, never silently drop files.
            await self.server.error("attachments_unavailable", frame.get("id"), conn)
            return
        thread = frame.get("thread") or str(uuid.uuid4())
        # A reconnect after an uncertain acknowledgement must not execute the turn twice.
        for row in self.journal.records:
            if (row.get("role") == "owner" and row.get("client_msg_id") == frame["client_msg_id"]):
                await conn.send(self.journal.public(row))
                return
        source = self.build_source(chat_id=employee, chat_type="dm", user_id="owner", thread_id=thread)
        source.profile = employee
        msg_id = str(uuid.uuid4())
        try:
            await self._record({"type": "message", "msg_id": msg_id, "employee": employee,
                                "thread": thread, "role": "owner", "text": frame["text"],
                                "files": [], "buttons": [], "reply_state": None,
                                "client_msg_id": frame["client_msg_id"],
                                "ts": datetime.now(timezone.utc).isoformat()})
        except HejoJournalError:
            return
        await self.handle_message(MessageEvent(text=frame["text"], source=source, user_id="owner",
                                               message_id=msg_id, raw_message=raw or frame))

    async def send_typing(self, chat_id, metadata=None):
        metadata = metadata or {}
        thread = metadata.get("thread_id")
        if thread:
            self._typing_threads[chat_id] = thread
        else:
            thread = self._typing_threads.get(chat_id)
        if thread:
            await self.server.broadcast({"v": 1, "type": "typing", "employee": metadata.get("hermes_profile") or chat_id,
                                         "thread": thread, "on": True})

    async def stop_typing(self, chat_id):
        thread = self._typing_threads.pop(chat_id, None)
        if thread:
            await self.server.broadcast({"v": 1, "type": "typing", "employee": chat_id, "thread": thread, "on": False})

    async def get_chat_info(self, chat_id):
        employee = next((e for e in self.employees() if e["id"] == chat_id), None)
        return {"name": employee["name"] if employee else chat_id, "type": "dm", "chat_id": chat_id}
