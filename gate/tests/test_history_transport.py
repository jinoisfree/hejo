"""Real HTTP/WS history boundaries using isolated journal and device credentials."""
import json
import uuid
import pytest
from aiohttp import ClientSession
from gate.tests.support import airport, registered, gate, client


def context(session, generation=1, **changes):
    return {'session': session, 'generation': generation, 'memberRevision': 0, 'ready': True,
            'items': {}, 'home': ['alpha'], 'hidden': [], 'names': {}, 'now': 1767225600, **changes}


@pytest.mark.asyncio
async def test_history_starts_at_head_then_live_and_old_mode_still_replays(gate, client):
    thread = str(uuid.uuid4())
    sent = await gate.send('alpha', 'history', metadata={'thread_id': thread})
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    assert welcome['history']['through'] == welcome['head_seq'] == gate.journal.head
    await ws.send_json({'v': 1, 'type': 'roster', 'id': 'fixture-roster'})
    assert (await client.read(ws))['type'] == 'roster'  # No initial history/sync_done frames.
    await gate.send('alpha', 'live', metadata={'thread_id': thread})
    live = await client.read(ws)
    assert live['type'] == 'message' and live['seq'] == welcome['head_seq'] + 1
    await ws.send_json({'v': 1, 'type': 'sync', 'id': 'fixture-sync', 'since': 0})
    assert (await client.read(ws))['code'] == 'unsupported_mode'
    old, _ = await client.open(token=welcome['token'], since=0, features=['rooms'])
    frames = await client.until(old, 'sync_done')
    assert frames[0]['msg_id'] == sent.message_id
    assert [f['seq'] for f in frames[:-1]] == [1, 2]


@pytest.mark.asyncio
async def test_authenticated_context_query_and_disconnected_session(gate, client):
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'first', metadata={'thread_id': thread})
    await gate.send('alpha', 'second', metadata={'thread_id': thread})
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    other, other_welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    headers = {'Authorization': 'Bearer ' + welcome['token']}
    session = welcome['history']['session']
    async with ClientSession(trust_env=False) as http:
        async with http.post(base+'context', json=context(session)) as response:
            assert response.status == 401
        async with http.post(base+'context', json=context(session),
                             headers={'Authorization':'Bearer '+other_welcome['token']}) as response:
            assert response.status == 403
        async with http.post(base+'context', json=context(session), headers=headers) as response:
            assert response.status == 200
            installed = await response.json()
        request = {'session': session, 'context': installed['context'], 'request': 'fixture-query',
                   'kind': 'messages', 'scope': 'alpha', 'target': {'room': 'alpha', 'thread': thread}, 'limit': 1}
        async with http.post(base+'query', json=request, headers=headers) as response:
            assert response.status == 200
            page = await response.json()
            assert [m['text'] for m in page['items']] == ['second'] and page['next']
        async with http.post(base+'query', json={**request, 'cursor': page['next']}, headers=headers) as response:
            older = await response.json()
            assert [m['text'] for m in older['items']] == ['first'] and older['complete']
        # The request transport must not write journal data.
        assert gate.journal.head == 2
        await ws.close()
        async with http.post(base+'query', json=request, headers=headers) as response:
            assert response.status == 409
            assert (await response.json())['code'] == 'session_expired'
    await other.close()


@pytest.mark.asyncio
async def test_context_generation_limits_and_invalid_json(gate, client):
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    session = welcome['history']['session']
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    headers = {'Authorization': 'Bearer '+welcome['token']}
    async with ClientSession(trust_env=False, headers=headers) as http:
        installed = []
        for generation in [1, 2, 3]:
            async with http.post(base+'context', json=context(session, generation)) as response:
                assert response.status == 200
                installed.append(await response.json())
        async with http.post(base+'context', json=context(session, 3)) as response:
            assert await response.json() == installed[-1]
        async with http.post(base+'context', json=context(session, 2)) as response:
            assert response.status == 409
        for data in [context(session, 4, home=['not-in-roster']),
                     context(session, 4, items={'read:alpha':{'v':'-1','at':0,'dev':'fixture'}}),
                     context(session, 4, names={'not-in-roster':'fixture'})]:
            async with http.post(base+'context', json=data) as response:
                assert response.status == 400
        for raw in ['{"session": NaN}', '{"invalid":', json.dumps(context(session, 4)).replace('1767225600','1e999')]:
            async with http.post(base+'context', data=raw) as response:
                assert response.status == 400
        async with http.post(base+'context', data=b' ' * (2097152+1)) as response:
            assert response.status == 413
        query = {'session':session,'context':installed[0]['context'],'request':'fixture-query',
                 'kind':'receipt','scope':'alpha','target':['fixture-unsent']}
        async with http.post(base+'query', json=query) as response:
            assert response.status == 409
        async with http.post(base+'query', json={**query,'context':installed[-1]['context']}) as response:
            result = await response.json()
            assert result['items'] == [{'client_msg_id':'fixture-unsent','status':'not_found'}]
    await ws.close()


@pytest.mark.asyncio
async def test_summaries_search_and_read_plan_use_unloaded_messages(gate, client):
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc).timestamp()
    question = str(uuid.uuid4())
    alert = str(uuid.uuid4())
    first = await gate.send('alpha', '승인해 줘', metadata={'thread_id': question, 'hejo_reply_state': 'asked'})
    second = await gate.send('alpha', '과거 한글 검색', metadata={'thread_id': alert})
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False, headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context', json=context(welcome['history']['session'], now=now+1)) as response:
            installed = await response.json()
        common = {'session':welcome['history']['session'],'context':installed['context'],
                  'request':'fixture-query','scope':'alpha'}
        async def query(**values):
            async with http.post(base+'query', json={**common, **values}) as response:
                assert response.status == 200, await response.text()
                return await response.json()
        # No messages request was made: complete counts still include both threads.
        overview = await query(kind='overview')
        assert overview['totals']['unread'] == 2
        assert overview['totals']['questions'] == overview['totals']['alerts'] == 1
        threads = await query(kind='threads',limit=1)
        assert threads['items'][0]['key']['thread'] == alert and threads['next']
        notices = await query(kind='notices')
        assert [n['id'] for n in notices['items']] == [first.message_id, second.message_id]
        found = await query(kind='search',mode='groups',query='한글 검색')
        assert [m['id'] for m in found['items'][0]['matches']] == [second.message_id]
        plan = await query(kind='read_plan',action='enter',limit=1)
        # Both threads ring. Entering does not silently read either one.
        assert plan['changes'] == {'read:alpha':'0'}
        assert gate.journal.head == 2
        # An unfinished mark-all plan stays at its original head even with a new message.
        plan = await query(kind='read_plan',action='mark_all',limit=1)
        await gate.send('alpha','new arrival',metadata={'thread_id':alert})
        changes = dict(plan['changes'])
        while plan['next']:
            plan = await query(kind='read_plan',action='mark_all',limit=1,cursor=plan['next'])
            assert plan['through'] == 2
            changes.update(plan['changes'])
        assert changes['read:alpha'] == '2'
        assert changes['thread:alpha/'+alert] == '2'
        assert 'bell:alpha/'+question not in changes
    await ws.close()


@pytest.mark.asyncio
async def test_search_cursor_removal_is_not_a_message_deletion(gate, client):
    a, b = str(uuid.uuid4()), str(uuid.uuid4())
    old = await gate.send('alpha','검색 대상',metadata={'thread_id':a})
    new = await gate.send('alpha','검색 대상',metadata={'thread_id':b})
    ws,welcome=await client.pair(since=0,features=['rooms','history-v1'])
    base=f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False,headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context',json=context(welcome['history']['session'])) as response:
            installed=await response.json()
        request={'session':welcome['history']['session'],'context':installed['context'],'request':'fixture-search',
                 'kind':'search','scope':'alpha','mode':'sidebar','query':'검색','limit':1}
        async with http.post(base+'query',json=request) as response:
            first=await response.json()
        assert first['next']
        remaining = old.message_id if first['items'][0]['id'] != old.message_id else new.message_id
        await gate.edit_message('alpha',remaining,'다른 내용',finalize=True)
        async with http.post(base+'query',json={**request,'cursor':first['next']}) as response:
            older=await response.json()
        assert older['items'][0]['removed'] is True
        assert 'deleted' not in older['items'][0]
        assert gate.journal.history.message(remaining)['text']=='다른 내용'
    await ws.close()


@pytest.mark.asyncio
async def test_anchor_resolves_unloaded_position_and_keeps_real_root(gate, client):
    thread = str(uuid.uuid4())
    sent = [await gate.send('alpha', f'line {i}', metadata={'thread_id': thread}) for i in range(5)]
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False, headers={'Authorization': 'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context', json=context(welcome['history']['session'])) as response:
            installed = await response.json()
        request = {'session': welcome['history']['session'], 'context': installed['context'],
                   'request': 'fixture-anchor', 'kind': 'resolve', 'scope': 'alpha', 'limit': 2,
                   'target': {'room': 'alpha', 'thread': thread}, 'anchor': sent[1].message_id}
        async with http.post(base+'query', json=request) as response:
            assert response.status == 200
            page = await response.json()
        assert [m['text'] for m in page['items']] == ['line 1', 'line 2']
        assert page['root']['rootID'] == sent[0].message_id
        assert page['root']['messageCount'] == 5 and page['newerCount'] == 2
        async with http.post(base+'query', json={**request, 'cursor': page['next']}) as response:
            older = await response.json()
            assert [m['text'] for m in older['items']] == ['line 0'] and older['complete']
        for changes, status in [({'anchor': 'fixture-missing'}, 404), ({'mode': 'groups'}, 400),
                                ({'kind': 'copy'}, 400), ({'target': [sent[0].message_id]}, 400)]:
            async with http.post(base+'query', json={**request, **changes}) as response:
                assert response.status == status
        async with http.post(base+'context', json=context(welcome['history']['session'], 2, now=10**400)) as response:
            assert response.status == 400
    await ws.close()


@pytest.mark.asyncio
async def test_capability_room_locale_search_and_response_contract(gate, client):
    from jsonschema import Draft202012Validator
    from gate.server import HISTORY_SCHEMA
    def validate(kind, value):
        Draft202012Validator({**HISTORY_SCHEMA, 'oneOf':[{'$ref':'#/$defs/'+kind}]}).validate(value)
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'Istanbul', metadata={'thread_id':thread})
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False) as http:
        async with http.get(base+'capabilities') as response:
            capability = await response.json()
            assert response.status == 200
            assert set(capability) == {'version','mode','limits'}
            assert capability['version'] == 1 and capability['mode'] == 'history-v1'
            assert capability['limits']['page_items'] == 50
    ws, welcome = await client.pair(since=0, features=['rooms','history-v1'])
    async with ClientSession(trust_env=False, headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context',json=context(welcome['history']['session'],locale='tr_TR')) as response:
            installed = await response.json(); validate('contextResponse', installed)
        common = {'session':welcome['history']['session'],'context':installed['context'],
                  'request':'fixture-contract','scope':'alpha'}
        for values in [{'kind':'search','mode':'room','query':'ıstan'}, {'kind':'threads'},
                       {'kind':'overview'}, {'kind':'messages','target':{'room':'alpha','thread':thread}},
                       {'kind':'read_plan','action':'enter'}]:
            async with http.post(base+'query', json={**common,**values}) as response:
                assert response.status == 200
                result = await response.json(); validate('queryResponse',result)
                if values['kind']=='search':
                    assert [row['key']['thread'] for row in result['items']] == [thread]
                    validate('summary', result['items'][0])
        async with http.post(base+'query',json={**common,'scope':'home','kind':'search','mode':'room','query':'ıstan'}) as response:
            assert response.status == 400; validate('errorResponse',await response.json())
    await ws.close()


@pytest.mark.asyncio
async def test_sidebar_metadata_and_seed_cover_roster_without_widening_messages(gate, client):
    await gate.send('beta', 'outside home scope', metadata={'thread_id':str(uuid.uuid4())})
    ws, welcome = await client.pair(since=0, features=['rooms','history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False,headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context',json=context(welcome['history']['session'])) as response:
            installed = await response.json()
        common = {'session':welcome['history']['session'],'context':installed['context'],
                  'request':'fixture-sidebar','scope':'home','mode':'sidebar'}
        async with http.post(base+'query',json={**common,'kind':'overview'}) as response:
            assert response.status == 200
            result = await response.json()
            beta = next(row for row in result['items'] if row['id']=='beta')
            assert beta['latestSeq'] == 1 and beta['latestActivity'] > 0
        async with http.post(base+'query',json={**common,'kind':'read_plan','action':'seed'}) as response:
            assert response.status == 200
            assert (await response.json())['changes']['read:beta'] == '1'
        for extra in [{'kind':'read_plan','action':'mark_all'}, {'kind':'overview','scope':'alpha'},
                      {'kind':'messages','target':{'room':'beta','thread':'fixture'}}]:
            async with http.post(base+'query',json={**common,**extra}) as response:
                assert response.status == 400
    await ws.close()


@pytest.mark.asyncio
async def test_global_search_ignores_home_filter_but_keeps_authorization(gate, client):
    thread = str(uuid.uuid4())
    message = await gate.send('alpha', 'fixture global search', metadata={'thread_id':thread})
    ws, welcome = await client.pair(since=0, features=['rooms','history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False,headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context',json=context(welcome['history']['session'],home=[])) as response:
            assert response.status == 200
            installed = await response.json()
        common = {'session':welcome['history']['session'],'context':installed['context'],
                  'request':'fixture-search','scope':'home','kind':'search','query':'global'}
        for mode in ['groups','sidebar']:
            async with http.post(base+'query',json={**common,'mode':mode}) as response:
                assert response.status == 200
                page = await response.json()
                hit = page['items'][0]['matches'][0] if mode == 'groups' else page['items'][0]
                assert hit['id'] == message.message_id
                assert hit['key']['room'] == 'alpha'
                from jsonschema import Draft202012Validator
                from gate.server import HISTORY_SCHEMA
                definition = 'searchGroup' if mode == 'groups' else 'searchHit'
                Draft202012Validator({**HISTORY_SCHEMA,'oneOf':[{'$ref':'#/$defs/'+definition}]}).validate(page['items'][0])
        async with http.post(base+'query',json={**common,'mode':'groups','scope':'not-authorized'}) as response:
            assert response.status == 404
    await ws.close()


@pytest.mark.asyncio
async def test_global_notice_metadata_ignores_home_filter(gate, client):
    from datetime import datetime, timezone
    thread = str(uuid.uuid4())
    sent = await gate.send('alpha', '\nfixture notice\nbody', metadata={'thread_id':thread})
    ws, welcome = await client.pair(since=0, features=['rooms','history-v1'])
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False,headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async with http.post(base+'context',json=context(welcome['history']['session'],home=[],now=datetime.now(timezone.utc).timestamp()+1)) as response:
            installed = await response.json()
        request = {'session':welcome['history']['session'],'context':installed['context'],
                   'request':'fixture-notices','scope':'home','kind':'notices'}
        async with http.post(base+'query',json=request) as response:
            assert (await response.json())['items'] == []
        async with http.post(base+'query',json={**request,'mode':'sidebar'}) as response:
            assert response.status == 200
            rows = (await response.json())['items']
            assert len(rows) == 1 and rows[0]['id'] == sent.message_id
            assert rows[0]['preview'] == 'fixture notice' and rows[0]['speaker'] == 'alpha'
            assert rows[0]['timestamp'] and 'text' not in rows[0]
        async with http.post(base+'query',json={**request,'mode':'sidebar','scope':'alpha'}) as response:
            assert response.status == 400
    await ws.close()


@pytest.mark.asyncio
async def test_bubble_message_state_is_metadata_authorized_and_read_aware(gate, client):
    thread = str(uuid.uuid4())
    sent = await gate.send('alpha', 'body must not be in metadata', metadata={'thread_id':thread})
    ws, welcome = await client.pair(since=0, features=['rooms','history-v1'])
    session = welcome['history']['session']
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    async with ClientSession(trust_env=False,headers={'Authorization':'Bearer '+welcome['token']}) as http:
        async def install(generation, **extra):
            async with http.post(base+'context',json=context(session,generation,home=[],**extra)) as response:
                assert response.status == 200
                return (await response.json())['context']
        token = await install(1)
        request = {'session':session,'context':token,'request':'fixture-state','scope':'home','kind':'message_state','target':[sent.message_id,'absent']}
        async with http.post(base+'query',json=request) as response:
            assert response.status == 200
            rows = (await response.json())['items']
            from jsonschema import validate
            from gate.server import HISTORY_SCHEMA
            for row in rows:
                validate(row, {'$ref':'#/$defs/messageState','$defs':HISTORY_SCHEMA['$defs']})
            assert rows == [{'id':sent.message_id,'status':'present','key':{'room':'alpha','thread':thread},'seq':1,'revision':1,'read':False,'eligible':True},{'id':'absent','status':'missing'}]
        for changes in [{'scope':'alpha'},{'mode':'sidebar'},{'target':{'room':'alpha','thread':thread}},{'limit':1}]:
            async with http.post(base+'query',json={**request,**changes}) as response:
                assert response.status == 400
        token = await install(2,items={'read:alpha':{'v':'1','at':1,'dev':'fixture'}})
        async with http.post(base+'query',json={**request,'context':token}) as response:
            assert (await response.json())['items'][0]['read'] is True
        # Foreign room IDs must be indistinguishable from unknown IDs.
        await gate.journal.append({'v':1,'type':'message','msg_id':'foreign','employee':'unlisted','thread':thread,'role':'employee','text':'private fixture','files':[],'buttons':[],'ts':'2026-01-01T00:00:00Z'})
        async with http.post(base+'query',json={**request,'context':token,'target':['foreign']}) as response:
            assert (await response.json())['items'] == [{'id':'foreign','status':'missing'}]
        await gate.journal.append({'v':1,'type':'delete','msg_id':sent.message_id})
        async with http.post(base+'query',json={**request,'context':token}) as response:
            assert (await response.json())['items'][0] == {'id':sent.message_id,'status':'deleted','revision':3}
        other = await gate.send('alpha', 'thread target', metadata={'thread_id':str(uuid.uuid4())})
        # The actual thread deletion path must also produce an authoritative tombstone.
        message = gate.journal.message(other.message_id)
        await gate.journal.append({'v':1,'type':'delete','scope':'thread','room':'alpha','thread':message['thread']})
        async with http.post(base+'query',json={**request,'context':token,'target':[other.message_id]}) as response:
            assert (await response.json())['items'] == [{'id':other.message_id,'status':'deleted','revision':5}]
        token = await install(3,ready=False)
        async with http.post(base+'query',json={**request,'context':token}) as response:
            assert response.status == 409
    await ws.close()


@pytest.mark.asyncio
async def test_history_wire_byte_boundaries_and_journal_preservation(gate, client, monkeypatch):
    from gate.history import encoded

    await gate.send('alpha', 'fixture journal sentinel')
    def originals():
        return {p.name: p.read_bytes() for p in gate.journal.path.glob('*.jsonl')}

    before = originals()
    assert before
    ws, welcome = await client.pair(since=0, features=['rooms', 'history-v1'])
    session = welcome['history']['session']
    base = f'http://127.0.0.1:{gate.server.port}/v1/history/'
    headers = {'Authorization': 'Bearer ' + welcome['token']}
    async with ClientSession(trust_env=False, headers=headers) as http:
        async def post(endpoint, payload, status):
            async with http.post(base + endpoint, data=payload) as response:
                assert response.status == status
                return await response.json()

        async def boundary(endpoint, document, size):
            exact = encoded(document).ljust(size, b' ')
            assert len(exact) == size
            result = await post(endpoint, exact, 200)
            error = await post(endpoint, exact + b' ', 413)
            assert error == {'code': 'too_large', 'request': None, 'retryable': False}
            return result

        installed = await boundary('context', context(session), 2 * 1024 * 1024)
        query = {'session': session, 'context': installed['context'], 'request': 'fixture-ref',
                 'kind': 'overview', 'scope': 'alpha'}
        await boundary('query', query, 64 * 1024)
        private_scope = {**query, 'scope': 'fixture-private-scope'}
        assert await post('query', encoded(private_scope), 404) == {
            'code': 'target_missing', 'request': 'fixture-ref', 'retryable': False}

        search = {**query, 'kind': 'search', 'mode': 'sidebar', 'query': 'é' * 2048}
        await post('query', encoded(search), 200)
        search['query'] += 'x'
        assert await post('query', encoded(search), 413) == {
            'code': 'too_large', 'request': 'fixture-ref', 'retryable': False}

        # Inject only the result of the query to exercise the final encoder guard.
        result = {'value': ''}
        result['value'] = 'x' * (512 * 1024 - len(encoded(result)))
        async def fixed_result(*args):
            return result
        monkeypatch.setattr(gate.server, 'history_query', fixed_result)
        assert await post('query', encoded(query), 200) == result
        result['value'] += 'x'
        assert await post('query', encoded(query), 413) == {
            'code': 'too_large', 'request': 'fixture-ref', 'retryable': False}
    await ws.close()
    gate.journal._recover()
    assert originals() == before
