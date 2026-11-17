#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
identity="${HEJO_SIGNING_IDENTITY:-AIpet Local Development}"
if ! security find-identity -v -p codesigning | /usr/bin/grep -Fq "\"$identity\""; then
  printf '%s\n' '서명 인증서가 없습니다. HEJO_SIGNING_IDENTITY를 확인하세요.' >&2
  exit 1
fi
bundle=.build/hejo.app
bash scripts/fetch_sparkle.sh
sparkle=.build/sparkle-2.10.0
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/Pet" "$bundle/Contents/Frameworks"
iconset=.build/AppIcon.iconset
rm -rf "$iconset"
xcrun swiftc -swift-version 5 -parse-as-library -O -target "$(uname -m)-apple-macosx13.0" \
  Sources/AppIcon.swift Tools/IconMain.swift -o .build/icon-generator -framework AppKit
.build/icon-generator "$iconset"
iconutil -c icns "$iconset" -o .build/AppIcon.icns
cp .build/AppIcon.icns "$bundle/Contents/Resources/AppIcon.icns"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
python3 ../scripts/build_info.py "$bundle/Contents/Resources/BuildInfo.json"
# hejo's shared Google desktop client: public id in config/google-oauth.json, secret from an untracked file or env.
google_id=$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("client_id",""))' ../config/google-oauth.json)
google_secret=""
if [[ "${HEJO_SKIP_GOOGLE_SECRET:-0}" != 1 ]]; then
  google_secret="${HEJO_GOOGLE_CLIENT_SECRET:-}"
  if [[ -z "$google_secret" && -f ../config/google-oauth-secret.json ]]; then
    google_secret=$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("client_secret",""))' ../config/google-oauth-secret.json)
  fi
fi
if [[ -n "$google_id" && -n "$google_secret" ]]; then
  /usr/libexec/PlistBuddy -c "Add :HejoGoogleClientID string $google_id" -c "Add :HejoGoogleClientSecret string $google_secret" "$bundle/Contents/Info.plist"
fi
cp Resources/Pet/*.png Resources/Pet/LICENSE "$bundle/Contents/Resources/Pet/"
sips -s format png Resources/Pet/spritesheet.webp --out "$bundle/Contents/Resources/Pet/spritesheet.png" >/dev/null
xcrun swiftc -swift-version 5 -parse-as-library -O -target "$(uname -m)-apple-macosx13.0" \
  Sources/*.swift -o "$bundle/Contents/MacOS/hejo" \
  -framework AppKit -framework Accelerate -framework ServiceManagement \
  -F "$sparkle" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
rm -rf "$bundle/Contents/Frameworks/Sparkle.framework"
ditto "$sparkle/Sparkle.framework" "$bundle/Contents/Frameworks/Sparkle.framework"
cp "$sparkle/LICENSE" "$bundle/Contents/Resources/Sparkle-LICENSE.txt"
framework="$bundle/Contents/Frameworks/Sparkle.framework/Versions/B"
for nested in XPCServices/Downloader.xpc XPCServices/Installer.xpc Autoupdate Updater.app; do
  codesign --force --sign "$identity" --timestamp=none "$framework/$nested"
done
codesign --force --sign "$identity" --timestamp=none "$bundle/Contents/Frameworks/Sparkle.framework"
codesign --force --sign "$identity" --identifier io.github.hermes-hejo.hejo --timestamp=none "$bundle"
codesign --verify --deep --strict "$bundle"
printf '%s\n' 'BUILD_OK app/.build/hejo.app'
