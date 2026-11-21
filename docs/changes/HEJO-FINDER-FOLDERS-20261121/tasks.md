# HEJO-FINDER-FOLDERS 작업 분해

2판 · 2026-11-21(계획 검증 1회차 반영, [plan-review.md](plan-review.md)). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-FINDER-FOLDERS.md](../../../tests/acceptance/HEJO-FINDER-FOLDERS.md), 인계 [handoff.md](handoff.md). 약어는 design 머리말.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-FINDER-FOLDERS-20261121/`, `H/tests/acceptance/HEJO-FINDER-FOLDERS.md` | — | 문서 | 완료(계획 검증 통과, 수락 명세 3판 V-1 정정) |
| TASK-02 | team-kit: Finder 고르기 후보 규칙(design 2절), Finder 전용 빈 목록·잘림 안내, 시험. **`HD` 임시 worktree에서**(design 5절) | FF-01~04, NFR-FF-01·02 / AT-FF-01~14 | `TK/lib/hermes_facility/app_setup.py`, `TK/lib/hermes_facility/app_connect.py`(고르기 대기 응답의 hint 한 곳, design 2절 8항), `TK/tests/`(새 시험 파일) | TASK-01 | 일반 · 2 | 완료(검증 2차, 운영 저장소 브랜치 커밋 f3318572) |
| TASK-03 | 서버 적용: team-kit 실행본 교체(design 5절, HEJO-CONNECTIONS 7.2 team-kit 절차) → `HD` 기록. 문 릴리스·앱 교체 없음. 재시작은 TASK-02 판정에 따름 | 전체 운영 | `TKL`의 바뀐 파일, `HD` | TASK-02 검토 통과 + 별도 인계 | 일반 · 3 | 완료(검증 3차) |
| TASK-05 | team-kit: Finder 후보 NFC 정규화·중복 합치기·미리 선택(design 7.1). 같은 `HD` worktree 브랜치에 새 커밋 | FF-05 / AT-FF-15~17, AT-FF-12 재확인 | `TK/lib/hermes_facility/app_setup.py`, `TK/tests/test_finder_folders.py` | TASK-03 | 일반 · 2 | 완료(검증 4차, d7208c11) |
| TASK-06 | 앱: 연결 창 높이 규칙(design 7.2), 먼저 재현·원인 기록 | FF-06 / AT-FF-20~23 | `H/app/Sources/ConnectionsWindow.swift`, 필요하면 `H/app/Sources/AppDelegate.swift`, `H/app/Tests/ConnectionsTests.swift` | TASK-03 | 일반 · 2 | 완료(검증 4차, b21dd94) |
| TASK-09 | 앱: 세 손가락 탭 지연 측정 → 원인 구간 수정(REQ-FF-07) | FF-07 / AT-FF-30~32 | `H/app/Sources/ThreeTap*.swift`, `PetController.swift`, `AppDelegate.swift`, `ConversationView.swift`·`ConversationController.swift`·`ConversationModel`(갱신 묶음, 6차), `H/app/Tests/` | TASK-06 | 일반 · 2 | 부분 완료·종료(검증 7차 b3fc5cb: 열기 101.3·닫기 94.6ms, 수용은 사장 M7) |
| TASK-07 | 서버 적용: TASK-05의 `app_setup.py` 실행본 교체(3차 지시와 같은 절차) → `HD` 기록 | 운영 | `TKL`, `HD` | TASK-05 검토 통과 + 별도 인계 | 일반 · 3 | 완료(검증 5차, 운영 main d7208c11) |
| TASK-08 | 앱 0.2.4(빌드 6) 공개 후보 준비(design 7.3) | FF-06 / M4 | `H/app/Resources/Info.plist`, 공개 산출물 | TASK-06·09 검토 통과 + 별도 인계 + SLACK-MOVE와 순서 조율 | 일반(공개) · 2 | 대기 |
| TASK-04 | 사장 확인 M1~M7, 현재 명세 반영(`HD/docs/연결-상태.md`의 Finder 설명이 있으면) | 전체 | `HD/docs/연결-상태.md`(필요 시) | TASK-07·08 | — | 대기 |

## TASK-08 착수 조건 (2026-11-22, HEJO-SLACK-MOVE 세션과 조율)

hejo main에는 HEJO-SLACK-MOVE의 문 변경 커밋이 섞여 있다(`gate/local.py` 새 Unix 소켓 입구, `adapter.py`·`rooms.py`·`__init__.py`). 그 작업은 아직 완료 판정 전이다. 공개 후보는 main HEAD 전체를 담으므로, 그대로 만들면 검증 안 된 문 코드가 공개판에 들어간다.
- TASK-08 인계 전에 그 세션에 다시 연락해 판정 상태를 확인한다.
- 그 작업이 완료가 아니면 선택지는 둘이다: 공개 후보에서 문 변경을 빼기(그 커밋들 이전 지점 기준으로 이 작업 앱 커밋만 고르기), 또는 공개를 그 판정 뒤로 미루기. 고르는 것은 사장 결정이다. 두 세션 모두 아침 보고에 적는다.
- 게이트웨이 재시작이나 `install/hejo-release`를 하게 되면 미리 알린다(그쪽 문 변경은 운영에 적용하지 않은 상태로 둔다). 이 작업의 TASK-07은 둘 다 하지 않는다.

## 병렬 갈래

없음(갈래 3개 미만: 1판은 TASK-02 한 갈래. 4판은 TASK-05(team-kit)·TASK-06(앱) 두 갈래로, 파일이 겹치지 않아 한 지시에서 차례로 해도 되고 따로 해도 된다. TASK-07·08은 각각 선행 의존).
