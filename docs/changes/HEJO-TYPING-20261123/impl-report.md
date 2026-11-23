# 구현 인계 — HEJO-TYPING v3

## 현재 결과

[확인] TASK-00B 기준 통합과 계측 보완, TASK-01 입력 국소 갱신을 구현했다. TASK-02 자동 검증은 아래 범위에서 수행했다. **최종 완료 판정은 보류**: 실제 한국어 입력기 관측은 미실행이고 전체 시험에는 기준에서도 재현되는 설치 시험 실패 1건이 남는다. 설치 앱 교체·운영 변경·푸시는 하지 않았다.

받은 설계는 [handoff v3](handoff.md), 요구와 예산은 [spec](spec.md), 검토 지적은 [호스트 판정 원본](../26405dfc-f5c9-4243-ab07-fa756b3c00bb/verdict.md)이다. 일반 위험도, 연합개발, 필요한 증거 수준 1/2/3. 실제 도달은 빌드와 가짜 데이터의 실제 AppKit 실행이며 OS 한국어 입력기의 수준 3 증거는 확보하지 않았다.

## 변경본과 책임

배정 브랜치 `role-workflow/26-26405dfc`에만 커밋했다.

1. `03fc1999bb9f3d9549355e70ad63930b2c7a5f02`: 고정 성능 개발 커밋의 merge. 부모는 `6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0`와 `221e84082a4230caca6b450cb3b2e0ee9d085ee8`. 충돌 없음. 기존 근간/텔레그램/UI 문서와 동결 시험 계보를 보존했다. 공개 snapshot이나 이동하는 브랜치 tip은 통합하지 않았다. 입력 수정 전 제품 기준이다.
2. `e0ac632a4dd279dfd2da0b1a1c3e6d65662b9671`: 계측 하네스와 timeout 관리 시험. 입력 전용/수신 병행 × 홈/직접방/단체방, 단계 로그와 실제 자식 종료 코드 수집을 추가했다.
3. **검토 대상 `e63085d84d66caea2cf19fd2f9421231f6bdbcc3`**: 입력 국소 갱신과 편집/연결된 버튼 시험. 최종 제품 소스는 성능 계측 binary의 소스 해시와 모두 일치한다. 연결된 버튼 시험 호출 추가는 별도 앱 전체 시험에서 검증했다. 작업 트리는 깨끗하며 확인 시점 main을 포함한다.

제품 변경은 `app/Sources/ConversationView.swift` 한 파일이다. textDidChange의 홈 전체 refresh 호출과 별도의 raw 본문 전송 버튼 계산을 제거했다. 기존 전체 refresh와 입력 이벤트가 `refreshInputPresentation`을 공유해 받는 사람 강조, 명시 선택, 힌트/접근성 설명, 전송 버튼을 같은 조건으로 갱신한다. 입력 경로는 초안을 저장하고 서식/높이/자동완성을 유지하며 textStorage 복원이나 undo 초기화를 호출하지 않는다. 모델·방 전환·수신은 기존 전체 refresh를 유지한다.

변경 성격: 불필요한 화면 부작용 제거 및 승인된 공백 초안 버튼 불일치 수정. 전송·초안 저장소·통신·영구 형식의 변경은 없다. 새 캐시/두 번째 원본/제품 시험 전용 분기는 추가하지 않았다. 롤백은 입력 수정 커밋의 diff를 되돌리는 것으로 가능하며 데이터 이관은 없다.

## 시험 변경

- `HejoPerfTests.swift`: 기존 fixture와 View 조립을 재사용. 단계별 시각, fixture 진행, 최초 refresh/layout, 입력 제출/시작/완료를 로그로 남긴다. 단체방은 동일 8×100×4 메시지에 가짜 room 메타데이터를 부여한다. 원래 HP 동결 기대값/입력 파일/예산은 변경하지 않았다.
- `HejoTypingTests.swift`: 문자 추가, 한글 문자열 삽입, 범위 교체, 삭제, 여러 줄 입력, 전체 지우기를 실제 NSTextView로 실행. 입력에 따른 full refresh 횟수와 초안 일치를 검사하고 raw 큐/처리/합계 시간 및 회차별 자료를 즉시 저장한다. 수정 전 홈은 각 이벤트 refresh 1회, 직접방/단체방은 0회로 관측하며 수정 후는 모두 0회를 요구한다.
- 편집 회귀: 실제 NSTextView의 커서/선택, undo/redo, 합성 marked text 수정·확정, attributed text 삽입, 홈 멘션과 명시 수신자 우선순위/해제. OS 키보드/입력기와 실제 클립보드 메뉴 동작의 대체 완료로 보지 않는다.
- `ComposerTargetTests.swift`: 기존 로컬 WebSocket fixture에서 연결·선택이 있는 상태의 빈 본문/공백/줄바꿈/본문 × 첨부 유무 버튼 값을 입력 직후와 전체 refresh 후 비교한다. 다른 연결 상태·선택 없음의 모든 교차 조합을 이 신규 시험 하나로 검증했다고 주장하지 않는다. 기존 Composer/대상/방 회귀도 앱 전체 시험에 포함된다.
- `hejo_perf.py`, `test_hejo_perf_runner.py`: timeout 시 terminate→필요시 kill→wait로 자식을 회수하고 실제 종료 코드, timeout, 마지막 단계와 표본 수를 기록한다. timeout 또는 비정상 종료는 관리 프로세스 실패로 전파한다. 성공/exit 7/timeout 3개 단위 시험 통과. baseline 조건이 제거 전 홈 호출을 실제 검출한 것을 회귀 검출 근거로 삼고 별도 mutation 코드는 추가하지 않았다.

## 전후 성능

[확인] 최적화 Swift 5 / arm64 macOS 13 target, 실행 OS macOS 27.2, 동일 840×760 AppKit 창, 기존 고정 시각/순서/3,200개 메시지. 조건별 warm-up 1회 + 측정 5회, 회당 동일 6동작(측정 이벤트 30개). before/after workload-frames.json은 조건별 바이트 일치한다. 수신 병행은 가짜 edit를 입력 앞에 넣는다. 실제 소켓 빈도나 OS 키보드 지연의 측정은 아니다.

단위 ms, 표 안은 중앙값 / 최대값이다.

| 조건 | 수정 전 입력 처리 | 수정 후 입력 처리 | 수정 후 제출→완료 |
|---|---:|---:|---:|
| home | 109.95 / 113.68 | 1.12 / 1.26 | 1.21 / 19.09 |
| direct | 0.17 / 0.29 | 1.17 / 1.36 | 1.31 / 18.37 |
| group | 0.16 / 0.37 | 1.13 / 1.36 | 1.22 / 18.08 |
| home-receive | 111.63 / 115.20 | 1.28 / 1.53 | 126.63 / 139.63 |
| direct-receive | 0.26 / 1.10 | 1.26 / 1.62 | 125.10 / 136.52 |
| group-receive | 0.28 / 0.40 | 1.32 / 2.33 | 138.30 / 189.45 |

홈의 측정 이벤트 전체 갱신은 30→0회, 직접방/단체방은 0→0회다. 여섯 조건 모두 큐/처리/합계 예산 중앙값 ≤250ms, 최대 ≤500ms를 만족했다. 입력 전용 홈의 처리 중앙값은 약 110ms에서 1.12ms로 줄었다. 성능 통합 전 TASK-00 timeout을 지연 수치나 성공으로 재해석하지 않았다.

## 실행 검사와 증거

아래 경로는 **구현 worktree 기준**이다. 로컬 절대 경로와 전체 명령 환경은 추적하지 않는 증거에 보존했다.

| 실행 | 실제 결과 | 증거 |
|---|---|---|
| `python3 app/Tests/hejo_perf.py home --evidence .build/hejo-perf-evidence/typing-baseline` (Sparkle 캐시 환경 지정) | 종료 0, 통합 기준 기존 홈 계측 완결 | 해당 폴더 runner.log, build.json, home/execution.json·performance.json |
| `hejo_perf.py typing-* --expect-baseline --evidence .../typing-before-r2` (첫 실행 빌드, 나머지 --no-build) | 여섯 조건 각 종료 0, before 원시 표본 보존 | `.build/hejo-perf-evidence/typing-before-r2/` |
| `hejo_perf.py typing-* --evidence .../typing-after` (첫 실행 빌드, 나머지 --no-build) | 여섯 조건 각 종료 0, 입력/편집 검사 통과 | `.build/hejo-perf-evidence/typing-after/` |
| `hejo_perf.py check --no-build --evidence .../typing-after` | 종료 0, 58단계 동결 의미 결과 일치 | typing-after/check/ |
| `hejo_perf.py regression ...` (원본 Resources/Pet 지정) | 종료 1: HP View 회귀는 통과, 변환 전 sprite 리소스 없음 | typing-after/regression/run.log·execution.json. 이후 정식 앱 전체 시험에서 해당 HP와 화면 회귀 통과 |
| `bash app/scripts/test.sh` (격리 홈/기존 검증 Python/Sparkle 환경) | **종료 0**. 서명 앱 빌드, 앱 전체 시험, 가짜 WebSocket fixture 포함. 연결된 버튼 검사 통과 | `.build/typing-verification/app.json`, app.log |
| `bash scripts/test.sh` (짧은 pytest basetemp) | **종료 1: 426 passed, 1 failed**. AT-HF-27 설치 영수증 mtime 동일성. 다음 단계는 스크립트 특성상 실행 안 됨 | `.build/typing-verification/all-r3.json`, all-r3.log |
| 수정 전 `03fc1999`의 install/gate/schema/수락시험을 추출해 AT-HF-27만 같은 환경 실행 | **종료 1, 동일 receipt mtime 실패 재현**. 설치 코드는 이번 범위 밖으로 유지 | `.build/typing-verification/baseline-install.json`, baseline-install.log, baseline-source.json |
| 검증 Python `-m gate.tests.gateway_delivery` | 종료 0, 종료된 전체 스크립트의 후속 단계를 독립 확인 | `.build/typing-verification/gateway.json`, gateway.log |
| 검증 Python `scripts/scan_private.py` (임시 홈/가짜 빈 명부) | 종료 0. 운영 명부/금고를 읽지 않음 | `.build/typing-verification/scan.json`, scan.log |
| `python3 app/Tests/test_hejo_perf_runner.py` | 종료 0, 3 tests OK | `.build/typing-verification/runner.json`, runner.log |
| git status/diff-check/동결 fixture diff/main ancestor 검사 | 각 종료 0, 깨끗한 worktree, 동결 fixture 불변 | `.build/typing-verification/final-evidence.json` |

초기 환경 실패도 보존했다. `all.log`와 `all-r2.log`는 pytest가 만든 긴 임시 홈으로 Unix post.sock bind가 실패했고, trace-connect.log에 `OSError AF_UNIX path too long`이 있다. HERMES_HOME만 짧게 해서는 pytest tmp_path가 바뀌지 않아 재실패했다. PYTEST_ADDOPTS의 짧은 basetemp로 대상 연결 시험이 통과(trace-connect-short.json, 종료 0)한 뒤 전체를 재실행했다. 앱 로그의 INSTANCE_LOCK_REJECTED_EXPECTED는 예상된 하위 시험 출력이며 앱 전체 실패가 아니다.

새 시험 최초 컴파일은 기존 TypingTests.swift 이름 충돌로 실패했다(typing-before/compile.log, 관리 프로세스 종료 1). 기존 파일을 HEAD와 동일하게 복원하고 HejoTypingTests.swift로 분리한 뒤 통과했다. 두 파일을 대체하거나 기존 시험을 제거하지 않았다.

전후 집계 원본은 `.build/typing-verification/comparison.json`, 최종 커밋과 측정 제품 해시/동일 workload 확인은 final-evidence.json. 이전 TASK-00 보고는 `.build/typing-verification/task00-impl-report.md`, 당시 원시 증거는 `.build/typing-task00/`에 그대로 있다.

## 지적 처분과 남은 작업

- V-HT-01: 지정 개발 커밋 통합 및 기준 고정 구현 완료. 현재 문서 보존/부모 확인 근거를 검토 요청한다.
- V-HT-02: 단계/종료 관측 보완, timeout 관리 단위 시험, 완결 전후 표본 확보. 이전 실패 자료는 덮어쓰지 않았다.
- V-HT-03: 입력 국소화와 버튼 수정, 방별 자동 계측/주요 편집·기존 회귀를 구현·실행했다. **실제 한국어 입력기의 연속 타이핑, 화면 튐/목록 위치 실물 관측은 미실행**이다. 합성 marked text나 insertText를 해당 관측으로 승격하지 않는다. 선택/연결 상태의 전체 교차 수락 항목은 기존 시험과 이 집중 시험의 대응을 검토자가 확인해야 한다.
- 범위 밖 기존 실패: AT-HF-27 설치 idempotency/receipt mtime. 기준 동일 재현 증거를 검토해 처분한다. 시험 완화·설치 코드 수정은 하지 않았다.
- 설치 앱은 교체하지 않았고 이 변경을 운영에 적용했다는 주장을 하지 않는다. 후속 실물 관측/설치 허가와 최종 판정은 계획 담당에게 반환한다. 제품 결과 검토 전 푸시대상을 제시하지 않으며 git push도 실행하지 않았다.

## 사용자 지시에 따른 직접 구현 재개
사용자가 “개발 그냥 너가 직접하자”라고 명시하여 이 대화가 직접 구현을 인수했다. 별도 실행 담당은 idle을 확인했고 기존 배정 worktree에서 e63085d를 이어 수정한다. 이후 직접 변경 검증은 자체 점검으로 표시하며 독립 검증으로 주장하지 않는다. 기존 보안·운영·푸시 경계와 수락 기준은 유지한다. 자동 인계 재개를 기다리지 않는다.

## 직접 구현 보완: 멘션 완성 재진입

- [확인] 격리 실제 AppKit 시험 창 준비 중 `--hejo-typing-manual`이 SIGSEGV(-11)로 종료됐다. 진단 스택은 `insertCompletion → didChangeText → ConversationView.textDidChange → complete → insertCompletion` 반복과 stack overflow를 보였다. 로그는 구현 worktree의 `.build/typing-v4/manual.json`, macOS 진단 보고서에 있다.
- [판정] 입력·멘션 계약 보존 범위의 실제 결함이다. 기대값을 완화하거나 자동완성을 시험에서 제거하지 않는다. DraftTextView 기존 완성 처리에 동기 재진입 방지를 추가한다. 초안 변경 알림은 그대로 처리하고 완성 재시작만 막는다. 실제 사용자 입력·완성 선택은 재검증한다.
- [미확정] 사용자에게 실제 타이핑 가능 답변을 받았으나 시험 창 종료로 OS 한국어 입력 관측은 아직 시작하지 못했다. 자동 합성 입력을 실입력 통과로 기록하지 않는다.

## 직접 구현 검증 진행

- 사용자 OS 한국어 입력 관측: 격리 시험 창에서 한국어 연속 입력·중간 수정/undo·멘션 완성·스크롤 후 입력에 대해 사용자가 “문제 없이 입력됨”으로 응답했다. `.build/typing-v4/manual-observation.json`에 기록. 자동 경계 시험도 `AT-HT-01/02/03 BOUNDARIES PASS`.
- 멘션 수정 `db52b3a` 커밋 후 최신 main `236b017`의 사이드바 변경을 통합했다. 통합 커밋 `404c8319979a947a43506b133257ed4d6e0ab419`. 공개 snapshot 이력은 병합하지 않는다.
- 연결 버튼/선택 없음/연결 끊김 회귀 종료 0: `.build/typing-v4/connected-r2.json` 및 log. 첫 실행은 시험 Python의 aiohttp 부재로 종료 1; 작업별 격리 venv를 사용해 재실행했다. Hermes 환경은 변경하지 않았다.
- 전체 AppKit 회귀 종료 1: `AT-UC-32` 판단 버튼 표시 단언 실패. 수정 전 바이너리의 동일 시험도 종료 1/같은 단언으로 재현됨(`ui-baseline.json/log`). 입력 수정 회귀로 단정하지 않으며 전체 통과를 주장하지 않는다. TD-HT-02로 기록한다.
- 중간 홈 수신 동시 성능 실행은 큐 예산 실패로 종료 1(`typing-v4-fixed/typing-home-receive`). 입력 핸들러는 1~5ms지만 큐 시간이 0.518~1.164초였다. 다른 AppKit/컴파일 실행이 겹친 조건이라 원인을 단정하지 않는다. 실패 증거를 보존하고 통합 최종본은 빌드 완료 후 단독 재측정한다. 예산은 변경하지 않는다.

## 배포 후보 준비

정식 `HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh` 종료 0. 검증 커밋 `404c8319979a947a43506b133257ed4d6e0ab419`, tree `e68747d6c20c52c9d45d2fa47106b891d984b49c`, BuildInfo dirty=false. 후보·기존 설치 모두 서명 엄격 검사 0, Google 구성 키 2개 존재, Pet/Sparkle 리소스 존재를 확인했다. 값은 출력하거나 문서에 복사하지 않았다. `.build/typing-v4/deployment-build.json`, `candidate-review.json` 참조.

설치 절차는 아직 미실행: 사용자 작성 중 초안 저장과 앱 종료 동의를 받은 후 기존 설치 번들을 로컬 백업, 후보를 별도 staging 번들에 복사하여 서명/BuildInfo 재확인 후 교체한다. 설정·키체인·서버는 수정하지 않는다. 실행 문제가 있으면 신규 앱을 종료하고 백업 번들을 복원한 뒤 기존 앱을 연다. 백업은 설치 성공 확인 전 삭제하지 않는다. 실제 설치 반영과 푸시 승인은 별개다.

## 최종 직접 구현·자체 점검

최종 검증/설치 대상 `404c8319979a947a43506b133257ed4d6e0ab419`. 최신 main `236b017` 포함. 사용자 직접 역할 변경에 따라 이 대화에서 구현·자체 점검했으며 독립 검증을 주장하지 않는다.

| 조건 | 전체 refresh | 처리 중앙값(ms) | 전체 최대(ms) |
|---|---:|---:|---:|
| typing-direct | 0 | 1.93 | 109.23 |
| typing-direct-receive | 0 | 1.28 | 178.21 |
| typing-group | 0 | 1.50 | 50.13 |
| typing-group-receive | 0 | 1.17 | 146.42 |
| typing-home | 0 | 1.09 | 24.02 |
| typing-home-receive | 0 | 1.44 | 175.96 |

여섯 조건 각 5회×6이벤트 모두 기존 예산 통과. 최종 성능·의미 회귀, 입력 경계, 선택 없음·연결 변화, 사이드바·전송 대상 검사 종료 0. `.build/typing-v4/final-checks.json`, `final-0.log`~`final-8.log`, `.build/hejo-perf-evidence/typing-final` 참조. 개인값·diff·main 포함 검사 종료 0(`static-final.json`). 소스/바이너리 해시는 하네스 build.json에 있다.

AT-HT-01: hejoTypingSample 및 BoundaryTests same-height. AT-HT-02: EditorChecks/ConnectedChecks/NoSelectionChecks/BoundaryTests 및 사용자 실제 OS 한국어 입력 관측. AT-HT-03: 원래 의미 fixture 58단계·수신 동시 입력 3조건·delete/typing/disconnect 단언. AT-HT-04: 여섯 조건 timing과 실제 입력 관측. 수락 fixture·기대값·예산은 불변이다.

기존 Python 설치 mtime 실패와 변경 전에도 재현된 AT-UC-32 판단 버튼 실패는 별도 부채다. 전체 시험 전부 통과로 표시하지 않는다. 중간 동시 부하 성능 실패도 보존하며 최종 단독 실행은 모두 통과했다.

사용자는 초안 저장 후 설치·재실행을 명시 승인했다. 기존 앱 백업 후 정상 후보 교체, 설치 서명 검사 0, 실행 프로세스 확인, BuildInfo tree `e68747d6c20c52c9d45d2fa47106b891d984b49c`/dirty=false. `install.json`, `installed-running.json` 참조. 백업 유지, 운영 설정·서버·실제 메시지 쓰기 없음. 실제 키보드 검증은 격리 창의 사용자 관측이며 설치 후 운영 대화 관측으로 확대하지 않는다. 푸시는 미실행이며 사용자 화면 승인을 기다린다.

## 공개 후보 통합

공개 기준 491b38f2d718a628aaac46f90e68a4ceeb2e86c7 대비 제품 차이는 ConversationView와 DraftEditor의 검증된 입력 수정뿐이다. 기존 공개 문서·성능 근거·사이드바 통합 기록을 보존했다. 검증된 404c831 대비 app 전체 소스/시험은 변경하지 않았다. 공개 문서 추가 후 개인값 검사 및 staged diff 검사 종료 0. 최종 snapshot/개발 tree 일치와 부모·기준 포함 검증 기록은 `.build/typing-public/`에 둔다.
