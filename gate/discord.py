"""Discord forum window. The journal owns messages; this door owns only routing."""
import asyncio
from collections import Counter, defaultdict
from contextlib import AsyncExitStack, asynccontextmanager
from datetime import datetime
import hmac
import json
import logging
import math
import os
from pathlib import Path
import secrets
import tempfile
import time
from types import SimpleNamespace
from weakref import WeakValueDictionary

from . import reply_rules
from .auth import AuthStore, PAIR_TTL, digest
from .context import thinking
from .files import UnknownFile
from .history_queries import assess, ask_row, question

log = logging.getLogger(__name__)
_discord = _bot = None
SETTLE_SECONDS = 2.0
TYPING_SECONDS = 8.0
MAX_SEND_FILE_BYTES = 8 * 1024 * 1024
MAX_RECEIVE_FILE_BYTES = 50 * 1024 * 1024
MAX_CONTENT_CHARACTERS = 2000
CATEGORY_LIMIT = 50
AUTO_ARCHIVE_MINUTES = 1440
RETRY_ATTEMPTS = 3
RETRY_DELAY = 60
STACK = '~stack'
DEFAULT_CATEGORY = object()
ARCHIVE_CATEGORY = object()
FOLLOW_STEPS = ('remove_post', 'remove_messages', 'update', 'rename', 'archive', 'duration')
IGNORED_POST_MESSAGES = {'recipient_add', 'recipient_remove', 'channel_name_change', 'pins_add'}
EMPTY_CONTEXT = SimpleNamespace(value=lambda _: None)


class SyncSuperseded(Exception):
    """The pairing or enabled state changed during synchronization."""


class SyncRateLimited(Exception):
    def __init__(self, delay):
        self.delay = delay


def layout_ids_valid(layout):
    section_ids = [section['id'] for section in layout['sections']]
    room_ids = [room for group in [*layout['sections'], layout['stack']] for room in group['rooms']]
    return (STACK not in section_ids and len(section_ids) == len(set(section_ids))
            and len(room_ids) <= 2000 and len(room_ids) == len(set(room_ids)))


async def rate_limit_delay(exc):
    # Import only on a Discord call failure. The platform dependency is optional.
    import discord
    rate_limited = getattr(discord, 'RateLimited', ())
    http_error = getattr(discord, 'HTTPException', ())
    if isinstance(rate_limited, type) and isinstance(exc, rate_limited):
        delay = exc.retry_after
    elif isinstance(http_error, type) and isinstance(exc, http_error) and exc.status == 429:
        try:
            # discord.py decoded the HTTP body before constructing HTTPException.
            delay = (await exc.response.json())['retry_after']
        except Exception:
            delay = RETRY_DELAY
    else:
        return None
    return delay if type(delay) in (float, int) and math.isfinite(delay) and delay >= 0 else RETRY_DELAY


def split_content(text):
    """Lossless character chunks, preferring line endings within Discord's limit."""
    chunks = []
    while len(text) > MAX_CONTENT_CHARACTERS:
        end = text.rfind('\n', 0, MAX_CONTENT_CHARACTERS) + 1 or MAX_CONTENT_CHARACTERS
        chunks.append(text[:end])
        text = text[end:]
    return chunks + [text]


def post_title(text):
    return next((line.strip()[:100] for line in text.splitlines() if line.strip()), '새 대화')


def snowflake(value):
    # Native snowflakes are integers; persisted identifiers are strings.
    return int(value) if value.isdecimal() else value


def platform_ready():
    return _discord is not None and bool(getattr(_discord, 'is_connected', False)) and _bot is not None


def closed_for(user_id, author, guild, channel_ids):
    try:
        allowed = _discord._is_allowed_user(user_id, author, guild=guild, is_dm=False, channel_ids=channel_ids)
        return not allowed and _discord._get_allow_bots() == 'none'
    except Exception:
        return False


def component_ui():
    # Interactions need the component-capable Discord SDK. Keep text-only transports usable.
    try:
        from discord import ui
    except ImportError:
        return False
    return callable(getattr(ui.View, 'add_item', None))


GLYPHS = {'circle': '○', 'xmark': '✕', 'pencil': '✎', 'checkmark': '✓',
          'arrow.uturn.backward': '↶', 'play': '▷', 'arrow.down': '↓',
          'note.text': '▤', 'doc.on.doc': '▣'}


def component_view(items):
    from discord import ui
    view = ui.View(timeout=None)
    for label, identifier, style in items:
        view.add_item(ui.Button(label=label, custom_id=identifier, style=style))
    # Only the global listener dispatches these ids, including after a restart.
    view.stop()
    return view


def component_signature(items):
    return [(b.custom_id, b.label, b.style) for b in items]


class ButtonResponse:
    features = {'rooms'}

    def __init__(self):
        self.frame = {}

    async def send(self, frame):
        if frame['type'] in {'error', 'click_ack', 'retract_ack'}:
            self.frame = frame


def attach_discord(native, adapter):
    """Attach independent listeners once, without wrapping native ingress or doing network I/O."""
    global _discord, _bot
    _discord, _bot = adapter, native
    if getattr(native, '_hejo_discord_listener', False):
        return
    async def on_message(message):
        from .adapter import _primary
        bridge = getattr(_primary, 'discord', None)
        if bridge is not None:
            await bridge.on_message(message)
    native.add_listener(on_message, 'on_message')
    if component_ui():
        async def on_interaction(interaction):
            from .adapter import _primary
            bridge = getattr(_primary, 'discord', None)
            if bridge is not None:
                await bridge.on_interaction(interaction)
        native.add_listener(on_interaction, 'on_interaction')
    native._hejo_discord_listener = True


class Discord:
    def __init__(self, adapter, home, clock=time.time):
        self.adapter, self.clock = adapter, clock
        self.vault = AuthStore(home, clock)
        self.settings_store = AuthStore(home, clock)
        self.settings_store.path = Path(home) / 'shared' / 'hejo' / 'discord'
        self.channel_problem = False
        self.settle_seconds = SETTLE_SECONDS
        self.pending, self.changed, self.workers, self.wakes = {}, {}, {}, {}
        self._typing_tasks, self._typing_at = set(), {}
        self._button_tasks = set()
        self.sent = []
        self.core_open = False
        self._webhooks = {}
        self._followed_posts = set()
        self._receive_lock = asyncio.Lock()
        self._post_locks = WeakValueDictionary()
        self._startup_tags = set()
        self._startup_task = None
        self._rename_tasks = {}
        self.sent_path = self.settings_store.path / 'sent.jsonl'
        self._load_sent()
        self._channel_lock = asyncio.Lock()
        self.rate_limit_sleep = asyncio.sleep
        self._retry_task = None
        self._retry_tag = None
        self._sync_requested = asyncio.Event()
        self._sync_task = asyncio.create_task(self._sync_worker())
        self._connection_task = asyncio.create_task(self._watch_connection())

    def _private(self):
        try:
            value = self.vault.read('discord.json', {'pair': None, 'code': None})
            pair, code = value['pair'], value['code']
            if pair is not None and not (isinstance(pair, dict) and pair.get('platform') == 'discord'
                    and all(isinstance(pair.get(k), str) for k in ('guild_id', 'user_id', 'tag'))
                    and len(pair['tag']) == 8 and type(pair.get('paired_at')) in (int, float)):
                return None
            if code is not None and not (isinstance(code, dict) and isinstance(code.get('hash'), str)
                    and type(code.get('expires')) in (int, float) and type(code.get('used')) is bool):
                return None
            return value
        except (OSError, ValueError, TypeError, KeyError):
            return None

    def private(self):
        return self._private() or {'pair': None, 'code': None}

    def _settings(self):
        try:
            value = self.settings_store.read('settings.json', {'enabled': False})
            if type(value['enabled']) is bool:
                return {'enabled': value['enabled']}
        except (OSError, ValueError, TypeError, KeyError):
            pass
        return None

    def settings(self):
        return self._settings() or {'enabled': False}

    def active(self):
        return bool(self.adapter.is_connected and platform_ready() and self._private() is not None
                    and self._settings() is not None and self.private()['pair'] and self.settings()['enabled'])

    def status(self, ref=None):
        return {'v': 1, 'type': 'discord_status', 'platform_ready': platform_ready(),
                'paired': self.private()['pair'] is not None, **self.settings(),
                'channel_problem': self.channel_problem, 'core_open': self.core_is_open(), **({'ref': ref} if ref is not None else {})}

    async def publish(self, conn=None, ref=None):
        status = self.status()
        for peer in tuple(self.adapter.server.connections):
            if 'discord' in peer.features:
                await peer.send({**status, **({'ref': ref} if peer is conn and ref is not None else {})})

    async def command(self, frame, conn):
        kind, ref = frame['type'], frame['id']
        if 'discord' not in conn.features:
            await self.adapter.server.error('unexpected_frame', ref, conn)
            return
        if kind == 'discord':
            self.request_sync()
            await conn.send(self.status(ref))
            return
        if kind == 'discord_layout':
            layout = {key: frame[key] for key in ('sections', 'stack')}
            if not layout_ids_valid(layout):
                await self.adapter.server.error('bad_layout', ref, conn)
                return
            with self.settings_store.locked():
                changed = layout != self.layout()
                if changed:
                    self.settings_store.write('layout.json', layout)
            if changed:
                self.request_sync()
            await conn.send(self.status(ref))
            return
        if kind == 'discord_pair':
            if not platform_ready():
                await self.adapter.server.error('discord_unavailable', ref, conn)
                return
            code = secrets.token_urlsafe(9)
            with self.vault.locked():
                value = self.private()
                value['code'] = {'hash': digest(code), 'expires': self.clock() + PAIR_TTL, 'used': False}
                self.vault.write('discord.json', value)
            await conn.send({'v': 1, 'type': 'discord_code', 'ref': ref, 'code': code, 'expires_in': PAIR_TTL})
            return
        if kind == 'discord_unpair':
            with self.vault.locked():
                self.vault.write('discord.json', {'pair': None, 'code': None})
            settings = {'enabled': False}
        else:
            settings = {'enabled': frame['enabled']}
            if settings['enabled'] and not self.private()['pair']:
                await self.adapter.server.error('discord_unpaired', ref, conn)
                return
        with self.settings_store.locked():
            self.settings_store.write('settings.json', settings)
        await self.publish(conn, ref)
        self.request_sync()

    def pending_code(self, message, private):
        code = private.get('code')
        return bool(code and not code['used'] and self.clock() < code['expires']
                    and hmac.compare_digest(code['hash'], digest(message.content.strip())))

    def core_is_open(self):
        pair = self.private()['pair']
        if not pair or not platform_ready():
            return self.core_open
        try:
            guild = _bot.get_guild(snowflake(pair['guild_id']))
            author = guild.get_member(snowflake(pair['user_id'])) if guild else None
            return self.core_open or not closed_for(pair['user_id'], author, guild, set())
        except Exception:
            return True

    async def notice(self, message, text):
        try:
            await message.channel.send(text)
        except Exception as exc:
            log.warning('discord_notice_failed kind=%s', type(exc).__name__)

    async def on_message(self, message):
        # One admission lane also prevents duplicate attachment staging across concurrent events.
        async with self._receive_lock:
            await self._receive_message(message)

    def interaction_denial(self, interaction, tag):
        pair = self.private()['pair']
        if (not pair or str(interaction.guild_id) != pair['guild_id']
                or str(interaction.user.id) != pair['user_id']):
            return '사장만 누를 수 있어요'
        if pair['tag'] != tag or not self.active():
            return '다시 연결한 뒤에는 hejo에서 눌러 주세요'

    async def on_interaction(self, interaction):
        custom_id = (interaction.data or {}).get('custom_id')
        if not isinstance(custom_id, str) or not custom_id.startswith('hejo:'):
            return
        try:
            parts = custom_id.split(':', 3)
            if len(parts) != 4:
                return
            _, tag, mid, button_id = parts
            denied = self.interaction_denial(interaction, tag)
            if denied:
                return await interaction.response.send_message(denied, ephemeral=True)
            if mid != 'x':
                # Determine modal vs. defer from the card, without projecting its whole thread.
                question = self.adapter.journal.history.message(mid) or {}
                if button_id == 'std:comment' or any(b['id'] == button_id and reply_rules.word(b['label']) == '의견'
                                                     for b in question.get('buttons', [])):
                    return await self.open_comment(interaction, tag, mid, button_id)
            await self.submit_button(interaction, tag, mid, button_id)
        except Exception as exc:
            log.warning('discord_interaction_failed kind=%s', type(exc).__name__)

    async def open_comment(self, interaction, tag, mid, button_id):
        from discord import ui, TextStyle
        door = self

        class Comment(ui.Modal):
            async def on_submit(self, submission):
                try:
                    denied = door.interaction_denial(submission, tag)
                    if denied:
                        return await submission.response.send_message(denied, ephemeral=True)
                    await door.submit_button(submission, tag, mid, button_id, text=field.value)
                except Exception as exc:
                    log.warning('discord_interaction_failed kind=%s', type(exc).__name__)

        modal = Comment(title='의견', timeout=300)
        field = ui.TextInput(label='의견', style=TextStyle.paragraph, min_length=1, max_length=4000)
        modal.add_item(field)
        await interaction.response.send_modal(modal)

    async def submit_button(self, interaction, tag, mid, button_id, **fields):
        from discord import ButtonStyle
        await interaction.response.defer(ephemeral=True, thinking=True)
        denied = self.interaction_denial(interaction, tag)
        if denied:
            return await interaction.followup.send(denied, ephemeral=True)
        response = ButtonResponse()
        if mid == 'x':
            await self.adapter.change_answer({'type': 'retract', 'answer_id': button_id}, response)
        else:
            await self.adapter.click(dict(msg_id=mid, button_id=button_id, **fields), response, source='discord')
        ack = response.frame
        if ack.get('type') == 'click_ack':
            remaining = (datetime.fromisoformat(ack['undo_until']) - self.adapter._reply_clock()).total_seconds()
            seconds = min(ack['undo_seconds'], remaining - (reply_rules.UNDO_GRACE_SECONDS - ack['undo_seconds']))
            if seconds <= 0:
                return await interaction.followup.send('보냈어요', ephemeral=True)
            deadline = asyncio.get_running_loop().time() + seconds
            view = component_view([('취소', f"hejo:{tag}:x:{ack['answer_id']}", ButtonStyle.secondary)])
            sent = await interaction.followup.send('보냈어요', ephemeral=True, view=view, wait=True)
            async def expire():
                await asyncio.sleep(max(0, deadline - asyncio.get_running_loop().time()))
                try:
                    await sent.edit(view=None)
                except Exception as exc:
                    log.warning('discord_interaction_failed kind=%s', type(exc).__name__)
            task = asyncio.create_task(expire())
            self._button_tasks.add(task)
            task.add_done_callback(self._button_tasks.discard)
        else:
            text = '취소했어요' if ack.get('type') == 'retract_ack' else '지금은 처리할 수 없어요'
            await interaction.followup.send(text, ephemeral=True)

    async def _receive_message(self, message):
        if (not self.adapter.is_connected or not platform_ready() or message.guild is None
                or message.author.bot or message.webhook_id):
            return
        private = self._private()
        if private is None or self._settings() is None:
            return
        parent = getattr(message.channel, 'parent_id', None)
        ids = {str(message.channel.id)} | ({str(parent)} if parent is not None else set())
        closed = closed_for(str(message.author.id), message.author, message.guild, ids)
        pair = private['pair']
        owned = pair and pair['guild_id'] == str(message.guild.id) and pair['user_id'] == str(message.author.id)
        if not closed:
            if owned:
                self.core_open = True
                log.warning('discord_core_open')
                await self.publish()
            return
        self.core_open = False
        if self.pending_code(message, private):
            with self.vault.locked():
                private = self._private()
                if private is None or self._settings() is None or not self.pending_code(message, private):
                    return
                private['pair'] = {'platform': 'discord', 'guild_id': str(message.guild.id),
                                   'user_id': str(message.author.id), 'tag': secrets.token_hex(4), 'paired_at': self.clock()}
                private['code']['used'] = True
                self.vault.write('discord.json', private)
            self._webhooks.clear()
            await self.notice(message, '연결됐어요')
            await self.publish()
            self.request_sync()
            return
        if not self.active() or not owned:
            return
        tag = pair['tag']
        channel = str(parent) if parent is not None else str(message.channel.id)
        post = str(message.channel.id) if parent is not None else '-'
        client_id = f'discord:{tag}:{channel}:{post}:{message.id}'
        if any(row.get('client_msg_id') == client_id for row in self.adapter.journal.records):
            return
        room = next((room for room, entry in self.channels(tag)['channels'].items()
                     if parent is not None and entry['channel'] == channel and not entry['closed']
                     and room in self.rooms()), None)
        if room is None:
            await self.notice(message, '앱에서 만든 방 채널에 써 주세요')
            return
        target = self.reply_thread(post, tag)
        thread = target[1] if target and target[0] == room else None
        text = message.content.strip()
        if str(message.id) == post or getattr(message.channel, 'starter', False):
            title = message.channel.name.strip()
            if not text.startswith(title):
                text = title + ('\n' + text if text else '')
        if not text and not message.attachments:
            return
        group = self.adapter.journal.rooms.get(room)
        employee = group['lead'] if group else room
        from .server import LIMITS
        try:
            if len(text.encode()) > LIMITS['text_bytes']:
                raise ValueError('too_large')
            files = []
            with tempfile.TemporaryDirectory() as directory:
                for index, attachment in enumerate(message.attachments):
                    if attachment.size > MAX_RECEIVE_FILE_BYTES:
                        raise ValueError('too_large')
                    # Never use an untrusted attachment name as a filesystem path.
                    path = Path(directory) / str(index) / Path(attachment.filename).name
                    path.parent.mkdir()
                    await attachment.save(path)
                    if path.stat().st_size > MAX_RECEIVE_FILE_BYTES:
                        raise ValueError('too_large')
                    staged = await self.adapter.files.copy(employee, path)
                    files.append(staged['file_id'])
            if not self.current(tag):
                return
            frame = {'employee': employee, 'thread': thread, 'text': text, 'client_msg_id': client_id,
                     'files': files, **({'room': room} if group else {})}
            reply = ExternalReply(self, message)
            received = await self.adapter.receive(frame, reply)
            if not received and not reply.failed:
                await reply.send({'type': 'error'})
        except Exception as exc:
            log.warning('discord_receive_failed kind=%s', type(exc).__name__)
            await self.notice(message, '지금은 받지 못했어요')

    def rooms(self):
        return {**{e['id']: e['name'] for e in self.adapter.employees()},
                **{room['id']: room['title'] for room in self.adapter.journal.rooms.values()
                   if not room.get('archived') and room['id'] not in self.adapter.journal.deleted_rooms}}

    def layout(self):
        from .server import CLIENT_VALIDATOR
        try:
            value = self.settings_store.read('layout.json', None)
            if not isinstance(value, dict) or value.keys() != {'sections', 'stack'}:
                return None
            frame = {**value, 'v': 1, 'type': 'discord_layout', 'id': 'stored'}
            if CLIENT_VALIDATOR.is_valid(frame) and layout_ids_valid(value):
                return value
        except (OSError, ValueError, TypeError, KeyError):
            pass
        return None

    def channels(self, tag):
        empty = {'tag': tag, 'category': None, 'archive': None, 'channels': {}}
        try:
            value = self.settings_store.read('channels.json', empty)
            if value['tag'] != tag:
                return empty
            entries = value['channels']
            sections = value.get('sections', {})
            if (not isinstance(sections, dict) or not all(isinstance(section, dict)
                    and isinstance(section.get('category'), str) and isinstance(section.get('name'), str)
                    for section in sections.values())):
                return empty
            if (not all(value.get(k) is None or isinstance(value[k], str) for k in ('category', 'archive'))
                    or not isinstance(entries, dict) or not all(isinstance(room, str) and isinstance(entry, dict)
                    and isinstance(entry['channel'], str) and isinstance(entry['name'], str)
                    and type(entry['closed']) is bool for room, entry in entries.items())):
                return empty
            return value
        except (OSError, ValueError, TypeError, KeyError):
            return empty

    def request_sync(self):
        if self.active():
            self._sync_requested.set()

    async def _watch_connection(self):
        previous = None
        while True:
            state = (platform_ready(), self.active())
            if state != previous:
                if previous is None or state[0] != previous[0]:
                    await self.publish()
                previous = state
                self.request_sync()
            await asyncio.sleep(.25)

    async def _sync_worker(self):
        while True:
            await self._sync_requested.wait()
            self._sync_requested.clear()
            await self.sync_channels()

    async def sync_channels(self):
        async with self._channel_lock:
            if not self.active():
                return
            pair = self.private()['pair']
            tag = pair['tag']
            try:
                guild = _bot.get_guild(snowflake(pair['guild_id']))
                sync = ChannelSync(self, guild, tag)
                await sync.run()
                problem = sync.problem
                if not problem and self.current(tag) and tag not in self._startup_tags:
                    self._startup_tags.add(tag)
                    if self._startup_task is not None:
                        self._startup_task.cancel()
                    self._startup_task = asyncio.create_task(self._reconcile(tag))
            except SyncSuperseded:
                return
            except SyncRateLimited as exc:
                problem = True
                if self.current(tag):
                    self._schedule_sync(tag, exc.delay)
            except Exception as exc:
                log.warning('discord_channel_failed kind=%s', type(exc).__name__)
                problem = True
            if self.current(tag) and self.channel_problem != problem:
                self.channel_problem = problem
                await self.publish()

    def _schedule_sync(self, tag, delay):
        if self._retry_task is not None:
            if self._retry_tag == tag:
                return
            self._retry_task.cancel()

        async def retry():
            try:
                await self.rate_limit_sleep(max(delay, RETRY_DELAY))
                if self.current(tag):
                    self.request_sync()
            finally:
                if self._retry_task is asyncio.current_task():
                    self._retry_task = None
                    self._retry_tag = None

        self._retry_tag = tag
        self._retry_task = asyncio.create_task(retry())

    def current(self, tag):
        return self.active() and self.private()['pair']['tag'] == tag

    def correspondences(self, tag):
        journal = self.adapter.journal
        for row in journal.records:
            if row['type'] != 'message' or row['role'] != 'owner':
                continue
            parts = row.get('client_msg_id', '').split(':')
            if len(parts) == 5 and parts[:2] == ['discord', tag]:
                _, _, ch, post, dc = parts
                yield ch, post, row['msg_id'], dc, False
        for row in self.sent:
            if row['tag'] == tag:
                yield row['ch'], row['post'], row['msg_id'], row['dc'], True

    def events(self, tag):
        journal = self.adapter.journal
        messages = {row['msg_id']: row['seq'] for row in journal.records if row['type'] == 'message'}
        events = [(messages[mid], ch, post, mid) for ch, post, mid, _, _ in self.correspondences(tag)
                  if mid in messages]
        # Stable order lets the replacement post of the same message supersede its predecessor.
        return sorted(events, key=lambda item: item[0])

    def reply_thread(self, post, tag):
        journal = self.adapter.journal
        match = next((event for event in reversed(self.events(tag)) if event[2] == post), None)
        key = journal.message_threads.get(match[3]) if match else None
        if (not key or not journal.message(match[3]) or key in journal.deleted_threads or key[0] not in self.rooms()):
            return None
        return key

    def recorded(self, row):
        kind = row['type']
        if kind in {'room', 'room_delete'}:
            self.request_sync()
            return
        if kind not in {'message', 'edit', 'state', 'delete'} or not self.active():
            return
        mid = row['msg_id']
        key = self.adapter.journal.message_threads.get(mid)
        if not key or key[0] not in self.rooms():
            return
        tag = self.private()['pair']['tag']
        send = kind == 'message' and (
            row['role'] == 'employee' or not row.get('client_msg_id', '').startswith('discord:'))
        queue = self.pending.setdefault(key, [])
        if component_ui():
            journal = self.adapter.journal
            original = row
            if kind == 'delete':
                original = next((r for r in reversed(journal.records)
                                 if r.get('msg_id') == mid and r['type'] == 'message'), {})
            targets = []
            if original.get('role') == 'owner':
                target = original.get('answer_to')
                if target:
                    targets.append(target)
                    undo = journal.history.undo(mid) or {}
                    if reply_rules.word(undo.get('label', original['text'])) != '의견':
                        send = False
                else:
                    # General replies can answer several earlier questions. Native cards
                    # retain their exception through the same history projection as click.
                    for q in journal.history.ids(key):
                        card = journal.history.resolve(q)
                        if card['seq'] >= original['seq']:
                            break
                        if 'answer' in card and (kind == 'delete' or (card['answer'] or {}).get('answer_id') == mid):
                            targets.append(q)
            elif kind == 'state' and 'reply_state' in row:
                targets.append(mid)
            for target in targets:
                if (target, tag, 'send') not in queue and (target, tag, 'edit') not in queue:
                    queue.append((target, tag, 'edit'))
        # A queued send reads the latest projection, including edits and answers.
        job = (mid, tag, 'send' if send else kind)
        if kind != 'edit' or ((mid, tag, 'send') not in queue and job not in queue):
            queue.append(job)
        self.changed[key] = asyncio.get_running_loop().time()
        self.wake(key)

    def wake(self, key):
        if key not in self.pending:
            return
        if key not in self.workers:
            self.wakes[key] = asyncio.Event()
            self.workers[key] = asyncio.create_task(self._settle(key))
        self.wakes[key].set()

    def typing(self, key):
        chat = 'room:' + key[0] if key[0] in self.adapter.journal.rooms else key[0]
        return any(thread == key[1] for _, thread in self.adapter._typing_threads.get(chat, set()))

    async def _settle(self, key):
        try:
            while self.pending.get(key):
                self.wakes[key].clear()
                msg_id, tag, kind = self.pending[key][0]
                row = self.adapter.journal.message(msg_id)
                if not self.current(tag):
                    self.pending[key].pop(0)
                    continue
                if kind != 'delete' and (kind != 'send' or (row and row['role'] == 'employee')):
                    delay = self.changed[key] + self.settle_seconds - asyncio.get_running_loop().time()
                    if delay > 0:
                        await asyncio.sleep(delay)
                        continue
                    if self.typing(key):
                        await self.wakes[key].wait()
                        continue
                self.pending[key].pop(0)
                if kind == 'send':
                    try:
                        await self._send_message(msg_id, key, tag)
                    except Exception as exc:
                        log.warning('discord_send_failed kind=%s', type(exc).__name__)
                try:
                    await self._follow_record(tag, key, msg_id, kind)
                except SyncSuperseded:
                    continue
        finally:
            self.pending.pop(key, None)
            self.workers.pop(key, None)
            self.wakes.pop(key, None)
            self.changed.pop(key, None)

    def post_lock(self, tag, post):
        return self._post_locks.setdefault((tag, post), asyncio.Lock())

    def check_current(self, tag):
        if not self.current(tag):
            raise SyncSuperseded

    async def discord_call(self, tag, call, *args, **kwargs):
        self.check_current(tag)
        result = await call(*args, **kwargs)
        self.check_current(tag)
        return result

    def post_states(self, tag):
        journal = self.adapter.journal
        original = {row['msg_id']: row['seq'] for row in journal.records if row['type'] == 'message'}
        edited = {row['msg_id'] for row in journal.records if row['type'] == 'edit'}
        if component_ui():
            # On reconnect a question may have been answered or retracted offline.
            edited.update(row['msg_id'] for row in journal.records
                          if (row['type'] == 'message' and question(row))
                          or (row['type'] == 'state' and 'reply_state' in row))
        posts = {}
        for ch, post, mid, dc, sent in self.correspondences(tag):
            state = posts.setdefault(post, PostState(ch))
            key = journal.message_threads.get(mid)
            if key:
                state.keys.add(key)
            if ch != state.channel:
                state.conflicting_channel = True
            if sent:
                state.sent.setdefault(mid, []).append(dc)
            else:
                state.owner[mid] = dc
            if mid not in original:
                continue
            if mid in journal.deleted_messages or key in journal.deleted_threads:
                state.dead.add(mid)
            if original[mid] < state.first_seq:
                state.first_seq = original[mid]
                state.title_message = mid if sent else None
            if sent and mid in edited:
                state.edited.add(mid)
        return posts

    def post_settled(self, post, tag):
        key = self.reply_thread(post, tag)
        if key is None:
            return False
        index = self.adapter.journal.history
        lines = [row for identifier in index.ids(key) if (row := index.message(identifier)) is not None]
        result, _, _ = assess(lines, EMPTY_CONTEXT)
        return result['settled']

    async def _follow_record(self, tag, key, mid, kind):
        self.check_current(tag)
        stats = Counter()
        kept = set()
        for post, state in self.post_states(tag).items():
            if key not in state.keys:
                continue
            if kind == 'delete':
                steps = FOLLOW_STEPS[:2]
            elif kind == 'edit' and mid in state.sent:
                steps = ('update', 'rename', 'archive')
            else:
                steps = ('archive',)
            if any(job_tag == tag and job_kind == 'send' for _, job_tag, job_kind in self.pending.get(key, ())):
                steps = tuple(step for step in steps if step != 'archive')
            if steps:
                await self._match_post(tag, post, steps, kept, stats, edit_mid=mid)

    async def _reconcile(self, tag):
        stats = Counter()
        kept = set()
        posts = self.post_states(tag)
        try:
            for step in FOLLOW_STEPS:
                for post in posts:
                    await self._match_post(tag, post, (step,), kept, stats)
        except SyncSuperseded:
            return
        for task in stats.pop('title_retries', []):
            await task
        if not self.current(tag):
            return
        log.info('discord_reconcile removed_posts=%d removed_messages=%d kept_posts=%d edited=%d '
                 'renamed=%d archived=%d failed=%d', stats['removed_posts'], stats['removed_messages'],
                 stats['kept_posts'], stats['edited'], stats['renamed'], stats['archived'], stats['failed'])

    async def _match_post(self, tag, post, steps, kept, stats, *, edit_mid=None):
        async with self.post_lock(tag, post):
            self.check_current(tag)
            state = self.post_states(tag).get(post)
            if state is None:
                return
            follow = PostFollow(self, tag, post, state, kept, stats)
            for step in steps:
                await follow.apply(step, edit_mid)

    def retry_title(self, tag, post, delay, stats):
        key = (tag, post)
        if key in self._rename_tasks:
            return

        async def retry(delay):
            try:
                for _ in range(RETRY_ATTEMPTS):
                    await self.rate_limit_sleep(delay)
                    async with self.post_lock(tag, post):
                        self.check_current(tag)
                        state = self.post_states(tag).get(post)
                        if state is None or state.whole_deleted:
                            return
                        follow = PostFollow(self, tag, post, state, set(), stats)
                        try:
                            await follow.rename()
                        except SyncRateLimited as exc:
                            delay = exc.delay
                        else:
                            return
                follow.failed('rename', SyncRateLimited(delay))
            except SyncSuperseded:
                pass
            except Exception as exc:
                stats['failed'] += 1
                log.warning('discord_rename_failed kind=%s', type(exc).__name__)
            finally:
                self._rename_tasks.pop(key, None)

        task = asyncio.create_task(retry(delay))
        self._rename_tasks[key] = task
        stats.setdefault('title_retries', []).append(task)

    async def rename_post(self, thread, title):
        # Thread.edit retries a 429 internally with the original payload. Return
        # the delay to the post lane so it can obtain the latest title on retry.
        from aiohttp import ClientTimeout, request
        from discord import HTTPException
        from discord.http import Route

        http = _bot.http
        route = Route('PATCH', '/channels/{channel_id}', channel_id=thread.id)
        headers = {'Authorization': 'Bot ' + http.token, 'User-Agent': http.user_agent}
        fields = {'name': title}
        if thread.archived:
            fields['archived'] = False
        async with request(route.method, route.url, json=fields, headers=headers,
                           proxy=http.proxy, proxy_auth=http.proxy_auth,
                           allow_redirects=False, timeout=ClientTimeout(total=30)) as response:
            if response.status == 429:
                delay = await rate_limit_delay(HTTPException(response, None))
                raise SyncRateLimited(delay if delay is not None else RETRY_DELAY)
            if response.status != 200:
                raise HTTPException(response, None)

    def anchor(self, key, tag, channel):
        journal = self.adapter.journal
        return next((post for _, ch, post, mid in reversed(self.events(tag))
                     if ch == channel and journal.message_threads.get(mid) == key), None)

    async def webhook(self, channel, *, create=True):
        key = (_bot, str(channel.id))
        if key not in self._webhooks:
            hooks = await channel.webhooks()
            hook = next((hook for hook in hooks if hook.name == 'hejo'
                         and getattr(hook.user, 'id', None) == _bot.user.id), None)
            if hook is None:
                if not create:
                    raise LookupError('missing_hejo_webhook')
                hook = await channel.create_webhook(name='hejo')
            self._webhooks[key] = hook
        return self._webhooks[key]

    def question_display(self, row, tag):
        from discord import ButtonStyle
        projected = self.adapter.journal.history.resolve(row['msg_id']) or {}
        answer = projected.get('answer')
        if answer:
            owner = self.adapter.journal.history.message(answer['answer_id']) or {}
            undo = self.adapter.journal.history.undo(answer['answer_id']) or {}
            discord_origin = undo.get('source') == 'discord' or owner.get('client_msg_id', '').startswith('discord:')
            source = '디스코드에서' if discord_origin else 'hejo에서'
            label = reply_rules.word(answer['label'] or '')
            icon = GLYPHS.get(reply_rules.LABELS.get(label, (None, None))[1], '•')
            return f"\n{icon} {answer['result'] or '답변함'} · {source}", None
        if 'answer' not in projected:
            return '', None
        buttons = ask_row(projected)['buttons']
        if not buttons:
            return '', None
        items = []
        for btn in buttons:
            label = reply_rules.word(btn['label'])
            identifier = f"hejo:{tag}:{row['msg_id']}:{btn['id']}"
            if len(identifier) > 100:
                return '\n선택: ' + ' / '.join(b['label'] for b in buttons) + '\n(이 선택은 hejo 앱에서 눌러 주세요)', None
            style = ButtonStyle.primary if label == '승인' else ButtonStyle.secondary
            items.append((GLYPHS.get(btn.get('icon'), '•') + ' ' + label, identifier, style))
        return '', component_view(items)

    def render_message(self, row, tag):
        text = row['text']
        view = None
        suffix = ''
        if component_ui():
            if row['role'] == 'employee':
                suffix, view = self.question_display(row, tag)
        else:
            replies = [b['label'] for b in row.get('buttons', []) if b['kind'] == 'reply']
            if replies:
                text += '\n선택: ' + ' / '.join(replies)
            if any(b['kind'] != 'reply' for b in row.get('buttons', [])):
                text += '\n(이 선택은 hejo 앱에서 눌러 주세요)'
        attachments = []
        for file in row.get('files', []):
            try:
                path, _ = self.adapter.files.registered(row['employee'], file['file_id'])
                if path.stat().st_size > MAX_SEND_FILE_BYTES:
                    raise ValueError('too_large')
                attachments.append(path)
            except (UnknownFile, OSError, ValueError):
                text += f"\n📎 {file['name']} (hejo 앱에서 열기)"
        return text + suffix, attachments, view

    async def _send_message(self, msg_id, key, tag):
        row = self.adapter.journal.message(msg_id)
        if (not row or thinking(row['text']) or not self.active() or key[0] not in self.rooms()
                or key in self.adapter.journal.deleted_threads or self.private()['pair']['tag'] != tag):
            return
        pair = self.private()['pair']
        entry = self.channels(tag)['channels'].get(key[0])
        guild = _bot.get_guild(snowflake(pair['guild_id']))
        if not entry or not guild or guild.get_channel(snowflake(entry['channel'])) is None:
            await self.sync_channels()
            entry = self.channels(tag)['channels'].get(key[0])
        if (not entry or entry['closed'] or not self.current(tag) or key[0] not in self.rooms()
                or not guild or guild.get_channel(snowflake(entry['channel'])) is None):
            return
        # Topic creation can yield for a long time; settle the current journal value again.
        while True:
            row = self.adapter.journal.message(msg_id)
            if (not row or thinking(row['text']) or not self.active() or self.private()['pair']['tag'] != tag
                    or key[0] not in self.rooms() or key in self.adapter.journal.deleted_threads):
                return
            if row['role'] == 'employee':
                self.wakes[key].clear()
                delay = self.changed[key] + self.settle_seconds - asyncio.get_running_loop().time()
                if delay > 0:
                    await asyncio.sleep(delay)
                    continue
                if self.typing(key):
                    await self.wakes[key].wait()
                    continue
            break
        post = self.anchor(key, tag, entry['channel'])
        async with AsyncExitStack() as locks:
            if post is not None:
                await locks.enter_async_context(self.post_lock(tag, post))
            row = self.adapter.journal.message(msg_id)
            if not row or not self.current(tag) or key[0] not in self.rooms():
                return
            await self._deliver_message(row, key, tag, pair, guild, entry, post, locks)

    async def _deliver_message(self, row, key, tag, pair, guild, entry, post, locks):
        msg_id = row['msg_id']
        from discord import AllowedMentions, File, Object, NotFound
        names = {e['id']: e['name'] for e in self.adapter.employees()}
        label = self.adapter.owner_label('사장') if row['role'] == 'owner' else names.get(row['employee'], row['employee'])
        title = post_title(row['text'])
        text, attachments, view = self.render_message(row, tag)
        channel = guild.get_channel(snowflake(entry['channel']))
        webhook_key = (_bot, str(channel.id))
        hook = await self.webhook(channel)
        chunks = split_content(text) if text else ['']
        for index, chunk in enumerate(chunks):
            if not self.current(tag) or key[0] not in self.rooms() or key in self.adapter.journal.deleted_threads:
                return
            args = {'content': chunk, 'username': label, 'allowed_mentions': AllowedMentions.none(), 'wait': True}
            if view and index == len(chunks) - 1:
                args['view'] = view
            # Discord rejects an empty message. File-only rows start the post with the first file.
            first_path = attachments.pop(0) if not chunk and attachments else None
            first_file = File(first_path) if first_path is not None else None
            if first_file:
                args['files'] = [first_file]
            try:
                if post:
                    try:
                        result = await hook.send(**args, thread=Object(id=post))
                    except NotFound:
                        if not self.current(tag) or key[0] not in self.rooms() or key in self.adapter.journal.deleted_threads:
                            return
                        if first_file:
                            # Webhook.send closes uploaded files even when HTTP returns 404.
                            first_file.close()
                            first_file = File(first_path)
                            args['files'] = [first_file]
                        result = await hook.send(**args, thread_name=title)
                else:
                    result = await hook.send(**args, thread_name=title)
                if not result:
                    raise OSError('send_failed')
                destination = str(result.channel.id)
                if destination != post:
                    await locks.enter_async_context(self.post_lock(tag, destination))
                post = destination
                self._save_sent(tag, entry['channel'], post, str(result.id), msg_id)
            except NotFound:
                # Creating a post failed. Leave webhook recovery to the next message.
                if self._webhooks.get(webhook_key) is hook:
                    self._webhooks.pop(webhook_key)
                raise
            finally:
                if first_file:
                    first_file.close()
        await self._follow(post, pair)
        for path in attachments:
            if not self.current(tag):
                return
            try:
                file = File(path)
                try:
                    result = await hook.send(username=label, files=[file], thread=Object(id=post),
                                             allowed_mentions=AllowedMentions.none(), wait=True)
                finally:
                    file.close()
                if not result:
                    raise OSError('send_failed')
                self._save_sent(tag, entry['channel'], post, str(result.id), msg_id)
            except Exception as exc:
                log.warning('discord_file_send_failed kind=%s', type(exc).__name__)

    async def _follow(self, post, pair):
        key = (pair['tag'], post)
        if key in self._followed_posts or not self.current(pair['tag']):
            return
        # Reserve before awaiting so simultaneous sends cannot add the same member twice.
        self._followed_posts.add(key)
        followed = False
        try:
            await _bot.http.add_user_to_thread(snowflake(post), snowflake(pair['user_id']))
            followed = True
        except Exception as exc:
            log.warning('discord_follow_failed kind=%s', type(exc).__name__)
        finally:
            if not followed:
                self._followed_posts.discard(key)

    def _load_sent(self):
        try:
            raw = self.sent_path.read_bytes()
        except OSError:
            return
        lines = raw.splitlines(keepends=True)
        for line in lines:
            try:
                row = json.loads(line) if line.endswith(b'\n') else None
                if (isinstance(row, dict) and set(row) == {'tag', 'ch', 'post', 'dc', 'msg_id'}
                        and all(isinstance(value, str) for value in row.values())):
                    self.sent.append(row)
            except (ValueError, UnicodeDecodeError):
                continue
        try:
            with self.sent_path.open('r+b') as stream:
                os.fchmod(stream.fileno(), 0o600)
                if lines and not lines[-1].endswith(b'\n'):
                    stream.truncate(len(raw) - len(lines[-1]))
                stream.flush()
                os.fsync(stream.fileno())
        except OSError:
            log.warning('discord_sent_read_failed')

    def _save_sent(self, tag, channel, post, dc_id, msg_id):
        row = {'tag': tag, 'ch': channel, 'post': post, 'dc': dc_id, 'msg_id': msg_id}
        with self.settings_store.locked():
            created = not self.sent_path.exists()
            fd = os.open(self.sent_path, os.O_CREAT | os.O_WRONLY | os.O_APPEND, 0o600)
            try:
                os.fchmod(fd, 0o600)
                with os.fdopen(fd, 'ab', closefd=False) as stream:
                    stream.write((json.dumps(row) + '\n').encode())
                    stream.flush()
                    os.fsync(stream.fileno())
            finally:
                os.close(fd)
            if created:
                directory = os.open(self.settings_store.path, os.O_RDONLY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
        self.sent.append(row)

    def send_typing(self, key):
        if not self.active() or key[0] not in self.rooms() or not self.typing(key):
            return
        tag = self.private()['pair']['tag']
        entry = self.channels(tag)['channels'].get(key[0])
        if not entry or entry['closed']:
            return
        post = self.anchor(key, tag, entry['channel'])
        if not post:
            return
        throttle = (tag, post)
        now = asyncio.get_running_loop().time()
        if now - self._typing_at.get(throttle, float('-inf')) < TYPING_SECONDS:
            return
        self._typing_at[throttle] = now
        bot = _bot
        async def request():
            try:
                await bot.http.send_typing(snowflake(post))
            except Exception as exc:
                log.warning('discord_typing_failed kind=%s', type(exc).__name__)
        task = asyncio.create_task(request())
        self._typing_tasks.add(task)
        task.add_done_callback(self._typing_tasks.discard)

    async def close(self):
        tasks = (self._sync_task, self._connection_task, *self.workers.values(), *self._typing_tasks,
                 *self._rename_tasks.values(), *self._button_tasks)
        if self._startup_task is not None:
            tasks += (self._startup_task,)
        if self._retry_task is not None:
            tasks += (self._retry_task,)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self.workers.clear()
        self.pending.clear()
        self._typing_tasks.clear()


class PostState:
    """A view of one forum post reconstructed from journal and sent correspondences."""

    def __init__(self, channel):
        self.channel = channel
        self.conflicting_channel = False
        self.sent, self.owner = {}, {}
        self.keys, self.dead, self.edited = set(), set(), set()
        self.first_seq = math.inf
        self.title_message = None

    @property
    def whole_deleted(self):
        return (self.sent.keys() | self.owner.keys()) <= self.dead

    @property
    def dead_sent(self):
        live = {dc for mid, ids in self.sent.items() if mid not in self.dead for dc in ids}
        owners = set(self.owner.values())
        return tuple(dict.fromkeys(dc for mid, ids in self.sent.items() if mid in self.dead
                                   for dc in ids if dc not in live and dc not in owners))


class PostFollow:
    """Compare one post with the current journal while holding its mutation lane."""

    def __init__(self, door, tag, post, state, kept, stats):
        self.door, self.tag, self.post = door, tag, post
        self.state, self.kept, self.stats = state, kept, stats
        self.thread = None
        self.skip_title = False
        self.missing = False

    def failed(self, operation, exc):
        self.stats['failed'] += 1
        log.warning('discord_%s_failed kind=%s', operation, type(exc).__name__)

    async def call(self, method, *args, **kwargs):
        return await self.door.discord_call(self.tag, method, *args, **kwargs)

    async def locate(self):
        from discord import NotFound
        if self.thread is None and not self.missing:
            try:
                thread = await self.call(_bot.fetch_channel, snowflake(self.post))
            except NotFound:
                self.missing = True
                return None
            pair = self.door.private()['pair']
            if (self.state.conflicting_channel or str(thread.parent_id) != self.state.channel
                    or str(thread.guild.id) != pair['guild_id']):
                raise ValueError('unexpected_forum_post')
            self.thread = thread
        return self.thread

    async def webhook(self):
        if self.thread.parent is None:
            raise LookupError('unavailable_forum_parent')
        return await self.call(self.door.webhook, self.thread.parent, create=False)

    async def edit_thread(self, **fields):
        edited = await self.call(self.thread.edit, **fields)
        if edited is not None:
            self.thread = edited

    @asynccontextmanager
    async def writable(self):
        archived = self.thread.archived
        if archived:
            await self.edit_thread(archived=False)
        try:
            yield
        finally:
            if archived and self.door.current(self.tag):
                await self.edit_thread(archived=True)

    async def apply(self, step, edit_mid):
        operation = {'remove_post': 'remove', 'remove_messages': 'remove',
                     'update': 'update', 'rename': 'rename', 'archive': 'archive', 'duration': 'archive'}[step]
        try:
            if step == 'remove_post':
                if self.state.whole_deleted:
                    await self.remove_post()
                return
            if step == 'remove_messages':
                if not self.state.whole_deleted or self.post in self.kept:
                    await self.remove_messages()
                return
            if self.state.whole_deleted:
                return
            if step == 'update':
                for mid in self.state.sent:
                    if mid in self.state.edited and (edit_mid is None or mid == edit_mid):
                        await self.update(mid)
            elif step == 'rename':
                if not self.skip_title and (edit_mid is None or edit_mid == self.state.title_message):
                    if (self.tag, self.post) not in self.door._rename_tasks:
                        await self.rename()
            elif step == 'archive':
                if self.door.post_settled(self.post, self.tag) and await self.locate() and not self.thread.archived:
                    await self.edit_thread(archived=True)
                    self.stats['archived'] += 1
            elif await self.locate() and not self.thread.archived:
                if self.thread.auto_archive_duration != AUTO_ARCHIVE_MINUTES:
                    await self.edit_thread(auto_archive_duration=AUTO_ARCHIVE_MINUTES)
        except SyncSuperseded:
            raise
        except SyncRateLimited as exc:
            if step == 'rename':
                self.door.retry_title(self.tag, self.post, exc.delay, self.stats)
            else:
                self.failed(operation, exc)
        except Exception as exc:
            self.failed(operation, exc)

    async def remove_post(self):
        from discord import NotFound
        thread = await self.locate()
        if thread is not None:
            if not thread.permissions_for(thread.guild.me).read_message_history:
                raise PermissionError('unreadable_history')
            try:
                seen = []
                async for message in thread.history(limit=None):
                    self.door.check_current(self.tag)
                    seen.append((str(message.id), getattr(message.type, 'name', None)))
                # New inbound records may have arrived while reading the Discord history.
                state = self.door.post_states(self.tag).get(self.post)
                if state is None or state.conflicting_channel:
                    return
                self.state = state
                if not state.whole_deleted:
                    return
                known = set(state.dead_sent) | set(state.owner.values())
                if any(kind not in IGNORED_POST_MESSAGES and
                       (kind not in {'default', 'reply'} or dc not in known) for dc, kind in seen):
                    self.kept.add(self.post)
                    self.stats['kept_posts'] += 1
                    log.info('discord_remove_kept count=1')
                    return
                await self.call(thread.delete)
            except NotFound:
                pass
        self.missing = True
        self.stats['removed_posts'] += 1

    async def remove_messages(self):
        from discord import NotFound, Object
        ids = self.state.dead_sent
        if not ids:
            return
        thread = await self.locate()
        if thread is None:
            self.stats['removed_messages'] += len(ids)
            return
        remaining = []
        for dc in ids:
            try:
                await self.call(thread.fetch_message, snowflake(dc))
            except NotFound:
                self.stats['removed_messages'] += 1
            else:
                remaining.append(dc)
        if not remaining:
            return
        hook = await self.webhook()
        thread_ref = Object(id=snowflake(self.post))
        async with self.writable():
            for dc in remaining:
                try:
                    await self.call(hook.delete_message, snowflake(dc), thread=thread_ref)
                except SyncSuperseded:
                    raise
                except NotFound:
                    self.stats['removed_messages'] += 1
                except Exception as exc:
                    self.failed('remove', exc)
                else:
                    self.stats['removed_messages'] += 1

    async def update(self, mid):
        from discord import AllowedMentions, NotFound, Object
        row = self.door.adapter.journal.message(mid)
        if not row:
            return
        thread = await self.locate()
        # An absent post has no surviving body chunks.
        known = []
        try:
            if thread is not None:
                ref = Object(id=snowflake(self.post))
                for dc in dict.fromkeys(self.state.sent[mid]):
                    try:
                        message = await self.call(thread.fetch_message, snowflake(dc))
                    except NotFound:
                        continue
                    # A file-only question can carry its controls on the first attachment.
                    if message.content or getattr(message, 'components', []) or (
                            component_ui() and dc == self.state.sent[mid][0] and message.attachments
                            and row.get('files') and not row['text']):
                        known.append((message, dc))
            if not known:
                self.stats['failed'] += 1
                log.warning('discord_update_failed kind=NotFound')
                self.skip_title |= mid == self.state.title_message
                return
            text, _, view = self.door.render_message(row, self.tag)
            desired = split_content(text) if text or view else []
            edits = []
            for index, ((message, dc), value) in enumerate(zip(known, desired)):
                wanted = view if index == len(desired) - 1 else None
                present = [b for action_row in getattr(message, 'components', []) for b in action_row.children]
                changed_view = component_signature(present) != component_signature(wanted.children if wanted else [])
                if message.content != value or changed_view:
                    edits.append((dc, value, {'view': wanted} if changed_view else {}))
            remove = known[len(desired):]
            add = desired[len(known):]
            if not (edits or remove or add):
                return
            hook = await self.webhook()
            mentions = AllowedMentions.none()
            changed = False
            async with self.writable():
                for dc, value, fields in edits:
                    try:
                        await self.call(hook.edit_message, snowflake(dc), thread=ref, content=value,
                                        allowed_mentions=mentions, **fields)
                    except SyncSuperseded:
                        raise
                    except Exception as exc:
                        self.failed('update', exc)
                        self.skip_title |= mid == self.state.title_message
                    else:
                        changed = True
                for message, dc in remove:
                    if message.attachments:
                        # Clear text without removing a file carried by the same Discord message.
                        await self.call(hook.edit_message, snowflake(dc), thread=ref, content='',
                                        allowed_mentions=mentions, **({'view': None} if getattr(message, 'components', []) else {}))
                    else:
                        await self.call(hook.delete_message, snowflake(dc), thread=ref)
                    changed = True
                for index, value in enumerate(add):
                    sent = await self.call(hook.send, thread=ref, content=value,
                                           username=known[0][0].author.display_name, allowed_mentions=mentions, wait=True,
                                           **({'view': view} if view and index == len(add) - 1 else {}))
                    if not sent:
                        raise OSError('send_failed')
                    self.door._save_sent(self.tag, self.state.channel, self.post, str(sent.id), mid)
                    changed = True
            self.stats['edited'] += int(changed)
        except SyncSuperseded:
            raise
        except Exception as exc:
            self.failed('update', exc)
            self.skip_title |= mid == self.state.title_message

    async def rename(self):
        mid = self.state.title_message
        if mid is None or not await self.locate():
            return
        row = self.door.adapter.journal.message(mid)
        if row is None:
            return
        title = post_title(row['text'])
        if self.thread.name == title:
            return
        try:
            await self.call(self.door.rename_post, self.thread, title)
        except (SyncSuperseded, SyncRateLimited):
            raise
        except Exception as exc:
            delay = await rate_limit_delay(exc)
            if delay is None:
                self.failed('rename', exc)
            else:
                raise SyncRateLimited(delay) from None
        else:
            self.stats['renamed'] += 1
            if self.thread.archived:
                await self.edit_thread(archived=True)


class ChannelSync:
    """One reconciliation under the Discord channel lock."""

    def __init__(self, door, guild, tag):
        self.door, self.guild, self.tag = door, guild, tag
        self.value = door.channels(tag)
        self.layout = door.layout()
        self.rooms = door.rooms()
        self.entries = self.value['channels']
        self.problem = False
        self.updated_channels = {}
        self.updated_parents = {}

    def check_current(self):
        if not self.door.current(self.tag):
            raise SyncSuperseded

    async def apply(self, call, *args, **kwargs):
        for attempt in range(RETRY_ATTEMPTS):
            self.check_current()
            try:
                result = await call(*args, **kwargs)
            except Exception as exc:
                self.check_current()
                delay = await rate_limit_delay(exc)
                if delay is None:
                    log.warning('discord_channel_failed kind=%s', type(exc).__name__)
                    self.problem = True
                    return False, None
                if attempt + 1 == RETRY_ATTEMPTS:
                    log.warning('discord_channel_failed kind=%s', type(exc).__name__)
                    raise SyncRateLimited(delay) from None
                await self.door.rate_limit_sleep(delay)
            else:
                self.check_current()
                return True, result

    def save(self):
        self.check_current()
        with self.door.settings_store.locked():
            self.door.settings_store.write('channels.json', self.value)

    def channel(self, identifier):
        return self.updated_channels.get(identifier) or self.guild.get_channel(snowflake(identifier))

    def room_channel(self, room):
        entry = self.entries.get(room)
        return self.channel(entry['channel']) if entry else None

    def parent(self, channel):
        identifier = str(channel.id)
        if identifier in self.updated_parents:
            return self.updated_parents[identifier]
        category = getattr(channel, 'category', None)
        parent_id = getattr(channel, 'category_id', None)
        return str(parent_id) if parent_id is not None else str(category.id) if category else None

    def children(self, category):
        identifier = str(category.id)
        cached = getattr(category, 'channels', None)
        if cached is None:
            # The original acceptance suite uses a dictionary of simple channel doubles.
            cached = self.guild.channels.values()
        children = {str(child.id): child for child in cached if self.parent(child) == identifier}
        for child_id, parent_id in self.updated_parents.items():
            if parent_id == identifier:
                children[child_id] = self.updated_channels[child_id]
        return children

    def category_entry(self, key):
        if key is DEFAULT_CATEGORY:
            return self.value.get('category'), 'hejo'
        if key is ARCHIVE_CATEGORY:
            return self.value.get('archive'), 'hejo 보관'
        entry = self.value.get('sections', {}).get(key, {})
        return entry.get('category'), entry.get('name')

    def category(self, key):
        identifier, _ = self.category_entry(key)
        return self.channel(identifier) if identifier else None

    async def ensure_category(self, key, name):
        identifier, recorded_name = self.category_entry(key)
        category = self.channel(identifier) if identifier else None
        if category is None:
            ok, category = await self.apply(self.guild.create_category, name)
            if not ok:
                return None
            identifier = str(category.id)
        elif recorded_name != name:
            ok, edited = await self.apply(category.edit, name=name)
            if not ok:
                return category
            category = edited or category
        else:
            return category
        self.updated_channels[identifier] = category
        if key is DEFAULT_CATEGORY:
            self.value['category'] = identifier
        elif key is ARCHIVE_CATEGORY:
            self.value['archive'] = identifier
        else:
            self.value.setdefault('sections', {})[key] = {'category': identifier, 'name': name}
        self.save()
        return category

    def room_order(self, room):
        return self.rooms.get(room, self.entries.get(room, {}).get('name', '')).casefold(), room

    def reserve(self, categories, destinations):
        # Managed children can move out. All other occupants reduce the room capacity.
        managed = {entry['channel'] for entry in self.entries.values()}
        by_category = defaultdict(list)
        for room, key in destinations.items():
            by_category[key].append(room)
        for key in [*categories, DEFAULT_CATEGORY]:
            if key not in by_category:
                continue
            category = categories.get(key) or self.category(key)
            reserved = len(self.children(category).keys() - managed) if category else 0
            overflow = sorted(by_category[key], key=self.room_order)[max(0, CATEGORY_LIMIT - reserved):]
            for room in overflow:
                if key is DEFAULT_CATEGORY:
                    del destinations[room]
                else:
                    by_category[DEFAULT_CATEGORY].append(room)
                    destinations[room] = DEFAULT_CATEGORY
            self.problem |= bool(overflow)

    async def place(self, room, channel, category, *, temporary=False):
        closed = room not in self.rooms
        previous = self.entries.get(room)
        name = None if closed else self.rooms[room]
        category_id = str(category.id)
        moved = channel is None or self.parent(channel) != category_id
        if channel is None:
            ok, channel = await self.apply(self.guild.create_forum, name=name, category=category)
            if not ok:
                return
        else:
            fields = {}
            if moved:
                fields['category'] = category
            if name is not None and previous['name'] != name:
                fields['name'] = name
            if fields:
                ok, edited = await self.apply(channel.edit, **fields)
                if not ok:
                    return
                channel = edited or channel
        identifier = str(channel.id)
        self.updated_channels[identifier] = channel
        if moved:
            self.updated_parents[identifier] = category_id
        entry = {'channel': identifier, 'name': name if name is not None else previous['name'],
                 'closed': previous['closed'] if temporary else closed}
        if entry != previous:
            self.entries[room] = entry
            self.save()

    async def place_rooms(self, pending):
        # Vacate existing channels before creating new ones. Break full-category
        # cycles with a single temporary move through hejo.
        while pending:
            ready = []
            for room, category in pending.items():
                channel = self.room_channel(room)
                if channel is None:
                    continue
                if self.parent(channel) == str(category.id) or len(self.children(category)) < CATEGORY_LIMIT:
                    ready.append(room)
                    await self.place(room, channel, category)
            for room in ready:
                del pending[room]
            if ready:
                continue
            default_id = self.category_entry(DEFAULT_CATEGORY)[0]
            wanted = {str(category.id) for category in pending.values()}
            cycle_room = next((room for room, category in pending.items() if room in self.rooms
                               and str(category.id) != default_id
                               and (channel := self.room_channel(room)) is not None
                               and (source := self.parent(channel)) != default_id
                               and source in wanted), None)
            if cycle_room is not None:
                channel = self.room_channel(cycle_room)
                staging = self.category(DEFAULT_CATEGORY)
                if staging is None:
                    staging = await self.ensure_category(DEFAULT_CATEGORY, 'hejo')
                if staging is not None and len(self.children(staging)) < CATEGORY_LIMIT:
                    await self.place(cycle_room, channel, staging, temporary=True)
                    if self.parent(channel) != str(staging.id):
                        del pending[cycle_room]
                    continue
            break

        for room, category in pending.items():
            if self.room_channel(room) is None and len(self.children(category)) < CATEGORY_LIMIT:
                await self.place(room, None, category)
            else:
                self.problem = True

    async def reorder(self, desired, occupants):
        if len(desired) < 2:
            return
        order = lambda channel: (channel.position, channel.id)
        if desired == sorted(desired, key=order):
            return
        # Update only managed IDs. Start after any tied position so Discord's
        # snowflake tie-break cannot undo the requested order.
        positions = sorted(channel.position for channel in desired)
        if len(set(positions)) != len(positions):
            start = max(channel.position for channel in occupants) + 1
            positions = range(start, start + len(desired))
        payload = [{'id': channel.id, 'position': position}
                   for channel, position in zip(desired, positions) if channel.position != position]
        await self.apply(_bot.http.bulk_channel_update, self.guild.id, payload)

    async def run(self):
        layout = self.layout
        groups = [] if layout is None else [*((row['id'], row) for row in layout['sections']), (STACK, layout['stack'])]
        destinations = {room: DEFAULT_CATEGORY for room in self.rooms}
        categories = {}
        for key, group in groups:
            categories[key] = await self.ensure_category(key, group['name'])
            for room in group['rooms']:
                if room in destinations:
                    destinations[room] = key
        self.reserve(categories, destinations)
        if DEFAULT_CATEGORY in destinations.values():
            categories[DEFAULT_CATEGORY] = await self.ensure_category(DEFAULT_CATEGORY, 'hejo')
        archived = [room for room in self.entries if room not in self.rooms and self.room_channel(room)]
        if archived:
            categories[ARCHIVE_CATEGORY] = await self.ensure_category(ARCHIVE_CATEGORY, 'hejo 보관')
        destinations.update(dict.fromkeys(archived, ARCHIVE_CATEGORY))
        pending = {room: categories[key] for room, key in destinations.items() if categories.get(key)}
        existing = {entry['channel'] for entry in self.entries.values()}
        await self.place_rooms(pending)
        for room in self.rooms:
            channel = self.room_channel(room)
            if channel is None:
                continue
            duration = getattr(channel, 'default_auto_archive_duration', AUTO_ARCHIVE_MINUTES)
            if str(channel.id) not in existing or duration != AUTO_ARCHIVE_MINUTES:
                await self.apply(channel.edit, default_auto_archive_duration=AUTO_ARCHIVE_MINUTES)

        if layout is not None:
            default = self.category(DEFAULT_CATEGORY)
            archive = self.category(ARCHIVE_CATEGORY)
            ordered = [category for category in [*(categories[key] for key, _ in groups), default, archive]
                       if category is not None]
            await self.reorder(ordered, ordered)
            by_channel = {entry['channel']: room for room, entry in self.entries.items()}
            for category in ordered:
                children = self.children(category)
                managed = sorted(children.keys() & by_channel.keys(), key=lambda cid: self.room_order(by_channel[cid]))
                await self.reorder([children[cid] for cid in managed], children.values())

        old_sections = self.value.get('sections', {}).keys() - {key for key, _ in groups}
        for key in [*sorted(old_sections), DEFAULT_CATEGORY]:
            category = self.category(key)
            if category is None or self.children(category):
                continue
            ok, _ = await self.apply(category.delete)
            if ok:
                if key is DEFAULT_CATEGORY:
                    self.value['category'] = None
                else:
                    del self.value['sections'][key]
                self.save()


class ExternalReply:
    features = {'rooms'}

    def __init__(self, bridge, event):
        self.bridge, self.event, self.failed = bridge, event, False

    async def send(self, frame):
        if frame['type'] == 'error':
            self.failed = True
            await self.bridge.notice(self.event, '지금은 받지 못했어요')
