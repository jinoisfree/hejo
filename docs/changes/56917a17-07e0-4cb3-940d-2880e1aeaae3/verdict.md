## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-25 착수 보류(D25-02~05)

1. **판정:** 미완료. TASK-25 제품 구현은 아직 시작되지 않았다. 실행 담당이 보고한 네 쟁점은 모두 실제 명세·설계 결함이며, 멈춘 판단은 옳았다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토 대상은 HEAD `cf0a23cd0778a57b5cc69b3933e5380099b2075d` 위의 미커밋 보고 파일 두 개다. 제품 코드 변경은 없다.
3. **설계 적합성(4.2):** 제품 변경이 없어 해당 없다. 보고된 쟁점을 원본에서 직접 확인했다.
   - D25-02: 규격 `x-sync`는 "seq == applied+1만 적용, 빈칸이면 sync"다. `GateClient.swift:166~170`도 같다. 18판처럼 지운 기록을 빼면 빈칸이 생겨 앱이 적용하지 못한다. 확인됨.
   - D25-03: spec REQ-HF-26.AC-01은 `bell:`을 큰 seq 우선으로 정했다. 그래서 종 되돌림(null)이 이길 수 없다. ddots `dismissed:`는 나중 쓴 쪽 우선이다. 확인됨.
   - D25-04: Hermes `ebb026e`의 `BRANCH_THREAD_PLATFORMS`는 Discord·Telegram·Slack·Matrix 고정 목록이다. `_branch_open_thread`는 목록 밖 플랫폼에서 어댑터를 부르지 않는다. 그래서 `create_handoff_thread`를 구현해도 호출되지 않는다. 확인됨.
   - D25-05: ddots는 질문 대기에 `askingColor`(빨강)를 쓰는데, 명세는 노랑이었다. 확인됨.
4. **직접 확인한 것:**
   - Hermes `gateway/slash_commands_branch_thread.py`, `slash_commands_session.py` 분기 처리(읽기만).
   - `schemas/hejo-wire-v1.json`의 `x-sync`·`delete` 정의, `app/Sources/GateClient.swift`, `gate/journal.py` seq 부여.
   - 실행 담당 재현 기록(`.build/task25/test_contracts.py` 3 passed, 처음 1 failed는 탐침의 플랫폼 등록 누락)은 보고와 맞다. 제품 수락 시험이 아니어서 다시 돌리지 않았다.
5. **지적:** D25-02~05는 모두 명세 결함이며 원인은 계획 담당에 있다. 25판에서 정했다(handoff 보완 25).
   - D25-02: 기존 `delete` 종류로 스레드 범위 확정점을 둔다. 앞 기록은 같은 seq의 `delete`로 바꿔 보내 seq 연속을 지킨다. 옛 앱·옛 문과도 호환된다.
   - D25-03: `bell:`을 나중 쓴 쪽 우선으로 바꾼다.
   - D25-04: 문이 직접 새 스레드를 만들고, 원래 대화를 문맥으로 붙인다. 본체 우회는 없다. Hermes 세션 복제는 하지 않는다는 차이를 기록했다.
   - D25-05: 원문대로 빨강.
   - 실행 담당 쪽 결함은 없다.
6. **원인 분류:** 명세 결함(계획). 18판 명세를 Hermes 본체 동작과 통신 규격 대조 없이 썼다.
7. **다음:** 보완 25에 따라 TASK-25를 재개한다.
