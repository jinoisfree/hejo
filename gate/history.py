"""Rebuildable current-message index for bounded history queries.

The journal remains the only durable authority. Updates run synchronously at its
commit boundary; callers receive copies and cannot mutate the indexed revision.
"""
import base64
from bisect import bisect_left
from copy import deepcopy
import hashlib
import hmac
import json
import secrets
import time

from .reply_rules import has_native_buttons


class HistoryIndex:
    def __init__(self):
        self.head = 0
        self._messages = {}
        self._threads = {}
        self._rooms = {}
        self._keys = {}
        self._revisions = {}
        self._thread_revisions = {}
        self._receipts = {}
        self._undos = {}
        self._fields = {}
        self._resolved_native = set()
        # Sparse transitions for replay: a later edit must not change an earlier frame.
        self._default_button_changes = {}
        self._deleted_threads = set()
        self._deleted_rooms = set()

    def apply(self, row):
        kind, seq = row['type'], row['seq']
        self.head = seq
        if kind == 'room_delete':
            room = row['room']
            self._deleted_rooms.add(room)
            for key in tuple(self._rooms.get(room, ())):
                self._delete_thread(key, seq)
            return
        if kind == 'delete' and row.get('scope') == 'thread':
            self._delete_thread((row['room'], row['thread']), seq)
            return
        identifier = row.get('msg_id')
        if identifier is None:
            return
        undo = row.get('_meta', {}).get('undo')
        if kind == 'message' and undo:
            self._undos[identifier] = dict(undo)
        if kind == 'state' and identifier in self._undos and row.get('_meta', {}).get('delivered'):
            self._undos[identifier]['delivered'] = True
        if kind == 'message':
            key = (row.get('room', row['employee']), row['thread'])
            self._keys[identifier] = key
            # This follows receive's original owner-message idempotency contract.
            if row.get('role') == 'owner' and row.get('client_msg_id'):
                self._receipts.setdefault(row['client_msg_id'], (identifier, seq))
            self._revisions[identifier] = seq
            if key in self._deleted_threads or key[0] in self._deleted_rooms:
                return
            self._messages[identifier] = {k: deepcopy(v) for k, v in row.items() if k != '_meta'}
            self._threads.setdefault(key, []).append((seq, identifier))
            self._rooms.setdefault(key[0], set()).add(key)
            self._thread_revisions[key] = seq
        elif kind == 'delete':
            self._delete(identifier, seq)
        elif kind in {'edit', 'state'}:
            message = self._messages.get(identifier)
            if message is not None:
                track_buttons = message.get('role') == 'employee' and any(
                    k in row for k in ('buttons', 'text', 'reply_state', 'checklist'))
                had_defaults = track_buttons and self._has_default_buttons(message)
                if kind == 'edit' and 'buttons' in row:
                    if row['buttons']:
                        self._resolved_native.discard(identifier)
                    elif has_native_buttons(message):
                        self._resolved_native.add(identifier)
                # Original sequence is the read boundary, revision is the update boundary.
                message.update({k: deepcopy(v) for k, v in row.items()
                                if k not in {'v', 'type', 'seq', '_meta'}})
                if track_buttons and not row.get('buttons'):
                    defaults = self._has_default_buttons(message)
                    if defaults != had_defaults or (defaults and 'buttons' in row):
                        self._default_button_changes[seq] = defaults
                self._revisions[identifier] = seq
                self._thread_revisions[self._keys[identifier]] = seq

    def _has_default_buttons(self, message):
        from .history_queries import has_default_buttons
        return message['msg_id'] not in self._resolved_native and has_default_buttons(message)

    def default_button_change(self, seq):
        return self._default_button_changes.get(seq)

    def _delete(self, identifier, revision):
        message = self._messages.pop(identifier, None)
        self._revisions[identifier] = revision
        if message is None:
            return
        key = self._keys[identifier]
        self._fields.pop(key, None)
        self._undos.pop(identifier, None)
        self._resolved_native.discard(identifier)
        entries = self._threads[key]
        position = bisect_left(entries, (message['seq'], identifier))
        if position < len(entries) and entries[position][1] == identifier:
            entries.pop(position)
        self._thread_revisions[key] = revision
        if not entries:
            del self._threads[key]
            self._rooms[key[0]].discard(key)

    def _delete_thread(self, key, revision):
        self._deleted_threads.add(key)
        self._fields.pop(key, None)
        for _, identifier in self._threads.pop(key, ()):
            self._undos.pop(identifier, None)
            self._resolved_native.discard(identifier)
            self._messages.pop(identifier, None)
            self._revisions[identifier] = revision
        self._rooms.get(key[0], set()).discard(key)
        self._thread_revisions[key] = revision

    def message(self, identifier):
        message = self._messages.get(identifier)
        if message is None:
            return None
        return dict(deepcopy(message), revision=self._revisions[identifier])

    def resolve(self, identifier):
        message = self.message(identifier)
        if message is not None:
            key = self._keys[identifier]
            revision = self.thread_revision(key)
            cached = self._fields.get(key)
            if cached is None or cached[0] != revision:
                from .history_queries import thread_fields
                lines = [self._messages[i] for i in self.ids(key)]
                cached = self._fields[key] = (revision, thread_fields(lines, self._undos, self._resolved_native))
            # Answers and branches can change when a different post is edited or deleted.
            message.update(deepcopy(cached[1].get(identifier, {'branch': None})), revision=revision)
            return message
        revision = self._revisions.get(identifier)
        return {'msg_id': identifier, 'deleted': True, 'revision': revision} if revision is not None else None

    def undo(self, identifier):
        return deepcopy(self._undos.get(identifier))

    def receipt(self, client_message_id):
        entry = self._receipts.get(client_message_id)
        if entry is None:
            return {'client_msg_id': client_message_id, 'status': 'not_found'}
        identifier, original = entry
        key = self._keys[identifier]
        return {'client_msg_id': client_message_id,
                'status': 'accepted' if identifier in self._messages else 'deleted',
                'msg_id': identifier, 'seq': original,
                'key': {'room': key[0], 'thread': key[1]}}

    def thread_keys(self, room):
        # Direct-room screen order: original root sequence, not latest edit sequence.
        return sorted(self._rooms.get(room, ()), key=lambda key: self._threads[key][0])

    def ids(self, key):
        return (identifier for _, identifier in self._threads.get(key, ()))

    def thread_revision(self, key):
        return self._thread_revisions.get(key, 0)

    def page(self, key, *, before=None, limit=50):
        """Latest/older original-sequence window; no journal replay or full copying."""
        if type(limit) is not int or not 1 <= limit <= 50:
            raise ValueError('invalid_limit')
        if before is not None and (type(before) is not int or before < 1):
            raise ValueError('invalid_cursor')
        entries = self._threads.get(key, ())
        end = len(entries) if before is None else bisect_left(entries, (before, ''))
        start = max(0, end - limit)
        selected = entries[start:end]
        return {'through': self.head,
                'items': [self.message(identifier) for _, identifier in selected],
                'before': selected[0][0] if start and selected else None,
                'complete': start == 0}


# Limits are shared by cursor management and the HTTP response encoder.
PAGE_ITEMS = 50
PAGE_BYTES = 512 * 1024
CONTENT_CHUNK_BYTES = 256 * 1024
SNAPSHOT_BYTES = 8 * 1024 * 1024
SNAPSHOT_COUNT = 8
SNAPSHOT_SECONDS = 60


class HistoryError(ValueError):
    def __init__(self, code, status=400):
        super().__init__(code)
        self.code, self.status = code, status


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()


class HistorySession:
    """Connection-owned opaque cursors; membership frozen, contents stay current.

    This object is released on disconnect. It neither grants authorization nor
    writes state. The HTTP boundary must validate its authenticated connection.
    """
    def __init__(self, index, *, clock=None):
        self.index = index
        self.token = secrets.token_urlsafe(32)
        self._secret = secrets.token_bytes(32)
        self.through = index.head
        self.clock = clock or time.monotonic
        self._snapshots = {}
        self.contexts = {}
        self.generation = -1

    def set_context(self, document, rooms):
        generation = document['generation']
        if generation <= self.generation:
            # Retried context installation is idempotent, but cannot overwrite a
            # newer generation with a late HTTP response/request.
            for context in self.contexts.values():
                if context.document == document and generation == self.generation:
                    return context
            raise HistoryError('stale_context', 409)
        context = HistoryContext(document, rooms)
        self.contexts[context.token] = context
        self.generation = generation
        while len(self.contexts) > 2:
            removed = next(iter(self.contexts))
            self.contexts.pop(removed)
            self._snapshots = {key: snap for key, snap in self._snapshots.items()
                               if snap.get('context', snap['binding'][0]) != removed}
        return context

    def context(self, token):
        context = self.contexts.get(token)
        if context is None:
            raise HistoryError('stale_context', 409)
        return context

    def _purge(self):
        now = self.clock()
        self._snapshots = {k: v for k, v in self._snapshots.items() if v['expires'] > now}

    def _snapshot(self, context, key, kind, limit, cursor, anchor=None):
        self._purge()
        if cursor is not None:
            if not isinstance(cursor, str):
                raise HistoryError('invalid_query')
            # Offset is encoded in a server-owned map, never accepted from callers.
            for token, snap in self._snapshots.items():
                if cursor in snap['cursors']:
                    if (context, key, kind, limit, anchor) != snap['binding']:
                        raise HistoryError('cursor_expired', 409)
                    return token, snap, snap['cursors'][cursor]
            raise HistoryError('cursor_expired', 409)
        remaining = SNAPSHOT_BYTES - sum(s['bytes'] for s in self._snapshots.values())
        identifiers, size = [], 0
        for identifier in self.index.ids(key):
            size += len(identifier.encode()) + 8
            if size > remaining:
                raise HistoryError('unavailable', 503)
            identifiers.append(identifier)
        if anchor is not None and anchor not in identifiers:
            raise HistoryError('target_missing', 404)
        end = min(len(identifiers), identifiers.index(anchor) + limit) if anchor is not None else len(identifiers)
        token = secrets.token_urlsafe(32)
        snap = {'ids': identifiers, 'bytes': size,
                'expires': self.clock() + SNAPSHOT_SECONDS,
                'binding': (context, key, kind, limit, anchor), 'cursors': {},
                'revision': self.index.thread_revision(key), 'lowest_seen': len(identifiers)}
        if kind == 'copy' or end > limit:
            if len(self._snapshots) >= SNAPSHOT_COUNT:
                raise HistoryError('unavailable', 503)
            self._snapshots[token] = snap
        return token, snap, end

    def messages(self, *, context, request, key, limit=PAGE_ITEMS, cursor=None, copy=False, anchor=None):
        if type(limit) is not int or not 1 <= limit <= PAGE_ITEMS:
            raise HistoryError('invalid_query')
        kind = 'copy' if copy else 'messages'
        token, snap, end = self._snapshot(context, key, kind, limit, cursor, anchor)
        if copy and snap['revision'] != self.index.thread_revision(key):
            raise HistoryError('stale_content', 409)
        result = {'session': self.token, 'context': context, 'request': request,
                  'through': self.index.head, 'items': [], 'next': None, 'complete': False}
        # Reuse a token for the same offset so retries do not grow cursor storage.
        def before(offset):
            for candidate, position in snap['cursors'].items():
                if position == offset:
                    return candidate
            candidate = secrets.token_urlsafe(32)
            snap['cursors'][candidate] = offset
            return candidate
        start = max(0, end - limit)
        # Membership must not change on retry when edited bodies grow. Keep the
        # same ID window and replace large individual values with content refs.
        allowance = (PAGE_BYTES - len(encoded(result)) - 1024) // limit
        for identifier in snap['ids'][start:end]:
            item = self.index.resolve(identifier)
            if item is None:
                raise HistoryError('unavailable', 503)
            if len(encoded(item)) > allowance:
                item = {'msg_id': identifier, 'revision': item['revision'],
                        'contentRef': self.content_ref(identifier, item['revision'])}
            result['items'].append(item)
        result.update(next=before(start) if start else None, complete=start == 0,
                      newerCount=len(snap['ids'])-end)
        if copy:
            result['copyRef'] = token
        if len(encoded(result)) > PAGE_BYTES:
            raise HistoryError('too_large', 413)
        if end >= snap['lowest_seen']:
            snap['lowest_seen'] = min(start, snap['lowest_seen'])
        return result

    def content_ref(self, identifier, revision):
        # Signed references are bounded: no per-message/session lookup allocation.
        payload = encoded([identifier, revision])
        signature = hmac.new(self._secret, payload, hashlib.sha256).digest()
        return base64.urlsafe_b64encode(signature + payload).decode()

    def content(self, reference, cursor=None, *, rooms=None):
        try:
            if not isinstance(reference, str) or len(reference) > 65536:
                raise ValueError()
            raw = base64.b64decode(reference.encode(), altchars=b'-_', validate=True)
            signature, payload = raw[:32], raw[32:]
            if not hmac.compare_digest(signature, hmac.new(self._secret, payload, hashlib.sha256).digest()):
                raise ValueError()
            identifier, revision = json.loads(payload)
            if not isinstance(identifier, str) or type(revision) is not int:
                raise ValueError()
        except (ValueError, TypeError, UnicodeError):
            raise HistoryError('invalid_query') from None
        key = self.index._keys.get(identifier)
        if rooms is not None and (key is None or key[0] not in rooms):
            raise HistoryError('target_missing', 404)
        message = self.index.resolve(identifier)
        if message is None or message.get('deleted'):
            raise HistoryError('target_missing', 404)
        if message['revision'] != revision:
            raise HistoryError('stale_content', 409)
        data = encoded(message)
        offset = 0
        if cursor is not None:
            # Same signing helper binds chunk offset to this content reference.
            try:
                position, signature = cursor.split('.', 1)
                offset = int(position)
                expected = hmac.new(self._secret, (reference + ':' + position).encode(), hashlib.sha256).hexdigest()
                if not hmac.compare_digest(signature, expected) or not 0 <= offset < len(data):
                    raise ValueError()
            except (ValueError, TypeError, AttributeError):
                raise HistoryError('cursor_expired', 409) from None
        end = min(len(data), offset + CONTENT_CHUNK_BYTES)
        following = None
        if end < len(data):
            signature = hmac.new(self._secret, (reference + ':' + str(end)).encode(), hashlib.sha256).hexdigest()
            following = str(end) + '.' + signature
        return {'session': self.token, 'revision': revision, 'offset': offset, 'totalBytes': len(data),
                'sha256': hashlib.sha256(data).hexdigest(), 'next': following,
                'data': base64.b64encode(data[offset:end]).decode()}

    def rows(self, document, values, *, older=False, freeze=False, totals=None):
        self._purge()
        binding = encoded({k: v for k, v in document.items() if k not in ('request', 'cursor')}).decode()
        limit = document.get('limit', PAGE_ITEMS)
        current = {row_identity(item): item for item in values}
        cursor = document.get('cursor')
        found = next(((token, snap) for token, snap in self._snapshots.items()
                      if cursor is not None and cursor in snap['cursors']), None)
        if cursor is not None and found is None:
            raise HistoryError('cursor_expired', 409)
        if found:
            token, snap = found
            if snap['binding'] != binding:
                raise HistoryError('cursor_expired', 409)
            offset = snap['cursors'][cursor]
            if freeze:
                current = snap['values']
        else:
            identifiers = list(current)
            size = len(encoded(current if freeze else identifiers))
            retain = len(identifiers) > limit
            if retain and (len(self._snapshots) >= SNAPSHOT_COUNT or size + sum(x['bytes'] for x in self._snapshots.values()) > SNAPSHOT_BYTES):
                raise HistoryError('unavailable', 503)
            offset = len(identifiers) if older else 0
            anchor = document.get('anchor')
            if anchor is not None:
                matches = [i for i, item in enumerate(values) if item.get('id') == anchor
                           or item.get('key', {}).get('thread') == anchor]
                if len(matches) != 1:
                    raise HistoryError('target_missing', 404)
                offset = min(len(identifiers), matches[0]+limit) if older else matches[0]
            token = secrets.token_urlsafe(32)
            snap = {'binding': binding, 'context': document['context'], 'ids': identifiers,
                    'bytes': size, 'expires': self.clock() + SNAPSHOT_SECONDS, 'cursors': {},
                    'through': self.index.head, 'values': deepcopy(current) if freeze else None}
            if retain:
                self._snapshots[token] = snap
        start, end = (max(0, offset-limit), offset) if older else (offset, min(offset+limit, len(snap['ids'])))
        next_offset = start if older else end
        complete = start == 0 if older else end == len(snap['ids'])
        following = None
        if not complete:
            following = next((c for c, pos in snap['cursors'].items() if pos == next_offset), None)
            if following is None:
                following = secrets.token_urlsafe(32)
                snap['cursors'][following] = next_offset
        result = {'session': self.token, 'context': document['context'], 'request': document['request'],
                  'through': snap['through'] if freeze else self.index.head,
                  'items': [current.get(identifier, {'id': identifier, 'removed': True, 'revision': self.index.head})
                            for identifier in snap['ids'][start:end]], 'next': following, 'complete': complete}
        if totals is not None:
            result['totals'] = totals
        if len(encoded(result)) > PAGE_BYTES:
            raise HistoryError('too_large', 413)
        return result

    def finish_copy(self, reference, *, context=None, key=None):
        self._purge()
        snap = self._snapshots.get(reference)
        if snap is None or snap['binding'][2] != 'copy':
            raise HistoryError('cursor_expired', 409)
        if context is not None and (snap['binding'][0] != context or snap['binding'][1] != key):
            raise HistoryError('cursor_expired', 409)
        if self.index.thread_revision(snap['binding'][1]) != snap['revision']:
            raise HistoryError('stale_content', 409)
        if snap['lowest_seen'] != 0:
            raise HistoryError('incomplete_copy', 409)
        return {'complete': True, 'revision': snap['revision']}


class HistoryContext:
    """Validated presentation input, not a member-state store or authorization grant."""
    def __init__(self, document, rooms):
        import math
        def finite(value):
            try:
                return math.isfinite(value)
            except OverflowError:
                return False
        if not finite(document['now']):
            raise HistoryError('invalid_query')
        if not set(document['home'] + document['hidden']).issubset(rooms):
            raise HistoryError('invalid_query')
        if not set(document['names']).issubset(rooms):
            raise HistoryError('invalid_query')
        items = document['items']
        if len(encoded(items)) > 1024 * 1024:
            raise HistoryError('too_large', 413)
        for key, entry in items.items():
            value = entry['v']
            if (len(key.encode()) > 200 or len(entry['dev'].encode()) > 200
                    or '\n' in entry['dev'] or not finite(entry['at'])
                    or value is not None and len(value.encode()) > 4096):
                raise HistoryError('invalid_query')
            if key.startswith(('read:', 'thread:', 'bell:')) and value is not None:
                if (not value.isascii() or not value.isdecimal() or len(value) > 16
                        or int(value) > 2 ** 53 - 1):
                    raise HistoryError('invalid_query')
        self.token = secrets.token_urlsafe(32)
        self.document = deepcopy(document)

    def value(self, key):
        return self.document['items'].get(key, {}).get('v')

    def read(self, key):
        return int(self.value(key) or 0)


def row_identity(item):
    key = item.get('key')
    return encoded([key, item.get('id')]).decode() if key else item['id']
