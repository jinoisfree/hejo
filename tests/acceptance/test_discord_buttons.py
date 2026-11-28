"""HEJO-BUTTONS Discord acceptance through the registered listener and FOLLOW webhook."""
import asyncio
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from gate import discord as door
from test_buttons import change, click, projected, restart, turns
from test_discord import client, discord_module as text_sdk, gate, named_roster, registered, pair, settled, transport
from test_discord_follow import FollowHook, ForumPost, lab

pytestmark = pytest.mark.asyncio


class View:
    def __init__(self, **kwargs):
        self.children = []
        self.__dict__.update(kwargs)

    def add_item(self, item):
        self.children.append(item)

    def stop(self):
        pass


@pytest.fixture(autouse=True)
def discord_module(text_sdk, monkeypatch):
    text_sdk.ui = SimpleNamespace(View=View, Modal=View, Button=SimpleNamespace, TextInput=SimpleNamespace)
    text_sdk.ButtonStyle.primary = 1
    text_sdk.TextStyle.paragraph = 2
    original_send = FollowHook._send
    original_edit = FollowHook.edit_message

    async def send(hook, **fields):
        sent = await original_send(hook, **fields)
        message = hook.lab.posts[sent.channel.id].messages[sent.id]
        message.channel_id = sent.channel.id
        message.components = [fields['view']] if fields.get('view') else []
        return sent

    async def edit(hook, identifier, **fields):
        specified = 'view' in fields
        view = fields.pop('view', None)
        await original_edit(hook, identifier, **fields)
        if specified:
            hook.lab.posts[str(fields['thread'].id)].messages[str(identifier)].components = [view] if view else []

    monkeypatch.setattr(FollowHook, '_send', send)
    monkeypatch.setattr(FollowHook, 'edit_message', edit)
    return text_sdk


def event(custom_id, message=None, guild='gld-A', user='usr-A'):
    return SimpleNamespace(data={'custom_id': custom_id}, guild_id=guild, user=SimpleNamespace(id=user),
                           message=message, channel_id=getattr(message, 'channel_id', None),
                           response=AsyncMock(), followup=AsyncMock())


def listener(lab):
    return next(fn for fn, name in lab.native.listeners if name == 'on_interaction')


def messages(lab, q):
    return [lab.posts[post].messages[dc] for post, dc in lab.sent(q)]


def buttons(message):
    return message.components[0].children


async def waiting(gate, lab):
    result = await gate.send('alpha', '확인해 주세요', metadata={
        'thread_id': str(uuid.uuid4()), 'hejo_reply_state': 'asked'})
    assert result.success
    mid = result.message_id
    await settled(gate)
    return mid, messages(lab, mid)[-1]


async def test_at_hb_20_render_limits_native_and_long_ids(gate, lab, discord_module):
    q, message = await waiting(gate, lab)
    tag = gate.discord.private()['pair']['tag']
    assert [b.label for b in buttons(message)] == ['○ 승인', '✕ 거절', '✎ 의견', '✓ 확인']
    assert [b.style for b in buttons(message)] == [1, 2, 2, 2]
    assert buttons(message)[0].custom_id == f'hejo:{tag}:{q}:std:approve'
    assert message.content == '확인해 주세요'
    thread = str(uuid.uuid4())
    text = '질' * 2100
    sent = await gate.send('alpha', text, metadata={'thread_id': thread, '_hejo_native_buttons': [
        {'label': '선택' + str(i), 'kind': 'clarify', 'style': 'default'} for i in range(7)]})
    await settled(gate)
    first, last = messages(lab, sent.message_id)
    assert not first.components and len(buttons(last)) == 5 and first.content + last.content == text
    assert [b.label for b in buttons(last)] == ['선택0', '선택1', '선택2', '선택3', '선택6']
    await gate.receive(dict(employee='alpha', thread=thread, text='일반 답', files=[], client_msg_id='plain'),
                       SimpleNamespace(features=set(), send=AsyncMock()))
    await settled(gate)
    assert len(buttons(last)) == 5
    long_id = 'x' * (100 - len(f'hejo:{tag}:{q}:'))
    for extra in ('', 'x'):
        await lab.append('edit', q, buttons=[dict(id=long_id + extra, label='확인', kind='reply', style='default')])
        await settled(gate)
        if extra:
            assert not message.components and '선택: 확인' in message.content and 'hejo 앱에서 눌러 주세요' in message.content
        else:
            assert len(buttons(message)[0].custom_id) == 100


@pytest.mark.parametrize('origin', ['hejo', '디스코드'])
async def test_at_hb_21_22_dispatch_then_retract(gate, lab, turns, monkeypatch, origin):
    q, message = await waiting(gate, lab)
    lab.writes.clear()
    if origin == 'hejo':
        answer_id = (await click(gate, turns, q))['answer_id']
    else:
        press = event(buttons(message)[0].custom_id, message)
        original = gate.click

        async def observed(*args, **kwargs):
            press.response.defer.assert_awaited_once_with(ephemeral=True, thinking=True)
            await original(*args, **kwargs)
        monkeypatch.setattr(gate, 'click', observed)
        await listener(lab)(press)
        answer_id = projected(gate, q)['answer']['answer_id']
        follow = press.followup.send.await_args
        assert follow.args == ('보냈어요',) and follow.kwargs['ephemeral']
        undo = follow.kwargs['view'].children[0]
        assert undo.custom_id == f"hejo:{gate.discord.private()['pair']['tag']}:x:{answer_id}"
    await settled(gate)
    assert turns.sink.await_count == 1
    assert not message.components
    footer = message.content.splitlines()[-1]
    assert [w[0] for w in lab.writes if w[0] in ('edit_message', 'send')] == ['edit_message']
    if origin == 'hejo':
        assert (await change(gate, turns, answer_id))['type'] == 'retract_ack'
    else:
        retract = event(undo.custom_id, SimpleNamespace(components=[follow.kwargs['view']], channel_id=message.channel_id))
        await listener(lab)(retract)
        retract.followup.send.assert_awaited_once_with('취소했어요', ephemeral=True)
    await settled(gate)
    assert projected(gate, q)['answer'] is None and len(buttons(message)) == 4
    assert turns.sink.await_args.args[0].raw_message['_hermes_retract']['answer_id'] == answer_id
    assert [w[0] for w in lab.writes if w[0] in ('edit_message', 'send')] == ['edit_message'] * 2
    assert footer == '○ 승인함 · ' + origin + '에서'


async def test_at_hb_22_source_survives_recovery(gate, lab, turns):
    q, message = await waiting(gate, lab)
    identifier = buttons(message)[0].custom_id
    await listener(lab)(event(identifier, message))
    await settled(gate)
    before = message.content
    restart(gate)
    await lab.restart()
    tag = gate.discord.private()['pair']['tag']
    text, _, view = gate.discord.render_message(gate.journal.message(q), tag)
    assert text == before == message.content and text.endswith('○ 승인함 · 디스코드에서')
    assert view is None
    assert not message.components
    assert turns.sink.await_count == 1


async def test_at_hb_22_app_click_rejects_source_fields(gate, client, lab, turns):
    q, message = await waiting(gate, lab)
    ws, _ = await client.pair()
    frame = dict(v=1, type='click', msg_id=q, button_id='std:approve')
    head = gate.journal.head
    for field in ('origin', 'source'):
        await ws.send_json({**frame, 'id': field, field: 'discord'})
        error = (await client.until(ws, 'error'))[-1]
        assert error['code'] == 'invalid_frame' and error['ref'] == field
        assert gate.journal.head == head and projected(gate, q)['answer'] is None
        turns.sink.assert_not_awaited()

    await ws.send_json(frame)
    ack = (await client.until(ws, 'click_ack'))[-1]
    undo = gate.journal.history.undo(ack['answer_id'])
    assert undo['button_id'] == frame['button_id'] and 'source' not in undo
    await settled(gate)
    assert message.content.endswith('○ 승인함 · hejo에서')
    turns.sink.assert_awaited_once()


async def test_at_hb_23_modal_and_comment_post(gate, lab, turns):
    q, message = await waiting(gate, lab)
    lab.writes.clear()
    press = event(buttons(message)[2].custom_id, message)
    await listener(lab)(press)
    press.response.defer.assert_not_awaited()
    modal = press.response.send_modal.await_args.args[0]
    field, = modal.children
    assert (field.min_length, field.max_length) == (1, 4000)
    field.value = '의견 내용'
    denied = event('modal', user='stranger')
    await modal.on_submit(denied)
    denied.response.send_message.assert_awaited_once_with('사장만 누를 수 있어요', ephemeral=True)
    assert turns.sink.await_count == 0
    submit = event('modal')
    await modal.on_submit(submit)
    await settled(gate)
    assert projected(gate, q)['answer']['text'] == field.value
    assert turns.sink.await_args.args[0].raw_message['_hermes_button']['comment'] is True
    assert [w[-1] for w in lab.writes if w[0] == 'send'] == [field.value]
    assert message.content.endswith('✎ 의견 보냄 · 디스코드에서')


async def test_at_hb_24_25_pair_and_listener_isolation(gate, lab, turns):
    _, message = await waiting(gate, lab)
    identifier = buttons(message)[0].custom_id
    head = gate.journal.head
    for press, why in [(event(identifier, user='other'), '사장만 누를 수 있어요'),
                       (event(identifier, guild='other'), '사장만 누를 수 있어요'),
                       (event(identifier.replace(identifier.split(':')[1], 'previous')), '다시 연결한 뒤에는 hejo에서 눌러 주세요')]:
        await listener(lab)(press)
        press.response.send_message.assert_awaited_once_with(why, ephemeral=True)
        press.response.defer.assert_not_awaited()
    for identifier in ('clarify:1:0', 'model_cancel', 'random', None):
        press = event(identifier)
        await listener(lab)(press)
        assert not press.response.mock_calls and not press.followup.mock_calls
    assert gate.journal.head == head and turns.sink.await_count == 0


async def test_at_hb_26_failures_are_local(gate, lab, turns, caplog):
    q, message = await waiting(gate, lab)
    press = event(buttons(message)[0].custom_id, message)
    press.followup.send.side_effect = ValueError('private-followup')
    lab.post(q).edit_error = OSError('private-edit')
    await listener(lab)(press)
    await settled(gate)
    assert projected(gate, q)['answer']['delivery'] == 'sent'
    failures = [r.getMessage() for r in caplog.records if r.name == 'gate.discord' and 'failed kind=' in r.getMessage()]
    assert failures == ['discord_interaction_failed kind=ValueError', 'discord_update_failed kind=OSError']
    another, _ = await waiting(gate, lab)
    assert lab.sent(another)


async def test_at_hb_27_attach_is_idempotent(registered, transport):
    adapter, native = transport
    attach = registered.get_platform_handler_factories('discord')[0][0]
    attach(native, adapter)
    attach(native, adapter)
    assert [name for _, name in native.listeners] == ['on_message', 'on_interaction']


async def test_at_hb_27b_glyphs_and_native_style(gate, lab):
    labels = ['메모', '메모+노션', '제작해', '선택6', '승인']
    sent = await gate.send('alpha', '선택', metadata={'thread_id': str(uuid.uuid4()), '_hejo_native_buttons': [
        {'label': label, 'kind': 'approval', 'style': 'default'} for label in labels]})
    await settled(gate)
    row = buttons(messages(lab, sent.message_id)[0])
    assert [b.label for b in row] == ['✎ 메모', '✎ 메모+노션', '▶ 제작해', '선택6', '○ 승인']
    assert [b.style for b in row] == [2, 2, 2, 2, 1]


async def test_at_hb_27b_reconcile_fetches_only_waiting_card(gate, lab, turns, monkeypatch):
    for _ in range(3):
        q, old = await waiting(gate, lab)
        await lab.append('edit', q, text='이전 질문')
        await click(gate, turns, q)
        await settled(gate)
        old.content = '옛 질문'
    _, pending = await waiting(gate, lab)
    pending.components = []
    fetched = []
    fetch = ForumPost.fetch_message

    async def observe(post, identifier):
        fetched.append(str(identifier))
        return await fetch(post, identifier)

    monkeypatch.setattr(ForumPost, 'fetch_message', observe)
    lab.writes.clear()
    await lab.restart()
    assert set(fetched) == {pending.id}
    assert [w[2] for w in lab.writes if w[0] == 'edit_message'] == [pending.id]
    assert len(buttons(pending)) == 4


async def test_at_hb_27b_card_updates_while_typing(gate, lab, turns):
    q, message = await waiting(gate, lab)
    meta = {'thread_id': projected(gate, q)['thread']}
    await gate.send_typing('alpha', meta)
    try:
        queued = await gate.send('alpha', '작성 중인 글', metadata=meta)
        answer = await click(gate, turns, q)
        async with asyncio.timeout(4):
            edits = 0
            while message.components:
                edits += 1
                await lab.append('edit', queued.message_id, text=f'작성 중 {edits}')
                await asyncio.sleep(gate.discord.settle_seconds / 5)
        assert message.content.endswith('○ 승인함 · hejo에서') and not lab.sent(queued.message_id)
        await change(gate, turns, answer['answer_id'])
        async with asyncio.timeout(4):
            while not message.components:
                await asyncio.sleep(.01)
        assert len(buttons(message)) == 4 and not lab.sent(queued.message_id)
    finally:
        await gate.stop_typing('alpha', meta)
    await settled(gate)
    assert lab.sent(queued.message_id)


async def test_at_hb_27b_wrong_button_question_and_rotated_modal(gate, lab, turns, client):
    q, first = await waiting(gate, lab)
    other, second = await waiting(gate, lab)
    tag = gate.discord.private()['pair']['tag']
    head = gate.journal.head
    for identifier in (f'hejo:{tag}:{q}:absent', buttons(second)[0].custom_id):
        press = event(identifier, first)
        await listener(lab)(press)
        press.response.send_message.assert_awaited_once_with('지금은 처리할 수 없어요', ephemeral=True)
    # Even a matching component on a different Discord message cannot target the other question.
    first.components, second.components = second.components, first.components
    press = event(buttons(first)[0].custom_id, first)
    await listener(lab)(press)
    press.response.send_message.assert_awaited_once_with('지금은 처리할 수 없어요', ephemeral=True)
    first.components, second.components = second.components, first.components
    press = event(buttons(first)[2].custom_id, first)
    await listener(lab)(press)
    modal = press.response.send_modal.await_args.args[0]
    ws, _ = await client.pair(features=['discord'])
    await pair(gate, client, ws, lab.native)
    assert gate.discord.private()['pair']['tag'] != tag
    modal.children[0].value = '옛 창'
    submit = event('modal')
    await modal.on_submit(submit)
    submit.response.send_message.assert_awaited_once_with('다시 연결한 뒤에는 hejo에서 눌러 주세요', ephemeral=True)
    assert gate.journal.head == head and projected(gate, other)['answer'] is None
    turns.sink.assert_not_awaited()


async def test_at_hb_27b_general_reply_updates_question_once(gate, lab, turns):
    q, message = await waiting(gate, lab)
    lab.writes.clear()
    await gate.receive(dict(employee='alpha', thread=projected(gate, q)['thread'], text='일반 답',
                            files=[], client_msg_id='plain'), turns.conn)
    await settled(gate)
    assert message.content.endswith('\n답변함 · hejo에서') and not message.components
    assert [w[2] for w in lab.writes if w[0] == 'edit_message'] == [message.id]


async def test_at_hb_27b_unknown_delivery(gate, lab, turns):
    q, message = await waiting(gate, lab)
    turns.sink.side_effect = OSError('fixture')
    press = event(buttons(message)[0].custom_id, message)
    await listener(lab)(press)
    press.followup.send.assert_awaited_once_with(
        '답은 기록됐지만 직원에게 갔는지 확인하지 못했어요. hejo에서 다시 보내기를 눌러 주세요.', ephemeral=True)
    assert projected(gate, q)['answer']['delivery'] == 'unknown'
    turns.sink.assert_awaited_once()
