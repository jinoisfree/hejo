# HEJO-IMESSAGE 수락 시험 명세

- 소유: 기획설계. 3판(2026-11-20, 구현 검토 1차 반영: AT-HI-11·19·31·34 보강, AT-HI-43·44 추가). 기대값 근거: [spec.md](../../docs/changes/HEJO-IMESSAGE-20261119/spec.md) 요구와 [design.md](../../docs/changes/HEJO-IMESSAGE-20261119/design.md) 3~7절.
- 상태: 모두 "명세 완료 · 코드 미작성 · 미실행 · 미검토". 코드는 구현 담당이 `tests/acceptance/test_imessage.py`(문), `app/Tests/`(앱), team-kit 시험 폴더(안내원)에 옮기며 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 공통 환경: 임시 `HERMES_HOME`, 가짜 명부(기본 프로필 `default`와 프로필 `alpha`, `beta`; 표시 이름 `Alpha`, `Beta`; `alpha` 별칭 `al`), 단체방 `G`(제목 `Team`, 구성원 `alpha`·`beta`, 대표 `alpha`), 실제 Hermes 모듈 import, 문 어댑터 단독 또는 기존 대역 러너. 증거 수준은 표시가 없으면 2.
- **가짜 아이메시지 어댑터 `F`:** 문 이름 `photon`, `MAX_MESSAGE_LENGTH = 100`, `handle_message`(원래 처리기, 호출 기록), `send(chat_id, content, reply_to=None, metadata=None)`(호출 기록, `im-out-1`, `im-out-2`… id를 차례로 돌려줌, 실패 주입 가능), `_is_sender_authorized`(기본 `None`, 값 주입 가능). 문이 등록한 공장을 `F`에 적용해 감싼다.
- **가짜 식별자:** 사장 대화창 `chat-A`·발신자 `user-A`, 다른 사람 `chat-B`·`user-B`, 단체 대화방 `chat-G`. 받은 글 id는 `im-in-1`…
- **정착 시간:** 시험은 0.05초로 바꿔 넣는다. "정착 뒤"는 그 시간이 지나 대기 작업이 끝난 시점이다.
- **활성 준비:** 짝짓기(AT-HI-01 절차) 뒤 `imessage_save{enabled:true, room:"alpha", reports:[]}`.

## 자동 시험

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HI-01 | 01.AC-01 | 앱(기능 `imessage`) 2개 연결. 앱1이 `imessage_pair{id:"p1"}` → 받은 `code`를 `chat-A`/`user-A` 1:1 글로 `F`에 넣음 | 앱1이 `imessage_code{ref:"p1", expires_in:600}`(code 길이 12)를 받음. 코드 글 뒤 `F.send` 1회(대상 `chat-A`), 두 앱 모두 `imessage_status{paired:true}`(ref 없음), 원래 처리기 0회, 기록장 행 증가 0 |
| AT-HI-02 | 01.AC-02 | (a) 대기 중 틀린 글 (b) 시계 +601초 뒤 맞는 코드 (c) 한 번 쓴 코드 다시 (d) `chat-G` 단체 대화방에서 맞는 코드 | 네 경우 모두 원래 처리기 1회씩(같은 이벤트 객체), `F.send` 0회, `imessage.json`의 `pair` 불변 |
| AT-HI-03 | 01.AC-03 | `F._is_sender_authorized`가 `False`를 돌려주게 하고 맞는 코드 | 짝 없음, 원래 처리기 1회, `imessage_status` 방송 0 |
| AT-HI-04 | 01.AC-04 | 활성 상태에서 `imessage_unpair{id:"u1"}` | `imessage_status{ref:"u1", paired:false, enabled:false, room:"alpha"}`, 이후 `chat-A` 글은 원래 처리기 1회·기록장 불변 |
| AT-HI-05 | 01.AC-05 | 짝지은 뒤 새 코드를 받아 `chat-B`/`user-B`에서 보냄 | 이후 `chat-B` 글만 차지, `chat-A` 글은 통과 |
| AT-HI-06 | 01.AC-06 | 공장을 적용하지 않은 채 `imessage_pair{id:"p2"}`, `imessage{id:"q1"}` | `error{ref:"p2", code:"imessage_unavailable"}`, `imessage.json`에 코드 없음. 조회는 `imessage_status{ref:"q1", platform_ready:false}` |
| AT-HI-07 | 01.AC-07, NFR-04 | 앱1·앱2(둘 다 기능 `imessage`) 연결. 앱1이 코드를 받아 짝짓고(AT-HI-01), AT-HI-12(본문 `hello`)·AT-HI-20·AT-HI-22(본문 `pong`)를 실행. 그 뒤 로그 캡처, 앱별로 받은 모든 프레임, 기록장 파일, `imessage.json`·`settings.json`·`sent.jsonl`을 검색 | 코드 평문: 앱1이 받은 `imessage_code` 1개에만 있고 앱2 프레임·로그·기록장·세 파일에 0건. `chat-A`·`user-A`: `imessage.json`에만 있고 모든 프레임·로그·기록장·나머지 두 파일에 0건. 본문 `hello`·`pong`: 기록장 `message` 행과 앱 `message` 프레임, `F.send` 인자에만 있고 로그·`imessage_status`·`error` 프레임·세 파일에 0건. `imessage.json` 권한 0600 |
| AT-HI-08 | 02.AC-01 | `imessage_save{id:"s1", enabled:true, room:"alpha", reports:["G"]}` → 문 어댑터 끊고 다시 연결 → `imessage{id:"q2"}` | 저장 직후 두 앱 모두 같은 `imessage_status`(요청한 앱만 `ref:"s1"`), 재연결 뒤 조회 값 동일, `settings.json` 권한 0600 |
| AT-HI-09 | 02.AC-02·03 | (a) `room:"nobody"` (b) `reports:["G","G"]` (c) `reports:["nobody"]` (d) 짝 없이 `enabled:true` | (a)~(c) `error(invalid_imessage)`, (d) `error(imessage_unpaired)`. 넷 다 `settings.json` 바이트 불변, 방송 0 |
| AT-HI-10 | 02.AC-04 | 기능 `imessage` 없는 앱3 연결 뒤 저장·짝짓기 | 앱3이 받은 `imessage_status`·`imessage_code` 0건 |
| AT-HI-11 | 02.AC-05 | `room:"G"`, `reports:["G","alpha"]` 저장 뒤 (a) `room_delete` G (b) 새 홈에서 같은 저장 뒤 `room_archive` G. 기능 `imessage` 앱 2개가 연결된 상태 | 두 경우 모두 조회가 `room:null`, `reports:["alpha"]`. (3판) 삭제·보관 직후 두 앱 모두 `ref` 없는 `imessage_status{room:null, reports:["alpha"]}`를 1개씩 받음 |
| AT-HI-12 | 03.AC-01 | 활성. `chat-A`에서 `hello`(id `im-in-1`) | 기록장에 사장 글 1행(`employee:"alpha"`, `room` 없음, 새 `thread`, `text:"hello"`, `client_msg_id:"imessage:im-in-1"`), 앱이 그 `message` 수신, 대역 처리기가 받은 이벤트 1개(`source.platform` hejo, `chat_id:"alpha"`, `profile:"alpha"`, `user_id:"owner"`, `thread_id` = 그 스레드), `F` 원래 처리기 0회 |
| AT-HI-13 | 03.AC-02 | 연결된 방 `G`. (a) `hi` (b) `@Beta hi` | (a) 받는 직원 `alpha`만 (b) `beta`만. 행에 `room:"G"` |
| AT-HI-14 | 03.AC-03 | AT-HI-12 뒤 `alpha`가 답(정착 뒤 `im-out-1`로 발신됨). 연결된 방을 `beta`로 바꾼 뒤 (a) `im-out-1`에 답장 (b) `im-in-1`에 답장 (c) 연결된 방을 `null`로 저장하고 `im-out-1`에 답장 | 세 글 모두 `alpha` 방의 AT-HI-12 스레드에 사장 글로 추가, `beta` 방 행 0 |
| AT-HI-15 | 03.AC-04·05 | (a) 모르는 id에 답장 (b) AT-HI-14 스레드를 `thread_delete`한 뒤 `im-out-1`에 답장 (c) 연결된 방 `null`에서 답장 아닌 글 | (a)(b) 연결된 방의 새 스레드 1행씩 (c) 기록장 불변, `F.send` 1회(본문에 `/방` 포함), 원래 처리기 0회 |
| AT-HI-16 | 03.AC-06 | (a) 짝 없음 (b) 짝 있고 `enabled:false` (c) 활성에서 `chat-B` 글 (d) 활성에서 `chat-G` 단체 대화방 글 (e) 활성에서 `chat-A`인데 발신자 `user-B` | 다섯 경우 모두 원래 처리기 1회(같은 객체, `source` 필드 불변), 기록장 불변, `F.send` 0회 |
| AT-HI-17 | 03.AC-07 | 같은 id `im-in-1` 글을 두 번 | 사장 글 1행, 대역 처리기 이벤트 1개 |
| AT-HI-18 | 03.AC-08 | (a) `media_urls` 있는 글 `look` (b) `media_urls`만 있고 본문 빈 글 (c) 탭백 이벤트(`raw_message.content.type == "reaction"`) | (a) `look` 1행 + 안내 1회 (b) 행 0 + 안내 1회 (c) 행 0, `F.send` 0회, 원래 처리기 0회 |
| AT-HI-19 | 03.AC-09 | (a) 기록장 쓰기 실패 주입 (b) 한도(`text_bytes`)를 넘는 본문 (c) (3판) `receive()`가 `RuntimeError`를 내도록 주입 | 세 경우 모두 행 0, 대역 처리기 이벤트 0, 안내 1회, `F`의 원래 처리기 0회, 예외가 `F.handle_message` 밖으로 나오지 않음, 다음 글 정상 처리. (c)는 로그 1줄(본문·식별자 없음) |
| AT-HI-20 | 04.AC-01·02 | 활성(연결된 방 `alpha`). `/방` → `/방 N`(N = 목록에서 `Beta` 줄의 번호) → `/방 al` → `/방 team` | `/방`: 안내 1회. 줄마다 `번호. 이름`이고 번호는 1부터 이어지며, 직원 줄 순서 = `employees()` 순서, 그 뒤 단체방 제목순(`Team`이 모든 직원 줄 뒤). 현재 방 `Alpha`가 표시됨. `/방 N`: 설정 `room:"beta"`, 앱에 `imessage_status{room:"beta"}`, 안내 1회. `/방 al`: `alpha`. `/방 team`: `G`. 네 번 모두 기록장 불변·원래 처리기 0회 |
| AT-HI-21 | 04.AC-03·04 | (a) `/방 9` (b) `/방 nobody` (c) 단체방 제목을 `Alpha`로 하나 더 만든 뒤 `/방 alpha` (d) `enabled:false`에서 `/방` | (a)~(c) 설정 불변, 목록 안내 1회씩 (d) 원래 처리기 1회, `F.send` 0회 |
| AT-HI-22 | 05.AC-01·05 | AT-HI-12 뒤 대역이 `send_typing` → `send(chat_id="alpha", "pong", thread)` → `stop_typing`. 정착 뒤 확인 | `F.send` 1회: 대상 `chat-A`, 본문 `[Alpha] pong`, `reply_to == "im-in-1"`. `sent.jsonl`에 `im-out-1` ↔ 그 글 id 1줄 |
| AT-HI-23 | 05.AC-02 | `reports:["G"]`. (a) 대역이 스레드 없이 `send(chat_id="room:G", "report", metadata{hermes_profile:"beta"})` (b) 앱이 `G`에 새 스레드로 글 → `alpha`가 `done` 답 | (a) 본문 `[Team · Beta] report`, `reply_to` 없음 (b) 본문 `[Team · Alpha] done`, `reply_to` 없음. 사장 글 발신 0 |
| AT-HI-24 | 05.AC-03 | `reports:[]`. 앱이 `alpha`에 글 → `alpha` 답 | 정착 뒤 `F.send` 0회 |
| AT-HI-25 | 05.AC-04 | 폰 스레드에서 대역이 `send_typing` → `send("생각 중…")` → `send("p", metadata{expect_edits:True})` → `edit_message`×3 → `edit_message("final", finalize=True)` → 진행 글 `send("tool")` → `delete_message(tool)` → `stop_typing` | 정착 뒤 `F.send` 정확히 1회, 본문 `[Alpha] final`. `stop_typing` 전에는 `F.send` 0회 |
| AT-HI-42 | 05.AC-12 | 폰 스레드에서 (a) 실패한 차례: `send_typing` → 진행 글 `send("tool")` → `send("failed")` → `stop_typing`(삭제 없음) (b) 삭제 실패: `send_typing` → `send("tool")` → `send("final")` → `stop_typing` → 기록장 쓰기 실패를 주입한 채 `delete_message(tool)`(거짓 반환) (c) 늦은 삭제: (b)와 같되 실패 주입 없이 정착 뒤에 `delete_message(tool)` | (a) 정착 뒤 `F.send` 2회, 순서대로 `[Alpha] tool`, `[Alpha] failed` (b) `F.send` 2회 `[Alpha] tool`, `[Alpha] final` (c) 정착 시점에 `F.send` 2회, 늦은 삭제 뒤 추가 `F.send` 0회·오류 없음. 세 경우 모두 기록장·앱 프레임은 기능이 없을 때와 같음 |
| AT-HI-26 | 05.AC-06·07 | 폰 스레드에서 원문 `"가"×125 + "a"×125`(250자, 줄바꿈 없음, UTF-8로 500바이트)로 답 → 문 재연결 → `im-out-3`에 답장. 따로, 원문 `"가"×60 + "\n" + "나"×60`(121자)으로 답 | 첫 글: 이름표 포함 258자이므로 `F.send` 정확히 3회, 본문 길이(`len`) 100·100·58, 이어 붙이면 `[Alpha] ` + 원문과 같음, 셋 다 `reply_to == "im-in-1"`, `sent.jsonl` 3줄이 같은 hejo 글 id. 재연결 뒤 답장이 같은 스레드에 추가. 둘째 글: 이름표 포함 129자, `F.send` 2회, 첫 통은 줄바꿈으로 끝나는 69자·둘째 통 60자, 이어 붙이면 이름표 + 원문 |
| AT-HI-27 | 05.AC-08 | 폰 스레드에서 (a) `metadata.hejo_buttons` 2개(`A`, `B`) 글 `pick` (b) 기본 승인 버튼 글 `ok?` (c) 첨부 `r.txt` 1개에 캡션 없는 글 | (a) `[Alpha] pick\n선택: A / B` (b) `[Alpha] ok?\n(이 선택은 hejo 앱에서 눌러 주세요)` (c) `[Alpha] 📎 r.txt (hejo 앱에서 열기)` |
| AT-HI-28 | 05.AC-09 | `F.send` 실패 주입 뒤 폰 스레드 답, 이어서 실패 해제 뒤 두 번째 답 | 첫 글: 시도 1회·재시도 0·`sent.jsonl` 0줄·로그 1줄(본문·식별자 없음). 두 번째 글은 정상 발신. 두 글 모두 앱 프레임·기록장 행은 정상 |
| AT-HI-29 | 05.AC-10 | (a) 폰 스레드 답을 기록한 직후(정착 전) 문 재연결 (b) `enabled:false` 저장 뒤 폰 스레드 답 (c) 연결 해제 뒤 답 | 세 경우 모두 `F.send` 0회 |
| AT-HI-30 | 05.AC-11, NFR-03 | 같은 앱 글·직원 답 순서를 (a) 공장 미적용 (b) 활성 + 폰 보고 방 두 홈에서 실행 | 기록장 행(seq·msg_id·ts 제외 필드)과 앱이 받은 프레임 종류·순서·본문이 같음 |
| AT-HI-31 | 06.AC-01 | `claims_external`을 (a) 활성 + `chat-A`/`user-A` 1:1 (b) `chat-B` (c) `enabled:false` (d) 대기 코드와 같은 글 (e) 대기 코드와 다른 글 (f) 단체 대화방 (g) (3판) 대기 코드와 같은 글인데 `F._is_sender_authorized`가 `False` (h) (3판) 활성 `chat-A`에서 이미 쓴 코드와 같은 글 (i) (3판) 활성 `chat-A`에서 만료된 코드와 같은 글로 부름. 전후 `imessage.json`·`settings.json`·기록장 비교 | (a)(d) `True`, 나머지 `False`. 파일 바이트 불변, `F.send` 0회 |
| AT-HI-43 | 01.AC-08 | 활성(연결된 방 `alpha`). 앱이 새 코드 C2를 받아 `chat-A`에서 보내 다시 짝지음. 그 뒤 `chat-A`/`user-A`에서 (a) C2를 새 글 id로 다시 보냄 (b) 새 코드 C3를 받고 시계를 +601초 한 뒤 C3를 보냄. 이어서 (c) 보통 글 `hi` | (a)(b) 각각 `F`의 원래 처리기 1회(같은 이벤트 객체), 기록장 행 증가 0, 대역 처리기 이벤트 0, `F.send` 0회, 앱이 받은 `message` 0개, 짝 정보 불변. (c) `alpha` 방에 사장 글 1행(활성 유지 확인). AT-HI-32의 두 감싸기 순서 모두에서 (a)의 가짜 안내원 분류 1회 |
| AT-HI-44 | NFR-05 | (a) `sent.jsonl`에 유효 줄 2개 사이에 깨진 줄 1개를 넣고 문 `connect()` (b) `settings.json`을 깨진 JSON으로 바꾸고 `connect()` 뒤 활성이던 `chat-A` 글과 앱 글 (c) `imessage.json`을 깨진 JSON으로 바꾸고 같은 절차 | 세 경우 모두 `connect()` 참, 앱 글 → 직원 답 왕복 정상. (a) 유효 줄 2개의 아이메시지 id에 대한 답장이 원래 스레드로 감, 깨진 줄은 파일에 그대로. (b)(c) `chat-A` 글은 원래 처리기 1회·기록장 불변, `F.send` 0회 |
| AT-HI-32 | 06.AC-04 (hejo 쪽) | `F`를 (a) hejo 공장 → 가짜 안내원 감싸기 (b) 그 반대 순서로 감쌈. 가짜 안내원은 `claims_external`이 참이면 원래 처리기를 부르고 아니면 "분류" 횟수를 올린 뒤 원래 처리기를 부름. 활성에서 `chat-A` 글과 `chat-B` 글 | 두 순서 모두: `chat-A` 글은 hejo 사장 글 1행·분류 0회, `chat-B` 글은 분류 1회·맨 안쪽 원래 처리기 1회 |
| AT-HI-33 | 06.AC-02·03 (team-kit 쪽) | team-kit 시험에서 가짜 러너에 가짜 hejo 어댑터를 (a) 참 (b) 거짓 (c) 메서드 없음 (d) 예외 (e) hejo 어댑터 없음으로 두고 photon 이벤트를 넣음. `route_event`·소유권 저장소 호출 기록 | (a) `route_event` 0회, 원래 처리기 1회, `source.profile` 불변 (b)~(e) `route_event` 1회로 기존 결과와 같음. Slack 이벤트는 hejo 답과 무관하게 기존 결과 |
| AT-HI-34 | 06.AC-03 | (3판) team-kit 기존 시험 전체를 양보 코드 적용 전과 후에 같은 환경으로 한 번씩 실행 | 기존 시험 파일 변경 0건. 적용 후의 실패 시험 집합이 적용 전과 같고(새 실패 0건), 통과 수가 줄지 않음. 적용 전부터 실패하는 시험은 이름과 원인을 보고한다(2026-11-20 계획 담당 확인: 운영 프로필 자료 길이를 재는 `test_all_profile_prompt_budget.py`의 1건이 무수정 원본에서도 실패) |
| AT-HI-35 | 07.AC-01·03 | 앱 시험: 상태 모델에 `imessage_status`(미연결 → 코드 → 연결됨 → 방 변경)를 차례로 넣고 설정 구역 뷰의 표시 값 확인 | 상태 글·코드·남은 시간·스위치·방 선택이 프레임 값과 같고, `paired:true` 수신 시 코드 영역이 사라짐 |
| AT-HI-36 | 07.AC-02 | 앱 시험: 1:1 방과 단체방의 방 메뉴 항목과 체크, 항목 선택 시 나가는 프레임 | 두 항목 존재, 체크가 상태와 같음, 선택 시 `imessage_save`의 `room`/`reports`가 기대 값(켜면 추가, 다시 고르면 제거·`room:null`) |
| AT-HI-37 | 07.AC-04·05 | 앱 시험: (a) 조회에 `error(unexpected_frame)` (b) `platform_ready:false` (c) `hello` 프레임 | (a) "서버가 지원하지 않음", 메뉴 두 항목 없음 (b) 안내 표시·코드 받기 꺼짐 (c) `features`에 `imessage` 포함 |
| AT-HI-38 | NFR-01·02·03 | `python3 scripts/scan_private.py`, `bash scripts/test.sh`, 작업 전후 Hermes 본체 `git status --porcelain`·`git rev-parse HEAD`(photon 폴더 포함) 비교 | 검사 통과, 전체 시험 통과, 본체의 작업 전후 값 동일 |
| AT-HI-39 | 가정(정착 시간) | 수준 3: 임시 `HERMES_HOME` 실제 게이트웨이(`gate/tests/gateway_delivery` 방식)에서 진행 글 정리를 켜고 한 차례 실행, `stop_typing`부터 마지막 진행 글 삭제 기록까지 시간을 5회 측정 | 측정값 5개를 보고. 최댓값이 2초 미만이면 가정 유지, 아니면 멈추고 보고(값 변경은 계획 담당 승인) |

## 폰의 "작성 중" 표시 (4판, REQ-HI-09, TASK-09)

가짜 아이메시지 어댑터가 `send_typing`·`stop_typing`·`send` 호출을 순서대로 기록한다. 기대값 출처: spec REQ-HI-09.

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HI-45 | 09.AC-01 | 짝·켜짐 상태에서 폰 글로 스레드를 만든 뒤 그 스레드로 hejo 문 `send_typing`을 3번 부름 | 가짜 어댑터에 짝 대화창으로 `send_typing`이 3번 기록됨 |
| AT-HI-46 | 09.AC-02 | 앱에서 시작한 스레드로 `send_typing`. 같은 일을 그 방의 "폰으로 보고 받기"를 켠 뒤 한 번 더 | 두 경우 모두 가짜 어댑터의 `send_typing`·`stop_typing` 0건 |
| AT-HI-47 | 09.AC-03 | 폰 스레드를 만든 뒤 (가) 연결 끄기 (나) 짝 해제 (다) 아이메시지 문 미연결 각각에서 `send_typing` | 세 경우 모두 `send_typing` 0건 |
| AT-HI-48 | 09.AC-04 | 폰 스레드에서 `send_typing` → 직원 글 기록 → `stop_typing` → 정착 시간 경과 | 호출 순서가 `send_typing`, 답 `send`, `stop_typing`이고 `stop_typing`은 정확히 1번. 직원 글 없이 `stop_typing`만 한 경우에도 `stop_typing` 1번 |
| AT-HI-49 | 09.AC-04 | 폰 스레드 2개가 동시에 진행 중일 때 하나만 끝냄 → 나머지도 끝냄 | 첫 종료 뒤 `stop_typing` 0건, 둘째 종료 뒤 1건 |
| AT-HI-50 | 09.AC-05 | 가짜 어댑터의 `send_typing`·`stop_typing`이 (가) 예외를 던짐 (나) 끝나지 않고 멈춤 | 두 경우 모두 hejo 문 `send_typing`·`stop_typing`이 1초 안에 돌아오고, 앱 `typing` 프레임과 폰으로 가는 답 `send`가 평소와 같음. 로그에 대화창 id 없음 |
| AT-HI-51 | 09.AC-06 | AT-HI-48 흐름 전후 비교 | 가짜 어댑터 `send` 기록이 답 글뿐(표시용 글 0건), 기록장 레코드 종류·설정 파일·금고 파일·규격 파일 변화 없음 |

## 서버 적용 확인 (수준 3, TASK-07)

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HI-40 | 08.AC-01 | 적용 전 기록 → 적용 → 재시작 → 게이트웨이 로그 확인 | 적용 전 기록 3종이 인계 보고에 있음, 재시작 뒤 로그에 hejo·photon·Slack 연결, 재시작 이후 새 오류·역추적 0건, hejo 앱 재연결 뒤 `imessage_status{platform_ready:true, paired:false}` |
| AT-HI-41 | 08.AC-02 | 롤백 절차를 인계 보고에 옮겨 적고 명령마다 대상 경로·커밋을 채움 | 빈 칸 0. 실패했다면 롤백 실행 기록과 롤백 뒤 로그 확인 |

## 수동 확인 (수준 4, 사장이 폰으로)

| ID | 절차 | 기대 |
|---|---|---|
| M1 | 앱 설정 → 아이메시지 → 코드 받기 → 서버 아이메시지 번호로 코드 보내기 | 폰에 "연결됐어요", 앱이 "연결됨" |
| M2 | 켜고 연결된 방을 직원 1:1 방으로 → 폰에서 글 보내기 | 그 방에 새 스레드, 그 직원 답이 `[이름]`과 함께 폰에 답장으로 옴. 쓰는 중인 조각은 안 옴. 진행 글은 차례가 성공하고 정리가 끝난 경우 안 옴(REQ-HI-05.AC-12의 경우는 불합격 아님) |
| M3 | 폰에서 그 답에 밀어서 답장 | 같은 스레드에 이어짐 |
| M4 | 폰에서 `/방` → `/방 번호`로 다른 방 → 새 글 | 목록이 오고, 바꾼 방의 직원이 답함. 앱 설정·메뉴 체크도 바뀜 |
| M5 | 방을 바꾼 뒤 M2의 옛 답에 답장 | 옛 방의 옛 스레드에 이어짐 |
| M6 | 한 방에 "폰으로 보고 받기"를 켜고 그 방 직원의 예약 보고(또는 앱에서 건 대화의 답) 기다리기 | 폰에 `[방 · 직원]` 글이 옴. 답장하면 그 스레드에 이어짐 |
| M7 | 앱에서 끄기 → 폰에서 글 | 이전처럼 안내원이 고른 직원이 답함 |
| M8 | 다시 켠 뒤 Slack·hejo 앱 대화가 평소와 같은지 | 같음 |
| M9 | (4판) 폰에서 글 보내고 대화창 지켜보기 | 직원이 처리하는 동안 아이메시지 기본 "작성 중" 표시가 보이고, 답이 온 뒤에는 남아 있지 않음. 앱의 표시는 평소와 같음 |
