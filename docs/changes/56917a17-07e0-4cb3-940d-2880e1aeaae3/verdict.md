## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-25 스레드 카드·작업 제어

1. **판정:** 부분 완료. 차단 결함은 없다. 고위험 조건(비설계자 검토, TASK-23 실물 수준 4)이 남았다. 비차단 지적 1건(N25-01)은 다음 커밋에서 보완한다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토한 코드는 `af39f962ab8fb3fb3fa568edaaad4b0be26f304a`(깨끗한 임시 worktree)이다.
3. **설계 적합성(4.2):** REQ-HF-27(24·25판)과 REQ-HF-26.AC-01(25판 `bell:`)을 충족한다.
   - 삭제(`gate/journal.py`, `adapter.py`):
     - 확정점은 기존 `delete`에 `scope:"thread"`를 단 한 줄이다. 새 기록 종류는 없다.
     - 나머지 글은 보통 `delete`로 이어 쓴다. 문이 시작할 때(`_finish_thread_deletions`) 빠진 것만 보충한다.
     - `replay`는 확정점 앞의 `message`·`edit`·`state`를 같은 seq의 `delete`로 바꾼다. `page`와 sync 대기열 모두 이 경로를 탄다.
     - 늦은 답·편집·상태·작성 중·파일은 `thread_deleted_drop`으로 버린다. send는 `thread_deleted`로 거절한다.
     - 첨부는 가려진 기록을 등록에서 빼서 정리한다. 다른 스레드와 공유한 첨부는 남는다.
   - 앱:
     - 스레드 범위 `delete`를 받으면 캐시를 같은 seq의 `delete`로 원자적으로 다시 쓰고, 고아 파일을 지운다.
     - 다시 열 때 복구한다.
     - 알 수 없는 seq 프레임은 순서대로 센다.
   - `bell:`은 허브와 앱 모두 LWW로 바뀌었다. `read:`·`thread:`는 큰 seq 우선 그대로다.
   - 분기:
     - `thread_branch` → 새 스레드와 `branch_from` 이어짐 글을 만든다.
     - 문맥(50줄·16,000자·줄 2,000자)은 분기 순간 `_meta`에 저장한다. 새 스레드의 첫 사장 글에만 붙인다.
     - `client_msg_id`로 같은 요청이 두 번 처리되지 않게 막는다.
     - `/branch`·`create_handoff_thread`·본체 우회는 쓰지 않는다.
     - 묶음 코드는 `gate/context.py` 한 곳에 있어 TASK-21이 다시 쓸 수 있다.
   - 문구·색:
     - 되돌리기 글에 Notion·NAS가 포함된다.
     - 복사 첨부는 `📎 ` 형식이다.
     - 질문 대기와 제목 표시 색은 `#E01E5A` 등 명세값이다.
     - 중지는 `/stop`이고, "중지를 요청했어요"가 뜬다.
   - `hejo://thread`: Info.plist에 주소 체계를 등록했다. 앱이 열리기 전에 들어온 주소는 보관했다가 처리한다.
4. **직접 확인한 것:**
   - `foundation9_runner.py hejo`(af39f96 worktree): 종료 0, 155 passed, 앱 시험 통과(`/tmp/t25r/.build/foundation9-hejo.log`).
     - 처음 실행에서 1 failed가 났다. worktree에 `.build/task03a-deps`·`task02-deps`를 복사하지 않아 `yaml`이 없었기 때문이다(기준 eac02ca도 같은 실패). 의존을 복사한 뒤 통과했다. 제품 결함이 아니다.
   - 검토자 돌연변이 1 — `files.cleanup`의 `hidden` 제외 제거: `test_threads.py` 2 failed / 4 passed로 잡혔다. 원복했다.
   - 검토자 돌연변이 2 — `replay` 치환 대상에서 `edit` 제거: 6 passed로 **잡히지 않았다**(N25-01). 코드는 맞지만 시험이 비어 있다.
   - 실행 담당 돌연변이(삭제 seq 치환, bell 병합)는 보고대로 검출된다(`.build/task25/mutations.json`).
   - 개인값 검사: 0.
   - 기존 시험 변경: `ConversationTests`·`TypingTests`의 기대값이 카드 버튼·작업 중 줄 변경(REQ-HF-27.AC-01·04)에 맞춰 바뀌었다. 승인 범위다.
   - 증거: `evidence/HEJO-FOUNDATION/TASK-25.md`와 캡처 4장. ddots 같은 상태 카드와 비교했다. 증거 수준은 2다.
5. **지적:**
   - N25-01(비차단, 시험 공백): 지운 스레드에 편집(`edit`) 기록이 있을 때, 재현·sync가 그 본문을 `delete`로 바꾸는지 확인하는 시험이 없다. 다음 커밋에서 이 시험을 더한다(편집 본문이 sync 출력에 없음 + `edit`를 치환 대상에서 빼는 돌연변이가 잡힘).
6. **남은 위험:** 실제 Hermes 바쁜 세션에서 `/stop`이 어떻게 처리되는지와, 두 Mac에서 종이 따라가는지는 TASK-23 실물 확인에서 본다.
7. **원인 분류:** 결함 없음. N25-01은 시험 보강이다.
8. **다음:** N25-01 시험 보강 → TASK-26.
