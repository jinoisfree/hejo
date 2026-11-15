"""Owner-only (0700/0600) files for members, devices and Hermes links; plaintext passwords and tokens never persist."""
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

LOCK_WINDOW = 600
MAX_FAILURES = 5
MIN_PASSWORD = 8
SCRYPT_N = 2 ** 14
ACCOUNT_ID = re.compile(r"[A-Za-z0-9._-]{3,64}")
SETTINGS_BYTES = 16384


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


def password_record(password):
    if not isinstance(password, str) or len(password) < MIN_PASSWORD or len(password) > 256:
        raise Rejected("weak_password")
    salt = secrets.token_bytes(16)
    value = hashlib.scrypt(password.encode(), salt=salt, n=SCRYPT_N, r=8, p=1, dklen=32)
    return {"salt": salt.hex(), "hash": value.hex(), "n": SCRYPT_N}


def password_matches(password, record):
    if not record or not isinstance(password, str) or len(password) > 256:
        return False
    value = hashlib.scrypt(password.encode(), salt=bytes.fromhex(record["salt"]), n=record["n"], r=8, p=1, dklen=32)
    return hmac.compare_digest(value.hex(), record["hash"])


class Rejected(Exception):
    def __init__(self, reason):
        self.reason = reason
        super().__init__(reason)


class HubStore:
    def __init__(self, home, clock=time.time):
        self.path = Path(home)
        self.clock = clock

    @contextmanager
    def locked(self):
        self.path.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(self.path, 0o700)
        fd = os.open(self.path / ".lock", os.O_CREAT | os.O_RDWR, 0o600)
        try:
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
        fd, tmp = tempfile.mkstemp(prefix=".hub-", dir=self.path)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(data, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(tmp, self.path / name)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    # Members ----------------------------------------------------------------------------------------------

    def _members(self):
        return self.read("members.json", {})

    def _by_login(self, members, account_id):
        return next((key for key, m in members.items() if hmac.compare_digest(m["id"].encode(), str(account_id).encode())), None)

    def _mint(self, member, device_name):
        device_id, token = str(uuid.uuid4()), secrets.token_urlsafe(32)
        devices = self.read("devices.json", {})
        devices[device_id] = {"hash": digest(token), "member": member, "name": str(device_name)[:100], "revoked": False}
        self.write("devices.json", devices)
        return {"device_id": device_id, "token": token}

    def _sign_out_all(self, member):
        devices = self.read("devices.json", {})
        for device in devices.values():
            if device["member"] == member:
                device["revoked"] = True
        self.write("devices.json", devices)

    def signup(self, account_id, password, device_name, google=None):
        with self.locked():
            members = self._members()
            if not isinstance(account_id, str) or not ACCOUNT_ID.fullmatch(account_id):
                raise Rejected("bad_id")
            if self._by_login(members, account_id) is not None:
                raise Rejected("exists")
            if google is not None and any(m.get("google_sub") == google[0] for m in members.values()):
                raise Rejected("google_in_use")
            member = str(uuid.uuid4())
            members[member] = {"id": account_id, "password": password_record(password), "settings": {}}
            if google is not None:
                members[member]["google_sub"], members[member]["google_email"] = google
            self.write("members.json", members)
            return self._mint(member, device_name)

    def _check(self, members, account_id, password):
        now = self.clock()
        member = self._by_login(members, account_id)
        record = members.get(member, {})
        if record.get("locked_until", 0) > now:
            raise Rejected("locked")
        if member is None or not password_matches(password, record.get("password")):
            if member is not None:
                failures = [t for t in record.get("failures", []) if now - t < LOCK_WINDOW] + [now]
                record["failures"] = failures
                if len(failures) >= MAX_FAILURES:
                    record["locked_until"] = now + LOCK_WINDOW
                self.write("members.json", members)
            raise Rejected("bad_login")
        record.pop("failures", None)
        return member

    def login(self, account_id, password, device_name):
        with self.locked():
            members = self._members()
            member = self._check(members, account_id, password)
            self.write("members.json", members)
            return self._mint(member, device_name)

    def google_login(self, google, device_name, new_password=None, link=None):
        sub, email = google
        with self.locked():
            members = self._members()
            if link is not None:
                member = self._check(members, *link)
                if any(m.get("google_sub") == sub for key, m in members.items() if key != member):
                    raise Rejected("google_in_use")
                members[member]["google_sub"], members[member]["google_email"] = sub, email
                self.write("members.json", members)
            member = next((key for key, m in members.items() if m.get("google_sub") and hmac.compare_digest(m["google_sub"], sub)), None)
            created = None
            if member is None:
                # First Google sign-in creates the member, as other apps do. No password until the member sets one.
                created = self._google_account_id(members, email)
                member = str(uuid.uuid4())
                members[member] = {"id": created, "password": None, "settings": {}, "google_sub": sub, "google_email": email}
                self.write("members.json", members)
            if new_password is not None:
                self._reset(members, member, new_password)
            return {**self._mint(member, device_name), "account": members[member]["id"], "created": created is not None}

    @staticmethod
    def _google_account_id(members, email):
        base = re.sub(r"[^A-Za-z0-9._-]", "", str(email).split("@")[0])[:56] or "member"
        base = base if len(base) >= 3 else (base + "-hejo")[:56]
        taken = {m["id"].lower() for m in members.values()}
        candidate, n = base, 2
        while candidate.lower() in taken:
            candidate, n = f"{base}-{n}", n + 1
        return candidate

    def _reset(self, members, member, password):
        members[member]["password"] = password_record(password)
        members[member].pop("failures", None)
        members[member].pop("locked_until", None)
        self.write("members.json", members)
        self._sign_out_all(member)

    # Devices ----------------------------------------------------------------------------------------------

    def device(self, token):
        """(device_id, member) for a live token; raises otherwise."""
        value = digest(token) if isinstance(token, str) else ""
        with self.locked():
            for device_id, device in self.read("devices.json", {}).items():
                if hmac.compare_digest(device["hash"], value):
                    if device["revoked"]:
                        raise Rejected("revoked")
                    return device_id, device["member"]
        raise Rejected("unknown")

    def devices(self):
        with self.locked():
            return {key: {"name": d["name"], "revoked": d["revoked"]} for key, d in self.read("devices.json", {}).items()}

    def revoke(self, device_id):
        with self.locked():
            devices = self.read("devices.json", {})
            if device_id not in devices:
                raise Rejected("unknown")
            devices[device_id]["revoked"] = True
            self.write("devices.json", devices)

    # Per-member app settings and the member's own Hermes ------------------------------------------------------

    def me(self, member):
        with self.locked():
            record = self._members().get(member) or {}
            gate = self.read("gates.json", {}).get(member)
            return {"account": record.get("id"), "google": bool(record.get("google_sub")), "settings": record.get("settings", {}),
                    "gate": {"port": gate["port"]} if gate and gate.get("port") else None}

    def save_settings(self, member, settings):
        if not isinstance(settings, dict) or len(json.dumps(settings)) > SETTINGS_BYTES:
            raise Rejected("bad_settings")
        with self.locked():
            members = self._members()
            members[member]["settings"] = settings
            self.write("members.json", members)

    def link(self, account_id, password):
        """A member's Hermes (run in that member's Mac account) proves the member and gets its gate key."""
        with self.locked():
            members = self._members()
            member = self._check(members, account_id, password)
            self.write("members.json", members)
            key = secrets.token_urlsafe(32)
            gates = self.read("gates.json", {})
            gates[member] = {"key": digest(key), "port": None}
            self.write("gates.json", gates)
            return key

    def operator_link(self, account_id):
        """Gate key for a member without their password: only the Mac account that owns the hub data can do this."""
        with self.locked():
            members = self._members()
            member = self._by_login(members, account_id)
            if member is None:
                raise Rejected("no_member")
            key = secrets.token_urlsafe(32)
            gates = self.read("gates.json", {})
            gates[member] = {"key": digest(key), "port": None}
            self.write("gates.json", gates)
            return key

    def gate(self, key):
        value = digest(key) if isinstance(key, str) else ""
        with self.locked():
            for member, gate in self.read("gates.json", {}).items():
                if hmac.compare_digest(gate["key"], value):
                    return member
        raise Rejected("unknown_gate")

    def register(self, member, port):
        if not isinstance(port, int) or not 1 <= port <= 65535:
            raise Rejected("bad_port")
        with self.locked():
            gates = self.read("gates.json", {})
            gates[member]["port"] = port
            self.write("gates.json", gates)

    def gate_reset(self, member, password, device_name):
        """Reset requested by the member's own Hermes after the airport-Mac proof; every device signs out."""
        with self.locked():
            members = self._members()
            self._reset(members, member, password)
            return self._mint(member, device_name)
