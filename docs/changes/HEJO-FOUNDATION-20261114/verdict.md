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
