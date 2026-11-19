## 검증 판정: 보완 68 — N34-03 진행 글 정리 실경로 (2026-11-20)

1. **판정:** 코드 통과, 수준 2/2. 운영 적용(공용 릴리스 갱신·재시작)과 보조 프로필 실물이 남는다. 지적 없음.
   - 결과는 2026-11-19 20:58 커밋 `d5c9133`으로 끝나 있었으나 이 대화로 전달되지 않아 검토가 늦었다(사장 지적 뒤 확인).
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:**
   - 원인(`impl-report` 보완 68 3항, `baseline-trace.json`): 실제 경로의 정리 어댑터는 수신한 **기본 문**이고, 기본 문 `delete_message`가 글 주인을 `default`로 고정해 보조 직원 글 삭제를 거절했다. 보완 67의 콜백 넘김은 이 경로를 지나지 않았다.
   - 수정(`gate/adapter.py` diff): 수신 차례마다 ContextVar `_delivery_scope=(대상 직원, chat, thread)`를 설정하고 finally로 복원. 범위가 있으면 삭제는 그 직원·chat·thread의 role=employee 글만 허용. 영구 저장·wire·본체·team-kit 변경 없음.
   - 시험: `test_gateway_progress.py`가 실제 `start_gateway`부터 post-delivery까지(가짜 모델만) 기본·보조 × 성공·실패 4경우. 수정 전 문으로 `baseline.log` 1 failed(보조 성공만 남음), 수정 뒤 `foundation9-n34-fixed.log` 1 passed, 경계 13 passed, 돌연변이(삭제 False 고정) 검출, foundation 257 passed.
4. **설계 적합성(4.2):** 보완 68 그대로(실경로 재현 → 수정 전 실패 증명 → 문에서 수정). D34-03(본체 순서 문제) 아님.
5. **운영 적용 범위:** 문 코드만(공용 릴리스 갱신 + 재시작). `d5c9133..HEAD`에는 gate·hub·schemas·install·config 변경이 없다.

---

## 검증 판정: 보완 67 — N52-02 학습 세션 증명, N34-02 보조 프로필 진행 글 정리 (2026-11-19)

1. **판정:** 코드 통과, 수준 2/2. 운영 적용·실물(사장 hejo에서 규칙 저장·진행 글 사라짐) 남음. 지적 없음.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:**
   - `gate/adapter.py`(`8b4e188..518d67f`): 보조(forwarder) 문의 `register/pop_post_delivery_callback`을 기본 문 보관함으로 넘긴다. 수신·최종 전달을 기본 문이 맡기 때문에 콜백이 그곳에서 꺼내져야 진행 글이 지워진다. 세션 키는 프로필마다 달라 섞이지 않는다.
   - team-kit 패치 `.build/n52-02/team-kit.patch` sha256 `1e79f114…77f6`(재계산 일치), 7파일. 새 `current_owner_message_in_session`은 공개 원문 증명 뒤 `session_id`+`role=user`+`platform_message_id=문 msg_id`인 비압축 행 존재로 세션을 증명(본문 안 읽음, query_only). 환경 `HERMES_SESSION_ID` 대조는 학습·진단·보고 상태·기억 문맥에서 모두 빠졌다.
   - 로그: 실제 executor 경로 시험 수정본 3 passed / 수정 전 1 failed(운영 오류 재현), 진행 글 11 passed, team-kit full 5087 passed, foundation 254 passed, 돌연변이 2종(세션 증명 제거·보조 콜백 전달 제거) 검출.
4. **설계 적합성(4.2):** 보완 67 방향 그대로. 원문은 문 공개 조회, 세션은 DB 행 존재로만 증명하고 Hermes 본체는 바꾸지 않았다.
5. **원인 분류:** N52-02는 시험이 실제 실행 경로를 흉내 내지 못한 것(계획 단계에서 실제 경로 시험을 요구하지 않음 — 계획 담당 몫). N34-02는 TASK-34 시험이 기본 문만 덮은 것.

---

## 검증 판정: TASK-53 업무 캡처·진단·대기 작업 hejo 원문 증명 (2026-11-19)

1. **판정:** 부분 완료(고위험 상한). 코드 통과, 인계 수준 2/2. TASK-52·53 운영 적용과 실물(수준 3)이 남는다. 지적 없음.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:**
   - `gate/adapter.py` diff(`3305387..8de89b9`): `employee_message`는 role=employee·employee=profile·thread·chat 일치·살아 있는 방만 통과, forwarder는 자기 `_owner_profile`로 고정.
   - team-kit 패치 sha256 `38a66b3a…e8ad`(재계산 일치), 6파일. `answered_employee_message`는 TASK-52 현재 사장 원문의 `answer_to`만 따라가고 응답의 직원·msg·chat·thread를 다시 대조. `work_capture`는 hejo에서 UUID를 Decimal로 쓰지 않고 원문 ts로 순서를 잡으며 Slack 워터마크와 분리. `wait_jobs`는 hejo origin(platform·profile·chat·thread)을 저장하고 목록·취소·prune을 같은 origin으로 제한, Slack 정규식은 Slack 갈래에만.
   - 로그: team-kit full 5080 passed, foundation 250 passed·APP_TEST_FAILED 없음, 돌연변이 3종(origin Slack 고정·Slack 대체 전송·직원 일치 제거) 모두 검출, 두 패치 순서 dry-run 0.
4. **설계 적합성(4.2):** 보완 66과 D51-01을 따른다. 원문·직원 글은 문 공개 조회로만, 다른 방·Slack 대체 전송 없음. hejo에서는 같은 대화에서 건 대기 작업만 보이는 보수적 선택(Slack에서 건 작업은 Slack에서 관리)이다.
5. **남은 것:** 운영 적용(공용 릴리스 갱신 — 문 코드 변경 포함, team-kit 패치 TASK-52 → TASK-53, 재시작, 계획 담당+사장) 뒤 실물: hejo에서 메일 읽기·학습 규칙 말하기·답 버튼으로 업무 지정·대기 작업 걸기.

---

## 검증 판정: N52-01 AT-96 시험 대기 (2026-11-19)

1. **판정:** N52-01 완료. TASK-52는 인계 수준 2 통과, 고위험이라 운영 적용·실물(수준 3) 뒤 완료.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:** `fb779ef` diff — 시험 파일만, `pause(0.12)`·`pause(0.3)`을 같은 조건의 `waitFor(3)`로 바꾸고 기존 단언은 그대로 남김. `n52-01/foundation-01.log`·`02.log` 각각 248 passed, `APP_TEST_FAILED` 0건, 실제 다운로드 이름 불변. team-kit 패치 sha256 `660142a0…6ee5` 그대로.
4. **설계 적합성(4.2):** 제품 코드 무변경, 보완 65 범위 그대로.
5. **다음:** TASK-53(보완 66). 운영 적용은 TASK-52·53을 함께 한 번에 한다(재시작 1회).

---

## 검증 판정: TASK-52 hejo 사장 인증·원문 증명 (2026-11-19)

1. **판정:** 부분 완료. 코드(`5fb0407` 문 + team-kit 패치 sha256 `660142a0…6ee5`, 12파일)는 통과. 필수 전체 검증(foundation9_runner hejo)이 AT-96 시험 하나로 종료 1이라 N52-01을 고친 뒤 완료한다.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:**
   - `gate/adapter.py` diff 전체: 수신 `build_source(..., message_id=msg_id)`, 공개 `owner_message`는 role=owner·thread·chat 일치·1:1 employee=profile·방은 살아 있는 방+`_meta.recipients`에 profile 포함만 통과. `journal.message()`는 행 전체 deepcopy라 `_meta`가 남는다(`gate/journal.py:171-184`). forwarder는 자기 `_owner_profile`로 기본 문에 묻는다.
   - team-kit `hermes_owner_chat.py`: `authenticated_owner`는 Slack·photon 기존 owner 검사를 호출자에게서 받고 hejo는 owner+chat, 배경 플래그·background review 거절. `current_owner_message`는 환경값만이 아니라 TASK-49의 ContextVar 수신 사건(`hermes_reply/plugin.py:326-330,508-528`)과 PROFILE·CHAT·THREAD·MESSAGE_ID가 모두 일치할 때만 문에 묻고, 응답도 다시 대조한다. 같은 루프 스레드에서 부르면 None(실패 폐쇄).
   - 로그: full 5058 passed, 돌연변이 3종(사용자 검사·방 수신자·DB content 대체) 검출, dry-run 0.
   - **AT-96:** 앱 소스는 바뀌지 않았다. 계획 담당이 같은 바이너리로 `web_pane_fixture.py`를 3회 단독 실행 → 3회 모두 `WEB_FIXTURE_PASS`. `WebPaneTests.swift:70-72`가 고정 0.3초 쉰 뒤 탭 줄 스크롤을 단언해 부하가 걸린 전체 실행에서 늦게 끝나는 시험 결함이다(제품 결함 아님).
4. **설계 적합성(4.2):** D51-01·보완 64를 따른다. 원문은 문 공개 `owner_message`로만 얻고 세션 DB content·문 내부 import를 쓰지 않는다. 프로젝트 영수증·학습 보고 위치·다 항목은 유지.
5. **N52-01(시험, 비차단 제품/차단 검증):** AT-96 탭 스크롤 단언을 `waitFor`(최대 3초)로 바꾼다. 보완 65.
6. **TASK-53 메모:** 구현 담당 지적대로 `learning.source`가 hejo를 받게 되면서 `wait_jobs` list/cancel·prune 입구가 hejo 사장 대화에서 열린다. 사장이 자기 대기 작업을 보거나 취소하는 것이라 권한상 문제는 아니나, Slack 출처 작업을 hejo에서 다룰 때 결과 전달 위치가 맞는지 TASK-53에서 확인한다.

---

## 검증 판정: TASK-51 D50-02 조사 (2026-11-19)

1. **판정:** 완료(조사 단계). 코드 변경 없음, 커밋 `4eb68a1`은 impl-report 10줄.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:** `survey.md` 147줄 전체를 읽었다. 핵심 주장 하나를 코드로 재확인했다: `gate/adapter.py:649`의 `build_source`에 `message_id`가 없고(Hermes `base.py:4916-4924`는 받는 인자가 있음), msg_id는 `MessageEvent.message_id`(:662)로만 간다. 세션 DB 조사는 집계만(본문·식별자 값 없음), immutable·query_only로 했다.
4. **설계 적합성(4.2):** 보완 63 범위(읽기 전용·제안만)를 지켰다. D50-01의 배경 거절 유지, 가짜 사장 글 차단 목적을 항목마다 따졌다. 이전 분류의 잘못된 요약(Notion·native_tools·approval helper)을 바로잡았다.
5. **결정:** 보완 64(D51-01)로 가/나/다를 확정하고 TASK-52·53으로 나눈다.

---

## 검증 판정: TASK-50 team-kit 사장 대화 판정에 hejo 포함 (2026-11-18)

1. **판정:** 부분 완료(고위험 상한). 패치는 통과, 인계 수준 2/2. 운영 적용·실물(수준 3)이 남는다. 차단 결함 없음.
   - 패치 `.build/task50/team-kit.patch` sha256 `70597129…2398`(직접 재계산 일치), 15개 파일. hejo 커밋 `96e221c`는 보고 두 파일뿐, public `1dfda64` 불변.
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **직접 확인:**
   - 패치 본문 전체를 읽었다. 새 `lib/hermes_owner_chat.py`의 `OWNER_CHAT_PLATFORMS = {slack, photon, hejo}` 한 곳으로 26개 판정을 바꿨다. 각 판정의 chat_id·user_id·배경·역할·계정 범위 검사는 그대로 남았다.
   - `write_policy.owner_chat`: hejo는 `user == 'owner'`만 통과(문이 내는 유일한 신원, `gate/adapter.py:649·662`).
   - 원래 문제 줄 `mail/__init__.py:540`이 바뀌었고, 재현 시험 `test_mail_other_account_read_reproduction`이 slack·photon·hejo × 배경 플래그 3종 × 빈 chat_id를 덮는다.
   - team-delegation의 `lib`은 team-kit `lib` 전체 링크라 새 모듈을 같이 본다.
   - 운영 원본에 `patch -p1 --dry-run` 종료 0, 운영 원본에 새 파일 없음(미적용).
   - 로그: `full.log` 5024 passed·5 skipped, `mutations.json` hejo 제거·배경 검사 제거 둘 다 검출, 정상 0.
4. **설계 적합성(4.2):** D50-01(hejo 대화 = 사장 대화, 배경 거절 유지)과 보완 62 분류 원칙을 따른다. 라우터 ingress·사용량·연결 점검 등 플랫폼 전용 코드는 유지하고 이유를 `classification.md`에 적었다.
5. **D50-02(사장 결정 필요, 결함 아님):** Slack 원문 증명에 묶인 기능은 hejo에서 아직 안 된다(`d50-02.json` 재현).
   - 기다림 작업(`wait_jobs` owner_slack_thread_required), 요청 원문 증명(`request_source`·`work_guidance`·`learning`·`memory_live`), 금고 백업 승인 버튼(`vault_backup_approval`), 개인 조회 인증(`mail_read.authorize`), Notion 대화 연결.
   - 이것들은 Slack API로 원문을 다시 확인하는 구조라 hejo 기록장으로 증명하는 새 설계가 필요하다(TASK-51 후보).
6. **남은 것:** 운영 적용(백업 → patch → team-kit 시험 → 재시작, 계획 담당+사장), hejo에서 다른 계정 메일 읽기 실물, D50-02 결정.

---

## 검증 판정: 보완 61 — 0.2.0 공개 후보 재생성 (2026-11-18)

1. **판정:** 보완 61 완료. 차단 결함·지적 없음. 제품 코드 변경 없음(실행 커밋 `7c8ae5d`는 impl-report 10줄).
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5).
3. **계획 담당 직접 확인:**
   - public `1dfda649f14483acc5dd90f1f363e63904805b43`, 부모 `f90bf08`(0.1.0), 공개 계보 4커밋. `cd1b995`는 public 조상이 아니다(개인 이력 미포함).
   - 트리: public = main(`7c8ae5d`) = `1886a991…`, `git diff public main` 없음.
   - 보존: `archive/public-0.2.0-before-parity` = `f716bdf`, `archive/task33-before-n33-01` = `09157e9`.
   - 작성자: 이전 공개본과 같은 GitHub noreply 이름만 사용.
   - 준비물 `.build/release-0.2.0/`: zip SHA256 `3f856009…bf47`이 prepared.json과 같다. 새 임시 폴더에 풀어 `codesign --verify --deep --strict` 통과, 버전 0.2.0·빌드 2, BuildInfo tree `1886a991…`·dirty false.
   - 서명 키: 앱 SUPublicEDKey = prepared publicKey = 이전 후보(n33-01) publicKey. 기존 키 재사용이 맞다.
   - 로그 직접 확인: final-foundation `OK`·실제 CLI 설정 lstat 불변·실제 다운로드 이름 불변, legacy-aeaa652 `AT84_OLD_GATE_NEW_APP_PASS`·1 passed, app-repeat 1~3 모두 `APP_TEST_OK`, offline-gh는 로컬 캐시만(network false), final-verification remoteCalls/remoteWrites 0.
4. **설계 적합성(4.2):** 보완 61 절차(보존→hejo-publish 스냅샷→prepare→같은 트리 검증)와 REQ-HF-33(사장만 publish, 에이전트 원격 쓰기 금지), D33-01(옛 문 aeaa652 호환)을 따른다. 운영 홈·공용 릴리스·본체·ddots 변경 없음.
5. **참고:** 이 판정 문서 커밋 뒤 main은 public보다 문서만 앞선다. 공개본 재생성은 필요 없다.
6. **작업 56917a17 전체:** 부분 완료. 남은 것은 모두 사장 승인·실행이다.
   - public `1dfda64` → github main 푸시 승인(플러그인 화면)
   - 사장 publish: `install/hejo-ship publish --approve-commit 1dfda649f14483acc5dd90f1f363e63904805b43 --prepared .build/release-0.2.0/prepared.json`
   - 0.2.x 운영 반영(계획 담당+사장): aeaa652 기준 새 롤백 백업, 문·허브 갱신, team-kit 패치, 게이트웨이 재시작, 실물 점검(보완 49·57·60, TASK-47 훅, TASK-23)
   - 비설계자 검토 여부

---

## 검증 판정: N47-01·02와 33·34판 구현 마감 현황 (2026-11-18)

1. **N47-01·02 판정:** 완료(`db2b51e9c76a0e7805e04bd920b2afc9f0a4b53b`, 파일 10개). 차단 결함과 지적은 없다.
   - `Dashboard.swift`: 연결 줄 앞붙임을 지워 ddots `Monitor.swift:46`의 detail만 보인다. 아래 세 단추는 13pt다. 원본을 분리 실행해 잰 값(`task47-footer-metrics.json`)과 같다.
   - 캡처 `task47-hejo-dashboard.png`를 직접 확인했다. "Claude Code 기록 폴더에 접근할 수 없음"으로 나오고, 단추 글자 크기가 ddots 캡처와 같다.
   - `n47/final-foundation.log`: 245 passed.
   - TASK-47 전체는 수준 2/3이라 부분 완료로 둔다. 실제 훅 연결·해제가 남았다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **작업 56917a17 전체:** 부분 완료. 계획한 구현 TASK는 모두 끝났다.
   - 완료: N34-01, TASK-34·35·36·37·38·39·40·41·42·43·44·45·46·48, N33-01, N48-01·02, N47-01·02
   - 실물이 남은 부분 완료: TASK-33(0.2.0 공개), TASK-49(team-kit 패치 운영 반영), TASK-47(실제 훅), TASK-23(두 Mac 실물)
   - 남은 것은 아래와 같다. 모두 사장 결정이나 사장 실행이 필요하다.
     - 0.2.x 운영 반영(계획 담당+사장): `aeaa652` 기준 새 롤백 백업, 문·허브 갱신, team-kit 패치, 게이트웨이 재시작, 실물 점검(보완 49·57·60, TASK-23)
     - 공개본 재생성 여부: public `f716bdf`는 TASK-36~47 이전의 0.2.0 후보다.
     - GitHub 공개(publish)와 푸시 승인
     - 비설계자 검토

---

## 검증 판정: TASK-47 작업 목록·승인 알림 훅 (2026-11-18)

1. **판정:** 부분 완료.
   - 코드는 `8067d2237e995a2b86d5a327d7f4d5ade51046a2`(파일 33개)이고 증거 수준 2다. 필요한 수준은 3이다(사장 Mac의 다른 앱 설정 실물).
   - 고칠 것이 2건 있다. N47-01은 문구이고 원인은 계획 담당, N47-02는 외관이다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-41.AC-01과 대조표 H05를 충족한다. N47-01은 예외다.
   - `configure_hooks.py`
     - 기존 설정을 덮어쓰지 않는다(원본 create-only).
     - 심볼릭 링크면 멈춘다.
     - 원자적으로 쓰고 권한은 0600이다.
     - 백업, 영수증, 실패 보상, 원래 바이트·권한 복원이 있다.
     - 훅 명령은 `<앱> --hook <provider>`이고 timeout은 2다.
   - `--hook`은 GUI를 띄우기 전에 상태 파일만 쓴다.
   - 세션 파일은 읽기만 한다.
   - `settings_guard.py`는 실제 `.codex`·`.claude` 설정 파일의 lstat 메타데이터만 시험 전후로 비교한다. 내용은 열지 않는다.
   - 메뉴 "작업 목록"과 설정 "승인 알림 연결 안내"를 연결했다.
4. **직접 확인한 것**
   - `configure_hooks.py` 1-60과 `settings_guard.py`를 정적으로 검토했다.
   - 캡처 `task47-{ddots,hejo}-dashboard.png`를 직접 비교했다.
     - 같다: 머리, 수 카드 3개(작업 중·확인 필요·최근 응답), 분류 탭, 세션 줄 3개, 상태 색, 시각.
     - 다르다: Claude Code 줄 앞의 "연결 안 됨 · "(N47-01), 아래 단추 글자 크기(N47-02).
   - ddots `Monitor.swift:46`, `Dashboard.swift:85-87`과 hejo `Dashboard.swift:99`를 대조했다.
   - `final-foundation.log`: 245 passed.
   - `mutation.json`: 실패 복원을 지운 변형이 검출됐다.
5. **지적**
   - N47-01(문구): hejo가 ddots에 없는 "연결 안 됨 · " 앞붙임을 쓴다. 계획 담당의 AT-98 문구 때문이다. AT-98을 원문으로 고쳤다.
   - N47-02(외관): 아래 단추 글자가 ddots보다 작다.
6. **원인 분류:** N47-01은 계획 결함(수락 시험 문구가 ddots와 다름)이다. N47-02는 구현 세부 차이다.
7. **보완:** 보완 60(N47-01·02 수정, 실물 수준 3 점검표).
8. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-46 내 캘린더 (2026-11-18)

1. **판정:** TASK-46 완료(`673736e19edd9d7136b1ca6fc56038ebceb0a319`, 파일 29개). N45-01을 포함한다. 증거 수준은 2/2다. 차단 결함과 지적은 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-40.AC-01, 대조표 H04, 2.1판 H04+를 충족한다.
   - `Info.plist`에 `NSCalendarsUsageDescription`과 `NSCalendarsFullAccessUsageDescription`이 둘 다 있다.
   - 권한 요청은 사용자가 누를 때만 한다(새로고침·허용 단추).
   - EventKit을 읽기만 한다. 쓰기 호출은 0이다(`post-checks.json`).
   - 일정은 영구 저장하지 않고 문·허브에도 보내지 않는다.
   - 날짜 해석은 원본 분리 실행 결과와 같다(`task46-original-dates.json`).
   - N45-01: 주소줄 단추·주소칸을 원본 실측 프레임에 맞췄다. 글자는 세로 가운데다.
4. **직접 확인한 것**
   - 캘린더 캡처 `task46-{ddots,hejo}-light.png`를 직접 비교했다. 제목, 새로고침, 이전·다음 달, 월 제목, 검색칸, 선택된 일정 행, 상세(시간·장소·메모)가 같다.
   - 옆 창 캡처 `task46-web-hejo-light.png`: 주소 글자가 세로 가운데에 있다. 단추 간격과 주소칸 시작 위치가 ddots(TASK-45 원본 캡처)와 같다. N45-01이 해소됐다.
   - `MacCalendar*.swift`의 권한·쓰기 호출을 grep으로 확인했다.
   - `final-foundation.log`: 245 passed.
   - `mutation.json`: 일정 시작 시각 확인을 빼는 변형이 검출됐다.
5. **남은 위험:** 실제 캘린더 권한 대화상자와 실제 일정(TASK-23 실물), 두 Mac.
6. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-47(마지막 동등 이식)이다.

---

## 검증 판정: TASK-45 옆 창(웹 칸) (2026-11-18)

1. **판정:** TASK-45 완료(`0dec4611b0e6feea8371840c82be92c0f26e1d2d`, 파일 47개). N44-01을 포함한다. 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N45-01(주소줄 배치)은 TASK-46으로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-39.AC-01, 대조표 H03, 2.1판 H03+를 충족한다.
   - `Info.plist`에 `NSAllowsArbitraryLoadsInWebContent`가 없다(0건).
   - 출입증·인증 머리글을 웹 칸 요청에 넣지 않는다(`WebPane*.swift`에서 Authorization·token 검색 0).
   - 첨부는 앱이 받은 로컬 파일을 따로 만든 `nonPersistent` 저장소에서 `loadFileURL(url, allowingReadAccessTo: url)`로 연다. 그 파일만 읽을 수 있다.
   - 탐색 정책
     - http·https·about·blob·data와 첨부 파일만 허용한다.
     - 다른 앱 주소는 사용자가 눌렀을 때만 밖에서 연다.
     - ⌘를 누르고 링크를 누르면 새 탭으로 연다.
     - 첨부 응답(Content-Disposition)이나 표시할 수 없는 형식은 다운로드한다.
     - 탭은 12개까지다.
   - 첫 탐색에 실패하면 "밖에서 열기"가 비활성이다. 원본에서도 그렇다는 것을 재현해 확인했으므로 코드 우선(26판)으로 받아들인다.
   - N44-01
     - 모든 시험 Controller에 임시 다운로드 폴더를 넘긴다.
     - `downloads_guard.py`가 실제 다운로드 폴더의 항목 이름만 비교한다. 내용은 읽지 않는다.
   - gate·hub·schemas 변경은 없다.
4. **직접 확인한 것**
   - `WebPane.swift` 140-175·300-330을 정적으로 검토했다.
   - 캡처 `task45-{ddots,hejo}-light.png`를 직접 비교했다.
     - 탭, 새 탭, 옆 창 단추, 페이지 내용이 같다.
     - 주소줄 배치가 다르다(N45-01).
   - `final-foundation.log`: 245 passed.
   - `mutation.json`: 탭 한도를 13으로 바꾼 변형이 검출됐다.
5. **지적**
   - N45-01(비차단, 배치)
     - 주소칸 글자가 위쪽에 붙는다(기준선 약 5pt).
     - 주소칸 시작이 약 20pt 늦고, 탐색 단추 간격이 넓다.
     - 원본과 맞춘다(보완 59).
6. **남은 위험:** 실제 사이트 로그인·다운로드, 두 Mac.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-46이다.

---

## 검증 판정: TASK-44 다운로드 폴더 저장 (2026-11-18)

1. **판정:** TASK-44 완료(`a6dbadfcf810879683456e2b42a4add947f3b520`, 파일 14개). 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N44-01(시험 격리)은 TASK-45로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-37.AC-01과 대조표 H02를 충족한다.
   - 받은 파일
     - 이름은 `yyyy-MM-dd HHmm 이름 (id).ext`다. 확장자를 지키고, 이름은 200바이트로 자르며, 경로 문자는 바꾼다.
     - 같은 파일은 다시 받지 않고 연다. 다만 기록에서 지워지지 않은 같은 직원의 등록 파일일 때만 그렇게 한다.
   - 보낸 사본
     - 같은 내용이면 기존 사본을 다시 쓰고, 다른 내용이면 번호를 붙인다.
     - 송신이 확인된 뒤에만 직렬 큐에서 남긴다.
   - 저장 실패: ddots 원문 "파일을 저장하지 못했어요. …"(`SlackController.swift:1470`)을 보이고 캐시 파일로 연다.
   - 50MiB 한도, 권한, 넘겨주기, 크기 확인은 그대로다. wire·문·허브·기록장·LocalStore 필드 변경은 없다.
4. **직접 확인한 것**
   - `GateHTTP.swift` 차이를 정적으로 검토했다.
   - `reference.json`: ddots 원본과 제품을 각각 실행한 파일 이름·본문 결과가 같다.
   - `final-foundation.log`: 245 passed.
   - `mutation.json`: ID를 뺀 변형이 검출됐다.
   - 실제 사용자 다운로드 폴더에 시험 산출물이 없다(11-17 20시 이후 생긴 항목은 사용자 파일 1개뿐이다).
5. **지적**
   - N44-01(비차단): 여러 앱 시험이 `downloads:` 없이 Controller를 만들어, 기본값이 실제 다운로드 폴더다. 지금은 쓰지 않지만 구조적 격리가 없다(보완 58).
6. **남은 위험:** 실제 사용자 다운로드 폴더 권한, 두 Mac.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-45다.

---

## 검증 판정: TASK-43 대화창 모양 설정 (2026-11-18)

1. **판정:** TASK-43 완료(`3f868f7c71c309f95636822b2584490f49d756d3`, 파일 27개). N42-01을 포함한다. 증거 수준은 2/2다. 차단 결함과 지적은 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-38.AC-01과 대조표 H01을 충족한다.
   - 대화창 모양 설정
     - 테마 3종, 불투명도, 글씨 크기 7단계, 내 말풍선 14색, 미리보기, 기본값으로 되돌리기가 있다.
     - 값은 `hejo-local.json`에만 저장하고 허브로 보내지 않는다.
     - 미리보기는 ddots SwiftUI 미리보기를 AppKit으로 옮긴 것이다. 새 SwiftUI는 없다.
   - N42-01
     - 허브 대기마다 자기 Future를 회원별 집합에 등록한다.
     - "등록한 뒤 읽기" 순서를 지킨다(`hub/server.py:160-165`).
     - PATCH와 서버 종료는 등록된 Future를 모두 끝낸다.
     - 끝나면 `finally`에서 등록을 지운다.
4. **직접 확인한 것**
   - 캡처 `task43-{ddots,hejo}-dark.png`를 직접 비교했다. 미리보기 말풍선, 테마 분할, 불투명도 65%, 글씨 눈금, 14색 원, 안내 문구, 두 단추가 같다.
   - `hub/server.py` 차이를 정적으로 검토했다.
   - `final-foundation.log`: 245 passed(허브 경합 회귀 포함).
   - `mutation.json`: 옛 공유 Event로 되돌린 변형이 검출됐다.
5. **남은 위험:** 시스템 "투명도 줄이기" 실제 전환, 두 Mac, 운영 허브 반영.
6. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-44다.

---

## 검증 판정: TASK-42 설정 창·메뉴·대기 동기화 (2026-11-18)

1. **판정:** TASK-42 완료(`631ef5af7c427a53572580df33f07fd4338252b8`, 파일 29개). N35-01을 포함한다. 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N42-01(허브 깨우기 경합)은 TASK-43으로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-07, 대조표 §G·V11, 2.1판 G09·G11~G13, N35-01을 충족한다.
   - 고급 탭에는 동작 미리보기, 마우스 시선 미리보기, 수정 요청문 복사(실패일 때만 보임)가 있다.
   - 연결과 동기화 탭에는 에이전트 연결, 고정 채널, 화면 배치 동기화와 원문 설명이 있다. Slack 행은 뺐다.
   - 허브 대기 요청(G09)
     - `GET /v1/me/state?wait=<rev>`는 25초 동안 기다린다. `since`와 `wait`를 함께 쓰면 거절한다.
     - 대기가 끝나면 기기를 다시 확인한다(그 사이 기기가 해지됐으면 막는다).
     - 서버가 멈출 때 대기를 모두 깨운다.
     - 응답 헤더 `X-Hejo-State-Wait: 1`로 지원 여부를 알린다. 옛 허브에서는 앱이 30초 받기로 내려간다.
     - 보내기는 1.5초 묶음이다.
   - 클립보드·끌어놓기 탭은 넣지 않았다(사장 결정).
4. **직접 확인한 것**
   - `hub/server.py` 차이를 정적으로 검토했다. `set()`은 PATCH 갈래에만 있어 대기끼리 서로 깨우는 반복은 없다.
   - 캡처: `task42-{ddots,hejo}-advanced-light.png`, `-sync-light.png`를 직접 비교했다.
     - 네 쌍이 바이트까지 같다(md5 일치).
     - `capture.py`를 보면 원본은 ddots 소스에서 분리 컴파일했고, 제품은 hejo `app/Sources`에서 따로 컴파일한 두 실행 파일이다. 같은 이미지를 두 번 쓴 것이 아니다.
     - ddots 설정 창도 AppKit이라 바이트까지 같은 결과가 나올 수 있다.
   - `final-foundation.log`: 244 passed(허브 시험 포함).
   - `mutation.json`: 회원 변경 깨우기를 지운 변형이 검출됐다.
5. **지적**
   - N42-01(비차단): 회원별로 `Event` 하나를 같이 쓰고 대기마다 `clear()`하므로, 드문 순서에서 깨우기를 놓치고 최대 25초 늦을 수 있다. 값은 사라지지 않는다. 대기별 Future로 바꾼다(보완 57).
6. **남은 위험:** 실제 로그인 항목 등록, 운영 허브 반영(허브 갱신은 0.2.x 운영 반영 때), 두 Mac 실시간 동기화.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-43이다.

---

## 검증 판정: TASK-41 펫·말풍선·창 (2026-11-18)

1. **판정:** TASK-41 완료(`34fb3ad8865ec11b6e0d603f654e90ad99df3d54`, 파일 23개). N40-01을 포함한다. 증거 수준은 2/2다. 차단 결함과 지적은 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-06, 대조표 §F·V08·V10·V14, 2.1판 F05·F06·F20~F25를 충족한다.
   - 움직임 수치가 원본 분리 실행과 제품이 같다(`motion-comparison.json` match true).
     - 폭: 428→608, 0.3초, 페이드 0.06.
     - 지니 반쪽 0.8, 끌기 행 [2,1], 졸기 Z 3개.
     - 추종·활공 좌표가 소수점까지 같다.
   - macOS 알림 센터 API를 쓰지 않는다(`UNUserNotification`·`NSUserNotification` 검색 결과 0, 사장 선택).
   - N40-01: 검색 강조가 `NSColor.systemYellow`로 바뀌었다(`WorkspaceTools.swift:34`).
   - wire·문·기록장 변경은 없다.
4. **직접 확인한 것**
   - 캡처 `task41-{ddots,hejo}-light.png`를 직접 비교했다. 다음 말풍선 세 가지가 같다.
     - "답변이 필요해요"
     - "답변을 생각하고 있어요"와 "직원 A, 직원 B 작성 중…"
     - "새 메시지"와 링크 열기·대화 열기·나중에 알… 단추
     - 유리 모양, 얼굴, 줄 배치도 같다.
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: 반전 진행도를 초기화하는 변형이 검출됐다.
5. **남은 위험:** 두 Mac 실물(끌기, 메뉴 막대 층, 한글 입력기 단축키), VoiceOver.
6. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-42다(N35-01 포함).

---

## 검증 판정: TASK-40 스크롤·알림 막대·검색·머리줄 (2026-11-18)

1. **판정:** TASK-40 완료(`0e3f4c0e5b6f0e5b451d64b0338a39e23c981d09`, 파일 25개). N39-01을 포함한다. 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N40-01(검색 강조색)은 TASK-41로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-05, 대조표 §E·V07·V15, 2.1판 E09·E14~E17, A17을 충족한다.
   - 스크롤 좌표
     - 가운데 y 1035, 끝 maxY 1264, 늘어날 때 첫 이동 36pt가 원본 계산과 같다(`scroll-comparison.json`).
     - 실제 AppKit 키 9종·클릭·휠로 예약된 이동이 취소된다(`event-results.json`).
   - wire·문·기록장 변경은 없다.
   - 날짜 파서 자원은 잠금 아래에서 다시 쓴다. 값 캐시는 없다.
4. **직접 확인한 것**
   - 캡처를 직접 비교했다.
     - 검색 결과 `task40-{ddots,hejo}-light.png`: "스레드 2개 · 글 2건", 결과 상자, 말한 이, 날짜, 선택 상자가 같다.
       - 강조색이 다르다(N40-01).
       - 결과 상자 높이가 약 6pt 다르다. 보고서에 적힌 AppKit/SwiftUI 기준선 차이다.
     - 알림 막대 `notices`: 핀, 노란 점, "직원 A 질문 2", › 알약이 같다.
     - 체크리스트 `checklist-*-light`
       - 단추 크기는 원본 실측과 같다(항목 61×24, 작성 47×24, 건너뛰기 69×24).
       - 글자 크기는 원본이 약간 크다. 선언된 12pt와 시스템 기본 제어 글꼴의 차이로 copy-review에 기록돼 있다. 받아들인다.
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: 가운데 이동을 바닥 이동으로 되돌린 사본이 검출됐다.
5. **지적**
   - N40-01(비차단): 검색 강조가 `NSColor.yellow`(#FFFF00)다. ddots는 SwiftUI `Color.yellow`, 곧 시스템 노랑이다(`SlackFindView.swift:89`). `NSColor.systemYellow`로 바꾼다(보완 56).
6. **남은 위험:** 실제 트랙패드 관성 스크롤, VoiceOver, 두 Mac.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-41이다.

---

## 검증 판정: TASK-39 카드·글·파일 (2026-11-18)

1. **판정:** TASK-39 완료(`439136d75dbd3322a900d2fc7f8d1b0a09e2d313`, 파일 30개). N37-01과 N38-01을 포함한다. 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N39-01(체크리스트 단추 크기)은 TASK-40으로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-04, 대조표 §D, 2.1판 D04·D25~D30, 35판 D39-01을 충족한다.
   - gate·schemas 변경은 0이다(`git show --stat`). 새 SwiftUI import도 0이다.
   - 삭제된 첨부 표시는 없다. 404는 "사진을 불러오지 못했어요"다.
   - AT-90 문구는 2.1판 D04("툴팁 없음, 접근성 이름")에 맞게 고쳤다.
4. **직접 확인한 것**
   - 캡처 `task39-{ddots,hejo}-light.png`를 직접 비교했다.
     - 같다: "할 일" 제목, 답 버튼 4개, "자세한 내용" 인용 두 단계와 색, 링크 색, 카드 단추(링크·복사·분기, 같은 색 — N37-01 해소), 삭제 단추 없음(답 있는 스레드를 고르지 않은 상태라 ddots 조건과 같음).
     - 같다: PDF 타일("2.0KB · PDF", ↓), 사진 비율, 실패 문구.
     - 다르다: 체크리스트 항목·건너뛰기 단추의 글자 크기와 폭(N39-01).
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: 삭제 대상 검사를 지운 사본이 검출됐다.
5. **지적**
   - N39-01(비차단, 세부): 체크리스트 단추의 글자가 작고 폭과 여백이 크다. ddots 3540-3575 기준으로 맞춘다(보완 55).
6. **남은 위험:** VoiceOver 실사용, 실제 서버, 두 Mac.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-40이다.

---

## 검증 판정: TASK-39 1차(D39-01 보류) (2026-11-18)

1. **판정:** TASK-39 미완료.
   - 실행 담당이 D39-01을 재현하고 멈췄다. 커밋은 없고, 초안 4개는 보존했다.
   - 작업 트리에는 보고 두 파일만 바뀌어 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 구현이 적용되지 않아 판정하지 않는다.
4. **직접 확인한 것**
   - `gate/files.py:177-193`: `cleanup`은 미등록 파일과 숨겨진 글의 파일만 지운다.
   - 스레드 삭제는 글 단위 `delete`다.
   - wire `file`에는 삭제 표식이 없다(실행 담당 경계 시험 `file-boundary.json`, 1 passed).
5. **원인 분류:** 명세 공백이다. 대조표 D11이 ddots의 Slack 삭제 표식을 hejo에서 누가 만드는지 확인하지 않았다. 구현 결함이 아니다.
6. **결정·보완:** 35판 보완 54.
   - D11 삭제 표시는 생산자가 없어 제외한다. 404와 유실은 실패 표시로 처리한다.
   - 대조표 D11을 갱신했다.
7. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-38 사이드바 (2026-11-18)

1. **판정:** TASK-38 완료(`f535b3114857cb8c46e8c1edbb315570d7eab92c`, 파일 27개). 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N38-01(그림 크기·간격)은 TASK-39로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-03, 대조표 §C·V03~V06·V13, 2.1판 C22~C27, 이관된 REQ-HF-34.AC-08을 충족한다.
   - 움직임
     - 행 차이는 `NSTableView` `beginUpdates`와 `insert/removeRows(.effectFade)`로 처리한다. 0.24초 easeInEaseOut이고, 직접 `reloadData`를 부르지 않는다.
     - 높이 변화는 `noteHeightOfRows`로 0.24초 움직인다.
     - 레일은 `CAShapeLayer` path·opacity가 0.24초 동안 바뀌고, presentation 값에서 이어 간다.
     - 선택 상자는 spring이다. ddots `.spring(response: 0.34, dampingFraction: 0.88)`(SlackPanel.swift:2071)을 stiffness `(2π/0.34)²`, damping `2·0.88·ω`로 정확히 바꿨다.
     - 동작 줄이기와 창이 없을 때는 즉시 바뀐다.
   - 접힌 구획에는 얼굴·사진이 없다(V03). 사장이 고른 것(DM 기본 이름, 얼굴 줄 없음)은 그대로다.
   - 새 영구 원본·wire·문 변경은 없다.
4. **직접 확인한 것**
   - 캡처: `task38-{ddots,hejo}-light-212.png`, `-dark-68.png`를 직접 비교했다.
     - 구획·홈·고정·함께·보관 전·DM 순서, 레일, 구분선, 선택 상자, 얼굴 묶음 +3, 수 배지 색(빨강·노랑·하늘)이 같다.
     - 좁은 폭(68)의 핀 위치와 이름 줄도 같다.
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: slideDown 변형이 검출됐다(baseline 0, 변형 1).
5. **지적**
   - N38-01(비차단, 세부): 방 행의 핀·알림 끔 그림이 ddots보다 작고 흐리다. "방 추가"의 ⊕와 글자 사이가 좁다. TASK-39에서 ddots 값으로 맞춘다(보완 53).
6. **남은 위험:** VoiceOver 실사용, 실제 서버, 두 Mac에서 ddots와 나란히 보는 실물 확인.
7. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-39다.

---

## 검증 판정: TASK-37 작성기 대상·보내기 (2026-11-18)

1. **판정:** TASK-37 완료(`13596ba16b74e1326a0bf899ec927f09f63fafea`, 파일 24개). N36-01·N36-02도 반영했다. 증거 수준은 2/2다. 차단 결함은 없다. 비차단 N37-01(카드 단추 색)은 TASK-39로 넘긴다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** REQ-HF-36.AC-02, 대조표 §B B01~B13, 2.1판 B04 정정("보내는 중")·B15~B18을 충족한다.
   - 확인 전 흐린 글의 시간 자리는 "보내는 중"이다(`ConversationView.swift:795`, 2.1판 정정과 같음).
   - B05 "답이 중단됐어요"
     - ddots에서 `replyInterrupted`를 만드는 곳은 `HermesBridge.swift:243`과 `HermesRelay.swift:29`(Hermes 직접 세션)뿐이다. Slack 방 경로에서는 늘 false다.
     - hejo는 Slack 방 경로에 해당하므로 새 이벤트를 추정하지 않았다. 이 판단을 받아들인다.
   - N36-01
     - 날짜 조건 분기와 그것만 쓰는 상수(`since`·`scriptSince`·`retired`·`legacyScript`)를 지웠다.
     - 날짜 조건 없이 `allowed`에 들어 있던 옛 범례 본문은, 결과가 바뀌지 않게 하라는 지시대로 남겼다.
   - B14는 대조표대로 넣지 않았다.
   - 원본 자리를 다시 썼다: Controller의 초안·pending·실패 메모리와 Model/MemberState.
4. **직접 확인한 것**
   - `final-foundation.log`: 236 passed.
   - `mutation.json`: 고정 초안 UUID로 보내는 돌연변이가 검출됐다.
   - 캡처
     - `task37-*-pending.png` 두 장을 직접 비교했다. 흐린 내 글, "보내는 중", 카드 배치가 같다.
     - 바뀐 `task36-hejo.png`는 연결 상태로 찍혀 승인·거절 단추가 ddots와 같아졌다(N36-02 해소).
     - 남은 차이: hejo의 분기·삭제 글자가 흐리다 → N37-01.
5. **지적**
   - N37-01(비차단, 카드 단추 색)
     - hejo 분기·삭제는 `.secondaryLabelColor`이고, ddots는 링크·복사와 같은 `quiet`다(`NativeThreadContent.swift:120-140`).
     - §D 카드 범위이므로 TASK-39에서 고친다(보완 52).
6. **원인 분류:** N37-01은 TASK-39 범위의 기존 차이다. 이번 변경으로 생긴 결함이 아니다.
7. **남은 위험:** 실제 한글 입력기, 실제 서버, 두 Mac 결합.
8. **작업 56917a17 전체:** 부분 완료. 다음은 TASK-38이다.

---

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
