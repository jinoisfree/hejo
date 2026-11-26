#!/bin/bash
# Use the built AppKit test executable with an isolated real gate and two WS clients.
set -euo pipefail
cd "$(dirname "$0")/../.."
export HEJO_OWNER_PROFILE_APP_TESTS="${HEJO_OWNER_PROFILE_APP_TESTS:-app/.build/app-tests}"
"${HEJO_PYTHON:-python3}" -m pytest gate/tests/owner_profile_transport_app.py -q -s \
    -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
