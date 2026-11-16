#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
HEJO_SKIP_GOOGLE_SECRET=1 bash scripts/build.sh
sources=()
for source in Sources/*.swift; do
  [[ "$source" == Sources/AppMain.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -parse-as-library -g -target "$(uname -m)-apple-macosx13.0" \
  "${sources[@]}" Tests/*.swift -o .build/app-tests \
  -framework AppKit -framework Accelerate -framework ServiceManagement
codesign --force --sign "${HEJO_SIGNING_IDENTITY:-AIpet Local Development}" --timestamp=none .build/app-tests
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' .build/hejo.app/Contents/Info.plist)" == io.github.hermes-hejo.hejo ]]
codesign --verify --strict .build/hejo.app
printf '%s\n' 'AT-HF-23 PASS'
.build/app-tests "$PWD/.build/hejo.app/Contents/Resources/Pet"
"${HEJO_PYTHON:-python3}" Tests/network_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/conversation_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/pictures_fixture.py .build/app-tests
"${HEJO_PYTHON:-python3}" Tests/thread_fixture.py .build/app-tests
