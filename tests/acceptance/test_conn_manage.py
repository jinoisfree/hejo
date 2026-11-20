"""AT-CM-20~28: authoritative actions, merged rows and per-device secret lifetime."""
import asyncio
import json

import pytest

from gate.connection_manager import Connections
from gate.connection_runtime import TeamKit
from gate.connections import ConnectionFailure


class Admin:
    async def request(self, method, route, **kwargs):
        assert method == 'GET'
        if route == '/api/env': return {}
        if route == '/api/mcp/servers': return {'servers': []}
        if route == '/api/mcp/catalog': return {'entries': []}
        return []


class Team:
    available = True
    def __init__(self):
        self.apps = {'connected': [], 'connectable': [], 'unavailable': []}
        self.rows = []
        self.calls = []
        self.reply = {'outcome': 'done'}
    async def run(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if command == 'status': return {'schema': 'hermes-connections/1', 'agents': [{'profile': 'alpha', 'connections': self.rows}]}
        if command == 'apps': return {'schema': 'hermes-installed-apps/1', 'agents': [{'profile': 'alpha', **self.apps}]}
        return self.reply


@pytest.fixture
def manager(tmp_path, monkeypatch):
    monkeypatch.setenv('HERMES_HOME', str(tmp_path))
    obj = Connections(tmp_path, lambda: [{'id': 'alpha', 'name': '직원 A'}], admin=Admin(), snapshot=lambda: None)
    obj.team = Team()
    return obj


def app(bundle='synthetic', **extra):
    return {'bundle_id': bundle, 'name': '시험 앱', **extra}


def account(identifier='synology', **extra):
    return {'id': identifier, 'group': 'account', 'label': '시험 계정', 'state': 'connected', 'actions': [], **extra}


async def rows(manager):
    doc = await manager.document('alpha')
    return {r['id']: r for r in doc['agents'][0]['connections']}


def frame(verb='app_connect', connection='app:synthetic', values=None, reauth=True):
    return {'profile': 'alpha', 'connection': connection, 'action': verb, 'reauth': reauth, 'values': values or {}}


@pytest.mark.asyncio
async def test_cm20_settings_and_actions(manager, caplog):
    settings = [{'step': 'sync_root', 'label': '폴더', 'value': 'synthetic-folder'}, {'step': 'login', 'label': '로그인', 'value': '저장됨'}]
    manager.team.apps['connected'] = [app(settings=settings), app('plain')]
    manager.team.apps['connectable'] = [app('new')]
    result = await rows(manager)
    assert result['app:synthetic']['settings'] == settings
    assert result['app:synthetic']['actions'] == [
        {'id': 'app_connect', 'label': '설정 바꾸기', 'primary': True}, {'id': 'app_disconnect', 'label': '해제', 'primary': False}]
    assert result['app:plain']['actions'] == [{'id': 'app_disconnect', 'label': '해제', 'primary': False}]
    assert result['app:new']['actions'][0]['label'] == '연결'
    assert '범위 바꾸기' not in json.dumps(result, ensure_ascii=False)
    assert 'synthetic-folder' not in caplog.text


@pytest.mark.asyncio
@pytest.mark.parametrize('category,progress,state,merged', [
    ('connected', False, 'connected', True), ('connectable', False, 'connected', False),
    ('connectable', True, 'connected', True), ('connectable', False, 'off', True)])
async def test_cm21_23b_merge_only_granted_or_pending_or_off(manager, category, progress, state, merged):
    for service in ('synology', 'notion'):
        manager.team.rows.append(account(service, state=state, reason='SYNOLOGY_VERIFIED', checked_at='2026-01-01T00:00:00Z', verified_by='direct_check'))
        item = app(service, links=[{'profile': 'alpha', 'connection': service, 'state': state}])
        if progress: item['progress'] = {'next': {'kind': 'resume'}}
        manager.team.apps[category].append(item)
    result = await rows(manager)
    assert ('team:synology' not in result) == merged
    assert ('team:notion' not in result) == merged
    if merged:
        assert result['app:synology']['state'] == state
        assert result['app:synology']['verified_by'] == 'direct_check'
        assert any(a['id'] == 'check' for a in result['app:synology']['actions'])
        await manager.perform('device', frame('check', 'app:synology', reauth=False))
        assert [c for c in manager.team.calls if c[0] == 'check'] == [('check', {'profile': 'alpha', 'connection': 'synology'})]
    if category == 'connectable' and not progress:
        assert result['app:synology']['actions'][0]['label'] == '연결'


@pytest.mark.asyncio
async def test_cm21b_producer_rows_merge_per_profile_and_connection_key(manager):
    """Real producer-shaped rows collapse once; drift and other profiles stay visible."""
    bundle = 'com.synology.CloudStation'
    manager.employees = lambda: [{'id': 'alpha', 'name': '직원 A'}, {'id': 'beta', 'name': '직원 B'}]
    manager.team.rows = [
        account('synology'),
        account('app-'+bundle, group='mac', reason='APP_CONNECTED', verified_by='team_registry'),
        account('app-other-key', group='mac', reason='APP_CONNECTED', verified_by='team_registry'),
        account('app-drift-key', group='mac', reason='CONFIG_DRIFT', verified_by='team_registry'),
        account('app-unmatched-key', group='mac', reason='APP_CONNECTED', verified_by='team_registry')]
    manager.team.apps['connected'] = [
        app(bundle, connection_key=bundle, links=[{'profile': 'alpha', 'connection': 'synology'},
                                                 {'profile': 'alpha', 'connection': 'app-'+bundle}]),
        app('other-bundle', connection_key='other-key'),
        app('drift-bundle', connection_key='drift-key')]
    original = manager.team.run
    beta_apps = []
    async def run(command, **kwargs):
        result = await original(command, **kwargs)
        if command == 'status':
            result['agents'].append({'profile': 'beta', 'connections': [
                account('app-'+bundle, group='mac', reason='APP_CONNECTED', verified_by='team_registry')]})
        elif command == 'apps':
            result['agents'].append({'profile': 'beta', 'connected': beta_apps})
        return result
    manager.team.run = run
    doc = await manager.document()
    alpha, beta = [{r['id']: r for r in a['connections']} for a in doc['agents']]
    assert 'app:'+bundle in alpha
    assert 'team:synology' not in alpha and 'team:app-'+bundle not in alpha
    assert 'app:other-key' in alpha and 'team:app-other-key' not in alpha
    assert 'team:app-drift-key' in alpha and 'app:drift-key' in alpha
    assert 'team:app-unmatched-key' in alpha
    assert 'team:app-'+bundle in beta  # Alpha's app cannot consume Beta's row.
    assert any(a['id'] == 'check' for a in alpha['app:'+bundle]['actions'])
    assert all(a['id'] != 'check' for a in alpha['app:other-key']['actions'])
    beta_apps.append(app(bundle, connection_key=bundle))
    beta_doc = await manager.document('beta')
    beta_ids = {r['id'] for r in beta_doc['agents'][0]['connections']}
    assert 'app:'+bundle in beta_ids and 'team:app-'+bundle not in beta_ids


@pytest.mark.asyncio
@pytest.mark.parametrize('category', ['connected', 'connectable', 'unavailable'])
@pytest.mark.parametrize('verified_by', ['team_registry', 'direct_check'])
async def test_cm21b_derived_row_always_merges_and_preserves_direct_check(manager, category, verified_by):
    """Derived matches do not need account links or a grant; they never add check."""
    manager.team.rows = [account('app-synthetic', group='mac', state='unknown', reason='APP_CONNECTED',
                                 checked_at='2026-01-01T00:00:00Z', verified_by=verified_by)]
    manager.team.apps[category] = [app(connection_key='synthetic')]
    result = await rows(manager)
    assert 'team:app-synthetic' not in result
    item = result['app:synthetic']
    assert all(a['id'] != 'check' for a in item['actions'])
    assert (await manager.perform('device', frame('check', reauth=False)))['reason'] == 'invalid_action'
    assert not any(c[0] == 'check' for c in manager.team.calls)
    if verified_by == 'direct_check':
        assert {k: item[k] for k in ('state', 'reason', 'checked_at', 'verified_by')} == {
            'state': 'unknown', 'reason': 'APP_CONNECTED', 'checked_at': '2026-01-01T00:00:00Z',
            'verified_by': 'direct_check'}
    else:
        assert item['state'] == ('connected' if category == 'connected' else 'unknown')


@pytest.mark.asyncio
async def test_cm24_change_option_not_stdin(manager):
    manager.team.apps['connected'] = [app(settings=[{'step': 'values', 'label': '쓸 곳', 'value': '1개'}])]
    await manager.perform('device', frame(values={'change': 'values'}))
    assert ('app_connect', {'profile': 'alpha', 'connection': 'synthetic', 'values': None, 'options': {'change': 'values'}}) in manager.team.calls
    manager.team.calls.clear()
    assert (await manager.perform('device', frame(values={'change': 'foo'})))['reason'] == 'invalid_action'
    assert not any(c[0] == 'app_connect' for c in manager.team.calls)


@pytest.mark.asyncio
@pytest.mark.parametrize('verb', ['account_connect', 'account_disconnect', 'account_undo'])
async def test_cm25_authoritative_account_actions(manager, verb):
    manager.team.rows = [account('x', actions=[{'id': verb, 'label': '동작'}])]
    assert (await manager.perform('device', frame(verb, 'team:x', reauth=False)))['reason'] == 'reauth_required'
    await manager.perform('device', frame(verb, 'team:x'))
    assert (verb, {'profile': 'alpha', 'connection': 'x', 'values': None}) in manager.team.calls
    assert (await manager.perform('device', frame('account_missing', 'team:x')))['reason'] == 'invalid_action'


@pytest.mark.asyncio
async def test_cm24_25_actual_cli_arguments(tmp_path):
    entry = tmp_path/'bin/hermes-connections'
    entry.parent.mkdir()
    entry.write_text('#!/usr/bin/env python3\nimport sys,json\nprint(json.dumps({"args":sys.argv[1:],"stdin":sys.stdin.read()}))\n')
    entry.chmod(0o700)
    team = TeamKit(tmp_path)
    for verb in ('account_disconnect', 'account_connect', 'account_undo'):
        result = await team.run(verb, profile='alpha', connection='google-personal')
        assert result['args'] == ['account', verb.split('_')[1], '--profile', 'alpha', '--connection', 'google-personal', '--json']
    result = await team.run('app_connect', profile='alpha', connection='synthetic', options={'change': 'values'})
    assert result['args'][-2:] == ['--change', 'values'] and result['stdin'] == ''
    with pytest.raises(ConnectionFailure):
        await team.run('app_connect', profile='alpha', connection='synthetic', options={'change': 'foo'})


@pytest.mark.asyncio
async def test_cm28_secret_lifetime_devices_commit_and_disconnect(manager, caplog):
    manager.team.apps['connected'] = [app(settings=[{'step': 'login', 'label': '로그인', 'value': '저장됨'}])]
    secure = {'next': {'fields': [{'id': 'password', 'secure': True}]}, 'outcome': 'waiting'}
    manager.team.reply = secure
    await manager.perform('device', frame(values={'change': 'login'}))
    manager.team.reply = {'outcome': 'waiting', 'next': {'kind': 'choose_scope'}}
    secret = 'synthetic-private-password'
    await manager.perform('device', frame(values={'change': 'login', 'password': secret}))
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == {'password'}
    manager.team.reply = secure
    await manager.perform('other', frame(values={'change': 'login'}))
    manager.team.reply = {'outcome': 'waiting', 'committed': True, 'instruction': secret}
    with pytest.raises(ConnectionFailure, match='invalid_response'):
        await manager.perform('device', frame(values={'change': 'login', 'password': secret}))
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == set()
    assert manager.input_fields[('other', 'alpha', 'app:synthetic')] == {'password'}
    manager.team.reply = secure
    await manager.perform('device', frame(values={'resume': 'permission_request'}))
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == {'password'}
    manager.disconnected('device')
    assert not any(k[0] == 'device' for k in manager.input_fields)
    assert secret not in caplog.text+manager.audit.path.read_text()


@pytest.mark.asyncio
async def test_cm28_inflight_redaction_survives_new_session(manager):
    manager.team.apps['connected'] = [app(settings=[{'step': 'login', 'label': '로그인', 'value': '저장됨'}])]
    manager.team.reply = {'next': {'fields': [{'id': 'password', 'secure': True}]}, 'outcome': 'waiting'}
    await manager.perform('device', frame(values={'change': 'login'}))
    entered, release = asyncio.Event(), asyncio.Event()
    original = manager.execute
    secret = 'synthetic-inflight-password'
    async def execute(device, profile, connection, verb, values, item):
        if 'password' in values:
            entered.set(); await release.wait()
            return {'outcome': 'waiting', 'committed': True, 'instruction': secret}
        return await original(device, profile, connection, verb, values, item)
    manager.execute = execute
    pending = asyncio.create_task(manager.perform('device', frame(values={'change': 'login', 'password': secret})))
    await entered.wait()
    await manager.perform('device', frame(values={'change': 'login'}))
    release.set()
    with pytest.raises(ConnectionFailure): await pending
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == {'password'}
    manager.disconnected('device')


@pytest.mark.asyncio
async def test_cm28_failure_and_nochange_reset_current_response_fields(manager):
    manager.team.apps['connected'] = [app(settings=[{'step': 'login', 'label': '로그인', 'value': '저장됨'}])]
    manager.team.reply = {'outcome': 'waiting', 'fields': [{'id': 'password', 'secure': True}]}
    await manager.perform('device', frame(values={'change': 'login'}))
    manager.team.reply = {'outcome': 'failed', 'fields': [{'id': 'token', 'secure': True}]}
    await manager.perform('device', frame(values={'change': 'login', 'password': 'synthetic-secret'}))
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == {'token'}
    manager.team.reply = {'outcome': 'waiting', 'fields': [{'id': 'new_secret', 'secure': True}]}
    await manager.perform('device', frame(values={'resume': 'permission_request'}))
    assert manager.input_fields[('device', 'alpha', 'app:synthetic')] == {'new_secret'}


@pytest.mark.asyncio
async def test_cm28_socket_disconnect_clears_device_fields(gate, client):
    ws, welcome = await client.pair()
    manager = gate.server.admin_connections
    key = (welcome['device_id'], 'alpha', 'app:synthetic')
    manager.input_fields[key] = {'password'}
    await ws.close()
    for _ in range(30):
        if key not in manager.input_fields: break
        await asyncio.sleep(.01)
    assert key not in manager.input_fields


@pytest.mark.asyncio
async def test_cm21_config_only_does_not_override_app_grant(manager):
    manager.team.rows = [account(verified_by='config', state='unknown', reason='CONFIG_ONLY')]
    manager.team.apps['connected'] = [app(links=[{'profile': 'alpha', 'connection': 'synology'}])]
    result = await rows(manager)
    assert result['app:synthetic']['state'] == 'connected'
    assert 'team:synology' not in result


@pytest.mark.asyncio
async def test_cm25_account_restart_resume_does_not_toggle_twice(manager, monkeypatch):
    manager.team.rows = [account('x', actions=[{'id': 'account_disconnect', 'label': '해제'}])]
    async def start(device, profile, restart):
        assert (device, profile) == ('device', 'alpha')
        return await restart()
    monkeypatch.setattr(manager.jobs, 'start', start)
    await manager.perform('device', frame('account_disconnect', 'team:x', values={'resume': 'gateway_restart'}))
    assert [c for c in manager.team.calls if c[0] not in {'status','apps'}] == [('gateway_restart', {})]
