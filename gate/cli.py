"""Run with the Hermes Python environment: python -m gate.cli."""
import argparse
import json
from hermes_constants import get_hermes_home
from .auth import AuthStore, AuthRejected


def main(argv=None):
    parser = argparse.ArgumentParser(prog="hejo-gate")
    parser.add_argument("command", choices=["pair", "devices", "revoke", "status"])
    parser.add_argument("device_id", nargs="?")
    args = parser.parse_args(argv)
    store = AuthStore(get_hermes_home())
    if args.command == "pair":
        print(store.pair_code())
    elif args.command == "devices":
        print(json.dumps(store.devices(), ensure_ascii=False))
    elif args.command == "revoke":
        if not args.device_id:
            parser.error("revoke requires device_id")
        try:
            store.revoke(args.device_id)
        except AuthRejected as exc:
            parser.exit(1, exc.reason + "\n")
    else:
        # Reports credential state, not an unverified claim that a listener is alive.
        devices = store.devices()
        print(json.dumps({"devices": len(devices),
                          "active_devices": sum(not d["revoked"] for d in devices.values())}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
