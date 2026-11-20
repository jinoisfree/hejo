"""Official loopback administration boundary; credential values never enter public replies."""
import asyncio
import hashlib
import json
import os
from pathlib import Path
import re
import time
from urllib.parse import quote

from aiohttp import ClientSession, ClientTimeout
from .auth import AuthStore

UNDO_SECONDS = 600
MAX_VALUES_BYTES = 16384


class ConnectionFailure(Exception):
    def __init__(self, reason, status=None):
        self.reason, self.status = reason, status
        super().__init__(reason)


class AdminClient:
    """The token stays on the server; redirects and non-loopback addresses are never used."""
    def __init__(self, home, *, timeout=30):
        self.timeout = timeout
        self.path = Path(home) / 'hejo' / 'admin.json'

    async def request(self, method, route, *, profile=None, body=None):
        try:
            if self.path.is_symlink() or self.path.stat().st_mode & 0o077:
                raise ConnectionFailure('admin_unavailable')
            settings = json.loads(self.path.read_text())
            port, token = settings['port'], settings['token']
            if type(port) is not int or not 1 <= port <= 65535 or not isinstance(token, str) or not token:
                raise ConnectionFailure('admin_unavailable')
        except (OSError, ValueError, KeyError, TypeError):
            raise ConnectionFailure('admin_unavailable') from None
        try:
            if not route.startswith('/api/') or '?' in route or '#' in route:
                raise ConnectionFailure('invalid_action')
            async with ClientSession(timeout=ClientTimeout(total=self.timeout), trust_env=False) as session:
                async with session.request(method, f'http://127.0.0.1:{port}'+route,
                        params={'profile':profile} if profile else None, json=body,
                        headers={'X-Hermes-Session-Token':token}, allow_redirects=False) as response:
                    if not 200 <= response.status < 300:
                        raise ConnectionFailure('admin_failed', response.status)
                    # Bounded before decoding; raw error bodies never enter exceptions or logs.
                    raw = bytearray()
                    async for part in response.content.iter_chunked(65536):
                        raw.extend(part)
                        if len(raw) > 1_000_000:
                            raise ConnectionFailure('invalid_response')
                    try:
                        return json.loads(raw)
                    except (ValueError, UnicodeError, TypeError):
                        raise ConnectionFailure('invalid_response') from None
        except ConnectionFailure:
            raise
        except (OSError, ValueError, KeyError, TypeError, asyncio.TimeoutError):
            raise ConnectionFailure('admin_unavailable') from None
        except Exception:
            # Transport implementations may include credentials in exception strings.
            raise ConnectionFailure('admin_unavailable') from None


class SecretTransactions:
    """Serial official writes, ten-minute undo and D9 compensation; never writes Hermes files."""
    def __init__(self, home, admin, clock=time.time):
        self.admin, self.clock = admin, clock
        self.store = AuthStore(home)
        self.store.path = Path(home) / 'hejo' / 'undo'
        self.lock = asyncio.Lock()

    def filename(self, profile, key):
        return hashlib.sha256((profile+'\0'+key).encode()).hexdigest()+'.json'

    def purge(self):
        if not self.store.path.exists():return
        with self.store.locked():
            for path in self.store.path.glob('*.json'):
                value = json.loads(path.read_text())
                if self.clock() >= value['until']:
                    path.unlink()

    def undo_available(self,profile,key):
        try:
            saved=self.store.read(self.filename(profile,key),None)
            return bool(isinstance(saved,dict) and saved.get('until',0)>self.clock())
        except (OSError,ValueError,TypeError):
            return False

    async def previous(self, profile, key):
        try:
            result = await self.admin.request('POST','/api/env/reveal',profile=profile,body={'key':key})
        except ConnectionFailure as error:
            if error.status == 404:
                return None
            raise
        if result.get('key') != key or not isinstance(result.get('value'),str):
            raise ConnectionFailure('invalid_response')
        return result['value']

    async def put(self, profile, key, value):
        await self.admin.request('DELETE' if value is None else 'PUT', '/api/env', profile=profile,
                                 body={'key':key} if value is None else {'key':key,'value':value})

    async def compensate(self, profile, key, previous):
        try:
            try:
                await self.put(profile,key,previous)
            except ConnectionFailure as error:
                # DELETE of an already absent value has achieved the desired state.
                if not (previous is None and error.status == 404):
                    raise
            rows = await self.admin.request('GET','/api/env',profile=profile)
            if bool(rows.get(key,{}).get('is_set')) != bool(previous):
                return False
            return True
        except ConnectionFailure:
            return False

    async def save(self, profile, key, value):
        if not re.fullmatch(r'[A-Z_][A-Z0-9_]{0,199}',key) or not isinstance(value,str) or not value or len(value.encode())>4096 or any(ord(c)<32 or ord(c)==127 for c in value):
            return {'outcome':'refused','reason':'FORMAT_INVALID'}
        async with self.lock:
            self.purge()
            check = await self.admin.request('POST','/api/providers/validate',profile=profile,
                                             body={'key':key,'value':value})
            if check.get('ok') is not True:
                return {'outcome':'refused','reason':'CHECK_FAILED'}
            previous = await self.previous(profile,key)
            until = self.clock()+UNDO_SECONDS
            name = self.filename(profile,key)
            with self.store.locked():
                self.store.write(name,{'profile':profile,'key':key,'previous':previous,'until':until})
            try:
                await self.put(profile,key,value)
            except ConnectionFailure:
                restored = await self.compensate(profile,key,previous)
                if restored:
                    (self.store.path/name).unlink(missing_ok=True)
                return {'outcome':'failed' if restored else 'partial',
                        'reason':'WRITE_FAILED' if restored else 'write_partial'}
            return {'outcome':'done','reason':'OK','undo_until':until,
                    'state':'connected' if check.get('reachable') is True else 'unknown',
                    'instruction':'연결됨' if check.get('reachable') is True else '키 저장됨(확인 안 함)'}

    async def undo(self, profile, key):
        async with self.lock:
            self.purge()
            name=self.filename(profile,key)
            with self.store.locked():
                saved=self.store.read(name,None)
            if not saved or saved.get('profile')!=profile or saved.get('key')!=key:
                return {'outcome':'refused','reason':'EXPIRED'}
            current=await self.previous(profile,key)
            try:
                await self.put(profile,key,saved['previous'])
            except ConnectionFailure:
                restored=await self.compensate(profile,key,current)
                return {'outcome':'failed' if restored else 'partial',
                        'reason':'WRITE_FAILED' if restored else 'write_partial'}
            (self.store.path/name).unlink(missing_ok=True)
            return {'outcome':'done','reason':'OK'}
