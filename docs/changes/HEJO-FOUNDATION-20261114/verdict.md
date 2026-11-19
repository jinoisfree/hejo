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

## 검증 판정: HEJO-FOUNDATION TASK-07 / 보완 6 재검토 (10차)

1. **검토 대상:** 구현 커밋 `b7212a9bf45e5e383d82bca8536c27faa943b399`(기준 `6a58e48`). 변경 10파일이며 `install/hejo-install`, `tests/acceptance/test_install.py`가 새로 들어왔다.
2. **판정: 완료(TASK-07).**
3. **설계 적합성(4.2): 적합.**
   - 프로필 목록은 Hermes의 이름 전용 API(`list_profile_names`·`get_profile_dir`)로만 읽는다. 기본 프로필에는 문 블록(`PRIMARY`)을, 보조 프로필에는 `{enabled: true, extra: {role: forwarder}}`를 쓴다(design 7절 3-1).
   - `hejo/`는 기록 부트스트랩으로 만들고, 영수증에는 `existed` 정보만 남긴다. `devices`·링크·설정은 대기(pending) 영수증 뒤에 바꾸고, 단계마다 `applied`로 갱신한다.
   - 실패하면 역순으로 되돌리고 종료 1. 제거 중 사장이 바꾼 값과 충돌하면 그 대상은 보존하고 종료 2. `--force`를 줄 때만 강제한다.
   - 설정 파일은 ruamel 왕복 + 원자 교체로 쓰고, 심볼릭 링크로 된 설정은 열지 않고 거부한다.
   - 비차단 참고: 영수증 `configs`에 각 `config.yaml`의 설치 전 원문 전체가 들어간다. Hermes 설정 파일에는 비밀값이 없고(비밀값은 `.env`), 영수증은 0600 권한이라 허용한다. 다만 사장이 `config.yaml`에 비밀을 직접 적은 경우에는 그 값이 복제된다. 이 점을 README에 한 줄 적도록 후속 TASK-09 점검표에 넣는다.
4. **직접 확인한 것:**
   - 검토자 독립 `bash scripts/test.sh`(`HEJO_PYTHON`·`HEJO_TEAM_KIT_LIB` 지정, 임시 홈): **종료 0, 80 passed**. 이어서 AT-HF-22 실제 게이트웨이가 리스너 1·배달 4·`GATEWAY_EXIT clean`이었고, 마지막에 "앱 시험 없음" 표시가 나왔다(`.build/task07-review.log`).
   - 검토자 `githooks/pre-commit`(개인값 검사): **종료 0, 위반 0**. 바이너리인 시안 PNG만 검사를 건너뛰었다(`.build/task07-review-scan.log`).
   - `test_install.py`가 AT-27·28·38·39(부트스트랩 예외 포함)·40(파일 열기 감사)을 다루는 것을 확인했다.
   - 증거 수준: 2 확인.
5. **지적 처분:** T07-01·02 해소. V-5와 과거 커밋 이력의 개인값 정리(3단계)는 유지한다.
6. **미검증 범위:** 운영 홈 실제 설치, 전원 중단·동시 설치 경쟁. 운영 설치는 TASK-09에서 한다.

## 검증 판정: HEJO-FOUNDATION TASK-05 / 앱 골격 + 펫 창 (11차)

1. **검토 대상:** 구현 커밋 `86bb82a038bc320ce09dbf7fce8abfca64d08e20`(기준 `77b2232`). 39파일이 바뀌었고 `app/`·`evidence/`가 새로 생겼다.
2. **판정: 완료(TASK-05, 자동 범위).** AT-HF-47의 수동 체크리스트(다른 앱 포커스 유지·genie 녹화·동작 줄이기·실제 다중 화면)는 미실행이다. 이 항목들은 TASK-09 실기기 점검에서 사장과 함께 한다.
3. **설계 적합성(4.2): 적합.**
   - `app/Sources`와 `app/Tests`에 `import SwiftUI`·Slack 참조가 0건이다(grep 확인).
   - `PetController`는 패널 하나를 쓴다(`.borderless`·`.nonactivatingPanel`, `.floating`, 모든 Space, `becomesKeyOnlyIfNeeded`). `ChatMorph.genieDuration` 타이머로 펼침·접힘을 한다. 동작 줄이기면 즉시 전환한다. 화면 변경과 끌기 중 대화 높이 유지도 ddots 구조 그대로다.
   - `PetPanel`은 펼쳐졌을 때만 키 창이 될 수 있고, 편집 가능한 글 칸을 눌렀을 때만 `makeKey`를 한다(포커스 비탈취). Esc를 누르면 접힌다.
   - 대화 자리는 연결 상태만 보여 주는 AppKit `NSView`다. TASK-06 범위는 구현하지 않았다.
   - `copy-review.md`에 펫 원본을 파일별로 기록했다. 원본 위치는 `<운영 저장소>` 표기만 쓴다.
   - 펫 그림은 LICENSE와 함께 들어왔다.
4. **직접 확인한 것:**
   - 검토자 독립 `bash scripts/test.sh`: **종료 0**(`.build/task05-review.log`).
     - gate 80 passed, AT-22 통과.
     - AT-HF-23 PASS(번들 ID·서명 검증).
     - AT-47 자동 부분·48 PASS.
     - AT-24 PASS(페어링·키체인·재시작 welcome, 빈칸·중복·페이지·ping).
     - AT-25 PASS(1·2·4·8초 백오프, 문 재시작 뒤 자동 복구).
     - FRAME_SIZE PASS(1009·too_large 표시, 1006 뒤 복구).
     - 시험용 키체인 항목 정리 확인.
   - 개인값 검사: 종료 0, 위반 0.
   - 자동 캡처(`evidence/HEJO-FOUNDATION/task05-automatic-open.png`): 펫과 빈 대화 자리, "펫으로 접기", "공항 연결 전" 표시를 확인했다.
   - 증거 수준: 2(문 대역 `network_fixture.py` + 실제 앱 바이너리).
5. **지적:** 없음. V-5와 과거 이력 개인값 정리는 기존 부채로 유지한다.
6. **넘기는 것:** AT-47 수동 4항목은 TASK-09 체크리스트로 넘긴다(`evidence/HEJO-FOUNDATION/TASK-05.md`).

## 검증 판정: HEJO-FOUNDATION TASK-06 / 대화 화면, 8판 기준 (12차)

1. **검토 대상:** 구현 커밋 `c5d25942194eebd5218ceeae1aa55a010d447ebe`(최초 기준 `91c2938`). 그 사이 계획 커밋(8판·방 단위 모델·시안 2~7판)이 함께 들어 있다. 구현 변경은 `app/`, `copy-review`, `impl-report`, `evidence`, README로 31파일이다.
2. **판정: 완료(TASK-06, 8판 기준의 자동 범위).**
   - AT-HF-26 수동 시각 동등성(ddots와 나란히 비교)은 TASK-09로 넘긴다.
   - 사용자가 대화 화면 방향을 다시 검토하는 중이다(시안 6·7판, 단체방 받는 사람 설계). 확정되면 9판에서 화면 배치를 다시 손볼 수 있다. 이번 결과의 모델·통신·첨부·버튼·방 단위 부품은 그대로 다시 쓴다.
3. **설계 적합성(4.2): 8판에 적합.**
   - 세 칸 화면을 지우고 ddots 배치(직원 탭 줄, 카드 펼침, 답글/새 글 전환, 알림 띠, 머리글)를 AppKit으로 옮겼다.
   - `import SwiftUI`는 0건이다.
   - 탭은 `Room`(direct) 단위로 다룬다. 통신 규격(employee·thread)은 바꾸지 않았다.
   - `copy-review.md`에 원본을 읽은 기록이 있다.
   - 확인 필요(AT-26 항목): 자동 캡처에서 직원 아바타가 파란 글자 타일로 그려진다. ddots 탭 타일과 색이 같은지는 나란히 비교할 때 확인한다.
4. **직접 확인한 것:**
   - 검토자 독립 `bash scripts/test.sh` 결과: **종료 0**(`.build/task06-review.log`).
     - gate 80 passed와 AT-22
     - 앱 AT-23·24·25·47·48·FRAME_SIZE
     - CONVERSATION_DDOTS_LAYOUT_PASS, CONVERSATION_MODEL_UI_PASS, CONVERSATION_NETWORK_PASS
     - CONVERSATION_HTTP_WS_PASS(업로드 2·클릭 1·보내기 5·내려받기 1·리디렉션 0)
     - 시험용 키체인 정리 OK
   - 개인값 검사: 종료 0, 위반 0.
   - 자동 캡처(`evidence/HEJO-FOUNDATION/task06-cards-automatic.png`): 탭 줄·펼친 카드·답글/새 글 전환·끊김 띠·펫을 확인했다.
   - 증거 수준: 2.
5. **지적:** 없음(차단 없음). V-5와 과거 이력 개인값 정리는 계속 부채로 남긴다.
6. **다음:** 사용자의 대화 화면 방향 결정을 기다린다. 결정이 나면 9판 개정과 TASK-06 보완을 진행한다. 그 밖에 남은 작업은 TASK-04·08·09다.

## 검증 판정: HEJO-FOUNDATION TASK-04 / team-kit hejo 답장 버튼 (13차)

1. **검토 대상:** hejo 보고 커밋 `f7d909123e7bf027f549b649d62daea491f30431`(기준 `b039368`). impl-report.md에 28줄을 추가했을 뿐이다. 운영 저장소 HEAD는 `36c5aee1` 그대로이고 새 커밋은 없다.
2. **판정: 미완료(착수 전 보류). 원인 분류: 외부 선행 조건.** 실행 담당의 결함이 아니다.
   - 운영 저장소에 다른 작업(DDOTS-DROP-MODEL-20261113)의 문서 2개가 미커밋 상태로 남아 있다.
     - `impl-report.md`: 20:46 수정
     - `verdict.md`: 21:31 수정
   - 두 파일은 TASK-04 착수(23:10) 전에 수정됐다.
   - 플러그인이 수집한 증거로도 실행 전후 작업 트리는 같다. 실행 담당은 이 파일들을 건드리지 않았다.
   - 인계 (0)항대로 멈춘 것은 올바르다.
3. **설계 적합성(4.2): 해당 없음.** 제품 변경이 없다.
4. **직접 확인한 것:**
   - 두 저장소의 `git status`와 `git log`
   - 운영 저장소 두 파일의 수정 시각
   - hejo 커밋의 변경 통계: 보고서 1개 파일
   - 운영 저장소 사용 현황: 다른 작업의 worktree·stash가 여럿 있다. 공용 main을 여러 작업이 함께 쓰고 있다.
   - 증거 수준: 2에 도달하지 못했다. 제품 시험과 airport-check은 실행되지 않았다.
5. **지적:** 없음.
6. **다음:**
   - DDOTS-DROP-MODEL 작업이 문서를 커밋해 운영 저장소 main이 깨끗해지면 TASK-04를 같은 인계로 다시 시작한다.
   - 재개할 때 (0)항 전체를 다시 확인한다: 원본 team-kit 변경, 처리 중 작업, sync 토큰 경고.
   - (0)항을 완화할지(다른 작업의 문서만 남아 있으면 진행 허용 등)는 사용자가 결정한다.

## 검증 판정: HEJO-FOUNDATION TASK-04 재개 / team-kit hejo 답장 버튼 (14차)

1. **검토 대상**
   - 실행 원본 `~/.hermes/plugin-store/team-kit`의 미커밋 변경 3개 파일. 해시는 보고서와 일치한다.
     - `lib/hermes_reply/plugin.py` (84e30288…)
     - `lib/hermes_reply/reply_buttons.py` (9940cb80…)
     - `tests/test_reply_hejo.py` (2cd76fc4…)
   - 변경 전 원본(`.build/task04-resume/original`)은 운영 저장소 사본과 같다.
   - hejo 보고 커밋은 `a41ba00`이다. 운영 저장소 HEAD는 `36c5aee1` 그대로이고, 남은 문서 2개는 그대로 보존되어 있다.
2. **판정: 부분 완료.**
   - 구현과 새 시험은 동작한다.
   - 전체 시험 합격·운영 저장소 커밋이 아직 없고, 설계 적합성 지적 1건(F3)이 남아 있다.
   - 원인 분류:
     - F1·F2는 기존 결함이다. 이번 변경과 무관하다.
     - F3·F4는 이번 구현의 보완 사항이다.
3. **설계 적합성(4.2): 대체로 적합, 1건 보완 필요.**
   - 적합한 부분:
     - `controls()`는 `reply_buttons`로 옮겼고, Slack 쪽은 같은 함수를 참조만 한다.
     - hejo는 `register_platform_handler('hejo', …)`와 공개 메서드(send·edit_message·set_reply_state·register_click_handler·handle_message)만 사용한다. 문 내부 import는 없다.
     - 클릭은 answered로 기록한 뒤 False를 반환한다. 최종 답장에서 closed가 된다.
     - Slack 변경 전후 시험 결과가 같다(214→214).
   - **F3 (보완 필요):** 보조 프로필 전달자 경로의 버튼 처리가 시험되지 않았다. 이 경로가 실제 직원 대부분이 쓰는 경로다(design 4.1 A).
     - 팩토리가 프로필마다 어댑터를 감싸면, 전달자의 `send`가 대표 어댑터의 **감싼** `send`를 다시 호출한다. 그래서 감싸기가 두 번 적용된다.
     - 대표 쪽 감싸기는 표식이 이미 빠진 글을 받는다. "버튼 없음"으로 보고 `close_answered`를 실행한다.
     - 그 결과, 같은 스레드에서 직원이 버튼 달린 새 질문만 보내도 answered 글이 closed로 바뀐다. 대표 프로필 직원은 그렇지 않다. **프로필에 따라 동작이 다르다.**
4. **직접 확인한 것**
   - 원본에서 `pytest tests/test_reply_hejo.py`: 종료 0, 8 passed.
   - `tests/test_org_review.py`: 종료 1, 8 failed·83 passed. 실패를 재현했다.
     - 원인: `seed()`가 날짜를 `2026-10-14`로 고정한다. `prune()`은 30일보다 오래된 기록을 지운다.
     - 오늘(2026-11-14)부터 터지는 날짜 시한폭탄이다.
   - 앱 시험(`app/scripts/test.sh`, 의존 경로 지정) 14회 실행 결과:
     - 13회 통과, 1회 `AT47 closing ends folded` 실패.
     - 원인: 0.30초 변형 뒤 고정 0.4초 대기 → 부하가 있을 때 가끔 실패한다.
     - 로그: `.build/task04-review-app-*.log`
   - 코드 검토: `install_hejo`, `clicked_context` 인수 추가, 공유 `controls`.
5. **지적**
   - **F1 (기존 결함, 차단):** `tests/test_org_review.py`의 날짜 고정. 시험만 고친다. 정책 코드(`org_review.py`)는 바꾸지 않는다.
   - **F2 (기존 결함, 차단):** `app/Tests/TestMain.swift:92`의 고정 대기. 접힘이 끝날 때까지 기다리는 방식(최대 2초)으로 바꾼다.
   - **F3 (보완, 차단):** 위 3항. 버튼 처리가 **경로마다 정확히 한 번**만 일어나야 한다. 전달자 경로 시험도 추가한다.
   - **F4 (보완, 낮음):** `message_threads`·`working`이 상한 없이 커진다. 닫히면 지우고, 보관 개수에 상한을 둔다.
6. **다음:** 보완 지시 8(handoff.md)대로 수정 → 전체 시험 종료 0 → airport-check → `./sync` 모으기 → 자기 파일만 커밋.

## 검증 판정: HEJO-FOUNDATION TASK-04 보완 8 (15차)

1. **검토 대상**
   - 실행 원본 team-kit의 4개 파일(운영 사본과 해시 일치):
     - `plugin.py`
     - `reply_buttons.py`
     - `tests/test_reply_hejo.py` (17개 시험)
     - `tests/test_org_review.py`
   - hejo 저장소의 미커밋 2개 파일: `app/Tests/TestMain.swift`, `impl-report.md`
   - 운영 저장소 HEAD는 `36c5aee1`이며 새 커밋은 없다.
2. **판정: 부분 완료.** 구현과 검증은 끝났고 커밋만 남았다.
   - 원인은 **계획 공백**이다. 보완 인계(재개) 4항에서 "무관한 사본 변화가 보이면 커밋하지 말라"고 지시했다. 그런데 `./sync`가 직원의 기억 파일(`MEMORY.md`) 변화까지 늘 함께 모은다는 점을 계획에 반영하지 않았다.
   - 실행 담당은 그 지시대로 멈췄으므로 결함이 아니다.
3. **설계 적합성(4.2): 적합.** 14차 지적 4건이 모두 해소됐다.
   - **F3:** 보조 프로필 어댑터는 공개 속성 `forwarder`로 구분해 감싸지 않는다. 버튼 처리는 대표 어댑터에서 한 번만 한다. 보조 프로필 직원 시나리오 시험을 추가했다.
   - **F4:** 추적 목록은 최근 2048개로 제한한다. closed가 되거나 실패하면 목록에서 지운다. 시험 코드를 일부러 망가뜨려 보는 변형 시험에서도 이 두 보완이 각각 검출됐다.
   - **F1:** 시험의 보고 날짜를 KST 상대 날짜로 바꿨다. 정책 코드(`org_review.py`)는 바꾸지 않았다.
   - **F2:** AT47의 고정 대기를 최대 2초 조건 폴링으로 바꿨다. 제품 앱 코드는 바꾸지 않았다.
   - 문 내부 import는 없고 Slack 시험은 214개 그대로다.
4. **직접 확인한 것**
   - 원본에서 `test_reply_hejo.py`와 `test_org_review.py`를 함께 실행: 종료 0, 108 passed.
   - 로그 직접 확인:
     - team-kit 전체: 4801 passed, 3 skipped (`.build/task04-r8-team-final.log`)
     - hejo `scripts/test.sh` 통과, 앱 시험 20회 연속 통과(실행 담당 로그)
   - `TestMain.swift` 차이를 읽었다. 시간 안에 조건이 맞지 않으면 기존 단언이 그대로 실패한다.
   - 운영 저장소 상태:
     - 이번 작업 4개 파일
     - DDOTS 문서 2개
     - `hermes/profiles/<직원>/memories/MEMORY.md` 1개. 실행 중인 직원 기억이 바뀐 것으로, 매일 04:30 자동 기록 대상이다.
   - 증거 수준: 2
5. **지적:** 없음(코드). 계획 쪽 보완은 보완 지시 9에 적는다.
6. **다음:** 보완 지시 9대로 자기 파일만 커밋한 뒤 푸시 대상을 보고한다.

## 검증 판정: HEJO-FOUNDATION TASK-04 커밋 마무리 (16차)

1. **검토 대상**
   - 운영 저장소 커밋 `392a2afb46338b86ace632b185e63941114dcc77`: 부모는 `36c5aee1` = `origin/main`이다.
   - hejo 커밋 `846bd7c96dae456248b3f3aeabb2131c91dcf01d`
2. **판정: 완료(TASK-04).** 푸시는 사용자 승인을 기다린다.
3. **설계 적합성(4.2): 적합.** 15차 판정에서 바뀐 코드가 없다.
4. **직접 확인한 것**
   - `git show --stat` 결과 정확히 4개 파일이다.
     - `plugin.py`
     - `reply_buttons.py`
     - `test_org_review.py`
     - `test_reply_hejo.py`
   - 각 파일에서 실행 원본의 SHA-256과 커밋된 내용의 SHA-256이 같다.
   - `git status`: DDOTS 문서 2개와 직원 기억 파일 1개는 그대로 ` M` 상태다. 손대지 않았다.
   - hejo 커밋 범위: `TestMain.swift`와 `impl-report.md`, 2개 파일이다.
   - 실행 중인 게이트웨이는 재시작하지 않았다. 따라서 새 코드는 아직 로드되지 않았다.
     - 실제 Slack·hejo 버튼 동작은 TASK-09에서 재시작한 뒤 확인한다.
   - 증거 수준: 2
5. **지적:** 없음.
6. **다음**
   - 운영 저장소 푸시는 사용자 승인으로 진행한다. fast-forward로 반영할 수 있다.
   - hejo는 원격이 없다.
   - 남은 작업: TASK-08(운영 config `cache_ttl: auto`, 사장 확인 필요), TASK-09(운영 설치·실기기 확인, 사장과 함께)

## 검증 판정: HEJO-FOUNDATION TASK-08·10·11 / 캐시 auto·로고·아일랜드 1단계 (17차)

1. **검토 대상**
   - 운영 저장소 `855149a4d1713804fec77bb2c8fd4ff370a6b04f` (TASK-08): 부모 `392a2afb`, 설정 사본 6개만 바뀌었다.
   - hejo `9f4ae93`(TASK-08 보고), `cc12820`(TASK-10), `e5208370376aca97f24ef8b05d5a5cb81f01e091`(TASK-11)
2. **판정: 완료(TASK-08·10·11).** TASK-12는 아직 실행되지 않아 이번 판정 대상이 아니다. 운영 푸시는 사용자 승인을 기다린다.
3. **설계 적합성(4.2): 적합.**
   - 아일랜드는 표시용 상태만 가진다(`IslandModel`). 원본은 그대로 기존 자리에 있다: 글·읽음·초안은 모델·컨트롤러, 연결 상태는 `GateClient.status`.
   - 새 원본, 새 wire 계약, SwiftUI는 없다.
   - 연결 끊김 띠와 답 대기 noticeBar는 지우고 알약으로 옮겼다. 다른 notice 용도는 그대로다.
   - 범위 밖 기능(알약 답 버튼, 할 일 칸, D-day)은 들어가지 않았다.
4. **직접 확인한 것**
   - **TASK-08 운영 설정:** 루트와 5개 프로필의 `config.yaml` 모두 `cache_ttl: auto`다(grep). 운영 커밋 파일 목록은 정확히 6개다. 이 값은 재시작 뒤에 적용된다. 그 확인은 TASK-09에서 한다.
   - **TASK-10:** `HEJO.`에서 H만 systemBlue이고 14 semibold, 10pt 버전 줄이 있다. `Info.plist`의 `CFBundleShortVersionString`은 0.1.0이다.
     - 자동 캡처에는 버전이 없다. 시험 실행 파일이 번들이 아니기 때문이다. 실제 앱에서는 TASK-09에서 눈으로 확인한다.
   - **TASK-11 코드:**
     - 칸은 늘 문제→사장→직원 순서다.
     - A·U와 빨간 점을 그린다. 4초/3초 늘어남은 순서 큐로 처리하고, 문제 칸이 떠 있는 동안은 큐가 멈춘다.
     - 답이 이미 된 질문은 큐에서 지운다.
     - 클릭하면 가장 오래된 asked로 가고, 마우스를 올리면 가장 최근 asked를 보여 준다(AC-05와 같다).
     - 반짝임: 글자 마스크를 씌운 `CAGradientLayer`의 위치만 1.6초 주기로 움직인다.
     - 동작 줄이기면 0.45 흐린 고정 글자다.
     - `.tooLarge`도 문제 칸에 보인다.
   - 시험 소스 해시: 실행 담당이 10회 반복할 때의 해시와 현재 HEAD 소스가 전부 같다(불일치 0).
   - **내가 다시 돌린 시험:** 환경을 지정하고 `bash scripts/test.sh` → 종료 0.
     - gate 80 passed
     - AT-HF-52, 53(모델·UI), 54, 55(모델·네트워크), 56 자동 PASS
     - HTTP/WS 대역 sends 6
     - 로그: `.build/review17-hejo.log`
   - 게이트웨이 Python으로 `scripts/scan_private.py` → 종료 0. `import SwiftUI` 0건.
   - 자동 캡처 `task11-working-automatic.png`를 직접 봤다. 로고 옆 알약에 `● 2 · 5 | B 일하는 중 · 2분`이 있고, 높이는 한 줄이다.
   - 증거 수준: TASK-08은 3(운영 원본 반영), TASK-10·11은 2.
5. **지적**
   - **T11-01 (낮음, 기존 위험):** AT47 펼침 완료 단언이 가끔 실패한다.
     - 기존 `PetController.screensChanged()`가 진행 값을 완료로 바꾸지 않는 경로가 있다. 실행 담당이 결정적으로 재현했다.
     - 자연 발생한 실패의 원인으로 확정되지는 않았다. 최종본은 10/10, 내 실행도 통과했다.
     - TASK-09 다중 화면 수동 확인에 넘긴다. 따로 고칠 필요가 생기면 별도 작업으로 한다.
   - **관찰 (TASK-09 수동):** 밝은 모드에서 흰 빛 띠가 잘 보이는지 실기기에서 확인한다.
6. **다음**
   - TASK-12(대화 안 작성 중 표시, 보완 지시 11)를 실행한다.
   - 운영 푸시: `origin/main` ← `855149a4…`(`392a2afb` 포함). 현재 원격은 `36c5aee1`이고 아직 포함되지 않았다(읽기 확인).

## 검증 판정: HEJO-FOUNDATION TASK-12 / 대화 안 작성 중 표시 (18차, 자체 점검)

1. **검토 대상:** hejo `80ade0839949a8e0bc603a9fed0f15d9b60fb33e`.
   - 사용자 지시("남은 순서도 너가 모두 직접 해라")에 따라 계획 담당이 직접 구현했다.
   - 같은 모델이 구현하고 검증했으므로 조건은 **자체 점검**이다.
2. **판정: 완료(TASK-12).** 제품 전체의 남은 일은 TASK-09(사장과 운영 설치·실기기) 하나다.
3. **설계 적합성(4.2): 적합.**
   - 반짝임은 공용 부품 하나(`ShimmerLayer`)를 아일랜드와 대화 줄이 함께 쓴다. design 6절 그대로다.
   - 경과 초의 원본은 모델의 `typingSince` 하나다.
   - 커서는 글 배치 밖의 하위 보기라서 Layout·`streamHeights`에 들어가지 않는다.
   - 새 wire·저장 형식·SwiftUI가 없고, gate·명세·시안은 바꾸지 않았다.
   - 남은 불일치: 아일랜드 직원 칸의 경과 분은 여전히 `IslandModel.workingSince`(직원 단위)로 센다. 대화 줄은 스레드 단위 `typingSince`로 센다. 분/초 단위와 직원/스레드 범위가 달라서 1단계에서는 그대로 둔다(낮음).
4. **직접 확인한 것**
   - 10회 연속 `bash app/scripts/test.sh`: 모두 0이고, 회차마다 AT-HF-52~57 PASS.
   - 전체 `bash scripts/test.sh`: 0이다(gate 80, AT-HF-57).
   - `scan_private`·pre-commit: 각각 0(게이트웨이 Python). SwiftUI 0, diff --check 0.
   - 커밋한 소스가 시험한 소스 해시와 같다.
   - 자동 캡처 두 장을 직접 봤다.
     - 기다림 "작성 중 12초"에 점이 없다.
     - 흘러나옴에서는 마지막 글자 오른쪽에 파란 커서가 있다.
   - 증거 수준: 2
5. **지적**
   - 위 경과 기준 불일치(낮음, 후속).
   - hejo에는 중지 버튼이 없다. REQ-HF-19의 "중지 버튼 유지"는 대상이 없어 해당 없음이다. ddots와 비교하는 일은 AT-26 TASK-09에서 확인한다.
6. **다음:** TASK-09는 사장과 함께 한다. 실행 순서는 handoff.md의 "TASK-09 실행 순서"에 있다.
   - 운영 푸시(`origin/main` ← `855149a4`)는 사용자 승인을 기다린다.

### 18차 보충: 실행 담당의 TASK-12 동시 착수 (2026-11-15)

- **무슨 일이 있었나:** 이전 재지시가 늦게 전달되어 실행 담당이 TASK-12를 시작했다. 그 사이 계획 담당이 직접 구현한 변경을 발견하고 스스로 멈췄다. 자기가 만든 `ShimmerText.swift`(참조 없음)는 지웠다. 커밋·시험·운영 변경은 없다.
- **확인:** HEAD는 `c4a858f`, 작업 트리는 깨끗하다. `ShimmerText.swift`는 없다. 앱 소스·시험 해시는 `.build/task12-source-hashes.txt`(시험한 소스)와 전부 같다.
- **판정:** 18차 판정(TASK-12 완료, 자체 점검)을 바꾸지 않는다. 실행 담당 쪽에서 반영할 결과는 없다.

## 검증 판정: HEJO-FOUNDATION TASK-09 / 운영 설치·실물 (19차, 자체 점검)

1. **검토 대상**
   - hejo 설치기 수정 `a30c28b`
   - 운영 저장소 `8fad28e65ada45da578fa8ea1fe3af73723fa6c7`(hejo 설정 6개)
   - 운영 게이트웨이 재시작 2회와 루프백 실물 시험
   - 사장 지시로 계획 담당이 직접 수행했으므로 조건은 **자체 점검**이다.
2. **판정: 부분 완료(TASK-09).** 공항 쪽은 끝났다: 설치, 재시작, 실제 직원 대화·첨부·전달자·다시 받기, 되돌림 증거. 노트북(Tailscale) 연결과 눈 확인 항목(AT-26·47·56·57, 버튼·예약 보고)은 사장이 있어야 한다.
   - **원인 분류: 사용자 참여 필요.** 결함이나 계획 누락 때문이 아니다.
3. **설계 적합성(4.2): 적합.**
   - 설정은 design 7절 키만 더했다.
   - 설치기 수정은 "주석·순서 보존" 원칙을 바이트 보존으로 강화했다. 운영 reader 기준 검증이므로 design 7절 의도와 맞다.
   - 영수증·되돌림 구조는 그대로다. 본체·비밀 파일·ddots는 손대지 않았다.
4. **직접 확인한 것** (상세는 impl-report "TASK-09 2단계 이후"와 `evidence/HEJO-FOUNDATION/TASK-09.md`)
   - 운영 diff는 hejo 줄뿐이고 사본과 일치한다.
   - 13 플랫폼, 리스너 1개다.
   - 실물 답 6회, 첨부 왕복, 401 차단을 확인했다.
   - 다시 받기가 순서대로 왔고, 시험 기기는 모두 취소했다.
   - 설치 전 사본 기준 설치 = 운영과 바이트 일치, 제거 = 원본과 바이트 일치.
   - 증거 수준: 3(운영 원본 실물). 노트북 4는 미도달이다.
5. **지적**
   - **(관찰)** 직원별 첫 hejo 대화에 Hermes 홈 채널 안내가 붙는다. 홈 채널을 바꿀지는 사장이 정한다.
   - **(남은 일)** 노트북에서 붙으려면 listen에 Tailscale 주소를 더하고 재시작해야 한다. 네트워크 노출 변경이라 사장이 있을 때 한다.
6. **다음:** 사장이 노트북으로 TASK-09.md 체크리스트를 진행한다. 운영 푸시는 `origin/main` ← `8fad28e6`(`392a2afb`·`855149a4` 포함)이며 사용자 승인을 기다린다.

## 검증 판정: HEJO-FOUNDATION TASK-13 / 자동 연결 (20차, 자체 점검)

1. **검토 대상:** hejo `b2d3b8ba96ea0c34c0ddbca90a25e8c9c4d06ce5`. 계획 담당이 직접 구현했으므로 조건은 자체 점검이다.
2. **판정: 완료(공항 Mac 실물까지).** 노트북 Tailscale 실물은 TASK-09 남은 항목에 넣는다.
3. **설계 적합성(4.2): 적합.**
   - 인증 원본은 그대로 문의 `AuthStore` 하나다. 로컬 코드는 `pairing.json`의 별도 칸이라 일반 코드·잠금과 섞이지 않는다.
   - 규격 변경은 hello 변형 추가와 거부 이유 추가뿐이다. 하위 호환이다.
   - 신뢰 경계를 design 6절에 적었다: 공항 Mac은 같은 사용자, 다른 Mac은 같은 Tailscale 사용자.
   - SwiftUI 0, 비밀 파일 접근 0. 앱은 `local-pair.json`만 읽는다.
4. **직접 확인한 것**
   - 문 시험: 로컬 코드 0600·일회용·교체·Tailscale 주소 거부. `auto`는 같은 사용자만 통과하고, 루프백 `auto`는 tailscale을 부르지 않고 거부한다. whois가 누락되면 거부한다.
   - 앱 시험: 파일 파싱, 파일 우선, 후보 순서, 없으면 찾지 못함.
   - 운영: 재시작 뒤 맥미니 앱이 입력 없이 페어링됐다.
5. **지적(낮음)**
   - Tailscale 신뢰는 "사장 계정에 로그인된 모든 기기"다. 노트북을 잃어버리면 출입증 취소와 함께 tailnet에서 그 기기를 빼야 한다(design에 적음).
   - 게이트웨이 시작 때 Tailscale이 꺼져 있으면 Tailscale 주소를 묶지 못해 hejo 문이 시작하지 못한다(Slack 무관).
6. **다음:** 노트북에 앱을 복사해 실행하고 자동 연결을 확인한 뒤 TASK-09 체크리스트를 진행한다.

## 검증 판정: HEJO-FOUNDATION TASK-17 / ddots 기능 이식 1단계(보완 12·12-1·12-2) (21차)

1. **판정: 부분 완료.** 요구·수락 기준은 모두 자동 증거로 충족했다. 남은 것은 교체된 옛 메뉴 동작 정리(V-1) 하나다.
2. **검증 조건:** 교차 모델. 실행 담당 codex가 구현했고, 계획 담당 Claude가 다른 대화에서 검토했다. 검토 대상은 제품 `e90681281196be1b66f18c3b934b41cbd5d0c1fb`와 보고 `d5e69e20ce46f0540249945b7e4d2263befbdb53`이다. 분리 worktree에서 시험을 다시 돌렸고, 그 worktree는 버렸다.
3. **설계 적합성(4.2): 적합.**
   - **창·펫 위치:** 창 크기·위치는 `LocalSettings`(이 Mac 전용)에 둔다.
   - **회원 설정:** 펫 이름·크기·말풍선 항상 보이기·고정·알림 끔·숨김은 기존 허브 회원 설정 문자열 맵에 둔다. 허브 서버는 바뀌지 않았다. 로컬 값은 오프라인용 복제본이고, 원본은 회원 설정 하나다.
   - **메뉴(12-1):** 상태 막대와 펫 메뉴가 같은 메뉴다. 항목은 "대화 열기 / 펫 숨기기·잠시 쉬기 / 설정… / 버전 / hejo 종료"뿐이다. 계정·로그인·펫 설정은 설정 창 세 페이지(일반·화면과 펫·계정)로 옮겼다.
   - **우클릭(12-2):** 직원 셀·빈 곳·머리줄이 각자 자기 메뉴를 갖는다(`EmployeeMenuTable.menu(for:)`, `EmployeeMenuScroll`). 앱 메뉴로 새지 않는다.
   - **알림 끔:** `visibleUnreadTotal`을 펫·아일랜드 합계에, `IslandModel` muted 필터를 강조에 쓴다. 이 직원의 asked는 빨간 점으로만 센다(AC-06 그대로).
   - **경계 유지:** 아일랜드·작성 중 표시·로그인·gate·hub·wire 계약은 유지했다. SwiftUI 0, Slack 호출 0.
   - **ddots 대조:** copy-review.md에 ddots 원본별 기록이 있다.
4. **직접 확인한 것**
   - `python3 .build/foundation9_runner.py hejo`(분리 worktree, `d5e69e2`): 종료 0. 93 passed, AT-HF-61·62·63·64·65·67 PASS, 앱 시험 APP_TEST_OK.
     - 첫 실행은 AT-HF-22에서 `No module named 'yaml'`로 실패했다. 검토자가 worktree에 `.build/task02-deps`·`task03a-deps`를 복사하지 않은 환경 탓이다. 복사 뒤 통과했다(제품 무관).
   - 개인값 검사 종료 0, `import SwiftUI` 0건.
   - 시험의 독립성: 메뉴 제목은 명세 문자열을 그대로 비교한다. 고정 순서·모두 읽음(스레드 2개)·알림 끔 집계·아일랜드 제외·숨김 보존·재등장·설정 문자열 왕복은 StubHub의 PUT 본문으로 확인한다. 수락 시험 문서(`tests/acceptance`)는 바뀌지 않았다.
   - 캡처 3장(계정·말풍선·설정)은 가짜 값만 담았다(가짜 회원·가짜 직원·가짜 공항).
   - 설치본: `/Applications`와 공용 사본의 실행 파일 해시가 같다. 서명 검증 통과, 프로세스 1개. 새 문자열(숨긴 대화 다시 보이기·목록에서 빼기·petScale)이 실행 파일에 있다.
   - 증거 수준: 2(자동 대역·창 캡처)로 설계 요구 수준에 도달했다.
5. **지적**
   - **V-1 (비차단, 구현).**
     - 위치: `app/Sources/AppDelegate.swift`의 `@objc settings()`·`resetPosition()`·`resetChatSize()`·`loginSettings()`·`login()`·`rename()`.
     - 기준: 30-verification 4.3·7.1(대체된 코드 정리).
     - 근거: 12-1로 메뉴 항목이 빠지면서 이 셀렉터를 부르는 곳이 0이 됐다(`#selector`·직접 호출 검색). `rename()`의 이름 입력 경고창은 설정 창 이름 칸으로 대체됐다.
     - 처리: 지운다. 설정 창은 `setLoginEnabled`와 `LoginLaunch.openSettings`, `pet.resetPosition`·`resetChatSize`를 직접 쓴다.
   - **관찰(지적 아님).** 회원 설정 저장이 실패하면 조용히 멈추고, 다음 변경 때 전체를 다시 보낸다. 인계서 "다음 저장 때 보낸다"에 맞다.
   - **관찰(지적 아님).** 보고서가 적은 "빌드 스크립트의 OAuth 비밀 파일 간접 읽기"는 hejo 자체의 미추적 `config/google-oauth-secret.json`이다. 제품 빌드가 Info.plist에 넣으려고 읽는 정해진 경로라 `~/.hermes` 비밀 파일 금지 위반이 아니다. 시험 빌드가 `HEJO_SKIP_GOOGLE_SECRET=1`로 읽지 않게 한 변경은 수락한다.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위와 남은 위험**
   - 실제 직원 글에서 말풍선·펫 동작을 보지 못했다.
   - 다른 Mac 사이 회원 설정 동기화를 보지 못했다(맥북프로·맥북에어 실물은 TASK-09 남은 항목).
   - 물리 화면 꺼짐·잠금과 우클릭 메뉴의 실사용 조작을 보지 못했다.
8. **원인 분류: 구현 오류(정리 누락).**
   - 완료 조건: V-1을 지우고 같은 검증(runner 0, 앱 시험, 개인값 검사 0)을 통과한다.
   - TASK-18(앱 아이콘)과 같은 실행 묶음에서 별도 커밋으로 한다(보완 지시 13-1).

## 검증 판정: HEJO-FOUNDATION TASK-17 V-1 · TASK-18 / 옛 메뉴 정리·앱 아이콘 HEJO. (22차)

1. **판정: 완료.** TASK-17은 V-1을 처리해 완료로, TASK-18도 완료로 판정한다. 보완 13-2(전체 미사용 코드 정리)는 실행 담당의 기준 커밋(`80b44a6`)보다 뒤에 쓴 새 지시라 이번 범위가 아니다. TASK-19로 따로 인계한다.
2. **검증 조건:** 교차 모델. 실행 담당 codex가 구현했고 계획 담당 Claude가 검토했다. 검토 대상은 `39f7e4b`(V-1)·`e485b22`(아이콘)·`44f37ba`(보고)이며, 분리 worktree에서 다시 실행한 뒤 버렸다.
3. **설계 적합성(4.2): 적합.**
   - V-1: 호출처가 없던 셀렉터 6개만 지웠다(17줄 삭제). 남은 경로는 설정 창의 `setLoginEnabled`·`LoginLaunch.openSettings`·`pet.resetPosition`·`resetChatSize`다.
   - 아이콘: `AppIcon.render(pixels:)`라는 순수 AppKit 함수 하나를 시험과 빌드 도구(`app/Tools/IconMain.swift`)가 함께 쓴다. 원본이 하나다. 빌드할 때 `.build/AppIcon.iconset` 10장을 만들고 `iconutil`로 `AppIcon.icns`를 만든다. Info.plist의 `CFBundleIconFile`은 `AppIcon`이다. png·icns·글꼴은 추적하지 않는다(`git ls-files` 0). 런타임에 Dock 아이콘을 바꾸지 않는다.
   - 모양: 824 사각형·반지름 185·heavy·폭 78%·H systemBlue sRGB·EJO. #1d1d1f. REQ-HF-22와 로고(REQ-HF-17)에 맞다.
4. **직접 확인한 것**
   - `python3 .build/foundation9_runner.py hejo`(worktree `44f37ba`, deps 복사): 종료 0. 93 passed, AT-HF-61~67 PASS.
   - 빌드 번들에 `AppIcon.icns`가 있고 plist 키가 `AppIcon`이다. 개인값 검사 0, `import SwiftUI` 0.
   - 설치본 두 사본: plist 키 `AppIcon`, icns 해시가 서로 같다. 서명 검증 통과, 앱 프로세스 1개.
   - OS가 읽은 아이콘 그림(`app/.build/task18-workspace-icon.png`)을 직접 보았다. 흰 둥근 사각형 가운데에 `HEJO.`가 있고 H만 파랑이며 좌우 여백이 있다.
   - AT-66 시험의 기대값은 명세 수치(모서리 투명, 가운데 줄 파랑·어두운 화소, 좌우 약 10% 여백, 16px 잘림 없음)에서 왔다. 구현 상수를 복사하지 않았다.
   - 증거 수준: 2(자동 + 실제 설치본의 OS 아이콘 읽기).
5. **지적:** 차단 0, 비차단 0.
   - 관찰: Finder 아이콘 보기 캡처는 자동화 권한 거부로 못 했고 OS 아이콘 읽기로 대신했다. 앱이 `LSUIElement`라 Dock 타일은 없다. 사장이 응용 프로그램 폴더에서 눈으로 확인하면 된다.
6. **기획설계로 넘긴 것:** 보완 13-2를 TASK-19 "쓰지 않는 코드 정리"로 등록.
7. **미검증 범위:** Finder 창 안에서의 아이콘 실물 표시(사장 눈 확인). TASK-17의 실물 미검증 항목(21차 7번)은 그대로 TASK-09 남은 항목이다.
8. **현재 명세 반영 요청:** REQ-HF-21.AC-01~06(1단계)과 REQ-HF-22.AC-01을 현재 명세(`docs/spec/current/`)에 반영한다. HEJO-FOUNDATION을 닫을 때 한꺼번에 한다.

## 검증 판정: HEJO-FOUNDATION TASK-19 / 쓰지 않는 코드 정리(보완 13-2·13-3) (23차)

1. **판정: 완료.** 앱의 호출처 없는 선언을 지웠고 동작·시험 기대값은 그대로다. `gate/`·`hub/`·`install/`에는 지울 대상이 없다는 실행 담당 보고를 독립 확인으로 받아들인다.
2. **검증 조건:** 교차 모델. 실행 담당 codex가 `9e991e1`로 구현·보고했고, 계획 담당 Claude가 검토했다(01번 계획 대화가 한도에 차서 새 계획 대화가 이어받음).
3. **설계 적합성(4.2): 적합.** 13개 앱 파일에서 307줄을 지웠다. 새 경로나 대체 경로는 없다. `ScreenFocus.swift`·`ScreenWindowResolver.swift`는 묶음 전체가 미사용이어서 파일째 없어졌다. 남긴 것(AppKit·대리자 메서드, `CodingKeys`, 셀렉터 버튼 동작, 응답 체인의 `pasteAsPlainText`·`pasteAsRichText`, `AppIcon.render`)은 13-2 기준에 맞다.
4. **직접 확인한 것**
   - 지운 이름 12개 표본(`callerAvatar`·`notificationAvatar`·`collapseConversation`·`ScreenWindowResolver`·`ScreenFocus`·`GeniePictureKey`·`PetBubbleMotion`·`perchRect`·`hasProfileColor`·`cachedCount`·`contentBounds`·`allowsLook`): app·gate·hub·install·tests·schemas 전역 검색 0건. `app/Sources`에 문자열 셀렉터(`NSSelectorFromString`·`Selector("…")`) 0건.
   - `gate/`·`hub/`·`install/` Python 정의(함수·클래스) 전체를 저장소 전역에서 이름 검색: 참조 1회 이하인 것은 pytest가 찾는 `test_*` 함수뿐이다. 제품 코드의 미참조 정의 0.
   - 실행 담당 로그: `.build/foundation9-hejo.log` 93 passed, `.build/task19-app.log` `APP_TEST_OK`, `.build/task19-install-verify.log` 서명 2·실행 파일 일치·프로세스 1. 코드 변경 뒤 새 커밋이 없어 전체 시험을 다시 돌리지 않았다.
   - 증거 수준: 1(자동 + 컴파일러가 남은 참조를 강제).
5. **지적:** 차단 0, 비차단 0.
   - 관찰: 기본 `python3`에 `ruamel`이 없어 개인값 검사 첫 실행이 종료 2였고 Hermes Python으로 0을 확인했다(`.build/task19-scan-initial.log`). 검사 도구 환경 문제이며 제품 결함이 아니다.
6. **기획설계로 넘긴 것:** 없음. 다음은 이미 인계된 TASK-22 → TASK-20 → TASK-21(기준 `41814ac`)이다.
7. **미검증 범위:** 없음(동작 불변 작업). TASK-17·09의 실물 미검증 항목은 그대로다.

## 검증 판정: HEJO-FOUNDATION TASK-54 / 에이전트 연결 검색·정렬·연결된 것만(보완 69) (1차)

1. **판정: 미완료.** 구현이 시작되지 않았다. 실행 담당이 인계의 중단 조건("impl-report.md에 남의 미커밋 변경이 섞이면 멈추고 보고")에 따라 보류로 보고했고, 그 판단은 옳다.
2. **검증 조건:** 교차 모델(실행 codex, 검토 Claude). 검토할 코드가 없어 문서·저장소 상태만 확인했다.
3. **설계 적합성(4.2): 판정 대상 없음.** 제품·시험 변경 0.
4. **직접 확인한 것**
   - 구현 worktree(브랜치 `role-workflow/3-d98f9311`): HEAD `d56f428`, 작업 트리 깨끗함. 플러그인 수집 증거도 변경 파일 0.
   - 계획 담당 checkout: `impl-report.md`·`copy-review.md`·`gate/`에 보완 68의 미커밋 변경이 있다(이 작업 것이 아님).
   - 시험·개인값 검사·돌연변이·화면 사진: 모두 미실행. 도달 증거 수준 없음.
5. **지적:** 차단 1.
   - V54-01(차단, 원인 분류: 설계·인계 오류 — 요구 불변): 보고 위치를 다른 작업이 같은 때 덧붙이는 `impl-report.md` 끝으로 지정해 착수할 수 없었다. 조치: [handoff.md](handoff.md) 보완 69의 보고 위치를 구현 worktree의 새 파일 `impl-report-task54.md`로 바꿨다. 요구(AC-05)·시험 기대값(AT-101)·범위(제품·시험 두 파일)는 그대로다.
6. **기획설계로 넘긴 것:** 위 인계 정정(완료). 실행 담당에게 같은 계획을 다시 인계한다.
7. **미검증 범위:** TASK-54 전체.

## 검증 판정: HEJO-FOUNDATION TASK-54 / 에이전트 연결 검색·정렬·연결된 것만(보완 69) (2차)

1. **판정: 완료.** REQ-HF-32.AC-05의 모든 항목이 구현됐고 AT-101이 통과한다.
2. **검증 조건:** 교차 모델(구현 codex, 검토 Claude — 계획도 같은 Claude 대화가 했으므로 설계 적합성을 3번에서 따로 판정). 검토한 코드 상태: 구현 worktree 브랜치 `role-workflow/3-d98f9311`, 커밋 `0a8864423e5731d40eeca4127eaa0f843835e945`(기준 `d5c9133`, 보완 68 포함), 작업 트리 깨끗함.
3. **설계 적합성(4.2): 적합.**
   - 설계 → 요구: AC-05의 자리·정렬·검색 네 필드·공백 제거·연결된 것만·빈 묶음·빈 안내·불변 항목·메모리 유지·접근성 이름이 모두 AT-101 또는 화면 사진·코드 확인에 연결돼 있다. 계획 검증 1회차 지적(PR54-01~04)으로 빠졌던 관측을 채웠다.
   - 구현 → 설계: 보이는 줄 계산은 `ConnectionsModel.visibleGroups` 한 곳이고, 뷰의 묶음별 `filter`와 묶음 정의(`groups`)는 지워졌다(교체, 남은 호출 없음). 검색어·켬 값은 모델의 `@Published` 메모리 값이며 저장·서버 요청이 없다. 요약 알약·요약 점·"모두 확인"·버튼 코드는 바뀌지 않았다.
   - 설계와 달라진 점: 없음. 시험용 사진 배경색 지정은 시험 코드 안의 캡처 보조이며 제품 동작이 아니다.
4. **직접 확인한 것**
   - 변경 파일: `git diff d5c9133 0a88644` — `app/Sources/ConnectionsWindow.swift`, `app/Tests/ConnectionsTests.swift`, `impl-report-task54.md`, `tasks.md` 상태 칸. 보고에 없는 변경 0. `TestMain.swift`·`gate/`·규격 변경 0.
   - 수락 시험: 기존 AT-HF-83 단언은 한 줄도 바뀌지 않았다(끝에 AT-101 호출만 더함). AT-101의 시험 자료 10개와 기대값은 handoff 8번과 글자 그대로 같다(literal).
   - 직접 실행: 검토자가 worktree에서 `bash app/scripts/test.sh`를 돌려 `AT-HF-83 APP PASS`·`AT-101 APP PASS`를 확인했다. 검토자 환경의 기본 python3에 `aiohttp`가 없어 뒤쪽 통신 시험에서 종료 1로 끝났다(환경 차이, 이 변경과 무관 — 구현 담당도 같은 원인을 기록).
   - 구현 담당 로그(직접 열어 확인): `.build/task54/app-test.log` 전체 종료 0(Hermes Python 지정), `.build/task54/scan.log` 개인값 검사 종료 0, `.build/task54/mutation-test.log` 정렬 제거 사본이 `AT-101 case-insensitive natural label order and equal-label id order`에서 실패.
   - 화면 사진(직접 열어 확인): `.build/task54/screenshots/task54-hejo.png` — 요약 알약(4·2·3) 아래 검색칸 "google"과 "연결된 것만" 체크, "계정과 서비스"에 Google AI Studio 두 줄(id순: 확인 안 됨 → 연결됨)뿐. `task54-detail.png` — 상세 화면에 검색칸·체크 없음.
   - 코드 확인: 검색칸·체크가 `$model.searchText`·`$model.connectedOnly`에 직접 묶임, 접근성 이름 "연결 검색"·"연결된 것만" 지정.
   - 증거 수준: 2(가짜 문서로 모델·화면 시험) — 요구 수준 2 충족.
5. **지적:** 차단 0, 비차단 0.
   - 관찰(기록만): 연결이 하나도 없는 직원은 필터가 꺼져 있어도 "맞는 연결이 없어요"가 보인다(전에는 빈 화면). AC-05 "모든 묶음이 비면" 문구와 맞고 해롭지 않아 그대로 둔다.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위와 남은 위험:** 실서버 자료(연결 수백 줄)에서의 손 조작·눈 확인은 미실행(사장 선택 항목). 사진의 같은 이름 중복 줄 정리는 범위 밖.
9. **현재 명세 반영:** 이 저장소에는 `docs/spec/current/`가 아직 없고 [spec.md](spec.md)가 현행 원본이다. REQ-HF-32.AC-05(36판)가 그대로 적용 기준이며 tasks.md TASK-54를 완료로 닫았다.
