# HEJO-TELEGRAM 수락 시험 명세

- 소유: 기획설계. 3판(2026-11-23, 구현 보류 HT-B01 반영 — 쓸 수 있는 방 4개: 공통 환경 `default` 표시 이름 `Main` 지정, 활성 준비·AT-HT-05·12·45의 토픽 수 3 → 4. 근거 [verdict.md](../../docs/changes/HEJO-TELEGRAM-20261122/verdict.md) 1차). 2판(계획 검증 1회차 반영: F 토픽 호출·로그, AT-HT-01·05·07·12·13·15·20·34·39 수정, AT-HT-45 추가). 1판은 1회차 BLOCKED. 기대값 근거: [spec.md](../../docs/changes/HEJO-TELEGRAM-20261122/spec.md) 요구와 [design.md](../../docs/changes/HEJO-TELEGRAM-20261122/design.md) 3~7절.
- 상태: 모두 "명세 완료 · 코드 미작성 · 미실행 · 미검토". 코드는 구현 담당이 `tests/acceptance/test_telegram.py`(문)와 `app/Tests/`(앱)에 옮기며 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 공통 환경: 임시 `HERMES_HOME`, 가짜 명부(기본 프로필 `default`와 프로필 `alpha`, `beta`; 표시 이름 `Main`, `Alpha`, `Beta`. 기본 프로필도 명부의 직원이라 1:1 방이 있다 — `gate/roster.py` `employees()`), 단체방 `G`(제목 `Team`, 구성원 `alpha`·`beta`, 대표 `alpha`), 실제 Hermes 모듈 import(텔레그램 SDK 없이), 문 어댑터 단독 또는 기존 대역 러너. 증거 수준은 표시가 없으면 2.
- **가짜 텔레그램 어댑터 `F`:** 본체 `BasePlatformAdapter` 하위, 문 이름 `telegram`. 기록하는 메서드: `handle_message`(원래 처리기), `_accept_update()`, `send(chat_id, content, reply_to=None, metadata=None)`(`tg-out-1`, `tg-out-2`… id를 차례로, `raw_response={"message_ids":[...]}`; 나눔 주입 가능: 한 호출에 id 2개; 실패 주입 가능), `send_document`·`send_image_file`(같은 id 규칙, 실패 주입), `send_typing(chat_id, metadata=None)`, 토픽 대역 `F._bot`: `create_forum_topic(chat_id, name, ...)`(돌려주는 객체의 `message_thread_id` = `topic-1`, `topic-2`…; 실패 주입 시 예외, 예외 메시지에 chat_id 포함), `edit_forum_topic(chat_id, message_thread_id, name)`, `close_forum_topic(chat_id, message_thread_id)`, `reopen_forum_topic(chat_id, message_thread_id)`. 실제 어댑터처럼 id를 로그에 쓰는 감싼 메서드 `F._create_dm_topic`·`F.rename_dm_topic`도 두되(어댑터 로거 이름으로 chat_id·토픽 id를 로그에 씀) 호출을 기록한다. `_is_sender_authorized`(기본 `None`, 값 주입). 문이 등록한 `telegram` 공장을 `F`에 적용해 감싼다.
- **가짜 식별자:** 포럼 그룹 `grp-A`(`raw_message.chat.is_forum = True`), 다른 포럼 그룹 `grp-B`, 포럼 아닌 그룹 `grp-N`, 1:1 대화 `dm-A`; 사장 계정 `user-A`, 다른 사람 `user-B`; 받은 글 id `tg-in-1`…; 일반 토픽 `"1"`.
- **이벤트 만들기:** `MessageEvent(text, message_id, reply_to_message_id, media_urls, media_types, source=SessionSource(platform=telegram, chat_type="group"(1:1은 "dm"), chat_id, user_id, thread_id))`, `raw_message`는 `chat.is_forum`·`caption`·`reply_to_message`를 가진 간단한 대역.
- **정착 시간:** 0.05초로 바꿔 넣는다.
- **활성 준비:** 짝짓기(AT-HT-01) 뒤 `telegram_save{enabled:true}` → 동기화가 끝난 뒤(`topics.json`에 쓸 수 있는 방 4개 `default`·`alpha`·`beta`·`G`). 토픽 id는 만든 순서대로 받으며 시험은 `topics.json`에서 방별 토픽 id를 읽는다.

## 자동 시험 — 문

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HT-01 | 01.AC-01·02 | 앱1·앱2(기능 `telegram`) 연결. 앱1이 `telegram_pair{id:"p1"}` → 받은 `code`를 `grp-A`/`user-A` 일반 토픽 글로 `F`에 넣음 | `telegram.json.pair.tag`는 8자. 앱1만 `telegram_code{ref:"p1", expires_in:600}`(code 길이 12) 받음. `F.send` 1회(대상 `grp-A`, 본문 `연결됐어요`, `metadata.thread_id` `"1"`), 두 앱 모두 `telegram_status{paired:true, enabled:false}`(ref 없음), 원래 처리기 0회, 기록장 행 증가 0, `telegram.json` 권한 0600, `pair.platform == "telegram"` |
| AT-HT-02 | 01.AC-01 | `telegram_pair` 두 번(`p2`, `p3`) 뒤 `p2`의 코드를 보냄 | 짝 없음, 원래 처리기 1회. `p3` 코드는 짝짓기 됨 |
| AT-HT-03 | 01.AC-03 | (a) 틀린 글 (b) 시계 +601초 뒤 맞는 코드 (c) 쓴 코드 다시 (d) `grp-N`에서 맞는 코드 (e) `dm-A`에서 맞는 코드 (f) `_is_sender_authorized`가 `False`일 때 맞는 코드 | 여섯 경우 모두 원래 처리기 1회(같은 이벤트 객체), `F.send` 0회, `telegram.json`의 `pair` 불변 |
| AT-HT-04 | 01.AC-04 | 활성에서 `telegram_unpair{id:"u1"}` 뒤 `grp-A`/`user-A`의 `alpha` 토픽 글 | `telegram_status{ref:"u1", paired:false, enabled:false}`, 글은 원래 처리기 1회·기록장 불변, `topics.json` 바이트 불변 |
| AT-HT-05 | 01.AC-05 | 활성(`grp-A`) 뒤 새 코드를 `grp-B`/`user-B`로 짝짓고 켬 | `grp-A` 글은 통과. `grp-B`에 방마다 새 토픽 생성(`F._bot.create_forum_topic` 대상 `grp-B` 4회). 새 `pair.tag` ≠ 이전 표지, `topics.json.tag` = 새 표지. 같은 `grp-A`로 다시 짝지어도 새 표지·토픽 새로 만들기 4회 |
| AT-HT-06 | 01.AC-06 | 공장 미적용 상태에서 `telegram_pair{id:"p4"}`, `telegram{id:"q1"}` | `error{ref:"p4", code:"telegram_unavailable"}`, `telegram.json`에 코드 없음, `telegram_status{ref:"q1", platform_ready:false}` |
| AT-HT-07 | 01.AC-07, NFR-04 | 앱1·앱2 연결, AT-HT-01 → 활성(토픽 만들기) → AT-HT-13(a)(b)(c) → AT-HT-20(본문 `hello`) → AT-HT-30(본문 `pong`). 로그 캡처(모든 로거, 어댑터 로거 포함)·앱별 모든 프레임·기록장·`telegram.json`·`settings.json`·`topics.json`·`sent.jsonl` 검색 | 코드 평문: 앱1의 `telegram_code` 1개에만. `grp-A`·`user-A`: `telegram.json`에만 있고 로그·모든 앱 프레임·기록장·나머지 세 파일 0건. 짝 표지·토픽 id·`tg-` 글 id: `telegram.json`(표지)·`topics.json`·`sent.jsonl`·기록장 `client_msg_id`·앱 `message` 프레임의 `client_msg_id`에만, 로그 0건. `hello`·`pong`: 기록장 `message` 행, 앱 `message` 프레임, `F.send` 인자에만, 로그·`telegram_status`·`error`·네 파일 0건. `F._create_dm_topic`·`F.rename_dm_topic` 호출 0회 |
| AT-HT-08 | 02.AC-01·02 | `telegram_save{id:"s1", enabled:true}` → 문 어댑터 끊고 다시 연결 → `telegram{id:"q2"}` | 두 앱 같은 `telegram_status`(요청 앱만 `ref:"s1"`), 재연결 뒤 같은 값, `settings.json` 0600 |
| AT-HT-09 | 02.AC-02 | 짝 없이 `telegram_save{enabled:true}` | `error(telegram_unpaired)`, `settings.json` 바이트 불변, 방송 0 |
| AT-HT-10 | 02.AC-03 | 기능 `telegram` 없는 앱3이 `telegram{id:"q3"}`; 앱1이 짝짓기·저장 | 앱3은 `error{ref:"q3", code:"unexpected_frame"}`, `telegram_status`·`telegram_code` 0건 |
| AT-HT-11 | 02.AC-04, 08.AC-01 | 기능 `["rooms","imessage"]` 앱이 `imessage{id:"q4"}`·`imessage_pair{id:"q5"}`. 문의 등록된 처리기 공장 목록 조회 | 두 요청 모두 `error unexpected_frame`. `photon` 공장 0개, `telegram` 공장 1개 |
| AT-HT-12 | 03.AC-01 | 짝 뒤 켜기 | `F._bot.create_forum_topic` 4회(`grp-A`, 이름 `Main`, `Alpha`, `Beta`, `Team` 각 1회), `topics.json`에 네 방. 다시 끄고 켜면 추가 만들기 0회. `F._create_dm_topic` 호출 0회 |
| AT-HT-13 | 03.AC-02 | 활성에서 (a) 단체방 `H`(제목 `Ops`) 만들기 (b) `H` 제목 `Ops2`로 (c) `H` 보관 (d) 보관 풀기 (e) `H` 삭제 | (a) `F._bot.create_forum_topic` 1회 `Ops` (b) `F._bot.edit_forum_topic` 1회 `Ops2` (c) `close_forum_topic` 1회 (d) `reopen_forum_topic` 1회 (e) `close_forum_topic` 1회. 각 단계 뒤 `topics.json`의 `H` 상태 일치. `F.rename_dm_topic` 호출 0회. 기록장·앱 프레임은 기능 없는 홈과 같음 |
| AT-HT-14 | 03.AC-03 | 활성 뒤 명부에 `gamma` 추가(토픽 없음) → `gamma`가 글을 씀 | 정착 뒤 토픽 만들기 1회(`Gamma`) 다음 `F.send` 1회(`metadata.thread_id` = 새 토픽) |
| AT-HT-15 | 03.AC-04 | `F._bot.create_forum_topic`이 예외(메시지에 `grp-A` 포함)를 내게 하고 켬 → `alpha` 글 기록 → 실패 주입 해제 → 끄고 켬 | 첫 켬 뒤 `telegram_status{topic_problem:true}`, 로그 경고 1줄 이상(`grp-A`·토픽 id 0건), `alpha` 글 발신 0. 다시 켠 뒤 만들기 성공, `topic_problem:false` 방송. 기록장·앱 프레임 영향 없음 |
| AT-HT-16 | 03.AC-05 | 활성에서 `grp-A`/`user-A`가 대응 없는 토픽 `topic-99`에 글 | 방 생성 0, 기록장 불변, `F.send` 1회(본문 `앱에서 만든 방 토픽에 써 주세요`, `thread_id` `topic-99`) |
| AT-HT-20 | 04.AC-01 | 활성. `alpha` 토픽에 `hello`(`tg-in-1`, 답장 아님) | 기록장 사장 글 1행(`employee:"alpha"`, `room` 없음, 새 `thread`, `text:"hello"`, `client_msg_id` = `"telegram:"` + `telegram.json.pair.tag` + `":tg-in-1"`, `grp-A` 미포함), 앱이 그 `message` 수신, 대역 처리기 이벤트 1개, `F` 원래 처리기 0회, `_accept_update` 1회, `F.send` 0회(되보내지 않음) |
| AT-HT-21 | 04.AC-01 | `G` 토픽에 (a) `hi` (b) `@Beta hi` | (a) 받는 직원 `alpha` (b) `beta`. 행에 `room:"G"` |
| AT-HT-22 | 04.AC-02 | AT-HT-20 뒤 `alpha` 답(정착 뒤 `tg-out-1`). (a) `alpha` 토픽에서 `tg-out-1`에 답장 (b) `beta` 토픽에서 `tg-in-1`에 답장 (c) `alpha` 토픽에서 `reply_to_message_id` = 토픽 id인 글 | (a)(b) AT-HT-20 스레드(`alpha` 방)에 추가 (c) `alpha` 방 새 스레드 |
| AT-HT-23 | 04.AC-02 | (a) 모르는 id에 답장 (b) AT-HT-20 스레드를 `thread_delete` 뒤 `tg-out-1`에 답장 | 둘 다 그 토픽 방의 새 스레드 1행씩 |
| AT-HT-24 | 04.AC-03 | (a) 캡션 `look`과 그림 파일 1개 (b) 캡션 없는 문서 1개 (c) `media_text_inlined:[True]`, `text`="caption\n[문서 내용]", `raw_message.caption`="caption"인 문서 | (a) 사장 글 1행 `text:"look"`, `files` 1개, 파일 내용 바이트 동일 (b) `text:""`, `files` 1개 (c) `text:"caption"`, `files` 1개. 셋 다 첨부 저장소에 있음 |
| AT-HT-25 | 04.AC-04 | 활성. (a) 일반 토픽 `"1"` 글 (b) `H` 보관 뒤 `H` 토픽 글 | 둘 다 기록장 불변, `F.send` 1회씩(본문 `앱에서 만든 방 토픽에 써 주세요`) |
| AT-HT-26 | 04.AC-05 | (a) 짝 없음 (b) 짝 있고 꺼짐 (c) 활성에서 `user-B` (d) 활성에서 `grp-B` (e) 활성에서 `dm-A` (f) `claims_external` 안에서 예외(금고 파일을 읽을 수 없게) | 여섯 경우 모두 원래 처리기 1회(같은 객체, `source` 필드 불변), 기록장 불변, `F.send` 0회 |
| AT-HT-27 | 04.AC-06 | AT-HT-20의 같은 이벤트(같은 `tg-in-1`)를 한 번 더 넣음 | 기록장 행 증가 0, 원래 처리기 0회 |
| AT-HT-28 | 04.AC-07 | (a) 첨부 저장 실패 주입 (b) 본문이 `text_bytes` 한도 초과 | 둘 다 기록장 불변, `F.send` 1회(본문 `지금은 받지 못했어요`), 원래 처리기 0회 |
| AT-HT-30 | 05.AC-01 | 활성. 앱이 `alpha` 방에 사장 글 `ping` → `alpha`가 `pong` 기록, 작성 중 꺼짐, 정착 | `F.send` 순서: ① `[사장] ping`(`thread_id` = alpha 토픽, `notify` 없음 또는 거짓, `reply_to` 없음) ② `[Alpha] pong`(`notify` 참, `reply_to` = ①의 id) |
| AT-HT-31 | 05.AC-01, 07 | `alpha`가 작성 중인 동안 `pong` 기록, 정착 시간의 3배 기다림 → 작성 중 끔 → 정착 | 작성 중인 동안 `pong` 발신 0, 끈 뒤 1회. 생각 중 글(`context.thinking`)은 0회 |
| AT-HT-32 | 05.AC-02 | AT-HT-20(텔레그램 사장 글) 뒤 정착 | `[사장] hello` 발신 0 |
| AT-HT-33 | 05.AC-03 | `G` 방 한 스레드에 직원 글 셋 기록(`beta` a, `alpha` b, `beta` c) | `[Beta] a`, `[Alpha] b`, `[Beta] c` 순서, 첫 글은 `reply_to` 없음, 나머지 둘은 `reply_to` = 첫 글 id. 이름표에 `Team` 없음 |
| AT-HT-34 | 05.AC-04 | (a) `alpha`가 그림 `p.png`와 문서 `d.txt`를 붙인 글 (b) 없는 파일 `x.bin`을 가리키는 글 (c) `F.send_document` 실패 주입(거짓 결과, 다음 회는 예외) 뒤 문서를 붙인 글 둘 | (a) 본문 발신 뒤 `send_image_file` 1회·`send_document` 1회(둘 다 같은 토픽, `reply_to` = 본문 첫 통 id) (b) 본문 끝에 `📎 x.bin (hejo 앱에서 열기)`, 파일 발신 0 (c) 두 글 모두 본문 발신 1회(📎 줄 없음), 파일 발신 1회씩, 다시 보내지 않음, 추가 `F.send` 0, 로그 1줄씩(id·파일 이름 없음), 기록장·앱 프레임 영향 없음 |
| AT-HT-35 | 05.AC-04 | 선택 버튼 `A`/`B` 글, 일반 버튼 글 | HEJO-IMESSAGE REQ-HI-05.AC-08과 같은 덧붙임 줄(`선택: A / B`, `(이 선택은 hejo 앱에서 눌러 주세요)`) |
| AT-HT-36 | 05.AC-05 | 나눔 주입(한 발신이 id 2개) → 문 다시 시작 → 두 번째 id에 답장 | `sent.jsonl` 2줄(같은 `msg_id`), 재시작 뒤 답장이 그 스레드로 |
| AT-HT-37 | 05.AC-06 | 발신 실패 주입 뒤 같은 글 정착 | 로그 1줄(id·본문 없음), 다시 보내지 않음, 기록장·앱 프레임 영향 없음 |
| AT-HT-38 | 05.AC-07 | 꺼진 동안 `alpha` 글 기록 → 켬 → 정착 시간 3배 | 그 글 발신 0 |
| AT-HT-39 | 05.AC-08, NFR-03 | 두 홈(기능 켬·활성 / 짝 없음)에 같은 hejo 쪽 대본: 앱이 `alpha` 방·`G` 방에 사장 글, 문 `send`로 직원 글(새 스레드·스레드 답·버튼·첨부), `edit_message`, `delete_message`, `send_typing`/`stop_typing`. 텔레그램 수신은 넣지 않는다 | 두 홈의 기록장 행(시각·uuid 제외)과 앱 프레임 순서·내용 같음. 활성 홈에서만 `F.send` 호출이 있음 |
| AT-HT-40 | 05.AC-06 | `sent.jsonl` 끝에 덜 쓰인 줄, 중간에 깨진 줄. `topics.json`·`settings.json`·`telegram.json` 각각 깨진 JSON으로 문 시작 | 네 경우 모두 문 연결 성공. 금고·설정 손상이면 모든 글 통과·발신 0. `topics.json` 손상이면 다음 동기화가 다시 씀 |
| AT-HT-41 | 06.AC-01·02 | 활성. 문의 `send_typing("alpha", {thread_id})` 3회를 1초 안에 → 5초 뒤 1회. 그리고 `F.send_typing` 실패 주입 | `F.send_typing` 호출 2회(`thread_id` = alpha 토픽), 표시용 `F.send` 0회. 실패 때 차례·발신 정상, 경고 로그 1줄 |
| AT-HT-42 | 08.AC-02 | 저장소 검색 `imessage`·`IMessage`·`photon`(대소문자 무시) — `docs/changes/`, `evidence/`, `tests/acceptance/HEJO-IMESSAGE.md`, `test_imessage.py` 삭제 뒤 남은 파일 기준 | `gate/`, `schemas/`, `app/Sources/`, `app/Tests/` 안 0건. 예외: `ConnectionsWindow.swift`의 서비스 아이콘 `photon`(에이전트 연결 목록, 다리 아님)과 이를 다루는 기존 시험 |
| AT-HT-43 | NFR-01·03 | `bash scripts/test.sh`, `python3 scripts/scan_private.py`(Hermes 환경 Python) | 둘 다 종료 0 |
| AT-HT-45 | 01.AC-05, 04.AC-02 | 짝 표지 `T1`로 AT-HT-20·30 뒤 같은 그룹으로 다시 짝지어 표지 `T2` → 켬 → 옛 `tg-out-1`에 답장(새 토픽 id의 토픽에서), 그리고 같은 글 id `tg-in-1`을 새 토픽에서 보냄 | 옛 글 답장은 그 토픽 방의 새 스레드(옛 표지 대응 안 씀). `tg-in-1`은 새 표지로 새 사장 글 1행(`client_msg_id`에 `T2`) |
| AT-HT-44 | 정착 측정 | `gate/tests/imessage_settling.py`가 이름·참조를 바꿔 유지된 시험 | 5회 모두 2초 미만(HEJO-IMESSAGE AT-HI-39와 같은 기준). 수준 3 |

## 자동 시험 — 앱

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HT-50 | 07.AC-01 | 텔레그램 구역을 상태 6가지(`unsupported`, 연결 전, `platform_ready:false`, 짝 없음, 연결됨, `topic_problem:true`)로 그림 | 상태 글이 spec 문구와 같음. 코드 받기 → `telegram_pair` 프레임, 켜기 → `telegram_save{enabled}`, 해제 → `telegram_unpair` |
| AT-HT-51 | 07.AC-02·03 | `GateClient.features`, 방 메뉴(1:1·단체), 소스 검색 | `features == ["rooms","telegram"]`. 방 메뉴에 아이메시지·텔레그램 항목 0. `IMessageState`·`IMessageSettingsSection`·`IMessageMenus` 정의 0 |
| AT-HT-52 | 07.AC-03 | 옛 문 흉내 고정물(`telegram` 조회에 `unexpected_frame`) | 구역 상태 "서버가 지원하지 않음". 기존 대화 고정 시험 모두 통과 |

## 운영·실물

| ID | AC | 절차 | 기대 |
|---|---|---|---|
| AT-HT-60 | 09.AC-01 | 적용 전 기록: 공용 릴리스 `RELEASE`, 설정 파일 해시(내용 안 봄), 게이트웨이 상태 | 인계 보고에 세 값. 롤백 절차의 명령마다 대상 경로·커밋 채움 |
| AT-HT-61 | 09.AC-02 | 적용 → 재시작 → 로그 | hejo·telegram·Slack 연결, 새 오류·역추적 0, 앱 재연결 뒤 `telegram_status{platform_ready:true}`. 수준 3 |

## 수동 확인 (수준 4, 사장이 안드로이드 폰으로)

| ID | 절차 | 기대 |
|---|---|---|
| M1 | 앱 설정 → 텔레그램 → 코드 받기 → 포럼 그룹에 코드 보내기 | 그룹에 "연결됐어요", 앱 "연결됨" |
| M2 | 앱에서 켜기 | 방마다 토픽이 생김(직원 이름·단체방 제목) |
| M3 | 직원 토픽에 글 보내기 | 앱 그 방에 새 스레드. 직원 답이 `[이름]`과 함께 그 토픽에 알림과 함께, 사장 글에 답장으로 옴. 처리 중 "입력 중" 표시 |
| M4 | 그 답에 답장 | 같은 스레드에 이어짐 |
| M5 | 앱에서 단체방에 글(첨부 하나 포함) | 그 토픽에 `[사장]` 글(무음)과 파일, 직원 답이 이어짐 |
| M6 | 토픽에 사진 보내기 | 앱 그 방에 사진이 붙은 사장 글 |
| M7 | 앱에서 단체방 만들기·이름 바꾸기·보관 | 토픽 생김·이름 바뀜·닫힘 |
| M8 | 앱에서 끄기 → 토픽에 글 | hejo 방에 안 올라감(Hermes 처리기로 감 — 알려진 결과). 다시 켬. Slack·hejo 앱 대화 평소와 같음. 아이메시지는 hejo 이전처럼 Hermes가 답함 |
