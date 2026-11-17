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
    with pytest.raises(ship['ShipError'],match='태그'):
        ship['publish'](path,'a'*40)
    assert not calls


def test_at84_publish_draft_upload_verify_signed_feed_latest(ship, tmp_path, monkeypatch):
    path,value=publish_fixture(ship,tmp_path,monkeypatch)
    calls=[]
    metadata={'draft':True,'assets':[{'name':value['archive'],'state':'uploaded','size':7,'digest':'sha256:'+value['sha256']}]}
    def run(args):
        calls.append(list(map(str,args)))
        if args[:2]==['gh','api']:
            result=deepcopy(metadata)
            feed=tmp_path/'appcast.xml'
            if feed.exists():
                result['assets'].append({'name':'appcast.xml','state':'uploaded','size':feed.stat().st_size,'digest':'sha256:'+ship['digest'](feed)})
            return json.dumps(result)
        return ''
    monkeypatch.setitem(ship,'run',run)
    ship['publish'](path,'a'*40)
    gh=[c for c in calls if c[0]=='gh']
    assert gh[0][:3]==['gh','release','create'] and '--draft' in gh[0]
    assert gh[1][:3]==['gh','release','upload']
    assert gh[-1][:3]==['gh','release','edit'] and '--latest' in gh[-1]
    assert any('--verify' in c and c[-1].endswith('appcast.xml') for c in calls)
    assert all('delete' not in c and '--clobber' not in c for c in calls)
    # A corrupt uploaded asset must leave the draft and never publish it.
    calls.clear();metadata['assets'][0]['digest']='sha256:wrong'
    with pytest.raises(ship['ShipError'],match='초안'):
        ship['publish'](path,'a'*40)
    assert not any(c[:3]==['gh','release','edit'] for c in calls)


def test_at84_fixed_sdk_pin_and_install_same_tag():
    root=SHIP.parent.parent
    fetch=(root/'app/scripts/fetch_sparkle.sh').read_text()
    assert '2.10.0' in fetch and 'c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c' in fetch
    installer=(root/'install/get-hejo').read_text()
    assert 'archive="hejo-${tag#v}-arm64.zip"' in installer
    assert '/releases/download/$tag/$archive' in installer and '/tar.gz/refs/tags/$tag' in installer
    value=plistlib.loads((root/'app/Resources/Info.plist').read_bytes())
    assert value['CFBundleShortVersionString']=='0.2.0' and value['CFBundleVersion']=='2'
    assert value['SURequireSignedFeed'] and value['SUVerifyUpdateBeforeExtraction']
    assert not value['SUEnableAutomaticChecks'] and not value['SUAutomaticallyUpdate']
