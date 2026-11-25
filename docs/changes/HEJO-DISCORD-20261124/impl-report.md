# 구현 인계: HEJO-DISCORD-20261124 — 검증 2회 보완 결과

[확인] **TASK-01·02 구현 및 자체 시험 완료, 검토용 커밋 생성.** `f6ec80026fded21b46fe6ea62a45eeee08a39c22`, 브랜치 `role-workflow/37-cdc4976c`, 부모 `236b0177468b90d9ea23a1b1190e996db78a0694`. 구현 worktree의 19개 변경 경로만 `git commit --only`로 커밋했다. 커밋 내용은 검증한 파일별 SHA-256과 일치하고 추적 작업 트리는 깨끗하다. 독립 검증과 AT-HD-45 개인값 검사 종료 0은 남아 있다.

- **B-1 해소.** `tests/acceptance/test_slack_move_gate.py`의 AT-SM-02에 허가된 주석 한 줄을 추가하고 규격 SHA-256 한 줄을 `c91a7a4f93a008028809871f377cf6b240c4a4095fab819b48fc69d122ce4bec`로 갱신했다. 1회 보완에서 남긴 18개 파일은 파일별 해시가 그대로다.
- **B-2 인계서 9-2 중간 확인 충족.** 개인값 검사 종료 1, 검출 30건(명부 28, 금고 2). 이전 증거의 기존 목업 14개와 검출 경로 집합이 정확히 같고 변경 19개 경로에서 검출 0이다. 기준 브랜치에 목업 정리가 반영되면 병합한 변경본으로 종료 0을 확인해야 한다.
- **B-3 이번 실행 통과.** 현재 변경본의 전체 앱 시험에서 AT-UC-32를 포함한 AT-UC-30~35와 이후 단위 시험, 12개 fixture, 훅 시험 9개가 모두 통과했다. 별도 임시 worktree에서 기준 커밋의 `app-tests --ui-clean-polish`도 한 번 실행해 종료 0을 확인했다. 이전 실패는 이번에 재현되지 않았다. 현재 전체 앱 시험이 처음부터 끝까지 통과했으므로 9-2의 실패 시 대체 실행 절차는 발동하지 않았다. 기준판과 현재판의 시험·판정 단추 코드는 변경하지 않았다.

검사 경로는 구현 worktree의 `.build/discord-evidence/` 기준이다. Python 검사는 기존 `env.sh`로 Hermes venv를 사용했다.

| 실제 명령 | 종료 코드와 관측 | 로그 |
|---|---|---|
| `HEJO_SKIP_GOOGLE_SECRET=1 bash scripts/test.sh` | **0**. Python 473개 통과, `GATEWAY_EXIT clean`, 서명 앱 빌드, 앱 단위 시험(AT-HD-50~53·AT-HT-50~52·AT-UC-30~35 포함), fixture와 훅 시험 전체 통과 | `review2-full.log`, `review2-full.exit` |
| 위 전체 시험의 AppKit 빌드 단계에서 `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash scripts/build.sh` (cwd `app`) | **0**, `BUILD_OK app/.build/hejo.app` | `review2-full.log` 164행 |
| `python3 scripts/scan_private.py` | **1**, 기존 목업 14개·변경 경로 0개. 집합 비교 **0** | `review2-scan.log`, `review2-scan.exit`, `review2-scan-compare.json` |
| `PYTEST_ADDOPTS="--basetemp=/tmp/hejo-discord-review2-target" "$HEJO_PYTHON" -m pytest tests/acceptance/test_discord.py -q -s -p no:cacheprovider` | **0**, 46개 통과. 정착 엔진 기본 2초 기준 2.027초 관측 | `review2-discord.log`, `review2-discord.exit` |
| `PYTEST_ADDOPTS="--basetemp=/tmp/hejo-discord-review2-mutation" "$HEJO_PYTHON" .build/discord-evidence/mutation.py` (cwd `review2-mutation-src`, 변경본 index에서 복제) | **0**, 닫힘·중복·채널 선택·멘션 변이 각각 기대한 pytest 종료 1. 원복 파일을 실제 소스와 바이트 비교 | `review2-mutation.log`, `review2-mutation.exit`, 복제본의 `.build/discord-evidence/mutation-*.log` 및 `mutation-results.json` |
| 기준 커밋 detached checkout에서 `bash app/scripts/build.sh`, 이어 앱 시험 바이너리 `swiftc` 컴파일과 `codesign` | **0**, 정확한 기준 커밋 확인 | `review2-base-build.log`, `review2-base-build.exit` |
| 기준 checkout의 `app/.build/app-tests --ui-clean-polish <기준판 앱 리소스>` (실제 cwd `review2-base/app`, 실행 경로 `.build/app-tests`) | **0**, AT-UC-30~35 통과. 설정·다운로드 보호 검사도 통과 | `review2-base-polish.log`, `review2-base-polish.exit` |
| `git diff --cached --check`, `git commit --only` | 각각 **0**, 검증본과 커밋의 19개 경로·해시 일치 | `review2-source-snapshot.json`, `review2-commit.log`, `review2-commit.exit`, `review2-verified-commit.txt` |

문·앱 증거 수준 1~2, 실제 정착 엔진 3. 운영 디스코드 실물 동작, 보관 글 묶음 재열림과 파일 한도는 미검증이다. TASK-03·운영 적용·푸시는 다음 범위에 남는다. 계획 담당은 위 커밋을 독립 검토하고 B-2의 최종 확인 절차를 진행한다.

## 이전 보완 1회 기록

아래는 당시 미커밋 변경과 차단 관측을 기록한 이력이다. 현재 상태와 최신 증거는 위 검증 2회 보완 결과를 따른다.


## 1. 판단 상태와 기준

[확인] **부분 완료·전체 검증 차단**. V-1~4를 반영하고 TASK-01·02의 기능 코드와 자체 시험을 작성했다. 디스코드 문 46개 pytest 사례와 앱 AT-HD-50~53은 통과했다. 하지만 AT-HD-45의 전체 검사 통과 조건은 충족하지 못했다. 아래 세 차단 사항이 남아 있으므로 구현 완료·제품 완료로 판정하지 않으며 **새 커밋을 만들지 않았다**. 사용자가 요구한 “모두 통과한 변경본 커밋” 조건을 우회하지 않는다.

기준: 이 폴더의 `handoff.md` 9-1, 보완된 `design.md` 2절·`tasks.md`, `tests/acceptance/HEJO-DISCORD.md`의 관측 방법 보충. base_commit `236b0177468b90d9ea23a1b1190e996db78a0694`. 연합개발, TASK-01 고위험(수준 2 + 정착 3), TASK-02 일반(수준 1~2). TASK-03은 하지 않았다.

## 2. 다음 계획에서 해결할 차단 사항

### B-1. 기존 수락 시험의 통신 규격 전체 해시

[확인] `tests/acceptance/test_slack_move_gate.py:61`의 AT-SM-02가 `schemas/hejo-wire-v1.json` 전체 SHA-256을 `7b3c2db703a83824ee6d173262bbefec34b5210c74954d7c5dc8556c1fb0f75b`로 고정 비교한다. 승인된 디스코드 프레임 6종 추가 후 값은 `c91a7a4f93a008028809871f377cf6b240c4a4095fab819b48fc69d122ce4bec`여서 실패한다. 해당 수락 시험은 수정하지 않았다. `bash scripts/test.sh`의 현재 결과는 **472 passed / 1 failed**, 실패는 이 한 곳이다.

[확인] `.build/discord-evidence/schema-compatibility.json`은 기준 커밋과의 직접 JSON 비교다. 기존 개별 프레임 정의 변경 0, root/client/server 참조의 기존 항목·순서 유지, 루트 메타데이터 유지, 새 정의는 정확히 `discord`, `discord_pair`, `discord_unpair`, `discord_save`, `discord_status`, `discord_code` 6종이다.

[제안] 계획 담당이 호환성 근거를 확인한 뒤 이 기존 수락 시험의 해시 갱신 또는 동등한 보존 관측 방법을 명시적으로 허가한다. 구현자는 기대값을 임의 갱신하거나 이 시험을 제외하지 않았다.

### B-2. 기존 문서의 개인값 검사 검출

[확인] 지정한 실제 개인값 검사는 종료 1이다. 검출 30건(명부 28, 금고 2), 파일 14개이며 **전부 기준 커밋과 내용이 같은 기존 mockup HTML**이다. 이번 변경 파일에서 검출된 항목은 없다. 검출값의 진위·허용 여부는 판정하지 않았다. 원문 값을 보고서에 복사하지 않는다.

검출 범위는 `docs/changes/HEJO-DRAWER-INLINE-20261122/mockups/filter-options.html`, `docs/changes/HEJO-UI-CLEAN-20261123/mockups/` 아래 13개 HTML이다. 전체 상대 경로·종류·행·지문은 `.build/discord-evidence/scan-current.log`, 파일별 `git diff --quiet base_commit -- <파일>` 종료 0 근거는 `scan-baseline-comparison.json`·`.log`에 있다. 기준 커밋 전체를 따로 스캔했다는 뜻은 아니다.

[제안] 계획 담당이 기존 문서 검출의 진위를 분류하고 필요한 정리 범위를 별도로 허가한다. 운영 명부·금고를 고치거나, 가짜 홈으로 지정 검사를 대체하거나, allowlist를 늘려 통과시키지 않았다.

### B-3. 앱 전체 시험 AT-UC-32

[확인] 현재 앱 수락 시험 AT-HD-50~53과 기존 AT-HT-50~52는 통과했다. 앱 전체 unit 실행은 `AT-UC-32 four word-only judgment buttons without image`에서 종료 1이다(`app/Tests/UICleanPolishTests.swift:94`). 해당 기대값·시험·판정 버튼 구현을 수정하지 않았다. **원인 미판정**이며 기준 커밋에서 같은 실패가 난다고 확인한 것은 아니다.

[제안] 계획 담당이 이 실패를 분류하고 필요한 진단·수정 범위를 지정한다. 앱 전체 unit이 중간에서 멈췄으므로 그 뒤 시험과 모든 개별 네트워크 fixture를 전체 통과로 보고하지 않는다.

## 3. V-1~4 처분과 변경 후 구조

- V-1 반영: `gate/rooms.py`의 잠금 안에서 디스코드 다리를 잡고, 잠금 밖에서 `recorded(saved)`를 호출한다. 기존 텔레그램 알림과 같은 한 곳이며 방 저장·방송 경로, 주기 동기화, 공통 추상화는 바꾸지 않았다.
- V-2 반영: `PetSettingsWindow.swift`가 디스코드 구역을 소유하고 “연결과 동기화” 페이지에 텔레그램과 함께 배치한다.
- V-3 반영: `TelegramTests.swift`의 기능 목록 정확 비교 한 줄만 세 기능으로 갱신했다. 그 시험의 다른 기대값과 `tests/acceptance/test_telegram.py`는 무수정이다.
- V-4 반영: AT-HD-22는 해당 `msg_id`의 이벤트 프로필과 `_meta.recipients`를 관측한다. 다른 메시지의 비동기 이벤트와 혼동하지 않는다. AT-HD-14는 초기 ready 전환이 끝난 뒤 방 명령만 보내고, 추가 조회·수동 sync 없이 채널 생성·이름·보관·해제·삭제를 관측한다.

책임은 `gate/discord.py`가 디스코드 창 전체를 소유하며 원본은 기존 기록장이다. 플랫폼 처리기 공장은 독립 듣기만 추가하고 Hermes 원래 처리기를 감싸지 않는다. 어댑터·방 명령·서버·앱은 각 기존 호출 자리에 디스코드 연결을 추가한다. 기록장 종류·기존 프레임 정의·`claims_external`은 유지한다.

## 4. 변경 파일과 이유

현재 변경 18개는 모두 구현 worktree의 index에 staging되어 있다. 추적 파일에 개인 경로·계정·비밀을 더하지 않았다.

| 파일 | 이유 |
|---|---|
| `gate/discord.py` 신규 | 금고·설정·채널·발신 대응, 짝짓기, 닫힘 확인, 중복 방지, 포럼 수신·첨부, 웹후크 발신·나누기·멘션 해제, 정착·typing·종료 |
| `gate/__init__.py`, `gate/adapter.py`, `gate/rooms.py`, `gate/server.py` | 공장 등록, 생성·종료·기록·typing·방 알림, 명령 전달 |
| `schemas/hejo-wire-v1.json`, `gate/README.md` | 프레임 6종과 운용 안내 |
| `tests/acceptance/test_discord.py` 신규 | 문 수락 명세 코드화, 실제 DiscordAdapter 통합, 정착 측정 |
| `app/Sources/DiscordState.swift` 신규 | gate 소유 상태·코드·남은 초·오류 표시 |
| `app/Sources/SettingsPages.swift`, `PetSettingsWindow.swift` | AppKit 디스코드 구역과 준비 안내 |
| `app/Sources/GateClient.swift`, `AppDelegate.swift`, `ConversationController.swift` | 기능 추가·프레임 분배·연결 수명·설정 갱신 |
| `app/Tests/DiscordTests.swift` 신규, `TestMain.swift` | AT-HD-50~53과 시험 진입 연결 |
| `app/Tests/TelegramTests.swift` | V-3 허가된 목록 한 줄 |
| `app/Tests/legacy_feature_fixture.py` | 기존 문 대역이 새 디스코드 조회에도 `unexpected_frame`을 돌려줌. 기존 fixture 시나리오 기대값은 유지 |

새 공통 계층·두 번째 기록 원본·임시 제품 우회 경로는 없다. 정착과 저장 형태는 텔레그램 선례를 각 창이 별도로 소유한다(설계 8절). 운영 설치·원격 발신·Hermes 수정·텔레그램 제품 수정은 없다. 변경 성격은 신규 기능이며 보존 비교 AT-HD-41과 무수정 텔레그램 수락 시험은 pytest 전체에서 통과했다.

구현 세부 보정: 채널 생성 실패에도 이미 만든 분류 id를 저장해 중복 분류 생성을 막는다. 플랫폼 ready와 hejo 활성 전환을 각각 관측하되, 활성 저장 명령이 중복 상태 방송을 만들지 않도록 ready 변경에만 연결 방송을 한다. 채널·웹후크 I/O 이후에는 활성/표지를 재확인한다. SDK `File`은 문맥 관리자가 아니므로 명시적으로 닫고, 404에서 SDK가 닫은 파일을 새 글 묶음으로 대체 발신할 때 새 `File`을 연다. 이는 승인된 계약을 구현하는 세부 처리이며 공개 형식 변경은 없다.

## 5. 외부 API 가정과 증거 수준

[확인] 운영 환경에 설치하지 않고 discord.py **v2.7.1 태그 원본**을 내려받아 읽었다.

- [Bot 원본](https://github.com/Rapptz/discord.py/blob/v2.7.1/discord/ext/commands/bot.py) 237~242행: `super().dispatch`와 `extra_events`의 듣기를 각각 예약. 629행 `add_listener`. 원래 이벤트와 추가 듣기가 함께 불린다는 가정 성립.
- [Webhook 원본](https://github.com/Rapptz/discord.py/blob/v2.7.1/discord/webhook/async_.py) 1719~1720·1790~1799·1879~1880·1905~1918행: `thread`/`thread_name` 지원·상호 배타·thread.id 전달. 221~224행 모든 HTTP 404를 `NotFound`로 올린다. 웹후크 없음도 포함하며 설계대로 한 번 대체 뒤 실패는 로그로 끝낸다. 1595~1612행 새 포럼 글의 응답 채널 id를 보존한다.
- [File 원본](https://github.com/Rapptz/discord.py/blob/v2.7.1/discord/file.py) 147~163행 `reset`·`close`, `__enter__` 없음. [HTTP 원본](https://github.com/Rapptz/discord.py/blob/v2.7.1/discord/http.py) 130~138행은 HTTP 처리 종료 시 파일을 닫는다. 대역에도 같은 수명을 반영하고 파일만 있는 글의 404 대체를 시험했다.

사본·SHA-256: `.build/discord-evidence/discord-{bot,webhook,file,http}.py`, `source-proof.log`. 두 인계 가정은 확인했다. 보관된 글 묶음 재열림과 실제 파일 한도는 실물 전까지 미확인이다.

도달 수준: 문·앱은 1~2, 정착 엔진은 실제 이벤트 루프·기록장으로 기본 2초 경계를 실행해 3(측정 **2.029초**, `discord-final-r3.log`). 네트워크는 대역이므로 수준 4가 아니다. AT-HD-30은 실제 Hermes `DiscordAdapter`의 `_dispatch_discord_message`와 hejo 듣기에 같은 객체를 양 순서로 넣어 원문·첨부·무부작용과 열린 허용의 물러남을 확인한다. SDK는 가짜 모듈이며 Hermes 설치 환경에는 설치하지 않았다.

## 6. 실제 검사와 로그

경로 기준은 **구현 worktree**다. 아래 표의 로그 파일명은 모두 `.build/discord-evidence/` 아래이며, `.exit`는 같은 이름의 종료 코드 파일이다. `.build/discord-evidence/env.sh`는 현재 Hermes venv, 기존 pytest 경로, 임시 공항 fixture를 사용한다. 빠진 PyYAML은 기존 시험 의존성의 yaml 모듈만 로컬 `.build/discord-evidence/deps/`에 복사해 보충했다. 운영 venv·설정·비밀 파일을 고치거나 설치하지 않았다. 현재 변경본의 파일별 SHA-256은 `verified-files.json`(18개), mutation 이후 원복 해시는 `mutation-results.json`이며 실제 파일과 다시 대조했다.

| 실제 명령(앞에 환경 파일 source) | 결과 | 로그 |
|---|---|---|
| `bash scripts/test.sh` | **1**, 472 passed / 1 failed, B-1. pytest 실패로 뒤쪽 runner·앱 단계는 실행되지 않음 | `full-tests-final.log`, `.exit` |
| `HEJO_SKIP_GOOGLE_SECRET=1 bash app/scripts/build.sh` | **0**, 서명 빌드·검증 통과 | `build-current.log`, `.exit` |
| `python3 scripts/scan_private.py` | **1**, B-2: 기존 파일 14개 검출 30건 | `scan-current.log`, `.exit` |
| `PYTEST_ADDOPTS="--basetemp=/tmp/hejo-discord-final" "$HEJO_PYTHON" -m pytest tests/acceptance/test_discord.py -q -s -p no:cacheprovider` | **0**, 46 passed, 정착 2.029초 | `discord-final-r3.log`, `.exit` |
| `bash .build/discord-evidence/app-checks.sh` | **1**, B-3. AT-HD-50~53·AT-HT-50~52 PASS, AT-UC-32 실패. 이미 끝난 빌드 단계를 제외한 기존 app/scripts/test.sh의 동일 컴파일·guard·실행 명령 | `app-checks.log`, `.exit`; runner 파일 보존 |
| `app/.build/app-tests --discord` | **0**, AT-HD-50~53 PASS, APP_TEST_OK | `app-discord.log`, `.exit` |
| `app/.build/app-tests --telegram` | **0**, AT-HT-50~52 PASS, APP_TEST_OK | `app-telegram.log`, `.exit` |
| `python3 app/Tests/network_fixture.py app/.build/app-tests` | **0**, AT-HF-24·25, gap/duplicate/pages/ping, 크기 제한·재연결·시험 출입증 정리 통과 | `app-network.log`, `.exit` |
| `"$HEJO_PYTHON" -m pytest gate/tests/test_gateway_progress.py::test_real_gateway_progress tests/acceptance/test_gate_delivery.py::test_at_hf_22 tests/acceptance/test_slack_move_gate.py::test_at_sm_10_11_12_actual_gateway_scheduler -q -p no:cacheprovider` | **0**, 환경 보충 뒤 3 passed. 이후 전체 pytest에서도 통과 | `gateway-deps-recheck.log`, `.exit` |
| `PYTEST_ADDOPTS="--basetemp=/tmp/hejo-discord-mutation" "$HEJO_PYTHON" .build/discord-evidence/mutation.py` | **0**, 네 변이 각각 pytest **1**로 검출, 원복 후 파일 해시 일치 | `mutation-final.log`, `.exit`, `mutation-results.json`, `mutation-{closed,duplicate,channel,mentions}.log` |
| `git diff --cached --check` | **0** | `diff-check-final.log`, `.exit` |
| 기준 대비 `git diff --exit-code`(telegram.py·test_telegram.py·test_slack_move_gate.py) | **0**, 세 파일 무수정 | `preserved-current.log` |

Mutation은 닫힘 판정 제거·첨부 staging 전 중복 차단 제거·현재 채널 제한 제거·멘션 해제 제거를 각각 검출한다. 변이 실패를 제품 실패로 세지 않는다. 하위 에이전트 사용 없음.

중간 시도의 실패·중단도 증거 폴더에 남겼다. `full-tests.log`의 yaml 누락 3건은 보충 후 해소됐고, 앱 최초 상태 문구 조사 오류는 수정 후 전용 수락 시험으로 통과했다. `app-tests-r4.log` 실행은 중단돼 전체 종료 코드를 확인하지 못했다. 이 중단을 통과로 세지 않았으며 이후 현재 빌드와 앱 시험 명령을 별도로 실행했다.

## 7. 미검증·인계 경계

[미실행/미완료] 필수 검사 3종 모두 통과한 변경본, AT-HD-45, AT-SM-02의 해시 뒤 본문, 앱 AT-UC-32 뒤의 전체 시험, 실물 M1~M10·M6b, 커밋·푸시·운영 적용. 고위험 교차 모델 코드 검토도 남아 있다. B-1~3 이외 범위 밖 정리는 하지 않았다.

브랜치 `role-workflow/37-cdc4976c`, HEAD는 여전히 `236b0177468b90d9ea23a1b1190e996db78a0694`. **새 커밋 없음**, 18개 변경 staging 상태. 계획 문서·보고서는 계획 담당 폴더에 있고 구현 worktree로 가져오지 않았다.

다음 담당은 B-1의 시험 충돌, B-2 기존 검출, B-3 원인 미판정을 직접 확인해 보완 계획을 정한다. 현재 변경을 지우거나 처음부터 다시 구현할 필요는 없다. 추가 변경이 생긴 범위와 필수 검사를 통과시킨 뒤에만 자기 경로를 `git commit --only`로 커밋한다. TASK-03·원격 푸시는 별도 허가 전까지 하지 않는다.
