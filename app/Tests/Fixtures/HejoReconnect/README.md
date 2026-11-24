# HEJO-RECONNECT baseline

`expected.json` is the final observation from the unmodified product at the commit in
`baseline.json`. It was frozen before changing either product file. Never regenerate
it from the changed implementation. The cache hash covers the actual JSONL bytes;
message IDs, order, text, state, read/bell/question values, drafts, selection and
send/error outcomes are observed without random failure IDs or state timestamps.

`HejoReconnectTests.swift` constructs the fixed common workload and preservation
sequence. `HejoReconnectBoundaryTests.swift` covers notification boundaries and
unpause; its synthetic cases also run in the ordinary app suite. The Python runner
uses an isolated home, actual AppKit views and a loopback fake server. Its only
socket instrumentation is an untracked copy of GateClient's receive loop that takes
a timestamp before `receive` and reports its return. It neither replaces receive nor
changes frame delivery, storage, model work or rendering. The same instrumentation
is used for baseline and comparison.

Run `python app/Tests/hejo_reconnect.py check` with the project's test dependencies
and cached Sparkle framework. Preserve `.build/hejo-reconnect-evidence/baseline/`
from the baseline run: `check` compares its input hash and measured median, as well
as this frozen observation and the older HEJO-PERF expected fixture. Output folders
are exclusive to prevent accidental replacement of evidence. `baseline` is a
one-time command requiring the exact base commit, unchanged product sources and no
existing frozen fixture; `HEJO_RECONNECT_BASELINE` excludes boundary tests requiring
the new API when building those original sources. No installed app or server is used.
