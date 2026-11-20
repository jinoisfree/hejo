"""Loopback room controls: no operating configuration or external requests."""
import asyncio,json,subprocess,sys,tempfile,uuid
from pathlib import Path
from aiohttp import web

async def main():
    room='11111111-1111-4111-8111-111111111111';thread=room
    async def handler(request):
        ws=web.WebSocketResponse();await ws.prepare(request);await ws.receive_json();seq=0
        async def emit(kind,**values):
            nonlocal seq
            row={'v':1,'type':kind,**values}
            if kind in {'message','room'}:seq+=1;row['seq']=seq
            await ws.send_json(row)
        await emit('welcome',device_id='fixture',token='fixture-token',head_seq=2,gate_version='test',employees=[{'id':x,'name':x,'aliases':[]} for x in ['alpha','beta']])
        await emit('room',room={'id':room,'title':'Fixture','description':'','members':['alpha','beta'],'lead':'alpha','picture':None,'archived':False})
        await emit('message',msg_id=str(uuid.uuid4()),employee='beta',room=room,thread=thread,role='employee',text='승인해 주세요',files=[],buttons=[],reply_state='asked',ts='2026-01-01T00:00:00Z')
        await emit('sync_done',ref='hello',through=2,head_seq=2,more=False)
        await emit('typing',employee='beta',room=room,thread=thread,on=True,ttl_seconds=120)
        async for item in ws:
            if item.type!=web.WSMsgType.TEXT:continue
            frame=json.loads(item.data)
            if frame['type']=='send':
                await emit('message',msg_id=str(uuid.uuid4()),employee=frame['employee'],room=room,thread=thread,role='owner',text=frame['text'],client_msg_id=frame['client_msg_id'],files=[],buttons=[],reply_state=None,ts='2026-01-01T00:00:00Z')
                await emit('typing',employee='beta',room=room,thread=thread,on=False)
        return ws
    app=web.Application();app.router.add_get('/v1/ws',handler);runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-review55-') as tmp:
            p=await asyncio.to_thread(subprocess.run,[str(Path(sys.argv[1]).resolve()),'--review55-network',tmp,f'127.0.0.1:{site._server.sockets[0].getsockname()[1]}'])
            assert p.returncode==0
    finally:await runner.cleanup()
    print('REVIEW55_FIXTURE_PASS')
if __name__=='__main__':asyncio.run(main())
