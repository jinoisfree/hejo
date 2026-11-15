# HEJO-FOUNDATION 설계

- 상태: 승인(2026-11-14 사용자). 명세: [spec.md](spec.md). 검토 기록: [plan-review.md](plan-review.md). 근간: [ARCHITECTURE.md](../../ARCHITECTURE.md).
- 근거 경로의 `R`은 `~/.hermes/hermes-agent`(운영 포크 브랜치, displayVersion 0.21.5+7339.gebb026e), `TK`는 `<운영 저장소>/hermes/plugin-store/team-kit`(운영 원본 `~/.hermes/plugin-store/team-kit`), `D`는 `<운영 저장소>/ddots`.

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)과 같다. 이 문서는 복사하지 않는다.

## 1. 전체 흐름

```
hejo 앱(MacBook) ──WebSocket(ws://<주소>:<포트>/v1/ws) + HTTP(/v1/files…)──▶ 문(기본 프로필 어댑터, 리스너 1개)
   ▲                                                                         │ source.profile = <직원 id>
   │ frame(seq)                                                              ▼
   └──────────── 대화 기록장(<HOME>/shared/hejo/journal) ◀── 답장·수정·작성 중·버튼 ── Hermes 차례(직원 홈)
```

- 문은 `register_platform("hejo", …)` 플러그인이다(`R/hermes_cli/plugins.py:807`). 본체 변경 없음.
- [확인] 플러그인 플랫폼은 공유 리스너를 선언할 수 없다(`R/gateway/config.py:307,315`의 고정 집합). 그래서 리스너는 **기본 프로필 어댑터에만** 둔다. 보조 프로필 어댑터는 `self._owner_profile`이 설정된다(`R/gateway/platforms/base.py:2477`). 이 경우 **어떤 모드에서도 포트를 묶지 않는다**(불변 조건). TASK-02의 보조 어댑터는 비활성 모드(`retryable=False` 실패)다. 전달자 모드는 4.1 탐침 뒤 계획 담당이 명세를 개정해야만 생긴다.
- 들어오는 글: `build_source(chat_id=<직원 id>, chat_type="dm", user_id=<사장 user id>, thread_id=<스레드 id>)` 뒤 `source.profile = <직원 id>`([확인] 선례 `R/gateway/platforms/webhook.py:711`), `handle_message(MessageEvent)`(`base.py:4079`). 세션 키는 `agent:<직원>:hejo:dm:<직원>:<스레드>`가 된다(`R/gateway/session.py:682`).
- 나가는 글: 러너가 받은 어댑터(문)로 `send/edit_message/send_typing…`을 부르고 `metadata.hermes_profile`이 직원을 알려 준다([확인] `base.py:171-174`, `R/gateway/authz_mixin.py:285`).
- 직원 id 검증: 들어온 `employee`가 현재 처리 중인 프로필 집합(`profiles_to_serve`, `R/hermes_cli/profiles.py:1174`)에 없으면 `unknown_employee` 오류.
- 권한: 문이 출입증으로 사장을 인증한다. Hermes 쪽 허용 사용자는 플랫폼 항목 `allowed_users_env="HEJO_ALLOWED_USERS"`로 둔다. 값은 비밀이 아니므로 `.env`가 아니라 `config.yaml`의 `gateway.platforms.hejo.extra.allowed_users: ["owner"]`에 두고, 플러그인의 `apply_yaml_config_fn`이 `_shared.apply_yaml_bridge`로 환경 변수에 옮긴다(`R/gateway/platforms/ADDING_A_PLATFORM.md` 18~43행, env가 이미 있으면 env 우선). 문이 만드는 `user_id`는 고정 문자열 `owner`. 시험에서 허용(`owner`)·거부(다른 id)를 확인한다. 설치 도우미와 문은 `.env`를 열거나 쓰지 않는다.

## 2. 통신 규격 v1 (`schemas/hejo-wire-v1.json`이 원본)

TASK-02가 JSON Schema로 만들고 앱·문이 같은 파일을 기준으로 시험한다. 아래는 필수 내용이다.

공통 봉투: `{"v":1,"type":<문자열>,"id":<요청 id, 선택>,…}`. 문→앱 기록 프레임에는 `seq`(기록장 순번, 단조 증가 정수)가 붙는다.

| 방향 | type | 필드 | 의미 |
|---|---|---|---|
| 앱→문 | `hello` | `token`·`pair_code`·`login`·`google`·`local` 중 하나(10판),  `device_name`, `app_version`, `since`(마지막 seq, 선택) | 첫 프레임. 5초 안에 없으면 끊음 |
| 문→앱 | `welcome` | `device_id`, `token`(페어링 때만), `gate_version`, `employees[]`, `head_seq` | 인증 성공 |
| 문→앱 | `pair_rejected` / `auth_rejected` | `reason`(expired·used·wrong·locked·revoked·unknown) | 실패 후 닫음 |
| 앱→문 | `roster` | `id` | 직원 목록 재요청 |
| 문→앱 | `roster` | `ref`(요청 id), `employees[]` | 직원 목록 응답(welcome의 `employees[]`와 같은 항목) |
| 앱→문 | `sync` | `id`, `since` | 기록장 `since` 다음부터 재전송 요청(2.1 규칙) |
| 문→앱 | `sync_done` | `ref`, `through`(이번에 보낸 마지막 seq, 보낸 것이 없으면 `since`), `more`(bool), `head_seq` | 재전송 한 페이지 끝 |
| 앱→문 | `send` | `employee`, `thread`(없으면 새 스레드), `text`, `client_msg_id`, `files[]`(업로드 id) | 사장 글 |
| 문→앱 | `message` | `seq`, `msg_id`, `employee`, `thread`, `role`(owner·employee·system), `text`, `files[]`, `buttons[]`, `reply_state`, `client_msg_id`(사장 글 확인용), `ts` | 새 글 |
| 문→앱 | `edit` | `seq`, `msg_id`, `text`, `final`(bool), `buttons[]`(선택) | 수정·스트리밍 |
| 문→앱 | `delete` | `seq`, `msg_id` | 삭제 |
| 문→앱 | `typing` | `employee`, `thread`, `on`, `ttl_seconds`(on일 때 6) | 작성 중(기록장에 안 씀). 앱은 같은 스레드의 `on`이 `ttl_seconds` 안에 다시 오지 않으면 꺼진 것으로 본다 |
| 문→앱 | `state` | `seq`, `msg_id`, `reply_state`(asked·answered·closed) | 답장 버튼 상태 |
| 앱→문 | `click` | `msg_id`, `button_id` | 버튼 누름 |
| 문→앱 | `error` | `code`, `ref`(요청 id) | 실패 알림 |
| 문→앱 | `ping` / 앱→문 `pong` | — | 30초 생존 확인 |

- `employees[]` 항목: `{id, name, aliases[], avatar}`. `avatar`는 사진이 있으면 `/v1/avatars/<id>` 경로, 없으면 null. 이름·별칭은 team-kit 명부가 있으면 `hermes_facility.team_registry`로 읽고 없으면 `name = id`.
- `buttons[]` 항목: `{id, label, kind, style}`. `kind`: `reply`(team-kit 답장 버튼), `approval`, `clarify`, `slash`. 문이 `button_id → (kind, 세션 키, 해석 정보)`를 기록장 메타에 보관하며 앱은 id만 돌려준다.
- 스레드 id: 앱이 만든 UUID(소문자 36자). 예약 보고 등 문이 시작한 스레드는 문이 UUID를 만든다.
- 크기 한도: 프레임 1 MiB, 글 64 KiB. 프레임 한도 안에서 글만 64 KiB를 넘으면 `error(too_large, ref)`를 보내고 연결을 유지한다. 프레임 자체가 1 MiB를 넘으면 문은 본문을 끝까지 읽지 않으므로 `error(too_large)`를 최선 노력으로 보낸 뒤 WebSocket 닫기 코드 1009로 연결을 닫는다(2판 보완: 상대가 아직 보내는 중에 닫으면 TCP가 앞서 보낸 오류 프레임을 버릴 수 있어 오류 프레임 도착을 보장할 수 없다). 같은 이유로 닫기 프레임도 도착을 보장할 수 없어, 앱은 `error(too_large)`, 닫기 코드 1009, 비정상 끊김(1006) 중 하나를 본다(3판 보완). 문이 보장하는 것은 "닫기 코드 1009로 닫기를 시도하고 계속 동작함"이며, 이는 문 쪽에서 검증한다. 앱은 `error(too_large)`·1009를 "너무 큼"으로, 1006을 일반 끊김으로 처리하고 다시 연결한다. 앱은 보내기 전에 프레임 크기를 검사해 1 MiB 초과를 보내지 않는다. 어느 경우든 문·게이트웨이는 계속 동작한다.
- 응답 짝: 요청 프레임의 `id`를 응답·오류의 `ref`로 돌려준다. `hello`의 응답은 `welcome`/`*_rejected`.
- `message.files[]` 항목(2판 보완, GAP-T02-01 결정): `{"file_id": str(UUID), "name": str(1~255자, 경로 구분자 없음), "mime": str, "size": int(바이트, 0 이상)}` 네 필드 모두 필수, 추가 필드 없음. 앱은 `GET /v1/files/<message.employee>/<file_id>`로 받는다. 사장 글(`role: owner`)의 첨부와 직원 글의 첨부가 같은 모양이다. 내부 메타(실제 경로·소유 등록)는 공개하지 않는다. `send.files[]`는 업로드가 돌려준 `file_id` 문자열 배열이다.
- 작성 중 표시: Hermes는 차례 동안 `send_typing(chat_id, metadata)`를 2초마다 다시 부르고(`R/gateway/platforms/base.py:3435` `_keep_typing`, interval 2.0) `stop_typing(chat_id)`에는 스레드 정보가 없다. 그래서 문은 직원별로 작성 중인 스레드 집합을 기억하고, `stop_typing(chat_id)`이 오면 그 직원의 기억된 스레드 모두에 `on:false`를 보내고 집합을 비운다. 아직 차례가 진행 중인 스레드는 다음 갱신(2초 안)에 다시 `on`이 된다. 앱은 `ttl_seconds`(6초) 안에 갱신이 없으면 끈다.

### 2.1 재전송 경계 규칙(REQ-HF-06)

0. `welcome`(또는 `*_rejected`)은 그 연결의 첫 프레임이다. 문은 인증 직후부터 그 연결을 재전송 중 상태로 두고, `welcome` 전송 뒤 `hello.since`가 있으면 그 값, 없으면 `welcome.head_seq`를 since로 하여 2번 절차(재전송)를 실행한다. 그래서 `welcome` 이전에 기록 프레임이 가지 않고, `welcome.head_seq` 뒤에 기록된 프레임도 빠지지 않는다. `hello.since`가 `head_seq`보다 크면 `error(invalid_since)`를 보내고 닫는다.
1. 앱은 적용한 마지막 seq(`applied`)를 기기에 저장한다. 앱은 `seq == applied + 1`인 기록 프레임만 적용하고, `seq <= applied`는 버린다(중복 무시), `seq > applied + 1`이면 적용하지 않고 `sync{since: applied}`를 보낸다(빈칸 복구).
2. 연결마다 문은 "재전송 중" 상태를 가진다. `hello{since}`(또는 `sync{since}`)를 받으면 그 연결을 재전송 중으로 바꾸고, 기록장에서 `since < seq` 프레임을 오름차순으로 최대 500개 보낸 뒤 `sync_done{through, more, head_seq}`를 보낸다. `more = through < 그 시점 head_seq`.
3. 재전송 중인 연결에는 실시간 기록 프레임을 보내지 않고 연결별 대기열에 쌓는다. `more == false`인 `sync_done` 직후 대기열에서 `seq > through`인 것만 순서대로 보내고 실시간 상태로 바꾼다. `more == true`면 대기열을 비우고(다음 페이지에 포함되므로) 앱의 다음 `sync{since: through}`를 기다린다. 대기열 상한 2,000개를 넘으면 대기열을 비우고 `more = true`로 처리한다.
4. `typing`·`roster`·`error`·`ping`은 기록 프레임이 아니며 seq가 없고 재전송 상태와 무관하게 보낸다.
5. 기기마다 연결과 상태가 독립이다. 두 기기는 각자 같은 기록장 seq 열을 받는다.

### 2.2 확장 훅(TASK-02에서 고정, TASK-04가 사용)

문 어댑터가 공개하는 확장 지점. team-kit은 이것만 쓰고 문의 내부를 import하지 않는다. 문도 team-kit을 import하지 않는다.

| 지점 | 형태 | 의미 |
|---|---|---|
| `metadata["hejo_buttons"]` | `send(chat_id, content, reply_to=None, metadata=None)`와 hejo가 확장한 `edit_message(chat_id, message_id, content, *, finalize=False, metadata=None)`의 `metadata`에 `[{"label": str, "style": "primary"\|"danger"\|"default"}]` | 문이 각 항목에 `button_id`를 발급하고 `kind="reply"`로 글에 단다. 최대 5개, 라벨 30자 |
| `metadata["hejo_reply_state"]` | `"asked"`\|`"answered"`\|`"closed"` | 그 글의 답장 상태. `send`에 실리면 새 글 상태, 단독 갱신은 아래 함수 |
| `await adapter.set_reply_state(msg_id, state)` | 코루틴, 반환 None | 기록장 락을 잡고 `state` 프레임을 쓰고 fsync까지 끝난 뒤 반환한다(반환 = 기록 완료, 전송은 연결별 규칙에 따라 그 뒤). 기록 실패면 `HejoJournalError`를 던지고 아무것도 보내지 않는다. 같은 `msg_id`의 상태는 호출 순서대로 기록된다 |
| `adapter.register_click_handler(kind, handler)` | `handler(click: dict) -> Awaitable[bool]` | `kind="reply"` 버튼이 눌리면 `click = {msg_id, button_id, label, employee, thread, message_text}`로 호출. `True`면 처리 완료, `False`면 문 기본 처리(라벨을 사장 글로 보내되 `raw_message={"_hermes_button": {label, message_id, message_text}}`) |
| `edit_message` 확장 | Hermes 기본 서명(`R/gateway/platforms/base.py:2782`)에 키워드 전용 `metadata=None`을 더한 재정의. 러너는 metadata 없이 부르므로 기존 호출과 호환된다. team-kit 래퍼는 `await adapter.edit_message(chat_id, message_id, content, finalize=…, metadata={...})`로 부른다 | 래퍼가 원래 메서드를 감쌀 때 이 서명을 그대로 유지한다 |
| 기본 처리의 이벤트 | `MessageEvent(text=label, source(thread=그 스레드, profile=그 직원), raw_message={"_hermes_button": …})` | team-kit이 없을 때도 같은 형태로 차례가 돈다 |

HTTP(같은 포트, 헤더 `Authorization: Bearer <출입증>`):

| 경로 | 동작 |
|---|---|
| `POST /v1/files?employee=<직원 id>` | 첨부 업로드(최대 50 MiB). **대기 칸** `<HOME>/shared/hejo/files/.pending/<직원 id>/<file_id>/<이름>`에 저장(쓰기 → fsync → 이름 바꾸기)하고 `file_id`·`name`·`mime`·`size`를 반환. 이 시점에는 기록장에 쓰지 않는다(6판) |
| `GET /v1/files/<직원 id>/<file_id>` | 기록장에 **그 직원 소유로 등록된** 첨부만 반환(대기 칸의 파일은 404). 미등록·다른 직원 소유·경로 탈출은 모두 404(존재 여부를 드러내지 않음), 출입증 없음 401 |
| `GET /v1/avatars/<직원 id>` | 1단계 근간에서는 항상 404이고 roster의 `avatar`는 항상 null이다(6판). 사진 원본 칸·읽기 계약은 1단계 후속 "직원 카드" 작업에서 정한다 |

직원이 보낸 파일(`send_document`/`send_image_file`)은 문이 `files/<file_id>/`로 복사해 그 직원 소유로 등록한 뒤 글에 단다. 원래 경로는 내보내지 않는다.

첨부 등록 시점(6판, T03B-01 결정): **첨부의 소유 등록은 그 첨부가 달린 글의 `message` 행 내부 메타로만 한다.** 업로드 전용 기록 행이나 가짜 대화 글은 만들지 않는다. 기록장이 다운로드 권한의 유일한 원본이라는 3절 규칙은 그대로다.
1. 사장 `send{employee, files:[id…]}`: 문은 각 id가 `.pending/<send.employee>/<id>/`에 있는지 확인한다. 하나라도 없으면(다른 직원 대기 칸 포함) `error(unknown_file, ref)`로 거절하고 아무것도 기록하지 않는다. 있으면 `files/<id>/`로 이름 바꾸기 → 사장 `message` 행(메타에 `{file_id, employee, owner: "owner", path}` 목록)을 기록장에 추가 → 직원 차례 이벤트의 `media_urls`에 `files/<id>/<이름>` 절대 경로. 기록장 쓰기가 실패하면 이름을 대기 칸으로 되돌리고 `error(journal_write_failed)`.
2. 직원 발송 파일: `files/<id>/`로 복사 → 직원 `message`(또는 그 글을 다는 행) 메타에 등록.
3. 재시작: 대기 칸은 그대로 남아 재시작 뒤에도 `send`할 수 있다. 시작할 때와 하루 한 번 24시간 넘은 대기 칸 항목을 지운다. `files/` 아래인데 기록장 등록이 없는 항목(이름 바꾸기 뒤 기록 전 멈춤)은 GET에 404이고 같은 정리에서 지운다.
4. 대기 칸 경로는 직원 id·`file_id`(UUID)·검증된 이름만으로 만들며 경로 탈출 검사를 둔다. `.pending`은 직원 id로 쓰일 수 없다(id 규칙상 점으로 시작 불가).

## 3. 대화 기록장(공용 창고)

- 위치 `<HOME>/shared/hejo/journal/`. 형식: 월별 JSONL(`YYYY-MM.jsonl`)만. **별도 head 파일은 두지 않는다.** 권위 있는 복구 원본은 JSONL 자체다. 한 줄 = 기록 프레임 하나(`message·edit·delete·state`, `seq` 포함) + 내부 메타(버튼 해석 정보, 첨부 등록). 앱으로 보낼 때 내부 메타는 뺀다.
- 단독 쓰기: 문은 시작할 때 `journal/.lock`에 배타 `flock`을 잡고 끝날 때까지 유지한다. 잠금 실패 → 리스너를 열지 않고 `retryable=False` 실패(REQ-HF-06.AC-07). 프로세스 안에서는 asyncio 락 하나로 순번 배정과 추가를 직렬화한다.
- 추가 절차: 순번 배정(`seq = 마지막 seq + 1`) → 한 줄(끝에 `\n`)을 한 번의 `write`로 추가 → `flush` + `fsync` → 성공하면 메모리의 마지막 seq 갱신 → 연결된 앱에 전송. `write`·`fsync` 실패 시: 마지막 seq를 올리지 않고, 파일 길이를 추가 전 길이로 되돌리고(`ftruncate`), 프레임을 보내지 않으며 `error(journal_write_failed)`를 알리고 로그를 남긴다(NFR-HF-02). 되돌리기도 실패하면 기록장을 읽기 전용 고장 상태로 두고 새 기록 프레임을 거부한다(재시작 때 아래 복구).
- 시작 시 복구: 가장 최근 월 파일부터 거꾸로 읽어 **마지막 완전한 줄**(끝 `\n` 있고 JSON 해석 가능, seq 정수)을 찾는다. 그 뒤 불완전한 꼬리는 잘라 내고 로그에 남긴다. 마지막 seq = 그 줄의 seq(파일이 없으면 0). 월 파일 사이 seq는 이어진다. seq 중복·역순이 발견되면 리스너를 열지 않고 실패로 보고한다(수동 조치).
- 배달 보장: 기록된 줄은 최소 한 번 앱에 간다(전송 전에 멈췄으면 재접속 sync로). 앱은 2.1 규칙으로 중복을 버린다.
- 첨부 등록·버튼 해석 정보도 같은 줄의 내부 메타로 남겨, 재시작 뒤에도 파일 권한·버튼 해석이 유지된다(버튼은 Hermes 쪽 만료 규칙을 그대로 따른다).
- 스트리밍 수정은 마지막 수정만 남기도록 같은 `msg_id`의 `edit`을 0.5초 단위로 합쳐 쓴다(`final=true`는 항상 즉시 기록).
- 직원 기억(세션)과 별개다. 앱 화면의 원본은 기록장, 직원이 기억하는 대화의 원본은 세션이다.
- 수명: 영구. 제거·갱신이 지우지 않는다. 보존 기간 정책은 후속 작업.

## 4. 문 모듈 구성(`gate/`)

| 모듈 | 책임 |
|---|---|
| `plugin.yaml`, `__init__.py` | 매니페스트(`kind: platform`, `name: hejo`), `register(ctx)` |
| `adapter.py` | `HejoAdapter(BasePlatformAdapter)`: connect/disconnect/send/edit/typing/send_document·image/send_clarify/_send_exec_approval_prompt/send_slash_confirm/get_chat_info, 들어온 프레임 → MessageEvent |
| `server.py` | aiohttp 앱(WebSocket + HTTP), 접속 주소 검사, 연결 관리 |
| `auth.py` | 페어링 코드·출입증(발급·검증·취소, 해시 저장, 실패 잠금) |
| `journal.py` | 기록장(순번·추가·재전송·첨부 등록) |
| `roster.py` | 직원 목록(처리 중 프로필 + 명부 감지) |
| `buttons.py` | 버튼 등록·해석(`cl:`/`appr:`/`sc:` 해석 함수 호출, team-kit 답장 버튼 연결점) |
| `cli.py` | `hejo-gate pair|devices|revoke|status`(운영자가 Mac mini에서 실행) |

- Hermes 기본 버튼 해석: 질문 `tools.clarify_gateway.resolve_gateway_clarify`(`R/tools/clarify_gateway.py:127`), 실행 승인 `tools.approval.resolve_gateway_approval`(`R/tools/approval.py:139`, 0이면 만료), 슬래시 확인 `tools.slash_confirm.resolve`(`R/tools/slash_confirm.py:64`). 참고 구현 `R/gateway/platforms/whatsapp_cloud.py:828-955`.
- 접속 주소 검사: 상대 주소가 루프백(127.0.0.0/8, ::1) 또는 Tailscale 범위(100.64.0.0/10, fd7a:115c:a1e0::/48)가 아니면 핸드셰이크 전에 닫는다. 듣는 주소는 설정 `extra.listen`(기본 `["127.0.0.1"]`), 설치 도우미가 `tailscale ip -4` 결과를 사장 확인 뒤 추가한다. 포트 기본 47820, 설정 `extra.port`.
- 리스너 실패(포트 사용 중)는 `_set_fatal_error(retryable=False)`로 끝내 재접속 폭주를 막는다(`R/gateway/run_adapters.py:1522` 재시도 경로 회피).

### 4.1 보조 프로필 배달(TASK-03a 탐침 → 계획 담당 결정)

**결정(5판, 2026-11-14 사용자 승인): A 전달자 채택(보강).** 근거는 verdict 5차(A 성공, B는 본체 배달 전 설정 검사 `tools/send_message_tool.py:319-323`·`cron/scheduler_delivery.py:1407-1408`에서 차단). 대안 D(직원별 리스너)·E(파일 쪽지함)·F(본체 수정)는 기각. 보강 4항:
1. 허브는 연결 때가 아니라 **보낼 때마다** 모듈 수준 등록에서 찾는다. 보조 어댑터는 기본 문 유무와 관계없이 연결됨으로 표시해 시작 순서에 영향받지 않는다.
2. 허브가 없으면 `SendResult(success=False, error="hejo_primary_unavailable")`와 로그로 끝낸다(fail closed, 다른 경로 없음).
3. 전달 대상은 `send`·`edit_message`·`send_typing`·`stop_typing`·버튼 메타·첨부(`send_document`/`send_image_file` 등 TASK-03b 첨부 경로)다. 직원 이름은 어댑터의 `_owner_profile`에서 정하고 호출자 메타데이터로 바꿀 수 없다.
4. 설정: 보조 프로필 `config.yaml`에 `plugins.enabled`의 hejo와 `gateway.platforms.hejo: {enabled: true, extra: {role: forwarder}}`(포트·주소 없음)를 설치 도우미가 영수증과 함께 쓴다. 이후 앱에서 직원을 만들 때도 같은 블록을 쓴다(후속 직원 생성 작업). 예약 보고의 기본 대상(`home_channel`)은 `{platform: hejo, chat_id: <직원 id>}`이며 스레드는 배달마다 새로 만든다.

**후속(2단계, Slack 은퇴 때):** 보조 직원에게서 Slack 연결이 빠지면 Hermes 위성 직원 경로(`R/gateway/authz_mixin.py:208-235` `_is_shared_bot_satellite`, 자기 어댑터가 없는 프로필은 기본 어댑터로 배달)가 성립할 수 있다. 그때 탐침해 `send_message` 설정 검사까지 통과하면 보조 프로필 hejo 설정을 영수증으로 걷어내고 전달자를 은퇴시킨다. 9절의 위성 방식 기각은 병행 기간에 한한다.

[확인] 보조 직원이 자기 연결(Slack)을 가지면 기본 프로필 어댑터를 빌리지 못한다(`R/gateway/authz_mixin.py:208-226`, fail closed). 예약 보고·`send_message` 같은 먼저 보내기는 그 직원의 어댑터 지도에서 hejo를 찾고, 없으면 플러그인의 `standalone_sender_fn`으로 간다(`R/tools/send_message_senders.py:313-339`).

| 안 | 방식 | 판정 기준 |
|---|---|---|
| A. 전달자 어댑터 | 모든 프로필에서 hejo를 켠다. 보조 프로필 어댑터는 포트를 묶지 않고 연결됨으로 표시하며, `send` 등을 같은 프로세스의 기본 문(모듈 수준 허브)으로 넘긴다 | 탐침에서 보조 프로필 예약 작업 `deliver=hejo`가 그 직원 스레드로 도착하고, 보조 어댑터가 포트·중복 자격 검사(`run_adapters.py:1147`)에 걸리지 않으면 채택 |
| B. 단독 발신자 | 기본 프로필에서만 켜고, `standalone_sender_fn`이 같은 프로세스 허브(없으면 루프백 내부 경로)로 넘긴다 | A가 실패하고 보조 프로필에서 `deliver=hejo`가 유효 대상으로 인정되면 채택 |

절차:
1. TASK-03a(구현 담당, 탐침 전용): 임시 홈의 실제 게이트웨이에서 A와 B를 각각 시험하고 결과·로그만 impl-report에 남긴다. 운영 코드로 채택하지 않는다(탐침 코드는 `gate/probes/`에 두고 결정 뒤 제거 또는 승격).
2. 계획 담당: 결과로 안을 결정하고 spec(REQ-HF-01·10, AC)·design·수락 시험(AT-HF-02, AT-HF-22)·tasks를 개정한다. A 채택은 "보조 프로필에서 hejo를 켬"이라는 운영 설정 변경을 포함하므로 사용자 승인 뒤에만 TASK-03b·07에 넘긴다.
3. 구현 담당은 탐침 결과로 AC나 시험을 바꾸지 않는다.

둘 다 실패하면 REQ-HF-10만 보류하고 사용자에게 선택지를 올린다(나머지 진행).

## 5. team-kit 답장 버튼 연결(운영 저장소, TASK-04)

- [확인] 중립 부분: `reply_buttons.extract`, `extract_checklist`, `allowed_labels`, `clicked_context`, `button_policy.guard`(`TK/lib/hermes_reply/reply_buttons.py:134-180,107-127`, `TK/lib/hermes_team_services/button_policy.py:92-110`). Slack 전용: Block Kit 배치·`adopt_click`·Bolt 등록.
- 변경: `TK/lib/hermes_reply/plugin.py:41` 옆에 `register_platform_handler('hejo', hejo_factory)`를 추가한다. hejo 설치기는 어댑터의 `send`/`edit_message`(2.2절 서명)를 감싸 `controls(content)`로 표식을 떼고 `metadata["hejo_buttons"] = [{"label": 라벨, "style": …}]`(id는 문이 발급), `metadata["hejo_reply_state"] = "asked"`를 넘긴다. 클릭은 `register_click_handler("reply", …)`로 받아 `False`를 돌려 문 기본 처리(2.2절 이벤트)를 쓰게 하고, `await set_reply_state(msg_id, "answered")`, 최종 답장 때 `"closed"`를 보낸다.
- `controls()`는 `plugin.py:117`에서 `reply_buttons`로 옮겨 Slack과 hejo가 같이 쓴다(동작 보존 리팩토링, Slack 시험으로 비교).
- 문은 team-kit을 import하지 않는다. 연결은 team-kit 쪽 등록이 문 어댑터의 공개 훅(2.2절: `metadata["hejo_buttons"]`, `metadata["hejo_reply_state"]`, `set_reply_state`, `register_click_handler`)만 쓴다. team-kit이 없으면 `[[버튼: …]]` 표식은 `button_policy`가 없으므로 글자 그대로 남고, 문은 `[[버튼: A | B]]`를 `A / B` 글자로 바꿔 보낸다(REQ-HF-09.AC-03).
- usage_ledger·hermes_router에는 이번 작업에서 hejo를 추가하지 않는다(1:1이라 안내원 불필요, 사용량 꼬리말 미사용). 2단계 단체방 작업에서 다룬다.

## 6. 앱 구조(`app/`)

- AppKit, `xcrun swiftc -parse-as-library … -target arm64-apple-macosx13.0` 단일 빌드(ddots `D/scripts/build.sh` 패턴). 번들 ID `io.github.hermes-hejo.hejo`, 이름 hejo, 서명 기본 `AIpet Local Development`(환경 변수로 바꿈), `LSUIElement`.
- 베껴 올 파일(ddots 조사 결과): `AppIdentity`, `LoginLaunch`(iMessage 점검 제거), `OptionsLayout`, `SmokeCheck`, `MenuBarIcon`, `DdotsThreadWindow`, `MessageFormat`(SwiftUI import 제거), `SlackLayout`(이름 `TextLayout`), `ChatStyle`, `ClipboardAttachments`; 다듬어 `NativeThreadCard`(hosted 경로 제거), `NativeThreadList`(표·셀·스크롤 핵심, `NSViewRepresentable` 제거), `DraftEditor`·`DraftFormat`(AppKit 클래스만), `AttachmentDrop`(AppKit 뷰만), `ProfileAvatar`(구조체만), `Conversation.swift` 모델 일부를 중립 이름으로, 키체인은 `/usr/bin/security` 방식 헬퍼(약 30줄, 엄격한 문자 검사 유지).
- 베끼기 원칙(4판, 사용자 지시 "코드를 가져올 때는 실제로 코드를 모두 살펴보고 가져와야 한다"): 아래 베낄 파일 목록은 조사에서 나온 **후보**다. 구현 담당은 베끼기 전에 후보 파일 전체와, 그 파일이 부르는 ddots 코드(호출·확장·전역 상태·자원·Info.plist 키)를 끝까지 읽고 `docs/changes/HEJO-FOUNDATION-20261114/copy-review.md`에 파일마다 기록한다. 기록할 것은 원본 경로·줄 수·커밋, 읽은 범위(전체), 의존(가져옴·대체·제거), 뺀 부분과 이유, SwiftUI·Slack·개인값(이름·경로·계정·번들 ID) 발견과 처리, hejo 쪽 대상 파일이다. 기록이 없는 파일은 베끼지 않는다. 일부만 읽고 "그대로 베낌"으로 표시하지 않는다. 목록에 없던 의존이 나오면 기록에 추가하고, 칸 배치나 범위가 바뀌면 멈추고 보고한다.
- 펫 창 구조(4판, REQ-HF-16): ddots 펫 열기·닫기 구조를 그대로 베낀다. `PetLayout`(배치·`ChatMorph` 0.30초), `GenieView`, `PetAnimation`, `PetPointerInteraction`, `PetSprite{Rasterizer,Contour,Presentation}`, `PetCarrySmoke`, `ScreenWindowResolver`는 순수 AppKit이라 그대로 베낀다. `PetView.swift`는 `PetPanel`(테두리 없음·`.nonactivatingPanel`·`.floating`·모든 Space·전체 화면 보조, 펼쳐졌을 때만 키 창)과 `PetView`(끌기·크기 조절·클릭)만 가져오고 SwiftUI 호스트(`GenieChatHost`·클립보드·말풍선 답장·파일 놓기 호스트)와 `slackModel`·`installChat`을 뺀다. 대화 내용은 hejo의 AppKit 대화 뷰(`NSView`)를 넣고, `captureGenie`는 그 뷰의 `cacheDisplay`로 찍는다. `App.swift`에서는 `showChat`·`collapseChat`·`placePet`·`advancePlacement`·끌기·화면 변경 처리만 새 `PetController`로 옮기고 `slack.*`·`web.*`·`paneSplit` 계산을 뺀다. 펫 그림(`Resources/Pet/`)은 같은 저작권자의 자산으로 LICENSE와 함께 베낀다. 펫 기본 이름은 중립 값으로 두고 사장이 바꾼다(`PetIdentity`). `ChatPet`(SwiftUI 미니 펫)은 가져오지 않는다. `ChatPanel`·`ChatPresentation`·`ChatWorkspace`는 아래 대화 화면 항목대로 AppKit으로 옮긴다(8판).
- **대화 화면 = ddots 현재 화면 그대로(8판, 사용자 지시).** 화면 기준은 시안(`mockup/hejo-ui*.html`)이 아니라 실행 중인 ddots의 대화 화면이다. 시안 1·2판은 참고 자료일 뿐 TASK-06 기준이 아니다. 옮길 원본: `ChatPanel.swift`의 `ChatView`·`ChatDragView`, `SlackPanel.swift`의 `ChatView` 확장(`slackPane`·`slackRooms`·`slackTab`·`slackRow`·`slackSearchField`·`slackSidebarHandle`·`slackConversation`/`nativeConversation`·`slackThread`·`slackFoot`·`slackStack`·`slackLine`·`slackApproval`·`slackComposer`·`slackFailures`·`fileView`·`slackAttachments`·`slackNoticeBar`)과 `SlackSidebar` 상수, `SlackLayout.swift`(`SlackZones` 등 배치 상수), `ChatPresentation.swift`(머리글·문맥 메뉴), `ChatWorkspace.swift`, `NativeThreadList`·`NativeThreadCard`(+ 그 안에 호스트된 SwiftUI 조각), `ChatStyle`, `DraftEditor`·`SlackComposerInput`, ddots `PetView`의 안 읽은 표시(`unreadCount` 배지). 이 중 SwiftUI로 된 부분은 **같은 크기·간격·색·글꼴·애니메이션의 AppKit으로 옮긴다**(AppKit 기본 원칙, SwiftUI 예외 없음). 옮김 대응(SwiftUI 뷰 → AppKit 클래스, 상수 출처)은 `copy-review.md`에 기록한다. 탭 줄의 '방'은 hejo의 '직원'으로, 스레드·글·첨부·버튼은 hejo 중립 모델로 바꾼다. 뺄 것(Slack 전용·2단계): 단체방 구역·핀·음소거·멘션 얼굴, 금고·드라이브 버튼, 프로젝트 기록, 웹 창, 클립보드 선반, iMessage·HermesRelay 출처, Slack 찾기·붙여넣기 특수 처리, 말풍선 답장 동작. 빠지는 자리는 비워 두지 않고 ddots에서 그 요소가 없을 때의 모양을 따른다. **방 단위 모델(8판 보완, 사용자 승인):** 앱의 탭·목록·안 읽은 수·카드 목록은 `Room{id, kind, title, members}` 단위로 다룬다. 1단계에는 `kind = direct`(직원 1:1, `id` = 직원 id, `members` = [그 직원]) 하나만 만든다. 2단계 단체방은 새 `kind`를 더해 같은 화면에 넣는다. 통신 규격(employee·thread)은 지금 바꾸지 않고, 앱이 `employee`를 1:1 방으로 대응시킨다. 2단계에서 방 정보를 규격에 더한다.
- 새로 AppKit으로: `AppDelegate`·진입점, 설정 저장(`hejo-local.json`), 연결 창, 직원 사이드바(`NSTableView`), 스레드 목록, 스레드 어댑터(중립 모델 → 카드 내용), 버튼 줄·작성 중 점·첨부 타일, 입력 줄, 머리글, WebSocket 클라이언트(`URLSessionWebSocketTask`, 템플릿 `D/Sources/UsageSources.swift`).
- 가져오지 않음: `Slack*` 전체, `HermesRelay*`, `HermesBridge`, `RemoteHermes`, `DdotsArchive`, `DdotsConfig`, `SettingsSync`, `App.swift`, Sparkle·업데이트, `Usage*`, 펫의 부가 기능(말풍선 답장·클립보드 선반·대시보드 문구), 클립보드 등 부가 기능, `*Smoke.swift`(SmokeCheck 제외).
- 앱 상태: 기록장 캐시는 `~/Library/Application Support/hejo/cache/`(조회용 복제, 지워도 재동기화), 적용한 마지막 seq·스레드별 읽은 seq는 `hejo-local.json`. 권위는 문의 기록장, 동기화는 2.1 규칙, 충돌 시 문 값으로 덮어쓴다. 캐시를 지우면 `applied = 0`으로 전체 재동기화한다.

### 로고와 아일랜드(9판, 2026-11-15 사용자 결정)

**로고(REQ-HF-17):** `ConversationView`의 `brand`를 `HEJO.`로 바꾼다. 첫 글자 H만 `systemBlue`인 속성 문자열이다(ddots의 `d` + `dots.` 방식). 그 밑의 `version`은 그대로 둔다. 방이 없을 때의 머리글 대체 글자도 `HEJO.`로 바꾼다.

**아일랜드(REQ-HF-18):** 새 AppKit 보기 `IslandView`와 상태 계산기 `IslandModel`로 만든다. SwiftUI는 쓰지 않는다.

- **위치**
  - 머리글 줄에서 로고 칸(`left` 폭) 바로 오른쪽에 둔다. x = left + 12, 높이 30, 세로 가운데.
  - 방 제목·부제는 알약 오른쪽 끝 + 12에서 시작해 잘린다.
  - 최대 너비 = 머리글 폭 − 로고 칸 − 오른쪽 아이콘 − 방 제목 최소 120.
- **칸**: 문제 → 사장 차례 → 일하는 직원 순서다. 칸 사이는 1×14 선이고, 빈 칸은 없앤다. 세 칸이 모두 비면 44×12 띠만 남긴다.
- **입력 원본(새 원본을 만들지 않음)**

  | 칸 | 원본 |
  |---|---|
  | 사장 차례 A | `ConversationModel.messages` 중 직원 글이면서 `replyState == "asked"`인 수. 상태가 answered·closed로 바뀌면 빠진다 |
  | 사장 차례 U | 기존 안 읽은 수의 합(탭 배지와 같은 값) |
  | 일하는 직원 | `ConversationModel.typing`의 살아 있는 키. 경과 분 = 그 직원 작성 중이 처음 켜진 시각부터 |
  | 연결 | `GateClient` 연결 상태와 다음 재시도 시각 |
  | 보내기 실패 | `ConversationController.sendCurrent`·`click`·`open`이 실패할 때의 `transferFailed` 문구. 실패한 글은 `drafts[key]`에 남는다. 알약에는 실패 문구와 첫 말을 보여 준다. "다시 보내기"는 다시 보낼 수 있는 실패(`notConnected`·기타)에만 붙이고 `sendCurrent(for: key)`를 부른다. 너무 큼·출입증·파일 바뀜은 문구만 보여 준다. 이 실패 문구는 notice 띠 대신 알약으로 옮긴다 |
  | 업로드 | `sendCurrent`의 첨부 반복에서 올린 수 k와 전체 n을 컨트롤러 상태로 내보낸다(새 원본이 아니라 진행 중 값이다) |

- **잠깐 늘어남**: 새 `asked`는 4초, 다른 스레드의 새 직원 글은 3초다. 같은 것이 겹치면 줄을 세우고, 높은 것(문제 > 사장 차례 > 직원)이 오면 낮은 것은 뒤로 미룬다.
- **누르기**
  - 사장 차례 → 가장 오래된 `asked` 글로 이동한다. 기존 탭 선택, 스레드 펼침, 스크롤 경로를 그대로 쓰고 1.5초 강조를 더한다.
  - 직원 → 그 직원 탭.
  - 문제 → `GateClient` 즉시 재접속, 또는 기존 다시 보내기.
- **일하는 중 움직임(사용자 선택, 시안 v32 3번)**: 도는 고리를 쓰지 않는다. "일하는 중"·"N명 일하는 중" 글자에 밝은 빛 띠가 왼→오로 지나가는 반짝임을 준다(1.6초 반복). 글자 마스크 위의 그라데이션 레이어 위치만 바꾸는 방식이라 글자 배치는 변하지 않는다. 동작 줄이기면 흐린 글자로 멈춘다.
- **올리기**: 사장 차례 칸에 마우스를 올리면 최근 `asked` 질문 한 줄과 "열기 ›"를 보여 준다. 칸 높이는 그대로다.
- **끌기**: `ConversationHeaderDrag`가 알약 사각형 안의 마우스 이벤트를 받지 않게 한다.
- **연결 끊김 띠**: 기존 끊김 띠(banner의 연결 용도)는 아일랜드로 옮긴다.
- **1단계 범위 밖**(데이터 또는 위험 문제)
  - 알약 안 답 버튼과 5초 되돌리기: 보낸 클릭은 직원 차례를 바로 시작하므로, 되돌리려면 보내기를 늦추는 설계가 필요하다. 승인·결제 같은 중요 버튼을 구분할 표식도 없다.
  - 왼쪽 할 일 칸(drawer).
  - D-day·마감: 규격에 마감 정보가 없다.
  - 직원 작업 실패: 구조화된 실패 이벤트가 없다.
  - 아침 요약, 펫 배지 색 변화.
- **시험**: AT-HF-52~56. 앱 시험은 가짜 모델 상태를 넣어 칸, 너비, 글자, 누르기 결과를 단언한다. 자동 캡처는 `evidence/HEJO-FOUNDATION/`에 둔다.
- **시안**(참고일 뿐, 기준 아님): `mockup/hejo-ui-v28-island-logo`, `hejo-ui-v31-island-all`.

### 대화 안 작성 중 표시(9판, REQ-HF-19, REQ-HF-12 예외)

- **기다림**
  - `ConversationView`의 작성 중 accessory(`thread.id+":typing"`)는 높이 22를 그대로 쓴다.
  - 그 안의 글자를 "작성 중" 반짝임 글자와 흐린 경과 초로 바꾼다.
  - 반짝임은 아일랜드와 같은 부품을 함께 쓴다(같은 1.6초). 따라서 TASK-11의 반짝임 보기를 재사용할 수 있게 만든다.
  - 경과 초의 시작 시각은 스레드별 작성 중 첫 켜짐 시각이다. 아일랜드 직원 칸의 경과 분과 같은 원본(작성 중 켜짐 기록)을 쓴다.
- **흘러나옴**
  - `NativeThreadCard`에서 `post.streaming`인 글의 본문 끝 글자 위치에 커서 보기(2pt, `systemBlue`)를 덧그린다.
  - 커서는 글자 속성이나 문자열에 넣지 않는다. 글을 다시 배치하지 않고, 높이 계산(`streamHeights`)에도 영향을 주지 않는다.
  - final이 오면 커서를 없앤다.
- **동작 줄이기**: 반짝임과 깜빡임을 멈춘다.
- **시안**: `mockup/hejo-ui-v33-chat-typing`의 1번과 4번.

### 사장 계정 로그인(10판 개정, REQ-HF-20)

- **원본:** 문 `AuthStore`의 `account.json`(아이디, scrypt 기록, 실패·잠금, `google_sub`·`google_email`)과 기존 `devices.json`(출입증). 앱은 출입증만 Keychain에 둔다.
- **공항 Mac 증표:** 기본 문이 시작할 때 `local_code(port)`로 `pairing.json`의 `local_hash`와 0600 `local-pair.json`을 만든다. 가입·재설정·Google 연결(`hello.local`)은 루프백이고 `consume_local`이 참일 때만 한다. 같은 사용자 프로세스는 이미 `~/.hermes`를 읽을 수 있어서 새 권한이 생기지 않는다. 이 증표만으로 출입증을 주는 길은 없다(자동 입장 없음).
- **로그인:** `hello.login` → `AuthStore.login`(10분 5회 잠금). `hello.google` → `gate/google.py identity`(인가 코드 교환 + tokeninfo 확인, 10초 제한) → `google_login(sub)`. `new_password`가 있으면 재설정한다. 재설정은 모든 출입증을 취소한다.
- **Google 설정:** 사장이 Google Cloud에서 "데스크톱 앱" OAuth 클라이언트를 만들고, 공항 Mac에서 `python -m gate.cli google <client_id>`에 비밀을 표준 입력으로 넣는다. 그러면 `<HOME>/hejo/google-client.json`(0600)이 생긴다. 비밀은 문에만 있고 앱·저장소에는 없다.
- **앱:** `LoginWindow`가 `AirportFinder.findAddress`(공항 Mac 증표 → Tailscale 온라인 Mac의 47820)와 `GET /v1/auth`로 화면을 고른다(가입·로그인·재설정·못 찾음). `GoogleSignIn`은 PKCE, 루프백 리스너, 브라우저 열기를 맡는다. `GateClient.signIn`은 한 번만 쓰는 hello 필드를 보낸다.

### SwiftUI 예외 목록

| 화면 | 이유 |
|---|---|
| 없음 | 이번 작업의 모든 화면은 AppKit으로 만든다. 필요하면 구현 담당이 멈추고 보고한다 |

## 7. 설치 도우미(`install/`)와 개인값 검사

- `install/hejo-install [--home PATH] [--check] [--uninstall]`:
  1. Hermes 홈 찾기(`HERMES_HOME` → 기본 경로). 조립식 감지(`owner/team.yaml` 존재)만 기록, 이번 작업에서 조립 층 설치는 하지 않음.
  2. `<HOME>/plugins/hejo` → 저장소 `gate/` 심볼릭 링크(운영 저장소 `./sync`는 링크를 링크로 모은다, `<운영 저장소>/sync:61-70`).
  3. 기본 프로필 `config.yaml`: `plugins.enabled`에 hejo 추가, `gateway.platforms.hejo: {enabled: true, extra: {port: 47820, listen: ["127.0.0.1"], allowed_users: ["owner"]}}`. 
  3-1. (5판) 보조 프로필마다 `<보조 홈>/plugins/hejo` 링크, `plugins.enabled`에 hejo, `gateway.platforms.hejo: {enabled: true, extra: {role: forwarder}}`. 보조 프로필 목록은 Hermes 프로필 API로 읽고 각 대상을 영수증에 넣는다.
  4. `<HOME>/hejo/`(0700)와 빈 `devices.json`(0600) 생성.
  5. 게이트웨이 재시작은 하지 않고 안내만 출력한다. 재시작은 운영 단계(TASK-09)에서 사장 확인 뒤 한다.
- 비밀 파일: 설치 도우미는 `.env*`, `auth.json`, `*token*`, `*secret*` 파일을 열지도 쓰지도 않는다. 허용 사용자는 3번의 `config.yaml` 값으로 처리한다(1절).
- 설치 영수증 `<HOME>/hejo/install-receipt.json`(0600):
  - 최초 설치 때 **변경 전에** 만든다. 대상마다 `{path(설정 키 경로 또는 파일 경로), existed(bool), before(설치 전 값 또는 링크 대상), after(설치가 쓴 값)}`와 단계 상태(`pending`/`applied`)를 적는다. 대상: `plugins.enabled`(목록 전체의 before/after), `gateway.platforms.hejo`(블록 전체), `<HOME>/plugins/hejo` 링크, `<HOME>/hejo/` 생성 여부.
  - 재설치: 영수증이 이미 `installed` 상태면 `before`를 바꾸지 않는다. 현재 값이 `after`와 같으면 변경 없음, 다르면(사장이 바꿈) 그 대상은 건드리지 않고 알린다.
  - 기록 부트스트랩(7판, T07-01 결정): 영수증을 쓰려면 `<HOME>/hejo/`(0700)가 있어야 하므로, 이 디렉터리 생성은 영수증보다 먼저 하는 **기록용 준비 단계**이며 되돌림 대상이 아니다. 영수증에는 `{path: <HOME>/hejo, existed}`를 정보로만 남긴다. 그 밖의 대상(설정 키·링크·`devices.json`)은 모두 영수증 뒤에 바꾸고 되돌림 대상이다.
  - 중간 실패: 단계마다 `applied`로 갱신한다. 예외가 나면 `applied`인 단계를 역순으로 `before`로 되돌리고 영수증을 `failed`로 표시, 종료 코드 1. 실패 뒤 남는 것은 `<HOME>/hejo/` 디렉터리(원래 없었으면 새로 생긴 것)와 그 안의 `failed` 영수증뿐이다.
  - 제거(`--uninstall`): 대상마다 현재 값이 `after`와 같을 때만 `before`로 되돌린다(`existed=false`면 키·링크 삭제). 다르면 그 대상은 건드리지 않고 충돌로 보고하며 끝에 종료 코드 2(`--force`면 되돌림). `<HOME>/hejo/`의 금고 파일·기록장·첨부는 지우지 않는다. 영수증은 `uninstalled`로 표시해 남긴다.
  - `config.yaml` 쓰기는 ruamel 왕복(주석·순서 보존), 임시 파일 + `os.replace`로 원자적 교체.
- `scripts/scan_private.py`: 운영 저장소 `hermes_facility.airport_boundaries`(TK)와 같은 패턴 규칙을 hejo **추적 파일 전체**(`git ls-files`)에 확장자와 무관하게 적용한다. 분류: 파일 앞 8 KiB에 NUL 바이트가 없고 UTF-8로 읽히면 텍스트(검사), 아니면 바이너리(검사 생략, 목록에 "바이너리 생략"으로 출력). 텍스트 중 코드 = 확장자 `.py .swift .sh` 이거나 첫 줄이 `#!`인 파일(확장자 없는 `install/hejo-install`, `githooks/pre-commit` 포함), 문서 = 그 밖의 텍스트.
  - 운영 홈에서 여는 파일은 **`<HOME>/owner/team.yaml`(agents 키·name·label·aliases)과 `<HOME>/owner/vault.yaml`(문자열 값)** 둘뿐이다. 경로를 고정 목록으로 열고 디렉터리 탐색을 하지 않는다. `.env*`·`auth.json`·토큰·`state.db`는 열지 않는다. 운영 홈이나 두 파일이 없으면 패턴 검사만.
  - 출력은 종류·파일·줄 번호·16진 지문만, 값은 출력하지 않는다.
  - 패턴: 명부·금고 단어, Slack ID 모양, 이메일, 사용자·볼륨 절대 경로는 모든 텍스트 파일에 적용한다. 고정 홈 경로 패턴(`airport_boundaries`의 `fixed_home`)만 코드 파일에 적용하고 문서에서는 기본 경로 설명을 허용한다.
  - 예외 목록 `scripts/scan_private_allow.txt`: 한 줄 = `파일 경로`, `그 줄 내용의 지문`, `이유`. 예외는 그 파일의 그 줄 내용에만 적용되며 파일 전체를 빼지 않는다(같은 파일의 다른 줄, 내용이 바뀐 줄은 검사됨). 허용 대상은 가짜 시험 값과 LICENSE의 게시자 저작권 고지 줄뿐이다.
  - `githooks/pre-commit`이 실행한다. 이 저장소는 기준선 없이 위반 0에서 시작한다.
- 공개 전(3단계) 조건: 전체 git 이력에도 같은 검사를 돌려 위반이 없어야 한다.

## 8. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| Slack 게이트웨이·ddots | 유지 | 병행. Slack 은퇴 조건 전까지 손대지 않는다 |
| team-kit `hermes_reply` Slack 경로 | 유지 + `controls()` 이동(통합) | Slack 동작 보존, 같은 함수를 hejo도 사용 |
| ddots 소스 | 유지 | 읽기만. 베껴 온 코드는 hejo 소유 |
| 운영 `config.yaml`(루트·모든 프로필) `prompt_caching.cache_ttl: 5m`/없음 | 교체 | `auto`(9판: 프로필 홈은 루트를 물려받지 않아 각각 둔다). 롤백은 각 파일 값 복원(없던 파일은 키 삭제) |

## 9. 대안

- api_server(`/p/<프로필>/v1`) 사용: 요청-응답이라 먼저 보내기·답장 버튼 불가 → 기각.
- 프로필마다 문이 포트를 따로 염: 같은 포트면 EADDRINUSE 재시도 폭주, 다른 포트면 앱이 6개 연결 → 기각.
- `gateway.profile_routes` 위성 방식: 보조 직원이 Slack 연결을 가져 위성이 아니므로 먼저 보내기 불가(`authz_mixin.py:208-226`) → 병행 기간 기각, Slack 은퇴 때 재탐침(4.1 후속).
- 기록장 없이 세션 기록에서 이력 제공: 버튼 상태·예약 배달·스트리밍 결과가 세션에 같은 모양으로 남지 않음 → 기각.

## 10. 위험과 롤백

- 고위험: 네트워크 리스너·인증(출입증), 운영 게이트웨이 설정 변경, 동시성(기록장 순번).
- 롤백: `install/hejo-install --uninstall`(영수증 키만 되돌림) → 게이트웨이 재시작. 기록장·금고는 남는다. team-kit 변경은 운영 저장소 커밋 되돌림. 캐시는 `5m` 복원.
- 운영 재시작은 Slack 대화를 잠시 끊으므로 TASK-09에서 진행 중 차례가 없을 때 사장 확인 뒤 한다.
