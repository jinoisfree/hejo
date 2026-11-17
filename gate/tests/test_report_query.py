"""TASK49: public report lookup is scoped to a live speaker and conversation."""
import uuid
import pytest
from gate.adapter import HejoAdapter


@pytest.mark.asyncio
async def test_first_thread_message_uses_current_text_and_skips_owner_deleted_other_speaker(gate):
    thread=str(uuid.uuid4());md={'thread_id':thread}
    await gate._record({'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha','thread':thread,
        'role':'owner','text':'owner first','files':[],'buttons':[],'reply_state':None,'ts':'2026-01-01T00:00:00Z'})
    await gate.send('beta','foreign',metadata=md)
    deleted=await gate.send('alpha','deleted',metadata=md)
    await gate._record({'type':'delete','msg_id':deleted.message_id})
    own=await gate.send('alpha','report',metadata=md)
    await gate.send('alpha','later',metadata=md)
    assert (await gate.edit_message('alpha',own.message_id,'latest report',finalize=True)).success
    assert await gate.first_thread_message('alpha',thread)=={'msg_id':own.message_id,'text':'latest report'}
    assert await gate.first_thread_message('alpha',str(uuid.uuid4())) is None
    snapshot=await gate.first_thread_message('alpha',thread);snapshot['text']='mutated'
    assert (await gate.first_thread_message('alpha',thread))['text']=='latest report'


@pytest.mark.asyncio
async def test_first_thread_message_forwarder_cannot_select_another_employee(gate):
    second=HejoAdapter(gate.config);second.set_owner_profile('beta');assert await second.connect()
    try:
        thread=str(uuid.uuid4());md={'thread_id':thread}
        await gate.send('alpha','foreign',metadata=md)
        own=await second.send('ignored','own',metadata=md)
        assert await second.first_thread_message('alpha',thread,metadata={'hermes_profile':'alpha'})=={'msg_id':own.message_id,'text':'own'}
        await gate.thread_delete({'room':'beta','thread':thread},None)
        assert await second.first_thread_message('ignored',thread) is None
    finally:await second.disconnect()


@pytest.mark.asyncio
async def test_first_thread_message_room_isolation_and_deleted_room(gate,client):
    ws,_=await client.pair(features=['rooms'])
    await ws.send_json({'v':1,'type':'room_save','title':'report room','members':['alpha','beta'],'lead':'alpha'})
    frame=await client.read(ws);room=frame['room']['id'];thread=str(uuid.uuid4())
    md={'thread_id':thread,'hermes_profile':'alpha'}
    await gate.send('alpha','dm',metadata=md)
    await gate.send('room:'+room,'other speaker',metadata={**md,'hermes_profile':'beta'})
    own=await gate.send('room:'+room,'own report',metadata=md)
    assert await gate.first_thread_message('room:'+room,thread,metadata=md)=={'msg_id':own.message_id,'text':'own report'}
    await gate.room_command({'type':'room_delete','id':room},None)
    assert await gate.first_thread_message('room:'+room,thread,metadata=md) is None
    await ws.close()
