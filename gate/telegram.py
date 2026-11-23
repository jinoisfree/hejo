"""Forum second door: private ownership, topic routing and settled delivery."""
import asyncio
import hmac
import json
import logging
import os
import secrets
import time
from pathlib import Path

from .auth import AuthStore, PAIR_TTL, digest
from .context import thinking
from .files import UnknownFile

log = logging.getLogger(__name__)
_telegram = None
SETTLE_SECONDS = 2.0
TYPING_SECONDS = 4.0
MAX_SEND_FILE_BYTES = 50 * 1024 * 1024


def platform_ready():
    return _telegram is not None and bool(getattr(_telegram, 'is_connected', False))


def attach_telegram(native, adapter):
    """Factories run before connection; never start network work here."""
    global _telegram
    _telegram = adapter
    from .telegram_comments import attach
    attach(native)
    if getattr(adapter, '_hejo_telegram_wrapped', False):
        return
    original = adapter.handle_message

    async def handle(event):
        from .adapter import _primary
        bridge = getattr(_primary, 'telegram', None)
        try:
            claimed = bridge is not None and bridge.claims_external(event)
        except Exception:
            log.warning('telegram_claim_failed')
            claimed = False
        if not claimed:
            return await original(event)
        try:
            accepted = await bridge.receive_external(event)
        except Exception as exc:
            log.warning('telegram_receive_failed kind=%s', type(exc).__name__)
            await bridge.notice(event, '지금은 받지 못했어요')
            return
        if accepted is False:
            return await original(event)

    adapter.handle_message = handle
    adapter._hejo_telegram_wrapped = True


class Telegram:
    def __init__(self, adapter, home, clock=time.time):
        self.adapter, self.clock = adapter, clock
        self.vault = AuthStore(home, clock)
        self.settings_store = AuthStore(home, clock)
        self.settings_store.path = Path(home) / 'shared' / 'hejo' / 'telegram'
        self.topic_problem = False
        self.settle_seconds = SETTLE_SECONDS
        self.pending, self.changed, self.workers, self.wakes = {}, {}, {}, {}
        self._typing_tasks, self._typing_at = set(), {}
        self.incoming = {}
        self.sent = {}
        self.sent_epochs = {}
        self.sent_path = self.settings_store.path / 'sent.jsonl'
        self._load_sent()
        from .telegram_comments import Comments
        self.comments = Comments(self)
        self._topic_lock = asyncio.Lock()
        self._sync_requested = asyncio.Event()
        self._sync_task = asyncio.create_task(self._sync_worker())
        self._connection_task = asyncio.create_task(self._watch_connection())

    def _private(self):
        try:
            value = self.vault.read('telegram.json', {'pair': None, 'code': None})
            if not isinstance(value, dict):
                return None
            pair, code = value.setdefault('pair', None), value.setdefault('code', None)
            if pair is not None and not (isinstance(pair, dict) and pair.get('platform') == 'telegram'
                    and all(isinstance(pair.get(k), str) for k in ('chat_id', 'user_id', 'tag'))
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
        return bool(self.adapter.is_connected and platform_ready() and self.private()['pair']
                    and self.settings()['enabled'])

    def status(self, ref=None):
        return {'v': 1, 'type': 'telegram_status', 'platform_ready': platform_ready(),
                'paired': self.private()['pair'] is not None, **self.settings(),
                'topic_problem': self.topic_problem or any(self.comments.route(room) == 'paused' for room in self.rooms()), **({'ref': ref} if ref is not None else {})}

    async def publish(self, conn=None, ref=None):
        status = self.status()
        for peer in tuple(self.adapter.server.connections):
            if 'telegram' in peer.features:
                await peer.send({**status, **({'ref': ref} if peer is conn and ref is not None else {})})

    async def command(self, frame, conn):
        kind, ref = frame['type'], frame['id']
        if 'telegram' not in conn.features:
            await self.adapter.server.error('unexpected_frame', ref, conn)
            return
        if kind == 'telegram':
            self.request_sync()
            await conn.send(self.status(ref))
            return
        if kind == 'telegram_pair':
            if not platform_ready():
                await self.adapter.server.error('telegram_unavailable', ref, conn)
                return
            code = secrets.token_urlsafe(9)
            with self.vault.locked():
                value = self.private()
                value['code'] = {'hash': digest(code), 'expires': self.clock() + PAIR_TTL, 'used': False}
                self.vault.write('telegram.json', value)
            await conn.send({'v': 1, 'type': 'telegram_code', 'ref': ref, 'code': code, 'expires_in': PAIR_TTL})
            return
        if kind == 'telegram_unpair':
            with self.vault.locked():
                value = self.private()
                self.retire_comments(value)
                value.update(pair=None, code=None)
                self.vault.write('telegram.json', value)
            settings = {'enabled': False}
        else:
            settings = {'enabled': frame['enabled']}
            if settings['enabled'] and not self.private()['pair']:
                await self.adapter.server.error('telegram_unpaired', ref, conn)
                return
        with self.settings_store.locked():
            self.settings_store.write('settings.json', settings)
        if not settings['enabled']:
            self.comments.cancel_queued()
        await self.publish(conn, ref)
        self.request_sync()

    def retire_comments(self, value):
        for binding in value.get('comments', []):
            if binding['state'] != 'retired':
                binding['state'] = 'retired'
                for room in self.comments.member_rooms(binding):
                    value.setdefault('route_epochs', {})[room] = {
                        'epoch': secrets.token_hex(16), 'cutover_seq': self.adapter.journal.head}

    def pending_code(self, event, private):
        code = private.get('code')
        return bool(code and not code['used'] and self.clock() < code['expires']
                    and hmac.compare_digest(code['hash'], digest(event.text.strip())))

    def claims_external(self, event):
        source = event.source
        if (not self.adapter.is_connected or not platform_ready() or source is None
                or getattr(source.platform, 'value', source.platform) != 'telegram'
                or source.chat_type not in {'group', 'forum'}):
            return False
        private = self._private()
        if private is None or self._settings() is None:
            return False
        code = private['code']
        if code and hmac.compare_digest(code['hash'], digest(event.text.strip())):
            return bool(self.pending_code(event, private)
                        and getattr(getattr(event.raw_message, 'chat', None), 'is_forum', False)
                        and _telegram._is_sender_authorized(source.user_id, source.chat_type, source.chat_id) is not False)
        pair = private['pair']
        return bool(self.active() and pair['chat_id'] == source.chat_id and pair['user_id'] == source.user_id)

    async def notice(self, event, text):
        try:
            result = await _telegram.send(event.source.chat_id, text, metadata={'thread_id': event.source.thread_id})
            if not result.success:
                log.warning('telegram_notice_failed')
        except Exception as exc:
            log.warning('telegram_notice_failed kind=%s', type(exc).__name__)

    async def receive_external(self, event):
        with self.vault.locked():
            # Recheck ownership while consuming: another admission may have used the code.
            if not self.claims_external(event):
                return False
            private = self.private()
            pairing = self.pending_code(event, private)
            if pairing:
                self.retire_comments(private)
                private['pair'] = {'platform': 'telegram', 'chat_id': event.source.chat_id,
                                   'user_id': event.source.user_id, 'tag': secrets.token_hex(4), 'paired_at': self.clock()}
                private['code']['used'] = True
                self.vault.write('telegram.json', private)
        accept = getattr(_telegram, '_accept_update', None)
        if accept:
            accept()
        if pairing:
            await self.notice(event, '연결됐어요')
            await self.publish()
            self.request_sync()
            return
        # Duplicate admission precedes file staging as well as receive().
        tag = self.private()['pair']['tag']
        client_id = f'telegram:{tag}:{event.message_id}'
        if any(row.get('client_msg_id') == client_id for row in self.adapter.journal.records):
            return
        reply_to = event.reply_to_message_id
        raw_reply = getattr(event.raw_message, 'reply_to_message', None)
        if reply_to == event.source.thread_id or getattr(raw_reply, 'forum_topic_created', None):
            reply_to = None
        target = self.reply_thread(reply_to, tag)
        if target:
            room, thread = target
            topic = self.topics(tag)['topics'].get(room)
            if not topic or topic['topic'] != event.source.thread_id:
                return
        else:
            topics = self.topics(tag)['topics']
            room = next((room for room, entry in topics.items()
                         if entry['topic'] == event.source.thread_id and not entry['closed']
                         and room in self.rooms()), None)
            thread = None
        if room is None:
            await self.notice(event, '앱에서 만든 방 토픽에 써 주세요')
            return
        if self.comments.route(room) == 'comments':
            await self.comments.forum_input(event.raw_message, room)
            return
        if self.comments.route(room) != 'topic':
            return
        text = (getattr(event.raw_message, 'caption', None) or '') if any(event.media_text_inlined or []) else event.text
        from .server import LIMITS
        if not event.message_id or len(text.encode()) > LIMITS['text_bytes']:
            await self.notice(event, '지금은 받지 못했어요')
            return
        group = self.adapter.journal.rooms.get(room)
        employee = group['lead'] if group else room
        files = []
        for path in event.media_urls:
            staged = await self.adapter.files.copy(employee, path)
            files.append(staged['file_id'])
        frame = {'employee': employee, 'thread': thread, 'text': text, 'client_msg_id': client_id,
                 'files': files, **({'room': room} if group else {})}
        if self.comments.route(room) != 'topic':
            return
        reply = ExternalReply(self, event)
        received = await self.adapter.receive(frame, reply)
        if not received and not reply.failed:
            await reply.send({'type': 'error'})

    def rooms(self):
        return {**{e['id']: e['name'] for e in self.adapter.employees()},
                **{room['id']: room['title'] for room in self.adapter.journal.rooms.values()
                   if not room.get('archived') and room['id'] not in self.adapter.journal.deleted_rooms}}

    def topics(self, tag):
        empty = {'tag': tag, 'topics': {}}
        try:
            value = self.settings_store.read('topics.json', empty)
            if value['tag'] != tag:
                return empty
            entries = value['topics']
            if not isinstance(entries, dict) or not all(isinstance(room, str) and isinstance(entry, dict)
                    and isinstance(entry['topic'], str) and isinstance(entry['name'], str)
                    and type(entry['closed']) is bool for room, entry in entries.items()):
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
                previous = state
                await self.publish()
                self.request_sync()
            await asyncio.sleep(.25)

    async def _sync_worker(self):
        while True:
            await self._sync_requested.wait()
            self._sync_requested.clear()
            await self.sync_topics()

    async def sync_topics(self):
        async with self._topic_lock:
            if not self.active():
                return
            pair = self.private()['pair']
            tag = pair['tag']
            value = self.topics(tag)
            rooms = self.rooms()
            desired = rooms
            problem = False
            for room in dict.fromkeys([*desired, *value['topics']]):
                if not self.active() or self.private()['pair']['tag'] != tag:
                    return
                entry = value['topics'].get(room)
                try:
                    bot = _telegram._bot
                    if entry is None:
                        result = await bot.create_forum_topic(chat_id=pair['chat_id'], name=desired[room])
                        entry = {'topic': str(result.message_thread_id), 'name': desired[room], 'closed': False}
                    else:
                        args = {'chat_id': pair['chat_id'], 'message_thread_id': entry['topic']}
                        closed = room not in desired
                        if not closed and entry['name'] != desired[room]:
                            await bot.edit_forum_topic(**args, name=desired[room])
                            entry['name'] = desired[room]
                        if entry['closed'] != closed:
                            await (bot.close_forum_topic if closed else bot.reopen_forum_topic)(**args)
                            entry['closed'] = closed
                    # Pair replacement or disabling during I/O must not publish stale state.
                    if not self.active() or self.private()['pair']['tag'] != tag:
                        return
                    value['topics'][room] = entry
                    with self.settings_store.locked():
                        self.settings_store.write('topics.json', value)
                except Exception as exc:
                    log.warning('telegram_topic_failed kind=%s', type(exc).__name__)
                    problem = True
            if self.topic_problem != problem:
                self.topic_problem = problem
                await self.publish()

    def reply_thread(self, tg_id, tag):
        if not tg_id:
            return None
        journal = self.adapter.journal
        msg_id = next((row['msg_id'] for row in journal.records
                       if row.get('client_msg_id') == f'telegram:{tag}:{tg_id}'), None)
        msg_id = msg_id or getattr(self, 'sent', {}).get((tag, tg_id))
        key = journal.message_threads.get(msg_id)
        if (not key or not journal.message(msg_id) or key in journal.deleted_threads or key[0] not in self.rooms()):
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
                and self.comments.route(key[0]) in {'topic', 'comments'}
                and (row['role'] == 'employee' or not row.get('client_msg_id', '').startswith('telegram:')
                     or (self.comments.route(key[0]) == 'comments'
                         and ':forum:' in row.get('client_msg_id', '')))):
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
                    log.warning('telegram_send_failed kind=%s', type(exc).__name__)
        finally:
            self.pending.pop(key, None)
            self.workers.pop(key, None)
            self.wakes.pop(key, None)
            self.changed.pop(key, None)

    def anchor(self, key, tag):
        by_message = {}
        epoch = self.comments.epoch(key[0])
        for (sent_tag, tg_id), msg_id in self.sent.items():
            if sent_tag == tag and self.sent_epochs.get((sent_tag, tg_id), 'legacy') == epoch:
                by_message.setdefault(msg_id, tg_id)
        prefix = f'telegram:{tag}:'
        for row in self.adapter.journal.records:
            if self.adapter.journal.message_threads.get(row.get('msg_id')) == key:
                client_id = row.get('client_msg_id', '')
                if epoch == 'legacy' and client_id.startswith(prefix):
                    return client_id[len(prefix):]
                if row.get('msg_id') in by_message:
                    return by_message[row['msg_id']]
        return None

    async def _send_message(self, msg_id, key, tag):
        row = self.adapter.journal.message(msg_id)
        if (not row or thinking(row['text']) or not self.active() or key[0] not in self.rooms()
                or key in self.adapter.journal.deleted_threads or self.private()['pair']['tag'] != tag):
            return
        route = self.comments.route(key[0])
        if route == 'comments':
            await self.comments.deliver(row, key, tag)
            return
        if route != 'topic' or not self.comments.new_since_cutover(key[0], msg_id):
            return
        entry = self.topics(tag)['topics'].get(key[0])
        if not entry:
            await self.sync_topics()
            entry = self.topics(tag)['topics'].get(key[0])
        if (not entry or entry['closed'] or not self.active() or self.private()['pair']['tag'] != tag
                or key[0] not in self.rooms()):
            return
        row = await self.settled_row(msg_id, key, tag)
        if not row:
            return
        pair = self.private()['pair']
        text, attachments = self.render(row)
        if not self.anchor(key, tag) and self.comments.continuation(*key):
            text = '이전 대화 이어쓰기 — 전환 이후 내용\n' + text
        metadata = {'thread_id': entry['topic']}
        if row['role'] == 'employee':
            metadata['notify'] = True
        result = await _telegram.send(pair['chat_id'], text, reply_to=self.anchor(key, tag), metadata=metadata)
        if not result.success:
            raise OSError('send_failed')
        ids = self.result_ids(result)
        for tg_id in ids:
            self._save_sent(tag, tg_id, msg_id)
        for path, mime in attachments:
            if not self.active() or self.private()['pair']['tag'] != tag:
                return
            try:
                send = _telegram.send_image_file if mime.startswith('image/') else _telegram.send_document
                result = await send(pair['chat_id'], str(path), reply_to=ids[0] if ids else None, metadata=metadata)
                if not result.success:
                    raise OSError('send_failed')
                for tg_id in self.result_ids(result):
                    self._save_sent(tag, tg_id, msg_id)
            except Exception as exc:
                log.warning('telegram_file_send_failed kind=%s', type(exc).__name__)

    async def settled_row(self, msg_id, key, tag):
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
            return row

    def render(self, row):
        names = {e['id']: e['name'] for e in self.adapter.employees()}
        label = '사장' if row['role'] == 'owner' else names.get(row['employee'], row['employee'])
        text = f"[{label}] " + row['text']
        buttons = row.get('buttons', [])
        replies = [b['label'] for b in buttons if b['kind'] == 'reply']
        if replies:
            text += '\n선택: ' + ' / '.join(replies)
        if any(b['kind'] != 'reply' for b in buttons):
            text += '\n(이 선택은 hejo 앱에서 눌러 주세요)'
        attachments = []
        for file in row.get('files', []):
            try:
                path, mime = self.adapter.files.registered(row['employee'], file['file_id'])
                if path.stat().st_size > MAX_SEND_FILE_BYTES:
                    raise ValueError('too_large')
                attachments.append((path, mime))
            except (UnknownFile, OSError, ValueError):
                text += f"\n📎 {file['name']} (hejo 앱에서 열기)"
        return text, attachments

    @staticmethod
    def result_ids(result):
        raw = result.raw_response
        values = raw.get('message_ids') if isinstance(raw, dict) else None
        return [str(value) for value in (values or ([result.message_id] if result.message_id else []))]

    def _load_sent(self):
        try:
            raw = self.sent_path.read_bytes()
        except OSError:
            return
        lines = raw.splitlines(keepends=True)
        for line in lines:
            try:
                row = json.loads(line) if line.endswith(b'\n') else None
                if (isinstance(row, dict) and set(row) == {'tag', 'tg', 'msg_id'}
                        and all(isinstance(value, str) for value in row.values())):
                    self.sent[(row['tag'], row['tg'])] = row['msg_id']
                elif (isinstance(row, dict) and row.get('v') == 2 and row.get('kind') == 'topic'
                      and set(row) == {'v', 'kind', 'tag', 'tg', 'msg_id', 'route_epoch'}
                      and all(isinstance(row[k], str) for k in ('tag', 'tg', 'msg_id', 'route_epoch'))):
                    self.sent[(row['tag'], row['tg'])] = row['msg_id']
                    self.sent_epochs[(row['tag'], row['tg'])] = row['route_epoch']
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
            log.warning('telegram_sent_read_failed')

    def _save_sent(self, tag, tg_id, msg_id):
        key = self.adapter.journal.message_threads.get(msg_id)
        epoch = self.comments.epoch(key[0]) if key else 'legacy'
        receipt = {'tag': tag, 'tg': tg_id, 'msg_id': msg_id}
        if epoch != 'legacy':
            receipt.update(v=2, kind='topic', route_epoch=epoch)
        with self.settings_store.locked():
            created = not self.sent_path.exists()
            fd = os.open(self.sent_path, os.O_CREAT | os.O_WRONLY | os.O_APPEND, 0o600)
            try:
                os.fchmod(fd, 0o600)
                with os.fdopen(fd, 'ab', closefd=False) as stream:
                    stream.write((json.dumps(receipt) + '\n').encode())
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
        self.sent[(tag, tg_id)] = msg_id
        self.sent_epochs[(tag, tg_id)] = epoch

    def send_typing(self, key):
        if not self.active() or key[0] not in self.rooms() or self.comments.route(key[0]) != 'topic':
            return
        pair = self.private()['pair']
        entry = self.topics(pair['tag'])['topics'].get(key[0])
        if not entry or entry['closed']:
            return
        throttle = (pair['tag'], entry['topic'])
        now = asyncio.get_running_loop().time()
        if now - self._typing_at.get(throttle, float('-inf')) < TYPING_SECONDS:
            return
        self._typing_at[throttle] = now
        phone = _telegram
        async def request():
            try:
                await phone.send_typing(pair['chat_id'], metadata={'thread_id': entry['topic']})
            except Exception as exc:
                log.warning('telegram_typing_failed kind=%s', type(exc).__name__)
        task = asyncio.create_task(request())
        self._typing_tasks.add(task)
        task.add_done_callback(self._typing_tasks.discard)

    async def close(self):
        await self.comments.close()
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
