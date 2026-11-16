"""AT70/71/80: actual AppKit client + actual gate + fake Hermes, isolated home only."""
import asyncio
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

async def main():
    root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root))
    with tempfile.TemporaryDirectory(prefix='hejo-rooms-') as directory:
        os.environ['HERMES_HOME']=str(Path(directory)/'server');os.environ['HEJO_ALLOWED_USERS']='owner'
        from hermes_cli.profiles import create_profile
        for name in ['alpha','beta']:create_profile(name,no_alias=True,no_skills=True)
        from gate import register
        from hermes_cli.plugins import PluginContext,PluginManager
        from hermes_cli.plugins_manifest import PluginManifest
        register(PluginContext(PluginManifest(name='hejo',kind='platform',source='user'),PluginManager()))
        from gate.adapter import HejoAdapter
        from gateway.config import PlatformConfig,GatewayConfig
        from gateway.authz_mixin import GatewayAuthorizationMixin
        gate=HejoAdapter(PlatformConfig(enabled=True,extra={'listen':['127.0.0.1'],'port':0}))
        gate.employees=lambda:[dict(id=i,name='직원 '+n,aliases=[alias],avatar=None) for i,n,alias in [('alpha','A','first'),('beta','B','second'),('default','C','outside')]]
        seen=[]
        class Runner(GatewayAuthorizationMixin):
            def __init__(self):self.config=GatewayConfig();self.adapters={gate.platform:gate}
            async def handle(self,event):
                assert self._is_user_authorized(event.source)
                seen.append((event.source.profile,event.text))
                await gate.send_typing(event.source.chat_id,{'hermes_profile':event.source.profile,'thread_id':event.source.thread_id})
                await gate.send(event.source.chat_id,'답 '+event.source.profile,metadata={'hermes_profile':event.source.profile,'thread_id':event.source.thread_id})
                await gate.stop_typing(event.source.chat_id,{'hermes_profile':event.source.profile})
        gate.set_message_handler(Runner().handle);assert await gate.connect()
        try:
            app_home=str(Path(directory)/'app')
            process=await asyncio.create_subprocess_exec(str(Path(sys.argv[1]).resolve()),'--rooms-network',app_home,f'127.0.0.1:{gate.server.port}',gate.auth.pair_code())
            try:code=await asyncio.wait_for(process.wait(),90)
            except BaseException:
                process.kill();await process.wait();raise
            assert code==0,code
            expected=[('beta','ordinary'),('alpha','@first single'),('alpha','@first @second both'),('beta','@first @second both'),('beta','@outside ignored'),('alpha','@직원 A face'),('beta','@직원 B explicit'),('beta','default'),('alpha','@직원 A alias'),('beta','@직원 C outside'),('alpha','@직원 A @직원 B both'),('beta','@직원 A @직원 B both'),('alpha','@직원 A')]
            assert seen==expected,(seen,expected)
            assert len(gate.journal.deleted_rooms)==1
            assert len([r for r in gate.journal.records if r['type']=='room_delete'])==1
            assert all(gate.journal.hidden(r) for r in gate.journal.records if r['type']=='message')
            print('ROOMS_GATE_APP_FIXTURE_PASS',len(seen))
        finally:
            await gate.cancel_background_tasks()
            await gate.disconnect()
            from gateway.status import flush_runtime_status_async
            assert await flush_runtime_status_async()
if __name__=='__main__':asyncio.run(main())
