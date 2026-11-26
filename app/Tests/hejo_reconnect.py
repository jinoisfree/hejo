#!/usr/bin/env python3
"""HEJO-RECONNECT v2: isolated AppKit/socket observations and immutable baseline."""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

from aiohttp import web
from jsonschema import Draft202012Validator

REPO = Path(__file__).resolve().parents[2]
BASE = '3b0006179eef606ba3f3bf1de5230e8338f9cea7'
FIXTURE = REPO / 'app/Tests/Fixtures/HejoReconnect'
PRODUCT = ['app/Sources/GateClient.swift', 'app/Sources/ConversationController.swift']


def git(*args):
    return subprocess.check_output(['git', '-C', str(REPO), *args], text=True).strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + '\n')


def build(evidence, baseline, skip=False):
    sources = sorted((REPO / 'app/Sources').glob('*.swift'))
    sources = [p for p in sources if p.name != 'AppMain.swift'] + sorted((REPO / 'app/Tests').glob('*.swift'))
    # Timing-only instrumentation in an untracked build copy: the real loop still calls
    # receive once, awaits it, then reports its return before reading the next socket frame.
    original = REPO / 'app/Sources/GateClient.swift'
    old = 'if try await receive(frame, run: run) == false { ws.cancel(with: .normalClosure, reason: nil); return }'
    new = '''let hrStart = ProcessInfo.processInfo.systemUptime
                    let hrKeep = try await receive(frame, run: run)
                    reconnectSocketReceived?(frame, hrStart)
                    if hrKeep == false { ws.cancel(with: .normalClosure, reason: nil); return }'''
    assert original.read_text().count(old) == 1
    instrumented = evidence / 'GateClient.swift'
    instrumented.write_text(original.read_text().replace(old, new))
    options = ['-swift-version', '5', '-parse-as-library', '-O', '-whole-module-optimization', '-D', 'HEJO_PERF_TESTING', '-D', 'HEJO_LEGACY_REFERENCE', '-target', platform.machine() + '-apple-macosx13.0']
    if baseline:
        options += ['-D', 'HEJO_RECONNECT_BASELINE']
    # Git history is provenance, not a build input: committing identical source must
    # preserve --no-build reuse, while changed source/options/compiler still reject it.
    fingerprint = {'runner_sha256': digest(Path(__file__)), 'sources': {str(p.relative_to(REPO)): digest(p) for p in sources},
                   'options': options,
                   'compiler': subprocess.check_output(['xcrun', 'swiftc', '--version'], text=True),
                   'instrumentation': {'old': old, 'new': new, 'copy_sha256': digest(instrumented)}}
    sources = [instrumented if p == original else p for p in sources]
    binary = evidence / 'reconnect-tests'
    sparkle = REPO / 'app/.build/sparkle-2.10.0'
    if skip:
        receipt = json.loads((evidence / 'build.json').read_text())
        assert receipt['input'] == fingerprint and receipt['binary_sha256'] == digest(binary), 'stale measurement build'
        return binary
    provenance = {'head': git('rev-parse', 'HEAD'), 'product_diff': git('diff', 'HEAD', '--', 'app/Sources')}
    command = ['xcrun', 'swiftc', *options, *map(str, sources), '-o', str(binary)]
    for framework in ['AppKit', 'EventKit', 'WebKit', 'Accelerate', 'ServiceManagement']:
        command += ['-framework', framework]
    command += ['-F', str(sparkle), '-framework', 'Sparkle', '-Xlinker', '-rpath', '-Xlinker', str(sparkle)]
    with (evidence / 'compile.log').open('w') as log:
        result = subprocess.run(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
    write(evidence / 'build.json', {'input': fingerprint, 'provenance': provenance, 'exit_code': result.returncode})
    if result.returncode:
        raise RuntimeError('compile failed; see compile.log')
    write(evidence / 'build.json', {'input': fingerprint, 'provenance': provenance, 'exit_code': 0, 'binary_sha256': digest(binary)})
    return binary


async def execute(binary, output, mode, endpoint=None):
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix='isolated-', dir=output.parent) as home:
        Path(home, 'hejo-reconnect-isolated').touch()
        Path(home, 'hejo-perf-isolated').touch()
        env = os.environ | {'HERMES_HOME': home, 'TZ': 'UTC', 'HEJO_THREE_TAP_TRACE': ''}
        command = [str(binary), '--hejo-reconnect', str(output), mode]
        if mode == 'boundaries':
            command = [str(binary), '--hejo-reconnect-boundaries']
        elif mode == 'legacy-perf':
            command = [str(binary), '--hejo-perf', str(REPO / 'app/Tests/Fixtures/HejoPerf/input.json'), str(output), 'semantic']
        elif mode == 'boundary-socket':
            command[1] = '--hejo-reconnect-boundary-socket'
        if endpoint:
            command.append(endpoint)
        with (output / 'run.log').open('w') as log:
            child = await asyncio.create_subprocess_exec(*command, env=env, cwd=REPO, stdout=log, stderr=asyncio.subprocess.STDOUT)
            try:
                code = await asyncio.wait_for(child.wait(), 420)
            except BaseException:
                child.kill(); await child.wait(); raise
        write(output / 'execution.json', {'exit_code': code, 'mode': mode})
        assert code == 0, f'{mode} failed; see run.log'


def wire_frame(frame):
    value = dict(frame)
    if 'employees' in value:
        value['employees'] = [dict(employee, avatar=employee.get('avatar')) for employee in value['employees']]
    return value


def wire_hash(frames):
    data = {key: [wire_frame(frame) for frame in rows] for key, rows in frames.items()}
    return hashlib.sha256(json.dumps(data, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


async def socket_run(binary, output, frames):
    connections, failures = [], []
    validator = Draft202012Validator(json.loads((REPO / "schemas/hejo-wire-v1.json").read_text()))
    async def socket(request):
        ws = web.WebSocketResponse(); await ws.prepare(request)
        try:
            hello = await ws.receive_json()
            assert hello['type'] == 'hello' and hello['since'] == 800
            assert hello['token'] == 'fixture-credential'
            index = len(connections); connections.append(index)
            batch = [frames['initial'][0], frames['initial'][-1]] if index % 2 == 0 else frames['backlog']
            for frame in batch:
                value = wire_frame(frame)
                validator.validate(value)
                await ws.send_json(value)
            if index % 2 == 0:
                # Let the initial handshake complete before disconnecting (outside measurement).
                # No pacing or sleeps occur in the measured replay.
                await asyncio.sleep(.15)
                await ws.close()
            else:
                async for message in ws:
                    if message.type == web.WSMsgType.TEXT:
                        frame = json.loads(message.data)
                        assert frame['type'] in ('discord', 'pong'), frame['type']
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        except Exception as exc:
            failures.append(repr(exc))
        return ws
    app = web.Application(); app.router.add_get('/v1/ws', socket)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, '127.0.0.1', 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    try:
        await execute(binary, output, 'socket', f'ws://127.0.0.1:{port}')
    finally:
        await runner.cleanup()
        write(output / 'fixture.json', {'connections': connections, 'failures': failures, 'wire_input_sha256': wire_hash(frames)})
    assert len(connections) == 12 and not failures, failures


async def boundary_socket_run(binary, output, frames):
    failures, seen = [], []
    def post(seq):
        value = dict(frames['backlog'][1])
        value.update(seq=seq, msg_id=f'00000000-0000-4000-8000-{70000+seq:012}')
        return value
    async def socket(request):
        ws = web.WebSocketResponse(); await ws.prepare(request)
        try:
            hello = await ws.receive_json()
            mode = hello['device_name']; seen.append(mode)
            welcome = dict(frames['initial'][0], head_seq=804 if mode != 'gap' else 800)
            await ws.send_json(wire_frame(welcome))
            async def take(kind):
                while True:
                    frame = await ws.receive_json()
                    if frame['type'] == 'discord':
                        continue
                    assert frame['type'] == kind, (kind, frame['type'])
                    return frame
            async def done(through, more):
                await ws.send_json(dict(v=1, type='sync_done', ref='fixture', through=through, more=more, head_seq=804))
            if mode in ('pages', 'gap'):
                if mode == 'gap':
                    await ws.send_json(dict(v=1, type='sync_done', ref='fixture', through=800, more=False, head_seq=800))
                    await ws.send_json(post(804))
                    sync = await take('sync'); assert sync['since'] == 800
                await ws.send_json(post(801)); await ws.send_json(post(802)); await done(802, True)
                sync = await take('sync'); assert sync['since'] == 802
                await ws.send_json(post(803)); await ws.send_json(post(804)); await done(804, False)
            else:
                await ws.send_json(post(801))
                await take('fixture_continue')
                await ws.send_json(dict(v=0, type='message', seq=802) if mode == 'protocol' else post(802))
            async for _ in ws:
                pass
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        except Exception as exc:
            failures.append(repr(exc))
        return ws
    app = web.Application(); app.router.add_get('/v1/ws', socket)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, '127.0.0.1', 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    try:
        await execute(binary, output, 'boundary-socket', f'ws://127.0.0.1:{port}')
    finally:
        await runner.cleanup()
        write(output / 'fixture.json', {'seen': seen, 'failures': failures})
    assert seen == ['pages', 'gap', 'protocol', 'storage'] and not failures, failures


def summary(rows):
    rows = [r for r in rows if not r['warm_up']]
    walls = [r['wall_seconds'] for r in rows]
    probes = {}
    for offset in [75, 150, 225]:
        samples = [next(p for p in r['probes'] if p['offset'] == offset) for r in rows]
        waits = [p['queue_seconds'] for p in samples]
        probes[str(offset)] = {'median': statistics.median(waits), 'max': max(waits), 'min': min(waits),
                              'valid': all(p['submitted_applied'] == 800+offset and 800+offset <= p['started_applied'] < 1100 and p['effect'] for p in samples)}
    return {'wall_median': statistics.median(walls), 'wall_max': max(walls),
            'receive_max': max(r['receive_max'] for r in rows), 'probes': probes,
            'complete': all(r['applied'] == 1100 for r in rows), 'runs': len(rows)}


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['baseline', 'check'])
    parser.add_argument('--no-build', action='store_true')
    args = parser.parse_args()
    evidence = REPO / '.build/hejo-reconnect-evidence' / args.mode
    evidence.mkdir(parents=True, exist_ok=args.no_build)
    if args.mode == 'baseline':
        assert git('rev-parse', 'HEAD') == BASE
        assert not git('diff', BASE, '--', 'app/Sources')
        assert not FIXTURE.exists(), 'never overwrite a frozen fixture'
    else:
        frozen = json.loads((FIXTURE / 'baseline.json').read_text())
        assert digest(FIXTURE / 'expected.json') == frozen['expected_sha256']
    binary = build(evidence, args.mode == 'baseline', skip=args.no_build)
    await execute(binary, evidence / 'semantic', 'semantic')
    observed = evidence / 'semantic/observed.json'
    if args.mode == 'baseline':
        FIXTURE.mkdir(parents=True)
        (FIXTURE / 'expected.json').write_bytes(observed.read_bytes())
        write(FIXTURE / 'baseline.json', {'base_commit': BASE, 'expected_sha256': digest(observed),
              'normalization': 'Only final values and cache byte hash; no random failure IDs or wall-clock state metadata.'})
    else:
        assert observed.read_bytes() == (FIXTURE / 'expected.json').read_bytes(), 'AT-HR-05 final state differs'
    await execute(binary, evidence / 'synthetic', 'synthetic')
    frames = json.loads((evidence / 'synthetic/input.json').read_text())
    await socket_run(binary, evidence / 'socket', frames)
    counts = json.loads((evidence / 'synthetic/counts.json').read_text())
    syn = summary(json.loads((evidence / 'synthetic/performance.json').read_text()))
    sock = summary(json.loads((evidence / 'socket/socket-performance.json').read_text()))
    result = {'counts': counts, 'synthetic': syn, 'socket': sock, 'input_sha256': digest(evidence / 'synthetic/input.json'), 'wire_input_sha256': wire_hash(frames)}
    write(evidence / 'summary.json', result)
    if args.mode == 'baseline':
        assert [r['notifications'] for r in counts] == [23, 103, 303], 'AT-HR-01 expected baseline failure must reproduce'
        print('AT-HR-01 BASELINE EXPECTED FAIL: notifications grow with N')
    else:
        baseline = json.loads((REPO / '.build/hejo-reconnect-evidence/baseline/summary.json').read_text())
        checks = {'AT-HR-01': len({r['notifications'] for r in counts}) == 1 and counts[0]['notifications'] <= 5,
                  'AT-HR-05': True, 'same_input': result['input_sha256'] == baseline['input_sha256'] and result['wire_input_sha256'] == baseline['wire_input_sha256'],
                  'reduction': syn['wall_median'] <= baseline['synthetic']['wall_median'] * .1}
        for name, values in [('synthetic', syn), ('socket', sock)]:
            checks[name] = (values['runs'] == 5 and values['wall_median'] <= 2 and values['wall_max'] <= 3 and
                            values['receive_max'] <= .5 and values['complete'] and all(
                                p['valid'] and 0 <= p['min'] and p['median'] <= .25 and p['max'] <= .5 for p in values['probes'].values()))
        write(evidence / 'budgets.json', checks)
        assert all(checks.values()), checks
        await execute(binary, evidence / 'boundaries', 'boundaries')
        await boundary_socket_run(binary, evidence / 'boundary-socket', frames)
        await execute(binary, evidence / 'legacy-perf', 'legacy-perf')
        assert (evidence / 'legacy-perf/observed.json').read_bytes() == (REPO / 'app/Tests/Fixtures/HejoPerf/expected.json').read_bytes(), 'HEJO-PERF frozen observations differ'
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    asyncio.run(main())
