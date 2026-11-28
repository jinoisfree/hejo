#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export PYTHONDONTWRITEBYTECODE=1
export HERMES_DISABLE_LAZY_INSTALLS=1
"${HEJO_PYTHON:-python3}" -m pytest gate/tests tests/acceptance -q \
  -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
"${HEJO_PYTHON:-python3}" -m gate.tests.gateway_delivery
bash app/scripts/test.sh

HEJO_BUTTON_SNAP="$PWD/.build/buttons/snap" "${HEJO_PYTHON:-python3}" app/Tests/result_done_fixture.py app/.build/app-tests buttons
