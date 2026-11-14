## 검증 판정: HEJO-FOUNDATION TASK-02 / 문 핵심과 통신 규격 v1 (1차)

1. **판정: 부분 완료**
2. **검증 조건:** 교차 모델(계획·검증 담당 Claude, 구현 담당 codex/gpt-6.1-sol). 같은 대화에서 설계와 검토를 함께 했으므로 설계 적합성을 따로 판정했다. 검토한 코드 상태: `main` `0c21b769e3419710f9b956faad4e572f1cebf626`(기준 `48e03cb`), 작업 트리 깨끗.
3. **설계 적합성(4.2):**
   - 구현은 design 1·2·2.1·2.2·3절과 맞다. 확인한 것: 기본 프로필 단독 리스너, 보조 프로필 비활성(`retryable=False`), 주소 검사, 페어링·출입증(해시·0600·잠금·취소), `source.profile`, 허용 사용자 YAML 브리지, flock 단독 쓰기, write+fsync 뒤 전송, 실패 시 `ftruncate`, 시작 시 꼬리 복구, 연결별 재전송·대기열, 2.2 훅(`edit_message(..., metadata=None)`, `await set_reply_state`, `register_click_handler`).
   - **설계 결함 3건(기획설계 책임):**
     - (a) `message.files[]` 항목 모양이 정의되지 않았다(GAP-T02-01). 구현 담당이 멈춘 것이 맞다.
     - (b) welcome과 실시간 프레임의 순서를 정하지 않았다(V-2의 원인).
     - (c) Hermes `stop_typing(chat_id)`에는 스레드 정보가 없는데, 같은 직원의 동시 스레드를 어떻게 처리할지 정하지 않았다(V-3의 원인).
   - 세 건 모두 이번 검토에서 design 2절·2.1절 0항, spec(REQ-HF-05.AC-05, REQ-HF-06.AC-08, REQ-HF-07.AC-03), 수락 시험 AT-HF-44~46으로 보완했다.
4. **직접 확인한 것:**
   - 전체 시험을 다시 실행했다: Hermes venv에서 `HERMES_HOME=$(mktemp -d) PYTHONPATH=.build/task02-deps:<Hermes 소스>:. HEJO_TEAM_KIT_LIB=<team-kit lib> python -m pytest gate/tests tests/acceptance/test_gate_foundation.py -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` → 종료 0, **38 passed**.
   - 변형 검사 1건을 직접 했다(임시 worktree, 검사 뒤 삭제): `broadcast`의 재전송 중 대기열을 끄면 AT-HF-33이 실패한다(`1 failed, 1 passed`). 구현 담당의 변형 4건 로그(`.build/task02-mutations.log`)와 함께 보면 핵심 보호 경계가 시험으로 지켜진다.
   - 승인 문서·수락 명세는 바뀌지 않았다(`git diff 48e03cb 0c21b76 -- docs tests/acceptance/HEJO-FOUNDATION.md`에 impl-report 추가만 있음).
   - 추적 파일의 개인값 패턴 검사: 0건(수락 명세 AT-HF-42에 쓴 가짜 경로 예시는 제외. 이 예시는 TASK-07 예외 목록 대상).
   - 증거 수준: **2 확인**(실제 Hermes 모듈·인가 믹스인·프로필 API·YAML 브리지 + 차례 대역, 임시 홈). 3·4는 미실행이며 이번 TASK의 요구가 아니다.
5. **지적 목록과 처분 상태:**

- 번호: V-1
  - 위치: `schemas/hejo-wire-v1.json` `$defs.file`
  - 위반 기준: REQ-HF-07(첨부 계약), handoff 9번(이후 TASK가 쓰는 첨부 필드 정의)
  - 근거: `$comment: BLOCKED` 외에 항목 정의가 없다. 원인은 설계 누락이다.
  - 등급: 차단
  - 보낼 곳: 기획설계 → 설계 보완 완료(design 2절 `message.files[]` 항목). 구현 반영은 대기.
- 번호: V-2
  - 위치: `gate/server.py:205-214`
  - 위반 기준: design 2.1(보완된 0항), REQ-HF-06.AC-08
  - 근거: 인증 직후 `connections`에 넣은 뒤 `welcome`을 보낸다. `since`가 없으면 `replaying=False`라서, 그 사이 `broadcast`되는 기록 프레임이 `welcome`보다 먼저 갈 수 있다. 또 `hello.since > head`를 검사하지 않는다(`sync`는 검사함).
  - 등급: 비차단(이번 보완에서 수정)
  - 보낼 곳: 구현
- 번호: V-3
  - 위치: `gate/adapter.py:224-238`
  - 위반 기준: REQ-HF-05.AC-03·AC-05(보완)
  - 근거: `_typing_threads`가 직원마다 스레드 하나만 기억한다. 같은 직원의 두 스레드가 동시에 작성 중이면, 먼저 시작한 스레드의 `off`는 보내지 않는다. `ttl_seconds`도 없다.
  - 등급: 비차단(이번 보완에서 수정)
  - 보낼 곳: 구현
- 번호: V-4
  - 위치: `gate/server.py:238-240`
  - 위반 기준: 30-verification 4.4(원인을 구별할 수 있는 실패)
  - 근거: 넓은 `except Exception`이 예외 정보 없이 `log.error("inbound_dispatch_failed")`만 남긴다. 프레임 본문을 기록하지 않는 조건은 유지하되 예외 종류와 스택은 남겨야 한다.
  - 등급: 비차단
  - 보낼 곳: 구현
- 번호: V-5
  - 위치: `gate/journal.py` `records`·`page`·`message`, `gate/adapter.py:206` 중복 검사
  - 위반 기준: 없음(현재 요구 충족)
  - 근거: 기록장 전체를 메모리에 두고 선형으로 찾는다. 기록장은 영구 보존이라 시간이 갈수록 커진다.
  - 등급: 기술 부채(보존·색인 정책은 후속 작업에 기록)
  - 보낼 곳: 기획설계(후속)

6. **기획설계로 넘긴 것:** V-1·V-2·V-3의 설계 보완은 이번 판정과 함께 완료했다(design·spec·수락 시험·tasks 갱신). V-5는 1단계 이후 "기록장 보존·색인" 과제로 둔다.
7. **미검증 범위와 남은 위험:**
   - 실제 게이트웨이 실행과 멀티플렉스 운영(수준 3), 노트북·Tailscale 실접속(수준 4)
   - 개인값 검사기(TASK-07 미생성, 이번 판정은 대체 정규식 확인만)
   - 첨부 HTTP·기본 버튼·보조 배달(TASK-03a/03b)
   - 페어링 코드는 12자 base64url(72비트)이라 사람이 입력하기 어렵다. 앱 연결 창을 만드는 TASK-05에서 입력 방식(붙여넣기)을 확인한다.
8. **미완료 원인 분류:** 설계 오류(누락). 첨부 항목 모양, welcome 순서, 동시 스레드 작성 중 처리가 설계에 없었다. 완료까지 남은 조건:
   - (1) 스키마 `$defs.file` 구현과 AT-HF-46
   - (2) welcome 우선·since 검사, AT-HF-44
   - (3) 작성 중 스레드 집합·`ttl_seconds`, AT-HF-45
   - (4) 디스패치 예외 기록 보완
   - (5) 기존 38개 시험과 새 시험 모두 통과
9. **현재 명세 반영 요청:** 해당 없음(완료 아님).

---

## 검증 판정: HEJO-FOUNDATION TASK-02 / 보완 1 재검토 (2차)

1. **판정: 부분 완료**
2. **검증 조건:** 교차 모델. 검토한 코드 상태: `main` `642cfceca31c5d01c35e1c0a1d1fcdfff408286a`(기준 `d9f9817`), 작업 트리 깨끗. 재검토 범위는 바뀐 7파일과 그 영향을 받는 시험(30-verification 6.3).
3. **설계 적합성(4.2):**
   - V-1~V-4 반영은 보완 설계와 맞다.
     - 스키마 `$defs.file`: 네 필드 필수, 추가 필드 금지, 경로 구분자 금지.
     - welcome 우선: 인증 뒤 연결 등록 전에 welcome을 보내고, `head_seq` 기준으로 재전송한다. 사이에 생긴 기록은 기록장에서 회수한다.
     - `invalid_since` 처리.
     - 직원별 작성 중 스레드 집합, `ttl_seconds: 6`.
     - 예외 종류·스택 기록(본문 제외).
   - 새로 드러난 설계 결함 1건: 1 MiB를 넘는 프레임에 `error(too_large)` 도착을 요구했는데, 전송 계층에서 보장할 수 없다(V-6). design 2절 크기 한도 문단을 보완했다. 이제 "최선 노력 오류 + 닫기 코드 1009, 앱은 둘을 같은 뜻으로 처리"다.
4. **직접 확인한 것:**
   - 전체 시험 6회 연속 재실행(커밋 `642cfce`, 임시 홈, 1차와 같은 명령): 매회 종료 0, **42 passed**.
   - 구현 담당 로그 `.build/task02-r1-final.log`: 같은 명령 1회 종료 1(41 passed / 1 failed). 실패는 `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`의 1 MiB 초과 프레임 단계에서 오류 프레임 대신 CLOSE(257)를 받은 것이다.
   - 기준 커밋(`d9f9817`)에서도 같은 간헐 실패를 재현한 기록이 있다(`.build/task02-r1-frame-race.log`, 기준 2/5·현재 1/5 실패).
   - 승인 문서·수락 명세 변경 없음(`git diff d9f9817 642cfce -- docs tests/acceptance/HEJO-FOUNDATION.md`에 impl-report만).
   - AT-HF-44~46 코드는 명세의 절차·합격 기준과 맞는다(welcome 직전 기록 3개 주입, 두 스레드 off, 스키마 무효 경우).
   - 증거 수준: **2 확인**.
5. **지적 목록과 처분 상태:**
   - V-1 (차단): **해소**. 스키마 구현과 AT-HF-46 통과.
   - V-2 (비차단): **해소**. `gate/server.py` welcome 우선·since 검사, AT-HF-44 통과.
   - V-3 (비차단): **해소**. `gate/adapter.py` 스레드 집합·ttl, AT-HF-45 통과.
   - V-4 (비차단): **해소**. 예외 종류·스택 기록과 본문 미기록 시험 통과.
   - V-5 (기술 부채): 유지(후속 과제).
   - 번호: V-6
     - 위치: `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`(1 MiB 초과 단계), `gate/server.py` `BoundedWebSocket.close`
     - 위반 기준: 30-verification 7.1(검증 결과가 안정적이지 않음). 원인은 design 2절 크기 한도 요구가 전송 계층과 맞지 않은 것.
     - 근거: 구현 담당 실행 1/1 실패, 진단 5회 중 1회 실패(기준 커밋 5회 중 2회). 검토자 6회는 모두 통과. 상대가 1 MiB를 보내는 중에 서버가 닫으면 TCP 재설정으로 앞서 보낸 오류 프레임이 버려질 수 있다.
     - 등급: 차단(시험 묶음이 안정적으로 통과하지 않음)
     - 보낼 곳: 기획설계(설계 보완 완료) → 구현(시험·닫기 코드 정렬)
6. **기획설계로 넘긴 것:** V-6 설계 보완 완료(design 2절 크기 한도). 요구 변경은 아니다. REQ-HF-03·NFR-HF-02의 "실패가 게이트웨이를 멈추지 않음"은 그대로이고, 너무 큰 프레임의 알림 방식만 전송 한계에 맞춰 분명히 했다.
7. **미검증 범위와 남은 위험:** 1차 판정 7항과 같다(수준 3·4, 개인값 검사기, TASK-03 범위, 페어링 코드 입력 방식).
8. **미완료 원인 분류:** 설계 오류(전송 한계와 맞지 않는 실패 알림 요구). 완료까지 남은 조건:
   - (1) 1 MiB 초과 프레임은 닫기 코드 1009로 닫는다(오류 프레임은 최선 노력).
   - (2) 시험은 "오류 프레임 `too_large` 또는 닫기 코드 1009" 중 하나를 받고, 닫기라면 코드가 1009이며, 그 뒤 문이 연결을 유지하고 새 연결로 roster 응답을 받는 것까지 확인한다.
   - (3) 전체 시험 묶음 20회 연속 종료 0.
9. **현재 명세 반영 요청:** 해당 없음.

## 검증 판정: HEJO-FOUNDATION TASK-02 / 보완 2 재검토 (3차)

1. **검토 대상:** 구현 커밋 `818a64775389556a1710ed8109c54a2df02d1444`(기준 `05b0c11`). 변경 3파일: `gate/server.py`, `gate/tests/test_boundaries.py`, `impl-report.md`.
2. **판정: 부분 완료.** 서버 코드 변경은 맞다. 그러나 보완한 시험이 여전히 간헐 실패한다.
3. **설계 적합성(4.2):**
   - `BoundedWebSocket.close`: 오류 프레임 전송이 실패해도 1009 닫기를 건너뛰지 않는다. 설계 2절 2판과 맞고 유지한다.
   - 새 단위 시험 `test_oversize_close_survives_error_frame_failure`: 적절하다.
   - 남은 결함은 설계 쪽이다(아래 V-7).
4. **직접 확인한 것:**
   - 구현 담당 로그 `.build/task02-r2-repeat.log`·`task02-r2-results.json`: 20회 모두 종료 0, 43 passed. 변형 시험 로그(1009→1000이면 종료 1)도 확인했다.
   - 검토자 전체 시험 20회(`HEJO_TEAM_KIT_LIB` 지정, 임시 홈): 모두 종료 0, 43 passed(`.build/task02-r2-review.log`).
   - 검토자가 `HEJO_TEAM_KIT_LIB` 없이 먼저 10회 돌렸다. 이때 AT-HF-08[True]는 `hermes_facility` 모듈이 없어 매회 실패했다. 이는 검토자 환경 탓이므로 판정에서 뺀다. 다만 그 10회 중 1회는 `test_bad_frames_are_isolated`가 `1006 == 1009`로 실패했다.
   - 해당 시험만 60회 돌린 집중 실행(`-k bad_frames`): **4/60 실패**. 네 번 모두 `ws.close_code`가 `ABNORMAL_CLOSURE(1006)`였다(`.build/task02-r2-stress.log`, `task02-r2-stress-fail-*.log`).
   - 승인 문서·수락 명세 변경 없음.
5. **지적:**
   - 번호: V-6 → **V-7로 이어짐**. 서버 동작은 해소, 시험 안정성은 미해소.
   - 번호: V-7
     - 위치: `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`(1 MiB 단계), design 2절 크기 한도
     - 위반 기준: 30-verification 7.1(검증 결과 불안정).
     - 근거: 상대가 보내는 중에 문이 닫으면 TCP 재설정으로 오류 프레임뿐 아니라 닫기 프레임도 버려질 수 있다. 그래서 앱 쪽에서는 1006을 본다. 2차 보완 설계가 이 경우를 빠뜨렸다.
     - 원인 분류: **설계 오류**(검토자 책임). 앱 쪽 관측으로 1009를 요구했다.
     - 등급: 차단
   - V-5: 기술 부채로 유지한다.
   - 증거 기준 보완: 20회 연속 전체 시험은 약 7% 확률의 간헐 실패를 놓칠 수 있다(검출 확률 약 77%). 그래서 완료 조건에 집중 반복을 더한다.
6. **기획설계 처리:** design 2절 크기 한도 3판 보완을 마쳤다.
   - 앱이 볼 수 있는 결과는 셋이다: `error(too_large)`, 1009, 1006 중 하나.
   - 문이 보장하는 것은 "1009 닫기 시도 + 계속 동작"이며, 문 쪽에서 검증한다.
   - 앱은 보내기 전에 크기를 검사한다(TASK-05 참고).
   - 요구는 바꾸지 않았다.
7. **미검증 범위:** 1차 7항과 같다.
8. **완료 조건:**
   - (1) 1 MiB 단계의 앱 쪽 기대를 바꾼다. TEXT면 `too_large`, 닫기면 코드가 {1009, 1006} 중 하나여야 한다.
   - (2) 서버 쪽 결정적 검증을 더한다. 문 쪽 웹소켓의 닫기 코드가 1009임을 확인한다(예: `BoundedWebSocket.close` 호출 기록이나 서버 측 `close_code`). 다른 연결과 게이트웨이가 계속 동작하고 새 연결의 roster가 응답하는지도 유지해서 확인한다.
   - (3) `-k bad_frames` 집중 실행 200회 실패 0과 전체 시험 20회 연속 종료 0을 로그로 남긴다.
9. **현재 명세 반영 요청:** 해당 없음.

## 검증 판정: HEJO-FOUNDATION TASK-02 / 보완 3 재검토 (4차)

1. **검토 대상:** 구현 커밋 `c6701afc0a8573e1b7caba2cf025f8114b100835`(기준 `a1825cc`). 같은 구간에 UI 시안 커밋 `72683e4`가 함께 있다(기획 담당 산출물). 구현 변경은 `gate/tests/test_boundaries.py`, `impl-report.md` 두 파일이다.
2. **판정: 완료(TASK-02).**
3. **설계 적합성(4.2): 적합.**
   - 1 MiB 단계에서 앱 쪽 기대를 바꿨다. TEXT면 `too_large`, 닫기면 {1009, 1006}이다.
   - 서버 쪽 검증을 더했다. 해당 연결의 `BoundedWebSocket.close`가 code=1009로 호출됐는지 확인한다. 원래 메서드를 그대로 실행하는 감시라 동작은 바꾸지 않는다.
   - 위 두 가지는 design 2절 3판과 맞는다.
   - 감시 기록은 `close` 시작 시점에 남는다. 그래서 오류 프레임·닫기 프레임·끊김 중 어느 것을 앱이 보든 그 전에 기록이 끝나 있고, 순서 경쟁이 없다.
   - 64 KiB 단계, 연결 유지, 새 연결 roster 확인은 그대로다. 제품 코드·스키마·수락 명세는 바뀌지 않았다(`git diff a1825cc c6701af -- gate schemas tests`에 이 시험 파일만 있음).
4. **직접 확인한 것:**
   - 구현 담당 로그 `.build/task02-r3-repeat.log`·`task02-r3-results.json`: 220회 모두 종료 0이다. 집중 실행 200회는 각 1 passed, 전체 시험 20회는 각 43 passed.
   - 검토자 독립 실행(`HEJO_TEAM_KIT_LIB` 지정, 임시 홈): 집중 실행(`-k bad_frames`) **100회 실패 0**, 전체 시험 **10회 실패 0**(`.build/task02-r3-review.log`).
     - 보완 전 집중 실행 실패율은 4/60이었다. 그 비율이 그대로라면 100회 실패 0이 우연히 나올 확률은 약 0.1%다.
   - 증거 수준: **2 확인**.
5. **지적 처분:**
   - V-1~V-4, V-6, V-7: 해소.
   - V-5(기록장 전체 메모리 적재·선형 탐색): 기술 부채로 유지한다. 보존·색인 후속 과제다.
6. **미검증 범위와 남은 위험:**
   - 실제 게이트웨이(수준 3)와 실기기(수준 4)는 TASK-03a·09에서 다룬다.
   - 필수 개인값 검사기는 TASK-07에서 생성한다. 이번 변경 파일은 보조 패턴 검사만 거쳤다.
   - 보조 프로필 배달은 TASK-03a에서 다룬다.
7. **현재 명세 반영:** HEJO-FOUNDATION 전체 완료 때 한 번에 반영한다.
8. **계획 변경(같은 날, 사용자 지시):** 앱 열기·닫기를 ddots 펫 구조로 한다(REQ-HF-16, 4판 보완, plan-review 참조). TASK-02에는 영향이 없다. TASK-05 인계 전에 재검증한다.

## 검증 판정: HEJO-FOUNDATION TASK-03a / 보조 프로필 배달 탐침 (5차)

1. **검토 대상:** 구현 커밋 `77e6c7eea7191a631ad9eb5c084f57c1e37aa048`(기준 `65a7d44`). 같은 구간에 계획 커밋 `65d1a35`가 있다.
   - 변경 파일: `gate/probes/{__init__,candidates,run}.py`, `gate/probes/README.md`, `impl-report.md`.
2. **판정: 완료(TASK-03a 탐침).** 결과는 **A 성공, B 차단**이다.
3. **설계 적합성(4.2): 적합.**
   - 탐침 범위·금지 범위를 지켰다. 본 모듈 import·변경 없음, 운영·본체·비밀 파일 접근 없음.
   - 탐침에만 쓰는 등록 값(`cron_deliver_env_var`, `parse_target_ref_fn`, `HEJO_ALLOWED_USERS`)이 있다. 본 플러그인에는 채택하지 않았다.
   - TASK-03b에서 A를 승격할 때 다음 두 가지는 설계 7절에 맞춰 다시 정한다.
     - 허용 사용자: config 브리지를 쓰고 .env는 쓰지 않는다.
     - 예약 대상 키: 새로 정한다.
4. **직접 확인한 것:**
   - A·B 최종 로그의 `PROBE_RESULT`와 `GATEWAY_EXIT clean`.
     - A: 리스너 1개. 직접 글과 예약 글이 모두 `employee=alpha`로 기록장 JSONL과 클라이언트 수신에서 일치했다. 단독 발신 호출은 0회.
     - B: `send_message`가 "hejo not configured"로 차단됐다.
   - Hermes 소스 `ebb026e`에서 B의 차단 지점을 확인했다.
     - `tools/send_message_tool.py:319-323`: 꺼진 설정을 미구성으로 처리한다.
     - `cron/scheduler_delivery.py:1407-1408`: 설정 블록이 있는데 꺼져 있으면 배달을 거부한다.
     - 같은 파일 바로 위: 블록이 없으면 켜진 것으로 본다. 그러면 보조 hejo가 켜져 B 구성이 성립하지 않는다(구현 담당 B run1 기록과 일치).
   - 회귀: `.build/task03a-regression.log` 43 passed.
   - 증거 수준: **3 확인**(임시 홈 실제 게이트웨이). 실제 Slack·모델·시간 트리거는 미검증이다.
5. **결론(design 4.1 판정 기준 대입):**
   - A는 채택 조건을 충족한다. 보조 프로필 `deliver=hejo`가 그 직원 스레드에 도착했고, 포트·중복 자격 검사를 통과했다.
   - B는 Hermes 본체의 배달 전 설정 검사 때문에 성립하지 않는다. 본체는 고치지 않는다는 제약이 있다.
   - 따라서 **A를 권고**한다. A는 각 보조 프로필 설정에 hejo를 켜는 운영 설정 변경을 포함하므로 **사용자 승인 대기**다.
6. **승인 뒤 개정할 것:** spec REQ-HF-01·10 AC, AT-HF-02·22, design 4.1·7절, tasks의 TASK-03b·07.
   - 설치 도우미는 보조 프로필에도 켬 블록을 쓰고, 영수증에 넣는다.
   - TASK-03b에서 전달자는 `send` 외에 `edit_message`·작성 중·버튼·첨부까지 전달하도록 승격한다.
   - 탐침 코드는 제거한다.

## 검증 판정: HEJO-FOUNDATION TASK-03b / 착수 보류 보고 (6차)

1. **검토 대상:** 커밋 `47b8d9a86a6c61bb2b48a7aef844a6e4ce4762ef`(기준 `dae1eed`). 변경 파일은 `impl-report.md` 하나다.
2. **판정: 미완료(TASK-03b 미착수).** 구현 담당의 보류는 **정당**하다(20-implementation 2절 중단 규칙).
3. **설계 적합성(4.2):** 설계 누락 2건을 확인했다. 둘 다 계획 담당 책임이다.
   - **T03B-01:** design 2.2의 POST 표는 "응답 전에 기록장 메타 등록"을 요구한다. 그런데 3절은 기록장 행을 `message·edit·delete·state`로 한정한다. 업로드 시점에는 붙일 글이 없어 두 규칙이 서로 맞지 않는다.
     - 직접 확인: `gate/journal.py:12`의 RECORD_TYPES, design 85·93-98줄.
   - **T03B-02:** 사진 원본 칸이 어디에도 정의되지 않았다.
     - design 51·87줄에는 URL만 있다.
     - team-kit `team_registry.roster()` 반환값에도 사진 항목이 없다.
4. **직접 확인한 것:**
   - `.build/task03b-preflight.log`: 진단용 등록 행은 스키마상 무효이고, 복구하면 0행이 된다.
   - 제품 코드·스키마·수락 명세는 바뀌지 않았다(`git diff dae1eed 47b8d9a --stat`에 impl-report만 있음).
   - 증거 수준은 1이다(진단).
5. **설계 보완(6판, 이 검토 커밋):**
   - **T03B-01 결정:** 업로드 파일은 먼저 **대기 칸**(`files/.pending/<직원>/<id>/`)에 둔다.
     - 소유 등록은 그 첨부가 달린 사장·직원 `message` 행의 메타로만 한다. 업로드만을 위한 별도 행이나 가짜 글은 만들지 않는다.
     - 대기 중인 파일을 GET으로 요청하면 404다. 다른 직원 문맥의 id로 send하면 `unknown_file`이다.
     - 재시작 뒤에도 send할 수 있다. 24시간이 지난 대기 파일은 정리한다.
     - 기록장 쓰기에 실패하면 파일을 대기 칸으로 되돌린다.
     - 반영 위치: spec REQ-HF-07.AC-04, AT-HF-51.
   - **T03B-02 결정:** 1단계 근간에서는 `avatar`를 항상 null로 두고 `/v1/avatars`는 404를 돌려준다. 사진 원본은 후속 "직원 카드" 작업에서 정한다.
     - REQ-HF-04에 "사진은 항상 없음"을 명시했다.
     - TASK-03b의 "사진 경로"는 직원이 보내는 이미지 파일(`send_image_file`)을 가리키며, 이번 범위에 그대로 남는다.
6. **미완료 원인 분류:** 설계 누락이며 구현 결함은 아니다.
   - 완료 조건은 handoff의 TASK-03b 인계와 '보완 지시 4' 전체다.

## 검증 판정: HEJO-FOUNDATION TASK-03b / 문 확장 + 보조 프로필 전달자 (7차)

1. **검토 대상:** 구현 커밋 `537fd8d6c8b9a80a926c81e7502db3fa7b38b00f`(기준 `d544ad9`). 변경 18파일이며 `gate/probes/` 제거를 포함한다.
2. **판정: 부분 완료.** 기능과 새 수락 시험은 맞게 구현됐다. 그러나 전체 시험 묶음이 종료 1이다.
3. **설계 적합성(4.2):** 대체로 적합하다. 확인 결과는 다음과 같다.
   - **전달자(`gate/adapter.py`):**
     - 보낼 때 모듈 수준 `_primary`를 조회한다.
     - 허브가 없으면 `hejo_primary_unavailable`를 반환한다.
     - 직원은 `_owner_profile`로 고정한다(호출자 `hermes_profile`보다 우선).
     - 보조 어댑터는 journal·files·auth·server를 만들지 않는다.
     - design 4.1 보강 1~3항과 맞는다.
   - **첨부(`gate/files.py`):**
     - 대기 칸 저장은 쓰기 → fsync → `os.replace` 순서다.
     - `promote`·`rollback`은 이름 바꾸기와 디렉터리 fsync를 한다.
     - 등록은 message 행의 `_meta.files`로만 한다.
     - GET은 기록장 등록과 경로 대조로 처리한다.
     - 경로 검사는 상위 이동(`..`)·심볼릭 링크·홈 밖을 막는다.
     - 24시간이 지난 대기 항목과 미등록 항목을 정리한다.
     - 스키마 변경은 `unknown_file` 코드 추가로 한정된다.
     - design 2.2 "첨부 등록 시점" 1~4항과 맞는다.
   - **기본 버튼:** 누른 사람의 권한을 검사한 뒤 해석 함수를 호출한다. 표식이 없으면 글자로 대체한다.
   - **V-8(비차단):** 전달된 `edit_message`가 대상 `message_id`가 그 직원의 글인지 확인하지 않는다. `set_reply_state`는 확인한다. 직원 간 기록장 무결성을 위해 같은 검사를 넣는다.
4. **직접 확인한 것:**
   - 검토자 독립 실행(`gate/tests` + `tests/acceptance` 전체, `HEJO_TEAM_KIT_LIB` 지정, 임시 홈): **종료 1, 57 passed / 1 failed.** 실패는 `gate/tests/test_boundaries.py::test_secondary_with_independent_home_never_listens`(`assert not await second.connect()`)이다. 로그는 `.build/task03b-review.log`.
   - AT-HF-22 로그 `.build/task03b-at22.log`의 `ACCEPTANCE_RESULT`:
     - 리스너 1개, 배달 4건, 새 스레드 4개, 오프라인 재전송 2건, 직원 beta, 다른 연결 송신 0.
     - `GATEWAY_EXIT clean`.
     - 증거 수준 3(임시 홈 실제 게이트웨이).
   - 변형 시험 로그(소유·직원 고정·되돌림)는 구현 담당 보고와 같다.
5. **T03B-03 원인 분류: 설계 누락(검토자 책임).**
   - 5판에서 보조 어댑터 계약을 "비활성"에서 "전달자"로 바꿨다. 그때 AT-HF-02만 개정 대상으로 적고, 같은 옛 계약을 담은 구현 범위 시험은 개정 허가에 넣지 않았다.
   - 구현 담당이 기대값 변경을 거부하고 보고한 것은 지시에 맞다.
   - 이 시험의 원래 의도(보조는 다른 홈·빈 포트에서도 flock·bind를 하지 않는다)는 새 계약에서도 그대로 유효하다.
6. **완료 조건(보완 지시 5):**
   - (1) 위 시험을 새 계약으로 바꾼다. 기대는 `connect()`가 True이고 다음 셋을 확인한다.
     - 다른 홈에 `journal/.lock`·`devices.json`·`shared/hejo/files`가 생기지 않는다.
     - 새 LISTEN 소켓이 없다.
     - 모듈 허브가 기본 문 그대로다.
   - (2) V-8: 전달된 `edit_message`도 대상 글의 직원이 `_owner_profile`과 다르면 실패(`message_not_found`)로 끝낸다. 시험을 추가한다.
   - (3) 전체 묶음 종료 0 로그와 AT-HF-22 재실행 로그를 남긴다.

## 검증 판정: HEJO-FOUNDATION TASK-03b / 보완 5 재검토 (8차)

1. **검토 대상:** 구현 커밋 `820f23a05ac43863f997f1daa81c94c247388d88`(기준 `ab26bc5`). 변경 파일은 `gate/adapter.py`, `gate/tests/{test_boundaries,test_extensions}.py`, `impl-report.md` 네 개다.
2. **판정: 완료(TASK-03b).**
3. **설계 적합성(4.2): 적합.**
   - V-8: 전달된 `edit_message`가 기본 문을 호출하기 전에 대상 글의 `employee`와 `_owner_profile`을 대조한다. 다르면 `message_not_found`로 끝낸다.
   - T03B-03: 옛 시험을 허가된 범위에서 새 계약으로 바꿨다. 새 시험은 다음을 확인한다.
     - 연결 성공
     - 다른 홈에 journal·devices·files가 생기지 않음
     - LISTEN 소켓 집합이 그대로임
     - `_primary`가 그대로 유지됨
   - 다른 기존 시험의 기대값은 바뀌지 않았다(구현 담당 AST 비교 로그 `.build/task03b-r5-static.log`).
4. **직접 확인한 것:**
   - 검토자 독립 실행(`gate/tests` + `tests/acceptance`, `HEJO_TEAM_KIT_LIB` 지정, 임시 홈): **종료 0, 59 passed**(`.build/task03b-r5-review.log`).
   - AT-HF-22 재실행 로그 `.build/task03b-r5-at22.log`: 리스너 1, 배달 4, `GATEWAY_EXIT clean`.
   - 증거 수준: 2, AT-22는 3으로 확인했다.
5. **지적 처분:** T03B-01·02·03과 V-8을 해소했다. V-5는 기술 부채로 유지한다.
6. **미검증 범위:** 실제 Slack 병행 상태의 운영 게이트웨이, 실제 모델 차례, 예약 시간 트리거, 실기기는 TASK-09에서 확인한다. 필수 개인값 검사기는 TASK-07에서 만든다.

## 검증 판정: HEJO-FOUNDATION TASK-07 / 부분 구현·보류 보고 (9차)

1. **검토 대상:** 기준 `30fea35`의 커밋되지 않은 스테이징 변경 8파일(README, copy-review, impl-report, githooks/pre-commit, scripts/{scan_private.py, scan_private_allow.txt, test.sh}, tests/acceptance/test_private_scan.py).
2. **판정: 미완료.** 개인값 검사기·훅·`scripts/test.sh`·README와 AT-29·41·42·43 시험은 작성됐다. 설치 도우미와 AT-27·28·38·39·40은 아직 없다. 보류 2건은 정당하다(설계 누락).
3. **설계 적합성(4.2):**
   - 검사기는 운영 홈에서 두 파일만 열고 `O_NOFOLLOW`·심볼릭 링크 거부를 한다. 출력은 지문뿐이고 예외는 줄 지문 단위다. design 7절과 맞는다.
   - T03-01과 T07-02는 아래와 같이 결정했다.
4. **직접 확인한 것:**
   - 검사기가 막은 15건이 무엇인지 값을 출력하지 않고 확인했다. 금고 단어 하나가 **운영자 비공개 저장소의 이름**이었고, 이 이름이 공개 문서 6개 파일에 쓰여 있었다(AGENTS.md 3, ARCHITECTURE 1, brainstorm 2, design 5, handoff 3, copy-review 1).
   - 사장이 금고에 넣은 값이므로 **개인값이 맞다.** 검사기가 정상 동작해 계획 담당의 공개 문서 위반을 잡은 것이다.
5. **원인 분류와 처리:**
   - **T07-02 — 계획 문서 오류(검토자 책임):**
     - 이 검토 커밋에서 추적 문서의 저장소 이름을 `<운영 저장소>`·"운영 저장소"로 바꿨다.
     - 실제 경로는 추적하지 않는 `AGENTS.local.md`(.gitignore에 추가)에 두고, `CLAUDE.md`가 이를 불러온다.
     - 구현 담당이 스테이징한 `copy-review.md` 1건은 구현 담당이 같은 방식으로 고친다.
     - 지난 커밋 이력에 남은 이름은 3단계 공개 전 이력 검사·재작성 과제로 남긴다(ARCHITECTURE 7절 4항).
   - **T07-01 — 설계 누락:** `<HOME>/hejo/` 생성을 영수증보다 앞선 기록용 준비 단계로 정했다. 이 단계는 되돌리지 않는다. 실패 뒤에는 이 디렉터리와 `failed` 영수증만 남는다. design 7절과 AT-HF-39 기대값에 이 예외를 명시했다(7판).
6. **완료 조건(보완 지시 6):** 설치 도우미 전체, AT-27·28·38·39·40, 검사기 위반 0, 전체 시험·AT-22 통과.
