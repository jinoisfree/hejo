"""D-2: actual bundle entry, immutable facilities and owner selection/grant preservation."""
import importlib.util
import json
import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys

import pytest
from test_google_deployment import deployed, team_library, team_command
from test_google_release import package

TOOLS = ['google_mail_workspace', 'google_calendar_workspace', 'google_files_workspace', 'google_contacts_workspace']
MANUAL = 'shared/secretary-skills/employee-google-workspace/SKILL.md'


def load_policy(path):
    spec = importlib.util.spec_from_file_location('bundle_policy', path)
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def snapshot(root):
    values = {}
    for path in root.rglob('*'):
        name = str(path.relative_to(root))
        if '.team-kit-deploy-' in name or name == 'owner/.app-connect.lock' or '__pycache__' in path.parts: continue
        if path.is_symlink(): values[name] = ('link', os.readlink(path))
        elif path.is_file(): values[name] = (path.read_bytes(), path.stat().st_mode & 0o777)
        elif path.is_dir(): values[name] = ('directory', path.stat().st_mode & 0o777)
    return values


def seal(source, policy, predecessor=None):
    kit = source / 'plugin-store/team-kit'; path = kit / 'google-connection-support.json'
    support = json.loads(path.read_text())
    previous = predecessor or support['bundle']['predecessor']
    support['bundle'] = {'version': 1, 'kit_sha256': policy.kit_identity(kit),
                        'files': {p: policy.file_identity(source / p) for p in policy.BUNDLE_PATHS},
                        'predecessor': previous}
    path.write_text(json.dumps(support))


@pytest.fixture
def bundle(deployed, team_library, tmp_path):
    release, root, env = deployed
    policy = load_policy(release / 'install/check_google_compat.py')
    repository = team_library.parents[2]
    source = tmp_path / 'bundle'
    shutil.copytree(repository / 'plugin-store/team-kit', source / 'plugin-store/team-kit',
                    ignore=shutil.ignore_patterns('__pycache__', '*.pyc', '.pytest_cache'))
    for name in policy.BUNDLE_PATHS:
        target = source / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repository / name, target)
    # Start from a legacy kit without a bundle claim, with a known predecessor.
    support_path = source / 'plugin-store/team-kit/google-connection-support.json'
    support = json.loads(support_path.read_text()); support.pop('bundle', None)
    support_path.write_text(json.dumps(support))
    for name in [*policy.BUNDLE_PATHS, 'bin/hermes-soul-assemble']:
        target = root / name; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(repository / name, target)
    shutil.copytree(source / 'plugin-store/team-kit', root / 'plugin-store/team-kit')
    (root / 'plugin-store/team-kit/legacy.txt').write_text('old facility\n')
    canonical = root / 'plugin-store/team-delegation/plugin.yaml'
    from hermes_facility.config_assembly import yaml_load, yaml_bytes, CONFIG
    old = yaml_load(canonical.read_bytes(), CONFIG); old['provides_tools'] = [t for t in old['provides_tools'] if t not in TOOLS]
    canonical.write_bytes(yaml_bytes(old, CONFIG))
    (canonical.parent / '__init__.py').write_text('# synthetic existing bridge\n')
    (root / 'owner/team.yaml').write_text(json.dumps({'version': 1, 'agents': {
        p: {'roles': ['personal'], 'apps': []} for p in ('default', 'alpha', 'beta')}}))
    (root / 'owner/skill-assembly.yaml').write_text(json.dumps({'version': 1, 'employees': {'alpha': {}}}))
    (root / 'owner/policy.yaml').write_text('unrelated: keep\n')
    vault = json.loads((root / 'owner/vault.yaml').read_text()); vault['manuals'] = {'repository_name': 'synthetic-repository'}
    (root / 'owner/vault.yaml').write_text(json.dumps(vault))
    from hermes_facility import plugin_store as hosts
    for profile in ('default', 'alpha', 'beta'):
        home = root if profile == 'default' else root / 'profiles' / profile
        (home / 'plugins').mkdir(parents=True, exist_ok=True)
        if profile != 'default': (home / 'config.yaml').write_text('{"packs":{"enabled":["mail"]},"custom":"preserve"}')
        for plugin in hosts.PLUGINS:
            host = home / 'plugins' / plugin
            if profile == 'default': hosts.relative_link(root / 'plugin-store' / plugin, host)
            else:
                manifest = b'provides_tools: [gmail_direct]\ncustom: keep\ngrants: [explicit-only]\n'
                hosts.restore_host(root, host, hosts.overlay(root, host, manifest))
                (host / 'plugin.yaml').chmod(0o640)
    (root / 'plugin-store/links.json').write_text(json.dumps(hosts.read_links(root)))
    before = snapshot(root)
    predecessor = {'kit_sha256': policy.kit_identity(root / 'plugin-store/team-kit'),
                   'files': {p: policy.file_identity(root / p) for p in policy.BUNDLE_PATHS}}
    for name in ('bin/hermes-plugin-store', 'bin/hermes-skill-assemble', 'bin/hermes-team-kit-deploy'):
        with (source / name).open('a') as f: f.write('\n# synthetic candidate\n')
    with (source / MANUAL).open('a') as f: f.write('\nSynthetic updated manual.\n')
    (source / 'plugin-store/team-kit/new.txt').write_text('new facility\n')
    seal(source, policy, predecessor)
    command = lambda action='apply', src=source: team_command(team_library, root, env, 'hermes-team-kit-deploy', action, '--bundle', src)
    return release, root, source, env, policy, before, command


def test_bundle_apply_then_whole_rollback_preserves_selection_and_grants(bundle, tmp_path):
    release, root, source, env, policy, before, command = bundle
    result = command(); assert result.returncode == 0, result.stdout + result.stderr
    from hermes_facility.config_assembly import yaml_load, CONFIG
    manifest = yaml_load((root / 'profiles/alpha/plugins/team-delegation/plugin.yaml').read_bytes(), CONFIG)
    assert set(TOOLS).issubset(manifest['provides_tools']) and manifest['grants'] == ['explicit-only']
    assert manifest['custom'] == 'keep' and 'gmail_direct' in manifest['provides_tools']
    assert (root / 'profiles/alpha/plugins/team-delegation/plugin.yaml').stat().st_mode & 0o777 == 0o640
    assert (root / 'profiles/beta/plugins/team-delegation/plugin.yaml').read_bytes() == before['profiles/beta/plugins/team-delegation/plugin.yaml'][0]
    target = root / 'profiles/alpha/skills/productivity/employee-google-workspace/SKILL.md'
    assert target.read_bytes() == (source / MANUAL).read_bytes()
    assert not (root / 'profiles/beta/skills').exists()
    for name in ['owner/team.yaml', 'owner/vault.yaml', 'owner/policy.yaml', 'owner/skill-assembly.yaml', 'profiles/alpha/config.yaml']:
        assert (root / name).read_bytes() == before[name][0]
    for name in policy.BUNDLE_PATHS: assert policy.file_identity(root / name) == policy.file_identity(source / name)
    assert not (root / 'profiles/alpha/plugins/team-kit/legacy.txt').exists()
    assert (root / 'profiles/alpha/plugins/team-kit/new.txt').is_symlink()
    from hermes_facility.plugin_store import check
    check(root)
    # Roll back a complete compatible bundle; a single old kit is refused below.
    previous = tmp_path / 'previous-bundle'; shutil.copytree(source, previous, symlinks=True)
    for name in ['bin/hermes-plugin-store', 'bin/hermes-skill-assemble', 'bin/hermes-team-kit-deploy', MANUAL]:
        (previous / name).write_bytes(before[name][0]); (previous / name).chmod(before[name][1])
    seal(previous, policy)
    result = command('rollback', previous); assert result.returncode == 0, result.stdout + result.stderr
    assert target.read_bytes() == before[MANUAL][0]
    check(root)


@pytest.mark.parametrize('damage', ['missing', 'companion', 'kit', 'version', 'symlink', 'local-file', 'local-kit', 'manifest', 'skill-edit', 'gateway', 'locked', 'stage'])
def test_bundle_denies_before_writing(bundle, damage):
    release, root, source, env, policy, before, command = bundle
    if damage == 'missing': (source / MANUAL).unlink()
    elif damage == 'companion': (source / 'bin/hermes-plugin-store').write_text('# foreign\n')
    elif damage == 'kit': (source / 'plugin-store/team-kit/new.txt').write_text('foreign')
    elif damage == 'version':
        path = source / 'plugin-store/team-kit/google-connection-support.json'; doc = json.loads(path.read_text()); doc['bundle']['version'] = 2; path.write_text(json.dumps(doc))
    elif damage == 'symlink':
        path = source / MANUAL; path.rename(path.with_suffix('.else')); path.symlink_to(path.with_suffix('.else'))
    elif damage == 'local-file': (root / 'bin/hermes-plugin-store').write_text('# local edit\n')
    elif damage == 'local-kit': (root / 'plugin-store/team-kit/legacy.txt').write_text('local edit')
    elif damage == 'manifest':
        (root / 'profiles/alpha/plugins/team-delegation/plugin.yaml').write_text('provides_tools: bad-type\n')
    elif damage == 'skill-edit':
        p = root / 'profiles/alpha/skills/productivity/employee-google-workspace/SKILL.md'; p.parent.mkdir(parents=True); p.write_text('Owner edit\n')
    elif damage == 'gateway': (root / 'gateway_state.json').write_text(json.dumps({'pid': os.getpid()}))
    elif damage == 'stage': (root / 'plugin-store/.team-kit-deploy-interrupted').mkdir()
    lock = None
    if damage == 'locked':
        import fcntl
        lock = (root / 'owner/.app-connect.lock').open('w'); fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    before = snapshot(root)
    try:
        result = command(); assert result.returncode != 0
        assert 'TEAM_BUNDLE_DEPLOYED' not in result.stdout and snapshot(root) == before
    finally:
        if lock: lock.close()


@pytest.mark.parametrize('action', ['apply', 'rollback'])
def test_kit_only_current_or_candidate_bundle_is_refused(bundle, action, tmp_path, team_library):
    release, root, source, env, policy, before, command = bundle
    candidate = source / 'plugin-store/team-kit'
    denied = team_command(team_library, root, env, 'hermes-team-kit-deploy', action, '--source', candidate)
    assert denied.returncode != 0 and snapshot(root) == before
    legacy = tmp_path / 'legacy'; shutil.copytree(root / 'plugin-store/team-kit', legacy, symlinks=True)
    assert command().returncode == 0
    before = snapshot(root)
    denied = team_command(team_library, root, env, 'hermes-team-kit-deploy', action, '--source', legacy)
    assert denied.returncode != 0 and snapshot(root) == before


@pytest.mark.parametrize('failed_path', [
    'bin/hermes-plugin-store', 'bin/hermes-skill-assemble', 'bin/hermes-team-kit-deploy',
    'plugin-store/team-delegation/plugin.yaml', MANUAL,
    'profiles/alpha/skills/productivity/employee-google-workspace/SKILL.md',
    'profiles/alpha/plugins/team-kit/plugin.yaml', 'profiles/alpha/plugins/team-delegation/plugin.yaml',
    'plugin-store/links.json'])
def test_every_file_or_overlay_failure_restores_whole_previous_unit(bundle, team_library, monkeypatch, failed_path):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility import config_assembly, plugin_store
    from hermes_facility.google_deployment import deploy_bundle
    original = config_assembly.atomic_write; fired = []
    def fail(path, data):
        if Path(path) == root / failed_path and not fired:
            fired.append(True); raise OSError('synthetic write failure')
        return original(path, data)
    monkeypatch.setattr(config_assembly, 'atomic_write', fail); monkeypatch.setattr(plugin_store, 'atomic_write', fail)
    with pytest.raises(OSError): deploy_bundle(root, source)
    assert fired and snapshot(root) == before
    assert not list((root / 'plugin-store').glob('.team-kit-deploy-*'))
    result = command(); assert result.returncode == 0, result.stderr


@pytest.mark.parametrize('which', [1, 2])
def test_each_kit_rename_failure_restores_whole_unit(bundle, monkeypatch, which):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility.google_deployment import deploy_bundle
    original = Path.rename; count = []
    def fail(path, target):
        if path == root / 'plugin-store/team-kit' or str(path).endswith('/after/plugin-store/team-kit'):
            count.append(str(path))
            if len(count) == which: raise OSError('synthetic rename failure')
        return original(path, target)
    monkeypatch.setattr(Path, 'rename', fail)
    with pytest.raises(OSError): deploy_bundle(root, source)
    assert len(count) == which and snapshot(root) == before


@pytest.mark.parametrize("all_selected", [True, False])
def test_applied_bundle_actual_registration_uses_installed_manifest_and_code(bundle, all_selected):
    release, root, source, env, policy, before, command = bundle
    config = root / 'profiles/alpha/config.yaml'
    owner_choice = json.loads(config.read_text())
    if all_selected: owner_choice['packs']['enabled'] = ['mail', 'calendar', 'files-docs', 'mac-apps']
    config.write_text(json.dumps(owner_choice))
    selected_before = config.read_bytes()
    result = command(); assert result.returncode == 0, result.stderr
    assert config.read_bytes() == selected_before
    script = '''import json, pathlib, sys, socket
from types import SimpleNamespace
root = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(root / 'plugin-store/team-kit/lib'))
def no_network(*a, **kw): raise AssertionError('real network forbidden')
socket.create_connection = no_network
socket.socket.connect = no_network
import hermes_execution as td
from hermes_facility.config_assembly import yaml_load, CONFIG
assert pathlib.Path(td.__file__).resolve().is_relative_to(root)
manifest = yaml_load((root / 'profiles/alpha/plugins/team-delegation/plugin.yaml').read_bytes(), CONFIG)
settings = {'selected_skills': {'enabled': True}, 'personal_roles': {'enabled': True},
            'packs': json.loads((root / 'profiles/alpha/config.yaml').read_text())['packs'], 'gmail': {'enabled': False}}
tools = {}
ctx = SimpleNamespace(profile_name='alpha', plugin_name='team-delegation',
 manifest=SimpleNamespace(provides_tools=set(manifest['provides_tools']),
 provides_hooks=set(manifest['provides_hooks']), provides_middleware=set(manifest['provides_middleware'])))
ctx.get_config = lambda k, default=None: settings.get(k, default)
ctx.register_tool = lambda **kw: tools.setdefault(kw['name'], kw)
ctx.register_hook = lambda *a, **kw: None
ctx.register_middleware = lambda *a, **kw: None
ctx.register_system_prompt_section = lambda *a, **kw: None
td.register(ctx)
required = {'google_mail_workspace', 'google_calendar_workspace', 'google_files_workspace', 'google_contacts_workspace'}
# The existing mail pack explicitly requires files-docs; preserve that closure.
expected = required if sys.argv[2] == 'all' else {'google_mail_workspace', 'google_files_workspace'}
assert required.intersection(tools) == expected, set(tools)
print('INSTALLED_SELECTED_TOOLS_REGISTERED')
'''
    result = subprocess.run([sys.executable, '-B', '-c', script, str(root), 'all' if all_selected else 'mail'], capture_output=True, text=True,
        env={**env, 'HERMES_HOME': str(root / 'profiles/alpha'), 'HERMES_ROOT': str(root), 'HERMES_PROFILE': 'alpha',
             'HERMES_TEAM_FILE': str(root / 'owner/team.yaml'), 'HERMES_VAULT_FILE': str(root / 'owner/vault.yaml')}, timeout=30)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'INSTALLED_SELECTED_TOOLS_REGISTERED' in result.stdout


def test_process_death_after_kit_switch_is_detected_on_rerun(bundle):
    release, root, source, env, policy, before, command = bundle
    script = '''from pathlib import Path
import os,sys
from hermes_facility.google_deployment import deploy_bundle
root, source = map(Path, sys.argv[1:])
original = Path.rename
def interrupted(path, target):
 result = original(path, target)
 if Path(target) == root / 'plugin-store/team-kit': os._exit(91)
 return result
Path.rename = interrupted
deploy_bundle(root, source)
'''
    result = subprocess.run([sys.executable, '-B', '-c', script, str(root), str(source)], env=env, capture_output=True, timeout=30)
    assert result.returncode == 91
    stages = list((root / 'plugin-store').glob('.team-kit-deploy-*'))
    assert len(stages) == 1 and (stages[0] / 'transaction.json').is_file()
    broken = snapshot(root)
    result = command(); assert result.returncode != 0 and snapshot(root) == broken
    assert (root / 'owner/vault.yaml').read_bytes() == before['owner/vault.yaml'][0]


def test_recovery_write_failure_retains_before_bundle_and_refuses_rerun(bundle, monkeypatch):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility import config_assembly, plugin_store
    from hermes_facility.google_deployment import deploy_bundle
    original = config_assembly.atomic_write
    def fail(path, data):
        if Path(path) == root / 'plugin-store/links.json': raise OSError('synthetic final write failure')
        if Path(path) == root / 'bin/hermes-plugin-store' and data == before['bin/hermes-plugin-store'][0]:
            raise OSError('synthetic recovery write failure')
        return original(path, data)
    monkeypatch.setattr(config_assembly, 'atomic_write', fail); monkeypatch.setattr(plugin_store, 'atomic_write', fail)
    with pytest.raises(OSError): deploy_bundle(root, source)
    stages = list((root / 'plugin-store').glob('.team-kit-deploy-*'))
    assert len(stages) == 1 and (stages[0] / 'before/plugin-store/team-kit').is_dir()
    broken = snapshot(root)
    result = command(); assert result.returncode != 0 and snapshot(root) == broken


def test_topology_restore_cannot_partially_remove_installed_bundle(bundle, team_library):
    release, root, source, env, policy, before, command = bundle
    assert command().returncode == 0
    before = snapshot(root)
    result = team_command(team_library, root, env, 'hermes-plugin-store', '--restore-copies')
    assert result.returncode != 0 and snapshot(root) == before


@pytest.mark.parametrize('damage', ['extra-path', 'missing-support', 'target-symlink', 'source-external-link'])
def test_bundle_path_allowlist_and_link_boundaries(bundle, damage, tmp_path):
    release, root, source, env, policy, before, command = bundle
    metadata = source / 'plugin-store/team-kit/google-connection-support.json'
    if damage == 'extra-path':
        doc = json.loads(metadata.read_text()); doc['bundle']['files']['../outside'] = None; metadata.write_text(json.dumps(doc))
    elif damage == 'missing-support': metadata.unlink()
    elif damage == 'target-symlink':
        p = root / 'bin/hermes-plugin-store'; p.rename(root / 'bin/foreign'); p.symlink_to(root / 'bin/foreign')
    else:
        outside = tmp_path / 'outside'; outside.write_text('foreign code')
        (source / 'plugin-store/team-kit/foreign').symlink_to(outside)
    before = snapshot(root)
    result = command(); assert result.returncode != 0 and snapshot(root) == before


def test_concurrent_owner_selection_change_aborts_without_reverting_owner(bundle, monkeypatch):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility import config_assembly
    from hermes_facility.google_deployment import deploy_bundle
    original = config_assembly.atomic_write
    changed = b'{"version":1,"employees":{"beta":{}}}\n'
    def concurrent(path, data):
        result = original(path, data)
        if Path(path) == root / 'bin/hermes-plugin-store':
            (root / 'owner/skill-assembly.yaml').write_bytes(changed)
        return result
    monkeypatch.setattr(config_assembly, 'atomic_write', concurrent)
    with pytest.raises(ValueError, match='BUNDLE_INPUT_CHANGED'): deploy_bundle(root, source)
    assert (root / 'owner/skill-assembly.yaml').read_bytes() == changed
    after = snapshot(root); before['owner/skill-assembly.yaml'] = (changed, before['owner/skill-assembly.yaml'][1])
    assert after == before


def test_unconverted_predecessor_without_support_keeps_legacy_contract(bundle, team_library, tmp_path):
    release, root, source, env, policy, before, command = bundle
    vault = json.loads((root / 'owner/vault.yaml').read_text()); vault.pop('google_connections')
    (root / 'owner/vault.yaml').write_text(json.dumps(vault))
    (root / 'plugin-store/team-kit/google-connection-support.json').unlink()
    legacy = tmp_path / 'legacy-no-support'; shutil.copytree(root / 'plugin-store/team-kit', legacy, symlinks=True)
    result = team_command(team_library, root, env, 'hermes-team-kit-deploy', 'apply', '--source', legacy)
    assert result.returncode == 0, result.stderr
    assert not (root / 'plugin-store/team-kit/google-connection-support.json').exists()
    # Bundle upgrade also accepts that explicitly pinned, unconverted predecessor.
    result = command(); assert result.returncode == 0, result.stderr
    assert not (root / 'profiles/alpha/skills').exists()
    assert (root / 'profiles/alpha/plugins/team-delegation/plugin.yaml').read_bytes() == before['profiles/alpha/plugins/team-delegation/plugin.yaml'][0]


def test_profile_link_escape_is_rejected_before_manifest_read(bundle, tmp_path, monkeypatch):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility.google_deployment import deploy_bundle
    outside = tmp_path / 'outside-profile'; (root / 'profiles/alpha').rename(outside)
    (root / 'profiles/alpha').symlink_to(outside, target_is_directory=True)
    original = Path.read_bytes
    def guarded(path):
        assert not path.resolve().is_relative_to(outside), 'escaped profile must not be read'
        return original(path)
    monkeypatch.setattr(Path, 'read_bytes', guarded)
    before = snapshot(root)
    with pytest.raises(ValueError, match='UNSAFE_PATH'): deploy_bundle(root, source)
    assert snapshot(root) == before


def test_pinned_policy_blocks_flagless_old_callers_for_bundle_source_and_current(bundle, tmp_path):
    release, root, source, env, policy, before, command = bundle
    from hermes_facility.google_deployment import InstalledChecker
    checker = InstalledChecker(root)
    with pytest.raises(ValueError): checker.check(source / 'plugin-store/team-kit')
    legacy = tmp_path / 'old-kit'; shutil.copytree(root / 'plugin-store/team-kit', legacy, symlinks=True)
    assert command().returncode == 0
    before = snapshot(root)
    with pytest.raises(ValueError): checker.check(legacy)
    assert snapshot(root) == before
