"""AT-HF-27/28/38/39/40: reversible installation in an isolated primary/profile home."""
from copy import deepcopy
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys

import re

import pytest
from ruamel.yaml import YAML


INSTALLER = Path(__file__).resolve().parents[2] / "install" / "hejo-install"
PROFILES = ("", "profiles/beta")
ORIGINAL = """# Owner configuration
plugins:
  enabled: [x, y] # Keep plugins
gateway:
  platforms:
    hejo: {enabled: false, extra: {port: 1}} # Keep door comment
other: unchanged
"""


@pytest.fixture
def install_airport(tmp_path, monkeypatch):
    home = tmp_path / "airport"
    home.mkdir()
    monkeypatch.setenv("HERMES_HOME", str(home))
    from hermes_cli.profiles import create_profile
    create_profile("beta", no_alias=True, no_skills=True)
    (home / "profiles/beta/config.yaml").write_text("{}\n")
    return home


@pytest.fixture
def installer():
    namespace = runpy.run_path(str(INSTALLER), run_name="install_test")
    return namespace["run"].__globals__


def cli(home, *args):
    environment = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
    return subprocess.run([sys.executable, str(INSTALLER), "--home", str(home), *args],
                          env=environment, capture_output=True, text=True)


def receipt(home):
    return json.loads((home / "hejo/install-receipt.json").read_text())


def managed(home):
    result = {}
    for profile in PROFILES:
        root = home / profile
        for relative in ("config.yaml", "plugins/hejo"):
            path = root / relative
            key = path.relative_to(home).as_posix()
            if path.is_symlink():
                result[key] = ("link", os.readlink(path), path.lstat().st_mtime_ns)
            elif path.exists():
                result[key] = ("file", path.read_bytes(), path.stat().st_mtime_ns)
            else:
                result[key] = None
    for relative in ("hejo/devices.json", "hejo/install-receipt.json"):
        path = home / relative
        result[relative] = (path.read_bytes(), path.stat().st_mtime_ns) if path.exists() else None
    return result


def seed_existing(home):
    for profile in PROFILES:
        root = home / profile
        (root / "config.yaml").write_text(ORIGINAL)
        (root / "plugins").mkdir(exist_ok=True)
        (root / "plugins/hejo").symlink_to("../previous-gate")


def test_at_hf_27_install_twice_and_check(install_airport):
    home = install_airport
    assert cli(home).returncode == 0
    first = managed(home)
    for profile in PROFILES:
        root = home / profile
        assert (root / "plugins/hejo").resolve() == INSTALLER.parents[1] / "gate"
        config = YAML().load((root / "config.yaml").read_text())
        assert config["plugins"]["enabled"] == ["hejo"]
        block = config["gateway"]["platforms"]["hejo"]
        if profile:
            assert block == {"enabled": True, "extra": {"role": "forwarder"}}
        else:
            # Port and Tailscale address depend on the machine: first free port, loopback first.
            extra = dict(block["extra"])
            assert 47820 <= extra.pop("port") < 47830 and extra.pop("listen")[0] == "127.0.0.1"
            assert block["enabled"] is True and extra == {"allowed_users": ["owner"]}
    assert stat.S_IMODE((home / "hejo").stat().st_mode) == 0o700
    assert stat.S_IMODE((home / "hejo/devices.json").stat().st_mode) == 0o600
    assert stat.S_IMODE((home / "hejo/install-receipt.json").stat().st_mode) == 0o600
    data = receipt(home)
    assert data["status"] == "installed" and data["bootstrap"] == {"path": "hejo", "existed": False}
    assert all(target["state"] == "applied" for target in data["targets"])
    assert cli(home).returncode == 0
    assert managed(home) == first  # Includes mtimes: no rewritten receipt/config/link/device.
    assert cli(home, "--check").returncode == 0


def test_at_hf_28_uninstall_restores_both_profiles_including_comments(install_airport):
    home = install_airport
    seed_existing(home)
    shared = home / "shared/hejo"
    shared.mkdir(parents=True)
    (shared / "kept.txt").write_text("retained data")
    assert cli(home).returncode == 0
    assert cli(home, "--uninstall").returncode == 0
    for profile in PROFILES:
        root = home / profile
        assert (root / "config.yaml").read_text() == ORIGINAL
        assert os.readlink(root / "plugins/hejo") == "../previous-gate"
    assert (home / "hejo/devices.json").is_file()
    assert (shared / "kept.txt").read_text() == "retained data"
    assert receipt(home)["status"] == "uninstalled"


def test_at_hf_38_owner_port_change_is_preserved_and_force_is_explicit(install_airport):
    home = install_airport
    seed_existing(home)
    assert cli(home).returncode == 0
    config_path = home / "config.yaml"
    yaml = YAML()
    document = yaml.load(config_path.read_text())
    document["gateway"]["platforms"]["hejo"]["extra"]["port"] = 47999
    with config_path.open("w") as stream:
        yaml.dump(document, stream)
    result = cli(home, "--uninstall")
    assert result.returncode == 2
    assert "config.yaml#gateway.platforms.hejo" in result.stdout
    document = yaml.load(config_path.read_text())
    assert document["gateway"]["platforms"]["hejo"]["extra"]["port"] == 47999
    assert document["plugins"]["enabled"] == ["x", "y"]
    assert os.readlink(home / "plugins/hejo") == "../previous-gate"
    assert (home / "profiles/beta/config.yaml").read_text() == ORIGINAL
    assert receipt(home)["status"] == "uninstalled"
    assert cli(home, "--uninstall", "--force").returncode == 0
    assert yaml.load(config_path.read_text())["gateway"]["platforms"]["hejo"] == {
        "enabled": False, "extra": {"port": 1}}


@pytest.mark.parametrize("existing", [False, True])
@pytest.mark.parametrize("fail_at", [1, 4])
def test_at_hf_39_config_write_failure_rolls_back_after_link(install_airport, installer, monkeypatch, existing, fail_at):
    home = install_airport
    if existing:
        seed_existing(home)
    originals = {profile: ((home / profile / "config.yaml").read_bytes()
                          if (home / profile / "config.yaml").exists() else None) for profile in PROFILES}
    events = []
    original_save = installer["save_receipt"]
    original_write = installer["write_config"]
    writes = 0
    def save(root, data):
        if not events:
            assert not (home / "hejo/devices.json").exists()
            for profile in PROFILES:
                config = home / profile / "config.yaml"
                assert (config.read_bytes() if config.exists() else None) == originals[profile]
                link = home / profile / "plugins/hejo"
                assert (os.readlink(link) if link.is_symlink() else None) == ("../previous-gate" if existing else None)
        original_save(root, data)
        events.append(deepcopy(data))
    def fail_once(path, document, mode):
        nonlocal writes
        writes += 1
        if writes != fail_at:
            return original_write(path, document, mode)
        assert (home / "plugins/hejo").is_symlink()
        on_disk = receipt(home)
        assert any(item["kind"] == "link" and item["state"] == "applied" for item in on_disk["targets"])
        monkeypatch.setitem(installer, "write_config", original_write)
        raise OSError("injected config write failure")
    monkeypatch.setitem(installer, "save_receipt", save)
    monkeypatch.setitem(installer, "write_config", fail_once)
    assert installer["main"](["--home", str(home)]) == 1
    assert events[0]["status"] == "installing"
    assert all(item["state"] == "pending" for item in events[0]["targets"])
    assert events[-1]["status"] == "failed"
    assert all(item["state"] == "pending" for item in events[-1]["targets"])
    for profile in PROFILES:
        root = home / profile
        path = root / "config.yaml"
        assert (path.read_bytes() if path.exists() else None) == originals[profile]
        if existing:
            assert os.readlink(root / "plugins/hejo") == "../previous-gate"
        else:
            assert not (root / "plugins").exists()
    assert {path.name for path in (home / "hejo").iterdir()} == {"install-receipt.json"}
    assert receipt(home)["status"] == "failed"


def test_at_hf_40_reinstall_preserves_before_and_owner_edit_under_open_audit(install_airport, tmp_path):
    home = install_airport
    for name in (".env", "auth.json", "access-token", "client-secret"):
        (home / name).write_text("test sentinel")
    audit = tmp_path / "install-audit.json"
    program = r'''
# Warm the standard-library lexer before the audit: its module name is not a credential.
import json, os, pathlib, runpy, sys, tokenize
from ruamel.yaml import YAML
home = pathlib.Path(sys.argv[2])
opened = []
def guard(event, args):
    if event != "open" or not isinstance(args[0], (str, bytes, os.PathLike)):
        return
    path = pathlib.Path(os.fsdecode(args[0])).resolve()
    opened.append(str(path))
    name = path.name.lower()
    if name.startswith(".env") or name == "auth.json" or "token" in name or "secret" in name:
        raise AssertionError("forbidden file open")
sys.addaudithook(guard)
api = runpy.run_path(sys.argv[1], run_name="audited_install")
assert api["main"](["--home", str(home)]) == 0
receipt_path = home / "hejo/install-receipt.json"
before = json.loads(receipt_path.read_text())
config = home / "config.yaml"
yaml = YAML()
value = yaml.load(config.read_text())
value["plugins"]["enabled"].append("z")
with config.open("w") as stream:
    yaml.dump(value, stream)
changed = config.read_bytes()
assert api["main"](["--home", str(home)]) == 0
assert config.read_bytes() == changed
assert yaml.load(config.read_text())["plugins"]["enabled"] == ["hejo", "z"]
assert json.loads(receipt_path.read_text()) == before
pathlib.Path(sys.argv[3]).write_text(json.dumps(opened))
'''
    result = subprocess.run([sys.executable, "-c", program, str(INSTALLER), str(home), str(audit)],
                            capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "preserved_owner_change config.yaml#plugins.enabled" in result.stdout
    opened = json.loads(audit.read_text())
    assert opened
    assert not any(Path(path).name.lower().startswith(".env") or Path(path).name == "auth.json"
                   or "token" in Path(path).name.lower() or "secret" in Path(path).name.lower() for path in opened)


def test_check_missing_installation_is_read_only(install_airport):
    assert cli(install_airport, "--check").returncode == 1
    assert not (install_airport / "hejo").exists()
    assert not (install_airport / "plugins").exists()


def test_existing_device_data_survives_failure_and_uninstall(install_airport, installer, monkeypatch):
    home = install_airport
    (home / "hejo").mkdir(mode=0o700)
    devices = home / "hejo/devices.json"
    devices.write_text('{"test-device": {"revoked": true}}\n')
    original = devices.read_bytes()
    os.chmod(devices, 0o640)
    original_write = installer["write_config"]
    def fail(path, document, mode):
        raise OSError("injected write failure")
    monkeypatch.setitem(installer, "write_config", fail)
    assert installer["main"](["--home", str(home)]) == 1
    assert devices.read_bytes() == original and devices.stat().st_mode & 0o777 == 0o640
    monkeypatch.setitem(installer, "write_config", original_write)
    assert cli(home).returncode == 0
    assert cli(home, "--uninstall").returncode == 0
    assert devices.read_bytes() == original


def test_changed_config_parent_does_not_block_other_restorations(install_airport):
    home = install_airport
    seed_existing(home)
    assert cli(home).returncode == 0
    path = home / "config.yaml"
    yaml = YAML()
    document = yaml.load(path.read_text())
    document["gateway"]["platforms"] = "owner replacement"
    with path.open("w") as stream:
        yaml.dump(document, stream)
    result = cli(home, "--uninstall")
    assert result.returncode == 2
    document = yaml.load(path.read_text())
    assert document["gateway"]["platforms"] == "owner replacement"
    assert document["plugins"]["enabled"] == ["x", "y"]
    assert os.readlink(home / "plugins/hejo") == "../previous-gate"


def test_config_symlink_is_rejected_without_opening_target(install_airport, tmp_path):
    home = install_airport
    outside = tmp_path / "kept.yaml"
    outside.write_text("do not change\n")
    (home / "config.yaml").symlink_to(outside)
    assert cli(home).returncode == 1
    assert outside.read_text() == "do not change\n"
    assert not (home / "hejo").exists()


DRIFTING = """model:
    default: test-model
display:
  memory_notifications: "off"
plugins:
  enabled:
    - x
    - z
  entries:
    x:
      settings:
        lists:
          - a
          - b
gateway:
  log_level: info

# Section comment kept with the next key
other: {inline: true}
"""


def test_operating_formatting_is_edited_line_by_line_and_restored(install_airport):
    """A config ruamel cannot reproduce byte for byte gets only hejo lines added; uninstall restores the bytes."""
    home = install_airport
    for profile in PROFILES:
        (home / profile / "config.yaml").write_text(DRIFTING)
    assert cli(home).returncode == 0
    for profile in PROFILES:
        text = (home / profile / "config.yaml").read_text()
        removed = [line for line in DRIFTING.splitlines() if line not in text.splitlines()]
        assert removed == []
        added = [line for line in text.splitlines() if line not in DRIFTING.splitlines()]
        assert "    - hejo" in added and "  platforms:" in added and "    hejo:" in added
        assert text.index("    - hejo") < text.index("  entries:")
        assert text.index("    hejo:") < text.index("# Section comment")
        config = YAML().load(text)
        assert config["display"]["memory_notifications"] == "off"
        assert config["plugins"]["enabled"] == ["x", "z", "hejo"]
        assert config["gateway"]["platforms"]["hejo"]["enabled"] is True
    path = home / "config.yaml"
    path.write_text(path.read_text().replace("log_level: info", "log_level: debug"))
    assert cli(home, "--uninstall").returncode == 0
    assert path.read_text() == DRIFTING.replace("log_level: info", "log_level: debug")
    assert (home / "profiles/beta/config.yaml").read_text() == DRIFTING


def test_operating_formatting_conflict_restores_other_keys_line_by_line(install_airport):
    home = install_airport
    for profile in PROFILES:
        (home / profile / "config.yaml").write_text(DRIFTING)
    assert cli(home).returncode == 0
    path = home / "config.yaml"
    path.write_text(re.sub(r"port: 478[0-9]{2}", "port: 47999", path.read_text()))
    result = cli(home, "--uninstall")
    assert result.returncode == 2 and "config.yaml#gateway.platforms.hejo" in result.stdout
    text = path.read_text()
    assert "    - hejo" not in text and "port: 47999" in text
    assert [line for line in DRIFTING.splitlines() if line not in text.splitlines()] == []
    assert YAML().load(text)["plugins"]["enabled"] == ["x", "z"]


def test_empty_inline_parent_is_filled_on_its_own_line(install_airport):
    home = install_airport
    text = DRIFTING.replace("gateway:\n  log_level: info\n", "gateway: {}\n")
    for profile in PROFILES:
        (home / profile / "config.yaml").write_text(text)
    assert cli(home).returncode == 0
    installed = (home / "config.yaml").read_text()
    assert "gateway: {}" not in installed and "  platforms:" in installed
    assert [line for line in text.splitlines() if line not in installed.splitlines()] == ["gateway: {}"]
    assert cli(home, "--uninstall").returncode == 0
    assert (home / "config.yaml").read_text() == text


def test_primary_block_takes_first_free_port_and_tailscale_address(installer, monkeypatch):
    import socket
    with socket.socket() as busy:
        busy.bind(("127.0.0.1", 0))
        taken = busy.getsockname()[1]
        assert installer["free_port"](range(taken, taken + 3)) != taken
    monkeypatch.setitem(installer, "free_port", lambda ports=None: 47823)
    monkeypatch.setitem(installer, "tailscale_ipv4", lambda: "100.64.1.2")
    assert installer["primary_block"]()["extra"] == {"port": 47823, "listen": ["127.0.0.1", "100.64.1.2"], "allowed_users": ["owner"]}
    monkeypatch.setitem(installer, "tailscale_ipv4", lambda: None)
    assert installer["primary_block"]()["extra"]["listen"] == ["127.0.0.1"]
    assert installer["PRIMARY"]["extra"]["listen"] == ["127.0.0.1"]  # the template is never mutated
