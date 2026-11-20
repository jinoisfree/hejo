"""Clicked work choices can cite only this employee's live post in the same conversation."""
import uuid
import pytest
from gate.adapter import HejoAdapter


@pytest.mark.asyncio
async def test_employee_message_scopes_identity_copy_and_deletion(gate, client):
    ws,_=await client.pair(features=['rooms'])
    thread=str(uuid.uuid4())
    post=await gate.send('alpha','work proposal',metadata={'thread_id':thread})
    mid=post.message_id
    row=await gate.employee_message('alpha','alpha',thread,mid)
    assert row['text']=='work proposal' and row['employee']=='alpha' and row['msg_id']==mid
    row['text']='forged'
    assert (await gate.employee_message('alpha','alpha',thread,mid))['text']=='work proposal'
    for profile,chat,tid,target in [('beta','alpha',thread,mid),('alpha','beta',thread,mid),
            ('alpha','alpha','foreign',mid),('alpha','alpha',thread,'missing'),('', 'alpha',thread,mid)]:
        assert await gate.employee_message(profile,chat,tid,target) is None
    await client.send(ws,thread=thread,text='owner is not an employee post')
    owner=(await client.until(ws,'message'))[-1]
    while owner.get('role') != 'owner':
        owner=(await client.until(ws,'message'))[-1]
    assert await gate.employee_message('alpha','alpha',thread,owner['msg_id']) is None
    await gate._record({'type':'delete','msg_id':mid})
    assert await gate.employee_message('alpha','alpha',thread,mid) is None
    await ws.close()


@pytest.mark.asyncio
async def test_employee_message_room_forwarder_and_deleted_scope(gate, client):
    ws,_=await client.pair(features=['rooms'])
    await ws.send_json({'v':1,'type':'room_save','title':'test room','members':['alpha','beta'],'lead':'alpha'})
    room=(await client.until(ws,'room'))[-1]['room']['id'];chat='room:'+room
    thread=str(uuid.uuid4())
    a=await gate.send(chat,'alpha proposal',metadata={'thread_id':thread,'hermes_profile':'alpha'})
    b=await gate.send(chat,'beta proposal',metadata={'thread_id':thread,'hermes_profile':'beta'})
    assert await gate.employee_message('alpha',chat,thread,a.message_id)
    assert await gate.employee_message('alpha',chat,thread,b.message_id) is None
    second=HejoAdapter(gate.config);second.set_owner_profile('beta');await second.connect()
    try:
        # A forwarder cannot borrow a caller-supplied profile.
        assert await second.employee_message('alpha',chat,thread,a.message_id) is None
        assert (await second.employee_message('alpha',chat,thread,b.message_id))['employee']=='beta'
    finally:await second.disconnect()
    await gate.room_command({'type':'room_delete','id':room},None)
    assert await gate.employee_message('alpha',chat,thread,a.message_id) is None
    assert await gate.employee_message('alpha','room:missing',thread,a.message_id) is None
    await ws.close()
