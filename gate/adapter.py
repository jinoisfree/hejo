"""Hermes adapter: routes normalized events and commits outbound frames before delivery."""
import asyncio
from datetime import datetime, timezone
from dataclasses import replace
import logging
import json
import uuid
from hermes_constants import get_hermes_home
from gateway.config import Platform
from gateway.platforms.base import BasePlatformAdapter, SendResult
from gateway.platforms.event import MessageEvent
from .auth import AuthStore
from .hub import HubLink
from .journal import Journal, HejoJournalError
from . import roster
from . import buttons as native_buttons
from .files import FileStore, UnknownFile, RETENTION_SECONDS
from .server import GateServer, LIMITS
from .context import conversation_lines, thinking, with_context

log = logging.getLogger(__name__)
_primary = None
REPLY_STATES = {"asked", "answered", "closed"}


class ThreadDeleted(ValueError):
    def __init__(self):
        super().__init__("thread_deleted_drop")


class HejoAdapter(BasePlatformAdapter):
    MAX_MESSAGE_LENGTH = 65536
    supports_code_blocks = True

    def __init__(self, config):
        super().__init__(config, Platform("hejo"))
        self.journal = None
        self.files = None
        self._file_cleanup_task = None
        self.auth = None
        self.hub = HubLink()  # disabled until connect() reads hub.json
        self._register_task = None
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

    @property
    def forwarder(self):
        return getattr(self, "_owner_profile", None) not in {None, "default"}

    async def _forward(self, method, *args, metadata=None, **kwargs):
        target = _primary
        if target is None or not target.is_connected:
            log.error("hejo_primary_unavailable")
            return SendResult(success=False, error="hejo_primary_unavailable")
        if method == "edit_message":
            if target.journal.message_threads.get(args[0]) in target.journal.deleted_threads:
                log.warning("thread_deleted_drop")
                return SendResult(success=False, error="thread_deleted_drop")
            message = target.journal.message(args[0])
            if not message or message.get("employee") != self._owner_profile:
                return SendResult(success=False, error="message_not_found")
        if metadata is not None or method not in {"stop_typing", "get_chat_info"}:
            kwargs["metadata"] = {**(metadata or {}), "hermes_profile": self._owner_profile}
        return await getattr(target, method)(self._owner_profile, *args, **kwargs)

    async def connect(self, *, is_reconnect=False):
        global _primary
        if self.forwarder:
            self._mark_connected()
            return True
        self.journal = Journal(get_hermes_home())
        try:
            self.journal.open()
            self.files = FileStore(get_hermes_home(), self.journal)
            self.files.cleanup()
            self.auth = AuthStore(get_hermes_home())
            self.server = GateServer(self)
            await self._finish_thread_deletions()
            await self.server.start(self.config.extra.get("listen", ["127.0.0.1"]),
                                    self.config.extra.get("port", 47820))
            self.auth.local_code(self.server.port)
            self.hub = HubLink(get_hermes_home())
            if self.hub.enabled:
                self._register_task = asyncio.ensure_future(self._register())
        except (OSError, ValueError, HejoJournalError):
            if self.server:
                await self.server.stop()
            self.journal.close()
            self._set_fatal_error("hejo_start_failed", "hejo listener or journal unavailable", retryable=False)
            return False
        self._wire_plugin_handlers(self.server)
        self._mark_connected()
        _primary = self
        self._file_cleanup_task = asyncio.create_task(self._cleanup_files())
        return True

    async def _register(self):
        """Tell the hub which port this member's gate serves; retried until the hub answers."""
        delay = 1
        while True:
            try:
                if await self.hub.register(self.server.port):
                    return
            except Exception:
                log.warning("hejo_hub_register_failed")
            await asyncio.sleep(delay)
            delay = min(60, delay * 2)

    async def _cleanup_files(self):
        while True:
            await asyncio.sleep(RETENTION_SECONDS)
            async with self.files.lock:
                self.files.cleanup()

    async def disconnect(self):
        global _primary
        if _primary is self:
            _primary = None
        if self.forwarder:
            self._mark_disconnected()
            return
        if self._register_task:
            self._register_task.cancel()
            await asyncio.gather(self._register_task, return_exceptions=True)
        if self._file_cleanup_task:
            self._file_cleanup_task.cancel()
            await asyncio.gather(self._file_cleanup_task, return_exceptions=True)
        for task in tuple(self._edit_tasks.values()):
            task.cancel()
        await asyncio.gather(*self._edit_tasks.values(), return_exceptions=True)
        self._edit_tasks.clear()
        self._pending_edits.clear()
        self._typing_threads.clear()
        if self.server:
            await self.server.stop()
        if self.journal:
            self.journal.close()
        self._mark_disconnected()

    async def _record(self, frame, internal=None):
        # Keep journal commit and publication in the same ordered lane.
        async with self._publish_lock:
            self._validate_frame(frame)
            key = ((frame.get("room", frame.get("employee")), frame.get("thread"))
                   if frame["type"] == "message" else self.journal.message_threads.get(frame.get("msg_id")))
            if frame["type"] != "delete" and key in self.journal.deleted_threads:
                log.warning("thread_deleted_drop")
                raise ThreadDeleted()
            try:
                saved = await self.journal.append(dict(frame, v=1), internal)
            except HejoJournalError:
                await self.server.error("journal_write_failed")
                raise
            await self.server.broadcast(saved)
            return saved

    def _validate_frame(self, frame):
        candidate = dict(frame, v=1, seq=self.journal.head + 1)
        if len(json.dumps(candidate, ensure_ascii=False, separators=(",", ":")).encode()) > LIMITS["frame_bytes"]:
            raise ValueError("too_large")

    def _checklist(self, metadata):
        value = metadata.get("hejo_checklist")
        if value is None:
            return {}
        if (not isinstance(value, dict) or set(value) != {"items", "selected", "can_skip"}
                or not isinstance(value["items"], list) or not isinstance(value["selected"], list)
                or not all(isinstance(item, str) and item for item in value["items"])
                or not all(isinstance(item, str) for item in value["selected"])
                or not set(value["selected"]).issubset(value["items"])
                or type(value["can_skip"]) is not bool):
            raise ValueError("invalid_checklist")
        return {"checklist": value}

    async def _finish_thread_deletions(self):
        deleted = {row["msg_id"] for row in self.journal.records if row["type"] == "delete"}
        for msg_id, key in tuple(self.journal.message_threads.items()):
            if key in self.journal.deleted_threads and msg_id not in deleted:
                saved = await self.journal.append({"v": 1, "type": "delete", "msg_id": msg_id})
                await self.server.broadcast(saved)
        self.files.cleanup()

    async def thread_delete(self, frame, conn):
        key = (frame["room"], frame["thread"])
        async with self.files.lock, self._publish_lock:
            if key not in self.journal.deleted_threads:
                first = next((row for row in self.journal.records if row["type"] == "message"
                              and self.journal.message_threads.get(row["msg_id"]) == key), None)
                if first is None:
                    await self.server.error("thread_not_found", frame.get("id"), conn)
                    return
                try:
                    saved = await self.journal.append({"v": 1, "type": "delete", "msg_id": first["msg_id"],
                        "scope": "thread", "room": key[0], "thread": key[1],
                        "at": datetime.now(timezone.utc).isoformat()})
                except HejoJournalError:
                    await self.server.error("journal_write_failed", frame.get("id"), conn)
                    return
                await self.server.broadcast(saved)
            else:
                await conn.send(self.journal.public(self.journal.deleted_threads[key]))
            try:
                await self._finish_thread_deletions()
            except (OSError, HejoJournalError):
                # The scope record is already committed; restart retries missing deletions/cleanup.
                log.warning("thread_cleanup_pending")

    async def thread_branch(self, frame, conn):
        room, thread = frame["room"], frame["thread"]
        async with self._publish_lock:
            if self.journal.deleted(room, thread):
                await self.server.error("thread_deleted", frame.get("id"), conn)
                return
            for row in self.journal.records:
                if row.get("_meta", {}).get("branch_client_msg_id") == frame["client_msg_id"]:
                    await conn.send(self.journal.replay(row))
                    return
            posts = [self.journal.message(row["msg_id"]) for row in self.journal.records
                     if row["type"] == "message" and self.journal.message_threads.get(row["msg_id"]) == (room, thread)]
            posts = [row for row in posts if row]
            if not posts:
                await self.server.error("thread_not_found", frame.get("id"), conn)
                return
            title = posts[0]["text"].split("\n", 1)[0][:30]
            names = {entry["id"]: entry["name"] for entry in self.employees()}
            context = conversation_lines(posts, names, limit=50, characters=16000, line_characters=2000)
            try:
                saved = await self.journal.append({"v": 1, "type": "message", "msg_id": str(uuid.uuid4()),
                    "employee": room, "thread": str(uuid.uuid4()), "role": "employee",
                    "text": f"‘{title}’에서 이어지는 스레드", "files": [], "buttons": [], "reply_state": None,
                    "branch_from": {"thread": thread}, "ts": datetime.now(timezone.utc).isoformat()},
                    {"branch_context": context, "branch_client_msg_id": frame["client_msg_id"]})
            except HejoJournalError:
                await self.server.error("journal_write_failed", frame.get("id"), conn)
                return
            await self.server.broadcast(saved)

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
        for entry in (metadata or {}).get("_hejo_native_buttons", []):
            button_id = str(uuid.uuid4())
            buttons.append({"id": button_id, "label": entry["label"],
                            "kind": entry["kind"], "style": entry["style"]})
            mappings[button_id] = {**context, **entry, "button_id": button_id}
        return buttons, {"buttons": mappings} if mappings else None

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        if self.forwarder:
            return await self._forward("send", content, reply_to=reply_to, metadata=metadata)
        metadata = metadata or {}
        if not metadata.get("hejo_buttons"):
            content = native_buttons.plain_labels(content)
        if len(content.encode()) > LIMITS["text_bytes"]:
            return SendResult(success=False, error="too_large", error_kind="too_long")
        employee = metadata.get("hermes_profile") or chat_id
        thread = metadata.get("thread_id")
        if not thread and reply_to:
            previous = self.journal.message(reply_to)
            key = self.journal.message_threads.get(reply_to)
            thread = previous.get("thread") if previous else (key[1] if key else None)
        thread = thread or str(uuid.uuid4())
        msg_id = str(uuid.uuid4())
        context = dict(msg_id=msg_id, employee=employee, thread=thread, message_text=content)
        try:
            buttons, internal = self._buttons(metadata, context)
            if metadata.get("_hejo_file_registration"):
                internal = {**(internal or {}), "files": metadata["_hejo_file_registration"]}
            state = metadata.get("hejo_reply_state")
            if state is not None and state not in REPLY_STATES:
                raise ValueError("invalid_reply_state")
            await self._record({"type": "message", "msg_id": msg_id, "employee": employee,
                                "thread": thread, "role": "employee", "text": content, "files": metadata.get("_hejo_files", []),
                                "buttons": buttons, "reply_state": state,
                                "ts": datetime.now(timezone.utc).isoformat(), **self._checklist(metadata)}, internal)
            return SendResult(success=True, message_id=msg_id)
        except (HejoJournalError, ValueError) as exc:
            return SendResult(success=False, error=str(exc))

    async def edit_message(self, chat_id, message_id, content, *, finalize=False, metadata=None):
        if self.forwarder:
            return await self._forward("edit_message", message_id, content, finalize=finalize, metadata=metadata)
        if not (metadata or {}).get("hejo_buttons"):
            content = native_buttons.plain_labels(content)
        if len(content.encode()) > LIMITS["text_bytes"]:
            return SendResult(success=False, error="too_large", error_kind="too_long")
        previous = self.journal.message(message_id)
        if self.journal.message_threads.get(message_id) in self.journal.deleted_threads:
            log.warning("thread_deleted_drop")
            return SendResult(success=False, error="thread_deleted_drop")
        if not previous or previous.get("employee") != chat_id:
            return SendResult(success=False, error="message_not_found", error_kind="not_found")
        frame = {"type": "edit", "msg_id": message_id, "text": content, "final": finalize}
        try:
            frame.update(self._checklist(metadata or {}))
            self._validate_frame(frame)
        except ValueError as exc:
            return SendResult(success=False, error=str(exc))
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
                except (HejoJournalError, ValueError) as exc:
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
        except ThreadDeleted:
            pass
        except ValueError:
            log.warning("stream_edit_too_large")
            await self.server.error("too_large")
        except HejoJournalError:
            log.error("stream_edit_journal_failed")
        finally:
            if self._edit_tasks.get(msg_id) is asyncio.current_task():
                self._edit_tasks.pop(msg_id, None)

    async def set_reply_state(self, msg_id, state):
        if self.forwarder:
            target = _primary
            if target is None or not target.is_connected:
                log.error("hejo_primary_unavailable")
                return SendResult(success=False, error="hejo_primary_unavailable")
            message = target.journal.message(msg_id)
            if target.journal.message_threads.get(msg_id) in target.journal.deleted_threads:
                log.warning("thread_deleted_drop")
                return
            if not message or message["employee"] != self._owner_profile:
                raise ValueError("message_not_found")
            return await target.set_reply_state(msg_id, state)
        if state not in REPLY_STATES:
            raise ValueError("invalid_reply_state")
        if self.journal.message_threads.get(msg_id) in self.journal.deleted_threads:
            log.warning("thread_deleted_drop")
            return
        if not self.journal.message(msg_id):
            raise ValueError("message_not_found")
        try:
            await self._record({"type": "state", "msg_id": msg_id, "reply_state": state})
        except ThreadDeleted:
            pass

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
        if button["kind"] != "reply":
            if self._is_sender_authorized("owner", "dm", message["employee"], thread_id=message["thread"]) is False:
                await self.server.error("unauthorized", frame.get("id"), conn)
                return
            if not await native_buttons.resolve(button):
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
        thread = frame.get("thread") or str(uuid.uuid4())
        if self.journal.deleted(employee, thread):
            await self.server.error("thread_deleted", frame.get("id"), conn)
            return
        # A reconnect after an uncertain acknowledgement must not execute the turn twice.
        for row in self.journal.records:
            if (row.get("role") == "owner" and row.get("client_msg_id") == frame["client_msg_id"]):
                await conn.send(self.journal.public(row))
                return
        source = self.build_source(chat_id=employee, chat_type="dm", user_id="owner", thread_id=thread)
        source.profile = employee
        msg_id = str(uuid.uuid4())
        async with self.files.lock:
            if self.journal.deleted(employee, thread):
                await self.server.error("thread_deleted", frame.get("id"), conn)
                return
            previous = [row for row in self.journal.records if row["type"] == "message"
                        and row.get("employee") == employee and row.get("thread") == thread]
            context = next((row.get("_meta", {}).get("branch_context", "") for row in previous), "") if not any(row.get("role") == "owner" for row in previous) else ""
            try:
                attachments, moved = self.files.promote(employee, frame.get("files", []))
            except (UnknownFile, OSError):
                await self.server.error("unknown_file", frame.get("id"), conn)
                return
            try:
                registrations = self.files.registration(employee, "owner", attachments)
                await self._record({"type": "message", "msg_id": msg_id, "employee": employee,
                                    "thread": thread, "role": "owner", "text": frame["text"],
                                    "files": attachments, "buttons": [], "reply_state": None,
                                    "client_msg_id": frame["client_msg_id"],
                                    "ts": datetime.now(timezone.utc).isoformat()},
                                   {"files": registrations} if registrations else None)
            except HejoJournalError:
                self.files.rollback(moved)
                return
        await self.handle_message(MessageEvent(text=with_context(context, frame["text"], "이전 스레드 대화"), source=source, user_id="owner",
                                               message_id=msg_id, raw_message=raw or frame,
                                               media_urls=[entry["path"] for entry in registrations],
                                               media_types=[entry["mime"] for entry in registrations]))

    async def send_typing(self, chat_id, metadata=None):
        if self.forwarder:
            return await self._forward("send_typing", metadata=metadata)
        metadata = metadata or {}
        employee = metadata.get("hermes_profile") or chat_id
        thread = metadata.get("thread_id")
        if thread:
            self._typing_threads.setdefault(employee, set()).add(thread)
            threads = [thread]
        else:
            threads = sorted(self._typing_threads.get(employee, set()))
        for thread in threads:
            async with self._publish_lock:
                if self.journal.deleted(employee, thread):
                    log.warning("thread_deleted_drop")
                    continue
                await self.server.broadcast({"v": 1, "type": "typing", "employee": employee,
                                             "thread": thread, "on": True, "ttl_seconds": 6})

    async def stop_typing(self, chat_id):
        if self.forwarder:
            return await self._forward("stop_typing")
        for thread in sorted(self._typing_threads.pop(chat_id, set())):
            async with self._publish_lock:
                if self.journal.deleted(chat_id, thread):
                    log.warning("thread_deleted_drop")
                    continue
                await self.server.broadcast({"v": 1, "type": "typing", "employee": chat_id, "thread": thread, "on": False})

    async def get_chat_info(self, chat_id):
        if self.forwarder:
            return await self._forward("get_chat_info")
        employee = next((e for e in self.employees() if e["id"] == chat_id), None)
        return {"name": employee["name"] if employee else chat_id, "type": "dm", "chat_id": chat_id}

    async def send_document(self, chat_id, file_path, caption=None, file_name=None,
                            reply_to=None, metadata=None, **kwargs):
        if self.forwarder:
            return await self._forward("send_document", file_path, caption=caption, file_name=file_name,
                                       reply_to=reply_to, metadata=metadata, **kwargs)
        employee = (metadata or {}).get("hermes_profile") or chat_id
        thread = (metadata or {}).get("thread_id")
        if not thread and reply_to:
            key = self.journal.message_threads.get(reply_to)
            thread = key[1] if key else None
        if self.journal.deleted(employee, thread):
            log.warning("thread_deleted_drop")
            return SendResult(success=False, error="thread_deleted_drop")
        path = self.validate_media_delivery_path(file_path)
        if path is None:
            return SendResult(success=False, error="invalid_file")
        async with self.files.lock:
            try:
                info = await self.files.copy(employee, path, file_name)
                descriptors, moved = self.files.promote(employee, [info["file_id"]])
                registrations = self.files.registration(employee, "employee", descriptors)
                result = await self.send(chat_id, caption or "", reply_to, {
                    **(metadata or {}), "_hejo_files": descriptors,
                    "_hejo_file_registration": registrations})
                if not result.success:
                    self.files.rollback(moved)
                return result
            except (OSError, ValueError):
                log.error("attachment_send_failed")
                return SendResult(success=False, error="attachment_send_failed")

    async def send_image_file(self, chat_id, image_path, caption=None, reply_to=None, metadata=None, **kwargs):
        if self.forwarder:
            return await self._forward("send_image_file", image_path, caption=caption,
                                       reply_to=reply_to, metadata=metadata, **kwargs)
        return await self.send_document(chat_id, image_path, caption=caption,
                                        reply_to=reply_to, metadata=metadata, **kwargs)

    async def _send_exec_approval_prompt(self, prompt):
        if self.forwarder:
            target = _primary
            if target is None or not target.is_connected:
                log.error("hejo_primary_unavailable")
                return SendResult(success=False, error="hejo_primary_unavailable")
            return await target._send_exec_approval_prompt(replace(prompt, chat_id=self._owner_profile,
                metadata={**(prompt.metadata or {}), "hermes_profile": self._owner_profile}))
        return await self.send(prompt.chat_id, prompt.text, metadata={
            **(prompt.metadata or {}), "_hejo_native_buttons": native_buttons.native_metadata(
                "approval", prompt.session_key, prompt.actions)})

    async def send_clarify(self, chat_id, question, choices, clarify_id, session_key, metadata=None):
        if self.forwarder:
            return await self._forward("send_clarify", question, choices, clarify_id, session_key, metadata=metadata)
        if not choices:
            from tools.clarify_gateway import mark_awaiting_text
            mark_awaiting_text(clarify_id)
            return await self.send(chat_id, question, metadata=metadata)
        native = native_buttons.native_metadata("clarify", session_key,
            [(str(choice), str(choice), "default") for choice in choices], clarify_id=clarify_id)
        native += native_buttons.native_metadata("clarify", session_key, [("Other", "", "default")],
                                           clarify_id=clarify_id, other=True)
        return await self.send(chat_id, question, metadata={**(metadata or {}), "_hejo_native_buttons": native})

    async def send_slash_confirm(self, chat_id, title, message, session_key, confirm_id, metadata=None):
        if self.forwarder:
            return await self._forward("send_slash_confirm", title, message, session_key, confirm_id, metadata=metadata)
        return await self.send(chat_id, title + "\n\n" + message, metadata={**(metadata or {}),
            "_hejo_native_buttons": native_buttons.native_metadata("slash", session_key,
                [("Approve once", "once", "primary"), ("Always", "always", "default"),
                 ("Cancel", "cancel", "danger")], confirm_id=confirm_id)})
