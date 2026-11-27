# HEJO-RESULT-DONE 작업

| TASK | 내용 | REQ/AC · 시험 | 선행 | worktree(로컬 경로는 `AGENTS.local.md`) | 상태 |
|---|---|---|---|---|---|
| TASK-01 | 공개판: 문 `assess`·`questions`·`summary`, 안내판 필드, 앱 해석, 시험 | REQ-RD-01~03 · AT-RD-01~10(08b 포함) | 없음 | 공개 `hejo-result-done-public-20261127` (시작 `github/main` `63e7bf9`) | 완료 |
| TASK-02 | 운영 문 줄: TASK-01의 문·안내판 변경과 문 시험을 옮김 | REQ-RD-04 AC-11 · AT-RD-11 | TASK-01 | 운영 `hejo-result-done-ops-20261127` (시작 `f7fdc1a`) | 완료 |
| TASK-03 | 실제 기록 사본 비교 → 문 릴리스·설치·재시작 1회 → 확인 | REQ-RD-04 AC-12·13 · AT-RD-12·13 | TASK-02 | 운영 worktree + 서버 | 완료 |
| TASK-04 | 앱 0.2.10 버전 커밋·빌드 | REQ-RD-05 · AT-RD-15 | TASK-01 | 공개 worktree | 완료 |
| 사장 | 앱 릴리스 게시·설치, 실물 관측 | AC-14 · AT-RD-14 | TASK-03·04 | — | 대기 |
| 계획 담당 | 검증 판정 뒤 `docs/spec/current` 반영 | — | 판정 | — | 완료 |

병렬 갈래: 없음(갈래 3개 미만: TASK-02·03·04가 모두 TASK-01 뒤이고 TASK-03은 TASK-02 뒤).
