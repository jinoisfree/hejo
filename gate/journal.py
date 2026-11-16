"""Single-writer durable JSONL journal. JSONL alone is the recovery authority."""
import asyncio
from copy import deepcopy
from datetime import datetime, timezone
import fcntl
import json
import logging
import os
from pathlib import Path

log = logging.getLogger(__name__)
RECORD_TYPES = {"message", "edit", "delete", "state"}


class HejoJournalError(Exception):
    pass


class Journal:
    def __init__(self, home):
        self.path = Path(home) / "shared" / "hejo" / "journal"
        self.lock = asyncio.Lock()
        self.records = []
        self.head = 0
        self.faulted = False
        self.fd = None
        self.message_threads = {}
        self.deleted_threads = {}

    def open(self):
        self.path.mkdir(parents=True, mode=0o700, exist_ok=True)
        self.fd = os.open(self.path / ".lock", os.O_CREAT | os.O_RDWR, 0o600)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            self.close()
            raise HejoJournalError("journal_locked") from exc
        try:
            self._recover()
        except Exception:
            self.close()
            raise

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def _recover(self):
        records = []
        # Trim only trailing damage, never discard a valid later record.
        for path in sorted(self.path.glob("????-??.jsonl")):
            raw = path.read_bytes()
            lines = raw.splitlines(keepends=True)
            decoded = []
            for line in lines:
                try:
                    row = json.loads(line) if line.endswith(b"\n") else None
                    valid = (isinstance(row, dict) and type(row.get("seq")) is int
                             and row["seq"] > 0 and row.get("type") in RECORD_TYPES)
                except (ValueError, UnicodeDecodeError):
                    row, valid = None, False
                decoded.append(row if valid else None)
            last = max((i for i, row in enumerate(decoded) if row is not None), default=-1)
            if any(row is None for row in decoded[:last + 1]):
                raise HejoJournalError("journal_corrupt_interior")
            kept = sum(len(line) for line in lines[:last + 1])
            if kept < len(raw):
                with path.open("r+b") as stream:
                    stream.truncate(kept)
                    stream.flush()
                    os.fsync(stream.fileno())
                log.warning("journal_tail_recovered")
            records.extend(decoded[:last + 1])
        previous = 0
        for row in records:
            if row["seq"] <= previous:
                raise HejoJournalError("journal_seq_order")
            previous = row["seq"]
        self.records, self.head = records, previous
        self.message_threads, self.deleted_threads = {}, {}
        for row in records:
            self._index(row)

    def _index(self, row):
        if row["type"] == "message":
            self.message_threads[row["msg_id"]] = (row.get("room", row["employee"]), row["thread"])
        if row["type"] == "delete" and row.get("scope") == "thread":
            self.deleted_threads.setdefault((row["room"], row["thread"]), row)

    def deleted(self, room, thread):
        return (room, thread) in self.deleted_threads

    def hidden(self, row):
        key = self.message_threads.get(row.get("msg_id"))
        return key in self.deleted_threads

    def replay(self, row):
        point = self.deleted_threads.get(self.message_threads.get(row.get("msg_id")))
        if point and row["seq"] < point["seq"] and row["type"] in {"message", "edit", "state"}:
            return {"v": 1, "type": "delete", "seq": row["seq"], "msg_id": row["msg_id"]}
        return self.public(row)

    async def append(self, frame, internal=None):
        async with self.lock:
            if self.fd is None or self.faulted:
                raise HejoJournalError("journal_unavailable")
            row = dict(frame, seq=self.head + 1)
            if internal:
                row["_meta"] = internal
            data = (json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
            month = datetime.now(timezone.utc).strftime("%Y-%m")
            path = self.path / (month + ".jsonl")
            fd, before = None, None
            try:
                fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_APPEND, 0o600)
                before = os.lseek(fd, 0, os.SEEK_END)
                if os.write(fd, data) != len(data):
                    raise OSError("short journal write")
                # os.write is unbuffered; fsync is the commit boundary.
                os.fsync(fd)
            except OSError as exc:
                if fd is not None and before is not None:
                    try:
                        os.ftruncate(fd, before)
                        os.fsync(fd)
                    except OSError:
                        self.faulted = True
                log.error("journal_write_failed")
                raise HejoJournalError("journal_write_failed") from exc
            finally:
                if fd is not None:
                    os.close(fd)
            self.records.append(row)
            self.head = row["seq"]
            self._index(row)
            return self.public(row)

    @staticmethod
    def public(row):
        return deepcopy({k: v for k, v in row.items() if k != "_meta"})

    def page(self, since, limit=500):
        return [self.replay(row) for row in self.records if row["seq"] > since][:limit]

    def message(self, msg_id):
        if self.message_threads.get(msg_id) in self.deleted_threads:
            return None
        result = None
        for row in self.records:
            if row.get("msg_id") != msg_id:
                continue
            if row["type"] == "message":
                result = deepcopy(row)
            elif row["type"] == "delete":
                result = None
            elif result is not None:
                result.update({k: v for k, v in row.items() if k not in {"v", "type", "seq"}})
        return result
