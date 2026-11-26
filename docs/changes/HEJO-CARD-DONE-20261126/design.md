# HEJO-CARD-DONE 설계

- 2판(계획 검증 1회차 반영) · 상태: 적용(3판 추가분은 기존 `markNoticeRead` 재사용 + `HistoryCoordinator` 같은 키 `notice` 합치기) · 기준 `github/main` `018036cbf24678ea3a29f826926531e8ab4d370b` · 칸 배치: [brainstorm.md](brainstorm.md) "칸·원본·쓰기 주체·수명"(ARCHITECTURE 8절 표·점검 답)

## 1. 변경 성격

의미 변경(화면 동작 추가). 비교: 수락 시험의 "기준본 기대" 열(기준본에는 띠·되돌리기 확인 전송이 없음).

## 2. 현황 [확인]

| 항목 | 위치 | 내용 |
|---|---|---|
| 카드 그리기·클릭 | `app/Sources/TodoDrawerView.swift:141-186` `TodoDrawerCardView` | 마우스 올림 추적(`hovered`), `mouseDown` 전체가 `perform`(대화 이동), 우클릭은 `menuItems` |
| 우클릭 마감 닫기 | `TodoDrawerView.swift:117-124` | 마감 카드만 "완료로 닫기/취소로 닫기/출처 열기" |
| 되돌리기 줄 | `TodoDrawerView.swift:91-98` | `undoTitle`이 있으면 `‘제목’ 닫음 · 되돌리기` |
| 경고 줄 | `TodoDrawerView.swift:77-79`, `TodoDrawerModel.Snapshot.warning/closeWarning` | 카드 목록 위 회색 글 |
| 마감 닫기 대기·전송 | `ConversationController.swift:28-124` | `pendingClose` 하나, 5초 뒤 `sendClose`, 응답 대기 75초, 확인 목록까지 `hiddenDeadlineCards`로 숨김, `stop()`에서 버림, 0.5초 주기 `pollDeadlineCloses` |
| 카드 투영 | `TodoDrawerModel.swift` `snapshot(… hidden:)` | `hidden`은 지금 마감 카드에만 적용. 답 요청 카드 id = 글 id, `key`·`messageID`·`employee` 있음 |
| 글 보내기 | `ConversationController.swift:466` `sendText(_:key:recipient:)` → `transmit`(803-849) | `client_msg_id`=`pending` 키. 쓰기 시작 전 실패는 `failPending`+`false`. 기록 모드에서 쓰기 시작 뒤 오류는 `pending` 유지, `notice`, `true` |
| 사후 결과 | `ConversationController.swift:642-666`(같은 `client_msg_id` 글 도착 → `pending` 제거 = 접수, `type=error` `ref` → `pending` 제거 + `failPending` = 거절), `:137-148` 영수증(`accepted`/`deleted` = 접수, `not_found` = 유지), `:590-600` 재연결 `sync_done` 미확인 → `failPending` | 전송 결과의 유일한 판정 자리들 |
| 연결 | `ConversationController.swift:671` `canSend` | `isConnected && replayComplete` |
| 연결점 | `ConversationView.swift:264-270` | `onCloseDeadline`·`onUndoClose` 등 카드창 콜백 |
| 완결 판정 | `gate/history_queries.py:44-87,151`, 앱 `ThreadTools.swift:88-116` | 일반 사장 글 = 앞 요청의 답. 사장 글이 마지막이면 카드 없음. 답 뒤 직원 글이 오면 settled |

## 3. 목표 구조와 흐름

```
카드(마우스 올림) ─ 띠 누름 ─▶ TodoDrawerView.onComplete(card)
                               │
                               ▼
          ConversationController.completeCard(card)   ← 단 하나의 진입점(띠·VoiceOver)
             · 마감: closeDeadline(card, "done")        (기존 경로 그대로)
             · 답 요청: 대기 자리에 "확인 보내기" 넣음
          대기 자리 하나(마감 닫기와 공유), 5초 → 실행
             · 마감: sendClose (기존)
             · 답 요청: sendText("확인", key, recipient: card.employee)
                  client_msg_id를 카드에 묶어 결과를 기다림(spec REQ-CD-03 표)
                  ① false / ② error(ref)·sync_done 실패 → 카드 다시 보임 + 경고
                  ③ pending 유지(미확정) → 숨김, 75초 뒤 띠 없이 보임
                  ④ 접수(글 도착·영수증) → 문 목록에서 빠질 때까지 숨김(접수부터 75초 상한)
```

- 책임: 띠 모양·누름 판정은 `TodoDrawerCardView`, 어떤 카드가 종결 가능한지·대기·전송·숨김은 `ConversationController`, 숨김 반영은 `TodoDrawerModel.snapshot`의 `hidden`.
- 대기 자리: 지금 `PendingClose`를 마감·답 요청 두 종류를 담는 한 자리로 넓힌다(이름·형태는 구현 자유). 앞에서 기다리던 것은 종류와 상관없이 바로 실행한다. 별도 두 번째 타이머·대기 자리를 만들지 않는다(NFR-CD-01).
- 숨김: `hidden` 집합에 (대기 중 답 요청 글 id) ∪ (보내는 중) ∪ (확인 대기 중)을 더한다. `TodoDrawerModel.snapshot`의 `hidden`을 답 요청 카드에도 적용한다(계수 `counts`에도 빠짐 — 마감 숨김과 같게).
- 결과 연결: 카드 ✓ 전송은 `transmit`이 만든 `client_msg_id`를 카드 글 id와 묶어 둔다(`sendText`가 그 id를 돌려주거나 같은 뜻의 내부 연결. 형태는 구현 자유). 결과 판정은 새로 만들지 않고 2절 "사후 결과"의 기존 자리(접수: 글 도착·영수증 accepted/deleted, 거절: `failPending`을 부르는 모든 자리)에서 그 id의 결과를 카드 추적에 알린다. 즉시 실패는 `sendText`의 `false`. `true`인데 `pending`에 그 id가 남아 있으면 ③(미확정) 또는 접수 대기다.
- 숨김 해제: 매 주기(`pollDeadlineCloses`와 같은 주기). ④는 현재 모델의 답 요청 알림 글 id에 없으면 해제, 접수부터 75초 지나면 해제. ③은 보낸 때부터 75초 지나면 보이되 `pending`에 그 id가 있는 동안 종결 불가(띠·VoiceOver 없음).
- 재전송 금지: 카드 추적은 어떤 결과에서도 스스로 `sendText`를 다시 부르지 않는다. 실패 뒤 다시 보내는 것은 사장이 띠를 다시 누를 때뿐이다.
- 종결 가능 판정(띠·VoiceOver 공통): 답 요청 = `kind == .question && key != nil && messageID != nil && canSend` 그리고 그 카드의 ③ 미확정 전송이 없음. 직원 버튼 유무와 관계없이 `click`은 보내지 않는다. 마감 = `kind == .deadline && deadlineRef != nil`. 카드 뷰에는 판정 결과만 넘긴다(뷰가 연결 상태를 직접 읽지 않음).
- 그리기: 띠는 카드 오른쪽 44pt, 카드 둥근 모서리 안으로 잘라 채움, 색 `NSColor.systemGreen`, 흰 ✓(SF Symbol `checkmark` 또는 선). 띠가 보이면 시간 글자는 그리지 않고 상태 줄 폭은 `bounds.width − 50 − 44 − 8`. 띠가 없으면 지금 그리기와 똑같다.
- 누름: `mouseDown`에서 위치가 띠 안이고 띠가 보이면 `onComplete`, 아니면 지금처럼 `perform`.
- 되돌리기 줄 글: 마감 `‘제목’ 닫음 ·`(지금), 답 요청 `‘제목’ 확인 보냄 ·`. 스냅숏에 종류를 함께 넘긴다.
- 경고: `확인을 보내지 못했어요. 다시 해 주세요.`를 `closeWarning`과 같은 줄 자리에 넣는다. 다음 `completeCard` 또는 카드창 열기(`setDrawerState`가 `closeFailed=false` 하는 곳)에서 지운다.
- 손쉬운 사용: 종결 가능 카드에 `NSAccessibilityCustomAction`(이름 REQ-CD-05) 하나, 호출 = `onComplete`.

## 4. 기존 경로 판정

| 경로 | 판정 | 이유·영향 |
|---|---|---|
| `closeDeadline`·`sendClose`·`receiveClose`·확인 목록 | 유지 | 마감 띠는 `closeDeadline(card,"done")` 호출만 한다 |
| `pendingClose`(마감 전용 대기) | 통합 | 답 요청 대기를 같은 한 자리로. `undoClose`·`stop()`·`resetCloses()`·`pollDeadlineCloses`가 두 종류를 같이 처리. 옛 마감 전용 필드를 남겨 두 자리를 만들지 않는다 |
| `sendText`·`transmit`·사후 결과 자리 | 유지(결과 알림만 추가) | 사장이 스레드에서 쓰는 전송 그대로. 새 프레임·새 판정 없음. 결과를 카드 추적에 알리는 호출만 더한다 |
| 우클릭 메뉴·카드 클릭·화살표·Enter | 유지 | 띠 밖 누름은 지금 동작 |
| 대화 안 "확인" 버튼(`confirm:`) | 유지 | 범위 밖. 카드 ✓와 뜻이 다름(사장 결정: 카드 ✓는 글을 보냄) |
| 문 판정(`history_queries.py`) | 유지 | 변경 없음 |

## 5. 유지할 계약

앱↔문 프레임(`send`, `deadline_close`, `deadlines`)과 형식, 회원 상태 키, 카드 높이 52·폭, 카드 색·테두리·주의 막대, 우클릭 메뉴 항목, 마감 되돌리기 줄 글, 마감 실패 경고 글, 5초·75초 값.

## 6. 대안

- 띠 대신 시간 자리 동그라미·알약·왼쪽 체크(시안 A·B·D): 사장 기각(시안 C 채택).
- 답 요청 대기를 별도 자리로: 기각. 되돌리기 줄이 둘이 될 수 있고 `stop()`·주기 처리가 두 벌이 된다.

## 7. 다른 작업과의 겹침

HEJO-JUMP-ONCE(재개 대기)가 `TodoDrawerView.swift`(카드창 경고 줄)·`ConversationView.swift`·`ConversationController.swift`를 바꿀 예정이다. 이 작업은 착수 때 `github/main` tip에서 시작하고, 커밋 전 tip이 바뀌었으면 그 위로 다시 올린다. 경고 줄 자리가 바뀌어 의도 판단이 필요한 충돌이면 멈추고 보고한다.

## 8. 위험·롤백

일반. 실제 직원에게 글이 가므로 시험은 가짜 전송자(`deadlineSender`와 같은 방식의 주입 또는 가짜 문)만 쓴다. 되돌리기는 커밋 되돌림. 앱 설치·서버 작업 없음.
