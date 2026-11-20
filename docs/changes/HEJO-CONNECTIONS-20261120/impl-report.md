# HEJO-CONNECTIONS 구현 인계

## 받은 범위와 현재 상태

- 설계: [handoff.md](handoff.md), design 3판과 계획 검토 3회차 APPROVED(`2776ab1`). 제품 기준 `1ca3f27`, 운영 저장소 기준 `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`.
- 구현자 판단: TASK-02~04 범위 구현·자체 시험 완료, 독립 검토 대기. 운영 적용·최종 완료 판정은 하지 않았다.
- 연합개발 구현·자체 시험, 고위험, 필요 증거 수준 2. 모든 갈래를 구현 담당이 직접 처리한다. 최종 독립 검토와 운영 적용은 별도다.
- 이번 범위는 TASK-02~04. 버전·배포·설치·재시작·운영 초안 변경·푸시는 범위 밖이다.

## TASK-02 문

[확인] 구현 완료, 자체 시험 수준 2. `Connections.document()`가 부분마다 읽기·변환을 원자적으로 처리하고 실패 부분만 제외한다. 묶음 설정 실패는 그 묶음 줄을 보존한다. 공유 status/apps는 요청마다 한 번, 직원별 결과와 실패 표시는 각 직원에 귀속한다.

- 변경: `gate/connection_manager.py` 부분 읽기·허용 필드·키 필터·숨김 표시·이어 하기 라벨, `gate/server.py` 전체 실패 실제 이유와 로그, `gate/connections.py` 응답 JSON 오류 구분과 undo 읽기 전용화.
- 제거: 직원 단위 통째 실패 처리, 전체 미설정 키 줄, 직원마다 apps 호출, 조회 중 purge/잠금 생성, 오류 이유를 하나로 덮는 경로.
- 의미 변경은 design 2절 그대로다. 추가 구조·공개 계약 변경 없음. 요청별 helper는 실제 오류 격리·변환 경계이며 대체 경로를 남기지 않았다.
- 새 수락 시험 `tests/acceptance/test_connections_screen.py`: AT-HC-01~08·10·11을 40사례로 구현. HTTP/모양/시간 초과 부분 실패, 직원 격리, 비밀·본문 무노출, 실제 루프백 AdminClient 실패 분류와 모든 가짜 홈 파일 hash 불변을 검사한다. AT-HC-09는 기존 연결 시험을 포함한 전체 Python 회귀로 확인했다.
- 기존 `CatalogAdmin` fixture의 켜진 묶음 설정에 `SYNTHETIC_KEY` 요구를 명시했다. 미설정 키 전체가 제거된 새 계약 아래에서 기존 보상 트랜잭션 시험의 쓰기/복원 조건과 기대값을 그대로 유지하기 위해서다.

| 실행 명령(게이트웨이 Python) | 실제 결과 | 로그(저장소 기준, 추적 안 함) |
|---|---|---|
| `python -m pytest tests/acceptance/test_connections_screen.py gate/tests/test_connections.py -q -p no:cacheprovider` (초회) | 종료 1, 57 통과·기존 보상 fixture 1 실패. 위 요구 키 누락을 보완 | `.build/connections-evidence/task02-targeted.log` |
| `python -m pytest gate/tests tests/acceptance -q -p no:cacheprovider` (초회) | 종료 1, 377 통과·4 실패. 기존 시험 경로에서 PyYAML/team-kit 경로 누락 | `.build/connections-evidence/task02-python.log` |
| 같은 전체 Python 명령(기존 로컬 시험 의존 경로와 worktree team-kit lib 지정, 임시 홈) | 종료 0, 381 통과·기존 pytest 경고 1 | `.build/connections-evidence/task02-python2.log` |
| 부분 실패 격리를 제거한 mutation, `test_hc01_03_config_isolation_and_safe_log` | 종료 1(의도대로 검출), 코드 원복 | `.build/connections-evidence/task02-mutation.log` |

정확한 로컬 환경은 추적하지 않는 `.build/connections-env.sh`에 있다. Python은 설치 facts의 `packages.venv.environment`, PYTHONPATH는 기존 시험 의존성·Hermes 소스·worktree team-kit·저장소다. 실패 기록도 보존했다. 고위험 변경의 운영 관측·실물 M1~M7은 미실행이며 TASK-05 이후다. 롤백은 이 TASK 커밋 되돌림이다.

## TASK-03 앱

[확인] 수정 전 개발 시험 도구(`.build/connections-repro/`)로 가짜 표·주소 응답·로그인 응답(아이디/비밀번호·7단계 안내)을 실제 ConnectionsWindow/NSHostingView에 넣었다. 주소 제출 자체는 `waiting` 다음 단계가 열린 채 유지됐다. 따라서 시설 저장 실패나 `waiting` 응답을 완료로 오인한 것이 원인이라는 증거는 없다.

연결 창을 기존 AppDelegate와 같은 높은 층(시험에서는 26)에 둔 뒤 기본 확인 창을 띄우면 alert 층은 8이며 뒤에 가렸다. `NSApp.modalWindow != nil`인 채 `show()`를 다시 불러도 모달은 풀리지 않았다. 첫 탐침에서 주 actor Task로 모달을 끝내려 한 것도 진행되지 않아 샘플로 `NSAlert.runModal → NSApplication.runModalForWindow` 대기를 확인하고 시험 프로세스만 종료했다. 이후 common runloop Timer로 끝내는 탐침은 종료 0으로 같은 현상을 확인했다. 창이 다시 안 열리는 재현 가능한 원인은 앱 전체 모달과 창 층의 충돌이다.

입력 sheet를 가려지게 한 상태와 요청 중 닫힘도 주입했다. 기존 `onDisappear`와 `onDismiss`가 같은 입력 정리를 중복 수행하고, 다음 단계 값도 이전 주소 값을 남긴다. 단순 `waiting`만으로 원래 운영 증상의 자발적인 창 닫힘은 재현하지 못했다. 운영 당시의 OS 인증창 사건은 미관측으로 남긴다. 수정은 design 3.3에 정한 창 층·sheet 확인·단일 닫힘 처리·요청 중 다음 단계 복원을 원래 창 소유자에서 수행한다.

증거: `.build/connections-evidence/task03-reproduction3.log`(종료 0), `task03-dismiss-race.log`(종료 0), `task03-repro-sample.txt`(첫 모달 대기 샘플). 재현 빌드 1~2차는 시험 helper 누락·잘못된 소수 리터럴로 실패했고, 고친 3~6차 산출물만 실행했다. 실제 서버나 운영 입력값은 사용하지 않았다.

### TASK-03 변경과 자체 시험

- `ConnectionModels.swift`: `unread`·`hidden_by_default` 해석, 숨긴 줄을 제외한 직원 요약, 다음 단계의 선택·입력 오류 필드.
- `ConnectionsWindow.swift`: 표 읽기 이유별 회색 문장과 직원별 마지막 표 보존, 입력 오류 상태 분리, 숨김 토글과 목록·개수·직원 점의 같은 필터. 필드의 일반 값만 미리 채우며 이전 단계의 주소·비밀번호 입력은 다음 단계에 남기지 않는다.
- 입력 표시의 소유자는 기존 `ConnectionsWindow`다. SwiftUI `.sheet`와 중복 `onDisappear`/`onDismiss` 정리를 제거하고 AppKit `beginSheet`/`endSheet` 한 경로로 교체했다. 화면 내용은 기존 SwiftUI 예외 화면을 유지했다. 입력 창은 긴 안내·옵션을 스크롤하고 저장 버튼은 아래에 고정한다. 임시 호환 경로나 새 저장 원본은 없다.
- 인증·확인은 `.normal` 층, 다시 시작·처음부터 다시 확인은 `beginSheetModal`을 사용한다. `AppDelegate.swift`의 창 층 갱신도 창 소유자의 인증·sheet 상태를 따른다. `show()`는 보이지 않는 sheet를 정리하고 창을 앞으로 가져오며, 요청 중 닫힘 뒤 도착한 다음 단계는 다시 표시한다. 인증 중에도 busy를 먼저 세워 중복 요청을 막는다.
- `ConnectionsTests.swift`: AT-HC-20~28의 가짜 프레임·실제 AppKit sheet 통합과 AT-HC-29 기존 시험. 새 시험은 표 보존·오류 분리·숨김·입력 단계 전환·요청 중 닫힘·sheet 확인·거절 시 무송신을 보호한다.
- 의미 변경은 design 3절 안이다. 내부 표시 소유권을 AppKit으로 옮긴 것은 design 3.3의 구현 선택이며 새 화면이나 구조 변경이 아니다.

| 실행 | 실제 결과 | 로그 |
|---|---|---|
| `bash app/scripts/test.sh` (게이트웨이 Python·임시 Hermes 홈) | 종료 0, AT-HC-20~29 및 기존 앱·네트워크 시험 통과, 실제 CLI 설정 메타데이터·Downloads 이름 불변 | `.build/connections-evidence/task03-app-first-pass.log` |
| 로그인 다음 단계만 강제로 닫는 별도 소스 사본 mutation | 종료 1, `AT-HC-25 waiting opens login stage`가 검출. 제품 원본은 변경하지 않음 | `.build/connections-evidence/task03-mutation.log` |

필요/도달 증거 수준은 2다. 정확한 운영 OS 인증 사건은 앞 재현 절의 미관측 범위이고, 운영 M5·M6 확인은 TASK-05 뒤다. 롤백은 앱 TASK 커밋 되돌림이며 운영 앱 사본은 바꾸지 않았다.

## TASK-04 team-kit

[확인] 구현·요청 범위 자체 시험 완료. 운영 저장소의 실제 착수 HEAD는 위 기준과 같다. 그 HEAD에서 `hejo-connections-20261120` worktree 브랜치를 만들었다. 로컬 위치는 `AGENTS.local.md`에 기록한다. 다른 작업의 main 변경은 보존한다.

운영 실행본과 기준 사본의 SHA-256 일치(모두 확인):

| team-kit 상대 파일 | 기준 SHA-256 |
|---|---|
| `lib/hermes_facility/synology_setup.py` | `58d6bc483e0090cb9889cfde3b132c3ae8525934de78bb57da1a5e04bd33a189` |
| `lib/hermes_facility/app_setup.py` | `f1dd31b34c8087da0ea7faafa94c5b5f705e11c6403407ad5d99b17b39ee8124` |
| `lib/hermes_facility/app_connect.py` | `4598709c56f52eed69eaa66079f2313365ec681371d7becc1d67bfa5fcb18849` |
| `lib/hermes_facility/connection_guides.py` | `15347bda0b8a0c5becb2695e52086b8b703ffeb5c0552ba14efecccfd13b903a` |
| `lib/hermes_facility/connection_secrets.py` | `841f51fb79855776ecd67f91c83e136ec55d7fc555be17175bccf5d345a43277` |
| `lib/hermes_packs/files_docs/files.py` | `fb306ff396ee1e0d8832d2c3f80a38ff0ce6bf1c8c54ca0f5a21acb4d5a250e7` |

원본 기록: `.build/connections-evidence/task04-baseline.json`. 운영 원본 교체·sync·restart는 하지 않았다.

### TASK-04 변경과 의미

- `synology_setup.py`: 다른 직원 연결·Drive Client에서 후보를 읽기 전용으로 찾는다. 한 연결의 주소·아이디 묶음을 유지하고 동일한 묶음만 합친다. 자기 초안·이전 설정을 먼저 쓰고, 자기 주소가 완전한 경우에만 같은 주소 묶음의 유일한 다른 출처 아이디를 보완한다. 무효 초안은 다른 출처를 조사하지 않고 주소 단계로 돌린다. 여러 완전 후보는 기존 계정 고르기 프레임과 불투명 id로 클릭 선택한다. 직접 넣기도 같은 주소 입력으로 이어진다.
- `files.py`: 기존 `nas_settings`의 주소 조건을 `address_problems`로 추출했다. 주소 단계와 파일 기능이 같은 규칙을 쓴다. 형식 밖 칸은 초안·응답에 넣지 않으며 두 주소가 함께 통과할 때만 `address`를 기록한다.
- `app_setup.py`·`app_connect.py`: 일반 칸의 아이디만 미리 채우고 비밀번호는 복사하지 않는다. 주소 수정 시 출처가 달라진 아이디와 이전 로그인 선택은 버린다. 잘못된 주소는 주소 단계로 돌아가고, Obsidian은 존재하는 보관함을 클릭으로 고르게 한다. 초안·비밀·되돌리기는 기존 `stage_values`/`undo`만 쓴다. 새 금고 키·진행 기록 형식·outcome·action id를 추가하지 않았다.
- `connection_guides.py`·`connection_secrets.py`: 기존 안내·라벨을 그 자리에서 교체했다. `docs/연결-상태.md`의 아이디 미리 채우지 않기 결정을 승인된 새 기준으로 바꾸었다.
- 기존 시험 조정: 가짜 홈의 서버 사용자 HOME도 격리하고, 엄격한 NAS 주소 정책에 맞는 가짜 host를 썼다. 완전한 자기 주소는 주소 입력 대신 로그인으로 넘어가는 새 의미를 반영했다. 줄인 안내의 새 순서·칸 이름만 맞췄고, 기존 비밀 보호·저장·복원·범위 기대값은 유지했다. 요구·수락 시험 명세·spec·design은 변경하지 않았다.

운영 Drive 자료는 `connection_table`의 칸 이름만 확인했다. 주소·아이디 값은 시험·문서에 옮기지 않았다. 발견기는 허용된 주소·사용자 이름 칸만 SELECT하고 세션·프록시 비밀·키 칸은 선택하지 않는다. SQLite는 `mode=ro`로 열고 명시적으로 닫는다. 정책에 맞는 전체 주소가 자료에 있으면 완전 후보, QuickConnect ID만 있으면 부분 후보가 된다. 운영 자료가 현재 완전 후보를 제공하는지는 미확인이다. 외부 이름 해석 요청은 없다.

### 안내 전후(현재 단계의 guide 항목 수)

| 연결 | 이전 → 이후 | 사람이 넣는 값·나머지 동작 |
|---|---|---|
| 시놀로지 완전 후보 하나 | 7 → 로그인 1 | 비밀번호, 아이디 미리 채움 |
| 시놀로지 완전 후보 여럿 | 7 → 후보 선택 1 / 로그인 1 | 후보 클릭 뒤 비밀번호 |
| 시놀로지 부분 후보 하나 | 7 → 주소 2 / 로그인 1 | 빠진 주소·비밀번호 |
| 시놀로지 부분 후보 여럿 | 7 → 주소 2 / 로그인 1 | 서로 다른 주소 칸·필요하면 아이디·비밀번호 |
| 시놀로지 자기 초안 완전 | 7 → 로그인 1 | 아이디 후보 없으면 아이디·비밀번호 |
| 시놀로지 후보 없음 | 7 → 주소 2 / 로그인 1 | 주소 두 개·아이디·비밀번호 |
| Obsidian 찾음 / 못 찾음 | 2 → 1 / 2 | 클릭 / 보관함 폴더 하나 |
| Slack 봇 | 7 → 5 | 봇·앱 로그인 열쇠 두 개, 앱 만들기 열기·설정 복사 |
| ddots Slack | 5 → 3 | 로그인 열쇠 하나, 열기·복사 |
| Notion | 4 → 3 | 로그인 열쇠 하나, 발급 페이지 열기 |
| X | 3 → 3 | 쿠키 두 개, 로그인 열기·쿠키 이름 복사 |
| Instagram | 2 → 2 | 로그인 열쇠 하나, 발급 페이지 열기 |
| Mac 앱(메일로 실측 시험) | 1 → 1 | 계정·범위·권한 클릭 |

### TASK-04 증거와 제한

새 `tests/test_connections_screen.py`는 AT-HC-40~47·49~52와 후보/수동 선택 경계를 실제 시설·CLI에 대한 36사례로 옮겼다. AT-HC-48은 기존 연결·앱·시놀로지·조립·플러그인 host 시험을 함께 실행했다. 비밀번호 이름 무조회, 조회 파일 불변, 실제 초안 작성→undo 뒤 자기 몫 제거·다른 직원/키 바이트 보존, 안내 판정표의 칸·단계·열기/복사를 검사한다. 기존 시험을 skip/xfail로 바꾸지 않았다.

| 실행 | 실제 결과 | 로그(hejo 저장소 기준) |
|---|---|---|
| 관련 시험 초회 | 종료 1, 97 통과·8 실패. 엄격 주소 검증용 가짜 정책·host, 옛 안내 순서 가정 보완 | `.build/connections-evidence/task04-initial.log` |
| 새 시험 통합 초회 | 종료 1, 111 통과·19 실패. 잘못 붙은 else와 가짜 profile.yaml 누락, 부분 후보 저장 시점을 고침 | `.build/connections-evidence/task04-targeted-fail.log` |
| 연결·앱·시놀로지·조립 관련 27개 시험 파일 | 종료 0, 448 통과 | `.build/connections-evidence/run-team.log`, 명령·cwd는 같은 이름 JSON |
| 주소 검사에서 잘못된 api_base 허용 mutation | 시험 종료 1, AT-HC-43이 검출. 별도 프로세스 주입, 제품 원본 불변 | `.build/connections-evidence/task04-mutation.log` |
| `airport-check --snapshot <worktree>` | 종료 0, boundary 382·document 0·compartments 0, 기준선 증가 없음 | `.build/connections-evidence/run-airport.log` |

추가 탐색으로 team-kit 전부도 임시 HOME에서 돌렸으나 종료 1(4993 통과·61 skip·29 실패·1 error, 58 subtests)였다. 운영 프로필·소스 도우미·문서 변환 전용 Python을 실제 사용자 HOME에서 찾는 기존 시험들이 임시 HOME과 맞지 않았다. 이 중 이번 변경으로 칸 이름이 바뀐 Notion 기대값은 수정했다. 연결 소스 도우미 시험은 worktree의 코드 파일만 임시 홈에 연결해 위 448개에 포함했다. 그 밖의 운영 프로필/문서 처리 시험을 임시 운영 값으로 재작성하거나 실제 사용자 홈으로 전환하지 않았다. 확장 전체 통과는 주장하지 않는다. 원본 로그는 `.build/connections-evidence/task04-broad-environment-fail.log`/JSON이다. 이 추가 실행은 요청 범위 AT-HC-48의 연결 회귀 통과와 구별해 검토해 달라.

바꾼 시설 가운데 `files.py`는 team-kit `__init__.py`의 파일 도구 로더가 게이트웨이에서 import한다. 나머지 다섯 파일은 connections CLI의 `app`/`secret` 명령과 그 내부 import 경로다(`connections.py`, `app_connect.py`, `app_setup.py`). CLI는 호출마다 새 프로세스지만 파일 도구의 게이트웨이 모듈 캐시는 별개이므로 TASK-05의 한가할 때 재시작 판단을 유지한다. 이번에는 운영 교체·sync·재시작을 하지 않았다.

## 검토·후속 작업

- 설계와의 목표·계약 차이: 없음. 내부 AppKit 표시 소유권 정리와 기존 프레임을 이용한 후보/보관함 고르기는 구현 세부다. 확장 team-kit 전체 시험의 환경 불일치는 위 제한으로 별도 보고한다.
- 제거 조건 있는 임시 제품 코드: 없음. 재현·mutation·실행 환경 스크립트와 로그는 추적하지 않는 `.build/`에만 있다.
- 미검증: 운영 적용·실물 M1~M7, 실제 현재 Drive 자료의 완전 후보 여부, 당시 운영 인증창의 정확한 닫힘 사건. 직원 B 초안은 그대로이고 사장이 고친 화면에서 이어 간다.
- 범위 밖 부채: 기존 문서의 Hermes 본체 묶음 설정 400과 만료 앱 undo 기록 정리는 그대로다. team-kit 확장 전체 시험에는 운영 HOME 의존이 남아 있다.
- 검토 요청: 자기 초안의 아이디 보완 예외, 부분 후보를 주소 완료로 기록하지 않는 조건, AppKit 닫힘 completion의 창 identity 검사, 표 조회 무쓰기, 실패 이유·로그의 비밀 무노출을 직접 확인해 달라. 운영 자발적 닫힘을 완전히 재현했다는 주장으로 읽지 말아 달라.
- 다음은 계획 담당의 실제 코드·시험 근거 검토다. TASK-05~07, 버전 변경·배포·설치·재시작·푸시는 이번 구현 범위 밖이다.

### 추가 수정 시험 파일의 착수 SHA-256

| team-kit 상대 파일 | 기준 SHA-256(실행본과 일치) |
|---|---|
| `tests/test_app_connect.py` | `39fc5f7556e602a3e997fab0c3a90276bb20ba925a83c0a83a6cef20b8d8c18c` |
| `tests/test_synology_app_connect.py` | `e718d6054647b004e5e5882f8f55ba730b3af89c78228f56f199f98649914c47` |
| `tests/test_connection_guides.py` | `b13e395d4e3176b499528e74f05a45d36cd7a9b6525dcde35de4745dcae4bf17` |
| `tests/test_connections_secret.py` | `8e46d7a65280a5fe2931dffbbc54c1d262281eb6777722337412aafbc7fbe5b5` |

## 최종 자체 검사와 검토 대상

| 명령 | 실제 결과 | 로그(hejo 기준) |
|---|---|---|
| `HEJO_PYTHON=<게이트웨이 Python> bash scripts/test.sh` (기존 시험 의존 경로·worktree team-kit lib·임시 Hermes 홈) | 종료 0. Python 381개·실제 게이트웨이 대역 수명주기·앱 빌드/서명·AppKit/네트워크 시험 통과 | `.build/connections-evidence/run-full.log`, `run-full.json` |
| `HEJO_PYTHON`과 같은 Python으로 `scripts/scan_private.py` | 종료 0, 개인값 검사 통과 | `.build/connections-evidence/final-scan.log` |
| `app/.build/app-tests --task32-capture <임시 증거 폴더>` | 종료 0. 기존 연결·필터와 AT-HC-20~29 통과. 화면 배치 직접 확인 | `.build/connections-evidence/task03-capture.log`, `ui/task54-hejo.png` |

TASK-04 대상 커밋은 `1c0ea8a5a6d7247c3e62e46fec4307c145baefc6`, 브랜치는 `hejo-connections-20261120`이다. 운영 저장소 HEAD에서 만든 worktree이며 실제 위치는 추적하지 않는 `AGENTS.local.md`에 있다. 검증 로그 사본은 그 worktree의 추적하지 않는 `.build/HEJO-CONNECTIONS/`에도 있다. 운영 main과 실행본은 수정하지 않았다. 기존 실행 파일·시험 10개 모두 착수 SHA-256 불변을 다시 확인했다.

TASK-02 대상 커밋은 `33814a7d9dc3831ba808981f73051886fee0ef49`다. TASK-03은 이 보고서의 최종 갱신과 함께 만든 앱 커밋을 검토한다(이 보고서를 담은 hejo HEAD). 그 커밋은 이전 TASK-02 위에 있고 제품 변경은 앱 3개 소스와 연결 시험뿐이다. 전체 로그는 위 추적하지 않는 경로에 보존했다. 푸시나 원격 포함은 확인·실행하지 않았다.

## 보완 1

### 받은 지시와 변경

기준은 hejo `4d377d689f39fbbf80abafdb18dc90be54d2429b`의 보완 지시 1·design 4판 4.1·수락 시험 명세 4판(AT-HC-53·54), team-kit worktree `1c0ea8a5a6d7247c3e62e46fec4307c145baefc6`다. 위험도 고위험, 필요 증거 수준 2다. 아래 자체 시험 기준으로 보완 구현을 마쳤으며 독립 재검토를 요청한다. 앞 절의 3판 기준 설명 중 자기 초안 우선순위와 후보 번호 라벨은 이번 4판 구현으로 대체된다.

- **V-1:** `synology_setup.prepare()`에서 자기 주소 두 개가 함께 검사를 통과할 때만 우선 출처로 쓴다. 틀리거나 불완전하면 기존 다른 직원→Drive 후보 순서를 따른다. 완전 후보 하나는 주소 두 칸을 교체하고, 여럿은 고르기, 완전 후보가 없으면 부분 후보가 제공하는 칸→검사를 통과한 자기 칸→빈 칸 순서다. 바뀐 주소에는 이전 로그인 선택을 재사용하지 않는다. `app_connect.py`의 기존 `stage_values`로 주소 완료·교체를 기록해 처음 초안 이전 상태로 되돌릴 수 있다. 자동 교체 로그인 `hint`와 여러 후보의 `input_error`는 설계 문장 그대로다. 사람이 직접 주소를 제출한 경우에는 자동 교체 안내를 붙이지 않는다.
- **V-2:** 같은 후보 고르기 경로에서 `link_host · 아이디`(아이디 없으면 `link_host`)를 표시하고 같은 라벨에는 출처 꼬리말을 붙인다. 옵션은 불투명 id와 라벨만 전달하며 비밀번호·직원 식별자를 넣지 않는다.
- **V-3:** `ConnectionsModel.perform()`이 선택한 줄의 `app_undo` 동작 라벨을 기존 확인 창에 전달한다. 진행 중은 제목·버튼이 “처음부터 다시”, 연결됨은 “마지막 연결 변경을 되돌릴까요?”·“되돌리기”다. 기존 AppKit 비동기 sheet와 취소 동작을 유지한다.

책임 자리·공개 계약·저장 형식·칸 배치는 그대로다. 설계와 달라진 점, 새 임시 제품 코드, 범위 밖 구조 변경은 없다. 후보 표시 helper는 기존 고르기 옵션을 만드는 책임만 맡는다. 수정한 두 시설은 연결 CLI가 호출마다 import하며, 이번에는 앞 TASK-04의 게이트웨이 import 파일 `files.py`를 더 고치지 않았다.

### 시험과 증거

team-kit `tests/test_connections_screen.py`에 AT-HC-53(가~다) 3사례와 AT-HC-54 1사례를 옮겼다. 각각 틀린 초안→비밀번호만 입력·초기 상태 undo, 후보 선택·오류 안내, 부분 칸 채움·주소 미완료, 후보 라벨·출처·비밀 무노출을 보호한다. 3판의 “틀린 자기 초안은 다른 출처를 조회하지 않음” 시험은 승인된 4판과 반대여서 AT-HC-53으로 교체했다. AT-HC-50의 후보 번호·아이디 숨김 기대도 승인된 라벨 규칙으로 바꿨다. 수락 시험 명세·spec·design은 수정하지 않았고 skip/xfail을 더하지 않았다.

앱 시험 한 사례에서 진행 중·연결됨 두 줄의 실제 `perform(app_undo)`를 실행하고, 실제 AppKit 확인 sheet의 제목과 버튼을 검사하고 취소한다. 모델 확인 대역으로 문구 검사를 대신하지 않았다.

| 검사 | 실제 결과 | 로그(hejo 기준) |
|---|---|---|
| 새 team-kit 시험 초회 | 종료 1, 37 통과·2 실패. 새 시험에서 기존 단계 상태 계약에 없는 `current`를 가정했다. `wait()` 계약인 사용자 입력 필요 여부로 단계 검사를 바로잡음 | `.build/connections-supplement1/team-initial.log` |
| 관련 27개 시험 파일 + AT-HC-53·54, 임시 HOME/HERMES_HOME | 종료 0, 451 통과(새 화면 시험 39사례 포함) | `.build/connections-supplement1/run-team.log`, `run-team.json` |
| V-1 mutation: 자기 값이 한 칸이라도 있으면 우선 출처로 되돌림 | pytest 종료 1, AT-HC-53(가)가 주소 칸으로 돌아가 실패. 실행 스크립트 종료 0, 원본 바이트 복구 확인 뒤 위 451개 실행 | `.build/connections-supplement1/mutation.log`, `mutation.json`, `mutation.py` |
| `airport-check --snapshot <worktree>` | 종료 0, boundary 382·document 0·compartments 0. 커밋 훅에서도 같은 검사 통과, 기준선 변경 없음 | `.build/connections-supplement1/run-airport.log`, `run-airport.json` |
| `HEJO_PYTHON=<게이트웨이 Python> bash scripts/test.sh` | 종료 0. Python 381개·게이트웨이 수명주기·앱 빌드/서명·AppKit(새 V-3 포함)·네트워크 전체 통과 | `.build/connections-supplement1/run-full.log`, `run-full.json` |
| 같은 Python으로 `scripts/scan_private.py` | 종료 0, 개인값 검사 통과 | `.build/connections-supplement1/run-scan.log`, `run-scan.json` |
| 운영 홈 주소 복구 읽기 전용 시뮬레이션 | 종료 0. 아래 제한 참조 | `.build/connections-supplement1/read-only-simulation.log`, `read-only-simulation.py` |

위 27개 파일의 정확한 목록·실행 Python·cwd는 `run-team.json`, 전체 검사의 실행 환경은 추적하지 않는 `.build/connections-env.sh`와 `run.py`에 있다. 검사한 제품·시험 파일 SHA-256은 `tested-inputs.json`에 있다. 원래 확인한 운영 원본 10개 파일의 SHA-256도 이전 착수 기록과 다시 일치했다. 앱 컴파일의 기존 동시성·미사용 값 경고와 WebKit 실행 진단은 남아 있으나 검사 실패는 없고 이 변경 경로의 새 경고는 없다.

### 운영 읽기 확인과 제한

운영 홈에서 `prepare()`와 자격 입력 칸 생성만 호출했다. 감사 hook으로 파일 쓰기·삭제·이름 변경·프로세스 실행·네트워크와 비밀 파일 열기를 차단했고, 비밀 파일을 여는 아이디 조회는 비활성화했다. 두 주소가 모두 정책 밖인 초안 1개·완전 후보 1개를 확인했으며, 메모리에서 후보 주소로 교체·`address` 완료·로그인 입력 칸 `user`/`password`로 이어졌다. 금고 파일의 실행 전후 digest가 같았다. 주소·아이디·직원 식별자는 출력하거나 복사하지 않았다. 운영 초안 저장·`app connect`는 호출하지 않았다.

따라서 운영 주소 복구와 로그인 단계까지의 형태는 읽기 확인했지만, **실제 아이디 미리 채움·비밀번호만 사람이 넣는 운영 첫 응답 전체는 확인하지 않았다.** `.env` 열기 금지를 지키기 위해 아이디 조회를 끈 영향이다. 해당 계약은 가짜 자료의 AT-HC-53(가)로 확인했다. 첫 시도는 감사 hook이 Python의 `token` 소스 모듈까지 비밀 파일로 분류해 차단했고, 소스 확장자를 구분한 뒤 위 제한을 유지한 채 통과했다. 운영 연결 자체·로그인·폴더·서버 적용·M1~M7은 후속 작업이다. 도달 증거 수준은 2이며 운영 적용 검증을 주장하지 않는다.

### 검토 대상과 다음 작업

team-kit 대상은 worktree 브랜치 `hejo-connections-20261120`의 `fe697e3b5a0805ec9ab80f63b2fcf9d3f3e53573`(부모 `1c0ea8a5`)이며 수정 경로는 시설 `synology_setup.py`·`app_connect.py`와 시험 `test_connections_screen.py`다. 앱 대상은 이 절을 담은 hejo main 커밋(부모 `4d377d6`)이며 `ConnectionsWindow.swift`·`ConnectionsTests.swift`와 이 보고서만 바뀐다. 로컬 worktree 위치는 `AGENTS.local.md`를 따른다. 증거 사본은 worktree의 추적하지 않는 `.build/HEJO-CONNECTIONS/supplement1/`에도 보존한다.

독립 재검토에서는 AT-HC-53(가)의 기존 undo 원점 보존, 부분 후보 우선 칸 채움, 실제 AppKit 확인 문구 두 상태를 확인해 달라. 새 범위 밖 부채는 없다. 운영 원본·운영 main·직원 B 초안·Hermes 본체·ddots는 수정하지 않았고 sync·재시작·버전·공개·설치 교체·푸시는 실행하지 않았다. 다음은 보완 1 재검토이며 TASK-05 이후는 별도 지시 범위다.


## TASK-05 서버 적용

### 적용 전 롤백 기록 (먼저 작성)

보완 지시 2·design 7.2·검토 2차를 기준으로 적용한다. 위험도 고위험, 필요 증거 수준 3. TASK-02~04 및 보완 1의 제품 변경·검사를 반복하지 않는다. 아래는 적용 전에 확인한 실제 값이다. `<HOME>`은 Hermes 홈, `$HOME`은 macOS 사용자 홈이다. 개인 홈 이름과 절대 경로는 쓰지 않는다.

- 대상 문 커밋: `1c6b3e2f18a3e3ceb24f01eeda8bcb042c4582a3`. 적용 전 공용 `RELEASE`: `95074cbafda3a5e16d1fd2e9a580b24abe667021`. 공용 릴리스 위치: `$HOME/../Shared/hejo`.
- 적용 전 `gateway.status` 런타임: pid `15798`, start_time 지문 `179515476080`(macOS epoch 센티초), 시작 `2026-11-20T06:06:00.800000+00:00`. 진행 중 에이전트 0·active_work 없음.
- team-kit 대상: worktree `fe697e3b5a0805ec9ab80f63b2fcf9d3f3e53573`. 실행본 `<HOME>/plugin-store/team-kit/`. 운영 저장소 main HEAD: `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`. 운영 문서가 기준 `9e68b39b`와 바이트 일치하고 이번 12개 경로에 다른 미커밋 변경이 없음을 확인했다.
- 보관 폴더: `$HOME/.cache/hejo-connections-task05-cf0fk2hu`. 실제 생성됨, 모드 `0700`. 목록·되돌리기 스크립트를 먼저 두었고, 실행본은 다음 교체 단계에서 이 폴더의 `team-kit/`에 보관하고 SHA-256 확인 후 교체한다. 원본은 아래 표다.

| 실행본 경로(`<HOME>/plugin-store/team-kit/` 아래) | 적용 전 SHA-256 |
|---|---|
| `lib/hermes_facility/app_connect.py` | `4598709c56f52eed69eaa66079f2313365ec681371d7becc1d67bfa5fcb18849` |
| `lib/hermes_facility/app_setup.py` | `f1dd31b34c8087da0ea7faafa94c5b5f705e11c6403407ad5d99b17b39ee8124` |
| `lib/hermes_facility/connection_guides.py` | `15347bda0b8a0c5becb2695e52086b8b703ffeb5c0552ba14efecccfd13b903a` |
| `lib/hermes_facility/connection_secrets.py` | `841f51fb79855776ecd67f91c83e136ec55d7fc555be17175bccf5d345a43277` |
| `lib/hermes_facility/synology_setup.py` | `58d6bc483e0090cb9889cfde3b132c3ae8525934de78bb57da1a5e04bd33a189` |
| `lib/hermes_packs/files_docs/files.py` | `fb306ff396ee1e0d8832d2c3f80a38ff0ce6bf1c8c54ca0f5a21acb4d5a250e7` |
| `tests/test_app_connect.py` | `39fc5f7556e602a3e997fab0c3a90276bb20ba925a83c0a83a6cef20b8d8c18c` |
| `tests/test_connection_guides.py` | `b13e395d4e3176b499528e74f05a45d36cd7a9b6525dcde35de4745dcae4bf17` |
| `tests/test_connections_screen.py` | 없음(새 파일, 롤백 때 제거) |
| `tests/test_connections_secret.py` | `8e46d7a65280a5fe2931dffbbc54c1d262281eb6777722337412aafbc7fbe5b5` |
| `tests/test_synology_app_connect.py` | `e718d6054647b004e5e5882f8f55ba730b3af89c78228f56f199f98649914c47` |

되돌리기는 다음 순서다. 실행본 보관본은 계속 움직이는 운영 저장소 커밋 대신 위 파일별 SHA-256을 기준으로 한다. 복원 스크립트는 모든 보관본을 먼저 검사하고 같은 디렉터리 임시 파일→이름 바꾸기로 복원한다.

```sh
python3 "$HOME/.cache/hejo-connections-task05-cf0fk2hu/restore-team-kit.py"
"$HOME/.hermes/bin/hermes-connections" status --json
"$HOME/.hermes/bin/hermes-connections" apps --json
# 문 적용 뒤 복구가 필요할 때만, 기록한 이전 릴리스를 별도 worktree로 꺼낸다.
git -C "$HOME/paseo-work/hermes-hejo" worktree add --detach "$HOME/.cache/hejo-connections-task05-cf0fk2hu/gate-rollback" 95074cbafda3a5e16d1fd2e9a580b24abe667021
"$HOME/.cache/hejo-connections-task05-cf0fk2hu/gate-rollback/install/hejo-release"
"$HOME/.hermes/bin/hermes-connections" gateway restart --json
# 앱은 이번에 바꾸지 않으므로 복원 대상 없음.
```

복원 읽기 명령의 값은 화면에 출력하지 않고 종료 코드·JSON 여부·개수만 남긴다. 재시작은 위 명령만 쓰며 BUSY일 때 강제하지 않는다. 운영 적용 결과는 아래에 이어 기록한다.


### TASK-05 적용 결과와 관측

자체 판단: **서버 적용 완료, 독립 검토 대기.** 필요·도달 증거 수준은 3이다. 아래 명령은 실제 운영 실행본·공용 릴리스·게이트웨이에 실행했다. 기존 대역 시험 결과를 운영 실행 증거로 대신하지 않았다.

1. 파일 11개(lib 6·tests 5)를 다시 SHA-256 대조했다. 기존 10개는 착수 기준과 일치하고 새 파일 1개는 없었다. 전부 0700 보관 폴더에 복사·검사한 뒤 각 실행본과 같은 폴더에 임시 파일을 쓰고 이름 바꾸기로 교체했다. 교체 뒤 11개 모두 `fe697e3b`의 바이트와 일치했다. `files.py`는 게이트웨이가 import하므로 아래 재시작으로 함께 적용됐고, 나머지 시설은 CLI가 호출마다 읽는다.
2. 교체 직후 실제 `status`·`apps`가 성공했다. 각각 직원 6명이며 앱 목록은 설치 앱 80개·서비스 1개다. 응답 원문·계정·주소는 로그에 남기지 않았다. 금고는 교체 전후 digest가 같았다.
3. 운영 main에서 `./sync`가 1589개 파일을 수집했고 토큰 경고는 없었다. 기존 미커밋 13개 경로를 사전 보관·바이트 대조했고 수집 후에도 모두 같아 복원할 파일이 없었다. `docs/연결-상태.md`는 기준 `9e68b39b`와 같음을 다시 확인하고 worktree 판으로 반영했다. `./airport-check`도 통과했다.
4. 운영 저장소 커밋은 `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`(부모 `9e68b39b`)다. team-kit 11개·운영 연결 문서 1개만 `git commit --only`로 커밋했고 모두 검토 worktree 판과 일치한다. 기존 13개 변경의 바이트·Git 상태를 보존했다. `./sync`가 추가로 모은 owner 사본 1개는 이 커밋에 넣지 않고 미커밋으로 남겼다.
5. `install/hejo-release` 기본 대상으로 문을 적용했다. 공용 `RELEASE`는 `1c6b3e2f18a3e3ceb24f01eeda8bcb042c4582a3`, 공용 `gate/` 19개 파일(시험·캐시 제외)이 그 커밋과 정확히 같다. 적용 전 릴리스의 `gate/`도 기록한 이전 커밋과 같음을 확인했다. 이 보고서를 담은 후속 커밋은 보고서만 바꾸며, 이미 적용한 릴리스를 다시 실행하지 않는다.
6. 지정된 `hermes-connections gateway restart --json`만 한 번 실행했다. 종료 0, `outcome=done`, `reason=OK`, 채널 7개 재연결이다. BUSY가 없어 10분 대기·재시도는 하지 않았다. 새 pid `31964`, start_time 지문 `179516510456`, 시작 UTC `2026-11-20T08:58:24.560000+00:00`으로 이전 pid·시작과 다르다. 공식 런타임은 살아 있고 최신이며 hejo 6개 행 모두 새 pid·시작 지문의 `connected`다.
7. `gateway.log`의 새 `Starting Hermes Gateway...` 표식 뒤 `✓ hejo connected` 6개를 확인했다(서버 시각 17:58:42~17:58:45). 포트 바인딩 주소를 직접 쓰는 전용 로그 줄은 현재 구현에 없으므로, 같은 새 pid가 TCP `47820`을 LISTEN하는 것을 `lsof` 종료 0으로 대조했다. 직원 식별자·주소가 있는 원문 대신 사건·시각만 증거에 남겼다. 실제 채널·문 연결은 확인했으므로 복구 조건에 해당하지 않았으며 운영 롤백은 실행하지 않았다.
8. 재시작 뒤 `status`·`apps`도 종료 0·JSON·직원 6명·앱 80개와 서비스 1개를 다시 확인했다. 실행본 SHA-256·릴리스도 그대로다. 운영 금고가 재시작 전 sync 사본과 같음을 digest로 확인했다. 직원 B 초안은 읽기 명령으로만 접했으며 `app connect`·undo·연결 상태 쓰기는 하지 않았다.

### TASK-05 실행 기록

로그는 모두 이 저장소 기준 `.build/connections-task05/`에 있다. 실제 값이 있는 CLI 원문·sync 출력 경로는 복사하지 않고 종료 코드·JSON 여부·개수·검사 결과만 기록했다. 보관 폴더의 `evidence/`에도 같은 기록을 보존한다.

| 명령·검사 | 실제 종료 코드·결과 | 로그 |
|---|---|---|
| 런타임·기준 SHA-256·운영 main/문서·자기 경로 사전 검사 | 0, 진행 중 0·기존 10개 일치·새 파일 1개 없음 | `preflight.log`, `preflight.json` |
| 보관·이름 바꾸기 교체·교체 SHA-256 | 0, 11개 일치·보관본 검증·금고 불변 | `apply-team.log`, `team-applied.json` |
| 실행본 `hermes-connections status --json`, `apps --json` | 각각 0, JSON·직원 수 확인 | `after-team.log`, `after-team.json` |
| 운영 main `./sync` | 0, 1589개·토큰 경고 없음·기존 13개 변경 보존 | `sync.log` |
| 운영 main `./airport-check` | 0, boundary 381·document 0·compartments 0, 기준선 변경 없음 | `airport.log` |
| 운영 main `git commit --only` 초회 | 1. 새 시험 파일이 Git에 아직 등록되지 않은 pathspec 오류. 읽기용 `--dry-run`에서도 같은 오류를 확인했다. 제품·읽기·토큰 검사의 실패는 아니며 HEAD는 그대로였다 | `operations-commit-initial.log`, `commit-preflight.log` |
| 새 자기 시험 파일만 `git add` 후 운영 main `git commit --only` | 0, 위 운영 커밋·12개 자기 경로만·검토본 일치 | `operations-commit.log`, `operations-recorded.json`, `operations-preserved.json` |
| `install/hejo-release` | 0, RELEASE·gate 19개 일치 | `release.log`, `release.json` |
| `hermes-connections gateway restart --json` | 0, 첫 시도 done·채널 7개 재연결 | `restart-command.log`, `restart-1.json` |
| 새 런타임·hejo 로그·문 포트·실행본 검사 | 0, 새 pid·hejo 6개 연결·LISTEN | `post-check.log`, `runtime-after.json`, `hejo-log-proof.json`, `applied-inputs.json` |
| 재시작 뒤 `status --json`, `apps --json` | 각각 0, JSON·직원 수 확인 | `after-restart.log`, `after-restart.json` |
| 운영 금고·기존 미커밋 보존 검사 | 0, sync 전후 기존 변경과 재시작 전후 금고 일치 | `state-preservation.json`, `operations-preserved.json` |
| 같은 게이트웨이 Python으로 `scripts/scan_private.py` | 0, 최종 보고서 개인값 검사 통과 | `scan-private.log` |

### TASK-05 남은 범위와 검토 요청

서버 적용·CLI 읽기·게이트웨이 재연결은 실제 실행으로 확인했다. 앱 사본·버전·공개·푸시는 실행하지 않았고 Hermes 본체·ddots를 고치지 않았다. spec·design·수락 시험 명세도 바꾸지 않았다. 문 제품 코드는 이미 검토한 대상과 같으므로 전체 대역/앱 시험은 반복하지 않았고, 보고서 개인값 검사도 통과했다.

M1~M7, 운영 아이디 자동 채움(M5), 직원 A의 오류 원인 로그(M2)는 남아 있다. 새 앱 설치 전 0.2.1 화면의 옛 오류 문구는 남는다는 인계 조건도 그대로다. 포트 바인딩 전용 로그의 부재를 연결 실패와 혼동하지 않도록 hejo 시작 사건·같은 pid의 수신·공식 런타임을 함께 검토해 달라. 다음은 TASK-05 적용 근거의 독립 검토, 그 뒤 별도 지시로 TASK-06 0.2.2 준비다.


## TASK-06 앱 0.2.2 공개 후보 준비

받은 지시는 handoff 보완 지시 3과 HEJO-IMESSAGE 보완 지시 5의 선례다. 자체 판단은 **후보 준비·자체 검증 완료, 독립 재검토 대기**다. 고위험(공개 배포물), 필요·도달 증거 수준 2. 실제 공개·푸시·업데이트 설치·M1~M7은 미실행이다.

### 후보와 준비물

- 착수 main `92591ea1f9a2e1743f49b7010295c355033c5c3b`에서 버전 커밋 `ee75b74cb51fa28e28a505dc658672d8be2104a3`을 만들었다. `app/Resources/Info.plist`를 0.2.2·빌드 4로 올리고 `tests/acceptance/test_ship.py`의 현재 버전 단언 한 줄만 함께 바꿨다. 제품 동작 코드는 그대로다. 수락 명세·spec·design을 고치지 않았고 이전 작업의 버전 기록은 유지했다.
- 공개 기준 main은 위 버전 커밋이다. 새 public `0cc0828d949d4efb2bf7e98b6f7548508b0a5797`, 부모 `363bcc021aff018ff0e62e1d2265717939bf61c8`, 트리 `441ad3633170807ccf6f06408ee5512c39acd012`다. 생성 당시 main/public 트리가 같고 기존 공개 계보에 정확히 한 커밋만 더해 개인 개발 이력은 들어가지 않았다. 이 보고서는 후속 문서 커밋이며 후보를 다시 만들지 않는다.
- `install/hejo-publish`의 두 작성자 조회는 선례의 오프라인 gh 대역으로 기존 public 작성자 정보를 재사용했다. 두 호출 모두 `network:false`다. 원격 Git·실제 gh·curl/wget을 차단한 환경에서 진행했고 차단된 원격 시도도 없었다. GitHub 조회(ls-remote 포함)·게시·push는 실행하지 않았다.
- `05107d59a23c27a4dea946c566b00d7e3df81696`의 작성 중 표시 코드가 포함됐다. 새 public의 `gate/adapter.py`·`gate/imessage.py`가 그 커밋과 바이트 단위로 같다. 공개 worktree 개인값 검사도 통과했다.
- 준비물: `.build/release-0.2.2/prepared.json`, `.build/release-0.2.2/hejo-0.2.2-arm64.zip`. 압축 SHA-256은 `46e9cae4c5ec9edd1decedc2af8aa32614b0b9109e81808e83b1f65dc0c87a85`다. 앱의 BuildInfo는 위 트리·`dirty=false`이며 압축을 풀어 실행 파일 동일·버전·빌드·코드 서명·업데이트 서명을 다시 확인했다.
- 기존 키체인 업데이트 키를 재사용했다. 새 키 생성·setup·키 내보내기는 하지 않았다. 준비물·압축 앱·이전 0.2.1 준비물·현재 설치본의 업데이트 공개 키가 같고, 설치본 0.2.1·빌드 3보다 버전과 빌드가 모두 크다. 허용된 기본 빌드 프로세스만 Google 비밀 입력을 읽었고 내용은 직접 열거나 출력·로그에 기록하지 않았다. 시험 빌드는 기존 절차대로 비밀 주입을 생략하고, 시험 뒤 같은 깨끗한 트리에서 배포용 기본 빌드를 다시 했다.

### TASK-06 검증 기록

대상은 위 public/트리이며, 명령·cwd·종료 코드·입력 트리 불변 여부는 `.build/release-0.2.2-work/`의 JSON에 있다. 아래 로그 이름도 그 폴더 기준이다.

| 검증 명령·대상 | 실제 결과 | 로그 |
|---|---|---|
| `install/hejo-publish` (로컬 작성자 캐시 대역) | 0, 부모·트리 일치·개인 이력 배제·작성 중 코드 포함 | `publish-local.log`, `publish-local.exit`, `snapshot.json`, `offline-gh.jsonl` |
| 같은 게이트웨이 Python `scripts/scan_private.py --repo <public-worktree>` | 0, 실제 공개 트리 검사 | `public-private.log`, `public-private.exit`, `public-private-final.log` |
| `HEJO_PYTHON=<게이트웨이 Python> bash scripts/test.sh` (임시 HERMES_HOME·가짜 명부) | 0, Python 381개·게이트웨이 수명주기·앱/네트워크/훅 전체 통과. 설치 시험과 AT-HI-37 포함 | `full.log`, `tests-result.json` |
| 같은 앱 시험 바이너리 반복 3회(각각 임시 홈) | 각각 0·APP_TEST_OK, 입력 트리 불변 | `app-repeat-1.log`~`app-repeat-3.log`, `verification-progress.json` |
| 옛 문 `aeaa652` + 새 앱 `test_update_compat.py` (선례의 임시 시험 원본) | 0, 1 passed·AT84_OLD_GATE_NEW_APP_PASS, 실제 루프백 인증·통신·가짜 차례 | `legacy-aeaa652.log`, `tests-result.json` |
| `bash app/scripts/build.sh` (기본 배포 빌드) | 0, 버전 0.2.2·4, BuildInfo 트리 일치·dirty false | `default-build.log`, `prepare-progress.json` |
| 같은 게이트웨이 Python `install/hejo-ship prepare --output .build/release-0.2.2/` | 0, 공개 커밋·트리·버전·빌드·압축 지문 일치 | `prepare.log`, `final-verification.json` |
| `ditto -x -k` 뒤 `codesign --verify --deep --strict <unpacked-app>` | 각각 0 | `extract.log`, `archive-codesign.log` |
| Sparkle `sign_update --account <existing account> --verify <archive> <prepared public signature>` | 0, 기존 키 재사용 | `archive-sparkle.log` |
| 별도 Python Ed25519 공개 키 검증·연속성·보존 검사 | 0, 압축 서명·SHA-256 검증, 설치본 메타데이터·운영 식별자 불변 | `independent-check.log`, `independent-check.json` |
| 실제 CLI 설정 lstat·실제 다운로드 이름 전후/최종 검사 | 모두 0, 내용 미조회·메타데이터/이름 불변 | `settings-before/after/final.log`, `downloads-before/after/final.log` |
| 같은 Python `scripts/scan_private.py` | 0, 후보 기준 main 검사 | `main-private.log` |
| 같은 개인값 검사(후속 보고서 포함)·`git diff --check` | 각각 0 | `report-private.log`, 최종 diff 확인 |

전체 검증 중 입력 커밋·트리를 바꾸지 않았다. 새 알고리즘·인증 조건을 바꾸지 않았으므로 추가 mutation은 하지 않았다. 기존 Swift 경고를 억제하거나 범위 밖 코드를 고치지 않았다. `final-verification.json`·`independent-check.json`이 준비물과 실제 검증 결과를 연결한다. 후속 보고서 개인값 검사와 최종 diff 검사도 통과했다.

### TASK-06 운영 보존과 인계

설치된 앱 사본은 교체하지 않았고 메타데이터도 그대로다. 공용 RELEASE `1c6b3e2f18a3e3ceb24f01eeda8bcb042c4582a3`와 게이트웨이 pid `31964`·시작 지문도 그대로다. 운영 홈·공용 릴리스·운영 저장소·Hermes 본체·ddots를 고치는 명령, 재시작, 실제 메시지 발송은 실행하지 않았다. 실제 공개·업데이트 설치와 M1~M7은 사장 실행 뒤 확인한다. GitHub의 현재 태그·브랜치는 조회하지 않았다.

사장용 공개 명령(미실행, 검토·푸시 승인 뒤 사장이 서버에서 실행):

```sh
install/hejo-ship publish --approve-commit 0cc0828d949d4efb2bf7e98b6f7548508b0a5797 --prepared .build/release-0.2.2/prepared.json
```

푸시 대상은 이 저장소의 `github` 원격 `main` 브랜치, 커밋 `0cc0828d949d4efb2bf7e98b6f7548508b0a5797`(로컬 `public`)이다. 개인 이력이 있는 로컬 `main`은 푸시하지 않는다. 실제 저장소 경로는 인계 상태 블록에 적는다. 이 대상 기록은 푸시 승인이 아니며 독립 재검토 뒤 사장이 플러그인 화면에서 승인한다. 다음 담당은 후보·서명 근거를 재검토하고 TASK-07 실물 확인으로 이어 간다.
