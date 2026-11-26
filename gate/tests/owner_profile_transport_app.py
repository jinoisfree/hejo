"""Run the two real AppKit controllers against the isolated loopback gate."""
import asyncio
import os
from pathlib import Path

from aiohttp import web
import pytest

from gate import owner
from gate.server import GateServer
from gate.tests.support import airport, registered, gate
from gate.tests.test_owner_profile import connected_gate


APP_TEST_BINARY = Path(os.environ.get("HEJO_OWNER_PROFILE_APP_TESTS", "app/.build/app-tests")).resolve()


async def run_app(gate, tmp_path, mode, expected):
    address = f"127.0.0.1:{gate.server.port}"
    _, first = gate.auth.pair(gate.auth.pair_code(), "Profile test A")
    _, second = gate.auth.pair(gate.auth.pair_code(), "Profile test B")
    process = await asyncio.create_subprocess_exec(
        str(APP_TEST_BINARY), "--owner-profile-transport", mode, address, str(tmp_path / "app-home"), first, second,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        output, errors = await asyncio.wait_for(process.communicate(), timeout=24)
        assert process.returncode == 0, (output + errors).decode()[-4500:]
        assert expected in output.decode(), output.decode()
        print(output.decode().strip())
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()


@pytest.mark.asyncio
async def test_at_op_35_two_app_controllers_profile_images(gate, tmp_path):
    await run_app(gate, tmp_path, "sync", "AT-OP-35 red")


@pytest.mark.asyncio
@pytest.mark.parametrize("fault", ["400", "401", "disconnect"])
async def test_at_op_23_failed_http_save_preserves_input(registered, airport, tmp_path, monkeypatch, fault):
    original = GateServer.owner_profile
    owner.write_name(airport, "등록된 이름")

    async def reject(server, request):
        if request.method != "PUT":
            return await original(server, request)
        await server.http_auth(request)
        if fault == "400":
            raise web.HTTPBadRequest(text="invalid_name")
        if fault == "401":
            raise web.HTTPUnauthorized()
        request.transport.close()
        return web.Response()

    monkeypatch.setattr(GateServer, "owner_profile", reject)
    async with connected_gate() as adapter:
        await run_app(adapter, tmp_path, fault, f"AT-OP-23 {fault} PASS")
