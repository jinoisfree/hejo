"""Hermes platform plugin entry point."""
import importlib.util


def check_requirements():
    return all(importlib.util.find_spec(name) is not None for name in ("aiohttp", "jsonschema"))


def create_adapter(config):
    from .adapter import HejoAdapter
    return HejoAdapter(config)


def apply_yaml_config(yaml_cfg, platform_cfg):
    from gateway.platforms._shared import apply_yaml_bridge
    return apply_yaml_bridge(
        platform_cfg.get("extra", {}),
        [("allowed_users", "HEJO_ALLOWED_USERS", "csv")],
    )


def parse_target(ref):
    from .files import EMPLOYEE, ID
    # Room targets start a new thread; neither form accepts filesystem paths.
    valid = ID.fullmatch(ref[5:]) if ref.startswith('room:') else EMPLOYEE.fullmatch(ref)
    return (ref, None) if valid else None


def register(ctx):
    from .telegram import attach_telegram
    ctx.register_platform_handler("telegram", attach_telegram)
    from .discord import attach_discord
    ctx.register_platform_handler("discord", attach_discord)
    ctx.register_platform(
        name="hejo", label="hejo", adapter_factory=create_adapter,
        check_fn=check_requirements, allowed_users_env="HEJO_ALLOWED_USERS",
        apply_yaml_config_fn=apply_yaml_config,
        is_connected=lambda config: config.enabled,
        max_message_length=65536,
        cron_deliver_env_var="HEJO_DELIVERY_TARGET",
        parse_target_ref_fn=parse_target,
        validate_target_ref_fn=lambda ref: parse_target(ref) is not None,
    )
