"""Independent failure/contract checks beyond the plan's acceptance cases."""
import asyncio
import json
import os
from pathlib import Path
from unittest.mock import patch
import uuid
import pytest

pytestmark = pytest.mark.asyncio


async def test_schema_contract(airport):
    """Every planned frame type is present; bad versions, states and thread ids fail."""
    from jsonschema import Draft202012Validator
    from gate.server import SCHEMA, CLIENT_VALIDATOR
    Draft202012Validator.check_schema(SCHEMA)
    definitions = SCHEMA["$defs"]
    types = {v.get("properties", {}).get("type", {}).get("const") for v in definitions.values()}
    assert types >= {"hello", "welcome", "pair_rejected", "auth_rejected", "roster", "sync", "sync_done",
                     "send", "message", "edit", "delete", "typing", "state", "click", "error", "ping", "pong"}
    good = {"v": 1, "type": "send", "employee": "alpha", "text": "hello", "client_msg_id": "one"}
    assert CLIENT_VALIDATOR.is_valid(good)
    for extra in ({"v": 2}, {"thread": "bad-thread"}, {"unexpected": True}):
        assert not CLIENT_VALIDATOR.is_valid({**good, **extra})
    state = {"v": 1, "type": "state", "seq": 1, "msg_id": "one", "reply_state": "answered"}
    validator = Draft202012Validator(SCHEMA)
    assert validator.is_valid(state)
    assert not validator.is_valid({**state, "reply_state": "invalid"})


async def test_port_collision(registered, gate, airport, monkeypatch):
    """Port contention is fatal and releases the journal lock for the next start."""
    from gate.adapter import HejoAdapter
    from gateway.config import PlatformConfig
    port = gate.server.port
    # Separate journal home so the port boundary, rather than flock, rejects the start.
    with monkeypatch.context() as context:
        context.setenv("HERMES_HOME", str(airport / "other"))
        second = HejoAdapter(PlatformConfig(enabled=True, extra={"port": port}))
        assert not await second.connect()
        assert not second._fatal_error_retryable
        assert second.journal.fd is None


@pytest.mark.parametrize("rollback_fails", [False, True])
async def test_fsync_failure(gate, client, rollback_fails):
    """fsync failure restores seq/length; failed rollback seals the writer until restart."""
    from gate.journal import HejoJournalError
    ws, _ = await client.pair()
    assert (await gate.send("alpha", "before")).success
    first = await client.read(ws)
    path = next(gate.journal.path.glob("*.jsonl"))
    size = path.stat().st_size
    real_sync = os.fsync
    calls = 0
    def broken(fd):
        nonlocal calls
        calls += 1
        if calls == 1 or rollback_fails:
            raise OSError("injected fsync failure")
        real_sync(fd)
    with patch("gate.journal.os.fsync", side_effect=broken):
        assert not (await gate.send("alpha", "failed")).success
    assert (await client.read(ws))["code"] == "journal_write_failed"
    assert path.stat().st_size == size
    assert gate.journal.head == first["seq"]
    assert gate.journal.faulted is rollback_fails
    result = await gate.send("alpha", "next")
    assert result.success is not rollback_fails
    await ws.close()


async def test_truncate_failure(gate, client):
    """A failed ftruncate refuses future writes and recovers only on restart."""
    real_write = os.write
    def partial(fd, data):
        real_write(fd, data[:7])
        raise OSError("write failure")
    with patch("gate.journal.os.write", side_effect=partial), patch("gate.journal.os.ftruncate", side_effect=OSError("truncate failure")):
        assert not (await gate.send("alpha", "failure")).success
    assert gate.journal.head == 0 and gate.journal.faulted
    assert not (await gate.send("alpha", "refused")).success
    await gate.disconnect()
    assert await gate.connect()
    assert (await gate.send("alpha", "restored")).success
    assert gate.journal.head == 1


@pytest.mark.parametrize("sequence", [[1, 1], [2, 1]])
async def test_corrupt_sequence_refuses_listener(registered, airport, sequence):
    """Duplicate/reversed durable seq must never be silently repaired."""
    from gate.adapter import HejoAdapter
    from gateway.config import PlatformConfig
    root = airport / "shared" / "hejo" / "journal"
    root.mkdir(parents=True)
    rows = [{"v": 1, "type": "delete", "seq": seq, "msg_id": "test"} for seq in sequence]
    (root / "2000-01.jsonl").write_text("".join(json.dumps(r) + "\n" for r in rows))
    gate = HejoAdapter(PlatformConfig(enabled=True, extra={"port": 0}))
    assert not await gate.connect()
    assert gate.server is None and not gate._fatal_error_retryable
    assert (root / "2000-01.jsonl").read_text() == "".join(json.dumps(r) + "\n" for r in rows)


async def test_reply_hooks(gate, client, runner, monkeypatch):
    """Metadata survives restart, edit signature stays compatible, clicks use normalized ingress."""
    from gate.tests.support import wait_for_turns
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    thread = str(uuid.uuid4())
    sent = await gate.send("alpha", "question", metadata={"thread_id": thread, "hejo_buttons": [
        {"label": "Accept", "style": "primary"}, {"label": "Decline", "style": "danger"}], "hejo_reply_state": "asked"})
    assert sent.success
    await gate.disconnect()
    assert await gate.connect()
    # The turn stub is still the real adapter's callback after reconnect.
    ws, _ = await client.pair(since=0)
    frames = await client.until(ws, "sync_done")
    message = frames[0]
    assert "_meta" not in message and message["reply_state"] == "asked"
    assert [b["label"] for b in message["buttons"]] == ["Accept", "Decline"]
    assert all(b["kind"] == "reply" for b in message["buttons"])
    observed = []
    async def handler(click):
        observed.append(click)
        await gate.set_reply_state(click["msg_id"], "answered")
        return False
    gate.register_click_handler("reply", handler)
    await ws.send_json({"v": 1, "type": "click", "msg_id": sent.message_id,
                        "button_id": message["buttons"][0]["id"]})
    frames = await client.until(ws, "message")
    assert [f["type"] for f in frames] == ["state", "message"]
    await wait_for_turns(runner, 1)
    event = runner.events[0]
    assert event.text == "Accept" and event.source.thread_id == thread and event.source.profile == "alpha"
    assert event.raw_message == {"_hermes_button": {"label": "Accept", "message_id": sent.message_id, "message_text": "question"}}
    assert set(observed[0]) == {"msg_id", "button_id", "label", "employee", "thread", "message_text"}
    await gate.edit_message("alpha", sent.message_id, "changed", finalize=True,
                            metadata={"hejo_buttons": [{"label": "Done", "style": "default"}]})
    edited = (await client.until(ws, "edit"))[-1]
    assert edited["buttons"][0]["label"] == "Done"
    await ws.close()


async def test_state_fsync_order_and_failure(gate, client):
    """set_reply_state returns only after durable append and raises on commit failure."""
    from gate.journal import HejoJournalError
    sent = await gate.send("alpha", "question")
    ws, _ = await client.pair()
    assert await gate.set_reply_state(sent.message_id, "asked") is None
    row = json.loads(next(gate.journal.path.glob("*.jsonl")).read_text().splitlines()[-1])
    assert row["type"] == "state" and row["reply_state"] == "asked"
    await client.read(ws)
    await asyncio.gather(gate.set_reply_state(sent.message_id, "answered"), gate.set_reply_state(sent.message_id, "closed"))
    assert [(await client.read(ws))["reply_state"] for _ in range(2)] == ["answered", "closed"]
    before = gate.journal.head
    with patch("gate.journal.os.write", side_effect=OSError("failed")):
        with pytest.raises(HejoJournalError):
            await gate.set_reply_state(sent.message_id, "closed")
    error = await client.read(ws)
    assert error["type"] == "error" and gate.journal.head == before
    await ws.close()


async def test_bad_frames_are_isolated(gate, client):
    """Malformed, too-large and unknown-employee inputs leave the adapter running."""
    ws, _ = await client.pair()
    for body in ("not-json", json.dumps({"v": 2, "type": "roster", "id": "bad"})):
        await ws.send_str(body)
        assert (await client.read(ws))["code"] == "invalid_frame"
    await client.send(ws, text="x" * 65537, id="large-text")
    error = await client.read(ws)
    assert (error["code"], error["ref"]) == ("too_large", "large-text")
    await client.send(ws, employee="not-a-profile")
    assert (await client.read(ws))["code"] == "unknown_employee"
    try:
        await ws.send_str("x" * 1048577)
    except ConnectionError:
        # The parser may reject the advertised size before the sender drains its body.
        pass
    assert (await client.read(ws))["code"] == "too_large"
    assert gate.is_connected
    await ws.close()


async def test_sync_queue_overflow(gate, airport):
    """Overflow forces another replay request without a premature live frame."""
    from gate.server import Connection
    class Sink:
        closed = False
        def __init__(self):
            self.frames = []
        async def send_json(self, frame):
            self.frames.append(frame)
    sink = Sink()
    conn = Connection(sink, "fake-device", replaying=True)
    gate.server.connections.add(conn)
    try:
        for seq in range(1, 2002):
            await gate.server.broadcast({"v": 1, "type": "delete", "seq": seq, "msg_id": "test"})
        assert conn.overflow and not conn.queue and not sink.frames
    finally:
        gate.server.connections.remove(conn)


async def test_hello_deadline(gate):
    """A real idle websocket receives the five-second hello timeout and closes."""
    from aiohttp import ClientSession, WSMsgType
    from gate.server import LIMITS
    assert LIMITS["hello_seconds"] == 5
    async with ClientSession(trust_env=False) as session:
        ws = await session.ws_connect(f"http://127.0.0.1:{gate.server.port}/v1/ws")
        error = await ws.receive_json(timeout=7)
        assert error["code"] == "hello_timeout"
        assert (await ws.receive(timeout=2)).type == WSMsgType.CLOSE


async def test_unreadable_auth_store_fails_closed(gate, client, monkeypatch):
    """Credential read errors close admitted sockets instead of killing the revocation poller."""
    from aiohttp import WSMsgType
    ws, _ = await client.pair()
    monkeypatch.setattr(gate.auth, "devices", lambda: (_ for _ in ()).throw(OSError("unavailable")))
    assert (await ws.receive(timeout=2)).type == WSMsgType.CLOSE
    assert not next(iter(gate.server.tasks)).done()
    await ws.close()


async def test_yaml_env_precedence(registered, monkeypatch):
    """Explicit environment policy keeps precedence over the YAML bridge."""
    from gate import apply_yaml_config
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "someone")
    result = apply_yaml_config({}, {"extra": {"allowed_users": ["owner"]}})
    assert result == {"allowed_users": ["owner"]}
    assert os.environ["HEJO_ALLOWED_USERS"] == "someone"


async def test_secondary_with_independent_home_never_listens(gate, airport, monkeypatch):
    """Secondary exclusion precedes both flock and bind, even with a free home and port."""
    from gate.adapter import HejoAdapter
    second = HejoAdapter(gate.config)
    second.set_owner_profile("beta")
    try:
        with monkeypatch.context() as context:
            context.setenv("HERMES_HOME", str(airport / "other"))
            assert not await second.connect()
        assert not second._fatal_error_retryable
    finally:
        await second.disconnect()


async def test_journal_open_failure_isolated(gate, client):
    """A failed monthly-file open produces the same durable-write error without stopping the adapter."""
    ws, _ = await client.pair()
    with patch("gate.journal.os.open", side_effect=PermissionError("read only")):
        assert not (await gate.send("alpha", "failure")).success
    assert (await client.read(ws))["code"] == "journal_write_failed"
    assert gate.is_connected and gate.journal.head == 0
    assert (await gate.send("alpha", "next")).success
    assert (await client.read(ws))["seq"] == 1
    await ws.close()
