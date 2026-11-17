#!/bin/bash
# Pin the archive as well as its version. Tests never download dependencies.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=2.10.0
SHA256=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
DEST="$ROOT/.build/sparkle-$VERSION"
ARCHIVE="$ROOT/.build/Sparkle-$VERSION.tar.xz"
if [[ -f "$DEST/.verified-$SHA256" ]]; then exit 0; fi
mkdir -p "$ROOT/.build"
STAGING=$(mktemp -d "$ROOT/.build/sparkle-download.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
if [[ ! -f "$ARCHIVE" ]]; then
    if [[ "${HEJO_SPARKLE_OFFLINE:-0}" == 1 ]]; then
        echo 'Sparkle가 없습니다. 먼저 bash app/scripts/fetch_sparkle.sh로 고정 의존성을 준비하세요.' >&2
        exit 1
    fi
    curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
        --connect-timeout 10 --max-time 120 --retry 2 \
        "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" -o "$STAGING/archive.tar.xz"
    mv "$STAGING/archive.tar.xz" "$ARCHIVE"
fi
ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
[[ "$ACTUAL" == "$SHA256" ]] || { echo 'Sparkle 다운로드 지문이 일치하지 않습니다.' >&2; exit 1; }
mkdir "$STAGING/unpacked"
tar -xJf "$ARCHIVE" -C "$STAGING/unpacked"
codesign --verify --deep --strict "$STAGING/unpacked/Sparkle.framework"
touch "$STAGING/unpacked/.verified-$SHA256"
rm -rf "$DEST"
mv "$STAGING/unpacked" "$DEST"
