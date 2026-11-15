"""Run the hub: python -m hub --home DIR --port 47800 --listen 127.0.0.1 [--listen <tailscale ip>].
Operator link (hub owner's Mac account only): python -m hub --home DIR --link ACCOUNT --hermes-home HERMES_HOME"""
import argparse
import asyncio
import json
import logging
import os
from pathlib import Path
import signal
import tempfile

from .server import Hub


async def serve(home, listen, port):
    hub = Hub(home)
    await hub.start(listen, port)
    logging.getLogger("hub").info("hub listening on %s:%s", ",".join(listen), hub.port)
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)
    await stop.wait()
    await hub.stop()


def link(home, account, hermes_home, port):
    from .store import HubStore, Rejected
    if not hermes_home:
        raise SystemExit("--hermes-home is required with --link")
    try:
        key = HubStore(home).operator_link(account)
    except Rejected as exc:
        print(f"hub_link_failed {exc.reason}")
        return 1
    directory = Path(hermes_home) / "hejo"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory)
    with os.fdopen(fd, "w") as stream:
        json.dump({"url": f"http://127.0.0.1:{port}", "gate_key": key}, stream)
    os.replace(tmp, directory / "hub.json")
    print("linked; restart that Hermes gateway")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(prog="hejo-hub")
    parser.add_argument("--home", required=True)
    parser.add_argument("--port", type=int, default=47800)
    parser.add_argument("--listen", action="append", default=[])
    parser.add_argument("--link", metavar="ACCOUNT", help="link a member's Hermes on this Mac account without a password")
    parser.add_argument("--hermes-home")
    args = parser.parse_args(argv)
    if args.link:
        return link(args.home, args.link, args.hermes_home, args.port)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    asyncio.run(serve(args.home, args.listen or ["127.0.0.1"], args.port))


if __name__ == "__main__":
    raise SystemExit(main())
