# 구현 인계: HEJO-TODO-DRAWER / TASK-02·03·04

## 기준과 판단 상태

- 받은 설계: 같은 폴더의 `handoff.md` 2판, `design.md` 2판과 `tests/acceptance/HEJO-TODO-DRAWER.md` 2판. 계획 검증 2회차 APPROVED 기록을 확인했다. 문서 일부의 ‘재검증 대기’ 문구는 수정하지 않았다.
- hejo 착수 기준은 `fe6c05a0a1dd6c7b83e96929b8b6cd9421a8ce95`. 설계의 제품 기준 `63cbe2a` 이후 제품 차이가 없음을 확인했다. 별도 구현 브랜치 `role-workflow/7-833b7c8b`에서만 제품을 변경했다.
- TASK-02·04 일반, TASK-03 고위험(공유 실행·연결 취소·프로세스 회수). 필요 증거 수준 2. 이 보고는 구현·자체 시험 결과이며 독립 검증이나 제품 최종 완료 판정이 아니다.
- 판단 상태와 최종 커밋은 아래 최종 결과 절을 따른다.

## TASK-02: team-kit 읽기 명령

- 작업 위치는 계획 폴더 기준 `../.worktrees/hejo-todo-drawer-20261120`. 실제 절대 경로 대응표는 구현 worktree의 `.build/todo-drawer/paths.json`에만 보관했다. 운영 원본을 수정하지 않았다.
- 기준 `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`. 착수 시 HEAD·작업 사본·실행본의 `deadline_watch.py` sha256은 모두 `e20213cdb0e17d4e72a97ea3bcaff5216382efa2b9269c7846063e7ce9f78af1`이었다. 로컬 `.build/todo-drawer/preflight.json`과 종료 시 `operating-source-check.json`을 참조한다.
- 변경: `hermes/bin/hermes-deadlines`, `hermes/plugin-store/team-kit/lib/hermes_team_services/deadline_watch.py`, `hermes/plugin-store/team-kit/tests/test_deadline_list.py`.
- `open_items`는 기존 `load`·검증을 재사용하여 열린 항목의 허용 필드만 돌려준다. CLI는 기존 `app_registry.read_team`·`profile_home`을 재사용하며 직원별 실패를 분리한다. 명부를 못 읽으면 `TEAM_UNAVAILABLE`로 종료한다. 쓰기·닫기·Slack 보고 경로는 변경하지 않았다.
- 전용 커밋: `b38cc557f443a1032b3e3ab4d1adf4b2023a2122`, 명부 YAML 실패 처리 보완 `b2bc84f89ff52a0d14b5cb39768b5e767eee189e`. 두 번 모두 `git commit --only`로 자기 파일만 커밋했다.
- 증거 수준 2. 가짜 홈의 파일 목록·해시 불변, 닫힌 항목 제외, 없는 장부, 깨진 JSON·심볼릭 링크·없는/깨진 명부와 기존 마감 동작을 검증한다(AT-TD-01~05).

## TASK-03: 문·규격

- 변경: `gate/deadlines.py`, `gate/server.py`, `schemas/hejo-wire-v1.json`, `gate/README.md`, `tests/acceptance/test_deadlines.py`.
- `Deadlines` 한 객체가 진행 중 실행 Task 하나를 소유한다. 연결의 대기 Task는 공유 실행을 shield로 기다리고, 연결 종료 시 자기 대기자만 취소한다. 대기자가 없어도 실행이 끝나며 결과 캐시는 남기지 않는다.
- 실행은 고정 명령, 입력·stderr 차단, 10초·stdout 512 KiB 제한을 적용한다. 제한 초과·취소·어댑터 종료 때 stdout도 비우면서 terminate → 0.2초 → kill → wait로 회수한다. 프로세스 생성 도중 취소와 정리 도중 취소도 회수 책임을 유지한다. 종료가 시작되면 새 실행을 받지 않는다.
- 응답은 허용 필드만 조립한다. 일반 문장 출처와 내부 기록을 내보내지 않는다. 로그에는 개수와 이유 코드만 남긴다. 기존 프레임·연결 명령 표는 그대로 두고 새 종류만 더했다.
- 전용 커밋: `8cdc08e267946216ee234e772579dd623b5c9f31`, 파이프 회수 보완 `e14de5ae2262b435b9df0115a37c890025e326be`. 둘 다 `git commit --only`.
- 증거 수준 2. 실제 subprocess·가짜 명령·인증된 두 소켓으로 AT-TD-10~19를 검사한다. 연속 출력과 SIGTERM 무시도 포함하며 종료 뒤 pid가 사라졌는지 확인한다.
- mutation: 공유 실행의 shield만 제거했을 때 AT-TD-18이 종료 1로 실패하고, 원복 후 정상 시험은 통과한다. `task03-mutation-final.json`이 대상 커밋·기대 실패 코드와 로그 위치를 기록한다.
- 독립 검토에서 공유 Task 소유권, 어댑터 종료 이후 요청, 생성·정리 취소, stdout 가득 참 경계를 특히 확인해 달라.

## TASK-04: 앱

- 변경: `TodoDrawerModel.swift`, `TodoDrawerView.swift`, `IslandModel.swift`, `IslandView.swift`, `PetLayout.swift`, `PetController.swift`, `PetView.swift`, `ConversationView.swift`, `ConversationController.swift`, `LocalStore.swift`, `AppDelegate.swift`, `TodoDrawerTests.swift`, `IslandTests.swift`, `TestMain.swift`(각각 `app/Sources/` 또는 `app/Tests/`). 전용 커밋은 `af30f400fba26a5a1d01844532fb84b17ac8d659`이며 `git commit --only`로 위 14개 파일만 커밋했다.
- 기존 `notices`를 읽는 메모리 투영이 카드 묶기·정렬·D-day·실패 안내를 맡는다. 마감 장부나 응답을 디스크에 복제하지 않는다. 칩 선택은 대화 컨트롤러의 세션 상태, 열림 여부만 Mac 로컬 설정이다.
- AppKit 목록·칩·카드와 덮기 막을 추가했다. `PetPlacement` 하나가 늘림/덮기를 결정한다. 채팅·웹 영역을 먼저 계산한 뒤 왼쪽에만 붙이므로 웹 폭을 줄이지 않는다. 0.25초 움직임은 기존 bubbleMotion을 사용하며 너비 덮개를 만들지 않는다.
- 기존 일반 사장 칸 클릭 경로를 `Action.drawer`로 교체했다. 새 질문 미리보기의 oldest 치환은 그대로다. 기존 `IslandTests.swift:70~72`의 AT56 단언을 변경하지 않았다.
- 기존 회귀 시험의 일반 클릭 입력은 승인된 교체 경로에 맞춰 ‘알약으로 열기 → 첫 질문 카드 누르기’로 옮겼다(`IslandTests.swift`). 질문 선택·펼침·강조에 대한 기존 기대값은 그대로이며 새 수락 시험 명세도 바꾸지 않았다. 테스트 전용 제품 fallback은 없다.
- 실제 ConversationView·IslandView·PetController와 가짜 화면·시계·문 응답으로 AT-TD-20~41을 검사한다. 기존 PetWindowTests·WebPaneTests는 기대값을 변경하지 않고 전체 회귀로 확인한다. 증거 수준 2.
- 동작 차이: 미리보기가 아닌 사장 칸·빈 알약은 이제 칸을 토글한다. 답 요청 카드가 기존 질문 이동과 1.5초 강조를 맡는다. 알림은 기존 `markAlertSeen` 경로를 사용한다.

## 설계 적합성과 남은 범위

- 책임 자리·공개 계약·수락 기대값의 임의 변경 없음. 새 원본·새 작업 저장소·허브 상태 키·SwiftUI 화면·임시 제품 코드 없음. 문 프로세스 실행 경계와 화면용 투영은 승인된 설계의 책임 분리다.
- TASK-05·06·07, 운영 설치·장부 실자료 조회·게이트웨이 재시작·앱 교체·실제 Slack/고객 메시지·git push는 수행하지 않았다. 운영 적용·롤백은 후속 TASK-05 인계에서만 결정한다.
- 남은 위험은 설계에 있는 Mac 시간대/KST 가정과 운영 source 형식이다. 실제 장부·운영 문·사장 확인(M1~M3)은 미검증이다.
- 진행 중 HEJO-CONN-MANAGE의 기준 checkout에 미커밋 제품 변경을 확인했다. 최종 기준 전진 상태는 아래 절을 따른다. 이 작업에 섞거나 덮어쓰지 않았다. 최종 검토자는 최신 기준 브랜치의 커밋·원격 tip을 다시 확인하고, 앞섰으면 승인된 workflow대로 merge 지시 후 재검증해야 한다.
- 하위 에이전트 실행 없음. 무관한 리팩토링 없음. 기존 500개 글 검색 회귀의 긴 실행은 스택을 확인한 뒤 정상 종료를 확인했다. `.build/todo-drawer/app-stall-sample.txt`에 기록했으며 해당 검색 코드는 고치지 않았다.

## 실행한 검사와 로그

환경은 구현 worktree의 로컬 `.build/todo-drawer/env.sh`에 있다. Hermes venv를 `HEJO_PYTHON`으로 사용하고 기존 로컬 시험 의존성 경로를 포함했다. 경로·실제 값은 추적 문서에 복사하지 않는다. 아래 로그 경로는 별도 표시가 없으면 hejo 구현 worktree 기준이다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| team-kit `pytest .../test_deadline_list.py .../test_deadline_watch.py -q -p no:cacheprovider` | 종료 0, 49 passed | `.build/todo-drawer/task02-final.log`(team-kit worktree에도 복사) |
| team-kit `"$HEJO_PYTHON" ./airport-check --snapshot "$PWD"` | 종료 0, boundary 382·document·compartments PASS, 기준선 변경 없음 | team-kit worktree `.build/todo-drawer/airport-check-final.log` |
| `pytest tests/acceptance/test_deadlines.py -q -p no:cacheprovider` | 종료 0, 12 passed | `.build/todo-drawer/task03-reaping.log` |
| `pytest gate/tests tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 393 passed·기존 pytest warning 1 | `.build/todo-drawer/task03-reaping-gate.log` |
| `"$HEJO_PYTHON" -m gate.tests.gateway_delivery` | 종료 0, GATEWAY_EXIT clean | `.build/todo-drawer/task03-gateway.log` |
| shield 제거 mutation | 시험 종료 1(기대한 실패), 원복 | `.build/todo-drawer/task03-mutation-final.log` |
| `.build/todo-drawer/compile-tests.sh`(실제 Swift 시험 바이너리의 `--todo-drawer`) | 종료 0, AT-TD-20..41·APP_TEST_OK | `.build/todo-drawer/task04-targeted-3.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py --home .build/todo-drawer/scan-home` | 종료 0, 가짜 명부·금고 대조와 정적 패턴 검사, 바이너리 생략 | `.build/todo-drawer/scan-final.log` |

- 첫 전체 실행은 기존 일반 사장 칸 클릭을 검사하던 회귀 시험에서 종료 1이었다. 위 TASK-04 절대로 승인된 새 입력 경로로 옮겼다. 원래 기대값이나 미리보기 수락 기준을 완화하지 않았다. 로그 `.build/todo-drawer/full-test.log`.
- 초기 실행 환경에서 YAML 의존성 누락을 확인해 기존 로컬 시험 의존성 경로를 포함했다. `.build/todo-drawer/task03-gate-diagnosis.log`·`task03-gate-env.log` 참조. 문 실패 시험의 정상 응답 준비에는 기본 10초를 쓰고, 의도한 시간 초과에만 짧은 제한을 주입한다.
- 기존 Swift 동시성·deprecated 경고는 로그에 남아 있으며 해당 범위 밖 코드는 고치지 않았다. 운영 파일 대조를 하는 일반 모드 airport-check와 실제 명부·금고를 읽는 정적 검사는 실행하지 않았다. airport-check는 허가된 임시 worktree snapshot에만 적용했다.

## 최종 결과와 검토 대상

[확인] 배정된 TASK-02·03·04의 구현·자체 시험 완료. 최종 제품 완료와 푸시 준비 완료는 아니며 독립 검토와 기준 통합을 기다린다.

- hejo 검토 대상: `5b8ffbaf7845a9f629745d10a32061ccbaae9791` / `role-workflow/7-833b7c8b`.
- team-kit 검토 대상: `b2bc84f89ff52a0d14b5cb39768b5e767eee189e` / `hejo-todo-drawer-20261120`.
- TASK-03 마지막 보완은 `5b8ffbaf7845a9f629745d10a32061ccbaae9791`이다. 문법상 URL이 아닌 출처 문자열도 장부의 정상 문자열이므로 URL 필드만 버리고 정상 목록을 유지한다. AT-TD-10의 URL 제외 경우에 깨진 URL 문자열을 추가했다. 수락 시험 명세의 기대값은 변경하지 않았다.
- `TZ=Asia/Seoul bash scripts/test.sh`: 종료 0. 검증한 제품 트리는 `af30f400fba26a5a1d01844532fb84b17ac8d659`와 같다. 원문 `.build/todo-drawer/full-test-final.log`에는 Python 393 passed, 가짜 게이트웨이 정상 종료, AT-TD-20..41, 기존 AT56 및 앱 전체·네트워크 시나리오·hook 9개, 실제 CLI 설정 메타데이터·다운로드 이름 불변이 있다.
- 마지막 URL 보완 후 문 전체 재검사: `pytest gate/tests tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function`, 종료 0, 393 passed·기존 warning 1. 로그 `.build/todo-drawer/task03-url-final-gate.log`.
- 전체 스크립트의 앱 트리는 마지막 문 보완에서 변경되지 않았다. `git diff --exit-code af30f400fba26a5a1d01844532fb84b17ac8d659 5b8ffbaf7845a9f629745d10a32061ccbaae9791 -- app schemas`는 종료 0·출력 없음이다. 최종 앱 파일 해시는 `.build/todo-drawer/final-app-inputs.json`으로 대조했다. 따라서 전체 앱 검사를 다시 반복하지 않았다.
- 최종 검사 명령·cwd·대상 커밋·종료 코드·로그는 `.build/todo-drawer/verification.json`에 있다. `git diff --check` 종료 0. hejo와 team-kit 구현 worktree의 최종 작업 트리는 깨끗하다.

### 기준 통합·푸시 차단 사항

- 최종 확인 시 다른 작업이 기준 `main`을 `961ea80fb455a3a49f22a2fac9e4f225b35d6ffa`로 전진시켰다. 이 최신 로컬 main은 검토 대상의 조상이 아니다(`merge-base --is-ancestor main <검토 대상>` 종료 1). 착수 기준 fe6c05a에 대한 앞선 결과로 최신 기준 포함을 주장하지 않는다.
- `git ls-remote github refs/heads/main`: 종료 0, 원격 tip `0cc0828d949d4efb2bf7e98b6f7548508b0a5797`. 이 tip도 검토 대상의 조상이 아니다(종료 1). 로컬 main과 원격 tip 사이 `git merge-base`도 종료 1이어서 단순히 ‘로컬 main만 merge하면 된다’고 판단하지 않았다. 원격 추적 ref는 없다.
- 근거는 `.build/todo-drawer/final-git-checks.json`. 이전 중간 안내의 원격 포함 진술은 마지막 읽기 검사로 정정했다. 원격 쓰기·merge·rebase·force는 하지 않았다.
- 계획 담당은 실제 두 기준의 계보와 HEJO-CONN-MANAGE 변경을 확인하고, 허가된 통합 방법을 보완 plan으로 지시해야 한다. 이후 통합·충돌 정리·전체 검사·독립 재검증을 마친 커밋으로만 푸시 대상을 확정한다. 푸시는 사용자 화면 승인 후 플러그인이 수행한다.

이 보고서는 지시대로 계획 담당 폴더에 작성했으며 구현 브랜치의 제품 커밋에는 섞지 않았다. 전체 로그·로컬 경로 대응표는 구현 worktree의 `.build/todo-drawer/`에 있다.


## 보완 1 — 기준 통합과 V-1·V-2·V-3

[확인] 보완 지시 1의 구현·자체 시험을 마쳤다. 최종 검토 대상은 `4a82dda0e506ae4dad7bae9406bad411f3bd4eba`(`role-workflow/7-833b7c8b`)이며 독립 재검증 대기다. 이 절이 앞선 기준 통합 차단 기록의 후속 결과다.

### 병합과 커밋

- 최초 로컬 `main`은 `a3786fbccc6314cc2ff07d2842eaf4333612bb21`이었다. `git merge --no-ff --no-commit main`은 예상한 `gate/server.py` 연결 종료 `finally` 한 곳에서 충돌하여 종료 1이었다. `admin_connections.disconnected(conn.device_id)`와 `deadline_waiters` 전체 취소·`asyncio.gather(..., return_exceptions=True)`를 모두 보존했다. 다른 충돌이나 의도 판단은 없었다.
- 충돌 해결 merge 커밋: `2a7ca15a7527eb71925deaeb4812164ac4522478`. merge 이력 전체를 보존하는 일반 merge 커밋이며 `git commit` 종료 0. 로그: `.build/todo-drawer-supplement1/merge.log`, `merge-resolution.log`.
- 앱 보완 커밋: `005677e801aa461bee8c158814e9be0b151fa86b`. 아래 네 파일만 `git commit --only`로 커밋했다(종료 0, `app-commit.log`).
- 실행 중 `main`이 추가 전진하여 충돌 없이 merge 커밋으로 포함했다. 각각 `git merge --no-ff main` 종료 0이다.
  - `729eee3317e8cea2dc5f8119271696977c0f8563`의 연결 관리 검토 문서: `c472178cbd741607811839852463805a991a911a`(`merge-latest.log`).
  - `131e47ff62f2d5df75c03907d9ae3a768586bbf1`의 연결 목록 합치기 코드·시험·보고서: `154950334e2b3b06430a0773293d30b42bfbbc8f`(`merge-connection-fix.log`).
  - `c9cd9c0471ee08f05d36386290dd57514e28ecb3`의 연결 관리 판정 문서: `4a82dda0e506ae4dad7bae9406bad411f3bd4eba`(`merge-verification.log`).
- 최종 로컬 `main`은 `c9cd9c0471ee08f05d36386290dd57514e28ecb3`이다. 최종 커밋의 조상임을 종료 0으로 확인했다. 기준 checkout의 미커밋 변경은 건드리지 않았다. rebase·force·원격 쓰기는 하지 않았다.

### 바꾼 파일과 동작

- `app/Sources/ConversationController.swift`: 실제 채팅 펼침 상태를 받아 `drawerVisible = drawerOpen && drawerChatExpanded`를 계산한다. 숨김 → 보임 전환에서 한 번 요청하고 5분 주기를 다시 시작한다. 주기 호출·재연결·비동기 전송 직전에도 가시성을 확인하므로 닫힘·접힘·접힌 채 시작에서는 요청하지 않는다. 열림 선호 저장·복원 형식은 그대로다.
- `app/Sources/PetController.swift`: 설치·칸 토글·채팅 펼침/접힘 때 열림 선호와 펼침 상태를 함께 전달한다. 기존 `onExpansionChanged` 배선을 보존했다.
- `app/Sources/ConversationView.swift`: `refresh`와 1초 tick의 `drawerSnapshot` 계산·`todoDrawer.show`를 가시성으로 제한한다. `refresh` 내부 tick의 중복 투영도 제거했다. 보이게 되면 컨트롤러의 변경 통지로 최신 상태를 그린다.
- `app/Tests/TodoDrawerTests.swift`: AT-TD-42를 추가했다. 접힌 11분 동안 주기 호출·재연결에도 요청 0, 펼친 직후 1, 5분 주기 재시작, 저장된 열림 선호로 접힌 채 시작할 때 요청 0을 실제 PetController/View 배선과 가짜 전송으로 확인한다. V-1은 숨은 동안 카드 내용을 바꿔 refresh/tick을 호출해도 카드 보기의 사진 읽기가 없고, 다시 보일 때 즉시 최신 카드를 그리는지 확인한다.
- 기존 AT-TD-20~41의 입력·기대값, AT56·AT92 및 다른 회귀 시험은 변경하지 않았다. `integration.json`에 기존 TodoDrawer 시험 본문 보존 대조 결과가 있다. spec·수락 시험 명세를 구현자가 고치지 않았다.
- 도달 증거 수준 2(실제 AppKit 패널·컨트롤러·가짜 화면/시계/문을 쓰는 대역 통합). 운영 마감 조회·운영 문 적용·사장 확인 증거는 아니다.

### 검사와 로그

아래 로그는 모두 hejo 구현 worktree의 `.build/todo-drawer-supplement1/` 기준이다. 환경은 기존 `.build/todo-drawer/env.sh`를 사용했다. `HEJO_PYTHON`은 Hermes venv이며, 개인값 검사는 가짜 명부·금고가 있는 임시 검사 홈으로 실행했다. 최종 명령·커밋·종료 코드·로그 대응은 `verification.json`, 병합/기준 기록은 `integration.json`에 있다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| `TZ=Asia/Seoul bash scripts/test.sh` 최종 병합본 | 종료 0. Python 416 passed·기존 warning 1, gateway clean, AT-TD-20~42·AT-HF-92·앱 전체·네트워크 회귀·hook 9개 통과. 실제 CLI 설정 메타데이터·다운로드 이름 불변 | `full-test-final.log` |
| `"$HEJO_PYTHON" -m pytest gate/tests tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` 최종 병합본 | 종료 0, 416 passed·기존 warning 1 | `gate-test-final.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py --home .build/todo-drawer/scan-home` 최종 병합본 | 종료 0, 바이너리는 기존 정책대로 생략 | `scan-final.log` |
| `git diff --check` | 종료 0 | `diff-check.log` |
| `git merge-base --is-ancestor main 4a82dda0e506ae4dad7bae9406bad411f3bd4eba` | 종료 0. 위에 적은 최종 로컬 main 기준 | `main-ancestry.log` |
| `TZ=Asia/Seoul app/.build/app-tests --task41`(AT92 단독) | 종료 0, AT-HF-92·APP_TEST_OK. 최종 앱과 입력이 같은 바이너리임을 `git diff ... -- app` 종료 0으로 대조 | `at92-isolated.log`, `app-inputs-unchanged.log` |

- 최종 실행 앞의 전체 실행 두 번은 모두 종료 1이었다. 두 번 모두 Python 409 passed와 AT-TD-20~42까지 통과한 뒤 기존 `AT92 real 0.18 fade intermediate frame`에서 실패했다. 각각 `full-test.log`, `full-test-2.log`에 보존했다. 첫 실행 중 호스트에서 다른 Swift 컴파일을 관측했다. 두 번째 실패 때는 다른 Swift 컴파일·시험 프로세스가 보이지 않았으므로 부하만을 원인으로 단정하지 않는다.
- AT92 기대값·코드를 바꾸지 않고 단독 실행 통과를 확인했다. 이후 추가 병합을 모두 마친 최종 커밋에서 전체 스크립트를 새로 실행해 종료 0을 확인했다. 앞선 실패를 최종 통과로 덮어쓰지 않는다. D-1(기존 실제 시간 의존)의 재현성 검토는 남는다.
- 중간 집중 시험 `bash .build/todo-drawer/compile-tests.sh`는 종료 0(`targeted.log`). 최종 V-1 보기 관측 단언을 더하기 전 실행이므로 최종 변경본의 통과 근거는 위 전체 시험이다. 추가 기준 병합 전 별도 문 시험은 종료 0, 409 passed(`gate-test.log`); 최종 기준에서는 위 416개 시험으로 다시 확인했다.

### 범위와 인계

- hejo 구현 worktree는 최종 커밋 기준 깨끗하다. 이 보고서 보완 절은 지시한 계획 담당 폴더의 `impl-report.md`에만 덧붙였으며 제품 커밋에는 섞지 않았다. 계획 담당이 재검증 뒤 보고서를 커밋한다.
- team-kit worktree·운영 원본은 이번 보완에서 변경하지 않았다. TASK-02 검토 대상은 앞서 통과한 `b2bc84f89ff52a0d14b5cb39768b5e767eee189e` 그대로이며 해당 시험·airport-check를 반복하지 않았다.
- TASK-05·06, 운영 공항 변경·재시작·비밀 파일 열기·Hermes 본체·ddots 변경·실제 메시지·git push는 수행하지 않았다.
- 다음 담당자는 최종 커밋의 merge 해결과 V-1·V-2·AT-TD-42, 위 증거를 직접 확인해 보완 1을 재판정한다. 공개 이력에 반영하는 TASK-06 절차나 푸시 대상은 이번 구현 보고에서 제안하지 않는다.
