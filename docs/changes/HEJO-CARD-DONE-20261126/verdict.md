# HEJO-CARD-DONE 판정 보고

## 1회 — TASK-01 미완료(보류 보고 확인), 원인: 환경·배치 차이

- 검토 대상: [impl-report.md](impl-report.md)(보류), 호스트 배정 worktree `role-workflow/53-17c39527` HEAD `a1a7d4c601f801c8dd6705aa9e88085d56caf88d`(추적 변경 없음, 플러그인 수집 증거와 일치), 기준 시험 로그 `<배정 worktree>/.build/card-done/`.
- 조건: 교차 모델(계획 Claude, 구현 Codex).

### 직접 확인
| 항목 | 결과 |
|---|---|
| 공개 착수 tip | `git fetch github` 뒤 `github/main` = `018036cbf24678ea3a29f826926531e8ab4d370b`. 보고와 같음 |
| 배정 브랜치와 공개 이력 | 공통 조상 없음(보고와 같음). 배정 브랜치는 개발 `main`에서 갈라져 기록 모드·영수증·`gate/history_queries.py`가 없다 |
| 기준본 실행본 | `.build/card-done/public-baseline` detached = `018036c` |
| AT-CD-11(a) | `baseline-at11a.log`: 1 passed |
| AT-CD-11(b) | `baseline-at11b.log`: `AT-CD-11b PASS` |
| AT-CD-14 Python 기준 | `baseline-gate-short.log`: 592 passed, 2 failed(`test_at_hf_08[True]`, `test_at_hf_27_install_twice_and_check`) = 착수 커밋 실패 목록으로 인정 |
| 제품·묶음 N 시험 | 없음(미실행) |

### 설계 적합성(4.2)
설계는 공개판(`github/main`) 코드를 기준으로 했고, 그 기준은 맞다. 인계서 9절 1항도 공개 tip에서 worktree를 만들라고 했다. 그런데 호스트가 개발 `main`에서 갈라진 worktree를 배정하면서 "이 폴더에서만 변경"이라고 지시해 두 지시가 충돌했다. 구현 담당이 멈춘 것은 규칙상 올바른 판단이다. 요구·설계·수락 시험에는 결함이 없다.

### 원인 분류와 조치
- 원인: 환경·배치 차이(10-planning 7절). 요구·설계·시험 오류가 아니다.
- 조치: 공개 구현 worktree를 **배정 폴더 안**에 둔다. 두 지시를 모두 만족한다. 경로 `<배정 worktree>/.build/card-done/public`, 브랜치 `hejo-card-done-public-20261126`, 시작점은 착수 시 `github/main` tip이다. 제품·시험 커밋은 이 브랜치에만 만든다. 배정 브랜치 `role-workflow/53-17c39527`에는 제품 커밋을 하지 않는다.
- 이미 확보한 기준본 기록(AT-CD-11 a·b, AT-CD-14 실패 목록, 묶음 N 빌드 불가 진단)은 tip이 `018036c` 그대로면 다시 쓴다.
- 판정: **미완료**(제품 미구현). 다음은 보완 plan이다.

## 2회 — TASK-01 합격, 작업 전체는 부분 완료(TASK-03·02 남음)

- 검토 대상: 공개 worktree `<배정 worktree>/.build/card-done/public`의 브랜치 `hejo-card-done-public-20261126`. 시험 커밋 `31bbd51b6fed0e86e3aea1a038ce60286cd8cf92`, 제품 커밋 `bd38bc47f3c7b58b3a14c4df3d0b1fd23e2e0b07`, 부모 `github/main` = `018036cbf24678ea3a29f826926531e8ab4d370b`(fetch로 재확인, 앞선 커밋 2개). 플러그인의 "변경 없음"은 배정 브랜치 기준이다. 실제 변경은 공개 브랜치에 있다(판정 1회 배치 결정).
- 조건: 교차 모델.

### 직접 확인(코드)
| 요구 | 근거 | 판정 |
|---|---|---|
| REQ-CD-01 띠 | `TodoDrawerView` `completionRect`: 마우스를 올렸을 때 종결 가능한 카드에만 생긴다. 높이 전체, 폭 44. 시간 글자는 그리지 않고 상태 줄은 띠 앞 8에서 끊는다. 종결 가능 여부는 컨트롤러 `canCompleteCard`(질문은 `canSend`·키·글 id·추적 없음, 마감은 참조·진행 중 아님, 알림은 불가)가 정한다 | 맞음 |
| REQ-CD-02 누름 | `mouseDown`: 띠 안을 누르면 `complete`, 밖을 누르면 `perform`. `completeCard`가 마감은 `closeDeadline(done)`, 질문은 `queueClose`. 대기 자리는 `PendingClose.Action` 하나이고 앞 것은 바로 `executeClose`. `stop()`은 `resetCloses`로 버린다 | 맞음 |
| REQ-CD-03 결과 | `transmit`이 카드의 `client_msg_id`를 쓴다(`confirmationID`). ① `sendText` false → `confirmationFailed`. ② `error ref`·`sync_done` 미확인 자리 → `confirmationFailed`. ③ 쓰기 직전 `awaiting(75초)` → `unresolved`(보이되 종결 불가). ④ 글 도착·영수증 accepted/deleted → `accepted(75초)`, 목록에서 빠지면 해제. 어디서도 재전송하지 않는다 | 맞음 |
| REQ-CD-05 | 질문 `확인 보내기`, 마감 `완료로 닫기` 사용자 동작 | 맞음 |
| NFR-CD-01 | 5초 상수 한 곳, `deadline_close`를 만드는 곳 한 곳, `gate`·`schemas`·`hub` 변경 없음(`candidate-at13.log`) | 맞음 |
| 화면 | `png/question-dark.png` 직접 봄: 오른쪽 초록 띠와 흰 ✓, 제목과 겹치지 않음(시안 C) | 맞음 |

### 직접 확인(시험·증거)
- 앱 시험 이름에 AT-CD-01·02·03·04·05·08a~c·09a~d·10·12가 있다. 가짜 문 시나리오 10개(confirm·deadline·undo·stop·mixed·ack·offline·reject·uncertain·reconnect)는 `candidate-card-tests.log`에서 모두 PASS, `CARD_DONE_WIRE_PASS`다. AT-CD-03b는 가짜 문 요청 글에 `approval` 버튼이 있고 `assert not gate.clicks`로 확인한다. 06·07은 mixed·stop 시나리오다.
- 묶음 B(AT-CD-11 a·b): 후보 커밋 통과. Python 회귀: 592 통과, 실패 2(착수 실패 목록과 같음).
- **한계(AT-CD-14):** `app/scripts/test.sh` 한 번 실행은 종료 1이었다.
  - 소유자 프로필 단계는 같은 시험을 따로 돌리면 통과했다.
  - "Real settings metadata changed" 가드 실패는 이 Mac에서 설치된 hejo 앱(`/Applications/hejo.app`, 실행 중 확인)이 실제 설정을 고친 데서 생긴 환경 요인으로 본다. 카드 시험은 임시 저장소만 쓴다.
  - 실패 뒤 남은 단계를 다시 돌렸을 때(`candidate-app-tail.log`) 가드는 `ACTUAL_SETTINGS_METADATA_UNCHANGED`로 통과했다.
  - 착수 커밋에서 앱 전체 스크립트를 돌린 기록은 없다. 그래서 TASK-03 뒤 최종 검증 때 앱 전체 스크립트를 착수 커밋과 후보에서 같은 조건으로 다시 비교한다.
- **명세 차이(경미, TASK-02에서 반영):** 공개 기록 모드는 `sync_done`을 주고받지 않는다. 그래서 REQ-CD-03 ②의 "재연결 뒤 `sync_done` 실패"는 기록 모드가 아닌 경로에만 해당한다. AT-CD-09c는 그 기존 자리를 수신 경로로 확인했다. 기록 모드의 재연결 결과는 영수증(③→④)으로 정해진다. 코드는 기존 자리에 연결만 했으므로 고칠 것이 없다.

### 설계 적합성(4.2)
칸(관제 화면만), 원본 하나(대기 자리·5초·프레임), 기존 경로 판정(유지·통합)이 design 2판과 맞는다. 덧댄 두 번째 경로는 없다. `confirmations` 항목이 미확정(③) 상태로 오래 남을 수 있지만, 메모리에만 있고 스레드 삭제·재설정 때 지워지므로 차단 사유가 아니다.

### 판정
- TASK-01: **합격**(구현 완료, 증거 수준 2. AT-CD-14 앱 전체 비교는 최종 검증에서 다시 한다).
- 작업 전체: **부분 완료**. TASK-03(3판 D-06·D-07)과 TASK-02가 남았다. 원인 분류: 요구 추가(사용자 승인 D-06·D-07, 2026-11-26)이며 구현 결함이 아니다.

## 3회 — TASK-03 합격, 작업 완료(현재 명세 반영 포함)

- 검토 대상: 공개 브랜치 `hejo-card-done-public-20261126`. TASK-03 시험 커밋 `2a467a2441a39d24a99a3db877c27f4080c0683e`, 제품 커밋 `2172446addadc9a34a592ac8d30c6203f6acb0a3`. 부모 사슬은 `bd38bc4` → `31bbd51` → `github/main` `018036c`(fetch로 재확인).
- 조건: 교차 모델.

### 직접 확인
| 요구 | 근거 | 판정 |
|---|---|---|
| REQ-CD-06 알림 ✓ | `canCompleteCard` `.alert` → 대화 키가 있으면 가능. `completeCard` `.alert` → 기존 `model.markNoticeRead(key)`(직접 선택과 같은 경로). 대기 자리·되돌리기·`send`를 쓰지 않는다. VoiceOver 이름은 `읽음으로 표시` | 맞음 |
| CD-06.AC-03 재누름 1건 | `HistoryCoordinator`: 같은 키의 `notice` 계획이 진행 중이면 합친다(`activeNoticeRead`). 변이 시험에서 중복 방지를 빼면 추가 `notice`가 잡힌다(`task03-refresh-disabled.log` 종료 1) | 맞음 |
| CD-06.AC-02 실패 | `strip-fail` 시나리오 통과(키 변화 없음, 카드 남음) | 맞음 |
| REQ-CD-07 | AT-CD-18 = 6개 상태(automatic·new-alert·home·staff·group·refreshing) × 3개 입구(mouse·thread·enter) = 18개. 착수 `018036c`와 `bd38bc4`에서 모두 통과(`at18-baseline.log`) → 결함 재현 안 됨. AC-03에 따라 제품을 고치지 않았다 | 맞음(재현 안 됨) |
| 화면 | `task03-alert-png/alert-dark.png` 직접 봄: 알림 카드 오른쪽 초록 띠와 ✓ | 맞음 |

### 회귀(AT-CD-14, 2회 한계 해소)
- `app/scripts/test.sh` 전체: 착수와 후보를 같은 조건으로 돌려 둘 다 종료 0. 후보는 `APP_TEST_OK` 33개, 착수는 23개(새 시험 10개 묶음 차이). 설정·다운로드 가드도 둘 다 통과.
- Python: 592 통과, 실패 2(착수와 같음). `scan_private`, AT-CD-11 a·b, AT-CD-13, `git diff --check` 모두 종료 0.

### 설계 적합성(4.2)
알림 띠는 새 읽음 경로를 만들지 않고 기존 `markNoticeRead`를 쓴다. `HistoryCoordinator`의 합치기는 같은 키의 `notice` 중복만 막고, 직접 선택 경로에도 같게 적용된다(새 부작용 없음). 칸·원본은 design과 맞다.

### 남은 사실(사장 확인 필요)
REQ-CD-07의 "직접 눌렀는데 안 사라짐"은 하네스로 재현되지 않았다. 실제 사례(어느 방, 어떻게 눌렀는지, 앱 버전)가 있어야 더 조사할 수 있다. 이 작업의 완료 조건은 AC-03(재현 안 되면 보고)에 따라 충족했다.

### 판정
- TASK-03: **합격**. TASK-02: 현재 명세 반영 완료(`docs/spec/current/hejo-thread-status.md` "가운데 창 카드 ✓ 띠" 절). 작업 문서 상태는 "적용".
- 작업 전체: **완료**(교차 모델). 설치 앱 반영은 별도 릴리스 작업이다.
