# HEJO-POST-GROUP 수락 시험 명세

2판 · 2026-11-22(계획 검증 1회차 PG-R1·R3 반영: AT-PG-02 펼침 고정, AT-PG-05 입력·기대 고정, AT-PG-13 전환 시험 추가, [plan-review.md](../../docs/changes/HEJO-POST-GROUP-20261122/plan-review.md)) · 명세 [spec.md](../../docs/changes/HEJO-POST-GROUP-20261122/spec.md), 설계 [design.md](../../docs/changes/HEJO-POST-GROUP-20261122/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1회차 BLOCKED → 2판 반영, 재검증 대기. 기대값 출처: spec 요구(사장 결정, brainstorm.md). 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

## 공통 준비 (`app/Tests/PostGroupTests.swift`, 기본 앱 시험 실행에 등록)
`TypingTests.swift`처럼 임시 `LocalStore` + `MemoryCredentials` + `testConversation`, `welcome`으로 가짜 직원 `alpha`(이름 Alpha), `beta`(이름 Beta). 스레드마다 새 UUID. 메시지는 `controller.receive(["type":"message",...])`로 넣고, 스레드 첫 글은 사장(`role:"owner"`)이 기본. 직원 파일 글은 `text:""`, `files:[{file_id, name:"a.txt", mime:"text/plain", size:1}]`(필드는 `MessageFile` 디코딩에 맞춤). `ConversationView`를 만들어 `refresh()` 뒤 `ui.history.contents`에서 해당 스레드 `Content`의 `replies` 조각을 본다.
- "글 목록" = `replies`의 `.post(p)`를 순서대로 `(p.id 앞부분, p.continuation)`.
- "입력 머리 수" = `replies`의 `.accessory(_, 34, make)` 중 `make() is TypingBubbleView`인 개수.
- "작업 줄 수" = `replies`에서 `make()`가 `WorkingControlRow`인 accessory 개수.
- "alpha 이름 머리 수" = alpha 글 중 `continuation == false`인 `.post` 개수 + 접근성 라벨이 "Alpha "로 시작하는 `TypingBubbleView` 개수.
- **펼침:** 답글이 3개 이상인 시험은 따로 적지 않으면 그 스레드를 펼친 상태(`openThread = key`, `togglePile`과 같은 경로)에서 검사하고, 검사 전에 `.stack` 조각이 없음을 확인한다. 답글 2개 이하는 접힘과 무관하다.

| ID | AC | 입력(스레드 첫 글 뒤 답글 순서) | 기대 |
|---|---|---|---|
| AT-PG-01 | PG-01.AC-01 | alpha 파일 글 F, alpha 글 T("끝났어요") | 글 목록 = [(F,false),(T,true)] |
| AT-PG-02 | PG-01.AC-02 | (가) alpha A1, 사장 O, alpha A2 (나) alpha A1, beta B1, alpha A2. 둘 다 펼친 상태 | 먼저 `.stack` 없음 확인. (가) [(A1,false),(O,false),(A2,false)] (나) [(A1,false),(B1,false),(A2,false)] |
| AT-PG-03 | PG-01.AC-03 | 스레드 첫 글이 alpha 글 R, 답글 alpha A1, alpha A2 | 답글 글 목록 = [(A1,false),(A2,true)]. top의 R 글은 `continuation == false` |
| AT-PG-04 | PG-01.AC-04 | 답글 alpha A1, alpha A2, alpha A3, alpha A4(모두 일반 글, 버튼 없음), 스레드 펼치지 않음 | 접힌 상태: 더미(`.stack`) 다음 글 목록 = [(A4,false)]. 펼친 뒤(`togglePile` 경로 또는 `openThread` 설정): [(A1,false),(A2,true),(A3,true),(A4,true)] |
| AT-PG-05 | PG-01.AC-04 | 접힌 상태(펼치지 않음). A1 = alpha 글, 본문 "확인해 주세요"(굵은 글씨 없음, 버튼 나눔 안 일어남), `buttons`에 응답 버튼 하나, `reply_state` 없음. A2 = alpha 일반 글(버튼 없음, 승인 요청 문구 없음). (가) 답글 A1, beta B1(일반 글), A2 (나) 답글 A1, alpha M(일반 글), A2 | 전제 먼저 assert: `.stack` 조각 1개("이전 답글 1개"), 보이는 글 목록의 id가 정확히 [A1, A2] 순서(B1·M 없음). 전제가 안 맞으면 실패(다른 구성 허용 안 함). 기대: (가)(나) 모두 [(A1,false),(A2,false)] |
| AT-PG-06 | PG-01.AC-05 | alpha A1, 그다음 alpha 글 S(버튼 나눔이 일어나는 대기 글: `CardTests.swift`의 AT90 split 입력과 같은 본문 형태, 파일 없음) | S 앞부분·뒷부분 글 모두 `continuation == true`, A1은 false |
| AT-PG-07 | PG-02.AC-01 | alpha 파일 글 F 다음, alpha `typing on`(ttl 600) | 입력 머리 수 0, 작업 줄 수 1, 글 목록 = [(F,false)] |
| AT-PG-08 | PG-02.AC-02 | (가) 답글 없음 + alpha typing (나) alpha A1, 사장 O + alpha typing (다) beta B1 + alpha typing (라) alpha A1 + alpha typing + 끼어들었어요 상태(`controller.interruptions[key]` 설정 경로) (마) alpha A1 + alpha·beta 둘 다 typing | (가)(나)(다)(라) 입력 머리 수 1(alpha), 작업 줄 수 1 (마) 입력 머리 1개이고 그 접근성 라벨이 "Beta …"(alpha 머리는 없음) |
| AT-PG-09 | PG-02.AC-03 | (가) alpha A1, 그다음 alpha 글 "🤔 생각 중..." (나) 사장 O, 그다음 alpha 생각 중 글 | (가) 생각 중 글의 조각 0개(입력 머리 수 0), 작업 줄 수 1 (나) 생각 중 글의 `TypingBubbleView` 1개(지금과 같음) |
| AT-PG-10 | PG-02.AC-04 | alpha 생각 중 글 Th(바로 앞은 사장 글), 그다음 alpha 글 T | Th의 입력 머리 1개, T는 `continuation == true` |
| AT-PG-11 | PG-03.AC-01 | AT-PG-01 상태. 추가로 alpha A1, alpha 글 C(파일 있음 + 본문에 "☐ 확인"이 있어 체크박스 도움말이 붙는 형태, `CardTests.swift:62`의 checkedFile과 같은 형태) | T의 `textHelp == T.time`(빈 문자열 아님), F의 `textHelp == nil`. C는 `continuation == true`이고 `textHelp == "체크박스를 누르면 내 확인 상태를 저장합니다."` |
| AT-PG-13 | PG-01.AC-01, PG-02.AC-01·03·04 | 한 스레드에서 차례로(각 단계 뒤 `refresh()`): (1) alpha 파일 글 F (2) alpha `typing on`(ttl 600) (3) alpha 생각 중 글 Th(`text:"🤔 생각 중..."`) 도착 (4) Th에 `edit`(`final:false`, 본문 "작성 중인 답") (5) Th에 `edit`(`final:true`, 본문 "끝났어요") 그리고 alpha `typing off` | 단계마다 alpha 이름 머리 수 == 1. 작업 줄 수: (1) 0 (2)(3)(4) 1 (5) 0. 글 목록: (1) [(F,false)] (2)(3) [(F,false)](Th 조각 없음) (4)(5) [(F,false),(Th,true)]. (5)에서 Th `textHelp == Th.time` |
| AT-PG-12 | PG-04.AC-01 | `HEJO_PYTHON=<Hermes venv python> bash scripts/test.sh`, `<Hermes venv python> scripts/scan_private.py` | 둘 다 종료 코드 0. 기존 시험 파일의 기대값 diff 없음(`git diff`에 기존 시험의 `check(` 기대 변경 없음, 등록 줄 추가만) |

수동(사장, 증거 수준 4, 완료 조건 아님): 실제 앱에서 직원에게 파일을 먼저 보내는 일을 시키고, 작업 중·끝난 뒤 모두 이름이 한 번만 보이는지 화면으로 확인.
