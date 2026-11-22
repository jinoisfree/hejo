"""AT-DC-10..20 (door): owner close entrance, origin/notice pass-through, close generations.

Real subprocesses and authenticated sockets; synthetic ledgers and commands only.
"""
import asyncio
import json
import logging
import os
from pathlib import Path
import sys
import time

import pytest
from jsonschema import Draft202012Validator
from gate.connection_runtime import ActionJournal
from gate.deadlines import Deadlines
from gate.server import SCHEMA

EMPLOYEES = {'alpha', 'beta', 'default'}
OK = {'ok': True, 'already_closed': False, 'repainted': True}
PRELUDE = ('import json,os,sys,time\nfrom pathlib import Path\nhome=Path(os.environ["HERMES_HOME"])\n'
           'def log(name,text):\n    with (home/name).open("a") as f: f.write(text+"\\n")\n')
LISTING = {'version': 1, 'failed': [], 'profiles': {'alpha': [
    {'id': 'reminder:a', 'title': '가짜 마감', 'due': '2026-11-21', 'source': 'ordinary'},
    {'id': 'gmail:b', 'title': '가짜 마감', 'due': '2026-11-22', 'source': 'ordinary',
     'notice': {'message_id': 'm', 'thread': 't'}},
    {'id': 'weird:c', 'title': '가짜 마감', 'due': '2026-11-23', 'source': 'ordinary'}]}}


def command(home, body):
    path = home / 'bin/hermes-deadlines'
    path.parent.mkdir(exist_ok=True)
    path.write_text('#!' + sys.executable + '\n' + PRELUDE + body)
    path.chmod(0o700)
    return path


def closer(home, body='print(json.dumps(OK))', listing=LISTING):
    """A fake team-kit command: `list` prints a ledger projection, `close` records its arguments then runs body."""
    return command(home, f'OK={OK!r}\nLIST={json.dumps(listing)!r}\n' +
        'if sys.argv[1]=="list": print(LIST); raise SystemExit(0)\n'
        'log("close-args", json.dumps(sys.argv[2:]))\n' + body + '\n')


def lines(home, name):
    path = home / name
    return path.read_text().splitlines() if path.exists() else []


def frames_valid(frame):
    Draft202012Validator({**SCHEMA, 'oneOf': [{'$ref': '#/$defs/serverFrame'}]}).validate(frame)


def request(ref='c1', employee='alpha', deadline='gmail:b', outcome='done'):
    return {'v': 1, 'type': 'deadline_close', 'id': ref, 'employee': employee, 'deadline': deadline, 'outcome': outcome}


async def started(home, name='close-args', n=1):
    async with asyncio.timeout(3):
        while len(lines(home, name)) < n:
            await asyncio.sleep(.01)


@pytest.mark.asyncio
async def test_at_dc_10_origin_and_notice(tmp_path):
    closer(tmp_path)
    result = await Deadlines(tmp_path).list()
    rows = {v['id']: v for v in result['items']}
    assert [rows[k].get('origin') for k in ('reminder:a', 'gmail:b', 'weird:c')] == ['reminder', 'gmail', None]
    assert rows['gmail:b']['notice'] == {'message_id': 'm', 'thread': 't'}
    assert 'notice' not in rows['reminder:a'] and 'notice' not in rows['weird:c']
    assert all(set(v) <= {'employee', 'id', 'title', 'due', 'deadline_at', 'url', 'origin', 'notice'} for v in rows.values())
    frames_valid({'v': 1, 'type': 'deadlines_status', 'ref': 'x', **result})


@pytest.mark.asyncio
@pytest.mark.parametrize('notice', [{'message_id': 'm', 'thread': 't', 'extra': 'x'}, {'message_id': 1, 'thread': 't'},
                                    {'message_id': 'm'}, 'm'])
async def test_at_dc_11_bad_notice(tmp_path, notice):
    listing = json.loads(json.dumps(LISTING))
    listing['profiles']['alpha'][1]['notice'] = notice
    closer(tmp_path, listing=listing)
    assert await Deadlines(tmp_path).list() == {'available': True, 'reason': 'invalid_response'}


@pytest.mark.asyncio
async def test_at_dc_12_18_close_over_socket(gate, client, airport, caplog):
    caplog.set_level(logging.INFO)
    closer(airport)
    ws, welcome = await client.pair()
    await ws.send_json(request())
    reply = await client.read(ws)
    assert reply == {'v': 1, 'type': 'deadline_close_status', 'ref': 'c1', **OK}
    assert json.loads(lines(airport, 'close-args')[0]) == ['--profile', 'alpha', '--id', 'gmail:b', '--outcome', 'done', '--json']
    rows = ActionJournal(airport).rows()
    assert len(rows) == 1
    assert {k: rows[0][k] for k in ('device', 'profile', 'action', 'outcome', 'deadline')} == {
        'device': welcome['device_id'], 'profile': 'alpha', 'action': 'deadline_close', 'outcome': 'done', 'deadline': 'gmail:b'}
    assert 'deadline_close outcome=done ok=1 repainted=1' in caplog.text
    assert 'gmail:b' not in caplog.text and '가짜' not in caplog.text  # NFR-DC-01


@pytest.mark.asyncio
async def test_at_dc_13_refused_without_running(tmp_path):
    reader = Deadlines(tmp_path)
    journal = ActionJournal(tmp_path)
    assert await reader.close('dev', 'alpha', 'gmail:b', 'done', EMPLOYEES) == {'ok': False, 'reason': 'unavailable'}
    assert [r['outcome'] for r in journal.rows()] == ['unavailable']
    closer(tmp_path)
    for employee, deadline, outcome in [('Alpha!', 'gmail:b', 'done'), ('gamma', 'gmail:b', 'done'),
                                        ('alpha', 'x:1', 'done'), ('alpha', 'gmail:b', 'later'),
                                        ('alpha', 'gmail:' + 'x' * 241, 'done'), ('alpha', 'gmail:a b', 'done')]:
        assert await reader.close('dev', employee, deadline, outcome, EMPLOYEES) == {'ok': False, 'reason': 'invalid_request'}
    assert lines(tmp_path, 'close-args') == [] and len(journal.rows()) == 1


@pytest.mark.asyncio
@pytest.mark.parametrize('body,reason', [
    ('print(json.dumps({"error":"UNKNOWN_DEADLINE"})); raise SystemExit(1)', 'unknown_deadline'),
    ('print(json.dumps({"error":"CLOSE_FAILED"})); raise SystemExit(1)', 'command_failed'),
    ('print("not json")', 'invalid_response'),
    ('print(json.dumps({"ok":True,"already_closed":"no","repainted":True}))', 'invalid_response'),
    ('print(json.dumps({"ok":True,"already_closed":False,"repainted":True,"x":1}))', 'invalid_response'),
    ('log("pids",str(os.getpid())); time.sleep(30)', 'command_failed')])
async def test_at_dc_14_failures(tmp_path, body, reason):
    closer(tmp_path, body)
    reader = Deadlines(tmp_path, close_timeout=1)
    assert await reader.close('dev', 'alpha', 'gmail:b', 'cancel', EMPLOYEES) == {'ok': False, 'reason': reason}
    assert [r['outcome'] for r in ActionJournal(tmp_path).rows()] == [reason]
    if 'pids' in body:
        with pytest.raises(ProcessLookupError): os.kill(int(lines(tmp_path, 'pids')[0]), 0)
    frames_valid({'v': 1, 'type': 'deadline_close_status', 'ref': 'x', 'ok': False, 'reason': reason})


@pytest.mark.asyncio
async def test_at_dc_14_already_closed_is_recorded(tmp_path):
    closer(tmp_path, 'print(json.dumps({"ok":True,"already_closed":True,"repainted":False}))')
    result = await Deadlines(tmp_path).close('dev', 'alpha', 'gmail:b', 'done', EMPLOYEES)
    assert result == {'ok': True, 'already_closed': True, 'repainted': False}
    assert [r['outcome'] for r in ActionJournal(tmp_path).rows()] == ['already_closed']


@pytest.mark.asyncio
async def test_at_dc_15_other_frames_and_disconnect(gate, client, airport, caplog):
    caplog.set_level(logging.INFO)
    closer(airport, 'time.sleep(2); log("done","x"); print(json.dumps(OK))')
    ws, _ = await client.pair()
    await ws.send_json(request())
    await asyncio.sleep(.3)
    await ws.send_json({'v': 1, 'type': 'roster', 'id': 'r'})
    assert (await client.read(ws))['ref'] == 'r'
    await asyncio.sleep(.2)
    await ws.close()
    async with asyncio.timeout(5):
        while not lines(airport, 'done') or not ActionJournal(airport).rows():
            await asyncio.sleep(.05)
    assert [r['outcome'] for r in ActionJournal(airport).rows()] == ['done']
    assert 'dispatch_failed' not in caplog.text and 'Traceback' not in caplog.text


@pytest.mark.asyncio
async def test_at_dc_16b_time_budget(gate, client, airport):
    closer(airport, 'time.sleep(1.5); log("marks","x"); print(json.dumps(OK))')
    gate.server.deadlines.close_wait, gate.server.deadlines.close_timeout = 1, 2
    sockets = [(await client.pair())[0] for _ in range(3)]
    begun = time.monotonic()
    for n, ws in enumerate(sockets):
        await ws.send_json(request(f'c{n}'))
    replies = [await client.read(ws) for ws in sockets]
    assert time.monotonic() - begun < 3
    assert sorted((r.get('reason') or 'ok') for r in replies) == ['busy', 'busy', 'ok']
    await asyncio.sleep(3)
    assert lines(airport, 'marks') == ['x'] and len(lines(airport, 'close-args')) == 1
    assert sorted(r['outcome'] for r in ActionJournal(airport).rows()) == ['busy', 'busy', 'done']


@pytest.mark.asyncio
async def test_at_dc_16c_read_after_close_is_fresh(gate, client, airport):
    # list runs: 1st contains X (slow), later ones do not. close answers at once.
    command(airport, 'OK=' + repr(OK) + '''
if sys.argv[1]=="close":
    print(json.dumps(OK)); raise SystemExit(0)
log("runs","x"); n=len(open(home/"runs").read().split())
time.sleep(1)
item={"id":"gmail:b","title":"가짜 마감","due":"2026-11-22","source":"ordinary"}
print(json.dumps({"version":1,"failed":[],"profiles":{"alpha":[item] if n==1 else []}}))
''')
    a, _ = await client.pair()
    b, _ = await client.pair()
    await a.send_json({'v': 1, 'type': 'deadlines', 'id': 'R0'})
    await asyncio.sleep(.1)
    await b.send_json({'v': 1, 'type': 'deadlines', 'id': 'R0b'})   # same generation: joins run 1
    await asyncio.sleep(.1)
    await a.send_json(request())
    assert (await client.read(a))['type'] == 'deadline_close_status'
    await a.send_json({'v': 1, 'type': 'deadlines', 'id': 'R1'})
    got = {}
    for ws in (a, a, b):
        frame = await client.read(ws)
        got[frame['ref']] = frame
    assert len(lines(airport, 'runs')) == 2
    assert [i['id'] for i in got['R0']['items']] == ['gmail:b'] and [i['id'] for i in got['R0b']['items']] == ['gmail:b']
    assert got['R1']['items'] == []


@pytest.mark.asyncio
async def test_at_dc_16_closes_never_overlap(gate, client, airport):
    closer(airport, 'log("spans",f"{os.getpid()} {time.time()}"); time.sleep(1); log("spans",f"{os.getpid()} {time.time()}"); print(json.dumps(OK))')
    a, _ = await client.pair()
    b, _ = await client.pair()
    await a.send_json(request('c1'))
    await b.send_json(request('c2'))
    assert (await client.read(a))['ok'] and (await client.read(b))['ok']
    spans = {}
    for row in lines(airport, 'spans'):
        pid, at = row.split()
        spans.setdefault(pid, []).append(float(at))
    (first_start, first_end), (second_start, second_end) = sorted(spans.values())
    assert len(spans) == 2 and first_end <= second_start


@pytest.mark.asyncio
async def test_at_dc_17_close_may_call_the_local_entrance(gate, client, airport):
    closer(airport, '''
import socket
s=socket.socket(socket.AF_UNIX); s.settimeout(5); s.connect(str(home/"hejo/post.sock"))
s.sendall(b"GET /local/v1/threads/zz?employee=alpha HTTP/1.0\\r\\n\\r\\n")
data=s.recv(100)
assert data.startswith(b"HTTP/1.")
log("reentered","x"); print(json.dumps(OK))''')
    ws, _ = await client.pair()
    await ws.send_json(request())
    assert await asyncio.wait_for(client.read(ws), 8) == {'v': 1, 'type': 'deadline_close_status', 'ref': 'c1', **OK}
    assert lines(airport, 'reentered') == ['x']


@pytest.mark.asyncio
async def test_at_dc_35_unauthenticated_cannot_close(gate, client, airport):
    closer(airport)
    from aiohttp import ClientSession
    async with ClientSession(trust_env=False) as session:
        raw = await session.ws_connect(f'http://127.0.0.1:{gate.server.port}/v1/ws')
        await raw.send_json(request())              # (가) no hello
        first = await raw.receive_json(timeout=5)
        assert first['type'] == 'error'
        await raw.close()
    ws, _ = await client.open(token='wrong-token')   # (나) wrong credential
    assert _['type'] == 'auth_rejected'
    try: await ws.send_json(request())
    except Exception: pass
    paired, welcome = await client.pair()            # (다) a revoked device credential
    await paired.close()
    gate.auth.revoke(welcome['device_id'])
    ws, rejected = await client.open(token=welcome['token'])
    assert rejected == {'v': 1, 'type': 'auth_rejected', 'reason': 'revoked'}
    try: await ws.send_json(request())
    except Exception: pass
    await asyncio.sleep(.5)
    assert lines(airport, 'close-args') == [] and ActionJournal(airport).rows() == []


@pytest.mark.asyncio
async def test_at_dc_19_schema_rules():
    base = {'v': 1, 'type': 'deadline_close_status', 'ref': 'x'}
    validator = Draft202012Validator({**SCHEMA, 'oneOf': [{'$ref': '#/$defs/deadline_close_status'}]})
    assert validator.is_valid({**base, 'ok': True, 'already_closed': False, 'repainted': False})
    assert validator.is_valid({**base, 'ok': False, 'reason': 'busy'})
    assert not validator.is_valid({**base, 'ok': True, 'already_closed': False, 'repainted': False, 'reason': 'busy'})
    assert not validator.is_valid({**base, 'ok': False})
    assert not validator.is_valid({**base, 'ok': False, 'reason': 'busy', 'repainted': True})
    assert not validator.is_valid({**base, 'ok': True})
    assert not validator.is_valid({**base, 'ok': False, 'reason': 'other'})
    client_validator = Draft202012Validator({**SCHEMA, 'oneOf': [{'$ref': '#/$defs/clientFrame'}]})
    assert client_validator.is_valid(request())
    assert not client_validator.is_valid({**request(), 'outcome': 'later'})
    assert not client_validator.is_valid({**request(), 'extra': 1})
    assert not client_validator.is_valid({**request(), 'employee': 'Alpha!'})
