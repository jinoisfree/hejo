# HEJO-JUMP-ONCE 구현 인계

현재 상태는 [5판 재개 기록](#5판-재개--기준본-대조)에 있다.

## 2판 첫 착수 기록

- 구현자 판단: **TASK-01 보류**. 설계 8절 G-2에 반례가 있어 TASK-02에 착수하기 전 기획설계 검토가 필요하다.
- 기준: [handoff.md](handoff.md) 2판, 교차 모델 연합개발, 위험도 일반, 필요 증거 수준 2. `git fetch github` 후 `8095aa46ff0d728d5919a673c33a7438056b7e2d`의 `github/main` 포함을 확인했다. `base_commit = 018036cbf24678ea3a29f826926531e8ab4d370b`.
- 대상: 브랜치 `hejo-jump-once-public-20261126`, worktree `../.worktrees/hejo-jump-once-public-20261126`. 제품 소스에는 위 기준본이 그대로 있다. 진단 시험 두 파일은 미커밋이다.

## G-1 · 방 목록 없이 한 스레드 먼저 그리기

방의 스레드 렌더링은 방 목록의 쪽 상태 대신 방에 해당하는 `history.summaries`를 사용한다(`app/Sources/ConversationModel.swift:856–875`, `app/Sources/ConversationView.swift:772–794`). 다른 방에서 단건 열기 응답과 원문만 받아 둔 뒤 그 방 목록을 받기 전에 E1을 실행했다. 즉시 대상 원문의 좌표가 생겼고 대상 방의 스레드 카드 한 장을 관측했다. 이 실험은 첫 화면에 단건을 그릴 수 있는지 확인한다. AT-JO-07·12의 목표 위치 유지와 시간 판정 전체는 남아 있다.

## G-2 · 보이는 답글 구성 유지와 미리 받기

가짜 방의 답글 120개인 스레드에서 최근 답글을 펼치고 10번째 답글을 카드 대상으로 삼았다. 대상은 현재 쪽 밖에 있다. 같은 시작 상태에서 두 경로를 비교했다.

| 적용 경로 | 기존 답글 구성 | 대상 글 좌표 |
| --- | --- | --- |
| 본문만 `applyHistoryBody`로 저장 | 유지 | 없음 |
| 글 지정 열기 쪽을 `applyHistoryMessages`로 적용 | 바뀜 | 있음 |

본문 저장은 `history.messagePageIDs`를 갱신하지 않는다(`ConversationModel.swift:677–704`). `historyReplyIDs`와 카드의 답글 렌더러는 그 순서에 있는 답글만 그린다(`ConversationModel.swift:564–571`, `ConversationView.swift:1223–1244, 1289–1307`). 글 지정 열기는 기존 쪽을 교체한다(`ConversationModel.swift:590–625`). `HistoryCoordinator.swift:297–305`의 기존 글 지정 열기는 실제로 그 교체 경로를 쓴다.

따라서 design 3.2의 본문 단독 저장은 글 구성 보존에는 충분하지만, 이미 보이는 스레드의 현재 쪽 밖까지 수락 시험에서 요구하는 준비 상태로 만들 수 없다. 열기 쪽을 미리 적용하면 구성 보존을 위반한다. 직접 차단 기준은 **REQ-JO-02.AC-02 / AT-JO-11**이다. 같은 대상을 클릭하면 서버 응답을 기다리는 경로가 남으므로 **REQ-JO-02.AC-01·03 / AT-JO-11·12**에도 영향을 준다.

### 설계 선택지

1. **권고** — 기존 기록장 본문 캐시를 사용하고, 대상 쪽의 순서·커서 정보는 클릭할 때 반영할 수 있도록 분리한다. AT-JO-11에 현재 읽는 쪽 밖의 답글을 명시한다. 준비 중 유효성, 문맥 변경·메모리 축출 뒤 무효화, 클릭 시 연속 구간 구성, 본문 복제·고정 없이 저장하는 책임을 설계에서 먼저 확정한다.
2. 이미 보이는 스레드에서는 현재 쪽에 포함된 글만 즉시 이동 대상으로 삼고, 범위 밖 답글은 클릭 후 받아 한 번 이동하는 조건으로 바꾼다. 미리 받기의 보장 범위가 달라지므로 사용자 결정과 해당 AC·AT에 반영해야 한다.

## 변경 및 검증

- `app/Tests/HistoryAutoloadFixture.py`, `app/Tests/HistoryAutoloadHarness.swift`에 기존 가짜 서버·AppKit 입구를 재사용하는 `jump-assumptions` 진단을 붙였다. AppKit의 스레드 가시 여부와 실제 레이아웃의 대상 글 틀을 관측한다. 증거 수준 2. 제품 경로 변경과 mutation check는 미실행이다.
- ThreeTapDiagnostics로 두 E1 입력을 관측했다. 선택이 바뀐 재현에서는 서버 갱신 1회, 화면 `refresh()` 4회였다. 순서는 `overview → threads → notices → questions → messages → resolve(글 지정) → resolve(원문)`. 이미 선택된 스레드에서 누른 별도 재현은 서버 갱신 0회, 화면 `refresh()` 3회였고 두 `resolve`만 보냈다. 두 경우 모두 글 지정 열기 1회가 완료되어 대상 글이 그려졌다. 읽음 상태가 서버 입력을 다시 바꾸는 경우의 글 지정 열기 소실 여부는 미검증이다. `.build/jump-once/three-tap-baseline.jsonl`, `.build/jump-once/three-tap-same-selection.jsonl`.
- 확인 명령·로그는 공개 worktree 기준이다.
  - 기존 하네스에서 `python -m pytest app/Tests/HistoryAutoloadFixture.py -k "basic or anchored and not send" -q` 종료 0, 7개 통과. `.build/jump-once/harness-regression.log`. 마지막 E1 선택 전환을 추가하기 전 시험 파일에서 실행했다.
  - `bash app/Tests/HistoryTransport.sh` 종료 0. `.build/jump-once/baseline-build.log`.
  - `python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump-assumptions -q -s` 종료 0, 1개 재현 시나리오 통과. 하네스가 두 경로를 비교해 G-2 반례를 기록했다. `.build/jump-once/baseline.log`, `.build/jump-once/three-tap-baseline.jsonl`.
  - `grep -n 'history.scrollTo\|pendingRevealScroll' app/Sources/ConversationView.swift` 종료 0. 기준 기대대로 기존 직접 이동과 대기 변수가 남아 AT-JO-17 기준을 위반한다. `.build/jump-once/at-jo-17-baseline.log`.
  - `git diff --exit-code HEAD -- app/Sources gate schemas hub docs/spec/current` 및 `git diff --check` 종료 0.
  - 기본 홈으로 실행한 `python3 scripts/scan_private.py`는 입력 홈을 지정하지 않아 검사 결과를 채택하지 않는다. 모듈 누락으로 종료 2였고 로그에는 오류 지문만 출력됐다. 가짜 명부와 금고를 둔 임시 홈을 지정해 재실행한 `python3 scripts/scan_private.py --home <임시 홈>` 종료 0. `.build/jump-once/scan-private.log`, `.build/jump-once/scan-private-fixture.log`.
- AT-JO-01~15 전체 시험 작성·실행과 AT-JO-16, TASK-02~05, PNG, 커밋은 미완료다. 수락 기준·시험 명세와 제품 코드는 건드리지 않았다. 설계 판정 뒤 TASK-01에서 이어갈 수 있다.

## 3판 재개 · 기준본 대조

- `git fetch github` 종료 0. 원격 추적 기준과 작업 브랜치의 HEAD는 모두 `018036cbf24678ea3a29f826926531e8ab4d370b`였다. 같은 worktree에서 1차의 G-1/G-2 로그와 ThreeTapDiagnostics를 재사용했다. D-08로 바뀐 미리 받기 범위도 확인했다.
- 제품 코드와 수락 시험 문서에는 변경이 없다. 이전의 `app/Tests/HistoryAutoloadFixture.py` 및 `app/Tests/HistoryAutoloadHarness.swift`에 G-3 서버 비교와 AT-JO-09의 경계 및 중간 위치를 더했다. 위험도 일반, 증거 수준 2. 시험 두 파일은 미커밋이다.

### G-3 반례 · TASK-05 보류

임시 공항의 기존 문 서버에서 `send`로 "생각 중…"을 보냈다. 두 번의 실제 `edit_message(finalize=False)` 뒤 각각 실시간 프레임에 `final:false`가 있는지 확인하고, 같은 회원 문맥의 `overview`·`threads`·`notices`·`questions` 응답을 비교했다. 전송 봉투를 제외하고 `items`와 `totals`를 비교했다. 근거는 `.build/jump-once/g3-baseline.log`에 있다.

| 전이 | 허용 목록 밖에서 바뀐 필드 |
| --- | --- |
| 생각 중 표시 → 일반 본문 | `overview`·`threads`·`notices`의 `unread` 0→1, `alerts` 0→1, `nextNoticeExpiry` 추가. `threads`의 `bell` null→true, `notice` 추가, `title`·`rootPreview` 변경. `notices.items`에 알림 추가. |
| 일반 본문 → 승인 요청 문구 | `overview`·`threads`·`notices`의 `alerts` 1→0, `questions` 0→1, `nextNoticeExpiry` 제거. `threads`의 `assessment.pendingID`·`requestID` 추가, `waitingButtonCount` 0→1, `title`·`rootPreview` 변경. 알림 항목의 `group`·`title`·`questions` 변경. |

별도 `questions` 응답과 `activity.working`은 이 두 입력에서 바뀌지 않았다. `gate/history_queries.py:50–91, 149–194`는 본문에서 생각 중 문구와 승인 요청을 판단한다. 안 읽음은 `thinking` 여부를 검사하며 `final:false`를 제외하지 않는다.

**영향은 REQ-JO-04.AC-03·05와 AT-JO-18이다.** 조각을 전부 건너뛰면 중간의 안 읽음·종·알림 분류 변화도 끝 조각이나 다음 갱신까지 미뤄진다. 사용자가 중간에 알림을 읽거나 확인했을 때와 종료·재연결 뒤의 AC-03 값은 별도 실험이 필요하다.

- 권고 — D-10을 유지한다면 조각 동안 안 읽음·종·알림 분류도 보류된다는 것을 명시하고, 두 전이와 재연결 뒤에 기준본 최종값으로 따라잡는지 시험한다.
- 대안 — 중간 의미 변화는 바로 보여야 한다면 어떤 변화를 예외로 할지 정한다. 문이 제공하는 집계 변경 신호 등 단일 판정 출처를 정하고, 조각 구간 전체 0건 기준 및 앱 전용 범위에 대한 사용자 결정을 받는다.

### AT-JO-09 · 기준본 기대 불일치

같은 방의 기록 모드, 스레드 12장, 대상 글 준비, 초기 목표 거리 300pt 이상, 동작 줄이기 켜짐을 확인했다. E1 클릭 뒤 1.5초의 원점과 실제 대상 글 틀을 60Hz로 관측했다. 맨 위 스레드의 원문은 목록 경계 때문에 카드 가운데와 글 가운데의 목표 원점이 모두 0pt다. 기존 코드가 여러 번 배치를 요청해도 좌표가 바뀐 횟수는 1회였다. 1차 측정에서 초기 거리 2368pt, 되튐 0회, 최종 원점·목표 모두 0pt였다. 이 조건은 시험 명세의 입력을 충족하고 경계 자르기도 명세 규칙이다. 기준본 기대 열은 실패이므로 제품 수정 전에 보류한다.

같은 경계 입력의 후속 실행에서는 첫 시료가 원점 2400pt를 잡아 실패하기도 했다. 시작 원점은 2368pt였고, 첫 시료가 32pt 증가를 잡은 경우와 곧바로 0pt를 잡은 경우에 판정이 달랐다. 중간 대상 대조에서는 카드·글 목표가 각각 1079.5pt와 1004pt였고 자동 이동은 2회였다.

위치가 같은 조건에서도 재현을 고정하려고, 이미 진행 중인 갱신의 응답을 가짜 서버가 클릭 관측이 끝날 때까지 보류하는 변형을 추가했다. 이 경우 카드 12장의 높이 합 2892pt, 보이는 높이 556pt, 초기 목표 거리 2400pt에서 두 목표 원점 모두 0pt였다. 기준본에서 이동 1회, 되튐 0회가 다시 확인됐다. 정상 응답의 중간 글과 진행 중 갱신의 목록 경계 결과가 갈리므로 두 입력을 수락 시험에 명시해야 한다.

권고는 중간 위치의 글을 실패 대조 입력으로 명시하고 목록 경계는 기준본 통과를 기대하는 별도 입력으로 두는 것이다. 좌표로 측정하는 한 번 이동 기준을 그대로 시험할 수 있다.

### 검증 기록과 남은 일

- G-3 `python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump_stream_aggregate_fields -q -s` 종료 0, 응답 비교 1개. 판정은 G-3 불성립. `.build/jump-once/g3-baseline.log`.
- 최종 진단 빌드 `bash app/Tests/HistoryTransport.sh` 종료 0. `.build/jump-once/v3-baseline-build.log`. `python -m pytest app/Tests/HistoryAutoloadFixture.py -k 'jump-reduced-motion or jump_stream_aggregate_fields' -q -s` 종료 0, 진단 4개 통과. 진단 프로세스는 관측을 기록하며 각 AT 판정은 로그의 별도 PASS/FAIL 줄이다. `.build/jump-once/v3-final-baseline.log`.
- 진행 중 갱신 변형을 `python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump-reduced-motion-refresh -q -s`로 독립 재실행했다. 종료 0, 기준본 판정 PASS, 이동 1회·되튐 0회. `.build/jump-once/v3-held-refresh-repeat.log`.
- AT-JO-09 1차 `python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump-reduced-motion -q -s` 종료 0, 시나리오 1개. 기준본의 좌표 판정은 PASS다. `.build/jump-once/v3-at-jo-09.log`.
- `git diff --exit-code HEAD -- app/Sources gate schemas hub docs/spec/current`, `git diff --check` 종료 0.
- G-3 보류는 TASK-05에 적용한다. TASK-02~04는 AT-JO-09 기준본 기대 불일치로 별도 보류했다. 나머지 수락 시험 기준본과 AT-JO-16 전체 회귀, 제품 변경, PNG, 커밋은 남았다.

## 4판 재개 · 기준본 및 시험 계약

- 기준본은 `018036cbf24678ea3a29f826926531e8ab4d370b`다. `git fetch github` 뒤 원격 추적 기준과 공개 작업 브랜치 HEAD가 같은 것을 확인했다. G-1·G-2·G-3과 누름 순서는 앞 회차 기록을 재사용했다.
- `app/Tests/HistoryAutoloadFixture.py`와 `app/Tests/HistoryAutoloadHarness.swift`의 기존 진단을 이어 썼다. AT-JO-01·01b·09는 4판의 대기 완료, 경계 거리, 카드와 글 목표 차이를 확인하고 누름 직전 시료부터 측정한다. 과거 3판의 진행 중 갱신 변형은 로그로 보존했다.

### AT-JO-18의 첫 메시지

4판 AT-JO-18은 새 글 `message`에 `final:false`를 요구한다. `schemas/hejo-wire-v1.json:686–789`의 `message`는 `final`을 선언하지 않고 추가 속성을 금지한다. `schemas/hejo-wire-v1.json:790–837`의 `edit`만 `final`을 받는다. 기존 문 서버에서 WebSocket으로 실제 첫 글과 후속 조각을 관측했고, 실제 첫 글에 필드를 넣은 사본은 공개 스키마 검사에서 거부됐다.

- 권고 — 첫 입력을 일반 `message`("생각 중…")로 두고 30개 후속 `edit`에 `final:false`를 넣는다. "생각 중…"은 `final`이 없는 첫 글이어도 서버에서 `activity.working`으로 분류된다(`gate/history_queries.py:190–194`). D-11의 집계 유예, 중간 전이와 최종 값 판정은 그대로 시험할 수 있다.
- 새 메시지 형식에도 `final`을 넣는다면 문의 발행, 스키마, 앱의 메시지 처리 계약을 다뤄야 한다. 현재 인계의 허용 범위에는 들어 있지 않다.

### AT-JO-08의 스레드 카드 대상

4판 관측 절은 AT-JO-08 모든 입구에 카드와 글의 목표 위치 차이 ≥50pt를 적용한다. 명세 4절은 글 id 없는 입구에서 그 스레드 카드 자체를 대상으로 정한다. `IslandModel.Action.worker`와 `ConversationView.openFromBubble`은 `ConversationKey`만 넘긴다(`app/Sources/IslandModel.swift:14`, `app/Sources/ConversationView.swift:311–315,539–545`). 따라서 E2 작업과 E3에는 두 번째 목표 위치가 없다. E3 미준비 조건도 "스레드 카드가 이미 그려져 있음, 대상 글 본문 없음"을 그대로 적용할 수 없다.

권고는 글 id를 가진 입구에만 카드·글 목표 차이를 적용하는 것이다. E2 작업과 E3의 준비된 입력은 스레드 카드 목표의 경계 거리와 한 번 이동을 검사하고, E3에서 대기하는 입력이 필요하면 대상 카드가 아직 그려지지 않은 조건을 명시한다. 이 입구도 특정 글까지 이동해야 한다면 대상 글을 정하는 계약이 필요하다.

### 4판 검증 기록

- `bash app/Tests/HistoryTransport.sh` 종료 0. `.build/jump-once/v4-baseline-build.log`.
- `python -m pytest app/Tests/HistoryAutoloadFixture.py -k 'jump-ready or jump-reduced-motion-interior or jump_stream_opening_frame_contract' -q -s` 종료 0, 진단 4개. `.build/jump-once/v4-baseline.log`. AppKit 시험의 프로세스 종료와 실제 좌표 판정은 각각 관측한다.
  - AT-JO-01·09: 카드 높이 합 2892pt, 뷰포트 556pt, 카드 목표 1079.5pt와 글 목표 1004pt로 차이 75.5pt. 두 목표는 경계에서 300pt 이상 떨어졌다. AT-JO-01은 31번째 시료에 정착(약 0.52초)하고 되튐이 있어 실패했다. AT-JO-09는 이동 2회로 실패했다. 둘 다 기준본 기대와 일치한다.
  - AT-JO-01b: 두 목표 0pt, 이동 1회, 되튐 1회, 33번째 시료에 정착(0.55초). 기준본 기대가 '기록'인 항목이다.
- `git diff --exit-code HEAD -- app/Sources gate schemas hub docs/spec/current`, `git diff --check` 종료 0.
- `python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump_stream_opening_frame_contract -q -s` 종료 0, 진단 1개 통과. 스키마 유효한 첫 프레임의 `final`은 없고, 입력대로 추가했을 때 `additionalProperties` 위반이다. 후속 실제 `edit`의 `final`은 false다. `.build/jump-once/v4-at-jo-18-contract.log`. AT-JO-18 전체는 미실행이다.
- AT-JO-08은 현재 입구 자료 계약을 확인했다. 수락 시험에서 요구하는 입력을 고치기 전에는 그 항목을 판정할 수 없다. 다른 수락 시험 전체, 제품 변경, PNG, 회귀 비교와 커밋은 보류 상태다.


## 5판 재개 · 기준본 대조

- `git fetch github` 뒤 공개 `github/main`과 작업 브랜치 HEAD가 `018036cbf24678ea3a29f826926531e8ab4d370b`인 것을 확인했다. G-1~G-3, ThreeTapDiagnostics, AT-JO-01·01b·09의 앞 회차 자료를 재사용했다.
- `app/Tests/HistoryAutoloadFixture.py`, `app/Tests/HistoryAutoloadHarness.swift`에서 5판의 시험 입력을 이어 썼다. 변경은 시험 두 파일에 한한다.

### 5판 입력과 기준본에서 확인한 동작

- AT-JO-08 준비됨은 실제 E2 질문·작업, E3 말풍선, E4 검색, E5 알림 핸들러를 사용했다. 글 목표를 보는 세 입구와 카드 목표를 보는 두 입구를 분리했다. 기준본에서는 다섯 입구 모두 실패했다. 카드 대상 E2 작업·E3은 각각 20번째 시료에서 정착했다. `.build/jump-once/v5-baseline.log`.
- AT-JO-02 같은 방은 글이 그려지기 전 원점이 최대 1247pt 움직였다. AT-JO-06 카드 있는 실패 입력은 `target_missing` 전에 최대 1247pt 움직였다. AT-JO-08 미준비 E4·E5의 원점은 그려지기 전에 32pt 움직였다. `.build/jump-once/v5-wait-baseline.log`.
- +32pt 원인을 확인했다. `ConversationView.refresh`가 갱신 상태를 목록 맨 위에 넣으면 14pt 행과 18pt 행 간격이 생긴다. `NativeThreadList.apply`의 기존 위치 유지 보정이 행 높이 증가를 보상해 원점을 옮긴 뒤, 호출부에서 실제 이동을 시작한다. ThreeTapDiagnostics가 원점 2349→2381pt, 사유 `keep`을 `scroll_to` 앞에 기록했다. 기준본 4판의 2368→2400pt와 변화량이 같다. `.build/jump-once/v5-wait-trace.jsonl`. TASK-02와 TASK-04에서 이동 시작과 상태 표시의 책임을 각각 확인할 근거다.
- AT-JO-18은 유효한 첫 `message`와 `edit` 30개를 사용했다. 중간 새 글과 끝 조각 없이 재연결도 각각 실행했다. 일반 스트림에서 화면의 작업 안내와 답변 글은 합계 31번 바뀌었다. 조각 도중 집계 요청은 40건, 끝난 뒤 `overview`는 2건이었다. 중간 새 글 뒤 `overview`는 5건, 재연결 뒤에는 1건이었다. 마지막 제목·미리보기·숫자·종·작업 상태를 로그에 적었다. `.build/jump-once/v5-status-stream-baseline.log`.
- AT-JO-14·15의 표시 진단에서 갱신, 앱 갱신 필요, 읽기 실패, 닫기 실패 모두 기준본의 카드 위치를 21pt 옮겼고, 대화 실패는 목록의 `history-status` 행으로 나타났다. 이 실행은 메뉴 재시도와 위치 보존 전체 판정 이전의 진단이다. `.build/jump-once/v5-status-stream-baseline.log`.

### 전체 회귀 기준본

- `bash scripts/test.sh`를 사용했다. 이전 로컬 환경에서 지정한 Python이 사라져 전용 가상환경과 기존 team-kit 라이브러리로 다시 실행했다. Python 단계 종료 1, 593 통과, `test_at_hf_27_install_twice_and_check` 1건 실패(설치 영수증 mtime). 통합 스크립트가 그 단계에서 멈춰 앱만 따로 실행했다. `.build/jump-once/v5-baseline-regression.log`.
- `bash app/scripts/test.sh`에서 테스트 앱을 로컬 빌드하고 기존 앱 시험을 실행했다. `AT89 inserted row fades at final y without slide or clipping`에서 실패했다. `.build/jump-once/v5-baseline-app.log`.
- `python3 scripts/scan_private.py --home <가짜 명부를 넣은 임시 홈>` 종료 0. `.build/jump-once/v5-baseline-scan.log`. `grep -n 'history.scrollTo\|pendingRevealScroll' app/Sources/ConversationView.swift` 종료 0, AT-JO-17 기존 직접 호출과 변수가 발견돼 기준본 기대와 일치했다. `.build/jump-once/v5-at-jo-17.log`.
- `python -m gate.tests.gateway_delivery` 종료 0. 통합 스크립트의 앞 단계가 중단됐으므로 따로 실행했다. `.build/jump-once/v5-baseline-delivery.log`.
- 일반·legacy 기록 하네스 빌드는 각 종료 0. 기존 기록 회귀는 `python -m pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py -k "not jump" -q` 종료 0, 84개 통과. `.build/jump-once/v5-baseline-transport.log`. 기존 Wait Jitter 단독 실행 종료 0. `.build/jump-once/v5-wait-jitter.log`.

### 추가 기준본 및 이어갈 시험

- AT-JO-02 다른 방, AT-JO-05 연속 누름, AT-JO-07 준비된 다른 방은 기준본에서 실패했다. `.build/jump-once/v5-extra-baseline.log`. 같은 실행의 E3 미준비 진단은 이미 받아진 요약을 써서 입력 확인 단계에서 실패했다.
- E3 미준비는 연결 후 가짜 방 기록에 새 스레드를 넣고, 누르기 전 요약 없음과 방 목록 0.6초 지연을 확인해 다시 실행했다. 대상 카드가 처음 나타난 50번째 시료에서 이동 1회·되튐 0으로 이 하위 입력은 기준본에서도 통과했다. 준비된 다섯 하위 입력과 미준비 E4·E5가 실패했으므로 AT-JO-08 전체의 기준본 기대(실패)와 일치한다. `.build/jump-once/v5-cold-fix.log`.
- AT-JO-11은 카드창 30장, 관측 범위 11장 중 1장만 이미 준비돼 있었다. 구간 밖 글 지정 요청 0건, 이미 있던 답글 구간과 선택·읽음·화면 위치 유지. AT-JO-12·13은 이 실행에서 미리 받기 전제만 실패했으며 지연 누름·조용한 오류와 축출은 미검증이다. `.build/jump-once/v5-cold-fix.log`.
- 현 시점의 남은 기준본은 AT-JO-03 높이 변경, AT-JO-04 실제 입력과 대조 궤적, AT-JO-06 카드 없는 실패, AT-JO-10 최종 원점, AT-JO-12·13 개별 하위 입력, AT-JO-14·15 전체 판정이다. TASK-01이 남아 있어 TASK-02~06은 미착수다.

### 5판 추가 기준본 확인

- AT-JO-03은 첫 변화와 정착 0.3초 뒤의 실제 행 높이가 각각 +120pt임을 확인했다. 목표 거리와 원점 시료는 `.build/jump-once/baseline-placement.log`에 기록했다.
- AT-JO-06 카드 없는 조건은 스레드·글이 없는 가짜 ID, 0.6초 지연 `target_missing` 응답을 사용했다. 기준본은 글이나 카드 없이 최대 66pt 움직였고 실패는 목록 행에 나타나 실패 기준에 부합했다. `.build/jump-once/baseline-next.log`.
- AT-JO-10의 기준 원점은 펼치기 2838.5pt, 대기 글 확인 뒤 5583pt, 다른 방 진입 약 0.074pt다. `.build/jump-once/placement-reference.json`과 `.build/jump-once/baseline-placement.log`.
- AT-JO-15의 세 안내는 각각 카드 위치를 21pt 움직였고, 대화 실패 행의 재시도 버튼은 새 개요 요청을 1건 보냈다. `.build/jump-once/baseline-placement.log`. 갱신 중 두 제목 줄과 대상 글 재조회 전체는 남아 있다.
- AT-JO-18 세 입력의 최종 집계 비교 자료는 `.build/jump-once/jump-stream{,-interleave,-reconnect}-reference.json`에 있다. 중간 새 글이 있기 전의 집계 요청과 재연결 뒤 갱신은 별도 판정한다. `JUMP_ONCE_VERIFY_REFERENCE=1`로 기준본과 최종 집계 비교를 켤 수 있다. `.build/jump-once/baseline-next.log`.
- AT-JO-04 첫 실험은 기존 전송 하네스가 앱 이벤트 루프를 실행하지 않아 창을 활성화하지 못하거나 클릭·키 궤적을 기록하지 못했다. 앱 이벤트 루프를 시험 입력에만 여는 별도 실행 경로를 붙였다. 첫 실패는 제품 기준본 판정에 쓰지 않는다. `.build/jump-once/baseline-input.log`.
- AT-JO-04의 앱 이벤트 루프 보완 뒤 실제 휠·클릭·방향키 6개 입력과 각 대조 궤적을 모두 기록했다. 미준비 세 하위 시험은 모두 기준본 기대대로 실패했다. 준비된 세 하위 시험은 기록이다. `.build/jump-once/baseline-input-loop.log`.
- AT-JO-12에서 준비된 다른 방 대상은 첫 프레임에 정착했고 같은 방 대상은 18프레임 기준을 충족하지 못했다. AT-JO-13은 의도한 서버 실패 요청 자체가 없어서 앞 요건이 충족되지 않았으며 작은 상주 한도에서 축출된 대상은 일찍 1481.5pt 움직였다. `.build/jump-once/baseline-prefetch-variants.log`.
- AT-JO-14의 준비된 글은 보였지만 지정 글 조회 1건과 목록 내 갱신 행이 남았고 대화창 접근성 이름이 없었다. AT-JO-15는 세 안내에서 모두 21pt, 실패 행 제거 뒤 다시 받기 한 번이었다. `.build/jump-once/baseline-status-final.log`. AT-JO-10 세 위치와 AT-JO-18 세 최종 집계는 기준본 재실행에서 저장한 기준값과 일치했다.

### TASK-02 시작

- `ConversationView`에서 E1~E5의 이동 요청을 한 곳으로 모았다. `NativeThreadList`의 세 번 예약을 하나의 감속 이동으로 바꾸고, `HistoryCoordinator`에서 화면에 준비된 지정 글을 다시 받지 않게 연결했다.
- 첫 제품 빌드는 종료 0. `.build/jump-once/task02-build.log`. 첫 실행은 일반 카드(AT-JO-01), 경계(AT-JO-01b), 준비된 다섯 입구, 준비된 다른 방(AT-JO-07)에서 한 번 이동 또는 첫 배치를 확인했다. 목록의 미로딩 자리표시자도 메시지 ID 좌표를 가지므로 대기 중에 이동하는 경로가 남아 본문 상주 여부를 확인하는 조건을 추가했다. `.build/jump-once/task02-motion.log`.
- AT-JO-09의 뒤 주행 1회는 기존 갱신 행이 사라질 때의 위치 보정과 검토해야 한다. AT-JO-10을 감싸는 기존 AT-ALD-14가 실패해 원인을 확인해야 한다. TASK-02 자체 검증과 이후 단계가 남았으며 제품 커밋은 아직 없다.

### TASK-02~05 중간 결과

- `.build/jump-once/task02-prepend.log`에서 이전 답글을 앞에 붙일 때 기존 리더 기준점을 우선하도록 고쳤다. AT-JO-05에서는 두 번째 대상에 정착한 뒤 첫 답이 올 때 원점 변화가 0pt였다. 이후 같은 기준점으로 보낸 대기 글과 확정 글의 위치에 남은 32pt 차이는 목록 갱신 행 제거 뒤 사라졌다.
- `.build/jump-once/task03-prefetch.log`에서 보이는 범위의 11개 대화를 최근 구간으로 준비했다. 기존 구간과 화면 상태를 보존했고 미리 받기에서 글 지정 요청은 0건이었다. 오류 카드 조회는 1건, 조정자 전역 오류는 없었으며 나머지 대상은 준비됐다. 작은 상주 한도에서는 11개 대상이 축출됐고 추가 고정은 0건이었다. 축출된 카드를 누를 때 기존에 펼친 긴 카드가 즉시 접히며 원점이 먼저 움직여, 본문 도착까지 기존 펼침을 유지하도록 수정했다. 보완 시험을 다시 실행한다.
- `.build/jump-once/task04-geometry.log`에서 실제 휠·클릭·방향키 여섯 입력의 대조 최대 차이는 모두 0pt였다. 대상 카드가 없는 실패는 원점 변화 0, 목록 실패 행 없음이었다. 세 카드창 안내를 켰다 끌 때 변화 0pt, 준비된 대상 재조회 0건, 정착 뒤 거리 0pt, 실패 재시도 개요 요청 1건을 확인했다. 시행 당시 AT-JO-10의 방 진입 0pt와 전송 5583pt는 기준 허용 범위였으나 펼치기는 5645pt로 기준 2838.5pt와 달랐다. 예전 최종 위치가 최근 쪽 조회를 한 경우 카드 중앙이었던 경로를 단일 이동에 반영했다. PNG는 `.build/jump-once/refresh.png`, `.build/jump-once/failure.png`이며 첫 갱신 캡처에는 오른쪽 표지만 보여 동시 표시를 보완한다.
- TASK-05는 `ConversationModel.affectsHistoryAggregates`를 본문 적용부와 수신부에서 함께 쓴다. 조각 본문과 판 처리에 이어 집계는 끝 조각 또는 기존 다른 갱신 사유에서 맞춘다. 세 입력의 최종 집계 기준본 대조는 실행 중이다.

### 수락 시험과 기존 경로 재확인

- AT-JO-11 진단에서 기존에 읽는 스레드의 최근 답글만 시험이 채우고 원문은 자리표시자로 남긴 상태였다. 이 원문을 첫 카드 미리 받기가 채우자, 대화 카드의 원문 높이가 72→54pt로 변했다. `.build/jump-once/task06-restore.log`와 `.build/jump-once/prefetch-trace.jsonl`에 원문만 변한 수치가 남아 있다. 원문도 실제 응답으로 채우고, 읽는 스레드의 원문·최근 답글 구간이 모두 그려졌음을 측정 전에 확인하도록 시험 준비를 보완했다. 수락 판정의 허용 오차와 범위는 그대로 사용한다.
- AT-JO-12·13 수락 시험에서 프레임 간격을 1/60초로 밀고, 연속 세 표본이 멈췄을 때 이동을 구분하는 수락 관측 규칙을 적용했다. `.build/jump-once/task06-confirm-prefetch.log`에서 같은 방 15프레임, 다른 방 첫 프레임, 구간 밖 글은 도착 전 0pt·이동 1회였다. 비재시도 오류와 한도 축출 뒤의 누름도 도착 전 0pt·이동 1회였다.
- `app/Tests/TodoDrawerTests.swift`의 AT-HO-05는 갱신 상태와 앱 갱신 필요 안내를 별개로 확인한다. 수락 문서 기대값은 건드리지 않았다. 기존 AT-DI-35가 확인하는 필터 폭·좌우 경계를 복원하고 ↻를 닫기 버튼 옆 여유에 놓았다. `.build/jump-once/task06-app-review.log`에서 AT-DI-35~39 통과를 확인했다.
- 알림 두 번째 페이지 실패와 본문 축출 회귀에서 차이가 나왔다. 갱신 시작 콜백에서 제목 표지만 갱신하고, 기존에 받은 최신 쪽의 비워진 본문은 기존 화면 복원 경로에서 받도록 수정했다. `.build/jump-once/task06-review.log`에서 알림 페이지 원자성은 통과했고, `.build/jump-once/task06-restore.log`에서 본문 복원 9개 하위 시험은 모두 통과했다.
- AT-JO-10의 최근 측정값은 펼치기 2838.5pt, 확정 뒤 답글 5583pt, 방 진입 0.324pt다. `.build/jump-once/task05-stream-prefetch.log`. AT-JO-18 일반은 도중 집계 요청·표시·표시값 변화 0, 글 변화 31회, 끝난 뒤 개요 1회였다. 중간 새 글은 그 글이 들어올 때 개요 재조회, 끝 조각 없음은 재연결 후 개요 1회였다. 세 최종 집계는 기준 자료와 일치했다. `.build/jump-once/task06-review.log`.
- AT-JO-17 `.build/jump-once/task06-at-jo-17.log`. `pendingRevealScroll` 0건. `history.scrollTo` 호출은 이동 요청 실행, 펼치기 위치, 답글 전송·열기 위치, 답글 초안 복원 위치에 남았다. E1~E5에는 직접 호출이 없다.

### 구현 최종본

- 시작점 `018036cbf24678ea3a29f826926531e8ab4d370b`. 커밋 직전 `git fetch github` 종료 0, `github/main`은 같은 시작점이었다.
- 공개 브랜치 `hejo-jump-once-public-20261126`에 `git commit --only`로 다음 다섯 커밋을 만들었다.
  1. TASK-01 시험 `950181b6d5b9b68a53ea163b392bddc0eb62905c`
  2. TASK-02 이동 `755bf6407d084cb9d84f8e48c99c76984c4fe23f`
  3. TASK-03 최근 구간 미리 받기 `c36ceabf7a3da267b2a6702a76ddb12bd32265fe`
  4. TASK-04 갱신 표시·아래쪽 안내 `629df5ec07cb5a88d32d588be3565c7fc61babbd`
  5. TASK-05 답변 집계 `6e92d277805ff2a253f4fda83896d2dfa03adf4e`
- 미리 받기에서 최근 쪽 조회 뒤 원문을 별도 자동 불러오기 후보로 다시 평가한다. 카드창을 닫거나 그 카드가 범위를 벗어나면 뒤이은 원문 요청이 새로 시작되지 않는다. 요약이 없는 카드로 이동할 때는 필요하면 글 지정 없이 그 스레드만 여는 기존 요청을 쓴다. 같은 스레드의 새 이동 요청이 오면 앞 요청의 뒤늦은 응답이 그 글을 덮지 않게 했다.
- 선택으로 전체 갱신이 돌 때 같은 판의 축출된 본문은 그려질 때 기존 복원 경로로 읽는다. 최신 쪽 전체 조회와 페이지 계산은 유지한다. 준비된 다른 방의 첫 화면에서 보이는 높이가 바뀌면 그려진 대상 가운데를 따라 한 번 배치한 위치를 유지한다.
- 시험한 작업본과 커밋한 전체 패치는 `cmp`로 일치 확인했다. `git diff --check` 종료 0. 공개 작업 폴더의 `git status --porcelain=v1`은 비어 있다. `ls-remote github refs/heads/hejo-jump-once-public-20261126` 종료 0, 대상 브랜치 조회 결과 없음. 사용자 푸시 승인 대기.

### 최종 검증 및 남은 항목

| 검사 | 실제 결과 | 공개 worktree 기준 로그 |
|---|---|---|
| `bash app/Tests/HistoryTransport.sh` | 최종 작업본 빌드 종료 0 | `.build/jump-once/review-final-build.log` |
| `JUMP_ONCE_VERIFY_REFERENCE=1 python -m pytest app/Tests/HistoryAutoloadFixture.py -k jump` | 36개 중 34개 통과, 휠 대조 입력 전달과 다른 방 정착에서 2개 실패. 휠 시험 시작점을 경계에서 떼고 다른 방의 높이 변경 뒤 대상 위치를 유지하도록 보완했다. | `.build/jump-once/final-acceptance.log` |
| 위 명령의 영향 범위 `-k 'jump-input or jump-ready-other or jump-placement or jump-prefetch-delay or jump-wait-bubble'` | 종료 0, 10개 통과. 실제 휠·클릭·방향키 여섯 실행의 대조 최대 차이 0pt. 미준비 휠 실행은 원점 80pt 이동도 관측. 다른 방 첫 화면 0pt·갱신 뒤 0.081pt. 펼치기 2838.5pt·전송 5583pt·방 진입 0pt로 각각 기준 ±1pt. | `.build/jump-once/review-final-acceptance.log` |
| AT-JO-11~13과 18 | 범위 안 11/11, 밖과 닫은 뒤 새 요청 0, 기존 구간·원점·표시 위치 유지(0.5pt 이내). 오류와 축출 입력은 각각 의도한 미준비 상태에서 누름을 검증했다. 일반 스트림 중 집계 요청·표시 0과 글 변화 31, 끝 조각 뒤 개요 1. 중간 새 글과 재연결 갱신 포함 세 최종 집계 기준과 일치. | `.build/jump-once/final-acceptance.log`, `.build/jump-once/review-final-acceptance.log` |
| 기존 기록 하네스 회귀 | 일반 82개, legacy 모드 1개, 파일 등록 1개로 84개 모두 통과. 최종 레이아웃 변경까지 포함한 위험 회귀(축출 본문 9개 및 알림 페이지 원자성) 10개 재실행 종료 0. | `.build/jump-once/final-transport.log`, `.build/jump-once/final-legacy.log`, `.build/jump-once/final-attachment-registration.log`, `.build/jump-once/review-final-restore.log` |
| `bash scripts/test.sh` | Python 단계 593개 통과, 종료 1. 착수 기준과 동일한 `test_at_hf_27_install_twice_and_check` 1건(영수증 mtime). `python -m gate.tests.gateway_delivery` 별도 실행 종료 0. | `.build/jump-once/task06-scripts.log`, `.build/jump-once/task06-delivery.log` |
| `bash app/scripts/test.sh` | 짧은 임시 경로와 기존 Python 라이브러리로 앱 UI, 네트워크, 소유자 프로필 4개 및 Wait Jitter까지 통과했다. 스크립트는 실제 hejo 설정 메타데이터 가드에서 종료 1. 메타데이터의 변경 시각 21:27:55, 앱 시험 실행 파일 생성 21:29:23으로 시험 앱 실행보다 앞서 있었다. 같은 시간 운영 hejo 앱이 실행 중임을 확인했다. 실제 파일 내용은 이 비교에 사용하지 않았다. | `.build/jump-once/task06-app-isolated.log`, `.build/jump-once/task06-settings-timing.log` |
| `python3 scripts/scan_private.py --home <가짜 명부의 임시 홈>` | 종료 0. | `.build/jump-once/final-scan.log` |

- 기준본의 +32pt 이동 원인 재현 `.build/jump-once/baseline-v5-wait-trace.jsonl`. 원문 자리표시자만 높이가 달라진 시험 준비 진단 `.build/jump-once/prefetch-placeholder-trace.jsonl`.
- AT-JO-14·15의 표시 위치와 접근성을 확인했다. 준비된 글 재조회 0, 정착 뒤 거리 0pt, 세 안내 위치 차이 0pt, 다시 시도 개요 1건. PNG 세 장은 `.build/jump-once/refresh.png`, `.build/jump-once/failure.png`, `.build/jump-once/drawer-read-failure.png`. 각 900×700. 사용자 화면 확인과 독립 판정은 인계 대상이다.

### 검증 4회차 처분

기준은 공개 작업 트리의 `6e92d277805ff2a253f4fda83896d2dfa03adf4e`와 검증 4회차 판정이다. 수락 기준과 0.5pt 허용 오차를 유지했다.

- **V-1** `app/Tests/HistoryAutoloadHarness.swift`에서 대조 실행의 입력 직전 원점을 `controlOrigin`과 대조한다. `HistoryJumpInputHarness.swift`는 실제 목록 리더 입력 콜백을 확인한다. 휠은 운영체제의 전역 커서로 창을 찾던 경로 대신 Core Graphics 휠 이벤트를 AppKit 목록의 `scrollWheel` 처리 경로에 전달한다. 스크롤이 다음 실행 루프에서 적용된 뒤 실제 원점이 80pt 바뀌었는지 확인한다. 클릭·방향키는 AppKit 창 이벤트와 목록 콜백을 모두 확인한다. 전달·원점 확인이 실패하면 시험 준비 오류다. `HistoryAutoloadFixture.py`는 두 궤적의 최대 차이가 0.5pt 이내인지를 환경 변수와 관계없이 판정한다.
- **V-2** `app/Sources/ConversationView.swift`의 `entry()`에서 중복 취소 호출 한 줄을 제거했다.
- **V-3** `app/Tests/HistoryAutoloadHarness.swift`의 AT-JO-11에서 오류·축출 목적의 입력은 `기록`으로 표시한다. 일반·지연 입력은 기존 판정을 유지한다.
- **V-4** `app/Sources/HistoryCoordinator.swift`에서 이동 요청의 글을 보존하는 조건에 요청이 처리된 세션을 포함했다. 새 세션에는 선택 스레드의 최신 쪽 조회가 나간다. `jump-status`에서 정착 뒤 연결을 끊고 가짜 서버에 답글을 추가한다. 다시 연결할 때 기존 대상 글을 메모리에 넣어 보존 조건이 발동할 수 있는 상황을 만들고, 최신 쪽 응답과 화면에 새 답글이 있는지 확인한다. 기존 AT-JO-14의 글 유지·재조회·표시 판정도 같은 실행에서 확인한다.

자체 시험 로그는 공개 worktree의 `.build/jump-once/v1-fix/`에 있다. pytest는 짧은 임시 경로를 사용했다.

| 확인 | 실제 결과 | 로그 |
|---|---|---|
| `HEJO_HISTORY_SPARKLE=… bash app/Tests/HistoryTransport.sh` 및 `--legacy` | 양쪽 종료 0 | `build.log`, `legacy-build.log` |
| `pytest app/Tests/HistoryAutoloadFixture.py -k jump` (`JUMP_ONCE_VERIFY_REFERENCE=1`) | 종료 0, 36개 통과. 기존 AT-JO-14 대상 재조회 0건, 목표 오차 0pt. 새 세션 최신 쪽 요청 1건과 끊긴 사이 답글 표시를 확인했다. 오류·축출의 AT-JO-11 출력은 `기록`이다. | `acceptance.log` |
| 같은 pytest에서 `-k 'not jump'` | 종료 0, 기존 회귀 37개 통과 | `regression.log` |
| 미준비 휠·클릭·방향키와 준비된 휠 각 10회 | 기준본 대조 환경 변수 없이 40회 전부 통과, 최대 궤적 차이 0pt. 모든 실행에서 입력 종류와 두 시작 원점을 기록했다. | `input-repeat-01.log`~`input-repeat-10.log` |
| 시험 준비 및 판정 실패 대조 | 임시 시험 사본의 대조 원점을 범위 밖으로 지정하면 시험 준비 오류로 종료 1. 생긴 궤적 차이를 1pt로 넣으면 기준본 대조 환경 변수 없이 판정 오류로 종료 1. | `origin-probe.log`, `difference-probe.log` |
| 재연결 보완 전 재현 | 이전 제품 코드 `6e92d277805ff2a253f4fda83896d2dfa03adf4e`에 새 시험을 실행해 종료 1. 재연결 뒤 최신 쪽 요청과 새 답글 표시를 확인하는 검사에서 실패했다. | `reconnect-before.log` |
| `python3 scripts/scan_private.py --home <가짜 명부의 임시 홈>` | 종료 0 | `scan.log` |

수정 커밋은 공개 브랜치 `hejo-jump-once-public-20261126`의 `708a6dadf22f0840c4a07195e8f5647e856433ad`다. `git commit --only`로 다섯 경로를 커밋했다. 시험한 패치와 커밋 패치의 `cmp`, `git diff --check`는 종료 0이고 공개 작업 트리는 깨끗하다. 검증 5회차와 기존 PNG 사용자 확인이 남았다.
