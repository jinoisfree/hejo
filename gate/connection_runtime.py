"""Durable action receipts and bounded, fixed-command administration on the server."""
import asyncio
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import time
import uuid

from .connections import ConnectionFailure, MAX_VALUES_BYTES

RESTART_WINDOW = 3600
RESTART_TIMEOUT = 180


class ActionJournal:
    def __init__(self, home, clock=time.time):
        self.path = Path(home)/'shared/hejo/actions.jsonl'
        self.clock = clock

    def rows(self):
        try:
            return [json.loads(line) for line in self.path.read_text().splitlines()]
        except FileNotFoundError:
            return []

    def append(self, *, device, profile, connection, action, outcome, job=None, identity=None, connected=None, expected=None, deadline=None):
        row={'at':self.clock(),'device':device,'profile':profile,'connection':connection,'action':action,'outcome':outcome}
        if job:row['job']=job
        if identity:row['identity']={'pid':identity['pid'],'start_time':identity['start_time']}
        if connected is not None:row['connected']=connected
        if expected is not None:row['expected']=expected
        if deadline:row['deadline']=deadline
        self.path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
        fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_APPEND,0o600)
        try:
            os.fchmod(fd,0o600)
            with os.fdopen(fd,'a') as stream:
                stream.write(json.dumps(row,ensure_ascii=False)+'\n');stream.flush();os.fsync(stream.fileno())
        except BaseException:
            # fdopen owns the descriptor after construction.
            raise
        return row


def runtime_snapshot():
    """Official runtime identity and freshness; no log text or secret file is read."""
    from gateway.status import read_runtime_status, runtime_status_pid_is_live, runtime_status_is_stale
    row=read_runtime_status()
    if not row or runtime_status_is_stale(row) or not runtime_status_pid_is_live(row):
        return None
    return row


def identity(row):
    return {'pid':row['pid'],'start_time':row['start_time']}


def started_at(row):
    value=row.get('start_time')
    if isinstance(value,(int,float)):return float(value)
    return datetime.fromisoformat(str(value).replace('Z','+00:00')).timestamp()


def platform_entries(row):
    from gateway.status import profile_platforms_from_multiplexer
    profiles=row.get('served_profiles') or ['default']
    return {profile+':'+key:value for profile in profiles
            for key,value in profile_platforms_from_multiplexer(row,profile).items()
            if value.get('state')!='disabled' and not value.get('mirrored_from')}


def platform_counts(row, expected):
    actual=platform_entries(row)
    connected=sum(actual.get(key,{}).get('state')=='connected'
                  and actual[key].get('writer_pid')==row.get('pid')
                  and actual[key].get('writer_start_time')==row.get('start_time') for key in expected)
    return len(expected),connected


class RestartJobs:
    def __init__(self, home, admin, *, clock=time.time, snapshot=runtime_snapshot):
        self.admin=admin;self.clock=clock;self.snapshot=snapshot
        self.audit=ActionJournal(home,clock);self.lock=asyncio.Lock()

    async def start(self, device, profile, *, restart=None):
        async with self.lock:
            state=self.snapshot()
            if not state or type(state.get('active_agents')) is not int:
                return {'outcome':'refused','reason':'BUSY_CHECK_FAILED'}
            if state['active_agents']>0 or state.get('active_work'):
                return {'outcome':'refused','reason':'BUSY'}
            history=self.audit.rows()
            declined={r.get('job') for r in history if r['outcome'] in {'refused','failed'}}
            past=[row for row in history if row['action']=='gateway_restart' and row['outcome']=='pending' and row.get('job') not in declined]
            if past and self.clock()-past[-1]['at']<RESTART_WINDOW:
                return {'outcome':'refused','reason':'RATE_LIMITED','last_restart_at':past[-1]['at']}
            job=str(uuid.uuid4())
            # This append must succeed before the request that can stop this process.
            self.audit.append(device=device,profile=profile,connection='gateway',action='gateway_restart',outcome='pending',job=job,identity=identity(state),expected=sorted(platform_entries(state)))
            try:
                answer=await restart() if restart else await self.admin.request('POST','/api/gateway/restart',profile='default')
                if isinstance(answer,dict) and answer.get('outcome') in {'refused','failed'}:
                    self.audit.append(device=device,profile=profile,connection='gateway',action='gateway_restart',outcome=answer['outcome'],job=job)
                    reason=answer.get('reason')
                    if reason not in {'BUSY','BUSY_CHECK_FAILED','RATE_LIMITED','RESTART_FAILED','RESTART_TIMEOUT'}:reason='RESTART_FAILED'
                    return {'outcome':answer['outcome'],'reason':reason,'job':job}
            except ConnectionFailure:
                # The request can have reached the backend before the transport failed.
                # Resolve through the saved identity; never retry the side effect.
                pass
            return {'outcome':'pending','reason':'OK','job':job}

    def result(self, job, device):
        all_rows=self.audit.rows()
        if job=='latest':
            previous=[r for r in all_rows if r.get('job') and r['device']==device and self.clock()-r['at']<RESTART_WINDOW]
            if not previous:return {'outcome':'refused','reason':'UNKNOWN_JOB'}
            job=previous[-1]['job']
        rows=[row for row in all_rows if row.get('job')==job]
        if not rows or rows[0]['device']!=device:
            return {'outcome':'refused','reason':'UNKNOWN_JOB'}
        request=rows[0]
        if rows[-1]['outcome']!='pending':
            return {key:rows[-1][key] for key in ('outcome','job','connected') if key in rows[-1]}
        state=self.snapshot();outcome='pending';connected=0
        try:
            fresh=state and identity(state)!=request['identity'] and started_at(state)>request['at']
        except (KeyError,ValueError,TypeError):fresh=False
        if fresh:
            expected,connected=platform_counts(state,request['expected'])
            if connected==expected:outcome='done'
            elif self.clock()-request['at']>=RESTART_TIMEOUT:outcome='partial' if connected else 'unknown'
        elif self.clock()-request['at']>=RESTART_TIMEOUT:outcome='timeout' if state else 'unknown'
        if outcome!='pending':
            self.audit.append(device=device,profile=request['profile'],connection='gateway',action='gateway_restart',outcome=outcome,job=job,connected=connected)
        return {'outcome':outcome,'job':job,'connected':connected}


class TeamKit:
    """Only the installed fixed entry point is executable. Submitted values use stdin only."""
    def __init__(self, home):
        self.home=Path(home);self.executable=self.home/'bin/hermes-connections'

    @property
    def available(self):return self.executable.is_file() and os.access(self.executable,os.X_OK)

    async def run(self, verb, *, profile=None, connection=None, values=None, options=None):
        if verb=='status':args=['status','--json'];seconds=30
        elif verb in {'check','check_all'}:
            args=['check','--profile',profile,'--all'] if verb=='check_all' else ['check','--profile',profile,'--connection',connection]
            args+=['--json'];seconds=90 if verb=='check_all' else 30
        elif verb in {'secret_guide','secret_set','secret_undo'}:
            args=['secret',verb.split('_',1)[1],'--profile',profile,'--connection',connection,'--json'];seconds=30
        elif verb in {'permission_request','open_settings'}:
            args=['permission','request' if verb=='permission_request' else 'settings','--profile',profile,'--connection',connection,'--json'];seconds=130 if verb=='permission_request' else 30
        elif verb=='gateway_restart':args=['gateway','restart','--json'];seconds=150
        elif verb in {'reconnect_start','reconnect_status'} and connection in {'personal','company'}:
            args=['reconnect',verb.split('_',1)[1],'--account',connection,'--json'];seconds=30
        elif verb=='apps':args=['apps','--json'];seconds=30
        elif verb in {'account_connect','account_disconnect','account_undo','account_status','account_cancel'} and connection in {'google','google-personal','google-company','x','instagram'}:
            args=['account',verb.split('_',1)[1],'--profile',profile,'--connection',connection,'--json'];seconds=30
            options=options or {}
            if verb in {'account_status','account_cancel'}:
                if connection!='google-personal' or not isinstance(options.get('session'),str) or not options['session'] or len(options['session'])>128:
                    raise ConnectionFailure('invalid_action')
                args+=['--session',options['session']]
            if connection=='google-personal' and verb=='account_disconnect':
                if options.get('disconnect_mode')!='forget_account':raise ConnectionFailure('UPDATE_REQUIRED')
                args+=['--disconnect-mode','forget_account']
        elif verb in {'app_connect','app_disconnect','app_undo'}:
            args=['app',verb.split('_',1)[1],'--profile',profile,'--app',connection,'--json'];seconds=180
            options=options or {}
            if 'change' in options:
                if verb!='app_connect' or (not isinstance(options['change'],str) or options['change'] not in {'address','login','sync_root','values'}):raise ConnectionFailure('invalid_action')
                args+=['--change',options['change']]
            for key in ('account','scope'):
                for identifier in options.get(key,[]):
                    if not isinstance(identifier,str):raise ConnectionFailure('invalid_action')
                    args+=['--'+key,identifier]
            if options.get('default'):args+=['--default',options['default']]
            if options.get('resume'):
                if options['resume'] not in {'gateway_restart','permission_request','internet_accounts'}:raise ConnectionFailure('invalid_action')
                args+=['--resume',options['resume']]
            if values:args+=['--values-stdin']
        else:raise ConnectionFailure('invalid_action')
        raw=json.dumps(values).encode() if values is not None else None
        if raw and len(raw)>MAX_VALUES_BYTES:raise ConnectionFailure('FORMAT_INVALID')
        if any(not isinstance(a,str) for a in args):raise ConnectionFailure('invalid_action')
        try:
            proc=await asyncio.create_subprocess_exec(str(self.executable),*args,stdin=asyncio.subprocess.PIPE if raw else asyncio.subprocess.DEVNULL,
                stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.DEVNULL,
                env={**os.environ,'HERMES_HOME':str(self.home),'HERMES_DISABLE_LAZY_INSTALLS':'1','PYTHONDONTWRITEBYTECODE':'1'})
            async def exchange():
                if raw:
                    proc.stdin.write(raw);await proc.stdin.drain();proc.stdin.close()
                output=bytearray()
                while part:=await proc.stdout.read(65536):
                    output.extend(part)
                    if len(output)>1_000_000:raise ConnectionFailure('invalid_response')
                await proc.wait()
                # A zero exit code can still carry refused/failed: callers judge outcome.
                reply=json.loads(output)
                if not isinstance(reply,dict):raise ConnectionFailure('invalid_response')
                if proc.returncode and 'outcome' not in reply:raise ConnectionFailure('command_failed')
                return reply
            try:return await asyncio.wait_for(exchange(),seconds)
            finally:
                if proc.returncode is None:
                    proc.terminate()
                    try:await asyncio.wait_for(proc.wait(),.2)
                    except asyncio.TimeoutError:proc.kill();await proc.wait()
        except ConnectionFailure:raise
        except (OSError,ValueError,asyncio.TimeoutError):raise ConnectionFailure('command_failed') from None
