"""GD-T06/T18: deletion meaning and owned OAuth jobs through the real gate."""
import json

import pytest

from gate.connection_manager import Connections, public


class Admin:
    async def request(self, method, route, **kwargs):
        assert method == 'GET'
        if route == '/api/env': return {}
        if route == '/api/mcp/servers': return {'servers': []}
        if route == '/api/mcp/catalog': return {'entries': []}
        return []


class Team:
    available = True
    def __init__(self): self.calls = []
    async def run(self, command, **kwargs):
        self.calls.append((command, kwargs))
        if command == 'status':
            return {'schema': 'hermes-connections/1', 'agents': [{
                'profile': 'alpha', 'connections': [{
                    'id': 'google-personal', 'group': 'account', 'service': 'google',
                    'scope': 'personal', 'reconnect': 'personal', 'label': 'Google 개인',
                    'state': 'not_connected', 'account': None, 'disconnect_mode': 'forget_account',
                    'actions': [{'id': 'account_connect', 'label': '연결', 'primary': True},
                                {'id': 'account_disconnect', 'label': '연결 해제', 'primary': False}]}]}]}
        if command == 'apps':
            return {'schema': 'hermes-installed-apps/1', 'agents': [{'profile': 'alpha', 'connected': [], 'connectable': [], 'unavailable': []}]}
        if command == 'account_connect':
            return {'outcome': 'pending', 'session_id': 'synthetic-worker-job', 'verification_url': 'https://accounts.google.com/o/oauth2/auth?state=synthetic'}
        return {'outcome': 'done', 'reason': 'CANCELLED' if command == 'account_cancel' else 'CONNECTED'}


@pytest.fixture
def manager(tmp_path, monkeypatch):
    monkeypatch.setenv('HOME', str(tmp_path))
    monkeypatch.setenv('HERMES_ROOT', str(tmp_path))
    monkeypatch.setenv('HERMES_HOME', str(tmp_path))
    value = Connections(tmp_path, lambda: [{'id': 'alpha', 'name': 'Synthetic'}], admin=Admin(), snapshot=lambda: None)
    value.team = Team()
    return value


def frame(action, connection='team:google-personal', *, values=None, reauth=True):
    return {'profile': 'alpha', 'connection': connection, 'action': action, 'reauth': reauth, 'values': values or {}}


def test_t18_capability_survives_public_projection():
    assert public({'disconnect_mode': 'forget_account'}) == {'disconnect_mode': 'forget_account'}


@pytest.mark.asyncio
@pytest.mark.parametrize('values', [{}, {'disconnect_mode': 'keep_values'}, {'disconnect_mode': []}])
async def test_t18_old_or_invalid_client_cannot_delete(manager, values):
    result = await manager.perform('device', frame('account_disconnect', values=values))
    assert result['outcome'] == 'refused' and result['reason'] == 'UPDATE_REQUIRED'
    assert not any(c == 'account_disconnect' for c, _ in manager.team.calls)


@pytest.mark.asyncio
async def test_t18_explicit_meaning_and_reauthentication_both_required(manager):
    values = {'disconnect_mode': 'forget_account'}
    denied = await manager.perform('device', frame('account_disconnect', values=values, reauth=False))
    assert denied['reason'] == 'reauth_required'
    result = await manager.perform('device', frame('account_disconnect', values=values))
    assert result['outcome'] == 'done'
    calls = [kw for command, kw in manager.team.calls if command == 'account_disconnect']
    assert len(calls) == 1 and calls[0]['profile'] == 'alpha'
    assert calls[0]['options']['disconnect_mode'] == 'forget_account'


@pytest.mark.asyncio
async def test_t06_poll_and_cancel_are_bound_to_originating_device(manager):
    started = await manager.perform('device', frame('account_connect'))
    assert started['outcome'] == 'pending' and started.get('session_id')
    session = started['session_id']
    before = len(manager.team.calls)
    for verb in ('oauth_poll', 'account_cancel'):
        denied = await manager.perform('other-device', frame(verb, session, reauth=False))
        assert denied['outcome'] == 'refused'
    assert len(manager.team.calls) == before
    checked = await manager.perform('device', frame('oauth_poll', session, reauth=False))
    assert checked['status'] == 'approved'
    poll = [kw for command, kw in manager.team.calls if command == 'account_status']
    assert len(poll) == 1 and poll[0]['profile'] == 'alpha'
    assert poll[0]['connection'] == 'google-personal'
    assert poll[0]['options']['session'] == 'synthetic-worker-job'
    cancelled = await manager.perform('device', frame('account_cancel', session, reauth=False))
    assert cancelled['reason'] in {'CANCELLED', 'NO_ACTIVE_JOB', 'UNKNOWN_JOB'}
    assert not any(command.startswith('reconnect_') for command, _ in manager.team.calls)
    assert 'synthetic-worker-job' not in manager.audit.path.read_text()


@pytest.mark.asyncio
async def test_t06_cancel_without_session_does_not_bypass_reauth(manager):
    result = await manager.perform('device', frame('account_cancel', reauth=False))
    assert result['outcome'] == 'refused'
    assert not any(command == 'account_cancel' for command, _ in manager.team.calls)


@pytest.mark.asyncio
async def test_t06_cross_profile_cannot_read_job(manager):
    started = await manager.perform('device', frame('account_connect'))
    manager.employees = lambda: [{'id': p, 'name': 'Synthetic'} for p in ('alpha', 'beta')]
    request = frame('oauth_poll', started['session_id'], reauth=False)
    request['profile'] = 'beta'
    before = len(manager.team.calls)
    denied = await manager.perform('device', request)
    assert denied['outcome'] == 'refused' and len(manager.team.calls) == before



@pytest.mark.asyncio
async def test_t06_active_cancel_is_one_use_and_audits_only_public_labels(manager):
    started = await manager.perform('device', frame('account_connect'))
    session = started['session_id']
    result = await manager.perform('device', frame('account_cancel', session, reauth=False))
    assert result['reason'] == 'CANCELLED'
    before = len(manager.team.calls)
    repeated = await manager.perform('device', frame('account_cancel', session, reauth=False))
    assert repeated['reason'] == 'UNKNOWN_JOB' and len(manager.team.calls) == before
    text = manager.audit.path.read_text()
    assert 'account_cancel' in text and 'synthetic-worker-job' not in text and session not in text


@pytest.mark.asyncio
async def test_t06_new_connect_and_disconnect_invalidate_prior_gate_capabilities(manager):
    first = await manager.perform('device', frame('account_connect'))
    second = await manager.perform('other-device', frame('account_connect'))
    assert second['session_id'] != first['session_id']
    assert (await manager.perform('device', frame('oauth_poll', first['session_id'], reauth=False)))['reason'] == 'UNKNOWN_JOB'
    await manager.perform('device', frame('account_disconnect', values={'disconnect_mode': 'forget_account'}))
    before = len(manager.team.calls)
    assert (await manager.perform('other-device', frame('account_cancel', second['session_id'], reauth=False)))['reason'] == 'UNKNOWN_JOB'
    assert len(manager.team.calls) == before


@pytest.mark.asyncio
async def test_t18_real_team_transport_forwards_fixed_deletion_and_job_flags(tmp_path, monkeypatch):
    from gate.connection_runtime import TeamKit
    from gate.connections import ConnectionFailure
    monkeypatch.setenv('HOME', str(tmp_path))
    monkeypatch.setenv('HERMES_HOME', str(tmp_path))
    script = tmp_path / 'bin/hermes-connections'
    script.parent.mkdir()
    script.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(json.dumps({"outcome":"done","args":sys.argv[1:]}))\n')
    script.chmod(0o700)
    team = TeamKit(tmp_path)
    result = await team.run('account_disconnect', profile='alpha', connection='google-personal', options={'disconnect_mode': 'forget_account'})
    assert result['args'] == ['account','disconnect','--profile','alpha','--connection','google-personal','--json','--disconnect-mode','forget_account']
    for verb in ('status', 'cancel'):
        result = await team.run('account_' + verb, profile='alpha', connection='google-personal', options={'session': 'synthetic-worker-job'})
        assert result['args'][-2:] == ['--session', 'synthetic-worker-job']
    with pytest.raises(ConnectionFailure): await team.run('account_disconnect', profile='alpha', connection='google-personal')
    with pytest.raises(ConnectionFailure): await team.run('account_cancel', profile='alpha', connection='google-company', options={'session':'synthetic'})
