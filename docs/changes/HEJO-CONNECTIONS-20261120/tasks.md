# HEJO-CONNECTIONS 작업 분해

3판 · 2026-11-20(계획 검토 1·2회차 반영). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-CONNECTIONS.md](../../../tests/acceptance/HEJO-CONNECTIONS.md), 인계 [handoff.md](handoff.md). 약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 실행 중인 team-kit 원본.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 원인 조사·명세·설계·수락 시험 명세·인계(design·수락 시험 4판: 구현 검토 V-1·V-2) | 전체 | `H/docs/changes/HEJO-CONNECTIONS-20261120/`, `H/tests/acceptance/HEJO-CONNECTIONS.md` | — | 문서 | 완료(3판, 계획 재검증 대기) |
| TASK-02 | 문: 부분 실패 격리·로그·실제 이유·줄 줄이기·이어 하기 라벨 | HC-01, 02, 03.AC-01·02, 05.AC-01, 06.AC-03·04, NFR-HC-02 / AT-HC-01~11 | `H/gate/connection_manager.py`, `H/gate/server.py`, `H/gate/connections.py`(2.2a·2.2b), `H/tests/acceptance/test_connections_screen.py`(새), 필요하면 `H/gate/tests/` | TASK-01 | 고위험 · 2 | 검토 통과(TASK-03은 보완 1 `20adc4d` 포함, [verdict](verdict.md)) |
| TASK-03 | 앱: 실패 문장·표 유지·숨김 토글·입력 창 오류 분리·멈춤 원인 재현과 수정·sheet 확인 창·이어 하기 | HC-01.AC-04·05, 03.AC-03, 05, 06 / AT-HC-20~29 | `H/app/Sources/ConnectionsWindow.swift`, `ConnectionModels.swift`, `AppDelegate.swift`(필요 시), `H/app/Tests/ConnectionsTests.swift` | TASK-01(계약은 design 2절로 확정) | 고위험 · 2 | 검토 통과(TASK-03은 보완 1 `20adc4d` 포함, [verdict](verdict.md)) |
| TASK-04 | team-kit: 시놀로지 값 찾기(후보 규칙)·주소 오류 바로잡기·Obsidian 보관함 찾기·모든 안내 문장·처음부터 다시 시험. **운영 원본은 고치지 않고 `HD` 임시 worktree에서**(design 7.1) | HC-04, HC-06.AC-04 / AT-HC-40~52 | `HD` worktree의 `hermes/plugin-store/team-kit/lib/hermes_facility/`(`synology_setup.py`·`app_setup.py`·`app_connect.py`·`connection_guides.py`·`connection_secrets.py` 중 필요한 것)와 `hermes_packs/files_docs/files.py`(주소 칸별 검사 함수, design 4.1), 같은 worktree의 `team-kit/tests/`(새 시험), `docs/연결-상태.md` | TASK-01 | 고위험(자격 값) · 2 | 검토 2차 통과(보완 1, worktree `fe697e3b`, [verdict](verdict.md)) |
| TASK-05 | 서버 적용: 롤백 먼저 기록 → team-kit 보관본·sha256 확인·교체·읽기 확인 → `HD` `./sync`·커밋 → 문 릴리스·한가할 때 재시작 → 로그 확인(M2) (design 7.2) | HC-01~06 운영 / M1~M6 전제 | `TKL` 바꿀 파일, `HD`(sync·커밋), 공용 릴리스 폴더, 운영 게이트웨이(재시작만) | TASK-02~04 검토 통과 | 고위험 · 3 | 검토 3차 통과(공용 RELEASE `1c6b3e2`, 운영 저장소 `7ae2b013`, [verdict](verdict.md)) |
| TASK-06 | 앱 0.2.2 공개 준비: 버전 올림, `hejo-publish`로 새 `public`, 빌드·`hejo-ship prepare`, 서명 검사, 이 Mac 앱 교체 | HC-07 / M7 | `H/app/Resources/Info.plist`, 공개 절차 산출물 | TASK-05 | 고위험(공개) · 3 | 보완 지시 3으로 진행 |
| TASK-07 | 사장 확인 M1~M7, 현재 명세 반영 | 전체 | `H/docs/ARCHITECTURE.md`(필요 시), `HD/docs/연결-상태.md` | TASK-06 | — | 대기 |

## 병렬 갈래

있음. TASK-02(문) / TASK-03(앱) / TASK-04(team-kit)는 담당 파일이 겹치지 않고 각자 시험으로 완료를 확인할 수 있다. 계약(새 필드 `unread`·`hidden_by_default`, 실패 이유 코드, 라벨)은 design 2절로 확정해 앱은 가짜 문서로 시험한다.

| 갈래 | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|
| 문 | `H/gate/connection_manager.py`, `H/gate/server.py`, `H/gate/connections.py`, 새 수락 시험 | — | 보통 | AT-HC-01~11 통과, `bash scripts/test.sh`의 gate 부분 통과 |
| 앱 | `H/app/Sources/Connections*.swift`, `AppDelegate.swift`, `app/Tests/ConnectionsTests.swift` | — | 어려움(멈춤 원인 재현) | AT-HC-20~29 통과, 원인 기록 |
| team-kit | `HD` 임시 worktree의 `team-kit/lib/hermes_facility/*`, `team-kit/tests/*`, `docs/연결-상태.md` | — | 보통 | AT-HC-40~52 통과(worktree, 임시 홈), 착수 때 기준 sha256 일치 기록 |

## 발견했지만 범위 밖 (보고)
- Hermes 본체: 묶음 설정 요청이 직원 범위 밖에서 이름을 검사해 직원 전용 플러그인 묶음에 400(`web_routers/tools.py:355`). 본체 수정 금지라 `HD` 쪽 별도 작업 후보.
- team-kit: 적용 끝난 앱 연결의 오래된 되돌리기 기록(10분 기한 지남)이 읽힐 때까지 남는다. 한 직원 기록에 255시간 된 것이 있고 0600 파일이다. 목록 조회는 쓰지 않는다는 규칙 때문에 지우는 주체가 없다. 별도 작업 후보.
