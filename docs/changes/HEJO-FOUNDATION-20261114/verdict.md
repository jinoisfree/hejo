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
