"""Remaining independent-review regressions; temporary homes and loopback only."""
import asyncio
from datetime import datetime, timezone
import json
from pathlib import Path
import runpy
import subprocess
import sys
import time
from types import SimpleNamespace as NS
import uuid
import pytest
from gate.connection_manager import Connections
from gate.files import UnknownFile
from gate.journal import Journal
from gate.server import Connection
from hub.state import MemberStateStore


@pytest.mark.asyncio
async def test_irs03_upload_body_does_not_own_file_commit_lock(gate,client,monkeypatch):
    from aiohttp import FormData, ClientSession
    ws,token=await client.pair();entered=asyncio.Event();release=asyncio.Event();stage=gate.files.stage
    async def stalled(*args):
        entered.set();await release.wait()
        assert not gate.files.lock.locked(), 'upload body must not hold files.lock'
        return await stage(*args)
    monkeypatch.setattr(gate.files,'stage',stalled)
    async with ClientSession() as session:
        data=FormData();data.add_field('file',b'fixture',filename='sample.txt')
        upload=asyncio.create_task(session.post(f'http://127.0.0.1:{gate.server.port}/v1/files?employee=alpha',data=data,headers={'Authorization':'Bearer '+token['token']}))
        try:
            await asyncio.wait_for(entered.wait(),2)
            assert not gate.files.lock.locked(), 'a stalled upload blocks all room commands'
        finally:release.set()
        response=await upload
        assert response.status==200


class Socket:
    def __init__(self,slow=False):self.closed=False;self.rows=[];self.slow=slow
    async def send_json(self,frame):
        if self.slow:await asyncio.Event().wait()
        self.rows.append(frame)
    async def close(self,**kwargs):self.closed=True


@pytest.mark.asyncio
async def test_irs04_slow_reader_does_not_hold_publication_lane(gate,monkeypatch):
    import gate.server as server
    monkeypatch.setattr(server,'SEND_TIMEOUT',.05,raising=False)
    slow,fast=Connection(Socket(True),'slow'),Connection(Socket(),'fast')
    gate.server.connections.update([slow,fast])
    try:
        await asyncio.wait_for(gate.server.broadcast({'v':1,'type':'ping'}),.03)
        async with asyncio.timeout(.5):
            while not slow.ws.closed or not fast.ws.rows:await asyncio.sleep(.005)
        assert not fast.ws.closed
    finally:gate.server.connections.difference_update([slow,fast])


@pytest.mark.asyncio
async def test_irs04_missing_pong_disconnects_only_that_connection(gate,client):
    ws,_=await client.pair();conn=next(c for c in gate.server.connections if c.device_id)
    conn.pong_deadline=time.monotonic()-1
    async with asyncio.timeout(1.5):
        while not conn.ws.closed:await asyncio.sleep(.02)


@pytest.mark.asyncio
async def test_irs05_only_secure_fields_are_reflection_inputs(tmp_path):
    manager=Connections(tmp_path,lambda:[{'id':'alpha'}])
    item={'id':'app:fixture','actions':[{'id':'app_connect'}],'fields':[{'id':'choice','secure':False}]}
    async def document(profile):manager.documents[profile]={'connections':[item]}
    async def execute(*args):return {'outcome':'waiting','reason':'SCOPE_INVALID','options':[{'id':'choice-a','label':'Fixture'}]}
    manager.document=document;manager.execute=execute
    result=await manager.perform('device',{'profile':'alpha','connection':'app:fixture','action':'app_connect','reauth':True,'values':{'choice':'choice-a'}})
    assert result['outcome']=='waiting' and result['options'][0]['id']=='choice-a'
    assert len(manager.audit.path.read_text().splitlines())==1


@pytest.mark.asyncio
async def test_irs07_individual_delete_hides_and_cleans_attachment(gate,client):
    from aiohttp import ClientSession
    async def chunks():yield b'fixture'
    info=await gate.files.stage('alpha','sample.txt',chunks());infos,moved=gate.files.promote('alpha',[info['file_id']])
    mid=str(uuid.uuid4());thread=str(uuid.uuid4())
    await gate.journal.append({'type':'message','msg_id':mid,'employee':'alpha','thread':thread,'role':'employee','text':'fixture'}, {'files':gate.files.registration('alpha','employee',infos)})
    path,_=gate.files.registered('alpha',info['file_id'])
    ws, welcome = await client.pair(since=gate.journal.head, features=['rooms', 'history-v1'])
    url = f"http://127.0.0.1:{gate.server.port}/v1/files/alpha/{info['file_id']}"
    async with ClientSession(trust_env=False, headers={'Authorization': 'Bearer ' + welcome['token']}) as http:
        async with http.get(url) as response:
            assert response.status == 200 and await response.read() == b'fixture'
        async with http.get(url + '/metadata') as response:
            assert response.status == 404
    await ws.close()
    await gate.journal.append({'type':'delete','msg_id':mid})
    with pytest.raises(UnknownFile):gate.files.registered('alpha',info['file_id'])
    gate.files.cleanup();assert not path.exists()


@pytest.mark.asyncio
async def test_irs08_clock_rollback_keeps_seq_file_order(tmp_path,monkeypatch):
    import gate.journal as module
    class Clock:
        month=12
        @classmethod
        def now(cls,tz):return datetime(2026,cls.month,1,tzinfo=timezone.utc)
    monkeypatch.setattr(module,'datetime',Clock)
    journal=Journal(tmp_path);journal.open()
    try:
        await journal.append({'type':'state','msg_id':'fixture','reply_state':'working'})
        Clock.month=11
        await journal.append({'type':'state','msg_id':'fixture','reply_state':'answered'})
    finally:journal.close()
    journal.open();assert journal.head==2;journal.close()
    assert [p.name for p in journal.path.glob('*.jsonl')]==['2026-12.jsonl']


@pytest.mark.parametrize('changed',[False,True])
def test_irs09_without_receipt_removes_only_exact_installer_block(tmp_path,changed):
    installer=runpy.run_path(str(Path(__file__).resolve().parents[2]/'install/hejo-install'))
    block=installer['PRIMARY']
    # Use the actual installer plan's block shape, never a guessed owner block.
    block=json.loads(json.dumps(block))
    if changed:block={**block,'module':'owner.module'}
    config=tmp_path/'config.yaml';config.write_text(installer['yaml_dump']({'gateway':{'platforms':{'hejo':block}},'model':'fixture'}))
    result=subprocess.run([sys.executable,str(Path(__file__).resolve().parents[2]/'install/hejo-install'),'--home',str(tmp_path),'--uninstall'],capture_output=True,text=True)
    after=installer['yaml_load'](config.read_text())
    if changed:assert result.returncode==2 and after['gateway']['platforms']['hejo']==block
    else:assert result.returncode==0 and 'hejo' not in after.get('gateway',{}).get('platforms',{})


def test_irs11_server_clamps_future_state(tmp_path):
    store=MemberStateStore(tmp_path);member=str(uuid.uuid4());now=time.time()
    result=store.patch(member,{'layout:test':{'v':'future','at':1e30,'dev':'fixture'}})
    assert now<=result['items']['layout:test']['at']<=time.time()+300
