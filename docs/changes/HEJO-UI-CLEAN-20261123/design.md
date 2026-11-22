# HEJO-UI-CLEAN 설계

1판 · 2026-11-23 · 명세 [spec.md](spec.md) · 기준 main `e9f2d59` · 칸 표는 spec 첫 절.

## 1. 지금 흐름 [확인]
- 알약: `IslandModel.snapshot()`이 `parts`(problem/owner/worker, 미리보기 event, "닫기 ‹" 덧붙임)를 만들고(`IslandModel.swift:111-160`), `IslandView`가 여러 칸으로 그린다. `ConversationView.layout`이 알약을 `x+12`에, 그 오른쪽에 `heading`(방 이름)·`subtitle`(설명)을 둔다. 클릭은 `ConversationView` `tickIsland`/`.drawer`·`.question`·`.worker`·`.reconnect`·`.retry` 처리.
- 칩 줄: `noticeBar`/`noticeScroll`(`ConversationView.swift:150,497,724`).
- 칸: `TodoDrawerModel.snapshot` → `Card`(badge·time·urgent) → `TodoDrawerView`(고정 머리 2줄, `TodoDrawerCardView`, `ComposerModeTrack` 필터).
- 카드 선택: `ConversationView.selectDrawerCard` → 스레드 선택·`highlightedMessageID` 1.5초(`ConversationView.swift:11-30`).
- 홈 줄 배지: `EmployeeSidebarCell` numbers 레이어(`ConversationChrome.swift:55`).
- 묶음 글자색: `ConversationChrome.swift:42-44` — `NSColor.labelColor`를 `.cgColor`로 바꿀 때 현재 그리기 모양새 기준으로 풀려 밝은 테마에서 흰색이 남는 것으로 추정[가정].

## 2. 바뀐 흐름

### 2.1 제목 알약 (TASK-02)
- **상태 원본은 `IslandModel` 하나.** `Snapshot`을 "제목 + 점 + 활동 하나" 모양으로 바꾼다: `title: String`, `dot: Bool`(처리할 일 total>0 — 입력 `todoTotal`을 `Input`에 더함), `activity: Activity?`(kind problem/question/worker, 문장, 사진 직원들, 색 tone, action), `drawerOpen`. 우선순위·미리보기 시간·재연결 초읽기 규칙은 지금 코드 재사용. "닫기 ‹"·owner 개수 문장·`iconOnly` 같은 여러 칸 규칙은 제거(교체).
- **그리기 원본은 `IslandView` 하나**: 캡슐 안 [방 이름][구분선][점][활동]. 점 깜빡임은 CALayer 불투명도 애니메이션(2.4초, ease-in-out, autoreverse 아님 → 100→35→100 한 주기 반복), `drawerOpen`·동작 줄이기면 제거. 사진은 지금 얼굴 그리기 원본(`controller.avatar`/`ProfileAvatar`) 사용.
- **배치**: `ConversationView.layout`에서 `heading`·`subtitle`을 없애고(제거) 알약이 머리 왼쪽 `x+12`부터 `fittedWidth(limit: 머리 폭-24)`. 방 이름 문자열은 지금 `heading`에 넣던 값을 `IslandModel.Input.title`로 넘긴다.
- **누르기**: `IslandView`가 영역을 둘로 나눠 `Action.drawer`(제목·점) / 활동 action(활동 부분)을 낸다. `ConversationView`의 기존 action 처리 경로를 그대로 쓴다.

### 2.2 칸 머리·카드 (TASK-01)
- `TodoDrawerView`: 고정 보기 두 개(`heading`·`filters`) → 한 줄(`filters` 안에 토글 + ✕ 단추). 제목 글자 제거. 스크롤 영역 위 끝 = 44.
- 카드 문장은 **모델이 만든다**: `Card`에 `status: String`, `statusUrgent: Bool`, `trailing: String`을 두고(기존 `badge`·`time`은 이 둘로 교체), 그리기는 문자열만 쓴다. 마감 날짜 계산은 지금 `days` 규칙 재사용.
- `TodoDrawerCardView.draw`: 새 배치. 테두리·바탕·올림·선택 색은 이름 붙은 공용 값(예: `SidebarTone.card…`)으로. 세로줄은 **새 공용 값**(예: `AttentionRail { color, width:3, inset:6, vertical:10 }`)을 만들고 채팅 질문 카드 그리기도 이것을 쓰도록 바꾼다(채팅 쪽 위치 변경 포함).
- 묶음 제목 레이블 제거, 묶음 사이 1px 선 보기.
- 올림: `NSTrackingArea`로 hover 상태. 선택: 기존 `selected`.
- 키보드: `TodoDrawerView`가 첫 응답자일 때 `moveUp/moveDown/insertNewline` 처리 → `onCard`/선택 이동 콜백. `ConversationView`가 선택 상태(`drawerSelectedID`)의 원본.
- 연결: `selectDrawerCard`의 1.5초 `highlightUntil`을 칸 선택 동안 유지로 바꾼다(선택 바뀜·칸 닫힘 때 해제). 답글 모드·얼굴 켜기는 지금 스레드 선택 경로(`replyMode=true`, `controller.composeKey`)를 그대로 탄다.
- 바닥 톤: `ConversationView.draw`의 열 바탕 높이를 바닥까지, `SidebarBlank.draw`의 검정 덮개 제거.
- 0개 필터 흐림: `ComposerButton`에 `dimmed` 또는 글자색 알파 인자(토글 공용 원본 안에서).

### 2.3 중복 정리·다듬기 (TASK-03)
- 칩 줄: `noticeScroll.isHidden`에 `drawerOpen` 조건 추가. 칩 클릭은 `onToggleDrawer`+`drawerFilter` 설정 경로.
- 홈 줄 배지: `EmployeeSidebarCell`에서 `row.kind == .home`이면 numbers 숨김.
- 질문 단추: `ThreadTools` 단추 표현에서 기호 제거(글자만).
- 묶음 글자색: 색을 해당 셀의 `effectiveAppearance.performAsCurrentDrawingAppearance` 안에서 풀거나 테마 변경 때 다시 칠함. 원인 확인 후 그 자리에서.
- 툴팁: 방 목록 셀 `toolTip`(잘렸을 때), `ComposerFaces` 얼굴별 툴팁.
- 분홍 표식·접기 단추: 조사 후 spec AC-04·05대로.

## 3. 대안
| 대안 | 판정 | 이유 |
|---|---|---|
| 알약 상태를 `IslandModel`에 두고 모양만 바꿈 | **채택** | 미리보기·우선순위·재연결 규칙을 재사용, 원본 하나 |
| 제목 알약용 새 모델을 만들고 `IslandModel`은 남김 | 기각 | 같은 상태 두 원본 |
| 카드 문장을 그리기에서 만듦 | 기각 | 시험이 모델로 문장을 볼 수 없음, 그리기와 접근성 이름이 갈라짐 |

## 4. 기존 경로 판정
| 경로 | 판정 |
|---|---|
| `IslandModel` 여러 칸 `parts`·"닫기 ‹"·owner 개수 문장·`iconOnly` | 교체(제목·점·활동 하나) |
| `ConversationView.heading`·`subtitle` | 제거 |
| `TodoDrawerView` 제목 띠 | 제거(REQ-DI-08 대체) |
| `Card.badge`·`time` | 교체(`status`·`statusUrgent`·`trailing`) |
| 1.5초 강조(`highlightUntil`)의 칸 선택 경로 | 교체(선택 동안 유지). 알약·다른 경로의 1.5초는 유지 |
| 홈 줄 배지 | 제거(홈만) |
| `SidebarBlank` 검정 덮개 | 제거 |
| 질문 단추 기호 | 제거 |
| 채팅 카드 세로줄 값 | 통합(공용 값) |
| 기존 시험: AT53(알약 칸·폭)·AT56(알약 클릭)·AT-TD-27·29·41(알약 열기/닫기 라벨)·AT-TD-20·22(카드 badge·time 문장)·AT-TD-25(1.5초)·AT-DI-35(제목 띠)·AT-DI-37·38 일부·AT-DI-44 이전 기대 | 교체(AT-UC로). 목록과 근거를 impl-report에 |

## 5. 유지할 계약
통신·저장 형식, `TodoDrawerModel` 필터·개수·정렬·urgent 규칙, 마감 닫기 흐름, 칸 폭·배치, 답글/새 글 토글·직원 얼굴 줄, 알약 미리보기 시간·재연결 초읽기, 동작 줄이기.

## 6. 위험·롤백
위험도 일반. 저장·통신 변화 없음, 커밋 되돌리기로 롤백. 가장 큰 위험은 알약 클릭 경로 누락(질문 이동·재연결·재전송) — AT-UC-05가 행동별로 본다.
