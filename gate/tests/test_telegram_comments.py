"""Shared comments: actual PTB dispatch, journal and file stores with Bot API transport substituted."""
import asyncio
import inspect
import uuid
import json
from types import SimpleNamespace

import pytest
import pytest_asyncio
from telegram import Update
from telegram.ext import Application, TypeHandler
from telegram.request import BaseRequest

from gate.telegram_comments import Comments, Rejected
from gate import telegram as door

pytestmark = pytest.mark.asyncio


class BotAPI(BaseRequest):
    def __init__(self):
        self.calls = []
        self.extra_admin = False
        self.public = False
        self.fail_send = False
        self.before_send = None
        self.next_message = 40
        self.transform = None

    @property
    def read_timeout(self):
        return 5

    async def initialize(self):
        pass

    async def shutdown(self):
        pass

    async def do_request(self, url, method, request_data=None, **kwargs):
        action = url.rsplit('/', 1)[-1]
        args = request_data.parameters if request_data else {}
        self.calls.append((action, args))
        if action == 'getMe':
            result = dict(id=900, is_bot=True, first_name='Fixture', username='fixture_bot')
        elif action == 'getChat':
            chat = int(args['chat_id'])
            result = dict(id=chat, type='channel' if chat in {-1000000000200, -1000000000201} else 'supergroup',
                          title='Fixture', accent_color_id=0, max_reaction_count=1,
                          linked_chat_id=chat - 100 if chat in {-1000000000200, -1000000000201} else chat + 100, is_forum=False)
            if self.public:
                result['username'] = 'fixture_public'
        elif action == 'getChatAdministrators':
            assert args['return_bots'] is True
            result = [dict(status='creator', user=dict(id=100, is_bot=False, first_name='Owner'),
                           is_anonymous=False),
                      dict(status='administrator', user=dict(id=900, is_bot=True, first_name='Bot'),
                           can_be_edited=False, is_anonymous=False, can_manage_chat=True,
                           can_delete_messages=True, can_manage_video_chats=True,
                           can_restrict_members=True, can_promote_members=False, can_change_info=True,
                           can_invite_users=True, can_post_stories=False, can_edit_stories=False,
                           can_delete_stories=False, can_post_messages=True)]
            if self.extra_admin:
                result.append(dict(status='creator', user=dict(id=101, is_bot=False, first_name='Other'),
                                   is_anonymous=False))
        elif action == 'sendChatAction':
            result = True
        elif action in {'sendMessage', 'sendPhoto', 'sendDocument', 'editMessageText'}:
            if self.before_send:
                result = self.before_send(args)
                if inspect.isawaitable(result):
                    await result
            if self.fail_send:
                raise OSError('fixture failure')
            self.next_message += 1
            result = dict(message_id=self.next_message, date=1001, text=args.get('text', ''),
                          chat=dict(id=int(args['chat_id']), type='supergroup'))
        else:
            raise AssertionError(action)
        if self.transform:
            result = self.transform(action, args, result)
        return 200, json.dumps(dict(ok=True, result=result)).encode()


@pytest_asyncio.fixture
async def native(gate, monkeypatch):
    monkeypatch.setenv('HEJO_ALLOWED_USERS', 'owner')
    api = BotAPI()
    app = Application.builder().token('900:fixture').request(api).get_updates_request(BotAPI()).build()
    await app.initialize()
    bridge = gate.telegram
    now = [1000.0]
    bridge.clock = lambda: now[0]
    bridge.vault.clock = bridge.clock
    with bridge.vault.locked():
        bridge.vault.write('telegram.json', dict(pair=dict(platform='telegram', chat_id='-1000000000100',
            user_id='100', tag='12345678', paired_at=1), code=None))
    with bridge.settings_store.locked():
        bridge.settings_store.write('settings.json', {'enabled': True})
    # Test the same factory used by Hermes; its first group handler consumes managed updates.
    transport = SimpleNamespace(handle_message=None, is_connected=False)
    door.attach_telegram(app, transport)
    monkeypatch.setattr(door, '_telegram', transport)
    core, observed = [], []

    async def original(update, context):
        core.append(update.update_id)

    async def observer(update, context):
        observed.append(update.update_id)

    app.add_handler(TypeHandler(Update, original), group=0)
    app.add_handler(TypeHandler(Update, observer), group=99)
    yield SimpleNamespace(app=app, api=api, bridge=bridge, now=now, core=core, observed=observed)
    await app.shutdown()


def update(native, text='hello', chat=-1000000000300, user=100, edit=False, forward=None):
    data = dict(message_id=7, date=1000, chat=dict(id=chat, type='supergroup'),
                from_user=None, text=text)
    data.pop('from_user')
    data['from'] = dict(id=user, is_bot=False, first_name='Fixture')
    if forward:
        data.update(is_automatic_forward=True, sender_chat=dict(id=chat + 100, type='channel', title='Fixture'),
                    forward_origin=dict(type='channel', date=1000,
                        chat=dict(id=chat + 100, type='channel', title='Fixture'), message_id=forward))
    return Update.de_json(dict(update_id=10, **{'edited_message' if edit else 'message': data}), native.app.bot)


async def dispatch(native, **kwargs):
    await native.app.process_update(update(native, **kwargs))


async def finish_probe(native):
    await dispatch(native, text='/hejo_comments_probe default')
    probe = native.bridge.private()['probes'][-1]
    root = native.bridge.comments.receipts[probe['tag'], 'channel']['message_id']
    await dispatch(native, forward=root)
    return native.bridge.private()['probes'][-1]


async def test_probe_reserves_before_send_dispatch_consumes_and_bind(native, gate):
    initial = list(gate.journal.records)
    def reserved(args):
        assert native.bridge.private()['probes'][-1]['probe_reserved'] is True
        assert native.bridge.comments.claims(update(native))
    native.api.before_send = reserved
    probe = await finish_probe(native)
    assert probe['state'] == 'complete'
    assert native.core == [] and len(native.observed) == 2
    sends = [args for method, args in native.api.calls if method == 'sendMessage']
    assert len(sends) == 3
    assert sends[1]['text'].startswith('probe_started:')
    assert sends[2]['reply_parameters']['message_id'] == 7
    assert sends[2]['reply_parameters']['allow_sending_without_reply'] is False
    assert 'message_thread_id' not in sends[2]
    await dispatch(native)
    await dispatch(native, edit=True)
    assert gate.journal.records == initial and native.core == []
    assert native.bridge.comments.route('default') == 'topic'
    native.now[0] += 10000
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'comments'
    binding = native.bridge.private()['comments'][0]
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.private()['comments'] == [binding]
    assert native.bridge.comments.route('alpha') == 'topic'
    assert native.bridge.private()['route_epochs']['default']['cutover_seq'] == gate.journal.head
    assert gate.journal.records == initial


@pytest.mark.parametrize('state', ['pending', 'complete', 'unknown', 'cancelled', 'timed_out'])
async def test_reservation_survives_restart_disabled_unpair(native, state):
    await dispatch(native, text='/hejo_comments_probe default')
    tag = native.bridge.private()['probes'][-1]['tag']
    native.bridge.comments.write_probe(tag, state=state)
    await native.bridge.comments.close()
    native.bridge.comments = Comments(native.bridge)
    with native.bridge.vault.locked():
        value = native.bridge.private()
        value['pair'] = None
        native.bridge.vault.write('telegram.json', value)
    with native.bridge.settings_store.locked():
        native.bridge.settings_store.write('settings.json', {'enabled': False})
    for edit in (False, True):
        await dispatch(native, edit=edit)
        await dispatch(native, forward=41, edit=edit)
    assert native.core == []
    assert len(native.observed) == 5
    await dispatch(native, chat=-1000000000999)
    assert native.core == [10]


@pytest.mark.parametrize('invalid', ['public', 'extra_admin', 'wrong_owner', 'missing_receipts'])
async def test_invalid_bind_leaves_vault_unchanged(native, invalid):
    before = native.bridge.private()
    native.api.public = invalid == 'public'
    native.api.extra_admin = invalid == 'extra_admin'
    await dispatch(native, text='/hejo_comments_bind default', user=101 if invalid == 'wrong_owner' else 100)
    assert native.bridge.private() == before
    assert native.bridge.comments.route('default') == 'topic'
    sends = [args for method, args in native.api.calls if method == 'sendMessage']
    assert len(sends) == (0 if invalid == 'wrong_owner' else 1)
    if sends:
        assert sends[0]['text'].startswith(('rejected:', 'permission_failed:', 'probe_required:'))


async def test_deadline_late_receipt_retry_and_complete_timer(native):
    await dispatch(native, text='/hejo_comments_probe default')
    old = native.bridge.private()['probes'][-1]
    native.now[0] = old['deadline'] + 1
    await dispatch(native, forward=41)
    assert native.bridge.private()['probes'][-1]['state'] == 'timed_out'
    await dispatch(native, text='/hejo_comments_probe default')
    new = native.bridge.private()['probes'][-1]
    assert new['tag'] != old['tag']
    await dispatch(native, forward=41)
    assert native.bridge.private()['probes'][-1]['state'] == 'pending'
    await dispatch(native, forward=native.bridge.comments.receipts[new['tag'], 'channel']['message_id'])
    assert native.bridge.private()['probes'][-1]['state'] == 'complete'
    native.now[0] = new['deadline'] + 100
    await native.bridge.comments.expire(new['tag'], new['deadline'])
    assert native.bridge.private()['probes'][-1]['state'] == 'complete'


async def test_failed_send_keeps_reservation(native):
    native.api.fail_send = True
    await dispatch(native, text='/hejo_comments_probe default')
    assert native.bridge.private()['probes'][-1]['state'] == 'unknown'
    await dispatch(native)
    assert native.core == []


async def test_busy_bind_and_corrupt_receipt_close_comments(native):
    await finish_probe(native)
    native.bridge.adapter._typing_threads['default'] = {('default', 'fixture-thread')}
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'topic'
    native.bridge.adapter._typing_threads.clear()
    with native.bridge.sent_path.open('ab') as stream:
        stream.write(b'{broken}\n')
    await native.bridge.comments.close()
    native.bridge.comments = Comments(native.bridge)
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.damaged
    assert native.bridge.comments.route('default') == 'topic'
    assert native.core == []


@pytest.mark.parametrize('fault', ['forum', 'link', 'owner', 'bot_missing', 'post_permission', 'api_error'])
async def test_permissions_reject_without_reserving(native, fault):
    before = native.bridge.private()
    def mutate(action, args, result):
        if action == 'getChat':
            if fault == 'api_error':
                raise OSError('fixture')
            if fault == 'forum' and result['type'] == 'supergroup':
                result['is_forum'] = True
            if fault == 'link' and result['type'] == 'channel':
                result['linked_chat_id'] = -1000000000999
        if action == 'getChatAdministrators':
            if fault == 'owner':
                result[0]['user']['id'] = 101
            if fault == 'bot_missing':
                result.pop()
            if fault == 'post_permission':
                result[1]['can_post_messages'] = False
        return result
    native.api.transform = mutate
    await dispatch(native, text='/hejo_comments_probe default')
    assert native.bridge.private() == before
    sends = [args for action, args in native.api.calls if action == 'sendMessage']
    assert len(sends) == 1
    assert sends[0]['text'].startswith(('rejected:', 'permission_failed:'))


async def test_privileges_revoked_pause_bound_route(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default')
    native.api.extra_admin = True
    count = len(native.api.calls)
    await dispatch(native)
    assert native.bridge.comments.route('default') == 'paused'
    assert native.core == []
    assert not any(action == 'sendMessage' for action, _ in native.api.calls[count:])


async def test_receipt_integrity_and_identity_required(native):
    probe = await finish_probe(native)
    identity = {key: probe[key] for key in ('bot_id', 'channel_id', 'discussion_id', 'owner_id', 'pair', 'room', 'contract')}
    saved = native.bridge.comments.receipts.pop((probe['tag'], 'forward'))
    with pytest.raises(Rejected, match='probe_required'):
        await native.bridge.comments.bind(identity)
    native.bridge.comments.receipts[probe['tag'], 'forward'] = saved
    for key in ('bot_id', 'contract'):
        with pytest.raises(Rejected, match='probe_required'):
            await native.bridge.comments.bind({**identity, key: 'different'})
    with pytest.raises(Rejected, match='pair_changed'):
        await native.bridge.comments.bind({**identity, 'pair': 'different'})


async def test_incoming_and_gateway_session_are_busy(native):
    probe = await finish_probe(native)
    native.bridge.incoming['default'] = 1
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'topic'
    native.bridge.incoming.clear()
    gate = native.bridge.adapter
    gate.journal.message_threads['fixture-message'] = ('default', 'fixture-thread')
    source = gate.build_source(chat_id='default', chat_type='dm', user_id='owner', thread_id='fixture-thread')
    source.profile = 'default'
    gate._active_sessions[gate._source_session_key(source)] = asyncio.Event()
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'topic'
    gate._active_sessions.clear()
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'comments'


async def test_native_rebuild_installs_handler_despite_wrapped_adapter(native):
    transport = door._telegram
    other = Application.builder().token('900:fixture').request(BotAPI()).get_updates_request(BotAPI()).build()
    door.attach_telegram(other, transport)
    assert len(other.handlers[0]) == 1
    await dispatch(native, text='/hejo_comments_probe default')
    assert other.handlers[0][0].check_update(update(native))


async def test_rooms_only_owner_and_pair_group(native):
    await dispatch(native, text='/hejo_comments_rooms', chat=-1000000000100, user=101)
    assert not any(action == 'sendMessage' for action, _ in native.api.calls)
    await dispatch(native, text='/hejo_comments_rooms', chat=-1000000000100)
    texts = [args['text'] for action, args in native.api.calls if action == 'sendMessage']
    assert len(texts) == 1 and 'default:' in texts[0]


async def test_unsupported_endpoint_does_not_query_or_reserve(native):
    bot = SimpleNamespace(base_url='https://invalid.example/botfixture')
    with pytest.raises(Rejected, match='unsupported_endpoint'):
        await native.bridge.comments.validate(bot, '-1000000000300', 'default', native.bridge.private()['pair'])
    assert 'probes' not in native.bridge.private()


async def test_startup_without_primary_still_consumes_reserved_updates(native, monkeypatch):
    from gate import adapter
    await dispatch(native, text='/hejo_comments_probe default')
    monkeypatch.setattr(adapter, '_primary', None)
    await dispatch(native)
    await dispatch(native, edit=True)
    assert native.core == []
    await dispatch(native, chat=-1000000000999)
    assert native.core == [10]


async def test_actual_unpair_preserves_probe_and_retires_binding(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default')
    before = native.bridge.private()['probes']
    conn = SimpleNamespace(features={'telegram'})
    await native.bridge.command(dict(type='telegram_unpair', id='fixture'), conn)
    value = native.bridge.private()
    assert value['pair'] is None and value['probes'] == before
    assert value['comments'][0]['state'] == 'retired'
    await dispatch(native)
    assert native.core == []


async def test_vault_old_missing_fields_and_bad_type(native):
    with native.bridge.vault.locked():
        native.bridge.vault.write('telegram.json', {})
    assert native.bridge.private() == {'pair': None, 'code': None}
    with native.bridge.vault.locked():
        native.bridge.vault.write('telegram.json', [])
    assert native.bridge._private() is None


async def test_two_rooms_share_one_hub_and_second_pair_is_rejected(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default alpha')
    first = native.bridge.private()['comments'][0]
    assert first['rooms'] == ['alpha', 'default']
    await dispatch(native, text='/hejo_comments_bind alpha default')
    await dispatch(native, text='/hejo_comments_bind beta')
    await dispatch(native, text='/hejo_comments_probe alpha', chat=-1000000000301)
    assert native.bridge.private()['comments'] == [first]
    assert native.bridge.comments.route('alpha') == 'comments'
    assert native.bridge.comments.route('beta') == 'topic'


async def test_mixed_legacy_receipts_and_incomplete_tail_survive_restart(native):
    await finish_probe(native)
    with native.bridge.sent_path.open('ab') as stream:
        stream.write(b'{"tag":"12345678","tg":"99","msg_id":"fixture-message"}\n')
        stream.write(b'{incomplete')
    bridge = native.bridge
    await bridge.close()
    replacement = door.Telegram(bridge.adapter, bridge.vault.path.parent, clock=bridge.clock)
    bridge.adapter.telegram = replacement
    native.bridge = replacement
    assert replacement.sent['12345678', '99'] == 'fixture-message'
    assert not replacement.comments.damaged
    assert replacement.sent_path.read_bytes().endswith(b'\n')
    await dispatch(native, text='/hejo_comments_bind default')
    assert replacement.comments.route('default') == 'comments'
    with replacement.vault.locked():
        value = replacement.private()
        value['comments_version'] = 999
        replacement.vault.write('telegram.json', value)
    assert replacement.comments.route('default') == 'paused'
    await dispatch(native)
    assert native.core == []


@pytest.mark.parametrize('paused', [False, True])
async def test_sync_preserves_converted_topics_and_updates_other_rooms(native, monkeypatch, paused):
    from unittest.mock import AsyncMock
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default')
    bridge = native.bridge
    if paused:
        with bridge.vault.locked():
            value = bridge.private()
            value['comments'][0]['state'] = 'paused'
            bridge.vault.write('telegram.json', value)
    preserved = dict(topic='8', name='Old', closed=False)
    with bridge.settings_store.locked():
        bridge.settings_store.write('topics.json', dict(tag='12345678', topics={
            'default': preserved, 'alpha': dict(topic='9', name='Old', closed=True),
            'removed': dict(topic='10', name='Removed', closed=False)}))
    bot = SimpleNamespace(close_forum_topic=AsyncMock(), reopen_forum_topic=AsyncMock(),
        edit_forum_topic=AsyncMock(), create_forum_topic=AsyncMock(return_value=SimpleNamespace(message_thread_id=11)))
    monkeypatch.setattr(door, '_telegram', SimpleNamespace(is_connected=True, _bot=bot))
    monkeypatch.setattr(bridge, 'rooms', lambda: dict(default='Changed', alpha='Renamed', beta='New'))
    await bridge.sync_topics()
    bot.close_forum_topic.assert_awaited_once_with(chat_id='-1000000000100', message_thread_id='10')
    bot.reopen_forum_topic.assert_awaited_once_with(chat_id='-1000000000100', message_thread_id='9')
    assert bot.edit_forum_topic.await_count == 2
    bot.create_forum_topic.assert_awaited_once_with(chat_id='-1000000000100', name='New')
    assert bridge.topics('12345678')['topics']['default'] == dict(topic='8', name='Changed', closed=False)
    # Even a bound room follows the old close path once actually deleted.
    monkeypatch.setattr(bridge, 'rooms', lambda: dict(alpha='Renamed', beta='New'))
    await bridge.sync_topics()
    assert bot.close_forum_topic.await_args.kwargs['message_thread_id'] == '8'
    assert bot.close_forum_topic.await_count == 2


def sent_texts(native):
    return [args['text'] for action, args in native.api.calls if action == 'sendMessage']


async def test_control_results_and_silent_reserved_input(native):
    await dispatch(native, text='/hejo_comments_bind default')
    assert sent_texts(native)[-1].startswith('probe_required:')
    await finish_probe(native)
    native.bridge.incoming['default'] = 1
    await dispatch(native, text='/hejo_comments_bind default')
    assert sent_texts(native)[-1].startswith('busy:')
    native.bridge.incoming.clear()
    await dispatch(native, text='/hejo_comments_bind default')
    assert sent_texts(native)[-1].startswith('bound:')
    before = native.bridge.private()
    await dispatch(native, text='/hejo_comments_bind default')
    assert sent_texts(native)[-1].startswith('already_bound:')
    assert native.bridge.private() == before
    count = len(sent_texts(native))
    await dispatch(native, text='/hejo_comments_bind default', user=101)
    await dispatch(native)
    await dispatch(native, edit=True)
    assert len(sent_texts(native)) == count and native.core == []
    native.api.extra_admin = True
    await dispatch(native, text='/hejo_comments_bind default')
    assert sent_texts(native)[-1].startswith('permission_failed:')


@pytest.mark.parametrize('command', ['probe', 'bind'])
async def test_notice_failure_does_not_repeat_or_undo_action(native, command, caplog):
    if command == 'bind':
        await finish_probe(native)
    native.api.calls.clear()
    marker = 'fixture-private-error-detail'
    def fail_notice(args):
        if args['text'].startswith(('bound:', 'probe_started:')):
            raise OSError(marker)
    native.api.before_send = fail_notice
    await dispatch(native, text=f'/hejo_comments_{command} default')
    value = native.bridge.private()
    assert len(value['probes']) == 1
    if command == 'probe':
        assert value['probes'][0]['state'] == 'pending'
        assert len(sent_texts(native)) == 2  # one probe and one failed notice, no retry
    else:
        assert len(value['comments']) == 1 and value['comments'][0]['state'] == 'active'
        assert len(sent_texts(native)) == 1
    assert marker not in caplog.text and marker not in ''.join(sent_texts(native))
    assert 'telegram_comments_notice_failed' in caplog.text


async def test_remote_exception_text_is_not_exposed(native, caplog):
    marker = 'fixture-private-error-detail'
    def fail_query(action, args, result):
        if action == 'getChat':
            raise OSError(marker)
        return result
    native.api.transform = fail_query
    await dispatch(native, text='/hejo_comments_probe default')
    assert len(sent_texts(native)) == 1 and sent_texts(native)[0].startswith('rejected:')
    assert marker not in caplog.text and marker not in sent_texts(native)[0]
    assert 'probes' not in native.bridge.private()



FORUM, CHANNEL, DISCUSSION = -1000000000100, -1000000000200, -1000000000300

async def settled(native):
    async with asyncio.timeout(4):
        while native.bridge.workers:
            await asyncio.sleep(.01)
        await asyncio.sleep(.02)

async def ready(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default alpha')
    assert native.bridge.comments.route('alpha') == 'comments'
    with native.bridge.settings_store.locked():
        native.bridge.settings_store.write('topics.json', dict(tag='12345678', topics={
            r: dict(topic=str(i), name=r, closed=False) for r,i in [('default',8),('alpha',9),('beta',10)]}))
    door._telegram.is_connected = True
    native.bridge.settle_seconds = 0
    native.api.calls.clear()


@pytest.mark.parametrize('blocked', [None, 'paused', 'disabled', 'closed', 'unpaired'])
async def test_hub_typing_in_original_topic_rechecks_state(native, gate, monkeypatch, blocked):
    """Comments keep forum typing; deferred actions cannot outlive routing changes."""
    await ready(native)
    async def send_typing(chat_id, metadata=None):
        await native.app.bot.send_chat_action(chat_id=chat_id, action='typing',
                                             message_thread_id=int(metadata['thread_id']))
    monkeypatch.setattr(door._telegram, 'send_typing', send_typing, raising=False)
    for _ in range(3):
        await gate.send_typing('default', {'thread_id': 'fixture-thread'})
    if blocked in {'paused', 'unpaired'}:
        with native.bridge.vault.locked():
            value = native.bridge.private()
            if blocked == 'paused':
                value['comments'][0]['state'] = 'paused'
            else:
                value['pair'] = None
            native.bridge.vault.write('telegram.json', value)
    elif blocked == 'disabled':
        with native.bridge.settings_store.locked():
            native.bridge.settings_store.write('settings.json', {'enabled': False})
    elif blocked == 'closed':
        with native.bridge.settings_store.locked():
            value = native.bridge.topics('12345678')
            value['topics']['default']['closed'] = True
            native.bridge.settings_store.write('topics.json', value)
    await asyncio.gather(*native.bridge._typing_tasks)
    actions = [args for method, args in native.api.calls if method == 'sendChatAction']
    assert actions == ([] if blocked else [dict(chat_id=str(FORUM), action='typing', message_thread_id=8)])
    assert not [m for m, _ in native.api.calls if m in {'sendMessage', 'editMessageText'}]


def incoming(native, number, chat=DISCUSSION, reply=None, raw=None, **extra):
    data = dict(message_id=number, date=1001, chat=dict(id=chat, type='supergroup', is_forum=chat==FORUM),
                text='fixture question')
    data['from'] = dict(id=100, is_bot=False, first_name='Fixture')
    if reply:
        data['reply_to_message'] = dict(message_id=reply, date=1001, chat=data['chat'])
    if raw:
        data['message_thread_id'] = raw
    data.update(extra)
    return Update.de_json(dict(update_id=number,message=data),native.app.bot)

async def topic_input(native, number, room='default', reply=None, **extra):
    from dataclasses import replace
    from gateway.platforms.event import MessageEvent
    topic = 8 if room=='default' else 9
    u = incoming(native,number,chat=FORUM,reply=reply,raw=topic,**extra)
    src = replace(native.bridge.adapter.build_source(chat_id=str(FORUM),user_id='100',
                  chat_type='group',thread_id=str(topic)),platform='telegram')
    event = MessageEvent(text=u.message.text or '', source=src, message_id=str(number),
                         reply_to_message_id=str(reply) if reply else None, raw_message=u.message)
    await native.bridge.receive_external(event)
    await settled(native)
    return u

async def forward_root(native, op, number):
    u=incoming(native,number, is_automatic_forward=True,
               sender_chat=dict(id=CHANNEL,type='channel',title='Fixture'),
               forward_origin=dict(type='channel',date=1001,chat=dict(id=CHANNEL,type='channel',title='Fixture'),
                                   message_id=op['message_id']))
    await native.app.process_update(u)
    await settled(native)


def deliveries(native, side=None):
    return [o for o in native.bridge.comments.operations.values() if side is None or o['side']==side]

def sends(native):
    return [a for m,a in native.api.calls if m in {'sendMessage','sendPhoto','sendDocument'}]

async def question(native, number=100, room='default', anchor=200):
    await topic_input(native,number,room)
    op=next(o for o in deliveries(native,'channel') if o['room']==room and o['status']=='receipt')
    await forward_root(native,op,anchor)
    return op

@pytest.mark.parametrize('failure', [None, 'stopped', 'permission', 'network'])
async def test_hub_typing_targets_exact_comment_thread(native, gate, runner, monkeypatch, failure):
    """Typing reaches only the question's comment thread without new chat messages."""
    await ready(native)
    async def send_typing(chat_id, metadata=None):
        if failure == 'network' and int(chat_id) == DISCUSSION:
            raise OSError('fixture typing unavailable')
        await native.app.bot.send_chat_action(chat_id=chat_id, action='typing',
                                             message_thread_id=int(metadata['thread_id']))
    monkeypatch.setattr(door._telegram, 'send_typing', send_typing, raising=False)
    monkeypatch.setattr(door._telegram, '_bot', native.app.bot, raising=False)
    first = await question(native)
    await question(native, number=101, room='alpha', anchor=201)
    # Start a new heartbeat window after setup's automatic runner typing.
    native.bridge._typing_at.clear()
    native.api.calls.clear()
    for _ in range(3):
        await gate.send_typing('default', {'thread_id': first['thread']})
    if failure == 'stopped':
        await gate.stop_typing('default', {'thread_id': first['thread']})
    elif failure == 'permission':
        native.api.extra_admin = True
    await asyncio.gather(*native.bridge._typing_tasks)
    actions = [args for method, args in native.api.calls if method == 'sendChatAction']
    expected = [] if failure == 'stopped' else [dict(chat_id=str(FORUM), action='typing', message_thread_id=8)]
    if failure is None:
        expected.append(dict(chat_id=str(DISCUSSION), action='typing', message_thread_id=200))
    assert actions == expected
    assert not [m for m, _ in native.api.calls if m in {'sendMessage', 'editMessageText'}]


async def test_hub_two_rooms_cards_and_comment_routing(native,gate,runner):
    await ready(native)
    a=await question(native)
    b=await question(native,101,'alpha',201)
    assert len(native.bridge.private()['comments'])==1
    assert {o['room'] for o in deliveries(native,'forum')}=={'default','alpha'}
    cards=[a for a in sends(native) if int(a['chat_id'])==FORUM]
    assert len(cards)==2
    assert {c['message_thread_id'] for c in cards}=={8,9}
    assert {c['reply_parameters']['message_id'] for c in cards}=={100,101}
    assert cards[0]['reply_markup']['inline_keyboard'][0][0]['url']=='https://t.me/c/300/200?thread=200'
    for index,op in enumerate([a,b]):
        await gate.send(op['room'],'reply',metadata={'thread_id':op['thread']})
        await settled(native)
        await native.app.process_update(incoming(native,300+index,reply=200+index,raw=200+index))
    await settled(native)
    assert len(runner.events)==4
    assert runner.events[0].source.thread_id==runner.events[2].source.thread_id
    assert runner.events[1].source.thread_id==runner.events[3].source.thread_id
    assert len(deliveries(native,'forum'))==2
    assert all('message_thread_id' not in c and c['reply_parameters']['allow_sending_without_reply'] is False
               for c in sends(native) if int(c['chat_id'])==DISCUSSION)

async def test_hub_channel_posts_and_unknown_forward_never_execute(native,gate,runner):
    await ready(native)
    await forward_root(native,dict(message_id=600),200)
    await dispatch(native,text='arbitrary channel post',chat=CHANNEL)
    assert not runner.events
    assert not gate.journal.records
    assert not native.core

@pytest.mark.parametrize('bad',['stranger','anonymous','forward','wrong_reply','conflicting','edited'])
async def test_hub_comment_auth_and_target_rejection(native,runner,bad):
    await ready(native);await question(native)
    data=incoming(native,300,reply=200).to_dict()
    if bad=='stranger':data['message']['from']['id']=777
    if bad=='anonymous':data['message']['sender_chat']=dict(id=DISCUSSION,type='supergroup',title='Fixture')
    if bad=='forward':data['message']['forward_origin']=dict(type='user',date=1001,sender_user=dict(id=777,is_bot=False,first_name='Fixture'))
    if bad=='wrong_reply':data['message']['reply_to_message']['message_id']=999
    if bad=='conflicting':data['message']['message_thread_id']=999
    if bad=='edited':data['edited_message']=data.pop('message')
    await native.app.process_update(Update.de_json(data,native.app.bot));await settled(native)
    assert len(runner.events)==1
    assert not native.core

async def test_hub_input_dedup_and_restart(native,runner):
    await ready(native);await question(native)
    u=incoming(native,300,reply=200)
    await native.app.process_update(u);await settled(native)
    await native.bridge.comments.close();native.bridge.comments=Comments(native.bridge)
    await native.app.process_update(u);await topic_input(native,100)
    assert len(runner.events)==2
    assert len(deliveries(native,'channel'))==1
    assert len(deliveries(native,'forum'))==1

async def test_hub_cross_room_card_and_unknown_reply_rejected(native,runner):
    await ready(native);await question(native)
    card=deliveries(native,'forum')[0]
    await topic_input(native,301,'alpha',reply=card['message_id'])
    await topic_input(native,302,reply=999)
    assert len(runner.events)==1
    await topic_input(native,303,reply=card['message_id'])
    assert len(runner.events)==2
    assert runner.events[0].source.thread_id==runner.events[1].source.thread_id

@pytest.mark.parametrize('media',[{'voice':dict(file_id='x',file_unique_id='y',duration=1)},
                                  {'media_group_id':'album'},{'video_note':dict(file_id='x',file_unique_id='y',duration=1,length=1)}])
async def test_hub_unsupported_input_does_not_execute_caption(native,runner,media):
    await ready(native);await question(native)
    await native.app.process_update(incoming(native,300,reply=200,caption='must not execute',**media))
    assert len(runner.events)==1

@pytest.mark.parametrize('stage',['root','card','comment'])
async def test_hub_unknown_send_never_retries(native,gate,runner,stage):
    await ready(native)
    if stage=='root':
        native.api.fail_send=True
        await topic_input(native,100)
    elif stage=='card':
        await topic_input(native,100)
        native.api.fail_send=True
        await forward_root(native,deliveries(native,'channel')[0],200)
    else:
        op=await question(native)
        native.api.fail_send=True
        await gate.send('default','answer',metadata={'thread_id':op['thread']});await settled(native)
    assert any(o['status']=='unknown' for o in deliveries(native))
    count=len(sends(native));native.api.fail_send=False
    await native.bridge.comments.close();native.bridge.comments=Comments(native.bridge)
    op=deliveries(native)[0]
    await gate.send('default','next',metadata={'thread_id':op['thread']});await settled(native)
    assert len(sends(native))==count

@pytest.mark.parametrize('early',[False,True])
async def test_hub_app_root_order_and_echo(native,gate,runner,early):
    await ready(native)
    async def before(args):
        if early and int(args['chat_id'])==CHANNEL:
            await forward_root(native,dict(message_id=native.api.next_message+1),200)
    # Do not await settled while inside the sender's own worker.
    if early:
        async def echo(args):
            if int(args['chat_id'])==CHANNEL:
                u=incoming(native,200,is_automatic_forward=True,sender_chat=dict(id=CHANNEL,type='channel',title='Fixture'),
                  forward_origin=dict(type='channel',date=1001,chat=dict(id=CHANNEL,type='channel',title='Fixture'),message_id=native.api.next_message+1))
                await native.app.process_update(u)
        native.api.before_send=echo
    await gate.send('default','x'*9000,metadata={'thread_id':str(uuid.uuid4())});await settled(native)
    if not early:await forward_root(native,deliveries(native,'channel')[0],200)
    assert len(deliveries(native,'channel'))==1
    assert len(deliveries(native,'discussion'))==2
    assert len(deliveries(native,'forum'))==1
    assert not runner.events

@pytest.mark.parametrize('abort',[False,True])
async def test_hub_off_all_rooms_retired_reservation(native,gate,abort):
    await ready(native);await question(native)
    journal=list(gate.journal.records)
    await dispatch(native,text='/hejo_comments_abort' if abort else '/hejo_comments_off',chat=FORUM if abort else DISCUSSION)
    assert native.bridge.comments.route('default')=='topic'
    assert native.bridge.comments.route('alpha')=='topic'
    assert native.bridge.private()['comments'][0]['state']=='retired'
    await native.app.process_update(incoming(native,300,reply=200))
    assert gate.journal.records==journal and not native.core
    await dispatch(native,text='/hejo_comments_bind default alpha')
    assert native.bridge.private()['comments'][0]['state']=='retired'

async def test_hub_busy_and_unknown_abort(native,gate):
    await ready(native)
    native.api.fail_send=True;await topic_input(native,100);native.api.fail_send=False
    await dispatch(native,text='/hejo_comments_off')
    assert native.bridge.comments.route('default')=='comments'
    await dispatch(native,text='/hejo_comments_abort',chat=FORUM)
    assert native.bridge.comments.route('alpha')=='topic'
    assert all(o['status']=='cancelled' for o in deliveries(native))

async def test_hub_legacy_binding_requires_migration(native):
    await ready(native)
    v=native.bridge.private();v['comments_version']=1
    v['comments'][0]['room']='default';v['comments'][0].pop('rooms')
    native.bridge.vault.write('telegram.json',v)
    assert native.bridge.comments.route('default')=='paused'
    await dispatch(native,text='/hejo_comments_bind default alpha')
    assert native.bridge.private()==v

async def test_hub_permission_loss_pauses_all_rooms(native,gate):
    await ready(native);op=await question(native)
    native.api.extra_admin=True
    count=len(sends(native))
    await gate.send('default','answer',metadata={'thread_id':op['thread']});await settled(native)
    assert native.bridge.comments.route('default')=='paused'
    assert native.bridge.comments.route('alpha')=='paused'
    assert len(sends(native))==count

async def test_hub_card_unknown_resolve_in_own_topic_only(native,gate):
    await ready(native);await topic_input(native,100)
    native.api.fail_send=True
    await forward_root(native,deliveries(native,'channel')[0],200)
    card=deliveries(native,'forum')[0];assert card['status']=='unknown'
    native.api.fail_send=False
    text=native.bridge.comments.card_text(native.bridge.comments.binding_for('default'),card['thread'])
    target=incoming(native,500,chat=FORUM,raw=8,text=text,
        reply_markup=dict(inline_keyboard=[[dict(text='대화 열기',url='https://t.me/c/300/200?thread=200')]])).to_dict()['message']
    target['from']=dict(id=900,is_bot=True,first_name='Fixture')
    def command(chat,topic):
        u=incoming(native,600,chat=chat,raw=topic,text='/hejo_comments_resolve '+card['operation']).to_dict()
        u['message']['reply_to_message']=target
        return Update.de_json(u,native.app.bot)
    await native.app.process_update(command(FORUM,9))
    assert deliveries(native,'forum')[0]['status']=='unknown'
    await native.app.process_update(command(FORUM,8))
    assert deliveries(native,'forum')[0]['status']=='receipt'
    count=len([x for x in sends(native) if x.get('reply_markup')])
    await gate.send('default','after resolve',metadata={'thread_id':card['thread']});await settled(native)
    assert len([x for x in sends(native) if x.get('reply_markup')])==count

@pytest.mark.parametrize('wrong',['none','text','origin','other_room'])
async def test_hub_root_unknown_resolve(native,gate,wrong):
    await ready(native);native.api.fail_send=True;await topic_input(native,100);native.api.fail_send=False
    op=deliveries(native,'channel')[0]
    source=gate.journal.message(op['msg_id'])
    payload=native.bridge.comments.parts(source)[0][1]
    target=incoming(native,200,text=payload,is_automatic_forward=True,
       sender_chat=dict(id=CHANNEL,type='channel',title='Fixture'),
       forward_origin=dict(type='channel',date=1001,chat=dict(id=CHANNEL,type='channel',title='Fixture'),message_id=500)).to_dict()['message']
    if wrong=='text':target['text']='different'
    if wrong=='origin':target['forward_origin']['chat']['id']-=1
    cmd=incoming(native,600,text='/hejo_comments_resolve '+op['operation']).to_dict()
    if wrong=='other_room':cmd['message']['chat']['id']=FORUM
    cmd['message']['reply_to_message']=target
    await native.app.process_update(Update.de_json(cmd,native.app.bot));await settled(native)
    assert deliveries(native,'channel')[0]['status']==('receipt' if wrong=='none' else 'unknown')

async def test_hub_same_thread_id_in_different_rooms(native,gate):
    await ready(native);thread=str(uuid.uuid4())
    await asyncio.gather(*(gate.send(room,'report',metadata={'thread_id':thread}) for room in ['default','alpha']))
    await settled(native)
    roots=deliveries(native,'channel');assert len(roots)==2
    for i,op in enumerate(roots):await forward_root(native,op,200+i)
    assert len(deliveries(native,'forum'))==2
    assert {o['room'] for o in roots}=={'default','alpha'}

async def test_hub_disable_cancels_waiting_payload(native,gate):
    await ready(native)
    await gate.send('default','x'*9000,metadata={'thread_id':str(uuid.uuid4())});await settled(native)
    root=deliveries(native,'channel')[0]
    await native.bridge.command(dict(type='telegram_set',id='fixture',enabled=False),SimpleNamespace(features={'telegram'}))
    count=len(sends(native))
    await forward_root(native,root,200)
    assert len(sends(native))==count
    assert all(o['status']=='cancelled' for o in deliveries(native,'discussion'))

async def test_hub_unpair_during_send_blocks_later_output(native,gate):
    await ready(native)
    async def before(args):
        await native.bridge.command(dict(type='telegram_unpair',id='fixture'),SimpleNamespace(features={'telegram'}))
    native.api.before_send=before
    await gate.send('default','x'*9000,metadata={'thread_id':str(uuid.uuid4())});await settled(native)
    assert len(sends(native))==1
    assert native.bridge.private()['comments'][0]['state']=='retired'
    await forward_root(native,deliveries(native,'channel')[0],200)
    assert len(sends(native))==1

async def test_hub_partial_failure_never_duplicates_first_fragment(native,gate):
    await ready(native);op=await question(native)
    base=len(sends(native));n=[0]
    async def before(args):
        n[0]+=1
        if n[0]==2:raise OSError('fixture')
    native.api.before_send=before
    await gate.send('default','x'*9000,metadata={'thread_id':op['thread']});await settled(native)
    out=deliveries(native,'discussion')
    assert [o['status'] for o in out]==['receipt','unknown','queued']
    assert len(sends(native))==base+2
    native.api.before_send=None
    await native.bridge.comments.close();native.bridge.comments=Comments(native.bridge)
    await gate.send('default','later',metadata={'thread_id':op['thread']});await settled(native)
    assert len(sends(native))==base+2

async def test_hub_receipt_fsync_failure_closes_without_retry(native,monkeypatch):
    await ready(native)
    comments=native.bridge.comments;original=comments.append_record
    def fail(row):
        if row.get('kind')=='delivery' and row.get('status')=='receipt':raise OSError('fixture')
        original(row)
    monkeypatch.setattr(comments,'append_record',fail)
    await topic_input(native,100)
    assert comments.damaged
    assert len(sends(native))==1
    monkeypatch.setattr(comments,'append_record',original)
    await comments.close();native.bridge.comments=Comments(native.bridge)
    assert any(o['status']=='intent' for o in deliveries(native))
    await topic_input(native,101)
    assert len(sends(native))==1

@pytest.mark.parametrize('fault',['oversize','download','success'])
async def test_hub_attachment_input_claim_before_download(native,gate,runner,monkeypatch,fault):
    await ready(native);await question(native)
    calls=[]
    class File:
        file_size=3
        async def download_to_drive(self,custom_path):
            calls.append('download')
            assert any(r['kind']=='input' and r['message_id']==300 for r in native.bridge.comments.records)
            if fault=='download':raise OSError('fixture')
            custom_path.write_bytes(b'abc')
    async def get_file(self,file_id):return File()
    from telegram.ext import ExtBot
    monkeypatch.setattr(ExtBot,'get_file',get_file)
    data=dict(file_id='fixture',file_unique_id='fixture',file_name='fixture.txt',file_size=30000000 if fault=='oversize' else 3)
    u=incoming(native,300,reply=200,text=None,caption='attachment',document=data)
    await native.app.process_update(u);await settled(native)
    await native.app.process_update(u);await settled(native)
    assert len(runner.events)==(2 if fault=='success' else 1)
    assert calls==([] if fault=='oversize' else ['download'])

async def test_hub_deleted_root_and_corrupt_ledger_do_not_recreate(native,gate):
    await ready(native);op=await question(native)
    # A remotely missing root must fail, never plain-send or create a replacement root.
    native.api.fail_send=True
    await gate.send('default','answer',metadata={'thread_id':op['thread']});await settled(native)
    assert len(deliveries(native,'channel'))==1
    with native.bridge.sent_path.open('ab') as f:f.write(b'{broken}\n')
    await native.bridge.comments.close();native.bridge.comments=Comments(native.bridge)
    assert native.bridge.comments.route('default')=='paused'
    assert native.bridge.comments.route('beta')=='topic'

async def test_hub_intent_before_network(native,gate):
    await ready(native)
    async def before(args):
        on_disk=[json.loads(x) for x in native.bridge.sent_path.read_text().splitlines()]
        assert any(r.get('kind')=='delivery' and r.get('status')=='intent' for r in on_disk)
    native.api.before_send=before
    await gate.send('default','report',metadata={'thread_id':str(uuid.uuid4())});await settled(native)
    assert deliveries(native,'channel')[0]['status']=='receipt'

async def test_hub_native_forum_dispatch_claims_before_core(native,runner):
    await ready(native)
    u=incoming(native,100,chat=FORUM,raw=8)
    await native.app.process_update(u);await settled(native)
    await native.app.process_update(u);await settled(native)
    assert len(runner.events)==1
    assert native.core==[]
    edit=u.to_dict();edit['edited_message']=edit.pop('message')
    await native.app.process_update(Update.de_json(edit,native.app.bot))
    assert len(runner.events)==1 and native.core==[]

async def test_hub_native_unenrolled_topic_stays_with_core(native):
    await ready(native)
    await native.app.process_update(incoming(native,100,chat=FORUM,raw=10))
    assert native.core==[100]


async def test_hub_card_status_edit_is_durable_and_never_clones(native,gate):
    await ready(native);op=await question(native)
    card=deliveries(native,'forum')[0]
    async def fail_comment(args):
        if int(args['chat_id']) == DISCUSSION:
            raise OSError('fixture comment failure')
    native.api.before_send=fail_comment
    await gate.send('default','result',metadata={'thread_id':op['thread']})
    await settled(native)
    edits=[args for method,args in native.api.calls if method=='editMessageText']
    assert len(edits)==1 and edits[0]['message_id']==card['message_id']
    assert edits[0]['text'].endswith('보류')
    assert len([o for o in deliveries(native,'forum') if o['media']=='text'])==1
    assert len([o for o in deliveries(native,'forum') if o['media']=='edit' and o['status']=='receipt'])==1
    restored=Comments(native.bridge)
    assert not restored.damaged
    await restored.update_card_state(native.app.bot,restored.binding_for('default'),('default',op['thread']))
    assert len([m for m,a in native.api.calls if m=='editMessageText'])==1
    await restored.close()


async def test_hub_unknown_card_edit_not_retried(native,gate):
    await ready(native);op=await question(native)
    native.api.fail_send=True
    await gate.send('default','result',metadata={'thread_id':op['thread']})
    await settled(native)
    assert any(o['media']=='edit' and o['status']=='unknown' for o in deliveries(native))
    count=len(native.api.calls)
    await native.bridge.comments.update_card_state(native.app.bot,native.bridge.comments.binding_for('default'),('default',op['thread']))
    assert len(native.api.calls)==count


async def test_hub_continuation_only_new_content_and_one_card(native,gate):
    thread=str(uuid.uuid4())
    await gate.send('default','old history',metadata={'thread_id':thread})
    await ready(native)
    await gate.send('default','new content',metadata={'thread_id':thread})
    await settled(native)
    root=next(o for o in deliveries(native,'channel') if o['thread']==thread)
    first=next(a for a in sends(native) if int(a['chat_id'])==CHANNEL)
    assert first['text'].startswith('이전 대화 이어쓰기 — 전환 이후 내용')
    assert 'old history' not in first['text'] and 'new content' in first['text']
    await forward_root(native,root,200)
    card=next(a for a in sends(native) if int(a['chat_id'])==FORUM)
    assert card['text'].startswith('이전 대화 이어쓰기 — 전환 이후 내용')
    await gate.send('default','next content',metadata={'thread_id':thread})
    await settled(native)
    assert len([o for o in deliveries(native,'forum') if o['media']=='text'])==1
    assert sends(native)[-1]['reply_parameters']['message_id']==200
    assert '이전 대화' not in sends(native)[-1]['text']


async def test_hub_native_before_primary_consumes_enrolled_topic(native,monkeypatch):
    from gate import adapter
    await ready(native)
    monkeypatch.setattr(adapter,'_primary',None)
    await native.app.process_update(incoming(native,700,chat=FORUM,raw=8))
    assert not native.core
    await native.app.process_update(incoming(native,701,chat=FORUM,raw=10))
    assert native.core==[701]


async def test_hub_unknown_edit_resolves_only_exact_card(native,gate):
    await ready(native);root=await question(native)
    native.api.fail_send=True
    await gate.send('default','result',metadata={'thread_id':root['thread']});await settled(native)
    op=next(o for o in deliveries(native) if o['media']=='edit')
    native.api.fail_send=False
    comments=native.bridge.comments
    text=comments.card_text(comments.binding_for('default'),root['thread'],'보류')
    def command(number):
        target=incoming(native,number,chat=FORUM,raw=8,text=text,
            reply_markup=dict(inline_keyboard=[[dict(text='대화 열기',url='https://t.me/c/300/200?thread=200')]])).to_dict()['message']
        target['from']=dict(id=900,is_bot=True,first_name='Fixture')
        u=incoming(native,800,chat=FORUM,raw=8,text='/hejo_comments_resolve '+op['operation']).to_dict()
        u['message']['reply_to_message']=target
        return Update.de_json(u,native.app.bot)
    await native.app.process_update(command(op['message_id']+1000))
    assert comments.operations[op['operation']]['status']=='unknown'
    await native.app.process_update(command(op['message_id']))
    assert comments.operations[op['operation']]['status']=='receipt'
    assert not Comments(native.bridge).damaged


async def test_hub_document_outbound_stays_in_comment_and_alias(native,gate,runner,tmp_path):
    await ready(native);root=await question(native)
    path=tmp_path/'fixture.txt';path.write_text('fixture document')
    await gate.send_document('default',str(path),caption='attachment',metadata={'thread_id':root['thread']})
    await settled(native)
    media=[a for m,a in native.api.calls if m=='sendDocument']
    assert len(media)==1 and int(media[0]['chat_id'])==DISCUSSION
    assert media[0]['reply_parameters']['message_id']==200
    assert media[0]['reply_parameters']['allow_sending_without_reply'] is False
    op=next(o for o in deliveries(native) if o['media']=='document')
    await native.app.process_update(incoming(native,900,reply=op['message_id'],raw=200))
    assert runner.events[-1].source.thread_id==root['thread']
    assert native.bridge.sent_path.stat().st_mode & 0o777==0o600
    ledger=native.bridge.sent_path.read_text()
    assert 'fixture document' not in ledger and 'fixture.txt' not in ledger
