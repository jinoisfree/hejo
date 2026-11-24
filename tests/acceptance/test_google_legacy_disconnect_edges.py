"""GD-T14 exact expiry and filesystem metadata boundaries."""
import json
from types import SimpleNamespace

import pytest
from test_google_legacy import legacy, package, links
from test_google_legacy_disconnect import legacy_disconnect


@pytest.mark.parametrize('age,allowed', [(599.999,False),(600.0,True)])
def test_expiry_uses_original_six_hundred_second_boundary(legacy,monkeypatch,age,allowed):
    c=legacy;journal,config=legacy_disconnect(c);at=json.loads(journal.read_bytes())['at']
    monkeypatch.setattr(c.policy,'time',SimpleNamespace(time=lambda:at+age))
    if allowed:c.policy.LegacyUpgrade(c.home,c.candidate)
    else:
        with pytest.raises(ValueError,match='NOT_EXPIRED'):c.policy.LegacyUpgrade(c.home,c.candidate)


@pytest.mark.parametrize('clock', [float('nan'),float('inf'),True,None,-1.0,0.0])
def test_unknown_clock_is_not_expiry_evidence(legacy,monkeypatch,clock):
    c=legacy;legacy_disconnect(c);monkeypatch.setattr(c.policy,'time',SimpleNamespace(time=lambda:clock))
    with pytest.raises(ValueError,match='CLOCK_CHANGED'):c.policy.LegacyUpgrade(c.home,c.candidate)


@pytest.mark.parametrize('target',['journal','config'])
def test_file_mode_change_blocks_legacy_transaction(legacy,monkeypatch,target):
    c=legacy;journal,config=legacy_disconnect(c,undo=False);original=c.policy.LegacyUpgrade.revalidate;calls=0;before=links(c),c.receipt.read_bytes()
    def race(self,ls,receipt):
        nonlocal calls
        calls+=1
        if calls==2:
            f=journal if target=='journal' else config
            f.chmod(0o640 if f.stat().st_mode&0o777==0o600 else 0o600)
        return original(self,ls,receipt)
    monkeypatch.setattr(c.policy.LegacyUpgrade,'revalidate',race)
    with pytest.raises(ValueError,match='INPUT_CHANGED'):c.ns['upgrade_legacy'](c.home,c.candidate)
    assert (links(c),c.receipt.read_bytes())==before


def test_old_before_is_opaque_never_decoded_or_restored(legacy):
    c=legacy;journal,config=legacy_disconnect(c);value=json.loads(journal.read_bytes())
    # Valid hex with no UTF-8/config meaning: admission uses only its type/path.
    value['undo']['before'][config.relative_to(c.home).as_posix()]='ff'
    journal.write_text(json.dumps(value));before=journal.read_bytes(),config.read_bytes()
    assert c.ns['upgrade_legacy'](c.home,c.candidate)==0
    assert (journal.read_bytes(),config.read_bytes())==before


def test_fixed_producer_can_disable_an_empty_prior_config(legacy):
    c=legacy;journal,config=legacy_disconnect(c,empty_before=True)
    value=json.loads(journal.read_bytes())
    assert value['undo']['before'][config.relative_to(c.home).as_posix()]==''
    before=journal.read_bytes(),config.read_bytes()
    assert c.ns['upgrade_legacy'](c.home,c.candidate)==0
    assert (journal.read_bytes(),config.read_bytes())==before
