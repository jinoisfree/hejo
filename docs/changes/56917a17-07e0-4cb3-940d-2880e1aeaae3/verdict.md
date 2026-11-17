## 검증 판정: TASK-36 읽음·종·버튼 규칙 (2026-11-18)

1. **판정:** TASK-36 완료(`f42a73996a7ca8a4fbf21cf6d64f938fde5581ba`, 파일 24개). 증거 수준은 2/2다. 차단 결함은 없다. 비차단 지적 N36-01(죽은 코드)과 N36-02(캡처 상태)가 있고, TASK-37에서 함께 처리한다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. ddots 원문과 줄 단위로 대조했다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-00·01, 대조표 §A A01~A11·A13~A16, V01·V02·V16, 35판 D36-01을 충족한다.
   - `ThreadAssessment.assess`는 ddots `approvalExchange`(SlackThreads.swift 553-578)와 같다.
     - 생각 중 줄을 빼고, 요청 판정, 가장 새 요청과 앞의 버튼 요청 선택, 첫 답, `yes` 낱말과 직원 이어 쓰기로 종결을 판정한다.
     - `answers`는 ddots 529-531과 같은 조건이다. 클릭 대상이 없으면 답이고, 있으면 그 글만 답이다. hejo에서는 `answerTo`를 쓴다.
     - `buttons`는 대기 버튼 글이 2개 이상이면 각 글, 아니면 대기 요청이다(ddots `buttonPosts` 547-551).
   - `yes` 낱말 목록, `approval1`·`approval2`·`nothingWaiting` 정규식이 DdotsConfig.swift 127-160과 같다.
   - 막대 색: 대기 #E01E5A, 처리 중 #ECB22E, 종결·승인 #2EB67D다. "처리 완료" 줄은 없다.
   - 기본 단추 4개, 정해진 단추가 아니면 흐림과 원문 안내, "확인" 툴팁 원문은 ddots SlackPanel.swift 2928-2951과 같다.
   - 연결이 끊겼을 때(`canSend`) 승인·거절을 막는 것은 hejo 기존 계약이다. ddots에는 이 조건이 없다.
   - 문: reply 클릭 기록에만 `answer_to`를 넣고, `send`의 `answer_to`는 스키마가 거절한다. 규격은 선택 필드만 추가했다.
   - 학습 보고·메일 초안 판정은 대조표 A06대로 넣지 않았다.
4. **직접 확인한 것**
   - 깨끗한 worktree(f42a739)에서 `gate/tests/test_answer_targets.py`를 다시 실행했다. 종료 0, 1 passed.
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: `answer_to` 기록을 뺀 사본은 종료 1로 검출되고, 기준 사본은 종료 0이다.
   - `post-checks.json`: 캡처, 옛 문 호환, 옛 앱 디코더, codesign이 모두 0이다.
   - 캡처 두 장을 직접 비교했다.
     - 막대 3색, 종 위치, 단추 기하가 같다.
     - hejo 쪽은 승인·거절과 분기·삭제가 흐리다. 연결 안 됨 상태로 찍혔기 때문이다(N36-02).
5. **지적**
   - N36-01(비차단, 정리): `ReplyButtonPolicy`의 2026-10-31 날짜 조건 분기(`since`·`scriptSince`·`retired`·`legacyScript`·`mailLegendBefore20261031`)는 hejo 기록(11-14 이후)에서는 실행되지 않는 ddots 이력이다. 그런데 운영자 업무 낱말을 공개 저장소에 남긴다.
   - N36-02(비차단, 증거): hejo 캡처가 연결 안 됨 상태라 ddots 캡처와 같은 상태가 아니다.
6. **원인 분류:** N36-01은 원본을 그대로 옮기면서 생긴 범위 과다다. N36-02는 증거를 만드는 과정의 실수다. 둘 다 기능 결함은 아니다.
7. **남은 위험:** 두 Mac 실물과 운영 결합. 옛 문에서는 버튼 답이 직접 쓴 글처럼 계산된다(35판 알려진 차이).
8. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-37이다.

---

## 검증 판정: TASK-36 1차(D36-01 보류) (2026-11-17)

1. **판정:** TASK-36 미완료.
   - 실행 담당이 A07에서 D36-01을 재현하고 멈췄다. 커밋은 없다.
   - 초안 14개는 `.build/task36/draft/`에 보존했다.
   - 작업 트리에는 보고 두 파일만 바뀌어 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 구현이 적용되지 않아 판정하지 않는다.
4. **직접 확인한 것**
   - `target-comparison.json`: ddots 원본 함수를 그대로 분리해 실행했을 때 `clickedPending=[request-b]`, `typedPending=[]`이다.
   - `gate/adapter.py:583-595`: reply 클릭은 `receive`를 부르고, 대상은 `raw._hermes_button`에만 있다.
   - `schemas/hejo-wire-v1.json` `message`: `additionalProperties: false`이고 대상 필드가 없다.
   - 실행 담당 보고와 일치한다.
5. **원인 분류:** 명세 공백이다. 대조표 A07은 "답하면 사라짐"만 적었고, ddots의 클릭 대상 구분과 그에 필요한 규격 필드를 계획하지 않았다. 구현 결함이 아니다.
6. **결정·보완:** 35판 보완 50.
   - 규격 v1 `message`에 선택 필드 `answer_to`를 더한다(하위 호환). 문이 버튼 답 기록에만 넣는다.
   - 앱은 ddots `answers`·`pendingPosts`대로 계산한다.
   - 옛 문에서 생기는 차이는 알려진 차이로 둔다.
7. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-49 team-kit hejo 경로 (2026-11-17)

1. **판정:** 부분 완료. 필요한 증거 수준은 3(운영 반영·실물)이고, 이번에 도달한 수준은 2(대역 통합)다. 구현에서 차단 결함은 찾지 못했다. 운영 반영과 실물 확인은 0.2.x 때 계획 담당과 사장이 한다(보완 49).
   - hejo 커밋 `85f1e23c2273a35b993e34ffff3d642a5a7e2f74`: 공개 조회 `first_thread_message`와 시험.
   - team-kit 패치 `.build/task49/team-kit.patch`(sha256 `7d7cb693…`, 4개 파일).
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. Hermes 본체와 운영 원본은 읽기만 했다.
3. **설계 적합성(4.2):** REQ-HF-43.AC-01과 35판 D49-01을 충족한다.
   - 문 조회
     - 그 직원의 살아 있는 첫 직원 글만 돌려준다. 사장 글, 다른 직원 글, 삭제된 방은 빼고, 보조 프로필 전달자로도 넘긴다.
     - 규격은 바뀌지 않았다.
     - team-kit은 문 내부를 import하지 않는다.
   - J01 글 나누기
     - Slack `post_pieces`를 공용 `_post_pieces`로 뺐다(Slack 경로 동작은 그대로).
     - hejo `send`는 조각이 2개 이상이고 중간 보냄·편집 예정·열린 흐름이 아닐 때 같은 스레드에 조각별로 보낸다. 조각마다 `prepare`를 따로 적용한다.
     - 나눌 수 없으면 나누기 줄만 뺀다.
   - J02 상태 보고
     - `report_status`는 플랫폼이 hejo일 때 hejo 갈래로 간다.
     - 소유자 차례, 스레드 안, 같은 세션 환경을 확인한다. 도구 인자로 대상을 정하지 않는다.
     - 첫 직원 글의 제목 표식을 바꾸고, `pending·failed→asked`, `partial→answered`, `done·declined→closed`로 바꾼다. 끝난 상태면 단추를 비운다.
     - 다시 그리는 `edit`가 답한 스레드를 닫아 버리지 않게 `_hermes_report_status` 표식을 쓴다.
     - Hermes `handle_message`는 결합을 설정한 문맥 안에서 백그라운드 작업을 만들고, 도구 스레드는 `copy_context`로 문맥을 넘긴다. 따라서 이 결합 방식은 Hermes 구조와 맞다. 실제 차례로 실물 확인은 남았다.
   - J03 체크리스트
     - 일반 체크리스트는 `can_skip: true`다(team-kit `checklist_blocks`에 늘 건너뛰기가 있음).
     - 맞춤 제출 변형은 `items`가 체크 항목뿐이고 `can_skip: false`다. 제출 낱말은 프레임 어디에도 없다(시험 382줄에서 확인).
     - 사장 답이 `선택: …`·`전체`·`건너뛰기`이고 그 체크리스트에 맞으면 answered로 바꾼다.
   - 사용량 꼬리말은 hejo에 등록하지 않는다(`test_usage_registration_excludes_hejo`).
4. **직접 확인한 것**
   - 깨끗한 worktree(85f1e23)에서 `test_report_query.py`를 다시 실행했다. 종료 0, 3 passed.
   - 실행 기록
     - `team-final-run.log`: 4878 passed, 3 skipped.
     - `airport-final-run.log`: PASS.
     - `frozen-progress.json`: 세 행 모두 종료 0이고 입력은 바뀌지 않았다.
   - `patch-dry-run.json`: 운영 원본 임시 복사본에 dry-run이 종료 0이었다. `appliedToLive`와 `liveModified`는 둘 다 false다.
   - `mutations.json`: 직원 소유 필터와 맞춤 `can_skip`을 바꾼 돌연변이가 각각 검출됐다.
   - `parity-comparison.json`: 같은 입력에서 ddots 파서·답 함수의 결과와 hejo 프레임이 같다.
5. **지적:** 없음.
6. **남은 위험(보완 49)**
   - 실제 Hermes 백그라운드 차례와 대기열 차례에서 `current_hejo_turn` 결합이 유지되는지 확인해야 한다.
   - 운영 원본 교체와 `./sync` 때 cctv의 다른 작업 변경이 섞이는지 확인해야 한다.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-36이다.

---

## 검증 판정: TASK-49 2차(D49-01 보류) (2026-11-17)

1. **판정:** TASK-49 미완료.
   - 시작 대조는 해소됐다. 변경 범위 373개가 운영 원본과 같다(`scoped-comparison.json`).
   - 실행 담당은 D49-01(맞춤 제출 계약)을 재현하고 멈췄다. 커밋은 보고 두 파일뿐이다(`ccc199f`).
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 구현이 없어 해당하지 않는다.
4. **직접 확인한 것**(읽기만 했다)
   - team-kit `reply_buttons.py:150-215`의 `ChecklistLabels.submits`, `checklist_blocks`.
   - `checklist-contract.json`: Slack 답 6종이고, 지금 hejo 답은 `선택: 일정`이며, 새 필드는 `invalid_checklist`로 거절된다.
   - ddots
     - `SlackThreads.swift:74-88`: 토글·건너뛰기만 읽는다.
     - `SlackPanel.swift:3540-3575`: 작성·건너뛰기만 있다.
     - `checklistAnswer` 605-609: `선택: …`.
   - 따라서 ddots에서도 맞춤 제출 단추는 보이지 않았다.
5. **원인 분류:** 명세 공백이다. 계획 담당이 REQ-HF-43 J03에 "submits는 Slack과 같은 의미로 정하고 기록"이라고만 적고, ddots 동작을 확인하지 않았다. 구현 결함이 아니다.
6. **결정·보완:** 35판 보완 48.
   - submits 변형은 ddots와 같게 `items` = 체크 항목, `can_skip: false`로 보낸다. 제출 낱말은 보내지 않는다.
   - 규격은 바꾸지 않는다.
   - spec J03을 갱신했다.
7. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-49 1차(시작 조건 보류) (2026-11-17)

1. **판정:** TASK-49 미완료(아직 착수 전).
   - 실행 담당은 시작 대조에서 소스 차이 3건을 찾고 지시대로 멈췄다. 맞는 처리다.
   - 커밋은 없다. hejo 작업 트리에는 보고 파일 2개만 바뀌어 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 구현이 없어 해당하지 않는다.
4. **직접 확인한 것**(읽기만 했다)
   - 운영 원본 `cctv/now.py`의 수정 시각은 2026-11-17 21:51이고, 저장소 사본은 11-13이다. 저장소 마지막 cctv 커밋은 11-17 04:30 자동 기록이다.
   - 운영 저장소 규칙(AGENTS.md 39·49줄)상 원본은 `~/.hermes`이고, 매일 04:30 `./sync --commit`이 모은다. 따라서 이 차이는 정상적인 미동기 상태다.
   - `diff -rq`로 보니 `lib/hermes_reply`, `report_status.py`, `tests/`는 사본과 원본이 같다(`.pytest_cache`만 다름).
5. **원인 분류:** 계획 결함이다. 시작 일치 조건을 team-kit 전체로 너무 넓게 잡았다. 구현 결함이 아니다.
6. **보완:** 보완 47이다. 대조 범위를 TASK-49가 바꾸는 범위로 좁히고, 마지막에 패치가 운영 원본 복사본에 그대로 적용되는지 확인한다.
7. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: N48-01·02 (2026-11-17)

1. **판정:** 완료(`f0367ecc990dc38a3f64a830223d7f2163de852f`, 파일 5개). 차단 결함은 없다. 지적도 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 보완 46과 같다.
   - 승인·확인 결과는 `platform.telegram.{approval|slash_confirm}.resolved_{응답}`의 이름 없는 공식 낱말이다. 승인은 once·session·always·deny, 확인은 once·always·cancel이며, 모두 ko.yaml에 있다.
   - clarify 결과는 Slack 낱말과 `user="나"`를 그대로 쓴다.
   - `send_video`는 `**kwargs`를 받아 `send_document`로 넘긴다.
   - 새 문구는 없다.
4. **직접 확인한 것**
   - 깨끗한 worktree(f0367ec)에서 `test_delivery_parity.py`를 다시 실행했다. 종료 0, 24 passed.
   - `.build/n48/foundation.log`: 232 passed.
5. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-49다.

---

## 검증 판정: TASK-48 문 Slack 경로 동등 (2026-11-17)

1. **판정:** TASK-48 완료(`d4677990806f9428d7070b25f4c81a99962a3740`, 파일 10개). 증거 수준은 2/2다. 차단 결함은 없다. 비차단 지적 N48-01(문구)과 N48-02(호환)가 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. Hermes 본체는 읽기만 했다(base.py·ko.yaml).
3. **설계 적합성(4.2):** REQ-HF-42.AC-01과 대조표 2.1판 I01~I06을 충족한다.
   - I01 앞 글 문맥
     - 1:1에서 단체방·분기가 아니고, 공식 `_session_store.lookup_by_session_key`에 세션이 없거나 중단된 상태일 때만 `channel_context`에 `[이전 스레드 대화]`를 넣는다.
     - 한도는 50줄·16,000자·줄당 2,000자다.
     - 분기 문맥과 겹쳐 들어가지 않는다.
     - 따로 영구 사본을 두지 않는다.
   - I02·I03 긴 글
     - `splits_long_messages = True`를 선언했다.
     - `split_text`는 UTF-8 바이트 한도 안에서 줄 경계를 우선해 자르고, 내용이 빠지지 않는다.
     - 버튼·체크리스트·상태는 마지막 조각에만 붙는다.
     - 흘러나오는 편집이 넘치면 조각을 이어 붙이고, 줄어들면 남는 조각을 `delete`한다.
     - 기록이 실패하면 이미 쓴 조각을 남기고 seq에 빈칸이 생기지 않는다.
   - I04 단추 낱말: 기본 단추 낱말은 `agent.i18n.t`를 쓴다(Slack 낱말표).
   - I05 누른 뒤
     - 결과 줄을 덧붙여 `edit final`하고 단추를 비운다.
     - 다시 누르면 잠금 안에서 조용히 무시한다.
     - 권한 확인과 resolver는 그대로다.
   - I06 첨부
     - `send_image`는 Hermes `tools.url_safety`로 넘겨주기 대상까지 SSRF를 검사한다. `image/*`만 받고, 받은 파일은 기존 `files.stage` 한도를 따른다.
     - 실패하면 공식 문구로 글을 보낸다.
     - `send_voice`·`send_video`는 `send_document`로 보낸다.
   - 규격 변경과 새 영구 원본은 없다. 편집 조각 목록은 메모리에만 있다. 재시작 뒤 옛 흐름이 이어지지 않는 것은 보고서에 적힌 한계로 받아들인다.
4. **직접 확인한 것**
   - 깨끗한 worktree(d467799)에서 `test_delivery_parity.py`를 다시 실행했다. 종료 0, 14 passed.
   - `.build/task48/foundation.log`: 222 passed.
   - `mutation.json`: 바이트 나누기를 지운 사본이 검출됐다.
   - 원본 대조 시험(`task48-reference-final`)은 실행 담당 기록으로 확인했다(1 passed).
5. **지적**
   - N48-01(비차단, 문구)
     - `buttons.decision`이 Slack 낱말 `{user}이(가) …`에 `user="나"`를 넣는다.
     - 결과 줄이 "✅ 나이(가) 한 번 승인했어요"로 문법이 틀린다.
     - 22판 규칙 "Slack 전용 구절 빼기"에 따라, Hermes 공식 낱말표에서 이름 없는 낱말(telegram 구획 `resolved_*`)을 쓴다. 보완 46이다.
   - N48-02(비차단, 호환): `send_video`에 `**kwargs`가 없어 Hermes 기반 서명과 다르다. 지금 Hermes 호출부는 추가 인자를 넘기지 않는다.
6. **원인 분류:** N48-01은 문구 변환 규칙을 적용하지 않은 구현 누락이다. N48-02는 구현 누락이다.
7. **남은 위험:** 실제 정기 보고 나누기, 실제 Hermes 승인 단추는 0.2.x 운영 반영 때 실물로 확인한다.
8. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: N33-01 publish 초안 조회 (2026-11-17)

1. **판정:** N33-01 수정 완료(`96ec311362c63fa8d0f1b823492671611d2e408d`, 파일 3개).
   - TASK-33은 고위험 상한이라 부분 완료로 둔다.
   - 남은 것은 사장의 공개(publish)와 두 Mac 실물(TASK-23)이다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 보완 44와 REQ-HF-33.AC-02를 충족한다.
   - 업로드 뒤의 두 조회는 `gh api repos/{repo}/releases --paginate --slurp` 목록에서 `tag_name`이 같고 `draft`가 참인 것을 정확히 하나 고른다. 0개나 2개 이상이면 초안을 남기고 멈춘다.
   - 만들기 전에 같은 태그의 초안이 있으면 지정 문구로 멈춘다. 지우거나 덮어쓰지 않는다.
   - 앱·문·통신 규격은 바뀌지 않았다.
   - 로컬 `gh` 2.102.0의 `api --help`에 `--slurp`가 있다.
4. **직접 확인한 것**
   - 깨끗한 worktree(96ec311)에서 `test_ship.py`를 다시 실행했다. 종료 0, 17 passed.
   - `mutation.json`
     - 조회를 다시 태그 경로로 되돌리면 종료 1로 검출된다.
     - 바꾸지 않은 사본은 종료 0이다.
   - `final-verification.json`
     - 공개본 `f716bdf`와 구현 커밋의 트리가 `0f048f0`으로 같다.
     - 원격 호출·쓰기 0, 개인 이력 없음, 배포 압축 서명 검증 통과, 운영 반영 없음.
     - 전체 종료 0이고, 실행 담당 보고로는 208 passed다.
   - 로컬 가지: `public`은 `f716bdf`(부모는 0.1.0 `f90bf08`)이고, 앞 후보는 `archive/task33-before-n33-01`에 있다.
5. **지적:** 없음.
6. **사장 차례(0.2.x 운영 반영 때)**
   - `aeaa652` 기준 새 롤백 백업을 만든다.
   - public `f716bdf`를 github main에 푸시한다(플러그인 승인).
   - `install/hejo-ship publish --approve-commit f716bdff38af3d8c2cb2cdf4502e080ecbecb2bc --prepared .build/n33-01/prepared/prepared.json`을 실행한다.
   - 두 Mac에 손으로 설치한다.
7. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-33 앱 자동 업데이트·배포 준비 (2026-11-17)

1. **판정:** 부분 완료. 구현은 `1675529eb4f377f04cda2c370db0c581c116e489`(25개 파일), 공개본은 `09157e983896599b19a741e601728ea943f5a04a`이고 두 커밋의 트리가 같다.
   - 앱 쪽(AC-01·AC-03)은 충족한다.
   - 배포 도구(AC-02)의 `publish`에 결함 N33-01이 있다. 초안 조회 방식 때문에 사장이 publish를 실행해도 공개되지 않는다.
   - 고위험이라 상한도 부분 완료다. 두 Mac 실물 업데이트는 TASK-23에서 본다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. 코드는 정적으로 읽었고, 실행 담당의 로그를 직접 확인했다.
3. **설계 적합성(4.2)**
   - 확인 시점
     - `/Applications`에 있을 때만 확인한다(`LoginLaunch.isInstalled`).
     - 첫 확인은 30초 뒤, 그 뒤 6시간마다다.
     - 수동 확인은 "오늘 다시 보지 않음"이나 알림 끔과 상관없이 된다(`UpdateNoticePolicy`).
     - 설치 위치가 아니면 안내 문구를 원문대로 보인다.
   - 묻기 창: 제목, 설명, 버튼 3개("업데이트"·"오늘 다시 보지 않음"·"나중에"), Esc가 원문과 같다. "오늘 다시 보지 않음"은 다음 날 0시까지 쉬고, 버전을 건너뛰지 않는다.
   - 수동 업데이트
     - 찾아 둔 버전이 있으면 메뉴가 "업데이트 <버전> 설치…"가 되고, 일반 탭에는 "새 버전 <버전>이 있어요"와 "업데이트" 단추가 보인다. 누르면 묻지 않고 설치한다(`consented`).
     - 받는 중이면 `canCheck`가 거짓이고 `isBusy`로 다시 누름을 막는다.
     - 최신이면 "최신 버전이에요 (<버전>)"를 보인다.
     - 메뉴 "업데이트 확인…"은 버전 줄 바로 아래에 있다.
   - 받는 곳·검증
     - 공개 릴리스 API에서 초안·사전 릴리스를 거절한다. 자산은 이름이 맞는 것 하나씩만 받는다.
     - 공개 다운로드 주소가 정확히 일치해야 한다. 메타데이터 요청의 넘겨주기(redirect)는 거절한다.
     - Sparkle에서 주소·버전·크기·`application` 종류를 확인하고, 델타·노트 주소가 있으면 거절한다.
     - Info.plist에 `SURequireSignedFeed`·`SUVerifyUpdateBeforeExtraction`·`SUPublicEDKey`가 있다. 자동 확인과 자동 설치는 끈다.
     - 실패 문구는 ddots에서 용어만 바꿨다(원문 대조).
   - 설치 뒤 알림: 기대한 버전·빌드로 다시 실행됐을 때만 표식을 쓰고 펫 말풍선을 10초 보인다. 알림 센터는 쓰지 않는다.
   - 일반 탭의 "업데이트 알림 받기"는 기본으로 켜져 있다.
   - 옛 문: `supported-legacy-run.log`에 `AT84_OLD_GATE_NEW_APP_PASS`가 있다(aeaa652, 35판 결정대로).
   - 저장소 이름 `HejoUpdateRepository`는 이미 README·get-hejo에 있는 공개 저장소 주소라서 새 개인값이 아니다.
4. **직접 확인한 것**
   - `final-verification.json`
     - 전체 종료 0, 앱 10회, 입력 169개 불변.
     - 공개본에 개인 이력이 없고, 원격 쓰기 0, 배포 압축 서명 검증 통과, 운영 반영 없음.
   - `.build/foundation9-hejo.log`: `APP_TEST_OK`. 실행 담당 보고는 198 passed다.
   - `mutations.json`: 주소 허용 검사를 지우면 시험이 실패해서 검출됐다.
   - 이번 검토에서 시험을 다시 실행하지는 않았다. 코드 변경이 없고 증거 파일이 서로 맞는다.
5. **지적**
   - N33-01(결함, 차단: 공개 불가)
     - `hejo-ship publish`는 초안 상태를 `gh api repos/{repo}/releases/tags/{tag}`로 조회한다(200·210줄).
     - GitHub REST의 이 경로는 공개된 릴리스만 돌려주고, 초안이면 404다.
     - 그래서 업로드 뒤 늘 실패하고 초안만 남는다. 지우거나 덮어쓰지 않으니 안전 쪽 실패이지만, 0.2.0을 공개할 수 없다.
     - 시험의 `gh api` 대역이 경로와 상관없이 초안을 돌려줘서 드러나지 않았다.
6. **원인 분류:** 구현 결함 + 시험 대역이 실제 API 의미를 흉내 내지 않은 공백. 수정 계획은 handoff 보완 44다.
7. **남은 위험**
   - 실제 GitHub 릴리스·appcast·Sparkle 교체·다시 실행, 두 Mac 실물(TASK-23)이 남았다.
   - publish는 사장만 실행한다.
8. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-33 1차(보류 보고, D33-01) (2026-11-17)

1. **판정:** TASK-33 미완료.
   - 실행 담당이 D33-01로 보류했다. 커밋은 없고, 제품 파일은 기준 `bdffda2`로 되돌렸다.
   - 초안 19개는 `.build/task33/draft/`에 보존했다.
   - 작업 트리에는 보고 파일 2개(`copy-review.md`, `impl-report.md`)만 바뀌어 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 아직 판정하지 않는다. 초안이 제품에 적용되지 않았다.
   - 보고된 초안 범위는 다음과 같다: 30초·6시간 확인, 동의 창, 수동 버튼, 하루 숨기기, 주소·버전·크기 허용, Sparkle SDK 경계, 펫 알림, 0.2.0·빌드 2, hejo-ship.
   - 이 범위는 보완 36·REQ-HF-33과 맞는다. 정식 판정은 재개 결과에서 한다.
4. **직접 확인한 것**
   - `legacy-run.log`: `test_old_gate_new_app`이 종료 1로 실패했다. 옛 문은 `a4a80d5`다.
   - `hello-boundary.json`: `features`가 있으면 `invalid_frame`, 없으면 `welcome`이다.
   - `git log a4a80d5..aeaa652 -- gate/server.py`: `features`를 받는 처리는 `61a5548`(TASK-21)에 들어갔다. 운영 적용본 `aeaa652`의 `gate/server.py:373`도 `hello.get("features")`를 받는다.
   - `61a5548:app/Sources/GateClient.swift:118`: 0.1.0 앱도 이미 `features:["rooms"]`를 보낸다.
5. **원인 분류:** 계획 결함(기준 지정 오류).
   - 계획 담당이 보완 36에 옛 문 예시를 `a4a80d5`로 적었다. 이 문은 운영 중이 아니고, TASK-21 뒤로는 지원 밖이다.
   - 구현 결함이 아니다. 실행 담당이 계약을 마음대로 고치지 않고 멈춘 것은 맞는 처리였다.
6. **결정·보완:** 35판 보완 43.
   - 옛 문은 운영 공용 릴리스 `aeaa652`이고, 지원하는 가장 낮은 문은 `61a5548` 이후다.
   - 되돌림 연결은 만들지 않는다.
   - spec REQ-HF-33.AC-03과 AT-HF-84 문구를 갱신했다.
7. **운영 주의:** 롤백 자료 `task23-20261116-200307`(`a4a80d5`)은 지금 앱과 맞지 않는다. 0.2.x 반영 전에 `aeaa652` 기준으로 새로 백업한다.
8. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-35 세 손가락 탭 (2026-11-17)

1. **판정:** TASK-35 완료(`91956f5640bbffeb04a6a1c99aacdde2aec32cbb`, 16개 파일). 증거 수준은 2이며 필요 수준 2를 채웠다. 차단 결함은 없다. 비차단 지적 N35-01이 1건 있다(TASK-42로 넘김).
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. ddots 원본(`ThreeTap.swift`·`ThreeTapReader.swift`·`ThreeTapController.swift`, `App.swift:1369-1406, 1947, 1982`)과 줄 단위로 비교했다.
3. **설계 적합성(4.2):** REQ-HF-35.AC-01을 충족한다.
   - 판정 상수·실패 판정·Touch Bar 거르기(행 10 미만)·기기 확인·잠자기 뒤 다시 연결은 ddots와 같다. 바뀐 것은 시험 주입(리더 프로토콜·시계·기호 찾기)뿐이다.
   - `ThreeTap.swift`
     - Slack 보고용 `valid`·`slackText`만 뺐다.
     - 요청문의 ddots를 hejo로 바꿨다(22판 용어 규칙).
   - 컨트롤러
     - `UserDefaults` 대신 이 Mac의 `LocalStore`에 저장한다(Mac별 값이라는 같은 뜻).
     - `onFailure`(Slack·원격 보고)를 없앴다.
   - 앱 연결
     - 탭은 펫 클릭 경로로 간다. 펫이 숨었거나 쉬는 중이면 무시한다(ddots `panel.isVisible, !pet.resting`과 같음).
     - 설정 툴팁·흐림 조건은 ddots `refreshThreeTapSettings`와 같다.
     - 실패 창에는 "수정 요청문 복사"와 "닫기"만 있다.
   - 비공개 프레임워크는 dlopen으로만 연다. 직접 링크와 외부 보고가 없음은 `final-checks.json`에서 확인했다.
   - 기록해 둔 hejo 고유 차이
     - 설정 저장이 실패하면 "설정을 저장하지 못했어요…" 안내를 낸다. `LocalStore`는 실패할 수 있어서 생긴 안내이고, 뜻은 바꾸지 않는다.
     - 시작할 때 저장이 실패하면 앱 시작 실패로 이어진다. 다른 `LocalStore` 쓰기와 같은 정책이라 받아들인다.
4. **직접 확인한 것**
   - `.build/foundation9-hejo.log`: 191 passed, `AT-HF-86 APP PASS`, `APP_TEST_OK`. 앱 반복 10회 기록이 모두 종료 0이고 입력은 바뀌지 않았다.
   - AT86 단언 범위
     - 0.2초 탭, 0.4초 오래 누름, 네 손가락, 두 손가락, 움직임, 쿨다운을 본다.
     - 29번째 이상 프레임은 통과하고 30번째에서 실패한다. 정상 프레임이 오면 연속 수가 초기화된다.
     - 시계 되돌림, Touch Bar·빈 센서 거르기, 기기 교체 시 다시 연결, dlopen 실패, 기호 없음 1회 보고를 본다.
     - 트랙패드 없음 안내, 펫 클릭 경로로 열고 닫기, 쉬는 중·숨김일 때 무시, 잠자기 뒤 다시 연결을 본다.
     - 설정 끔 저장·복원, 찾아보기 안내 1회, 실패 시 리더 정지와 설정 흐림을 본다.
   - 돌연변이 기록(`.build/task35/mutations.json`): 탭 허용 시간 확대, 실패 한도 변경이 각각 종료 1로 검출됐다.
5. **지적**
   - N35-01(비차단, 범위 경계): ddots 설정 "고급" 탭의 "수정 요청문 복사" 단추가 hejo에 없다(D:App.swift:1401·1982). 고급 탭은 TASK-42(G02·G07)가 만들므로 그때 같이 넣는다(handoff 보완 42). 실패 창의 복사 단추가 있어서 AC-01은 충족한다.
6. **남은 위험:** 실제 트랙패드 탭, 실제 비공개 ABI, 기기 교체·잠자기 깨기는 TASK-23 실물 확인 때 본다.
7. **작업 56917a17 전체:** 부분 완료. 남은 것은 TASK-33(0.2.0), TASK-48, TASK-49, TASK-36~47, TASK-23 실물, 비설계자 검토, 푸시 승인이다.

---

## 검증 판정: N34-01 스레드 범위 중지 시험 (2026-11-17)

1. **판정:** N34-01 완료. 시험만 보강했다(`e94ee2f6d03fd2e1914d2604a6d9b7cac5b8f5f7`, `gate/tests/test_progress.py` +41). 제품 코드는 바뀌지 않았다. 차단 결함은 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. 깨끗한 임시 worktree에 시험 의존만 복사해 검토했다.
3. **설계 적합성(4.2):** 보완 39의 기대를 그대로 시험한다.
   - 같은 대화에서 A·B 두 스레드가 `final:false`로 흐르는 중에 A의 `thread_id`로 stop을 두 번 보낸다.
   - 새 edit는 A `final:true` 한 번뿐이다. A의 본문은 그대로 남는다.
   - B는 `final:false`이고 작성 중 등록도 남는다.
   - 기본 문과 보조 프로필 전달자 경로를 매개변수로 둘 다 시험한다.
4. **직접 확인한 것**
   - `foundation9_runner.py`(test_progress.py, e94ee2f): 종료 0, 7 passed.
   - 검토자 돌연변이(직접 실행, 원복 확인)
     - `stop_typing`의 `selected` 필터 제거 → primary·forwarder 2 failed, 검출.
     - 전달자 `_forward("stop_typing")` metadata를 `{}`로 되돌림 → forwarder 1 failed, 검출.
   - 실행 담당 돌연변이 기록 `.build/n34-01/mutations.json`과 일치한다.
5. **지적:** 없음.
6. **작업 56917a17 전체:** 부분 완료. 남은 것은 TASK-35, TASK-33(0.2.0), TASK-48, TASK-49, TASK-36~47, TASK-23 실물, 비설계자 검토, 푸시 승인이다.

---

## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-34 실물 지적 수정 (+ 작업 전체 현황)

1. **판정**
   - TASK-34: 완료. 범위는 REQ-HF-34.AC-01~07·09이고, AC-08은 33판 보완 38에 따라 TASK-38로 옮겼다. 증거 수준은 2이며 필요 수준 2를 채웠다. 차단 결함은 없다. 비차단 지적 N34-01이 1건 있다.
   - 작업 56917a17 전체: 부분 완료. 남은 것은 아래와 같다.
     - N34-01
     - TASK-35, TASK-33(0.2.0), TASK-36~47(33판)
     - TASK-23 실물: 0.2.0 운영 반영, 두 Mac에서 한글 입력기와 실제 차례 정리 확인
     - 비설계자 검토, 푸시 승인
2. **검증 조건**
   - 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5(계획 담당)다.
   - 검토한 코드는 `44ab635fdf7ac77fd095533888fb80035a94d83b`다. 깨끗한 임시 worktree에 시험 의존만 복사해 검토했다.
3. **설계 적합성(4.2):** REQ-HF-34.AC-01~07·09와 보완 37 추가 1~3을 충족한다.
   - 문 `stop_typing`
     - 끝내는 범위는 그 직원·그 대화·`metadata.thread_id` 스레드다. Hermes `_stop_typing_with_metadata`(base.py 3027~3035)가 스레드별로 부르는 계약에 맞다.
     - 범위 안에서 `final`이 아닌 글을 마지막 본문으로 `edit final:true` 한 번 닫는다. 기다리는 편집은 정리한다.
     - 전달자는 `thread_id`를 보존한다. `_forward`가 `hermes_profile`를 덧붙인다.
   - `delete_message`
     - 자기 직원·같은 대화의 직원 글만 보통 `delete`로 지운다(25판 종류, seq 연속).
     - 사장 글·남의 글·없는 글은 기록하지 않는다.
   - 앱
     - 작성기 줄: 스위치는 왼쪽, 얼굴은 오른쪽 가로 스크롤이고 세로 가운데에 맞췄다.
     - 작업 줄: 간격 9, 중지 단추는 초 표시 오른쪽 6pt.
     - `finalized` 글은 생각 중이어도 작성 중으로 세지 않는다.
     - DM 기본 이름은 "DM"이고 얼굴·사진은 그리지 않는다.
     - + 버튼은 표의 마지막 40pt 행이고, 검색 중에는 없다.
     - 방 이름은 자유 글 80자다. 문 `room_save`도 앞뒤 공백 정리만 해서 한글을 받는다. Slack 안내는 없앴다. 제목·설명 창은 `RoomDialogs.header`로 옮겼다.
   - 설치 도우미
     - `display.platforms.hejo.cleanup_progress: true`를 값이 없을 때만 넣는다.
     - 홈 채널과 같은 `owner_may_change` 영수증·키 단위 되돌림·`--check`(두 키 따로)를 쓴다. `--uninstall-home-channel`은 홈 키만 다룬다.
   - 범위: 운영 홈·공용 릴리스·public·원격은 바뀌지 않았다(`final-verification.json`과 일치).
4. **직접 확인한 것**
   - `foundation9_runner.py hejo`(44ab635, 깨끗한 worktree): 종료 0, 189 passed. AT-HF-85 APP PASS와 기존 가짜 Hermes·앱·통신 시험이 모두 통과했다.
   - 검토자 돌연변이
     - 문 `_finish_streams` 호출 제거 → `test_progress.py` 3 failed, 검출.
     - `delete_message` 주소 검사 무력화 → 2 failed, 검출.
     - 앱 중지 단추를 줄 끝으로 되돌림 → `AT85 stop follows elapsed by six` 실패, 검출.
     - `stop_typing`의 `thread_id` 필터 제거 → 5 passed, **잡히지 않음**(N34-01).
     - 전달자 metadata 보존 되돌림 → 5 passed, **잡히지 않음**(N34-01).
     - 모두 원복했다.
   - 캡처 `evidence/HEJO-FOUNDATION/task34-hejo.png`와 `task34-ddots.png`
     - 작성기 줄·작업 줄·DM·+ 위치가 ddots 조각과 같다.
     - 상단의 큰 재시도 숫자는 합성 시계 때문이라 비교에서 뺐다. 실행 담당이 보고서에 적은 대로다.
     - 접힌 구획 얼굴은 33판 V03에서 TASK-38이 되돌린다.
5. **지적**
   - N34-01(비차단, 시험 공백): 스레드 범위 `stop_typing`을 시험하지 않는다.
     - 경우: 같은 대화에서 두 스레드가 동시에 흘러나오는 중이고, 한 스레드의 `thread_id`로 stop이 온다.
     - 기대: 다른 스레드의 `final:false` 글을 닫지 않고, 그 스레드의 작성 중 표시도 남긴다.
     - 같은 경우를 보조 프로필 전달자 경로에서도 시험한다.
     - 필터를 빼도 지금 시험이 통과한다.
6. **남은 위험·운영 주의**
   - 실제 한국어 입력기 조합과 실제 Hermes 성공·실패 차례의 진행 글 지우기는 0.2.0 운영 반영 때 실물로 확인한다. 이때 계획 담당과 사장이 설치 도우미 재실행과 게이트웨이 재시작을 한다.
   - `.build/task38-start.patch`는 32판 움직임 초안이다. 33판 REQ-HF-36.AC-03을 만족한다는 뜻이 아니다.
7. **원인 분류:** 결함 아님. N34-01은 시험 보강이다.
8. **다음**
   - N34-01 시험 보강(실행 담당, 시험만)
   - TASK-35 → TASK-33(0.2.0) → TASK-36~47(보완 38 순서)
   - 0.2.0 운영 반영과 실물 확인(사장)
   - 비설계자 검토, 푸시 승인(사장)
