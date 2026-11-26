## 검증 판정: HEJO-ALERT-SEEN TASK-01 (작업 ID 486f23e4-66ff-48e1-97a9-b9101d208836) — 1차

1. **판정: 미완료.** 제품 구현이 시작되지 않았다. 구현 담당은 handoff 0절의 착수 조건(HEJO-AUTOLOAD TASK-01이 공개 `github/main`에 반영)이 충족되지 않아 아무것도 바꾸지 않고 멈췄다. 멈춘 판단은 옳다.
2. **검증 조건:** 교차 모델(구현 담당 codex, 검증 담당은 이 계획 대화). 검토한 상태: 구현 worktree `role-workflow-42-486f23e4`(브랜치 `role-workflow/42-486f23e4`) HEAD `159995c39b0ea00217d6a5e6f641d55a59544cd2` = 실행 전 커밋, 작업 트리 변경 없음.
3. **설계 적합성(4.2):** 판정 대상 구현이 없다. 계획은 계획 검증 2회차에서 APPROVED를 받았고([plan-review.md](plan-review.md)), 이번 회차에 설계 변경이 필요한 새 근거는 없다.
4. **직접 확인한 것(2026-11-25):**
   - `git fetch github && git rev-parse github/main` → `c22e6774604398f84351d69dd926ba3510d31aa2`(handoff 작성 때와 같음).
   - `git merge-base --is-ancestor db8a2240cefacd74b0bb466372b580490a0ed030 github/main` → 종료 1. AUTOLOAD 후보 커밋은 공개 tip에 들어 있지 않다.
   - `git grep -E 'onLoadViewport|autoloadAppended' github/main -- app/Sources` → 일치 없음(종료 1).
   - `docs/changes/HEJO-AUTOLOAD-20261125/verdict.md`의 마지막 판정은 "부분 완료"(수락 시험 충돌로 멈춤, 커밋 없음).
   - 구현 worktree `git status --short` 비어 있음. `impl-report.md`는 없고, 착수 중단 지시에 따른 것이라 정상이다.
   - 시험: 미실행(구현 없음). 증거 수준: 해당 없음.
5. **지적 목록:** 구현 지적 없음. 차단 사유 1건: 선행 작업 미반영(아래 8).
6. **기획설계로 넘긴 것:** 착수 시점 결정. AUTOLOAD를 계속 기다릴지, 아니면 AUTOLOAD 없이 현재 공개 tip에서 시작할지 사용자에게 묻는다. 후자를 고르면 "원문 불러오기" 버튼이 남아 있으므로 design 4절대로 그 버튼도 직접 선택 입구로 옮겨야 하고, AUTOLOAD·WAIT-JITTER와 같은 `ConversationView.swift`를 고치게 되어 나중에 들어가는 작업이 다시 올리고 재검증해야 한다.
7. **미검증 범위와 남은 위험:** REQ-AS-01·02 전부 미검증.
8. **미완료 원인 분류:** 환경·외부 요인(선행 작업 HEJO-AUTOLOAD TASK-01이 부분 완료 상태로 공개판에 반영되지 않음). 구현 오류·설계 오류·시험 오류 아님. 완료까지 남은 조건: 착수 조건 충족(AUTOLOAD 반영 또는 사용자의 선행 해제 결정) → handoff 2판 9절대로 TASK-01 수행 → 재검증.
9. **현재 명세 반영 요청:** 없음(완료 아님).

## 검증 판정: HEJO-ALERT-SEEN TASK-01 — 2차 (2026-11-26)

1. **판정: 미완료.** 제품 변경이 없다. 구현 담당은 handoff 9절 2(시험 먼저)에서 보존 시험 AT-AS-01·02·07a가 기준본에서 실패하자 제품을 고치지 않고 멈췄다. 멈춘 판단은 옳고, 원인은 설계의 틀린 가정이다(아래 V-1).
2. **검증 조건:** 교차 모델(구현 codex, 검증은 이 계획 대화. 같은 대화가 설계도 했으므로 설계 적합성은 코드로 다시 읽어 따로 판정). 검토 상태: 공개 worktree `hejo-alert-seen-public-20261125` HEAD `7540da13639b1094774195ea6815b3d0d4cdf826`(= 공개 `github/main`), 미커밋 시험 변경 3개 파일 + 새 파일 `app/Tests/HistoryAlertSeenHarness.swift`. `git diff --exit-code -- app/Sources gate/history_queries.py` 종료 0(제품 무변경). 호스트 worktree `role-workflow-42-486f23e4`는 변경 없음(플러그인 수집과 일치, 실제 작업은 인계서대로 공개 worktree).
3. **설계 적합성(4.2): 부적합(2판).** [확인 `7540da1`] `HistoryCoordinator.inputsChanged`(324~334행)는 선택·입력(회원 상태를 담은 문맥)·창 표시가 바뀌면 `reads = []`로 대기 읽음 요청을 모두 버린다. `ConversationModel`의 `memberState.onChange`(429행 부근)는 회원 상태가 바뀔 때마다 `intentGeneration`을 올리고, 조정자는 세대가 다른 요청을 보내지 않는다. 직접 선택은 `select`가 `thread` 요청을 건 뒤 `markAlertSeen`이 `notice`를 거는데, 선택 변경을 감지한 `inputsChanged`(컨트롤러 갱신 487행, `reveal` 뒤 `open`→`enqueue`)가 둘을 비우거나, `thread`가 적용되는 순간 `notice`가 버려진다. 따라서 2판의 "두 요청은 독립"(F2 처리)과 "가운데 카드·채팅 클릭은 이미 동작"(F1 처리)은 출시 경로에서 틀렸다. 이 소실이 사용자가 처음 본 증상의 주원인이다. 기존 AT-TD-39는 레거시 참조 모드에서만 돌아 이 경로를 보지 못했다. → 3판으로 고침(design 2.1: 울리는 알림은 `notice` 한 건, `inputsChanged`는 새 세션이 아니면 지금 세대 요청을 남김).
4. **직접 확인한 것:** 위 코드 줄. 공개 worktree `.build/alert-seen/baseline.log`(AT-AS별 관측), `baseline-transport-full.log` 끝줄 `4 failed, 75 passed`(실패는 새 AT-AS-01·02·04·07a, 기존 69개 통과). 시험 diff 3개 파일 204줄 추가 + 새 하네스 파일. 증거 수준: 2(대역 통합)는 기준본 관측에 한함. 수정본 시험 미실행.
5. **지적 목록**
   - V-1 · 차단 · 위치 design 2.1(2판)·수락 시험 2판 AT-AS-01·02·05·07a~c 기대값 · 근거 3번 · 보낼 곳 기획설계 · 처분: **반영(3판)** — spec 3판(문제 3번, AC-05a·07a~c 재작성·08·09 추가), design 3판(2.1 확인 요청 한 건·조정자 세대 필터·대안·위험), 수락 시험 3판(기준본 기대 열을 실제 관측으로 바로잡고 AT-AS-12·13 추가), handoff·tasks(D-04).
   - V-2 · 비차단 · `bash scripts/test.sh` 기준본 6건 실패(시험 venv에 `yaml` 없음 등, `baseline-suite.log`) · 환경 · 처분: 수정본에서 같은 목록과 비교(새 실패 0이 기준).
6. **기획설계로 넘긴 것:** V-1 → 3판 반영 완료.
7. **미검증 범위:** REQ-AS-01·02 수정본 전부. AT-AS-12·13 미작성.
8. **원인 분류:** 설계 오류(요구 불변). 완료까지: 3판 시험 갱신 → 기준본 재실행(`baseline-v3.log`) → 제품 수정 → 회귀 → 커밋 → 재검증.
9. **현재 명세 반영 요청:** 없음.

## 검증 판정: HEJO-ALERT-SEEN TASK-01 — 3차 (2026-11-26)

1. **판정: 완료.** REQ-AS-01(AC-01~06·05a·07a~c·08·09)과 REQ-AS-02(AC-01~08)가 대역 통합 시험으로 충족됐고, 유지할 계약을 지켰으며, 미해결 차단 지적이 없다.
2. **검증 조건:** 교차 모델(구현 codex, 검증 이 계획 대화). 검토 대상: 공개 worktree `hejo-alert-seen-public-20261125`, 기준 `github/main` `7540da13639b1094774195ea6815b3d0d4cdf826`(원격 tip, `ls-remote`로 확인) 위 시험 커밋 `43b7e9d567174f26b7cff13a09ff71f4fd2e1fc7` → 제품 커밋 `b1fc6c49c33eee7ff1b5778adf13b67da992c08a`(fast-forward, `merge-base --is-ancestor` 종료 0). 작업 트리 깨끗함. 호스트 worktree `role-workflow-42-486f23e4`에 변경이 없는 것은 인계서대로 공개 worktree에서 일했기 때문이다.
3. **설계 적합성(4.2): 적합.** 제품 diff(6개 파일 +59/−23)를 직접 읽었다.
   - 단일 입구 `ConversationModel.selectUserThread`(`WorkspaceTools.swift`): `select(markRead:false)` 뒤 울리는 알림이면 `markNoticeRead`(=`notice` 한 건)만 하고, 아니면 창이 보이고 `markRead`일 때 `markThreadRead`. `markAlertSeen`은 private이 됐고 호출은 이 입구 한 곳(AT-AS-08 grep 확인). 입구를 부르는 곳은 `reveal(direct:true)`·`chooseThread`·`writeReply`, 그리고 컨트롤러의 링크 열기·"의견" 버튼(`revealThread(direct:true)`). 분기·후속 같은 자동 표시는 `direct:false`로 `select`만 한다(D-01). `selectAutomatic`·임시글 복원은 손대지 않았다.
   - 조정자 `inputsChanged`: 새 세션이면 `reads` 전부, 아니면 지금 `intentGeneration`이 아닌 것만 버린다. 보내기 직전 세대 검사는 그대로다(design 2.1).
   - 문 `history_queries.py`: 첫 줄이 멘션뿐(모든 조각이 `@`+한 글자 이상)이면 다음 내용 줄을 " · "로 붙이고 `prefix(…, 300)`.
   - **설계에 없던 변경 1건(수용):** `ConversationModel.setVisible`가 창을 **숨길 때만** `intentGeneration`을 올린다(이전에는 보일 때도 올림). 말풍선 경로는 선택 뒤 창을 여는데, 여는 순간 세대가 올라 방금 건 `notice`가 버려졌다. 보조 시험이 변형(표시 때 증가 복원)에서 `notice` 누락을 재현하고 수정본에서 통과했다(`bubble-probe/before-result.log` 실패, `result.log` 통과). 같은 책임(의도 세대) 안의 수정이고, 창이 숨은 동안 걸리는 읽음 요청은 말풍선의 직접 선택뿐이라(`markThreadRead`·`enterRoom`은 창이 보일 때만) 옛 의도가 새로 나가는 경로를 만들지 않는다.
   - 공백만 있는 줄을 빈 줄로 보도록 바뀌었다(`line.strip()`). spec의 "첫 비어 있지 않은 줄"에 맞고 AT-AS-10(다른 미리보기 유지)이 통과했다.
4. **직접 확인한 것(증거 수준 2, 대역 통합):**
   - 시험 코드(`gate/tests/history_transport_app.py` `test_alert_seen`): 사례마다 그 key 대상 요청을 action·상태 코드까지 단언한다(01·02·04 `[('notice',…,200)]`, 07a·b `[('notice',…,409)]`, 12a·b `[('thread',…,200)]`, 13 A 대상 0건·B 대상 있음). 기대값이 수락 시험 3판과 같다.
   - `candidate-v3-full-transport.log`: `82 passed`, AT-AS 13개 시나리오(01·02·03·04·05·06·07a·07b·07c×2·12a·12b·13) 모두 PASSED. `candidate-v3-gate.log`: `20 passed`. `baseline-v3.log`: 기준본은 3판 "기준본 기대"와 일치(문 15통과·5예상 실패, 앱 대역 7통과·6예상 실패).
   - `candidate-v3-compare.log`: `scripts/test.sh` 기준본 6실패 → 수정본 5실패, 새 실패 `[]`(남은 실패는 시험 venv 모듈 부재 등 환경, V-2). `candidate-v3-app.log`: 레거시 앱 시험 `OK`, 실제 설정·다운로드 메타데이터 무변경. 개인값 검사는 impl-report 기록상 종료 0(로그 본문은 파일 목록만 있어 종료 코드는 보고에 의존).
   - 수정본 시험을 다시 돌리지는 않았다. 대상 코드·입력이 로그를 남긴 커밋과 같아서다(`candidate-v3-tested.patch` = 제품 커밋 패치라는 구현 담당의 비교 기록과 작업 트리가 깨끗함을 확인).
5. **지적 목록**
   - V-1(차단, 2차) · 처분: 해결(3판 설계대로 구현, 시험 통과).
   - V-2(비차단·환경) · `scripts/test.sh`의 환경 실패 5건 · 처분: 기준본과 같은 목록이라 판정을 막지 않음.
   - V-3(비차단·기술 부채) · 말풍선·섬 클릭(spec의 직접 선택 목록에 있음)을 지키는 시험이 저장소 밖 보조 시험(`.build/alert-seen/bubble-probe/`)뿐이다. 수락 시험에 해당 행이 없던 것은 계획 담당의 누락이다 · 보낼 곳: 기획설계 · 처분: 후속 과제로 기록(tasks.md).
   - V-4(비차단) · 멘션 줄 끝에 공백이 있으면 제목이 "@acct  · …"처럼 공백 두 칸이 된다 · 처분: 표시 문제, 후속 과제로 기록.
6. **기획설계로 넘긴 것:** 현재 명세 반영(TASK-02). V-3·V-4 후속 과제.
7. **미검증 범위와 남은 위험:** 실제 서버의 문과 설치 앱에서의 동작(증거 수준 3·4)은 별도 릴리스 작업. 문을 갱신하기 전에는 카드 제목이 바뀌지 않는다. 이미 쓴 읽음 기록은 되돌림으로 복구되지 않는다(design 5절).
8. **원인 분류:** 해당 없음(완료).
9. **현재 명세 반영 요청:** `docs/spec/current/hejo-thread-status.md`에 REQ-AS-01(직접 선택만 알림 확인, 요청 한 건, 조정자 세대 규칙)과 REQ-AS-02(카드 제목 규칙)를 반영한다.
