"""AT-HF-68: real authenticated HTTP and roster broadcasts, isolated profiles."""
import os
import struct
import zlib
from pathlib import Path
import aiohttp
import pytest
from gate.tests.support import airport, registered, gate, client


def png():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\0\xff\0\0\xff")) + chunk(b"IEND", b"")


def test_roster_sources_and_colors(airport):
    from hermes_cli.profiles import profiles_to_serve
    from gate.roster import employees
    homes = dict(profiles_to_serve(True))
    for name, color in (("default", "'#12aBcD'"), ("alpha", "'hsl(-120, 100%, 50%)'"), ("beta", "'invalid'")):
        home = Path(homes[name]); (home / "assets").mkdir(exist_ok=True)
        (home / "profile.yaml").write_text(f"other:\n  color: '#FFFFFF'\nui_meta:\n  hermes-bots:\n    color: {color}\n")
    alpha = Path(homes["alpha"]); (alpha / "assets/slack-avatar.png").write_bytes(png())
    rows = {e["id"]: e for e in employees()}
    assert rows["default"]["avatar"] is None and rows["default"]["color"] == "#12ABCD"
    assert rows["alpha"]["avatar"] and not rows["alpha"]["avatar_custom"] and rows["alpha"]["color"] == "#0000FF"
    assert rows["beta"]["color"] is None
    (alpha / "assets/avatar.png").write_bytes(png())
    assert next(e for e in employees() if e["id"] == "alpha")["avatar_custom"]
    (alpha / "profile.yaml").write_text("color: '#FF0000'\nother:\n  color: '#FF0000'\n")
    assert next(e for e in employees() if e["id"] == "alpha")["color"] is None


@pytest.mark.asyncio
async def test_employee_http_and_two_device_broadcast(gate, client, airport):
    from hermes_cli.profiles import profiles_to_serve
    home = Path(dict(profiles_to_serve(True))["alpha"])
    (home / "assets").mkdir(exist_ok=True)
    fallback = home / "assets/slack-avatar.png"; fallback.write_bytes(png())
    profile = home / "profile.yaml"; before = profile.read_bytes() if profile.exists() else None
    ws, welcome = await client.pair(); ws2, _ = await client.pair()
    token = welcome["token"]
    url = f"http://127.0.0.1:{gate.server.port}/v1/pictures/employee/alpha"
    async with aiohttp.ClientSession(trust_env=False) as http:
        for method in (http.get, http.put, http.delete):
            async with method(url, data=png() if method == http.put else None) as response:
                assert response.status == 401
        async with http.put(url, data=png(), headers={"Authorization": "Bearer unrelated-member"}) as response:
            assert response.status == 401
        headers = {"Authorization": "Bearer " + token}
        async with http.put(url, data=png(), headers=headers) as response:
            assert response.status == 200
        for connection in (ws, ws2):
            row = next(e for e in (await client.read(connection))["employees"] if e["id"] == "alpha")
            assert row["avatar_custom"] and row["avatar"].startswith("/v1/pictures/employee/alpha?v=")
        target = home / "assets/avatar.png"
        assert target.read_bytes() == png() and target.stat().st_mode & 0o777 == 0o644
        async with http.get(url, headers=headers) as response:
            assert response.status == 200 and await response.read() == png()
        for data, expected in ((b"x" * (513 * 1024), 413), (b"not an image", 415), (png()[:-1], 415)):
            async with http.put(url, data=data, headers=headers) as response:
                assert response.status == expected
            assert target.read_bytes() == png()
        async with http.delete(url, headers=headers) as response:
            assert response.status == 200
        for connection in (ws, ws2):
            row = next(e for e in (await client.read(connection))["employees"] if e["id"] == "alpha")
            assert row["avatar"] and not row["avatar_custom"]
        assert not target.exists() and fallback.read_bytes() == png()
        assert (profile.read_bytes() if profile.exists() else None) == before
        async with http.get(url, headers=headers) as response:
            assert await response.read() == png()
        async with http.get(url.replace("pictures/employee/alpha", "avatars/alpha"), headers=headers) as response:
            assert response.status == 404
        shared = url.replace("employee/alpha", "room/section-1")
        async with http.put(shared, data=png(), headers=headers) as response:
            assert response.status == 200
            address = (await response.json())["picture"]
        picture = airport / "shared/hejo/pictures/section-1.png"
        assert picture.stat().st_mode & 0o777 == 0o600 and picture.parent.stat().st_mode & 0o777 == 0o700
        assert address == f"/v1/pictures/room/section-1?v={picture.stat().st_mtime_ns}"
        assert not list(picture.parent.glob("employee-*"))
        async with http.delete(shared, headers=headers) as response:
            assert response.status == 200 and not picture.exists()


def test_atomic_failure_and_symlink(airport, monkeypatch):
    from gate.pictures import Pictures
    pictures = Pictures(airport)
    target = pictures.put("employee", "beta", png())
    def fail(*args):
        raise OSError("injected")
    with monkeypatch.context() as patch:
        patch.setattr(os, "replace", fail)
        with pytest.raises(OSError):
            pictures.put("employee", "beta", png() + b"changed")
    assert target.read_bytes() == png() and not list(target.parent.glob(".picture-*"))
    target.unlink(); target.symlink_to(airport / "unrelated")
    with pytest.raises(KeyError):
        pictures.put("employee", "beta", png())
    with pytest.raises(KeyError):
        pictures.put("room", "../outside", png())


def test_png_truncated_compressed_stream():
    from gate.pictures import valid_png
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    # A valid signature and chunk CRC must not hide a truncated pixel stream,
    # including after the bounded decoder has emitted more than one output block.
    header = chunk(b"IHDR", struct.pack(">IIBBBBB", 2048, 2048, 8, 6, 0, 0, 0))
    compressed = zlib.compress(b"\0" * (2048 * 2048 * 4 + 2048))
    data = b"\x89PNG\r\n\x1a\n" + header + chunk(b"IDAT", compressed[:-2]) + chunk(b"IEND", b"")
    assert not valid_png(data)


@pytest.mark.parametrize("value,expected", [("hsl(240 100% 50%)", "#0000FF"), ("hsl(2.4e2, +100%, 50%)", "#0000FF"), ("hsl(inf 50% 50%)", None), ("hsl(240 101% 50%)", None)])
def test_source_hsl_forms(airport, value, expected):
    from gate.pictures import profile_color
    (airport / "profile.yaml").write_text("ui_meta:\n  hermes-bots:\n    color: '" + value + "'\n")
    assert profile_color(airport) == expected
