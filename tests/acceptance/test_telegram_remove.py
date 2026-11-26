"""Acceptance coverage for the removed platform and the remaining wire contract."""
import asyncio
from contextlib import contextmanager
import json
import os
from pathlib import Path
import subprocess
import sys
import uuid

from aiohttp import ClientSession
import pytest


ROOT = Path(__file__).resolve().parents[2]
SCHEMA = "schemas/hejo-wire-v1.json"
BASELINE = "c22e6774604398f84351d69dd926ba3510d31aa2"
LEGACY_REQUESTS = ("telegram", "telegram_pair", "telegram_unpair", "telegram_save")
LEGACY_DEFINITIONS = {*LEGACY_REQUESTS, "telegram_status", "telegram_code"}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def test_at_htr_01_registration(registered):
    from gateway.platform_registry import platform_registry
    from gate import create_adapter

    assert len(registered.get_platform_handler_factories("telegram")) == 0
    assert len(registered.get_platform_handler_factories("discord")) == 1
    hejo = [entry for entry in platform_registry.all_entries() if entry.name == "hejo"]
    assert len(hejo) == 1 and hejo[0].adapter_factory is create_adapter


def test_at_htr_02_tracked_sources():
    excluded = {"tests/acceptance/HEJO-TELEGRAM-REMOVE.md",
                "tests/acceptance/test_telegram_remove.py"}
    excluded_dirs = ("docs/changes/",)
    remaining = []
    for item in git("ls-files", "-z").split(b"\0"):
        path = os.fsdecode(item)
        if not path or path in excluded or path.startswith(excluded_dirs):
            continue
        source = ROOT / path
        data = os.fsencode(os.readlink(source)) if source.is_symlink() else source.read_bytes()
        for marker in (b"HEJO-TELEGRAM-REMOVE", b"HEJO-TELEGRAM", b"platform.telegram."):
            data = data.replace(marker, b"")
        remaining.extend(f"{path}:{number}" for number, line in enumerate(data.splitlines(), 1)
                         if b"telegram" in line.lower())
    assert remaining == []
    for path in ("gate/telegram.py", "gate/telegram_comments.py", "app/Sources/TelegramState.swift"):
        assert not os.path.lexists(ROOT / path), path


def snapshot(vault, shared):
    paths = [vault, shared, *sorted(shared.rglob("*"))]
    return {path: (path.stat().st_mtime_ns, path.read_bytes() if path.is_file() else None)
            for path in paths if path.exists()}


@contextmanager
def observe_legacy_access(vault, shared, monkeypatch):
    events, legacy_events = [], []
    observed = {"open", "os.listdir", "os.scandir", "os.stat", "os.lstat"}
    active = True

    def audit(event, args):
        if active and event in observed and isinstance(args[0], (str, bytes, os.PathLike)):
            path = Path(os.path.abspath(os.fsdecode(args[0])))
            events.append(event)
            if path == vault or path.is_relative_to(shared):
                legacy_events.append((event, path))

    sys.addaudithook(audit)
    try:
        with monkeypatch.context() as patch:
            # CPython audits enumeration and open. Report metadata probes to the
            # same audit hook because stat and lstat don't emit built-in events.
            def instrument(name):
                original = getattr(os, name)

                def observe(path, *args, **kwargs):
                    sys.audit(f"os.{name}", path)
                    return original(path, *args, **kwargs)

                patch.setattr(os, name, observe)

            instrument("stat")
            instrument("lstat")
            yield events, legacy_events
    finally:
        active = False


@pytest.mark.asyncio
@pytest.mark.parametrize("with_legacy_data", [True, False])
async def test_at_htr_03_gate_ignores_legacy_data(airport, registered, monkeypatch, with_legacy_data):
    from gateway.config import PlatformConfig
    from gate.adapter import HejoAdapter

    home = airport.resolve()
    vault, shared = home / "hejo/telegram.json", home / "shared/hejo/telegram"
    if with_legacy_data:
        vault.parent.mkdir(parents=True, exist_ok=True)
        vault.touch(mode=0o600)
        vault.write_text("fixture vault\n")
        shared.mkdir(parents=True)
        for name in ("settings.json", "topics.json"):
            (shared / name).write_text("fixture shared data\n")
    before = snapshot(vault, shared)
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    adapter = HejoAdapter(PlatformConfig(enabled=True, extra={"listen": ["127.0.0.1"], "port": 0}))
    employees = adapter.employees
    names = {"default": "Main", "alpha": "Alpha", "beta": "Beta"}
    monkeypatch.setattr(adapter, "employees", lambda: [{**e, "name": names[e["id"]]} for e in employees()])
    thread = str(uuid.uuid4())

    async def respond(event):
        assert event.text == "fixture request"
        sent = await adapter.send("alpha", "fixture reply", metadata={"thread_id": thread})
        assert sent.success

    with observe_legacy_access(vault, shared, monkeypatch) as (events, legacy_events):
        assert await adapter.connect()
        try:
            adapter.set_message_handler(respond)
            async with ClientSession(trust_env=False) as session:
                async with session.ws_connect(f"http://127.0.0.1:{adapter.server.port}/v1/ws") as ws:
                    await ws.send_json({"v": 1, "type": "hello", "device_name": "Test device",
                                        "app_version": "test", "pair_code": adapter.auth.pair_code()})
                    assert (await ws.receive_json(timeout=5))["type"] == "welcome"
                    assert (await ws.receive_json(timeout=5))["type"] == "sync_done"
                    await ws.send_json({"v": 1, "type": "send", "employee": "alpha", "thread": thread,
                                        "id": "round-trip", "client_msg_id": str(uuid.uuid4()),
                                        "text": "fixture request"})
                    request = await ws.receive_json(timeout=5)
                    assert (request["role"], request["text"], request["thread"]) == ("owner", "fixture request", thread)
                    async with asyncio.timeout(5):
                        while True:
                            reply = await ws.receive_json()
                            if reply["type"] == "message":
                                break
                            assert reply["type"] != "error", reply
                    assert (reply["role"], reply["text"], reply["thread"]) == ("employee", "fixture reply", thread)
        finally:
            await adapter.disconnect()
    assert events and not legacy_events
    assert snapshot(vault, shared) == before
    if not with_legacy_data:
        assert not shared.exists()


def test_at_htr_04_schema_only_removes_legacy_definitions():
    text = (ROOT / SCHEMA).read_text()
    current = json.loads(text)
    baseline = json.loads(git("show", f"{BASELINE}:{SCHEMA}"))
    assert {name for name in baseline["$defs"] if name.startswith("telegram")} == LEGACY_DEFINITIONS
    for name in LEGACY_DEFINITIONS:
        del baseline["$defs"][name]
    refs = {f"#/$defs/{name}" for name in LEGACY_DEFINITIONS}
    for union in (baseline, baseline["$defs"]["clientFrame"], baseline["$defs"]["serverFrame"]):
        union["oneOf"] = [entry for entry in union["oneOf"] if entry.get("$ref") not in refs]
    assert current == baseline
    assert not any(name.startswith("telegram") for name in current["$defs"])
    assert '"#/$defs/telegram' not in text


@pytest.mark.asyncio
async def test_at_htr_05_old_requests_rejected_on_the_same_socket(client, gate):
    ws, _ = await client.pair(features=["discord"])
    before = gate.journal.head, tuple(gate.journal.records)
    for kind in LEGACY_REQUESTS:
        ref = f"x-{kind}"
        frame = {"v": 1, "type": kind, "id": ref}
        if kind == "telegram_save":
            frame["enabled"] = True
        await ws.send_json(frame)
        assert await client.read(ws) == {"v": 1, "type": "error", "code": "unexpected_frame", "ref": ref}
    await ws.send_json({"v": 1, "type": "discord", "id": "dc-after"})
    frame = await client.read(ws)
    assert (frame["type"], frame["ref"], ws.closed) == ("discord_status", "dc-after", False)
    assert (gate.journal.head, tuple(gate.journal.records)) == before


@pytest.mark.asyncio
async def test_at_htr_06_old_feature_list_can_pair(client):
    ws, welcome = await client.pair(features=["rooms", "telegram", "discord"])
    assert welcome["type"] == "welcome" and welcome["token"]
    await ws.send_json({"v": 1, "type": "discord", "id": "dc-legacy-features"})
    frame = await client.read(ws)
    assert (frame["type"], frame["ref"]) == ("discord_status", "dc-legacy-features")


def test_at_htr_07_journal_record_types():
    from gate.journal import RECORD_TYPES

    assert RECORD_TYPES == {"message", "edit", "delete", "state", "room", "room_delete"}


def test_at_htr_08_adapter_removes_external_claims(gate):
    assert not hasattr(type(gate), "claims_external")
    assert not hasattr(gate, "telegram")


def test_at_htr_30_retired_tests_and_evidence_removed():
    for path in ("tests/acceptance/test_telegram.py", "tests/acceptance/HEJO-TELEGRAM.md",
                 "app/Tests/TelegramTests.swift", "gate/tests/telegram_settling.py",
                 "gate/tests/test_telegram_comments.py", "evidence/HEJO-TELEGRAM"):
        assert not os.path.lexists(ROOT / path), path
