[설계 인계: HEJO-TIDY TASK-01b / 통합 줄의 수락 시험 조정·재검증]

0. **기준**
   - base: 공개 worktree `hejo-tidy-public-20261126` HEAD `e381cd08a46a37f3cd3d0395a59d58cd42b332d1`(M2).
   - 문서: 수락 시험 HEJO-DISCORD-SECTIONS 7판, HEJO-TIDY 3판.
   - 판정 근거: verdict 1회.
1. **문서:** [verdict.md](verdict.md) 1회, `tests/acceptance/HEJO-DISCORD-SECTIONS.md` 7판(AT-DK-22·23·54 행), [handoff.md](handoff.md)(TASK-01, 금지 범위는 그대로).
2. **할 일**
   1. `tests/acceptance/HEJO-DISCORD-SECTIONS.md` 7판을 공개 worktree에 그대로 복사한다. 개발 main 파일과 `cmp`로 같은지 확인한다.
   2. `tests/acceptance/test_discord_sections.py`의 줄 기준판 후보 맨 앞에 `1ca2cbbf25ddf8da0697e03175fb25292dabf701`을 추가한다. 순서: 1ca2cbb → c22e677 → adf54d7. HEAD의 조상인 첫 커밋을 고른다. 다른 단언은 바꾸지 않는다.
   3. `app/Tests/DiscordSectionsTests.swift`의 AT-DK-54 단언을 `GateClient.features == ["rooms", "discord"]`로 바꾼다. 메시지 문자열은 그대로 둔다. 그 줄에 telegram 글자가 남지 않아야 한다(AT-HTR-02).
   4. 하나의 커밋으로 만든다. 메시지 예: `Align Discord section checks with the Telegram-free public line`.
   5. 원격 확인: `git ls-remote github refs/heads/main`.
      - `425d565`이 아니면(예: HEJO-TELEGRAM-REMOVE `1fa08c6`이 먼저 푸시됨) `git fetch github` 뒤 `git merge --no-edit github/main`을 한다.
      - 충돌이 나거나, merge 전후 트리 diff에 `1fa08c6`·`425d565`·`1ca2cbb`에 없던 내용이 생기면 멈추고 보고한다.
      - `git diff <merge 전> <merge 후> --stat`을 기록한다.
   6. 재실행: AT-TIDY-01(최종 HEAD 기준, 원격 tip 조상 포함), AT-TIDY-02(필수 pytest 전체, `scan_private`, 앱 빌드), AT-TIDY-02a(M1·M2 비교는 1회 결과 유지, 최종 HEAD 규격이 M2와 같은지만 확인), AT-TIDY-03(기준선은 1회 결과 재사용 가능. 원격이 움직였으면 새 tip으로 다시), `bash app/scripts/test.sh`.
      - AT-CS-02·AT89·AT-UC-32·AT-HD-08이 실패하면 같은 실행기로 한 번 더 돌리고 두 결과를 모두 적는다(TD-1·TD-3).
   7. 증거는 `.build/tidy/task01b/`에 두고, 개발 main `impl-report.md`에 "TASK-01b" 절을 추가한다(`git commit --only`).
3. **유지할 계약:** 제품 코드 무변경이다. 이 작업에서 바뀌는 것은 시험 2파일과 수락 시험 명세 사본 1개, 원격 merge뿐이다.
4. **위험도·증거:** 일반, 2.
5. **변경 성격:** 시험 기대값을 승인된 7판에 맞추는 것뿐이다(제품 의미 변경 없음).
6. **금지:** git push, 서버 쓰기, 앱 설치, rebase·force, 제품 코드 수정, 7판에 없는 기대값 변경.
7. **병렬 갈래:** 없음(갈래 3개 미만, 경미 시험 조정).

## 보완 2판 (검증 2회 뒤)

1. 공개 worktree의 `tests/acceptance/HEJO-DISCORD-SECTIONS.md`를 개발 main 8판으로 덮어쓴다. `cmp`로 같은지 확인한다.
2. 커밋을 하나 새로 만든다(amend 금지). 메시지 예: `Keep the Discord sections acceptance record Telegram-free`.
3. 재실행할 것:
   - AT-HTR-02.
   - 필수 pytest 묶음(AT-TIDY-02).
   - 전체 pytest와 기준선 JUnit 비교(AT-TIDY-03, 기준선은 이전 결과 재사용).
   - 런타임 Python `scan_private`.
   - 원격 재조회와 fast-forward 확인. 원격이 움직였으면 위 1판 5번 규칙을 따른다.
   - 앱 시험과 빌드는 앱·제품 파일 변경이 없으므로 다시 돌리지 않는다. 39dbaea 결과를 재사용한다.
4. 증거는 `.build/tidy/task01b2/`에 두고, 개발 main `impl-report.md`에 "TASK-01b 보완 2" 절을 추가한다(`git commit --only`).
5. 금지 범위는 1판과 같다.
