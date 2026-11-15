"""Attachment failure/ownership boundaries and forwarder lifetime contracts."""
import asyncio
import os
from pathlib import Path
import uuid
from unittest.mock import patch
import pytest
from gate.files import UnknownFile
from gate.journal import HejoJournalError
from gate.tests.extension_support import upload, get

pytestmark = pytest.mark.asyncio


async def test_inbound_file_rollback_after_journal_failure(gate, client):
    info, headers = await upload(gate)
    ws, _ = await client.pair()
    with patch.object(gate.journal, "append", side_effect=HejoJournalError("disk full")):
        await client.send(ws, files=[info["file_id"]])
        assert (await client.read(ws))["code"] == "journal_write_failed"
    assert gate.journal.head == 0
    assert gate.files.pending("alpha", info["file_id"]).is_dir()
    assert not (gate.files.root / info["file_id"]).exists()
    assert (await get(gate, "files/alpha/" + info["file_id"], headers))[0] == 404
    await client.send(ws, files=[info["file_id"]])
    assert (await client.read(ws))["files"] == [info]
    await ws.close()


async def test_download_symlink_and_pending_traversal(gate, client, airport):
    info, headers = await upload(gate)
    for employee, identity in (("../alpha", info["file_id"]), ("alpha", "../escape")):
        with pytest.raises(UnknownFile):
            gate.files.pending(employee, identity)
    ws, _ = await client.pair()
    await client.send(ws, files=[info["file_id"]])
    await client.read(ws)
    stored = gate.files.root / info["file_id"] / info["name"]
    stored.unlink()
    target = airport / "private-fixture.txt"
    target.write_text("must not leak")
    stored.symlink_to(target)
    assert (await get(gate, "files/alpha/" + info["file_id"], headers))[0] == 404
    await ws.close()


async def test_stage_limit_is_50_mib_and_failed_write_leaves_no_item(gate):
    async def over_limit():
        for _ in range(801):
            yield b"x" * 65536
    with pytest.raises(ValueError, match="too_large"):
        await gate.files.stage("alpha", "large.bin", over_limit())
    assert list((gate.files.root / ".pending" / "alpha").iterdir()) == []


async def test_orphan_cleanup_preserves_registered_and_recent_pending(gate, client):
    registered, _ = await upload(gate)
    pending, _ = await upload(gate)
    orphan = gate.files.root / str(uuid.uuid4())
    orphan.mkdir()
    (orphan / "orphan.txt").write_text("uncommitted")
    ws, _ = await client.pair()
    await client.send(ws, files=[registered["file_id"]])
    await client.read(ws)
    await ws.close()
    await gate.disconnect()
    assert await gate.connect()
    assert not orphan.exists()
    assert (gate.files.root / registered["file_id"]).is_dir()
    assert gate.files.pending("alpha", pending["file_id"]).is_dir()


async def test_forwarder_rebind_and_image_and_missing_hub(gate, client, airport, caplog):
    from gate.adapter import HejoAdapter
    second = HejoAdapter(gate.config)
    second.set_owner_profile("beta")
    assert await second.connect()
    await gate.disconnect()
    for call in (second.send("alpha", "lost"), second.edit_message("alpha", "missing", "lost"),
                 second.send_typing("alpha"), second.stop_typing("alpha"),
                 second.send_document("alpha", "unopened.txt")):
        result = await call
        assert not result.success and result.error == "hejo_primary_unavailable"
    assert "hejo_primary_unavailable" in caplog.text
    assert await gate.connect()
    ws, _ = await client.pair()
    image = airport / "image.png"
    image.write_bytes(b"fixture image")
    result = await second.send_image_file("alpha", str(image), metadata={"hermes_profile": "alpha"})
    assert result.success, result.error
    frame = await client.read(ws)
    assert frame["employee"] == "beta" and frame["files"][0]["mime"] == "image/png"
    await second.set_reply_state(frame["msg_id"], "closed")
    assert (await client.read(ws))["reply_state"] == "closed"
    await ws.close()
    await second.disconnect()


async def test_avatar_is_absent_and_upload_auth_required(gate, client):
    ws, welcome = await client.pair()
    assert all(e["avatar"] is None for e in welcome["employees"])
    assert (await get(gate, "avatars/alpha"))[0] == 404
    from aiohttp import ClientSession
    async with ClientSession(trust_env=False) as session:
        async with session.post(f"http://127.0.0.1:{gate.server.port}/v1/files?employee=alpha") as response:
            assert response.status == 401
    await ws.close()


async def test_forwarder_edit_rejects_other_employee_before_dispatch(gate):
    """A foreign/missing message never reaches the primary edit method or journal."""
    from gate.adapter import HejoAdapter
    second = HejoAdapter(gate.config)
    second.set_owner_profile("beta")
    assert await second.connect()
    try:
        foreign = await gate.send("alpha", "original alpha")
        owned = await second.send("alpha", "original beta")
        assert foreign.success and owned.success
        head = gate.journal.head
        with patch.object(gate, "edit_message", wraps=gate.edit_message) as dispatch:
            for message_id in (foreign.message_id, str(uuid.uuid4())):
                result = await second.edit_message("alpha", message_id, "must not edit", finalize=True,
                                                   metadata={"hermes_profile": "alpha"})
                assert result.success is False and result.error == "message_not_found"
            dispatch.assert_not_awaited()
            assert gate.journal.head == head
            assert gate.journal.message(foreign.message_id)["text"] == "original alpha"
            assert gate.journal.message(owned.message_id)["text"] == "original beta"
            result = await second.edit_message("alpha", owned.message_id, "edited beta", finalize=True,
                                               metadata={"hermes_profile": "alpha"})
            assert result.success
            dispatch.assert_awaited_once()
        assert gate.journal.head == head + 1
        assert gate.journal.message(owned.message_id)["text"] == "edited beta"
        assert gate.journal.message(owned.message_id)["employee"] == "beta"
    finally:
        await second.disconnect()
