"""The second door: private pairing, room settings and external message ownership."""
import asyncio
import hmac
import json
import logging
import os
import secrets
import time
from pathlib import Path

from .auth import AuthStore, PAIR_TTL, digest
from .context import thinking

log = logging.getLogger(__name__)
_photon = None
SETTLE_SECONDS = 2.0


def platform_ready():
    return _photon is not None and getattr(_photon, "is_connected", True)


def attach_photon(native, adapter):
    """Platform handler contract; resolve the primary at dispatch time, in either start order."""
    global _photon
    changed = _photon is not adapter
    _photon = adapter
    if changed:
        from .adapter import _primary
        if _primary is not None and _primary.is_connected and _primary.imessage:
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                loop = None
            if loop is not None:
                loop.create_task(_primary.imessage.publish())
    if getattr(adapter, "_hejo_imessage_wrapped", False):
        return
    original = adapter.handle_message

    async def handle(event):
        from .adapter import _primary
        bridge = getattr(_primary, "imessage", None)
        try:
            claimed = bridge is not None and bridge.claims_external(event)
            if claimed and bridge.pending_code(event, bridge.private()):
                claimed = adapter._is_sender_authorized(
                    event.source.user_id, event.source.chat_type, event.source.chat_id) is not False
        except Exception:
            log.warning("imessage_claim_failed")
            claimed = False
        if claimed:
            return await bridge.receive_external(event)
        return await original(event)

    adapter.handle_message = handle
    adapter._hejo_imessage_wrapped = True


class IMessage:
    def __init__(self, adapter, home, clock=time.time):
        self.adapter = adapter
        self.clock = clock
        self.vault = AuthStore(home, clock)
        self.settings_store = AuthStore(home, clock)
        self.settings_store.path = Path(home) / "shared" / "hejo" / "imessage"
        self.settle_seconds = SETTLE_SECONDS
        self.pending, self.changed, self.workers, self.wakes = {}, {}, {}, {}
        self.sent = {}
        self.sent_path = self.settings_store.path / "sent.jsonl"
        self._load_sent()

    def _load_sent(self):
        try:
            raw = self.sent_path.read_bytes()
        except FileNotFoundError:
            return
        lines = raw.splitlines(keepends=True)
        rows = []
        for line in lines:
            try:
                row = json.loads(line) if line.endswith(b"\n") else None
                if not isinstance(row, dict) or set(row) != {"im", "msg_id"} or not all(isinstance(v, str) for v in row.values()):
                    row = None
            except (ValueError, UnicodeDecodeError):
                row = None
            rows.append(row)
        last = max((i for i, row in enumerate(rows) if row is not None), default=-1)
        if any(row is None for row in rows[:last + 1]):
            raise ValueError("imessage_sent_corrupt")
        for row in rows[:last + 1]:
            self.sent[row["im"]] = row["msg_id"]
        with self.sent_path.open("r+b") as stream:
            os.fchmod(stream.fileno(), 0o600)
            stream.truncate(sum(len(line) for line in lines[:last + 1]))
            stream.flush()
            os.fsync(stream.fileno())

    async def close(self):
        tasks = tuple(self.workers.values())
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self.workers.clear()
        self.pending.clear()

    def recorded(self, row):
        if row["type"] not in {"message", "edit", "delete"}:
            return
        key = self.adapter.journal.message_threads.get(row.get("msg_id"))
        if not key:
            return
        if row["type"] == "message" and row["role"] == "employee":
            self.pending.setdefault(key, []).append(row["msg_id"])
        if key not in self.pending:
            return
        self.changed[key] = asyncio.get_running_loop().time()
        self.wake(key)

    def wake(self, key):
        if key not in self.pending:
            return
        if key not in self.workers:
            self.wakes[key] = asyncio.Event()
            self.workers[key] = asyncio.create_task(self._settle(key))
        self.wakes[key].set()

    def typing(self, key):
        chat = "room:" + key[0] if key[0] in self.adapter.journal.rooms else key[0]
        return any(thread == key[1] for _, thread in self.adapter._typing_threads.get(chat, set()))

    async def _settle(self, key):
        try:
            while key in self.pending:
                await self.wakes[key].wait()
                self.wakes[key].clear()
                while key in self.pending:
                    delay = self.changed[key] + self.settle_seconds - asyncio.get_running_loop().time()
                    if delay > 0:
                        await asyncio.sleep(delay)
                        continue
                    if self.typing(key):
                        break
                    msg_id = self.pending[key].pop(0)
                    if not self.pending[key]:
                        del self.pending[key]
                    try:
                        await self._send_message(msg_id, key)
                    except (OSError, ValueError):
                        log.warning("imessage_send_failed")
        finally:
            self.workers.pop(key, None)
            self.wakes.pop(key, None)
            self.changed.pop(key, None)

    def phone_parent(self, key):
        return next((row["client_msg_id"][len("imessage:"):] for row in reversed(self.adapter.journal.records)
                     if row.get("role") == "owner" and row.get("client_msg_id", "").startswith("imessage:")
                     and self.adapter.journal.message_threads.get(row.get("msg_id")) == key), None)

    async def _send_message(self, msg_id, key):
        row = self.adapter.journal.message(msg_id)
        settings, pair = self.settings(), self.private()["pair"]
        parent = self.phone_parent(key)
        if (not row or thinking(row["text"]) or not pair or not settings["enabled"] or _photon is None
                or key[0] not in {r[0] for r in self.rooms()} or not (parent or key[0] in settings["reports"])):
            return
        names = {e["id"]: e["name"] for e in self.adapter.employees()}
        label = names.get(row["employee"], row["employee"])
        group = self.adapter.journal.rooms.get(key[0])
        if group:
            label = group["title"] + " · " + label
        text = f"[{label}] " + row["text"]
        buttons = row.get("buttons", [])
        if buttons:
            if all(b["kind"] == "reply" for b in buttons):
                text += "\n선택: " + " / ".join(b["label"] for b in buttons)
            else:
                text += "\n(이 선택은 hejo 앱에서 눌러 주세요)"
        for file in row.get("files", []):
            text += ("\n" if row["text"] or buttons or not text.endswith("] ") else "") + f"📎 {file['name']} (hejo 앱에서 열기)"
        try:
            for part in split_characters(text, _photon.MAX_MESSAGE_LENGTH):
                result = await _photon.send(pair["chat_id"], part, reply_to=parent)
                if not result.success:
                    raise OSError("imessage_send_failed")
                if result.message_id:
                    self._save_sent(result.message_id, msg_id)
        except Exception:
            # No exception text: transport failures can contain credentials or the message.
            log.warning("imessage_send_failed")

    def _save_sent(self, im_id, msg_id):
        with self.settings_store.locked():
            created = not self.sent_path.exists()
            fd = os.open(self.sent_path, os.O_CREAT | os.O_WRONLY | os.O_APPEND, 0o600)
            try:
                os.fchmod(fd, 0o600)
                with os.fdopen(fd, "ab", closefd=False) as stream:
                    stream.write((json.dumps({"im": im_id, "msg_id": msg_id}) + "\n").encode())
                    stream.flush()
                    os.fsync(fd)
            finally:
                os.close(fd)
            if created:
                directory = os.open(self.settings_store.path, os.O_RDONLY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
        self.sent[im_id] = msg_id

    def private(self):
        return self.vault.read("imessage.json", {"pair": None, "code": None})

    def rooms(self):
        employees = self.adapter.employees()
        groups = sorted((room for room in self.adapter.journal.rooms.values()
                         if not room.get("archived") and room["id"] not in self.adapter.journal.deleted_rooms),
                        key=lambda room: room["title"].casefold())
        return [(e["id"], e["name"], [e["id"], e["name"], *e.get("aliases", [])]) for e in employees] + [
            (r["id"], r["title"], [r["title"]]) for r in groups]

    def settings(self):
        value = self.settings_store.read("settings.json", {"enabled": False, "room": None, "reports": []})
        available = {r[0] for r in self.rooms()}
        return {"enabled": value["enabled"], "room": value["room"] if value["room"] in available else None,
                "reports": [r for r in value["reports"] if r in available]}

    def status(self, ref=None):
        return {"v": 1, "type": "imessage_status", "platform_ready": platform_ready(),
                "paired": self.private()["pair"] is not None, **self.settings(),
                **({"ref": ref} if ref is not None else {})}

    async def publish(self, conn=None, ref=None):
        status = self.status()
        for peer in tuple(self.adapter.server.connections):
            if "imessage" in peer.features:
                await peer.send({**status, **({"ref": ref} if peer is conn and ref is not None else {})})

    async def command(self, frame, conn):
        if "imessage" not in conn.features:
            await self.adapter.server.error("unexpected_frame", frame["id"], conn)
            return
        kind, ref = frame["type"], frame["id"]
        if kind == "imessage":
            await conn.send(self.status(ref))
            return
        if kind == "imessage_pair":
            if not platform_ready():
                await self.adapter.server.error("imessage_unavailable", ref, conn)
                return
            code = secrets.token_urlsafe(9)
            with self.vault.locked():
                value = self.vault.read("imessage.json", {"pair": None, "code": None})
                value["code"] = {"hash": digest(code), "expires": self.clock() + PAIR_TTL, "used": False}
                self.vault.write("imessage.json", value)
            await conn.send({"v": 1, "type": "imessage_code", "ref": ref, "code": code, "expires_in": PAIR_TTL})
            return
        if kind == "imessage_unpair":
            with self.vault.locked():
                self.vault.write("imessage.json", {"pair": None, "code": None})
            settings = self.settings()
            settings["enabled"] = False
        else:
            settings = {key: frame[key] for key in ("enabled", "room", "reports")}
            available = {r[0] for r in self.rooms()}
            if (settings["room"] is not None and settings["room"] not in available
                    or len(set(settings["reports"])) != len(settings["reports"])
                    or not set(settings["reports"]) <= available):
                await self.adapter.server.error("invalid_imessage", ref, conn)
                return
            if settings["enabled"] and not self.private()["pair"]:
                await self.adapter.server.error("imessage_unpaired", ref, conn)
                return
        with self.settings_store.locked():
            self.settings_store.write("settings.json", settings)
        await self.publish(conn, ref)

    def pending_code(self, event, value):
        code = value.get("code")
        return bool(code and not code["used"] and self.clock() < code["expires"]
                    and hmac.compare_digest(code["hash"], digest(event.text.strip())))

    def claims_external(self, event):
        if not self.adapter.is_connected or not platform_ready():
            return False
        source = event.source
        if source is None or source.chat_type != "dm" or getattr(source.platform, "value", source.platform) != "photon":
            return False
        private = self.private()
        if self.pending_code(event, private):
            return True
        pair = private["pair"]
        return bool(pair and self.settings()["enabled"] and pair["platform"] == "photon"
                    and pair["chat_id"] == source.chat_id and pair["user_id"] == source.user_id)

    async def notice(self, chat_id, text):
        try:
            result = await _photon.send(chat_id, text)
            if not result.success:
                log.warning("imessage_notice_failed")
        except Exception:
            log.warning("imessage_notice_failed")

    async def receive_external(self, event):
        # Recheck and consume under the same file lock: a code may only pair once.
        with self.vault.locked():
            private = self.vault.read("imessage.json", {"pair": None, "code": None})
            pairing = self.pending_code(event, private)
            if pairing:
                private["pair"] = {"platform": "photon", "chat_id": event.source.chat_id,
                                   "user_id": event.source.user_id, "paired_at": self.clock()}
                private["code"]["used"] = True
                self.vault.write("imessage.json", private)
        if pairing:
            await self.notice(event.source.chat_id, "연결됐어요")
            await self.publish()
            return
        raw = event.raw_message if isinstance(event.raw_message, dict) else {}
        if (raw.get("content") or {}).get("type") == "reaction":
            return
        text = event.text.strip()
        if text == "/방" or text.startswith("/방 "):
            await self.room_command(event, text[2:].strip())
            return
        if event.media_urls:
            await self.notice(event.source.chat_id, "첨부는 아직 hejo 앱에서만 보낼 수 있어요")
        if not event.text:
            return
        target = self.reply_thread(event.reply_to_message_id)
        room, thread = target if target else (self.settings()["room"], None)
        if room is None:
            await self.notice(event.source.chat_id, "연결된 방이 없어요. /방으로 골라 주세요")
            return
        from .server import LIMITS
        if len(event.text.encode()) > LIMITS["text_bytes"] or not event.message_id:
            await self.notice(event.source.chat_id, "지금은 받지 못했어요")
            return
        group = self.adapter.journal.rooms.get(room)
        frame = {"employee": group["lead"] if group else room, "thread": thread,
                 "text": event.text, "client_msg_id": "imessage:" + event.message_id,
                 **({"room": room} if group else {})}
        reply = ExternalReply(self, event.source.chat_id)
        try:
            received = await self.adapter.receive(frame, reply)
        except ValueError:
            received = False
        if not received and not reply.failed:
            await reply.send({"type": "error"})

    def reply_thread(self, im_id):
        if not im_id:
            return None
        journal = self.adapter.journal
        msg_id = next((row["msg_id"] for row in journal.records if row.get("client_msg_id") == "imessage:" + im_id), None)
        msg_id = msg_id or getattr(self, "sent", {}).get(im_id)
        key = journal.message_threads.get(msg_id)
        if (not key or not journal.message(msg_id) or key in journal.deleted_threads
                or key[0] not in {room[0] for room in self.rooms()}):
            return None
        return key

    async def room_command(self, event, choice):
        rooms = self.rooms()
        selected = []
        if choice.isdecimal():
            number = int(choice)
            selected = rooms[number - 1:number] if number > 0 else []
        elif choice:
            selected = [r for r in rooms if choice.casefold() in {name.casefold() for name in r[2]}]
        if len(selected) == 1:
            settings = self.settings()
            settings["room"] = selected[0][0]
            with self.settings_store.locked():
                self.settings_store.write("settings.json", settings)
            await self.publish()
            await self.notice(event.source.chat_id, "연결된 방: " + selected[0][1])
        else:
            current = next((r[1] for r in rooms if r[0] == self.settings()["room"]), "없음")
            listing = "연결된 방: " + current + "\n" + "\n".join(f"{n}. {r[1]}" for n, r in enumerate(rooms, 1))
            await self.notice(event.source.chat_id, listing)


class ExternalReply:
    """The receive() response endpoint for the phone; journal acknowledgements stay in the app."""
    features = {"rooms"}

    def __init__(self, bridge, chat_id):
        self.bridge, self.chat_id = bridge, chat_id
        self.failed = False

    async def send(self, frame):
        if frame["type"] == "error":
            self.failed = True
            await self.bridge.notice(self.chat_id, "지금은 받지 못했어요")


def split_characters(text, limit):
    """Lossless phone chunks in Unicode code points, preferring the last complete line."""
    while len(text) > limit:
        end = text.rfind("\n", 0, limit) + 1 or limit
        yield text[:end]
        text = text[end:]
    if text:
        yield text
