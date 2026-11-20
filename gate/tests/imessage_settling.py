"""AT-HI-39: five successful cleanup timings in an isolated real gateway process."""
import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import types
import uuid


async def child(sandbox):
    from gate.tests.gateway_delivery import isolate, setup
    isolate(sandbox)
    root = Path(os.environ['HERMES_HOME'])
    secondary = setup(root)
    import yaml
    for home in (root, secondary):
        path = home / 'config.yaml'
        config = yaml.safe_load(path.read_text())
        config['display'] = {'tool_progress': 'all', 'tool_progress_grouping': 'accumulate',
                             'platforms': {'hejo': {'cleanup_progress': True}}}
        path.write_text(yaml.safe_dump(config))
    sent = threading.Event()

    class FakeAgent:
        def __init__(self, **kwargs):
            self.tools = []
            self.tool_progress_callback = kwargs.get('tool_progress_callback')

        def run_conversation(self, message, **kwargs):
            self.tool_progress_callback('tool.started', 'terminal', 'fixture progress', {})
            assert sent.wait(10), 'progress never reached the gate'
            return {'final_response': 'fixture final answer', 'messages': [], 'api_calls': 1}

    fake = types.ModuleType('run_agent')
    fake.AIAgent = FakeAgent
    sys.modules['run_agent'] = fake
    from gateway import run
    run._resolve_runtime_agent_kwargs = lambda **kwargs: {'api_key': 'fixture'}
    from gate.adapter import HejoAdapter
    original_send, original_stop, original_record = HejoAdapter.send, HejoAdapter.stop_typing, HejoAdapter._record
    stops, deletes = [], []

    async def send(self, *args, **kwargs):
        result = await original_send(self, *args, **kwargs)
        if result.success: sent.set()
        return result

    async def stop(self, *args, **kwargs):
        stops.append(asyncio.get_running_loop().time())
        return await original_stop(self, *args, **kwargs)

    async def record(self, frame, *args, **kwargs):
        result = await original_record(self, frame, *args, **kwargs)
        if frame['type'] == 'delete': deletes.append(asyncio.get_running_loop().time())
        return result

    HejoAdapter.send, HejoAdapter.stop_typing, HejoAdapter._record = send, stop, record
    ready = asyncio.Event()
    original_wait = run.GatewayRunner.wait_for_shutdown

    async def wait(self):
        ready.set()
        await original_wait(self)

    run.GatewayRunner.wait_for_shutdown = wait
    task = asyncio.create_task(run.start_gateway(verbosity=0))
    runner = None
    try:
        async with asyncio.timeout(90):
            while not (ready.is_set() and run._gateway_runner_ref and (runner := run._gateway_runner_ref()) and runner._running):
                if task.done(): raise AssertionError('gateway stopped before ready')
                await asyncio.sleep(0.02)
        from gateway.config import Platform
        from aiohttp import ClientSession
        primary = runner.adapters[Platform('hejo')]
        samples = []
        async with ClientSession(trust_env=False) as client:
            ws = await client.ws_connect(f'http://127.0.0.1:{primary.server.port}/v1/ws')
            await ws.send_json({'v': 1, 'type': 'hello', 'device_name': 'Fixture', 'app_version': 'test',
                                'pair_code': primary.auth.pair_code()})
            assert (await ws.receive_json(timeout=5))['type'] == 'welcome'
            assert (await ws.receive_json(timeout=5))['type'] == 'sync_done'
            for _ in range(5):
                sent.clear(); stops.clear(); deletes.clear()
                await ws.send_json({'v': 1, 'type': 'send', 'id': str(uuid.uuid4()), 'employee': 'default',
                                    'thread': str(uuid.uuid4()), 'client_msg_id': str(uuid.uuid4()), 'text': 'fixture request'})
                async with asyncio.timeout(30):
                    while not deletes or primary._active_sessions:
                        await asyncio.sleep(0.01)
                assert stops and len(deletes) == 1
                samples.append(max(deletes) - min(stops))
            await ws.close()
        print('AT_HI_39_SECONDS ' + json.dumps(samples), flush=True)
        assert len(samples) == 5 and all(0 <= sample < 2 for sample in samples)
        print('AT_HI_39_PASS', flush=True)
    finally:
        if runner: await runner.stop()
        await asyncio.wait_for(task, 40)


def main():
    with tempfile.TemporaryDirectory(prefix='hejo-imessage-', dir='/tmp') as directory:
        sandbox = Path(directory).resolve()
        home, root = sandbox / 'home', sandbox / 'airport'
        home.mkdir(); root.mkdir()
        env = {'PATH': os.defpath, 'HOME': str(home), 'HERMES_HOME': str(root), 'TMPDIR': str(sandbox),
               'XDG_STATE_HOME': str(sandbox / 'state'), 'HERMES_GATEWAY_LOCK_DIR': str(sandbox / 'locks'),
               'HERMES_DISABLE_LAZY_INSTALLS': '1', 'PYTHONDONTWRITEBYTECODE': '1',
               'PYTHONPATH': os.pathsep.join(sys.path), 'NO_COLOR': '1'}
        result = subprocess.run([sys.executable, '-m', 'gate.tests.imessage_settling', '--child'], cwd=sandbox,
                                env=env, capture_output=True, text=True, timeout=180)
        print(result.stdout)
        print(result.stderr)
        return result.returncode


if __name__ == '__main__':
    if '--child' in sys.argv:
        asyncio.run(child(Path(os.environ['HERMES_HOME']).parent))
    else:
        sys.exit(main())
