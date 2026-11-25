#!/bin/bash
# Build the isolated real HTTP/WS client check, not the installed app.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${HEJO_HISTORY_SPARKLE:?existing Sparkle framework directory required}"
sources=()
for source in app/Sources/*.swift; do
  [[ "$source" == app/Sources/AppMain.swift ]] || sources+=("$source")
done
output=app/.build/history-transport-tests
flags=(-D HEJO_HISTORY_TRANSPORT_TEST)
if [[ "${1:-}" == --legacy ]]; then
  output=app/.build/history-legacy-tests
  flags+=(-D HEJO_LEGACY_REFERENCE)
fi
xcrun swiftc -swift-version 5 -parse-as-library "${flags[@]}" \
  -target "$(uname -m)-apple-macosx13.0" "${sources[@]}" app/Tests/History*Harness.swift \
  -o "$output" -framework AppKit -framework EventKit -framework WebKit \
  -framework Accelerate -framework ServiceManagement -F "$HEJO_HISTORY_SPARKLE" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$HEJO_HISTORY_SPARKLE"
