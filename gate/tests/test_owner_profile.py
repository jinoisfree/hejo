"""AT-OP-01–14 through real gate HTTP/WS and isolated external transports."""
from contextlib import asynccontextmanager
from importlib.util import module_from_spec, spec_from_file_location
import json
from pathlib import Path
import re
import uuid

from aiohttp import ClientSession
from jsonschema import Draft202012Validator
import pytest
import pytest_asyncio

from gate.adapter import HejoAdapter
from gate.auth import AuthStore
from gate.server import SCHEMA
from gate.tests.support import airport, registered, gate, client, runner, wait_for_turns
from gate.tests.test_pictures import png
from gate.tests.test_rooms import create
from gateway.config import PlatformConfig

def bridge_tests(platform):
    # Load the existing fake transports without requiring a global tests package.
    path = Path(__file__).resolve().parents[2] / "tests" / "acceptance" / f"test_{platform}.py"
    spec = spec_from_file_location(f"owner_profile_{platform}_fixtures", path)
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


discord = bridge_tests("discord")
discord_module = discord.discord_module
discord_transport = discord.transport

pytestmark = pytest.mark.asyncio
NAME = "길동"
LONG_NAME = "가나다라마바사아자차카타파하가나다라마바"
PICTURE = "/v1/pictures/owner/owner"
EMPTY = {"name": None, "avatar": None}


@pytest.fixture(autouse=True)
def allow_owner(airport, monkeypatch):
    monkeypatch.setenv("HEJO_ALLOWED_USERS", "owner")


@pytest_asyncio.fixture
async def http():
    async with ClientSession(trust_env=False) as session:
        async def request(gate, method, path, token=None, **fields):
            headers = {"Authorization": f"Bearer {token}"} if token else {}
            async with session.request(method, f"http://127.0.0.1:{gate.server.port}{path}",
                                       headers=headers, **fields) as response:
                if response.content_type == "application/json":
                    body = await response.json()
                elif response.content_type == "image/png":
                    body = await response.read()
                else:
                    body = await response.text()
                return response.status, body
        yield request


@asynccontextmanager
async def connected_gate():
    adapter = HejoAdapter(PlatformConfig(enabled=True, extra={"listen": ["127.0.0.1"], "port": 0}))
    assert await adapter.connect()
    try:
        yield adapter
    finally:
        await adapter.disconnect()


async def put_name(http, gate, token, name=NAME):
    status, body = await http(gate, "PUT", "/v1/owner", token, json={"name": name})
    assert status == 200
    assert body["ok"] is True
    return body["owner"]


def assert_avatar(address):
    assert re.fullmatch(re.escape(PICTURE) + r"\?v=[0-9]+", address)


@pytest.mark.parametrize("existing", [False, True])
async def test_at_op_01_permissions_and_restart(registered, airport, http, existing):
    directory = airport / "shared" / "hejo"
    if existing:
        directory.mkdir(parents=True)
        directory.chmod(0o755)
    else:
        assert not directory.exists()
    async with connected_gate() as first:
        _, token = first.auth.pair(first.auth.pair_code(), "Test device")
        assert await put_name(http, first, token) == {**EMPTY, "name": NAME}
        owner_file = directory / "owner.json"
        assert owner_file.stat().st_mode & 0o777 == 0o600
        assert json.loads(owner_file.read_text()) == {"v": 1, "name": NAME}
    async with connected_gate() as restarted:
        assert await http(restarted, "GET", "/v1/owner", token) == (
            200, {"ok": True, "owner": {**EMPTY, "name": NAME}})
        assert (await http(restarted, "PUT", PICTURE, token, data=png()))[0] == 200
    assert directory.stat().st_mode & 0o777 == (0o755 if existing else 0o700)
    assert (directory / "pictures").stat().st_mode & 0o777 == 0o700
    assert (directory / "pictures" / "owner.png").stat().st_mode & 0o777 == 0o600


async def test_at_op_02_trim_and_clear(gate, client, http, airport):
    _, welcome = await client.pair()
    token = welcome["token"]
    assert await put_name(http, gate, token, f"  {NAME}  ") == {**EMPTY, "name": NAME}
    for value in (None, "", "   "):
        assert await put_name(http, gate, token, value) == EMPTY
        assert json.loads((airport / "shared/hejo/owner.json").read_text()) == {"v": 1, "name": None}


async def test_at_op_03_invalid_name_preserves_value(gate, client, http):
    _, welcome = await client.pair()
    token = welcome["token"]
    assert len(LONG_NAME) == 20
    assert (await put_name(http, gate, token, LONG_NAME))["name"] == LONG_NAME
    invalid = [{"json": {"name": value}} for value in
               (LONG_NAME + "사", "a\nb", "\u0007", "a\u2028b", 123, [])]
    for fields in [*invalid, {"data": "not json"}]:
        assert await http(gate, "PUT", "/v1/owner", token, **fields) == (400, "invalid_name")
    assert await http(gate, "GET", "/v1/owner", token) == (
        200, {"ok": True, "owner": {**EMPTY, "name": LONG_NAME}})


async def test_at_op_04_unauthorized_member_cannot_write(gate, client, http, tmp_path):
    _, welcome = await client.pair()
    token = welcome["token"]
    assert (await put_name(http, gate, token))["name"] == NAME
    other = AuthStore(tmp_path / "other-member")
    _, foreign_token = other.pair(other.pair_code(), "Other test device")
    for credential in (None, foreign_token):
        assert (await http(gate, "PUT", "/v1/owner", credential, json={"name": None}))[0] == 401
        assert (await http(gate, "GET", "/v1/owner", credential))[0] == 401
    assert (await http(gate, "GET", "/v1/owner", token))[1]["owner"]["name"] == NAME


async def test_at_op_05_picture_round_trip_and_validation(gate, client, http, airport):
    _, welcome = await client.pair()
    token = welcome["token"]
    data = png()
    status, body = await http(gate, "PUT", PICTURE, token, data=data)
    assert status == 200
    assert_avatar(body["picture"])
    assert body["owner"] == {**EMPTY, "avatar": body["picture"]}
    assert await http(gate, "GET", body["picture"], token) == (200, data)
    assert (airport / "shared/hejo/pictures/owner.png").stat().st_mode & 0o777 == 0o600
    assert (await http(gate, "PUT", "/v1/pictures/owner/x", token, data=data))[0] == 404
    assert await http(gate, "PUT", PICTURE, token, data=b"invalid") == (415, "invalid_picture")
    assert (await http(gate, "PUT", PICTURE, token, data=b"x" * (512 * 1024 + 1)))[0] == 413
    assert await http(gate, "GET", PICTURE, token) == (200, data)
    assert await http(gate, "DELETE", PICTURE, token) == (
        200, {"ok": True, "picture": None, "owner": EMPTY})
    assert (await http(gate, "GET", PICTURE, token))[0] == 404


@pytest.mark.parametrize("symlink", [False, True])
async def test_at_op_06_broken_file_or_symlink_replaced(registered, airport, http, symlink):
    path = airport / "shared/hejo/owner.json"
    path.parent.mkdir(parents=True)
    target = airport / "fixture.json"
    original = '{"v":1,"name":"가짜"}'
    if symlink:
        target.write_text(original)
        path.symlink_to(target)
    else:
        path.write_text("{")
    async with connected_gate() as gate:
        _, token = gate.auth.pair(gate.auth.pair_code(), "Test device")
        async with ClientSession(trust_env=False) as session:
            async with session.ws_connect(f"http://127.0.0.1:{gate.server.port}/v1/ws") as ws:
                await ws.send_json({"v": 1, "type": "hello", "device_name": "Test device",
                                    "app_version": "test", "token": token})
                first = await ws.receive_json(timeout=5)
                assert first["type"] == "welcome" and first["owner"] == EMPTY
        assert await http(gate, "GET", "/v1/owner", token) == (200, {"ok": True, "owner": EMPTY})
        assert (await put_name(http, gate, token)) == {**EMPTY, "name": NAME}
        assert not path.is_symlink()
        assert json.loads(path.read_text()) == {"v": 1, "name": NAME}
        if symlink:
            assert target.read_text() == original


async def test_at_op_07_09_welcome_and_old_frame(gate, client, http):
    _, first = await client.pair()
    assert first["owner"] == EMPTY
    token = first["token"]
    await put_name(http, gate, token)
    status, picture = await http(gate, "PUT", PICTURE, token, data=png())
    assert status == 200
    _, current = await client.open(token=token)
    assert current["owner"] == {"name": NAME, "avatar": picture["picture"]}
    assert_avatar(current["owner"]["avatar"])
    # client.read validates each frame against serverFrame, including welcome and roster.
    validator = Draft202012Validator({**SCHEMA, "$ref": "#/$defs/serverFrame"})
    validator.validate({key: value for key, value in first.items() if key != "owner"})


async def test_at_op_08_09_roster_notifications_and_requested_snapshot(gate, client, http):
    first, welcome = await client.pair()
    second, other = await client.pair()
    assert other["device_id"] != welcome["device_id"]
    token = welcome["token"]

    async def broadcast(ref, profile):
        for ws in (first, second):
            frame = await client.read(ws)
            assert frame["type"] == "roster" and frame["ref"] == ref
            assert frame["owner"] == profile

    assert await put_name(http, gate, token) == {**EMPTY, "name": NAME}
    await broadcast("owner", {**EMPTY, "name": NAME})
    status, picture = await http(gate, "PUT", PICTURE, token, data=png())
    assert status == 200
    assert_avatar(picture["picture"])
    await broadcast("owner", {"name": NAME, "avatar": picture["picture"]})
    assert (await http(gate, "DELETE", PICTURE, token))[0] == 200
    await broadcast("owner", {**EMPTY, "name": NAME})
    assert (await http(gate, "PUT", "/v1/pictures/employee/alpha", token, data=png()))[0] == 200
    await broadcast("picture", {**EMPTY, "name": NAME})
    status, picture = await http(gate, "PUT", PICTURE, token, data=png())
    assert status == 200
    with_picture = {"name": NAME, "avatar": picture["picture"]}
    await broadcast("owner", with_picture)
    await first.send_json({"v": 1, "type": "roster", "id": "roster-request"})
    response = await client.read(first)
    assert response["type"] == "roster" and response["ref"] == "roster-request"
    assert response["owner"] == with_picture


async def test_at_op_10_discord_owner_name(gate, client, http, runner, discord_transport):
    _, native = discord_transport
    ws, welcome = await client.pair(features=["discord"])
    await discord.activate(gate, client, ws, native)
    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text="first")
    await wait_for_turns(runner, 1)
    await discord.settled(gate)
    assert [call[1]["username"] for call in native.calls] == ["사장"]
    assert (await put_name(http, gate, welcome["token"]))["name"] == NAME
    await client.send(ws, thread=thread, text="second")
    await wait_for_turns(runner, 2)
    await discord.settled(gate)
    assert [call[1]["username"] for call in native.calls] == ["사장", NAME]


async def test_at_op_14_discord_name_changes_only_new_posts(gate, client, http, runner, discord_transport):
    _, native = discord_transport
    ws, welcome = await client.pair(features=["discord"])
    await discord.activate(gate, client, ws, native)
    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text="first")
    await wait_for_turns(runner, 1)
    await discord.settled(gate)
    assert [(fields["username"], fields["content"]) for _, fields in native.calls] == [("사장", "first")]

    first_id = runner.events[0].message_id
    journal_segment, first_line = next(
        (segment, line)
        for segment in gate.journal.path.glob("????-??.jsonl")
        for line in segment.read_bytes().splitlines(keepends=True)
        if json.loads(line).get("msg_id") == first_id
    )
    sent_path = gate.discord.sent_path
    first_mapping = sent_path.read_bytes()
    assert json.loads(first_line)["text"] == "first"
    assert len(first_mapping.splitlines()) == 1

    assert (await put_name(http, gate, welcome["token"]))["name"] == NAME
    assert first_line in journal_segment.read_bytes().splitlines(keepends=True)
    assert sent_path.read_bytes() == first_mapping

    await client.send(ws, thread=thread, text="second")
    await wait_for_turns(runner, 2)
    await discord.settled(gate)
    assert [(fields["username"], fields["content"]) for _, fields in native.calls] == [
        ("사장", "first"), (NAME, "second"),
    ]
    assert first_line in journal_segment.read_bytes().splitlines(keepends=True)
    mapping = sent_path.read_bytes()
    assert mapping.startswith(first_mapping) and len(mapping.splitlines()) == 2


@pytest.mark.parametrize("name", [None, NAME])
async def test_at_op_11_thread_and_room_context(name, gate, client, http, runner, monkeypatch):
    original = gate.employees
    monkeypatch.setattr(gate, "employees", lambda: [
        {**employee, "name": "알파"} if employee["id"] == "alpha" else employee
        for employee in original()
    ])
    ws, welcome = await client.pair(features=["rooms"])
    if name is not None:
        await put_name(http, gate, welcome["token"], name)
        assert (await client.read(ws))["type"] == "roster"
    room = await create(client, ws)
    label = name or "나"
    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text="owner text")
    await client.until(ws, "message")
    await wait_for_turns(runner, 1)
    await gate.send("alpha", "employee text", metadata={"thread_id": thread})
    await client.until(ws, "message")
    await client.send(ws, thread=thread, text="next")
    await client.until(ws, "message")
    await wait_for_turns(runner, 2)
    assert runner.events[-1].channel_context.splitlines()[1:] == [
        f"{label}: owner text", "알파: employee text"]

    await client.send(ws, thread=thread, text="@alpha owner text", room=room)
    await wait_for_turns(runner, 3)
    assert (await gate.send(f"room:{room}", "employee text",
                            metadata={"thread_id": thread, "hermes_profile": "alpha"})).success
    await client.send(ws, thread=thread, text="@beta next", room=room)
    await wait_for_turns(runner, 4)
    assert runner.events[-1].text.splitlines()[1:3] == [
        f"{label}: @alpha owner text", "알파: employee text"]


async def test_at_op_12_hermes_identity_stays_stable(gate, client, http, runner):
    ws, welcome = await client.pair()
    thread = str(uuid.uuid4())
    await client.send(ws, thread=thread, text="first")
    await wait_for_turns(runner, 1)
    first = runner.events[0].source
    assert first.user_name is None
    await put_name(http, gate, welcome["token"])
    await client.send(ws, thread=thread, text="second")
    await wait_for_turns(runner, 2)
    current = runner.events[1].source
    assert current.user_name == NAME
    assert current.user_id == first.user_id == "owner"
    assert current.chat_id == first.chat_id == "alpha"
    assert current.thread_id == first.thread_id == thread
    assert runner.keys[0] == runner.keys[1]


@pytest.mark.parametrize("name", [None, NAME])
async def test_at_op_13_clarify_decision_name(name, gate, client, http, monkeypatch):
    from agent.i18n import t
    from tools import clarify_gateway
    monkeypatch.setattr(clarify_gateway, "resolve_gateway_clarify", lambda *args: True)
    ws, welcome = await client.pair()
    if name is not None:
        await put_name(http, gate, welcome["token"], name)
    await gate.send_clarify("alpha", "Choose", ["A"], "fixture-clarify", "fixture-session")
    question = (await client.until(ws, "message"))[-1]
    await ws.send_json({"v": 1, "type": "click", "id": "fixture-click",
                        "msg_id": question["msg_id"], "button_id": question["buttons"][0]["id"]})
    edit = (await client.until(ws, "edit"))[-1]
    assert edit["text"] == "Choose\n\n" + t("platform.slack.clarify.resolved", user=name or "나", choice="A")
