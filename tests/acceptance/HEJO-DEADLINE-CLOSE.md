# HEJO-DEADLINE-CLOSE 수락 시험 명세

3판 · 2026-11-22(2판: 계획 검증 1회차 PR-01~06, 3판: 2회차 PR-01-R2·PR-03-R2 반영) · 명세 [spec.md](../../docs/changes/HEJO-DEADLINE-CLOSE-20261122/spec.md) · 설계 [design.md](../../docs/changes/HEJO-DEADLINE-CLOSE-20261122/design.md)

상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1·2회차 BLOCKED → 3판 반영, 재검토 대기.

- 기대값 출처는 spec 요구와 design 2~5절이다. 구현 담당은 코드로 옮길 때 기대값·합격 기준을 바꾸지 않는다. 바꿔야 하면 멈추고 보고한다.
- 공통 조건: 임시 `HERMES_HOME`, 가짜 직원 `alpha`·`beta`(+ `default`), 가짜 장부, 가짜 `hermes-deadlines`, 고정 시계 2026-11-22 10:00 Asia/Seoul. 실제 직원 id·제목·주소는 쓰지 않는다.

## team-kit (`HD` worktree `team-kit/tests/test_deadline_list.py`·`test_deadline_close.py`(새))

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-DC-01 | DC-05.AC-01 | alpha 열린 항목 3개를 둔다. (가) hejo 영수증이 2개다: 7단계 `sent`(at 09:00, m1/t1), 3단계 `sent`(at 10:00, m2/t2). (나) Slack 영수증만 있다(`ts`만). (다) hejo 영수증이 `uncertain`이다 | (가)만 `notice == {message_id:"m2", thread:"t2"}`다. (나)(다)에는 `notice` 키가 없다. 어떤 항목에도 `notifications`·`body`·`target`·`delivery`가 없다 |
| AT-DC-02 | DC-05.AC-02, DC-03.AC-08 | alpha 열린 항목 `gmail:x1`(hejo 영수증 1개), `close --profile alpha --id gmail:x1 --outcome done --json`. 다시 칠하기는 가짜(호출 기록) | 종료 0, `{"ok":true,"already_closed":false,"repainted":true}`. 장부에 `closed.reason=="담당자 확인"`이 있다. `replies[-1].text=="hejo에서 사장이 완료로 닫음"`이다. 다시 칠하기가 그 항목으로 1번 불렸다 |
| AT-DC-03 | DC-05.AC-02, DC-03.AC-08 | 같은 조건에서 `--outcome cancel` | `closed.reason=="취소"`, `closed.evidence=="hejo에서 사장이 취소로 닫음"`, 다시 칠하기 1번 |
| AT-DC-04 | DC-05.AC-02 | 다시 칠하기가 예외를 던진다 | 종료 0, `repainted:false`, 장부는 닫힘 |
| AT-DC-05 | DC-05.AC-03, DC-03.AC-09 | 이미 닫힌 항목을 닫는다 | 종료 0, `{"ok":true,"already_closed":true,"repainted":false}`. 장부 파일 sha256이 같고 다시 칠하기 0번이다 |
| AT-DC-06 | DC-05.AC-04 | (가) 명부에 없는 `gamma` (나) 없는 id (다) 깨진 장부 (라) 명부 파일 없음 (마) alpha 장부가 심볼릭 링크 | (가) `PROFILE_UNKNOWN` (나) `UNKNOWN_DEADLINE` (다)(마) `DEADLINE_STATE_UNAVAILABLE` (라) `TEAM_UNAVAILABLE`. 모두 종료 1이고 가짜 홈 전체 sha256이 같다 |
| AT-DC-07 | DC-05.AC-04 | `--outcome later`, `--profile` 빠짐 | 종료 1(argparse 또는 오류 JSON). 장부 불변 |
| AT-DC-08 | DC-05.AC-05 | 기존 `test_deadline_list.py`·`test_deadline_watch.py` | 모두 통과. 기존 AT-TD-01의 "키는 `{id,title,due,source}`와 `deadline_at`뿐" 기대는 `notice?`를 더한 집합으로 바뀐다(이 작업이 그 기대를 고친다) |
| AT-DC-09b | DC-05.AC-03·05 동시성 | 같은 열린 항목. 다시 칠하기(`repaint_closed`)는 가짜(호출 기록). (가) `close` CLI 진입 함수 2개를 별도 프로세스로 동시에 실행 (나) CLI `close` 1개와 **직원 도구 진입 `handle(config, home, {"action":"close","id":…,"reason":"담당자 확인","reply":…}, kind="chat", …)`**(기존 `test_deadline_watch.py`의 chat close 호출 방식) 1개를 동시에 실행. 순서를 강제한 두 경우(CLI 먼저 / handle 먼저)를 모두 본다 | (가) 출력 둘 중 정확히 하나가 `already_closed:false`, 다른 하나가 `already_closed:true`. (나) 두 순서 모두: 장부 `closed`가 한 번만 기록되고, **다시 칠하기 호출이 정확히 1번**이다. CLI가 먼저면 CLI `already_closed:false`·handle `status_updated:false`, handle이 먼저면 handle이 다시 칠하고 CLI `already_closed:true`. (다) 이미 닫힌 항목에 handle close만 다시 부르면 다시 칠하기 0번, `status_updated:false` |
| AT-DC-09 | DC-05.AC-02 동시성 | 닫기와 같은 장부에 직원 쪽 `perform(upsert)`를 스레드 2개로 동시에 실행 | 두 변경이 모두 남는다(잠금 직렬화). 장부가 유효하다(`validate` 통과) |

## 문 (`tests/acceptance/test_deadline_close.py`(새))

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-DC-10 | DC-02.AC-01(문 쪽) | 가짜 list 출력. 항목 id가 `reminder:a`, `gmail:b`, `weird:c`이고, `gmail:b`에 `notice{message_id:"m",thread:"t"}`가 있다 | 응답의 `origin`은 각각 `reminder`, `gmail`, 키 없음이다. `notice`는 `gmail:b`에만 그대로 있다. 키 집합은 `{employee,id,title,due,deadline_at?,url?,origin?,notice?}`의 부분집합이다 |
| AT-DC-11 | 규격 | `notice`에 다른 키가 있거나 `message_id`가 숫자 | `reason:"invalid_response"` |
| AT-DC-12 | DC-04.AC-01 | `deadline_close{employee:alpha,deadline:"gmail:b",outcome:done}`. 가짜 close가 인자를 기록하고 `{"ok":true,"already_closed":false,"repainted":true}`를 출력 | 인자가 정확히 `close --profile alpha --id gmail:b --outcome done --json`이다. 응답은 `deadline_close_status{ref,ok:true,already_closed:false,repainted:true}`다. 행동 기록 1줄(`action:"deadline_close"`, `profile:"alpha"`, `outcome:"done"`, `deadline:"gmail:b"`, 기기 id) |
| AT-DC-13 | DC-04.AC-02 | (가) 명령 파일 없음 (나) employee `Alpha!` (다) 명부에 없는 `gamma` (라) deadline `x:1` (마) outcome `later` | (가) `unavailable`, 행동 기록 1줄. (나)~(마) `invalid_request`, 행동 기록 0줄. 모든 경우 명령 실행 0번 |
| AT-DC-14 | DC-04.AC-03 | 가짜 close가 (가) 종료 1 + `UNKNOWN_DEADLINE` (나) 종료 1 + `CLOSE_FAILED` (다) JSON 아님 (라) 멈춤(제한 시간 주입 1초) | (가) `unknown_deadline` (나) `command_failed` (다) `invalid_response` (라) `command_failed`이고 자식 프로세스가 남지 않는다. 각각 행동 기록 1줄(결과 = 이유) |
| AT-DC-15 | DC-04.AC-04 | 2초 걸리는 가짜 close. 보낸 뒤 0.3초에 같은 연결로 `roster`를 보내고, 0.5초에 연결을 끊는다 | `roster` 응답이 close 응답보다 먼저 온다. 연결을 끊어도 명령은 끝까지 돌고(종료 표식 파일이 생김) 행동 기록 1줄이 남는다. 예외가 로그 밖으로 새지 않는다 |
| AT-DC-16b | DC-04.AC-03 시간 예산 | 주입 값: 잠금 대기 1초, 실행 제한 2초. 가짜 close는 1.5초 걸리고 실행마다 표식 파일을 남김. 서로 다른 연결 3개에서 0초에 연달아 요청 | 첫째 성공. 둘째는 첫째가 끝난 1.5초에 차례를 얻지 못하므로(대기 1초 초과) `busy`. 셋째도 `busy`. 표식 파일 1개(둘째·셋째는 실행 0번), 3초 더 기다려도 표식이 늘지 않는다. 행동 기록 3줄(`done`,`busy`,`busy`). 모든 응답이 요청 뒤 3초(대기+실행 예산) 안에 온다 |
| AT-DC-16c | DC-04.AC-07 | **실제 `Deadlines.list` 공유 경로**를 쓴다. 가짜 list 명령은 실행마다 번호를 올려 출력에 담고(1번째 실행은 항목 X 포함, 2번째부터 X 없음) 1초 걸린다. 가짜 close는 즉시 성공. 순서: R0 `deadlines` → 0.2초에 `deadline_close`(성공 응답 수신) → 그 뒤 R1 `deadlines` | list 명령 실행 2번. R0 응답 = 1번째 실행(X 있음), R1 응답 = 2번째 실행(X 없음). 닫기 전 R0와 같은 세대의 요청(닫기 전에 보낸 R0') 은 1번째 실행에 합류한다(실행 횟수 증가 없음) |
| AT-DC-16 | DC-04.AC-04 동시성 | 1초 걸리는 가짜 close를 서로 다른 연결 2개에서 동시에 요청. 가짜는 시작·끝 시각을 기록 | 두 실행 구간이 겹치지 않는다(직렬화). 두 응답 모두 온다 |
| AT-DC-17 | DC-04.AC-04 재진입 | 가짜 close가 실행 중 문 Unix 입구(`/local/v1/…`)에 요청 1번을 보내고 그 응답을 받은 뒤 끝난다 | close가 제한 시간 안에 성공으로 끝난다(교착 없음) |
| AT-DC-35 | NFR-DC-02 | (가) hello 없이 `deadline_close` (나) 틀린 출입증으로 hello 뒤 `deadline_close` (다) 취소된 기기 출입증 | 연결이 거부·종료되거나 오류만 온다. 명령 실행 0번, 행동 기록 0줄 |
| AT-DC-18 | NFR-DC-01 | AT-DC-12·14 | 문 로그에 제목·마감 id·출처 표식 문자열이 없다. `deadline_close outcome=… ok=… repainted=…` 형식만 있다 |
| AT-DC-19 | 규격 | AT-DC-10~16의 요청·응답 | `schemas/hejo-wire-v1.json`으로 검증 통과. `deadline_close_status`의 `ok:true`+`reason`, `ok:false`에 `reason` 없음은 규격 위반이다. `reason:"busy"`는 유효하다. 기존 규격 시험 모두 통과 |
| AT-DC-20 | 회귀 | — | `bash scripts/test.sh` gate 부분 전부 통과(AT-TD-10~19 포함). AT-TD-10의 허용 키 집합은 2판에서 `origin`·`notice`를 더한 집합으로 바뀌었다(`tests/acceptance/test_deadlines.py`, 계획 담당 수정). 그 밖의 AT-TD 기대값은 그대로다 |

## 앱 (`app/Tests/TodoDrawerTests.swift` 확장)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-DC-21 | DC-02.AC-01 | 마감 `reminder:`/`gmail:`/origin 없음 3개 | 종류 줄이 `D+1 · 미리알림`, `D-DAY · 메일`, `D-4`다 |
| AT-DC-21b | DC-02.AC-01 (검증 1차 V-1) | origin 6종 `notion`·`calendar`·`reminder`·`slack`·`notes`·`gmail`과 모르는 값 `other` | 종류 줄 꼬리가 각각 `노션`·`캘린더`·`미리알림`·`Slack`·`메모`·`메일`이고, `other`는 꼬리가 없다 |
| AT-DC-22 | DC-02.AC-02 | (가) notice 있음 + 그 글이 모델에 있음 (나) notice 있지만 모델에 없음, url 없음 (다) url만 (라) 둘 다 없음 | `linked`: (가) 참 (나) 거짓 (다) 참 (라) 거짓. 거짓인 카드 보기만 "연결된 대화 없음"을 그린다(보기 접근성 문자열 또는 그리기 기록으로 관측) |
| AT-DC-23 | DC-01.AC-01 | (가) 카드 클릭 | 그 글 방·스레드가 선택된다. `highlightedMessageID == notice.message_id`이고 1.5초 뒤 강조가 사라진다. 칸이 열려 있고 카드가 선택 상태다 |
| AT-DC-24 | DC-01.AC-02·04 | (다) 클릭, notice+url 둘 다 있는 카드 클릭 | (다)는 링크 열기 1번. 둘 다 있으면 링크 열기 0번이고 글로 이동한다 |
| AT-DC-25 | DC-01.AC-03 | (라)와 (나) 클릭. 클릭 전 선택 방은 beta 1:1 | 선택 방이 그대로 beta다(alpha 1:1로 바뀌지 않음). 링크 열기 0번, 카드 선택 상태 |
| AT-DC-26 | DC-03.AC-01, DC-01.AC-04 | 각 카드의 `menu(for:)`, url 있는 카드에서 "출처 열기" 항목 실행 | 마감 카드: 제목이 `["완료로 닫기","취소로 닫기"]`, url이 있으면 `"출처 열기"`가 더 있다. 답 요청·알림 카드: `nil`. 카드 보기에 단추(NSButton)가 없다. "출처 열기" 실행 → 링크 열기 경로가 그 url로 1번 불린다 |
| AT-DC-27 | DC-03.AC-02·04 | 마감 4개에서 1개를 "완료로 닫기". 시계를 4.9초로 진행한 뒤 5.0초로 진행 | 즉시 목록·개수에서 빠지고 되돌리기 줄이 보인다. 4.9초에 보낸 프레임 0개다. 5.0초에 `deadline_close{employee,deadline,outcome:"done"}` 1개를 보낸다. 성공 응답 → `deadlines` 요청 1개(칸이 닫혀 있어도). 새 목록(그 항목 없음)을 받은 뒤에도 빠진 상태다 |
| AT-DC-27b | DC-03.AC-04 | 닫기 프레임을 보내기 **전에** 보낸 목록 요청 R0이 있다. 성공 응답 뒤 R0 응답이 그 항목을 포함해 늦게 도착 → 이어서 성공 뒤 요청 R1의 응답이 (가) `reason` 실패 (나) 그 직원이 `failed`에 듦 (다) 유효하고 항목 없음 (라) 유효하고 항목 있음 | R0 응답 뒤에도 카드는 숨김. (가)(나) 뒤에도 숨김. (다) 숨김 유지(목록에 없음)이고 확인 상태가 끝남. (라) 카드가 다시 보인다 |
| AT-DC-27c | DC-03.AC-10 | A·B를 닫음(B 선택이 A를 즉시 보냄, B는 5초 뒤 보냄). A 성공 → 확인 목록 요청 R1. B 응답 대기 중에 R1 응답(유효, A 없음, **B 있음**) 도착. 그 뒤 B 성공 → R2 응답(B 없음) | R1 뒤 A는 사라진 채, B는 숨김 유지(응답 대기 중). B 카드에 메뉴를 열 수 없다(보이지 않음). R2 뒤 B도 사라진 채. 보낸 `deadline_close`는 A·B 각 1개 |
| AT-DC-27d | DC-03.AC-11 | 닫기 성공 → 확인 요청 R1. 그보다 앞 번호인 R0가 있다. R1 응답(유효, 항목 없음)이 먼저 와서 확인이 끝난 뒤 R0 응답(항목 있음)이 도착 | R0 응답은 버려진다: 카드가 다시 나타나지 않고, 마감 개수·`failed`·경고 줄도 R1 기준 그대로다 |
| AT-DC-28 | DC-03.AC-03 | 닫기 → 2초 뒤 되돌리기 → 10초 진행 | 카드가 원래 순서로 돌아온다. 보낸 `deadline_close` 0개 |
| AT-DC-29 | DC-03.AC-05 | A 닫기 → 1초 뒤 B "취소로 닫기" | B를 고르는 순간 A의 프레임 1개(`done`). 되돌리기 줄은 B 제목이다. 5초 뒤 B 프레임(`cancel`) |
| AT-DC-30 | DC-03.AC-06 | 닫기 → 칸 닫기(또는 채팅 접기) → 5초 | 프레임 1개를 보낸다 |
| AT-DC-31 | DC-03.AC-07 | (가) 응답 `ok:false,reason:unknown_deadline` (나) 전송 예외 (다) 응답 없이 75초 | 카드가 다시 나타나고 실패 줄 "마감을 닫지 못했어요. 다시 해 주세요."가 보인다. 칸을 닫았다 열면 줄이 사라진다. (다)는 74.9초에는 아직 숨김이다 |
| AT-DC-32 | DC-03.AC-07 | 응답 대기 중 연결 재설정(`welcome`) | 실패 처리(카드 재표시 + 실패 줄) 뒤 새 목록 요청 |
| AT-DC-34 | DC-03.AC-06 | 닫기 → 2초 뒤 컨트롤러 정지(앱 종료 경로) → 시계 10초 진행 | 보낸 `deadline_close` 0개, 타이머가 남지 않는다 |
| AT-DC-33 | DC-02.AC-03 회귀 | 기존 AT-TD-20~42 | 모두 통과. AT-TD-26의 "없음은 alpha 1:1 선택" 줄은 AT-DC-25로 대체한다 |

## 수동·실환경 (TASK-04, 이번 구현 지시 밖)

| ID | AC | 절차 | 기대 |
|---|---|---|---|
| M-DC-1 | DC-06.AC-01 | 적용 뒤 `hermes-deadlines list --json` | 종료 0, `failed` 없음. 기록에는 항목 개수와 가명(직원 A·B…)만 적는다. 직원 id·이름·제목·출처는 적지 않는다 |
| M-DC-2 | DC-06.AC-02 | 사장이 앱에서 `reminder:` 2개를 "완료로 닫기"(또는 사장 선택) | 5초 뒤 카드가 사라진다. `list --json`에서 빠진다. 행동 기록 2줄이 남는다. Slack 영수증뿐이고 플랫폼이 hejo이므로 다시 칠하기 대상이 없어 `repainted`는 참(대상 0)이다. 실제 Slack 쓰기가 없어야 한다 |
