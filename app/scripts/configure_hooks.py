#!/usr/bin/env python3
"""Preview or connect hejo hooks. Existing configuration is never overwritten."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shlex
import stat
import tempfile


def config(provider: str, executable: Path) -> dict:
    events = ['UserPromptSubmit', 'PermissionRequest', 'PostToolUse', 'Stop', 'SessionEnd']
    events += ['Notification', 'StopFailure'] if provider == 'claude' else ['Interrupt']
    command = f'{shlex.quote(str(executable))} --hook {provider}'
    hooks = {}
    for event in events:
        group = {'hooks': [{'type': 'command', 'command': command, 'timeout': 2}]}
        if event == 'Notification':
            group['matcher'] = 'permission_prompt|idle_prompt'
        hooks[event] = [group]
    return {'hooks': hooks}


def write_atomic(path, data, mode=0o600):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def contents(path):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError('기존 설정 보존을 위해 중단: 심볼릭 링크')
    return path.read_bytes() if path.exists() else None


class HookSetup:
    def __init__(self, home, support, executable):
        self.home, self.support, self.executable = home, support, executable
        self.receipt = support / 'hooks-receipt.json'
        self.targets = [('codex', home / '.codex/hooks.json'), ('claude', home / '.claude/settings.json')]

    def inspect(self):
        rows = []
        for provider, path in self.targets:
            desired = config(provider, self.executable)
            before = contents(path)
            if before is not None:
                try:
                    same = json.loads(before) == desired
                except (ValueError, UnicodeError):
                    same = False
                if not same:
                    raise ValueError('기존 설정 보존을 위해 중단. 기존 내용과 추가 항목을 검토한 뒤 별도로 병합해야 합니다.')
            installed = before if before is not None else (json.dumps(desired, ensure_ascii=False, indent=2)+'\n').encode()
            rows.append((provider, path, before, installed))
        return rows

    @contextlib.contextmanager
    def locked(self):
        self.support.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.support.is_symlink() or self.receipt.is_symlink():
            raise ValueError('연결 기록 경로를 확인해 주세요.')
        with (self.support / 'hooks.lock').open('a+b') as lock:
            os.chmod(lock.name, 0o600)
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            yield

    def connect(self):
        with self.locked():
            if self.receipt.exists():
                receipt = json.loads(self.receipt.read_bytes())
                if receipt.get('phase') == 'connected':
                    self.inspect()
                    self.validate(receipt, installed_only=True)
                    return
                raise ValueError('남은 연결 기록을 연결 해제로 되돌린 뒤 다시 실행해 주세요.')
            rows = self.inspect()  # Check every target before any configuration changes.
            backup = self.support / 'hooks-backup'
            backup.mkdir(mode=0o700, exist_ok=True)
            receipt = {'version': 1, 'phase': 'connecting', 'targets': []}
            for provider, path, before, installed in rows:
                mode = stat.S_IMODE(path.stat().st_mode) if before is not None else 0o600
                if before is not None:
                    write_atomic(backup / provider, before, mode=0o600)
                receipt['targets'].append({'provider': provider, 'existed': before is not None,
                                           'mode': mode, 'before': sha(before) if before is not None else None,
                                           'installed': sha(installed)})
            write_atomic(self.receipt, json.dumps(receipt, sort_keys=True).encode())
            try:
                for _, path, before, installed in rows:
                    if contents(path) != before:
                        raise ValueError('설정이 바뀌어 연결을 멈췄어요.')
                    if before is None:
                        # Exclusive creation preserves a configuration created concurrently.
                        path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                        fd, temporary = tempfile.mkstemp(prefix='.hejo-hook-', dir=path.parent)
                        try:
                            with os.fdopen(fd, 'wb') as handle:
                                os.fchmod(handle.fileno(), 0o600)
                                handle.write(installed); handle.flush(); os.fsync(handle.fileno())
                            os.link(temporary, path)  # Publish complete bytes without clobbering a new file.
                        finally:
                            os.unlink(temporary)
                receipt['phase'] = 'connected'
                write_atomic(self.receipt, json.dumps(receipt, sort_keys=True).encode())
            except Exception:
                self.restore(receipt)
                raise

    def validate(self, receipt, installed_only=False):
        if receipt.get('version') != 1 or len(receipt.get('targets', [])) != 2:
            raise ValueError('연결 기록을 확인해 주세요.')
        for row, (provider, path) in zip(receipt['targets'], self.targets):
            if row.get('provider') != provider:
                raise ValueError('연결 기록을 확인해 주세요.')
            current = contents(path)
            digest = sha(current) if current is not None else None
            allowed = [row['installed']] if installed_only else [row['installed'], row['before']]
            if digest not in allowed:
                raise ValueError('연결 뒤 설정이 바뀌었어요. 설정과 백업을 확인해 주세요.')
            if row['existed']:
                original = (self.support / 'hooks-backup' / provider).read_bytes()
                if sha(original) != row['before']:
                    raise ValueError('백업을 확인해 주세요.')

    def restore(self, receipt):
        self.validate(receipt)
        for row, (provider, path) in zip(receipt['targets'], self.targets):
            if row['existed']:
                write_atomic(path, (self.support / 'hooks-backup' / provider).read_bytes(), row['mode'])
            elif path.exists():
                path.unlink()
        self.receipt.unlink()  # Backups remain private; the next connection replaces them.

    def disconnect(self):
        with self.locked():
            if self.receipt.exists():
                self.restore(json.loads(self.receipt.read_bytes()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    parser.add_argument('--home', type=Path, default=Path.home())
    parser.add_argument('--support', type=Path)
    action = parser.add_mutually_exclusive_group()
    action.add_argument('--apply', action='store_true')
    action.add_argument('--disconnect', action='store_true')
    args = parser.parse_args()
    executable = args.app.resolve() / 'Contents/MacOS/hejo'
    if not executable.is_file():
        parser.error('앱 실행 파일을 확인해 주세요.')
    support = args.support or args.home / 'Library/Application Support/hejo'
    setup = HookSetup(args.home, support, executable)
    try:
        if args.disconnect:
            setup.disconnect()
        elif args.apply:
            setup.connect()
            print('Codex 공식 훅은 /hooks에서 신뢰 검토가 필요합니다. 기존 작업을 중단하거나 재시작하지 않습니다.')
        else:
            for provider, _ in setup.targets:
                print(json.dumps({'provider': provider, 'create_only': True, 'config': config(provider, executable)}, ensure_ascii=False, indent=2))
    except (OSError, ValueError, KeyError) as error:
        parser.error(str(error) if isinstance(error, ValueError) else '설정과 연결 기록을 확인해 주세요.')


if __name__ == '__main__':
    main()
