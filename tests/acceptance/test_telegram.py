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
    monkeypatch.setattr(gate, 'employees', lambda: [{**e, 'name': {'default':'Main', 'alpha':'Alpha', 'beta':'Beta'}.get(e['id'], e['name'])} for e in original()])
    gate.telegram.settle_seconds = .05


async def request(client, ws, kind='telegram', **fields):
    await ws.send_json({'v':1, 'type':kind, 'id':'request', **fields})
    while True:
        frame = await client.read(ws)
        if frame.get('ref') == 'request': return frame


async def pair(client, ws, transport, **fields):
    code = await request(client, ws, 'telegram_pair')
    await transport.handle_message(transport.event(code['code'], **fields))
    assert (await client.until(ws,'telegram_status'))[-1]['paired']
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
    assert (await client.until(ws,'telegram_status'))[-1]['paired']
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


async def until(predicate):
    async with asyncio.timeout(3):
        while not predicate(): await asyncio.sleep(.01)


async def activate(gate, client, ws, transport):
    group_id = await group(gate)
    await pair(client, ws, transport)
    await request(client,ws,'telegram_save',enabled=True)
    tag=gate.telegram.private()['pair']['tag']
    await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
    transport.calls.clear();transport.accepted=0
    return group_id,gate.telegram.topics(tag)['topics']


async def test_at_ht_04_05_topics_and_unpair_repair(gate,client,transport):
    ws,_=await client.pair(features=['telegram'])
    _,topics=await activate(gate,client,ws,transport)
    old_tag=gate.telegram.private()['pair']['tag']
    path=gate.telegram.settings_store.path/'topics.json'
    before=path.read_bytes()
    state=await request(client,ws,'telegram_unpair')
    assert not state['enabled'] and not state['paired'] and state['ref']=='request'
    event=transport.event(topic=topics['alpha']['topic'])
    await transport.handle_message(event)
    assert transport.originals==[event] and path.read_bytes()==before
    for chat,user in [('grp-B','user-B'),('grp-A','user-A')]:
        transport.topic_calls.clear()
        await pair(client,ws,transport,chat=chat,user=user)
        await request(client,ws,'telegram_save',enabled=True)
        tag=gate.telegram.private()['pair']['tag']
        assert tag!=old_tag
        await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
        assert [args['chat_id'] for name,args in transport.topic_calls if name=='create_forum_topic']==[chat]*4
        old_tag=tag


async def test_at_ht_12_13_topic_lifecycle(gate,client,transport):
    ws,_=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    assert sorted(args['name'] for name,args in transport.topic_calls)==['Alpha','Beta','Main','Team']
    await request(client,ws,'telegram_save',enabled=False)
    await request(client,ws,'telegram_save',enabled=True)
    await asyncio.sleep(.05)
    assert len(transport.topic_calls)==4
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    sink=Sink()
    for frame,method in [
        ({'type':'room_save','title':'Ops','members':['alpha','beta'],'lead':'alpha'},'create_forum_topic'),
        ({'type':'room_save','title':'Ops2','members':['alpha','beta'],'lead':'alpha'},'edit_forum_topic'),
        ({'type':'room_archive','archived':True},'close_forum_topic'),
        ({'type':'room_archive','archived':False},'reopen_forum_topic'),
        ({'type':'room_delete'},'close_forum_topic')]:
        before=len(transport.topic_calls)
        if method!='create_forum_topic': frame['id']=identifier
        await gate.room_command(frame,sink)
        if method=='create_forum_topic': identifier=next(i for i,r in gate.journal.rooms.items() if r['title']=='Ops')
        await until(lambda: len(transport.topic_calls)>before)
        assert transport.topic_calls[-1][0]==method
        tag=gate.telegram.private()['pair']['tag']
        entry=gate.telegram.topics(tag)['topics'][identifier]
        assert entry['closed']==(method=='close_forum_topic')
    assert not transport.wrapped_calls


async def test_at_ht_15_topic_failure_redacted(gate,client,transport,caplog):
    ws,_=await client.pair(features=['telegram'])
    await group(gate);await pair(client,ws,transport)
    transport.topic_failure=True
    await request(client,ws,'telegram_save',enabled=True)
    await until(lambda: gate.telegram.topic_problem)
    assert 'grp-A' not in caplog.text and 'topic-sensitive' not in caplog.text
    assert any('telegram_topic_failed' in r.message for r in caplog.records)
    assert not transport.wrapped_calls
    transport.topic_failure=False
    await request(client,ws,'telegram_save',enabled=False)
    await request(client,ws,'telegram_save',enabled=True)
    await until(lambda: not gate.telegram.topic_problem)


async def test_at_ht_16_20_21_22_23_25_27_routing(gate,client,transport,runner):
    ws,_=await client.pair(features=['rooms','telegram'])
    group_id,topics=await activate(gate,client,ws,transport)
    start=gate.journal.head
    event=transport.event(topic=topics['alpha']['topic'])
    await transport.handle_message(event)
    await wait_for_turns(runner,1)
    row=gate.journal.records[-1];key=gate.journal.message_threads[row['msg_id']]
    tag=gate.telegram.private()['pair']['tag']
    assert row['text']=='hello' and row['employee']=='alpha' and 'room' not in row
    assert row['client_msg_id']==f'telegram:{tag}:tg-in-1' and gate.journal.head==start+1
    assert transport.accepted==1 and not transport.originals and not transport.calls
    assert (await client.until(ws,'message'))[-1]['client_msg_id']==row['client_msg_id']
    await transport.handle_message(event)
    assert gate.journal.head==start+1
    for index,(text,employee) in enumerate([('hi','alpha'),('@Beta hi','beta')]):
        await transport.handle_message(transport.event(text,topic=topics[group_id]['topic'],mid=f'group-{index}'))
        await wait_for_turns(runner,index+2)
        assert runner.events[-1].source.profile==employee
        assert gate.journal.records[-1]['room']==group_id
    await transport.handle_message(transport.event('reply',topic=topics['beta']['topic'],mid='reply',reply_to_message_id='tg-in-1'))
    assert gate.journal.message_threads[gate.journal.records[-1]['msg_id']]==key
    for mid,reply in [('root',topics['alpha']['topic']),('unknown','unknown-id')]:
        await transport.handle_message(transport.event(mid,topic=topics['alpha']['topic'],mid=mid,reply_to_message_id=reply))
        assert gate.journal.records[-1]['thread']!=key[1]
    class Sink:
        features={'rooms'}
        async def send(self, frame): pass
    await gate.thread_delete({'room':'alpha','thread':key[1]}, Sink())
    await transport.handle_message(transport.event('deleted',topic=topics['alpha']['topic'],mid='deleted',reply_to_message_id='tg-in-1'))
    assert gate.journal.records[-1]['thread']!=key[1]
    for topic in ['1','topic-99']:
        before=gate.journal.head
        await transport.handle_message(transport.event(topic=topic,mid=topic))
        assert gate.journal.head==before
        assert transport.calls[-1][1]=='앱에서 만든 방 토픽에 써 주세요'
        assert transport.calls[-1][3]['thread_id']==topic
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    await gate.room_command({'type':'room_archive','id':group_id,'archived':True},Sink())
    before=gate.journal.head
    await transport.handle_message(transport.event(topic=topics[group_id]['topic'],mid='archived'))
    assert gate.journal.head==before and transport.calls[-1][1]=='앱에서 만든 방 토픽에 써 주세요'


@pytest.mark.parametrize('case',['no_pair','disabled','user','chat','dm','claim_exception'])
async def test_at_ht_26_unclaimed_same_object(gate,client,transport,case,monkeypatch):
    ws,_=await client.pair(features=['telegram'])
    if case!='no_pair': await activate(gate,client,ws,transport)
    if case=='disabled': await request(client,ws,'telegram_save',enabled=False)
    if case=='claim_exception': monkeypatch.setattr(gate.telegram,'_private',lambda: (_ for _ in ()).throw(OSError()))
    event=transport.event(chat='grp-B' if case=='chat' else 'grp-A',user='user-B' if case=='user' else 'user-A',kind='dm' if case=='dm' else 'group')
    before=gate.journal.head
    source=replace(event.source)
    await transport.handle_message(event)
    assert transport.originals==[event] and transport.originals[0] is event and event.source==source
    assert gate.journal.head==before and not transport.calls


async def test_at_ht_24_28_attachments_and_receive_failures(gate,client,transport,runner,tmp_path,monkeypatch):
    ws,_=await client.pair(features=['telegram'])
    _,topics=await activate(gate,client,ws,transport)
    for n,(text,caption,inlined) in enumerate([('look',None,[]),('',None,[]),('caption\n[문서 내용]','caption',[True])]):
        file=tmp_path/f'in-{n}.txt';file.write_bytes(b'fixture attachment')
        event=transport.event(text,topic=topics['alpha']['topic'],mid=f'file-{n}',media_urls=[str(file)],media_types=['text/plain'],media_text_inlined=inlined)
        event.raw_message.caption=caption
        await transport.handle_message(event)
        row=gate.journal.records[-1]
        assert row['text']==('caption' if inlined else text) and len(row['files'])==1
        path,_=gate.files.registered('alpha',row['files'][0]['file_id'])
        assert path.read_bytes()==b'fixture attachment'
    before=gate.journal.head
    with patch.object(gate.files,'copy',side_effect=OSError('grp-A')):
        await transport.handle_message(event.__class__(**{**event.__dict__,'message_id':'fail-file'}))
    assert gate.journal.head==before and transport.calls[-1][1]=='지금은 받지 못했어요'
    from gate.server import LIMITS
    await transport.handle_message(transport.event('x'*(LIMITS['text_bytes']+1),mid='too-long',topic=topics['alpha']['topic']))
    assert gate.journal.head==before and transport.calls[-1][1]=='지금은 받지 못했어요' and not transport.originals


async def test_pair_consumed_between_claim_and_admission(gate,client,transport):
    ws,_=await client.pair(features=['telegram'])
    code=await request(client,ws,'telegram_pair')
    event=transport.event(code['code'])
    original=gate.telegram.receive_external
    async def competing_admission(event):
        with gate.telegram.vault.locked():
            value=gate.telegram.private()
            value['code']['used']=True
            gate.telegram.vault.write('telegram.json',value)
        return await original(event)
    with patch.object(gate.telegram,'receive_external',side_effect=competing_admission):
        await transport.handle_message(event)
    assert transport.originals==[event] and transport.originals[0] is event
    assert not transport.calls and transport.accepted==0 and gate.journal.head==0
