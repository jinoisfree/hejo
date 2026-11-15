"""Run the hub: python -m hub --home DIR --port 47800 --listen 127.0.0.1 [--listen <tailscale ip>]."""
import argparse
import asyncio
import logging
import signal

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


def main(argv=None):
    parser = argparse.ArgumentParser(prog="hejo-hub")
    parser.add_argument("--home", required=True)
    parser.add_argument("--port", type=int, default=47800)
    parser.add_argument("--listen", action="append", default=[])
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    asyncio.run(serve(args.home, args.listen or ["127.0.0.1"], args.port))


if __name__ == "__main__":
    main()
