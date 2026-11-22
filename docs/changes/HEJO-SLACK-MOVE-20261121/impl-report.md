# HEJO-SLACK-MOVE 구현 인계 보고

## 현재 판단: TASK-02~08 구현·자체 시험·마지막 분리 전체 검사 통과

[확인] 구현 검토 2차와 설계·인계 7판(`892d54ed1ddecbe96eddc1945494f1f8c6583777`)으로 재개했다. 기본 프로필 작성자 D-3를 반영했다. TASK-03 커밋 `57d00939c04d81d6c033ef5a31999fe02e35a383`의 분리 전체 검사가 종료 0으로 통과했다. TASK-04는 운영 worktree의 최종 제품 커밋 `22f8aa629bdf828e9b02085531bfd0819d071139`에서 회귀 시험 245개와 경계 검사를 통과했다. 공개 커밋 `0dfe9db8aab7373ebee6fc456deaf0134eb00e05`와 이 team-kit 커밋을 각각 고정한 전체 검사도 종료 0이다. TASK-05는 설계 8판 반영까지 구현·커밋하고 자체 시험을 마쳤다. 공개·운영 커밋을 고정한 분리 전체 검사도 종료 0으로 통과했다(아래 마지막 절). TASK-06은 `8020089a`로 구현·검토 수락됐다. TASK-07·08은 아래 마지막 절의 커밋과 시험으로 구현을 마쳤고 마지막 두 커밋 고정 전체 검사도 종료 0으로 통과했다. 중간 절의 미완료·중단 문장은 당시 상태이며, 최신 상태는 마지막 절을 따른다.

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


## TASK-06 재개: 진단·보류·개인 메일 경로 일부 구현(미커밋)

[범위] 4차 판정 `0bfa9f98aee2bf1e9eafc17d01dbdfd7caff373c`와 최신 지시를 적용했다. S-4는 나머지 구현을 막지 않는다. 위키 일일 보고·금고 백업 질문/승인은 H-5 결정 대기라 AT-SM-41·60의 전수 대상에서 제외한다. 위키 저장소·`TS/vault_backup_approval.py`·승인 대기 형식은 바꾸지 않았다. AT-SM-64 회귀 확인은 TASK-07에서 남아 있다.

[기준 확인] 운영 main `f86cf3506dc4448741dea2b9ee7c5fac3feeb3f8`, 구현 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f`. 새 후보 21개 파일의 main/worktree/실행본 SHA-256이 모두 같았다(`.build/slack-move/task06-preedit.json`). 이번 수정 뒤에도 21개 실행본은 불변이다. 정확한 미커밋 10개 파일과 SHA-256은 `task06-partial-source.json`에 있다. TASK-05 수락과 기존 검사 결과는 그대로 보존한다.

| 경로 | 현재 변경·상태 | 발생 건과 재시도 |
|---|---|---|
| `TS/doctor.py` | 진단 직원 직책 대상으로 공통 전송. 기존 점검 상태 안 notice에 본문·대상·점검 스냅샷·조각 상태 저장 | 새 알림 회차 UUID를 I/O 전에 저장. 일시 실패는 같은 스냅샷·열쇠, 4xx는 오류를 남기고 그 회차 종료 |
| `TS/error_digest.py` | 진단 직원 직책 대상으로 공통 전송. 기존 오류 요약 상태 안 notice에 본문·대상·보고한 오류 집합·조각 상태 저장 | 새 보고 회차 UUID를 먼저 저장. 복구 중 현재 로그를 다시 계산하지 않음. 성공/4xx 때 그 스냅샷만 확인 처리 |
| `TS/eventkit_stall_watch.py` | 즉시 알림의 받을 곳을 진단 직원 직책으로 해석, hejo에서 Slack DM 값 불필요 | 즉시 알림은 기존 일회성 정책 유지. 실패 기록만 남김. 조용한 시간의 알림은 아래 보류 장부가 소유 |
| `TS/morning_queue.py` | 기존 held-posts 행에 문·직책 대상·요청 열쇠·조각 상태. 아침 flush가 공통 전송 | hold 때 새 회차 UUID, 옛 Slack 행은 첫 native flush 전에 생성·저장. 부분 조각 실패와 응답 유실 복구. 4xx 오류 기록 뒤 종료. Slack 복귀 시 hejo 행을 Slack에 보내지 않음 |
| `TS/memory_tidy.py` | 학습 보고 직책으로 대상 해석 후 기존 보류 장부에 넣음. 독립 글을 새로 보내지 않음 | 학습 보고가 기존처럼 부록을 소유·확인 처리. 옛 Slack 보류 부록도 native 학습 보고에서 선택 가능 |
| `TS/personal_mail_summary.py` | 보고 직책 대상으로 공통 전송, 실행 항목에 hejo 표시 | 기존 보내기 전 회차 선점·불명확 결과 재전송 금지 정책 유지(일회성). 새 재시도 큐 없음 |

[가짜 Slack 기준] 제품 수정 전에 진단 보고·오류 요약·멈춤 알림·개인 메일 요약의 실제 HTTP 요청 4건, 보류 장부 flush 요청 1건을 수집했다. `TK/tests/fixtures/slack_move_reports_baseline.json`·`slack_move_held_baseline.json`에 고정하고 수정 후 같은 요청인지 비교한다. 수집 로그는 `task06-baseline.log`·`task06-held-baseline.log`. 기준 파일을 덮어쓰는 시험 옵션은 제거했다.

[자체 시험] 임시 HOME/HERMES_HOME과 짧은 임시 Unix 소켓 경로에서 게이트웨이 Python으로 8개 시험 파일을 실행했다. 종료 0, **235 passed**, 건너뜀 0. 로그 `.build/slack-move/task06-isolated-reports.log`, 실행 명령/종료 코드 `task06-isolated-reports.json`, 실행기 `task06_test.py`. 대상은 운영 `84c6a82d` 위 위 10개 미커밋 파일과 공개 문 코드 `0bfa9f9`다. 가짜 입구에서 저장 선행·503·4xx·부분 조각·동일 본문의 별개 회차·Slack 복귀를 검사했고, 실제 문 어댑터/Unix 입구에서는 기록 후 HTTP 응답을 끊어 진단·오류·보류 보고가 한 건으로 복구되는 것을 확인했다. 관련 기존 진단·멈춤·아침·기억 정리 회귀도 포함했다.

[시험 준비 보완] 첫 직접 통합 실행은 긴 기본 임시 경로에서 소켓 연결 준비가 실패했다. 짧은 임시 경로로 고쳤다. 임시 HOME의 기존 회귀 2건은 운영 위치에서 시험 입력 코드(mini-maintenance와 인스타 보고 렌더러)를 찾고 있었으므로 worktree의 해당 코드만 임시 홈에 복사했다. 기대값과 기존 시험 코드는 바꾸지 않았다. 이 두 준비 오류를 통과로 세지 않고 보완 후 전체 235개 결과를 기록했다.

[정적 검사] 같은 미커밋 변경본의 `airport-check --snapshot .`는 임시 HOME/HERMES_HOME에서 종료 0, boundary 382·document 0·compartments 0(`task06-partial-airport.log`·`.json`). 기준선은 바꾸지 않았다.

[추가 조사] 운영 저장소 `local-bin/mini-maintenance:69-112`의 `slack`은 직접 HTTP 전송이며, `queue_notice:114-132`가 기존 아침 장부 저장 실패 시 이를 부른다. 같은 운영 저장소 안이므로 TASK-06의 추가 이전 대상이다. 본문은 정비 결과·경고와 로그 위치다. main/worktree/실행본 해시도 같음을 확인했으나 아직 가짜 Slack 기준 수집·수정은 하지 않았다. 두 저장소 밖에서 추가로 확정한 생산자는 기존 S-4 외에 없다(외부 경로 전수 조사를 마쳤다는 뜻은 아님).

[남음] 위 여섯 제품 파일만 일부 구현했다. `morning_system` 본 보고, `org_review`, `starter_plugins`, `paseo_autofix`, `ai_digest`, 보고 검토 결과, CCTV·제안 장부, linked_work와 호출자, 진단 요청 결과, 뉴스·마감, file_link, mini-maintenance와 나머지 전수 조사/시험은 남았다. AT-SM-41·60 전체·61·61b·62는 완료가 아니다. TASK-06 커밋과 분리 전체 검사, TASK-07·08은 미실행이다. TASK-06 경계가 끝나지 않아 부분 제품 변경은 커밋하지 않았다. 운영 적용·실제 전송·푸시 없음.


## TASK-06 계속: 아침·조직·스타터·자동수정·소식 보고(미커밋)

[기준] 공개 `0bfa9f98aee2bf1e9eafc17d01dbdfd7caff373c`, 운영 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f` 위 변경이다. 수정 전 운영 main `f86cf3506dc4448741dea2b9ee7c5fac3feeb3f8`와 새 후보 여섯 파일의 실행본·worktree SHA-256을 다시 대조해 일치를 확인했다(`task06-threaded-preedit.json`). 이후 파일 첨부·뉴스·마감·mini-maintenance 네 후보도 같은 방법으로 확인했다(`task06-files-news-preedit.json`). 후자 네 파일은 아직 수정하지 않았다.

| 경로 | 이번 구현 | 발생 건·실패 처리 |
|---|---|---|
| `TS/morning_system.py` | 기존 아침 보고 outbox에 문·대상·열쇠·조각 상태·별도 글/스레드 id. 자동수정 작업에 native 스레드와 원 보고 글 id 전달 | 보고 날짜와 새 회차 값을 보내기 전에 저장. 현재 점검/오류/정비 입력을 재계산하지 않고 재시도. 4xx는 회차 종료 |
| `TS/doctor.py`, `error_digest.py` | 아침 보고가 같은 기준 상태를 확인 처리할 때 단독 보고의 미완료 notice와 더 새로 확인한 기준을 보존. native 오류 상태는 기존 잠금 방식으로 직렬화 | 옛 보고의 복구가 더 새 기준·알림을 덮어쓰지 않음. Slack 호출 기준 유지 |
| `TS/starter_plugins.py` | 보고 직책 대상, 첫 글·답글의 공통 전송, native 순번 읽기, 상태 편집. 완료한 옛 Slack 질문은 재게시하지 않음 | 기존 보고/답글 항목에 회차·조각 상태. 응답 유실/503 재시도, 4xx 오류 기록. 편집으로 바뀐 글 id 저장 |
| `TS/org_review.py` | 진단 직책 대상, 첫 글·상세·승인 답글의 공통 전송, native 순번과 ISO 시각 읽기, 상태 편집, 자동수정에 문·스레드·원 글 전달 | 보고 열쇠·조각 구분과 저장한 새 회차. native에서는 Slack auth 조회 없음. 순번을 시각으로 잘못 쓰지 않음 |
| `TS/paseo_autofix.py` | 기존 held 목록에 native 전송/편집 의도를 단계 상태와 함께 저장. 다음 tick의 held 처리로 전송 복구. 부모 글과 스레드 id 분리 | 기존 보류 항목의 UUID를 저장하고 재사용. 새 단계의 같은 본문은 새 발생 건. 확인 답글 편집은 기존 글을 고치며, 긴 편집으로 교체된 글 id도 보존. 일회성 상태 표시 실패는 기존처럼 기록 |
| `TS/ai_digest.py` | 보고 직책 대상, 각 조각과 후속 상세를 같은 native 스레드로 연결. 이전 날짜의 미완료 보고도 먼저 복구 | 날짜·회차·조각 번호와 공통 전송의 조각 상태. 일시 실패는 고정 본문 재시도, 4xx 종료 |

[기준 요청] 수정 전 아침 보고 2건·자동수정 답글 1건·스타터 첫 글/답글 2건, 조직개편안 2건·AI 소식 2건의 가짜 Slack HTTP 요청을 추가 고정했다. `TK/tests/fixtures/slack_move_threaded_baseline.json`·`slack_move_org_ai_baseline.json`이며, 임시 홈 경로가 들어간 metadata 해시만 형식을 검사한 뒤 정규화한다. 수집 로그는 `task06-threaded-baseline.log`·`task06-org-ai-baseline.log`. 수집 옵션은 제거했다. 앞의 5건을 합쳐 현재 기준 요청은 14건이며 나머지 경로의 기준은 아직 없다.

[증거 주의] 이전 235건 로그 이름을 후속 실행에서도 사용해 그 파일은 이후 결과로 갱신됐다. 중간 두 실행은 로그 파일을 동시에 열어 일부 출력이 섞였으므로 이 중간 파일을 현재 변경본의 최종 증거로 쓰지 않는다. 실행이 끝난 것을 확인한 뒤 아래의 새 로그 이름으로 분리해 다시 검사했다. 모든 시험은 임시 HOME/HERMES_HOME을 썼으며 운영 전송·운영 상태 변경은 없다.

[남은 범위] 보고 검토 결과, CCTV·제안 장부, linked_work와 호출자, 진단 결과 및 그 자동수정 연결, 뉴스·마감, file_link, mini-maintenance는 아직 이전하지 않았다. 이번에 바꾼 조직·스타터의 게이트웨이 답글 훅은 TASK-07에서 계속해야 한다. AT-SM-61의 실제 버튼 처리 전체, 61b·62 및 전수 AT-SM-41·60은 완료로 세지 않는다. 자동수정의 장문 원 보고 상태 표시와 진단 요청 생산자/소비자의 연결도 최종 통합 시험에서 확인해야 한다. TASK-06 전체가 끝나기 전이므로 커밋과 분리 전체 검사는 하지 않았다. 다음은 나머지 전송 경로 → TASK-06 커밋 → TASK-07 → TASK-08이다.

[현재 검증] 위 18개 미커밋 파일의 정확한 해시는 `.build/slack-move/task06-threaded-source.json`이다(운영 실행본 21개 불변 확인). 게이트웨이 Python `task06_test.py`는 임시 HOME/HERMES_HOME에서 관련 회귀와 새 시험을 함께 실행해 **종료 0, 490 passed, 건너뜀 0**이다. 로그 `task06-threaded-reviewed.log`, 명령·종료 코드·변경본 명세 연결은 같은 이름의 `.json`. 실제 어댑터/Unix 입구의 기록 후 응답 유실은 아침·조직·소식·스타터·자동수정까지 검사했다. 이 결과는 TASK-06 전체 또는 최종 분리 전체 검사의 통과를 뜻하지 않는다.

[현재 정적 검사] 최종 미커밋 변경본 `airport-check --snapshot .` 종료 0, boundary 382·document 0·compartments 0(`task06-threaded-final-airport.log`·`.json`). 기준선 변경 없음. 공개 보고 변경본의 개인값 검사 종료 0(`task06-threaded-scan.log`), 두 저장소 `git diff --check` 종료 0(`task06-threaded-diff.json`). 운영 원본·실제 전송·재시작·커밋·푸시 없음.

## TASK-06 계속: 뉴스·마감·파일 첨부·정비 알림(미커밋)

[기준] 공개 `0bfa9f98aee2bf1e9eafc17d01dbdfd7caff373c`, 운영 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f` 위 변경이다. 뉴스·마감 수정 직전 운영 main `f86cf3506dc4448741dea2b9ee7c5fac3feeb3f8`, 파일·정비 수정 직전 main `dba8f4fb8b4e832383d834e2863c1883d06885db`와 실행본·worktree 해시 일치를 각각 확인했다. 중간 main 변경의 team-kit 범위는 다른 작업의 `tests/test_finder_folders.py`뿐이며 대상 제품 파일은 불변이다. 로컬 증거는 `task06-watchers-preedit.json`, `task06-file-link-preedit.json`, `task06-mini-preedit.json`이다.

| 경로 | 이번 구현과 상태 자리 | 발생 건·실패 처리 |
|---|---|---|
| `TS/news_watch.py` | 보고 직책 대상. 기존 `inflight`에 hejo 문·UUID·대상·렌더된 알림·조각 상태·알릴 항목 id를 저장. 원문 수집 자료는 저장하지 않음. 완료 뒤 inflight 제거 | hejo의 일시 실패는 같은 본문·열쇠로 다음 실행에서 복구, 4xx는 오류 기록과 해당 항목 확인 처리로 종료. 다른 발생 건은 새 UUID. Slack의 기존 불확실 전송/프로세스 종료 후 재발송 금지는 그대로. Slack 복귀 때 미완료 hejo 항목을 소비하거나 재전송하지 않음. 로그인·건강 경고는 기존 선행 시도 표시와 일회성 전송 유지 |
| `TS/deadline_watch.py` | 기존 단계별 notifications에 문·UUID·고정 본문·조각 상태·글/스레드 id. hejo 대상은 보고 직책. 닫기는 해당 문 기록만 편집하고 버튼을 비움 | hejo pending 단계는 같은 알림으로 복구(나중 제목·입력으로 재계산하지 않음). 4xx는 오류와 기존 terminal 예약 상태로 종료. Slack 단계 예약/불확실 전송 정책은 불변. 편집 의도는 공통 조각 상태에 저장하며 닫기 재호출로 복구 가능 |
| `TKL/hermes_packs/files_docs/files.py` | `file_link`가 현재 hejo 어댑터의 공개 `send_document` 계약 사용. 현재 사장 원문·프로필·대화·스레드·메시지와 세션 사용자 행을 확인. 기존 파일 범위·심링크·크기 검사 유지 | 일회성 첨부, 불확실 실패를 자동 재시도하지 않음. 새 큐/캐시 파일 없음. 결과에 native 글/스레드 id를 돌려주며 Slack URL을 만들지 않음. Slack 업로드·기존 캐시는 그대로이고 hejo 전환 뒤 Slack 업로드는 거절 |
| `local-bin/mini-maintenance` | 시스템 Python에서 기존 게이트웨이 Python 환경을 골라 공통 전송의 문 설정·직책 대상을 읽고 hejo 알림 전송. 기존 아침 장부가 실패했을 때의 즉시 알림도 이 경로 | 일회성. 전송/환경 확인 실패를 기록하고 Slack으로 우회하지 않음. 설치 환경이 없거나 모호하면 실패로 기록. Slack일 때 기존 말투 처리·HTTP 본문 유지 |

[기준 요청] 제품 변경 전 `slack_move_watchers_baseline.json`에 뉴스·마감 2건, `slack_move_files_baseline.json`에 파일 업로드 4건, `slack_move_maintenance_baseline.json`에 정비 1건을 고정했다. 앞 14건과 합쳐 현재 비교 입력은 21건이다. 수집 로그는 `task06-watchers-baseline.log`, `task06-file-link-baseline.log`, `task06-mini-baseline-captured.log`. 기준 수집용 쓰기는 시험에서 제거했다. 정비 첫 수집 시 시험 대역이 `.env` 파일 이름을 잘못 판별한 실패가 있었고, 대역만 고친 뒤 제품 수정 전 수집했다.

[자체 검증] 모든 명령은 게이트웨이 Python, 임시 HOME/HERMES_HOME, 가짜 외부 요청으로 실행했다. 명령·실제 종료 코드는 각 로그 옆 `.json`에 있다.

- 뉴스·마감과 기존 회귀, 실제 Unix 입구 기록 후 응답 유실: `task06-watchers-ingress.log`, 종료 0, 129 passed. 파일 첨부 및 기존 파일/되돌리기 회귀: `task06-file-link-docenv.log`, 종료 0, 289 passed, 건너뜀 0. 최초 파일 묶음은 임시 홈에 문서 Python 환경이 없어 10 failed·268 passed·11 skipped였고, 기존 설치 환경을 임시 홈에서 참조하고 바이트코드 쓰기를 끈 후 재검사했다. 기대값은 바꾸지 않았다.
- 정비 가짜 Slack/실패 대조 및 실제 자식 프로세스→공통 전송→임시 Unix 입구: `task06-mini-ingress-reviewed.log`, 종료 0, 14 passed. 다른 실제 입구 시험과 함께 실행한 수이며 정비 단독 건수는 아니다.
- 기존 TASK-06 부분 구현과 새 파일을 합친 검사: `task06-watchers-files-reviewed.log`, 종료 1, 902 passed·2 failed. 실패 둘은 기존 시험이 찾는 정비 스크립트·인스타 학습 보고 시험 입력이 임시 홈에 없었던 경우다. 실행기에 worktree 원본 복사를 추가한 뒤 해당 둘을 재실행해 `task06-fixture-regression.log`, 종료 0, 2 passed. **합친 검사 자체의 종료 코드를 0으로 바꾸어 기록하지 않는다.** 앞의 성공 묶음과 중복이 있으므로 건수를 합산하지 않는다.
- `file_link`의 사장/세션 확인을 메모리 변형으로 한 번 제거: 해당 5개 거절 시험이 실패(변형 pytest 종료 1, 5 failed·4 passed·2 deselected), 실행기 종료 0. 원본 파일 해시 불변. `task06-file-mutation.log`·`.json`.
- 정확한 미커밋 28파일 해시와 실행본 22파일 불변은 `task06-watchers-files-source.json`. 같은 변경본의 `airport-check --snapshot .` 종료 0, boundary 382·document 0·compartments 0(`task06-watchers-files-airport.log`·`.json`). 기준선 변경 없음.

[남음] 보고 검토 결과, CCTV/제안 장부, linked_work와 호출자, 진단 결과와 자동수정 연결은 여전히 미구현이다. 진단 요청 `run`은 pending이 아닌 요청의 재실행을 막으며 `queue_fix`가 자동수정에 Slack의 posted_ts/thread_ts를 넘기므로 이 생산자와 소비자를 같이 고쳐야 한다. 제안 장부는 현재 글 id와 스레드 id를 같은 값으로 보고 있어 design 5절의 별도 식별자·문 표시·유일한 열린 제안 판정을 구현해야 한다. 이번 네 경로가 통과한 사실로 AT-SM-41·60 전수, 61 전체 버튼 처리, 61b를 완료로 세지 않는다. 마감 문맥 안내의 hejo 대응은 들어오는 규칙 TASK-07에서 함께 확인한다. TASK-06 전체 완료 전이므로 커밋·분리 전체 검사·TASK-07·08은 아직 하지 않았다. 운영 설정·비밀·재시작·실제 전송·허브·H-5 보류 파일·푸시 변경 없음.

[최종 정적 확인] 공개 보고 변경본 `scripts/scan_private.py` 종료 0(`task06-watchers-files-scan.log`). 두 저장소 `git diff --check` 각각 종료 0(`task06-watchers-files-diff.json`). 앞의 개별 성공 묶음은 실행 당시 변경본이고, 최종 28파일 명세는 합친 검사와 누락 입력 보완 후 재검사 기록에 연결했다. 운영 제품 변경·커밋·푸시 없음.

## TASK-06 계속: CCTV·제안·연결 업무·진단 결과(미커밋)

[기준] 공개 `0bfa9f98aee2bf1e9eafc17d01dbdfd7caff373c`, 운영 worktree `84c6a82d18c4b70730bcf4e49f9c9c0af224983f` 위 변경이다. 최신 운영 main `dba8f4fb8b4e832383d834e2863c1883d06885db`와 수정 전 후보 실행본·worktree 해시를 대조했다. 증거는 `.build/slack-move/task06-cctv-preedit.json`, `task06-linked-preedit.json`, `task06-diagnosis-preedit.json`. 이미 수정 중인 자동수정 파일은 실행본과 main이 같고 이번에 고칠 `enqueue_incident` 함수가 기준본과 같은지 별도로 확인했다. 기존 미커밋 변경은 보존했다.

| 경로 | 구현·발생 건·실패 처리 |
|---|---|
| `TKL/hermes_governance/proposal_decisions.py` | 기존 장부에 hejo 문·글 id·머리 글 id·스레드 id·조각 상태 저장. 제안 행 id를 요청 열쇠로 사용. 기존 정책대로 전송 결과가 불확실한 제안은 `posting`으로 남고 재제안하지 않음. 4xx는 `post_failed`. 그림은 제안 스레드에 한 번 첨부하고 실패가 제안을 취소하지 않음. 버튼은 공통 누른 글 id 함수, 글자 승인은 같은 문·방·스레드의 열린 제안 하나만 선택. 실제 실행 전 사장·문·방·스레드·상태를 다시 검사 |
| `TKL/hermes_packs/cctv/{watch,now,settings,reference}.py` | 고객 방 직책 값, 경고·제안·그림 전송. 기존 once-per-day 경고·제안 판정과 카메라·기록 실행은 유지. 수동 확인은 기존 소유자 검사 뒤 hejo 고객 방 또는 자기 1:1만 허용. `now`의 그림은 기존 공통 `upload_image`의 native 분기를 사용 |
| `TKL/hermes_packs/linked_work/slack_report.py`, `work_scope_backfill.py` | 완료 동기화 보고는 한 실행 안의 중복 제거와 일회 전송, 분류 보고는 보내기 전 시도 기록 뒤 불확실 실패를 재시도하지 않는 기존 정책 유지. hejo 보고 직책 대상으로 보내며 글/스레드 id를 구별. `notion_completion_sync` 호출자는 완료 보고 뒤 같은 상태를 되돌리지 않으며 코드 수정 불필요 |
| 같은 칸 `link_decisions.py` | 첫 글·항목 글의 별도 id와 스레드, 문 표시, 새 질문마다 UUID와 조각 상태. 기존 질문 생성의 한 번 전송 정책 유지. 상태 편집에 공통 조각 상태를 쓰고 교체된 글 id 저장. 새 후보 질문을 올리기 전에 옛 글 id를 비워 실패한 새 질문에 옛 버튼이 붙지 않게 함. native 판정 함수는 명시한 문과 따로 저장한 스레드/글 id 사용. 게이트웨이 훅의 hejo 이벤트 연결은 TASK-07에 남음 |
| 같은 칸 `conflict_decisions.py` | 다음 점검에서 다시 묻는 실패 경로는 기존 질문 행에 본문·대상·UUID·조각 상태·`delivery_pending`을 먼저 저장. 예외 처리 전 중단돼도 다음 호출이 같은 질문으로 복구. 응답 유실/503은 같은 열쇠, 4xx는 해당 질문 종료. 완료 편집은 저장한 조각 상태와 글 id 사용. Slack 분기 기준 요청 유지 |
| `TKL/hermes_packs/diagnosis/diagnosis_requests.py`, `TS/paseo_autofix.py` | 요청 스레드의 짧은 결과와 보고 받을 곳의 전체 결과를 공통 전송으로. 진단 실행기는 여전히 `pending`만 한 번 실행하며 전송 실패 후 진단 자체를 다시 돌리지 않음. 따라서 이 결과·접수 안내는 일회 전송이고 새 재시도 장부 없음. 보고 글 id·머리 글 id·스레드를 따로 저장하고 자동수정 작업에 전달. 이전 Slack 요청은 native로 마친 전체 보고만 보내고 옛 Slack 스레드를 native id로 쓰지 않음. 저장한 native 요청을 읽는 소비자의 UUID·방·사장 검사를 추가했지만 신규 요청을 받는 게이트웨이 검사는 아직 TASK-07 대상 |

[변경 전 기준] CCTV 경고·제안·첨부 4건, 연결 업무 완료·답글·고치기·충돌·연결 질문·분류 보고 8건, 진단 결과 4건, 실제 보고 검토 후 상태 고치기·결과 답글 3건을 제품 수정 전에 고정했다. `TK/tests/fixtures/slack_move_{proposals,linked,diagnosis,review}_baseline.json`. 앞 21건과 합쳐 TASK-06 기준은 **40건**이다(기존 TASK-04 스킬 fixture 2건은 제외). 수집 로그는 `task06-cctv-baseline.log`, `task06-linked-baseline.log`, `task06-diagnosis-baseline-captured.log`, `task06-review-baseline.log`. 수집 옵션은 제거했다. 진단 최초 수집은 임시 요청 폴더 누락으로 실패했고 폴더를 준비한 뒤 수정 전 다시 수집했다.

[확인한 호출 경계] `TS/report_review.py`의 결과 답글은 이미 `learning_report.slack` 공통 전송을 사용하므로 이번에 중복 전송 함수를 만들지 않았다. 실제 파일 거절 후의 Slack 기준 3건과 기존 검토 시험을 실행했다. hejo에서 필요한 것은 TASK-07의 `find`/입력 훅·사장·버튼 식별자 및 보고 상태 편집 연결이다. `hermes_reply/reply_buttons.py`의 `_update_status`와 체크 목록 편집은 Slack 어댑터에 등록된 Slack 입력 처리기다. native 문은 자기 버튼 상태 처리를 이미 갖는다. Slack 입력 처리기를 없애거나 hejo 입구로 옮기지 않았다(허브·H-5의 Slack 입력은 유지).

[자체 시험] 게이트웨이 Python, 임시 HOME/HERMES_HOME, 가짜 외부 요청으로 실행했다. 명령은 각 로그 옆 JSON에 있다. 성공 건수는 중복이 있어 합산하지 않는다.

- CCTV·제안 기존/새 시험 및 긴 글 실제 Unix 입구: `task06-cctv-final.log`, 종료 0, 282 passed. 실제 입구의 그림 등록·같은 스레드 첨부는 별도 `task06-cctv-picture.log`, 종료 0, 1 passed.
- 연결 업무·분류·보고 검토 회귀와 충돌 응답 유실 복구: `task06-linked-claim-reviewed.log`, 종료 0, 123 passed. 중단 시험은 `BaseException`으로 예외 복구를 건너뛰고 저장한 `delivery_pending`을 다음 호출이 읽는 시험이며 **별도 프로세스 SIGKILL 시험으로 주장하지 않는다**.
- 진단·자동수정 기존 회귀와 실제 입구 연결: `task06-diagnosis-regression-final.log`, 종료 0, 259 passed. 실제 입구에서 긴 결과 두 조각→자동수정 접수 안내→진행 글과 마지막 결과 조각의 완료 상태를 확인했다. 준비 중 실패는 임시 명부·요청 형식·자동수정 설정 위치·시간 정책 누락이었고 기존 시험 기대값은 바꾸지 않았다.
- 현재 TASK-06 새 시험 묶음과 관련 기존 회귀: `task06-reports-linked-reviewed.log`, 종료 0, 495 passed, 건너뜀 0. 이 실행 뒤 그림 실제 입구 시험 하나를 추가하고 위의 별도 1건으로 검사했다. 495건 실행은 전체 `scripts/test.sh`나 TASK-06 수락 전수 검사를 대신하지 않는다.
- 제안의 유일한 열린 행 검사와 스레드 검사 각각 메모리 변형: 해당 pytest 종료 1(각 1개 실패), 실행기 종료 0, 원본 불변. `task06-proposal-mutation.json`과 개별 로그. 진단 native 요청의 사장 검사 제거도 pytest 종료 1(1 failed·4 passed), 실행기 종료 0, 원본 불변(`task06-diagnosis-mutation.log`·`.json`).
- `airport-check --snapshot .`: 종료 0, boundary 382·document 0·compartments 0. `task06-linked-diagnosis-airport.log`·`.json`. 기준선 변경 없음.

[변경본] 현재 운영 미커밋은 **46파일**(제품 25, 시험 10, 기준 요청 11)이다. 정확한 해시는 `task06-proposals-linked-source.json`. 수정한 제품 실행본 25개는 main 및 작업 기준본과 같아 운영 원본 불변을 확인했다. 이는 앞서 조사한 별도 후보를 모두 다시 해시했다는 뜻은 아니다. 공개 문서와 운영 로컬 인계만 갱신했고 타 작업 문서는 보존했다.

[남음] AT-SM-41·60 전수 대조와 AT-SM-61 전체 버튼 입력/편집, TASK-06 커밋·분리 전체 검사는 아직 미완료다. 추가 대조에서 자동수정 `decide_cap`의 하루 한도 질문 상태 표시가 여전히 Slack식 `report_status.mark`를 쓰는 것을 확인했다. 이 경로와 `TS/report_status.py`의 도구 경로를 수정 전 기준 요청/해시를 확보해 조사·보완해야 한다. 연결 질문의 hejo 게이트웨이 훅은 입력 단계와 함께 연결해야 하며, 일반 보고 검토의 `find`·상태 편집도 아직 Slack 전제다. TASK-06 전체 완료 전 부분 커밋 금지는 유지한다. 그 뒤 TASK-07(AT-SM-64 보류 경로 회귀·67 포함)→08. H-5 보류 파일·프로젝트 허브·운영 설정·금고·재시작·실제 전송·푸시는 변경하지 않았다.


### 같은 회차 후속: 자동수정 한도 질문

[확인·변경] `decide_cap` 함수가 아직 기준본과 같은지, 최신 운영 HEAD와 실행본 SHA-256을 다시 확인했다(`task06-cap-preedit.json`). 수정 전 가짜 Slack 조회·고치기 2건을 `slack_move_cap_baseline.json`에 고정했고 동일 요청 회귀를 통과했다. TASK-06 기준 요청은 이제 **42건**이다. native 한도 질문의 닫기는 저장한 실제 질문 글 id와 스레드로 수행한다. 전송 응답 유실 또는 조용한 시간 뒤 복구해도 질문 글 id가 남도록 기존 `held`의 `question` 역할을 소비할 때 `question_ts`를 저장한다. 새 저장소나 별도 재시도 장부는 만들지 않았다.

[검증] 실제 Unix 입구에서 질문 기록 후 응답 유실→저장된 의도로 복구→같은 질문 1건→거절→해당 질문 버튼 제거·닫기를 확인했다. Slack 기준 대조와 기존 자동수정 회귀를 포함한 `task06-cap-reviewed.log`는 종료 0, 119 passed. 앞 495건 실행 이후의 추가 변경이므로 그 이전 묶음을 이 최종 변경본 전체의 검사라고 주장하지 않는다.

[기존 경로 확인] `TS/report_status.py`는 이미 현재 사장 세션을 증명하고 바인딩된 hejo 어댑터의 자기 스레드 글을 고치는 별도 경로가 있었다. 제품 파일은 수정하지 않았다. 실제 어댑터·세션 연결과 기존 Slack 보고 상태 시험 `test_report_status.py test_hejo_parity.py`는 종료 0, 36 passed(`task06-status-existing-reviewed.log`). 이 사실은 일반 보고 검토의 아직 연결하지 않은 hejo 입력 훅을 완료했다는 뜻이 아니다.

[최종 변경본·다음] 미커밋 **47파일**(제품 25, 시험 10, 기준 요청 12)의 해시는 `task06-cap-source.json`에 따로 보존했다. 이전 46파일 명세와 검사 기록은 덮어쓰지 않았다. 남은 일은 AT-SM-41·60 전수 경로/호출자 대조, AT-SM-61 전체 버튼·61b 종단 입력 증거를 완성하고 TASK-06을 커밋하는 것이다. 이어 TASK-07의 들어오는 훅·문맥·보고 검토(보류된 AT-SM-64는 회귀만, 67 포함), TASK-08 순서다. 한도 질문과 기존 보고 상태 도구의 조사 항목은 위 결과로 처분한다. 운영 적용·실제 전송·푸시·TASK-06 부분 커밋은 하지 않았다.

[최종 경계 확인] 최종 47파일 변경본의 `airport-check --snapshot .` 종료 0, boundary 382·document 0·compartments 0(`task06-cap-airport.log`·`.json`). 수정한 제품 실행본 25개가 운영 main·앞서 기록한 기준 해시와 같은지 재확인했다.


## TASK-06 전수 대조와 실제 입력 보완

[기준] 공개 HEAD·운영 worktree HEAD·운영 main은 앞 절과 같다. 직전 47파일 해시와 실제 변경본이 모두 같음을 확인한 뒤 이어갔다. 검색 결과는 `.build/slack-move/task06-{direct-path,profile-path,local-bin}-candidates.txt`에 보존했다. 검색은 두 저장소의 제품 소스만 대상으로 했으며 운영 비밀·설정·대화는 읽지 않았다. 아래 표는 design 4.2의 모든 줄과 추가 조사 줄을 대조한 결과다.

| 경로/호출자 | hejo 도달·검증 근거 |
|---|---|
| `TS/error_digest`, `eventkit_stall_watch`, `doctor` | `test_slack_move_reports`의 직책 대상·응답 유실·저장 실패, `test_slack_move_reports_gate`의 실제 입구 |
| `TS/morning_system`, `morning_queue` | 고정된 아침 보고/보류 항목과 실제 작업 스레드 연결. 같은 두 묶음 및 `test_slack_move_threaded` |
| `TS/org_review`, `starter_plugins`, `paseo_autofix` | 저장한 스레드·조각·순번 읽기와 편집. `test_slack_move_threaded`, 실제 입구 및 한도 질문 복구. 입력 훅의 모델 건너뛰기 계약은 TASK-07에서 추가 확인 |
| `TS/personal_mail_summary` | 일회 보고, 보고 직책 대상과 실패 정책. `test_slack_move_reports` |
| `TS/learning_report`, `skill_report`, `ai_digest` | TASK-04 공통 전송 위에서 실제 보고 생산자를 실행. `test_delivery_hejo`, `test_slack_move_threaded`, 새 다섯 보고 종단 시험 |
| `TS/report_review` | 실제 hejo 버튼/글자→검토 함수→임시 스킬 복원→보고 상태 고치기→같은 스레드 결과. 새 `test_slack_move_buttons` |
| `TS/vault_backup_approval` 및 외부 위키 생산자 | **H-5 보류로 AT-SM-41·60에서 제외.** 제품·대기 파일 모양 변경 없음. AT-SM-64 Slack 입력 회귀는 TASK-07 |
| CCTV `watch`, `now`, 제안 장부 | 가짜 CCTV 판정/그림과 공통 전송. 실제 입구의 그림 첨부, 실제 WebSocket→team-kit 등록 제안 훅→가짜 기록 실행. `test_slack_move_proposals`, `test_slack_move_buttons`, `test_slack_move_reports_gate` |
| `linked_work/slack_report`와 `notion_completion_sync` 호출자 | 완료 보고·연결/충돌 질문은 공통 전송. 호출자가 결과 상태를 되돌려 재전송하지 않음을 확인. `test_slack_move_linked`, 기존 완료/연결 회귀 |
| `linked_work/work_scope_backfill` | 기존 한 번 시도 정책으로 분류 보고. `test_slack_move_linked` |
| `diagnosis/diagnosis_requests` | 실제 요청 결과 두 조각·요청 스레드·진단 보고 스레드·자동수정 연결. pending-only 실행 유지. `test_slack_move_diagnosis`, 실제 입구 |
| `TS/news_watch`, `deadline_watch` | 기존 inflight/단계별 알림에 발생 건·본문·조각 상태. `test_slack_move_watchers`, 실제 입구 |
| `files_docs/files.file_link` | 현재 사장 세션 증명 뒤 바인딩된 실제 문 첨부. `test_slack_move_files`, 기존 파일 회귀 |
| 인스타 감시·피드·학습 보고, 네이버톡 다리 | TASK-05 수락된 경로. 이번에 직접 제품 수정 없음. 공통 학습/보고 변경 영향은 인스타 격리 회귀로 확인 |
| 공개 채널 자동 가입 | 설계대로 이관하지 않음. 예약 끄기는 운영 전환 TASK-10 |
| `TS/night_batch` | 별도 Slack 전송 없음. 진단 요청 실행·점검 준비·조직개편안 생성 후 아침 보고가 저장 결과를 소비. 기존 야간 시험과 아침 보고 시험 |
| `TS/gap_review` | 예약 작업의 사전 입력이며 전송 생산자 아님. 기존 빈틈 검토 시험 |
| `TS/memory_tidy` | 학습 보고 부록을 `morning_queue.hold`로 넘김. native 대상·부록 소비 확인 시험 |
| `local-bin/mini-maintenance` | 실제 게이트웨이 Python 자식에서 공통 전송, 실패 시 Slack 우회 없음. `test_slack_move_maintenance`, 실제 자식→입구 |
| `hermes_reply/reply_buttons`, 체크 목록, `report_status` | Slack 어댑터에만 붙는 편집 처리기는 유지. native 버튼은 문의 계약을 사용하며 보고 상태 도구에는 기존 native 현재 세션 증명이 있음. `test_hejo_parity`, `test_report_status` |
| 조회·연결 검사·문맥/조립 코드 | `slack_read`는 메서드 허용 목록이 읽기만, `connection_checks`는 auth.test. `optimization`·`learning`의 검색 일치는 자료/파일 처리. 사용량·예약·대기 작업은 TASK-07, 조립은 TASK-08 |
| 프로젝트 허브 | 사용자 결정으로 범위 밖. 파일 변경 없음, native 안내 부재 확인은 AT-SM-67 |

[실제 입력] 새 `test_slack_move_buttons.py`는 임시 문·WebSocket·team-kit의 실제 hejo 버튼 설치를 사용한다. AT-SM-61의 명세에 적힌 다섯 생산자(조직개편안·스킬·학습·AI 소식·자동수정)를 두 번 실행해 한 스레드/중복 없음과 사장 버튼 이벤트의 실제 글 id를 확인한다. 이는 버튼 전송·해석의 증거이며, 각 서비스의 모델 호출 차단과 도구 문맥은 TASK-07 수락으로 구분한다. AT-SM-61b는 제안 등록 훅까지 통과해 승인·거절, 장부에 없는 글 id, 다른 스레드, 열린 제안 두 개→하나, 재승인 시 추가 실행 없음을 확인했다. 열린 행 두 개는 유효한 장부 경계 입력으로 준비하고 입력/전송은 실제 문을 썼다.

[결과 전송의 호출 경계 보완] 보고 검토는 공통 전송만 바꾸어서는 hejo에서 입구의 Slack 전용 조건 때문에 실행되지 않았다. 요청된 TASK-06 결과 전송을 검증하기 위해 이 최소 호출 경계와 상태 편집을 함께 연결했다. `TS/report_review`는 문·사장·보고 대상·저장 보고의 문 표시를 대조하고 공통 누른 글 id로 현재 부분을 찾는다. `TS/learning.owner_report_place`는 hejo 직원 1:1 또는 학습 보고 직책 대상만 인정한다. `learning_report`는 부분별 영속 편집을 사용하며 저장 시 최신 검토 결정을 덮지 않고 조각 상태·교체 글 id만 합친다. 이전 미완료 편집을 먼저 끝낸 뒤 최신 표시를 적용한다. 스킬 native 전송에서 비어 있던 owner/bot도 생산자에서 기록한다. 새 저장 파일·설정·공개 규격은 없다. 수정 전 `task06-review-preedit.json`에서 실행본/main 해시와 이번 함수들이 기준 함수와 같음을 확인했고, 기존 가짜 Slack 검토 3건을 수정 직전 다시 대조했다(`task06-review-preedit-baseline.log`, 종료 0, 1 passed).

[현재 시험 기록] 새 입력 묶음은 최종 보완 전 `task06-review-edit-retry.log` 종료 0, 14 passed였다. 잘못된 검토 글의 버튼 거절을 추가한 뒤 야간 시험 보완과 합친 `task06-night-fixture-fixed.log` 종료 0, 36 passed. 검토 글 식별자 검사를 메모리에서 무력화하면 실제 입력 시험 둘이 실패했다(변형 pytest 종료 1, 실행기 종료 0, 원본 불변, `task06-review-mutation.log`·`.json`).

[실패 기록 보존] 합친 실행 준비의 v1·v2는 시험 파일 경로를 잘못 구성해 pytest 종료 4·시험 0건이었다. 상대 경로를 바로잡은 v3은 종료 1, 1641 passed·2 failed. 둘은 야간 시험 대역에 새 `accept_snapshot`/acknowledge 인자가 없는 것과 격리 홈에 기존 보존 검사 스크립트가 없는 것이었다. 기대값은 그대로 두고 대역 인터페이스와 임시 홈에 복사할 시험 소스를 보완했다. `task06-all-reviewed*.log`와 JSON을 덮어쓰지 않았다.


[최종 결과] TASK-06 구현·자체 시험을 마치고 운영 worktree의 작업 파일 **52개만** `git commit --only`로 커밋했다: `8020089a9fb00649222fe09125d40d84f629c76d`. 제품 28개, 시험 12개, 가짜 요청 fixture 12개다. 추적되지 않는 인계 파일은 커밋하지 않았다. 커밋 파일 집합과 시험 변경본 SHA-256이 정확히 같음을 확인했다(`task06-commit.json`, `task06-completion-source.json`). 운영 원본 28파일은 확인한 운영 main과 같으며 `learning`/`learning_report`의 앞선 TASK-04 차이는 수정 전 함수 대조 기록으로 구분했다.

- 합친 TASK-06 및 관련 기존 회귀: 게이트웨이 Python pytest **종료 0, 1643 passed, 건너뜀 0**. `task06-all-reviewed-v4.log`·`.json`. 실행 명령의 전체 파일 목록은 JSON에 있다.
- 공통 학습/보고 변경에 대한 인스타·네이버톡 격리 회귀: `tests/run_isolated.py -q -rs` **종료 0, 819 passed, 건너뜀 0**. `task06-shared-instagram.log`·`.json`.
- 운영 worktree `airport-check --snapshot .` **종료 0**, boundary 382·document 0·compartments 0. `task06-completion-airport.log`·`.json`. 기준선 변경 없음.
- 별도 프로세스 검사와 전체 앱/게이트웨이 검사 `bash scripts/test.sh`를 이번 회차에 추가 실행했다고 주장하지 않는다. 마지막 TASK 뒤 고정한 두 커밋의 분리 worktree에서 전체 검사를 한다. TASK-06 자체 수락 증거와 제품 최종 완료/푸시는 구별한다.

[다음 경계] TASK-07은 아직 대기다. TASK-06 결과 전송을 막던 보고 검토 입구·표시 연결은 위 커밋에 포함했으며, TASK-07에서는 등록 훅/도구 문맥과 학습 검토 전체의 AT-SM-66을 이어서 확인한다. 예약 허용 대상, 진단 사용량·요청 접수, 스타터/조직개편안과 연결 업무의 native 입력 훅, 대기 작업 방 작성자, H-5 보류 파일의 Slack 회귀, 허브 무변경/안내 부재를 구현·검증한다. TASK-08에서는 실제 본체 도구 집합 비교가 같지 않으면 차이를 보고하고 멈춘다. 운영 전환·고객 글·푸시는 하지 않았다.


## TASK-07 착수 회귀 — S-5: 보류한 Slack 승인과 전송 스위치 충돌

[판단] TASK-06은 앞 절의 운영 커밋 `8020089a9fb00649222fe09125d40d84f629c76d`, 공개 보고 커밋 `10334567bbb8c111495d50caf9ca6c5e43fc8fd8`로 보존했다. TASK-07은 AT-SM-64 회귀에서 설계·호출자 불일치를 확인하여 부분 착수 상태로 반환한다. 제품 코드와 수락 기준은 고치지 않았다.

[발견 사실] S-4는 H-5 결정 전까지 금고 백업 승인 답장을 Slack 그대로 유지하고 소비자·대기 파일 모양을 고치지 않도록 한다. 그러나 `TK/__init__.py:1154-1170`의 실제 등록은 공통 `learning_report`를 소비자에 넘긴다. `TS/vault_backup_approval.py:272-291`는 그 객체의 `slack`으로 질문 상태와 결과 답장을 보낸다. `TS/learning_report.py:94-98`는 전역 문 선택이 hejo이면 Slack 채널을 hejo 대상으로 해석하여 `unknown_employee`로 거절한다. 내부 `_slack`도 쓰기에는 `delivery.require_slack`을 적용하므로 그 함수로 바꾸기만 해서는 해결되지 않는다. 이는 design 4.1의 “hejo일 때 Slack 쓰기 함수가 불리면 예외”와 S-4·AT-SM-64의 유지 요구 사이에 빠진 예외 계약이다. 두 저장소 밖 생산자를 새로 발견한 경우가 아니라 **내부 공통 전송과 보존할 소비자의 충돌**이다.

[재현] 새 `TK/tests/test_slack_move_incoming.py`는 기존 승인 접수 시험의 임시 홈·가짜 사장/금고·가짜 백업을 쓰되, 전송과 상태 고치기를 실제 `learning_report.slack`·`report_status.mark`에 연결한다. HTTP만 가짜 Slack으로 받으며 운영 입구 호출은 시험 실패로 막는다. 승인/거절 각각 전송 설정을 slack/hejo로 바꿔 비교한다. Slack에서는 조회→질문 고치기→결과 답장 3개 요청이 발생한다. hejo에서는 승인/거절 처리와 대기 항목 종료는 되지만 가짜 Slack 요청은 0개이며 결과 전달 실패가 기록된다. 기존 회귀의 전송 대역만으로는 이 연결 오류가 드러나지 않았다. 실제 게이트웨이 등록은 코드로 대조했으며 이 새 시험은 소비자와 실제 전송 경계의 통합 재현이지 WebSocket 종단 시험은 아니다.

[검증] 게이트웨이 Python, 임시 HOME/HERMES_HOME에서 `pytest tests/test_slack_move_incoming.py -q`: **종료 1, 2 passed·2 failed**. 통과는 slack 승인/거절, 실패는 hejo 승인/거절이다. 전체 명령·종료 코드·변경본은 `.build/slack-move/task07-h5-real-sender.json`, 로그는 같은 이름의 `.log`다. 대상은 운영 `8020089`와 새 미커밋 시험 한 파일이며 제품 변경은 없다. `task07-h5-source.json`에 시험 SHA-256과 소비자의 worktree·운영 main·실행본 해시 일치를 기록했다. 확인한 운영 main은 `dba8f4fb8b4e832383d834e2863c1883d06885db`다. 시험은 기존 승인 대기 필드 집합도 그대로 확인한다. 실제 백업·Slack·고객 전송은 없었다.

[선택지와 권고] 기획설계에서 H-5 보류 소비자에만 허용하는 Slack 전송 예외의 책임·허용 메서드·대상 증명·해제 조건을 정하는 것을 권고한다. 기존 소비자와 대기 파일 모양은 유지하면서 등록 지점과 공통 전송의 계약을 보완할 수 있는지 검토가 필요하다. 다른 선택은 H-5 자체를 결정하여 생산자·소비자 이관을 별도 인계하는 것이며 이는 사용자 결정이 먼저다. 일반 Slack 쓰기 차단을 풀거나 설정을 잠시 slack으로 바꾸는 우회, 소비자 파일 임의 수정, AT-SM-64 기대값 완화는 하지 않았다.

[남은 범위] TASK-07의 나머지 예약·진단 접수·보고/조직/스타터 입력·대기 작업·AT-SM-67과 TASK-08은 아직 미완료다. H-5와 독립된 입력 규칙은 계속 구현 가능한 부분이지만, 규칙 20-implementation 2절의 설계 불일치 보고를 먼저 반환한다. 새 실패 재현 시험은 운영 worktree에 미커밋으로 보존한다. 설계·명세·인계서·판정서는 수정하지 않는다. TASK-07/08 완료 후 두 저장소 커밋을 고정한 분리 전체 검사는 여전히 미실행이다.


## TASK-07: 설계 9판의 남겨 둔 Slack 길과 들어오는 규칙

[확인] 판정 5차 `25a8b8a822cec2ec313d57fbf8b9a932dcbbe214`의 S-5 처분을 반영했다. 운영 커밋 `8cb51621a527bcdb82051c1e664b59470436c21f`(제품 10·시험 3파일), 누락 입력 경로 보완 `8a86f1390f4867fa5b789be95d7517a0f50d1d0d`(제품 3·시험 1파일)이다. H-5는 결정하지 않았고 금고 백업 소비자·대기 형식은 그대로다.

| 책임 자리 | 변경과 검증 연결 |
|---|---|
| `TS/delivery.py`, `learning_report.py` | 남긴 길은 `vault_backup`·`slack_session` 두 이름만. 전자는 스레드 읽기·글 고치기·글 올리기만, 후자는 본체 대화 환경의 현재 Slack 사장 대화만 허용. 이름 없는 일반 쓰기와 모르는 이름은 hejo에서 거절. 예약·배경·사장 아닌 대화는 허용하지 않음 |
| `TK/__init__.py` | 금고 백업 등록이 전용으로 읽은 보고 모듈 사본에만 `vault_backup` 보내기를 주입. 소비자 파일과 대기 레코드 필드 변경 없음 |
| `TKL/hermes_packs/files_docs/files.py`, `TS/report_status.py` | 현재 Slack 도구의 파일 올리기·보고 상태 변경만 `slack_session`. native 파일·표시 경로는 그대로. 같은 성격의 직접 쓰기 조사에서 추가 적용 대상은 없었고 이름 사용 자리를 AST 시험으로 고정 |
| `TS/cron_guard.py` | hejo 대화의 예약 관리를 받아 보고 받을 곳과 local만 허용. 다른 대화·Slack 대상·예약/배경 호출은 거절 |
| `TKL/hermes_packs/diagnosis/diagnosis_requests.py`, `native_tools/__init__.py` | 현재 native 사장 글·세션·구성된 받을 곳을 증명해 진단 접수. 사용량은 실제 스레드 조회의 글 순번으로 이전 요청을 선택하고 현재·미래 글을 제외. 기존 pending-only 진단 실행은 유지 |
| `TS/starter_plugins.py`, `org_review.py` | hejo 사장 답글을 저장한 문·방·스레드와 대조. 실제 native 버튼은 이미 기록된 사장 글이므로 중복 입력을 추가하지 않음. 결과는 같은 스레드. 보고 검토는 TASK-06의 실제 훅·상태 연결을 회귀 확인 |
| `TKL/hermes_packs/linked_work/link_decisions.py`, `conflict_decisions.py` | 이전 보고의 잔여 입력 훅 보완. 현재 문·사장·내부 이벤트를 검사하고 공통 누른 글 id를 기존 판정 함수의 글 식별자에 전달. 실제 버튼과 글 답변으로 결정 장부와 같은 스레드 결과를 확인 |
| `TS/deadline_watch.py` | hejo에서도 기존 열린 마감의 도구 안내를 제공. 기존 Slack 안내 내용과 동일 |
| 변경 없는 대기 작업·프로젝트 허브 | 실제 대기 작업 생성→본체 예약 배달→방 기록에서 요청 직원 이름을 확인. hejo 문맥에는 허브 안내가 없고 Slack에는 유지. 금지한 허브 다섯 파일 변경 0줄 |

수정 전 운영 main과 실행본 SHA-256을 대조했다. 증거는 `task07-exceptions-preedit.json`, `task07-native-preedit.json`, `task07-linked-preedit.json`이다. TASK-04에서 새로 만든 delivery 파일은 main/실행본에 모두 없으며, 기존 수정 파일의 worktree 차이는 앞선 TASK 커밋이다. 확인한 운영 main은 `dba8f4fb8b4e832383d834e2863c1883d06885db`다. 새 입력 훅 수정 전 연결 보고 fake Slack fixture도 다시 대조했다.

모든 로그·JSON은 로컬 `.build/slack-move/` 아래에 있다. 격리 실행기는 임시 HOME/HERMES_HOME과 가짜 명부·Slack·문을 사용했다.

| 실행 | 실제 결과·검사한 변경본 | 증거 |
|---|---|---|
| 예외 경로 변경 전 pytest 3파일/선택 시험 | 종료 0, 28 passed | `task07-exceptions-baseline.log`·`.json` |
| 예약·진단·스타터·조직 변경 전 pytest 4파일 | 종료 0, 158 passed | `task07-native-baseline.log`·`.json` |
| TASK-07 pytest 22파일 | 종료 0, 666 passed. 제품은 `8cb51621`과 같음. H-5 시험은 이후 정확한 요청 비교로 보강 | `task07-reviewed.log`·`.json`, `task07-completion-source.json` |
| 최종 AT-SM-64 승인·거절 | 종료 0, 2 passed. 각 시험 안에서 Slack/hejo 설정의 실제 등록·전송 모듈을 실행해 URL·본문 배열이 동일, native 입구 0건. `8cb51621`의 최종 시험 | `task07-h5-wire.log`·`.json` |
| 예외 조건 무력화 mutation | 변형 pytest 종료 1, 6 failed·1 passed. 원본 SHA 불변. 최초 실행기 문법 오류 로그는 검출 증거에서 제외 | `task07-retained-mutation-v2.log`·`.json` |
| 연결 입력 변경 전 pytest 3파일 | 종료 0, 57 passed, 기존 가짜 Slack 기준 요청 일치 | `task07-linked-baseline.log`·`.json` |
| 연결 입력·마감 및 회귀 pytest 4파일 | 종료 0, 62 passed. `8a86f139`와 같은 변경본. 실제 WebSocket→문→reply 설치→소비자→입구 결과를 버튼/글로 각각 확인 | `task07-linked-incoming-v2.log`·`.json` |
| `airport-check --snapshot .` | 종료 0, boundary 382·document 0·compartments 0. TASK-07 주 변경본, 임시 홈. 기준선 변경 없음 | `task07-completion-airport.log`·`.json` |
| 금지 파일 Git diff | 종료 0, 허브·금고 백업 소비자·앱 설치/연결 제품 파일 변경 0줄(TASK-06 이후) | `task07-protected-diff.json` |

AT-SM-63·65~68의 native 입력 증거는 `test_slack_move_native.py`, 64는 `test_slack_move_incoming.py`, 69는 `test_slack_move_retained.py`에 있다. AT-SM-65 결과 전송은 TASK-06 진단 통합 시험, 66 보고 검토는 TASK-06 검토 통합 시험을 함께 근거로 쓴다. 예외를 추가한 뒤에도 정기 보고의 native 전송 회귀를 실행했다. 새 입력 시험 초기 실패는 임시 금고/정책 위치, fixture 의존성, 실제 버튼 문구·항목 선택 문법·결과 제목을 실제 계약대로 바로잡은 기록으로 남겼다. 수락 명세·기존 기대값을 바꾸지 않았다.

## TASK-08: 도구 묶음 조립과 실제 도구 집합

운영 커밋 `fcdec420b51193da5cfa3982044c61b33490abb1`의 두 파일만 변경했다. `TKL/hermes_facility/config_assembly.py`는 Slack에 선택된 목록에서 `hermes-slack`만 `hermes-hejo`로 바꾼 hejo 목록을 만들고, 앱 플러그인 추가에도 hejo를 포함한다. 선택하지 않은 기본 묶음은 추가하지 않으며 같은 입력을 다시 조립해도 같다. `app_setup.py`·`app_connect.py` 제품 파일은 바꾸지 않았다.

`tests/test_slack_move_toolsets.py`는 세 가짜 프로필의 조립 결과와 실제 본체 `toolsets.resolve_toolset` 결과를 비교한다. 실제 문 등록과 실제 인스타 플러그인 도구 등록을 임시 홈에 묶었다. 세 경우 모두 전체 도구 이름 집합이 같고 인스타 선택 시 인스타 도구가 포함된다. 문에는 별도 전용 도구가 없어 비교에서 제외한 이름은 없다. 최초 fixture가 다른 임시 홈으로 환경을 바꾸어 문 등록을 보지 못한 실패는 같은 홈을 사용하도록 고쳤다. 도구를 임의로 추가하거나 빼지 않았다.

- 수정 전 main·실행본·worktree config_assembly 해시 일치: `task08-preedit.json`.
- 기존 조립 시험: 종료 0, 9 passed(`task08-baseline.log`·`.json`).
- AT-SM-70~72와 조립 회귀: 종료 0, 15 passed(`task08-toolsets-v3.log`·`.json`).
- 새 시험·조립·앱 연결/설치 회귀 네 파일: 종료 0, 58 passed(`task08-reviewed.log`·`.json`), 커밋 `fcdec420`과 해당 파일 해시 일치.
- 임시 홈 `airport-check --snapshot .`: 종료 0, boundary 382·document 0·compartments 0(`task08-airport.log`·`.json`). 해시 `task08-final-source.json`. 이 검사는 연결 입력 후속 수정 전이며, 후속 커밋의 Git 훅 경계 검사도 같은 수치로 통과했다.

[다음] 이 보고를 커밋한 뒤 공개 커밋과 운영 `fcdec420`을 각각 고정한 detached worktree에서 마지막 `bash scripts/test.sh`를 실행한다. 이 문단 시점에는 미실행이다. 운영 적용·재시작·실제 Slack/고객 전송·푸시는 하지 않았다. 위키/H-5의 이전과 TASK-09·10은 여전히 범위 밖이다.


## 최종 고정 커밋 검사와 검토 인계

[확인] `bash scripts/test.sh`를 공개 `28e9d7cbf70f6324c4818ee0373550ebb1affc76`와 운영 `fcdec420b51193da5cfa3982044c61b33490abb1` 두 detached worktree 조합에서 실행해 **종료 0**을 확인했다. Python 434 passed, 실제 게이트웨이 정상 종료, 앱 기본·연동 fixture와 훅 시험 9건 모두 통과했다. 앱 실행 전 중복 app-tests가 없음을 확인했다. 입력 서비스 통신 경고와 기존 Swift 경고가 있었지만 실제 종료는 성공이다. 앱만 실패한 조건에 해당하지 않아 제품 기준 커밋의 비교 검사는 실행하지 않았다. 두 검사 worktree를 제거했으며 구현 worktree는 깨끗하다.

- 명령·커밋·종료 코드: `.build/slack-move/task08-final-isolated-full.json`; 전체 로그: 같은 이름의 `.log`.
- 공통 전송 변경 후 인스타·네이버톡 격리 회귀 `python tests/run_isolated.py -q -rs`: 운영 `fcdec420`·공개 `28e9d7c`, 종료 0, 819 passed·건너뜀 0. `task08-shared-instagram.log`·`.json`.
- 최종 운영 `fcdec420`의 임시 홈 `airport-check --snapshot .`: 종료 0, boundary 382·document 0·compartments 0. `task08-final-airport.log`·`.json`. 기준선 재설정 없음.
- 최종 수정 제품 14개 경로의 운영 main/실행본 SHA 대조: 같음(신규 공통 전송은 양쪽 모두 없음). `task08-final-live-check.json`; 운영 main `dba8f4fb8b4e832383d834e2863c1883d06885db`.
- 이 최종 결과를 적는 후속 공개 커밋은 구현 보고와 TASK 상태만 바꾼다. 전체 검사는 위의 고정 커밋 조합에 대한 결과이며, 다른 작업·이후 제품 변경에 대한 통과를 주장하지 않는다.

[검토 인계] TASK-07의 이름 붙은 Slack 예외·실제 입력 증거와 TASK-08 실제 도구 집합을 검토한다. 최신 자체 시험 근거가 없는 새로운 제품 변경이 생기지 않으면 같은 전체 검사를 반복할 필요는 없다. 최종 판정은 검토 역할에 남긴다. 운영 전환 TASK-10 및 푸시는 실행하지 않았으며 별도 승인 전에는 진행하지 않는다. H-5 위키 경로는 Slack에 보류, TASK-09 허브는 범위 밖이다. 다른 작업 문서는 보존했다.


## TASK-10 1~3단계 — 적용 전 기록

1단계의 최신 운영 main 병합은 충돌 없이 완료했다. 검사 대상은 운영 `67e9d3b66e7635978c74631e730432fddfad99c0`(기존 작업 `fcdec420b51193da5cfa3982044c61b33490abb1`와 최신 main `dba8f4fb8b4e832383d834e2863c1883d06885db`의 병합)이며, 적용할 이 작업 제품 경로는 44개다. 실행본과 main 기준 SHA-256은 전부 같고, 이 경로에 최신 main의 다른 변경은 없다. 대상 문은 `ce4e98fb3c35c328a56c99c8bb8e65dfb0acd1f1`, 되돌릴 공용 RELEASE는 `7811c51e26b214f29c8feb6727cbd652bd483a7d`다.

운영 변경 전에 0700 보관 폴더와 실행 가능한 `operate.py`, 파일별 기준·대상 해시, 서비스별 정지·복귀 명령, 이전/대상 문 커밋의 분리 checkout을 준비했다. 실제 경로와 명령은 비추적 `.build/slack-move/task10-application-location.json`이 가리키는 `ROLLBACK.md`·`manifest.json`에 있다. 실행 스크립트 SHA-256: `bb619c0f21ffc5e9e37a9f4d7305e16c2fd9f369b167bd5e51cf077409b40f34`. 적용 전에 보관 파일 해시와 일관된 DB 사본 해시를 기록하며, 중단 사이 DB 내용이 달라지면 교체하지 않는다. 적용 후 확인 실패 시 같은 스크립트가 보관본을 원자적으로 복원하고 이전 문 설치·전체 재시작·서비스 복귀를 수행한다. 스위치·금고·운영 설정은 이 단계에서 쓰지 않는다.

검증: team-kit 49개 파일 1692 passed, 인스타·네이버톡 격리 819 passed(각 종료 0, `task10-merged-teamkit-v2`·`task10-merged-plugin` 로그/JSON). 최초 시험 목록 실행은 하위 경로 누락으로 수집 실패(종료 4, 제품 시험 미실행)였고 원래 경로를 복원했다.

M7 최종 예행은 `task10-rehearsal-v5.log`·`.json`, 종료 0이다. 임시 홈의 지시서·가짜 금고·설정·예약 보관→hejo 변경→복원→조립, 파일 해시 일치와 `slack` 반환, 실제 격리 게이트웨이 두 차례 기동·정상 종료, 가짜 타이머 복귀를 확인했다. 운영 DB는 스키마만 읽어 빈 표를 만든 뒤 새 열 세 개를 추가하고 구버전의 읽기·쓰기를 확인했다. 앞선 예행 실행은 임시 경로 별칭, 조립 전 fixture, 빈 기록장 전제의 기존 시험 재사용 때문에 실패했고 해당 로그를 보존했다. 제품 코드·기존 수락 기대값은 바꾸지 않았다.

2단계 실행 및 3단계 준비물: 아직 미실행. 아래에 실제 결과를 추가한다.

### TASK-10 2단계 중단·원복 결과

**실행본은 전부 적용 전 상태로 되돌렸다. 3단계 준비물·4단계 전환은 시작하지 않았다.** 중단 원인은 구현 담당이 만든 운영 확인 요청의 규격 오류다. 제품 결함으로 판정하지 않는다.

- 최초 적용 시도는 인스타 감시 프로세스 1개 때문에 BUSY로 교체 전에 종료했다. 그 프로세스의 자연 종료 뒤 재확인한 진행 중 턴·네이버 전송·피드 처리·인스타 프로세스는 모두 0이었다.
- 44개 실행 파일과 네이버톡 DB를 0700 폴더에 보관했다. DB는 WAL의 확정 기록을 포함하는 SQLite 일관 사본이며 SHA-256은 `5f2e2428d1d7c9ab6ea82cf1754893c4907c52c695dbd02e09d782c747d02e9e`다. 프로그램 정지 전·후 사본의 논리 내용 일치도 확인했다. 내용은 로그에 출력하지 않았다.
- 관련 프로그램 15개 정지 → 파일 44개 원자 교체 → 대상 문 `ce4e98fb3c35c328a56c99c8bb8e65dfb0acd1f1` 설치 → 전체 재시작을 실행했다. 다른 재시작·릴리스 설치 프로세스는 두 번 확인 모두 0이었다. 재시작 명령, `status --json`, `apps --json`은 각각 종료 0. Slack 6개·iMessage·hejo 연결, 새 오류 로그 0, 파일 교체보다 뒤의 새 프로세스, `slack` 스위치, 소켓 0600까지 확인했다.
- 그 다음 읽기 요청에서 실패했다. `thread_query`는 `employee` 또는 `room` 중 하나만 허용하는데, 확인 스크립트가 둘 다 보냈고 `room_not_found`만 기대했다. 실제 운영 응답의 상태·본문은 assertion 전에 기록하지 못했다. 따라서 운영 응답을 사후 추정하여 통과로 고치지 않는다. 읽기 요청은 한 번이며 글 전송 요청은 없었다.
- 지시대로 즉시 원복했다. 프로그램은 정지 상태를 유지한 채 파일 44개 해시 복원·새 전송 파일 제거·DB 원복 → 기존 문 `7811c51e26b214f29c8feb6727cbd652bd483a7d` 설치 → 전체 재시작 → 프로그램 15개 복귀를 마쳤다. 원복 뒤 Slack 6개·iMessage·hejo 연결, 새 오류 로그 0, 새 프로세스, `status`·`apps` 종료 0, `slack` 반환, 프로그램 정상 실행/대기, DB 행 수 일치를 확인했다. 신규 열 세 개는 없다. 중단 직후 DB 사본도 보관해 두었다.
- 운영 main은 `dba8f4fb8b4e832383d834e2863c1883d06885db` 그대로이며 작업 트리는 깨끗하다. 적용이 실패했으므로 `./sync`, `./airport-check`, 운영 main 적용 커밋은 실행하지 않았다. 자동 보고 관찰도 미실행이다. 스위치·금고·운영 설정·위키·프로젝트 허브·본체·ddots는 고치지 않았다. 실제 고객/Slack 시험 글, 인스타 승인, 푸시 없음.

후속 격리 재현(`task10-read-probe-reproduction.log`·`.json`, 종료 0, 1 passed): 같은 실제 문 어댑터의 임시 Unix 입구에서 잘못된 쿼리는 `400 invalid_frame`, `room` 하나만 주는 없는 방의 스레드 읽기는 `400 room_not_found`; 기록장 추가 0. 기존 수락 시험이나 제품 코드는 바꾸지 않았다. 이 재현은 운영 재적용 또는 운영 응답 증거를 대신하지 않는다.

증거 위치: `.build/slack-move/task10-apply-exit.json`(초기 BUSY, 종료 1), `task10-apply-v2-exit.json`(적용 확인 실패 후 원복, 종료 1), `task10-rollback-final.json`(최종 실행본·릴리스·DB·서비스 복원 확인). 실제 운영 명령별 로그와 시간은 `task10-application-location.json`이 가리키는 보관 폴더의 `operation-state.json`·개별 `.log`에 있다. 원복은 완료됐고 보관 폴더와 고정 릴리스 checkout은 남겼다.

다음 판단: 운영 확인 도우미의 읽기 쿼리를 규격에 맞게 고치고, assertion보다 먼저 HTTP 상태·오류 코드를 보존하도록 한 뒤 재적용할지 판단한다. 인계서의 중단 조건 때문에 이번에는 재적용하지 않는다. 재개 시에는 최신 운영 main·실행본 해시·다른 재시작/릴리스·BUSY를 다시 확인하고 새 DB 보관본을 만들어야 한다. 기존 49개/격리 시험 대상 제품 파일이 바뀌지 않았다면 같은 전체 시험을 이유 없이 반복하지 않는다.


### TASK-10 2・3단계 재개 — 적용 전 기록(인계서 2판)

대상 문 `e68ae82458a62a1c3d3468041c3d6dee0b576a2b`, 운영 작업 `67e9d3b66e7635978c74631e730432fddfad99c0`, 운영 main `dba8f4fb8b4e832383d834e2863c1883d06885db`, 이전 RELEASE `7811c51e26b214f29c8feb6727cbd652bd483a7d`. 운영 main과 실행본 44개·대상 파일 해시가 이전 검사와 같아 기존 49개 시험·인스타 격리 전체 시험을 반복하지 않았다(`task10-retry-source.json`).

확인 도우미는 서로 다른 새 무작위 UUID 두 개와 `room` 쿼리만 사용하며, HTTP 상태와 오류를 파일에 쓴 다음 `400 room_not_found`를 판정한다. 실제 적용에서 사용할 같은 함수로 임시 홈의 실제 문을 시험해 종료 0·1 passed, 기록장 추가 0을 확인했다(`task10-probe-fixed.log`·`.json`). 도우미 SHA-256 `d298cc5eb1170788633cdbaea9cd940ea52401ae263bc1cf70d497423ed34719`.

기존 보관본을 보존하고 별도 0700 보관 폴더를 준비했다. 새 위치는 비추적 `.build/slack-move/task10-retry-location.json`, 구체적인 복원 명령·경로·커밋·파일별 해시는 그 폴더의 `ROLLBACK.md`·`manifest.json`이다. 운영 스크립트 SHA-256 `af14cfbba1f7d54b82ab68d1840529d2933815c344f02fcdcd37f60050a1ce13`. 새 네이버 DB 일관 사본과 실행본 44개는 이 폴더에 보관하며 교체 전 해시를 기록한다. 적용 확인 실패 시 이전 파일·DB·문 설치와 전체 재시작·서비스 복귀를 수행한다. 아래에 실제 적용 결과를 추가한다.

### TASK-10 재적용 결과·자연 보고 관찰 중

재적용 도우미 `operate.py apply`는 종료 0이다(`task10-retry-apply.json`, 실제 명령과 개별 로그는 새 보관 폴더). 진행 중 턴·네이버 전송·인스타 프로세스·피드 처리 0, 다른 작업의 재시작/릴리스 설치 0을 다시 확인했다. 새 DB 일관 사본과 실행 파일 44개를 보관하고 프로그램 15개 정지 → 원자 교체 → 문 `e68ae82458a62a1c3d3468041c3d6dee0b576a2b` 설치 → 전체 재시작 → 확인 → 프로그램 복귀를 완료했다. 이번에는 원복하지 않았다.

- 입구 소켓 0600. 수정한 단일 읽기 요청의 실제 응답 `400 room_not_found`를 판정 전에 `ingress-read-response.json`에 기록했다.
- Slack 연결 6개·iMessage·hejo 연결, 교체 시각 뒤의 새 프로세스, 새 게이트웨이 오류 로그 0, 스위치 답 `slack`. 재시작·`status --json`·`apps --json` 각각 종료 0.
- 프로그램 15개 정상 실행/대기, 네이버 사건 표의 새 열 3개와 기존 행 수 유지. 후속 읽기 검사에서도 실행 파일 44개의 대상 해시 일치, 프로그램 상태 정상, 운영 지시서의 `delivery.platform` 부재를 확인했다(`task10-post-application.json`).
- **2단계 전체 완료는 아직 아니다.** 재시작 이후 자연 발생 보고의 Slack 도착을 관찰 중이다. 다음 정시 인스타 요약은 실행됐으나 대기 문의가 없어 글을 올리지 않았다. 뉴스 검사도 전송 0건이었다. 시험 글이나 보고 강제 실행은 하지 않았다. 도착 확인 전이므로 `./sync`·`./airport-check`·운영 main 적용 커밋은 미실행이다. 관찰 시작/기한은 비추적 `task10-observation.json`에 적는다.
- 인스타의 기존 질문 닫기 경고는 재적용 이전 로그에도 존재했다. 이번 변경의 신규 오류로 단정하거나 제품을 임의 수정하지 않았다. 고객 문장·대화 내용은 보고에 옮기지 않았다.

3단계 준비물 6개는 새 보관 폴더의 `preparation/`에 작성했다. 실제 경로·파일별 줄 수·SHA-256은 비추적 `.build/slack-move/task10-preparation.json`에 있다. 방 5개의 구성원 수는 순서대로 6·5·5·5·5명이며 대표 직원은 근거를 붙인 **제안**이다. 설정의 빈 Slack 허용 목록은 기존 입구 규칙상 제한 없음으로 해석했고, 실제 Slack API 조회로 참여 여부를 확인했다고 주장하지 않는다. 방은 만들지 않았으며 앞으로 생성될 방 id는 생성 응답을 참조하는 식으로 표기했다.

받을 곳 대조표 39행은 설계·TASK-06 전수표 및 Slack에 남기는 세 길을 포함하며 빈 셀 0이다. 인스타 학습 보고와 자동 답장 보고를 별도 행으로 나누고, 매시 요약은 기존 고객 방에 대응했다. 예약 목록은 6개 프로필의 Slack 예약 14개(꺼진 예약 포함)와 공개 채널 자동 가입의 비활성화 제안이다. 시스템 알림은 재시작·온라인 제외, 종료·저장소 경고 유지 제안만 작성했다. 정지 목록은 적용 때 다룬 프로그램 15개와 전체 게이트웨이/예약 실행기이며 별도 앱·위키 등 제외 항목도 구분했다.

운영 설정·명부의 임시 사본에서 실제 team-kit·team-delegation·해당 인스타 플러그인의 등록과 본체 도구 집합 풀이를 실행했다. 등록한 훅·도구 핸들러는 호출하지 않았다. 외부 쓰기·비밀 파일 읽기·외부 네트워크를 차단하고 조립 결과는 임시 사본에만 만들었다. 프로필별 Slack/hejo 도구 수는 80/80, 47/47, 78/78, 31/31, 28/28, 87/87이고 차이 0, 등록 오류 0이다(`task10-toolsets-results.json`, 각 실행 종료 0). 첫 확인 도우미는 플랫폼 핸들러 등록 콜백이 빠져 종료 1이었으며, 도우미를 실제 인터페이스에 맞춰 고쳤다. 제품·시험 기대값은 변경하지 않았다.

운영 main은 기존 커밋 그대로이고, 작업 브랜치도 `67e9d3b66e7635978c74631e730432fddfad99c0` 그대로다. 이번 변경은 확인 도우미와 비추적 준비표 및 이 보고다. 4단계 전환, 금고/운영 설정 쓰기, 위키·프로젝트 허브·본체·별도 앱 수정, 실제 시험 글·고객 글, 승인 버튼 조작과 푸시는 하지 않았다.

### TASK-10 자연 보고 관찰 종료 — 미확인 반환

2026-11-22 09:51:11 재시작부터 **10:51:11 KST 기한까지 자연 발생 보고의 Slack 도착을 확인하지 못했다.** `task10-observe-natural.py`는 기존 기록만 30초 간격으로 읽었고, 기한 종료 시 전송 후보 0으로 정상 종료했다(종료 0은 관찰 프로그램의 종료 상태이며 도착 수락 조건의 통과가 아니다). 인스타 10시 요약은 대기 문의가 없어 올리지 않았고, 뉴스 10시·10시 30분 검사는 각각 전송 0·실패 0이었다. 마지막에 관찰 시작 이후 바뀐 상태·학습 JSON 16개에서 저장된 Slack 글/스레드 시각도 대조했으나 기한 내 후보는 없었다. 모든 Slack 전송이 없었다고 단정하지 않고 **요구한 도착 증거가 미확인**이라고 보고한다.

증거: `.build/slack-move/task10-observe-natural.log`, `task10-observation.json`, `task10-final-receipt-survey.json`. 관찰은 송신 함수를 부르거나 Slack API를 직접 호출하지 않았으며, 시험 글·강제 보고·고객 글·승인 버튼 조작은 하지 않았다.

기한 종료 뒤 읽기 확인(`task10-observation-final-check.py`, 종료 0; `task10-observation-final-server.log`·`.json`): 적용 파일 44개는 대상 SHA-256과 일치, 프로그램 15개는 정상 실행/대기, 게이트웨이는 교체 뒤 시작한 프로세스로 실행 중, 오류 로그는 재시작 뒤 변경 없음, 소켓 0600, 공용 RELEASE는 `e68ae82458a62a1c3d3468041c3d6dee0b576a2b`, 스위치 답은 `slack`, `delivery.platform`은 운영에 없음. 준비표 작성 때와 운영 프로필 설정 해시도 같다. 운영 main `dba8f4fb8b4e832383d834e2863c1883d06885db`와 작업 브랜치 `67e9d3b66e7635978c74631e730432fddfad99c0`는 그대로이며 둘 다 깨끗하다.

실제 적용 확인 실패는 발견하지 않았고, 이번 지시의 “기한에도 도착 증거가 없으면 미확인으로 반환”에 따라 **적용 상태를 유지하고 반환한다.** 다시 적용하거나 재시작·원복하지 않았다. 도착 조건이 미확인이므로 운영 `./sync` → `./airport-check` → 적용 커밋은 **미실행**이다. 2단계 전체 통과·운영 적용 커밋 완료로 세지 않는다. 3단계 준비물 6개는 앞 절의 상태로 보존했고, 4단계 전환은 미착수다. 보관본과 되돌리기 절차도 유지한다.

다음 검토는 자연 보고 미확인 상태에서의 후속 관찰·운영 기록 절차다. 사용자가 요청하지 않은 시험 글 전송이나 기한 연장, 전환은 하지 않는다. 보고만 고친 이번 변경에 제품 전체 시험은 반복하지 않았다.

공개 보고 최종 검사: `scripts/scan_private.py`·`git diff --check` 각각 종료 0. 로그는 `.build/slack-move/task10-observation-final-scan.log`, 변경 문서 해시·명령·종료 코드·커밋 대응은 `task10-observation-final-checks.json`에 기록한다. 운영 main 적용 커밋과 구분하여 이 작업의 보고·상태 문서만 커밋한다.
