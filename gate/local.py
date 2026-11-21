"""Employee-only HTTP ingress on the primary gate's private Unix socket."""
import asyncio
import errno
import json
import os
from pathlib import Path
import socket
import stat
import uuid

from aiohttp import web
from jsonschema import Draft202012Validator

from .journal import HejoJournalError

SCHEMA = json.loads((Path(__file__).resolve().parent.parent / 'schemas' / 'hejo-local-v1.json').read_text())
LIMITS = SCHEMA['x-limits']
VALIDATORS = {name: Draft202012Validator({**SCHEMA, '$ref': '#/$defs/' + name})
              for name in ('post', 'patch', 'delete', 'room', 'thread_query')}
ERRORS = set(SCHEMA['$defs']['error']['properties']['error']['enum'])


class Rejected(ValueError):
    def __init__(self, code, status=400, **details):
        super().__init__(code)
        self.code, self.status, self.details = code, status, details


@web.middleware
async def errors(request, handler):
    try:
        return await handler(request)
    except Rejected as exc:
        return web.json_response({'error': exc.code, **exc.details}, status=exc.status)
    except (json.JSONDecodeError, UnicodeError, web.HTTPRequestEntityTooLarge):
        return web.json_response({'error': 'invalid_frame'}, status=400)
    except HejoJournalError:
        return web.json_response({'error': 'journal_write_failed'}, status=503)
    except ValueError as exc:
        code = str(exc) if str(exc) in ERRORS else 'invalid_frame'
        return web.json_response({'error': code}, status=400)


class LocalIngress:
    def __init__(self, adapter, home):
        self.adapter = adapter
        self.path = Path(home) / 'hejo' / 'post.sock'
        self.runner = None
        self.socket = None
        self.identity = None
        # Only this ingress accepts local client keys. Serializing requests keeps
        # duplicate lookup and commit together without a second persistent index.
        self.lock = asyncio.Lock()

    async def start(self):
        self.path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        if self.path.exists() or self.path.is_symlink():
            info = self.path.lstat()
            if not stat.S_ISSOCK(info.st_mode) or info.st_uid != os.getuid():
                raise ValueError('local_socket_path_occupied')
            probe = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            probe.setblocking(False)
            try:
                await asyncio.wait_for(asyncio.get_running_loop().sock_connect(probe, str(self.path)), 1)
            except OSError as exc:
                if exc.errno != errno.ECONNREFUSED:
                    raise
                if self.path.lstat().st_ino != info.st_ino:
                    raise ValueError('local_socket_path_changed') from None
                self.path.unlink()
            else:
                raise ValueError('local_socket_in_use')
            finally:
                probe.close()
        app = web.Application(middlewares=[errors], client_max_size=LIMITS['frame_bytes'])
        app.router.add_post('/local/v1/messages', self.post)
        app.router.add_patch('/local/v1/messages/{msg_id}', self.patch)
        app.router.add_delete('/local/v1/messages/{msg_id}', self.delete)
        app.router.add_get('/local/v1/threads/{thread}', self.thread)
        app.router.add_post('/local/v1/rooms', self.room)
        self.runner = web.AppRunner(app, access_log=None)
        await self.runner.setup()
        try:
            self.socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            # Bind with owner-only permissions, including the interval before chmod.
            mask = os.umask(0o177)
            try:
                self.socket.bind(str(self.path))
            finally:
                os.umask(mask)
            self.identity = self.path.lstat().st_ino
            self.path.chmod(0o600)
            self.socket.setblocking(False)
            await web.SockSite(self.runner, self.socket).start()
        except BaseException:
            await self.stop()
            raise

    async def stop(self):
        if self.runner:
            await self.runner.cleanup()
            self.runner = None
        if self.socket:
            self.socket.close()
            self.socket = None
        if self.identity is not None:
            try:
                if self.path.lstat().st_ino == self.identity:
                    self.path.unlink()
            except FileNotFoundError:
                pass
            self.identity = None

    async def body(self, request, kind):
        value = await request.json()
        if not VALIDATORS[kind].is_valid(value):
            raise Rejected('invalid_frame')
        if 'text' in value and len(value['text'].encode('utf-8')) > LIMITS['text_bytes']:
            raise Rejected('invalid_frame')
        return value

    def scope(self, employee=None, room=None, thread=None):
        a = self.adapter
        if employee is not None and employee not in {e['id'] for e in a.employees()}:
            raise Rejected('unknown_employee')
        if room:
            if room in a.journal.deleted_rooms:
                raise Rejected('room_deleted')
            if room not in a.journal.rooms:
                raise Rejected('room_not_found')
            if employee is not None and employee not in a.journal.rooms[room]['members']:
                raise Rejected('room_member_required')
        if thread and a.journal.deleted(room or employee, thread):
            raise Rejected('thread_deleted')
        return 'room:' + room if room else employee

    @staticmethod
    def checked(result):
        if result.success:
            return result.message_id
        code = (result.error or '').removesuffix('_drop')
        if code == 'journal_unavailable':
            code = 'journal_write_failed'
        if code not in ERRORS:
            code = 'invalid_frame'
        raise Rejected(code, 503 if code == 'journal_write_failed' else 400)

    async def post(self, request):
        data = await self.body(request, 'post')
        a = self.adapter
        async with self.lock:
            chat = self.scope(data['employee'], data.get('room'), data.get('thread'))
            key = data.get('client_id')
            if key is not None:
                original = next((r for r in a.journal.records if r['type'] == 'message'
                                 and r['employee'] == data['employee']
                                 and r.get('_meta', {}).get('local', {}).get('client_id') == key), None)
                if original:
                    if a.journal.deleted(original.get('room', original['employee']), original['thread']):
                        raise Rejected('thread_deleted')
                    if not a.journal.message(original['msg_id']):
                        raise Rejected('message_not_found')
                    return web.json_response({'msg_id': original['msg_id'], 'thread': original['thread'], 'repeated': True})
            thread = data.get('thread') or str(uuid.uuid4())
            meta = {'hermes_profile': data['employee'], 'thread_id': thread,
                    '_hejo_local': {'source': 'local', **({'client_id': key} if key is not None else {})}}
            for field in ('buttons', 'checklist', 'reply_state'):
                if field in data:
                    meta['hejo_' + field] = data[field]
            if 'checklist' in data:
                try:
                    a._checklist(meta)
                except ValueError:
                    raise Rejected('invalid_frame') from None
            # Stage all attachments and register them on the single message commit.
            # The same media path guard, copy, promotion and rollback are used by
            # send_image_file/send_document; no separate attachment posts are made.
            staged = []
            for source in data.get('images', []):
                path = a.validate_media_delivery_path(source)
                if path is None:
                    raise Rejected('invalid_frame')
                try:
                    staged.append(await a.files.copy(data['employee'], path))
                except (OSError, ValueError):
                    raise Rejected('invalid_frame') from None
            async with a.files.lock:
                moved = []
                try:
                    if staged:
                        descriptors, moved = a.files.promote(data['employee'], [s['file_id'] for s in staged])
                        meta['_hejo_files'] = descriptors
                        meta['_hejo_file_registration'] = a.files.registration(data['employee'], 'employee', descriptors)
                    result = await a.send(chat, data['text'], metadata=meta)
                    if not result.success:
                        a.files.rollback(moved)
                        moved = []
                    msg_id = self.checked(result)
                except OSError:
                    a.files.rollback(moved)
                    raise Rejected('journal_write_failed', 503) from None
            return web.json_response({'msg_id': msg_id, 'thread': thread, 'repeated': False})

    def authored(self, msg_id, employee, *, deleted_ok=False):
        a = self.adapter
        original = next((r for r in a.journal.records if r['type'] == 'message' and r['msg_id'] == msg_id), None)
        if not original or original['role'] != 'employee' or original['employee'] != employee:
            raise Rejected('message_not_found')
        current = a.journal.message(msg_id)
        if not current and not deleted_ok:
            raise Rejected('message_not_found')
        return current or original

    async def patch(self, request):
        data = await self.body(request, 'patch')
        async with self.lock:
            a = self.adapter
            row = self.authored(request.match_info['msg_id'], data['employee'])
            chat = self.scope(data['employee'], row.get('room'), row['thread'])
            if 'text' in data or 'buttons' in data:
                meta = {'hejo_buttons': data['buttons']} if 'buttons' in data else None
                self.checked(await a.edit_message(chat, row['msg_id'], data.get('text', row['text']), finalize=True, metadata=meta))
            if 'reply_state' in data:
                await a.set_reply_state(row['msg_id'], data['reply_state'])
            return web.json_response({'msg_id': row['msg_id']})

    async def delete(self, request):
        data = await self.body(request, 'delete')
        async with self.lock:
            a = self.adapter
            row = self.authored(request.match_info['msg_id'], data['employee'], deleted_ok=True)
            if not a.journal.message(row['msg_id']):
                return web.json_response({})
            chat = self.scope(data['employee'], row.get('room'), row['thread'])
            from .adapter import _delivery_scope
            token = _delivery_scope.set((data['employee'], chat, row['thread']))
            try:
                if not await a.delete_message(chat, row['msg_id']):
                    raise Rejected('journal_write_failed', 503)
            finally:
                _delivery_scope.reset(token)
            return web.json_response({})

    async def thread(self, request):
        query = dict(request.query)
        try:
            query['after'] = int(query.get('after', 0))
        except ValueError:
            raise Rejected('invalid_frame') from None
        if not VALIDATORS['thread_query'].is_valid(query):
            raise Rejected('invalid_frame')
        thread = request.match_info['thread']
        self.scope(query.get('employee'), query.get('room'), thread)
        a = self.adapter
        key = (query.get('room') or query['employee'], thread)
        messages = []
        for original in a.journal.records:
            if original['type'] != 'message' or a.journal.message_threads.get(original['msg_id']) != key:
                continue
            row = a.journal.message(original['msg_id'])
            if row and row['seq'] > query['after']:
                messages.append({field: row[field] for field in ('msg_id', 'seq', 'role', 'employee', 'text', 'ts', 'reply_state')})
        return web.json_response({'messages': messages})

    async def room(self, request):
        data = await self.body(request, 'room')
        a = self.adapter
        async with self.lock, a.files.lock, a._publish_lock:
            try:
                record = a.room_save_record(data, str(uuid.uuid4()))
            except ValueError as exc:
                raise Rejected(str(exc)) from None
            matches = [r for r in a.journal.rooms.values() if r['title'] == record['room']['title']]
            def details(room):
                return {'room': room['id'], **{key: room[key] for key in ('members', 'lead', 'archived')}}
            if len(matches) > 1:
                raise Rejected('room_ambiguous', 409, rooms=[details(r) for r in matches])
            if matches:
                previous = matches[0]
                if previous['archived'] or set(previous['members']) != set(data['members']) or previous['lead'] != data['lead']:
                    raise Rejected('room_conflict', 409, **details(previous))
                return web.json_response({'room': previous['id'], 'created': False})
            a._validate_frame(record)
            saved = await a.journal.append(record)
            await a.server.broadcast(saved)
            return web.json_response({'room': record['room']['id'], 'created': True})
