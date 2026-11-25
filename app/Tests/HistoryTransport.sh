#!/bin/bash
# Build the isolated real HTTP/WS client check, not the installed app.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${HEJO_HISTORY_SPARKLE:?existing Sparkle framework directory required}"
sources=()
for source in app/Sources/*.swift; do
  [[ "$source" == app/Sources/AppMain.swift ]] || sources+=("$source")
done
xcrun swiftc -swift-version 5 -parse-as-library -D HEJO_HISTORY_TRANSPORT_TEST \
  -target "$(uname -m)-apple-macosx13.0" "${sources[@]}" app/Tests/HistoryTransportHarness.swift \
  -o app/.build/history-transport-tests -framework AppKit -framework EventKit -framework WebKit \
  -framework Accelerate -framework ServiceManagement -F "$HEJO_HISTORY_SPARKLE" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$HEJO_HISTORY_SPARKLE"
