# 구현 인계 · HEJO-AUTOLOAD TASK-01

## 판단

보류(20-implementation 2절 보고). 승인된 [4판 인계](handoff.md) 10절의 위치 유지 가정을 기준판에서 측정했다. 기존 AppKit 목록은 위쪽 카드가 커지는 경우 읽던 글의 위치를 유지한다. 답글 끝에서 다음 쪽을 붙이는 경우에는 마지막으로 읽던 글이 화면 밖으로 밀린다. 인계서의 착수 중단 조건에 따라 제품 구현을 보류했다.

위험도는 일반, 요청된 구현 증거는 수준 3이다. 확보한 증거는 기준판의 실제 AppKit 위치 재현과 실제 loopback HTTP/WS 회귀 시험이다. 새 구현에 대한 증거는 없다.

## 위치 측정

공개판 `570c611f11fb531a8a98eff9823348ea5c0d9f37`의 소스와 AppKit 창에 연결된 실제 `NativeThreadList`를 사용했다. 같은 목록에서 높이가 다른 본문을 반영한 뒤 레이아웃이 안정될 때까지 기다리고, 대상 글의 프레임 y에서 스크롤 원점을 빼 화면 y를 계산했다. 두 번 실행한 결과가 같았다.

| 조건 | 반영 전 | 반영 후 | 이동 | 허용 |
|---|---:|---:|---:|---:|
| AT-ALD-08 관련. 카드 12개 중 읽는 글 위의 카드 5개를 1줄에서 20줄로 늘림 | −2pt | −2pt | 0pt | 1pt |
| AT-ALD-14 관련. 펼친 스레드 끝에서 120~169번째 답글이 보이는 목록에 170~218번째를 붙임. 기준 글은 169번째 | 273pt | −3,010pt | 3,283pt | 1pt |

`app/Sources/NativeThreadList.swift:135-144`의 `readerAnchor()`는 문서 끝과 보이는 영역의 차이가 2pt 이하일 때 글 기준점을 반환하지 않는다. `apply`(190–203행)는 이 경우 이전의 문서 끝 여백을 유지하고, `restore`(208행)는 확장된 문서의 끝으로 원점을 옮긴다. 기존 하네스의 `anchorCheck`(934–948행)는 중간 위치에서 앞에 카드를 추가하는 사례를 검증한다.

## 변경 범위와 보완 결정

- 구현용 공개판 worktree는 계획 폴더 기준 `../.worktrees/hejo-autoload-public-20261125`, 브랜치는 `hejo-autoload-public-20261125`다. HEAD는 위 기준 커밋이다.
- 추적 파일 변경과 새 커밋은 없다. 진단 Swift 소스와 로그는 구현 worktree의 무시 경로 `.build/autoload/`에 있다. 이 인계 보고서는 계획 폴더에 기록했다.
- 계획 담당이 설계 3절에 자동 기록 반영 시 목록 끝에서도 읽던 글의 위치를 고정하는 계약을 정하는 방안을 권고한다. 기존 답변 스트리밍의 하단 따라가기와 직접 열기 스크롤을 보존할 반영 조건도 명시한다. AT-ALD-14의 입력과 1pt 허용치는 그대로 둔다. 계획을 보완하고 나면 같은 기준 worktree에서 구현을 이어갈 수 있다.
- AT-ALD-01~34의 전체 수락 흐름, AT-ALD-12의 이전 답글 추가 위치 검증, 최종 구현 정적 검사와 설치 앱 수동 확인은 미실행이다. 이번 위치 진단은 기준판에서 레이아웃 가정만 검증했다.

## 기준 검증

로그는 공개판 worktree의 `.build/autoload/` 기준이다. Python은 기존 Hermes 시험 환경과 읽기 전용 런타임 workspace를 사용했다. 기존 증거 경로의 `regex`를 import 경로에 추가해 초기 의존성 오류를 해소했다. 재현용 환경 명령은 `baseline-env.zsh`에 있다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| 기준판 소스 + `.build/autoload/AnchorProbe.swift`를 Swift로 빌드 | 종료 0 | `baseline-anchor-build.log` |
| `.build/autoload/anchor-probe` 2회 | 각 종료 1. 위 카드 높이 변화 시 0pt, 목록 끝 다음 쪽 추가 시 3,283pt | `baseline-anchor.log`, `baseline-anchor-repeat.log` |
| `bash app/Tests/HistoryTransport.sh`로 생성한 바이너리로 Python `-m pytest gate/tests/history_transport_app.py -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 실제 loopback HTTP/WS 32개 통과 | `baseline-history-build.log`, `baseline-history.log` |
| `bash scripts/test.sh` | 종료 1. pytest 506개 통과, 5개 실패. 기준판에서도 PyYAML·`hermes_facility` import 실패와 현지화 라벨 불일치가 발생했다. 이 진입점에서는 후속 게이트웨이와 앱 단계가 실행되지 않았다 | `baseline-suite.log` |
| `git diff --exit-code` 및 `git status --short --branch` | 추적 변경 없음, 위 기준 커밋 유지 | 셸 출력 |
| `bash app/scripts/test.sh` 단독 | 종료 1. `APP_TEST_OK` 표식 17회, 훅 시험 9개 OK. 종료 시 설정 메타데이터 보호 검사 실패. 다운로드 메타데이터 보호 통과. 설정 중 어느 경로가 바뀌었는지와 원인은 미확인 | `baseline-app.log` |

## 5판 보완 구현 인계

5판의 구현은 부분 구현이다. 공개판 기준과 worktree는 위와 같다. 위의 보류 보고와 기준 로그를 변경 전 증거로 보존했다. V-1의 목록 끝 예외를 작업본에 구현했다. `ConversationView`는 과거 답글이 아래에 추가됐다는 정보만 넘기며, `NativeThreadList`가 기존 글 기준점 경로를 적용한다.

| 변경 경로 | 변경 이유 |
|---|---|
| `app/Sources/NativeThreadList.swift` | 보이는 영역과 앞서 받는 영역의 카드·글 위치를 게시하고, 자동으로 아래에 붙인 경우 기존 글 기준점을 목록 끝에서도 사용 |
| `app/Sources/ConversationView.swift` | 현재 영역에 필요한 대상과 실패 UI를 구성하고 다섯 기존 불러오기 버튼과 휠 기반 본문 복원 호출을 제거 |
| `app/Sources/HistoryCoordinator.swift`, `app/Sources/HistoryHTTP.swift` | 기존 조정자가 자동 대상·갱신 우선순위·이전 커서 재구성·대상별 지연 재시도를 소유. 자동 요청은 기존 HTTP의 즉시 재시도를 끄고 tick으로 지연 |
| `app/Sources/HistoryProjection.swift`, `app/Sources/ConversationModel.swift` | 열린 기록 쪽의 글 순서와 이전 커서를 세션 상태에 보존. 다음 답글 쪽을 합칠 때 이전 커서와 최근 답글 남은 수를 별도로 반영 |
| `app/Tests/HistoryTransport.sh`, `app/Tests/HistoryTransportHarness.swift`, `app/Tests/HistoryAutoloadHarness.swift`, `app/Tests/HistoryAutoloadFixture.py` | 실제 루프백 HTTP/WS와 AppKit으로 초기 자동 불러오기 시험 19시나리오를 실행하는 경로 추가. 승인된 수락 명세와 기존 복원 시험의 단언은 편집하지 않음 |

기존 `view-root`·`view-root-owner` 복원 fixture는 420pt 창에 짧은 답글 세 개를 사용한다. 기존 Swift 검사는 휠 전 상주 본문이 원문 하나뿐이라고 단언하고, 서버 쪽 검사는 휠 뒤 전체 복원 요청이 정확히 한 건이라고 단언한다. 근거는 `app/Tests/HistoryTransportHarness.swift:356-376` 및 `gate/tests/history_transport_app.py:600-607`이다. 화면 범위 기반 자동 복원에 맞춰 fixture 배치와 요청 기대값을 어떻게 바꿀지 계획 보완을 요청한다. 기존 회귀의 원문 고정, 상주 한도, 요청 중복, 커서·안 읽음 수 보존, 삭제 결과 검사는 보존할 수 있다. 기존 시험 실패를 모두 이 계약 충돌로 분류하지 않는다. 아래 후보 시험에서 위치와 페이지 대기 등 별도 작업이 남았다.

이전 답글 50개를 앞에 반영하는 기준 진단은 0pt로 통과했다(`.build/autoload/baseline-prepend.log`, 종료 0). 후보 목록 진단은 위쪽 카드 성장 0pt, 맨 끝 자동 답글 붙이기 0pt, 기존 라이브 추가 끝 여백 0pt이고 새 글은 보였다(`.build/autoload/candidate-anchor.log`, 종료 0). 이 진단은 실제 AppKit 목록을 쓰며, 전체 수락 흐름 대신 레이아웃 경계를 확인한다.

### 후보 시험 결과

- `bash app/Tests/HistoryTransport.sh` 종료 0(`history-candidate-build.log`). 이 바이너리의 기존 HTTP/WS 시험은 27개 통과·5개 실패(`candidate-history.log`). 실패는 `view`, `view-long`, `view-cycle`, `view-root`, `view-root-owner`이고, 별도의 명시 읽음 재시도 회귀는 분리 후 통과했다.
- 새 하네스의 초기 19시나리오는 9개 통과·10개 실패(`candidate-autoload.log`, 종료 1). 원문 요청의 보류와 해제, 단일 실패 UI, 59초/61초 재시도, 영역·방 이동, 선택 원문 조회를 포함한다. 위치·페이지 실패 및 fixture의 관측 시점을 분리해 추가로 잡아야 한다. 이 실행의 수치로 수락 시험 35개 통과를 주장할 수 없다.
- `bash scripts/test.sh` 종료 1. 문 pytest 506개 통과·5개 실패, 기준 실패 ID 목록과 diff 종료 0(`candidate-suite.log`, `suite-failures.diff`).
- 개인값 검사 종료 0(`candidate-private.log`). 임시 Git 인덱스에 새 시험 파일을 포함했다. 실제 인덱스는 바꾸지 않았다.
- 초기 앱 단독 시험은 소스 수정과 컴파일이 겹쳐 유효하지 않다(`candidate-app.log`). 같은 실행에서 읽기 전용 lstat 비교로 hejo 설정 폴더의 mtime·ctime과 `hejo-local.json`의 inode·mtime·ctime 차이를 확인했다(`candidate-settings-diff.log`). 설정 내용과 변경 주체는 확인하지 않았다.
- 계측용 복원 fixture 사본에서 미리보기 표시가 실제 본문 id처럼 고정되는 문제가 나타났다. 표시 id를 분리하니 기존 인위적 1개 한도 fixture에 정지 상태 복원 재요청이 드러났고, 두 경우에서 각각 2,297건·2,162건이 찍혔다(`restore-contract-after-markers.log`). 해당 수치는 격리된 loopback 시험이며 제품 배포 증거가 아니다.
- 같은 범위에서 이미 복원한 대상을 다시 호출하지 않도록 한 뒤 계측 사본을 재실행했다. `view-root`와 `view-root-owner`에서 각각 **복원 3건**으로 줄었다. 기존 검사는 한 경우 시간 초과, 다른 경우 `fixture_not_root_only`로 실패했다(`restore-contract-bounded.log`, 종료 1). `view-root-owner`는 휠 전 단언에서 종료했다. 두 시험의 단언·입력은 유지했고 계측 사본은 요청 수만 표시한다.

### 다음 검토가 필요한 부분

1. 승인 범위에서 기존 복원 fixture를 새 동작에 맞게 바꾸는 방법을 정한다. 현재의 단일 요청 기대를 유지하려면 화면 배치를 바꿔 한 번에 필요한 복원 대상을 하나만 범위에 들도록 해야 한다. 현재의 짧은 네 글 fixture를 유지한다면 보이는 범위에 든 글마다 최대 한 번이라는 요청 기대가 필요하다. 후자는 현재 금지된 `gate/tests/history_transport_app.py` 수정 범위에 걸린다.
2. 초기 자동 하네스에서 실패한 전체 화면 원점(AT-ALD-02), 이전·다음 쪽, 커서 무효 복구를 게이트 요청·뷰 렌더링 단계별로 추적한다. `live` 초안은 대상 스레드가 목록의 마지막이라는 AT-ALD-35 입력을 별도로 맞추고 시험한다.
3. 복사 버튼 이후 클립보드, 큰 방 상주 한도, 모든 목록 쪽, 삭제, 긴 원문 단독 오류, 우선순위와 범위 이탈 등 아직 완전히 코드로 옮기지 않은 수락 시험을 채운다. AT-ALD-01~35 통과 판정은 미완료다.
4. 운영 서버, 규약, 설치, 릴리스, 수락 명세는 편집 범위에 포함하지 않았다. 공개판 브랜치 HEAD는 기준 커밋 그대로고 후보 파일은 작업본에 있다. 최종 커밋과 교차 검증은 남았다.

### 같은 범위 복원 제한 후 재검증

- 기록 하네스를 별도 바이너리로 빌드했다. Swift 컴파일 종료 0(`bounded-build.log`). 실행 파일 경로만 바꾼 기존 HTTP/WS 시험 사본을 실행해 종료 1, 27개 통과·5개 실패로 초기 후보와 같은 목록을 확인했다(`bounded-history.log`).
- 초기 초안에서 통과했던 9시나리오를 같은 바이너리로 다시 실행했다. 종료 0, 9개 통과·10개 미선택(`bounded-autoload-checks.log`). 미선택은 위 초기 초안 실패 사례다.
- 최종 작업본의 개인값 검사 종료 0(`final-private.log`). `git diff --check` 종료 0, `git diff --name-only -- gate schemas install` 출력 없음.
- 앱 단독 시험은 설정 표시 id 분리 후, 같은 범위 복원 제한을 넣기 전의 바이너리로 재실행했다. 종료 1, `APP_TEST_OK` 표식 17회·훅 시험 9개 OK로 기준판과 같았다. 실패는 종료 시 설정 메타데이터 검사였다. 다운로드 보호 통과(`final-app.log`). 전후 `lstat`에서 hejo 설정 디렉터리와 `hejo-local.json`의 메타데이터 차이가 다시 관찰됐다(`final-settings-diff.log`). 변경 주체와 내용은 미확인이다.

## 6판 보완 구현 인계

판단: 부분 구현 및 명세 대조에서 중단. 제품 후보는 공개판 worktree에 있으며 HEAD는 `570c611f11fb531a8a98eff9823348ea5c0d9f37`이다. 이번에도 커밋하지 않았다.

### 차단 사항 — 검색으로 중간 답글을 연 직후의 이전 쪽 자동 요청

- REQ-ALD-03과 design 3절은 펼친 스레드의 첫 답글이 받는 범위에 들어오면 이전 쪽을 자동 요청하도록 한다. 기존 검색 열기의 `onAnchor`는 가리킨 답글을 화면에 놓는다. `gate/history.py`의 앵커 응답은 120번째를 처음 글로 삼은 120~169번째 쪽과 그 앞 커서를 반환한다. 즉 검색 열기 자체가 이전 쪽 자동 요청의 조건을 충족한다.
- 같은 흐름의 AT-ALD-15는 다음 세 쪽을 받은 시점에도 1~119번째가 앱에 없어야 한다고 요구한다. 현 사양에는 검색 열기의 이동을 이전 쪽 가장자리 진입으로 취급하지 않는 규칙이 없다. AT-ALD-28은 내려간 뒤에야 같은 세 이전 쪽을 받는 흐름이다.
- 실제 loopback 요청 추적에서 `anchored`는 120번째 앵커 열기 직후, 아래로 스크롤하는 하네스 단계에 이르기 전에 이전 커서 요청 3건을 냈다. 초기 120~169쪽 대기는 시간 초과했다. 정답이나 자격 조건을 수정하지 않았다.
- 권고: 검색·알림의 명시적 위치 이동이 이전 답글 접근을 자동으로 시작할지 결정한다. 시작하면 AT-ALD-15/28의 이전 쪽 시점을 대조해 조정한다. AT-ALD-15/28을 유지하려면 검색·알림으로 중간을 연 직후의 이전 쪽 요청 예외와 위로 이동한 뒤 재개하는 조건을 명시한다. 양쪽에서 기존 화면의 검색 앵커 이동 자체는 유지할 수 있다.

### 작업본 변경

- `NativeThreadList.swift`가 앞서 받기용 글 위치와 실제 보이는 글 위치를 함께 보고한다. `ConversationView.swift`는 표시용 본문 ID를 원래 ID로 풀어 넘기고, `HistoryCoordinator.swift`가 비워진 글의 요청을 보이는 영역으로 제한한다. 기존 복원 횟수에 의존하던 상태를 삭제했다.
- 기존 복원 시험의 `view-root`, `view-root-owner`만 6판의 휠 전 네 본문 및 복원 요청 3건 단언으로 옮겼다. 변경 범위는 `app/Tests/HistoryTransportHarness.swift`와 `gate/tests/history_transport_app.py`의 해당 분기다. 원문 고정, 주인 원문의 분기 버튼, 커서·끝 여부·안 읽음, 삭제 정리는 보존했다. 나머지 세 view fixture 전환과 수락 시험 36개 전체 이관은 남았다.
- 이번 턴에서 기준 시험을 다시 돌리거나 실제 설정 파일을 열지 않았다. 기존의 기준 실패 비교 로그는 앞 절에 있다.

### 시나리오와 수락 시험 대응

이 표는 이관 또는 진단을 시작한 항목을 나타낸다. 일부 단언을 실행한 경우 해당 AT 전체의 합격을 뜻하지 않는다. 경로는 공개판 worktree `.build/autoload/` 기준이다.

| 시나리오 | AT 번호 | 이번 턴 결과 | 로그 |
|---|---|---|---|
| basic | 01, 02, 17 일부 | 미재실행, 5판 02에서 실패 | `candidate-autoload.log` |
| held | 03 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| missing | 04, 22 일부 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| retry | 33 일부 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| retry-fails | 34 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| long | 09 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| viewport | 05, 23 일부 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| leave-room | 06 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| refresh-fails | 25 일부 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| root-only | 13, 26 | 미재실행, 5판 통과 | `bounded-autoload-checks.log` |
| older | 11, 12 | 실패. 첫 50개 대기 중에 이전 커서 요청이 시작됨 | `v6-page-trace.log`, `v6-older-requests.json` |
| anchored | 14(가), 15, 19 일부, 28 | 실패. 최초 120~169, 후속 구간 70~119·20~69·원문과 1~19가 아래 방향 조작 전에 수신됨 | `v6-page-response.log`, `v6-anchored-responses.json` |
| anchored-last | 14(나), 15 | 실패 | `v6-page-trace.log` |
| anchored-fail | 27 | 실패 | `v6-page-trace.log` |
| cursor-context | 30(가) | 미재실행, 5판 실패 | `candidate-autoload.log` |
| cursor-expired | 30(나) | 미재실행, 5판 실패 | `candidate-autoload.log` |
| cursor-far | 31 | 실패 | `v6-page-trace.log` |
| cursor-fails | 32 | 미재실행, 5판 실패 | `candidate-autoload.log` |
| live | 35 | 미재실행, 5판 실패 | `candidate-autoload.log` |

AT-ALD-07·08·10·16·18·20·24·29·36 전체 흐름과 17의 명시 복사, 22의 삭제, 23·25·33의 나머지 단언은 실행 가능한 수락 시험으로 남아 있다. AT-ALD-21에 대응하는 미커밋 범위 점검에서 지정한 gate 시험 파일 한 줄만 나왔다. 커밋 범위 비교는 미실행이다.


| 기존 회귀 시나리오 | 대응 AT | 결과 | 로그 |
|---|---|---|---|
| view-root | 16(나)의 기존 회귀 | 실패. 420pt에서 네 본문 대기 중 시간 초과 | `v6-root.log` |
| view-root-owner | 16(나)의 기존 회귀 | 실패. 420pt에서 네 본문 대기 중 시간 초과 | `v6-root.log` |
| view, view-long, view-cycle | 16(가), 36의 기존 회귀 대상 | 이번 턴 미이관·미실행 | 이전 실패 `bounded-history.log` |

### 실행 기록

- `bash app/Tests/HistoryTransport.sh` 종료 0(`v6-build.log`). 이 바이너리는 화면에 보이는 범위만으로 복원 대상을 좁힌 시점이고, 루트 회귀의 기대값 변경 전이다.
- `pytest .build/autoload/V6RequestDiagnostics.py -q -k 'anchored or older or cursor-far'` 종료 1, 5개 실패·14개 미선택(`v6-page-trace.log`). `pytest .build/autoload/V6ResponseDiagnostics.py -q -k 'anchored]'` 종료 1, 1개 실패·18개 미선택(`v6-page-response.log`). 사본은 요청·응답에 계측만 추가했으며 시험의 동작과 단언은 원본대로다.
- 6판 루트 회귀 기대값을 포함해 Swift 하네스 재빌드 종료 0(`v6-root-build.log`). 바이너리 경로만 바꾼 시험 사본에서 `pytest .build/autoload/V6RootReplay.py -q -k 'cursor and view-root'` 종료 1, 2개 시간 초과 실패·30개 미선택(`v6-root.log`).
- `python scripts/scan_private.py` 종료 0(`v6-private.log`, 임시 Git 인덱스로 신규 파일 포함). `git diff --check` 종료 0. `git diff --name-only -- gate schemas install`에 지정된 gate 시험 파일만 있고 해당 diff는 두 루트 fixture의 요청 수 기대만 수정했다.

## 7판 보완 구현 인계 진행 기록

- 5줄 답글과 700pt 창 fixture, 50개 쪽 높이 > 창×2 단언, 첫 자동 이전 쪽의 실제 HTTP 응답 ID 기록을 추가했다. 첫 검색 앵커의 위치가 이전 쪽 반영 시 유지되도록 우선 기준점을 넘기고, 목록은 기존 위치 복원이 끝난 뒤 범위를 다시 보고한다.
- 기존 복원 다섯 fixture에는 하네스가 AppKit 프레임과 클립 영역을 직접 비교해 관측한 진입 ID를 기록하게 했다. gate 시험은 요청 ID와 비교한다. 다른 기존 복원 사례의 오류 주입·상태 단언은 기존 경로에 남겼다.
- 일반 시험의 기준 실패 목록 비교는 `v7-standard.log`와 `v7-standard.diff`다. pytest 506개 통과·5개 실패, 실패 ID diff 종료 0.
- `v7-suite.log` 이후 재시도 fixture는 첫 요청 발생을 직접 확인하고 시계를 진행한다. `v7-final-autoload.log`는 28개 통과·2개 실패. 기본 방 원점이 5pt에서 151pt로 이동했으며, evicted fixture 첫 화면에서 보인 아홉 슬롯 중 두 본문을 복원했다. `v7-final-regression.log`는 31개 통과·1개 실패이며 반복 스크롤 fixture에서 복원 요청 수가 기하 관측치보다 컸다. 후속 검증으로 확인할 실패다.
- `bash app/scripts/test.sh`는 설정 보호 검사에서 종료 1(`v7-app.log`). 기준과 같이 `APP_TEST_OK` 17회, 훅 시험 9개 OK, 다운로드 보호 통과다. 실제 설정 내용을 열지 않고 메타데이터만 비교한 결과는 `v7-settings.diff`에 있다. 폴더와 `hejo-local.json`의 메타데이터 차이가 재현됐고 변경 주체는 미확인이다. 이 바이너리는 같은 위치의 복원 묶음 및 동일 슬롯 ID 변경 전 소스로 빌드했다.
- 같은 화면의 긴 본문을 첫 응답마다 곧바로 그리면 뒤쪽의 비워진 본문 슬롯이 먼저 범위 밖으로 밀리는 것을 확인했다. 최신 후보는 현재 보이는 복원 대상들을 동일한 화면 배치에서 한 번에 하나씩 보내고, 그 대상들의 반영은 함께 그린다. 사용자가 범위를 움직이면 기존 대상 목록을 갱신한다. 본문과 빈 표시가 같은 슬롯 ID를 써서 위치와 고정 판단에 같은 기준을 사용한다.

### 7판 최종 후보 시나리오 ↔ 수락 시험

환경은 임시 Hermes 홈과 가짜 명부, 실제 loopback HTTP/WS와 AppKit이다(증거 수준 3). 아래 `v7-acceptance-and-regression.log`는 보이는 슬롯의 최근 높이 유지까지 포함한 제품 코드에서 신규 31개와 기존 32개를 함께 실행한 결과다. 일부 새 시험의 단언을 강화한 최종 하네스는 아래 추가 로그에 별도로 적는다. 로그 경로는 구현 worktree `.build/autoload/` 기준이다.

| 시나리오 | AT-ALD 번호 | 결과 | 로그 |
|---|---|---|---|
| basic | 01, 02, 17 | 통과 | `v7-acceptance-and-regression.log` |
| held | 03 | 통과 | 같은 로그 |
| missing | 04, 22(권한·본문 실패) | 통과 | 같은 로그 |
| viewport | 05, 23 | 통과 | 같은 로그 |
| leave-room | 06 | 통과 | 같은 로그 |
| repeat | 07 | 통과 | 같은 로그 |
| growth | 08 | 통과 | 같은 로그 |
| long | 09 | 통과 | 같은 로그 |
| long-fail | 10 | 통과 | 같은 로그 |
| older | 11, 12, 19(직접 열기) | 통과 | 같은 로그 |
| root-only | 13, 26 | 통과 | 같은 로그 |
| anchored | 14(가), 15, 19(검색 열기), 28 | 통과 | 같은 로그 |
| anchored-last | 14(나), 15 | 통과 | 같은 로그 |
| evicted | 16(가), 36(보이는 글) | 통과 | 같은 로그 |
| 기존 view-root, view-root-owner | 16(나) | 통과 | 같은 로그 |
| legacy | 18 | 통과. 같은 세 스레드, 기록 HTTP 0건 | 같은 로그 |
| budget | 20 | 통과 | 같은 로그 |
| Git 변경 범위 | 21 | 지정한 시험 파일 한 개 | 커밋 전후 git 검사 |
| delete | 22(삭제) | 통과 | `v7-acceptance-and-regression.log` |
| priority | 24 | 통과 | 같은 로그 |
| refresh-fails | 25(갱신 실패 및 복구) | 통과 | 같은 로그 |
| anchored-fail | 27 | 통과 | 같은 로그 |
| thread-pages | 29 | 통과 | 같은 로그 |
| cursor-context, cursor-expired | 30(가, 나) | 통과 | 같은 로그 |
| cursor-far | 31 | 통과 | 같은 로그 |
| cursor-fails | 32 | 통과 | 같은 로그 |
| retry, retry-outside | 33(시간·범위) | 통과 | 같은 로그 |
| retry-fails | 34 | 통과 | 같은 로그 |
| live | 35 | 통과 | 같은 로그, 기존 앱 시험 `v7-app.log` |
| prefetch-eviction | 36(앞서 받은 뒤 비워진 글) | 통과 | `v7-acceptance-and-regression.log` |
| root-edge | 37 | 통과. 원문 위치에서 두 쪽이 순서대로 이어짐 | 같은 로그 |
| 기존 view, view-long, view-cycle | 16, 36 회귀 | 통과. AppKit 보이는 글 진입 ID와 서버 복원 ID 비교 | 같은 로그 |

- `bash app/Tests/HistoryTransport.sh`와 `bash app/Tests/HistoryTransport.sh --legacy`가 종료 0(`v7-footprint-build.log`, `v7-footprint-legacy-build.log`). 함께 실행한 `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py -q` 종료 0, 63개 통과(`v7-acceptance-and-regression.log`).
- 마지막 제품 코드의 `bash scripts/test.sh`는 종료 1, 기준판처럼 506개 통과·5개 실패, 실패 목록 diff 종료 0(`v7-final-standard.log`, `v7-final-standard.diff`). 최종 제품 코드에서 앱 단독 전체를 별도로 재실행하지 않았다. 위 `v7-app.log`는 직전 후보와 기준판의 비교이며, 마지막 제품 코드의 같은 fixture 전량 수신 확인은 63개 통합 기록에 있다.
- 최종 Git 인덱스와 `python scripts/scan_private.py` 종료 0. 제품 중 변경은 앱에만 있고, `gate/tests/history_transport_app.py`는 다섯 기존 복원 시나리오의 기대 확인만 수정했다(`v7-final-private.log`).

### 보강 단언과 마지막 통합 실행

- `v7-exact-build.log` Swift 빌드 종료 0. `v7-exact.log` 통합 종료 0, 신규 31개·기존 32개 총 63개 통과. 기본 방 클립보드 전체 서식과 복사 완료 1회, 권한 실패 카드 문구, 직접 펼침 상태, 300개 방 끝까지 이동 후 마지막 본문과 상주 한도 단언을 포함한다. 앞 절의 `v7-acceptance-and-regression.log` 뒤에 이 단언들을 강화하고 다시 실행했다.
- 승인된 AT-ALD-20은 300개 방 끝까지 스크롤한 상태의 상주 한도를 검증한다. 모든 중간 카드에서 개별 응답을 기다리는 별도 실험은 수동 중단했고(`v7-strict.log`), 해당 실험은 통과 집계에 넣지 않았다. 최종 하네스는 300개 카드의 위치를 순서대로 지나 끝에 도착한 뒤 마지막 본문과 실측 한도를 확인한다.
- `refresh-count` ↔ AT-ALD-25(가) ↔ 통과 ↔ `v7-refresh-count.log`. 이 마지막 시나리오는 스레드 30개에서 선택한 스레드가 받는 범위 밖임을 먼저 단언하고, 새 글 3건 뒤 선택 스레드의 갱신마다 일반 쪽 요청 1건씩만 있었는지 대조했다. 마지막 Swift 하네스 빌드 종료 0(`v7-refresh-count-build.log`), 이 시나리오만 실행해 1개 통과·31개 미선택. 통합 실행 63개에 이 별도 시나리오 1개를 더해 총 64개 테스트 결과다.

### 최종 커밋과 교차 검토 인계

- 구현 담당 판단: TASK-01 구현·자체 시험 완료. 공개판 `hejo-autoload-public-20261125`의 커밋은 `db8a2240cefacd74b0bb466372b580490a0ed030`이고, 기준은 `570c611f11fb531a8a98eff9823348ea5c0d9f37`이다. 추적 및 미추적 변경 없는 작업본을 확인했다.
- 변경 파일 11개: `app/Sources/{ConversationModel,ConversationView,HistoryCoordinator,HistoryHTTP,HistoryProjection,NativeThreadList}.swift`, `app/Tests/HistoryAutoloadFixture.py`, `app/Tests/{HistoryAutoloadHarness,HistoryTransportHarness}.swift`, `app/Tests/HistoryTransport.sh`, `gate/tests/history_transport_app.py`. `git diff --name-only <기준>..<구현> -- gate schemas install`의 유일한 출력은 계획에서 허용한 그 gate 시험 파일이다(AT-ALD-21). 제품 문과 규약·설치 diff는 비어 있다.
- 구현 종료 시의 목록은 실제 표시가 안정된 프레임으로 읽기 위치와 요청 범위를 판단한다. 보이는 복원 슬롯은 결과가 돌아오는 동안 위치 기준을 공유하며, 이미 그린 뒤 비워진 슬롯은 마지막 측정 높이를 유지한다. 같은 화면에서 현재 보이는 본문을 순차로 받은 뒤 그 화면에 함께 반영한다.
- 마지막 제품 코드의 `bash app/scripts/test.sh`도 종료 1(`v7-exact-app.log`). 기준과 같은 `APP_TEST_OK` 17회·훅 9개 OK·다운로드 보호 통과 뒤 설정 메타데이터 보호만 실패했다. `v7-exact-settings.diff`에서 hejo 설정 폴더와 `hejo-local.json`의 메타데이터 차이를 확인했다. 파일 본문과 변경 주체는 조사하지 않았다. 이 결과로 위 앱 단독 전체 재실행 미실행 표기를 대체한다.
- 교차 모델의 커밋 줄 단위 검토 및 수락 재검증, 설치 앱 수동 확인, TASK-02 현재 명세 반영과 원격 승인 절차는 남아 있다. 구현 중 사용한 확대 300개 전량 로딩 대기 실험은 최종 시나리오 통과 근거에 포함하지 않았다.

## 8판 보완 구현 인계

공개판 `hejo-autoload-public-20261125`의 보완 커밋은 `2ffd3dfe126dcea31a008ced76ffdb8aa0af8a4f`이다. 부모는 `db8a2240cefacd74b0bb466372b580490a0ed030`이다. 위험도는 일반이며 실제 AppKit과 루프백 HTTP/WS에서 요구한 증거 수준 3을 확보했다.

| 지적 | 변경 위치와 처분 | 기록 |
|---|---|---|
| V-7 | `app/Sources/ConversationModel.swift`에서 답글 쪽이 겹치거나 커서·스냅샷으로 맞닿음을 확인하면 서버 순서대로 합친다. 떨어진 쪽으로 바뀌면 이전 묶음의 상주·복원 항목을 제거한다. 새 글은 최근 끝까지 받은 묶음에 바로 붙인다. 직접 앵커 열기는 기존 경로대로 가리킨 글 주변에서 시작한다. `app/Sources/HistoryProjection.swift`의 답글 상태와 `app/Sources/ConversationView.swift`의 표시 순서를 맞췄다. | `anchored-reopen`, `anchored-live`, `live`, `test_controller_explicit_root_and_older_page` 통과 |
| V-8 | `app/Sources/HistoryCoordinator.swift`에서 응답 뒤에도 같은 자동 대상이 필요한 경우 해당 대상에 ‘다시 시도’를 표시한다. 이전 커서를 다시 만든 때는 성공한 이전 쪽과 재구성에 쓴 쪽을 함께 반영해 이어진 범위를 보존한다. | `anchored-no-progress` 통과. 정상 HTTP 응답이 기존 범위를 그대로 반환하면 자동 요청 1회에서 멈추고 직접 재시도 후 이어 받는다. 기존 64개 통과 |
| V-9 | `app/Tests/HistoryAutoloadFixture.py`와 `app/Tests/HistoryAutoloadHarness.swift`에서 AT-ALD-28의 실제 화면 답글 조각 순서, AT-ALD-32의 시험 시계 10초와 왕복 스크롤 뒤 같은 스레드 쪽 요청 0건을 단언한다. | `anchored`, `cursor-fails` 통과. AT-ALD-14(나)와 38의 mutation 확인은 아래 로그를 참조 |

첫 통합 실행에서 65개가 통과했고 두 검사가 실패했다(`v8-acceptance.log`). 완전히 받은 짧은 스레드의 수락 기준대로 접힌 카드에서 마지막 조각을 확인하도록 AT-ALD-39를 이관했다. 서버 갱신 응답을 붙잡은 상태에서 새 WS 글이 이미 끝에 보이는지도 단언했다. 기존 명시 앵커 회귀의 기대값을 유지하기 위해 직접 열기의 앵커 창 동작을 복구했다. 두 사례를 먼저 재실행해 통과했다(`v8-exact-focused.log`).

### 최종 시나리오와 수락 시험

로그는 공개판 worktree의 `.build/autoload/` 기준이다. 아래는 보완본에서 실행한 결과다.

| 시나리오 | AT-ALD | 결과 | 로그 |
|---|---|---|---|
| `basic`, `held`, `missing` | 01–04, 17, 22(권한·본문 실패) | 통과 | `v8-final-acceptance.log` |
| `viewport`, `leave-room`, `repeat`, `growth`, `long`, `long-fail` | 05–10, 23 | 통과 | `v8-final-acceptance.log` |
| `older`, `root-only`, `root-edge` | 11–13, 19(직접 열기), 26, 37 | 통과 | `v8-final-acceptance.log` |
| `anchored`, `anchored-last`, `anchored-fail` | 14–15, 19(검색 열기), 27–28 | 통과 | `v8-final-acceptance.log` |
| `evicted`, `prefetch-eviction`, 기존 `view`·`view-long`·`view-cycle`·`view-root`·`view-root-owner` | 16, 36 | 통과 | `v8-final-acceptance.log` |
| `legacy`, `budget`, `delete`, `priority` | 18, 20, 22(삭제), 24 | 통과 | `v8-final-acceptance.log` |
| `refresh-fails`, `refresh-count`, `thread-pages` | 25, 29 | 통과 | `v8-final-acceptance.log` |
| `cursor-context`, `cursor-expired`, `cursor-far`, `cursor-fails` | 30–32 | 통과 | `v8-final-acceptance.log` |
| `retry`, `retry-outside`, `retry-fails` | 33–34 | 통과 | `v8-final-acceptance.log` |
| `anchored-reopen` | 38 | 통과. 최신 50개 ID 순서, 중간 묶음 본문 상주 0개, 위쪽 한 쪽이 붙은 100개 ID 순서를 확인 | `v8-final-acceptance.log` |
| `anchored-live`, `live` | 35, 39 | 통과. 중간 묶음에서 새 글 미표시, 끝까지 받아 연속 표시, 짧은 스레드에 새 글이 즉시 붙는 경우를 확인 | `v8-final-acceptance.log` |
| `anchored-no-progress` | V-8 추가 회귀 | 통과 | `v8-final-acceptance.log` |
| `git diff --name-only 570c611..HEAD -- gate schemas install` | 21 | 승인된 기존 시험 `gate/tests/history_transport_app.py` 한 개 | Git 범위 검사 |

### 실행 결과

| 명령 | 종료 코드와 결과 | 로그 |
|---|---|---|
| `bash app/Tests/HistoryTransport.sh`, 같은 명령에 `--legacy` | 두 빌드 모두 0 | `v8-exact-build.log`, `v8-exact-legacy-build.log` |
| `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py -v --basetemp=<짧은 임시 경로>` | 0. 기존 64개와 추가 3개 모두 통과 | `v8-final-acceptance.log` |
| 독립 하네스 사본으로 `anchored-reopen` 및 `anchored-last` 실행 | 1. 두 변이를 각 기대 단언이 검출했다. db8a224의 모델과 화면을 사용한 사본은 ‘AT-ALD-38 latest reply order’에서 실패했다. 목록 끝에서 글 기준점을 사용하지 않는 사본은 ‘AT-ALD-14 next page position’에서 실패했다. 두 변이는 같은 별도 바이너리에 넣었고 해당 동작을 각각 검증했다. | `v8-mutation-build.log`, `v8-mutations.log` |
| `bash scripts/test.sh` | 1. pytest 506개 통과·기존 5개 실패. 기준 실패 ID 목록 diff 0. 후속 게이트웨이·앱 단계는 이 명령에서 미실행 | `v8-exact-standard.log`, `v8-exact-standard-failures.diff` |
| `python3 scripts/scan_private.py`(임시 `HERMES_HOME`) | 0 | `v8-exact-private.log` |
| `git diff --check`, 커밋 범위와 작업본 검사 | 0. 이번 커밋은 위 앱 파일 6개를 변경 | Git 검사 |

### 검토와 푸시 전 남은 조건

- 설치 앱 수동 확인 M-ALD-01·02, 앱 단독 전체 시험과 설정 메타데이터 보호 원인 조사는 이번 판에서 실행하지 않았다.
- `git ls-remote github refs/heads/main`은 `c22e6774604398f84351d69dd926ba3510d31aa2`를 반환했다(`v8-remote-read.log`). 로컬 원격 추적 tip과 같으며 새 구현과의 공통 조상은 `570c611f11fb531a8a98eff9823348ea5c0d9f37`이다. `github/main`을 포함하는 후보의 통합과 전체 재검증 후 TASK-02 및 푸시 승인 절차를 진행해야 한다.

## 9판 보완 구현 인계

공개판 `hejo-autoload-public-20261125`의 통합 커밋은 `b2912252f7113d6307545e5df592c98bd6ffe7f0`이다. 구현 `37e8a9f58b949f49504d244d8c365446985c81e8`과 원격 `c22e6774604398f84351d69dd926ba3510d31aa2`를 부모로 둔다.

| 지적 | 변경 위치와 처분 | 증거 |
|---|---|---|
| V-10 | `app/Sources/ConversationModel.swift`는 서버 쪽을 받기 전에 이번 연결의 실시간 ID를 순서대로 보관한다. 스레드 요약의 원문 ID가 그 목록에 있을 때 실시간 답글을 원문과 이어진 범위로 표시한다. `app/Sources/HistoryCoordinator.swift`는 이 스레드를 펼칠 때 선택 갱신에 쪽 요청을 맡긴다. `app/Tests/HistoryAutoloadFixture.py`와 `app/Tests/HistoryAutoloadHarness.swift`에 AT-ALD-40을 옮겼다. | 실제 AppKit과 루프백 HTTP/WS의 `live-new-thread`에서 클릭 전 원문·마지막 답글, 펼친 뒤 두 답글의 전송 순서, 기존 선택과 쪽 요청 상한을 확인했다. `v9-focused.log` 종료 0. 판정을 끈 별도 진단은 클릭 전 답글 조각 단언에서 실패했다. `v9-liveness-mutation.log` 종료 1. |
| V-11 | `git fetch github main` 뒤 `git merge --no-ff --no-edit github/main`으로 원격 기준의 4커밋을 충돌 없이 포함했다. | `v9-fetch.log`, `v9-remote.log`. `git merge-base --is-ancestor github/main HEAD` 종료 0. |

중간 묶음을 연 스레드에 실제로 답글을 보냈다. 더 최근 답글 수가 131로 남아 있을 때 모델의 전송 대기 항목과 서버가 확인한 본문을 각각 관측했다. 두 시점 모두 해당 글 조각은 화면에 없었다. 이 동작은 관측만 했다. `v9-send-observation.log` 종료 0.

### 검증 진행 기록

로그는 공개판 worktree의 `.build/autoload/`에 있다. 위험도는 일반이고 요구 증거는 수준 3이다. 통합 커밋에서 일반·전량 수신 하네스 빌드가 각각 종료 0이었다(`v9-build.log`, `v9-legacy-build.log`). 임시 Hermes 홈을 사용한 개인값 검사와 `git diff --check github/main..HEAD`도 종료 0이었다(`v9-private.log`). `git diff --name-only github/main..HEAD -- gate schemas install`은 허용된 `gate/tests/history_transport_app.py`만 반환했다.

시스템 임시 볼륨의 공간 부족으로 중단된 실행은 최종 결과에서 제외한다. 작업 볼륨을 임시 경로로 사용한 일반 시험은 기준과 통합본 각각 543개 통과·6개 실패였고 실패 ID 목록이 같았다(`v9-volume-baseline-standard.log`, `v9-volume-standard.log`, `v9-volume-standard-failures.diff`). 이 실행에서 검사기의 합성 절대 경로 단언은 짧은 시스템 임시 경로에서 양쪽 모두 통과했다(`v9-private-symlink-baseline.log`, `v9-private-symlink-candidate.log`). 최초 일반 시험의 한쪽에서만 실패한 Discord 시나리오 `AT-HD-46`은 분리 실행 시 원격 기준과 통합본에서 각 3회 모두 동일한 프레임 수 단언으로 실패했다(`v9-discord-baseline-repro.log`, `v9-discord-candidate-repro.log`).

기존 기록 시험 중 `long-fail`과 `budget`이 늦어진 통합 실행은 66개 통과·2개 시간 초과였다(`v9-volume-acceptance.log`). 같은 통합 커밋에서 두 시나리오만 다시 실행해 모두 통과했다(`v9-focused-previous.log`). 최종 통합 시험과 앱 단독 비교 결과는 아래에 있다.

### 기록 하네스와 일반 시험 최종 실행

- 통합 커밋에서 `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py -v`가 종료 0이었다. AT-ALD-40 시나리오를 포함해 68개가 통과했다. `v9-complete-acceptance.log`
- 시스템 임시 공간이 확보된 뒤 `bash scripts/test.sh`를 짧은 시스템 임시 경로에서 다시 비교했다. 기준은 543개 통과·6개 실패, 통합본은 544개 통과·5개 실패였고 둘 다 종료 1이었다. 공통 실패 5개 외 차이는 기준에서만 실패한 Discord `AT-HD-46` 하나다. 이 시험은 처음 비교에서 반대로 통합본에서만 실패했고, 위 분리 실행에서는 두 버전에서 각 3회 같은 단언으로 실패했다. `v9-complete-baseline-standard.log`, `v9-complete-candidate-standard.log`, `v9-complete-standard-failures.diff`

### 앱 단독 시험 최종 비교

`bash app/scripts/test.sh`는 원격 기준과 통합본 모두 빌드·서명 후 기본 앱 시험까지 통과했다. 임시 사용자 폴더의 첫 네트워크 fixture에서 자격 증명 저장 상태 오류와 시간 초과가 발생해 두 실행 모두 종료 1이었다. 실패 표식과 설정·다운로드 메타데이터 보호 검사 결과의 차이는 없었다. `v9-volume-baseline-app.log`, `v9-complete-app.log`, `v9-complete-app-failures.diff`

같은 두 바이너리에서 네트워크 fixture부터 나머지 명령 13개를 각각 실행했다. 양쪽 모두 종료 0이었다. 자격 증명 접근이 필요한 네트워크와 대화 fixture는 임시 LocalStore 및 시험 계정을 사용했고, 네트워크 fixture의 계정 정리 검사도 통과했다. 다른 fixture는 임시 사용자 폴더를 그대로 사용했다. `v9-complete-baseline-app-remaining.log`, `v9-complete-app-remaining.log`

### 작업본과 남은 확인

기준 비교용 임시 worktree를 제거했다. 구현 worktree에는 추적·미추적 변경이 없다. 읽기 명령으로 확인한 `github/main`의 tip은 여전히 `c22e6774604398f84351d69dd926ba3510d31aa2`이고, 통합 커밋의 조상이다. `v9-baseline-cleanup.log`, `v9-remote.log`

독립 검증, TASK-02, 설치 앱 수동 확인 M-ALD-01·02, 최종 푸시 승인 절차가 남아 있다.

## 10판 보완 구현 인계

6차 판정 V-12의 10판 지시를 적용했다. 시작 커밋은 `b2912252f7113d6307545e5df592c98bd6ffe7f0`이고, 시작 시 `git fetch github main`이 확인한 원격 tip은 `c22e6774604398f84351d69dd926ba3510d31aa2`다. 위험도는 일반이고 요구 증거는 수준 3이다.

AT-ALD-41은 AppKit의 작성 영역에서 실제로 답글을 보내고 루프백 문의 WebSocket 확인을 붙잡았다가 푼다. 보내기 중에는 최신 50개 뒤의 대기 조각을, 확인 뒤에는 같은 화면 위치의 확정 조각과 두 시점의 전체 순서를 검사한다. 9판의 일회성 전송 관측을 이 수락 시험으로 대체했다.

첫 단독 실행은 통과했다(`v10-focused.log`). 첫 통합 실행은 68개 통과·1개 실패였으며 AT-ALD-41의 확인 뒤 위치가 실패했다(`v10-acceptance.log`). 답글 ID를 전송 전후에 연결하는 첫 보완 뒤에도 단독 반복에서 505pt가 537pt로 이동했다(`v10-final-focused-2.log`). 이후 최초 확인 기준점을 한 번 적용하는 방식에서도 505pt가 444pt로 이동했다(`v10-position-focused-2.log`). 최종 구현은 아래처럼 목록의 위치 반영이 끝날 때까지 같은 기준점을 유지한다.

일반 스크립트 첫 실행에서 추가로 실패한 Discord 웹훅 두 경우는 원격 기준과 후보에서 분리 실행해 각각 통과했다(`v10-discord-baseline.log`, `v10-discord-candidate.log`). 같은 환경에서 원격 기준과 후보의 일반 스크립트를 재실행한 결과, 양쪽 모두 544개 통과·5개 실패였고 실패 ID diff가 비어 있다(`v10-compare-baseline.log`, `v10-compare-candidate.log`, `v10-compare-standard.diff`). 이 스크립트는 양쪽 모두 기존 문 pytest 실패에서 종료 1이었다.

### 최종 구현과 검증

공개판 `hejo-autoload-public-20261125`의 V-12 보완 커밋은 `5a4b3f797be9b41ea084dd6e3dbef2a4591d5af7`이다. 부모는 `b2912252f7113d6307545e5df592c98bd6ffe7f0`이다.

| 변경 파일 | V-12 처분 |
|---|---|
| `app/Sources/ConversationController.swift`, `app/Sources/HistoryCoordinator.swift` | 답글 전송에 앞서 미수신 답글이 있으면 같은 조정자에서 앵커 없는 열기를 완료한다. 기존 전송과 대상 확인을 이어가며, 전송 대기 글에 기존 목록 스크롤을 요청한다. |
| `app/Sources/ConversationModel.swift` | 미수신 최신 답글 판정과 기존 답글 쪽 합치기를 사용한다. 서로 떨어진 중간 답글 쪽은 최신 쪽으로 교체된다. |
| `app/Sources/ConversationView.swift`, `app/Sources/NativeThreadCard.swift`, `app/Sources/NativeThreadList.swift` | 전송 대기·확정 조각을 동일한 클라이언트 메시지 ID로 찾아 기존 스크롤 기준점을 유지한다. 확인 전 레이아웃의 보정은 무효화하고, 목록이 안정된 뒤 정상 읽기 위치 처리로 돌아간다. |
| `app/Tests/HistoryAutoloadFixture.py`, `app/Tests/HistoryAutoloadHarness.swift` | 실제 전송을 확인할 때까지 기다린 뒤 루프백 문의 처리를 풀어 AT-ALD-41 두 시점을 검증한다. 전송 중 조각과 확정 조각의 화면 위치 및 화면 조각 ID 순서를 각각 단언한다. |

| 실행 | 결과 | 로그(`.build/autoload/`) |
|---|---|---|
| `bash app/Tests/HistoryTransport.sh`, 같은 명령에 `--legacy` | 두 빌드 모두 종료 0 | `v10-settled-build.log`, `v10-settled-legacy-build.log` |
| AT-ALD-41 단독 반복 5회 | 모두 종료 0 | `v10-settled-focused-1.log`부터 `v10-settled-focused-5.log` |
| `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py -v` | 종료 0, 69개 통과 | `v10-settled-acceptance.log` |
| 최종 커밋의 `bash scripts/test.sh` | 종료 1. 544개 통과·기준과 같은 5개 실패. 실패 ID 비교 종료 0 | `v10-commit-standard.log`, `v10-commit-standard.diff` |
| `python3 scripts/scan_private.py`(임시 Hermes 홈), `git diff --check` | 모두 종료 0 | `v10-settled-private.log`, Git 확인 |

커밋 전 다시 받은 원격 tip은 이전과 같은 `c22e6774604398f84351d69dd926ba3510d31aa2`이고 후보의 조상이다. `app/scripts/test.sh` 단독 실행은 지시에 따라 생략했다. 원격 tip 대비 `gate`, `schemas`, `install`의 유일한 차이는 앞서 허용한 `gate/tests/history_transport_app.py`다. 10판 커밋은 앱 파일 8개에 한정했다. 작업본이 깨끗하고 기준 비교용 임시 worktree를 제거했다. `v10-fetch.log`, `v10-remote.log`

독립 검증과 TASK-02, 설치 앱 수동 확인 M-ALD-01·02, 최종 푸시 승인 절차가 남아 있다.
