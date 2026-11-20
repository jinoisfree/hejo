# HEJO-CONN-MANAGE 작업 분해

3판 · 2026-11-20(계획 검증 1·2회차 반영, [plan-review.md](plan-review.md)). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-CONN-MANAGE.md](../../../tests/acceptance/HEJO-CONN-MANAGE.md), 인계 [handoff.md](handoff.md). 약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 실행 중인 team-kit 원본, `TK`·`TD` = `HD` worktree의 `hermes/plugin-store/team-kit`·`team-delegation`.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-CONN-MANAGE-20261120/`, `H/tests/acceptance/HEJO-CONN-MANAGE.md` | — | 문서 | 완료(3판, 계획 재검증 대기) |
| TASK-02 | team-kit: 설정 단계 표·`settings`·바꾸기 모드(`--change`, 마지막 저장 전 쓰기 없음, 주소·로그인 단계 강제 진입, Notion 로그인 열쇠)·저장 값 시작·다시 연결, 계정 꺼짐 칸 표·Google 스킬 칸과 표시·`account` 명령(칸 단위 쓰기)·되돌리기, 꺼짐을 지키는 소비자, 해제 동작 라벨. **운영 원본은 고치지 않고 `HD` 임시 worktree에서**(design 7절) | CM-01~04(team-kit 몫), CM-02.AC-06·07, NFR / AT-CM-01~18·14b, 40~44 | `TK/lib/hermes_facility/`(`app_connect.py`, `connections.py`, `app_registry.py`, 필요하면 새 계정 켜고 끄기 함수 파일 하나), `TK/lib/hermes_packs/mac_apps/discovery.py`, `TK/lib/hermes_team_services/`(`news_watch.py`, `wait_jobs.py`, `personal_review.py`, `morning_report.py`·`report_review.py` 위치의 실제 파일), `TK/lib/hermes_execution/personal_scopes.py`, `TK/lib/hermes_packs/mail/mail_index.py`, `TK/lib/hermes_facility/connection_checks.py`, `TD/__init__.py`, `TK/tests/`·`TD` 시험(새), `HD/docs/연결-상태.md` | TASK-01 | 고위험(권한·자격 값) · 2 | 대기 |
| TASK-03 | 문: 라벨(설정 바꾸기·해제), `settings` 전달, 시놀로지·Notion 줄 합치기(design 4절 조건)와 `check` 전달, `change` 인자, 바꾸기 세션 보안 칸 누적, `account_*` 동작 전달 | CM-01, CM-03(문 몫), CM-04, NFR-CM-01 / AT-CM-20~28, 23b | `H/gate/connection_manager.py`, `H/gate/connection_runtime.py`, `H/tests/acceptance/test_conn_manage.py`(새), 필요하면 `H/gate/tests/` | TASK-01(계약은 design 2~4절로 확정) | 고위험 · 2 | 대기 |
| TASK-04 | 앱: "⋯" 메뉴, 해제 확인, 지금 설정 절·바꾸기, 바꾸기 세션 값 모으기(메모리만), 미리 선택, 확인 창 뒤 창 유지(먼저 재현·원인 기록) | CM-01.AC-02, CM-02.AC-01, CM-03(앱 몫), CM-05 / AT-CM-30~38 | `H/app/Sources/ConnectionsWindow.swift`, `ConnectionModels.swift`, `ConnectionInputField.swift`(필요 시), `AppDelegate.swift`(필요 시), `H/app/Tests/ConnectionsTests.swift` | TASK-01 | 고위험 · 2 | 대기 |
| TASK-05 | 서버 적용: [HEJO-CONNECTIONS design 7.2](../HEJO-CONNECTIONS-20261120/design.md#72-서버-적용-task-05) 절차 그대로(team-kit·team-delegation 보관본·sha256·교체·읽기 확인 → `HD` `./sync`·`./airport-check`·커밋 → 문 릴리스 → 한가할 때 재시작 → 로그 확인) | 전체 운영 | `TKL`, `HD`, 공용 릴리스, 운영 게이트웨이(재시작만) | TASK-02~04 검토 통과 | 고위험 · 3 | 대기 |
| TASK-06 | 앱 0.2.3(빌드 +1) 공개 준비(HEJO-CONNECTIONS TASK-06 절차) | CM-06 / M5 | `H/app/Resources/Info.plist`, 공개 절차 산출물 | TASK-05 | 고위험(공개) · 3 | 대기 |
| TASK-07 | 사장 확인 M1~M4, 현재 명세 반영 | 전체 | `H/docs/ARCHITECTURE.md`(필요 시), `HD/docs/연결-상태.md` | TASK-06 | — | 대기 |

## 병렬 갈래

있음. TASK-02(team-kit) / TASK-03(문) / TASK-04(앱)는 담당 파일이 겹치지 않고 각자 시험으로 완료를 확인할 수 있다. 사이 계약(`settings` 모양, `change` 값, `account_*` 동작 id·명령 인자, 줄 합치기 규칙, 라벨)은 design 2~4절로 확정해 문은 가짜 team-kit 명령, 앱은 가짜 문서로 시험한다.

| 갈래 | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|
| team-kit | TASK-02 영향 파일(`HD` worktree) | — | 어려움(여러 소비자, 바꾸기 모드) | AT-CM-01~18·14b·40~44 통과(worktree, 임시 홈), 착수 때 기준 sha256 일치 기록 |
| 문 | `H/gate/connection_manager.py`, `H/gate/connection_runtime.py`, 새 수락 시험 | — | 보통 | AT-CM-20~28·23b 통과, `bash scripts/test.sh`의 gate 부분 통과 |
| 앱 | `H/app/Sources/Connections*.swift`, `AppDelegate.swift`, `app/Tests/ConnectionsTests.swift` | — | 보통(확인 창 재현) | AT-CM-30~38 통과, 원인 기록 |
