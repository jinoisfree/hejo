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
    await gate.send('alpha','topic failure',metadata={'thread_id':str(uuid.uuid4())})
    await settled(gate)
    assert not transport.calls
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


async def settled(gate):
    await until(lambda: not gate.telegram.pending and not gate.telegram.workers)


async def test_at_ht_14_new_roster_room_on_send(gate,client,transport,monkeypatch):
    ws,_=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    original=gate.employees
    monkeypatch.setattr(gate,'employees',lambda: original()+[{'id':'gamma','name':'Gamma','aliases':[]}])
    transport.topic_calls.clear();transport.operations.clear()
    await gate.send('gamma','new room',metadata={'thread_id':str(uuid.uuid4())})
    await settled(gate)
    assert transport.topic_calls==[('create_forum_topic',{'chat_id':'grp-A','name':'Gamma'})]
    assert transport.operations==['create_forum_topic','send']
    assert transport.calls[-1][3]['thread_id']==gate.telegram.topics(gate.telegram.private()['pair']['tag'])['topics']['gamma']['topic']


async def test_at_ht_30_31_32_35_order_settling_and_buttons(gate,client,transport,runner):
    ws,_=await client.pair(features=['rooms','telegram'])
    _,topics=await activate(gate,client,ws,transport)
    thread=str(uuid.uuid4())
    await client.send(ws,thread=thread,text='ping')
    await wait_for_turns(runner,1)
    await gate.send('alpha','pong',metadata={'thread_id':thread})
    await settled(gate)
    assert transport.calls[:2]==[
        ('grp-A','[사장] ping',None,{'thread_id':topics['alpha']['topic']}),
        ('grp-A','[Alpha] pong','tg-out-1',{'thread_id':topics['alpha']['topic'],'notify':True})]
    thread2=str(uuid.uuid4())
    await gate.send_typing('alpha',{'thread_id':thread2})
    await gate.send('alpha','waiting',metadata={'thread_id':thread2})
    await asyncio.sleep(.15)
    assert not any(call[1]=='[Alpha] waiting' for call in transport.calls)
    await gate.stop_typing('alpha',{'thread_id':thread2});await settled(gate)
    assert sum(call[1]=='[Alpha] waiting' for call in transport.calls)==1
    await gate.send('alpha','🤔 생각 중…\nprivate thought',metadata={'thread_id':str(uuid.uuid4())})
    await settled(gate)
    assert not any('private thought' in call[1] for call in transport.calls)
    await transport.handle_message(transport.event(topic=topics['alpha']['topic']))
    await settled(gate)
    assert not any(call[1]=='[사장] hello' for call in transport.calls)
    await gate.send('alpha','choose',metadata={'thread_id':str(uuid.uuid4()),'hejo_buttons':[{'label':'A','style':'primary'},{'label':'B','style':'default'}],
        '_hejo_native_buttons':[{'label':'Open','kind':'approval','style':'default'}]})
    await settled(gate)
    assert transport.calls[-1][1]=='[Alpha] choose\n선택: A / B\n(이 선택은 hejo 앱에서 눌러 주세요)'


async def test_at_ht_33_group_order_and_anchor(gate,client,transport):
    ws,_=await client.pair(features=['telegram'])
    group_id,topics=await activate(gate,client,ws,transport)
    thread=str(uuid.uuid4())
    for employee,text in [('beta','a'),('alpha','b'),('beta','c')]:
        await gate.send('room:'+group_id,text,metadata={'hermes_profile':employee,'thread_id':thread})
    await settled(gate)
    assert [call[1] for call in transport.calls]==['[Beta] a','[Alpha] b','[Beta] c']
    assert [call[2] for call in transport.calls]==[None,'tg-out-1','tg-out-1']
    assert all(call[3]=={'thread_id':topics[group_id]['topic'],'notify':True} for call in transport.calls)


async def test_at_ht_34_files_preflight_and_runtime_failure(gate,client,transport,tmp_path,caplog):
    ws,_=await client.pair(features=['telegram'])
    _,topics=await activate(gate,client,ws,transport)
    picture=tmp_path/'p.png';picture.write_bytes(b'fixture picture')
    document=tmp_path/'d.txt';document.write_text('fixture document')
    # Existing public file sends create ordinary message rows; one row carries both files.
    files=[]
    for path in (picture,document):
        staged=await gate.files.copy('alpha',path)
        promoted,_=gate.files.promote('alpha',[staged['file_id']]);files.extend(promoted)
    from datetime import datetime,timezone
    thread=str(uuid.uuid4())
    await gate._record({'type':'message','employee':'alpha','thread':thread,'role':'employee','msg_id':str(uuid.uuid4()),
        'text':'files','files':files,'buttons':[],'reply_state':None,'ts':datetime.now(timezone.utc).isoformat()},
        {'files':gate.files.registration('alpha','employee',files)})
    await settled(gate)
    assert [call[0] for call in transport.file_calls]==['image','document']
    assert all(call[3]=='tg-out-1' and call[4]['thread_id']==topics['alpha']['topic'] for call in transport.file_calls)
    missing={'file_id':str(uuid.uuid4()),'name':'x.bin','mime':'application/octet-stream','size':1}
    await gate._record({'type':'message','employee':'alpha','thread':str(uuid.uuid4()),'role':'employee','msg_id':str(uuid.uuid4()),
        'text':'missing','files':[missing],'buttons':[],'reply_state':None,'ts':datetime.now(timezone.utc).isoformat()})
    await settled(gate)
    assert transport.calls[-1][1].endswith('📎 x.bin (hejo 앱에서 열기)') and len(transport.file_calls)==2
    for failure in [True,'exception']:
        caplog.clear();transport.file_failure=failure
        before=len(transport.calls);before_files=len(transport.file_calls)
        await gate.send_document('alpha',str(document),caption='runtime',metadata={'thread_id':str(uuid.uuid4())})
        await settled(gate);await asyncio.sleep(.15)
        assert len(transport.calls)==before+1 and '📎' not in transport.calls[-1][1]
        assert len(transport.file_calls)==before_files+1
        logs=[r.message for r in caplog.records if r.name=='gate.telegram']
        assert len(logs)==1 and 'grp-A' not in logs[0] and 'd.txt' not in logs[0]


async def test_at_ht_22_23_36_45_reply_split_restart_and_repair(gate,client,transport):
    ws,_=await client.pair(features=['telegram'])
    _,topics=await activate(gate,client,ws,transport)
    await transport.handle_message(transport.event(topic=topics['alpha']['topic']))
    key=gate.journal.message_threads[gate.journal.records[-1]['msg_id']]
    transport.split=True
    reply=await gate.send('alpha','answer',metadata={'thread_id':key[1]})
    await settled(gate)
    assert transport.calls[-1][2]=='tg-in-1'
    rows=[json.loads(line) for line in gate.telegram.sent_path.read_text().splitlines()]
    assert len(rows)==2 and all(row['msg_id']==reply.message_id for row in rows)
    home=gate.telegram.vault.path.parent
    await gate.telegram.close();gate.telegram=telegram.Telegram(gate,home);gate.telegram.settle_seconds=.05
    await transport.handle_message(transport.event('reply',topic=topics['alpha']['topic'],mid='reply',reply_to_message_id='tg-out-1-2'))
    assert gate.journal.message_threads[gate.journal.records[-1]['msg_id']]==key
    old_tag=gate.telegram.private()['pair']['tag']
    await pair(client,ws,transport)
    await request(client,ws,'telegram_save',enabled=True)
    tag=gate.telegram.private()['pair']['tag'];assert tag!=old_tag
    await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
    topic=gate.telegram.topics(tag)['topics']['alpha']['topic']
    await transport.handle_message(transport.event('old reply',topic=topic,mid='new-reply',reply_to_message_id='tg-out-1'))
    assert gate.journal.records[-1]['thread']!=key[1]
    before=gate.journal.head
    await transport.handle_message(transport.event(topic=topic))
    assert gate.journal.head==before+1 and gate.journal.records[-1]['client_msg_id']==f'telegram:{tag}:tg-in-1'


async def test_at_ht_37_38_failure_no_retry_or_backfill(gate,client,transport,caplog):
    ws,_=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    transport.failure=True;caplog.clear()
    await gate.send('alpha','sensitive-body',metadata={'thread_id':str(uuid.uuid4())})
    await settled(gate);await asyncio.sleep(.15)
    assert len(transport.calls)==1
    logs=[r.message for r in caplog.records if r.name=='gate.telegram']
    assert len(logs)==1 and all(value not in logs[0] for value in ['grp-A','sensitive-body','tg-out'])
    await request(client,ws,'telegram_save',enabled=False)
    await gate.send('alpha','disabled-body',metadata={'thread_id':str(uuid.uuid4())})
    await request(client,ws,'telegram_save',enabled=True)
    await asyncio.sleep(.15)
    assert len(transport.calls)==1


@pytest.mark.parametrize('broken',['telegram.json','settings.json','topics.json','sent.jsonl'])
async def test_at_ht_40_corrupt_stores_do_not_block_connect(gate,client,transport,broken):
    ws,_=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    home=gate.telegram.vault.path.parent
    sent_before={}
    if broken=='sent.jsonl':
        await gate.send('alpha','persisted',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
        sent_before=dict(gate.telegram.sent)
    path=(gate.telegram.vault.path if broken=='telegram.json' else gate.telegram.settings_store.path)/broken
    if broken=='sent.jsonl':
        with path.open('ab') as stream: stream.write(b'broken middle\n{"partial":')
    else: path.write_text('{broken')
    await gate.disconnect()
    assert await gate.connect()
    assert gate.is_connected
    transport.calls.clear()
    if broken in {'telegram.json','settings.json'}:
        event=transport.event();await transport.handle_message(event)
        await gate.send('alpha','blocked',metadata={'thread_id':str(uuid.uuid4())})
        await asyncio.sleep(.15)
        assert transport.originals==[event] and not transport.calls
    elif broken=='topics.json':
        tag=gate.telegram.private()['pair']['tag']
        await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
    else:
        assert gate.telegram.sent==sent_before and path.read_bytes().endswith(b'\n')


async def test_at_ht_41_typing_throttle_and_failure(gate,client,transport,caplog):
    ws,_=await client.pair(features=['telegram'])
    _,topics=await activate(gate,client,ws,transport)
    thread=str(uuid.uuid4())
    for _ in range(3): await gate.send_typing('alpha',{'thread_id':thread})
    await asyncio.sleep(5)
    await gate.send_typing('alpha',{'thread_id':thread})
    await until(lambda: len(transport.typing_calls)==2)
    assert transport.typing_calls==[('grp-A',{'thread_id':topics['alpha']['topic']})]*2 and not transport.calls
    caplog.clear();transport.typing_failure=True
    await gate.send_typing('beta',{'thread_id':str(uuid.uuid4())})
    await asyncio.sleep(.02)
    assert sum('telegram_typing_failed' in r.message for r in caplog.records)==1
    await gate.stop_typing('alpha',{'thread_id':thread})
    await gate.send('alpha','still works',metadata={'thread_id':thread});await settled(gate)
    assert transport.calls[-1][1]=='[Alpha] still works'


async def test_at_ht_07_private_values_have_only_authorized_sinks(gate,client,transport,caplog):
    caplog.set_level(logging.DEBUG)
    ws,welcome=await client.pair(features=['rooms','telegram'])
    other,_=await client.open(token=welcome['token'],features=['rooms','telegram'])
    group_id=await group(gate)
    code=await request(client,ws,'telegram_pair')
    await transport.handle_message(transport.event(code['code']))
    await request(client,ws,'telegram_save',enabled=True)
    tag=gate.telegram.private()['pair']['tag']
    await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    sink=Sink()
    await gate.room_command({'type':'room_save','title':'Ops','members':['alpha','beta'],'lead':'alpha'},sink)
    identifier=next(i for i,r in gate.journal.rooms.items() if r['title']=='Ops')
    await until(lambda: identifier in gate.telegram.topics(tag)['topics'])
    await gate.room_command({'type':'room_save','id':identifier,'title':'Ops2','members':['alpha','beta'],'lead':'alpha'},sink)
    await until(lambda: gate.telegram.topics(tag)['topics'][identifier]['name']=='Ops2')
    await gate.room_command({'type':'room_archive','id':identifier,'archived':True},sink)
    await until(lambda: gate.telegram.topics(tag)['topics'][identifier]['closed'])
    topic=gate.telegram.topics(tag)['topics']['alpha']['topic']
    await transport.handle_message(transport.event('hello',topic=topic))
    thread=gate.journal.records[-1]['thread']
    await gate.send('alpha','pong',metadata={'thread_id':thread});await settled(gate)
    frames=[]
    for peer in [ws,other]:
        await peer.send_json({'v':1,'type':'roster','id':'privacy-boundary'})
        while True:
            frame=await client.read(peer);frames.append(frame)
            if frame.get('ref')=='privacy-boundary': break
    # The only code frame was already read by the requester. No code appears elsewhere.
    assert code['code'] not in json.dumps(frames)
    private=(gate.telegram.vault.path/'telegram.json').read_text()
    public_stores=''.join((gate.telegram.settings_store.path/name).read_text() for name in ['settings.json','topics.json','sent.jsonl'])
    journal=json.dumps(gate.journal.records)
    for secret in ['grp-A','user-A']:
        assert secret in private
        assert secret not in public_stores+json.dumps(frames)+journal+caplog.text
    for secret in ['hello','pong',code['code']]:
        assert secret not in private+public_stores+caplog.text
    assert tag not in caplog.text and 'topic-' not in caplog.text and 'tg-' not in caplog.text
    for frame in frames:
        if frame['type']!='message':
            assert all(secret not in json.dumps(frame) for secret in [tag,'tg-in-1','tg-out-1','hello','pong'])
    assert not transport.wrapped_calls


async def test_at_ht_39_same_journal_and_app_frames_when_enabled(gate,client,transport,monkeypatch,tmp_path):
    import re
    from hermes_cli.profiles import create_profile
    outputs=[]
    await gate.disconnect()
    for enabled in [True,False]:
        home=tmp_path/('active' if enabled else 'inactive');home.mkdir()
        monkeypatch.setenv('HERMES_HOME',str(home))
        for name in ['alpha','beta']: create_profile(name,no_alias=True,no_skills=True)
        assert await gate.connect()
        gate.telegram.settle_seconds=.05
        handled=[]
        async def handle(event): handled.append(event)
        gate.set_message_handler(handle)
        control,_=await client.pair(features=['telegram'])
        group_id=await group(gate)
        if enabled:
            await pair(client,control,transport)
            await request(client,control,'telegram_save',enabled=True)
            tag=gate.telegram.private()['pair']['tag']
            await until(lambda: len(gate.telegram.topics(tag)['topics'])==4)
        transport.calls.clear()
        ws,_=await client.pair(features=['rooms'])
        observed=[]
        for room in ['alpha',group_id]:
            thread=str(uuid.uuid4())
            before_turns=len(handled)
            await client.send(ws,thread=thread,text='owner fixture',**({'room':room} if room==group_id else {}))
            # Observe owner commit before delivering employee turns.
            observed.extend(await client.until(ws,'message'))
            await until(lambda: len(handled)>before_turns and not gate._active_sessions)
            chat='room:'+room if room==group_id else room
            metadata={'thread_id':thread,'hermes_profile':'alpha'}
            await gate.send_typing(chat,metadata)
            first=await gate.send(chat,'draft',metadata=metadata)
            assert (await gate.edit_message(chat,first.message_id,'edited',metadata=metadata)).success
            doomed=await gate.send(chat,'removed',metadata=metadata)
            from gate.adapter import _delivery_scope
            token=_delivery_scope.set(('alpha',chat,thread))
            try:
                assert await gate.delete_message(chat,doomed.message_id)
            finally:
                _delivery_scope.reset(token)
            await gate.send(chat,'reply',reply_to=first.message_id,metadata={**metadata,'hejo_buttons':[{'label':'A','style':'primary'}]})
            file=home/'sample.txt';file.write_text('fixture bytes')
            await gate.send_document(chat,str(file),caption='attachment',metadata=metadata)
            await gate.stop_typing(chat,metadata)
        await settled(gate)
        frames=observed
        await ws.send_json({'v':1,'type':'roster','id':'end'})
        while True:
            frame=await client.read(ws)
            if frame.get('ref')=='end': break
            frames.append(frame)
        def normalize(value):
            if isinstance(value,dict): return {normalize(key):normalize(item) for key,item in value.items() if key not in {'ts','at'}}
            if isinstance(value,list): return [normalize(item) for item in value]
            if isinstance(value,str):
                return re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','<uuid>',value.replace(str(home),'<home>'))
            return value
        outputs.append((normalize(gate.journal.records),normalize(frames)))
        assert bool(transport.calls)==enabled
        await ws.close();await control.close();await gate.disconnect()
    (tmp_path/'compare.json').write_text(json.dumps(outputs,indent=2))
    assert outputs[0]==outputs[1]


async def test_at_ht_08_reconnect_retains_paired_enabled_state(gate,client,transport):
    ws,welcome=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    pair_before=gate.telegram.private()['pair']
    await gate.disconnect()
    assert await gate.connect()
    ws,_=await client.open(token=welcome['token'],features=['telegram'])
    state=await request(client,ws)
    assert state['paired'] and state['enabled'] and state['platform_ready']
    assert gate.telegram.private()['pair']==pair_before


async def test_at_ht_10_no_feature_peer_receives_no_status_or_code(gate,client,transport):
    ws,welcome=await client.pair(features=['telegram'])
    old,_=await client.open(token=welcome['token'])
    assert (await request(client,old))['code']=='unexpected_frame'
    await activate(gate,client,ws,transport)
    await old.send_json({'v':1,'type':'roster','id':'legacy-boundary'})
    frames=await client.until(old,'roster')
    assert not any(frame['type'] in {'telegram_code','telegram_status'} for frame in frames)


async def test_at_ht_42_retired_implementation_absent():
    root=Path(__file__).resolve().parents[2]
    for directory in ['gate','schemas','app/Sources','app/Tests']:
        for path in (root/directory).rglob('*'):
            if path.suffix not in {'.py','.swift','.json'}: continue
            for line in path.read_text().splitlines():
                if path.name=='ConnectionsWindow.swift' and 'photon' in line: continue
                assert not any(word in line.lower() for word in ['imessage','photon']),str(path.relative_to(root))
    for name in ['RoomMenus.swift','RoomDialogs.swift','ConversationView.swift']:
        assert 'telegram' not in (root/'app/Sources'/name).read_text().lower()


async def test_topic_io_rechecks_latest_message_and_typing(gate,client,transport,monkeypatch):
    ws,_=await client.pair(features=['telegram'])
    await activate(gate,client,ws,transport)
    original=gate.employees
    monkeypatch.setattr(gate,'employees',lambda: original()+[{'id':'gamma','name':'Gamma','aliases':[]}])
    entered,release=asyncio.Event(),asyncio.Event()
    create=transport._bot.create_forum_topic
    async def delayed(**fields):
        if fields['name']=='Gamma':
            entered.set();await release.wait()
        return await create(**fields)
    transport._bot.create_forum_topic=delayed
    thread=str(uuid.uuid4())
    message=await gate.send('gamma','old',metadata={'thread_id':thread})
    await asyncio.wait_for(entered.wait(),3)
    assert (await gate.edit_message('gamma',message.message_id,'new')).success
    await gate.send_typing('gamma',{'thread_id':thread})
    release.set();await asyncio.sleep(.15)
    assert not transport.calls
    await gate.stop_typing('gamma',{'thread_id':thread});await settled(gate)
    assert [call[1] for call in transport.calls]==['[Gamma] new']
