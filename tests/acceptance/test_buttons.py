"""HEJO-BUTTONS gate acceptance: isolated journal, fake turns and transport."""

import asyncio
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock
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


async def change(gate, turns, answer, action="retract"):
    await gate.change_answer(dict(type=action, answer_id=answer), turns.conn)
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

    async def interrupt(*args):
        if after_handoff:
            await original(*args)
        raise RuntimeError("simulated stop")

    monkeypatch.setattr(gate, "_reply_event", interrupt)
    with pytest.raises(RuntimeError):
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
        assert not projected(gate, q).get("answer") and turns.sink.await_count == 1
    else:
        assert frame["code"] == "button_expired"
        assert gate.journal.records[-1]["type"] == "delete"
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
        ("a", "owner", dict(answer_to="q")),
        ("f", "employee", {}),
        ("g", "employee", {}),
        ("qq", "employee", dict(reply_state="asked")),
        ("general", "owner", {}),
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
    assert index.resolve("qq")["answer"]["label"] is None
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
            assert len(encoded(row["text"])) <= 240 and "\x02" not in row["text"]


@pytest.mark.asyncio
async def test_at_hb_14_partial_answers_and_settled_notice(gate, turns):
    questions = [await ask(gate) for _ in range(3)]
    queries = HistoryQueries(gate.journal.history, context())
    await click(gate, turns, questions[1])
    notice = (await queries.summary(("alpha", THREAD)))["notice"]
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
