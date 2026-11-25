#!/bin/bash
# Separate small contract probes; never replace the frozen baseline executable.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${HEJO_HISTORY_SPARKLE:?existing Sparkle framework required}"
mode="${1:-current}"
probe_sources=()
if [[ "$mode" == reference ]]; then
  reference=.build/history-contract-reference-sources
  mkdir -p "$reference"
  python3 - "$reference" <<'PY'
import pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1])
commit='8b873b974d3b4d6df3044f78116b3b4ec79d675f'
for name in subprocess.check_output(['git','ls-tree','-r','--name-only',commit,'app/Sources'],text=True).splitlines():
    if name.endswith('.swift') and not name.endswith('/AppMain.swift'):
        (root/pathlib.Path(name).name).write_bytes(subprocess.check_output(['git','show',commit+':'+name]))
PY
  probe_sources=("$reference"/*.swift)
  flags=(-D HEJO_HISTORY_CONTRACT_PROBE -D HEJO_FROZEN_REFERENCE)
else
  for source in app/Sources/*.swift; do
    [[ "$source" == app/Sources/AppMain.swift ]] || probe_sources+=("$source")
  done
  flags=(-D HEJO_HISTORY_CONTRACT_PROBE)
fi
xcrun swiftc -swift-version 5 -parse-as-library "${flags[@]}" \
  -target "$(uname -m)-apple-macosx13.0" "${probe_sources[@]}" app/Tests/HistoryContractProbe.swift \
  -o "app/.build/history-contract-$mode" -framework AppKit -framework EventKit -framework WebKit \
  -framework Accelerate -framework ServiceManagement -F "$HEJO_HISTORY_SPARKLE" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$HEJO_HISTORY_SPARKLE"
