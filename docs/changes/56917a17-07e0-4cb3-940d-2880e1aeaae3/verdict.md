## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-20 직원 사진·색·사이드바 배치

1. **판정:** 부분 완료. 이번 검토 범위에서 결함은 없다. 고위험 조건(비설계자 검토, TASK-23 실물 수준 4)이 남았다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토한 코드는 `344cbbdec030e6f5a003f252fc3a751bde2a5e5e`(깨끗한 임시 worktree)이다.
   - 실행 담당이 결과를 푸시 승인 대기로 보고해 자동 검토 요청이 오지 않았다. 사장 질문을 받고 계획 담당이 직접 검토했다.
3. **설계 적합성(4.2):** REQ-HF-23(23판)을 충족한다.
   - 문(`gate/pictures.py`, `roster.py`, `server.py`):
     - 명부에 `avatar`(avatar.png > slack-avatar.png, `?v=` 수정 시각), `avatar_custom`(avatar.png일 때만 true), `color`(`ui_meta.hermes-bots.color`만, hex·hsl 정규화)를 보낸다.
     - 사진 쓰기: `PUT`/`DELETE /v1/pictures/{employee|room}/{id}`는 인증을 받는다. 512 KiB 초과는 413, PNG 구조·CRC·압축 해제 검증 실패는 415다. 직원 사진은 프로필 `assets/avatar.png`에만 0644로 원자적으로 쓴다. 심볼릭 링크는 거부한다.
     - 방·구획·홈 사진은 `shared/hejo/pictures`에 0700/0600으로 둔다.
     - 사진이 바뀌면 직원 명부를 방송한다. `/v1/avatars`는 지웠다.
   - 앱(`SidebarLayout`):
     - 순서: 홈 → 구획 3개("section N") → 1:1 묶음(명부 순서·이름).
     - 고정: 고정한 1:1은 묶음 밖으로 나온다. 1~5번째 자리를 먼저 채우고 나머지는 최신 순이다. 빈 자리는 메운다.
     - 끌기: 묶음 안 1:1은 끌 수 없다.
     - 삭제 문구는 22판 그대로다. 신호 점·99+ 표시가 있고, 배치는 회원 상태 키에 저장한다.
   - 메뉴: 2~5번째 자리 고정, 빈 곳 "새 섹션 만들기"·"목록에서 뺀 방".
4. **직접 확인한 것:**
   - `foundation9_runner.py hejo`(344cbbd): 종료 0, pytest 148 passed, 앱 시험 통과. 로그 `/tmp/t20-review-full.log`.
   - 검토자 돌연변이: `avatar_custom`을 늘 true로 바꾸면 사진 시험이 2 failed / 7 passed로 잡아낸다. 원복했다.
   - 개인값 검사(344cbbd): 0.
   - 기존 시험 변경: `Task17Tests`·`ConversationTests`의 메뉴·행 위치 기대만 사이드바 구조 변경(REQ-HF-23.AC-02, 22·23판)에 맞춰 바뀌었다. 승인된 변경이다. 수락 시험 문서 변경은 없다.
   - 증거: 캡처 5장과 `evidence/HEJO-FOUNDATION/TASK-20.md`(ddots 사이드바와 나란히 비교).
   - 증거 수준: 2.
5. **지적:** 차단·비차단 없음.
6. **흐름 문제(기록):**
   - 실행 담당이 커밋 뒤 status를 푸시 승인 대기로 보고해, 작업이 사장 입력 대기에서 멈췄다.
   - 보완 23에 흐름 규칙을 적었다. TASK가 끝나면 `result`로 보고하고, 푸시는 진행 조건이 아니다.
7. **남은 위험:** 단체방 사진은 방 존재 여부를 TASK-21에서 확인해야 한다(지금은 id 형식만 검사). 실제 두 Mac 확인은 TASK-23에서 한다.
8. **원인 분류:** 결함이 아니다. 남은 조건은 계획된 고위험 단계다.
9. **다음:** TASK-25.
