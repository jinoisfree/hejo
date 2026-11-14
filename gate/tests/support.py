"""Isolated integration fixtures. The runner substitutes agent turns, never transport/auth."""
import asyncio
import os
import uuid
import pytest
import pytest_asyncio


@pytest.fixture
def airport(tmp_path, monkeypatch):
    monkeypatch.setenv("HERMES_HOME", str(tmp_path))
    for key in tuple(os.environ):
        if key.startswith(("GATEWAY_", "HEJO_", "HERMES_PROFILE", "HERMES_TEAM_")):
            if key != "HEJO_TEAM_KIT_LIB":
                monkeypatch.delenv(key, raising=False)
    library = os.environ.get("HEJO_TEAM_KIT_LIB")
    if library:
        monkeypatch.syspath_prepend(library)
    from hermes_cli.profiles import create_profile
    for name in ("alpha", "beta"):
        create_profile(name, no_alias=True, no_skills=True)
    return tmp_path


@pytest.fixture
def registered(airport):
    from hermes_cli.plugins import PluginContext, PluginManager
    from hermes_cli.plugins_manifest import PluginManifest
    from gate import register
    manager = PluginManager()
    manifest = PluginManifest(name="hejo", kind="platform", source="user")
    register(PluginContext(manifest, manager))
    return manager


@pytest_asyncio.fixture
async def gate(registered):
    from gateway.config import PlatformConfig
    from gate.adapter import HejoAdapter
    adapter = HejoAdapter(PlatformConfig(enabled=True, extra={"listen": ["127.0.0.1"], "port": 0}))
    assert await adapter.connect()
    try:
        yield adapter
    finally:
        await adapter.disconnect()


@pytest.fixture
def runner(gate):
    from gateway.authz_mixin import GatewayAuthorizationMixin
    from gateway.config import GatewayConfig

    class TurnRunner(GatewayAuthorizationMixin):
        def __init__(self):
            self.events = []
            self.keys = []
            self.denied = []
            self.config = GatewayConfig()
            self.adapters = {gate.platform: gate}

        async def handle(self, event):
            if self._is_user_authorized(event.source):
                self.events.append(event)
                self.keys.append(gate._event_session_key(event))
            else:
                self.denied.append(event)

    value = TurnRunner()
    gate.set_message_handler(value.handle)
    return value


@pytest_asyncio.fixture
async def client(gate):
    from aiohttp import ClientSession
    from jsonschema import Draft202012Validator
    from gate.server import SCHEMA
    validator = Draft202012Validator({**SCHEMA, "oneOf": [{"$ref": "#/$defs/serverFrame"}]})

    class Client:
        async def open(self, **hello):
            ws = await session.ws_connect(f"http://127.0.0.1:{gate.server.port}/v1/ws")
            await ws.send_json({"v": 1, "type": "hello", "device_name": "Test device", "app_version": "test", **hello})
            return ws, await self.read(ws)

        async def pair(self, **hello):
            return await self.open(pair_code=gate.auth.pair_code(), **hello)

        async def read(self, ws):
            frame = await ws.receive_json(timeout=5)
            validator.validate(frame)
            return frame

        async def until(self, ws, typ):
            frames = []
            while True:
                frame = await self.read(ws)
                frames.append(frame)
                if frame["type"] == typ:
                    return frames

        async def send(self, ws, thread=None, **fields):
            await ws.send_json({"v": 1, "type": "send", "id": str(uuid.uuid4()),
                                "employee": "alpha", "thread": thread or str(uuid.uuid4()),
                                "text": "test request", "client_msg_id": str(uuid.uuid4()), **fields})

    async with ClientSession(trust_env=False) as session:
        yield Client()


async def wait_for_turns(runner, count):
    async with asyncio.timeout(3):
        while len(runner.events) + len(runner.denied) < count:
            await asyncio.sleep(0.01)
