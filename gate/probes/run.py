"""Launch each candidate in an isolated, real Hermes gateway process."""
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


def setup(mode, root):
    import yaml
    from hermes_cli.profiles import create_profile
    secondary = create_profile("alpha", no_alias=True, no_skills=True)
    for name, home in (("default", root), ("alpha", secondary)):
        plugin = home / "plugins" / "hejo"
        plugin.mkdir(parents=True, exist_ok=True)
        (plugin / "plugin.yaml").write_text("name: hejo\nkind: platform\nversion: 1.0.0\n")
        (plugin / "__init__.py").write_text("from gate.probes.candidates import register\n")
        platforms = {"probe_peer": {"enabled": True, "token": f"fixture-{name}"}}
        platforms["hejo"] = {"enabled": name == "default" or mode == "A",
                "home_channel": {"platform": "hejo", "chat_id": "alpha", "name": "Fixture",
                                 "thread_id": "00000000-0000-4000-8000-000000000003"},
                "extra": {"port": 0, "listen": ["127.0.0.1"], "allowed_users": ["owner"]}}
        config = {"plugins": {"enabled": ["hejo"]},
                  "gateway": {"multiplex_profiles": True, "platforms": platforms},
                  "agent": {"gateway_startup_warmup_timeout": 0},
                  "cron": {"wrap_response": False}}
        (home / "config.yaml").write_text(yaml.safe_dump(config))
    return secondary


async def exercise(mode, runner, secondary):
    from aiohttp import ClientSession
    from gate.probes import candidates
    from gateway.config import Platform
    from gateway.run import _profile_runtime_scope
    from tools.send_message_tool import send_message_tool
    from cron.scheduler_delivery import _resolve_delivery_targets, _deliver_result
    import psutil
    primary = runner.adapters[Platform("hejo")]
    own = runner._profile_adapters["alpha"]
    peer = own[Platform("probe_peer")]
    primary_peer = runner.adapters[Platform("probe_peer")]
    listener_ports = [c.laddr.port for c in psutil.Process().net_connections(kind="tcp")
                      if c.status == psutil.CONN_LISTEN]
    assert listener_ports == [primary.server.port], listener_ports
    assert primary.is_connected and peer.is_connected
    assert (Platform("hejo") in own) == (mode == "A")
    before = (id(peer), list(peer.sent))
    primary_peer_before = (id(primary_peer), list(primary_peer.sent))
    results = {"mode": mode, "startup": True, "tcp_listeners": len(listener_ports),
               "secondary_platforms": sorted(p.value for p in own)}
    async with ClientSession(trust_env=False) as client:
        ws = await client.ws_connect(f"http://127.0.0.1:{primary.server.port}/v1/ws")
        await ws.send_json({"v": 1, "type": "hello", "pair_code": primary.auth.pair_code(),
                            "device_name": "Probe", "app_version": "probe"})
        assert (await ws.receive_json(timeout=5))["type"] == "welcome"
        assert (await ws.receive_json(timeout=5))["type"] == "sync_done"
        with _profile_runtime_scope(secondary, hydrate_secrets=False):
            results["send_message"] = json.loads(await asyncio.to_thread(
                send_message_tool, {"target": "hejo:alpha", "message": "probe direct"}))
            job = {"id": "fixture-job", "name": "Fixture report", "deliver": "hejo",
                   "origin": {"platform": "hejo", "chat_id": "alpha", "chat_type": "dm",
                              "thread_id": "00000000-0000-4000-8000-000000000003"}}
            results["cron_targets"] = _resolve_delivery_targets(job)
            results["cron_error"] = await asyncio.to_thread(
                _deliver_result, job, "probe scheduled", own, asyncio.get_running_loop())
        received = []
        for _ in range(2 if mode == "A" else 0):
            frame = await ws.receive_json(timeout=5)
            assert frame["type"] == "message" and frame["employee"] == "alpha"
            assert frame["role"] == "employee"
            received.append({k: frame[k] for k in ("employee", "thread", "text")})
        results["received"] = received
        disk_records = [json.loads(line) for path in sorted(primary.journal.path.glob("*.jsonl"))
                        for line in path.read_text().splitlines()]
        assert disk_records == primary.journal.records
        results["journal"] = [{k: r[k] for k in ("employee", "thread", "text")}
                              for r in disk_records if r.get("type") == "message"]
        assert results["journal"] == received
        if mode == "A":
            assert results["send_message"].get("success") and results["cron_error"] is None
            assert len(received) == 2 and received[1]["text"] == "probe scheduled"
            assert received[1]["thread"] == job["origin"]["thread_id"]
        else:
            assert results["send_message"].get("error") and results["cron_error"]
            assert not candidates.standalone_calls
        await ws.close()
    assert before == (id(own[Platform("probe_peer")]), peer.sent)
    assert peer.is_connected
    with _profile_runtime_scope(secondary, hydrate_secrets=False):
        peer_result = await asyncio.to_thread(send_message_tool, {
            "target": "probe_peer:fixture-room", "message": "peer control"})
    assert json.loads(peer_result).get("success"), peer_result
    assert peer.sent == [("fixture-room", "peer control")]
    assert primary_peer_before == (id(runner.adapters[Platform("probe_peer")]), primary_peer.sent)
    assert primary_peer.is_connected
    results["other_platform"] = "same adapter, zero hejo side effects, control send succeeds"
    results["standalone_calls"] = list(candidates.standalone_calls)
    return results


async def child(mode, sandbox):
    isolate(sandbox)
    secondary = setup(mode, Path(os.environ["HERMES_HOME"]))
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
                if ready.is_set() and runner and runner._running and runner._profile_adapters.get("alpha"):
                    break
                await asyncio.sleep(0.05)
        results = await exercise(mode, runner, secondary)
        results["duplicate_checks"] = checks
        assert checks and not any(c["refused"] for c in checks)
        print("PROBE_RESULT " + json.dumps(results, ensure_ascii=False), flush=True)
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
    parser.add_argument("--mode", choices=["A", "B"], required=True)
    parser.add_argument("--child", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.child:
        asyncio.run(child(args.mode, Path(os.environ["HEJO_PROBE_SANDBOX"]).resolve()))
        return
    # sys.path already contains the caller-provided Hermes source and optional local dependencies.
    with tempfile.TemporaryDirectory(prefix="hejo-probe-", dir=os.environ.get("HEJO_PROBE_TMPDIR")) as directory:
        sandbox = Path(directory).resolve()
        home = sandbox / "home"
        root = home / ".hermes"
        root.mkdir(parents=True)
        env = {"PATH": os.defpath, "HOME": str(home), "HERMES_HOME": str(root),
               "TMPDIR": str(sandbox), "XDG_STATE_HOME": str(sandbox / "state"),
               "HERMES_GATEWAY_LOCK_DIR": str(sandbox / "locks"),
               "HEJO_PROBE_SANDBOX": str(sandbox), "HEJO_PROBE_MODE": args.mode,
               "HERMES_DISABLE_LAZY_INSTALLS": "1",
               "PYTHONDONTWRITEBYTECODE": "1", "PYTHONPATH": os.pathsep.join(sys.path),
               "NO_COLOR": "1"}
        completed = subprocess.run([sys.executable, "-m", "gate.probes.run",
                                    "--mode", args.mode, "--child"],
                                   cwd=sandbox, env=env, timeout=180)
        raise SystemExit(completed.returncode)


if __name__ == "__main__":
    main()
