# HEJO-TELEGRAM 설계

- 상태: 1판(2026-11-22, 초안). 요구는 [spec.md](spec.md), 칸 배치는 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)이 원본이다. 앞선 설계 [HEJO-IMESSAGE design](../HEJO-IMESSAGE-20261119/design.md)의 정착·나누기·수신 일반화 결정을 이어받고, 다른 점만 적는다.
- 경로 약어: `R` = Hermes 본체(`~/.hermes/hermes-agent`), `T` = `R/plugins/platforms/telegram/adapter.py`, `B` = `R/gateway/platforms/base.py`, `TK` = `<운영 저장소>`의 team-kit `lib/hermes_router`.

## 1. 현황 (근거, 2026-11-22 읽기)

| 사실 | 근거 |
|---|---|
| 아이메시지 연결은 `gate/imessage.py` 하나가 맡고, `__init__`이 `photon` 처리기를 등록하며 adapter·server·rooms가 부른다 | `gate/__init__.py:30-31`, `gate/adapter.py:51,122-123,145-146,173-174,212-213,800-801,826-830`, `gate/server.py:465-466`, `gate/rooms.py:53-54,85-86` |
| 감싼 처리기: `claims_external` 참이면 `receive_external`, 예외면 안내 후 끝, 거짓이면 원래 처리기 | `gate/imessage.py:23-59` |
| 수신은 `receive(frame, conn)`를 `ExternalReply`로 부른다. 중복은 `client_msg_id` | `gate/imessage.py:418-428,463-474`, `gate/adapter.py:696-743` |
| 첨부 들여오기: `files.copy(employee, path, name)` → 대기 id → `receive` 프레임 `files` → `promote` | `gate/files.py:81-120,169-180`, `gate/adapter.py:734-743` |
| 방 기록은 기록장 `room`(만들기·이름·보관)과 `room_delete` 레코드다. 기록 뒤 `imessage.recorded(row)`가 불린다 | `gate/rooms.py:39-87`, `gate/adapter.py:194-213` |
| 처리기 공장은 `factory(native, adapter)`로 불리며 텔레그램은 `connect()` 안, 폴링 시작 전(`is_connected` 거짓)이다. 재접속 재구성 때 같은 어댑터로 다시, 게이트웨이 재접속 때 새 어댑터로 불린다. 이름 제약 없음 | `R/hermes_cli/plugins.py:859-881`, `B:2341-2371`, `T:3180,3302`, `R/gateway/run_adapters.py:813,831-833` |
| 텔레그램의 모든 수신은 인스턴스의 `handle_message`를 부른다. 원래 처리기는 `_accept_update()` 뒤 본체로 간다 | `T:2983,6600,6633,6680,6774-6939,870`, `R/.../telegram/update_admission.py:262-268` |
| 수신 이벤트: `source.platform == "telegram"`, 슈퍼그룹은 포럼이어도 `chat_type == "group"`, `chat_id`, `source.user_id`, `source.thread_id`(일반 토픽 `"1"`), `message_id`, `reply_to_message_id`, `media_urls`(내려받은 로컬 경로)·`media_types`, `media_text_inlined`, `raw_message`(PTB `Message`) | `T:7171-7206,5976-5990,6883-6939`, `R/gateway/platforms/event.py:45` |
| 포럼 토픽 안의 답장 아닌 글도 `reply_to_message`가 토픽 만들기 표시 글을 가리킬 수 있다(Bot API 동작, 코드 미확인) | 조사 보고 — 구현에서 확인 |
| 연속 글·앨범은 한 이벤트로 합쳐지고 첫 글 id가 남는다. 봇 자신의 글은 버린다. 반응·고친 글은 `handle_message`로 오지 않는 것이 기본이나 고친 글이 같은 id로 다시 올 수 있다(PTB 동작, 미확인) | `T:6718,6741-6749,6462,6494,2847-2967`, `B:2607-2626` |
| 발신 `send(chat_id, content, reply_to, metadata)`: 토픽은 `metadata["thread_id"]`, 4096 단위로 스스로 나눔, `SendResult.message_id`는 첫 통, 모든 통은 `raw_response["message_ids"]`. 마크다운을 텔레그램 서식으로 바꿈. 기본 무음, `metadata["notify"]` 참이면 알림 | `T:3722-3851,1101-1176,5713-5810,891-896` |
| 파일 발신 `send_document`·`send_image_file`(`metadata` thread_id, `reply_to`) | `T:5399,5460,5220-5239` |
| 토픽: 만들기 `_create_dm_topic`(아무 chat_id, 실패 시 None), 이름 `rename_dm_topic`(실패 시 예외). 닫기·다시 열기는 감싼 메서드가 없어 `adapter._bot`의 Bot API 호출. 봇은 토픽 관리 권한 관리자여야 함 | `T:2591-2683`, `T:594,3300` |
| 작성 중 `send_typing(chat_id, metadata)` thread_id 지원, `stop_typing`은 본체 기본(무동작) | `T:5664-5690`, `B:3013` |
| 텔레그램 어댑터의 허용·멘션 판정은 `handle_message` **앞**에서 돈다. 허용 환경값이 하나도 없으면 모두 통과 | `T:1043-1098,6483-6520,6570-6600` |
| 발신자 허용 판정 `_is_sender_authorized(user_id, chat_type, chat_id, ...)`는 본체 공통 | `B:2446-2472` |
| team-kit 안내원은 `slack`·`photon`·`bluebubbles`만 감싼다. 텔레그램은 감싸지 않는다. 안내원의 hejo 양보 검사는 `claims_external`이 없으면 양보하지 않는다 | `TK/plugin.py:14-30`, `TK/ingress.py:363-374` |
| Hermes 환경에 `python-telegram-bot`이 설치돼 있지 않다 | 조사 보고(`R/pyproject.toml:331`, venv에 없음) |

## 2. 책임과 흐름

새 모듈 하나가 텔레그램 연결을 맡는다: `gate/telegram.py`(이름 권고, 책임 고정). 책임은 다섯이다 — 금고·설정·토픽 대응·보낸 글 대응 저장, 수신 판정(통과 / 짝짓기 / 안내 / 방에 올리기), 토픽 동기화, 발신(정착·이름표·첨부·닻), 상태 프레임. `adapter.py`·`server.py`·`rooms.py`는 부르기만 한다. `gate/imessage.py`는 지운다.

```text
[수신]  telegram 어댑터 수신 → (어댑터 자체 허용·멘션 판정) → handle_message(감싼 것)
          ├ claims_external 거짓/예외 → 원래 처리기(같은 이벤트) — Hermes 직통(사장 결정)
          └ 참 → adapter._accept_update() → 짝짓기 | 안내 | 방에 올리기(= receive())

[발신]  HejoAdapter._record → telegram.recorded(row)
          ├ room/room_delete 레코드 → 토픽 동기화 작업
          └ message 레코드 → 스레드 대기열 → (사장 글 즉시 | 직원 글 정착 뒤)
               → 방 토픽 확보 → send(그룹, 이름표+본문, reply_to=닻, metadata{thread_id, notify})
               → 첨부 send_document/send_image_file → sent.jsonl 덧붙임
```

- **문 붙이기.** `gate/__init__.py`가 `register_platform_handler("telegram", attach_telegram)`만 등록한다(`photon` 등록 삭제). 공장은 어댑터를 모듈 변수에 두고 `handle_message`를 어댑터마다 한 번 감싼다(표시 속성). 공장이 불릴 때 `is_connected`가 거짓이므로 상태 방송·동기화는 공장 안이 아니라 첫 수신·발신·조회 때 또는 연결 뒤 일정 작업으로 한다(구현 선택, 단 공장 안에서 네트워크 호출 금지).
- **차지한 글의 접수 표시.** 차지해서 원래 처리기를 부르지 않는 글은 `adapter._accept_update()`를 부른다(어댑터의 수신 기록 유지). 메서드가 없으면 건너뛴다.
- **기본 어댑터만.** HEJO-IMESSAGE와 같다(`_primary`).
- **받은 글의 짝.** 사장 글의 `client_msg_id` = `telegram:` + 그룹 id + `:` + 글 id. 그룹을 바꿔 다시 짝지어도 충돌하지 않는다. 중복 방지·답장 대상 찾기·닻 찾기가 이 값으로 된다.
- **보낸 글의 짝.** `sent.jsonl` 한 줄 = `{"chat": 그룹 id, "tg": 글 id, "msg_id": hejo 글 id}`. 읽기·손상 처리는 HEJO-IMESSAGE 3판 규칙(읽을 수 없는 줄 건너뜀, 덜 쓰인 꼬리만 자름, 시작을 막지 않음).
- **답장 대상 찾기.** `reply_to_message_id` → (받은 글 `client_msg_id` 또는 `sent.jsonl`, 현재 그룹 것만) → hejo 글 id → `journal.message_threads` → (방, 스레드). 대상이 토픽 id와 같거나 원본이 토픽 만들기 표시면 "답장 아님".

## 3. 저장 형식

- `<HOME>/hejo/telegram.json`(0600, `AuthStore` 잠금·원자적 쓰기): `{"pair": {"platform":"telegram","chat_id","user_id","paired_at"} | null, "code": {"hash","expires","used"} | null}`.
- `<HOME>/shared/hejo/telegram/settings.json`(0600): `{"enabled": bool}`, 기본 `false`.
- `<HOME>/shared/hejo/telegram/topics.json`(0600, 원자적 쓰기): `{"chat": 그룹 id, "topics": {방 id: {"topic": 토픽 id, "name": 마지막으로 맞춘 이름, "closed": bool}}}`. `chat`이 현재 짝 그룹과 다르면 비어 있는 것으로 읽는다. 손상이면 비어 있는 것으로 읽고 다음 동기화에서 덮어쓴다(토픽이 중복 생길 수 있음 — 알려진 결과).
- `<HOME>/shared/hejo/telegram/sent.jsonl`(0600).
- 문 시작이 이 파일들 때문에 실패하지 않는다(NFR-HT-05).

## 4. 통신 규격 (`schemas/hejo-wire-v1.json`)

| 방향 | 프레임 | 필드 |
|---|---|---|
| 앱 → 문 | `telegram` | `id` |
| 앱 → 문 | `telegram_pair` | `id` |
| 앱 → 문 | `telegram_unpair` | `id` |
| 앱 → 문 | `telegram_save` | `id`, `enabled`(bool) |
| 문 → 앱 | `telegram_status` | `ref`(답일 때만), `platform_ready`, `paired`, `enabled`, `topic_problem` |
| 문 → 앱 | `telegram_code` | `ref`, `code`(12자), `expires_in`(600) |
| 문 → 앱 | `error` | 새 코드 `telegram_unavailable`, `telegram_unpaired` |

- 아이메시지 프레임 정의 6종과 그 참조를 규격에서 지운다. 문은 그 종류를 모르는 프레임으로 처리한다(`unexpected_frame`).
- 기능 이름 `telegram`. 밝히지 않은 연결에는 보내지 않는다. `telegram_code`는 요청한 연결에만. `telegram_status`는 기록장에 넣지 않는 상태 프레임이다.

## 5. 수신 판정 순서

감싼 `handle_message(event)`:

1. hejo 기본 어댑터가 없거나 끊겼거나, `source.platform`이 `telegram`이 아니거나, 그룹 글이 아니면(`chat_type`이 `group`/`forum`이 아님) 통과.
2. 글 전체(앞뒤 공백 제외)가 금고의 코드와 해시로 같으면: 코드가 유효하고, 포럼 그룹이며(`raw_message.chat.is_forum` 참), 허용 검사(`_is_sender_authorized(user_id, chat_type, chat_id)`)가 `False`가 아니면 짝짓기, 그 밖은 통과. 코드 글은 방에 올리지 않는다.
3. 활성이 아니거나 그룹·계정이 짝과 다르면 통과.
4. 그 밖은 차지: 답장 대상이 살아 있으면 그 스레드, 아니면 `source.thread_id`의 방 토픽(대응 있고 닫히지 않은 방)의 새 스레드, 그 밖(일반 토픽·모르는 토픽·닫힌 토픽)은 안내.

`claims_external(event)`는 1~3을 부작용 없이 되풀이한다(2는 "유효 + 포럼 + 허용"이면 참, 3은 "활성 + 짝 일치"면 참). 감싼 처리기는 그 답만 쓴다. 안내원이 텔레그램을 감싸지 않으므로 team-kit 변경은 없다. `HejoAdapter.claims_external`은 텔레그램 모듈에 위임하도록 남긴다(안내원은 `photon`에 대해 부르지만 텔레그램 모듈은 `photon` 글에 거짓을 돌려준다).

- **본문.** `event.text`. 단 `media_text_inlined`가 있으면 `raw_message.caption`(없으면 빈 글)을 쓴다.
- **첨부.** `media_urls`의 각 로컬 파일을 `files.copy`로 대기시키고 그 id를 `receive` 프레임 `files`에 넣는다. 받는 직원 결정이 `receive()` 안에 있으므로, 대기는 방 대표(단체방) 또는 직원(1:1)으로 하고 `promote`가 옮긴다(구현이 `receive` 일반화와 맞춰 정한다. 사장 글 기록 경로를 둘로 만들지 않는다). 파일 크기는 기존 첨부 한도를 따르고 넘으면 AC-07 안내.
- **차지한 뒤 오류.** HEJO-IMESSAGE와 같다: 잡아서 "지금은 받지 못했어요", 로그 한 줄, 원래 처리기로 넘기지 않음.
- **안내 글**은 `sent.jsonl`에 넣지 않는다. 안내는 그 글의 토픽(`metadata thread_id`)으로 보낸다.

## 6. 토픽 동기화

- **계기.** (가) 활성이 되는 순간: 켜기 저장, 짝지은 뒤 켜져 있는 상태, 텔레그램 문 첫 연결 확인. (나) `recorded(row)`의 `room`·`room_delete` 레코드. (다) 발신할 방에 토픽이 없을 때.
- **작업 한 줄.** 방마다 원하는 상태(열림+이름 / 닫힘)를 계산해 `topics.json`과 다르면 맞춘다. 직렬로 한 작업자가 처리하며 기록·방송을 막지 않는다(`_publish_lock` 밖).
- **만들기.** 어댑터의 토픽 만들기 메서드(`T:2591`) — `None`이면 실패. **이름 바꾸기**는 `T:2674`(예외 = 실패). **닫기·다시 열기**는 `adapter._bot`의 Bot API(`close_forum_topic`, `reopen_forum_topic`). `_bot`이 없으면 실패로 보고 다음 계기에 다시.
- **실패 처리.** 로그 한 줄(종류만), `topic_problem` 참으로 방송. 다음 성공에서 거짓으로 돌린다.
- **보관 풀기**는 `room` 레코드의 `archived` 거짓이다. 삭제된 방은 다시 열지 않는다.
- 텔레그램 쪽 토픽 삭제·이름 변경은 알 수 없다. 사장이 토픽을 지우면 그 방 발신이 실패하고(어댑터가 일반 토픽으로 보낼 수 있음 — `T:3606-3621`), 앱에서 짝을 다시 하거나 `topics.json`을 비우는 방법만 있다(알려진 결과, 실물 확인 M8에서 안내).

## 7. 발신 규칙

- **후보.** 문 시작 뒤 쓸 수 있는 방에 기록된 `message` 행 중 (가) 직원 글, (나) `telegram:` 접두가 아닌 사장 글. 기록 순간 활성이 아니었으면 후보가 아니다(AC-07). 보내는 순간 다시 활성·방·토픽을 확인한다.
- **스레드 대기열.** 스레드마다 기록 순서 대기열 하나. 맨 앞이 사장 글이면 바로 보낸다. 맨 앞이 직원 글이면 HEJO-IMESSAGE 정착 규칙(작성 중 없음 + 마지막 기록 뒤 정착 시간, 기본 2초 상수, 시험에서 바꿈)을 기다린다. 생각 중 글은 뺀다. 본문은 보내는 순간 `journal.message()`의 본문이다.
- **이름표.** 직원 `[이름]`(단체방도 방 제목은 붙이지 않는다 — 토픽이 방이다), 사장 `[사장]`. 버튼 덧붙임 줄은 HEJO-IMESSAGE REQ-HI-05.AC-08 문구 그대로.
- **나누기.** 어댑터가 나눈다. 문은 나누지 않는다. `raw_response["message_ids"]`(없으면 `message_id`)의 모든 id를 대응시킨다.
- **닻.** 스레드의 가장 이른 텔레그램 대응 글(받은 사장 글의 `client_msg_id` 또는 `sent.jsonl`)의 id. 없으면 이번 글 첫 통이 닻이 된다. 닻이 지워졌으면 어댑터가 닻 없이 다시 보낸다(`T:3622-3634`).
- **알림.** 직원 글 `metadata["notify"] = True`, 사장 글은 넣지 않는다(무음).
- **첨부.** 글 행의 각 파일을 저장소 경로로 찾아 이미지면 `send_image_file`, 그 밖은 `send_document`로 같은 토픽에 그 글 첫 통 답장으로 보낸다. 본문 발신이 실패하면 첨부도 보내지 않는다. 실패한 첨부는 다시 보내지 않고 로그 한 줄. 보내기 전에 아는 이유(파일 없음, 50MB 초과)로 못 보내는 첨부는 본문에 `📎 이름 (hejo 앱에서 열기)` 줄로 넣는다. 첨부 글 id도 `sent.jsonl`에 같은 hejo 글로 적는다.
- **실패.** HEJO-IMESSAGE와 같다(로그 한 줄, 다시 보내지 않음, `_record`를 막지 않음).

## 7.1 작성 중

`adapter.send_typing`의 (방, 스레드) 열쇠마다, 활성이고 방 토픽이 있으면 텔레그램 `send_typing(그룹, metadata{thread_id: 토픽})`을 기다리지 않는 작업으로 요청한다. 같은 토픽은 4초에 한 번 이하로 줄인다(텔레그램 표시는 약 5초 유지). 정지 요청·집합 관리는 없다(HEJO-IMESSAGE 6.1의 `stop_typing` 계산은 지운다). 예외는 삼키고 경고 한 줄.

## 8. 앱

- `GateClient`: `features`를 `["rooms","telegram"]`로. 아이메시지 프레임 처리·`IMessageState` 삭제, `TelegramState`(이름 권고) 추가: 조회·코드 요청·해제·켜기 저장, 상태·코드·남은 초·문제 표시.
- 설정 `PetSettingsWindow`의 "연결과 동기화" 첫 구역을 `TelegramSettingsSection`으로 바꾼다. 안내 문구(고정): "텔레그램에서 포럼(토픽)을 켠 그룹을 만들고 봇을 토픽 관리 권한이 있는 관리자로 넣은 뒤, 이 코드를 그 그룹에 보내세요. 연결을 켜면 hejo의 방마다 토픽이 생깁니다."
- `RoomMenus`의 `IMessageMenus`와 그 호출(`ConversationView.swift:249`, `RoomDialogs.swift:102`), `ConversationController`의 `imessageRooms`, `AppDelegate`의 구역 연결을 지우거나 텔레그램 구역으로 바꾼다.
- 시험: `IMessageTests.swift`·`--imessage` 플래그를 텔레그램 시험으로 바꾸고, 고정 보조물 `legacy_feature_fixture.py`의 `reject_imessage`를 `telegram` 조회 거절로 바꾼다(앱이 옛 문을 흉내 내는 시험의 뜻 유지).

## 9. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| `gate/imessage.py`, `photon` 처리기 등록 | 교체 → 제거 | 같은 변경에서 지운다. 서버의 photon 수신은 hejo 이전 경로(안내원·Hermes)로 돌아간다 |
| 규격 아이메시지 프레임 6종·오류 코드 3종 | 교체 → 제거 | 텔레그램 프레임으로. 옛 앱은 `unexpected_frame`로 "지원하지 않음" |
| 앱 아이메시지 구역·메뉴·상태·시험 | 교체 → 제거 | 텔레그램 구역(메뉴 없음) |
| `receive()` 응답 대상 일반화(`ExternalReply`) | 유지 | 텔레그램 모듈로 옮겨 쓴다 |
| 정착 규칙·`SETTLE_SECONDS`·`gate/tests/imessage_settling.py` | 유지(이전) | 상수는 텔레그램 모듈로. 정착 측정 시험은 본체 지연을 재는 것이라 이름·참조만 바꿔 유지 |
| `HejoAdapter.claims_external` | 유지 | 텔레그램 모듈에 위임 |
| `rooms.py`의 상태 비교 방송 | 교체 | 토픽 동기화는 `recorded(row)`로 하므로 `rooms.py`의 브리지 호출은 텔레그램 상태 비교로 바꾸거나 지운다(상태 필드에 방이 없어 비교가 필요 없으면 지운다) |
| team-kit 안내원의 photon 양보 | 유지(무변경) | hejo가 `photon`을 차지하지 않으면 양보가 일어나지 않는다. 철거는 운영 저장소 몫으로 남긴다(범위 밖, tasks에 후속 후보로 기록) |
| 서버 photon 플랫폼 | 유지(사장 결정) | 아이메시지는 Hermes 직통 |

## 10. 대안

| 대안 | 판정 | 이유 |
|---|---|---|
| 문이 Bot API를 직접 부름(Hermes에 텔레그램을 켜지 않음) | 기각 | 직통 차단이 요구가 아니게 됐다(사장 결정). 수신 루프·첨부를 새로 짜야 한다 |
| 공장에서 PTB `MessageHandler`를 `native`에 먼저 등록해 어댑터 판정 앞에서 잡기 | 기각 | 어댑터 허용 판정을 건너뛰고 PTB 내부 순서에 기댄다. 아이메시지와 같은 감싸기 계약을 유지한다 |
| 방마다 그룹 | 기각 | 사장 결정(포럼 그룹) |
| 봇 1:1 대화의 토픽 | 기각 | 사장 결정. 최근 기능이라 동작 확인 필요 |
| 보낸 뒤 고침·삭제를 `edit_message`·`delete_message`로 반영 | 이번 밖 | 남은 글만 보내므로 대부분 필요 없다. 필요하면 후속 |

## 11. 위험과 롤백

- **위험.** (1) 짝짓기가 사장을 정한다 — 코드는 앱 연결에만, 해시로만 보관, 포럼 그룹·허용 검사·계정 일치. (2) 감싸기가 텔레그램 수신 전체를 지난다 — 판정 예외는 통과. (3) 운영 텔레그램 허용 설정이 비어 있으면 어댑터가 모든 계정을 통과시킨다(`T:1074-1075`) — 문은 계정 일치로 차지를 막지만, 차지하지 않은 글은 Hermes로 간다. 그래서 운영 적용 전 허용 계정 설정을 사장이 넣는 것이 적용 조건이다(TASK-07). (4) 방 수만큼 토픽을 만들 때 속도 제한.
- **적용 순서(TASK-07).** 사장 준비(봇, 포럼 그룹, 봇 관리자 권한, `TELEGRAM_BOT_TOKEN`, 허용 계정) → Hermes 환경에 텔레그램 의존성 설치(본체 코드 무수정, 본체가 정한 패키지 판) → hejo 공용 릴리스 → 게이트웨이 재시작 → 앱 공개(TASK-07b).
- **롤백.** (1) 앱에서 끄기·해제(재시작 없이). (2) 코드: 적용 전 `RELEASE` 커밋으로 `install/hejo-release` 재실행 → 재시작(아이메시지 연결이 돌아온다; 옛 `imessage.json`을 지우지 않았으므로 짝도 그대로). (3) Hermes 텔레그램 끄기는 사장이 토큰을 빼는 것으로. (4) 새 파일(`telegram.json`, `shared/hejo/telegram/`)은 옛 코드가 읽지 않으므로 남겨도 된다. 기록장 형식은 같다.
