"""Member-context projection of complete journal threads for partial clients.

Policies mirror ConversationModel, ThreadAssessment and WorkspaceSearch. The
client owns member-state writes; this module returns read plans, never writes.
"""
import asyncio
from datetime import datetime, timezone
import re
import unicodedata
from .history import HistoryError
from .history_search import clusters, ranges, snippet

YES = {'승인','전송','발송','발송해','승인, 발송해','응','응응','ㅇㅇ','네','예','좋아','진행','그래','오케이','ok','yes'}
PATTERNS = {name: re.compile(pattern) for name, pattern in {'nothingWaiting': '승인(을|이)?\\s*(기다리는|해\\s*주실|해\\s*줄|할|받을|드릴)[^\\n.!?]{0,14}없', 'approval1': '승인(을|이)?\\s*((만|좀|다시|한\\s*번\\s*더)\\s*)*(하면|해\\s*줘(?!서)|해\\s*주|해\\s*줄래|해\\s*\\?|부탁|기다|필요|요청|할래|할까|바라|받아야|줘(?!서)|주면)', 'approval2': '승인[^\\n.!?]{0,14}?(이?라고|한\\s*마디)만?\\s*((다시|한\\s*번(\\s*더|만)?|정확히|꼭|바로|그냥)\\s*)*(((답(장|변)?|말씀?|입력)\\s*)?(해((?![가-힣])|\\s*(줘(?!서)|주))|하면)|(보내|적어|남겨|써|알려)((?![가-힣])|\\s*(줘(?!서)|주))|보내면|적으면|남기면|쓰면)'} .items()}


def thinking(text):
    return re.search(r'^[◐◓◑◒🤔\s]*생각\s*중\s*(\.{2,}|…)?\s*$', text.split('\n')[0]) is not None


def prefix(text, count):
    return ''.join(clusters(text, limit=count))


def stamp(text):
    try:
        value = datetime.fromisoformat(text.replace('Z', '+00:00'))
        return value.replace(tzinfo=timezone.utc).timestamp() if value.tzinfo is None else value.timestamp()
    except (ValueError, OverflowError):
        return -62135769600.0  # Foundation Date.distantPast (0001-01-01 UTC).


def approval(text):
    own = '\n'.join(line for line in text.split('\n') if not line.lstrip().startswith('>'))
    return (not PATTERNS['nothingWaiting'].search(own)
            and bool(PATTERNS['approval1'].search(own) or PATTERNS['approval2'].search(own)))


def trimmed_answer(text):
    while text and (text[0].isspace() or unicodedata.category(text[0]).startswith('P')):
        text = text[1:]
    while text and (text[-1].isspace() or unicodedata.category(text[-1]).startswith('P')):
        text = text[:-1]
    return text.lower()


def assess(lines, context):
    posts = [p for p in lines if p['role'] == 'owner' or not thinking(p['text'])]
    asks = [i for i, p in enumerate(posts) if p['role'] == 'employee'
            and (p.get('reply_state') is not None or p.get('buttons') or p.get('checklist') is not None or approval(p['text']))]
    result = {'requestID': None, 'pendingID': None, 'working': False, 'settled': False, 'approved': False}
    if not asks:
        return result, set(), posts
    # First qualifying owner response after each post, in one reverse pass.
    answers, targeted, general = {}, {}, None
    employees_after = [False] * len(posts)
    seen_employee = False
    for i in range(len(posts)-1, -1, -1):
        post = posts[i]
        candidates = [value for value in (general, targeted.get(post['msg_id'])) if value is not None]
        answers[i] = min(candidates, default=None)
        employees_after[i] = seen_employee
        if post['role'] == 'employee' and post.get('final') is not False:
            seen_employee = True
        if post['role'] == 'owner':
            if post.get('answer_to') is None:
                general = i
            else:
                targeted[post['answer_to']] = i
    def answer(i):
        return answers[i]
    last = asks[-1]
    asked = last if answer(last) is None else next((i for i in reversed(asks) if answer(i) is None and posts[i].get('buttons')), last)
    request, answered = posts[asked], answer(asked)
    said = trimmed_answer(posts[answered]['text']) if answered is not None else ''
    finished = answered is not None and employees_after[answered]
    result['requestID'] = request['msg_id']
    if finished or request.get('reply_state') == 'closed':
        result['settled'] = True
    elif request.get('reply_state') == 'answered':
        result['working'] = True
    elif answered is None:
        if context.value('confirm:' + request['msg_id']) is None:
            result['pendingID'] = request['msg_id']
    else:
        result['approved'] = said in YES
    waiting = {p['msg_id'] for i, p in enumerate(posts) if p['role'] == 'employee'
               and p.get('buttons') and p.get('reply_state') not in ('answered', 'closed') and answer(i) is None}
    if len(waiting) < 2:
        waiting = {result['pendingID']} if result['pendingID'] else set()
    return result, waiting, posts


def normalized(text):
    return unicodedata.normalize('NFC', text.strip()).lower()


def state_label(state):
    return '답을 기다리는 중' if state == 'asked' else '처리 완료' if state in ('answered', 'closed') else state


def words(message, names, *, sidebar=False):
    state = message.get('reply_state')
    label = (state_label(state) + ('' if sidebar else ' ' + state)) if state else ''
    return '\n'.join([message['text']] + [f['name'] for f in message.get('files', [])]
                     + ['나' if message['role'] == 'owner' else names.get(message['employee'], message['employee']), label])


def search_hit(message, key, query):
    # Presentation only: no message type/body/files that could enter the body cache.
    terms = normalized(query).split()
    notes = []
    if terms and not all(term in normalized(message['text']) for term in terms):
        candidates = ['📎 ' + f['name'] for f in message.get('files', [])]
        candidates.append(state_label(message.get('reply_state') or ''))
        notes = [note for note in candidates if any(term in normalized(note) for term in terms)]
    return {'id': message['msg_id'], 'key': {'room': key[0], 'thread': key[1]},
            'snippet': snippet(message['text'], query), 'notes': notes,
            'role': message['role'], 'speaker': message['employee'], 'timestamp': message['ts'],
            'revision': message['revision']}


class HistoryQueries:
    def __init__(self, index, context):
        self.index, self.context = index, context
        self.cache = {}

    async def summary(self, key):
        revision = self.index.thread_revision(key)
        cached = self.cache.get(key)
        if cached is not None and cached[0] == revision:
            return cached[1]
        lines = []
        for number, identifier in enumerate(list(self.index.ids(key))):
            message = self.index.message(identifier)
            if message is not None:
                lines.append(message)
            if number % 50 == 49:
                await asyncio.sleep(0)
        if self.index.thread_revision(key) != revision:
            raise HistoryError('unavailable', 503)
        if not lines:
            self.cache.pop(key, None)
            return None
        root, last = lines[0], lines[-1]
        state, buttons, posts = assess(lines, self.context)
        original = max(p['seq'] for p in lines)
        read = max(self.context.read('read:' + key[0]), self.context.read('thread:' + key[0] + '/' + key[1]))
        unread = sum(p['role'] == 'employee' and p['seq'] > read and not thinking(p['text']) for p in lines)
        confirmed = state['requestID'] and self.context.value('confirm:' + state['requestID']) is not None
        bell_read = self.context.read('bell:' + key[0] + '/' + key[1])
        notice = None
        expires = None
        if posts and posts[-1]['role'] != 'owner' and not state['working'] and not state['settled'] and not confirmed and bell_read < original:
            if state['pendingID']:
                asked = next(p for p in posts if p['msg_id'] == state['pendingID'])
                speaker = asked['employee']
                notice = {'id': asked['msg_id'], 'group': 'question:' + speaker, 'questions': True,
                          'title': self.context.document['names'].get(speaker, speaker) + ' 질문'}
            elif state['requestID'] is None and posts[0]['role'] == 'employee' and not any(p['role'] == 'owner' for p in posts):
                begin = stamp(posts[0]['ts'])
                now = self.context.document['now']
                if now < begin:
                    expires = begin
                elif now < begin + 86400:
                    expires = begin + 86400
                    notice = {'id': posts[0]['msg_id'], 'group': 'alert', 'questions': False, 'title': '알림'}
        if notice:
            source = next(p for p in lines if p['msg_id'] == notice['id'])
            lines_with_text = (line for line in source['text'].splitlines() if line.strip())
            preview = next(lines_with_text, '')
            words = preview.split()
            if words and all(word.startswith('@') and len(word) > 1 for word in words):
                next_line = next(lines_with_text, '')
                if next_line:
                    preview += ' · ' + next_line
            notice.update(speaker=source['employee'], timestamp=source['ts'], preview=prefix(preview, 300))
        bell = None
        if not state['working'] and not state['settled'] and not confirmed:
            if self.context.value('bell:' + key[0] + '/' + key[1]) is not None and bell_read >= original:
                bell = False
            elif notice:
                bell = True
        title = root['text'] or next((f['name'] for f in root.get('files', [])), '대화')
        result = {'key': {'room': key[0], 'thread': key[1]}, 'rootID': root['msg_id'],
                  'rootRole': root['role'], 'rootSeq': root['seq'], 'rootTime': root['ts'], 'latestSeq': max(p['revision'] for p in lines),
                  'sidebarActivity': max((stamp(p['ts']) if stamp(p['ts']) != -62135769600.0 else p['revision']) for p in lines),
                  'originalMaxSeq': original, 'lastTime': max((p['ts'] for p in lines), key=stamp),
                  'title': prefix(title, 48).replace('\n', ' '), 'preview': prefix(last['text'], 80),
                  'rootPreview': prefix(root['text'], 240), 'messageCount': len(lines), 'unread': unread,
                  'assessment': state, 'bell': bell, 'waitingButtonCount': len(buttons), 'revision': revision,
                  'notice': notice, 'nextNoticeExpiry': expires,
                  'activity': {
                      'lastSpeaker': next((p['employee'] for p in reversed(lines) if p['role'] != 'owner'), None),
                      'working': any(p['role'] != 'owner' and (p.get('final') is False or
                                     p.get('final') is not True and thinking(p['text'])) for p in lines),
                      'latestEmployeeTime': max((stamp(p['ts']) for p in lines if p['role'] == 'employee'), default=None)}}
        self.cache[key] = (revision, result)
        return result

    async def summaries(self, rooms):
        head = self.index.head
        result = []
        for room in rooms:
            for key in self.index.thread_keys(room):
                item = await self.summary(key)
                if item is not None:
                    result.append(item)
            await asyncio.sleep(0)
        if self.index.head != head:
            raise HistoryError('unavailable', 503)
        return result

    @staticmethod
    def notices(summaries):
        result = []
        groups = []
        ordered = sorted(summaries, key=lambda s: (stamp(s['rootTime']), s['rootSeq']))
        for summary in ordered:
            if summary['notice']:
                item = dict(summary['notice'], key=summary['key'], revision=summary['revision'])
                if item['group'] not in groups:
                    groups.append(item['group'])
                result.append(item)
        return sorted(result, key=lambda item: (not item['questions'], groups.index(item['group'])))

    async def questions(self, rooms):
        # Island asked-state is deliberately broader than actionable notices.
        head, result = self.index.head, []
        for room in rooms:
            for key in self.index.thread_keys(room):
                for number, identifier in enumerate(list(self.index.ids(key))):
                    message = self.index.message(identifier)
                    if (message is not None and message['role'] == 'employee'
                            and message.get('reply_state') == 'asked'
                            and self.context.value('confirm:' + identifier) is None):
                        first = next((line for line in message['text'].splitlines() if line), '')
                        result.append({'id': identifier, 'key': {'room': key[0], 'thread': key[1]},
                                       'seq': message['seq'], 'revision': message['revision'],
                                       'speaker': message['employee'], 'preview': prefix(first, 24)})
                    if number % 50 == 49:
                        await asyncio.sleep(0)
        if self.index.head != head:
            raise HistoryError('unavailable', 503)
        return sorted(result, key=lambda row: row['seq'])

    async def search(self, query, rooms, mode):
        term = query.strip() if mode == 'room' else normalized(query)
        if not term:
            return []
        terms, names = term.split(), self.context.document['names']
        head = self.index.head
        matches = []
        for room in rooms:
            if mode == 'groups' and room in self.context.document['hidden']:
                continue
            for key in self.index.thread_keys(room):
                for number, identifier in enumerate(list(self.index.ids(key))):
                    message = self.index.message(identifier)
                    if message is not None:
                        haystack = normalized(words(message, names, sidebar=mode == 'sidebar'))
                        if mode == 'room':
                            locale = self.context.document.get('locale')
                            if locale is None:
                                raise HistoryError('invalid_query')
                            matched = bool(ranges(message['text'], term, locale))
                        else:
                            matched = term in haystack or mode == 'groups' and all(t in haystack for t in terms)
                        if matched and (mode != 'groups' or not thinking(message['text'])):
                            matches.append((message, key, term in haystack))
                    if number % 50 == 49:
                        await asyncio.sleep(0)
        if head != self.index.head:
            raise HistoryError('unavailable', 503)
        if mode == 'room':
            keys = dict.fromkeys(key for _, key, _ in matches)
            result = [await self.summary(key) for key in keys]
            if head != self.index.head:
                raise HistoryError('unavailable', 503)
            return sorted(result, key=lambda item: (-item['latestSeq'], item['key']['thread']))
        matches.sort(key=lambda value: (stamp(value[0]['ts']), value[0]['msg_id']), reverse=True)
        matches = matches[:30 if mode == 'sidebar' else 200]
        if mode == 'sidebar':
            return [search_hit(m, k, query) for m, k, _ in matches]
        grouped = {}
        for message, key, exact in matches:
            item = grouped.setdefault(key, {'key': {'room': key[0], 'thread': key[1]}, 'matches': [], 'exact': False,
                                           'latest': message['ts']})
            item['matches'].append(search_hit(message, key, query))
            item['exact'] |= exact
        for key, item in grouped.items():
            item['root'] = await self.summary(key)
            item['rootSnippet'] = snippet(self.index.message(item['root']['rootID'])['text'], query)
        if head != self.index.head:
            raise HistoryError('unavailable', 503)
        return sorted(grouped.values(), key=lambda item: (item['exact'], stamp(item['latest']),
                      item['key']['room'] + ':' + item['key']['thread']), reverse=True)

    async def read_plan(self, rooms, action, target=None):
        if not self.context.document['ready']:
            raise HistoryError('state_not_ready', 409)
        summaries = await self.summaries(rooms)
        notices = self.notices(summaries)
        changes = {}
        def thread_key(item):
            return item['key']['room'] + '/' + item['key']['thread']
        if action in ('thread', 'notice'):
            selected = next((s for s in summaries if s['key'] == target), None)
            if selected is None:
                raise HistoryError('target_missing', 404)
            changes['thread:' + thread_key(selected)] = str(selected['originalMaxSeq'])
            if action == 'notice':
                changes['bell:' + thread_key(selected)] = str(selected['originalMaxSeq'])
        elif action == 'seed':
            for room in rooms:
                if 'read:' + room not in self.context.document['items']:
                    seen = any(k.startswith('thread:' + room + '/') for k in self.context.document['items'])
                    changes['read:' + room] = str(0 if seen else max((s['originalMaxSeq'] for s in summaries if s['key']['room'] == room), default=0))
        elif action in ('enter', 'mark_all'):
            for room in rooms:
                scoped = [s for s in summaries if s['key']['room'] == room]
                ringing = [s for s in scoped if s['notice']]
                for item in scoped:
                    if action == 'mark_all' or not item['notice']:
                        changes['thread:' + thread_key(item)] = str(item['originalMaxSeq'])
                newest = max((s['originalMaxSeq'] for s in scoped), default=0)
                cap = min((s['rootSeq']-1 for s in ringing), default=newest)
                changes['read:' + room] = str(min(newest, cap) if action == 'enter' else newest)
        elif action != 'all_notices':
            raise HistoryError('invalid_query')
        if action in ('all_notices', 'mark_all'):
            for notice in notices:
                if not notice['questions']:
                    item = next(s for s in summaries if s['key'] == notice['key'])
                    changes['bell:' + thread_key(item)] = str(item['originalMaxSeq'])
                    changes['thread:' + thread_key(item)] = str(item['originalMaxSeq'])
        return [{'id': key, 'value': value} for key, value in sorted(changes.items())]
