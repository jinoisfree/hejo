"""TASK-01 load diagnostic; real GateServer websocket, Journal and AppKit client.

Existing dependencies only. Provide HEJO_PYTHON/PYTHONPATH from the local test
setup. No Hermes runner, external transport or operational home is started.
"""
import argparse
import asyncio
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tempfile
from types import SimpleNamespace
import uuid


def digest(data):
    return hashlib.sha256(data).hexdigest()


def isolation_profile(root, executable):
    # Foundation's createFile uses an item-replacement directory obtained through
    # Darwin confstr, ignoring TMPDIR. Permit only this diagnostic's NSIRD prefix.
    temporary = Path(subprocess.check_output(["getconf", "DARWIN_USER_TEMP_DIR"], text=True).strip()).resolve() / "TemporaryItems"
    replacement = "^" + re.escape(str(temporary)) + "/NSIRD_" + re.escape(executable) + "_[^/]+(/|$)"
    return ('(version 1)(allow default)(deny file-write*)'
        + '(allow file-write* (subpath ' + json.dumps(str(root)) + ')'
        + ' (literal ' + json.dumps(str(temporary)) + ') (regex ' + json.dumps(replacement) + '))'
        + '(deny network-outbound)(allow network-outbound (remote ip "localhost:*"))'
        + '(deny file-read* (subpath ' + json.dumps(str(Path.home() / "Library/Application Support/hejo")) + '))')


def storage_probe(binary, output):
    evidence = []
    for repaired in (False, True):
        with tempfile.TemporaryDirectory(prefix="hejo-history-probe-") as directory:
            root = Path(directory).resolve(); profile = root / "probe.sb"
            policy = isolation_profile(root, binary.name) if repaired else ('(version 1)(allow default)(deny file-write*)(allow file-write* (subpath ' + json.dumps(str(root)) + '))')
            profile.write_text(policy)
            run = subprocess.run(["/usr/bin/sandbox-exec", "-f", str(profile), str(binary), str(root)], capture_output=True, text=True)
            lines = [line for line in run.stdout.splitlines() if line.startswith(("createFile=", "dataWrite=", "plainCreate=", "posixOpen="))]
            assert run.returncode == 0 and ("createFile=true" if repaired else "createFile=false") in lines
            assert "dataWrite=true" in lines
            with tempfile.TemporaryDirectory(prefix="hejo-history-denied-") as denied:
                path = Path(denied) / "probe"
                negative = subprocess.run(["/usr/bin/sandbox-exec", "-f", str(profile), "/bin/sh", "-c", 'echo probe > "$1"', "guard", str(path)], capture_output=True)
                assert negative.returncode != 0 and not path.exists()
            evidence.append(dict(repaired=repaired, exitCode=run.returncode, observations=lines, outsideWriteExit=negative.returncode, outsideWriteDenied=True))
    (output / "storage-probe.json").write_text(json.dumps(evidence, indent=2) + "\n")
    return 0


def fixture(count, long_thread):
    # Last 1,000 messages are identical across the two history sizes.
    rows = []
    for index in range(count):
        ordinal = index - count + 10000
        rows.append(dict(v=1, type="message", seq=index + 1,
            msg_id=str(uuid.UUID(int=ordinal + 10001)), employee="alpha",
            thread=str(uuid.UUID(int=1 if long_thread else ordinal + 20001)),
            role="employee", text=f"기준 글 {ordinal}", files=[], buttons=[],
            reply_state=None, ts="2026-01-01T00:00:00Z"))
    return rows


async def sample(binary, count, long_thread, semantic=False):
    from aiohttp import WSMsgType, web
    # HERMES_HOME is set before importing any gate dependency.
    with tempfile.TemporaryDirectory(prefix="hejo-history-") as directory:
        root = Path(directory).resolve()
        os.environ["HERMES_HOME"] = str(root / "airport")
        from gate.auth import AuthStore
        from gate.journal import Journal
        from gate.server import GateServer
        import gate.server as server_module
        journal = Journal(os.environ["HERMES_HOME"])
        journal.path.mkdir(parents=True)
        if semantic:
            from .history_baseline_semantics import rows as semantic_rows
            rows = semantic_rows()
        else:
            rows = fixture(count, long_thread)
        raw = b"".join((json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n").encode() for row in rows)
        (journal.path / "2026-01.jsonl").write_bytes(raw)
        journal.open()
        auth = AuthStore(os.environ["HERMES_HOME"])
        queries = {}
        class DiscordStatus:
            async def command(self, frame, conn):
                assert frame["type"] == "discord"
                queries[conn] = queries.get(conn, 0) + 1
                await conn.send(dict(v=1, type="discord_status", ref=frame["id"],
                                     platform_ready=False, paired=False, enabled=False,
                                     channel_problem=False, core_open=False))
        adapter = SimpleNamespace(journal=journal, auth=auth,
            hub=SimpleNamespace(enabled=False), discord=DiscordStatus(),
            employees=lambda: [dict(id=name, name=name.title(), aliases=[], avatar=None) for name in ("alpha", "beta", "gamma")])
        wire = dict(frames=0, bytes=0)
        original_socket = server_module.BoundedWebSocket
        welcomed = set()
        unexpected = []

        class MeasuredSocket(original_socket):
            async def receive(self, *args, **kwargs):
                message = await super().receive(*args, **kwargs)
                if message.type == WSMsgType.TEXT:
                    frame = json.loads(message.data)
                    if frame["type"] not in {"hello", "sync", "pong", "discord"}:
                        unexpected.append(frame["type"])
                return message

            async def send_str(self, data, compress=None):
                await super().send_str(data, compress=compress)
                if self not in welcomed and json.loads(data)["type"] == "welcome":
                    welcomed.add(self)
                wire["frames"] += 1
                wire["bytes"] += len(data.encode("utf-8"))
        server_module.BoundedWebSocket = MeasuredSocket
        server = GateServer(adapter)
        # Register the actual websocket handler, without operational local ingress
        # or platform-maintenance workers. No server logic is copied or replaced.
        app = web.Application(); app.router.add_get("/v1/ws", server.websocket)
        runner = web.AppRunner(app, access_log=None); await runner.setup()
        site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
        port = site._server.sockets[0].getsockname()[1]
        config = root / "config.json"
        config.write_text(json.dumps(dict(fixture="history-baseline", count=count, semantic=semantic, address=f"ws://127.0.0.1:{port}", code=auth.pair_code())))
        config.chmod(0o600)
        # Enforce the app's write boundary independently of path injection.
        # AppKit may attempt denied preference/cache writes; they cannot escape.
        profile = root / "isolation.sb"
        profile.write_text(isolation_profile(root, binary.name))
        allowed_probe = root / "allowed-probe"
        guard = await asyncio.create_subprocess_exec("/usr/bin/sandbox-exec", "-f", str(profile),
            "/bin/sh", "-c", 'echo probe > "$1"', "history-guard", str(allowed_probe),
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
        assert await guard.wait() == 0 and allowed_probe.read_text() == "probe\n", "sandbox profile invalid"
        with tempfile.TemporaryDirectory(prefix="hejo-history-forbidden-") as forbidden:
            probe = Path(forbidden) / "must-not-exist"
            guard = await asyncio.create_subprocess_exec("/usr/bin/sandbox-exec", "-f", str(profile),
                "/bin/sh", "-c", 'echo probe > "$1"', "history-guard", str(probe),
                stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
            guard_code = await guard.wait()
            assert guard_code != 0 and not probe.exists(), "sandbox write boundary not enforced"
        child = None
        try:
            child = await asyncio.create_subprocess_exec("/usr/bin/sandbox-exec", "-f", str(profile), str(binary), str(config), env={**os.environ, "TMPDIR": str(root) + "/"}, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
            try:
                stdout, stderr = await asyncio.wait_for(child.communicate(), 120)
            except asyncio.TimeoutError:
                child.kill(); await child.wait()
                return dict(status="timeout", limitSeconds=120, inputSHA256=digest(raw))
            if child.returncode:
                print(stdout.decode(errors="replace"), flush=True)
                print(stderr.decode(errors="replace"), flush=True)
                # Raw stderr may include host paths; keep only a digest in public evidence.
                return dict(status="failed", exitCode=child.returncode, stderrSHA256=digest(stderr), stdoutSHA256=digest(stdout), inputSHA256=digest(raw))
            assert not unexpected, unexpected
            assert welcomed and {conn.ws: count for conn, count in queries.items()} == dict.fromkeys(welcomed, 1)
            result = json.loads((root / "result.json").read_text())
            result.update(status="completed", exitCode=0, inputSHA256=digest(raw), transmittedJSON=wire, outsideWriteDenied=True, guardExitCode=guard_code)
            assert (journal.path / "2026-01.jsonl").read_bytes() == raw
            assert result["applied"] == len(rows)
            if not semantic: assert result["messages"] == count
            return result
        finally:
            if child and child.returncode is None:
                child.kill(); await child.wait()
            await server.stop(); await runner.cleanup(); journal.close()
            server_module.BoundedWebSocket = original_socket


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--storage-probe", action="store_true", help="diagnose Foundation replacement paths without running loads")
    parser.add_argument("--semantic", action="store_true", help="run only the small deterministic fixture twice; never load tests")
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    binary = args.binary.resolve()
    if args.storage_probe: return storage_probe(binary, args.output)
    report = dict(binarySHA256=digest(binary.read_bytes()), python=platform.python_version(),
                  os=platform.mac_ver()[0], architecture=platform.machine(), samples=[])
    if args.semantic:
        for iteration in range(2):
            report["samples"].append(await sample(binary, 0, False, semantic=True))
        complete = all(s["status"] == "completed" for s in report["samples"])
        report["identical"] = complete and report["samples"][0]["semantic"] == report["samples"][1]["semantic"]
        report["invariantsVerified"] = False
        # Preserve this run even if an independent fixture assertion fails below.
        (args.output / "semantic.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        if complete:
            from .history_baseline_semantics import identifier
            for sample_result in report["samples"]:
                snapshots = {entry["label"]: entry for entry in sample_result["semantic"]}
                assert not snapshots["before-member-fetch"]["memberFetched"] and snapshots["after-member-fetch"]["memberFetched"]
                assert "beta" in snapshots["mute"]["muted"]
                assert any(m["id"] == identifier(9) and m["check"] for m in snapshots["checked"]["messages"])
                assert any(m["id"] == identifier(1) and m["confirmed"] for m in snapshots["confirmed"]["messages"])
                assert identifier(102) not in snapshots["24-hour-boundary"]["roomOrder"]
                assert all(m["id"] != identifier(7) for m in snapshots["24-hour-boundary"]["messages"])
                assert "link-opened" in snapshots and "appkit-input" in snapshots
                assert all(t["linkRoundTrip"] for t in snapshots["home"]["threads"])
            report["invariantsVerified"] = True
        (args.output / "semantic.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
        return 0 if report["identical"] else 1
    previous = args.output / "load.json"
    if previous.exists() and any(s["status"] == "timeout" for s in json.loads(previous.read_text())["samples"]):
        parser.error("load measurement stopped after timeout; planning review required")
    stopped = False
    for count, long_thread in ((1000, False), (10000, False), (10000, True)):
        for iteration in range(6):
            entry = dict(count=count, longThread=long_thread, warmup=iteration == 0, iteration=iteration)
            if stopped:
                entry["status"] = "not_run"
            else:
                entry.update(await sample(binary, count, long_thread))
                stopped = entry["status"] != "completed"
            report["samples"].append(entry)
            (args.output / "load.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    return 1 if stopped else 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
