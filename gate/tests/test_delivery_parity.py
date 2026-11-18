"""AT99: Slack-path delivery semantics through the public hejo adapter boundary."""
import asyncio
import json
import os
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch
import uuid

import pytest

from gate.journal import HejoJournalError
from gate.tests.support import wait_for_turns

pytestmark = pytest.mark.asyncio


@pytest.fixture(autouse=True)
def allow_owner(airport, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')



@pytest.mark.parametrize('text', ['x'*5000, '한'*30000, ('line\n'*18000), '😀'*40000])
async def test_long_text_is_lossless_bounded_and_buttons_last(gate, text):
    sent = await gate.send('alpha', text, metadata={'hejo_buttons':[{'label':'Next','style':'primary'}]})
    assert sent.success
    rows = [r for r in gate.journal.records if r['type']=='message']
    assert ''.join(r['text'] for r in rows) == text
    assert len({r['thread'] for r in rows}) == 1
    assert all(len(r['text'].encode()) <= 65536 for r in rows)
    assert all(not r['buttons'] for r in rows[:-1]) and len(rows[-1]['buttons']) == 1
    assert [r['seq'] for r in rows] == list(range(1, len(rows)+1))
    assert sent.message_id == rows[-1]['msg_id']


async def test_line_boundary_and_stream_overflow_then_shorter_final(gate):
    first = 'a'*60000+'\n'
    sent = await gate.send('alpha','start', metadata={'expect_edits':True})
    for text in (first+'한'*30000, first+'한'*50000, 'short final'):
        final = text == 'short final'
        assert (await gate.edit_message('alpha', sent.message_id, text, finalize=final,
            metadata={'hejo_buttons':[{'label':'Done','style':'default'}]})).success
        rows = [gate.journal.message(r['msg_id']) for r in gate.journal.records if r['type']=='message']
        rows = [r for r in rows if r]
        assert ''.join(r['text'] for r in rows) == text
        assert all(len(r['text'].encode()) <= 65536 for r in rows)
        assert all(not r['buttons'] for r in rows[:-1]) and rows[-1]['buttons']
        if not final:
            assert rows[0]['text'] == first and rows[-1]['final'] is False
    assert gate.journal.message(sent.message_id)['final'] is True
    assert [r['seq'] for r in gate.journal.page(0)] == list(range(1,gate.journal.head+1))


async def test_partial_record_failure_keeps_committed_piece_without_seq_gap(gate, monkeypatch):
    append = gate.journal.append
    count = 0
    async def fail(frame, internal=None):
        nonlocal count
        count += 1
        if count == 2:
            raise HejoJournalError('injected_write_failure')
        return await append(frame, internal)
    monkeypatch.setattr(gate.journal, 'append', fail)
    result = await gate.send('alpha', '한'*50000)
    assert not result.success
    assert len(gate.journal.records) == 1
    assert gate.journal.records[0]['seq'] == gate.journal.head == 1
    assert gate.journal.records[0]['text'] == '한'*21845


async def test_cold_thread_context_uses_official_store_without_persistent_mirror(gate, runner, client, airport):
    from gateway.session import SessionStore
    from gateway.config import GatewayConfig
    store = SessionStore(airport/'sessions', GatewayConfig(multiplex_profiles=True))
    gate.set_session_store(store)
    thread = str(uuid.uuid4())
    await gate.send('alpha', 'scheduled report', metadata={'thread_id':thread})
    ws, _ = await client.pair(since=gate.journal.head)
    await client.read(ws)
    await client.send(ws, thread=thread, text='first reply')
    await client.read(ws)
    await wait_for_turns(runner, 1)
    event = runner.events[-1]
    assert event.text == 'first reply' and event.channel_context.endswith(': scheduled report')
    assert event.channel_context.count('[이전 스레드 대화]') == 1
    entry = store.get_or_create_session(event.source)
    assert store.lookup_by_session_key(gate._source_session_key(event.source)) is entry
    await client.send(ws, thread=thread, text='second reply')
    await client.read(ws)
    await wait_for_turns(runner, 2)
    assert runner.events[-1].channel_context is None
    # Explicit suspension, unlike elapsed time, opens a fresh conversation.
    entry.suspended = True
    await client.send(ws, thread=thread, text='after suspension')
    await client.read(ws)
    await wait_for_turns(runner, 3)
    assert 'second reply' in runner.events[-1].channel_context
    await ws.close()


async def test_context_bounds_and_branch_is_not_injected_twice(gate, runner, client):
    thread=str(uuid.uuid4())
    for index in range(60):
        await gate.send('alpha', str(index)+' '+('한'*3000), metadata={'thread_id':thread})
    await gate.send('alpha','생각 중...', metadata={'thread_id':thread})
    ws,_=await client.pair(since=gate.journal.head);await client.read(ws);await client.send(ws, thread=thread)
    await client.read(ws)
    await wait_for_turns(runner, 1)
    context=runner.events[-1].channel_context
    assert len(context.split('\n',1)[1]) <= 16000
    assert len(context.splitlines()[1:]) <= 50
    assert '생각 중' not in context and '59 ' in context
    assert all(len(line.split(': ',1)[-1]) <= 2000 for line in context.splitlines()[1:])
    await ws.close()


async def test_native_labels_outcome_and_repeat_are_idempotent(gate, client, monkeypatch, airport):
    from agent.i18n import reset_language_cache, t
    (airport/'config.yaml').write_text('display:\n  language: ko\n')
    reset_language_cache()
    ws,_=await client.pair()
    with patch('tools.slash_confirm.resolve', new_callable=AsyncMock, return_value='done') as resolver:
        sent=await gate.send_slash_confirm('alpha','Confirm','Question','fake-session','fake-confirm')
        message=await client.read(ws)
        assert [b['label'] for b in message['buttons']] == ['한 번 승인','항상 승인','취소']
        click={'v':1,'type':'click','msg_id':sent.message_id,'button_id':message['buttons'][0]['id']}
        await ws.send_json(click)
        edit=await client.read(ws)
        assert edit['type']=='edit' and edit['buttons']==[] and '한 번 승인' in edit['text']
        assert edit['text'].rsplit('\n\n',1)[-1]==t('platform.telegram.slash_confirm.resolved_once')
        assert '이(가)' not in edit['text']
        await ws.send_json(click)
        await ws.send_json({'v':1,'type':'roster','id':'barrier'})
        assert (await client.read(ws))['ref']=='barrier'
        assert resolver.await_count==1
    await gate.send_clarify('alpha','Choose',['A'],'fake-clarify','fake-session')
    assert (await client.read(ws))['buttons'][-1]['label']=='✏️ 기타…'
    reset_language_cache()
    await ws.close()


async def test_link_image_and_local_voice_video_become_owned_attachments(gate, airport):
    import httpx
    from tools import url_safety
    image=b'\x89PNG\r\n\x1a\nfixture'
    async def handle(request): return httpx.Response(200, headers={'content-type':'image/png'}, content=image)
    with patch.object(url_safety,'is_safe_url',return_value=True), patch.object(url_safety,'create_ssrf_safe_async_client',
        side_effect=lambda **kw:httpx.AsyncClient(transport=httpx.MockTransport(handle),**kw)):
        assert (await gate.send_image('alpha','https://media.invalid/image.png')).success
    for method,name,content in ((gate.send_voice,'sound.ogg',b'OggSfixture'),(gate.send_video,'movie.mp4',b'fixture-video')):
        file=airport/name;file.write_bytes(content)
        assert (await method('alpha',str(file))).success
    rows=[r for r in gate.journal.records if r['type']=='message']
    assert [r['files'][0]['mime'] for r in rows]==['image/png','audio/ogg','video/mp4']
    for row,expected in zip(rows,[image,b'OggSfixture',b'fixture-video']):
        path,_=gate.files.registered('alpha',row['files'][0]['file_id'])
        assert path.read_bytes()==expected and (path.stat().st_mode & 0o777)==0o600
        assert str(airport) not in json.dumps({k:v for k,v in row.items() if k!='_meta'})


async def test_blocked_or_nonimage_url_is_text_notice_without_host_paths(gate):
    import httpx
    from tools import url_safety
    with patch.object(url_safety,'is_safe_url',return_value=False), patch.object(url_safety,'create_ssrf_safe_async_client') as client:
        assert (await gate.send_image('alpha','https://media.invalid/blocked.png')).success
        client.assert_not_called()
    async def handle(request): return httpx.Response(200,headers={'content-type':'text/plain'},content=b'not image')
    with patch.object(url_safety,'is_safe_url',return_value=True), patch.object(url_safety,'create_ssrf_safe_async_client',
        side_effect=lambda **kw:httpx.AsyncClient(transport=httpx.MockTransport(handle),**kw)):
        assert (await gate.send_image('alpha','https://media.invalid/not-image')).success
    assert all(not row['files'] and 'media.invalid' not in row['text'] for row in gate.journal.records)


async def test_official_cron_cap_passes_full_report_to_chunking_adapter(gate, airport):
    from gateway.delivery import DeliveryRouter
    saved=[]
    router=SimpleNamespace(_save_full_output=lambda text, job: saved.append((text,job)) or airport/'audit.txt')
    text='report '+('한'*5000)
    output=DeliveryRouter._cap_oversized_output(router,gate,text,'fake-job')
    assert output==text and saved==[(text,'fake-job')]
    assert (await gate.send('alpha',output)).success
    assert gate.journal.records[-1]['text']==text


async def test_image_redirect_private_target_and_streamed_size_are_rejected(gate, monkeypatch):
    import httpx
    from tools import url_safety
    from gate import files
    requested=[]
    async def redirect(request):
        requested.append(str(request.url))
        return httpx.Response(302, headers={'location':'http://127.0.0.1/private'})
    with patch.object(url_safety,'is_safe_url',side_effect=lambda url:url.startswith('https://media.invalid/')), \
         patch.object(url_safety,'create_ssrf_safe_async_client',
            side_effect=lambda **kw:httpx.AsyncClient(transport=httpx.MockTransport(redirect),**kw)):
        assert (await gate.send_image('alpha','https://media.invalid/redirect')).success
    assert requested==['https://media.invalid/redirect']
    monkeypatch.setattr(files,'MAX_FILE_BYTES',4)
    async def oversized(request):return httpx.Response(200,headers={'content-type':'image/png'},content=b'12345')
    with patch.object(url_safety,'is_safe_url',return_value=True), patch.object(url_safety,'create_ssrf_safe_async_client',
        side_effect=lambda **kw:httpx.AsyncClient(transport=httpx.MockTransport(oversized),**kw)):
        assert (await gate.send_image('alpha','https://media.invalid/large.png')).success
    assert all(not row['files'] for row in gate.journal.records)
    assert not list(gate.files.root.glob('.pending/*/*'))


async def test_repeated_large_final_edit_preserves_one_chain_and_last_buttons(gate):
    sent=await gate.send('alpha','preview',metadata={'hejo_buttons':[{'label':'Done','style':'default'}]})
    text='한'*30000
    for _ in range(2):
        assert (await gate.edit_message('alpha',sent.message_id,text,finalize=True)).success
        rows=[gate.journal.message(row['msg_id']) for row in gate.journal.records if row['type']=='message']
        rows=[row for row in rows if row]
        assert ''.join(row['text'] for row in rows)==text
        assert len(rows)==2 and not rows[0]['buttons'] and rows[1]['buttons'][0]['label']=='Done'


@pytest.mark.parametrize('kind,response,key', [
    ('approval','once','platform.telegram.approval.resolved_once'),
    ('approval','session','platform.telegram.approval.resolved_session'),
    ('approval','always','platform.telegram.approval.resolved_always'),
    ('approval','deny','platform.telegram.approval.resolved_deny'),
    ('slash','once','platform.telegram.slash_confirm.resolved_once'),
    ('slash','always','platform.telegram.slash_confirm.resolved_always'),
    ('slash','cancel','platform.telegram.slash_confirm.resolved_cancel'),
])
async def test_native_outcome_uses_official_nameless_korean_catalog(kind,response,key,monkeypatch):
    from agent.i18n import t
    from gate.buttons import decision
    monkeypatch.setenv('HERMES_LANGUAGE','ko')
    actual=decision({'kind':kind,'response':response})
    assert actual==t(key)
    assert '이(가)' not in actual


@pytest.mark.parametrize('other,key', [
    (False,'platform.slack.clarify.resolved'),
    (True,'platform.slack.clarify.awaiting'),
])
async def test_clarify_outcome_keeps_official_owner_wording(other,key,monkeypatch):
    from agent.i18n import t
    from gate.buttons import decision
    monkeypatch.setenv('HERMES_LANGUAGE','ko')
    assert decision({'kind':'clarify','response':'A','other':other})==t(key,user='나',choice='A')


async def test_video_accepts_extra_base_adapter_keywords(gate,airport):
    file=airport/'clip.mp4';file.write_bytes(b'fixture-video')
    result=await gate.send_video('alpha',str(file),supports_streaming=True)
    assert result.success
    message=gate.journal.message(result.message_id)
    assert message['files'][0]['mime']=='video/mp4'
    path,_=gate.files.registered('alpha',message['files'][0]['file_id'])
    assert path.read_bytes()==b'fixture-video'
