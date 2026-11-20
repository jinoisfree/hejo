"""AT-TD-10..19: real subprocess and authenticated sockets, synthetic ledgers only."""
import asyncio
import json
import logging
import os
from pathlib import Path
import sys

import pytest
from jsonschema import Draft202012Validator
from gate.deadlines import Deadlines
from gate.server import SCHEMA

DOCUMENT = {'version': 1, 'profiles': {'default': [{'id': 'notion:one', 'title': 'synthetic-title-marker',
    'due': '2026-11-20', 'source': 'synthetic-source-marker'}], 'alpha': [
    {'id': 'notion:two', 'title': '가짜 마감', 'due': '2026-11-21', 'source': 'https://example.invalid/x',
     'notifications': {}, 'history': [], 'closed': None, 'extra': 'discard'},
    {'id': 'notion:three', 'title': '가짜 마감', 'due': '2026-11-24', 'source': 'ordinary'}], 'beta': []}, 'failed': []}


def command(home, body):
    path = home / 'bin/hermes-deadlines'
    path.parent.mkdir(exist_ok=True)
    path.write_text('#!' + sys.executable + '\n' + body)
    path.chmod(0o700)
    return path


def fake(home, document=DOCUMENT, delay=0, ignore_term=False):
    return command(home, 'import json,os,time,signal\nfrom pathlib import Path\n' +
        ('signal.signal(signal.SIGTERM,signal.SIG_IGN)\n' if ignore_term else '') +
        "p=Path(os.environ['HERMES_HOME']);(p/'pids').open('a').write(str(os.getpid())+'\\n')\n" +
        f'time.sleep({delay})\nprint({json.dumps(json.dumps(document))})\n')


def pids(home):
    return [int(v) for v in (home / 'pids').read_text().splitlines()]


def gone(pid):
    with pytest.raises(ProcessLookupError): os.kill(pid, 0)


async def started(home, n=1):
    async with asyncio.timeout(3):
        while not (home/'pids').exists() or len(pids(home)) < n:
            await asyncio.sleep(.01)


@pytest.mark.asyncio
async def test_at_td_10_13_15_16(tmp_path, caplog):
    caplog.set_level(logging.INFO)
    fake(tmp_path)
    reader = Deadlines(tmp_path)
    result = await reader.list()
    assert result['available'] and len(result['items']) == 3 and result['failed'] == []
    assert all(set(v) <= {'employee','id','title','due','deadline_at','url'} for v in result['items'])
    assert [v.get('url') for v in result['items']] == [None, 'https://example.invalid/x', None]
    assert 'synthetic-title-marker' not in caplog.text and 'synthetic-source-marker' not in caplog.text
    assert 'deadlines_read items=3 failed=0' in caplog.text
    Draft202012Validator(SCHEMA).validate({'v':1,'type':'deadlines_status','ref':'test',**result})
    Draft202012Validator(SCHEMA).validate({'v':1,'type':'deadlines','id':'test'})
    for source in ['ftp://example.invalid/x','javascript:alert(1)','https:missing']:
        doc = json.loads(json.dumps(DOCUMENT));doc['profiles']['default'][0]['source'] = source
        doc['failed'] = [{'profile':'alpha','reason':'deadline_state_corrupt'}]
        fake(tmp_path, doc)
        result = await reader.list()
        assert 'url' not in result['items'][0] and result['failed'] == ['alpha']
        Draft202012Validator(SCHEMA).validate({'v':1,'type':'deadlines_status','ref':'test',**result})


@pytest.mark.asyncio
async def test_at_td_11(tmp_path):
    result = await Deadlines(tmp_path).list()
    assert result == {'available':False,'items':[]}
    Draft202012Validator(SCHEMA).validate({'v':1,'type':'deadlines_status','ref':'test',**result})


@pytest.mark.asyncio
@pytest.mark.parametrize('body,reason', [('raise SystemExit(1)', 'command_failed'), ('print("not json")','invalid_response'),
    ('print("x"*600*1024)','invalid_response'), ('import time;time.sleep(20)','command_failed')])
async def test_at_td_12(tmp_path, caplog, body, reason):
    command(tmp_path, body)
    result = await Deadlines(tmp_path, timeout=.2 if "sleep" in body else 10).list()
    assert result == {'available':True,'reason':reason}
    assert f'deadlines_failed reason={reason}' in caplog.text
    Draft202012Validator(SCHEMA).validate({'v':1,'type':'deadlines_status','ref':'test',**result})


@pytest.mark.asyncio
async def test_at_td_12_invalid_record(tmp_path):
    doc = json.loads(json.dumps(DOCUMENT));doc['profiles']['default'][0]['due'] = 'bad'
    fake(tmp_path,doc)
    assert (await Deadlines(tmp_path).list())['reason'] == 'invalid_response'


@pytest.mark.asyncio
async def test_at_td_14(gate, client, airport):
    fake(airport,delay=1)
    a, _ = await client.pair();b, _ = await client.pair()
    for ref in ['a1','a2']: await a.send_json({'v':1,'type':'deadlines','id':ref})
    await a.send_json({'v':1,'type':'roster','id':'roster'})
    await b.send_json({'v':1,'type':'deadlines','id':'b1'})
    assert (await client.read(a))['ref'] == 'roster'
    assert {(await client.read(a))['ref'],(await client.read(a))['ref']} == {'a1','a2'}
    assert (await client.read(b))['ref'] == 'b1' and len(pids(airport)) == 1


@pytest.mark.asyncio
async def test_at_td_18_disconnect(gate, client, airport):
    fake(airport,delay=2)
    a, _ = await client.pair();b, _ = await client.pair()
    for ws in [a,b]: await ws.send_json({'v':1,'type':'deadlines','id':'test'})
    await started(airport);await asyncio.sleep(.5);await a.close()
    assert (await client.read(b))['type'] == 'deadlines_status'
    assert len(pids(airport)) == 1;gone(pids(airport)[0])
    # No waiter is needed for execution to finish and reap its child.
    await b.send_json({'v':1,'type':'deadlines','id':'again'})
    await started(airport,2);await b.close()
    await asyncio.wait_for(asyncio.shield(gate.server.deadlines._running), 4)
    assert gate.server.deadlines._running is None
    for pid in pids(airport): gone(pid)


@pytest.mark.asyncio
async def test_at_td_18_timeout(tmp_path):
    fake(tmp_path,delay=30,ignore_term=True)
    reader = Deadlines(tmp_path,timeout=1)
    assert (await reader.list())['reason'] == 'command_failed'
    gone(pids(tmp_path)[0]);assert reader._running is None
    fake(tmp_path)
    assert (await reader.list())['available']
    assert len(pids(tmp_path)) == 2


@pytest.mark.asyncio
async def test_at_td_19(gate, client, airport):
    fake(airport,delay=30,ignore_term=True)
    ws,_ = await client.pair()
    await ws.send_json({'v':1,'type':'deadlines','id':'stop'})
    await started(airport)
    task = gate.server.deadlines._running
    await gate.disconnect()
    assert task.cancelled()
    gone(pids(airport)[0])


@pytest.mark.asyncio
async def test_at_td_12_continuous_stdout_is_reaped(tmp_path):
    command(tmp_path, "import os,signal\nfrom pathlib import Path\n"
        "Path(os.environ['HERMES_HOME'],'pids').write_text(str(os.getpid()))\n"
        "signal.signal(signal.SIGTERM,signal.SIG_IGN)\n"
        "while True: os.write(1,b'x'*65536)\n")
    reader = Deadlines(tmp_path)
    result = await asyncio.wait_for(reader.list(), 3)
    assert result == {'available':True,'reason':'invalid_response'}
    gone(pids(tmp_path)[0])
