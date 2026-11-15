"""Is a Tailscale peer one of the gate owner's own devices? Asks the local tailscale CLI; any doubt is a no."""
import asyncio
import json
import shutil

CANDIDATES = ("/opt/homebrew/bin/tailscale", "/usr/local/bin/tailscale",
              "/Applications/Tailscale.app/Contents/MacOS/Tailscale")


def binary():
    found = shutil.which("tailscale")
    if found:
        return found
    for path in CANDIDATES:
        if shutil.which(path):
            return path
    return None


async def _json(*args, timeout=3):
    tool = binary()
    if tool is None:
        return None
    process = await asyncio.create_subprocess_exec(tool, *args, stdout=asyncio.subprocess.PIPE,
                                                   stderr=asyncio.subprocess.DEVNULL)
    try:
        out, _ = await asyncio.wait_for(process.communicate(), timeout)
    except asyncio.TimeoutError:
        process.kill()
        return None
    if process.returncode != 0:
        return None
    try:
        return json.loads(out)
    except ValueError:
        return None


async def owner_device(address):
    """(True, device name) only when the peer's user is the same tailnet user as this Mac."""
    status, whois = await _json("status", "--json"), await _json("whois", "--json", address)
    try:
        mine = status["Self"]["UserID"]
        theirs = whois["UserProfile"]["ID"]
        name = whois["Node"].get("ComputedName") or whois["Node"].get("Name") or "Tailscale device"
    except (TypeError, KeyError, AttributeError):
        return False, None
    if not isinstance(mine, int) or mine != theirs:
        return False, None
    return True, str(name)[:100]
