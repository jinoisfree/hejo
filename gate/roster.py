"""Read serving profiles; optional team-kit owns display metadata."""
from hermes_cli.profiles import profiles_to_serve


def employees(multiplex=True):
    try:
        from hermes_facility.team_registry import roster
    except ModuleNotFoundError as exc:
        if exc.name not in {"hermes_facility", "hermes_facility.team_registry"}:
            raise
        names = {}
    else:
        names = roster()
    return [{"id": profile, "name": names.get(profile, {}).get("name", profile),
             "aliases": list(names.get(profile, {}).get("aliases", [])), "avatar": None}
            for profile, home in profiles_to_serve(multiplex)]
