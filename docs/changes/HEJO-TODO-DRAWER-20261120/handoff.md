# 설계 인계: HEJO-TODO-DRAWER / TASK-02~04 왼쪽 할 일 칸

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음, 두 번째 원본 없음. 마감은 읽기만 한다.

```text
[설계 인계: HEJO-TODO-DRAWER TASK-02~04 / team-kit·문·앱]
0. 기준: 제품 코드 기준 63cbe2a(이 저장소 main), 운영 저장소 7ae2b013 / spec·design·tasks·수락 시험 2판(spec·수락 시험은 보완 지시 1에서 3판) /
   작성 2026-11-20, 2판(계획 검증 1회차 반영, plan-review.md) / 승인: 사장 결정 5개(brainstorm.md) + 계획 승인 대기(이 plan) / 운영 모드: 연합개발(교차 모델 기본)
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-TODO-DRAWER-20261120/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-TODO-DRAWER.md. team-kit은 <운영 저장소>/AGENTS.md와 ./airport-check 규칙.
2. 요구와 수락 기준: REQ-TD-01~06, NFR-TD-01~03(REQ-TD-07 서버 적용·공개는 이번 지시 밖).
   정상: 알약 사장 차례 칸·빈 알약으로 칸 토글, 창이 왼쪽으로 290pt 늘어나고 0.25초, 답 요청·알림·마감 카드.
   핵심 실패: 왼쪽 자리 없음 → 덮기, team-kit 없음 → 마감 숨김, 읽기 실패 → 마지막 목록 + 회색 줄.
3. 유지할 기존 계약: 기존 프레임·필드 불변(v 1, 새 type만 추가), deadline_watch 장부 형식·쓰기·Slack 보고 불변,
   hermes-connections 명령 표 불변, notices() 결과 불변, PetPlacement leading=0일 때 기존 결과 동일,
   직원 얼굴·문제 칸 클릭 동작 불변, 사장 칸 미리보기 중 클릭은 가장 오래된 질문으로(IslandModel.swift:143, IslandTests AT56 불변).
4. 책임과 흐름: design 1절. 마감 뜻 = team-kit deadline_watch, 실행 경계·이유 코드 = 문 Deadlines,
   카드 묶기·문장 = 앱 TodoDrawerModel, 창 배치(늘림/덮기 판정) = PetPlacement 하나.
5. 기존 경로 판정: design 6절(교체 1: 사장 차례 칸 클릭 → Action.drawer, 옛 할당 제거. 나머지 유지·확장).
6. 위험도: TASK-03 문은 고위험(동시성: 문 전체 공유 실행·연결 종료 취소·자식 프로세스 회수, design 3절 계약) → 다른 모델 독립 검증 필수,
   복구는 문 릴리스 롤백(TASK-05). TASK-02·04는 일반. 필요 증거 수준 2. TASK-05·06은 고위험(이번 지시 밖).
   응답 허용 필드와 로그·문서·시험 금지 범위는 NFR-TD-01(2판)로 구분했다.
7. 변경 성격: 의미 변경(알약 사장 차례 칸 클릭의 결과). 보존 비교: AT-TD-05·17·28·29·38, bash scripts/test.sh 전체.
8. 수락 시험: tests/acceptance/HEJO-TODO-DRAWER.md 2판 AT-TD-01~05(team-kit), 10~19(문), 20~41(앱).
   기대값 출처 spec·design. 상태: 명세 완료·코드 미작성·미실행·계획 검증 1회차 BLOCKED 반영, 재검증 대기.
9. 작업 범위: tasks.md TASK-02·03·04 영향 파일만. TASK마다 별도 커밋(git commit --only로 자기 경로만),
   impl-report.md에 TASK별 절. 금지: 운영 공항(~/.hermes) 파일 변경·게이트웨이 재시작·운영 team-kit 원본 수정
   (team-kit은 <운영 저장소> 임시 worktree에서만, 착수 때 기준 sha256 기록), Hermes 본체, ddots, 비밀 파일 열기,
   실제 Slack·고객 메시지, git push. 병렬 갈래: 있음(tasks.md 표, team-kit/문/앱 파일 겹침 없음).
10. 가정·미확정: [가정] 사장 Mac 시간대 = deadline_watch KST(D-day 표시). [미확인] 운영 장부의 source 실제 형태
    (링크 아니면 직원 방 이동으로 처리, 차단 아님). 창 배치 세부(움직임 곡선, 막의 투명도)는 구현 자유.
    시안 v28은 참고일 뿐 기준이 아니다. 착수 차단 없음.
11. 사용자 확인: 칸 내용·여는 곳·웹 칸 동시·출처·칸 배치 '가'는 사장 답(brainstorm.md). 범위·AC는 이 plan 승인으로 확인.

[인계 전 점검]
- 현재 코드·계약·명세가 base 63cbe2a와 호환: 예(작성 시점 main HEAD, 미추적 문서는 HEJO-CONN-MANAGE 계획뿐).
- G1–G4: 요구·범위·제외 확정, 현황 근거(spec 1절), 경로 판정, AC↔시험 연결, 위험·증거 수준 지정. 통과.
```

## AC ↔ 시험

| AC | 시험 |
|---|---|
| TD-01.AC-01·03 | AT-TD-27·41 |
| TD-01.AC-02 | AT-TD-28·29 |
| TD-01.AC-04 | AT-TD-30 |
| TD-02.AC-01 | AT-TD-31 |
| TD-02.AC-02 | AT-TD-32 |
| TD-02.AC-03 | AT-TD-33 |
| TD-02.AC-04 | AT-TD-34 |
| TD-02.AC-05 | AT-TD-35 |
| TD-03.AC-01·02 | AT-TD-20 |
| TD-03.AC-03 | AT-TD-21 |
| TD-03.AC-04 | AT-TD-22 |
| TD-03.AC-05·06 | AT-TD-23·37·39 |
| TD-04.AC-01 | AT-TD-25·39 |
| TD-04.AC-02·03 | AT-TD-26 |
| TD-05.AC-01 | AT-TD-01·10 |
| TD-05.AC-02 | AT-TD-11·24 |
| TD-05.AC-03 | AT-TD-12·24 |
| TD-05.AC-04 | AT-TD-02·13·40 |
| TD-05.AC-05 | AT-TD-03 |
| TD-06 | AT-TD-36 |
| NFR-TD-01 | AT-TD-10(응답 허용 필드)·15(로그), 개인값 검사 |
| NFR-TD-02 | AT-TD-14·18·19 |
| NFR-TD-03 | AT-TD-37·42 |
| TD-07 | M1·M2(TASK-05), TASK-06 |

## 구현 담당 보고

`impl-report.md`에 TASK별로 아래를 적는다.
- 바꾼 파일과 커밋.
- 시험 명령, 종료 코드, 로그 경로(`.build/` 아래).
- 도달 증거 수준.
- 남은 문제.
- team-kit worktree 경로와 커밋.

검사 명령:
- `bash scripts/test.sh`
- `python3 scripts/scan_private.py`. 둘 다 Hermes venv 파이썬(`~/.hermes/installs/*/environments/*/venv/bin/python`, `HEJO_PYTHON`)으로 실행한다. 시스템 python3에서는 `scan_error`로 실패한다.
- `HD` 쪽은 `./airport-check`.

## 보완 지시 1 — 기준 통합과 V-1·V-2 (검증 1차, [verdict.md](verdict.md))

- 기준
  - 구현 브랜치 `role-workflow/7-833b7c8b` @ `5b8ffba`, 통합할 기준은 merge 시점의 최신 로컬 `main`(검증 1차 작성 중 `961ea80` → `f0ca282`로 전진, 둘 다 HEJO-CONN-MANAGE 커밋). merge-tree로 본 충돌은 `gate/server.py` 한 곳뿐이다.
  - spec 3판(NFR-TD-03 명확화), 수락 시험 3판(AT-TD-42 추가). 그 밖의 설계·수락 기대값은 2판과 같다.
- 할 일
  1. **V-3 통합**: 구현 worktree에서 로컬 `main`을 merge한다(merge 커밋, rebase·force 금지).
     - `gate/server.py` 연결 종료 `finally`의 충돌은 두 줄을 모두 남긴다: `self.admin_connections.disconnected(conn.device_id)`와 `deadline_waiters` 취소·gather.
     - 다른 충돌이 생기거나 두 작업의 의도 판단이 필요하면 멈추고 보고한다.
     - 계획 담당 checkout의 미커밋 HEJO-CONN-MANAGE 변경(`app/Sources/Connection*.swift` 등)은 건드리지 않는다.
  2. **V-1**: 칸 투영(`drawerSnapshot` 계산·`todoDrawer.show`)은 칸이 보일 때(열림 ∧ 채팅 펼침)만 한다. 닫혀 있거나 접혀 있을 때 1초 tick과 `refresh`에서 모든 방 `notices`를 계산하지 않는다. 보이게 되는 순간에는 한 번 계산해 최신 상태로 그린다.
  3. **V-2**: 마감 요청 조건을 "열림 선호 ∧ 채팅 펼침"으로 한다(NFR-TD-03 3판).
     - 채팅을 접으면 주기 요청이 멈춘다.
     - 펼칠 때 열림이면 한 번 요청하고 주기를 다시 시작한다.
     - 앱을 시작할 때 채팅이 접혀 있으면 요청하지 않는다.
     - 열림 선호(`todoDrawerOpen`)의 저장·복원은 지금 그대로 둔다.
  4. **AT-TD-42**를 `app/Tests/TodoDrawerTests.swift`에 추가한다. 기존 AT-TD 기대값은 바꾸지 않는다.
- 검사(대상 = 최종 커밋)
  - `TZ=Asia/Seoul bash scripts/test.sh` 전체.
  - 문 `pytest gate/tests tests/acceptance`.
  - `scan_private.py`(Hermes venv).
  - `git diff --check`.
  - `git merge-base --is-ancestor main <최종 커밋>` 종료 0(보고 시점의 로컬 `main` 해시를 함께 적는다).
  - 실제 시간에 기대는 기존 시험(예: AT92)이 부하로 흔들리면 부하 없이 다시 실행하고, 두 결과를 모두 기록한다.
- 보고: `impl-report.md`에 "보완 1" 절을 덧붙인다(merge 커밋, 충돌 해결 내용, 바꾼 파일, 시험 명령·종료 코드·로그 경로). team-kit worktree는 바꿀 것이 없다.
- 금지: 기존과 같다(운영 공항·재시작·운영 team-kit 원본·비밀 파일·Hermes 본체·ddots·실제 메시지·git push). TASK-05·06은 하지 않는다.

## 보완 지시 2 — 실제 시간 애니메이션 시험 회귀(V-4) (검증 2차, [verdict.md](verdict.md))

- 기준
  - 구현 브랜치 `role-workflow/7-833b7c8b` @ `4a82dda`. 통합할 기준은 merge 시점의 최신 로컬 `main`(현재 `d5d04a2`, 문서 1개, merge-tree 충돌 없음).
  - 설계·수락 시험은 3판 그대로다.
- 사실: 같은 기계에서 앱 시험 기본 묶음을 번갈아 돌린 결과(verdict 2차 4번 표)
  - 기준 main `c9cd9c0`: 0/7 실패.
  - `4a82dda`: 4/7 실패(`AT92 real 0.18 fade intermediate frame`, `AT89 following row has an intermediate y`).
  - 할 일 칸 시험 호출만 뺀 `4a82dda`: 2/4 실패.
- 할 일
  1. **원인 확정.** 제품 코드와 시험 정리 누락 가운데 무엇이 같은 프로세스의 뒤 시험(AT89·AT92)의 메인 스레드·애니메이션 시간을 미는지 실험으로 가린다. 실험 방법은 구현 자유다(예: `IslandTests`의 칸 열기 경로를 기준과 같게 돌려 비교, 남은 `PetController`·`ConversationView`의 타이머와 칸 투영 호출 횟수 계측). 근거와 실험 로그를 보고한다.
  2. **수정.**
     - 원인이 제품 코드이면 제품 쪽에서 고친다. 예: 칸이 보일 때도 1초마다 모든 방을 투영하지 않고 바뀜이 있을 때만 하기, 이동이 끝나면 타이머 멈추기.
     - 원인이 시험 정리 누락이면, 새로 넣거나 바꾼 시험(`IslandTests`·`TodoDrawerTests`)이 끝날 때 칸을 닫고 펫 패널·보기·타이머·클라이언트를 정리한다.
     - 둘 다면 둘 다 고친다.
     - AT89·AT92와 다른 기존 시험의 기대값·대기 시간·순서를 바꾸지 않는다. 수락 시험 AT-TD 기대값도 바꾸지 않는다.
  3. 최신 로컬 `main`을 merge 커밋으로 병합한다(rebase·force 금지).
- 합격 기준(대상 = 최종 커밋)
  - 다른 무거운 프로세스 없이 `TZ=Asia/Seoul app/.build/app-tests "$PWD/app/.build/hejo.app/Contents/Resources/Pet"`(기본 묶음)를 **10회 연속** 실행해 모두 종료 0. 회차별 종료 코드를 기록한다.
  - 그 뒤 `TZ=Asia/Seoul bash scripts/test.sh` 종료 0.
  - 문 `pytest gate/tests tests/acceptance` 종료 0.
  - `scan_private.py`(Hermes venv) 종료 0.
  - `git diff --check` 종료 0.
  - `git merge-base --is-ancestor main <최종 커밋>` 종료 0(로컬 main 해시 기록).
  - 중간 실패도 지우지 말고 모두 기록한다.
- 보고: `impl-report.md`에 "보완 2" 절(원인 실험·결론, 바꾼 파일, 커밋, 10회 결과표, 명령·종료 코드·로그)을 덧붙인다.
- 금지: 기존과 같다. 운영 공항·재시작·운영 team-kit 원본·비밀 파일·Hermes 본체·ddots·실제 메시지·git push, TASK-05·06은 하지 않는다.

## 사장 결정 (2026-11-21)과 TASK-05 합동 서버 적용 (시작 대기)

- 사장 결정
  1. 서버 적용은 HEJO-CONN-MANAGE와 **한 번에** 한다(계획 담당 권고안). 게이트웨이 재시작은 한 번만 한다.
  2. 결과물은 로컬 `main`에 반영하고, 원격 반영은 TASK-06 공개 절차로 한다(권고안).
- main 반영
  - 로컬 `main`은 `e99e60f`(판정 문서)가 앞서 있어 빨리 감기가 불가능했다. 그래서 충돌 없는 일반 merge 커밋 `433095a`로 검증 커밋 `73a9447`을 넣었다.
  - `git diff --exit-code 73a9447 433095a -- app gate schemas tests` 종료 0이다. 제품 내용은 검증본과 같다.
- **시작 조건** (모두 충족되기 전에는 TASK-05를 시작하지 않는다)
  1. HEJO-CONN-MANAGE TASK-02b가 끝나고 그 작업의 검토를 통과한다.
     - 사장 결정 (가)에 따라 CONN-MANAGE의 서버 적용은 TASK-02b 뒤에 한다.
     - 이미 `main`에 들어 있는 CONN-MANAGE 문 코드(`961ea80`·`131e47f`)는 이 작업의 문 릴리스에 함께 실리므로, 그 전에 릴리스하면 사장 결정을 어기게 된다.
     - 2026-11-21 읽기 확인: `<운영 저장소>` HEAD `dfb469d3`의 `wait_jobs.py` sha256 = 실행본 `441a8501…`. TASK-02b 시작 조건이 이제 충족됐다.
  2. 문 릴리스 대상 커밋은 두 작업이 모두 들어간 로컬 `main`이다. 계획 담당 둘(이 작업과 CONN-MANAGE)이 그 커밋을 확인한다.
- **절차**: [HEJO-CONNECTIONS design 7.2](../HEJO-CONNECTIONS-20261120/design.md#72-서버-적용-task-05)를 그대로 따른다. 이 작업이 더하는 것은 아래뿐이다.
  - team-kit
    - `hejo-todo-drawer-20261120` 브랜치(`b2bc84f8`, 기준 `7ae2b013`)를 `<운영 저장소>` 최신 HEAD에 merge한다.
      - 대상 파일은 `hermes/bin/hermes-deadlines`(새), `deadline_watch.py`(읽기 함수 추가), 시험이다.
      - 착수 때 HEAD의 `deadline_watch.py` sha256이 `e20213cd…`인지 확인한다. 2026-11-21에는 HEAD와 실행본 모두 일치했다.
    - CONN-MANAGE의 team-kit 변경과 같은 `./airport-check`·`./sync`·커밋으로 묶는다.
    - 실행본 `<HOME>/bin/hermes-deadlines`도 sync 대상인지 확인한다. 롤백 목록에도 "새 파일 삭제"로 적는다.
  - 문: 같은 공용 릴리스 하나에 담는다.
  - 롤백(먼저 기록)
    - 교체 전 `deadline_watch.py`와 문 릴리스 폴더의 보관본과 sha256을 남긴다.
    - 되돌릴 때는 새 `hermes-deadlines`를 삭제하고, 이전 릴리스로 되돌린 뒤 재시작한다.
  - 확인
    - M1: `hermes-deadlines list --json`이 종료 0이고 `failed`가 없다. 운영 장부 2개의 sha256이 실행 전후로 같다. 기록에는 개수와 직원 id만 남긴다.
    - M2: 재시작 뒤 문 로그에 `deadlines_read items=N failed=0`가 남는다.
  - 금지
    - 실제 Slack·고객 메시지를 보내지 않는다. 비밀 파일을 열지 않는다. Hermes 본체를 고치지 않는다. git push를 하지 않는다.
    - 재시작은 합동 적용에서 한 번만 한다.

### 두 작업 계획 담당 합의 (2026-11-21, 사장 지시 "알아서 소통 후 순서 정해서 진행")

1. HEJO-CONN-MANAGE가 TASK-02b를 구현하고 검토를 통과한다. 그 작업 담당이 시작 조건 충족을 확인했고 구현 지시를 냈다.
2. 합동 TASK-05 실행 인계는 **HEJO-CONN-MANAGE 계획 담당이 하나만** 낸다.
   - 절차는 HEJO-CONNECTIONS design 7.2 하나다.
   - 이 작업의 추가분(team-kit `b2bc84f8` merge, `hermes-deadlines`, 롤백 항목, M1·M2)을 그 인계에 넣는다. 위 절을 링크한다.
   - 이 작업 쪽은 TASK-05 인계를 따로 내지 않는다.
3. 문 릴리스 대상은 두 작업이 모두 들어간 로컬 `main` 커밋이다. 재시작은 1회다. 적용 뒤 확인 항목은 각자 검증한다. 이 작업은 M1·M2를 맡는다.
4. TASK-06 앱 공개도 하나로 합쳐 0.2.3으로 한 번 낸다.
5. 이 작업의 team-kit 브랜치(`b2bc84f8`)나 `main` 범위가 바뀌면 상대 계획 담당에게 바로 알린다. 상대는 TASK-05 인계를 내기 직전에 다시 확인을 요청한다.
