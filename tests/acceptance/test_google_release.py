"""GD-T14: use actual release output, never a hand-copied compatibility checker."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

import pytest

REPOSITORY = Path(__file__).resolve().parents[2]


def snapshot(root):
    result = {}
    for path in root.rglob('*'):
        if path.is_symlink(): result[str(path.relative_to(root))] = ('link', os.readlink(path))
        elif path.is_file(): result[str(path.relative_to(root))] = path.read_bytes()
    return result


def release(source, target, env):
    return subprocess.run(['bash', str(source / 'install/hejo-release'), str(target)],
                          env=env, capture_output=True, text=True, timeout=30)


@pytest.fixture
def package(tmp_path):
    source = tmp_path / 'isolated-source'
    source.mkdir()
    for directory in ('gate', 'hub', 'schemas', 'install'):
        shutil.copytree(REPOSITORY / directory, source / directory,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    # Never copy even the working-tree config directory into a release fixture.
    (source / 'config').mkdir()
    (source / 'config/google-oauth.json').write_text('{}\n')
    env = {**os.environ, 'HOME': str(tmp_path), 'HERMES_HOME': str(tmp_path / 'unused-home'),
           'PYTHONDONTWRITEBYTECODE': '1', 'HERMES_DISABLE_LAZY_INSTALLS': '1'}
    return source, env


def install(package, home, env):
    # Run the released installer; only its host Tailscale discovery is stubbed.
    # The installer, receipts, links and compatibility boundary remain real.
    script = "import runpy,sys; n=runpy.run_path(sys.argv[1],run_name='isolated_install'); n['run'].__globals__['tailscale_ipv4']=lambda:None; sys.exit(n['main'](sys.argv[2:]))"
    return subprocess.run([sys.executable, '-B', '-c', script, str(package / 'install/hejo-install'),
                           '--home', str(home), '--port', '47900'],
                          env={**env, 'HERMES_HOME': str(home)}, capture_output=True, text=True, timeout=30)


@pytest.mark.parametrize('location', ['first', 'different-location'])
def test_t14_released_install_without_source_or_scripts(package, tmp_path, location):
    source, env = package
    target = tmp_path / location / 'release'
    result = release(source, target, env)
    assert result.returncode == 0, result.stderr
    assert (target / 'install/check_google_compat.py').is_file()
    assert (target / 'install/google-connection-support.json').is_file()
    assert not (target / 'scripts').exists()
    home = tmp_path / location / 'airport'
    home.mkdir(parents=True)
    (home / 'config.yaml').write_text('{}\n')
    result = install(target, home, env)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (home / 'plugins/hejo').resolve() == target / 'gate'
    original = source.with_name('unavailable-source')
    source.rename(original)
    os.chmod(original, 0)
    try:
        (home / 'owner').mkdir(exist_ok=True)
        (home / 'owner/vault.yaml').write_text(json.dumps({
            'google_connections': {'version': 1, 'profiles': {'alpha': {'scope': 'personal', 'account': None}}}}))
        checker = target / 'install/check_google_compat.py'
        command = [sys.executable, str(checker), '--home', str(home), '--component', 'hejo', '--target', str(target)]
        allowed = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
        assert allowed.returncode == 0, allowed.stdout + allowed.stderr
        metadata = target / 'install/google-connection-support.json'
        metadata.unlink()
        before = snapshot(home)
        denied = subprocess.run(command, env=env, capture_output=True, text=True, timeout=15)
        assert denied.returncode != 0
        assert snapshot(home) == before
        denied_install = install(target, home, env)
        assert denied_install.returncode != 0 and snapshot(home) == before
    finally:
        os.chmod(original, 0o700)


@pytest.mark.parametrize('missing', ['check_google_compat.py', 'google-connection-support.json'])
def test_t14_release_missing_required_file_fails(package, tmp_path, missing):
    source, env = package
    (source / 'install' / missing).unlink(missing_ok=True)
    result = release(source, tmp_path / 'release', env)
    assert result.returncode != 0 and 'RELEASED' not in result.stdout


def test_t14_team_support_cannot_borrow_hejo_declaration(package, tmp_path):
    source, env = package
    target = tmp_path / 'release'
    assert release(source, target, env).returncode == 0
    checker = target / 'install/check_google_compat.py'
    assert checker.is_file()
    home = tmp_path / 'airport'
    (home / 'owner').mkdir(parents=True)
    (home / 'owner/vault.yaml').write_text(json.dumps({
        'google_connections': {'version': 1, 'profiles': {'alpha': {'scope': 'personal', 'account': None}}}}))
    # A real release's hejo declaration is present; team-kit has no declaration.
    unsupported = tmp_path / 'legacy-team-kit'
    unsupported.mkdir()
    result = subprocess.run([sys.executable, str(checker), '--home', str(home), '--component', 'team-kit', '--target', str(unsupported)],
                            env=env, capture_output=True, text=True, timeout=15)
    assert result.returncode != 0
