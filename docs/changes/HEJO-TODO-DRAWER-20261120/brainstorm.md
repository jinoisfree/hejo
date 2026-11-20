# HEJO-TODO-DRAWER 결정 요약

작성 2026-11-20 · 진행 방식 연합개발 · 기준 커밋 `63cbe2a`

## 요청
"아일랜드 알약을 누르면 채팅 크기는 그대로 두고 창이 왼쪽으로 290px 늘어나면서 '처리할 일' 칸이 생긴다. 0.25초 동안 스르륵 열린다. 이 방법 좋아, 구현해."
시안: [`hejo-ui-v28-drawer-logo`](../HEJO-FOUNDATION-20261114/mockup/hejo-ui-v28-drawer-logo.html)(v27을 다듬은 판). HEJO-FOUNDATION 설계 9판에서 "1단계 범위 밖"으로 미룬 것(`design.md:202`)이다.

## 사장 결정 (2026-11-20, 질문 도구 답)
1. 칸 내용: **답 요청 + 알림 + 마감·할 일까지**.
2. 여는 곳: **알약의 사장 차례 칸과 빈 알약**을 누르면 칸이 열리고 닫힌다. 지금 "가장 오래된 질문으로 가기"는 칸의 맨 위 카드가 맡는다. 직원 얼굴(그 직원 탭으로)과 문제 칸(다시 연결)은 지금처럼 동작한다.
3. 오른쪽 웹·파일 칸과 함께 열기: **화면 폭이 되면 둘 다 연다. 왼쪽 자리가 없으면 할 일 칸이 채팅 위에 덮인다**(시안 대안).
4. 마감·할 일 자료의 출처: **직원이 만드는 할 일**.

## 조사로 확인한 것 (읽기 전용)
- 답 요청·알림은 앱이 이미 계산한다. 원본은 `ConversationModel.notices(_:)`(`app/Sources/WorkspaceTools.swift:73`)이다. 사이드바 배지(`ConversationModel.swift:166,169`)와 방 알림 줄(`ConversationView.swift:440`)이 이것을 쓴다.
- 알약 동작은 `IslandModel`·`IslandView`(`app/Sources/Island*.swift`)에 있다. 사장 차례 칸의 지금 동작은 `.question(가장 오래된 asked)`이다.
- 창 넓히기의 선례로 오른쪽 웹 칸이 있다. `PetLayout.paneSplit`(`PetLayout.swift:100`)과 `PetPlacement`의 `trailing`(`PetLayout.swift:217,247`)을 쓰고, 넓어지는 동안 `ChatWidthSlide`로 덮는다.
- [확인] **직원이 만드는 마감에는 이미 원본이 있다.** 운영 저장소 team-kit의 `hermes_team_services/deadline_watch.py`가 맡는다.
  - 저장 위치: 직원 프로필마다 `<프로필 홈>/state/deadline-watch.json`.
  - 항목 모양: `id`(notion·calendar·slack·notes·gmail 출처), `title`, `due`(날짜), `source`, `closed`.
  - 직원 런타임이 쓰고 닫는다. 닫는 이유는 담당자 확인, 완료 근거 확인, 마감 경과, 취소 중 하나다.
  - 읽기용 `snapshot()`이 있고, 지금은 Slack 보고로만 알린다.
- [확인] 마감이 없는 업무 할 일도 원본이 있다. `personal_work_bundle`(`task_capture.py`)이 Obsidian 메모와 노션 업무 DB에 만든다.
- 그러므로 hejo 기록장에 직원용 "할 일" 기록을 새로 만들면 **두 번째 원본**이 된다. ARCHITECTURE 5절 원칙 1과 AGENTS.md 첫 규칙에 어긋난다. 따라서 칸 배치를 보고하고 결정을 기다린다.

## 칸 배치 선택지 — **결정: 가** (2026-11-20 사장 답 "가")
- **가(권고) 기존 마감 장부를 읽어 보여 준다.**
  - 문이 team-kit이 있으면 감지해 각 직원의 마감 장부 `snapshot`을 읽기만 하고 앱에 보낸다(원칙 5).
  - 할 일 칸 = 답 요청 + 알림 + 마감(D-day). 원본과 쓰기 주체는 그대로 직원이다. 완료 처리는 기존 길(직원에게 말하기·닫기 이유)을 쓴다.
  - team-kit이 없는 공항에서는 마감 묶음이 비어 보인다.
  - 마감 없는 업무 할 일(Obsidian·노션)은 이번 범위 밖이다.
- **나 hejo 기록장에 새 할 일 원본을 둔다.**
  - 직원 표식 `[[할 일:…]]` → team-kit → 문 → 기록장 → 앱 길이다. 체크리스트와 같은 길이다.
  - 기존 마감 장부와 원본이 둘이 되므로, ARCHITECTURE 칸 표를 바꾸고 기존 장부를 은퇴·이관하는 계획까지 사장 승인이 필요하다.
- **다 이번엔 답 요청 + 알림만으로 칸을 만든다.** 마감은 가안을 다음 작업으로 붙인다.
