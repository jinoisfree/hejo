# 비설계자 독립 검토 — team-kit 패치 (2026-11-20)

검토 범위는 `review-request.md` "추가 범위"의 team-kit 패치 네 개다(`.build/task50` → `task52` → `task53` → `n52-02`). 설계·구현에 참여하지 않은 새 세션이 문서·패치·실제 코드만 읽고 썼다.

## 결론

- **차단 지적 0건, 비차단 지적 4건.**
- 네 질문 모두 "뚫리는 길"은 찾지 못했다. 찾은 것은 모두 **닫히는 쪽으로 틀린 것**(되어야 할 일이 거절됨)과 남는 예약 작업이다.
- 비차단 4건 가운데 IRT-01은 실제 Hermes 기본 어댑터 경로로 재현했다. 사장이 직원이 일하는 중에 보낸 글은 hejo 원문 증명을 받지 못한다.

## 검토 방법

- 운영 원본 `~/.hermes/plugin-store/team-kit`은 읽기만 했다. 패치가 건드린 파일 전부가 `.build/n52-02/team-kit` 사본과 바이트 단위로 같음을 확인했다(차이 0).
- 시험은 임시 폴더에 복사한 team-kit에서 게이트웨이 Python, 임시 `HERMES_HOME`, 가짜 명부로만 돌렸다. 임시 폴더는 검토 뒤 지웠다.
- hejo 관련 기존 시험 5개 파일(`test_owner_chat_hejo`·`test_owner_provenance_hejo`·`test_hejo_work_wait`·`test_hejo_session_proof`·`test_hejo_parity`): 255 통과, 1 건너뜀.
- 검토용 탐침 시험 11개를 임시 사본에만 더해 돌렸다(아래 지적의 "근거"에 출력 인용).
- 하지 않은 것: team-kit 시험 전체 실행(약 5천 개), 돌연변이 재실행, 운영 게이트웨이에서의 실물 확인. 비밀 파일·대화 본문·기록장은 열지 않았다.

파일 경로는 모두 team-kit 뿌리 기준이다. Hermes 본체 경로는 `CORE/`로 적는다.

## 지적

### IRT-01 (비차단, TASK-52·53·N52-02) — 직원이 일하는 중에 온 사장 글은 원문 증명이 항상 실패한다

- **파일:줄:** `lib/hermes_reply/plugin.py:507-508·528`(차례 묶음 `_HEJO_TURN` 설정·해제), `lib/hermes_owner_chat.py:39-43`(환경값과 묶인 사건 대조), `CORE/gateway/platforms/base.py:4754-4761·4825-4850`(대기 글을 새 작업으로 넘김).
- **실패 시나리오:** 사장이 hejo 스레드에 글 1을 보낸다 → 직원이 처리 중일 때 같은 스레드에 글 2("앞으로 이렇게 해 줘")를 보낸다 → Hermes가 글 2를 대기열에 넣고, 글 1 처리가 끝나면 **글 1을 처리하던 작업 안에서** 새 작업을 만들어 글 2를 처리한다 → 새 작업은 글 1의 `_HEJO_TURN` 묶음을 물려받는다 → 환경의 `HERMES_SESSION_MESSAGE_ID`는 글 2, 묶인 사건은 글 1이라 `current_owner_message`가 `None`을 돌려준다.
- **잘못된 결과:** 글 2 차례에서 `team_learn`(규칙 저장), `team_wait` 만들기·목록·취소, 업무 등록(`_task_capture_owner_chat`), 진단 기록(`owner_record`), 보고 상태 표시(`_hejo_status`), 기억 문맥(`_pre_owner`), 학습 안내(`learning.note`·`_lead_chat_policy`)가 모두 거절되거나 빠진다. 권한이 새지는 않는다(닫히는 쪽).
- **근거(실행):** 실제 문 어댑터 + `install_hejo` + 실제 기본 어댑터 대기열로 같은 스레드에 글 두 개를 보낸 탐침 결과.
  - 글 1: `event_id == env_id == bound_id`, `proof=True`
  - 글 2: `event_id = env_id = 4c9d6421…`, `bound_id = 2379c434…`(글 1), `proof=False`
- **시험이 못 잡는 이유:** 기존 시험의 `bound()` 도우미(`tests/test_owner_provenance_hejo.py:47-50`)는 항상 현재 사건과 같은 묶음을 직접 넣는다. 대기열을 거친 차례는 어디에도 없다.

### IRT-02 (비차단, TASK-53) — hejo 대기 작업은 만든 스레드에서만 보이고 정리된다

- **파일:줄:** `lib/hermes_team_services/wait_jobs.py:274-275`(`_matches_origin` 완전 일치), `:234-238`(prune), `:366-374`(목록·취소), `:302-303`(활성 10개 한도는 전체를 셈).
- **실패 시나리오 1(남는 예약 작업):** 사장이 hejo 스레드 A에서 대기를 건다 → 조건이 충족돼 결과가 전달된다(상태 `fired`) → 사장이 스레드 A에서 `team_wait`를 다시 부르지 않는다. 다른 hejo 스레드에서 부른 `team_wait`는 origin이 달라 이 작업을 건너뛴다 → 그 대기의 cron 작업이 지워지지 않고 10분마다 확인 스크립트를 계속 돈다. Slack에서는 아무 `team_wait` 호출이나 끝난 대기를 모두 정리한다.
- **실패 시나리오 2(안 보이는 한도):** 서로 다른 hejo 스레드에 활성 대기가 10개 있다 → 새 스레드에서 목록을 보면 비어 있고, 만들기는 `active_waits_limit_10`으로 거절되며, 다른 스레드의 대기 ID로 취소하면 `wait_not_found`다. 사장은 한도를 채운 대기를 hejo 새 스레드에서 보지도 지우지도 못한다.
- **근거(실행):** 탐침 출력 `list={'ok': True, 'active': [], 'recent': []} create={'ok': False, 'error': 'active_waits_limit_10'} cancel={'ok': False, 'error': 'wait_not_found'} removed=[]`.
- **참고:** 보완 66의 "다른 대화의 작업은 거절"을 따른 결과다. 결과가 다른 곳으로 새는 문제는 아니다.

### IRT-03 (비차단, N52-02) — `paseo_authority`에 환경 세션 ID 대조가 남아 있다

- **파일:줄:** `lib/hermes_governance/paseo_authority.py:48-53·59`.
- **실패 시나리오:** 보완 67은 `HERMES_SESSION_ID` 대조를 다른 hejo 원문 소비자에서도 함께 고치라고 했다. `paseo_authority.owner_text`는 여전히 환경의 `HERMES_SESSION_ID`가 비어 있으면 거절하고, 넘겨받은 `session_id`와 다르면 거절하며, 그 환경 ID로 `learning.source`를 부른다. N52-02 실경로 시험(`.build/n52-02/test_executor.py`)이 재현한 조건(도구 실행 문맥에서 환경 ID가 빈 값이거나 다른 세션 값)에서는 hejo에서 Paseo 권한 확인이 항상 실패한다.
- **근거(실행):** 같은 차례에서 환경 ID만 바꾼 탐침.
  - `HERMES_SESSION_ID='session-a'` → 통과
  - `''` → `Paseo requires a current Slack transport event`
  - `'other-profile-session'` → `Paseo session mismatch`
  - 세 경우 모두 `learning.source(home,'session-a')`는 통과(N52-02 수정이 적용된 쪽).
- **확인하지 못한 것:** 운영에서 Paseo 권한 확인이 불리는 문맥의 환경 ID 실제 값은 보지 않았다. 닫히는 쪽이라 권한 문제는 아니다. impl-report의 "paseo_authority는 기존 학습 원문 공급자를 통해 이 증명을 받는다"는 문장은 51-53줄 대조가 남아 있어 절반만 맞다.
- **시험이 못 잡는 이유:** `tests/test_owner_provenance_hejo.py:23`이 환경 ID를 `session_id`와 같게 고정한다(N52-02 때와 같은 약점).

### IRT-04 (비차단, TASK-53) — hejo에서는 글로 친 범위 선택이 받아들여지지 않는다

- **파일:줄:** `lib/hermes_packs/linked_work/work_capture.py:222-229`(hejo 갈래), `:26`(`authorized`가 선택 판정 전에 부름).
- **실패 시나리오:** 직원이 "메모 / 메모+노션 / 확인"을 묻는다 → 사장이 버튼을 누르지 않고 "메모+노션"이라고 직접 친다 → 그 글에는 `answer_to`가 없어 `_answered_message`가 `WORK_SCOPE_TARGET_UNBOUND`를 던진다. Slack 갈래는 같은 상황에서 바로 앞 직원 글을 찾아 선택을 인정한다(`work_capture.py:230-251`).
- **근거(실행):** 탐침 출력 `typed -> WORK_SCOPE_TARGET_UNBOUND`. 기존 시험 `no-answer`(`tests/test_hejo_work_wait.py`)도 같은 결과를 기대값으로 둔다.
- **참고:** 보완 66이 정한 대로다(직원 글은 `answer_to`로만 인정). 다만 Slack(ddots)과 다른 동작이므로 사장 선택 차이로 기록돼 있는지 계획 담당이 확인할 일이다. 오류 문구가 `WORK_SCOPE_CHOICE_REQUIRED`(다시 물어보라는 안내)가 아니라서 직원이 다시 버튼을 올리도록 유도되지 않는다.

## 질문별 답

### (1) 배경·예약·단발·Kanban 거절이 Slack과 같은 곳에서 유지되는가 — 유지된다

- Hermes cron은 실행 문맥에서 `HERMES_SESSION_PLATFORM`·`CHAT_ID`를 빈 값으로 놓고 origin을 환경에 넣지 않는다(`CORE/cron/scheduler.py:2363-2379`). hejo origin에 `user_id: owner`가 들어 있어도 cron 실행은 사장 대화로 보이지 않는다.
- TASK-50이 바꾼 판정 약 30곳은 `{'slack','photon'}` 글자를 `OWNER_CHAT_PLATFORMS`로 바꾼 것뿐이고, 각 자리의 배경 검사(`background(...)`, 세 플래그 검사)는 그대로다. 패치 전후 문맥 줄을 하나씩 대조했다.
- 새 공용 함수 `authenticated_owner`(`lib/hermes_owner_chat.py:9-23`)는 세 플래그와 배경 검토를 먼저 거절한다. `current_owner_message`는 이 함수를 거치고 `_HEJO_TURN` 묶음이 없으면 `None`이다(cron·Kanban·단발에는 묶음이 없다).
- **실행 근거:** `HERMES_CRON_SESSION=1`·`yes`, `HERMES_SINGLE_QUERY_SESSION=1`·`true`, `HERMES_KANBAN_TASK=t1` 다섯 경우에 `authenticated_owner`·`current_owner_message`·`current_owner_message_in_session`·`_task_capture_owner_chat`·`_pre_owner`·`write_policy.owner_chat`·`learning.source`·`request_source.text`·`mail_read.authorize`·`wait_jobs.create`·`wait_jobs.handle(list)` 11개가 모두 거절됐다.
- 문은 사장 글 한 곳에서만 사건을 만든다(`gate/adapter.py:714·729`). 직원 글·방 전달·cron 결과가 `user_id=owner` 사건으로 들어오는 길은 없다.

### (2) 원문·세션 증명이 가짜로 채워지는가 — 채워지는 길을 찾지 못했다

- **가짜 글자:** 원문은 세션 DB content가 아니라 문 기록장의 `text`다(`gate/adapter.py:527-546`). chat·thread·msg_id는 도구 인자가 아니라 세션 환경과 묶인 사건에서만 온다. 시험 고정물은 DB에 가짜 Slack 머리글 본문을 일부러 넣어 두고 원문이 그것과 다름을 본다.
- **다른 방·다른 스레드:** 문이 `thread`·`chat_id`·1:1 직원·방 수신자(`_meta.recipients`)를 검사하고, team-kit이 결과의 `msg_id`·`chat_id`·`thread_id`를 다시 대조한다(`lib/hermes_owner_chat.py:57-59`).
- **다른 직원 글:** `employee_message`는 `role=employee`·`employee==profile`만 돌려주고(`gate/adapter.py:548-563`), team-kit이 `result['employee'] != profile`을 다시 거절한다(`lib/hermes_owner_chat.py:84-87`). `answer_to`는 서버가 버튼 누름에서만 넣는다(`gate/adapter.py:658`).
- **지운 글:** `journal.message`가 없으면 `None` → 닫힌다.
- **다른 세션의 msg_id:** `current_owner_message_in_session`은 넘겨받은 `session_id`에 현재 사건 msg_id를 가진 살아 있는 user 행이 있어야 한다(`lib/hermes_owner_chat.py:96-115`). 하위 에이전트 세션에는 그 행이 없어 거절된다.
- **forwarder:** `_forward`가 프로필을 호출 인자가 아니라 `self._owner_profile`로 고정한다(`gate/adapter.py:94-95`).
- **followup:** hejo에서는 `followup_rows`가 빈 목록이다(`lib/hermes_team_services/learning.py:266-270`). 묶이지 않은 steer 글이 근거로 쓰이지 않는다.
- **버튼 라벨:** 버튼을 누르면 사장 글의 본문이 직원이 정한 라벨(30자 이하)이 된다. Slack 갈래도 같은 방식이라 차이가 아니다.

### (3) 대기 작업 결과가 만든 hejo 대화 밖으로 가는가 — 가지 않는다

- origin은 증명된 원문의 chat·thread와 현재 프로필에서만 만든다(`wait_jobs.py:263-271`). 프로필이 `home`의 프로필과 다르면 거절한다.
- `create_job`은 `deliver="origin"`과 그 origin을 그대로 넘긴다(`wait_jobs.py:218-221`). Hermes는 origin에 platform·chat_id가 있으면 그 대상 하나만 고른다(`CORE/cron/scheduler_delivery.py:634-640`). 홈 채널 대체는 origin이 없을 때만이다(`:641-650`). Slack 전용 "오래된 스레드" 보정은 hejo에 적용되지 않는다(`:580-588`).
- 전달 실패 때는 같은 대상으로만 다시 시도하고 오류를 남긴다. 다른 플랫폼으로 넘기는 코드는 없다. 기존 시험 `test_real_cron_delivery_stays_in_hejo_origin_and_records_failure`가 가짜 Slack 어댑터를 함께 두고 Slack 전송 0건을 본다.
- 보조 프로필의 forwarder는 1:1 전송의 chat을 자기 프로필로 고정한다(`gate/adapter.py:108`). 다른 직원 1:1로 갈 수 없다.
- hejo 세션에서 목록·취소·정리는 같은 origin만 건드린다(IRT-02는 이 범위가 좁아서 생긴 부작용이다).

### (4) Slack 전용이어야 할 경계가 hejo에 열렸는가 — 열리지 않았다

- **금고 백업 승인:** `lib/hermes_team_services/vault_backup_approval.py:148·241`이 `platform != "slack"`을 그대로 거절한다. 네 패치 모두 이 파일을 건드리지 않는다.
- **CCTV 기준 방:** `lib/hermes_packs/cctv/reference.py:178`이 `owner_chat` 통과 뒤에도 `!= 'slack'`을 거절한다. 뒤의 `learning.source` 호출(`:188`)은 이 검사 다음이라 hejo에서 닿지 않는다.
- **Slack 사용량 조회:** `lib/hermes_packs/native_tools/__init__.py:81`이 `platform != "slack"`을 거절한다.
- **참고:** `learning.source`가 환경값으로 hejo 갈래를 타므로, D51-01 목록에 이름이 없는 읽기 도구(`cron_status`·`news_watch_read`·`deadline_watch`·`morning_report` 다시 보기 등)도 hejo에서 원문 증명만 통과하면 열린다. D51-01이 `learning.source`를 "나"로 정했으므로 결정 범위 안으로 봤다.

## 확인했지만 문제없는 항목

- 운영 원본과 패치 사본 일치: 네 패치가 건드린 파일 전부 `cmp` 차이 0.
- `write_policy.owner_chat`의 hejo 갈래(`user == 'owner'`): 배경 검사와 chat_id 검사 뒤에 있다.
- `approval.py` 개인 workspace 쓰기: 배경·진단 요청 거절 뒤, `selected_skills.owner_chat`(slack·hejo만)과 `authenticated_owner`를 모두 통과해야 한다. photon은 앞 조건에서 걸러진다.
- `mail_read.authorize`·Notion `conversation()`·`work_guidance.context`: 모두 플래그 검사 뒤 `authenticated_owner`를 쓴다. Slack 허용 목록에 `owner`가 섞이지 않는다.
- `work_capture.transition`의 hejo 시각 비교: UUID가 아니라 문이 찍은 `ts`를 쓰고, Slack 값과 따로 보관한다.
- `diagnosis_records.owner_record`: hejo 값을 Slack ts 칸에 넣지 않고 Slack 링크 파서를 타지 않는다.
- cron 전달 뒤 세션 미러(`attach_to_session`): 미러 행에는 `platform_message_id`가 없어 원문 증명의 user 행으로 쓰일 수 없다.
- `hejo_source`가 방 대화도 `chat_type: 'dm'`으로 돌려준다(`learning.py:216`): 문이 방도 `dm`으로 보내고 D50-01이 방을 사장 대화로 정했으므로 결정대로다. Slack의 "DM 또는 보고 방" 제한이 hejo 방에는 걸리지 않는다는 점만 적어 둔다.
- `conversation_recall`에 hejo 세션 포함: 출처가 `hejo`인 세션만 더해지고 도구·cron·Kanban 세션은 여전히 빠진다.

## 확인하지 못한 것

- 차례 시작 때 user 행이 `platform_message_id`와 함께 저장되는 시점과 `pre_llm_call` 훅의 순서. hejo의 `_pre_owner`는 그 행이 있어야 통과하므로, 순서가 반대면 hejo에서 기억 문맥이 항상 빠진다. 보완 68의 운영 확인은 `team_learn`(도구 시점)만 봤다.
- `_lead_chat_policy`·`learning.note`가 게이트웨이 이벤트 루프 스레드에서 불리는지. 그 스레드에서 불리면 `current_owner_message`가 `None`을 돌려준다(`lib/hermes_owner_chat.py:48-49`).
- 운영 게이트웨이에서의 실제 대기 작업 전달과 IRT-01의 실물 재현.

## TASK별 결론

| TASK | 결론 |
|---|---|
| TASK-50 (사장 대화 판정 공용화) | 통과 |
| TASK-52 (사장 인증·원문 공급자) | 지적 있음 — IRT-01, IRT-03 (비차단) |
| TASK-53 (업무 선택·진단 출처·대기 작업) | 지적 있음 — IRT-01, IRT-02, IRT-04 (비차단) |
| N52-02 (세션 증명) | 지적 있음 — IRT-01, IRT-03 (비차단) |
