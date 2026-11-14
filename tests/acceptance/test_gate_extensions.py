"""AT-HF-15..18,21,49..51 translated from the approved acceptance specification."""
import asyncio
import os
from pathlib import Path
import time
import uuid
from unittest.mock import patch, AsyncMock
import pytest
from aiohttp import ClientSession, FormData
from gateway.platforms.base import ExecApprovalPrompt
from gate.adapter import HejoAdapter
from gate.tests.support import wait_for_turns
from gate.tests.extension_support import upload, get

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def allow_owner(airport):
    from gate import apply_yaml_config
    previous = os.environ.pop("HEJO_ALLOWED_USERS", None)
    try:
        apply_yaml_config({}, {"extra": {"allowed_users": ["owner"]}})
        yield
    finally:
        if previous is None:
            os.environ.pop("HEJO_ALLOWED_USERS", None)
        else:
            os.environ["HEJO_ALLOWED_USERS"] = previous




async def test_at_hf_15(gate, client, runner):
    info, _ = await upload(gate)
    ws, _ = await client.pair()
    await client.send(ws, files=[info["file_id"]])
    message = await client.read(ws)
    await wait_for_turns(runner, 1)
    event = runner.events[0]
    assert event.media_urls == [str(gate.files.root / info["file_id"] / "sample.png")]
    assert event.media_types == ["image/png"]
    assert Path(event.media_urls[0]).read_bytes() == b"fixture image"
    assert message["files"] == [info]
    await ws.close()


async def test_at_hf_16(gate, client, runner):
    info, headers = await upload(gate, "beta")
    ws, _ = await client.pair()
    await client.send(ws, employee="beta", files=[info["file_id"]])
    await client.read(ws)
    assert (await get(gate, "files/alpha/" + str(uuid.uuid4()), headers))[0] == 404
    assert (await get(gate, "files/alpha/..%2F..%2Fx", headers))[0] == 404
    assert (await get(gate, "files/beta/" + info["file_id"]))[0] == 401
    assert (await get(gate, "files/alpha/" + info["file_id"], headers))[0] == 404
    assert await get(gate, "files/beta/" + info["file_id"], headers) == (200, b"fixture image")
    await ws.close()


def approval():
    return ExecApprovalPrompt("alpha", "fixture-session", "Run fixture command?",
        [("Approve", "once", "primary"), ("Deny", "deny", "danger")], "fixture", "", False)


async def click(ws, message, index=0):
    await ws.send_json({"v": 1, "type": "click", "msg_id": message["msg_id"],
                       "button_id": message["buttons"][index]["id"]})


async def test_at_hf_17(gate, client):
    ws, _ = await client.pair()
    with patch("tools.approval.resolve_gateway_approval", return_value=1) as resolve_approval, \
         patch("tools.clarify_gateway.resolve_gateway_clarify", return_value=True) as resolve_clarify, \
         patch("tools.slash_confirm.resolve", new_callable=AsyncMock, return_value="done") as resolve_slash:
        await gate._send_exec_approval_prompt(approval())
        await click(ws, await client.read(ws))
        await gate.send_clarify("alpha", "Choose", ["First", "Second"], "fixture-clarify", "fixture-session")
        await click(ws, await client.read(ws))
        await gate.send_slash_confirm("alpha", "Confirm", "Reload?", "fixture-session", "fixture-confirm")
        await click(ws, await client.read(ws))
        # Round trip a request after clicks so dispatch is known to have completed.
        await ws.send_json({"v": 1, "type": "roster", "id": "barrier"})
        assert (await client.read(ws))["ref"] == "barrier"
        resolve_approval.assert_called_once_with("fixture-session", "once")
        resolve_clarify.assert_called_once_with("fixture-clarify", "First")
        resolve_slash.assert_awaited_once_with("fixture-session", "fixture-confirm", "once")
    await ws.close()


async def test_at_hf_18(gate, client, runner):
    ws, _ = await client.pair()
    await gate._send_exec_approval_prompt(approval())
    message = await client.read(ws)
    with patch("tools.approval.resolve_gateway_approval", return_value=0) as resolve, \
         patch("tools.clarify_gateway.resolve_gateway_clarify") as other:
        await click(ws, message)
        assert (await client.read(ws))["code"] == "button_expired"
        resolve.assert_called_once_with("fixture-session", "once")
        other.assert_not_called()
        assert runner.events == []
    await ws.close()


async def test_at_hf_21(gate, client):
    ws, _ = await client.pair()
    await gate.send("alpha", "검토해줘\n[[버튼: 승인 | 거절]]")
    message = await client.read(ws)
    assert message["buttons"] == []
    assert message["text"].endswith("승인 / 거절")
    await ws.close()


async def test_at_hf_49(gate, client, airport):
    second = HejoAdapter(gate.config)
    second.set_owner_profile("beta")
    assert await second.connect()
    ws, _ = await client.pair()
    thread = str(uuid.uuid4())
    hostile = {"hermes_profile": "alpha", "thread_id": thread}
    result = await second.send("alpha", "forwarded", metadata=hostile)
    message = await client.read(ws)
    assert message["employee"] == "beta" and message["thread"] == thread
    assert (await second.edit_message("alpha", result.message_id, "edited", finalize=True)).success
    edit = await client.read(ws)
    assert edit["type"] == "edit" and edit["msg_id"] == message["msg_id"]
    assert gate.journal.message(edit["msg_id"])["employee"] == "beta"
    await second.send_typing("alpha", hostile)
    assert (await client.read(ws))["employee"] == "beta"
    await second.stop_typing("alpha")
    assert (await client.read(ws))["employee"] == "beta"
    await second.send("alpha", "choose", metadata={**hostile, "hejo_buttons": [{"label": "Yes", "style": "primary"}]})
    button_message = await client.read(ws)
    assert button_message["employee"] == "beta" and button_message["buttons"][0]["label"] == "Yes"
    source = airport / "sample.png"
    source.write_bytes(b"fixture image")
    sent = await second.send_document("alpha", str(source), metadata=hostile)
    assert sent.success, sent.error
    file_message = await client.read(ws)
    assert file_message["employee"] == "beta" and len(file_message["files"]) == 1
    assert file_message["files"][0]["mime"] == "image/png"
    for row in gate.journal.records:
        if row["type"] == "message":
            assert row["employee"] == "beta"
    await ws.close()
    await second.disconnect()


async def test_at_hf_50(registered, airport, caplog):
    from gateway.config import PlatformConfig
    second = HejoAdapter(PlatformConfig(enabled=True, extra={"role": "forwarder"}))
    second.set_owner_profile("beta")
    assert await second.connect()
    result = await second.send("alpha", "must not send")
    assert result.success is False and result.error == "hejo_primary_unavailable"
    assert "hejo_primary_unavailable" in caplog.text
    assert not list(airport.glob("shared/hejo/journal/*.jsonl"))
    assert second.server is None and second.journal is None
    await second.disconnect()


async def test_at_hf_51(gate, client, runner):
    info, headers = await upload(gate)
    assert (await get(gate, "files/alpha/" + info["file_id"], headers))[0] == 404
    ws, _ = await client.pair()
    head = gate.journal.head
    await client.send(ws, employee="beta", files=[info["file_id"]])
    assert (await client.read(ws))["code"] == "unknown_file"
    assert gate.journal.head == head and runner.events == []
    await ws.close()
    await gate.disconnect()
    assert await gate.connect()
    gate.set_message_handler(runner.handle)
    ws, _ = await client.pair()
    await client.send(ws, files=[info["file_id"]])
    message = await client.read(ws)
    assert message["role"] == "owner" and message["files"] == [info]
    assert await get(gate, "files/alpha/" + info["file_id"], headers) == (200, b"fixture image")
    old, _ = await upload(gate)
    directory = gate.files.pending("alpha", old["file_id"])
    os.utime(directory, (time.time() - 25 * 3600,) * 2)
    await ws.close()
    await gate.disconnect()
    assert await gate.connect()
    assert not directory.exists()
