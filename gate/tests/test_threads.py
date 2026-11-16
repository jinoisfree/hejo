"""AT75/76: commit-point deletion, continuous redacted replay, branch context and metadata."""
import asyncio
from unittest.mock import patch
import uuid
import pytest
from gate.tests.support import airport, registered, gate, client, runner
from gate.journal import HejoJournalError
from gate.context import conversation_lines


def request(kind, thread, **fields):
    return {"v": 1, "type": kind, "id": str(uuid.uuid4()), "room": "alpha", "thread": thread, **fields}


@pytest.mark.asyncio
async def test_at75_delete_commit_failure_redaction_reconnect_and_late_output(gate, client, runner, tmp_path, caplog):
    ws, welcome = await client.pair()
    thread = str(uuid.uuid4())
    first = await gate.send("alpha", "private first", metadata={"thread_id": thread})
    second = await gate.send("alpha", "private second", metadata={"thread_id": thread})
    await client.read(ws); await client.read(ws)
    original = gate.journal.append
    async def failure(frame, internal=None):
        if frame.get("scope") == "thread":
            raise HejoJournalError("journal_write_failed")
        return await original(frame, internal)
    head = gate.journal.head
    with patch.object(gate.journal, "append", side_effect=failure):
        await ws.send_json(request("thread_delete", thread))
        assert (await client.read(ws))["code"] == "journal_write_failed"
    assert gate.journal.head == head and gate.journal.message(first.message_id)
    # A queued streaming edit must also be dropped if the scope commits before its flush.
    await gate.edit_message("alpha", second.message_id, "late edit")
    await ws.send_json(request("thread_delete", thread))
    point = await client.read(ws)
    assert point["type"] == "delete" and point["scope"] == "thread" and point["msg_id"] == first.message_id
    assert (await client.read(ws))["msg_id"] == second.message_id
    assert gate.journal.message(first.message_id) is None
    after = gate.journal.head
    assert not (await gate.send("alpha", "late", reply_to=first.message_id)).success
    assert not (await gate.edit_message("alpha", second.message_id, "late", finalize=True)).success
    await gate.set_reply_state(first.message_id, "answered")
    await gate.send_typing("alpha", {"thread_id": thread})
    await asyncio.sleep(.55)
    assert gate.journal.head == after and "thread_deleted_drop" in caplog.text
    source = tmp_path / "late.txt"; source.write_text("late attachment")
    assert not (await gate.send_document("alpha", str(source), metadata={"thread_id": thread})).success
    await ws.send_json({"v": 1, "type": "send", "employee": "alpha", "thread": thread,
                        "text": "rejected", "client_msg_id": str(uuid.uuid4())})
    assert (await client.read(ws))["code"] == "thread_deleted" and not runner.events
    page = gate.journal.page(0)
    assert [row["seq"] for row in page] == list(range(1, after + 1))
    assert all(row["type"] == "delete" and "text" not in row and "files" not in row and "buttons" not in row for row in page)
    replay, _ = await client.open(token=welcome["token"], since=0)
    rows = [await client.read(replay) for _ in range(after)]
    assert rows == page and (await client.read(replay))["more"] is False
    await ws.send_json(request("thread_delete", thread))
    assert (await client.read(ws))["seq"] == point["seq"] and gate.journal.head == after


@pytest.mark.asyncio
async def test_at75_restart_finishes_missing_deletes_and_exclusive_files(gate, tmp_path):
    class Sink:
        async def send(self, row): pass
    thread, other = str(uuid.uuid4()), str(uuid.uuid4())
    a = tmp_path / "exclusive.txt"; a.write_text("exclusive")
    b = tmp_path / "shared.txt"; b.write_text("shared")
    exclusive = await gate.send_document("alpha", str(a), metadata={"thread_id": thread})
    shared = await gate.send_document("alpha", str(b), metadata={"thread_id": thread})
    row = gate.journal.message(shared.message_id)
    # Another committed message refers to the same attachment: deletion must retain it.
    await gate.send("alpha", "survives", metadata={"thread_id": other, "_hejo_files": row["files"], "_hejo_file_registration": row["_meta"]["files"]})
    exclusive_id = gate.journal.message(exclusive.message_id)["files"][0]["file_id"]
    shared_id = row["files"][0]["file_id"]
    original = gate.journal.append
    async def fail_tail(frame, internal=None):
        if frame["type"] == "delete" and "scope" not in frame:
            raise HejoJournalError("journal_write_failed")
        return await original(frame, internal)
    with patch.object(gate.journal, "append", side_effect=fail_tail):
        await gate.thread_delete(request("thread_delete", thread), Sink())
    assert gate.journal.deleted("alpha", thread)
    await gate.disconnect()
    assert await gate.connect()
    deletes = [r for r in gate.journal.records if r["type"] == "delete"]
    assert {r["msg_id"] for r in deletes} == {exclusive.message_id, shared.message_id}
    assert not (gate.files.root / exclusive_id).exists() and (gate.files.root / shared_id).is_dir()
    head = gate.journal.head
    await gate.disconnect(); assert await gate.connect()
    assert gate.journal.head == head and gate.files.registered("alpha", shared_id)


@pytest.mark.asyncio
async def test_at75_branch_snapshot_idempotence_and_first_owner_only(gate, client, runner, monkeypatch):
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    ws, _ = await client.pair()
    thread = str(uuid.uuid4())
    await gate.send("alpha", "원래 제목\n본문", metadata={"thread_id": thread})
    await gate.send("alpha", "생각 중...", metadata={"thread_id": thread})
    await client.read(ws); await client.read(ws)
    removed = await gate.send("alpha", "deleted before branch", metadata={"thread_id": thread})
    await client.read(ws)
    await gate._record({"type": "delete", "msg_id": removed.message_id}); await client.read(ws)
    branch = request("thread_branch", thread, client_msg_id=str(uuid.uuid4()))
    await ws.send_json(branch)
    created = await client.read(ws)
    assert created["text"] == "‘원래 제목’에서 이어지는 스레드" and created["branch_from"] == {"thread": thread}
    new = created["thread"]; assert new != thread
    await ws.send_json(branch); assert (await client.read(ws)) == created
    await gate.send("alpha", "snapshot excludes later", metadata={"thread_id": thread}); await client.read(ws)
    for text in ("first", "second"):
        await ws.send_json({"v": 1, "type": "send", "employee": "alpha", "thread": new, "text": text, "client_msg_id": str(uuid.uuid4())})
        response = await client.read(ws)
        while response["type"] == "typing":
            response = await client.read(ws)
        assert response.get("text") == text, response
        for _ in range(100):
            if len(runner.events) >= (1 if text == "first" else 2): break
            await asyncio.sleep(.01)
    assert "[이전 스레드 대화]" in runner.events[0].text and "원래 제목 본문" in runner.events[0].text
    assert "생각 중" not in runner.events[0].text and "snapshot excludes later" not in runner.events[0].text
    assert "deleted before branch" not in runner.events[0].text
    assert runner.events[0].text.endswith("[이번 글]\nfirst") and runner.events[1].text == "second"
    assert all(event.text != "/branch" for event in runner.events)


@pytest.mark.asyncio
async def test_at76_checklist_message_edit_and_context_bounds(gate, client):
    ws, _ = await client.pair()
    value = {"items": ["전체", "하나", "둘"], "selected": ["하나"], "can_skip": True}
    sent = await gate.send("alpha", "choose", metadata={"hejo_checklist": value})
    assert (await client.read(ws))["checklist"] == value
    value = {**value, "selected": ["둘"]}
    assert (await gate.edit_message("alpha", sent.message_id, "updated", finalize=True, metadata={"hejo_checklist": value})).success
    assert (await client.read(ws))["checklist"] == value
    assert not (await gate.send("alpha", "bad", metadata={"hejo_checklist": {**value, "selected": ["missing"]}})).success
    huge = {"items": ["x" * 1048576], "selected": [], "can_skip": False}
    head = gate.journal.head
    assert (await gate.send("alpha", "oversize metadata", metadata={"hejo_checklist": huge})).error == "too_large"
    assert (await gate.edit_message("alpha", sent.message_id, "oversize metadata", finalize=True, metadata={"hejo_checklist": huge})).error == "too_large"
    assert gate.journal.head == head
    posts = [{"employee": "alpha", "role": "employee", "text": str(i) + "x" * 3000, "files": []} for i in range(60)]
    text = conversation_lines(posts, {"alpha": "직원 A"}, limit=50, characters=16000, line_characters=2000)
    assert len(text) <= 16000 and len(text.splitlines()) <= 50 and "59" in text
    short = [{**row, "text": str(index)} for index, row in enumerate(posts)]
    lines = conversation_lines(short, {"alpha": "직원 A"}, limit=50, characters=16000, line_characters=2000).splitlines()
    assert len(lines) == 50 and lines[0] == "직원 A: 10" and lines[-1] == "직원 A: 59"


@pytest.mark.asyncio
async def test_at75_failed_attachment_cleanup_retried_at_restart(gate, tmp_path):
    class Sink:
        async def send(self, row): pass
    thread = str(uuid.uuid4())
    file = tmp_path / "cleanup.txt"; file.write_text("fake attachment")
    sent = await gate.send_document("alpha", str(file), metadata={"thread_id": thread})
    file_id = gate.journal.message(sent.message_id)["files"][0]["file_id"]
    with patch.object(gate.files, "cleanup", side_effect=OSError("injected cleanup failure")):
        await gate.thread_delete(request("thread_delete", thread), Sink())
    assert (gate.files.root / file_id).exists() and gate.journal.message(sent.message_id) is None
    await gate.disconnect(); assert await gate.connect()
    assert not (gate.files.root / file_id).exists()


@pytest.mark.asyncio
async def test_at76_stop_reaches_real_busy_command_with_thread_scope(gate, client, monkeypatch):
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    from gateway.run_busy import GatewayBusySessionMixin
    class Busy(GatewayBusySessionMixin):
        def __init__(self): self.calls = []
        async def _interrupt_and_clear_session(self, key, source, **reasons):
            self.calls.append((key, source.thread_id, reasons))
    busy = Busy()
    async def handle(event):
        assert event.text == "/stop"
        return await busy._busy_stop_command(event, gate._event_session_key(event), event.source)
    gate.set_message_handler(handle)
    ws, _ = await client.pair()
    thread = str(uuid.uuid4())
    await ws.send_json({"v": 1, "type": "send", "employee": "alpha", "thread": thread, "text": "/stop", "client_msg_id": str(uuid.uuid4())})
    for _ in range(100):
        if busy.calls: break
        await asyncio.sleep(.01)
    assert len(busy.calls) == 1 and busy.calls[0][1] == thread
    assert busy.calls[0][2]["invalidation_reason"] == "stop_command"
