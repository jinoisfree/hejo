"""AT-68 app HTTP/cache boundary with a temporary authenticated loopback server."""
import asyncio
import json
from pathlib import Path
import secrets
import sys
import tempfile
import uuid
import random
import struct
import zlib
from aiohttp import web


async def main():
    token = secrets.token_urlsafe(32)
    peers, stored = set(), {}
    counts = {"get": 0, "put": 0, "delete": 0, "leak": 0}
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    noise = random.Random(42).randbytes(512 * 512 * 3)
    pixels = b"".join(b"\0" + noise[row * 1536:(row + 1) * 1536] for row in range(512))
    legacy_large = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 512, 512, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b"")
    assert len(legacy_large) > 512*1024

    def roster():
        return [{"id": "alpha", "name": "Test alpha", "aliases": [], "color": "#12ABCD",
                 "avatar": "/v1/pictures/employee/alpha?v=2" if stored else None, "avatar_custom": bool(stored)}]

    async def socket(request):
        ws = web.WebSocketResponse(); await ws.prepare(request)
        hello = await ws.receive_json(); assert hello["pair_code"] == "test_code-12"
        await ws.send_json({"v": 1, "type": "welcome", "device_id": str(uuid.uuid4()), "token": token,
                            "gate_version": "test", "head_seq": 0, "employees": roster()})
        await ws.send_json({"v": 1, "type": "sync_done", "ref": "hello", "through": 0, "more": False, "head_seq": 0})
        peers.add(ws)
        try:
            async for message in ws:
                if message.type == web.WSMsgType.TEXT:
                    value = json.loads(message.data)
                    if value["type"] == "sync":
                        await ws.send_json({"v": 1, "type": "sync_done", "ref": value["id"], "through": 0, "more": False, "head_seq": 0})
        finally:
            peers.discard(ws)
        return ws

    async def picture(request):
        assert request.headers.get("Authorization") == "Bearer " + token
        key = request.match_info["id"]
        if request.method == "GET":
            counts["get"] += 1
            if request.query.get("v") == "redirect":
                raise web.HTTPFound("/leak")
            if request.query.get("v") == "large":
                return web.Response(body=legacy_large, content_type="image/png")
            return web.Response(body=stored[key], content_type="image/png")
        if request.method == "PUT":
            data = await request.read(); assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) <= 512*1024
            stored[key] = data; counts["put"] += 1
        else:
            stored.pop(key, None); counts["delete"] += 1
        for ws in peers:
            await ws.send_json({"v": 1, "type": "roster", "ref": "picture", "employees": roster()})
        return web.json_response({"ok": True, "picture": "/v1/pictures/employee/alpha?v=2" if stored else None})

    async def leak(request):
        counts["leak"] += 1
        return web.Response()

    app = web.Application(); app.router.add_get("/v1/ws", socket)
    app.router.add_route("*", "/v1/pictures/{kind}/{id}", picture); app.router.add_get("/leak", leak)
    runner = web.AppRunner(app, access_log=None); await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-picture-client-") as directory:
            process = await asyncio.create_subprocess_exec(str(Path(sys.argv[1]).resolve()), "--pictures", directory,
                f"ws://127.0.0.1:{site._server.sockets[0].getsockname()[1]}", *sys.argv[2:], stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            output, _ = await asyncio.wait_for(process.communicate(), 30)
            print(output.decode(), end=""); assert process.returncode == 0
            assert counts["put"] == 1 and counts["delete"] == 1 and counts["get"] == 3 and counts["leak"] == 0, counts
    finally:
        for ws in tuple(peers):
            await ws.close()
        await runner.cleanup()
    print("AT-HF-68 app authenticated HTTP/cache/redirect PASS")


asyncio.run(main())
