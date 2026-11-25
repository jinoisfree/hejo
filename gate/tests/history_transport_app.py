"""Explicit small Swift/real-gate history test; never launches the installed app."""
import asyncio
from pathlib import Path
import uuid
import pytest
from gate.tests.support import airport, registered, gate, client


@pytest.mark.asyncio
async def test_swift_partial_history_transport(gate, tmp_path):
    thread = str(uuid.uuid4())
    await gate.send('alpha', '가'*20000, metadata={'thread_id':thread})
    await gate.send('alpha', 'second', metadata={'thread_id':thread})
    binary = Path('app/.build/history-transport-tests').resolve()
    process = await asyncio.create_subprocess_exec(str(binary), f'127.0.0.1:{gate.server.port}',
        gate.auth.pair_code(), str(tmp_path/'app-home'), thread,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        ready = await asyncio.wait_for(process.stdout.readline(), timeout=15)
        if ready != b'READY\n':
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=5)
            raise AssertionError(f'Swift setup failed: exit={process.returncode}; {stderr.decode()[-3000:]}')
        await gate.send('alpha', 'fixture live', metadata={'thread_id':thread})
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS history preflight' in stdout
    finally:
        if process.returncode is None:
            process.kill()
            await process.wait()


@pytest.mark.asyncio
async def test_swift_unsupported_server_never_opens_websocket(tmp_path):
    from aiohttp import web
    requests = []
    async def capabilities(request):
        requests.append('capabilities')
        return web.Response(status=404)
    async def websocket(request):
        requests.append('websocket')
        return web.Response(status=400)
    app = web.Application()
    app.router.add_get('/v1/history/capabilities', capabilities)
    app.router.add_get('/v1/ws', websocket)
    runner = web.AppRunner(app); await runner.setup()
    site = web.TCPSite(runner, '127.0.0.1', 0); await site.start()
    port = site._server.sockets[0].getsockname()[1]
    process = None
    try:
        process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
            f'127.0.0.1:{port}', 'fixture-code', str(tmp_path/'unsupported-home'), 'fixture-thread', 'unsupported',
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS unsupported server' in stdout
        assert requests == ['capabilities']
    finally:
        if process is not None and process.returncode is None:
            process.kill(); await process.wait()
        await runner.cleanup()


@pytest.mark.asyncio
async def test_swift_controller_bootstrap_read_and_live(gate, tmp_path):
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'first', metadata={'thread_id':thread})
    await gate.send('alpha', 'second', metadata={'thread_id':thread})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'controller-home'), thread, 'controller',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        ready = await asyncio.wait_for(process.stdout.readline(), timeout=15)
        if ready != b'READY\n':
            stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=5)
            raise AssertionError(f'Controller bootstrap failed: {stderr.decode()[-3000:]}')
        await gate.send('alpha', 'fixture live', metadata={'thread_id':thread})
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS controller bounded bootstrap' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_controller_read_plan_pages_fail_without_partial_writes(gate, tmp_path):
    from gate.history import HistoryError
    threads = [str(uuid.uuid4()) for _ in range(51)]
    for thread in threads:
        await gate.send('alpha', 'fixture notice', metadata={'thread_id':thread})
    original = gate.server.history_query
    failures = 0
    async def interrupt_second_page(session, context, document, rooms):
        nonlocal failures
        if document['kind'] == 'read_plan' and document.get('action') == 'mark_all' and document.get('cursor') and failures < 2:
            failures += 1
            raise HistoryError('unavailable', 503)
        return await original(session, context, document, rooms)
    gate.server.history_query = interrupt_second_page
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'read-plan-home'), threads[-1], 'controller-plan',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert failures == 2
        assert b'PASS controller multi-page read failure' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_controller_explicit_root_and_older_page(gate, tmp_path):
    # Exactly one page boundary; semantic test, no load measurements.
    thread = str(uuid.uuid4())
    await gate.send('alpha', '가'*20000, metadata={'thread_id': thread})
    for index in range(50):
        await gate.send('alpha', f'fixture reply {index}', metadata={'thread_id': thread})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'pages-home'), thread, 'controller-pages',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS explicit root' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_copy_revision_change_preserves_clipboard(gate, tmp_path):
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'fixture first', metadata={'thread_id':thread})
    await gate.send('alpha', 'fixture second', metadata={'thread_id':thread})
    original = gate.server.history_query
    changed = False
    async def change_before_finalizing(session, context, document, rooms):
        nonlocal changed
        if document['kind'] == 'copy' and document.get('action') == 'finalize' and not changed:
            changed = True
            identifier = next(session.index.ids(('alpha', thread)))
            await gate.edit_message('alpha', identifier, 'fixture changed during copy', finalize=True)
        return await original(session, context, document, rooms)
    gate.server.history_query = change_before_finalizing
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'copy-home'), thread, 'controller-copyfail',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert changed
        assert b'PASS copy final revision failure' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_controller_search_resolves_unloaded_message(gate, tmp_path):
    from gate.history import HistoryError
    original = gate.server.history_query
    failures = 0
    async def fail_sidebar(session, context, document, rooms):
        nonlocal failures
        if document['kind'] == 'search' and document.get('mode') == 'sidebar' and failures < 2:
            failures += 1
            raise HistoryError('unavailable', 503)
        return await original(session, context, document, rooms)
    gate.server.history_query = fail_sidebar
    old_thread, recent_thread = str(uuid.uuid4()), str(uuid.uuid4())
    await gate.send('alpha', 'fixture needle body', metadata={'thread_id':old_thread})
    await gate.send('alpha', 'fixture recent body', metadata={'thread_id':recent_thread})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'search-home'), recent_thread, 'controller-search',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS server search display' in stdout
        assert failures == 2
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_notice_second_page_failure_does_not_publish_partial_drawer(gate, tmp_path):
    from gate.history import HistoryError
    threads = [str(uuid.uuid4()) for _ in range(51)]
    for thread in threads:
        await gate.send('alpha', 'fixture notice', metadata={'thread_id':thread})
    original = gate.server.history_query
    failures = 0
    async def fail_second_page(session, context, document, rooms):
        nonlocal failures
        if document['kind'] == 'notices' and document.get('cursor') and failures < 2:
            failures += 1
            raise HistoryError('unavailable', 503)
        return await original(session, context, document, rooms)
    gate.server.history_query = fail_second_page
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'notice-home'), threads[-1], 'controller-noticefail',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert failures == 2
        assert b'PASS notice page failure is atomic' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_island_questions_are_complete_without_loading_bodies(gate, tmp_path):
    thread, recent = str(uuid.uuid4()), str(uuid.uuid4())
    await gate.send('alpha', 'first question\nhttps://example.invalid/answer\n내일 3시 회의', metadata={'thread_id':thread,'hejo_reply_state':'asked'})
    await gate.send('alpha', '생각 중...', metadata={'thread_id':thread,'hejo_reply_state':'asked'})
    # Owner response suppresses notices but does not rewrite the original asked flags.
    await gate.journal.append({'v':1,'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha','thread':thread,'role':'owner','text':'answer','files':[],'buttons':[],'reply_state':None,'ts':'2026-01-01T00:00:00Z'})
    await gate.send('alpha', 'recent', metadata={'thread_id':recent,'hejo_reply_state':'answered'})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'questions-home'), thread, 'controller-questions', recent,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=30)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS Island complete asked metadata' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_unloaded_attachment_uses_server_registration_not_legacy_cache(gate, tmp_path):
    async def chunks():
        yield b'fixture'
    info = await gate.files.stage('alpha', 'sample.txt', chunks())
    infos, _ = gate.files.promote('alpha', [info['file_id']])
    thread, recent, mid = str(uuid.uuid4()), str(uuid.uuid4()), str(uuid.uuid4())
    await gate.journal.append({'v':1,'type':'message','msg_id':mid,'employee':'alpha','thread':thread,'role':'employee','text':'attachment','files':infos,'buttons':[],'ts':'2026-01-01T00:00:00Z'}, {'files':gate.files.registration('alpha','employee',infos)})
    await gate.send('alpha', 'recent', metadata={'thread_id':recent})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'file-home'), recent, 'controller-file', info['file_id'],
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        ready = await asyncio.wait_for(process.stdout.readline(), timeout=15)
        if ready != b'FILE_READY\n':
            _, stderr = await asyncio.wait_for(process.communicate(), timeout=5)
            raise AssertionError(stderr.decode()[-3000:])
        await gate._record({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':thread})
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS unloaded attachment auth' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
@pytest.mark.parametrize('fault', ['delete', 'reconnect'])
async def test_attachment_inflight_generation_rejection(gate, tmp_path, monkeypatch, fault):
    """Pause authenticated file bytes; a deleted scope or new session cannot publish old bytes."""
    from aiohttp import web
    async def chunks():
        yield b'fixture'
    info = await gate.files.stage('alpha', 'sample.txt', chunks())
    infos, _ = gate.files.promote('alpha', [info['file_id']])
    thread, recent = str(uuid.uuid4()), str(uuid.uuid4())
    await gate.journal.append({'v':1,'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha','thread':thread,'role':'employee','text':'attachment','files':infos,'buttons':[],'ts':'2026-01-01T00:00:00Z'}, {'files':gate.files.registration('alpha','employee',infos)})
    await gate.send('alpha', 'recent', metadata={'thread_id':recent})
    entered, release = asyncio.Event(), asyncio.Event()
    original = web.FileResponse._sendfile
    async def paused(response, request, fobj, offset, count):
        if request.method == 'GET' and request.path.endswith('/'+info['file_id']) and not entered.is_set():
            entered.set()
            await asyncio.wait_for(release.wait(), 15)
        return await original(response, request, fobj, offset, count)
    monkeypatch.setattr(web.FileResponse, '_sendfile', paused)
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'file-home'), recent,
        'controller-file-'+fault, info['file_id'], stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        await asyncio.wait_for(entered.wait(), 15)
        if fault == 'delete':
            await gate._record({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':thread})
        else:
            for connection in tuple(gate.server.connections):
                await connection.close()
        observed = await asyncio.wait_for(process.stdout.readline(), 15)
        assert observed == b'FILE_FAULT_OBSERVED\n', observed
        release.set()
        stdout, stderr = await asyncio.wait_for(process.communicate(), 15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS in-flight attachment rejected' in stdout
    finally:
        release.set()
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_live_edit_invalidates_disk_body(gate, tmp_path):
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'first', metadata={'thread_id':thread})
    first = next(row['msg_id'] for row in gate.journal.records if row.get('type') == 'message')
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'cache-home'), thread, 'controller-cache',
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        assert await asyncio.wait_for(process.stdout.readline(), 15) == b'CACHE_READY\n'
        await gate._record({'v':1,'type':'edit','msg_id':first,'employee':'alpha','text':'edited','final':True})
        stdout, stderr = await asyncio.wait_for(process.communicate(), 15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS live edit invalidates persisted body' in stdout
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_receipt_after_lost_ack_and_duplicate_ack(gate, tmp_path, monkeypatch):
    """Lose only the owner echo, reconnect, then repeat the same durable acknowledgement."""
    from gate.server import Connection
    from gate.history import HistoryIndex
    receipts=[]
    original_receipt=HistoryIndex.receipt
    def receipt(index, identifier):
        receipts.append(identifier)
        return original_receipt(index,identifier)
    monkeypatch.setattr(HistoryIndex,'receipt',receipt)
    # The Hermes execution boundary is external to this HTTP/WS receipt check.
    # Keep receive routing/journal/auth real; never launch an actual employee turn.
    delivered=[]
    async def handle(event):
        delivered.append(event)
    monkeypatch.setattr(gate,'handle_message',handle)
    thread=str(uuid.uuid4())
    await gate.send('alpha','first',metadata={'thread_id':thread})
    accepted=asyncio.Event()
    dropped=[]
    enqueue=Connection.enqueue
    def lose_ack(connection, frame):
        if frame.get('role') == 'owner' and frame.get('text') == 'receipt fixture' and not dropped:
            dropped.append(frame.copy());accepted.set()
            future=asyncio.get_running_loop().create_future();future.set_result(False)
            return future
        return enqueue(connection,frame)
    monkeypatch.setattr(Connection,'enqueue',lose_ack)
    process=await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}',gate.auth.pair_code(),str(tmp_path/'receipt-home'),thread,'controller-receipt',
        stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
    try:
        await asyncio.wait_for(accepted.wait(),15)
        async with asyncio.timeout(5):
            while not delivered:
                await asyncio.sleep(0.01)
        for connection in tuple(gate.server.connections):
            await connection.close()
        assert await asyncio.wait_for(process.stdout.readline(),15) == b'RECEIPT_READY\n'
        for connection in tuple(gate.server.connections):
            await connection.send(dropped[0]);await connection.send(dropped[0])
        await gate.send('alpha','after duplicates',metadata={'thread_id':thread})
        stdout,stderr=await asyncio.wait_for(process.communicate(),15)
        assert process.returncode == 0,stderr.decode()[-3000:]
        assert b'PASS reconnect receipt' in stdout
        assert sum(row.get('client_msg_id') == dropped[0]['client_msg_id'] for row in gate.journal.records) == 1
        assert dropped[0]['client_msg_id'] in receipts
        assert len(delivered) == 1
    finally:
        if process.returncode is None:
            process.kill();await process.wait()


@pytest.mark.asyncio
@pytest.mark.parametrize('fault',['delete','reconnect'])
async def test_upload_access_change_discards_staged_result(gate,tmp_path,monkeypatch,fault):
    """Pause the real staging response; stale completion must not become a sendable attachment."""
    thread=str(uuid.uuid4())
    await gate.send('alpha','first',metadata={'thread_id':thread})
    entered,release=asyncio.Event(),asyncio.Event()
    original=gate.files.stage
    async def stage(*args,**kwargs):
        result=await original(*args,**kwargs)
        entered.set();await asyncio.wait_for(release.wait(),15)
        return result
    monkeypatch.setattr(gate.files,'stage',stage)
    process=await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}',gate.auth.pair_code(),str(tmp_path/'upload-home'),thread,'controller-upload-'+fault,
        stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
    try:
        await asyncio.wait_for(entered.wait(),15)
        if fault == 'delete':
            await gate._record({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':thread})
        else:
            for connection in tuple(gate.server.connections):
                await connection.close()
        assert await asyncio.wait_for(process.stdout.readline(),15) == b'UPLOAD_FAULT_OBSERVED\n'
        release.set()
        stdout,stderr=await asyncio.wait_for(process.communicate(),15)
        assert process.returncode == 0,stderr.decode()[-3000:]
        assert b'PASS upload result rejected' in stdout
        assert not any(row.get('role') == 'owner' for row in gate.journal.records)
    finally:
        release.set()
        if process.returncode is None:
            process.kill();await process.wait()


@pytest.mark.asyncio
@pytest.mark.parametrize('status',['notfound','deleted'])
async def test_receipt_missing_and_deleted_boundaries(gate,tmp_path,monkeypatch,status):
    from gate.server import Connection
    from gate.history import HistoryIndex
    thread=str(uuid.uuid4())
    await gate.send('alpha','first',metadata={'thread_id':thread})
    async def handle(event):
        pass  # external employee execution only
    monkeypatch.setattr(gate,'handle_message',handle)
    reached=asyncio.Event();captured=[];outcomes=[]
    receive=gate.receive;enqueue=Connection.enqueue;receipt=HistoryIndex.receipt
    async def intercept(frame,connection):
        captured.append(frame.copy())
        if status == 'notfound':
            reached.set();return
        return await receive(frame,connection)
    def drop(connection,frame):
        if frame.get('role') == 'owner' and frame.get('text') == 'boundary fixture':
            reached.set()
            done=asyncio.get_running_loop().create_future();done.set_result(False);return done
        return enqueue(connection,frame)
    def lookup(index,identifier):
        result=receipt(index,identifier);outcomes.append(result['status']);return result
    monkeypatch.setattr(gate,'receive',intercept)
    monkeypatch.setattr(Connection,'enqueue',drop)
    monkeypatch.setattr(HistoryIndex,'receipt',lookup)
    process=await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}',gate.auth.pair_code(),str(tmp_path/'receipt-home'),thread,'controller-receipt-'+status,
        stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
    try:
        await asyncio.wait_for(reached.wait(),15)
        if status == 'deleted':
            owner=next(row for row in gate.journal.records if row.get('client_msg_id') == captured[0]['client_msg_id'])
            # A durable deletion while the client's live channel is unavailable.
            await gate.journal.append({'v':1,'type':'delete','msg_id':owner['msg_id'],'room':'alpha','thread':thread})
        for connection in tuple(gate.server.connections):
            await connection.close()
        if status == 'notfound':
            assert await asyncio.wait_for(process.stdout.readline(),15) == b'NOTFOUND_READY\n'
            assert 'not_found' in outcomes and len(captured) == 1
            monkeypatch.setattr(Connection,'enqueue',enqueue)
            await receive(captured[0],next(iter(gate.server.connections)))
        stdout,stderr=await asyncio.wait_for(process.communicate(),15)
        assert process.returncode == 0,stderr.decode()[-3000:]
        assert b'PASS receipt boundary' in stdout
        assert ('not_found' if status == 'notfound' else 'deleted') in outcomes
        assert len(captured) == 1
    finally:
        if process.returncode is None:
            process.kill();await process.wait()


@pytest.mark.asyncio
async def test_unloaded_reply_and_explicit_new_post_intent(gate,tmp_path,monkeypatch):
    from gate.history import HistoryError
    old,retry,latest=[str(uuid.uuid4()) for _ in range(3)]
    for thread in (old,retry,latest):
        await gate.send('alpha','fixture original',metadata={'thread_id':thread})
    async def handle(event):
        pass  # Only external employee execution is replaced.
    monkeypatch.setattr(gate,'handle_message',handle)
    query=gate.server.history_query;rejected=False;resolved=[]
    async def fault(session,context,document,rooms):
        nonlocal rejected
        if document['kind']=='resolve' and isinstance(document.get('target'),dict):
            resolved.append(document.copy())
            if document['target']['thread']==retry and not rejected:
                rejected=True
                raise HistoryError('target_missing',404)
        return await query(session,context,document,rooms)
    monkeypatch.setattr(gate.server,'history_query',fault)
    process=await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}',gate.auth.pair_code(),str(tmp_path/'intent-home'),old,'controller-intent',retry,
        stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
    try:
        stdout,stderr=await asyncio.wait_for(process.communicate(),25)
        assert process.returncode==0,stderr.decode()[-3000:]
        assert b'PASS unloaded reply and explicit intent' in stdout
        owners=[r for r in gate.journal.records if r.get('role')=='owner']
        assert [(r['text'],r['thread']) for r in owners[:2]]==[('bubble fixture',old),('retry fixture',retry)]
        assert len(owners)==3 and owners[2]['text']=='new fixture'
        assert owners[2]['thread'] not in (old,retry,latest)
        assert rejected and all(r.get('limit')==1 for r in resolved)
    finally:
        if process.returncode is None:
            process.kill();await process.wait()


@pytest.mark.asyncio
async def test_unloaded_group_control_uses_whole_thread_speaker(gate,client,tmp_path,monkeypatch):
    from gate.tests.test_rooms import create
    ws,_=await client.pair(features=['rooms'])
    room=await create(client,ws);thread=str(uuid.uuid4())
    await gate.send('room:'+room,'fixture group',metadata={'hermes_profile':'beta','thread_id':thread})
    await gate.send('alpha','newest fixture',metadata={'thread_id':str(uuid.uuid4())})
    async def handle(event):
        pass
    monkeypatch.setattr(gate,'handle_message',handle)
    received=[];receive=gate.receive
    async def record(frame,connection):
        received.append(frame.copy());return await receive(frame,connection)
    monkeypatch.setattr(gate,'receive',record)
    process=await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}',gate.auth.pair_code(),str(tmp_path/'group-home'),thread,'controller-group',room,
        stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.PIPE)
    try:
        stdout,stderr=await asyncio.wait_for(process.communicate(),25)
        assert process.returncode==0,stderr.decode()[-3000:]
        assert b'PASS unloaded group control' in stdout
        sends=[r for r in received if r.get('type')=='send']
        assert [r['text'] for r in sends]==['group bubble','/stop']
        assert all(r['employee']=='beta' and r['room']==room and r['targeted'] for r in sends)
    finally:
        if process.returncode is None:
            process.kill();await process.wait()


@pytest.mark.asyncio
@pytest.mark.parametrize("fault", ["none", "edit", "context", "view", "view-long", "view-cycle", "view-root", "view-root-owner", "content-cancel"])
async def test_controller_restores_evicted_body_without_resetting_cursor(gate, tmp_path, fault, monkeypatch):
    # Four actual journal rows with a two-body injected budget, not a load run.
    original = gate.server.history_query
    restores = 0
    content_requests = 0
    content_waiting = asyncio.Event()
    release = asyncio.Event()
    async def count_restore(session, context, document, rooms):
        nonlocal restores
        if document['kind'] == 'resolve' and isinstance(document.get('target'), list) and document.get('limit') == 1:
            restores += 1
            if fault in ('edit', 'context') and restores == 1:
                stale = await original(session, context, document, rooms)
                await gate._record({'v':1,'type':'edit','msg_id':document['target'][0],'employee':'alpha','text':'restore edited body','final':True})
                await release.wait()
                return stale
            if fault == 'content-cancel':
                result = await original(session, context, document, rooms)
                result['items'] = [{'msg_id': row['msg_id'], 'revision': row['revision'],
                    'contentRef': session.content_ref(row['msg_id'], row['revision'])} for row in result['items']]
                return result
        return await original(session, context, document, rooms)
    if fault == 'content-cancel':
        from aiohttp import web
        import gate.history as history_module
        monkeypatch.setattr(history_module, 'CONTENT_CHUNK_BYTES', 64)
        prepare = web.Response.prepare
        async def delayed_content(response, request):
            nonlocal content_requests
            if request.path.endswith('/history/content'):
                content_requests += 1
                if content_requests == 2:
                    content_waiting.set()
                await asyncio.wait_for(release.wait(), 15)
            return await prepare(response, request)
        monkeypatch.setattr(web.Response, 'prepare', delayed_content)
    gate.server.history_query = count_restore
    thread = str(uuid.uuid4())
    for index in range(4):
        body = f'restore fixture {index}'
        if fault in ('view-long', 'view-cycle'):
            body += '\n' + '\n'.join(f'paragraph {line}: reading fixture' for line in range(24))
        if fault == 'view-root-owner' and index == 0:
            await gate._record({'v':1,'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha',
                                'role':'owner','thread':thread,'text':body,'files':[],'buttons':[],'reply_state':None,'ts':'2026-01-01T00:00:00Z'})
        else:
            await gate.send('alpha', body, metadata={'thread_id': thread})
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'restore-home'), thread, 'controller-restore', fault,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        if fault == 'content-cancel':
            signal = await asyncio.wait_for(process.stdout.readline(), 15)
            if signal != b'CONTENT_PIN_REPLACED\n':
                _, stderr = await asyncio.wait_for(process.communicate(), 5)
                raise AssertionError(stderr.decode()[:2500])
            await asyncio.wait_for(content_waiting.wait(), 5)
            release.set()
        if fault in ('edit', 'context'):
            assert await asyncio.wait_for(process.stdout.readline(), 15) == b'RESTORE_EDIT_SEEN\n'
            release.set()
        if fault == 'view-cycle':
            assert await asyncio.wait_for(process.stdout.readline(), 15) == b'VIEW_CYCLE_STARTED\n'
        ready = await asyncio.wait_for(process.stdout.readline(), 15)
        if ready != b'RESTORE_READY\n':
            _, stderr = await asyncio.wait_for(process.communicate(), 5)
            raise AssertionError(f'exit={process.returncode}; {stderr.decode()[:2500]}')
        if fault in ('none', 'view-root', 'view-root-owner'):
            assert restores == 1
        elif fault in ('view', 'view-long'):
            assert restores == 2
        elif fault == 'view-cycle':
            assert restores == 6
        elif fault == 'content-cancel':
            assert restores == 7
            assert content_requests > restores
        await gate._record({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':thread})
        stdout, stderr = await asyncio.wait_for(process.communicate(), timeout=15)
        assert process.returncode == 0, stderr.decode()[-3000:]
        assert b'PASS evicted body restored without cursor reset' in stdout
        if fault in ('view', 'view-long', 'view-cycle'):
            stages = [line for line in stderr.decode().splitlines() if line.startswith('RESTORE_STAGE ')]
            assert stages == ['RESTORE_STAGE '+stage for stage in (
                'initial-open', 'initial-open-complete', 'view-ready', 'first-wheel',
                'first-restore-complete', 'second-wheel', 'anchor-settled')]
    except TimeoutError as error:
        # Preserve the failed phase and Swift error before reaping a crashed/hung child.
        if process.returncode is None:
            process.kill()
        stdout, stderr = await process.communicate()
        stages = [line for line in stderr.decode().splitlines() if line.startswith('RESTORE_STAGE ')]
        raise AssertionError(f'restore timeout fault={fault} restores={restores} stages={stages}; '
                             f'stdout={stdout.decode()[-1000:]}; stderr={stderr.decode()[-4000:]}') from error
    finally:
        release.set()
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
@pytest.mark.parametrize("fault", ["none", "cancel"])
async def test_attachment_budget_preserves_active_reader(gate, tmp_path, monkeypatch, fault):
    from aiohttp import web
    async def chunks():
        yield b'fixture'
    infos = []
    for _ in range(2):
        staged = await gate.files.stage('alpha', 'sample.txt', chunks())
        promoted, _ = gate.files.promote('alpha', [staged['file_id']])
        infos.extend(promoted)
    thread = str(uuid.uuid4())
    await gate.journal.append({'v':1,'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha','thread':thread,'role':'employee','text':'attachment budget','files':infos,'buttons':[],'ts':'2026-01-01T00:00:00Z'}, {'files':gate.files.registration('alpha','employee',infos)})
    release = asyncio.Event()
    original = web.FileResponse.prepare
    heads = 0
    async def paused(response, request):
        nonlocal heads
        if request.method == 'HEAD' and request.path.endswith('/'+infos[0]['file_id']):
            heads += 1
            if heads == 2:
                await asyncio.wait_for(release.wait(), 15)
        return await original(response, request)
    monkeypatch.setattr(web.FileResponse, 'prepare', paused)
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'budget-home'), thread,
        'controller-file-budget', infos[0]['file_id'], infos[1]['file_id'], fault, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        ready = await asyncio.wait_for(process.stdout.readline(), 15)
        if ready != b'FILE_PIN_READY\n':
            _, stderr = await asyncio.wait_for(process.communicate(), 5)
            raise AssertionError(stderr.decode()[:2500])
        assert heads == 2
        release.set()
        stdout, stderr = await asyncio.wait_for(process.communicate(), 15)
        assert process.returncode == 0, stderr.decode()[:2500]
        assert b'PASS attachment budget' in stdout
    finally:
        release.set()
        if process.returncode is None:
            process.kill(); await process.wait()


@pytest.mark.asyncio
async def test_authenticated_thumbnail_view_lifetime(gate, tmp_path, monkeypatch):
    """Actual file GET -> View tiles -> cell recreation -> authoritative deletion releases pixels."""
    import struct
    import zlib
    from aiohttp import web
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 640, 320, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress((b'\x00' + b'\x20\x40\x60\xff' * 640) * 320)) + chunk(b'IEND', b''))
    async def chunks():
        yield png
    infos = []
    for _ in range(2):
        staged = await gate.files.stage('alpha', 'fixture.png', chunks())
        promoted, _ = gate.files.promote('alpha', [staged['file_id']])
        infos.extend(promoted)
    thread = str(uuid.uuid4())
    await gate.journal.append({'v':1,'type':'message','msg_id':str(uuid.uuid4()),'employee':'alpha','thread':thread,
        'role':'employee','text':'image fixture','files':infos,'buttons':[],'ts':'2026-01-01T00:00:00Z'},
        {'files':gate.files.registration('alpha','employee',infos)})
    gets = []
    original = web.FileResponse.prepare
    async def observed(response, request):
        if request.method == 'GET' and any(request.path.endswith('/'+row['file_id']) for row in infos):
            gets.append(request.path)
        return await original(response, request)
    monkeypatch.setattr(web.FileResponse, 'prepare', observed)
    process = await asyncio.create_subprocess_exec(str(Path('app/.build/history-transport-tests').resolve()),
        f'127.0.0.1:{gate.server.port}', gate.auth.pair_code(), str(tmp_path/'image-home'), thread,
        'controller-image', stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        ready = await asyncio.wait_for(process.stdout.readline(), 15)
        if ready != b'IMAGE_READY\n':
            _, stderr = await asyncio.wait_for(process.communicate(), 5)
            raise AssertionError(stderr.decode()[-2500:])
        assert len(gets) == 2
        await gate._record({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':thread})
        _, stderr = await asyncio.wait_for(process.communicate(), 15)
        assert process.returncode == 0, stderr.decode()[-2500:]
        assert len(gets) == 2
    finally:
        if process.returncode is None:
            process.kill(); await process.wait()
