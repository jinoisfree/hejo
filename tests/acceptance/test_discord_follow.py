"""HEJO-DISCORD-FOLLOW acceptance against the gate and isolated Discord objects."""
import asyncio
import json
import logging
from pathlib import Path
from types import SimpleNamespace
import uuid

import pytest
import pytest_asyncio

from gate import discord as door

from test_discord import (
    Channel, Hook, NotFound, activate, client, discord_module, gate, group, named_roster,
    registered, settled, transport, until,
)

pytestmark = pytest.mark.asyncio


async def test_at_df_03_edits_before_send_are_settled(gate, client, transport):
    _, native = transport
    ws, _ = await client.pair(features=['discord'])
    await activate(gate, client, ws, native)
    meta = {'thread_id': str(uuid.uuid4())}
    result = await gate.send('alpha', 'first', metadata=meta)
    for text in ('second', 'last'):
        assert (await gate.edit_message('alpha', result.message_id, text, finalize=True, metadata=meta)).success
    await settled(gate)
    assert [fields['content'] for _, fields in native.calls] == ['last']
    assert not any(call[0] == 'edit_message' for call in native.operations)


async def test_at_df_09_forum_default_archive_duration(gate, client, transport):
    _, native = transport
    ws, _ = await client.pair(features=['discord'])
    _, entries = await activate(gate, client, ws, native)
    guild = native.guilds['gld-A']
    old = guild.channels[entries['alpha']['channel']]
    old.default_auto_archive_duration = 4320
    native.operations.clear()
    room = await group(gate, 'Archive fixture')
    await gate.discord.sync_channels()
    tag = gate.discord.private()['pair']['tag']
    new_id = gate.discord.channels(tag)['channels'][room]['channel']
    await gate.discord.sync_channels()
    changes = [(op[1], op[2]) for op in native.operations
               if op[0] == 'edit' and 'default_auto_archive_duration' in op[2]]
    assert len(changes) == 2
    assert dict(changes) == {
        old.id: {'default_auto_archive_duration': 1440},
        new_id: {'default_auto_archive_duration': 1440},
    }


async def test_at_df_20_discord_invite_instructions():
    settings = Path(__file__).resolve().parents[2] / 'app' / 'Sources' / 'SettingsPages.swift'
    lines = [line for line in settings.read_text().splitlines() if 'Message Content Intent' in line]
    assert len(lines) == 1
    assert lines[0].count('스레드 관리') == 1


class Forbidden(Exception):
    pass


class ForumPost:
    def __init__(self, lab, parent, identifier, title):
        self.lab, self.parent, self.id, self.name = lab, parent, identifier, title
        self.parent_id = parent.id
        self.guild = lab.native.guilds['gld-A']
        self.archived = False
        self.auto_archive_duration = 1440
        self.messages = {}
        self.readable, self.history_error = True, None
        self.edit_error, self.delete_error = None, None
        self.rename_delayed = False
        self.read_barrier = None
        self.history_barrier = None

    def message(self, identifier, text='', *, kind='default', attachments=()):
        value = SimpleNamespace(id=identifier, content=text, author=SimpleNamespace(display_name='Employee'),
                                attachments=attachments,
                                type=SimpleNamespace(name=kind) if isinstance(kind, str) else kind)
        self.messages[identifier] = value
        return value

    def permissions_for(self, member):
        return SimpleNamespace(read_message_history=self.readable)

    async def history(self, *, limit):
        assert limit is None
        if self.history_error:
            raise self.history_error
        if self.history_barrier:
            entered, release = self.history_barrier
            self.history_barrier = None
            entered.set()
            await release.wait()
        for message in list(self.messages.values()):
            yield message

    async def fetch_message(self, identifier):
        if self.read_barrier:
            entered, release = self.read_barrier
            self.read_barrier = None
            entered.set()
            await release.wait()
        return self.messages[str(identifier)] if str(identifier) in self.messages else missing()

    async def edit(self, **fields):
        if 'name' in fields and self.rename_delayed:
            self.rename_delayed = False
            raise door.SyncRateLimited(600)
        self.lab.writes.append(('post_edit', self.id, fields))
        for field, value in fields.items():
            setattr(self, field, value)
        return self

    async def delete(self):
        if self.delete_error:
            raise self.delete_error
        self.lab.writes.append(('post_delete', self.id))
        del self.lab.posts[self.id]


def missing():
    raise NotFound('fixture-message')


class FollowHook(Hook):
    def __init__(self, lab, channel):
        super().__init__(lab.native, channel)
        self.lab = lab

    async def _send(self, **fields):
        if 'thread' in fields:
            identifier = str(fields['thread'].id)
            if identifier not in self.lab.posts:
                raise NotFound('fixture-post')
        result = await super()._send(**fields)
        identifier = result.channel.id
        if 'thread_name' in fields:
            self.lab.make_post(self.channel, identifier, fields['thread_name'])
        post = self.lab.posts[identifier]
        if post.archived:
            post.archived = False
        content = fields.get('content', '')
        post.message(result.id, content, attachments=fields.get('files', ()))
        self.lab.writes.append(('send', identifier, content))
        return result

    async def edit_message(self, identifier, *, thread, content, allowed_mentions):
        post = self.lab.posts[str(thread.id)]
        assert not post.archived
        if post.edit_error:
            raise post.edit_error
        message = await post.fetch_message(identifier)
        self.lab.writes.append(('edit_message', post.id, str(identifier), content))
        message.content = content

    async def delete_message(self, identifier, *, thread):
        post = self.lab.posts[str(thread.id)]
        assert not post.archived
        await post.fetch_message(identifier)
        self.lab.writes.append(('delete_message', post.id, str(identifier)))
        del post.messages[str(identifier)]


class Lab:
    def __init__(self, gate, native):
        self.gate, self.native = gate, native
        self.native.guilds['gld-A'].me = native.user
        self.posts, self.writes = {}, []

    def make_post(self, channel, identifier, name):
        post = ForumPost(self, channel, identifier, name)
        self.posts[identifier] = post
        return post

    async def locate(self, identifier):
        return self.posts[str(identifier)] if str(identifier) in self.posts else missing()

    async def append(self, kind, mid, **fields):
        return await self.gate._record({'type': kind, 'msg_id': mid, **fields})

    async def employee(self, text='first', *, key=None, asked=False, files=(), room='alpha'):
        mid, key = str(uuid.uuid4()), key or str(uuid.uuid4())
        buttons = [{'label': label, 'kind': 'reply'} for label in ('승인', '거절')] if asked else []
        await self.gate._record(
            {'type': 'message', 'msg_id': mid, 'role': 'employee', 'employee': 'alpha',
             'thread': key, 'text': text, 'files': list(files), 'buttons': buttons,
             'reply_state': 'asked' if asked else None, **({'room': room} if room != 'alpha' else {})},
            {'files': self.gate.files.registration('alpha', 'employee', files)} if files else None,
        )
        return mid, key

    async def owner(self, key, *, post=None, text='답변', dc='fixture-owner'):
        mid = str(uuid.uuid4())
        if post:
            tag = self.gate.discord.private()['pair']['tag']
            post.message(dc, text)
            fields = {'client_msg_id': f'discord:{tag}:{post.parent_id}:{post.id}:{dc}'}
        else:
            fields = {}
        await self.append('message', mid, role='owner', employee='alpha',
                          thread=key, text=text, files=[], buttons=[], **fields)
        return mid

    def sent(self, mid):
        return [(row['post'], row['dc']) for row in self.gate.discord.sent if row['msg_id'] == mid]

    def post(self, mid):
        return self.posts[self.sent(mid)[0][0]]

    async def restart(self):
        old = self.gate.discord
        await old.close()
        self.gate.discord = door.Discord(self.gate, old.vault.path.parent)
        self.gate.discord.settle_seconds = .05
        await self.gate.discord.sync_channels()
        assert self.gate.discord._startup_task is not None
        await self.gate.discord._startup_task

    async def offline(self, kind, mid, **fields):
        return await self.gate.journal.append({'v': 1, 'type': kind, 'msg_id': mid, **fields})


@pytest_asyncio.fixture
async def lab(gate, client, transport, monkeypatch):
    _, native = transport
    value = Lab(gate, native)
    monkeypatch.setattr(native, 'fetch_channel', value.locate, raising=False)

    async def create(channel, name):
        hook = FollowHook(value, channel)
        channel.hooks.append(hook)
        return hook

    async def rename(_, post, title):
        if post.archived and not post.rename_delayed:
            fields = {'name': title, 'archived': False}
            post.lab.writes.append(('post_edit', post.id, fields))
            post.name = title
        else:
            await post.edit(name=title)

    monkeypatch.setattr(Channel, 'create_webhook', create)
    monkeypatch.setattr(door.Discord, 'rename_post', rename)
    ws, _ = await client.pair(features=['discord'])
    value.room, value.channels = await activate(gate, client, ws, native)
    await until(lambda: gate.discord._startup_task is not None)
    await gate.discord._startup_task
    return value


async def test_at_df_01_edit_title_then_archive(gate, lab):
    mid, _ = await lab.employee('🔴 A', asked=True)
    await settled(gate)
    post = lab.post(mid)
    _, dc = lab.sent(mid)[0]
    assert post.messages[dc].content.endswith('선택: 승인 / 거절')
    lab.writes.clear()
    await lab.append('edit', mid, text='✅ A', buttons=[])
    await lab.append('state', mid, reply_state='closed')
    await settled(gate)
    assert lab.writes == [('edit_message', post.id, dc, '✅ A'),
                          ('post_edit', post.id, {'name': '✅ A'}),
                          ('post_edit', post.id, {'archived': True})]
    assert lab.sent(mid) == [(post.id, dc)]


@pytest.mark.parametrize('by_owner', [False, True])
async def test_at_df_02_only_door_title_changes(gate, lab, by_owner):
    key = str(uuid.uuid4())
    if by_owner:
        channel = lab.native.guilds['gld-A'].get_channel(lab.channels['alpha']['channel'])
        post = lab.make_post(channel, 'fixture-owner-post', 'Owner title')
        await lab.owner(key, post=post)
    else:
        first, _ = await lab.employee(key=key)
        await settled(gate)
        post = lab.post(first)
    mid, _ = await lab.employee('reply', key=key)
    await settled(gate)
    lab.writes.clear()
    await lab.append('edit', mid, text='changed reply')
    await settled(gate)
    assert lab.writes == [('edit_message', post.id, lab.sent(mid)[0][1], 'changed reply')]


@pytest.mark.parametrize('mode', ['shrink', 'grow', 'file', 'same', 'shrink-restart', 'external-restart'])
async def test_at_df_04_current_body_chunks(gate, lab, tmp_path, mode, caplog):
    before = 'A' * (3000 if mode == 'shrink' else 100)
    after = 'B' * (4500 if mode == 'grow' else 100)
    if mode.endswith('restart'):
        before, after = 'A' * 2000 + 'B' * 1000, 'A' * 2000 + 'C' * 1000
    if mode == 'same':
        after = before
    files = []
    if mode == 'file':
        path = tmp_path / 'fixture.bin'
        path.write_bytes(b'fixture')
        staged = await gate.files.copy('alpha', path)
        files, _ = gate.files.promote('alpha', [staged['file_id']])
    mid, _ = await lab.employee(before, files=files)
    await settled(gate)
    post = lab.post(mid)
    sent = lab.sent(mid)
    if mode == 'shrink-restart':
        await lab.append('edit', mid, text='A' * 2000)
        await settled(gate)
    if mode == 'external-restart':
        del post.messages[sent[1][1]]
    if mode.endswith('restart'):
        await lab.restart()
    lab.writes.clear()
    caplog.clear()
    await lab.append('edit', mid, text=after)
    await settled(gate)
    content = [x for x in lab.writes if x[0] != 'post_edit']
    if mode == 'shrink':
        assert content == [('edit_message', post.id, sent[0][1], after),
                           ('delete_message', post.id, sent[1][1])]
    if mode == 'grow':
        assert content == [('edit_message', post.id, sent[0][1], 'B' * 2000),
                           ('send', post.id, 'B' * 2000), ('send', post.id, 'B' * 500)]
        assert len(lab.sent(mid)) == len(sent) + 2
    if mode == 'file':
        assert content == [('edit_message', post.id, sent[0][1], after)]
        assert post.messages[sent[1][1]].attachments
    if mode == 'same':
        assert lab.writes == []
    if mode.endswith('restart'):
        assert content == [('send', post.id, 'C' * 1000)]
        assert len(lab.sent(mid)) == len(sent) + 1
        assert not [r for r in caplog.records if r.name == 'gate.discord']


async def test_at_df_05_rate_retry_uses_latest_and_yields(gate, lab):
    mid, key = await lab.employee()
    await settled(gate)
    post = lab.post(mid)
    post.rename_delayed = True
    waiting, release = asyncio.Event(), asyncio.Event()

    async def sleep(delay):
        assert delay == 600
        waiting.set()
        await release.wait()

    gate.discord.rate_limit_sleep = sleep
    await lab.append('edit', mid, text='first changed')
    await asyncio.wait_for(waiting.wait(), 3)
    lab.writes.clear()
    await lab.employee('same lane', key=key)
    await lab.employee('other room', room=lab.room)
    await settled(gate)
    await lab.append('edit', mid, text='middle title')
    await settled(gate)
    await lab.append('edit', mid, text='last title')
    await settled(gate)
    assert [x[2] for x in lab.writes if x[0] == 'send'] == ['same lane', 'other room'] or         sorted(x[2] for x in lab.writes if x[0] == 'send') == ['other room', 'same lane']
    assert not any(x[0] == 'post_edit' for x in lab.writes)
    release.set()
    await until(lambda: not gate.discord._rename_tasks)
    assert [x for x in lab.writes if x[0] == 'post_edit'] == [('post_edit', post.id, {'name': 'last title'})]


@pytest.mark.parametrize('failure', ['missing', 'Forbidden', 'NotFound'])
async def test_at_df_06_missing_or_failed_body(gate, lab, failure, caplog):
    mid, _ = await lab.employee()
    await settled(gate)
    post = lab.post(mid)
    if failure == 'missing':
        post.messages.clear()
    else:
        post.edit_error = (Forbidden if failure == 'Forbidden' else NotFound)('fixture-private')
    lab.writes.clear()
    await lab.append('edit', mid, text='hidden text')
    await settled(gate)
    assert lab.writes == []
    assert [r.message for r in caplog.records if r.name == 'gate.discord'] == [
        'discord_update_failed kind=' + ('NotFound' if failure == 'missing' else failure)]
    next_mid, _ = await lab.employee('next')
    await settled(gate)
    assert lab.sent(next_mid)


async def test_at_df_07_and_08_assess_and_already_archived(gate, lab):
    mid, key = await lab.employee(asked=True)
    await settled(gate)
    post = lab.post(mid)
    assert not post.archived
    post.archived = True
    lab.writes.clear()
    await lab.append('state', mid, reply_state='asked')
    await settled(gate)
    assert post.archived and lab.writes == []
    post.archived = False
    await lab.owner(key)
    await lab.employee('done', key=key)
    await settled(gate)
    assert [x for x in lab.writes if x[0] == 'post_edit'] == [('post_edit', post.id, {'archived': True})]
    lab.writes.clear()
    await lab.append('state', mid, reply_state='closed')
    await settled(gate)
    assert lab.writes == []


@pytest.mark.parametrize('mode', ['edit', 'closed-edit', 'delete'])
async def test_at_df_10_temporarily_open_archive(gate, lab, mode):
    first, key = await lab.employee(asked=(mode == 'closed-edit'))
    await settled(gate)
    mid, _ = await lab.employee('second', key=key)
    if mode == 'closed-edit':
        await lab.append('state', first, reply_state='closed')
    await settled(gate)
    post = lab.post(first)
    post.archived = True
    lab.writes.clear()
    if mode == 'delete':
        await lab.append('delete', mid)
    else:
        await lab.append('edit', mid, text='changed')
    await settled(gate)
    action = 'delete_message' if mode == 'delete' else 'edit_message'
    assert [x[0] for x in lab.writes] == ['post_edit', action, 'post_edit']
    assert [lab.writes[i][2] for i in (0, 2)] == [{'archived': False}, {'archived': True}]
    assert post.archived


async def test_at_df_11_delete_uses_discord_message_ids(gate, lab, tmp_path):
    first, key = await lab.employee()
    await settled(gate)
    path = tmp_path / 'fixture.bin'
    path.write_bytes(b'fixture')
    staged = await gate.files.copy('alpha', path)
    files, _ = gate.files.promote('alpha', [staged['file_id']])
    second, _ = await lab.employee('A' * 3000, key=key, files=files)
    await settled(gate)
    post = lab.post(first)
    lab.writes.clear()
    await lab.append('delete', second)
    await settled(gate)
    assert len(lab.sent(second)) == 3
    assert lab.writes == [('delete_message', post.id, dc) for _, dc in lab.sent(second)]
    lab.writes.clear()
    await lab.append('delete', first)
    await settled(gate)
    assert lab.writes == [('post_delete', post.id)]


async def test_at_df_12_thread_delete_follows_all_records(gate, lab):
    mid, key = await lab.employee()
    other, _ = await lab.employee('another', key=key)
    await settled(gate)
    post = lab.post(mid)
    lab.writes.clear()
    await gate.thread_delete({'room': 'alpha', 'thread': key}, None)
    await settled(gate)
    assert lab.writes == [('post_delete', post.id)]
    assert gate.journal.message(other) is None

    channel = lab.native.guilds['gld-A'].get_channel(lab.channels['alpha']['channel'])
    post = lab.make_post(channel, 'fixture-owner-post', 'Owner title')
    key, next_key = str(uuid.uuid4()), str(uuid.uuid4())
    await lab.owner(key, post=post)
    removed, _ = await lab.employee('old reply', key=key)
    await settled(gate)
    reading, release = asyncio.Event(), asyncio.Event()
    post.history_barrier = reading, release
    lab.writes.clear()
    await gate.thread_delete({'room': 'alpha', 'thread': key}, None)
    await asyncio.wait_for(reading.wait(), 3)
    await lab.owner(next_key, post=post, dc='fixture-new-owner')
    release.set()
    await settled(gate)
    assert lab.writes == [('delete_message', post.id, lab.sent(removed)[0][1])]
    fresh, _ = await lab.employee('new reply', key=next_key)
    await settled(gate)
    assert gate.journal.message(fresh)
    assert lab.post(fresh) is post


async def test_at_df_13_room_other_pair_and_owner_are_preserved(gate, lab):
    mid, key = await lab.employee(room=lab.room)
    await settled(gate)
    post = lab.post(mid)
    pair_tag = gate.discord.private()['pair']['tag']
    gate.discord._save_sent('other-tag', post.parent_id, post.id, 'different-pair', mid)
    gate.discord._save_sent(pair_tag, post.parent_id, post.id, 'unknown', 'foreign-id')
    channel = lab.native.guilds['gld-A'].get_channel(lab.channels['alpha']['channel'])
    owner_post = lab.make_post(channel, 'fixture-owner-post', 'Owner title')
    other_key = str(uuid.uuid4())
    owner = await lab.owner(other_key, post=owner_post)
    await lab.employee('reply', key=other_key)
    await settled(gate)
    lab.writes.clear()
    await lab.append('delete', owner)
    await lab.append('delete', 'foreign-id')
    await gate._record({'type': 'room_delete', 'room': lab.room})
    await gate.discord.sync_channels()
    await settled(gate)
    assert not [x for x in lab.writes if x[0] in ('delete_message', 'post_delete')]
    assert ('edit', post.parent_id, {'category': post.parent.category}) in lab.native.operations
    assert post.parent.category.name == 'hejo 보관'


@pytest.mark.parametrize('kind,kept,failed', [
    ('recipient_add', 0, 0), ('unknown-live-door', 1, 0), ('read-error', 0, 1),
    ('thread_created', 1, 0), (99, 1, 0), ('known-system', 0, 0), ('no-history-permission', 0, 1),
])
async def test_at_df_13b_verify_entire_discord_history(gate, lab, caplog, kind, kept, failed):
    mid, key = await lab.employee()
    await settled(gate)
    post = lab.post(mid)
    if kind == 'read-error':
        post.history_error = Forbidden('fixture-private')
    elif kind == 'no-history-permission':
        post.readable = False
    elif kind == 'known-system':
        post.message('notice-rename', kind='channel_name_change')
        post.message('notice-pin', kind='pins_add')
    elif kind == 'unknown-live-door':
        other, _ = await lab.employee('unknown live', key=key)
        await settled(gate)
        assert lab.post(other) is post
        sent = gate.discord.sent_path
        rows = sent.read_text().splitlines()
        assert json.loads(rows[-1])['msg_id'] == other
        sent.write_text('\n'.join([*rows[:-1], '{bad']) + '\n')
    else:
        post.message('notice', kind=kind)
    await lab.offline('delete', mid)
    caplog.set_level(logging.INFO, logger='gate.discord')
    lab.writes.clear()
    await lab.restart()
    if failed:
        assert lab.writes == []
    elif kept:
        assert lab.writes == [('delete_message', post.id, lab.sent(mid)[0][1])]
    else:
        assert lab.writes == [('post_delete', post.id)]
    log = next(r.message for r in caplog.records if r.message.startswith('discord_reconcile'))
    assert f'kept_posts={kept} ' in log and log.endswith(f'failed={failed}')
    assert sum(r.message == 'discord_remove_kept count=1' for r in caplog.records) == kept


async def test_at_df_13c_tombstone_requires_original(gate, lab):
    mid, _ = await lab.employee()
    await settled(gate)
    post = lab.post(mid)
    path = next(gate.journal.path.glob('*.jsonl'))
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    # Keep contiguous sequences while replacing the original with an unrelated event.
    for row in rows:
        if row.get('msg_id') == mid:
            row.update(msg_id='fixture-other-message')
    path.write_text(''.join(json.dumps(row) + '\n' for row in rows))
    gate.journal.close()
    gate.journal.open()
    await lab.append('delete', mid)
    await settled(gate)
    lab.writes.clear()
    await lab.restart()
    assert lab.writes == [] and post.id in lab.posts


async def startup_fixture(gate, lab):
    first, _ = await lab.employee('P1')
    scoped, key = await lab.employee('P2')
    await lab.employee('P2 next', key=key)
    partial, key3 = await lab.employee('P3')
    removed, _ = await lab.employee('P3 next', key=key3)
    edited, _ = await lab.employee('🔴 B', asked=True)
    unchanged, _ = await lab.employee('P5')
    await settled(gate)
    await lab.offline('delete', first)
    await lab.offline('delete', scoped, scope='thread', room='alpha', thread=key)
    await lab.offline('delete', removed)
    await lab.offline('edit', edited, text='✅ B', buttons=[])
    await lab.offline('state', edited, reply_state='closed')
    return first, scoped, partial, removed, edited, unchanged


async def test_at_df_09_and_14_to_16_startup_order_and_idempotency(gate, lab, caplog):
    first, scoped, partial, removed, edited, unchanged = await startup_fixture(gate, lab)
    post1, post2, post3, post4, post5 = [lab.post(mid).id for mid in (first, scoped, partial, edited, unchanged)]
    lab.posts[post5].auto_archive_duration = 4320
    lab.writes.clear()
    caplog.set_level(logging.INFO, logger='gate.discord')
    await lab.restart()
    assert {x[1] for x in lab.writes[:2]} == {post1, post2}
    assert [x[0] for x in lab.writes[:2]] == ['post_delete', 'post_delete']
    assert lab.writes[2:] == [
        ('delete_message', post3, lab.sent(removed)[0][1]),
        ('edit_message', post4, lab.sent(edited)[0][1], '✅ B'),
        ('post_edit', post4, {'name': '✅ B'}),
        ('post_edit', post4, {'archived': True}),
        ('post_edit', post5, {'auto_archive_duration': 1440}),
    ]
    assert ('discord_reconcile removed_posts=2 removed_messages=1 kept_posts=0 edited=1 '
            'renamed=1 archived=1 failed=0') in caplog.messages
    lab.writes.clear()
    caplog.clear()
    await lab.restart()
    assert lab.writes == []
    assert ('discord_reconcile removed_posts=2 removed_messages=1 kept_posts=0 edited=0 '
            'renamed=0 archived=0 failed=0') in caplog.messages


@pytest.mark.parametrize('unpair', [False, True])
async def test_at_df_17_startup_failure_and_pair_change(gate, lab, monkeypatch, caplog, unpair):
    first, scoped, _, _, _, _ = await startup_fixture(gate, lab)
    post1, post2 = lab.post(first), lab.post(scoped)
    if unpair:
        original = post1.delete

        async def delete():
            await original()
            with gate.discord.settings_store.locked():
                gate.discord.settings_store.write('settings.json', {'enabled': False})

        post1.delete = delete
    else:
        post1.delete_error = Forbidden('fixture-private')
    lab.writes.clear()
    caplog.set_level(logging.INFO, logger='gate.discord')
    await lab.restart()
    if unpair:
        assert lab.writes == [('post_delete', post1.id)]
    else:
        assert lab.writes[0] == ('post_delete', post2.id)
        assert any(x[0] == 'edit_message' for x in lab.writes)
        assert 'discord_remove_failed kind=Forbidden' in caplog.messages
        assert any(line.endswith('failed=1') for line in caplog.messages)


async def test_at_df_19_startup_read_serializes_with_live_send_and_edit(gate, lab):
    mid, key = await lab.employee()
    await settled(gate)
    post = lab.post(mid)
    await lab.offline('edit', mid, text='offline edit')
    lab.writes.clear()
    entered, release = asyncio.Event(), asyncio.Event()
    post.read_barrier = entered, release
    reboot = asyncio.create_task(lab.restart())
    await asyncio.wait_for(entered.wait(), 3)
    await lab.employee('queued employee', key=key)
    await lab.append('edit', mid, text='latest edit')
    await asyncio.sleep(.12)
    assert lab.writes == []
    release.set()
    await reboot
    await settled(gate)
    changed = [call for call in lab.writes if call[0] in ('send', 'edit_message')]
    assert [(x[0], x[-1]) for x in changed] == [
        ('edit_message', 'offline edit'), ('send', 'queued employee'), ('edit_message', 'latest edit')]


async def test_title_http_reports_rate_limit_without_retry(gate, monkeypatch, discord_module):
    import sys
    from types import ModuleType
    import aiohttp

    class HTTPException(Exception):
        def __init__(self, response, _):
            self.status = response.status
            self.response = response

    class Route:
        def __init__(self, method, path, *, channel_id):
            self.method = method
            self.url = path.format(channel_id=channel_id)

    class Response:
        status = 429

        async def json(self):
            return {'retry_after': 600}

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            pass

    calls = []

    def request(method, path, **fields):
        calls.append((method, path, fields['json']))
        assert fields['allow_redirects'] is False
        return Response()

    module = ModuleType('discord.http')
    module.Route = Route
    monkeypatch.setitem(sys.modules, 'discord.http', module)
    monkeypatch.setattr(discord_module, 'HTTPException', HTTPException)
    monkeypatch.setattr(aiohttp, 'request', request)
    monkeypatch.setattr(door, '_bot', SimpleNamespace(http=SimpleNamespace(
        token='fixture', user_agent='fixture', proxy=None, proxy_auth=None)))
    with pytest.raises(door.SyncRateLimited) as raised:
        await gate.discord.rename_post(SimpleNamespace(id='fixture', archived=True), 'Last title')
    assert raised.value.delay == 600
    assert calls == [('PATCH', '/channels/fixture', {'name': 'Last title', 'archived': False})]
