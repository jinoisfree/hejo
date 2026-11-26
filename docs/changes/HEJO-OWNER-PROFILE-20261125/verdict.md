## 검증 판정: HEJO-OWNER-PROFILE (작업 ID ea7efaba-a3fc-47d5-8a8f-111af3a65fc3)

### 1차 (2026-11-25) — 구현 담당의 착수 보류 보고 검토

1. **판정: 미완료.** 제품 구현이 시작되지 않았다. 구현 담당은 호스트가 배정한 worktree와 인계서 9절의 작업 공간이 서로 다른 이력이라 멈췄고, 멈춘 판단은 옳다.
2. **검증 조건**: 교차 모델(구현 codex, 검증은 계획 담당 대화). 검토 대상 제품 변경 없음.
3. **설계 적합성(4.2)**: 이번 보고로 설계 결함이 드러나지 않았다. 계획 2판(계획 검증 2회차 APPROVED)을 유지한다.
4. **직접 확인한 것**
   - 호스트 worktree `role-workflow/43-ea7efaba`: HEAD `452821b`(개발 `main`의 계획 문서 커밋), `git status --short` 비어 있음, 새 커밋 없음. 플러그인 수집 "변경 파일 없음"과 일치.
   - `git merge-base 452821b github/main`: 종료 1(공통 조상 없음). 개발 이력과 공개 이력이 다르다는 기존 사실과 같다.
   - `github/main` = `c22e6774604398f84351d69dd926ba3510d31aa2`. AUTOLOAD 확인 명령 일치 없음(TASK-02 대기 조건 그대로).
   - impl-report의 기준 시험 표와 로그 파일(호스트 worktree `.build/owner-profile/baseline-public-*.log`, `*.exit`)이 실제로 있다. 공개 기준 문·수락 pytest 549 통과(team-kit 라이브러리 경로 지정 시), 게이트웨이 전달 시험 정상, 앱 시험은 기준에서 `AT92 real 0.18 fade intermediate frame`과 설정 메타데이터 비교로 이미 실패. 이 목록을 구현 뒤 비교 기준으로 쓴다.
   - `../.worktrees/hejo-owner-profile-public-20261125`는 아직 없다.
5. **지적**: 없음(차단 사유는 작업 위치).
6. **미검증 범위**: AT-OP-01~36 전부(코드 미작성), 증거 수준 3 미도달.
7. **미완료 원인 분류**: 환경·외부 차이 — 호스트가 개발 `main`에서 worktree를 배정했으나 hejo 제품은 공개 이력(`github/main`)에서만 개발·배포한다(공개판에만 `gate/discord.py`·기록 하네스가 있음). 설계·요구·시험은 그대로다.
8. **조치(재확정한 지시)**: 인계서 9절대로 `github/main`(`c22e677`)에서 공개 worktree `../.worktrees/hejo-owner-profile-public-20261125`(브랜치 `hejo-owner-profile-public-20261125`)를 만들어 거기서만 변경·커밋한다. 호스트 worktree에는 아무것도 커밋하지 않는다. 기준 시험은 이미 측정했으므로 다시 돌리지 않는다. 푸시 대상은 검증 뒤 공개 worktree의 커밋을 `github`/`main` 일반 대상(빨리 감기 확인)으로 제안한다.
9. **완료까지 남은 조건**: TASK-01 구현·검증 → AUTOLOAD 반영 감지 뒤 TASK-02 → 검증 → TASK-03 → 푸시 승인.

### 2차 (2026-11-26) — TASK-01 중간 검토 (TASK-02 진행 대기 중)

1. **판정: 부분 완료(진행 중).** TASK-01(문)은 승인 기준에 맞게 구현·검증됐다. TASK-02(앱)·TASK-03이 남아 작업 전체는 아직 완료가 아니다.
2. **검증 조건**: 교차 모델(구현 codex, 검증 계획 담당). 대상 커밋 공개 worktree `hejo-owner-profile-public-20261125`의 `a6266cde188e17fb17942b5e90500c9cbfed9895`(부모 `c22e677`).
3. **설계 적합성(4.2)**: 맞음. 원본은 `shared/hejo/owner.json`·`pictures/owner.png` 하나이고 쓰기는 문만 한다. 표시 이름은 `adapter.owner_label` 한 곳을 거쳐 맥락(`adapter.py` 두 곳, `rooms.py`)·텔레그램·디스코드·버튼·Hermes `user_name`에 쓰인다. welcome·명단 요청 응답·변경 알림 모두 `roster_frame`/`owner.profile`로 `owner`를 싣는다. 새 프레임 종류·레코드 종류 없음. `gate/journal.py`의 변경(공용 폴더를 새로 만들 때 0700)은 spec REQ-OP-01.AC-01 "없으면 0700"을 첫 기동 경로에서 지키기 위한 것이고 기존 폴더 권한은 바꾸지 않아 범위 안이다.
4. **직접 확인한 것**
   - `git show a6266cd`: 15파일. 스키마 diff는 `owner_profile` 정의와 welcome·roster의 선택 `owner`뿐. AT-SM-02는 해시와 주석 한 줄만 바뀜(D-03 조건 충족).
   - 이름 검증(`owner.valid_name`): 제어 문자·U+2028/2029 거절 뒤 공백 제거, 20자 초과 거절, 빈 값은 지움. 읽기 실패·심볼릭 링크는 "설정 안 됨". 원자적 쓰기·0600.
   - `broadcast`는 seq 없는 프레임을 방 없는 프레임으로 보고 모든 연결에 넣는다(`server.py:581-589`) → `ref:owner` roster가 모든 기기에 간다.
   - 시험 함수 `gate/tests/test_owner_profile.py`가 AT-OP-01~14를 모두 다룸(13함수·매개변수 포함 17건).
   - 로그(공개 worktree `.build/owner-profile/`): `task01-d03-suite.exit`=0, 566 통과(기준 549 + 새 17), `task01-d03-private.exit`=0. 앱 `task01-d03-app.exit`=1, 첫 실패 `AT92 opening takes key focus`. TASK-01은 앱 파일을 바꾸지 않았고 기준에서도 AT92(다른 단언)로 실패했으므로 TASK-01에 의한 새 실패로 보지 않는다. 다만 앱 시험이 첫 실패에서 멈춰 뒤 시험이 돌지 않으므로, TASK-02 검토 때 이 AT92 실패가 환경(포커스) 때문인지 분리해 확인해야 한다.
5. **지적**: 없음(TASK-01 범위).
6. **미검증 범위**: AT-OP-20~36(TASK-02), 앱 전체 회귀.
7. **완료까지 남은 조건**: AUTOLOAD 반영 감지 → TASK-02 → 앱 시험(AT92 실패 원인 분리 포함) → 검증 → TASK-03 → 푸시 승인.

### 3차 (2026-11-26) — TASK-01 완료 보고 확인, TASK-02 대기

- 보고 확인: 공개 worktree HEAD `a6266cd`, 작업본 깨끗함. 전체 `bash scripts/test.sh`(`task01-d03-suite.log`) 종료 0이며 이 실행 안의 앱 시험도 통과했다. 앱 단독 실행의 AT92 포커스 단언 실패는 전체 실행에서 같은 단언이 통과해 실행 환경(창 포커스) 영향으로 본다. TASK-01 판정은 2차 그대로(지적 없음).
- AUTOLOAD: `github/main`은 여전히 `c22e677`. 계획 폴더의 HEJO-AUTOLOAD verdict는 V-12 보완 중이라 반영 시점 미정.
- 조치: 사용자 지시(TASK-02는 AUTOLOAD 반영 감지 뒤 시작)를 유지한다. 계획 담당이 10분 간격 읽기 명령으로 감지를 이어 받고, 반영되면 구현 담당에게 TASK-02 시작을 보낸다.

### 4차 (2026-11-26) — 최종 검토: 완료

1. **판정: 완료.** REQ-OP-01~07의 AC를 AT-OP-01~36이 모두 다루고 통과했다. TASK-03(현재 명세 반영)은 이 판정 뒤 계획 담당이 같은 공개 브랜치에 문서 커밋으로 한다.
2. **검증 조건**: 교차 모델(구현 codex, 검증 계획 담당 Claude). 대상: 공개 worktree `hejo-owner-profile-public-20261125`의 `f116bdcae507d6559cd43c5db7b32d3a51b21578`(부모 merge `380b6c4` = TASK-01 `a6266cd` + `github/main` `df46dbe`). 작업본 깨끗함.
3. **설계 적합성(4.2)**: 맞음.
   - 앱은 사장 프로필을 메모리(`ConversationModel.owner`)에만 두고, welcome에 없으면 지우고 roster에 없으면 유지한다(REQ-OP-02.AC-04). 늦은 HTTP 응답은 `ownerRevision`으로 무시해 더 최신 roster를 덮지 않는다.
   - 말풍선 배치는 `NativeThreadCard` 한 곳에서 내 글·직원 글 모두 `ChatMetrics.bubbleCorner`·`bubbleInset`을 쓴다. `isConversational`·`Post.conversational`·`postPieces(conversational:)`는 제거됐다(설계 4절 제거 판정 이행, 이중 경로 없음).
   - 사장 이어 쓰기는 직원과 같은 규칙에 스레드 첫 글(사장 글)을 앞 글로 포함한다(D-04).
   - 코드 상자는 글자 단위 줄바꿈(`TextLayout` 코드 문단 `byCharWrapping`)으로 잘림 없이 폭 안에 든다.
   - 설정은 기존 설정 창의 영역(`PetSettingsWindow`), 우클릭 "내 프로필…"은 그 영역에 초점을 둔다.
4. **직접 확인한 것**
   - merge 무결성: `git diff a6266cd 380b6c4`가 `git diff c22e677 df46dbe`와 같다(merge에서 손댄 줄 없음). `df46dbe`·`a6266cd`는 HEAD의 조상.
   - TASK-02 diff(21파일) 읽음: 위 3절. 기존 시험 변경은 AT-PG-09 기대값 한 줄(D-04)과 `HejoSmoothTests`의 기록 필드 출처(`post.conversational` → `!piece.bubble.isEmpty`, 필드 제거에 따른 기록기 수정, 단언 변경 아님).
   - 구현 담당 로그 종료 코드(공개 worktree `.build/owner-profile/`): `task02-d04-suite` 0(scripts/test.sh: 문 566·게이트웨이·앱·통신·훅·실제 문 왕복), `task02-d04-app` 0(AT92 포함 통과), `task02-d04-unit` 0, `task02-d04-transport` 0, `task02-d04-private` 0.
   - 검증 담당 재실행: `bash app/Tests/OwnerProfileTransport.sh` 종료 0, 4 passed(AT-OP-35 왕복, AT-OP-23 세 가지 실패) → `verify-transport.log`. `app/.build/app-tests --owner-profile-unit` 종료 0, "AT-OP-20,21,22,24–34,36 PASS" → `verify-unit.log`. 증거 수준 3.
   - AT-OP-35 구현: 설정 영역의 저장 동작(`section.saveName()`)을 호출하고, 두 컨트롤러의 `ownerAvatar()`를 34×34 비트맵에 그려 가운데 픽셀로 빨강→파랑→삭제를 판정하며 welcome 재수신 0을 확인한다(수락 시험 명세와 같음).
   - 증거 PNG 두 장(`owner-chat-light.png`, `owner-chat-dark.png`): 표 칸 줄바꿈, 코드 끝 `END0123456`이 말풍선 안, 내 머리줄 `시간 이름 [사진]`, 이어 쓴 내 글 머리줄 생략이 보인다.
5. **지적**: 차단 없음. 참고(비차단) — 머리줄 시간 글꼴이 직원 10pt·내 글 11pt로 기존 값을 그대로 둬 1pt 다르다. AC 범위 밖이다.
6. **미검증 범위**: 실제 서버 설치·실물 Slack/텔레그램/디스코드 전송(범위 밖, 별도 작업). 설치된 앱의 수동 확인.
7. **완료 조건**: 충족. 남은 것은 TASK-03 문서 커밋과 사용자 푸시 승인.
