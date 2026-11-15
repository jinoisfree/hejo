## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-22 hejo 홈 채널 자동 설정

1. **판정:** 부분 완료
2. **검증 조건:** 교차 모델(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당). 같은 대화 검토가 아니다. 다만 계획 담당이 설계도 맡았으므로 고위험 규칙(보완 15)에 따라 이 판정은 최대 부분 완료다. 검토한 코드 상태는 `b1ae3b2354babb50b7477ed5dfefb19c8027b055`이며, 깨끗한 임시 worktree에서 확인했다. 작업 트리의 `impl-report.md` 수정(TASK-20 착수 보류 8줄)은 실행 담당이 아직 커밋하지 않은 문서이고 제품 변경이 아니다.
3. **설계 적합성(4.2):** 대체로 충족하지만, 결함 하나를 계획 담당 설계에서 찾았다(V-1).
   - 맞는 점:
     - 최상위 `platforms.hejo.home_channel` 칸, 영수증 version 1 유지, `owner_may_change` 대상을 쓴다.
     - 갱신 경로는 pending을 먼저 저장하고, 실패하면 키 단위로 되돌린다. 맞춤 표 5행, `released`, `--uninstall-home-channel`, `missing_target`/`owner_set`도 들어 있다.
     - REQ-HF-25.AC-01과 AT-72 입력을 모두 다룬다.
   - 결함(V-1):
     - 16판 맞춤 표는 `applied`+값 없음을 늘 사장 변경(`released`)으로 본다.
     - 그래서 롤백이 키를 지운 뒤 영수증을 저장하기 전에 끊긴 경우와, 사장이 키를 지운 경우를 구별하지 못한다.
     - 결과적으로 이 경로에서 AC-01의 '`--check`는 빠진 프로필을 알린다'가 지켜지지 않는다.
4. **직접 확인한 것:**
   - `python3 .build/foundation9_runner.py hejo`(b1ae3b2 worktree): 종료 0, pytest 108 passed, 앱·대역 시험 통과. 로그 `/tmp/t22-review-full.log`.
   - 독립 돌연변이(검토자 작성): 갱신 실패 때 `remove_home_channels(added)`를 빼면 `test_install.py`가 1 failed / 31 passed로 잡아낸다. 소스는 원복했다.
   - 개인값 검사 `scripts/scan_private.py --repo .`(b1ae3b2): 종료 0.
   - 수락 시험 변경: `test_install.py`의 기존 줄 삭제는 0건이고 추가만 했다. `HEJO-FOUNDATION.md`의 AT 기대값 변경은 없다.
   - 실행 보고 대조: 보고한 변경 파일 6개가 git 변경과 같다. 보고에 없는 변경은 없다. 롤백 실패 사례 시험 확인(C1)의 읽기·쓰기 실패 → 종료 1·`applied` 유지 시험이 있다. 실행 담당의 돌연변이 3종 로그, 옛 설치 소스로 한 갱신(`task22-legacy.log` PASS), 공용 릴리스(`task22-release.json` 종료 0)도 확인했다.
   - 증거 수준: 2(임시 HERMES_HOME에서 실제 설치 도우미를 실행). 요구한 인계 수준 2에 도달했다. 최종 수준 4(운영 재시작 뒤 첫 답에 안내 없음)는 TASK-23 몫이다.
5. **지적 목록**
   - V-1
     - 위치: `install/hejo-install` `remove_home_channels`·`reconcile_home_channels`, design 'hejo 홈 채널' 맞춤 표
     - 위반 기준: REQ-HF-25.AC-01('`--check`는 빠진 프로필을 알린다', '어느 지점에서 끊겨도 맞춰진다')
     - 근거: worktree에 임시 시험을 넣어 재현했다. 설치 → `--uninstall-home-channel` 중 `save_receipt`에서 중단 → 다시 설치하면 종료 0, `preserved_owner_change`가 나오고 기본 프로필 `platforms`는 None이다(값이 돌아오지 않음). `--check`는 `owner_set`·종료 0이고 대상 상태는 `released`다.
     - 등급: 비차단(드문 중단 경로)이지만 TASK-23 롤백 전에 고친다.
     - 보낼 곳: 기획설계(설계 결함) → 17판 보완 16으로 구현에 넘긴다.
   - V-2
     - 위치: `run --check`
     - 위반 기준: design 점검 항목
     - 근거: `released`이고 값이 없는 프로필(사장이 키를 지움)에 `owner_set`을 출력한다(`test_at_hf_72_owner_change_check_and_forced_uninstall`이 `owner_set` 2개를 기대함). 값이 없는데 '사장이 정했다'고 알리게 된다.
     - 등급: 비차단
     - 보낼 곳: 기획설계 → 17판에서 `owner_removed`로 고친다(보완 16).
   - 기술 부채: 기존 비동기 pytest 경고·Swift Sendable 경고(실행 보고와 같음, 이번 변경과 무관).
6. **기획설계로 넘긴 것:** V-1·V-2를 계획 담당이 직접 고쳤다. design 17판(맞춤 표 `removing` 3행, 지우는 순서, `owner_removed`), AT-72 입력·기대값 추가, handoff 보완 16.
7. **미검증 범위와 남은 위험:**
   - 운영 공항 적용·재시작·새 세션 첫 답 확인은 수준 4이며 TASK-23에서 한다.
   - 비설계자 독립 검토는 아직 없다.
   - `.env`의 `HEJO_HOME_CHANNEL` 여부는 설계상 확인하지 않는다.
8. **미완료 원인 분류:** 설계 오류(V-1·V-2, 계획 담당 16판 맞춤 표). 완료까지 남은 조건은 다음과 같다.
   1. 보완 16 구현과 검토
   2. 비설계자 검토
   3. TASK-23 실물 수준 4
9. **현재 명세 반영 요청:** 없음(완료 아님).
