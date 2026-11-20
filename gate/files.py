"""Attachment staging and ownership; committed message metadata is the authority."""
import asyncio
import mimetypes
import os
from pathlib import Path
import re
import shutil
import time
import uuid

MAX_FILE_BYTES = 50 * 1024 * 1024
RETENTION_SECONDS = 24 * 60 * 60
ID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
EMPLOYEE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9_-]*$")


class UnknownFile(ValueError):
    def __init__(self):
        super().__init__("unknown_file")


def safe_name(name):
    if not isinstance(name, str) or not 1 <= len(name) <= 255 or name in {".", ".."}:
        raise UnknownFile()
    if any(c in name for c in ("/", "\\", "\x00")):
        raise UnknownFile()
    return name


class FileStore:
    def __init__(self, home, journal):
        self.home = Path(home).resolve()
        self.root = self.home / "shared" / "hejo" / "files"
        self.journal = journal
        self.lock = asyncio.Lock()
        self.active_uploads = set()
        self.checked(self.root).mkdir(parents=True, exist_ok=True, mode=0o700)

    def checked(self, path):
        path = Path(path)
        try:
            relative = path.relative_to(self.home)
        except ValueError:
            raise UnknownFile() from None
        cursor = self.home
        for part in relative.parts:
            if part in {".", ".."}:
                raise UnknownFile()
            cursor /= part
            if cursor.is_symlink():
                raise UnknownFile()
        if not path.resolve().is_relative_to(self.home):
            raise UnknownFile()
        return path

    def pending(self, employee, file_id):
        if not EMPLOYEE.fullmatch(employee) or not ID.fullmatch(file_id):
            raise UnknownFile()
        return self.checked(self.root / ".pending" / employee / file_id)

    def describe(self, directory, file_id):
        entries = list(self.checked(directory).iterdir())
        if len(entries) != 1:
            raise UnknownFile()
        path = self.checked(entries[0])
        name = safe_name(path.name)
        if not path.is_file():
            raise UnknownFile()
        return {"file_id": file_id, "name": name,
                "mime": mimetypes.guess_type(name)[0] or "application/octet-stream",
                "size": path.stat().st_size}

    @staticmethod
    def fsync_dir(path):
        fd = os.open(path, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    async def stage(self, employee, name, chunks):
        name = safe_name(name)
        file_id = str(uuid.uuid4())
        target = self.pending(employee, file_id)
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        working = self.checked(target.parent / (".writing-" + file_id))
        working.mkdir(mode=0o700)
        self.active_uploads.add(working)
        try:
            fd = os.open(working / name, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
            try:
                size = 0
                async for chunk in chunks:
                    size += len(chunk)
                    if size > MAX_FILE_BYTES:
                        raise ValueError("too_large")
                    with memoryview(chunk) as data:
                        while data:
                            written = os.write(fd, data)
                            if written <= 0:
                                raise OSError("short file write")
                            data = data[written:]
                os.fsync(fd)
            finally:
                os.close(fd)
            self.fsync_dir(working)
            async with self.lock:
                os.replace(working, target)
                self.fsync_dir(target.parent)
                return self.describe(target, file_id)
        except BaseException:
            if working.exists():
                shutil.rmtree(working)
            if target.exists():
                shutil.rmtree(target)
            raise
        finally:
            self.active_uploads.discard(working)

    def promote(self, employee, ids):
        if len(ids) != len(set(ids)):
            raise UnknownFile()
        prepared = [(self.pending(employee, i), self.describe(self.pending(employee, i), i)) for i in ids]
        moved = []
        try:
            for source, info in prepared:
                destination = self.checked(self.root / info["file_id"])
                if destination.exists():
                    raise UnknownFile()
                os.rename(source, destination)
                moved.append((source, destination))
            if moved:
                self.fsync_dir(self.root)
                for parent in {source.parent for source, _ in moved}:
                    self.fsync_dir(parent)
        except BaseException:
            self.rollback(moved)
            raise
        return [info for _, info in prepared], moved

    def rollback(self, moved):
        for source, destination in reversed(moved):
            self.checked(source)
            self.checked(destination)
            os.rename(destination, source)
            self.fsync_dir(source.parent)
        if moved:
            self.fsync_dir(self.root)

    def registration(self, employee, owner, descriptors):
        return [{**info, "employee": employee, "owner": owner,
                 "path": str(self.checked(self.root / info["file_id"] / info["name"]))}
                for info in descriptors]

    def registered(self, employee, file_id):
        if not EMPLOYEE.fullmatch(employee) or not ID.fullmatch(file_id):
            raise UnknownFile()
        for row in reversed(self.journal.records):
            if self.journal.hidden(row):
                continue
            for entry in row.get("_meta", {}).get("files", []):
                if entry["file_id"] == file_id and entry["employee"] == employee:
                    path = self.checked(self.root / file_id / safe_name(entry["name"]))
                    if str(path) != entry["path"] or not path.is_file():
                        raise UnknownFile()
                    return path, entry["mime"]
        raise UnknownFile()

    async def copy(self, employee, file_path, file_name=None):
        source = Path(file_path)
        if source.is_symlink() or not source.is_file():
            raise UnknownFile()
        async def chunks():
            fd = os.open(source, os.O_RDONLY | os.O_NOFOLLOW)
            try:
                while chunk := os.read(fd, 65536):
                    yield chunk
            finally:
                os.close(fd)
        return await self.stage(employee, file_name or source.name, chunks())

    def cleanup(self, now=None):
        cutoff = (time.time() if now is None else now) - RETENTION_SECONDS
        registered = {entry["file_id"] for row in self.journal.records
                      if not self.journal.hidden(row)
                      for entry in row.get("_meta", {}).get("files", [])}
        for item in self.root.iterdir():
            if item.name == ".pending":
                for employee in self.checked(item).iterdir():
                    for pending in self.checked(employee).iterdir():
                        if pending not in self.active_uploads and self.checked(pending).stat().st_mtime < cutoff:
                            shutil.rmtree(pending)
            elif item.name not in registered:
                self.checked(item)
                if item.is_dir():
                    shutil.rmtree(item)
                else:
                    item.unlink()
