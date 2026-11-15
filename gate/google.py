"""Google sign-in for the owner account: the gate redeems the app's authorization code and checks the identity."""
import json
from pathlib import Path
from urllib.parse import urlsplit

import aiohttp

TOKEN_URL = "https://oauth2.googleapis.com/token"
INFO_URL = "https://oauth2.googleapis.com/tokeninfo"
ISSUERS = {"accounts.google.com", "https://accounts.google.com"}
CLIENT_FILE = "google-client.json"  # {"client_id", "client_secret"}, 0600, written by `gate.cli google`


class GoogleRejected(Exception):
    pass


def client(home):
    try:
        value = json.loads((Path(home) / "hejo" / CLIENT_FILE).read_text())
    except (FileNotFoundError, ValueError):
        return None
    if not isinstance(value, dict) or not value.get("client_id") or not value.get("client_secret"):
        return None
    return value


def loopback_redirect(uri):
    parts = urlsplit(uri)
    return parts.scheme == "http" and parts.hostname in {"127.0.0.1", "localhost"} and parts.port is not None


async def _post(url, data):
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
        async with session.post(url, data=data) as response:
            return response.status, await response.json(content_type=None)


async def _get(url, params):
    async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=10)) as session:
        async with session.get(url, params=params) as response:
            return response.status, await response.json(content_type=None)


async def identity(home, code, verifier, redirect_uri):
    """(sub, email) of the Google account that approved this sign-in; anything doubtful raises."""
    settings = client(home)
    if settings is None or not loopback_redirect(redirect_uri):
        raise GoogleRejected("not_configured")
    try:
        status, tokens = await _post(TOKEN_URL, {"code": code, "code_verifier": verifier, "redirect_uri": redirect_uri,
                                                 "client_id": settings["client_id"], "client_secret": settings["client_secret"],
                                                 "grant_type": "authorization_code"})
        if status != 200 or not tokens.get("id_token"):
            raise GoogleRejected("exchange")
        status, info = await _get(INFO_URL, {"id_token": tokens["id_token"]})
    except (aiohttp.ClientError, TimeoutError, ValueError, AttributeError) as exc:
        raise GoogleRejected("network") from exc
    if (status != 200 or info.get("aud") != settings["client_id"] or info.get("iss") not in ISSUERS
            or str(info.get("email_verified")).lower() != "true" or not info.get("sub")):
        raise GoogleRejected("identity")
    return str(info["sub"]), str(info.get("email", ""))
