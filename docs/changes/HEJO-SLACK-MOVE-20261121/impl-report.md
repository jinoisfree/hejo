# HEJO-SLACK-MOVE 구현 인계 보고

## 현재 판단: 부분 구현·멈춤 보고(분리 전체 검사 실패, 예약 작성자 설계 빈틈)

[확인] 설계 6판과 구현 검토 1차의 V-3·V-4·V-5, D-1·D-2를 반영했다. TASK-02 분리 전체 검사는 앱 포커스 단언에서 실패했다. 검사가 도는 동안 작성한 TASK-03 변경과 시험은 미커밋이며, 실제 예약 시험에서 기본 프로필의 작성자 선택 문제를 확인해 멈췄다. TASK-04~08은 미착수이고 전체 완료 판정은 요청하지 않는다.

- 받은 지시: [handoff.md](handoff.md) 6판, [verdict.md](verdict.md) 구현 검토 1차, TASK-02~08. 계획 보완 기준 `716f67e5ae61795202023dc74694a53df7da0a06`, 제품 기준 `cb06e7d`. 고위험, 필요 증거 수준 2, 연합개발.
- 다른 작업의 `app/` 및 HEJO-FINDER-FOLDERS 문서 변경은 보존하며 커밋에 포함하지 않는다. 전체 검사는 TASK 커밋을 임시 detached worktree로 꺼내 실행한다.
- 운영 저장소 최초 착수 HEAD는 `f3318572b9cbd85fccb54347872feca8915532cd`였다. 당시 대상 실행본·기준본 Python 소스 233개의 SHA-256이 같았다(`.build/slack-move-baseline-check.json`). team-kit 착수 전 최신 HEAD와 파일별 해시를 다시 확인한다.
- 운영 저장소 worktree·team-kit·직원 플러그인 변경은 아직 없다. 운영 적용·재시작·실제 전송·비밀 파일 열기·본체·ddots·앱 소스 수정·푸시는 하지 않았다.
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
- V-1: 커밋을 분리한 전체 검사도 실패해 미해소(아래). V-2: TASK-03 부분 구현, TASK-04~08 잔여.

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

## TASK-03: 부분 구현·미커밋

- `gate/__init__.py`: `room:<UUID>` 대상 문법. `gate/rooms.py`: 첫 글이 직원이면 작성자, 사장 글이면 내부 수신자를 현재 구성원·명부로 거른다. `gate/adapter.py`는 기존 `recipients`에 기록장·스레드를 전달한다. `room_save_record` 추출 위에 작업했다.
- `tests/acceptance/test_slack_move_gate.py`: AT-SM-20~22의 실제 WS 수신·주인 유지·멘션·구성원 제거·targeted·1:1 및 AT-SM-12 문법을 추가했다. AT-SM-10~12는 기존 `gate.tests.gateway_delivery`의 격리 감사와 실제 `start_gateway`를 그대로 쓰고 시나리오만 바꾼다. 본체·전송 경로를 대역으로 바꾸지 않는다.
- 실행: TASK-03 미커밋 변경본에서 `python -m pytest tests/acceptance/test_slack_move_gate.py gate/tests/test_rooms.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` → **종료 1, 21 passed·1 failed**. 로그 `task03-targeted.log`, `.exit`. 새 예약 시험이 실패했으며 AT-SM-10의 B 보고 두 건과 서로 다른 스레드, 없는 방 거절까지 확인한 뒤 멈췄다. 뒤의 삭제 방·기존 대상 검사는 이 실행에서 도달하지 못했다.
- TASK-03 파일은 커밋하지 않았다. 완료나 전체 회귀 통과로 취급하지 않는다. README 갱신·분리 전체 검사·TASK-03 커밋은 미실행이다.

## 멈춤 보고와 선택이 필요한 지점

### S-1: 분리 전체 검사에서도 앱 포커스 단언 실패

[확인] `.build/slack-move/verify-task02`를 TASK-02 커밋 `2911232cbea8c0e48fc26aeca2b925050194bd13`의 detached worktree로 만들고 전체 검사를 실행했다. 원래 폴더의 앱 미커밋 변경은 들어가지 않았다. `app/Tests/TestMain.swift:216`의 `controller.panel.isKeyWindow` 단언(`AT92 opening takes key focus (V08 replaces old AT47)`)이 실패했다. 컴파일은 끝났고 Python 428개와 실제 게이트웨이 검사는 통과했다. 단순 컴파일 충돌이었던 이전 실패와 다르며, UI 환경 경합인지 기존 앱 결함인지 아직 구분하지 못했다. 앱을 고치거나 기준을 완화하지 않았다.

worktree의 추적 변경이 없음을 확인한 뒤 `git worktree remove`로 제거했다. 로그와 검사 커밋은 원래 저장소의 `.build/slack-move/`에 보존했다. 선택지: 앱 담당이 포커스 실패를 조사하고 동일 커밋의 실행 환경을 확보하거나, 계획 담당이 미해소 전체 검사와 독립적으로 문·team-kit 갈래를 진행할지 명시한다. 권고: 앱 코드 수정 없이 실행 환경부터 별도 확인하고, 이 결과를 통과로 바꾸지 않는다.

### S-2: 기본 프로필 예약은 방 대표로 작성자를 바꿔 구성원 검사를 통과함

[확인] AT-SM-11의 구성원 아닌 C를 기본 프로필(`default`)로 둔 실제 게이트웨이 시험에서, 방 구성원 `alpha`·`beta`, 대표 `alpha`인 방으로 C가 예약 보고를 보내면 실패 대신 성공한다. 방을 만든 것과 B의 두 번 예약은 실제 입구·실제 스케줄러를 거친다. 다른 플랫폼으로 보내지는 않는다.

근거: `gate/adapter.py`의 `forwarder`는 기본 프로필을 제외하고, `_forward`는 전달자에만 `hermes_profile`을 붙인다. `send`는 `metadata.hermes_profile`이 없으면 방 대표를 직원으로 정한다. 본체 스케줄러의 `_live_route_metadata`는 job·notify·thread 정보를 넘기며 직원 id를 넣지 않는다. 따라서 기본 어댑터의 예약은 방 대표로 기록된다. design 3.2의 “새 코드는 문법뿐”은 이 경로를 다루지 못한다. `send`의 작성자 선택까지 바꾸는 것은 지정된 TASK-03 변경 위치(`receive`의 받는 직원 계산)를 넘으므로 구현 규칙 2절에 따라 멈춘다.

실패 단언에 오류 반환값과 추가된 가짜 기록을 표시해 한 번 더 확인했다(`task03-scheduler-stop.log`, `.exit`). 재확인 결과는 종료 1, 1 failed·14 deselected이며 반환 오류는 null, 추가된 글의 작성자는 `alpha`, 본문은 `Outsider`였다. 기대한 `room_member_required`는 바꾸지 않았다. 선택지: 기본 프로필의 예약 작성자를 전달자와 동일하게 명시하도록 설계·영향 범위를 보완하거나 기본 프로필 예약의 적용 범위를 명확히 정한다. 권고: 실제 보내는 프로필의 작성자와 구성원 검사를 보장하고, 본체를 고치지 않는 문 쪽 책임으로 보완한다. 기본 프로필을 시험에서 빼거나 성공을 허용해 통과시키지 않는다.

## 남은 범위와 재개 순서

계획 담당이 S-1·S-2를 판단한 뒤 재개한다. TASK-02 전체 실패 처리 → TASK-03 기본 프로필 작성자 경계·미도달 시험·README·커밋·분리 전체 검사 → TASK-04 → TASK-05(인스타 최우선) → TASK-06 → TASK-07 및 TASK-08. 판단 대기 중 가능한 부분은 기존 변경·로그 검토이며 추가 구현은 멈췄다. team-kit 착수 때 운영 저장소 최신 기준과 실행본 SHA-256을 다시 확인한다. TASK-09와 운영 전환 TASK-10은 계속 범위 밖이다.

마지막 상태 대조: 검사 중 다른 작업이 앱 두 파일을 `b21dd94528981dddcfa98e5a9883e864442d243d`로 커밋했다. 이 커밋은 분리 전체 검사 대상에 포함되지 않았고, 그 이후 HEAD의 전체 통과를 주장하지 않는다. 타 작업의 보고서 미커밋 변경은 그대로 보존한다. 최종 변경본의 `python scripts/scan_private.py`는 종료 0(`.build/slack-move/stop-scan.log`, `.exit`), `git diff --check`도 종료 0이다.
