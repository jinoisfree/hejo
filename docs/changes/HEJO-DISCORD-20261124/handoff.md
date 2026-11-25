[설계 인계: TASK-01·TASK-02 / HEJO-DISCORD 디스코드 창]

0. 기준: base_commit `236b0177468b90d9ea23a1b1190e996db78a0694`(main) / spec·design·수락 시험 2판 / 2026-11-24 / 승인: 사장 브레인스토밍 결정(brainstorm.md), 계획 검증 1회차 BLOCKED 반영([plan-review.md](plan-review.md)), 2회차 APPROVED / 운영 모드: 연합개발(교차 모델, 계획 검증 켜기) / 재시작(2026-11-24): 이전 작업 #36과 같은 계획으로 새 작업을 시작함. main HEAD 재확인 결과 base_commit 그대로. 작업 위치는 플러그인이 만든 작업 공간이 있으면 그것을, 없으면 9번의 worktree를 쓴다

1. 공식 문서: [ARCHITECTURE](../../ARCHITECTURE.md), [spec](spec.md), [design](design.md), [tasks](tasks.md), [수락 시험](../../../tests/acceptance/HEJO-DISCORD.md), 통신 규격 `schemas/hejo-wire-v1.json`, 선례 [HEJO-TELEGRAM design](../HEJO-TELEGRAM-20261122/design.md)·`gate/telegram.py`(커밋 `236b017`). 이 작업 문서는 아직 커밋되지 않았으므로 main 작업 폴더(`docs/changes/HEJO-DISCORD-20261124/`, `tests/acceptance/HEJO-DISCORD.md`)에서 읽는다.

2. 요구와 수락 기준: REQ-HD-01~08(TASK-01: 01~07, TASK-02: 08). 핵심: 짝지은 서버·사장 계정의 포럼 글 → 기록장 사장 글(중복 없이, 원문 그대로), 기록장 글 → 현재 방 채널의 포럼 글(웹후크 이름, 멘션 해제, 채널 재생성·글 묶음 없음 대체), Hermes 원래 처리기는 닫힘 운영으로 들이기에서 거부되고 문은 글마다 닫힘 확인 후 열려 있으면 물러남.

3. 반드시 유지할 기존 계약: 기록장 레코드 종류, 앱 프레임 기존 종류, 텔레그램 창 전체 동작(`test_telegram.py` 무수정 통과), `register_platform_handler` 외 Hermes 무수정, 기존 `hello.features` 값 유지(추가만).

4. 책임과 흐름: `gate/discord.py`가 디스코드 창 전부를 맡는다. 수신은 봇에 붙인 hejo 듣기(`add_listener`) 한 경로이며 원래 처리기는 감싸지 않는다(design 2·2.2절). 발신은 `_record` → 정착 → 4절 글 묶음 선택 → 채널 웹후크(design 4·5절).

5. 기존 경로 판정: design 8절. 텔레그램 다리 유지(손대지 않음), 어댑터의 텔레그램 호출 자리 옆에 디스코드 호출 추가, `claims_external` 유지.

6. 위험도: 고위험(인증·권한·운영 게이트웨이·데이터 무결성). 증거 수준: TASK-01 2(대역) + 정착 3, TASK-02 1~2. 고위험 롤백: design 10절(운영 적용은 TASK-03에서만).

7. 변경 성격: 신규 기능(의미 변경 없음). 비교: AT-HD-41(디스코드 유무 동일성), AT-HD-44(텔레그램 회귀), AT-HD-30(원래 디스코드 경로 무변경·무부작용).

8. 수락 시험: AT-HD-01~17·20~45(문 43개), AT-HD-50~53(앱 4개). AT-HD-30은 실제 `DiscordAdapter`를 Hermes 시험 선례(`~/.hermes/hermes-agent/tests/gateway/test_discord_free_response.py`의 가짜 `discord` 모듈)로 import해 원래 경로부터 시험한다. discord.py를 운영 Hermes 환경에 설치하지 않는다. 기대값 출처 spec·design. 상태: 명세 완료 / 코드 미작성 / 미실행 / 명세 검토 완료(계획 검증 2회차·재시작 3회차 APPROVED, plan-review.md) — 코드·실행 결과는 미검토.

9. 작업 범위: tasks.md TASK-01·02 파일만. 금지: Hermes 본체·플러그인, `gate/telegram.py`·`gate/telegram_comments.py`, 운영 공항(`~/.hermes`) 설정·재시작·설치, 비밀 파일, 실제 디스코드·Slack·텔레그램 발신, 수락 기준·수락 시험 명세 수정. 작업 위치: 새 worktree `../.worktrees/hejo-discord-20261124`(브랜치 `hejo-discord-20261124`, base_commit에서). main 작업 폴더의 커밋 안 된 텔레그램 댓글 작업(`gate/telegram_comments.py` 등)은 가져오지도 건드리지도 않는다. 선행: 없음. 병렬 갈래: 없음(갈래 3개 미만, tasks.md).

9-1. 보완(검증 1회, [verdict.md](verdict.md)): V-1 `gate/rooms.py`의 `room_command`에 디스코드 알림 한 곳 허가(design 2절). V-2 `app/Sources/PetSettingsWindow.swift` 허가. V-3 `app/Tests/TelegramTests.swift`의 기능 목록 정확 비교를 세 기능으로 갱신 허가(`tests/acceptance/test_telegram.py`는 계속 무수정). 수락 기준·기대값은 그대로다. 같은 worktree의 미커밋 초안을 이어서 쓴다.

9-2. 보완(검증 2회, [verdict.md](verdict.md) 2회 절):
    - B-1 허가: `tests/acceptance/test_slack_move_gate.py`의 AT-SM-02 규격 해시 한 줄을 `c91a7a4f93a008028809871f377cf6b240c4a4095fab819b48fc69d122ce4bec`로 바꾸고, 바로 위 주석에 "HEJO-DISCORD added definitions only (verdict 2회, B-1)" 한 줄을 더한다(선례: HEJO-DEADLINE-CLOSE·HEJO-TELEGRAM). 그 시험의 다른 줄은 바꾸지 않는다. 해시 갱신 뒤 규격 파일을 다시 고치면 멈추고 보고한다.
    - B-2 분류: 기존 문제(이 작업 밖). 검출 14개 mockup HTML은 base_commit의 추적 파일 그대로이며, main 작업 폴더에는 이를 고친 미커밋 변경이 있어 main에서는 검사가 종료 0이다. 구현 담당은 mockup을 고치거나 가져오지 않는다. 이번 회차 조건: 검출 파일 집합이 그 14개와 같고 이번 변경 파일 검출 0. AT-HD-45의 "종료 0"은 mockup 정리가 기준 브랜치에 들어와 merge된 뒤 최종 확인한다(푸시 전 조건).
    - B-3 분류: 기존 불안정 시험(다른 작업 보고에서 기준판 재현·간헐 통과 기록). AT-UC-32와 판정 단추 코드를 고치지 않는다. 해시 갱신 뒤 `bash scripts/test.sh`를 다시 실행하고, 앱 단계가 AT-UC-32에서만 멈추면 (가) base_commit 빌드에서 `app-tests --ui-clean-polish`가 같은 단언으로 실패함을 보이고 (나) `app/scripts/test.sh`의 나머지 단계(다른 unit 진입점, 모든 fixture, test_hooks)를 하나씩 실행해 종료 코드를 남긴다. AT-UC-32 외 실패가 하나라도 있으면 멈추고 보고한다.
    - 위 조건을 채우면 커밋한다(자기 경로만 `git commit --only`). "전체 검사 모두 통과"가 아니어도 되며, 보고서에 B-2·B-3 예외를 그대로 적는다.

9-3. 보완(검증 3회, [verdict.md](verdict.md) 3회 절): F-1 — `gate/discord.py`의 발신에서 대체 발신(`thread_name`)까지 `NotFound`면 그 채널의 웹후크 캐시 항목을 버린다(design 5절). 처음부터 새 포럼 글로 보내다 `NotFound`가 난 경우도 같다. 그 글은 재시도하지 않고 기존처럼 로그만 남긴다. `tests/acceptance/test_discord.py`에 "웹후크가 지워진 뒤 첫 글은 실패(로그), 다음 글은 웹후크를 다시 만들어 전달"을 확인하는 시험을 더한다(AT-HD 번호를 새로 만들지 않고 발신 실패 시험 옆에 둔다). mockup 정리는 main `20f1f7cf30cd046e19201c153d7c217ed66f1925`에 커밋됐다(계획 담당이 그 커밋 단독 트리로 `scan_private.py` 종료 0 확인). 구현 담당은 main을 worktree 브랜치에 merge(충돌 시 멈추고 보고)한 뒤 F-1을 고치고, 전체 검사 3종(`scripts/test.sh`, `app/scripts/build.sh`, `scan_private.py`)을 모두 종료 0으로 다시 실행한다.

10. 가정·미확정:
    - [가정] `commands.Bot.add_listener`가 `@client.event` 처리기와 함께 불린다 — AT-HD-01을 실제 discord.py 없이 가짜로 시험하므로, 구현 중 discord.py 2.7.1 소스(설치하지 말고 내려받은 원본 읽기 또는 공개 문서)로 확인해 impl-report에 근거를 적는다. 틀리면 멈추고 보고.
    - [가정] 웹후크 `send`의 `thread_name`(포럼 새 글)·`thread`(글 묶음 안) 인자와 없는 글 묶음에 보낼 때의 `NotFound`가 discord.py 2.7.1에 있다 — 같은 방식으로 확인.
    - [확인] 닫힘 운영의 근거: `_discord_message_admission`(D:1483-1530)이 `_is_allowed_user`(D:3951~) 거짓이면 부작용 없이 거부. 문은 `_is_allowed_user`·`_get_allow_bots`(D:4980)를 읽기만 하며, 예외면 열림으로 본다.
    - [미확인] 웹후크 파일 한도 → 상수 8 MiB, 실물 M7(TASK-03).
    - 착수 차단 없음.

11. 사용자 확인: 브레인스토밍에서 목적·범위·디스코드 채택·텔레그램은 별도 작업으로 끄기를 사장이 결정. 커뮤니티 켜기·웹후크 이름 표시·꺼진 동안 글 미수신은 에이전트 제안이며 계획 보고에서 사장에게 알림.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환: main HEAD = base_commit. 커밋 안 된 변경(텔레그램 댓글 작업)은 범위 밖이며 worktree가 분리한다.
- G1~G4: G3의 독립 검토는 계획 검증(교차 모델)으로 받는다. 통과 전 구현 착수 불가.
