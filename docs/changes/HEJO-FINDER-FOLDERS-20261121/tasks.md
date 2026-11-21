# HEJO-FINDER-FOLDERS 작업 분해

2판 · 2026-11-21(계획 검증 1회차 반영, [plan-review.md](plan-review.md)). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-FINDER-FOLDERS.md](../../../tests/acceptance/HEJO-FINDER-FOLDERS.md), 인계 [handoff.md](handoff.md). 약어는 design 머리말.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-FINDER-FOLDERS-20261121/`, `H/tests/acceptance/HEJO-FINDER-FOLDERS.md` | — | 문서 | 완료(계획 검증 통과, 수락 명세 3판 V-1 정정) |
| TASK-02 | team-kit: Finder 고르기 후보 규칙(design 2절), Finder 전용 빈 목록·잘림 안내, 시험. **`HD` 임시 worktree에서**(design 5절) | FF-01~04, NFR-FF-01·02 / AT-FF-01~14 | `TK/lib/hermes_facility/app_setup.py`, `TK/lib/hermes_facility/app_connect.py`(고르기 대기 응답의 hint 한 곳, design 2절 8항), `TK/tests/`(새 시험 파일) | TASK-01 | 일반 · 2 | 완료(검증 2차, 운영 저장소 브랜치 커밋 f3318572) |
| TASK-03 | 서버 적용: team-kit 실행본 교체(design 5절, HEJO-CONNECTIONS 7.2 team-kit 절차) → `HD` 기록. 문 릴리스·앱 교체 없음. 재시작은 TASK-02 판정에 따름 | 전체 운영 | `TKL`의 바뀐 파일, `HD` | TASK-02 검토 통과 + 별도 인계 | 일반 · 3 | 완료(검증 3차) |
| TASK-05 | team-kit: Finder 후보 NFC 정규화·중복 합치기·미리 선택(design 7.1). 같은 `HD` worktree 브랜치에 새 커밋 | FF-05 / AT-FF-15~17, AT-FF-12 재확인 | `TK/lib/hermes_facility/app_setup.py`, `TK/tests/test_finder_folders.py` | TASK-03 | 일반 · 2 | 대기 |
| TASK-06 | 앱: 연결 창 높이 규칙(design 7.2), 먼저 재현·원인 기록 | FF-06 / AT-FF-20~23 | `H/app/Sources/ConnectionsWindow.swift`, 필요하면 `H/app/Sources/AppDelegate.swift`, `H/app/Tests/ConnectionsTests.swift` | TASK-03 | 일반 · 2 | 대기 |
| TASK-07 | 서버 적용: TASK-05의 `app_setup.py` 실행본 교체(3차 지시와 같은 절차) → `HD` 기록 | 운영 | `TKL`, `HD` | TASK-05 검토 통과 + 별도 인계 | 일반 · 3 | 대기 |
| TASK-08 | 앱 0.2.4(빌드 6) 공개 후보 준비(design 7.3) | FF-06 / M4 | `H/app/Resources/Info.plist`, 공개 산출물 | TASK-06 검토 통과 + 별도 인계 | 일반(공개) · 2 | 대기 |
| TASK-04 | 사장 확인 M1~M6, 현재 명세 반영(`HD/docs/연결-상태.md`의 Finder 설명이 있으면) | 전체 | `HD/docs/연결-상태.md`(필요 시) | TASK-07·08 | — | 대기 |

## 병렬 갈래

없음(갈래 3개 미만: 1판은 TASK-02 한 갈래. 4판은 TASK-05(team-kit)·TASK-06(앱) 두 갈래로, 파일이 겹치지 않아 한 지시에서 차례로 해도 되고 따로 해도 된다. TASK-07·08은 각각 선행 의존).
