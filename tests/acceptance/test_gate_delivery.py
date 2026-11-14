"""AT-HF-22 uses the production plugin and real gateway lifecycle in a subprocess."""
import asyncio
import os
from pathlib import Path
import sys
import pytest


@pytest.mark.asyncio
async def test_at_hf_22(tmp_path):
    env = {**os.environ, "HERMES_DISABLE_LAZY_INSTALLS": "1", "PYTHONDONTWRITEBYTECODE": "1"}
    # Keep Unix socket paths short without disabling Hermes' production-DB guard.
    env.setdefault("HEJO_GATE_TEST_TMPDIR", str(Path(os.devnull).parent.parent / "tmp"))
    process = await asyncio.create_subprocess_exec(sys.executable, "-m", "gate.tests.gateway_delivery",
        env=env, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
    output, _ = await asyncio.wait_for(process.communicate(), 180)
    (tmp_path / "gateway.log").write_bytes(output)
    assert process.returncode == 0, output.decode()
    assert b'"acceptance": "AT-HF-22"' in output
    assert b'GATEWAY_EXIT clean' in output
