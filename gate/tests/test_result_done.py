"""HEJO-RESULT-DONE acceptance: a result notice is not a question awaiting an answer.

Q = employee `asked` + [승인, 거절], R = employee `asked` + [확인, 되돌리기] (result notice),
O = owner general post, E = plain employee post. Names ending in `_judgement` cover only the
judgement fields that also exist in the baseline gate; `_waiting_ids` cover the new field.
"""
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

from gate.history import HistoryIndex
from gate.history_queries import HistoryQueries, assess
from gate.tests.test_history_queries import make_context, post

SCHEMA = json.loads((Path(__file__).resolve().parents[2] / 'schemas' / 'hejo-history-v1.json').read_text())
SUMMARY = Draft202012Validator({**SCHEMA, 'oneOf': [{'$ref': '#/$defs/summary'}]})
KEY = ('alpha', 'fixture-thread')


def buttons(seq, *labels):
    return [{'id': f'button-{seq}-{number}', 'label': label, 'kind': 'reply', 'style': 'default'}
            for number, label in enumerate(labels)]


def Q(seq, **extra):
    return post(seq, text='보내도 될까요?', reply_state='asked', buttons=buttons(seq, '승인', '거절'), **extra)


def R(seq, labels=('확인', '되돌리기'), **extra):
    return post(seq, text='처리 결과를 알려 드려요.', reply_state='asked', buttons=buttons(seq, *labels), **extra)


def O(seq, **extra):
    return post(seq, role='owner', text='일정에 등록', **extra)


def E(seq, **extra):
    return post(seq, text='처리했어요')


def thread(*rows, **context):
    index = HistoryIndex()
    for row in rows:
        index.apply(row)
    return HistoryQueries(index, make_context(**context))


async def summary_of(*rows, **context):
    return await thread(*rows, **context).summary(KEY)


def judgement(item):
    return item['assessment'], item['notice'], item['bell'], item['waitingButtonCount']


AS_ASKED = {'requestID': 'fixture-3', 'pendingID': 'fixture-3', 'working': False, 'settled': False, 'approved': False}


@pytest.mark.asyncio
async def test_at_rd_01_judgement_result_notice_after_answer_is_settled():
    item = await summary_of(Q(1), O(2), R(3))
    assert item['assessment'] == {'requestID': 'fixture-3', 'pendingID': None, 'working': False,
                                  'settled': True, 'approved': False}
    assert item['notice'] is None and item['bell'] is None
    assert item['waitingButtonCount'] == 1
    assert HistoryQueries.notices([item]) == []


@pytest.mark.asyncio
async def test_at_rd_01_waiting_ids_result_notice_is_the_only_button_post():
    item = await summary_of(Q(1), O(2), R(3))
    assert item['waitingButtonIDs'] == ['fixture-3']


@pytest.mark.asyncio
@pytest.mark.parametrize('labels', [(':white_check_mark: 확인', '되돌리기'), ('확인', ' 되돌리기 ')],
                         ids=['prefixed', 'padded'])
async def test_at_rd_01b_judgement_decorated_labels_stay_a_question(labels):
    item = await summary_of(Q(1), O(2), R(3, labels))
    assert item['assessment'] == AS_ASKED
    assert item['notice']['id'] == 'fixture-3' and item['notice']['questions'] is True
    assert item['bell'] is True and item['waitingButtonCount'] == 1


@pytest.mark.asyncio
async def test_at_rd_01b_waiting_ids_decorated_labels_still_listed():
    for labels in ((':white_check_mark: 확인', '되돌리기'), ('확인', ' 되돌리기 ')):
        assert (await summary_of(Q(1), O(2), R(3, labels)))['waitingButtonIDs'] == ['fixture-3']


@pytest.mark.asyncio
async def test_at_rd_01c_judgement_reversed_order_stays_a_question():
    item = await summary_of(Q(1), O(2), R(3, ('되돌리기', '확인')))
    assert item['assessment'] == AS_ASKED
    assert item['notice']['id'] == 'fixture-3' and item['notice']['questions'] is True
    assert item['bell'] is True and item['waitingButtonCount'] == 1


@pytest.mark.asyncio
async def test_at_rd_01c_waiting_ids_reversed_order_still_listed():
    assert (await summary_of(Q(1), O(2), R(3, ('되돌리기', '확인'))))['waitingButtonIDs'] == ['fixture-3']


@pytest.mark.asyncio
async def test_at_rd_02_judgement_lone_result_notice_is_neither_question_nor_alert():
    item = await summary_of(R(1), now=1767225660)
    assert item['assessment'] == {'requestID': 'fixture-1', 'pendingID': None, 'working': False,
                                  'settled': True, 'approved': False}
    assert item['notice'] is None and item['bell'] is None


@pytest.mark.asyncio
async def test_at_rd_02_waiting_ids_lone_result_notice_keeps_its_buttons():
    assert (await summary_of(R(1), now=1767225660))['waitingButtonIDs'] == ['fixture-1']


@pytest.mark.asyncio
async def test_at_rd_03_judgement_result_notice_does_not_hide_an_unanswered_question():
    item = await summary_of(Q(1), R(2))
    assert item['assessment']['pendingID'] == 'fixture-1' and not item['assessment']['settled']
    assert item['notice']['id'] == 'fixture-1' and item['notice']['questions'] is True
    assert item['waitingButtonCount'] == 2


@pytest.mark.asyncio
async def test_at_rd_03_waiting_ids_both_unanswered_posts_in_seq_order():
    assert (await summary_of(Q(1), R(2)))['waitingButtonIDs'] == ['fixture-1', 'fixture-2']


@pytest.mark.asyncio
async def test_waiting_ids_follow_seq_not_id_order():
    item = await summary_of(Q(9), R(10))
    assert item['waitingButtonIDs'] == ['fixture-9', 'fixture-10']
    assert item['waitingButtonCount'] == 2


OTHER_BUTTON_SETS = [
    ('a', post(1, reply_state='asked', buttons=buttons(1, '확인'))),
    ('b', post(1, reply_state='asked', buttons=buttons(1, '확인', '되돌리기', '수정'))),
    ('c', Q(1)),
    ('d', post(1, reply_state='asked')),
    ('e', post(1, text='승인해 줘')),
]


@pytest.mark.parametrize('row', [row for _, row in OTHER_BUTTON_SETS], ids=[name for name, _ in OTHER_BUTTON_SETS])
def test_at_rd_04_judgement_other_button_sets_are_unchanged(row):
    state, waiting, _ = assess([row], make_context())
    assert state == {'requestID': 'fixture-1', 'pendingID': 'fixture-1', 'working': False,
                     'settled': False, 'approved': False}
    assert waiting == {'fixture-1'}


@pytest.mark.asyncio
async def test_at_rd_04_judgement_f_answered_question_then_plain_reply_is_settled():
    item = await summary_of(Q(1), O(2), E(3))
    assert item['assessment'] == {'requestID': 'fixture-1', 'pendingID': None, 'working': False,
                                  'settled': True, 'approved': False}
    assert item['notice'] is None and item['waitingButtonCount'] == 0


@pytest.mark.asyncio
@pytest.mark.parametrize('row', [row for _, row in OTHER_BUTTON_SETS], ids=[name for name, _ in OTHER_BUTTON_SETS])
async def test_at_rd_04_judgement_summary_counts_the_post_once(row):
    item = await summary_of(row)
    assert item['notice']['id'] == 'fixture-1'
    assert item['waitingButtonCount'] == 1


@pytest.mark.asyncio
async def test_at_rd_04_waiting_ids_other_button_sets():
    for _, row in OTHER_BUTTON_SETS:
        assert (await summary_of(row))['waitingButtonIDs'] == ['fixture-1']
    assert (await summary_of(Q(1), O(2), E(3)))['waitingButtonIDs'] == []


@pytest.mark.asyncio
async def test_at_rd_05_judgement_pressed_result_notice_matches_baseline():
    pressed = post(4, role='owner', text='되돌리기', answer_to='fixture-3')
    item = await summary_of(Q(1), O(2), R(3), pressed)
    assert item['assessment'] == {'requestID': 'fixture-3', 'pendingID': None, 'working': False,
                                  'settled': False, 'approved': False}
    assert item['notice'] is None and item['waitingButtonCount'] == 0
    item = await summary_of(Q(1), O(2), R(3), pressed, E(5))
    assert item['assessment'] == {'requestID': 'fixture-3', 'pendingID': None, 'working': False,
                                  'settled': True, 'approved': False}
    assert item['notice'] is None and item['waitingButtonCount'] == 0


@pytest.mark.asyncio
async def test_at_rd_05_waiting_ids_pressed_result_notice_is_empty():
    pressed = post(4, role='owner', text='되돌리기', answer_to='fixture-3')
    assert (await summary_of(Q(1), O(2), R(3), pressed))['waitingButtonIDs'] == []
    assert (await summary_of(Q(1), O(2), R(3), pressed, E(5)))['waitingButtonIDs'] == []


@pytest.mark.asyncio
async def test_at_rd_06_judgement_island_questions_skip_result_notices():
    index = HistoryIndex()
    for row in (Q(1), O(2), R(3), Q(4, thread='other-thread')):
        index.apply(row)
    questions = await HistoryQueries(index, make_context()).questions(['alpha'])
    assert {q['id'] for q in questions} == {'fixture-1', 'fixture-4'}


@pytest.mark.asyncio
async def test_at_rd_07_waiting_ids_summaries_pass_the_schema_with_and_without_the_field():
    items = [await summary_of(Q(1), O(2), R(3)), await summary_of(Q(1), R(2)), await summary_of(Q(1))]
    old = [{k: v for k, v in item.items() if k != 'waitingButtonIDs'} for item in items]
    assert len(items + old) == 6
    for item in items:
        assert 'waitingButtonIDs' in item
    for item in items + old:
        SUMMARY.validate(item)
    assert 'waitingButtonIDs' not in SCHEMA['$defs']['summary']['required']
