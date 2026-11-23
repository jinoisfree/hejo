import pytest
from types import SimpleNamespace
from unittest.mock import AsyncMock
from gate.tests.support import airport, registered, gate
from gate.tests.test_telegram_comments import native, finish_probe, dispatch
from gate import telegram as door
pytestmark = pytest.mark.asyncio

async def test_bound_topic_is_not_modified(native, monkeypatch):
    await finish_probe(native)
    bridge = native.bridge
    with bridge.settings_store.locked():
        bridge.settings_store.write('topics.json', {'tag': '12345678', 'topics': {'default': {'topic': '8', 'name': 'Fixture', 'closed': False}}})
    bot = SimpleNamespace(close_forum_topic=AsyncMock(), reopen_forum_topic=AsyncMock(), edit_forum_topic=AsyncMock())
    monkeypatch.setattr(door, '_telegram', SimpleNamespace(is_connected=True, _bot=bot))
    monkeypatch.setattr(bridge, 'rooms', lambda: {'default': 'Fixture'})
    await dispatch(native, text='/hejo_comments_bind default')
    await bridge.sync_topics()
    assert bot.close_forum_topic.await_count == 0, 'bound topic must remain unchanged'

async def test_busy_command_reports_reason(native):
    await finish_probe(native)
    native.bridge.incoming['default'] = 1
    native.api.calls.clear()
    await dispatch(native, text='/hejo_comments_bind default')
    sends = [args for method,args in native.api.calls if method == 'sendMessage']
    assert sends, 'authorized owner must receive busy result'
