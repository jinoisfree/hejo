"""HEJO-IMESSAGE acceptance contracts: real gate/Hermes, isolated home, fake phone transport."""
import asyncio
import json
from dataclasses import replace
from pathlib import Path
from unittest.mock import patch

import pytest
from gateway.config import Platform, PlatformConfig
from gateway.platforms.base import BasePlatformAdapter, SendResult
from gateway.platforms.event import MessageEvent
from gate import imessage
from gate.tests.support import airport, registered, gate, runner, client, wait_for_turns

pytestmark = pytest.mark.asyncio
# G is the acceptance document's symbolic group; wire room ids use the existing UUID contract.
G = '00000000-0000-4000-8000-000000000001'


class Phone(BasePlatformAdapter):
    MAX_MESSAGE_LENGTH = 100

    def __init__(self):
        super().__init__(PlatformConfig(enabled=True), Platform('hejo'))
        self.calls, self.originals = [], []
        self.failure = False
        self._mark_connected()

    async def handle_message(self, event):
        self.originals.append(event)

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        self.calls.append((chat_id, content, reply_to))
        return SendResult(success=not self.failure, message_id=f'im-out-{len(self.calls)}')

    async def connect(self):
        return True

    async def disconnect(self):
        pass

    async def get_chat_info(self, chat_id):
        return {"chat_id": chat_id, "type": "dm"}

    def event(self, text='hello', chat='chat-A', user='user-A', kind='dm', mid='im-in-1', **fields):
        source = self.build_source(chat_id=chat, user_id=user, chat_type=kind)
        source = replace(source, platform='photon')
        return MessageEvent(text=text, source=source, message_id=mid, **fields)


@pytest.fixture
def phone(registered, monkeypatch):
    value = Phone()
    factories = registered.get_platform_handler_factories('photon')
    assert len(factories) == 1
    monkeypatch.setattr(imessage, '_photon', None)
    factories[0][0](None, value)
    return value


@pytest.fixture(autouse=True)
def named_roster(gate, monkeypatch):
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")
    original = gate.employees
    def employees():
        return [{**e, 'name': {'alpha': 'Alpha', 'beta': 'Beta'}.get(e['id'], e['name']),
                 'aliases': ['al'] if e['id'] == 'alpha' else e.get('aliases', [])} for e in original()]
    monkeypatch.setattr(gate, 'employees', employees)


async def request(client, ws, kind='imessage', **fields):
    await ws.send_json({'v': 1, 'type': kind, 'id': 'request', **fields})
    while True:
        reply = await client.read(ws)
        if reply.get('ref') == 'request':
            return reply


async def pair_phone(client, ws, phone, **fields):
    code = await request(client, ws, 'imessage_pair')
    await phone.handle_message(phone.event(code['code'], **fields))
    status = await client.read(ws)
    assert status['paired']
    phone.calls.clear()
    return code


async def activate(client, ws, phone, room='alpha', reports=None):
    await pair_phone(client, ws, phone)
    return await request(client, ws, 'imessage_save', enabled=True, room=room, reports=reports or [])


async def group(gate):
    await gate.journal.append({'v': 1, 'type': 'room', 'room': {
        'id': G, 'title': 'Team', 'members': ['alpha', 'beta'], 'lead': 'alpha', 'archived': False, 'description': '', 'picture': None}})


async def test_at_hi_01_pair_private_reply_and_broadcast(gate, client, phone):
    ws, welcome = await client.pair(features=['imessage'])
    other, _ = await client.open(token=welcome['token'], features=['imessage'])
    code = await request(client, ws, 'imessage_pair')
    assert code == {'v': 1, 'type': 'imessage_code', 'ref': 'request', 'code': code['code'], 'expires_in': 600}
    assert len(code['code']) == 12
    await phone.handle_message(phone.event(code['code']))
    assert (await client.read(ws))['paired'] is True
    status = await client.read(other)
    assert status['paired'] is True and 'ref' not in status
    assert phone.calls == [('chat-A', '연결됐어요', None)]
    assert phone.originals == [] and gate.journal.head == 0


@pytest.mark.parametrize('case', ['wrong', 'expired', 'used', 'group', 'denied'])
async def test_at_hi_02_03_invalid_pair_passes_same_event(gate, client, phone, case):
    ws, _ = await client.pair(features=['imessage'])
    code = await request(client, ws, 'imessage_pair')
    if case == 'used':
        await phone.handle_message(phone.event(code['code']))
        await client.read(ws)
        phone.calls.clear()
    before = gate.imessage.private()['pair']
    if case == 'expired':
        gate.imessage.clock = lambda: 10**12
    if case == 'denied':
        phone.set_authorization_check(lambda *args: False)
    event = phone.event('wrong' if case == 'wrong' else code['code'], kind='group' if case == 'group' else 'dm')
    await phone.handle_message(event)
    assert phone.originals == [event] and phone.originals[0] is event
    assert not phone.calls and gate.imessage.private()['pair'] == before
    assert gate.journal.head == 0


async def test_at_hi_04_05_unpair_and_replace(gate, client, phone):
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    await pair_phone(client, ws, phone, chat='chat-B', user='user-B')
    assert not gate.claims_external(phone.event())
    assert gate.claims_external(phone.event(chat='chat-B', user='user-B'))
    state = await request(client, ws, 'imessage_unpair')
    assert state['ref'] == 'request' and not state['paired'] and not state['enabled'] and state['room'] == 'alpha'
    event = phone.event()
    await phone.handle_message(event)
    assert phone.originals == [event] and gate.journal.head == 0


async def test_at_hi_06_unavailable(gate, client, monkeypatch):
    monkeypatch.setattr(imessage, '_photon', None)
    ws, _ = await client.pair(features=['imessage'])
    assert (await request(client, ws, 'imessage_pair'))['code'] == 'imessage_unavailable'
    assert gate.imessage.private()['code'] is None
    assert not (await request(client, ws))['platform_ready']


async def test_at_hi_08_09_settings_atomic_validation_restart(gate, client, phone):
    await group(gate)
    ws, welcome = await client.pair(features=['imessage'])
    other, _ = await client.open(token=welcome['token'], features=['imessage'])
    await pair_phone(client, ws, phone)
    await client.read(other)
    status = await request(client, ws, 'imessage_save', enabled=True, room='alpha', reports=[G])
    assert status['room'] == 'alpha' and status['reports'] == [G] and status['ref'] == 'request'
    assert await client.read(other) == {k: v for k, v in status.items() if k != 'ref'}
    path = gate.imessage.settings_store.path / 'settings.json'
    assert path.stat().st_mode & 0o777 == 0o600
    before = path.read_bytes()
    for room, reports in [('nobody', []), ('alpha', [G, G]), ('alpha', ['nobody'])]:
        assert (await request(client, ws, 'imessage_save', enabled=True, room=room, reports=reports))['code'] == 'invalid_imessage'
        assert path.read_bytes() == before
    fresh = imessage.IMessage(gate, airport_home(gate))
    assert fresh.settings() == {'enabled': True, 'room': 'alpha', 'reports': [G]}
    await request(client, ws, 'imessage_unpair')
    await client.read(other)
    before = path.read_bytes()
    assert (await request(client, ws, 'imessage_save', enabled=True, room='alpha', reports=[]))['code'] == 'imessage_unpaired'
    assert path.read_bytes() == before


def airport_home(gate):
    return gate.imessage.vault.path.parent


async def test_at_hi_10_feature_mask(gate, client, phone):
    ws, welcome = await client.pair(features=['imessage'])
    old, _ = await client.open(token=welcome['token'])
    await activate(client, ws, phone)
    # A ping/pong boundary proves no feature frames were queued to a legacy client.
    await old.send_json({'v': 1, 'type': 'roster', 'id': 'boundary'})
    assert (await client.read(old))['type'] == 'roster'


@pytest.mark.parametrize('kind', ['room_delete', 'room_archive'])
async def test_at_hi_11_dead_rooms_filtered(gate, client, phone, kind):
    await group(gate)
    ws, welcome = await client.pair(features=['imessage', 'rooms'])
    await activate(client, ws, phone, room=G, reports=[G, 'alpha'])
    other, _ = await client.open(token=welcome['token'], features=['imessage', 'rooms'])
    await ws.send_json({'v': 1, 'type': kind, 'id': G, **({'archived': True} if kind == 'room_archive' else {})})
    for peer in (ws, other):
        assert (await client.read(peer))['type'] in {'room', 'room_deleted'}
        state = await client.read(peer)
        assert state['type'] == 'imessage_status' and 'ref' not in state
        assert state['room'] is None and state['reports'] == ['alpha']
        # A boundary also proves exactly one status was broadcast.
        await peer.send_json({'v': 1, 'type': 'roster', 'id': 'boundary'})
        assert (await client.read(peer))['type'] == 'roster'
    state = await request(client, ws)
    assert state['room'] is None and state['reports'] == ['alpha']


async def test_at_hi_31_claims_are_read_only(gate, client, phone):
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    before = [p.read_bytes() for p in [gate.imessage.vault.path / 'imessage.json', gate.imessage.settings_store.path / 'settings.json']]
    assert gate.claims_external(phone.event())
    assert not gate.claims_external(phone.event(chat='chat-B'))
    assert not gate.claims_external(phone.event(kind='group'))
    assert before == [p.read_bytes() for p in [gate.imessage.vault.path / 'imessage.json', gate.imessage.settings_store.path / 'settings.json']]
    assert not phone.calls and gate.journal.head == 0
    await request(client, ws, 'imessage_save', enabled=False, room='alpha', reports=[])
    assert not gate.claims_external(phone.event())
    code = await request(client, ws, 'imessage_pair')
    paths = [gate.imessage.vault.path / 'imessage.json', gate.imessage.settings_store.path / 'settings.json']
    before = [p.read_bytes() for p in paths]
    assert gate.claims_external(phone.event(code['code']))
    assert not gate.claims_external(phone.event('wrong'))
    phone.set_authorization_check(lambda *args: False)
    assert not gate.claims_external(phone.event(code['code']))
    assert before == [p.read_bytes() for p in paths]
    phone.set_authorization_check(lambda *args: True)
    await phone.handle_message(phone.event(code['code']))
    await client.read(ws)
    await request(client, ws, 'imessage_save', enabled=True, room='alpha', reports=[])
    phone.calls.clear()
    before = [p.read_bytes() for p in paths]
    assert not gate.claims_external(phone.event(code['code']))
    assert before == [p.read_bytes() for p in paths]
    code = await request(client, ws, 'imessage_pair')
    before = [p.read_bytes() for p in paths]
    gate.imessage.clock = lambda: 10**12
    assert not gate.claims_external(phone.event(code['code']))
    assert before == [p.read_bytes() for p in paths]
    assert not phone.calls and gate.journal.head == 0


async def test_photon_dispatch_uses_instance_handler_and_authorizer(gate, phone, registered):
    # Use actual photon normalization without constructing a sidecar or reading credentials.
    from plugins.platforms.photon.adapter import PhotonAdapter
    native = PhotonAdapter.__new__(PhotonAdapter)
    BasePlatformAdapter.__init__(native, PlatformConfig(enabled=True), Platform('hejo'))
    native.platform = 'photon'
    native._last_inbound_by_chat = {}
    native._recent_richlinks_by_chat = {}
    native._pending_parts = {}
    native._sent_message_ids = {}
    native.require_mention = False
    events = []
    async def original(event):
        events.append(event)
    native.handle_message = original
    registered.get_platform_handler_factories('photon')[0][0](None, native)
    await native._dispatch_inbound({'messageId': 'im-in-1', 'space': {'id': 'chat-A', 'type': 'dm'},
                                    'sender': {'id': 'user-A'}, 'content': {'type': 'text', 'text': 'hello'}})
    assert len(events) == 1 and events[0].text == 'hello'
    native.set_authorization_check(lambda user, kind, chat: False)
    assert native._is_sender_authorized('user-A', 'dm', 'chat-A') is False


async def test_at_hi_12_13_17_normal_dm_group_and_duplicate(gate, runner, client, phone):
    await group(gate)
    ws, _ = await client.pair(features=['imessage', 'rooms'])
    await activate(client, ws, phone)
    event = phone.event()
    await phone.handle_message(event)
    row = await client.read(ws)
    assert row['role'] == 'owner' and row['employee'] == 'alpha' and 'room' not in row
    assert row['text'] == 'hello' and row['client_msg_id'] == 'imessage:im-in-1'
    await wait_for_turns(runner, 1)
    e = runner.events[0]
    assert e.source.platform.value == 'hejo' and e.source.chat_id == 'alpha'
    assert e.source.profile == 'alpha' and e.source.user_id == 'owner' and e.source.thread_id == row['thread']
    await phone.handle_message(event)
    assert len([r for r in gate.journal.records if r['type'] == 'message']) == 1 and len(runner.events) == 1 and not phone.originals
    await request(client, ws, 'imessage_save', enabled=True, room=G, reports=[])
    for text, expected, mid in [('hi', 'alpha', 'im-in-2'), ('@Beta hi', 'beta', 'im-in-3')]:
        await phone.handle_message(phone.event(text, mid=mid))
        row = (await client.until(ws, 'message'))[-1]
        await wait_for_turns(runner, 2 if mid == 'im-in-2' else 3)
        assert row['room'] == G and runner.events[-1].source.profile == expected
    assert len(runner.events) == 3


@pytest.mark.parametrize('case', ['unpaired', 'disabled', 'chat', 'group', 'user'])
async def test_at_hi_16_passthrough(gate, runner, client, phone, case):
    ws, _ = await client.pair(features=['imessage'])
    if case != 'unpaired':
        await activate(client, ws, phone)
    if case == 'disabled':
        await request(client, ws, 'imessage_save', enabled=False, room='alpha', reports=[])
    event = phone.event(chat='chat-B' if case == 'chat' else 'chat-A', kind='group' if case == 'group' else 'dm',
                        user='user-B' if case == 'user' else 'user-A')
    source = replace(event.source)
    await phone.handle_message(event)
    assert phone.originals == [event] and phone.originals[0] is event
    assert event.source == source and not phone.calls and gate.journal.head == 0 and not runner.events


async def test_at_hi_18_19_attachment_reaction_and_receive_failure(gate, runner, client, phone):
    from gate.journal import HejoJournalError
    from gate.server import LIMITS
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    await phone.handle_message(phone.event('look', media_urls=['fixture.png']))
    assert (await client.read(ws))['text'] == 'look'
    await wait_for_turns(runner, 1)
    assert len(phone.calls) == 1
    for text, raw, expected in [('', None, 1), ('reaction', {'content': {'type': 'reaction'}}, 0)]:
        phone.calls.clear()
        await phone.handle_message(phone.event(text, raw_message=raw, media_urls=['fixture.png'], mid='im-in-2'))
        assert len(phone.calls) == expected and gate.journal.head == 1
    phone.calls.clear()
    with patch.object(gate.journal, 'append', side_effect=HejoJournalError('fixture failure')):
        await phone.handle_message(phone.event('failure', mid='im-in-3'))
    assert (await client.until(ws, 'error'))[-1]['code'] == 'journal_write_failed'
    assert len(phone.calls) == 1 and len(runner.events) == 1 and gate.journal.head == 1
    phone.calls.clear()
    await phone.handle_message(phone.event('a' * (LIMITS['text_bytes'] + 1), mid='im-in-4'))
    assert len(phone.calls) == 1 and len(runner.events) == 1 and gate.journal.head == 1
    await phone.handle_message(phone.event('next', mid='im-in-5'))
    assert (await client.until(ws, 'message'))[-1]['text'] == 'next'
    await wait_for_turns(runner, 2)


async def test_at_hi_20_21_room_commands(gate, client, phone):
    await group(gate)
    ws, _ = await client.pair(features=['imessage', 'rooms'])
    await activate(client, ws, phone)
    await phone.handle_message(phone.event('/방'))
    listing = phone.calls[-1][1]
    expected = ['default', 'Alpha', 'Beta', 'Team']
    assert listing == '연결된 방: Alpha\n' + '\n'.join(f'{n}. {name}' for n, name in enumerate(expected, 1))
    for choice, room in [('3', 'beta'), ('al', 'alpha'), ('team', G)]:
        before = len(phone.calls)
        await phone.handle_message(phone.event('/방 ' + choice))
        assert (await client.read(ws))['room'] == room and len(phone.calls) == before + 1
    before = gate.imessage.settings()
    for choice in ['9', 'nobody']:
        n = len(phone.calls)
        await phone.handle_message(phone.event('/방 ' + choice))
        assert gate.imessage.settings() == before and len(phone.calls) == n + 1
    await gate.journal.append({'v': 1, 'type': 'room', 'room': {**gate.journal.rooms[G], 'title': 'Alpha'}})
    await phone.handle_message(phone.event('/방 alpha'))
    assert gate.imessage.settings() == before
    assert not phone.originals and not [r for r in gate.journal.records if r['type'] == 'message']
    await request(client, ws, 'imessage_save', enabled=False, room='alpha', reports=[])
    phone.calls.clear()
    e = phone.event('/방')
    await phone.handle_message(e)
    assert phone.originals == [e] and not phone.calls


@pytest.mark.parametrize('outer', ['hejo', 'reception'])
async def test_at_hi_32_wrapper_order(gate, runner, client, phone, outer):
    # Rebuild only the fake transport's handler chain, preserving the production factory.
    phone.handle_message = Phone.handle_message.__get__(phone)
    phone._hejo_imessage_wrapped = False
    classifications = []
    def reception():
        original = phone.handle_message
        async def handle(e):
            if not gate.claims_external(e): classifications.append(e)
            return await original(e)
        phone.handle_message = handle
    if outer == 'hejo': reception()
    imessage.attach_photon(None, phone)
    if outer == 'reception': reception()
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    await phone.handle_message(phone.event())
    assert (await client.read(ws))['text'] == 'hello'
    await wait_for_turns(runner, 1)
    assert len(runner.events) == 1 and not classifications
    other = phone.event(chat='chat-B')
    await phone.handle_message(other)
    assert classifications == [other] and phone.originals == [other]


@pytest.fixture
def settle(gate):
    gate.imessage.settle_seconds = 0.05
    async def wait():
        async with asyncio.timeout(3):
            while gate.imessage.workers:
                await asyncio.sleep(0.01)
    return wait


async def phone_thread(gate, runner, client, ws, phone):
    await activate(client, ws, phone)
    await phone.handle_message(phone.event())
    row = (await client.until(ws, 'message'))[-1]
    await wait_for_turns(runner, 1)
    # BasePlatformAdapter runs the substituted turn in its own task.
    async with asyncio.timeout(3):
        while gate._active_sessions:
            await asyncio.sleep(0.01)
    return row['thread']


async def test_at_hi_14_15_22_reply_follows_original_thread(gate, runner, client, phone, settle):
    ws, _ = await client.pair(features=['imessage', 'rooms'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    await gate.send_typing('alpha', {'thread_id': thread})
    result = await gate.send('alpha', 'pong', metadata={'thread_id': thread})
    await gate.stop_typing('alpha')
    await settle()
    assert phone.calls == [('chat-A', '[Alpha] pong', 'im-in-1')]
    assert gate.imessage.sent == {'im-out-1': result.message_id}
    await request(client, ws, 'imessage_save', enabled=True, room='beta', reports=[])
    for n, target in enumerate(['im-out-1', 'im-in-1', 'im-out-1'], 2):
        if n == 4:
            await request(client, ws, 'imessage_save', enabled=True, room=None, reports=[])
        await phone.handle_message(phone.event('reply', mid=f'im-in-{n}', reply_to_message_id=target))
        row = [r for r in gate.journal.records if r.get('client_msg_id') == f'imessage:im-in-{n}'][0]
        assert row['employee'] == 'alpha' and row['thread'] == thread
    await request(client, ws, 'imessage_save', enabled=True, room='beta', reports=[])
    await phone.handle_message(phone.event('unknown', mid='im-in-5', reply_to_message_id='missing'))
    unknown = [r for r in gate.journal.records if r.get('client_msg_id') == 'imessage:im-in-5'][0]
    assert unknown['employee'] == 'beta' and unknown['thread'] != thread
    await gate.thread_delete({'room': 'alpha', 'thread': thread, 'id': 'delete'}, next(iter(gate.server.connections)))
    await phone.handle_message(phone.event('deleted', mid='im-in-6', reply_to_message_id='im-out-1'))
    assert [r for r in gate.journal.records if r.get('client_msg_id') == 'imessage:im-in-6'][0]['employee'] == 'beta'
    await request(client, ws, 'imessage_save', enabled=True, room=None, reports=[])
    phone.calls.clear()
    before = gate.journal.head
    await phone.handle_message(phone.event('no room', mid='im-in-7'))
    assert gate.journal.head == before and len(phone.calls) == 1 and '/방' in phone.calls[0][1]


async def test_at_hi_23_24_report_rooms_and_app_threads(gate, runner, client, phone, settle):
    await group(gate)
    ws, _ = await client.pair(features=['imessage', 'rooms'])
    await activate(client, ws, phone, reports=[G])
    assert (await gate.send('room:' + G, 'report', metadata={'hermes_profile': 'beta'})).success
    await settle()
    assert phone.calls == [('chat-A', '[Team · Beta] report', None)]
    await client.send(ws, room=G, text='from app')
    row = (await client.until(ws, 'message'))[-1]
    while row.get('role') != 'owner':
        row = (await client.until(ws, 'message'))[-1]
    await wait_for_turns(runner, 1)
    await gate.send('room:' + G, 'done', metadata={'hermes_profile': 'alpha', 'thread_id': row['thread']})
    await settle()
    assert phone.calls[-1] == ('chat-A', '[Team · Alpha] done', None) and len(phone.calls) == 2
    await request(client, ws, 'imessage_save', enabled=True, room='alpha', reports=[])
    await client.send(ws, text='private app')
    row = (await client.until(ws, 'message'))[-1]
    while row.get('role') != 'owner': row = (await client.until(ws, 'message'))[-1]
    await gate.send('alpha', 'private answer', metadata={'thread_id': row['thread']})
    await settle()
    assert len(phone.calls) == 2


async def test_at_hi_25_stream_final_and_deleted_progress(gate, runner, client, phone, settle):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    await gate.send_typing('alpha', {'thread_id': thread})
    await gate.send('alpha', '생각 중…', metadata={'thread_id': thread})
    result = await gate.send('alpha', 'p', metadata={'thread_id': thread, 'expect_edits': True})
    for text in ['f', 'fi', 'fin']:
        assert (await gate.edit_message('alpha', result.message_id, text)).success
    assert (await gate.edit_message('alpha', result.message_id, 'final', finalize=True)).success
    tool = await gate.send('alpha', 'tool', metadata={'thread_id': thread})
    # Deletion enforces profile ownership, just as the real multiplex forwarder does.
    from gate.adapter import _delivery_scope
    token = _delivery_scope.set(('alpha', 'alpha', thread))
    try:
        assert await gate.delete_message('alpha', tool.message_id)
    finally:
        _delivery_scope.reset(token)
    await asyncio.sleep(0.08)
    assert not phone.calls
    await gate.stop_typing('alpha')
    await settle()
    assert phone.calls == [('chat-A', '[Alpha] final', 'im-in-1')]


@pytest.mark.parametrize('case', ['failed_turn', 'delete_failure', 'late_delete'])
async def test_at_hi_42_remaining_progress_is_sent(gate, runner, client, phone, settle, case):
    from gate.adapter import _delivery_scope
    from gate.journal import HejoJournalError
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    await gate.send_typing('alpha', {'thread_id': thread})
    tool = await gate.send('alpha', 'tool', metadata={'thread_id': thread})
    final = 'failed' if case == 'failed_turn' else 'final'
    await gate.send('alpha', final, metadata={'thread_id': thread})
    await gate.stop_typing('alpha')
    token = _delivery_scope.set(('alpha', 'alpha', thread))
    try:
        if case == 'delete_failure':
            with patch.object(gate.journal, 'append', side_effect=HejoJournalError('fixture failure')):
                assert not await gate.delete_message('alpha', tool.message_id)
        await settle()
        assert [c[1] for c in phone.calls] == ['[Alpha] tool', '[Alpha] ' + final]
        if case == 'late_delete':
            assert await gate.delete_message('alpha', tool.message_id)
            await settle()
            assert len(phone.calls) == 2
    finally:
        _delivery_scope.reset(token)


async def test_at_hi_26_character_split_persistence_and_newline(gate, runner, client, phone, settle):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    text = '가' * 125 + 'a' * 125
    result = await gate.send('alpha', text, metadata={'thread_id': thread})
    await settle()
    assert [len(c[1]) for c in phone.calls] == [100, 100, 58]
    assert ''.join(c[1] for c in phone.calls) == '[Alpha] ' + text
    assert [c[2] for c in phone.calls] == ['im-in-1'] * 3
    assert set(gate.imessage.sent.values()) == {result.message_id}
    assert len(gate.imessage.sent) == 3 and gate.imessage.sent_path.stat().st_mode & 0o777 == 0o600
    await gate.imessage.close()
    gate.imessage = imessage.IMessage(gate, airport_home(gate))
    gate.imessage.settle_seconds = 0.05
    await phone.handle_message(phone.event('reply', mid='im-in-2', reply_to_message_id='im-out-3'))
    assert [r for r in gate.journal.records if r.get('client_msg_id') == 'imessage:im-in-2'][0]['thread'] == thread
    phone.calls.clear()
    text = '가' * 60 + '\n' + '나' * 60
    await gate.send('alpha', text, metadata={'thread_id': thread})
    await settle()
    assert [len(c[1]) for c in phone.calls] == [69, 60]
    assert ''.join(c[1] for c in phone.calls) == '[Alpha] ' + text


async def test_at_hi_27_buttons_and_files(gate, runner, client, phone, settle):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    await gate.send('alpha', 'pick', metadata={'thread_id': thread, 'hejo_buttons': [
        {'label': 'A', 'style': 'default'}, {'label': 'B', 'style': 'default'}]})
    await settle()
    assert phone.calls[-1][1] == '[Alpha] pick\n선택: A / B'
    await gate.send('alpha', 'ok?', metadata={'thread_id': thread, '_hejo_native_buttons': [
        {'label': 'approve', 'kind': 'approval', 'style': 'primary'}]})
    await settle()
    assert phone.calls[-1][1] == '[Alpha] ok?\n(이 선택은 hejo 앱에서 눌러 주세요)'
    file = airport_home(gate) / 'r.txt'
    file.write_text('fixture')
    await gate.send_document('alpha', str(file), metadata={'thread_id': thread})
    await settle()
    assert phone.calls[-1][1] == '[Alpha] 📎 r.txt (hejo 앱에서 열기)'


async def test_at_hi_28_send_failure_isolated(gate, runner, client, phone, settle, caplog):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    phone.failure = True
    first = await gate.send('alpha', 'first', metadata={'thread_id': thread})
    await settle()
    assert len(phone.calls) == 1 and not gate.imessage.sent
    logs = [r.message for r in caplog.records if r.name == 'gate.imessage']
    assert logs == ['imessage_send_failed']
    phone.failure = False
    second = await gate.send('alpha', 'second', metadata={'thread_id': thread})
    await settle()
    assert len(phone.calls) == 2 and len(gate.imessage.sent) == 1
    for mid in [first.message_id, second.message_id]: assert gate.journal.message(mid)
    messages = (await client.until(ws, 'message'))
    while not any(f.get('msg_id') == second.message_id for f in messages):
        messages += await client.until(ws, 'message')
    assert {first.message_id, second.message_id} <= {f.get('msg_id') for f in messages}


@pytest.mark.parametrize('case', ['restart', 'disabled', 'unpaired'])
async def test_at_hi_29_no_pending_replay(gate, runner, client, phone, settle, case):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    if case == 'restart':
        await gate.send('alpha', 'pending', metadata={'thread_id': thread})
        await gate.imessage.close()
        gate.imessage = imessage.IMessage(gate, airport_home(gate))
    else:
        await request(client, ws, 'imessage_unpair' if case == 'unpaired' else 'imessage_save',
                      **({} if case == 'unpaired' else {'enabled': False, 'room': 'alpha', 'reports': []}))
        await gate.send('alpha', 'pending', metadata={'thread_id': thread})
    await settle()
    await asyncio.sleep(0.08)
    assert not phone.calls


async def test_at_hi_07_sensitive_values_only_in_allowed_outputs(gate, runner, client, phone, settle, caplog, monkeypatch):
    import logging
    caplog.set_level(logging.DEBUG)
    ws, welcome = await client.pair(features=['imessage'])
    other, _ = await client.open(token=welcome['token'], features=['imessage'])
    received = {ws: [], other: []}
    read = client.read
    async def capture(socket):
        frame = await read(socket)
        received[socket].append(frame)
        return frame
    monkeypatch.setattr(client, 'read', capture)
    code = await pair_phone(client, ws, phone)
    await client.read(other)
    await request(client, ws, 'imessage_save', enabled=True, room='alpha', reports=[])
    await client.read(other)
    await phone.handle_message(phone.event('hello'))
    owner = (await client.until(ws, 'message'))[-1]
    await wait_for_turns(runner, 1)
    await phone.handle_message(phone.event('/방'))
    phone.calls.clear()
    await gate.send('alpha', 'pong', metadata={'thread_id': owner['thread']})
    await settle()
    for socket in [ws, other]:
        await socket.send_json({'v': 1, 'type': 'roster', 'id': 'boundary'})
        await client.until(socket, 'roster')
    log = '\n'.join(r.getMessage() for r in caplog.records)
    private = gate.imessage.vault.path / 'imessage.json'
    settings = gate.imessage.settings_store.path / 'settings.json'
    sent = gate.imessage.sent_path
    journal = '\n'.join(p.read_text() for p in gate.journal.path.glob('*.jsonl'))
    frames = [f for items in received.values() for f in items]
    for socket, items in received.items():
        matches = [f for f in items if code['code'] in json.dumps(f)]
        assert matches == [code] if socket is ws else not matches
    assert code['code'] not in log + journal + private.read_text() + settings.read_text() + sent.read_text()
    for identifier in ['chat-A', 'user-A']:
        assert identifier in private.read_text()
        assert identifier not in log + journal + json.dumps(frames) + settings.read_text() + sent.read_text()
    for body in ['hello', 'pong']:
        assert body in journal
        assert body not in log + private.read_text() + settings.read_text() + sent.read_text()
        assert all(body not in json.dumps(f) for f in frames if f['type'] not in ['message', 'edit'])
    assert private.stat().st_mode & 0o777 == 0o600
    assert phone.calls == [('chat-A', '[Alpha] pong', 'im-in-1')]


async def test_at_hi_30_42_journal_and_app_frames_preserved(gate, airport, monkeypatch):
    """Same app input and failed/deleted progress sequences in two disposable homes."""
    from aiohttp import ClientSession
    from gate.adapter import HejoAdapter, _delivery_scope
    from gate.journal import HejoJournalError
    results = []
    for active in [False, True]:
        home = airport / ('enabled' if active else 'baseline')
        monkeypatch.setenv('HERMES_HOME', str(home))
        adapter = HejoAdapter(PlatformConfig(enabled=True, extra={'listen': ['127.0.0.1'], 'port': 0}))
        adapter.employees = lambda: [{'id': 'alpha', 'name': 'Alpha', 'aliases': []}]
        assert await adapter.connect()
        transport = Phone()
        if active:
            imessage.attach_photon(None, transport)
            with adapter.imessage.vault.locked():
                adapter.imessage.vault.write('imessage.json', {'pair': {'platform': 'photon', 'chat_id': 'chat-A', 'user_id': 'user-A', 'paired_at': 0}, 'code': None})
            with adapter.imessage.settings_store.locked():
                adapter.imessage.settings_store.write('settings.json', {'enabled': True, 'room': 'alpha', 'reports': ['alpha']})
        else:
            monkeypatch.setattr(imessage, '_photon', None)
        adapter.imessage.settle_seconds = 0.05
        async def turn(e): return None
        adapter.set_message_handler(turn)
        try:
            async with ClientSession(trust_env=False) as session:
                ws = await session.ws_connect(f'http://127.0.0.1:{adapter.server.port}/v1/ws')
                await ws.send_json({'v': 1, 'type': 'hello', 'device_name': 'Fixture', 'app_version': 'test', 'pair_code': adapter.auth.pair_code()})
                assert (await ws.receive_json(timeout=5))['type'] == 'welcome'
                assert (await ws.receive_json(timeout=5))['type'] == 'sync_done'
                thread = '00000000-0000-4000-8000-000000000002'
                await ws.send_json({'v': 1, 'type': 'send', 'id': 'input', 'employee': 'alpha', 'thread': thread,
                                    'client_msg_id': 'fixture-client', 'text': 'app request'})
                frames = []
                async with asyncio.timeout(3):
                    while not any(f['type'] == 'message' for f in frames): frames.append(await ws.receive_json())
                    while adapter._active_sessions: await asyncio.sleep(0.01)
                for case in ['failed_turn', 'delete_failure', 'late_delete', 'ordinary_delete']:
                    await adapter.send_typing('alpha', {'thread_id': thread})
                    tool = await adapter.send('alpha', 'tool', metadata={'thread_id': thread})
                    await adapter.send('alpha', 'failed' if case == 'failed_turn' else 'final', metadata={'thread_id': thread})
                    token = _delivery_scope.set(('alpha', 'alpha', thread))
                    try:
                        if case == 'ordinary_delete': assert await adapter.delete_message('alpha', tool.message_id)
                        await adapter.stop_typing('alpha')
                        if case == 'delete_failure':
                            with patch.object(adapter.journal, 'append', side_effect=HejoJournalError('fixture')):
                                assert not await adapter.delete_message('alpha', tool.message_id)
                        async with asyncio.timeout(3):
                            while adapter.imessage.workers: await asyncio.sleep(0.01)
                        if case == 'late_delete': assert await adapter.delete_message('alpha', tool.message_id)
                    finally:
                        _delivery_scope.reset(token)
                await ws.send_json({'v': 1, 'type': 'roster', 'id': 'boundary'})
                while True:
                    frame = await ws.receive_json(timeout=5)
                    if frame['type'] == 'roster': break
                    frames.append(frame)
                ids = {r['msg_id']: f'message-{n}' for n, r in enumerate(adapter.journal.records) if r['type'] == 'message'}
                def normalized(row):
                    return {k: ids.get(v, v) if isinstance(v, str) else v for k, v in row.items() if k not in ['seq', 'msg_id', 'ts']}
                disk = [json.loads(line) for p in adapter.journal.path.glob('*.jsonl') for line in p.read_text().splitlines()]
                results.append(([normalized(r) for r in disk], [normalized(f) for f in frames]))
                if active:
                    assert [c[1] for c in transport.calls] == ['[Alpha] tool', '[Alpha] failed', '[Alpha] tool', '[Alpha] final', '[Alpha] tool', '[Alpha] final', '[Alpha] final']
        finally:
            await adapter.disconnect()
    assert results[0] == results[1]


async def test_at_hi_39_real_gateway_cleanup():
    from gate.tests.imessage_settling import main
    assert await asyncio.to_thread(main) == 0


async def test_claim_exception_passes_original_unchanged(gate, client, phone):
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    event = phone.event()
    with patch.object(gate.imessage, 'claims_external', side_effect=ValueError('fixture')):
        await phone.handle_message(event)
    assert phone.originals == [event] and phone.originals[0] is event and gate.journal.head == 0


async def test_transport_readiness_and_queries_do_not_create_settings(gate, client, phone):
    ws, _ = await client.pair(features=['imessage'])
    assert not gate.imessage.settings_store.path.exists()
    assert (await request(client, ws))['platform_ready']
    assert not gate.imessage.settings_store.path.exists()
    phone._mark_disconnected()
    assert not (await request(client, ws))['platform_ready']
    assert (await request(client, ws, 'imessage_pair'))['code'] == 'imessage_unavailable'
    assert gate.imessage.private()['code'] is None


async def test_mixed_button_guidance_and_disconnected_outbound(gate, runner, client, phone, settle):
    ws, _ = await client.pair(features=['imessage'])
    thread = await phone_thread(gate, runner, client, ws, phone)
    phone.MAX_MESSAGE_LENGTH = 1000
    await gate.send('alpha', 'pick', metadata={'thread_id': thread,
        'hejo_buttons': [{'label': 'A', 'style': 'default'}],
        '_hejo_native_buttons': [{'label': 'approve', 'kind': 'approval', 'style': 'primary'}]})
    await settle()
    assert phone.calls == [('chat-A', '[Alpha] pick\n선택: A\n(이 선택은 hejo 앱에서 눌러 주세요)', 'im-in-1')]
    phone.calls.clear(); phone._mark_disconnected()
    await gate.send('alpha', 'not ready', metadata={'thread_id': thread})
    await settle()
    assert not phone.calls


@pytest.mark.parametrize('failure', ['journal', 'oversize', 'unexpected'])
async def test_at_hi_19_failure_isolated_and_next_message_works(gate, runner, client, phone, caplog, failure):
    from gate.journal import HejoJournalError
    from gate.server import LIMITS
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    caplog.clear()
    text = 'private fixture text'
    event = phone.event(text, mid='private-fixture-id')
    if failure == 'journal':
        with patch.object(gate.journal, 'append', side_effect=HejoJournalError(text)):
            await phone.handle_message(event)
    elif failure == 'unexpected':
        with patch.object(gate, 'receive', side_effect=RuntimeError(text + event.message_id)):
            await phone.handle_message(event)
        assert [r.getMessage() for r in caplog.records] == ['imessage_receive_failed']
    else:
        await phone.handle_message(phone.event('a' * (LIMITS['text_bytes'] + 1)))
    assert gate.journal.head == 0 and not runner.events and not phone.originals
    assert phone.calls == [('chat-A', '지금은 받지 못했어요', None)]
    await phone.handle_message(phone.event('next', mid='im-next'))
    assert (await client.until(ws, 'message'))[-1]['text'] == 'next'
    await wait_for_turns(runner, 1)


@pytest.mark.parametrize('outer', ['hejo', 'reception'])
async def test_at_hi_43_retained_code_never_enters_active_room(gate, runner, client, phone, outer):
    phone.handle_message = Phone.handle_message.__get__(phone)
    phone._hejo_imessage_wrapped = False
    classifications = []
    def reception():
        original = phone.handle_message
        async def handle(event):
            if not gate.claims_external(event):
                classifications.append(event)
            return await original(event)
        phone.handle_message = handle
    if outer == 'hejo': reception()
    imessage.attach_photon(None, phone)
    if outer == 'reception': reception()
    ws, _ = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    code = await pair_phone(client, ws, phone)
    for case in ['used', 'expired', 'denied']:
        if case != 'used':
            code = await request(client, ws, 'imessage_pair')
        if case == 'expired': gate.imessage.clock = lambda: 10**12
        if case == 'denied': phone.set_authorization_check(lambda *args: False)
        before = gate.imessage.private()['pair']
        event = phone.event(code['code'], mid='im-' + case)
        await phone.handle_message(event)
        assert phone.originals[-1] is event and classifications[-1] is event
        assert len(phone.originals) == len(classifications) == ['used', 'expired', 'denied'].index(case) + 1
        assert gate.journal.head == 0 and not runner.events and not phone.calls
        assert gate.imessage.private()['pair'] == before
        await ws.send_json({'v': 1, 'type': 'roster', 'id': 'boundary'})
        assert (await client.read(ws))['type'] == 'roster'
    phone.set_authorization_check(lambda *args: True)
    await phone.handle_message(phone.event('hi', mid='im-normal'))
    row = (await client.until(ws, 'message'))[-1]
    assert row['text'] == 'hi' and row['employee'] == 'alpha'
    await wait_for_turns(runner, 1)


@pytest.mark.parametrize('file', ['sent.jsonl', 'settings.json', 'imessage.json'])
async def test_at_hi_44_corrupt_connection_files_preserve_app(gate, runner, client, phone, settle, file):
    from gate.adapter import _delivery_scope
    ws, welcome = await client.pair(features=['imessage'])
    await activate(client, ws, phone)
    originals = []
    if file == 'sent.jsonl':
        for n in range(2):
            await phone.handle_message(phone.event('seed', mid=f'im-seed-{n}'))
            originals.append((await client.until(ws, 'message'))[-1])
            await wait_for_turns(runner, n + 1)
        path = gate.imessage.sent_path
        raw = (json.dumps({'im': 'im-out-A', 'msg_id': originals[0]['msg_id']}) + '\n' +
               'broken fixture row\n' + json.dumps({'im': 'im-out-B', 'msg_id': originals[1]['msg_id']}) + '\n').encode()
    else:
        path = (gate.imessage.vault.path if file == 'imessage.json' else gate.imessage.settings_store.path) / file
        raw = b'{broken fixture'
    path.write_bytes(raw)
    await ws.close()
    await gate.disconnect()
    assert await gate.connect()
    # Keep the real adapter and the same substituted turn handler across reconnect.
    gate.set_message_handler(runner.handle)
    gate.imessage.settle_seconds = 0.05
    ws, _ = await client.open(token=welcome['token'], features=['imessage'])
    if file == 'sent.jsonl':
        assert path.read_bytes() == raw
        for n, im_id in enumerate(['im-out-A', 'im-out-B']):
            await phone.handle_message(phone.event('reply', mid=f'im-reply-{n}', reply_to_message_id=im_id))
            assert (await client.until(ws, 'message'))[-1]['thread'] == originals[n]['thread']
        await wait_for_turns(runner, 4)
    else:
        head = gate.journal.head
        event = phone.event('pass through')
        await phone.handle_message(event)
        assert phone.originals == [event] and gate.journal.head == head and not phone.calls
    await client.send(ws, text='app input')
    owner = (await client.until(ws, 'message'))[-1]
    await wait_for_turns(runner, 5 if file == 'sent.jsonl' else 1)
    result = await gate.send('alpha', 'app answer', metadata={'thread_id': owner['thread']})
    assert result.success
    assert (await client.until(ws, 'message'))[-1]['text'] == 'app answer'
    token = _delivery_scope.set(('alpha', 'alpha', owner['thread']))
    try:
        await gate.stop_typing('alpha')
    finally:
        _delivery_scope.reset(token)
    await settle()
    if file != 'sent.jsonl': assert not phone.calls
