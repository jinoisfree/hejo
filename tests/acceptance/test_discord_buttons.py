"""HEJO-BUTTONS Discord acceptance through the registered listener and FOLLOW webhook."""
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from gate import discord as door
from gate.server import CLIENT_VALIDATOR
from test_buttons import change, click, projected, restart, turns
from test_discord import client, discord_module as text_sdk, gate, named_roster, registered, settled, transport
from test_discord_follow import FollowHook, lab

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


def event(custom_id, guild='gld-A', user='usr-A'):
    return SimpleNamespace(data={'custom_id': custom_id}, guild_id=guild, user=SimpleNamespace(id=user),
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
    assert buttons(last)[-1].label.endswith('선택6')
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
        press = event(buttons(message)[0].custom_id)
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
        retract = event(undo.custom_id)
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
    frame = dict(v=1, type='click', msg_id=q, button_id='std:approve')
    assert CLIENT_VALIDATOR.is_valid(frame)
    assert not CLIENT_VALIDATOR.is_valid(dict(frame, source='discord'))

    await listener(lab)(event(identifier))
    await settled(gate)
    message.content = '확인해 주세요'
    restart(gate)
    await lab.restart()
    assert message.content.endswith('○ 승인함 · 디스코드에서')
    assert not message.components
    assert turns.sink.await_count == 1


async def test_at_hb_23_modal_and_comment_post(gate, lab, turns):
    q, message = await waiting(gate, lab)
    lab.writes.clear()
    press = event(buttons(message)[2].custom_id)
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
    press = event(buttons(message)[0].custom_id)
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
