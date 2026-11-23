"""Probe lifecycle tests: timeout must reap the child and remain a failure."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("hejo_perf", Path(__file__).with_name("hejo_perf.py"))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class ProbeLifecycleTests(unittest.TestCase):
    def run_child(self, code, timeout=5):
        with tempfile.TemporaryFile() as log:
            return runner.run_probe([sys.executable, "-c", code], os.environ.copy(), log, timeout)

    def test_success(self):
        self.assertEqual(self.run_child("pass"), (0, False))

    def test_failure(self):
        self.assertEqual(self.run_child("raise SystemExit(7)"), (7, False))

    def test_timeout_reaps_child(self):
        code, timed_out = self.run_child("import time; time.sleep(60)", 0.1)
        self.assertTrue(timed_out)
        self.assertLess(code, 0)


if __name__ == "__main__":
    unittest.main()
