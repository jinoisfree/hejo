from legacy_feature_fixture import reject_telegram
"""AT88 real WebSocket acknowledgement/failure boundaries, with no external messaging."""
import asyncio,json,os,subprocess,sys,tempfile,uuid
from pathlib import Path
from aiohttp import web
from jsonschema import Draft202012Validator

async def main():
    validator=Draft202012Validator(json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text()))
    records=[];seen=[];errors=[];thread=str(uuid.uuid4())
    async def handler(request):
        ws=web.WebSocketResponse();await ws.prepare(request)
        async def emit(kind,**data):
            frame=dict(v=1,type=kind,**data);validator.validate(frame);await ws.send_json(frame)
        try:
            hello=await ws.receive_json();validator.validate(hello)
            capture=hello['device_name']=='fake capture'
            roster=[dict(id='alpha',name='직원 A',aliases=[],avatar=None,color='#007AFF'),dict(id='beta',name='직원 B',aliases=[],avatar=None,queued=True)]
            if not capture and not records:records.append(dict(v=1,type='message',seq=1,msg_id=str(uuid.uuid4()),employee='alpha',thread=thread,role='employee',text='첫 직원 글',files=[],buttons=[],reply_state=None,ts='2026-11-15T00:00:00Z'))
            # Capture tests install their synthetic history after opening the real socket.
            # An empty initial roster avoids seeding read:0 before that history replay.
            await emit('welcome',device_id=str(uuid.uuid4()),token='fake-composer-credential',gate_version='test',head_seq=0 if capture else len(records),employees=[] if capture else roster)
            if not capture:
                for row in records:
                    if row['seq']>hello['since']:await ws.send_json(row)
            await emit('sync_done',ref='hello',through=0 if capture else len(records),head_seq=0 if capture else len(records),more=False)
            if not capture:await emit('typing',employee='alpha',thread=thread,on=True,ttl_seconds=6)
            async for item in ws:
                if item.type!=web.WSMsgType.TEXT:continue
                frame=json.loads(item.data);validator.validate(frame)
                if await reject_telegram(ws, frame):continue
                if frame['type']=='pong':continue
                if frame['type']=='sync':
                    await emit('sync_done',ref=frame.get('id','sync'),through=0 if capture else len(records),head_seq=0 if capture else len(records),more=False);continue
                assert not capture and frame['type']=='send'
                if frame['text'] in ['new-reject','home-reject']:assert frame['thread'] != thread
                else:assert frame['thread']==thread
                seen.append(frame['text'])
                if frame['text']=='unconfirmed':await ws.close();break
                if frame['text'] in ['reject','new-reject','home-reject']:
                    await asyncio.sleep(.25);await emit('error',code='too_large',ref=frame['client_msg_id']);continue
                assert frame['text']=='delay'
                await asyncio.sleep(.6)
                row=dict(v=1,type='message',seq=len(records)+1,msg_id=str(uuid.uuid4()),employee='alpha',thread=thread,role='owner',text=frame['text'],files=[],buttons=[],reply_state=None,client_msg_id=frame['client_msg_id'],ts='2026-11-15T00:00:01Z')
                validator.validate(row);records.append(row);await ws.send_json(row)
        except (ConnectionResetError,asyncio.CancelledError):pass
        except Exception as error:errors.append(repr(error))
        return ws
    async def upload(request):
        assert request.headers.get('Authorization')=='Bearer fake-composer-credential'
        part=await (await request.multipart()).next();data=await part.read()
        return web.json_response(dict(file_id=str(uuid.uuid4()),name=part.filename,mime=part.headers.get('Content-Type','application/octet-stream'),size=len(data)))
    app=web.Application();app.router.add_post('/v1/files',upload);app.router.add_get('/v1/ws',handler);runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-compose-network-') as home:
            address=f'127.0.0.1:{site._server.sockets[0].getsockname()[1]}'
            if len(sys.argv)>2:
                args=[str(Path(sys.argv[1]).resolve()),'--task36-capture',str(Path(sys.argv[2]).resolve())];env=dict(os.environ,HERMES_HOME=home,HERMES_ROOT=home,HEJO_CAPTURE_ADDRESS=address)
            else:args=[str(Path(sys.argv[1]).resolve()),'--task37-network',home,address];env=dict(os.environ,HERMES_HOME=home,HERMES_ROOT=home)
            result=await asyncio.to_thread(subprocess.run,args,env=env)
            assert result.returncode==0 and not errors,(result.returncode,errors)
            if len(sys.argv)==2:assert seen==['delay','reject','unconfirmed','new-reject','home-reject'],seen
            print('COMPOSER_FIXTURE_PASS',seen)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
