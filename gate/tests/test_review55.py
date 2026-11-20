"""Independent-review regressions: compensation, availability and room ownership."""
import asyncio
import json
from pathlib import Path
import runpy
from types import SimpleNamespace as NS
import uuid
import pytest
from gate.auth import AuthRejected
from gate.hub import HubLink
from gate.connection_manager import Connections
from gate.connections import ConnectionFailure


@pytest.mark.asyncio
@pytest.mark.parametrize('native', [False, True], ids=['control', 'button'])
async def test_ir01_room_control_and_button_go_to_the_selected_employee(gate, client, runner, monkeypatch, native):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    from gate.tests.test_rooms import create
    ws, _ = await client.pair(features=['rooms'])
    room = await create(client, ws)
    thread = str(uuid.uuid4())
    if native:
        sent = await gate.send('room:'+room, '승인해 주세요', metadata={
            'hermes_profile':'beta','thread_id':thread,'hejo_buttons':[{'label':'승인','style':'primary'}]})
        post = await client.read(ws)
        await ws.send_json({'v':1,'type':'click','msg_id':sent.message_id,'button_id':post['buttons'][0]['id']})
    else:
        await client.send(ws, room=room, thread=thread, employee='beta', text='/stop', targeted=True)
    # This is the real wire validation and receive routing, not a direct helper call.
    async with asyncio.timeout(2):
        while not runner.events:
            frame = await client.read(ws)
            assert frame['type'] != 'error', frame
            await asyncio.sleep(0.01)
    assert [e.source.profile for e in runner.events] == ['beta']
    assert runner.events[0].text in {'/stop','승인'}


@pytest.mark.asyncio
@pytest.mark.parametrize('undo_fails', [False, True])
async def test_irs01_catalog_exception_compensates_all_written_keys(tmp_path, undo_fails):
    values = {'KEY_A': 'old-a', 'KEY_B': 'old-b'}
    calls = []
    async def request(*args, **kwargs):
        return {'entries': [{'name': 'fixture', 'required_env': [{'name': 'KEY_A'}, {'name': 'KEY_B'}]}]}
    async def save(profile, key, value):
        if key == 'KEY_B':
            raise ConnectionFailure('admin_failed')
        values[key] = value
        return {'outcome': 'done'}
    async def undo(profile, key):
        calls.append(key)
        if undo_fails:
            raise ConnectionFailure('admin_failed')
        values[key] = 'old-a'
        return {'outcome': 'done'}
    manager = Connections(tmp_path, lambda: [])
    manager.admin = NS(request=request)
    manager.secrets = NS(save=save, undo=undo)
    result = await manager.execute('device', 'alpha', 'catalog:fixture', 'catalog_install',
                                   {'KEY_A': 'new-a', 'KEY_B': 'new-b'}, {'kind': 'catalog', 'name': 'fixture'})
    assert calls == ['KEY_A']
    assert result['outcome'] == ('partial' if undo_fails else 'failed')
    assert result['reason'] == ('write_partial' if undo_fails else 'CONNECTIONS_READ_FAILED')
    assert values['KEY_A'] == ('new-a' if undo_fails else 'old-a')


@pytest.mark.asyncio
async def test_irs02_outage_preserves_only_recent_verified_connections():
    now = [0]
    hub = HubLink(clock=lambda: now[0])
    async def success(*args): return 200, {'device_id': 'fixture-device'}
    async def outage(*args): raise TimeoutError()
    hub.call = success
    assert await hub.verify('fixture-token', fresh=True) == 'fixture-device'
    hub.call = outage
    with pytest.raises(AuthRejected) as new:
        await hub.verify('new-token', fresh=True)
    assert new.value.reason == 'hub_unavailable'
    now[0] = 299
    assert await hub.verify('fixture-token', fresh=True, allow_cached=True) == 'fixture-device'
    now[0] = 301
    with pytest.raises(AuthRejected) as expired:
        await hub.verify('fixture-token', fresh=True, allow_cached=True)
    assert expired.value.reason == 'hub_unavailable'
    async def revoked(*args): return 401, {'error': 'revoked'}
    hub.call = revoked
    with pytest.raises(AuthRejected) as revoked_error:
        await hub.verify('fixture-token', fresh=True, allow_cached=True)
    assert revoked_error.value.reason == 'revoked'


@pytest.mark.asyncio
async def test_irs02_new_connection_outage_uses_legacy_safe_retry_frame(gate, client):
    from aiohttp import ClientSession
    async def unavailable(*args, **kwargs): raise AuthRejected('hub_unavailable')
    gate.hub.url = 'http://127.0.0.1'
    gate.hub.verify = unavailable
    async with ClientSession() as session:
        ws = await session.ws_connect(f'http://127.0.0.1:{gate.server.port}/v1/ws')
        await ws.send_json({'v': 1, 'type': 'hello', 'device_name': 'Fixture',
                            'app_version': 'test', 'token': 'fixture-token'})
        reply = await ws.receive_json(timeout=3)
        assert reply == {'v': 1, 'type': 'error', 'code': 'hub_unavailable', 'ref': None}


@pytest.mark.asyncio
async def test_irs06_nonmember_cannot_write_or_address_room(gate, client, runner):
    from gate.tests.test_rooms import create
    ws, _ = await client.pair(features=['rooms'])
    room = await create(client, ws)
    sent = await gate.send('room:'+room, 'not a member', metadata={'hermes_profile': 'default'})
    assert not sent.success and sent.error == 'room_member_required'
    head = gate.journal.head
    await client.send(ws, room=room, employee='default')
    frame = await client.read(ws)
    assert frame['type'] == 'error' and frame['code'] == 'room_member_required'
    assert gate.journal.head == head and not runner.events


def test_irs10_receipt_contains_only_owned_config_values(airport):
    installer = runpy.run_path(str(Path(__file__).resolve().parents[2]/'install/hejo-install'))
    path = airport/'config.yaml'
    original = 'unrelated: synthetic-owner-setting\nplugins: {enabled: []}\n'
    path.write_text(original)
    receipt = installer['plan'](airport)
    assert 'synthetic-owner-setting' not in json.dumps(receipt)
    # Legacy receipts are compacted as soon as read, with no configuration writes.
    receipt['configs']['config.yaml'].update(before=original, written=original)
    receipt_path = airport/'hejo/install-receipt.json'
    receipt_path.parent.mkdir(exist_ok=True)
    receipt_path.write_text(json.dumps(receipt))
    migrated = installer['load_receipt'](airport)
    assert 'synthetic-owner-setting' not in json.dumps(migrated)
    assert 'synthetic-owner-setting' not in receipt_path.read_text()
    assert path.read_text() == original


@pytest.mark.asyncio
async def test_irt04_latest_employee_post_is_live_same_scope_and_before_owner(gate,client,runner,monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS','owner')
    ws,_=await client.pair();thread=str(uuid.uuid4())
    post=await gate.send('alpha','scope choice',metadata={'thread_id':thread})
    await client.read(ws)
    await client.send(ws,thread=thread,text='메모')
    rows=await client.until(ws,'message');anchor=rows[-1]['msg_id']
    later=await gate.send('alpha','later post',metadata={'thread_id':thread})
    query=getattr(gate,'latest_employee_message',None)
    assert callable(query)
    got=await query('alpha','alpha',thread,anchor)
    assert got['msg_id']==post.message_id and got['text']=='scope choice'
    assert await query('beta','alpha',thread,anchor) is None
    assert await query('alpha','alpha',str(uuid.uuid4()),anchor) is None
    assert await query('alpha','alpha',thread,'missing') is None
    # The listener has no alpha delivery scope here; use its profile forwarder.
    from gate.adapter import HejoAdapter
    sender=HejoAdapter(gate.config);sender.set_owner_profile('alpha');assert await sender.connect()
    try:
        assert await sender.delete_message('alpha',post.message_id)
        assert await query('alpha','alpha',thread,anchor) is None
        assert (await sender.latest_employee_message('foreign','alpha',thread,anchor)) is None
    finally:await sender.disconnect()
