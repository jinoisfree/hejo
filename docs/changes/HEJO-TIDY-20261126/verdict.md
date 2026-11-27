# HEJO-TIDY 검증 판정

## 검증 판정 1회 (2026-11-26): TASK-01 공개 통합

1. **판정: 미완료.** 통합 자체는 맞다. 다만 두 작업의 수락 시험이 서로 모순되어 필수 시험 2건이 실패하고, 앱 시험 1건이 실패한다. 이 상태로는 푸시하지 않는다.
2. **검증 조건**
   - 교차 모델: 구현 codex, 검증 Claude(계획 담당 대화).
   - 대상: 공개 worktree `../.worktrees/hejo-tidy-public-20261126`의 M1 `688964c9c91e3525939ef167ed9d777b5a8c3b52`(425d565 + a6d5e9a)와 M2 `e381cd08a46a37f3cd3d0395a59d58cd42b332d1`(M1 + 1ca2cbb). 작업 트리는 깨끗하다.
   - 보고서: 개발 main `c4ea9da`.
3. **설계 적합성(4.2):** 부적합 1건.
   - design D-01의 병합 순서와 충돌 해결 규칙은 맞게 적용됐다. 규격 세 비교도 통과했다.
   - 그러나 설계가 두 작업의 **수락 시험끼리 충돌하는지**를 조사하지 않았다. HEJO-DISCORD-SECTIONS 6판은 텔레그램이 있던 공개 줄을 기준으로 다음 둘을 고정했다:
     - AT-DK-22(c)·23: `test_discord.py`가 줄 기준판 `c22e677`과 바이트가 같을 것.
     - AT-DK-54: `features == [rooms, telegram, discord]`.
   - 그런데 HEJO-TELEGRAM-REMOVE는 같은 파일과 같은 값을 바꾸도록 정했다: AT-HTR-20 `[rooms, discord]`, AT-HTR-02 추적 파일에 telegram 0.
   - 따라서 통합 줄에서는 두 쪽을 동시에 만족할 수 없다.
4. **직접 확인한 것**(증거 수준 2)
   - `.build/tidy/task01/schema.txt`: M1·M2·T0..M2 모두 PASS. AT-SM-02 = `966e53c3…`.
   - `junit-comparison.json`:
     - 기준선 586 중 실패 1(`test_at_hf_08[True]`, 기존).
     - M2 590 중 실패 3: 위 기존 1건에 더해 `test_at_dk_22_discord_schema_structure`, `test_at_htr_02_tracked_sources`.
     - 오류·건너뜀 0. 삭제 노드는 텔레그램 시험과 AT-OP-10·14 텔레그램, AT-HD-34뿐이다.
   - M2 `app/Tests/DiscordSectionsTests.swift:104`는 `["rooms","telegram","discord"]`를 단언한다. `app/Sources/GateClient.swift:25`는 `["rooms","discord"]`다. 보고 내용과 같다.
   - `test_discord_sections.py:585`의 줄 기준판 후보는 `c22e677`·`adf54d7` 두 개뿐이다.
   - 원격: `git ls-remote` 결과 `425d565`. M2는 fast-forward 가능하다.
5. **지적**
   - V-01(차단, 수락 시험 오류): HEJO-DISCORD-SECTIONS AT-DK-22(c)·23·54가 텔레그램이 있는 공개 줄에 고정돼 있어, 텔레그램 제거와 통합된 줄에서 거짓 실패한다.
     - 처분: 수락 시험 7판으로 고쳤다. 줄 기준판에 `1ca2cbb`를 추가했고, AT-DK-54는 "줄 기준판의 기능 목록 보존"으로 바꿨다.
     - 앱 시험 104행은 `["rooms","discord"]`로 바꾼다(구현 담당).
   - V-02(비차단, 조정): HEJO-TELEGRAM-REMOVE의 별도 계획 대화가 후보 `1fa08c6`(1ca2cbb + 425d565, verdict 13회)으로 푸시 승인을 기다린다.
     - 그것이 먼저 푸시되면 M2는 fast-forward가 아니게 된다. 다만 `1fa08c6`의 내용은 M2에 이미 다 들어 있다.
     - 처분: 보완 인계에 "원격이 움직였으면 `github/main`을 merge하고, 트리 변화가 없는지 확인한 뒤 재검사"를 넣었다.
6. **기획설계로 넘긴 것:** V-01은 계획 담당이 이미 반영했다(DISCORD-SECTIONS 수락 시험 7판).
7. **미검증 범위:** 서버 문과 설치 앱(이 작업 범위 밖).
8. **미완료 원인 분류:** 수락 시험 오류(DISCORD-SECTIONS 6판). 그리고 HEJO-TIDY 설계 누락(작업 간 수락 시험 충돌 미조사).
   - 완료 조건: TASK-01b 수행 → AT-TIDY-02·02a·03 재실행 시 새 실패 0, 앱 시험 종료 0(TD-1 불안정 시험은 재실행 규칙) → 재검증 → 푸시 1 승인.

## 검증 판정 2회 (2026-11-26): TASK-01b

1. **판정: 미완료.** 시험 코드 조정은 맞다. 그러나 공개판에 새로 들어간 수락 시험 문서 7판이 AT-HTR-02(추적 파일에 영문 telegram 0)에 걸린다.
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 대상: 공개 worktree HEAD `39dbaea7d0c94aea294e9f52ba5ca1696df4591e`(M2 + 1커밋). 보고서: 개발 main `6cb615a`.
3. **설계 적합성(4.2):** 부적합 1건(인계 오류).
   - handoff-task01b가 7판 문서를 공개 줄로 "복사"하라고 했다. 하지만 그 문서는 원래 공개 줄에 없었다(`git ls-tree e381cd0 tests/acceptance/`에 HEJO-DISCORD-SECTIONS.md 없음).
   - 7판에는 영문 `telegram` 표기 3곳(36·55·61행)이 남아 있었다.
   - 시험 두 파일의 변경은 7판 기대값과 같다.
4. **직접 확인한 것**(증거 수준 2)
   - `git diff e381cd0 39dbaea`: 바뀐 것은 Swift 104행 `["rooms", "discord"]`, Python 기준판 후보 맨 앞 `1ca2cbb`, 새 문서 1개다. 제품 파일 변경은 0이다.
   - 보고: 앱 시험·Discord 섹션·OWNER-PROFILE·history·빌드·개인값 검사는 각각 종료 0이다. 전체 pytest의 새 실패는 AT-HTR-02 1건뿐이고, 원인은 이 문서다.
   - 검사기와 같은 규칙으로 7판 문서에서 영문 표기를 세어 보니 3곳이었다. 보고와 같다.
5. **지적**
   - V-03(차단, 수락 시험 오류·인계 오류): 7판 문서에 영문 텔레그램 표기가 있고, 공개 줄 반입을 지시했다.
   - 처분: 8판으로 고쳤다. 세 곳을 뜻 그대로 한글 표기로 바꿨고 기대값은 무변경이다. 같은 규칙의 잔여 일치는 0이다.
6. **미완료 원인 분류:** 수락 시험 오류(계획 담당).
   - 완료 조건: 공개 사본을 8판으로 교체 → AT-HTR-02를 포함한 필수 pytest 0, 전체 pytest의 새 실패 0 → 재검증 → 푸시 1 승인.

## 검증 판정 3회 (2026-11-26): TASK-01 최종 후보

1. **판정: 완료(TASK-01).** 푸시 후보는 `a90dc1d4c767add55a3e7c41c5638430be854dec`다.
   - 공개 worktree `hejo-tidy-public-20261126`.
   - 이력: `425d565` → M1 `688964c` → M2 `e381cd0` → `39dbaea` → `a90dc1d`.
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 작업 트리는 깨끗하다.
3. **설계 적합성(4.2):** 적합.
   - REQ-TIDY-01 AC-01~04를 충족한다.
   - 두 작업의 승인 동작(Discord 섹션 동기화, 텔레그램 부재, 사장 프로필)이 함께 있다.
   - 수락 시험 충돌은 DISCORD-SECTIONS 8판으로 풀었다. 기대값의 의미는 바뀌지 않았다.
4. **직접 확인한 것**(증거 수준 2)
   - 개발 main 8판과 공개 사본이 `cmp`로 같다.
   - `git ls-remote github refs/heads/main` = `425d565`이고, `merge-base --is-ancestor github/main HEAD` 종료 0이다. 따라서 fast-forward다.
   - `task01b2/junit-comparison.json`: 590개 중 589 통과, 실패는 기존 `test_at_hf_08[True]` 하나뿐이다. 오류·건너뜀 0이다.
   - AT-HTR-02 단독 실행 1 passed, `scan_private` 종료 0.
   - `git grep -il telegram`에서 남은 일치는 문서와 시험 안의 `HEJO-TELEGRAM*` 작업 이름, 그리고 Hermes 번역 키뿐이다(AT-HTR-02 허용 범위).
   - 앱 빌드·시험은 `39dbaea` 결과(종료 0)를 재사용했다. 그 뒤 바뀐 것은 문서 1개라 영향이 없다.
   - 규격 3비교 PASS, AT-SM-02 = `966e53c3…`(1회).
5. **지적:** 없음. 기술 부채: 기존 TD-1·TD-3.
6. **조정 사항:** HEJO-TELEGRAM-REMOVE 쪽 별도 후보 `1fa08c6`은 `a90dc1d`에 내용이 모두 들어 있다(`1ca2cbb`과 `425d565`가 모두 조상).
   - `a90dc1d`를 먼저 푸시하면 `1fa08c6`은 더 푸시할 필요가 없다.
   - 그쪽을 먼저 푸시하면 `a90dc1d`는 fast-forward가 아니게 되어, merge 뒤 다시 승인받아야 한다.
7. **남은 조건:** 푸시 1(사용자 승인) → `ls-remote` 확인 → TASK-03 인계. 앱 릴리스와 현재 명세 반영은 뒤 작업이다.

- **원격 반영(2026-11-26):** 사용자가 푸시했다. `git ls-remote github refs/heads/main` = `a90dc1d4c767add55a3e7c41c5638430be854dec`, `merge-base --is-ancestor a90dc1d github/main` 종료 0. TASK-02 완료. HEJO-TELEGRAM-REMOVE의 `1fa08c6`은 더 푸시할 필요가 없다(내용 포함).

## 검증 판정 4회 (2026-11-26): TASK-03 이전판 정리 + 절차 + V-3 + V-4

1. **판정: 완료(TASK-03, 증거 수준 2).** 실물 확인 M-01은 릴리스(TASK-04, 맨 마지막) 뒤에 한다.
   - 푸시 후보: `878ce94fe228d274e6a33248e4e7d4a4d8e804d6`(`a90dc1d` → `8de1848` → `5e18f50` → `c888671` → `878ce94`).
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 작업 트리는 깨끗하다. 구현 보고: 개발 main `14b03b8`.
3. **설계 적합성(4.2):** 적합.
   - **공항 설계(ARCHITECTURE 3·6·8절)**
     - 정리 기능은 관제 화면 칸(`app/Sources/StaleCopies.swift`)에만 있다. 새 설정·저장 파일은 0이고, 기록은 OS 통합 로그뿐이다.
     - 옮기는 대상은 같은 번들 ID의 자기 이전판뿐이다. 사장 칸과 `~/Library/Application Support/hejo`는 건드리지 않는다.
     - `install/` 변경 0(D-03). 판정 원본은 앱 한 곳이다.
   - **D-02:** 설치 위치 판정을 복제하지 않았다. `LoginLaunch.applicationFolders` 하나로 묶고 `isInstalled`와 정리가 함께 쓴다. 기존 호출부는 기본값 인자로 그대로다.
   - **V-4(D-05):** 바뀐 것은 이어 붙이는 경우에 `preview.strip()`을 쓰는 한 줄뿐이다. 판정 규칙과 300 글자 묶음은 그대로다.
   - **V-3(D-06):** 실제 앱 경로를 쓴다. 말풍선은 `ConversationView.openFromBubble`(`AppDelegate.swift:286`과 같은 입구), 섬은 `island.onAction`(`ConversationView.swift:272`).
4. **직접 확인한 것**(증거 수준 2)
   - 코드 읽기: `StaleCopies.clean`의 조건이 spec 조건 1~4와 같다(같은 ID, 자기 아님, 정수 빌드 < 자기, 실행 중 아님).
     - 두 폴더 모두 최상위만 본다. 심볼릭 링크와 디렉터리가 아닌 항목은 건너뛴다.
     - 휴지통 실패는 로그만 남기고 다음 사본으로 넘어간다.
     - 실제 실행에서는 `trashItem`이 돌려준 결과 경로를 남긴다.
   - 시험 코드 `StaleCopiesTests.swift`가 다루는 것:
     - AT-TIDY-04·04b(두 폴더 × 자기 위치 두 경우, 각 정확히 2건)
     - 05(다른 ID·plist 없음·`abc`·빌드 11)
     - 06(설치 위치 밖), 07(하위 폴더·실행 중)
     - 08(첫 실패 뒤 계속), 08b(이동·실패 기록)
   - 기본 앱 시험 목록에 등록됐다(`TestMain.swift`).
   - 증거 `.build/tidy/task03/`
     - 기준본(`a90dc1d`):
       - 정리 시험은 기능이 없어 형검사 종료 1. 재현 시험으로서 의도한 결과다.
       - AT-AS-09는 새 두 행만 실패한다. 재현 시험으로서 의도한 결과다.
       - bubble·island는 2 passed. 보존 시험으로서 통과해야 하는 결과다.
     - 후보:
       - preview 0, history 47 passed, app.exit 0, build 0, private 0.
       - JUnit 590 → 594(추가 노드만), 새 실패 0.
   - 원격 `a90dc1d` 그대로이고, `merge-base --is-ancestor github/main 878ce94`가 0이다. fast-forward로 올라간다.
5. **지적:** 차단 0.
   - 비차단 관찰: 실행 중 앱 목록(`NSWorkspace.runningApplications`)을 백그라운드 큐에서 읽는다. 문서상 읽기는 허용된다. 실물 M-01에서 함께 본다.
6. **미검증 범위:** 실제 설치 Mac에서의 동작(M-01, 증거 수준 4)은 릴리스 뒤에 확인한다.
7. **남은 조건:** 푸시 2(사용자 승인) → TASK-05 감사 → TASK-06 → 푸시 3 → TASK-04 릴리스 → M-01 → TASK-07.

- **원격 반영(2026-11-26):** 사용자가 푸시했다. `git ls-remote github refs/heads/main` = `878ce94fe228d274e6a33248e4e7d4a4d8e804d6`, `merge-base --is-ancestor 878ce94 github/main` 종료 0. 푸시 2 완료.

## 검증 판정 5회 (2026-11-26): TASK-05 코드 정리 감사

1. **판정: 완료(TASK-05).**
   - 감사 문서: `cleanup-audit.md`(개발 main `ce27bdc`).
   - 공개 worktree 변경 0(`git status --porcelain` 빈 출력을 직접 확인).
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 기준 `878ce94`.
3. **설계 적합성(4.2):** 적합.
   - 범위는 R1-01대로 추적 파일 기준이다. 954 − 593 = 361이며, 제외 경로와 이유가 적혀 있다.
   - 후보마다 공항 칸 이름, 근거, 영향, 권고가 있다.
   - 칸을 넘는 통합(CU-09: 탑승교와 허브의 같은 `read`)은 칸 독립을 이유로 "유지"로 판단했다. 공항 설계 원칙 1(칸마다 원본)과 맞는다.
4. **직접 확인한 것**(증거 수준 1)
   - `git grep -n -w`로 다시 셌다: `worstContrast`·`togglePin`·`deleteSectionPicture`·`smoothClearBodies`·`smoothHighlight`·`fromOutput`·`hookMetadata` 모두 1건(정의만). 보고와 같다.
   - CU-06: `gate/connection_manager.py`의 `asyncio`·`re`가 import 줄 외 사용 0이다.
   - CU-07: `context.thinking`(`fullmatch`)과 `history_queries.thinking`(`search ^…$`)은 첫 줄만 보므로(개행 분리) 같은 판정이다. 보고의 2,304 입력 차이 0과 맞는다.
   - 사용처: `discord.py:15`는 context, `server.py:316`은 history_queries에서 가져온다.
5. **승인 목록(계획 담당 추천 = 사용자 위임 결정)**
   - **삭제 승인:** CU-01, 02, 03, 04, 05, 06.
   - **통합 승인:**
     - CU-07: 원본은 `gate/context.thinking`이다. `history_queries`는 `from .context import thinking`으로 같은 이름을 다시 내보내고, `server.py` 호출은 그대로 둔다.
     - CU-08: `app/Tests` 공용 보조 한 곳으로 합친다.
   - **유지:** CU-09(칸 독립), CU-11(레거시 비교 빌드 소비자 있음), CU-12(번역 키 사용 중), CU-13(제거 회귀 검사).
   - **CU-10 `hookMetadata`(조사 과제):** 유지한다. 공개 통신 규격(안내판 칸)은 외부 독자가 있을 수 있는 계약이다. 지우면 AT-SM-02 해시와 공개 계약이 바뀌고, 얻는 것은 정의 하나뿐이다. 기술 부채 TD-TIDY-01로 기록한다.
6. **지적:** 없음.
7. **남은 조건:** TASK-06(승인 목록 적용) → AT-TIDY-16 비교 → 푸시 3 → TASK-04 릴리스 → M-01 → TASK-07.

## 검증 판정 6회 (2026-11-26): TASK-06 승인 정리 적용

1. **판정: 완료(TASK-06, 증거 수준 2).**
   - 푸시 후보: `4443ff2ef8558420496996d5cd0a49513f2a1996`(`878ce94` → `0718776` 앱 제품 → `3f99c66` 앱 시험 → `4443ff2` 탑승교).
   - 13파일, +17 −54.
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 작업 트리는 깨끗하다. 구현 보고: 개발 main `6e2b92b`.
3. **설계 적합성(4.2):** 적합.
   - 승인 목록 CU-01~08만 적용됐다. 바뀐 파일이 handoff-task06의 갈래 A·B·C 파일 목록과 같다.
   - 공항 칸을 넘는 이동은 없다. `thinking`의 원본은 탑승교 칸 안 `gate/context.py` 하나다. `context.py`는 `re`만 import하므로 순환 import가 없다.
4. **직접 확인한 것**
   - `git diff 878ce94 HEAD` 내용:
     - 지운 함수 5개(`worstContrast`, `togglePin`, `deleteSectionPicture`, `smoothClearBodies`·`smoothHighlight`, `fromOutput`).
     - 미사용 import 정리: connection_manager `asyncio`·`re`, connections `os`·`quote`, connection_runtime `timezone`, server `os`, adapter `thinking`.
     - `history_queries`는 `from .context import thinking`을 쓴다(`server.py:316`의 가져오기는 그대로 동작).
     - 앱 시험 캡처는 `TestMain.swift` 공용 보조로 합쳤다.
   - `git diff --exit-code 878ce94 HEAD -- schemas/` 종료 0(AT-SM-02 불변).
   - `task06/comparison.txt`: 기준·후보 모두 593 통과·1 실패(기존 `test_at_hf_08[True]`). added·removed·changed 0.
   - 보고: app build/test 0(PERF 조건 빌드 포함), PNG 4개 이름·순서 같음, history 47 통과, gateway_delivery 0, scan_private 0.
   - 원격 `878ce94` 그대로이고 `merge-base --is-ancestor github/main 4443ff2` 0이다. fast-forward로 올라간다.
5. **지적:** 없음.
6. **남은 조건:** 푸시 3(사용자 승인) → TASK-04 릴리스(HEJO-RELEASE 절차, 맨 마지막) → 게시(사용자) → M-01 → TASK-07 현재 명세 반영.

- **원격 반영(2026-11-26):** 사용자가 푸시했다. `git ls-remote github refs/heads/main` = `4443ff2ef8558420496996d5cd0a49513f2a1996`, `merge-base --is-ancestor 4443ff2 github/main` 종료 0. 푸시 3 완료.

## 검증 판정 7회 (2026-11-26): TASK-04 릴리스 준비 hejo 0.2.9

1. **판정: 완료(TASK-04 준비 단계, REQ-TIDY-06 AC-01·02).** 게시(AC-03)와 실물 M-01은 남았다.
   - 버전 커밋 R = `2dea766cbdbd5e179a6269aabbfefc750036b219`(부모 `4443ff2`). `refs/heads/public` = R.
2. **검증 조건:** 교차 모델(구현 codex, 검증 Claude). 작업 트리는 깨끗하다. 구현 보고: 개발 main `f5ec633`.
3. **설계 적합성(4.2):** 적합. HEJO-RELEASE 절차(D-08)와 같고, 정비 격납고 칸 안의 로컬 준비만 했다. 원격 쓰기는 0이다.
4. **직접 확인한 것**(증거 수준 1·3)
   - `git diff R^ R`: Info.plist `0.2.9`/`11`과 `test_ship.py` 단언, 두 파일 3줄뿐이다.
   - `prepared.json`:
     - commit = R, tree = `47665919…`(= `R^{tree}`), version 0.2.9, build 11, archive `hejo-0.2.9-arm64.zip`, size 6,839,174.
     - sha256 `69ab96c7…0186`이 `shasum -a 256` 결과와 같다.
   - 출력 폴더에는 zip과 `prepared.json` 둘뿐이다.
   - `build-info.json`: tree = R 트리, dirty false.
   - `codesign --verify --deep --strict app/.build/hejo.app` 종료 0(검증 담당 실행).
   - 보고: 시험 결과가 `4443ff2`와 노드·결과 같다(594 중 기존 1 실패). app test, scan_private, test_ship 각 0.
   - 원격은 `4443ff2`이고 R은 그 fast-forward다.
5. **지적:** 없음.
6. **남은 조건과 순서**(`install/hejo-ship publish`는 원격 main = R을 요구한다. `publish` 함수가 `ls-remote`로 확인)
   1. 푸시 4: R을 `github/main`에 올린다(사용자 승인).
   2. 사장 게시: 공개 worktree에서 `install/hejo-ship publish --prepared .build/ship-0.2.9/prepared.json --approve-commit 2dea766cbdbd5e179a6269aabbfefc750036b219`.
   3. AT-TIDY-14b(계획 담당, 읽기): `gh release view v0.2.9`.
   4. M-01(서버 Mac·맥북).
   5. TASK-07 현재 명세 반영.

## 검증 판정 8회 (2026-11-26): 푸시 4·게시·AT-TIDY-14b

- **푸시 4:** `git ls-remote github refs/heads/main` = `2dea766cbdbd5e179a6269aabbfefc750036b219`, 조상 검사 0.
- **게시:** 사장이 `hejo-ship publish`를 실행했고 출력은 `PUBLISHED v0.2.9`였다. 태그 `v0.2.9` = `2dea766`. GitHub 최신 릴리스 = v0.2.9.
- **AT-TIDY-14b 통과**(읽기 명령 `gh release view v0.2.9`):
  - isDraft false.
  - 자산 `hejo-0.2.9-arm64.zip`: 6,839,174바이트, `sha256:69ab96c7…0186`. `prepared.json`과 같다.
  - 자산 `appcast.xml`: 968바이트.
  - 증거: 공개 worktree `.build/tidy/m01/at-tidy-14b.json`.
- **M-01 설치 전 기록(이 서버 Mac, `.build/tidy/m01/server-before.txt`)**
  - `/Applications/hejo.app`: 빌드 10, 실행 중(PID 76798, `/Applications/hejo.app/Contents/MacOS/hejo`).
  - `/Applications/hejo-typing-previous.app`: 빌드 9.
  - `/Applications/hejo-connection-stuck-…-previous.app`: 빌드 9.
  - 분류 예정(N = 11, Sparkle 갱신): 갱신 경로 = `/Applications/hejo.app`, 적격 = 빌드 9 사본 2개(실행 중 아님), 보존 = 다른 번들 ID 전부.
- **남은 조건:** 사용자의 앱 갱신(서버 Mac·맥북) → M-01 판정 → TASK-07.
