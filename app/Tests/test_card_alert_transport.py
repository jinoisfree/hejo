"""Drive actual AppKit selection and history HTTP against a temporary loopback gate."""
import asyncio
import json
import os
from pathlib import Path
from uuid import uuid4

import pytest

from gate.history import HistoryError
from gate.tests.support import airport, client, gate, registered, runner
from gate.tests.test_rooms import create


ALERT_BINARY = Path(os.environ.get("HEJO_CARD_ALERT_BINARY", "app/.build/app-tests")).resolve()
ALERT_EVIDENCE = os.environ.get("HEJO_CARD_ALERT_EVIDENCE")


async def exercise(gate, client, tmp_path, scenario, entry):
    thread = str(uuid4())
    room = "alpha"
    if scenario == "group":
        socket, _ = await client.pair(features=["rooms"])
        room = await create(client, socket)
    destination = "room:" + room if scenario == "group" else room

    async def publish(text):
        await gate.send(destination, text, metadata={"hermes_profile": "alpha", "thread_id": thread})
        return str(gate.journal.head)

    expected = await publish("fixture initial alert")
    original = gate.server.history_query
    noticed = []
    hold = False
    reject = scenario == "strip-fail"
    frames = []
    receive = gate.receive

    async def observe_frame(frame, connection):
        if frame["type"] in ("send", "click", "deadline_close"):
            frames.append(frame["type"])
        return await receive(frame, connection)

    gate.receive = observe_frame
    held, release = asyncio.Event(), asyncio.Event()

    async def query(session, context, document, rooms):
        nonlocal hold
        notice = document["kind"] == "read_plan" and document["action"] == "notice"
        if hold and (notice if entry == "strip" else document["kind"] == "overview"):
            hold = False
            held.set()
            await release.wait()
        if notice:
            noticed.append(document.get("target"))
            if reject:
                raise HistoryError("state_not_ready", 409)
        return await original(session, context, document, rooms)

    gate.server.history_query = query
    environment = dict(os.environ)
    if ALERT_EVIDENCE:
        environment["HEJO_CARD_ALERT_EVIDENCE"] = ALERT_EVIDENCE
    child = await asyncio.create_subprocess_exec(
        str(ALERT_BINARY), "--card-alert", f"127.0.0.1:{gate.server.port}",
        gate.auth.pair_code(), str(tmp_path / "app"), room, thread, scenario, entry,
        stdin=asyncio.subprocess.PIPE, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
        env=environment)
    diagnostics = asyncio.create_task(child.stderr.read())
    start = 0
    failed = None
    try:
        async with asyncio.timeout(30):
            while line := await child.stdout.readline():
                row = json.loads(line)
                phase = row["phase"]
                if phase == "result":
                    break
                if phase == "failed":
                    failed = row
                    continue
                if phase == "retry":
                    reject = False
                if phase == "duplicate":
                    await held.wait()
                if phase == "hold":
                    hold = True
                if phase == "publish":
                    expected = await publish("fixture next alert while open")
                if phase == "select":
                    if scenario == "refreshing":
                        await held.wait()
                    start = len(noticed)
                    if entry == "strip":
                        hold = True
                    if scenario == "automatic":
                        assert start == 0
                if phase == "release":
                    release.set()
                child.stdin.write(b"go\n")
                await child.stdin.drain()
            assert await child.wait() == 0, (await diagnostics).decode()[-4000:]
        return row, noticed[start:], {"room": room, "thread": thread}, expected, failed, frames
    finally:
        release.set()
        if child.returncode is None:
            child.kill()
            await child.wait()
        await diagnostics


@pytest.mark.asyncio
@pytest.mark.usefixtures("runner")
@pytest.mark.parametrize("scenario", ["automatic", "new-alert", "home", "staff", "group", "refreshing"])
@pytest.mark.parametrize("entry", ["mouse", "thread", "enter"])
async def test_at_cd_18_direct_selection(gate, client, tmp_path, scenario, entry):
    row, noticed, target, expected, _, _ = await exercise(gate, client, tmp_path, scenario, entry)
    print(f"AT-CD-18 {scenario}/{entry} requests={len(noticed)} remaining={row['remaining']} "
          f"thread={row['threadRead']} bell={row['bellRead']}")
    assert noticed == [target]
    assert row["threadRead"] == row["bellRead"] == expected
    assert not row["remaining"]


@pytest.mark.asyncio
@pytest.mark.usefixtures("runner")
@pytest.mark.parametrize("scenario", ["strip", "strip-undo", "strip-fail"])
async def test_at_cd_16_and_17_strip(gate, client, tmp_path, scenario):
    row, noticed, target, expected, failed, frames = await exercise(gate, client, tmp_path, scenario, "strip")
    assert not frames, frames
    if scenario == "strip-fail":
        assert failed["failure"] and failed["remaining"]
        assert failed["threadRead"] == failed["bellRead"] == ""
        assert noticed == [target, target]
    else:
        assert noticed == [target]
    assert row["threadRead"] == row["bellRead"] == expected
    assert not row["selected"] and not row["remaining"]
    print(f"AT-CD-16/17 {scenario} PASS notice={len(noticed)}")
