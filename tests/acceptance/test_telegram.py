"""HEJO-TELEGRAM: real gate and Hermes contracts with an isolated fake transport."""
import asyncio
import json
import logging
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
import uuid

import pytest
from gateway.config import Platform, PlatformConfig
from gateway.platforms.base import BasePlatformAdapter, SendResult
from gateway.platforms.event import MessageEvent
from gate import telegram
from gate.tests.support import airport, registered, gate, runner, client, wait_for_turns

pytestmark = pytest.mark.asyncio
G = '00000000-0000-4000-8000-000000000001'
H = '00000000-0000-4000-8000-000000000002'


class Transport(BasePlatformAdapter):
    def __init__(self):
        super().__init__(PlatformConfig(enabled=True), Platform('hejo'))
        self.calls, self.originals, self.topic_calls, self.wrapped_calls = [], [], [], []
        self.file_calls, self.typing_calls, self.operations = [], [], []
        self.failure = self.topic_failure = self.file_failure = self.typing_failure = False
        self.split = False
        self.accepted = 0
        self.authorized = None
        self._bot = SimpleNamespace(**{name: self.topic_method(name) for name in
            ('create_forum_topic', 'edit_forum_topic', 'close_forum_topic', 'reopen_forum_topic')})
        self._mark_connected()

    def topic_method(self, name):
        async def call(**kwargs):
            self.topic_calls.append((name, kwargs))
            self.operations.append(name)
            if self.topic_failure:
                raise OSError('grp-A topic-sensitive')
            return SimpleNamespace(message_thread_id=f'topic-{len(self.topic_calls)}')
        return call

    async def _create_dm_topic(self, chat_id, name):
        self.wrapped_calls.append('_create_dm_topic')
        logging.getLogger('plugins.platforms.telegram.adapter').warning('topic %s', chat_id)

    async def rename_dm_topic(self, chat_id, topic_id, name):
        self.wrapped_calls.append('rename_dm_topic')
        logging.getLogger('plugins.platforms.telegram.adapter').warning('topic %s %s', chat_id, topic_id)

    def _is_sender_authorized(self, *args):
        return self.authorized

    def _accept_update(self):
        self.accepted += 1

    async def handle_message(self, event):
        self.originals.append(event)

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        self.calls.append((chat_id, content, reply_to, metadata or {}))
        self.operations.append('send')
        mid = f'tg-out-{len(self.calls)}'
        return SendResult(success=not self.failure, message_id=mid,
                          raw_response={'message_ids': [mid, mid+'-2']} if self.split else None)

    async def send_document(self, chat_id, file_path, reply_to=None, metadata=None, **kwargs):
        return await self.file_send('document', chat_id, file_path, reply_to, metadata)

    async def send_image_file(self, chat_id, file_path, reply_to=None, metadata=None, **kwargs):
        return await self.file_send('image', chat_id, file_path, reply_to, metadata)

    async def file_send(self, kind, chat_id, path, reply_to, metadata):
        self.file_calls.append((kind, chat_id, path, reply_to, metadata))
        if self.file_failure == 'exception':
            raise OSError('grp-A d.txt')
        return SendResult(success=not self.file_failure, message_id=f'tg-file-{len(self.file_calls)}')

    async def send_typing(self, chat_id, metadata=None):
        self.typing_calls.append((chat_id, metadata))
        if self.typing_failure:
            raise OSError('grp-A')

    async def connect(self): return True
    async def disconnect(self): pass
    async def get_chat_info(self, chat_id): return {'chat_id': chat_id, 'type': 'group'}

    def event(self, text='hello', chat='grp-A', user='user-A', kind='group', mid='tg-in-1', topic='1', **fields):
        source = replace(self.build_source(chat_id=chat, user_id=user, chat_type=kind, thread_id=topic), platform='telegram')
        raw = fields.pop('raw_message', SimpleNamespace(chat=SimpleNamespace(is_forum=chat != 'grp-N'), caption=None, reply_to_message=None))
        return MessageEvent(text=text, source=source, message_id=mid, raw_message=raw, **fields)


@pytest.fixture
def transport(registered, monkeypatch):
    value = Transport()
    monkeypatch.setattr(telegram, '_telegram', None)
    factories = registered.get_platform_handler_factories('telegram')
    assert len(factories) == 1
    factories[0][0](None, value)
    return value


@pytest.fixture(autouse=True)
def named_roster(gate, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    original = gate.employees
    monkeypatch.setattr(gate, 'employees', lambda: [{**e, 'name': {'alpha':'Alpha', 'beta':'Beta'}.get(e['id'], e['name'])} for e in original()])
    gate.telegram.settle_seconds = .05


async def request(client, ws, kind='telegram', **fields):
    await ws.send_json({'v':1, 'type':kind, 'id':'request', **fields})
    while True:
        frame = await client.read(ws)
        if frame.get('ref') == 'request': return frame


async def pair(client, ws, transport, **fields):
    code = await request(client, ws, 'telegram_pair')
    await transport.handle_message(transport.event(code['code'], **fields))
    assert (await client.read(ws))['paired']
    transport.calls.clear()
    return code


async def group(gate):
    class Sink:
        features = {'rooms'}
        async def send(self, frame): pass
    await gate.room_command({'type':'room_save', 'title':'Team', 'members':['alpha','beta'], 'lead':'alpha'}, Sink())
    identifier = next(iter(gate.journal.rooms))
    return identifier


async def test_at_ht_01_02_code_private_and_rotation(gate, client, transport):
    ws, welcome = await client.pair(features=['telegram'])
    other, _ = await client.open(token=welcome['token'], features=['telegram'])
    first = await request(client, ws, 'telegram_pair')
    code = await request(client, ws, 'telegram_pair')
    assert code == {'v':1,'type':'telegram_code','ref':'request','code':code['code'],'expires_in':600}
    assert len(code['code']) == 12
    stale = transport.event(first['code'])
    await transport.handle_message(stale)
    assert transport.originals == [stale] and gate.telegram.private()['pair'] is None
    await transport.handle_message(transport.event(code['code']))
    assert (await client.read(ws))['paired']
    status = await client.read(other)
    assert status['paired'] and not status['enabled'] and 'ref' not in status
    private = gate.telegram.private()
    assert private['pair']['platform'] == 'telegram' and len(private['pair']['tag']) == 8
    assert (gate.telegram.vault.path/'telegram.json').stat().st_mode & 0o777 == 0o600
    assert transport.calls == [('grp-A','연결됐어요',None,{'thread_id':'1'})]
    assert gate.journal.head == 0


@pytest.mark.parametrize('case', ['wrong','expired','used','nonforum','dm','denied'])
async def test_at_ht_03_invalid_pair_passes_same_object(gate, client, transport, case):
    ws,_ = await client.pair(features=['telegram'])
    code = await request(client,ws,'telegram_pair')
    if case == 'used':
        await transport.handle_message(transport.event(code['code']))
        await client.read(ws); transport.calls.clear()
    before = gate.telegram.private()['pair']
    if case == 'expired': gate.telegram.clock = lambda: 10**12
    if case == 'denied': transport.authorized = False
    event = transport.event('wrong' if case == 'wrong' else code['code'], chat='grp-N' if case == 'nonforum' else 'grp-A', kind='dm' if case=='dm' else 'group')
    await transport.handle_message(event)
    assert transport.originals == [event] and transport.originals[0] is event
    assert not transport.calls and gate.telegram.private()['pair'] == before and gate.journal.head == 0


async def test_at_ht_06_09_10_11_mask_and_unavailable(gate, client, transport, registered, monkeypatch):
    ws,welcome = await client.pair(features=['telegram'])
    old,_ = await client.open(token=welcome['token'],features=['rooms','imessage'])
    assert (await request(client,old))['code']=='unexpected_frame'
    for kind in ('imessage','imessage_pair'):
        assert (await request(client,old,kind))['code']=='unexpected_frame'
    assert not registered.get_platform_handler_factories('photon')
    assert len(registered.get_platform_handler_factories('telegram'))==1
    path = gate.telegram.settings_store.path/'settings.json'
    assert (await request(client,ws,'telegram_save',enabled=True))['code']=='telegram_unpaired'
    assert not path.exists()
    monkeypatch.setattr(telegram,'_telegram',None)
    assert (await request(client,ws,'telegram_pair'))['code']=='telegram_unavailable'
    assert gate.telegram.private()['code'] is None
    assert not (await request(client,ws))['platform_ready']
    await old.send_json({'v':1,'type':'roster','id':'boundary'})
    assert (await client.read(old))['type']=='roster'


async def test_at_ht_08_settings_and_reconstruction(gate, client, transport):
    ws,welcome=await client.pair(features=['telegram'])
    other,_=await client.open(token=welcome['token'],features=['telegram'])
    await pair(client,ws,transport); await client.read(other)
    status=await request(client,ws,'telegram_save',enabled=True)
    assert await client.read(other)=={k:v for k,v in status.items() if k!='ref'}
    assert (gate.telegram.settings_store.path/'settings.json').stat().st_mode & 0o777==0o600
    fresh=telegram.Telegram(gate,gate.telegram.vault.path.parent)
    assert fresh.settings()=={'enabled':True}
    await fresh.close()
