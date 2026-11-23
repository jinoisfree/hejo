"""Compare download metadata without reading contents or following symlinks."""
import json
import sys
from pathlib import Path

def snapshot(root):
    result = {}
    def visit(path):
        try:
            s = path.lstat()
        except FileNotFoundError:
            result[str(path.relative_to(root))] = None
            return
        result[str(path.relative_to(root))] = [s.st_dev, s.st_ino, s.st_mode, s.st_size, s.st_mtime_ns, s.st_ctime_ns]
        if path.is_dir() and not path.is_symlink():
            for child in sorted(path.iterdir()):
                visit(child)
    visit(root)
    return result

if __name__ == '__main__':
    state = Path(sys.argv[2])
    current = snapshot(Path.home() / 'Downloads')
    if sys.argv[1] == 'snapshot':
        state.write_text(json.dumps(current))
    else:
        assert current == json.loads(state.read_text()), 'Actual Downloads metadata changed'
        print('ACTUAL_DOWNLOADS_METADATA_UNCHANGED · contents not opened')
