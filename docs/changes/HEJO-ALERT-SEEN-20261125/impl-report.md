## 구현 인계 — HEJO-ALERT-SEEN TASK-01

### 3판 구현 인계

**판단 상태: 구현 완료, 독립 검토 대기.** handoff 3판 및 검증 2차 V-1을 반영했다. 위험도 일반, 필요한 증거 수준 2, 도달한 증거 수준 2(대역 문·허브의 앱 통합). 기준은 `7540da13639b1094774195ea6815b3d0d4cdf826`이다.

| 코드 상태 | 값 |
|---|---|
| 공개 worktree | `../.worktrees/hejo-alert-seen-public-20261125` |
| 작업 브랜치 | `hejo-alert-seen-public-20261125` |
| 시험 전용 커밋 | `43b7e9d567174f26b7cff13a09ff71f4fd2e1fc7` |
| 제품 커밋 | `b1fc6c49c33eee7ff1b5778adf13b67da992c08a` |
| 검토 대상 원격 브랜치 | `github/main` (커밋 직전 fetch와 직후 ls-remote의 tip은 기준과 동일) |

#### 구현과 설계 대조

- `WorkspaceTools.swift`의 `ConversationModel.selectUserThread`가 직접 선택의 단일 입구다. `markAlertSeen`은 기존 알림 조건에 맞을 때 `notice`를 걸고 성공한 분기를 반환한다. 일반·질문 스레드는 해당 경로의 읽음 조건에 맞춰 `thread`를 건다. 정의·호출 각각 한 곳은 `candidate-v3-structure.log`에서 확인할 수 있다.
- `ConversationView.swift`에서 `reveal`, `chooseThread`, `writeReply`를 이관했다. `ConversationController.swift`의 화면 열기 콜백은 링크·의견 버튼에 직접 선택을 명시하고 후속 표시에는 지정하지 않는다. 링크 경로의 선행 읽음 선택을 제거해 직접 선택을 중복 실행하지 않는다. 사이드바 및 임시글 자동 선택은 기존 입구를 사용한다. AUTOLOAD 뒤 남은 다시 시도 버튼은 조회만 한다.
- `HistoryCoordinator.swift`에서 동일 세션의 현재 세대 요청을 보존한다. 새 세션부터 기존 목록을 비우며 송신 직전의 세대 비교를 유지했다. 대기열이나 저장 키 추가 없음.
- `ConversationModel.swift`는 숨길 때 세대를 바꾸고 표시할 때는 유지한다. 기존 말풍선 준비 순서는 선택 다음에 창을 표시한다. 표시 시점의 세대 증가를 그대로 두면 방금 고른 알림 의도가 취소되는 것을 보조 시험으로 재현했다. 이 변경으로 동일 선택의 말풍선 경로를 지원하며, 다른 스레드로 선택이 바뀌면 기존 선택 세대 증가가 적용된다.
- `gate/history_queries.py`의 notice 미리보기가 멘션 줄에 다음 내용 줄을 이어 붙인 뒤 기존 300 글자 묶음 한도를 적용한다. 문 HTTP와 다른 미리보기, 레거시 카드 제목은 기존 계약을 사용한다.

#### 시험과 회귀

로그는 공개 worktree의 `.build/alert-seen/`에 있다. 기준본과 최종 검증은 각각 해당 커밋에 대응하며 제품 커밋 패치가 검증한 작업 트리 패치와 일치하는 것을 비교했다.

| 명령/기준 | 종료와 결과 | 로그 |
|---|---|---|
| 3판 기준본 `bash app/Tests/HistoryTransport.sh` | 0 | `baseline-v3-build.log` |
| 3판 기준본 `pytest gate/tests/test_history_queries.py -k alert_seen` | 1, 15통과·5예상 실패 | `baseline-v3-gate.log` |
| 3판 기준본 `pytest gate/tests/history_transport_app.py -k alert_seen` | 1, 7통과·6예상 실패. AT-AS-13 A 0건, B 1건 관측 | `baseline-v3-transport.log`, 판정 `baseline-v3.log` |
| 문 변경 직후 `pytest gate/tests/test_history_queries.py -k 'at_as_09 or at_as_10'` | 0, 19통과 | `candidate-v3-preview.log` |
| `pytest gate/tests/test_history_queries.py -k alert_seen` | 0, 20통과 | `candidate-v3-gate.log` |
| 최종 `bash app/Tests/HistoryTransport.sh` + `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py` | 각각 0, 기존 69개 포함 82통과 | `candidate-v3-final-build.log`, `candidate-v3-full-transport.log` |
| 말풍선 열기 보조 시험, `pytest .build/alert-seen/bubble-probe/test_bubble.py` | 0, 1통과. 선택과 창 표시가 한 UI 갱신 안에서 이어짐 | `bubble-probe/result.log` |
| 말풍선 변형, `pytest .build/alert-seen/bubble-probe/test_before.py` | 1, 1실패. 창 표시의 기존 세대 증가만 복원하자 notice가 전송되지 않고 카드가 남음 | `bubble-probe/before-result.log` |
| `bash scripts/test.sh` | 1, 564통과·5실패. 기준본 6개 중 부분집합이며 새 실패 0. 뒤의 문 배달·앱 항목은 이 명령에서 미실행 | `candidate-v3-final-suite.log`, `candidate-v3-compare.log` |
| `sandbox-exec -f .build/alert-seen/app-write-guard.sb bash app/scripts/test.sh` | 0, 독립 앱·레거시 회귀 통과(AT-TD-39·AT-UC-17·AT77 포함). 실제 설정·다운로드 메타데이터 유지 | `candidate-v3-app.log` |
| Hermes 실행 venv의 `python scripts/scan_private.py --home <가짜 홈>` | 0 | `candidate-v3-final-private.log` |
| `git fetch github`, `git ls-remote github refs/heads/main`, 패치 비교, `git diff --check` | 각각 0. 공개 tip과 검증 변경본 확인 | `candidate-v3-remote.log`, `candidate-v3-tested.patch`, `candidate-v3-commit.log` |

AT-AS-12는 두 스레드의 직원 글을 처음엔 알림 기간 안에 두고 창을 연 뒤 시험 시계를 전진시켜 만료시킨다. 클릭 전 대상 안 읽음이 2개임을 확인한다. AT-AS-13은 대역 문이 A 선택 뒤 context 응답을 지연하는 동안 B를 고른다. 수정본에서 이전 A 요청과 읽음 상태 변경이 없고 B의 대상 요청이 있었다.

#### 독립 검토 및 미검증 범위

검토 시 현재 세대 보존과 옛 세대 송신 차단, 말풍선의 창 열기 순서, 자동 콜백의 직접 선택 제외를 확인한다. 일반 회귀의 환경 실패는 기준본과 비교했다. 앱 설치·실제 게이트웨이·원격 푸시는 미실행이다.

### 이전 기록 — 2판 기준본 보류

**판단 상태: 보류(기준본 보존 시험 불일치).** 2판 인계서 0절에 따라 HEJO-AUTOLOAD 완료 판정과 공개판 반영을 확인했다. 착수 기준은 공개 `github/main`의 `7540da13639b1094774195ea6815b3d0d4cdf826`이다. 위험도 일반, 목표 증거 수준 2, 연합개발. 대역 통합 증거는 기준본에 한한다.

### 시험 코드와 변경 범위

공개 worktree `../.worktrees/hejo-alert-seen-public-20261125`, 브랜치 `hejo-alert-seen-public-20261125`. HEAD는 착수 커밋이다. 시험 파일 네 개와 무추적 로그를 남겼다. 9절 2단계에서 멈춰 시험 전용 첫 커밋과 제품 커밋은 미실행이다.

- `app/Tests/HistoryAlertSeenHarness.swift`, `app/Tests/HistoryTransportHarness.swift`에 실 AppKit 선택과 허브 대역 상태 동기화, 가운데 창 스냅숏 관측을 연결했다.
- `gate/tests/history_transport_app.py`는 임시 기록장과 루프백 문에서 `read_plan`의 action, scope, target을 기록하고 action별 409를 주입한다. AT-AS-06은 사장 답변이 문 기록장에 들어갔는지 확인한다.
- `gate/tests/test_history_queries.py`에 AT-AS-08 단일 입구, AT-AS-09 카드 문구, AT-AS-10 다른 미리보기 제한 시험을 추가했다. 기존 시험 기대값 변경 없음. 별도 변형 시험은 제품 변경 보류로 미실행.
- 제품 변경 위치는 인계대로 관제 화면의 직접 선택과 문의 notice 미리보기다. 기준본에서 AUTOLOAD 이후 원문 불러오기 버튼이 사라졌고, 다시 시도는 `historyLoading.retry`만 호출한다.

### 보류 근거

| 보존 시험 | 기준본 관측 |
|---|---|
| AT-AS-01 | 채팅이 보이는 상태에서 가운데 카드 클릭 후 `enter`만 관측됐다. `notice` 0건이고 카드가 남았다. |
| AT-AS-02 | 채팅의 카드를 눌러 `thread` 200을 받았다. `notice` 0건이고 카드가 남았다. |
| AT-AS-07a | `thread` 200을 받았다. 대역 문이 `notice`만 409로 거절하도록 준비했으나 요청이 들어오지 않았다. |

AT-AS-02·07a를 설명하는 코드 경로가 있다. `HistoryCoordinator.start`는 읽기 계획 하나를 적용하고 다음 항목으로 간다. 앞선 `thread` 적용이 새 회원 상태를 쓰면 `ConversationModel.swift:429`의 콜백이 문맥과 선택 세대를 무효화한다. `HistoryCoordinator.swift:324`의 `inputsChanged`가 작업과 대기 읽기 목록을 지워 뒤의 `notice`가 전송되지 않을 수 있다. AT-AS-01에서 `reveal`의 `notify:false` 선택 직후 호출하는 `open(anchor:)`는 `enqueue` 안에서 `inputsChanged`를 먼저 실행한다. 새 선택이 감지되면 이미 등록된 읽기 목록이 지워지는 경로다. HTTP 관측과 소스 대조 결과이며 큐 내부 시점은 따로 계측하지 않았다.

AT-AS-04·08·09의 예상 실패와 나머지 보존 판정은 `.build/alert-seen/baseline.log`에 기록했다. AT-AS-07c는 두 복구 시나리오의 재선택 요청과 카드 제거를 관측했다. AT-AS-07a의 첫 클릭에서 409가 발생하지 않아 해당 복구 시나리오의 전제는 검증되지 않았다.

### 검증 증거

공개 worktree의 `.build/alert-seen/`에 전체 결과가 있다.

| 명령 | 종료와 결과 | 로그 |
|---|---|---|
| `bash app/Tests/HistoryTransport.sh`, `bash app/Tests/HistoryTransport.sh --legacy` | 최종 빌드 각각 0. 출시 로그에 앞선 입력 편집 오류도 남아 있음 | `baseline-build.log`, `baseline-build-legacy.log` |
| `pytest gate/tests/test_history_queries.py -k alert_seen` | 1, 15통과·5예상 실패 | `baseline-gate.log` |
| `pytest gate/tests/history_transport_app.py -k alert_seen` | 1, 6통과·4실패(예상 1, 불일치 3) | `baseline-transport-confirm.log` |
| `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py` | 1, 75통과·4실패. 기존 69개 모두 통과, 실패는 새 AT-AS-01·02·04·07a | `baseline-transport-full.log` |
| `bash scripts/test.sh` | 1, 543통과·6실패. 신규 AT-AS는 별도 실행. pytest 실패로 뒤의 문 배달 명령과 앱 시험 미실행 | `baseline-suite.log` |
| `python scripts/scan_private.py --home <가짜 홈>` | 0, Hermes 실행 venv와 시험 파일을 넣은 임시 인덱스 사용 | `baseline-private.log` |
| `git diff --check` 및 `git diff --exit-code -- app/Sources gate/history_queries.py` | 각각 0, 제품 변경 없음 확인 | 작업 트리 |
| `git fetch github && git rev-parse github/main HEAD` | 0, 둘 모두 착수 해시 | 작업 트리 |

일반 회귀의 실패 목록은 별도 비교를 위해 보존했다. 일부 실패에서 시험 venv의 `yaml` 모듈 부재가 확인됐다.

### 계획 담당 검토 요청

AT-AS-01·02·07a의 기준본 분류와 두 읽음 계획의 독립성 가정을 다시 검토한다. 확인 처리 입구만 통합하면 이미 드러난 읽기 의도 소실은 남는다. 직접 선택에서 파생된 의도를 자기 회원 상태 갱신이나 화면 열기와 어떻게 연결할지 계획에 포함하는 것이 필요하다. 선택이 다른 스레드로 바뀐 경우 오래된 의도를 폐기하는 기존 안전 조건도 함께 검토한다. 시험용 파일과 증거는 공개 worktree에 보존했다. 문과 앱 제품 수정, 커밋, 설치, 푸시, 후보 검증은 미실행.
