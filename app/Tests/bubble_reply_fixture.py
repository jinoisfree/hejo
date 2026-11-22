from legacy_feature_fixture import reject_telegram
"""AT82 real loopback sends; a fake gateway rejects one message after receiving it."""
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

async def main():
    validator=Draft202012Validator(json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text()))
    seen=[];errors=[]
    async def handler(request):
        ws=web.WebSocketResponse();await ws.prepare(request);seq=0
        try:
            hello=await ws.receive_json();validator.validate(hello)
            async def emit(kind,**data):
                frame=dict(v=1,type=kind,**data);validator.validate(frame);await ws.send_json(frame)
            async def post(text,role='employee',**extra):
                nonlocal seq
                seq+=1
                await emit('message',seq=seq,msg_id=str(uuid.uuid4()),employee='alpha',thread=THREAD,role=role,text=text,files=[],buttons=[],reply_state=None,ts='2026-01-01T00:00:00Z',**extra)
            await emit('welcome',device_id=str(uuid.uuid4()),token='fake-bubble-credential',gate_version='test',head_seq=1,employees=[dict(id='alpha',name='직원 A',aliases=[],avatar=None,queued=True)])
            await post('대상 스레드')
            await emit('sync_done',ref='hello',through=1,head_seq=1,more=False)
            await post('동기화 뒤 새 글')
            await emit('typing',employee='alpha',thread=THREAD,on=True,ttl_seconds=6)
            async for item in ws:
                if item.type!=web.WSMsgType.TEXT:continue
                frame=json.loads(item.data);validator.validate(frame)
                if await reject_telegram(ws, frame):continue
                if frame['type']=='pong':continue
                assert frame['type']=='send' and frame['employee']=='alpha' and frame['thread']==THREAD
                assert frame.get('files',[])==[]
                seen.append(frame['text'])
                if frame['text']=='reject':
                    await asyncio.sleep(.15)
                    await emit('error',code='too_large',ref=frame['client_msg_id'])
                else:
                    await post(frame['text'],role='owner',client_msg_id=frame['client_msg_id'])
                    await asyncio.sleep(.25)
                    await post('새 답')
                    await emit('typing',employee='alpha',thread=THREAD,on=False)
        except (ConnectionResetError,asyncio.CancelledError):pass
        except Exception as error:errors.append(type(error).__name__)
        return ws
    app=web.Application();app.router.add_get('/v1/ws',handler);runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-bubble-') as home:
            result=await asyncio.to_thread(subprocess.run,[str(Path(sys.argv[1]).resolve()),'--bubble-network',home,f'127.0.0.1:{site._server.sockets[0].getsockname()[1]}'])
            assert result.returncode==0 and not errors,(result.returncode,errors)
            assert seen==['interrupt','reject'],seen
            print('BUBBLE_REPLY_FIXTURE_PASS',seen)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
