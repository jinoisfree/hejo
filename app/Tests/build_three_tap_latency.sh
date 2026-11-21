#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if pgrep -f '[a]pp-tests' >/dev/null; then
  printf '%s\n' '다른 앱 시험이 실행 중입니다. 진단 빌드를 중단합니다.' >&2
  exit 2
fi
out=.build/three-tap-diagnostic
mkdir -p "$out"
# Same-file extension access only; the product source is copied verbatim.
cat Sources/AppDelegate.swift Tests/ThreeTapLatencyHarness.swift > "$out/AppDelegate.swift"
sources=()
for source in Sources/*.swift; do
  [[ "$source" == Sources/AppMain.swift || "$source" == Sources/AppDelegate.swift ]] || sources+=("$source")
done
xcrun swiftc -D HEJO_THREE_TAP_DIAGNOSTIC -swift-version 5 -parse-as-library -O \
  -target "$(uname -m)-apple-macosx13.0" "${sources[@]}" "$out/AppDelegate.swift" -o "$out/three-tap-diagnostic" \
  -framework AppKit -framework EventKit -framework WebKit -framework Accelerate -framework ServiceManagement \
  -F .build/sparkle-2.10.0 -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../hejo.app/Contents/Frameworks
codesign --force --sign "${HEJO_SIGNING_IDENTITY:-AIpet Local Development}" --timestamp=none "$out/three-tap-diagnostic"
printf '%s\n' 'THREE_TAP_DIAGNOSTIC_BUILD_OK'
