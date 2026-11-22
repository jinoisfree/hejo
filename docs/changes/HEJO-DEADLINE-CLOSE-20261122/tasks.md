# HEJO-DEADLINE-CLOSE 작업

3판 · 2026-11-22(계획 검증 1·2회차 반영) · [spec](spec.md) · [design](design.md) · [수락 시험](../../../tests/acceptance/HEJO-DEADLINE-CLOSE.md) · [인계](handoff.md)

| TASK | 내용 | REQ·시험 | 영향 파일 | 위험도·증거 | 선행 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | team-kit: `open_items`에 `notice`, `perform` close `closed_now`, `handle` 다시 칠하기 조건, `close` CLI, 실행 파일 진입 | DC-05, DC-03.AC-08·09 / AT-DC-01~09b | `HD` worktree의 `hermes/plugin-store/team-kit/deadline_watch.py`, `hermes/bin/hermes-deadlines`, `team-kit/tests/test_deadline_list.py`(AT-TD-01 키 집합에 `notice?` 추가 포함), `test_deadline_close.py`(새) | 일반 · 2 | 없음 | 검증 완료(verdict 2차) |
| TASK-02 | 문·안내판: `origin`·`notice` 전달, `deadline_close` 입구, 닫기 세대별 목록 공유, 행동 기록 | DC-04, DC-02.AC-01(문), NFR-DC-01·02 / AT-DC-10~20·16c·35 | `gate/deadlines.py`, `gate/server.py`, `gate/connection_runtime.py`(`append` 선택 인자만), `schemas/hejo-wire-v1.json`, `tests/acceptance/test_deadline_close.py`(새) | **고위험** · 2 | 없음(계약은 design 2·4절로 고정, 가짜 명령 사용) | 검증 완료(verdict 2차) |
| TASK-03 | 앱: 이동 교체, 출처·없음 표시, 우클릭 메뉴, 5초 대기·되돌리기·실패 | DC-01~03 / AT-DC-21~34·27d | `app/Sources/TodoDrawerModel.swift`, `TodoDrawerView.swift`, `ConversationController.swift`, `ConversationView.swift`, `app/Tests/TodoDrawerTests.swift` | 일반 · 2 | 없음(계약은 design 4절) | 검증 완료(verdict 2차) |
| TASK-04 | 서버 적용(team-kit sync + 문 릴리스 + 재시작 1회) → 사장이 묵은 2건 닫기 | DC-06 / M-DC-1·2 | 운영 공항 | 고위험 · 3·4 | TASK-01~03 검증 완료 + 사장 승인(2026-11-22 "남은 일 모두 진행") | 지시 2 |
| TASK-05 | 앱 0.2.6(빌드 8) 공개 후보 준비 → 사장 push·publish | — | 0.2.5 절차 | 고위험(공개) · 2 | TASK-04 | 공개 완료(v0.2.6, public 98a9f242) |
| 반영 | 현재 명세 반영: ARCHITECTURE 3절 직원 사물함 행의 쓰기 주체에 "사장(문 경유, 마감 닫기)" 추가, TD spec REQ-TD-04 AC-02·03 대체 표시, 이 문서들 상태 "적용" | — | `docs/` | 계획 담당 | 검증 완료 + TASK-04 적용 | 대기(TASK-04 뒤) |

병렬 갈래: 있음. TASK-01(운영 저장소 worktree), TASK-02(gate·schemas·tests/acceptance py), TASK-03(app)은 파일이 겹치지 않는다. 계약은 design 2·4절로 고정돼 있고, 각자 가짜 명령·가짜 프레임으로 따로 시험할 수 있다.

| 갈래 | 담당 파일 | 난이도 | 완료 조건 |
|---|---|---|---|
| A = TASK-01 | 위 표 | 보통 | AT-DC-01~09b + 기존 team-kit 시험 + `./airport-check` 종료 0 |
| B = TASK-02 | 위 표 | 어려움(자식 프로세스·재진입·직렬화·시간 예산) | AT-DC-10~20·16c·35 + `bash scripts/test.sh` gate 부분 종료 0 |
| C = TASK-03 | 위 표 | 보통(요청별 숨김 상태) | AT-DC-21~34·27d + 앱 시험 기본 묶음 종료 0 |
