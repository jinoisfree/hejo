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


def test_hub_link_writes_owner_only_key(install_airport, tmp_path):
    """`--hub` joins this Hermes to the hub as a member; the gate key lands in 0600 hub.json."""
    import asyncio, threading
    from hub.server import Hub
    from hub.store import HubStore
    HubStore(tmp_path / "hub").signup("member2", "another horse", "air")
    loop = asyncio.new_event_loop(); hub = Hub(tmp_path / "hub")
    loop.run_until_complete(hub.start(["127.0.0.1"], 0))
    thread = threading.Thread(target=loop.run_forever, daemon=True); thread.start()
    try:
        url = f"http://127.0.0.1:{hub.port}"
        environment = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
        run = lambda lines: subprocess.run([sys.executable, str(INSTALLER), "--home", str(install_airport), "--hub", url],
                                           env=environment, input=lines, capture_output=True, text=True)
        bad = run("member2\nwrong horse\n")
        assert bad.returncode == 1 and "hub_link_failed bad_login" in bad.stdout
        assert not (install_airport / "hejo/hub.json").exists()
        good = run("member2\nanother horse\n")
        assert good.returncode == 0, good.stdout + good.stderr
        path = install_airport / "hejo/hub.json"
        assert stat.S_IMODE(path.stat().st_mode) == 0o600
        value = json.loads(path.read_text())
        assert value["url"] == url and len(value["gate_key"]) >= 43 and "another horse" not in path.read_text()
        assert HubStore(tmp_path / "hub").gate(value["gate_key"])
    finally:
        loop.call_soon_threadsafe(loop.stop); thread.join(5)


@pytest.fixture
def home_channels_airport(install_airport):
    from hermes_cli.profiles import create_profile
    create_profile("gamma", no_alias=True, no_skills=True)
    for file in ("config.yaml", "profiles/beta/config.yaml", "profiles/gamma/config.yaml"):
        (install_airport / file).write_text(DRIFTING)
    return install_airport


def home_targets(home):
    return [item for item in receipt(home)["targets"] if item.get("owner_may_change") and item["keys"] == ["platforms", "hejo", "home_channel"]]


def set_owner_home(home, profile="default"):
    path = home / ("config.yaml" if profile == "default" else f"profiles/{profile}/config.yaml")
    yaml = YAML()
    document = yaml.load(path.read_text())
    document.setdefault("platforms", {}).setdefault("hejo", {})["home_channel"] = {
        "platform": "hejo", "chat_id": "owner-room", "name": "Owner choice"}
    with path.open("w") as stream:
        yaml.dump(document, stream)
    return path.read_bytes()


def legacy_install(home, installer, monkeypatch):
    # Create the old version-1 installed receipt: no home targets or top-level platforms.
    with monkeypatch.context() as patch:
        patch.setitem(installer, "home_target", lambda file, document: None)
        assert installer["main"](["--home", str(home)]) == 0
    data = receipt(home)
    assert not home_targets(home)
    assert data["status"] == "installed"
    return data


def test_at_hf_72_new_install_three_profiles_and_owner_value(home_channels_airport):
    """New installation uses profile ids, preserves existing owner values, and is idempotent."""
    home = home_channels_airport
    owner_bytes = set_owner_home(home, "beta")
    assert cli(home).returncode == 0
    data = receipt(home)
    assert len(home_targets(home)) == 2
    for profile in ("default", "beta", "gamma"):
        file = "config.yaml" if profile == "default" else f"profiles/{profile}/config.yaml"
        document = YAML().load((home / file).read_text())
        expected = {"platform": "hejo", "chat_id": profile, "name": profile}
        if profile == "beta":
            expected = {"platform": "hejo", "chat_id": "owner-room", "name": "Owner choice"}
        assert document["platforms"]["hejo"]["home_channel"] == expected
    snapshot = {file: (home / file).stat().st_mtime_ns for file in data["configs"]}
    assert cli(home).returncode == 0
    assert receipt(home) == data
    assert snapshot == {file: (home / file).stat().st_mtime_ns for file in data["configs"]}
    checked = cli(home, "--check")
    assert checked.returncode == 0 and "owner_set profiles/beta/config.yaml#platforms.hejo.home_channel" in checked.stdout
    assert cli(home, "--uninstall").returncode == 0
    assert (home / "profiles/beta/config.yaml").read_bytes() == owner_bytes
    assert (home / "config.yaml").read_text() == DRIFTING
    assert (home / "profiles/gamma/config.yaml").read_text() == DRIFTING


def test_at_hf_72_upgrade_old_receipt_and_missing_target(home_channels_airport, installer, monkeypatch):
    """Upgrade adds only absent home keys, keeping legacy targets and original snapshots."""
    home = home_channels_airport
    before = legacy_install(home, installer, monkeypatch)
    disk = (home / "hejo/install-receipt.json").read_bytes()
    result = cli(home, "--check")
    assert result.returncode == 1 and result.stdout.count("missing_target ") == 3
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    owner = set_owner_home(home, "beta")
    assert cli(home).returncode == 0
    after = receipt(home)
    assert after["targets"][:len(before["targets"])] == before["targets"]
    assert all(after["configs"][file]["before"] == cfg["before"] for file, cfg in before["configs"].items())
    assert len(home_targets(home)) == 2
    assert (home / "profiles/beta/config.yaml").read_bytes() == owner
    assert cli(home, "--check").returncode == 0


def test_at_hf_72_upgrade_failure_rolls_back_only_new_keys(home_channels_airport, installer, monkeypatch):
    """A second-profile failure removes this upgrade's keys without undoing the installed gate."""
    home = home_channels_airport
    before = legacy_install(home, installer, monkeypatch)
    configs = {file: (home / file).read_bytes() for file in before["configs"]}
    write = installer["write_config"]
    def fail_second(path, document, mode):
        if path == home / "profiles/beta/config.yaml":
            raise OSError("injected second-profile write failure")
        return write(path, document, mode)
    with monkeypatch.context() as patch:
        patch.setitem(installer, "write_config", fail_second)
        assert installer["main"](["--home", str(home)]) == 1
    after = receipt(home)
    assert after["status"] == "installed"
    assert after["targets"] == before["targets"]
    for file, original in configs.items():
        assert (home / file).read_bytes() == original
        assert after["configs"][file]["before"] == before["configs"][file]["before"]
    assert cli(home).returncode == 0
    assert cli(home, "--check").returncode == 0


@pytest.mark.parametrize("interruption", ["pending", "written", "owner_changed"])
@pytest.mark.parametrize("recover", ["install", "uninstall"])
def test_at_hf_72_interruption_reconcile(home_channels_airport, installer, monkeypatch, interruption, recover):
    """The durable pending target recovers all three crash boundaries, including immediate uninstall."""
    home = home_channels_airport
    legacy_install(home, installer, monkeypatch)
    save, apply = installer["save_receipt"], installer["apply"]
    class Interrupted(BaseException):
        pass
    def save_and_stop(root, data):
        save(root, data)
        if any(item.get("owner_may_change") for item in data["targets"]):
            assert all(item["state"] == "pending" for item in home_targets(home))
            assert all("platforms" not in YAML().load((home / file).read_text()) for file in data["configs"])
            raise Interrupted()
    def apply_and_stop(root, data, target):
        apply(root, data, target)
        if target.get("owner_may_change"):
            assert home_targets(home)[0]["state"] == "pending"
            raise Interrupted()
    with monkeypatch.context() as patch:
        patch.setitem(installer, "save_receipt" if interruption == "pending" else "apply",
                      save_and_stop if interruption == "pending" else apply_and_stop)
        with pytest.raises(Interrupted):
            installer["main"](["--home", str(home)])
    owner = set_owner_home(home) if interruption == "owner_changed" else None
    snapshot = (home / "config.yaml").stat().st_mtime_ns
    disk = (home / "hejo/install-receipt.json").read_bytes()
    checked = cli(home, "--check")
    assert checked.returncode == 1  # Other profiles still have no home channel.
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    result = cli(home) if recover == "install" else cli(home, "--uninstall")
    assert result.returncode == 0, result.stdout
    if recover == "install":
        if interruption == "written":
            assert (home / "config.yaml").stat().st_mtime_ns == snapshot
        target = home_targets(home)[0]
        assert target["state"] == ("released" if owner else "applied")
        assert cli(home, "--uninstall").returncode == 0
    if owner:
        expected = YAML().load(owner.decode())["platforms"]
        assert YAML().load((home / "config.yaml").read_text())["platforms"] == expected
        assert "preserved_owner_change" in result.stdout
    else:
        assert (home / "config.yaml").read_text() == DRIFTING
    for profile in ("beta", "gamma"):
        assert (home / f"profiles/{profile}/config.yaml").read_text() == DRIFTING


def test_at_hf_72_rollback_abc_and_reinstall(home_channels_airport):
    """Selective rollback preserves A's preexisting and B's changed value and removes C only."""
    home = home_channels_airport
    set_owner_home(home)
    assert cli(home).returncode == 0
    set_owner_home(home, "beta")
    before = receipt(home)
    unchanged = {file: (home / file).read_bytes() for file in ("config.yaml", "profiles/beta/config.yaml")}
    result = cli(home, "--uninstall-home-channel")
    assert result.returncode == 0
    assert "preserved_owner_change config.yaml#platforms.hejo.home_channel" in result.stdout
    assert "preserved_owner_change profiles/beta/config.yaml#platforms.hejo.home_channel" in result.stdout
    assert receipt(home)["status"] == "installed"
    assert [item for item in receipt(home)["targets"] if not item.get("owner_may_change")] == [
        item for item in before["targets"] if not item.get("owner_may_change")]
    assert [item["state"] for item in home_targets(home)] == ["released", "removed"]
    for file, original in unchanged.items():
        assert (home / file).read_bytes() == original
    assert "platforms" not in YAML().load((home / "profiles/gamma/config.yaml").read_text())
    assert cli(home, "--uninstall-home-channel").returncode == 0
    assert cli(home).returncode == 0
    assert cli(home, "--check").returncode == 0
    for file, original in unchanged.items():
        assert (home / file).read_bytes() == original


@pytest.mark.parametrize("failure", ["read", "write"])
def test_at_hf_72_c1_rollback_config_failure_keeps_applied(home_channels_airport, installer, monkeypatch, failure):
    """Config I/O failure returns 1 and never marks the still-present home channel removed (C1)."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    original = (home / "config.yaml").read_bytes()
    name = "read_config" if failure == "read" else "write_config"
    operation = installer[name]
    def fail(path, *args, **kwargs):
        if path == home / "config.yaml":
            raise OSError("injected config I/O failure")
        return operation(path, *args, **kwargs)
    with monkeypatch.context() as patch:
        patch.setitem(installer, name, fail)
        assert installer["main"](["--home", str(home), "--uninstall-home-channel"]) == 1
    assert (home / "config.yaml").read_bytes() == original
    target = next(item for item in home_targets(home) if item["file"] == "config.yaml")
    assert target["state"] == "applied"
    assert receipt(home)["status"] == "installed"
    assert cli(home, "--uninstall-home-channel").returncode == 0


def test_at_hf_72_owner_change_check_and_forced_uninstall(home_channels_airport):
    """Owner changes, including deleting the key, remain released even under forced uninstall."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    owner = set_owner_home(home)
    path = home / "profiles/beta/config.yaml"
    yaml = YAML()
    document = yaml.load(path.read_text())
    del document["platforms"]["hejo"]["home_channel"]
    with path.open("w") as stream:
        yaml.dump(document, stream)
    disk = (home / "hejo/install-receipt.json").read_bytes()
    checked = cli(home, "--check")
    assert checked.returncode == 0 and checked.stdout.count("owner_set ") == 1 and checked.stdout.count("owner_removed ") == 1
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    result = cli(home, "--uninstall", "--force")
    assert result.returncode == 0
    assert YAML().load((home / "config.yaml").read_text())["platforms"] == YAML().load(owner.decode())["platforms"]
    assert not YAML().load(path.read_text())["platforms"]["hejo"]


def test_at_hf_72_owner_change_between_reconcile_and_removal(home_channels_airport, installer, monkeypatch):
    """A concurrent owner edit after reconciliation is rechecked at the key deletion boundary."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    read = installer["read_config"]
    calls = 0
    owner = None
    def change_before_removal(path):
        nonlocal calls, owner
        if path == home / "config.yaml":
            calls += 1
            if calls == 2:
                owner = set_owner_home(home)
        return read(path)
    with monkeypatch.context() as patch:
        patch.setitem(installer, "read_config", change_before_removal)
        assert installer["main"](["--home", str(home), "--uninstall-home-channel"]) == 0
    assert owner is not None and (home / "config.yaml").read_bytes() == owner
    assert home_targets(home)[0]["state"] == "released"


def test_at_hf_72_upgrade_does_not_restore_obsolete_owner_home(home_channels_airport, installer, monkeypatch):
    """Removing an upgraded key cannot resurrect an owner value from the legacy before snapshot."""
    home = home_channels_airport
    set_owner_home(home)
    legacy_install(home, installer, monkeypatch)
    path = home / "config.yaml"
    yaml = YAML()
    document = yaml.load(path.read_text())
    del document["platforms"]["hejo"]["home_channel"]
    with path.open("w") as stream:
        yaml.dump(document, stream)
    assert cli(home).returncode == 0
    assert cli(home, "--uninstall-home-channel").returncode == 0
    assert "home_channel" not in yaml.load(path.read_text())["platforms"]["hejo"]
    assert cli(home, "--uninstall").returncode == 0
    assert "home_channel" not in yaml.load(path.read_text())["platforms"]["hejo"]


@pytest.mark.parametrize("remove_command", ["--uninstall-home-channel", "--uninstall"])
@pytest.mark.parametrize("interruption", ["removing", "deleted"])
@pytest.mark.parametrize("recover", ["install", "--uninstall-home-channel", "--uninstall"])
def test_at_hf_72_rollback_interruption(home_channels_airport, installer, monkeypatch,
                                       remove_command, interruption, recover):
    """AT-72 ④/⑤: durable deletion intent distinguishes a rollback crash from owner removal."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    before = receipt(home)
    config = home / "config.yaml"
    original = config.read_bytes()
    save, write = installer["save_receipt"], installer["write_config"]
    class Interrupted(BaseException):
        pass
    def save_and_stop(root, data):
        save(root, data)
        target = next(item for item in home_targets(home) if item["file"] == "config.yaml")
        if target["state"] == "removing":
            assert config.read_bytes() == original
            raise Interrupted()
    def write_and_stop(path, document, mode):
        written = write(path, document, mode)
        if path == config:
            target = next(item for item in home_targets(home) if item["file"] == "config.yaml")
            assert target["state"] == "removing"
            assert "platforms" not in YAML().load(config.read_text())
            raise Interrupted()
        return written
    with monkeypatch.context() as patch:
        patch.setitem(installer, "save_receipt" if interruption == "removing" else "write_config",
                      save_and_stop if interruption == "removing" else write_and_stop)
        with pytest.raises(Interrupted):
            installer["main"](["--home", str(home), remove_command])
    assert home_targets(home)[0]["state"] == "removing"
    snapshot = config.read_bytes(), config.stat().st_mtime_ns
    disk = (home / "hejo/install-receipt.json").read_bytes()
    checked = cli(home, "--check")
    assert checked.returncode == (0 if interruption == "removing" else 1)
    assert ("missing_target config.yaml#platforms.hejo.home_channel" in checked.stdout) == (interruption == "deleted")
    assert "owner_set" not in checked.stdout and "owner_removed" not in checked.stdout
    assert "preserved_owner_change" not in checked.stdout
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    assert (config.read_bytes(), config.stat().st_mtime_ns) == snapshot
    result = cli(home) if recover == "install" else cli(home, recover)
    assert result.returncode == 0, result.stdout
    assert "preserved_owner_change" not in result.stdout
    targets = [item for item in home_targets(home) if item["file"] == "config.yaml"]
    if recover == "install":
        assert targets[-1]["state"] == "applied"
        assert YAML().load(config.read_text())["platforms"]["hejo"]["home_channel"] == {
            "platform": "hejo", "chat_id": "default", "name": "default"}
        if interruption == "removing":
            assert (config.read_bytes(), config.stat().st_mtime_ns) == snapshot
        else:
            assert targets[0]["state"] == "removed"
        assert cli(home, "--check").returncode == 0
    else:
        assert targets[0]["state"] == "removed"
        assert "platforms" not in YAML().load(config.read_text())
        assert receipt(home)["status"] == ("installed" if recover == "--uninstall-home-channel" else "uninstalled")
    after = receipt(home)
    assert all(after["configs"][file]["before"] == cfg["before"] for file, cfg in before["configs"].items())
    if recover != "--uninstall":
        assert [item for item in after["targets"] if not item.get("owner_may_change")] == [
            item for item in before["targets"] if not item.get("owner_may_change")]


@pytest.mark.parametrize("recover", ["install", "--uninstall-home-channel", "--uninstall"])
def test_at_hf_72_removing_preserves_later_owner_value(home_channels_airport, installer, monkeypatch, recover):
    """A different value at removing belongs to the owner and becomes released on recovery."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    save = installer["save_receipt"]
    class Interrupted(BaseException):
        pass
    def stop(root, data):
        save(root, data)
        if home_targets(home)[0]["state"] == "removing":
            raise Interrupted()
    with monkeypatch.context() as patch:
        patch.setitem(installer, "save_receipt", stop)
        with pytest.raises(Interrupted):
            installer["main"](["--home", str(home), "--uninstall-home-channel"])
    owner = set_owner_home(home)
    disk = (home / "hejo/install-receipt.json").read_bytes()
    checked = cli(home, "--check")
    assert checked.returncode == 0 and "owner_set config.yaml#platforms.hejo.home_channel" in checked.stdout
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    result = cli(home) if recover == "install" else cli(home, recover)
    assert result.returncode == 0 and "preserved_owner_change config.yaml#platforms.hejo.home_channel" in result.stdout
    assert home_targets(home)[0]["state"] == "released"
    config = (home / "config.yaml").read_bytes()
    assert YAML().load(config.decode())["platforms"] == YAML().load(owner.decode())["platforms"]
    if recover != "--uninstall":
        assert config == owner


@pytest.mark.parametrize("legacy", [False, True])
def test_at_hf_72_failed_install_uses_durable_removal(home_channels_airport, installer, monkeypatch, legacy):
    """Both fresh-install and installed-upgrade failure rollback persist removing before deletion."""
    home = home_channels_airport
    if legacy:
        legacy_install(home, installer, monkeypatch)
    write, save = installer["write_config"], installer["save_receipt"]
    states = []
    injected = False
    def observe(root, data):
        save(root, data)
        targets = home_targets(home)
        if targets:
            states.append(targets[0]["state"])
    def fail_second_profile(path, document, mode):
        nonlocal injected
        if path == home / "profiles/beta/config.yaml" and not injected:
            injected = True
            raise OSError("injected install failure")
        if path == home / "config.yaml":
            current = YAML().load(path.read_text())
            if "home_channel" in current.get("platforms", {}).get("hejo", {}) and "home_channel" not in document.get("platforms", {}).get("hejo", {}):
                assert home_targets(home)[0]["state"] == "removing"
                assert states[-1] == "removing"
        return write(path, document, mode)
    with monkeypatch.context() as patch:
        patch.setitem(installer, "save_receipt", observe)
        patch.setitem(installer, "write_config", fail_second_profile)
        assert installer["main"](["--home", str(home)]) == 1
    assert injected and "removing" in states and "removed" in states
    assert states.index("removing") < states.index("removed")
    assert receipt(home)["status"] == ("installed" if legacy else "failed")
    assert "platforms" not in YAML().load((home / "config.yaml").read_text())
    assert cli(home).returncode == 0
    assert cli(home, "--check").returncode == 0


def test_at_hf_72_owner_removed_is_distinct_from_rollback(home_channels_airport):
    """An owner-deleted key remains released, with owner_removed and a read-only successful check."""
    home = home_channels_airport
    assert cli(home).returncode == 0
    config = home / "config.yaml"
    yaml = YAML()
    document = yaml.load(config.read_text())
    del document["platforms"]["hejo"]["home_channel"]
    with config.open("w") as stream:
        yaml.dump(document, stream)
    original = config.read_bytes()
    assert cli(home).returncode == 0
    assert home_targets(home)[0]["state"] == "released"
    disk = (home / "hejo/install-receipt.json").read_bytes()
    checked = cli(home, "--check")
    assert checked.returncode == 0
    assert "owner_removed config.yaml#platforms.hejo.home_channel" in checked.stdout
    assert "owner_set config.yaml#platforms.hejo.home_channel" not in checked.stdout
    assert (home / "hejo/install-receipt.json").read_bytes() == disk
    assert config.read_bytes() == original
    assert cli(home, "--uninstall-home-channel").returncode == 0
    assert config.read_bytes() == original


def test_at85_cleanup_progress_installs_only_missing_key_and_home_rollback_leaves_it(install_airport):
    home=install_airport;yaml=YAML()
    (home/'config.yaml').write_text('display:\n  cleanup_progress: false\n  platforms:\n    slack: {cleanup_progress: false}\n')
    owner='display:\n  platforms:\n    hejo: {cleanup_progress: false}\n'
    (home/'profiles/beta/config.yaml').write_text(owner)
    assert cli(home).returncode==0
    document=yaml.load((home/'config.yaml').read_text())
    assert document['display']=={'cleanup_progress':False,'platforms':{'slack':{'cleanup_progress':False},'hejo':{'cleanup_progress':True}}}
    assert yaml.load((home/'profiles/beta/config.yaml').read_text())['display']['platforms']['hejo']['cleanup_progress'] is False
    targets=[t for t in receipt(home)['targets'] if t.get('keys')==['display','platforms','hejo','cleanup_progress']]
    assert len(targets)==1 and targets[0]['state']=='applied' and targets[0]['after'] is True
    assert cli(home,'--check').returncode==0
    assert cli(home,'--uninstall-home-channel').returncode==0
    assert yaml.load((home/'config.yaml').read_text())['display']['platforms']['hejo']['cleanup_progress'] is True
    assert cli(home,'--uninstall').returncode==0
    assert yaml.load((home/'config.yaml').read_text())['display']=={'cleanup_progress':False,'platforms':{'slack':{'cleanup_progress':False}}}
    assert (home/'profiles/beta/config.yaml').read_text()==owner


def test_at85_cleanup_upgrade_rollback_and_owner_change(install_airport,installer,monkeypatch):
    home=install_airport;yaml=YAML()
    with monkeypatch.context() as patch:
        patch.setitem(installer,'cleanup_target',lambda file,doc:None)
        assert installer['main'](['--home',str(home)])==0
    old={file:(home/file).read_bytes() for file in receipt(home)['configs']}
    assert cli(home,'--check').returncode==1
    write=installer['write_config']
    def fail(path,document,mode):
        value=document.get('display',{}).get('platforms',{}).get('hejo',{}).get('cleanup_progress')
        if path.parent.name=='beta' and value is True:raise OSError('fake failure')
        return write(path,document,mode)
    with monkeypatch.context() as patch:
        patch.setitem(installer,'write_config',fail)
        assert installer['main'](['--home',str(home)])==1
    assert receipt(home)['status']=='installed'
    assert all((home/file).read_bytes()==raw for file,raw in old.items())
    assert cli(home).returncode==0
    path=home/'config.yaml';doc=yaml.load(path.read_text());doc['display']['platforms']['hejo']['cleanup_progress']=False
    with path.open('w') as f:yaml.dump(doc,f)
    assert cli(home,'--check').returncode==0
    assert cli(home,'--uninstall').returncode==0
    assert yaml.load(path.read_text())['display']['platforms']['hejo']['cleanup_progress'] is False
