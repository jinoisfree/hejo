"""The second door: private pairing, room settings and external message ownership."""
import asyncio
import hmac
import logging
import secrets
import time
from pathlib import Path

from .auth import AuthStore, PAIR_TTL, digest

log = logging.getLogger(__name__)
_photon = None


def attach_photon(native, adapter):
    """Platform handler contract; resolve the primary at dispatch time, in either start order."""
    global _photon
    _photon = adapter
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

    adapter._hejo_imessage_original = original
    adapter.handle_message = handle
    adapter._hejo_imessage_wrapped = True


class IMessage:
    def __init__(self, adapter, home, clock=time.time):
        self.adapter = adapter
        self.clock = clock
        self.vault = AuthStore(home, clock)
        self.settings_store = AuthStore(home, clock)
        self.settings_store.path = Path(home) / "shared" / "hejo" / "imessage"

    def private(self):
        with self.vault.locked():
            return self.vault.read("imessage.json", {"pair": None, "code": None})

    def rooms(self):
        employees = self.adapter.employees()
        groups = sorted((room for room in self.adapter.journal.rooms.values()
                         if not room.get("archived") and room["id"] not in self.adapter.journal.deleted_rooms),
                        key=lambda room: room["title"].casefold())
        return [(e["id"], e["name"], [e["id"], e["name"], *e.get("aliases", [])]) for e in employees] + [
            (r["id"], r["title"], [r["title"]]) for r in groups]

    def settings(self):
        with self.settings_store.locked():
            value = self.settings_store.read("settings.json", {"enabled": False, "room": None, "reports": []})
        available = {r[0] for r in self.rooms()}
        return {"enabled": value["enabled"], "room": value["room"] if value["room"] in available else None,
                "reports": [r for r in value["reports"] if r in available]}

    def status(self, ref=None):
        return {"v": 1, "type": "imessage_status", "platform_ready": _photon is not None,
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
            if _photon is None:
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
        if not self.adapter.is_connected or _photon is None:
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
        # TASK-03 supplies the admitted message path.
        return await self.original_external(event)

    async def original_external(self, event):
        return await _photon._hejo_imessage_original(event)
