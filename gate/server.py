"""Address/auth boundary, websocket framing and per-device replay state."""
import asyncio
from dataclasses import dataclass, field
import ipaddress
import json
import logging
from pathlib import Path
from aiohttp import web, WSMsgType
from jsonschema import Draft202012Validator
from .auth import AuthRejected

log = logging.getLogger(__name__)
SCHEMA = json.loads((Path(__file__).resolve().parent.parent / "schemas" / "hejo-wire-v1.json").read_text())
LIMITS = SCHEMA["x-limits"]
CLIENT_VALIDATOR = Draft202012Validator({**SCHEMA, "oneOf": [{"$ref": "#/$defs/clientFrame"}]})
NETWORKS = tuple(ipaddress.ip_network(net) for net in
                 ("127.0.0.0/8", "::1/128", "100.64.0.0/10", "fd7a:115c:a1e0::/48"))


class BoundedWebSocket(web.WebSocketResponse):
    async def close(self, *, code=1000, message=b"", drain=True):
        # aiohttp enforces the bound while assembling fragments, before JSON parsing.
        if code == 1009 and not self.closed:
            await self.send_json({"v": 1, "type": "error", "code": "too_large", "ref": None})
        return await super().close(code=code, message=message, drain=drain)


def allowed_address(address):
    try:
        ip = ipaddress.ip_address(address)
        return any(ip in net for net in NETWORKS)
    except (ValueError, TypeError):
        return False


class FrameError(ValueError):
    def __init__(self, code, ref=None):
        self.ref = ref
        super().__init__(code)


@dataclass(eq=False)
class Connection:
    ws: object
    device_id: str
    replaying: bool = False
    queue: list = field(default_factory=list)
    overflow: bool = False
    lock: asyncio.Lock = field(default_factory=asyncio.Lock)

    async def send(self, frame):
        if not self.ws.closed:
            try:
                await self.ws.send_json(frame)
            except (ConnectionError, RuntimeError):
                await self.ws.close()


class GateServer:
    def __init__(self, adapter):
        self.adapter = adapter
        self.connections = set()
        self.runner = None
        self.sites = []
        self.tasks = set()
        self.port = None

    async def start(self, listen, port):
        if not listen or any(not allowed_address(addr) for addr in listen):
            raise ValueError("listen_address_forbidden")
        app = web.Application(client_max_size=LIMITS["frame_bytes"])
        app.router.add_get("/v1/ws", self.websocket)
        # Access logs contain no credential-bearing frame data or query strings.
        self.runner = web.AppRunner(app, access_log=None)
        await self.runner.setup()
        try:
            for address in listen:
                site = web.TCPSite(self.runner, address, port if self.port is None else self.port)
                await site.start()
                self.sites.append(site)
                self.port = site._server.sockets[0].getsockname()[1]
        except Exception:
            await self.stop()
            raise
        self.tasks.add(asyncio.create_task(self.maintenance()))

    async def stop(self):
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        self.tasks.clear()
        await asyncio.gather(*(c.ws.close() for c in tuple(self.connections)))
        if self.runner:
            await self.runner.cleanup()
            self.runner = None
        self.sites.clear()

    async def maintenance(self):
        ticks = 0
        while True:
            await asyncio.sleep(0.5)
            try:
                devices = self.adapter.auth.devices()
            except (OSError, ValueError, KeyError, TypeError):
                log.error("auth_store_unavailable")
                await asyncio.gather(*(c.ws.close(code=1008) for c in tuple(self.connections)))
                continue
            revoked = [conn for conn in tuple(self.connections)
                       if devices.get(conn.device_id, {}).get("revoked", True)]
            await asyncio.gather(*(conn.ws.close(code=1008) for conn in revoked))
            for conn in self.connections - set(revoked):
                if ticks and ticks % 60 == 0:
                    await conn.send({"v": 1, "type": "ping"})
            ticks += 1

    async def error(self, code, ref=None, conn=None):
        frame = {"v": 1, "type": "error", "code": code, "ref": ref}
        if conn:
            await conn.send(frame)
        else:
            await self.broadcast(frame)

    async def broadcast(self, frame):
        for conn in tuple(self.connections):
            if "seq" not in frame:
                await conn.send(frame)
                continue
            async with conn.lock:
                if conn.replaying:
                    if not conn.overflow:
                        conn.queue.append(frame)
                        if len(conn.queue) > LIMITS["sync_queue"]:
                            conn.queue.clear()
                            conn.overflow = True
                else:
                    await conn.send(frame)

    async def sync(self, conn, since, ref):
        async with conn.lock:
            conn.replaying = True
            conn.overflow = False
            conn.queue.clear()
            page = self.adapter.journal.page(since, LIMITS["sync_page"])
        for frame in page:
            await conn.send(frame)
        through = page[-1]["seq"] if page else since
        async with conn.lock:
            head = self.adapter.journal.head
            more = through < head or conn.overflow
            await conn.send({"v": 1, "type": "sync_done", "ref": ref,
                             "through": through, "more": more, "head_seq": head})
            if not more:
                for frame in conn.queue:
                    if frame["seq"] > through:
                        await conn.send(frame)
                conn.replaying = False
            conn.queue.clear()

    def parse(self, message):
        if message.type != WSMsgType.TEXT:
            raise FrameError("invalid_frame")
        if len(message.data.encode()) > LIMITS["frame_bytes"]:
            raise FrameError("too_large")
        try:
            frame = json.loads(message.data)
        except (ValueError, UnicodeDecodeError):
            raise FrameError("invalid_frame") from None
        ref = frame.get("id") if isinstance(frame, dict) else None
        ref = ref if isinstance(ref, str) else None
        if not CLIENT_VALIDATOR.is_valid(frame):
            raise FrameError("invalid_frame", ref)
        if len(frame.get("text", "").encode()) > LIMITS["text_bytes"]:
            raise FrameError("too_large", ref)
        return frame

    async def websocket(self, request):
        # Never trust forwarded headers; use the actual TCP peer.
        if not allowed_address(request.remote):
            raise web.HTTPForbidden()
        ws = BoundedWebSocket(max_msg_size=LIMITS["frame_bytes"] + 1, autoping=True, timeout=0.5)
        await ws.prepare(request)
        conn = None
        try:
            try:
                message = await asyncio.wait_for(ws.receive(), LIMITS["hello_seconds"])
                if ws.closed:
                    return ws
                hello = self.parse(message)
                if hello["type"] != "hello":
                    raise ValueError("hello_required")
            except (ValueError, asyncio.TimeoutError) as exc:
                code = str(exc) if isinstance(exc, ValueError) else "hello_timeout"
                await ws.send_json({"v": 1, "type": "error", "code": code, "ref": None})
                return ws
            paired = "pair_code" in hello
            try:
                if paired:
                    device_id, token = self.adapter.auth.pair(hello["pair_code"], hello["device_name"])
                else:
                    device_id = self.adapter.auth.authenticate(hello["token"])
            except AuthRejected as exc:
                await ws.send_json({"v": 1, "type": "pair_rejected" if paired else "auth_rejected",
                                    "reason": exc.reason})
                return ws
            conn = Connection(ws, device_id, replaying="since" in hello)
            self.connections.add(conn)
            welcome = {"v": 1, "type": "welcome", "device_id": device_id,
                       "gate_version": "1.0.0", "employees": self.adapter.employees(),
                       "head_seq": self.adapter.journal.head}
            if paired:
                welcome["token"] = token
            await conn.send(welcome)
            if "since" in hello:
                await self.sync(conn, hello["since"], hello.get("id", "hello"))
            async for message in ws:
                if message.type in {WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.ERROR}:
                    break
                try:
                    frame = self.parse(message)
                except ValueError as exc:
                    await self.error(str(exc), getattr(exc, "ref", None), conn)
                    continue
                try:
                    if frame["type"] == "roster":
                        await conn.send({"v": 1, "type": "roster", "ref": frame["id"],
                                         "employees": self.adapter.employees()})
                    elif frame["type"] == "sync":
                        if frame["since"] > self.adapter.journal.head:
                            await self.error("invalid_since", frame.get("id"), conn)
                        else:
                            await self.sync(conn, frame["since"], frame["id"])
                    elif frame["type"] == "send":
                        await self.adapter.receive(frame, conn)
                    elif frame["type"] == "click":
                        await self.adapter.click(frame, conn)
                    elif frame["type"] != "pong":
                        await self.error("unexpected_frame", frame.get("id"), conn)
                except Exception:
                    log.error("inbound_dispatch_failed")
                    await self.error("dispatch_failed", frame.get("id"), conn)
        finally:
            if conn:
                self.connections.discard(conn)
            await ws.close()
        return ws
