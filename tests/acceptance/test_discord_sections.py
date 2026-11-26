"""AT-DK acceptance cases against the real wire, routing, and journal."""
import asyncio
import importlib.util
import json
from pathlib import Path
import re
import stat
import subprocess
from types import SimpleNamespace
import uuid

import pytest
import pytest_asyncio

from test_discord import (
    Channel, Guild, activate, client, discord_module, drain, gate, group, named_roster,
    pair, registered, request, settled, transport, until,
)

pytestmark = pytest.mark.asyncio
BASE = 'c22e6774604398f84351d69dd926ba3510d31aa2'


class RateLimited(Exception):
    def __init__(self, retry_after):
        self.retry_after = retry_after


class HTTPException(Exception):
    def __init__(self, status, retry_after=None):
        self.status = status

        async def json_body():
            return {'retry_after': retry_after}

        self.response = SimpleNamespace(json=json_body)


class Example:
    def __init__(self, native, gate, client, ws):
        self.native, self.gate, self.client, self.ws = native, gate, client, ws
        self.attempts, self.rejects, self.failures = [], [], {}
        self.max_children = 0
        self.dir = gate.discord.settings_store.path
        self.g = None

    @property
    def guild(self):
        return self.native.guilds['gld-A']

    @property
    def tag(self):
        return self.gate.discord.private()['pair']['tag']

    @property
    def entries(self):
        return self.gate.discord.channels(self.tag)

    def category(self, name):
        return next(c for c in self.guild.channels.values() if isinstance(c, Category) and c.name == name)

    def room(self, room):
        return self.guild.channels[self.entries['channels'][room]['channel']]

    def names(self, category):
        return [c.name for c in sorted(self.category(category).channels, key=lambda c: c.position)]

    def call(self, guild, kind, target, value=None):
        self.attempts.append((guild.id, kind, target, value))
        failures = self.failures.get(kind, [])
        if failures:
            raise failures.pop(0)

    def count(self, category):
        self.max_children = max(self.max_children, len(category.channels))
        if len(category.channels) >= 50:
            self.rejects.append(category.id)
            raise HTTPException(400)

    @property
    def layout(self):
        return {'sections': [{'id': '1', 'name': 'Work', 'rooms': [self.g]},
                             {'id': '2', 'name': 'Ops', 'rooms': ['beta']}],
                'stack': {'name': 'DM', 'rooms': ['alpha', 'default']}}

    async def command(self, kind='discord', **fields):
        return await request(self.client, self.ws, kind, **fields)

    async def report(self, layout=None, ref='l1', ws=None, wait=True):
        ws = self.ws if ws is None else ws
        await ws.send_json({'v': 1, 'type': 'discord_layout', 'id': ref,
                            **(self.layout if layout is None else layout)})
        while True:
            reply = await self.client.read(ws)
            if reply.get('ref') == ref:
                break
        if wait:
            await self.synced()
        return reply

    async def synced(self):
        bridge = self.gate.discord
        await until(lambda: not bridge._channel_lock.locked() and not bridge._sync_requested.is_set())

    async def activate(self):
        self.g, _ = await activate(self.gate, self.client, self.ws, self.native)
        await self.synced()

    def external(self, category, *identifiers):
        for identifier in identifiers:
            category.guild.add(Forum, identifier, identifier, category)

    def written(self, name):
        return (self.dir / name).read_bytes()

    def l1_parents(self):
        return {room: self.room(room).category.name for room in [self.g, 'beta', 'alpha', 'default']}

    async def archive(self, room, archived=True):
        await self.gate.room_command({'type': 'room_archive', 'id': room, 'archived': archived}, Sink())
        await self.synced()


class Sink:
    features = {'rooms'}

    async def send(self, frame):
        pass


class Positioned(Channel):
    def __init__(self, guild, identifier, name, category, position):
        super().__init__(guild.native, identifier, name, category=category)
        self.guild, self.position = guild, position

    async def edit(self, **fields):
        category = fields.get('category')
        kind = 'move' if category else 'rename'
        self.guild.example.call(self.guild, kind, self.id, category.name if category else fields.get('name'))
        if category and category is not self.category:
            self.guild.example.count(category)
        await super().edit(**fields)
        if category:
            self.guild.example.max_children = max(self.guild.example.max_children, len(category.channels))
        return self


class Category(Positioned):
    @property
    def channels(self):
        return [channel for channel in self.guild.channels.values() if channel.category is self]

    async def delete(self):
        assert not self.channels
        self.guild.example.call(self.guild, 'delete', self.id)
        del self.guild.channels[self.id]


class Forum(Positioned):
    pass


class Server(Guild):
    def __init__(self, example, identifier):
        super().__init__(example.native, identifier)
        self.example = example
        self.next_position = 0
        self.categories_created = 0

    def add(self, cls, identifier, name, category=None):
        self.next_position += 1
        channel = cls(self, identifier, name, category, self.next_position)
        self.channels[identifier] = channel
        return channel

    async def create_category(self, name, position=None):
        self.example.call(self, 'category', name)
        self.categories_created += 1
        return self.add(Category, f'cat-{self.id[-1]}-{self.categories_created}', name)

    async def create_forum(self, *, name, category):
        self.example.call(self, 'forum', name, category.name)
        self.example.count(category)
        self.native.channels += 1
        channel = self.add(Forum, f'ch-{self.native.channels}', name, category)
        self.example.max_children = max(self.example.max_children, len(category.channels))
        return channel

    async def bulk(self, payload):
        for update in payload:
            self.example.call(self, 'position', update['id'], update['position'])
            self.channels[update['id']].position = update['position']


@pytest_asyncio.fixture
async def example(gate, client, transport, discord_module, caplog):
    _, native = transport
    ws, _ = await client.pair(features=['discord'])
    example = Example(native, gate, client, ws)
    native.guilds = {key: Server(example, key) for key in native.guilds}

    async def bulk(guild_id, payload):
        await native.guilds[guild_id].bulk(payload)

    native.http.bulk_channel_update = bulk
    discord_module.RateLimited = RateLimited
    discord_module.HTTPException = HTTPException

    async def immediate(seconds):
        pass

    gate.discord.rate_limit_sleep = immediate
    yield example
    for phase in ('setup', 'call', 'teardown'):
        for record in caplog.get_records(phase):
            if record.name.endswith('.discord'):
                assert not re.search(r'gld-|cat-|ch-|Work|Ops|Team', record.getMessage())
                if example.tag:
                    assert example.tag not in record.getMessage()


async def configured(example):
    await example.activate()
    example.attempts.clear()
    return await example.report()


def operations(example, kind):
    return [row[2:] for row in example.attempts if row[1] == kind]


def check_l1(example):
    assert example.l1_parents() == {example.g: 'Work', 'beta': 'Ops', 'alpha': 'DM', 'default': 'DM'}
    assert example.entries['category'] is None
    assert set(example.entries['sections']) == {'1', '2', '~stack'}
    assert not example.gate.discord.channel_problem


async def test_at_dk_01_layout(example):
    reply = await configured(example)
    assert reply['type'] == 'discord_status' and reply['ref'] == 'l1'
    assert json.loads(example.written('layout.json')) == example.layout
    assert stat.S_IMODE((example.dir / 'layout.json').stat().st_mode) == 0o600
    assert operations(example, 'category') == [('Work', None), ('Ops', None), ('DM', None)]
    assert not operations(example, 'forum')
    assert operations(example, 'delete') == [('cat-A-1', None)]
    assert not [f for f in await drain(example.client, example.ws) if f.get('ref') == 'l1']
    check_l1(example)


async def test_at_dk_02_rename(example):
    await configured(example)
    layout = example.layout
    old = example.category('Work').id
    layout['sections'][0]['name'] = 'Projects'
    example.attempts.clear()
    await example.report(layout)
    assert example.category('Projects').id == old
    assert operations(example, 'rename') == [(old, 'Projects')]
    assert not any(operations(example, key) for key in ['category', 'move', 'delete'])


async def test_at_dk_03_move_keeps_empty_section(example):
    await configured(example)
    layout = example.layout
    layout['sections'][1]['rooms'] += layout['sections'][0]['rooms']
    layout['sections'][0]['rooms'] = []
    example.attempts.clear()
    await example.report(layout)
    assert operations(example, 'move') == [(example.room(example.g).id, 'Ops')]
    assert not operations(example, 'delete') and not operations(example, 'category')
    assert example.names('Work') == [] and '1' in example.entries['sections']


def deleted_section(example):
    layout = example.layout
    layout['sections'][0]['rooms'] += layout['sections'].pop()['rooms']
    return layout


async def test_at_dk_04_remove_section(example):
    await configured(example)
    old = example.category('Ops').id
    example.attempts.clear()
    await example.report(deleted_section(example))
    assert operations(example, 'move') == [(example.room('beta').id, 'Work')]
    assert operations(example, 'delete') == [(old, None)]
    assert set(example.entries['sections']) == {'1', '~stack'}


async def test_at_dk_05_pin(example):
    await configured(example)
    layout = example.layout
    layout['sections'][0]['rooms'].append(layout['stack']['rooms'].pop(0))
    example.attempts.clear()
    await example.report(layout)
    assert operations(example, 'move') == [(example.room('alpha').id, 'Work')]
    assert example.names('DM') == ['Main']


async def test_at_dk_06_duplicate_report(example):
    await configured(example)
    before = example.written('layout.json')
    path = example.dir / 'layout.json'
    timestamp = path.stat().st_mtime_ns
    example.attempts.clear()
    reply = await example.report(ref='l2')
    assert reply['type'] == 'discord_status' and reply['ref'] == 'l2'
    assert not [f for f in await drain(example.client, example.ws) if f.get('ref') == 'l2']
    assert path.stat().st_mtime_ns == timestamp and path.read_bytes() == before
    assert not example.attempts


async def test_at_dk_07_no_layout(example):
    await example.activate()
    assert [c.name for c in example.guild.channels.values() if isinstance(c, Category)] == ['hejo']
    assert set(example.names('hejo')) == {'Main', 'Alpha', 'Beta', 'Team'}
    assert not (example.dir / 'layout.json').exists()
    assert not example.entries.get('sections')


async def test_at_dk_08_unreported_room(example):
    await configured(example)
    example.attempts.clear()
    new = await group(example.gate, 'Zed')
    await example.synced()
    assert operations(example, 'category') == [('hejo', None)]
    assert example.room(new).category.name == 'hejo'
    old = example.category('hejo').id
    layout = example.layout
    layout['sections'][0]['rooms'].append(new)
    await example.report(layout)
    assert example.room(new).category.name == 'Work'
    assert operations(example, 'delete') == [(old, None)] and example.entries['category'] is None


async def test_at_dk_09_archive_roundtrip(example):
    await configured(example)
    old = example.category('Work').id
    example.attempts.clear()
    await example.archive(example.g)
    assert operations(example, 'category') == [('hejo 보관', None)]
    assert operations(example, 'move') == [(example.room(example.g).id, 'hejo 보관')]
    assert example.names('Work') == [] and not operations(example, 'delete')
    example.attempts.clear()
    await example.archive(example.g, False)
    assert example.room(example.g).category.id == old
    assert example.names('hejo 보관') == []
    assert not operations(example, 'category') and not operations(example, 'delete')


async def test_at_dk_10_external_children(example):
    mine = example.guild.add(Category, 'cat-x', 'Mine')
    example.external(mine, 'txt-9')
    await configured(example)
    assert not any(row[2] in {'cat-x', 'txt-9'} for row in example.attempts)
    ops = example.category('Ops')
    example.external(ops, 'txt-8')
    example.attempts.clear()
    await example.report(deleted_section(example))
    assert example.entries['sections']['2']['category'] == ops.id
    assert not any(target in {'cat-x', 'txt-9', 'txt-8', ops.id}
                   for _, kind, target, _ in example.attempts if kind != 'move')


async def employee_send(example, room='alpha'):
    metadata = {'thread_id': str(uuid.uuid4())}
    if room != 'alpha':
        metadata.update(hermes_profile='alpha')
        room = 'room:' + room
    assert (await example.gate.send(room, 'fixture text', metadata=metadata)).success


async def test_at_dk_11_category_positions(example):
    await configured(example)

    def ordered():
        categories = [c for c in example.guild.channels.values() if isinstance(c, Category)]
        return [c.name for c in sorted(categories, key=lambda c: c.position)]

    assert ordered() == ['Work', 'Ops', 'DM']
    layout = example.layout
    layout['sections'].reverse()
    await example.report(layout)
    assert ordered() == ['Ops', 'Work', 'DM']
    example.attempts.clear()
    await example.report(layout)
    assert not operations(example, 'position')
    await employee_send(example)
    await settled(example.gate)
    assert example.native.calls and not operations(example, 'position')


def roster(example, monkeypatch, names, *, extra=False):
    before = example.gate.employees()
    monkeypatch.setattr(example.gate, 'employees', lambda: [
        *(before if extra else []),
        *({'id': name, 'name': name, 'aliases': []} for name in names),
    ])


async def test_at_dk_12_name_order(example, monkeypatch):
    await configured(example)
    assert example.names('DM') == ['Alpha', 'Main']
    before = example.gate.employees()
    monkeypatch.setattr(example.gate, 'employees', lambda: [
        {**e, 'name': 'Zulu'} if e['id'] == 'alpha' else e for e in before
    ])
    await example.command()
    await example.synced()
    assert example.names('DM') == ['Main', 'Zulu']
    example.attempts.clear()
    await example.command()
    await example.synced()
    assert not operations(example, 'position')


@pytest.mark.parametrize('has_external', [False, True])
async def test_at_dk_13_capacity(example, monkeypatch, has_external):
    await configured(example)
    names = [f'E{i:02d}' for i in range(1, 49 if has_external else 53)]
    roster(example, monkeypatch, names, extra=has_external)
    if has_external:
        example.external(example.category('DM'), 'txt-7')
        layout = example.layout
        layout['stack']['rooms'] += names
        expected_dm = {'Alpha', 'txt-7', *names}
        expected_default = {'Main'}
    else:
        layout = example.layout
        layout['sections'][0]['rooms'] = []
        layout['sections'][1]['rooms'] = []
        layout['stack']['rooms'] = names
        expected_dm = set(names[:50])
        expected_default = {'E51', 'E52', 'Team'}
    example.attempts.clear()
    await example.report(layout)
    assert set(example.names('DM')) == expected_dm
    assert set(example.names('hejo')) == expected_default
    assert not example.rejects and example.gate.discord.channel_problem
    assert not any(row[2] == 'txt-7' for row in example.attempts)


async def test_at_dk_14_bad_reports(example):
    await configured(example)
    other, _ = await example.client.pair(features=['rooms'])
    await drain(example.client, other)
    await drain(example.client, example.ws)
    baseline = example.written('layout.json')
    example.attempts.clear()
    assert (await example.report(ws=other))['code'] == 'unexpected_frame'
    broken = example.layout
    del broken['stack']
    assert (await example.report(broken))['code'] == 'invalid_frame'
    for change in ('room', 'reserved', 'duplicate', 'total'):
        layout = example.layout
        if change == 'room':
            layout['sections'][1]['rooms'].append(example.g)
        elif change == 'total':
            layout['stack']['rooms'] = [f'fixture-{index}' for index in range(2000)]
        else:
            layout['sections'][0]['id'] = '~stack' if change == 'reserved' else '2'
        assert (await example.report(layout))['code'] == 'bad_layout'
    assert not await drain(example.client, example.ws)
    assert not await drain(example.client, other)
    assert example.written('layout.json') == baseline and not example.attempts


async def test_at_dk_15_keeps_layout_across_pairing(example):
    await configured(example)
    before = example.written('layout.json')
    tag = example.tag
    await example.command('discord_unpair')
    await pair(example.gate, example.client, example.ws, example.native)
    example.attempts.clear()
    await example.command('discord_save', enabled=True)
    await example.synced()
    assert example.tag != tag and example.written('layout.json') == before
    assert len(operations(example, 'forum')) == 4
    assert operations(example, 'category') == [('Work', None), ('Ops', None), ('DM', None)]
    check_l1(example)


class Waits:
    def __init__(self, hold=lambda _: False):
        self.hold = hold
        self.calls = []
        self.entered, self.release = asyncio.Event(), asyncio.Event()

    async def __call__(self, seconds):
        self.calls.append(seconds)
        if self.hold(seconds):
            self.entered.set()
            await self.release.wait()

    async def entered_wait(self):
        await asyncio.wait_for(self.entered.wait(), 4)


@pytest.mark.parametrize('error, delays, attempts', [
    (lambda: RateLimited(.25), [.25, .25], 3),
    (lambda: HTTPException(429, .5), [.5], 2),
])
async def test_at_dk_16_17_rate_limits(example, error, delays, attempts):
    await example.activate()
    example.attempts.clear()
    waits = Waits()
    example.gate.discord.rate_limit_sleep = waits
    example.failures['category'] = [error() for _ in delays]
    await example.report()
    assert waits.calls == delays
    assert operations(example, 'category').count(('Work', None)) == attempts
    check_l1(example)


@pytest.mark.parametrize('delay, reserved_delay', [(.25, 60), (90, 90)])
async def test_at_dk_18_reservation(example, delay, reserved_delay):
    await example.activate()
    bridge = example.gate.discord
    waits = Waits()
    # The first two waits precede attempts two and three. Observe the
    # reservation separately even when all three durations are equal.
    waits.hold = lambda _: len(waits.calls) > 2
    bridge.rate_limit_sleep = waits
    example.attempts.clear()
    example.failures['move'] = [RateLimited(delay) for _ in range(3)]
    await example.report()
    await waits.entered_wait()
    assert waits.calls == [delay, delay, reserved_delay]
    assert len(set(operations(example, 'move'))) == 1
    assert len(operations(example, 'move')) == 3 and example.attempts[-1][1] == 'move'
    status = await drain(example.client, example.ws)
    assert any(f.get('channel_problem') is True for f in status)
    reservation = bridge._retry_task
    # Another failure while it is pending cannot schedule a second timer.
    waits.hold = lambda _: False
    example.failures['move'] = [RateLimited(delay) for _ in range(3)]
    await bridge.sync_channels()
    assert bridge._retry_task is reservation and len(waits.calls) == 5
    if delay < 60:
        waits.release.set()
        await until(lambda: not bridge.channel_problem)
        await example.synced()
        check_l1(example)
    else:
        await bridge.close()
        assert reservation.cancelled()


async def blocked_rename(example):
    waits = Waits(lambda _: True)
    example.gate.discord.rate_limit_sleep = waits
    example.failures['rename'] = [RateLimited(.5)]
    layout = example.layout
    layout['sections'][0]['name'] = 'Projects'
    await example.report(layout, wait=False)
    await waits.entered_wait()
    return waits


async def test_at_dk_19_existing_channel_keeps_sending(example):
    await configured(example)
    waits = await blocked_rename(example)
    await employee_send(example)
    await until(lambda: len(example.native.calls) == 1)
    assert example.category('Work') and example.gate.discord._channel_lock.locked()
    waits.release.set()
    await example.synced()
    assert example.category('Projects') and not example.gate.discord.channel_problem


async def test_at_dk_20_other_failures_continue(example):
    await example.activate()
    example.attempts.clear()
    example.failures['move'] = [OSError('gld-A ch-sensitive')]
    await example.report()
    moves = operations(example, 'move')
    assert len(set(channel for channel, _ in moves)) == len(moves) == 4
    assert sum(parent != 'hejo' for parent in example.l1_parents().values()) == 3
    assert example.gate.discord.channel_problem and example.gate.discord._retry_task is None


async def test_at_dk_22_additive_schema():
    root = Path(__file__).resolve().parents[2]
    candidates = (BASE, 'adf54d76c967707078f19c7dab09d8a50f44d489')
    baseline = next((commit for commit in candidates if subprocess.run(
        ['git', 'merge-base', '--is-ancestor', commit, 'HEAD'], cwd=root).returncode == 0), None)
    assert baseline is not None, 'expected a public or operational schema baseline'
    path = 'schemas/hejo-wire-v1.json'
    old = json.loads(subprocess.check_output(['git', 'show', f'{baseline}:{path}'], cwd=root))
    new = json.loads((root / path).read_bytes())
    assert new['$defs'].pop('discord_layout')['properties']['type'] == {'const': 'discord_layout'}
    for union in (new, new['$defs']['clientFrame']):
        assert union['oneOf'].pop() == {'$ref': '#/$defs/discord_layout'}
    assert old == new
    path = 'tests/acceptance/test_discord.py'
    assert (root / path).read_bytes() == subprocess.check_output(['git', 'show', f'{baseline}:{path}'], cwd=root)


@pytest.mark.parametrize('full_staging', [False, True])
async def test_at_dk_24_25_full_categories_swap(example, monkeypatch, full_staging):
    a, b = ([f'{prefix}{i:02d}' for i in range(1, 50)] for prefix in 'AB')
    await pair(example.gate, example.client, example.ws, example.native)
    h = await group(example.gate, 'Zed') if full_staging else None
    roster(example, monkeypatch, a + b)
    layout = {'sections': [{'id': '1', 'name': 'X', 'rooms': a},
                           {'id': '2', 'name': 'Y', 'rooms': b}],
              'stack': {'name': 'DM', 'rooms': []}}
    await example.report(layout)
    await example.command('discord_save', enabled=True)
    await example.synced()
    example.external(example.category('X'), 'txt-5')
    example.external(example.category('Y'), 'txt-6')
    if full_staging:
        assert example.room(h).category.name == 'hejo'
        example.external(example.category('hejo'), *(f'txt-fixture-{i}' for i in range(49)))
    a[-1], b[-1] = b[-1], a[-1]
    example.attempts.clear()
    await example.report(layout)
    assert not example.rejects and example.max_children <= 50
    assert all(len(example.category(name).channels) == 50 for name in 'XY')
    assert not any(row[2] in {'txt-5', 'txt-6'} for row in example.attempts)
    if full_staging:
        assert not operations(example, 'move')
        assert example.room('A49').category.name == 'X' and example.room('B49').category.name == 'Y'
        assert example.gate.discord.channel_problem and example.gate.discord._retry_task is None
    else:
        assert example.room('A49').category.name == 'Y' and example.room('B49').category.name == 'X'
        assert len(operations(example, 'move')) == 3
        assert example.entries['category'] is None and not example.gate.discord.channel_problem


async def test_at_dk_26_default_capacity(example):
    await example.activate()
    example.external(example.category('hejo'), *(f'txt-fixture-{i}' for i in range(46)))
    example.attempts.clear()
    new = await group(example.gate, 'Zed')
    await example.synced()
    assert new not in example.entries['channels']
    assert not example.attempts and not example.rejects
    assert example.gate.discord.channel_problem


async def test_at_dk_27_previous_release(example, tmp_path, monkeypatch):
    await configured(example)
    original = example.gate.discord
    home = original.vault.path.parent
    await original.close()
    source = tmp_path / 'discord_baseline.py'
    root = Path(__file__).resolve().parents[2]
    source.write_bytes(subprocess.check_output(['git', 'show', f'{BASE}:gate/discord.py'], cwd=root))
    spec = importlib.util.spec_from_file_location('gate.discord_baseline', source)
    baseline = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(baseline)
    from gate import discord
    monkeypatch.setattr(baseline, '_bot', discord._bot)
    monkeypatch.setattr(baseline, '_discord', discord._discord)
    example.attempts.clear()
    example.gate.discord = baseline.Discord(example.gate, home)
    new = await group(example.gate, 'Zed')
    await example.synced()
    assert operations(example, 'category') == [('hejo', None)]
    assert operations(example, 'forum') == [('Zed', 'hejo')]
    assert not operations(example, 'move')
    assert example.room(new).category.name == 'hejo'
    assert not example.gate.discord.channel_problem


async def test_at_dk_28_new_channel_waits(example):
    await configured(example)
    waits = await blocked_rename(example)
    new = await group(example.gate, 'Zed')
    await employee_send(example, new)
    await asyncio.sleep(.1)
    assert example.gate.discord.workers and not example.native.calls
    waits.release.set()
    await settled(example.gate)
    assert len(example.native.calls) == 1
    assert example.native.calls[0][0] == example.room(new).id


@pytest.mark.parametrize('change', ['unpair', 'new-pair', 'disable'])
async def test_at_dk_29_superseded_pairing(example, change):
    await configured(example)
    before_tag = example.tag
    if change == 'disable':
        waits = Waits(lambda _: True)
        example.gate.discord.rate_limit_sleep = waits
        example.failures['move'] = [RateLimited(.5)]
        layout = example.layout
        layout['sections'][1]['rooms'] += layout['sections'][0]['rooms']
        layout['sections'][0]['rooms'] = []
        await example.report(layout, wait=False)
        await waits.entered_wait()
    else:
        waits = await blocked_rename(example)
    before = example.written('channels.json')
    example.attempts.clear()
    if change == 'disable':
        await example.command('discord_save', enabled=False)
    else:
        await example.command('discord_unpair')
        if change == 'new-pair':
            await pair(example.gate, example.client, example.ws, example.native, guild='gld-B', user='usr-B')
            await example.command('discord_save', enabled=True)
    waits.release.set()
    await example.synced()
    assert not any(row[0] == 'gld-A' for row in example.attempts)
    assert waits.calls == [.5] and example.gate.discord._retry_task is None
    if change == 'new-pair':
        assert example.tag != before_tag
        assert example.entries['tag'] == example.tag
        assert operations(example, 'category') == [('Projects', None), ('Ops', None), ('DM', None)]
        assert set(operations(example, 'forum')) == {
            ('Team', 'Projects'), ('Beta', 'Ops'), ('Alpha', 'DM'), ('Main', 'DM')}
        assert not example.gate.discord.channel_problem
    else:
        assert example.written('channels.json') == before


async def test_at_dk_30_full_archive(example, monkeypatch):
    await configured(example)
    before = [e for e in example.gate.employees() if e['id'] != 'beta']
    monkeypatch.setattr(example.gate, 'employees', lambda: before)
    await example.command()
    await example.synced()
    archive = example.category('hejo 보관')
    example.external(archive, *(f'txt-fixture-{i}' for i in range(49)))
    recorded = example.written('channels.json')
    example.attempts.clear()
    await example.archive(example.g)
    await employee_send(example, example.g)
    await settled(example.gate)
    assert example.room(example.g).category.name == 'Work'
    assert not example.entries['channels'][example.g]['closed']
    assert example.written('channels.json') == recorded
    assert not example.attempts and not example.native.calls and not example.rejects
    assert example.gate.discord.channel_problem
    del example.guild.channels['txt-fixture-0']
    await example.command()
    await example.synced()
    assert operations(example, 'move') == [(example.room(example.g).id, 'hejo 보관')]
    assert example.entries['channels'][example.g]['closed']
    assert example.names('Work') == [] and not example.gate.discord.channel_problem


async def test_new_pair_replaces_stale_reservation(example):
    await example.activate()
    bridge = example.gate.discord
    waits = Waits(lambda delay: delay >= 60)
    bridge.rate_limit_sleep = waits
    example.failures['move'] = [RateLimited(.25)] * 3
    await example.report()
    await waits.entered_wait()
    old_retry = bridge._retry_task

    await example.command('discord_unpair')
    await pair(example.gate, example.client, example.ws, example.native, guild='gld-B', user='usr-B')
    example.failures['forum'] = [RateLimited(.5)] * 3
    waits.entered.clear()
    await example.command('discord_save', enabled=True)
    await waits.entered_wait()
    assert old_retry.cancelled()
    assert waits.calls == [.25, .25, 60, .5, .5, 60]

    waits.release.set()
    await until(lambda: not bridge.channel_problem)
    await example.synced()
    assert len(example.entries['channels']) == 4
