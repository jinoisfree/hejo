# HEJO-CARD-DONE TASK-01 구현 인계

## 받은 설계와 판단

[인계서 2판](handoff.md), [설계](design.md), [명세](spec.md), [수락 시험 2판](../../../tests/acceptance/HEJO-CARD-DONE.md)을 대조했다. 일반 위험도, 필요한 증거 수준 2, 교차 모델 연합개발이다.

**보류.** 공개 착수 커밋은 `018036cbf24678ea3a29f826926531e8ab4d370b`다. `git fetch github` 후 추적 ref와 `ls-remote`에서 같은 tip을 확인했다. 호스트에서 쓰기를 허가한 브랜치 `role-workflow/53-17c39527`의 HEAD는 `a1a7d4c601f801c8dd6705aa9e88085d56caf88d`다. 두 커밋에 공통 조상이 없다.

| 확인 지점 | 공개 착수본 | 배정된 구현 브랜치 |
| --- | --- | --- |
| `app/Sources/ConversationController.swift` | 137행에서 영수증을 받고 813–840행에서 기록 모드의 쓰기 시작 뒤 오류를 미확정으로 유지한다. | 632행의 `transmit`은 쓰기 오류를 기존 실패 경로로 보내며 영수증 연결점이 없다. |
| `gate/history_queries.py` | AT-CD-11(a)의 판정 원본이 있다. | 경로가 없다. |
| `app/Tests/HistoryTransportHarness.swift` | AT-CD-09(c)(d)의 기록 모드 시험 경계가 있다. | 경로가 없다. |

REQ-CD-03의 ③과 ④는 공개판에 이미 있는 결과 판정 자리를 연결하는 설계다. 배정 브랜치에서 이 판정을 구현하려면 기록 모드와 영수증 처리까지 들여와야 한다. 배정 경로 한정 지시와 인계서 9절의 공개판 제품 커밋 지시를 충족할 수 있도록 호스트가 공개 착수본을 가리키는 구현 배치를 확정해야 한다. **권고**는 공개 tip 기반 구현 worktree를 별도로 배정하고 계획 문서의 개발 이력을 보존하는 것이다. 개발 worktree를 유지하려면 기록 모드 없는 코드 대상으로 요구사항과 수락 기준을 기획설계부터 다시 확정해야 한다.

## 변경 범위와 남은 작업

- 제품, 추적되는 수락 시험, 브랜치 이력을 변경하지 않았다. 구현·시험 커밋은 없다.
- 지정된 구현 폴더 아래의 `.build/card-done/public-baseline/`에 공개 착수 커밋의 detached 검증본을 두고 기준 시험을 수행했다. 반복용 시험 파일은 `.build/card-done/baseline-fixtures/`에 있다.
- 작업 문서 변경은 이 구현 인계 보고 한 건이다.
- 배치가 확정되면 AT-CD 수락 시험을 등록하고, 앱 ✓와 공용 되돌리기 대기를 구현한 뒤 기준본과 비교한다. 09(c)(d)는 공개 기록 모드의 실제 전송과 수신 경로에서 확인한다. 현재 명세 반영과 공개 푸시 승인 대상은 이후 단계에 남아 있다.
- 기능 동작의 증거 수준 2는 아직 확보하지 못했다. 제품 변경이 없어 mutation check와 화면 PNG도 미실행이다.
- 검토 우선순위는 브랜치 기준과 REQ-CD-03의 기존 연결점이다. 공항 운영, 실제 메시지 전송, 앱 설치, 원격 쓰기는 수행하지 않았다.

## 검증

검증 로그는 배정된 구현 worktree의 `.build/card-done/`에 있다. 표의 실행본은 모두 공개 착수 커밋이다.

| 기준 | 실행 명령 또는 실행기 | 종료·결과 | 로그 |
| --- | --- | --- | --- |
| AT-CD-11(a) | `python -m pytest ../baseline-fixtures/test_history_assessment.py -q -p no:cacheprovider` | 0, 통과. `assess`와 실제 `HistoryQueries.summary`에서 사장 일반 글로 답 요청이 사라지고 직원 최종 답 뒤 완결 | `baseline-at11a.log` |
| AT-CD-11(b) | `bash .build/card-done/compare-bases.sh assessment` | 0, 통과. 앱 소스로 빌드한 `ThreadAssessment.assess`가 해당 순서에서 같은 판정 | `baseline-at11b.log` |
| 묶음 N의 새 진입점 확인 | `bash .build/card-done/compare-bases.sh entry` | 1, 예상대로 기준본에 `ConversationController.completeCard` 없음. 묶음 N 본 시험은 미작성 | `baseline-entry.log` |
| AT-CD-14 개인값 | `python scripts/scan_private.py` (Hermes 실행 Python, 임시 `HERMES_HOME`) | 0, 통과 | `baseline-scan.log` |
| AT-CD-14 기존 앱 시험 | 공개 착수본의 `app/Sources`와 `app/Tests`를 `xcrun swiftc`로 컴파일한 후 `baseline-app-tests --todo-drawer`, `baseline-app-tests --drawer-inline` 실행 | 빌드·두 시험 모두 0. `TodoDrawerTests`의 마감 닫기와 `DrawerHeaderTests` 헤더·필터 통과 | `baseline-drawer-build.log`, `baseline-todo-drawer.log`, `baseline-drawer-inline.log` |
| AT-CD-14 전체 스크립트 | `bash scripts/test.sh` (Hermes Python, 기존 시험 의존성, 시스템 기본 임시 홈) | 1. Python 단계 327 통과·10 실패·257 설정 오류. 게이트 연결 설정 오류와 `psutil` 의존성 누락이 확인됐다. 이후 단계 미실행 | `baseline-suite.log` |
| AT-CD-14 Python 재실행 | `python -m pytest gate/tests tests/acceptance -q --basetemp=<짧은 임시 경로> -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` (기존 시험 모듈 경로 보충) | 1. 592 통과, 2 실패. `test_gate_foundation.py::test_at_hf_08[True]` 모듈 누락, `test_install.py::test_at_hf_27_install_twice_and_check` 영수증 수정 시각 불일치 | `baseline-gate-short.log` |

`baseline.log`에 기준 시험 요약과 예상 컴파일 진단 첫 줄을 남겼다. 브랜치·파일 비교 원본은 `branches.log`다. 묶음 N의 기능 시험과 AT-CD-13/15의 변경본 검증은 미실행 상태다. 약 73 MiB의 로컬 기준 checkout·빌드·로그는 검토를 위해 보존하고, 검토가 끝난 뒤 detached worktree를 등록 해제하고 빌드·로그를 정리할 수 있다.

## 2회 — TASK-01 공개판 구현

- 받은 설계는 승인본 2판이며, [판정 1회](verdict.md)의 배치 보완 지시를 적용했다. 일반 위험도, 교차 모델, 요구 증거 수준 2다.
- 공개 기준 `018036cbf24678ea3a29f826926531e8ab4d370b`를 재확인했다. 공개 구현 checkout은 배정 worktree의 `.build/card-done/public/`, 브랜치는 `hejo-card-done-public-20261126`이다.
- 시험 커밋 `31bbd51b6fed0e86e3aea1a038ce60286cd8cf92`. 제품 커밋 `bd38bc47f3c7b58b3a14c4df3d0b1fd23e2e0b07`. 범위를 해당 공개 브랜치에 한정했다.
- 판정 1회에서 인정한 기준 시험을 재사용했다. 승인된 TASK-01이 실행 중인 동안 호스트에서 보류한 새 계획은 이 변경에 적용하지 않았다.

### 구현 구조

- `TodoDrawerView.swift`와 `ConversationView.swift`에서 44pt 초록 띠와 흰 체크, 띠 누름과 VoiceOver 동작을 컨트롤러의 같은 진입점에 연결했다. 띠가 보일 때는 시간 글자를 빼고 제목·상태 줄을 띠 앞에서 줄인다. 띠 밖 누름은 기존 카드 열기다.
- `ConversationController.swift`에서 마감 전용 대기 자리를 답 요청과 마감이 공유하는 한 자리로 넓혔다. 답 요청은 기존 `sendText → transmit`으로 “확인”을 보낸다. 마감은 기존 `deadline_close`를 사용한다. 결과 알림은 이미 존재하는 `client_msg_id` 접수·실패 자리에 연결했다. 추적 상태는 메모리에만 있고 기존 75초 상한을 공유한다.
- `TodoDrawerModel.swift`는 숨긴 답 요청을 카드와 필터 계수에서 빼고, 하나의 되돌리기 줄에 카드 종류를 전달한다. 실패 경고는 기존 마감 경고 자리에서 표시한다.
- `CardDoneTests.swift`, `card_done_fixture.py`를 앱 시험 입구에 등록했다. 가짜 문은 실제 WebSocket·HTTP로 프레임을 받으며 `send`와 `click` 횟수, 대상 스레드·직원, 마감 순서를 확인한다. 앱 전송 함수는 대체하지 않는다. 쓰기 결과 미확정 시험은 실제 URLSession 쓰기를 가짜 문까지 보내고, 그 한 프레임의 완료 콜백에 연결 손실을 주입한다. 임시 후크는 해당 시험 프로세스에서 원복한다. 핵심 새 경로에 대한 별도 mutation은 기준본의 새 API 부재 검증과 와이어 계약 시험을 수행해 추가하지 않았다.

### 검증과 남은 판단

로그는 배정 worktree의 `.build/card-done/`에 있다. 제품 및 시험 소스는 위 두 공개 커밋과 같다. 실운영 전송, 앱 설치, 푸시는 수행하지 않았다.

| 기준 | 명령·결과 | 로그 |
| --- | --- | --- |
| 착수 묶음 N | 공개 기준 소스와 신규 시험을 함께 `xcrun swiftc -typecheck`. 종료 1. 첫 오류 `TodoDrawerView has no member 'onComplete'` | `baseline-group-n.log` |
| AT-CD-01~10, 03b, 09a~d, 12 | `bash ../build-card-tests.sh`, `python Tests/card_done_fixture.py .build/card-done-tests ../../png`. 각각 0, AppKit·가짜 문 10개 시나리오 통과 | `candidate-card-build.log`, `candidate-card-tests.log` |
| AT-CD-11(a)(b) | `python -m pytest ../baseline-fixtures/test_history_assessment.py -q`, 후보 앱 소스와 기존 `CardDoneAssessment.swift` 컴파일 후 실행. 각각 0 | `candidate-at11a.log`, `candidate-at11b.log` |
| AT-CD-13 | `rg`로 대기 변수·5초 상수·`deadline_close` 생산부 각 한 곳을 확인. `git diff --exit-code github/main HEAD -- gate schemas hub`와 `git diff --check github/main HEAD` 종료 0 | `candidate-at13.log` |
| AT-CD-14 Python | `python -m pytest gate/tests tests/acceptance -q --basetemp=<짧은 임시 경로> -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider`. 종료 1, 592 통과·2 실패. 기준과 같은 `test_at_hf_08[True]`의 `hermes_facility` 모듈 부재와 `test_at_hf_27_install_twice_and_check`의 설치 영수증 수정 시각 불일치 | `candidate-gate.log` |
| AT-CD-14 게이트웨이와 개인값 | `python -m gate.tests.gateway_delivery`, 임시 `HERMES_HOME`에서 `python scripts/scan_private.py`. 각각 0 | `candidate-gateway.log`, `candidate-scan.log` |
| AT-CD-15 | 밝은·어두운 답 요청/마감 카드를 각각 저장하고 직접 확인했다. 네 그림의 오른쪽 초록 띠와 흰 ✓, 제목·상태 글과 띠 사이 여백을 확인했다. | `png/question-light.png`, `png/question-dark.png`, `png/deadline-light.png`, `png/deadline-dark.png` |

**검토 쟁점 AT-CD-09c.** 실제 가짜 문으로 접속·쓰기를 하면서 미확정 결과를 만들고, 재연결 `welcome`도 WebSocket으로 받았다. 그 뒤 `sync_done`은 수락 시험에서 허용한 `controller.receive` 경계에 넣어 카드·경고 복구를 확인했다. 공개 착수 코드의 `GateClient.receive`는 기록 모드에서 `sync_done`을 허용하지 않고, 공개 문도 기록 모드 재연결 때 이 프레임을 발행하지 않는다. 그래서 기록 모드의 실제 WebSocket 재연결이 이 분기를 밟게 하는 것까지는 입증할 수 없다. 기록 모드에서 `not_found`를 실패로 바꾸지 않는 나머지 계약도 그대로 적용된다. 기획설계에서 이 수신 경계 검증으로 충분한지, 실운영에서 새 재연결 실패 판정이 필요한지 판단해야 한다.

### AT-CD-14 앱 회귀 추가 기록

| 명령 | 종료·실제 결과 | 로그 |
| --- | --- | --- |
| `bash app/scripts/test.sh` | 1. 앱·시험 빌드와 서명, AppKit 전체, `TodoDrawerTests`·`DrawerHeaderTests`, WebSocket·HTTP fixture(신규 카드 포함), hooks 통과. 기본 임시 경로에서 프로필 게이트를 열지 못해 그 단계가 실패했고, 종료 시 실제 설정 메타데이터 가드가 불일치를 보고했다. 다운로드 메타데이터 검사는 통과 | `candidate-app-full.log` |
| `bash app/Tests/OwnerProfileTransport.sh` (짧은 임시 경로) | 0. 프로필 관련 4건 통과 | `candidate-owner-short.log` |
| `python ../replay-app-runtime.py` (임시 HOME 및 짧은 경로, 기존 빌드 재사용) | 1. AppKit 전체 통과, 설정·다운로드 가드 통과. 키체인 연결 시험이 격리 환경의 자격 저장 단계에서 중단됐다. 같은 시험은 기본 환경 실행에서 통과했다. | `candidate-app-isolated.log` |
| `python ../replay-app-runtime.py tail` (같은 격리 환경) | 0. 기존 스크립트의 프로필 이후 명령 그대로 실행. 프로필 4건, 대기 지터와 추적 켜짐·꺼짐 비교, 설정·다운로드 가드 통과 | `candidate-app-tail.log` |

앱 검증은 단계별 통과 근거를 확보했다. 전체 앱 스크립트를 단일 환경에서 연속 통과한 증거는 없다. 런타임 재실행 스크립트는 `.build/card-done/replay-app-runtime.py`에 있고 임시 폴더는 종료 시 정리한다. 검증 역할은 AT-CD-09c의 기록 모드 계약과 앱 회귀 환경 분리를 함께 확인한다.

## 3회 — TASK-03 알림 ✓와 직접 선택 회귀

- 받은 설계는 명세 3판 D-06·D-07, REQ-CD-06·07과 인계서 9절 6항이다. 일반 위험도, 교차 모델, 요구 및 도달 증거 수준 2다.
- 공개 checkout은 배정 worktree의 `.build/card-done/public/`, 브랜치는 `hejo-card-done-public-20261126`이다. 공개 기준 `018036cbf24678ea3a29f826926531e8ab4d370b`, TASK-01 제품 `bd38bc47f3c7b58b3a14c4df3d0b1fd23e2e0b07` 위에 시험 `2a467a2441a39d24a99a3db877c27f4080c0683e`, 제품 `2172446addadc9a34a592ac8d30c6203f6acb0a3`을 각각 커밋했다.

### 구조와 직접 선택 판정

- `ConversationController.swift`는 대화 키가 있는 알림에 기존 ✓ 동작을 열고, 누르면 선택·전송·대기열 갱신 없이 기존 `markNoticeRead`로 전달한다. `TodoDrawerView.swift`가 이 동작의 VoiceOver 이름을 “읽음으로 표시”로 표시한다.
- `HistoryCoordinator.swift`의 기존 `notice` 읽음 작업에 진행 중인 동일 키를 합치는 처리를 추가했다. 이 상태는 실제 읽음 계획과 같은 실행 수명에만 있다. 실패하면 카드와 회원 상태가 유지되어 다시 시도할 수 있다.
- AT-CD-18을 먼저 실행했다. 자동 선택 대상 재클릭, 열린 스레드에 새 알림, 홈·직원·단체방, 갱신 중을 카드 클릭·채팅 카드 클릭 핸들러·화살표+Enter에 걸어 각 커밋 18개 조합을 돌렸다. 두 기준 모두 통과했다. 자동 선택 순간의 `notice` 요청은 0건이었다. 직접 선택·자동 선택 진입점은 수정하지 않았다(REQ-CD-07.AC-03).
- `CardAlertHarness.swift` 및 `test_card_alert_transport.py`는 기존 격리 문과 관측용 회원 상태 대역을 쓴다. `CardDoneTests.swift`의 띠가 없는 알림 예는 새 명세에 맞춰 키 없는 카드로 유지하고, 키 있는 알림은 AT-CD-16에서 따로 확인한다. `TestMain.swift`·`app/scripts/test.sh`가 정규 시험에 등록한다.
- 3판 수락 시험의 기존 AT-CD-01/12 문구에 키 있는 알림 띠가 없다는 2판 표현이 남아 있다. 구현의 기대값은 새 REQ-CD-01.AC-01(c), REQ-CD-06과 AT-CD-16을 적용했다. 원본 명세의 문구 정리는 기획설계 범위다.

### 자체 검증

아래 로그와 PNG는 배정 worktree의 `.build/card-done/` 기준이다.

| 기준 | 명령·실제 결과 | 로그 |
| --- | --- | --- |
| AT-CD-18 두 기준 | 각 커밋의 앱 소스를 같은 AT-CD-18 하네스와 컴파일한 뒤 `python -m pytest app/Tests/test_card_alert_transport.py` 실행. 각 종료 0, 18개 통과. 보고된 결함은 재현되지 않았다. | `at18-baseline.log` |
| AT-CD-16~18 후보 | `bash ../build-alert.sh public alert-final`, `python -m pytest app/Tests/test_card_alert_transport.py -q -s`. 각각 종료 0, 21개 통과. 읽음 성공·진행 중 재누름·기존 되돌리기 보존·실패 후 VoiceOver 재시도·직접 선택 조합, 대상 및 `bell:`·`thread:` 값 확인. 직원 글 전송과 대화 이동 0건 | `task03-alert-build.log`, `task03-alert.log` |
| AT-CD-11(a) | `python -m pytest ../baseline-fixtures/test_history_assessment.py -q`, 종료 0 | `task03-at11a.log` |
| AT-CD-13 | 대기 변수·5초 상수·`deadline_close` 생산부 각각 한 곳 확인. `git diff --exit-code github/main HEAD -- gate schemas hub`, `git diff --check github/main HEAD` 각각 종료 0 | `task03-at13.log` |
| AT-CD-14 Python·개인값 | `python -m pytest gate/tests tests/acceptance -q` 종료 1, 592통과·2실패로 기준 실패 목록과 같음. 임시 홈에서 `python scripts/scan_private.py` 종료 0 | `task03-gate.log`, `task03-scan.log` |
| AT-CD-15 알림 PNG | 밝은·어두운 268×52 카드에서 제목과 초록 ✓ 띠가 겹치지 않음을 직접 확인 | `task03-alert-png/alert-light.png`, `task03-alert-png/alert-dark.png` |
| AT-CD-11(b) | 후보 앱 소스와 기존 `CardDoneAssessment.swift`를 컴파일해 실행, 종료 0 | `task03-at11b.log` |
| 중복 방지 변이 비교 | `bash ../run-alert-mutation.sh enabled/disabled`로 실패 뒤 사용자 재시도 전 기록 갱신을 수행. 제품 소스는 종료 0, 중복 방지 제거본은 종료 1(기대한 실패, `notice`가 하나 더 관측됨). 성공 응답 사례 단독에서는 기존 세대 무효화만으로도 중복이 폐기되어 변이가 통과했다. 변이 소스와 추가 탐침은 무시되는 증거 폴더에만 생성했다. | `task03-refresh-enabled.log`, `task03-refresh-disabled.log`, `task03-mutation.log` |
| AT-CD-14 착수 앱 전체 | `python run-app-comparison.py public-baseline`에서 `bash app/scripts/test.sh`, 종료 0. 빌드·서명, AppKit, 네트워크 fixture, 프로필 4건, 대기 지터, 설정·다운로드 가드 모두 통과 | `task03-app-baseline.log` |

앱 전체 비교는 같은 호스트·로그인 홈·Hermes 시험 Python 및 의존성, 같은 Sparkle, 동일한 짧은 임시 경로 구성으로 실행했다. 설치 앱은 두 실행 중 켜져 있었고 종료·재시작하지 않았다. 실제 설정은 가드에서 메타데이터만 비교한다. 실행 중 설치 앱은 2회 보고에서 메타데이터 불일치의 가능한 외부 요인이며 원인 판정은 확인되지 않았다. `task03-installed-process.log`에 설치 앱 관측을 남겼다.

### 최종 후보 비교 결과

`python run-app-comparison.py public`의 `bash app/scripts/test.sh`는 종료 0이다. 일반 앱·시험 빌드와 서명, AppKit 전체, 기존 마감·서랍 헤더, TASK-01 카드 10개, TASK-03 알림·직접 선택 21개, 프로필 및 대기 지터, 두 메타데이터 가드를 통과했다. 착수 앱 전체도 종료 0이며, 비교한 앱 단계에서 새 실패는 없다. 후보 로그는 `task03-app-candidate.log`다. 두 Python 실패 이름은 착수 목록과 같다.

TASK-03 구현·자체 시험 완료로 넘긴다. 최종 교차 검토, TASK-02 문서 반영과 푸시 승인 단계가 남았다. 사용자 보고 결함은 AT-CD-18의 지정 조건에서 관측되지 않았다. 실제 운영 문·직원 전송, 설치 앱 교체, 원격 쓰기는 수행하지 않았다.
