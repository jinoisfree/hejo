"""Read-only team-kit boundary; one shielded execution belongs to the gate."""
import asyncio
from datetime import date, datetime
import json
import logging
import os
from pathlib import Path
from hermes_constants import PROFILE_ID_RE
from urllib.parse import urlsplit

log = logging.getLogger(__name__)
MAX_OUTPUT = 512 * 1024
PROFILE = PROFILE_ID_RE


class DeadlineFailure(ValueError):
    pass


def public_items(document):
    if (not isinstance(document, dict) or type(document.get('version')) is not int or document['version'] != 1
            or not isinstance(document.get('profiles'), dict) or not isinstance(document.get('failed'), list)):
        raise ValueError('invalid_response')
    def profile(value):
        if not isinstance(value, str) or not PROFILE.fullmatch(value):
            raise ValueError('invalid_response')
        return value
    items = []
    for employee, records in document['profiles'].items():
        profile(employee)
        if not isinstance(records, list): raise ValueError('invalid_response')
        for record in records:
            if not isinstance(record, dict): raise ValueError('invalid_response')
            for key, lower, upper in [('id', 1, 300), ('title', 1, 300), ('source', 0, 1000)]:
                if not isinstance(record.get(key), str) or not lower <= len(record[key]) <= upper:
                    raise ValueError('invalid_response')
            due = record.get('due')
            if not isinstance(due, str) or date.fromisoformat(due).isoformat() != due:
                raise ValueError('invalid_response')
            item = {key: record[key] for key in ('id', 'title', 'due')}
            item['employee'] = employee
            if 'deadline_at' in record:
                if not isinstance(record['deadline_at'], str) or 'T' not in record['deadline_at']:
                    raise ValueError('invalid_response')
                datetime.fromisoformat(record['deadline_at'])
                item['deadline_at'] = record['deadline_at']
            source = urlsplit(record['source'])
            if source.scheme in {'http', 'https'} and source.hostname:
                item['url'] = record['source']
            items.append(item)
    failed = []
    for record in document['failed']:
        if (not isinstance(record, dict) or record.get('reason') not in
                {'deadline_state_corrupt', 'deadline_symlink_refused', 'read_failed'}):
            raise ValueError('invalid_response')
        failed.append(profile(record.get('profile')))
    return {'available': True, 'items': items, 'failed': failed}


class Deadlines:
    def __init__(self, home, *, timeout=10):
        self.home = Path(home)
        self.executable = self.home / 'bin/hermes-deadlines'
        self.timeout = timeout
        self._running = None
        self._stopped = False

    @property
    def available(self):
        return self.executable.is_file() and os.access(self.executable, os.X_OK)

    async def list(self):
        if self._stopped: raise asyncio.CancelledError
        if self._running is None:
            self._running = asyncio.create_task(self._execute())
        return await asyncio.shield(self._running)

    async def stop(self):
        self._stopped = True
        task = self._running
        if task is not None:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)

    async def _execute(self):
        proc = None
        try:
            if not self.available:
                return {'available': False, 'items': []}
            async with asyncio.timeout(self.timeout):
                spawning = asyncio.create_task(asyncio.create_subprocess_exec(
                    str(self.executable), 'list', '--json', stdin=asyncio.subprocess.DEVNULL,
                    stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                    env={**os.environ, 'HERMES_HOME': str(self.home), 'HERMES_DISABLE_LAZY_INSTALLS': '1',
                         'PYTHONDONTWRITEBYTECODE': '1'}))
                try:
                    proc = await asyncio.shield(spawning)
                except asyncio.CancelledError:
                    proc = await spawning
                    raise
                output = bytearray()
                while part := await proc.stdout.read(65536):
                    output.extend(part)
                    if len(output) > MAX_OUTPUT: raise DeadlineFailure('invalid_response')
                await proc.wait()
                if proc.returncode: raise DeadlineFailure('command_failed')
                try:
                    result = public_items(json.loads(output))
                except (ValueError, TypeError, KeyError, OverflowError):
                    raise DeadlineFailure('invalid_response') from None
            log.info('deadlines_read items=%d failed=%d', len(result['items']), len(result['failed']))
            return result
        except (DeadlineFailure, OSError, TimeoutError) as exc:
            reason = str(exc) if isinstance(exc, DeadlineFailure) else 'command_failed'
            log.warning('deadlines_failed reason=%s', reason)
            return {'available': True, 'reason': reason}
        finally:
            try:
                if proc is not None and proc.returncode is None:
                    try: proc.terminate()
                    except ProcessLookupError: pass
                    try: await asyncio.wait_for(proc.wait(), .2)
                    except TimeoutError:
                        try: proc.kill()
                        except ProcessLookupError: pass
                        await proc.wait()
            finally:
                self._running = None
