"""Hermes adapter: routes normalized events and commits outbound frames before delivery."""
import asyncio
from datetime import datetime, timedelta, timezone
from weakref import WeakValueDictionary
from dataclasses import replace
from contextlib import asynccontextmanager
from contextvars import ContextVar
import mimetypes
import logging
import json
import uuid
from agent.i18n import t
from hermes_constants import get_hermes_home
from gateway.config import Platform
from gateway.platforms.base import BasePlatformAdapter, SendResult
from gateway.platforms.event import MessageEvent
from .auth import AuthStore
from .hub import HubLink
from .journal import Journal, HejoJournalError
from . import owner, roster, reply_rules
from . import buttons as native_buttons
from .files import FileStore, UnknownFile, RETENTION_SECONDS
from .server import FrameError, GateServer, LIMITS
from .context import conversation_lines, with_context, split_text
from .rooms import RoomCommands, recipients

log = logging.getLogger(__name__)
_primary = None
# The primary is the transport for routed profiles too. Background delivery and
# its scheduled callbacks inherit the admitted event's scope, not the listener's
# default profile. No process-global current employee or second message store.
_delivery_scope = ContextVar("hejo_delivery_scope", default=None)
_reply_task = ContextVar("hejo_reply_task", default=None)
REPLY_STATES = {"asked", "answered", "closed"}


class ThreadDeleted(ValueError):
    def __init__(self):
        super().__init__("thread_deleted_drop")


class RoomDeleted(ValueError):
    def __init__(self):
        super().__init__("room_deleted_drop")


class HejoAdapter(RoomCommands, BasePlatformAdapter):
    MAX_MESSAGE_LENGTH = 65536
    splits_long_messages = True
    supports_code_blocks = True

    def __init__(self, config):
        super().__init__(config, Platform("hejo"))
        self.discord = None
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
        self._question_locks = WeakValueDictionary()
        self._reply_clock = lambda: datetime.now(timezone.utc)
        self._stream_parts = {}

    def employees(self):
        runner = self.gateway_runner
        multiplex = getattr(getattr(runner, "config", None), "multiplex_profiles", True)
        return roster.employees(multiplex is not False)

    def owner_label(self, default):
        return owner.read(self.server.home)["name"] or default

    @property
    def forwarder(self):
        return getattr(self, "_owner_profile", None) not in {None, "default"}

    def register_post_delivery_callback(self, session_key, callback, *, generation=None):
        # Ingress and final delivery belong to the primary even for a multiplexed turn.
        if self.forwarder:
            if _primary is not None:
                _primary.register_post_delivery_callback(session_key, callback, generation=generation)
            return
        return super().register_post_delivery_callback(session_key, callback, generation=generation)

    def pop_post_delivery_callback(self, session_key, *, generation=None):
        if self.forwarder:
            return _primary.pop_post_delivery_callback(session_key, generation=generation) if _primary is not None else None
        return super().pop_post_delivery_callback(session_key, generation=generation)

    async def _forward(self, method, *args, metadata=None, chat_id=None, **kwargs):
        target = _primary
        if target is None or not target.is_connected:
            log.error("hejo_primary_unavailable")
            return SendResult(success=False, error="hejo_primary_unavailable")
        if method in {"owner_message", "employee_message", "latest_employee_message"}:
            return await getattr(target, method)(self._owner_profile, chat_id, *args)
        if method == "edit_message":
            if target.journal.room_id({"type":"edit","msg_id":args[0]}) in target.journal.deleted_rooms:
                log.warning("room_deleted_drop")
                return SendResult(success=False,error="room_deleted_drop")
            if target.journal.message_threads.get(args[0]) in target.journal.deleted_threads:
                log.warning("thread_deleted_drop")
                return SendResult(success=False, error="thread_deleted_drop")
            message = target.journal.message(args[0])
            if not message or message.get("employee") != self._owner_profile:
                return SendResult(success=False, error="message_not_found")
        if metadata is not None or method not in {"stop_typing", "get_chat_info"}:
            kwargs["metadata"] = {**(metadata or {}), "hermes_profile": self._owner_profile}
        return await getattr(target, method)(chat_id if chat_id and chat_id.startswith("room:") else self._owner_profile, *args, **kwargs)

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
            from .discord import Discord
            self.discord = Discord(self, get_hermes_home())
            self.server = GateServer(self)
            await self._finish_thread_deletions()
            self.cleanup_rooms()
            await self.server.start(self.config.extra.get("listen", ["127.0.0.1"]),
                                    self.config.extra.get("port", 47820))
            self.auth.local_code(self.server.port)
            self.hub = HubLink(get_hermes_home())
            if self.hub.enabled:
                self._register_task = asyncio.ensure_future(self._register())
        except (OSError, ValueError, HejoJournalError):
            if self.discord:
                await self.discord.close()
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
        if self.discord:
            await self.discord.close()
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
        self._stream_parts.clear()
        if self.server:
            await self.server.stop()
        if self.journal:
            self.journal.close()
        self._mark_disconnected()

    async def _record(self, frame, internal=None):
        # Keep journal commit and publication in the same ordered lane.
        async with self._publish_lock:
            key = ((frame.get("room", frame.get("employee")), frame.get("thread"))
                   if frame["type"] == "message" else self.journal.message_threads.get(frame.get("msg_id")))
            if key and key[0] in self.journal.deleted_rooms:
                log.warning("room_deleted_drop")
                raise RoomDeleted()
            if frame["type"] != "delete" and key in self.journal.deleted_threads:
                log.warning("thread_deleted_drop")
                raise ThreadDeleted()
            self._validate_frame(frame)
            try:
                saved = await self.journal.append(dict(frame, v=1), internal)
            except HejoJournalError:
                # A click/retract request reports this failure once, with its request id.
                # Background writes still broadcast the journal fault.
                if _reply_task.get() is not asyncio.current_task():
                    await self.server.error("journal_write_failed")
                raise
            await self.server.broadcast(saved)
        if self.discord:
            self.discord.recorded(saved)
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
            if key in self.journal.deleted_threads and key[0] not in self.journal.deleted_rooms and msg_id not in deleted:
                saved = await self.journal.append({"v": 1, "type": "delete", "msg_id": msg_id})
                await self.server.broadcast(saved)
                self.discord.recorded(saved)
        self.files.cleanup()

    async def thread_delete(self, frame, conn):
        key = (frame["room"], frame["thread"])
        if key[0] in self.journal.deleted_rooms:
            await self.server.error("room_deleted", frame.get("id"), conn)
            return
        async with self.files.lock, self._publish_lock:
            if key[0] in self.journal.deleted_rooms:
                await self.server.error("room_deleted", frame.get("id"), conn)
                return
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
                self.discord.recorded(saved)
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
            if room in self.journal.deleted_rooms:
                await self.server.error("room_deleted", frame.get("id"), conn)
                return
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
            context = conversation_lines(posts, names, owner=self.owner_label("나"), limit=50, characters=16000, line_characters=2000)
            try:
                saved = await self.journal.append({"v": 1, "type": "message", "msg_id": str(uuid.uuid4()),
                    "employee": self.journal.rooms[room]["lead"] if room in self.journal.rooms else room, **({"room":room} if room in self.journal.rooms else {}), "thread": str(uuid.uuid4()), "role": "employee",
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
        return reply_rules.styled(buttons), {"buttons": mappings} if mappings else None

    def _sending_employee(self, chat_id, metadata):
        return (metadata or {}).get("hermes_profile") or (
            (getattr(self, "_owner_profile", None) or "default") if chat_id.startswith("room:") else chat_id)

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        if self.forwarder:
            return await self._forward("send", content, chat_id=chat_id, reply_to=reply_to, metadata=metadata)
        metadata = metadata or {}
        room = chat_id[5:] if chat_id.startswith("room:") else None
        if room in self.journal.deleted_rooms:
            log.warning("room_deleted_drop")
            return SendResult(success=False, error="room_deleted_drop")
        if room and room not in self.journal.rooms:
            return SendResult(success=False, error="room_not_found")
        if not metadata.get("hejo_buttons"):
            content = native_buttons.plain_labels(content)
        chunks = split_text(content, LIMITS["text_bytes"])
        employee = self._sending_employee(chat_id, metadata)
        if room and employee not in self.journal.rooms[room]['members']:
            return SendResult(success=False, error='room_member_required')
        thread = metadata.get("thread_id")
        if not thread and reply_to:
            previous = self.journal.message(reply_to)
            key = self.journal.message_threads.get(reply_to)
            thread = previous.get("thread") if previous else (key[1] if key else None)
        thread = thread or str(uuid.uuid4())
        if len(chunks) > 1:
            sent = []
            for index, chunk in enumerate(chunks):
                last = index == len(chunks) - 1
                piece = dict(metadata, thread_id=thread)
                if not last:
                    for field in ("hejo_buttons", "_hejo_native_buttons", "hejo_checklist", "hejo_reply_state",
                                  "_hejo_files", "_hejo_file_registration"):
                        piece.pop(field, None)
                result = await self.send(chat_id, chunk, reply_to, piece)
                if not result.success:
                    return result
                sent.append(result.message_id)
            if metadata.get("expect_edits"):
                self._stream_parts[sent[0]] = sent
                return SendResult(success=True, message_id=sent[0])
            return result
        msg_id = str(uuid.uuid4())
        context = dict(msg_id=msg_id, employee=employee, thread=thread, message_text=content, **({"room":room} if room else {}))
        try:
            buttons, internal = self._buttons(metadata, context)
            if metadata.get("_hejo_local"):
                internal = {**(internal or {}), "local": metadata["_hejo_local"]}
            if metadata.get("_hejo_file_registration"):
                internal = {**(internal or {}), "files": metadata["_hejo_file_registration"]}
            state = metadata.get("hejo_reply_state")
            if state is not None and state not in REPLY_STATES:
                raise ValueError("invalid_reply_state")
            await self._record({"type": "message", "msg_id": msg_id, "employee": employee,
                                "thread": thread, "role": "employee", "text": content, "files": metadata.get("_hejo_files", []),
                                "buttons": buttons, "reply_state": state,
                                "ts": datetime.now(timezone.utc).isoformat(), **({"room":room} if room else {}), **self._checklist(metadata)}, internal)
            return SendResult(success=True, message_id=msg_id)
        except (HejoJournalError, ValueError) as exc:
            return SendResult(success=False, error=str(exc))

    async def edit_message(self, chat_id, message_id, content, *, finalize=False, metadata=None):
        if self.forwarder:
            return await self._forward("edit_message", message_id, content, chat_id=chat_id, finalize=finalize, metadata=metadata)
        if self.journal.room_id({"type":"edit", "msg_id":message_id}) in self.journal.deleted_rooms:
            log.warning("room_deleted_drop")
            return SendResult(success=False, error="room_deleted_drop")
        if not (metadata or {}).get("hejo_buttons"):
            content = native_buttons.plain_labels(content)
        previous = self.journal.message(message_id)
        if self.journal.message_threads.get(message_id) in self.journal.deleted_threads:
            log.warning("thread_deleted_drop")
            return SendResult(success=False, error="thread_deleted_drop")
        if not previous or ("room:" + previous["room"] if previous.get("room") else previous.get("employee")) != chat_id:
            return SendResult(success=False, error="message_not_found", error_kind="not_found")
        chunks = split_text(content, LIMITS["text_bytes"])
        if len(chunks) > 1 or message_id in self._stream_parts:
            return await self._edit_split(chat_id, message_id, previous, chunks, finalize, metadata or {})
        frame = {"type": "edit", "msg_id": message_id, "text": content, "final": finalize}
        if previous.get("room"):
            frame["room"] = previous["room"]
        try:
            frame.update(self._checklist(metadata or {}))
            self._validate_frame(frame)
        except ValueError as exc:
            return SendResult(success=False, error=str(exc))
        internal = None
        if metadata and "hejo_buttons" in metadata:
            try:
                frame["buttons"], internal = self._buttons(metadata, dict(
                    msg_id=message_id, employee=previous["employee"], thread=previous["thread"], message_text=content, **({"room":previous["room"]} if previous.get("room") else {})))
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

    async def _edit_split(self, chat_id, message_id, previous, chunks, finalize, metadata):
        async with self._edit_lock:
            task = self._edit_tasks.pop(message_id, None)
            if task:
                task.cancel()
            self._pending_edits.pop(message_id, None)
            parts = self._stream_parts.setdefault(message_id, [message_id])
            last_message = self.journal.message(parts[-1]) or previous
            try:
                for index, chunk in enumerate(chunks):
                    last = index == len(chunks) - 1
                    piece = dict(metadata, thread_id=previous["thread"], hermes_profile=previous["employee"])
                    if not last:
                        for field in ("hejo_buttons", "_hejo_native_buttons", "hejo_checklist", "hejo_reply_state"):
                            piece.pop(field, None)
                    if index >= len(parts):
                        result = await self.send(chat_id, chunk, metadata=piece)
                        if not result.success:
                            return result
                        parts.append(result.message_id)
                    frame = {"type":"edit", "msg_id":parts[index], "text":chunk,
                             "final":finalize or not last, "buttons":[], **self._checklist(piece)}
                    internal = None
                    if last and ("hejo_buttons" in piece or "_hejo_native_buttons" in piece):
                        frame["buttons"], internal = self._buttons(piece, dict(msg_id=parts[index],
                            employee=previous["employee"], thread=previous["thread"], message_text=chunk,
                            **({"room":previous["room"]} if previous.get("room") else {})))
                    elif last:
                        frame["buttons"] = last_message.get("buttons", [])
                        mappings = last_message.get("_meta", {}).get("buttons", {})
                        if mappings:
                            internal = {"buttons":{key:{**value, "msg_id":parts[index], "message_text":chunk}
                                                   for key, value in mappings.items()}}
                    if previous.get("room"):
                        frame["room"] = previous["room"]
                    await self._record(frame, internal)
                for extra in parts[len(chunks):]:
                    await self._record({"type":"delete", "msg_id":extra})
                del parts[len(chunks):]
                return SendResult(success=True, message_id=message_id)
            except (HejoJournalError, ValueError) as exc:
                return SendResult(success=False, error=str(exc))

    async def _flush_edit(self, msg_id):
        frame, internal = self._pending_edits.pop(msg_id)
        await self._record(frame, internal)

    async def delete_message(self, chat_id, message_id):
        owner = getattr(self, "_owner_profile", None) or "default"
        scope = _delivery_scope.get() if not self.forwarder else None
        if scope is not None:
            owner, scoped_chat, scoped_thread = scope
            if chat_id != scoped_chat:
                return False
        target = _primary if self.forwarder else self
        if target is None or not target.is_connected:
            return False
        address = chat_id if chat_id.startswith("room:") else (owner if self.forwarder else chat_id)
        async with target._edit_lock:
            message = target.journal.message(message_id)
            if (not message or message.get("role") != "employee" or message.get("employee") != owner
                    or (scope is not None and message.get("thread") != scoped_thread)
                    or ("room:"+message["room"] if message.get("room") else message["employee"]) != address):
                return False
            task = target._edit_tasks.pop(message_id, None)
            if task:
                task.cancel()
            target._pending_edits.pop(message_id, None)
            try:
                await target._record({"type":"delete", "msg_id":message_id})
                return True
            except (HejoJournalError, ValueError):
                return False

    async def _finish_streams(self, chat_id, employee, thread):
        async with self._edit_lock:
            for msg_id, key in tuple(self.journal.message_threads.items()):
                if key != (chat_id[5:] if chat_id.startswith("room:") else chat_id, thread):
                    continue
                message = self.journal.message(msg_id)
                if not message or message.get("role") != "employee" or message.get("employee") != employee:
                    continue
                pending = self._pending_edits.get(msg_id)
                if pending:
                    frame, internal = pending
                else:
                    frame, internal = {"type":"edit", "msg_id":msg_id, "text":message["text"], "final":message.get("final", True)}, None
                    if message.get("room"):
                        frame["room"] = message["room"]
                if frame["final"]:
                    continue
                task = self._edit_tasks.pop(msg_id, None)
                if task:
                    task.cancel()
                self._pending_edits.pop(msg_id, None)
                await self._record({**frame, "final":True}, internal)

    async def _deferred_edit(self, msg_id):
        try:
            await asyncio.sleep(0.5)
            async with self._edit_lock:
                await self._flush_edit(msg_id)
        except (ThreadDeleted, RoomDeleted):
            pass
        except ValueError:
            log.warning("stream_edit_too_large")
            await self.server.error("too_large")
        except HejoJournalError:
            log.error("stream_edit_journal_failed")
        finally:
            if self._edit_tasks.get(msg_id) is asyncio.current_task():
                self._edit_tasks.pop(msg_id, None)

    async def owner_message(self, profile, chat_id, thread_id, msg_id):
        """Read an owner's original message only within this employee's delivery scope."""
        if self.forwarder:
            result = await self._forward("owner_message", thread_id, msg_id, chat_id=chat_id)
            return result if isinstance(result, dict) else None
        message = self.journal.message(msg_id)
        if not message or message.get("role") != "owner" or message.get("thread") != thread_id:
            return None
        room = message.get("room")
        actual_chat = "room:" + room if room else message.get("employee")
        if not profile or chat_id != actual_chat:
            return None
        if room:
            if (room not in self.journal.rooms or room in self.journal.deleted_rooms
                    or profile not in message.get("_meta", {}).get("recipients", [])):
                return None
        elif message.get("employee") != profile:
            return None
        return {"msg_id": message["msg_id"], "text": message["text"], "chat_id": actual_chat,
                "thread_id": message["thread"], "answer_to": message.get("answer_to"), "ts": message["ts"]}

    async def employee_message(self, profile, chat_id, thread_id, msg_id):
        """Read one live post written by this employee in the specified conversation."""
        if self.forwarder:
            result = await self._forward("employee_message", thread_id, msg_id, chat_id=chat_id)
            return result if isinstance(result, dict) else None
        message = self.journal.message(msg_id)
        if (not profile or not message or message.get("role") != "employee"
                or message.get("employee") != profile or message.get("thread") != thread_id):
            return None
        room = message.get("room")
        actual_chat = "room:" + room if room else message.get("employee")
        if chat_id != actual_chat:
            return None
        if room and (room not in self.journal.rooms or room in self.journal.deleted_rooms):
            return None
        return {"msg_id": message["msg_id"], "text": message["text"], "chat_id": actual_chat,
                "thread_id": message["thread"], "employee": profile, "ts": message["ts"]}

    async def latest_employee_message(self, profile, chat_id, thread_id, before_msg_id):
        """Last live employee post preceding a verified owner event in this scope."""
        if self.forwarder:
            return await self._forward('latest_employee_message', thread_id, before_msg_id, chat_id=chat_id)
        if await self.owner_message(profile, chat_id, thread_id, before_msg_id) is None:
            return None
        boundary = self.journal.message(before_msg_id)['seq']
        for row in reversed(self.journal.records):
            if row['type'] != 'message' or row['seq'] >= boundary:
                continue
            post = await self.employee_message(profile, chat_id, thread_id, row['msg_id'])
            if post and post['text'].strip():
                return post
        return None

    async def first_thread_message(self, chat_id, thread_id, *, metadata=None):
        """Return the first live message this employee wrote, never another speaker's.

        Report integrations use a projected copy, not the journal or transport cache.
        """
        if self.forwarder:
            return await self._forward("first_thread_message", thread_id,
                                       chat_id=chat_id, metadata=metadata)
        employee = (metadata or {}).get("hermes_profile") or chat_id
        room = chat_id[5:] if chat_id.startswith("room:") else None
        if room and (room not in self.journal.rooms or room in self.journal.deleted_rooms):
            return None
        for row in self.journal.records:
            if (row["type"] != "message" or row.get("role") != "employee"
                    or row.get("employee") != employee or row.get("thread") != thread_id
                    or row.get("room") != room):
                continue
            message = self.journal.message(row["msg_id"])
            if message:
                return {"msg_id": message["msg_id"], "text": message["text"]}
        return None

    async def set_reply_state(self, msg_id, state):
        if self.forwarder:
            target = _primary
            if target is None or not target.is_connected:
                log.error("hejo_primary_unavailable")
                return SendResult(success=False, error="hejo_primary_unavailable")
            if target.journal.room_id({"type":"state","msg_id":msg_id}) in target.journal.deleted_rooms:
                log.warning("room_deleted_drop")
                return
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
        if self.journal.room_id({"type":"state","msg_id":msg_id}) in self.journal.deleted_rooms:
            log.warning("room_deleted_drop")
            return
        message = self.journal.message(msg_id)
        if not message:
            raise ValueError("message_not_found")
        try:
            await self._record({"type": "state", "msg_id": msg_id, "reply_state": state, **({"room":message["room"]} if message.get("room") else {})})
        except (ThreadDeleted, RoomDeleted):
            pass

    def register_click_handler(self, kind, handler):
        if kind != "reply" or not callable(handler):
            raise ValueError("invalid_click_handler")
        self._click_handlers[kind] = handler

    def _question_lock(self, identifier):
        return self._question_locks.setdefault(identifier, asyncio.Lock())

    def _question_error(self, question, conn):
        room = question.get("room")
        if room:
            current = self.journal.rooms.get(room)
            if "rooms" not in conn.features or not current or question["employee"] not in current["members"]:
                return "button_expired"
        if question["employee"] not in {employee["id"] for employee in self.employees()}:
            return "button_expired"
        if self._is_sender_authorized("owner", "dm", "room:" + room if room else question["employee"],
                                      thread_id=question["thread"]) is False:
            return "unauthorized"

    @asynccontextmanager
    async def _reply_errors(self, request, conn):
        token = _reply_task.set(asyncio.current_task())
        try:
            yield
        except FrameError as exc:
            await self.server.error(str(exc), request.get("id"), conn)
        except HejoJournalError:
            await self.server.error("journal_write_failed", request.get("id"), conn)
        except (ThreadDeleted, RoomDeleted):
            await self.server.error("button_expired", request.get("id"), conn)
        except Exception as exc:
            log.warning("reply_dispatch_failed type=%s", type(exc).__name__)
            await self.server.error("dispatch_failed", request.get("id"), conn)
        finally:
            _reply_task.reset(token)

    async def click(self, frame, conn):
        identifier = frame["msg_id"]
        async with self._reply_errors(frame, conn), self._question_lock(identifier):
            original = self.journal.message(identifier)
            projected = self.journal.history.resolve(identifier)
            if not original or not projected or "answer" not in projected:
                return await self.server.error("button_expired", frame.get("id"), conn)
            if error := self._question_error(original, conn):
                return await self.server.error(error, frame.get("id"), conn)
            button_id = frame["button_id"]
            button = next((b for b in projected["buttons"] if b["id"] == button_id), None)
            if button_id == "std:comment":
                button = reply_rules.standard()[2]
            if not button:
                return await self.server.error("button_expired", frame.get("id"), conn)
            text = button["label"]
            if button["role"] == "comment":
                text = frame.get("text")
                if not isinstance(text, str) or not text.strip() or len(text) > 4000:
                    return await self.server.error("invalid_text", frame.get("id"), conn)
                text = text.strip()
            elif "text" in frame:
                return await self.server.error("invalid_text", frame.get("id"), conn)
            if projected["answer"] and not button["repeat"]:
                return await self.server.error("button_expired", frame.get("id"), conn)
            now = self._reply_clock()
            until = (now + timedelta(seconds=reply_rules.UNDO_GRACE_SECONDS)).isoformat()
            undo = dict(until=until, button_id=button_id, kind=button["kind"], label=button["label"])
            room = {"room": original["room"]} if original.get("room") else {}
            prior_context = self.room_context(original["room"], original["thread"], original["employee"]) if room else None
            answer = await self._record(dict(type="message", msg_id=str(uuid.uuid4()), employee=original["employee"],
                thread=original["thread"], role="owner", text=text, files=[], buttons=[], reply_state=None,
                client_msg_id=str(uuid.uuid4()), ts=now.isoformat(), answer_to=identifier, undo_until=until, **room),
                {"undo":undo, **({"recipients":[original["employee"]]} if room else {})})
            await self._deliver_answer(original, answer, undo, conn, retry=False, prior_context=prior_context)

    async def _deliver_answer(self, question, answer, undo, conn, *, retry, prior_context=None):
        room = {"room": question["room"]} if question.get("room") else {}
        identifier = question["msg_id"]
        if undo["kind"] == "reply":
            click = dict(msg_id=identifier, button_id=undo["button_id"], label=undo["label"],
                         employee=question["employee"], thread=question["thread"], message_text=question["text"], **room)
            handler = self._click_handlers.get("reply")
            if not handler or not await handler(click):
                metadata = dict(label=undo["label"], message_id=identifier, message_text=question["text"])
                if reply_rules.word(undo["label"]) == "의견":
                    metadata.update(label="의견", comment=True)
                if retry and room:
                    prior_context = self.room_context(question["room"], question["thread"], question["employee"],
                                                      before=answer["seq"])
                delivered = await self._reply_event(question, answer["text"], answer["msg_id"],
                                                    {"_hermes_button": metadata}, conn, prior_context=prior_context)
                if not delivered:
                    raise FrameError("button_expired")
        else:
            mapping = question.get("_meta", {}).get("buttons", {}).get(undo["button_id"])
            if retry and not mapping:
                mapping = next((row["_meta"]["buttons"][undo["button_id"]] for row in reversed(self.journal.records)
                                if row.get("msg_id") == identifier and undo["button_id"] in
                                row.get("_meta", {}).get("buttons", {})), None)
            try:
                resolved = mapping is not None and await native_buttons.resolve(mapping)
            except Exception as exc:
                log.warning("native_reply_failed type=%s", type(exc).__name__)
                if not retry:
                    await self._record(dict(type="delete", msg_id=answer["msg_id"], **room))
                raise FrameError("button_expired") from None
            if not resolved and not retry:
                await self._record(dict(type="delete", msg_id=answer["msg_id"], **room))
            chat = "room:" + question["room"] if room else question["employee"]
            text = question["text"]
            if resolved:
                text += "\n\n" + native_buttons.decision(mapping, self.owner_label("나"))
            if question.get("buttons"):
                result = await self.edit_message(chat, identifier, text, finalize=True, metadata={"hejo_buttons":[]})
                if not result.success:
                    raise FrameError("journal_write_failed")
            if not resolved:
                raise FrameError("button_expired")
        await self._record(dict(type="state", msg_id=answer["msg_id"], **room),
                           {"delivered": self._reply_clock().isoformat()})
        await conn.send(dict(v=1, type="click_ack", msg_id=identifier, button_id=undo["button_id"],
                             answer_id=answer["msg_id"], undo_seconds=reply_rules.UNDO_SECONDS, undo_until=undo["until"]))

    async def _reply_event(self, question, text, event_id, raw, conn, *, prior_context=None):
        frame = dict(employee=question["employee"], thread=question["thread"], targeted=True, text=text)
        if question.get("room"):
            frame["room"] = question["room"]
        return await self.receive(frame, conn, raw=raw, event_id=event_id, prior_context=prior_context)

    async def change_answer(self, frame, conn):
        identifier = frame["answer_id"]
        answer = self.journal.message(identifier)
        if not answer or answer.get("role") != "owner":
            return await self.server.error("retract_expired", frame.get("id"), conn)
        async with self._reply_errors(frame, conn), self._question_lock(answer.get("answer_to") or identifier):
            if not self.journal.message(identifier):
                raise FrameError("retract_expired")
            if error := self._question_error(answer, conn):
                raise FrameError(error)
            if not answer.get("answer_to"):
                raise FrameError("already_sent" if frame["type"] == "redeliver" else "retract_expired")
            question = self.journal.message(answer["answer_to"])
            undo = self.journal.history.undo(identifier)
            if frame["type"] == "redeliver":
                if not undo or undo.get("delivered"):
                    return await self.server.error("already_sent", frame.get("id"), conn)
                if question is None:
                    return await self.server.error("button_expired", frame.get("id"), conn)
                return await self._deliver_answer(question, answer, undo, conn, retry=True)
            if not undo or self._reply_clock() > datetime.fromisoformat(undo["until"]):
                return await self.server.error("retract_expired", frame.get("id"), conn)
            await self._record(dict(type="delete", msg_id=identifier,
                                    **({"room":answer["room"]} if answer.get("room") else {})))
            # The delete commits the cancellation. Report follow-up failures, then acknowledge it.
            async with self._reply_errors(frame, conn):
                if undo["kind"] == "reply" and question and question.get("reply_state") == "answered":
                    records = reversed(self.journal.records)
                    state = next((r for r in records if r.get("msg_id") == question["msg_id"] and "reply_state" in r), {})
                    remaining = self.journal.history.resolve(question["msg_id"]).get("answer")
                    if state.get("seq", 0) > answer["seq"] and not remaining:
                        await self.set_reply_state(question["msg_id"], "asked")
            async with self._reply_errors(frame, conn):
                metadata = dict(message_id=answer["answer_to"], answer_id=identifier, label=undo["label"])
                notified = await self._reply_event(answer, reply_rules.RETRACT_TEXT, str(uuid.uuid4()),
                                                   {"_hermes_retract": metadata}, conn)
                if not notified:
                    raise FrameError("button_expired")
            await conn.send(dict(v=1, type="retract_ack", answer_id=identifier))

    async def receive(self, frame, conn, raw=None, *, event_id=None, prior_context=None):
        room_id = frame.get("room")
        employee = frame["employee"]
        thread = frame.get("thread") or str(uuid.uuid4())
        async with self.files.lock:
            room = self.journal.rooms.get(room_id)
            known = {e["id"] for e in self.employees()}
            scope = room_id or employee
            error = None
            if room_id in self.journal.deleted_rooms:
                error = "room_deleted"
            elif room_id and not room:
                error = "room_not_found"
            elif room and employee not in room['members']:
                error = "room_member_required"
            elif employee not in known:
                error = "unknown_employee"
            elif self.journal.deleted(scope, thread):
                error = "thread_deleted"
            if error:
                if event_id is not None:
                    raise FrameError(error)
                await self.server.error(error, frame.get("id"), conn)
                return
            if event_id is None:
                for row in self.journal.records:
                    if row.get("role") == "owner" and row.get("client_msg_id") == frame["client_msg_id"]:
                        await conn.send(self.server.project(row, conn))
                        return True
            targets = ([employee] if frame.get('targeted') else recipients(frame["text"], room, self.employees(), self.journal, thread)) if room else [employee]
            if not set(targets) <= known:
                await self.server.error("unknown_employee", frame.get("id"), conn)
                return
            if prior_context is not None:
                contexts = {employee: prior_context}
            else:
                contexts = {target:self.room_context(room_id, thread, target) for target in targets} if room else {}
            previous = [row for row in self.journal.records if row["type"] == "message"
                        and row["msg_id"] != event_id and self.journal.message_threads.get(row["msg_id"]) == (scope, thread)]
            branch = next((row.get("_meta", {}).get("branch_context", "") for row in previous), "") if not any(row.get("role") == "owner" for row in previous) else ""
            history = [self.journal.message(row["msg_id"]) for row in previous] if not room and not branch else []
            history = [row for row in history if row]
            msg_id = event_id
            registrations = []
            if event_id is None:
                try:
                    attachments, moved = self.files.promote(employee, frame.get("files", []))
                except (UnknownFile, OSError):
                    await self.server.error("unknown_file", frame.get("id"), conn)
                    return
                try:
                    registrations = self.files.registration(employee, "owner", attachments)
                    internal = {"files":registrations, **({"recipients":targets} if room else {})}
                    msg_id = str(uuid.uuid4())
                    await self._record({"type":"message", "msg_id":msg_id, "employee":employee,
                        "thread":thread, "role":"owner", "text":frame["text"], "files":attachments,
                        "buttons":[], "reply_state":None, "client_msg_id":frame["client_msg_id"],
                        "ts":datetime.now(timezone.utc).isoformat(), **({"room":room_id} if room else {}),
                        **({"answer_to":frame["answer_to"]} if frame.get("answer_to") else {})}, internal)
                except HejoJournalError:
                    self.files.rollback(moved)
                    return
        name = self.owner_label(None)
        source_name = {"user_name": name} if name is not None else {}

        async def deliver(target):
            source = self.build_source(chat_id="room:"+room_id if room else employee, chat_type="dm",
                                       user_id="owner", thread_id=thread, message_id=msg_id, **source_name)
            source.profile = target
            text = with_context(contexts.get(target, ""), frame["text"], "방 대화 — 받기 전 글") if room else frame["text"]
            text = with_context(branch, text, "이전 스레드 대화")
            restored = None
            if event_id is not None:
                context = contexts.get(target) or branch
                if context:
                    heading = "방 대화 — 받기 전 글" if room else "이전 스레드 대화"
                    restored = f"[{heading}]\n{context}"
                text = frame["text"]
            if history:
                store = getattr(self, "_session_store", None)
                entry = store.lookup_by_session_key(self._source_session_key(source)) if store else None
                if entry is None or entry.suspended:
                    names = {item["id"]:item["name"] for item in self.employees()}
                    context = conversation_lines(history, names, owner=name or "나", limit=50, characters=16000, line_characters=2000)
                    if context:
                        restored = "[이전 스레드 대화]\n" + context
            token = _delivery_scope.set((target, source.chat_id, thread))
            try:
                await self.handle_message(MessageEvent(text=text, source=source, user_id="owner", message_id=msg_id,
                    channel_context=restored,
                    raw_message=raw or frame, media_urls=[entry["path"] for entry in registrations],
                    media_types=[entry["mime"] for entry in registrations]))
            finally:
                _delivery_scope.reset(token)
        await asyncio.gather(*(deliver(target) for target in targets))
        return True

    async def send_typing(self, chat_id, metadata=None):
        if self.forwarder:
            return await self._forward("send_typing", metadata=metadata, chat_id=chat_id)
        metadata = metadata or {}
        if chat_id.startswith("room:") and chat_id[5:] in self.journal.deleted_rooms:
            log.warning("room_deleted_drop")
            return
        employee = self._sending_employee(chat_id, metadata)
        thread = metadata.get("thread_id")
        if thread:
            self._typing_threads.setdefault(chat_id, set()).add((employee, thread))
            threads = [thread]
        else:
            threads = [entry[1] for entry in sorted(self._typing_threads.get(chat_id, set()))]
        for thread in threads:
            async with self._publish_lock:
                room = chat_id[5:] if chat_id.startswith("room:") else None
                if room in self.journal.deleted_rooms:
                    log.warning("room_deleted_drop")
                    continue
                if self.journal.deleted(room or employee, thread):
                    log.warning("thread_deleted_drop")
                    continue
                await self.server.broadcast({"v": 1, "type": "typing", "employee": employee,
                                             "thread": thread, "on": True, "ttl_seconds": 6, **({"room":room} if room else {})})
            if self.discord:
                self.discord.send_typing((room or chat_id, thread))

    async def stop_typing(self, chat_id, metadata=None):
        if self.forwarder:
            return await self._forward("stop_typing", chat_id=chat_id, metadata=metadata or {})
        active=self._typing_threads.get(chat_id,set())
        owner=self._sending_employee(chat_id, metadata)
        selected=(metadata or {}).get("thread_id")
        stopping={entry for entry in active if (not chat_id.startswith("room:") or entry[0]==owner)
                  and (selected is None or entry[1]==selected)}
        self._typing_threads[chat_id]=active-stopping
        for employee, thread in sorted(stopping):
            try:
                await self._finish_streams(chat_id, employee, thread)
            except (ThreadDeleted, RoomDeleted):
                continue
            async with self._publish_lock:
                room = chat_id[5:] if chat_id.startswith("room:") else None
                if room in self.journal.deleted_rooms:
                    log.warning("room_deleted_drop")
                    continue
                if self.journal.deleted(room or chat_id, thread):
                    log.warning("thread_deleted_drop")
                    continue
                await self.server.broadcast({"v": 1, "type": "typing", "employee": employee, "thread": thread, "on": False, **({"room":room} if room else {})})
        if self.discord:
            room = chat_id[5:] if chat_id.startswith("room:") else None
            for _, thread in sorted(stopping):
                self.discord.wake((room or chat_id, thread))

    async def get_chat_info(self, chat_id):
        if self.forwarder:
            return await self._forward("get_chat_info", chat_id=chat_id)
        employee = next((e for e in self.employees() if e["id"] == chat_id), None)
        return {"name": employee["name"] if employee else chat_id, "type": "dm", "chat_id": chat_id}

    async def send_document(self, chat_id, file_path, caption=None, file_name=None,
                            reply_to=None, metadata=None, **kwargs):
        if self.forwarder:
            return await self._forward("send_document", file_path, chat_id=chat_id, caption=caption, file_name=file_name,
                                       reply_to=reply_to, metadata=metadata, **kwargs)
        employee = self._sending_employee(chat_id, metadata)
        room = chat_id[5:] if chat_id.startswith("room:") else None
        if room in self.journal.deleted_rooms:
            log.warning("room_deleted_drop")
            return SendResult(success=False, error="room_deleted_drop")
        thread = (metadata or {}).get("thread_id")
        if not thread and reply_to:
            key = self.journal.message_threads.get(reply_to)
            thread = key[1] if key else None
        if self.journal.deleted(room or employee, thread):
            log.warning("thread_deleted_drop")
            return SendResult(success=False, error="thread_deleted_drop")
        path = self.validate_media_delivery_path(file_path)
        if path is None:
            return SendResult(success=False, error="invalid_file")
        try:
            info = await self.files.copy(employee, path, file_name)
        except (OSError, ValueError):
            return SendResult(success=False, error="attachment_send_failed")
        async with self.files.lock:
            if room in self.journal.deleted_rooms:
                log.warning("room_deleted_drop")
                return SendResult(success=False, error="room_deleted_drop")
            try:
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
            return await self._forward("send_image_file", image_path, chat_id=chat_id, caption=caption,
                                       reply_to=reply_to, metadata=metadata, **kwargs)
        return await self.send_document(chat_id, image_path, caption=caption,
                                        reply_to=reply_to, metadata=metadata, **kwargs)

    async def send_image(self, chat_id, image_url, caption=None, reply_to=None, metadata=None):
        if self.forwarder:
            return await self._forward("send_image", image_url, chat_id=chat_id, caption=caption,
                                       reply_to=reply_to, metadata=metadata)
        from tools.url_safety import create_ssrf_safe_async_client, is_safe_url, redirect_target_from_response
        import httpx
        async def guard(response):
            target = redirect_target_from_response(response)
            if target and not is_safe_url(target):
                raise ValueError("unsafe_image")
        try:
            if not is_safe_url(image_url):
                raise ValueError("unsafe_image")
            async with asyncio.timeout(30), create_ssrf_safe_async_client(
                    timeout=30, follow_redirects=True, event_hooks={"response":[guard]}) as client:
                async with client.stream("GET", image_url) as response:
                    response.raise_for_status()
                    mime = response.headers.get("content-type", "").split(";", 1)[0].strip().lower()
                    if not mime.startswith("image/"):
                        raise ValueError("invalid_image")
                    extension = mimetypes.guess_extension(mime)
                    if not extension:
                        raise ValueError("invalid_image")
                    employee = self._sending_employee(chat_id, metadata)
                    info = await self.files.stage(employee, "image"+extension, response.aiter_bytes())
            async with self.files.lock:
                descriptors, moved = self.files.promote(employee, [info["file_id"]])
                registrations = self.files.registration(employee, "employee", descriptors)
                result = await self.send(chat_id, caption or "", reply_to, {
                    **(metadata or {}), "_hejo_files":descriptors, "_hejo_file_registration":registrations})
                if not result.success:
                    self.files.rollback(moved)
                return result
        except (OSError, ValueError, TimeoutError, httpx.HTTPError):
            return await self.send(chat_id, (caption+"\n" if caption else "") + t("platform.shared.media.image_failed"),
                                   reply_to, metadata)

    async def send_voice(self, chat_id, audio_path, caption=None, reply_to=None, metadata=None, **kwargs):
        return await self.send_document(chat_id, audio_path, caption=caption, reply_to=reply_to, metadata=metadata)

    async def send_video(self, chat_id, video_path, caption=None, reply_to=None, metadata=None, **kwargs):
        return await self.send_document(chat_id, video_path, caption=caption, reply_to=reply_to, metadata=metadata, **kwargs)

    async def _send_exec_approval_prompt(self, prompt):
        if self.forwarder:
            target = _primary
            if target is None or not target.is_connected:
                log.error("hejo_primary_unavailable")
                return SendResult(success=False, error="hejo_primary_unavailable")
            return await target._send_exec_approval_prompt(replace(prompt, chat_id=prompt.chat_id if prompt.chat_id.startswith("room:") else self._owner_profile,
                metadata={**(prompt.metadata or {}), "hermes_profile": self._owner_profile}))
        return await self.send(prompt.chat_id, prompt.text, metadata={
            **(prompt.metadata or {}), "_hejo_native_buttons": native_buttons.native_metadata(
                "approval", prompt.session_key, prompt.actions)})

    async def send_clarify(self, chat_id, question, choices, clarify_id, session_key, metadata=None):
        if self.forwarder:
            return await self._forward("send_clarify", question, choices, clarify_id, session_key, chat_id=chat_id, metadata=metadata)
        if not choices:
            from tools.clarify_gateway import mark_awaiting_text
            mark_awaiting_text(clarify_id)
            return await self.send(chat_id, question, metadata=metadata)
        native = native_buttons.native_metadata("clarify", session_key,
            [(str(choice), str(choice), "default") for choice in choices], clarify_id=clarify_id)
        native += native_buttons.native_metadata("clarify", session_key, [(t("platform.slack.clarify.other"), "", "default")],
                                           clarify_id=clarify_id, other=True)
        return await self.send(chat_id, question, metadata={**(metadata or {}), "_hejo_native_buttons": native})

    async def send_slash_confirm(self, chat_id, title, message, session_key, confirm_id, metadata=None):
        if self.forwarder:
            return await self._forward("send_slash_confirm", title, message, session_key, confirm_id, chat_id=chat_id, metadata=metadata)
        return await self.send(chat_id, title + "\n\n" + message, metadata={**(metadata or {}),
            "_hejo_native_buttons": native_buttons.native_metadata("slash", session_key,
                [(t("platform.slack.confirm.approve_once"), "once", "primary"),
                 (t("platform.slack.confirm.always_approve"), "always", "default"),
                 (t("platform.slack.confirm.cancel"), "cancel", "danger")], confirm_id=confirm_id)})
