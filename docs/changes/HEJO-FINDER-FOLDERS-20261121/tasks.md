# HEJO-FINDER-FOLDERS 작업 분해

2판 · 2026-11-21(계획 검증 1회차 반영, [plan-review.md](plan-review.md)). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-FINDER-FOLDERS.md](../../../tests/acceptance/HEJO-FINDER-FOLDERS.md), 인계 [handoff.md](handoff.md). 약어는 design 머리말.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-FINDER-FOLDERS-20261121/`, `H/tests/acceptance/HEJO-FINDER-FOLDERS.md` | — | 문서 | 완료(계획 검증 통과, 수락 명세 3판 V-1 정정) |
| TASK-02 | team-kit: Finder 고르기 후보 규칙(design 2절), Finder 전용 빈 목록·잘림 안내, 시험. **`HD` 임시 worktree에서**(design 5절) | FF-01~04, NFR-FF-01·02 / AT-FF-01~14 | `TK/lib/hermes_facility/app_setup.py`, `TK/lib/hermes_facility/app_connect.py`(고르기 대기 응답의 hint 한 곳, design 2절 8항), `TK/tests/`(새 시험 파일) | TASK-01 | 일반 · 2 | 부분 완료(검증 1차: 구현 적합, 커밋·AT-FF-12 재확인 대기) |
| TASK-03 | 서버 적용: team-kit 실행본 교체(design 5절, HEJO-CONNECTIONS 7.2 team-kit 절차) → `HD` 기록. 문 릴리스·앱 교체 없음. 재시작은 TASK-02 판정에 따름 | 전체 운영 | `TKL`의 바뀐 파일, `HD` | TASK-02 검토 통과 + 별도 인계 | 일반 · 3 | 대기 |
| TASK-04 | 사장 확인 M1~M3, 현재 명세 반영(`HD/docs/연결-상태.md`의 Finder 설명이 있으면) | 전체 | `HD/docs/연결-상태.md`(필요 시) | TASK-03 | — | 대기 |

## 병렬 갈래

없음(갈래 3개 미만: 코드 변경은 TASK-02 team-kit 한 갈래뿐, TASK-03·04는 TASK-02 결과에 선행 의존).
