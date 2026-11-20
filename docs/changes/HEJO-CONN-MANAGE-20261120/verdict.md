# HEJO-CONN-MANAGE 검증 판정

## 1차 (2026-11-20) — 미완료(구현 보류, 정당한 멈춤)

- 대상: 구현 보고 [impl-report.md](impl-report.md)(미추적), hejo HEAD `251efabd2baa08f423e0da6b46e14fb8de582071`, `<운영 저장소>` HEAD `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`.
- 검증 조건: 교차 모델(계획·검증 Claude, 구현 Codex). 고위험.
- 판정: **미완료.** 제품 변경 없음, 수락 시험 미작성·미실행. 구현 담당의 멈춤은 인계서 9항의 명시적 중단 조건에 맞는다(구현 오류 아님).

### 직접 확인한 것
| 항목 | 결과 |
|---|---|
| 제품 코드 변경 | [확인] `git diff --stat 251efab` 작업 트리 변경은 다른 작업 `HEJO-TODO-DRAWER` 문서 5개와 이 작업의 미추적 `impl-report.md`뿐. `gate/`·`app/` 변경 없음 |
| `wait_jobs.py` 기준 | [확인] `<운영 저장소>` HEAD 파일 sha256 `bf1dd909…`, 작업본·실행본 모두 `441a8501…`. 차이는 hejo 대기 작업의 origin 비교·`prune` 호출 7줄(다른 작업의 미커밋 변경, 이미 실행본에 반영됨). 보고서 표와 일치 |
| TASK-02 나머지 영향 파일 | [확인] `app_connect.py`, `connections.py`, `app_registry.py`, `discovery.py`, `news_watch.py`, `personal_review.py`, `morning_report.py`, `report_review.py`, `personal_scopes.py`, `mail_index.py`, `connection_checks.py`, `hermes_execution/__init__.py` 12개 모두 HEAD = 실행본(sha256 앞 12자리 대조) |
| team-delegation `__init__.py` | [확인] `hermes/plugin-store/team-delegation/__init__.py`는 `../team-kit/lib/hermes_execution/__init__.py`로 가는 심볼릭 링크다. 설계의 `TD/__init__.py`는 실제로 이 team-kit 파일이다(설계 표기 보완 대상, 기능 영향 없음) |
| 개인값 | 보고서·증거 경로에 개인 경로 없음. `scan_private` 로그는 보고서 기록대로(재실행 안 함, 문서만 추가된 상태) |

### 설계 적합성(4.2)
- 설계 자체의 결함은 없다. 다만 착수 조건이 파일 하나의 외부 상태에 전체 TASK-02를 묶어, 기준이 맞는 나머지 작업까지 막았다. 원인 분류: **환경·외부 시스템 차이**(다른 작업의 미커밋 변경). 계획 쪽 보완: 그 파일만 뒤로 미루는 순서로 바꾼다.

### 지적
| ID | 내용 | 등급 | 원인 | 조치 |
|---|---|---|---|---|
| V-1 | `wait_jobs.py`의 Google 꺼짐 검사(design 3.1 표 "`wait_jobs.account`")는 기준 불일치로 지금 시작할 수 없다 | 차단(그 부분만) | 환경 차이 | TASK-02b로 분리. `<운영 저장소>` HEAD가 실행본과 같아진 뒤(다른 작업의 커밋 또는 매일 자동 기록 커밋) 시작 |
| V-2 | 설계 표기 `TD/__init__.py`는 심볼릭 링크 | 권고 | 설계 표기 | handoff 9항에 실제 파일(`team-kit/lib/hermes_execution/__init__.py`) 명시 |

### 다음
보완 지시(handoff 2차 지시 절): TASK-02(wait_jobs.py 제외)·03·04를 지금 진행, TASK-02b는 조건 충족 뒤.
