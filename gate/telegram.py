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

log = logging.getLogger(__name__)
_telegram = None
SETTLE_SECONDS = 2.0


def platform_ready():
    return _telegram is not None and bool(getattr(_telegram, 'is_connected', False))


def attach_telegram(native, adapter):
    """Factories run before connection; never start network work here."""
    global _telegram
    _telegram = adapter
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
            if await bridge.receive_external(event) is False:
                return await original(event)
        except Exception as exc:
            log.warning('telegram_receive_failed kind=%s', type(exc).__name__)
            await bridge.notice(event, '지금은 받지 못했어요')

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
        self._topic_lock = asyncio.Lock()
        self._sync_requested = asyncio.Event()
        self._sync_task = asyncio.create_task(self._sync_worker())
        self._connection_task = asyncio.create_task(self._watch_connection())

    def _private(self):
        try:
            value = self.vault.read('telegram.json', {'pair': None, 'code': None})
            pair, code = value['pair'], value['code']
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
                'topic_problem': self.topic_problem, **({'ref': ref} if ref is not None else {})}

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
                self.vault.write('telegram.json', {'pair': None, 'code': None})
            settings = {'enabled': False}
        else:
            settings = {'enabled': frame['enabled']}
            if settings['enabled'] and not self.private()['pair']:
                await self.adapter.server.error('telegram_unpaired', ref, conn)
                return
        with self.settings_store.locked():
            self.settings_store.write('settings.json', settings)
        await self.publish(conn, ref)
        self.request_sync()

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
        else:
            topics = self.topics(tag)['topics']
            room = next((room for room, entry in topics.items()
                         if entry['topic'] == event.source.thread_id and not entry['closed']
                         and room in self.rooms()), None)
            thread = None
        if room is None:
            await self.notice(event, '앱에서 만든 방 토픽에 써 주세요')
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
            desired = self.rooms()
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

    def wake(self, key):
        pass

    def send_typing(self, key):
        pass

    async def close(self):
        tasks = (self._sync_task, self._connection_task)
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)


class ExternalReply:
    features = {'rooms'}

    def __init__(self, bridge, event):
        self.bridge, self.event, self.failed = bridge, event, False

    async def send(self, frame):
        if frame['type'] == 'error':
            self.failed = True
            await self.bridge.notice(self.event, '지금은 받지 못했어요')
