#!/bin/bash
# Build only. Python orchestration owns isolated execution and the global timeout gate.
set -euo pipefail
cd "$(dirname "$0")/../.."
if [[ ${1:-} == --help ]]; then
  echo 'HEJO_HISTORY_SPARKLE=<existing framework directory> bash app/Tests/HistoryBaseline.sh'
  echo 'Then: "$HEJO_PYTHON" -m gate.tests.history_baseline --binary app/.build/history-baseline --output <evidence directory>'
  exit 0
fi
: "${HEJO_HISTORY_SPARKLE:?existing Sparkle framework directory required}"
mkdir -p app/.build
sources=()
for source in app/Sources/*.swift; do
  [[ "$source" == app/Sources/AppMain.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -parse-as-library -O -whole-module-optimization -target "$(uname -m)-apple-macosx13.0" \
  -D HEJO_HISTORY_BASELINE "${sources[@]}" app/Tests/HistoryBaseline.swift app/Tests/HistoryBaselineSemantics.swift app/Tests/WorkspaceSearchReference.swift \
  -o app/.build/history-baseline -framework AppKit -framework EventKit -framework WebKit \
  -framework Accelerate -framework ServiceManagement -F "$HEJO_HISTORY_SPARKLE" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$HEJO_HISTORY_SPARKLE"
