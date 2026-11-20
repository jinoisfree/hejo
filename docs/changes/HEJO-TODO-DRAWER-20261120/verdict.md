# HEJO-TODO-DRAWER 검증 판정

## 검증 판정 1차: TASK-02·03·04 (2026-11-20)

1. **판정: 부분 완료.**
   - 배정된 구현은 요구와 수락 기준을 충족한다.
   - 차단 1건(V-3): 기준 `main`이 다른 작업으로 앞서 나가 `gate/server.py`에서 병합 충돌이 난다. 통합하고 전체 시험을 다시 돌리기 전에는 완료로 판정하지 않는다.
   - 비차단 2건(V-1·V-2)은 같은 보완에서 고친다.
   - 서버 적용(TASK-05)·공개(TASK-06)·사장 확인(M1~M3)은 아직 범위 밖이다.

2. **검증 조건: 교차 모델.**
   - 구현은 codex/gpt-6.1-sol이 했고, 검증은 이 대화(Claude Opus 5.5, 기획·설계 담당)가 했다. 구현 대화의 추론은 보지 않았고, 설계·인계 보고·코드·실행 결과만 봤다.
   - 계획 담당이 자기 설계를 검토한 것이므로, 설계 적합성은 3번에서 따로 판정한다.
   - 검토한 코드
     - hejo: `role-workflow/7-833b7c8b` @ `5b8ffbaf7845a9f629745d10a32061ccbaae9791`(worktree `../.worktrees/31ptpirh/role-workflow-7-833b7c8b`). 기준 `fe6c05a`, 제품 커밋 `8cdc08e`, `e14de5a`, `af30f40`, `5b8ffba`.
     - team-kit: `hejo-todo-drawer-20261120` @ `b2bc84f89ff52a0d14b5cb39768b5e767eee189e`(`<운영 저장소>` 임시 worktree). 기준 `7ae2b013`.

3. **설계 적합성(4.2): 적합.** 설계가 요구와 AC를 충족한다.
   - 칸 배치 '가'(마감 원본은 team-kit 장부 하나, 문·앱은 읽기만)를 지켰다. 새 저장 위치, 허브 키, 장부 쓰기가 없다(`open_items`는 `load`만 쓰고 폴더·잠금을 만들지 않음, AT-TD-03).
   - NFR-TD-01(2판)의 응답 허용 목록은 `public_items`가 키를 골라 담는 방식으로 지켜진다.
   - 공유 실행 계약(design 3절)은 코드와 1:1로 대응한다. `Deadlines._running` 단일 소유, `shield`, 연결별 대기 Task 취소, 자기 종료와 `_reap`, `stop()`.
   - 설계의 빈틈 하나: NFR-TD-03은 "칸이 닫혀 있을 때"만 말하고, 채팅을 접어 칸이 숨은 경우를 정하지 않았다(V-2). REQ-TD-02 AC-05("접으면 칸도 함께 사라진다")와 design 7절 기각 사유("칸이 닫혀 있으면 쓸모가 없다")의 의도에 맞게 spec 3판에서 "칸이 화면에 보이지 않을 때"로 명확히 한다(요구 의도는 그대로).

4. **직접 확인한 것**
   - 코드 읽기
     - team-kit: `hermes/bin/hermes-deadlines`, `deadline_watch.open_items`·`list_main`.
     - 문: `gate/deadlines.py` 전체, `gate/server.py` 차이.
     - 앱: `TodoDrawerModel.swift` 전체, `IslandModel`·`IslandView`·`ConversationController`·`ConversationView`·`PetController`·`PetLayout`·`PetView`·`LocalStore`·`AppDelegate` 차이.
     - 시험: `TodoDrawerTests.swift` 전체, `IslandTests` 차이, `test_deadlines.py` 구성.
   - 수락 시험 명세 `tests/acceptance/HEJO-TODO-DRAWER.md`는 `fe6c05a..5b8ffba`에서 바뀌지 않았다(diff stat에 없음).
   - 실행 결과(로그는 계획 폴더 `.build/todo-drawer-verify/`)

     | 명령 | 대상 | 종료 | 결과 | 로그 |
     |---|---|---|---|---|
     | `pytest tests/acceptance/test_deadlines.py` | `5b8ffba` | 0 | 12 passed | `gate-deadlines.log` |
     | team-kit `pytest test_deadline_list.py test_deadline_watch.py` | `b2bc84f8` | 0 | 49 passed | `teamkit.log` |
     | `TZ=Asia/Seoul bash scripts/test.sh` 1회 | `5b8ffba` | 1 | `APP_TEST_FAILED assertion("AT92 real 0.18 fade intermediate frame")` | `full-test.log` |
     | 같은 명령 2회 | `5b8ffba` | 0 | Python 393 passed, `AT-TD-20..41 … PASS`, `AT-HF-54 PASS`, 앱 전체 `APP_TEST_OK` | `full-test-2.log` |
     | `scan_private.py --home .build/todo-drawer/scan-home` | `5b8ffba` | 0 | 통과 | `scan.log` |
     | `git merge-tree --write-tree 5b8ffba 961ea80` | — | 1 | `CONFLICT (content): gate/server.py` | `merge-tree.txt` |

   - AT92 1회 실패에 대한 판단
     - 실패한 시험은 접힌 말풍선이 실제 시간 0.18초 동안 나타나는 도중의 투명도를 본다(`PetWindowTests.swift:67-70`, `pause(0.08)` 뒤 presentation opacity).
     - 이번 변경은 그 경로(foldedBubble 페이드)에 닿지 않는다.
     - 1회는 개인값 검사와 merge-tree를 동시에 돌린 부하 상태였다. 부하 없이 다시 돌린 2회는 통과했고, 구현 담당의 최종 실행도 통과했다.
     - 따라서 실제 시간에 기대는 기존 시험의 흔들림(기술 부채 D-1)으로 판정한다.
   - 증거 수준: 2(가짜 홈·가짜 명령·실제 subprocess·인증 소켓·실제 AppKit 보기 조립). 설계가 요구한 수준 2에 도달했다. 3·4(운영 실행·사장 확인)는 TASK-05~07 범위라 미실행이다.
   - mutation: 구현 담당이 shield를 지웠을 때 AT-TD-18이 실패하는 것을 기록했다(`task03-mutation-final.log`). 시험 구성(pid 파일로 자식 소멸 확인, 연결 A 끊김 뒤 B 응답, 대기자 0, 제한 시간 회수, 재실행 횟수 2)을 읽어, 그 mutation을 잡을 수 있는 구조임을 확인했다. 검증자가 직접 다시 하지는 않았다.

5. **지적 목록과 처분 상태**
   - **V-3 (차단, 보낼 곳: 구현, 원인: 환경·외부 요인)**
     - 위치: `gate/server.py` 연결 종료 `finally`.
     - 기준: 30-verification 7.1(검토 대상이 최신 기준을 포함), 푸시 규칙.
     - 근거: 기준 `main`이 HEJO-CONN-MANAGE 커밋 `961ea80`으로 앞섰다. 그 커밋은 같은 `finally`에 `self.admin_connections.disconnected(conn.device_id)`를 넣었고, 이 작업은 같은 자리에 `deadline_waiters` 취소를 넣었다. merge-tree에서 충돌을 확인했다.
     - 두 줄은 서로 독립이라 둘 다 남기면 된다(의도 판단 불필요).
     - 검토 중 `main`이 `f0ca282`(앱 연결 화면 커밋)로 더 나아갔다. `git merge-tree 5b8ffba f0ca282`로 봐도 충돌은 `gate/server.py` 한 곳뿐이다.
     - 처분: 보완 지시 1. 미해결.
   - **V-1 (비차단, 보낼 곳: 구현)**
     - 위치: `ConversationView.tickIsland()`와 `refresh()`의 `todoDrawer.show(controller.drawerSnapshot…)`.
     - 기준: 20-implementation(불필요한 계산), design 5.1.
     - 근거: 칸이 닫혀 있거나 채팅이 접혀 있어도, 1초마다 그리고 매 `refresh`마다 모든 방의 `notices`를 다시 계산한다. 기존 코드는 선택된 방 하나만 1초마다 계산했다. 방·글이 많으면 메인 스레드 비용이 늘어난다.
     - 처분: 칸이 보일 때(열림이고 채팅 펼침)만 투영을 계산하고 그린다. 미해결.
   - **V-2 (비차단, 보낼 곳: 구현 + 기획설계 명확화)**
     - 위치: `PetController.collapseChat`/`showChat`와 `ConversationController.drawerOpen`·`pollDeadlines`.
     - 기준: NFR-TD-03(3판 명확화), REQ-TD-02 AC-05.
     - 근거: 열림 선호가 참인 채로 채팅을 접어도 `ConversationController.drawerOpen`은 참으로 남는다. 그래서 5분마다 `deadlines` 요청이 계속 나간다. 앱을 다시 켰는데 채팅이 접혀 있어도 `installDrawer`가 바로 요청한다.
     - 처분: 요청 조건을 "열림 선호 ∧ 채팅 펼침"으로 한다. 채팅을 펼칠 때 열림이면 한 번 요청한다. 수락 시험 AT-TD-42를 추가했다. 미해결.
   - **기술 부채 D-1**: `PetWindowTests.swift:67-70` AT92가 실제 시간 0.08초 대기 뒤 0.18초 페이드의 중간값을 본다. 부하에 따라 흔들린다. 이번 변경과는 무관하므로 기록만 한다.
   - 보고와 실제의 대조
     - impl-report가 적은 변경 파일 목록은 diff stat과 같다.
     - 미보고 변경은 없다.
     - 옛 경로(사장 칸 `.question(oldest)` 할당)는 `IslandModel.swift`에서 `.drawer`로 교체되었고, 미리보기 치환(`:145` 부근)은 그대로다.
   - 기존 시험 변경: `IslandTests.swift`의 일반 사장 칸 클릭 회귀 입력을 "칸 열기 → 첫 질문 카드 누르기"로 옮겼다. 기대값(방 선택·펼침·1.5초 강조·2pt 강조색)은 그대로다. design 6절의 승인된 **교체**에 따른 입력 이동이므로 수락한다. 미리보기 AT56 단언(`:70-72`)은 바뀌지 않았다.

6. **기획설계로 넘긴 것**
   - NFR-TD-03 명확화(V-2): spec 3판과 수락 시험 3판 AT-TD-42로 이번에 반영했다.
   - 계획 검증 PR-05(인계서 판 번호): 보완 지시 작성 때 함께 바로잡았다.
   - 정정: plan-review 1회차 PR-01 처리 문장 "바꿀 기존 시험은 없다"는 미리보기 경로에만 맞다. 일반 클릭 경로의 기존 회귀 시험 입력은 교체에 따라 옮겨야 했다(위 5번, 수락함).
   - 현재 명세 반영(TASK-07) 때 HEJO-FOUNDATION의 사장 칸 클릭 서술(AT-HF-56 계열)을 "칸 열기, 미리보기 중에는 가장 오래된 질문"으로 갱신해야 한다.

7. **미검증 범위와 남은 위험**
   - 운영 장부 실제 출력(M1), 운영 문 응답(M2), 사장 화면 확인(M3)은 미실행이다.
   - 시간대 가정(KST)과 운영 `source` 형식은 그대로 남아 있다.
   - 푸시 경로: 원격 `github`의 `main`(`0cc0828`)은 공개판 `public` 브랜치 이력이고, 로컬 `main`과 공통 조상이 없다. 이 작업의 결과는 `main` 통합 뒤 TASK-06 공개 절차(`hejo-publish`)로 원격에 나간다. 구현 브랜치를 원격 `main`에 직접 푸시하는 대상은 없다.

8. **미완료 원인 분류와 남은 조건**
   - 원인: 환경·외부 요인. 다른 작업의 기준 전진이 V-3를 만들었다.
   - 남은 조건
     1. 구현 브랜치에 최신 로컬 `main`을 merge하고 충돌을 정리한다.
     2. V-1·V-2를 고치고 AT-TD-42를 추가한다.
     3. 전체 `bash scripts/test.sh`, 문 시험, 개인값 검사를 통과한 커밋을 만든다.
     4. 계획 담당이 그 커밋을 재검증한다.
   - 이후 TASK-05·06·07이 남는다.

9. **현재 명세 반영 요청**: 해당 없음(완료 판정 아님).

## 검증 판정 2차: 보완 1 (2026-11-20)

1. **판정: 부분 완료.**
   - 보완 1의 지시 사항은 모두 맞게 들어갔다: 기준 통합(V-3), 숨은 동안 투영 억제(V-1), 숨은 동안 요청 억제(V-2), 새 시험 AT-TD-42.
   - 그러나 직접 반복 실행해 보니, 이 변경이 기존 실제 시간 애니메이션 시험(AT92, AT89)을 흔들리게 만드는 **회귀**를 확인했다(V-4, 차단).
   - 1차 판정에서 AT92 실패를 "이번 변경과 무관한 기술 부채 D-1"로 본 것은 **틀렸다.** 아래 근거로 정정하고, D-1은 V-4로 대체한다.

2. **검증 조건: 교차 모델.**
   - 구현은 codex/gpt-6.1-sol, 검증은 이 대화(Claude Opus 5.5)가 했다.
   - 대상: `role-workflow/7-833b7c8b` @ `4a82dda0e506ae4dad7bae9406bad411f3bd4eba`. 보완 커밋은 `2a7ca15`(main 병합·충돌 해결), `005677e`(앱 보완), `c472178`·`1549503`·`4a82dda`(main 추가 병합)다.
   - team-kit `b2bc84f8`은 변경 없음(1차 통과 유지).

3. **설계 적합성(4.2): 적합.**
   - spec 3판의 NFR-TD-03(칸이 보이지 않으면 요청 없음)은 `ConversationController.drawerVisible = drawerOpen ∧ drawerChatExpanded`로 정확히 구현됐다.
   - V-1은 `refresh`와 `tickIsland`의 투영을 `drawerVisible`로 막아 해결했다.
   - V-4는 설계 결함이 아니다. 구현이나 시험이 남기는 메인 스레드 부담 문제다.

4. **직접 확인한 것**
   - 병합
     - `git diff c9cd9c0 4a82dda --stat`: 이 작업의 파일 19개만 다르다. main 쪽 내용을 바꾸거나 잃은 것은 없다.
     - `2a7ca15`의 `gate/server.py` 충돌 해결은 `admin_connections.disconnected(...)`와 `deadline_waiters` 취소·gather를 둘 다 남겼다.
     - `git merge-base --is-ancestor c9cd9c0 4a82dda`: 종료 0.
   - 코드: `005677e`의 `ConversationController`·`ConversationView`·`PetController` 차이와 AT-TD-42·V-1 시험 추가분을 읽었다. 기존 AT-TD 기대값은 바뀌지 않았다.
   - **A/B 반복 실행**
     - 방법: 같은 기계에서 다른 검사 없이 앱 시험 바이너리 기본 묶음(`app-tests <Pet 자원>`)을 번갈아 실행했다.
     - 로그: 계획 폴더 `.build/todo-drawer-verify/s1/ab.txt`, `app-*.log`.

     | 대상 | 실패/실행 | 실패 단언 |
     |---|---|---|
     | 기준 main `c9cd9c0`(임시 worktree 빌드) | **0/7** | — |
     | 이 브랜치 `4a82dda`(구현 담당 최종 빌드, 입력 일치) | **4/7** | `AT92 real 0.18 fade intermediate frame` ×3, `AT89 following row has an intermediate y` ×1 |
     | `4a82dda`에서 `TestMain`의 `todoDrawerTests` 호출만 뺀 것(임시 worktree) | **2/4** | AT92 ×2 |

     - 이 표와 앞선 기록(구현 담당 전체 실행 3회 중 2회 실패, 검증 1차 2회 중 1회 실패)을 합치면 판단은 이렇다. 기준 main에서는 재현되지 않고 이 브랜치에서만 약 절반의 확률로 실패한다.
     - 할 일 칸 시험을 빼도 실패하므로, 원인은 `TodoDrawerTests`가 남긴 객체만이 아니다. 후보는 둘이다.
       - 제품 코드: 칸이 보이는 동안 1초마다 모든 방 `notices`를 투영한다. 그 밖에 이동·타이머 변화도 있다.
       - 바뀐 `IslandTests`: `pet.installDrawer`와 칸 열기를 하고, 열린 칸을 가진 펫·보기를 남긴다.
     - 원인 분리는 구현 담당에게 맡긴다. 임시 worktree 두 개는 확인 뒤 지웠다.
   - 구현 담당의 최종 전체 실행(종료 0)과 AT92 단독 통과는 로그로 확인했다. 단독 통과는 "같은 프로세스 앞 단계의 부담" 가설과 들어맞으며, 회귀가 없다는 증거가 아니다.
   - 증거 수준 2(대역 통합)는 유지된다.

5. **지적 목록과 처분 상태**
   - V-1·V-2·V-3: **해결 확인.**
   - **V-4 (차단, 보낼 곳: 구현, 원인: 구현 오류)**
     - 위치: 미확정. 후보는 앱 제품 코드(칸 투영·이동 타이머)와 `app/Tests/IslandTests.swift`·`TodoDrawerTests.swift`의 정리 누락이다.
     - 기준: 30-verification 4.4·7.1(유지할 계약), handoff 7번 보존 비교(`bash scripts/test.sh` 전체).
     - 근거: 위 A/B 표.
     - 처분: 보완 지시 2. 미해결.
   - 기술 부채 D-1(1차): **철회.** 기존 시험의 흔들림이 아니라 이 변경의 회귀(V-4)다.

6. **기획설계로 넘긴 것**
   - 없음(설계 변경 불필요).
   - 기준 `main`이 `d5d04a2`(HEJO-CONN-MANAGE 문서 1개)로 다시 앞섰다. merge-tree로는 충돌이 없다. 보완 2에서 함께 병합한다.

7. **미검증 범위와 남은 위험**
   - V-4의 원인이 제품 쪽이면, 실제 앱에서도 칸이 열린 동안 애니메이션이 끊길 수 있다. 원인을 확정해야 판단할 수 있다.
   - M1~M3과 시간대·source 가정은 1차와 같다.

8. **미완료 원인 분류와 남은 조건**
   - 원인: 구현 오류(V-4).
   - 남은 조건: 원인을 확정해 고친다 → 기본 앱 시험 묶음이 부하 없이 10회 연속 통과한다(AT89·AT92 기대값·대기 시간 불변) → 전체 `scripts/test.sh` 종료 0 → 최신 main 포함 → 계획 담당이 재검증한다.

9. **현재 명세 반영 요청**: 해당 없음.
