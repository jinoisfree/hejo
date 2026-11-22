# HEJO-DRAWER-INLINE 판정

## 1회 · 2026-11-22 · 판정: 미완료(선행 대기, 구현 착수 전 보류)

- 대상: TASK-01. 구현 담당 보고 "보류(2절 보고)". impl-report.md 없음(착수 조건 미충족 때 파일을 만들지 말라는 handoff 0항 지시대로).
- 검증 조건: 교차 모델(계획·검증 담당과 구현 담당 모델이 다름). 구현 산출물이 없어 코드 검증은 해당 없음.

### 직접 확인 [확인]
- `git rev-parse main` = `0644e9e54d66b35bfaa596c7ffc295a1ce83f239`. 구현 worktree(`role-workflow/17-96051e66`) HEAD도 같고 `git status --porcelain` 빈 출력 → 변경·커밋 없음. 플러그인 수집 증거(변경 없음)와 일치.
- `git log main -- app/Sources/TodoDrawerView.swift` 최신 `2fffbe0`, HEJO-DEADLINE-CLOSE 앱 커밋 없음. 그 작업 tasks.md TASK-03 상태 "대기".
- 따라서 handoff 0항 착수 조건(HEJO-DEADLINE-CLOSE TASK-03 main 반영)은 충족되지 않았고, 구현 담당의 보류는 지시와 맞다.

### 설계 적합성(4.2)
계획 2판(계획 검증 2회차 APPROVED)은 바뀐 것이 없다. 구현이 없어 설계와 구현의 대조는 해당 없음. 설계 결함 아님.

### 원인 분류(10-planning 7절)
환경·외부 작업 차이: 사장이 정한 선행 작업(HEJO-DEADLINE-CLOSE 앱 TASK-03)이 아직 구현되지 않았다. 구현 오류·설계 오류 아님.

### 다음
같은 지시를 다시 보내면 같은 보류가 반복되므로 재인계하지 않는다. 사장 결정 대기:
- (가) 마감 닫기 앱 작업이 main에 들어올 때까지 이 작업을 멈춰 둔다(지금 결정 유지).
- (나) 순서를 바꿔 이 작업을 먼저 한다(그러면 HEJO-DEADLINE-CLOSE TASK-03이 바뀐 칸 배치 위에서 이어 가야 하고, 그 작업 문서의 기준 커밋을 갱신해야 한다).

## 2회 · 2026-11-23 · 판정: 미완료(구현 담당 보류) — 원인: 수락 시험 오류(계획 담당)

- 대상: 구현 worktree `role-workflow/17-96051e66`, HEAD `9a10cff` + 미커밋 12개 파일(증거 `.build/drawer-inline-evidence/candidate.patch`). 구현 담당 판단 "보류(2절 보고)". 검증 조건: 교차 모델.

### 직접 확인 [확인]
- `git status`: 보고된 12개 파일만 변경(app/Sources 7, app/Tests 5), 커밋 없음. 플러그인 수집 증거와 일치.
- 전체 앱 시험 로그 `app-tests-final.log` 마지막: `APP_TEST_FAILED assertion("AT-TD-41 owner input reaches real controller and native view")`.
- 실패 단언(`TodoDrawerTests.swift:57`, 빈 알약 `:116`)은 `panel.frame.minX == closed.minX-290`로 옛 왼쪽 늘림 좌표를 고정한다. REQ-DI-02 AC-01(왼쪽 끝 불변)과 동시에 만족할 수 없다. 구현 담당이 기대값을 고치지 않고 멈춘 것은 지시(기대값 변경 금지)와 맞다.
- 2판 AT-DI-32가 AT-TD-41을 "수정 없이 통과"로 묶은 것이 계획 담당의 수락 시험 오류다(AT-TD-41 수락 명세 문장은 "늘림 목표로 바뀐다"였지만 코드 단언이 옛 좌표를 담고 있음을 확인하지 않았다).
- main은 `338c35a`로 앞섰다. `9a10cff..main`의 app 변경은 `app/Resources/Info.plist`(버전)뿐.

### 설계 적합성(4.2) — 중간 판단
diff를 읽었다. `PetPlacement.withDrawer`(오른쪽 넓힘, `over`·`shift` 왼쪽 옮김, `safe.width`로 자름, `drawerShift = -shift`), `contentBubble` = 열린 상자 − 오른쪽 칸(크기 조절 계약 유지), `stepPlacement`의 `drawerSlideStart + (target.drawer - drawerSlideStart) * easedWidthProgress`(완화값은 `PetBubbleMotion.easedWidthProgress` 한 곳), `paneSplit` `available`에서 칸 몫 빼기, `PetView`의 칸·덮개 제거, `ConversationView.drawerShownWidth` 전달이 design 2판 2.1·2.2·2.4와 맞는다. 최종 판단은 전체 시험 통과 뒤 다시 한다.

### 원인 분류와 조치(10-planning 7절)
- 수락 시험 오류: `tests/acceptance/HEJO-DRAWER-INLINE.md` 3판으로 고쳤다 — AT-TD-41의 창 프레임 단언 두 곳을 교체 대상에 넣고, 대신할 AT-DI-33(같은 조립, 열린 뒤 `minX` 불변·폭 +290·펫 불변, 오른쪽 여유 전제도 단언)을 추가했다. 독립 근거: 고정 조립(1440×900, 펫 (650,700))에서 오른쪽 여유가 있어 REQ-DI-02 AC-01이 그대로 적용된다.
- 기준 갱신: 최신 main 병합 후 전체 시험 재실행.

## 3회 · 2026-11-23 · 판정: 미완료(구현 담당 보류) — 원인: 수락 시험 오류(계획 담당)

- 대상: worktree HEAD `95680e9` + 미커밋 12개 파일(보완 1 추가 변경은 `TodoDrawerTests.swift` 하나). 검증 조건: 교차 모델.
- [확인] 보완 1의 AT-TD-41 단언 교체는 3판 정정과 일치(두 단언만, 전제 단언 포함). AT-DI-33·AT-TD-20~42·AT-DC-21~34·새 AT-DI 통과 뒤 `IslandTests.swift:133-134` AT53에서 종료 1(로그 `supplement-1-app-tests.log`).
- [확인] AT53은 AT-TD-27(`:114`)에서 칸을 연 뒤 닫지 않고 `ui.frame.size.width=428`로 채팅 최소 폭을 겨냥한다. 새 배치에서는 칸 290이 보기 안에 들어가 채팅 몫이 70이 되므로 제목 폭 ≥120을 만족할 수 없다. 제품 결함이 아니라 옛 배치를 전제한 시험 입력이다.
- 원인: 수락 시험 오류(2판 AT-DI-32가 "기존 시험 기대값 수정 없이"만 적고 보기 폭 입력의 의미 변화를 다루지 않음). 조치: 수락 시험 5판 정정 — 칸 열림 상태에서 보기 폭을 직접 정하는 시험은 입력에 290을 더하고 기대는 유지(AT53 428→718, 760→1050). 같은 꼴은 같은 규칙, 다른 꼴은 멈춤.
- 설계 적합성: 2회 중간 판단 유지(적합). 로고·버전 가운데(REQ-DI-07)는 아직 미착수(지시가 충돌로 적용되지 않음).
- main은 `c9a653a` 이상으로 앞섰다(01e5e47 문서 포함). 다음 보완에서 최신 main 병합.

## 4회 · 2026-11-23 · 판정: 미완료(구현 담당 보류) — 원인: 수락 시험 오류(계획 담당)

- 대상: worktree HEAD `19e0495` + 미커밋 13개 파일(보완 2 추가: `ConversationView.swift`, `DrawerInlineTests.swift`, `IslandTests.swift`). 검증 조건: 교차 모델.
- [확인] AT53 입력 이관은 5판 정정대로 두 값(428→718, 760→1050)만. 로고는 attributed string에 가운데 문단 스타일을 넣고 정렬 값 하나를 로고·버전이 공유(design 2.5 적합). 어두운 테마 68·212에서 중심 34·106pt(보고·사진).
- [확인] AT-DI-34의 폭 140은 `ConversationSidebar.snapped`(`ConversationChrome.swift:10-14`: 34 미만 0, 124 미만 68, 그 위는 180~300)가 180으로 맞추는 허용 밖 값이다. 제품 계약이 옳고 시험 입력이 틀렸다. 구현 담당이 시험용 우회 없이 멈춘 것은 맞다.
- 조치: 수락 시험 6판 — AT-DI-34 폭을 68·212·240으로, spec REQ-DI-07 AC-01에 허용 범위(180~300) 명시.
- 전체 시험은 아직 미실행(종료 0 미확인). main은 `0ded4b8`로 앞섰고 HEJO-TELEGRAM이 `ConversationView.swift`·`TestMain.swift`를 바꿨다 → 병합 시 충돌 가능.
- 설계 적합성: 적합(중간). 최종 판정은 전체 시험 종료 0과 밝은 테마 AT-DI-34 확인 뒤.

## 5회 · 2026-11-23 · 판정: 미완료(구현 담당 보류) — 원인: 미확정(시험 조립 또는 구현), 원인 확인을 구현에 지시

- 대상: worktree HEAD `bb14bd3` + 미커밋 13개 파일(보완 3 추가: `DrawerInlineTests.swift` 입력 140→240). 보존 stash `HEJO-DRAWER-INLINE-supplement-3-preserved`도 남아 있음(작업 트리에 이미 적용됨). 검증 조건: 교차 모델.
- [확인] 병합 충돌 없음, HEJO-TELEGRAM 변경 유지. 전체 시험 종료 1: 어두운 테마 AT-DI-34(68·212·240 중심 34·106·120pt) 통과 뒤 밝은 테마 `AT-DI-34 missing rendered ink 26..<38`(버전 줄).
- [확인] 시험은 `window.appearance`/`view.appearance`만 바꾼다(`DrawerInlineTests.swift` AT-DI-34 반복). 버전 글자 색은 `refresh()`에서 `CardText.quiet(dark:)`로 정해지고(`ConversationView.swift` refresh), 실제 테마 변경은 `ChatAppearance.change` → `applyChatAppearance` 경로다. 시험 전환이 실제 경로를 거치지 않아 버전 색·숨김이 갱신되지 않았을 가능성이 크지만 [미확정].
- 원인 분류: 미확정. 수락 시험에 전환 방법이 없던 것은 계획 쪽 누락이라 7판 보충으로 정했다(실제 앱 경로로 전환, 기대 불변, 그래도 안 보이면 제품 결함).
- main `1150a27`(bb14bd3 이후 app 변경 없음).

## 6회 · 2026-11-23 · 판정: 완료 (조건: 교차 모델) — 남은 사람 확인 M-DI-1·2

- 대상: 구현 커밋 `94b06efe92743f0439bb6190d2ddd8ab088a8ddd`(브랜치 `role-workflow/17-96051e66`, 기준 `ce0e3d4`). worktree 깨끗함, 커밋은 지정 13경로만(`git show --stat`).
- main 통합: 계획 담당이 `94b06ef`를 로컬 main에 `--no-ff` 병합 → `18de43eb2d552e985b327dbcd6ecbfe7de7f7783`. 병합 뒤 `app/` 트리가 시험한 `94b06ef`와 같다(`git diff --stat 94b06ef 18de43e -- app/` 빈 출력, `ce0e3d4..main`의 추가 변경은 문서·gate 시험 문서뿐).

### 시험 증거 [확인]
- `supplement-4-final-app-tests.log`(구현 worktree `.build/drawer-inline-evidence/`): `AT-DI-33 … PASS`, `AT-DI-01..14,31 INLINE PLACEMENT PASS`, `AT-DI-20..23 PIXEL PASS`, `AT-DI-34 LOGO AND VERSION PIXEL CENTERS PASS`, 묶음별 `APP_TEST_OK` 전부, 마지막 `OK`. 구현 보고 종료 0.
- 시험 코드 대조(`DrawerInlineTests.swift`): AT-DI-08 다섯 경우 (1634,600,720)…(1002,428,260), AT-DI-10 528/290/170, AT-DI-11 508·346·798·1144, AT-DI-14 0/145/290·428/478/528·360/265/170과 단계 ≤30·한 방향·겹침 없음·도중 재클릭 145→0, AT-DI-12 카드 폭 262 — 수락 시험 기대값과 같다. AT-DI-34 RGBA 비교는 알파 차이를 더 잡는 쪽이라 약화가 아니다.
- AT-DI-30 검색 0건, `git diff --check` 0, scan_private 새 지적 0(기존 HEJO-DEADLINE-CLOSE 문서 4건은 기준 대조). 이 작업 문서에 절대 경로 0건(직접 grep).
- 화면 증거 직접 열람: `inline-right-edge-dark.png`(방 목록 | 처리할 일 | 채팅, 칸이 유리 위 옅은 톤, 선택 카드 옅은 강조 채움, 급함은 배지 글자만 빨강), `logo-sidebar-68-dark.png`(로고·버전 0.2.5가 68 열 가운데).

### 설계 적합성(4.2) — 적합
칸 폭 판정 `PetPlacement.withDrawer` 한 곳, 칸 열 배치 `ConversationView.layout`·바탕 `ConversationView.draw`(공용 `SidebarTone`), 칸 폭 보간은 `PetBubbleMotion.easedWidthProgress` 공유(역산식 제거), 크기 조절은 `contentBubble` 재정의로 기존 `resized` 계약 보존, `paneSplit`은 `available`에서 칸 몫만 뺌, `PetView`의 칸·덮개·불투명 배경 제거, 로고·버전 정렬 값 하나 공유. 옛 경로 이중 존재 없음(AT-DI-30). design 2·4절과 일치.

### 수락 시험 정정 이력(계획 담당 원인)
3판 AT-TD-41 창 프레임 단언 교체(AT-DI-33), 5판 열린 칸 상태 보기 폭 입력 +290(AT53), 6판 AT-DI-34 폭 140→240, 7판 실제 테마 전환 경로. 모두 기대값이 아니라 옛 배치 전제·허용 밖 입력·전환 방법을 바로잡은 것이다.

### 남은 것
- M-DI-1·2 사장 확인(개발 빌드에서 배치·색·오른쪽 끝 비킴). tasks.md "사람 확인" 행.
- 공개: 사장 결정(다음 공개 판). github 원격 `main`은 공개 판 이력(`hejo 0.2.6` 등)이라 이 커밋을 그대로 푸시하는 대상이 아니다.
- 현재 명세 반영 완료: HEJO-TODO-DRAWER spec REQ-TD-02·AC-04, HEJO-FINDER-FOLDERS spec REQ-FF-08·13, 수락 시험 AT-TD-30·31·33·34·35·41, AT-FF-40·41·90~93에 대체 표시, 이 작업 spec·design 상태 "적용".
