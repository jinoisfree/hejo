"""AT-SM-01–08/30–31: real Unix HTTP ingress and durable gate boundaries."""
import asyncio
import hashlib
import os
from pathlib import Path
import socket
import stat
import uuid

from aiohttp import ClientSession, UnixConnector, ClientConnectorError
import pytest
import pytest_asyncio

from gate.tests.support import wait_for_turns


@pytest_asyncio.fixture
async def local(gate, airport):
    async with ClientSession(connector=UnixConnector(path=str(airport / 'hejo' / 'post.sock')), trust_env=False) as session:
        async def call(method, path='/messages', *, status=200, **data):
            async with session.request(method, 'http://local/local/v1' + path,
                                       **({'json': data} if method != 'GET' else {})) as response:
                body = await response.json()
                assert response.status == status, body
                return body
        yield call


async def make_room(local, **overrides):
    return (await local('POST', '/rooms', **{'title': 'Fixture room', 'members': ['alpha', 'beta'],
                                           'lead': 'alpha', **overrides}))['room']


@pytest.mark.asyncio
async def test_at_sm_01_posts_reach_app_and_one_journal_row(gate, local, client):
    ws, _ = await client.pair(features=['rooms'])
    result = await local('POST', employee='alpha', text='Hello')
    frame = await client.read(ws)
    assert (frame['msg_id'], frame['thread'], frame['employee'], frame['role'], frame['text']) == (
        result['msg_id'], result['thread'], 'alpha', 'employee', 'Hello')
    assert result['repeated'] is False
    assert len(gate.journal.records) == 1
    assert gate.journal.records[0]['_meta']['local']['source'] == 'local'
    assert '_meta' not in frame
    room = await make_room(local)
    await client.read(ws)
    result = await local('POST', employee='beta', room=room, text='Room post')
    frame = await client.read(ws)
    assert frame['room'] == room and frame['employee'] == 'beta' and frame['msg_id'] == result['msg_id']
    assert sum(r['type'] == 'message' for r in gate.journal.records) == 2


@pytest.mark.asyncio
async def test_at_sm_02_edit_state_buttons_images_delete(gate, local, airport, client):
    from gate.adapter import _delivery_scope
    from gate.journal import RECORD_TYPES
    wire = Path('schemas/hejo-wire-v1.json')
    # The baseline hash was measured before adding the local contract.
    # HEJO-DEADLINE-CLOSE added definitions only (verdict V-2).
    # HEJO-TELEGRAM replaced the external-messenger frames only (verdict 2차, HT-B02).
    # HEJO-HISTORY adds only the negotiated, optional welcome.history field.
    # HEJO-DISCORD added definitions only (verdict 2회, B-1)
    # HEJO-OWNER-PROFILE added the optional owner field and its definition only (tasks D-03)
    # HEJO-TELEGRAM-REMOVE removed the HEJO-TELEGRAM definitions only
    assert hashlib.sha256(wire.read_bytes()).hexdigest() == 'd72ed5d1eaba6e505e8720f0d0723e43f1a9aa1248fca6096c97bf8a921cb6c2'
    assert RECORD_TYPES == {'message', 'edit', 'delete', 'state', 'room', 'room_delete'}
    ws, welcome = await client.pair()
    assert 'history' not in welcome
    result = await local('POST', employee='alpha', text='initial')
    msg = result['msg_id']
    await client.read(ws)
    buttons = [{'label': 'Approve', 'style': 'primary'}]
    await local('PATCH', '/messages/' + msg, employee='alpha', text='changed', buttons=buttons, reply_state='asked')
    edited, state = await client.read(ws), await client.read(ws)
    assert (edited['type'], edited['text'], state['type'], state['reply_state']) == ('edit', 'changed', 'state', 'asked')
    assert edited['buttons'][0]['label'] == 'Approve'
    assert gate.journal.message(msg)['reply_state'] == 'asked'
    direct = await gate.send('alpha', 'initial')
    await gate.edit_message('alpha', direct.message_id, 'changed', finalize=True, metadata={'hejo_buttons': buttons})
    await gate.set_reply_state(direct.message_id, 'asked')
    indirect = gate.journal.message(msg)
    explicit = gate.journal.message(direct.message_id)
    assert indirect.keys() == explicit.keys()  # both have internal button metadata
    for field in ('text', 'role', 'employee', 'reply_state', 'files'):
        assert indirect[field] == explicit[field]
    picture = airport / 'fixture.png'
    picture.write_bytes(bytes.fromhex('89504e470d0a1a0a') + b'fixture')
    result = await local('POST', employee='alpha', text='picture', images=[str(picture)])
    image = gate.journal.message(result['msg_id'])
    assert len(image['files']) == 1 and image['files'][0]['mime'] == 'image/png'
    direct_image = await gate.send_image_file('alpha', str(picture), caption='picture')
    expected = gate.journal.message(direct_image.message_id)
    for field in ('name', 'mime', 'size'):
        assert image['files'][0][field] == expected['files'][0][field]
    assert gate.files.registered('alpha', image['files'][0]['file_id'])[0].read_bytes() == picture.read_bytes()
    await local('DELETE', '/messages/' + msg, employee='alpha')
    assert gate.journal.records[-1]['type'] == 'delete'
    token = _delivery_scope.set(('alpha', 'alpha', explicit['thread']))
    try:
        assert await gate.delete_message('alpha', direct.message_id)
    finally:
        _delivery_scope.reset(token)
    assert gate.journal.records[-2].keys() == gate.journal.records[-1].keys()
    assert gate.journal.message(msg) is None


@pytest.mark.asyncio
async def test_at_sm_03_ordered_read_and_after(gate, local, client, runner):
    post = await local('POST', employee='alpha', text='one')
    ws, _ = await client.pair()
    await client.send(ws, thread=post['thread'], text='owner')
    await client.until(ws, 'message')
    await wait_for_turns(runner, 1)
    await local('POST', employee='alpha', thread=post['thread'], text='three')
    path = '/threads/' + post['thread'] + '?employee=alpha'
    rows = (await local('GET', path))['messages']
    assert [r['text'] for r in rows] == ['one', 'owner', 'three']
    assert [r['role'] for r in rows] == ['employee', 'owner', 'employee']
    assert all(set(r) == {'msg_id', 'seq', 'role', 'employee', 'text', 'ts', 'reply_state'} for r in rows)
    assert (await local('GET', path + '&after=' + str(rows[0]['seq'])))['messages'] == rows[1:]


@pytest.mark.asyncio
async def test_at_sm_04_rejections_never_record(gate, local, client):
    room = await make_room(local)
    post = await local('POST', employee='alpha', room=room, text='initial')
    ws, _ = await client.pair(features=['rooms'])
    head = gate.journal.head
    cases = [({'employee': 'missing'}, 'unknown_employee'),
             ({'room': str(uuid.uuid4())}, 'room_not_found'),
             ({'employee': 'default', 'room': room}, 'room_member_required'),
             ({'text': 'x' * 65537}, 'invalid_frame')]
    for fields, expected in cases:
        assert (await local('POST', status=400, **{'employee': 'alpha', 'text': 'denied', **fields}))['error'] == expected
        assert gate.journal.head == head
    assert (await local('PATCH', '/messages/' + post['msg_id'], status=400, employee='beta', text='wrong'))['error'] == 'message_not_found'
    assert (await local('DELETE', '/messages/' + post['msg_id'], status=400, employee='beta'))['error'] == 'message_not_found'
    assert gate.journal.head == head
    await ws.send_json({'v': 1, 'type': 'thread_delete', 'room': room, 'thread': post['thread']})
    deleted = await client.until(ws, 'delete')
    assert deleted[-1]['scope'] == 'thread'
    head = gate.journal.head
    assert (await local('POST', status=400, employee='alpha', room=room, thread=post['thread'], text='denied'))['error'] == 'thread_deleted'
    assert gate.journal.head == head
    await ws.send_json({'v': 1, 'type': 'room_delete', 'id': room})
    await client.until(ws, 'room_deleted')
    head = gate.journal.head
    assert (await local('POST', status=400, employee='alpha', room=room, text='denied'))['error'] == 'room_deleted'
    assert gate.journal.head == head


@pytest.mark.asyncio
async def test_at_sm_05_socket_lifecycle_and_tcp_separation(gate, local, airport):
    path = airport / 'hejo' / 'post.sock'
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    async with ClientSession(trust_env=False) as session:
        async with session.post(f'http://127.0.0.1:{gate.server.port}/local/v1/messages', json={}) as response:
            assert response.status == 404
    await gate.disconnect()
    assert not path.exists()
    stale = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    stale.bind(str(path))
    stale.close()
    assert path.exists()
    assert await gate.connect()
    assert stat.S_IMODE(path.stat().st_mode) == 0o600
    # A second ingress must not replace the running socket or delete a regular file.
    from gate.local import LocalIngress
    extra = LocalIngress(gate, airport)
    with pytest.raises(ValueError, match='local_socket_in_use'):
        await extra.start()
    assert path.exists()
    await gate.disconnect()
    path.write_text('preserve')
    with pytest.raises(ValueError, match='local_socket_path_occupied'):
        await extra.start()
    assert path.read_text() == 'preserve'
    path.unlink()


@pytest.mark.asyncio
async def test_at_sm_06_only_employee_metadata_and_primary_socket(gate, local, airport):
    from gate.adapter import HejoAdapter
    from gateway.config import PlatformConfig
    for unknown in ({'role': 'owner'}, {'_meta': {'recipients': ['beta']}}, {'_hejo_local': {'client_id': 'forged'}}):
        assert (await local('POST', status=400, employee='alpha', text='denied', **unknown))['error'] == 'invalid_frame'
    assert not gate.journal.records
    forwarder = HejoAdapter(PlatformConfig(enabled=True, extra={'role': 'forwarder'}))
    forwarder._owner_profile = 'beta'
    assert await forwarder.connect()
    assert forwarder.server is None
    assert not (airport / 'profiles' / 'beta' / 'hejo' / 'post.sock').exists()
    await forwarder.disconnect()


@pytest.mark.asyncio
async def test_at_sm_07_missing_socket_is_delivery_failure(airport):
    async with ClientSession(connector=UnixConnector(path=str(airport / 'hejo' / 'post.sock')), trust_env=False) as sender:
        with pytest.raises(ClientConnectorError):
            await sender.post('http://local/local/v1/messages', json={'employee': 'alpha', 'text': 'hello'})


@pytest.mark.asyncio
async def test_at_sm_08_dedup_restart_limits_and_deleted_original(gate, local, client):
    data = {'employee': 'alpha', 'text': 'once', 'client_id': 'occurrence-one'}
    first = await local('POST', **data)
    results = await asyncio.gather(*(local('POST', **data) for _ in range(4)))
    assert all(r == {**first, 'repeated': True} for r in results)
    assert len(gate.journal.records) == 1
    await gate.disconnect()
    original = gate
    gate = type(original)(original.config)
    assert gate is not original and gate.journal is None
    assert await gate.connect()
    try:
        assert await local('POST', **data) == {**first, 'repeated': True}
        other = await local('POST', **{**data, 'employee': 'beta'})
        assert other['msg_id'] != first['msg_id']
        head = gate.journal.head
        assert (await local('POST', status=400, employee='alpha', text='x' * 65537, client_id='too-long'))['error'] == 'invalid_frame'
        assert gate.journal.head == head
        boundary = await local('POST', employee='alpha', text='x' * 65536, client_id='too-long')
        assert boundary['repeated'] is False
        assert gate.journal.head == head + 1
        assert len(gate.journal.message(boundary['msg_id'])['text']) == 65536
        await local('DELETE', '/messages/' + first['msg_id'], employee='alpha')
        head = gate.journal.head
        assert (await local('POST', status=400, **data))['error'] == 'message_not_found'
        await local('DELETE', '/messages/' + first['msg_id'], employee='alpha')
        assert gate.journal.head == head
        another = await local('POST', **{**data, 'client_id': 'another'})
        assert another['repeated'] is False and another['msg_id'] != first['msg_id']
    finally:
        await gate.disconnect()



@pytest.mark.asyncio
async def test_at_sm_30_room_idempotency_and_validation(gate, local):
    data = {'title': 'Fixture room', 'members': ['alpha', 'beta'], 'lead': 'alpha'}
    first = await local('POST', '/rooms', **data)
    assert first['created'] is True
    for members in (['alpha', 'beta'], ['beta', 'alpha']):
        assert await local('POST', '/rooms', **{**data, 'members': members}) == {**first, 'created': False}
    assert gate.journal.head == 1
    for fields, error in [({'members': ['alpha']}, 'invalid_room'),
                          ({'members': ['alpha', 'missing']}, 'unknown_employee'),
                          ({'lead': 'default'}, 'invalid_room')]:
        assert (await local('POST', '/rooms', status=400, **{**data, **fields}))['error'] == error
        assert gate.journal.head == 1


@pytest.mark.asyncio
async def test_at_sm_31_room_conflict_ambiguous_archived_deleted(gate, local, client):
    room = await make_room(local, members=['alpha', 'default'])
    ws, _ = await client.pair(features=['rooms'])
    data = {'title': 'Fixture room', 'members': ['alpha', 'beta'], 'lead': 'alpha'}
    head = gate.journal.head
    result = await local('POST', '/rooms', status=409, **data)
    assert result == {'error': 'room_conflict', 'room': room, 'members': ['alpha', 'default'], 'lead': 'alpha', 'archived': False}
    assert gate.journal.head == head
    result = await local('POST', '/rooms', status=409, **{**data, 'members': ['alpha', 'default'], 'lead': 'default'})
    assert result['error'] == 'room_conflict' and gate.journal.head == head
    sent = await gate.send('room:' + room, 'denied', metadata={'hermes_profile': 'beta'})
    assert not sent.success and sent.error == 'room_member_required'
    await ws.send_json({'v': 1, 'type': 'room_archive', 'id': room, 'archived': True})
    await client.until(ws, 'room')
    head = gate.journal.head
    result = await local('POST', '/rooms', status=409, **{**data, 'members': ['alpha', 'default']})
    assert result['archived'] is True and gate.journal.head == head
    await ws.send_json({'v': 1, 'type': 'room_save', **data})
    await client.until(ws, 'room')
    head = gate.journal.head
    result = await local('POST', '/rooms', status=409, **data)
    assert result['error'] == 'room_ambiguous' and len(result['rooms']) == 2
    assert gate.journal.head == head
    for entry in result['rooms']:
        await ws.send_json({'v': 1, 'type': 'room_delete', 'id': entry['room']})
        await client.until(ws, 'room_deleted')
    assert (await local('POST', '/rooms', **data))['created'] is True


@pytest.mark.asyncio
async def test_at_sm_09_commit_failure_retry_and_state_contract(gate, local, monkeypatch):
    from gate.journal import HejoJournalError
    from gate.local import VALIDATORS
    async def unavailable(frame, internal=None):
        raise HejoJournalError('journal_write_failed')
    data = {'employee': 'alpha', 'text': 'retry me', 'client_id': 'durable-occurrence'}
    head = gate.journal.head
    with monkeypatch.context() as fault:
        fault.setattr(gate.journal, 'append', unavailable)
        assert await local('POST', status=503, **data) == {'error': 'journal_write_failed'}
    assert gate.journal.head == head
    first = await local('POST', **data)
    assert first['repeated'] is False and gate.journal.head == head + 1
    assert await local('POST', **data) == {**first, 'repeated': True}
    assert gate.journal.head == head + 1
    msg_id = first['msg_id']
    invalid = {'employee': 'alpha', 'text': 'must not change', 'reply_state': None}
    assert not VALIDATORS['patch'].is_valid(invalid)
    before = gate.journal.message(msg_id)
    assert await local('PATCH', '/messages/' + msg_id, status=400, **invalid) == {'error': 'invalid_frame'}
    assert gate.journal.message(msg_id) == before and gate.journal.head == head + 1
    for state in ('asked', 'answered', 'closed'):
        await local('PATCH', '/messages/' + msg_id, employee='alpha', reply_state=state)
        assert gate.journal.message(msg_id)['reply_state'] == state
    for fields in ({}, {'reply_state': None}):
        assert VALIDATORS['post'].is_valid({'employee': 'alpha', 'text': 'no state', **fields})
        posted = await local('POST', employee='alpha', text='no state', **fields)
        assert gate.journal.message(posted['msg_id'])['reply_state'] is None


@pytest.mark.asyncio
async def test_v5_edit_then_state_failure_converges_on_retry(gate, local, monkeypatch):
    from gate.journal import HejoJournalError
    posted = await local('POST', employee='alpha', text='before', reply_state='asked')
    msg_id = posted['msg_id']
    append = gate.journal.append
    async def fail_state(frame, internal=None):
        if frame['type'] == 'state':
            raise HejoJournalError('journal_write_failed')
        return await append(frame, internal)
    update = {'employee': 'alpha', 'text': 'after', 'reply_state': 'answered'}
    with monkeypatch.context() as fault:
        fault.setattr(gate.journal, 'append', fail_state)
        assert await local('PATCH', '/messages/' + msg_id, status=503, **update) == {'error': 'journal_write_failed'}
    partial = gate.journal.message(msg_id)
    assert partial['text'] == 'after' and partial['reply_state'] == 'asked'
    for _ in range(2):
        assert await local('PATCH', '/messages/' + msg_id, **update) == {'msg_id': msg_id}
        row = gate.journal.message(msg_id)
        assert row['text'] == 'after' and row['reply_state'] == 'answered'
    assert sum(r['type'] == 'message' for r in gate.journal.records) == 1


@pytest.mark.asyncio
async def test_at_sm_20_21_22_thread_owner_mentions_and_fallback(gate, local, client, runner, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    room = await make_room(local)
    first = await local('POST', employee='beta', room=room, text='Report')
    ws, _ = await client.pair(features=['rooms'])
    count = 0

    async def owner(thread, text, expected, **fields):
        nonlocal count
        await client.send(ws, room=room, thread=thread, text=text, **fields)
        await client.until(ws, 'message')
        count += len(expected)
        await wait_for_turns(runner, count)
        assert not runner.denied
        assert [e.source.profile for e in runner.events[count-len(expected):count]] == expected
        row = gate.journal.message(runner.events[-1].message_id)
        assert row['_meta']['recipients'] == expected

    await owner(first['thread'], 'Please revise', ['beta'])
    await owner(first['thread'], '@alpha another opinion', ['alpha'])
    await owner(first['thread'], 'Continue', ['beta'])
    human_thread = str(uuid.uuid4())
    await owner(human_thread, '@beta begin', ['beta'])
    await owner(human_thread, 'Continue', ['beta'])
    await owner(str(uuid.uuid4()), 'New topic', ['alpha'])
    await owner(first['thread'], 'Chosen recipient', ['alpha'], targeted=True)
    await owner(first['thread'], 'Continue again', ['beta'])
    # The owner metadata remains authoritative for a multi-recipient first post too.
    shared = str(uuid.uuid4())
    await owner(shared, '@alpha @beta together', ['alpha', 'beta'])
    await owner(shared, 'Continue together', ['alpha', 'beta'])
    await ws.send_json({'v': 1, 'type': 'room_save', 'id': room, 'title': 'Fixture room',
                        'members': ['alpha', 'default'], 'lead': 'alpha'})
    await client.until(ws, 'room')
    await owner(first['thread'], 'Former owner removed', ['alpha'])
    await owner(human_thread, 'Former recipient removed', ['alpha'])
    # Direct messages do not inherit room recipients or use mentions for routing.
    await client.send(ws, employee='beta', text='@alpha direct message')
    await client.until(ws, 'message')
    await wait_for_turns(runner, count + 1)
    assert runner.events[-1].source.profile == 'beta'
    assert runner.events[-1].source.chat_id == 'beta'


def test_at_sm_12_target_validation():
    from gate import parse_target
    room = str(uuid.uuid4())
    assert parse_target('room:' + room) == ('room:' + room, None)
    assert parse_target('alpha') == ('alpha', None)
    for value in ('room:', 'room:../alpha', 'room:/alpha', 'room:alpha/beta',
                  'room:' + room + '/extra', 'room:alpha', '../alpha'):
        assert parse_target(value) is None


async def exercise_room_scheduling(runner, secondary):
    """Run inside gateway_delivery's real start_gateway/stop lifecycle and audit guard."""
    from gateway.config import Platform
    from gateway.run import _profile_runtime_scope
    from cron.scheduler_delivery import _resolve_delivery_targets, _deliver_result
    primary = runner.adapters[Platform('hejo')]
    own = runner._profile_adapters['beta']
    root = Path(os.environ['HERMES_HOME'])
    loop = asyncio.get_running_loop()
    async with ClientSession(connector=UnixConnector(path=str(root / 'hejo' / 'post.sock')),
                             trust_env=False) as http:
        async with http.post('http://local/local/v1/rooms', json={
                'title': 'Schedule fixture', 'members': ['alpha', 'beta'], 'lead': 'alpha'}) as response:
            assert response.status == 200
            room = (await response.json())['room']

    async def scheduled(target, text, home=secondary, adapters=own):
        with _profile_runtime_scope(home, hydrate_secrets=False):
            job = {'id': 'fixture-room-job', 'name': 'Fixture', 'deliver': 'hejo:' + target}
            targets = _resolve_delivery_targets(job)
            assert targets[0]['chat_id'] == target and not targets[0].get('thread_id')
            return await asyncio.to_thread(_deliver_result, job, text, adapters, loop)

    for text in ('First report', 'Second report'):
        assert await scheduled('room:' + room, text) is None
    rows = [r for r in primary.journal.records if r['type'] == 'message']
    assert [r['text'] for r in rows] == ['First report', 'Second report']
    assert all(r['employee'] == 'beta' and r['room'] == room for r in rows)
    assert len({r['thread'] for r in rows}) == 2
    head = primary.journal.head
    assert 'room_not_found' in await scheduled('room:' + str(uuid.uuid4()), 'Missing')
    error = await scheduled('room:' + room, 'Outsider', root, runner.adapters)
    unexpected = [{k: row.get(k) for k in ('type', 'employee', 'text', 'room')}
                  for row in primary.journal.records if row['seq'] > head]
    assert 'room_member_required' in (error or ''), {'error': error, 'unexpected_records': unexpected}
    assert primary.journal.head == head
    async with ClientSession(trust_env=False) as http:
        async with http.ws_connect(f'http://127.0.0.1:{primary.server.port}/v1/ws') as ws:
            await ws.send_json({'v': 1, 'type': 'hello', 'device_name': 'Fixture', 'app_version': 'test',
                               'features': ['rooms'], 'pair_code': primary.auth.pair_code()})
            while (await ws.receive_json(timeout=5))['type'] != 'sync_done':
                pass
            await ws.send_json({'v': 1, 'type': 'room_delete', 'id': room})
            assert (await ws.receive_json(timeout=5))['type'] == 'room_deleted'
    # AT-SM-11b: primary profile identity across scheduler, attachments and real owner ingress.
    text_file, image_file = root / 'fixture.txt', root / 'fixture.png'
    text_file.write_text('fixture document')
    image_file.write_bytes(bytes.fromhex('89504e470d0a1a0a') + b'fixture')
    async with ClientSession(connector=UnixConnector(path=str(root / 'hejo' / 'post.sock')),
                             trust_env=False) as http:
        async def create(title, members, lead):
            async with http.post('http://local/local/v1/rooms', json={
                    'title': title, 'members': members, 'lead': lead}) as response:
                assert response.status == 200
                return (await response.json())['room']
        outside = await create('Outside fixture', ['alpha', 'beta'], 'alpha')
        member = await create('Member fixture', ['default', 'beta'], 'beta')
        leader = await create('Leader fixture', ['default', 'beta'], 'default')
        for identifier, allowed in ((outside, False), (member, True), (leader, True)):
            chat = 'room:' + identifier
            before = primary.journal.head
            error = await scheduled(chat, 'Primary report', root, runner.adapters)
            if allowed:
                assert error is None
                assert primary.journal.records[-1]['employee'] == 'default'
            else:
                assert 'room_member_required' in error
                assert primary.journal.head == before
            for send, path in ((primary.send_document, text_file), (primary.send_image_file, image_file)):
                before = primary.journal.head
                sent = await send(chat, str(path), caption='Primary attachment')
                if allowed:
                    assert sent.success, sent.error
                    row = primary.journal.message(sent.message_id)
                    assert row['employee'] == 'default' and len(row['files']) == 1
                    assert primary.files.registered('default', row['files'][0]['file_id'])
                else:
                    assert not sent.success and sent.error == 'room_member_required'
                    assert primary.journal.head == before
        # Explicit ingress author and forwarder identity remain independent of the room lead.
        async with http.post('http://local/local/v1/messages', json={
                'employee': 'beta', 'room': leader, 'text': 'Ingress author'}) as response:
            assert response.status == 200
            assert primary.journal.message((await response.json())['msg_id'])['employee'] == 'beta'
        assert await scheduled('room:' + leader, 'Forwarder author') is None
        assert primary.journal.records[-1]['employee'] == 'beta'

    replies = []
    async def fake_agent(event):
        assert event.source.profile == 'default'
        replies.append(event)
        return 'Primary reply'
    primary.set_message_handler(fake_agent)
    async with ClientSession(trust_env=False) as http:
        async with http.ws_connect(f'http://127.0.0.1:{primary.server.port}/v1/ws') as ws:
            await ws.send_json({'v': 1, 'type': 'hello', 'device_name': 'Fixture', 'app_version': 'test',
                               'features': ['rooms'], 'pair_code': primary.auth.pair_code()})
            while (await ws.receive_json(timeout=5))['type'] != 'sync_done':
                pass
            for identifier in (member, leader):
                thread = str(uuid.uuid4())
                await ws.send_json({'v': 1, 'type': 'send', 'employee': 'default', 'room': identifier,
                                   'thread': thread, 'text': 'Please answer', 'targeted': True,
                                   'client_msg_id': str(uuid.uuid4())})
                async with asyncio.timeout(5):
                    while True:
                        row = await ws.receive_json()
                        if row['type'] == 'message' and row['role'] == 'employee' and row['thread'] == thread:
                            assert row['employee'] == 'default' and row['text'] == 'Primary reply'
                            break
            assert len(replies) == 2
    head = primary.journal.head
    assert 'room_deleted_drop' in await scheduled('room:' + room, 'Deleted')
    assert primary.journal.head == head
    assert await scheduled('beta', 'Legacy target') is None
    last = primary.journal.records[-1]
    assert last['employee'] == 'beta' and last['text'] == 'Legacy target' and 'room' not in last
    for adapters in (runner.adapters, own):
        assert not adapters[Platform('probe_peer')].sent
    return {'acceptance': 'AT-SM-10-12/11b', 'room_reports': 2, 'other_platform_sends': 0}


@pytest.mark.asyncio
async def test_at_sm_10_11_12_actual_gateway_scheduler(tmp_path):
    import sys
    import tempfile
    with tempfile.TemporaryDirectory(prefix='hsmcron-', dir=os.environ.get('HEJO_GATE_TEST_TMPDIR') or '/tmp') as directory:
        sandbox = Path(directory).resolve()
        (sandbox / 'home').mkdir()
        (sandbox / 'airport').mkdir()
        env = {'PATH': os.defpath, 'HOME': str(sandbox / 'home'), 'HERMES_HOME': str(sandbox / 'airport'),
               'TMPDIR': str(sandbox), 'XDG_STATE_HOME': str(sandbox / 'state'),
               'HERMES_GATEWAY_LOCK_DIR': str(sandbox / 'locks'), 'HEJO_GATE_TEST_SANDBOX': str(sandbox),
               'HERMES_DISABLE_LAZY_INSTALLS': '1', 'PYTHONDONTWRITEBYTECODE': '1',
               'PYTHONPATH': os.pathsep.join(sys.path), 'NO_COLOR': '1'}
        # Only the scenario and fake profile setup differ from the existing full gateway harness.
        program = '''
import asyncio, os, runpy, sys
from pathlib import Path
from gate.tests import gateway_delivery as harness
scenario = runpy.run_path(sys.argv[1])
harness.exercise = scenario['exercise_room_scheduling']
original_setup = harness.setup
def setup(root):
    secondary = original_setup(root)
    from hermes_cli.profiles import create_profile
    create_profile('alpha', no_alias=True, no_skills=True)
    return secondary
harness.setup = setup
asyncio.run(harness.child(Path(os.environ['HEJO_GATE_TEST_SANDBOX'])))
'''
        process = await asyncio.create_subprocess_exec(sys.executable, '-c', program, str(Path(__file__).resolve()),
            cwd=sandbox, env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
        try:
            output, _ = await asyncio.wait_for(process.communicate(), 180)
        except BaseException:
            process.kill()
            await process.wait()
            raise
        (tmp_path / 'room-scheduler.log').write_bytes(output)
        assert process.returncode == 0, output.decode()
        assert b'"acceptance": "AT-SM-10-12/11b"' in output
        assert b'GATEWAY_EXIT clean' in output


@pytest.mark.asyncio
@pytest.mark.parametrize('members,lead,allowed', [
    (['alpha', 'beta'], 'alpha', False),
    (['default', 'beta'], 'beta', True),
    (['default', 'beta'], 'default', True),
])
async def test_at_sm_11b_remote_image_and_typing_author(gate, local, client, monkeypatch, members, lead, allowed):
    import httpx
    from tools import url_safety
    calls = []
    def response(request):
        calls.append(request.url)
        return httpx.Response(200, headers={'content-type': 'image/png'},
                              content=bytes.fromhex('89504e470d0a1a0a') + b'fixture')
    # External HTTP/DNS are fixtures; the adapter stages, promotes and records the real attachment.
    monkeypatch.setattr(url_safety, 'is_safe_url', lambda value: value == 'https://fixture.invalid/image.png')
    monkeypatch.setattr(url_safety, 'create_ssrf_safe_async_client',
                        lambda **kwargs: httpx.AsyncClient(transport=httpx.MockTransport(response), **kwargs))
    room = await make_room(local, members=members, lead=lead)
    head = gate.journal.head
    sent = await gate.send_image('room:' + room, 'https://fixture.invalid/image.png', caption='Remote fixture')
    assert len(calls) == 1
    if allowed:
        assert sent.success
        row = gate.journal.message(sent.message_id)
        assert row['employee'] == 'default' and len(row['files']) == 1
        assert gate.files.registered('default', row['files'][0]['file_id'])
    else:
        assert not sent.success and sent.error == 'room_member_required'
        assert gate.journal.head == head
    ws, _ = await client.pair(features=['rooms'])
    thread = str(uuid.uuid4())
    await gate.send_typing('room:' + room, {'thread_id': thread})
    frame = (await client.until(ws, 'typing'))[-1]
    assert frame['employee'] == 'default' and frame['thread'] == thread
    await gate.stop_typing('room:' + room, {'thread_id': thread})
    assert (await client.until(ws, 'typing'))[-1]['on'] is False
