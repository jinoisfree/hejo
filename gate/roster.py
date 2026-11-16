"""Read serving profiles; optional team-kit owns display metadata."""
from hermes_cli.profiles import profiles_to_serve
from .pictures import profile_color, profile_picture


def profile_queued(home):
    """Read the same display block as BubbleReply.isQueued; never write profile settings."""
    try:
        lines = (home / "config.yaml").read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError):
        return False
    display = False
    for line in lines:
        if line.startswith("display:"):
            display = True
            continue
        if line and not line[0].isspace() and line[0] != "#":
            display = False
            continue
        if display and line.strip().startswith("busy_input_mode:"):
            value = line.strip()[len("busy_input_mode:"):].split("#", 1)[0]
            return value.strip(" \t\r\v\f\"'") == "queue"
    return False


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
                       "color": profile_color(home), "queued": profile_queued(home)})
    return result
