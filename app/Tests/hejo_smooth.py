#!/usr/bin/env python3
"""Build the existing optimized AppKit harness and preserve smoothness observations."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import statistics
import shutil
import subprocess
import tempfile

# Installed in app/Tests; the existing builder fingerprints every source and option.
import hejo_perf

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "app/.build/hejo-smooth-public"
BASE = "dba49a7ccea4b4212618ecf773e40c4e18f6bb67"

def write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n")

def summarize(output, baseline):
    runs = [r for r in json.loads((output / "performance.json").read_text()) if not r["warm_up"]]
    old = [r for r in json.loads((baseline / "performance.json").read_text()) if not r["warm_up"]]
    summary = {}
    for name in runs[0]["seconds"]:
        samples = [r["seconds"][name] for r in runs]
        assert len(samples) == 5 and all(v >= 0 for v in samples)
        limit = max(r["seconds"][name] for r in old) if name in {"room_first", "room_revisit"} else .050
        summary[name] = {"raw": samples, "median": statistics.median(samples), "max": max(samples),
            "median_limit": limit, "pass": statistics.median(samples) <= limit and (name in {"room_first", "room_revisit"} or max(samples) <= .100)}
    scroll = [v for r in runs for v in r["scroll_seconds"]]
    summary["scroll_observation_only"] = {"samples": len(scroll), "median": statistics.median(scroll), "max": max(scroll), "pass":statistics.median(scroll)<=.0167 and max(scroll)<=.050}
    write(output / "summary.json", summary)
    return summary

def compare(output, baseline):
    assert (output / "workload-frames.json").read_bytes() == (baseline / "workload-frames.json").read_bytes(), "Frozen workload changed"
    if (output / "stream.json").exists():
        left = json.loads((output / "stream.json").read_text())["observations"]
        right = json.loads((baseline / "stream.json").read_text())["observations"]
        assert len(left) == len(right)
        for observed, expected in zip(left, right):
            assert observed["frame"] == expected["frame"] and observed["tick"] == expected["tick"]
            assert observed["text"] == expected["text"], "AT-SM-03 prefix/order mismatch"
            assert abs(observed["y"] - expected["y"]) < 1, "AT-SM-03 follow position mismatch"
    if (output / "transitions.json").exists():
        left = json.loads((output / "transitions.json").read_text())[1:]
        right = json.loads((baseline / "transitions.json").read_text())[1:]
        assert len(left) == len(right) == 5
        for observed, expected in zip(left,right):
            assert observed["placement_pass"] and observed["before_refreshes"]<=1 and observed["during_refreshes"]==0 and observed["during_scroll_starts"]==0, "AT-SM-04/06 placement/overlap failure"
            assert abs(observed["final_y"] - expected["final_y"])<1, "AT-SM-04 final position differs from public baseline"
        assert sum(x["frame_pass"] for x in left)>=sum(x["frame_pass"] for x in right), "AT-SM-06 worsened against public baseline"

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("mode", choices=["baseline", "cache", "check", "derived", "cards", "transitions"])
    p.add_argument("--no-build", action="store_true")
    p.add_argument("--output", type=Path)
    p.add_argument("--source", type=Path, help="Preserved public baseline source with observations only")
    p.add_argument("--probe", type=Path, help="Use an independently preserved compatible build")
    args = p.parse_args()
    output = (args.output or ROOT / args.mode).resolve()
    output.relative_to(ROOT.resolve())
    if output.exists():
        raise RuntimeError("Evidence already exists; preserve it and use another output")
    baseline = ROOT / "baseline-values"
    if args.mode != "baseline":
        assert (baseline / "execution.json").is_file(), "Baseline must be frozen first"
    hejo_perf.EVIDENCE = (args.probe or ROOT / "probe").resolve()
    hejo_perf.EVIDENCE.relative_to(ROOT.resolve())
    hejo_perf.EVIDENCE.mkdir(parents=True, exist_ok=True)
    hejo_perf.REPO=(args.source or REPO).resolve()
    binary = hejo_perf.build(args.no_build)
    output.mkdir(parents=True)
    shutil.copy2(hejo_perf.EVIDENCE / "build.json", output / "build.json")
    shutil.copy2(binary, output / "tested-binary")
    with tempfile.TemporaryDirectory(prefix="hejo-sm-", dir="/tmp") as home:
        env = os.environ | {"HERMES_HOME": home, "TZ": "UTC", "HEJO_THREE_TAP_TRACE": ""}
        command = [str(binary), "--hejo-smooth", args.mode, str(output), str(REPO / "app/.build/hejo.app/Contents/Resources/Pet")]
        with (output / "run.log").open("w") as log:
            code, timed_out = hejo_perf.run_probe(command, env, log, 600)
    write(output / "execution.json", {"command": "--hejo-smooth " + args.mode, "exit_code": code, "timeout": timed_out,
        "head": BASE if args.mode=="baseline" else hejo_perf.git("rev-parse", "HEAD"), "preserved_source": args.source is not None, "product_diff": hejo_perf.git("diff", "HEAD", "--", "app/Sources"),
        "binary_sha256": hejo_perf.digest(binary), "build_receipt": str((hejo_perf.EVIDENCE / "build.json").relative_to(REPO))})
    if (output / "performance.json").exists():
        summary = summarize(output, baseline if args.mode != "baseline" else output)
        print(json.dumps(summary, ensure_ascii=False))
    if code or timed_out:
        raise RuntimeError("AppKit probe failed; see run.log and execution.json")
    if args.mode in {"derived","cards","manual"}:
        print("HEJO_SMOOTH_"+args.mode.upper()+"_RECORDED"); return
    if args.mode != "baseline":
        compare(output, baseline)
        if (output / "performance.json").exists():
            assert all(v["pass"] for k, v in summary.items() if k != "scroll_observation_only"), "AT-SM-05 budget missed"
    print("HEJO_SMOOTH_" + args.mode.upper() + "_OK")

if __name__ == "__main__":
    main()
