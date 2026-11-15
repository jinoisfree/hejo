"""AT-HF-29/41/42/43: tracked-text coverage, redaction, and exact owner read boundary."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


SCANNER = Path(__file__).resolve().parents[2] / "scripts" / "scan_private.py"


@pytest.fixture
def scan_airport(tmp_path):
    repo = tmp_path / "repo"
    home = tmp_path / "airport"
    repo.mkdir()
    (home / "owner").mkdir(parents=True)
    (home / "owner" / "team.yaml").write_text(json.dumps({"agents": {
        "alpha": {"name": "Alpha", "aliases": ["Test Captain"]}}}))
    (home / "owner" / "vault.yaml").write_text(json.dumps({"test": "Fixture-Only-Value"}))
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    return repo, home


def track(repo, name, data):
    path = repo / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if isinstance(data, bytes) else data.encode())
    subprocess.run(["git", "-C", str(repo), "add", "--", name], check=True)


def run_scan(repo, home):
    return subprocess.run([sys.executable, str(SCANNER), "--repo", str(repo), "--home", str(home)],
                          text=True, capture_output=True)


def test_at_hf_29_roster_value_is_reported_only_as_fingerprint(scan_airport):
    repo, home = scan_airport
    track(repo, "note.md", "Alpha\n")
    result = run_scan(repo, home)
    assert result.returncode == 1
    assert "Alpha" not in result.stdout + result.stderr
    assert result.stdout.strip().split("\t") == [
        "roster", "note.md", "1", hashlib.sha256(b"Alpha").hexdigest()]


def test_at_hf_41_only_two_owner_files_are_opened(scan_airport, tmp_path):
    repo, home = scan_airport
    track(repo, "note.md", "neutral text\n")
    for name in (".env", "auth.json", "state.db"):
        (home / name).write_text("must not open")
    audit = tmp_path / "audit.json"
    program = r'''
import json, os, pathlib, runpy, sys
from ruamel.yaml import YAML
root = pathlib.Path(os.environ["SCAN_AUDIT_HOME"]).resolve()
opened = []
def hook(event, args):
    if event != "open" or not isinstance(args[0], (str, bytes, os.PathLike)):
        return
    path = pathlib.Path(os.fsdecode(args[0])).resolve()
    if path.is_relative_to(root):
        relative = path.relative_to(root).as_posix()
        opened.append(relative)
        if relative not in {"owner/team.yaml", "owner/vault.yaml"}:
            raise AssertionError("unexpected owner read")
sys.addaudithook(hook)
sys.argv = [os.environ["SCAN_AUDIT_SCRIPT"], "--repo", os.environ["SCAN_AUDIT_REPO"], "--home", str(root)]
try:
    runpy.run_path(sys.argv[0], run_name="__main__")
finally:
    pathlib.Path(os.environ["SCAN_AUDIT_LOG"]).write_text(json.dumps(opened))
'''
    environment = {**os.environ, "HERMES_HOME": str(home), "SCAN_AUDIT_HOME": str(home),
                   "SCAN_AUDIT_SCRIPT": str(SCANNER), "SCAN_AUDIT_REPO": str(repo),
                   "SCAN_AUDIT_LOG": str(audit)}
    result = subprocess.run([sys.executable, "-c", program], env=environment, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert set(json.loads(audit.read_text())) == {"owner/team.yaml", "owner/vault.yaml"}


@pytest.mark.parametrize("name", ["install/fake-tool", "githooks/pre-commit", "notes.toml"])
def test_at_hf_42_all_tracked_text_kinds_are_scanned(scan_airport, name):
    repo, home = scan_airport
    value = "/".join(("", "Users", "someone", "x"))
    content = ("#!/bin/sh\n" if name != "notes.toml" else "") + value + "\n"
    track(repo, name, content)
    result = run_scan(repo, home)
    assert result.returncode == 1
    assert "absolute_path\t" + name in result.stdout
    assert value not in result.stdout + result.stderr


def test_at_hf_42_binary_is_named_but_never_printed(scan_airport):
    repo, home = scan_airport
    track(repo, "fixture.bin", b"\0Alpha\xff")
    result = run_scan(repo, home)
    assert result.returncode == 0
    assert result.stdout == "바이너리 생략\tfixture.bin\n"
    assert "Alpha" not in result.stdout + result.stderr


def test_at_hf_43_exemption_matches_only_original_notice_line(scan_airport):
    repo, home = scan_airport
    notice = "Copyright Alpha (test publisher)"
    track(repo, "LICENSE", notice + "\n")
    digest = hashlib.sha256(notice.encode()).hexdigest()
    track(repo, "scripts/scan_private_allow.txt", f"LICENSE\t{digest}\tlicense-notice\n")
    assert run_scan(repo, home).returncode == 0
    track(repo, "LICENSE", notice + "\nAlpha\n")
    result = run_scan(repo, home)
    assert result.returncode == 1 and "roster\tLICENSE\t2\t" in result.stdout
    assert "\tLICENSE\t1\t" not in result.stdout
    track(repo, "LICENSE", notice + " amended\n")
    result = run_scan(repo, home)
    assert result.returncode == 1 and "roster\tLICENSE\t1\t" in result.stdout
    assert "Alpha" not in result.stdout + result.stderr


def test_source_errors_do_not_print_values(scan_airport):
    repo, home = scan_airport
    (home / "owner" / "team.yaml").write_text("Alpha: [malformed")
    result = run_scan(repo, home)
    assert result.returncode == 2 and result.stdout.startswith("scan_error\t")
    assert "Alpha" not in result.stdout + result.stderr


def test_tracked_symlink_never_opens_home_target(scan_airport):
    repo, home = scan_airport
    outside = home / "state.db"
    outside.write_text("Alpha")
    (repo / "alias").symlink_to(outside)
    subprocess.run(["git", "-C", str(repo), "add", "alias"], check=True)
    result = run_scan(repo, home)
    assert result.returncode == 0
    assert "Alpha" not in result.stdout + result.stderr
