"""AT85: official turn completion and progress cleanup preserve ownership and seq."""
import asyncio
from types import SimpleNamespace
import uuid
import pytest
from gate.adapter import HejoAdapter


@pytest.mark.asyncio
async def test_stop_closes_only_employee_thread_once_and_accepts_late_edit(gate,client):
    ws,welcome=await client.pair();old,_=await client.open(token=welcome['token'])
    thread=str(uuid.uuid4());other=str(uuid.uuid4())
    await gate.send_typing('alpha',{'thread_id':thread});await client.read(ws);await client.read(old)
    sent=await gate.send('alpha','tool progress',metadata={'thread_id':thread})
    await client.read(ws);await client.read(old)
    await gate.edit_message('alpha',sent.message_id,'latest tool text',finalize=False)
    elsewhere=await gate.send('alpha','other thread',metadata={'thread_id':other});await client.read(ws);await client.read(old)
    await gate.edit_message('alpha',elsewhere.message_id,'still running',finalize=False)
    await gate.send('alpha','final answer',metadata={'thread_id':thread});await client.read(ws);await client.read(old)
    await gate.stop_typing('alpha',{'thread_id':thread})
    finished=await client.read(ws);assert finished==await client.read(old)
    assert finished['type']=='edit' and finished['msg_id']==sent.message_id and finished['text']=='latest tool text' and finished['final'] is True
    assert (await client.read(ws))['on'] is False;await client.read(old)
    head=gate.journal.head;await gate.stop_typing('alpha',{'thread_id':thread});assert gate.journal.head==head
    assert gate.journal.message(elsewhere.message_id).get('final') is not True
    assert (await gate.edit_message('alpha',sent.message_id,'late text',finalize=True)).success
    assert gate.journal.message(sent.message_id)['text']=='late text'
    assert [r['seq'] for r in gate.journal.page(0)]==list(range(1,gate.journal.head+1))


@pytest.mark.asyncio
async def test_forwarder_stop_and_delete_are_scoped_to_owner_chat(gate):
    second=HejoAdapter(gate.config);second.set_owner_profile('beta');assert await second.connect()
    try:
        thread=str(uuid.uuid4());other_thread=str(uuid.uuid4())
        await second.send_typing('ignored',{'thread_id':thread})
        own=await second.send('ignored','beta progress',metadata={'thread_id':thread})
        await second.edit_message('ignored',own.message_id,'beta latest',finalize=False)
        other=await second.send('ignored','separate',metadata={'thread_id':other_thread})
        await second.edit_message('ignored',other.message_id,'separate latest',finalize=False)
        await second.stop_typing('ignored',{'thread_id':thread})
        assert gate.journal.message(own.message_id)['final'] is True
        assert gate.journal.message(other.message_id).get('final') is not True
        foreign=await gate.send('alpha','foreign')
        boss=await gate._record({'type':'message','msg_id':str(uuid.uuid4()),'employee':'beta','thread':thread,'role':'owner','text':'boss','files':[],'buttons':[],'reply_state':None,'ts':'2026-01-01T00:00:00Z'})
        head=gate.journal.head
        assert not await second.delete_message('ignored',foreign.message_id)
        assert not await second.delete_message('ignored',boss['msg_id'])
        assert not await second.delete_message('ignored','missing')
        assert not await gate.delete_message('beta',own.message_id)
        assert gate.journal.head==head
        assert await second.delete_message('ignored',own.message_id)
        assert gate.journal.message(own.message_id) is None
        assert gate.journal.records[-1]['type']=='delete' and 'scope' not in gate.journal.records[-1]
        assert not await second.delete_message('ignored',own.message_id)
    finally:await second.disconnect()


@pytest.mark.asyncio
@pytest.mark.parametrize('failed',[False,True])
async def test_official_successful_turn_cleans_progress_after_delivery(gate,failed):
    from gateway.run_turn import GatewayTurnMixin
    thread=str(uuid.uuid4());ids=[]
    for text in ('progress 1','progress 2'):
        ids.append((await gate.send('default',text,metadata={'thread_id':thread})).message_id)
    final=await gate.send('default','final answer',metadata={'thread_id':thread})
    ctx=SimpleNamespace(_cleanup_progress=True,_cleanup_msg_ids=ids,session_key='fake-session',source=SimpleNamespace(chat_id='default'),run_generation=1)
    GatewayTurnMixin._run_agent_schedule_bubble_cleanup(None,{'failed':failed},gate,ctx)
    callback=gate.pop_post_delivery_callback('fake-session',generation=1)
    if failed:
        assert callback is None and all(gate.journal.message(mid) for mid in ids)
    else:
        assert callable(callback);callback()
        async def done():
            while any(gate.journal.message(mid) for mid in ids):await asyncio.sleep(0)
        await asyncio.wait_for(done(),2)
        assert [r['msg_id'] for r in gate.journal.records if r['type']=='delete']==ids
    assert gate.journal.message(final.message_id)['text']=='final answer'


@pytest.mark.asyncio
async def test_room_stop_and_delete_do_not_touch_other_employee(gate,client):
    from gate.tests.test_rooms import create
    ws,_=await client.pair(features=['rooms']);room=await create(client,ws);chat='room:'+room;thread=str(uuid.uuid4())
    second=HejoAdapter(gate.config);second.set_owner_profile('beta');assert await second.connect()
    try:
        await gate.send_typing(chat,{'hermes_profile':'alpha','thread_id':thread})
        await second.send_typing(chat,{'thread_id':thread})
        alpha=await gate.send(chat,'alpha',metadata={'hermes_profile':'alpha','thread_id':thread})
        beta=await second.send(chat,'beta',metadata={'thread_id':thread})
        await gate.edit_message(chat,alpha.message_id,'alpha progress',finalize=False)
        await second.edit_message(chat,beta.message_id,'beta progress',finalize=False)
        await second.stop_typing(chat,{'thread_id':thread})
        assert gate.journal.message(beta.message_id)['final'] is True
        assert gate.journal.message(alpha.message_id).get('final') is not True
        assert ('alpha',thread) in gate._typing_threads[chat]
        head=gate.journal.head
        assert not await second.delete_message(chat,alpha.message_id)
        assert not await second.delete_message('another-chat',beta.message_id)
        assert gate.journal.head==head
        assert await second.delete_message(chat,beta.message_id)
        assert gate.journal.message(alpha.message_id) is not None
    finally:await second.disconnect()
