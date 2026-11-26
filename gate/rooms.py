"""Group commands and delivery context; the journal alone owns room state."""
from datetime import datetime, timezone
import logging
import re
import uuid
from .context import conversation_lines
from .journal import HejoJournalError

log = logging.getLogger(__name__)


def recipients(text, room, employees, journal, thread):
    called = []
    matches = []
    for employee in employees:
        if employee['id'] not in room['members']:
            continue
        for name in [employee['name'], employee['id'], *employee.get('aliases', [])]:
            if name:
                for match in re.finditer(r'@' + re.escape(name) + r'(?![^\W_])', text):
                    matches.append((match.start(), -len(name), match.end(), employee['id']))
    end = -1
    for start, _, stop, employee in sorted(matches):
        if start >= end:
            if employee not in called:
                called.append(employee)
            end = stop
    if called:
        return called
    first = next((row for row in journal.records if row['type'] == 'message'
                  and journal.message_threads.get(row['msg_id']) == (room['id'], thread)), None)
    owners = ([first['employee']] if first['role'] == 'employee'
              else first.get('_meta', {}).get('recipients', [])) if first else []
    eligible = set(room['members']) & {employee['id'] for employee in employees}
    return [owner for owner in owners if owner in eligible] or [room['lead']]


class RoomCommands:
    def room_save_record(self, frame, identifier, existing=None):
        known = {entry['id'] for entry in self.employees()}
        members, title = frame['members'], frame['title'].strip()
        if not title or len(set(members)) < 2 or len(set(members)) != len(members) or frame['lead'] not in members:
            raise ValueError('invalid_room')
        if not set(members) <= known:
            raise ValueError('unknown_employee')
        room = {**(existing or {}), 'id': identifier, 'title': title,
                'description': frame.get('description', ''), 'members': members, 'lead': frame['lead'],
                'archived': (existing or {}).get('archived', False), 'picture': (existing or {}).get('picture')}
        return {'v': 1, 'type': 'room', 'room': room}

    async def room_command(self, frame, conn):
        async with self.files.lock, self._publish_lock:
            discord = getattr(self, 'discord', None)
            identifier = frame.get('id') or str(uuid.uuid4())
            if identifier in self.journal.deleted_rooms:
                await self.server.error('room_deleted', identifier, conn)
                return
            existing = self.journal.rooms.get(identifier)
            if frame['type'] != 'room_save' and existing is None or frame['type'] == 'room_save' and frame.get('id') and existing is None:
                await self.server.error('room_not_found', identifier, conn)
                return
            if frame['type'] == 'room_save':
                try:
                    record = self.room_save_record(frame, identifier, existing)
                except ValueError as exc:
                    await self.server.error(str(exc), identifier, conn)
                    return
            elif frame['type'] == 'room_archive':
                record = {'v': 1, 'type': 'room', 'room': {**existing, 'archived': frame['archived']}}
            else:
                record = {'v': 1, 'type': 'room_delete', 'room': identifier, 'at': datetime.now(timezone.utc).isoformat()}
            self._validate_frame(record)
            try:
                saved = await self.journal.append(record)
            except HejoJournalError:
                await self.server.error('journal_write_failed', identifier, conn)
                return
            await self.server.broadcast(saved)
            if frame['type'] == 'room_delete':
                try:
                    self.cleanup_rooms()
                except OSError:
                    log.warning('room_cleanup_pending')
        if discord:
            discord.recorded(saved)

    def cleanup_rooms(self):
        self.files.cleanup()
        for identifier in self.journal.deleted_rooms:
            self.server.pictures.delete('room', identifier)

    def room_context(self, room, thread, employee):
        rows = [self.journal.message(row['msg_id']) for row in self.journal.records
                if row['type'] == 'message' and self.journal.message_threads.get(row['msg_id']) == (room, thread)]
        rows = [row for row in rows if row]
        # Receiving an owner post is durable metadata on that owner post; own answers also mark receipt.
        last = max((row['seq'] for row in rows if employee in row.get('_meta', {}).get('recipients', [])
                    or row['role'] == 'employee' and row['employee'] == employee), default=0)
        missed = [row for row in rows if row['seq'] > last]
        return conversation_lines(missed, {e['id']: e['name'] for e in self.employees()},
                                  owner=self.owner_label("나"), limit=20, characters=4000, line_characters=500)
