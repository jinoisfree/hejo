#!/usr/bin/env python3
"""Record independent native test groups without losing failures after an early assertion."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import hejo_perf

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "app/.build/hejo-smooth-public"
BASE = "dba49a7ccea4b4212618ecf773e40c4e18f6bb67"
FLAGS = ["--hejo-perf-regression", "--hejo-typing-boundaries", "--task40", "--task37",
         "--task39", "--task41", "--task43", "--task42", "--task38", "--task36",
         "--task47", "--task46", "--task45", "--task44", "--review56-existing",
         "--review56", "--review55", "--telegram", "--todo-drawer", "--drawer-inline",
         "--finder-picture", "--ui-clean-island", "--ui-clean-polish", "--ui-clean-polish-probe", "--connections", "--connection-stuck", "--thread-done", "--pet-position", "--hejo-reconnect-boundaries"]

def write(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["baseline", "final"])
    parser.add_argument("--output", type=Path)
    parser.add_argument("--source",type=Path)
    parser.add_argument("--probe",type=Path)
    args = parser.parse_args()
    folder = (args.output or ROOT / ("regression-" + args.mode)).resolve()
    folder.relative_to(ROOT.resolve())
    folder.mkdir()  # Preserve earlier evidence, including failures.
    source = REPO
    if args.source:
        source=args.source.resolve()
    elif args.mode == "baseline":
        source = folder / "source"
        source.mkdir()
        archive = subprocess.check_output(["git", "archive", BASE, "app/Sources", "app/Tests"], cwd=REPO)
        subprocess.run(["tar", "-xf", "-", "-C", str(source)], input=archive, check=True)
    hejo_perf.REPO = source
    hejo_perf.EVIDENCE = (args.probe or folder / "build").resolve()
    hejo_perf.EVIDENCE.mkdir(exist_ok=True)
    os.environ["HEJO_PERF_SPARKLE_DIR"] = str(REPO / "app/.build/sparkle-2.10.0")
    binary = hejo_perf.build(args.probe is not None)
    resources = REPO / "app/.build/hejo.app/Contents/Resources/Pet"
    results = []
    with tempfile.TemporaryDirectory(prefix="hejo-sm-", dir="/tmp") as home:
        Path(home, "hejo-perf-isolated").touch()
        env = os.environ | {"HERMES_HOME": home, "TMPDIR": home, "TZ": "UTC", "HEJO_THREE_TAP_TRACE": "", "PYTHONDONTWRITEBYTECODE": "1"}
        def run(name, command):
            log = folder / (name + ".log")
            with log.open("w") as stream:
                code, timeout = hejo_perf.run_probe(list(map(str, command)), env, stream, 180)
            (folder / (name + ".exit")).write_text(str(code) + "\n")
            results.append({"name": name, "command": list(map(str, command)), "exit_code": code,
                            "timeout": timeout, "log": str(log.relative_to(ROOT))})
            write(folder / "results.json", results)
        semantic = folder / "semantic"
        semantic.mkdir()
        run("semantic", [binary, "--hejo-perf", REPO / "app/Tests/Fixtures/HejoPerf/input.json", semantic, "semantic"])
        if (semantic / "observed.json").exists():
            results[-1]["frozen_equal"] = (semantic / "observed.json").read_bytes() == (REPO / "app/Tests/Fixtures/HejoPerf/expected.json").read_bytes()
        for flag in FLAGS:
            run(flag[2:], [binary, flag, resources])
        capture = folder / "three-tap"
        capture.mkdir()
        run("three-tap", [binary, "--task35-capture", resources, capture])
    write(folder / "results.json", results)
    write(folder / "revision.json", {"commit": BASE if args.mode == "baseline" else hejo_perf.git("rev-parse", "HEAD"),
          "binary_sha256": hejo_perf.digest(binary), "recording_complete": True})
    print("Groups recorded:", len(results), "failures:", [r["name"] for r in results if r["exit_code"]])

if __name__ == "__main__":
    main()
