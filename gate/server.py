"""Address/auth boundary, websocket framing and per-device replay state."""
import asyncio
from dataclasses import dataclass, field
import ipaddress
import json
import logging
import os
import traceback
import time
from collections import deque
from pathlib import Path
from aiohttp import web, WSMsgType
from jsonschema import Draft202012Validator
from .auth import AuthRejected
from .connection_manager import Connections
from .connections import ConnectionFailure
from .deadlines import Deadlines
from .files import MAX_FILE_BYTES, UnknownFile
from .pictures import Pictures, MAX_PICTURE_BYTES, valid_png
from .journal import HejoJournalError
from hermes_constants import get_hermes_home

SEND_TIMEOUT = 5.0
PONG_TIMEOUT = 30.0
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
            try:
                await self.send_json({"v": 1, "type": "error", "code": "too_large", "ref": None})
            except (ConnectionError, RuntimeError):
                # The peer may still be sending or already disconnected. An error
                # frame is best effort; its failure must not skip the 1009 close.
                pass
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
    hub_token: str = None  # set for hub-issued sign-ins; re-checked with the hub while connected
    features: set = field(default_factory=set)

    deadline_waiters: set = field(default_factory=set)

    outgoing: deque = field(default_factory=deque)
    sender: object = None
    pong_deadline: float = None

    def enqueue(self, frame):
        done = asyncio.get_running_loop().create_future()
        if self.ws.closed:
            done.set_result(False)
            return done
        if len(self.outgoing) >= LIMITS['sync_queue']:
            done.set_result(False)
            asyncio.create_task(self.close())
            return done
        self.outgoing.append((frame, done))
        if self.sender is None or self.sender.done():
            self.sender = asyncio.create_task(self.drain())
        return done

    async def close(self, code=1000):
        try:
            await asyncio.wait_for(self.ws.close(code=code), 1.0)
        except (TimeoutError, ConnectionError, RuntimeError):
            transport = getattr(getattr(self.ws, '_req', None), 'transport', None)
            if transport is not None: transport.close()

    async def drain(self):
        try:
            while self.outgoing:
                frame, done = self.outgoing.popleft()
                success = False
                try:
                    if not self.ws.closed:
                        await asyncio.wait_for(self.ws.send_json(frame), SEND_TIMEOUT)
                        success = True
                except (TimeoutError, ConnectionError, RuntimeError):
                    await self.close()
                finally:
                    if not done.done(): done.set_result(success)
        finally:
            while self.outgoing:
                _, done = self.outgoing.popleft()
                if not done.done(): done.set_result(False)

    async def send(self, frame):
        await asyncio.shield(self.enqueue(frame))


class GateServer:
    def __init__(self, adapter):
        self.adapter = adapter
        self.connections = set()
        self.runner = None
        self.sites = []
        self.tasks = set()
        self.port = None
        self.deadlines = Deadlines(get_hermes_home())
        self.admin_connections = Connections(get_hermes_home(), adapter.employees)
        runner = getattr(adapter, "_message_handler", None)
        runner = getattr(runner, "__self__", None)
        self.pictures = Pictures(get_hermes_home(), getattr(getattr(runner, "config", None), "multiplex_profiles", True))

    async def start(self, listen, port):
        if not listen or any(not allowed_address(addr) for addr in listen):
            raise ValueError("listen_address_forbidden")
        app = web.Application(client_max_size=MAX_FILE_BYTES + LIMITS["frame_bytes"])
        app.router.add_get("/v1/ws", self.websocket)
        app.router.add_post("/v1/files", self.upload)
        app.router.add_get("/v1/files/{employee}/{file_id}", self.download)
        app.router.add_route("GET", "/v1/pictures/{kind}/{identifier}", self.picture)
        app.router.add_route("PUT", "/v1/pictures/{kind}/{identifier}", self.picture)
        app.router.add_route("DELETE", "/v1/pictures/{kind}/{identifier}", self.picture)
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
        await self.deadlines.stop()
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        self.tasks.clear()
        await asyncio.gather(*(c.close() for c in tuple(self.connections)))
        if self.runner:
            await self.runner.cleanup()
            self.runner = None
        self.sites.clear()

    async def send_deadlines(self, conn, ref):
        try:
            result = await self.deadlines.list()
            await conn.send({'v': 1, 'type': 'deadlines_status', 'ref': ref, **result})
        except (ConnectionError, RuntimeError, TimeoutError):
            log.warning('deadlines_failed reason=connection_closed')

    async def http_auth(self, request):
        if not allowed_address(request.remote):
            raise web.HTTPForbidden()
        authorization = request.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            raise web.HTTPUnauthorized()
        try:
            await self.authenticate(authorization[7:])
        except AuthRejected:
            raise web.HTTPUnauthorized() from None

    async def upload(self, request):
        await self.http_auth(request)
        employee = request.query.get("employee", "")
        if employee not in {e["id"] for e in self.adapter.employees()}:
            raise web.HTTPBadRequest(text="unknown_employee")
        try:
            reader = await request.multipart()
            part = await reader.next()
            if part is None or part.name != "file" or not part.filename:
                raise ValueError("invalid_upload")
            async def chunks():
                while chunk := await part.read_chunk(65536):
                    yield chunk
            info = await self.adapter.files.stage(employee, part.filename, chunks())
            return web.json_response(info)
        except ValueError as exc:
            if str(exc) == "too_large":
                raise web.HTTPRequestEntityTooLarge(max_size=MAX_FILE_BYTES, actual_size=MAX_FILE_BYTES + 1) from None
            raise web.HTTPBadRequest(text="invalid_upload") from None
        except OSError:
            log.error("attachment_upload_failed")
            raise web.HTTPInternalServerError() from None

    async def download(self, request):
        await self.http_auth(request)
        try:
            path, mime = self.adapter.files.registered(request.match_info["employee"], request.match_info["file_id"])
        except (UnknownFile, OSError):
            raise web.HTTPNotFound() from None
        return web.FileResponse(path, headers={"Content-Type": mime, "X-Content-Type-Options": "nosniff"})

    async def picture(self, request):
        await self.http_auth(request)
        identifier = request.match_info["identifier"]
        if request.match_info["kind"] == "room" and not identifier.startswith(("home-", "section-")) and request.method != "GET":
            async with self.adapter.files.lock, self.adapter._publish_lock:
                room = self.adapter.journal.rooms.get(identifier)
                if room is None:
                    raise web.HTTPNotFound()
                path = self.pictures.path("room", identifier)
                before = path.read_bytes() if path.is_file() else None
                response = await self._picture(request)
                picture = json.loads(response.body)["picture"]
                try:
                    saved = await self.adapter.journal.append({"v": 1, "type": "room", "room": {**room, "picture": picture}})
                except HejoJournalError:
                    if before is None:
                        self.pictures.delete("room", identifier)
                    else:
                        self.pictures.put("room", identifier, before)
                    raise web.HTTPInternalServerError(text="journal_write_failed") from None
                await self.broadcast(saved)
                return response
        return await self._picture(request)

    async def _picture(self, request):
        kind, identifier = request.match_info["kind"], request.match_info["identifier"]
        if kind == "employee" and identifier not in {e["id"] for e in self.adapter.employees()}:
            raise web.HTTPNotFound()
        if kind == "room" and not identifier.startswith(("home-", "section-")) and identifier not in self.adapter.journal.rooms:
            raise web.HTTPNotFound()
        try:
            picture = None
            if request.method == "GET":
                path = self.pictures.path(kind, identifier)
                if not path.is_file():
                    raise KeyError("unknown_picture")
                return web.FileResponse(path, headers={"Content-Type": "image/png", "X-Content-Type-Options": "nosniff"})
            if request.method == "PUT":
                data = bytearray()
                async for chunk in request.content.iter_chunked(65536):
                    data.extend(chunk)
                    if len(data) > MAX_PICTURE_BYTES:
                        raise web.HTTPRequestEntityTooLarge(max_size=MAX_PICTURE_BYTES, actual_size=len(data))
                if not valid_png(bytes(data)):
                    raise web.HTTPUnsupportedMediaType(text="invalid_picture")
                path = self.pictures.put(kind, identifier, bytes(data))
                picture = f"/v1/pictures/{kind}/{identifier}?v={path.stat().st_mtime_ns}"
            else:
                self.pictures.delete(kind, identifier)
            if kind == "employee":
                await asyncio.gather(*(c.send({"v": 1, "type": "roster", "ref": "picture", "employees": self.adapter.employees()}) for c in tuple(self.connections)))
            return web.json_response({"ok": True, "picture": picture})
        except KeyError:
            raise web.HTTPNotFound() from None
        except OSError:
            log.error("picture_write_failed")
            raise web.HTTPInternalServerError() from None

    async def maintenance(self):
        ticks = 0
        while True:
            await asyncio.sleep(0.5)
            try:
                devices = self.adapter.auth.devices()
            except (OSError, ValueError, KeyError, TypeError):
                log.error("auth_store_unavailable")
                await asyncio.gather(*(c.close(code=1008) for c in tuple(self.connections)))
                continue
            revoked = [conn for conn in tuple(self.connections)
                       if conn.hub_token is None and devices.get(conn.device_id, {}).get("revoked", True)]
            if ticks and ticks % 60 == 0:
                for conn in tuple(self.connections):
                    if conn.hub_token is not None:
                        try:
                            await self.adapter.hub.verify(conn.hub_token, fresh=True, allow_cached=True)
                        except AuthRejected as exc:
                            if exc.reason == 'hub_unavailable':
                                await conn.close(code=1001)
                            else:revoked.append(conn)
            await asyncio.gather(*(conn.close(code=1008) for conn in revoked))
            for conn in tuple(self.connections - set(revoked)):
                if conn.pong_deadline is not None and time.monotonic() >= conn.pong_deadline:
                    await conn.close()
                elif ticks and ticks % 60 == 0:
                    conn.pong_deadline = time.monotonic() + PONG_TIMEOUT
                    conn.enqueue({"v": 1, "type": "ping"})
            try:
                self.admin_connections.secrets.purge()
            except (OSError,ValueError,KeyError):
                log.error("connection_undo_cleanup_failed")
            ticks += 1

    async def error(self, code, ref=None, conn=None):
        frame = {"v": 1, "type": "error", "code": code, "ref": ref}
        if conn:
            await conn.send(frame)
        else:
            await self.broadcast(frame)

    async def broadcast(self, frame):
        # All queue transitions are synchronous on the server loop. Socket backpressure
        # belongs to each connection, outside the journal's publication lane.
        for conn in tuple(self.connections):
            if "seq" not in frame:
                if not self.adapter.journal.room_id(frame) or "rooms" in conn.features:
                    conn.enqueue(frame)
            elif conn.replaying:
                if not conn.overflow:
                    conn.queue.append(frame)
                    if len(conn.queue) > LIMITS["sync_queue"]:
                        conn.queue.clear(); conn.overflow = True
            else:
                conn.enqueue(self.project(frame, conn))

    def project(self, frame, conn):
        room = self.adapter.journal.room_id(frame)
        if room and "rooms" not in conn.features:
            return {"v": 1, "type": "delete", "seq": frame["seq"], "msg_id": frame.get("msg_id", "room:" + room)}
        return self.adapter.journal.replay(frame)

    async def sync(self, conn, since, ref):
        conn.replaying = True; conn.overflow = False; conn.queue.clear()
        page = self.adapter.journal.page(since, LIMITS["sync_page"])
        for frame in page:
            await conn.send(self.project(frame, conn))
        through = page[-1]["seq"] if page else since
        head = self.adapter.journal.head
        more = through < head or conn.overflow
        # Queue the boundary and buffered records atomically before live publication resumes.
        pending = [conn.enqueue({"v": 1, "type": "sync_done", "ref": ref,
                                "through": through, "more": more, "head_seq": head})]
        if not more:
            pending += [conn.enqueue(self.project(frame, conn)) for frame in conn.queue if frame["seq"] > through]
            conn.replaying = False
        conn.queue.clear()
        await asyncio.gather(*pending)

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

    async def authenticate(self, token, *, fresh=False):
        """(device id, hub token or None): this gate's own devices first, then the member's hub sign-ins."""
        try:
            return self.adapter.auth.authenticate(token), None
        except AuthRejected as exc:
            if exc.reason != "unknown" or not self.adapter.hub.enabled:
                raise
        return await self.adapter.hub.verify(token, fresh=fresh), token

    @staticmethod
    def peer(request):
        try:
            return ipaddress.ip_address(request.remote)
        except (ValueError, TypeError):
            return None

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
            paired = "token" not in hello
            peer = self.peer(request)
            auth, name, hub_token = self.adapter.auth, hello["device_name"], None
            try:
                if "local" in hello:
                    # Password reset without the old password: only on the Mac that runs this member's Hermes.
                    if (peer is None or not peer.is_loopback or not self.adapter.hub.enabled
                            or not auth.consume_local(hello["local"]["code"])):
                        raise AuthRejected("local_only")
                    device_id, token = await self.adapter.hub.reset(hello["local"]["password"], name)
                    hub_token = token
                elif "pair_code" in hello:
                    device_id, token = auth.pair(hello["pair_code"], name)
                else:
                    device_id, hub_token = await self.authenticate(hello["token"], fresh=True)
            except AuthRejected as exc:
                if exc.reason == 'hub_unavailable':
                    # Old apps treat unknown pre-welcome frames as retryable protocol
                    # failures, preserving credentials; auth_rejected would erase them.
                    await ws.send_json({'v':1,'type':'error','code':'hub_unavailable','ref':None})
                    return ws
                await ws.send_json({"v": 1, "type": "pair_rejected" if paired else "auth_rejected",
                                    "reason": exc.reason})
                return ws
            conn = Connection(ws, device_id, replaying=True, hub_token=hub_token, features=set(hello.get("features", [])))
            welcome = {"v": 1, "type": "welcome", "device_id": device_id,
                       "gate_version": "1.0.0", "employees": self.adapter.employees(),
                       "head_seq": self.adapter.journal.head}
            if "rooms" in conn.features:
                welcome["rooms"] = list(self.adapter.journal.rooms.values())
            if paired:
                welcome["token"] = token
            await conn.send(welcome)
            since = hello.get("since", welcome["head_seq"])
            if since > welcome["head_seq"]:
                await self.error("invalid_since", hello.get("id"), conn)
                return ws
            # Enrol only after welcome: ephemeral frames cannot overtake it either.
            # Records committed during welcome are recovered from its head snapshot.
            self.connections.add(conn)
            await self.sync(conn, since, hello.get("id", "hello"))
            async for message in ws:
                if message.type in {WSMsgType.CLOSE, WSMsgType.CLOSED, WSMsgType.ERROR}:
                    break
                try:
                    frame = self.parse(message)
                except ValueError as exc:
                    await self.error(str(exc), getattr(exc, "ref", None), conn)
                    continue
                try:
                    if frame["type"] in {"imessage", "imessage_pair", "imessage_unpair", "imessage_save"}:
                        await self.adapter.imessage.command(frame, conn)
                    elif frame["type"] == "roster":
                        await conn.send({"v": 1, "type": "roster", "ref": frame["id"],
                                         "employees": self.adapter.employees()})
                    elif frame['type'] == 'deadlines':
                        waiter = asyncio.create_task(self.send_deadlines(conn, frame['id']))
                        conn.deadline_waiters.add(waiter)
                        waiter.add_done_callback(conn.deadline_waiters.discard)
                    elif frame['type'] in {'connections','connection_action'}:
                        try:
                            if frame['type']=='connections':
                                document=await self.admin_connections.document(frame.get('profile'))
                                await conn.send({'v':1,'type':'connections_status','ref':frame['id'],'document':document})
                            else:
                                reply=await self.admin_connections.perform(conn.device_id,frame)
                                await conn.send({'v':1,'type':'connection_result','ref':frame['id'],'reply':reply})
                        except (ConnectionFailure,OSError,ValueError) as error:
                            reason=error.reason if isinstance(error,ConnectionFailure) else 'invalid_response'
                            log.warning('connections_failed type=%s profile=%s reason=%s',frame['type'],frame.get('profile','-'),reason)
                            await conn.send({'v':1,'type':'connection_result','ref':frame['id'],
                                             'reply':{'outcome':'failed','reason':reason}})
                        finally:
                            frame.pop('values',None)
                    elif frame["type"] == "sync":
                        if frame["since"] > self.adapter.journal.head:
                            await self.error("invalid_since", frame.get("id"), conn)
                        else:
                            await self.sync(conn, frame["since"], frame["id"])
                    elif frame["type"] == "send":
                        await self.adapter.receive(frame, conn)
                    elif frame["type"] == "click":
                        await self.adapter.click(frame, conn)
                    elif frame["type"] == "thread_delete":
                        await self.adapter.thread_delete(frame, conn)
                    elif frame["type"] == "thread_branch":
                        await self.adapter.thread_branch(frame, conn)
                    elif frame["type"] in {"room_save", "room_archive", "room_delete"}:
                        await self.adapter.room_command(frame, conn)
                    elif frame["type"] == "pong":
                        conn.pong_deadline = None
                    else:
                        await self.error("unexpected_frame", frame.get("id"), conn)
                except Exception as exc:
                    # Exception messages may embed frame text. Keep only type and stack.
                    log.error("inbound_dispatch_failed exception_type=%s.%s\n%s",
                              type(exc).__module__, type(exc).__qualname__,
                              "".join(traceback.format_tb(exc.__traceback__)))
                    await self.error("dispatch_failed", frame.get("id"), conn)
        finally:
            if conn:
                self.connections.discard(conn)
                self.admin_connections.disconnected(conn.device_id)
                for waiter in tuple(conn.deadline_waiters):
                    waiter.cancel()
                await asyncio.gather(*conn.deadline_waiters, return_exceptions=True)
                if conn.sender is not None and not conn.sender.done():
                    conn.sender.cancel()
                    await asyncio.gather(conn.sender, return_exceptions=True)
            await ws.close()
        return ws
