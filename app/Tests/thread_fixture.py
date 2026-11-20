from legacy_feature_fixture import reject_imessage
"""AT75/76 loopback client controls; external Hermes and journal are covered by gate tests."""
import asyncio
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid
from aiohttp import web
from jsonschema import Draft202012Validator

THREAD = "11111111-1111-4111-8111-111111111111"
MESSAGE = "33333333-3333-4333-8333-333333333333"


async def main():
    schema = json.loads((Path(__file__).resolve().parents[2] / "schemas/hejo-wire-v1.json").read_text())
    validator = Draft202012Validator(schema)
    seen = {"stop": 0, "undo": 0, "branch": 0, "delete": 0, "click": 0, "interrupt": 0}
    errors = []
    async def handler(request):
        ws = web.WebSocketResponse(); await ws.prepare(request)
        seq = 0
        ids = [MESSAGE]
        try:
            hello = await ws.receive_json(); validator.validate(hello)
            assert hello["pair_code"] == "test_code-12" and hello["since"] == 0
            async def emit(kind, **values):
                nonlocal seq
                frame = {"v": 1, "type": kind, **values}
                if kind in {"message", "state", "delete"}:
                    seq += 1; frame["seq"] = seq
                validator.validate(frame); await ws.send_json(frame)
            async def message(text, thread=THREAD, role="employee", **extra):
                msg_id = extra.pop("msg_id", str(uuid.uuid4()))
                await emit("message", msg_id=msg_id, employee="alpha", thread=thread, role=role, text=text,
                           files=[], buttons=extra.pop("buttons", []), reply_state=extra.pop("reply_state", None),
                           ts="2026-01-01T00:00:00Z", **extra)
                if thread == THREAD and msg_id not in ids: ids.append(msg_id)
            await emit("welcome", device_id=str(uuid.uuid4()), token="fake-thread-credential", gate_version="test", head_seq=1,
                       employees=[{"id": "alpha", "name": "직원 A", "aliases": [], "avatar": None}])
            buttons = [{"id": str(uuid.uuid4()), "label": word, "kind": "reply", "style": "default"} for word in ("의견", "확인", "Continue")]
            await message("✅ 작업 제어", msg_id=MESSAGE, buttons=buttons, reply_state="asked")
            await emit("sync_done", ref="hello", through=1, head_seq=1, more=False)
            await emit("typing", employee="alpha", thread=THREAD, on=True, ttl_seconds=6)
            async for item in ws:
                if item.type != web.WSMsgType.TEXT: continue
                frame = json.loads(item.data); validator.validate(frame)
                if await reject_imessage(ws, frame): continue
                kind = frame["type"]
                if kind == "click":
                    assert frame["button_id"] in [buttons[1]["id"], buttons[2]["id"]]
                    seen["click"] += 1
                    await emit("state", msg_id=MESSAGE, reply_state="answered")
                elif kind == "send":
                    assert frame["thread"] == THREAD
                    if frame["text"] == "interrupt":
                        seen["interrupt"] += 1
                        await message(frame["text"], role="owner", client_msg_id=frame["client_msg_id"])
                        await asyncio.sleep(.3)
                        await message("새 답")
                        continue
                    if frame["text"] == "/stop":
                        seen["stop"] += 1
                    else:
                        assert frame["text"] == "방금 중지한 작업에서 이미 바꾼 것(메모·파일·Notion·NAS·보낸 메시지 등)을 목록으로 먼저 보여 줘. 내가 확인하면 원래대로 되돌려 줘. 확인 전에는 아무것도 바꾸지 마."
                        seen["undo"] += 1
                    await message(frame["text"], role="owner", client_msg_id=frame["client_msg_id"])
                    await emit("typing", employee="alpha", thread=THREAD, on=False)
                elif kind == "thread_branch":
                    seen["branch"] += 1
                    await message("‘✅ 작업 제어’에서 이어지는 스레드", thread=str(uuid.uuid4()), branch_from={"thread": THREAD})
                elif kind == "thread_delete":
                    seen["delete"] += 1
                    await emit("delete", msg_id=MESSAGE, scope="thread", room="alpha", thread=THREAD, at="2026-01-02T00:00:00Z")
                    for msg_id in ids[1:]: await emit("delete", msg_id=msg_id)
                elif kind == "pong": pass
                else: raise AssertionError("unexpected control frame")
        except (ConnectionResetError, asyncio.CancelledError): pass
        except Exception as exc: errors.append(type(exc).__name__)
        return ws
    app = web.Application(); app.router.add_get("/v1/ws", handler)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-controls-") as tmp:
            args = [str(Path(sys.argv[1]).resolve()), "--threads", tmp, f"127.0.0.1:{port}", *sys.argv[2:]]
            result = await asyncio.to_thread(subprocess.run, args)
            assert result.returncode == 0 and not errors, errors
            assert seen == {"stop": 1, "undo": 1, "branch": 1, "delete": 1, "click": 2, "interrupt": 1}, seen
            print("THREAD_CONTROL_FIXTURE_PASS")
    finally: await runner.cleanup()


if __name__ == "__main__": asyncio.run(main())
