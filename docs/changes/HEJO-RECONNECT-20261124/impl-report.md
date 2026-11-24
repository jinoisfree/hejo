# 구현 인계: HEJO-RECONNECT-20261124

[확인] **TASK-HR-04 재설치·실행·서버 연결 확인을 마쳤다.** 사용자 승인 ‘지금 재설치’에 따라 수락 커밋 `a420b634428bf33dc4c97c081b5693a3de491bfc`의 보존한 정식 후보를 설치했다. 시스템 키체인 확인 창을 관측했고 사용자가 직접 처리 완료를 알렸다. 활성 TCP와 앱의 ‘서버에 연결됨’ 표시·대화 창을 확인했다. 실행 파일·서명·BuildInfo는 후보와 일치한다. 코드·시험 변경과 추가 커밋은 없다. 첫 시도·복구 기록은 **15절**, 이번 성공 결과는 **16절**이다. **AT-HR-06 사용자 체감 관측·현재 명세 반영·푸시는 남아 있으므로 전체 상태는 부분 완료다.**

문서는 계획 담당 폴더의 원본이며 실행 경로는 구현 worktree 기준이다. **1~13절은 최초 구현 `8c16c2e` 시점의 기록**이다. 이후 AT-HR-01~05 수락과 기존·환경 실패 판단은 [검토 1회차](verdict.md)를, 이번 통합 결과와 현재 검토 대상은 **14절**을 따른다.

## 1. 받은 설계와 판단

- 설계: [handoff.md](handoff.md), spec/design v1·수락 시험 v2. 기준 `3b0006179eef606ba3f3bf1de5230e8338f9cea7`, 연합개발, 위험도 일반, 필요한 증거 수준 1·2·3.
- 구현자 판단: **보류(20-implementation 2절 보고)**. TASK-HR-01·02 완료, TASK-HR-03은 성능·집중 시험·개인값 검사 완료, 전체 앱 회귀 차단. TASK-HR-04는 이번 범위 밖이다.
- 차단: 기존 `AT-HC-27 show after onDismiss clears input and remains usable`가 기준·수정 빌드의 같은 `-O` 조건 순차 실행에서 모두 실패했다. 또한 앱 회귀 보호 검사에서 실제 `hejo` 설정 트리의 메타데이터 변화가 감지됐다. 원인은 미확정이며 운영 앱을 멈추거나 설정을 되돌리지 않았다. 이 상태를 전체 회귀 통과로 바꾸지 않는다.

## 2. 변경 후 구조

GateClient는 welcome·sync_done·누락 seq로 연결 수명의 knownHead를 갱신하고 hasPendingHistory만 내준다. Controller는 기존 performUpdates에서 기록 프레임의 화면 통지만 보류하며, head 도달·seq 없는 통지 경계·기존 즉시 통지·0.5초 점검에서 전달한다. 프레임 적용·저장·프레임별 모델 부수 효과는 그대로 실행한다.

## 3. 더한 것과 뺀 것

제품 수정은 `app/Sources/GateClient.swift`, `app/Sources/ConversationController.swift` 두 파일뿐이다.

- welcome마다 head를 새로 정하고 연결 시작·끊김·stop·인증 거절 때 폐기한다. JSON boolean이 NSNumber/Int로 변환되는 경우를 제외하며, 정수 아닌 head는 정보 없음으로 취급한다. head는 저장하지 않는다.
- 프레임당 통지 경로를 같은 자리에서 조건부 보류로 교체했다. 기존 performUpdates 중첩과 다른 동기 통지는 유지한다.
- setPaused 해제의 프레임별 통지 반복을 하나의 트랜잭션으로 교체했다.
- 기존 0.5초 콜백의 본문을 pollUpdates로 옮겨 보류 통지도 전달한다. 새 타이머·전역 지연·저장 항목·별도 적용 경로는 없다.

시험 변경은 `app/Tests/HejoReconnectTests.swift`, `HejoReconnectBoundaryTests.swift`, `hejo_reconnect.py`, `Fixtures/HejoReconnect/{README.md,baseline.json,expected.json}`, 등록부 `TestMain.swift`다. **기존 단언 조정·삭제·skip·허용 오차 변경은 없다.**

## 4. 설계와 달라진 점

제품 설계 차이는 없다. 구현자가 만든 소켓 대역 명부의 필수 avatar 누락을 추가 규격 점검에서 발견하여 전송 직전에 기본값 null을 채웠다. 실제 전송 프레임은 공유 규격으로 검증한다. 동결 기대값과 합성 입력은 수정하지 않았다. 제품 수정 전에 만든 기준 바이너리를 그대로 사용해 기준·수정 소켓 측정만 다시 대조했다. 원래 소켓 측정과 summary는 기준 폴더의 `socket-before-schema-check/`, `summary-before-schema-check.json` 및 `check-initial/`에 보존했다.

## 5. 계측 경로와 임시 코드

소켓 receive 소요와 반환 직후 탐침을 재기 위해 빌드 폴더의 GateClient 사본에 실제 receive 앞뒤 계측만 삽입한다. 실제 소켓 루프·receive·저장·모델·View를 대체하지 않는다. 제품에는 시험 hook이 없다. 같은 계측을 기준·수정 빌드에 사용했다. 삽입 전후 문자열, 원본 소스 해시, 컴파일 옵션·컴파일러, 사본·바이너리 해시는 각 build.json에 남는다. `--no-build`는 소스·옵션·runner·바이너리 fingerprint 일치 여부를 검사한다.

pollUpdates는 기존 주기 점검의 본문이며 명세의 한 주기 호출을 직접 시험하는 데도 쓴다. 남긴 임시 제품 코드와 공존 적용 경로는 없다.

## 6. 변경 성격과 보존

화면 통지 시점만 의미 변경이다. 제품 수정 전에 AT-HR-05 최종 관측을 동결했고, 수정본의 글 ID·본문·순서·상태, applied, 캐시 JSONL 바이트 해시, 읽음·종·질문·선택·초안·전송/오류 관측이 바이트 단위로 같았다. 기존 HEJO-PERF expected도 일치한다. 동결 기대값을 다시 생성하지 않았다.

## 7. 시험과 결함 검출

- HejoReconnectTests: 고정 8명·25스레드·4글(800건), 회원 상태 330항목, 실제 840×760 View, N=20·100·300 통지 횟수, 캐시 포함 receive 비용, +75/+150/+225 반환 직후 입력/방 전환 탐침, 최종 관측 비교.
- HejoReconnectBoundaryTests: 여러 쪽·수신 멈춤·끊김·head 없음/잘못된 값(JSON boolean 포함)·head 도달·sync_done의 새 head·누락 보충·사용자 동작·규격/저장 실패, M=1·50 일시정지 해제. 합성 경계 시험은 일반 앱 회귀에도 등록했다.
- 과거 결함 검출 근거는 제품 수정 전 AT-HR-01의 예상 실패(23·103·303회)다. 별도 제품 mutation은 생략했고 기준 결함을 실제 재현했다.
- 기존 시험·단언을 지우거나 합치지 않았다. 범위 밖 AT-HC-27을 통과시키기 위한 수정도 하지 않았다.

## 8. AC별 자체 결과

| 수락 시험 | 결과 | 근거 |
|---|---|---|
| AT-HR-01 | 통과 | N=20·100·300 모두 4회, 실제 카드 최종 편집·모델 및 화면 반환 경계 확인 |
| AT-HR-02 | 통과 | 합성 경계 + 실제 소켓 pages/gap/protocol/storage 모두 통과 |
| AT-HR-03 | 통과 | M=1·50 모두 반환 전 순서대로 적용, 통지 1회 |
| AT-HR-04 | 통과 | 아래 최종 수치, 동일 입력 해시, 5회 및 warm-up 1회 원시 결과 |
| AT-HR-05 | **부분 충족/차단** | 신규 동결 비교와 기존 HEJO-PERF expected 일치. 전체 앱 회귀는 AT-HC-27 및 보호 검사 실패로 미통과 |
| AT-HR-06 | 미실행 | 설치 승인·실물 확인은 이번 범위 밖 |

## 9. 최종 계측

같은 Mac, Swift 5 모드, `-O -whole-module-optimization`, arm64/macOS 13 대상. 프레임당 store.append를 측정 구간에 포함한다. 최종 비교는 앱 회귀와 일부 병행 실행됐다. OS 키보드 지연의 증거는 아니다.

| 지표 | 기준 | 최종 수정 |
|---|---:|---:|
| 합성 300건 중앙값 / 최대 | 20.863602 / 21.026624초 | 0.648065 / 0.688385초 |
| 실제 소켓 재연결 중앙값 / 최대 | 20.512291 / 20.801385초 | 0.647736 / 0.697567초 |
| 합성 receive 최대 | 0.115795초 | 0.134765초 |
| 실제 소켓 receive 최대 | 0.174358초 | 0.183355초 |
| N=20·100·300 통지 | 23·103·303 | 4·4·4 |

합성 중앙값 감소율 96.89%. 최종 합성 탐침별(+75·+150·+225) 큐 대기 중앙값은 0.000008625·0.000007458·0.000006208초, 최대는 0.001465875·0.000009167·0.000031833초다. 소켓은 중앙값 0.000013333·0.000012583·0.000013208초, 최대 0.000014708·0.000015708·0.000033000초다. 모두 지정 applied에서 제출됐고 head 전에 처리되며 동작 결과를 확인했다.

합성 입력 SHA256 `4ed0efddd4c18cdab6379873e7e6915c2ea5cb55ee6b65cafe26a0ffc1554889`, 실제 wire 입력 SHA256 `f6382bf81808958b086da668cef89ac06c025030f544d0501256c88f3cc3ae00`. 양쪽 빌드에서 같다.

## 10. 실제 명령·종료 코드·로그

Python은 `.build/reconnect-env.sh`가 가리키는 유효한 Hermes venv를 사용했다. 이 로컬 파일에는 의존성 경로가 있으며 추적하지 않는다. 모든 재현 자료는 임시 LocalStore·가짜 명부·가짜 글이다.

| 실행 | 실제 결과 | 증거(worktree 기준) |
|---|---|---|
| `python app/Tests/hejo_reconnect.py baseline` | exit 0, 제품 수정 전 기준 계측·동결, AT-01 예상 실패 기록 | `.build/hejo-reconnect-evidence/baseline-command.log`, `baseline/build.json`, `baseline/{semantic,synthetic}/` |
| 소켓 규격 보완 뒤 `python -`로 기존 기준 바이너리와 socket_run 실행 | exit 0, 양쪽 실제 소켓 조건 통과 | `.build/hejo-reconnect-evidence/socket-schema-recheck.log`, `baseline/socket/{fixture,execution,socket-performance}.json` |
| 최종 `build(evidence, False)` 최적화 컴파일 | exit 0 | `.build/hejo-reconnect-evidence/final-optimized-build-command.log`, `check/build.json` |
| `python app/Tests/hejo_reconnect.py check --no-build` | exit 0, 모든 집중 조건 통과 | `.build/hejo-reconnect-evidence/check-final-command.log`, `check/budgets.json`, `check/{semantic,synthetic,socket,boundaries,boundary-socket,legacy-perf}/` |
| `bash scripts/test.sh` | exit 1, 243 passed / 184 errors: 긴 임시 경로의 Unix 소켓 오류 | `.build/hejo-reconnect-evidence/final/{regression.log,results.json}` |
| `TMPDIR=/tmp bash scripts/test.sh` | exit 1, 426 passed / 1 failed: 중첩 경로가 여전히 김 | `.build/hejo-reconnect-evidence/final/regression-short-tmp.{log,json}` |
| `TMPDIR=/tmp PYTEST_ADDOPTS=--basetemp=<temporary>/p bash scripts/test.sh` | exit 1. 문·수락 시험 427 passed 및 격리 게이트웨이 실행 통과. 이후 head 형식 보완 편집과 빌드가 겹쳐 컴파일 중단 | `.build/hejo-reconnect-evidence/final/regression-short-base.{log,json}` |
| 소스 고정 뒤 `TMPDIR=/tmp bash app/scripts/test.sh` | exit 1. 빌드 통과, 집중 경계 시험 포함. AT-HC-27 및 실제 hejo 메타데이터 보호 검사 실패 | `.build/hejo-reconnect-evidence/final/app-regression.{log,json}` |
| 기준·최종 최적화 바이너리의 기본 앱 시험을 같은 인자·조건으로 순차 실행 | 각각 exit 1, 둘 다 같은 AT-HC-27 실패, timeout 아님 | `.build/hejo-reconnect-evidence/final/{baseline-unit-serial.log,check-unit-serial.log,unit-serial.json}` |
| `bash app/scripts/build.sh` (최종 커밋 뒤) | exit 0 | `.build/hejo-reconnect-evidence/final/build-final.{log,json}` |
| `python scripts/scan_private.py` | exit 0, 최종 파일 stage 후 검사. 임시 가짜(빈) 명부·금고 입력 | `.build/hejo-reconnect-evidence/final/private-final.{log,json}` |
| 소스·범위·동결 해시 감사, `git diff --cached --check` | exit 0 | `.build/hejo-reconnect-evidence/final/source-audit.json` |

Unix 경로 오류는 추적 진단에서 `AF_UNIX path too long`으로 확인했다(`gate-path-diagnostic.log`). 기준 커밋 아카이브에서도 재현됐다(`gate-baseline-first-error.json`, exit 1). 짧은 basetemp의 해당 단일 시험은 통과했다(`gate-short-basetemp.log`, exit 0). 기대값·시험 코드를 완화하지 않고 실행 환경 경로만 줄였다.

첫 기준 최적화 컴파일도 등록 파일을 컴파일 중 편집하여 exit 1이었다. 정리 후 다시 빌드해 통과했다(`baseline-compile-attempt1/`). 편집과 빌드를 겹친 두 실패는 구현자의 실행 오류이며 제품/시험 실패와 구별한다.

하위 에이전트는 사용하지 않았다. 도달 증거는 1(빌드)·2(문 대역 통합)·3(실제 AppKit·GateClient 소켓 루프 실행/계측). 운영 문 접속이나 수준 4 실물 증거를 뜻하지 않는다.

## 11. 미검증·남은 위험과 범위 밖

- 전체 앱 회귀가 조기에 끝나 후속 기존 network fixture 묶음은 미실행이다. 이번 실제 소켓 집중 시험으로 이를 대신했다고 주장하지 않는다.
- AT-HR-06, 사용자 설치 승인, 최종 검토·verdict·현재 명세 반영, 원격 통합·푸시가 남았다.
- 실제 설정 보호 검사는 hejo 메타데이터 변화를 감지했다. 내용은 열지 않았고 원인은 미확정이다. 운영 앱·서버·설정에 쓰거나 재시작하는 명령, 실제 메시지 전송은 실행하지 않았다. 다른 프로세스의 변화를 임의로 되돌리지 않았다.
- gate/schemas/hub/LocalStore/View 변경은 없다. 로컬 main 제품 파일과 다른 작업은 수정하지 않았다. AT-HC-27의 코드·단언은 그대로 두었다.

## 12. 검토 요청·권고

검토자는 두 소스 파일, 최종 `check/build.json`의 소스 fingerprint, 집중 시험 원시 결과, 기준/수정 AT-HC-27 동일 실패를 직접 확인해 달라. 기존 performUpdates 중첩과 기록 보류의 경계, 연결마다 head 폐기, JSON head 판별, 기존 주기 점검, 계측 사본의 실행 경로 보존을 중점 검토해 달라.

전체 회귀 미충족을 예외 통과로 바꾸지 말고 기존 연결창 시험의 실패 원인·실행 환경과 보호 검사 변화를 먼저 판단하는 것을 권고한다. 범위 밖 제품 수정이 필요하면 보완 계획이 필요하다. 수락 기준 완화나 운영 앱 조작으로 우회하지 않았다.

## 13. 검토 대상

- worktree: `../.worktrees/hejo-reconnect-public-149bf6c9`
- 브랜치: `role-workflow/32-149bf6c9-public`
- 전체 커밋: `8c16c2e54b2a55425aeafdf1fc15deed51449cdc`
- 원격: github. 원격 main은 읽기 확인 결과 `81d5545810f8c9337f9297493a819e4bf976174b`다. 지시된 기준을 유지했으며 merge·rebase·push는 하지 않았다. 이 후속 main은 두 제품 파일에 차이가 없지만 통합·재검토는 별도다.
- Git 작업 트리는 커밋 뒤 깨끗하다. 계획 담당 폴더에 이 보고서만 별도로 썼다.
- 커밋 기준 최종 일반 빌드 exit 0. BuildInfo는 root tree `133eb5dec02b346c8ad53d874f4bba2376b81008`, dirty=false로 위 커밋의 트리와 같다. 앱 바이너리 SHA256과 집중 시험 컴파일 fingerprint가 커밋의 소스와 일치함을 `final/committed-verification.json`에 확인했다. 빌드 산출물은 설치하지 않았다.

## 14. TASK-HR-06 보완 인계

### 받은 범위와 현재 판단

검토 1회차의 TASK-HR-06 지시대로 최신 공개 main 통합, 비차단 V-HR-01 처분, 통합본 재검증을 수행했다. 위험도 일반, 필요한 증거 수준 1·2·3이며 이번에도 해당 수준까지 실행했다. 수락 시험 v2·합격선·동결 fixture는 변경하지 않았다. 구현자 판단은 **보완 구현 완료·재검토 요청**이다. 전체 앱 스크립트의 보호 검사 실패를 통과로 바꾸지 않는다.

### 통합과 변경 범위

- 시작 커밋: `8c16c2e54b2a55425aeafdf1fc15deed51449cdc`.
- `git ls-remote github refs/heads/main`으로 착수 때와 검증 종료 때 확인한 공개 tip: `81d5545810f8c9337f9297493a819e4bf976174b`(종료 0). 종료 확인 로그는 `.build/hejo-reconnect-evidence/integration/remote-main.log`와 `remote-main-command.json`이다.
- merge 커밋: `d5ebc87df2d133baf056e81f0f87fd68599bfd0b`. 부모는 시작 커밋과 위 공개 tip이다. rebase·강제 변경은 하지 않았다.
- 충돌은 `app/Tests/TestMain.swift` 등록부 한 곳이었다. 재연결의 세 실행 경로와 원격의 `--thread-done` 경로를 모두 보존했다. 두 재연결 제품 파일에는 충돌이 없었다.
- merge로 들어온 `ConversationView.swift`·`ThreadTools.swift`는 공개 tip의 바이트 그대로다. `GateClient.swift`·`ConversationController.swift`는 시작 커밋과 동일하다. merge 이외 제품 수정은 없다.
- V-HR-01 수정 커밋이자 **현재 검토 대상**: `a420b634428bf33dc4c97c081b5693a3de491bfc`. 이 커밋은 `app/Tests/hejo_reconnect.py`만 변경했다.
- 브랜치: `role-workflow/32-149bf6c9-public`, 원격: `github`, worktree: `../.worktrees/hejo-reconnect-public-149bf6c9`. 작업 트리는 깨끗하다. 계획 담당 폴더에서는 이 보고서만 갱신했다.

### V-HR-01 처분: 수용·수정

빌드 재사용 조건에서 HEAD와 미커밋 제품 diff를 제거하고, 별도 `provenance`에만 기록한다. 실제 비교 입력은 Swift 소스 내용 해시, 컴파일 옵션·컴파일러, runner 해시, 계측 치환 문자열·사본 해시이며 바이너리 해시도 계속 검증한다. 판정식·기대값·예산에는 변경이 없다.

통합 merge 커밋에 최종 runner 수정을 적용한 상태에서 새로 빌드하고 집중 검사를 실행했다. 이어 runner 수정을 커밋한 뒤 **같은 바이너리로 `check --no-build`를 실행하여 종료 0**을 확인했다. 새 빌드 당시 HEAD와 diff는 `integration/check-fresh-command.json`, 영수증은 `integration/check-fresh-results/build.json`에 남겼다. 최종 감사에서 Swift 입력 154개와 runner가 현재 검토 커밋과 일치함을 확인했다. 따라서 두 실행은 같은 소스를 검증한다.

추가 검사 `.build/hr06-fingerprint.py`는 커밋 뒤 동일 입력의 재사용을 확인한 다음, 임시 영수증의 소스·옵션·컴파일러·runner·계측 사본·바이너리 해시를 각각 바꾼 여섯 경우 모두 `stale measurement build`로 거부함을 확인했다. 실제 제품 소스·영수증·바이너리는 변조하지 않았다. 종료 0, 로그 `integration/fingerprint.log`, 명령 기록 `integration/fingerprint-command.json`이다.

### 통합 계측

다음 경로의 공통 접두어는 `.build/hejo-reconnect-evidence/`다. 기존 검토자의 `check/` 자료는 `check-planner-reviewed/`에 보존했다. 이번 새 빌드 실행 결과는 `integration/check-fresh-results/`에 보존한 뒤, 빌드 영수증과 바이너리를 유지한 `check/`에서 커밋 뒤 재사용 검사를 실행했다. 재실행 전 기존 결과 하위 폴더를 보관한 것은 증거 덮어쓰기를 피하기 위한 파일 이동이다.

| 지표 | 통합 새 빌드 | 커밋 뒤 재사용 |
|---|---:|---:|
| 합성 중앙값 / 최대 | 0.613573 / 0.666928초 | 0.592470 / 0.598764초 |
| 실제 소켓 재연결 중앙값 / 최대 | 0.636874 / 0.649751초 | 0.633804 / 0.647345초 |
| 합성 receive 최대 | 0.131322초 | 0.118828초 |
| 실제 소켓 receive 최대 | 0.171644초 | 0.170827초 |
| N=20·100·300 통지 | 4·4·4 | 4·4·4 |

양쪽 모두 warm-up 1회와 측정 5회, 탐침 +75·+150·+225의 제출 applied·head 전 처리·동작 결과가 유효하다. 여섯 경로·탐침을 합친 큐 대기 최대는 새 빌드 0.000013875초, 재사용 0.000012583초다. 중앙값 0.25초·최대 0.5초, receive 최대 0.5초 기준을 충족한다. 합성 중앙값은 원래 기준 대비 약 97% 감소했다. 합성·wire 입력 해시는 9절과 동일하다. 신규 동결 관측과 기존 HEJO-PERF 동결 관측도 일치하며, 합성·소켓 경계 검사와 일시정지 해제 검사가 통과했다.

### 실제 검증 명령과 결과

모든 Python은 `.build/reconnect-env.sh`의 Hermes venv를 사용했다. 앱·시험은 임시 `HERMES_HOME`을 사용했고, 개인값 검사는 임시 가짜(빈) 명부·금고로 실행했다. 일반 빌드는 `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1` 조건이다. 다음 표의 로그 접두어는 `.build/hejo-reconnect-evidence/integration/`다. 전체 argv·cwd·실제 종료 코드·대상 커밋은 `regression-results.json` 및 각 명령 JSON에 있다.

| 명령 | 실제 결과 | 로그 / 명령 기록 |
|---|---|---|
| `$HEJO_PYTHON app/Tests/hejo_reconnect.py check` | exit 0, 새 계측 빌드와 모든 집중 조건 통과 | `check-fresh.log`, `check-fresh-command.json`, `check-fresh-results/` |
| `$HEJO_PYTHON app/Tests/hejo_reconnect.py check --no-build` | 현재 검토 커밋에서 exit 0 | `check-no-build.log`, `check-no-build-command.json`; 원시 결과는 공통 접두어의 `check/` |
| `$HEJO_PYTHON .build/hr06-fingerprint.py` | exit 0, 동일 입력 수락·변조 여섯 경우 거부 | `fingerprint.log`, `fingerprint-command.json` |
| `bash app/scripts/test.sh` | exit 1. 일반 단위 묶음·fixture 12개·hooks 9개는 통과한 뒤 설정 보호 검사 실패. 다운로드 보호 검사는 통과 | `app-regression.log`, `regression-results.json` |
| 앱 폴더에서 `$HEJO_PYTHON Tests/<name>_fixture.py .build/app-tests` | network·conversation·pictures·thread·workspace·bubble_reply·home_room·rooms·composer_target·downloads·web_pane·review55 모두 각각 exit 0 | `fixture-<name>.log`, `regression-results.json` |
| 앱 폴더에서 `$HEJO_PYTHON Tests/test_hooks.py` | exit 0, 9 tests OK | `test-hooks.log`, `regression-results.json` |
| 앱 폴더에서 `.build/app-tests --thread-done <generated Pet resources>` | exit 0, AT-TD-01~06·thread tools·typing 통과 | `thread-done.log`, `regression-results.json` |
| `xcrun swiftc ...`로 임시 TestMain 사본 단위 묶음 빌드·`codesign ...` | 각각 exit 0. 정확한 인자와 전체 소스 목록은 명령 기록 참조 | `unit-remaining-compile.log`, `unit-remaining-sign.log`, `regression-results.json` |
| 첫 임시 단위 묶음 실행 | exit 1, 바이너리 배치 때문에 펫 리소스를 찾지 못함(아래 설명) | `unit-remaining.log`, `regression-results.json` |
| 앱 폴더에서 `.build/app-tests-remaining <generated Pet resources>` | exit 0, APP_TEST_OK | `unit-remaining-resource-layout.log`, `unit-remaining-resource-layout.json` |
| `bash app/scripts/build.sh` | 현재 검토 커밋에서 exit 0 | `build-final.log`, `regression-results.json` |
| `$HEJO_PYTHON scripts/scan_private.py` | 현재 검토 커밋에서 exit 0 | `private-final.log`, `regression-results.json` |
| `$HEJO_PYTHON .build/hr06-audit.py` | exit 0, 소스·범위·동결·바이너리·BuildInfo·깨끗한 Git 상태 검사 통과 | `source-audit.log`, `source-audit.json` |

**앱 회귀 해석:** 이번 일반 단위 묶음은 수정하지 않은 원본 TestMain으로 `APP_TEST_OK`까지 진행했고 후속 fixture도 실행됐다. 기존 AT-HC-27 실패는 이번 실행에서 재현되지 않았다. `ThreadDoneTests`의 `AT_TD_01_06_PASS`는 일반 단위 묶음과 별도 `--thread-done` 실행 모두에서 확인했다. 전체 스크립트 종료 1은 마지막 `settings_guard.py`의 `Real settings metadata changed`다. 검토 1회차에 기록된 보호 검사와 같은 실패 메시지이며, 이번 실행에서는 변한 세부 항목을 추가 진단하지 않았다. 실제 설정 내용은 열지 않았고 운영 앱·설정을 조작하거나 보호 검사를 바꾸지 않았다.

**임시 단위 묶음:** 사용자 지시대로 원본의 일반 `connectionsTests()` 호출 하나만 뺀 빌드 사본을 사용했다(`unit-exclusion.patch`). 기존 단언·추적 시험 파일의 조정·삭제는 0건이다. 첫 실행에서 구현자가 바이너리를 증거 폴더에 둬 `AppearanceTests.swift`의 실행 파일 옆 `hejo.app` 탐색이 실패했고, 앱 폴더에서의 대체 상대 경로도 맞지 않았다. 같은 바이너리를 일반 시험과 같은 `app/.build/`에 복사해 재실행하자 통과했다. SHA256이 같은 바이너리임과 첫/재실행의 리소스 존재 여부는 `unit-remaining-resource-layout.json`에 남겼다. 제품·시험·리소스를 고쳐 통과시킨 것이 아니다. 실행 helper `.build/run-hr06.py`도 이 올바른 배치를 사용하도록 정리했다.

**gate 재사용:** 통합 전후 `gate/`, 루트 `tests/`, `schemas/`, `hub/`는 무변경이다(`source-audit.json`). 사용자 허용대로 최초 구현의 gate·수락 시험 427 passed 및 격리 gateway 실행 통과 로그 `../final/regression-short-base.log`를 재사용했다. 이 로그를 포함한 루트 전체 스크립트의 최종 종료 코드는 당시 1이었으며, 10절에 기록된 후속 앱 컴파일 실행 오류 때문이다. gate 묶음의 통과와 전체 스크립트의 실패를 구분한다.

### 현재 산출물과 남은 일

현재 커밋의 일반 빌드 BuildInfo는 tree `cc446a96975156f20a1a15acafe8a86a3acaf4f3`, dirty=false다. 실제 앱 바이너리 해시와 계측 입력 154개·runner·계측 바이너리의 커밋 일치는 `source-audit.json`에 있다. 설치하지 않았다.

남은 일은 계획 담당의 통합본 재검토·V-HR-01 처분 확인과 tasks/verdict 상태 갱신, 사용자 설치 승인 뒤 AT-HR-06, 현재 명세 반영, 플러그인 화면 승인 푸시다. 설치·운영 앱/서버 조작·실제 메시지·git push는 이번에도 실행하지 않았다. 기존 V-HR-02와 head 과대 시 최대 0.5초 표시 지연 위험은 남아 있다. 새로운 제품 설계 차이는 없다.

## 15. TASK-HR-04 로컬 설치 시도·복구 인계

### 승인·대상과 결과

2026-11-24 사용자의 ‘설치 진행’ 승인과 검토 2회차 인계에 따라 수행했다. 위험도 일반, 범위는 기존 로컬 앱 번들의 교체·실행·실패 시 복구다. 승인 커밋 `a420b634428bf33dc4c97c081b5693a3de491bfc`, tree `cc446a96975156f20a1a15acafe8a86a3acaf4f3`, 브랜치 `role-workflow/32-149bf6c9-public`를 착수·교체 전에 재확인했다. 코드·시험·수락 기준·운영 서버는 변경하지 않았고 작업 트리는 깨끗하다.

**설치 후 연결 검증 실패 → 원본 복구·재실행 완료.** 새 앱의 정식 빌드·서명·BuildInfo·실행 경로·실행 파일 해시와 대화 화면 표시는 확인했지만, 서버 연결이 확인되지 않았다. 인계의 실패 절차대로 새 앱을 정상 종료하고 백업 번들을 복원했다. 현재 설치·실행된 파일은 설치 전 원본과 동일하다. 수신 성능의 실물 판정 AT-HR-06은 미실행이다.

이 절은 14절 뒤에 수행한 설치 시도의 기록이다. 이전 절들의 ‘설치 미실행’은 그 시점의 상태다.

### 로컬 증거와 보존

모든 설치 상세·백업·CPU·sample은 **저장소 밖 로컬 증거 폴더** `install-20261124T122139Z/`에 두었다. 폴더 권한은 0700이다. 아래 파일 경로는 이 폴더 기준이다. 실제 루트 위치는 구현 worktree의 무시된 `.build/reconnect-install-evidence-location.txt`와 역할 인계에만 기록했다. 추적 문서에 개인 절대 경로·계정·주소·인증값·sample 본문을 넣지 않았다.

- `before.json`: 설치 전 번들 ID·실행 위치·버전·실행 파일 해시. 실제 프로세스 PID 24164와 번들 ID `io.github.hermes-hejo.hejo`를 함께 확인했다.
- `candidate-hejo.app`: 정식 빌드 후보 보존본.
- **`backup/hejo.app`**: 이번 작업에서 새로 만든 설치 전 원본 백업. 이전 작업의 백업은 덮지 않았다. 복사 후 서명과 실행 파일 해시를 대조했다.
- `prepared.json`, `prepare-commands.json`: 후보·백업·서명·리소스 대조와 실제 실행 명령.
- `replacement.json`: 실제 교체·새 프로세스 PID 90077·실행 경로·후보 해시 대응.
- `restored-running.json`, `result.json`: 복구 후 실제 PID 93994·실행 경로·원본 해시 대응과 최종 결과.

### 정식 빌드와 배포 기능 보존

`bash app/scripts/build.sh`를 승인 커밋에서 실행해 exit 0이었다(`formal-build.log`, `formal-build-command.json`). `HEJO_SKIP_GOOGLE_SECRET`·시험 컴파일 조건을 쓰지 않았다. 기존 앱에 내장된 Google 로그인 빌드 값을 출력 없이 빌드 자식 프로세스에 전달했다. 운영 Hermes 비밀 파일이나 키체인 내용은 도구로 열지 않았다. 빌드 로그에 해당 비밀 값이 섞이지 않도록 처리했다.

후보의 전체 Info.plist 값은 기존 배포본과 같으며, Google 로그인 값·표시 버전 0.2.7(9)·서명 식별자/인증서·entitlements·Sparkle 버전을 보존했다. 후보와 복사본·설치본·백업의 `codesign --verify --deep --strict`가 모두 exit 0이었다. 후보 BuildInfo는 승인 tree와 같고 dirty=false다.

리소스 첫 대조는 도움말 파일명 차이로 exit 1이었다(`resource-preflight-first.json`, `resource-comparison.json`). 기존 `connection-help.html`과 후보 `연결안내.html`의 SHA256은 모두 `c06d457c124d09bfeecc742132e10ea2bcbf650bb59a302dd259ec340ba2a3e8`이다. 승인 코드의 `HooksHelp.swift`가 후보의 한글 파일명을 찾는 것을 확인했다. 이 동일 내용의 이름 대응과 변경되는 BuildInfo를 구분한 뒤 총 9개 리소스 내용이 같음을 확인해 준비 검사를 통과했다. 번들·코드·리소스를 추가 수정하지 않았다.

| 실행 파일 | SHA256 |
|---|---|
| 설치 전 원본 및 새 백업 | `f8733f8ec8b45db54c1709350b40c0ce457f78a391240dac211928bf7c01fa62` |
| 정식 빌드 후보·교체 후 실행 경로의 파일 | `1576290a0e9c54689929ce1c50ad656d651a0d24023f445b338a1628d39fc53d` |
| 복구 후 설치·실행 경로의 파일 | `f8733f8ec8b45db54c1709350b40c0ce457f78a391240dac211928bf7c01fa62` |

실제 경로는 NSWorkspace의 번들 ID 조회와 `ps -p <PID> -o comm=`를 대조했다. 개인 경로 대신 `before.json`·`replacement.json`·`restored-running.json`의 경로 필드를 근거로 남긴다.

### 정상 종료·실행·연결 실패

1. 원본의 정상 종료가 인증정보 삭제를 유발하는 설정인지 필요한 자동 로그인 플래그만 읽어 확인했다. 설정 값을 바꾸지 않았다.
2. 서명 검증한 후보를 임시 배치하고 `NSRunningApplication.terminate`로 원본을 정상 종료했다. 요청 수락 후 6.86초에 원본 PID 종료를 확인했다(`quit.json`). 강제 종료는 하지 않았다.
3. 앱 번들을 교체하고 `open <설치 번들>`을 실행했다. 새 PID의 번들 ID·실행 경로·SHA256·BuildInfo가 후보와 일치했다. `대화 열기` 메뉴를 실행했고 실제 화면 위 창(1102×777), 입력 영역과 첨부 버튼을 접근성/창 서버로 확인했다(`chat-open-action.json`, `chat-ui-inspection.json`).
4. 설정 창의 계정 탭을 읽기 전용으로 열어 연결 상태를 확인했다. 실제 표시는 **‘서버와 연결이 끊겼어요 · 0초 뒤 다시 연결’**이었고, 해당 PID의 `lsof ... -iTCP -sTCP:ESTABLISHED`는 exit 1로 활성 TCP 연결을 찾지 못했다. 연결 검증은 exit 1이다(`connection-ui-inspection.json`, `connection-observation.json`, `installation-failure.json`). 설정 컨트롤 값은 수정하지 않고 창을 닫았다.
5. 재실행 직후와 연결 실패 확인 시점에 각각 3초 sample을 수집했다. 두 시점 모두 `GateClient.connectLoop → GateKeychain.read → SecItemCopyMatching` 호출이 관측됐다. 연결 전 인증정보 읽기 단계의 대기 정황이다. 잠금·승인·접근 제어 중 세부 원인은 미확정이며, 키체인 승인이나 수정을 시도하지 않았다. 실제 재연결 성공 직후의 sample은 확보하지 못했다.

CPU 원시 관측은 `before-cpu.log`의 100.0%, `after-launch-cpu-*.log`의 0.4%·75.5%, `after-connection-check-cpu-*.log`의 37.6%·40.9%다. 시점과 프로세스 수명이 다른 `ps` 스냅샷이며 AT-HR-06 판정에 사용하지 않았다. sample은 `before-sample.txt`, `after-launch-sample.txt`, `after-connection-check-sample.txt`에 있다. 파일명 정리 내역은 `observation-file-renames.json`에 보존했다.

### 복구 결과와 실행한 명령

로컬 **`restore.py`**를 Hermes venv Python으로 실행해 exit 0이었다(`restore.log`, `restore-command.json`, `restore-commands.json`). 이 명령은 실행 완료했다.

```sh
# 로컬 증거 폴더에서 사용한 복구 명령
"$HEJO_PYTHON" restore.py
```

복구 helper는 원본 백업 해시·서명을 먼저 검증하고 새 앱에 정상 종료만 요청한다. 종료를 확인한 뒤 백업을 복사·서명 검증·원위치 배치·재실행하며, 예상 외 앱 해시나 정상 종료 실패가 있으면 교체하지 않는다. 실제로 복구된 실행 파일의 경로·해시·서명은 원본 및 백업과 같았다(`restored.json`, `restored-running.json`, `restored-signature.log`). 임시 교체용 번들만 해시 확인 후 정리했고 원본 백업·후보 보존본은 남겼다(`temporary-bundle-cleanup.json`).

복구 앱의 상태 창을 자동으로 여는 시도는 AppleEvent 오류(-10000)로 exit 1이었다. 후속 직접 접근성 조회는 exit 0이었지만 연결 상태 텍스트는 노출되지 않았다. 복구 PID의 활성 TCP 조회와 3초 sample은 각각 exit 0이었다(`restored-status-ui-attempt.json`, `restored-ui-inspection.json`, `restored-observation.json`). 원본 앱의 CPU 100.0%도 관측돼 로컬 로그에 남겼다. 복구 앱의 연결 UI 상태는 미확인으로 남긴다.

### 미완료·검토 요청

구현자 판단은 **보류: 설치 후 연결 검증 실패, 원본 복구 완료**다. 새 앱의 인증정보 읽기 대기 원인과 허용 가능한 다음 조치를 계획 담당이 판단해 달라. 이번 권한 밖인 키체인·설정·서버 조작으로 우회하지 않았다. AT-HR-06은 사용자의 관측 대상이며 통과로 적지 않는다. 현재 명세 반영과 푸시도 남았다. 재설치·실제 메시지·인위적 서버 끊기·git push는 추가 실행하지 않았다.

## 16. TASK-HR-04 재설치·연결 확인 인계

### 승인·대상과 결과

2026-11-24 사용자의 **‘지금 재설치’** 승인과 검토 3회차 보완 절차로 재설치했다. V-HR-03의 키체인 확인 창 대기를 실패로 처리하지 않고 사용자 처리를 기다렸다. **로컬 설치·실행·서버 연결 확인 완료**, 이번 시도에서는 복구하지 않았다. AT-HR-06의 재연결 체감은 사용자 관측 대기이며 통과로 적지 않는다.

승인 커밋 `a420b634428bf33dc4c97c081b5693a3de491bfc`, tree `cc446a96975156f20a1a15acafe8a86a3acaf4f3`, dirty=false를 교체 전·종료 시 다시 확인했다. 보존한 정식 후보를 재사용했다. 제품 코드·시험·수락 기준·운영 서버 변경 및 추가 커밋은 없다. 15절의 실패·복구는 첫 시도의 이력이며, 현재 설치 상태는 이 절을 따른다.

### 사전 검증·교체

- 실행 중 원본 PID 93994의 번들 ID·실행 경로와 실행 파일 해시를 확인했다. 기존 작업 백업이 같은 원본이라 새 백업은 만들지 않았다. 원본·백업·후보의 서명 검증이 각각 exit 0이었다.
- 후보의 전체 Info.plist 값은 원본과 같고, BuildInfo는 승인 tree·dirty=false였다. 정식 빌드·배포 기능 보존 근거는 15절을 재사용했다. 후보를 다시 빌드하거나 수정하지 않았다.
- 원본에 정상 종료를 요청해 수락 후 **6.57초**에 종료를 확인했다. 강제 종료는 하지 않았다. 검증한 후보를 배치·서명 재확인한 뒤 직접 번들 경로로 재실행했다.
- 새 PID **13011**의 NSWorkspace 번들 ID·경로와 `ps -o comm=`를 대조했다. 실행 경로는 실제 설치 위치의 `hejo.app/Contents/MacOS/hejo`이며, 그 파일의 SHA256·서명·BuildInfo가 보존 후보와 같았다. 상대 경로 표기는 아래 로컬 증거의 실제 경로 필드를 참조한다.

| 실행 파일 | SHA256 |
|---|---|
| 재설치 전 원본·기존 백업 | `f8733f8ec8b45db54c1709350b40c0ce457f78a391240dac211928bf7c01fa62` |
| 보존 후보·재설치 후 실제 실행 경로의 파일 | `1576290a0e9c54689929ce1c50ad656d651a0d24023f445b338a1628d39fc53d` |

### 키체인 확인 창·연결·화면 확인

시스템 창 서버의 **SecurityAgent 소유 창 존재만** 확인했다. 창 제목·접근성 입력 필드·보안 입력값은 조회하지 않았다. 재실행 직후 시스템 확인 창 1개와 활성 TCP 없음이 관측됐고, 초기 3초 sample에 `GateKeychain.read → SecItemCopyMatching`이 있었다. 확인 창을 닫거나 우회하지 않고 10분 한도 안에서 연결을 주기적으로 확인했다. 대기 중 앱 UI를 조작해 보안 입력의 포커스를 옮기지 않았다.

약 **70초** 뒤 관측에서 시스템 확인 창이 0개가 되고 해당 앱 PID의 활성 TCP 조회가 exit 0으로 바뀌었다. 사용자는 질문 도구에 **‘처리 완료’**라고 답했다. 이 답변과 창 소멸·연결 성립으로 사용자 처리 완료를 확인했다. 암호·토큰은 묻거나 읽거나 입력하지 않았고 키체인 항목을 수정하지 않았다.

확인 창 소멸 뒤 대화 창을 열고 화면 위 1102×777 창·입력 영역·첨부 버튼을 확인했다. 첫 조회는 메뉴 동작 직후 창 전환 중이라 예상 요소가 없어 검증 단언이 exit 1이었다. 같은 앱이 정착한 뒤 재조회로 exit 0을 확인했다. 코드·UI·설정을 고쳐 통과시킨 것이 아니다. 이후 설정 계정 탭을 읽기 전용으로 열어 **‘서버에 연결됨’**을 확인하고 정확히 창 닫기 버튼으로 닫았다. 입력 영역의 값은 읽지 않았다.

연결 확인 뒤 3초 sample과 CPU를 로컬 증거로 남겼다. 이 sample의 `SecItemCopyMatching`은 0건이었다(초기 sample은 2건). CPU 스냅샷은 28.2%·41.8%였으며 프로세스 수명·시점이 다른 단순 관측이다. 연결 성립 순간의 연속 성능 측정이나 개선율·AT-HR-06 합격 근거로 사용하지 않는다. 최종 점검에서도 활성 TCP·대화 창·후보 실행 파일·서명·깨끗한 소스 상태를 확인했다.

### 로컬 증거·실제 명령 결과

새 증거는 저장소 밖 **`reinstall-20261124T124307Z/`**에 보존했다(권한 0700). 경로는 이 폴더 기준이며 실제 루트는 무시된 `.build/reconnect-reinstall-evidence-location.txt`와 역할 인계에만 기록했다. 이전 **`install-20261124T122139Z/candidate-hejo.app`**, **`install-20261124T122139Z/backup/hejo.app`**는 그대로 보존했다. 새 교체 과정에서 생긴 임시 이전 번들만 원본 해시 확인 후 정리했다.

| 명령·검사 | 실제 결과 | 로컬 증거 |
|---|---|---|
| 원본·백업·후보 `codesign --verify --deep --strict` 및 해시·BuildInfo 대조 | exit 0 | `prepared.json`, `preflight-commands.json`, `*-signature.log` |
| Hermes venv Python `install.py` | exit 0, 정상 종료·교체·재실행 | `install.py`, `install-commands.json`, `normal-quit.json`, `launched.json` |
| Hermes venv Python `monitor.py` | exit 0, 10분 안에 연결·시스템 확인 창 소멸 | `monitor.py`, `connection-monitor.jsonl`, `connection-ready.json` |
| `sample <PID> 3 -file ...` 초기·연결 확인 뒤 | 각각 exit 0 | `initial.sample.txt`, `initial-sample-result.json`, `connected.sample.txt`, `running-verified.json` |
| 실제 프로세스 경로·해시·BuildInfo·설치본 서명 | exit 0 | `running-verified.json`, `installed-signature.log` |
| `대화 열기` 메뉴·접근성 조회 | 메뉴 exit 0, 즉시 단언 exit 1 → 정착 뒤 재조회 exit 0 | `chat-open-action.json`, `chat-ui-inspection.json`, `chat-ui-settled.json`, `result.json` |
| 계정 탭 연결 표시 조회·창 닫기 | 각각 exit 0, ‘서버에 연결됨’ | `connection-ui-action.json`, `connection-ui-0.json`, `settings-close-action.json` |
| 최종 Git HEAD·status / 설치본·백업 서명 / TCP / 화면 | 각각 exit 0, 승인 커밋·소스 무변경·연결 유지 | `result.json`의 실제 명령·종료 코드, `final-*.log` |
| 임시 이전 번들 정리 | 원본·백업 해시 대조 후 성공 | `temporary-bundle-cleanup.json` |

### 복구 절차·남은 범위

이번에는 복구하지 않았다. 필요하면 새 로컬 증거 폴더에서 보존한 **`restore.py`**를 Hermes venv로 실행한다.

```sh
# reinstall-20261124T124307Z 폴더에서, 복구가 필요한 경우에만
"$HEJO_PYTHON" restore.py
```

helper는 이전 증거 폴더의 원본 백업을 참조하며 원본 해시·서명을 검증한다. 현재 앱 해시가 예상 대상인지 확인하고 정상 종료가 완료된 뒤에만 백업을 원위치에 복원·서명 검증·재실행한다. 예상 외 변경이나 정상 종료 거부 시 멈춘다. 실행 전 현재 사용자 작업 상태와 복구 지시를 확인한다. 원본 백업은 덮지 않았다.

구현 범위의 재설치는 완료했으므로 계획 담당에 결과 검토를 인계한다. **AT-HR-06 실제 재연결 체감, 현재 명세 반영, 푸시 승인·실행은 남았다.** 운영 게이트웨이·허브·플러그인·설정·키체인·명부·대화 저장소를 변경하거나 재시작하지 않았다. 비밀 파일 열기·실제 메시지 전송·인위적 서버 끊기·git push도 실행하지 않았다.
