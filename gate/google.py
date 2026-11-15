"""Google sign-in for the owner account. The app signs in with hejo's shared desktop OAuth client and sends the
ID token; the gate asks Google to verify it and accepts it only for that client (or a locally configured one)."""
import json
from pathlib import Path

import aiohttp

INFO_URL = "https://oauth2.googleapis.com/tokeninfo"
ISSUERS = {"accounts.google.com", "https://accounts.google.com"}
SHARED = Path(__file__).resolve().parent.parent / "config" / "google-oauth.json"
CLIENT_FILE = "google-client.json"  # optional per-airport override {"client_id"}, written by `gate.cli google`


class GoogleRejected(Exception):
    pass


def _client_id(path):
    try:
        value = json.loads(Path(path).read_text())
    except (FileNotFoundError, ValueError):
        return None
    return value.get("client_id") or None if isinstance(value, dict) else None


def client_id(home):
    return _client_id(Path(home) / "hejo" / CLIENT_FILE) or _client_id(SHARED)


async def _get(url, params):
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
        async with session.get(url, params=params) as response:
            return response.status, await response.json(content_type=None)


async def identity(home, id_token):
    """(sub, email) of the verified Google account; anything doubtful raises."""
    expected = client_id(home)
    if not expected or not isinstance(id_token, str):
        raise GoogleRejected("not_configured")
    try:
        status, info = await _get(INFO_URL, {"id_token": id_token})
    except (aiohttp.ClientError, TimeoutError, ValueError) as exc:
        raise GoogleRejected("network") from exc
    if (status != 200 or not isinstance(info, dict) or info.get("aud") != expected or info.get("iss") not in ISSUERS
            or str(info.get("email_verified")).lower() != "true" or not info.get("sub")):
        raise GoogleRejected("identity")
    return str(info["sub"]), str(info.get("email", ""))
