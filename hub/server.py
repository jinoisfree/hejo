"""hub HTTP API. Apps sign up / sign in here and learn their own Hermes gate; gates verify app tokens here."""
import asyncio
import ipaddress
import json
import logging

from aiohttp import web

from . import google
from .store import HubStore, Rejected
from .state import MemberStateStore, MAX_BYTES

log = logging.getLogger(__name__)
NETWORKS = tuple(ipaddress.ip_network(net) for net in ("127.0.0.0/8", "::1/128", "100.64.0.0/10", "fd7a:115c:a1e0::/48"))
STATUS = {"bad_login": 401, "locked": 429, "revoked": 401, "unknown": 401, "unknown_gate": 401, "not_linked": 401}


def allowed(address):
    try:
        ip = ipaddress.ip_address(address)
    except (ValueError, TypeError):
        return False
    return any(ip in net for net in NETWORKS)


def loopback(address):
    try:
        return ipaddress.ip_address(address).is_loopback
    except (ValueError, TypeError):
        return False


class Hub:
    def __init__(self, home):
        self.home = home
        self.store = HubStore(home)
        self.state = MemberStateStore(home)
        self.runner = None
        self.sites = []
        self.port = None
        self.state_waiters = {}
        self.stopping = False
        self.state_wait_seconds = 25

    def app(self):
        app = web.Application(client_max_size=64 * 1024, middlewares=[self.guard])
        app.on_shutdown.append(self.shutdown)
        app.router.add_get("/v1/hub", self.info)
        app.router.add_post("/v1/signup", self.signup)
        app.router.add_post("/v1/login", self.login)
        app.router.add_post("/v1/google", self.google)
        app.router.add_get("/v1/me", self.me)
        app.router.add_put("/v1/me/settings", self.settings)
        app.router.add_get("/v1/me/state", self.member_state)
        app.router.add_patch("/v1/me/state", self.member_state)
        app.router.add_post("/v1/link", self.link)
        app.router.add_post("/v1/gate/register", self.register)
        app.router.add_post("/v1/gate/verify", self.verify)
        app.router.add_post("/v1/gate/reset", self.reset)
        return app

    @web.middleware
    async def guard(self, request, handler):
        if not allowed(request.remote):
            raise web.HTTPForbidden()
        try:
            response = await handler(request)
        except Rejected as exc:
            response = web.json_response({"error": exc.reason}, status=STATUS.get(exc.reason, 400))
            log.info("%s %s %s %s", request.method, request.path, response.status, exc.reason)
            return response
        except (KeyError, TypeError, ValueError, json.JSONDecodeError):
            log.info("%s %s 400 bad_request", request.method, request.path)
            return web.json_response({"error": "bad_request"}, status=400)
        # Method, path and status only: never bodies, tokens or account names.
        log.info("%s %s %s", request.method, request.path, response.status)
        return response

    async def start(self, listen, port):
        self.runner = web.AppRunner(self.app(), access_log=None)
        await self.runner.setup()
        for address in listen:
            site = web.TCPSite(self.runner, address, port if self.port is None else self.port)
            await site.start()
            self.sites.append(site)
            self.port = site._server.sockets[0].getsockname()[1]

    async def shutdown(self, app):
        self.stopping = True
        for event in self.state_waiters.values():
            event.set()

    async def stop(self):
        if self.runner:
            await self.runner.cleanup()
            self.runner = None

    async def body(self, request):
        value = await request.json()
        if not isinstance(value, dict):
            raise ValueError("object")
        return value

    def bearer(self, request, scheme="Bearer "):
        value = request.headers.get("Authorization", "")
        if not value.startswith(scheme):
            raise Rejected("unknown")
        return value[len(scheme):]

    async def identity(self, id_token):
        try:
            return await google.identity(self.home, id_token)
        except google.GoogleRejected:
            raise Rejected("google_failed") from None

    async def info(self, request):
        return web.json_response({"hub": 1, "google_client_id": google.client_id(self.home)})

    async def signup(self, request):
        body = await self.body(request)
        linked = await self.identity(body["google_id_token"]) if body.get("google_id_token") else None
        return web.json_response(self.store.signup(body["account"], body["password"], body["device_name"], linked))

    async def login(self, request):
        body = await self.body(request)
        return web.json_response(self.store.login(body["account"], body["password"], body["device_name"]))

    async def google(self, request):
        body = await self.body(request)
        link = (body["account"], body["password"]) if "account" in body else None
        return web.json_response(self.store.google_login(await self.identity(body["id_token"]), body["device_name"],
                                                         body.get("new_password"), link))

    async def me(self, request):
        _, member = self.store.device(self.bearer(request))
        return web.json_response(self.store.me(member))

    async def settings(self, request):
        _, member = self.store.device(self.bearer(request))
        self.store.save_settings(member, (await self.body(request))["settings"])
        return web.json_response({"ok": True})

    async def member_state(self, request):
        _, member = self.store.device(self.bearer(request))
        try:
            if request.method == "GET":
                since = request.query.get("since")
                waiting = request.query.get("wait")
                if since is not None and waiting is not None:
                    raise Rejected("bad_state")
                revision = waiting if waiting is not None else since
                if revision is not None and (not revision.isascii() or not revision.isdecimal() or len(revision) > 16):
                    raise Rejected("bad_state")
                revision = int(revision) if revision is not None else None
                if waiting is None:
                    result = self.state.get(member, revision)
                else:
                    # Register before inspecting the revision: PATCH cannot be missed between read and wait.
                    event = self.state_waiters.setdefault(member, asyncio.Event())
                    event.clear()
                    result = self.state.get(member, revision)
                    if result["rev"] == revision and not self.stopping:
                        try:
                            await asyncio.wait_for(event.wait(), self.state_wait_seconds)
                        except asyncio.TimeoutError:
                            pass
                        self.store.device(self.bearer(request))  # A device revoked while waiting no longer has access.
                        result = self.state.get(member, revision)
            else:
                request = request.clone(client_max_size=MAX_BYTES + 64 * 1024)
                body = await self.body(request)
                if set(body) != {"items"}:
                    raise Rejected("bad_state")
                result = self.state.patch(member, body["items"])
                if member in self.state_waiters:
                    self.state_waiters[member].set()
        except (ValueError, TypeError, KeyError, web.HTTPRequestEntityTooLarge):
            raise Rejected("bad_state") from None
        return web.json_response(result, headers={"X-Hejo-State-Wait": "1"})

    # Gate side: only from this Mac (each member's Hermes runs here, in that member's own Mac account).

    def gate_member(self, request):
        if not loopback(request.remote):
            raise web.HTTPForbidden()
        return self.store.gate(self.bearer(request, "Gate "))

    async def link(self, request):
        if not loopback(request.remote):
            raise web.HTTPForbidden()
        body = await self.body(request)
        return web.json_response({"gate_key": self.store.link(body["account"], body["password"])})

    async def register(self, request):
        member = self.gate_member(request)
        self.store.register(member, (await self.body(request))["port"])
        return web.json_response({"ok": True})

    async def verify(self, request):
        member = self.gate_member(request)
        device_id, owner = self.store.device((await self.body(request))["token"])
        if owner != member:
            raise Rejected("unknown")  # another member's device must never open this member's Hermes
        return web.json_response({"device_id": device_id})

    async def reset(self, request):
        member = self.gate_member(request)
        body = await self.body(request)
        return web.json_response(self.store.gate_reset(member, body["password"], body["device_name"]))
