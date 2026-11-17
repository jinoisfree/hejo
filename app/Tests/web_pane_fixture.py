"""AT96 uses only a loopback fake page/gateway. Browser requests may never carry an app credential."""
import asyncio
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile
import uuid
from aiohttp import web
from jsonschema import Draft202012Validator

async def main():
    binary=Path(sys.argv[1]).resolve()
    resource=Path(__file__).resolve().parents[1]/'.build/hejo.app/Contents/Resources/Pet'
    validator=Draft202012Validator(json.loads((Path(__file__).resolve().parents[2]/'schemas/hejo-wire-v1.json').read_text()))
    token=secrets.token_urlsafe(32);identifier=str(uuid.uuid4());errors=[];file_reads=0;web_reads=0
    payload=b'private fixture'
    async def socket(request):
        ws=web.WebSocketResponse();await ws.prepare(request)
        try:
            hello=await ws.receive_json();validator.validate(hello);assert hello['pair_code']=='test_code-12'
            frames=[dict(v=1,type='welcome',token=token,device_id=str(uuid.uuid4()),gate_version='test',head_seq=1,employees=[dict(id='alpha',name='직원 A',aliases=[],avatar=None)]),dict(v=1,type='message',seq=1,msg_id=str(uuid.uuid4()),employee='alpha',thread=str(uuid.uuid4()),role='employee',text='첨부',files=[dict(file_id=identifier,name='private.txt',mime='text/plain',size=len(payload))],buttons=[],reply_state=None,ts='2026-01-02T03:04:05Z'),dict(v=1,type='sync_done',ref='hello',through=1,more=False,head_seq=1)]
            for frame in frames:validator.validate(frame);await ws.send_json(frame)
            async for _ in ws:pass
        except Exception as error:errors.append(type(error).__name__)
        return ws
    async def file(request):
        nonlocal file_reads
        assert request.headers.get('Authorization')=='Bearer '+token
        file_reads+=1
        return web.Response(body=payload)
    async def page(request):
        nonlocal web_reads
        assert 'Authorization' not in request.headers,'WebKit credential leak'
        web_reads+=1
        path=request.path
        if path=='/download':return web.Response(body=b'local web download',headers={'Content-Disposition':'attachment; filename="web.txt"','Content-Type':'application/octet-stream'})
        if path=='/missing':request.transport.close();return web.Response()
        title='둘째 페이지' if path=='/second' else '합성 페이지'
        return web.Response(text=f'<!doctype html><meta charset=utf-8><title>{title}</title><style>body{{margin:0;background:#f3f7f4;font:16px -apple-system}}header{{background:#217949;color:white;padding:22px}}main{{padding:25px}}</style><header>{title}</header><main><p>로컬 웹 페이지</p><input id=field><p><a id=next href=/second target=_blank>새 탭 링크</a></p></main>',content_type='text/html')
    app=web.Application();app.router.add_get('/v1/ws',socket);app.router.add_get('/v1/files/alpha/{id}',file);app.router.add_get('/{tail:.*}',page)
    runner=web.AppRunner(app);await runner.setup();site=web.TCPSite(runner,'127.0.0.1',0);await site.start();port=site._server.sockets[0].getsockname()[1]
    try:
        with tempfile.TemporaryDirectory(prefix='hejo-web-') as home:
            command=[str(binary),'--task45-network',home,f'http://127.0.0.1:{port}',str(resource)]
            if len(sys.argv)>2:command.append(str(Path(sys.argv[2]).resolve()))
            child=await asyncio.create_subprocess_exec(*command,env=dict(os.environ,HERMES_HOME=home,HERMES_ROOT=home),stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
            try:output,_=await asyncio.wait_for(child.communicate(),90)
            except BaseException:child.kill();await child.wait();raise
            print(output.decode(),end='',flush=True)
            assert child.returncode==0 and not errors,(child.returncode,errors)
            assert file_reads==1 and web_reads>4,(file_reads,web_reads)
            print('WEB_FIXTURE_PASS credentialed-app-file=1 credential-free-web=true temporary-downloads=true',flush=True)
    finally:await runner.cleanup()
if __name__=='__main__':asyncio.run(main())
