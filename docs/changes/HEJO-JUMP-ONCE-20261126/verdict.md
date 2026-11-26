## 검증 판정: HEJO-JUMP-ONCE-20261126 TASK-01(가정 확인 단계) / 카드 누름 한 번 이동·미리 받기·갱신 표시

1. **판정: 미완료** (2026-11-26) — 구현 담당이 인계서 9절 2번의 멈춤 조건대로 제품 수정 전에 멈췄다. 구현 잘못이 아니다.
2. **검증 조건:** 교차 모델(설계·검증과 구현이 다른 모델, 다른 대화). 검토한 상태: 공개 worktree `../.worktrees/hejo-jump-once-public-20261126`, 브랜치 같은 이름, HEAD `018036cbf24678ea3a29f826926531e8ab4d370b`(= base_commit), 미커밋 변경은 시험 두 파일(`app/Tests/HistoryAutoloadFixture.py`, `app/Tests/HistoryAutoloadHarness.swift`)뿐.
3. **설계 적합성(4.2):** 판정 대상 없음(제품 코드 변경 0). 대신 **설계 가정 G-2가 성립하지 않음을 확인했다.** 설계(design 2판 3.2 "보이는 방에 이미 그려진 스레드는 대상 글 본문만 채우고 글 구성을 바꾸지 않는다")로는 REQ-JO-02.AC-01(받는 범위의 모든 카드 대상이 준비됨)을 충족할 수 없다.
4. **직접 확인한 것**
   - `git -C <worktree> status`·`log`·`diff --stat`: 제품 소스 변경 없음, 시험 두 파일 +145/−5.
   - 코드(base_commit): 스레드는 답글을 이어진 한 구간(`history.messagePageIDs`)만 그린다(`ConversationModel.swift` `historyReplyIDs`). 글 지정 열기는 그 구간을 통째로 바꾸고 구간 밖 글을 메모리에서 지운다(`applyHistoryMessages` → `mergeHistoryReplyPage`의 `merge == .open, state.anchor != nil` → 교체, `obsolete` 삭제). 본문만 넣는 `applyHistoryBody`는 구간 순서를 건드리지 않는다. 구현 보고의 설명과 일치한다.
   - 로그 `.build/jump-once/baseline.log`: `G-2 body-only resident=true composition-preserved=true target-frame=false`, `G-2 anchored page changes visible composition=true target-frame=true`, `AUTOLOAD PASS jump-assumptions`, `1 passed`.
   - G-1(방 목록 없이 대상 스레드 하나 먼저 그리기): 성립한다는 보고와 근거(`history.summaries` 기반 렌더링)를 코드 위치로 확인했다. 위치 유지·시간 판정(AT-JO-07·12)은 아직 미실행이다.
   - 직접 재실행한 시험: 없음(제품 변경이 없고 로그와 코드가 일치해 반복하지 않았다).
5. **수락 시험 상태:** AT-JO-01~17 코드 미작성(가정 진단 1건만 작성), 미실행. 기준본 기록 중 AT-JO-17만 남김.
6. **원인 분류:** 설계·계약 오류(요구 불변으로 고칠 수 있는지에 따라 요구 변경이 될 수 있음). 가정 G-2가 틀렸다. 대화 스레드는 "최근 쪽" 또는 "지정한 글 주변" 한 구간만 가지므로, 지금 보이는 구간 밖의 오래된 답글을 화면을 바꾸지 않고 미리 준비해 둘 자리가 없다.
7. **선택지(사용자 결정 필요, D-01의 보장 범위에 닿음)**
   - A. 미리 받기는 각 대화의 최근 쪽(또는 이미 보이는 구간)과 원문·대상 글 본문까지. 대상 글이 그 구간 안이면 바로 이동, 구간 밖의 오래된 답글이면 누른 뒤 받아 한 번 이동(REQ-JO-01.AC-02). 새 저장 자리 없음, 기존 자동 불러오기 규칙 재사용.
   - B. 구간 밖 대상의 "글 주변 쪽"을 따로 보관했다가 누를 때 적용. 모든 카드가 바로 이동하지만 보관분의 유효성(읽음이 바뀔 때마다 문맥이 바뀌어 다시 받아야 함), 메모리, 중복 요청 규칙을 새로 설계해야 하고 요청 수가 늘어난다.
8. **다음:** 사용자 결정 뒤 spec REQ-JO-02(AC-01~03·07), design 3.2·8절, AT-JO-11~13, handoff를 3판으로 고치고 다시 인계한다. TASK-02(한 번 이동)·TASK-04(표시)는 이 결정과 무관하지만, 같은 파일을 고치므로 3판 인계 한 번으로 묶어 재개한다.
9. **남은 위험:** 읽음 변화로 문맥이 바뀔 때 글 지정 열기가 사라지는지는 미검증(구현 보고). TASK-01 재개 때 확인 항목으로 유지한다.

---

## 검증 판정 2회차: TASK-01(3판 재개, 가정 확인·기준본 대조)

1. **판정: 미완료** (2026-11-26) — 구현 담당이 인계서 3판의 멈춤 조건대로 제품 수정 전에 멈췄다. 구현 잘못이 아니다.
2. **검증 조건:** 교차 모델. 검토한 상태: 공개 worktree `../.worktrees/hejo-jump-once-public-20261126`, HEAD `018036cbf24678ea3a29f826926531e8ab4d370b`(= `github/main`, base_commit 그대로), 미커밋 변경은 시험 두 파일(`app/Tests/HistoryAutoloadFixture.py`, `app/Tests/HistoryAutoloadHarness.swift`)뿐. 제품 소스·`gate`·`schemas`·`hub`·`docs/spec/current` 변경 없음(구현 보고의 `git diff --exit-code` 종료 0, `git status`로 직접 확인).
3. **설계 적합성(4.2):** 판정 대상 없음(제품 변경 0). 대신 **설계 가정 G-3이 성립하지 않음을 확인했다.** design 3판 3.4의 "써지는 중 조각은 미리보기·순서용 값만 바꾼다"는 틀렸다.
4. **직접 확인한 것**
   - `.build/jump-once/g3-baseline.log`: 첫 조각("생각 중…" → 본문)에서 `unread` 0→1, `alerts` 0→1, `bell` null→true, `notice` 생김, `title`·`rootPreview` 변경. 둘째 조각(본문 → "승인해 줘")에서 알림이 질문으로 바뀜(`group` alert→question, `questions` false→true, `alerts` 1→0).
   - 문 코드 `gate/history_queries.py`: 안 읽음은 `not thinking(text)`만 보고 `final`을 보지 않는다(146행). 질문은 본문의 승인 문구 판정(`approval`, 20-30행)으로 정한다(45-47행). 로그와 일치한다.
   - `.build/jump-once/v3-final-baseline.log`: 맨 위 대상(목표 0으로 잘림)은 `AT-JO-09 FAIL moves=1 rebounds=2`와 `PASS moves=1 rebounds=0`(진행 중 갱신 보류 변형)이 모두 나왔고, 중간 대상은 `AT-JO-09 FAIL moves=2 rebounds=2`. 경계 대상은 판정이 흔들리고 중간 대상은 기준본 기대(실패)와 맞는다.
   - 직접 재실행한 시험: 없음(제품 변경이 없고 로그·코드가 보고와 일치).
5. **원인 분류**
   - GAP-JO-02 G-3 불성립: **설계·계약 오류 → 요구 조정**. 써지는 중에 바뀌는 집계를 언제 보여 줄지 사용자 결정이 필요했다. 2026-11-26 사용자가 기획설계 추천을 받아들여 D-11 "답이 끝난 뒤 한 번"으로 정했다.
   - AT-JO-09(와 같은 입력을 쓰는 AT-JO-01): **수락 시험 오류**. 대상이 목록 경계로 잘릴 수 있게 적어 기준본 판정이 흔들렸다. 구현 잘못이 아니다.
6. **수정(4판, 기획설계가 함)**
   - spec REQ-JO-04 본문·AC-03·05·06: 써지는 중 집계 변화도 끝 조각 뒤로 미룬다. 끝난 뒤 값은 기준본 최종값과 같다(승인 요청 전이 포함).
   - design 2절 정정 행, 3.4(앱이 문의 판정 규칙을 흉내 내지 않음), 6절 대안 G 기각, 8절 G-3 처리.
   - 수락 시험: 관측 절에 "가운데 대상"(두 목표가 경계에서 300pt 이상, 서로 50pt 이상 다름)과 "표본 시작"(누름 직전 원점, 진행 중 갱신 끝난 뒤 누름)을 추가. AT-JO-01·09 보완, 경계 대상은 AT-JO-01b(기록)로 분리. AT-JO-18에 "생각 중" → 본문, 본문 → 승인 요청 전이를 넣고 사이 구간 표시 유지·끝난 뒤 값 일치를 판정.
   - tasks: GAP-JO-02, 시험 오류 기록, D-11, TASK-01 재개 조건. handoff 4판.
7. **다음:** 4판 계획 검증 → 승인 뒤 구현 담당이 같은 worktree에서 TASK-01을 이어 4판 입력으로 기준본을 다시 남기고 TASK-02~06을 진행한다. 착수를 막는 가정은 더 없다.

---

## 검증 판정 3회차: TASK-01(4판 재개, 기준본 대조)

1. **판정: 미완료** (2026-11-26) — 구현 담당이 수락 시험 입력 문제로 제품 수정 전에 멈췄다. 구현 잘못이 아니다.
2. **검증 조건:** 교차 모델. 공개 worktree HEAD `018036cbf24678ea3a29f826926531e8ab4d370b`(= `github/main`), 미커밋은 `app/Tests/HistoryAutoloadFixture.py`·`HistoryAutoloadHarness.swift`뿐(직접 `git status` 확인). 제품·`gate`·`schemas`·`hub`·`docs/spec/current` 변경 없음.
3. **설계 적합성(4.2):** 판정 대상 없음(제품 변경 0). 설계 결함은 새로 나오지 않았다.
4. **직접 확인한 것**
   - `.build/jump-once/v4-baseline.log`: AT-JO-01(가운데 대상, 카드 목표 1079.5pt·글 목표 1004pt) `FAIL moves=1 rebounds=1 settleFrame=31`, AT-JO-09 `FAIL moves=2`(1111.5pt 거쳐 1004pt), AT-JO-01b `moves=1 rebounds=1 settleFrame=33`. 기준본 기대(01·09 실패, 01b 기록)와 일치한다. 세 경우 모두 누른 직후 원점이 2368→2400pt로 32pt 반대로 움직인다(되튐 원인 후보, TASK-02에서 확인).
   - `.build/jump-once/v4-at-jo-18-contract.log`: 첫 글 `message final=absent`, `final:false`를 넣은 사본은 `Additional properties are not allowed`, 후속 `edit final=false`. `schemas/hejo-wire-v1.json` 686행 `message` 정의 확인.
   - 입구 자료: `IslandModel.Action.worker`와 `ConversationView.openFromBubble`은 `ConversationKey`만 받는다(구현 보고, 이전 회차에서 `ConversationView.swift:311-315, 539-545` 직접 읽음).
   - 직접 재실행한 시험: 없음(제품 변경 없음, 로그·코드가 보고와 일치).
5. **원인 분류:** 수락 시험 오류 2건(기획설계). AT-JO-18 첫 프레임 입력이 공개 규격과 충돌, AT-JO-08이 글 id 없는 입구에 글 대상 조건을 적용.
6. **수정(5판):** spec 4절 '준비됨'(카드 대상 정의 추가)·REQ-JO-01.AC-08, 수락 시험 관측 절 '가운데 대상'·AT-JO-08·18, tasks 기록, handoff 5판. 요구와 사용자 결정은 그대로다.
7. **다음:** 5판 계획 검증 뒤 구현 담당이 TASK-01을 이어 AT-JO-08·18 기준본을 남기고 TASK-02~06을 진행한다. 4판 AT-JO-01·01b·09 기준본은 재사용한다.

---

## 검증 판정 4회차: TASK-01~06 구현

1. **판정: 부분 완료** (2026-11-26) — 요구 대부분을 직접 실행으로 확인했으나 수락 시험 AT-JO-04 한 항목이 검증자 실행에서 재현되지 않는다(차단 1건).
2. **검증 조건:** 교차 모델(구현 codex, 검증 이 대화). 검토 대상: 공개 worktree `../.worktrees/hejo-jump-once-public-20261126`, 브랜치 같은 이름, HEAD `6e92d277805ff2a253f4fda83896d2dfa03adf4e`(기준 `018036cbf24678ea3a29f826926531e8ab4d370b` = `github/main`), 작업 트리 깨끗함. 커밋 5개: `950181b` 시험, `755bf64` 이동, `c36ceab` 미리 받기, `629df5e` 표시, `6e92d27` 집계.
3. **설계 적합성(4.2):** 적합(아래 V-4 한 경계 제외).
   - 이동: E1~E5가 `navigate(to:message:)` 하나로 모였고 `scrollTo`는 감속 이동 하나가 매 프레임 대상 틀로 목적지를 다시 잡는다. 준비 안 된 대상은 `beginTargetPositioning`으로 원점을 잡아 두고 글이 그려진 뒤 `resolveNavigation`이 한 번 이동한다(D-07). 리더 입력은 `onReaderInput` → `cancelNavigation`. `pendingRevealScroll`·`openingEntry`·세 번 예약 제거. 남은 `history.scrollTo` 직접 호출은 펼치기·답글 열기·초안 복원·답글 쓰기·이동 실행뿐(AT-JO-17).
   - 미리 받기: `updateCardTargets`가 카드창 보이는 카드와 위아래 한 화면을 넘기고, 조정자는 기존 `AutoLoad.thread/.root/.content`만 쓰며 글 지정 열기를 쓰지 않는다(D-08). 실패는 `failed(quiet:true)`로 조용히 남는다.
   - 표시: 목록의 `history-status` 카드와 카드창 경고 줄 삽입이 지워졌고, ↻(`historyRefreshMark`)가 카드창 제목 줄·대화창 제목 줄에, 실패·안내는 아래쪽 떠 있는 줄에 있다(D-09). PNG 세 장 확인(아래 7).
   - 집계: `ConversationModel.affectsHistoryAggregates` 하나를 `apply`와 `onHistoryFrame`이 함께 쓴다. 써지는 중 조각만 제외하고 문의 판정을 흉내 내지 않는다(D-10·D-11).
   - 설계와 달라진 점: 카드 미리 받기의 `.thread` 요청은 원문을 따로 다음 후보로 받는다(설계 범위 안). 펼치기 위치는 기존 최종 위치를 지키려고 `keepCentered`를 둔다(AT-JO-10 기준값과 일치).
4. **직접 실행한 것** (증거 수준 2, 로그는 worktree `.build/jump-once/verify/`)
   - `HEJO_HISTORY_SPARKLE=… bash app/Tests/HistoryTransport.sh` 종료 0(`build.log`).
   - `JUMP_ONCE_VERIFY_REFERENCE=1 pytest app/Tests/HistoryAutoloadFixture.py -k jump --basetemp=/tmp/jov` → **35 통과, 1 실패**(`acceptance.log`). 실패는 `jump-input-cold-wheel`(AT-JO-04 나, maxDifference=80). 그 밖의 판정 줄: AT-JO-01·01b·09 이동 1회·되튐 0·15프레임(0.25초) 이내, AT-JO-02·06·08 대기 중 이동 0·뒤 1회, AT-JO-05·07 통과, AT-JO-10 펼치기 2838.5·전송 5583·진입 0.32(기준 ±1pt), AT-JO-11 11/11·글 지정 0·구간·원점 유지, AT-JO-12 같은 방 15프레임·다른 방 0프레임·구간 밖 대기 후 1회, AT-JO-13 통과, AT-JO-14·15 위치 변화 0·재조회 0·재시도 1, AT-JO-18 세 입력 통과(일반: 도중 집계 요청 0·표시 변화 0·글 변화 31·끝난 뒤 개요 1).
   - 같은 명령 `-k "not jump"`(기존 자동 불러오기 회귀) 37 통과, 종료 0(`regression.log`).
   - `jump-input-cold-wheel` 단독 반복: 판정 강제 없이 4회 중 1회 maxDifference=89(`cold-wheel-repeat.log`), 판정 강제로 6회 모두 0(`cold-wheel-1..6.log`). 합계 11회 중 2회 실패.
   - `scripts/scan_private.py --home <임시 홈>` 종료 0(`scan.log`).
   - 구현자 로그 확인(재실행 안 함): `bash scripts/test.sh` 593 통과·1 실패(`test_at_hf_27_install_twice_and_check`, 착수 기준과 같음), `bash app/scripts/test.sh`는 `APP_TEST_OK` 뒤 설정 메타데이터 가드에서 종료 1. 메타데이터 변경 시각(21:27:55)이 시험 실행 파일 생성(21:29:23)보다 앞서 실행 중인 운영 앱의 변경으로 보인다는 구현자 설명과 로그 시각이 맞는다.
5. **지적**
   - **V-1 (차단, 구현)** `app/Tests/HistoryAutoloadFixture.py:380-409` AT-JO-04(REQ-JO-01.AC-04 나). 근거: 실패 실행에서 본 실행은 2119→2199(휠 +80)→2288(본문 도착 +89), 대조 실행은 2279에서 시작해 휠 이동 없이 +89만 있었다. 대조 실행이 본 실행의 시작 원점(`controlOrigin`)에 놓이지 않았고 휠 입력도 반영되지 않았다 — 제품이 아니라 대조 실행 준비 문제로 보이지만, 이 상태로는 AC-04를 판정할 수 없다. 또 이 판정은 `JUMP_ONCE_VERIFY_REFERENCE=1`일 때만 assert되어 기본 실행에서는 FAIL을 출력하고도 통과한다.
   - **V-2 (비차단, 구현)** `app/Sources/ConversationView.swift:504-505` `entry()`에 `cancelNavigation()`이 두 번 있다.
   - **V-3 (비차단, 구현)** `HistoryAutoloadHarness.swift:603` 오류·축출 변형(`jump-prefetch-error`·`-budget`)에서 판정 대상이 아닌 AT-JO-11 줄이 `FAIL`로 찍힌다(10/11, 2/11). 해당 변형에서는 "기록"으로 찍어 판정 줄과 구별한다.
   - **V-4 (비차단, 기획설계→구현)** `HistoryCoordinator.holdsNavigationMessage`: 조정자의 이동 요청은 도착 뒤에도 리더 입력·새 이동 전까지 남아, 그동안 갱신이 선택 스레드의 최신 쪽 요청을 건너뛴다. 다시 연결(새 세션)에서도 건너뛰면 끊긴 사이의 그 스레드 변경을 놓칠 수 있다. 설계 3.2의 "대상 글이 그려져 있는 동안" 조건에 "같은 연결 안에서"를 더한다.
6. **판정 근거:** REQ-JO-01~04의 다른 AC와 NFR-JO-01~03은 직접 실행으로 충족을 확인했다. V-1이 남아 AC-04(나)를 판정할 수 없다.
7. **사용자 확인 대기:** AT-JO-15 시안 PNG(`.build/jump-once/refresh.png`, `failure.png`, `drawer-read-failure.png`)의 ↻ 자리와 아래쪽 안내 줄 모양(D-06). 검증자가 본 바로는 ↻가 카드창 ✕ 옆과 대화창 오른쪽 위에, 실패 안내는 대화 목록 아래쪽 떠 있는 줄로 있다.
8. **푸시:** 대상 커밋 `6e92d27`은 이 판정으로 푸시를 제안하지 않는다. 수정 커밋 뒤 다시 판정한다.

---

## 검증 판정 5회차: 4회차 지적 처분 확인 (최종)

1. **판정: 완료** (2026-11-27)
2. **검증 조건:** 교차 모델(구현 codex, 검증 이 대화). 검토 대상: 공개 worktree `../.worktrees/hejo-jump-once-public-20261126`, 브랜치 `hejo-jump-once-public-20261126`, HEAD `708a6dadf22f0840c4a07195e8f5647e856433ad`(4회차 대상 `6e92d27` 위 수정 커밋 1개, 기준 `018036cbf24678ea3a29f826926531e8ab4d370b` = `github/main`), 작업 트리 깨끗함.
3. **설계 적합성(4.2):** 적합. 4회차 판정(이동 통합·최근 쪽 미리 받기·↻와 아래쪽 안내·집계 판단 함수 공유)을 그대로 재사용한다(바뀐 제품 코드는 아래 두 곳뿐). V-4 처분으로 설계 3.2의 글 보존 조건이 "같은 연결 안에서"로 좁혀졌다(4회차에서 기획설계가 요청한 그대로).
4. **지적 처분**
   - V-1 수정 수락: 대조 실행이 본 실행의 입력 직전 원점에 놓였는지(0.5pt) 확인하고, 입력이 목록의 리더 입력 감시(`onReaderInput`)에 닿았는지와 휠이 80pt 움직였는지 확인하지 못하면 시험 준비 오류로 실패한다. 최대 차이 판정은 환경 변수와 무관하게 항상 assert한다. 기대값·허용 오차(0.5pt)는 그대로다. 휠 입력은 데스크톱 커서를 옮기는 HID 이벤트 대신 목록의 `scrollWheel(with:)`에 실제 `NSEvent`를 넘긴다. 리더 입력 판정은 그 메서드(`NativeThreadList.swift:347-349` → `readerInput`)에서 하므로 검사할 제품 경로는 그대로이고, 운영자의 실제 마우스 커서를 움직이지 않게 됐다. 클릭·방향키는 앱 이벤트 배송 경로를 그대로 쓴다.
   - V-2 수정 수락: `entry()`의 중복 `cancelNavigation()` 제거.
   - V-3 수정 수락: 오류·축출 변형의 AT-JO-11 줄은 "기록"으로 찍힌다.
   - V-4 수정 수락: 조정자의 이동 요청이 연결(`session`)을 기억하고, 새 연결에서는 선택 스레드의 최신 쪽을 다시 받는다(`HistoryCoordinator.swift` `holdsNavigationMessage`). 끊긴 동안 생긴 답글이 다시 연결 뒤 그려지는 검사(`AT-JO-14 reconnect`)가 추가됐다.
5. **직접 실행한 것** (증거 수준 2, 로그는 worktree `.build/jump-once/verify5/`, `@708a6da`)
   - `bash app/Tests/HistoryTransport.sh` 종료 0(`build.log`).
   - `pytest app/Tests/HistoryAutoloadFixture.py -k jump --basetemp=/tmp/jov` (환경 변수 없이, 판정 항상 적용) **36 통과**, 종료 0(`acceptance.log`). AT-JO-04 여섯 입력 모두 maxDifference 0, `AT-JO-14 reconnect PASS recentRequests=1 replyRendered=true`.
   - 같은 명령 `-k "not jump"` 37 통과, 종료 0(`regression.log`).
   - 휠 두 입력(cold·ready) 8회 반복, 16회 모두 maxDifference 0·종료 0(`wheel-1..8.log`).
   - 구현자 보고의 반례 확인 로그(`.build/jump-once/v1-fix/origin-probe.log`, `difference-probe.log`, `reconnect-before.log`)는 존재만 확인하고 재실행하지 않았다.
   - 4회차에서 직접 확인한 개인값 검사(종료 0)와 구현자의 `bash scripts/test.sh`(착수 기준과 같은 1건 실패)·`bash app/scripts/test.sh`(설정 가드 환경 문제) 결과는, 이번 수정이 시험 파일과 제품 두 줄만 바꿨으므로 재사용한다.
6. **완료 근거:** REQ-JO-01~04와 NFR-JO-01~03의 수락 시험이 검증자 실행에서 모두 통과했다. 미해결 차단 지적 없음. 대체된 옛 경로(입구별 직접 이동, `pendingRevealScroll`, 세 번 예약, 목록 상태 줄, 카드창 경고 줄, 조각마다 갱신) 제거 확인.
7. **남은 것(완료 판정 밖)**
   - 사용자 확인: AT-JO-15 시안 PNG의 ↻ 자리와 아래쪽 안내 줄 모양(D-06). 바꾸자고 하면 별도 수정으로 받는다.
   - 설치된 앱에는 새 버전 빌드·배포 전까지 변화가 없다(범위 밖, 별도 릴리스 작업).
