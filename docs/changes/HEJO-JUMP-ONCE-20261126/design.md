# HEJO-JUMP-ONCE 설계

- 4판 · 적용(공개판 `708a6da`, V-4로 3.2 글 보존을 같은 연결 안으로 한정)(검증 2회차 GAP-JO-02, 사용자 결정 D-11 반영) · 2026-11-26 · 짝: [spec.md](spec.md) 4판

## 1. 칸·원본·쓰기 주체·수명

| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 이동 요청과 목록 위치 | 관제 화면(hejo 앱) | `app/Sources/ConversationView.swift`, `NativeThreadList.swift` | 개발 | 갱신 때 교체 |
| 미리 받기 대상 목록 | 관제 화면(hejo 앱) | `app/Sources/HistoryCoordinator.swift` | 개발 | 갱신 때 교체 |
| 갱신 표시·안내 줄 | 관제 화면(hejo 앱) | `app/Sources/TodoDrawerView.swift`, `ConversationView.swift` | 개발 | 갱신 때 교체 |
| 실시간 조각이 집계 갱신을 일으키는 조건 | 관제 화면(hejo 앱) | `app/Sources/ConversationController.swift`(`onHistoryFrame`), `ConversationModel.swift`(`apply`) | 개발 | 갱신 때 교체 |
| 미리 받은 본문 | 기존 기록장 조회용 캐시 | 앱 메모리(`ConversationModel.history`) | 앱 | 지워도 다시 받음 |

새 칸·두 번째 원본·새 저장 위치·새 설정 없음. `docs/ARCHITECTURE.md` 8절의 다섯 질문은 [brainstorm.md](brainstorm.md)에 답했다.

## 2. 현황(`github/main` `2dea766` 기준)

| 사실 | 근거 |
|---|---|
| E1은 `reveal` → `historyLoading.open(key,anchor:)` → `refresh()` → `history.scrollTo(key.thread)` 순서다. 목적지는 스레드 카드 가운데 | `ConversationView.swift:18-26` |
| 본문 도착 뒤 `onAnchor`가 `history.scrollTo(key.thread,message:id,bottom:)`를 다시 부른다. 목적지는 글 가운데 | `ConversationView.swift:253`, `HistoryCoordinator.swift:288` |
| `scrollTo` 한 번은 0·0.15·0.45초에 각각 감속 이동(0.24초)을 새로 시작한다. 그동안 `positioningRevision`으로 위치 유지 보정을 막는다 | `NativeThreadList.swift:542-570`, `WorkspaceViews.swift:153-161` |
| E2·E5(전량 수신)·`openFromBubble`은 `scrollTo(thread)`를, E4·E5(기록 모드)는 `historyLoading.open`만 부르고 `onAnchor`에 기댄다 | `ConversationView.swift:313-315, 539-545, 572-602` |
| 방이 바뀌는 열기는 `openingEntry` → `history.enter(thread)`로 감속 없이 놓는 길이 따로 있다 | `ConversationView.swift:526-538, 703` |
| 선택·입력이 바뀌면 조정자가 작업을 취소하고 `demands`를 비운 뒤 전체 갱신을 시작한다 | `HistoryCoordinator.swift:324-347` |
| 갱신은 `history.refreshing`을 켠다. 새 문맥을 시작해도 받은 값은 화면에 남고 스레드 쪽 커서만 비운다 | `HistoryCoordinator.swift:490, 559`, `HistoryProjection.swift:72-76` |
| 갱신이 선택 스레드의 최신 쪽을 다시 받아 덮는다. 글 지정 열기(`.open(key, 글)`)가 대기 중일 때만 건너뛴다 | `HistoryCoordinator.swift:544-550` |
| 자동 불러오기는 보이는 방(scope)의 대상만 받고, 요약이 있어야 한다 | `HistoryCoordinator.swift:49-54, 75-93` |
| 카드창 경고는 카드 묶음 맨 앞에 줄로 들어간다. 아래쪽에는 되돌리기 줄(`footer`)이 이미 있다 | `TodoDrawerView.swift:77-79, 93-100` |
| 대화 목록 상태 줄은 카드 배열 맨 앞에 들어간다 | `ConversationView.swift:783-786, 1555-1559` |
| 왼쪽 방 목록은 이미 줄을 끼우지 않는 표시(↻)를 쓴다 | `ConversationChrome.swift:90-103` |
| [3판 추가, `018036c` 기준] 기록장 실시간 프레임은 종류와 관계없이 `model.apply`가 `history.refreshing = true`로 하고, `onHistoryFrame`이 `historyLoading.liveChanged()`로 새 문맥과 집계 전체 갱신을 시작한다. 직원 답이 써지는 동안 문은 조각마다 `edit` 프레임(`final:false`)을 보낸다 | `ConversationModel.swift:740-766`, `ConversationController.swift:543-548`, `HistoryCoordinator.swift:351`, `gate/adapter.py:405, 454` |
| [4판 정정] 써지는 중 조각은 서버 집계를 바꿀 수 있다. "생각 중…" → 본문이면 안 읽음·종·알림·알림 만료·제목, 본문 → 승인 요청 문구면 질문·`assessment`·기다리는 버튼 수가 바뀐다. 안 읽음은 `thinking` 여부만 보고 `final`을 보지 않는다 | `gate/history_queries.py:20-91, 146, 180-195`, 구현 진단 `.build/jump-once/g3-baseline.log`(검증 2회차) |
| [3판 추가] 스레드는 답글을 이어진 한 구간만 그린다. 글 지정 열기는 구간을 교체하고 구간 밖 글을 지운다. 본문만 넣으면 구간 순서는 그대로다 | `ConversationModel.swift` `historyReplyIDs`·`applyHistoryMessages`·`mergeHistoryReplyPage`·`applyHistoryBody`, 검증 1회차([verdict.md](verdict.md)) |

## 3. 목표 구조

### 3.1 이동 요청은 한 곳(REQ-JO-01, NFR-JO-01)
- `ConversationView`가 **이동 요청 하나**(대상 스레드, 글 id 선택, 강조 여부)를 가진다. 모든 이동 입구(E1~E5)는 이 요청을 세우기만 하고 `history.scrollTo`를 직접 부르지 않는다. 새 요청은 이전 요청을 지운다(AC-05).
- 요청은 대상이 **그려진 뒤**(목록 배치에 그 글의 틀이 있을 때) 한 번 실행하고 지운다. 그 판단은 `refresh()`가 목록을 그린 직후 한 곳에서 한다. `onAnchor`는 이동을 직접 부르지 않고 "받기 끝남"만 알려 같은 판단을 다시 돌린다.
- 준비 안 됨: 요청을 "글 대기"로 남기고 **움직이지 않는다**(스레드 카드로 먼저 가지 않는다). 대상 글이 그려지면 대상 글로 한 번 이동하고 지운다(AC-02). 받기가 실패로 확정되면 그때 스레드 카드로 한 번 이동하고 지운다. 카드도 없으면 그냥 지운다(AC-06).
- 리더 입력(휠·클릭·방향키, 목록의 기존 입력 감시)은 이동 중이든 글 대기 중이든 요청을 지운다. 뒤늦게 온 본문은 요청을 되살리지 않는다(AC-04).
- 다른 방: 방을 바꾸는 열기는 기존 `openingEntry`/`history.enter` 길을 써서 첫 화면부터 대상에 놓는다(AC-07). `enter`가 글 id를 받아 글 가운데에 놓도록 넓힌다.
- `NativeThreadList.scrollTo`는 **한 번의 이동**이 된다. 0·0.15·0.45초 세 번 시작을 없애고, 감속 이동 하나가 매 프레임 대상의 지금 틀로 목적지를 다시 잡는다(이동 중 높이 변화, AC-03). 도착하면 대상을 기준점으로 하는 기존 위치 유지(`keep`)에 넘긴다. 리더 입력·새 요청이면 그 자리에서 끝난다(기존 `userScrolls`·`scrollRevision` 규칙).
- 최종 위치 규칙(`scrollOrigin`)은 그대로다. 답글 보내기의 `replyPlacement`, `chooseThread`의 `bottom:true`도 같은 한 번 이동을 쓰며 최종 위치는 같다(AC-10).

### 3.2 카드 대화 미리 받기(REQ-JO-02, 최근 쪽만)
- `HistoryCoordinator`에 **카드 대상 목록**(스레드, 글 id)을 넘기는 입구를 하나 둔다. 넘기는 쪽은 카드창을 그리는 곳(`ConversationView`가 `todoDrawer.show`를 부르는 자리)이며, 카드창이 보일 때 받는 범위(카드창)의 카드만 넘긴다. 카드창이 닫히면 빈 목록을 넘긴다.
- 조정자는 이 목록을 기존 자동 불러오기 순서의 **맨 뒤**에서 처리한다(보이는 대화의 자동 불러오기와 사용자 요청이 먼저). 방(scope) 제한 없이 받는다. 대상 하나의 처리는 다음 둘뿐이다.
  1. 스레드에 원문이나 답글 구간이 없으면: 기존 자동 불러오기의 스레드 열기(`AutoLoad.thread`, 글 지정 없는 `resolve` + 원문)와 같은 요청으로 **최근 쪽**을 받는다.
  2. 대상 글이 그 구간 안인데 본문이 없으면(`contentRef`만 있음): 기존 `AutoLoad.content`로 본문만 채운다.
  대상이 구간 밖이면 아무것도 받지 않는다. 글 지정 열기(`.open(key, 글)`)는 미리 받기에서 쓰지 않는다(GAP-JO-01, D-08).
- 부작용 금지: 선택·읽음·알림 확인·`historyOpenAnchor`·자동 붙임 표시(`automaticAppends`)를 건드리지 않는다. 이미 구간이 있는 스레드의 구간을 바꾸지 않는다(AC-02, AC-10).
- 실패·대기 상태는 기존 `loadStates` 규칙을 쓴다(같은 연결·같은 판에서 한 번, 실패는 조용히). 조정자의 `failure`·`showProgress`에 올리지 않는다(AC-06, AC-08).
- 누른 뒤: 대상이 준비됨이면 3.1대로 바로 한 번 이동. 구간 밖이면 3.1의 "준비 안 됨"(글 대기, 기존 글 지정 열기로 받은 뒤 한 번 이동).
- 누른 뒤 갱신에서 지키기(AC-09): 준비된 대상으로 열었으면 갱신이 선택 스레드의 최신 쪽으로 덮어 대상 글을 빼지 않도록, 글 지정 열기 대기와 같은 건너뛰기 조건을 "이동 요청의 대상 글이 그 스레드에 그려져 있는 동안"으로 넓힌다. 선택이 바뀌어 작업을 취소해도 받은 본문은 지우지 않는다(지금도 남는다. 시험으로 고정).
- 메모리: 기존 `HistoryResidentBudget`만 따른다. 미리 받은 본문은 고정(pin)하지 않는다.
- 다른 방 첫 화면(AC-04): 방의 스레드 목록이 아직 없으면 대상 스레드만 먼저 그리고(G-1 확인됨), 나머지가 오면 기존 위치 유지로 대상을 붙든다.

### 3.3 갱신 표시와 안내(REQ-JO-03)
- 카드창: `Snapshot.warning`에서 "갱신 중"을 떼어 `historyUpdating` 값만 남긴다. 표시는 카드창 제목 줄(필터 줄) 오른쪽의 작은 ↻이며 카드 묶음에 줄을 넣지 않는다. 나머지 글 안내는 기존 `footer`가 있는 아래쪽 고정 영역으로 옮긴다.
- 대화창: `history-status` 카드를 목록에 넣지 않는다. 갱신 중은 대화창 제목 줄의 ↻, 실패는 목록 위에 떠 있는 아래쪽 줄(목록의 보이는 높이를 바꾸지 않음)과 "다시 시도".
- 표시는 왼쪽 방 목록의 기존 ↻와 같은 글자·색을 쓴다.

### 3.4 써지는 중에는 전체 갱신 안 함(REQ-JO-04)
- 판단은 프레임을 받는 한 곳에서 한다. 써지는 중 조각(`type == "edit"`, `final == false`)이면 `ConversationModel.apply`는 본문·판(revision)·캐시 무효화는 지금처럼 하되 `history.refreshing`을 켜지 않고, `onHistoryFrame`은 `historyLoading.liveChanged()`를 부르지 않는다. 같은 판단을 두 곳에 따로 두지 않도록 "이 프레임이 집계를 바꾸는가"를 모델의 함수 하나로 두고 두 곳이 그것을 쓴다.
- 그 밖의 프레임(새 글, `final:true` 또는 `final` 없는 `edit`, `state`, 삭제, 방)은 지금처럼 갱신을 일으킨다. 진행 중 갱신 뒤 한 번으로 모이는 기존 동작(`dirty`)을 그대로 쓴다. 새 지연 시간 상수는 두지 않는다.
- 써지는 중에 바뀌는 집계(2절 4판 정정 행)도 끝 조각 뒤 갱신에서 한 번에 맞춘다(사용자 결정 D-11). 앱은 서버의 "생각 중"·승인 요청 판정을 흉내 내 갱신 여부를 정하지 않는다(판정 원본은 문 하나). 끝 조각이 오지 않으면 다음 갱신 사유(새 글·상태·삭제·방 프레임, 선택 변경, 다시 연결)에서 맞춰진다.

## 4. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| 입구가 직접 부르는 `history.scrollTo`(E1·E2·E3·E5) | 교체 | 이동 요청으로 바꾸고 직접 호출을 같은 변경에서 지운다 |
| `onAnchor` → `scrollTo` | 교체 | 이동 요청 재판단으로 바꾼다. 답글 열기(`pending:`)의 위치 잡기는 유지 |
| `pendingRevealScroll` | 통합 | 이동 요청에 합치고 지운다 |
| `scrollTo`의 세 번 시작 | 교체 | 목적지를 따라가는 한 번 이동. `positioningRevision`은 그 이동의 수명으로 맞춘다 |
| `openingEntry`/`history.enter` | 유지(넓힘) | 글 id를 받는다 |
| 카드창 경고 줄 삽입 | 교체 | 표시와 아래쪽 줄. 줄 삽입 코드 제거 |
| `historyStatusContent`와 `history-status` 카드 | 제거 | 표시와 아래쪽 줄로 대체. 이 카드를 기대하는 시험은 새 기준으로 고친다(수락 시험 "기준본 기대" 참고) |
| 자동 불러오기(`loadingTargets`) | 유지 | 카드 대상은 별도 목록, 같은 실행 고리. 카드 대상 처리는 기존 `AutoLoad.thread`·`.content`를 재사용 |
| 실시간 프레임마다 `liveChanged`·`history.refreshing = true` | 교체 | 써지는 중 조각은 제외. 판단 함수 하나를 두 호출부가 공유 |
| 선택 변경 때 전체 갱신 | 유지 | 범위 밖 |

## 5. 유지할 계약
- 문과의 통신(요청 종류·필드), 기록장 형식, 캐시 형식.
- 스크롤 최종 위치 규칙, 리더 입력 우선, 따라가기, 끝 거리 유지, 기록 기준점(HEJO-WAIT-JITTER·HEJO-AUTOLOAD의 수락 기준).
- 카드 누름의 읽음·알림 확인·강조 동작, 카드창 카드 내용·정렬.
- 자동 불러오기의 받는 범위·중복 없음·실패 표시(HEJO-AUTOLOAD).

## 6. 대안
- **A(채택)** 이동 요청 하나 + 한 번 이동 + 카드 대상 미리 받기 + 자리 없는 표시.
- **B(기각)** `scrollTo` 호출 수만 줄이고(입구 호출 제거) 세 번 시작은 유지: 목적지는 하나가 되지만 높이가 바뀌면 0.15·0.45초 보정이 다시 보인다.
- **C(기각)** 선택 변경 때 전체 갱신을 없애 원인을 제거: 기록 조정자의 문맥 규칙을 바꿔야 해 위험이 크고, 표시가 자리를 밀지 않으면 화면에 드러나지 않는다.
- **D(기각)** 미리 받기 없이 캐시 파일에서만 채우기: 처음 보는 대화는 여전히 기다린다.
- **E(기각, 사용자 D-08)** 구간 밖 대상의 글 주변 쪽을 따로 보관했다가 누를 때 적용: 모든 카드가 바로 이동하지만 읽음이 바뀔 때마다 보관분이 무효가 되고 새 저장 자리·유효성 규칙이 필요하다.
- **F(기각)** 실시간 조각마다의 갱신을 시간으로만 묶기(예: 1초에 한 번): 갱신 횟수는 줄지만 써지는 동안 표시가 계속 깜빡이고 집계가 바뀌지 않는 요청이 남는다.
- **G(기각, 사용자 D-11)** 의미가 바뀌는 조각("생각 중" → 본문, 버튼·질문 붙음)에서만 추가 갱신: 숫자가 빨리 뜨지만 앱이 문의 판정 규칙을 흉내 내야 해 두 번째 원본이 생기고, 글로만 쓴 승인 요청은 결국 끝 조각까지 늦는다.

## 7. 실패·경계
- 대상 글 없음: 3.1의 실패 경로. 안내는 3.3의 아래쪽 줄.
- 연결 끊김 중 누름: 준비됐으면 그대로 이동, 아니면 움직이지 않고 글 대기로 둔다. 다시 연결돼 글이 그려지면 한 번 이동하고, 받기가 실패로 확정되면 3.1의 실패 경로를 탄다. 그 사이 리더 입력이 있으면 요청은 지워진다.
- 미리 받기 중 선택 변경: 작업이 취소되면 남은 대상은 다음 고리에서 다시 고른다(중복 요청 규칙 유지).

## 8. 가정과 멈춤 조건
- [확인 G-1] 방의 스레드 목록이 없어도 대상 스레드 하나를 먼저 그릴 수 있다(검증 1회차, 구현 진단).
- [G-2 불성립 → 3판에서 설계 변경] 미리 받기는 구간을 바꾸지 않고, 구간 밖 대상은 누른 뒤 받는다(3.2, GAP-JO-01, D-08).
- [G-3 불성립 → 4판에서 요구 조정] 써지는 중 조각도 집계를 바꾼다(GAP-JO-02). 그 변화는 끝 조각 뒤로 미룬다(D-11, 3.4). TASK-05의 시작을 막는 가정은 더 없다.
- [미확정→TASK-01에서 확인] 누름 한 번에 갱신이 몇 번 도는지, 그때 `demands`가 비워져 글 지정 열기가 사라지는 경우가 있는지. 기준본 기록으로 확인하고 design 2절에 덧붙인다.
