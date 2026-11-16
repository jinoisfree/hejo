## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-32 직원별 도구 연결 (+ 작업 전체 현황)

1. **판정:** TASK-32는 부분 완료다. 차단 결함은 없다. 고위험 조건(비설계자 검토, TASK-23 실물 수준 4)이 남았고, 비차단 지적 N32-01이 1건 있다. 작업 56917a17 전체도 부분 완료다. 구현 TASK는 모두 끝났고, 남은 것은 TASK-23(사장과 운영 적용), 비설계자 검토, 푸시 승인이다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토한 코드는 `aeaa652a4119bef949c61f192029d2b0b3f5a026`(깨끗한 임시 worktree, 시험 의존 복사)이다.
3. **설계 적합성(4.2):** REQ-HF-32(20·21·29판)를 충족한다.
   - D9(`gate/connections.py`):
     - 공식 검사 `ok`가 true가 아니면 거절한다.
     - 이전 값은 `POST /api/env/reveal`로 받는다(404면 없음). 되돌림 금고에는 10분만 둔다.
     - 쓰기는 공식 `PUT/DELETE /api/env`로 한다. 실패하면 같은 공식 경로로 보상하고, 존재 여부를 확인한다. 보상이 성공하면 `WRITE_FAILED`, 실패하면 `write_partial`과 정해진 문장이다.
     - `reachable`이 true가 아니면 "키 저장됨(확인 안 함)"으로 보인다.
     - hejo가 `.env`를 직접 쓰는 일은 없다.
     - 카탈로그 설치는 여러 키를 넣다 실패하면 역순으로 되돌린다.
   - 재확인: 앱이 `LAContext.deviceOwnerAuthentication`으로 다시 확인한다.
   - 설치 도우미:
     - 의존성이 없으면 "서버의 Hermes를 업데이트해 주세요(hermes update)"를 내고 `skipped`로 남긴다. Hermes venv에 설치하지 않는다.
     - `install/hejo-admin` 감싸개를 쓴다.
     - 운영 launchd 등록은 하지 않았다.
   - 재시작 판정·바쁨 거절·team-kit 프록시·연결 창(SwiftUI 예외)은 실행 담당 시험과 돌연변이로 확인됐다.
4. **직접 확인한 것:**
   - `foundation9_runner.py hejo`(aeaa652): 종료 0, 180 passed.
   - 실행 담당 돌연변이: 보상 제거와 바쁨 거절 제거가 검출됐다(`.build/task32/mutations.json`). 가짜 비밀값 전체 바이트 검색 결과는 0(`byte-search.json`).
   - 검토자 돌연변이 — 보상 뒤 존재 여부 확인 제거: `test_connections.py` 16 passed로 **잡히지 않았다**(N32-01). 원복했다.
5. **지적:**
   - N32-01(비차단, 시험 공백): 보상 `PUT`/`DELETE`는 성공으로 답했는데 실제 존재 여부가 이전과 다르면 `write_partial`이어야 한다. 이 경우를 다루는 시험이 없다. TASK-23 전에 시험만 더한다.
6. **남은 위험·운영 주의:**
   - 실제 서버 키·OAuth·게이트웨이 재시작·launchd 활성화·두 Mac 확인은 TASK-23에서 한다.
   - 롤백은 `shared/hejo` 사본과 이전 릴리스를 함께 복원한다.
7. **원인 분류:** 결함 아님. N32-01은 시험 보강이다.
8. **다음:**
   - N32-01 시험 보강(실행 담당).
   - TASK-23 운영 적용(사장 승인과 참여 필요).
   - 비설계자 검토.
   - 푸시 승인(사장).
