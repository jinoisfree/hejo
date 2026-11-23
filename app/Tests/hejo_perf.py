#!/usr/bin/env python3
"""Build an optimized isolated AppKit probe; freeze only on the approved source baseline."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[2]
FIXTURE = REPO / "app/Tests/Fixtures/HejoPerf"
EVIDENCE = REPO / ".build/hejo-perf-evidence"
BASE = "39f954c1bd3a50fd27d4f11a3b03774d0e74aa41"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(["git", "-C", str(REPO), *args], text=True).strip()


def write_json(path, obj):
    path.write_text(json.dumps(obj, indent=2, sort_keys=True, ensure_ascii=False) + "\n")


def build(skip):
    binary = EVIDENCE / "hejo-perf-tests"
    sparkle = Path(os.environ.get("HEJO_PERF_SPARKLE_DIR", REPO / "app/.build/sparkle-2.10.0"))
    if not (sparkle / "Sparkle.framework").is_dir():
        raise RuntimeError("Cached Sparkle framework required; set HEJO_PERF_SPARKLE_DIR")
    sources = sorted((REPO / "app/Sources").glob("*.swift"))
    sources = [p for p in sources if p.name != "AppMain.swift"] + sorted((REPO / "app/Tests").glob("*.swift"))
    options = ["-swift-version", "5", "-parse-as-library", "-O", "-D", "HEJO_PERF_TESTING", "-target", platform.machine() + "-apple-macosx13.0"]
    fingerprint = {"sources": {str(p.relative_to(REPO)): digest(p) for p in sources}, "options": options,
                   "compiler": subprocess.check_output(["xcrun", "swiftc", "--version"], text=True)}
    receipt = EVIDENCE / "build.json"
    if skip:
        old = json.loads(receipt.read_text())
        if old["input"] != fingerprint or old["binary_sha256"] != digest(binary):
            raise RuntimeError("Stale probe executable; rebuild without --no-build")
        return binary
    command = ["xcrun", "swiftc", *options, *map(str, sources), "-o", str(binary)]
    for framework in ["AppKit", "EventKit", "WebKit", "Accelerate", "ServiceManagement"]:
        command += ["-framework", framework]
    command += ["-F", str(sparkle), "-framework", "Sparkle", "-Xlinker", "-rpath", "-Xlinker", str(sparkle)]
    with (EVIDENCE / "compile.log").open("w") as log:
        result = subprocess.run(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError("Compile failed; see .build/hejo-perf-evidence/compile.log")
    write_json(receipt, {"input": fingerprint, "binary_sha256": digest(binary), "compile_exit_code": result.returncode})
    return binary


def main():
    global EVIDENCE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["freeze", "check", "measure", "home", "regression"])
    parser.add_argument("--no-build", action="store_true")
    parser.add_argument("--evidence", type=Path, default=EVIDENCE)
    args = parser.parse_args()
    EVIDENCE = args.evidence.resolve()
    EVIDENCE.relative_to((REPO / ".build/hejo-perf-evidence").resolve())
    if EVIDENCE == REPO / ".build/hejo-perf-evidence" and git("diff", BASE, "--", "app/Sources"):
        raise RuntimeError("Preserve baseline evidence; use --evidence with a separate comparison directory")
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    expected = FIXTURE / "expected.json"
    manifest = FIXTURE / "baseline.json"
    source_tree = git("rev-parse", BASE + ":app/Sources")
    if args.mode == "freeze":
        if git("rev-parse", "HEAD") != BASE or expected.exists() or manifest.exists():
            raise RuntimeError("Freeze requires exact baseline HEAD and no existing expected fixture")
        subprocess.run(["git", "diff", "--exit-code", BASE, "--", "app/Sources"], cwd=REPO, check=True)
    else:
        frozen = json.loads(manifest.read_text())
        if frozen["input_sha256"] != digest(FIXTURE / "input.json") or frozen["expected_sha256"] != digest(expected):
            raise RuntimeError("Frozen fixture changed")
    output = EVIDENCE / args.mode
    if output.exists():
        raise RuntimeError("Evidence directory already exists; preserve it before another run")
    binary = build(args.no_build)
    output.mkdir()
    with tempfile.TemporaryDirectory(prefix="isolated-home-", dir=EVIDENCE) as home:
        Path(home, "hejo-perf-isolated").touch()
        env = os.environ | {"HERMES_HOME": home, "TZ": "UTC", "HEJO_THREE_TAP_TRACE": ""}
        with (output / "run.log").open("w") as log:
            command = [str(binary), "--hejo-perf", str(FIXTURE / "input.json"), str(output),
                       args.mode if args.mode in {"measure", "home"} else "semantic"]
            if args.mode == "regression":
                resources = os.environ.get("HEJO_PERF_PET_DIR", str(REPO / "app/.build/hejo.app/Contents/Resources/Pet"))
                command = [str(binary), "--hejo-perf-regression", resources]
            result = subprocess.run(command, cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT)
    write_json(output / "execution.json", {"exit_code": result.returncode, "head": git("rev-parse", "HEAD"),
               "source_tree": git("rev-parse", "HEAD:app/Sources"), "product_diff": git("diff", "HEAD", "--", "app/Sources"),
               "binary_sha256": digest(binary), "platform": platform.platform(),
               "input_sha256": digest(FIXTURE / "input.json"), "timezone": "UTC"})
    if result.returncode:
        raise RuntimeError("Probe failed; see run.log (exit " + str(result.returncode) + ")")
    observed = output / "observed.json"
    if args.mode == "freeze":
        # Exclusive creation: never replace an earlier baseline, including a partial freeze.
        with expected.open("xb") as stream:
            stream.write(observed.read_bytes())
        with manifest.open("x") as stream:
            json.dump({"base_commit": BASE, "product_tree": source_tree, "input_sha256": digest(FIXTURE / "input.json"),
                       "expected_sha256": digest(expected), "normalization": [
                           "Unknown generated selection thread UUIDs become <generated-thread>; fixture IDs remain exact.",
                           "Dictionary/set observations are sorted; timeline, thread and notice order remains exact.",
                           "Wall-clock member-state metadata and typing expiry timestamps are excluded; values/typing presence are observed."
                       ]}, stream, indent=2, sort_keys=True)
            stream.write("\n")
    elif args.mode != "regression" and observed.read_bytes() != expected.read_bytes():
        raise RuntimeError("Baseline output mismatch; compare observed.json with frozen expected.json")
    if args.mode in {"measure", "home"}:
        raw = json.loads((output / "performance.json").read_text())
        rows = [r for r in raw["runs"] if not r["warm_up"]]
        summary = {}
        for name in ["wall_seconds", "cpu_percent", "input_queue_seconds", "switch_queue_seconds", "switch_seconds"]:
            values = [r[name] for r in rows]
            summary[name] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
        values = [sum(r["receive_seconds"]) / len(r["receive_seconds"]) for r in rows]
        summary["mean_receive_seconds"] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
        summary["cpu_seconds"] = {"median": statistics.median(r["cpu_seconds"] for r in rows), "max": max(r["cpu_seconds"] for r in rows), "min": min(r["cpu_seconds"] for r in rows)}
        summary["all_actions_before_end"] = all(r["input_before_end"] and r["switch_before_end"] for r in rows)
        summary["workload_sha256"] = digest(output / "workload-frames.json")
        write_json(output / "summary.json", summary)
        print(json.dumps(summary, sort_keys=True))
        samples = [v for r in rows for v in r["receive_seconds"]]
        checks = {"receive": statistics.median(samples) <= .25 and max(samples) <= .5,
                  "completed_actions": summary["all_actions_before_end"]}
        for name in ["input_queue_seconds", "switch_queue_seconds", "switch_seconds"]:
            checks[name] = summary[name]["median"] <= .25 and summary[name]["max"] <= .5 and summary[name]["min"] >= 0
        for name in ["wall_seconds", "cpu_seconds"]:
            checks[name] = summary[name]["median"] <= 2 and summary[name]["max"] <= 3
        if args.mode == "measure":
            baseline = json.loads((REPO / ".build/hejo-perf-evidence/measure/performance.json").read_text())
            base_cpu = statistics.median(r["cpu_seconds"] for r in baseline["runs"] if not r["warm_up"])
            checks["cpu_reduction_99_percent"] = summary["cpu_seconds"]["median"] <= base_cpu * .01
            checks["same_workload"] = all(r["workload_sha256"] == summary["workload_sha256"] for r in baseline["runs"])
        write_json(output / "budgets.json", checks)
        if not all(checks.values()):
            raise RuntimeError("v3 performance budget failed; see budgets.json")
    print("HEJO_PERF_" + args.mode.upper() + "_OK")


if __name__ == "__main__":
    main()
