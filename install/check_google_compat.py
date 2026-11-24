#!/usr/bin/env python3
"""Read-only deployment barrier. This file is the single compatibility policy."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shlex
import stat
import subprocess
import sys
import time


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
    if component == 'team-kit' and 'bundle' in value: bundle_declaration(target)
    return value['versions']


# Facility paths only; owner settings and credentials are never bundle members.
BUNDLE_PATHS = ('bin/hermes-plugin-store', 'bin/hermes-skill-assemble',
                'bin/hermes-team-kit-deploy', 'plugin-store/team-delegation/plugin.yaml',
                'shared/secretary-skills/employee-google-workspace/SKILL.md')


def file_identity(path):
    data = regular_bytes(path)
    return {'sha256': hashlib.sha256(data).hexdigest(), 'mode': Path(path).stat().st_mode & 0o777}


def validate_bundle_identity(row):
    if (not isinstance(row, dict) or not re.fullmatch('[0-9a-f]{64}', str(row.get('kit_sha256', '')))
            or not isinstance(row.get('files'), dict) or set(row['files']) != set(BUNDLE_PATHS)):
        raise CompatibilityError('INVALID_GOOGLE_BUNDLE')
    for item in row['files'].values():
        if (item is not None and (not isinstance(item, dict) or set(item) != {'sha256', 'mode'}
                or not re.fullmatch('[0-9a-f]{64}', str(item['sha256']))
                or type(item['mode']) is not int or not 0 <= item['mode'] <= 0o777)):
            raise CompatibilityError('INVALID_GOOGLE_BUNDLE')


def kit_identity(kit):
    kit = Path(kit)
    if kit.is_symlink() or kit.resolve() != kit.absolute():
        raise CompatibilityError('UNSAFE_BUNDLE_KIT')
    entries = {}
    for path in sorted(kit.rglob('*')):
        relative = path.relative_to(kit)
        if {'__pycache__', '.pytest_cache', '.DS_Store'}.intersection(relative.parts) or path.suffix == '.pyc':
            continue
        if relative.as_posix() == 'google-connection-support.json':
            continue
        if (path.name.startswith('.env') or path.name in {'auth.json', 'google_token.json', 'google-token.json', 'token.json', 'tokens.json', 'credentials.json'} or path.name.endswith('-token.json')):
            raise CompatibilityError('PRIVATE_FILE_IN_BUNDLE')
        mode = path.lstat().st_mode & 0o777
        if path.is_symlink():
            if not path.resolve(strict=True).is_relative_to(kit):
                raise CompatibilityError('UNSAFE_BUNDLE_LINK')
            entries[relative.as_posix()] = {'link': os.readlink(path)}
        elif path.is_file(): entries[relative.as_posix()] = file_identity(path)
        elif path.is_dir(): entries[relative.as_posix()] = {'directory': mode}
        else: raise CompatibilityError('INVALID_BUNDLE_FILE')
    return hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def bundle_declaration(kit):
    path = Path(kit) / 'google-connection-support.json'
    if not path.exists() and not path.is_symlink(): return None
    value = json_value(regular_bytes(path))
    if not isinstance(value, dict): raise CompatibilityError('INVALID_GOOGLE_SUPPORT')
    declaration = value.get('bundle')
    if declaration is None: return None
    if (not isinstance(declaration, dict) or type(declaration.get('version')) is not int
            or declaration['version'] != 1 or set(declaration) != {'version', 'kit_sha256', 'files', 'predecessor'}):
        raise CompatibilityError('INVALID_GOOGLE_BUNDLE')
    for row in (declaration, declaration['predecessor']):
        validate_bundle_identity(row)
    if any(item is None for item in declaration['files'].values()):
        raise CompatibilityError('INCOMPLETE_GOOGLE_BUNDLE')
    return declaration


def verify_bundle(root, declaration=None):
    root = Path(root).absolute()
    if root.resolve() != root: raise CompatibilityError('UNSAFE_BUNDLE_ROOT')
    kit = root / 'plugin-store/team-kit'
    # Explicit predecessor identity is captured from the approved bundle; its
    # transition-version compatibility is checked by the caller's pinned checker.
    # An unconverted predecessor may predate support declarations entirely.
    if declaration is None:
        validate_build(kit, 'team-kit')
        declaration = bundle_declaration(kit)
    if declaration is None: raise CompatibilityError('GOOGLE_BUNDLE_REQUIRED')
    validate_bundle_identity(declaration)
    if kit_identity(kit) != declaration['kit_sha256']:
        raise CompatibilityError('GOOGLE_BUNDLE_KIT_MISMATCH')
    for name, expected in declaration['files'].items():
        path = root / name
        if expected is None:
            if path.exists() or path.is_symlink(): raise CompatibilityError('GOOGLE_BUNDLE_FILE_MISMATCH')
        elif file_identity(path) != expected:
            raise CompatibilityError('GOOGLE_BUNDLE_FILE_MISMATCH')
    return declaration


def check_component(home, target, component):
    """Version check used by a full transaction's already pinned prior snapshot."""
    version = transition_version(home)
    target = Path(target).resolve(strict=True)
    if not target.is_dir():
        raise CompatibilityError('INVALID_DEPLOY_TARGET')
    if version is not None and version not in validate_build(target, component):
        raise CompatibilityError('UNSUPPORTED_GOOGLE_VERSION')


def check_target(home, target, component, *, bundle=False, kit_only=False):
    if bundle:
        if component != 'team-kit': raise CompatibilityError('INVALID_BUNDLE_COMPONENT')
        verify_bundle(target)
        target = Path(target) / 'plugin-store/team-kit'
    elif component == 'team-kit':
        # Enforce this even for older callers that do not know --kit-only.
        # No legacy executable may replace half of an installed bundle.
        for kit in (Path(target), Path(home) / 'plugin-store/team-kit'):
            if bundle_declaration(kit) is not None: raise CompatibilityError('GOOGLE_BUNDLE_REQUIRED')
    elif kit_only:
        raise CompatibilityError('INVALID_BUNDLE_COMPONENT')
    check_component(home, target, component)


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


def hejo_identity(root):
    """Identity of released facilities, excluding the separately delivered app."""
    root = Path(root).absolute()
    if root.resolve(strict=True) != root:
        raise CompatibilityError('UNSAFE_LEGACY_RELEASE')
    names = {'gate', 'hub', 'schemas', 'config', 'install', 'LICENSE', 'RELEASE', 'hejo.app'}
    if any(p.name not in names for p in root.iterdir()):
        raise CompatibilityError('UNKNOWN_LEGACY_RELEASE_FILE')
    entries = {}
    for name in ('gate', 'hub', 'schemas', 'config', 'install', 'LICENSE', 'RELEASE'):
        top = root / name
        if not top.exists() or top.is_symlink():
            raise CompatibilityError('INCOMPLETE_LEGACY_RELEASE')
        paths = [top, *sorted(top.rglob('*'))] if top.is_dir() else [top]
        for path in paths:
            relative = path.relative_to(root)
            if ({'__pycache__', '.pytest_cache', '.DS_Store'}.intersection(relative.parts)
                    or path.suffix == '.pyc' or relative.parts[:2] == ('gate', 'tests')):
                continue
            if (path.name.startswith('.env') or path.name in {'auth.json', 'google_token.json', 'credentials.json', 'token.json', 'tokens.json'}
                    or 'secret' in path.name.lower() or path.name.endswith('-token.json')):
                raise CompatibilityError('PRIVATE_FILE_IN_RELEASE')
            if path.is_symlink():
                if not path.resolve(strict=True).is_relative_to(root):
                    raise CompatibilityError('UNSAFE_LEGACY_RELEASE_LINK')
                entries[relative.as_posix()] = {'link': os.readlink(path)}
            elif path.is_dir():
                entries[relative.as_posix()] = {'directory': path.stat().st_mode & 0o777}
            else:
                entries[relative.as_posix()] = file_identity(path)
    return hashlib.sha256(json.dumps(entries, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def legacy_stopped(home, release):
    """Observe stop conditions only; never stop or signal a process here."""
    for profile in profile_homes(home):
        for folder in (profile, profile / 'hejo', profile / 'plugins'):
            if folder.is_symlink() or (folder.exists() and not folder.is_dir()):
                raise CompatibilityError('UNSAFE_LEGACY_STATE_PARENT')
            if folder.exists() and any(folder.glob('.hejo-install-*')) or folder.exists() and any(folder.glob('.hejo-link-*')):
                raise CompatibilityError('PENDING_FACILITY_DEPLOYMENT')
        path = profile / 'gateway_state.json'
        if path.exists() or path.is_symlink():
            value = json_value(regular_bytes(path))
            if not isinstance(value, dict):
                raise CompatibilityError('INVALID_GATEWAY_STATE')
            pid = value.get('pid')
            if pid is not None:
                if type(pid) is not int or pid <= 0:
                    raise CompatibilityError('INVALID_GATEWAY_STATE')
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    raise CompatibilityError('GATEWAY_MUST_BE_STOPPED')
    store = home / 'plugin-store'
    if store.is_symlink() or (store.exists() and any(store.glob('.team-kit-deploy-*'))):
        raise CompatibilityError('PENDING_FACILITY_DEPLOYMENT')
    result = subprocess.run(['ps', '-axo', 'pid=,command='], capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise CompatibilityError('WORKER_STATE_UNKNOWN')
    workers = {'google_connection_auth.py', 'hermes_facility.google_connection_auth',
               'google_reauth.py', 'google_api.py', 'mail_waiting_worker.py', 'document_review_worker.py', 'doc_worker.py',
               'hermes-wait-jobs', 'hermes-personal-review', 'hermes-morning-report'}
    for line in result.stdout.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2 or not fields[0].isdigit():
            raise CompatibilityError('WORKER_STATE_UNKNOWN')
        if int(fields[0]) == os.getpid():
            continue
        try:
            words = shlex.split(fields[1])
        except ValueError:
            raise CompatibilityError('WORKER_STATE_UNKNOWN') from None
        if any(Path(word).name in workers or word.startswith(str(release) + '/gate/')
               or word.startswith(str(home / 'bin') + '/')
               or word.startswith(str(home / 'plugin-store/team-kit') + '/') for word in words):
            raise CompatibilityError('AFFECTED_WORKER_MUST_BE_STOPPED')


class LegacyUpgrade:
    """Explicit first-checker admission, pinned to the package's reviewed Git baselines."""
    def __init__(self, home, package):
        self.home = Path(home).resolve(strict=True)
        self.package = Path(package).resolve(strict=True)
        validate_build(self.package, 'hejo')
        self.support = json_value(regular_bytes(self.package / 'install/google-connection-support.json'))
        legacy = self.support.get('legacy')
        if (not isinstance(legacy, dict) or set(legacy) != {'version', 'hejo', 'team'}
                or type(legacy['version']) is not int or legacy['version'] != 1):
            raise CompatibilityError('LEGACY_SUPPORT_REQUIRED')
        for component in ('hejo', 'team'):
            row = legacy[component]
            if not isinstance(row, dict) or not re.fullmatch('[0-9a-f]{40}', str(row.get('commit', ''))):
                raise CompatibilityError('INVALID_LEGACY_SUPPORT')
        if not re.fullmatch('[0-9a-f]{64}', str(legacy['hejo'].get('sha256', ''))):
            raise CompatibilityError('INVALID_LEGACY_SUPPORT')
        if (set(legacy['hejo']) != {'commit', 'sha256'}
                or set(legacy['team']) != {'commit', 'kit_sha256', 'files'}):
            raise CompatibilityError('INVALID_LEGACY_SUPPORT')
        validate_bundle_identity(legacy['team'])
        self.legacy = legacy
        self.receipt_path = self.home / 'hejo/install-receipt.json'
        self.receipt = regular_bytes(self.receipt_path)
        self.receipt_mode = self.receipt_path.stat().st_mode & 0o777
        if self.receipt_mode != 0o600:
            raise CompatibilityError('INVALID_LEGACY_RECEIPT_MODE')
        value = json_value(self.receipt)
        if (not isinstance(value, dict) or type(value.get('version')) is not int
                or value['version'] not in (1, 2) or value.get('status') != 'installed'
                or not isinstance(value.get('targets'), list) or 'legacy_upgrade' in value):
            raise CompatibilityError('INVALID_LEGACY_RECEIPT')
        self.links = {}
        for row in value['targets']:
            if not isinstance(row, dict):
                raise CompatibilityError('INVALID_LEGACY_RECEIPT')
            if row.get('kind') != 'link':
                continue
            relative = row.get('path')
            if (not isinstance(relative, str)
                    or not re.fullmatch(r'(?:profiles/[A-Za-z0-9][A-Za-z0-9_-]*/)?plugins/hejo', relative)
                    or relative in self.links or row.get('state') != 'applied'
                    or not isinstance(row.get('after'), str)):
                raise CompatibilityError('INVALID_LEGACY_RECEIPT')
            self.links[relative] = row['after']
        if 'plugins/hejo' not in self.links:
            raise CompatibilityError('INVALID_LEGACY_RECEIPT')
        root_link = self.home / 'plugins/hejo'
        if not root_link.is_symlink() or root_link.parent.resolve() != root_link.parent:
            raise CompatibilityError('INVALID_LEGACY_LINK')
        self.release = root_link.resolve(strict=True).parent
        if any((self.home / relative).resolve(strict=True) != self.release / 'gate'
               for relative in self.links):
            raise CompatibilityError('MIXED_LEGACY_RELEASES')
        checker = self.release / 'install/check_google_compat.py'
        if checker.exists() or checker.is_symlink():
            raise CompatibilityError('LEGACY_CHECKER_ALREADY_PRESENT')
        self.homes = self.home_set()
        self.candidate = hejo_identity(self.package)
        self.google_inputs = None
        self.google_checked_at = None
        self.revalidate(self.links, self.receipt)

    def home_set(self):
        profiles = self.home / 'profiles'
        if profiles.is_symlink():
            raise CompatibilityError('INVALID_LEGACY_PROFILE_SET')
        if profiles.exists() and any(not p.is_dir() or p.is_symlink() for p in profiles.iterdir()):
            raise CompatibilityError('INVALID_LEGACY_PROFILE_SET')
        return {str(p): (p.stat().st_dev, p.stat().st_ino, p.stat().st_mode & 0o777)
                for p in profile_homes(self.home)}

    def revalidate(self, links, receipt):
        if self.home_set() != self.homes or regular_bytes(self.receipt_path) != receipt:
            raise CompatibilityError('LEGACY_INPUT_CHANGED')
        if self.receipt_path.stat().st_mode & 0o777 != self.receipt_mode:
            raise CompatibilityError('LEGACY_INPUT_CHANGED')
        if hejo_identity(self.package) != self.candidate:
            raise CompatibilityError('LEGACY_CANDIDATE_CHANGED')
        # Released/checked-out facility roots use the same fixed 0755 mode as
        # the Git packaging producer; owner home permissions are unrelated.
        if any(path.stat().st_mode & 0o777 != 0o755 for path in (
                self.package, self.release, self.home / 'plugin-store/team-kit')):
            raise CompatibilityError('LEGACY_FACILITY_MODE_CHANGED')
        if hejo_identity(self.release) != self.legacy['hejo']['sha256']:
            raise CompatibilityError('LEGACY_CODE_MISMATCH')
        if regular_bytes(self.release / 'RELEASE').decode().strip() != self.legacy['hejo']['commit']:
            raise CompatibilityError('LEGACY_RELEASE_MISMATCH')
        if (self.release / 'install/check_google_compat.py').exists():
            raise CompatibilityError('LEGACY_CHECKER_ALREADY_PRESENT')
        verify_bundle(self.home, self.legacy['team'])
        inputs = self.google_state()
        if self.google_inputs is None:
            self.google_inputs = inputs
        elif inputs != self.google_inputs:
            raise CompatibilityError('LEGACY_GOOGLE_INPUT_CHANGED')
        legacy_stopped(self.home, self.release)
        for profile in profile_homes(self.home):
            path = profile / 'plugins/hejo'
            relative = path.relative_to(self.home).as_posix()
            if relative not in links:
                if path.exists() or path.is_symlink():
                    raise CompatibilityError('UNRECORDED_LEGACY_LINK')
                continue
            if (path.parent.resolve() != path.parent or not path.is_symlink()
                    or os.readlink(path) != links[relative]
                    or path.resolve(strict=True).name != 'gate'):
                raise CompatibilityError('LEGACY_LINK_CHANGED')
        for relative, target in links.items():
            path = self.home / relative
            if (not path.is_symlink() or path.parent.resolve() != path.parent
                    or os.readlink(path) != target):
                raise CompatibilityError('LEGACY_LINK_CHANGED')

    def google_state(self):
        # Only the verified legacy admission path interprets its old producer.
        # Store fingerprints/metadata, never the old undo/config bodies.
        now = time.time()
        if (type(now) not in (int, float) or not math.isfinite(now) or now <= 0
                or self.google_checked_at is not None and now < self.google_checked_at):
            raise CompatibilityError('LEGACY_GOOGLE_CLOCK_CHANGED')
        inputs = {}
        for profile, journal, value, stamp in google_journals(self.home):
            inputs[str(journal)] = stamp
            if value is None:
                continue
            if value.get('phase') != 'applied':
                inactive_google_job(value)
                continue
            allowed = {'at', 'action', 'phase', 'done', 'restart_required'}
            if (set(value) not in (allowed, allowed | {'undo'})
                    or value.get('action') != 'disconnect'
                    or value.get('done') != [] or value.get('restart_required') is not True):
                raise CompatibilityError('INVALID_LEGACY_GOOGLE_JOURNAL')
            at = value.get('at')
            if (type(at) not in (int, float) or at <= 0 or at > now
                    or not math.isfinite(at) or now - at < 600):
                raise CompatibilityError('LEGACY_GOOGLE_UNDO_NOT_EXPIRED')
            config = profile / 'config.yaml'
            raw, config_state = stable_file(config)
            if config_state is None:
                raise CompatibilityError('INVALID_LEGACY_GOOGLE_CONFIG')
            try:
                # The existing CONFIG reader accepts flow YAML as well as JSON,
                # defines YAML 1.1 and rejects duplicate keys.
                from hermes_yaml import safe_load
                document = safe_load(raw)
                enabled = document['plugins']['entries']['team-delegation']['settings']['gmail']['enabled']
                disabled = document['skills']['disabled']
                if (enabled is not False or not isinstance(disabled, list)
                        or any(not isinstance(v, str) for v in disabled)
                        or 'google-workspace' not in disabled):
                    raise ValueError
            except Exception:
                raise CompatibilityError('INVALID_LEGACY_GOOGLE_CONFIG') from None
            if 'undo' in value:
                undo = value['undo']
                relative = config.relative_to(self.home).as_posix()
                if (not isinstance(undo, dict) or set(undo) != {'before', 'after'}
                        or not isinstance(undo['before'], dict) or set(undo['before']) != {relative}
                        or not isinstance(undo['before'][relative], str)
                        or not re.fullmatch(r'(?:[0-9a-f]{2})*', undo['before'][relative])
                        or not isinstance(undo['after'], dict) or set(undo['after']) != {relative}
                        or undo['after'][relative] != hashlib.sha256(raw).hexdigest()):
                    raise CompatibilityError('LEGACY_GOOGLE_CONFIG_CONFLICT')
                # before is opaque: no hex decoding, output, restoration or copy.
            if (stable_fingerprint(config) != config_state
                    or stable_fingerprint(journal) != inputs[str(journal)]):
                raise CompatibilityError('LEGACY_GOOGLE_INPUT_CHANGED')
            inputs[str(config)] = config_state
        self.google_checked_at = now
        return inputs


def stable_file(path):
    path = Path(path)
    if path.resolve() != path:
        raise CompatibilityError('UNSAFE_COMPAT_FILE')
    if not path.exists() and not path.is_symlink():
        return None, None
    before = path.lstat()
    raw = regular_bytes(path)
    after = path.lstat()
    def metadata(info):
        return (info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns)
    if metadata(before) != metadata(after):
        raise CompatibilityError('LEGACY_GOOGLE_INPUT_CHANGED')
    return raw, (metadata(after), hashlib.sha256(raw).hexdigest())


def stable_fingerprint(path):
    return stable_file(path)[1]


def google_journals(home):
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
        raw, stamp = stable_file(journal)
        value = json_value(raw) if raw is not None else None
        if value is not None and not isinstance(value, dict):
            raise CompatibilityError('GOOGLE_AUTH_REMAINS')
        # JSON null is an existing ambiguous journal, never an absent journal.
        if stamp is not None and value is None:
            raise CompatibilityError('GOOGLE_AUTH_REMAINS')
        yield profile, journal, value, stamp


def inactive_google_job(value):
    if value.get('phase') not in ('disconnected', 'cancelled', 'failed'):
        raise CompatibilityError('GOOGLE_AUTH_REMAINS')
    if value.get('worker_pid'):
        try:
            os.kill(int(value['worker_pid']), 0)
        except ProcessLookupError:
            pass
        else:
            raise CompatibilityError('GOOGLE_AUTH_REMAINS')


def no_google_residue(home):
    for profile, journal, value, stamp in google_journals(home):
        if value is not None:
            inactive_google_job(value)


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
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--bundle', action='store_true')
    mode.add_argument('--kit-only', action='store_true')
    args = parser.parse_args(argv)
    try:
        if args.validate_build:
            target = args.target
            if args.bundle:
                if args.component != 'team-kit': raise CompatibilityError('INVALID_BUNDLE_COMPONENT')
                verify_bundle(target)
                target = target / 'plugin-store/team-kit'
            if 1 not in validate_build(target, args.component):
                raise CompatibilityError('UNSUPPORTED_GOOGLE_VERSION')
        elif args.home is None:
            raise CompatibilityError('HOME_REQUIRED')
        else:
            check_target(args.home, args.target, args.component, bundle=args.bundle, kit_only=args.kit_only)
    except (OSError, ValueError, TypeError, KeyError, UnicodeError):
        print('GOOGLE_COMPAT_DENIED', file=sys.stderr)
        return 1
    print('GOOGLE_COMPAT_OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
