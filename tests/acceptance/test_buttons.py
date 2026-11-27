"""HEJO-BUTTONS gate acceptance: isolated journal, fake turns and transport."""

import asyncio
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock
from uuid import UUID

import pytest
from jsonschema import Draft202012Validator

from gate import reply_rules
from gate.history import HistoryError, HistoryIndex, HistorySession, PAGE_BYTES, encoded
from gate.history_queries import HistoryQueries, assess
from gate.server import CLIENT_VALIDATOR, HISTORY_VALIDATORS, SCHEMA

THREAD = str(UUID(int=1))


def context():
    return SimpleNamespace(
        token="fixture",
        value=lambda _: None,
        read=lambda _: 0,
        document={"names": {}, "now": 0, "home": ["alpha"]},
    )


@pytest.fixture
def turns(gate, monkeypatch):
    sink = AsyncMock()
    monkeypatch.setattr(gate, "handle_message", sink)
    instant = [datetime(2026, 1, 1, tzinfo=timezone.utc)]
    monkeypatch.setattr(gate, "_reply_clock", lambda: instant[0])
    return SimpleNamespace(sink=sink, conn=SimpleNamespace(send=AsyncMock(), features=set()), instant=instant)


async def ask(gate, labels=(), **kwargs):
    result = await gate.send(
        "alpha",
        "확인해 주세요",
        metadata=dict(
            thread_id=THREAD,
            hejo_reply_state="asked",
            hejo_buttons=[dict(label=label, style="default") for label in labels],
            **kwargs,
        ),
    )
    assert result.success
    return result.message_id


async def click(gate, turns, q, button="std:approve", **fields):
    await gate.click(dict(msg_id=q, button_id=button, **fields), turns.conn)
    return turns.conn.send.await_args.args[0]


async def change(gate, turns, answer, action="retract", **fields):
    await gate.change_answer(dict(type=action, answer_id=answer, **fields), turns.conn)
    return turns.conn.send.await_args.args[0]


def projected(gate, q):
    return gate.journal.history.resolve(q)


def restart(gate):
    gate.journal.close()
    gate.journal.open()


@pytest.mark.asyncio
async def test_at_hb_01_02_styles_and_legacy_recovery(gate):
    assert reply_rules.UNDO_SECONDS == 5 and reply_rules.UNDO_GRACE_SECONDS == 6
    for labels, roles, icons in [
        (
            reply_rules.STANDARD,
            ["approve", "reject", "comment", "confirm"],
            ["circle", "xmark", "pencil", "checkmark"],
        ),
        (
            ["메모", "메모+노션", "확인"],
            ["other", "other", "confirm"],
            ["note.text", "doc.on.doc", "checkmark"],
        ),
        (["확인", "되돌리기"], ["confirm", "undo"], ["checkmark", "arrow.uturn.backward"]),
        (["제작해", "수정", "취소"], ["approve", "other", "reject"], ["play", "pencil", "xmark"]),
        (["1", "2", "의견"], ["other", "other", "comment"], [None, None, "pencil"]),
    ]:
        q = await ask(gate, labels)
        saved = gate.journal.message(q)
        buttons = projected(gate, q)["buttons"]
        assert buttons == saved["buttons"]
        assert gate.server.project(saved, SimpleNamespace(features=set()))["buttons"] == buttons
        page = HistorySession(gate.journal.history).messages(
            context="ctx", request="shapes", key=("alpha", THREAD)
        )
        assert next(m for m in page["items"] if m["msg_id"] == q)["buttons"] == buttons
        assert [b["role"] for b in buttons] == roles
        assert [b.get("icon") for b in buttons] == icons
        for i, b in enumerate(buttons):
            assert b["primary"] == (i == 0)
            assert b["accent"] == ("green" if labels[i] == "승인" else "blue")
            assert b["repeat"] == (labels[i] == "되돌리기")
    old = dict(
        saved, msg_id="old", buttons=[dict(id="old-button", label="승인", kind="reply", style="primary")]
    )
    old.pop("_meta", None)
    await gate.journal.append(old)
    file = next(gate.journal.path.glob("*.jsonl"))
    before = file.read_bytes()
    restart(gate)
    assert projected(gate, "old")["buttons"][0]["role"] == "approve"
    assert file.read_bytes() == before


@pytest.mark.asyncio
async def test_at_hb_03_04_07_defaults_and_targeted_click(gate, turns):
    q = await ask(gate)
    ids = [b["id"] for b in projected(gate, q)["buttons"]]
    assert ids == ["std:approve", "std:reject", "std:comment", "std:confirm"]
    prompt = await gate.send("alpha", "승인해 주세요")
    assert projected(gate, prompt.message_id)["buttons"][0]["id"] == ids[0]
    ordinary = await gate.send("alpha", "일반 글")
    assert projected(gate, ordinary.message_id)["buttons"] == []
    old_confirm = SimpleNamespace(value=lambda k: "1" if k == "confirm:" + q else None)
    assert q not in assess([projected(gate, q)], old_confirm)[1]
    checked = await ask(gate, hejo_checklist=dict(items=["항목"], selected=[], can_skip=True))
    assert projected(gate, checked)["buttons"] == []
    await click(gate, turns, checked, "std:comment", text="항목 의견")
    assert turns.sink.await_args.args[0].raw_message["_hermes_button"]["comment"]
    assert projected(gate, checked)["buttons"] == []
    called = AsyncMock(return_value=False)
    gate.register_click_handler("reply", called)
    ack = await click(gate, turns, q, "std:confirm")
    called.assert_awaited_once()
    event = turns.sink.await_args.args[0]
    assert event.raw_message == {
        "_hermes_button": dict(label="확인", message_id=q, message_text="확인해 주세요")
    }
    assert event.text == "확인"
    assert projected(gate, q)["answer"]["result"] == "확인함"
    owners = [r for r in gate.journal.records if r.get("role") == "owner"]
    assert len(owners) == 2 and owners[-1]["answer_to"] == q and owners[-1]["msg_id"] == ack["answer_id"]
    assert owners[-1]["buttons"] == []
    assert q not in assess([projected(gate, q), owners[-1]], context())[1]


@pytest.mark.asyncio
@pytest.mark.parametrize("labels", [[], ["확인", "되돌리기"], ["메모", "메모+노션", "확인"]])
async def test_at_hb_05_05b_comment(gate, turns, labels):
    q = await ask(gate, labels)
    buttons = projected(gate, q)["buttons"]
    for fields in ({}, {"text": " "}, {"text": "가" * 4001}):
        assert (await click(gate, turns, q, "std:comment", **fields))["code"] == "invalid_text"
    assert (await click(gate, turns, q, buttons[0]["id"], text="금지"))["code"] == "invalid_text"
    turns.sink.assert_not_awaited()
    await click(gate, turns, q, "std:comment", text="  내용  ")
    event = turns.sink.await_args.args[0]
    assert event.text == "내용" and event.raw_message["_hermes_button"]["comment"] is True
    assert projected(gate, q)["answer"]["role"] == "comment"
    assert projected(gate, q)["buttons"] == buttons


@pytest.mark.asyncio
async def test_at_hb_06_invalid_targets(gate, turns):
    q = (await gate.send("alpha", "일반 글")).message_id
    for mid, button in [(q, "std:approve"), (q, "std:comment"), ("missing", "unknown")]:
        assert (await click(gate, turns, mid, button))["code"] == "button_expired"
    q = await ask(gate)
    await gate._record(dict(type="delete", msg_id=q))
    assert (await click(gate, turns, q))["code"] == "button_expired"
    await gate.journal.append(
        dict(
            type="message",
            role="employee",
            msg_id="other-room",
            employee="alpha",
            room="other",
            thread=THREAD,
            ts=turns.instant[0].isoformat(),
            text="승인해 주세요",
            buttons=[],
        )
    )
    await gate.journal.append(dict(type="room", room=dict(id="other", members=["beta"], lead="beta")))
    turns.conn.features.add("rooms")
    before = gate.journal.head
    assert (await click(gate, turns, "other-room"))["code"] == "button_expired"
    assert gate.journal.head == before
    assert not CLIENT_VALIDATOR.is_valid(
        dict(v=1, type="send", employee="alpha", text="글", answer_to=q, client_msg_id="x")
    )
    turns.sink.assert_not_awaited()


@pytest.mark.asyncio
@pytest.mark.parametrize("seconds,expires", [(3, False), (6.1, True)])
async def test_at_hb_08_09_10_11b_undo(gate, turns, seconds, expires):
    q = await ask(gate)

    async def handler(click):
        await gate.set_reply_state(click["msg_id"], "answered")
        return False

    gate.register_click_handler("reply", handler)
    ack = await click(gate, turns, q)
    assert ack["undo_seconds"] == 5 and datetime.fromisoformat(ack["undo_until"]) - turns.instant[
        0
    ] == timedelta(seconds=6)
    a = ack["answer_id"]
    assert projected(gate, q)["answer"]["delivery"] == "sent"
    restart(gate)
    turns.sink.assert_awaited_once()
    turns.instant[0] += timedelta(seconds=seconds)
    head = gate.journal.head
    frame = await change(gate, turns, a)
    if expires:
        assert frame["code"] == "retract_expired" and turns.sink.await_count == 1
        return
    assert frame["type"] == "retract_ack"
    assert projected(gate, q)["reply_state"] == "asked" and projected(gate, q)["answer"] is None
    assert turns.sink.await_count == 2
    event = turns.sink.await_args.args[0]
    assert event.text == (
        "[답 취소] 사장이 방금 이 질문에 보낸 답을 취소했어요. 그 답으로 시작한 일은 멈춰 주세요. "
        "이미 처리된 일은 되돌리지 말고, 무엇이 처리됐는지 사장에게 알려 주세요."
    )
    assert event.raw_message == {"_hermes_retract": dict(message_id=q, answer_id=a, label="승인")}
    assert not any(r.get("text") == event.text for r in gate.journal.records)
    records = [row for row in gate.journal.records if row["seq"] > head]
    assert [(r["type"], r["msg_id"], r.get("reply_state")) for r in records] == [
        ("delete", a, None),
        ("state", q, "asked"),
    ]
    repeated = (await click(gate, turns, q))["answer_id"]
    assert (await change(gate, turns, repeated))["type"] == "retract_ack"
    b = (await click(gate, turns, q, "std:reject"))["answer_id"]
    before = gate.journal.head
    for identifier in (q, a):
        assert (await change(gate, turns, identifier))["code"] == "retract_expired"
    assert gate.journal.head == before and projected(gate, q)["answer"]["answer_id"] == b


@pytest.mark.asyncio
@pytest.mark.parametrize("after_handoff", [False, True])
async def test_at_hb_10b_crash_windows(gate, turns, monkeypatch, after_handoff):
    q = await ask(gate)
    original = gate._reply_event

    async def interrupt(*args, **kwargs):
        if after_handoff:
            await original(*args, **kwargs)
        raise asyncio.CancelledError("simulated stop")

    monkeypatch.setattr(gate, "_reply_event", interrupt)
    with pytest.raises(asyncio.CancelledError):
        await click(gate, turns, q)
    monkeypatch.setattr(gate, "_reply_event", original)
    restart(gate)
    answer = projected(gate, q)["answer"]
    assert answer["delivery"] == "unknown" and turns.sink.await_count == int(after_handoff)
    a = answer["answer_id"]
    assert (await change(gate, turns, a, "redeliver"))["type"] == "click_ack"
    assert projected(gate, q)["answer"]["delivery"] == "sent"
    assert (await change(gate, turns, a, "redeliver"))["code"] == "already_sent"
    assert turns.sink.await_count == 1 + int(after_handoff)
    await change(gate, turns, a)
    assert (await change(gate, turns, a, "redeliver"))["code"] == "retract_expired"


@pytest.mark.asyncio
async def test_at_hb_10c_legacy_record(gate, turns):
    q = await ask(gate)
    await gate.journal.append(
        dict(
            type="message",
            role="owner",
            msg_id="old",
            employee="alpha",
            thread=THREAD,
            text="승인",
            answer_to=q,
            ts=turns.instant[0].isoformat(),
        )
    )
    restart(gate)
    before = gate.journal.head
    assert "delivery" not in projected(gate, q)["answer"]
    assert (await change(gate, turns, "old", "redeliver"))["code"] == "already_sent"
    assert gate.journal.head == before and not turns.sink.await_count


@pytest.mark.asyncio
async def test_at_hb_11_concurrent_and_repeat(gate, turns):
    q = await ask(gate)
    await asyncio.gather(click(gate, turns, q), click(gate, turns, q, "std:reject"))
    assert [c.args[0]["type"] for c in turns.conn.send.await_args_list] == ["click_ack", "error"]
    assert turns.sink.await_count == 1
    q = await ask(gate, ["확인", "되돌리기"])
    confirm, undo = projected(gate, q)["buttons"]
    for b in (confirm, undo, undo):
        assert (await click(gate, turns, q, b["id"]))["type"] == "click_ack"


@pytest.mark.asyncio
@pytest.mark.parametrize("success", [False, True])
async def test_at_hb_12_native(gate, turns, monkeypatch, success):
    from gate import buttons

    resolve = AsyncMock(return_value=success)
    monkeypatch.setattr(buttons, "resolve", resolve)
    q = (await gate.send_slash_confirm("alpha", "승인해 주세요", "확인", "fixture", "fixture")).message_id
    b = projected(gate, q)["buttons"][0]["id"]
    frame = await click(gate, turns, q, b)
    if success:
        assert frame["type"] == "click_ack" and not projected(gate, q)["buttons"]
        await change(gate, turns, frame["answer_id"])
        assert not projected(gate, q).get("answer") and projected(gate, q)["buttons"] == []
        assert turns.sink.await_count == 1
    else:
        assert frame["code"] == "button_expired"
        assert [r["type"] for r in gate.journal.records[-2:]] == ["delete", "edit"]
        assert projected(gate, q)["buttons"] == []
    resolve.assert_awaited_once()


def seed(index, mid, thread=THREAD, role="employee", text="검토", **fields):
    index.apply(
        dict(
            type="message",
            seq=index.head + 1,
            msg_id=mid,
            ts="2026-01-01T00:00:00Z",
            role=role,
            employee="alpha",
            thread=thread,
            text=text,
            buttons=[],
            **fields,
        )
    )


def test_at_hb_13_branch():
    index = HistoryIndex()
    for mid, role, fields in [
        ("q", "employee", dict(reply_state="asked")),
        ("a", "owner", dict(answer_to="q", text="승인")),
        ("f", "employee", {}),
        ("g", "employee", {}),
        ("qq", "employee", dict(reply_state="asked")),
        ("general", "owner", dict(text="일" * 30 + "뒤")),
        ("c", "employee", {}),
        ("qqq", "employee", dict(reply_state="asked")),
    ]:
        seed(index, mid, role=role, **fields)
    assert [index.resolve(i)["branch"] for i in index.ids(("alpha", THREAD))] == [
        None,
        "q",
        "q",
        "q",
        None,
        None,
        None,
        None,
    ]
    assert index.resolve("q")["answer"]["label"] == "승인"
    assert index.resolve("qq")["answer"]["label"] is None
    assert index.resolve("qq")["answer"]["text"] == "일" * 30
    seed(
        index,
        "opinion",
        role="owner",
        answer_to="qqq",
        text="수정 요청",
        _meta={"undo": dict(label="의견", until="2026-01-01T00:00:06Z")},
    )
    seed(index, "follow")
    assert index.resolve("qqq")["answer"]["role"] == "comment"
    assert index.resolve("qqq")["answer"]["text"] == "수정 요청"
    assert index.resolve("follow")["branch"] == "qqq"


@pytest.mark.asyncio
async def test_at_hb_14_14b_bounded_queries_and_cursor(gate):
    index = HistoryIndex()
    queries = HistoryQueries(index, context())
    session = HistorySession(index)
    key = ("alpha", THREAD)
    document = dict(
        kind="asks",
        context="fixture",
        request="fixture",
        target=dict(room="alpha", thread=THREAD),
        scope="alpha",
        limit=50,
    )
    assert HISTORY_VALIDATORS["query"].is_valid(document | {"session": "fixture"})
    for i in range(774):
        seed(index, str(i), reply_state="asked")
    seed(index, "answered", role="owner", answer_to="51")
    rows = queries.asks(key)
    assert rows[51]["answer"] and rows[50]["answer"] is None
    page = session.rows(document, rows)
    ids = [r["id"] for r in page["items"]]
    for mid in ("answered", "53"):
        index.apply(dict(type="delete", seq=index.head + 1, msg_id=mid))
    while not page["complete"]:
        page = session.rows(dict(document, cursor=page["next"]), queries.asks(key))
        for row in page["items"]:
            ids.append(row["id"])
            if row["id"] == "53":
                assert row["removed"]
            else:
                assert row["id"] == row["msg_id"] and row["answer"] is None
    assert ids == list(map(str, range(774)))
    buttons = [
        dict(id=str(UUID(int=i + 1)), kind="clarify", style="default", label=('"\\\x01' + "😀" * 27))
        for i in range(7)
    ]
    buttons[-1]["label"] = "기타"
    for t in range(50):
        thread = str(UUID(int=t + 100))
        for i in range(4):
            mid = str(UUID(int=1000 + t * 4 + i))
            seed(index, mid, thread, text='\x02"\\' + "😀" * 300, reply_state="asked")
            index.apply(dict(type="edit", seq=index.head + 1, msg_id=mid, buttons=buttons))
        assert len(index.resolve(mid)["buttons"]) == 7
    notice_query = dict(
        context="fixture", request="notices", kind="notices", mode="sidebar", scope="home", limit=50
    )
    # The 774-question thread is also present. Read the first 50 rows as one HTTP-sized response.
    page = await gate.server.history_query(session, context(), notice_query, {"alpha"})
    assert len(encoded(page)) <= PAGE_BYTES and len(page["items"]) == 50
    assert max(row["asksWaiting"] for row in page["items"]) >= 4
    notices = queries.notices([await queries.summary(("alpha", str(UUID(int=t + 100)))) for t in range(50)])
    assert len(encoded(session.rows(notice_query, notices))) < PAGE_BYTES
    assert len(notices) == 50 and len(encoded(notices)) < PAGE_BYTES
    for notice in notices:
        assert notice["asksWaiting"] == 4 and notice["asksAnswered"] == 0 and len(notice["asksPreview"]) == 3
        assert len(encoded(notice["preview"])) <= 900
        for row in notice["asksPreview"]:
            assert len(row["buttons"]) == 5 and row["buttons"][-1]["label"] == "기타"
            assert all(all(ord(ch) >= 32 for ch in b["label"]) for b in row["buttons"])
            assert len(encoded(row["text"])) <= 240 and "\x02" not in row["text"]


@pytest.mark.asyncio
async def test_at_hb_14_partial_answers_and_settled_notice(gate, turns):
    questions = [await ask(gate) for _ in range(3)]
    queries = HistoryQueries(gate.journal.history, context())
    assert (await queries.summary(("alpha", THREAD)))["bell"] is True
    await click(gate, turns, questions[1])
    summary = await queries.summary(("alpha", THREAD))
    assert summary["bell"] is not True
    notice = summary["notice"]
    assert (notice["asksWaiting"], notice["asksAnswered"]) == (2, 1)
    assert [row["msg_id"] for row in notice["asksPreview"]] == [questions[0], questions[2]]
    for q in (questions[0], questions[2]):
        await click(gate, turns, q)
    await gate.send("alpha", "처리했습니다", metadata=dict(thread_id=THREAD))
    assert (await queries.summary(("alpha", THREAD)))["notice"] is None


@pytest.mark.asyncio
async def test_at_hb_14b_long_answers_and_room_scope(gate):
    index = HistoryIndex()
    for i in range(50):
        q = str(UUID(int=i + 100))
        seed(index, q, reply_state="asked")
        seed(
            index,
            "answer-" + q,
            role="owner",
            answer_to=q,
            text="말" * 4000,
            _meta={"undo": dict(label="의견", until="2026-01-01T00:00:06Z")},
        )
    session, member = HistorySession(index), context()
    query = dict(
        context=member.token,
        request="answers",
        kind="asks",
        scope="alpha",
        target=dict(room="alpha", thread=THREAD),
        limit=50,
    )
    page = await gate.server.history_query(session, member, query, {"alpha", "beta"})
    assert page["complete"] and len(page["items"]) == 50 and len(encoded(page)) < PAGE_BYTES
    assert all(
        r["answer"]["text"].endswith("…") and len(encoded(r["answer"]["text"])) <= 240 for r in page["items"]
    )
    with pytest.raises(HistoryError, match="invalid_query"):
        await gate.server.history_query(session, member, dict(query, scope="beta"), {"alpha", "beta"})
    with pytest.raises(HistoryError, match="target_missing"):
        await gate.server.history_query(session, member, query, {"beta"})
    seed(index, "combining", text=("a" + "\u0301" * 100) * 300, reply_state="asked")
    notice = (await member.queries.summary(("alpha", THREAD)))["notice"]
    assert notice["preview"].endswith("…") and len(encoded(notice["preview"])) <= 900


def test_at_hb_15_16_wire():
    schema = Draft202012Validator(SCHEMA)
    assert schema.is_valid(
        dict(
            v=1,
            type="click_ack",
            msg_id="q",
            button_id="std:confirm",
            answer_id="answer",
            undo_until="2026-01-01T00:00:06Z",
            undo_seconds=5,
        )
    )
    assert CLIENT_VALIDATOR.is_valid(dict(v=1, type="click", msg_id="q", button_id="legacy"))
    for kind in ("retract", "redeliver", "retract_ack"):
        assert schema.is_valid(dict(v=1, type=kind, answer_id="fixture"))
    assert CLIENT_VALIDATOR.is_valid(
        dict(v=1, type="click", msg_id="q", button_id="std:comment", text="의견")
    )


async def general_reply(gate, turns, text):
    await gate.receive(dict(employee="alpha", thread=THREAD, client_msg_id="general", text=text), turns.conn)


@pytest.mark.asyncio
@pytest.mark.parametrize("outcome", ["resolved", "expired", "exception"])
async def test_at_hb_11c_native_and_general(gate, turns, monkeypatch, outcome):
    from gate import buttons

    resolver = AsyncMock(
        return_value=outcome == "resolved",
        side_effect=RuntimeError("temporary") if outcome == "exception" else None,
    )
    monkeypatch.setattr(buttons, "resolve", resolver)
    native = buttons.native_metadata("approval", "fixture", [("승인", "once", "primary")])
    q = (
        await gate.send("alpha", "승인 요청", metadata=dict(thread_id=THREAD, _hejo_native_buttons=native))
    ).message_id
    r = await ask(gate)
    general = "아직 결정하지 않았습니다" * 4
    await general_reply(gate, turns, general)
    key = ("alpha", THREAD)
    query = HistoryQueries(gate.journal.history, context())
    summary = await query.summary(key)
    assert summary["waitingButtonIDs"] == [q] and summary["assessment"]["pendingID"] == q
    assert summary["notice"]["asksWaiting"] == 1 and summary["notice"]["asksPreview"][0]["msg_id"] == q
    native_row, ordinary = query.asks(key)
    assert native_row["answer"] is None
    assert ordinary["answer"]["label"] is None and ordinary["answer"]["text"] == general[:30]
    assert (await click(gate, turns, r))["code"] == "button_expired"

    button = native_row["buttons"][0]["id"]
    frame = await click(gate, turns, q, button, id="request")
    resolver.assert_awaited_once()
    if outcome == "exception":
        assert frame["code"] == "button_expired" and frame["ref"] == "request"
        assert projected(gate, q)["answer"] is None and projected(gate, q)["buttons"] == native_row["buttons"]
        resolver.side_effect = None
        resolver.return_value = True
        assert (await click(gate, turns, q, button))["type"] == "click_ack"
        return
    if outcome == "resolved":
        assert projected(gate, q)["answer"]["answer_id"] == frame["answer_id"]
        state = (await query.summary(key))["assessment"]
        assert state["requestID"] == q and state["approved"] and state["pendingID"] is None
        assert (await click(gate, turns, q, button))["code"] == "button_expired"
        resolver.assert_awaited_once()
        assert (await change(gate, turns, frame["answer_id"]))["type"] == "retract_ack"
    else:
        assert frame["code"] == "button_expired" and frame["ref"] == "request"
        assert gate.journal.records[-2]["type"] == "delete"
    restart(gate)
    question = projected(gate, q)
    assert question["buttons"] == [] and question["answer"]["text"] == general[:30]
    assert question["answer"]["label"] is None
    assert q not in (await HistoryQueries(gate.journal.history, context()).summary(key))["waitingButtonIDs"]


@pytest.mark.asyncio
async def test_at_hb_11c_general_survives_retraction(gate, turns):
    q = await ask(gate)
    ack = await click(gate, turns, q)
    await general_reply(gate, turns, "일반 답")
    assert projected(gate, q)["answer"]["answer_id"] == ack["answer_id"]
    await change(gate, turns, ack["answer_id"])
    assert projected(gate, q)["answer"]["text"] == "일반 답"
    assert (await click(gate, turns, q))["code"] == "button_expired"


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["false", "exception", "membership"])
async def test_tk1_02_delivery_failure_receipts(gate, turns, monkeypatch, failure):
    q = await ask(gate)
    if failure == "membership":
        gate.register_click_handler(
            "reply", AsyncMock(side_effect=lambda _: monkeypatch.setattr(gate, "employees", lambda: []))
        )
    else:
        monkeypatch.setattr(
            gate,
            "receive",
            AsyncMock(
                return_value=False, side_effect=RuntimeError("temporary") if failure == "exception" else None
            ),
        )
    error = await click(gate, turns, q, id="click-req")
    code = {"false": "button_expired", "exception": "dispatch_failed", "membership": "unknown_employee"}[
        failure
    ]
    assert error == dict(v=1, type="error", code=code, ref="click-req")
    answer = projected(gate, q)["answer"]
    assert answer["delivery"] == "unknown"
    if failure == "membership":
        return
    a = answer["answer_id"]
    error = await change(gate, turns, a, "redeliver", id="retry")
    assert error["type"] == "error" and error["ref"] == "retry"
    turns.conn.send.reset_mock()
    await change(gate, turns, a, id="cancel")
    frames = [call.args[0] for call in turns.conn.send.await_args_list]
    # AT-HB-12b: the delete is the cancellation receipt boundary.
    assert frames == [dict(v=1, type="retract_ack", answer_id=a)]
    assert projected(gate, q)["answer"] is None


@pytest.mark.asyncio
@pytest.mark.parametrize("retry", [False, True])
async def test_tk1_03_room_reply_includes_missed_post(gate, client, turns, retry):
    from gate.tests.test_rooms import create

    ws, _ = await client.pair(features=["rooms"])
    room = await create(client, ws)
    turns.conn.features.add("rooms")
    q = (
        await gate.send(
            "room:" + room,
            "승인 요청",
            metadata=dict(thread_id=THREAD, hermes_profile="alpha", hejo_reply_state="asked"),
        )
    ).message_id
    result = await gate.send(
        "room:" + room, "다른 직원의 추가 설명", metadata=dict(thread_id=THREAD, hermes_profile="beta")
    )
    assert result.success
    if retry:
        turns.sink.side_effect = RuntimeError("temporary")
        assert (await click(gate, turns, q, id="initial"))["code"] == "dispatch_failed"
        answer_id = projected(gate, q)["answer"]["answer_id"]
        later = await gate.send(
            "room:" + room, "나중에 온 글", metadata=dict(thread_id=THREAD, hermes_profile="beta")
        )
        assert later.success
        turns.sink.side_effect = None
        assert (await change(gate, turns, answer_id, "redeliver"))["type"] == "click_ack"
    else:
        assert (await click(gate, turns, q))["type"] == "click_ack"
    event = turns.sink.await_args.args[0]
    assert event.source.profile == "alpha" and event.text == "승인"
    assert "다른 직원의 추가 설명" in event.channel_context
    assert "나중에 온 글" not in event.channel_context
    assert "다른 직원의 추가 설명" not in gate.room_context(room, THREAD, "alpha")
    await ws.close()


@pytest.mark.asyncio
async def test_tk1_05_live_and_replayed_button_transitions(gate, client):
    ws, _ = await client.pair()
    q = (await gate.send("alpha", "초안")).message_id
    assert (await client.read(ws))["buttons"] == []
    for text, expected in [("승인해 주세요", reply_rules.standard()), ("초안 수정", [])]:
        assert (await gate.edit_message("alpha", q, text, finalize=True)).success
        edit = await client.read(ws)
        assert edit["type"] == "edit" and edit["buttons"] == expected
        assert Draft202012Validator(SCHEMA).is_valid(edit)
    await gate.set_reply_state(q, "asked")
    state = await client.read(ws)
    assert state["buttons"] == reply_rules.standard() and Draft202012Validator(SCHEMA).is_valid(state)
    await ws.close()
    await gate.disconnect()
    assert await gate.connect()
    ws, _ = await client.pair(since=0)
    replay = await client.until(ws, "sync_done")
    assert [r["buttons"] for r in replay if r.get("msg_id") == q] == [
        [],
        reply_rules.standard(),
        [],
        reply_rules.standard(),
    ]
    await ws.close()


@pytest.mark.asyncio
@pytest.mark.parametrize("operation", ["click", "marker", "retract"])
async def test_tk1_02_journal_errors_reference_request(gate, turns, monkeypatch, operation):
    from gate.journal import HejoJournalError

    q = await ask(gate)
    if operation == "retract":
        answer = (await click(gate, turns, q))["answer_id"]
    append = gate.journal.append
    fail_on = {"click": "message", "marker": "state", "retract": "delete"}[operation]

    async def failing_append(frame, internal=None):
        if frame["type"] == fail_on:
            raise HejoJournalError("fault")
        return await append(frame, internal)

    monkeypatch.setattr(gate.journal, "append", failing_append)
    if operation == "retract":
        error = await change(gate, turns, answer, id="request")
        assert projected(gate, q)["answer"]["answer_id"] == answer
    else:
        error = await click(gate, turns, q, id="request")
        expected = projected(gate, q)["answer"]
        if operation == "marker":
            assert expected["delivery"] == "unknown" and turns.sink.await_count == 1
        else:
            assert expected is None and turns.sink.await_count == 0
    assert error["type"] == "error" and error["code"] == "journal_write_failed" and error["ref"] == "request"


@pytest.mark.asyncio
async def test_tk1_02_journal_error_on_socket(gate, client, monkeypatch):
    from gate.journal import HejoJournalError

    ws, _ = await client.pair()
    q = await ask(gate)
    await client.until(ws, "message")
    monkeypatch.setattr(gate.journal, "append", AsyncMock(side_effect=HejoJournalError("fault")))
    await ws.send_json(dict(v=1, type="click", id="request", msg_id=q, button_id="std:approve"))
    await ws.send_json(dict(v=1, type="roster", id="barrier"))
    frames = await client.until(ws, "roster")
    assert frames[:-1] == [dict(v=1, type="error", code="journal_write_failed", ref="request")]
    await ws.close()


@pytest.mark.asyncio
@pytest.mark.parametrize("finalize", [False, True])
async def test_at_hb_12b_hermes_settles_approval(gate, turns, client, monkeypatch, finalize):
    from gate import buttons

    ws, _ = await client.pair()
    native = buttons.native_metadata("approval", "fixture", [("승인", "once", "primary")])
    q = (
        await gate.send(
            "alpha",
            "승인 요청",
            metadata=dict(thread_id=THREAD, _hejo_native_buttons=native, _hejo_local={"origin": "fixture"}),
        )
    ).message_id
    prompt = await client.read(ws)
    old_id = prompt["buttons"][0]["id"]
    assert old_id in gate.journal.message(q)["_meta"]["buttons"]

    resolver = AsyncMock()
    monkeypatch.setattr(buttons, "resolve", resolver)
    result = await gate.edit_message("alpha", q, "승인 요청 시간이 지났습니다", finalize=finalize)
    assert result.success
    if not finalize:
        assert q in gate._pending_edits  # Wait for the actual deferred publication.
    edit = await client.read(ws)
    assert (edit["type"], edit["msg_id"], edit["final"], edit["buttons"]) == ("edit", q, finalize, [])
    await general_reply(gate, turns, "다음 작업을 알려 주세요")
    restart(gate)
    card = gate.journal.message(q)
    assert card["buttons"] == [] and card["_meta"] == {"local": {"origin": "fixture"}}
    assert projected(gate, q)["answer"]["text"] == "다음 작업을 알려 주세요"
    summary = await HistoryQueries(gate.journal.history, context()).summary(("alpha", THREAD))
    assert summary["waitingButtonIDs"] == [] and summary["bell"] is not True
    assert (await click(gate, turns, q, old_id))["code"] == "button_expired"
    resolver.assert_not_awaited()
    await ws.close()


@pytest.mark.asyncio
async def test_at_hb_12b_unedited_clarify_waits_until_clicked(gate, turns, monkeypatch):
    from tools import clarify_gateway

    resolve = Mock(return_value=False)
    monkeypatch.setattr(clarify_gateway, "resolve_gateway_clarify", resolve)
    q = (
        await gate.send_clarify(
            "alpha", "어느 쪽인가요?", ["첫째"], "fixture", "session", metadata={"thread_id": THREAD}
        )
    ).message_id
    turns.instant[0] += timedelta(hours=2)
    await general_reply(gate, turns, "일반 답")
    before = projected(gate, q)
    assert before["answer"] is None and before["buttons"]
    queries = HistoryQueries(gate.journal.history, context())
    assert (await queries.summary(("alpha", THREAD)))["waitingButtonIDs"] == [q]
    resolve.assert_not_called()
    head = gate.journal.head
    error = await click(gate, turns, q, before["buttons"][0]["id"], id="expired")
    assert error == dict(v=1, type="error", code="button_expired", ref="expired")
    resolve.assert_called_once_with("fixture", "첫째")
    answer, delete, edit = [r for r in gate.journal.records if r["seq"] > head]
    assert answer["answer_to"] == q and delete["type"] == "delete" and delete["msg_id"] == answer["msg_id"]
    assert edit["msg_id"] == q and edit["buttons"] == []
    assert projected(gate, q)["answer"]["text"] == "일반 답"
    assert (await queries.summary(("alpha", THREAD)))["waitingButtonIDs"] == []


@pytest.mark.asyncio
@pytest.mark.parametrize("failure", ["notify", "state", "delete", "publish"])
async def test_at_hb_12b_single_retract_response(gate, client, turns, monkeypatch, caplog, failure):
    from gate.journal import HejoJournalError

    ws, _ = await client.pair()
    q = await ask(gate)
    await client.read(ws)
    await ws.send_json(dict(v=1, type="click", msg_id=q, button_id="std:approve"))
    a = (await client.until(ws, "click_ack"))[-1]["answer_id"]
    await gate.set_reply_state(q, "answered")
    await client.until(ws, "state")
    head = gate.journal.head
    secret = "private test detail"
    if failure == "notify":
        monkeypatch.setattr(gate, "receive", AsyncMock(side_effect=RuntimeError(secret)))
    elif failure == "publish":
        broadcast = gate.server.broadcast

        async def publish(frame):
            if frame["type"] == "delete":
                raise RuntimeError(secret)
            await broadcast(frame)

        monkeypatch.setattr(gate.server, "broadcast", publish)
    else:
        append = gate.journal.append

        async def write(frame, internal=None):
            if frame["type"] == failure:
                raise HejoJournalError(secret)
            return await append(frame, internal)

        monkeypatch.setattr(gate.journal, "append", write)

    caplog.clear()
    await ws.send_json(dict(v=1, type="retract", answer_id=a, id="cancel"))
    await ws.send_json(dict(v=1, type="roster", id="barrier"))
    frames = await client.until(ws, "roster")
    replies = [f for f in frames[:-1] if "seq" not in f]
    deletes = [r for r in gate.journal.records if r["seq"] > head and r["type"] == "delete"]
    if failure == "delete":
        assert replies == [dict(v=1, type="error", code="journal_write_failed", ref="cancel")]
        assert deletes == [] and projected(gate, q)["answer"]["answer_id"] == a
        assert turns.sink.await_count == 1
    else:
        assert replies == [dict(v=1, type="retract_ack", answer_id=a)]
        assert [r["msg_id"] for r in deletes] == [a] and projected(gate, q)["answer"] is None
        assert turns.sink.await_count == (1 if failure == "notify" else 2)
        errors = [r.getMessage() for r in caplog.records if r.name == "gate.adapter"]
        kind = "HejoJournalError" if failure == "state" else "RuntimeError"
        assert errors == [f"retract_{failure}_failed type={kind}"]
        assert secret not in caplog.text
    await ws.close()


@pytest.mark.asyncio
async def test_at_hb_12b_split_native_card_edit(gate):
    from gate import buttons

    native = buttons.native_metadata("approval", "fixture", [("승인", "once", "primary")])
    text = "줄" * 30000
    sent = await gate.send(
        "alpha", text, metadata=dict(thread_id=THREAD, expect_edits=True, _hejo_native_buttons=native)
    )
    assert sent.success
    first, last = gate._stream_parts[sent.message_id]
    assert not gate.journal.message(first)["buttons"] and gate.journal.message(last)["_meta"]["buttons"]
    assert (await gate.edit_message("alpha", first, text + " 만료", finalize=False)).success
    for mid in (first, last):
        saved = gate.journal.message(mid)
        assert saved["buttons"] == [] and not saved.get("_meta", {}).get("buttons")
