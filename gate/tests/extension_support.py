"""HTTP fixture helpers shared by attachment contract tests."""
from aiohttp import ClientSession, FormData


async def upload(gate, employee="alpha", name="sample.png", data=b"fixture image"):
    async with ClientSession(trust_env=False) as session:
        form = FormData()
        form.add_field("file", data, filename=name, content_type="image/png")
        headers = {"Authorization": "Bearer " + gate.auth.pair(gate.auth.pair_code(), "HTTP test")[1]}
        async with session.post(f"http://127.0.0.1:{gate.server.port}/v1/files",
                                params={"employee": employee}, data=form, headers=headers) as response:
            assert response.status == 200
            return await response.json(), headers


async def get(gate, suffix, headers=None):
    async with ClientSession(trust_env=False) as session:
        async with session.get(f"http://127.0.0.1:{gate.server.port}/v1/{suffix}", headers=headers) as response:
            return response.status, await response.read()

