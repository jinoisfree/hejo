# HEJO-TIDY 작업표

| 작업 | 요구·시험 | 담당 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|
| TASK-00 개발 저장소 미커밋 문서 로컬 커밋 | — | 계획 담당 | 없음 | 경미 | 완료(계획 담당, 아래 기록) |
| TASK-01 공개 통합(DISCORD-SECTIONS + TELEGRAM-REMOVE) | REQ-TIDY-01 · AT-TIDY-01~03 | 구현 | 없음 | 일반 · 2 | 완료(검증 3회, 후보 a90dc1d) |
| TASK-02 푸시 1(통합 커밋) | REQ-TIDY-01 | 사용자 승인 | TASK-01 계획 담당 검증 | — | 완료(원격 a90dc1d) |
| TASK-03 이전판 사본 정리 + 절차 + V-3 + V-4 | REQ-TIDY-02~05 · AT-TIDY-04~13 | 구현 | TASK-02(원격 반영) | 일반 · 2 | 완료(검증 4회, 원격 878ce94) |
| TASK-04 릴리스 준비(R·public ref·빌드·prepare) → 푸시 2 → 게시(사용자 `hejo-ship publish`) → 게시 관측 → M-01 | REQ-TIDY-06 AC-01~03, 02.AC-08 · AT-TIDY-14·14b, M-01 | 구현 + 사용자 | TASK-06 푸시 3 반영(사용자 결정 2026-11-26: 릴리스는 모든 작업 뒤 한 번) | 일반 · 4 | 준비 완료(검증 7회, R 2dea766) → 푸시 4 승인 대기 → 사장 게시 → 14b·M-01 |
| TASK-05 코드 정리 감사(코드 변경 없음, 추적 파일 기준 범위) | REQ-TIDY-07.AC-01 · AT-TIDY-15 | 구현 | TASK-03 검증 → 푸시 2(TASK-03 반영) | 경미(읽기) | 완료(검증 5회, [cleanup-audit.md](cleanup-audit.md)) |
| TASK-06 승인 항목 삭제 → 푸시 3 | REQ-TIDY-07.AC-02·03 · AT-TIDY-16 | 구현 | TASK-05 계획 담당 승인 | 일반 · 2 | 완료(검증 6회, 원격 4443ff2) |
| TASK-07 현재 명세 반영 | ARCHITECTURE 3절 관제 화면 행 수명·6절 갱신 행(이전판 사본 휴지통), 칸 표 정비 격납고 행 원본 위치에 `tests/`·`githooks/` 추가(D-09, 사용자 결정), `docs/spec/current/hejo-thread-status.md`(REQ-AS-02 공백 규칙), 새 `docs/spec/current/hejo-update.md`는 만들지 않음(기존 원본에 기록) | 계획 담당 | 각 검증 완료 | 경미 | 대기 |

- HEJO-ALERT-SEEN tasks.md의 V-3·V-4는 이 작업으로 옮겼다(REQ-TIDY-04·05).
- 순서(사용자 결정 2026-11-26): TASK-03 → 푸시 2 → TASK-05 → TASK-06 → 푸시 3 → TASK-04 릴리스(마지막에 한 번, 모든 변경을 담음) → M-01 → TASK-07.
- 푸시는 세 번이고 릴리스 버전 커밋 푸시가 하나 더 있다. 각 푸시 직전에 `git ls-remote github refs/heads/main`으로 fast-forward를 다시 확인한다. 원격이 움직였으면 merge 후 재시험한다.

## TASK-00 기록

- 개발 main의 미커밋 문서(다른 작업의 변경 문서·수락 시험 명세·현재 명세 초안)를 `git commit --only`로 로컬 커밋한다. 개발 main은 공개판과 이력이 무관하므로 푸시하지 않는다.

## 기술 부채

- TD-TIDY-01: `schemas/hejo-wire-v1.json` `hookMetadata` 정의는 저장소 안에서 참조되지 않는다. 공개 통신 규격이라 외부 독자를 확인하기 전까지 유지한다(검증 5회).
