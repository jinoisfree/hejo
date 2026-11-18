import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get('HEJO_TEST_APP', ROOT / '.build/hejo.app'))
SCRIPT = Path(os.environ.get('HEJO_HOOK_SCRIPT', ROOT / 'scripts/configure_hooks.py'))
spec = importlib.util.spec_from_file_location('hook_setup', SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class HookTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='hejo-hooks-')
        self.home = Path(self.temporary.name)
        self.support = self.home / 'support'
        self.executable = APP / 'Contents/MacOS/hejo'
        self.setup = module.HookSetup(self.home, self.support, self.executable)
        self.addCleanup(self.temporary.cleanup)

    def test_hook_metadata_only_silent_bounded_and_malformed(self):
        event_root = self.home / 'events'
        payload = dict(session_id='../../escape', hook_event_name='PermissionRequest',
                       cwd=str(self.home / 'project'), tool_input={'command': 'PRIVATE_SECRET'})
        result = subprocess.run([str(self.executable), '--hook', 'claude', '--event-root', str(event_root)],
                                input=json.dumps(payload), text=True, capture_output=True, timeout=3)
        self.assertEqual((result.returncode, result.stdout, result.stderr), (0, '', ''))
        files = list(event_root.glob('*.json'))
        self.assertEqual(len(files), 1)
        data = files[0].read_text()
        self.assertNotIn('PRIVATE_SECRET', data)
        self.assertNotIn(str(self.home), data)
        self.assertEqual(json.loads(data)['state'], 'waiting')
        self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)
        for args in [['--hook', 'codex'], ['--hook', 'invalid'], ['--hook']]:
            result = subprocess.run([str(self.executable), *args], input='{broken', text=True, capture_output=True, timeout=3)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, '', ''))
        self.assertEqual(set(p.name for p in self.home.iterdir()), {'events'})

    def test_official_events_match_source_contract(self):
        codex = module.config('codex', self.executable)['hooks']
        claude = module.config('claude', self.executable)['hooks']
        self.assertEqual(set(codex), {'UserPromptSubmit', 'PermissionRequest', 'PostToolUse', 'Stop', 'SessionEnd', 'Interrupt'})
        self.assertEqual(set(claude), {'UserPromptSubmit', 'PermissionRequest', 'PostToolUse', 'Stop', 'SessionEnd', 'Notification', 'StopFailure'})
        self.assertEqual(claude['Notification'][0]['matcher'], 'permission_prompt|idle_prompt')
        for events in [codex, claude]:
            for groups in events.values():
                self.assertEqual(groups[0]['hooks'][0]['timeout'], 2)
                self.assertEqual(groups[0]['hooks'][0]['type'], 'command')

    def test_preview_no_configuration_access_or_write(self):
        # Even an invalid fake configuration is not read by preview.
        target = self.home / '.claude/settings.json'
        target.parent.mkdir(); target.write_bytes(b'not-json')
        result = subprocess.run(['python3', str(SCRIPT), '--home', str(self.home), '--app', str(APP)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn('create_only', result.stdout)
        self.assertEqual(target.read_bytes(), b'not-json')
        self.assertFalse(self.support.exists())

    def test_connect_backup_receipt_idempotent_disconnect_exact_bytes(self):
        target = self.home / '.claude/settings.json'
        target.parent.mkdir()
        original = (' \n'+json.dumps(module.config('claude', self.executable), indent=3)+'\n\n').encode()
        target.write_bytes(original); target.chmod(0o640)
        self.setup.connect()
        receipt = json.loads(self.setup.receipt.read_bytes())
        self.assertEqual(receipt['phase'], 'connected')
        self.assertEqual((self.support / 'hooks-backup/claude').read_bytes(), original)
        self.assertEqual(self.setup.receipt.stat().st_mode & 0o777, 0o600)
        self.setup.connect()
        self.assertEqual(target.read_bytes(), original)
        self.setup.disconnect()
        self.assertEqual(target.read_bytes(), original)
        self.assertEqual(target.stat().st_mode & 0o777, 0o640)
        self.assertFalse((self.home / '.codex/hooks.json').exists())
        self.assertFalse(self.setup.receipt.exists())

    def test_known_conflict_no_partial_configuration(self):
        target = self.home / '.claude/settings.json'
        target.parent.mkdir(); original = b'{"model":"existing"}\n'; target.write_bytes(original)
        with self.assertRaises(ValueError):
            self.setup.connect()
        self.assertEqual(target.read_bytes(), original)
        self.assertFalse((self.home / '.codex/hooks.json').exists())
        self.assertFalse(self.setup.receipt.exists())

    def test_midway_failure_rolls_back_and_receipt_precedes_config(self):
        actual_link = os.link
        calls = []
        def fail_second(source, destination):
            self.assertTrue(self.setup.receipt.exists())
            receipt = json.loads(self.setup.receipt.read_bytes())
            self.assertEqual(receipt['phase'], 'connecting')
            calls.append(destination)
            if len(calls) == 2:
                raise OSError('synthetic write failure')
            actual_link(source, destination)
        with patch.object(module.os, 'link', side_effect=fail_second):
            with self.assertRaises(OSError):
                self.setup.connect()
        self.assertEqual(len(calls), 2)
        self.assertFalse((self.home / '.codex/hooks.json').exists(), 'AT98 midway rollback removes first setting')
        self.assertFalse((self.home / '.claude/settings.json').exists())
        self.assertFalse(self.setup.receipt.exists())

    def test_receipt_completion_failure_restores_existing_bytes(self):
        target = self.home / '.claude/settings.json'
        target.parent.mkdir()
        original = (json.dumps(module.config('claude', self.executable), indent=4)+'\n\n').encode()
        target.write_bytes(original)
        actual_write = module.write_atomic
        def fail_completion(path, data, mode=0o600):
            if path == self.setup.receipt and json.loads(data).get('phase') == 'connected':
                raise OSError('synthetic completion failure')
            actual_write(path, data, mode)
        with patch.object(module, 'write_atomic', side_effect=fail_completion):
            with self.assertRaises(OSError):
                self.setup.connect()
        self.assertEqual(target.read_bytes(), original)
        self.assertFalse((self.home / '.codex/hooks.json').exists())
        self.assertFalse(self.setup.receipt.exists())

    def test_disconnect_preserves_a_later_user_edit_and_receipt(self):
        self.setup.connect()
        target = self.home / '.claude/settings.json'
        changed = b'{"changed":true}\n'; target.write_bytes(changed)
        with self.assertRaises(ValueError):
            self.setup.disconnect()
        self.assertEqual(target.read_bytes(), changed)
        self.assertTrue(self.setup.receipt.exists())
        self.assertTrue((self.home / '.codex/hooks.json').exists())

    def test_symlink_refused(self):
        target = self.home / '.claude/settings.json'
        target.parent.mkdir(); other = self.home / 'other'; other.write_bytes(b'{}')
        target.symlink_to(other)
        with self.assertRaises(ValueError):
            self.setup.connect()
        self.assertEqual(other.read_bytes(), b'{}')
        self.assertFalse((self.home / '.codex/hooks.json').exists())


if __name__ == '__main__':
    unittest.main()
