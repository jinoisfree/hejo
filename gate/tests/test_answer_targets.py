"""AT87: reply targets are durable server output, never an owner-supplied send field."""
import uuid

import pytest
from jsonschema import Draft202012Validator
from gate.server import SCHEMA
from gate.tests.support import wait_for_turns


@pytest.mark.asyncio
async def test_targeted_click_survives_journal_recovery_and_reconnect(gate, client, runner, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    thread = str(uuid.uuid4())
    metadata = {'thread_id': thread, 'hejo_reply_state': 'asked',
                'hejo_buttons': [{'label': '승인', 'style': 'default'}, {'label': '거절', 'style': 'default'}]}
    a = await gate.send('alpha', '항목 A', metadata=metadata)
    b = await gate.send('alpha', '항목 B', metadata=metadata)
    await gate.set_reply_state(a.message_id, 'answered')
    assert gate.journal.message(b.message_id)['reply_state'] == 'asked'
    ws, _ = await client.pair(since=gate.journal.head)
    await client.read(ws)  # sync_done at the current head
    await ws.send_json({'v': 1, 'type': 'click', 'id': str(uuid.uuid4()), 'msg_id': a.message_id,
                       'button_id': gate.journal.message(a.message_id)['buttons'][0]['id']})
    reply = await client.read(ws)
    assert reply['role'] == 'owner' and reply['text'] == '승인'
    assert reply['answer_to'] == a.message_id
    await wait_for_turns(runner, 1)
    assert runner.events[0].raw_message['_hermes_button']['message_id'] == a.message_id
    await client.send(ws, thread=thread, text='승인')
    typed = (await client.until(ws, 'message'))[-1]
    assert typed['text'] == reply['text'] and 'answer_to' not in typed
    head = gate.journal.head
    forged = {'v': 1, 'type': 'send', 'id': str(uuid.uuid4()), 'employee': 'alpha', 'thread': thread,
              'client_msg_id': str(uuid.uuid4()), 'text': '승인', 'answer_to': b.message_id}
    validator = Draft202012Validator(SCHEMA)
    assert not validator.is_valid(forged)
    await ws.send_json(forged)
    assert (await client.until(ws, 'error'))[-1]['code'] == 'invalid_frame'
    assert gate.journal.head == head
    await ws.close()
    gate.journal.close()
    gate.journal.open()
    assert next(r for r in gate.journal.page(0) if r.get('msg_id') == reply['msg_id']) == reply
    ws, _ = await client.pair(since=0)
    replay = await client.until(ws, 'sync_done')
    assert next(r for r in replay if r.get('msg_id') == reply['msg_id']) == reply
    assert next(r for r in replay if r.get('msg_id') == typed['msg_id']) == typed
    await ws.close()
