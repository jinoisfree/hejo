## 검증 판정: HEJO-POST-GROUP-20261122 / 같은 직원 연속 답글 한 이름으로 묶기 (1차 검증, 2026-11-22)

1. **판정: 완료**
2. **검증 조건:** 교차 모델(계획·검증 Claude, 구현 Codex 별도 대화). 검토한 코드 상태: main `f3085af2265b41783894607e016031b95a3f7258`(코드 커밋 `aacf168`, 보고서 커밋 `f3085af`). 그 사이 `378ec4b`·`c8b2dcf`는 HEJO-FINDER-FOLDERS 문서 커밋으로 이 작업 파일과 겹치지 않음 [확인] `git show --stat`.
3. **설계 적합성(4.2):** 적합. 묶을지 판단은 `threadContent`(`ConversationView.swift:916-921`)가 `replies` 타임라인 바로 앞 원소가 화면에 보이고(`shownIDs`) 같은 직원(`role != owner`, `speaker` 일치)인지로 계산한다 — spec 용어 "바로 앞 답글"과 같다. `postPieces`는 생각 중 글이면 빈 조각(`:971`), 일반 글이면 `continuation=true`와 `textHelp`가 nil일 때만 시간(`:1017`), 버튼 나눔 앞부분에 같은 인자 전달(`:1084`). 입력 중 머리는 끼어듦 없음 + `shown.last`가 같은 직원일 때만 생략(`:941`). 사장 글(`mine`)에는 적용 안 됨. `NativeThreadCard`·문·기록 변경 없음. 설계와 다른 점 없음.
4. **직접 확인한 것:**
   - `HEJO_PYTHON=<Hermes venv> bash app/scripts/test.sh`(임시 HERMES_HOME·TMPDIR), HEAD `f3085af`: 종료 0, `AT-PG-01...11,13 PASS`, 기존 앱 시험·fixture 전부 OK. 로그 `.build/post-group-verify/app-test.log`.
   - `<Hermes venv> scripts/scan_private.py`(임시 HERMES_HOME): 종료 0(AT-PG-12). 로그 `.build/post-group-verify/scan.log`.
   - 게이트 pytest 434 passed는 구현 담당 로그 `.build/post-group-evidence/test.log`로 확인(이 작업은 gate·Python 파일을 바꾸지 않아 재실행 안 함).
   - 수락 시험 명세 `tests/acceptance/HEJO-POST-GROUP.md`·spec·design은 `d58248c` 이후 변경 없음 [확인] `git diff`. `aacf168`은 `ConversationView.swift`·새 `PostGroupTests.swift`·`TestMain.swift` 한 줄만 바꿔 기존 시험 기대값 변경 없음.
   - `PostGroupTests.swift`를 수락 시험 명세와 한 줄씩 대조: AT-PG-02 펼침 + `.stack` 없음 확인, AT-PG-05 전제(더미 "이전 답글 1개", 보이는 id 정확히 [A1,A2]) 먼저 assert 후 둘 다 false(가운데 beta·alpha 두 사례), AT-PG-13 다섯 단계 이름 머리 1·작업 줄 0/1/1/1/0·끝 시간 도움말. 기대값은 명세 그대로이며 구현에서 가져오지 않음.
   - Mutation 증거(`.build/post-group-evidence/mutation-*.log`): 묶음 제거·입력 머리 생략 제거·화면 표시 확인 제거가 각각 AT-PG-01·07·04에서 실패.
   - 도달 증거 수준: 1(빌드) + 2(실제 `ConversationView`에 가짜 문 프레임). 요구 수준 도달.
5. **지적:** 차단 0, 비차단 0. 기술 부채 0.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위와 남은 위험:** [미실행] 실제 앱 화면에서 직원이 파일을 먼저 보내는 상황 확인(수준 4, 완료 조건 아님 — 사장 확인 권장). 운영 앱 설치·공개판 빌드는 이 작업 범위 밖.
8. **미완료 원인:** 해당 없음.
9. **현재 명세 반영:** 이 저장소에 `docs/spec/current/`가 없고 현행 기준은 수락 시험 문서와 변경 문서다. spec.md 상태를 "적용"으로, tasks TASK-01을 "검증 완료"로 바꿨다. ARCHITECTURE 칸 변경 없음.
10. **푸시 관련 확인(읽기 명령만, 2026-11-22):** hejo `github` `main` = `eb5e62a`(hejo 0.2.4 공개 이력)이고 로컬 main과 공통 조상이 없다(`git merge-base --is-ancestor` 실패, 원격에만 8·로컬에만 499 커밋). 그래서 이 변경(`aacf168`)은 일반 `git push`가 아니라 다음 공개판(0.2.5 후보 → 사장 `hejo-ship publish`)으로 내보낸다. 이 작업에서 제안할 pushTargets 없음.
