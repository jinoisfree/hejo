# HEJO-OWNER-PROFILE 작업 (2판, 2026-11-25)

| TASK | 내용 | REQ/AC | 수락 시험 | 선행 | 상태 |
|---|---|---|---|---|---|
| TASK-01 | 문: 사장 프로필 저장·HTTP·사진 종류·wire `owner`·표시 이름 사용처(맥락·텔레그램·디스코드·버튼·Hermes user_name)·스키마 문서 | REQ-OP-01~03 | AT-OP-01~14 | 계획 검증 통과 | 검증 완료(`a6266cd`, verdict 2·4차) |
| TASK-02 | 앱: 프로필 받기·저장 요청·설정 "내 프로필"·우클릭·말풍선 통일·내 글 머리줄·"나" 표기·미리보기 | REQ-OP-02.AC-02·04(앱 쪽), REQ-OP-04~07 | AT-OP-20~36 | TASK-01, HEJO-AUTOLOAD TASK-01의 `github/main` 반영 | 검증 완료(`f116bdc`, verdict 4차) |
| TASK-03 | 현재 명세 반영(`docs/spec/current/`, ARCHITECTURE 공용 창고 행, 계약 원본 확인) | 전체 | — | TASK-01·02 검증 완료 | 반영(공개 브랜치 문서 커밋) |
| 후속(별도 작업) | 서버 설치: 운영 문 줄(`632d090` 계열)과 공개판 차이 정리 뒤 설치 | — | — | TASK-03 | 범위 밖 |

## 영향 파일
- TASK-01: `gate/owner.py`(새), `gate/pictures.py`, `gate/server.py`, `gate/adapter.py`, `gate/context.py`, `gate/rooms.py`, `gate/buttons.py`, `gate/telegram.py`, `gate/discord.py`, `gate/tests/test_owner_profile.py`(새), 기존 문 시험 중 바뀐 시그니처 호출부, `schemas/hejo-wire-v1.json`, `schemas/pictures.md`, `gate/README.md`(HTTP 경로 목록이 있으면).
- TASK-02: `app/Sources/ConversationModel.swift`, `ConversationController.swift`, `GateHTTP.swift`, `NativeThreadCard.swift`, `ConversationView.swift`, `ChatStyle.swift`, `AppearancePreview.swift`, `ThreadTools.swift`, `WorkspaceViews.swift`, `PetSettingsWindow.swift`, `AppDelegate.swift`(필요 시), `app/Tests/OwnerProfileTests.swift`(새), `app/Tests/OwnerProfileTransport.sh`와 그 하네스·문 fixture(새), 기존 앱 시험 중 "기존 회귀 시험의 기대값 변경" 절 해당분, 앱 시험 실행 스크립트 등록.

## 다른 작업과의 겹침
- HEJO-AUTOLOAD(진행 중), HEJO-WAIT-JITTER·HEJO-ALERT-SEEN(AUTOLOAD 대기)이 `ConversationView.swift`를 고친다. AUTOLOAD는 `NativeThreadCard` 계열도 고칠 수 있다. 그래서 TASK-02는 AUTOLOAD 반영 뒤 시작한다. TASK-01(문)은 겹치지 않는다(AUTOLOAD는 문 제품 파일 변경 금지).
- 푸시 전에 `github/main`이 앞서 있으면 구현 담당이 최신 `github/main`을 작업 브랜치에 merge하고 전체 시험을 다시 돌린다(의도 판단이 필요한 충돌은 멈추고 보고).

## 결정 기록
- D-01 (사용자, 2026-11-25): 채팅 A안, 직원 글 전부 말풍선, 표·코드 말풍선 안 폭 맞춤, 말풍선 모양 통일, 내 글 머리줄 시간이 가장 바깥쪽, 이름을 앱·텔레그램·직원 모두에 사용, 공용 창고 저장.
- D-02 (계획 담당 제안): 디스코드도 텔레그램과 같이 이름 사용, 이름 1~20자, 사진 규칙은 직원 사진과 같음, 설정 화면은 기존 설정 창의 영역.
- D-03 (계획 담당, 2026-11-26): 기존 `tests/acceptance/test_slack_move_gate.py` AT-SM-02의 wire 스키마 SHA-256 고정값을 갱신하는 것을 허용한다. 이전 작업들(DEADLINE-CLOSE, TELEGRAM, HISTORY, DISCORD)도 같은 방식으로 갱신했다. 조건: 스키마 변경이 `owner_profile` 정의와 welcome·roster의 선택 속성 `owner` 두 곳 추가뿐임(계획 담당이 스테이지 diff로 확인), 해시값과 그 위 설명 주석 한 줄(`# HEJO-OWNER-PROFILE added the optional owner field and its definition only`)만 바꾸고 같은 시험의 다른 단언은 그대로 둔다.
- D-04 (계획 담당, 2026-11-26): 기존 `app/Tests/PostGroupTests.swift` AT-PG-09의 `expectPosts(content,[(previous,false)],…)` 기대값을 `[(previous,precedingOwner)]`로 바꾸는 한 줄을 허용한다. 이유: 스레드 첫 글이 사장 글이고 바로 아래 첫 답글도 사장 글이면 '바로 앞에 보이는 글도 내 글'(REQ-OP-06.AC-02)이라 머리줄을 생략하는 것이 승인된 동작이다. 같은 시험의 다른 단언(생각 중 머리·작업 줄 수 등)은 그대로 둔다. impl-report에 전·후 표를 남긴다.
