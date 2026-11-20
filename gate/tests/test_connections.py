"""AT83/D9: public outcomes and official compensation, including failed compensation."""
import json
import stat
import pytest
from gate.connections import ConnectionFailure, SecretTransactions


class Admin:
    def __init__(self, previous='old', *, fail=False, compensate_fails=False, valid=True, reachable=True):
        self.value=previous; self.fail=fail; self.compensate_fails=compensate_fails
        self.valid=valid;self.reachable=reachable;self.writes=[]

    async def request(self, method, route, *, profile=None, body=None):
        assert profile=='alpha'
        if route=='/api/providers/validate':return {'ok':self.valid,'reachable':self.reachable,'message':'discard raw error'}
        if route=='/api/env/reveal':
            if self.value is None:raise ConnectionFailure('admin_failed',404)
            return {'key':'SYNTHETIC_KEY','value':self.value}
        if method=='GET':return {'SYNTHETIC_KEY':{'is_set':bool(self.value)}}
        self.writes.append((method,body));self.value=None if method=='DELETE' else body['value']
        if self.fail and (len(self.writes)==1 or self.compensate_fails):
            raise ConnectionFailure('admin_failed',500)
        return {'ok':True}


@pytest.mark.asyncio
@pytest.mark.parametrize('previous,method',[('old','PUT'),(None,'DELETE')])
async def test_d9_failed_write_compensates_via_official_path(tmp_path,previous,method):
    admin=Admin(previous,fail=True);transactions=SecretTransactions(tmp_path,admin)
    reply=await transactions.save('alpha','SYNTHETIC_KEY','synthetic-private-value')
    assert reply=={'outcome':'failed','reason':'WRITE_FAILED'}
    assert admin.value==previous and admin.writes[-1][0]==method
    assert not list((tmp_path/'hejo/undo').glob('*.json'))
    assert 'synthetic-private-value' not in json.dumps(reply)
    assert not list(tmp_path.rglob('.env')) and not list(tmp_path.rglob('config.yaml'))


@pytest.mark.asyncio
async def test_d9_partial_is_visible_and_undo_survives(tmp_path):
    transactions=SecretTransactions(tmp_path,Admin(fail=True,compensate_fails=True))
    reply=await transactions.save('alpha','SYNTHETIC_KEY','synthetic-private-value')
    assert reply=={'outcome':'partial','reason':'write_partial'}
    undo=list((tmp_path/'hejo/undo').glob('*.json'));assert len(undo)==1
    assert stat.S_IMODE(undo[0].stat().st_mode)==0o600
    assert json.loads(undo[0].read_text())['previous']=='old'
    assert 'synthetic-private-value' not in json.dumps(reply)


@pytest.mark.asyncio
async def test_d9_validation_refusal_never_writes(tmp_path):
    admin=Admin(valid=False);reply=await SecretTransactions(tmp_path,admin).save('alpha','SYNTHETIC_KEY','synthetic-private-value')
    assert reply=={'outcome':'refused','reason':'CHECK_FAILED'} and not admin.writes


@pytest.mark.asyncio
async def test_d9_unknown_validation_save_undo_and_expiry(tmp_path):
    now=[1000];admin=Admin(reachable=False);transactions=SecretTransactions(tmp_path,admin,lambda:now[0])
    reply=await transactions.save('alpha','SYNTHETIC_KEY','synthetic-private-value')
    assert reply=={'outcome':'done','reason':'OK','undo_until':1600,'state':'unknown','instruction':'키 저장됨(확인 안 함)'}
    assert await transactions.undo('alpha','SYNTHETIC_KEY')=={'outcome':'done','reason':'OK'} and admin.value=='old'
    await transactions.save('alpha','SYNTHETIC_KEY','synthetic-private-value');now[0]=1600
    assert await transactions.undo('alpha','SYNTHETIC_KEY')=={'outcome':'refused','reason':'EXPIRED'}
    assert not list((tmp_path/'hejo/undo').glob('*.json'))


@pytest.mark.asyncio
async def test_restart_refuses_busy_unknown_and_records_before_request(tmp_path):
    from gate.connection_runtime import RestartJobs
    state={'pid':1,'start_time':900,'active_agents':1,'platforms':{}}
    jobs=RestartJobs(tmp_path,None,clock=lambda:1000,snapshot=lambda:state)
    called=[]
    async def restart():
        assert jobs.audit.rows()[-1]['outcome']=='pending'
        called.append(True)
    assert (await jobs.start('device','alpha',restart=restart))['reason']=='BUSY'
    state.pop('active_agents')
    assert (await jobs.start('device','alpha',restart=restart))['reason']=='BUSY_CHECK_FAILED'
    assert not called
    state['active_agents']=0
    reply=await jobs.start('device','alpha',restart=restart)
    assert reply['outcome']=='pending' and called==[True]
    assert (await jobs.start('device','alpha',restart=restart))['reason']=='RATE_LIMITED'
    assert jobs.result(reply['job'],'other-device')['reason']=='UNKNOWN_JOB'


@pytest.mark.asyncio
async def test_restart_uses_saved_expected_channels_and_new_identity(tmp_path):
    from gate.connection_runtime import RestartJobs
    now=[1000];state=[{'pid':1,'start_time':900,'active_agents':0,'served_profiles':['default','alpha'],
        'platforms':{'hejo':{'state':'connected','writer_pid':1,'writer_start_time':900},'alpha:slack':{'state':'connected','writer_pid':1,'writer_start_time':900}}}]
    jobs=RestartJobs(tmp_path,None,clock=lambda:now[0],snapshot=lambda:state[0])
    async def restart():pass
    reply=await jobs.start('device','alpha',restart=restart);job=reply['job']
    assert jobs.result(job,'device')['outcome']=='pending'
    state[0]={'pid':2,'start_time':1001,'active_agents':0,'served_profiles':['default','alpha'],
        'platforms':{'hejo':{'state':'connected','writer_pid':2,'writer_start_time':1001}}}
    now[0]=1002;assert jobs.result(job,'device')['outcome']=='pending'
    now[0]=1180;assert jobs.result(job,'device')=={'outcome':'partial','job':job,'connected':1}
    assert jobs.result(job,'device')=={'outcome':'partial','job':job,'connected':1}


class CatalogAdmin(Admin):
    async def request(self,method,route,*,profile=None,body=None):
        if route=='/api/tools/toolsets':return [{'name':'memory','label':'기억','enabled':True}]
        if route.endswith('/config'):return {'providers':[{'name':'시험','env_vars':[{'key':'SYNTHETIC_KEY','is_set':bool(self.value)}]}]}
        if route=='/api/mcp/catalog':return {'entries':[]}
        if route=='/api/mcp/servers':return {'servers':[]}
        if route=='/api/providers/oauth':return {'providers':[]}
        if route=='/api/env' and method=='GET':return {'SYNTHETIC_KEY':{'is_set':bool(self.value),'redacted_value':'must-not-forward'}}
        if route=='/api/gateway/restart':raise AssertionError('read must not restart')
        return await super().request(method,route,profile=profile,body=body)


@pytest.mark.asyncio
@pytest.mark.parametrize('previous,method',[('old','PUT'),(None,'DELETE')])
async def test_d9_successful_compensation_with_wrong_presence_is_partial(tmp_path,previous,method):
    """A successful compensation reply cannot hide a mismatched stored-key presence."""
    from gate.connection_manager import Connections

    class WrongPresence(CatalogAdmin):
        async def request(self,verb,route,*,profile=None,body=None):
            result=await super().request(verb,route,profile=profile,body=body)
            if route=='/api/env' and verb in ('PUT','DELETE'):
                # Only the compensation returns success; its storage state is wrong.
                assert len(self.writes)==2 and verb==method
                self.value=None if previous else 'synthetic-residual-value'
            return result

    admin=WrongPresence(previous,fail=True)
    manager=Connections(tmp_path,lambda:[{'id':'alpha','name':'직원 A'}],admin=admin,snapshot=lambda:None)
    reply=await manager.perform('device',{'profile':'alpha','connection':'key:SYNTHETIC_KEY',
        'action':'secret_set','reauth':True,'values':{'value':'synthetic-private-value'}})
    assert [entry[0] for entry in admin.writes]==['PUT',method]
    assert bool(admin.value)!=bool(previous)
    assert reply['outcome']=='partial' and reply['reason']=='write_partial'
    assert reply['instruction']=='저장이 중간에 멈췄어요. 서버에서 이 키를 확인해 주세요'
    assert manager.audit.rows()[-1]['outcome']=='partial'
    assert 'synthetic-private-value' not in manager.audit.path.read_text()+json.dumps(reply)


@pytest.mark.asyncio
async def test_action_boundary_auth_profile_no_secret_output_or_action_bytes(tmp_path):
    from gate.connection_manager import Connections
    admin=CatalogAdmin();manager=Connections(tmp_path,lambda:[{'id':'alpha','name':'직원 A'}],admin=admin,snapshot=lambda:None)
    frame={'profile':'alpha','connection':'key:SYNTHETIC_KEY','action':'secret_set','reauth':False,'values':{'value':'synthetic-private-value'}}
    assert (await manager.perform('device',frame))['reason']=='reauth_required'
    assert not admin.writes
    frame['reauth']=True
    reply=await manager.perform('device',frame)
    assert reply['outcome']=='done' and 'values' not in frame
    assert b'synthetic-private-value' not in manager.audit.path.read_bytes()
    assert 'synthetic-private-value' not in json.dumps(reply)
    document=await manager.document('alpha')
    assert 'redacted_value' not in json.dumps(document) and 'must-not-forward' not in json.dumps(document)
    assert (await manager.perform('device',{'profile':'foreign','connection':'gateway','action':'gateway_restart','reauth':True}))['reason']=='UNKNOWN_PROFILE'
    assert (await manager.perform('device',{'profile':'alpha','connection':'gateway','action':'check_all','reauth':False}))['outcome']=='done'


@pytest.mark.asyncio
async def test_management_frames_private_not_replayed_or_broadcast(gate,client,tmp_path,caplog):
    # The fixtures use two fake profiles and actual authenticated loopback WebSockets.
    admin=CatalogAdmin();gate.server.admin_connections.admin=admin
    gate.server.admin_connections.secrets.admin=admin
    ws,welcome=await client.pair();other,_=await client.open(token=welcome['token'])
    await ws.send_json({'v':1,'type':'connections','id':'list','profile':'alpha'})
    document=await client.read(ws)
    assert document['type']=='connections_status' and document['ref']=='list'
    frame={'v':1,'type':'connection_action','id':'save','profile':'alpha','connection':'key:SYNTHETIC_KEY',
           'action':'secret_set','reauth':True,'values':{'value':'synthetic-private-value'}}
    await ws.send_json(frame);reply=await client.read(ws)
    assert reply['reply']['outcome']=='done'
    assert gate.journal.head==0
    await other.send_json({'v':1,'type':'roster','id':'probe'})
    assert (await client.read(other))['ref']=='probe'
    await ws.send_json({'v':1,'type':'connections','id':'foreign','profile':'not-in-roster'})
    assert (await client.read(ws))['reply']['outcome']=='failed'
    await ws.send_json({'v':1,'type':'connection_action','id':'rejected','profile':'alpha','connection':'key:SYNTHETIC_KEY','action':'secret_set','reauth':False})
    assert (await client.read(ws))['reply']['reason']=='reauth_required'
    # Fake credentials may occur only in the fake official writer and approved previous-value vault.
    for path in (tmp_path/'shared/hejo').rglob('*'):
        if path.is_file():assert b'synthetic-private-value' not in path.read_bytes()
    assert 'synthetic-private-value' not in caplog.text+json.dumps(document)+json.dumps(reply)


@pytest.mark.asyncio
async def test_admin_transport_never_exposes_token_error_or_redirect(tmp_path):
    from aiohttp import web
    from gate.connections import AdminClient
    seen=[]
    async def endpoint(request):
        seen.append((request.headers.get('X-Hermes-Session-Token'),request.query.get('profile')))
        if request.path.endswith('chunked'):
            import asyncio
            response=web.StreamResponse(headers={'Content-Type':'application/json'});await response.prepare(request)
            await response.write(b'{\"ok\":');await asyncio.sleep(.01);await response.write(b'true}');await response.write_eof();return response
        if request.path.endswith('bad'):return web.json_response({'detail':'synthetic-private-value'},status=500)
        if request.path.endswith('redirect'):raise web.HTTPFound('/api/env')
        return web.json_response({'ok':True})
    app=web.Application();app.router.add_route('*','/api/{tail:.*}',endpoint)
    server=web.AppRunner(app);await server.setup();site=web.TCPSite(server,'127.0.0.1',0);await site.start()
    try:
        vault=tmp_path/'hejo';vault.mkdir();path=vault/'admin.json'
        path.write_text(json.dumps({'port':site._server.sockets[0].getsockname()[1],'token':'synthetic-admin-token'}));path.chmod(0o600)
        admin=AdminClient(tmp_path)
        assert await admin.request('GET','/api/env',profile='alpha')=={'ok':True}
        for route in ('/api/bad','/api/redirect'):
            with pytest.raises(ConnectionFailure) as error:await admin.request('GET',route,profile='beta')
            assert 'synthetic-' not in str(error.value)
        assert await admin.request('GET','/api/chunked',profile='beta')=={'ok':True}
        assert len(seen)==4 and seen[0]==('synthetic-admin-token','alpha')
        path.chmod(0o644)
        with pytest.raises(ConnectionFailure):await admin.request('GET','/api/env')
        assert len(seen)==4
    finally:await server.cleanup()


def test_admin_receipt_no_token_owner_change_and_removal(tmp_path):
    import importlib.util
    from pathlib import Path
    spec=importlib.util.spec_from_file_location('admin_support_test',Path(__file__).resolve().parents[2]/'install/admin_support.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    vault=tmp_path/'hejo';vault.mkdir();receipt={};saved=[]
    def save(home,value):saved.append(json.loads(json.dumps(value)))
    assert module.prepare(tmp_path,receipt,save,dependencies=lambda:False) and receipt['admin']['state']=='skipped'
    assert module.prepare(tmp_path,receipt,save,dependencies=lambda:True)
    token=json.loads((vault/'admin.json').read_text())['token']
    assert token not in json.dumps(saved) and token.encode() not in (vault/'admin.plist').read_bytes()
    assert module.check(tmp_path,receipt)
    assert module.remove(tmp_path,receipt,save) and not (vault/'admin.json').exists()
    assert module.prepare(tmp_path,receipt,save,dependencies=lambda:True)
    (vault/'admin.json').write_text('owner change')
    assert not module.remove(tmp_path,receipt,save) and (vault/'admin.json').read_text()=='owner change'


@pytest.mark.asyncio
async def test_team_command_stdin_limit_allowlist_and_nonzero_outcome(tmp_path):
    from gate.connection_runtime import TeamKit
    folder=tmp_path/'bin';folder.mkdir()
    executable=folder/'hermes-connections'
    executable.write_text('''#!/usr/bin/env python3
import json,sys
raw=sys.stdin.read()
assert 'synthetic-private-value' not in ' '.join(sys.argv)
assert '--values-stdin' not in sys.argv
assert json.loads(raw)=={'value':'synthetic-private-value'}
print(json.dumps({'outcome':'refused','reason':'CHECK_FAILED'}))
sys.exit(1)
''');executable.chmod(0o700)
    team=TeamKit(tmp_path)
    assert await team.run('secret_set',profile='alpha',connection='sample',values={'value':'synthetic-private-value'})=={'outcome':'refused','reason':'CHECK_FAILED'}
    for verb in ('shell','arbitrary'):
        with pytest.raises(ConnectionFailure):await team.run(verb)
    with pytest.raises(ConnectionFailure):await team.run('secret_set',profile='alpha',connection='sample',values={'value':'x'*16385})


@pytest.mark.asyncio
async def test_team_timeout_child_terminated_and_reflection_not_audited(tmp_path,monkeypatch):
    import asyncio
    import gate.connection_runtime as runtime
    from gate.connection_manager import Connections
    folder=tmp_path/'bin';folder.mkdir();executable=folder/'hermes-connections'
    executable.write_text('#!/usr/bin/env python3\nimport time\ntime.sleep(10)\n');executable.chmod(0o700)
    original=asyncio.wait_for;timeouts=[]
    async def bounded(awaitable,seconds):
        timeouts.append(seconds);return await original(awaitable,min(seconds,.05))
    monkeypatch.setattr(runtime.asyncio,'wait_for',bounded)
    with pytest.raises(ConnectionFailure):await runtime.TeamKit(tmp_path).run('check',profile='alpha',connection='sample')
    assert timeouts[0]==30
    executable.unlink()
    manager=Connections(tmp_path,lambda:[{'id':'alpha','name':'직원 A'}],admin=CatalogAdmin(),snapshot=lambda:None)
    async def reflected(*args):return {'outcome':'synthetic-private-value','reason':'OK'}
    monkeypatch.setattr(manager,'execute',reflected)
    with pytest.raises(ConnectionFailure):
        await manager.perform('device',{'profile':'alpha','connection':'key:SYNTHETIC_KEY','action':'secret_set','reauth':True,'values':{'value':'synthetic-private-value'}})
    assert not manager.audit.path.exists()


@pytest.mark.asyncio
async def test_official_mcp_catalog_and_device_oauth_use_profile_and_no_raw_errors(tmp_path):
    from gate.connection_manager import Connections
    class Management(CatalogAdmin):
        def __init__(self):super().__init__();self.calls=[]
        async def request(self,method,route,*,profile=None,body=None):
            self.calls.append((method,route,profile,body))
            if route=='/api/mcp/catalog':return {'entries':[{'name':'sample','description':'시험 도구','installed':False,'required_env':[]}]}
            if route=='/api/mcp/catalog/install':return {'ok':True,'background':False}
            if route=='/api/providers/oauth':return {'providers':[{'id':'nous','name':'Nous','flow':'device_code'},{'id':'qwen','name':'Qwen','flow':'external','cli_command':'hermes login'}]}
            if route.endswith('/start'):return {'session_id':'synthetic-session','user_code':'TEST-CODE','verification_url':'https://example.invalid/device','access_token':'synthetic-private-value','error':'synthetic-private-value'}
            if '/poll/' in route:return {'status':'approved','access_token':'synthetic-private-value','error_message':'synthetic-private-value'}
            return await super().request(method,route,profile=profile,body=body)
    admin=Management();manager=Connections(tmp_path,lambda:[{'id':'alpha','name':'직원 A'}],admin=admin,snapshot=lambda:None)
    async def perform(connection,verb,device='device'):
        return await manager.perform(device,{'profile':'alpha','connection':connection,'action':verb,'reauth':True})
    assert (await perform('catalog:sample','catalog_install'))['outcome']=='done'
    assert admin.calls[-1]==('POST','/api/mcp/catalog/install','alpha',{'name':'sample','enable':True,'env':{}})
    result=await perform('oauth:nous','oauth_connect');assert 'access_token' not in result
    result=await perform('synthetic-session','oauth_poll');assert result=={'status':'approved'}
    assert (await perform('synthetic-session','oauth_poll','other'))['reason']=='UNKNOWN_JOB'
    assert '서버에서' in (await perform('oauth:qwen','oauth_guide'))['instruction']
    assert not any(c[1]=='/api/providers/oauth/qwen/start' for c in admin.calls)
    assert b'synthetic-private-value' not in manager.audit.path.read_bytes()


@pytest.mark.asyncio
async def test_restart_command_refusal_is_not_pending_or_consumed_cooldown(tmp_path):
    from gate.connection_runtime import RestartJobs
    state={'pid':1,'start_time':900,'active_agents':0,'platforms':{}}
    jobs=RestartJobs(tmp_path,None,clock=lambda:1000,snapshot=lambda:state)
    async def declined():return {'outcome':'refused','reason':'BUSY'}
    result=await jobs.start('device','alpha',restart=declined)
    assert result['outcome']=='refused' and result['reason']=='BUSY'
    assert jobs.audit.rows()[-1]['outcome']=='refused'
    async def launched():return {'outcome':'done'}
    assert (await jobs.start('device','alpha',restart=launched))['outcome']=='pending'


def test_server_terminology_does_not_rewrite_ids_or_paths():
    from gate.connection_manager import server_words
    original={'next':{'hint':'이 Mac에서 허용해 주세요','options':[{'id':'이 Mac','mac_path':'이 Mac/자료'}]},'rules':['맥미니에서 실행해요']}
    translated=server_words(original)
    assert translated['next']['hint']=='서버에서 허용해 주세요' and translated['rules']==['서버에서 실행해요']
    assert translated['next']['options']==original['next']['options']
