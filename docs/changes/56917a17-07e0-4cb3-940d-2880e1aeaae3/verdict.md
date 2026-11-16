## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-26 알림 막대·검색·머리줄·작성기

1. **판정:** 완료(TASK-26, 일반 위험 · 증거 수준 2). 결함 없음. 전체 작업 56917a17은 다음 TASK가 남아 계속 진행한다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토한 코드는 `feecf4ff144551e86f7f4f7eddea38eddcd3c35a`(깨끗한 임시 worktree, 시험 의존 복사)이다.
3. **설계 적합성(4.2):** REQ-HF-28(26판)을 충족한다.
   - 검색(`WorkspaceTools.WorkspaceSearch`):
     - 처리 순서: 생각 중 줄과 숨긴 방을 빼고 일치 글을 최신 순으로 고른다. 그중 `prefix(200)`을 스레드별로 묶는다. 구절 일치 묶음이 먼저이고, 그다음 최신 순이다. ddots `SlackSearch` 원문과 같다.
     - 사이드바 글 검색은 최신 30건이다.
     - 하이라이트는 노랑 바탕 검정이다.
   - 알림 막대(`notices`):
     - 질문 묶음과 24시간 안 알림을 구분한다. 종·확인 상태는 허브 회원 상태 `bell:`/`confirm:`을 쓴다.
     - "모두 읽음"은 질문을 빼고 처리한다.
     - 색 #36C5F0·#ECB22E와 문구는 원문이다(impl-report "원본 차이 처리"에 26판 근거 기록).
   - 머리줄 제목·설명은 회원 상태 `title:`(4 KiB 검사)에 저장한다. 새 영구 원본은 없다.
   - 멘션 토글·자리별 초안·답글 자동 전환·실패 글 보존/되살리기/지우기를 구현했다. 자동 재전송은 없다.
   - 통신 계약과 기록장은 바뀌지 않았다. SwiftUI import는 0건이다.
4. **직접 확인한 것:**
   - `foundation9_runner.py hejo`(feecf4f): 종료 0, 156 passed. 앱 시험과 `WORKSPACE_FIXTURE_PASS`(실제 루프백 자동 전환·실패 보존)가 통과했다.
   - 검토자 돌연변이 — 검색의 200개 선택을 빼고 전부 묶음: 앱 시험이 `AT78 latest 200 matching posts before grouping`으로 실패했다(검출). 원복했다.
   - 개인값 검사 0(실행 담당 로그 및 직전 커밋 검사).
   - 기존 시험 변경: `ConversationTests`·`IslandTests`·`Task17Tests`의 기대값이 머리줄 메뉴·알림 수 변경(REQ-HF-28.AC-01·04)에 맞춰 바뀌었다. 승인 범위다.
   - 증거: `evidence/HEJO-FOUNDATION/TASK-26.md`와 ddots/hejo 같은 상태 캡처 5장.
5. **지적:** 없음.
6. **남은 위험:**
   - 단체방 명부와 함께 쓰는 검색·알림은 TASK-21에서 확인한다.
   - 운영 연결 실물 확인은 TASK-23에서 한다.
7. **다음:** TASK-29.
