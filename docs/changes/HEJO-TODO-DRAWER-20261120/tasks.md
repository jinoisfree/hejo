# HEJO-TODO-DRAWER 작업 분해

1판 · 2026-11-20 · 명세 [spec.md](spec.md) · 설계 [design.md](design.md) · 수락 시험 [HEJO-TODO-DRAWER.md](../../../tests/acceptance/HEJO-TODO-DRAWER.md) · 인계 [handoff.md](handoff.md)
약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 운영 공항 team-kit 원본.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-TODO-DRAWER-20261120/`, `H/tests/acceptance/HEJO-TODO-DRAWER.md` | — | 문서 | 완료(1판) |
| TASK-02 | team-kit 읽기 명령 `hermes-deadlines list --json` + 읽기 함수. **운영 원본을 고치지 않고 `HD` 임시 worktree에서** | TD-05.AC-01·04·05 / AT-TD-01~05 | `HD` worktree의 `hermes/bin/hermes-deadlines`(새), `hermes/plugin-store/team-kit/lib/hermes_team_services/deadline_watch.py`(읽기 함수 추가만), `team-kit/tests/test_deadline_list.py`(새) | TASK-01 | 일반 · 2 | 대기 |
| TASK-03 | 문: `gate/deadlines.py`, `server.py` 분배(비동기·공유 실행), 규격 `deadlines`·`deadlines_status` | TD-05, NFR-TD-01·02 / AT-TD-10~17 | `H/gate/deadlines.py`(새), `H/gate/server.py`, `H/schemas/hejo-wire-v1.json`, `H/gate/README.md`(한 줄), `H/tests/acceptance/test_deadlines.py`(새) | TASK-01(명령 출력 계약은 design 2절로 확정, 가짜 명령으로 시험) | 일반 · 2 | 대기 |
| TASK-04 | 앱: `TodoDrawerModel`·`TodoDrawerView`, 알약 `Action.drawer`·닫기 표시, `PetPlacement.leading`·늘림/덮기, 웹 칸과 함께, 열림 기억, 마감 요청 주기 | TD-01~04, TD-06, NFR-TD-03 / AT-TD-20~38 | `H/app/Sources/TodoDrawer*.swift`(새), `IslandModel.swift`, `IslandView.swift`, `PetLayout.swift`, `PetController.swift`, `PetView.swift`(칸 배치), `ConversationView.swift`, `ConversationController.swift`, `LocalStore.swift`, `AppDelegate.swift`(연결 배선만), `H/app/Tests/TodoDrawerTests.swift`(새), 기존 시험 파일 갱신 | TASK-01(규격은 design 4절로 확정, 가짜 문으로 시험) | 일반 · 2 | 대기 |
| TASK-05 | 서버 적용: 롤백 먼저 기록 → team-kit 새 파일 보관본·sha256 확인·교체 → `HD` `./airport-check`·`./sync`·커밋 → 문 릴리스·한가할 때 재시작 → M1·M2 | TD-07.AC-01 / M1·M2 | `TKL` 바꿀 파일, `<HOME>/bin/hermes-deadlines`, `HD`(sync·커밋), 공용 릴리스 폴더, 운영 게이트웨이(재시작만) | TASK-02·03 검토 통과 | 고위험(운영 시설) · 3 | 대기(별도 보완 지시로 허가) |
| TASK-06 | 앱 공개 후보: 버전 올림, `hejo-publish`, 빌드·`hejo-ship prepare`, 서명 검사, 이 Mac 앱 교체 | TD-07.AC-02 | `H/app/Resources/Info.plist`, 공개 절차 산출물 | TASK-04 검토 통과, TASK-05 | 고위험(공개) · 3 | 대기(별도 보완 지시로 허가) |
| TASK-07 | 사장 확인 M3, 현재 명세 반영(ARCHITECTURE 문 절에 마감 읽기 한 줄) | 전체 | `H/docs/ARCHITECTURE.md` | TASK-06 | — | 대기 |

이번 인계는 TASK-02·03·04다. TASK-05·06은 검토 통과 뒤 별도 보완 지시로 허가한다.

## 병렬 갈래

있음. TASK-02(team-kit), TASK-03(문), TASK-04(앱)는 담당 파일이 겹치지 않는다. 각자 가짜 명령·가짜 문·가짜 홈으로 따로 시험해 완료를 확인할 수 있다. 계약(명령 출력, 프레임)은 design 2·4절로 확정되어 있다.

| 갈래 | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|
| team-kit | `HD` worktree의 `hermes/bin/hermes-deadlines`, `deadline_watch.py`(읽기 함수), `team-kit/tests/test_deadline_list.py` | — | 단순 | AT-TD-01~05 통과(worktree, 임시 홈), 착수 때 기준 sha256 기록 |
| 문 | `H/gate/deadlines.py`, `H/gate/server.py`, `H/schemas/hejo-wire-v1.json`, `H/gate/README.md`, `H/tests/acceptance/test_deadlines.py` | — | 보통 | AT-TD-10~17 통과 |
| 앱 | `H/app/Sources/` 위 목록, `H/app/Tests/` | — | 어려움(창 배치·움직임) | AT-TD-20~38 통과, `bash scripts/test.sh` 앱 부분 통과 |

## 동시 수정

HEJO-CONN-MANAGE(같은 날 계획, 미추적 문서)도 다음 파일을 바꿀 수 있다.
- `H/gate/server.py`
- `H/schemas/hejo-wire-v1.json`
- `H/app/Sources/AppDelegate.swift`
- team-kit

두 작업의 구현이 동시에 돌면 이 파일들은 한 작업씩 병합한다. 착수 때 base 커밋이 바뀌었으면 겹친 파일의 변경을 확인하고 기록한다. team-kit 쪽은 겹치는 파일이 없다(CONN-MANAGE는 `hermes_facility/`, 이 작업은 `hermes_team_services/deadline_watch.py`와 새 `bin` 파일).
