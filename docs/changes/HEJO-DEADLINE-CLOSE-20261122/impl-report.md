# HEJO-DEADLINE-CLOSE 구현 보고 (TASK-01~03)

2026-11-22 · 구현·자체 시험 담당 · 인계서 3판 기준 · TASK-04·05 하지 않음.

## 요약

| 항목 | 값 |
|---|---|
| 이 저장소 worktree | `<구현 worktree>`, 브랜치 `role-workflow/16-a3ea9587`, 기준 `0644e9e`(main과 같음) |
| 이 저장소 커밋 | TASK-02 `a43662d2be5d41efea40487d7af5f52ddddb4a94`, TASK-03 `0c8549688e26b3465da649cdce3596d4d394d380` |
| team-kit worktree(`HD`) | `<HD worktree>`, 브랜치 `hejo-deadline-close-20261122`, 기준 `eee573e6` |
| team-kit 커밋 | TASK-01 `cfe6d9d21a96caae8fe09396a5505e87788a4916` |
| 착수 때 `deadline_watch.py` sha256 | `470d272578d84ed32b3bd95c6dcad876781fef2a963c1497fd4a6df2b6f1b4b2`(인계서와 같음) |
| 도달 증거 수준 | 2(자동 시험 + 변이 확인). 운영 공항 실환경은 TASK-04 몫이라 미실행 |

**멈춤 보고 1건(수락 기대값 충돌, 아래 "결정 필요")**: 기존 수락 시험 `AT-SM-02`가 `schemas/hejo-wire-v1.json`의 sha256을 못 박아 두어, 설계 4절이 정한 스키마 추가만으로 이 한 시험이 실패한다. 수락 기대값이라 고치지 않고 그대로 두었다. 이 하나를 뺀 나머지는 모두 통과했다.

## TASK-01 team-kit (일반, 증거 2)

- 바꾼 파일(`HD`): `hermes/plugin-store/team-kit/lib/hermes_team_services/deadline_watch.py`(실제 원본. 같은 이름의 `team-kit/deadline_watch.py`는 이 파일로 가는 git 심볼릭 링크라 따로 고치지 않음), `hermes/bin/hermes-deadlines`, `tests/test_deadline_list.py`(AT-TD-01 키 집합에 `notice?`), `tests/test_deadline_close.py`(새).
- 한 일: `open_items`에 `notice`(`read_ledger`·`notice_of`로 읽기 보호 한 곳), `perform` close 반환에 `closed_now`(잠금 안), `handle` 다시 칠하기 조건 `ok and closed_now`(거짓이면 `status_updated:false`), `close_main`·`main`(공용 진입), 실행 파일은 `main` 호출.
- 설계와 달라진 점(작은 구현 판단 2개):
  1. `close_main`은 잠금 전에 장부를 읽기만 해서 (가) 없는 id → `UNKNOWN_DEADLINE`, (나) 이미 닫힘 → `already_closed:true` 출력 후 끝낸다. AT-DC-05의 "장부 파일 sha256 불변"과 AT-DC-06의 "가짜 홈 전체 불변"을 지키려면 필요했다(`perform`은 이미 닫힌 항목도 장부를 다시 쓰고 `locked`는 잠금 파일을 만든다). 닫을지 말지의 최종 판정은 여전히 `perform`의 잠금 안 `closed_now`다.
  2. 인자 오류(AT-DC-07)는 argparse의 종료 2 대신 `{"error":"INVALID_ARGUMENTS"}` 종료 1로 낸다(인수 형식이 어긋난 호출은 문이 보낼 수 없으므로 문 매핑에 영향 없음).
- 시험(venv `~/.hermes/installs/9cbdaddabb27b1ce/environments/c46cf6bca25e43daa8916acfb5c5607d/venv/bin/python`, pytest는 `PYTHONPATH=~/.local/share/hermes-pytest`):
  - `tests/test_deadline_close.py tests/test_deadline_list.py tests/test_deadline_watch.py` → 60 통과(AT-DC-01~09b 포함, 3회 반복 통과).
  - team-kit `tests` 전체 → 5218 통과, **2 실패**(`test_learning.py::test_host_origin_renderer_is_recognized_and_its_body_restored`, `test_skill_learning.py::...[steer]`). 기준 `eee573e6`를 깨끗한 worktree에서 같은 두 시험을 돌려도 똑같이 실패해서 이번 변경과 무관(미처리 부채로 기록만). 로그 `/tmp/dc-hd-teamkit.log`.
  - `./airport-check` 종료 0(경계 PASS 80→81, 문서·칸 모두 PASS). 로그 `/tmp/dc-hd-airport.log`. 커밋 훅에서도 한 번 더 통과.
- 남은 문제: `./sync`·운영 공항 적용은 하지 않음(TASK-04). 이 브랜치는 운영 저장소 main과 합치지 않았다.

## TASK-02 문·안내판 (고위험, 증거 2) — 다른 모델 검증 필수

- 바꾼 파일: `gate/deadlines.py`, `gate/server.py`, `gate/connection_runtime.py`(`append`에 선택 인자 `deadline`만), `schemas/hejo-wire-v1.json`(추가만, 166줄), `tests/acceptance/test_deadline_close.py`(새), `tests/acceptance/test_deadlines.py`(계획 담당이 이미 고친 AT-TD-10 허용 키 줄을 그대로 반영, 내용 동일).
- 구조: 자식 프로세스 실행(`stdin DEVNULL`·출력 상한·`_reap`)을 `_capture` 한 곳으로 모으고 `list`와 `close`가 같이 쓴다. `close_generation`·세대별 읽기 사전 `_reads`(`_running`은 현재 세대 읽기를 돌려주는 속성으로 두어 기존 시험이 그대로 통과), 닫기는 `asyncio.Lock` 하나 + 잠금 대기 20초(`asyncio.timeout`, 만료 → 미실행 `busy`) + 실행 40초, 연결과 분리(`asyncio.shield`), 닫기 끝나면(성공·실패·시간 초과 모두 `finally`) 세대를 올린 뒤 행동 기록·응답. `invalid_request`·`busy`·`unavailable`은 세대를 올리지 않는다(`busy`는 실행 안 함).
- 고위험 점검:
  - 권한: 기기 출입증 검증 뒤 수신 루프에서만 `deadline_close`를 받는다(AT-DC-35: hello 없음, 틀린 출입증, 취소된 출입증 모두 명령 0번·행동 기록 0줄).
  - 입력 방어: employee는 안내판 패턴 + 현재 명부(`default` 포함), deadline은 team-kit 키 정규식(`\S{1,240}`), outcome 열거. 인자는 배열로만 넘긴다(셸 없음).
  - 동시성: 같은 연결의 다른 프레임(`roster`)은 닫기 중에도 답한다(AT-DC-15). 문 Unix 입구 재진입은 교착 없이 끝난다(AT-DC-17).
  - 개인값: 로그는 `deadline_close outcome=… ok=… repainted=…`만, 제목·id 없음(AT-DC-18). 행동 기록에는 id가 들어간다(설계대로).
- 시험(HEJO_PYTHON 위와 같음, `--basetemp=/tmp/dcb`로 Unix 소켓 경로를 짧게):
  - `tests/acceptance/test_deadline_close.py` → 21 통과(2회). AT-DC-10·11·12·13·14·15·16·16b·16c·17·18·19·35. AT-DC-20은 아래 전체 실행으로 대신.
  - 변이 확인: 세대 고정(`generation=0`)으로 바꾸면 AT-DC-16c 실패, 닫기 잠금 제거하면 AT-DC-16·16b 실패(AT-DC-16은 처음 시험이 약해서 프로세스별 구간 비교로 고친 뒤 실패를 확인).
  - 전체 `pytest gate/tests tests/acceptance`(yaml 의존을 `.build/task02-deps`로 보충한 실행, 로그 `.build/dc-pytest-yaml.log`): 452 통과 / 3 실패. 3 실패 중 둘(`test_delivery_parity::test_native_labels...`, `test_gate_foundation::test_at_hf_08[True]`)은 기준 `0644e9e`에서도 같은 이유로 실패(환경: 모듈·금고 문구). **셋째가 `test_slack_move_gate::test_at_sm_02`(아래 결정 필요).** venv에 `yaml`이 없는 기본 환경에서는 기준에서도 6건 실패(그 6건과 `AT-SM-02`가 이번 실패 목록의 전부, 로그 `/tmp/dc-task02-pytest.log`·`/tmp/dc-base-pytest.log`).
  - `gate.tests.gateway_delivery`: `yaml` 보충 환경에서 `GATEWAY_EXIT clean`.
  - 개인값 검사 `scan_private.py` 종료 0. `git diff --check` 종료 0.

## TASK-03 앱 (일반, 증거 2)

- 바꾼 파일: `app/Sources/TodoDrawerModel.swift`, `TodoDrawerView.swift`, `ConversationController.swift`, `ConversationView.swift`, `AppDelegate.swift`(앱 종료 때 `conversation?.stop()` 한 줄), `app/Tests/TodoDrawerTests.swift`, `app/Tests/TestMain.swift`(새 시험 함수 호출 2곳).
- 구조: 이동 대상은 `selectDrawerCard` 한 곳(알림 글 → 링크 → 선택만, 1:1 분기 삭제). `Card`에 `deadlineRef`·`linked`, 종류 줄은 `badge`에 " · 출처 이름". 컨트롤러가 `pendingClose`(5초)·카드별 `closesInFlight`(75초)·`closesConfirming`(확인 목록 번호)·`closeFailed`를 갖고, 목록 요청에 번호를 붙여 `lastAppliedSeq`보다 앞 번호 응답은 통째로 버린다. 닫기 성공이면 다음 번호 요청을 칸이 닫혀 있어도 한 번 보낸다. 되돌리기 줄은 `TodoDrawerView` 아래쪽 고정 줄, 실패 줄은 경고 옆. 우클릭 메뉴는 `RoomActionItem` 방식.
- 설계와 달라진 점: ① 대기·응답 시간은 설계의 "카드마다 타이머" 대신 컨트롤러의 기존 0.5초 틱과 주입 시계로 센다(`pollDeadlines()`가 `pollDeadlineCloses()`를 먼저 부르므로 칸이 안 보여도 돈다). ② `Card.noticeID` 필드는 소비처가 없어 만들지 않았다(알림 글이 모델에 있을 때만 `messageID`·`key`로 담는다). ③ `ConversationController.stop()`을 새로 두어 앱 종료 때 대기를 보내지 않고 버리고 틱 타이머를 끈다.
- 기존 시험 변경: `AT-TD-26`의 "없음은 alpha 1:1 선택" 한 줄만 `AT-DC-25` 기대("방·링크 불변, 카드 선택")로 바꿨다(인계서 3번 항목). 그 밖의 AT-TD-20~42는 그대로 통과.
- 시험: `TZ=Asia/Seoul bash app/scripts/test.sh` 종료 0(로그 `.build/dc-app-test.log`). `AT-DC-21..34 CARD TARGET, MENU, CLOSE FLOW PASS`, `AT-TD-20..42 ... PASS`. AT-DC-27b는 (가)~(라) 네 경우를 모두 돌린다. 변이 확인: 번호 순서 규칙과 확인 번호 조건을 빼면 AT-DC-27b(가)가 실패.

## 결정 필요 (수락 기대값 충돌)

`tests/acceptance/test_slack_move_gate.py:57-59`(AT-SM-02)는 `hashlib.sha256(schemas/hejo-wire-v1.json) == 'b62f99a6…'`를 요구한다. 설계 4절이 안내판에 `origin`·`notice`·`deadline_close`·`deadline_close_status`를 더하므로(필수) 해시는 `4f365159c687db76249fed494627764f2e8fe741e89a56471642fe983371b7ce`로 바뀐다. 시험 의도는 "SLACK-MOVE가 기록장 레코드 종류·기존 규격을 건드리지 않았다"이므로, 기대값을 새 해시로 올리거나 기존 정의가 불변인지 비교하는 방식으로 바꾸는 것이 맞다고 본다. 수락 시험이라 구현 담당이 고치지 않고 이 한 시험을 실패 상태로 남겼다(작업 문서 명세에도 적혀 있지 않던 항목). **결정 후 계획 담당이 시험 기대값을 갱신하거나 갱신을 지시해 주세요.**

## 검사 요약

| 명령 | 대상 | 결과 |
|---|---|---|
| team-kit pytest(위 3개 파일) | HD `cfe6d9d2` | 60 통과 |
| team-kit pytest 전체 | HD `cfe6d9d2` | 5218 통과·2 실패(기준과 같은 2건) |
| `./airport-check` | HD `cfe6d9d2` | 종료 0 |
| `pytest tests/acceptance/test_deadline_close.py` | hejo `a43662d`+ | 21 통과 |
| `pytest gate/tests tests/acceptance`(yaml 보충) | hejo `0c85496` | 452 통과·3 실패(기준과 같은 2 + AT-SM-02) |
| `TZ=Asia/Seoul bash app/scripts/test.sh` | hejo `0c85496` | 종료 0 |
| `scan_private.py`(Hermes venv) | hejo 작업 트리 | 종료 0 |
| `git diff --check` | hejo | 종료 0 |

`bash scripts/test.sh` 전체는 `set -e`로 pytest 실패(위 기준 실패+AT-SM-02)에서 멈추므로 한 번에 끝까지 못 돌렸다. 앱 부분은 `bash app/scripts/test.sh`로 따로 통과를 확인했다.

## 남은 일·메모

- TASK-04(서버 적용) 전 확인: HD 브랜치 `hejo-deadline-close-20261122`를 운영 저장소 main에 합치는 절차와 `./sync`는 계획 담당·사장 승인 몫이다. 운영 저장소 main은 이 작업 중 `eee573e6` 그대로였다.
- 시험 환경 메모(비밀 아님): 기본 시스템 python3·Hermes venv 둘 다 `pytest`·`yaml`이 없다. pytest는 `PYTHONPATH=~/.local/share/hermes-pytest`, yaml은 계획 폴더 `.build/task02-deps`를 `PYTHONPATH`에 더해 돌렸다. gate 시험은 `--basetemp=/tmp/dcb`(짧은 경로) 필수.
- 미처리 부채(범위 밖, 기록만): HD `test_learning.py`·`test_skill_learning.py` 각 1건 기존 실패, hejo 기준 6건 환경 실패.

## 보완 1 (검증 1차 V-1·V-2)

- 커밋 `54272ad03e7fa7e6c197effbc8f5892c5d926e1d`(브랜치 role-workflow/16-a3ea9587). 로컬 main은 기준 0644e9e 그대로라 merge 없음, `merge-base --is-ancestor main HEAD` 참. 운영 저장소 브랜치는 바꾸지 않음.
- V-1: `TodoDrawerModel.originNames` calendar→캘린더, slack→Slack. `TodoDrawerTests.swift`에 AT-DC-21b(6종+모르는 값 other는 꼬리 없음) 추가.
- V-2: `tests/acceptance/test_slack_move_gate.py`의 고정 해시를 4f365159c687db76249fed494627764f2e8fe741e89a56471642fe983371b7ce로, 주석 'HEJO-DEADLINE-CLOSE added definitions only (verdict V-2)' 추가. 다른 줄 불변.
- 검사: pytest gate/tests tests/acceptance(yaml 보충, --basetemp=/tmp/dcb) 453 통과·2 실패(기준 환경 2건뿐, `.build/dc-pytest-r1.log`). TZ=Asia/Seoul bash app/scripts/test.sh 종료 0(`.build/dc-app-test-r1.log`). scan_private.py 종료 0. git diff --check 종료 0.

## TASK-04 서버 적용 (고위험, 증거 3·4)

### 롤백 기록 (적용 전에 씀, 2026-11-22 23:3x)

- 시작 조건: 진행 중 턴 0(`gateway_restart.running_turns` 읽기 전용 호출 결과 0), 기대 채널 7개. 구현 worktree를 로컬 main(`d3f5b5f`)으로 merge한 커밋 `227ef160694635f8afde36f06515f5136f73dc30`(제품 코드는 검증본 54272ad와 동일, 차이는 문서뿐).
- team-kit 보관본(0700 폴더 `~/.cache/dc-rollback-20261122/`, 폴더 권한 drwx------):
  - `deadline_watch.py` sha256 `470d272578d84ed32b3bd95c6dcad876781fef2a963c1497fd4a6df2b6f1b4b2`(원 위치 `~/.hermes/plugin-store/team-kit/lib/hermes_team_services/deadline_watch.py`, 권한 644)
  - `hermes-deadlines` sha256 `8340115fe460e76a89e529280567af1aa577f62ef6c8a4a24a975b7a55c4535d`(원 위치 `~/.hermes/bin/hermes-deadlines`, 권한 755)
  - 복원 명령: 각 보관본을 같은 폴더의 임시 파일로 복사 후 `mv`(이름 바꾸기), 권한 644·755.
- 교체할 새 파일(HD `cfe6d9d21a96caae8fe09396a5505e87788a4916`): `deadline_watch.py` sha256 `1fa7fddb1531fb288b3029cf25da88693a160c1c96a929e633944a8884b6ad85`, `hermes-deadlines` sha256 `ec8d7158cd8ccf37bda70f048256fabb8fb6be437178602ecda9896be2eccc5a`.
- 문 롤백 기준: 공용 릴리스 `/Users/Shared/hejo/RELEASE` = `e68ae82458a62a1c3d3468041c3d6dee0b576a2b`. 되돌리기: 그 커밋을 임시 worktree로 꺼내 `install/hejo-release`를 실행하고 게이트웨이 재시작 1회, team-kit 보관본도 함께 복원.
- 운영 장부 파일 2개의 sha256 목록을 적용 전·후 비교(기록에는 개수와 목록 해시만): 적용 전 목록 해시 `a32a215b432247b8908261ff22ce62ca3672440cabbbe65aa37a712657d90c1f`.
- 릴리스 대상 확인: `e68ae824..227ef160`의 `gate/ hub/ schemas/ config/ install/` 변경 커밋은 `a43662d`(이 작업)·`91ee402`(문서, gate/README.md)뿐. 변경 파일은 gate/README.md, gate/connection_runtime.py, gate/deadlines.py, gate/server.py, schemas/hejo-wire-v1.json.

### TASK-04 결과 (2026-11-22 23:3x~23:4x)

- 통합: 구현 worktree 브랜치에 로컬 main(`d3f5b5f`)을 merge 커밋 `227ef160694635f8afde36f06515f5136f73dc30`으로 통합(충돌 없음, 제품 코드는 검증본 54272ad와 같음).
- team-kit 교체: 두 실행본을 임시 파일+이름 바꾸기로 교체. 적용 후 sha256 `deadline_watch.py` 1fa7fddb…ad85, `hermes-deadlines` ec8d7158…cc5a(둘 다 HD `cfe6d9d2`와 같음), 권한 644·755 유지.
- `~/.hermes/bin/hermes-deadlines list --json`: 종료 0, `failed` 빈 목록, 직원 6명 가운데 열린 마감 합계 2건(직원 2에만, 가명), `notice` 있는 항목 0. 운영 장부 파일 2개 sha256 목록 적용 전후 동일(LEDGER_SAME). 장부는 닫지 않음.
- HD main: 운영 저장소 main(`99bd8856`)에 `hejo-deadline-close-20261122`를 merge 커밋 **`b32048c813aefa72be778eaa7dca51815a9de429`**로 병합(마감 관련 4파일만, 충돌 없음). `./sync` 종료 0 → 작업 트리 깨끗, `./airport-check` 종료 0. 주의: `./sync`는 원본(`~/.hermes`) 기준으로 사본을 다시 채우므로 시험 파일 2개(`test_deadline_close.py`, `test_deadline_list.py`)가 되돌려져, 원본 쪽 `~/.hermes/plugin-store/team-kit/tests/`에 같은 시험 파일 2개를 복사해 둔 뒤 다시 sync했다(실행 코드 아님, 게이트웨이가 읽지 않음). 다른 작업 파일은 커밋하지 않음, push 안 함. 별도 `commit --only`는 변경이 merge 안에 이미 있어 필요 없었다.
- 문: 롤백 기준 `RELEASE` = `e68ae82458a62a1c3d3468041c3d6dee0b576a2b`. `e68ae824..227ef160`의 gate/hub/schemas/config/install 변경은 `a43662d`·`91ee402`뿐(gate/README.md, connection_runtime.py, deadlines.py, server.py, schemas). `install/hejo-release`(구현 worktree 227ef160 기준) → `RELEASE` = `227ef160694635f8afde36f06515f5136f73dc30`, 공용 릴리스 `gate/`·`schemas/`가 소스와 바이트 동일.
- 재시작 1회(`hermes-connections gateway restart --json`, 시작 직전 진행 중 턴 0): `{"outcome":"done","reason":"OK","connected":7}`. 재시작 뒤 `gateway.log`에 ERROR·Traceback 0.
- 문 읽기 확인: 공용 릴리스 코드(`/Users/Shared/hejo/gate`)의 `Deadlines.list()`를 운영 홈으로 직접 호출(읽기 전용): `deadlines_read items=2 failed=0`, origin은 `reminder`만. **실제 문 로그(gateway.log)에는 재시작 뒤 `deadlines_read`가 아직 없다**(앱이 아직 목록을 요청하지 않음. 칸을 열면 남는다). `deadlines_failed`는 없음.
- 롤백이 필요했던 일은 없었다. 보관본 `~/.cache/dc-rollback-20261122/`(0700)는 사장 확인 전까지 둔다.

## TASK-05 앱 0.2.6(빌드 8) 공개 후보 (고위험, 증거 2)

- 시작 조건: 원격 `github` main(`git ls-remote` 읽기) = 로컬 `public` = `47a424564d4067c697b17b23aedcc0af9ab160ee`(같음, 로컬 추적 ref `github/main`은 오래된 값 0.2.4라 ls-remote로 확인). `95b9041` 뒤 main의 제품 코드(app gate hub schemas install config) 변경 0.
- 버전 올림 커밋 **`cec1f94e33fa06a1b87311e759d193655c756cb5`**(`app/Resources/Info.plist` 0.2.6·8, `tests/acceptance/test_ship.py` 현재 버전 단언 한 줄만).
- 추가 문서 커밋 `d88e2c80f6a74e0f52baee9b35eb193b8758c226`: 이 보고서가 main에 들어간 판에 `<구현 worktree>`·`<HD worktree>` 절대 경로 2줄이 있어 공개 개인값 검사(`absolute_path`)에 걸려, 그 두 줄을 자리표시자로 바꿨다(문서만). 계획 담당 checkout의 impl-report는 이 두 줄이 아직 절대 경로이니 다음 커밋 때 같게 고쳐야 한다.
- 새 public **`98a9f242a74a97a2af6885264cac49da241ad7fa`**, 부모 `47a424564d4067c697b17b23aedcc0af9ab160ee`(0.2.5), 트리 `d520388ca783c51c71162df88fa13877c4e40584`(= 구현 브랜치 HEAD 트리). `install/hejo-publish`를 로컬 작성자 대역(gh 캐시, 원격 git·curl·wget 차단)으로 실행. 차단된 원격 시도 0(`blocked-remote.jsonl` 없음).
- 준비물: `.build/release-0.2.6/prepared.json`(계획 담당 폴더), `hejo-0.2.6-arm64.zip` 6,415,451 bytes, SHA-256 `9a1c318fd63696c5cd3905bab89071711c1779cd17d225f6126eb46ad8fc5a78`. 기본 배포 빌드(무시된 Google 입력을 기존 경로로, 링크만 두고 열람 안 함) BuildInfo `dirty:false`, 트리 일치, 압축 해제본 실행 파일이 빌드와 바이트 동일.
- 연속성: 0.2.6·8 > 이전 준비물 0.2.5·7 > …, 설치본은 0.2.5, 업데이트 공개 키 0.2.5 준비물과 같음, 코드 서명 Authority가 설치된 앱과 같음. codesign 검증, Sparkle `sign_update --verify`, 별도 Ed25519 공개 키 검증 모두 통과. 설치 앱은 0.2.5 그대로.
- 공개 트리 `gate/`·`schemas/`·`hub/`·`config/`·`install/` = 공용 릴리스 실행본(TASK-04 뒤 `RELEASE 227ef160`)과 바이트 동일(차이 0, README도 같음).
- 검증(깨끗한 public checkout, 짧은 TMPDIR `/tmp/f26`, resolve한 임시 HERMES_HOME, `pgrep -f app-tests` 종료 1, TZ=Asia/Seoul):

| 명령 | 결과 | 로그(`.build/dc-release-0.2.6/`) |
|---|---|---|
| `pytest gate/tests tests/acceptance`(yaml 보충, `HEJO_TEAM_KIT_LIB`) | 454 통과·1 실패(`test_delivery_parity::test_native_labels_outcome_and_repeat_are_idempotent`: Hermes 본체 문구 키 불일치로 기준 0644e9e에서도 실패하는 환경 문제) | `pytest.log` |
| `gate.tests.gateway_delivery` | 종료 0 | `gwdelivery.log` |
| `bash app/scripts/test.sh` | 종료 0 | `app-full.log` |
| 기본 배포 빌드 / `hejo-ship prepare` | 각각 0 | `default-build.log`, `prepare.log` |
| 압축 해제본 codesign·Sparkle·Ed25519 | 각각 0 | (명령 출력, 위 내용) |

  `bash scripts/test.sh` 한 번에는 위 pytest 1건 때문에 끝까지 못 가므로 세 단계를 따로 돌렸다.
  전체 시험 로그 PASS 줄 인용:
```text
AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS
AT-DC-21..34 CARD TARGET, MENU, CLOSE FLOW PASS
AT-FF-40 dark/light PIXEL PASS alpha=1.0, AT-FF-41 dark/light PIXEL PASS alpha=1.0
AT-FF-90/92/93 PLACEMENT BOUNDARIES PASS
```
  문 시험 AT-DC-10~20·35는 `tests/acceptance/test_deadline_close.py` 21건이 pytest 454 통과에 들어 있다(개별 PASS 문자열은 출력하지 않는 pytest 시험).
- 사장용 명령 두 줄(계획 담당 폴더 `hermes-hejo`에서):
```sh
git push github 98a9f242a74a97a2af6885264cac49da241ad7fa:refs/heads/main
install/hejo-ship publish --approve-commit 98a9f242a74a97a2af6885264cac49da241ad7fa --prepared .build/release-0.2.6/prepared.json
```
