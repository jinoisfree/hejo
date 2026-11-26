"""Loopback gate and observation fixture for the AppKit history transport harness."""
import asyncio
import json
import os
import time
from pathlib import Path
import uuid

from aiohttp import web
import pytest

from gate.history import HistoryError, HistorySession
from gate.tests.support import airport, client, registered, gate


def fixture_id(number):
    return str(uuid.UUID(int=number, version=4))


@pytest.mark.asyncio
@pytest.mark.parametrize("scenario", [
    *[f"jump-input-{readiness}-{kind}" for readiness in ("ready", "cold") for kind in ("wheel", "click", "key")],
    "basic", "held", "missing", "retry", "retry-fails", "long",
    "viewport", "leave-room", "refresh-fails", "root-only",
    "older", "anchored", "anchored-last", "anchored-fail", "anchored-reopen", "anchored-live",
    "anchored-no-progress", "anchored-send",
    "cursor-context", "cursor-expired", "cursor-far", "cursor-fails", "live", "live-new-thread", "root-edge",
    "repeat", "growth", "long-fail", "delete", "priority", "thread-pages", "budget",
    "evicted", "prefetch-eviction", "retry-outside", "refresh-count",
    "legacy", "jump-assumptions", "jump-ready-middle", "jump-ready-edge",
    "jump-reduced-motion-interior", "jump-height", "jump-entry-question", "jump-entry-worker",
    "jump-entry-bubble", "jump-entry-search", "jump-entry-notice", "jump-stream",
    "jump-wait-drawer", "jump-wait-search", "jump-wait-notice", "jump-wait-bubble",
    "jump-wait-missing", "jump-wait-no-card", "jump-wait-replaced", "jump-wait-other", "jump-ready-other", "jump-stream-interleave", "jump-stream-reconnect", "jump-status", "jump-prefetch", "jump-prefetch-error", "jump-prefetch-budget", "jump-prefetch-delay", "jump-placement",
])
async def test_history_autoload(gate, tmp_path, scenario, monkeypatch):
    total = {
        "viewport": 30, "leave-room": 30, "refresh-fails": 30, "priority": 30, "refresh-count": 30,
        "prefetch-eviction": 30, "retry-outside": 30, "repeat": 10, "growth": 12,
        "thread-pages": 120, "budget": 300, "jump-assumptions": 12, "jump-ready-middle": 12,
        "jump-ready-edge": 12, "jump-reduced-motion-interior": 12, "jump-height": 12, "jump-prefetch": 30,
        **dict.fromkeys(("jump-entry-question", "jump-entry-worker", "jump-entry-bubble",
                         "jump-entry-search", "jump-entry-notice", "jump-wait-drawer",
                         "jump-wait-search", "jump-wait-notice", "jump-wait-bubble", "jump-wait-missing", "jump-wait-no-card", "jump-wait-replaced", "jump-wait-other", "jump-ready-other"), 12),
    }.get(scenario, 3)
    if scenario.startswith("jump-input-"):
        total = 12
    elif scenario.startswith("jump-prefetch"):
        total = 30
    if scenario == "live":
        total = 1
    if scenario in ("older", "root-only", "cursor-context", "cursor-expired", "cursor-fails", "root-edge"):
        reply_count = 120
    elif scenario == "jump-assumptions" or scenario.startswith("jump-prefetch"):
        reply_count = 120
    elif scenario == "cursor-far":
        reply_count = 1000
    elif scenario.startswith("anchored") or scenario == "jump-placement":
        reply_count = 300
    else:
        reply_count = {"live": 10, "evicted": 20}.get(scenario, 2)
    threads = []
    rows = {}
    sequence = 0
    main_index = total - 1 if scenario == "anchored-last" else 0
    for index in range(total):
        key = fixture_id(100 + index)
        threads.append(key)
        rows[key] = []
        replies = 0 if scenario in ("budget", "thread-pages", "prefetch-eviction") else (reply_count if index == main_index else 2)
        for reply in range(1 + replies):
            sequence += 1
            msg_id = fixture_id(10000 + sequence)
            text = f"fixture card {index} reply {reply}"
            if index == main_index and reply > 0 and reply_count >= 120 and scenario != "root-only":
                text += "\nline 2\nline 3\nline 4\nline 5"
            if index == 0 and reply == 1 and scenario in ("long", "long-fail"):
                text = "긴 글" * 12000
            if scenario == "growth" and reply == 0:
                text += "\nline" * 19
            if scenario == "evicted" and reply > 0:
                text += "\nline" * 23
            if scenario == "budget":
                text += " substantive fixture words" * 1600
            rows[key].append(msg_id)
            # The root-only thread stays selected when the view chooses the room's newest card.
            timestamp = "2026-01-02T00:00:00Z" if scenario == "root-only" and key == threads[0] else "2026-01-01T00:00:00Z"
            await gate.journal.append({
                "v": 1, "type": "message", "msg_id": msg_id, "employee": "alpha",
                "thread": key, "role": "employee", "text": text,
                "files": [], "buttons": [], "ts": timestamp,
                **({"reply_state": "asked"} if scenario.startswith(("jump-entry-", "jump-wait-"))
                   and index == 5 and reply == 0 else {}),
            })
    if main_index:
        threads.insert(0, threads.pop(main_index))
    other = fixture_id(300)
    other_message = await gate.send("beta", "fixture other room", metadata={"thread_id": other})
    assert other_message.success
    if scenario in ("jump-wait-bubble", "jump-wait-other", "jump-ready-other"):
        for index in range(11):
            sent = await gate.send("beta", f"fixture room thread {index}\n" * 5,
                                   metadata={"thread_id": fixture_id(320 + index)})
            assert sent.success
    chosen = threads[0] if scenario in ("root-only", "live", "jump-ready-edge") else threads[-1]
    failure_target = threads[-2] if scenario == "retry-outside" else (threads[1] if total > 1 else threads[0])
    observed = []
    condition = {
        "hold": scenario in ("basic", "held", "leave-room", "refresh-fails", "viewport", "growth", "priority"),
        "fail": scenario in ("missing", "retry", "retry-fails", "retry-outside"),
        "content": scenario == "long-fail",
        "cursor": scenario in ("cursor-expired", "cursor-fails"),
        "refresh": False,
    }
    held = asyncio.Event()
    live_refresh = asyncio.Event()
    release_send = asyncio.Event()
    original = gate.server.history_query
    live_thread = fixture_id(400)
    root_to_thread = {ids[0]: key for key, ids in rows.items()}
    older_page_seen = False
    stream_id = None
    stream_final = None
    stream_times = []
    stream_interleave = None
    stream_disconnect = None

    async def query(session, context, document, rooms):
        nonlocal older_page_seen
        kind = document["kind"]
        target = document.get("target")
        thread = target.get("thread") if isinstance(target, dict) else (
            root_to_thread.get(target[0]) if isinstance(target, list) and target else None
        )
        entry = {
            "kind": kind, "thread": thread, "scope": document["scope"],
            "threadTarget": isinstance(target, dict),
            "anchor": document.get("anchor"), "cursor": bool(document.get("cursor")),
            "action": document.get("action"),
            "restoreID": target[0] if kind == "resolve" and isinstance(target, list) and document.get("limit") == 1 else None,
        }
        if scenario.startswith("jump-"):
            entry["time"] = time.monotonic()
        observed.append(entry)
        delay = condition.get("fixed-query-delay")
        if condition.get("delayed-opening") and kind == "resolve" and entry["anchor"]:
            delay = 0.6
        if delay:
            await asyncio.sleep(delay)
        if condition.get("prefetch-error") and kind == "resolve" and isinstance(target, dict) and thread == threads[5] and not entry["anchor"]:
            raise HistoryError("target_missing", 404)
        if condition.get("jump-delay"):
            waiting_for_room = scenario in ("jump-wait-bubble", "jump-ready-other") and kind == "threads" and document["scope"] == "beta"
            if scenario == "jump-wait-no-card":
                delayed_id = fixture_id(10931)
            elif scenario == "jump-wait-other":
                delayed_id = other_message.message_id
            else:
                delayed_id = rows[threads[5]][0]
            waiting_for_body = kind == "resolve" and document.get("anchor") == delayed_id
            if waiting_for_room or waiting_for_body:
                await asyncio.sleep(0.6)
                if scenario in ("jump-wait-missing", "jump-wait-no-card"):
                    raise HistoryError("target_missing", 404)
        if (scenario.startswith("anchored") or scenario == "jump-placement") and thread == threads[0] and entry["cursor"] and not older_page_seen:
            older_page_seen = True
            condition["held"] = True
            try:
                await asyncio.wait_for(held.wait(), 15)
            finally:
                condition["held"] = False
        if condition.get("live-refresh") and kind == "messages" and thread == chosen and not entry["cursor"] and not entry["anchor"]:
            condition["held"] = True
            try:
                await asyncio.wait_for(live_refresh.wait(), 15)
            finally:
                condition["held"] = False
        if kind == "resolve" and isinstance(target, dict) and thread != chosen and not document.get("anchor"):
            if condition["hold"]:
                condition["hold"] = False
                condition["held"] = True
                try:
                    await asyncio.wait_for(held.wait(), 15)
                finally:
                    condition["held"] = False
            if condition["fail"] and thread == failure_target:
                if scenario in ("retry", "retry-outside"):
                    condition["fail"] = False
                raise HistoryError("target_missing", 404) if scenario == "missing" else HistoryError("unavailable", 503)
        if condition["cursor"] and kind == "messages" and thread == threads[0] and entry["cursor"]:
            if scenario == "cursor-expired":
                condition["cursor"] = False
            raise HistoryError("cursor_expired", 409)
        if condition["refresh"] and (
            (kind == "messages" and thread == chosen and not entry["cursor"] and not entry["anchor"])
            or (kind == "threads" and scenario == "jump-status")
        ):
            raise HistoryError("unavailable", 503)
        if scenario == "anchored-fail" and kind == "messages" and entry["anchor"] == rows[threads[0]][218] and not entry["cursor"]:
            if not condition.get("newer-allowed"):
                raise HistoryError("target_missing", 404)
        if scenario == "anchored-no-progress" and entry["anchor"] == rows[threads[0]][169] and not entry["cursor"]:
            if not condition.get("newer-allowed"):
                document = dict(document, anchor=rows[threads[0]][120])
        result = await original(session, context, document, rooms)
        entry["responseIDs"] = [row["msg_id"] for row in result.get("items", []) if "msg_id" in row]
        return result

    gate.server.history_query = query
    if scenario in ("anchored-send", "jump-placement"):
        original_receive = gate.receive

        async def receive_after_release(frame, connection, raw=None):
            if frame.get("thread") == threads[0]:
                condition["sendHeld"] = True
                try:
                    await asyncio.wait_for(release_send.wait(), 15)
                finally:
                    condition["sendHeld"] = False
            return await original_receive(frame, connection, raw=raw)

        monkeypatch.setattr(gate, "receive", receive_after_release)
    legacy_http = []
    if scenario == "legacy":
        original_prepare = web.StreamResponse.prepare

        async def record_http(response, request):
            if request.path.startswith("/v1/history/"):
                legacy_http.append(request.path)
            return await original_prepare(response, request)

        monkeypatch.setattr(web.StreamResponse, "prepare", record_http)
    if scenario == "long-fail":
        original_content = HistorySession.content

        def content(session, reference, cursor=None, *, rooms=None):
            observed.append({"kind": "content", "scope": "alpha", "cursor": bool(cursor)})
            if condition["content"]:
                raise HistoryError("target_missing", 404)
            return original_content(session, reference, cursor, rooms=rooms)

        monkeypatch.setattr(HistorySession, "content", content)

    async def observe(request):
        return web.json_response(dict(requests=observed, held=condition.get("held", False),
                                      sendHeld=condition.get("sendHeld", False),
                                      streamFinal=stream_final, streamTimes=stream_times,
                                      streamInterleave=stream_interleave, streamDisconnect=stream_disconnect))

    async def control(request):
        nonlocal stream_id, stream_final, stream_interleave, stream_disconnect
        action = request.match_info["action"]
        if action in ("fail", "cursor", "refresh", "content"):
            condition[action] = False
        elif action == "jump-cold-room-thread":
            thread = fixture_id(930)
            root = fixture_id(10930)
            await gate.journal.append({
                "v": 1, "type": "message", "msg_id": root, "employee": "beta",
                "thread": thread, "role": "employee", "text": "fixture unloaded room thread",
                "files": [], "buttons": [], "ts": "2026-01-02T00:00:00Z",
            })
            return web.json_response({"thread": thread, "root": root})
        elif action == "prefetch-error":
            condition["prefetch-error"] = True
        elif action == "prefetch-link-delay":
            condition["fixed-query-delay"] = 2
        elif action == "prefetch-old-delay":
            condition.pop("fixed-query-delay", None)
            condition["delayed-opening"] = True
        elif action == "jump-refresh-delay":
            condition["fixed-query-delay"] = 0.3
        elif action == "prefetch-clear-delay":
            condition.pop("fixed-query-delay", None)
            condition.pop("delayed-opening", None)
        elif action == "jump-delay":
            condition["jump-delay"] = True
        elif action == "stream-open":
            sent = await gate.send("alpha", "생각 중…", metadata={"thread_id": live_thread, "expect_edits": True})
            assert sent.success
            stream_id = sent.message_id
            return web.json_response({"thread": live_thread, "root": stream_id})
        elif action == "stream-run":
            assert stream_id is not None
            for index in range(1, 31):
                if index < 10:
                    text = f"생각 중…\n준비 단계 {index}"
                elif index < 20:
                    text = f"자료를 확인했어요. {index}"
                else:
                    text = f"자료를 확인했어요. 승인해 줘. {index}"
                stream_times.append(time.monotonic())
                await gate._record({"type": "edit", "msg_id": stream_id, "text": text, "final": False})
                if scenario == "jump-stream-interleave" and index == 15:
                    stream_interleave = time.monotonic()
                    sent = await gate.send("alpha", "다른 스레드의 새 글", metadata={"thread_id": threads[0]})
                    assert sent.success
                await asyncio.sleep(0.03)
            if scenario == "jump-stream-reconnect":
                stream_disconnect = time.monotonic()
                await asyncio.gather(*(connection.close() for connection in tuple(gate.server.connections)))
            else:
                stream_final = time.monotonic()
                await gate._record({"type": "edit", "msg_id": stream_id, "text": "완료했어요. 승인해 줘.", "final": True})
        elif action == "status-offline-reply":
            sent = await gate.send("alpha", "fixture reply while disconnected", metadata={"thread_id": threads[0]})
            assert sent.success
            return web.json_response({"id": sent.message_id})
        elif action == "fail-refresh":
            condition["refresh"] = True
        elif action == "allow-newer":
            condition["newer-allowed"] = True
        elif action == "release":
            held.set()
        elif action == "release-live-refresh":
            live_refresh.set()
        elif action == "release-send":
            release_send.set()
        elif action == "delete":
            await gate._record({"v": 1, "type": "delete", "scope": "thread", "room": "alpha", "thread": threads[0]})
        elif action == "live-root":
            sent = await gate.send("alpha", "fixture new thread", metadata={"thread_id": live_thread})
            assert sent.success
            root_to_thread[sent.message_id] = live_thread
            return web.json_response({"thread": live_thread, "root": sent.message_id})
        elif action == "live-replies":
            replies = []
            for number in range(2):
                sent = await gate.send("alpha", f"fixture live reply {number}", metadata={"thread_id": live_thread})
                assert sent.success
                replies.append(sent.message_id)
            return web.json_response(replies)
        elif action == "live":
            condition["live-refresh"] = scenario == "live"
            same_thread = scenario in ("live", "anchored-live")
            key = threads[0] if same_thread else other
            room = "alpha" if same_thread else "beta"
            sent = await gate.send(room, "fixture live\nline 2\nline 3\nline 4\nline 5", metadata={"thread_id": key})
            assert sent.success
            return web.json_response({"id": sent.message_id})
        else:
            raise web.HTTPBadRequest()
        return web.json_response({})

    app = web.Application()
    app.router.add_get("/observe", observe)
    app.router.add_post("/control/{action}", control)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "127.0.0.1", 0)
    await site.start()
    port = site._server.sockets[0].getsockname()[1]
    fixture = tmp_path / "fixture.json"
    fixture_values = {
        "scenario": scenario, "threads": threads, "chosen": chosen, "rows": rows,
        "failure": failure_target, "port": port, "other": other, "otherRoot": other_message.message_id,
    }
    fixture.write_text(json.dumps(fixture_values))
    binary = Path("app/.build/history-legacy-tests" if scenario == "legacy" else "app/.build/history-transport-tests").resolve()
    mode = ("autoload-legacy" if scenario == "legacy" else
            "autoload-input" if scenario.startswith("jump-input-") else "autoload")
    environment = dict(os.environ)
    if scenario in ("jump-assumptions", "jump-wait-drawer", "jump-prefetch"):
        trace_dir = Path(".build/jump-once").resolve()
        trace_dir.mkdir(parents=True, exist_ok=True)
        trace_name = {
            "jump-assumptions": "three-tap-baseline.jsonl",
            "jump-wait-drawer": "v5-wait-trace.jsonl",
            "jump-prefetch": "prefetch-trace.jsonl",
        }[scenario]
        trace = trace_dir / trace_name
        trace.unlink(missing_ok=True)
        environment["HEJO_THREE_TAP_TRACE"] = str(trace)
    process = await asyncio.create_subprocess_exec(
        str(binary), f"127.0.0.1:{gate.server.port}", gate.auth.pair_code(),
        str(tmp_path / "app-home"), chosen, mode, str(fixture),
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env=environment,
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), 180 if scenario == "budget" else 45)
        assert process.returncode == 0, "\n".join([stdout.decode(), stderr.decode()[-2000:], json.dumps(observed[-24:])])
        if scenario.startswith("jump-"):
            print(stdout.decode(), end="")
        if scenario.startswith("jump-input-"):
            def trajectory(output):
                prefix = "AT-JO-04 trajectory "
                value, = [json.loads(line.removeprefix(prefix)) for line in output.decode().splitlines()
                          if line.startswith(prefix)]
                return value

            measured = trajectory(stdout)
            fixture.write_text(json.dumps({
                **fixture_values, "controlOrigin": measured["origin"], "controlBodyTick": measured["bodyTick"],
            }))
            condition["jump-delay"] = False
            control_app = await asyncio.create_subprocess_exec(
                str(binary), f"127.0.0.1:{gate.server.port}", gate.auth.pair_code(),
                str(tmp_path / "contrast-home"), chosen, mode, str(fixture),
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE, env=environment,
            )
            try:
                control_stdout, control_stderr = await asyncio.wait_for(control_app.communicate(), 45)
                assert control_app.returncode == 0, (
                    "AT-JO-04 contrast run failed:\n" + control_stderr.decode(errors="replace")[-2000:]
                )
                contrast = trajectory(control_stdout)
            finally:
                if control_app.returncode is None:
                    control_app.kill()
                    await control_app.wait()
            assert len(measured["samples"]) == len(contrast["samples"])
            maximum_error = max(abs(left - right) for left, right in zip(measured["samples"], contrast["samples"]))
            print(f"AT-JO-04 {scenario} {'PASS' if maximum_error <= 0.5 else 'FAIL'} maxDifference={maximum_error}")
            print(f"AT-JO-04 input={measured['input']} contrastInput={contrast['input']} "
                  f"origin={measured['origin']} contrastOrigin={contrast['origin']}")
            assert maximum_error <= 0.5
        if scenario in ("jump-stream", "jump-stream-interleave", "jump-stream-reconnect"):
            prefix = "AT-JO-18 canonical "
            summary, = [json.loads(line.removeprefix(prefix)) for line in stdout.decode().splitlines()
                        if line.startswith(prefix)]
            reference = Path(".build/jump-once") / f"{scenario}-reference.json"
            if os.environ.get("JUMP_ONCE_CAPTURE_REFERENCE") == "1":
                reference.write_text(json.dumps(summary, ensure_ascii=False, sort_keys=True) + "\n")
            elif os.environ.get("JUMP_ONCE_VERIFY_REFERENCE") == "1":
                assert summary == json.loads(reference.read_text()), "AT-JO-18 final aggregates differ from baseline"
        if scenario == "jump-placement":
            prefix = "AT-JO-10 canonical "
            origins, = [json.loads(line.removeprefix(prefix)) for line in stdout.decode().splitlines()
                        if line.startswith(prefix)]
            reference = Path(".build/jump-once") / "placement-reference.json"
            if os.environ.get("JUMP_ONCE_CAPTURE_REFERENCE") == "1":
                reference.write_text(json.dumps(origins, sort_keys=True) + "\n")
            elif os.environ.get("JUMP_ONCE_VERIFY_REFERENCE") == "1":
                expected = json.loads(reference.read_text())
                assert set(origins) == set(expected)
                assert all(abs(origins[key] - expected[key]) <= 1 for key in expected)
        if os.environ.get("JUMP_ONCE_VERIFY_REFERENCE") == "1":
            verdicts = {
                "jump-prefetch": ("AT-JO-11 PASS",),
                "jump-prefetch-delay": ("AT-JO-12 same room PASS", "AT-JO-12 other room PASS",
                                        "AT-JO-12 outside recent page PASS"),
                "jump-prefetch-error": ("AT-JO-13 error PASS", "AT-JO-13 error click PASS"),
                "jump-prefetch-budget": ("AT-JO-13 eviction PASS", "AT-JO-13 evicted click PASS"),
                "jump-ready-middle": ("AT-JO-01 PASS",),
                "jump-ready-edge": ("AT-JO-01b PASS",),
                "jump-reduced-motion-interior": ("AT-JO-09 PASS",),
                "jump-height": ("AT-JO-03 PASS",),
                "jump-wait-drawer": ("AT-JO-02 same room PASS",),
                "jump-wait-other": ("AT-JO-02 other room PASS",),
                "jump-ready-other": ("AT-JO-07 PASS",),
                "jump-wait-replaced": ("AT-JO-05 PASS",),
                "jump-wait-missing": ("AT-JO-06 card PASS",),
                "jump-wait-no-card": ("AT-JO-06 no card PASS",),
                "jump-status": (
                    "AT-JO-14 target missing=false refetches=0 placement=true",
                    "conversationAccessibility=true inlineUpdate=false cleared=true",
                    "AT-JO-14 refresh drawer shift=0.0 accessibility=true",
                    "AT-JO-15 conversation inline failure row=false retryRefreshes=1",
                ),
            }
            expected_verdicts = verdicts.get(scenario, ())
            if scenario in ("jump-stream", "jump-stream-interleave", "jump-stream-reconnect"):
                expected_verdicts = (f"AT-JO-18 {scenario} PASS",)
            elif scenario.startswith("jump-entry-"):
                expected_verdicts = (f"AT-JO-08 {scenario.removeprefix('jump-entry-')} PASS",)
            elif scenario in ("jump-wait-bubble", "jump-wait-search", "jump-wait-notice"):
                expected_verdicts = (f"AT-JO-08 cold {scenario} PASS",)
            output = stdout.decode()
            for expected_verdict in expected_verdicts:
                assert expected_verdict in output
        assert b"AUTOLOAD PASS" in stdout
        if scenario == "legacy":
            assert not observed and not legacy_http
    finally:
        held.set()
        live_refresh.set()
        release_send.set()
        if process.returncode is None:
            process.kill()
            await process.wait()
        await runner.cleanup()


@pytest.mark.asyncio
async def test_jump_stream_aggregate_fields(gate, client):
    """Record G-3 from the same HTTP projections that the app refreshes."""
    from datetime import datetime, timezone

    from aiohttp import ClientSession

    room = "alpha"
    thread = fixture_id(900)
    sent = await gate.send(room, "생각 중…", metadata={"thread_id": thread, "expect_edits": True})
    assert sent.success
    ws, welcome = await client.pair(since=0, features=["rooms", "history-v1"])
    session = welcome["history"]["session"]
    base = f"http://127.0.0.1:{gate.server.port}/v1/history/"
    headers = {"Authorization": "Bearer " + welcome["token"]}

    async with ClientSession(trust_env=False, headers=headers) as http:
        async with http.post(base + "context", json={
            "session": session, "generation": 1, "memberRevision": 0, "ready": True,
            "items": {}, "home": [room], "hidden": [], "names": {},
            "now": datetime.now(timezone.utc).timestamp(),
        }) as response:
            assert response.status == 200
            context = (await response.json())["context"]

        async def snapshot():
            result = {}
            for kind in ("overview", "threads", "notices", "questions"):
                request = {"session": session, "context": context, "kind": kind, "request": str(uuid.uuid4()),
                           "scope": room if kind == "threads" else "home"}
                if kind in ("overview", "notices"):
                    request["mode"] = "sidebar"
                async with http.post(base + "query", json=request) as response:
                    assert response.status == 200
                    page = await response.json()
                    assert page["complete"]
                    result[kind] = {key: page[key] for key in ("items", "totals") if key in page}
            return result

        async def stream(text):
            edit = await gate.edit_message(room, sent.message_id, text, finalize=False)
            assert edit.success
            frame = await asyncio.wait_for(client.read(ws), timeout=3)
            assert frame["type"] == "edit" and frame["final"] is False
            return await snapshot()

        before = await snapshot()
        first = await stream("자료를 확인하고 있어요.")
        second = await stream("자료를 확인하고 있어요. 승인해 줘")

    def changes(before, after, path):
        if isinstance(before, dict) and isinstance(after, dict):
            for key in sorted(before.keys() | after.keys()):
                yield from changes(before.get(key), after.get(key), f"{path}.{key}")
        elif isinstance(before, list) and isinstance(after, list) and len(before) == len(after):
            for index, (left, right) in enumerate(zip(before, after)):
                yield from changes(left, right, f"{path}[{index}]")
        elif before != after:
            yield path, before, after

    for label, left, right in [("first edit", before, first), ("second edit", first, second)]:
        print(f"G-3 {label}")
        for path, old, new in changes(left, right, "server"):
            print(f"{path}: {json.dumps(old, ensure_ascii=False)} -> {json.dumps(new, ensure_ascii=False)}")


@pytest.mark.asyncio
async def test_jump_stream_opening_frame_contract(gate, client):
    """Compare AT-JO-18's opening input with the gate's actual wire contract."""
    from jsonschema import Draft202012Validator
    from gate.server import SCHEMA

    ws, _ = await client.pair(since=0, features=["rooms", "history-v1"])
    sent = await gate.send("alpha", "생각 중…", metadata={"thread_id": fixture_id(901), "expect_edits": True})
    assert sent.success
    opening = await client.read(ws)
    assert opening["type"] == "message" and opening["msg_id"] == sent.message_id
    validator = Draft202012Validator({**SCHEMA, "oneOf": [{"$ref": "#/$defs/message"}]})
    assert validator.is_valid(opening)
    errors = list(validator.descend(dict(opening, final=False), SCHEMA["$defs"]["message"]))
    assert [error.validator for error in errors] == ["additionalProperties"]
    edited = await gate.edit_message("alpha", sent.message_id, "자료를 확인하고 있어요.", finalize=False)
    assert edited.success
    fragment = await asyncio.wait_for(client.read(ws), timeout=3)
    assert fragment["type"] == "edit" and fragment["final"] is False
    print("AT-JO-18 opening frame: message final=" + str(opening.get("final", "absent")))
    print("AT-JO-18 fixture with message final:false: " + errors[0].message)
    print("AT-JO-18 first subsequent fragment: edit final=false")
