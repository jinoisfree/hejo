"""GD-T14: the explicit first checker upgrade, from the pinned Git facilities."""
import contextlib
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tarfile
from types import SimpleNamespace

import pytest
from test_google_release import package, release, REPOSITORY


def archive(repo, commit, paths, output):
    tar = output.with_suffix('.tar')
    subprocess.run(['git', '-C', str(repo), 'archive', '-o', str(tar), commit, '--', *paths], check=True)
    output.mkdir()
    with tarfile.open(tar) as stream:
        stream.extractall(output, filter='data')
    for child in output.rglob('*'):
        if not child.is_symlink():
            child.chmod(0o755 if child.is_dir() or child.stat().st_mode & 0o111 else 0o644)


@pytest.fixture
def legacy(package, tmp_path, monkeypatch):
    source, env = package
    shutil.copyfile(REPOSITORY / 'LICENSE', source / 'LICENSE')
    candidate = tmp_path / 'candidate'
    result = release(source, candidate, env)
    assert result.returncode == 0, result.stderr
    ns = runpy.run_path(str(candidate / 'install/hejo-install'), run_name='legacy_test_installer')
    policy = ns['check_google_compat']
    support = json.loads((candidate / 'install/google-connection-support.json').read_text())['legacy']
    oldsource, old = tmp_path / 'old-source', tmp_path / 'old-release'
    archive(REPOSITORY, support['hejo']['commit'], ['gate', 'hub', 'schemas', 'config', 'install', 'LICENSE'], oldsource)
    result = subprocess.run(['bash', str(oldsource / 'install/hejo-release'), str(old)], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stderr
    (old / 'RELEASE').write_text(support['hejo']['commit'] + '\n')
    assert policy.hejo_identity(old) == support['hejo']['sha256']
    library = Path(os.environ['HEJO_TEAM_KIT_LIB']).resolve()
    repository = library.parents[3]
    # Extract the fixed reference, never copy operating facility bytes.
    baseline = tmp_path / 'baseline'
    archive(repository, support['team']['commit'], ['hermes/plugin-store/team-kit', 'hermes/plugin-store/team-delegation',
            'hermes/bin/hermes-plugin-store', 'hermes/bin/hermes-skill-assemble', 'hermes/bin/hermes-soul-assemble'], baseline)
    home = tmp_path / 'airport'
    shutil.copytree(baseline / 'hermes', home, symlinks=True)
    (home / 'owner').mkdir()
    (home / 'owner/team.yaml').write_text(json.dumps({'version': 1, 'agents': {
        p: {'roles': [], 'apps': []} for p in ('default', 'alpha', 'beta', 'gamma')}}))
    (home / 'owner/vault.yaml').write_text('{"manuals":{"repository_name":"synthetic"}}')
    (home / 'owner/skill-assembly.yaml').write_text('{"version":1,"employees":{"alpha":{}}}')
    targets = []
    for name in ('default', 'alpha', 'beta', 'gamma'):
        profile = home if name == 'default' else home / 'profiles' / name
        (profile / 'plugins').mkdir(parents=True, exist_ok=True)
        (profile / 'config.yaml').write_text('{"custom":"keep"}')
        if name == 'gamma':
            continue  # An existing but uninstalled home must never be enrolled.
        for plugin in ('team-kit', 'team-delegation'):
            path = profile / 'plugins' / plugin
            path.symlink_to(os.path.relpath(home / 'plugin-store' / plugin, path.parent))
        path = profile / 'plugins/hejo'; path.symlink_to(old / 'gate')
        targets.append({'kind': 'link', 'path': path.relative_to(home).as_posix(), 'before': None,
                        'after': str(old / 'gate'), 'state': 'applied'})
    (home / 'hejo').mkdir(mode=0o700)
    receipt = home / 'hejo/install-receipt.json'
    receipt.write_text(json.dumps({'version': 2, 'status': 'installed', 'targets': targets, 'configs': {}, 'created_dirs': []}))
    receipt.chmod(0o600)
    from hermes_facility import plugin_store
    (home / 'plugin-store/links.json').write_text(json.dumps(plugin_store.read_links(home)))
    policy.verify_bundle(home, support['team'])
    monkeypatch.setenv('HOME', str(tmp_path))
    monkeypatch.setenv('HERMES_HOME', str(home))
    monkeypatch.setenv('HERMES_ROOT', str(home))
    monkeypatch.setenv('HERMES_TEAM_FILE', str(home / 'owner/team.yaml'))
    monkeypatch.setenv('HERMES_VAULT_FILE', str(home / 'owner/vault.yaml'))
    return SimpleNamespace(home=home, candidate=candidate, old=old, policy=policy, ns=ns,
                           receipt=receipt, source=source, library=library, env={**env, 'HERMES_HOME': str(home)})


def links(case):
    return {str(p.relative_to(case.home)): os.readlink(p) for p in case.home.glob('**/plugins/hejo') if p.is_symlink()}


def protected(case):
    return {str(p.relative_to(case.home)): p.read_bytes() for p in [
        *sorted((case.home / 'owner').glob('*.yaml')), case.home / 'config.yaml',
        *sorted((case.home / 'profiles').glob('*/config.yaml'))]}


def test_explicit_released_cli_then_actual_full_bundle(legacy):
    c = legacy; before = protected(c)
    result = subprocess.run([sys.executable, '-B', str(c.candidate / 'install/hejo-install'),
                             '--home', str(c.home), '--upgrade-legacy'],
                            env=c.env, capture_output=True, text=True, timeout=40)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'LEGACY_UPGRADED' in result.stdout
    assert len(links(c)) == 3 and set(links(c).values()) == {str(c.candidate / 'gate')}
    assert not (c.home / 'profiles/gamma/plugins/hejo').exists()
    assert protected(c) == before
    assert c.policy.installed_path(c.home) == c.candidate / 'install/check_google_compat.py'
    # The first full bundle is verified by the newly installed checker, with
    # the original absence of both new companion files still intact.
    assert not (c.home / 'bin/hermes-team-kit-deploy').exists()
    repository = c.library.parents[2]
    result = subprocess.run([sys.executable, '-B', str(repository / 'bin/hermes-team-kit-deploy'),
                            'apply', '--root', str(c.home), '--bundle', str(repository)],
                            env=c.env, capture_output=True, text=True, timeout=50)
    assert result.returncode == 0, result.stdout + result.stderr
    c.policy.verify_bundle(c.home)
    assert protected(c) == before
    assert not (c.home / 'profiles/gamma/plugins/hejo').exists()


@pytest.mark.parametrize('damage', ['receipt', 'pending-receipt', 'duplicate-receipt', 'missing-root',
    'profile-link', 'unrecorded-link', 'checker', 'code', 'code-mode', 'internal-link', 'companion',
    'absent-companion', 'vault-transition', 'credential', 'auth-job', 'gateway', 'profile-gateway', 'pending'])
def test_legacy_refuses_before_any_code_write(legacy, damage):
    c = legacy; home = c.home
    if damage == 'receipt':
        value = json.loads(c.receipt.read_text()); value['targets'][0]['after'] = str(c.candidate / 'gate'); c.receipt.write_text(json.dumps(value))
    elif damage == 'pending-receipt':
        value = json.loads(c.receipt.read_text()); value['status'] = 'upgrading-legacy'; c.receipt.write_text(json.dumps(value))
    elif damage == 'duplicate-receipt':
        c.receipt.write_text('{"status":"installed","status":"installed"}')
    elif damage == 'missing-root': (home / 'plugins/hejo').unlink()
    elif damage == 'profile-link':
        path = home / 'profiles/alpha/plugins/hejo'; path.unlink(); path.symlink_to(c.candidate / 'gate')
    elif damage == 'unrecorded-link': (home / 'profiles/gamma/plugins/hejo').symlink_to(c.old / 'gate')
    elif damage == 'checker': (c.old / 'install/check_google_compat.py').write_text('raise AssertionError("must not run")')
    elif damage == 'code': (c.old / 'gate/adapter.py').write_text('# unexpected')
    elif damage == 'code-mode': (c.old / 'gate/adapter.py').chmod(0o600)
    elif damage == 'internal-link':
        path = home / 'plugin-store/team-kit/ai_digest.py'; path.unlink(); path.symlink_to('/etc/hosts')
    elif damage == 'companion': (home / 'bin/hermes-plugin-store').write_text('# changed')
    elif damage == 'absent-companion': (home / 'bin/hermes-team-kit-deploy').write_text('# unexpected')
    elif damage == 'vault-transition':
        (home / 'owner/vault.yaml').write_text('{"google_connections":{"version":1,"profiles":{"alpha":{"account":null}}}}')
    elif damage == 'credential':
        path = home / 'profiles/alpha/hejo'; path.mkdir(); (path / 'google-token.json').write_text('synthetic-private')
    elif damage == 'auth-job':
        path = home / 'profiles/alpha/state/connections'; path.mkdir(parents=True)
        name = 'account-' + __import__('hashlib').sha256(b'google-personal').hexdigest()[:24] + '.json'
        (path / name).write_text('{"phase":"opening","worker_pid":1}')
    elif damage in ('gateway', 'profile-gateway'):
        where = home if damage == 'gateway' else home / 'profiles/gamma'
        (where / 'gateway_state.json').write_text(json.dumps({'pid': os.getpid()}))
    elif damage == 'pending': (home / 'plugin-store/.team-kit-deploy-pending').mkdir()
    before, receipt, owner = links(c), c.receipt.read_bytes(), protected(c)
    with pytest.raises((ValueError, OSError)):
        c.ns['upgrade_legacy'](home, c.candidate)
    assert links(c) == before and c.receipt.read_bytes() == receipt and protected(c) == owner


@pytest.mark.parametrize('point', range(1, 9))
@pytest.mark.parametrize('after_write', [False, True])
def test_each_write_failure_restores_only_links_and_receipt(legacy, monkeypatch, point, after_write):
    c = legacy; original = c.receipt.read_bytes(); before = links(c); owner = protected(c); count = 0
    def wrap(function):
        def run(*args, **kwargs):
            nonlocal count
            count += 1
            fail = count == point
            if fail and not after_write: raise OSError('synthetic I/O failure')
            result = function(*args, **kwargs)
            if fail: raise OSError('synthetic post-replace failure')
            return result
        return run
    namespace = c.ns['upgrade_legacy'].__globals__
    for name in ('atomic_write', 'replace_link'): monkeypatch.setitem(namespace, name, wrap(namespace[name]))
    with pytest.raises(OSError): c.ns['upgrade_legacy'](c.home, c.candidate)
    assert count >= point
    assert links(c) == before and c.receipt.read_bytes() == original and protected(c) == owner
    assert not (c.home / 'profiles/gamma/plugins/hejo').exists()


def test_lock_and_current_checker_do_not_fall_back(legacy):
    c = legacy
    with c.policy.deployment_guard(c.home):
        with pytest.raises(ValueError, match='DEPLOYMENT_LOCKED'):
            c.ns['upgrade_legacy'](c.home, c.candidate)
    assert c.ns['upgrade_legacy'](c.home, c.candidate) == 0
    before = c.receipt.read_bytes()
    with pytest.raises(ValueError, match='LEGACY_CHECKER_ALREADY_PRESENT'):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert c.receipt.read_bytes() == before


@pytest.mark.parametrize('change', ['profile-add', 'profile-remove', 'profile-replace', 'receipt', 'candidate', 'team'])
def test_cas_rejects_changed_complete_input_set(legacy, monkeypatch, change):
    c = legacy; before = links(c); original = c.receipt.read_bytes(); calls = 0
    previous = c.policy.LegacyUpgrade.revalidate
    def race(self, expected_links, expected_receipt):
        nonlocal calls
        calls += 1
        if calls == 2:
            if change == 'profile-add': (c.home / 'profiles/new').mkdir()
            elif change == 'profile-remove': shutil.rmtree(c.home / 'profiles/gamma')
            elif change == 'profile-replace':
                path = c.home / 'profiles/gamma'; path.rename(c.home / 'detached-profile'); path.mkdir()
            elif change == 'receipt': c.receipt.write_bytes(original + b' ')
            elif change == 'candidate': (c.candidate / 'gate/adapter.py').write_text('# changed')
            else: (c.home / 'bin/hermes-plugin-store').write_text('# changed')
        return previous(self, expected_links, expected_receipt)
    monkeypatch.setattr(c.policy.LegacyUpgrade, 'revalidate', race)
    with pytest.raises(ValueError): c.ns['upgrade_legacy'](c.home, c.candidate)
    assert links(c) == before
    if change != 'receipt': assert c.receipt.read_bytes() == original


def test_transition_during_failure_forbids_old_code_restore(legacy, monkeypatch):
    c = legacy; namespace = c.ns['upgrade_legacy'].__globals__; previous = namespace['replace_link']
    def race(path, target):
        previous(path, target)
        (c.home / 'owner/vault.yaml').write_text('{"google_connections":{"version":1,"profiles":{"alpha":{"account":null}}}}')
        raise OSError('synthetic late transition')
    monkeypatch.setitem(namespace, 'replace_link', race)
    with pytest.raises(ValueError, match='GOOGLE_RECOVERY_REQUIRED'):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert json.loads(c.receipt.read_text())['status'] == 'upgrading-legacy'
    assert str(c.candidate / 'gate') in links(c).values()
    with pytest.raises(ValueError): c.ns['run'](c.home)


def test_credentials_and_owner_files_are_never_backed_up(legacy, monkeypatch):
    c = legacy; forbidden = {c.home / name for name in ('.env', 'auth.json', 'google_token.json')}
    for path in forbidden: path.write_text('synthetic-private')
    previous = c.policy.regular_bytes
    def checked(path):
        assert Path(path) not in forbidden
        return previous(path)
    monkeypatch.setattr(c.policy, 'regular_bytes', checked)
    before = protected(c)
    backups = {str(p.relative_to(c.home)) for p in c.home.glob('**/*backup*')}
    assert c.ns['upgrade_legacy'](c.home, c.candidate) == 0
    assert protected(c) == before
    assert {str(p.relative_to(c.home)) for p in c.home.glob('**/*backup*')} == backups


def test_worker_observation_failure_and_live_worker_are_denied(legacy, monkeypatch):
    c = legacy; previous = c.policy.subprocess.run
    for stdout, code in [('321 python mail_waiting_worker.py\n', 0), ('', 1)]:
        def observe(argv, **kwargs):
            return SimpleNamespace(stdout=stdout, returncode=code) if argv[0] == 'ps' else previous(argv, **kwargs)
        monkeypatch.setattr(c.policy.subprocess, 'run', observe)
        with pytest.raises(ValueError, match='WORKER'):
            c.ns['upgrade_legacy'](c.home, c.candidate)


def test_process_death_preserves_incomplete_receipt_and_refuses_retry(legacy):
    c = legacy
    script = '''import os,runpy,sys
from pathlib import Path
package,home=map(Path,sys.argv[1:])
n=runpy.run_path(str(package/'install/hejo-install'),run_name='interrupted_installer')
g=n['upgrade_legacy'].__globals__;original=g['replace_link']
def interrupted(*args):
 original(*args)
 os._exit(73)
g['replace_link']=interrupted
n['upgrade_legacy'](home,package)
'''
    result = subprocess.run([sys.executable, '-B', '-c', script, str(c.candidate), str(c.home)],
                            env=c.env, capture_output=True, text=True, timeout=40)
    assert result.returncode == 73, result.stdout + result.stderr
    receipt = json.loads(c.receipt.read_text())
    assert receipt['status'] == 'upgrading-legacy' and receipt['legacy_upgrade']['from'] == str(c.old)
    assert str(c.candidate / 'gate') in links(c).values()
    before = c.receipt.read_bytes(), links(c), protected(c)
    for call in (lambda: c.ns['run'](c.home), lambda: c.ns['upgrade_legacy'](c.home, c.candidate)):
        with pytest.raises((ValueError, OSError)): call()
        assert (c.receipt.read_bytes(), links(c), protected(c)) == before


def test_persistent_recovery_failure_stays_closed(legacy, monkeypatch):
    c = legacy; g = c.ns['upgrade_legacy'].__globals__; original = g['replace_link']; count = 0
    def failing(*args):
        nonlocal count
        count += 1
        if count >= 2: raise OSError('synthetic persistent failure')
        return original(*args)
    monkeypatch.setitem(g, 'replace_link', failing)
    with pytest.raises(OSError): c.ns['upgrade_legacy'](c.home, c.candidate)
    assert json.loads(c.receipt.read_text())['status'] == 'upgrading-legacy'
    before = c.receipt.read_bytes(), links(c)
    with pytest.raises(ValueError): c.ns['run'](c.home)
    assert (c.receipt.read_bytes(), links(c)) == before


def test_new_profile_during_write_forbids_uncertain_recovery(legacy, monkeypatch):
    c = legacy; g = c.ns['upgrade_legacy'].__globals__; original = g['replace_link']
    def race(*args):
        result = original(*args)
        (c.home / 'profiles/new').mkdir()
        return result
    monkeypatch.setitem(g, 'replace_link', race)
    with pytest.raises(ValueError, match='LEGACY_INPUT_CHANGED'):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert json.loads(c.receipt.read_text())['status'] == 'upgrading-legacy'
    assert str(c.candidate / 'gate') in links(c).values()
    assert not (c.home / 'profiles/new/plugins/hejo').exists()


def test_corrupt_support_cannot_admit_a_secret_file(legacy, monkeypatch):
    c = legacy; path = c.candidate / 'install/google-connection-support.json'
    value = json.loads(path.read_text())
    value['legacy']['team']['files']['.env'] = {'sha256': '0' * 64, 'mode': 0o600}
    path.write_text(json.dumps(value))
    previous = c.policy.regular_bytes
    def checked(path):
        assert Path(path).name != '.env'
        return previous(path)
    monkeypatch.setattr(c.policy, 'regular_bytes', checked)
    with pytest.raises(ValueError, match='INVALID_GOOGLE_BUNDLE'):
        c.ns['upgrade_legacy'](c.home, c.candidate)


@pytest.mark.parametrize('status', ['failed', 'uninstalled', 'installing'])
def test_explicit_legacy_does_not_reclassify_other_receipt_states(legacy, status):
    c = legacy; value = json.loads(c.receipt.read_text()); value['status'] = status
    c.receipt.write_text(json.dumps(value)); before = c.receipt.read_bytes(), links(c)
    with pytest.raises(ValueError, match='INVALID_LEGACY_RECEIPT'):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert (c.receipt.read_bytes(), links(c)) == before


def test_normal_install_never_selects_missing_checker_candidate(legacy):
    c = legacy; before = c.receipt.read_bytes(), links(c)
    with pytest.raises((ValueError, OSError)): c.ns['run'](c.home)
    assert (c.receipt.read_bytes(), links(c)) == before


@pytest.mark.parametrize('damage', ['receipt-mode', 'receipt-link', 'support-link', 'profile-link', 'unknown-code'])
def test_unknown_or_unsafe_legacy_inputs_remain_closed(legacy, damage):
    c = legacy
    if damage == 'receipt-mode': c.receipt.chmod(0o644)
    elif damage in ('receipt-link', 'support-link'):
        path = c.receipt if damage == 'receipt-link' else c.candidate / 'install/google-connection-support.json'
        moved = path.with_name('unexpected-alias'); path.rename(moved); path.symlink_to(moved)
    elif damage == 'profile-link':
        path = c.home / 'profiles/gamma'; path.rename(c.home / 'other-profile'); path.symlink_to(c.home / 'other-profile')
    else: (c.old / 'unrecognized-code.py').write_text('# unexpected')
    before = links(c)
    with pytest.raises((ValueError, OSError)): c.ns['upgrade_legacy'](c.home, c.candidate)
    assert links(c) == before


@pytest.mark.parametrize('kind', ['receipt-temp', 'link-temp', 'config-temp', 'kit-mode', 'release-mode', 'candidate-mode'])
def test_orphan_install_artifacts_and_facility_root_mode_are_rejected(legacy, kind):
    c = legacy
    if kind == 'receipt-temp': (c.home / 'hejo/.hejo-install-interrupted').write_text('synthetic')
    elif kind == 'link-temp': (c.home / 'profiles/gamma/plugins/.hejo-link-interrupted').symlink_to(c.old / 'gate')
    elif kind == 'config-temp': (c.home / 'profiles/alpha/.hejo-install-interrupted').write_text('synthetic')
    else:
        path = c.home / 'plugin-store/team-kit' if kind == 'kit-mode' else c.old if kind == 'release-mode' else c.candidate
        path.chmod(0o777)
    before = c.receipt.read_bytes(), links(c)
    with pytest.raises(ValueError, match='PENDING_FACILITY|LEGACY_FACILITY_MODE'):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert (c.receipt.read_bytes(), links(c)) == before
