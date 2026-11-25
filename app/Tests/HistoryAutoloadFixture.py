"""Loopback gate and observation fixture for the AppKit history transport harness."""
import asyncio
import json
from pathlib import Path
import uuid

from aiohttp import web
import pytest

from gate.history import HistoryError, HistorySession
from gate.tests.support import airport, registered, gate


def fixture_id(number):
    return str(uuid.UUID(int=number, version=4))


@pytest.mark.asyncio
@pytest.mark.parametrize("scenario", [
    "basic", "held", "missing", "retry", "retry-fails", "long",
    "viewport", "leave-room", "refresh-fails", "root-only",
    "older", "anchored", "anchored-last", "anchored-fail", "anchored-reopen", "anchored-live",
    "anchored-no-progress",
    "cursor-context", "cursor-expired", "cursor-far", "cursor-fails", "live", "live-new-thread", "root-edge",
    "repeat", "growth", "long-fail", "delete", "priority", "thread-pages", "budget",
    "evicted", "prefetch-eviction", "retry-outside", "refresh-count",
    "legacy",
])
async def test_history_autoload(gate, tmp_path, scenario, monkeypatch):
    total = {
        "viewport": 30, "leave-room": 30, "refresh-fails": 30, "priority": 30, "refresh-count": 30,
        "prefetch-eviction": 30, "retry-outside": 30, "repeat": 10, "growth": 12,
        "thread-pages": 120, "budget": 300,
    }.get(scenario, 3)
    if scenario == "live":
        total = 1
    if scenario in ("older", "root-only", "cursor-context", "cursor-expired", "cursor-fails", "root-edge"):
        reply_count = 120
    elif scenario == "cursor-far":
        reply_count = 1000
    elif scenario.startswith("anchored"):
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
            await gate.journal.append({
                "v": 1, "type": "message", "msg_id": msg_id, "employee": "alpha",
                "thread": key, "role": "employee", "text": text,
                "files": [], "buttons": [], "ts": "2026-01-01T00:00:00Z",
            })
    if main_index:
        threads.insert(0, threads.pop(main_index))
    other = fixture_id(300)
    await gate.send("beta", "fixture other room", metadata={"thread_id": other})
    chosen = threads[0] if scenario in ("root-only", "live") else threads[-1]
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
    original = gate.server.history_query
    live_thread = fixture_id(400)
    root_to_thread = {ids[0]: key for key, ids in rows.items()}
    older_page_seen = False

    async def query(session, context, document, rooms):
        nonlocal older_page_seen
        kind = document["kind"]
        target = document.get("target")
        thread = target.get("thread") if isinstance(target, dict) else (
            root_to_thread.get(target[0]) if isinstance(target, list) and target else None
        )
        entry = {
            "kind": kind, "thread": thread, "scope": document["scope"],
            "anchor": document.get("anchor"), "cursor": bool(document.get("cursor")),
            "action": document.get("action"),
            "restoreID": target[0] if kind == "resolve" and isinstance(target, list) and document.get("limit") == 1 else None,
        }
        observed.append(entry)
        if scenario.startswith("anchored") and thread == threads[0] and entry["cursor"] and not older_page_seen:
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
        if condition["refresh"] and kind == "messages" and thread == chosen and not entry["cursor"] and not entry["anchor"]:
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
        return web.json_response(dict(requests=observed, held=condition.get("held", False)))

    async def control(request):
        action = request.match_info["action"]
        if action in ("fail", "cursor", "refresh", "content"):
            condition[action] = False
        elif action == "fail-refresh":
            condition["refresh"] = True
        elif action == "allow-newer":
            condition["newer-allowed"] = True
        elif action == "release":
            held.set()
        elif action == "release-live-refresh":
            live_refresh.set()
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
    fixture.write_text(json.dumps({
        "scenario": scenario, "threads": threads, "chosen": chosen, "rows": rows,
        "failure": failure_target, "port": port,
    }))
    binary = Path("app/.build/history-legacy-tests" if scenario == "legacy" else "app/.build/history-transport-tests").resolve()
    mode = "autoload-legacy" if scenario == "legacy" else "autoload"
    process = await asyncio.create_subprocess_exec(
        str(binary), f"127.0.0.1:{gate.server.port}", gate.auth.pair_code(),
        str(tmp_path / "app-home"), chosen, mode, str(fixture),
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), 180 if scenario == "budget" else 45)
        assert process.returncode == 0, "\n".join([stdout.decode(), stderr.decode()[-2000:], json.dumps(observed[-24:])])
        assert b"AUTOLOAD PASS" in stdout
        if scenario == "legacy":
            assert not observed and not legacy_http
    finally:
        held.set()
        live_refresh.set()
        if process.returncode is None:
            process.kill()
            await process.wait()
        await runner.cleanup()
