# 설계 인계: HEJO-DEADLINE-CLOSE / TASK-01~03 마감 카드 이동·없음 표시·우클릭 닫기

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음, 두 번째 원본 없음. 장부 쓰기 주체에 "사장(문 경유, 닫기만)"이 더해진다.

```text
[설계 인계: HEJO-DEADLINE-CLOSE TASK-01~03 / team-kit·문·앱]
0. 기준: 이 저장소 main de8bdac, 운영 저장소 eee573e6(deadline_watch.py sha256 470d2725…, 실행본과 같음) /
   spec·design·수락 시험 3판, tasks·handoff 3판 / 작성 2026-11-22, 3판(계획 검증 1·2회차 반영, plan-review.md) / 승인: 사장 결정 5개(brainstorm.md) + 계획 검증 재검토 대기 /
   운영 모드: 연합개발(교차 모델, 계획 검증 켬)
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-DEADLINE-CLOSE-20261122/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-DEADLINE-CLOSE.md. 앞선 작업 docs/changes/HEJO-TODO-DRAWER-20261120/. team-kit은 <운영 저장소>/AGENTS.md와 ./airport-check.
2. 요구와 수락 기준: REQ-DC-01~05, NFR-DC-01·02(REQ-DC-06 서버 적용은 이번 지시 밖).
   정상: 알림 글로 이동, 출처 종류 표시, 우클릭 완료/취소 → 5초 뒤 문이 team-kit close 실행 → 목록 새로 받기.
   핵심 실패: 이동할 곳 없음 → "연결된 대화 없음"(1:1 방 이동 없음), 닫기 실패 → 카드 재표시 + 회색 줄, 되돌리기 → 아무것도 안 보냄.
3. 유지할 기존 계약: 프레임 v 1(새 type·선택 필드만 추가), deadlines_status 기존 필드 의미,
   deadline_watch 장부 형식·perform/handle/repaint_closed/reopen 동작, list 출력의 기존 키·실패 처리, hermes-connections 명령 표,
   ActionJournal 기존 호출과 행 모양(선택 필드 deadline만 추가), perform 반환(close에 closed_now 추가만), handle close(이미 닫힘이면 다시 칠하지 않음 — 이 한 줄만 변경), 답 요청·알림 카드 동작(AT-TD-25).
   기존 AT-TD 기대값은 그대로이며 바뀌는 것은 정확히 셋: AT-TD-26 일부(1:1 방·단추 없음 → AT-DC-25·26), AT-TD-10 허용 키(+origin·notice, 계획 담당이 test_deadlines.py를 이미 고침),
   AT-TD-01 키 집합(+notice?, TASK-01이 HD test_deadline_list.py를 고침, 기대는 AT-DC-08).
4. 책임과 흐름: design 1절. 닫기 규칙 = team-kit perform+repaint_closed 한 곳, 실행 경계·검증·행동 기록 = 문 Deadlines.close,
   대기·되돌리기·숨김 = 앱 ConversationController, 이동 대상 = ConversationView.selectDrawerCard 한 곳.
5. 기존 경로 판정: design 6절(교체: 마감 카드 1:1 방 분기 제거, TD REQ-TD-04 AC-03 "닫는 단추 없음" → 우클릭 메뉴. 나머지 유지·확장).
6. 위험도: TASK-02 문은 고위험(새 원격 쓰기 입구 = 권한, 자식 프로세스·Unix 입구 재진입·직렬화 = 동시성) → 다른 모델 검증 필수.
   TASK-01·03 일반. 필요 증거 수준 2. 롤백은 design 8절(서버 적용은 TASK-04).
7. 변경 성격: 의미 변경(마감 카드 클릭 결과, 마감 닫기 가능). 보존 비교: AT-DC-08·20·33, bash scripts/test.sh 전체.
8. 수락 시험: tests/acceptance/HEJO-DEADLINE-CLOSE.md 3판 AT-DC-01~09b(team-kit), 10~20·16c·35(문), 21~34·27d(앱). 기대값 출처 spec·design.
   상태: 명세 완료·코드 미작성·미실행·계획 검증 대기.
9. 작업 범위: tasks.md TASK-01·02·03 영향 파일만. TASK마다 별도 커밋(git commit --only로 자기 경로만), impl-report.md에 TASK별 절.
   team-kit은 <운영 저장소> 임시 worktree(기준 eee573e6)에서만 고치고, 착수 때 deadline_watch.py sha256을 기록한다(운영 저장소의 미커밋 변경은 건드리지 않음).
   금지: 운영 공항(~/.hermes) 파일 변경·게이트웨이 재시작·운영 team-kit 원본 수정, 실제 장부 닫기, Hermes 본체, ddots, 비밀 파일 열기,
   실제 Slack·고객 메시지, git push. TASK-04·05는 하지 않는다.
   병렬 갈래: 있음(tasks.md 표, team-kit/문/앱 파일 겹침 없음).
10. 가정·미확정: [제안] 되돌리기 대기 5초, 문 총 60초 = 잠금 대기 ≤20 + 실행 40, 앱 응답 대기 75초(근거 design 3절). 대기 줄·실패 줄의 그리기 세부는 구현 자유.
    [가정] 앱 기록(model.messages)에 hejo 알림 글이 있으면 그 id가 notice.message_id와 같다(gate/local.py:198-202의 msg_id = 기록장 id).
    착수 차단 없음.
11. 사용자 확인: 우클릭 닫기·문이 바로 닫기·완료/취소·확인 없이 되돌리기·알림 글 이동+없음 표시는 사장 답(brainstorm.md). 범위·AC는 이 plan 승인으로 확인.

[인계 전 점검]
- 현재 코드·계약·명세가 base de8bdac와 호환: 예(작성 시점 main HEAD. 미추적 docs/changes/HEJO-AUDIT-20261122는 다른 작업의 문서이며 영향 없음).
- G1–G4: 요구·범위·제외 확정, 현황 근거(spec 1절), 경로 판정(design 6절), AC↔시험 연결(아래), 위험·증거 수준 지정. 계획 검증 통과 전까지 G3 보류.
```

## AC ↔ 시험

| AC | 시험 |
|---|---|
| DC-01.AC-01 | AT-DC-23 |
| DC-01.AC-02·04 | AT-DC-24·26 |
| DC-01.AC-03 | AT-DC-25 |
| DC-02.AC-01 | AT-DC-10·21 |
| DC-02.AC-02 | AT-DC-22 |
| DC-02.AC-03 | AT-DC-33 |
| DC-03.AC-01 | AT-DC-26 |
| DC-03.AC-02·04 | AT-DC-27·27b |
| DC-03.AC-10 | AT-DC-27c |
| DC-03.AC-03 | AT-DC-28 |
| DC-03.AC-05 | AT-DC-29 |
| DC-03.AC-06 | AT-DC-30·34 |
| DC-03.AC-07 | AT-DC-31·32 |
| DC-03.AC-08 | AT-DC-02·03 |
| DC-03.AC-09 | AT-DC-05·09b·14 |
| DC-04.AC-01 | AT-DC-12 |
| DC-04.AC-02 | AT-DC-13 |
| DC-04.AC-03 | AT-DC-14·16b |
| DC-04.AC-07 | AT-DC-16c |
| DC-03.AC-11 | AT-DC-27d |
| DC-04.AC-04 | AT-DC-15·16·17 |
| DC-04.AC-05 | AT-DC-12·13·14 |
| DC-05.AC-01 | AT-DC-01 |
| DC-05.AC-02 | AT-DC-02·03·04·09 |
| DC-05.AC-03 | AT-DC-05·09b |
| DC-05.AC-04 | AT-DC-06·07 |
| DC-05.AC-05 | AT-DC-08·09b |
| NFR-DC-01 | AT-DC-18, 개인값 검사 |
| NFR-DC-02 | AT-DC-12·35 |
| 규격 | AT-DC-11·19 |
| DC-06 | M-DC-1·2(TASK-04) |

## 구현 담당 보고

`impl-report.md`에 TASK별로 바꾼 파일·커밋, 시험 명령·종료 코드·로그 경로(`.build/` 아래), 도달 증거 수준, 남은 문제, team-kit worktree 경로·커밋을 적는다.

검사 명령(대상 = 최종 커밋):
- `TZ=Asia/Seoul bash scripts/test.sh`
- 문 `pytest gate/tests tests/acceptance`
- `python3 scripts/scan_private.py`
  - 위 둘은 Hermes venv 파이썬(`~/.hermes/installs/*/environments/*/venv/bin/python`, `HEJO_PYTHON`)으로 돌린다. 시스템 python3에서는 `scan_error`로 실패한다.
- `git diff --check`
- `HD` worktree: `./airport-check`와 team-kit 시험

## 보완 지시 1 — 검증 1차 V-1·V-2 ([verdict.md](verdict.md))

- 기준
  - 구현 브랜치 `role-workflow/16-a3ea9587` @ `0c85496`.
  - 운영 저장소 브랜치 `hejo-deadline-close-20261122` @ `cfe6d9d2`는 바꾸지 않는다.
- 할 일
  1. **V-1**: `app/Sources/TodoDrawerModel.swift` `originNames`를 spec REQ-DC-02 AC-01대로 고친다. `calendar`→`캘린더`, `slack`→`Slack`(나머지 노션·미리알림·메모·메일은 그대로).
  2. **AT-DC-21b**(수락 시험 명세 3판에 추가됨)를 `app/Tests/TodoDrawerTests.swift`에 추가한다. 기존 AT-DC·AT-TD 기대값은 바꾸지 않는다.
  3. **V-2**(계획 담당 결정, 기대값 소유는 계획 담당): `tests/acceptance/test_slack_move_gate.py:59`의 고정 해시를 `4f365159c687db76249fed494627764f2e8fe741e89a56471642fe983371b7ce`로 바꾼다. 바로 위 주석에 "HEJO-DEADLINE-CLOSE added definitions only (verdict V-2)"를 덧붙인다. 그 밖의 AT-SM-02 줄은 바꾸지 않는다. 안내판을 또 바꿨다면 멈추고 보고한다.
  4. 로컬 `main`이 `0644e9e`보다 앞서 있으면 merge 커밋으로 통합한다(rebase·force 금지). 의도 판단이 필요한 충돌이 생기면 멈추고 보고한다.
- 검사(대상 = 최종 커밋)
  - `pytest gate/tests tests/acceptance`: 실패는 기준 환경 실패 2건(`test_delivery_parity::test_native_labels…`, `test_at_hf_08[True]`)뿐이어야 한다.
  - `TZ=Asia/Seoul bash app/scripts/test.sh` 종료 0.
  - `scan_private.py`(Hermes venv) 종료 0.
  - `git diff --check` 종료 0.
  - `git merge-base --is-ancestor main <최종 커밋>` 종료 0(로컬 main 해시 기록).
- 보고: `impl-report.md`에 "보완 1" 절(커밋, 바꾼 파일, 명령·종료 코드·로그 경로).
- 금지: 기존과 같다. 운영 공항·재시작·운영 team-kit 원본·실제 장부 닫기·비밀 파일·Hermes 본체·ddots·실제 메시지·git push, TASK-04·05는 하지 않는다.

## 지시 2 (2026-11-22): TASK-04 서버 적용 → TASK-05 앱 0.2.6 공개 후보 준비

사장 지시 "남은 일 모두 진행". 검증 완료본은 로컬 `main`에 들어갔다: merge `5a3f123`(54272ad 병합), 문서 `95b9041`. 이 저장소 작업은 **로컬 main checkout에서 하지 않는다.** 구현 worktree 브랜치를 로컬 `main`(`95b9041` 이후)으로 merge해서 쓴다.

### TASK-04 서버 적용 (고위험, 증거 수준 3·4)

- 시작 조건
  - 직원 진행 중 턴이 0이다(기존 `hermes-connections gateway restart --json`의 BUSY 검사).
  - 적용 전에 **롤백 기록을 impl-report 'TASK-04' 절에 먼저** 쓴다. 명령마다 경로·커밋·sha256을 채우고 빈칸을 남기지 않는다.
- **team-kit**(운영 공항 `~/.hermes`가 원본이고 `HD`는 `./sync`로 모으는 사본이다)
  1. 실행본 sha256이 기준과 같은지 확인한다. 다르면 멈추고 보고한다.
     - `~/.hermes/plugin-store/team-kit/lib/hermes_team_services/deadline_watch.py` = `470d2725…`
     - `~/.hermes/bin/hermes-deadlines` = `8340115f…`
  2. 두 실행본을 0700 임시 폴더에 그대로 보관하고 경로와 sha256을 적는다. 이 보관본이 복원 기준이다.
  3. `HD` 브랜치 `hejo-deadline-close-20261122`(`cfe6d9d2`)의 두 파일을 임시 파일에 쓴 뒤 이름 바꾸기로 실행본에 교체한다. 권한은 기존과 같게 둔다(`hermes-deadlines` 실행 가능).
  4. 확인: `~/.hermes/bin/hermes-deadlines list --json`이 종료 0이고 `failed`가 비어 있어야 한다. 실행 전후로 운영 장부 파일들의 sha256이 같아야 한다. 기록에는 개수와 가명만 쓴다(M-DC-1). 실패하면 즉시 보관본으로 되돌리고 같은 확인을 한 뒤 멈춘다.
  5. `HD`(main, 다른 작업의 미커밋 변경이 있음)
     - `hejo-deadline-close-20261122`를 merge 커밋으로 넣는다. 충돌이 나거나 다른 작업 파일과 겹치면 멈춘다.
     - `./sync` → `./airport-check` 종료 0.
     - `git commit --only`로 이 작업 경로만 커밋한다(sync가 모은 다른 작업 파일은 커밋하지 않는다). 우리 두 파일은 sync 뒤에 merge 결과와 바이트가 같아야 한다.
     - HD 원격 push는 하지 않는다.
- **문**
  1. 지금 공용 릴리스 `RELEASE` = `e68ae82458a62a1c3d3468041c3d6dee0b576a2b`를 기록한다(롤백 기준).
  2. 릴리스 대상은 구현 worktree 브랜치를 로컬 main(`95b9041`)으로 merge한 커밋이다.
     - `e68ae824..대상`에 `gate/ hub/ schemas/ config/ install/` 변경이 이 작업(a43662d)과 문서 커밋(91ee402) 말고도 있으면 멈추고 보고한다.
  3. 그 커밋 checkout에서 `install/hejo-release` → 게이트웨이 재시작 1회(`hermes-connections gateway restart --json`).
  4. 확인: 재시작 뒤 채널 재연결, 문 로그에 `deadlines_read items=N failed=0`(M2). 실제 장부는 닫지 않는다.
  5. 되돌리기: 기록한 커밋을 임시 worktree로 꺼내 `install/hejo-release`를 실행하고 재시작한다. team-kit 보관본도 함께 되돌린다.
- **복구 조건**: 재시작 뒤 채널 재연결이 확인되지 않거나, `list --json`이 실패하거나, 문 로그에 `deadlines_failed`가 남으면 team-kit·문을 모두 보관본으로 되돌린다.
- **금지**
  - 실제 장부 닫기(사장이 앱에서 한다)
  - Slack·고객 메시지
  - 비밀 파일 열기
  - Hermes 본체 변경
  - 재시작 2회 이상
  - 다른 작업 파일 커밋
  - git push(HD 포함)

### TASK-05 앱 0.2.6(빌드 8) 공개 후보 준비 (TASK-04 성공 뒤, 고위험 · 증거 수준 2)

- 선례: HEJO-FINDER-FOLDERS handoff 23차 지시(TASK-17, 0.2.5)를 **0.2.6·빌드 8**로 그대로 따른다. 다른 점만 적는다.
- 들어가는 것: 로컬 `main`(이 작업 merge 포함)의 HEAD. 새 `public`의 부모는 지금 로컬 `public`(0.2.5, github/main `47a42456`과 같아야 한다. 다르면 멈춘다).
  - `95b9041` 뒤 main에 다른 작업의 **제품 코드**(`app/ gate/ hub/ schemas/ install/ config/`) 커밋이 들어왔으면 멈추고 보고한다(문서만이면 진행).
- 확인 추가
  1. 공개 후보 전체 시험 로그에서 AT-DC-21..34(앱), AT-DC-10~20·35(문) PASS 줄을 인용한다.
  2. 준비물 버전·빌드(0.2.6·8)가 0.2.5·7보다 크고, 업데이트 서명 키가 0.2.5와 같다.
  3. 새 `public`의 `gate/`·`schemas/`가 TASK-04 뒤 공용 릴리스 실행본과 같다(README 말고 차이가 있으면 멈춘다).
  4. 짧은 `TMPDIR`과 resolve한 임시 `HERMES_HOME`을 쓴다.
- 보고: 버전 올림 커밋, 새 `public` 전체 커밋, 준비물 경로, 사장용 명령 두 줄(`git push github <새 public 커밋>:refs/heads/main`, `install/hejo-ship publish --approve-commit <새 public 커밋> --prepared .build/release-0.2.6/prepared.json`), 검증 명령·종료 코드.
- 금지: 23차와 같다.
  - GitHub 쓰기·publish·push
  - 설치 앱 교체, 비밀 값 열람
  - 제품 동작 코드·spec·design·수락 시험 수정
  - TASK-04 밖의 공용 릴리스·운영 홈 변경
  - 앱 시험 전에는 `pgrep -f app-tests`로 남은 프로세스를 확인한다.

### 보고
`impl-report.md`에 'TASK-04'·'TASK-05' 절을 쓴다. TASK-04가 실패하면 되돌린 뒤 TASK-05를 하지 않고 result로 보고한다.
