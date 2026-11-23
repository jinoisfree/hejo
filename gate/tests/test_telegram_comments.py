"""TASK 1: real PTB dispatch and gate stores; Bot API alone is substituted."""
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
            result = dict(id=chat, type='channel' if chat in {-200, -201} else 'supergroup',
                          title='Fixture', accent_color_id=0, max_reaction_count=1,
                          linked_chat_id=chat - 100 if chat in {-200, -201} else chat + 100, is_forum=False)
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
        elif action in {'sendMessage', 'sendPhoto', 'sendDocument'}:
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
        bridge.vault.write('telegram.json', dict(pair=dict(platform='telegram', chat_id='-100',
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


def update(native, text='hello', chat=-300, user=100, edit=False, forward=None):
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
    await dispatch(native, chat=-999)
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
                result['linked_chat_id'] = -999
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
    await dispatch(native, text='/hejo_comments_rooms', chat=-100, user=101)
    assert not any(action == 'sendMessage' for action, _ in native.api.calls)
    await dispatch(native, text='/hejo_comments_rooms', chat=-100)
    texts = [args['text'] for action, args in native.api.calls if action == 'sendMessage']
    assert len(texts) == 1 and 'default:' in texts[0]


async def test_unsupported_endpoint_does_not_query_or_reserve(native):
    bot = SimpleNamespace(base_url='https://invalid.example/botfixture')
    with pytest.raises(Rejected, match='unsupported_endpoint'):
        await native.bridge.comments.validate(bot, '-300', 'default', native.bridge.private()['pair'])
    assert 'probes' not in native.bridge.private()


async def test_startup_without_primary_still_consumes_reserved_updates(native, monkeypatch):
    from gate import adapter
    await dispatch(native, text='/hejo_comments_probe default')
    monkeypatch.setattr(adapter, '_primary', None)
    await dispatch(native)
    await dispatch(native, edit=True)
    assert native.core == []
    await dispatch(native, chat=-999)
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


async def test_two_rooms_bind_independently_and_target_cannot_be_reused(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default')
    first = native.bridge.private()['comments'][0]
    await dispatch(native, text='/hejo_comments_bind alpha')
    assert native.bridge.private()['comments'] == [first]
    await dispatch(native, text='/hejo_comments_probe alpha', chat=-301)
    probe = native.bridge.private()['probes'][-1]
    root = native.bridge.comments.receipts[probe['tag'], 'channel']['message_id']
    await dispatch(native, chat=-301, forward=root)
    await dispatch(native, text='/hejo_comments_bind alpha', chat=-301)
    assert len(native.bridge.private()['comments']) == 2
    assert native.bridge.comments.route('default') == 'comments'
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
    bot.close_forum_topic.assert_awaited_once_with(chat_id='-100', message_thread_id='10')
    bot.reopen_forum_topic.assert_awaited_once_with(chat_id='-100', message_thread_id='9')
    bot.edit_forum_topic.assert_awaited_once_with(chat_id='-100', message_thread_id='9', name='Renamed')
    bot.create_forum_topic.assert_awaited_once_with(chat_id='-100', name='New')
    assert bridge.topics('12345678')['topics']['default'] == preserved
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


async def process(native, incoming):
    await native.app.process_update(incoming)
    async with asyncio.timeout(3):
        while native.bridge.adapter._active_sessions:
            await asyncio.sleep(.01)


async def activate(native):
    await finish_probe(native)
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'comments'


def fresh(native, number=100, root=None, reply=None, **extra):
    data = update(native, forward=root).to_dict()['message']
    data['date'] = 1001
    data['message_id'] = number
    if root:
        data['forward_origin']['date'] = 1001
    if reply is not None:
        data['reply_to_message'] = dict(message_id=reply, date=1001,
                                      chat=data['chat'], text='fixture')
    data.update(extra)
    return Update.de_json(dict(update_id=number, message=data), native.app.bot)


async def test_comments_ingress_root_reply_dedupe_restart(native, gate, runner):
    await activate(native)
    root = fresh(native, root=500)
    await process(native, root)
    assert len(runner.events) == 1
    await process(native, root)
    native.bridge.comments = Comments(native.bridge)
    await process(native, root)
    assert len(runner.events) == 1
    await process(native, fresh(native, 101, reply=100))
    assert len(runner.events) == 2
    assert runner.events[0].source.thread_id == runner.events[1].source.thread_id
    assert not native.core
    rows = [r for r in gate.journal.records if r.get('role') == 'owner']
    assert len(rows) == 2
    assert rows[0]['client_msg_id'].endswith(':channel:500')
    assert rows[1]['client_msg_id'].endswith(':discussion:101')


@pytest.mark.parametrize('change', [
    {'sender_chat': {'id': -300, 'type': 'supergroup', 'title': 'Fixture'}},
    {'from': {'id': 101, 'is_bot': False, 'first_name': 'Other'}},
    {'from': {'id': 100, 'is_bot': True, 'first_name': 'Bot'}},
    {'message_thread_id': 999}, {'date': 1000},
])
async def test_comments_rejects_untrusted_reply(native, runner, change):
    await activate(native)
    await process(native, fresh(native, root=500))
    assert len(runner.events) == 1
    before = len(native.api.calls)
    await process(native, fresh(native, 101, reply=100, **change))
    assert len(runner.events) == 1 and not native.core
    assert not any(m == 'sendMessage' for m, _ in native.api.calls[before:])


async def test_comments_prebind_origin_edit_channel_and_deleted_target(native, gate, runner):
    await activate(native)
    old = fresh(native, root=500).to_dict()
    old['message']['forward_origin']['date'] = 999
    await process(native, Update.de_json(old, native.app.bot))
    root = fresh(native, root=501)
    data = root.to_dict()
    data['edited_message'] = data.pop('message')
    await process(native, Update.de_json(data, native.app.bot))
    data['channel_post'] = data.pop('edited_message')
    await process(native, Update.de_json(data, native.app.bot))
    assert not runner.events
    await process(native, root)
    row = next(r for r in gate.journal.records if r.get('role') == 'owner')
    gate.journal.deleted_messages.add(row['msg_id'])
    await process(native, fresh(native, 101, reply=100))
    assert len(runner.events) == 1


@pytest.mark.parametrize('media', [
    {'media_group_id': 'fixture-album'},
    {'document': {'file_id': 'fixture', 'file_unique_id': 'fixture', 'file_size': 21 * 1024 * 1024}},
    {'document': {'file_id': 'fixture', 'file_unique_id': 'fixture', 'file_size': 10, 'file_name': '../fixture'}},
])
async def test_comments_unsupported_media_never_executes_caption(native, runner, media):
    await activate(native)
    await process(native, fresh(native, root=500, **media))
    assert not runner.events and not native.core
    assert not any(m == 'getFile' for m, _ in native.api.calls)
    assert not list(native.bridge.adapter.files.root.glob('.telegram-*'))


@pytest.mark.parametrize('failure', ['none', 'download', 'revoke', 'receive'])
async def test_comments_attachment_lifecycle(native, gate, runner, monkeypatch, failure):
    await activate(native)
    downloads = []
    async def get_file(bot, file_id):
        async def download_to_drive(custom_path):
            downloads.append(custom_path)
            assert custom_path.stat().st_mode & 0o777 == 0o600
            custom_path.write_bytes(b'fixture document')
            if failure == 'download':
                raise OSError('fixture download failed')
            if failure == 'revoke':
                with native.bridge.settings_store.locked():
                    native.bridge.settings_store.write('settings.json', {'enabled': False})
        return SimpleNamespace(file_size=16, download_to_drive=download_to_drive)
    monkeypatch.setattr(type(native.app.bot), 'get_file', get_file)
    if failure == 'receive':
        async def receive(*args):
            raise OSError('fixture receive failed')
        monkeypatch.setattr(gate, 'receive', receive)
    message = fresh(native, root=500, text=None, caption='fixture caption', document=dict(
        file_id='fixture', file_unique_id='fixture', file_size=16, file_name='fixture.txt'))
    await process(native, message)
    await process(native, message)
    assert len(downloads) == 1
    assert all(not p.exists() for p in downloads)
    assert not list(gate.files.root.glob('.pending/*/*'))
    assert len(runner.events) == (1 if failure == 'none' else 0)
    if failure == 'none':
        row = next(r for r in gate.journal.records if r.get('role') == 'owner')
        assert row['text'] == 'fixture caption' and len(row['files']) == 1
        path, _ = gate.files.registered('default', row['files'][0]['file_id'])
        assert path.read_bytes() == b'fixture document'


async def test_comments_committed_turn_failure_never_replays(native, gate, monkeypatch):
    await activate(native)
    calls = []
    async def fail(event):
        calls.append(event)
        raise OSError('fixture downstream failure')
    gate.set_message_handler(fail)
    message = fresh(native, root=500)
    await process(native, message)
    native.bridge.comments = Comments(native.bridge)
    await process(native, message)
    assert len(calls) == 1
    assert len([r for r in gate.journal.records if r.get('role') == 'owner']) == 1


async def test_comments_reply_to_reply_and_conflicting_anchor(native, runner):
    await activate(native)
    await process(native, fresh(native, root=500))
    await process(native, fresh(native, 101, reply=100))
    await process(native, fresh(native, 102, reply=101, message_thread_id=100))
    await process(native, fresh(native, 103, root=501))
    await process(native, fresh(native, 104, reply=101, message_thread_id=103))
    assert len(runner.events) == 4
    assert runner.events[0].source.thread_id == runner.events[2].source.thread_id
    assert runner.events[0].source.thread_id != runner.events[3].source.thread_id


async def test_comments_root_deletion_blocks_nested_reply_and_raw_requires_anchor(native, gate, runner):
    await activate(native)
    await process(native, fresh(native, root=500))
    await process(native, fresh(native, 101, reply=100))
    await process(native, fresh(native, 102, message_thread_id=101))
    assert len(runner.events) == 2
    root = next(r for r in gate.journal.records if r.get('role') == 'owner')
    gate.journal.deleted_messages.add(root['msg_id'])
    await process(native, fresh(native, 103, reply=101))
    assert len(runner.events) == 2


async def test_comments_input_claim_precedes_download_and_survives_failed_receive(native, gate, runner, monkeypatch):
    await activate(native)
    calls = []
    async def stage(*args):
        binding = native.bridge.private()['comments'][-1]
        restored = Comments(native.bridge)
        assert restored.lookup(binding, 'channel', 500)['kind'] == 'input'
        calls.append('stage')
        raise OSError('fixture failure')
    monkeypatch.setattr(native.bridge.comments, 'stage_input', stage)
    await process(native, fresh(native, root=500))
    native.bridge.comments = Comments(native.bridge)
    await process(native, fresh(native, root=500))
    assert calls == ['stage'] and not runner.events


async def test_comments_duplicate_channel_origin_different_forward_alias(native, runner):
    await activate(native)
    await process(native, fresh(native, root=500))
    await process(native, fresh(native, 110, root=500))
    await process(native, fresh(native, 111, reply=110))
    assert len(runner.events) == 2
    assert runner.events[0].source.thread_id == runner.events[1].source.thread_id


async def test_comments_permission_loss_pauses_without_topic_fallback(native, runner):
    await activate(native)
    native.api.extra_admin = True
    await process(native, fresh(native, root=500))
    assert not runner.events and not native.core
    assert native.bridge.comments.route('default') == 'paused'
    assert not native.bridge.comments.damaged


async def test_comments_photo_download_and_same_numeric_id_different_side(native, gate, runner, monkeypatch):
    await activate(native)
    async def get_file(bot, file_id):
        assert file_id == 'large'
        async def download_to_drive(custom_path):
            custom_path.write_bytes(b'fixture photo')
        return SimpleNamespace(file_size=13, download_to_drive=download_to_drive)
    monkeypatch.setattr(type(native.app.bot), 'get_file', get_file)
    photos = [dict(file_id=key, file_unique_id=key, width=size, height=size, file_size=13)
              for key, size in [('small', 1), ('large', 2)]]
    await process(native, fresh(native, 100, root=101, text=None, photo=photos))
    await process(native, fresh(native, 101, reply=100))
    assert len(runner.events) == 2
    rows = [r for r in gate.journal.records if r.get('role') == 'owner']
    assert rows[0]['files'][0]['name'] == 'photo.jpg'
    assert rows[0]['client_msg_id'].endswith(':channel:101')
    assert rows[1]['client_msg_id'].endswith(':discussion:101')


async def test_comments_receipt_middle_corruption_stops_execution(native, runner):
    await activate(native)
    native.bridge.comments.append_record(dict(v=2, kind='input'))
    native.bridge.comments = Comments(native.bridge)
    assert native.bridge.comments.damaged
    await process(native, fresh(native, root=500))
    assert not runner.events and not native.core


async def test_comments_conflicting_alias_fails_closed_after_restart(native, runner):
    await activate(native)
    await process(native, fresh(native, root=500))
    alias = next(r for r in native.bridge.comments.records if r['kind'] == 'alias')
    native.bridge.comments.append_record({**alias, 'thread': 'conflicting-thread'})
    native.bridge.comments = Comments(native.bridge)
    assert native.bridge.comments.damaged
    await process(native, fresh(native, 101, reply=100))
    assert len(runner.events) == 1 and not native.core


async def outbound_ready(native):
    await activate(native)
    door._telegram.is_connected = True
    native.bridge.settle_seconds = 0
    native.api.calls.clear()


async def settled_comments(native):
    async with asyncio.timeout(3):
        while native.bridge.workers:
            await asyncio.sleep(.01)


def sent_calls(native):
    return [args for method, args in native.api.calls if method in {'sendMessage', 'sendPhoto', 'sendDocument'}]


async def test_comments_outbound_two_questions_and_file_alias(native, gate, runner):
    await outbound_ready(native)
    await process(native, fresh(native, 100, root=500))
    await process(native, fresh(native, 200, root=600))
    for event, text in zip(runner.events, ['first answer', 'second answer']):
        await gate.send('default', text, metadata={'thread_id': event.source.thread_id})
    await settled_comments(native)
    calls = sent_calls(native)
    assert len(calls) == 2
    assert [c['reply_parameters']['message_id'] for c in calls] == [100, 200]
    assert all(int(c['chat_id']) == -300 and 'message_thread_id' not in c for c in calls)
    assert all(c['reply_parameters']['allow_sending_without_reply'] is False for c in calls)
    receipt = next(r for r in native.bridge.comments.operations.values() if r['status'] == 'receipt')
    await process(native, fresh(native, 300, reply=receipt['message_id']))
    assert len(runner.events) == 3
    assert runner.events[0].source.thread_id == runner.events[2].source.thread_id


@pytest.mark.parametrize('early', [False, True])
async def test_comments_channel_root_echo_race_and_split(native, gate, runner, early):
    await outbound_ready(native)
    async def before(args):
        if int(args['chat_id']) == -200 and early:
            await native.app.process_update(fresh(native, 100, root=native.api.next_message + 1))
    native.api.before_send = before
    thread = str(uuid.uuid4())
    await gate.send('default', 'x' * 9000, metadata={'thread_id': thread})
    await settled_comments(native)
    if not early:
        assert len(sent_calls(native)) == 1
        op = next(r for r in native.bridge.comments.operations.values() if r['root'])
        await process(native, fresh(native, 100, root=op['message_id']))
        await settled_comments(native)
    calls = sent_calls(native)
    assert len(calls) == 3
    assert [int(c['chat_id']) for c in calls] == [-200, -300, -300]
    assert all(len(c['text']) <= 4096 for c in calls)
    assert all(c['reply_parameters']['message_id'] == 100 for c in calls[1:])
    assert not runner.events
    for index, op in enumerate(list(native.bridge.comments.operations.values())):
        if op['side'] == 'discussion':
            await process(native, fresh(native, 500 + index, reply=op['message_id']))
    assert len(runner.events) == 2
    assert all(e.source.thread_id == thread for e in runner.events)


async def test_comments_unknown_root_restart_hold_status_resolve(native, gate, runner):
    await outbound_ready(native)
    native.api.fail_send = True
    thread = str(uuid.uuid4())
    await gate.send('default', 'fixture answer', metadata={'thread_id': thread})
    await settled_comments(native)
    op = next(iter(native.bridge.comments.operations.values()))
    assert op['status'] == 'unknown'
    native.api.fail_send = False
    native.bridge.comments = Comments(native.bridge)
    await gate.send('default', 'next answer', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    await process(native, fresh(native, 100, root=500))
    assert not runner.events
    assert sent_calls(native)[-1]['text'].startswith('held:')
    await dispatch(native, text='/hejo_comments_status')
    assert 'unknown' in sent_calls(native)[-1]['text']
    target = fresh(native, 100, root=500).to_dict()['message']
    target['text'] = native.bridge.render(gate.journal.message(op['msg_id']))[0]
    await process(native, fresh(native, 101, text='/hejo_comments_resolve ' + op['operation'], reply_to_message=target))
    await settled_comments(native)
    assert native.bridge.comments.operations[op['operation']]['status'] == 'receipt'
    assert sum(c.get('text', '').endswith('next answer') for c in sent_calls(native)) == 1
    assert not runner.events
    count = len(sent_calls(native))
    await process(native, fresh(native, 102, text='/hejo_comments_resolve ' + op['operation'], reply_to_message=target))
    assert len(sent_calls(native)) == count + 1
    assert sent_calls(native)[-1]['text'].startswith('rejected:')


async def test_comments_receipt_fsync_failure_never_retries(native, gate, runner, monkeypatch):
    await outbound_ready(native)
    comments = native.bridge.comments
    original = comments.append_record
    def fail(row):
        if row.get('kind') == 'delivery' and row['status'] == 'receipt':
            raise OSError('fixture fsync failure')
        return original(row)
    monkeypatch.setattr(comments, 'append_record', fail)
    await gate.send('default', 'uncertain', metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    assert comments.damaged
    native.bridge.comments = Comments(native.bridge)
    op = next(iter(native.bridge.comments.operations.values()))
    assert op['status'] == 'intent'
    assert 'unknown' in native.bridge.comments.delivery_status(update(native).message)
    await process(native, fresh(native, 100, root=native.api.next_message))
    assert not runner.events
    assert len([c for c in sent_calls(native) if int(c['chat_id']) == -200]) == 1


async def test_comments_outbound_permission_loss_and_no_plain_fallback(native, gate, runner):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    thread = runner.events[0].source.thread_id
    native.api.fail_send = True
    await gate.send('default', 'answer', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    assert sent_calls(native)[0]['reply_parameters']['allow_sending_without_reply'] is False
    assert next(iter(native.bridge.comments.operations.values()))['status'] == 'unknown'
    native.api.fail_send = False
    native.api.extra_admin = True
    await gate.send('default', 'blocked', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    assert native.bridge.comments.route('default') == 'paused'
    assert native.bridge.status()['topic_problem']


@pytest.mark.parametrize('abort', [False, True])
async def test_comments_off_abort_retire_without_replay(native, gate, runner, abort):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    thread = runner.events[0].source.thread_id
    if abort:
        native.api.fail_send = True
        await gate.send('default', 'uncertain answer', metadata={'thread_id': thread})
        await settled_comments(native)
        native.api.fail_send = False
    before = list(gate.journal.records)
    epoch = native.bridge.comments.epoch('default')
    command = '/hejo_comments_abort default' if abort else '/hejo_comments_off default'
    await dispatch(native, text=command, chat=-100 if abort else -300)
    assert native.bridge.comments.route('default') == 'topic'
    assert native.bridge.comments.epoch('default') != epoch
    assert gate.journal.records == before
    assert all(r['status'] == 'cancelled' for r in native.bridge.comments.operations.values())
    native.bridge.comments = Comments(native.bridge)
    await process(native, fresh(native, 101, root=501))
    assert len(runner.events) == 1 and not native.core
    await dispatch(native, text='/hejo_comments_bind default')
    assert native.bridge.comments.route('default') == 'topic'
    assert sent_calls(native)[-1]['text'].startswith('rejected:')
    assert not any('delete' in method.lower() for method, _ in native.api.calls)


async def test_comments_off_busy_unknown_abort_busy_live_call(native, gate):
    await outbound_ready(native)
    entered, release = asyncio.Event(), asyncio.Event()
    async def before(args):
        if int(args['chat_id']) == -200:
            entered.set()
            await release.wait()
    native.api.before_send = before
    thread = str(uuid.uuid4())
    await gate.send('default', 'fixture answer', metadata={'thread_id': thread})
    await asyncio.wait_for(entered.wait(), 2)
    await dispatch(native, text='/hejo_comments_abort default', chat=-100)
    assert native.bridge.comments.route('default') == 'comments'
    assert sent_calls(native)[-1]['text'].startswith('busy:')
    release.set()
    await settled_comments(native)
    await dispatch(native, text='/hejo_comments_off default')
    assert native.bridge.comments.route('default') == 'comments'
    assert sent_calls(native)[-1]['text'].startswith('busy:')
    await dispatch(native, text='/hejo_comments_abort default', chat=-100)
    assert native.bridge.comments.route('default') == 'topic'


async def test_comments_disable_cancels_queued_parts_and_unpair_keeps_reservation(native, gate, runner):
    await outbound_ready(native)
    await gate.send('default', 'x' * 9000, metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    op = next(r for r in native.bridge.comments.operations.values() if r['root'])
    await native.bridge.command(dict(type='telegram_set_enabled', id='fixture', enabled=False), SimpleNamespace(features={'telegram'}))
    assert all(r['status'] != 'queued' for r in native.bridge.comments.operations.values())
    await process(native, fresh(native, 100, root=op['message_id']))
    assert not runner.events
    await native.bridge.command(dict(type='telegram_set_enabled', id='fixture', enabled=True), SimpleNamespace(features={'telegram'}))
    await process(native, fresh(native, 100, root=op['message_id']))
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    await native.bridge.command(dict(type='telegram_unpair', id='fixture'), SimpleNamespace(features={'telegram'}))
    native.bridge.comments = Comments(native.bridge)
    await process(native, fresh(native, 101, root=501))
    assert not runner.events and not native.core


async def test_comments_continuation_bind_off_and_topic_epoch(native, gate, monkeypatch):
    thread = str(uuid.uuid4())
    await gate.send('default', 'old history', metadata={'thread_id': thread})
    await outbound_ready(native)
    await gate.send('default', 'new content', metadata={'thread_id': thread})
    await settled_comments(native)
    call = sent_calls(native)[0]
    assert call['text'].startswith('이전 대화 이어쓰기 — 전환 이후 내용\n')
    assert 'old history' not in call['text'] and 'new content' in call['text']
    op = next(r for r in native.bridge.comments.operations.values() if r['root'])
    await process(native, fresh(native, 100, root=op['message_id']))
    await settled_comments(native)
    await gate.send('default', 'next content', metadata={'thread_id': thread})
    await settled_comments(native)
    assert sent_calls(native)[-1]['reply_parameters']['message_id'] == 100
    assert not sent_calls(native)[-1]['text'].startswith('이전 대화')
    await dispatch(native, text='/hejo_comments_off default')
    topic_calls = []
    async def send(chat, text, **kwargs):
        topic_calls.append((text, kwargs))
        return SimpleNamespace(success=True, message_id=str(700 + len(topic_calls)), raw_response={})
    monkeypatch.setattr(door._telegram, 'send', send, raising=False)
    with native.bridge.settings_store.locked():
        native.bridge.settings_store.write('topics.json', dict(tag='12345678', topics={
            'default': dict(topic='10', name=native.bridge.rooms()['default'], closed=False)}))
    await gate.send('default', 'after off', metadata={'thread_id': thread})
    await settled_comments(native)
    await gate.send('default', 'after off again', metadata={'thread_id': thread})
    await settled_comments(native)
    assert topic_calls[0][0].startswith('이전 대화 이어쓰기 — 전환 이후 내용\n')
    assert topic_calls[0][1]['reply_to'] is None
    assert topic_calls[1][1]['reply_to'] == '701'
    native.bridge.comments = Comments(native.bridge)
    assert not native.bridge.comments.damaged
    native.bridge.sent.clear()
    native.bridge._load_sent()
    assert native.bridge.anchor(('default', thread), '12345678') == '701'


async def test_comments_deleted_anchor_never_new_root_and_old_edit_not_resent(native, gate, runner):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    root = next(r for r in gate.journal.records if r.get('role') == 'owner')
    gate.journal.deleted_messages.add(root['msg_id'])
    await gate.send('default', 'must not send', metadata={'thread_id': root['thread']})
    await settled_comments(native)
    assert not sent_calls(native)
    assert native.bridge.comments.outstanding(native.bridge.private()['comments'][-1])
    await dispatch(native, text='/hejo_comments_abort default', chat=-100)
    assert native.bridge.comments.route('default') == 'topic'


async def test_comments_partial_send_unknown_keeps_first_receipt(native, gate, runner):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    count = [0]
    def before(args):
        count[0] += 1
        if count[0] == 2:
            raise OSError('fixture lost response')
    native.api.before_send = before
    await gate.send('default', 'x' * 9000, metadata={'thread_id': runner.events[0].source.thread_id})
    await settled_comments(native)
    states = [r['status'] for r in native.bridge.comments.operations.values()]
    assert states == ['receipt', 'unknown', 'queued']
    native.bridge.comments = Comments(native.bridge)
    assert [r['status'] for r in native.bridge.comments.operations.values()] == states
    assert len(sent_calls(native)) == 2
    await gate.send('default', 'next while unknown', metadata={'thread_id': runner.events[0].source.thread_id})
    await settled_comments(native)
    assert len(sent_calls(native)) == 2


@pytest.mark.parametrize('wrong', ['body', 'origin', 'sender', 'reply'])
async def test_comments_resolve_rejects_wrong_target(native, gate, wrong):
    await outbound_ready(native)
    native.api.fail_send = True
    await gate.send('default', 'fixture answer', metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    native.api.fail_send = False
    op = next(iter(native.bridge.comments.operations.values()))
    target = fresh(native, 100, root=500).to_dict()['message']
    target['text'] = native.bridge.render(gate.journal.message(op['msg_id']))[0]
    extra = {}
    if wrong == 'body':
        target['text'] = 'different body'
    elif wrong == 'origin':
        target['forward_origin']['chat']['id'] = -999
    elif wrong == 'sender':
        extra['from'] = dict(id=101, is_bot=False, first_name='Other')
    else:
        target['chat']['id'] = -999
    await process(native, fresh(native, 101, text='/hejo_comments_resolve ' + op['operation'], reply_to_message=target, **extra))
    assert native.bridge.comments.operations[op['operation']]['status'] == 'unknown'


async def test_comments_attachment_outbound_alias_and_permissions(native, gate, runner, tmp_path):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    thread = runner.events[0].source.thread_id
    path = tmp_path / 'fixture.txt'
    path.write_text('fixture document')
    await gate.send_document('default', str(path), caption='attachment', metadata={'thread_id': thread})
    await settled_comments(native)
    assert [m for m, _ in native.api.calls if m.startswith('send')] == ['sendMessage', 'sendDocument']
    assert all(c['reply_parameters']['message_id'] == 100 for c in sent_calls(native))
    op = next(r for r in native.bridge.comments.operations.values() if r['media'] == 'document')
    await process(native, fresh(native, 101, reply=op['message_id']))
    assert runner.events[-1].source.thread_id == thread
    assert native.bridge.sent_path.stat().st_mode & 0o777 == 0o600
    content = native.bridge.sent_path.read_text()
    assert 'fixture document' not in content and 'fixture.txt' not in content
    assert 'channel_id' not in content and 'discussion_id' not in content


async def test_comments_native_reattach_single_handler(native):
    from gate.telegram_comments import attach
    before = len(native.app.handlers[0])
    attach(native.app)
    assert len(native.app.handlers[0]) == before
    await dispatch(native, chat=-999)
    assert native.core == [10] and native.observed == [10]


async def test_comments_settled_typing_deletion_and_buttons(native, gate, runner):
    await outbound_ready(native)
    await process(native, fresh(native, root=500))
    thread = runner.events[0].source.thread_id
    await gate.send_typing('default', {'thread_id': thread})
    await gate.send('default', 'waiting', metadata={'thread_id': thread})
    await asyncio.sleep(.03)
    assert not sent_calls(native)
    await gate.stop_typing('default', {'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    await gate.send('default', '🤔 생각 중…\nfixture thought', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    await gate.send('default', 'choose', metadata={'thread_id': thread,
        'hejo_buttons': [{'label': 'A', 'style': 'primary'}],
        '_hejo_native_buttons': [{'label': 'Open', 'kind': 'approval', 'style': 'default'}]})
    await settled_comments(native)
    assert sent_calls(native)[-1]['text'].endswith('choose\n선택: A\n(이 선택은 hejo 앱에서 눌러 주세요)')
    gate.journal.deleted_threads[('default', thread)] = {}
    count = len(sent_calls(native))
    await gate.send('default', 'deleted', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == count


async def test_comments_concurrent_threads_each_get_root_without_stranded_queue(native, gate):
    await outbound_ready(native)
    entered, release = asyncio.Event(), asyncio.Event()
    async def before(args):
        if int(args['chat_id']) == -200 and not entered.is_set():
            entered.set()
            await release.wait()
    native.api.before_send = before
    await gate.send('default', 'first', metadata={'thread_id': str(uuid.uuid4())})
    await asyncio.wait_for(entered.wait(), 2)
    await gate.send('default', 'second', metadata={'thread_id': str(uuid.uuid4())})
    await asyncio.sleep(.02)
    release.set()
    await settled_comments(native)
    assert len(sent_calls(native)) == 2
    assert all(int(c['chat_id']) == -200 for c in sent_calls(native))
    assert all(r['status'] == 'receipt' for r in native.bridge.comments.operations.values())


async def test_comments_unpair_during_send_does_not_enqueue_late_forward(native, gate, runner):
    await outbound_ready(native)
    async def before(args):
        await native.bridge.command(dict(type='telegram_unpair', id='fixture'), SimpleNamespace(features={'telegram'}))
    native.api.before_send = before
    await gate.send('default', 'x' * 9000, metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1
    assert native.bridge.private()['comments'][-1]['state'] == 'retired'
    assert all(r['status'] != 'queued' for r in native.bridge.comments.operations.values())
    await process(native, fresh(native, 100, root=native.api.next_message))
    assert not runner.events and not native.core


async def test_comments_damage_does_not_disable_unconverted_topic_epoch(native):
    native.bridge.comments.damaged = True
    assert native.bridge.comments.epoch('default') == 'legacy'
    assert native.bridge.comments.route('default') == 'topic'


async def test_comments_new_binding_new_epoch_and_same_thread(native, gate):
    await outbound_ready(native)
    thread = str(uuid.uuid4())
    await gate.send('default', 'first generation', metadata={'thread_id': thread})
    await settled_comments(native)
    op = next(r for r in native.bridge.comments.operations.values() if r['root'])
    await process(native, fresh(native, 100, root=op['message_id']))
    await dispatch(native, text='/hejo_comments_off default')
    old = native.bridge.private()['comments'][0]
    await dispatch(native, chat=-301, text='/hejo_comments_probe default')
    probe = native.bridge.private()['probes'][-1]
    root = native.bridge.comments.receipts[probe['tag'], 'channel']['message_id']
    await dispatch(native, chat=-301, forward=root)
    await dispatch(native, chat=-301, text='/hejo_comments_bind default')
    new = native.bridge.private()['comments'][-1]
    assert new['binding'] != old['binding'] and old['state'] == 'retired'
    native.api.calls.clear()
    await gate.send('default', 'new generation', metadata={'thread_id': thread})
    await settled_comments(native)
    assert len(sent_calls(native)) == 1 and int(sent_calls(native)[0]['chat_id']) == -201
    assert sent_calls(native)[0]['text'].startswith('이전 대화 이어쓰기 — 전환 이후 내용\n')
    assert 'first generation' not in sent_calls(native)[0]['text']


async def test_comments_two_bindings_same_ids_and_raw_thread_only(native, gate, runner):
    await activate(native)
    await dispatch(native, chat=-301, text='/hejo_comments_probe alpha')
    probe = native.bridge.private()['probes'][-1]
    root = native.bridge.comments.receipts[probe['tag'], 'channel']['message_id']
    await dispatch(native, chat=-301, forward=root)
    await dispatch(native, chat=-301, text='/hejo_comments_bind alpha')
    one = fresh(native, 100, root=500)
    data = one.to_dict()
    data['message']['chat']['id'] = -301
    data['message']['sender_chat']['id'] = -201
    data['message']['forward_origin']['chat']['id'] = -201
    two = Update.de_json(data, native.app.bot)
    await asyncio.gather(process(native, one), process(native, two))
    assert len(runner.events) == 2
    assert {e.source.profile for e in runner.events} == {'default', 'alpha'}
    assert len({e.source.thread_id for e in runner.events}) == 2
    await process(native, fresh(native, 101, message_thread_id=100))
    assert runner.events[-1].source.profile == 'default'
    assert runner.events[-1].source.thread_id == runner.events[0].source.thread_id


async def test_comments_intent_is_durable_before_network(native, gate):
    await outbound_ready(native)
    seen = []
    def before(args):
        restored = Comments(native.bridge)
        assert any(r['status'] == 'intent' for r in restored.operations.values())
        seen.append(True)
    native.api.before_send = before
    await gate.send('default', 'fixture', metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    assert seen == [True]


async def test_comments_new_pair_does_not_read_old_operation_status(native, gate):
    await outbound_ready(native)
    native.api.fail_send = True
    await gate.send('default', 'fixture', metadata={'thread_id': str(uuid.uuid4())})
    await settled_comments(native)
    op = next(iter(native.bridge.comments.operations))
    with native.bridge.vault.locked():
        value = native.bridge.private()
        native.bridge.retire_comments(value)
        value['pair']['tag'] = '87654321'
        native.bridge.vault.write('telegram.json', value)
    assert op not in native.bridge.comments.delivery_status(update(native, chat=-100).message)
    assert not native.bridge.comments.command(update(native, text='/hejo_comments_status').message)
