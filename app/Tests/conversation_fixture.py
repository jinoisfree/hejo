"""Conversation UI transport boundary: ephemeral loopback HTTP/WS, fake roster only."""
import asyncio
import json
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import uuid

from aiohttp import web
from jsonschema import Draft202012Validator

THREAD = "11111111-1111-4111-8111-111111111111"
MESSAGE = "33333333-3333-4333-8333-333333333333"
BUTTON = "44444444-4444-4444-8444-444444444444"
REDIRECT = "77777777-7777-4777-8777-777777777777"


async def main():
    binary = Path(sys.argv[1]).resolve()
    validator = Draft202012Validator(json.loads((Path(__file__).resolve().parents[2] / "schemas/hejo-wire-v1.json").read_text()))
    credential = secrets.token_urlsafe(32)
    seq = 0
    pending = {}
    registered = {}
    errors = []
    observed = {"uploads": 0, "clicks": 0, "sends": 0, "downloads": 0, "redirect_followed": 0}

    def authenticated(request):
        assert request.headers.get("Authorization") == "Bearer " + credential

    def valid(frame):
        if not validator.is_valid(frame):
            raise AssertionError("fixture violates shared wire schema")

    async def ws_handler(request):
        nonlocal seq
        ws = web.WebSocketResponse(); await ws.prepare(request)
        try:
            hello = await ws.receive_json(); valid(hello)
            pairing = "pair_code" in hello
            if pairing:
                assert hello.get("pair_code") == "test_code-12" and hello["since"] == 0
            else:
                assert hello.get("token") == credential and hello["since"] == seq

            async def send(kind, **values):
                nonlocal seq
                frame = {"v": 1, "type": kind, **values}
                if kind in {"message", "edit", "state", "delete"}:
                    seq += 1; frame["seq"] = seq
                valid(frame); await ws.send_json(frame)

            async def message(id, text, role="employee", files=None, buttons=None, client_id=None):
                fields = dict(msg_id=id, employee="alpha", thread=THREAD, role=role, text=text, files=files or [],
                              buttons=buttons or [], reply_state=None, ts="2026-01-01T00:00:00Z")
                if client_id is not None:
                    fields["client_msg_id"] = client_id
                await send("message", **fields)

            welcome = dict(device_id=str(uuid.uuid4()), gate_version="test", head_seq=3 if pairing else seq,
                           employees=[dict(id="alpha", name="Alpha", aliases=[], avatar=None), dict(id="beta", name="Beta", aliases=[], avatar=None)])
            if pairing:
                welcome["token"] = credential
            await send("welcome", **welcome)
            if pairing:
                await message(MESSAGE, "first answer", buttons=[dict(id=BUTTON, label="Continue", kind="reply", style="primary")])
                await send("edit", msg_id=MESSAGE, text="stream **answer**", final=False)
                await send("state", msg_id=MESSAGE, reply_state="asked")
                await send("sync_done", ref="hello", through=3, more=False, head_seq=3)
            else:
                await send("sync_done", ref="hello", through=seq, more=False, head_seq=seq)
            async for item in ws:
                if item.type != web.WSMsgType.TEXT:
                    continue
                frame = json.loads(item.data); valid(frame)
                if frame["type"] == "click":
                    assert frame["msg_id"] == MESSAGE and frame["button_id"] == BUTTON
                    observed["clicks"] += 1
                    await send("state", msg_id=MESSAGE, reply_state="closed")
                elif frame["type"] == "send":
                    observed["sends"] += 1
                    assert frame["employee"] == "alpha" and frame["thread"] == THREAD
                    if frame["text"] == "disconnect unacknowledged":
                        request.transport.abort()
                        return ws
                    elif frame["text"] == "reject attachment":
                        await send("error", code="unknown_file", ref=frame["id"])
                    elif frame["text"] == "too large reply":
                        await send("error", code="too_large", ref=frame["id"])
                    else:
                        assert frame["text"] in ("normal request", "normal request again")
                        assert len(frame["files"]) == (1 if frame["text"] == "normal request" else 0)
                        attached = []
                        for file_id in frame["files"]:
                            employee, data, info = pending.pop(file_id)
                            assert employee == frame["employee"]
                            registered[file_id] = (employee, data, info); attached.append(info)
                        await message(str(uuid.uuid4()), frame["text"], role="owner", files=attached, client_id=frame["client_msg_id"])
                        if frame["text"] == "normal request":
                            await send("message", msg_id=str(uuid.uuid4()), employee="beta", thread="22222222-2222-4222-8222-222222222222",
                                       role="employee", text="A separate conversation", files=[], buttons=[], reply_state=None, ts="2026-01-01T00:01:00Z")
                            await send("typing", employee="alpha", thread=THREAD, on=True, ttl_seconds=6)
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        except Exception as error:
            errors.append(type(error).__name__)
        return ws

    async def upload(request):
        try:
            authenticated(request)
            assert request.query["employee"] == "alpha"
            part = await (await request.multipart()).next()
            assert part.name == "file" and part.filename == "note.txt"
            await asyncio.sleep(0.15)
            data = await part.read(); assert data == b"fixture attachment"
            info = dict(file_id=str(uuid.uuid4()), name=part.filename, mime="text/plain", size=len(data))
            pending[info["file_id"]] = (request.query["employee"], data, info)
            observed["uploads"] += 1
            return web.json_response(info)
        except Exception as error:
            errors.append(type(error).__name__); raise web.HTTPBadRequest()

    async def download(request):
        authenticated(request)
        file_id = request.match_info["file_id"]
        if file_id == REDIRECT:
            raise web.HTTPFound(location="/credential-leak")
        if file_id not in registered or registered[file_id][0] != request.match_info["employee"]:
            raise web.HTTPNotFound()
        observed["downloads"] += 1
        return web.Response(body=registered[file_id][1], content_type="text/plain")

    async def leak(request):
        observed["redirect_followed"] += 1
        return web.Response()

    app = web.Application(); app.router.add_get("/v1/ws", ws_handler)
    app.router.add_post("/v1/files", upload); app.router.add_get("/v1/files/{employee}/{file_id}", download)
    app.router.add_get("/credential-leak", leak)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-conversation-") as directory:
            try:
                child = await asyncio.create_subprocess_exec(str(binary), "--conversation", directory, f"ws://127.0.0.1:{port}", str(Path(__file__).resolve().parents[1]/".build/hejo.app/Contents/Resources/Pet"), str(Path(__file__).resolve().parents[1]/".build/task06-automatic.png"),
                                                             stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
                try:
                    output, _ = await asyncio.wait_for(child.communicate(), 40)
                except BaseException:
                    child.kill(); await child.wait(); raise
                print(output.decode(), end="", flush=True)
                print("CONVERSATION_FIXTURE_OBSERVED", observed, errors, flush=True)
                assert child.returncode == 0, "conversation app test failed"
                assert not errors, "fixture assertion failure: " + ",".join(errors)
                assert observed == dict(uploads=2, clicks=1, sends=5, downloads=1, redirect_followed=0), "unexpected transport count"
                assert credential not in Path(directory, "hejo-local.json").read_text()
                print("CONVERSATION_HTTP_WS_PASS", observed, flush=True)
            finally:
                settings = Path(directory, "hejo-local.json")
                if settings.exists():
                    account = json.loads(settings.read_text())["credentialAccount"]
                    args = ["-s", "io.github.hermes-hejo.hejo.gate-token", "-a", account]
                    deleted = subprocess.run(["security", "delete-generic-password", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    absent = subprocess.run(["security", "find-generic-password", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    assert deleted.returncode in (0, 44) and absent.returncode == 44
                    print("CONVERSATION_CREDENTIAL_CLEANUP_OK", flush=True)
    finally:
        await runner.cleanup()


if __name__ == "__main__":
    asyncio.run(main())
