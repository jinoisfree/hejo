"""Read serving profiles; optional team-kit owns display metadata."""
from hermes_cli.profiles import profiles_to_serve
from .pictures import profile_color, profile_picture


def employees(multiplex=True):
    try:
        from hermes_facility.team_registry import roster
    except ModuleNotFoundError as exc:
        if exc.name not in {"hermes_facility", "hermes_facility.team_registry"}:
            raise
        names = {}
    else:
        names = roster()
    result = []
    for profile, home in profiles_to_serve(multiplex):
        picture = profile_picture(home)
        result.append({"id": profile, "name": names.get(profile, {}).get("name", profile),
                       "aliases": list(names.get(profile, {}).get("aliases", [])),
                       "avatar": f"/v1/pictures/employee/{profile}?v={picture.stat().st_mtime_ns}" if picture else None,
                       "avatar_custom": picture is not None and picture.name == "avatar.png",
                       "color": profile_color(home)})
    return result
