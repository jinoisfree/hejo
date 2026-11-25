"""HEJO-DISCORD acceptance: real gate/journal, isolated Discord network objects."""
import asyncio
from datetime import datetime, timezone
import importlib
import json
import logging
from pathlib import Path
import re
import sys
from types import SimpleNamespace, ModuleType
from unittest.mock import AsyncMock, MagicMock
import uuid

import pytest
from gateway.config import Platform, PlatformConfig
from gateway.platforms.base import BasePlatformAdapter
from gate import discord as door
from gate.tests.support import airport, registered, gate, runner, client, wait_for_turns

pytestmark = pytest.mark.asyncio


class NotFound(Exception):
    status = 404


class FakeFile:
    def __init__(self, path): self.path, self.closed = Path(path), False
    def close(self): self.closed = True


@pytest.fixture(autouse=True)
def discord_module(monkeypatch):
    # Hermes' own test precedent: the SDK is absent and must not be installed for tests.
    module = MagicMock()
    module.DMChannel = type('DMChannel', (), {})
    module.Thread = type('Thread', (), {})
    module.ForumChannel = type('ForumChannel', (), {})
    module.Client = MagicMock
    module.File = FakeFile
    module.Object = lambda *, id: SimpleNamespace(id=id)
    module.NotFound = NotFound
    module.AllowedMentions.none.side_effect = lambda: SimpleNamespace(everyone=False, users=False, roles=False, replied_user=False)
    module.ui = SimpleNamespace(View=object, button=lambda *a, **k: lambda fn: fn, Button=object)
    module.ButtonStyle = SimpleNamespace(success=1, primary=2, secondary=2, danger=3, green=1, grey=2, blurple=2, red=3)
    module.Color = SimpleNamespace(orange=lambda: 1, green=lambda: 2, blue=lambda: 3, red=lambda: 4, purple=lambda: 5)
    module.Interaction = object
    module.app_commands = SimpleNamespace(describe=lambda **kw: lambda fn: fn, choices=lambda **kw: lambda fn: fn,
                                         Choice=lambda **kw: SimpleNamespace(**kw))
    ext = MagicMock(); commands = MagicMock(); commands.Bot = MagicMock; ext.commands = commands
    for name, value in [('discord', module), ('discord.ext', ext), ('discord.ext.commands', commands)]:
        monkeypatch.setitem(sys.modules, name, value)
    return module


class Channel:
    def __init__(self, native, identifier, name='', parent=None, starter=False, category=None):
        self.native, self.id, self.name = native, identifier, name
        self.category, self.starter = category, starter
        self.hooks = []
        if parent is not None: self.parent_id = parent

    async def send(self, text): self.native.notices.append((self.id, text))
    async def edit(self, **fields):
        self.native.operations.append(('edit', self.id, fields))
        for key, value in fields.items(): setattr(self, key, value)
    async def webhooks(self): return list(self.hooks)
    async def create_webhook(self, name):
        self.native.operations.append(('webhook', self.id, name))
        hook = Hook(self.native, self)
        self.hooks.append(hook)
        return hook


class Hook:
    name = 'hejo'
    id, token = 'fake-hook-id', 'fake-hook-token'
    def __init__(self, native, channel):
        self.native, self.channel, self.user = native, channel, native.user
    async def send(self, **fields):
        for file in fields.get('files', []):
            if file.closed:
                raise ValueError('closed SDK file')
        try:
            return await self._send(**fields)
        finally:
            for file in fields.get('files', []):
                file.close()

    async def _send(self, **fields):
        self.native.calls.append((self.channel.id, fields))
        self.native.operations.append(('send', self.channel.id, fields))
        if self not in self.channel.hooks:
            raise NotFound('fake-hook-id')
        failure = self.native.failures.pop(0) if self.native.failures else None
        if fields.get('files') and self.native.file_failure: raise OSError('gld-A p.png')
        if failure == 'missing': raise NotFound('post-sensitive')
        if failure == 'exception': raise OSError('gld-A body-sensitive')
        if failure == 'false': return False
        if 'thread_name' in fields:
            self.native.posts += 1
            post = f'post-{self.native.posts}'
        else: post = str(fields['thread'].id)
        return SimpleNamespace(id=f'dc-out-{len(self.native.calls)}', channel=SimpleNamespace(id=post))


class Guild:
    def __init__(self, native, identifier): self.native, self.id, self.channels = native, identifier, {}
    def get_channel(self, identifier): return self.channels.get(str(identifier))
    def get_member(self, identifier): return SimpleNamespace(id=identifier, bot=False, roles=[])
    async def create_category(self, name):
        identifier = f'cat-{sum(key.startswith("cat-") for key in self.channels)+1}'
        channel = Channel(self.native, identifier, name)
        self.channels[identifier] = channel
        self.native.operations.append(('category', name))
        return channel
    async def create_forum(self, *, name, category):
        self.native.operations.append(('forum', name, category.id))
        if self.native.channel_failure: raise OSError('gld-A ch-sensitive')
        self.native.channels += 1
        channel = Channel(self.native, f'ch-{self.native.channels}', name, category=category)
        self.channels[channel.id] = channel
        return channel


class Native:
    def __init__(self):
        self.listeners, self.calls, self.notices, self.operations, self.typing_calls = [], [], [], [], []
        self.user = SimpleNamespace(id='bot-A', bot=True)
        self.guilds = {key: Guild(self, key) for key in ['gld-A', 'gld-B']}
        self.channels = self.posts = 0
        self.channel_failure = self.file_failure = self.typing_failure = False
        self.failures = []
        self.follow_calls = []
        self.follow_failure = False
        self.http = SimpleNamespace(send_typing=self.send_typing, add_user_to_thread=self.add_user_to_thread)
    def add_listener(self, fn, name): self.listeners.append((fn, name))
    def get_guild(self, identifier): return self.guilds.get(str(identifier))
    async def send_typing(self, identifier):
        self.typing_calls.append(identifier)
        if self.typing_failure: raise OSError('post-sensitive')
    async def add_user_to_thread(self, post, user):
        self.follow_calls.append((post, user))
        self.operations.append(('follow', post, user))
        if self.follow_failure:
            raise OSError(f'{post} {user}')
    async def emit(self, message): await self.listeners[0][0](message)
    def message(self, content='hello', *, guild='gld-A', user='usr-A', parent=None, post='post-in-1',
                title='hello', starter=False, mid='dc-in-1', attachments=None, bot=False, webhook=None):
        channel = Channel(self, post if parent else 'txt-1', title, parent=parent, starter=starter)
        return SimpleNamespace(id=mid, content=content, author=SimpleNamespace(id=user, bot=bot, roles=[]),
                               guild=self.get_guild(guild) if guild else None, channel=channel,
                               webhook_id=webhook, attachments=attachments or [], mentions=[], reference=None)


class Transport(BasePlatformAdapter):
    def __init__(self):
        super().__init__(PlatformConfig(enabled=True), Platform('hejo'))
        self.allowed, self.allow_bots = False, 'none'
        self.arguments, self.originals = [], []
        self._mark_connected()
    def _get_allow_bots(self): return self.allow_bots
    def _is_allowed_user(self, *args, **kwargs):
        self.arguments.append((args, kwargs))
        if self.allowed == 'exception': raise ValueError('private')
        return self.allowed
    async def handle_message(self, event): self.originals.append(event)
    async def connect(self): return True
    async def disconnect(self): pass
    async def send(self, *args, **kwargs): raise AssertionError('native send forbidden')
    async def get_chat_info(self, chat_id): return {}


@pytest.fixture
def transport(registered, monkeypatch):
    value, native = Transport(), Native()
    monkeypatch.setattr(door, '_discord', None);monkeypatch.setattr(door, '_bot', None)
    factory = registered.get_platform_handler_factories('discord')[0][0]
    factory(native, value)
    return value, native


@pytest.fixture(autouse=True)
def named_roster(gate, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    original = gate.employees
    monkeypatch.setattr(gate, 'employees', lambda: [{**e, 'name': {'default':'Main', 'alpha':'Alpha', 'beta':'Beta'}.get(e['id'], e['name'])} for e in original()])
    gate.discord.settle_seconds = .05


async def until(predicate):
    async with asyncio.timeout(4):
        while not predicate(): await asyncio.sleep(.01)


async def settled(gate):
    await until(lambda: not gate.discord.workers)
    await asyncio.sleep(.02)


async def request(client, ws, kind='discord', **fields):
    await ws.send_json({'v':1, 'type':kind, 'id':'request', **fields})
    while True:
        frame = await client.read(ws)
        if frame.get('ref') == 'request': return frame


async def drain(client, ws):
    await ws.send_json({'v':1,'type':'roster','id':'boundary'})
    frames=[]
    while True:
        frame=await client.read(ws)
        if frame.get('ref')=='boundary': return frames
        frames.append(frame)


async def pair(gate, client, ws, native, **fields):
    code=await request(client,ws,'discord_pair')
    await native.emit(native.message(code['code'], **fields))
    assert (await client.until(ws,'discord_status'))[-1]['paired']
    native.notices.clear()
    return code


async def group(gate, title='Team'):
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    await gate.room_command({'type':'room_save','title':title,'members':['alpha','beta'],'lead':'alpha'},Sink())
    return next(i for i,r in gate.journal.rooms.items() if r['title']==title)


async def activate(gate,client,ws,native):
    identifier=await group(gate)
    await pair(gate,client,ws,native)
    await request(client,ws,'discord_save',enabled=True)
    tag=gate.discord.private()['pair']['tag']
    await until(lambda: len(gate.discord.channels(tag)['channels'])==4)
    return identifier,gate.discord.channels(tag)['channels']


async def incoming(gate,native,channels,room='alpha',**fields):
    message=native.message(parent=channels[room]['channel'],**fields)
    await native.emit(message)
    return message


async def test_at_hd_01_registration_listener_is_independent(registered,transport):
    adapter,native=transport
    factory=registered.get_platform_handler_factories('discord')
    assert len(factory)==1 and len(registered.get_platform_handler_factories('telegram'))==1
    original=adapter.handle_message
    factory[0][0](native,adapter);factory[0][0](native,adapter)
    assert adapter.handle_message==original and len(native.listeners)==1
    assert native.listeners[0][1]=='on_message' and not native.operations


async def test_at_hd_02_03_pair_private_rotation(gate,client,transport):
    adapter,native=transport
    ws,welcome=await client.pair(features=['discord'])
    other,_=await client.open(token=welcome['token'],features=['discord'])
    stale=await request(client,ws,'discord_pair');code=await request(client,ws,'discord_pair')
    await native.emit(native.message(stale['code']))
    assert gate.discord.private()['pair'] is None
    await native.emit(native.message(code['code']))
    frames=await drain(client,ws);others=await drain(client,other)
    assert len(code['code'])==12 and code['expires_in']==600 and code['ref']=='request'
    for values in [frames,others]:
        states=[f for f in values if f['type']=='discord_status']
        assert len(states)==1 and states[0]['paired'] and not states[0]['enabled'] and 'ref' not in states[0]
        assert not any(f['type']=='discord_code' for f in values)
    private=gate.discord.private()
    assert {k:v for k,v in private['pair'].items() if k not in {'tag','paired_at'}}=={'platform':'discord','guild_id':'gld-A','user_id':'usr-A'}
    assert re.fullmatch('[0-9a-f]{8}',private['pair']['tag']) and private['code']['used']
    assert (gate.discord.vault.path/'discord.json').stat().st_mode&0o777==0o600
    assert native.notices==[('txt-1','연결됐어요')] and not adapter.originals and gate.journal.head==0


@pytest.mark.parametrize('case',['wrong','expired','used','dm','bot','webhook','allowed','bots','exception','corrupt'])
async def test_at_hd_04_rejected_pair_has_no_side_effect(gate,client,transport,case):
    adapter,native=transport;ws,_=await client.pair(features=['discord'])
    code=await request(client,ws,'discord_pair')
    if case=='used':
        await native.emit(native.message(code['code']));await client.until(ws,'discord_status');native.notices.clear()
    if case=='expired': gate.discord.clock=lambda:10**12
    if case=='allowed': adapter.allowed=True
    if case=='bots': adapter.allow_bots='all'
    if case=='exception': adapter.allowed='exception'
    if case=='corrupt':
        with gate.discord.settings_store.locked(): gate.discord.settings_store.write('settings.json',{'enabled':'bad'})
    before=gate.discord.private()['pair']
    message=native.message('wrong' if case=='wrong' else code['code'],guild=None if case=='dm' else 'gld-A',bot=case=='bot',webhook='hook' if case=='webhook' else None)
    await native.emit(message)
    assert gate.discord.private()['pair']==before and not native.notices and gate.journal.head==0
    if case in {'allowed','bots','exception'}:
        _,args=adapter.arguments[-1]
        assert args['guild'] is message.guild and args['is_dm'] is False and 'txt-1' in args['channel_ids']


async def test_at_hd_05_06_unpair_and_repair(gate,client,transport):
    _,native=transport;ws,_=await client.pair(features=['discord'])
    _,channels=await activate(gate,client,ws,native)
    old=gate.discord.private()['pair']['tag'];path=gate.discord.settings_store.path/'channels.json';before=path.read_bytes()
    status=await request(client,ws,'discord_unpair')
    await incoming(gate,native,channels)
    assert not status['paired'] and not status['enabled'] and not native.calls and not native.notices
    assert path.read_bytes()==before
    for index in range(2):
        count=sum(op[0]=='forum' for op in native.operations)
        await pair(gate,client,ws,native,guild='gld-B',user='usr-B')
        await request(client,ws,'discord_save',enabled=True)
        tag=gate.discord.private()['pair']['tag'];assert tag!=old
        await until(lambda: gate.discord.channels(tag)['channels'] and len(gate.discord.channels(tag)['channels'])==4)
        assert sum(op[0]=='forum' for op in native.operations)==count+4
        old=tag
    head=gate.journal.head
    await incoming(gate,native,channels)
    assert gate.journal.head==head


async def test_at_hd_07_10_11_unavailable_unpaired_no_feature(gate,client,transport,monkeypatch):
    monkeypatch.setattr(door,'_discord',None);monkeypatch.setattr(door,'_bot',None)
    ws,welcome=await client.pair(features=['discord'])
    assert (await request(client,ws,'discord_pair'))['code']=='discord_unavailable'
    assert not (await request(client,ws))['platform_ready']
    assert gate.discord.private()['code'] is None
    path=gate.discord.settings_store.path/'settings.json'
    assert (await request(client,ws,'discord_save',enabled=True))['code']=='discord_unpaired'
    assert not path.exists()
    assert not any(f['type']=='discord_status' for f in await drain(client,ws))
    old,_=await client.open(token=welcome['token'])
    assert (await request(client,old))['code']=='unexpected_frame'
    await gate.discord.publish()
    assert not any(f['type'] in {'discord_status','discord_code'} for f in await drain(client,old))


async def test_at_hd_09_exactly_one_state_and_reconnect(gate,client,transport):
    _,native=transport;ws,welcome=await client.pair(features=['discord'])
    await group(gate);await pair(gate,client,ws,native)
    other,_=await client.open(token=welcome['token'],features=['discord'])
    await ws.send_json({'v':1,'type':'discord_save','id':'s1','enabled':True})
    a=[f for f in await drain(client,ws) if f['type']=='discord_status'];b=[f for f in await drain(client,other) if f['type']=='discord_status']
    assert len(a)==len(b)==1 and a[0].pop('ref')=='s1' and 'ref' not in b[0] and a==b
    assert (gate.discord.settings_store.path/'settings.json').stat().st_mode&0o777==0o600
    await ws.close();await other.close();await gate.disconnect();assert await gate.connect()
    ws,_=await client.open(token=welcome['token'],features=['discord'])
    await drain(client,ws)
    frame=await request(client,ws)
    assert {k:v for k,v in frame.items() if k!='ref'}==a[0]
    assert not any(f['type']=='discord_status' for f in await drain(client,ws))


async def test_at_hd_12_13_sync_failure_recovery(gate,client,transport,caplog):
    _,native=transport;ws,_=await client.pair(features=['discord']);await group(gate);await pair(gate,client,ws,native)
    native.channel_failure=True
    await request(client,ws,'discord_save',enabled=True)
    await until(lambda: gate.discord.channel_problem)
    await gate.send('alpha','blocked',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    assert not native.calls and 'gld-A' not in caplog.text
    assert any(f.get('channel_problem') for f in await drain(client,ws))
    native.channel_failure=False
    await request(client,ws,'discord_save',enabled=False);await request(client,ws,'discord_save',enabled=True)
    tag=gate.discord.private()['pair']['tag'];await until(lambda:len(gate.discord.channels(tag)['channels'])==4)
    assert not gate.discord.channel_problem
    calls=[op for op in native.operations if op[0]=='forum'][-4:]
    assert {op[1] for op in calls}=={'Main','Alpha','Beta','Team'}
    assert sum(op==('category','hejo') for op in native.operations)==1
    count=len(native.operations)
    await request(client,ws,'discord_save',enabled=False);await request(client,ws,'discord_save',enabled=True);await gate.discord.sync_channels()
    assert len(native.operations)==count


async def test_at_hd_14_room_lifecycle(gate,client,transport):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    await asyncio.sleep(.4)  # Let the initial platform-ready transition finish first.
    identifier=await group(gate,'Ops');tag=gate.discord.private()['pair']['tag']
    await until(lambda:identifier in gate.discord.channels(tag)['channels'])
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    for kind,fields,closed in [('room_save',{'title':'Ops2','members':['alpha','beta'],'lead':'alpha'},False),
                                ('room_archive',{'archived':True},True),('room_archive',{'archived':False},False),('room_delete',{},True)]:
        await gate.room_command({'type':kind,'id':identifier,**fields},Sink())
        await until(lambda: gate.discord.channels(tag)['channels'][identifier]['closed']==closed
                    and gate.discord.channels(tag)['channels'][identifier]['name']=='Ops2')
        entry=gate.discord.channels(tag)['channels'][identifier]
        assert entry['closed']==closed and entry['name']=='Ops2'
        channel=native.get_guild('gld-A').get_channel(entry['channel'])
        assert channel.category.name==('hejo 보관' if closed else 'hejo')
    assert sum(op==('category','hejo 보관') for op in native.operations)==1


async def test_at_hd_15_16_recreated_channel_latest_mapping_survives_restart(gate,client,transport,monkeypatch):
    _,native=transport;ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    original=gate.employees;monkeypatch.setattr(gate,'employees',lambda:original()+[{'id':'gamma','name':'Gamma','aliases':[]}])
    await gate.send('gamma','gamma first',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    assert any(op[:2]==('forum','Gamma') for op in native.operations) and len(native.calls)==1
    native.calls.clear()
    thread=str(uuid.uuid4());await client.send(ws,thread=thread,text='a1');await client.until(ws,'message');await settled(gate)
    assert native.calls[-1][1]['thread_name']=='a1'
    old=channels['alpha']['channel'];del native.get_guild('gld-A').channels[old]
    for text in ['a2','a3']:
        await client.send(ws,thread=thread,text=text);await client.until(ws,'message');await settled(gate)
    new=gate.discord.channels(gate.discord.private()['pair']['tag'])['channels']['alpha']['channel']
    assert new!=old and 'thread_name' in native.calls[1][1]
    post=native.calls[2][1]['thread'].id
    assert post=='post-3'
    home=gate.discord.vault.path.parent;await gate.discord.close();gate.discord=door.Discord(gate,home);gate.discord.settle_seconds=.05
    await client.send(ws,thread=thread,text='a4');await client.until(ws,'message');await settled(gate)
    assert native.calls[-1][1]['thread'].id==post
    sent=[json.loads(line) for line in gate.discord.sent_path.read_text().splitlines()]
    assert [row['ch'] for row in sent[-3:]]==[new]*3
    channels=gate.discord.channels(gate.discord.private()['pair']['tag'])['channels']
    await incoming(gate,native,channels,post=post,content='r1')
    assert gate.journal.records[-1]['thread']==thread


async def test_at_hd_17_notfound_replaces_once_other_failure_does_not(gate,client,transport,caplog,tmp_path):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    thread=str(uuid.uuid4());await gate.send('alpha','first',metadata={'thread_id':thread});await settled(gate)
    native.failures=['missing']
    await gate.send('alpha','b1',metadata={'thread_id':thread});await settled(gate)
    assert native.calls[1][1]['thread'].id=='post-1' and native.calls[2][1]['thread_name']=='b1'
    assert native.calls[1][1]['content']==native.calls[2][1]['content']=='b1'
    await gate.send('alpha','b2',metadata={'thread_id':thread});await settled(gate)
    assert native.calls[-1][1]['thread'].id=='post-2'
    caplog.clear();native.failures=['exception'];count=len(native.calls)
    await gate.send('alpha','b3',metadata={'thread_id':thread});await settled(gate)
    assert len(native.calls)==count+1 and sum('discord_send_failed' in r.message for r in caplog.records)==1
    # The SDK closes uploads on failure; file-only replacement needs a fresh File.
    path=tmp_path/'p.png';path.write_bytes(b'fixture')
    native.failures=['missing'];count=len(native.calls)
    await gate.send_document('alpha',str(path),caption='',metadata={'thread_id':thread});await settled(gate)
    assert len(native.calls)==count+2 and native.calls[-2][1]['thread'].id=='post-2'
    assert native.calls[-1][1]['thread_name']=='새 대화'
    assert native.calls[-2][1]['files'][0] is not native.calls[-1][1]['files'][0]
    assert native.calls[-1][1]['files'][0].path.read_bytes()==b'fixture'


async def test_at_hd_20_21_22_23_24_28_ingress_routing_and_duplicate(gate,client,transport,runner):
    _,native=transport;ws,_=await client.pair(features=['rooms','discord']);identifier,channels=await activate(gate,client,ws,native)
    head=gate.journal.head
    msg=await incoming(gate,native,channels,starter=True)
    row=gate.journal.records[-1];key=('alpha',row['thread'])
    assert row['text']=='hello' and row['role']=='owner' and row['employee']=='alpha'
    tag=gate.discord.private()['pair']['tag']
    assert row['client_msg_id']==f"discord:{tag}:{channels['alpha']['channel']}:post-in-1:dc-in-1"
    assert (await client.until(ws,'message'))[-1]['text']=='hello'
    await wait_for_turns(runner,1);assert len(runner.events)==1
    await native.emit(msg);assert gate.journal.head==head+1
    await incoming(gate,native,channels,content='more',mid='dc-in-2');assert gate.journal.records[-1]['thread']==key[1]
    await gate.thread_delete({'room':'alpha','thread':key[1]},SimpleNamespace(send=AsyncMock()))
    await incoming(gate,native,channels,content='again',mid='dc-in-3');second=gate.journal.records[-1]['thread'];assert second!=key[1]
    await incoming(gate,native,channels,content='again2',mid='dc-in-4');assert gate.journal.records[-1]['thread']==second
    for index,content,expected in [(5,'details','Q\ndetails'),(6,'','Q')]:
        await incoming(gate,native,channels,content=content,title='Q',starter=True,post=f'post-in-{index}',mid=f'dc-in-{index}')
        assert gate.journal.records[-1]['text']==expected
    for index,text,employee in [(7,'hi','alpha'),(8,'@Beta hi','beta')]:
        await incoming(gate,native,channels,room=identifier,content=text,mid=f'dc-in-{index}',post=f'post-in-{index}')
        row=gate.journal.records[-1]
        assert row['room']==identifier and row['_meta']['recipients']==[employee]
        await until(lambda:any(event.message_id==row['msg_id'] for event in runner.events))
        assert [event.source.profile for event in runner.events if event.message_id==row['msg_id']]==[employee]
    thread=str(uuid.uuid4());await gate.send('alpha','out',metadata={'thread_id':thread});await settled(gate)
    post=f'post-{native.posts}'
    await incoming(gate,native,channels,content='reply',post=post,mid='dc-in-9')
    assert gate.journal.records[-1]['thread']==thread and len(native.calls)==1 and not native.notices


class Attachment:
    def __init__(self,name='p.png',data=b'fixture',size=None,failure=False):
        self.filename,self.data,self.size,self.failure=name,data,len(data) if size is None else size,failure
        self.reads=self.saves=0
    async def save(self,path):
        self.saves+=1
        if self.failure: raise OSError('private attachment')
        Path(path).write_bytes(self.data)
    async def read(self): self.reads+=1;return self.data


async def test_at_hd_25_26_29_attachments_limits_and_channel_notice(gate,client,transport):
    _,native=transport;ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    for index,text in enumerate(['look','']):
        attachment=Attachment()
        message=await incoming(gate,native,channels,content=text,attachments=[attachment],mid=f'file-{index}')
        row=gate.journal.records[-1];assert row['text']==text and len(row['files'])==1
        head=gate.journal.head
        await native.emit(message)
        assert gate.journal.head==head and attachment.saves==1
        path,_=gate.files.registered('alpha',row['files'][0]['file_id']);assert path.read_bytes()==b'fixture'
    from gate.server import LIMITS
    for fields in [{'attachments':[Attachment(size=50*1024*1024+1)]}, {'attachments':[Attachment(failure=True)]}, {'content':'x'*(LIMITS['text_bytes']+1)}]:
        head=gate.journal.head;await incoming(gate,native,channels,mid=str(uuid.uuid4()),**fields)
        assert gate.journal.head==head and native.notices[-1][1]=='지금은 받지 못했어요'
    identifier=await group(gate,'Ops');await gate.discord.sync_channels()
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    await gate.room_command({'type':'room_archive','id':identifier,'archived':True},Sink());await gate.discord.sync_channels()
    archived=gate.discord.channels(gate.discord.private()['pair']['tag'])['channels'][identifier]['channel']
    for message in [native.message(),native.message(parent='unknown'),native.message(parent=archived)]:
        head=gate.journal.head;await native.emit(message)
        assert gate.journal.head==head and native.notices[-1][1]=='앱에서 만든 방 채널에 써 주세요'


@pytest.mark.parametrize('case',['unpaired','disabled','other-user','other-guild','dm','webhook','corrupt','open'])
async def test_at_hd_27_ignored_messages_and_core_open(gate,client,transport,case,caplog):
    adapter,native=transport;ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    if case=='unpaired': await request(client,ws,'discord_unpair')
    if case=='disabled': await request(client,ws,'discord_save',enabled=False)
    if case=='corrupt': (gate.discord.vault.path/'discord.json').write_text('{broken')
    if case=='open': adapter.allowed=True
    head=gate.journal.head;caplog.clear()
    await incoming(gate,native,channels,user='usr-B' if case=='other-user' else 'usr-A',guild='gld-B' if case=='other-guild' else None if case=='dm' else 'gld-A',webhook='fake-hook' if case=='webhook' else None)
    assert gate.journal.head==head and not native.notices and not native.calls
    if case=='open':
        assert sum('discord_core_open' in r.message for r in caplog.records)==1 and 'usr-A' not in caplog.text
        assert any(f.get('core_open') and 'ref' not in f for f in await drain(client,ws))


@pytest.mark.parametrize('original_first',[True,False])
async def test_at_hd_30_actual_discord_admission_has_no_side_effects(gate,client,transport,discord_module,monkeypatch,original_first,caplog):
    import os
    import gateway
    for key in tuple(os.environ):
        if key.startswith(('DISCORD_','GATEWAY_')): monkeypatch.delenv(key,raising=False)
    source=Path(gateway.__file__).parent.parent/'plugins/platforms/discord/adapter.py'
    monkeypatch.syspath_prepend(str(source.parent))
    name='plugins.platforms.discord.adapter'
    module=importlib.import_module(name)
    assert Path(module.__file__).resolve()==source.resolve()
    monkeypatch.setattr(module,'discord',discord_module)
    native=transport[1]
    actual=module.DiscordAdapter(PlatformConfig(enabled=True, token='fixture'))
    actual._client=native;actual._ready_event.set();actual._mark_connected()
    actual._handle_message=AsyncMock()
    door.attach_discord(native,actual)
    ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    native.notices.clear()
    results=[]
    for index in range(4):
        attachment=Attachment() if index==2 else None
        msg=native.message('<@bot-A> hi' if index in [0,1] else 'see',parent=None if index==0 else channels['alpha']['channel'],
                           mid=f'actual-{index}',attachments=[attachment] if attachment else [],bot=index==3,webhook='fake-hook' if index==3 else None)
        msg.type=discord_module.MessageType.default
        original=msg.content;head=gate.journal.head
        if original_first:
            assert await actual._dispatch_discord_message(msg) is False
            assert not attachment or not attachment.saves
            await native.emit(msg)
        else:
            await native.emit(msg)
            saved=attachment.saves if attachment else 0
            assert await actual._dispatch_discord_message(msg) is False
            assert not attachment or attachment.saves==saved
        assert msg.content==original and not actual._handle_message.called and not native.calls
        if index in [1,2]:
            assert gate.journal.head==head+1 and gate.journal.records[-1]['text']==original
            assert len(gate.journal.records[-1]['files'])==(1 if index==2 else 0)
        else: assert gate.journal.head==head
        assert not attachment or (attachment.reads==0 and attachment.saves==1)
        results.append(gate.journal.head-head)
    assert results==[0,1,1,0] and native.notices==[('txt-1','앱에서 만든 방 채널에 써 주세요')]
    assert not any(op[0] in {'create_thread','native_send'} for op in native.operations)
    # Connect() normally snapshots these environment allowlists. No native network is started.
    monkeypatch.setenv('DISCORD_ALLOWED_USERS','usr-A')
    opened=module.DiscordAdapter(PlatformConfig(enabled=True,token='fixture'))
    opened._allowed_user_ids=opened._get_allowed_users()
    opened._client=native;opened._mark_connected();opened._ready_event.set()
    door.attach_discord(native,opened)
    caplog.clear();head=gate.journal.head
    await incoming(gate,native,channels,content='<@bot-A> hi',mid='open-native')
    assert gate.journal.head==head and sum('discord_core_open' in r.message for r in caplog.records)==1
    assert any(f.get('core_open') for f in await drain(client,ws))


async def test_at_hd_31_32_33_37_38_settling_names_titles_and_mentions(gate,client,transport,runner,tmp_path):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    thread=str(uuid.uuid4());await client.send(ws,thread=thread,text='ping');await wait_for_turns(runner,1)
    await gate.send_typing('alpha',{'thread_id':thread});await gate.send('alpha','pong',metadata={'thread_id':thread})
    await asyncio.sleep(.16)
    assert len(native.calls)==1 and native.calls[0][1]['content']=='ping'
    await gate.stop_typing('alpha',{'thread_id':thread});await settled(gate)
    assert native.calls[0][1]['username']=='사장' and native.calls[0][1]['thread_name']=='ping'
    assert native.calls[1][1]['username']=='Alpha' and native.calls[1][1]['thread'].id=='post-1' and native.calls[1][1]['content']=='pong'
    assert len(gate.discord.sent_path.read_text().splitlines())==2
    await gate.send('alpha','🤔 생각 중…\nprivate thought',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    assert len(native.calls)==2
    for text,title in [('a'*120,'a'*100),('\nbody','body')]:
        await gate.send('alpha',text,metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
        assert native.calls[-1][1]['thread_name']==title
    picture=tmp_path/'p.png';picture.write_bytes(b'fixture')
    await gate.send_document('alpha',str(picture),caption='',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    assert native.calls[-1][1]['thread_name']=='새 대화' and native.calls[-1][1]['files'][0].path.name=='p.png'
    await gate.send('alpha','choose',metadata={'thread_id':str(uuid.uuid4()),'hejo_buttons':[{'label':'A','style':'primary'},{'label':'B','style':'default'}],
        '_hejo_native_buttons':[{'label':'Open','kind':'approval','style':'default'}]});await settled(gate)
    assert native.calls[-1][1]['content']=='choose\n선택: A / B\n(이 선택은 hejo 앱에서 눌러 주세요)'
    await gate.send('alpha','@everyone hi <@123>',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    for _,args in native.calls:
        mentions=args['allowed_mentions']
        assert mentions.everyone is False and mentions.users is False and mentions.roles is False and args['wait'] is True


async def test_at_hd_46_follow_once_per_post_and_retry_after_failure(gate, client, transport, runner, tmp_path, caplog):
    _, native = transport
    ws, _ = await client.pair(features=['discord'])
    await group(gate)
    await pair(gate, client, ws, native, user='1101')
    await request(client, ws, 'discord_save', enabled=True)
    tag = gate.discord.private()['pair']['tag']
    await until(lambda: len(gate.discord.channels(tag)['channels']) == 4)
    await drain(client, ws)
    journal_start = len(gate.journal.records)
    native.operations.clear()

    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text='ping')
    await wait_for_turns(runner, 1)
    await settled(gate)
    for text in ('pong', 'more'):
        await gate.send('alpha', text, metadata={'thread_id': thread})
        await settled(gate)
    assert native.follow_calls == [('post-1', 1101)]
    assert native.calls[0][1]['thread_name'] == 'ping'
    assert [(args['username'], args['thread'].id) for _, args in native.calls[1:]] == [('Alpha', 'post-1')] * 2

    home = gate.discord.vault.path.parent
    await gate.discord.close()
    gate.discord = door.Discord(gate, home)
    gate.discord.settle_seconds = .05
    await gate.send('alpha', 'after restart', metadata={'thread_id': thread})
    await settled(gate)
    assert native.follow_calls == [('post-1', 1101)] * 2
    assert native.calls[-1][1]['thread'].id == 'post-1'

    other = str(uuid.uuid4())
    attachment = tmp_path / 'fixture.txt'
    attachment.write_bytes(b'fixture')
    native.follow_failure = True
    caplog.clear()
    await gate.send_document('alpha', str(attachment), caption='new post', metadata={'thread_id': other})
    await settled(gate)
    assert native.follow_calls[-1] == ('post-2', 1101)
    assert [operation[0] for operation in native.operations[-3:]] == ['send', 'follow', 'send']
    assert native.calls[-1][1]['files'][0].path.name == attachment.name
    assert native.calls[-1][1]['thread'].id == 'post-2'
    assert [record.getMessage() for record in caplog.records if record.name == 'gate.discord'] == [
        'discord_follow_failed kind=OSError',
    ]

    native.follow_failure = False
    await gate.send('alpha', 'retry', metadata={'thread_id': other})
    await settled(gate)
    assert native.follow_calls == [('post-1', 1101)] * 2 + [('post-2', 1101)] * 2
    assert native.calls[-1][1]['thread'].id == 'post-2'
    assert [args.get('content') for _, args in native.calls] == [
        'ping', 'pong', 'more', 'after restart', 'new post', None, 'retry',
    ]
    assert all(not args['allowed_mentions'].everyone and not args['allowed_mentions'].users
               and not args['allowed_mentions'].roles for _, args in native.calls)

    records = gate.journal.records[journal_start:]
    texts = ['ping', 'pong', 'more', 'after restart', 'new post', 'retry']
    assert [(row['type'], row['text']) for row in records] == [('message', text) for text in texts]
    frames = await drain(client, ws)
    assert [frame['text'] for frame in frames if frame['type'] == 'message'] == texts
    assert sorted(frame['type'] for frame in frames) == ['discord_status'] + ['message'] * 6 + ['typing'] * 2


async def test_at_hd_34_both_windows_reflect_only_other_ingress(gate,client,transport,registered,monkeypatch):
    from test_telegram import Transport as TelegramTransport
    from gate import telegram
    phone=TelegramTransport();monkeypatch.setattr(telegram,'_telegram',None)
    registered.get_platform_handler_factories('telegram')[0][0](None,phone)
    _,native=transport;ws,_=await client.pair(features=['discord','telegram']);_,channels=await activate(gate,client,ws,native)
    await ws.send_json({'v':1,'type':'telegram_pair','id':'tg-code'})
    while True:
        frame=await client.read(ws)
        if frame.get('ref')=='tg-code': break
    await phone.handle_message(phone.event(frame['code']));await client.until(ws,'telegram_status')
    await ws.send_json({'v':1,'type':'telegram_save','id':'tg-on','enabled':True})
    await until(lambda:gate.telegram.active())
    await gate.telegram.sync_topics();phone.calls.clear();gate.telegram.settle_seconds=.05
    topics=gate.telegram.topics(gate.telegram.private()['pair']['tag'])['topics']
    await phone.handle_message(phone.event('tg',topic=topics['alpha']['topic']))
    await settled(gate)
    assert len(native.calls)==1 and native.calls[0][1]['content']=='tg' and native.calls[0][1]['username']=='사장'
    await incoming(gate,native,channels,content='dc')
    await until(lambda:not gate.telegram.workers);await settled(gate)
    assert len(native.calls)==1 and [call[1] for call in phone.calls]==['[사장] dc']


async def test_at_hd_35_long_split_reassembles_and_maps_after_restart(gate,client,transport):
    _,native=transport;ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    text='가'*1999+'\n'+'z'*1999+'\n'+'end'*166+'xy'
    assert len(text)==4500
    thread=str(uuid.uuid4());result=await gate.send('alpha',text,metadata={'thread_id':thread});await settled(gate)
    assert len(native.calls)==3 and ''.join(args['content'] for _,args in native.calls)==text
    assert all(len(args['content'])<=2000 for _,args in native.calls)
    assert native.calls[0][1]['thread_name']=='가'*100
    assert [args['thread'].id for _,args in native.calls[1:]]==['post-1','post-1']
    sent=[json.loads(line) for line in gate.discord.sent_path.read_text().splitlines()]
    assert len(sent)==3 and all(row['msg_id']==result.message_id for row in sent)
    home=gate.discord.vault.path.parent;await gate.discord.close();gate.discord=door.Discord(gate,home)
    await incoming(gate,native,channels,content='reply',post='post-1',mid='split-reply')
    assert gate.journal.records[-1]['thread']==thread


async def record_files(gate,text,files):
    return await gate._record({'type':'message','employee':'alpha','thread':str(uuid.uuid4()),'role':'employee','msg_id':str(uuid.uuid4()),
        'text':text,'files':files,'buttons':[],'reply_state':None,'ts':datetime.now(timezone.utc).isoformat()},
        {'files':gate.files.registration('alpha','employee',files)})


async def test_at_hd_36_files_preflight_and_runtime_failure(gate,client,transport,tmp_path,caplog):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    files=[]
    for name in ['p.png','d.txt']:
        path=tmp_path/name;path.write_bytes(b'fixture')
        staged=await gate.files.copy('alpha',path);promoted,_=gate.files.promote('alpha',[staged['file_id']]);files.extend(promoted)
    await record_files(gate,'files',files);await settled(gate)
    assert len(native.calls)==3 and native.calls[0][1]['content']=='files'
    assert [args['files'][0].path.name for _,args in native.calls[1:]]==['p.png','d.txt']
    assert all(args['thread'].id=='post-1' for _,args in native.calls[1:])
    missing={'file_id':str(uuid.uuid4()),'name':'x.bin','mime':'application/octet-stream','size':1}
    await record_files(gate,'missing',[missing]);await settled(gate)
    assert native.calls[-1][1]['content'].endswith('📎 x.bin (hejo 앱에서 열기)')
    large=tmp_path/'large.bin'
    with large.open('wb') as stream: stream.truncate(8*1024*1024+1)
    await gate.send_document('alpha',str(large),caption='large',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
    assert native.calls[-1][1]['content'].endswith('📎 large.bin (hejo 앱에서 열기)') and 'files' not in native.calls[-1][1]
    native.file_failure=True;caplog.clear();count=len(native.calls)
    await gate.send_document('alpha',str(tmp_path/'p.png'),caption='failure',metadata={'thread_id':str(uuid.uuid4())});await settled(gate);await asyncio.sleep(.16)
    assert len(native.calls)==count+2
    logs=[r.message for r in caplog.records if r.name=='gate.discord']
    assert len(logs)==1 and 'p.png' not in logs[0] and 'gld-A' not in logs[0]


@pytest.mark.parametrize('failure',['false','exception'])
async def test_at_hd_39_40_failure_no_retry_no_backfill(gate,client,transport,failure,caplog):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    native.failures=[failure];caplog.clear()
    await gate.send('alpha','body-sensitive',metadata={'thread_id':str(uuid.uuid4())});await settled(gate);await asyncio.sleep(.16)
    assert len(native.calls)==1
    logs=[r.message for r in caplog.records if r.name=='gate.discord']
    assert len(logs)==1 and all(value not in logs[0] for value in ['gld-A','body-sensitive','post-'])
    await request(client,ws,'discord_save',enabled=False)
    await gate.send('alpha','disabled',metadata={'thread_id':str(uuid.uuid4())})
    await request(client,ws,'discord_save',enabled=True);await asyncio.sleep(.16)
    assert len(native.calls)==1


@pytest.mark.parametrize('has_post', [False, True], ids=['new-post', 'replacement-post'])
async def test_deleted_webhook_is_recreated_for_next_message(gate, client, transport, caplog, has_post):
    _, native = transport
    ws, _ = await client.pair(features=['discord'])
    _, channels = await activate(gate, client, ws, native)
    channel = native.get_guild('gld-A').get_channel(channels['alpha']['channel'])
    original_thread = str(uuid.uuid4())
    await gate.send('alpha', 'initial', metadata={'thread_id': original_thread})
    await settled(gate)
    sent_before = gate.discord.sent_path.read_bytes()
    assert len(channel.hooks) == 1
    deleted_hook = channel.hooks.pop()

    thread = original_thread if has_post else str(uuid.uuid4())
    caplog.clear()
    start = len(native.calls)
    await gate.send('alpha', 'undelivered', metadata={'thread_id': thread})
    await settled(gate)
    failed = [fields for _, fields in native.calls[start:]]
    assert [fields['content'] for fields in failed] == ['undelivered'] * (2 if has_post else 1)
    assert failed[-1]['thread_name'] == 'undelivered'
    if has_post:
        assert failed[0]['thread'].id == 'post-1'
    assert [r.message for r in caplog.records if r.name == 'gate.discord'] == [
        'discord_send_failed kind=NotFound'
    ]
    assert not channel.hooks
    assert gate.discord.sent_path.read_bytes() == sent_before

    start = len(native.calls)
    await gate.send('alpha', 'delivered', metadata={'thread_id': thread})
    await settled(gate)
    assert [fields['content'] for _, fields in native.calls[start:]] == ['delivered']
    assert len(channel.hooks) == 1 and channel.hooks[0] is not deleted_hook
    assert gate.discord.sent_path.read_bytes().startswith(sent_before)
    assert len(gate.discord.sent_path.read_bytes().splitlines()) == 2


@pytest.mark.parametrize('broken',['discord.json','settings.json','channels.json','sent.jsonl'])
async def test_at_hd_42_corruption_isolated_from_gate(gate,client,transport,broken):
    _,native=transport;ws,_=await client.pair(features=['discord']);_,channels=await activate(gate,client,ws,native)
    thread=str(uuid.uuid4());await gate.send('alpha','persisted',metadata={'thread_id':thread});await settled(gate)
    code=await request(client,ws,'discord_pair')
    path=(gate.discord.vault.path if broken=='discord.json' else gate.discord.settings_store.path)/broken
    before=list(gate.discord.sent)
    if broken=='sent.jsonl':
        extra={**before[0],'dc':'dc-after-corrupt'};before.append(extra)
        with path.open('ab') as stream: stream.write(b'bad middle\n'+json.dumps(extra).encode()+b'\n{"partial":')
    else: path.write_text('{broken')
    home=gate.discord.vault.path.parent;await gate.disconnect();assert await gate.connect();gate.discord.settle_seconds=.05
    native.calls.clear();native.notices.clear()
    if broken=='sent.jsonl':
        assert gate.discord.sent==before and path.read_bytes().endswith(b'\n')
        await incoming(gate,native,channels,post='post-1',content='reply',mid='repair-reply')
        assert gate.journal.records[-1]['thread']==thread
    elif broken=='channels.json':
        tag=gate.discord.private()['pair']['tag']
        await until(lambda:len(gate.discord.channels(tag)['channels'])==4)
    # A still-valid code is admitted only when both private stores remain readable.
    paired_before=gate.discord.private()['pair']
    await native.emit(native.message(code['code'],mid='valid-code'))
    if broken in {'discord.json','settings.json'}:
        head=gate.journal.head
        await incoming(gate,native,channels)
        await gate.send('alpha','blocked',metadata={'thread_id':str(uuid.uuid4())});await settled(gate)
        assert gate.journal.head==head+1 and not native.calls and not native.notices
        assert gate.discord.private()['pair']==paired_before and not gate.discord.active()
    else:
        assert gate.discord.private()['pair']['tag']!=paired_before['tag']
        tag=gate.discord.private()['pair']['tag']
        await until(lambda:len(gate.discord.channels(tag)['channels'])==4)
        channels=gate.discord.channels(tag)['channels']
        head=gate.journal.head
        await incoming(gate,native,channels,mid='after-repair')
        assert gate.journal.head==head+1
        await gate.send('alpha','working',metadata={'thread_id':gate.journal.records[-1]['thread']});await settled(gate)
        assert native.calls[-1][1]['content']=='working'


async def test_at_hd_43_typing_throttled_to_post_failure_nonblocking(gate,client,transport,caplog):
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    thread=str(uuid.uuid4());await gate.send('alpha','first',metadata={'thread_id':thread});await settled(gate)
    for _ in range(3): await gate.send_typing('alpha',{'thread_id':thread})
    await asyncio.sleep(9)
    await gate.send_typing('alpha',{'thread_id':thread});await until(lambda:len(native.typing_calls)==2)
    assert native.typing_calls==['post-1']*2
    await gate.send_typing('alpha',{'thread_id':str(uuid.uuid4())});await asyncio.sleep(.02)
    assert len(native.typing_calls)==2 and len(native.calls)==1
    native.typing_failure=True;gate.discord._typing_at.clear();caplog.clear()
    await gate.send_typing('alpha',{'thread_id':thread});await asyncio.sleep(.02)
    assert sum('discord_typing_failed' in r.message for r in caplog.records)==1
    await gate.stop_typing('alpha',{'thread_id':thread});await gate.send('alpha','still works',metadata={'thread_id':thread});await settled(gate)
    assert native.calls[-1][1]['content']=='still works'


async def test_at_hd_08_private_values_only_in_authorized_sinks(gate,client,transport,caplog):
    caplog.set_level(logging.DEBUG)
    _,native=transport;ws,welcome=await client.pair(features=['rooms','discord'])
    other,_=await client.open(token=welcome['token'],features=['rooms','discord'])
    await group(gate);code=await pair(gate,client,ws,native)
    await request(client,ws,'discord_save',enabled=True);tag=gate.discord.private()['pair']['tag']
    await until(lambda:len(gate.discord.channels(tag)['channels'])==4)
    identifier=await group(gate,'Ops');await gate.discord.sync_channels()
    class Sink:
        features={'rooms'}
        async def send(self,frame): pass
    await gate.room_command({'type':'room_save','id':identifier,'title':'Ops2','members':['alpha','beta'],'lead':'alpha'},Sink())
    await gate.room_command({'type':'room_archive','id':identifier,'archived':True},Sink());await gate.discord.sync_channels()
    channels=gate.discord.channels(tag)['channels'];await incoming(gate,native,channels,content='hello')
    await gate.send('alpha','pong',metadata={'thread_id':gate.journal.records[-1]['thread']});await settled(gate)
    frames=await drain(client,ws)+await drain(client,other)
    private=(gate.discord.vault.path/'discord.json').read_text()
    public=''.join((gate.discord.settings_store.path/name).read_text() for name in ['settings.json','channels.json','sent.jsonl'])
    journal=json.dumps(gate.journal.records);wire=json.dumps(frames)
    assert code['code'] not in private+public+journal+wire+caplog.text
    for value in ['gld-A','usr-A']:
        assert value in private and value not in public+journal+wire+caplog.text
    for value in ['hello','pong']:
        assert value not in private+public+caplog.text
    for value in [tag,'ch-','post-','dc-','fake-hook-id','fake-hook-token']:
        assert value not in caplog.text
    assert 'fake-hook-id' not in private+public+journal+wire and 'fake-hook-token' not in private+public+journal+wire
    assert all(all(value not in json.dumps(f) for value in [tag,'ch-','post-','dc-','hello','pong']) for f in frames if f['type']!='message')


async def test_at_hd_41_same_gate_script_with_and_without_discord(gate,client,transport,monkeypatch,tmp_path):
    from hermes_cli.profiles import create_profile
    _,native=transport;outputs=[];await gate.disconnect()
    for enabled in [True,False]:
        home=tmp_path/('active' if enabled else 'inactive');home.mkdir();monkeypatch.setenv('HERMES_HOME',str(home))
        for name in ['alpha','beta']: create_profile(name,no_alias=True,no_skills=True)
        assert await gate.connect();gate.discord.settle_seconds=.05
        handled=[]
        async def handle(event): handled.append(event)
        gate.set_message_handler(handle)
        control,_=await client.pair(features=['discord']);identifier=await group(gate)
        if enabled:
            await pair(gate,client,control,native);await request(client,control,'discord_save',enabled=True)
            await gate.discord.sync_channels()
        native.calls.clear();ws,_=await client.pair(features=['rooms']);observed=[]
        for room in ['alpha',identifier]:
            thread=str(uuid.uuid4());count=len(handled)
            await client.send(ws,thread=thread,text='owner fixture',**({'room':room} if room==identifier else {}))
            observed.extend(await client.until(ws,'message'));await until(lambda:len(handled)>count and not gate._active_sessions)
            chat='room:'+room if room==identifier else room;metadata={'thread_id':thread,'hermes_profile':'alpha'}
            await gate.send_typing(chat,metadata)
            first=await gate.send(chat,'draft',metadata=metadata);assert (await gate.edit_message(chat,first.message_id,'edited',metadata=metadata)).success
            doomed=await gate.send(chat,'removed',metadata=metadata)
            from gate.adapter import _delivery_scope
            token=_delivery_scope.set(('alpha',chat,thread))
            try: assert await gate.delete_message(chat,doomed.message_id)
            finally: _delivery_scope.reset(token)
            await gate.send(chat,'reply',reply_to=first.message_id,metadata={**metadata,'hejo_buttons':[{'label':'A','style':'primary'}]})
            path=home/'sample.txt';path.write_text('fixture bytes');await gate.send_document(chat,str(path),caption='attachment',metadata=metadata)
            await gate.stop_typing(chat,metadata)
        await settled(gate);observed.extend(await drain(client,ws))
        def normalize(value):
            if isinstance(value,dict): return {normalize(k):normalize(v) for k,v in value.items() if k not in {'ts','at'}}
            if isinstance(value,list): return [normalize(v) for v in value]
            if isinstance(value,str): return re.sub(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}','<uuid>',value.replace(str(home),'<home>'))
            return value
        outputs.append((normalize(gate.journal.records),normalize(observed)))
        assert bool(native.calls)==enabled
        await ws.close();await control.close();await gate.disconnect()
    assert outputs[0]==outputs[1]


async def test_settlement_real_clock_default(gate,client,transport):
    """Level 3 timing: real event loop/journal, default 2 s boundary, transport still fake."""
    _,native=transport;ws,_=await client.pair(features=['discord']);await activate(gate,client,ws,native)
    gate.discord.settle_seconds=2.0
    start=asyncio.get_running_loop().time()
    await gate.send('alpha','settled',metadata={'thread_id':str(uuid.uuid4())})
    await asyncio.sleep(1.8);assert not native.calls
    await settled(gate);elapsed=asyncio.get_running_loop().time()-start
    assert 2.0<=elapsed<4.0
    print(f'discord settlement measured {elapsed:.3f}s')


async def test_at_hd_11_featureless_peer_excluded_during_pair_and_save(gate,client,transport):
    _,native=transport
    ws,welcome=await client.pair(features=['discord'])
    old,_=await client.open(token=welcome['token'])
    assert (await request(client,old))['code']=='unexpected_frame'
    await activate(gate,client,ws,native)
    assert not any(frame['type'] in {'discord_status','discord_code'} for frame in await drain(client,old))
