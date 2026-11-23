# 구현 인계: 펫 위치 유지와 드래그 — 계획 5판

## 현재 상태와 변경본
TASK-01 제품 수정 및 TASK-02 자동 회귀를 구현했다. 실제 손 입력·체감 비교는 미실행이며 전체 시험에도 아래 실패가 남아 있어 최종 완료가 아니다. 기존 화면 승인 범위로 진행했으며 재승인·운영 변경·푸시는 하지 않았다. 위험도 일반, 요구 증거 수준 1·2·3 중 자동 근거와 실환경 미검증을 구분한다.

- 원래 목표: 채팅 개폐에 펫 위치·크기가 바뀌지 않고 열린 채팅에서도 포인터 변위대로 펫이 이동한다.
- 제품 기준: `6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0`.
- 준비 커밋: `b1e3a8ccb617b74044c116988c891cce324af7f5`.
- 이번 구현 커밋: `acf168c6999d74c91e9f54d4c8bbed0c4705614d`.
- 브랜치: `role-workflow/25-ebc502d3`. 위 커밋의 변경 전 파일과 실행한 변경본은 동일하다. 보고·로그는 계획 담당 작업 문서 폴더가 원본이며 구현 worktree에는 복제하지 않았다.
- V1 좌우 리사이즈 설계 오류는 계획 5판에서 정정됐으므로 이전 보고의 착수 보류를 해제했다. 계획·수락 명세는 구현자가 수정하지 않았다.

## 변경 파일과 이유
- `app/Sources/PetLayout.swift`: 펫을 헤더에 맞춰 축소·이동하는 배치, 가상 복원 anchor 및 서랍의 펫 동반 이동을 제거했다. 펫 자체 화면 제한과 채팅 화면 제한을 분리했다. 채팅과 펫이 겹칠 수 있으므로 위/아래 방향을 명시적으로 전달한다. 단일 NSWindow의 화면 픽셀 반올림이 로컬 좌표에 영향을 주지 않도록 창 사각형을 정수 점으로 둘러싼 뒤 로컬 사각형을 계산한다. 실제 view 좌표 검사에서 검출된 0.5pt 차이에 대한 책임 위치의 수정이다.
- `app/Sources/PetController.swift`: 드래그에 따른 채팅 높이 변경, 접기·웹 닫기의 이전 펫 anchor 복원 제거. 자동 크기 변경은 현재 채팅 minX와 펫 쪽 가장자리(아래 maxY/위 minY)를 기준으로 계산하고 채팅만 화면 제한한다. 헤더 드래그의 서랍 포함 배치를 놓은 뒤에도 유지한다. 직접 좌우 리사이즈는 현재 채팅 중심·기존 웹 제한, 세로는 반대쪽 고정을 보존한다. 기존 저장 필드·단일 패널·입력 경로를 유지하며 새 타이머나 상태 저장 원본을 추가하지 않았다.
- `app/Tests/PetPositionTests.swift`, `TestMain.swift`: 실제 PetView mouseDown/Dragged/Up과 실제 view→화면 사각형을 검사하는 T1~T5 자동 회귀. 가짜 화면·포인터·시계를 사용하며 실제 손 입력으로 표현하지 않는다. 과거 carried-height 검사를 새 이동·크기 불변 계약으로 대체했다.
- `app/Tests/DrawerInlineTests.swift`: 계획에서 대체한 서랍의 펫 동반 이동 기대를 제거하고 채팅만 화면 보정하는 기대를 적용했다. 개별 배치 사례의 초기 개폐를 명시해 이전 사례의 채팅 위치를 이어받지 않게 했다. AT-DI-11 중심 리사이즈 및 경계 검사는 유지했다.
- `app/Tests/TodoDrawerTests.swift`: 펫에만 적용됐던 시험 모션 축소 설정을 제목 버튼에도 적용했다. 너비 애니메이션 직후 아직 폭이 없는 버튼을 클릭하던 불안정성을 제거했으며 프레임·펫 좌표 단정은 완화하지 않았다.
- `app/Tests/PetPositionManual.swift`: 가짜 서랍을 실제로 표시하고 로컬 웹·비영속 저장소·편집기 포커스를 확인하는 `--probe-fixtures`를 추가했다. 이 옵션은 프로그램 조작 확인이며 손 입력 증거가 아니다.
- TASK-00의 guard·wrapper는 변경하지 않았다. 실패·INT·TERM 검증을 추가 실행했다. Hermes 본체·운영 설정·다른 앱은 수정하지 않았다.

## 검증 결과
공통 실행 환경: 임시 HERMES_HOME/HERMES_ROOT, 비밀 없는 빌드 옵션, 선택한 HEJO_PYTHON. Python 의존성은 무시되는 `app/.build/pet-test-env`에 준비했다. 전체 Python 시험은 선택한 임시 환경과 읽기 전용 선택 라이브러리 HEJO_TEAM_KIT_LIB를 사용했다. 운영 환경에 패키지를 설치하지 않았다. 아래 cwd는 별도 표시가 없으면 구현 worktree 루트다. 로그의 개인 절대 경로는 자리표시자로 바꿨고 private snapshot은 증거로 복사하지 않았다.

| 명령·대상 | 실제 결과/종료 코드 | 로그 |
|---|---|---|
| `HEJO_PYTHON=… PYTEST_ADDOPTS='-s --basetemp=…' bash scripts/test.sh` · 최종 제품 소스, TodoDrawer 시험 안정화 전 | 전체 1. Python **427 passed**, gateway delivery 통과, 빌드 통과. 앱은 빈 제목 버튼 클릭 검사 실패. 설정 guard 실패도 보존 | [전체 2차](logs/pet-full-tests-2.log) |
| `HEJO_PYTHON=… bash app/scripts/test.sh` · 최종 7개 파일 | 전체 1. 빌드·서명 및 T1~T5/서랍/카드 입력 통과 후 기존 AT-UC-32 실패. 설정 guard 실패, 다운로드 guard 통과 | [앱 전체](logs/pet-app-full-tests-3.log) |
| 보호 wrapper + `app-tests --ui-clean-polish` · 수정판 및 기준판 각각 | 양쪽 1, **같은 AT-UC-32**(판정 버튼 4개) 실패. 양쪽 guard 통과. 해당 제품/시험 코드를 바꾸지 않음 | [수정판](logs/pet-ui-polish-fixed.log), [기준판](logs/pet-ui-polish-baseline.log) |
| 보호 wrapper + `app-tests --pet-position` | 최종 제품과 같은 소스: 회귀 통과. 3차는 설정 guard 실패로 1, 4차는 두 guard 포함 0 | [3차](logs/pet-position-tests-3.log), [4차](logs/pet-position-tests-4.log) |
| 보호 wrapper + `app-tests --todo-drawer` · 최종 시험 안정화 후 | 0, AT-TD/AT-DC 및 두 guard 통과 | [할 일](logs/pet-todo-tests-2.log) |
| 보호 wrapper + `app-tests --drawer-inline` | 단정 통과, 설정 guard 실패로 전체 1. 이후 최종 앱 전체에서도 서랍 단정 통과 | [서랍](logs/pet-drawer-tests-3.log) |
| 보호 wrapper + `app-tests --task41` | 0, AT-HF-92 및 두 guard 통과 | [창](logs/pet-window-tests-1.log) |
| app/scripts/test.sh의 network~review55 fixture 12개 및 test_hooks.py를 순차 실행 | 각 fixture 0, hook 9개 통과. 설정 guard 실패로 실행 전체 1, 다운로드 guard 통과 | [통신](logs/pet-network-tests.log), [명령](logs/run-pet-network-tests.sh.txt) |
| 보호 wrapper + 임시 TestMain에서 typingTests부터 마지막 unit까지 원문 그대로 실행 · 최종 제품 소스 | 기능 단정 모두 통과(APP_TEST_OK), 설정 guard 실패로 전체 1. 최초 실행은 HEJO_PYTHON 누락으로 aiohttp import 실패(1), 지정 후 기능 통과. 전체 시험 대체 아님 | [최종 부분 실행](logs/pet-remaining-unit-2.log), [초기](logs/pet-remaining-unit.log), [부분 진입점](logs/PetRemainingTestMain.swift.txt) |
| `bash app/scripts/pet-position-manual.sh --probe-fixtures --probe-duration 2` · 양쪽 checkout | 양쪽 0, 서랍/로컬 웹/비영속/편집기 포커스와 두 guard 통과. 손 입력 미실행 | [수정판](logs/pet-manual-fixtures-fixed.log), [기준판](logs/pet-manual-fixtures-baseline.log), [수정 좌표](logs/pet-manual-fixtures-fixed-events.jsonl), [기준 좌표](logs/pet-manual-fixtures-baseline-events.jsonl) |
| 임시 대역에서 실패·INT·TERM 주입, 실제 wrapper 실행 | 시험 driver 0. child 종료 7/130/143 각각 확인, 두 guard 호출과 snapshot 제거 통과 | [결과](logs/pet-wrapper-failure-signals.log), [실행 코드](logs/test-probe-wrapper.py.txt) |
| 동일 독립 좌표 불변식 harness + 기준판/수정판 PetLayout 별도 swiftc 컴파일·실행 | 수정판 0, 기준판 1(expected). 개폐 및 서랍 확장 규칙 위반을 각각 검출 | [수정](logs/pet-layout-fixed.log), [기준](logs/pet-layout-baseline.log), [harness](logs/pet-layout-regression.swift.txt) |
| 기준판 제품 + 새 T1~T5 시험 별도 컴파일/실행 | 컴파일 0, 실행 1(expected): 첫 개폐 반전의 실제 view 0.5pt 오차 검출. 이 실행은 설정 guard도 실패했으므로 분리 기록 | [컴파일](logs/pet-baseline-regression-compile.log), [실행](logs/pet-baseline-regression.log) |
| 임시 HERMES_HOME + 선택 Python의 `scripts/scan_private.py` · 신규 파일 포함 stage 후 | 0 | [개인값 검사](logs/pet-final-scan.log) |
| `git diff --cached --check` · 최종 stage | 0 | [diff](logs/pet-final-diff-check.log) |

초기 실패도 삭제하지 않았다. Python 첫 전체 실행은 선택 라이브러리·추가 시험 의존성 미비로 425 통과/2 실패였고 환경 보완 후 위 427 통과를 확인했다([초기](logs/pet-full-tests-1.log)). 펫/서랍 시험의 초기 실패는 [펫 1](logs/pet-position-tests-1.log), [펫 2](logs/pet-position-tests-2.log), [서랍 1](logs/pet-drawer-tests-1.log), [서랍 2](logs/pet-drawer-tests-2.log), [제목 버튼](logs/pet-todo-tests-1.log)에 남겼다. TASK-00 최초 빌드·scan 실패와 정상/격리 재실행 근거는 기존 logs의 baseline-build-initial/task00-scan-initial 및 후속 로그를 유지한다. 기존 Swift actor 관련 컴파일 경고는 남아 있다.

## 보호 검사 실패의 범위
메타데이터 비교 실패를 무시하거나 합격 처리하지 않았다. 실패 snapshot의 내용을 열지 않고 비교한 범주는 hejo 지원 폴더였으며 루트 및 로컬 설정 파일의 메타데이터 변화가 관측됐다. 별도로 app-tests가 시작/종료 시점 모두 없는 10초 동안에도 같은 hejo 범주가 변했다([독립 관측](logs/pet-settings-background-observation.log), 관측 명령 종료 0). 운영 앱이 실행 중인 것도 확인했다. 이는 시험 밖 변경이 존재한다는 근거이며 모든 실패의 원인이 확정됐다는 뜻은 아니다. 운영 앱을 종료·재시작하거나 사용자 파일을 복원하지 않았다. 현재 전체 실행의 오염 없음 판정은 확보하지 못했다.

## 증거 수준과 남은 항목
- 수준 1: 코드·현재 호출 경로 점검, 컴파일/빌드/개인값 검사 근거. 펫 위치 원본은 실제 sprite 사각형 하나다.
- 수준 2: T1 개폐 프레임/반전·서랍/웹, T2 실제 PetView 메서드에 가짜 포인터 주입, T3 경계/음수 화면/화면 제거, T4 헤더 이동 뒤 자동 크기·직접 경계·웹 닫기, T5 저장 좌표/크기 복구를 자동 검사했다. 기존 AT48/AT92/서랍 시험과 함께 판단한다. 독립 불변식과 기준판 회귀 실패로 검출력도 확인했다.
- 수준 3: AppKit 실행·가짜 서랍/웹 표시·편집기 포커스는 실행했으나 **T2·T4 실제 마우스 입력과 체감 지연 전후 비교는 미실행**. 데스크톱 손 입력·관측 수단이 없어 이벤트 지연 개선을 주장하지 않는다. 손 입력 합격 및 전체 시험 합격 없이 최종 완료를 주장하지 않는다.
- AT-UC-32는 기준판에서도 재현되며 타 작업 변경 없이 검토자에게 넘긴다. 전체 검사는 실패 상태로 유지한다. 운영 설정 보호 검사 실패 원인 구분·재검증 조건도 검토가 필요하다.
- 계획 담당의 독립 코드 검토·기준 브랜치 포함 확인·푸시 대상 선정은 아직이다. 푸시 승인 요청 단계가 아니다.

## 기준판 보존과 실제 입력 인계
기준판 위치는 구현 worktree의 무시되는 `app/.build/pet-baseline-root`에 보존했다. 기준 제품 소스 99개가 원 커밋과 바이트 동일함을 다시 확인했다([근거](logs/pet-baseline-source-check.log)). 동일 최신 수동 fixture로 기준판 시험 바이너리를 재컴파일했다([로그](logs/pet-baseline-fixture-compile.log)). baseline의 제품은 변경하지 않았으며 새 회귀 시험·진입점과 수동 fixture만 시험용 차이로 남아 있다. 각 checkout의 바이너리와 리소스를 사용한다.

구현 worktree에서 아래를 **순차** 실행한다. HEJO_PYTHON을 선택했다면 양쪽 동일하게 export한다. 운영 앱을 시험 대상으로 사용하거나 종료하지 않는다.

```sh
pet_baseline_root=$(cat app/.build/pet-baseline-root)
bash "$pet_baseline_root/app/scripts/pet-position-manual.sh"
# 기준판 Control-Q 종료 및 guard 결과 확인 후
bash app/scripts/pet-position-manual.sh
```

같은 화면·크기·출발 위치에서 접힌/열린/전환 중 펫을 상하좌우로 끌고 놓기, 가장자리 왕복, 헤더 이동, Control-D 서랍, Control-W 로컬 웹과 이동 후 닫기, 편집기 입력을 확인한다. 개폐 전후 펫 사각형·포인터 변위·놓은 뒤 튐과 눈에 보이는 지연을 커밋별로 기록한다. Control-R은 크기 초기화, Control-Q는 종료다. trace는 wrapper가 출력하는 임시 루트 evidence/events.jsonl에 남는다. snapshot 내용은 복사하지 않고 종료 guard 실패를 숨기지 않는다. 기준판 결함이 실입력에서 재현되지 않아도 그 사실을 기록한다.

## 직접 구현 보완 — 2026-11-24
사용자의 직접 구현 지시로 현재 대화가 구현을 인수했다. 검증 성격은 자체 점검이다. main의 `236b0177468b90d9ea23a1b1190e996db78a0694`를 merge한 `ebb011e0d32cdc94010236b3cc6e7e68f0ca7bcd` 위에 `5865aa6c6554f80d81dfbb5646f1c8dcdda539f6`를 생성했다.

- PetLayout의 단일 제한 함수가 펫 본체·휴대폰·시계 영역을 제외한 네 방향의 채팅 후보를 선택한다. 안전한 현재 좌표는 유지하고 전체 크기 보존, 최소 크기, 면적, 이동 거리 순으로 판정한다. 펫 좌표는 변경하지 않는다.
- 초기 개폐, 헤더 이동, 서랍 확장, 자동 크기 변경과 애니메이션 프레임에 같은 회피를 적용한다. 서랍과 웹 너비는 최종 표시 폭으로 다시 나눈다. 기존 웹 폭 배분의 최소 채팅 폭은 유지했다.
- T6에 실제 입력에서 보존한 겹침 좌표, 양수·음수 화면 격자, 큰 채팅, 드래그와 서랍/웹 애니메이션 프레임의 실제 view 좌표 검사를 추가했다. T4는 펫에서 멀어지는 세로 리사이즈로 반대쪽 고정 계약을 검사한다. 서랍 가로 폭 시험은 웹 선호 높이 500을 지정해 충돌 제약과 분리한다.
- 이전 acf168c 좌표 경로에 같은 실제 fixture를 넣으면 겹침 회귀 검사 exit 1, 현재 경로는 exit 0이며 두 경우 모두 펫 좌표는 유지됐다.
- 첫 전체 실행은 기본 pytest 임시 경로에서 184 setup errors/243 passed로 실패했다. 짧은 basetemp와 기존 선택 라이브러리를 명시한 재실행은 Python 427 passed, gateway delivery 및 제품 빌드/서명 검사를 통과했다. Swift 전체 결과는 후속 기록한다.
- 실제 입력 재검증과 푸시는 아직 완료하지 않았다.

### 직접 구현 최종 자동검사
대상 소스: `5865aa6c6554f80d81dfbb5646f1c8dcdda539f6` (전체 실행 시작 때 변경본, 실행 중 동일 소스를 커밋).

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| 임시 홈·짧은 pytest basetemp·HEJO_TEAM_KIT_LIB·HEJO_PYTHON 지정 `bash scripts/test.sh` | 전체 exit 1. Python 427, gateway delivery, 빌드·서명, Swift 전체 APP_TEST_OK, 모든 후속 네트워크 fixture, hook 9개 통과. 마지막 settings_guard 실패, downloads_guard 통과 | logs/pet-overlap-full-2.log |
| 보호 wrapper `bash app/.build/run-pet-tests.sh --pet-position` | exit 0. T1~T6 및 두 보호 검사 통과 | logs/pet-overlap-position-final.log |
| acf168c/현재 PetLayout + 동일 겹침 재현 Swift 실행 | 기준 exit 1, 수정 exit 0. 양쪽 펫 좌표 불변 | logs/pet-overlap-before.log, pet-overlap-after.log, pet-overlap-regression.swift |
| 임시 홈 지정 `python3 scripts/scan_private.py`, `git diff --cached --check` | 각각 exit 0 | logs/pet-overlap-scan.log, diff 출력 없음 |

기존 AT-UC-32는 이번 전체 실행에서 통과했다. 과거 실패 기록은 유지하되 현재 실패로 재보고하지 않는다. 전체 보호 실패의 변경 주체는 이 검사만으로 확정할 수 없다. 같은 최종 소스의 펫 전용 시험은 보호 검사까지 통과했지만 이를 전체 무오염 증명으로 대체하지 않는다.

## 위·아래 배치 직접 수정 (7판)
대상 `8df04a02f57ae1f3e07292969c52925724101e9b`. 사용자 피드백에 따라 좌우 후보를 제거했고, 비중첩인 옆 배치도 수직으로 복구한다. 채팅 상단 헤더 20pt에만 걸침을 허용하며 본문 침범은 금지한다. 펫 좌표·크기·드래그 경로는 변경하지 않았다. 이미 선택된 수직 배치의 화면 제한 및 선호 크기는 기존 원본을 따른다. 서랍 단위 시험의 시작 펫 좌표를 각 채팅 위로 옮겨 가로 화면 경계 단정과 새 수직 계약을 분리했으며 기존 수치 단정은 유지했다.

최종 자체 점검(모두 해당 커밋과 동일한 소스):
- swiftc 전체 시험 컴파일 exit 0; 제품 build.sh exit 0, logs/pet-vertical-build.log.
- 보호 wrapper --pet-position exit 0, T1~T6/헤더 걸침/수직 축소/옆 배치 거부 및 두 보호 검사 통과, logs/pet-vertical-final-pet-position.log.
- --drawer-inline 기능 APP_TEST_OK(배치·픽셀·헤더·필터·서랍 전부 통과), settings_guard 실패로 전체 exit 1, downloads_guard 통과, logs/pet-vertical-final-drawer-inline.log.
- --task41 exit 0, AT92 및 두 보호 검사 통과, logs/pet-vertical-final-task41.log.
- 수동 격리 --probe-fixtures --probe-duration 2 exit 0, 로컬 웹·서랍·포커스와 두 보호 검사 통과, logs/pet-vertical-smoke.log. 실제 마우스 합격 증거는 아니다.
- 같은 lateral fixture: 5865aa6은 exit 1, 현재 소스는 exit 0, 양쪽 펫 불변. logs/pet-vertical-before.log, pet-vertical-after.log, pet-vertical-regression.swift.
- 임시 홈 개인값 검사 및 staged diff --check 각각 exit 0. logs/pet-vertical-scan.log.
직전 5865aa6의 전체 기능시험 결과는 그 커밋의 증거로 보존한다. 이번 변경은 관련 AppKit/레이아웃 회귀를 재실행했으며 Python·네트워크 전체를 재실행한 것으로 보고하지 않는다.


## 최종 사용자 실물 확인 — 2026-11-24
대상 `8df04a02f57ae1f3e07292969c52925724101e9b`. 사용자가 최종 시험창에 대해 “e됫다 만족함”으로 수락했다. 위쪽 헤더 걸침 또는 아래 배치와 드래그에 관한 사용자 재확인 대기는 해소됐다. 해당 시험 PID와 실행 명령을 확인한 뒤 시험 프로세스만 SIGTERM 종료했다. wrapper 종료 코드 1, 설정 metadata guard 실패, 다운로드 guard 통과. 사용자 수락과 보호 검사 실패를 구분한다. 로그는 logs/pet-vertical-user.log, 입력 사건 수집 요약은 logs/manual-vertical-user-summary.json에 기록했다.


공개 통합은 public-integration.md를 따른다. 제품 커밋 7db94ee0fb4220525dbcf5072ee79668a9f9a63c. 사용자 승인에 따라 공개 기준의 수정은 보존했다. 기능 수락 완료, 전체 검사 제한을 표시한 부분 완료 상태로 화면 푸시 승인을 요청한다. 원본 개발 작업공간/이력/증거 보존.
