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

## 2차 (2026-11-20) — 부분 완료

- 대상: hejo `961ea80`(TASK-03), `f06d8b2`(TASK-04), `f0ca282`(GAP 보고), 운영 저장소 worktree 브랜치 `hejo-conn-manage-20261120` `5e6c81cc`(TASK-02). 보고 [impl-report.md](impl-report.md).
- 검증 조건: 교차 모델. 고위험. 필요 증거 수준 2.
- 판정: **부분 완료.** TASK-02(wait_jobs.py 제외)·TASK-04는 설계대로 구현됐다. TASK-03은 설계 결함(V-3) 때문에 원래 목표인 "시놀로지 한 줄"을 실제 생산자 자료에서 채우지 못한다. TASK-02b는 기준 불일치로 대기다.

### 직접 확인한 것
| 항목 | 결과 |
|---|---|
| 검증 로그 | [확인] `product-full.log` 끝 OK(`bash scripts/test.sh`), `team-final.log` `5214 passed, 4 skipped`, `airport-final.log` 문서·칸 검사 PASS, `private-final.log` 지적 없음, `mutation-*.log` 4개 있음. 이 로그들은 `f0ca282`·`5e6c81cc` 기준이다. 그 뒤 hejo HEAD에는 다른 작업(HEJO-TODO-DRAWER)의 문서 커밋만 있어 코드 차이가 없다 |
| 문(TASK-03) | [확인] `PUBLIC_KEYS`에 `settings`·`step`·`committed`. `change`는 `app_connect`의 네 단계만 허용(문·`connection_runtime` 두 곳에서 검사). 보호 목록은 `change` 세션 동안 누적되고, 새 세션·`change` 없음·`committed`·failed/refused에서 다시 설정된다. 가림 값은 요청 시작 때 계산된다. 기기 끊김 때 정리(`server.py`). `account_*` 동작 전달·재시작 재개. 줄 합치기는 `group=='account'`와 조건 2(연결됨·진행 중·off)를 따른다 |
| 앱(TASK-04) | [확인] "⋯" 메뉴, 해제 확인 → 재확인 순서(`ConnectionsWindow.swift:135-138`), `change` 세션 값을 메모리에서 합쳐 보냄, `committed`·완료·실패·오류·창 닫기에서 지움, 지난 세션의 응답은 버림. 재확인·확인 창 뒤 `restoreFocus`(활성화 + 연결 창·입력 창 앞으로) |
| team-kit(TASK-02) | [확인] 새 `account_connect.py`, `app_connect.py` 바꾸기 모드, 꺼짐 칸 소비자(`hermes_execution/__init__.py`, `personal_scopes`, `mail_index`, `news_watch`, `morning_report`, `report_review`, `personal_review`, `connection_checks`). AT-CM-14b는 별도 프로세스에서 본체 `get_disabled_skill_names`를 실제로 실행한다(`test_conn_management.py:260`) |
| 창 사라짐 원인 | [부분 확인] 실제 `LAContext` 시험에서 확인 끝 직후 앱 비활성·창 key 잃음을 관측했다. 오래 숨는 것 자체는 재현하지 못했다. 고친 내용은 그 경계를 다룬다. 실물 확인은 M3 |
| 파생 줄 GAP | [확인] 구현 담당의 진단(`derived-row-gap.json`) 관측 `team:app-com.synology.CloudStation` + `app:com.synology.CloudStation` 두 줄. 원인은 team-kit `inventory()`가 명부 장착마다 `app-<키>` 줄(group mac)을 만드는데 design 3판 4절이 이를 빠뜨린 것이다 |
| TASK-02b | [확인] 운영 저장소 HEAD `7ae2b013`의 `wait_jobs.py`는 여전히 `bf1dd909…`, 실행본 `441a8501…`. 대기 유지 |

### 설계 적합성(4.2)
- 계약(`settings`·`committed`·`change`·`account_*`·보호 목록 경계)은 설계 3판과 일치한다. 책임 위치(동작·단계·꺼짐 칸 = team-kit, 합치기 = 문, 그리기 = 앱)도 지켰다.
- 설계 결함 1건(V-3)은 계획 담당 책임이다.

### 지적
| ID | 내용 | 등급 | 원인 | 조치 |
|---|---|---|---|---|
| V-3 | 앱 파생 줄 `team:app-<키>`가 앱 줄과 함께 남아 시놀로지(그리고 모든 장착 앱)가 두 줄 | 차단 | 설계·계약 오류(요구 불변) | design 4판 4절 "앱 파생 줄" 규칙, 수락 시험 4판 AT-CM-21b, handoff 3차 지시(TASK-03 보완 1) |
| V-1 | TASK-02b 기준 불일치 | 차단(그 부분만) | 환경 차이 | 유지(2차 지시 조건) |

### 범위 밖 관찰 (보고만)
- 첫 화면 캡처의 "메모"·"캘린더" 두 줄은 앱 줄과 Mac 권한 줄(`notes_read`·`calendar_read`)이다. 권한 줄에는 권한 요청·시스템 설정 동작이 따로 있어 이번 합치기 규칙(같은 연결)에 넣지 않았다. 원하면 별도 작업 후보.
