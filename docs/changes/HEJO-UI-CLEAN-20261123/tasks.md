# HEJO-UI-CLEAN 작업

1판 · 2026-11-23 · [spec](spec.md) · [design](design.md) · [수락 시험](../../../tests/acceptance/HEJO-UI-CLEAN.md) · [인계](handoff.md)

| TASK | 내용 | REQ·시험 | 영향 파일 | 위험도·증거 | 선행 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 처리할 일 칸: 머리 한 줄(필터+✕), 0개 흐림, 카드(사진·상태·시각, 52pt), 급함 세로줄 공용 값(채팅 카드도 같은 위치), 묶음 선, 올림·선택, 선택↔채팅 강조 유지·답글, 키보드, 바닥 톤 | UC-02·03 / AT-UC-10~19 | `TodoDrawerModel.swift`, `TodoDrawerView.swift`, `ConversationView.swift`(선택 강조·바닥 톤), `SidebarMotion.swift`(SidebarBlank·공용 색), `ConversationChrome.swift`(토글 흐림·공용 값), 채팅 질문 카드 세로줄 그리기 파일, `app/Tests/`(새 시험·이관) | 일반 · 2 + 사진 | 없음 | 대기 |
| TASK-02 | 제목 알약: IslandModel 스냅숏(제목·점·활동 하나), IslandView 그리기·점 깜빡임·두 영역 클릭, 머리 heading·subtitle 제거 | UC-01 / AT-UC-01~06 | `IslandModel.swift`, `IslandView.swift`, `ConversationView.swift`(머리 배치·action 연결), `app/Tests/IslandTests.swift`·`TodoDrawerTests.swift`(알약 단언 이관)·새 시험 | 일반 · 2 + 사진 | TASK-01(같은 ConversationView) | 대기 |
| TASK-03 | 중복 정리·다듬기: 칸 열림 때 칩 줄 숨김·칩→필터, 홈 배지 제거, 질문 단추 글자만, 밝은 테마 묶음 글자 버그, 툴팁, 분홍 표식·접기 단추 조사 | UC-04·05 / AT-UC-30~35, 전체 AT-UC-40 | `ConversationView.swift`, `ConversationChrome.swift`, `ThreadTools.swift`(단추 표현), `ComposerFaces` 있는 파일, `app/Tests/` | 일반 · 2 + 사진 | TASK-02 | 대기 |
| 반영 | 현재 명세 반영: TD REQ-TD-01·04 AC-01 강조 시간, DRAWER-INLINE REQ-DI-05 AC-03·04·REQ-DI-08 AC-01·02에 대체 표시, 수락 시험 이관 표시, 상태 '적용' | — | `docs/`, `tests/acceptance/` | 계획 담당 | 검증 완료 | 대기 |
| 공개 | 다음 공개 판 | — | 공개 절차(HEJO-TELEGRAM 쪽과 조율) | 사장 결정 | 검증 완료 | 이번 지시 밖 |

병렬 갈래: 없음(파일 겹침: `ConversationView.swift`를 TASK-01·02·03이 모두 고친다). 순서대로 한다.

TASK마다 따로 커밋(`git commit --only`로 자기 경로만), impl-report.md에 TASK별 절. 세 TASK를 한 지시로 이어서 하되 TASK 사이에 전체 앱 시험을 돌린다.
