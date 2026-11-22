# HEJO-DRAWER-INLINE 설계

상태: 4판(2.6) 구현 대기 · 1~3판 적용(2026-11-23) · 3판 · 2026-11-23(REQ-DI-07 로고·버전 가운데 추가, 사장 요청) · 2판 · 2026-11-22(계획 검증 1회차 R1·R2 반영, [plan-review.md](plan-review.md)) · 명세 [spec.md](spec.md) · 칸 표는 [spec 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 기준 커밋 main `0644e9e`. 착수 때 HEJO-DEADLINE-CLOSE TASK-03 반영 뒤 기준으로 다시 확인한다(handoff 0항).

## 1. 지금 흐름 [확인]

```
PetController.placePet
  → PetLayout.paneSplit(available = 화면폭-24)           # 웹 칸 폭
  → PetPlacement(init …, trailing: 웹칸, leading: 290)   # 채팅 자리
      → withLeading: 왼쪽으로 290 붙임 / 모자라면 펫+창 오른쪽으로 비킴 / 그래도 안 되면 drawerOverlay
  → stepPlacement: shownLeading(움직임 중 드러난 폭) → apply → PetView.arrange
PetView.arrange: conversationContent(=ConversationView) x = leading, 폭 = 창-웹칸-leading
                 todoDrawer(PetView에 따로 꽂힘) x = leading-290 또는 0(덮기), drawerScrim
TodoDrawerView.draw: 대화 창 덮개 색을 알파 1로 칠함 (PetView.updateScrim이 색을 넣음)
```
근거: `PetController.swift:31-49,303,308,312-342`, `PetLayout.swift:168-186,199-202,237-278`, `PetView.swift:90-94,232-238,350-358`, `TodoDrawerView.swift:5-31,111-116`.

## 2. 바뀐 흐름

```
PetController.placePet
  → drawer = (drawerOpen && chatExpanded) ? 290 : 0
  → PetLayout.paneSplit(base, minimumBase, wanted, available = 화면폭-24-drawer)   # 칸 몫을 먼저 뺀다
  → PetPlacement(init …, trailing: 웹칸, drawer: drawer)
      → 닫힌 상태 자리 계산(지금 그대로) 뒤 오른쪽으로 drawer만큼 넓힘
        오른쪽 여백 넘으면 넘는 만큼 창+펫 왼쪽으로 옮김(drawerShift, anchorOrigin에서 되돌려 저장 위치 불변)
  → stepPlacement: shown = 움직임 중 드러난 칸 폭(0…290) → apply → PetView.arrange
PetView.arrange: ConversationView x = 0, 폭 = 창-웹칸 ; ConversationView.drawerShownWidth = shown
ConversationView.layout: [방 목록 sidebarWidth][칸 shown][채팅 칸 나머지]
ConversationView.draw: 칸 열 바탕 = SidebarTone(방 목록과 같은 값), 칸 오른쪽 1px 선
TodoDrawerView: 배경 칠하지 않음(투명), 카드 색만 그림
```

### 2.1 배치 계산 (`PetPlacement`, `PetController`)
- 칸 폭의 판정은 `PetPlacement` 한 곳이 갖는다. 새 이름은 구현 자유(예: `drawer`, `withDrawer(_:visibleFrame:)`, `drawerShift`).
- 계산 순서
  1. 닫힌 상태의 `globalBubble`(웹 칸 포함)과 `globalSprite`를 지금 규칙 그대로 구한다.
  2. 넓힌 창 = 같은 `minX`, 폭 + `drawer`.
  3. `over = 넓힌 maxX - (visible.maxX - 12)`. `over > 0`이면 `shift = min(over, 닫힌 minX - (visible.minX + 12))`만큼 창과 펫을 왼쪽으로 옮긴다(`shift ≥ 0`). `over == 0`이면 옮기지 않는다(REQ-DI-03 AC-03).
  4. 채팅 좁히기(REQ-DI-04 AC-01)는 `placePet`의 `paneSplit`이 맡는다: `available`에서 칸 몫을 뺐으므로 `kept = min(base, available)`가 채팅(방 목록 포함) 폭을 줄인다. 그래서 2번 폭은 보통 가시 영역 안쪽에 들어간다. 그래도 넘으면(예: 끌기 경로처럼 `paneSplit`을 거치지 않는 호출) 창 폭을 `visible.width - 24`로 자르고 잘린 만큼은 채팅 칸이 내준다. 칸 폭 290은 줄이지 않는다.
- `anchorOrigin`은 지금처럼 임시 옮김(`drawerShift`)을 되돌려 계산한다(방향만 반대). 그래서 `petX`·`petY`는 열고 닫아도 같다(REQ-DI-03 AC-02).
- 채팅 끌기(`moveChatDrag`)는 끌린 닫힌 자리에 같은 넓힘을 다시 적용한다(지금 `withLeading` 자리). 끌기 중 기준 상자는 칸을 뺀 상자(아래 크기 조절과 같은 정의)다.
- 크기 조절(`PetController.resize`, `PetLayout.resized`)은 **기존 계약 보존**(REQ-DI-04 AC-04). 지금 `resize`가 `start.contentBubble`(칸을 뺀 상자)로 `chatStart`를 만들어 `resized`에 넘기는 구조를 그대로 두고, 그 상자만 새 정의(열린 상자에서 오른쪽 `drawer`를 뺀 상자, 같은 `minX`, 옮겨진 펫과 함께)로 바꾼다. 웹 칸 오른쪽 끝 끌기의 `resizeStart!.contentBubble.width - paneBase`도 같은 상자를 쓴다. `resized`의 가운데 기준 식(`2*(target-center)`)은 건드리지 않는다. 저장되는 `chatWidth`에는 칸 폭이 들어가지 않는다(REQ-DI-04 AC-03).
- 움직임: 지금처럼 `bubbleMotion.slideWidth` + retarget, 0.25초. 동작 줄이기면 즉시.
- 드러난 폭 `shown`(2판, R1): 창 폭에서 역산하지 않는다(지금 `shownLeading` 역산식 `size.width-(target.width-target.leading)`은 좁은 화면에서 창 폭 변화가 290보다 작아 열기 시작 190·닫기 시작 100으로 건너뛴다 — 제거). 대신 여닫기 시작 때 그 순간의 `shown`을 `s0`으로, 목표(`drawer`, 290 또는 0)를 `s1`로 적어 두고 `shown = s0 + (s1 - s0) * eased`로 계산한다. `eased`는 `BubbleMotion.step`이 창 크기에 쓰는 것과 같은 값(`widthProgress`의 smoothstep, `PetLayout.swift:367-368`)이어야 창 폭과 칸 폭이 함께 움직인다 — `BubbleMotion`이 이 값을 내보내게 하거나 같은 함수를 공용으로 쓴다(식 복사 금지). 움직임이 없을 때(끌기·창 옮김·웹 칸 변화 등)는 `shown = 목표 drawer`. 도중 다시 누르면 그때의 `shown`이 새 `s0`.
- 그래서 채팅 칸 폭 = 대화 보기 폭 - 방 목록 - `shown`이 시작 값에서 끝 값으로 연속해서 바뀐다(좁은 화면에서는 채팅 칸이 움직이는 동안 줄었다 늘었다 한다).
- `ChatWidthSlide` 덮개(웹 칸용)는 칸 여닫기에서 쓰지 않는다(지금과 같음).

### 2.2 대화 보기 안 배치 (`ConversationView`)
- 칸(`todoDrawer`)은 `ConversationView`의 하위 보기로 둔다. `PetController.installDrawer`는 보기를 `PetView`에 꽂지 않고 콜백 배선만 한다.
- `drawerShownWidth`(이름 구현 자유)를 받아 `layout()`의 `x`(지금 `x=left`)를 `left + shown`으로, `right`를 그만큼 줄인다. 채팅 머리·글 목록·공지·입력 줄·첨부·끌기 손잡이 등 `x`/`right`를 쓰는 모든 프레임이 함께 옮겨진다.
- 칸 보기 프레임: `x = left`, `폭 = shown`, `y = 0`, `높이 = bounds.height`. 칸 안 쌓기 보기는 폭 290(`PetController.drawerWidth`)로 배치하고 보기 경계에서 잘라 보인다(움직이는 동안 다시 줄바꿈 없음, REQ-DI-02 AC-03). `shown == 0`이면 숨긴다.
- `draw`: 지금 `sidebarWidth`를 기준으로 그리는 머리 줄·공지 띠·구분선은 `left + shown` 기준으로 옮긴다. 칸 열 `[left, left+shown]`에는 방 목록 바탕과 같은 `SidebarTone.primary(dark ? 0.035:0.025)`(높이 범위도 방 목록 바탕과 같게)와 오른쪽 끝 1px `SidebarTone.primary(0.1)`을 칠한다. 방 목록 바탕 값을 복사하지 말고 한 곳(예: `SidebarTone`의 이름 붙은 값)을 둘이 같이 쓴다.
- 방 목록 너비가 0이면 칸이 맨 왼쪽에 붙는다(REQ-DI-01 AC-02).

### 2.3 칸 그리기 (`TodoDrawerView`)
- `backgroundColor`, 불투명 `draw`, `isOpaque = true`, 테마 바뀜 관찰의 배경 목적을 없앤다. 테마 바뀜 때 카드 다시 그리기는 유지한다.
- 카드(`TodoDrawerCardView.draw`)
  - 모든 카드: 바탕 `labelColor` 알파 0.035 수준, 테두리 `SidebarTone.primary(0.1)` 1px, 모서리 10.
  - 선택: 테두리 굵기 그대로, 바탕을 `controlAccentColor` 알파 `dark ? 0.22 : 0.12`로 채운다(방 목록 선택 행 `ConversationChrome.swift:46`과 같은 값 — 숫자를 복사하지 말고 공용 값으로 뽑아 둘이 쓴다).
  - 급함: 배지 글자만 `systemRed`. 다른 글자 색은 지금 그대로.
- HEJO-DEADLINE-CLOSE TASK-03이 이 파일에 넣은 것(출처·없음 표시, 우클릭 메뉴, 숨김)은 그대로 둔다.

### 2.4 `PetView`
- `todoDrawer`, `installDrawer`, `drawerScrim`, `drawerOpen`(칸 표시 판단용이면), `updateScrim`의 칸 색 설정, `arrange`의 칸·덮개 프레임 줄을 없앤다. `arrange`는 `conversationContent`를 `x = 0`, `폭 = 창 - paneWidth`로 둔다.
- Esc로 닫기(`panel.onCloseDrawer`, `PetView.swift:7,18`)는 유지한다.

### 2.5 로고·버전 가운데 (3판, REQ-DI-07)
- 원본: `ConversationView`의 `brand`·`version` 라벨과 `layout()`의 프레임 한 곳. 프레임은 지금처럼 방 목록 열 폭 전체(`x:0, width:left`)로 두고, 글자 정렬을 실제로 가운데로 만든다(예: 로고 attributed string에 가운데 문단 스타일을 넣음). 프레임을 글자 폭에 맞춰 직접 계산하는 방식도 되지만 정렬 원본은 하나만 둔다.
- 할 일 칸과 무관하다(칸은 방 목록 오른쪽에 붙으므로 방 목록 열 폭이 바뀌지 않음).

### 2.6 고정 머리·필터 토글 (4판, REQ-DI-08·09)
- `TodoDrawerView`가 세 영역을 직접 배치한다: 제목 띠(위 44), 필터 띠(그 아래 44), 스크롤 영역(나머지, 맨 아래는 되돌리기 바닥 줄). 제목·필터는 `scroll`의 문서 보기(`stack`) 밖 고정 보기로 옮기고, `stack`에는 안내 줄·빈 상태·묶음·카드만 둔다. 세 영역 모두 폭 290(`PetController.drawerWidth`)으로 배치해 일부만 드러날 때 잘려 보인다.
- 띠 아래 선은 `ConversationView.draw`가 방 목록·채팅 머리 선에 쓰는 같은 값(`SidebarTone.primary(0.1)`)을 쓴다. 칸 열 바탕은 지금처럼 `ConversationView.draw`가 칠하고 띠에 따로 불투명 바탕을 칠하지 않는다.
- 필터 토글은 "답글 / 새 대화" 토글의 그리기 원본을 재사용한다: 트랙은 `ConversationView`의 `modeBackground`와 같은 값(`labelColor` 알파 0.1, 모서리 = 높이/2 수준, 안쪽 2pt), 칸은 `ComposerButton(mode:true)`의 `chosen` 그리기. 트랙·칸 크기 규칙을 새로 숫자로 복사하지 말고 두 곳이 쓰는 공용 값(예: 트랙 그리는 작은 보기 또는 공용 상수)으로 뽑는다. 글자 크기는 토글과 같은 11pt.
- 옛 `TodoDrawerButton` 필터 글자(10pt, 강조색 글자만)는 제거한다(교체). "‹ 접기"는 지금 단추 그대로 제목 띠로 옮긴다.

## 3. 대안
| 대안 | 판정 | 이유 |
|---|---|---|
| A. 칸을 `ConversationView` 안 열로 두고 창을 오른쪽으로 넓힘 | **채택** | 사장 결정. 칸이 대화 보기와 같은 유리·같은 그리기 원본을 써서 색이 자연스럽게 맞는다. 덮기 경로가 사라져 코드가 준다 |
| B. 칸은 `PetView`에 두고 프레임만 방 목록 오른쪽에 겹쳐 놓음 | 기각 | 대화 보기 안 채팅 칸 프레임을 밖에서 밀어야 해서 두 곳이 배치를 나눠 갖게 된다(책임 둘). 투명 바탕이면 아래 채팅 글자가 비친다 |
| C. 창 크기 그대로, 채팅 칸만 290 좁힘 | 기각 | 사장이 "오른쪽으로 넓어짐"을 골랐다. 좁은 화면 경계에서만 이 동작을 쓴다(REQ-DI-04) |

## 4. 기존 경로 판정
| 경로 | 판정 | 내용 |
|---|---|---|
| `PetPlacement.leading`·`withLeading`·`drawerOverlay`, `contentBubble`의 뜻(왼쪽 칸 뺀 상자 → 오른쪽 칸 뺀 상자), `stepPlacement`의 `shownLeading` 역산식 | 교체 | 오른쪽 넓힘 판정으로 바꾼다. 호출부(`placePet`, `moveChatDrag`, `stepPlacement`, `PetPlacement(init)`) 모두 이관, 옛 이름 제거 |
| `drawerShift`/`anchorOrigin` 되돌림 | 유지(방향 반대) | 저장 위치 불변 규칙은 그대로 |
| `PetView.todoDrawer`·`installDrawer`·`drawerScrim`·`TodoDrawerScrim` | 제거 | 덮기 없음. 칸은 `ConversationView` 하위 |
| `TodoDrawerView.backgroundColor`·불투명 `draw`, `PetView.updateScrim` 칸 색 | 제거 | REQ-FF-08 대체 |
| `paneSplit` | 유지 | `available`에서 칸 몫을 뺀 값을 넘기는 것만 바뀐다 |
| `PetController.drawerWidth`(290)·`drawerDuration`(0.25)·`setDrawerOpen`·`todoDrawerOpen` 저장 | 유지 | |
| 시험 `DrawerOutsidePlacementTests.swift`(AT-FF-90~93), `TodoDrawerBackgroundTests.swift`(AT-FF-40/41), `TodoDrawerTests.swift`의 AT-TD-30(덮개)·31·33·34·35 단언 | 교체 | 새 AT-DI 시험으로 바꾼다. 옛 시험 파일은 지우거나 새 시험으로 이름을 바꾸며 `TestMain.swift` 등록도 맞춘다 |

## 5. 유지할 계약
- 알약 동작(`IslandModel` `Action.drawer`, 미리보기 예외), 칸 내용 모델(`TodoDrawerModel`), 마감 요청 시점(NFR-TD-03), `todoDrawerOpen` 저장, 웹 칸 `paneSplit` 규칙, 칸 290·0.25초, Esc·"‹ 접기" 닫기, 펫 저장 위치 불변.
- `PetWindowTests`·`WebPaneTests` 등 칸이 닫힌 상태 시험의 기대값은 그대로다.

## 6. 위험·롤백
- 위험도 일반(공통 4절): 여러 모듈의 화면 배치, 되돌릴 수 있음, 저장 형식·통신·권한 변화 없음.
- 롤백: 이 작업 커밋을 되돌린다. 저장 값이 바뀌지 않으므로 이전 판으로 돌아가도 설정이 그대로 읽힌다.
- 주의: 채팅 칸 `x`를 쓰는 프레임 누락(입력 줄·끌기 손잡이·검색 결과·실패 줄 등)이 가장 흔한 실패다. AT-DI-05가 대표 프레임을 모두 본다.
