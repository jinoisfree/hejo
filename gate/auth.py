"""Cross-process, owner-only pairing and device credentials; plaintext never persists."""
from contextlib import contextmanager
import fcntl
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import tempfile
import time
import uuid

PAIR_TTL = 600
LOCAL_FILE = "local-pair.json"
MAX_FAILURES = 5


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class AuthRejected(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


class AuthStore:
    def __init__(self, home, clock=time.time):
        self.path = Path(home) / "hejo"
        self.clock = clock

    @contextmanager
    def locked(self):
        self.path.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(self.path, 0o700)
        fd = os.open(self.path / ".auth.lock", os.O_CREAT | os.O_RDWR, 0o600)
        try:
            os.fchmod(fd, 0o600)
            fcntl.flock(fd, fcntl.LOCK_EX)
            yield
        finally:
            os.close(fd)

    def read(self, name, default):
        try:
            return json.loads((self.path / name).read_text())
        except FileNotFoundError:
            return default

    def write(self, name, data):
        fd, tmp = tempfile.mkstemp(prefix=".auth-", dir=self.path)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(data, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(tmp, self.path / name)
            directory = os.open(self.path, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    def pair_code(self):
        code = secrets.token_urlsafe(9)
        with self.locked():
            previous = self.read("pairing.json", {})
            # Issuing a new code never clears an active failure lockout.
            previous.update(hash=digest(code), expires=self.clock() + PAIR_TTL, used=False)
            self.write("pairing.json", previous)
        return code

    def local_code(self, port):
        """Fresh one-time code for an app on this Mac, readable only through the owner's 0600 file."""
        with self.locked():
            self._rotate_local(self.read("pairing.json", {}), port)

    def _rotate_local(self, pair, port):
        code = secrets.token_urlsafe(9)
        pair.update(local_hash=digest(code), local_port=port)
        self.write("pairing.json", pair)
        self.write(LOCAL_FILE, {"v": 1, "port": port, "code": code})

    def pair_trusted(self, device_name):
        """Mint a device for a peer the caller already verified (owner's own Tailscale node)."""
        with self.locked():
            return self._mint(device_name)

    def _mint(self, device_name):
        device_id, token = str(uuid.uuid4()), secrets.token_urlsafe(32)
        devices = self.read("devices.json", {})
        devices[device_id] = {"hash": digest(token), "name": device_name, "revoked": False}
        self.write("devices.json", devices)
        return device_id, token

    def pair(self, code, device_name, local=False):
        with self.locked():
            now = self.clock()
            pair = self.read("pairing.json", {})
            if local and pair.get("local_hash") and hmac.compare_digest(pair["local_hash"], digest(code)):
                # Consume before minting, then rotate so the file never holds a spent code.
                pair.pop("local_hash")
                self.write("pairing.json", pair)
                minted = self._mint(device_name)
                self._rotate_local(pair, pair.get("local_port"))
                return minted
            failures = [t for t in pair.get("failures", []) if now - t < PAIR_TTL]
            if pair.get("locked_until", 0) > now:
                raise AuthRejected("locked")
            if not hmac.compare_digest(pair.get("hash", ""), digest(code)):
                failures.append(now)
                pair["failures"] = failures
                if len(failures) >= MAX_FAILURES:
                    pair["locked_until"] = now + PAIR_TTL
                self.write("pairing.json", pair)
                raise AuthRejected("wrong")
            if pair.get("used"):
                raise AuthRejected("used")
            if now >= pair.get("expires", 0):
                raise AuthRejected("expired")
            device_id, token = str(uuid.uuid4()), secrets.token_urlsafe(32)
            devices = self.read("devices.json", {})
            devices[device_id] = {"hash": digest(token), "name": device_name, "revoked": False}
            # Consume first: a crash must never allow the same code to mint twice.
            pair["used"] = True
            self.write("pairing.json", pair)
            self.write("devices.json", devices)
            return device_id, token

    def authenticate(self, token):
        value = digest(token)
        with self.locked():
            for device_id, device in self.read("devices.json", {}).items():
                if hmac.compare_digest(device["hash"], value):
                    if device["revoked"]:
                        raise AuthRejected("revoked")
                    return device_id
        raise AuthRejected("unknown")

    def devices(self):
        with self.locked():
            return {key: {"name": val["name"], "revoked": val["revoked"]}
                    for key, val in self.read("devices.json", {}).items()}

    def revoke(self, device_id):
        with self.locked():
            devices = self.read("devices.json", {})
            if device_id not in devices:
                raise AuthRejected("unknown")
            devices[device_id]["revoked"] = True
            self.write("devices.json", devices)
