from legacy_feature_fixture import reject_discord
"""AT79: two real loopback sends and delayed fake employee replies; no automatic retries."""
import asyncio
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid
from aiohttp import web
from jsonschema import Draft202012Validator

async def main():
    schema=json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text())
    validator=Draft202012Validator(schema);seen=[];errors=[]
    async def handler(request):
        ws=web.WebSocketResponse();await ws.prepare(request);seq=0
        try:
            hello=await ws.receive_json();validator.validate(hello);assert hello['pair_code']=='test_code-12'
            async def emit(frame):
                validator.validate(frame);await ws.send_json(frame)
            await emit(dict(v=1,type='welcome',device_id=str(uuid.uuid4()),token='fake-workspace-token',gate_version='test',head_seq=0,employees=[dict(id='alpha',name='직원 A',aliases=[],avatar=None),dict(id='beta',name='직원 B',aliases=[],avatar=None)]))
            await emit(dict(v=1,type='sync_done',ref='hello',through=0,head_seq=0,more=False))
            async for item in ws:
                if item.type!=web.WSMsgType.TEXT:continue
                frame=json.loads(item.data);validator.validate(frame)
                if await reject_discord(ws, frame):continue
                if frame['type']=='pong':continue
                assert frame['type']=='send';seen.append(frame['text'])
                if frame['text']=='fail':
                    await emit(dict(v=1,type='error',code='too_large',ref=frame['client_msg_id']));continue
                for role,text in [('owner',frame['text']),('employee','delayed answer')]:
                    if role=='employee':await asyncio.sleep(.35)
                    seq+=1;message=dict(v=1,type='message',seq=seq,msg_id=str(uuid.uuid4()),employee=frame['employee'],thread=frame['thread'],role=role,text=text,files=[],buttons=[],reply_state=None,ts='2026-01-01T00:00:00Z')
                    if role=='owner':message['client_msg_id']=frame['client_msg_id']
                    await emit(message)
        except (ConnectionResetError,asyncio.CancelledError):pass
        except Exception as exc:errors.append(type(exc).__name__)
        return ws
    app=web.Application();app.router.add_get('/v1/ws',handler);runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-workspace-') as tmp:
            result=await asyncio.to_thread(subprocess.run,[str(Path(sys.argv[1]).resolve()),'--workspace-network',tmp,f'127.0.0.1:{site._server.sockets[0].getsockname()[1]}'])
            assert result.returncode==0 and not errors,(result.returncode,errors)
            assert seen==['follow-empty','follow-typed','fail'],seen
            print('WORKSPACE_FIXTURE_PASS',seen)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
