## 구현 인계 · HEJO-OWNER-PROFILE-20261125

- **상태** · TASK-01 착수 보류. 계획 검증 2회차에서 승인된 [인계서 2판](handoff.md)을 확인했다. 위험도 일반, 요구 증거 수준 3, 연합개발. 목표는 문에서 사장 이름·사진을 저장하고 앱·외부 채널·직원 맥락에 적용하는 것이다.
- **작업 위치 충돌** · 호스트는 `role-workflow/43-ea7efaba` worktree만 수정하고 그 브랜치에 커밋하라고 지정했다. 실제 HEAD는 `452821b93a7370a73863c649e8474af078fe3016`이다. 인계서 9절과 이번 지시는 `github/main`의 `c22e6774604398f84351d69dd926ba3510d31aa2`에서 `AGENTS.local.md`에 지정된 새 공개 worktree `hejo-owner-profile-public-20261125`를 사용하라고 한다. 그 공개 worktree 및 동명 브랜치는 아직 없다.
- **실제 차이** · 두 기준의 `git merge-base HEAD github/main`은 종료 1(공통 조상 없음). 호스트 기준에는 TASK-01이 수정할 `gate/discord.py`와 TASK-02가 본뜰 `app/Tests/HistoryTransportHarness.swift`가 없고 `gate/adapter.py`, `gate/server.py`도 다르다. 증거는 호스트 worktree의 `.build/owner-profile/worktree-check.log`에 있다.
- **권고 및 대안** · 계획 담당이 공개 기준의 별도 worktree를 구현 대상으로 호스트 인계에도 명시해 두 작업 위치를 일치시키는 것을 권고한다. 호스트 지정 브랜치를 유지해야 하면 계획 담당이 그 브랜치의 현재 구조를 기준으로 범위와 공개 반영 방식을 다시 확정해야 한다. 구현자는 브랜치 이동, 서로 다른 이력의 병합, 제품 변경이나 커밋을 수행하지 않았다.
- **TASK-02 선행 조건** · `git fetch github` 뒤 `github/main`이 `c22e6774604398f84351d69dd926ba3510d31aa2`임을 확인했다. 인계서 9절의 AUTOLOAD 확인 명령은 종료 1로 일치 항목이 없었다.
- **미실행** · 변경 후 회귀 비교, AT-OP-01~36, 별도 빌드·개인값 검사, 증거 PNG, TASK-03, 설치와 푸시. 요구 증거 수준 3의 제품 변경 검증은 착수 전이다.

### 기준 시험

`c22e6774604398f84351d69dd926ba3510d31aa2`의 깨끗한 분리 체크아웃(`.build/owner-profile/baseline-source`)에서 기존 시험을 실행했다. 로그는 호스트 worktree의 `.build/owner-profile/` 기준이다. 운영 공항 대신 임시 Hermes 홈을 사용했다.

| 명령 | 종료 및 관측 | 로그 |
|---|---|---|
| 호스트 브랜치에서 시스템 Python으로 `bash scripts/test.sh` | 1. 실행기에서 `pytest`를 찾지 못했다. 설계 기준판의 시험 결과는 아래 행부터다. | `baseline.log` |
| 공개 기준판에서 Hermes 시험 Python으로 `bash scripts/test.sh` | 1. 328 통과, 3 실패, 218 설정 오류. 최초 설정 실패는 `adapter.connect()` 단언이며, 별개 게이트웨이 subprocess 실패 로그에는 `yaml` import 오류가 있다. | `baseline-public.log`, `baseline-public-first-error.log` |
| 공개 기준판에서 기존 Python 의존성과 짧은 pytest 임시 경로를 적용해 `bash scripts/test.sh` 재실행 | 1. 548 통과, 1 실패. 유일한 실패는 `tests/acceptance/test_gate_foundation.py::test_at_hf_08[True]`에서 `hermes_facility` import 오류다. 스크립트의 게이트웨이 수명주기와 앱 단계는 실행되지 않았다. | `baseline-public-retry.log` |
| 기존 team-kit 라이브러리 경로를 지정해 `"$HEJO_PYTHON" -m pytest 'tests/acceptance/test_gate_foundation.py::test_at_hf_08[True]' -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 0. 1 통과. | `baseline-public-roster.log` |
| 같은 환경에서 `"$HEJO_PYTHON" -m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 0. 549 통과, 기존 pytest 경고 1건. 실패 목록 없음. | `baseline-public-pytest.log` |
| 같은 환경에서 `"$HEJO_PYTHON" -m gate.tests.gateway_delivery` | 0. 격리 게이트웨이 기동·전송·정상 종료(`GATEWAY_EXIT clean`). | `baseline-public-gateway.log` |
| 공개 기준판에서 단독 `bash app/scripts/test.sh` | 1. 앱 빌드 및 서명 검사는 통과했다. 앱 본시험은 `AT92 real 0.18 fade intermediate frame` 단언에서 중단돼 후속 통신·훅 시험은 실행되지 않았다. 종료 시 설정 메타데이터 비교도 실패했고 다운로드 메타데이터 비교는 통과했다. 설정 내용과 변경 주체는 조사하지 않았다. | `baseline-public-app.log` |

앱 빌드의 `BuildInfo.json`은 기준 커밋의 트리 `3d74ec698fafbf7e61932eac68f97a7ac962539b` 및 `dirty: false`를 기록한다. 시험 후 호스트 worktree와 기준판 체크아웃의 `git status --porcelain`이 모두 비어 있음을 확인했다.

## 2차 · 공개 worktree의 TASK-01

공개 기준 `c22e6774604398f84351d69dd926ba3510d31aa2`에서 `hejo-owner-profile-public-20261125` worktree와 브랜치를 만들었다. 앞 절의 기준 시험 결과를 비교에 사용했다. 구현 성격은 REQ-OP-01~03의 의미 변경이다.

- `gate/owner.py`가 공용 프로필 이름의 읽기·검증·원자적 쓰기를 맡는다. `gate/pictures.py`의 공용 사진 경로를 확장했다. 문 시작 단계에서 `Journal.open`이 공용 디렉터리를 먼저 만들기 때문에 `gate/journal.py`에서 새 `shared/hejo`의 모드를 0700으로 지정했다. 기존 디렉터리 모드는 유지한다.
- `gate/server.py`는 기존 출입증 인증으로 이름·사진 변경을 받고, 연결에 현재 프로필이 포함된 welcome·roster를 보낸다. 모든 roster 생성점은 한 프레임 함수로 모았다. 사장 사진 쓰기·삭제 응답은 `picture`에 더해 앱이 즉시 반영할 `owner`를 돌려준다. `schemas/hejo-wire-v1.json`과 `schemas/pictures.md`에 같은 계약을 반영했다.
- `gate/adapter.py`의 표시 이름을 방·스레드 맥락, Hermes 출처, 버튼 결과 및 텔레그램·디스코드에서 사용한다. 사장 표시의 기존 기본값과 대화 세션 식별을 유지한다. 수락 시험 문서 2판은 계획 폴더의 파일을 그대로 복사했다.

### 문 수락 시험

시험 실행 파일은 `gate/tests/test_owner_profile.py`다. 아래는 실제 loopback HTTP/WS 및 기존 가짜 채널 송신자를 사용한 `owner-target.log` 결과다. 위험도 일반, 문 저장·전파·직원 전달 기준 증거 수준 3을 확보했다. 외부 채널 송신 경계는 대역 증거 수준 2다.

| 수락 기준 | 시험 함수 | 실행 결과 |
|---|---|---|
| AT-OP-01 | `test_at_op_01_permissions_and_restart` | 새 공용 경로 및 기존 0755 권한 경로 모두 통과, 재시작 뒤 읽기와 사진 권한 확인 |
| AT-OP-02~05 | `test_at_op_02_trim_and_clear`, `test_at_op_03_invalid_name_preserves_value`, `test_at_op_04_unauthorized_member_cannot_write`, `test_at_op_05_picture_round_trip_and_validation` | 각각 통과, 비정상 요청 뒤 기존 값 보존 확인 |
| AT-OP-06 | `test_at_op_06_broken_file_or_symlink_replaced` | 두 경우 통과, 손상 파일 복구와 링크 대상 파일 보존 확인 |
| AT-OP-07~09 | `test_at_op_07_09_welcome_and_old_frame`, `test_at_op_08_09_roster_notifications_and_requested_snapshot` | 각각 통과, 실제 프레임 스키마 검증 및 owner 없는 welcome 호환 확인 |
| AT-OP-10·14 | `test_at_op_10_discord_owner_name`, `test_at_op_10_14_telegram_name_changes_only_new_posts` | 각각 통과, 새 이름으로 다음 글만 전송되고 이전 기록·대응표 보존 확인 |
| AT-OP-11 | `test_at_op_11_thread_and_room_context` | 기본값 및 사용자 이름 두 경우 통과, 직원 이름 유지 |
| AT-OP-12 | `test_at_op_12_hermes_identity_stays_stable` | 통과, 이름 설정 전후 세션 키·사용자·스레드 식별자 유지 |
| AT-OP-13 | `test_at_op_13_clarify_decision_name` | 기본값 및 사용자 이름 두 경우 통과 |

인증 변이는 시험 프로세스 메모리에서만 기존 HTTP 인증을 우회했다. AT-OP-04가 401 대신 200을 관측해 의도대로 실패했다. 그 밖의 변이는 위 수락 시험이 실제 정상·오류·경계 경로를 검증해 생략했다.

### 차단 · 기존 wire 파일 해시 고정과 REQ-OP-02.AC-03 충돌

전체 시험에서 기존 `tests/acceptance/test_slack_move_gate.py`의 `test_at_sm_02_edit_state_buttons_images_delete`가 실패했다. 이 시험은 wire 스키마 파일 전체를 고정된 SHA-256과 비교한다. 선택 속성 `owner`를 실제 `schemas/hejo-wire-v1.json`에 추가하는 REQ-OP-02.AC-03과 동시에 만족할 수 없다. 구조 비교에서 새 `owner_profile` 정의와 welcome·roster 응답의 선택 참조 두 개만 빼면 기준 스키마와 구조가 동일함을 확인했다.

수락 시험 2판의 기존 회귀 단언 보존 지시에 따라 AT-SM-02는 그대로 두었다. 계획 담당이 승인된 선택 필드 추가를 반영해 AT-SM-02의 기대 해시를 갱신하거나, 기존 의미를 보존하는 구조 검사를 별도로 확정해야 한다. 이전 공개 이식의 선례와 후속 변경 범위를 감안하면 스키마 해시 한 줄과 설명 갱신을 해당 단계에 명시적으로 승인하는 방안을 권고한다. 그 판단 전까지 작업 트리와 스테이지를 유지한다. 구현 대상 트리 `ba2c2e2d1779c04b861bcdd080dfc407b40ad72d`, HEAD `c22e6774604398f84351d69dd926ba3510d31aa2`.

### 실행 증거

로그 경로는 공개 worktree의 `.build/owner-profile/` 기준이다. 재현 환경은 같은 폴더의 `test-env.sh`에 기록했다.

| 명령 | 결과 | 로그 |
|---|---|---|
| `"$HEJO_PYTHON" -m pytest gate/tests/test_owner_profile.py -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 0. AT-OP-01~14, 17케이스 통과. | `owner-target.log` |
| `bash scripts/test.sh` | 1. 기존 548개 및 신규 17개 통과, 기존 AT-SM-02의 스키마 해시 단언 1개 실패. 스크립트의 게이트웨이·앱 단계는 여기서 실행되지 않았다. | `task01-suite.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py` | 0. 스테이지 포함 추적 파일 검사 통과. | `task01-private.log` |
| 인증 제거 변이로 AT-OP-04 단독 수행 | 1. 401 대신 200을 검출한 의도된 실패. 시험 프로세스 종료로 원복. | `task01-mutation-auth.log` |
| JSON 구조 비교 및 `git diff --cached --check` | 0. 승인된 owner 스키마 필드·정의 이외의 변경 없음, 공백 오류 없음. | `task01-wire-structure.log` |
| `"$HEJO_PYTHON" -m gate.tests.gateway_delivery` 단독 | 0. 격리 게이트웨이 기동·전송·정상 종료(`GATEWAY_EXIT clean`). | `task01-gateway.log` |
| `bash app/scripts/test.sh` 단독 및 재개 뒤 한 차례 재실행 | 두 번 모두 턴 중단으로 종료 코드 미확인. 첫 실행은 빌드 통과(`BUILD_OK`), 두 번째는 컴파일 경고까지 기록했다. 빌드 산출물 `codesign --verify --deep --strict app/.build/hejo.app`은 0. 앱 본시험 결과 미확인. | `task01-app.log`, `task01-app-resumed.log` |
| AT-SM-02 진단용 사본에 새 스키마의 정확한 해시만 대입해 단독 pytest | 0. 1개 통과. 원본 수락 시험의 실패 상태는 그대로다. | `task01-hash-diagnostic.log` |

재개 후에도 수락 시험 원본은 변경되지 않았다. `git fetch github`는 0, `github/main`은 `c22e6774604398f84351d69dd926ba3510d31aa2`, AUTOLOAD 확인 grep은 일치 없이 종료 1이었다. TASK-01은 위 단언 충돌로 커밋 전이고, 커밋 후 10분 간격 감지·TASK-02·TASK-03은 미착수다. 앱 회귀는 단언 처리 결정 후 최종 변경본의 전체 시험에서 다시 확인한다.

계획 담당의 직접 전달을 기존 인계서 9절과 대조했다. 전달은 공개 worktree 및 작업 순서를 재확인했으며 AT-SM-02 변경 권한은 추가하지 않았다. 공개 worktree의 HEAD와 스테이지 트리는 위 기록과 일치한다. 기존 전체 시험과 진단용 사본의 로그를 재확인했고 재실행은 생략했다.

## 3차 · D-03 수락 시험 해시 갱신

계획 담당 승인 `350d89e`(tasks D-03, 인계서 9절)에 따라 `tests/acceptance/test_slack_move_gate.py`의 AT-SM-02에서 설명 주석 한 줄을 추가하고 예상 SHA-256을 `87aa0ca6fd92ab66236ac66aa3243062f3d8635ba2bed06a64a0dd728aae0ca8`에서 `de81c49f8a24d4b0838025cf056daf65e3aa2e7ae2618199f0262172ba365168`로 갱신했다. 실제 SHA-256을 확인했다. 같은 시험의 다른 단언과 HEJO-OWNER-PROFILE 수락 시험 명세 2판을 보존했다. 제품 스테이지는 D-03 전과 동일하며, 시험 해시 갱신까지 포함한 스테이지 트리는 `d2b719e60eae4b87af4008de400dc7f290342c61`이다.

기준 시험은 1차 절의 증거를 재사용한다. 검사는 분리된 백그라운드 프로세스에서 순차 실행해 턴 재개 뒤에도 기록을 확인할 수 있게 했다. 증거 로그와 종료 코드는 공개 worktree의 `.build/owner-profile/`에 있다.

`bash scripts/test.sh`의 pytest 단계는 566개 통과(기준 549개와 신규 17개), 기존 경고 1건이다. 같은 실행의 게이트웨이 수명주기는 `GATEWAY_EXIT clean`을 기록했다. 앱 단계 및 앱 단독 실행의 최종 결과는 아래에 이어 기록한다.

| 검사 | 종료 및 결과 | 로그 |
|---|---|---|
| `bash scripts/test.sh` | 0. pytest 566개 통과, 게이트웨이 정상 종료, AppKit 빌드·서명·AT92·앱/통신·훅 및 종료 시 두 메타데이터 검사 통과. | `task01-d03-suite.log` |
| `bash app/scripts/test.sh` 단독 | 1. 빌드·서명과 두 메타데이터 검사 통과. 기준 목록에 있던 AT92에서 중단했다. 이번 단언은 `opening takes key focus`, 기준 실행의 단언은 `real 0.18 fade intermediate frame`이다. 단독 실행에서는 이후 시험이 실행되지 않았다. 전체 실행에서는 AT92와 이후 단계가 모두 통과했고, 이 커밋에는 앱 소스 변경이 없다. | `task01-d03-app.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py`, `git diff --cached --check`, 승인 수락 시험 원본 `cmp` | 모두 0. | `task01-d03-private.log`(개인값 검사) 및 셸 출력 |

TASK-01 커밋은 `a6266cde188e17fb17942b5e90500c9cbfed9895`다. 커밋의 트리와 시험 대상 스테이지 트리가 동일하고 작업 트리가 깨끗함을 확인했다. 커밋 뒤 `autoload-watch.log`에 10분 간격 감지를 시작했다. 감지 주기의 시작·종료 코드는 `autoload-watch.start` 및 `autoload-watch.exit`에 기록한다.

### AUTOLOAD 감지 종료

감지는 2026-11-26 00:39:28 KST에 시작했다. 01:19:31 KST까지 10분 간격으로 5회 확인했고, 매회 공개 `github/main`은 `c22e6774604398f84351d69dd926ba3510d31aa2`였다. 이후 대기 도구가 요청한 간격보다 늦게 반환했고, 감지 프로세스는 벽시계 기준 3시간 상한을 넘어 종료 코드 124를 기록했다. 기록 공백 동안 매 10분 확인은 이뤄지지 않았다(`autoload-watch.log`, `autoload-watch.exit`). 재개 직후의 `git fetch github`는 종료 0이며 인계서의 `git grep`는 종료 1, 공개 tip 역시 그대로임을 독립 확인했다(`autoload-final.log`). TASK-02는 대기 상태이고, 앱 변경과 증거 PNG 및 TASK-03이 남았다.

## 4차 · AUTOLOAD 병합과 TASK-02

공개 `github/main`의 `df46dbefa5f26544ec20f3a861a4b16870b4b93f`에서 AUTOLOAD 표식 두 곳을 확인했다. 이를 TASK-01 커밋에 병합한 커밋은 `380b6c4fdd0359ffdaba6af60afc28b2d03d544d`다. 충돌 없이 병합했다. 앱 수정 전 `bash scripts/test.sh`는 종료 0(문 pytest 566개, 게이트웨이 정상 종료, 앱과 메타데이터 검사 통과)이다. 증거는 공개 worktree의 `.build/owner-profile/task02-merge-suite.log`와 `.exit`다.

`ConversationModel`은 welcome·roster의 프로필을 메모리에서 관리한다. `GateHTTP`와 `ConversationController`는 이름 저장·사진 변경 응답을 적용하며, 오래 기다린 응답이 그 사이 받은 새 roster를 덮지 않도록 프로필 revision과 연결 범위를 확인한다. `PetSettingsWindow` 계정 탭의 프로필 영역은 기존 `AppDelegate` 설정 진입점과 연결했고, 카드 사진과 머리줄에서 같은 영역을 열 수 있다. 입력 오류 메시지는 이름 초안을 보존하며 사진 처리는 기존 PNG 변환과 주소 캐시를 공유한다.

`ConversationView`가 두 화자의 머리줄 입력을 만들고 `NativeThreadCard`가 같은 모서리·여백으로 양쪽 말풍선을 그린다. 직원 글의 분기 조건을 제거했다. 여러 줄은 측정한 TextKit 폭을 실제 화면에서도 유지하며, 긴 코드 문단은 글자 단위로 줄을 바꾼다. 더 보기의 위치는 말풍선 안, 첨부와 버튼은 그 아래다. 기존 현재 기록 조회 방식에서 `HistoryCoordinator`·`HistoryCopy`를 통과하는 복사 경로까지 표시 이름을 전달했다. 검색·작업 공간 및 설정 미리보기에도 반영했다.

기존 회귀 단언은 유지했다. 이미 제거한 속성에 접근하던 진단 스냅샷의 관측 항목 하나가 바뀌었다.

| 기존 관측 | 변경 전 | 변경 후 |
|---|---|---|
| `HejoSmoothTests.swift`의 S2 카드 스냅샷 `conversational` 값 | 짧은 직원 답글 조건 `post.conversational` | 실제 배치 `!piece.bubble.isEmpty` |

수락 시험 문서 2판은 계획 폴더 원본과 `cmp` 일치다. 실제 AppKit 카드와 실제 루프백 문 위의 앱 두 대를 관측했다. 증거 수준 3. 이미지 두 장은 공개 worktree의 `.build/owner-profile/owner-chat-light.png`와 `owner-chat-dark.png`다.

| 수락 시험 | 시험과 관측 |
|---|---|
| AT-OP-20·21 | `ownerProfileTests`와 `ownerProfileTransport`. 연결 상태별 버튼, 실제 카드의 메뉴 동작과 이름 필드 초점 |
| AT-OP-22·24 | `ownerProfileTests`. roster 이름 전파와 프로필 없는 이전 프레임의 호환 |
| AT-OP-23 | `test_at_op_23_failed_http_save_preserves_input`. 세 HTTP 응답 상황에서 입력·이전 이름 및 오류 문구를 확인 |
| AT-OP-25·26 | `ownerProfileTests`, `assertRichBody`. 직원 말풍선 여섯 유형, 360pt·600pt의 실제 TextKit 줄 조각, 표 셀 경계, 마지막 코드 글리프, 가로 스크롤 부재 |
| AT-OP-27·28 | `ownerProfileTests`. 공통 반지름·여백과 사용자 색, 접기 안쪽·첨부와 버튼 바깥쪽 |
| AT-OP-29~33·36 | `ownerProfileTests`. 이름·시간·사진의 위치와 이어 쓰기, 대기·중단 표기, 아바타 글자, 미리보기, 직원 머리줄 |
| AT-OP-34 | `ownerProfileTests`. 검색 화자, 복사, 작업 공간의 설정 이름과 기본값 |
| AT-OP-35 | `test_at_op_35_two_app_controllers_profile_images`. 앱 둘이 서로 다른 출입증으로 접속해 설정에서 저장하고, 두 앱이 가운데 픽셀 기준 빨강→파랑→글자 아바타로 갱신되는 동안 연결 id·epoch 및 welcome 횟수 유지 |

최종 검사 대상 스테이지 트리는 `403999d34ce7962dcfa17f3a511820b61e89d85e`다. 로그는 공개 worktree의 `.build/owner-profile/`에 둔다.

### 회귀 시험에서 확인한 신규 단언 충돌

`bash scripts/test.sh`에서 문 566개, 게이트웨이, 빌드·서명, 추가 앱 수락 단위 시험을 통과했다. 전체 명령은 기존 `app/Tests/PostGroupTests.swift`의 AT-PG-09에서 종료 1이다(`task02-final-suite.log`·`.exit`). 이 시험의 `precedingOwner == true` 경우에는 같은 스레드의 내 글 두 개 뒤에 직원의 '생각 중'이 온다. 기존 단언 `[(previous,false)]`는 생각 중 글이 본문 조각에 없다는 조건과 두 번째 내 글의 `continuation == false`를 함께 본다. 새 REQ-OP-06.AC-02 및 AT-OP-30은 이 내 글의 머리줄 생략을 요구하므로 `continuation == true`가 맞다. 병합 기준 전체 시험에서 AT-PG-09는 통과했다.

권고하는 변경은 AT-PG-09의 튜플 기대값을 `[(previous,precedingOwner)]`로 고치는 한 줄이다. 직원의 기대값 `false`, 생각 중 본문 부재, 생각 중 머리줄과 작업 줄 검사는 유지한다. 현재 수락 시험 문서가 허용한 예외에는 연속 내 글 단언이 없으므로 계획 변경·승인 전에는 원본 시험을 유지한다.

| 실행 | 종료 | 실제 결과와 파일 |
|---|---:|---|
| `bash scripts/test.sh` | 1 | 566개, 게이트웨이, 앱 빌드·서명, 신규 앱 단위 통과 뒤 AT-PG-09 실패. 후속 통신·훅은 미실행. 설정·다운로드 메타데이터 통과. `task02-final-suite.log` |
| `bash app/scripts/test.sh` | 1 | 위와 같은 AT-PG-09에서 중단했다. 설정·다운로드 메타데이터 통과. `task02-final-app.log` |
| `app/.build/app-tests --owner-profile-unit .build/owner-profile` | 0 | AT-OP-20·21·22·24~34·36 통과, 최종 PNG 두 장 생성 후 직접 확인. `task02-final-unit.log` |
| `bash app/Tests/OwnerProfileTransport.sh` | 0 | 네 시나리오 통과. AT-OP-20 연결 상태, AT-OP-23의 400·401·연결 단절, AT-OP-35 사진 왕복. `task02-final-transport.log` |
| `bash app/scripts/build.sh` | 0 | 최종 AppKit 빌드·서명 확인. `task02-final-build.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py` | 0 | 스테이지 포함 추적 파일 개인값 검사 통과. `task02-final-private.log` |
| AT-PG-09 한 줄만 갱신한 진단용 사본으로 앱 본시험 | 0 | AT-PG-01~11·13, AT-HF-92 등 앱 본시험 전부 통과(`APP_TEST_OK`). 정식 원본의 판정은 위와 같다. `task02-pg09-diagnostic.log` |

AT-OP-26의 초기 실행은 측정 폭을 줄이며 마지막 코드 글리프가 카드 높이 밖으로 내려가는 문제를 재현했다. 실제 TextKit 폭을 유지한 최종본에서는 합격했다. AT-PG-09의 원본 파일은 작업 트리와 스테이지 모두 변경 사항이 없음을 다시 확인했다. TASK-02는 승인 전 커밋 보류다. 승인 뒤 예외 한 줄을 적용하고 전체 명령을 재실행해 정상적으로 도달하는 후속 통신·훅까지 확인한다.

### D-04 · AT-PG-09 승인 반영

계획 결정 `ebea599570687813f606ec56574f0909e4696369`에 따라 `app/Tests/PostGroupTests.swift`의 AT-PG-09 기대값 한 줄을 갱신했다. 앞 절에서 검증한 제품 코드와 수락 시험 명세를 유지했다. 시험 대상 스테이지는 `09b053b08c23fa033a00e9badd50a4decfc5abe6`이며, 앞 절의 트리와 비교해 승인된 파일 하나만 다르다.

| 시험 | 변경 전 | 변경 후 |
|---|---|---|
| AT-PG-09 · 생각 중인 글은 본문에 나타나지 않음 | `[(previous,false)]` · 앞에서 이어진 내 글에도 머리줄 표시 | `[(previous,precedingOwner)]` · 연속 내 글에서만 머리줄 생략, 직원 글의 기대값 `false` 유지 |

같은 시험의 생각 중 머리줄·작업 줄·본문 조각 검사는 그대로다. 변경된 시험 파일은 앞 절의 한 줄 수정 진단 사본과 동일하다.

최종 `bash scripts/test.sh`는 종료 0이다(`task02-d04-suite.log`·`.exit`). 문·수락 566개, 게이트웨이, 앱 본시험(AT-PG-09·AT92 포함), 후속 통신, 훅 9개, 신규 실제 문 왕복 4개, 설정·다운로드 메타데이터 검사가 모두 통과했다.

| 최종 실행 | 종료 | 실제 결과와 파일 |
|---|---:|---|
| `bash app/scripts/test.sh` | 0 | 단독 실행에서도 AT-PG-09와 AT92 통과. 후속 통신·훅 9개·실제 문 왕복 4개·두 메타데이터 검사 통과. `task02-d04-app.log` |
| `app/.build/app-tests --owner-profile-unit .build/owner-profile` | 0 | 신규 AppKit 수락 단언 통과 및 PNG 두 장 재생성. `task02-d04-unit.log` |
| `bash app/Tests/OwnerProfileTransport.sh` | 0 | AT-OP-23 세 오류와 AT-OP-35 사진 왕복, 연결 제어 포함 4개 통과. `task02-d04-transport.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py` | 0 | 스테이지 포함 추적 파일 검사 통과. `task02-d04-private.log` |

TASK-02 최종 커밋은 `f116bdcae507d6559cd43c5db7b32d3a51b21578`이며, 트리 `09b053b08c23fa033a00e9badd50a4decfc5abe6`는 시험 대상과 일치한다. TASK-01 커밋과 AUTOLOAD 공개 tip을 조상으로 포함하며 작업 트리는 깨끗하다. 앱 설치·운영 반영은 작업 범위 밖이다. 다음 단계는 계획 담당의 독립 검토와 TASK-03이다.
