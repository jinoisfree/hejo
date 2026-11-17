"""Stamp a tree, never the private working history or developer paths."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def source_info():
    tree = subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=ROOT, text=True).strip()
    changed = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=all'], cwd=ROOT, text=True)
    return {'tree': tree, 'dirty': bool(changed.strip())}


if __name__ == '__main__':
    Path(sys.argv[1]).write_text(json.dumps(source_info(), sort_keys=True) + '\n')
