"""Compare directory entry names only. Never read or print the user's files."""
import json
import sys
from pathlib import Path
folder = Path.home() / 'Downloads'
state = Path(sys.argv[2])
names = sorted(p.name for p in folder.iterdir()) if folder.exists() else []
if sys.argv[1] == 'snapshot':
    state.write_text(json.dumps(names))
else:
    assert names == json.loads(state.read_text()), 'Actual Downloads entry names changed during app tests'
    print('ACTUAL_DOWNLOADS_NAMES_UNCHANGED')
