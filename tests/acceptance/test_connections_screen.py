"""AT-HC-01~11: partial reads, scoped lists and credential-free failure evidence."""
import asyncio
import hashlib
import json
import socket

import pytest
from aiohttp import web

from gate.connection_manager import Connections, public
from gate.connections import AdminClient, ConnectionFailure


PART_ROUTES = {
    'toolsets': '/api/tools/toolsets', 'toolset_config': '/api/tools/toolsets/x/config',
    'env': '/api/env', 'mcp': '/api/mcp/servers', 'oauth': '/api/providers/oauth',
    'catalog': '/api/mcp/catalog',
}
BODY_MARKER = 'synthetic-response-body'
SECRET = 'synthetic-private-value'


def tree(root):
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


class Admin:
    def __init__(self):
        self.failure = {}; self.calls = []

    async def request(self, method, route, *, profile=None, body=None):
        assert method == 'GET' and body is None
        self.calls.append((profile, route))
        injected = self.failure.get((profile, route)) or self.failure.get(route)
        if isinstance(injected, Exception): raise injected
        if injected == 'shape': return {'unrecognized': BODY_MARKER}
        if route == PART_ROUTES['toolsets']:
            return [{'name': name, 'enabled': name == 'x'} for name in ('x', 'y')]
        if route.endswith('/config'):
            return {'providers': [{'name': '시험', 'env_vars': [
                {'key': 'ENABLED_KEY' if '/x/' in route else 'DISABLED_KEY', 'is_set': False}]}]}
        if route == PART_ROUTES['env']:
            return {key: {'is_set': key.startswith('SET'), 'redacted_value': SECRET}
                    for key in ['SET_ONE', 'SET_TWO', 'ENABLED_KEY', 'DISABLED_KEY'] + ['UNUSED_'+str(n) for n in range(6)]}
        if route == PART_ROUTES['mcp']: return {'servers': [{'name': 'installed'}]}
        if route == PART_ROUTES['oauth']: return {'providers': [{'id': 'login'}]}
        if route == PART_ROUTES['catalog']:
            return {'entries': [{'name': 'extra'+str(n), 'installed': False} for n in range(2)]}
        raise AssertionError(route)


class Team:
    available = True
    def __init__(self): self.failure = {}; self.calls = []
    async def run(self, command):
        self.calls.append(command)
        injected = self.failure.get(command)
        if isinstance(injected, Exception): raise injected
        if injected == 'shape': return {'schema': 'broken'}
        agents = []
        for profile in ('alpha', 'beta'):
            if command == 'status':
                agents.append({'profile': profile, 'connections': [{'id': 'service', 'label': '시험 연결'}]})
            else:
                agent = {'profile': profile}
                for category, count in [('connected', 1), ('connectable', 2), ('unavailable', 3)]:
                    agent[category] = [{'bundle_id': category+str(n), 'name': category+str(n)} for n in range(count)]
                agent['connectable'][0]['progress'] = {'next': {'kind': 'resume'}, 'undo_until': 9999999999}
                agent['connected'][0]['progress'] = {'undo_until': 9999999999}
                agents.append(agent)
        return {'schema': 'hermes-connections/1' if command == 'status' else 'hermes-installed-apps/1', 'agents': agents}


@pytest.fixture
def manager(tmp_path, monkeypatch):
    monkeypatch.setenv('HERMES_HOME', str(tmp_path))
    import gate.connection_manager as module
    monkeypatch.setattr(module, 'platform_entries', lambda state: state['platforms'])
    obj = Connections(tmp_path, lambda: [{'id': 'alpha', 'name': '직원 A'}, {'id': 'beta', 'name': '직원 B'}],
        admin=Admin(), snapshot=lambda: {'platforms': {'alpha:chat': {'state': 'connected'}, 'beta:chat': {'state': 'connected'}}})
    obj.team = Team()
    # Pre-existing undo records include an expired record; document must not purge it or create a lock.
    obj.secrets.clock = lambda: 1000
    obj.secrets.store.path.mkdir(parents=True)
    for key, until in [('SET_ONE', 999), ('SET_TWO', 1600)]:
        path = obj.secrets.store.path / obj.secrets.filename('alpha', key)
        path.write_text(json.dumps({'until': until, 'previous': SECRET})); path.chmod(0o600)
    return obj


async def read_unchanged(manager, caplog, profile='alpha'):
    before = tree(manager.home)
    result = await manager.document(profile)
    assert tree(manager.home) == before  # AT-HC-10, on every partial-read fixture
    assert SECRET not in json.dumps(result)+caplog.text
    assert BODY_MARKER not in json.dumps(result)+caplog.text
    return result


@pytest.mark.asyncio
async def test_hc01_03_config_isolation_and_safe_log(manager, caplog):
    manager.admin.failure[PART_ROUTES['toolset_config']] = ConnectionFailure('admin_failed', 400)
    result = await read_unchanged(manager, caplog)
    agent = result['agents'][0]; items = {r['id']: r for r in agent['connections']}
    assert items['tool:x']['capabilities'] == []
    assert items['tool:y']['capabilities'] == ['시험: DISABLED_KEY — 키 없음']
    assert agent['unread'] == [{'part': 'toolset_config', 'reason': 'admin_failed'}]
    assert caplog.messages == ['connections_part_failed profile=alpha part=toolset_config reason=admin_failed status=400']
    assert public(agent)['unread'] == agent['unread']


@pytest.mark.asyncio
@pytest.mark.parametrize('part', ['toolsets', 'env', 'mcp', 'oauth', 'catalog', 'team_status', 'apps', 'runtime'])
@pytest.mark.parametrize('failure', ['http', 'shape', 'timeout'])
async def test_hc02_each_part_is_atomic(manager, caplog, part, failure):
    error = {'http': ConnectionFailure('admin_failed', 400), 'shape': 'shape',
             'timeout': ConnectionFailure('admin_unavailable')}[failure]
    if part in PART_ROUTES: manager.admin.failure[PART_ROUTES[part]] = error
    elif part in ('team_status', 'apps'): manager.team.failure['status' if part == 'team_status' else 'apps'] = error
    else:
        def broken():
            if failure == 'shape': return {'unrecognized': BODY_MARKER}
            raise error
        manager.snapshot = broken
    result = await read_unchanged(manager, caplog)
    agent = result['agents'][0]; ids = {r['id'] for r in agent['connections']}
    assert agent['unread'] == [{'part': part, 'reason': 'invalid_response' if failure == 'shape' else error.reason}]
    representatives = {'toolsets': 'tool:x', 'env': 'key:SET_ONE', 'mcp': 'mcp:installed', 'oauth': 'oauth:login',
                       'catalog': 'catalog:extra0', 'team_status': 'team:service', 'apps': 'app:connected0', 'runtime': 'channel:alpha:chat'}
    assert representatives[part] not in ids
    assert all(identifier in ids for other, identifier in representatives.items() if other != part)
    assert 'gateway' in ids and 'instruction' not in result


@pytest.mark.asyncio
async def test_hc04_profile_isolation_shared_commands_once(manager, caplog):
    manager.admin.failure[('beta', PART_ROUTES['env'])] = ConnectionFailure('admin_failed', 400)
    result = await read_unchanged(manager, caplog, None)
    assert 'unread' not in result['agents'][0]
    assert result['agents'][1]['unread'] == [{'part': 'env', 'reason': 'admin_failed'}]
    assert manager.team.calls == ['status', 'apps']
    assert 'channel:beta:chat' not in {r['id'] for r in result['agents'][0]['connections']}


@pytest.mark.asyncio
@pytest.mark.parametrize('reason', ['admin_unavailable', 'admin_failed'])
async def test_hc05_only_transport_outage_has_instruction(manager, caplog, reason):
    manager.admin.failure = {route: ConnectionFailure(reason, 400 if reason == 'admin_failed' else None)
                             for route in PART_ROUTES.values()}
    result = await read_unchanged(manager, caplog)
    assert ('instruction' in result) == (reason == 'admin_unavailable')
    if reason == 'admin_unavailable':
        assert result['instruction'] == '서버의 관리 기능에 닿지 못했어요. 읽은 항목만 보여 드려요.'
    ids = {r['id'] for r in result['agents'][0]['connections']}
    assert {'team:service', 'app:connected0', 'channel:alpha:chat', 'gateway'} <= ids
    assert len(result['agents'][0]['unread']) == 5


@pytest.mark.asyncio
async def test_hc06_10_rows_hidden_progress_and_read_only_undo(manager, caplog):
    result = await read_unchanged(manager, caplog)
    items = {r['id']: r for r in result['agents'][0]['connections']}
    assert {key for key in items if key.startswith('key:')} == {'key:SET_ONE', 'key:SET_TWO', 'key:ENABLED_KEY'}
    assert {key for key, row in items.items() if row.get('hidden_by_default')} == {
        'catalog:extra0', 'catalog:extra1', 'app:unavailable0', 'app:unavailable1', 'app:unavailable2'}
    assert all('hidden_by_default' not in row for key, row in items.items() if key not in {
        'catalog:extra0', 'catalog:extra1', 'app:unavailable0', 'app:unavailable1', 'app:unavailable2'})
    assert items['app:connectable0']['actions'] == [
        {'id': 'app_connect', 'label': '이어서 하기', 'primary': True},
        {'id': 'app_undo', 'label': '처음부터 다시', 'primary': False}]
    assert items['app:connected0']['actions'][-1]['label'] == '되돌리기'
    assert [a['id'] for a in items['key:SET_ONE']['actions']] == ['secret_set']
    assert [a['id'] for a in items['key:SET_TWO']['actions']] == ['secret_set', 'secret_undo']
    assert 'unread' not in result['agents'][0]


@pytest.mark.asyncio
@pytest.mark.parametrize('reason', ['command_failed', 'too_large', 'UNKNOWN_PROFILE', 'invalid_response'])
async def test_hc05_whole_failure_frame_and_log(gate, client, monkeypatch, caplog, reason):
    async def failed(profile): raise ConnectionFailure(reason)
    monkeypatch.setattr(gate.server.admin_connections, 'document', failed)
    ws, _ = await client.pair()
    await ws.send_json({'v': 1, 'type': 'connections', 'id': 'probe', 'profile': 'alpha'})
    reply = await client.read(ws)
    assert reply['reply'] == {'outcome': 'failed', 'reason': reason}
    assert 'connections_failed type=connections profile=alpha reason='+reason in caplog.messages


@pytest.mark.asyncio
async def test_hc05_action_preserves_reason(manager, monkeypatch, caplog):
    async def failed(*args): raise ConnectionFailure('admin_failed', 500)
    monkeypatch.setattr(manager, 'execute', failed)
    frame = {'profile': 'alpha', 'connection': 'gateway', 'action': 'gateway_restart', 'reauth': True}
    assert await manager.perform('device', frame) == {'outcome': 'failed', 'reason': 'admin_failed'}
    assert 'connections_failed type=connection_action profile=alpha reason=admin_failed' in caplog.messages


@pytest.mark.asyncio
@pytest.mark.parametrize('mode,reason,status', [('json', 'invalid_response', None), ('large', 'invalid_response', None),
    ('http', 'admin_failed', 500), ('timeout', 'admin_unavailable', None),
    ('closed', 'admin_unavailable', None), ('permissions', 'admin_unavailable', None)])
async def test_hc11_actual_admin_boundary(manager, caplog, mode, reason, status):
    async def endpoint(request):
        if mode == 'json': return web.Response(text=BODY_MARKER)
        if mode == 'large': return web.Response(body=b' ' * 1_000_001)
        if mode == 'timeout':
            await asyncio.sleep(.1)
            return web.json_response({})
        if mode == 'http': return web.Response(status=500, text=BODY_MARKER)
        return web.json_response({})
    app = web.Application(); app.router.add_route('*', '/api/{tail:.*}', endpoint)
    server = web.AppRunner(app); await server.setup()
    site = web.TCPSite(server, '127.0.0.1', 0); await site.start()
    try:
        port = site._server.sockets[0].getsockname()[1]
        if mode == 'closed':
            sock = socket.socket(); sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]; sock.close()
        path = manager.home/'hejo/admin.json'
        path.write_text(json.dumps({'port': port, 'token': 'synthetic-admin-token'}))
        path.chmod(0o644 if mode == 'permissions' else 0o600)
        manager.admin = AdminClient(manager.home, timeout=.02 if mode == 'timeout' else 1)
        with pytest.raises(ConnectionFailure) as caught:
            await manager.admin.request('GET', '/api/env', profile='alpha')
        assert (caught.value.reason, caught.value.status) == (reason, status)
        result = await read_unchanged(manager, caplog)
        assert ('instruction' in result) == (reason == 'admin_unavailable')
        assert result['agents'][0]['unread']
        assert 'synthetic-admin-token' not in caplog.text+json.dumps(result)
    finally: await server.cleanup()
