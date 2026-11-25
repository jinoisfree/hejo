"""Small original-app contract oracle and native cache faults; no load execution."""
import asyncio
import hashlib
import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo
import pytest
from gate.tests.history_baseline_semantics import rows, identifier
from gate.history import HistoryContext, HistoryIndex
from gate.history_queries import HistoryQueries

ROOT = Path(__file__).resolve().parents[2]
REFERENCE = ROOT / 'app/.build/history-contract-reference'
CURRENT = ROOT / 'app/.build/history-contract-current'
NOW = time.time()
STAMP = datetime.fromtimestamp(NOW, timezone.utc).isoformat().replace('+00:00', 'Z')


async def run(binary, mode, config, folder):
    folder.mkdir(parents=True, exist_ok=True)
    config_path = folder / 'input.json'
    config_path.write_text(json.dumps(config, ensure_ascii=False))
    process = await asyncio.create_subprocess_exec(str(binary), mode, str(config_path),
        env={**os.environ, 'HERMES_HOME': str(folder / 'fake-home'), 'TZ': config.get('zone', 'UTC')},
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), 30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        return stdout.decode()
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()


def fixture():
    # Same small input as TASK-01, with replay's canonical deleted-room frame.
    result = [{**row, 'type': 'room_deleted', 'id': row['room']} if row['type'] == 'room_delete' else dict(row)
              for row in rows()]
    # Keep fresh alerts fresh for original methods whose default Date() is wall-clock.
    # The very old question retains its original timestamp.
    for row in result:
        if row.get('ts') == '2026-01-01T00:00:00Z':
            row['ts'] = STAMP
    return result


def cases():
    rooms = ['alpha', 'beta', 'gamma', identifier(101)]
    initial = {'read:' + room: '0' for room in rooms}
    target = {'room': 'alpha', 'thread': identifier(1)}
    result = []
    for label, items in [('unread', initial), ('partial', {**initial, 'read:beta': '4',
            'thread:alpha/' + identifier(1): '3', 'bell:alpha/' + identifier(1): '3'})]:
        for action in ['enter', 'mark_all', 'thread', 'notice', 'all_notices']:
            result.append({'id': label + '-' + action, 'items': items, 'action': action,
                           'scope': 'alpha', 'target': target})
    for action in ['enter', 'mark_all', 'all_notices']:
        result.append({'id': 'home-' + action, 'items': initial, 'action': action,
                       'scope': '@home', 'target': target})
    result.append({'id': 'seed-empty', 'items': {}, 'action': 'seed', 'scope': '@home', 'target': target})
    result.append({'id': 'seed-existing-thread', 'items': {'thread:alpha/' + identifier(1): '3'},
                   'action': 'seed', 'scope': '@home', 'target': target})
    return result


async def reference(folder, zone='UTC'):
    output = folder / 'reference.json'
    await run(REFERENCE, 'reference', {'home': str(folder / 'app'), 'rows': fixture(),
              'cases': cases(), 'now': NOW, 'output': str(output), 'zone': zone}, folder)
    return json.loads(output.read_text())


def effective(items):
    return {key: str(value) for key, value in items.items()
            if key.startswith(('read:', 'thread:', 'bell:'))}


@pytest.mark.asyncio
async def test_read_plans_match_original_app_commands(tmp_path):
    expected = await reference(tmp_path / 'oracle')
    index = HistoryIndex()
    for row in fixture():
        index.apply(row)
    allowed = {'alpha', 'beta', 'gamma', identifier(101)}
    for case, wanted in zip(cases(), expected, strict=True):
        assert case['id'] == wanted['id']
        doc = {'session': 'fixture', 'generation': 1, 'memberRevision': 1, 'ready': True,
               'items': {key: {'v': value, 'at': 1, 'dev': 'fixture-device'} for key, value in case['items'].items()},
               'home': ['alpha', 'beta', 'gamma'], 'hidden': [], 'names': {r: r for r in allowed}, 'now': NOW}
        queries = HistoryQueries(index, HistoryContext(doc, allowed))
        # Seed is a roster-wide action; home reads use only the home membership.
        scope = sorted(allowed) if case['action'] == 'seed' else (doc['home'] if case['scope'] == '@home' else [case['scope']])
        plan = await queries.read_plan(scope, case['action'], case['target'])
        actual = dict(case['items'])
        for change in plan:
            key, value = change['id'], change['value']
            actual[key] = str(max(int(actual.get(key, '0')), int(value))) if key.startswith(('read:', 'thread:')) else value
        assert effective(actual) == effective(wanted['items']), (case['id'], actual, wanted['items'])
    (tmp_path / 'comparison.json').write_text(json.dumps({'matched': True, 'cases': [c['id'] for c in cases()],
        'referenceCommit': '8b873b974d3b4d6df3044f78116b3b4ec79d675f', 'scope': 'effective read/thread/bell values'}, indent=2))


@pytest.mark.asyncio
async def test_authenticated_copy_matches_original_app(gate, tmp_path, monkeypatch):
    # Force multiple small pages while using the real HTTP/WS session and finalizer.
    import gate.history as history_module
    original_page = history_module.HistorySession.messages
    def short_copy_page(session, **fields):
        if fields.get('copy'):
            fields['limit'] = min(fields.get('limit', 50), 2)
        return original_page(session, **fields)
    monkeypatch.setattr(history_module.HistorySession, 'messages', short_copy_page)
    wanted = (await reference(tmp_path / 'oracle'))[0]['copies']
    wanted = [entry for entry in wanted if entry['key']['room'] in ('alpha', 'beta')]
    # Group/removed-room rows are outside this direct-room formatting comparison.
    for row in fixture():
        if row['type'] in ('room', 'room_deleted') or row.get('room'):
            continue
        await gate._record({k: v for k, v in row.items() if k != 'seq'})
    output = tmp_path / 'copy.json'
    before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in gate.journal.path.glob('*.jsonl')}
    await run(CURRENT, 'copy', {'home': str(tmp_path / 'app'), 'address': f'127.0.0.1:{gate.server.port}',
        'pair': gate.auth.pair_code(), 'now': NOW, 'keys': [row['key'] for row in wanted], 'output': str(output)}, tmp_path / 'run')
    assert json.loads(output.read_text()) == wanted
    assert before == {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in gate.journal.path.glob('*.jsonl')}


@pytest.mark.asyncio
async def test_group_copy_matches_original_owner_and_local_time(gate, tmp_path):
    room = identifier(101)
    zone = 'Asia/Seoul'
    reference_rows = (await reference(tmp_path / 'oracle', zone))[0]['copies']
    wanted = [row for row in reference_rows if row['key']['room'] == room]
    assert len(wanted) == 1 and '나\n승인' in wanted[0]['text']
    local_stamp = datetime.fromtimestamp(NOW, ZoneInfo(zone)).strftime('%Y-%m-%d %H:%M')
    assert wanted[0]['text'].startswith('#Fixture room 101') and local_stamp in wanted[0]['text']
    for row in fixture():
        defines_room = row['type'] == 'room' and row['room']['id'] == room
        updates_question = row['type'] == 'state' and row['msg_id'] == identifier(4)
        if defines_room or row.get('room') == room or updates_question:
            await gate._record({k: v for k, v in row.items() if k != 'seq'})
    output = tmp_path / 'group.json'
    await run(CURRENT, 'copy', {'home': str(tmp_path / 'app'), 'address': f'127.0.0.1:{gate.server.port}',
        'pair': gate.auth.pair_code(), 'now': NOW, 'keys': [wanted[0]['key']], 'groups': [room],
        'names': {room: 'Fixture room 101'}, 'zone': zone, 'output': str(output)}, tmp_path / 'run')
    assert json.loads(output.read_text()) == wanted


@pytest.mark.asyncio
async def test_cache_native_write_failures_and_process_exit(tmp_path):
    home = tmp_path / 'cache-app'
    # Sentinel files represent data that the disposable cache must never change.
    home.mkdir()
    sentinels = {home / 'hejo-local.json': b'fixture settings and drafts', home / 'cache/frames.jsonl': b'fixture legacy'}
    for path, data in sentinels.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    assert 'PASS cache' in await run(CURRENT, 'cache', {'home': str(home)}, tmp_path / 'run')
    for path, data in sentinels.items():
        assert path.read_bytes() == data
    await run(CURRENT, 'cache-crash', {'home': str(home)}, tmp_path / 'crash')
    namespace = home / 'cache/history-v1' / hashlib.sha256(b'fixture-a').hexdigest()
    unpublished = hashlib.sha256(b'unpublished').hexdigest()
    assert (namespace / (unpublished + '.json')).is_file()
    assert unpublished not in json.loads((namespace / 'index.json').read_text())
    # A fresh cache process reopens the manifest and deletes the unpublished batch file.
    assert 'PASS cache' in await run(CURRENT, 'cache-reopen', {'home': str(home)}, tmp_path / 'restart')
    for path, data in sentinels.items():
        assert path.read_bytes() == data


@pytest.mark.asyncio
async def test_read_oracle_rejects_noop_plan(tmp_path, monkeypatch):
    async def noop(*args, **kwargs):
        return []
    monkeypatch.setattr(HistoryQueries, 'read_plan', noop)
    with pytest.raises(AssertionError, match='unread-enter'):
        await test_read_plans_match_original_app_commands(tmp_path)
