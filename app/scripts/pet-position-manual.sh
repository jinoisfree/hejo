#!/bin/bash
# Run from either the archived baseline or the implementation checkout.
set -euo pipefail
cd "$(dirname "$0")/.."
pet_probe_root=$(mktemp -d "${TMPDIR:-/tmp}/hejo-pet-probe.XXXXXX")
mkdir -p "$pet_probe_root/hermes" "$pet_probe_root/local" "$pet_probe_root/evidence"
probe_python="${HEJO_PYTHON:-python3}"
settings_ready=0
downloads_ready=0
finish() {
    result=$?
    if [[ "$settings_ready" == 1 ]]; then "$probe_python" Tests/settings_guard.py verify "$pet_probe_root/settings-before.json" || result=1; fi
    if [[ "$downloads_ready" == 1 ]]; then "$probe_python" Tests/downloads_guard.py verify "$pet_probe_root/downloads-before.json" || result=1; fi
    rm -f "$pet_probe_root/settings-before.json" "$pet_probe_root/downloads-before.json"
    echo "Probe evidence retained in temporary root: $pet_probe_root"
    exit "$result"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
"$probe_python" Tests/settings_guard.py snapshot "$pet_probe_root/settings-before.json"
settings_ready=1
"$probe_python" Tests/downloads_guard.py snapshot "$pet_probe_root/downloads-before.json"
downloads_ready=1
env -u HEJO_THREE_TAP_TRACE HERMES_HOME="$pet_probe_root/hermes" HERMES_ROOT="$pet_probe_root/hermes" \
.build/app-tests --pet-position-manual --probe-root "$pet_probe_root" --local-store "$pet_probe_root/local" --evidence "$pet_probe_root/evidence" "$@" "$PWD/.build/hejo.app/Contents/Resources/Pet"
