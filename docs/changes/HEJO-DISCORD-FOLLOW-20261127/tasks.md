# HEJO-DISCORD-FOLLOW 작업

| TASK | 내용 | REQ/AC · 시험 | 선행 | worktree(로컬 경로는 `AGENTS.local.md`) | 상태 |
|---|---|---|---|---|---|
| TASK-01 | 공개판: 디스코드 문 고침·보관·삭제·시작 맞추기, 삭제 알림 호출, 자동 보관 시간, 앱 안내 문구, 시험 | REQ-DF-01~05·07 · AT-DF-01~17·19·20 | 없음 | 공개 `hejo-discord-follow-public-20261127` (시작 `github/main` `db5a446`) | 완료 |
| TASK-02 | 운영 문 줄: TASK-01의 `gate/discord.py`·`gate/adapter.py` 변경과 문 시험을 옮김 | REQ-DF-06 AC-21 · AT-DF-21 | TASK-01 | 운영 `hejo-discord-follow-ops-20261127` (시작 `c2b292d`) | 완료 |
| TASK-03 | 서버 사본 확인(AT-DF-18) → 릴리스·설치·재시작 1회 → 확인 | REQ-DF-04 AC-18 · REQ-DF-06 AC-22 · AT-DF-18·22 | TASK-02 | 운영 worktree + 서버 | 완료 |
| 사장 | 휴대폰 관측 | AC-23 · AT-DF-23 | TASK-03 | — | 대기 |
| 계획 담당 | 판정 뒤 현재 명세 반영: ARCHITECTURE 61행(디스코드 문이 고침·삭제·종결 보관을 따라감), 앱 안내 권한 | — | 판정 | — | 완료 |

병렬 갈래: 없음(갈래 3개 미만: TASK-02는 TASK-01 뒤, TASK-03은 TASK-02 뒤).
