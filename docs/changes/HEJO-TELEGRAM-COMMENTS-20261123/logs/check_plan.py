"""Read-only validation of this plan's links, AC coverage and generic private patterns."""
from pathlib import Path
import importlib.util
import re
import subprocess

root = Path.cwd()
folder = root / "docs/changes/HEJO-TELEGRAM-COMMENTS-20261123"
acceptance = root / "tests/acceptance/HEJO-TELEGRAM-COMMENTS.md"
files = sorted(folder.glob("*.md")) + [acceptance, root / "docs/changes/a6291a01-a451-4239-b635-ac5ef2f23e69/plan-review.md"]
module_spec = importlib.util.spec_from_file_location("private_scan", root / "scripts/scan_private.py")
scanner = importlib.util.module_from_spec(module_spec)
module_spec.loader.exec_module(scanner)
errors = []
for path in files:
    text = path.read_text()
    for target in re.findall(r"\]\(([^)]+)\)", text):
        if "://" not in target and not target.startswith("#"):
            if not (path.parent / target.split("#", 1)[0]).exists():
                errors.append(f"broken-link:{path.name}:{target}")
    for label, pattern in scanner.PATTERNS.items():
        if label != "fixed_home" and pattern.search(text):
            errors.append(f"private-pattern:{path.name}:{label}")
required = set()
section = None
for line in (folder / "spec.md").read_text().splitlines():
    heading = re.match(r"### (REQ-HTC-\d+|NFR-HTC-\d+)", line)
    if heading:
        section = heading[1]
    ac = re.match(r"- AC-(\d+)", line)
    if ac and section:
        required.add(f"{section}.AC-{ac[1]}")
mapped = set()
for line in acceptance.read_text().splitlines():
    if re.match(r"\| T\d+ \|", line):
        cell = line.split("|")[2].strip()
        for prefix, ac in re.findall(r"(\d{2}|N)\.(\d{2})", cell):
            req = "NFR-HTC-01" if prefix == "N" else f"REQ-HTC-{prefix}"
            mapped.add(f"{req}.AC-{ac}")
mapped.update(re.findall(r"REQ-HTC-\d+\.AC-\d+", acceptance.read_text()))
errors.extend(f"unmapped:{item}" for item in sorted(required - mapped))
errors.extend(f"unknown-ac:{item}" for item in sorted(mapped - required))
head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
print(f"base_commit={head}")
print(f"markdown_files={len(files)} ac_total={len(required)} mapped={len(mapped)}")
print("scope=plan documents only; no runtime tests or owner-specific private inputs")
for error in errors:
    print(error)
print("PASS" if not errors else "FAIL")
raise SystemExit(bool(errors))
