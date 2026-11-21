# 구현 인계: HEJO-CONN-MANAGE-20261120

> 최신 판단: **4차 TASK-02b 구현·자체 시험 완료, 독립 검토 대기**. 시작 조건 충족을 확인하고 지정 main 병합 뒤 Google 꺼짐 소비자를 보완했다(문서 끝 4차 구현). TASK-02~04의 이전 검토 통과분은 유지한다. 아래 이전 단계·GAP·대기는 당시 기록이며, 최종 제품 완료·운영 적용·푸시 완료를 뜻하지 않는다.

## 판단 상태

**보류(구현 규칙 2절 보고 대기).** TASK-02 착수 전 기준 일치 검사에서 인계서 9항의 중단 조건을 확인했다. 제품 코드는 변경하지 않았다. TASK-02·03·04는 미구현이며, 제품 완료나 수락 시험 통과를 뜻하지 않는다.

## 받은 설계와 현재 기준

- [확인] 받은 설계: [handoff.md](handoff.md), 계획 3판 `da4592568a2da8122181fc7eb139f7f9e36132ee`. [plan-review.md](plan-review.md) 3회차 APPROVED 기록 확인.
- [확인] hejo 착수 HEAD: `251efabd2baa08f423e0da6b46e14fb8de582071` (`main`). 제품 기준 `63cbe2a` 이후 `gate/`·`app/`·`schemas/`·`scripts/` 차이 없음. 착수 시 hejo 작업 트리는 깨끗했다.
- [확인] 운영 저장소 착수 HEAD: `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`. 실제 경로는 추적하지 않는 `AGENTS.local.md`의 운영 저장소 항목을 따른다.
- 고위험, 필요 증거 수준 2, 연합개발의 구현·자체 시험 역할. 운영 적용·공개·설치·재시작은 이번 범위 밖이다.

## TASK-02: 기준 파일 불일치로 착수 중단

검사 대상은 `team-kit/lib/hermes_team_services/wait_jobs.py`다. 운영 저장소에서는 `hermes/plugin-store/` 아래에 있다. 실행본은 플러그인 창고의 같은 상대 경로다. 비밀 파일은 열지 않았다.

| 대상 | sha256 |
|---|---|
| 운영 저장소 HEAD의 파일 | `bf1dd9097a537b7f7999af93398b97386f6c3a24e3acc441b960b25bafd1ec83` |
| 운영 저장소 미커밋 파일 | `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d` |
| 실행 중인 파일 | `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d` |

[확인] 실행본과 미커밋 파일은 같고, HEAD 기준 파일과는 다르다. HEAD에서 임시 worktree를 만들면 이 파일의 기준 일치 조건을 만족하지 못한다. 새 worktree를 만들거나 운영 원본·미커밋 파일을 고치지 않았다. 다른 작업의 변경을 가져오거나 커밋하지 않았다.

인계서 9항은 이 파일을 특히 지목하며 “sha256 확인 결과를 반드시 적고 다르면 멈추고 보고”하도록 명시한다. 기존 변경을 무시한 HEAD 개발이나 미커밋 파일의 임의 반입은 승인된 절차에 없다.

### 계획 담당이 결정할 쟁점

1. 권고: 해당 미커밋 변경의 담당 작업이 검증·커밋으로 기준을 확정한 뒤, 갱신된 HEAD와 실행본을 다시 비교하여 새 worktree에서 시작한다. 다른 작업의 변경을 이 작업 커밋에 섞지 않는다.
2. 대안: 계획 담당이 현재 미커밋 변경의 소유권·상태·기준을 확인하고, 그 변경을 포함하는 별도 기준 수립 절차를 명시한다. 구현자가 임의로 파일을 복사하거나 기준 일치 요건을 생략하지 않는다.

## TASK-03·04

[미실행] 제품 변경과 수락 시험 코드 작성 전이다. TASK-03은 확정된 계약과 가짜 team-kit으로 독립 구현할 수 있다. TASK-04는 이 Mac에서 확인 창 뒤 창 사라짐을 먼저 재현해야 한다. 차단 해소를 위한 수정 지시에서 독립 갈래 선행 여부도 명시할 수 있다. 현재 응답에서는 인계서의 중단 요구에 따라 작업 경계에서 멈춘다.

## 변경·설계 차이·남긴 코드

- 추가: 이 구현 인계 보고서. 기존 제품 코드·시험·명세·설계 변경 없음.
- 설계 변경 없음. 계획이 요구한 착수 검사에서 중단했다.
- 새 구조·공개 계약·저장 형식·임시 제품 코드 없음. 롤백할 제품 변경 없음.
- 별도 에이전트 실행 없음. 운영 파일·설정·금고·명부·토큰·ddots·Hermes 본체 변경 없음.

## 검증과 증거

실행 기록은 로컬 `.build/conn-manage-evidence/`에 둔다. 개인 경로를 추적 문서에 넣지 않는다.

- [확인] 읽기 전용 sha256 비교: Python 표준 라이브러리로 `git show HEAD:<상대 경로>`의 바이트와 운영 저장소 작업본·실행본을 비교. 실행 종료 코드 0, 기준 일치 판정 BLOCKED. 원문 로그: `.build/conn-manage-evidence/preflight.log`. 이 보고서의 표는 해당 로그에서 직접 확인했다.
- [확인] `git diff --stat 63cbe2a HEAD -- gate app schemas scripts`: 종료 코드 0, 출력 없음. 원문 로그의 `product_changes_since_base`도 빈 목록.
- [확인] `python3 scripts/scan_private.py --home <임시 가짜 홈>` 첫 실행: 종료 코드 1. 가짜 명부의 `alpha`·`beta`가 기존 시험 식별자와 Swift 투명도 이름에 걸렸다. 제품 결함으로 판정하지 않는다. 로그: `.build/conn-manage-evidence/scan-initial.log`. 가짜 명부를 검사 전용 식별자로 분리해 최종 문서 상태에서 다시 실행한다. 실제 명부·금고의 개인값 대조는 수행하지 않는다. 최종 실행 결과는 `.build/conn-manage-evidence/scan-result.json`과 `scan.log`를 따른다.
- [미실행] AT-CM-01~18·14b·40~44·20~28·23b·30~38, 회귀 시험, 앱 빌드, `./airport-check`, mutation check. 제품 변경 전 중단했으므로 실행하지 않았다. 본체 소비자 시험 AT-CM-14b를 통과로 세지 않는다.
- 도달 증거: 착수 파일 비교만 확인. 필요한 제품 증거 수준 2는 아직 도달하지 않았다.

## 다음 인계

계획 담당은 기준 불일치 처리 방식을 확정해 구현 지시를 갱신한다. 이후 구현 담당은 실제 HEAD·실행본·작업 트리를 다시 확인한 뒤, 허가된 기준으로 TASK-02·03·04와 수락 시험을 진행한다. 현재 푸시 대상 커밋은 생성하지 않았다.


## 2차 구현 — TASK-03 문

[확인] 보완 인계 `e96ca98`에 따라 재개했다. 작업 기준은 같은 커밋이며 기존 제품 변경은 없었다.

- 구현자 판단: TASK-03 계획의 명세 시험은 통과했다. 최종 생산자 자료 대조의 추가 GAP으로 전체 목표 충족 판정은 보류한다(문서 끝).
- 변경: `gate/connection_manager.py`에서 `settings`·`committed` 공개 필드, 연결된 앱의 설정 바꾸기 라벨, 조건부 계정 줄 합치기와 확인 전달, `change` 전달, 기기별 보안 칸 누적과 세션 경계를 구현했다. 설정 표시 값은 공개하되 보안 입력 값은 기존 거부 원칙을 유지한다.
- `gate/connection_runtime.py`는 `--change`와 `account connect|disconnect|undo`의 고정 인자를 검증한다. 계정 저장 뒤 재개는 계정 변경을 다시 실행하지 않고 기존 다시 시작 작업으로 간다.
- `gate/server.py`의 소켓 종료 지점에서 해당 기기의 보호 목록을 비운다. 이는 인계서의 기기 연결 끊김 정리를 위한 실제 호출자 변경이다. 새 창 닫힘 프레임·저장 형식은 추가하지 않았다.
- 새 `tests/acceptance/test_conn_manage.py`: AT-CM-20~28·23b를 코드로 옮겼다. 설치만 된 앱은 기존 계정 줄을 유지하고, 설정 기준 확인 결과는 직접 확인 결과로 취급하지 않는다. 진행 중 요청은 시작 시점의 비밀값 집합을 유지하여 뒤 요청·기기 끊김에 영향받지 않는다.
- 기존 마지막 응답 덮어쓰기 경로를 세션 누적으로 교체했다. 새 세션·일반 요청·저장 완료·실패/거절·기기 끊김 경계에서 정리하며, 오래 걸린 이전 세션 응답이 새 세션 목록을 덮지 않도록 집합의 소유권도 검사한다.

### TASK-03 검증

| 명령 | 실제 결과 | 로그(hejo 기준) |
|---|---|---|
| gateway Python `-m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 397 passed, 기존 비동기 표시 경고 1 | `.build/conn-manage-evidence/gate-all-final.log` |
| gateway Python `-m gate.tests.gateway_delivery` | 종료 0, 격리된 가짜 홈·플랫폼의 게이트웨이 전달/종료 확인 | `.build/conn-manage-evidence/gateway-delivery.log` |
| 보안 칸 누적 제거 mutation | 시험 종료 1(예상대로 검출), 원복 | `.build/conn-manage-evidence/mutation-secure-field-accumulation.log` |
| 요청 비밀값 필터 제거 mutation | 시험 종료 1(예상대로 검출), 원복 | `.build/conn-manage-evidence/mutation-reflected-secret-filter.log` |

필요·도달 증거 수준은 2다. 운영 관리 서비스·실제 직원·메시지·게이트웨이는 사용하지 않았다. TASK-02·04 결과는 다음 절에 이어 기록한다.


## 2차 구현 — TASK-02 team-kit (wait_jobs.py 제외)

**배정 범위 구현·자체 시험 완료.** 운영 저장소 HEAD `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`에서 별도 worktree를 만들었다. 위치는 `AGENTS.local.md`의 TASK-02 항목, 브랜치는 `hejo-conn-manage-20261120`이다. 실행 원본과 운영 저장소 main의 다른 작업 파일은 고치지 않았다.

### 착수 기준 확인

각 파일의 기준과 실행본 sha256을 직접 비교했다. 표의 지문은 앞 12자리이며 전체 값은 `.build/conn-manage-evidence/task02-baselines.json`에 있다. 새 파일은 비교할 이전 실행본이 없다.

| team-kit lib 상대 경로(시험은 tests/) | HEAD sha256 앞 12자리 | 실행본 비교 |
|---|---|---|
| `hermes_facility/app_connect.py` | `7457e18c6bee` | 일치 |
| `hermes_facility/connections.py` | `9c27a65c01b7` | 일치 |
| `hermes_facility/app_registry.py` | `b663c9f044c9` | 일치 |
| `hermes_facility/app_setup.py` | `17834aa1382c` | 일치 |
| `hermes_packs/mac_apps/discovery.py` | `47a56912f2d0` | 일치 |
| `hermes_team_services/news_watch.py` | `0ad2cfe71ef1` | 일치 |
| `hermes_team_services/personal_review.py` | `5a4f965533fb` | 일치 |
| `hermes_team_services/morning_report.py` | `4fa29ae8ad2e` | 일치 |
| `hermes_team_services/report_review.py` | `71b043dd68be` | 일치 |
| `hermes_execution/personal_scopes.py` | `e0fd7e0581a1` | 일치 |
| `hermes_packs/mail/mail_index.py` | `c657baa370e8` | 일치 |
| `hermes_facility/connection_checks.py` | `4a1fa5db559c` | 일치 |
| `hermes_execution/__init__.py` | `6fd73c1f44e4` | 일치 |
| `hermes_facility/synology_setup.py` | `d48ce57783ce` | 일치 |
| `hermes_team_services/wait_jobs.py` | `bf1dd9097a53` | 불일치·TASK-02b 대기 |
| `tests/test_morning_report.py` | `d91eed049008` | 일치 |
| `tests/test_news_watch.py` | `85d0cc68cf45` | 일치 |

추가로 `hermes/schemas/connections-status.json`의 실행본·기준 일치를 확인했다(sha256 `d53a2e66f52efd988b9ac38374da7e55d37507763d7688d3602a7b96e859919d`). 최종 확인에서도 변경한 기존 코드·시험·스키마 16개의 실행본은 기준과 같았다(`live-final.json`).

### 변경과 책임

- `app_connect.py`: 기존 `steps_from`에 Notion 로그인 단계를 연결하고, 저장된 설정의 안전한 표시(`settings_for`), `--change`의 단계 강제 진입·저장 값 재사용·현재 옵션 미리 선택을 구현했다. 바꾸기 동안 `stage_values`와 진행 기록 만료 쓰기를 하지 않는다. 실제 저장 뒤에는 `committed: true`를 내고 재개와 바꾸기를 함께 받지 않는다. 저장 이후 어댑터 실패에도 저장 경계 표시는 유지한다.
- `synology_setup.py`: 기존 실제 로그인·폴더 세션도 확인 기록을 저장한다는 점을 발견했다. 바꾸기 요청에만 메모리의 내부 `_change` 표시를 전달해 성공·인증 실패·통신 실패 기록 쓰기를 생략한다. 비밀값과 이 표시는 금고에 저장되지 않는다. 평소 연결·점검의 기록 경로는 유지한다. 실제 어댑터 + 가짜 NAS로 저장 전 지문 불변을 검증했다.
- 같은 앱이 명부에 이미 있으면 명부의 기존 바이트를 사용하여 인용부호·주석까지 보존한다. 새 연결과 해제의 명부 변경은 기존 조립 규칙대로다.
- `connections.py` 한 곳에 계정 서비스의 켜짐 칸·줄 id 표를 두었다. Google은 `gmail.enabled`와 해제가 추가한 스킬 표시, X는 기존 켜짐 칸, Instagram은 플러그인 목록을 사용한다. 상태·동작 목록과 새 `account` 명령도 이 원본을 따른다.
- 새 `account_connect.py`: 직원 설정 하나만 칸 단위로 바꾸며, 기존 앱의 잠금·쓰기 전 기록·복구·원자 쓰기·10분 되돌리기·지문 충돌 거절을 공유한다. 별도 기록 형식은 만들지 않았다. 공통 writer와 선택 가능한 undo 경로는 `app_connect.py`에서 뽑았다.
- `hermes_execution/__init__.py`는 team-delegation 링크의 실제 파일이다. Google 꺼짐 때 해당 도구 등록을 생략한다. `personal_scopes.install_mail`, `personal_review.mail`, `mail_index.run`, `news_watch.fetch_x`, Instagram을 직접 싣는 세 경로도 직원 설정을 따른다. 공유 토큰의 `token_home` 결정은 바꾸지 않았다.
- `discovery.py`는 연결된 앱의 설정을 읽기 전용으로 제공한다. `app_registry.derived_settings`는 이미 Gmail 블록을 복사하므로 `enabled`·`off_added_skills`를 보존한다. 이 파일과 `app_setup.py`는 수정할 필요가 없었다.
- 상태 스키마의 동작 id 열거형과 운영 저장소의 `docs/연결-상태.md`를 함께 갱신했다. 기존 시험 중 활성 목록이 없던 Instagram·X 가짜 홈은 새 활성 판정에 맞게 설정했다. 성공·실패 기대값은 유지하고, 기존 꺼짐 줄의 동작 검사는 승인된 `account_connect` 계약에 맞췄다.

새 수락 시험 코드는 worktree `hermes/plugin-store/team-kit/tests/test_conn_management.py`다. AT-CM-01~18·14b·40~44의 배정 부분을 옮겼으며, AT-CM-12(라)의 `wait_jobs.account`는 아래 TASK-02b로 분리했다. 시험 명세·합격 기준은 수정하지 않았다.

### TASK-02 검증

| 명령/확인 | 실제 결과 | 로그(hejo 기준) |
|---|---|---|
| gateway Python `-m pytest hermes/plugin-store/team-kit/tests -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` (TASK-02 worktree) | 종료 0, 5214 passed·기존 4 skipped·경고 1·58 subtests passed, 검사 중 코드 지문 동일 | `.build/conn-manage-evidence/team-final.log` 및 `.log.json` |
| 새 수락 시험 파일 집중 실행 | 종료 0, 24 passed | `.build/conn-manage-evidence/team-manage-final.log` |
| 실제 NAS 어댑터·기존 NAS/연결 화면 회귀 | 종료 0, 69 passed(명부 인용부호 보존 보강 전, 해당 보강은 위 최종 전체 검사에 포함) | `.build/conn-manage-evidence/nas-real-adapter.log` |
| team-delegation 기존 manifest·Google calendar·rollback 시험 | 종료 0, 39 passed | `.build/conn-manage-evidence/delegation.log` |
| `./airport-check --snapshot .` (worktree) | 종료 0, boundary 382·document 0·compartments 0, 기준선 증가 없음 | `.build/conn-manage-evidence/airport-final.log` 및 `.log.json` |
| NAS 저장 전 확인 기록 억제 제거 mutation | 시험 종료 1(검출), 원복 | `.build/conn-manage-evidence/mutation-nas-precommit-check-record.log` |
| Google 등록 필터 제거 mutation | 시험 종료 1(검출), 원복 | `.build/conn-manage-evidence/mutation-google-tool-optout.log` |

AT-CM-14b는 설정 배열 검사로 대체하지 않았다. 시험에서 가짜 홈을 `HERMES_HOME`으로 지정한 새 gateway Python 프로세스로 본체 `agent.skill_utils.get_disabled_skill_names()`를 직접 호출했다. 목록이 없던 경우와 JSON 배열 문자열 경우 모두 해제 뒤 스킬 포함·연결 뒤 원상태를 확인했다. 본체 수정은 없다. 일반 수락 증거 수준은 2이며 운영 적용·실물 증거로 보고하지 않는다.

TASK-02 커밋: `5e6c81cc173042e879bacf1b7f0fb766ba8494fd`. 게이트웨이가 import하는 변경 원본은 위 lib 파일과 새 `account_connect.py`이며, 운영 반영은 하지 않았다. 임시 worktree 커밋을 버리면 개발 변경은 되돌릴 수 있고, 실제 교체·보관·복원 절차는 기존 handoff TASK-05가 담당한다.

## 2차 구현 — TASK-02b

**대기(기준 불일치).** 최종 읽기 확인에서도 운영 저장소 HEAD는 `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`, `wait_jobs.py` 기준 sha256은 `bf1dd9097a537b7f7999af93398b97386f6c3a24e3acc441b960b25bafd1ec83`, 실행본은 `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d`다. 파일 수정·반입·merge·해당 수락 시험은 하지 않았다. 이 조건이 풀리기 전 Google 배경 대기 작업의 꺼짐을 완료로 세거나 운영에 적용하면 안 된다.

## 2차 구현 — TASK-04 앱

배정 구현과 앱 대역 시험을 마쳤다. `ConnectionModels.swift`는 설정 항목을 읽고, 기존 `ConnectionsView`에 다른 동작 메뉴·지금 설정·단계별 바꾸기를 더했다. 기존 SwiftUI 화면 안의 변경이며 별도 맞춤 화면은 만들지 않았다(design 5절 예외).

- 해제는 값이 남는다는 확인 → 지문/암호 재확인 → 요청 순서다. 저장 뒤 다시 시작을 재개할 때 해제 확인을 다시 묻거나 같은 변경을 다시 실행하지 않는다.
- 단계가 하나면 바로 그 단계를 열고, 여러 개면 자세히 화면에서 고른다. 서버의 `selected`를 그대로 미리 선택한다.
- 바꾸기 세션은 `changeValues`에만 누적하고 디스크·로그에 쓰지 않는다. 저장 완료·실패·창 닫힘에 지우며, 닫힌 세션의 늦은 응답도 세션을 되살리지 않는다. 저장 뒤 재개 프레임은 `resume`만 갖는다.
- `authenticated()`와 AppKit `ask()`의 종료 시 성공·취소 모두 앱 활성화와 연결 창/입력 창을 앞으로 가져온다. 확인 중 창 높이는 기존 `.normal` 규칙을 유지한다.

### 확인 창 재현과 원인

수정 전 이 Mac에서 독립 AppKit 창과 실제 `LAContext.evaluatePolicy(.deviceOwnerAuthentication)`로 시험했다. 12초 뒤 context를 취소한 경계에서 `success=false`, 오류 코드 `-9`, 앱 `active=false`·창 `key=false`·`visible=true`를 관측했다. 0.5초 뒤에는 시스템이 다시 활성화했다. 따라서 지속적인 숨김 전체를 재현했다고 주장하지 않으며, 재확인 완료 직후 키 창을 잃는 경계를 확인한 것이다. 원문은 `.build/conn-manage-evidence/auth-repro.swift`·`auth-repro.log`다.

기존 `authenticated()`와 `ask()`는 확인 중 높이만 바꾸고 완료 뒤 활성화·키 창 복원을 하지 않았다. 이 책임 자리에 복원을 추가했다. 실제 암호 승인 성공은 미실행이며, 성공/취소·입력 창 유무 조합은 AT-CM-35의 주입한 비활성 상태·활성화 함수와 실제 AppKit 키 창으로 시험했다. OS의 비동기 deactivate 타이밍에 의존하던 중간 시험을 명세가 요구한 주입 방식으로 바꿨으며, 기대하는 복원 횟수·키 창·표시·확인 중 높이는 유지했다.

`app/Tests/ConnectionsTests.swift`의 AT-CM-30~38은 메뉴 동작 목록, 설정 읽기·선택, 두 종류 해제 프레임과 확인 순서, 미리 선택, 값 누적·committed 경계·resume 전용·닫힘 정리를 확인한다. 기존 연결 화면 시험도 통과했다. 전체 `bash app/scripts/test.sh`는 종료 0이며 `.build/conn-manage-evidence/app-all.log`에 `AT-CM-30~38 APP PASS`와 마지막 settings/downloads 메타데이터 불변 확인이 있다. Swift 컴파일 경고는 출력되며 경고 정리는 이번 범위 밖이다. 최종 필수 통합 스크립트 결과는 다음 절에 기록한다.

## 추가 검토가 필요한 범위

- TASK-02b와 운영 적용·공개·설치·버전 변경·실제 M1~M5는 미완료/미실행이다. 새 코드의 서버 설치나 실제 서비스 메시지 전송은 하지 않았다.
- Google 등록 필터는 `gmail_direct`·`google_reauth`·`google_calendar_*`·`calendar_direct_*` 이름에 적용한다. 일부 이름은 Mac Mail/Calendar 앱도 공유하므로, 같은 직원의 Google 해제와 Mac 앱 동시 연결에서 원하는 도구 노출 범위를 검토자가 특히 확인해야 한다. 별도 사용자 결정을 구현자가 추가하지 않았다.
- 금고에 설정이 없는 옛 조립 설정만의 경로는 추가 실물 검증을 하지 않았다. 수락 시험은 명세의 저장 값이 있는 가짜 연결을 기준으로 한다.
- 고위험 작업의 독립 검토와 최종 완료 판정은 다음 담당 역할에 남아 있다. 본 보고는 운영 준비 완료나 푸시 완료 선언이 아니다.


## 최종 통합 검사와 인계 상태

[확인] `bash scripts/test.sh` 종료 0. 최종 코드가 실행 중 바뀌지 않았음을 파일 지문으로 확인했다. 문/수락 시험 397 passed, 격리 게이트웨이 전달 시험, 앱 빌드·서명 검증·AppKit/네트워크 대역 시험 및 마지막 훅 시험 9개가 끝까지 통과했다. 원문과 검사 대상 지문은 `.build/conn-manage-evidence/product-full.log`·`product-full.log.json`이다. 관련 Swift 경고와 기존 pytest 표시 경고는 남아 있다. 기능 시험을 skip/xfail로 돌려 통과시키지 않았다.

- TASK-02: `5e6c81cc173042e879bacf1b7f0fb766ba8494fd`, 개발 worktree의 `hejo-conn-manage-20261120` 브랜치. TASK-02b는 포함하지 않는다.
- TASK-03: `961ea80fb455a3a49f22a2fac9e4f225b35d6ffa`, hejo `main`.
- TASK-04: `f06d8b292fafb29f5542621e97728d76f95e7e98`, hejo `main`. 이후 보고서만 보강한 커밋은 인계 상태 블록에서 확인한다.
- 배정 범위 필요/도달 증거 수준: 2/2. TASK-02b·운영 적용·실물 확인·독립 검토는 남아 있다.
- 로컬 재현 환경: `source .build/conn-manage-env.sh`로 이번 worktree lib를 먼저 사용한다. 예전 `connections-env.sh`만 쓰면 이전 작업 worktree가 먼저 잡히므로 새 환경 파일을 사용한다.
- 다른 작업의 `docs/changes/HEJO-TODO-DRAWER-20261120/impl-report.md`가 미추적으로 생겼으며 수정·스테이징하지 않았다.
- 운영 main 동기화·원본 교체·게이트웨이 재시작·설치·공개·푸시는 하지 않았다. 다음 담당은 이 보고서와 실제 코드/증거를 검토하고, TASK-02b 기준 일치가 풀렸는지 다시 확인한다.

추가 대역 화면 캡처: `app/.build/app-tests --task32-capture <임시 출력 폴더>` 종료 0, 검사 중 코드 지문 동일. 로그는 `.build/conn-manage-evidence/app-capture.log`, 생성 파일은 `ui/conn-manage-list.png`·`ui/conn-manage-settings.png`(같은 증거 폴더 아래)다. 운영 화면 캡처가 아니다.

최종 개인값 검사: gateway Python `scripts/scan_private.py` 종료 0, 지적 0. 실제 owner 입력과 비교하는 정식 검사이며 기준선·예외를 늘리지 않았다. 로그는 `.build/conn-manage-evidence/private-final.log`와 `.log.json`이다.


## 최종 자체 점검 추가 GAP — 앱 파생 Mac 줄 중복

**판단: 보류(구현 규칙 2절, 설계·시험 입력 보완 필요).** 제품 코드를 임의로 더 고치지 않고 계획 담당에게 넘긴다. 기존 명세 시험 통과와 이 추가 관측을 구분한다.

### 발견 사실과 근거

- [확인] team-kit `hermes_facility/connections.py`의 `inventory()`는 명부에 명시적 앱 장착이 있으면 `id: app-<bundle>`, `group: mac`, `verified_by: team_registry` 행을 더 만든다. 이는 이번 변경 전에도 있던 생산자 경로이며, 계약상 `status` 출력의 행 자체는 유지해야 한다.
- [확인] `discovery.installed_apps()`의 같은 서비스 `links`에는 계정 행과 이 파생 Mac 행이 모두 들어간다.
- [확인] design 4절과 현재 문 구현의 통합 조건은 `group == account`다. 그 조건대로 계정 행을 합쳐도 파생 Mac 행은 남는다.
- [확인] 임시 가짜 홈과 가짜 명령으로 실제 생산자 모양(시놀로지 계정 행 + 파생 Mac 행 + 연결된 앱)을 문 `document()`에 넣었다. 결과는 `team:app-com.synology.CloudStation`와 `app:com.synology.CloudStation` 두 행이다. 시놀로지 한 줄 목표(M1와 원래 목표)의 충족을 선언할 수 없다.
- 기존 AT-CM-21 입력은 계정 행과 앱 행만 주므로 이 생산자 사례를 잡지 못한다. 시험 명세·기대값·설계 본문은 수정하지 않았다.

진단 명령은 hejo에서 환경 파일을 읽고 gateway Python으로 `.build/conn-manage-evidence/probe-derived-row.py`를 실행하는 것이다. 프로세스 종료는 0(진단 수행 성공)이지만 `oneRowCriterionMet: false`이므로 **제품 기준은 실패**다. 원문·대상 코드 지문은 `derived-row-gap.log`·`.log.json`, 관측 값은 `derived-row-gap.json`(모두 같은 증거 폴더)이다. 실제 운영 상태 명령이나 관리 서비스를 호출하지 않았다.

### 계획 담당이 판단할 선택지와 권고

권고: `status` 생산자의 기존 계약은 유지하고, 문에서 실제 앱과 같은 직원·같은 연결 키의 파생 `team:app-*` 행을 통합하는 조건을 설계에 보완한다. AT-CM-21에도 실제 생산자 3행 입력을 포함하도록 계획 담당이 수락 시험 명세를 보완한 뒤 구현 지시를 준다. 설치만 된 앱과 다른 직원 행을 숨기지 않는 경계도 함께 확정해야 한다.

원래 계획의 계정 행 통합 범위를 구현자가 임의로 확대하지 않았다. 배정된 나머지 코드와 검증 근거는 커밋했고, 계속할 수 있는 제품 변경은 이 보완 판단 및 TASK-02b 기준 일치 뒤다. 운영 적용·실물 확인·푸시는 여전히 미실행이다.

## 3차 구현 — TASK-03 보완 1 (V-3)

받은 기준은 `729eee3317e8cea2dc5f8119271696977c0f8563`의 design 4판 4절·수락 시험 4판 AT-CM-21b·handoff 3차 지시다. 착수 때 작업 트리는 깨끗했고, 읽기 전용 인계 상태와 문서의 V-3·V-1을 대조했다. 위험도 고위험, 필요 증거 수준 2이며, 본 절은 구현자의 자체 시험 기록이다.

### 변경과 이유

- `gate/connection_manager.py`의 기존 `document()` 합치기 자리에 같은 직원의 `team:app-<connection_key>`와 `APP_CONNECTED` 조건을 더했다. 앱 분류·계정 링크 유무와 관계없이 같은 연결을 합친다. `CONFIG_DRIFT`와 다른 연결 키의 줄은 남긴다. 직원별 목록 안에서 처리하므로 다른 직원의 줄을 지우지 않는다.
- 계정 줄과 파생 줄의 직접 확인 기록을 같은 복사 경로로 통합했다. `config`·`team_registry`는 앱의 연결 상태를 덮지 않으며, 직접 확인의 `state`·`reason`·`checked_at`·`verified_by`를 앱 줄에 반영한다. 계정과 파생 줄 모두 직접 확인 기록이 있으면 같은 앱 연결의 파생 줄 기록을 마지막에 반영한다.
- 기존 계정 줄을 합칠 때만 `check`를 붙이고 계정 id로 전달한다. 파생 줄만 합칠 때는 확인 동작·전달 경로를 만들지 않는다. team-kit `status` 생산자와 앱 코드는 변경하지 않았다. 공개 계약·저장 형식·설계 변경, 별도 칸·임시 제품 코드 없음. 되돌릴 때는 이 보완 커밋의 표시 규칙과 시험만 되돌리며 영속 자료 이관은 없다.
- `tests/acceptance/test_conn_manage.py`에 AT-CM-21b 7사례를 옮겼다. 실제 생산자 형태의 시놀로지 계정+파생+앱 한 줄, 다른 앱의 연결 키, 불일치 줄·다른 직원 보존, beta 앱 유무에 따른 독립 판단, 세 앱 분류의 항상 합치기, 직접 확인 기록, 파생 줄만 있는 경우 확인 요청 거절을 관측한다. 수락 시험 명세·기준은 수정하지 않았다.

### 자체 시험과 증거

모든 경로는 로컬 `.build/conn-manage-evidence/` 아래다. 명령 앞에서 hejo 루트의 `source .build/conn-manage-env.sh`를 적용했다. 로그의 `.log.json`에는 실제 명령·종료 코드·착수 커밋·검사한 변경 코드의 지문·검사 중 불변 여부가 있다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| 수정 전 `pytest tests/acceptance/test_conn_manage.py -k cm21b -q` | 종료 1, 새 7사례 모두 실패(기존 결함 검출) | `v3-red.log` |
| `pytest tests/acceptance/test_conn_manage.py tests/acceptance/test_connections_screen.py gate/tests -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 193 passed(AT-CM-20~28·23b 포함) | `v3-gate.log` |
| 진단 `probe-derived-row.py` 재실행 | 종료 0, 관측 id `app:com.synology.CloudStation` 하나, `observedCount:1`, `oneRowCriterionMet:true` | `v3-derived-row.log` |
| Mutation: 합치기 조건에 `CONFIG_DRIFT`를 의도적으로 허용 후 AT-CM-21b 실행 | 기대한 종료 1, 해당 보존 단정에서 1 failed·6 passed. 원본 코드로 복원 | `v3-mutation-drift.log` |
| `bash scripts/test.sh` 전체 재실행 | 종료 0, 문·수락 시험 404 passed, 격리 게이트웨이 전달·앱 빌드/서명·앱/네트워크 대역·훅 9개 끝까지 통과 | `v3-product-full.log` |

[확인] 검사 중 변경 코드 불변. 기존 pytest 경고 1개와 Swift 컴파일 경고는 남아 있으며 이번에 기준·예외를 늘리지 않았다. 필요/도달 증거 수준은 2/2(가짜 홈·가짜 team-kit/관리 서비스 대역 통합)다. 최종 개인값 정적 분석의 실제 종료 코드와 지적은 `v3-private.log`·`.log.json` 및 인계 상태 블록으로 확인한다. 검사한 코드와 별도 커밋 본문의 일치 대조는 `v3-final-evidence.json`에 남긴다. 검토 대상은 hejo `main`의 이 보완 커밋이며 전체 해시는 최종 상태 블록에 적는다.

진단 스크립트는 수정하지 않았다. 이 스크립트의 `result` 문자열은 과거 GAP 설명으로 고정돼 있으므로 결과 판정은 실제 `observedIds`·`observedCount`·`oneRowCriterionMet`로 한다. 과거 실패는 `derived-row-gap.log`, 이번 관측은 `v3-derived-row.log`로 구분한다(스크립트가 `derived-row-gap.json`을 최신 관측으로 덮어쓴다).

### TASK-02b와 남은 범위

**대기(기준 불일치).** 읽기 전용 재확인에서 운영 저장소 HEAD는 `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`, `wait_jobs.py` 기준 sha256은 `bf1dd9097a537b7f7999af93398b97386f6c3a24e3acc441b960b25bafd1ec83`, 실행본은 `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d`다. 명령 실행 종료 0, 일치 판정 false(`v3-task02b.json`). 파일 수정·반입·merge·TASK-02b 시험은 하지 않았다.

추가 설계 차이·범위 밖 부채 없음. 이번 제품 변경은 문과 수락 시험 코드뿐이고, 본 보고서는 구현 인계 의무에 따라 이어 쓴 것이다. 운영 적용·실물 M1~M5·최종 독립 검토·푸시는 미실행이다. 다음 검토자는 같은 직원·키·reason 경계와 파생 줄 직접 확인 반영, 계정 check 전달의 보존을 우선 확인한다.

## 4차 구현 — TASK-02b (2026-11-21)

받은 기준은 `30680a1`의 handoff 4차 지시와 design 3.1 표, AT-CM-12(라)다. 고위험·필요 증거 수준 2, 구현·자체 시험 역할이며 TASK-05 운영 적용은 이번에 시작하지 않는다.

### 착수와 병합

[확인] 착수 때 운영 저장소 HEAD/main은 `dfb469d3b33a7732583a291283ffb6b0eeca2ab1`, `wait_jobs.py`의 HEAD·실행본 sha256은 모두 `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d`였다. 해당 파일 미커밋 표시 없음, 작업 worktree는 깨끗한 `hejo-conn-manage-20261120`의 `5e6c81cc173042e879bacf1b7f0fb766ba8494fd`였다. 기존 TASK-02 변경과 들어올 변경의 파일 교집합은 없었다. 경로는 추적하지 않는 `AGENTS.local.md`를 따른다. 근거: `.build/conn-manage-evidence/v4-preflight.json`.

지정된 main 커밋을 worktree에 `git merge --no-edit`로 병합했다(종료 0, 충돌 없음). 병합 커밋은 `fe7f0c954ea7d8cfa3360078c716d3d4c0685373`이며 부모는 기존 TASK-02 커밋과 위 운영 main이다. 다른 작업의 origin 비교·prune 변경은 이 main 조상으로 들어왔고 TASK-02b 변경으로 다시 작성하지 않았다. 운영 main·실행본은 수정하지 않았다.

### 변경과 자체 시험

- 실제 파일 `team-kit/lib/hermes_team_services/wait_jobs.py`의 `account(home)`가 그 직원의 `gmail.enabled is False`를 먼저 확인하고 기존 소비자와 같은 `ValueError('GOOGLE_DISABLED')`로 계정 선택을 끝낸다. 칸이 없거나 true이면 기존 주소 정리·계정 없음 오류를 유지한다.
- 실제 호출 경계를 조사하니 `gmail_service()`가 계정 확인 전에 클라이언트를 만들고 있었다. 같은 파일에서 계정 결정을 클라이언트보다 앞에 옮기고, `evaluate()`도 계정 확인을 먼저 한다. `create()`의 메일 갈래는 이미 서비스 객체가 주어진 경우에도 메일 읽기 전에 계정을 확인한다. 따라서 꺼진 직원은 클라이언트·메일함 주소·스레드 읽기를 호출하지 않는다. 새 공개 형식·저장 칸·설계 변경이나 별도 처리 계층은 없다.
- 꺼진 상태의 기존 대기 확인은 기존 `check()` 오류 처리(`read_failed`, 처음에는 깨우지 않음)를 따른다. `check`·`handle`·`cancel`·`_matches_origin`·`prune`는 바꾸지 않았다. 이전 main과 AST를 직접 비교해 이 함수들의 보존 및 이번에 바뀐 네 함수만 확인했다(`v4-preservation.json`).
- `tests/test_conn_management.py`에 AT-CM-12(라) wait_jobs 사례와 켜짐 대조를 추가했다. 가짜 홈에서 실제 해제·재연결을 거쳐 계정 결정, 새 대기 생성(서비스 주입 유무), 기존 대기 평가·확인의 Google 호출 없음, 다른 직원 유지, 재연결 뒤 같은 읽기 경로 복원을 확인한다. `.env`·가짜 토큰·beta 설정 바이트를 보존하며 운영 파일·서비스를 쓰지 않는다. 별도 2사례는 enabled 없음/true의 정규화와 계정 없음 오류를 확인한다. 수락 시험 명세·기대값은 수정하지 않았다.

검사 환경은 hejo 루트에서 `source .build/conn-manage-env.sh`를 적용한 뒤 worktree에서 게이트웨이 환경 Python으로 실행했다. 로그는 모두 `.build/conn-manage-evidence/` 아래이며 대응 `.log.json`은 실제 명령·종료 코드·대상 코드 지문·검사 중 불변 여부를 담는다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| 병합 후, TASK-02b 수정 전 team-kit 전체 | 종료 0, 5219 passed·기존 4 skipped·58 subtests | `v4-merged-team.log` |
| 병합 후 `./airport-check --snapshot .` | 종료 0, boundary 382·document 0·compartments 0 PASS | `v4-merged-airport.log` |
| 수정 전 새 wait_jobs 수락 시험 | 종료 1, 꺼짐 무시를 검출(1 failed·2 passed) | `v4-red.log` |
| `test_conn_management.py`·`test_wait_jobs.py`·`test_hejo_work_wait.py` 상세 실행 | 종료 0, 61 passed. AT-CM-01~18·14b·40~44 및 origin·prune 회귀 포함 | `v4-focused.log` |
| Mutation: 클라이언트 생성 뒤 계정을 확인하도록 순서를 되돌림 | 기대한 종료 1, 호출 기록 `['client']`로 검출(1 failed·2 passed). 원본 복원 | `v4-mutation-client-before-check.log` |
| 수정 후 team-kit 전체 | 종료 0, 5222 passed·기존 4 skipped·58 subtests·기존 경고 1개 | `v4-final-team.log` |
| 수정 후 `./airport-check --snapshot .` | 종료 0, boundary 382·document 0·compartments 0 PASS, 기준선 증가 없음 | `v4-final-airport.log` |

AT-CM-14b는 이번에도 새 프로세스에서 본체 `agent.skill_utils.get_disabled_skill_names`를 가짜 HERMES_HOME으로 실행했다(2사례 PASSED, 미실행/skip 아님). 필요/도달 증거 수준은 2/2다. 병합 뒤 전체 시험에서 기존 표시 경고 1개가 있었으며 이번 변경으로 기준·예외를 늘리지 않았다.

### 인계와 남은 범위

TASK-02b의 실제 수정 범위는 worktree의 위 코드·시험 2개이며, `git commit --only`로 `ae04a715d351befaebd36a3809df6a3565d82f96`에 기록했다(브랜치 `hejo-conn-manage-20261120`). hejo에는 이 구현 보고서만 이어 썼다. 계획과 다른 제품 동작·추가 부채 없음. 롤백은 TASK-02b 보완 커밋만 되돌리며 병합해 들여온 다른 작업은 유지한다. 최종 개인값 검사 결과는 `v4-private.log`·`.log.json` 및 상태 블록에, 검토 대상 커밋과 검사 코드의 일치 대조는 `v4-final-evidence.json`에 기록한다. 보고서 커밋 해시는 최종 상태 블록에 적는다.

운영 원본 교체·`./sync`·게이트웨이 재시작·릴리스·설치·푸시는 하지 않았다. 독립 검토 통과 뒤 계획 담당이 합동 TASK-05(HEJO-TODO-DRAWER 추가분 포함) 인계를 내며, 이번 구현자가 그 단계를 시작하지 않는다.
