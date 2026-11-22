# HEJO-DEADLINE-CLOSE 명세: 마감 카드 이동·없음 표시·우클릭 닫기

3판 · 2026-11-22(2판: 계획 검증 1회차 PR-01~06, 3판: 2회차 PR-01-R2·PR-03-R2 반영, [plan-review.md](plan-review.md)) · 상태: 초안(계획 검증 재검토 대기) · 기준 커밋 `de8bdac`(이 저장소), 운영 저장소 `eee573e6`
결정 기록 [brainstorm.md](brainstorm.md), 설계 [design.md](design.md), 수락 시험 [HEJO-DEADLINE-CLOSE.md](../../../tests/acceptance/HEJO-DEADLINE-CLOSE.md), 작업 [tasks.md](tasks.md).
앞선 작업: [HEJO-TODO-DRAWER spec](../HEJO-TODO-DRAWER-20261120/spec.md)(이하 `TD`). 약어 `HD` = `<운영 저장소>`, `TK` = `HD/hermes/plugin-store/team-kit`.

## 칸·원본·쓰기 주체·수명

| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 마감 항목과 닫힘 | 직원 사물함(기존) | 직원 홈마다 `state/deadline-watch.json` | 직원 런타임(기존) **+ 사장(문 경유, 닫기만)** | 영구(기존) |
| 목록·닫기 명령 | team-kit 시설 | `HD/hermes/bin/hermes-deadlines`, `TK/deadline_watch.py` | 개발(운영 저장소 규칙) | 갱신 때 교체 |
| 닫기 요청 실행, 행동 기록 | 문 | `gate/deadlines.py`, `gate/server.py`, 기존 `shared/hejo/actions.jsonl` | 개발 / 문(기록) | 갱신 때 교체 / 기록 영구 |
| `deadline_close`·`deadline_close_status`, `deadlines_status` 항목 필드 | 안내판 | `schemas/hejo-wire-v1.json` | 개발 | 갱신 때 교체 |
| 우클릭 메뉴, 이동, 없음 표시, 되돌리기 대기 | 관제 화면 | `app/Sources/TodoDrawer*.swift`, `ConversationController`·`ConversationView` | 개발(대기 상태는 메모리만) | 갱신 때 교체 |

새 칸 없음. 두 번째 원본 없음. 닫힘의 원본은 여전히 장부 하나이고, 닫기 규칙(사유·근거·알림 다시 칠하기)은 team-kit `perform`·`repaint_closed` 한 곳이다. 문과 앱은 마감을 고치거나 새로 만들지 않는다.

## 1. 현재 상태 (조사 2026-11-22, 읽기 전용)

| # | 사실 | 근거 |
|---|---|---|
| 1 | 마감 카드 클릭: `url`이 있으면 링크를 열고, 없으면 직원 1:1 방을 고른다 | `app/Sources/ConversationView.swift:11-17`, TD REQ-TD-04 AC-02, `app/Tests/TodoDrawerTests.swift:79-80`(AT-TD-26) |
| 2 | 문은 `http(s)`+host 출처만 `url`로 넘기고 `source`는 버린다 | `gate/deadlines.py:47-52` |
| 3 | 목록 명령은 열린 항목의 `id,title,due,deadline_at,source`만 낸다 | `TK/deadline_watch.py` `open_items`·`list_main`(160-187) |
| 4 | hejo로 보낸 알림 영수증에는 `platform:'hejo'`, `status`, `message_id`, `head_id`, `thread`가 있다. 닫으면 `repaint_closed_hejo`가 마지막 알림 글을 버튼 없이 편집하고 영수증의 `message_id`를 새 글로 바꾼다 | `TK/deadline_watch.py:320-333, 380-400` |
| 5 | 닫기 규칙: 사유는 `담당자 확인`(reply 필수)·`완료 근거 확인`·`취소`(evidence 필수)·`마감 경과` 중 하나. 없는 id는 `unknown_deadline`. 이미 닫혔으면 바꾸지 않는다 | `TK/deadline_watch.py:41, 228-249` |
| 6 | 직원 도구의 닫기(`handle`)는 닫은 뒤 `repaint_closed`를 부른다 | `TK/deadline_watch.py:450-451` |
| 7 | 문은 team-kit 쓰기 명령을 고정 실행 파일로 부르고 `ActionJournal`에 남기는 선례가 있다 | `gate/connection_runtime.py:16-42, 139-`, `gate/connection_manager.py:292` |
| 8 | 운영 장부의 열린 항목: 직원 1명에 2개(모두 `reminder:`, 출처 `reminders://`), 다른 직원 0개 | `~/.hermes/bin/hermes-deadlines list --json` 실행(2026-11-22, 읽기) |
| 9 | 실행본 `deadline_watch.py` sha256 = HD HEAD 파일 = `470d2725…` | `shasum` 2026-11-22 |
| 10 | `docs/spec/current/` 폴더가 없다(프로젝트 설정 표에는 있음). 이 작업은 현재 명세 반영을 TD와 같은 방식(ARCHITECTURE·작업 문서 상태)으로 한다 | `ls` |

## 2. 요구와 수락 기준

### REQ-DC-01 마감 카드를 누르면 관련 hejo 글로 간다
- AC-01(정상): 마감 항목에 hejo로 보낸 알림이 있고(`notice.message_id`), 그 글이 앱 기록에 있으면, 카드를 눌렀을 때 그 글의 방·스레드로 이동하고 1.5초 강조한다(TD REQ-TD-04 AC-01과 같은 경로). 칸은 열린 채로 남고 카드는 선택 테두리로 표시된다.
- AC-02(정상): hejo 알림 글이 없거나 앱 기록에 없고 출처가 `http(s)` 링크면, 지금처럼 링크 열기 경로로 연다.
- AC-03(경계): 둘 다 없으면 이동하지 않는다. 카드는 선택 테두리만 표시된다. **직원 1:1 방으로 이동하지 않는다**(TD REQ-TD-04 AC-02의 "링크가 아니면 1:1 방" 교체).
- AC-04(정상): 알림 글과 링크가 둘 다 있으면 누를 때는 알림 글로 가고, 우클릭 메뉴의 "출처 열기"로 링크를 연다.

### REQ-DC-02 출처와 없음 표시
- AC-01(정상): 마감 카드의 종류 줄은 `D-n` 뒤에 출처 종류를 붙인다. 예: `D+34 · 미리알림`. 출처 종류는 항목 id 앞부분으로 정한다: `notion`→노션, `calendar`→캘린더, `reminder`→미리알림, `slack`→Slack, `notes`→메모, `gmail`→메일. 모르는 앞부분이면 출처 종류를 붙이지 않는다.
- AC-02(경계): REQ-DC-01 AC-03처럼 이동할 곳이 없는 카드는 종류 줄 오른쪽에 "연결된 대화 없음"을 회색으로 늘 보여 준다. 누르기 전에도 보인다.
- AC-03(정상): 답 요청·알림 카드의 모양과 동작은 바뀌지 않는다.

### REQ-DC-03 우클릭으로 닫기
- AC-01(정상): 마감 카드를 우클릭(또는 control-클릭)하면 메뉴에 "완료로 닫기", "취소로 닫기"가 있다. 출처 링크가 있으면 "출처 열기"도 있다. 답 요청·알림 카드에는 메뉴가 없다.
- AC-02(정상): 닫기를 고르면 확인 창 없이 그 카드가 바로 목록과 개수에서 빠진다. 칸 맨 아래에 "‘<제목>’ 닫음 · 되돌리기" 줄이 5초 동안 보인다.
- AC-03(정상): 5초 안에 "되돌리기"를 누르면 카드가 원래 자리로 돌아오고 문에 아무것도 보내지 않는다.
- AC-04(정상): 5초가 지나면 앱은 문에 닫기를 요청한다. 성공하면 마감 목록을 다시 요청한다. 카드는 **그 성공 뒤에 보낸 목록 요청의 유효한 응답**(실패 이유 없음, 그 직원이 `failed`에 없음)을 받을 때까지 숨김을 유지한다. 그 응답에 항목이 없으면 그대로 끝나고, 있으면 장부대로 다시 보인다(원인을 추정해 표시하지 않는다). 성공 전에 보낸 목록 요청의 늦은 응답, 실패 응답, 그 직원이 `failed`에 든 응답은 숨김을 풀지 않는다(다음 주기 목록을 기다림).
- AC-11(경계): 앱은 목록 응답을 요청 번호 순서로만 적용한다. 이미 적용한 응답보다 앞 번호의 응답이 늦게 오면 버린다(목록·숨김 모두 바꾸지 않음). 문은 닫기 성공을 답한 뒤에 받은 목록 요청을 그 닫기 전에 시작한 읽기 결과로 답하지 않는다(REQ-DC-04 AC-07).
- AC-10(경계): 닫기 요청은 카드마다 따로 추적한다. A가 성공해 목록을 확인하는 동안 B의 요청이 아직 응답 대기 중이면, 어떤 목록 응답도 B의 숨김을 풀지 않는다. 숨겨진 카드(대기·응답 대기·확인 대기)에는 다시 닫기를 할 수 없다(보이지 않으므로 메뉴도 없음).
- AC-05(경계): 대기 중에 다른 카드를 닫으면 앞 카드는 그 자리에서 바로 요청하고(대기 끝), 새 카드가 5초 대기를 시작한다. 되돌리기 줄은 새 카드 것만 보인다.
- AC-06(경계): 대기 중에 칸을 닫거나 채팅을 접어도 대기는 계속되고, 5초 뒤 요청한다. 대기 중에 앱이 끝나면 요청하지 않는다(장부는 그대로 열림, 다음 목록에서 카드가 다시 보임).
- AC-07(실패): 닫기 요청이 실패하면(문 연결 없음, 문이 `ok:false`로 답함, 응답 없음 75초 = 문 총 제한 60초 + 여유) 카드가 목록에 다시 나타나고 칸에 회색 한 줄 "마감을 닫지 못했어요. 다시 해 주세요."가 붙는다. 이 줄은 다음 닫기 성공이나 칸을 다시 열 때 사라진다. 장부는 그대로다(team-kit이 닫기 전에 실패한 경우). 이미 닫힌 뒤 응답만 잃었으면(앱 75초 초과 등) 다음 목록에서 카드가 빠진다. 문이 `busy`로 답했으면 명령은 실행되지 않았음이 보장된다.
- AC-08(정상): 장부 결과: "완료로 닫기"는 사유 `담당자 확인`, reply "hejo에서 사장이 완료로 닫음"이다. "취소로 닫기"는 사유 `취소`, evidence "hejo에서 사장이 취소로 닫음"이다. 닫은 뒤 이미 보낸 알림 글은 직원 도구로 닫을 때와 똑같이 다시 칠해진다(`repaint_closed`). 다시 칠하기가 실패해도 닫힘은 유지된다.
- AC-09(경계): 이미 닫힌 항목을 닫으면 성공으로 답하고 장부·알림 글을 바꾸지 않는다. 없는 id면 `unknown_deadline`로 실패한다(AC-07 동작).

### REQ-DC-04 문의 닫기 입구
- AC-01(정상): 문은 `deadline_close`(employee, deadline, outcome) 요청을 받아 `hermes-deadlines close --profile <employee> --id <deadline> --outcome <done|cancel> --json`을 실행하고 `deadline_close_status`로 답한다.
- AC-02(실패): 다음은 명령을 실행하지 않고 실패로 답한다: team-kit 없음(`unavailable`), employee가 형식에 어긋나거나 현재 명부(`default` 포함)에 없음, deadline id가 team-kit 키 형식(`^(notion|calendar|reminder|slack|notes|gmail):\S{1,240}$`)이 아님, outcome이 `done`·`cancel`이 아님(모두 `invalid_request`).
- AC-03(실패): 시간 제한은 **요청 수신부터 총 60초**다. 앞선 닫기를 기다리는 시간은 최대 20초이고, 그 안에 차례가 오지 않으면 명령을 **실행하지 않고** `busy`로 답한다(행동 기록 결과 `busy`). 차례가 오면 실행 제한은 40초다. 명령 실패·실행 시간 초과·응답 모양 틀림은 `command_failed`·`invalid_response`로 답한다. 명령의 `UNKNOWN_DEADLINE`은 `unknown_deadline`로 답한다.
- AC-04(경계): 요청한 연결이 끊겨도 이미 시작한 명령은 끝까지 실행하고 행동 기록을 남긴다. 닫기 실행 중에도 문은 다른 프레임(예: `roster`, `deadlines`)에 답한다.
- AC-07(경계): 목록 읽기 공유는 "닫기 완료 세대"가 같은 요청끼리만 한다. 닫기 명령이 끝난 뒤(응답을 보내기 전에 세대를 올림) 들어온 `deadlines` 요청은, 그 전에 시작한 읽기가 아직 진행 중이어도 합류하지 않고 새 읽기를 시작한다. 옛 읽기는 원래 기다리던 요청에만 답한다.
- AC-05(정상): 실행할 때마다(성공·실패 모두, `invalid_request` 제외) 행동 기록 한 줄을 남긴다: 시각, 기기, 직원, 동작 `deadline_close`, 결과(`done`/`cancel`/`already_closed`/실패 이유), 마감 id.

### REQ-DC-05 team-kit 목록·닫기 명령
- AC-01(정상): `list --json`의 각 항목에 hejo로 보낸 마지막 알림이 있으면 `notice: {message_id, thread}`를 더한다. 영수증 중 `platform == 'hejo'`, `status == 'sent'`, `message_id`가 있는 것 가운데 `at`이 가장 늦은 것이다. 없으면 `notice` 키가 없다. 다른 영수증 정보(본문·대상·delivery)는 내보내지 않는다.
- AC-02(정상): `close --profile P --id I --outcome done|cancel --json`은 그 직원 홈 장부를 REQ-DC-03 AC-08대로 닫고 `repaint_closed`를 부른다. 출력은 `{"ok":true,"already_closed":false,"repainted":true|false}`, 종료 0이다.
- AC-03(경계): 이미 닫힌 항목이면 `{"ok":true,"already_closed":true,"repainted":false}`, 종료 0이다. 장부·알림 글은 바뀌지 않는다. "이번 호출이 닫았는가"는 장부 잠금 안에서 정한다. 같은 항목을 동시에 닫는 호출(사장 close 둘, 또는 사장 close와 직원 도구 close)에서 새 닫힘과 다시 칠하기는 정확히 하나만 일어난다(직원 도구가 이긴 경우 사장 쪽은 `already_closed:true`).
- AC-04(실패): 명부에 없는 직원은 `{"error":"PROFILE_UNKNOWN"}`, 없는 id는 `{"error":"UNKNOWN_DEADLINE"}`, 장부 깨짐·장부 심볼릭 링크 거부는 `{"error":"DEADLINE_STATE_UNAVAILABLE"}`, 명부를 읽을 수 없으면 `{"error":"TEAM_UNAVAILABLE"}`이다. 모두 종료 1이고 장부는 그대로다.
- AC-05(회귀): `list`의 기존 출력 키와 실패 처리는 그대로다(`notice` 추가만). `perform`의 close 결과에 키 `closed_now`(bool)가 더해지는 것 외에 기존 반환·동작은 그대로다. 직원 도구의 reopen·notify 동작은 그대로다. 직원 도구 close(`handle`)는 한 가지만 바뀐다: `closed_now`가 거짓(이미 닫힘)이면 `repaint_closed`를 부르지 않고 `status_updated:false`를 낸다. 새로 닫았을 때의 동작·반환은 그대로다.

### REQ-DC-06 서버 적용과 묵은 항목 정리 (이번 구현 지시 밖)
- AC-01: 사장 승인 뒤 team-kit·문을 운영 공항에 적용하고 게이트웨이를 한 번 재시작한다. 롤백 절차를 먼저 기록한다.
- AC-02: 적용한 뒤 사장이 앱에서 묵은 `reminder:` 항목 2개를 우클릭으로 닫는다(사장 행동). 이어서 목록에서 빠졌는지 읽기로 확인한다.

### NFR-DC-01 개인값
- 문 로그에는 제목·출처·마감 id를 남기지 않는다. `deadline_close outcome=<…> ok=<0|1> repainted=<0|1>` 형식만 남긴다. 행동 기록에는 마감 id를 남긴다(사장 공항 안 기록, 기존 행동 기록과 같은 0600).
- 시험·문서 예시는 가짜 직원·가짜 제목만 쓴다.

### NFR-DC-02 권한
- 닫기 입구는 기존 기기 출입증으로 열린 연결에서만 받는다(새 인증 없음). 인증 전이거나 출입증이 틀린·취소된 연결에서는 명령이 실행되지 않는다. Touch ID 재확인은 하지 않는다(사장 결정: 확인 없이 + 되돌리기). 근간 원칙 6의 재확인 대상(직원 생성·도구 부여·해고)이 아니다. 행동 기록은 남긴다.
