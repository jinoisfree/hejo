from legacy_feature_fixture import reject_imessage
"""AT80: real loopback sends prove home is a view and rejected recipients produce no frame."""
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
    validator=Draft202012Validator(json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text()))
    seen=[];errors=[];threads=[];pictures=[];photo=None
    async def handler(request):
        ws=web.WebSocketResponse();await ws.prepare(request);seq=0
        try:
            hello=await ws.receive_json();validator.validate(hello)
            async def emit(frame):validator.validate(frame);await ws.send_json(frame)
            await emit(dict(v=1,type='welcome',device_id=str(uuid.uuid4()),token='fake-home-token',gate_version='test',head_seq=0,employees=[dict(id=person,name='직원 '+label,aliases=[label],avatar=None) for person,label in [('alpha','A'),('beta','B'),('gamma','C')]]))
            await emit(dict(v=1,type='sync_done',ref='hello',through=0,head_seq=0,more=False))
            async for item in ws:
                if item.type!=web.WSMsgType.TEXT:continue
                frame=json.loads(item.data);validator.validate(frame)
                if await reject_imessage(ws, frame):continue
                if frame['type']=='pong':continue
                assert frame['type']=='send' and 'room' not in frame
                index=len(seen);expected=[('alpha','default'),('beta','second @B'),('alpha','face @B'),('gamma','@C mention'),('beta','configured'),('alpha','reply')]
                assert (frame['employee'],frame['text'])==expected[index]
                uuid.UUID(frame['thread'])
                if index<5:assert frame['thread'] not in threads;threads.append(frame['thread'])
                else:assert frame['thread']==threads[0]
                seen.append((frame['employee'],frame['text']))
                for role,text in [('owner',frame['text']),('employee','새 답')]:
                    if role=='employee':await asyncio.sleep(.6 if index==0 else .1)
                    seq+=1;message=dict(v=1,type='message',seq=seq,msg_id=str(uuid.uuid4()),employee=frame['employee'],thread=frame['thread'],role=role,text=text,files=[],buttons=[],reply_state=None,ts='2026-01-01T00:00:00Z')
                    if role=='owner':message['client_msg_id']=frame['client_msg_id']
                    await emit(message)
        except (ConnectionResetError,asyncio.CancelledError):pass
        except Exception as error:errors.append(type(error).__name__)
        return ws
    async def picture(request):
        nonlocal photo
        assert request.headers.get('Authorization')=='Bearer fake-home-token'
        if request.method=='PUT':
            photo=await request.read();assert photo.startswith(b'\x89PNG\r\n\x1a\n');pictures.append('PUT')
            return web.json_response({'picture':'/v1/pictures/room/home-main?v=1'})
        if request.method=='DELETE':
            pictures.append('DELETE')
            if pictures.count('DELETE')==1:return web.Response(status=500)
            photo=None;return web.json_response({'picture':None})
        return web.Response(body=photo,content_type='image/png') if photo else web.Response(status=404)
    app=web.Application();app.router.add_route('*','/v1/pictures/room/home-main',picture);app.router.add_get('/v1/ws',handler);runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-home-') as home:
            result=await asyncio.to_thread(subprocess.run,[str(Path(sys.argv[1]).resolve()),'--home-network',home,f'127.0.0.1:{site._server.sockets[0].getsockname()[1]}'])
            assert result.returncode==0 and not errors,(result.returncode,errors)
            assert len(seen)==6 and pictures==['PUT','DELETE','DELETE'],(seen,pictures)
            print('HOME_ROOM_FIXTURE_PASS',seen)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
