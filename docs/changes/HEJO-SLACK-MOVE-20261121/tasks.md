# HEJO-SLACK-MOVE 작업 분해

1판 · 2026-11-21. 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-SLACK-MOVE.md](../../../tests/acceptance/HEJO-SLACK-MOVE.md), 인계 [handoff.md](handoff.md). 약어는 spec 머리말과 같다.

순서 원칙(사장 강조): 문의 입구 → 인스타 → 나머지. 전환은 모든 작업이 끝난 뒤 한 번.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 조사·명세·설계·수락 시험 명세·인계 | 전체 | `H/docs/changes/HEJO-SLACK-MOVE-20261121/`, `H/tests/acceptance/HEJO-SLACK-MOVE.md` | — | 문서 | 완료(1판, 계획 검증 대기) |
| TASK-02 | 문: 서버 안 전용 입구(글 올리기·고치기·지우기·스레드 읽기·방 만들기)와 규격 파일 | SM-01, SM-04.AC-02 / AT-SM-01~07, 30 | `H/gate/`의 새 모듈 하나, `H/gate/server.py`(소켓 시작·끝), `H/schemas/hejo-local-v1.json`, `H/gate/README.md`, `H/tests/acceptance/test_slack_move_gate.py`(입구 부분) | — | 고위험(새 쓰기 권한) · 2 | 대기 |
| TASK-03 | 문: 예약 보고의 방 대상, 방 스레드 주인 | SM-02, SM-03 / AT-SM-10~12, 20~22 | `H/gate/__init__.py`, `H/gate/rooms.py`, `H/gate/adapter.py`(`receive`의 받는 직원 계산), `H/gate/README.md`, `H/tests/acceptance/test_slack_move_gate.py`(대상·주인 부분) | — | 일반 · 2 | 대기 |
| TASK-04 | team-kit: `delivery.platform` 읽기, 직책 키 받을 곳 풀이, 공통 전송(Slack·hejo), 상태 항목의 문 표시 규칙, 꾸밈 대응 | SM-05 / AT-SM-40~45(공통 전송을 쓰는 가짜 호출자로) | `TS/`의 공통 전송 자리(지금 `learning_report.py`·`learning.py`의 전송·받을 곳 함수와 새 모듈), `TS/slack_blocks.py`를 부르는 자리, 그 시험 | TASK-02의 규격 파일(가짜 입구로 시험) | 고위험(모든 보고의 길) · 2 | 대기 |
| TASK-05 | 인스타·네이버톡을 공통 전송으로: 고객별 스레드, 초안·버튼, 승인 판정, 훅, 요약, 상태, 피드, 학습 보고, 네이버톡 다리. 코드 상수 제거 | SM-06 / AT-SM-50~59 | `CP/plugins/instagram-dm/`(`watch.py`, `__init__.py`, `feed_runner.py`, `learning_report.py`, `naver_talk.py`), `CP/scripts/naver-talk/bridge.py`, 그 시험 | TASK-04 | 고위험(고객 응대 승인 판정) · 2 | 대기 |
| TASK-06 | 나머지 직접 전송 경로를 공통 전송으로(design 4.2 표에서 인스타·네이버톡 제외 전부, 착수 때 더 찾은 줄 포함). `file_link`의 hejo 첨부 | SM-07 / AT-SM-41(전 줄), 60~62 | design 4.2 표의 `TS/`·`TKL/hermes_packs/`·`TKL/hermes_governance/proposal_decisions.py` 파일과 그 시험 | TASK-04 | 고위험 · 2 | 대기 |
| TASK-07 | 들어오는 규칙의 hejo 대응: 예약 관리 도구, 금고 백업 승인, 진단 사용량 조회·진단 요청 접수, 보고 검토·스타터·조직개편안 답글, 대기 작업의 방 글쓴이 | SM-08.AC-01~04 / AT-SM-63~66, 68 | `TS/cron_guard.py`, `TS/vault_backup_approval.py`, `TKL/hermes_packs/native_tools/__init__.py`, `TKL/hermes_packs/diagnosis/diagnosis_requests.py`의 접수 검사, `TS/report_review.py`·`starter_plugins.py`·`org_review.py`의 답글 인식 부분, `TS/wait_jobs.py`, `TK/__init__.py`의 훅 연결, 그 시험 | TASK-04, TASK-06(같은 파일을 TASK-06이 먼저 전송 쪽을 고침) | 고위험 · 2 | 대기 |
| TASK-08 | 도구 묶음: 조립기가 `platform_toolsets.hejo`를 만듦, 앱 설치 때 hejo에도 묶음 추가, 실제 도구 집합 비교 | SM-09 / AT-SM-70~72 | `TKL/hermes_facility/config_assembly.py`와 그 시험 | — | 고위험(직원 권한 범위) · 2 | 대기 |
| TASK-09a | 계획 담당: 일 넘기기(프로젝트 허브) 흐름 조사, design 4.5·REQ-SM-08.AC-05·AT-SM-67 보완 | SM-08.AC-05 | 계획 문서 | — | 문서 | 대기(계획 담당) |
| TASK-09 | 일 넘기기 안내·프로젝트 허브의 hejo 대응 | SM-08.AC-05 / AT-SM-67 | TASK-09a가 정함 | TASK-09a, TASK-04 | TASK-09a가 정함 | **차단(설계 미확정)** |
| TASK-10 | 서버 적용과 전환: 코드 적용(동작 불변) → 하루 회귀 관찰 → 대조표·방 표 사장 확인 → 전환(design 7절) → 확인 | SM-04, SM-10, SM-11 / M1~M5, M7 | `TK`, `CP`, 공용 릴리스(문), `<HOME>/owner/policy.yaml`, `<HOME>/owner/vault.yaml`, `<HOME>/config.yaml`, 조립 결과, `HD`(`./sync`·`./airport-check`·커밋) | TASK-02~09, 사장 승인 | 고위험(운영) · 3·4 | 대기(별도 인계) |
| TASK-11 | 다음 날 관찰(M6), 현재 명세 반영(`ARCHITECTURE.md` 3·4·7절의 입구·방 대상·Slack 은퇴 단계, `gate/README.md`, `HD` 문서) | SM-11.AC-02·05 / M6 | `H/docs/ARCHITECTURE.md`, `HD` 문서 | TASK-10 | 문서 | 대기 |

## 병렬 갈래

있음. 갈래끼리 담당 파일이 겹치지 않고 각자 시험으로 완료를 확인할 수 있다. 사이 계약은 design 3.1(입구 규격), 3.3(주인 규칙), 4.1(직책 키와 금고 키 이름), 4.3(꾸밈 대응)으로 고정했다. team-kit 쪽은 규격 파일대로 만든 가짜 입구로 시험한다.

| 갈래 | TASK | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|---|
| 문·입구 | 02 | `H/gate/` 새 모듈, `server.py`, `schemas/hejo-local-v1.json`, 시험 파일의 입구 부분 | — | 보통 | AT-SM-01~07·30 통과, `bash scripts/test.sh`의 gate 부분 통과, `scan_private` 통과 |
| 문·대상과 주인 | 03 | `H/gate/__init__.py`, `rooms.py`, `adapter.py` | — | 보통 | AT-SM-10~12·20~22 통과, 같은 전체 검사 |
| team-kit·공통 전송 | 04 | `TS/` 공통 전송 자리 | 규격 파일(TASK-02 첫 커밋) | 어려움 | AT-SM-40~45 통과, `./airport-check` 통과 |
| team-kit·도구 묶음 | 08 | `config_assembly.py` | — | 보통 | AT-SM-70~72 통과 |

TASK-02와 03은 같은 시험 파일의 다른 부분을 쓴다. 한 사람이 이어서 하거나, 따로 하면 시험 파일을 둘로 나눈다(`test_slack_move_gate.py`, `test_slack_move_rooms.py`).

TASK-04 뒤에는 05(직원 플러그인 파일) / 06(team-kit 전송 쪽) 두 갈래가 겹치지 않는다. 07은 06과 같은 파일을 고치므로 06 뒤에 한다. 인스타가 가장 중요하므로 한 사람이 하면 04 → 05 → 06 → 07 순서다.
