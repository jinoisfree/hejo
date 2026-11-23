"""Protect real CLI and app settings without opening their contents: lstat metadata only."""
import json
from pathlib import Path
import sys
from downloads_guard import snapshot as tree_snapshot


def snapshot():
    home = Path.home()
    result = {}
    for directory in ['.codex', '.claude']:
        root = home / directory
        names = set(['config.toml', 'hooks.json'] if directory == '.codex' else ['settings.json', 'settings.local.json'])
        for name in sorted(names):
            try:
                s = (root / name).lstat()
                result[directory+'/'+name] = [s.st_dev, s.st_ino, s.st_mode, s.st_size, s.st_mtime_ns, s.st_ctime_ns]
            except FileNotFoundError:
                result[directory+'/'+name] = None
    result["hejo"] = tree_snapshot(home / "Library" / "Application Support" / "hejo")
    result["app-tests-preferences"] = tree_snapshot(home / "Library" / "Preferences" / "app-tests.plist")
    return result


if __name__ == '__main__':
    mode, path = sys.argv[1:]
    if mode == 'snapshot':
        Path(path).write_text(json.dumps(snapshot(), sort_keys=True))
    else:
        assert json.loads(Path(path).read_text()) == snapshot(), 'Real settings metadata changed'
        print('ACTUAL_SETTINGS_METADATA_UNCHANGED · contents not opened')
