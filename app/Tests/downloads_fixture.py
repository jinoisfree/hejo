"""AT95: actual loopback HTTP/WS, temporary application and Downloads directories only."""
import asyncio
import json
from pathlib import Path
import secrets
import sys
import tempfile
import uuid
from aiohttp import web
from jsonschema import Draft202012Validator

async def main():
    binary=Path(sys.argv[1]).resolve()
    schema=json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text())
    validator=Draft202012Validator(schema)
    token=secrets.token_urlsafe(32)
    ids=[str(uuid.uuid4()) for _ in range(3)]
    thread=str(uuid.uuid4()); seq=3; downloads={}; uploads={}; errors=[]; sent=0
    def info(identifier,name,data):
        return dict(file_id=identifier,name=name,mime='text/plain',size=len(data))
    payloads={ids[0]:b'received',ids[1]:b'different',ids[2]:b'fallback'}
    descriptors={identifier:info(identifier,'note.txt' if index<2 else 'fallback.txt',payloads[identifier]) for index,identifier in enumerate(ids)}
    def auth(request):
        assert request.headers.get('Authorization')=='Bearer '+token
    async def socket(request):
        nonlocal seq,sent
        ws=web.WebSocketResponse();await ws.prepare(request)
        async def send(frame):
            validator.validate(frame);await ws.send_json(frame)
        try:
            hello=await ws.receive_json();validator.validate(hello);assert hello['pair_code']=='test_code-12'
            await send(dict(v=1,type='welcome',token=token,device_id=str(uuid.uuid4()),gate_version='test',head_seq=3,employees=[dict(id='alpha',name='직원 A',aliases=[],avatar=None),dict(id='beta',name='직원 B',aliases=[],avatar=None)]))
            for index,identifier in enumerate(ids):
                await send(dict(v=1,type='message',seq=index+1,msg_id=str(uuid.uuid4()),employee='alpha',thread=thread,role='employee',text='파일',files=[descriptors[identifier]],buttons=[],reply_state=None,ts='2026-01-02T03:04:05.123Z'))
            await send(dict(v=1,type='sync_done',ref='hello',through=3,more=False,head_seq=3))
            async for item in ws:
                if item.type!=web.WSMsgType.TEXT:continue
                frame=json.loads(item.data);validator.validate(frame)
                if frame['type']=='send':
                    sent+=1
                    assert frame['employee']=='alpha' and len(frame['files'])==1
                    if frame['text']=='reject':await send(dict(v=1,type='error',code='unknown_file',ref=frame['id']))
                    else:
                        assert frame['text']=='accept';seq+=1
                        await send(dict(v=1,type='message',seq=seq,msg_id=str(uuid.uuid4()),employee='alpha',thread=frame['thread'],role='owner',text='accept',files=[uploads[frame['files'][0]]],buttons=[],reply_state=None,ts='2026-01-02T03:04:05.123Z',client_msg_id=frame['client_msg_id']))
        except Exception as error:errors.append(type(error).__name__);await ws.close()
        return ws
    async def download(request):
        auth(request)
        if request.match_info['employee']!='alpha':raise web.HTTPNotFound()
        identifier=request.match_info['identifier'];assert identifier in payloads
        downloads[identifier]=downloads.get(identifier,0)+1
        assert downloads[identifier]==1,'saved file fetched again'
        return web.Response(body=payloads[identifier])
    async def upload(request):
        auth(request);part=await (await request.multipart()).next();data=await part.read()
        identifier=str(uuid.uuid4());uploads[identifier]=info(identifier,part.filename,data)
        return web.json_response(uploads[identifier])
    app=web.Application();app.router.add_get('/v1/ws',socket);app.router.add_get('/v1/files/{employee}/{identifier}',download);app.router.add_post('/v1/files',upload)
    runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start()
    port=site._server.sockets[0].getsockname()[1]
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-downloads-') as home:
            child=await asyncio.create_subprocess_exec(str(binary),'--task44-network',home,f'ws://127.0.0.1:{port}',stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
            try:output,_=await asyncio.wait_for(child.communicate(),30)
            except BaseException:child.kill();await child.wait();raise
            print(output.decode(),end='',flush=True)
            assert child.returncode==0 and not errors,(child.returncode,errors)
            assert downloads=={identifier:1 for identifier in ids} and sent==2 and len(uploads)==2
            assert token not in Path(home,'hejo-local.json').read_text()
            print('DOWNLOADS_FIXTURE_PASS received=3 each-once accepted=1 rejected=1 temporary-only',flush=True)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
