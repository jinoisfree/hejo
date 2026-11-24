"""GD-T17: loopback-only fake gate, real desktop transport and AppKit controls."""
import asyncio
import json
import os
import pathlib
import sys
import tempfile
import uuid

from aiohttp import web
from jsonschema import Draft202012Validator


async def main():
    binary = pathlib.Path(sys.argv[1]).resolve()
    evidence = pathlib.Path(sys.argv[2]).resolve()
    evidence.mkdir(parents=True, exist_ok=True)
    close_only = len(sys.argv) > 3 and sys.argv[3] == "close"
    schema = pathlib.Path(__file__).resolve().parents[2] / "schemas/hejo-wire-v1.json"
    contract = json.loads(schema.read_text())
    client_validator = Draft202012Validator(dict(contract, oneOf=[{"$ref": "#/$defs/clientFrame"}]))
    server_validator = Draft202012Validator(dict(contract, oneOf=[{"$ref": "#/$defs/serverFrame"}]))
    old = "old" + "@example.test"
    new = "new" + "@example.test"
    account = None if close_only else old
    frames, failures, sessions = [], [], {}
    starts = 0
    polled = {}
    workers = []
    late_cancel = asyncio.Event()
    late_sent = False

    def document():
        item = dict(id="team:google-personal", service="google", label="Google 개인",
                    group="account", state="connected" if account else "not_connected",
                    reason="GOOGLE_VERIFIED" if account else "NOT_CONNECTED",
                    checked_at="2026-01-01T00:00:00Z", scope="personal",
                    disconnect_mode="forget_account", capabilities=[], rules=[])
        if account:
            item["account"] = account
        item["actions"] = [dict(id="account_disconnect" if account else "account_connect",
                                label="연결 해제" if account else "연결", primary=True)]
        return dict(schema="hermes-connections/1", checked_at="2026-01-01T00:00:00Z",
                    agents=[dict(profile="alpha", display_name="Synthetic", connections=[item])])

    async def socket(request):
        nonlocal account, starts, late_sent
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        async def send(value):
            frame = dict(v=1, **value)
            server_validator.validate(frame)
            await ws.send_json(frame)
        try:
            hello = await ws.receive_json()
            client_validator.validate(hello)
            assert hello["type"] == "hello"
            if hello.get("pair_code") != "test_code-12":
                assert close_only and hello.get("token") == "synthetic-gate-token"
                while not (evidence/"allow-reconnect").exists():
                    await asyncio.sleep(0.01)
            await send(dict(type="welcome", device_id=str(uuid.uuid4()), token="synthetic-gate-token",
                            gate_version="0.1.0", employees=[dict(id="alpha", name="Synthetic", aliases=[], avatar=None)], head_seq=0))
            await send(dict(type="sync_done", ref="hello", through=0, more=False, head_seq=0))
            async for msg in ws:
                frame = json.loads(msg.data)
                client_validator.validate(frame)
                if frame["type"] in ("pong", "telegram"):
                    continue
                frames.append(frame)
                if frame["type"] == "connections":
                    await send(dict(type="connections_status", ref=frame["id"], document=document()))
                    if late_sent:
                        (evidence/"late-refresh-sent").write_text("sent")
                    continue
                assert frame["type"] == "connection_action" and frame["profile"] == "alpha"
                action = frame["action"]
                reply = dict(outcome="pending")
                if action == "job_status":
                    reply = dict(outcome="done")
                elif action == "account_disconnect":
                    assert account and frame["connection"] == "team:google-personal"
                    assert frame["reauth"] is True and frame["values"] == dict(disconnect_mode="forget_account")
                    account = None
                    reply = dict(outcome="done", reason="DISCONNECTED")
                elif action == "account_connect":
                    assert frame["reauth"] is True and frame["connection"] == "team:google-personal"
                    starts += 1
                    modes = {1: "close", 2: "offline-close", 3: "cancel-ok", 4: "late-close"} if close_only else {1: "success", 2: "cancel-fails", 3: "expires", 4: "close", 5: "cancel-ok"}
                    mode = modes[starts]
                    sid = "synthetic-session-" + str(starts)
                    sessions[sid] = mode
                    reply = dict(outcome="pending", session_id=sid)
                    if mode == "offline-close":
                        async def disconnect():
                            while not (evidence/"disconnect-requested").exists():
                                await asyncio.sleep(0.01)
                            await ws.close(code=1001)
                        workers.append(asyncio.create_task(disconnect()))
                elif action == "oauth_poll":
                    assert frame["reauth"] is False
                    sid = frame["connection"]
                    mode = sessions[sid]
                    polled[sid] = polled.get(sid, 0) + 1
                    if mode == "late-close":
                        ref = frame["id"]
                        async def late_reply():
                            nonlocal late_sent
                            (evidence/"late-poll-ready").write_text("held")
                            await late_cancel.wait()
                            await asyncio.sleep(0.1)
                            await send(dict(type="connection_result", ref=ref, reply=dict(status="approved")))
                            late_sent = True
                            (evidence/"late-response-sent").write_text("sent")
                        workers.append(asyncio.create_task(late_reply()))
                        continue
                    if mode == "success":
                        # Leave time for the real authentication sheet to be presented and observed.
                        await asyncio.sleep(0.25)
                        account = new
                        reply = dict(status="approved")
                    elif mode == "expires":
                        reply = dict(status="pending")
                elif action == "account_cancel":
                    assert frame["reauth"] is False
                    mode = sessions[frame["connection"]]
                    if mode == "late-close":
                        late_cancel.set()
                    reply = dict(outcome="failed", reason="CANCEL_UNCONFIRMED") if mode == "cancel-fails" else dict(outcome="done", reason="CANCELLED")
                else:
                    raise AssertionError("unexpected connection action")
                await send(dict(type="connection_result", ref=frame["id"], reply=reply))
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        except Exception as error:
            failures.append(type(error).__name__)
            print("FIXTURE_ERROR", type(error).__name__, str(error)[:1600], flush=True)
        return ws

    app = web.Application(); app.router.add_get("/v1/ws", socket)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-google-ui-") as area:
            env = dict(os.environ, HOME=area, HERMES_HOME=str(pathlib.Path(area)/"hermes"), HERMES_ROOT=str(pathlib.Path(area)/"hermes"))
            pathlib.Path(env["HERMES_HOME"]).mkdir()
            argv = [str(binary), "--google-disconnect-close-ui" if close_only else "--google-disconnect-ui", area, f"ws://127.0.0.1:{port}", str(evidence)]
            print(json.dumps(dict(argv=argv, cwd=os.getcwd(), environment={k:env[k] for k in ("HOME", "HERMES_HOME", "HERMES_ROOT", "HEJO_PYTHON")}), ensure_ascii=False), flush=True)
            child = await asyncio.create_subprocess_exec(*argv, env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
            try:
                output, _ = await asyncio.wait_for(child.communicate(), 90)
            except BaseException:
                child.kill(); await child.wait(); raise
            print(output.decode(), end="", flush=True)
            (evidence/"frames.json").write_text(json.dumps(frames, indent=2)+"\n")
            print(json.dumps(dict(childExitCode=child.returncode, fixtureErrors=failures, starts=starts)), flush=True)
            assert child.returncode == 0 and not failures
            cancels = [f["connection"] for f in frames if f.get("action") == "account_cancel"]
            if close_only:
                assert starts == 4
                assert cancels == ["synthetic-session-1", "synthetic-session-3", "synthetic-session-4"]
                assert (evidence/"late-refresh-sent").exists()
                assert not any(f.get("action") == "account_disconnect" for f in frames)
            else:
                assert starts == 5
                assert polled["synthetic-session-3"] == 450
                assert cancels == ["synthetic-session-2", "synthetic-session-3", "synthetic-session-4", "synthetic-session-5"]
                assert len([f for f in frames if f.get("action") == "account_disconnect"]) == 2
            assert account is None
            print("GD-T17 LOOPBACK FRAME CONTRACT PASS", flush=True)
    finally:
        for worker in workers:
            worker.cancel()
        await asyncio.gather(*workers, return_exceptions=True)
        await runner.cleanup()


if __name__ == "__main__":
    asyncio.run(main())
