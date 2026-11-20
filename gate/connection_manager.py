"""Member-scoped connection documents and owner-confirmed actions; no journal/broadcast path."""
import asyncio
from datetime import datetime, timezone
import json
import logging
from pathlib import Path
import re
import uuid
from urllib.parse import quote

from .connections import AdminClient, ConnectionFailure, SecretTransactions, MAX_VALUES_BYTES
from .connection_runtime import ActionJournal, RestartJobs, TeamKit, runtime_snapshot, platform_entries

log = logging.getLogger(__name__)

DEVICE_PROVIDERS={'nous','openai-codex','minimax-oauth','xai-oauth'}
PUBLIC_KEYS={'schema','checked_at','agents','profile','display_name','connections','id','service','label','reason','group','state','account','scope','reconnect','capabilities','rules','connect_kind','verified_by','expires_at','actions','primary','action','outcome','check','results','saved_names','restart_required','undo_until','url','instruction','fields','guide','n','text','open_url','copy','image','field','pattern','message','secure','last_restart_at','connected','missing','next','kind','steps','needs_user','hint','pane','target','resume_key','options','disabled','multi','needs_default','other_account','account_settings','input_error','app','role_hint','bundle_id','name','scanned_at','apps','features','applescript','app_intents','url_schemes','links','route','can_do','available','tools','connection_key','progress','connected','connectable','unavailable','server_path','mac_path','status','session_id','user_code','verification_url','poll_interval','expires_in','job','select_all','selected','scope','value','required','unread','part','hidden_by_default'}


def public(value, secrets=()):
    """Allow fields, never error/detail/log/preview/value; reject reflected input credentials."""
    if isinstance(value,dict):return {k:public(v,secrets) for k,v in value.items() if k in PUBLIC_KEYS and not (k=='value' and value.get('secure') is not False)}
    if isinstance(value,list):return [public(v,secrets) for v in value]
    if isinstance(value,str) and any(secret and secret in value for secret in secrets):
        raise ConnectionFailure('invalid_response')
    return value


def server_words(value, text=False):
    """Apply the approved terminology only to prose, never ids, URLs or file paths."""
    if isinstance(value,dict):return {key:server_words(item,key in {'text','hint','instruction','capabilities','rules'}) for key,item in value.items()}
    if isinstance(value,list):return [server_words(item,text) for item in value]
    if isinstance(value,str) and text:return value.replace('공항 Mac','서버').replace('맥미니','서버').replace('이 Mac','서버')
    return value


def stamp():return datetime.now(timezone.utc).isoformat()


def action(name,label,primary=False):return {'id':name,'label':label,'primary':primary}


def row(identifier,label,group='account',*,state='unknown',reason='CONFIG_ONLY',actions=(),description=''):
    return {'id':identifier,'service':identifier.split(':',1)[0],'label':label,'group':group,'state':state,'reason':reason,'checked_at':stamp(),
            'capabilities':[description] if description else [],'rules':['동작은 서버에서 실행해요. 위험한 동작은 다시 확인해요.'],'actions':list(actions)}


class Connections:
    def __init__(self, home, employees, *, admin=None, snapshot=runtime_snapshot):
        self.home=Path(home);self.employees=employees;self.admin=admin or AdminClient(home)
        self.secrets=SecretTransactions(home,self.admin);self.team=TeamKit(home)
        self.audit=ActionJournal(home);self.jobs=RestartJobs(home,self.admin,snapshot=snapshot)
        self.snapshot=snapshot;self.sessions={}
        self.documents={};self.input_fields={}

    def profiles(self):return {p['id']:p for p in self.employees()}

    async def document(self, profile=None):
        people=self.profiles()
        if profile is not None and profile not in people:raise ConnectionFailure('UNKNOWN_PROFILE')
        agents=[];admin_results=[]
        shared_failures={}

        def failed(identifier, part, error, unread):
            reason=error.reason if isinstance(error,ConnectionFailure) else 'invalid_response'
            status=error.status if isinstance(error,ConnectionFailure) else None
            unread.setdefault(part,{'part':part,'reason':reason})
            log.warning("connections_part_failed profile=%s part=%s reason=%s status=%s",
                        identifier,part,reason,status if status is not None else '-')

        def mapping(value):
            if not isinstance(value,dict):raise ConnectionFailure('invalid_response')
            return value

        def rows(value):
            if not isinstance(value,list) or any(not isinstance(v,dict) for v in value):
                raise ConnectionFailure('invalid_response')
            return value

        async def shared(command, schema):
            if not self.team.available:return {}
            try:
                raw=mapping(await self.team.run(command))
                if raw['schema']!=schema:raise ConnectionFailure('invalid_response')
                return {a['profile']:a for a in rows(raw['agents']) if a['profile'] in people}
            except (ConnectionFailure,KeyError,TypeError) as error:
                shared_failures['team_status' if command=='status' else 'apps']=error
                return {}

        team=await shared('status','hermes-connections/1')
        apps=await shared('apps','hermes-installed-apps/1')
        for identifier,person in people.items():
            if profile is not None and profile!=identifier:continue
            items=[];unread={}
            for part,error in shared_failures.items():failed(identifier,part,error,unread)

            async def read(part, route, build):
                try:
                    raw=await self.admin.request('GET',route,profile=identifier)
                    value=build(raw)
                except (ConnectionFailure,KeyError,TypeError) as error:
                    failed(identifier,part,error,unread)
                    admin_results.append(error.reason if isinstance(error,ConnectionFailure) else 'invalid_response')
                    return None
                admin_results.append(None)
                return value

            def tool_rows(raw):
                return [(tool['name'],tool.get('enabled') is True,
                         row('tool:'+tool['name'],tool.get('label') or tool['name'],'tool',
                             state='unknown' if tool.get('enabled') is True else 'off',
                             actions=[action('disable' if tool.get('enabled') is True else 'enable',
                                             '끄기' if tool.get('enabled') is True else '켜기',True)],
                             description=tool.get('description',''))) for tool in rows(raw)]

            required=set()
            for name,enabled,item in await read('toolsets','/api/tools/toolsets',tool_rows) or []:
                items.append(item)
                def config_details(raw):
                    raw=mapping(raw);caps=[];keys=set()
                    if raw.get('has_category') is False:caps.append('키 필요 없음')
                    for provider in rows(raw['providers']):
                        fields=rows(provider['env_vars'])
                        keys.update(k['key'] for k in fields)
                        caps.append(provider['name']+': '+(', '.join(k['key']+(' — 키 저장됨(확인 안 함)' if k.get('is_set') else ' — 키 없음') for k in fields) if fields else '키 필요 없음'))
                    return caps,keys
                config=await read('toolset_config','/api/tools/toolsets/'+quote(name,safe='')+'/config',config_details)
                if config is not None:
                    item['capabilities'].extend(config[0])
                    if enabled:required.update(config[1])

            def key_rows(raw):
                result=[]
                for key,info in mapping(raw).items():
                    present=mapping(info)['is_set'] is True
                    if not present and key not in required:continue
                    result.append(row('key:'+key,info.get('provider_label') or key,reason='KEY_UNVERIFIED' if present else 'NO_TOKEN',
                        actions=[action('secret_set','키 바꾸기' if present else '연결',True)]+([action('secret_undo','되돌리기')] if self.secrets.undo_available(identifier,key) else []),
                        description='키 저장됨(확인 안 함)' if present else '키 없음'))
                return result
            items.extend(await read('env','/api/env',key_rows) or [])

            def mcp_rows(raw):
                result=[]
                for server in rows(mapping(raw)['servers']):
                    name=server['name'];enabled=server.get('enabled',True)
                    result.append(row('mcp:'+name,name,'tool',state='unknown' if enabled else 'off',
                        actions=[action('check','시험',True),action('disable' if enabled else 'enable','끄기' if enabled else '켜기'),action('mcp_delete','삭제'),action('mcp_login','로그인 안내')]))
                result.append(row('mcp','MCP 서버','tool',actions=[action('mcp_add','추가',True)]))
                return result
            items.extend(await read('mcp','/api/mcp/servers',mcp_rows) or [])

            def catalog_rows(raw):
                result=[]
                for entry in rows(mapping(raw)['entries']):
                    if entry.get('installed'):continue
                    item=row('catalog:'+entry['name'],entry['name'],'tool',actions=[action('catalog_install','설치',True)],description=entry.get('description',''))
                    item['hidden_by_default']=True;result.append(item)
                return result
            items.extend(await read('catalog','/api/mcp/catalog',catalog_rows) or [])

            def oauth_rows(raw):
                result=[]
                for provider in rows(raw if isinstance(raw,list) else mapping(raw)['providers']):
                    name=provider['id'];external=provider.get('flow')=='external'
                    result.append(row('oauth:'+name,provider.get('name') or provider.get('label') or name,
                        actions=[action('oauth_guide' if external else 'oauth_connect','서버 로그인 안내' if external else '다시 연결',True)],
                        description=('서버에서 '+provider.get('cli_command','공식 로그인 명령')+'을 실행해 주세요') if external else '브라우저에서 동의해 주세요'))
                return result
            items.extend(await read('oauth','/api/providers/oauth',oauth_rows) or [])

            if 'team_status' not in shared_failures:
                try:
                    part_items=[]
                    for item in rows(team.get(identifier,{}).get('connections',[])):
                        item=public(item);item['id']='team:'+item['id'];part_items.append(item)
                    items.extend(part_items)
                except (ConnectionFailure,KeyError,TypeError) as error:failed(identifier,'team_status',error,unread)
            if 'apps' not in shared_failures:
                try:
                    part_items=[]
                    group=mapping(apps.get(identifier,{}))
                    for category in ('connected','connectable','unavailable'):
                        for app in rows(group.get(category,[])):
                            progress=mapping(app.get('progress') or {});actions=[]
                            if category!='unavailable':actions.append(action('app_connect','이어서 하기' if progress.get('next') else '범위 바꾸기' if category=='connected' else '연결',True))
                            if category=='connected':actions.append(action('app_disconnect','해제'))
                            if progress.get('undo_until'):actions.append(action('app_undo','되돌리기' if category=='connected' else '처음부터 다시'))
                            item=row('app:'+app.get('connection_key',app['bundle_id']),app['name'],'mac',state='connected' if category=='connected' else 'unknown',actions=actions,description=app.get('can_do',''))
                            item['rules']=app.get('rules',[]);item['next']=progress.get('next')
                            if category=='unavailable':item['hidden_by_default']=True
                            part_items.append(item)
                    items.extend(part_items)
                except (ConnectionFailure,KeyError,TypeError) as error:failed(identifier,'apps',error,unread)
            try:
                part_items=[];state=self.snapshot()
                if state:
                    for name,entry in platform_entries(state).items():
                        if not name.startswith(identifier+':'):continue
                        part_items.append(row('channel:'+name,name.split(':',1)[1],'channel',state='connected' if entry.get('state')=='connected' else 'unknown'))
                items.extend(part_items)
            except (ConnectionFailure,KeyError,TypeError) as error:failed(identifier,'runtime',error,unread)
            items.append(row('gateway','게이트웨이','channel',actions=[action('gateway_restart','다시 시작',True)]))
            agent={'profile':identifier,'display_name':person['name'],'connections':items}
            if unread:agent['unread']=list(unread.values())
            self.documents[identifier]=agent;agents.append(agent)
        result={'schema':'hermes-connections/1','checked_at':stamp(),'agents':agents}
        if admin_results and all(reason=='admin_unavailable' for reason in admin_results):
            result['instruction']='서버의 관리 기능에 닿지 못했어요. 읽은 항목만 보여 드려요.'
        # The official plugin inventory is the count source; no guessed provider list.
        from hermes_cli.plugins import get_plugin_manager
        failed=sum(bool(p.get('error')) for p in get_plugin_manager().list_plugins() if p.get('kind') in {'backend','model-provider','exclusive'})
        result['unavailable_providers']=failed
        if len(json.dumps(result,ensure_ascii=False).encode())>1_000_000:raise ConnectionFailure('too_large')
        return server_words(result)

    async def perform(self, device, frame):
        profile,connection,verb=frame['profile'],frame['connection'],frame['action']
        if profile not in self.profiles():return {'outcome':'refused','reason':'UNKNOWN_PROFILE'}
        if verb=='job_status':return self.jobs.result(connection,device)
        if verb=='oauth_poll':
            owned=self.sessions.get(connection)
            if not owned or owned[:2]!=(device,profile):return {'outcome':'refused','reason':'UNKNOWN_JOB'}
            provider=owned[2]
            if provider.startswith('team:'):
                result=await self.team.run('reconnect_status',connection=provider.split(':',1)[1])
                return {'status':'approved' if result.get('state')=='connected' else 'pending' if result.get('state')=='running' else 'error'}
            return public(await self.admin.request('GET','/api/providers/oauth/'+quote(provider,safe='')+'/poll/'+quote(connection,safe=''),profile=profile))
        if verb not in {'secret_guide','check','check_all','oauth_guide','mcp_login','apps'} and frame.get('reauth') is not True:
            return {'outcome':'refused','reason':'reauth_required'}
        values=frame.get('values',{})
        if not isinstance(values,dict) or len(json.dumps(values).encode())>MAX_VALUES_BYTES:return {'outcome':'refused','reason':'FORMAT_INVALID'}
        # Fresh authoritative actions, not a client-supplied command list.
        await self.document(profile)
        item=next((r for r in self.documents[profile]['connections'] if r['id']==connection),None)
        special=verb in {'secret_guide','secret_undo'} and item and any(a['id']=='secret_set' for a in item['actions'])
        if not item or not (special or any(a['id']==verb for a in item['actions']) or verb=='check_all'):
            return {'outcome':'refused','reason':'invalid_action'}
        form=(device,profile,connection)
        def secure_fields(value):
            if isinstance(value,dict):
                result={f['id'] for f in value.get('fields',[]) if isinstance(f,dict) and f.get('secure') is True and isinstance(f.get('id'),str)}
                for child in value.values(): result.update(secure_fields(child))
                return result
            if isinstance(value,list): return set().union(*(secure_fields(child) for child in value)) if value else set()
            return set()
        protected=secure_fields(item) | self.input_fields.get(form,set())
        if connection.startswith('key:') and verb=='secret_set': protected.add('value')
        if connection.startswith('catalog:') and verb=='catalog_install': protected.update(values)
        secrets=tuple(v for key,v in values.items() if key in protected and isinstance(v,str))
        try:
            reply=await self.execute(device,profile,connection,verb,values,item)
        except ConnectionFailure as error:
            log.warning('connections_failed type=connection_action profile=%s reason=%s',profile,error.reason)
            reply={'outcome':'failed','reason':error.reason}
        finally:
            frame.pop('values',None)
        self.input_fields[form]=secure_fields(reply)
        reply=public(reply,secrets)
        outcome=reply.get('outcome','done')
        if outcome not in {'done','pending','partial','unknown','timeout','failed','refused','needs_user','waiting'}:raise ConnectionFailure('invalid_response')
        self.audit.append(device=device,profile=profile,connection=connection,action=verb,outcome=outcome)
        if reply.get('reason')=='write_partial':reply['instruction']='저장이 중간에 멈췄어요. 서버에서 이 키를 확인해 주세요'
        return server_words(public(reply,secrets))

    async def execute(self, device, profile, connection, verb, values, item):
        kind,_,name=connection.partition(':')
        if verb=='check_all':
            results=[]
            for target in self.documents[profile]['connections']:
                if target['id'].startswith('mcp:'):
                    results.append(await self.execute(device,profile,target['id'],'check',{},target))
            if self.team.available:results.append(public(await self.team.run('check_all',profile=profile)))
            return {'outcome':'done','reason':'OK','results':results}
        if connection=='gateway' and verb=='gateway_restart':
            restart=(lambda:self.team.run('gateway_restart')) if self.team.available else None
            return await self.jobs.start(device,profile,restart=restart)
        if kind=='team':
            target=item.get('reconnect') or item.get('scope')
            command='reconnect_start' if verb=='oauth_connect' else verb
            result=await self.team.run(command,profile=profile,connection=target if verb=='oauth_connect' else name,values=values if verb=='secret_set' else None)
            await self.team.run('status')
            if verb=='oauth_connect':
                if result.get('state')=='running':
                    session=str(uuid.uuid4());self.sessions[session]=(device,profile,'team:'+target)
                    return {'session_id':session,'verification_url':result.get('url'),'outcome':'pending'}
                return {'outcome':'done' if result.get('state')=='connected' else 'refused','reason':result.get('reason','CHECK_FAILED')}
            if verb=='open_settings':result['instruction']='서버에서 허용해 주세요'
            return public(result)
        if kind=='app' and verb in {'app_connect','app_disconnect','app_undo'}:
            options={}
            for key in ('account','scope'):
                if key in values:
                    options[key]=json.loads(values[key])
                    if not isinstance(options[key],list):raise ConnectionFailure('FORMAT_INVALID')
            for key in ('default','resume'):
                if key in values:options[key]=values[key]
            body={k:v for k,v in values.items() if k not in {'account','scope','default','resume'}}
            async def run():return await self.team.run(verb,profile=profile,connection=name,values=body or None,options=options)
            if options.get('resume')=='gateway_restart':return await self.jobs.start(device,profile,restart=run)
            result=await run()
            await self.team.run('status')
            return public(result)
        if kind=='key':
            if verb=='secret_guide':return {'outcome':'done','reason':'OK','fields':[{'id':'value','label':name,'secure':True}],'guide':[{'n':1,'text':'공식 서비스에서 키를 발급받아 붙여넣으세요.'}]}
            if verb=='secret_set':return await self.secrets.save(profile,name,values.get('value'))
            if verb=='secret_undo':return await self.secrets.undo(profile,name)
        if kind=='catalog' and verb=='catalog_install':
            catalog=await self.admin.request('GET','/api/mcp/catalog',profile=profile)
            entry=next((e for e in catalog.get('entries',[]) if e['name']==name),None)
            if entry is None:raise ConnectionFailure('invalid_action')
            required=entry.get('required_env',[])
            if required and not values:return {'outcome':'done','reason':'OK','fields':[{'id':e['name'],'label':e.get('prompt') or e['name'],'secure':True} for e in required]}
            changed=[]
            async def rollback(result):
                partial=result.get('reason')=='write_partial'
                for old in reversed(changed):
                    try:
                        if (await self.secrets.undo(profile,old))['outcome']!='done':partial=True
                    except Exception:
                        partial=True
                return {'outcome':'partial','reason':'write_partial'} if partial else result
            try:
                for field in required:
                    key=field['name']
                    if not values.get(key):continue
                    result=await self.secrets.save(profile,key,values[key])
                    if result['outcome']!='done':return await rollback(result)
                    changed.append(key)
            except Exception:
                return await rollback({'outcome':'failed','reason':'CONNECTIONS_READ_FAILED'})
            try:
                reply=await self.admin.request('POST','/api/mcp/catalog/install',profile=profile,body={'name':name,'enable':True,'env':{}})
            except ConnectionFailure:
                return await rollback({'outcome':'failed','reason':'WRITE_FAILED'})
            return {'outcome':'done','reason':'OK','instruction':'서버에서 설치가 진행돼요. 새로 확인을 눌러 결과를 확인해 주세요' if reply.get('background') else '설치했어요. 새로 확인해 주세요'}
        if kind=='tool' and verb in {'enable','disable'}:
            await self.admin.request('PUT','/api/tools/toolsets/'+quote(name,safe=''),profile=profile,body={'enabled':verb=='enable'})
        elif kind=='mcp':
            target='/api/mcp/servers/'+quote(name,safe='')
            if verb=='check':
                answer=await self.admin.request('POST',target+'/test',profile=profile)
                return {'outcome':'done' if answer.get('ok') else 'failed','reason':'OK' if answer.get('ok') else 'CHECK_FAILED'}
            if verb=='mcp_delete':await self.admin.request('DELETE',target,profile=profile)
            elif verb in {'enable','disable'}:await self.admin.request('PUT',target+'/enabled',profile=profile,body={'enabled':verb=='enable'})
            elif verb=='mcp_login':return {'outcome':'done','reason':'OK','instruction':'서버에서 로그인해 주세요'}
        elif connection=='mcp' and verb=='mcp_add':
            if not values:return {'outcome':'done','reason':'OK','fields':[{'id':'name','label':'이름','secure':False},{'id':'url','label':'MCP 주소','secure':False},{'id':'bearer_token','label':'비밀값(선택)','secure':True,'required':False}]}
            if not values.get('name') or not values.get('url'):raise ConnectionFailure('FORMAT_INVALID')
            body={k:values[k] for k in ('name','url','bearer_token') if values.get(k)}
            await self.admin.request('POST','/api/mcp/servers',profile=profile,body=body)
        elif kind=='oauth':
            if verb=='oauth_guide':return {'outcome':'done','reason':'OK','instruction':item['capabilities'][0]}
            if name not in DEVICE_PROVIDERS:raise ConnectionFailure('invalid_action')
            answer=await self.admin.request('POST','/api/providers/oauth/'+quote(name,safe='')+'/start',profile=profile)
            self.sessions[answer['session_id']]=(device,profile,name)
            return {k:answer[k] for k in ('session_id','user_code','verification_url','expires_in','poll_interval') if k in answer}
        else:raise ConnectionFailure('invalid_action')
        return {'outcome':'done','reason':'OK'}
