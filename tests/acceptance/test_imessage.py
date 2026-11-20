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
    ws, _ = await client.pair(features=['imessage', 'rooms'])
    await activate(client, ws, phone, room=G, reports=[G, 'alpha'])
    await ws.send_json({'v': 1, 'type': kind, 'id': G, **({'archived': True} if kind == 'room_archive' else {})})
    await client.read(ws)
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
    before = gate.imessage.private()
    assert gate.claims_external(phone.event(code['code']))
    assert not gate.claims_external(phone.event('wrong'))
    assert gate.imessage.private() == before


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
