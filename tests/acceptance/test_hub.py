"""AT-HF-58/59/60: the hejo hub (members, sign-in, Google, settings) and each member's gate joined to it."""
import ipaddress
import json
from unittest.mock import patch

import pytest
import pytest_asyncio
from aiohttp import ClientSession

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture
async def hub(tmp_path):
    from hub.server import Hub
    value = Hub(tmp_path / "hub")
    await value.start(["127.0.0.1"], 0)
    yield value
    await value.stop()


@pytest_asyncio.fixture
async def http():
    async with ClientSession() as session:
        yield session


async def call(http, hub, method, path, body=None, token=None, gate=None):
    headers = {"Authorization": "Bearer " + token} if token else {"Authorization": "Gate " + gate} if gate else {}
    async with http.request(method, f"http://127.0.0.1:{hub.port}{path}", json=body, headers=headers) as response:
        text = await response.text()
        try:
            return response.status, json.loads(text)
        except ValueError:
            return response.status, text


async def test_at_hf_58_members_sign_up_sign_in_and_keep_their_own_settings(hub, http):
    status, body = await call(http, hub, "POST", "/v1/login", {"account": "admin", "password": "correct horse", "device_name": "d"})
    assert (status, body["error"]) == (401, "bad_login")
    status, body = await call(http, hub, "POST", "/v1/signup", {"account": "x", "password": "correct horse", "device_name": "d"})
    assert body["error"] == "bad_id"
    status, body = await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "short", "device_name": "d"})
    assert body["error"] == "weak_password"
    status, admin = await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "correct horse", "device_name": "pro"})
    assert status == 200 and admin["token"]
    status, member2 = await call(http, hub, "POST", "/v1/signup", {"account": "member2", "password": "another horse", "device_name": "air"})
    assert status == 200 and member2["token"] != admin["token"]
    status, body = await call(http, hub, "POST", "/v1/signup", {"account": "member2", "password": "taken horse", "device_name": "x"})
    assert body["error"] == "exists"
    stored = (hub.home / "members.json").read_text()
    assert "correct horse" not in stored and "another horse" not in stored
    status, me = await call(http, hub, "GET", "/v1/me", token=member2["token"])
    assert me == {"account": "member2", "google": False, "settings": {}, "gate": None}
    assert (await call(http, hub, "PUT", "/v1/me/settings", {"settings": {"petName": "Mochi"}}, token=member2["token"]))[0] == 200
    assert (await call(http, hub, "GET", "/v1/me", token=member2["token"]))[1]["settings"] == {"petName": "Mochi"}
    assert (await call(http, hub, "GET", "/v1/me", token=admin["token"]))[1]["settings"] == {}
    assert (await call(http, hub, "PUT", "/v1/me/settings", {"settings": {"x": "y" * 20000}}, token=member2["token"]))[1]["error"] == "bad_settings"
    for _ in range(5):
        assert (await call(http, hub, "POST", "/v1/login", {"account": "admin", "password": "wrong horse", "device_name": "d"}))[1]["error"] == "bad_login"
    status, body = await call(http, hub, "POST", "/v1/login", {"account": "admin", "password": "correct horse", "device_name": "d"})
    assert (status, body["error"]) == (429, "locked")
    status, body = await call(http, hub, "POST", "/v1/login", {"account": "member2", "password": "another horse", "device_name": "d"})
    assert status == 200  # one member's lockout never blocks another
    assert (await call(http, hub, "GET", "/v1/me", token="forged"))[0] == 401
    from hub import google
    assert (await call(http, hub, "GET", "/v1/hub"))[1] == {"hub": 1, "google_client_id": google.client_id(hub.home)}


async def test_at_hf_59_google_sign_in_link_and_reset(hub, http):
    from hub import google
    who = {"sub": "g-admin"}
    async def identity(home, id_token):
        if who["sub"] is None:
            raise google.GoogleRejected("identity")
        return who["sub"], "google-address"
    with patch.object(google, "identity", identity):
        status, admin = await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "correct horse", "google_id_token": "t", "device_name": "pro"})
        assert status == 200
        status, body = await call(http, hub, "POST", "/v1/signup", {"account": "other", "password": "correct horse", "google_id_token": "t", "device_name": "x"})
        assert body["error"] == "google_in_use"
        status, body = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "device_name": "air"})
        assert status == 200 and body["token"]
        who["sub"] = "g-member2"
        await call(http, hub, "POST", "/v1/signup", {"account": "member2", "password": "another horse", "device_name": "air"})
        assert (await call(http, hub, "POST", "/v1/google", {"id_token": "t", "account": "member2", "password": "bad horse", "device_name": "d"}))[1]["error"] == "bad_login"
        assert (await call(http, hub, "POST", "/v1/google", {"id_token": "t", "account": "member2", "password": "another horse", "device_name": "d"}))[0] == 200
        status, member2 = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "device_name": "air2"})
        assert (await call(http, hub, "GET", "/v1/me", token=member2["token"]))[1]["account"] == "member2"
        who["sub"] = None
        assert (await call(http, hub, "POST", "/v1/google", {"id_token": "t", "device_name": "d"}))[1]["error"] == "google_failed"
        who["sub"] = "g-admin"
        status, reset = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "new_password": "after reset!", "device_name": "pro"})
        assert status == 200
    assert (await call(http, hub, "GET", "/v1/me", token=admin["token"]))[0] == 401  # reset signed every admin device out
    assert (await call(http, hub, "GET", "/v1/me", token=member2["token"]))[0] == 200   # member2 untouched
    assert (await call(http, hub, "POST", "/v1/login", {"account": "admin", "password": "after reset!", "device_name": "d"}))[0] == 200


async def test_google_identity_checks_audience_issuer_and_email(tmp_path):
    from hub import google
    info = {"aud": "cid", "iss": "https://accounts.google.com", "email_verified": "true", "sub": "s1", "email": "e"}
    async def get(url, params):
        assert params == {"id_token": "jwt"}
        return 200, dict(info)
    with patch.object(google, "SHARED", tmp_path / "missing.json"):
        with pytest.raises(google.GoogleRejected):
            await google.identity(tmp_path, "jwt")
        (tmp_path / google.CLIENT_FILE).write_text(json.dumps({"client_id": "cid"}))
        with patch.object(google, "_get", get):
            assert await google.identity(tmp_path, "jwt") == ("s1", "e")
            for change in ({"aud": "other"}, {"email_verified": "false"}, {"iss": "https://evil.example"}):
                saved = dict(info); info.update(change)
                with pytest.raises(google.GoogleRejected):
                    await google.identity(tmp_path, "jwt")
                info.clear(); info.update(saved)


async def link_gate(gate, hub, http, account, password):
    """What `hejo-install --hub` does in the member's own Mac account: link, then the gate reads hub.json."""
    from gate.hub import HubLink
    status, body = await call(http, hub, "POST", "/v1/link", {"account": account, "password": password})
    assert status == 200
    (gate.auth.path / "hub.json").write_text(json.dumps({"url": f"http://127.0.0.1:{hub.port}", "gate_key": body["gate_key"]}))
    gate.hub = HubLink(gate.auth.path.parent)
    assert await gate.hub.register(gate.server.port)


async def test_at_hf_60_member_gate_accepts_only_its_members_sign_ins(gate, client, hub, http):
    _, admin = await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "correct horse", "device_name": "pro"})
    _, member2 = await call(http, hub, "POST", "/v1/signup", {"account": "member2", "password": "another horse", "device_name": "air"})
    ws, rejected = await client.open(token=admin["token"])
    assert rejected["type"] == "auth_rejected"; await ws.close()  # not joined to a hub yet
    await link_gate(gate, hub, http, "admin", "correct horse")
    assert (await call(http, hub, "GET", "/v1/me", token=admin["token"]))[1]["gate"] == {"port": gate.server.port}
    assert (await call(http, hub, "GET", "/v1/me", token=member2["token"]))[1]["gate"] is None
    ws, welcome = await client.open(token=admin["token"])
    assert welcome["type"] == "welcome" and "token" not in welcome; await ws.close()
    ws, rejected = await client.open(token=member2["token"])
    assert rejected["type"] == "auth_rejected"; await ws.close()  # another member's device never opens this Hermes
    async with http.get(f"http://127.0.0.1:{gate.server.port}/v1/files/alpha/00000000-0000-4000-8000-000000000000",
                        headers={"Authorization": "Bearer " + admin["token"]}) as response:
        assert response.status == 404  # authorized; the file simply does not exist
    async with http.get(f"http://127.0.0.1:{gate.server.port}/v1/files/alpha/00000000-0000-4000-8000-000000000000",
                        headers={"Authorization": "Bearer " + member2["token"]}) as response:
        assert response.status == 401
    status, body = await call(http, hub, "POST", "/v1/gate/verify", {"token": admin["token"]}, gate="forged")
    assert status == 401


async def test_at_hf_60_airport_mac_reset_goes_through_the_members_gate(gate, client, hub, http):
    from gate.server import GateServer
    _, admin = await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "correct horse", "device_name": "pro"})
    code = json.loads((gate.auth.path / "local-pair.json").read_text())["code"]
    ws, rejected = await client.open(local={"code": code, "password": "brand new pass"})
    assert rejected["reason"] == "local_only"; await ws.close()  # not joined to a hub
    await link_gate(gate, hub, http, "admin", "correct horse")
    code = json.loads((gate.auth.path / "local-pair.json").read_text())["code"]
    with patch.object(GateServer, "peer", staticmethod(lambda request: ipaddress.ip_address("100.100.1.1"))):
        ws, rejected = await client.open(local={"code": code, "password": "brand new pass"})
    assert rejected["reason"] == "local_only"; await ws.close()
    code = json.loads((gate.auth.path / "local-pair.json").read_text())["code"]
    ws, rejected = await client.open(local={"code": code, "password": "short"})
    assert rejected["reason"] == "weak_password"; await ws.close()
    code = json.loads((gate.auth.path / "local-pair.json").read_text())["code"]
    ws, welcome = await client.open(local={"code": code, "password": "brand new pass"})
    assert welcome["type"] == "welcome" and welcome["token"]; await ws.close()
    assert (await call(http, hub, "GET", "/v1/me", token=admin["token"]))[0] == 401
    assert (await call(http, hub, "GET", "/v1/me", token=welcome["token"]))[1]["account"] == "admin"
    assert (await call(http, hub, "POST", "/v1/login", {"account": "admin", "password": "brand new pass", "device_name": "d"}))[0] == 200


async def test_gate_routes_and_link_are_loopback_only(hub, http):
    from hub import server
    await call(http, hub, "POST", "/v1/signup", {"account": "admin", "password": "correct horse", "device_name": "pro"})
    with patch.object(server, "loopback", lambda address: False):
        assert (await call(http, hub, "POST", "/v1/link", {"account": "admin", "password": "correct horse"}))[0] == 403
        assert (await call(http, hub, "POST", "/v1/gate/verify", {"token": "t"}, gate="k"))[0] == 403
    with patch.object(server, "allowed", lambda address: False):
        assert (await call(http, hub, "GET", "/v1/hub"))[0] == 403


def test_operator_links_a_member_hermes_without_password(tmp_path):
    import stat
    from hub.__main__ import main
    from hub.store import HubStore
    store = HubStore(tmp_path / "hub")
    store.signup("admin", "correct horse", "pro")
    assert main(["--home", str(tmp_path / "hub"), "--link", "nobody", "--hermes-home", str(tmp_path / "hermes")]) == 1
    assert main(["--home", str(tmp_path / "hub"), "--link", "admin", "--hermes-home", str(tmp_path / "hermes"), "--port", "47999"]) == 0
    path = tmp_path / "hermes" / "hejo" / "hub.json"
    value = json.loads(path.read_text())
    assert stat.S_IMODE(path.stat().st_mode) == 0o600 and value["url"] == "http://127.0.0.1:47999"
    assert store.gate(value["gate_key"])



async def test_first_google_sign_in_creates_the_member(hub, http):
    """Like other apps: the first Google sign-in creates a member (id from the address), no password until set."""
    from hub import google
    who = {"sub": "g-new", "email": "new.person@example.invalid"}
    async def identity(home, id_token):
        return who["sub"], who["email"]
    with patch.object(google, "identity", identity):
        await call(http, hub, "POST", "/v1/signup", {"account": "new.person", "password": "correct horse", "device_name": "x"})
        status, first = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "device_name": "air"})
        assert status == 200 and first["created"] is True and first["account"] == "new.person-2"
        status, again = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "device_name": "air"})
        assert status == 200 and again["created"] is False and again["account"] == "new.person-2"
        assert (await call(http, hub, "GET", "/v1/me", token=again["token"]))[1]["google"] is True
        status, body = await call(http, hub, "POST", "/v1/login", {"account": "new.person-2", "password": "anything goes", "device_name": "d"})
        assert body["error"] == "bad_login"  # no password yet
        status, reset = await call(http, hub, "POST", "/v1/google", {"id_token": "t", "new_password": "chosen later", "device_name": "air"})
        assert status == 200
        assert (await call(http, hub, "POST", "/v1/login", {"account": "new.person-2", "password": "chosen later", "device_name": "d"}))[0] == 200
