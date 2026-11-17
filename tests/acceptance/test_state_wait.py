"""AT-HF-93: authenticated revision wait preserves old GET, wakes only its member and times out empty."""
import asyncio
import pytest
from test_hub import hub, http, call
from test_member_state import entry

pytestmark = pytest.mark.asyncio


async def signup(http, hub, account):
    _, user = await call(http, hub, "POST", "/v1/signup", {
        "account": account, "password": "correct horse", "device_name": "fixture"})
    return user["token"]


async def test_at93_wait_wakes_without_polling_and_preserves_legacy_get(hub, http):
    token = await signup(http, hub, "member-a")
    other = await signup(http, hub, "member-b")
    hub.state_wait_seconds = 0.25
    waiting = asyncio.create_task(call(http, hub, "GET", "/v1/me/state?wait=0", token=token))
    await asyncio.sleep(0.03)
    assert not waiting.done()
    await call(http, hub, "PATCH", "/v1/me/state", {"items": {"pin:beta": entry("1")}}, token=other)
    await asyncio.sleep(0.03)
    assert not waiting.done(), "another member must neither wake nor leak into this response"
    await call(http, hub, "PATCH", "/v1/me/state", {"items": {"pin:alpha": entry("2")}}, token=token)
    status, value = await asyncio.wait_for(waiting, 0.15)
    assert status == 200 and value["rev"] == 1 and value["items"] == {"pin:alpha": entry("2")}
    assert (await call(http, hub, "GET", "/v1/me/state?since=1", token=token))[1] == {"rev": 1, "items": {}}
    assert (await call(http, hub, "GET", "/v1/me/state", token=token))[1] == value
    assert (await call(http, hub, "GET", "/v1/me/state?wait=0", token=token))[1] == value


async def test_at93_wait_timeout_capability_and_shutdown(hub, http):
    token = await signup(http, hub, "member-a")
    assert hub.state_wait_seconds == 25
    hub.state_wait_seconds = 0.06
    async with http.get(f"http://127.0.0.1:{hub.port}/v1/me/state?wait=0", headers={"Authorization": "Bearer " + token}) as response:
        assert response.headers["X-Hejo-State-Wait"] == "1"
        assert await response.json() == {"rev": 0, "items": {}}
    hub.state_wait_seconds = 25
    waiting = asyncio.create_task(call(http, hub, "GET", "/v1/me/state?wait=0", token=token))
    await asyncio.sleep(0.03)
    await hub.shutdown(None)
    assert (await asyncio.wait_for(waiting, 0.2))[1] == {"rev": 0, "items": {}}


@pytest.mark.parametrize("query", ["wait=-1", "wait=x", "wait=1.5", "wait=1&since=1", "wait=" , "wait=" + "1"*17])
async def test_at93_wait_rejects_bad_revisions_and_auth(hub, http, query):
    token = await signup(http, hub, "member-a")
    assert (await call(http, hub, "GET", "/v1/me/state?" + query, token=token))[1] == {"error": "bad_state"}
    assert (await call(http, hub, "GET", "/v1/me/state?wait=0"))[0] == 401
