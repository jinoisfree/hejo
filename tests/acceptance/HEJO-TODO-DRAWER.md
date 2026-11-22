# HEJO-TODO-DRAWER 수락 시험 명세

3판 · 2026-11-20(3판: 검증 1차 V-2로 AT-TD-42 추가 / 2판: 계획 검증 1회차 PR-01~04 반영, [plan-review.md](../../docs/changes/HEJO-TODO-DRAWER-20261120/plan-review.md)) · 명세 [spec.md](../../docs/changes/HEJO-TODO-DRAWER-20261120/spec.md) · 설계 [design.md](../../docs/changes/HEJO-TODO-DRAWER-20261120/design.md)

상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1회차 BLOCKED → 2판 반영, 재검증 대기.

기대값 출처는 spec 요구와 design 2~5절이다. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통 조건: 임시 `HERMES_HOME`, 가짜 직원 `alpha`·`beta`(+ `default`), 가짜 장부, 가짜 `hermes-deadlines` 명령, 고정 시계 2026-11-20 10:00(Mac 시간대 = Asia/Seoul로 고정). 실제 직원 id·제목·주소는 쓰지 않는다.

## team-kit (`HD` worktree `team-kit/tests/test_deadline_list.py`(새))

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-TD-01 | TD-05.AC-01 | 가짜 루트 홈과 명부(alpha, beta). 장부는 이렇게 둔다: `default` 열림 1개, alpha 열림 2개 + 닫힘 1개, beta 파일 없음 | `list --json` 종료 0. `profiles.default` 1개, `profiles.alpha` 2개(닫힘 제외), `profiles.beta` 빈 목록, `failed` 빈 목록. 각 항목 키는 `{id,title,due,source}`와 있으면 `deadline_at`뿐이다(HEJO-DEADLINE-CLOSE에서 `notice?` 추가, AT-DC-08)(`notifications`·`history`·`replies`·`source_check` 없음) |
| AT-TD-02 | TD-05.AC-04 | alpha 장부를 깨진 JSON으로, beta 장부를 심볼릭 링크로 둔다 | 종료 0. `failed`에 `{alpha, deadline_state_corrupt}`, `{beta, deadline_symlink_refused}`가 있고 `default` 항목은 정상으로 나온다 |
| AT-TD-03 | TD-05.AC-05 | AT-TD-01·02 실행 전후 | 가짜 홈 전체의 파일 목록·sha256이 같다. `state/` 폴더나 `deadline-watch.lock`이 새로 생기지 않는다(beta처럼 폴더가 없던 홈 포함) |
| AT-TD-04 | design 2절 | 명부 파일을 읽을 수 없음 | `{"error":"TEAM_UNAVAILABLE"}`, 종료 1 |
| AT-TD-05 | 회귀 | 기존 `deadline_watch` 시험 | 모두 통과(쓰기·닫기·Slack 보고 동작 불변) |

## 문 (`tests/acceptance/test_deadlines.py`(새))

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-TD-10 | TD-05.AC-01 | 가짜 명령이 AT-TD-01 모양을 출력. `source`는 alpha의 하나만 `https://example.invalid/x`, 나머지는 일반 문장 | `deadlines_status`: `available:true`, items 3개. 각 항목의 키 집합이 허용 목록 `{employee,id,title,due,deadline_at?,url?}`(HEJO-DEADLINE-CLOSE 2판에서 `origin?`·`notice?` 추가, AT-DC-20)의 부분집합이다(가짜 명령이 항목에 `notifications`·`history`·`closed`·`extra`를 덧붙여 내보내도 응답에는 없다). 링크 항목에만 `url`이 있다. 어떤 항목에도 `source` 키와 일반 문장 출처의 표식 문자열이 없다. `ftp://`·`javascript:`·host 없는 `https:` 출처는 `url`이 없다. `failed: []` |
| AT-TD-11 | TD-05.AC-02 | `<HOME>/bin/hermes-deadlines` 없음 | `{available:false, items:[]}`. 명령을 실행하지 않는다 |
| AT-TD-12 | TD-05.AC-03 | 가짜 명령이 (가) 종료 1 (나) JSON 아님 (다) 600 KiB 출력 (라) 항목 `due`가 날짜가 아님 (마) 20초 대기(시험에서는 제한 시간을 짧게 주입할 수 있다) | (가)(마) `reason:"command_failed"`, (나)(다)(라) `reason:"invalid_response"`. (마)에서 자식 프로세스가 남지 않는다 |
| AT-TD-13 | TD-05.AC-04 | 출력에 `failed:[{profile:alpha,reason:deadline_state_corrupt}]` | 응답 `failed:["alpha"]`, 다른 항목은 정상 |
| AT-TD-14 | NFR-TD-02 | 1초 걸리는 가짜 명령. 연결 A에서 `deadlines` 두 번과 `roster` 한 번, 연결 B에서 `deadlines` 한 번을 이어 보낸다 | 연결 A의 `roster` 응답이 첫 `deadlines` 응답보다 먼저 온다. 명령 실행 횟수는 1이다. A의 두 응답과 B의 응답이 모두 오고 각 `ref`가 맞다 |
| AT-TD-18 | NFR-TD-02 (취소 경계) | 2초 걸리는 가짜 명령. 연결 A·B가 `deadlines`를 보낸 뒤 0.5초에 A를 끊는다. 그다음 B도 끊어 대기자가 0이 되는 경우와, 가짜 명령이 30초 멈추는 경우(제한 시간 주입 1초)를 함께 본다 | A를 끊어도 B는 정상 응답을 받는다. 실행 횟수는 1이다. 대기자가 0이 돼도 실행은 끝까지 가고, 끝난 뒤 자식 프로세스가 없다(pid 조회). 멈춤 경우에는 제한 시간 뒤 `terminate`/`kill`로 회수되고 남은 대기자는 `command_failed`를 받는다. 끝난 뒤 새 요청은 새 실행을 만든다(실행 횟수 2) |
| AT-TD-19 | NFR-TD-02 (종료) | 실행 중에 문 어댑터를 멈춘다 | 실행 Task가 취소되고 자식 프로세스가 없다. 예외가 로그 밖으로 새지 않는다 |
| AT-TD-15 | NFR-TD-01 | AT-TD-10·12 | 문 로그에 제목·`source` 문자열(가짜 표식)이 없다. `deadlines_read items=3 failed=0`과 `deadlines_failed reason=…` 형식만 있다 |
| AT-TD-16 | 규격 | AT-TD-10~13의 응답과 요청 | `schemas/hejo-wire-v1.json`으로 검증하면 통과한다. 기존 규격 시험이 모두 통과한다 |
| AT-TD-17 | 회귀 | — | `bash scripts/test.sh` gate 부분 전부 통과(AT-HC 연결 시험 포함) |

## 앱 (`app/Tests/TodoDrawerTests.swift`(새), 기존 `IslandTests`·`PetWindowTests`·`WebPaneTests`)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-TD-20 | TD-03.AC-01·02 | 가짜 모델. 답 요청 2(alpha 10분 전, beta 1시간 전), 알림 1, 마감 4개(지남 1일, 오늘, 내일, 4일 뒤), muted 방의 답 요청 1 | "급한 것" = [지남, 오늘, 내일, 답 요청 beta, 답 요청 alpha](5개). "나머지" = [4일 뒤, 알림](2개). muted 방 항목 없음. 머리 개수 7 |
| AT-TD-21 | TD-03.AC-03 | AT-TD-20에서 칩 "마감" 선택 → 닫기 → 열기 | 마감 4개만 남는다. 다시 열어도 "마감"이 선택되어 있다. 새 모델(앱 재시작 흉내)에서는 "전체"다 |
| AT-TD-22 | TD-03.AC-04 | 마감 `deadline_at` 오늘 18:00 / `due`만 11-24 / 지남 1일 | 표시는 `D-DAY` "오늘 18시까지", `D-4` "11월 24일까지", `D+1` |
| AT-TD-23 | TD-03.AC-05·06 | 빈 모델 → 답 요청 1 추가 → 그 질문에 답(`replyState` answered) | "처리할 일이 없어요" → 카드 1 → 다시 빈 상태 |
| AT-TD-39 | TD-03.AC-06, TD-04.AC-01 (알림) | 알림 카드 1개(24시간 안 직원 글)인 상태에서 칸의 그 카드를 누른다 | 그 글의 방·스레드가 선택되고 1.5초 강조된다. 칸은 열린 채다. 기존 알림 읽음 처리(`markAlertSeen`)가 일어나 `notices`에서 빠지면 칸에서도 그 카드가 사라진다 |
| AT-TD-24 | TD-05.AC-02·03 | 마감 상태: (가) available false (나) 성공 후 실패 (다) 받은 적 없이 실패 | (가) 마감 칩·카드 없음, 회색 줄 없음. (나) 마지막 목록 유지 + "마감을 읽지 못했어요. 잠시 뒤 다시 볼게요." (다) 마감 없음 + 같은 회색 줄. 옛 문의 오류 프레임은 (가)처럼 처리 |
| AT-TD-40 | TD-05.AC-04 (앱) | 성공 응답: items = alpha 마감 2개, `failed:["beta"]` | alpha 마감 카드 2개가 보이고 마감 칩 개수 2. 회색 줄 "마감을 읽지 못했어요. 잠시 뒤 다시 볼게요."이 함께 보인다. 다음 응답이 `failed: []`이면 회색 줄이 사라진다 |
| AT-TD-25 | TD-04.AC-01 | 답 요청 카드 클릭 | 지금 `.question` 이동과 같은 결과(선택 방·스레드·강조 1.5초). 칸은 열린 채이고 그 카드가 선택 상태다 |
| AT-TD-26 | TD-04.AC-02·03 | 마감 카드: `url` 있음 / 없음(alpha) | 있음은 링크 열기 경로가 그 URL로 한 번 불린다. ~~없음은 alpha 1:1 방이 선택된다. 카드 보기에 닫기·고치기 단추가 없다~~ → HEJO-DEADLINE-CLOSE에서 대체: 없음은 [AT-DC-25](HEJO-DEADLINE-CLOSE.md), 메뉴·단추는 AT-DC-26 |
| AT-TD-27 | TD-01.AC-01·03 | 알약: 사장 차례 칸이 있을 때(미리보기 아님) / 빈 알약일 때 클릭 | 둘 다 `Action.drawer`. 열림 뒤 스냅숏의 사장 칸 글자가 " · 닫기 ‹"로 끝나고 `drawerOpen` 표시가 있다. 빈 알약이 열린 경우 칸 하나 "닫기 ‹" |
| AT-TD-41 | TD-01.AC-01 (배선) | 실제 `ConversationView`·`IslandView`·`PetController`(가짜 화면)를 조립하고, 채팅을 펼친 상태에서 `IslandView.mouseDown`(또는 `activate(at:)`)으로 (가) 사장 칸 (나) 빈 알약을 누른다. 각각 한 번 더 누른다 | 첫 클릭 뒤 컨트롤러의 열림 상태가 참이고, 창 프레임이 늘림 목표로 바뀌고, 칸 보기가 보인다. 둘째 클릭 뒤 열림 상태가 거짓이고 원래 프레임·칸 숨김. 스냅숏 단언만으로 대신하지 않는다 (창 프레임 기대는 HEJO-DRAWER-INLINE AT-DI-33으로 대체: 왼쪽 끝 불변·폭 +290) |
| AT-TD-28 | TD-01.AC-02 | 직원 얼굴 클릭, 문제 칸 클릭(열림 상태) | 기존 `.worker`, `.reconnect` 동작이 일어나고 열림 상태는 그대로 |
| AT-TD-29 | TD-01.AC-02 (회귀) | 오래된 asked 1(alpha)이 있을 때 새 asked 2(beta)가 와서 사장 칸이 미리보기로 늘어난 동안 클릭 | 기존과 같이 `.question(asked 1, alpha)`(**가장 오래된** 질문)으로 이동한다. 칸 상태는 그대로다. 기존 `IslandTests` AT56(`IslandTests.swift:70-72`)이 수정 없이 통과한다 |
| AT-TD-30 | TD-01.AC-04 | Esc / "‹ 접기" / 덮기 모드의 막 클릭 / 늘림 모드의 채팅 클릭 | 앞의 셋은 닫힌다. 마지막은 닫히지 않는다 (덮기 모드의 막 클릭은 HEJO-DRAWER-INLINE에서 없어짐, AT-DI-31) |
| ~~AT-TD-31~~ (HEJO-DRAWER-INLINE로 대체, [AT-DI](HEJO-DRAWER-INLINE.md)) | TD-02.AC-01 | 가시 영역 1440×900, 채팅이 가운데, 왼쪽 여유 충분 | 열림 뒤 창 `minX`가 290 줄고 폭이 290 늘어난다. 채팅 영역의 화면 좌표(x, 폭, y, 높이)는 같다. 닫으면 원래 창 프레임으로 돌아간다 |
| AT-TD-32 | TD-02.AC-02 | 동작 줄이기 끔 / 켬 | 끔: 움직임 시간 0.25초(±1 프레임). 켬: 첫 단계에서 목표 프레임 |
| ~~AT-TD-33~~ (HEJO-DRAWER-INLINE로 대체, [AT-DI](HEJO-DRAWER-INLINE.md)) | TD-02.AC-03 | 채팅 왼쪽 끝이 가시 영역 왼쪽 + 100 | 창 프레임 불변, 덮기 모드, 칸이 채팅 왼쪽 위에 겹치고 막이 보인다 |
| ~~AT-TD-34~~ (HEJO-DRAWER-INLINE로 대체, [AT-DI](HEJO-DRAWER-INLINE.md)) | TD-02.AC-04 | 웹 칸 열림 + 할 일 칸 열기: (가) 화면 넓음 (나) 셋이 안 들어감. 그 뒤 웹 칸 닫기 | (가) 창이 양쪽으로 늘고 웹 칸 폭은 열기 전과 같다. (나) 할 일 칸이 덮기 모드이고 웹 칸 폭이 줄지 않는다. 웹 칸을 닫아도 할 일 칸은 열려 있다 |
| ~~AT-TD-35~~ (HEJO-DRAWER-INLINE로 대체, [AT-DI](HEJO-DRAWER-INLINE.md)) | TD-02.AC-05 | 열림 상태에서 채팅 끌기로 왼쪽 끝 근처에 놓기 → 채팅 접기 → 다시 펼치기 | 놓인 뒤 덮기 모드. 접으면 칸이 보이지 않는다. 다시 펼치면 늘림·덮기를 다시 판정해 칸이 열린다 |
| AT-TD-36 | TD-06.AC-01·02 | 열기 → 저장된 `hejo-local.json` 확인 → 새 컨트롤러 | `todoDrawerOpen`(이름은 구현 자유) 참. 새 컨트롤러에서 채팅을 펼치면 열린다. `MemberState`의 변경 대기열에 새 키가 없다 |
| AT-TD-37 | NFR-TD-03, TD-03.AC-06 | 가짜 문. 칸 닫힘 10분 / 열림 11분 / 열림 중 재연결 | 닫힘: `deadlines` 요청 0. 열림: 열 때 1 + 5분마다(5분·10분) = 3. 재연결 직후 1 추가 |
| AT-TD-42 | NFR-TD-03 (3판), TD-02.AC-05 | 칸 열림 상태에서 채팅 접기 → 11분 경과(주기 확인 호출 포함) → 채팅 펼치기. 또 열림 선호가 저장된 상태로 새 컨트롤러를 만들고 채팅을 접은 채 둔다 | 접힌 11분 동안 `deadlines` 요청 0. 펼친 직후 요청 1. 접힌 채로 시작한 새 컨트롤러는 펼치기 전까지 요청 0 |
| AT-TD-38 | 회귀 | `leading` 0인 `PetPlacement` | 기존 `PetWindowTests`·`WebPaneTests` 기대값이 그대로다. `bash scripts/test.sh` 앱 부분이 전부 통과한다 |

## 운영·사장 확인 (수동)

| ID | AC | 절차 | 기대 |
|---|---|---|---|
| M1 | TD-05.AC-01·05 | 서버에서 `hermes-deadlines list --json` 실행(출력은 개수·직원 id만 기록). 실행 전후 운영 장부 2개의 sha256을 비교 | 종료 0, `failed` 없음, 장부 sha256 같음 |
| M2 | TD-07.AC-01 | 문 재시작 뒤 앱에서 칸 열기 | 문 로그 `deadlines_read items=N failed=0`, 앱에 마감 카드 N개 |
| M3 | TD-01~04 | 사장이 이 Mac에서 열고 닫기·덮기·카드 누르기 | 시안 v28 느낌과 위 AC대로 동작(사장 판단) |
