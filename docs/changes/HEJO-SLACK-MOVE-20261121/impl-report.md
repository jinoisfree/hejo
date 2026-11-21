# HEJO-SLACK-MOVE 구현 인계 보고

## 현재 판단: TASK-02 구현·국소 검증 완료, 분리 전체 검사 대기

[확인] 설계 6판과 구현 검토 1차의 V-3·V-4·V-5, D-1·D-2를 반영했다. TASK-03~08은 아직 미착수이며 전체 작업의 완료 판정은 요청하지 않는다.

- 받은 지시: [handoff.md](handoff.md) 6판, [verdict.md](verdict.md) 구현 검토 1차, TASK-02~08. 계획 보완 기준 `716f67e5ae61795202023dc74694a53df7da0a06`, 제품 기준 `cb06e7d`. 고위험, 필요 증거 수준 2, 연합개발.
- 다른 작업의 `app/` 및 HEJO-FINDER-FOLDERS 문서 변경은 보존하며 커밋에 포함하지 않는다. 전체 검사는 TASK 커밋을 임시 detached worktree로 꺼내 실행한다.
- 운영 저장소 최초 착수 HEAD는 `f3318572b9cbd85fccb54347872feca8915532cd`였다. 당시 대상 실행본·기준본 Python 소스 233개의 SHA-256이 같았다(`.build/slack-move-baseline-check.json`). team-kit 착수 전 최신 HEAD와 파일별 해시를 다시 확인한다.
- 운영 저장소 worktree·team-kit·직원 플러그인 변경은 아직 없다. 운영 적용·재시작·실제 전송·비밀 파일 열기·본체·ddots·앱 소스 수정·푸시는 하지 않았다.
- 직접 구현·시험했으며 하위 에이전트는 사용하지 않았다.

## TASK-02: 서버 안 전용 입구

### 책임과 변경

규격의 첫 커밋은 `9f7dfb29db663836ea094c8c2d1ba0f727099afe`이며 `schemas/hejo-local-v1.json`만 포함한다. TASK-02 구현 커밋은 이 절을 포함한 커밋이다. 검사할 정확한 커밋과 결과는 아래 증거 기록에 남긴다.

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
- V-1: 커밋 후 분리 전체 검사 대기. V-2: TASK-03~08 잔여.

### 실행 증거

게이트웨이 Python과 로컬 `.build/connections-env.sh`의 의존성, 임시 홈·가짜 명부를 썼다. 로그 기준 폴더는 `.build/slack-move/`다. 필요한 증거 수준 2를 입구 범위에서 확인했으며 전체 작업은 미완료다.

| 명령·검사 | 실제 결과 | 로그 |
|---|---|---|
| `python -m pytest tests/acceptance/test_slack_move_gate.py gate/tests/test_rooms.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` (짧은 임시 `--basetemp`) | 종료 0, 19 passed | `task02-revision-tests.log`, `.exit` |
| `python .build/slack-move/mutation_check.py` | 실행기 종료 0. 작성자·중복 변형의 pytest는 각각 종료 1·1 failed(의도한 결함 검출). 원본 불변 | `mutation-author.log`, `mutation-dedup.log`, `mutation-results.json` |
| 이전 변경본 `bash scripts/test.sh` | 종료 1. Python 426 passed, 실제 게이트웨이 정상 종료. 타 작업의 앱 파일 변경으로 Swift 빌드 실패. 최신 전체 통과 증거로 쓰지 않음 | `task02-full.log`, `task02-full.exit` |

초기 기본 임시 경로의 문 시작 실패는 짧은 pytest 기본 경로를 사용해 해소했다. 최초 시험 코드의 삭제 응답 프레임 이름 오류는 기존 계약의 `delete`와 `scope=thread`로 바로잡았다. 수락 기대값은 변경하지 않았다. 이전 중단 시점의 파일 해시는 `stop-evidence.json`에 보존되어 있다.

## 남은 범위와 재개 순서

TASK-02 분리 전체 검사 → TASK-03 → TASK-04 → TASK-05(인스타 최우선) → TASK-06 → TASK-07 및 TASK-08. TASK마다 결과·파일·검증 증거를 이 보고에 더한다. team-kit 착수 때 운영 저장소 최신 기준과 실행본을 대조한 뒤 허가된 임시 worktree를 만든다. TASK-09와 운영 전환 TASK-10은 계속 범위 밖이다.
