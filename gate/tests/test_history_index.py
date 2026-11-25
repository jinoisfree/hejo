"""History projection: durable commit/recovery, deletion and bounded older pages."""
from copy import deepcopy
from unittest.mock import patch
import pytest
from gate.journal import Journal, HejoJournalError


def message(identifier, *, thread='fixture-thread', room=None, role='employee', **extra):
    return {'v': 1, 'type': 'message', 'msg_id': identifier, 'employee': 'fixture-employee',
            'thread': thread, 'role': role, 'text': 'fixture text', 'files': [], 'buttons': [],
            'reply_state': None, 'timestamp': '2026-01-01T00:00:00Z',
            **({'room': room} if room else {}), **extra}


@pytest.fixture
def journal(tmp_path, monkeypatch):
    monkeypatch.setenv('HERMES_HOME', str(tmp_path))
    value = Journal(tmp_path)
    value.open()
    try:
        yield value
    finally:
        value.close()


@pytest.mark.asyncio
async def test_page_50_then_1_does_not_scan_journal(journal):
    for i in range(51):
        await journal.append(message(f'fixture-message-{i}'))
    key = ('fixture-employee', 'fixture-thread')
    with patch.object(journal, 'message', side_effect=AssertionError('full scan')):
        page = journal.history.page(key)
        assert [m['seq'] for m in page['items']] == list(range(2, 52))
        assert page['before'] == 2 and page['complete'] is False
        older = journal.history.page(key, before=2)
        assert [m['seq'] for m in older['items']] == [1]
        assert older['before'] is None and older['complete'] is True
        assert journal.history.page(key, before=1)['items'] == []
    for invalid in [0, 51, True, -1, 1.5]:
        with pytest.raises(ValueError):
            journal.history.page(key, limit=invalid)


@pytest.mark.asyncio
async def test_current_revision_public_fields_and_restart(journal):
    await journal.append(message('fixture-first', role='owner', client_msg_id='fixture-send'),
                         internal={'private': 'fixture-private'})
    await journal.append(message('fixture-second', thread='fixture-other'))
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-first', 'text': 'edited'})
    await journal.append({'v': 1, 'type': 'state', 'msg_id': 'fixture-first', 'reply_state': 'answered'})
    expected = journal.public(journal.message('fixture-first'))
    projected = journal.history.message('fixture-first')
    assert projected == dict(expected, revision=4)
    assert projected['seq'] == 1
    assert '_meta' not in projected
    projected['text'] = 'caller mutation'
    assert journal.history.message('fixture-first')['text'] == 'edited'
    assert journal.history.thread_keys('fixture-employee') == [
        ('fixture-employee', 'fixture-thread'), ('fixture-employee', 'fixture-other')]
    before = deepcopy(journal.history.page(('fixture-employee', 'fixture-thread')))
    journal._recover()
    assert journal.history.page(('fixture-employee', 'fixture-thread')) == before
    assert journal.history.receipt('fixture-send')['status'] == 'accepted'


@pytest.mark.asyncio
@pytest.mark.parametrize('scope', ['message', 'thread', 'room'])
async def test_deletion_tombstones_receipts_and_late_edit(journal, scope):
    await journal.append(message('fixture-first', room='fixture-room', role='owner',
                                 client_msg_id='fixture-send'))
    await journal.append(message('fixture-second', room='fixture-room'))
    if scope == 'room':
        deletion = {'v': 1, 'type': 'room_delete', 'room': 'fixture-room'}
    else:
        deletion = {'v': 1, 'type': 'delete', 'msg_id': 'fixture-first'}
        if scope == 'thread':
            deletion.update(scope='thread', room='fixture-room', thread='fixture-thread')
    await journal.append(deletion)
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-first', 'text': 'must not resurrect'})
    assert journal.history.resolve('fixture-first') == {
        'msg_id': 'fixture-first', 'deleted': True, 'revision': 3}
    assert journal.history.resolve('fixture-missing') is None
    assert journal.history.receipt('fixture-send')['status'] == 'deleted'
    assert journal.history.receipt('fixture-unsent')['status'] == 'not_found'
    page = journal.history.page(('fixture-room', 'fixture-thread'))
    assert [m['msg_id'] for m in page['items']] == (['fixture-second'] if scope == 'message' else [])
    journal._recover()
    assert journal.history.page(('fixture-room', 'fixture-thread')) == page


@pytest.mark.asyncio
async def test_failed_commit_does_not_publish_projection(journal):
    await journal.append(message('fixture-first'))
    before = journal.history.page(('fixture-employee', 'fixture-thread'))
    with patch('gate.journal.os.write', side_effect=OSError('fixture disk failure')):
        with pytest.raises(HejoJournalError, match='journal_write_failed'):
            await journal.append(message('fixture-second'))
    assert journal.history.head == journal.head == 1
    assert journal.history.page(('fixture-employee', 'fixture-thread')) == before
    journal._recover()
    assert journal.history.page(('fixture-employee', 'fixture-thread')) == before


@pytest.mark.asyncio
async def test_cursor_membership_revision_context_and_expiry(journal):
    from gate.history import HistorySession, HistoryError
    for i in range(3):
        await journal.append(message(f'fixture-{i}'))
    clock = [0]
    session = HistorySession(journal.history, clock=lambda: clock[0])
    key = ('fixture-employee', 'fixture-thread')
    page = session.messages(context='fixture-context', request='fixture-request', key=key, limit=1)
    assert [m['msg_id'] for m in page['items']] == ['fixture-2']
    await journal.append(message('fixture-new'))
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-1', 'text': 'latest'})
    await journal.append({'v': 1, 'type': 'delete', 'msg_id': 'fixture-0'})
    args = dict(context='fixture-context', request='fixture-request', key=key, limit=1, cursor=page['next'])
    older = session.messages(**args)
    assert older['items'][0]['text'] == 'latest'
    assert session.messages(**args) == older
    final = session.messages(**dict(args, cursor=older['next']))
    assert final['items'] == [{'msg_id': 'fixture-0', 'deleted': True, 'revision': 6}]
    assert final['complete'] and final['next'] is None
    for invalid in [dict(args, context='other'), dict(args, limit=2), dict(args, key=('other', 'thread'))]:
        with pytest.raises(HistoryError, match='cursor_expired'):
            session.messages(**invalid)
    with pytest.raises(HistoryError, match='cursor_expired'):
        HistorySession(journal.history).messages(**args)
    clock[0] = 60
    with pytest.raises(HistoryError, match='cursor_expired'):
        session.messages(**args)


@pytest.mark.asyncio
async def test_large_content_chunks_cannot_mix_revisions(journal):
    import base64
    import hashlib
    import json
    from gate.history import HistorySession, HistoryError, encoded
    # A composed current value can exceed one history page; use a synthetic index
    # fixture here, not an oversized live frame or a performance workload.
    await journal.append(message('fixture-large', text='가' * 180000))
    session = HistorySession(journal.history)
    page = session.messages(context='fixture-context', request='fixture-request',
                            key=('fixture-employee', 'fixture-thread'))
    assert len(encoded(page)) <= 512 * 1024
    item = page['items'][0]
    assert 'text' not in item and 'contentRef' in item
    first = session.content(item['contentRef'])
    assert len(encoded(first)) <= 512 * 1024
    data = base64.b64decode(first['data'])
    next_cursor = first['next']
    while next_cursor:
        chunk = session.content(item['contentRef'], next_cursor)
        assert chunk['offset'] == len(data)
        data += base64.b64decode(chunk['data'])
        next_cursor = chunk['next']
    assert hashlib.sha256(data).hexdigest() == first['sha256']
    assert json.loads(data)['text'] == '가' * 180000
    with pytest.raises(HistoryError, match='invalid_query'):
        HistorySession(journal.history).content(item['contentRef'])
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-large', 'text': 'new'})
    with pytest.raises(HistoryError, match='stale_content'):
        session.content(item['contentRef'], first['next'])


@pytest.mark.asyncio
async def test_snapshot_capacity_and_copy_finalize(journal):
    from gate.history import HistorySession, HistoryError
    await journal.append(message('fixture-first'))
    session = HistorySession(journal.history)
    args = dict(context='fixture-context', request='fixture-request', key=('fixture-employee', 'fixture-thread'))
    page = session.messages(**args, copy=True)
    assert session.finish_copy(page['copyRef']) == {'complete': True, 'revision': 1}
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-first', 'text': 'new'})
    with pytest.raises(HistoryError, match='stale_content'):
        session.finish_copy(page['copyRef'])
    # Complete normal pages have no cursor/finalize reference to retain.
    for _ in range(12):
        assert session.messages(**args)['complete']
    # Copy references still retain snapshots, even with only one message.
    for _ in range(7):
        session.messages(**args, copy=True)
    with pytest.raises(HistoryError, match='unavailable'):
        session.messages(**args, copy=True)


@pytest.mark.asyncio
async def test_retry_keeps_page_ids_when_edit_grows_and_copy_requires_all_pages(journal):
    from gate.history import HistorySession, HistoryError
    for i in range(4):
        await journal.append(message(f'fixture-{i}'))
    session = HistorySession(journal.history)
    args = dict(context='fixture-context', request='fixture-request', key=('fixture-employee', 'fixture-thread'), limit=2)
    first = session.messages(**args)
    before = session.messages(**args, cursor=first['next'])
    await journal.append({'v': 1, 'type': 'edit', 'msg_id': 'fixture-1', 'text': '가' * 180000})
    after = session.messages(**args, cursor=first['next'])
    assert [m['msg_id'] for m in before['items']] == [m['msg_id'] for m in after['items']]
    assert 'contentRef' in after['items'][1]
    copied = session.messages(**args, copy=True)
    with pytest.raises(HistoryError, match='incomplete_copy'):
        session.finish_copy(copied['copyRef'])
    session.messages(**args, copy=True, cursor=copied['next'])
    assert session.finish_copy(copied['copyRef'])['complete']
