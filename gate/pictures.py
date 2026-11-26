"""Profile-owned employee pictures and shared room and owner pictures."""
import colorsys
import math
import os
from pathlib import Path
import re
import struct
import tempfile
import zlib

from hermes_cli.profiles import profiles_to_serve
from ruamel.yaml import YAML
from ruamel.yaml.error import YAMLError

MAX_PICTURE_BYTES = 512 * 1024
PNG = b"\x89PNG\r\n\x1a\n"


def profile_color(home):
    try:
        data = YAML(typ="safe").load((Path(home) / "profile.yaml").read_text())
        value = data["ui_meta"]["hermes-bots"]["color"]
        if not isinstance(value, str):
            return None
        if re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            return value.upper()
        match = re.fullmatch(r"hsl\((.*)\)", value)
        if match:
            parts = re.split(r"[\s,]+", match[1].strip())
            if len(parts) != 3 or not parts[1].endswith("%") or not parts[2].endswith("%"):
                return None
            hue, saturation, lightness = float(parts[0]), float(parts[1][:-1]), float(parts[2][:-1])
            if all(map(math.isfinite, (hue, saturation, lightness))) and 0 <= saturation <= 100 and 0 <= lightness <= 100:
                rgb = colorsys.hls_to_rgb((hue % 360) / 360, lightness / 100, saturation / 100)
                return "#" + "".join(f"{int(c * 255 + .5):02X}" for c in rgb)
    except (OSError, ValueError, TypeError, KeyError, YAMLError):
        pass
    return None


def profile_picture(home):
    assets = Path(home) / "assets"
    if assets.is_symlink():
        return None
    for name in ("avatar.png", "slack-avatar.png"):
        path = assets / name
        if not path.is_symlink() and path.is_file():
            return path
    return None


def valid_png(data):
    """Check complete PNG framing, CRC and a decodable pixel stream, within a bound."""
    if not data.startswith(PNG):
        return False
    offset, first, pixels, ended = 8, True, bytearray(), False
    try:
        while offset + 12 <= len(data):
            size = struct.unpack_from(">I", data, offset)[0]
            kind = data[offset + 4:offset + 8]
            end = offset + 8 + size
            if end + 4 > len(data):
                return False
            body = data[offset + 8:end]
            if zlib.crc32(kind + body) != struct.unpack_from(">I", data, end)[0]:
                return False
            if first:
                if kind != b"IHDR" or size != 13:
                    return False
                width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", body)
                if not width or not height or depth not in (1, 2, 4, 8, 16) or color not in (0, 2, 3, 4, 6) or compression or filtering or interlace not in (0, 1):
                    return False
                first = False
            if kind == b"IDAT":
                pixels.extend(body)
            if kind == b"IEND":
                ended = size == 0 and end + 4 == len(data)
                break
            offset = end + 4
        if not ended or not pixels:
            return False
        # Bounded decompression validates the stream without allocating attacker-sized images.
        decoder = zlib.decompressobj()
        remaining, decoded_bytes = bytes(pixels), 0
        while remaining:
            decoded_bytes += len(decoder.decompress(remaining, 1024 * 1024))
            remaining = decoder.unconsumed_tail
        return decoded_bytes > 0 and decoder.eof and not decoder.unused_data
    except (ValueError, struct.error, zlib.error):
        return False


def picture_address(kind, identifier, path):
    return f"/v1/pictures/{kind}/{identifier}?v={path.stat().st_mtime_ns}"


class Pictures:
    def __init__(self, home, multiplex=True):
        self.home = Path(home)
        self.multiplex = multiplex

    def path(self, kind, identifier, *, write=False):
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,128}", identifier):
            raise KeyError("unknown_picture")
        if kind == "employee":
            homes = dict(profiles_to_serve(self.multiplex))
            if identifier not in homes:
                raise KeyError("unknown_employee")
            directory = Path(homes[identifier]) / "assets"
            path = directory / "avatar.png" if write else profile_picture(homes[identifier])
        elif kind == "room" or (kind == "owner" and identifier == "owner"):
            directory = self.home / "shared" / "hejo" / "pictures"
            stem = identifier
            if kind == "room" and not identifier.startswith(("section-", "home-")):
                stem = "room-" + identifier
            path = directory / (stem + ".png")
        else:
            raise KeyError("unknown_picture")
        # Reject symlink components before reading or creating directories.
        checked = [directory] if kind == "employee" else [directory, directory.parent, directory.parent.parent]
        if any(p.is_symlink() for p in checked) or (path is not None and path.is_symlink()):
            raise KeyError("unknown_picture")
        if path is None:
            raise KeyError("unknown_picture")
        return path

    def put(self, kind, identifier, data):
        path = self.path(kind, identifier, write=True)
        if kind == "owner":
            path.parent.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        path.parent.mkdir(parents=True, exist_ok=True, mode=0o755 if kind == "employee" else 0o700)
        if kind != "employee":
            os.chmod(path.parent, 0o700)
        temporary = None
        try:
            fd, temporary = tempfile.mkstemp(prefix=".picture-", dir=path.parent)
            with os.fdopen(fd, "wb") as stream:
                os.fchmod(stream.fileno(), 0o644 if kind == "employee" else 0o600)
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(temporary, path)
            temporary = None
        finally:
            if temporary is not None:
                os.unlink(temporary)
        return path

    def delete(self, kind, identifier):
        self.path(kind, identifier, write=True).unlink(missing_ok=True)
