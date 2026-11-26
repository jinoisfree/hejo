#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
settings_snapshot=$(mktemp)
"${HEJO_PYTHON:-python3}" Tests/settings_guard.py snapshot "$settings_snapshot"
downloads_snapshot=$(mktemp)
"${HEJO_PYTHON:-python3}" Tests/downloads_guard.py snapshot "$downloads_snapshot"
trap 'result=$?; "${HEJO_PYTHON:-python3}" Tests/settings_guard.py verify "$settings_snapshot" || result=1; rm -f "$settings_snapshot"; "${HEJO_PYTHON:-python3}" Tests/downloads_guard.py verify "$downloads_snapshot" || result=1; rm -f "$downloads_snapshot"; exit "$result"' EXIT
HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash scripts/build.sh
sources=()
for source in Sources/*.swift; do
  [[ "$source" == Sources/AppMain.swift ]] || sources+=("$source")
done
xcrun swiftc -D HEJO_LEGACY_REFERENCE -D HEJO_PERF_TESTING -swift-version 5 -parse-as-library -g -target "$(uname -m)-apple-macosx13.0" \
  "${sources[@]}" Tests/*.swift -o .build/app-tests \
  -framework AppKit -framework EventKit -framework WebKit -framework Accelerate -framework ServiceManagement \
  -F .build/sparkle-2.10.0 -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/hejo.app/Contents/Frameworks
codesign --force --sign "${HEJO_SIGNING_IDENTITY:-AIpet Local Development}" --timestamp=none .build/app-tests
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' .build/hejo.app/Contents/Info.plist)" == io.github.hermes-hejo.hejo ]]
codesign --verify --strict .build/hejo.app
printf '%s\n' 'AT-HF-23 PASS'
.build/app-tests "$PWD/.build/hejo.app/Contents/Resources/Pet"
"${HEJO_PYTHON:-python3}" Tests/network_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/conversation_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/pictures_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/thread_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/card_done_fixture.py .build/app-tests "${HEJO_CARD_DONE_EVIDENCE:-.build/card-done-evidence}"

"${HEJO_PYTHON:-python3}" Tests/workspace_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/bubble_reply_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/home_room_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/rooms_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/composer_target_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/downloads_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/web_pane_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/review55_fixture.py .build/app-tests

"${HEJO_PYTHON:-python3}" Tests/test_hooks.py

bash Tests/OwnerProfileTransport.sh
(
  cd ..
  export HEJO_CARD_ALERT_BINARY=app/.build/app-tests
  "${HEJO_PYTHON:-python3}" -m pytest app/Tests/test_card_alert_transport.py -q -s \
    -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
)

wait_jitter_output="$PWD/.build/wait-jitter-tests"
mkdir -p "$wait_jitter_output"
wait_jitter_trace="$wait_jitter_output/trace.jsonl"
rm -f "$wait_jitter_trace"
HEJO_THREE_TAP_TRACE="$wait_jitter_trace" .build/app-tests --wait-jitter "$wait_jitter_output/enabled" Tests/WaitJitterTargets.json
"${HEJO_PYTHON:-python3}" Tests/wait_jitter_trace.py "$wait_jitter_trace" --harness
"${HEJO_PYTHON:-python3}" Tests/wait_jitter_trace_test.py
wait_jitter_trace_hash="$(shasum -a 256 "$wait_jitter_trace")"
env -u HEJO_THREE_TAP_TRACE .build/app-tests --wait-jitter "$wait_jitter_output/disabled" Tests/WaitJitterTargets.json --trace-subset
[[ "$(shasum -a 256 "$wait_jitter_trace")" == "$wait_jitter_trace_hash" ]]
