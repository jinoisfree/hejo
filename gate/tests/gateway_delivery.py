"""AT-HF-22: production plugin in a real, isolated multiplex gateway process."""
import argparse
import asyncio
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def isolate(sandbox):
    """Refuse operational secrets, writes outside the sandbox, and external sockets."""
    def inside(path):
        return Path(path).resolve().is_relative_to(sandbox)

    def audit(event, args):
        if event == "open" and isinstance(args[0], (str, bytes, os.PathLike)):
            path = Path(os.fsdecode(args[0]))
            if not inside(path):
                if path.name.startswith(".env") or path.name.endswith(".env") or path.name == "auth.json" or "token" in path.name.lower() and path.suffix == ".json":
                    raise PermissionError("probe refuses non-fixture secret file")
                if args[2] & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC):
                    if path != Path(os.devnull):
                        raise PermissionError("probe refuses non-fixture write")
        elif event == "sqlite3.connect" and not inside(args[0]):
            raise PermissionError("probe refuses non-fixture database")
        elif event in {"socket.connect", "socket.bind"}:
            address = args[1]
            if isinstance(address, tuple) and not ipaddress.ip_address(address[0]).is_loopback:
                raise PermissionError("probe refuses external socket")
        elif event == "socket.getaddrinfo":
            if args[0] not in {"localhost", "127.0.0.1", "::1", None}:
                raise PermissionError("probe refuses external DNS")
    sys.addaudithook(audit)


def setup(root):
    import yaml
    from hermes_cli.profiles import create_profile
    secondary = create_profile("beta", no_alias=True, no_skills=True)
    for name, home in (("default", root), ("beta", secondary)):
        plugin = home / "plugins" / "hejo"
        plugin.mkdir(parents=True, exist_ok=True)
        (plugin / "plugin.yaml").write_text("name: hejo\nkind: platform\nversion: 1.0.0\n")
        (plugin / "__init__.py").write_text("from gate import register as gate_register\nfrom gate.tests.gateway_delivery import register_peer\ndef register(ctx):\n    gate_register(ctx)\n    register_peer(ctx)\n")
        extra = ({"port": 0, "listen": ["127.0.0.1"], "allowed_users": ["owner"]}
                 if name == "default" else {"role": "forwarder"})
        platforms = {"probe_peer": {"enabled": True, "token": f"fixture-{name}"},
            "hejo": {"enabled": True, "home_channel": {"platform": "hejo", "chat_id": name, "name": "Fixture"}, "extra": extra}}
        config = {"plugins": {"enabled": ["hejo"]},
                  "gateway": {"multiplex_profiles": True, "platforms": platforms},
                  "agent": {"gateway_startup_warmup_timeout": 0},
                  "cron": {"wrap_response": False}}
        (home / "config.yaml").write_text(yaml.safe_dump(config))
    return secondary


def register_peer(ctx):
    from gateway.config import Platform
    from gateway.platforms.base import BasePlatformAdapter, SendResult
    class Peer(BasePlatformAdapter):
        def __init__(self, config):
            super().__init__(config, Platform("probe_peer"))
            self.sent = []
        async def connect(self, *, is_reconnect=False):
            self._mark_connected()
            return True
        async def disconnect(self):
            self._mark_disconnected()
        async def send(self, chat_id, content, reply_to=None, metadata=None):
            self.sent.append(content)
            return SendResult(success=True, message_id="fixture-peer")
        async def get_chat_info(self, chat_id):
            return {"name": "Fixture", "type": "dm"}
    ctx.register_platform(name="probe_peer", label="Fixture peer", adapter_factory=Peer,
                          check_fn=lambda: True, is_connected=lambda config: config.enabled)


async def exercise(runner, secondary):
    from aiohttp import ClientSession
    from gateway.config import Platform
    from gateway.run import _profile_runtime_scope
    from tools.send_message_tool import send_message_tool
    from cron.scheduler_delivery import _resolve_delivery_targets, _deliver_result
    import psutil
    primary = runner.adapters[Platform("hejo")]
    own = runner._profile_adapters["beta"]
    peers = [runner.adapters[Platform("probe_peer")], own[Platform("probe_peer")]]
    listeners = [c.laddr.port for c in psutil.Process().net_connections(kind="tcp") if c.status == psutil.CONN_LISTEN]
    assert listeners == [primary.server.port]
    assert own[Platform("hejo")].is_connected
    assert own[Platform("hejo")].server is None and own[Platform("hejo")].journal is None
    async with ClientSession(trust_env=False) as client:
        async def open_socket(**hello):
            ws = await client.ws_connect(f"http://127.0.0.1:{primary.server.port}/v1/ws")
            await ws.send_json({"v": 1, "type": "hello", "device_name": "Fixture", "app_version": "test", **hello})
            return ws, await ws.receive_json(timeout=5)
        ws, welcome = await open_socket(pair_code=primary.auth.pair_code())
        assert welcome["type"] == "welcome"
        assert (await ws.receive_json(timeout=5))["type"] == "sync_done"
        loop = asyncio.get_running_loop()
        async def deliver(text, scheduled):
            with _profile_runtime_scope(secondary, hydrate_secrets=False):
                if scheduled:
                    job = {"id": "fixture-job", "name": "Fixture", "deliver": "hejo"}
                    target = _resolve_delivery_targets(job)
                    assert target[0]["chat_id"] == "beta" and not target[0].get("thread_id")
                    error = await asyncio.to_thread(_deliver_result, job, text, own, loop)
                    assert error is None, error
                else:
                    result = json.loads(await asyncio.to_thread(send_message_tool, {"target": "hejo:beta", "message": text}))
                    assert result.get("success"), result
        await deliver("direct online", False)
        await deliver("scheduled online", True)
        online = [await ws.receive_json(timeout=5) for _ in range(2)]
        assert [r["text"] for r in online] == ["direct online", "scheduled online"]
        for row in online:
            assert row["employee"] == "beta" and row["type"] == "message"
        since = online[-1]["seq"]
        await ws.close()
        await deliver("scheduled offline", True)
        await deliver("direct offline", False)
        ws, welcome = await open_socket(token=welcome["token"], since=since)
        replay = [await ws.receive_json(timeout=5) for _ in range(2)]
        done = await ws.receive_json(timeout=5)
        assert done["type"] == "sync_done" and done["more"] is False
        assert [r["text"] for r in replay] == ["scheduled offline", "direct offline"]
        rows = online + replay
        assert all(r["employee"] == "beta" for r in rows)
        assert [r["seq"] for r in rows] == [1, 2, 3, 4]
        assert len({r["thread"] for r in rows}) == 4
        import uuid
        for row in rows:
            assert str(uuid.UUID(row["thread"])) == row["thread"]
        disk = [json.loads(line) for p in primary.journal.path.glob("*.jsonl") for line in p.read_text().splitlines()]
        assert [{k: r[k] for k in ("employee", "thread", "text")} for r in disk] == [
            {k: r[k] for k in ("employee", "thread", "text")} for r in rows]
        assert all(p.is_connected and not p.sent for p in peers)
        await ws.close()
    return {"acceptance": "AT-HF-22", "tcp_listeners": len(listeners), "delivered": 4,
            "new_threads": 4, "offline_replayed": 2, "employee": "beta", "other_platform_sends": 0}


async def child(sandbox):
    isolate(sandbox)
    secondary = setup(Path(os.environ["HERMES_HOME"]))
    from gateway import run
    checks = []
    original = run.GatewayRunner._refuse_duplicate_claim

    def observe(self, claim, claimed, profile_name, platform, kind, **kwargs):
        refused = original(self, claim, claimed, profile_name, platform, kind, **kwargs)
        checks.append({"profile": profile_name, "platform": platform.value,
                       "kind": kind, "has_claim": claim is not None, "refused": refused})
        return refused

    # Observation only: the real duplicate check and the full start_gateway lifecycle run.
    run.GatewayRunner._refuse_duplicate_claim = observe
    ready = asyncio.Event()
    original_wait = run.GatewayRunner.wait_for_shutdown

    async def observe_ready(self):
        ready.set()
        await original_wait(self)

    run.GatewayRunner.wait_for_shutdown = observe_ready
    task = asyncio.create_task(run.start_gateway(verbosity=1))
    runner = None
    try:
        async with asyncio.timeout(90):
            while True:
                runner = run._gateway_runner_ref()
                if task.done():
                    raise RuntimeError(f"gateway ended before probe: {task.result()}")
                if ready.is_set() and runner and runner._running and runner._profile_adapters.get("beta"):
                    break
                await asyncio.sleep(0.05)
        results = await exercise(runner, secondary)
        results["duplicate_checks"] = checks
        assert checks and not any(c["refused"] for c in checks)
        print("ACCEPTANCE_RESULT " + json.dumps(results, ensure_ascii=False), flush=True)
    except BaseException:
        import traceback
        traceback.print_exc()
        raise
    finally:
        if runner:
            await runner.stop()
        verdict = await asyncio.wait_for(task, 40)
        assert verdict is True
        print("GATEWAY_EXIT clean", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--child", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.child:
        asyncio.run(child(Path(os.environ["HEJO_GATE_TEST_SANDBOX"]).resolve()))
        return
    # sys.path already contains the caller-provided Hermes source and optional local dependencies.
    with tempfile.TemporaryDirectory(prefix="hejo-gateway-", dir=os.environ.get("HEJO_GATE_TEST_TMPDIR") or str(Path(os.devnull).parent.parent / "tmp")) as directory:
        sandbox = Path(directory).resolve()
        home = sandbox / "home"
        root = sandbox / "airport"
        home.mkdir()
        root.mkdir(parents=True)
        env = {"PATH": os.defpath, "HOME": str(home), "HERMES_HOME": str(root),
               "TMPDIR": str(sandbox), "XDG_STATE_HOME": str(sandbox / "state"),
               "HERMES_GATEWAY_LOCK_DIR": str(sandbox / "locks"),
               "HEJO_GATE_TEST_SANDBOX": str(sandbox),
               "HERMES_DISABLE_LAZY_INSTALLS": "1",
               "PYTHONDONTWRITEBYTECODE": "1", "PYTHONPATH": os.pathsep.join(sys.path),
               "NO_COLOR": "1"}
        completed = subprocess.run([sys.executable, "-m", "gate.tests.gateway_delivery",
                                    "--child"],
                                   cwd=sandbox, env=env, timeout=180)
        raise SystemExit(completed.returncode)


if __name__ == "__main__":
    main()
