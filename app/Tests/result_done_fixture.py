"""Loopback history gate for result notices. No Hermes home or external service.

Each mode serves one fake thread whose summary is what the gate would report, then lets the
app press buttons and records the frames it received (AT-RD-08, 08b, 09, 01b/01c app part).
"""
from datetime import datetime, timedelta, timezone
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
    if mode == "buttons":
        return [("employee", ["승인", "거절", "의견", "확인"])] * 5
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
        self.answers, self.commands, self.queries = {}, [], []
        self.hide_preview = False
        self.notice_revision = self.seq
        self.behavior = ""
        if mode == "buttons":
            for post,title in zip(self.posts,["공지 초안을 보낼까요?", "회의 자료를 공유할까요?", "일정을 확정할까요?", "메모를 남길까요?", "검토가 끝났나요?"]):
                post["text"]=title
                for i, button in enumerate(post["buttons"]):
                    button.update(role=["approve","reject","comment","confirm"][i], icon=["circle","xmark","pencil","checkmark"][i],
                                  primary=i==0, accent="green" if i==0 else "blue")
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
        self.ws=ws
        self.session = str(uuid4())
        await ws.send_json(dict(v=1, type="welcome", token="fake-result-fixture", device_id=str(uuid4()),
                                gate_version="test", head_seq=self.seq,
                                history=dict(version=1, session=self.session, through=self.seq),
                                employees=[dict(id=EMPLOYEE, name="시험 직원", aliases=[])]))
        async for item in ws:
            if item.type != web.WSMsgType.TEXT:
                continue
            frame = json.loads(item.data)
            if self.mode=="buttons":
                print("wire", frame["type"], flush=True)
            if await reject_discord(ws, frame):
                continue
            if self.mode == "buttons" and frame["type"] in ("click","redeliver","retract"):
                self.commands.append(frame)
                action, self.behavior = self.behavior, ""
                if action in ("invalid_frame","journal_write_failed","retract_expired","button_expired"):
                    await ws.send_json(dict(v=1,type="error",ref=frame["id"],code=action))
                    continue
                if frame["type"]=="retract":
                    q=next(k for k,v in self.answers.items() if v["answer_id"]==frame["answer_id"])
                    if action!="drop_before":
                        self.answers.pop(q)
                    if action=="replace":
                        self.answer(q, "거절")
                    response=dict(v=1,type="retract_ack",answer_id=frame["answer_id"])
                else:
                    if frame["type"]=="redeliver":
                        q=next(k for k,v in self.answers.items() if v["answer_id"]==frame["answer_id"])
                        ans=self.answers[q]
                        ans["delivery"]="sent"
                        button=next(b for b in self.posts[0]["buttons"] if b["label"]==ans["label"])
                    else:
                        q=frame["msg_id"]
                        post=next(p for p in self.posts if p["msg_id"]==q)
                        button=next((b for b in post["buttons"] if b["id"]==frame["button_id"]), {"id":"std:comment","label":"의견"})
                        ans=self.answer(q,button["label"])
                    response=dict(v=1,type="click_ack",msg_id=q,button_id=button["id"],answer_id=ans["answer_id"],undo_seconds=5,undo_until=ans["undo_until"])
                if action in ("replace","drop_before","drop_after"):
                    await ws.close()
                    return ws
                await ws.send_json(response)
            elif frame["type"] == "click":
                self.clicks.append(frame)
            elif frame["type"] == "send":
                self.sends += 1
            elif frame["type"] == "deadlines":
                continue
            else:
                assert frame["type"] == "pong", frame
        return ws

    def answer(self, question, label):
        now=datetime.now(timezone.utc)
        role={"승인":"approve","거절":"reject","확인":"confirm","의견":"comment"}[label]
        self.answers[question]=dict(answer_id=str(uuid4()),label=label,role=role,result=label+(" 보냄" if role=="comment" else "함"),
                                    at=now.isoformat(),undo_until=(now+timedelta(seconds=5)).isoformat(),delivery="sent")
        return self.answers[question]

    def ask_rows(self):
        return [dict(id=p["msg_id"],msg_id=p["msg_id"],text=p["text"],buttons=p["buttons"],answer=self.answers.get(p["msg_id"])) for p in self.posts]

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
        self.queries.append(kind)
        notices = [self.notice_row()] if self.pending() else []
        if self.mode=="buttons" and notices and not self.hide_preview:
            rows=self.ask_rows()
            notices[0].update(revision=self.notice_revision,asksPreview=[r for r in rows if not r["answer"]][:3],asksWaiting=len(rows)-len(self.answers),asksAnswered=len(self.answers))
        if self.mode=="buttons" and kind=="receipt":
            page["items"]=[dict(client_msg_id=i,status="not_found") for i in body["target"]]
        elif kind=="asks":
            assert self.mode=="buttons" and body["target"]=={"room":EMPLOYEE,"thread":self.thread}
            if self.behavior=="cursor_expired":
                self.behavior=""
                return web.json_response(dict(code="cursor_expired",retryable=True),status=409)
            page["items"]=self.ask_rows()
        elif kind == "overview":
            page["items"] = [dict(id=EMPLOYEE, latestActivity=0.0, unread=0,
                                  questions=len(notices), alerts=0, latestSeq=self.seq)]
        elif kind == "threads":
            page["items"] = [self.summary()]
        elif kind == "notices":
            page["items"] = notices
        elif kind == "resolve":
            page["root"] = self.summary()
            if self.mode=="buttons" and isinstance(body["target"],list):
                originals={p["msg_id"]:dict(p,revision=self.seq,answer=self.answers.get(p["msg_id"])) for p in self.posts}
                for question,answer in self.answers.items():
                    originals[answer["answer_id"]]=dict(self.posts[0],role="owner",answer_to=question,msg_id=answer["answer_id"],revision=self.seq)
                page["items"]=[originals.get(i,dict(msg_id=i,missing=True)) for i in body["target"]]
        elif kind == "messages":
            page["items"] = [dict(post, revision=post["seq"]) for post in self.posts]
        elif kind == "read_plan":
            page.update(changes={}, action=body["action"])
        else:
            assert kind == "questions", body
        return web.json_response(page)

    async def control(self, _request):
        data=await _request.json()
        if "behavior" in data:
            if data["behavior"]=="old_gate":
                self.hide_preview=True
            elif data["behavior"]=="revision":
                self.seq+=1
                self.notice_revision=self.seq
                await self.ws.send_json(dict(v=1,type="state",seq=self.seq,msg_id=self.question,reply_state="asked"))
            elif data["behavior"]=="reset":
                self.answers.clear()
                self.behavior=""
                self.seq+=1
                self.notice_revision=self.seq
                await self.ws.send_json(dict(v=1,type="state",seq=self.seq,msg_id=self.question,reply_state="asked"))
            else:
                self.behavior=data["behavior"]
            print("fixture", data["behavior"], flush=True)
        if self.mode=="buttons":
            return web.json_response(dict(thread=self.thread,commands=self.commands,queries=self.queries,posts=self.posts,answers=self.answers,sends=self.sends))
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
    # AT-HB-30. Inspect the release inputs, including declarations as well as uses.
    policy=re.compile(r"ReplyButtonPolicy\.(?:standard|mail|contexts|allowed|script|pressable|symbol)\b")
    for path in (REPOSITORY/"app/Sources").glob("*.swift"):
        release=re.sub(r"(?ms)^\s*#if HEJO_LEGACY_REFERENCE\s*$.*?^\s*#endif\b","",path.read_text())
        assert not policy.search(release), path.name
    print("AT-HB-30 PASS", flush=True)


async def run(mode, binary):
    gate = ResultGate(mode)
    runner = web.AppRunner(gate.routes)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    address = f"127.0.0.1:{site._server.sockets[0].getsockname()[1]}"
    try:
        with tempfile.TemporaryDirectory(prefix="hejo-result-done-") as home:
            process = await asyncio.create_subprocess_exec(binary, "--buttons" if mode=="buttons" else "--result-done", home, address, mode)
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
