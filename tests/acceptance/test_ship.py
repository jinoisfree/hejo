"""AT-HF-84: local release preparation and owner-only publishing, no real remote writes."""
import base64
from copy import deepcopy
import json
from pathlib import Path
import plistlib
import runpy
import xml.etree.ElementTree as ET

import pytest

SHIP = Path(__file__).resolve().parents[2] / 'install/hejo-ship'


@pytest.fixture
def ship(tmp_path, monkeypatch):
    ns = runpy.run_path(str(SHIP), run_name='ship_test')
    g = ns['prepare'].__globals__
    monkeypatch.setitem(g, 'ROOT', tmp_path)
    return g


def test_at84_public_manifest_and_signed_enclosure(ship, tmp_path):
    archive = tmp_path / 'hejo-0.2.1-arm64.zip'
    archive.write_bytes(b'fake signed archive')
    value = dict(commit='a'*40, tree='b'*40, repository='sample/hejo', version='0.2.1', build='3',
                 archive=archive.name, size=archive.stat().st_size, sha256=ship['digest'](archive), signature='public-signature')
    path = tmp_path / 'prepared.json'
    path.write_text(json.dumps(value))
    assert ship['load_prepared'](path)[0] == value
    enclosure = ET.fromstring(ship['appcast'](value)).find('channel/item/enclosure')
    assert enclosure.attrib['url'] == 'https://github.com/sample/hejo/releases/download/v0.2.1/hejo-0.2.1-arm64.zip'
    assert enclosure.attrib['length'] == '19'
    assert enclosure.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}version'] == '3'
    archive.write_bytes(b'tampered')
    with pytest.raises(ship['ShipError'], match='바뀌었어요'):
        ship['load_prepared'](path)


def test_at84_setup_does_not_replace_other_key(ship, tmp_path, monkeypatch):
    path = tmp_path / 'app/Resources/Info.plist'
    path.parent.mkdir(parents=True)
    path.write_bytes(plistlib.dumps({'SUPublicEDKey':'previous-public'}))
    monkeypatch.setitem(ship, 'tools', lambda:tmp_path)
    monkeypatch.setitem(ship, 'public_key', lambda _: 'another-public')
    with pytest.raises(ship['ShipError'], match='달라요'):
        ship['setup']()
    assert plistlib.loads(path.read_bytes())['SUPublicEDKey'] == 'previous-public'


def test_at84_prepare_rejects_dirty_or_other_tree(ship, monkeypatch, tmp_path):
    monkeypatch.setitem(ship, 'git', lambda *args:' M changed')
    with pytest.raises(ship['ShipError'], match='커밋하지'):
        ship['prepare'](tmp_path/'hejo.app', tmp_path/'out')
    monkeypatch.setitem(ship, 'git', lambda *args: '' if args[0]=='status' else ('c'*40 if args[-1]=='HEAD^{tree}' else 'a'*40))
    with pytest.raises(ship['ShipError'], match='공개본과'):
        ship['prepare'](tmp_path/'hejo.app', tmp_path/'out')


def test_at84_prepare_checks_build_source_and_key(ship, monkeypatch, tmp_path):
    app = tmp_path/'hejo.app'; resources=app/'Contents/Resources'; resources.mkdir(parents=True)
    source = tmp_path/'app/Resources/Info.plist'; source.parent.mkdir(parents=True)
    value={'CFBundleShortVersionString':'0.2.1','CFBundleVersion':'3','SUPublicEDKey':'key','HejoUpdateRepository':'sample/hejo'}
    source.write_bytes(plistlib.dumps(value))
    monkeypatch.setitem(ship, 'bundle', lambda _:value)
    def git(*args):
        if args[0]=='status': return ''
        if args[0]=='rev-parse': return 'a'*40
        return 'a'*40
    monkeypatch.setitem(ship, 'git', git)
    build=resources/'BuildInfo.json'; build.write_text(json.dumps({'tree':'b'*40,'dirty':False}))
    with pytest.raises(ship['ShipError'], match='빌드와 공개본'):
        ship['prepare'](app,tmp_path/'out')
    build.write_text(json.dumps({'tree':'a'*40,'dirty':True}))
    with pytest.raises(ship['ShipError'], match='빌드와 공개본'):
        ship['prepare'](app,tmp_path/'out')
    build.write_text(json.dumps({'tree':'a'*40,'dirty':False}))
    monkeypatch.setitem(ship, 'tools', lambda:tmp_path)
    monkeypatch.setitem(ship, 'public_key', lambda _:'wrong')
    with pytest.raises(ship['ShipError'], match='키체인'):
        ship['prepare'](app,tmp_path/'out')


def publish_fixture(ship, tmp_path, monkeypatch):
    archive=tmp_path/'hejo-0.2.1-arm64.zip'; archive.write_bytes(b'archive')
    value=dict(commit='a'*40,tree='b'*40,repository='sample/hejo',version='0.2.1',build='3',archive=archive.name,
               size=7,sha256=ship['digest'](archive),signature='public-signature',publicKey='public-key')
    path=tmp_path/'prepared.json';path.write_text(json.dumps(value))
    monkeypatch.setitem(ship,'tools',lambda:tmp_path)
    monkeypatch.setitem(ship,'public_key',lambda _:'public-key')
    monkeypatch.setitem(ship,'git',lambda *args:'a'*40+'\trefs/heads/main')
    return path,value


def test_at84_owner_approval_and_existing_tag_before_writes(ship, tmp_path, monkeypatch):
    path,value=publish_fixture(ship,tmp_path,monkeypatch)
    calls=[];monkeypatch.setitem(ship,'run',lambda args: calls.append(args) or '')
    with pytest.raises(ship['ShipError'],match='승인'):
        ship['publish'](path,'c'*40)
    assert not calls
    monkeypatch.setitem(ship,'git',lambda *args:'a'*40+'\trefs/heads/main\n'+'b'*40+'\trefs/tags/v0.2.1')
    monkeypatch.setitem(ship,'run',lambda args: calls.append(args) or '[[]]')
    with pytest.raises(ship['ShipError'],match='태그'):
        ship['publish'](path,'a'*40)
    assert calls == [['gh', 'api', 'repos/sample/hejo/releases', '--paginate', '--slurp']]


class ReleaseAPI:
    """GitHub boundary: tag lookup omits drafts; paginated lists include them."""

    def __init__(self, ship, value):
        self.ship = ship
        self.value = value
        self.calls = []
        self.drafts = []
        self.list_reads = 0
        self.change_on_read = {}
        self.corrupt_asset = None

    def __call__(self, args):
        args = list(map(str, args))
        self.calls.append(args)
        if args[:2] == ['gh', 'api']:
            endpoint = args[2]
            if endpoint.startswith('repos/sample/hejo/releases/tags/'):
                raise self.ship['ShipError']('gh 실행 실패: 404')
            assert endpoint == 'repos/sample/hejo/releases'
            assert args[3:] == ['--paginate', '--slurp']
            self.list_reads += 1
            drafts = deepcopy(self.drafts)
            if self.list_reads in self.change_on_read:
                drafts = self.change_on_read[self.list_reads](drafts)
            # The selected draft is on the next page, among unrelated/published releases.
            return json.dumps([[{'tag_name': 'v9.0.0', 'draft': True},
                                {'tag_name': 'v0.2.1', 'draft': False}], drafts])
        if args[:3] == ['gh', 'release', 'create']:
            assert not self.drafts
            self.drafts = [{'tag_name': 'v0.2.1', 'draft': True, 'assets': []}]
        elif args[:3] == ['gh', 'release', 'upload']:
            asset = Path(args[4])
            entry = {'name': asset.name, 'state': 'uploaded', 'size': asset.stat().st_size,
                     'digest': 'sha256:' + self.ship['digest'](asset)}
            if asset.name == self.corrupt_asset:
                entry['digest'] = 'sha256:wrong'
            self.drafts[0]['assets'].append(entry)
        return ''


def test_at84_publish_draft_upload_verify_signed_feed_latest(ship, tmp_path, monkeypatch):
    path, value = publish_fixture(ship, tmp_path, monkeypatch)
    api = ReleaseAPI(ship, value)
    monkeypatch.setitem(ship, 'run', api)
    ship['publish'](path, 'a'*40)
    gh = [c for c in api.calls if c[0] == 'gh']
    assert gh[0][:2] == ['gh', 'api']  # Existing drafts checked before any remote write.
    writes = [c for c in gh if c[1] == 'release']
    assert [c[2] for c in writes] == ['create', 'upload', 'upload', 'edit']
    assert '--draft' in writes[0] and '--latest' in writes[-1]
    assert api.list_reads == 3  # Before creation, after archive, after signed feed.
    assert any('--verify' in c and c[-1].endswith('appcast.xml') for c in api.calls)
    assert all('delete' not in c and '--clobber' not in c for c in api.calls)


@pytest.mark.parametrize('asset', ['hejo-0.2.1-arm64.zip', 'appcast.xml'])
def test_at84_publish_corrupt_upload_leaves_draft(ship, tmp_path, monkeypatch, asset):
    path, value = publish_fixture(ship, tmp_path, monkeypatch)
    api = ReleaseAPI(ship, value)
    api.corrupt_asset = asset
    monkeypatch.setitem(ship, 'run', api)
    with pytest.raises(ship['ShipError'], match='초안|피드'):
        ship['publish'](path, 'a'*40)
    assert api.drafts[0]['draft'] is True
    assert not any(c[:3] == ['gh', 'release', 'edit'] for c in api.calls)
    assert all('delete' not in c and '--clobber' not in c for c in api.calls)


@pytest.mark.parametrize('read', [2, 3])
@pytest.mark.parametrize('count', [0, 2])
def test_at84_publish_requires_exactly_one_draft_after_each_upload(
        ship, tmp_path, monkeypatch, read, count):
    path, value = publish_fixture(ship, tmp_path, monkeypatch)
    api = ReleaseAPI(ship, value)
    api.change_on_read[read] = lambda drafts: drafts * count
    monkeypatch.setitem(ship, 'run', api)
    with pytest.raises(ship['ShipError'], match='하나로 확인하지 못했어요'):
        ship['publish'](path, 'a'*40)
    assert api.drafts[0]['draft'] is True
    writes = [c[2] for c in api.calls if c[:2] == ['gh', 'release']]
    assert writes == ['create'] + ['upload'] * (read - 1)
    assert all('delete' not in c and '--clobber' not in c for c in api.calls)


@pytest.mark.parametrize('count', [1, 2])
@pytest.mark.parametrize('existing_tag', [False, True])
def test_at84_publish_existing_draft_is_preserved(ship, tmp_path, monkeypatch, count, existing_tag):
    path, value = publish_fixture(ship, tmp_path, monkeypatch)
    if existing_tag:
        monkeypatch.setitem(ship, 'git', lambda *args: 'a'*40+'\trefs/heads/main\n'+'b'*40+'\trefs/tags/v0.2.1')
    api = ReleaseAPI(ship, value)
    api.drafts = [{'tag_name': 'v0.2.1', 'draft': True, 'assets': [{'name': 'existing'}]}] * count
    before = deepcopy(api.drafts)
    monkeypatch.setitem(ship, 'run', api)
    with pytest.raises(ship['ShipError']) as error:
        ship['publish'](path, 'a'*40)
    assert str(error.value) == '같은 태그의 초안이 남아 있어요. GitHub에서 확인한 뒤 지우고 다시 실행해 주세요.'
    assert api.drafts == before
    assert not any(c[:2] == ['gh', 'release'] for c in api.calls)


def test_at84_fixed_sdk_pin_and_install_same_tag():
    root=SHIP.parent.parent
    fetch=(root/'app/scripts/fetch_sparkle.sh').read_text()
    assert '2.10.0' in fetch and 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c' in fetch
    installer=(root/'install/get-hejo').read_text()
    assert 'archive="hejo-${tag#v}-arm64.zip"' in installer
    assert '/releases/download/$tag/$archive' in installer and '/tar.gz/refs/tags/$tag' in installer
    value=plistlib.loads((root/'app/Resources/Info.plist').read_bytes())
    assert value['CFBundleShortVersionString']=='0.2.1' and value['CFBundleVersion']=='3'
    assert value['SURequireSignedFeed'] and value['SUVerifyUpdateBeforeExtraction']
    assert not value['SUEnableAutomaticChecks'] and not value['SUAutomaticallyUpdate']
