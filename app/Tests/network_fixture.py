"""Temporary loopback gateway; no Hermes home or external service is consulted."""
import asyncio
import json
import pathlib
import secrets
import subprocess
import sys
import tempfile
import time
import uuid

from aiohttp import web
from jsonschema import Draft202012Validator


async def main():
    binary = pathlib.Path(sys.argv[1]).resolve()
    schema = json.loads((pathlib.Path(__file__).resolve().parents[2] / "schemas/hejo-wire-v1.json").read_text())
    validator = Draft202012Validator(schema)
    token = secrets.token_urlsafe(32)
    device_id = str(uuid.uuid4())
    phase = "pair"
    seen = []
    failures = []
    stop_tasks = []
    outage_started = None
    last_recovery = None
    runner = None
    site = None
    port = None

    def validate(frame):
        if not validator.is_valid(frame):
            raise AssertionError("wire fixture violates shared schema")

    async def socket(request):
        nonlocal outage_started, last_recovery
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        try:
            hello = await ws.receive_json()
            validate(hello)
            assert hello["type"] == "hello"
            if phase == "pair":
                assert hello.get("pair_code") == "test_code-12" and hello["since"] == 0
            else:
                assert hello.get("token") == token and hello["since"] == 4
            seen.append((phase, hello["since"]))

            async def send(frame):
                frame = {"v": 1, **frame}
                validate(frame)
                await ws.send_json(frame)

            welcome = dict(type="welcome", device_id=device_id, gate_version="0.1.0", employees=[], head_seq=4)
            if phase == "pair":
                welcome["token"] = token
            await send(welcome)
            if phase == "pair":
                async def record(seq):
                    await send(dict(type="delete", seq=seq, msg_id=str(uuid.uuid4())))
                await record(1)
                await record(1)  # At-least-once duplicate must not be cached twice.
                await record(3)  # The client must discard the gap and ask from applied=1.
                sync = await ws.receive_json(); validate(sync)
                assert sync["type"] == "sync" and sync["since"] == 1
                await record(2); await record(3)
                await send(dict(type="sync_done", ref=sync["id"], through=3, more=True, head_seq=4))
                sync = await ws.receive_json(); validate(sync)
                assert sync["type"] == "sync" and sync["since"] == 3
                await record(4)
                await send(dict(type="sync_done", ref=sync["id"], through=4, more=False, head_seq=4))
                await send(dict(type="ping"))
                pong = await ws.receive_json(); validate(pong); assert pong["type"] == "pong"
            else:
                await send(dict(type="sync_done", ref="hello", through=4, more=False, head_seq=4))
            if phase == "too-large":
                await asyncio.sleep(0.2)
                await ws.close(code=1009)
            elif phase == "error-large":
                await asyncio.sleep(0.2)
                await send(dict(type="error", code="too_large", ref="fixture"))
            elif phase == "outage":
                if outage_started is None:
                    async def outage():
                        nonlocal site, outage_started
                        await asyncio.sleep(0.2)
                        outage_started = time.monotonic()
                        await site.stop()
                        request.transport.abort()  # No close frame: abnormal disconnection.
                        await asyncio.sleep(10)
                        site = web.TCPSite(runner, "127.0.0.1", port)
                        await site.start()
                    stop_tasks.append(asyncio.create_task(outage()))
                else:
                    last_recovery = time.monotonic()
            async for _ in ws:
                pass
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        except Exception as error:
            failures.append(type(error).__name__)
        return ws

    app = web.Application(); app.router.add_get("/v1/ws", socket)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    with tempfile.TemporaryDirectory(prefix="hejo-app-test-") as directory:
        try:
            for phase, mode in [("pair", "pair"), ("resume", "resume"), ("too-large", "too-large"), ("error-large", "too-large"), ("outage", "outage")]:
                child = await asyncio.create_subprocess_exec(str(binary), "--network-" + mode, directory,
                                                             f"ws://127.0.0.1:{port}", stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
                try:
                    stdout, _ = await asyncio.wait_for(child.communicate(), 55)
                except BaseException:
                    child.kill(); await child.wait(); raise
                print(stdout.decode(), end="", flush=True)
                assert child.returncode == 0, "app network test failed"
                assert not failures, "fixture assertions failed: " + ",".join(failures)
                assert token not in pathlib.Path(directory, "hejo-local.json").read_text()
                lines = pathlib.Path(directory, "cache/frames.jsonl").read_text().splitlines()
                assert [json.loads(line)["seq"] for line in lines] == [1, 2, 3, 4]
            assert last_recovery is not None and last_recovery - outage_started < 40
            print("AT-HF-24 PASS: pair/keychain/restart; gap/duplicate/pages/ping PASS")
            print("AT-HF-25 PASS: ten-second outage; recovery within thirty seconds of listener restart")
            print("FRAME_SIZE PASS: 1009 and too_large surfaced; abnormal disconnect recovered")
        finally:
            settings = pathlib.Path(directory, "hejo-local.json")
            if settings.exists():
                account = json.loads(settings.read_text())["credentialAccount"]
                deleted = subprocess.run(["security", "delete-generic-password", "-s", "io.github.hermes-hejo.hejo.gate-token", "-a", account],
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                remaining = subprocess.run(["security", "find-generic-password", "-s", "io.github.hermes-hejo.hejo.gate-token", "-a", account],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
                assert deleted.returncode in (0, 44) and remaining.returncode == 44, "test credential cleanup failed"
                print("TEST_CREDENTIAL_CLEANUP_OK", flush=True)
            await runner.cleanup()
            await asyncio.gather(*stop_tasks, return_exceptions=True)


if __name__ == "__main__":
    asyncio.run(main())
