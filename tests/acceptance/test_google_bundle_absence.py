"""D-2: first bundle install and failure recovery preserve absent companion slots."""
import json
import pytest
from test_google_bundle import bundle, snapshot, seal, MANUAL
from test_google_deployment import deployed, team_library
from test_google_release import package


@pytest.mark.parametrize('failure', [False, True])
def test_initially_absent_companions_are_created_or_restored_absent(bundle, monkeypatch, failure):
    release, root, source, env, policy, _, command = bundle
    names = ['bin/hermes-team-kit-deploy', MANUAL]
    for name in names: (root / name).unlink()
    support = json.loads((source / 'plugin-store/team-kit/google-connection-support.json').read_text())
    previous = support['bundle']['predecessor']
    for name in names: previous['files'][name] = None
    seal(source, policy, previous)
    before = snapshot(root)
    if failure:
        from hermes_facility import config_assembly
        from hermes_facility.google_deployment import deploy_bundle
        original = config_assembly.atomic_write
        def failed(path, data):
            if path == root / 'plugin-store/links.json': raise OSError('synthetic late failure')
            return original(path, data)
        monkeypatch.setattr(config_assembly, 'atomic_write', failed)
        with pytest.raises(OSError): deploy_bundle(root, source)
        assert snapshot(root) == before
        assert not list((root / 'plugin-store').glob('.team-kit-deploy-*'))
    else:
        result = command(); assert result.returncode == 0, result.stdout + result.stderr
        for name in names: assert policy.file_identity(root / name) == policy.file_identity(source / name)
