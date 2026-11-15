"""Per-member screen state: one locked, atomic document; reads advance and other keys use LWW."""
from contextlib import contextmanager
import fcntl
import json
import math
import os
from pathlib import Path
import tempfile
import uuid

from .store import Rejected

MAX_BYTES = 1024 * 1024
MAX_VALUE_BYTES = 4096
READ_PREFIXES = ("read:", "thread:", "bell:")
CAPS = {"thread:": 3000, "bell:": 1000, "confirm:": 2000, "check:": 2000}


def encoded(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode()


def read_value(entry):
    return int(entry["v"]) if entry and entry["v"] is not None else 0


def validate(items):
    if not isinstance(items, dict):
        raise Rejected("bad_state")
    for key, entry in items.items():
        if (not isinstance(key, str) or not 1 <= len(key.encode()) <= 200 or "\n" in key
                or not isinstance(entry, dict) or set(entry) != {"v", "at", "dev"}):
            raise Rejected("bad_state")
        value, at, device = entry["v"], entry["at"], entry["dev"]
        try:
            valid_time = not isinstance(at, bool) and isinstance(at, (int, float)) and math.isfinite(at) and at >= 0
        except OverflowError:
            valid_time = False
        if (value is not None and (not isinstance(value, str) or len(value.encode()) > MAX_VALUE_BYTES)
                or not valid_time
                or not isinstance(device, str) or not 1 <= len(device.encode()) <= 200 or "\n" in device):
            raise Rejected("bad_state")
        if key.startswith(READ_PREFIXES) and value is not None:
            if not value.isascii() or not value.isdecimal() or len(value) > 16 or int(value) > 2 ** 53 - 1:
                raise Rejected("bad_state")


def wins(key, new, old):
    if old is None:
        return True
    if key.startswith(READ_PREFIXES):
        return read_value(new) > read_value(old)
    return (new["at"], new["dev"]) > (old["at"], old["dev"])


class MemberStateStore:
    def __init__(self, home):
        self.directory = Path(home) / "state"

    @contextmanager
    def locked(self, member):
        member = str(uuid.UUID(member))  # Authenticated HubStore identity, never an account name/path.
        self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        fd = os.open(self.directory / (member + ".lock"), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield self.directory / (member + ".json")
        finally:
            os.close(fd)

    def read(self, path):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
        except FileNotFoundError:
            return {"rev": 0, "items": {}}
        with os.fdopen(fd) as stream:
            return json.load(stream)

    def get(self, member, since=None):
        with self.locked(member) as path:
            doc = self.read(path)
        return {"rev": doc["rev"], "items": {} if since == doc["rev"] else doc["items"]}

    def write(self, path, data):
        fd, temporary = tempfile.mkstemp(prefix=".state-", dir=self.directory)
        try:
            with os.fdopen(fd, "wb") as stream:
                os.fchmod(stream.fileno(), 0o600)
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def patch(self, member, items):
        validate(items)
        with self.locked(member) as path:
            doc = self.read(path)
            merged = dict(doc["items"])
            for key, entry in items.items():
                if wins(key, entry, merged.get(key)):
                    merged[key] = entry
            for prefix, keep in CAPS.items():
                keys = [key for key in merged if key.startswith(prefix)]
                def rank(key):
                    return read_value(merged[key]) if key.startswith(READ_PREFIXES) else merged[key]["at"]
                for key in sorted(keys, key=lambda key: (rank(key), key), reverse=True)[keep:]:
                    del merged[key]
            result = {"rev": doc["rev"] + 1, "items": merged}
            data = encoded(result)
            if len(data) > MAX_BYTES:
                raise Rejected("bad_state")
            self.write(path, data)
            return result
