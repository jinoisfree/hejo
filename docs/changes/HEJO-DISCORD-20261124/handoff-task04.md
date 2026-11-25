# 설계 인계: HEJO-DISCORD / TASK-04 공개 통합 (1판, 2026-11-25)

0. 기준: 검증 완료 개발 커밋 `3b9da3d3007f62d4cbce8f4669691f4eb73fcc63`(verdict 4회, 브랜치 `role-workflow/37-cdc4976c`). 개발 기준 `236b0177468b90d9ea23a1b1190e996db78a0694`. 공개 원격 `github/main` tip `27e0e95fab5de0294ae925c188bb50f5ba361411`(2026-11-25 읽기 확인, 개발 main과 공통 조상 없음). 승인: 사용자 "진행해보자 남은일들"(2026-11-25). 운영 모드: 연합개발(교차 모델).

1. 공식 문서: 이 폴더의 spec·design·tasks·verdict(4회), 수락 시험 명세 `tests/acceptance/HEJO-DISCORD.md`. 선례: HEJO-SMOOTH handoff "TASK-10 공개 통합".

2. 목표: 개발 커밋의 디스코드 제품 변경과 시험을 공개 tip 위로 옮기고, 공개 트리에서 다시 검증해 푸시 후보 커밋을 만든다.

3. 이식 범위: `git diff 236b017 3b9da3d`에서 다음 19개 경로만. 개발 main에서 merge로 들어온 목업·작업 문서는 이식하지 않는다.
   - 공개 tip과 개발 기준이 같은 파일(그대로 적용될 것): `gate/discord.py`(새), `gate/__init__.py`, `gate/adapter.py`, `gate/rooms.py`, `gate/server.py`, `gate/README.md`, `schemas/hejo-wire-v1.json`, `tests/acceptance/test_discord.py`(새), `tests/acceptance/test_slack_move_gate.py`, `app/Sources/DiscordState.swift`(새), `app/Sources/AppDelegate.swift`, `app/Sources/PetSettingsWindow.swift`, `app/Sources/SettingsPages.swift`, `app/Tests/DiscordTests.swift`(새), `app/Tests/TelegramTests.swift`, `app/Tests/legacy_feature_fixture.py`.
   - 공개 tip에서 내용이 다른 파일(손으로 옮길 수 있음): `app/Sources/GateClient.swift`, `app/Sources/ConversationController.swift`, `app/Tests/TestMain.swift`. 공개판 구조를 유지하고 같은 변경만 옮기며 위치를 보고한다. 의도 판단이 필요한 충돌은 멈춰 보고한다.
   - AT-SM-02 해시: 공개 tip의 규격 파일이 개발 기준과 같으므로 갱신값 `c91a7a4f93a008028809871f377cf6b240c4a4095fab819b48fc69d122ce4bec`가 그대로 맞아야 한다. 다르면 멈춘다.

4. 작업 위치: 저장소 바깥 형제 폴더 `../.worktrees/hejo-discord-public-20261125`, 브랜치 `hejo-discord-public-20261125`, 시작점 = 원격 공개 tip(읽기 명령으로 다시 확인, 낡았으면 fetch만). 같은 이름이 있으면 멈춘다. 개발 worktree·계획 담당 체크아웃·다른 공개 작업 공간을 건드리지 않는다. 두 이력을 merge하지 않는다.

5. 검증(공개 트리에서, 개발 증거로 대신하지 않음, Hermes venv): `bash scripts/test.sh`, `bash app/scripts/build.sh`, `python3 scripts/scan_private.py` 모두 종료 0. `tests/acceptance/test_discord.py` 전체와 mutation 5종. `tests/acceptance/test_telegram.py` 무수정 통과. 공개 tip 자체에서 이미 실패하는 항목이 있으면 tip에서도 실행해 그대로 기록한다. AT-UC-32가 한 번 실패하면 같은 트리 재실행 1회까지 허용하고 두 결과를 모두 기록한다.

6. 커밋: 제품·시험만 한 커밋(자기 경로만 `git commit --only`). 작업 문서와 현재 명세(`docs/ARCHITECTURE.md`, `docs/spec/current/hejo-discord.md`)는 계획 담당이 검토 뒤 같은 브랜치에 문서 커밋으로 더한다.

7. 금지: 운영 서버(`~/.hermes`) 설정·설치·재시작, 공용 릴리스 갱신, 비밀 파일, 실제 디스코드·텔레그램·Slack 발신, Hermes 본체, `gate/telegram.py`·`telegram_comments.py` 수정, 수락 기준 수정, 개인값, git push.

8. 보고: impl-report.md 맨 위에 "TASK-04 공개 통합 결과" 절 — 공개 tip 해시, 통합 커밋 전체 해시, 손으로 옮긴 위치, 명령·종료 코드·로그 경로, 미검증 범위, 푸시 후보(저장소 경로·원격 `github`·브랜치 `main`·커밋, 원격 tip이 조상인지).

9. 위험도: 고위험(통합 대상이 운영 설치 원본). 증거 수준 2 + 정착 3. TASK-03(운영 적용)은 이 커밋이 푸시된 뒤 `handoff-task03.md`로 별도 허가.

## 보충 1 (2026-11-25, verdict 5회)

- 목업 개인값: 공개 tip에도 같은 목업 14개(개발 기준과 blob 동일)가 있어 `scan_private.py`가 실패한다. 개발 main 커밋 `20f1f7cf30cd046e19201c153d7c217ed66f1925`의 목업 14개 변경을 공개 브랜치에 **별도 커밋**으로 이식한다(`git diff 236b017 20f1f7c -- docs/changes/HEJO-DRAWER-INLINE-20261122/mockups docs/changes/HEJO-UI-CLEAN-20261123/mockups`가 그대로 적용돼야 한다. 안 되면 멈춘다). 이식 뒤 공개 트리 `scan_private.py` 종료 0이 조건이다.
- 설정 보호 검사(`app/Tests/settings_guard.py`, "Real settings metadata changed"): 공개 tip 단독에서도 같은 실패, 시험 프로세스가 없는 30초에도 hejo 설정 메타데이터가 바뀜(실행 중인 설치 앱이 쓰는 것으로 보임) — 환경 요인, 기술 부채로 기록한다(선례 HEJO-RECONNECT V-HR-02). 조건: `scripts/test.sh`가 그 단계 **하나만** 실패하고 그 앞 단계(Python 전체, 게이트웨이, 앱 단위, 연동 12, 훅 9)가 모두 통과. 다른 실패가 있으면 멈춘다. 이 조건을 채우면 커밋한다.
- 커밋 순서: (1) 목업 정리 커밋 (2) 디스코드 제품·시험 커밋(현재 staged 19개). 두 커밋 모두 자기 경로만 `git commit --only`. 최종 트리로 `scan_private.py`·`app/scripts/build.sh`·`test_discord.py`를 다시 실행하고, `scripts/test.sh`는 위 조건으로 판정한다.

## 보충 2 (2026-11-25, 푸시 준비: 개발 기준 합치기)

- 이유: 플러그인 푸시 검사는 공개 통합 대상(`publicIntegration`)에서도 개발 기준 브랜치(로컬 `main`)가 개발 커밋의 조상이기를 요구한다. 개발 `main`이 `2b0946d`(HEJO-SMOOTH 개발 통합 `e54e1c7` 포함)로 앞서 있다. 공개 브랜치에는 개발 `main`을 합치지 않는다(이력 무관).
- 할 일: 개발 worktree(브랜치 `role-workflow/37-cdc4976c`)에 그 시점의 로컬 `main`을 `git merge main`으로 합친다. 충돌은 `app/Sources/GateClient.swift`·`ConversationController.swift`·`app/Tests/TestMain.swift` 등에서 날 수 있다. 공개 통합 커밋 `86fb981`의 같은 파일(공개판은 이미 매끄러움 작업을 포함)을 기준으로 "양쪽 변경 모두 유지"로 정리한다. 의도 판단이 필요하면 멈추고 보고한다. rebase·force 금지.
- 확인: 합친 뒤 개발 트리의 디스코드 19개 경로가 공개 커밋 `86fb981`과 같은지(앱 3개는 의미상 같은지) 비교해 기록한다. Hermes venv로 `scripts/test.sh`(설정 보호 단독 실패는 보충 1 조건), `app/scripts/build.sh`, `scan_private.py`, `test_discord.py`를 실행한다.
- 공개 브랜치 `hejo-discord-public-20261125`(`f69b46a`)는 바꾸지 않는다. 계획 담당은 이 합치기가 끝날 때까지 `main`에 커밋하지 않는다.

## 보충 3 (2026-11-25, 공개 main이 앞섬: 다시 옮기기)

- 사실: 공개 원격 `github/main`이 `59589595bf769badfc7928ab1203f0b915cd3710`(HEJO-SMOOTH2/HISTORY, 부모 `27e0e95`)로 앞서 `f69b46a`는 빨리 감기가 안 된다. 그 커밋은 `gate/server.py`·`gate/__init__.py`·`schemas/hejo-wire-v1.json`·`tests/acceptance/test_slack_move_gate.py`(AT-SM-02 해시 `7508984f…`)·앱 4개(`AppDelegate`·`ConversationController`·`GateClient`·`TestMain`)를 바꿨고, 개발 main에서 복사된 옛 HEJO-DISCORD 작업 문서를 담았다. 디스코드 코드(`gate/discord.py`)는 없다. 목업 14개는 아직 옛 내용이다. 개발 로컬 `main`도 `0748f3d`로 다시 앞섰다.
- A. 개발: 개발 worktree(`role-workflow/37-cdc4976c`)에 그 시점의 로컬 `main`을 다시 `git merge main`. 정리 원칙은 보충 2와 같다.
- B. 공개: 같은 공개 worktree에서 `github/main`(`5958959`, 읽기로 재확인)을 시작점으로 새 브랜치 `hejo-discord-public-20261125b`를 만든다(옛 브랜치는 보존). 그 위에 `b68aaf2`(목업 14개)와 `86fb981`(디스코드 제품·시험)을 순서대로 cherry-pick한다. `f69b46a`(문서)는 가져오지 않는다 — 문서 커밋은 계획 담당이 다시 만든다. 충돌은 "공개 main의 새 변경(기록 전송 HISTORY 등)과 디스코드 추가를 모두 유지"로 정리하고, 의도 판단이 필요하면 멈춘다. 두 이력 merge·rebase·force 금지.
- C. AT-SM-02: 합친 `schemas/hejo-wire-v1.json`이 `5958959` 대비 디스코드 정의 6종 추가와 세 `oneOf` 목록 뒤 추가뿐임을 JSON 비교로 확인한 뒤에만, 해시를 새 값으로 바꾸고 주석 한 줄(`HEJO-DISCORD added definitions only (verdict 2회, B-1)`)을 유지한다. 그 외 차이가 있으면 멈춘다.
- D. 검사(공개 새 브랜치 최종 트리, Hermes venv): `scripts/test.sh`(설정 보호 단독 실패만 보충 1 조건), `app/scripts/build.sh`, `scan_private.py` 종료 0, `test_discord.py` 전체, `test_telegram.py`, mutation 5종. A의 개발 트리도 `scripts/test.sh`·`test_discord.py`. 디스코드 19개 경로를 개발 트리와 비교해 기록.
- 계획 담당은 이 작업이 끝나 푸시될 때까지 개발 `main`에 커밋하지 않는다(이 보충과 verdict 7회는 미커밋으로 둔다).
