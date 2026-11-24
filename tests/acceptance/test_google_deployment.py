"""GD-T14: real release/install and every declared deployment/recovery entry."""
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
from contextlib import contextmanager

import pytest
from test_google_release import package, release, install, snapshot


@pytest.fixture
def deployed(package, tmp_path):
    source, env = package
    target, home = tmp_path / 'released', tmp_path / 'airport'
    assert release(source, target, env).returncode == 0
    home.mkdir()
    (home / 'config.yaml').write_text('{}\n')
    result = install(target, home, env)
    assert result.returncode == 0, result.stdout + result.stderr
    (home / 'owner').mkdir(exist_ok=True)
    (home / 'owner/vault.yaml').write_text(json.dumps({'google_connections': {
        'version': 1, 'profiles': {'alpha': {'scope': 'personal', 'account': None}}}}))
    return target, home, env


@pytest.fixture
def team_library(monkeypatch):
    library = Path(os.environ['HEJO_TEAM_KIT_LIB']).resolve(strict=True)
    assert (library / 'hermes_facility/google_deployment.py').is_file()
    monkeypatch.syspath_prepend(str(library))
    return library


def kit(path, supported=True, marker='original'):
    path.mkdir(parents=True)
    (path / '__init__.py').write_text('# synthetic ' + marker + '\n')
    (path / 'plugin.yaml').write_text('name: synthetic\ntools: []\n')
    if supported:
        (path / 'google-connection-support.json').write_text(json.dumps({
            'schema': 'google-connection-support/1', 'component': 'team-kit',
            'versions': [1], 'disconnect_mode': 'forget_account'}))
    return path


def team_command(library, home, env, name, *args):
    return subprocess.run([sys.executable, '-B', str(library.parents[2] / 'bin' / name),
                           *map(str, args), '--root', str(home)],
                          env={**env, 'HERMES_HOME': str(home)}, capture_output=True, text=True, timeout=25)


@pytest.mark.parametrize('action', ['apply', 'rollback'])
def test_t14_team_apply_rollback_allow_and_refuse(deployed, team_library, tmp_path, action):
    target, home, env = deployed
    current = kit(home / 'plugin-store/team-kit')
    source = kit(tmp_path / 'supported-kit', marker='replacement')
    old = kit(tmp_path / 'unsupported-kit', supported=False)
    before = snapshot(home)
    result = team_command(team_library, home, env, 'hermes-team-kit-deploy', action, '--source', old)
    assert result.returncode != 0 and snapshot(home) == before
    result = team_command(team_library, home, env, 'hermes-team-kit-deploy', action, '--source', source)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (current / '__init__.py').read_text() == (source / '__init__.py').read_text()
    assert (home / 'owner/vault.yaml').read_bytes() == before['owner/vault.yaml']
    assert not list((home / 'plugin-store').glob('.team-kit-deploy-*'))


@pytest.mark.parametrize('damage', ['missing-receipt', 'mismatch', 'state', 'schema-bool', 'missing-link', 'missing-checker', 'checker-symlink', 'receipt-symlink', 'checker-error'])
def test_t14_installed_checker_resolution_never_falls_back(deployed, team_library, tmp_path, damage):
    target, home, env = deployed
    kit(home / 'plugin-store/team-kit')
    source = kit(tmp_path / 'new-kit')
    receipt, checker = home / 'hejo/install-receipt.json', target / 'install/check_google_compat.py'
    if damage == 'missing-receipt': receipt.unlink()
    elif damage in ('mismatch', 'state', 'schema-bool'):
        value = json.loads(receipt.read_text())
        if damage == 'state': value['status'] = 'failed'
        elif damage == 'schema-bool': value['version'] = True
        else:
            next(item for item in value['targets'] if item['path'] == 'plugins/hejo')['after'] = str(tmp_path / 'other/gate')
        receipt.write_text(json.dumps(value))
    elif damage == 'missing-link': (home / 'plugins/hejo').unlink()
    elif damage == 'missing-checker': checker.unlink()
    elif damage in ('checker-symlink', 'receipt-symlink'):
        path = checker if damage == 'checker-symlink' else receipt
        moved = tmp_path / 'outside'
        path.rename(moved);path.symlink_to(moved)
    else: checker.write_text('raise SystemExit(83)\n')
    before = snapshot(home)
    env = {**env, 'PATH': str(source), 'PWD': str(source)}
    result = team_command(team_library, home, env, 'hermes-team-kit-deploy', 'apply', '--source', source)
    assert result.returncode != 0 and snapshot(home) == before
    assert 'TEAM_KIT_DEPLOYED' not in result.stdout


@pytest.mark.parametrize('mode', ['migrate', 'restore-copies'])
def test_t14_plugin_store_checked_normal_and_rejected(deployed, team_library, tmp_path, mode):
    target, home, env = deployed
    for name in ('team-kit', 'team-delegation'):
        kit(home / 'plugins' / name)
    command = lambda option: team_command(team_library, home, env, 'hermes-plugin-store', '--' + option)
    if mode == 'restore-copies':
        result = command('migrate')
        assert result.returncode == 0, result.stderr
    source = home / ('plugins' if mode == 'migrate' else 'plugin-store') / 'team-kit'
    metadata = source / 'google-connection-support.json'
    metadata.unlink()
    before = snapshot(home)
    denied = command(mode)
    assert denied.returncode != 0 and snapshot(home) == before
    metadata.write_text(json.dumps({'schema': 'google-connection-support/1', 'component': 'team-kit',
                                    'versions': [1], 'disconnect_mode': 'forget_account'}))
    result = command(mode)
    assert result.returncode == 0, result.stderr
    assert (home / 'plugins/team-kit').is_symlink() == (mode == 'migrate')


@pytest.mark.parametrize('compatible', [True, False])
def test_t14_plugin_store_failure_recovery_checked(deployed, team_library, monkeypatch, compatible):
    target, home, env = deployed
    for name in ('team-kit', 'team-delegation'):
        kit(home / 'plugins' / name)
    namespace = runpy.run_path(str(team_library.parents[2] / 'bin/hermes-plugin-store'))
    def failure(root):
        if not compatible:
            (root / 'plugin-store/team-kit/google-connection-support.json').unlink()
        raise RuntimeError('synthetic verification failure')
    namespace['migrate'].__globals__['check'] = failure
    before = snapshot(home)
    with pytest.raises((ValueError, RuntimeError)):
        namespace['migrate'](home)
    if compatible:
        assert snapshot(home) == before
    else:
        assert (home / 'plugin-store/team-kit').is_dir()
        assert (home / 'plugins/team-kit').is_symlink()
        assert (home / 'owner/vault.yaml').read_bytes() == before['owner/vault.yaml']


def test_t14_pinned_checker_survives_replacement(deployed, team_library, tmp_path):
    from hermes_facility.google_deployment import InstalledChecker
    target, home, env = deployed
    checker = InstalledChecker(home)
    original = checker.fingerprint
    (target / 'install/check_google_compat.py').write_text('raise SystemExit(84)\n')
    source = kit(tmp_path / 'supported')
    checker.check(source)
    assert checker.fingerprint == original
    with pytest.raises(ValueError): InstalledChecker(home).check(source)


@pytest.mark.parametrize('text,allowed', [
    ('google_connections:\n  version: 1\n  profiles:\n    alpha:\n      scope: personal\n      account: null\n', True),
    ('"google_connections":\n  version: 2\n  profiles:\n    alpha: {}\n', False),
    ('google_connections: {version: 1, profiles: {alpha: {}}}\n', False),
    ('<<: *external\n', False),
    ('google_connections:\n  version: *version\n  profiles:\n    alpha: {}\n', False),
    ('google_connections:\n  version: 1\n  profiles:\n    alpha: {}\ngoogle_connections: {}\n', False),
])
def test_t14_yaml_cannot_hide_transition(deployed, text, allowed):
    target, home, env = deployed
    (home / 'owner/vault.yaml').write_text(text)
    before = snapshot(home)
    result = subprocess.run([sys.executable, '-I', '-B', str(target / 'install/check_google_compat.py'),
                             '--home', str(home), '--component', 'hejo', '--target', str(target)],
                            capture_output=True, env=env, timeout=15)
    assert (result.returncode == 0) == allowed
    assert snapshot(home) == before


def test_t14_installer_rollback_denies_before_receipt_upgrade(deployed, tmp_path):
    target, home, env = deployed
    previous = tmp_path / 'old/gate'
    previous.mkdir(parents=True)
    path = home / 'hejo/install-receipt.json'
    receipt = json.loads(path.read_text())
    receipt['version'] = 1
    for item in receipt['targets']:
        if item['kind'] == 'link': item['before'] = str(previous)
    path.write_text(json.dumps(receipt))
    before = snapshot(home)
    result = subprocess.run([sys.executable, str(target / 'install/hejo-install'), '--home', str(home), '--uninstall'],
                            env={**env, 'HERMES_HOME': str(home)}, capture_output=True, text=True, timeout=20)
    assert result.returncode != 0 and snapshot(home) == before


def test_t14_first_install_with_transition_and_no_receipt_refused(package, tmp_path):
    source, env = package
    target, home = tmp_path / 'release', tmp_path / 'airport'
    assert release(source, target, env).returncode == 0
    (home / 'owner').mkdir(parents=True)
    (home / 'config.yaml').write_text('{}\n')
    (home / 'owner/vault.yaml').write_text(json.dumps({'google_connections': {'version': 1, 'profiles': {'alpha': {'account': None}}}}))
    before = snapshot(home)
    result = install(target, home, env)
    assert result.returncode != 0 and snapshot(home) == before


def test_t14_release_refuses_unenumerated_existing_output(package, tmp_path):
    source, env = package
    target = tmp_path / 'release'
    assert release(source, target, env).returncode == 0
    before = snapshot(target)
    result = release(source, target, env)
    assert result.returncode != 0 and snapshot(target) == before


def test_t14_release_does_not_open_secret_config(package, tmp_path):
    source, env = package
    secret = source / 'config/google-oauth-secret.json'
    secret.write_text('{"client_secret":"synthetic-only"}')
    secret.chmod(0)
    try:
        target = tmp_path / 'release'
        result = release(source, target, env)
        assert result.returncode == 0, result.stderr
        assert not (target / 'config/google-oauth-secret.json').exists()
    finally:
        secret.chmod(0o600)


def recovered(deployed, status):
    target, home, env = deployed
    (home / 'owner/vault.yaml').write_text('{}\n')
    result = subprocess.run([sys.executable, str(target / 'install/hejo-install'), '--home', str(home), '--uninstall'],
                            env={**env, 'HERMES_HOME': str(home)}, capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
    path = home / 'hejo/install-receipt.json'
    receipt = json.loads(path.read_text());receipt['status'] = status
    path.write_text(json.dumps(receipt))
    return target, home, env


@pytest.mark.parametrize('status', ['failed', 'uninstalled'])
def test_v7_recovered_installer_resumes_without_erasing_receipt(deployed, status):
    target, home, env = recovered(deployed, status)
    result = install(target, home, env)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (home / 'plugins/hejo').resolve() == target / 'gate'
    assert (home / 'owner/vault.yaml').read_text() == '{}\n'


@pytest.mark.parametrize('status', ['failed', 'uninstalled'])
@pytest.mark.parametrize('damage', ['null-binding', 'unknown-empty', 'credential', 'temporary-credential', 'authorizing',
    'committing', 'damaged-vault', 'duplicate-receipt', 'schema', 'installing', 'root-link', 'profile-link',
    'symlink-parent', 'support-missing', 'support-symlink', 'checker-symlink'])
def test_v7_recovery_exception_denies_unsafe_states(deployed, tmp_path, status, damage):
    target, home, env = recovered(deployed, status)
    receipt = home / 'hejo/install-receipt.json'
    vault = home / 'owner/vault.yaml'
    if damage == 'null-binding':
        vault.write_text(json.dumps({'google_connections': {'version': 1, 'profiles': {'alpha': {'account': None}}}}))
    elif damage == 'unknown-empty':
        vault.write_text(json.dumps({'google_connections': {'version': 99, 'profiles': {}}}))
    elif damage in ('credential', 'temporary-credential'):
        folder = home / 'profiles/alpha/hejo';folder.mkdir(parents=True)
        (folder / ('google-token.json' if damage == 'credential' else '.google-token.json-torn')).write_text('synthetic')
    elif damage in ('authorizing', 'committing'):
        import hashlib
        folder = home / 'profiles/alpha/state/connections';folder.mkdir(parents=True)
        (folder / ('account-' + hashlib.sha256(b'google-personal').hexdigest()[:24] + '.json')).write_text(json.dumps({'phase': damage}))
    elif damage == 'damaged-vault': vault.write_text('<<: *unknown\n')
    elif damage == 'duplicate-receipt': receipt.write_text('{"version":2,"version":2,"status":"failed","targets":[]}')
    elif damage in ('schema', 'installing'):
        value = json.loads(receipt.read_text());value['version' if damage == 'schema' else 'status'] = 99 if damage == 'schema' else 'installing'
        receipt.write_text(json.dumps(value))
    elif damage in ('root-link', 'profile-link'):
        relative = 'plugins/hejo' if damage == 'root-link' else 'profiles/alpha/plugins/hejo'
        link = home / relative;link.parent.mkdir(parents=True, exist_ok=True);link.symlink_to(target / 'gate')
        if damage == 'profile-link':
            value = json.loads(receipt.read_text());value['targets'].append({'kind': 'link', 'path': relative,
                'before': None, 'after': str(target / 'gate'), 'state': 'pending'})
            receipt.write_text(json.dumps(value))
    elif damage == 'symlink-parent':
        outside = tmp_path / 'external-plugins';outside.mkdir();(home / 'plugins').symlink_to(outside)
    elif damage == 'support-missing': (target / 'install/google-connection-support.json').unlink()
    else:
        path = target / ('install/google-connection-support.json' if damage == 'support-symlink' else 'install/check_google_compat.py')
        outside = tmp_path / 'external-file';path.rename(outside);path.symlink_to(outside)
    before = snapshot(home)
    result = install(target, home, env)
    assert result.returncode != 0 and snapshot(home) == before


@pytest.mark.parametrize('damage', ['missing', 'unsupported', 'duplicate', 'invalid-version'])
def test_v7_candidate_support_checked_before_checker_execution(deployed, tmp_path, damage):
    target, home, env = recovered(deployed, 'failed')
    marker = tmp_path / 'must-not-execute'
    (target / 'install/check_google_compat.py').write_text('from pathlib import Path\nPath(' + repr(str(marker)) + ').touch()\n')
    metadata = target / 'install/google-connection-support.json'
    if damage == 'missing': metadata.unlink()
    elif damage == 'duplicate': metadata.write_text('{"component":"hejo","component":"hejo"}')
    else:
        value = json.loads(metadata.read_text());value['versions'] = [2] if damage == 'unsupported' else [True, 1]
        metadata.write_text(json.dumps(value))
    before = snapshot(home)
    result = install(target, home, env)
    assert result.returncode != 0 and not marker.exists() and snapshot(home) == before


@pytest.mark.parametrize('status', ['failed', 'uninstalled'])
def test_v7_transition_inserted_after_selection_is_rejected(deployed, monkeypatch, status):
    target, home, env = recovered(deployed, status)
    monkeypatch.setenv('HERMES_HOME', str(home))
    namespace = runpy.run_path(str(target / 'install/hejo-install'))
    checker = namespace['check_google_compat'];guard = checker.deployment_guard
    observations = []
    @contextmanager
    def racing(root):
        with guard(root):
            (home / 'owner/vault.yaml').write_text(json.dumps({'google_connections': {'version': 1, 'profiles': {'alpha': {'account': None}}}}))
            observations.append(snapshot(home))
            yield
    monkeypatch.setattr(checker, 'deployment_guard', racing)
    assert namespace['main'](['--home', str(home)]) == 1
    assert snapshot(home) == observations[0]


def test_v7_existing_vault_writer_lock_excludes_parallel_installer(deployed, monkeypatch):
    target, home, env = recovered(deployed, 'failed')
    monkeypatch.setenv('HERMES_HOME', str(home))
    namespace = runpy.run_path(str(target / 'install/hejo-install'))
    with namespace['check_google_compat'].deployment_guard(home):
        before = snapshot(home)
        result = install(target, home, env)
        assert result.returncode != 0 and snapshot(home) == before


def test_v7_owner_vault_yaml_round_trip_uses_normal_serializer(deployed, team_library):
    from hermes_facility.config_assembly import yaml_bytes
    from hermes_facility.owner_vault import _parse
    target, home, env = deployed
    value = {'manuals': {'repository_name': 'Synthetic', 'description': '가짜 금고'},
             'google_connections': {'version': 1, 'profiles': {'alpha': {'scope': 'personal', 'account': None}}}}
    body = yaml_bytes(value)
    assert _parse(body.decode()) == value
    (home / 'owner/vault.yaml').write_bytes(body)
    result = subprocess.run([sys.executable, '-I', '-B', str(target / 'install/check_google_compat.py'),
        '--home', str(home), '--component', 'hejo', '--target', str(target)], env=env, capture_output=True, timeout=20)
    assert result.returncode == 0, result.stderr


def test_v7_release_a_to_b_updates_root_profile_links_and_receipt(package, tmp_path):
    source, env = package
    a, b, home = tmp_path / 'release-a', tmp_path / 'release-b', tmp_path / 'airport'
    assert release(source, a, env).returncode == release(source, b, env).returncode == 0
    (home / 'profiles/beta').mkdir(parents=True)
    (home / 'config.yaml').write_text('{}\n');(home / 'profiles/beta/config.yaml').write_text('{}\n')
    (home / 'profiles/beta/profile.yaml').write_text('display_name: Synthetic\n')
    assert install(a, home, env).returncode == 0
    (home / 'owner/vault.yaml').write_text(json.dumps({'google_connections': {'version': 1, 'profiles': {'beta': {'account': None}}}}))
    before = (home / 'owner/vault.yaml').read_bytes()
    result = install(b, home, env)
    assert result.returncode == 0, result.stdout + result.stderr
    receipt = json.loads((home / 'hejo/install-receipt.json').read_text())
    links = [item for item in receipt['targets'] if item['kind'] == 'link']
    assert {item['path'] for item in links} == {'plugins/hejo', 'profiles/beta/plugins/hejo'}
    for item in links:
        assert (home / item['path']).resolve() == b / 'gate'
        assert item['after'] == str(b / 'gate') and item['state'] == 'applied'
    assert (home / 'owner/vault.yaml').read_bytes() == before


def test_v7_release_update_failure_restores_compatible_links_receipt(package, tmp_path, monkeypatch):
    source, env = package
    a, b, home = tmp_path / 'a', tmp_path / 'b', tmp_path / 'airport'
    assert release(source, a, env).returncode == release(source, b, env).returncode == 0
    home.mkdir();(home / 'config.yaml').write_text('{}\n')
    assert install(a, home, env).returncode == 0
    before = snapshot(home)
    namespace = runpy.run_path(str(b / 'install/hejo-install'));save = namespace['save_receipt']
    failures = []
    def fail_once(root, receipt):
        if not failures and any(item.get('after') == str(b / 'gate') for item in receipt['targets']):
            failures.append(True);raise OSError('synthetic receipt write failure')
        return save(root, receipt)
    monkeypatch.setenv('HERMES_HOME', str(home));namespace['run'].__globals__['save_receipt'] = fail_once
    assert namespace['main'](['--home', str(home)]) == 1
    assert failures and snapshot(home) == before


@pytest.mark.parametrize('action', ['apply', 'rollback'])
@pytest.mark.parametrize('failure', [False, True])
def test_v7_team_overlay_add_remove_and_failure_restore(deployed, team_library, tmp_path, monkeypatch, action, failure):
    from hermes_facility import plugin_store
    target, home, env = deployed
    current = kit(home / 'plugin-store/team-kit')
    (current / 'removed.py').write_text('# old\n')
    host = home / 'profiles/alpha/plugins/team-kit';host.mkdir(parents=True)
    manifest = b'name: synthetic\ntools: [mac_app]\n'
    (host / 'plugin.yaml').write_bytes(manifest)
    for child in current.iterdir():
        if child.name != 'plugin.yaml': (host / child.name).symlink_to(child)
    source = kit(tmp_path / 'new-kit', marker='new');(source / 'added.py').write_text('# new\n')
    before = snapshot(home)
    if failure:
        namespace = runpy.run_path(str(team_library.parents[2] / 'bin/hermes-team-kit-deploy'))
        restore = plugin_store.restore_host;failed = []
        def fail_once(root, path, value):
            restore(root, path, value)
            if not failed:failed.append(True);raise OSError('synthetic overlay failure')
        monkeypatch.setattr(plugin_store, 'restore_host', fail_once)
        with pytest.raises(OSError):namespace['deploy'](home, source)
        assert failed and snapshot(home) == before
    else:
        result = team_command(team_library, home, env, 'hermes-team-kit-deploy', action, '--source', source)
        assert result.returncode == 0, result.stderr
        assert (host / 'added.py').resolve() == current / 'added.py'
        assert not (host / 'removed.py').is_symlink()
        assert (host / 'plugin.yaml').read_bytes() == manifest
