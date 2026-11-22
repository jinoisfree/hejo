"""Forum second door: private ownership, topic routing and settled delivery."""
import asyncio
import hmac
import json
import logging
import os
import secrets
import time
from pathlib import Path

from .auth import AuthStore, PAIR_TTL, digest

log = logging.getLogger(__name__)
_telegram = None
SETTLE_SECONDS = 2.0


def platform_ready():
    return _telegram is not None and bool(getattr(_telegram, 'is_connected', False))


def attach_telegram(native, adapter):
    """Factories run before connection; never start network work here."""
    global _telegram
    _telegram = adapter
    if getattr(adapter, '_hejo_telegram_wrapped', False):
        return
    original = adapter.handle_message

    async def handle(event):
        from .adapter import _primary
        bridge = getattr(_primary, 'telegram', None)
        try:
            claimed = bridge is not None and bridge.claims_external(event)
        except Exception:
            log.warning('telegram_claim_failed')
            claimed = False
        if not claimed:
            return await original(event)
        try:
            accept = getattr(adapter, '_accept_update', None)
            if accept:
                accept()
            return await bridge.receive_external(event)
        except Exception as exc:
            log.warning('telegram_receive_failed kind=%s', type(exc).__name__)
            await bridge.notice(event, '지금은 받지 못했어요')

    adapter.handle_message = handle
    adapter._hejo_telegram_wrapped = True


class Telegram:
    def __init__(self, adapter, home, clock=time.time):
        self.adapter, self.clock = adapter, clock
        self.vault = AuthStore(home, clock)
        self.settings_store = AuthStore(home, clock)
        self.settings_store.path = Path(home) / 'shared' / 'hejo' / 'telegram'
        self.topic_problem = False
        self.settle_seconds = SETTLE_SECONDS

    def _private(self):
        try:
            value = self.vault.read('telegram.json', {'pair': None, 'code': None})
            pair, code = value['pair'], value['code']
            if pair is not None and not (isinstance(pair, dict) and pair.get('platform') == 'telegram'
                    and all(isinstance(pair.get(k), str) for k in ('chat_id', 'user_id', 'tag'))
                    and len(pair['tag']) == 8 and type(pair.get('paired_at')) in (int, float)):
                return None
            if code is not None and not (isinstance(code, dict) and isinstance(code.get('hash'), str)
                    and type(code.get('expires')) in (int, float) and type(code.get('used')) is bool):
                return None
            return value
        except (OSError, ValueError, TypeError, KeyError):
            return None

    def private(self):
        return self._private() or {'pair': None, 'code': None}

    def _settings(self):
        try:
            value = self.settings_store.read('settings.json', {'enabled': False})
            if type(value['enabled']) is bool:
                return {'enabled': value['enabled']}
        except (OSError, ValueError, TypeError, KeyError):
            pass
        return None

    def settings(self):
        return self._settings() or {'enabled': False}

    def active(self):
        return bool(self.adapter.is_connected and platform_ready() and self.private()['pair']
                    and self.settings()['enabled'])

    def status(self, ref=None):
        return {'v': 1, 'type': 'telegram_status', 'platform_ready': platform_ready(),
                'paired': self.private()['pair'] is not None, **self.settings(),
                'topic_problem': self.topic_problem, **({'ref': ref} if ref is not None else {})}

    async def publish(self, conn=None, ref=None):
        status = self.status()
        for peer in tuple(self.adapter.server.connections):
            if 'telegram' in peer.features:
                await peer.send({**status, **({'ref': ref} if peer is conn and ref is not None else {})})

    async def command(self, frame, conn):
        kind, ref = frame['type'], frame['id']
        if 'telegram' not in conn.features:
            await self.adapter.server.error('unexpected_frame', ref, conn)
            return
        if kind == 'telegram':
            await conn.send(self.status(ref))
            return
        if kind == 'telegram_pair':
            if not platform_ready():
                await self.adapter.server.error('telegram_unavailable', ref, conn)
                return
            code = secrets.token_urlsafe(9)
            with self.vault.locked():
                value = self.private()
                value['code'] = {'hash': digest(code), 'expires': self.clock() + PAIR_TTL, 'used': False}
                self.vault.write('telegram.json', value)
            await conn.send({'v': 1, 'type': 'telegram_code', 'ref': ref, 'code': code, 'expires_in': PAIR_TTL})
            return
        if kind == 'telegram_unpair':
            with self.vault.locked():
                self.vault.write('telegram.json', {'pair': None, 'code': None})
            settings = {'enabled': False}
        else:
            settings = {'enabled': frame['enabled']}
            if settings['enabled'] and not self.private()['pair']:
                await self.adapter.server.error('telegram_unpaired', ref, conn)
                return
        with self.settings_store.locked():
            self.settings_store.write('settings.json', settings)
        await self.publish(conn, ref)

    def pending_code(self, event, private):
        code = private.get('code')
        return bool(code and not code['used'] and self.clock() < code['expires']
                    and hmac.compare_digest(code['hash'], digest(event.text.strip())))

    def claims_external(self, event):
        source = event.source
        if (not self.adapter.is_connected or not platform_ready() or source is None
                or getattr(source.platform, 'value', source.platform) != 'telegram'
                or source.chat_type not in {'group', 'forum'}):
            return False
        private = self._private()
        if private is None or self._settings() is None:
            return False
        code = private['code']
        if code and hmac.compare_digest(code['hash'], digest(event.text.strip())):
            return bool(self.pending_code(event, private)
                        and getattr(getattr(event.raw_message, 'chat', None), 'is_forum', False)
                        and _telegram._is_sender_authorized(source.user_id, source.chat_type, source.chat_id) is not False)
        pair = private['pair']
        return bool(self.active() and pair['chat_id'] == source.chat_id and pair['user_id'] == source.user_id)

    async def notice(self, event, text):
        try:
            result = await _telegram.send(event.source.chat_id, text, metadata={'thread_id': event.source.thread_id})
            if not result.success:
                log.warning('telegram_notice_failed')
        except Exception as exc:
            log.warning('telegram_notice_failed kind=%s', type(exc).__name__)

    async def receive_external(self, event):
        with self.vault.locked():
            private = self.private()
            pairing = self.pending_code(event, private)
            if pairing:
                private['pair'] = {'platform': 'telegram', 'chat_id': event.source.chat_id,
                                   'user_id': event.source.user_id, 'tag': secrets.token_hex(4), 'paired_at': self.clock()}
                private['code']['used'] = True
                self.vault.write('telegram.json', private)
        if pairing:
            await self.notice(event, '연결됐어요')
            await self.publish()

    def recorded(self, row):
        pass

    def wake(self, key):
        pass

    def send_typing(self, key):
        pass

    async def close(self):
        pass
