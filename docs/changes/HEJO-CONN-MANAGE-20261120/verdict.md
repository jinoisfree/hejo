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

## 3차 (2026-11-20) — 부분 완료(TASK-02~04 통과, TASK-02b 대기, 운영 적용 전)

- 대상: hejo `131e47f`(TASK-03 보완 1), 이전 통과분 `961ea80`·`f06d8b2`, 운영 저장소 worktree `5e6c81cc`(변경 없음 확인).
- 판정: V-3 해소. **TASK-02(wait_jobs 제외)·TASK-03·TASK-04 검토 통과.** 작업 전체는 부분 완료다. 남은 것은 TASK-02b(V-1, 환경 차이)와 TASK-05~07(운영 적용·공개·사장 확인)이다.

### 직접 확인한 것
| 항목 | 결과 |
|---|---|
| 변경 | [확인] `131e47f`는 `gate/connection_manager.py`(+11/-4), `tests/acceptance/test_conn_manage.py`(AT-CM-21b), impl-report만 바꿨다. team-kit worktree는 `5e6c81cc` 그대로다 |
| 설계 4판 4절 | [확인] 같은 직원 표(`items`)에서 `team:app-<connection_key>`이고 `reason == APP_CONNECTED`일 때만 합친다. `CONFIG_DRIFT`는 남는다. 직접 확인 기록은 계정 줄과 같은 규칙으로 앱 줄에 쓴다. 파생 줄만 합칠 때는 `check` 동작을 붙이지 않는다 |
| 시험 | [확인] `v3-gate.log` 193 passed, `v3-product-full.log` 404 passed(`bash scripts/test.sh`). `v3-mutation-drift.log`: 드리프트 합치기 변이에서 AT-CM-21b가 실패(1 failed)로 잡음. `v3-red.log`는 수정 전 실패 기록 |
| 생산자 진단 | [확인] `v3-derived-row.log` `observedCount: 1`, `oneRowCriterionMet: true`. 끝의 `result` 문구("GAP…")는 진단 스크립트의 고정 문자열이라 판정에 쓰지 않는다(보고서 설명과 같음) |
| 작업 트리 | [확인] hejo `git status` 깨끗 |
| TASK-02b | [확인] 운영 저장소 HEAD의 `wait_jobs.py` `bf1dd909…` ≠ 실행본 `441a8501…`. 대기 유지 |

### 설계 적합성(4.2)
설계 4판과 일치한다. 책임 위치는 문 한 곳이고, team-kit `status` 출력은 그대로다.

### 남은 조건
| ID | 내용 | 원인 | 조치 |
|---|---|---|---|
| V-1 | TASK-02b(Google 끈 직원의 대기 작업 `wait_jobs.account`) | 환경 차이(다른 작업 미커밋) | 운영 저장소 HEAD와 실행본이 같아진 뒤(매일 자동 기록 커밋 등) 진행 |
| — | TASK-05 서버 적용, TASK-06 0.2.3 공개 준비, TASK-07 사장 확인 M1~M5 | 계획된 다음 단계 | 사장 결정(아래) 뒤 진행 |

### 사장 결정이 필요한 것
TASK-02b 없이 서버에 먼저 적용하면, Google을 해제한 직원도 **대기 작업(기다렸다가 메일 확인하기)** 경로에서는 Google을 계속 쓸 수 있다(spec REQ-CM-02.AC-07 일부 미충족). 선택지: (가) TASK-02b 기준이 맞을 때까지 기다렸다가 함께 적용(권고) (나) 지금 TASK-05를 적용하고 Google 해제는 TASK-02b 적용 전까지 쓰지 않기.

## 4차 (2026-11-21) — TASK-02b 통과, 작업 전체는 부분 완료(TASK-05~07 남음)

- 대상: 운영 저장소 worktree 브랜치 `hejo-conn-manage-20261120` `ae04a715`(코드), `fe7f0c95`(merge, 부모 `5e6c81cc`·`dfb469d3`), hejo `96be814`(보고).
- 판정: **TASK-02b 검토 통과.** V-1 해소. TASK-02~04·02b 모두 통과했다. 남은 것은 TASK-05(합동 서버 적용)·06(공개)·07(사장 확인)이다.

### 직접 확인한 것
| 항목 | 결과 |
|---|---|
| 변경 | [확인] `ae04a715`는 `wait_jobs.py`(+8/-3)와 `test_conn_management.py`(+52)만 바꿨다. merge로 들어온 다른 작업 문서는 운영 저장소 main(`dfb469d3`) 내용 그대로다 |
| 설계 3.1 | [확인] `account()`는 `gmail.enabled is False`면 `GOOGLE_DISABLED`를 낸다. `gmail_service()`·`evaluate()`·`create()`는 Gmail 클라이언트를 만들기 전에 이것을 확인한다. `enabled` 없음/true는 지금 동작 그대로다. 다른 작업의 origin 비교·prune 변경은 보존됐다 |
| 시험 | [확인] `v4-red.log` 수정 전 1 failed, `v4-mutation-client-before-check.log` 클라이언트를 먼저 만드는 변이를 잡음(1 failed), `v4-final-team.log` 5222 passed·4 skipped, `v4-final-airport.log` boundary 382·document 0·compartments 0 PASS |
| 적용 준비 사실 | [확인] 이 작업 team-kit 바꿀 파일(lib 아래)의 실행본은 모두 기준 `dfb469d3`과 같다(`account_connect.py`는 새 파일). HEJO-TODO-DRAWER 범위(브랜치 `b2bc84f8`: `hermes/bin/hermes-deadlines`·`deadline_watch.py`·시험)와 파일이 겹치지 않는다. `deadline_watch.py`는 HEAD = 실행본 `e20213cd…`. hejo `main`에 이 작업 문 코드(`961ea80`·`131e47f`)와 TODO-DRAWER `433095a`가 모두 들어 있다 |

### 설계 적합성(4.2)
설계 4판과 일치한다. Google 꺼짐 검사는 team-kit 한 곳(`account()`)에서 한다.

### 다음
handoff 5차 지시: 합동 TASK-05(HEJO-TODO-DRAWER와 재시작 1회).

## 5차 (2026-11-21) — 합동 TASK-05 보류(인계 지시 충돌, 정당한 멈춤)

- 대상: hejo `3743d38`(보고만), 운영 저장소 HEAD `dfb469d3`.
- 판정: **미완료.** 운영 변경은 없다. [확인] 운영 저장소 HEAD `dfb469d3`, 미커밋 없음, 새 파일(`account_connect.py`·`hermes-deadlines`) 실행본 없음. `3743d38`은 impl-report만 바꿨다.
- 원인: **설계·계약 오류(계획 담당 인계 문장).** 5차 지시 6항 복구 조건은 "이전 릴리스로 되돌린 뒤 재시작"을 요구하는데, 7항은 "재시작 2회 이상"을 금지했다. 게이트웨이는 이미 적재한 코드를 쓰므로, 파일만 되돌리고 재시작하지 않으면 복구가 안 된다. 구현 담당의 멈춤이 맞다.
- 착수 확인값(보고·로그와 일치): 실행본 15개 = HEAD, 두 브랜치 tip `ae04a715`·`b2bc84f8`, 파일 겹침 없음, 릴리스 후보 조상 확인, 진행 중 턴 0.
- 조치: handoff 6차 지시. 계획된 재시작은 1회다. 복구 조건이 걸렸을 때만 롤백을 위한 재시작 1회를 더 허용한다(총 2회 상한). 그 밖의 재시작은 금지한다.

## 6차 (2026-11-21) — 합동 TASK-05 적용 후 복구(미완료). 원인은 계획 담당의 확인 기준 오류

- 대상: 운영 저장소 main `66f2a44c`(두 작업 merge), 문 릴리스 후보 `0366192`, 복구 뒤 공용 RELEASE `1c6b3e2`, hejo 보고 `a8763be`.
- 판정: **미완료.** 실행 담당은 지시대로 적용했고, 확인 기준에 걸리자 지시대로 롤백과 복구 재시작을 했다(총 2회). 실행 오류는 없다.
- 직접 확인:
  - [확인] 걸린 항목은 `connections_part_failed part=toolset_config reason=admin_failed status=400` 1건(`v6-failure-summary.json`)이다. 같은 줄이 **적용 전 이전 릴리스에서도** 같은 직원에 대해 반복해서 나왔다(게이트웨이 로그, 2026-11-20 20:11~20:18). 이것은 HEJO-CONNECTIONS에서 확인하고 범위 밖으로 남긴 Hermes 본체 문제(직원 전용 플러그인 묶음의 설정 요청 400, [HEJO-CONNECTIONS tasks "발견했지만 범위 밖"](../HEJO-CONNECTIONS-20261120/tasks.md))다. 문은 설계대로 그 부분만 빼고 표를 보여 준다.
  - [확인] 같은 창에서 TODO-DRAWER M1(`hermes-deadlines` 종료 0·failed 없음·장부 불변)과 M2(`deadlines_read items=2 failed=0`)는 통과했다. 롤백으로 지금 실행본에는 없다.
  - [확인] 복구: 기존 15개 실행본 복원, 새 파일 2개 삭제, 이전 RELEASE `1c6b3e2`, `status`·`apps` 종료 0(`v6-recovery-proof.json`).
- 원인 분류: **수락 기준(확인 기준) 오류 — 계획 담당.** 5차 지시 6항 "connections_failed·connections_part_failed 새 줄 없음"은 이미 알려진 기존 실패를 빼지 않았다. 기준은 "적용 전과 비교해 새 종류의 실패가 없음"이어야 했다.
- 남은 위험: 운영 저장소 main(`66f2a44c`)은 새 코드인데 실행본은 이전 상태다. 매일 자동 기록은 `./sync`로 실행본을 저장소에 모으므로, 재적용 전에 자동 기록이 돌면 저장소가 이전 내용으로 되돌아가는 커밋이 생길 수 있다. 재적용은 브랜치 tip(`ae04a715`·`b2bc84f8`)을 원본으로 삼는다.
- 조치: handoff 7차 지시(재적용, 확인 기준 정정, 재시작 예산 새로).
