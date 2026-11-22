# HEJO-DEADLINE-CLOSE 설계

3판 · 2026-11-22(계획 검증 1·2회차 반영) · 상태: 적용(2026-11-22, 운영 RELEASE 227ef160·team-kit HD b32048c8·앱 v0.2.6) · 명세 [spec.md](spec.md) · 기준 `de8bdac` / HD `eee573e6`

## 1. 책임과 흐름

```
[앱 TodoDrawer] --deadlines--> [문 Deadlines.list] --exec--> [hermes-deadlines list] --읽기--> 장부
     ^ items(+origin,+notice)                                    (notice = hejo 영수증 요약)
[앱] 우클릭 → 5초 대기 → --deadline_close--> [문 Deadlines.close] --exec--> [hermes-deadlines close]
                                               └ ActionJournal 1줄                 └ perform(close) + repaint_closed
     <--deadline_close_status-- ; 성공이면 앱이 deadlines 다시 요청
```

| 책임 | 단 하나의 자리 |
|---|---|
| 닫기 규칙(사유·근거·멱등·다시 칠하기) | team-kit `deadline_watch.perform` + `repaint_closed`(기존). 새 CLI는 이것을 부르기만 한다 |
| 알림 위치 요약(`notice`) 계산 | team-kit `open_items` |
| 출처 종류(`origin`) 계산 | 문 `public_items`(id 앞부분 → 열거값). 앱은 열거값 → 한국어 이름만 |
| 요청 검증·실행 경계·이유 코드·행동 기록 | 문 `Deadlines.close` |
| 대기·되돌리기·숨김·실패 줄 | 앱 `ConversationController`(상태) + `TodoDrawerModel.snapshot`(숨김 반영) |
| 이동 대상 결정 | 앱 `ConversationView.selectDrawerCard` 한 곳 |

의존 방향: 앱 → 안내판 → 문 → team-kit 실행 파일 → 장부. 앱은 team-kit 키 형식을 해석하지 않는다(`origin`을 받음).

## 2. team-kit (`HD`)

- `deadline_watch.py`
  - `open_items(home)`: 기존 키에 `notice`를 더한다. 영수증 중 `platform=='hejo' and status=='sent' and message_id`인 것 가운데 `at`이 가장 늦은 것의 `{message_id, thread}`다. `thread`가 없으면 `notice`를 만들지 않는다.
  - 새 `close_main(home, argv)`: `close --profile P --id I --outcome done|cancel --json`.
    1. 명부를 읽는다(`read_team`, `list_main`과 같은 실패 → `TEAM_UNAVAILABLE`). `P ∉ ["default", *agents]` → `PROFILE_UNKNOWN`.
    2. `home_p = profile_home(home, P)`. `perform(home_p, {"action":"close", ...})`을 부른다. **허용 변경**: `perform`의 close 분기는 이미 잠금 안에서 `if not item["closed"]`로 닫는다. 이 분기에서 이번 호출이 닫았는지를 지역 변수로 기록해 반환 dict에 `closed_now: bool`을 더한다(close 동작일 때만). 그 밖의 `perform` 분기·반환·잠금은 바꾸지 않는다. 전후 읽기나 시각 비교는 쓰지 않는다(경합).
    3. done → `{"action":"close","id":I,"reason":"담당자 확인","reply":"hejo에서 사장이 완료로 닫음"}`. cancel → `{"action":"close","id":I,"reason":"취소","evidence":"hejo에서 사장이 취소로 닫음"}`.
    4. `closed_now`가 참일 때만 `repaint_closed(home_p, item)`를 부르고, 거짓이면 `already_closed:true, repainted:false`다. 예외는 `repainted:false`로 바꾸고 닫힘은 유지한다.
    5. `ValueError("unknown_deadline")` → `UNKNOWN_DEADLINE`. `deadline_state_corrupt`·`deadline_symlink_refused` → `DEADLINE_STATE_UNAVAILABLE`. 그 밖의 예외는 종료 1 + `{"error":"CLOSE_FAILED"}`.
  - 공용 진입 `main(home, argv)`: 첫 인자 `list`/`close`로 나눈다. `list_main`의 동작은 그대로 둔다.
- `hermes/bin/hermes-deadlines`: docstring을 "open deadlines list and owner close"로 바꾸고 `main`을 부른다. 런타임 선택 부분은 그대로 둔다.
- `handle`(직원 도구) **허용 변경 한 줄**: close 뒤 다시 칠하기 조건을 `result.get("ok")`에서 `result.get("ok") and result.get("closed_now")`로 바꾼다. 거짓이면 `result["status_updated"] = False`. 그 밖의 인증·범위·반환은 바꾸지 않는다. 이로써 CLI·직원 도구 어느 순서로 동시에 닫아도 다시 칠하기는 잠금 안에서 닫은 호출 하나만 한다.
- 동시성: 장부 쓰기는 기존 `locked()`(파일 잠금 + 원자적 교체)가 직원 런타임과 직렬화한다. `repaint_closed_hejo`는 자체적으로 `locked` 안에서 문의 Unix 입구를 부른다. 그래서 문이 CLI 실행 중에 이벤트 루프를 막으면 교착된다(3절 조건).

## 3. 문 (`gate/deadlines.py`, `gate/server.py`)

- `public_items`
  - 항목에 `origin`을 더한다. `id`가 `^(notion|calendar|reminder|slack|notes|gmail):`로 시작하면 그 앞부분이고, 아니면 키를 넣지 않는다.
  - 입력에 `notice`가 있으면 검증해서 넘긴다. `message_id`·`thread`는 문자열 1~200자이고, 다른 키가 있으면 `invalid_response`다.
  - 허용 응답 키: `{employee,id,title,due,deadline_at?,url?,origin?,notice?}`.
- `Deadlines.close(device, employee, deadline, outcome, employees)`
  - 검증(spec REQ-DC-04 AC-02) → 실패면 `{'ok':False,'reason':'invalid_request'}`. 행동 기록과 실행은 하지 않는다.
  - `not available` → `unavailable`(행동 기록 남김).
  - 닫기 실행은 `asyncio.Lock` 하나로 직렬화한다(문 전체에서 한 번에 하나).
  - 시간 예산(요청 수신 시각 기준 총 60초): 잠금 대기 ≤ 20초(`asyncio.timeout`으로 `lock.acquire` 감쌈). 만료면 자식 프로세스를 만들지 않고 `busy`로 답한다 → **미실행 보장**. 잠금을 얻으면 실행 제한 40초(대기 시간과 무관하게 고정, 20+40=60). 실행 시작 뒤의 실패는 "실행됐을 수 있음"이며 앱은 다음 목록으로 진실을 확인한다(spec AC-07). 값은 주입 가능하게 둔다(시험).
  - 실행은 `list`와 같은 자식 프로세스 규칙을 따른다: `stdin DEVNULL`, 출력 상한, `_reap`, env.
  - 실행 제한 40초의 근거: `repaint_closed`는 Slack 플랫폼일 때 알림마다 HTTP 제한 20초를 쓴다(`slack_call`). hejo 플랫폼(현재 운영 설정)일 때는 Unix 입구 왕복이다. Slack 플랫폼에서 알림이 2개를 넘으면 40초를 넘을 수 있고, 그때는 닫힘은 남고 다시 칠하기가 중간에 끊긴다(장부는 원자적 교체라 일관됨). 이 한계를 받아들인다.
  - 실행 Task는 연결과 분리한다. 요청 연결이 끊겨도 `asyncio.shield`로 끝까지 실행하고, 행동 기록 뒤에 연결이 살아 있으면 답한다. 문 정지(`stop`) 때는 기존 `list`처럼 취소·회수한다.
  - 출력 해석: 종료 0 + `{"ok":true,"already_closed":bool,"repainted":bool}` → 성공. 종료 1 + `{"error":"UNKNOWN_DEADLINE"}` → `unknown_deadline`. 그 밖의 오류 코드·종료 코드 → `command_failed`. JSON 아님·모양 틀림 → `invalid_response`.
  - 행동 기록: `ActionJournal(home).append(device=…, profile=employee, connection='deadline:'+outcome, action='deadline_close', outcome=<done|cancel|already_closed|이유>)`. 마감 id는 행 필드 `deadline`으로 더한다(`append`에 선택 인자 `deadline=None` 추가, 기존 호출 불변).
  - 로그: `deadline_close outcome=%s ok=%d repainted=%d`. 제목·id·출처는 남기지 않는다.
- 목록 읽기와 닫기 세대(PR-01-R2)
  - `Deadlines`에 정수 `close_generation`을 둔다. 닫기 명령이 끝나면(성공·실패·시간 초과 모두, 자식 프로세스 회수 뒤) 응답을 보내기 **전에** 1 올린다. `busy`·`invalid_request`처럼 실행하지 않은 경우는 올리지 않는다.
  - `list()`는 실행 중인 읽기가 있고 그 읽기의 시작 세대가 현재 세대와 같을 때만 합류한다. 다르면 새 읽기를 시작한다. 옛 읽기는 계속 돌아 원래 대기자에게만 답한다. 실행 중 읽기를 세대별로 관리하며(예: 세대→Task 사전), 끝난 Task는 지운다. 문 정지 때 모두 취소·회수한다.
  - 결과: 앱이 닫기 성공을 받은 뒤 보낸 목록 요청은 반드시 닫기가 끝난 뒤 시작한 읽기로 답을 받는다.
- `server.py` 분배
  - `frame['type']=='deadline_close'` → `deadline_waiters`처럼 Task로 띄워 수신 루프를 막지 않는다.
  - 응답은 `{'v':1,'type':'deadline_close_status','ref':frame['id'],'ok':True,'already_closed':…,'repainted':…}` 또는 `{…,'ok':False,'reason':…}`다.
  - 명부는 `{e['id'] for e in self.adapter.employees()} | {'default'}`다.
- 연결 종료 정리: 닫기 대기 Task는 취소하지 않는다(AC-04). 응답 전송 실패는 무시하고 로그만 남긴다.

## 4. 안내판 (`schemas/hejo-wire-v1.json`)

- `deadlines_status.items.properties`에 `origin: {enum:[notion,calendar,reminder,slack,notes,gmail]}`, `notice: {type:object, properties:{message_id,thread: string 1..200}, required:[message_id,thread], additionalProperties:false}`를 더한다.
- 새 `deadline_close`(앱→문): `{v:1,type,id(1..200),employee(직원 패턴),deadline(1..300),outcome:enum[done,cancel]}`, 추가 필드 금지.
- 새 `deadline_close_status`(문→앱): `{v,type,ref,ok}`.
  - `ok:true`이면 `already_closed`·`repainted`(boolean)가 필수이고 `reason`은 없다.
  - `ok:false`이면 `reason` enum `[unavailable,invalid_request,busy,unknown_deadline,command_failed,invalid_response]`가 필수다.
- 두 정의를 최상위 `oneOf` 목록에 더한다. 버전은 `v:1`로 유지한다(새 type·선택 필드 추가뿐이다).

## 5. 앱

- `TodoDrawerModel.Deadline`: `origin: String?`, `notice: (messageID, thread)?`를 읽는다.
- `Card`: `origin` 표시용 문자열, `noticeID: String?`, `deadlineRef: (employee, id)?`, `linked: Bool`을 더한다.
  - `linked`는 "알림 글이 모델에 있음 ∨ url 있음"이고 `snapshot`이 계산한다.
  - 종류 줄 = `badge` + (`origin` 있으면 " · 이름"). `linked == false`면 오른쪽에 "연결된 대화 없음"을 그린다.
- `snapshot(…, hidden: Set<String>)`: 숨긴 마감 카드 id(`deadline:<employee>:<id>`)를 목록과 개수에서 뺀다.
- `ConversationView.selectDrawerCard`(교체): 마감 카드면 알림 글이 `model.messages`에 있을 때 그 글로 이동(`reveal`+강조 1.5초)한다. 아니면 url을 열고, 둘 다 없으면 선택만 한다. **1:1 방 선택 분기를 지운다.** 답 요청·알림 카드는 지금 그대로다.
- `TodoDrawerCardView.menu(for:)`: 마감 카드에만 `NSMenu`(완료로 닫기 / 취소로 닫기 / url 있으면 출처 열기)를 준다. 기존 `RoomActionItem` 방식을 따른다(`ConversationView.swift:242`).
- `ConversationController` 대기 상태(메모리만)
  - `pendingClose: (card, outcome, timer)?`, `inFlight: [cardID: closeRef]`(보낸 뒤 응답 대기, 카드마다 75초 타이머), `confirming: [cardID: listSeq]`(성공 뒤 확인 대기), `closeFailed: Bool`.
  - 목록 요청마다 단조 증가 번호 `listSeq`를 붙이고 ref→번호를 기억한다(`deadlineRefs`를 사전으로).
  - 닫기 선택: 이미 대기 중인 것이 있으면 바로 보낸다. 새 것을 `pendingClose`로 두고 5초 타이머를 건다. 숨김 = `pending ∪ inFlight.keys ∪ confirming.keys`.
  - 되돌리기: 타이머를 해제하고 `pendingClose = nil`. 보내지 않는다.
  - 보냄: `deadline_close` 프레임, ref를 기억하고, 75초 응답 타이머를 건다. 연결이 없거나 전송 예외가 나면 실패 처리한다.
  - `deadline_close_status`(ref로 카드 찾기): 성공 → `inFlight`에서 빼고 `confirming[card] = 다음 listSeq`로 둔 뒤 `requestDeadlines()`(이때 쓰인 번호). 실패 → `inFlight`에서 빼고 `closeFailed = true`(카드 재표시).
  - 목록 응답 적용 순서: `lastAppliedSeq`를 둔다. 번호 n ≤ `lastAppliedSeq`인 응답은 버린다(목록·`available`·`failed`·숨김 모두 그대로). n이 더 크면 적용하고 `lastAppliedSeq = n`. 연결 재설정 때 번호는 이어서 늘리고 `lastAppliedSeq`는 유지한다.
  - `deadlines_status`(번호 n, 위 규칙으로 적용된 것만): 유효(reason 없음)하면 `confirming` 가운데 `seq ≤ n`이고 직원이 `failed`에 없는 카드만 뺀다. `inFlight`·`pendingClose`는 목록으로 풀지 않는다. 실패 응답·`seq > n`은 아무것도 풀지 않는다.
  - 기존 `requestDeadlines`의 "칸이 보일 때만 요청" 조건(NFR-TD-03)은 `confirming`이 비어 있지 않을 때 성공 직후 1회 요청에는 적용하지 않는다(확인 요청). 칸이 안 보이면 그 뒤 주기 요청은 기존 규칙대로다.
  - `closeFailed`는 닫기 성공 또는 칸을 다시 열 때 지운다. 문장은 "마감을 닫지 못했어요. 다시 해 주세요."다.
  - 칸 가시성과 무관하게 타이머가 돈다(AC-06). 연결 재설정(`welcome` 전 리셋)에서 `inFlight`는 모두 실패로 처리한다(`confirming`은 유지하고 재연결 뒤 목록으로 확인). 컨트롤러 정지·앱 종료 때 `pendingClose`는 보내지 않고 버린다.
- `TodoDrawerView`: 맨 아래 되돌리기 줄("‘제목’ 닫음 · 되돌리기")과 실패 줄을 둔다. 콜백은 `onCloseDeadline(card, outcome)`, `onUndoClose()`, `onOpenSource(url)`이다.
- 시계: 대기·응답 시간은 기존 주입 시계(`clock`)와 타이머 주입으로 시험에서 바꿀 수 있어야 한다.

## 6. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| 마감 카드 클릭 → 1:1 방 선택(`ConversationView.swift:16`) | **교체** | 알림 글 → 링크 → 선택만. 같은 변경에서 1:1 분기를 지운다. TD AT-TD-26의 "없음은 1:1 방" 기대와 "닫기 단추 없음" 기대는 AT-DC-25·26으로 대체한다(TD 수락 시험 표에 대체 표시) |
| TD REQ-TD-04 AC-03 "칸에 닫는 단추 없음, 쓰기 주체는 직원뿐" | **교체** | 사장 결정. 단추는 없고 우클릭 메뉴만 둔다. 고치기·새로 만들기는 여전히 없다 |
| team-kit `list_main` | 유지·확장 | `notice` 추가 외 불변 |
| team-kit `perform` close 분기 | 유지·확장 | 반환에 `closed_now`만 추가(잠금 안 판정). 닫기 규칙 복제 금지 |
| team-kit `repaint_closed` | 유지 | 새 CLI가 같은 함수를 부른다 |
| team-kit `handle` close의 다시 칠하기 조건 | 교체(한 줄) | `ok` → `ok and closed_now`. 이미 닫힌 항목의 중복 다시 칠하기 제거 |
| 문 수락 시험 AT-TD-10 허용 키(`tests/acceptance/test_deadlines.py:57`) | 교체 | `origin`·`notice` 추가. 계획 담당이 2판에서 직접 고침(수락 시험 쓰기 허가) |
| team-kit 시험 AT-TD-01 키 집합(`HD` `team-kit/tests/test_deadline_list.py`) | 교체 | `notice?` 추가. TASK-01이 고침(운영 저장소 시험은 이 저장소 수락 시험 밖, 기대값은 AT-DC-08이 정함) |
| 문 `Deadlines.list` 실행 공유 | 확장 | 공유 조건에 "닫기 완료 세대 일치"를 더한다(3절). 자식 프로세스 회수는 유지·재사용 |
| `ActionJournal.append` | 유지·확장 | 선택 인자 `deadline` 추가, 기존 호출 불변 |

## 7. 대안과 기각

| 대안 | 판단 |
|---|---|
| 직원에게 "닫아줘" 글을 보내 직원이 닫기 | 사장이 기각(문이 바로 닫기 선택). AI 처리라 느리고 확실하지 않다 |
| 되돌리기 = 닫은 뒤 team-kit `reopen` | 기각. `repaint_closed_hejo`가 알림 글 버튼을 지우고 `reopen`은 되살리지 않아 반쪽 되돌리기가 된다. 보내기 전 대기로 대체한다 |
| 앱이 id 앞부분으로 출처 종류 해석 | 기각. team-kit 키 형식이 앱에 새어 나간다. 문이 열거값으로 바꾼다 |
| 장부를 문이 직접 고치기 | 기각. 닫기 규칙·잠금·다시 칠하기의 두 번째 원본이 생긴다 |

## 8. 위험과 롤백

- team-kit(TASK-01): 일반. 기존 잠금·규칙 재사용, 되돌릴 수 있음(`reopen`).
- 문(TASK-02): **고위험**. 근거는 두 가지다.
  - 기기 출입증 연결에 새 원격 쓰기 입구가 생긴다(권한).
  - 자식 프로세스와 이벤트 루프·Unix 입구 재진입 사이에 교착 가능성이 있다(동시성).
  - 그래서 구현 담당과 다른 모델의 검증이 필수다.
- 앱(TASK-03): 일반.
- 서버 적용(TASK-04): 고위험(운영 공항). 롤백은 문 릴리스를 이전 것으로 되돌리고 `deadline_watch.py`·`hermes-deadlines` 보관본으로 바꾼 뒤 재시작하는 것이다. 이미 닫은 항목은 직원 도구 `reopen`으로 되돌린다(알림 글 색은 되돌아오지 않음, 사장에게 고지).
