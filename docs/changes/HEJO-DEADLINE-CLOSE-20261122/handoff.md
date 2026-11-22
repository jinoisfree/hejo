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
