"""AT85: official turn completion and progress cleanup preserve ownership and seq."""
import asyncio
from types import SimpleNamespace
import uuid
import pytest
from gate.adapter import HejoAdapter


@pytest.mark.asyncio
@pytest.mark.parametrize('forwarded', [False, True], ids=['primary', 'forwarder'])
async def test_stop_typing_keeps_other_active_thread_running(gate, forwarded):
    """N34-01: stopping A leaves concurrent B untouched through either adapter."""
    sender = gate
    chat = 'alpha'
    employee = 'alpha'
    if forwarded:
        sender = HejoAdapter(gate.config)
        sender.set_owner_profile('beta')
        assert await sender.connect()
        chat, employee = 'ignored', 'beta'
    thread_a, thread_b = str(uuid.uuid4()), str(uuid.uuid4())
    try:
        messages = []
        for thread, text in ((thread_a, 'progress A'), (thread_b, 'progress B')):
            await sender.send_typing(chat, {'thread_id': thread})
            sent = await sender.send(chat, text, metadata={'thread_id': thread})
            assert sent.success
            assert (await sender.edit_message(chat, sent.message_id, text, finalize=False)).success
            messages.append(sent.message_id)

        async def both_streaming():
            while not all(gate.journal.message(mid).get('final') is False for mid in messages):
                await asyncio.sleep(0.01)

        await asyncio.wait_for(both_streaming(), 2)
        head = gate.journal.head
        await sender.stop_typing(chat, {'thread_id': thread_a})
        await sender.stop_typing(chat, {'thread_id': thread_a})

        edits = [row for row in gate.journal.records if row['seq'] > head and row['type'] == 'edit']
        assert [(row['msg_id'], row['final']) for row in edits] == [(messages[0], True)]
        assert gate.journal.message(messages[0])['text'] == 'progress A'
        assert gate.journal.message(messages[1])['final'] is False
        assert gate._typing_threads[employee] == {(employee, thread_b)}
    finally:
        if forwarded:
            await sender.disconnect()


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


@pytest.mark.asyncio
@pytest.mark.parametrize('forwarded',[False,True],ids=['primary','forwarder'])
@pytest.mark.parametrize('failed',[False,True],ids=['success','failed'])
async def test_ingress_final_delivery_cleans_edited_progress_on_owning_adapter(gate,monkeypatch,forwarded,failed):
    """The primary receives the turn; cleanup registered by its profile adapter fires after final delivery."""
    from gateway.run_turn import GatewayTurnMixin
    from gateway.run_turn_runner import TurnRunner
    from gateway.platforms.base import MessageEvent
    monkeypatch.setenv('HEJO_ALLOWED_USERS','owner')
    sender=gate;chat='default';profile='default';ids=[]
    if forwarded:
        sender=HejoAdapter(gate.config);sender.set_owner_profile('beta');assert await sender.connect()
        chat=profile='beta'
    thread=str(uuid.uuid4())
    source=gate.build_source(chat_id=chat,chat_type='dm',user_id='owner',thread_id=thread)
    source.profile=profile
    key=gate._source_session_key(source)
    async def handle(event):
        guard=gate._active_sessions[key];guard._hermes_run_generation=7
        ctx=SimpleNamespace(_cleanup_progress=True,_cleanup_msg_ids=[],session_key=key,source=source,run_generation=7)
        tracker=TurnRunner(None,ctx)
        for text in ('first tool progress','second tool progress'):
            sent=await sender.send(chat,text,metadata={'thread_id':thread})
            tracker._track_progress_result(sent);ids.append(sent.message_id)
        edited=await sender.edit_message(chat,ids[0],'updated tool progress',finalize=False)
        tracker._track_progress_result(edited)
        GatewayTurnMixin._run_agent_schedule_bubble_cleanup(None,{'failed':failed},sender,ctx)
        # A stale generation must not consume this turn's callback.
        assert gate.pop_post_delivery_callback(key,generation=6) is None
        return 'final answer'
    gate.set_message_handler(handle)
    try:
        await gate.handle_message(MessageEvent(text='fake request',source=source,user_id='owner',message_id=str(uuid.uuid4())))
        async def completed():
            while key in gate._active_sessions or not ids:await asyncio.sleep(0.01)
            if not failed:
                while any(gate.journal.message(mid) for mid in ids):await asyncio.sleep(0.01)
        await asyncio.wait_for(completed(),5)
        finals=[row for row in gate.journal.records if row.get('text')=='final answer' and row.get('employee')==profile]
        assert len(finals)==1 and gate.journal.message(finals[0]['msg_id'])['text']=='final answer'
        if failed:
            assert all(gate.journal.message(mid) for mid in ids)
            assert gate.journal.message(ids[0])['text']=='updated tool progress'
        else:
            assert all(gate.journal.message(mid) is None for mid in ids)
            assert set(row['msg_id'] for row in gate.journal.records if row['type']=='delete')==set(ids)
        assert key not in gate._post_delivery_callbacks and key not in sender._post_delivery_callbacks
    finally:
        if forwarded:await sender.disconnect()


@pytest.mark.asyncio
@pytest.mark.parametrize('room', [False, True], ids=['dm', 'room'])
async def test_concurrent_ingress_cleanup_preserves_employee_chat_thread_and_owner(gate, client, monkeypatch, room):
    """Transport sharing never grants another profile, thread, or owner message deletion."""
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    employees = {row['id']: row for row in gate.employees()}
    monkeypatch.setattr(gate, 'employees', lambda: [
        {**employees['alpha'], 'id': 'default'}, employees['beta']])
    entered, finished, outcomes, retained = set(), asyncio.Event(), [], {}
    both = asyncio.Event()

    async def handle(event):
        profile, thread = event.source.profile, event.source.thread_id
        chat = event.source.chat_id
        own = await gate.send(chat, 'own progress', metadata={'thread_id': thread, 'hermes_profile': profile})
        other = await gate.send(chat, 'other thread', metadata={'thread_id': str(uuid.uuid4()), 'hermes_profile': profile})
        retained[profile] = other.message_id
        entered.add(profile)
        if len(entered) == 2:
            both.set()
        await asyncio.wait_for(both.wait(), 3)
        foreign = 'beta' if profile == 'default' else 'default'
        outcomes.append((
            await gate.delete_message(chat if room else foreign, retained[foreign]),
            await gate.delete_message(chat, other.message_id),
            await gate.delete_message(chat, event.message_id),
            await gate.delete_message(chat, own.message_id)))
        if len(outcomes) == 2:
            finished.set()
        return 'final answer'

    gate.set_message_handler(handle)
    ws, _ = await client.pair(features=['rooms'])
    room_chat = None
    if room:
        await ws.send_json({'v': 1, 'type': 'room_save', 'title': 'Fixture',
                            'members': ['default', 'beta'], 'lead': 'default'})
        frame = await client.read(ws)
        room_id = frame['room']['id']
        room_chat = 'room:' + room_id
        await client.send(ws, employee='default', room=room_id, text='@default @beta fixture request')
    else:
        await client.send(ws, employee='default')
        await client.send(ws, employee='beta')
    await asyncio.wait_for(finished.wait(), 5)
    assert outcomes == [(False, False, False, True)] * 2
    assert all(gate.journal.message(mid) for mid in retained.values())
    # The receive task's scope is reset; the listener alone cannot delete beta's text.
    assert not await gate.delete_message(room_chat or 'beta', retained['beta'])
    async with asyncio.timeout(3):
        while gate._active_sessions:
            await asyncio.sleep(0.01)
