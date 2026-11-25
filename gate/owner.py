"""The paired owner's profile in the gate's shared storage."""
import json
import logging
import os
from pathlib import Path
import tempfile
from unicodedata import category

from .pictures import Pictures, picture_address

log = logging.getLogger(__name__)


def valid_name(value):
    if value is None:
        return None
    if not isinstance(value, str) or any(
        category(character).startswith("C") or character in "\u2028\u2029"
        for character in value
    ):
        raise ValueError("invalid_name")
    name = value.strip()
    if len(name) > 20:
        raise ValueError("invalid_name")
    return name or None


def _path(home):
    path = Path(home) / "shared" / "hejo" / "owner.json"
    if path.parent.is_symlink() or path.parent.parent.is_symlink():
        raise OSError("owner_profile_directory")
    return path


def read(home):
    try:
        path = _path(home)
        if path.is_symlink() or (path.exists() and not path.is_file()):
            raise ValueError("invalid_owner_profile_file")
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict) or type(data.get("v")) is not int or data["v"] != 1:
            raise ValueError("invalid_owner_profile_version")
        return {"name": valid_name(data["name"])}
    except FileNotFoundError:
        return {"name": None}
    except (OSError, ValueError, KeyError, RecursionError):
        log.warning("owner_profile_read_failed")
        return {"name": None}


def write_name(home, value):
    name = valid_name(value)
    path = _path(home)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = None
    try:
        fd, temporary = tempfile.mkstemp(prefix=".owner-", dir=path.parent)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            os.fchmod(stream.fileno(), 0o600)
            json.dump({"v": 1, "name": name}, stream, ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            os.unlink(temporary)


def profile(home):
    result = read(home)
    result["avatar"] = None
    try:
        path = Pictures(home).path("owner", "owner")
        if path.is_file():
            result["avatar"] = picture_address("owner", "owner", path)
    except (KeyError, OSError):
        pass
    return result
