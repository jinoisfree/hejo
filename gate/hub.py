"""This gate's link to the hejo hub: members sign in at the hub, and the gate checks app tokens with it.
`<HOME>/hejo/hub.json` (0600) holds the hub URL and this member's gate key, written by `hejo-install --hub`."""
import json
import logging
import time
from pathlib import Path

import aiohttp

from .auth import AuthRejected, digest

log = logging.getLogger(__name__)
HUB_FILE = "hub.json"
CACHE_SECONDS = 30


class HubLink:
    def __init__(self, home=None, clock=time.monotonic):
        """`home=None` is a disabled link (gate not joined to a hub)."""
        try:
            value = json.loads((Path(home) / "hejo" / HUB_FILE).read_text()) if home is not None else None
        except (FileNotFoundError, ValueError):
            value = None
        ok = isinstance(value, dict) and value.get("url") and value.get("gate_key")
        self.url, self.key = (value["url"].rstrip("/"), value["gate_key"]) if ok else (None, None)
        self.clock = clock
        self.cache = {}

    @property
    def enabled(self):
        return self.url is not None

    async def call(self, path, body):
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as session:
            async with session.post(self.url + path, json=body, headers={"Authorization": "Gate " + self.key}) as response:
                return response.status, await response.json(content_type=None)

    async def verify(self, token, fresh=False):
        """Device id of a hub-issued token for this gate's member; AuthRejected otherwise."""
        key = digest(token)
        cached = self.cache.get(key)
        if cached and not fresh and self.clock() - cached[1] < CACHE_SECONDS:
            return cached[0]
        try:
            status, body = await self.call("/v1/gate/verify", {"token": token})
        except (aiohttp.ClientError, TimeoutError, ValueError):
            raise AuthRejected("unknown") from None
        if status != 200 or not isinstance(body, dict) or not body.get("device_id"):
            self.cache.pop(key, None)
            raise AuthRejected("revoked" if isinstance(body, dict) and body.get("error") == "revoked" else "unknown")
        self.cache[key] = (body["device_id"], self.clock())
        return body["device_id"]

    async def register(self, port):
        status, _ = await self.call("/v1/gate/register", {"port": port})
        return status == 200

    async def reset(self, password, device_name):
        try:
            status, body = await self.call("/v1/gate/reset", {"password": password, "device_name": device_name})
        except (aiohttp.ClientError, TimeoutError, ValueError):
            raise AuthRejected("hub_unavailable") from None
        if status != 200:
            raise AuthRejected(body.get("error", "unknown") if isinstance(body, dict) else "unknown")
        return body["device_id"], body["token"]
