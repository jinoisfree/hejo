"""Loopback history gate for card completion. No Hermes home or external service."""
import asyncio
import json
from pathlib import Path
import sys
import tempfile
from uuid import uuid4

from aiohttp import web
from legacy_feature_fixture import reject_discord

EMPLOYEE = "fixture"
STAMP = "2026-01-01T00:00:00Z"
# AT-HB-35 replaces the question strip. Deadline close, cancellation and offline behavior remain.
MODES = {"confirm": [], "deadline": ["done"], "undo": [], "stop": [],
         "mixed": ["done", "cancel"], "offline": []}


class CardGate:
    def __init__(self, mode):
        self.mode = mode
        self.keys = {name: str(uuid4()) for name in ("A", "B", "C")}
        self.posts = {}
        self.seen = []
        self.clicks = []
        self.receipts = []
        self.hidden = set()
        self.receipt_status = "not_found"
        self.seq = 0
        for name, thread in self.keys.items():
            self.posts[thread] = [self.message(thread, f"질문 {name}", "employee", asked=True)]
        self.routes = web.Application()
        self.routes.router.add_get("/v1/ws", self.socket)
        self.routes.router.add_get("/v1/history/capabilities", self.capabilities)
        self.routes.router.add_post("/v1/history/context", self.context)
        self.routes.router.add_post("/v1/history/query", self.query)
        self.routes.router.add_post("/fixture", self.control)

    def message(self, thread, text, role, *, asked=False, **fields):
        self.seq += 1
        buttons = ([{"id": str(uuid4()), "label": word, "kind": kind, "style": "default"}
                    for word, kind in [("회신", "reply"), ("닫기", "approval")]]
                   if asked else [])
        return dict(v=1, type="message", seq=self.seq, msg_id=str(uuid4()), thread=thread,
                    employee=EMPLOYEE, role=role, text=text, files=[], buttons=buttons,
                    reply_state="asked" if asked else None, ts=STAMP, **fields)

    async def socket(self, request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        hello = await ws.receive_json()
        assert "history-v1" in hello["features"]
        self.session = str(uuid4())
        await ws.send_json(dict(v=1, type="welcome", token="fake-card-fixture", device_id=str(uuid4()),
                                gate_version="test", head_seq=self.seq,
                                history=dict(version=1, session=self.session, through=self.seq),
                                employees=[dict(id=EMPLOYEE, name="시험 직원", aliases=[])]))
        async for item in ws:
            if item.type != web.WSMsgType.TEXT:
                continue
            frame = json.loads(item.data)
            if await reject_discord(ws, frame):
                continue
            if frame["type"] == "send":
                name = next(name for name, value in self.keys.items() if value == frame["thread"])
                assert frame["employee"] == EMPLOYEE and frame["text"] == "확인", frame
                self.seen.append(name)
                self.last_send = frame
                if self.mode == "reject":
                    await ws.send_json(dict(v=1, type="error", ref=frame["client_msg_id"],
                                            code="journal_write_failed"))
                elif self.mode in ("confirm", "ack", "mixed"):
                    line = self.message(frame["thread"], "확인", "owner",
                                        client_msg_id=frame["client_msg_id"])
                    self.posts[frame["thread"]].append(line)
                    await ws.send_json(line)
            elif frame["type"] == "deadline_close":
                assert frame["employee"] == EMPLOYEE
                assert frame["deadline"] == "fixture-" + frame["outcome"]
                self.seen.append(frame["outcome"])
            elif frame["type"] == "click":
                self.clicks.append(frame)
            elif frame["type"] == "deadlines":
                # Real list requests must not replace the deliberately injected fixture ledger.
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

    def summary(self, thread):
        first, *rest = self.posts[thread]
        last = rest[-1] if rest else first
        return dict(key=dict(room=EMPLOYEE, thread=thread), rootID=first["msg_id"],
                    rootRole="employee", rootTime=STAMP, lastTime=STAMP, rootSeq=first["seq"],
                    latestSeq=last["seq"], originalMaxSeq=last["seq"], revision=last["seq"],
                    title=first["text"], rootPreview=first["text"], preview=last["text"],
                    messageCount=1 + len(rest), unread=0, waitingButtonCount=0,
                    activity=dict(lastSpeaker=EMPLOYEE, working=False, latestEmployeeTime=None),
                    assessment=dict(working=False, settled=False, approved=False))

    async def query(self, request):
        body = await request.json()
        kind = body["kind"]
        page = dict(session=self.session, context=body["context"], request=body["request"],
                    through=self.seq, complete=True, next=None, items=[])
        if kind == "overview":
            page["items"] = [dict(id=EMPLOYEE, latestActivity=0.0, unread=0,
                                  questions=3, alerts=0, latestSeq=self.seq)]
        elif kind == "threads":
            page["items"] = [self.summary(thread) for thread in self.posts]
        elif kind == "notices":
            page["items"] = [dict(id=posts[0]["msg_id"], key=dict(room=EMPLOYEE, thread=thread),
                                  group="question:fixture", title="답 요청", speaker=EMPLOYEE,
                                  timestamp=STAMP, preview=posts[0]["text"], questions=True,
                                  revision=posts[0]["seq"])
                             for thread, posts in self.posts.items() if thread not in self.hidden]
        elif kind == "resolve":
            page["root"] = self.summary(body["target"]["thread"])
        elif kind == "messages":
            thread = body["target"]["thread"]
            page["items"] = [dict(post, revision=post["seq"]) for post in self.posts[thread]]
        elif kind == "receipt":
            for identifier in body["target"]:
                status = self.receipt_status
                self.receipts.append(status)
                row = dict(client_msg_id=identifier, status=status)
                if status == "accepted":
                    assert self.last_send["client_msg_id"] == identifier
                    row.update(msg_id=str(uuid4()), seq=self.seq,
                               key=dict(room=EMPLOYEE, thread=self.last_send["thread"]))
                page["items"].append(row)
        elif kind == "read_plan":
            page.update(changes={}, action=body["action"])
        else:
            assert kind == "questions", body
        return web.json_response(page)

    async def control(self, request):
        body = await request.json()
        for field, action in [("hide", self.hidden.add), ("show", self.hidden.discard)]:
            if field in body:
                action(self.keys[body[field]])
        if "receipt" in body:
            self.receipt_status = body["receipt"]
        return web.json_response(dict(seen=self.seen, clicks=len(self.clicks), receipts=self.receipts))


async def run(mode, binary, evidence):
    gate = CardGate(mode)
    runner = web.AppRunner(gate.routes)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    address = f"127.0.0.1:{site._server.sockets[0].getsockname()[1]}"
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-card-done-") as home:
            process = await asyncio.create_subprocess_exec(
                binary, "--card-done", home, address, mode, str(evidence))
            try:
                assert await asyncio.wait_for(process.wait(), 45) == 0, mode
            finally:
                if process.returncode is None:
                    process.kill()
                    await process.wait()
        assert gate.seen == MODES[mode], (mode, gate.seen)
        assert not gate.clicks, mode
    finally:
        await runner.cleanup()


async def main():
    binary, evidence = (Path(value).resolve() for value in sys.argv[1:3])
    for mode in sys.argv[3:] or MODES:
        await run(mode, binary, evidence)
    print("CARD_DONE_WIRE_PASS", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
