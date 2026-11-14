"""Code translation of AT-HF-01..14 and 32..37; expectations owned by the plan."""
import asyncio
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import uuid
from unittest.mock import patch
import pytest
from gate.tests.support import wait_for_turns

pytestmark = pytest.mark.asyncio


async def cli(*args):
    process = await asyncio.create_subprocess_exec(sys.executable, "-m", "gate.cli", *args,
                                                  stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    out, err = await process.communicate()
    assert process.returncode == 0, err.decode()
    return out.decode().strip()


async def test_at_hf_01(gate):
    """Listener binds exactly the configured interface and port."""
    assert gate.is_connected
    sockets = [sock for site in gate.server.sites for sock in site._server.sockets]
    assert len(sockets) == 1
    assert sockets[0].getsockname()[:2] == ("127.0.0.1", gate.server.port)
    with socket.socket() as probe:
        with pytest.raises(OSError):
            probe.bind(("127.0.0.1", gate.server.port))


async def test_at_hf_02(gate, client):
    """A secondary neither opens a listener nor requests runner reconnect."""
    from gate.adapter import HejoAdapter
    second = HejoAdapter(gate.config)
    second.set_owner_profile("beta")
    with patch("gate.server.GateServer.start") as start:
        assert await second.connect() is False
        start.assert_not_called()
    assert second._fatal_error_retryable is False
    assert second.server is None
    from gateway.run_adapters import GatewayAdapterLifecycleMixin
    lifecycle = object.__new__(GatewayAdapterLifecycleMixin)
    lifecycle._running = True
    lifecycle._profile_failed_platforms = {}
    with patch("asyncio.create_task") as scheduled:
        lifecycle._schedule_secondary_profile_startup_reconnect("beta", second.platform, second)
        lifecycle._schedule_secondary_profile_reconnect("beta", second.platform, second)
        scheduled.assert_not_called()
    assert lifecycle._profile_failed_platforms == {}
    ws, welcome = await client.pair()
    assert welcome["type"] == "welcome"
    await ws.close()


async def test_at_hf_03(gate, client):
    """CLI issuance shares credentials with the running gateway; code is one-use."""
    code = await cli("pair")
    ws, welcome = await client.open(pair_code=code)
    assert welcome["type"] == "welcome"
    assert len(welcome["token"]) >= 43
    await ws.close()
    ws, rejected = await client.open(pair_code=code)
    assert rejected == {"v": 1, "type": "pair_rejected", "reason": "used"}
    await ws.close()


async def test_at_hf_04(gate, client):
    """Expiry and five failures never mint credentials; correct code remains locked."""
    now = [1000]
    gate.auth.clock = lambda: now[0]
    code = gate.auth.pair_code()
    now[0] += 601
    ws, rejected = await client.open(pair_code=code)
    assert rejected["reason"] == "expired"
    await ws.close()
    code = gate.auth.pair_code()
    for _ in range(5):
        ws, rejected = await client.open(pair_code="wrong-code")
        assert rejected["reason"] == "wrong"
        await ws.close()
    ws, rejected = await client.open(pair_code=code)
    assert rejected["reason"] == "locked"
    assert gate.auth.devices() == {}
    await ws.close()


async def test_at_hf_05(gate, client):
    """Revocation by a separate CLI process disconnects within two seconds."""
    from aiohttp import WSMsgType
    ws, welcome = await client.pair()
    start = asyncio.get_running_loop().time()
    await cli("revoke", welcome["device_id"])
    message = await ws.receive(timeout=2 - (asyncio.get_running_loop().time() - start))
    assert message.type in {WSMsgType.CLOSE, WSMsgType.CLOSED}
    assert asyncio.get_running_loop().time() - start <= 2
    ws, rejected = await client.open(token=welcome["token"])
    assert rejected == {"v": 1, "type": "auth_rejected", "reason": "revoked"}
    await ws.close()


async def test_at_hf_06(gate, client):
    """Peer policy rejects the LAN address before preparing a websocket."""
    from aiohttp import web
    from types import SimpleNamespace
    from gate.server import allowed_address
    for address, allowed in [("192.168.0.10", False), ("100.100.1.1", True), ("127.0.0.1", True)]:
        assert allowed_address(address) is allowed
        if not allowed:
            with patch("gate.server.BoundedWebSocket") as websocket:
                with pytest.raises(web.HTTPForbidden):
                    await gate.server.websocket(SimpleNamespace(remote=address))
                websocket.assert_not_called()


async def test_at_hf_07(gate, client, airport, caplog):
    """No plaintext credentials in durable state or logs; credentials file is owner-only."""
    code = await cli("pair")
    ws, welcome = await client.open(pair_code=code)
    token = welcome["token"]
    await ws.close()
    ws, reject = await client.open(pair_code=code)
    assert reject["reason"] == "used"
    await ws.close()
    await cli("revoke", welcome["device_id"])
    ws, reject = await client.open(token=token)
    assert reject["reason"] == "revoked"
    await ws.close()
    stored = "".join(p.read_text() for p in (airport / "hejo").glob("*.json"))
    stored += "".join(p.read_text() for p in gate.journal.path.glob("*.jsonl"))
    for credential in (code, token):
        assert credential not in stored + caplog.text
    assert (airport / "hejo" / "devices.json").stat().st_mode & 0o777 == 0o600


@pytest.mark.parametrize("with_roster", [True, False])
async def test_at_hf_08(gate, client, airport, with_roster):
    """Both roster response types use the serving set and optional team-kit metadata."""
    if with_roster:
        # Use the real optional registry, no replacement parser or fake module.
        from hermes_facility import team_registry
        owner = airport / "owner"
        owner.mkdir()
        (owner / "team.yaml").write_text("agents:\n  alpha:\n    name: Alpha\n    aliases: [al]\n")
    ws, welcome = await client.pair()
    await ws.send_json({"v": 1, "type": "roster", "id": "r1"})
    response = await client.read(ws)
    assert response["ref"] == "r1"
    for frame in (welcome, response):
        assert {e["id"] for e in frame["employees"]} == {"default", "alpha", "beta"}
        alpha = next(e for e in frame["employees"] if e["id"] == "alpha")
        assert alpha["name"] == ("Alpha" if with_roster else "alpha")
        assert alpha["aliases"] == (["al"] if with_roster else [])
    await ws.close()


async def test_at_hf_09(gate, client):
    """Profile creation after connect is reflected in a new roster response."""
    from hermes_cli.profiles import create_profile
    ws, welcome = await client.pair()
    assert "gamma" not in {e["id"] for e in welcome["employees"]}
    create_profile("gamma", no_alias=True, no_skills=True)
    await ws.send_json({"v": 1, "type": "roster", "id": "r2"})
    assert "gamma" in {e["id"] for e in (await client.read(ws))["employees"]}
    await ws.close()


async def test_at_hf_10(gate, client, runner, monkeypatch):
    """Actual BasePlatformAdapter ingress and source keying route the employee/thread."""
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    ws, _ = await client.pair()
    thread = str(uuid.uuid4())
    await client.send(ws, thread)
    assert (await client.read(ws))["role"] == "owner"
    await wait_for_turns(runner, 1)
    assert runner.events[0].source.profile == "alpha"
    assert runner.events[0].source.user_id == "owner"
    assert runner.keys == [f"agent:alpha:hejo:dm:alpha:{thread}"]
    sent = await gate.send("alpha", "test response", metadata={"thread_id": thread, "hermes_profile": "alpha"})
    assert sent.success
    response = (await client.until(ws, "message"))[-1]
    assert (response["employee"], response["thread"], response["role"]) == ("alpha", thread, "employee")
    await ws.close()


async def test_at_hf_11(gate, client, runner, monkeypatch):
    """Two threads form distinct actual Hermes session keys."""
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    ws, _ = await client.pair()
    for _ in range(2):
        await client.send(ws)
        await client.until(ws, "message")
    await wait_for_turns(runner, 2)
    assert len(set(runner.keys)) == 2
    await ws.close()


async def test_at_hf_12(gate, client):
    """Typing brackets a stream; final edit is immediate and uses the same id."""
    ws, _ = await client.pair()
    thread = str(uuid.uuid4())
    await gate.send_typing("alpha", {"thread_id": thread})
    sent = await gate.send("alpha", "initial", metadata={"thread_id": thread})
    for index in range(3):
        await gate.edit_message("alpha", sent.message_id, f"partial {index}")
    await gate.edit_message("alpha", sent.message_id, "final body", finalize=True)
    await gate.stop_typing("alpha")
    frames = [await client.read(ws) for _ in range(4)]
    assert [f["type"] for f in frames] == ["typing", "message", "edit", "typing"]
    assert frames[0]["on"] is True and frames[-1]["on"] is False
    edits = [f for f in frames if f["type"] == "edit"]
    assert 1 <= len(edits) <= 3
    assert all(f["msg_id"] == sent.message_id for f in edits)
    assert edits[-1]["final"] is True and edits[-1]["text"] == "final body"
    await ws.close()


async def test_at_hf_13(gate, client):
    """Reconnect since N replays exactly the three offline frames."""
    ws, welcome = await client.pair()
    await ws.close()
    start = gate.journal.head
    for _ in range(3):
        assert (await gate.send("alpha", "offline")).success
    ws, _ = await client.open(token=welcome["token"], since=start)
    frames = await client.until(ws, "sync_done")
    assert [f["seq"] for f in frames[:-1]] == list(range(start + 1, start + 4))
    assert frames[-1]["through"] == start + 3 and frames[-1]["more"] is False
    await ws.close()


async def test_at_hf_14(gate, client):
    """A partial write never publishes; truncation restores length and sequence."""
    ws, _ = await client.pair()
    assert (await gate.send("alpha", "before")).success
    before = await client.read(ws)
    path = next(gate.journal.path.glob("*.jsonl"))
    length = path.stat().st_size
    real_write = os.write
    def broken(fd, data):
        real_write(fd, data[:13])
        raise OSError("injected write failure")
    with patch("gate.journal.os.write", side_effect=broken):
        failed = await gate.send("alpha", "must not appear")
    assert failed.success is False
    error = await client.read(ws)
    assert error["type"] == "error" and error["code"] == "journal_write_failed"
    assert path.stat().st_size == length
    assert gate.is_connected
    assert (await gate.send("alpha", "after")).success
    assert (await client.read(ws))["seq"] == before["seq"] + 1
    await ws.close()


async def seed(gate, count):
    for _ in range(count):
        assert (await gate.send("alpha", "history")).success


async def collect_pages(client, ws):
    pages, seqs = [], []
    while True:
        frames = await client.until(ws, "sync_done")
        seqs.extend(f["seq"] for f in frames[:-1])
        done = frames[-1]
        pages.append(done)
        if not done["more"]:
            return pages, seqs
        await ws.send_json({"v": 1, "type": "sync", "id": str(uuid.uuid4()), "since": done["through"]})


async def test_at_hf_32(gate, client):
    """A 1203-record backlog has the approved three page boundaries."""
    await seed(gate, 1203)
    ws, _ = await client.pair(since=0)
    pages, seqs = await collect_pages(client, ws)
    assert [p["through"] for p in pages] == [500, 1000, 1203]
    assert [p["more"] for p in pages] == [True, True, False]
    assert seqs == list(range(1, 1204))
    await ws.close()


async def test_at_hf_33(gate, client, monkeypatch):
    """Concurrent live records do not interleave with replay pages."""
    from gate.server import Connection
    await seed(gate, 1203)
    original = Connection.send
    triggered = False
    async def intercept(conn, frame):
        nonlocal triggered
        await original(conn, frame)
        if frame.get("seq") == 100 and not triggered:
            triggered = True
            await seed(gate, 20)
    monkeypatch.setattr(Connection, "send", intercept)
    ws, _ = await client.pair(since=0)
    pages, seqs = await collect_pages(client, ws)
    assert triggered
    assert seqs == list(range(1, 1224))
    assert [p["through"] for p in pages] == [500, 1000, 1223]
    assert pages[-1]["more"] is False
    await ws.close()


async def test_at_hf_34(gate, client):
    """Independent credentials see the same ordered live records."""
    first, one = await client.pair()
    second, two = await client.pair()
    assert one["device_id"] != two["device_id"]
    await seed(gate, 10)
    a = [await client.read(first) for _ in range(10)]
    b = [await client.read(second) for _ in range(10)]
    assert [f["seq"] for f in a] == [f["seq"] for f in b] == list(range(1, 11))
    await first.close()
    await second.close()


@pytest.mark.parametrize("empty_new_month", [False, True])
async def test_at_hf_35(gate, client, caplog, empty_new_month):
    """Tail repair and an empty newer month preserve the previous last sequence."""
    await seed(gate, 5)
    await gate.disconnect()
    paths = sorted(gate.journal.path.glob("*.jsonl"))
    original = paths[0]
    if empty_new_month:
        previous = original.with_name("2000-01.jsonl")
        original.rename(previous)
        original.write_bytes(b"")
    else:
        with original.open("ab") as stream:
            stream.write(b'{"seq":6,"text":')
    assert await gate.connect()
    if not empty_new_month:
        assert "journal_tail_recovered" in caplog.text
    assert (await gate.send("alpha", "new")).success
    assert gate.journal.head == 6
    ws, _ = await client.pair(since=0)
    _, seqs = await collect_pages(client, ws)
    assert seqs == [1, 2, 3, 4, 5, 6]
    await ws.close()


async def test_at_hf_36(gate, client):
    """A separate process cannot acquire the lifetime journal lock or open a listener."""
    script = '''import asyncio
from hermes_cli.plugins import PluginContext, PluginManager
from hermes_cli.plugins_manifest import PluginManifest
from gate import register
register(PluginContext(PluginManifest(name="hejo", kind="platform", source="user"), PluginManager()))
from gateway.config import PlatformConfig
from gate.adapter import HejoAdapter
async def main():
    adapter = HejoAdapter(PlatformConfig(enabled=True, extra={"port": 0}))
    assert not await adapter.connect()
    assert not adapter._fatal_error_retryable
    assert not adapter.server
asyncio.run(main())
'''
    proc = await asyncio.create_subprocess_exec(sys.executable, "-c", script, stderr=asyncio.subprocess.PIPE)
    _, err = await proc.communicate()
    assert proc.returncode == 0, err.decode()
    ws, welcome = await client.pair()
    assert welcome["type"] == "welcome"
    await ws.close()


async def test_at_hf_37(gate, client, runner, monkeypatch):
    """Real Hermes YAML bridge plus authorization admits owner and denies another list."""
    from gateway.config_loader import apply_plugin_yaml_hooks
    from gateway.platform_registry import platform_registry
    ws, _ = await client.pair()
    for turn_count, (allowed, expected) in enumerate([(["owner"], 1), (["someone"], 1)], 1):
        monkeypatch.delenv("HEJO_ALLOWED_USERS", raising=False)
        data = {"hejo": {"enabled": True, "extra": {"allowed_users": allowed}}}
        apply_plugin_yaml_hooks({}, data, data, platform_registry)
        assert os.environ["HEJO_ALLOWED_USERS"] == ",".join(allowed)
        await client.send(ws)
        await client.until(ws, "message")
        await wait_for_turns(runner, turn_count)
        assert len(runner.events) == expected
    assert len(runner.denied) == 1
    await ws.close()


async def test_at_hf_44(gate, client, monkeypatch):
    """Welcome leads concurrent records; implicit since loses none; future since closes."""
    from aiohttp import ClientSession, WSMsgType
    from gate.server import Connection
    original = Connection.send
    injected = False

    async def before_welcome(conn, frame):
        nonlocal injected
        if frame["type"] == "welcome" and not injected:
            injected = True
            assert conn.replaying
            for index in range(3):
                assert (await gate.send("alpha", f"during welcome {index}")).success
        await original(conn, frame)

    monkeypatch.setattr(Connection, "send", before_welcome)
    async with ClientSession(trust_env=False) as session:
        ws = await session.ws_connect(f"http://127.0.0.1:{gate.server.port}/v1/ws")
        await ws.send_json({"v": 1, "type": "hello", "pair_code": gate.auth.pair_code(),
                            "device_name": "Test device", "app_version": "test"})
        welcome = await client.read(ws)
        assert welcome["type"] == "welcome"
        assert injected
        frames = await client.until(ws, "sync_done")
        assert [f["seq"] for f in frames[:-1]] == list(range(welcome["head_seq"] + 1, welcome["head_seq"] + 4))
        assert frames[-1]["through"] == welcome["head_seq"] + 3
        assert frames[-1]["more"] is False
        await ws.close()
        ws = await session.ws_connect(f"http://127.0.0.1:{gate.server.port}/v1/ws")
        await ws.send_json({"v": 1, "type": "hello", "id": "future-since", "token": welcome["token"],
                            "device_name": "Test device", "app_version": "test", "since": gate.journal.head + 5})
        assert (await client.read(ws))["type"] == "welcome"
        error = await client.read(ws)
        assert error == {"v": 1, "type": "error", "code": "invalid_since", "ref": "future-since"}
        assert (await ws.receive(timeout=2)).type == WSMsgType.CLOSE
        await ws.close()


async def test_at_hf_45(gate, client):
    """Two active threads both receive off; on frames carry a six-second lifetime."""
    ws, _ = await client.pair()
    t1, t2 = str(uuid.uuid4()), str(uuid.uuid4())
    await gate.send_typing("alpha", {"thread_id": t1})
    await gate.send_typing("alpha", {"thread_id": t2})
    await gate.stop_typing("alpha")
    frames = [await client.read(ws) for _ in range(4)]
    assert [(f["type"], f["employee"], f["thread"], f["on"], f["ttl_seconds"]) for f in frames[:2]] == [
        ("typing", "alpha", t1, True, 6), ("typing", "alpha", t2, True, 6)]
    assert {(f["type"], f["employee"], f["thread"], f["on"]) for f in frames[2:]} == {
        ("typing", "alpha", t1, False), ("typing", "alpha", t2, False)}
    await ws.close()


async def test_at_hf_46(airport):
    """All four public attachment fields are required; extra fields and paths fail."""
    from jsonschema import Draft202012Validator
    from gate.server import SCHEMA
    validator = Draft202012Validator(SCHEMA)
    item = {"file_id": str(uuid.uuid4()), "name": "sample.txt", "mime": "text/plain", "size": 0}
    message = {"v": 1, "type": "message", "seq": 1, "msg_id": "sample-message", "employee": "alpha",
               "thread": str(uuid.uuid4()), "role": "employee", "text": "sample", "files": [item],
               "buttons": [], "reply_state": None, "ts": "2000-01-01T00:00:00Z"}
    assert validator.is_valid(message)
    for key in ("file_id", "name", "mime", "size"):
        assert not validator.is_valid({**message, "files": [{k: v for k, v in item.items() if k != key}]})
    assert not validator.is_valid({**message, "files": [{**item, "extra": "forbidden"}]})
    assert not validator.is_valid({**message, "files": [{**item, "name": "folder/sample.txt"}]})
    for invalid in ({"file_id": "invalid-uuid"}, {"file_id": item["file_id"] + "\n"},
                    {"name": ""}, {"name": "x" * 256},
                    {"name": "folder\\sample.txt"}, {"size": -1}, {"size": 1.5}, {"mime": 7}):
        assert not validator.is_valid({**message, "files": [{**item, **invalid}]})
    assert validator.is_valid({**message, "files": [{**item, "name": "x" * 255}]})
