"""AT70/71: durable room boundary, projection/privacy, routing and restart cleanup."""
import asyncio
import json
import uuid
from unittest.mock import patch
import pytest
from gate.tests.support import airport, registered, gate, client, runner, wait_for_turns
from gate.journal import HejoJournalError
from gate.adapter import HejoAdapter
from gateway.config import PlatformConfig


def command(kind, **values):
    return {'v':1,'type':kind,**values}


async def create(client, ws):
    await ws.send_json(command('room_save',title='시험 방',members=['alpha','beta'],lead='alpha'))
    frame = await client.read(ws)
    assert frame['type'] == 'room'
    return frame['room']['id']


@pytest.mark.asyncio
async def test_at70_room_lifecycle_broadcast_compatibility_and_seq(gate, client):
    ws, welcome = await client.pair(features=['rooms'])
    other, _ = await client.open(token=welcome['token'],features=['rooms'])
    old, _ = await client.open(token=welcome['token'])
    room = await create(client,ws)
    assert (await client.read(other))['room']['id'] == room
    legacy = await client.read(old)
    assert legacy == {'v':1,'type':'delete','seq':1,'msg_id':'room:'+room}
    for kind, fields in [('room_save',dict(title='새 이름',description='설명',members=['alpha','beta'],lead='beta')),
                         ('room_archive',dict(archived=True)),('room_archive',dict(archived=False))]:
        await ws.send_json(command(kind,id=room,**fields))
        assert (await client.read(ws))['type'] == 'room'
        assert (await client.read(other))['type'] == 'room'
        assert (await client.read(old))['type'] == 'delete'
    thread=str(uuid.uuid4())
    result=await gate.send('room:'+room,'hidden group body',metadata={'hermes_profile':'beta','thread_id':thread})
    msg=await client.read(ws);assert msg['room']==room and msg['employee']=='beta'
    await client.read(other);assert 'text' not in await client.read(old)
    await gate.edit_message('room:'+room,result.message_id,'secret edited',finalize=True)
    edited=await client.read(ws);await client.read(other);assert (await client.read(old))['type']=='delete'
    await gate.set_reply_state(result.message_id,'asked')
    await client.read(ws);await client.read(other);await client.read(old)
    await ws.send_json(command('room_delete',id=room))
    point=await client.read(ws);assert point=={'v':1,'type':'room_deleted','seq':gate.journal.head,'id':room}
    assert (await client.read(other))==point;assert (await client.read(old))['msg_id']=='room:'+room
    assert len([r for r in gate.journal.records if r['type']=='room_delete'])==1
    assert not [r for r in gate.journal.records if r['type']=='delete']
    page=gate.journal.page(0)
    assert [r['seq'] for r in page]==list(range(1,gate.journal.head+1))
    assert next(r for r in page if r['seq']==edited['seq'])=={'v':1,'type':'delete','seq':edited['seq'],'msg_id':result.message_id}
    assert all(r.get('room')=={'id':room,'deleted':True} for r in page if r['type']=='room')
    replay, new_welcome=await client.open(token=welcome['token'],features=['rooms'],since=0)
    assert new_welcome['rooms']==[]
    assert (await client.until(replay,'sync_done'))[:-1]==page
    legacy_replay,_=await client.open(token=welcome['token'],since=0)
    legacy_page=(await client.until(legacy_replay,'sync_done'))[:-1]
    assert all(r['type']=='delete' and 'text' not in r for r in legacy_page)
    assert [r['seq'] for r in legacy_page]==list(range(1,gate.journal.head+1))
    assert gate.journal.message(result.message_id) is None
    for kind,fields in [('room_save',dict(title='revive',members=['alpha','beta'],lead='alpha')),
                         ('send',dict(employee='alpha',room=room,text='no',client_msg_id=str(uuid.uuid4())))]:
        await ws.send_json(command(kind,id=room,**fields));assert (await client.read(ws))['code']=='room_deleted'


@pytest.mark.asyncio
async def test_at70_delete_failure_cleanup_restart_and_late_output(gate,client,tmp_path,caplog):
    ws,welcome=await client.pair(features=['rooms']);room=await create(client,ws);thread=str(uuid.uuid4())
    path=tmp_path/'fake.txt';path.write_text('fake bytes')
    exclusive=await gate.send_document('room:'+room,str(path),metadata={'hermes_profile':'alpha','thread_id':thread});await client.read(ws)
    shared=await gate.send_document('room:'+room,str(path),metadata={'hermes_profile':'beta','thread_id':thread});await client.read(ws)
    row=gate.journal.message(shared.message_id)
    await gate.send('beta','survives',metadata={'_hejo_files':row['files'],'_hejo_file_registration':row['_meta']['files']});await client.read(ws)
    exclusive_id=gate.journal.message(exclusive.message_id)['files'][0]['file_id'];shared_id=row['files'][0]['file_id']
    # Existing valid PNG fixture; only fake picture bytes are read.
    from gate.tests.test_pictures import png
    gate.server.pictures.put('room',room,png())
    original=gate.journal.append
    async def fail(frame,internal=None):
        if frame['type']=='room_delete':raise HejoJournalError('journal_write_failed')
        return await original(frame,internal)
    head=gate.journal.head
    with patch.object(gate.journal,'append',side_effect=fail):
        await ws.send_json(command('room_delete',id=room));assert (await client.read(ws))['code']=='journal_write_failed'
    assert gate.journal.head==head and room in gate.journal.rooms
    assert (gate.files.root/exclusive_id).exists() and gate.server.pictures.path('room',room).exists()
    with patch.object(gate.files,'cleanup',side_effect=OSError('injected cleanup failure')):
        await ws.send_json(command('room_delete',id=room));assert (await client.read(ws))['type']=='room_deleted'
    head=gate.journal.head
    assert not (await gate.send('room:'+room,'late',metadata={'hermes_profile':'alpha','thread_id':thread})).success
    assert not (await gate.edit_message('room:'+room,exclusive.message_id,'late',finalize=True)).success
    assert (await gate.edit_message('room:'+room,exclusive.message_id,'x'*70000,finalize=True)).error=='room_deleted_drop'
    await gate.send_typing('room:'+room,{'hermes_profile':'alpha','thread_id':thread})
    assert 'room:'+room not in gate._typing_threads
    await gate.set_reply_state(exclusive.message_id,'answered')
    assert not (await gate.send_document('room:'+room,str(path),metadata={'hermes_profile':'alpha','thread_id':thread})).success
    assert gate.journal.head==head and 'room_deleted_drop' in caplog.text
    await gate.disconnect();assert await gate.connect()
    assert gate.journal.head==head and room in gate.journal.deleted_rooms
    assert not (gate.files.root/exclusive_id).exists() and (gate.files.root/shared_id).exists()
    assert not gate.server.pictures.path('room',room).exists()
    await gate.disconnect();assert await gate.connect();assert gate.journal.head==head


@pytest.mark.asyncio
async def test_at71_routing_mentions_alias_context_and_forwarder(gate,client,runner,monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS','owner')
    # Fake roster, no real team names or profile secrets.
    roster=[{'id':i,'name':n,'aliases':[a],'avatar':None} for i,n,a in [('alpha','직원 A','first'),('beta','직원 B','second'),('default','직원 C','outside')]]
    monkeypatch.setattr(gate,'employees',lambda:roster)
    ws,_=await client.pair(features=['rooms']);room=await create(client,ws);thread=str(uuid.uuid4())
    async def post(text,count):
        await client.send(ws,thread=thread,room=room,text=text)
        frames=await client.until(ws,'message');assert frames[-1]['text']==text
        await wait_for_turns(runner,count)
    await post('@first first',1)
    assert runner.events[-1].source.profile=='alpha' and runner.events[-1].source.chat_id=='room:'+room
    await post('missed owner',2)
    for text in ['answer one','answer two','answer three']:
        await gate.send('room:'+room,text,metadata={'hermes_profile':'beta','thread_id':thread});await client.until(ws,'message')
    # alpha received the immediately preceding owner, so only three beta answers are context here.
    await post('@first now',3)
    assert '[방 대화 — 받기 전 글]' in runner.events[-1].text and '직원 B: answer three' in runner.events[-1].text
    assert runner.events[-1].text.endswith('[이번 글]\n@first now')
    await post('@first @second both',5)
    assert {e.source.profile for e in runner.events[-2:]}=={'alpha','beta'}
    await post('@outside ignored',6);assert runner.events[-1].source.profile=='alpha'
    forward=HejoAdapter(PlatformConfig(enabled=True,extra={}));forward._owner_profile='beta';assert await forward.connect()
    sent=await forward.send('room:'+room,'forwarded',metadata={'thread_id':thread});assert sent.success
    msg=(await client.until(ws,'message'))[-1];assert msg['room']==room and msg['employee']=='beta'
    await forward.disconnect()


@pytest.mark.asyncio
async def test_at70_invalid_room_and_picture_existence(gate,client):
    ws,welcome=await client.pair(features=['rooms'])
    for values,code in [(dict(title=' ',members=['alpha','beta'],lead='alpha'),'invalid_room'),
                        (dict(title='bad',members=['alpha','missing'],lead='alpha'),'unknown_employee')]:
        await ws.send_json(command('room_save',**values));assert (await client.read(ws))['code']==code
    from aiohttp import ClientSession
    async with ClientSession() as session:
        for method in ['get','put','delete']:
            async with getattr(session,method)(f'http://127.0.0.1:{gate.server.port}/v1/pictures/room/{uuid.uuid4()}',headers={'Authorization':'Bearer '+welcome['token']}) as response:
                assert response.status==404
    assert gate.journal.head==0


@pytest.mark.asyncio
async def test_at71_five_missed_lines_and_actual_delivery_bounds(gate,client,runner,monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS','owner')
    ws,_=await client.pair(features=['rooms']);room=await create(client,ws);thread=str(uuid.uuid4())
    count=0
    async def owner(text):
        nonlocal count
        count+=1;await client.send(ws,thread=thread,room=room,text=text);await client.until(ws,'message');await wait_for_turns(runner,count)
    await owner('@alpha initial')
    await owner('@beta owner one');await owner('@beta owner two')
    for i in range(3):
        await gate.send('room:'+room,'answer '+str(i),metadata={'hermes_profile':'beta','thread_id':thread});await client.until(ws,'message')
    await gate.send('room:'+room,'other thread excluded',metadata={'hermes_profile':'beta','thread_id':str(uuid.uuid4())});await client.until(ws,'message')
    removed=await gate.send('room:'+room,'deleted excluded',metadata={'hermes_profile':'beta','thread_id':thread});await client.until(ws,'message')
    await gate._record({'type':'delete','msg_id':removed.message_id});await client.read(ws)
    await owner('@alpha now')
    actual=runner.events[-1].text
    expected='[방 대화 — 받기 전 글]\n나: @beta owner one\n나: @beta owner two\nbeta: answer 0\nbeta: answer 1\nbeta: answer 2\n\n[이번 글]\n@alpha now'
    assert actual==expected
    assert gate.journal.message(runner.events[-1].message_id)['text']=='@alpha now'
    for i in range(26):
        await gate.send('room:'+room,f'{i:02d} '+('x'*600),metadata={'hermes_profile':'beta','thread_id':thread});await client.until(ws,'message')
    await owner('@alpha bounded')
    context=runner.events[-1].text.split('\n',1)[1].split('\n\n[이번 글]',1)[0]
    assert len(context)<=4000 and len(context.splitlines())<=20 and '25 '+('x'*497) in context
    assert all(len(line.split(': ',1)[-1])<=500 for line in context.splitlines())
    assert '00 '+('x'*10) not in context and 'other thread excluded' not in context


@pytest.mark.asyncio
async def test_at70_picture_auth_atomic_room_metadata_and_failed_commit(gate,client):
    from aiohttp import ClientSession
    from gate.tests.test_pictures import png
    ws,welcome=await client.pair(features=['rooms']);room=await create(client,ws)
    url=f'http://127.0.0.1:{gate.server.port}/v1/pictures/room/{room}'
    headers={'Authorization':'Bearer '+welcome['token']}
    async with ClientSession() as session:
        async with session.put(url,data=png()) as response:assert response.status==401
        async with session.put(url,data=b'not an image',headers=headers) as response:assert response.status==415
        async with session.put(url,data=b'x'*(512*1024+1),headers=headers) as response:assert response.status==413
        async with session.put(url,data=png(),headers=headers) as response:
            assert response.status==200;address=(await response.json())['picture']
        assert (await client.read(ws))['room']['picture']==address
        path=gate.server.pictures.path('room',room);assert path.stat().st_mode&0o777==0o600
        async with session.get(url,headers=headers) as response:assert response.status==200 and await response.read()==png()
        head=gate.journal.head
        with patch.object(gate.journal,'append',side_effect=HejoJournalError('injected journal failure')):
            async with session.delete(url,headers=headers) as response:assert response.status==500
        assert path.read_bytes()==png() and gate.journal.head==head and gate.journal.rooms[room]['picture']==address
        async with session.delete(url,headers=headers) as response:assert response.status==200
        assert (await client.read(ws))['room']['picture'] is None and not path.exists()


@pytest.mark.asyncio
async def test_at70_fsync_commit_failure_preserves_bytes_and_room(gate,client):
    ws,_=await client.pair(features=['rooms']);room=await create(client,ws)
    path=next(gate.journal.path.glob('*.jsonl'));before=path.read_bytes();head=gate.journal.head
    with patch('gate.journal.os.fsync',side_effect=[OSError('injected fsync'),None]):
        await ws.send_json(command('room_delete',id=room));assert (await client.read(ws))['code']=='journal_write_failed'
    assert path.read_bytes()==before and gate.journal.head==head and room in gate.journal.rooms
