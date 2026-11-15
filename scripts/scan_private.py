#!/usr/bin/env python3
"""Scan tracked text using two explicit owner inputs; never print matched values."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


# Pattern provenance and deliberate scope differences: TASK-07 copy-review.md.
PATTERNS = {
    "slack_id": re.compile(r"(?<![A-Za-z0-9_])[CDUTW]0[A-Z0-9]{8,}(?![A-Za-z0-9_])"),
    "email": re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"),
    "absolute_path": re.compile(r"/(?:Users|Volumes)/"),
    "fixed_home": re.compile(r"""(?:Path\.home\(\)\s*/\s*["']\.hermes["']|["']~/?\.hermes|\$(?:HOME|\{HOME\})/\.hermes|expanduser\(["']~["']\)\s*[/+]\s*["']/?\.hermes)"""),
}
CODE_SUFFIXES = {".py", ".swift", ".sh"}


def fingerprint(line):
    return hashlib.sha256(line.encode("utf-8")).hexdigest()


def read_owner(home, name):
    path = home / "owner" / name
    # Do not let a fixed input name become an alias to another home file.
    if path.resolve() != path:
        raise ValueError("owner input must not be a symlink")
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except FileNotFoundError:
        return {}
    with os.fdopen(fd, encoding="utf-8") as stream:
        text = stream.read()
    try:
        return json.loads(text)
    except ValueError:
        from ruamel.yaml import YAML
        return YAML(typ="safe").load(text)


def roster_words(roster):
    words = set()
    for identifier, member in (roster or {}).get("agents", {}).items():
        if identifier != "default":
            words.update((identifier, identifier.replace("-", "_")))
        for key in ("name", "label"):
            if isinstance(member.get(key), str):
                words.add(member[key])
        words.update(alias for alias in member.get("aliases", []) if isinstance(alias, str))
    return {word for word in words if word}


def vault_words(value):
    if isinstance(value, str):
        if len(value) <= 16 and re.fullmatch(r"[a-z][a-z0-9_-]*", value):
            return set()
        return {value} if len(value) >= 3 else set()
    if isinstance(value, dict):
        return set().union(set(), *(vault_words(item) for item in value.values()))
    if isinstance(value, list):
        return set().union(set(), *(vault_words(item) for item in value))
    return set()


def word_pattern(words):
    parts = []
    for word in sorted(words, key=lambda word: (-len(word), word)):
        escaped = re.escape(word)
        if re.fullmatch(r"[A-Za-z0-9_-]+", word):
            escaped = r"(?<![A-Za-z0-9_])" + escaped + r"(?![A-Za-z0-9_])"
        parts.append(escaped)
    return re.compile("|".join(parts)) if parts else None


def read_allow(path):
    if not path.exists():
        return {}
    allowed = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        name, digest, reason = line.split("\t", 2)
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("invalid line fingerprint")
        if reason not in {"fake-test", "license-notice"}:
            raise ValueError("invalid exception reason")
        allowed[(name, digest)] = reason
    return allowed


def is_allowed(allowed, name, line):
    reason = allowed.get((name, fingerprint(line)))
    if reason == "fake-test":
        return True
    return (reason == "license-notice" and Path(name).name.upper().startswith("LICENSE")
            and re.search(r"copyright|©", line, re.IGNORECASE) is not None)


def scan(repo, home, allow):
    checks = dict(PATTERNS)
    checks["roster"] = word_pattern(roster_words(read_owner(home, "team.yaml")))
    checks["vault"] = word_pattern(vault_words(read_owner(home, "vault.yaml")))
    allowed = read_allow(allow)
    names = subprocess.check_output(["git", "-C", str(repo), "ls-files", "-z"], stderr=subprocess.PIPE)
    findings = 0
    for raw in names.split(b"\0"):
        if not raw:
            continue
        name = os.fsdecode(raw)
        path = repo / name
        if path.is_symlink():
            data = os.readlink(path).encode("utf-8")
        else:
            if not path.resolve().is_relative_to(repo):
                raise ValueError("tracked path escapes repository")
            if not path.exists():
                continue  # A tracked deletion has no working-tree contents to inspect.
            data = path.read_bytes()
        try:
            if b"\0" in data[:8192]:
                raise UnicodeError
            text = data.decode("utf-8")
        except UnicodeError:
            print(f"바이너리 생략\t{name}")
            continue
        code = path.suffix in CODE_SUFFIXES or text.startswith("#!")
        for number, line in enumerate(text.splitlines(), 1):
            if is_allowed(allowed, name, line):
                continue
            for kind, pattern in checks.items():
                if kind == "fixed_home" and not code:
                    continue
                if pattern is not None and pattern.search(line):
                    print(f"{kind}\t{name}\t{number}\t{fingerprint(line)}")
                    findings += 1
    return 1 if findings else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--home", type=Path)
    parser.add_argument("--allow", type=Path)
    args = parser.parse_args(argv)
    repo = args.repo.expanduser().resolve()
    home = (args.home or Path(os.environ.get("HERMES_HOME", Path.home().joinpath(".hermes")))).expanduser().resolve()
    allow = args.allow or repo / "scripts" / "scan_private_allow.txt"
    try:
        return scan(repo, home, allow)
    except Exception as exc:
        # Parser/library errors may contain source values; emit no exception text.
        print(f"scan_error\t-\t0\t{fingerprint(type(exc).__name__)}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
