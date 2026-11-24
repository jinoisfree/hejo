"""Channel comments owned by the existing Telegram door and journal."""
import asyncio
import hashlib
import json
import os
import re
import secrets
import uuid
import tempfile
import shutil
from pathlib import Path
from urllib.parse import urlsplit

CONTRACT = 'hejo-comments-probe-1'
PROBE_SECONDS = 60
_native_bot = None
COMMAND = re.compile(r'/hejo_comments_(rooms|probe|bind|add|status|resolve|off|abort)(?: ([^\n]+))?\Z')


class Rejected(Exception):
    pass


class Comments:
    def __init__(self, bridge):
        self.bridge = bridge
        self.lock = asyncio.Lock()
        self.tasks = set()
        self.receipts = {}
        self.records = []
        self.operations = {}
        self.forwards = []
        self.inflight = set()
        self.output_locks = {}
        self.damaged = False
        self._load()
        for probe in self.bridge.private().get('probes', []):
            if probe['state'] == 'pending' and not self.damaged:
                self.schedule_expiry(probe)

    def _load(self):
        try:
            lines = self.bridge.sent_path.read_bytes().splitlines(keepends=True)
        except FileNotFoundError:
            return
        for line in lines:
            if not line.endswith(b'\n'):
                continue  # Telegram's existing loader truncates the incomplete tail.
            try:
                row = json.loads(line)
                if set(row) == {'tag', 'tg', 'msg_id'}:
                    continue
                if row.get('v') == 2 and row.get('kind') == 'topic':
                    if (set(row) != {'v', 'kind', 'tag', 'tg', 'msg_id', 'route_epoch'}
                            or not all(isinstance(row[k], str) for k in ('tag', 'tg', 'msg_id', 'route_epoch'))):
                        raise ValueError('topic_record')
                    continue
                if row.get('v') in {2, 3} and row.get('kind') == 'delivery':
                    self.validate_delivery(row)
                    self.validate_transition(row)
                    self.operations[row['operation']] = row
                    continue
                if row.get('v') == 2 and row.get('kind') == 'forward':
                    if (set(row) != {'v', 'kind', 'binding', 'generation', 'origin', 'message_id'}
                            or not isinstance(row['binding'], str)
                            or any(type(row[k]) is not int or row[k] <= 0 for k in ('generation', 'origin', 'message_id'))):
                        raise ValueError('forward_record')
                    self.forwards.append(row)
                    continue
                if row.get('v') in {2, 3} and row.get('kind') in {'input', 'alias'}:
                    self.validate_record(row)
                    self.validate_alias(row)
                    self.records.append(row)
                    continue
                if (row.get('v') != 2 or row.get('kind') != 'probe'
                        or row.get('step') not in {'channel', 'forward', 'comment'}
                        or not isinstance(row.get('probe'), str)
                        or type(row.get('message_id')) is not int or row['message_id'] <= 0
                        or type(row.get('at')) not in (int, float)):
                    raise ValueError('receipt')
                key = (row['probe'], row['step'])
                if key in self.receipts and self.receipts[key] != row:
                    raise ValueError('duplicate')
                self.receipts[key] = row
            except (ValueError, TypeError, AttributeError, KeyError):
                self.damaged = True

    def save_receipt(self, tag, step, message_id):
        if type(message_id) is not int or message_id <= 0:
            raise Rejected('invalid_receipt')
        row = dict(v=2, kind='probe', probe=tag, step=step,
                   message_id=message_id, at=self.bridge.clock())
        self.append_record(row)
        self.receipts[tag, step] = row

    def append_record(self, row):
        with self.bridge.settings_store.locked():
            fd = os.open(self.bridge.sent_path, os.O_CREAT | os.O_APPEND | os.O_WRONLY, 0o600)
            try:
                os.fchmod(fd, 0o600)
                with os.fdopen(fd, 'ab', closefd=False) as stream:
                    stream.write((json.dumps(row) + '\n').encode())
                    stream.flush()
                    os.fsync(fd)
            finally:
                os.close(fd)
            directory = os.open(self.bridge.settings_store.path, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)

    def private(self):
        value = self.bridge.private()
        if value.get('comments_version', 1) not in {1, 2} or self.damaged:
            raise Rejected('comments_unavailable')
        return value

    def rooms(self):
        return self.bridge.rooms()

    def recipient(self, room):
        if room not in self.rooms():
            raise Rejected('unknown_room')
        group = self.bridge.adapter.journal.rooms.get(room)
        employee = group['lead'] if group else room
        if (employee not in {e['id'] for e in self.bridge.adapter.employees()}
                or group and employee not in group['members']):
            raise Rejected('unknown_employee')
        return employee

    def command(self, message):
        pair = self.bridge.private().get('pair')
        user = message.from_user
        if (not pair or not user or str(user.id) != pair['user_id'] or user.is_bot
                or message.sender_chat or message.forward_origin):
            return None
        match = COMMAND.fullmatch(message.text or '')
        if not match:
            return None
        name, room = match.groups()
        if name == 'status':
            registered = any(str(message.chat_id) == c['discussion_id'] and c['pair'] == pair['tag']
                             and c['owner_id'] == pair['user_id'] for c in self.bridge.private().get('comments', []))
            return (name, None) if room is None and (registered or str(message.chat_id) == pair['chat_id']) else None
        if name == 'abort':
            return (name, None) if room is None and str(message.chat_id) == pair['chat_id'] else None
        if name == 'off':
            return (name, None) if room is None and self.reserved(self.bridge.private(), message) else None
        if name == 'rooms':
            return (name, None) if room is None and str(message.chat_id) == pair['chat_id'] else None
        return (name, room) if room and message.chat.type == 'supergroup' else None

    def claims(self, update):
        message = getattr(update, "effective_message", None)
        if message is None:
            return False
        value = self.bridge.private()
        return self.reserved(value, message) or self.forum_room(message) is not None or bool(update.message and self.command(message))

    def forum_room(self, message):
        pair = self.bridge.private().get('pair')
        if not pair or str(message.chat_id) != pair['chat_id']:
            return None
        topics = self.bridge.topics(pair['tag'])['topics']
        return next((room for room, topic in topics.items()
                     if str(message.message_thread_id) == topic['topic']
                     and not topic['closed'] and self.route(room) != 'topic'), None)

    @staticmethod
    def reserved(value, message):
        return bool(message and any(str(message.chat_id) in {item.get('channel_id'), item.get('discussion_id')}
            for item in [*value.get('probes', []), *value.get('comments', [])]))

    @staticmethod
    def member_rooms(binding):
        return binding.get('rooms', [binding['room']] if 'room' in binding else [])

    def hub(self):
        value = self.private()
        active = [b for b in value.get('comments', []) if b['state'] != 'retired']
        if not active:
            return None
        if value.get('comments_version') != 2 or len(active) != 1 or 'rooms' not in active[0]:
            raise Rejected('migration_required')
        return active[0]

    def binding_for(self, room):
        hub = self.hub()
        if not hub or room not in hub['rooms']:
            return None
        return dict(hub, room=room)

    def route(self, room):
        value = self.bridge.private()
        entries = [item for item in value.get('comments', []) if room in self.member_rooms(item)
                   and item['state'] != 'retired']
        if not entries:
            return 'topic'
        if value.get('comments_version') != 2 or self.damaged or len(entries) != 1:
            return 'paused'
        pair = value.get('pair')
        item = entries[0]
        return 'comments' if (pair and item['pair'] == pair['tag']
                              and item['state'] == 'active' and 'rooms' in item) else 'paused'

    async def validate(self, bot, discussion_id, room, pair):
        if room not in self.rooms():
            raise Rejected('unknown_room')
        url = urlsplit(str(bot.base_url))
        if url.scheme != 'https' or url.netloc != 'api.telegram.org' or not url.path.startswith('/bot'):
            raise Rejected('unsupported_endpoint')
        me = await bot.get_me()
        discussion = await bot.get_chat(discussion_id)
        if discussion.type != 'supergroup' or discussion.is_forum or not discussion.linked_chat_id:
            raise Rejected('invalid_discussion')
        channel = await bot.get_chat(discussion.linked_chat_id)
        if channel.type != 'channel' or channel.linked_chat_id != discussion.id:
            raise Rejected('invalid_channel')
        for chat in (channel, discussion):
            if chat.username or getattr(chat, 'active_usernames', None):
                raise Rejected('public_chat')
            admins = await bot.get_chat_administrators(chat.id, api_kwargs={'return_bots': True})
            if {str(a.user.id) for a in admins} != {pair['user_id'], str(me.id)}:
                raise Rejected('unexpected_admin')
            owner = next(a for a in admins if str(a.user.id) == pair['user_id'])
            own = next(a for a in admins if a.user.id == me.id)
            if owner.status != 'creator' or owner.user.is_bot or own.status != 'administrator':
                raise Rejected('missing_permission')
            if chat is channel and not own.can_post_messages:
                raise Rejected('missing_permission')
        return dict(bot_id=str(me.id), channel_id=str(channel.id), discussion_id=str(discussion.id),
                    owner_id=pair['user_id'], pair=pair['tag'], room=room, contract=CONTRACT)

    def available(self, value, identity):
        for item in value.get('comments', []):
            overlap = {item['channel_id'], item['discussion_id']} & {identity['channel_id'], identity['discussion_id']}
            if item['state'] == 'retired':
                if overlap:
                    raise Rejected('target_reserved')
                continue
            if value.get('comments_version') != 2 or 'rooms' not in item:
                raise Rejected('migration_required')
            if not overlap or any(item.get(k) != identity[k] for k in
                                  ('bot_id', 'channel_id', 'discussion_id', 'owner_id', 'pair', 'contract')):
                raise Rejected('hub_bound')

    def busy(self, room):
        bridge = self.bridge
        adapter = bridge.adapter
        group = adapter.journal.rooms.get(room)
        chat = 'room:' + room if group else room
        for scope, thread in set(adapter.journal.message_threads.values()):
            if scope != room:
                continue
            source = adapter.build_source(chat_id=chat, chat_type='dm', user_id='owner', thread_id=thread)
            for employee in group['members'] if group else [room]:
                source.profile = employee
                if adapter._source_session_key(source) in adapter._active_sessions:
                    return True
        return (bool(bridge.incoming.get(room)) or bool(bridge.adapter._typing_threads.get(chat))
                or any(key[0] == room for key in bridge.pending)
                or any(key[0] == room for key in bridge.workers))

    def current(self, identity):
        value = self.private()
        pair = value.get('pair')
        if not self.bridge.settings()['enabled']:
            raise Rejected('disabled')
        if not pair or pair['tag'] != identity['pair'] or pair['user_id'] != identity['owner_id']:
            raise Rejected('pair_changed')
        if identity['room'] not in self.rooms():
            raise Rejected('unknown_room')
        self.available(value, identity)
        return value

    def complete(self, probe):
        rows = [self.receipts.get((probe['tag'], step)) for step in ('channel', 'forward', 'comment')]
        return (probe['state'] == 'complete' and probe['contract'] == CONTRACT
                and all(row and row['at'] <= probe['deadline'] for row in rows))

    def write_probe(self, tag, **changes):
        with self.bridge.vault.locked():
            value = self.private()
            probe = next(p for p in value['probes'] if p['tag'] == tag)
            probe.update(changes)
            self.bridge.vault.write('telegram.json', value)
            return probe

    def schedule_expiry(self, probe):
        task = asyncio.create_task(self.expire(probe['tag'], probe['deadline']))
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)

    async def expire(self, tag, deadline):
        await asyncio.sleep(max(0, deadline - self.bridge.clock()))
        async with self.lock:
            value = self.private()
            probe = next(p for p in value.get('probes', []) if p['tag'] == tag)
            if probe['state'] == 'pending' and self.bridge.clock() >= deadline:
                self.write_probe(tag, state='timed_out')

    async def probe(self, bot, identity):
        value = self.current(identity)
        if any(p['state'] == 'pending' and all(p.get(k) == v for k, v in identity.items())
               and p['deadline'] > self.bridge.clock() for p in value.get('probes', [])):
            raise Rejected('probe_busy')
        probe = dict(identity, tag=secrets.token_hex(16), state='pending',
                     probe_reserved=True, deadline=self.bridge.clock() + PROBE_SECONDS)
        with self.bridge.vault.locked():
            value = self.current(identity)
            for old in value.setdefault('probes', []):
                if old['state'] == 'pending' and old['deadline'] <= self.bridge.clock():
                    old['state'] = 'timed_out'
            value.setdefault('comments_version', 1)
            value['probes'].append(probe)
            self.bridge.vault.write('telegram.json', value)
        self.schedule_expiry(probe)
        try:
            result = await bot.send_message(identity['channel_id'], '댓글 연결 확인용 — 직원 실행 없음')
            self.save_receipt(probe['tag'], 'channel', result.message_id)
        except Exception:
            self.write_probe(probe['tag'], state='unknown')
            raise

    async def bind(self, identity, rooms=None):
        rooms = sorted(set(rooms or [identity['room']]))
        if not rooms or any(room not in self.rooms() for room in rooms):
            raise Rejected('unknown_room')
        for room in rooms:
            self.recipient(room)
        async with self.bridge._topic_lock:
            with self.bridge.vault.locked():
                value = self.current(identity)
                existing = self.hub()
                if existing:
                    if existing['rooms'] != rooms:
                        raise Rejected('hub_bound')
                    return 'already_bound'
                if any(self.busy(room) for room in rooms):
                    raise Rejected('busy')
                probe = next((p for p in reversed(value.get('probes', []))
                              if all(p.get(k) == v for k, v in identity.items() if k != 'room')
                              and self.complete(p)), None)
                if not probe:
                    raise Rejected('probe_required')
                hub = {k: v for k, v in identity.items() if k != 'room'}
                hub.update(binding=secrets.token_hex(16), generation=1, rooms=rooms,
                           activated_at=self.bridge.clock(), state='active')
                value.setdefault('comments', []).append(hub)
                value['comments_version'] = 2
                for room in rooms:
                    value.setdefault('route_epochs', {})[room] = dict(
                        epoch=secrets.token_hex(16), cutover_seq=self.bridge.adapter.journal.head)
                self.bridge.vault.write('telegram.json', value)
        self.bridge.request_sync()
        return 'bound'

    async def add_rooms(self, identity, rooms):
        async with self.bridge._topic_lock:
            with self.bridge.vault.locked():
                value = self.current(identity)
                hub = self.hub()
                if (not hub or hub['state'] != 'active'
                        or any(hub.get(k) != v for k, v in identity.items() if k != 'room')):
                    raise Rejected('binding_changed')
                added = sorted(set(rooms) - set(hub['rooms']))
                for room in rooms:
                    self.recipient(room)
                if not added:
                    return 'already_bound'
                if (any(self.busy(room) for room in [*hub['rooms'], *added])
                        or self.unresolved(hub) or self.inflight):
                    raise Rejected('busy')
                current = next(b for b in value['comments'] if b['binding'] == hub['binding'])
                current['rooms'] = sorted([*hub['rooms'], *added])
                for room in added:
                    value.setdefault('route_epochs', {})[room] = dict(
                        epoch=secrets.token_hex(16), cutover_seq=self.bridge.adapter.journal.head)
                self.bridge.vault.write('telegram.json', value)
        self.bridge.request_sync()
        return 'added'

    async def forward(self, bot, update):
        message = update.message
        if not message or not message.is_automatic_forward or not message.sender_chat:
            return
        origin = message.forward_origin
        if not origin or origin.type != 'channel':
            return
        for probe in reversed(self.private().get('probes', [])):
            if (probe['state'] != 'pending' or str(message.chat_id) != probe['discussion_id']
                    or str(message.sender_chat.id) != probe['channel_id']
                    or str(origin.chat.id) != probe['channel_id']):
                continue
            if self.bridge.clock() >= probe['deadline']:
                self.write_probe(probe['tag'], state='timed_out')
                continue
            receipt = self.receipts.get((probe['tag'], 'channel'))
            if not receipt or origin.message_id != receipt['message_id']:
                continue
            if not self.bridge.settings()['enabled']:
                return
            identity = await self.validate(bot, probe['discussion_id'], probe['room'], self.private()['pair'])
            self.current(identity)
            if self.bridge.clock() >= probe['deadline']:
                self.write_probe(probe['tag'], state='timed_out')
                return
            if any(probe.get(k) != v for k, v in identity.items()):
                return
            from telegram import ReplyParameters
            try:
                self.save_receipt(probe['tag'], 'forward', message.message_id)
                result = await bot.send_message(probe['discussion_id'], '댓글 연결 확인용 — 직원 실행 없음',
                    reply_parameters=ReplyParameters(message.message_id, allow_sending_without_reply=False))
                self.save_receipt(probe['tag'], 'comment', result.message_id)
                state = 'complete' if self.bridge.clock() <= probe['deadline'] else 'timed_out'
                self.current(identity)
                self.write_probe(probe['tag'], state=state)
            except Exception:
                self.write_probe(probe['tag'], state='unknown')
                raise
            return

    async def check_binding(self, bot, message):
        value = self.private()
        binding = next((c for c in value.get('comments', [])
                        if str(message.chat_id) in {c['channel_id'], c['discussion_id']}
                        and c['state'] == 'active'), None)
        if not binding:
            return
        await self.validate_binding(bot, binding)

    async def validate_binding(self, bot, binding):
        try:
            available_room = next(room for room in self.member_rooms(binding) if room in self.rooms())
            identity = await self.validate(bot, binding['discussion_id'], available_room, self.private()['pair'])
            self.current(identity)
            if any(binding.get(k) != v for k, v in identity.items() if k != 'room'):
                raise Rejected('binding_changed')
        except Exception:
            with self.bridge.vault.locked():
                current = self.private()
                for item in current.get('comments', []):
                    if item['binding'] == binding['binding'] and item['state'] == 'active':
                        item['state'] = 'paused'
                self.bridge.vault.write('telegram.json', current)
            await self.bridge.publish()
            raise

    async def handle(self, update, context):
        from .telegram import log
        async with self.lock:
            cmd = None
            result = None
            try:
                cmd = self.command(update.message) if update.message else None
                if cmd:
                    name, room = cmd
                    if name == 'status':
                        result = self.delivery_status(update.message)
                    elif name == 'resolve':
                        result = await self.resolve(context.bot, update.message, room)
                    elif name in {'off', 'abort'}:
                        result = await self.retire(update.message, room, abort=name == 'abort')
                    elif name == 'rooms':
                        result = '\n'.join(f'{key}: {name}' for key, name in self.rooms().items()) or '연결 가능한 방 없음'
                    else:
                        if not self.bridge.settings()['enabled']:
                            raise Rejected('disabled')
                        pair = self.private()['pair']
                        requested = room.split() if name in {'bind', 'add'} else [room]
                        identity = await self.validate(context.bot, update.message.chat_id, requested[0], pair)
                        if name == 'probe':
                            await self.probe(context.bot, identity)
                            result = 'probe_started: 연결 시험을 시작했습니다. 댓글 확인이 끝난 뒤 bind를 실행하세요.'
                        else:
                            status = (await self.add_rooms(identity, requested) if name == 'add'
                                      else await self.bind(identity, requested))
                            result = ('already_bound: 이미 같은 대상으로 연결되어 있습니다.'
                                      if status == 'already_bound' else 'bound: 댓글 연결을 저장했습니다.')
                elif self.forum_room(update.effective_message) is not None:
                    room = self.forum_room(update.effective_message)
                    if update.message and self.route(room) == 'comments':
                        binding = self.binding_for(room)
                        await self.validate_live(context.bot, binding)
                        await self.accept_input(context.bot, update.message, binding, 'forum')
                else:
                    await self.check_binding(context.bot, update.effective_message)
                    await self.forward(context.bot, update)
                    if not await self.delivery_forward(context.bot, update):
                        await self.ingress(context.bot, update)
            except Exception as exc:
                # Only local, allowlisted rejection codes may reach the user.
                log.warning('telegram_comments_rejected kind=%s', type(exc).__name__)
                reason = exc.args[0] if isinstance(exc, Rejected) and exc.args else None
                result = {
                    'busy': 'busy: 진행 중인 작업이 끝난 뒤 다시 연결하세요.',
                    'probe_busy': 'busy: 연결 시험이 진행 중입니다.',
                    'probe_required': 'probe_required: 완료된 연결 시험이 필요합니다.',
                    'missing_permission': 'permission_failed: 소유자와 봇의 권한을 확인하세요.',
                    'unexpected_admin': 'permission_failed: 관리자 구성을 확인하세요.',
                }.get(reason, 'rejected: 요청을 완료하지 못했습니다. 연결 조건과 권한을 확인하세요.')
            # Notification is a separate best-effort step, never an action retry.
            # Recheck ownership after API awaits; ordinary reserved input stays silent.
            if cmd and result:
                try:
                    if self.command(update.message) == cmd:
                        await context.bot.send_message(update.message.chat_id, result)
                except Exception as exc:
                    log.warning('telegram_comments_notice_failed kind=%s', type(exc).__name__)

    @staticmethod
    def validate_record(row):
        required = {'v', 'kind', 'binding', 'generation', 'route_epoch', 'side', 'message_id', 'thread', 'msg_id', 'anchor'}
        if row.get('v') == 3:
            required.add('room')
            if not isinstance(row.get('room'), str) or not row['room']:
                raise ValueError('record_room')
        if (set(row) != required or row['v'] not in {2, 3} or row['kind'] not in {'input', 'alias'}
                or row['side'] not in {'forum', 'channel', 'discussion'}
                or type(row['generation']) is not int or row['generation'] < 1
                or type(row['message_id']) is not int or row['message_id'] <= 0
                or type(row['anchor']) is not int or row['anchor'] <= 0
                or not all(isinstance(row[k], str) for k in ('binding', 'route_epoch', 'thread', 'msg_id'))
                or not all(row[k] for k in ('binding', 'route_epoch', 'thread'))):
            raise ValueError('comments_record')

    def validate_alias(self, row):
        identity = ('binding', 'generation', 'side', 'message_id')
        for old in self.records:
            if all(old[key] == row[key] for key in identity):
                if (any(old.get(key) != row.get(key) for key in ('route_epoch', 'thread', 'anchor', 'room'))
                        or (old['msg_id'] and row['msg_id'] and old['msg_id'] != row['msg_id'])):
                    raise ValueError('conflicting_alias')

    def record(self, binding, kind, side, message_id, thread, anchor, msg_id=''):
        row = dict(v=3, room=binding['room'], kind=kind, binding=binding['binding'], generation=binding['generation'],
                   route_epoch=self.epoch(binding['room']), side=side, message_id=message_id,
                   thread=thread, anchor=anchor, msg_id=msg_id)
        self.validate_record(row)
        self.validate_alias(row)
        try:
            self.append_record(row)
        except BaseException:
            self.damaged = True
            raise
        self.records.append(row)
        return row

    def epoch(self, room):
        return self.bridge.private().get('route_epochs', {}).get(room, {}).get('epoch', 'legacy')

    def lookup(self, binding, side, message_id):
        return next((r for r in reversed(self.records) if r['binding'] == binding['binding']
                     and r['generation'] == binding['generation'] and r.get('room') in binding['rooms']
                     and r['route_epoch'] == self.epoch(r['room'])
                     and ('room' not in binding or r['room'] == binding['room'])
                     and r['side'] == side and r['message_id'] == message_id), None)

    def live(self, binding):
        room = binding.get('room') or next(room for room in self.member_rooms(binding) if room in self.rooms())
        identity = dict(binding, room=room)
        value = self.current(identity)
        current = next((c for c in value.get('comments', []) if c['binding'] == binding['binding']), None)
        expected = {k: v for k, v in binding.items() if k != 'room'}
        if not current or current != expected or current['state'] != 'active':
            raise Rejected('binding_changed')
        if 'room' in binding and binding['room'] not in current['rooms']:
            raise Rejected('unknown_room')
        return current

    async def input_notice(self, bot, message):
        from .telegram import log
        try:
            await bot.send_message(message.chat_id, '입력을 받지 못했습니다. 텍스트 또는 개별 사진·문서와 답장 대상을 확인하세요.')
        except Exception as exc:
            log.warning('telegram_comments_notice_failed kind=%s', type(exc).__name__)

    async def stage_input(self, bot, message, room):
        from .files import MAX_FILE_BYTES, safe_name
        from .server import LIMITS
        text = message.text or message.caption or ''
        unsupported = any(getattr(message, key, None) for key in
                          ('media_group_id', 'audio', 'voice', 'video', 'animation', 'sticker', 'video_note',
                           'contact', 'location', 'venue', 'poll', 'dice', 'paid_media'))
        if unsupported or len(text.encode()) > LIMITS['text_bytes']:
            raise Rejected('unsupported_input')
        media = message.document or (message.photo[-1] if message.photo else None)
        if not media:
            if not text.strip():
                raise Rejected('unsupported_input')
            return text, []
        limit = min(20 * 1024 * 1024, MAX_FILE_BYTES)
        if media.file_size is None or media.file_size > limit:
            raise Rejected('unsupported_input')
        name = safe_name(message.document.file_name or 'document') if message.document else 'photo.jpg'
        remote = await bot.get_file(media.file_id)
        if remote.file_size is None or remote.file_size > limit:
            raise Rejected('unsupported_input')
        with tempfile.TemporaryDirectory(prefix='.telegram-', dir=self.bridge.adapter.files.root) as directory:
            path = Path(directory) / 'download'
            path.touch(mode=0o600)
            await remote.download_to_drive(custom_path=path)
            if path.stat().st_size > limit:
                raise Rejected('unsupported_input')
            async def chunks():
                with path.open('rb') as stream:
                    while data := stream.read(65536):
                        yield data
            staged = await self.bridge.adapter.files.stage(room, name, chunks())
        return text, [staged['file_id']]

    async def forum_input(self, message, room):
        async with self.lock:
            binding = self.binding_for(room)
            if not binding or self.route(room) != 'comments' or _native_bot is None:
                return
            await self.validate_live(_native_bot, binding)
            await self.accept_input(_native_bot, message, binding, 'forum')

    async def ingress(self, bot, update):
        message = update.message
        binding = self.hub()
        if not message or not binding or str(message.chat_id) != binding['discussion_id']:
            return
        if binding['state'] != 'active' or not self.bridge.settings()['enabled']:
            return
        await self.accept_input(bot, message, binding, 'discussion')

    async def accept_input(self, bot, message, binding, side):
        if (not message.from_user or message.from_user.is_bot or message.sender_chat
                or message.forward_origin or message.is_automatic_forward or message.external_reply
                or str(message.from_user.id) != binding['owner_id']
                or message.date.timestamp() <= binding['activated_at']):
            return
        self.live(binding)
        journal = self.bridge.adapter.journal
        reply = message.reply_to_message
        expected_chat = self.private()['pair']['chat_id'] if side == 'forum' else binding['discussion_id']
        if reply and (str(reply.chat_id) != expected_chat or reply.external_reply):
            return
        # A topic's service message is not a question reply.
        if side == 'forum' and reply and (reply.forum_topic_created or reply.message_id == message.message_thread_id):
            reply = None
        target = self.lookup(binding, side, reply.message_id) if reply else None
        if reply and not target:
            # Existing forum history remains a valid continuation, but never crosses rooms.
            key = self.bridge.reply_thread(str(reply.message_id), binding['pair']) if side == 'forum' else None
            if not key or key[0] != binding['room']:
                return
            target = dict(room=key[0], thread=key[1], anchor=message.message_id)
        if side == 'discussion':
            raw = self.lookup(binding, side, message.message_thread_id) if message.message_thread_id else None
            if (message.message_thread_id and not raw) or (raw and raw['message_id'] != raw['anchor']):
                return
            if target and raw and (target['room'], target['thread']) != (raw['room'], raw['thread']):
                return
            target = target or raw
            if (not target or not journal.message(target.get('msg_id'))
                    or journal.message_threads.get(target['msg_id']) != (target['room'], target['thread'])):
                return
            root = self.lookup(binding, side, target['anchor'])
            if not root or not journal.message(root['msg_id']):
                return
            binding = dict(binding, room=target['room'])
        thread = target['thread'] if target else str(uuid.uuid4())
        anchor = target['anchor'] if target else message.message_id
        room = binding['room']
        if (room, thread) in journal.deleted_threads or room in journal.deleted_rooms:
            return
        employee = self.recipient(room)
        group = journal.rooms.get(room)
        client_id = f"telegram:comments:{binding['binding']}:{binding['generation']}:{side}:{message.message_id}"
        existing = self.lookup(binding, side, message.message_id)
        saved = next((r for r in journal.records if r.get('client_msg_id') == client_id), None)
        if existing or saved:
            if existing and saved and not existing['msg_id']:
                self.record(binding, 'alias', side, message.message_id, existing['thread'], existing['anchor'], saved['msg_id'])
            return
        self.record(binding, 'input', side, message.message_id, thread, anchor)
        files = []
        try:
            text, files = await self.stage_input(bot, message, employee)
            self.live(binding)
            if self.recipient(room) != employee:
                raise Rejected('room_lead_changed')
            class Reply:
                features = {'rooms'}
                failed = False
                async def send(self, frame):
                    if frame['type'] == 'error':
                        self.failed = True
            result = Reply()
            await self.bridge.adapter.receive(dict(employee=employee, thread=thread, text=text,
                files=files, client_msg_id=client_id,
                **(dict(room=room, targeted=True, expected_lead=employee) if group else {})), result)
            saved = next((r for r in journal.records if r.get('client_msg_id') == client_id), None)
            if saved:
                self.record(binding, 'alias', side, message.message_id, thread, anchor, saved['msg_id'])
            elif result.failed:
                await self.input_notice(bot, message)
        except Exception:
            await self.input_notice(bot, message)
            raise
        finally:
            for file_id in files:
                path = self.bridge.adapter.files.pending(employee, file_id)
                if path.exists():
                    shutil.rmtree(path)

    @staticmethod
    def validate_delivery(row):
        fields = {'v', 'kind', 'operation', 'binding', 'generation', 'route_epoch', 'side',
                  'message_id', 'thread', 'msg_id', 'anchor', 'part', 'media', 'fingerprint', 'status', 'root'}
        if row.get('v') == 3:
            fields.add('room')
            if not isinstance(row.get('room'), str) or not row['room']:
                raise ValueError('delivery_room')
        if (set(row) != fields or row['v'] not in {2, 3} or row['kind'] != 'delivery'
                or row['status'] not in {'queued', 'intent', 'receipt', 'unknown', 'cancelled'}
                or row['side'] not in {'forum', 'channel', 'discussion'} or row['media'] not in {'text', 'photo', 'document', 'edit'}
                or row['media'] == 'edit' and (row['side'] != 'forum' or row['root'] or not row['message_id'])
                or type(row['root']) is not bool
                or any(type(row[k]) is not int or row[k] < 0 for k in ('message_id', 'anchor', 'part'))
                or type(row['generation']) is not int or row['generation'] < 1
                or any(not isinstance(row[k], str) or not row[k] for k in
                       ('operation', 'binding', 'route_epoch', 'thread', 'msg_id', 'fingerprint'))
                or (row['status'] == 'receipt' and not row['message_id'])):
            raise ValueError('delivery_record')

    def validate_transition(self, row):
        old = self.operations.get(row['operation'])
        if old:
            immutable = set(row) - {'status', 'message_id', 'anchor'}
            if (any(old[k] != row[k] for k in immutable)
                    or old['message_id'] and old['message_id'] != row['message_id']
                    or old['anchor'] and old['anchor'] != row['anchor']
                    or old['status'] == 'cancelled' and row['status'] != 'cancelled'
                    or old['status'] == 'receipt' and row['status'] not in {'receipt', 'cancelled'}):
                raise ValueError('conflicting_delivery')

    def outstanding(self, binding):
        return [r for r in self.binding_operations(binding) if r['status'] in {'queued', 'intent', 'unknown'}
                or (r['root'] and r['status'] == 'receipt' and not r['anchor'])]

    def cancel_queued(self):
        for op in list(self.operations.values()):
            if op['status'] == 'queued':
                self.delivery_record(op, status='cancelled')

    def delivery_record(self, row, **changes):
        row = {**row, **changes}
        self.validate_delivery(row)
        self.validate_transition(row)
        try:
            self.append_record(row)
        except BaseException:
            self.damaged = True
            raise
        self.operations[row['operation']] = row
        return row

    def binding_operations(self, binding):
        return [r for r in self.operations.values() if r['binding'] == binding['binding']
                and r['generation'] == binding['generation']]

    def unresolved(self, binding):
        return [r for r in self.binding_operations(binding) if r['status'] in {'intent', 'unknown'}]

    def thread_anchor(self, binding, thread):
        rows = [r for r in self.records if r['binding'] == binding['binding']
                and r['generation'] == binding['generation'] and r['route_epoch'] == self.epoch(binding['room'])
                and r.get('room') == binding['room'] and r['thread'] == thread and r['side'] == 'discussion']
        return rows[0] if rows else None

    async def validate_live(self, bot, binding):
        # Same ownership contract at both input and output boundaries.
        await self.validate_binding(bot, binding)
        self.live(binding)

    def parts(self, row, continuation=False):
        text, attachments = self.bridge.render(row)
        if row['role'] == 'owner':
            key = self.bridge.adapter.journal.message_threads.get(row['msg_id'])
            name = self.rooms().get(key[0], '대화') if key else '대화'
            text = f'[{name}] ' + text
        if continuation:
            text = '이전 대화 이어쓰기 — 전환 이후 내용\n' + text
        parts = [('text', text[i:i + 4096]) for i in range(0, len(text), 4096)]
        parts.extend(('photo' if mime.startswith('image/') else 'document', path) for path, mime in attachments)
        return parts

    @staticmethod
    def fingerprint(media, payload):
        data = payload.encode() if media == 'text' else payload.read_bytes()
        return hashlib.sha256(media.encode() + b'\0' + data).hexdigest()

    def continuation(self, room, thread):
        cutover = self.bridge.private().get('route_epochs', {}).get(room, {}).get('cutover_seq', 0)
        journal = self.bridge.adapter.journal
        first = next((r['seq'] for r in journal.records if r['type'] == 'message'
                      and journal.message_threads.get(r['msg_id']) == (room, thread)), None)
        return first is not None and first <= cutover

    def new_since_cutover(self, room, msg_id):
        cutover = self.bridge.private().get('route_epochs', {}).get(room, {}).get('cutover_seq', 0)
        original = next((r for r in self.bridge.adapter.journal.records
                         if r['type'] == 'message' and r['msg_id'] == msg_id), None)
        return original is not None and original['seq'] > cutover

    def enqueue(self, binding, row):
        key = (row['room'], row['thread'])
        entry = (row['msg_id'], binding['pair'])
        if entry not in self.bridge.pending.get(key, []):
            self.bridge.pending.setdefault(key, []).append(entry)
            self.bridge.changed[key] = asyncio.get_running_loop().time()
        self.bridge.wake(key)

    def anchor_delivery(self, binding, operation, forward):
        binding = dict(binding, room=operation['room'])
        operation = self.delivery_record(operation, anchor=forward['message_id'])
        self.record(binding, 'alias', 'channel', operation['message_id'], operation['thread'],
                    forward['message_id'], operation['msg_id'])
        self.record(binding, 'alias', 'discussion', forward['message_id'], operation['thread'],
                    forward['message_id'], operation['msg_id'])
        self.enqueue(binding, operation)
        for row in self.binding_operations(binding):
            if row['status'] == 'queued' and not self.unresolved(binding):
                self.enqueue(binding, row)

    async def delivery_forward(self, bot, update):
        message = update.message
        if not message or not message.is_automatic_forward or not message.sender_chat:
            return False
        origin = message.forward_origin
        if not origin or origin.type != 'channel':
            return False
        binding = next((b for b in self.private().get('comments', []) if b['state'] == 'active'
                        and str(message.chat_id) == b['discussion_id']
                        and str(message.sender_chat.id) == str(origin.chat.id) == b['channel_id']), None)
        if not binding or not self.bridge.settings()['enabled']:
            return False
        operations = self.binding_operations(binding)
        matched = next((r for r in operations if r['root'] and r['status'] == 'receipt'
                        and r['message_id'] == origin.message_id), None)
        uncertain = self.unresolved(binding)
        if not matched and not uncertain:
            return False
        forward = dict(v=2, kind='forward', binding=binding['binding'], generation=binding['generation'],
                       origin=origin.message_id, message_id=message.message_id)
        if forward not in self.forwards:
            self.append_record(forward)
            self.forwards.append(forward)
            if not matched and not any(r['operation'] in self.inflight for r in uncertain):
                await bot.send_message(binding['discussion_id'], 'held: 불확실한 발신이 있어 새 원문을 보류했습니다. /hejo_comments_status로 확인하세요.')
        if matched and not matched['anchor']:
            self.anchor_delivery(binding, matched, forward)
        return True

    async def deliver(self, row, key, tag):
        # Serialize the shared hub's network sends independently of native ingress.
        # The lock is released as soon as an automatic forward is needed.
        async with self.output_locks.setdefault('hub', asyncio.Lock()):
            try:
                await self._deliver(row, key, tag)
            finally:
                # A known card can show a held delivery without publishing another card.
                # Failure is durable and visible through status; never mask the original error.
                binding = self.binding_for(key[0])
                if binding and _native_bot is not None:
                    try:
                        await self.update_card_state(_native_bot, binding, key)
                    except Exception:
                        pass  # The edit operation remains unknown (or the hub is paused).


    async def _deliver(self, row, key, tag):
        bot = _native_bot
        binding = self.binding_for(key[0])
        if bot is None or not binding or binding['state'] != 'active' or binding['pair'] != tag or not self.new_since_cutover(key[0], row['msg_id']):
            return
        await self.validate_live(bot, binding)
        row = await self.bridge.settled_row(row['msg_id'], key, tag)
        if not row:
            return
        # Always publish the first new journal message, even when the employee result wins the queue race.
        first = next((self.bridge.adapter.journal.message(r['msg_id'])
                      for r in self.bridge.adapter.journal.records if r['type'] == 'message'
                      and self.bridge.adapter.journal.message_threads.get(r['msg_id']) == key
                      and self.new_since_cutover(key[0], r['msg_id'])), None)
        if first and first['msg_id'] != row['msg_id'] and not self.thread_anchor(binding, key[1]):
            await self._deliver(first, key, tag)
        anchor_now = self.thread_anchor(binding, key[1])
        if anchor_now:
            await self.send_card(bot, binding, key, anchor_now)
        existing = [r for r in self.binding_operations(binding) if r['msg_id'] == row['msg_id'] and r['side'] != 'forum']
        anchor = self.thread_anchor(binding, key[1])
        roots = [r for r in self.binding_operations(binding) if r['root'] and r.get('room') == key[0] and r['thread'] == key[1]]
        continuation = self.continuation(*key)
        pieces = self.parts(row, continuation=continuation and not anchor and not roots)
        if roots and not anchor and not existing:
            for part, (media, payload) in enumerate(pieces):
                self.delivery_record(dict(v=3, room=key[0], kind='delivery', operation=secrets.token_hex(16),
                    binding=binding['binding'], generation=binding['generation'], route_epoch=self.epoch(key[0]),
                    side='discussion', message_id=0, thread=key[1], msg_id=row['msg_id'], anchor=0, part=part,
                    media=media, fingerprint=self.fingerprint(media, payload), status='queued', root=False))
            return
        if existing:
            # The first root's continuation marker is part of its original payload.
            root = next((r for r in existing if r['root']), None)
            pieces = self.parts(row, continuation=bool(root and continuation))
        else:
            for part, (media, payload) in enumerate(pieces):
                root = not anchor and not roots and part == 0
                op = dict(v=3, room=key[0], kind='delivery', operation=secrets.token_hex(16), binding=binding['binding'],
                          generation=binding['generation'], route_epoch=self.epoch(key[0]),
                          side='channel' if root else 'discussion', message_id=0, thread=key[1],
                          msg_id=row['msg_id'], anchor=0, part=part, media=media,
                          fingerprint=self.fingerprint(media, payload), status='queued', root=root)
                existing.append(self.delivery_record(op))
        for op in sorted(existing, key=lambda r: r['part']):
            op = self.operations[op['operation']]
            if op['status'] != 'queued':
                continue
            if self.unresolved(binding):
                return
            await self.validate_live(bot, binding)
            journal = self.bridge.adapter.journal
            latest = await self.bridge.settled_row(row['msg_id'], key, tag)
            if not latest:
                return
            pieces = self.parts(latest, continuation=bool(any(r['root'] for r in existing) and continuation))
            anchor = self.thread_anchor(binding, key[1])
            if not op['root'] and not anchor:
                return  # Waiting is durable and visible; never await a forward holding a lock.
            if anchor and (not journal.message(anchor['msg_id'])):
                return
            if op['part'] >= len(pieces):
                self.delivery_record(op, status='unknown')
                return
            media, payload = pieces[op['part']]
            if self.fingerprint(media, payload) != op['fingerprint']:
                self.delivery_record(op, status='unknown')
                return
            from telegram import ReplyParameters
            kwargs = {} if op['root'] else {'reply_parameters': ReplyParameters(
                anchor['anchor'], allow_sending_without_reply=False)}
            if op['root']:
                from telegram import InlineKeyboardButton, InlineKeyboardMarkup
                topic = self.bridge.topics(tag)['topics'].get(key[0])
                if not topic or topic['closed']:
                    raise Rejected('topic_unavailable')
                back = self.message_link(self.private()['pair']['chat_id'], topic['topic'])
                kwargs['reply_markup'] = InlineKeyboardMarkup([[InlineKeyboardButton('방으로' if key[0] in self.bridge.adapter.journal.rooms else '사람별 방으로', url=back)]])
            destination = binding['channel_id'] if op['root'] else binding['discussion_id']
            op = self.delivery_record(op, status='intent', anchor=0 if op['root'] else anchor['anchor'])
            self.inflight.add(op['operation'])
            try:
                if media == 'text':
                    result = await bot.send_message(destination, payload, **kwargs)
                else:
                    with payload.open('rb') as stream:
                        send = bot.send_photo if media == 'photo' else bot.send_document
                        result = await send(destination, stream, **kwargs)
                op = self.delivery_record(op, status='receipt', message_id=result.message_id)
                if (self.route(key[0]) != 'comments' or self.epoch(key[0]) != op['route_epoch']
                        or not self.bridge.settings()['enabled']):
                    return
                if op['root']:
                    forward = next((f for f in self.forwards if f['binding'] == binding['binding']
                                    and f['generation'] == binding['generation'] and f['origin'] == result.message_id), None)
                    if forward:
                        self.anchor_delivery(binding, op, forward)
                else:
                    self.record(binding, 'alias', 'discussion', result.message_id, key[1], op['anchor'], row['msg_id'])
            except BaseException:
                if not self.damaged and self.operations[op['operation']]['status'] != 'receipt':
                    self.delivery_record(op, status='unknown')
                raise
            finally:
                self.inflight.discard(op['operation'])

    @staticmethod
    def message_link(chat_id, message_id, thread_id=None):
        # Bot API channel ids encode the positive MTProto id with a 10^12 offset.
        value = int(chat_id)
        if value >= -1000000000000 or int(message_id) <= 0:
            raise Rejected('invalid_link')
        link = f'https://t.me/c/{-value - 1000000000000}/{int(message_id)}'
        if thread_id is not None:
            if int(thread_id) <= 0:
                raise Rejected('invalid_link')
            link += f'?thread={int(thread_id)}'
        return link

    def card_source(self, binding, thread):
        journal = self.bridge.adapter.journal
        return next((journal.message(r['msg_id']) for r in journal.records if r['type'] == 'message'
                     and journal.message_threads.get(r['msg_id']) == (binding['room'], thread)
                     and self.new_since_cutover(binding['room'], r['msg_id'])), None)

    def card_text(self, binding, thread, state='대화 가능'):
        row = self.card_source(binding, thread)
        if not row:
            raise Rejected('deleted')
        title = (row['text'].strip().splitlines() or ['첨부 대화'])[0][:80]
        prefix = '이전 대화 이어쓰기 — 전환 이후 내용\n' if self.continuation(binding['room'], thread) else ''
        return prefix + title + '\n' + state

    async def send_card(self, bot, binding, key, anchor):
        from telegram import InlineKeyboardButton, InlineKeyboardMarkup, ReplyParameters
        cards = [op for op in self.binding_operations(binding) if op['side'] == 'forum'
                 and op['room'] == key[0] and op['thread'] == key[1]
                 and op['route_epoch'] == self.epoch(key[0])]
        if cards:
            return  # Unknown cards never cause a second publication.
        await self.validate_live(bot, binding)
        pair = self.private()['pair']
        topic = self.bridge.topics(pair['tag'])['topics'].get(key[0])
        if not topic or topic['closed']:
            raise Rejected('topic_unavailable')
        link = self.message_link(binding['discussion_id'], anchor['anchor'], anchor['anchor'])
        text = self.card_text(binding, key[1])
        source = self.card_source(binding, key[1])
        original = next((r for r in self.records if r.get('room') == key[0] and r['thread'] == key[1]
                         and r['binding'] == binding['binding'] and r['side'] == 'forum'
                         and r['msg_id'] == source['msg_id']), None)
        op = dict(v=3, room=key[0], kind='delivery', operation=secrets.token_hex(16),
                  binding=binding['binding'], generation=binding['generation'], route_epoch=self.epoch(key[0]),
                  side='forum', message_id=0, thread=key[1], msg_id=source['msg_id'], anchor=int(topic['topic']),
                  part=0, media='text', fingerprint=self.fingerprint('text', text), status='intent', root=False)
        self.delivery_record(op)
        self.inflight.add(op['operation'])
        try:
            kwargs = dict(message_thread_id=int(topic['topic']),
                          reply_markup=InlineKeyboardMarkup([[InlineKeyboardButton('대화 열기', url=link)]]))
            if original:
                kwargs['reply_parameters'] = ReplyParameters(original['message_id'], allow_sending_without_reply=False)
            result = await bot.send_message(pair['chat_id'], text, **kwargs)
            self.delivery_record(op, status='receipt', message_id=result.message_id)
            self.live(binding)
            self.record(binding, 'alias', 'forum', result.message_id, key[1], int(topic['topic']), source['msg_id'])
        except BaseException:
            if not self.damaged and self.operations[op['operation']]['status'] != 'receipt':
                self.delivery_record(op, status='unknown')
            raise
        finally:
            self.inflight.discard(op['operation'])

    async def update_card_state(self, bot, binding, key):
        cards = [r for r in self.binding_operations(binding) if r['side'] == 'forum'
                 and r.get('room') == key[0] and r['thread'] == key[1]
                 and r['route_epoch'] == self.epoch(key[0])]
        card = next((r for r in cards if r['media'] == 'text' and r['status'] == 'receipt'), None)
        if not card or any(r['status'] in {'intent', 'unknown'} for r in cards):
            return
        latest = cards[-1]
        state = '보류' if self.unresolved(binding) else '대화 가능'
        text = self.card_text(binding, key[1], state)
        if self.fingerprint('text', text) == latest['fingerprint']:
            return
        await self.validate_live(bot, binding)
        anchor = self.thread_anchor(binding, key[1])
        if not anchor:
            return
        from telegram import InlineKeyboardButton, InlineKeyboardMarkup
        link = self.message_link(binding['discussion_id'], anchor['anchor'], anchor['anchor'])
        op = self.delivery_record(dict(card, operation=secrets.token_hex(16), media='edit',
                                       fingerprint=self.fingerprint('text', text), status='intent'))
        self.inflight.add(op['operation'])
        try:
            await bot.edit_message_text(text, chat_id=self.private()['pair']['chat_id'],
                message_id=card['message_id'], reply_markup=InlineKeyboardMarkup(
                    [[InlineKeyboardButton('대화 열기', url=link)]]))
            self.delivery_record(op, status='receipt')
        except BaseException:
            if not self.damaged and self.operations[op['operation']]['status'] != 'receipt':
                self.delivery_record(op, status='unknown')
            raise
        finally:
            self.inflight.discard(op['operation'])

    def delivery_status(self, message):
        pair = self.private()['pair']
        bindings = [b for b in self.private().get('comments', []) if b['pair'] == pair['tag']
                    and b['owner_id'] == pair['user_id']
                    and str(message.chat_id) in {b['discussion_id'], pair['chat_id']}]
        lines = []
        for b in bindings:
            lines.append('rooms: ' + ', '.join(self.member_rooms(b)) + ' / connection: ' + b['state'])
            operations = sorted(self.binding_operations(b), key=lambda r: r['status'] == 'receipt')
            for r in operations:
                status = 'unknown' if r['status'] == 'intent' and r['operation'] not in self.inflight else r['status']
                if r['root'] and status == 'receipt' and not r['anchor']:
                    status = 'waiting_anchor'
                lines.append(r['operation'] + ': ' + r.get('room', 'legacy') + '/' + r['side'] + '/' + r['media'] + ' ' + status)
        return '\n'.join(lines)[:4000] or 'idle: 등록된 댓글 연결이 없습니다.'

    async def resolve(self, bot, message, operation):
        op = self.operations.get(operation)
        if not op or op['status'] not in {'unknown', 'intent'} or operation in self.inflight:
            raise Rejected('invalid_operation')
        binding = next((b for b in self.private().get('comments', []) if b['binding'] == op['binding']
                        and b['generation'] == op['generation'] and b['state'] == 'active'), None)
        if binding:
            binding = dict(binding, room=op['room'])
        target = message.reply_to_message
        if binding and op['side'] == 'forum':
            return await self.resolve_card(bot, message, binding, op)
        if (not binding or str(message.chat_id) != binding['discussion_id'] or not target
                or str(target.chat_id) != binding['discussion_id'] or message.external_reply):
            raise Rejected('invalid_target')
        await self.validate_live(bot, binding)
        if op['route_epoch'] != self.epoch(binding['room']) or target.date.timestamp() <= binding['activated_at']:
            raise Rejected('invalid_target')
        origin = target.forward_origin
        if op['root']:
            if (not target.is_automatic_forward or not origin or origin.type != 'channel'
                    or not target.sender_chat or str(target.sender_chat.id) != binding['channel_id']
                    or str(origin.chat.id) != binding['channel_id']):
                raise Rejected('invalid_target')
            remote_id = origin.message_id
        else:
            if (not target.from_user or str(target.from_user.id) != binding['bot_id']
                    or target.sender_chat or origin):
                raise Rejected('invalid_target')
            reply = target.reply_to_message
            raw = target.message_thread_id
            if ((reply and reply.message_id != op['anchor']) or (raw and raw != op['anchor'])
                    or not (reply or raw)):
                raise Rejected('invalid_target')
            remote_id = target.message_id
        if any(r['status'] == 'receipt' and r['side'] == op['side'] and r['message_id'] == remote_id
               for r in self.binding_operations(binding)):
            raise Rejected('used_target')
        row = self.bridge.adapter.journal.message(op['msg_id'])
        if not row or (binding['room'], op['thread']) in self.bridge.adapter.journal.deleted_threads:
            raise Rejected('deleted')
        pieces = self.parts(row, continuation=bool(op['root'] and self.continuation(binding['room'], op['thread'])))
        media, payload = pieces[op['part']]
        if self.fingerprint(media, payload) != op['fingerprint']:
            raise Rejected('changed_source')
        if media == 'text':
            if target.text != payload:
                raise Rejected('mismatch')
        elif (media == 'photo' and not target.photo) or (media == 'document' and not target.document):
            raise Rejected('mismatch')
        op = self.delivery_record(op, status='receipt', message_id=remote_id)
        if op['root']:
            self.anchor_delivery(binding, op, {'message_id': target.message_id})
        else:
            self.record(binding, 'alias', 'discussion', remote_id, op['thread'], op['anchor'], op['msg_id'])
            for queued in self.binding_operations(binding):
                if queued['status'] == 'queued':
                    self.enqueue(binding, queued)
        return 'resolved: 실제 발신 글과의 대응을 저장했습니다. 재발신하지 않습니다.'

    async def resolve_card(self, bot, message, binding, op):
        target = message.reply_to_message
        pair = self.private()['pair']
        topic = self.bridge.topics(pair['tag'])['topics'].get(op['room'])
        if (str(message.chat_id) != pair['chat_id'] or message.external_reply or not target or not topic
                or str(target.chat_id) != pair['chat_id'] or target.message_thread_id != int(topic['topic'])
                or message.message_thread_id != int(topic['topic']) or target.forward_origin or target.sender_chat
                or not target.from_user or str(target.from_user.id) != binding['bot_id']
                or target.date.timestamp() <= binding['activated_at'] or op['route_epoch'] != self.epoch(op['room'])):
            raise Rejected('invalid_target')
        await self.validate_live(bot, binding)
        journal = self.bridge.adapter.journal
        if ((op['room'], op['thread']) in journal.deleted_threads
                or journal.message_threads.get(op['msg_id']) != (op['room'], op['thread'])
                or not journal.message(op['msg_id'])):
            raise Rejected('deleted')
        text = self.card_text(binding, op['thread'])
        if op['media'] == 'edit':
            text = next((self.card_text(binding, op['thread'], state) for state in ('대화 가능', '보류')
                         if self.fingerprint('text', self.card_text(binding, op['thread'], state)) == op['fingerprint']), '')
            if target.message_id != op['message_id']:
                raise Rejected('invalid_target')
        anchor = self.thread_anchor(binding, op['thread'])
        if not anchor or target.text != text or self.fingerprint('text', text) != op['fingerprint']:
            raise Rejected('mismatch')
        link = self.message_link(binding['discussion_id'], anchor['anchor'], anchor['anchor'])
        buttons = target.reply_markup.inline_keyboard if target.reply_markup else ()
        if len(buttons) != 1 or len(buttons[0]) != 1 or buttons[0][0].url != link:
            raise Rejected('mismatch')
        if op['media'] != 'edit' and any(r['side'] == 'forum' and r['status'] == 'receipt' and r['message_id'] == target.message_id
               for r in self.binding_operations(binding)):
            raise Rejected('used_target')
        self.delivery_record(op, status='receipt', message_id=target.message_id)
        self.record(binding, 'alias', 'forum', target.message_id, op['thread'], op['anchor'], op['msg_id'])
        for row in self.binding_operations(binding):
            if row['status'] == 'queued':
                self.enqueue(binding, row)
        return 'resolved: 카드 대응을 저장했습니다. 재발신하지 않습니다.'

    async def retire(self, message, room=None, abort=False):
        binding = self.hub()
        if not binding or room is not None or (not abort and str(message.chat_id) != binding['discussion_id']):
            raise Rejected('invalid_target')
        async with self.bridge._topic_lock:
            if any(self.busy(r) for r in binding['rooms']) or self.inflight:
                raise Rejected('busy')
            outstanding = self.outstanding(binding)
            if outstanding and not abort:
                raise Rejected('busy')
            with self.bridge.vault.locked():
                value = self.private()
                current = next(b for b in value['comments'] if b['binding'] == binding['binding'])
                current['state'] = 'retired'
                for r in binding['rooms']:
                    value.setdefault('route_epochs', {})[r] = dict(epoch=secrets.token_hex(16),
                                                                  cutover_seq=self.bridge.adapter.journal.head)
                self.bridge.vault.write('telegram.json', value)
            for op in outstanding:
                self.delivery_record(op, status='cancelled')
        self.bridge.request_sync()
        return ('aborted: 미전송 댓글을 취소합니다. ' if abort else 'off: ') + '참여 방 모두 토픽으로 돌아갑니다. 기존 채널·그룹은 영구 은퇴하며 다시 연결하려면 새 쌍이 필요합니다.'

    async def close(self):
        for task in self.tasks:
            task.cancel()
        await asyncio.gather(*self.tasks, return_exceptions=True)
        self.tasks.clear()


def attach(native):
    global _native_bot
    if native is None:
        return
    _native_bot = native.bot
    if native.bot_data.get('_hejo_comments_handler'):
        return
    from telegram.ext import BaseHandler
    from hermes_constants import get_hermes_home
    from .auth import AuthStore
    vault = AuthStore(get_hermes_home())
    topics_store = AuthStore(get_hermes_home())
    topics_store.path = Path(get_hermes_home()) / 'shared' / 'hejo' / 'telegram'

    class CommentsHandler(BaseHandler):
        def check_update(self, update):
            from .adapter import _primary
            bridge = getattr(_primary, 'telegram', None)
            if bridge:
                return bridge.comments.claims(update)
            # Telegram can connect before the hejo listener. Reservation ownership
            # survives this interval; the callback consumes without executing.
            value = vault.read('telegram.json', {})
            message = getattr(update, 'effective_message', None)
            if Comments.reserved(value, message):
                return True
            pair = value.get('pair')
            if not message or not pair or str(message.chat_id) != pair['chat_id']:
                return False
            saved = topics_store.read('topics.json', {})
            if saved.get('tag') != pair['tag']:
                return False
            rooms = {room for b in value.get('comments', []) if b['state'] != 'retired'
                     for room in Comments.member_rooms(b)}
            return any(room in rooms and str(message.message_thread_id) == topic['topic']
                       and not topic['closed'] for room, topic in saved.get('topics', {}).items())

    async def callback(update, context):
        from .adapter import _primary
        bridge = getattr(_primary, 'telegram', None)
        if bridge:
            await bridge.comments.handle(update, context)

    # Factories run once per native Application, including connection rebuilds.
    handler = CommentsHandler(callback, block=True)
    native.add_handler(handler, group=0)
    native.bot_data['_hejo_comments_handler'] = handler
