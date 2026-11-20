"""N34-03: real gateway ingress, worker progress and post-delivery cleanup.

Only the model is replaced. Transport, profile routing, turn runner, journal,
callback registration and final delivery run unchanged in a disposable process.
"""
import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import types
import uuid
from functools import wraps


async def child(sandbox):
    from gate.tests.gateway_delivery import isolate, setup
    isolate(sandbox)
    root = Path(os.environ["HERMES_HOME"])
    secondary = setup(root)
    import yaml
    for home in (root, secondary):
        path = home / "config.yaml"
        config = yaml.safe_load(path.read_text())
        config["display"] = {"tool_progress": "all", "tool_progress_grouping": "accumulate",
                             "platforms": {"hejo": {"cleanup_progress": True}}}
        path.write_text(yaml.safe_dump(config))

    sent, edited, flushed = threading.Event(), threading.Event(), threading.Event()
    model_calls = []

    class FakeAgent:
        def __init__(self, **kwargs):
            self.tools = []
            self.tool_progress_callback = kwargs.get("tool_progress_callback")

        def run_conversation(self, message, conversation_history=None, task_id=None, **kwargs):
            model_calls.append(threading.get_ident())
            self.tool_progress_callback("tool.started", "terminal", "fixture first", {})
            assert sent.wait(10), "real progress send did not complete"
            self.tool_progress_callback("tool.started", "terminal", "fixture second", {})
            self.tool_progress_callback("tool.started", "terminal", "fixture third", {})
            assert edited.wait(10), "real progress edit did not complete"
            assert flushed.wait(10), "real progress edit did not reach the journal"
            if "fixture failure" in message:
                return {"final_response": "", "messages": [], "api_calls": 1,
                        "failed": True, "error": "fixture model failure"}
            return {"final_response": "fixture final answer", "messages": [], "api_calls": 1}

    fake = types.ModuleType("run_agent")
    fake.AIAgent = FakeAgent
    sys.modules["run_agent"] = fake
    from gateway import run
    run._resolve_runtime_agent_kwargs = lambda **kwargs: {"api_key": "fixture"}
    from gate.adapter import HejoAdapter
    from gateway.platforms.base import BasePlatformAdapter
    from gateway.run_turn import GatewayTurnMixin

    trace = []

    def record(kind, adapter=None, **fields):
        trace.append({"order": len(trace), "kind": kind,
                      "adapter": getattr(adapter, "_owner_profile", None) or "default", **fields})

    original_send = HejoAdapter.send
    original_edit = HejoAdapter.edit_message
    original_register = HejoAdapter.register_post_delivery_callback
    original_pop = HejoAdapter.pop_post_delivery_callback
    original_fire = BasePlatformAdapter._fire_post_delivery_callback
    original_schedule = GatewayTurnMixin._run_agent_schedule_bubble_cleanup
    original_delete = HejoAdapter.delete_message
    original_record = HejoAdapter._record

    @wraps(original_send)
    async def observe_send(self, *args, **kwargs):
        result = await original_send(self, *args, **kwargs)
        record("send", self, msg_id=result.message_id, success=result.success)
        sent.set()
        return result

    @wraps(original_edit)
    async def observe_edit(self, *args, **kwargs):
        result = await original_edit(self, *args, **kwargs)
        record("edit", self, msg_id=result.message_id, success=result.success,
               finalize=kwargs.get("finalize"))
        edited.set()
        return result

    async def observe_delete(self, chat_id, message_id):
        row = self.journal.message(message_id) if self.journal else None
        result = await original_delete(self, chat_id, message_id)
        record("delete", self, chat=chat_id, msg_id=message_id,
               employee=row.get("employee") if row else None, success=result)
        return result

    async def observe_record(self, frame, *args, **kwargs):
        result = await original_record(self, frame, *args, **kwargs)
        if frame["type"] == "edit" and not frame.get("final"):
            flushed.set()
        return result

    def observe_register(self, key, callback, *, generation=None):
        record("register", self, key=key, generation=generation,
               active_keys=list(self._active_sessions))
        return original_register(self, key, callback, generation=generation)

    def observe_pop(self, key, *, generation=None):
        result = original_pop(self, key, generation=generation)
        record("pop", self, key=key, generation=generation, found=callable(result))
        return result

    async def observe_fire(self, key, event):
        record("fire", self, key=key, generation=getattr(event, "_hermes_run_generation", None))
        return await original_fire(self, key, event)

    def observe_schedule(self, response, adapter, ctx):
        record("schedule", adapter, key=ctx.session_key, generation=ctx.run_generation,
               cleanup=ctx._cleanup_progress, ids=list(ctx._cleanup_msg_ids),
               failed=response.get("failed", False) if isinstance(response, dict) else None)
        return original_schedule(self, response, adapter, ctx)

    HejoAdapter.send = observe_send
    HejoAdapter.edit_message = observe_edit
    HejoAdapter.register_post_delivery_callback = observe_register
    HejoAdapter.pop_post_delivery_callback = observe_pop
    HejoAdapter.delete_message = observe_delete
    HejoAdapter._record = observe_record
    BasePlatformAdapter._fire_post_delivery_callback = observe_fire
    GatewayTurnMixin._run_agent_schedule_bubble_cleanup = observe_schedule
    ready = asyncio.Event()
    original_wait = run.GatewayRunner.wait_for_shutdown

    async def observe_ready(self):
        ready.set()
        await original_wait(self)

    run.GatewayRunner.wait_for_shutdown = observe_ready
    task = asyncio.create_task(run.start_gateway(verbosity=0))
    runner = None
    try:
        async with asyncio.timeout(90):
            while not (ready.is_set() and run._gateway_runner_ref and
                       (runner := run._gateway_runner_ref()) and runner._running):
                if task.done():
                    raise AssertionError(f"gateway ended early: {task.result()}")
                await asyncio.sleep(0.02)
        from aiohttp import ClientSession
        from gateway.config import Platform
        primary = runner.adapters[Platform("hejo")]
        failures = []
        async with ClientSession(trust_env=False) as client:
            ws = await client.ws_connect(f"http://127.0.0.1:{primary.server.port}/v1/ws")
            await ws.send_json({"v": 1, "type": "hello", "device_name": "Fixture",
                                "app_version": "test", "pair_code": primary.auth.pair_code()})
            assert (await ws.receive_json(timeout=5))["type"] == "welcome"
            assert (await ws.receive_json(timeout=5))["type"] == "sync_done"
            for profile, failed in (("default", False), ("beta", False),
                                    ("default", True), ("beta", True)):
                sent.clear(); edited.clear(); flushed.clear()
                thread = str(uuid.uuid4())
                start = primary.journal.head
                trace_start = len(trace)
                await ws.send_json({"v": 1, "type": "send", "id": str(uuid.uuid4()),
                                    "employee": profile, "thread": thread,
                                    "client_msg_id": str(uuid.uuid4()),
                                    "text": "fixture failure" if failed else "fixture request"})
                async with asyncio.timeout(30):
                    while True:
                        rows = [r for r in primary.journal.records if r["seq"] > start]
                        scheduled = [t for t in trace[trace_start:] if t["kind"] == "schedule"]
                        if scheduled and not primary._active_sessions:
                            break
                        await asyncio.sleep(0.02)
                # Cleanup is scheduled onto the loop after post-delivery returns.
                for _ in range(100):
                    if failed or any(r["type"] == "delete" for r in rows):
                        break
                    await asyncio.sleep(0.02)
                    rows = [r for r in primary.journal.records if r["seq"] > start]
                assert len(scheduled) == 1 and scheduled[0]["failed"] is failed
                ids = scheduled[0]["ids"]
                progress = [r for r in rows if r["type"] == "message" and r["msg_id"] in ids]
                finals = [r for r in rows if r["type"] == "message" and r.get("role") == "employee"
                          and r["msg_id"] not in ids]
                assert len(progress) == 1
                edits = [r for r in rows if r["type"] == "edit" and r["msg_id"] == progress[0]["msg_id"]]
                assert len(edits) >= 2 and edits[-1]["final"] is True
                assert len(finals) == 1 and primary.journal.message(finals[0]["msg_id"]) is not None
                if not failed:
                    assert finals[0]["text"] == "fixture final answer"
                deleted = [r for r in rows if r["type"] == "delete"]
                assert all(r["seq"] > finals[0]["seq"] for r in deleted)
                cleaned = all(primary.journal.message(r["msg_id"]) is None for r in progress)
                record("case", profile=profile, failed=failed, cleaned=cleaned,
                       rows=[{k: r[k] for k in ("seq", "type", "msg_id", "final") if k in r} for r in rows])
                if cleaned is failed:
                    failures.append(profile)
                if failed:
                    assert not deleted and all(primary.journal.message(r["msg_id"]) for r in progress)
            await ws.close()
        assert len(model_calls) == 4 and all(t != threading.get_ident() for t in model_calls)
        assert not failures, f"progress retained after final delivery: {failures}"
        print("GATEWAY_PROGRESS_PASS", flush=True)
    finally:
        print("GATEWAY_PROGRESS_TRACE " + json.dumps(trace), flush=True)
        if runner:
            await runner.stop()
        await asyncio.wait_for(task, 40)


def test_real_gateway_progress():
    with tempfile.TemporaryDirectory(prefix="hejo-progress-", dir="/tmp") as directory:
        sandbox = Path(directory).resolve()
        home, root = sandbox / "home", sandbox / "airport"
        home.mkdir(); root.mkdir()
        env = {"PATH": os.defpath, "HOME": str(home), "HERMES_HOME": str(root),
               "TMPDIR": str(sandbox), "XDG_STATE_HOME": str(sandbox / "state"),
               "HERMES_GATEWAY_LOCK_DIR": str(sandbox / "locks"),
               "HERMES_DISABLE_LAZY_INSTALLS": "1", "PYTHONDONTWRITEBYTECODE": "1",
               "PYTHONPATH": os.pathsep.join(sys.path), "NO_COLOR": "1"}
        result = subprocess.run([sys.executable, "-m", "gate.tests.test_gateway_progress", "--child"],
                                cwd=sandbox, env=env, capture_output=True, text=True, timeout=180)
        print(result.stdout)
        print(result.stderr)
        assert result.returncode == 0


if __name__ == "__main__":
    asyncio.run(child(Path(os.environ["HERMES_HOME"]).parent))
