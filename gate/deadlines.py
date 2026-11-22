"""team-kit boundary: a shared read-only list and the owner's serialized close."""
import asyncio
from datetime import date, datetime
import json
import logging
import os
from pathlib import Path
import re
from hermes_constants import PROFILE_ID_RE
from urllib.parse import urlsplit

from .connection_runtime import ActionJournal

log = logging.getLogger(__name__)
MAX_OUTPUT = 512 * 1024
PROFILE = PROFILE_ID_RE
# team-kit ledger key; the prefix is also the origin kind shown to the owner.
DEADLINE_ID = re.compile(r'(notion|calendar|reminder|slack|notes|gmail):\S{1,240}')
OUTCOMES = {'done', 'cancel'}
CLOSE_WAIT = 20  # seconds a close may wait for the one before it; expiry means "not executed"
CLOSE_RUN = 40   # seconds the close command may run once it has its turn (wait + run = 60)


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
            origin = DEADLINE_ID.match(record['id'])
            if origin:
                item['origin'] = origin.group(1)
            if 'notice' in record:
                notice = record['notice']
                if (not isinstance(notice, dict) or set(notice) != {'message_id', 'thread'}
                        or not all(isinstance(v, str) and 1 <= len(v) <= 200 for v in notice.values())):
                    raise ValueError('invalid_response')
                item['notice'] = dict(notice)
            if 'deadline_at' in record:
                if not isinstance(record['deadline_at'], str) or 'T' not in record['deadline_at']:
                    raise ValueError('invalid_response')
                datetime.fromisoformat(record['deadline_at'])
                item['deadline_at'] = record['deadline_at']
            try:
                source = urlsplit(record['source'])
            except ValueError:
                source = None  # An ordinary source string need not be a valid URL.
            if source is not None and source.scheme in {'http', 'https'} and source.hostname:
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
    def __init__(self, home, *, timeout=10, close_wait=CLOSE_WAIT, close_timeout=CLOSE_RUN):
        self.home = Path(home)
        self.executable = self.home / 'bin/hermes-deadlines'
        self.timeout = timeout
        self.close_wait = close_wait
        self.close_timeout = close_timeout
        # Reads in flight by the close generation they started in; only same-generation requests share one.
        self._reads = {}
        self._closing = set()
        self._close_lock = asyncio.Lock()
        self.close_generation = 0
        self.journal = ActionJournal(self.home)
        self._stopped = False

    @property
    def available(self):
        return self.executable.is_file() and os.access(self.executable, os.X_OK)

    @property
    def _running(self):
        return self._reads.get(self.close_generation)

    async def list(self):
        if self._stopped: raise asyncio.CancelledError
        generation = self.close_generation
        task = self._reads.get(generation)
        if task is None:
            task = self._reads[generation] = asyncio.create_task(self._execute(generation))
        return await asyncio.shield(task)

    async def stop(self):
        self._stopped = True
        tasks = [*self._reads.values(), *self._closing]
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

    async def close(self, device, employee, deadline, outcome, employees):
        """Close one deadline for the owner. The command runs to its end even if the caller goes away."""
        if (not isinstance(employee, str) or not PROFILE.fullmatch(employee) or employee not in employees
                or not isinstance(deadline, str) or not DEADLINE_ID.fullmatch(deadline) or outcome not in OUTCOMES):
            return {'ok': False, 'reason': 'invalid_request'}
        if self._stopped: raise asyncio.CancelledError
        task = asyncio.create_task(self._close(device, employee, deadline, outcome))
        self._closing.add(task)
        task.add_done_callback(self._closing.discard)
        return await asyncio.shield(task)

    async def _close(self, device, employee, deadline, outcome):
        recorded = result = None
        try:
            if not self.available:
                recorded, result = 'unavailable', {'ok': False, 'reason': 'unavailable'}
            else:
                try:
                    async with asyncio.timeout(self.close_wait):
                        await self._close_lock.acquire()
                except TimeoutError:
                    recorded, result = 'busy', {'ok': False, 'reason': 'busy'}
                else:
                    try:
                        result = await self._run_close(employee, deadline, outcome)
                    finally:
                        # The ledger may have changed even if the command failed or timed out:
                        # reads that began before this point must not answer later requests.
                        self.close_generation += 1
                        self._close_lock.release()
                    recorded = ('already_closed' if result.get('already_closed') else outcome) if result['ok'] else result['reason']
            return result
        finally:
            if recorded is not None:
                self._record(device, employee, deadline, outcome, recorded, result)

    def _record(self, device, employee, deadline, outcome, recorded, result):
        try:
            self.journal.append(device=device, profile=employee, connection='deadline:' + outcome,
                                action='deadline_close', outcome=recorded, deadline=deadline)
        except OSError:
            log.warning('deadline_close journal_failed')
        log.info('deadline_close outcome=%s ok=%d repainted=%d', recorded, result['ok'],
                 bool(result.get('repainted')))

    async def _run_close(self, employee, deadline, outcome):
        try:
            code, output = await self._capture('close', '--profile', employee, '--id', deadline,
                                               '--outcome', outcome, '--json', timeout=self.close_timeout)
            try:
                document = json.loads(output)
            except ValueError:
                document = None
            if code == 0:
                if (isinstance(document, dict) and set(document) == {'ok', 'already_closed', 'repainted'}
                        and document['ok'] is True and type(document['already_closed']) is bool
                        and type(document['repainted']) is bool):
                    return {'ok': True, 'already_closed': document['already_closed'], 'repainted': document['repainted']}
                raise DeadlineFailure('invalid_response')
            if code == 1 and document == {'error': 'UNKNOWN_DEADLINE'}:
                raise DeadlineFailure('unknown_deadline')
            raise DeadlineFailure('command_failed')
        except (DeadlineFailure, OSError, TimeoutError) as exc:
            return {'ok': False, 'reason': str(exc) if isinstance(exc, DeadlineFailure) else 'command_failed'}

    async def _capture(self, *arguments, timeout):
        """Run the command with the shared child-process rules: no stdin, bounded output, always reaped."""
        proc = None
        try:
            async with asyncio.timeout(timeout):
                spawning = asyncio.create_task(asyncio.create_subprocess_exec(
                    str(self.executable), *arguments, stdin=asyncio.subprocess.DEVNULL,
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
            return proc.returncode, bytes(output)
        finally:
            if proc is not None:
                cleanup = asyncio.create_task(self._reap(proc))
                try: await asyncio.shield(cleanup)
                except asyncio.CancelledError:
                    await cleanup
                    raise

    async def _execute(self, generation):
        try:
            if not self.available:
                return {'available': False, 'items': []}
            code, output = await self._capture('list', '--json', timeout=self.timeout)
            if code: raise DeadlineFailure('command_failed')
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
            if self._reads.get(generation) is asyncio.current_task():
                del self._reads[generation]

    @staticmethod
    async def _reap(proc):
        # Drain the pipe as well as wait: a full stdout pipe otherwise prevents
        # asyncio's subprocess transport from completing even after kill.
        async def drain_and_wait():
            while await proc.stdout.read(65536):
                pass
            await proc.wait()
        if proc.returncode is None:
            try: proc.terminate()
            except ProcessLookupError: pass
        try: await asyncio.wait_for(drain_and_wait(), .2)
        except TimeoutError:
            try: proc.kill()
            except ProcessLookupError: pass
            await drain_and_wait()
