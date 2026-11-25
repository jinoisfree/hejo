"""Discord forum window. The journal owns messages; this door owns only routing."""
import asyncio
import hmac
import json
import logging
import os
from pathlib import Path
import secrets
import tempfile
import time

from .auth import AuthStore, PAIR_TTL, digest
from .context import thinking
from .files import UnknownFile

log = logging.getLogger(__name__)
_discord = _bot = None
SETTLE_SECONDS = 2.0
TYPING_SECONDS = 8.0
MAX_SEND_FILE_BYTES = 8 * 1024 * 1024
MAX_RECEIVE_FILE_BYTES = 50 * 1024 * 1024
MAX_CONTENT_CHARACTERS = 2000


def split_content(text):
    """Lossless character chunks, preferring line endings within Discord's limit."""
    chunks = []
    while len(text) > MAX_CONTENT_CHARACTERS:
        end = text.rfind('\n', 0, MAX_CONTENT_CHARACTERS) + 1 or MAX_CONTENT_CHARACTERS
        chunks.append(text[:end])
        text = text[end:]
    return chunks + [text]


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


def attach_discord(native, adapter):
    """Attach one independent listener. Never wrap native ingress or do network I/O."""
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
        self.sent = []
        self.core_open = False
        self._webhooks = {}
        self._followed_posts = set()
        self._receive_lock = asyncio.Lock()
        self.sent_path = self.settings_store.path / 'sent.jsonl'
        self._load_sent()
        self._channel_lock = asyncio.Lock()
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

    def channels(self, tag):
        empty = {'tag': tag, 'category': None, 'archive': None, 'channels': {}}
        try:
            value = self.settings_store.read('channels.json', empty)
            if value['tag'] != tag:
                return empty
            entries = value['channels']
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
            value = self.channels(tag)
            desired = self.rooms()
            problem = False
            try:
                guild = _bot.get_guild(snowflake(pair['guild_id']))
                category = guild.get_channel(snowflake(value['category'])) if value['category'] else None
                if category is None:
                    category = await guild.create_category('hejo')
                    if not self.current(tag):
                        return
                    value['category'] = str(category.id)
                    with self.settings_store.locked():
                        self.settings_store.write('channels.json', value)
                for room in dict.fromkeys([*desired, *value['channels']]):
                    if not self.current(tag):
                        return
                    entry = value['channels'].get(room)
                    closed = room not in desired
                    try:
                        channel = guild.get_channel(snowflake(entry['channel'])) if entry else None
                        if channel is None and closed:
                            continue
                        destination = category
                        if closed:
                            destination = guild.get_channel(snowflake(value['archive'])) if value['archive'] else None
                            if destination is None:
                                destination = await guild.create_category('hejo 보관')
                                value['archive'] = str(destination.id)
                        if channel is None:
                            channel = await guild.create_forum(name=desired[room], category=destination)
                            entry = {'channel': str(channel.id), 'name': desired[room], 'closed': False}
                        else:
                            args = {}
                            if not closed and entry['name'] != desired[room]:
                                args['name'] = desired[room]
                            if entry['closed'] != closed:
                                args['category'] = destination
                            if args:
                                await channel.edit(**args)
                            entry = {**entry, 'name': desired.get(room, entry['name']), 'closed': closed}
                        if not self.current(tag):
                            return
                        value['channels'][room] = entry
                        with self.settings_store.locked():
                            self.settings_store.write('channels.json', value)
                    except Exception as exc:
                        log.warning('discord_channel_failed kind=%s', type(exc).__name__)
                        problem = True
            except Exception as exc:
                log.warning('discord_channel_failed kind=%s', type(exc).__name__)
                problem = True
            if self.channel_problem != problem:
                self.channel_problem = problem
                await self.publish()

    def current(self, tag):
        return self.active() and self.private()['pair']['tag'] == tag

    def events(self, tag):
        journal = self.adapter.journal
        messages = {row['msg_id']: row for row in journal.records if row['type'] == 'message'}
        events = []
        for row in messages.values():
            parts = row.get('client_msg_id', '').split(':')
            if len(parts) == 5 and parts[:2] == ['discord', tag]:
                events.append((row['seq'], parts[2], parts[3], row['msg_id']))
        for row in self.sent:
            if row['tag'] == tag and row['msg_id'] in messages:
                events.append((messages[row['msg_id']]['seq'], row['ch'], row['post'], row['msg_id']))
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
        if row['type'] in {'room', 'room_delete'}:
            self.request_sync()
            return
        key = self.adapter.journal.message_threads.get(row.get('msg_id'))
        if not key:
            return
        if (row['type'] == 'message' and self.active() and key[0] in self.rooms()
                and (row['role'] == 'employee' or not row.get('client_msg_id', '').startswith('discord:'))):
            self.pending.setdefault(key, []).append((row['msg_id'], self.private()['pair']['tag']))
        if key in self.pending:
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
                msg_id, tag = self.pending[key][0]
                row = self.adapter.journal.message(msg_id)
                if row and row['role'] == 'employee':
                    delay = self.changed[key] + self.settle_seconds - asyncio.get_running_loop().time()
                    if delay > 0:
                        await asyncio.sleep(delay)
                        continue
                    if self.typing(key):
                        await self.wakes[key].wait()
                        continue
                self.pending[key].pop(0)
                try:
                    await self._send_message(msg_id, key, tag)
                except Exception as exc:
                    log.warning('discord_send_failed kind=%s', type(exc).__name__)
        finally:
            self.pending.pop(key, None)
            self.workers.pop(key, None)
            self.wakes.pop(key, None)
            self.changed.pop(key, None)

    def anchor(self, key, tag, channel):
        journal = self.adapter.journal
        return next((post for _, ch, post, mid in reversed(self.events(tag))
                     if ch == channel and journal.message_threads.get(mid) == key), None)

    async def webhook(self, channel):
        key = (_bot, str(channel.id))
        if key not in self._webhooks:
            hooks = await channel.webhooks()
            hook = next((hook for hook in hooks if hook.name == 'hejo'
                         and getattr(hook.user, 'id', None) == _bot.user.id), None)
            self._webhooks[key] = hook or await channel.create_webhook(name='hejo')
        return self._webhooks[key]

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
        from discord import AllowedMentions, File, Object, NotFound
        names = {e['id']: e['name'] for e in self.adapter.employees()}
        label = '사장' if row['role'] == 'owner' else names.get(row['employee'], row['employee'])
        title = next((line.strip()[:100] for line in row['text'].splitlines() if line.strip()), '새 대화')
        text = row['text']
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
        channel = guild.get_channel(snowflake(entry['channel']))
        webhook_key = (_bot, str(channel.id))
        hook = await self.webhook(channel)
        post = self.anchor(key, tag, entry['channel'])
        chunks = split_content(text) if text else ['']
        for chunk in chunks:
            if not self.current(tag) or key[0] not in self.rooms() or key in self.adapter.journal.deleted_threads:
                return
            args = {'content': chunk, 'username': label, 'allowed_mentions': AllowedMentions.none(), 'wait': True}
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
                post = str(result.channel.id)
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
        tasks = (self._sync_task, self._connection_task, *self.workers.values(), *self._typing_tasks)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        self.workers.clear()
        self.pending.clear()
        self._typing_tasks.clear()


class ExternalReply:
    features = {'rooms'}

    def __init__(self, bridge, event):
        self.bridge, self.event, self.failed = bridge, event, False

    async def send(self, frame):
        if frame['type'] == 'error':
            self.failed = True
            await self.bridge.notice(self.event, '지금은 받지 못했어요')
