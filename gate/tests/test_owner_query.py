"""Owner provenance is scoped to the receiving employee, never supplied by model text."""
import asyncio
import uuid
from types import SimpleNamespace
import pytest
from gate.adapter import HejoAdapter
from gate.tests.support import wait_for_turns


@pytest.mark.asyncio
async def test_owner_message_reads_original_and_rejects_foreign_deleted_and_employee(gate, client, runner):
    ws, _ = await client.pair(features=['rooms'])
    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text='original owner request')
    row = (await client.until(ws, 'message'))[-1]
    await wait_for_turns(runner, 1)
    mid = row['msg_id']
    expected = dict(msg_id=mid, text='original owner request', chat_id='alpha', thread_id=thread,
                    answer_to=None, ts=row['ts'])
    assert await gate.owner_message('alpha', 'alpha', thread, mid) == expected
    copy = await gate.owner_message('alpha', 'alpha', thread, mid)
    copy['text'] = 'forged'
    assert await gate.owner_message('alpha', 'alpha', thread, mid) == expected
    for profile, chat, target_thread, target in [('beta','alpha',thread,mid),('alpha','beta',thread,mid),
            ('alpha','alpha','foreign',mid),('alpha','alpha',thread,'missing')]:
        assert await gate.owner_message(profile,chat,target_thread,target) is None
    staff = await gate.send('alpha','staff content',metadata={'thread_id':thread})
    assert await gate.owner_message('alpha','alpha',thread,staff.message_id) is None
    await gate._record({'type':'delete','msg_id':mid})
    assert await gate.owner_message('alpha','alpha',thread,mid) is None
    await ws.close()


@pytest.mark.asyncio
async def test_room_owner_query_requires_actual_recipients_and_forwarder_identity(gate, client, runner):
    ws,_ = await client.pair(features=['rooms'])
    await ws.send_json({'v':1,'type':'room_save','title':'test room','members':['alpha','beta'],'lead':'alpha'})
    room=(await client.until(ws,'room'))[-1]['room']['id']
    thread=str(uuid.uuid4())
    await client.send(ws,thread=thread,room=room,text='owner request')
    row=(await client.until(ws,'message'))[-1]
    await wait_for_turns(runner,1)
    mid=row['msg_id'];chat='room:'+room
    assert await gate.owner_message('alpha',chat,thread,mid)
    assert await gate.owner_message('beta',chat,thread,mid) is None
    second=HejoAdapter(gate.config);second.set_owner_profile('beta');await second.connect()
    try:
        assert await second.owner_message('alpha',chat,thread,mid) is None
        await client.send(ws,thread=thread,employee='beta',text='beta owner request')
        own=(await client.until(ws,'message'))[-1]
        assert (await second.owner_message('alpha','beta',thread,own['msg_id']))['text']=='beta owner request'
        assert await second.owner_message('alpha','alpha',thread,own['msg_id']) is None
    finally:
        await second.disconnect()
    await gate.room_command({'type':'room_delete','id':room},None)
    assert await gate.owner_message('alpha',chat,thread,mid) is None
    await ws.close()


@pytest.mark.asyncio
async def test_receive_exposes_same_message_id_in_real_gateway_context(gate, client, runner, monkeypatch):
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    from gateway.run import GatewayRunner
    from gateway.session_context import get_session_env, clear_session_vars
    ws,_=await client.pair()
    thread=str(uuid.uuid4())
    await client.send(ws,thread=thread,text='current request')
    row=(await client.until(ws,'message'))[-1]
    await wait_for_turns(runner,1)
    source=runner.events[0].source
    context=SimpleNamespace(source=source,session_key='test-key')
    host=SimpleNamespace(adapters={gate.platform:gate})
    tokens=GatewayRunner._set_session_env(host,context)
    try:
        assert get_session_env('HERMES_SESSION_MESSAGE_ID')==row['msg_id']==runner.events[0].message_id
        assert get_session_env('HERMES_SESSION_SCOPE_ID')==''
        assert get_session_env('HERMES_SESSION_THREAD_ID')==thread
    finally:
        clear_session_vars(tokens)
    await gate.thread_delete({'room':'alpha','thread':thread},None)
    assert await gate.owner_message('alpha','alpha',thread,row['msg_id']) is None
    await ws.close()
