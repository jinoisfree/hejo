"""Loopback history gate for result notices. No Hermes home or external service.

Each mode serves one fake thread whose summary is what the gate would report, then lets the
app press buttons and records the frames it received (AT-RD-08, 08b, 09, 01b/01c app part).
"""
import asyncio
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from uuid import uuid4

from aiohttp import web
from legacy_feature_fixture import reject_discord

EMPLOYEE = "fixture"
STAMP = "2026-01-01T00:00:00Z"
APPROVAL = ["승인", "거절"]
RESULT = ["확인", "되돌리기"]
MODES = ["done", "both", "prefixed", "padded", "reversed", "legacy"]
REPOSITORY = Path(__file__).resolve().parents[2]
BASELINE_COMMIT = "63e7bf9da0789be6128f10afe8e5bb8ccda6fe90"


def thread_script(mode):
    """(role, labels) rows in seq order."""
    last = {"done": RESULT, "prefixed": [":white_check_mark: 확인", "되돌리기"], "padded": ["확인", " 되돌리기 "],
            "reversed": ["되돌리기", "확인"]}
    if mode == "both":
        return [("employee", APPROVAL), ("employee", RESULT)]
    if mode == "legacy":
        return [("employee", APPROVAL)]
    return [("employee", APPROVAL), ("owner", []), ("employee", last[mode])]


class ResultGate:
    def __init__(self, mode):
        self.mode = mode
        self.thread = str(uuid4())
        self.clicks = []
        self.sends = 0
        self.seq = 0
        self.posts = []
        for role, labels in thread_script(mode):
            self.posts.append(self.message(role, labels))
        self.routes = web.Application()
        self.routes.router.add_get("/v1/ws", self.socket)
        self.routes.router.add_get("/v1/history/capabilities", self.capabilities)
        self.routes.router.add_post("/v1/history/context", self.context)
        self.routes.router.add_post("/v1/history/query", self.query)
        self.routes.router.add_post("/fixture", self.control)

    def message(self, role, labels):
        self.seq += 1
        employee = role == "employee"
        buttons = [{"id": str(uuid4()), "label": label, "kind": "reply", "style": "default"} for label in labels]
        return dict(v=1, type="message", seq=self.seq, msg_id=str(uuid4()), thread=self.thread,
                    employee=EMPLOYEE, role=role, text=("질문이에요" if labels == APPROVAL else "처리 결과를 알려 드려요.") if employee else "일정에 등록",
                    files=[], buttons=buttons, reply_state="asked" if employee else None, ts=STAMP)

    @property
    def question(self):
        return self.posts[0]["msg_id"]

    @property
    def last(self):
        return self.posts[-1]["msg_id"]

    async def socket(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        hello = await ws.receive_json()
        assert "history-v1" in hello["features"]
        self.session = str(uuid4())
        await ws.send_json(dict(v=1, type="welcome", token="fake-result-fixture", device_id=str(uuid4()),
                                gate_version="test", head_seq=self.seq,
                                history=dict(version=1, session=self.session, through=self.seq),
                                employees=[dict(id=EMPLOYEE, name="시험 직원", aliases=[])]))
        async for item in ws:
            if item.type != web.WSMsgType.TEXT:
                continue
            frame = json.loads(item.data)
            if await reject_discord(ws, frame):
                continue
            if frame["type"] == "click":
                self.clicks.append(frame)
            elif frame["type"] == "send":
                self.sends += 1
            elif frame["type"] == "deadlines":
                continue
            else:
                assert frame["type"] == "pong", frame
        return ws

    async def capabilities(self, _request):
        return web.json_response(dict(version=1, mode="history-v1", limits=dict(
            page_items=50, page_bytes=512 * 1024, content_chunk_bytes=256 * 1024)))

    async def context(self, request):
        body = await request.json()
        return web.json_response(dict(context="fixture-context", generation=body["generation"],
                                      memberRevision=body["memberRevision"]))

    def pending(self):
        """What the gate reports: a decorated or reversed result looks like any other request."""
        return self.mode != "done"

    def waiting(self):
        if self.mode == "both":
            return [self.posts[0]["msg_id"], self.posts[1]["msg_id"]]
        return [self.last] if self.mode != "legacy" else None

    def summary(self):
        first, last = self.posts[0], self.posts[-1]
        pending = self.question if self.mode in ("both", "legacy") else self.last
        assessment = (dict(requestID=pending, pendingID=pending, working=False, settled=False, approved=False)
                      if self.pending() else
                      dict(requestID=self.last, pendingID=None, working=False, settled=True, approved=False))
        body = dict(key=dict(room=EMPLOYEE, thread=self.thread), rootID=first["msg_id"],
                    rootRole="employee", rootTime=STAMP, lastTime=STAMP, rootSeq=first["seq"],
                    latestSeq=last["seq"], originalMaxSeq=last["seq"], revision=last["seq"],
                    title=first["text"], rootPreview=first["text"], preview=last["text"],
                    messageCount=len(self.posts), unread=0,
                    waitingButtonCount=len(self.waiting() or [pending]),
                    activity=dict(lastSpeaker=EMPLOYEE, working=False, latestEmployeeTime=None),
                    assessment=assessment, bell=True if self.pending() else None)
        if self.waiting() is not None:
            body["waitingButtonIDs"] = self.waiting()
        return body

    def notice_row(self):
        asked = next(p for p in self.posts if p["msg_id"] == self.summary()["assessment"]["pendingID"])
        return dict(id=asked["msg_id"], key=dict(room=EMPLOYEE, thread=self.thread), group="question:fixture",
                    title="시험 직원 질문", speaker=EMPLOYEE, timestamp=STAMP, preview=asked["text"],
                    questions=True, revision=asked["seq"])

    async def query(self, request):
        body = await request.json()
        kind = body["kind"]
        page = dict(session=self.session, context=body["context"], request=body["request"],
                    through=self.seq, complete=True, next=None, items=[])
        notices = [self.notice_row()] if self.pending() else []
        if kind == "overview":
            page["items"] = [dict(id=EMPLOYEE, latestActivity=0.0, unread=0,
                                  questions=len(notices), alerts=0, latestSeq=self.seq)]
        elif kind == "threads":
            page["items"] = [self.summary()]
        elif kind == "notices":
            page["items"] = notices
        elif kind == "resolve":
            page["root"] = self.summary()
        elif kind == "messages":
            page["items"] = [dict(post, revision=post["seq"]) for post in self.posts]
        elif kind == "read_plan":
            page.update(changes={}, action=body["action"])
        else:
            assert kind == "questions", body
        return web.json_response(page)

    async def control(self, _request):
        return web.json_response(dict(
            thread=self.thread, sends=self.sends,
            clicks=[{name: frame[name] for name in ("type", "msg_id", "button_id")} for frame in self.clicks],
            posts=[dict(id=p["msg_id"], role=p["role"], buttons=p["buttons"]) for p in self.posts]))


def check_static():
    """AT-RD-10: HistoryThreadSummary has no custom decoder, in the new app and in 0.2.9."""
    def custom(source):
        start = source.index("struct HistoryThreadSummary")
        end = source.index("\nstruct ", start + 1)
        return [line for line in source[start:end].splitlines() if re.search(r"init\s*\(\s*from\b", line)]
    sources = [(REPOSITORY / "app/Sources/HistoryProjection.swift").read_text()]
    shown = subprocess.run(["git", "-C", str(REPOSITORY), "show", BASELINE_COMMIT + ":app/Sources/HistoryProjection.swift"],
                           capture_output=True, text=True)
    if shown.returncode == 0:
        sources.append(shown.stdout)
    assert all(custom(source) == [] for source in sources), "HistoryThreadSummary gained a custom decoder"
    print("AT-RD-10 PASS", flush=True)


async def run(mode, binary):
    gate = ResultGate(mode)
    runner = web.AppRunner(gate.routes)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    address = f"127.0.0.1:{site._server.sockets[0].getsockname()[1]}"
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-result-done-") as home:
            process = await asyncio.create_subprocess_exec(binary, "--result-done", home, address, mode)
            try:
                assert await asyncio.wait_for(process.wait(), 60) == 0, mode
            finally:
                if process.returncode is None:
                    process.kill()
                    await process.wait()
    finally:
        await runner.cleanup()


async def main():
    binary = Path(sys.argv[1]).resolve()
    check_static()
    for mode in sys.argv[2:] or MODES:
        await run(mode, binary)
    print("RESULT_DONE_WIRE_PASS", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
