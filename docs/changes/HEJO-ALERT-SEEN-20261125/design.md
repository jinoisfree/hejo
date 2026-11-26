# HEJO-ALERT-SEEN 설계

- 상태: 3판(검증 2차 V-1 반영: 확인 요청 소실과 조정자 대기열) · spec 3판과 짝 · 3판 현황 근거 커밋: 공개판 `7540da1` · 설계 근거 커밋: 공개판 `github/main` `c22e677`(착수 때 tip으로 다시 확인, handoff 0절)
- 변경 성격: 의미 변경(작음). REQ-AS-01은 빠진 선택 경로를 기존 확인 처리에 묶고, REQ-AS-02는 문의 notice 미리보기 문장만 바꾼다.

## 1. 현황 [확인, `c22e677`]

| 사실 | 근거 |
|---|---|
| 확인 처리 함수: 그 스레드가 울리는 알림(질문 아님)일 때만 `markNoticeRead` → 기록 나눠 받기 모드는 `history.readIntent("notice", 방, key)` | `app/Sources/WorkspaceTools.swift` `markAlertSeen`·`markNoticeRead` |
| 문의 읽음 계획: `notice`면 `thread:`와 `bell:`을 그 스레드 `originalMaxSeq`로 한 번에 쓴다 | `gate/history_queries.py` `read_plan` |
| `markAlertSeen`을 부르는 곳은 둘뿐: `reveal`(가운데 카드·말풍선·검색·링크·질문 칩·분기 이동이 모두 지나감), `chooseThread`(채팅의 스레드 카드 클릭) | `app/Sources/ConversationView.swift` `reveal`·`chooseThread` |
| 직접 선택인데 확인을 안 하는 곳: `writeReply`("답글" 버튼), 미로딩 카드 "원문 불러오기"(`select(..., markRead:false)`) | 같은 파일 `writeReply`, `unloadedThreadContent` |
| 자동 선택(확인 안 함, 유지): `selectAutomatic`, `entry`의 임시글 복원(`markRead:false`), 갱신 중 임시글 복원, 컨트롤러의 후속·재시도·방 만들기 선택 | 같은 파일 `selectAutomatic`·`entry`·갱신부, `ConversationController.swift` |
| 카드 제목: 기록 나눠 받기 모드는 문이 준 `notice.preview`를 그대로 쓴다 | `app/Sources/TodoDrawerModel.swift` `snapshot`(`remote?.preview`) |
| 문의 미리보기: 첫 비어 있지 않은 줄을 300 묶음으로 자른다 | `gate/history_queries.py` `summary` 안 `notice.update(... preview=prefix(first_line, 300))` |
| 출시 빌드는 기록 나눠 받기 경로만 컴파일한다. 레거시 경로는 `HEJO_LEGACY_REFERENCE` 등 참조·시험 빌드 전용 | `WorkspaceTools.swift`의 `#if` 블록, `app/scripts/test.sh`의 `-D HEJO_LEGACY_REFERENCE` |

진행 중인 다른 작업: [HEJO-AUTOLOAD](../HEJO-AUTOLOAD-20261125/spec.md) TASK-01이 같은 `ConversationView.swift`의 미로딩 카드 버튼을 없앤다(자동 불러오기는 선택·읽음을 일으키지 않음, REQ-ALD-01 AC-02). [HEJO-WAIT-JITTER](../HEJO-WAIT-JITTER-20261125/handoff.md)도 같은 파일(`updateSidebarRows`)과 `NativeThreadList.swift`를 고친다.

## 2. 구조

### 2.1 REQ-AS-01 — 사장 직접 선택의 단일 입구

- **책임 위치:** "사장이 직접 고른 선택 = 선택 + 읽음 + 알림 확인"을 한 입구로 만든다. 지금 `reveal`·`chooseThread`가 각자 `select(...)` 뒤에 `markAlertSeen(key)`를 붙이는 것을 그 입구 하나로 통합하고, 직접 선택 경로(`writeReply`, 카드 안 버튼으로 여는 경로가 남아 있으면 그것)도 그 입구를 쓴다. 입구의 위치(모델의 메서드인지 뷰의 private 함수인지)와 이름은 구현이 정한다. 단, `markAlertSeen` 호출은 그 입구 한 곳에만 남는다(검증: `grep -n markAlertSeen app/Sources`가 정의 1 + 호출 1).
- **자동 선택은 입구를 쓰지 않는다(D-01).** `selectAutomatic`·임시글 복원·컨트롤러 후속 선택은 지금처럼 `ConversationModel.select`를 직접 부른다.
- **읽음과 알림 확인의 관계:** 입구의 읽음(`markRead`)은 각 경로의 지금 값을 유지한다. "원문 불러오기"는 지금 `markRead:false`인데, 직접 클릭이므로 알림 확인은 한다(알림 확인 = 문의 `notice` 계획이 `thread:`도 함께 씀. 지금 `reveal`도 같은 결과).
- **`markAlertSeen` 자체는 유지:** 울리는 알림인지 판정해 아니면 아무것도 하지 않으므로 질문·일반 스레드·새 스레드에 불러도 부작용이 없다(AC-06).
- **확인 요청은 한 건(3판):** 고른 스레드가 울리는 알림이면 입구는 스레드 읽음(`thread`)을 따로 걸지 않고 알림 확인(`notice`)만 건다. 문의 `notice` 계획이 `thread:`와 `bell:`을 함께 쓰므로 읽음이 빠지지 않는다. 울리는 알림이 아니면 지금처럼 경로의 읽음 값대로 `thread`만 건다. 그래서 한 번의 직접 선택은 그 스레드에 대해 읽음 요청을 최대 한 건만 만든다(AC-05a). 구현 방법(예: 입구가 판정을 먼저 하고 `select`의 `markRead`를 끄는 것)은 구현이 정한다. 레거시 참조 모드도 같은 입구를 지나므로 같은 결과(`markNoticeRead`가 두 키를 한 번에 씀)다.
- **조정자 대기열(3판, `HistoryCoordinator.inputsChanged`):** [확인 `7540da1`] `inputsChanged`는 세션·입력(회원 상태 포함 문맥)·선택·창 표시 중 하나가 바뀌면 `reads`를 모두 비운다. 그런데 `ConversationModel.select`는 선택이 바뀔 때 `intentGeneration`을 먼저 올린 뒤 읽음 요청을 건다. 즉 비우는 시점에 대기열에는 "바뀐 뒤에 걸린 지금 세대 요청"이 들어 있을 수 있다. 수정: 세션이 바뀐 경우가 아니면 `inputsChanged`는 지금 `intentGeneration`과 같은 세대의 읽음 요청은 남기고 옛 세대 요청만 버린다. 새 세션이면 지금처럼 모두 버린다. 보내기 직전의 세대 검사(`request.3 == intentGeneration`)는 그대로 둔다. 이로써 (가) 직접 선택 직후의 요청은 살아남고, (나) 옛 선택의 요청은 계속 버려진다(AC-09, 기존 안전 조건 유지). 회원 상태가 바뀌면 세대가 올라가므로 그 전에 걸린 요청은 지금처럼 버려진다. 확인 요청이 한 건이 되어 자기 쓰기 때문에 자기 요청이 버려지는 일은 없다.
- **실패:** 기존 실패 처리(`failure`, 실패 줄)를 그대로 쓴다. 새 재시도·대기열을 만들지 않는다. 같은 스레드를 다시 고르면 새 요청이 걸린다(AC-07c).

대안(조정자): 직접 선택용 요청을 따로 보관하는 두 번째 대기열. 기각 — 같은 일을 하는 두 경로가 생긴다(덧대기). 대안(문): `thread` 계획이 울리는 알림이면 `bell:`도 쓰게 하는 안. 기각 — 창이 보일 때의 다른 `thread` 읽음(자동 경로 포함)까지 알림을 지워 D-01을 어긴다.

위험도: 일반 유지. 대기열 변경은 `@MainActor` 단일 스레드 안의 순서 규칙이고, 잘못돼도 영향은 읽음·확인 표시(회원 상태의 읽음 키)다. 옛 선택 요청을 버리는 조건(AC-09)을 시험으로 고정한다.

### 2.2 REQ-AS-02 — notice 미리보기 문장

- **책임 위치:** 문 `gate/history_queries.py`의 notice 미리보기 계산 한 곳. 첫 비어 있지 않은 줄을 고르는 지금 코드를 "첫 줄이 멘션뿐이면 다음 비어 있지 않은 줄을 ' · '로 이어 붙임"으로 바꾸고 `prefix(..., 300)`은 그대로 적용한다. 작은 순수 함수로 빼도 된다(이름은 구현이 정함).
- 앱은 바꾸지 않는다(`remote?.preview`를 그대로 표시). 레거시 참조 경로의 `IslandModel.firstLine`도 유지(참조 빌드는 "출시 동작 비교용"이라 바꾸지 않음).
- 스키마: notice `preview`는 여전히 문자열이다. 길이 한도 동일. 앱 쪽 디코더(`HistoryHTTP.swift`의 `row["preview"] is String`)와 호환.

대안: 앱이 스레드 요약의 `rootPreview`로 제목을 다시 만드는 안. 기각 — 가운데 창은 모든 방의 알림을 보여 주는데 요약은 열린 방 것만 있어 일관되지 않고, 같은 규칙의 두 번째 원본이 생긴다.

## 3. 유지할 계약

- 옛 선택·옛 세대의 읽음 요청은 보내지 않는다(조정자 보내기 직전 세대 검사, AC-09).

- 알림·질문 판정, `bell:`·`thread:` 키와 값, 읽음 계획 동작(`read_plan`), 기존 시험 AT-TD-39·AT-UC-17·AT77 기대값.
- 자동 선택 동작과 읽음 처리(D-01).
- 문 HTTP 규격(필드 추가·삭제 없음), 섬 질문 미리보기 24자, 스레드 요약 `title`·`preview`·`rootPreview`.

## 4. 기존 경로 판정

| 경로 | 판정 | 처리 |
|---|---|---|
| `reveal`·`chooseThread`의 `select + markAlertSeen` | 통합 | 단일 입구로 옮기고 두 곳의 직접 호출은 지운다 |
| `writeReply`의 `select` | 교체 | 단일 입구로 |
| 미로딩 카드 버튼의 `select(markRead:false)` | 교체(남아 있을 때) | 단일 입구로(읽음 값 유지). AUTOLOAD로 사라졌으면 해당 없음을 impl-report에 적는다 |
| 자동 선택 경로 | 유지 | D-01 |
| 문 notice `preview` 계산 | 교체 | 새 규칙, 옛 계산 줄 제거 |
| 조정자 `inputsChanged`의 `reads = []`(세션 외 변경) | 교체(3판) | 지금 세대 요청은 남기고 옛 세대만 버림. 새 세션은 지금처럼 전부 버림 |
| 울리는 알림 직접 선택의 `thread` + `notice` 두 요청 | 통합(3판) | `notice` 한 건 |
| 레거시 `TodoDrawerModel`의 `firstLine` 제목 | 유지 | 참조 빌드 |

## 5. 위험·롤백

- 위험도 일반. 저장 구조·키 종류 변화 없음. 코드 오류의 영향은 알림 카드가 덜 지워지거나(남음) 더 지워지는(사라짐) 것이다.
- **코드 되돌림이 복구하는 것:** 앞으로의 동작(어느 선택이 알림을 확인하는지, 카드 제목 문장). 제목은 저장되지 않으므로 문을 되돌리면 바로 옛 문장이 된다.
- **코드 되돌림이 복구하지 않는 것:** 새 경로(주로 "답글" 버튼, 카드 안 여는 버튼)가 이미 허브 회원 상태에 쓴 `bell:`·`thread:` 값. 이 값은 회원 상태에 남고 다른 기기에도 퍼진다. 영향은 두 가지다. (1) `bell:`: 그 스레드의 알림 카드·종이 다시 울리지 않는다. 알림 카드는 원래 직원 첫 글에서 24시간 뒤 스스로 빠지므로(문 `summary`의 알림 조건) 이 영향은 **그 알림 카드의 표시 기한(최대 24시간) 안에서만** 차이가 난다. (2) `thread:`: 기한 없이 남아 그 스레드의 안 읽은 글 수 계산에 계속 쓰인다(`history_queries.py` `summary`의 `read = max(read:, thread:)`). 즉 그때까지의 직원 글은 읽은 것으로 남는다. 다만 "답글" 버튼은 기준본에서도 `select(markRead:true)`로 `thread:`를 이미 쓰므로 새로 생기는 `thread:`는 `markRead:false`였던 카드 안 여는 버튼 경로(남아 있을 때)에 한하고, 그 뒤 새 직원 글은 seq가 커서 다시 안 읽음으로 센다. 질문 카드는 `notice` 계획 대상이 아니므로(`markAlertSeen`이 질문을 거름) 잘못 지워지지 않는다. 대화 원본 손실은 없다(문 기록장에 그대로).
- **처리:** 되돌린 뒤 따로 상태를 지우지 않는다. 사장이 특정 알림을 다시 보고 싶으면 그 스레드는 채팅에 그대로 있다. 허브 상태를 손으로 고치는 복구 절차는 만들지 않는다(이 작업 범위 밖, 실데이터 수정이라 별도 승인 필요).
- 앱·문 설치는 이 작업 밖(별도 릴리스). 문이 갱신되기 전에는 REQ-AS-02가 보이지 않는다.
