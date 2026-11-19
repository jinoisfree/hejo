# HEJO-IMESSAGE 수락 시험 명세

- 소유: 기획설계. 1판(2026-11-19). 기대값 근거: [spec.md](../../docs/changes/HEJO-IMESSAGE-20261119/spec.md) 요구와 [design.md](../../docs/changes/HEJO-IMESSAGE-20261119/design.md) 3~7절.
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
| AT-HI-07 | 01.AC-07, NFR-04 | AT-HI-01·10·20 뒤 로그 캡처, 앱이 받은 모든 프레임, 기록장 파일, `imessage.json` 검색 | 코드 평문·`chat-A`·`user-A`가 로그·프레임·기록장에 0건(기록장의 `imessage:im-in-*`는 허용), `imessage.json` 권한 0600이고 코드 평문 0건, 로그에 시험 본문 0건 |
| AT-HI-08 | 02.AC-01 | `imessage_save{id:"s1", enabled:true, room:"alpha", reports:["G"]}` → 문 어댑터 끊고 다시 연결 → `imessage{id:"q2"}` | 저장 직후 두 앱 모두 같은 `imessage_status`(요청한 앱만 `ref:"s1"`), 재연결 뒤 조회 값 동일, `settings.json` 권한 0600 |
| AT-HI-09 | 02.AC-02·03 | (a) `room:"nobody"` (b) `reports:["G","G"]` (c) `reports:["nobody"]` (d) 짝 없이 `enabled:true` | (a)~(c) `error(invalid_imessage)`, (d) `error(imessage_unpaired)`. 넷 다 `settings.json` 바이트 불변, 방송 0 |
| AT-HI-10 | 02.AC-04 | 기능 `imessage` 없는 앱3 연결 뒤 저장·짝짓기 | 앱3이 받은 `imessage_status`·`imessage_code` 0건 |
| AT-HI-11 | 02.AC-05 | `room:"G"`, `reports:["G","alpha"]` 저장 뒤 (a) `room_delete` G (b) 새 홈에서 같은 저장 뒤 `room_archive` G | 두 경우 모두 조회가 `room:null`, `reports:["alpha"]` |
| AT-HI-12 | 03.AC-01 | 활성. `chat-A`에서 `hello`(id `im-in-1`) | 기록장에 사장 글 1행(`employee:"alpha"`, `room` 없음, 새 `thread`, `text:"hello"`, `client_msg_id:"imessage:im-in-1"`), 앱이 그 `message` 수신, 대역 처리기가 받은 이벤트 1개(`source.platform` hejo, `chat_id:"alpha"`, `profile:"alpha"`, `user_id:"owner"`, `thread_id` = 그 스레드), `F` 원래 처리기 0회 |
| AT-HI-13 | 03.AC-02 | 연결된 방 `G`. (a) `hi` (b) `@Beta hi` | (a) 받는 직원 `alpha`만 (b) `beta`만. 행에 `room:"G"` |
| AT-HI-14 | 03.AC-03 | AT-HI-12 뒤 `alpha`가 답(정착 뒤 `im-out-1`로 발신됨). 연결된 방을 `beta`로 바꾼 뒤 (a) `im-out-1`에 답장 (b) `im-in-1`에 답장 (c) 연결된 방을 `null`로 저장하고 `im-out-1`에 답장 | 세 글 모두 `alpha` 방의 AT-HI-12 스레드에 사장 글로 추가, `beta` 방 행 0 |
| AT-HI-15 | 03.AC-04·05 | (a) 모르는 id에 답장 (b) AT-HI-14 스레드를 `thread_delete`한 뒤 `im-out-1`에 답장 (c) 연결된 방 `null`에서 답장 아닌 글 | (a)(b) 연결된 방의 새 스레드 1행씩 (c) 기록장 불변, `F.send` 1회(본문에 `/방` 포함), 원래 처리기 0회 |
| AT-HI-16 | 03.AC-06 | (a) 짝 없음 (b) 짝 있고 `enabled:false` (c) 활성에서 `chat-B` 글 (d) 활성에서 `chat-G` 단체 대화방 글 (e) 활성에서 `chat-A`인데 발신자 `user-B` | 다섯 경우 모두 원래 처리기 1회(같은 객체, `source` 필드 불변), 기록장 불변, `F.send` 0회 |
| AT-HI-17 | 03.AC-07 | 같은 id `im-in-1` 글을 두 번 | 사장 글 1행, 대역 처리기 이벤트 1개 |
| AT-HI-18 | 03.AC-08 | (a) `media_urls` 있는 글 `look` (b) `media_urls`만 있고 본문 빈 글 (c) 탭백 이벤트(`raw_message.content.type == "reaction"`) | (a) `look` 1행 + 안내 1회 (b) 행 0 + 안내 1회 (c) 행 0, `F.send` 0회, 원래 처리기 0회 |
| AT-HI-19 | 03.AC-09 | (a) 기록장 쓰기 실패 주입 (b) 한도(`text_bytes`)를 넘는 본문 | 두 경우 모두 행 0, 대역 처리기 이벤트 0, 안내 1회, 예외 없이 다음 글 정상 처리 |
| AT-HI-20 | 04.AC-01·02 | 활성(연결된 방 `alpha`). `/방` → `/방 N`(N = 목록에서 `Beta` 줄의 번호) → `/방 al` → `/방 team` | `/방`: 안내 1회. 줄마다 `번호. 이름`이고 번호는 1부터 이어지며, 직원 줄 순서 = `employees()` 순서, 그 뒤 단체방 제목순(`Team`이 모든 직원 줄 뒤). 현재 방 `Alpha`가 표시됨. `/방 N`: 설정 `room:"beta"`, 앱에 `imessage_status{room:"beta"}`, 안내 1회. `/방 al`: `alpha`. `/방 team`: `G`. 네 번 모두 기록장 불변·원래 처리기 0회 |
| AT-HI-21 | 04.AC-03·04 | (a) `/방 9` (b) `/방 nobody` (c) 단체방 제목을 `Alpha`로 하나 더 만든 뒤 `/방 alpha` (d) `enabled:false`에서 `/방` | (a)~(c) 설정 불변, 목록 안내 1회씩 (d) 원래 처리기 1회, `F.send` 0회 |
| AT-HI-22 | 05.AC-01·05 | AT-HI-12 뒤 대역이 `send_typing` → `send(chat_id="alpha", "pong", thread)` → `stop_typing`. 정착 뒤 확인 | `F.send` 1회: 대상 `chat-A`, 본문 `[Alpha] pong`, `reply_to == "im-in-1"`. `sent.jsonl`에 `im-out-1` ↔ 그 글 id 1줄 |
| AT-HI-23 | 05.AC-02 | `reports:["G"]`. (a) 대역이 스레드 없이 `send(chat_id="room:G", "report", metadata{hermes_profile:"beta"})` (b) 앱이 `G`에 새 스레드로 글 → `alpha`가 `done` 답 | (a) 본문 `[Team · Beta] report`, `reply_to` 없음 (b) 본문 `[Team · Alpha] done`, `reply_to` 없음. 사장 글 발신 0 |
| AT-HI-24 | 05.AC-03 | `reports:[]`. 앱이 `alpha`에 글 → `alpha` 답 | 정착 뒤 `F.send` 0회 |
| AT-HI-25 | 05.AC-04 | 폰 스레드에서 대역이 `send_typing` → `send("생각 중…")` → `send("p", metadata{expect_edits:True})` → `edit_message`×3 → `edit_message("final", finalize=True)` → 진행 글 `send("tool")` → `delete_message(tool)` → `stop_typing` | 정착 뒤 `F.send` 정확히 1회, 본문 `[Alpha] final`. `stop_typing` 전에는 `F.send` 0회 |
| AT-HI-26 | 05.AC-06·07 | 폰 스레드에서 한글 포함 250자 글 답 → 문 재연결 → `im-out-3`에 답장 | `F.send` 3회(각 본문 ≤ 100자, 이어 붙이면 `[Alpha] ` + 원문과 같음, 모두 `reply_to == "im-in-1"`), `sent.jsonl` 3줄이 같은 hejo 글 id. 재연결 뒤 답장이 같은 스레드에 추가 |
| AT-HI-27 | 05.AC-08 | 폰 스레드에서 (a) `metadata.hejo_buttons` 2개(`A`, `B`) 글 `pick` (b) 기본 승인 버튼 글 `ok?` (c) 첨부 `r.txt` 1개에 캡션 없는 글 | (a) `[Alpha] pick\n선택: A / B` (b) `[Alpha] ok?\n(이 선택은 hejo 앱에서 눌러 주세요)` (c) `[Alpha] 📎 r.txt (hejo 앱에서 열기)` |
| AT-HI-28 | 05.AC-09 | `F.send` 실패 주입 뒤 폰 스레드 답, 이어서 실패 해제 뒤 두 번째 답 | 첫 글: 시도 1회·재시도 0·`sent.jsonl` 0줄·로그 1줄(본문·식별자 없음). 두 번째 글은 정상 발신. 두 글 모두 앱 프레임·기록장 행은 정상 |
| AT-HI-29 | 05.AC-10 | (a) 폰 스레드 답을 기록한 직후(정착 전) 문 재연결 (b) `enabled:false` 저장 뒤 폰 스레드 답 (c) 연결 해제 뒤 답 | 세 경우 모두 `F.send` 0회 |
| AT-HI-30 | 05.AC-11, NFR-03 | 같은 앱 글·직원 답 순서를 (a) 공장 미적용 (b) 활성 + 폰 보고 방 두 홈에서 실행 | 기록장 행(seq·msg_id·ts 제외 필드)과 앱이 받은 프레임 종류·순서·본문이 같음 |
| AT-HI-31 | 06.AC-01 | `claims_external`을 (a) 활성 + `chat-A`/`user-A` 1:1 (b) `chat-B` (c) `enabled:false` (d) 대기 코드와 같은 글 (e) 대기 코드와 다른 글 (f) 단체 대화방으로 부름. 전후 `imessage.json`·`settings.json`·기록장 비교 | (a)(d) `True`, 나머지 `False`. 파일 바이트 불변, `F.send` 0회 |
| AT-HI-32 | 06.AC-04 (hejo 쪽) | `F`를 (a) hejo 공장 → 가짜 안내원 감싸기 (b) 그 반대 순서로 감쌈. 가짜 안내원은 `claims_external`이 참이면 원래 처리기를 부르고 아니면 "분류" 횟수를 올린 뒤 원래 처리기를 부름. 활성에서 `chat-A` 글과 `chat-B` 글 | 두 순서 모두: `chat-A` 글은 hejo 사장 글 1행·분류 0회, `chat-B` 글은 분류 1회·맨 안쪽 원래 처리기 1회 |
| AT-HI-33 | 06.AC-02·03 (team-kit 쪽) | team-kit 시험에서 가짜 러너에 가짜 hejo 어댑터를 (a) 참 (b) 거짓 (c) 메서드 없음 (d) 예외 (e) hejo 어댑터 없음으로 두고 photon 이벤트를 넣음. `route_event`·소유권 저장소 호출 기록 | (a) `route_event` 0회, 원래 처리기 1회, `source.profile` 불변 (b)~(e) `route_event` 1회로 기존 결과와 같음. Slack 이벤트는 hejo 답과 무관하게 기존 결과 |
| AT-HI-34 | 06.AC-03 | team-kit 기존 시험 전체 | 고치지 않고 통과 |
| AT-HI-35 | 07.AC-01·03 | 앱 시험: 상태 모델에 `imessage_status`(미연결 → 코드 → 연결됨 → 방 변경)를 차례로 넣고 설정 구역 뷰의 표시 값 확인 | 상태 글·코드·남은 시간·스위치·방 선택이 프레임 값과 같고, `paired:true` 수신 시 코드 영역이 사라짐 |
| AT-HI-36 | 07.AC-02 | 앱 시험: 1:1 방과 단체방의 방 메뉴 항목과 체크, 항목 선택 시 나가는 프레임 | 두 항목 존재, 체크가 상태와 같음, 선택 시 `imessage_save`의 `room`/`reports`가 기대 값(켜면 추가, 다시 고르면 제거·`room:null`) |
| AT-HI-37 | 07.AC-04·05 | 앱 시험: (a) 조회에 `error(unexpected_frame)` (b) `platform_ready:false` (c) `hello` 프레임 | (a) "서버가 지원하지 않음", 메뉴 두 항목 없음 (b) 안내 표시·코드 받기 꺼짐 (c) `features`에 `imessage` 포함 |
| AT-HI-38 | NFR-01·02·03 | `python3 scripts/scan_private.py`, `bash scripts/test.sh`, 작업 전후 Hermes 본체 `git status --porcelain`·`git rev-parse HEAD`(photon 폴더 포함) 비교 | 검사 통과, 전체 시험 통과, 본체의 작업 전후 값 동일 |
| AT-HI-39 | 가정(정착 시간) | 수준 3: 임시 `HERMES_HOME` 실제 게이트웨이(`gate/tests/gateway_delivery` 방식)에서 진행 글 정리를 켜고 한 차례 실행, `stop_typing`부터 마지막 진행 글 삭제 기록까지 시간을 5회 측정 | 측정값 5개를 보고. 최댓값이 2초 미만이면 가정 유지, 아니면 멈추고 보고(값 변경은 계획 담당 승인) |

## 서버 적용 확인 (수준 3, TASK-07)

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HI-40 | 08.AC-01 | 적용 전 기록 → 적용 → 재시작 → 게이트웨이 로그 확인 | 적용 전 기록 3종이 인계 보고에 있음, 재시작 뒤 로그에 hejo·photon·Slack 연결, 재시작 이후 새 오류·역추적 0건, hejo 앱 재연결 뒤 `imessage_status{platform_ready:true, paired:false}` |
| AT-HI-41 | 08.AC-02 | 롤백 절차를 인계 보고에 옮겨 적고 명령마다 대상 경로·커밋을 채움 | 빈 칸 0. 실패했다면 롤백 실행 기록과 롤백 뒤 로그 확인 |

## 수동 확인 (수준 4, 사장이 폰으로)

| ID | 절차 | 기대 |
|---|---|---|
| M1 | 앱 설정 → 아이메시지 → 코드 받기 → 서버 아이메시지 번호로 코드 보내기 | 폰에 "연결됐어요", 앱이 "연결됨" |
| M2 | 켜고 연결된 방을 직원 1:1 방으로 → 폰에서 글 보내기 | 그 방에 새 스레드, 그 직원 답이 `[이름]`과 함께 폰에 답장으로 옴. 쓰는 중인 조각·진행 글은 안 옴 |
| M3 | 폰에서 그 답에 밀어서 답장 | 같은 스레드에 이어짐 |
| M4 | 폰에서 `/방` → `/방 번호`로 다른 방 → 새 글 | 목록이 오고, 바꾼 방의 직원이 답함. 앱 설정·메뉴 체크도 바뀜 |
| M5 | 방을 바꾼 뒤 M2의 옛 답에 답장 | 옛 방의 옛 스레드에 이어짐 |
| M6 | 한 방에 "폰으로 보고 받기"를 켜고 그 방 직원의 예약 보고(또는 앱에서 건 대화의 답) 기다리기 | 폰에 `[방 · 직원]` 글이 옴. 답장하면 그 스레드에 이어짐 |
| M7 | 앱에서 끄기 → 폰에서 글 | 이전처럼 안내원이 고른 직원이 답함 |
| M8 | 다시 켠 뒤 Slack·hejo 앱 대화가 평소와 같은지 | 같음 |
