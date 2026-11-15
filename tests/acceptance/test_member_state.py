"""AT-HF-73: screen state never crosses members, loses concurrent keys, or regresses read positions."""
import asyncio
import json
import stat
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
import uuid

import pytest

from hub.state import MemberStateStore
from hub.store import Rejected
from test_hub import hub, http, call


def entry(value, at=10, dev="device-a"):
    return {"v": value, "at": at, "dev": dev}


def test_at_hf_73_lww_reads_tombstones_caps_and_atomic_failure(tmp_path):
    state = MemberStateStore(tmp_path)
    member = str(uuid.uuid4())
    first = state.patch(member, {"pin:alpha": entry("1"), "read:alpha": entry("20")})
    second = state.patch(member, {"pin:alpha": entry("2", 9), "read:alpha": entry("19", 99)})
    assert second["items"] == first["items"] and second["rev"] > first["rev"]
    assert state.patch(member, {"pin:alpha": entry("3", 10, "device-b")})["items"]["pin:alpha"]["v"] == "3"
    assert state.patch(member, {"pin:alpha": entry(None, 11)})["items"]["pin:alpha"] == entry(None, 11)
    for prefix, keep in (("thread:", 3000), ("bell:", 1000), ("confirm:", 2000), ("check:", 2000)):
        doc = state.patch(member, {prefix + str(i): entry(str(i), i) for i in range(keep + 1)})
        assert sum(key.startswith(prefix) for key in doc["items"]) == keep
        assert prefix + "0" not in doc["items"] and prefix + str(keep) in doc["items"]
    path = tmp_path / "state" / (member + ".json")
    original = path.read_bytes()
    with patch("hub.state.os.replace", side_effect=OSError("injected replace failure")):
        with pytest.raises(OSError):
            state.patch(member, {"title:alpha": entry("new")})
    assert path.read_bytes() == original and stat.S_IMODE(path.stat().st_mode) == 0o600
    assert not list(path.parent.glob(".state-*"))
    assert state.get(member, json.loads(original)["rev"])["items"] == {}


def test_at_hf_73_concurrent_patch_preserves_both_documents(tmp_path):
    member = str(uuid.uuid4())
    def write(key):
        return MemberStateStore(tmp_path).patch(member, {key: entry("1")})
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(write, ["hide:alpha", "mute:beta"]))
    assert sorted(item["rev"] for item in results) == [1, 2]
    assert MemberStateStore(tmp_path).get(member)["items"] == {"hide:alpha": entry("1"), "mute:beta": entry("1")}


@pytest.mark.parametrize("items", [
    {"x" * 201: entry("x")}, {"x": entry("x" * 4097)}, {"x": entry("x", float("nan"))},
    {"x": entry("x", True)}, {"x": {"v": "x", "at": 1}}, {"read:alpha": entry("-1")},
    {"bell:alpha": entry("1.5")}, {"x\ny": entry("x")},
    {"x": entry("x", 10 ** 400)},
])
def test_at_hf_73_bad_state_is_rejected_without_changes(tmp_path, items):
    state, member = MemberStateStore(tmp_path), str(uuid.uuid4())
    state.patch(member, {"hide:alpha": entry("1")})
    before = state.get(member)
    with pytest.raises(Rejected, match="bad_state"):
        state.patch(member, items)
    assert state.get(member) == before


def test_at_hf_73_member_size_limit_keeps_previous_file(tmp_path):
    state, member = MemberStateStore(tmp_path), str(uuid.uuid4())
    before = state.patch(member, {"hide:alpha": entry("1")})
    with pytest.raises(Rejected, match="bad_state"):
        state.patch(member, {"layout:" + str(i): entry("x" * 4096) for i in range(260)})
    assert state.get(member) == before


@pytest.mark.asyncio
async def test_at_hf_73_authenticated_state_api_and_member_isolation(hub, http):
    _, a = await call(http, hub, "POST", "/v1/signup", {"account": "member-a", "password": "correct horse", "device_name": "a"})
    _, b = await call(http, hub, "POST", "/v1/signup", {"account": "member-b", "password": "another horse", "device_name": "b"})
    assert (await call(http, hub, "GET", "/v1/me/state"))[0] == 401
    assert (await call(http, hub, "PATCH", "/v1/me/state", {"items": {}}, token="foreign-hub-token"))[0] == 401
    status, saved = await call(http, hub, "PATCH", "/v1/me/state", {"items": {"hide:alpha": entry("1")}}, token=a["token"])
    assert status == 200 and saved["rev"] == 1
    assert (await call(http, hub, "GET", "/v1/me/state", token=b["token"]))[1] == {"rev": 0, "items": {}}
    assert (await call(http, hub, "GET", "/v1/me/state?since=1", token=a["token"]))[1] == {"rev": 1, "items": {}}
    responses = await asyncio.gather(*(call(http, hub, "PATCH", "/v1/me/state", {"items": {key: entry("1")}}, token=a["token"]) for key in ("mute:alpha", "pin:beta")))
    assert all(status == 200 for status, _ in responses)
    assert sorted(body["rev"] for _, body in responses) == [2, 3]
    assert len((await call(http, hub, "GET", "/v1/me/state", token=a["token"]))[1]["items"]) == 3
    assert (await call(http, hub, "PATCH", "/v1/me/state", {"items": {"x" * 201: entry("x")}}, token=a["token"]))[1]["error"] == "bad_state"
    large = {"layout:" + str(i): entry("x" * 4096) for i in range(260)}
    assert (await call(http, hub, "PATCH", "/v1/me/state", {"items": large}, token=a["token"]))[1]["error"] == "bad_state"
    # A valid state request above the older settings endpoint's 64 KiB body limit must work.
    bulk = {"check:bulk:" + str(i): entry("x" * 4096) for i in range(20)}
    status, saved = await call(http, hub, "PATCH", "/v1/me/state", {"items": bulk}, token=a["token"])
    assert status == 200 and all(saved["items"][key] == value for key, value in bulk.items())
