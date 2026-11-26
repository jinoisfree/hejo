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
from . import owner
from .auth import AuthRejected
from .connection_manager import Connections
from .connections import ConnectionFailure
from .deadlines import Deadlines
from .files import MAX_FILE_BYTES, UnknownFile
from .pictures import Pictures, MAX_PICTURE_BYTES, picture_address, valid_png
from .journal import HejoJournalError
from .history import HistorySession, HistoryError, encoded, PAGE_BYTES
from .history_queries import HistoryQueries, stamp
from .history_search import available as history_search_available
from hermes_constants import get_hermes_home

SEND_TIMEOUT = 5.0
PONG_TIMEOUT = 30.0
log = logging.getLogger(__name__)
SCHEMA = json.loads((Path(__file__).resolve().parent.parent / "schemas" / "hejo-wire-v1.json").read_text())
LIMITS = SCHEMA["x-limits"]
HISTORY_SCHEMA = json.loads((Path(__file__).resolve().parent.parent / "schemas" / "hejo-history-v1.json").read_text())
HISTORY_VALIDATORS = {kind: Draft202012Validator({**HISTORY_SCHEMA, "oneOf": [{"$ref": "#/$defs/" + kind}]})
                      for kind in ("context", "query", "content")}
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

    history: object = None
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
        self.local = None
        self.home = Path(get_hermes_home())
        self.deadlines = Deadlines(self.home)
        self.admin_connections = Connections(self.home, adapter.employees)
        runner = getattr(adapter, "_message_handler", None)
        runner = getattr(runner, "__self__", None)
        self.pictures = Pictures(self.home, getattr(getattr(runner, "config", None), "multiplex_profiles", True))

    async def start(self, listen, port):
        if not listen or any(not allowed_address(addr) for addr in listen):
            raise ValueError("listen_address_forbidden")
        app = web.Application(client_max_size=MAX_FILE_BYTES + LIMITS["frame_bytes"])
        app.router.add_get("/v1/ws", self.websocket)
        app.router.add_get("/v1/history/capabilities", self.history_capabilities)
        for kind in ("context", "query", "content"):
            app.router.add_post("/v1/history/" + kind, self.history_request)
        app.router.add_post("/v1/files", self.upload)
        app.router.add_get("/v1/files/{employee}/{file_id}", self.download)
        app.router.add_get("/v1/files/{employee}/{file_id}/metadata", self.file_metadata)
        app.router.add_get("/v1/owner", self.owner_profile)
        app.router.add_put("/v1/owner", self.owner_profile)
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
            from .local import LocalIngress
            self.local = LocalIngress(self.adapter, get_hermes_home())
            await self.local.start()
        except Exception:
            await self.stop()
            raise
        self.tasks.add(asyncio.create_task(self.maintenance()))

    async def stop(self):
        if self.local:
            await self.local.stop()
            self.local = None
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

    async def send_deadline_close(self, conn, frame):
        employees = {e['id'] for e in self.adapter.employees()} | {'default'}
        try:
            result = await self.deadlines.close(conn.device_id, frame['employee'], frame['deadline'],
                                                frame['outcome'], employees)
            await conn.send({'v': 1, 'type': 'deadline_close_status', 'ref': frame['id'], **result})
        except (ConnectionError, RuntimeError, TimeoutError):
            log.warning('deadline_close_failed reason=connection_closed')

    async def http_auth(self, request):
        if not allowed_address(request.remote):
            raise web.HTTPForbidden()
        authorization = request.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            raise web.HTTPUnauthorized()
        try:
            return await self.authenticate(authorization[7:])
        except AuthRejected:
            raise web.HTTPUnauthorized() from None

    async def history_capabilities(self, request):
        if not allowed_address(request.remote):
            return web.json_response({'code': 'auth', 'request': None, 'retryable': False}, status=403)
        if not history_search_available():
            return web.json_response({'code': 'unavailable', 'request': None, 'retryable': True}, status=503)
        return web.json_response({'version': 1, 'mode': 'history-v1', 'limits': HISTORY_SCHEMA['x-limits']},
                                 headers={'Cache-Control': 'no-store'})

    async def history_request(self, request):
        ref = None
        try:
            device, hub_token = await self.http_auth(request)
            kind = request.path.rsplit('/', 1)[-1]
            limit = HISTORY_SCHEMA['x-limits']['context_bytes' if kind == 'context' else 'query_bytes']
            body = bytearray()
            async for chunk in request.content.iter_chunked(16384):
                body.extend(chunk)
                if len(body) > limit:
                    raise HistoryError('too_large', 413)
            try:
                document = json.loads(body, parse_constant=lambda _: (_ for _ in ()).throw(ValueError()))
            except (ValueError, UnicodeError, RecursionError):
                raise HistoryError('invalid_query') from None
            if not HISTORY_VALIDATORS[kind].is_valid(document):
                raise HistoryError('invalid_query')
            try:
                encoded(document)  # Reject non-finite numbers and unpaired Unicode surrogates.
            except (ValueError, UnicodeError, RecursionError):
                raise HistoryError('invalid_query') from None
            ref = document.get('request')
            conn = next((c for c in self.connections if c.history is not None
                         and c.history.token == document['session'] and not c.ws.closed), None)
            if conn is None:
                raise HistoryError('session_expired', 409)
            if conn.device_id != device or bool(conn.hub_token) != bool(hub_token):
                raise HistoryError('auth', 403)
            session = conn.history
            rooms = {e['id'] for e in self.adapter.employees()} | set(self.adapter.journal.rooms)
            if kind == 'context':
                context = session.set_context(document, rooms)
                result = {'context': context.token, 'generation': document['generation'],
                          'memberRevision': document['memberRevision']}
            elif kind == 'content':
                result = session.content(document['ref'], document.get('cursor'), rooms=rooms)
            else:
                context = session.context(document['context'])
                if len(document.get('query', '').encode()) > HISTORY_SCHEMA['x-limits']['query_text_bytes']:
                    raise HistoryError('too_large', 413)
                result = await self.history_query(session, context, document, rooms)
            if conn not in self.connections or conn.ws.closed:
                raise HistoryError('session_expired', 409)
            if kind == 'query':
                session.context(document['context'])
            payload = encoded(result)
            if len(payload) > PAGE_BYTES:
                raise HistoryError('too_large', 413)
            return web.Response(body=payload, content_type='application/json', headers={'Cache-Control': 'no-store'})
        except web.HTTPException as error:
            if error.status not in (401, 403):
                raise
            return web.json_response({'code': 'auth', 'request': None, 'retryable': False}, status=error.status)
        except HistoryError as error:
            return web.json_response({'code': error.code, 'request': ref,
                                      'retryable': error.status == 503}, status=error.status)

    async def history_query(self, session, context, document, rooms):
        kind, scope = document['kind'], document['scope']
        if scope != 'home' and scope not in rooms:
            raise HistoryError('target_missing', 404)
        allowed = set(context.document['home']) & rooms if scope == 'home' else {scope}
        if document.get('mode') == 'sidebar' and kind in ('overview', 'read_plan', 'notices'):
            if scope != 'home' or kind == 'read_plan' and document.get('action') != 'seed':
                raise HistoryError('invalid_query')
            allowed = rooms
        result = {'session': session.token, 'context': context.token, 'request': document['request'],
                  'through': session.index.head, 'items': [], 'next': None, 'complete': True}
        if not hasattr(context, 'queries'):
            context.queries = HistoryQueries(session.index, context)
        queries = context.queries
        if kind in ('messages', 'copy') or kind == 'resolve' and isinstance(document.get('target'), dict):
            target = document.get('target')
            if not isinstance(target, dict) or target['room'] not in allowed:
                raise HistoryError('invalid_query')
            if kind == 'copy' and document.get('action') == 'finalize':
                return {**result, **session.finish_copy(document.get('copyRef'), context=context.token, key=(target['room'], target['thread']))}
            key = (target['room'], target['thread'])
            root = await queries.summary(key)
            if root is None:
                raise HistoryError('target_missing', 404)
            page = session.messages(context=context.token, request=document['request'],
                                    key=(target['room'], target['thread']), limit=document.get('limit', 50),
                                    cursor=document.get('cursor'), copy=kind == 'copy', anchor=document.get('anchor'))
            page['root'] = root
            return page
        if kind == 'message_state':
            if not context.document['ready']:
                raise HistoryError('context_not_ready', 409)
            from .history_queries import thinking
            for identifier in document['target']:
                key = session.index._keys.get(identifier)
                item = session.index.resolve(identifier) if key and key[0] in rooms else None
                state = {'id': identifier, 'status': 'missing'}
                if item and item.get('deleted'):
                    state = {'id': identifier, 'status': 'deleted', 'revision': item['revision']}
                elif item:
                    state = {'id': identifier, 'status': 'present',
                             'key': {'room': key[0], 'thread': key[1]},
                             'seq': item['seq'], 'revision': item['revision'],
                             'read': item['revision'] <= max(context.read('read:'+key[0]),
                                                            context.read('thread:'+key[0]+'/'+key[1])),
                             'eligible': item['role'] == 'employee' and not thinking(item['text'])}
                result['items'].append(state)
            return result
        if kind in ('receipt', 'resolve'):
            target = document.get('target')
            if not isinstance(target, list):
                raise HistoryError('invalid_query')
            for identifier in target:
                if kind == 'receipt':
                    item = session.index.receipt(identifier)
                    if 'key' in item and item['key']['room'] not in allowed:
                        item = {'client_msg_id': identifier, 'status': 'not_found'}
                else:
                    item = session.index.resolve(identifier)
                    key = session.index._keys.get(identifier)
                    if key is not None and key[0] not in allowed:
                        item = None
                    item = item or {'msg_id': identifier, 'missing': True}
                    if len(encoded(item)) > (PAGE_BYTES - 4096) // len(target):
                        item = {'msg_id': identifier, 'revision': item['revision'],
                                'contentRef': session.content_ref(identifier, item['revision'])}
                result['items'].append(item)
            return result
        if kind == 'read_plan':
            # Cursor pages reuse the complete original plan, even if live messages
            # or thread membership changed after its first page.
            values = [] if document.get('cursor') else await queries.read_plan(
                sorted(allowed), document.get('action'), document.get('target'))
            if len(encoded(values)) > 1024 * 1024:
                raise HistoryError('too_large', 413)
            result = session.rows(document, values, freeze=True)
            result['action'] = document.get('action')
            result['changes'] = {item['id']: item['value'] for item in result.pop('items')}
            return result
        if kind == 'questions':
            if scope != 'home':
                raise HistoryError('invalid_query')
            return session.rows(document, await queries.questions(sorted(rooms)))
        if kind == 'search':
            mode = document.get('mode', 'groups')
            if mode not in ('groups', 'sidebar', 'room'):
                raise HistoryError('unsupported_query')
            if mode == 'room' and scope == 'home':
                raise HistoryError('invalid_query')
            # Workspace and sidebar search cover every authorized room, independent of home filters.
            if mode in ('groups', 'sidebar') and scope == 'home':
                allowed = rooms
            values = await queries.search(document.get('query', ''), sorted(allowed), mode)
            return session.rows(document, values)
        if kind in ('threads', 'overview', 'notices'):
            summaries = await queries.summaries(sorted(allowed))
            notices = queries.notices(summaries)
            totals = {'unread': sum(s['unread'] for s in summaries),
                      'questions': sum(n['questions'] for n in notices),
                      'alerts': sum(not n['questions'] for n in notices)}
            expiries = [s['nextNoticeExpiry'] for s in summaries if s['nextNoticeExpiry'] is not None]
            totals['nextNoticeExpiry'] = min(expiries, default=None)
            if kind == 'notices':
                return session.rows(document, notices, totals=totals)
            if kind == 'overview':
                values = []
                for room in sorted(allowed):
                    scoped = [s for s in summaries if s['key']['room'] == room]
                    scoped_notices = [n for n in notices if n['key']['room'] == room]
                    values.append({'id': room, 'unread': sum(s['unread'] for s in scoped),
                                   'questions': sum(n['questions'] for n in scoped_notices),
                                   'alerts': sum(not n['questions'] for n in scoped_notices),
                                   'latestSeq': max((s['latestSeq'] for s in scoped), default=0),
                                   'latestActivity': max((s['sidebarActivity'] for s in scoped), default=0)})
                return session.rows(document, values, totals=totals)
            if document.get('mode') == 'selection':
                summaries.sort(key=lambda s: (-s['latestSeq'], s['key']['thread']))
                older = False
            elif document.get('mode') is not None:
                raise HistoryError('invalid_query')
            elif scope == 'home':
                summaries.sort(key=lambda s: (stamp(s['lastTime']), s['key']['thread']))
                older = True
            else:
                summaries.sort(key=lambda s: s['rootSeq'])
                older = True
            return session.rows(document, summaries, older=older, totals=totals)
        raise HistoryError('unsupported_query')

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

    async def file_metadata(self, request):
        await self.http_auth(request)
        try:
            _, entry, timestamp = self.adapter.files.registered_entry(request.match_info["employee"], request.match_info["file_id"])
        except (UnknownFile, OSError):
            raise web.HTTPNotFound() from None
        if not isinstance(timestamp, str) or not timestamp:
            raise web.HTTPNotFound()
        return web.json_response({"file": {key: entry[key] for key in ("file_id", "name", "mime", "size")}, "ts": timestamp})

    async def download(self, request):
        await self.http_auth(request)
        try:
            path, mime = self.adapter.files.registered(request.match_info["employee"], request.match_info["file_id"])
        except (UnknownFile, OSError):
            raise web.HTTPNotFound() from None
        return web.FileResponse(path, headers={"Content-Type": mime, "X-Content-Type-Options": "nosniff"})

    def roster_frame(self, ref, profile):
        return {"v": 1, "type": "roster", "ref": ref,
                "employees": self.adapter.employees(), "owner": profile}

    async def owner_profile(self, request):
        await self.http_auth(request)
        if request.method == "PUT":
            try:
                data = await request.json()
                if not isinstance(data, dict) or "name" not in data:
                    raise ValueError("invalid_name")
                owner.write_name(self.home, data["name"])
            except (ValueError, RecursionError):
                raise web.HTTPBadRequest(text="invalid_name") from None
            except OSError:
                log.error("owner_profile_write_failed")
                raise web.HTTPInternalServerError() from None
        profile = owner.profile(self.home)
        if request.method == "PUT":
            await self.broadcast(self.roster_frame("owner", profile))
        return web.json_response({"ok": True, "owner": profile})

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
        if kind == "owner" and identifier != "owner":
            raise web.HTTPNotFound()
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
                picture = picture_address(kind, identifier, path)
            else:
                self.pictures.delete(kind, identifier)
            result = {"ok": True, "picture": picture}
            if kind in {"employee", "owner"}:
                profile = owner.profile(self.home)
                await self.broadcast(self.roster_frame("owner" if kind == "owner" else "picture", profile))
                if kind == "owner":
                    result["owner"] = profile
            return web.json_response(result)
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
            if conn.history is not None and frame.get('seq', conn.history.through + 1) <= conn.history.through:
                continue
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
        # Removed feature frames are unknown, as are any other unregistered types.
        kinds = {SCHEMA['$defs'][item['$ref'].split('/')[-1]]['properties']['type']['const']
                 for item in SCHEMA['$defs']['clientFrame']['oneOf']}
        if isinstance(frame, dict) and isinstance(frame.get('type'), str) and frame['type'] not in kinds:
            raise FrameError("unexpected_frame", ref)
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
                       "head_seq": self.adapter.journal.head, "owner": owner.profile(self.home)}
            if "rooms" in conn.features:
                welcome["rooms"] = list(self.adapter.journal.rooms.values())
            if paired:
                welcome["token"] = token
            if "history-v1" in conn.features:
                conn.history = HistorySession(self.adapter.journal.history)
                welcome['history'] = {'version': 1, 'session': conn.history.token,
                                      'through': conn.history.through}
                # No await between H, welcome enqueue and publication enrollment.
                sent = conn.enqueue(welcome)
                conn.replaying = False
                self.connections.add(conn)
                await sent
            else:
                await conn.send(welcome)
                since = hello.get("since", welcome["head_seq"])
                if since > welcome["head_seq"]:
                    await self.error("invalid_since", hello.get("id"), conn)
                    return ws
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
                    if frame["type"] in {"telegram", "telegram_pair", "telegram_unpair", "telegram_save"}:
                        await self.adapter.telegram.command(frame, conn)
                    elif frame["type"] in {"discord", "discord_pair", "discord_unpair", "discord_save", "discord_layout"}:
                        await self.adapter.discord.command(frame, conn)
                    elif frame["type"] == "roster":
                        await conn.send(self.roster_frame(frame["id"], owner.profile(self.home)))
                    elif frame['type'] == 'deadlines':
                        waiter = asyncio.create_task(self.send_deadlines(conn, frame['id']))
                        conn.deadline_waiters.add(waiter)
                        waiter.add_done_callback(conn.deadline_waiters.discard)
                    elif frame['type'] == 'deadline_close':
                        # The close itself is shielded inside Deadlines: dropping this waiter never stops it.
                        waiter = asyncio.create_task(self.send_deadline_close(conn, frame))
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
                        if conn.history is not None:
                            await self.error("unsupported_mode", frame.get("id"), conn)
                        elif frame["since"] > self.adapter.journal.head:
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
