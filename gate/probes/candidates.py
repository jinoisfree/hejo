"""A/B experiments only. Remove or promote after the planning role decides."""
from gate.adapter import HejoAdapter
from gateway.config import Platform
from gateway.platforms.base import BasePlatformAdapter, SendResult
from hermes_cli.profiles import get_active_profile_name

hub = None
standalone_calls = []


class Forwarder(HejoAdapter):
    async def connect(self, *, is_reconnect=False):
        global hub
        if self._owner_profile:
            if hub is None:
                return False
            self._mark_connected()
            return True
        connected = await super().connect(is_reconnect=is_reconnect)
        if connected:
            hub = self
        return connected

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        if self._owner_profile:
            return await hub.send(chat_id, content, reply_to, {
                **(metadata or {}), "hermes_profile": self._owner_profile})
        return await super().send(chat_id, content, reply_to, metadata)

    async def disconnect(self):
        global hub
        if self._owner_profile:
            self._mark_disconnected()
        else:
            await super().disconnect()
            hub = None


class PrimaryOnly(HejoAdapter):
    async def connect(self, *, is_reconnect=False):
        global hub
        connected = await super().connect(is_reconnect=is_reconnect)
        if connected:
            hub = self
        return connected

    async def disconnect(self):
        global hub
        await super().disconnect()
        if hub is self:
            hub = None


async def standalone(config, chat_id, message, *, thread_id=None,
                     media_files=None, force_document=False):
    profile = get_active_profile_name() or "default"
    standalone_calls.append(profile)
    if hub is None:
        return {"error": "probe_hub_unavailable"}
    result = await hub.send(chat_id, message, metadata={
        "hermes_profile": profile, "thread_id": thread_id})
    return ({"success": True, "message_id": result.message_id}
            if result.success else {"error": result.error})


class PeerAdapter(BasePlatformAdapter):
    """Synthetic separate transport. No Slack SDK, real credentials or network."""
    def __init__(self, config):
        super().__init__(config, Platform("probe_peer"))
        self.sent = []

    async def connect(self, *, is_reconnect=False):
        self._mark_connected()
        return True

    async def disconnect(self):
        self._mark_disconnected()

    async def send(self, chat_id, content, reply_to=None, metadata=None):
        self.sent.append((chat_id, content))
        return SendResult(success=True, message_id="fixture-receipt")

    async def get_chat_info(self, chat_id):
        return {"name": "Fixture room", "type": "dm"}


def register(ctx):
    import os
    from gate import apply_yaml_config, check_requirements
    mode = os.environ["HEJO_PROBE_MODE"]
    ctx.register_platform(
        name="hejo", label="hejo probe", check_fn=check_requirements,
        adapter_factory=Forwarder if mode == "A" else PrimaryOnly,
        is_connected=lambda config: config.enabled,
        allowed_users_env="HEJO_ALLOWED_USERS", apply_yaml_config_fn=apply_yaml_config,
        max_message_length=65536, cron_deliver_env_var="HEJO_HOME_CHANNEL",
        standalone_sender_fn=standalone if mode == "B" else None,
        parse_target_ref_fn=lambda ref: (ref, None),
    )
    ctx.register_platform(
        name="probe_peer", label="Isolated peer", adapter_factory=PeerAdapter,
        check_fn=lambda: True, is_connected=lambda config: config.enabled,
        parse_target_ref_fn=lambda ref: (ref, None),
    )
