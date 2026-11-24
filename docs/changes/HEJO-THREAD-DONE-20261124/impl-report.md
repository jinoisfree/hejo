# 구현 인계: HEJO-THREAD-DONE-20261124 / TASK-01

## 받은 설계와 판단

- [확인] [handoff.md](handoff.md), [spec.md](spec.md) 2판의 REQ-TD-01·02 / AC-01~07을 구현했다. 기준 커밋은 `236b0177468b90d9ea23a1b1190e996db78a0694`, 연합개발, 위험도 일반, 필요한 증거 수준 3이다.
- 구현자 판단: 제품 구현과 범위 시험 완료. 전체 검사 통과로 판정하지 않는다. 최종 검토·현재 명세 반영·푸시는 계획 담당에게 남는다.
- 설계 변경 없음. 시험 가능한 카드 색 helper를 만들지 않고 실제 `ConversationView`가 조립한 `NativeThreadCard.Content.style.status`를 관측했다.

## 바꾼 곳과 이유

| 파일 | 변경 |
|---|---|
| `app/Sources/ThreadTools.swift` | `ThreadAssessment.assess`의 finished에서 승인 단어 조건을 없애고 사장 답 뒤 non-streaming 직원 글 존재를 검사한다. 기존 생각 중 제외, approved, closed, answered, answer_to, 버튼 판정은 유지한다. |
| `app/Sources/ConversationView.swift` | 기존 tone 계산에서 제목 표시 색 대체를 `state.request == nil`로 제한한다. 기존 판정 색·질문 대기 `AttentionRail.color`·작업 중 노랑 우선순위를 유지한다. |
| `app/Tests/ThreadDoneTests.swift` | spec의 AT-TD-01~06을 임시 LocalStore와 가짜 명부로 코드화한다. 실제 모델·종·알림/질문 목록·카드 상태 색을 실행한다. |
| `app/Tests/ReadNoticeTests.swift` | 기존 readNotice 실행 경로에서 새 시험을 호출한다. 기존 AT87 기대값은 바꾸지 않았다. |
| `app/Tests/TestMain.swift` | `--thread-done`에 새 시험을 포함한 readNotice, 기존 ThreadTools·typing 시험을 연결한다. 기본 전체 시험의 기대값·목록은 유지한다. |

책임은 앱 관제 화면의 기존 파생 판정과 카드 조립에 그대로 있다. gate·기록장 형식·Hermes 본체·ddots·운영 설정·다른 작업의 변경은 수정하지 않았다. 새 원본·저장 필드·임시 제품 경로·wrapper는 없다. 변경 성격은 설계가 승인한 의미 변경이다.

## 시험 계약과 결함 검출

| 시험 | 보호하는 계약 |
|---|---|
| AT-TD-01 | 비승인 자유 답 뒤 완성 직원 글은 settled/초록, 종 없음, 알림/질문 제외이며 🔴 제목에도 카드 초록이다. |
| AT-TD-02 | 완결 뒤 새 요청은 그 요청을 pending으로 다시 빨강이다. |
| AT-TD-03(a)(b) | streaming 글만 또는 생각 중 글만 있으면 미완결이며 실제 작업 중 카드가 노랑이다. |
| AT-TD-04 | answer_to=A 뒤 직원 글이 있어도 요청 B가 답을 못 받았으면 B 대기/빨강이다. |
| AT-TD-05 | 요청에 자유 답만 있으면 카드 색 없음, 작업 중일 때는 노랑이다. |
| AT-TD-06 | 요청 없는 보고의 🔴/✅ 제목 색은 유지하고 작업 중이면 노랑이 우선한다. |
| AT-TD-07 | 기존 readNotice / ThreadTools / typing 시험을 기대값 변경 없이 실행했다. |

[확인] mutation은 제품 파일을 바꾸지 않고 무시되는 빌드 폴더의 복사본을 컴파일했다. (1) 기준 버전의 완결 판정·tone은 AT-TD-01에서 종료 1, (2) streaming 제외 삭제는 AT-TD-03a에서 종료 1, (3) 제목 색 제한 삭제는 AT-TD-05에서 종료 1이었다. 변형별 컴파일은 모두 종료 0이다. 최종 복사본은 원본 제품 파일 2개와 `cmp` 일치(종료 0)를 확인했다. 삭제·완화·합친 기존 시험은 없다.

## 실행 환경과 검증 근거

모든 아래 상대 로그 경로는 **구현 worktree 기준**이다. 실행한 개인 로컬 절대 경로를 공개 문서에 넣지 않기 위해 실행 파일 위치를 `HERMES_PYTHON`(Hermes 본체의 venv/bin/python), `HERMES_SOURCE`(본체 소스), `LOCAL_TEST_PYTHON`(구현 worktree의 `.build/thread-done-venv/bin/python`)으로 표기한다. 원래 실행 argv와 전체 출력은 해당 로컬 로그·상태 파일을 참조한다. 테스트의 `HERMES_HOME`은 임시 폴더다.

| 명령 / 대상 | 실제 결과 | 로그 |
|---|---|---|
| `HEJO_SKIP_GOOGLE_SECRET=1 bash app/scripts/build.sh` | 종료 0, BUILD_OK / 서명 검증 통과. 기존 Swift 동시성 경고는 수정 범위 밖이다. | `.build/thread-done-logs/build.log` |
| `bash .build/thread-done-mutation.sh final` | 종료 0, 최종 제품 코드와 전체 시험 컴파일·서명 | `.build/thread-done-logs/final-tests-build.log`, `mutation-final-compile.log` |
| `HERMES_HOME=<임시> app/.build/app-tests-final --thread-done <빌드앱 Pet 리소스>` | 종료 0: AT_TD_01_06_PASS, AT-HF-87 APP PASS, THREAD_TOOLS_UNIT_PASS, AT-HF-57 PASS, TYPING_AUTOMATIC_CAPTURES_OK, APP_TEST_OK | `.build/thread-done-logs/targeted-thread-done-final.log` |
| `HERMES_HOME=<임시> LOCAL_TEST_PYTHON app/Tests/thread_fixture.py app/.build/app-tests-final` | 종료 0: THREAD_NETWORK_PASS, APP_TEST_OK, THREAD_CONTROL_FIXTURE_PASS. AT75/76·관련 AT87의 루프백 대역 통합 시험이며 증거 수준 2로 구분한다. | `.build/thread-done-logs/thread-fixture-final.log` |
| `HERMES_HOME=<임시> LOCAL_TEST_PYTHON app/Tests/bubble_reply_fixture.py app/.build/app-tests-final` | 종료 0: AT-HF-82 BUBBLE NETWORK PASS, APP_TEST_OK, BUBBLE_REPLY_FIXTURE_PASS. 기존 AT87 읽음 회귀도 포함하는 루프백 대역 통합(수준 2)이다. | `.build/thread-done-logs/bubble-fixture-final.log` |
| `HEJO_PYTHON=HERMES_PYTHON bash app/scripts/test.sh` | 종료 143. 빌드·시험 컴파일·서명은 통과했지만 전체 앱 실행이 기존 island 시험에서 장시간 실행되어 SIGTERM으로 중단했다. 실패 assertion을 관측한 것은 아니다. | `.build/thread-done-logs/app-test.log`, `app-test-sample.log` |
| 기준 제품 코드 + 새 시험, 전체 앱 실행(45초 제한) | 자식 종료 -15 / timeout=true. 기존 island 시험 구간에서 45초 내 미완료. 같은 위치의 동일 무한 루프라고 단정하지 않는다. | `.build/thread-done-logs/app-test-baseline-run.log`, `app-test-baseline-status.log`, `app-test-baseline-sample.log` |
| 최종 `app/.build/app-tests-final <빌드앱 Pet 리소스>` 전체 실행(180초 상한) | 종료 1, timeout=false. 기존 `AT-UC-32 four word-only judgment buttons without image` assertion 실패. 앞선 중단을 무한 루프 증거로 취급하지 않는다. | `.build/thread-done-logs/app-unit-final.log`, `app-unit-final-status.json` |
| 기준 제품 코드 `app/.build/app-tests-baseline --ui-clean-polish <빌드앱 Pet 리소스>` | 종료 0. AT-UC-32는 단독 실행에서 재현되지 않아 전체 시험 순서에서의 기준 재현을 별도 진행했다. | `.build/thread-done-logs/app-uc32-baseline.log` |
| 기준 제품 코드 `app/.build/app-tests-baseline <빌드앱 Pet 리소스>` 전체 순서 실행 | 종료 1: 최종 코드와 동일한 `AT-UC-32 four word-only judgment buttons without image` assertion으로 실패. 이 작업 이전 제품 코드에서도 전체 순서에서 재현됨을 확인했다. | `.build/thread-done-logs/app-unit-baseline-final.log` |
| `PYTHONPATH=HERMES_SOURCE PYTEST_ADDOPTS=--basetemp=/tmp/hejo-td-final HEJO_PYTHON=LOCAL_TEST_PYTHON bash scripts/test.sh` | 종료 1: 420 passed, 7 failed, 1 warning. pytest에서 멈춰 이 실행에서는 gateway_delivery와 앱 단계 미진입. | `.build/thread-done-logs/full-test-final.log` |
| 위 실패 7개 nodeid를 기준 커밋 archive에서 동일 최종 Python 환경으로 재실행 | 종료 1: 동일 7개 모두 재현. psutil·hermes_facility 등 외부 환경 의존성/설치 시험 실패이며 이 작업은 gate/·install/을 바꾸지 않았다. | `.build/thread-done-logs/baseline-failed-tests.log`, `baseline-failed-tests-command.json`, `baseline-failed-tests-status.json` |
| `HERMES_PYTHON scripts/scan_private.py` | 종료 1: 기존 문서 mockup의 roster 탐지 30건. 최종 변경 파일에서 신규 탐지 없음. | `.build/thread-done-logs/scan-private-final.log` |
| 기준 archive에서 `HERMES_PYTHON scripts/scan_private.py --repo <기준 archive>` | 종료 1, 같은 30건. 최종과 지적 행·fingerprint 모두 동일 | `.build/thread-done-logs/scan-private-baseline.log`, `scan-private-final-comparison.log` |
| `git diff --check` | 종료 0 | `.build/thread-done-logs/diff-check.log` |

앞선 환경 준비 실행도 숨기지 않는다: Hermes Python의 pytest 부재로 `bash scripts/test.sh`는 종료 1(`full-test.log`, 기준 archive도 `full-test-baseline-missing-pytest.log`에서 종료 1), 로컬 시험 venv에서 Hermes 소스 경로 없이 pytest 수집은 종료 2(`pytest.log`), 긴 pytest 임시 경로의 Unix 소켓 문제를 포함한 실행은 종료 1(`pytest-hermes-path.log`)이었다. 단일 Gate 시험은 짧은 basetemp에서 종료 0(`pytest-short-path-probe.log`)으로 확인했다. 의존성을 보강하던 중의 전체 실행은 407 passed/20 failed, 종료 1(`full-test-configured.log`), 기준 archive 실행은 412 passed/15 failed, 종료 1(`full-test-configured-baseline.log`)이었다. 이 두 실행은 동일 환경 비교 근거로 쓰지 않고, 최종 환경에서 위 실패 7개의 기준 재현을 따로 확인했다. 로컬 시험 의존성은 무시되는 `.build/thread-done-venv`에만 설치했다. 패키지 목록은 `python-packages.txt`, 설치 로그는 `test-dependencies*.log`다. 본체 venv는 수정하지 않았다.

## 미검증·남은 일과 검토 요청

- [확인] 필요한 수준 3에 대해 실제 앱 모델과 AppKit 카드 조립을 실행한 범위 증거 수준 3을 확보했다. 독립 검토나 실제 운영 스레드 화면의 관측 증거는 아니다.
- [미실행] 운영 앱 설치·문 재시작·실제 메시지 송신·실제 제보 스레드 확인·푸시. 제품 변경의 롤백은 해당 커밋 되돌리기다.
- 전체 앱 시험의 AT-UC-32 실패와 전체 Gate/설치 시험 의존성, 기존 개인값 30건은 범위 밖 잔여 문제다. AT-UC-32는 단독 기준 실행은 통과하지만 전체 순서에서는 기준 제품 코드도 동일 assertion으로 실패한다. 실패를 skip하거나 scanner allow를 추가하지 않았다.
- 검토자는 승인 단어 없이 settled가 되는 의미 변경, streaming/생각 중 경계, answer_to 회귀, 실제 카드 색의 단일 계산 경로를 특히 확인한다. 기존 테스트 기대값이 그대로인지와 전체 검사 미통과의 처분을 검토한다.
- 최종 검토·verdict·현재 명세 반영 및 푸시 승인 요청은 계획 담당이 한다. 커밋만으로 최종 완료를 선언하지 않는다.

## 검토 대상

- 브랜치: `role-workflow/34-09c749f7`
- 작업 ID에 배정된 구현 worktree의 제품·시험 5개 파일. 실제 경로는 호스트 인계 상태에 기록한다.
- 커밋: `f1cb67d3dfbd74f7479566db5b6cb5c6da53b065` (`git commit --only`로 위 5개 파일만 커밋). 커밋 뒤 작업 트리 깨끗함과 시험 대상 파일 내용 일치를 확인했다(`commit-content-check.log`, 종료 0).
- 명령·종료 코드·대상 커밋·로그의 요약은 구현 worktree의 `.build/thread-done-logs/verification.json`에도 남겼다. 이 보고서는 지시대로 계획 담당 작업 문서 폴더에 작성했으며 위 제품·시험 커밋에 포함되지 않는다.
