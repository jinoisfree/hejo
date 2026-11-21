# HEJO-SLACK-MOVE 구현 인계 보고

## 현재 판단: TASK-02~05 구현·자체 시험·분리 전체 검사 통과

[확인] 구현 검토 2차와 설계·인계 7판(`892d54ed1ddecbe96eddc1945494f1f8c6583777`)으로 재개했다. 기본 프로필 작성자 D-3를 반영했다. TASK-03 커밋 `57d00939c04d81d6c033ef5a31999fe02e35a383`의 분리 전체 검사가 종료 0으로 통과했다. TASK-04는 운영 worktree의 최종 제품 커밋 `22f8aa629bdf828e9b02085531bfd0819d071139`에서 회귀 시험 245개와 경계 검사를 통과했다. 공개 커밋 `0dfe9db8aab7373ebee6fc456deaf0134eb00e05`와 이 team-kit 커밋을 각각 고정한 전체 검사도 종료 0이다. TASK-05는 설계 8판 반영까지 구현·커밋하고 자체 시험을 마쳤다. 공개·운영 커밋을 고정한 분리 전체 검사도 종료 0으로 통과했다(아래 마지막 절). TASK-06~08은 미착수다. 아래 S-1·S-2는 이전 중단 기록이다.

- 받은 지시: [handoff.md](handoff.md) 7판, [verdict.md](verdict.md) 구현 검토 2차, TASK-02~08. 최신 계획 보완 기준 `892d54ed1ddecbe96eddc1945494f1f8c6583777`, 제품 기준 `cb06e7d`. 고위험, 필요 증거 수준 2, 연합개발.
- 다른 작업의 `app/` 및 HEJO-FINDER-FOLDERS 문서 변경은 보존하며 커밋에 포함하지 않는다. 전체 검사는 TASK 커밋을 임시 detached worktree로 꺼내 실행한다.
- 진행 중 추가된 인계 `d28f72ed8abbde1f5a84dc6425e12ffbf99af6b1`도 확인했다. 프로젝트 허브는 범위 밖이며, 앱 시험 전 다른 `app-tests` 실행을 확인한다. 다른 작업이 맡은 `app_setup.py`·`app_connect.py`는 고치지 않는다.
- 운영 저장소 최초 착수 HEAD는 `f3318572b9cbd85fccb54347872feca8915532cd`였다. 당시 대상 실행본·기준본 Python 소스 233개의 SHA-256이 같았다(`.build/slack-move-baseline-check.json`). team-kit 착수 전 최신 HEAD와 파일별 해시를 다시 확인한다.
- 운영 저장소 임시 worktree에 TASK-04 제품·시험 8개 파일을 변경했다. 다음 TASK-05의 예비 대조는 운영 저장소 최신 HEAD `d7208c11c23ddb0dacddbe3e225864058f263006`에서 대상 Python 29개가 실행본·작업 기준과 모두 같았다(`task05-preliminary-hashes.json`). TASK-05 수정 직전 같은 운영 HEAD에서 대상 29개를 다시 대조해 모두 일치했다(`task05-edit-hashes.json`). 운영 적용·재시작·실제 전송·비밀 파일 열기·본체·ddots·앱 소스 수정·푸시는 하지 않았다.
- 직접 구현·시험했으며 하위 에이전트는 사용하지 않았다.

## TASK-02: 서버 안 전용 입구

### 책임과 변경

규격의 첫 커밋은 `9f7dfb29db663836ea094c8c2d1ba0f727099afe`이며 `schemas/hejo-local-v1.json`만 포함한다. TASK-02 구현 커밋은 `2911232cbea8c0e48fc26aeca2b925050194bd13`이다. 검사할 정확한 커밋과 결과는 아래 증거 기록에 남긴다.

| 파일 | 변경 이유 |
|---|---|
| `schemas/hejo-local-v1.json` | 다섯 HTTP 동작, 요청·응답, 바이트 한도, 요청 열쇠와 방 충돌 규격. PATCH 상태는 null을 허용하지 않음 |
| `gate/local.py` | 기본 프로필 Unix HTTP 입구. 소켓 0600·기존 소켓 보호·종료 정리, 허용 필드, 직원 글만 작성, 기록장 기반 중복 판정, 작성자 검사, 조회, 방 충돌 |
| `gate/server.py` | 문의 시작·종료에 입구 연결. TCP에 로컬 경로를 등록하지 않음 |
| `gate/adapter.py` | 입구 출처·요청 열쇠를 기존 글의 내부 메타에 함께 저장 |
| `gate/rooms.py` | 기존 방 저장 검사를 추출해 앱과 입구가 공유. TASK-03의 주인 규칙은 아직 미반영 |
| `gate/README.md` | 입구 규격 참조와 시험 경로 안내 |
| `tests/acceptance/test_slack_move_gate.py` | AT-SM-01~09·30·31 및 V-5의 실제 Unix HTTP 시험 |

기록 쓰기는 기존 문·기록장, 첨부는 기존 경로 검사·복사·승격·등록이 맡는다. 별도 중복 표가 없고 한 요청의 첨부는 한 메시지에 함께 등록한다. 삭제는 기존 배달 범위 컨텍스트로 작성자를 지정해 기존 삭제 함수를 부른다. adapter 내부 메타 전달과 rooms 검사 추출은 검토 1차에서 필요한 최소 변경으로 수용됐다. 앱 규격 파일·레코드 종류·수락 명세는 변경하지 않았다.

의미 변경은 설계가 허용한 로컬 전송 입구 추가다. 기존 TCP 동작과 앱↔문 계약은 유지한다. 입구와 앱의 검사는 방 저장 함수 한 곳을 사용한다. Slack 공존 분기와 전송 상태 변경은 아직 구현하지 않았다.

### 검토 지적 반영

- V-3: 동일 임시 홈에 **새 어댑터 객체**를 연결해 기록장 파일을 다시 읽은 뒤 원래 글 id·스레드가 반환됨을 검사한다. 새 객체는 시험 종료 때 직접 닫는다.
- V-4: 임시 코드 사본에서 `authored`의 작성자 비교 및 `post`의 열쇠 조회를 각각 한 번 제거했다. AT-SM-04·08이 각각 실패했다. 원본 해시 불변을 확인했고 임시 사본은 제거했다.
- D-1·AT-SM-09: 기록 실패의 `503 / journal_write_failed`, 기록 불변, 쓰기 복구 후 같은 열쇠로 정확히 한 글, 이후 중복 응답을 확인한다.
- D-2·AT-SM-09: PATCH null을 규격에서 제외하고 중복 수동 검사를 제거했다. 규격 검사와 실제 HTTP 거절·글 불변, 세 유효 상태, POST null·생략 허용을 확인한다.
- V-5: 본문 수정 후 상태 기록만 실패하면 본문은 바뀌고 상태는 이전 값으로 남는다. 같은 PATCH를 재전송하면 본문·상태가 요청값으로 복구되고 메시지 수는 하나임을 고정했다.
- V-1: TASK-02 당시 전체 실패 기록은 보존하며, 최신 TASK-03 커밋의 분리 전체 검사 종료 0을 확보했다. V-2: TASK-03 구현·검증 완료, TASK-04~08 잔여.

### 실행 증거

게이트웨이 Python과 로컬 `.build/connections-env.sh`의 의존성, 임시 홈·가짜 명부를 썼다. 로그 기준 폴더는 `.build/slack-move/`다. 필요한 증거 수준 2를 입구 범위에서 확인했으며 전체 작업은 미완료다.

| 명령·검사 | 실제 결과 | 로그 |
|---|---|---|
| `python -m pytest tests/acceptance/test_slack_move_gate.py gate/tests/test_rooms.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` (짧은 임시 `--basetemp`) | 종료 0, 19 passed | `task02-revision-tests.log`, `.exit` |
| `python .build/slack-move/mutation_check.py` | 실행기 종료 0. 작성자·중복 변형의 pytest는 각각 종료 1·1 failed(의도한 결함 검출). 원본 불변 | `mutation-author.log`, `mutation-dedup.log`, `mutation-results.json` |
| 커밋 `2911232cbea8c0e48fc26aeca2b925050194bd13`의 detached worktree에서 `bash scripts/test.sh` | 종료 1. Python 428 passed, 실제 게이트웨이 정상 종료. Swift 시험의 AT92 key focus 단언 실패 | `task02-isolated-full.log`, `task02-isolated-full.json` |
| TASK-02 보완 후 `python scripts/scan_private.py` | 종료 0 | `task02-revision-scan.log`, `.exit` |
| 이전 변경본 `bash scripts/test.sh` | 종료 1. Python 426 passed, 실제 게이트웨이 정상 종료. 타 작업의 앱 파일 변경으로 Swift 빌드 실패. 최신 전체 통과 증거로 쓰지 않음 | `task02-full.log`, `task02-full.exit` |

초기 기본 임시 경로의 문 시작 실패는 짧은 pytest 기본 경로를 사용해 해소했다. 최초 시험 코드의 삭제 응답 프레임 이름 오류는 기존 계약의 `delete`와 `scope=thread`로 바로잡았다. 수락 기대값은 변경하지 않았다. 이전 중단 시점의 파일 해시는 `stop-evidence.json`에 보존되어 있다.

## TASK-03: 구현·검증

### 7판 반영

`gate/adapter.py`의 `_sending_employee`가 send·입력 중 표시·파일·URL 이미지 네 자리와 입력 중 표시 종료의 작성자를 정한다. 방 글에 직원 표시가 없으면 기본 프로필 자신이다. 대표 대체를 지웠고 1:1과 명시된 작성자는 유지했다. `gate/README.md`에 방 예약·작성자와 스레드 주인을 설명했다. AT-SM-11b는 실제 게이트웨이에서 기본 프로필이 비구성원·구성원이나 대표 아님·대표인 경우의 예약과 파일·그림, 실제 WS 사장 글에 대한 답글을 검사한다. URL 이미지는 가짜 HTTP 응답으로 실제 첨부 경로를 검사한다. 기존 수락 명세·기존 시험 기대값은 수정하지 않았다.

- 작성자를 대표로 되돌린 임시 사본에서 실제 예약 시험 실패: mutation 실행기 종료 0, 변형 pytest 종료 1·1 failed. 원본 보존(`.build/slack-move/task03-mutation-results.json`, `mutation-room-author.log`).
- 최초 전체 Python 실행은 431 passed·3 failed(종료 1), 국소 재확인은 22 passed·3 failed였다. 새 시험에서 기본 프로필의 입력 중 표시가 끝나지 않는 문제를 발견했다. 본체는 기본 프로필의 `_owner_profile`을 None으로 두는데, 기존 stop_typing은 None을 기본값으로 바꾸지 않아 작성자 default와 맞지 않았다. 같은 표시의 종료 소비자인 stop_typing도 공통 계산을 쓰게 했다. 수신자·1:1 동작은 그대로이며 기존 시험을 바꾸지 않았다(`task03-python.log`, `task03-revision-final.log`).
- 기존 시험에서 대표 대체에 기대는 경로는 발견되지 않았다. 새 기본 프로필 예약 실패 시험은 D-3 수정 후 통과했다.

- 최종 국소 검사: `python -m pytest tests/acceptance/test_slack_move_gate.py gate/tests/test_rooms.py gate/tests/test_progress.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` → 종료 0, 38 passed(`.build/slack-move/task03-final-targeted.log`, `.exit`). 개인값 검사 종료 0(`task03-scan.log`, `.exit`), diff 공백 검사 종료 0.

TASK-03 제품 커밋: `57d00939c04d81d6c033ef5a31999fe02e35a383`. 분리 전체 검사 `bash scripts/test.sh`는 종료 0: Python 434 passed, 실제 게이트웨이 정상 종료, 앱·모든 연동 fixture·훅 시험 9개 통과. 로그 `.build/slack-move/task03-isolated-full.log`, 커밋·실제 종료 코드 `.build/slack-move/task03-isolated-full.json`. 검사 worktree는 제거했다. 앱 도중 UI 서비스 통신 경고가 나타났지만 이후 정상 진행해 전체가 통과했다. 이전 TASK-02 커밋의 실패 원인이 확인됐다는 뜻은 아니다. 이 커밋과 부모의 `git diff --stat -- app`는 빈 결과다. 이전 TASK-02 커밋부터의 범위에는 타 작업 `b21dd94`의 앱 두 파일 변경이 있으므로 그 구간 전체가 빈 diff라고 기록하지 않는다. TASK-03 자체는 앱을 바꾸지 않았다.

### 6판 중단 당시 기록(아래 미커밋·미도달 상태는 당시 상태)

- `gate/__init__.py`: `room:<UUID>` 대상 문법. `gate/rooms.py`: 첫 글이 직원이면 작성자, 사장 글이면 내부 수신자를 현재 구성원·명부로 거른다. `gate/adapter.py`는 기존 `recipients`에 기록장·스레드를 전달한다. `room_save_record` 추출 위에 작업했다.
- `tests/acceptance/test_slack_move_gate.py`: AT-SM-20~22의 실제 WS 수신·주인 유지·멘션·구성원 제거·targeted·1:1 및 AT-SM-12 문법을 추가했다. AT-SM-10~12는 기존 `gate.tests.gateway_delivery`의 격리 감사와 실제 `start_gateway`를 그대로 쓰고 시나리오만 바꾼다. 본체·전송 경로를 대역으로 바꾸지 않는다.
- 실행: TASK-03 미커밋 변경본에서 `python -m pytest tests/acceptance/test_slack_move_gate.py gate/tests/test_rooms.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` → **종료 1, 21 passed·1 failed**. 로그 `task03-targeted.log`, `.exit`. 새 예약 시험이 실패했으며 AT-SM-10의 B 보고 두 건과 서로 다른 스레드, 없는 방 거절까지 확인한 뒤 멈췄다. 뒤의 삭제 방·기존 대상 검사는 이 실행에서 도달하지 못했다.
- TASK-03 파일은 커밋하지 않았다. 완료나 전체 회귀 통과로 취급하지 않는다. README 갱신·분리 전체 검사·TASK-03 커밋은 미실행이다.

## 이전 멈춤 보고와 7판 처분

### S-1: 분리 전체 검사에서도 앱 포커스 단언 실패

[확인] `.build/slack-move/verify-task02`를 TASK-02 커밋 `2911232cbea8c0e48fc26aeca2b925050194bd13`의 detached worktree로 만들고 전체 검사를 실행했다. 원래 폴더의 앱 미커밋 변경은 들어가지 않았다. `app/Tests/TestMain.swift:216`의 `controller.panel.isKeyWindow` 단언(`AT92 opening takes key focus (V08 replaces old AT47)`)이 실패했다. 컴파일은 끝났고 Python 428개와 실제 게이트웨이 검사는 통과했다. 단순 컴파일 충돌이었던 이전 실패와 다르며, UI 환경 경합인지 기존 앱 결함인지 아직 구분하지 못했다. 앱을 고치거나 기준을 완화하지 않았다.

worktree의 추적 변경이 없음을 확인한 뒤 `git worktree remove`로 제거했다. 로그와 검사 커밋은 원래 저장소의 `.build/slack-move/`에 보존했다. 선택지: 앱 담당이 포커스 실패를 조사하고 동일 커밋의 실행 환경을 확보하거나, 계획 담당이 미해소 전체 검사와 독립적으로 문·team-kit 갈래를 진행할지 명시한다. 권고: 앱 코드 수정 없이 실행 환경부터 별도 확인하고, 이 결과를 통과로 바꾸지 않는다.

### S-2: 기본 프로필 예약은 방 대표로 작성자를 바꿔 구성원 검사를 통과함

[확인] AT-SM-11의 구성원 아닌 C를 기본 프로필(`default`)로 둔 실제 게이트웨이 시험에서, 방 구성원 `alpha`·`beta`, 대표 `alpha`인 방으로 C가 예약 보고를 보내면 실패 대신 성공한다. 방을 만든 것과 B의 두 번 예약은 실제 입구·실제 스케줄러를 거친다. 다른 플랫폼으로 보내지는 않는다.

근거: `gate/adapter.py`의 `forwarder`는 기본 프로필을 제외하고, `_forward`는 전달자에만 `hermes_profile`을 붙인다. `send`는 `metadata.hermes_profile`이 없으면 방 대표를 직원으로 정한다. 본체 스케줄러의 `_live_route_metadata`는 job·notify·thread 정보를 넘기며 직원 id를 넣지 않는다. 따라서 기본 어댑터의 예약은 방 대표로 기록된다. design 3.2의 “새 코드는 문법뿐”은 이 경로를 다루지 못한다. `send`의 작성자 선택까지 바꾸는 것은 지정된 TASK-03 변경 위치(`receive`의 받는 직원 계산)를 넘으므로 구현 규칙 2절에 따라 멈춘다.

실패 단언에 오류 반환값과 추가된 가짜 기록을 표시해 한 번 더 확인했다(`task03-scheduler-stop.log`, `.exit`). 재확인 결과는 종료 1, 1 failed·14 deselected이며 반환 오류는 null, 추가된 글의 작성자는 `alpha`, 본문은 `Outsider`였다. 기대한 `room_member_required`는 바꾸지 않았다. 선택지: 기본 프로필의 예약 작성자를 전달자와 동일하게 명시하도록 설계·영향 범위를 보완하거나 기본 프로필 예약의 적용 범위를 명확히 정한다. 권고: 실제 보내는 프로필의 작성자와 구성원 검사를 보장하고, 본체를 고치지 않는 문 쪽 책임으로 보완한다. 기본 프로필을 시험에서 빼거나 성공을 허용해 통과시키지 않는다.

## TASK-04 착수 준비(제품 변경 전)

운영 저장소 HEAD `f3318572b9cbd85fccb54347872feca8915532cd`를 다시 확인했다. 대상 Python 파일 233개의 기준 커밋·실행본 SHA-256은 모두 일치했다(`.build/slack-move/task04-baseline-check.json`). 운영 저장소에 다른 설정·학습 변경이 있어 건드리지 않고 해당 HEAD로 임시 worktree 브랜치 `hejo-slack-move-20261121`을 만들었다. 로컬 worktree 위치는 상태 인계에만 적는다. 새 worktree의 제품 코드는 아직 변경하지 않았다.

- 변경 전 `python airport-check --snapshot .`: 종료 0, boundary count=382·document count=0·compartments count=0. 기준선은 바꾸지 않았다(`.build/slack-move/task04-baseline-airport.log`, `.exit`). 임시 HOME·HERMES_HOME·HERMES_ROOT, 게이트웨이 Python 사용. 운영 모드의 조립 검사로 대체 주장하지 않는다.
- 변경 전 공통 Slack 전송의 가짜 요청 기록: 종료 0, 올리기·고치기·지우기·스레드 읽기·대화 읽기와 그림 업로드의 요청 총 8건(`task04-slack-baseline.json`, `.log`, `.exit`). 가짜 명부·금고·지시서·토큰 파일과 외부 네트워크 차단 감사 안에서 실행했다. 이것은 공통 HTTP 기준 기록이며 TASK-05·06의 모든 호출 경로 회귀 자료는 아직 수집하지 않았다. 초기 기록 도우미가 가짜 업로드 응답의 status를 빠뜨려 실패했고, 응답 대역을 실제 인터페이스에 맞춰 수정했다. 제품 코드는 변경하지 않았다.

## TASK-04: 공통 전송과 보고 복구

운영 저장소의 분리 worktree에서 구현했다. 기준 `f3318572b9cbd85fccb54347872feca8915532cd`, 제품·시험 커밋 `b4a240e046b68e962af9f13b0471e9beba605cf4`, 편집 저장 실패 보완 `c8b31f3177d182a7c6b61e2ddaabf09b43582f7e`, 4xx 거절의 보고 종료 보완 `22f8aa629bdf828e9b02085531bfd0819d071139`가 최종 제품 커밋이다. 기존 파일 세 개의 실행본 SHA-256을 수정 직전에 다시 대조했고 모두 일치했다(`.build/slack-move/task04-edit-hashes.json`). 커밋 뒤 실행본 불변도 확인했다(`task04-final-scope.json`). 실행본·운영 설정·본체·앱은 바꾸지 않았다.

### 변경과 호출 계약

- `TS/delivery.py`: 지시서 스위치 한 곳, 직책 키와 대상 검증, Unix HTTP 전송, 4xx 영구 거절과 그 밖의 실패 구분, 조각 전송·고치기·삭제·읽기, 그림·체크 목록·버튼의 마지막 조각 배치. 한도는 규격과 대조하는 시험으로 고정한다. TCP 우회나 새 재시도 큐는 없다.
- `TS/learning_report.py`, `TS/learning.py`: 기존 Slack 함수의 HTTP 본문은 그대로 두고 hejo 공통 전송으로 연결했다. Slack 쓰기 구현은 hejo 모드에서 거절하며 읽기는 허용한다. 학습 보고의 플랫폼·열쇠·조각 상태를 기존 보고 파일에 저장한다.
- `TS/skill_report.py`: AT-SM-46의 “스레드로 잇는 보고 하나”로 스킬 보고를 연결했다. 학습 보고와 같은 조각 복구 함수를 쓰며 기존 `team_skills_` 발생 건 표식을 유지한다. TASK-04의 스레드 보고 검증을 위한 변경이고 나머지 직접 전송 경로는 TASK-06에 남아 있다.
- 새 시험 `tests/test_delivery_hejo.py`, 별도 프로세스 도우미 `tests/helpers/delivery_report_worker.py`, 작업 전 가짜 Slack 요청 두 자료를 운영 worktree에 추가했다. 통합 시험은 `HEJO_GATE_SOURCE`로 이 저장소 checkout을 받고, 실제 어댑터와 Unix 입구를 임시 홈에 띄운다. 해당 환경 값이 없으면 이 통합 묶음은 건너뛰므로 아래 증거는 반드시 값을 준 실행이다(건너뜀 0).

재전송 호출자는 `delivery.post(..., client_id=발생건값, state=자기상태항목, save=동기저장함수)`를 쓴다. 영속 상태를 준 hejo 호출에는 열쇠가 필수다. 조각 목록·열쇠·꾸밈을 첫 요청 전에 저장하고, 다시 실행하면 저장된 조각 열쇠를 읽어 첫 조각부터 올린다. 결과의 `head_id`는 첫 글, `msg_id`는 버튼이 달린 마지막 글, `thread`는 별도 스레드 id다. 호환 함수의 `ts`는 마지막 **글** id이며 스레드로 쓰지 않는다. `read_thread`의 각 행은 규격 그대로 `msg_id`와 `seq`를 쓴다. `clicked_message_id(event)`와 `thread_key(event)`가 버튼 글·스레드를 따로 읽는다.

전송 실패는 호출자가 처리한다. `Refused.permanent`는 4xx만 참이며, 학습·스킬 보고는 이 경우 실패 사유와 조각 번호를 `delivery_error`에 적고 해당 회차를 끝낸다. 다음 실행에서 그 회차를 다시 올리거나 다음 날짜의 보고를 막지 않는다. 보내지 못한 부록은 전달 완료로 확인하지 않는다. 503·연결 끊김은 미완료 상태와 같은 열쇠를 유지한다. 이는 기존 design 3.1 D-1의 구현 보완이며 요구 변경이 아니다.

긴 글 고치기는 기존 조각을 고치고 남는 조각을 지우거나 같은 스레드에 더한다. PATCH는 체크 목록·그림을 옮기거나 상태를 null로 지울 수 없으므로, 마지막 조각 위치가 달라지거나 이 꾸밈이 바뀌면 필요한 뒷부분을 지우고 새 발생 건 열쇠로 다시 올린다. 이 편집 계획도 요청 전에 같은 상태 항목에 저장하며 받은 새 글 id를 반환한다. 앞 조각 id와 스레드는 유지한다. 문 규격·수락 기준은 바꾸지 않았다.

| 호출자 | 다시 보내기 | 발생 건 값·저장 시점 |
|---|---|---|
| 학습 보고 | 다음 실행 | 기존 `team_learning_` 표식(홈·날짜·보고 조각), 조각의 `client_id`에 첫 요청 전 저장. 내부 긴 글 조각은 번호를 붙여 별도 저장 |
| 스킬 보고 | 다음 실행 | 기존 `team_skills_` 표식, 같은 방식 |
| 공통 함수의 일회성 알림 | 호출자가 정함 | 상태·열쇠 없이 호출 가능. 실패를 그대로 올리며 자체 재시도 없음. 나머지 호출자별 분류는 TASK-05·06 |

### 실행 증거

게이트웨이 Python, 임시 홈과 가짜 외부 응답만 사용했다. 로그는 `.build/slack-move/` 아래다.

| 명령·범위 | 실제 결과 | 로그 |
|---|---|---|
| `pytest test_delivery_hejo.py` | 종료 0, 21 passed. AT-SM-40~45 공통 경로, 46 학습·스킬 보고, 47·48 실제 문, 49 정기 보고 부분 | `task04-targeted-5.log`, `.exit` |
| `pytest test_delivery_hejo.py test_learning.py test_learning_report.py test_learning_report_status.py test_skill_report.py test_slack_blocks.py` | 종료 0, 242 passed | `task04-regression.log`, `.exit` |
| 보완 뒤 `pytest test_delivery_hejo.py` | 종료 0, 22 passed. 편집 계획 저장이 실패한 같은 메모리 객체로 다시 호출해도, 저장 성공 전에 문에 쓰지 않음을 추가 확인 | `task04-revision.log`, `.exit` |
| 4xx 보완 뒤 전송·학습 보고·스킬 보고 시험 | 종료 0, 115 passed | `task04-d1.log`, `.exit` |
| 최종 `22f8aa62` detached 사본의 위 6개 시험 파일 | 종료 0, 245 passed. 새 전송 묶음 24개 포함, 건너뜀 0 | `task04-reviewed-regression.log`, `.json` |
| `python .build/slack-move/task04_mutation.py` | 실행기 종료 0. 조각 열쇠 중복 변형은 4 failed, 요청 전 저장 제거 변형은 1 failed·3 passed. 각 pytest 종료 1, 원본 불변 | `task04-mutation-results.json`, `task04-mutation-piece-key.log`, `task04-mutation-intent-save.log` |
| `python airport-check --snapshot .` | 변경 중 검사 종료 0, boundary=382·document=0·compartments=0. 커밋 훅도 같은 검사 통과. 기준선 변경 없음 | `task04-airport.log`, `.exit` |
| 제품 커밋 `b4a240e0`에서 `python airport-check --snapshot .` | 종료 0, 같은 집계. 보완 커밋의 인덱스 검사 훅도 통과 | `task04-commit-airport.log`, `.json` |
| 최종 `22f8aa62` detached 사본의 `python airport-check --snapshot .` | 종료 0, boundary=382·document=0·compartments=0, 기준선 변경 없음 | `task04-reviewed-airport.log`, `.json` |

AT-SM-46은 학습·스킬 보고를 각각 별도 프로세스로 실행했다. 가짜 Unix 입구가 기록 후 연결을 끊는 두 지점과, 응답을 받은 뒤 상태 저장 직전에 SIGKILL하는 지점을 검사했다. 재실행은 디스크 상태만 읽고, 입구는 요청마다 열쇠가 이미 파일에 있는지 확인한다. AT-SM-47·48은 실제 문의 기록 후 HTTP 연결을 끊었으며, 재시작 경우에는 같은 임시 홈에 새 어댑터 객체를 만들어 기록장을 다시 읽었다. 중복 0, 한 스레드, 조각 순서·버튼 위치·완료 뒤 재실행의 기록장 불변을 확인했다.

초기 신규 시험 실패는 허용 목록 밖 체크 목록을 시험에 넣은 점과, 상위 fixture가 지운 gate 경로 환경 값을 자식 프로세스에 다시 전달하지 않은 점이었다. 입력을 기존 허용 목록으로 맞추고 경로를 명시했다. 제품 계약이나 기존 시험 기대값은 수정하지 않았다. 변형 실행기는 “모든 경우가 실패”라는 실행기 자체 조건을 “결함이 검출됨”으로 바로잡았다(저장 제거는 첫 응답 유실 때 검출되고, 뒤 조각까지 진행한 경우에는 이후 저장에 포함된다).

최초 전체 검사는 공개 저장소 `d28f72ed8abbde1f5a84dc6425e12ffbf99af6b1`의 detached worktree와 team-kit 작업 worktree를 조합해 시작했다. 검사 전에 다른 앱 시험 프로세스가 없음을 확인했으며 대기는 없었다(`task04-app-check.json`). Python 단계 뒤 자체 검토에서 편집 계획의 첫 저장이 실패한 같은 객체를 재사용하는 경우도 요청 전에 다시 저장해야 함을 찾아 보완했다. 따라서 이 최초 실행은 단일 team-kit 커밋의 최종 증거로 쓰지 않고, 보완 커밋도 detached 사본으로 고정해 전체 검사를 다시 한다. 새 인계의 앱 시험 동시 실행 방지 규칙과 프로젝트 허브 범위 밖 결정은 확인했고, 해당 파일은 고치지 않았다.

이 최초 실행은 종료 0이었다(`task04-isolated-full.log`, `.json`). 다음으로 공개 저장소 `0dfe9db8aab7373ebee6fc456deaf0134eb00e05`와 team-kit `c8b31f31`을 각각 고정한 전체 검사도 종료 0이었다(`task04-final-isolated-full.log`, `.json`). 마지막 4xx 보완 뒤에는 같은 공개 커밋과 최종 team-kit `22f8aa62`를 고정해 **전체 검사 종료 0**을 확인했다: Python 434 passed, 실제 게이트웨이 정상 종료, 앱·연동 fixture·훅 시험 9개 통과(`task04-reviewed-isolated-full.log`, 두 커밋을 적은 `.json`). 각 검사 전 앱 시험 프로세스 없음·대기 없음과 UTC 시각은 `task04-final-app-check.json`, `task04-reviewed-app-check.json`에 있다. 검사 사본들은 제거했고 구현을 이어갈 운영 worktree만 유지한다. 운영 저장소의 조립·적용 검사는 실행하지 않았다.

개인값 검사 `python scripts/scan_private.py`와 작업 파일 공백 검사도 종료 0이다(`task04-final-scan.log`, `.exit`). 전체 검사 도중 다른 작업이 앱 변경을 커밋했으므로 이후 공개 HEAD 전체를 검사했다고 주장하지 않는다. TASK-04는 공개 제품 코드를 바꾸지 않았고, 검사 대상 공개 커밋과 현재의 문·규격·이 작업 문 시험 소스는 같음을 확인했다. 다음 TASK에서 검사할 때도 정확한 두 저장소 커밋을 고정한다.

## TASK-05 이전 진행 기록: 인스타 보완·네이버톡 착수 전 중단

기준 운영 worktree는 `22f8aa629bdf828e9b02085531bfd0819d071139`이다. 운영 main은 재개 시에도 `d7208c11c23ddb0dacddbe3e225864058f263006`였다. 최초 대상 Python 29개 실행본 대조와 이번 새 수정 대상 6개의 최신 main·worktree·실행본 SHA-256 대조가 일치했다(`task05-edit-hashes.json`, `task05-followup-hashes.json`). 이전 미커밋 8개 파일은 `task05-partial-source.json`과 모두 일치한 상태에서 이어갔다. 현재 검토 대상 파일 해시는 `task05-followup-source.json`에 둔다. 공개 문 소스는 `173697fcf438e4bbed199d2cde67b31603e4725c` 기준이며, 뒤의 `4b12880eef414026f2cc753950dc62e7f85d2b31`은 다른 작업의 문서 두 개만 바뀌었다. 이 공개 HEAD 전체의 앱 검사 통과를 주장하지 않는다.

| 파일(CP의 인스타 플러그인 아래) | 현재 변경 |
|---|---|
| `watch.py` | 고객별 hejo 스레드, 영속 초안·수신/결과 알림·다시 보이기·시간별 요약·실패/회복 알림, 조각 상태와 편집 재개. 요약의 Slack 첨부 본문을 hejo 일반 본문으로 보존. 결과 재시도가 이미 새로 이어진 고객 스레드를 과거 값으로 되돌리지 않음 |
| `__init__.py` | hejo 승인 훅·문맥 훅, 클릭 글 id/스레드 분리, 바로 앞 글의 순번 검사, 초안 등록 시각을 승인 작업자까지 전달, 가이드 제안의 플랫폼 대조 |
| `learning.py`, `learning_report.py` | hejo 사장 원문 검증 함수 재사용, 학습 문맥, 공통 영속 보고, hejo 문/글 식별자 저장. Slack 원문 링크를 hejo 보고에 만들지 않음 |
| `feed.py`, `feed_extra.py`, `feed_runner.py` | hejo 사장 세션 대응, 예약·댓글 알림의 공통 전송 연결, 기존 가이드 제안 행에 영속 전송 상태와 별도 글/스레드 저장. Slack의 기존 한 번 시도 정책 유지 |
| `tests/test_hejo_draft_delivery.py`, `test_hejo_approval_integration.py` | 실제 문·team-kit·승인 함수·가짜 고객 API 통합, 응답 유실/강제 종료/재개, 같은 본문 새 발생 건, 문맥·요약·피드·보고 검사 |
| `tests/test_slack_move_baseline.py`, `fixtures/slack_move_requests.json` | 변경 전 가짜 Slack 요청 12건. 스위치 없음/slack 회귀 비교 |
| `tests/test_slack_move_naver_baseline.py`, `fixtures/naver_slack_requests.json` | **네이버톡 제품 코드 수정 전** 최초/수정 초안·결과·상태·직접 답장·유실 후 재시도 없음의 가짜 Slack 요청 7건 고정 |
| `tests/conftest.py`, 기존 시험의 설정·호출부 | 가짜 금고/허용 사용자 제공, 지운 상수 대신 설정 읽기 함수 호출. 기존 사람/채널 식별자 입력은 가짜 값으로 치환. 승인/전송 횟수와 결과 의미의 기대값 유지 |
| `tests/run_isolated.py` | 소스와 기존 회귀 입력을 임시 홈에 복사하고, 감사 훅으로 외부 쓰기·비밀 읽기·실제 외부 통신 차단 |

채널·멘션 대상·작업 공간 주소 상수를 지웠다. Slack 채널과 주소는 기존 금고 키, 멘션 대상은 기존 허용 사용자 설정, hejo는 직책 키를 쓴다. 자동 초안 생성·실제 고객 전송·자동 전송 판정은 바꾸지 않았다. 새 전송 큐 파일은 없다. 기존 스레드·건강 상태·요약·보고·가이드 제안 항목이 각각 자기 전송 상태를 소유한다.

### 호출자별 발생 건과 재시도

| 경로 | 발생 건·저장 자리 | 재시도 |
|---|---|---|
| 수신 글 알림 | 수신 글 id, 고객 스레드 `notices` | 다음 받은함 차례, 같은 열쇠 |
| 초안 | 대화 id + 초안 열쇠 + `created_at`, `draft_pending` → 성공 때 `draft_post` | 다음 차례, 새 모델 턴 전에 표시부터 재개 |
| 다시 보이기 | 새 난수 값, 같은 `draft_pending` | `drafts_due`가 없어도 다음 차례에 재개 |
| 승인·자동 전송 결과와 자동 초안 실패 안내 | 올리기 직전 만든 값, 기존 스레드 `notices` | 고객 전송/모델 턴을 반복하지 않고 표시만 재시도 |
| 요약 | 보고 시각의 날짜·시간 + 종류, 기존 `digests` 항목 | 미완료 올리기와 편집 계획 재개, 다음 회차는 별도 글 |
| 감시 실패·회복·토큰 경고 | 처음 올리려는 때 만든 값, 기존 건강 상태 항목 | 해당 실패/회복 차례, 4xx는 실패 사유 저장 후 종료 |
| 인스타 학습·자동 답장 보고 | 종류·보고 날짜·조각, 기존 보고 상태 | 공통 보고의 영속 조각 상태 재사용 |
| 가이드 제안 | 올리기 직전 만든 값, 기존 제안 행 | `posting` 행을 다음 차례에 먼저 재개, 4xx 종료 |
| 피드 예약 결과·댓글 및 기존 피드 실패 알림 | 기존 발행/확인 상태의 한 번 시도 표시 | 일회성. Slack 때처럼 애매한 결과를 다시 보내지 않음 |

### 실행 증거와 한계

- 최종 미커밋 변경본: 게이트웨이 Python으로 `tests/run_isolated.py -q` → **종료 0, 685 passed, skip 0**. 로그 `.build/slack-move/task05-instagram-followup.log`. 임시 소스/홈·실제 문과 team-kit·가짜 API이며 네이버톡 기준 기록 비교도 포함한다.
- AT-SM-46 인스타의 별도 프로세스: 실제 입구 응답 직후 `SIGKILL`(-9), 받은 id 저장 전 종료를 확인했다. 같은 홈의 새 프로세스가 저장된 열쇠로 재개해 기록 한 건·id/스레드 복구. 여러 조각의 응답 유실 시험은 기존 실제 문 시험과 함께 통과한다. TASK-04의 다른 두 보고 프로세스 시험은 기존 증거를 유지하며 반복하지 않았다.
- AT-SM-49: 첫 초안을 실제 승인해 끝낸 뒤 동일 본문 재등록, 동일 초안 열쇠/새 등록 시각, 각각 응답 유실 후 한 건, 둘째 글에만 승인, 첫 글 삭제 뒤 새 글을 확인했다. 시간별 보고의 같은 내용/다른 회차도 별도 글이다.
- AT-SM-50~53·51b: 실제 WS → 문 → team-kit → 인스타 훅 → 실제 승인 함수 → 가짜 인스타 API. 문맥 훅도 실제 사장 방 글로 검사했다. 승인 작업자 부팅만 동일 프로세스 시험 스레드로 연결한다. SIGKILL 시험은 이 대역을 복원해 실제 별도 프로세스를 쓴다.
- AT-SM-54·56의 전송 부분: 요약 항목 고치기·같은 회차 중복 방지·실패 3회 알림·응답 유실, 실제 예약 결과/댓글/가이드 제안/학습 보고의 hejo 전송을 확인했다. 요약 명세의 완료 항목 제외를 포함한 전체 입력 조합과 hejo 피드 사전 승인 세션의 종단 검증은 더 필요하다. AT-SM-57~59 전체 완료로 세지 않는다. 네이버톡·피드의 모든 Slack 비교 상황도 아직 남았다.
- 재개 중 실패는 통과로 세지 않았다: 건강 상태 기본 키 누락 4건, 시험 모듈 경로/가짜 설정 연결, 요약 첨부 본문 누락을 수정했다. 피드 통합 시험은 실제 배경 실행기처럼 `watch._load_plugin()`을 써 가짜 프로필 토큰을 읽도록 고쳤다. 네이버 기준 수집 도우미는 수집 뒤 정리 감사에서 실패했으며, 생성물을 확인해 지운 뒤 위 격리 전체 시험에서 기록 7건이 재현됨을 확인했다.
- 이전 676개 통과 및 변경 전 학습 보고 3건의 설정 오류 증거는 `task05-isolated-instagram.log`, `task05-preexisting-report-tests.log`에 남아 있다. 이번 전체 결과가 이전 국소 검사 결과를 대체한다.
- 최종 미커밋 변경본의 `gateway-python airport-check --snapshot .`: 종료 0, boundary 382·document 0·compartments 0 (`task05-followup-airport.log`). 기준선 변경 없음. 검사 대상은 `task05-followup-source.json`의 26개 파일이며 운영 실행본 29개 불변을 다시 확인했다. TASK-05 완료 전 커밋 금지 지시에 따라 **커밋·분리 전체 검사 미실행**. 운영 적용·실제 전송·푸시 없음.

최종 공개 보고의 `scripts/scan_private.py`는 종료 0(`task05-followup-scan.log`), 두 저장소 `git diff --check`도 종료 0이다. 검사한 파일 해시 및 실행본 불변 기록은 `task05-followup-source.json`이다. 운영 worktree의 로컬 `HANDOFF.md`에도 중단 지점과 재개 조건을 적었다.

### S-3: 네이버톡 영속 전송 상태의 저장 형식 — 계획 보완 요청

[확인] `design.md` 4.1은 네이버톡 사건 표에 `notice_key` **열 하나**를 추가하고, 성공 때 `preview`·고객 `thread`·`notified=1`을 함께 적도록 정했다. 동시에 같은 절은 조각 열쇠 목록과 받은 id를 해당 글의 상태 항목에 저장하라고 정한다. TASK-04 공통 전송 `TS/delivery.py:260-288`은 본문 조각·꾸밈·스레드·조각별 열쇠를 동기 `save`로 먼저 저장하고 응답 id도 그 항목에 저장한다.

[확인] 실제 `CP/scripts/naver-talk/bridge.py:365-379`의 사건 표에는 그 전송 상태를 저장할 항목이 없다. `body`는 수신 사건 본문이고 `reply`·`reason`·`approval`·`preview`는 현재 초안/판정의 원본이다. `preview`를 전송 상태로 겸용하면 AT-SM-49c의 종료 직후 빈 `preview` 및 성공 뒤 글 id 계약과 어긋난다. `notice_key`에 변하는 전송 상태를 넣으면 재시도에서 같은 열쇠를 읽는 계약을 깨뜨린다. 현재 고객 표의 `thread`·`cursor`에도 문 표시가 없다.

[확인] 보낼 알림 본문은 사건 행만의 순수 함수도 아니다. `notify:656-663`은 현재 시각과 고객의 직접 상담 상태에 따라 `approve/stale/expired/direct` 안내를 선택한다. 실패 뒤 행의 `approval/status`가 그대로여도 다른 시각에 본문을 재계산할 수 있다. 이미 올린 글의 재시도에 쓸 본문·대상·스레드와 조각 상태를 어디에 고정할지 정해야 한다.

[판단] 공통 저장 요구를 구현하려면 **추가 저장 필드의 형식과 수명**을 확정해야 한다. 구현 규칙 20-implementation 2절의 “설계에 없는 공개 인터페이스·저장 형식·설정 키 변경이 필요하다”에 해당하므로 이 부분을 임의로 선택하지 않았다. 네이버톡 제품 코드는 미수정이다.

[권고] 기존 사건 표에 전송 상태 JSON 필드(본문·대상·스레드·공통 조각 상태)를 더하고 고객 스레드의 문 표시도 명시한다. 0→2를 잡을 때 새 `notice_key`와 표시할 내용을 같은 트랜잭션에 고정하고, 2 재개는 그 내용을 읽는다. 초안/상태 변경으로 0이 되면 다음 잡기에서 옛 전송 상태를 교체한다. 성공의 원자적 완료·4xx 종료·0 우선·Slack의 기존 동작은 유지한다. 별도 큐/파일을 만드는 대안이나 기존 본문·`preview` 필드 겸용은 권하지 않는다. 정확한 필드명·기본값·마이그레이션·전환/되돌리기 처분을 설계에 확정한 뒤 구현한다.

대기 중 독립적으로 가능한 일은 인스타의 위 남은 입력 조합·피드 Slack 기준 확대·승인 경합 mutation check다. 이번 중단 보고에서 이 항목들을 완료로 올리지 않는다.

## 남은 범위와 재개 순서

TASK-05 설계 8판 반영과 커밋·분리 전체 검사까지 마쳤다. 다음은 TASK-06 → TASK-07(AT-SM-67 포함) → TASK-08 순서로 진행한다. S-3 저장 계약 보완 대기는 해소됐다. TASK-06은 최신 운영 HEAD와 새 수정 대상 실행본을 대조하고 변경 전 가짜 Slack 요청을 먼저 기록한다. 중간 TASK에서 앱만 실패하면 Python·실제 게이트웨이 통과와 변경 범위를 기록하고 이어간다. 마지막 TASK 뒤 최종 전체 검사에서도 앱만 실패하면 제품 기준 cb06e7d를 같은 조건에서 한 번 검사해 대조하고 보고한다. TASK-09와 운영 전환 TASK-10은 범위 밖이다.

마지막 상태 대조: TASK-02의 이전 분리 검사에는 타 작업 앱 커밋 `b21dd94528981dddcfa98e5a9883e864442d243d`가 없었고, TASK-03 전체 검사에는 포함되어 통과했다. TASK-04 동안 공유 폴더의 앱·타 작업 보고서가 다시 수정 중이므로 해당 미커밋 변경을 보존하고 분리 검사에 넣지 않았다. 위 결과는 각각 명시한 커밋과 조합에만 해당한다.


## TASK-05 설계 8판 반영: 네이버톡 구현과 인스타 잔여 검증

[확인] 검토 3차 `fbcbfed9707a4f497ba2a2cf3c95fa870c22abcf`의 S-3 보완을 적용했다. 위 S-3는 이전 중단 이력이며 더 이상 보완 대기가 아니다. 운영 worktree 기준은 TASK-04 `22f8aa629bdf828e9b02085531bfd0819d071139`다. 착수 직전 운영 main `d7208c11c23ddb0dacddbe3e225864058f263006`의 다리·네이버톡 플러그인 두 실행본을 다시 대조했고 모두 같았다(`task05-naver-preedit.json`). 기존 모델 프로세스 시험의 준비값 보완 전에도 그 파일의 main·worktree·실행본 해시를 대조했다.

### 변경

- `CP/scripts/naver-talk/bridge.py`: 기존 마이그레이션에 사건 표 `notice_key`·`notice_state`, 고객 표 `thread_platform`만 추가했다. 새 상태 파일·표·추가 열은 없다.
- 0인 행을 잡는 트랜잭션에서 본문·꾸밈·대상·스레드·빈 조각 상태를 `pending`에 고정하고 2와 새 열쇠를 함께 적는다. 2인 행은 저장된 값을 읽으며, 매번 전송 전에 조건부 저장의 갱신 행 수를 검사한다. 완료 트랜잭션에서 preview·posted·고객 스레드·1을 함께 적고 pending을 지운다. 4xx는 오류 이름을 pending에 남겨 1로 끝내며, 일시 실패는 2로 남긴다.
- 취소는 posted와 preview가 같은 hejo 글에만 공통 편집을 적용한다. 응답을 잃어도 저장한 편집 계획으로 다시 고친다. Slack 미리보기는 건너뛴다. 문이 바뀌면 고객 스레드를 새로 만들고 cursor·mark를 초기화한다.
- 승인 확인은 실제 hejo 스레드의 preview 순번 뒤 첫 사장 글과 인접 여부를 검사한다. cursor는 처리한 사장 글의 순번이다. 머리 글은 본문을 보존하며 asked/closed만 고친다. hejo의 머리 글 표시 실패는 성공한 뒤에만 mark를 기록해 다음 차례에 다시 시도한다. Slack의 기존 한 번 시도 규칙은 유지했다.
- `CP/plugins/instagram-dm/naver_talk.py`: 문맥 훅과 상태·초안 도구를 hejo에 연결했다. 도구는 공통 사장 원문/세션 증명을 사용하며 배경 실행은 거절한다.
- 인스타 시험: 실제 받은함 입력에서 완료 대화를 요약에서 제외하는 조합, 실제 문·team-kit·세션 원문 증명을 거친 피드 예약 승인과 가짜 Graph API 게시, 오래된 승인 작업자가 동일 본문 재등록과 경합하는 경우를 추가했다. 피드의 가짜 Slack 요청은 **변경 전 커밋**에서 별도로 5건을 수집해 현재 요청과 비교한다(기존 12건·네이버톡 7건 fixture는 그대로).
- 격리 실행기는 기존 네이버톡 다리 시험도 임시 홈으로 복사한다. 그중 모델 자식의 환경 인자를 확인하는 시험 1건은 운영 설치 정보에 의존하고 있었다. 다른 프로세스 시험과 같은 `current_python` 대역을 채웠으며 기대값은 바꾸지 않았다.

### 검증 증거

- 실제 문과 가짜 네이버 API: AT-SM-49b·49c·49d·55를 실행했다. 별도 Python 프로세스에서 실제 다리·공통 전송을 실행해 입구 전/응답 직후 SIGKILL(-9), 같은 홈의 새 프로세스 복구, 재등록·취소·직접 답장·4xx·문 없음·Slack 복귀를 검사한다. 초안 및 직접 답장 알림 모두 중복 없이 복구되고 preview가 복원된다. 슬롯 선점·본문 고정·오래된 저장 콜백 거절·편집 응답 유실·옛 표 마이그레이션도 포함한다. 가짜 이벤트 직접 호출이나 예외 처리로 강제 종료 시험을 대신하지 않았다.
- 승인 경합 변형 검사: 임시 소스 사본에서 등록 시각 검사를 제거한 변형, 소진된 초안을 남기는 변형이 각각 해당 시험을 실패시켰다(각 pytest 종료 1). 원본 해시 불변. 실행기 종료 0, `task05-mutation-results.json`, `task05-mutation-occurrence.log`, `task05-mutation-spent.log`.
- AT-SM-57·58: 제품 소스의 Slack 개인 식별자/작업 공간 주소 상수 검사, 임시 홈 밖 쓰기·비밀 읽기·외부 소켓/DNS 차단, 가짜 HTTP 허용 목록을 시험에 적용했다. `airport-check --snapshot .` 종료 0, boundary 382·document 0·compartments 0 (`task05-airport-final.log`). 기준선은 변경하지 않았다.
- 중간 실패 기록: 첫 네이버톡 연결에서 공통 대상 함수의 필수 Slack 콜백 누락과 읽기 응답의 messages 포장 해제를 빠뜨렸다. 구현을 고쳐 통과했다. 새 시험 대역의 네이버 성공 코드 누락, SIGKILL의 취소 편집/알림 구분, WebSocket 수신 대기, 피드 시험의 Popen 대역 범위도 실제 계약에 맞춰 보완했다. 기대값·수락 명세는 변경하지 않았다.

- TASK-05 제품·시험 커밋: 운영 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f`, 32개 파일. `git commit --only`로 이 작업 파일만 담았다. 커밋 훅의 스냅샷 경계 검사도 종료 0(`task05-commit.log`).
- 최종 `CP/plugins/instagram-dm/tests/run_isolated.py -q`: 종료 0, **819 passed**, 건너뜀 0. 인스타와 기존 네이버톡 다리 전체 회귀를 함께 실행했다(`task05-final-plugin.log`, 정확한 파일 해시 `task05-source-final.json`). 기존 실행본 29개와 추가 대조 대상도 불변을 재확인했다.
- 두 저장소 `git diff --check`: 종료 0. 분리 전체 검사 결과는 다음 절과 같다. TASK-06~08 및 운영 전환·푸시는 아직 수행하지 않았다.


### TASK-05 고정 커밋 조합의 분리 전체 검사

| 대상 | 고정 커밋 | 결과 |
|---|---|---|
| 공개 저장소 | `c034fb7307fc937791525858b7c008912453cae0` | 이 커밋을 detached worktree로 검사 |
| 운영 저장소(team-kit·고객 플러그인) | `84c6a82d18c4b70730bcf4e49f9c9c0af224983f` | 별도 detached worktree의 team-kit을 사용 |
| `bash scripts/test.sh` | 위 두 커밋 조합 | **종료 0**. Python 434 passed, 실제 게이트웨이 묶음 정상 종료, 앱 본체·네트워크/방/첨부·후크 시험 통과 |

로그 `.build/slack-move/task05-isolated-full.log`, 두 커밋·종료 코드 기록 `.build/slack-move/task05-isolated-full.json`, 실행기 기록 `task05-full-driver.log`. 실행 전 `pgrep -f app-tests` 중복 없음. 두 검사 worktree는 종료 뒤 제거했다. 앱의 컴파일 경고와 시험 중 시스템 메시지는 남았지만 실패는 없었다. 실제 CLI 설정 메타데이터와 다운로드 이름 보존 검사도 통과했다. 본 작업의 커밋은 app/·본체·ddots를 바꾸지 않았다.

검사 중 운영 main이 `f86cf3506dc4448741dea2b9ee7c5fac3feeb3f8`로 이동했다. 이전 조사 기준과 team-kit·고객 플러그인 범위를 비교하면 `TK/tests/test_live_soul.py`만 바뀌었고 TASK-05 대상 제품 파일은 불변이다. 운영 main 전체를 검사한 것으로 대신하지 않는다. TASK-06 수정 전에는 최신 HEAD와 그 수정 대상 실행본을 다시 대조한다.

TASK-06 착수 전 읽기 조사만 진행했다. `night_batch`는 조직개편안/아침 보고를 호출하고, `gap_review`는 예약 사전 입력을 만들며 직접 Slack 쓰기는 발견되지 않았다. `memory_tidy`는 보고 받을 곳을 계산한 뒤 `morning_queue.hold`에 넣는다. `reply_buttons._update_status`는 Slack 전용 client 경로다. 금고 백업의 첫 질문 생산자와 전체 직접 전송 목록 대조는 다음 단계에서 계속한다. TASK-06 제품 파일은 아직 고치지 않았다.


## TASK-06 착수 조사 중단: S-4 금고 백업 첫 질문의 외부 생산자

[확인] 착수 시 공개 HEAD `f1ce4586c2a830fa7dc5d50d6a56572140848834`, 운영 구현 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f`(깨끗함), 최신 운영 main `f86cf3506dc4448741dea2b9ee7c5fac3feeb3f8`를 대조했다. TASK-05는 위 커밋 및 기존 검사 기록 상태를 유지한다. 이번 조사에서 제품 파일은 고치지 않았다.

[확인] 추가 조사 대상인 금고 백업 첫 질문은 **별도 위키 저장소**의 `02_etc/scripts/wiki_daily.py`가 만든다. 해당 저장소 HEAD는 `085db649d188bfc9d4f878d9148d7d55a4dbae5e`, 읽은 소스 SHA-256은 `a197d62fde3ac00d639993088f639a4d1075d66171f551908e8375156cd9506f`다. `send_slack:154-166`은 158줄에서 `hermes send --to slack:…`를 실행한다. 일일 작업 272줄이 이를 부르고 275줄이 `ask_backup_approval`을 부른다. 173-175줄은 기존 승인 대기 파일에 `chat_id`·`thread_ts`·`created_at`·백업 대상과 변경 목록을 적는다. 개인 경로와 값은 공개 보고에 싣지 않았고 로컬 증거만 `.build/slack-move/task06-external-producer.json`에 남겼다. 비밀 파일·운영 대기 파일은 읽지 않았다.

[확인] 소비자는 `TS/vault_backup_approval.py:252-269`이며, 대기 파일의 채널·Slack 스레드·버튼 글 id를 검사한다. 생산자를 그대로 두고 소비자만 hejo에 연결하면 첫 질문은 계속 Slack으로 나가고 hejo 질문/승인 식별자가 생기지 않는다. 이는 AT-SM-41·60의 전수 전송과 TASK-07 AT-SM-64의 시작 입력에도 영향을 준다.

[중단 근거] `handoff.md` 9번과 `design.md` 4.2의 “다른 저장소나 본체에 있으면 멈추고 보고한다” 조건에 해당한다. 요청한 새 수정 대상 실행본 SHA-256 대조와 가짜 Slack 기준 요청 수집은 대상 범위 확정 전이라 미실행이다. TASK-06 제품 구현·수락 시험·분리 전체 검사, TASK-07·08도 미실행이다. 기존 통과 결과를 이번 TASK의 통과로 세지 않는다.

[기획설계 요청·권고] 원래 목표를 유지하려면 외부 생산자의 변경 범위와 임시 worktree 절차를 승인하고, 첫 질문의 직책 대상·공통 전송 연결·재시도 분류와 기존 승인 대기 항목의 platform/message_id/thread 저장 계약을 생산자와 소비자 함께 확정하는 방안을 권고한다. 외부 파일을 임의로 고치거나 team-kit에 대체 생산자를 만들지 않는다. 다른 선택은 이 알림을 명시적으로 범위 밖에 두는 것이지만, 현재의 전체 이전 요구와 수락 기준을 바꾸므로 사용자·기획설계 결정이 필요하다. 승인 대기 레코드의 두 번째 원본은 만들지 않는다.

[재개 가능 부분] 결정 뒤 TASK-06의 나머지 내부 경로 조사·가짜 Slack 기준 수집은 독립적으로 진행할 수 있다. 이번 인계는 명시된 멈춤 조건에 따라 조사 결과만 반환한다. TASK-05를 다시 구현하거나 검사하지 않으며, 재개 순서는 TASK-06 → TASK-07(AT-SM-67 포함) → TASK-08이다.

[자체 확인] 이번 보고 변경본의 게이트웨이 Python `scripts/scan_private.py` 종료 0(`.build/slack-move/task06-stop-scan.log`), 두 저장소 `git diff --check` 종료 0. 제품 코드 변경이 없어 기존 전체 검사를 반복하지 않았다. TASK-05의 고정 커밋 조합과 종료 0은 기존 `task05-isolated-full.json`을 재확인했으며 TASK-06 검증 결과가 아니다.
