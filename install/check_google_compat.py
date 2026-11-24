#!/usr/bin/env python3
"""Read-only deployment barrier. This file is the single compatibility policy."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys


class CompatibilityError(ValueError):
    pass


def regular_bytes(path):
    path = Path(path).absolute()
    if path.resolve() != path:
        raise CompatibilityError('UNSAFE_COMPAT_FILE')
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > 4 * 1024 * 1024:
            raise CompatibilityError('INVALID_COMPAT_FILE')
        return stream.read()


def json_value(data):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise CompatibilityError('DUPLICATE_COMPAT_KEY')
            result[key] = value
        return result
    return json.loads(data, object_pairs_hook=unique)


def mapping_line(line):
    # A deliberately bounded reader, not a general YAML loader. Unsupported
    # YAML is refused instead of being mistaken for an unconverted airport.
    match = re.fullmatch(r'''("(?:[^"\\]|\\.)*"|'(?:[^']|'')*'|[A-Za-z_][A-Za-z0-9_-]*):(?:[ \t]+(.*))?''', line)
    if not match:
        raise CompatibilityError('UNSUPPORTED_VAULT_FORMAT')
    key, value = match.groups()
    if key.startswith('"'):
        key = json.loads(key)
    elif key.startswith("'"):
        key = key[1:-1].replace("''", "'")
    return key, (value or '').strip()


def transition_version(home):
    path = Path(home) / 'owner/vault.yaml'
    if path.parent.is_symlink():
        raise CompatibilityError('UNSAFE_VAULT_PARENT')
    if not path.exists() and not path.is_symlink():
        return None
    text = regular_bytes(path).decode('utf-8')
    if not text.strip():
        return None
    if text.lstrip().startswith('{'):
        document = json_value(text)
        if not isinstance(document, dict):
            raise CompatibilityError('INVALID_VAULT_FORMAT')
        if 'google_connections' not in document:
            return None
        value = document['google_connections']
        if (not isinstance(value, dict) or type(value.get('version')) is not int
                or not isinstance(value.get('profiles'), dict)):
            raise CompatibilityError('INVALID_GOOGLE_CONNECTIONS')
        if value['version'] != 1:
            raise CompatibilityError('UNKNOWN_GOOGLE_VERSION')
        return value['version'] if value['profiles'] else None
    roots, section, active, started = set(), [], False, False
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        if '\t' in line[:len(line)-len(line.lstrip())]:
            raise CompatibilityError('UNSUPPORTED_VAULT_FORMAT')
        if line == '---' and not started:
            started = True
            continue
        started = True
        if not line.startswith(' '):
            key, value = mapping_line(line)
            if key in roots:
                raise CompatibilityError('DUPLICATE_COMPAT_KEY')
            roots.add(key)
            active = key == 'google_connections'
            if active and value and not value.startswith('#'):
                raise CompatibilityError('UNSUPPORTED_GOOGLE_FORMAT')
        elif active:
            section.append(line)
    if 'google_connections' not in roots:
        return None
    if not section:
        raise CompatibilityError('INVALID_GOOGLE_CONNECTIONS')
    indent = min(len(line)-len(line.lstrip()) for line in section)
    fields = {}
    profiles = []
    collecting = False
    for line in section:
        depth = len(line)-len(line.lstrip())
        if depth == indent:
            key, value = mapping_line(line.strip())
            if key in fields:
                raise CompatibilityError('DUPLICATE_COMPAT_KEY')
            fields[key] = value
            collecting = key == 'profiles'
        elif collecting:
            profiles.append(line)
    version = fields.get('version', '')
    if not re.fullmatch(r'[1-9][0-9]*(?:\s+#.*)?', version) or 'profiles' not in fields:
        raise CompatibilityError('INVALID_GOOGLE_CONNECTIONS')
    if int(version.split()[0]) != 1:
        raise CompatibilityError('UNKNOWN_GOOGLE_VERSION')
    if re.fullmatch(r'\{\s*\}(?:\s+#.*)?', fields['profiles']) and not profiles:
        return None
    if fields['profiles'] and not fields['profiles'].startswith('#') or not profiles:
        raise CompatibilityError('UNSUPPORTED_GOOGLE_FORMAT')
    return int(version.split()[0])


def validate_build(target, component):
    target = Path(target).resolve(strict=True)
    if not target.is_dir():
        raise CompatibilityError('INVALID_DEPLOY_TARGET')
    relative = 'install/google-connection-support.json' if component == 'hejo' else 'google-connection-support.json'
    value = json_value(regular_bytes(target / relative))
    if (not isinstance(value, dict) or value.get('schema') != 'google-connection-support/1'
            or value.get('component') != component or value.get('disconnect_mode') != 'forget_account'
            or not isinstance(value.get('versions'), list) or not value['versions']
            or any(type(version) is not int or version < 1 for version in value['versions'])):
        raise CompatibilityError('INVALID_GOOGLE_SUPPORT')
    if component == 'hejo':
        regular_bytes(target / 'install/check_google_compat.py')
    return value['versions']


def check_target(home, target, component):
    version = transition_version(home)
    target = Path(target).resolve(strict=True)
    if not target.is_dir():
        raise CompatibilityError('INVALID_DEPLOY_TARGET')
    if version is not None and version not in validate_build(target, component):
        raise CompatibilityError('UNSUPPORTED_GOOGLE_VERSION')


def installed_path(home):
    home = Path(home).resolve(strict=True)
    receipt = json_value(regular_bytes(home / 'hejo/install-receipt.json'))
    link = home / 'plugins/hejo'
    if (not isinstance(receipt, dict) or type(receipt.get('version')) is not int or receipt.get('version') not in (1, 2)
            or receipt.get('status') != 'installed' or not link.is_symlink()
            or link.parent.resolve() != link.parent):
        raise CompatibilityError('GOOGLE_COMPAT_INSTALL_REQUIRED')
    targets = [item for item in receipt.get('targets', []) if isinstance(item, dict)
               and item.get('kind') == 'link' and item.get('path') == 'plugins/hejo']
    if len(targets) != 1 or targets[0].get('state') != 'applied' or not isinstance(targets[0].get('after'), str):
        raise CompatibilityError('GOOGLE_COMPAT_RECEIPT_MISMATCH')
    target = Path(targets[0]['after'])
    if not target.is_absolute():
        target = link.parent / target
    gate = link.resolve(strict=True)
    if target.resolve(strict=True) != gate or gate.name != 'gate' or not gate.is_dir():
        raise CompatibilityError('GOOGLE_COMPAT_RECEIPT_MISMATCH')
    checker = gate.parent / 'install/check_google_compat.py'
    regular_bytes(checker)
    return checker


def profile_homes(home):
    homes = [home]
    profiles = home / 'profiles'
    if profiles.is_symlink():
        raise CompatibilityError('UNSAFE_PROFILE_PATH')
    if profiles.exists():
        for child in profiles.iterdir():
            if child.is_symlink():
                raise CompatibilityError('UNSAFE_PROFILE_PATH')
            if child.is_dir():
                homes.append(child)
    return homes


def no_google_residue(home):
    if transition_version(home) is not None:
        raise CompatibilityError('GOOGLE_RECOVERY_REQUIRED')
    journal_name = 'account-' + hashlib.sha256(b'google-personal').hexdigest()[:24] + '.json'
    for profile in profile_homes(home):
        folder = profile / 'hejo'
        if folder.is_symlink():
            raise CompatibilityError('UNSAFE_CREDENTIAL_PARENT')
        if folder.exists() and any('google-token' in child.name for child in folder.iterdir()):
            raise CompatibilityError('GOOGLE_CREDENTIALS_REMAIN')
        journal = profile / 'state/connections' / journal_name
        if journal.resolve() != journal:
            raise CompatibilityError('UNSAFE_GOOGLE_JOURNAL')
        if journal.exists():
            value = json_value(regular_bytes(journal))
            if not isinstance(value, dict) or value.get('phase') not in ('disconnected', 'cancelled', 'failed'):
                raise CompatibilityError('GOOGLE_AUTH_REMAINS')
            if value.get('worker_pid'):
                try:
                    os.kill(int(value['worker_pid']), 0)
                except ProcessLookupError:
                    pass
                else:
                    raise CompatibilityError('GOOGLE_AUTH_REMAINS')


def recovery_receipt(home):
    raw = regular_bytes(home / 'hejo/install-receipt.json')
    receipt = json_value(raw)
    if (not isinstance(receipt, dict) or type(receipt.get('version')) is not int
            or receipt['version'] not in (1, 2) or receipt.get('status') not in ('failed', 'uninstalled')
            or not isinstance(receipt.get('targets'), list)):
        raise CompatibilityError('INVALID_RECOVERY_RECEIPT')
    no_google_residue(home)
    links = {}
    for item in receipt['targets']:
        if not isinstance(item, dict):
            raise CompatibilityError('INVALID_RECOVERY_RECEIPT')
        if item.get('kind') != 'link':
            continue
        relative = item.get('path')
        if not isinstance(relative, str) or not re.fullmatch(r'(?:profiles/[A-Za-z0-9][A-Za-z0-9_-]*/)?plugins/hejo', relative):
            raise CompatibilityError('UNSAFE_RECOVERY_LINK')
        if relative in links or 'before' not in item or 'after' not in item:
            raise CompatibilityError('INVALID_RECOVERY_RECEIPT')
        links[relative] = item
    if 'plugins/hejo' not in links:
        raise CompatibilityError('INVALID_RECOVERY_RECEIPT')
    for profile in profile_homes(home):
        path = profile / 'plugins/hejo'
        if (path.exists() or path.is_symlink()) and path.relative_to(home).as_posix() not in links:
            raise CompatibilityError('UNRECORDED_CODE_LINK')
    for relative, item in links.items():
        path = home / relative
        if path.parent.resolve() != path.parent:
            raise CompatibilityError('UNSAFE_RECOVERY_LINK')
        before = item['before']
        if before is None:
            if path.exists() or path.is_symlink():
                raise CompatibilityError('CODE_RECOVERY_INCOMPLETE')
        else:
            if not isinstance(before, str) or not before or not path.is_symlink():
                raise CompatibilityError('CODE_RECOVERY_INCOMPLETE')
            normalized = lambda value: os.path.normpath(os.path.join(path.parent, value))
            if normalized(os.readlink(path)) != normalized(before):
                raise CompatibilityError('CODE_RECOVERY_INCOMPLETE')
    return raw


@contextmanager
def deployment_guard(home):
    # The existing vault-writer lock is also deployment exclusion. Keep it for
    # the complete transaction so Google begin/commit cannot enter in between.
    lock = home / 'owner/.app-connect.lock'
    if lock.parent.resolve() != lock.parent:
        raise CompatibilityError('UNSAFE_DEPLOY_LOCK')
    lock.parent.mkdir(mode=0o700, exist_ok=True)
    fd = os.open(lock, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise CompatibilityError('UNSAFE_DEPLOY_LOCK')
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise CompatibilityError('DEPLOYMENT_LOCKED') from None
        yield
    finally:
        os.close(fd)


class Checker:
    """Capture the verified current checker once, including for failure recovery.

    Its code stays only in process memory; replacing a deployment cannot switch
    policy mid-operation or make recovery rediscover the just-replaced package.
    """
    def __init__(self, path, home):
        self.path = Path(path)
        self.source = regular_bytes(path).decode('utf-8')
        self.fingerprint = hashlib.sha256(self.source.encode()).hexdigest()
        self.home = Path(home).resolve(strict=True)
        self.bootstrap = None
        self.receipt = None

    def revalidate(self, target):
        if self.bootstrap == 'recovery':
            if recovery_receipt(self.home) != self.receipt:
                raise CompatibilityError('RECOVERY_CHANGED')
        elif self.bootstrap == 'first':
            path = self.home / 'hejo/install-receipt.json'
            if path.exists() or path.is_symlink():
                raise CompatibilityError('INSTALL_CHANGED')
            no_google_residue(self.home)
        elif installed_path(self.home) != self.path:
            raise CompatibilityError('INSTALL_CHANGED')
        self.check(target)

    def check(self, target, component='hejo'):
        result = subprocess.run([sys.executable, '-I', '-B', '-c', self.source,
                                 '--home', str(self.home), '--component', component, '--target', str(target)],
                                capture_output=True, text=True, timeout=20)
        if result.returncode:
            raise CompatibilityError('GOOGLE_COMPAT_DENIED')


def preflight(home, target, *, first_package=None):
    home = Path(home).resolve(strict=True)
    receipt = home / 'hejo/install-receipt.json'
    mode, raw = None, None
    if first_package is not None and not receipt.exists() and not receipt.is_symlink():
        no_google_residue(home)
        mode = 'first'
    elif first_package is not None:
        value = json_value(regular_bytes(receipt))
        if isinstance(value, dict) and value.get('status') in ('failed', 'uninstalled'):
            raw = recovery_receipt(home)
            mode = 'recovery'
    if mode:
        validate_build(first_package, 'hejo')
        path = Path(first_package).resolve(strict=True) / 'install/check_google_compat.py'
    else:
        path = installed_path(home)
    checker = Checker(path, home)
    checker.bootstrap, checker.receipt = mode, raw
    checker.check(target)
    return checker


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--home', type=Path)
    parser.add_argument('--component', choices=('hejo', 'team-kit'), required=True)
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--validate-build', action='store_true')
    args = parser.parse_args(argv)
    try:
        if args.validate_build:
            if 1 not in validate_build(args.target, args.component):
                raise CompatibilityError('UNSUPPORTED_GOOGLE_VERSION')
        elif args.home is None:
            raise CompatibilityError('HOME_REQUIRED')
        else:
            check_target(args.home, args.target, args.component)
    except (OSError, ValueError, TypeError, KeyError, UnicodeError):
        print('GOOGLE_COMPAT_DENIED', file=sys.stderr)
        return 1
    print('GOOGLE_COMPAT_OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
