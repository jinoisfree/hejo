"""GD-T14 mutation checks run only in isolated fixture policy memory."""
from pathlib import Path

import pytest
from test_google_legacy import legacy, package
from test_google_legacy_disconnect import (
    test_legacy_completion_refuses_ambiguous_or_changed_inputs_without_writes as refuses,
    test_completed_transaction_cas_before_write_and_failure_restore as cas_refuses,
    test_common_first_and_recovery_keep_rejecting_legacy_applied as common_refuses,
)


MUTATIONS = [
    ('expiry', 'now - at < 600', 'False', 'unexpired'),
    ('producer-fields', "set(value) not in (allowed, allowed | {'undo'})", 'False', 'session'),
    ('action', "value.get('action') != 'disconnect'", 'False', 'connect'),
    ('off', 'enabled is not False', 'False', 'enabled'),
    ('after', "undo['after'][relative] != hashlib.sha256(raw).hexdigest()", 'False', 'after-hash'),
    ('undo-path', "if 'undo' in value:", 'if False:', 'before-path'),
    ('cas', 'elif inputs != self.google_inputs:', 'elif False:', 'cas'),
    ('clock', 'or self.google_checked_at is not None and now < self.google_checked_at', 'or False', 'clock'),
    ('common', "if value.get('phase') not in ('disconnected', 'cancelled', 'failed'):",
     "if value.get('phase') not in ('disconnected', 'cancelled', 'failed', 'applied'):", 'common'),
]


@pytest.mark.parametrize('name,old,new,damage', MUTATIONS, ids=[v[0] for v in MUTATIONS])
def test_semantic_rejection_detects_isolated_mutant(legacy, monkeypatch, name, old, new, damage):
    c=legacy;path=c.candidate/'install/check_google_compat.py';original=path.read_bytes();source=original.decode()
    assert source.count(old)==1
    # Product and release files stay untouched: only this fresh fixture module
    # executes the deliberate defect, against the same public rejection test.
    exec(compile(source.replace(old,new,1),str(path),'exec'),c.policy.__dict__)
    with pytest.raises(pytest.fail.Exception,match='DID NOT RAISE'):
        if damage=='cas':cas_refuses(c,monkeypatch,'journal',False)
        elif damage=='clock':cas_refuses(c,monkeypatch,'clock-small',False)
        elif damage=='common':common_refuses(c,True,'common')
        else:refuses(c,damage)
    assert path.read_bytes()==original
