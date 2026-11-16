"""Receipt-owned private loopback service files. Registration is an explicit operating step."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import plistlib
import socket
import sys
import tempfile


def digest(raw):return hashlib.sha256(raw).hexdigest()


def safe(home,relative):
    home=Path(home).resolve();path=home/relative
    if path.parent.resolve()!=path.parent or path.is_symlink():raise ValueError('admin_path_conflict')
    return path


def atomic(path,raw):
    fd,name=tempfile.mkstemp(prefix='.admin-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as stream:
            os.fchmod(stream.fileno(),0o600);stream.write(raw);stream.flush();os.fsync(stream.fileno())
        os.replace(name,path)
    finally:
        if os.path.exists(name):os.unlink(name)


def available():
    return all(importlib.util.find_spec(name) is not None for name in ('fastapi','uvicorn'))


def prepare(home,receipt,save,*,dependencies=available):
    previous=receipt.get('admin',{})
    if previous.get('state')=='applied':
        return check(home,receipt)
    if previous.get('state') in {'pending','removing'}:
        if not remove(home,receipt,save):return False
    if not dependencies():
        receipt['admin']={'state':'skipped','reason':'missing_dependencies'};save(home,receipt)
        print('서버의 Hermes를 업데이트해 주세요(hermes update); admin skipped')
        return True
    paths=['hejo/admin.json','hejo/admin.plist']
    # A receipt never contains the token, even while preparing an interrupted install.
    if any(safe(home,p).exists() for p in paths):
        receipt['admin']={'state':'preserved_owner_change'};save(home,receipt);return True
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    raw=json.dumps({'port':port,'token':os.urandom(48).hex()}).encode()+b'\n'
    wrapper=Path(__file__).resolve().with_name('hejo-admin')
    plist=plistlib.dumps({'Label':'io.github.hermes-hejo.admin','ProgramArguments':[sys.executable,str(wrapper),'--home',str(home),'--run'],
        'RunAtLoad':True,'KeepAlive':True,'EnvironmentVariables':{'HERMES_HOME':str(home)},'StandardOutPath':'/dev/null','StandardErrorPath':'/dev/null'})
    receipt['admin']={'state':'pending','files':{paths[0]:digest(raw),paths[1]:digest(plist)}};save(home,receipt)
    for path,content in zip(paths,(raw,plist)):atomic(safe(home,path),content)
    receipt['admin']['state']='applied';save(home,receipt)
    return True


def check(home,receipt):
    item=receipt.get('admin',{})
    if item.get('state') in (None,'skipped','removed','preserved_owner_change'):return True
    return all((path:=safe(home,name)).is_file() and path.stat().st_mode & 0o777==0o600 and digest(path.read_bytes())==wanted
               for name,wanted in item['files'].items())


def remove(home,receipt,save):
    item=receipt.get('admin',{})
    if item.get('state') not in {'applied','pending','removing'}:return True
    if any((path:=safe(home,name)).exists() and digest(path.read_bytes())!=wanted for name,wanted in item['files'].items()):
        item['state']='preserved_owner_change';save(home,receipt);return False
    item['state']='removing';save(home,receipt)
    for name in item['files']:safe(home,name).unlink(missing_ok=True)
    item['state']='removed';save(home,receipt);return True
