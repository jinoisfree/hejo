# HEJO-IMESSAGE 설계

- 상태: 초안 1판(2026-11-19). 계획 검증 대기. 요구는 [spec.md](spec.md), 칸 배치는 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)이 원본이다.
- 경로 약어: `R` = Hermes 본체, `P` = `R/plugins/platforms/photon`, `TK` = `<운영 저장소>`의 team-kit `lib/hermes_router`.

## 1. 현황 (근거)

| 사실 | 근거 |
|---|---|
| 앱 글은 `receive()`가 기록장에 사장 글을 쓰고 직원마다 `handle_message`로 넘긴다. 중복은 `client_msg_id`로 막는다 | `gate/adapter.py:662-735` |
| 직원 글은 `send()`가 기록한다. 스레드가 없으면 문이 새 id를 만든다 | `gate/adapter.py:314-366` |
| 흘러나오는 글은 `expect_edits` 글 + `edit_message` + 마지막 `finalize=True`다 | `R/gateway/stream_consumer_transport.py:462`, `gate/adapter.py:368-412` |
| 차례가 끝나면 작성 중 끄기 → 배달 뒤 콜백(임시 진행 글 삭제를 예약만 함) → 작성 중 끄기 한 번 더 순서다. 삭제 완료를 알리는 신호는 없다 | `R/gateway/platforms/base.py:4777-4785`, `R/gateway/run_turn.py:4182-4210` |
| 작성 중 상태는 `_typing_threads[chat_id]`의 (직원, 스레드) 묶음이다 | `gate/adapter.py:737-785` |
| 기록장은 모르는 레코드 종류를 손상으로 본다(옛 코드로 되돌리면 열지 못함) | `gate/journal.py:12,58-67` |
| 앱 기능 표시(`hello.features`)로 프레임을 가려 보낸다 | `gate/server.py:262,277,373-378` |
| photon 수신 이벤트: `source.chat_id` = 대화창 id, `source.user_id` = 발신자 id, `source.chat_type`, `message_id`, `reply_to_message_id`, `media_urls`, 탭백은 `raw_message.content.type == "reaction"` | `P/adapter.py:835-934` |
| photon 발신: `send(chat_id, content, reply_to=)` → `SendResult.message_id`, 길이 한도 `MAX_MESSAGE_LENGTH` | `P/adapter.py:580,1293-1296,1515-1538` |
| 플러그인 처리기 공장은 문이 `connect()`할 때 `(native, adapter)`로 불린다. 같은 플러그인·같은 이름은 한 번만 | `R/gateway/platforms/base.py:2341-2371` |
| team-kit 안내원은 `adapter.handle_message`를 감싸 `route_event`(분류·소유권 기록·`source.profile` 변경) 뒤 원래 처리기를 부른다. 거절하면 글을 버린다 | `TK/ingress.py:349-389`, `:27-130`, `:237-241` |
| 서버의 문은 공용 릴리스 사본을 실행한다. team-kit 원본은 실행 중인 `<HOME>/plugin-store/team-kit`이고 운영 저장소 사본은 `./sync`가 만든다 | `<HOME>/plugins/hejo` 링크, `install/hejo-release`, `<운영 저장소>/AGENTS.md` |

## 2. 책임과 흐름

새 모듈 하나가 아이메시지 연결을 맡는다: `gate/imessage.py`(이름은 권고, 책임은 고정). 책임은 넷이다 — 금고·설정·보낸 글 대응 저장, 수신 판정(통과 / 짝짓기 / 명령 / 방에 올리기), 발신(완성된 글 고르기·이름표·나누기), 상태 프레임 만들기. `adapter.py`·`server.py`는 이 모듈을 부르기만 한다.

```text
[수신]  photon._dispatch_inbound → photon.handle_message(감싼 것)
          ├ hejo 차지 아님 → 원래 처리기(안내원 포함) 그대로
          └ hejo 차지 → 짝짓기 | 명령 | 방에 올리기
                          방에 올리기 = HejoAdapter.receive()와 같은 경로(기록장 → 앱 방송 → 직원 handle_message)

[발신]  HejoAdapter가 직원 글을 기록 → 연결 모듈이 후보로 기억
          → 정착 규칙 통과 → photon.send(짝지은 대화창, 이름표+본문, reply_to=그 스레드의 최근 아이메시지 사장 글)
          → 받은 글 id를 sent.jsonl에 덧붙임
```

- **아이메시지 문 붙이기.** `gate/__init__.py`의 `register()`가 `ctx.register_platform_handler("photon", 공장)`을 등록한다. 공장은 그 어댑터를 연결 모듈에 알리고 `handle_message`를 한 번만 감싼다(어댑터에 표시를 남겨 중복 방지, team-kit과 같은 방식). 지원 문은 `photon` 하나다.
- **기본 어댑터만.** 판정·저장·발신은 hejo 기본 어댑터(`_primary`)의 것만 쓴다. 기본 어댑터가 없거나 끊겼으면 모든 글이 통과한다. 전달자 어댑터는 관여하지 않는다.
- **수신은 한 경로.** 아이메시지 글도 `receive()`가 처리한다. `receive()`의 응답 대상(지금은 앱 연결 `conn`)을 "응답 받는 곳"으로 일반화해, 아이메시지에서는 오류 코드를 안내 글로 바꾼다. 사장 글을 기록하는 두 번째 코드를 만들지 않는다.
- **받은 글의 짝.** 아이메시지 사장 글의 `client_msg_id`는 `imessage:` + 아이메시지 글 id다. 중복 방지(기존 `client_msg_id` 검사)와 답장 대상 찾기, 폰 스레드 판정이 이 값 하나로 된다. 기록장 형식은 그대로다.
- **보낸 글의 짝.** `sent.jsonl` 한 줄 = `{"im": 아이메시지 글 id, "msg_id": hejo 글 id}`. 덧붙이기 + `fsync`. 시작할 때 읽어 메모리 색인을 만든다. 손상된 꼬리 줄은 버리고 계속한다.
- **답장 대상 찾기.** `reply_to_message_id` → (받은 글이면 기록장 `client_msg_id`, 보낸 글이면 `sent.jsonl`) → hejo 글 id → `journal.message_threads` → (방, 스레드). `journal.message()`가 없거나 스레드·방이 지워졌으면 "모름"이다.

## 3. 저장 형식

- `<HOME>/hejo/imessage.json`(0600, `AuthStore`와 같은 잠금·원자적 쓰기): `{"pair": {"platform", "chat_id", "user_id", "paired_at"} | null, "code": {"hash", "expires", "used"} | null}`.
- `<HOME>/shared/hejo/imessage/settings.json`(0600, 원자적 쓰기): `{"enabled": bool, "room": str | null, "reports": [str]}`. 기본값 `false / null / []`.
- `<HOME>/shared/hejo/imessage/sent.jsonl`(0600).
- 죽은 방은 읽을 때 걸러 낸다(spec REQ-HI-02.AC-05). 파일을 고쳐 쓸 필요는 없다.

## 4. 통신 규격 추가 (`schemas/hejo-wire-v1.json`)

| 방향 | 프레임 | 필드 |
|---|---|---|
| 앱 → 문 | `imessage` | `id` |
| 앱 → 문 | `imessage_pair` | `id` |
| 앱 → 문 | `imessage_unpair` | `id` |
| 앱 → 문 | `imessage_save` | `id`, `enabled`(bool), `room`(string 또는 null), `reports`(string 배열) |
| 문 → 앱 | `imessage_status` | `ref`(요청에 대한 답일 때만), `platform_ready`, `paired`, `enabled`, `room`, `reports` |
| 문 → 앱 | `imessage_code` | `ref`, `code`, `expires_in` |
| 문 → 앱 | `error` | 새 코드 `imessage_unavailable`, `imessage_unpaired`, `invalid_imessage` |

- 방 id는 1:1 방이면 직원 id, 단체방이면 방 id다(문 안의 `scope`와 같은 규칙).
- `imessage_status`는 기록장에 넣지 않는 상태 프레임이다(`connections_status` 선례). 값이 바뀔 때마다 `imessage` 기능을 밝힌 모든 연결에 `ref` 없이 방송한다. 앱은 연결 직후 `imessage`로 조회한다.
- 기능 이름은 `imessage`다. 밝히지 않은 연결에는 보내지 않는다.

## 5. 수신 판정 순서

감싼 `handle_message(event)`는 아래 순서로 판정한다. "통과"는 원래 처리기를 같은 이벤트로 부르는 것이다.

1. hejo 기본 어댑터가 없거나 1:1 글이 아니면 통과.
2. 대기 중 코드가 있고 만료 전이며 글 전체(앞뒤 공백 제외)가 그 코드와 같으면(해시 비교) 짝짓기. 발신자 허용 검사가 `False`면 짝짓지 않고 통과.
3. 활성이 아니거나 짝지은 문·대화창·발신자와 다르면 통과.
4. 탭백이면 삼킴.
5. 글이 `/방` 또는 `/방 `으로 시작하면 명령.
6. 그 밖은 방에 올리기: 답장 대상이 살아 있는 스레드면 그 방·스레드, 아니면 연결된 방의 새 스레드, 연결된 방이 없으면 안내.

`claims_external(event)`는 1~3의 판정만 부작용 없이 되풀이한다(2 또는 "활성 + 짝 일치"면 참).

- **코드 잠금을 두지 않는 이유.** 코드는 72비트 무작위이고 10분·한 번만 유효해 맞히기가 불가능에 가깝다. 틀린 글을 세려면 통과시킬 글에 부작용을 내야 하고, 안내원이 바깥에 있으면 문이 모든 글을 보지 못해 세는 값이 순서에 따라 달라진다.
- **명령·안내 글.** 문이 보내는 안내는 `sent.jsonl`에 넣지 않는다. 안내에 답장하면 "모름"이라 연결된 방의 새 스레드가 된다.

## 6. 발신 규칙

- **후보.** 문이 시작된 뒤 기록된 직원 `message`만 후보다. 활성이고, 그 스레드가 폰 스레드이거나 그 방이 폰 보고 방일 때만 보낸다(보내는 순간에 판정).
- **정착 규칙.** 한 스레드에 대해 (가) 그 스레드에 작성 중인 직원이 없고 (나) 그 스레드의 마지막 기록(글·수정·삭제) 뒤 정착 시간이 지났을 때, 아직 보내지 않은 살아 있는 직원 글을 기록 순서대로 보낸다. "생각 중" 글(`context.thinking`)은 후보에서 뺀다. 보낼 본문은 보내는 순간 `journal.message()`의 본문이다.
- **정착 시간.** 기본 2초 [가정]. 코드 상수 하나로 두고 시험에서 바꿔 넣을 수 있게 한다. 설정 키는 만들지 않는다. 근거와 한계: 임시 진행 글 삭제는 차례 종료 직후 예약 실행되며 완료 신호가 없다(1절). 삭제가 정착 뒤에 오면 진행 글 한 통이 폰에 남는다.
- **이름표·덧붙임 줄.** spec REQ-HI-05.AC-05·08.
- **나누기.** 이름표를 포함한 글이 아이메시지 어댑터의 `MAX_MESSAGE_LENGTH`를 넘으면 `context.split_text`와 같은 방식으로 나눠 순서대로 보낸다. 모든 통의 id를 같은 hejo 글에 대응시킨다.
- **답장 대상.** 그 스레드에서 가장 최근의 `imessage:` 사장 글의 아이메시지 id. 나눈 통은 모두 같은 대상을 쓴다.
- **실패.** `SendResult.success`가 거짓이거나 예외면 로그 한 줄(종류만) 뒤 그 글을 "보냄 시도함"으로 표시하고 다시 보내지 않는다.
- **기록장·앱에 영향 없음.** 발신은 기록·방송이 끝난 뒤 따로 돈다. 발신이 느리거나 실패해도 `_record`를 막지 않는다(`_publish_lock` 밖).

## 7. 안내원 양보 (team-kit)

`TK/ingress.py`의 감싼 `handle_message` 맨 앞(그림자 모드 분기보다 앞)에 한 가지 검사를 넣는다: 문이 `photon`·`bluebubbles`이고, `adapter.gateway_runner`의 어댑터 목록에 `hejo` 어댑터가 있고, 그 `claims_external(event)`가 `True`를 돌려주면 `return await original(event)`. 그 밖(없음·메서드 없음·거짓·예외)은 지금 코드 그대로다.

| 감싼 순서 | hejo가 차지하는 글의 길 |
|---|---|
| hejo 바깥, 안내원 안 | hejo가 삼킨다. 안내원은 보지 못한다 |
| 안내원 바깥, hejo 안 | 안내원이 양보해 원래 처리기(= hejo가 감싼 것)를 부르고 hejo가 삼킨다 |

team-kit 변경은 hejo 쪽이 아직 적용되지 않은 서버에 먼저 실려도 동작이 같다(메서드가 없으면 기존 동작).

## 8. 앱

- `GateClient`: `hello.features`에 `imessage`, 새 프레임 4종 보내기·2종 받기.
- 모델 하나(아이메시지 상태)를 두고 설정 창 구역과 방 메뉴가 그것만 본다. 상태의 원본은 문이다. 앱은 값을 따로 저장하지 않는다.
- 설정 창(`SettingsPages`)에 "아이메시지" 구역, 방 메뉴(`RoomMenus`)에 두 항목(spec REQ-HI-07).
- SwiftUI 예외 없음.

## 9. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| `receive()` 앱 수신 | 유지 + 응답 대상 일반화 | 앱 동작 불변. 기존 시험 그대로 통과해야 한다 |
| `send()`·`edit_message()`·`delete_message()`·작성 중 | 유지 | 연결 모듈에 "기록됨·작성 중 바뀜"을 알리는 호출만 더한다 |
| 기록장 | 유지 | 레코드 종류·형식 불변 |
| photon 수신 → team-kit 안내원 | 유지(활성이 아닐 때) / hejo가 차지(활성일 때) | 권위 경로는 `claims_external` 하나로 정한다. 같은 글을 둘이 처리하는 경우는 없다 |
| 아이메시지에 답하던 안내원 세션 | 유지 | 연결을 끄면 그대로 다시 쓴다 |

## 10. 대안

| 대안 | 판정 | 이유 |
|---|---|---|
| 설정·보낸 글 대응을 기록장 새 레코드로 | 기각 | 옛 문 코드가 모르는 종류를 손상으로 봐서 롤백하면 기록장을 열지 못한다 |
| 차례 종료 콜백(`register_post_delivery_callback`)으로 발신 | 기각 | 예약 보고처럼 차례 밖에서 오는 글이 빠지고, 진행 글 삭제보다 먼저 불린다 |
| 직원 글이 기록될 때마다 바로 발신 | 기각 | 쓰는 중인 글·진행 글이 폰으로 가고 아이메시지는 고칠 수 없다 |
| photon 내부 메서드(`_dispatch_inbound`)를 감싸 안내원보다 먼저 잡기 | 기각 | 다른 플러그인의 내부에 기대는 것이라 플러그인 계약 밖이다 |

## 11. 위험과 롤백

- **위험.** (1) 짝짓기가 사장을 정한다 — 코드 유출이 곧 방 접근이다. 코드는 앱 연결(출입증 통과)에만 주고 해시로만 보관한다. (2) 감싸기가 photon 수신 전체를 지난다 — 판정 코드의 예외는 잡아서 통과시킨다(글을 잃지 않는다). (3) 재시작 동안 직원 대화가 끊긴다.
- **적용 순서.** team-kit(양보) → hejo 공용 릴리스 → 앱 사본 → 게이트웨이 재시작. 재시작 전까지 실행 중인 동작은 바뀌지 않는다.
- **롤백.** (1) 앱에서 끄기 또는 연결 해제(재시작 없이 즉시 통과 상태). (2) 코드 롤백: 적용 전 `RELEASE` 커밋에서 `install/hejo-release` 재실행, team-kit은 기록해 둔 이전 내용으로 되돌리고 `./sync`, 게이트웨이 재시작. (3) 새 파일(`imessage.json`, `shared/hejo/imessage/`)은 옛 코드가 읽지 않으므로 남겨도 된다. 기록장은 형식이 같아 그대로 열린다.
