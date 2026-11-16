"""AT82 read-only profile mode and optional roster capability."""
import json
import sys
import types
from pathlib import Path

from jsonschema import Draft202012Validator
from gate import roster


def test_at_hf_82_queued_roster_read_only(tmp_path, monkeypatch):
    homes = [(name, tmp_path / name) for name in ("alpha", "beta", "gamma")]
    texts = ["display:\n  busy_input_mode: 'queue' # chosen\n", "display:\n  busy_input_mode: steer\n", "other:\n  busy_input_mode: queue\n"]
    before = {}
    for (_, home), text in zip(homes, texts):
        home.mkdir()
        path = home / "config.yaml"
        path.write_text(text)
        before[path] = (path.read_bytes(), path.stat().st_mtime_ns)
    monkeypatch.setattr(roster, "profiles_to_serve", lambda multiplex: homes)
    registry = types.ModuleType("hermes_facility.team_registry")
    registry.roster = lambda: {}
    monkeypatch.setitem(sys.modules, "hermes_facility", types.ModuleType("hermes_facility"))
    monkeypatch.setitem(sys.modules, "hermes_facility.team_registry", registry)
    rows = roster.employees()
    assert [item["queued"] for item in rows] == [True, False, False]
    assert before == {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in before}
    schema = json.loads((Path(__file__).resolve().parents[2] / "schemas/hejo-wire-v1.json").read_text())
    validator = Draft202012Validator(schema)
    validator.validate({"v": 1, "type": "roster", "ref": "test", "employees": rows})
    for item in rows:
        item.pop("queued")
    validator.validate({"v": 1, "type": "roster", "ref": "test", "employees": rows})
    (homes[0][1] / "config.yaml").unlink()
    assert roster.profile_queued(homes[0][1]) is False
    (homes[0][1] / "config.yaml").write_bytes(b"\xff")
    assert roster.profile_queued(homes[0][1]) is False
    (homes[0][1] / "config.yaml").write_text("display:\n  busy_input_mode: ' queue '\n")
    assert roster.profile_queued(homes[0][1]) is True
