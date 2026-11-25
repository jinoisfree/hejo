# HEJO-DISCORD 설계

- 상태: 초안 2판(2026-11-24, 계획 검증 1회차 PR-01~05 반영 — [plan-review.md](plan-review.md)). 1판은 1회차 BLOCKED. 요구는 [spec.md](spec.md), 칸 배치는 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)이 원본이다. [HEJO-TELEGRAM design](../HEJO-TELEGRAM-20261122/design.md)의 정착·나누기·대응 저장 결정을 이어받고 다른 점만 적는다.
- 경로 약어: `R` = Hermes 본체(`~/.hermes/hermes-agent`), `D` = `R/plugins/platforms/discord/adapter.py`, `B` = `R/gateway/platforms/base.py`. 근거 줄은 2026-11-24 읽기, 기준 커밋 `236b017`.

## 1. 현황 (근거)

| 사실 | 근거 |
|---|---|
| 처리기 공장은 `factory(native, adapter)`. 디스코드의 `native`는 discord.py `commands.Bot`이고, 공장은 **연결(ready)이 끝난 뒤** 불린다. 재구성되면 새 봇으로 다시 불린다 | `R/hermes_cli/plugins.py:859-874`, `D:1322-1326,1425-1427`, `B:2341-2371` |
| 원래 수신: `@client.event on_message` → `_dispatch_discord_message` → 들이기 판정 `_discord_message_admission` → 통과하면 `_handle_message` | `D:1361-1363,1566-1575` |
| 들이기 판정은 중복·자기 글·글 종류를 본 뒤 **봇 글은 `allow_bots`(기본 `none`이면 거부)**, **사람 글은 `_is_allowed_user`**로 거르며, 거부면 어떤 부작용도 없이 `False`를 돌려준다 | `D:1483-1530`, `D:4980-4983` |
| `_is_allowed_user`: 디스코드 짝 승인 사용자면 참. 허용 사용자·역할이 없으면 디스코드 전체 허용·게이트웨이 전체 허용·허용 채널(1:1 아님)일 때만 참, 아니면 **거짓(닫힘 기본값, 경고 1회)** | `D:3929-3990`, `D:4023-4038`, `D:4971-4980` |
| `_handle_message`는 통과한 글에 대해 봇 멘션을 지운 본문을 `message.content`에 다시 쓰고, 일반 글 채널 멘션이면 자동 스레드를 만들며 실패 시 안내를 보내고, 첨부를 모으고 기록을 당겨 온 뒤 `handle_message`를 부른다 | `D:6021-6040,6074-6114,6161-6187,6223-6227` (계획 검증 PR-01) |
| 그래서 `handle_message`를 감싸 버리는 방식은 부작용을 막지 못한다. 부작용 전 단계에서 거부되게 하는 방법은 들이기 판정(설정으로 닫힘)뿐이다 | 위 줄에서 도출 [확인] |
| 원래 어댑터의 글 묶음 만들기·고침·지움 처리는 플랫폼 이벤트 구독자가 있을 때만 이벤트를 내보내며 차례를 만들지 않는다 | `D:1365-1375`, `D:1612`, 이벤트 발행 함수(`_emit_platform_event`) |
| `commands.Bot.add_listener`로 붙인 듣기는 `@client.event` 처리기와 별도로 함께 불린다 | discord.py 2.x 공개 API [가정 — 구현에서 원본으로 확인] |
| 수신 글의 글 묶음: `message.channel`이 `discord.Thread`이면 `parent_id`가 포럼 채널 | `D:2016-2019,1579-1587` |
| 한 글 한도 2000자 | `D:1056` |
| REST `POST /channels/{id}/typing` 한 번은 약 10초 유지. 어댑터 `send_typing`은 12초 반복+`stop_typing` 필요 | `D:4250-4295` |
| Hermes 시험은 discord.py 없이 `sys.modules`에 가짜 `discord` 모듈을 넣고 실제 `DiscordAdapter`를 import해 들이기·멘션 판정을 시험한다 | `R/tests/gateway/test_discord_free_response.py:16-53` (시험 방법 선례) |
| Hermes 환경에 discord.py가 설치돼 있지 않다 | `R/venv/lib/python*/site-packages`에 `discord*` 없음, `R/pyproject.toml:265,332` |
| 운영 공항의 어느 프로필도 지금 디스코드 플랫폼을 켜지 않았다 | 각 `config.yaml` `platforms` 절 읽기 [확인 — 비밀 파일은 열지 않음; TASK-03에서 다시 확인] |
| hejo 문의 텔레그램 다리 호출 자리 | `gate/adapter.py:51,122-123,134-135,147-148,175-176,214-215,702,802-803,828-831`, `gate/server.py:479-480`, `gate/__init__.py:30-31` |
| 포럼 채널은 커뮤니티 서버에서만 만들 수 있다 | Discord 고객센터 "What are Forum Channels?"(support.discord.com/hc/en-us/articles/6208479917079) |
| 웹후크로 올리는 파일 한도는 공식 문서로 확인하지 못했다(제3자 자료 8MB~25MB 엇갈림) | [미확인] → 5절 보수 상수 |

## 2. 책임과 흐름

새 모듈 `gate/discord.py` 하나가 디스코드 창을 맡는다. 책임: 금고·설정·채널 대응·보낸 글 대응 저장, 수신 판정, 닫힘 확인, 채널 동기화, 발신, 작성 중, 상태 프레임. `adapter.py`·`server.py`·`__init__.py`·`schemas`는 부르기·등록만 더한다.

```text
[수신]  discord.py 봇 ─┬ (원래) on_message → 들이기 판정: 닫힘 운영이라 거부(부작용 없음)
                      └ (hejo) add_listener('on_message') → Discord.on_message(message)
                               → 무시 | 짝짓기 | 안내 | 닫힘 열림 알림 | receive(frame, ExternalReply)

[발신]  HejoAdapter._record → telegram.recorded(row); discord.recorded(row)   ← message 레코드
        RoomCommands.room_command(gate/rooms.py) → 텔레그램 알림 바로 옆에서 discord.recorded(saved)   ← room/room_delete 레코드
          ├ room/room_delete 레코드 → 채널 동기화
          └ message 레코드 → 스레드 대기열 → (사장 글 즉시 | 직원 글 정착 뒤)
               → 현재 채널의 대응 글 묶음 있음: 웹후크 발신(thread=글 묶음)
                 없음 / 글 묶음 없음 실패: 웹후크 발신(thread_name, 새 포럼 글)
```

방 레코드 경로(검증 1회 V-1 보완, 2026-11-24): 방 만들기·이름 바꾸기·보관·삭제는 `_record`를 거치지 않고 `gate/rooms.py`의 `room_command`가 직접 기록·방송한 뒤 텔레그램 다리에만 알린다(`236b017` 기준 51~85행). 그래서 `room_command`가 텔레그램과 같은 방식으로(잠금 안에서 다리를 잡고, 잠금 밖에서 `recorded(saved)`) 디스코드 다리에도 알린다. 이 한 곳 외에 `rooms.py`의 동작·기록 경로는 바꾸지 않으며, 주기 동기화나 공통 알림 추상화를 만들지 않는다.

수신의 유일한 경로는 hejo 듣기다. 원래 처리기는 감싸지도 바꾸지도 않는다. 두 경로가 같은 글을 처리하지 않는다는 보장은 "닫힘 운영"(spec 제약)이며, 문은 글마다 닫힘 확인으로 이를 검증하고 열려 있으면 물러난다(그 글은 원래 처리기 몫).

### 2.1 공장 `attach_discord(native, adapter)`

- `gate/__init__.py`가 `ctx.register_platform_handler("discord", attach_discord)`를 더한다(텔레그램 등록 유지).
- 공장은 네트워크 작업을 하지 않는다: 전역 `_discord`(어댑터)·`_bot`(native)을 바꾸고 `native.add_listener(hejo_on_message, 'on_message')`를 같은 봇에 한 번만(표지 속성) 붙인다. `adapter.handle_message`는 감싸지 않는다. `HejoAdapter.claims_external`은 바꾸지 않는다(텔레그램 전용으로 남음).
- `platform_ready()` = `_discord is not None and _discord.is_connected and _bot is not None`.

### 2.2 닫힘 확인 `closed_for(message)`

참이려면 모두: `_discord._get_allow_bots() == "none"`, 그리고 `_discord._is_allowed_user(str(author.id), author, guild=message.guild, is_dm=False, channel_ids={채널 id, 부모 id})`가 거짓. 어느 호출이든 예외면 거짓(열린 것으로 봄). 상태의 `core_open`은 짝지은 서버·사장 계정·빈 채널 집합 기준 값과 마지막 수신 글의 값을 OR한다. 비공개 메서드 사용은 텔레그램 다리(`_bot`, `_accept_update`)와 같은 수준의 의존이며, 이름이 사라지면 예외 → 열림 → hejo가 물러나는 안전한 쪽으로 실패한다.

### 2.3 `Discord.on_message(message)` 판정 순서

1. `message.guild`가 없거나(1:1), 작성자가 봇이거나, `message.webhook_id`가 있으면 무시.
2. 금고·설정을 읽지 못하면 무시.
3. `closed_for(message)`가 거짓이면 무시(짝지은 서버의 사장 글이면 로그 `discord_core_open` 한 줄, `core_open` 참 방송).
4. 유효 코드면 금고 잠금 안에서 다시 확인 후 짝짓기, 그 채널에 "연결됐어요", 방송, 동기화 요청. 끝.
5. 활성이 아니거나 짝 서버·사장 계정이 아니면 무시.
6. `client_msg_id = discord:{tag}:{채널 id}:{글 묶음 id}:{글 id}`(글 묶음이 아니면 글 묶음 자리는 `-`)가 기록장에 있으면 무시.
7. 채널이 글 묶음이고 부모가 열린 방 채널(현재 표지 `channels.json`, `closed` 거짓, 방이 쓸 수 있음)이면 방을 정한다. 아니면 "앱에서 만든 방 채널에 써 주세요" 후 끝.
8. 스레드: 4절 디스코드 → hejo 규칙. 새 포럼 글의 첫 글이면 본문 = 제목 규칙(REQ-HD-04.AC-01).
9. 본문은 `message.content` 원문(앞뒤 공백 제거)이다. 원래 처리기가 거부하므로 바뀌지 않는다.
10. 첨부: `attachment.size` 50 MiB 이하 확인 후 임시 폴더로 내려받아 `files.copy(employee, path)`. 실패·초과·본문 `text_bytes` 초과는 "지금은 받지 못했어요".
11. `receive({employee, thread, text, client_msg_id, files, room?}, ExternalReply)` — 받는 직원 규칙은 텔레그램과 같다.

## 3. 저장 형식

| 파일 | 형식 |
|---|---|
| `<HOME>/hejo/discord.json` | `{pair: null | {platform:"discord", guild_id, user_id, tag(8자 hex), paired_at}, code: null | {hash, expires, used}}` — 텔레그램 `telegram.json`과 같은 검증 규칙 |
| `shared/hejo/discord/settings.json` | `{enabled: bool}` |
| `shared/hejo/discord/channels.json` | `{tag, category: id|null, archive: id|null, channels: {방 id: {channel, name, closed}}}` — `tag`가 현재 짝 표지와 다르면 빈 것으로 본다 |
| `shared/hejo/discord/sent.jsonl` | 줄마다 `{tag, ch, post, dc, msg_id}`(`ch` = 그 글을 보낸 포럼 채널, `post` = 글 묶음, `dc` = 디스코드 글). 덜 쓰인 끝 줄은 시작 때 자르고 깨진 줄은 건너뛴다 |

저장은 텔레그램과 같은 `AuthStore` 잠금·원자적 교체·0600. 웹후크(id·토큰)는 채널별 메모리 캐시이며 없으면 `channel.webhooks()`에서 이 봇이 만든 `hejo` 웹후크를 찾고 없으면 `create_webhook(name="hejo")`.

## 4. 글 묶음 ↔ hejo 스레드 대응 (따로 저장하지 않음)

대응 사건 = 현재 표지의 (a) 기록장에서 `client_msg_id`가 `discord:{tag}:`로 시작하는 사장 글 행(채널·글 묶음은 그 id에서), (b) `sent.jsonl` 줄. 사건마다 `(ch, post, hejo 글 → 스레드 K, 기록 순서)`. 기록 순서는 그 hejo 글의 기록장 `seq`다.

- **디스코드 → hejo:** 글 묶음 `P`의 대응 = `post == P`인 사건 중 `seq`가 가장 큰 것의 스레드 `K`. `K`가 삭제됐거나 방이 쓸 수 없으면 대응 없음 → 새 스레드. 새 스레드에 기록되는 순간 그 글이 `P`의 가장 나중 사건이 되므로 이후 글도 새 스레드로 간다.
- **hejo → 디스코드:** 스레드 `K`의 글 묶음 = 스레드 `K`이고 `ch`가 **현재 그 방의 `channels.json` 채널**인 사건 중 `seq`가 가장 큰 것의 `post`. 없으면 새 포럼 글. 그래서 방 채널이 지워져 새로 만들어지면 옛 채널의 글 묶음은 고르지 않고, 첫 발신이 새 채널에 글 묶음을 만들며, 그 사건이 이후 발신·재시작 뒤에도 선택된다.
- **글 묶음 없음 대체:** 글 묶음 안 웹후크 발신이 "없음"(HTTP 404 / discord.py `NotFound`)으로 실패하면 그 글을 새 포럼 글로 한 번 보낸다. 다른 실패는 로그만. 단, 대체 발신(새 포럼 글)까지 "없음"으로 실패하면 웹후크 자체가 지워진 것이므로 그 채널의 웹후크 메모리 캐시를 버려 다음 글에서 다시 찾거나 만들게 한다(검증 3회 F-1). 그 글은 다시 보내지 않는다.
- 시작 때 `sent.jsonl`을 메모리 색인으로 읽는다. 기록장 쪽 사건은 기록장 레코드에서 계산한다.

## 5. 발신

- 대기열·정착·작성 중 대기·생각 중 제외·활성/표지 재확인은 텔레그램 `recorded`·`_settle`·`settled_row`와 같다(`SETTLE_SECONDS = 2.0`).
- 보낼 대상: `role == "employee"` 또는 `client_msg_id`가 `discord:`로 시작하지 않는 사장 글.
- 이름: 직원 = 명부 표시 이름, 사장 = `사장`. 본문에 이름표를 붙이지 않는다.
- 새 포럼 글 제목: 본문(버튼·📎 덧붙임 전)의 첫 번째 비어 있지 않은 줄(앞뒤 공백 제거)의 앞 100자, 없으면 `새 대화`.
- 렌더는 텔레그램 `render`의 버튼 줄·📎 줄 규칙과 같다. 첨부 한도 `MAX_SEND_FILE_BYTES = 8 * 1024 * 1024`: 실제 한도가 [미확인]이라 엇갈린 자료 중 가장 낮은 값으로 정한 **보수 상수**다. 실물에서 이 상수의 동작(넘는 파일은 📎 줄)을 확인할 뿐 디스코드의 실제 한도는 확인하지 않는다. 올리려면 근거를 갖춘 별도 변경.
- 2000자 나누기: 줄 경계 우선, 순서대로. 첫 통이 새 포럼 글이면 그 결과의 글 묶음을 이후 통에 쓴다. 모든 통을 `sent.jsonl`에 적는다.
- 첨부는 본문 마지막 통 뒤 같은 글 묶음에 하나씩.
- 모든 웹후크 발신은 `allowed_mentions = AllowedMentions.none()`, `wait=True`.
- 실패: 로그 `discord_send_failed kind=<예외 이름>` 한 줄, 4절 대체 외에는 다시 보내지 않음.

## 6. 채널 동기화

텔레그램 `sync_topics`와 같은 잠금·재확인 구조. 대상 서버는 `_bot.get_guild(pair.guild_id)`. 분류 `hejo`·`hejo 보관`은 없으면 만들고 id를 `channels.json`에 둔다. 방 채널: 없으면 `guild.create_forum(name, category=hejo)`, 이름이 다르면 `edit(name=)`, 닫힘이 다르면 `edit(category=보관 또는 hejo)`. 저장된 채널을 찾을 수 없으면(사장이 지움) 대응을 새 채널로 바꾼다(옛 글 묶음은 4절 규칙으로 더는 고르지 않음). 실패하면 `discord_channel_failed kind=…`, `channel_problem` 참.

## 7. 작성 중

문의 `send_typing`이 디스코드 다리의 `send_typing(key)`를 부르면(텔레그램 옆), 활성·4절 글 묶음 있음·`typing(key)` 참일 때 `_bot.http.send_typing(글 묶음 id)`. 같은 글 묶음은 `TYPING_SECONDS = 8.0` 안에 다시 보내지 않는다. 실패는 경고 한 줄.

## 8. 기존 경로 판정

| 대상 | 판정 | 내용 |
|---|---|---|
| 텔레그램 다리 `gate/telegram.py`·`telegram_comments.py` | 유지 | 손대지 않는다. 같은 기록장을 비추는 독립 창. 권위 원본은 기록장, 창마다 자기 대응 파일만 쓴다, 두 창이 같은 글을 보내는 것은 의도(서로 다른 메신저). 종료 조건: 디스코드 안정 뒤 별도 작업에서 텔레그램 창 제거(사장 결정) |
| `HejoAdapter`의 텔레그램 호출 자리 | 옆에 더함 | 텔레그램 제거가 예정돼 공통 추상화를 만들지 않는다. 제거 작업이 그 자리를 지운다 |
| `adapter.claims_external` | 유지 | 디스코드는 쓰지 않는다 |
| 디스코드 어댑터 원래 처리 | 유지(감싸지 않음) | 닫힘 운영으로 거부. 문은 확인만 |

## 9. 대안

| 대안 | 판단 |
|---|---|
| A. hejo 듣기 + 닫힘 운영(들이기 판정에서 거부) + 글마다 닫힘 확인 | **채택.** 부작용 전 단계에서 거부(PR-01), 본체 무수정 |
| A'. 1판: 듣기 + 감싼 `handle_message`에서 버림 | 기각(PR-01): `_handle_message`의 본문 변경·자동 스레드·안내·첨부 수집이 그 전에 일어남 |
| B. `require_mention: false` + `handle_message`만 감싸기 | 기각: A'와 같은 부작용, 다른 서버 동작까지 바뀜 |
| C. 운영 설정 `ignored_channels: "*"` | 기각: 무시 판정이 본문 변경(`D:6035-6040`) 뒤에 있어 멘션 글의 원문이 바뀜 |
| D. hejo가 자기 discord.py 클라이언트·토큰을 따로 운영 | 기각: 같은 봇 연결 둘, 토큰이 hejo 금고에, 플랫폼 계약 우회 |
| 이름 표시: 봇이 `[이름] 본문` | 기각(직원별 표시 요구). 웹후크 채택 |
| 일반 글 채널 + 스레드(커뮤니티 불필요) | 기각: 휴대폰 질문별 목록이 포럼보다 못함 |

## 10. 롤백·복구 (TASK-03 인계서가 이 절을 구체 명령으로 옮긴다)

- 적용 전: (1) 공용 릴리스 커밋 기록 (2) 바꿀 설정 파일(기본 프로필 `config.yaml`) **복사본**을 작업 증거 폴더(`.build/discord-apply/`, 0600)에 두고 원본·복사본 해시 기록 (3) Hermes 환경 설치 꾸러미 목록(`pip freeze`) 기록 (4) 디스코드 플랫폼 꺼짐 확인.
- 복원: 공용 릴리스를 기록한 커밋으로 되돌림 → 복사본으로 `config.yaml`을 덮어쓰고 해시가 적용 전 값과 같은지 확인 → 게이트웨이 재시작 → hejo·텔레그램 연결과 디스코드 꺼짐 확인. 토큰은 사장이 지운다.
- 의존성: 디스코드 플랫폼을 끄면 discord.py는 불리지 않으므로 롤백 때 기본은 **남겨 둔다**. 지우기를 사장이 원하면 (3)과 비교해 새로 생긴 꾸러미만 지우고 `pip freeze`가 (3)과 같은지 확인한다.
- 자료: `discord.json`·`shared/hejo/discord/`는 지우지 않는다. 기록장에 들어간 디스코드 사장 글은 일반 사장 글이라 되돌릴 것이 없다.
