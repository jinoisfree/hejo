## 검증 판정: HEJO-DEADLINE-CLOSE / TASK-01~03 (검증 1차, 2026-11-22)

1. **판정: 부분 완료**

2. **검증 조건**
   - 교차 모델: 구현은 claude-sonnet-5-5, 검증은 계획 담당 claude-opus-5-5(다른 모델, 구현 미참여).
   - 검토한 코드 상태
     - 이 저장소: worktree `.worktrees/31ptpirh/role-workflow-16-a3ea9587`, 브랜치 `role-workflow/16-a3ea9587`, 기준 `0644e9e`, 커밋 `a43662d`(TASK-02)·`0c85496`(TASK-03).
     - 운영 저장소: worktree `.worktrees/31ptpirh/hd-deadline-close`, 브랜치 `hejo-deadline-close-20261122`, 기준 `eee573e6`, 커밋 `cfe6d9d2`(TASK-01).
   - impl-report는 상태 블록 보고로 받았고, 아래 사실은 코드·실행으로 다시 확인했다.

3. **설계 적합성(4.2)**: 적합. 근거는 아래와 같다.
   - **문**
     - 세대별 읽기 공유(`gate/deadlines.py` `list`/`_reads`/`close_generation`): 닫기 실행 뒤 `finally`에서 응답 전에 세대를 올린다. REQ-DC-04 AC-07을 충족하고 AT-DC-16c가 실제 `Deadlines.list` 경로로 관측한다.
     - 잠금 대기 20초 만료 → 자식 프로세스 없이 `busy`, 실행 40초(AC-03, AT-DC-16b).
     - 연결과 분리된 shield 실행(AC-04, AT-DC-15).
     - 검증 실패면 행동 기록 없음(AC-02, AT-DC-13). 프레임은 `CLIENT_VALIDATOR`가 규격으로 먼저 거른다(`server.py` `parse`).
   - **team-kit**
     - `perform` close가 잠금 안에서 `closed_now`를 돌려준다. `handle`은 `ok and closed_now`일 때만 다시 칠한다. `close_main`은 `closed_now`일 때만 다시 칠한다. AT-DC-09b가 실제 `handle(kind="chat")`과 CLI를 두 순서로 관측한다.
   - **앱**
     - `pendingClose`/`closesInFlight`/`closesConfirming`를 카드별로 둔다.
     - 확인 번호 = 성공 직후 강제 목록 요청 번호다. 앞 번호 응답은 `lastAppliedSeq`로 통째로 버린다(AC-04·10·11, AT-DC-27b·c·d).
     - 1:1 방 분기를 지웠다(`ConversationView.swift:16-17`, AT-DC-25).
   - **설계와 달라진 점**(보고됨, 수락)
     - `close_main` 잠금 전 읽기: 없는 id·이미 닫힘에는 잠금 파일·장부를 만들지 않는다. 최종 판정은 여전히 `perform`이 잠금 안에서 한다. AT-DC-05·06의 "홈 불변"과 맞는다.
     - 인자 오류 `INVALID_ARGUMENTS` 종료 1: AT-DC-07이 허용하는 형태다.
     - `Card.noticeID`를 만들지 않고 `key`·`messageID`를 재사용: 같은 정보라 수락한다.
     - `controller.stop()` 신설: AC-06의 앱 종료 미전송 요구를 충족한다(AT-DC-34).

4. **직접 확인한 것**(증거 수준 2 = 대역 통합, 요구 수준 2 도달)
   - 문 수락 시험: `pytest tests/acceptance/test_deadline_close.py tests/acceptance/test_deadlines.py` 33 passed, 종료 0(`/tmp/dcv-gate-accept.log`).
   - team-kit: `pytest tests/test_deadline_close.py tests/test_deadline_list.py tests/test_deadline_watch.py` 60 passed, 종료 0(`/tmp/dcv-tk.log`).
   - 문 전체: `pytest gate/tests tests/acceptance` 452 passed, 3 failed, 종료 1(`/tmp/dcv-gate-all.log`).
     - `test_delivery_parity::test_native_labels…`, `test_at_hf_08[True]`: 같은 환경에서 기준 `0644e9e`(계획 담당 checkout)에서도 실패했다(환경, 기술 부채).
     - `test_at_sm_02…`: V-2.
   - 앱: `TZ=Asia/Seoul bash app/scripts/test.sh`(HEJO_PYTHON=Hermes venv) 종료 0, `AT-DC-21..34 … PASS`(`/tmp/dcv-app.log`).
   - 수락 시험 무단 변경 없음: 이 저장소에서 바뀐 수락 시험은 계획 담당이 고친 `test_deadlines.py` 한 줄과 새 `test_deadline_close.py`뿐이다. 운영 저장소 `test_deadline_list.py`는 AT-DC-08이 허용한 키 집합 변경이다.
   - 안내판 변경은 추가만 했다(`git diff 0644e9e -- schemas` 삭제 줄 0).
   - 시험 환경: pytest는 `PYTHONPATH=~/.local/share/hermes-pytest:<계획 폴더>/.build/task02-deps`, `--basetemp`, `TZ=Asia/Seoul`.

5. **지적 목록**
   - **V-1**
     - 위치: `app/Sources/TodoDrawerModel.swift` `originNames`
     - 위반 기준: REQ-DC-02 AC-01(출처 이름 `calendar`→캘린더, `slack`→Slack)
     - 근거: 코드가 `"calendar":"일정"`, `"slack":"슬랙"`이다. 보고된 차이가 아니고, AT-DC-21은 미리알림·메일만 관측해서 잡지 못했다.
     - 등급: 차단(요구 불일치·미보고) · 보낼 곳: 구현
   - **V-2**
     - 위치: `tests/acceptance/test_slack_move_gate.py:59` AT-SM-02의 안내판 sha256 고정
     - 위반 기준: 수락 시험 오류(10-planning 7절)
     - 근거: AT-SM-02의 해시 조건은 "HEJO-SLACK-MOVE 작업 전과 같음"이라는 그 작업 범위의 불변 조건이다(HEJO-SLACK-MOVE.md 14행). 이후 안내판을 합법적으로 바꾸는 작업(이번 추가 166줄, 삭제 0)마다 반드시 실패한다. 새 해시 `4f365159c687db76249fed494627764f2e8fe741e89a56471642fe983371b7ce`는 검증자가 직접 계산해 일치를 확인했다.
     - 등급: 차단 · 보낼 곳: 기획설계 → 결정함
     - 처분: 계획 담당 결정. 고정 해시를 새 값으로 바꾸고 주석으로 사유를 남긴다. 명세 행에 갱신 사유를 적었다(`tests/acceptance/HEJO-SLACK-MOVE.md`). 코드 줄 교체는 구현 worktree 브랜치에 있어야 하므로 이번 보완 지시에서 구현 담당이 그대로 옮긴다(기대값 소유는 계획 담당).
   - 비차단: 없음.
   - 기술 부채: 위 기준 실패 2건(yaml·환경 의존).

6. **기획설계로 넘긴 것**: V-2(위 처분으로 해결).

7. **미검증 범위와 남은 위험**
   - 실환경(증거 3·4)은 TASK-04 범위다. M-DC-1·2는 미실행이다.
   - 운영 저장소 구현 브랜치 `hejo-deadline-close-20261122`는 운영 main에 아직 반영되지 않았다. TASK-04 전에 합치기 절차가 필요하다.
   - 병행 작업 HEJO-DRAWER-INLINE(같은 할 일 칸 앱 코드)이 이 작업의 TASK-03 반영 뒤 기준으로 착수하기로 돼 있다(그 design 머리말). 이 작업의 main 반영 순서를 그 작업 계획 담당과 맞춰야 한다.
   - `bash scripts/test.sh` 전체는 기준 실패 2건 때문에 `set -e`로 중간에 멈춘다. 구성 요소(pytest·앱 시험)를 각각 실행해 대신했다.

8. **미완료 원인 분류**
   - V-1 = 구현 오류.
   - V-2 = 수락 시험 오류(계획 담당이 결정함).
   - 완료까지 남은 조건: 보완 지시 1의 V-1 수정, V-2 줄 교체, 재시험 통과, 검증 2차.

9. **현재 명세 반영 요청**: 완료 판정 뒤에 한다(tasks.md "반영" 행).

---

## 검증 판정: HEJO-DEADLINE-CLOSE / TASK-01~03 (검증 2차, 2026-11-22)

1. **판정: 완료**(TASK-01~03 범위). TASK-04 서버 적용·TASK-05 공개·REQ-DC-06은 계획상 이번 지시 밖이다.

2. **검증 조건**
   - 교차 모델: 구현 claude-sonnet-5-5, 검증 claude-opus-5-5.
   - 검토한 코드 상태
     - 이 저장소: `role-workflow/16-a3ea9587` @ `54272ad03e7fa7e6c197effbc8f5892c5d926e1d`(기준 `0644e9e` = 로컬 main, 조상 확인).
     - 운영 저장소: `hejo-deadline-close-20261122` @ `cfe6d9d2`(1차 이후 변경 없음, 1차 검증 결과 재사용).

3. **설계 적합성(4.2)**: 1차 판정 그대로 적합하다. 보완 1은 표시 문자열과 시험 기대값만 바꿨고, 구조·계약 변경은 없다.

4. **직접 확인한 것**(증거 수준 2 도달)
   - `git diff 0c85496 54272ad`: 지시한 세 가지뿐이다.
     - `originNames`의 `calendar`→캘린더, `slack`→Slack.
     - AT-DC-21b(6종 + 모르는 값, 기대값은 spec 문자열).
     - AT-SM-02 해시 줄과 주석. 다른 줄은 바뀌지 않았다.
   - `pytest gate/tests tests/acceptance` @54272ad: 453 passed, 2 failed(기준 환경 실패 2건뿐, 1차에서 `0644e9e`로 동일 확인), 종료 1(`/tmp/dcv2-gate-all.log`).
   - `TZ=Asia/Seoul bash app/scripts/test.sh` @54272ad: 종료 0, `AT-DC-21..34 … PASS`(`/tmp/dcv2-app.log`).
   - `scan_private.py`(Hermes venv): 종료 0.

5. **지적 처분**
   - V-1: 수정, 수락.
   - V-2: 계획 담당 결정대로 수정, 수락.
   - 미해결 차단 없음. 기술 부채는 기준 환경 실패 2건(기록만).

6. **기획설계로 넘긴 것**: 없음.

7. **미검증 범위와 남은 위험**
   - 실환경 M-DC-1·2(증거 3·4)는 TASK-04에서 한다.
   - 운영 저장소 브랜치를 운영 main에 합치는 절차가 남았다.
   - 원격 `github/main`은 공개판 이력이라 `54272ad`의 조상이 아니다(로컬 main 511커밋 분기). 원격 반영은 이 브랜치를 바로 올리지 않고 기존 공개 절차로 한다.
   - 병행 HEJO-DRAWER-INLINE과 main 반영 순서를 조율해야 한다.

8. **미완료 원인**: 해당 없음.

9. **현재 명세 반영 요청**: tasks.md "반영" 행.
   - ARCHITECTURE 3절 직원 사물함 쓰기 주체에 "사장(문 경유, 마감 닫기)"을 더한다.
   - TD spec REQ-TD-04 AC-02·03에 대체 표시를 한다.
   - 이 작업 문서 상태를 "적용"으로 바꾼다.
   - 반영 시점은 서버 적용(TASK-04)으로 Baseline이 된 뒤다. 그 전까지 tasks에 남긴다.
