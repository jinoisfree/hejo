# HEJO-BUBBLE-WIDTH 설계

- 2판(계획 검증 1회차 반영) · 2026-11-26 · 기준 `github/main` `2dea766cbdbd5e179a6269aabbfefc750036b219` · 명세 [spec.md](spec.md) 2판

## 1. 칸·원본·쓰기 주체·수명
| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 최대 폭 숫자(0.75, 240) | 관제 화면(hejo 앱) | `app/Sources/ChatStyle.swift` `ChatMetrics` | 개발 | 갱신 때 교체 |
| 최대 폭 식과 폭 맞춤 | 관제 화면(hejo 앱) | `app/Sources/NativeThreadCard.swift` `layout` | 개발 | 갱신 때 교체 |
| 화면 규칙 문장 | 관제 화면(hejo 앱)의 현재 명세 | `docs/spec/current/hejo-owner-profile.md` "앱 화면" | 기획설계 | 명세와 같음 |

1. 칸: 모두 관제 화면이다. 새 칸과 두 번째 원본은 없다(NFR-BW-01로 원본을 하나로 줄인다).
2. 쓰기 주체: 개발. 사장 칸(금고·지시서·공방·명부)은 건드리지 않는다.
3. 갱신·제거: 앱 갱신 때 함께 바뀐다. 따로 보존하거나 지울 자료가 없다(6절 표의 "갱신 → 앱").
4. 개인값: 없다. 시험 글은 가짜 문장만 쓴다.
5. 다른 사장의 공항: 화면 폭만으로 계산하므로 코드 수정 없이 같다.

## 2. 현황 (기준 커밋)
- `ChatStyle.swift:54-55`: `minimumBubbleWidth = 240`, `bubbleWidthFraction = 0.82`.
- `ConversationView.swift:1278·1364`: `bubbleWidth = max(240, (창 폭 − 사이드바 − 서랍) × 0.82)`를 `NativeThreadCard.Content`에 넣는다. `1564·1572`(날짜 줄·안내 줄)는 글이 없는 카드라 500을 넣는다.
- `NativeThreadCard.swift:71`: `Content.bubbleWidth`. `:249`: `limit = min(columnWidth, content.bubbleWidth) − 24`. 소비자는 이 한 줄뿐이다.
- `NativeThreadCard.swift:251`: 한 줄이면 글 폭, 아니면 `limit`.
- `NativeThreadCard.swift:262-287`: 써지는 중 높이를 `streamHeights`에 기억한다(폭은 기억하지 않는다).
- `TextLayout.swift:124`: 표는 폭 100% 비율. `:286-299`: 코드 상자는 글 그리는 칸 폭에 맞춰 그린다.
- 시험: `app/Tests/OwnerProfileTests.swift:31`이 `width × bubbleWidthFraction`을 넣는다. `HistoryTransportHarness.swift:69`, `ScrollTests.swift:22`, `WaitJitterTests.swift:96`은 300을 넣는다.
- `AppearancePreview.swift`(설정 창 미리보기)는 고정 폭으로 따로 그린다.

## 3. 바뀐 뒤 책임과 흐름
- 숫자는 `ChatMetrics`에(`bubbleWidthFraction = 0.75`, `minimumBubbleWidth = 240`), 식 `B = min(C, max(240, 0.75 × C))`는 `NativeThreadCard.layout`의 글 배치 한 곳에 둔다. `C`는 그 자리에서 이미 계산하는 `columnWidth`다.
- 답글 줄도 같은 `place`를 지나므로 같은 식이 적용된다.
- 폭 맞춤: 안쪽 최대 폭에서 잰 뒤, 자동 줄바꿈·표·코드 상자·왼쪽 정렬이 아닌 문단이 모두 없으면 가장 긴 줄 폭으로, 그 밖에는 안쪽 최대 폭으로 한다.
- 우선순위: ① `B`를 넘지 않는다 ② "더 보기/접기" 글자가 말풍선 안에 들어간다(지금의 `NativeThreadCard.swift:303-307` 동작 유지: 말풍선 폭 = max(글 폭, 접기 글자 폭) + 24) ③ 가장 긴 줄 맞춤. 판정 방법(예: 한없이 넓은 칸에서 잰 폭과 비교, 줄 조각 수 비교)은 구현이 고른다.
- 대조 항목: 좁힌 폭으로 다시 그렸을 때 줄이 더 꺾이지 않아야 한다(높이가 최대 폭에서 잰 높이와 같음). 소수점 폭은 올림한다.
- 써지는 중 폭: 높이와 같은 방식으로 글별 최소 폭을 기억한다. 열쇠와 버리는 조건(카드 폭·글씨 크기 변경, 다 써짐)은 `streamHeights`와 같은 자리에서 다룬다. 기억 개수 상한도 같은 방식으로 둔다.

## 4. 기존 경로 판정
| 경로 | 판정 | 내용 |
|---|---|---|
| `Content.bubbleWidth`와 `ConversationView`의 영역 × 0.82 계산 | 교체·제거 | 글 칸 기준 식으로 바꾸고 필드와 모든 호출부 인자를 같은 변경에서 지운다. [확인] 대화 목록은 자기 폭이 바뀌면 스스로 다시 잰다(`NativeThreadList.swift:593-606`, `layout()` → `remeasure()`가 `contents` 전체를 새 폭으로 `NativeThreadCard.layout`). 그래서 `ConversationView`가 폭 값을 넘기지 않아도 다시 배치된다. 실제 화면 경로는 AT-BW-10(떠 있는 목록의 폭을 바꿔 보이는 카드를 관측)으로 확인한다. `Content`의 같음 비교에 이 값이 쓰여 다시 그리기를 일으키는 곳이 있으면 멈추고 보고한다. |
| 한 줄만 맞추는 조건(`:251`) | 교체 | 3절 규칙으로 바꾼다. |
| `streamHeights`·높이 풀기 | 유지 | 높이 동작은 그대로다. |
| `AppearancePreview` 고정 폭 | 유지 | 범위 밖이다. |
| 표 100% 비율, 코드 상자 그리기 | 유지 | `TextLayout.swift`는 고치지 않는다. |

## 5. 유지할 계약
모서리 12, 안쪽 여백 12×8, 머리줄 배치(AT-OP-29·36), 내 글 오른쪽 정렬·직원 글 왼쪽 정렬, 표·코드의 안쪽 폭 줄바꿈과 가로 스크롤 없음, "더 보기/접기"가 말풍선 안, 써지는 중 높이 동작, 측정 캐시 상한.

## 6. 대안
- 대화 영역 기준 비율을 0.82에서 낮추기만 한다: 기각. 사진·카드 여백이 폭에 따라 다른 비중을 차지해 내 글과 직원 글의 여백이 식으로 같아지지 않고, 호출부마다 값을 넘기는 두 번째 원본이 남는다.
- 긴 글도 가장 긴 줄에 맞춘다: 기각. 글마다 끝이 달라져 양쪽 여백이 같지 않다.

## 7. 위험과 되돌리기
위험도 일반. 화면 배치만 바뀐다. 되돌리기는 커밋 되돌림이면 충분하다. 성능: 글마다 측정이 한 번 늘 수 있으므로 기존 측정 캐시를 쓰고, 기존 성능 시험(AT-BW-07 회귀)에서 새 실패가 없어야 한다.
