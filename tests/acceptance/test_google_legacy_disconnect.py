"""GD-T14: expired transactions from the pinned legacy producer, never live data."""
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

import pytest
from test_google_legacy import legacy, package, links, protected


def legacy_disconnect(c, *, undo=True, age=601, profile='alpha', empty_before=False):
    """Run pinned account_connect.run/write_transaction in its original module tree."""
    home = c.home if profile == 'default' else c.home / 'profiles' / profile
    config = home / 'config.yaml'
    config.write_text(json.dumps({'custom': 'keep', 'plugins': {'entries': {
        'team-delegation': {'settings': {'gmail': {'enabled': True}}}}},
        'skills': {'disabled': ['synthetic-skill']}}))
    if empty_before:config.write_bytes(b'')
    # Only fake connection discovery is supplied; the fixed producer, serializer,
    # write-ahead transaction and optional expiry cleanup all execute unchanged.
    script = '''import sys,time,json
from pathlib import Path
from types import SimpleNamespace
from hermes_facility import account_connect as a,app_connect as app
root=Path(sys.argv[1]);profile=sys.argv[2];home=root if profile=='default' else root/'profiles'/profile
at=time.time()-float(sys.argv[3])
a.find_connection=lambda *args:SimpleNamespace(home=home,row={'group':'account'})
r=a.run(root,'disconnect',profile,'google-personal',clock=lambda:at)
assert r['outcome']=='waiting' and r['reason']=='RESTART_REQUIRED'
f=a.record_path(home,'google-personal')
assert json.loads(f.read_bytes())['phase']=='applied'
if sys.argv[4]=='absent':app.read_record(f,lambda:at+601)
'''
    env = {**c.env, 'PYTHONPATH': str(c.home / 'plugin-store/team-kit/lib') + os.pathsep + os.environ.get('PYTHONPATH', '')}
    q = subprocess.run([sys.executable, '-B', '-c', script, str(c.home), profile, str(age),
                        'present' if undo else 'absent'], env=env, capture_output=True, text=True, timeout=20)
    assert q.returncode == 0, q.stderr
    journal = home / 'state/connections' / ('account-' + hashlib.sha256(b'google-personal').hexdigest()[:24] + '.json')
    assert ('undo' in json.loads(journal.read_bytes())) == undo
    return journal, config


def read_only_inputs(c, journal, config):
    return protected(c), journal.read_bytes(), config.read_bytes(), journal.stat().st_mode, config.stat().st_mode


@pytest.mark.parametrize('undo', [True, False])
@pytest.mark.parametrize('profile', ['alpha', 'default'])
def test_expired_producer_actual_release_upgrade_bundle_leaves_inputs_unchanged(legacy, undo, profile):
    c = legacy; journal, config = legacy_disconnect(c, undo=undo, profile=profile)
    before = read_only_inputs(c, journal, config)
    q = subprocess.run([sys.executable, '-B', str(c.candidate / 'install/hejo-install'), '--home', str(c.home),
                        '--upgrade-legacy'], env=c.env, capture_output=True, text=True, timeout=40)
    assert q.returncode == 0, q.stderr
    q = subprocess.run([sys.executable, '-B', str(c.library.parents[2] / 'bin/hermes-team-kit-deploy'),
                        'apply', '--root', str(c.home), '--bundle', str(c.library.parents[2])],
                       env=c.env, capture_output=True, text=True, timeout=50)
    assert q.returncode == 0, q.stdout + q.stderr
    c.policy.verify_bundle(c.home)
    assert read_only_inputs(c, journal, config) == before
    from hermes_facility.account_connect import run
    assert run(c.home, 'undo', profile, 'google-personal')['reason'] == 'REAUTH_REQUIRED'
    assert read_only_inputs(c, journal, config) == before
    assert len(links(c)) == 3 and not (c.home / 'profiles/gamma/plugins/hejo').exists()


DAMAGE = ['unexpired', 'missing-at', 'future', 'nan', 'infinity', 'bool-at', 'string-at', 'huge-at',
          'connect', 'applying', 'undoing', 'choosing', 'done', 'restart', 'session', 'binding_id',
          'worker_pid', 'unknown', 'before-path', 'after-path', 'after-hash', 'undo-shape', 'before-format',
          'enabled', 'missing-enabled', 'missing-disabled', 'disabled-string', 'duplicate-config',
          'duplicate-journal', 'null-journal', 'journal-link', 'config-link', 'journal-parent-link',
          'transition', 'credential']


@pytest.mark.parametrize('damage', DAMAGE)
def test_legacy_completion_refuses_ambiguous_or_changed_inputs_without_writes(legacy, damage):
    c = legacy; journal, config = legacy_disconnect(c)
    value = json.loads(journal.read_bytes());relative = config.relative_to(c.home).as_posix()
    if damage == 'unexpired': value['at'] = time.time() - 599
    elif damage == 'missing-at': del value['at']
    elif damage in ('future', 'nan', 'infinity', 'bool-at', 'string-at', 'huge-at'):
        value['at'] = {'future': time.time()+10, 'nan': math.nan, 'infinity': math.inf,
                       'bool-at': True, 'string-at': 'expired', 'huge-at': 10**500}[damage]
    elif damage == 'connect': value['action'] = 'connect'
    elif damage in ('applying', 'undoing', 'choosing'): value['phase'] = damage
    elif damage == 'done': value['done'] = ['config']
    elif damage == 'restart': value['restart_required'] = 1
    elif damage in ('session', 'binding_id', 'worker_pid', 'unknown'): value[damage] = None
    elif damage == 'before-path': value['undo']['before'] = {'profiles/beta/config.yaml': '7b7d'}
    elif damage == 'after-path': value['undo']['after'] = {'../config.yaml': hashlib.sha256(config.read_bytes()).hexdigest()}
    elif damage == 'after-hash': value['undo']['after'][relative] = '0'*64
    elif damage == 'undo-shape': value['undo']['extra'] = {}
    elif damage == 'before-format': value['undo']['before'][relative] = 'not-hex'
    elif damage in ('enabled', 'missing-enabled', 'missing-disabled', 'disabled-string'):
        value.pop('undo')  # Off semantics must be checked even after original expiry cleanup.
        from hermes_yaml import safe_load, safe_dump
        doc = safe_load(config.read_bytes())
        if damage == 'enabled': doc['plugins']['entries']['team-delegation']['settings']['gmail']['enabled'] = True
        elif damage == 'missing-enabled': del doc['plugins']['entries']['team-delegation']['settings']['gmail']['enabled']
        elif damage == 'missing-disabled': doc['skills']['disabled'] = []
        else: doc['skills']['disabled'] = '["google-workspace"]'
        config.write_text(safe_dump(doc))
    elif damage == 'duplicate-config': value.pop('undo');config.write_text('plugins: {}\nplugins: {}\n')
    elif damage == 'transition':
        (c.home/'owner/vault.yaml').write_text('{"google_connections":{"version":1,"profiles":{"alpha":null}}}')
    elif damage == 'credential':
        folder=config.parent/'hejo';folder.mkdir();(folder/'google-token.json').write_text('synthetic-never-read')
    if damage == 'duplicate-journal': journal.write_text('{"phase":"applied","phase":"failed"}')
    elif damage == 'null-journal': journal.write_text('null')
    else: journal.write_text(json.dumps(value))
    if damage in ('journal-link', 'config-link'):
        target = journal if damage == 'journal-link' else config
        other=target.with_name(target.name+'.synthetic');target.rename(other);target.symlink_to(other)
    elif damage == 'journal-parent-link':
        parent=journal.parent;other=parent.with_name('detached');parent.rename(other);parent.symlink_to(other)
    before = journal.read_bytes(), config.read_bytes(), c.receipt.read_bytes(), links(c)
    with pytest.raises((ValueError, OSError)):
        c.ns['upgrade_legacy'](c.home, c.candidate)
    assert (journal.read_bytes(), config.read_bytes(), c.receipt.read_bytes(), links(c)) == before


@pytest.mark.parametrize('undo', [True, False])
@pytest.mark.parametrize('entry', ['common', 'first', 'failed', 'uninstalled'])
def test_common_first_and_recovery_keep_rejecting_legacy_applied(legacy, undo, entry):
    c = legacy;journal,config=legacy_disconnect(c,undo=undo)
    if entry=='first':c.receipt.unlink()
    if entry in ('failed','uninstalled'):
        value=json.loads(c.receipt.read_bytes());value['status']=entry;c.receipt.write_text(json.dumps(value))
    before=journal.read_bytes(),config.read_bytes(),c.receipt.read_bytes() if c.receipt.exists() else None,links(c)
    with pytest.raises(ValueError):
        if entry=='common':c.policy.no_google_residue(c.home)
        elif entry=='first':c.policy.preflight(c.home,c.candidate,first_package=c.candidate)
        else:c.policy.recovery_receipt(c.home)
    assert (journal.read_bytes(),config.read_bytes(),c.receipt.read_bytes() if c.receipt.exists() else None,links(c))==before


@pytest.mark.parametrize('what', ['journal', 'config', 'journal-replace', 'config-replace', 'clock', 'clock-small', 'transition', 'credential'])
@pytest.mark.parametrize('during_failure', [False, True])
def test_completed_transaction_cas_before_write_and_failure_restore(legacy, monkeypatch, what, during_failure):
    c=legacy;journal,config=legacy_disconnect(c,undo=False);before=links(c);old_receipt=c.receipt.read_bytes();original=c.policy.LegacyUpgrade.revalidate;count=0
    def change():
        if what in ('journal','config'):
            f=journal if what=='journal' else config;f.write_bytes(f.read_bytes()+b'\n')
        elif what in ('journal-replace','config-replace'):
            f=journal if what=='journal-replace' else config;data=f.read_bytes();f.unlink();f.write_bytes(data)
        elif what=='clock':monkeypatch.setattr(c.policy.time,'time',lambda:1.0)
        elif what=='clock-small':
            earlier=time.time()-0.25;monkeypatch.setattr(c.policy.time,'time',lambda:earlier)
        elif what=='transition':(c.home/'owner/vault.yaml').write_text('{"google_connections":{"version":1,"profiles":{"alpha":null}}}')
        else:
            folder=config.parent/'hejo';folder.mkdir();(folder/'google-token-tmp.json').write_text('synthetic')
    def check(self,ls,receipt):
        nonlocal count
        count+=1
        if not during_failure and count==2:change()
        return original(self,ls,receipt)
    monkeypatch.setattr(c.policy.LegacyUpgrade,'revalidate',check)
    if during_failure:
        ns=c.ns['upgrade_legacy'].__globals__;replace=ns['replace_link']
        def fail(path,target):replace(path,target);change();raise OSError('synthetic failure after link')
        monkeypatch.setitem(ns,'replace_link',fail)
    with pytest.raises(ValueError):c.ns['upgrade_legacy'](c.home,c.candidate)
    if during_failure:
        assert json.loads(c.receipt.read_bytes())['status']=='upgrading-legacy'
        assert str(c.candidate/'gate') in links(c).values()
    else:assert links(c)==before and c.receipt.read_bytes()==old_receipt


def test_unchanged_expired_inputs_allow_only_code_rollback(legacy,monkeypatch):
    c=legacy;journal,config=legacy_disconnect(c);before=read_only_inputs(c,journal,config);old_links=links(c);receipt=c.receipt.read_bytes();ns=c.ns['upgrade_legacy'].__globals__;replace=ns['replace_link'];called=False
    def fail(path,target):
        nonlocal called
        replace(path,target)
        if not called:called=True;raise OSError('synthetic link write failure')
    monkeypatch.setitem(ns,'replace_link',fail)
    with pytest.raises(OSError):c.ns['upgrade_legacy'](c.home,c.candidate)
    assert links(c)==old_links and c.receipt.read_bytes()==receipt
    assert read_only_inputs(c,journal,config)==before
