"""Cross-process, owner-only pairing and device credentials; plaintext never persists."""
from contextlib import contextmanager
import fcntl
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import tempfile
import time
import uuid

PAIR_TTL = 600
LOCAL_FILE = "local-pair.json"
ACCOUNT_FILE = "account.json"
MIN_PASSWORD = 8
SCRYPT_N = 2 ** 14
MAX_FAILURES = 5


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


ACCOUNT_ID = re.compile(r"[A-Za-z0-9._-]{3,64}")


def password_record(password):
    if not isinstance(password, str) or len(password) < MIN_PASSWORD or len(password) > 256:
        raise AuthRejected("weak_password")
    salt = secrets.token_bytes(16)
    value = hashlib.scrypt(password.encode(), salt=salt, n=SCRYPT_N, r=8, p=1, dklen=32)
    return {"salt": salt.hex(), "hash": value.hex(), "n": SCRYPT_N}


def password_matches(password, record):
    if not record or not isinstance(password, str) or len(password) > 256:
        return False
    value = hashlib.scrypt(password.encode(), salt=bytes.fromhex(record["salt"]), n=record["n"], r=8, p=1, dklen=32)
    return hmac.compare_digest(value.hex(), record["hash"])


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

    def consume_local(self, code):
        """True once for the code in the owner's 0600 file; the file then holds a fresh code."""
        with self.locked():
            pair = self.read("pairing.json", {})
            if not pair.get("local_hash") or not hmac.compare_digest(pair["local_hash"], digest(code)):
                return False
            pair.pop("local_hash")
            self.write("pairing.json", pair)
            self._rotate_local(pair, pair.get("local_port"))
            return True

    def _mint(self, device_name, devices=None):
        device_id, token = str(uuid.uuid4()), secrets.token_urlsafe(32)
        devices = self.read("devices.json", {}) if devices is None else devices
        devices[device_id] = {"hash": digest(token), "name": device_name, "revoked": False}
        self.write("devices.json", devices)
        return device_id, token

    # Owner account: one per airport. The first sign-up owns it; password reset needs Google or the airport Mac.

    def account_status(self):
        with self.locked():
            account = self.read(ACCOUNT_FILE, {})
            return {"account": bool(account.get("id")), "google": bool(account.get("google_sub"))}

    def signup(self, account_id, password, device_name, google=None):
        """First sign-up becomes the airport's owner; afterwards sign-up is closed."""
        with self.locked():
            if self.read(ACCOUNT_FILE, {}).get("id"):
                raise AuthRejected("exists")
            if not isinstance(account_id, str) or not ACCOUNT_ID.fullmatch(account_id):
                raise AuthRejected("bad_id")
            account = {"id": account_id, "password": password_record(password)}
            if google is not None:
                account["google_sub"], account["google_email"] = google
            self.write(ACCOUNT_FILE, account)
            return self._mint(device_name)

    def local_reset(self, password, device_name):
        """Airport Mac only (caller proved it): new password without the old one; every device signs out."""
        with self.locked():
            account = self.read(ACCOUNT_FILE, {})
            if not account.get("id"):
                raise AuthRejected("no_account")
            devices = self._reset(account, password)
            return self._mint(device_name, devices)

    def _reset(self, account, password):
        account["password"] = password_record(password)
        account.pop("failures", None)
        account.pop("locked_until", None)
        devices = self.read("devices.json", {})
        for device in devices.values():
            device["revoked"] = True
        self.write(ACCOUNT_FILE, account)
        return devices

    def _check_login(self, account, account_id, password):
        now = self.clock()
        if not account.get("id"):
            raise AuthRejected("no_account")
        if account.get("locked_until", 0) > now:
            raise AuthRejected("locked")
        same = hmac.compare_digest(account["id"].encode(), str(account_id).encode())
        if not (password_matches(password, account["password"]) and same):
            failures = [t for t in account.get("failures", []) if now - t < PAIR_TTL] + [now]
            account["failures"] = failures
            if len(failures) >= MAX_FAILURES:
                account["locked_until"] = now + PAIR_TTL
            self.write(ACCOUNT_FILE, account)
            raise AuthRejected("bad_login")
        account.pop("failures", None)

    def login(self, account_id, password, device_name):
        with self.locked():
            account = self.read(ACCOUNT_FILE, {})
            self._check_login(account, account_id, password)
            self.write(ACCOUNT_FILE, account)
            return self._mint(device_name)

    def google_login(self, google, device_name, new_password=None, link=None):
        """Sign in with the linked Google account; `link=(id, password)` links it first; `new_password` resets."""
        sub, email = google
        with self.locked():
            account = self.read(ACCOUNT_FILE, {})
            if link is not None:
                self._check_login(account, *link)
                account["google_sub"], account["google_email"] = sub, email
                self.write(ACCOUNT_FILE, account)
            if not account.get("google_sub"):
                raise AuthRejected("no_account" if not account.get("id") else "not_linked")
            if not hmac.compare_digest(account["google_sub"], sub):
                raise AuthRejected("bad_login")
            devices = self._reset(account, new_password) if new_password is not None else None
            return self._mint(device_name, devices)

    def pair(self, code, device_name):
        with self.locked():
            now = self.clock()
            pair = self.read("pairing.json", {})
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
