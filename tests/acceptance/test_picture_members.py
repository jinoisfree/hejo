"""AT-HF-68: valid credentials for a different member cannot touch this gate's pictures."""
import pytest
from test_hub import hub, http, call, link_gate
from gate.tests.test_pictures import png


@pytest.mark.asyncio
async def test_picture_member_isolation(gate, airport, hub, http):
    from hermes_cli.profiles import profiles_to_serve
    status, owner = await call(http, hub, "POST", "/v1/signup", {"account": "picture-owner", "password": "fake owner password", "device_name": "test-a"})
    assert status == 200
    status, other = await call(http, hub, "POST", "/v1/signup", {"account": "picture-other", "password": "fake other password", "device_name": "test-b"})
    assert status == 200
    await link_gate(gate, hub, http, "picture-owner", "fake owner password")
    target = dict(profiles_to_serve(True))["alpha"] / "assets/avatar.png"
    url = f"http://127.0.0.1:{gate.server.port}/v1/pictures/employee/alpha"
    for method in ("GET", "PUT", "DELETE"):
        async with http.request(method, url, data=png() if method == "PUT" else None,
                                headers={"Authorization": "Bearer " + other["token"]}) as response:
            assert response.status == 401
        assert not target.exists()
    async with http.put(url, data=png(), headers={"Authorization": "Bearer " + owner["token"]}) as response:
        assert response.status == 200
    assert target.read_bytes() == png()
    async with http.delete(url, headers={"Authorization": "Bearer " + other["token"]}) as response:
        assert response.status == 401
    assert target.read_bytes() == png()
