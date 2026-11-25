# 설계 인계: HEJO-SMOOTH2-20261125 / 개발 main 통합과 남은 지연 계측

0. 기준: 개발 `main` `431d0dd`(착수 시 다시 확인), 개발 브랜치 `hejo-smooth-20261124` `fc756976ff5e52ed7498fcfd8231a37f05fdc59f` / spec v1 / 2026-11-25 / 사용자 요청으로 착수 / 연합개발.
1. 문서: [spec](spec.md), [tasks](tasks.md), 앞선 작업 [HEJO-SMOOTH verdict](../HEJO-SMOOTH-20261124/verdict.md)와 [구현 보고](../HEJO-SMOOTH-20261124/impl-report.md).
2. 요구: spec의 AC-01~06.
3. 유지: 제품 동작 일체, `main`의 최신 문서, 다른 작업의 미커밋·스테이징 변경, 디스코드 작업 공간.
4. 흐름: 개발 작업 공간에서 통합 커밋을 만들고 검증 → 계획 담당 체크아웃 `main`을 그 커밋으로 빨리감기 → 통합 커밋에서 계측.
5. 경로 판정: 문서 되돌림은 `main` 쪽을 권위로 삼는다. 제품은 개발 브랜치 쪽.
6. 위험도 일반(복구 가능한 이력 통합, 제품 동작 무변경). 증거 1·2·3. 복구: 빨리감기 전 `main` 해시로 되돌릴 수 있게 기록하되, 되돌리기는 사용자 승인 뒤에만.
7. 성격: 이력 통합(동작 보존)과 계측.
8. 시험: spec 표의 검사 열. 기대값 근거는 `main`과 `fc75697…`의 실제 내용.
9. 범위·금지: 아래 절차. 공개 저장소·푸시·설치·서버·디스코드 파일 금지. 다른 작업 변경을 stash·커밋·삭제하지 않는다. rebase·force 금지. 병렬 갈래: 없음(선행 관계).
10. 미확정: 지연 개선 방법(TASK-S2-04)은 착수 차단.
11. 사용자 확인: 2026-11-25 "따로 남은 것 진행하자", 네 항목 모두 선택.

## 절차
### TASK-S2-01 (개발 작업 공간 `../.worktrees/hejo-smooth-20261124`)
1. 작업 트리가 깨끗하고 HEAD가 `fc75697…`인지 확인한다.
2. `git merge --no-ff main`으로 현재 개발 `main`을 합친다. 충돌이 나면 `app/`은 개발 브랜치 쪽, 그 밖은 `main` 쪽을 기본으로 하고, 의도 판단이 필요하면 멈춘다.
3. 문서 되돌림 바로잡기: `README.md`, `docs/ARCHITECTURE.md`, `docs/changes/HEJO-TELEGRAM-20261122/`, `docs/changes/HEJO-SIDEBAR-SELECTION-20261123/`, `docs/changes/HEJO-UI-CLEAN-20261123/verdict.md`를 `main`의 내용으로 되돌린다(`git checkout main -- <경로>`). 그 밖에 `app/` 밖에서 개발 브랜치가 바꾼 경로 중 위 목록이나 아래 4번 목록에 없는 것이 있으면 목록으로 보고하고 `main` 쪽으로 둔다.
4. 계획 담당 체크아웃의 최신 내용으로 다음을 넣는다(파일 복사): `docs/changes/HEJO-SMOOTH-20261124/` 전체, `docs/changes/HEJO-SMOOTH2-20261125/` 전체, `tests/acceptance/HEJO-SMOOTH.md`, `docs/spec/current/hejo-performance.md`, `docs/changes/60f149af-b64e-4d3a-9e8e-a1c7d4ea1045/` 전체, `docs/changes/26405dfc-f5c9-4243-ab07-fa756b3c00bb/` 전체, `docs/changes/HEJO-TYPING-20261123/` 전체, `tests/acceptance/HEJO-PERF.md`, `tests/acceptance/HEJO-TYPING.md`. 계획 담당 체크아웃에 없는 파일은 지우지 않는다. 증거 폴더(`logs/` 등 큰 원시 자료)는 이미 추적 중인 것만 둔다.
5. 개인값 검사, 상대 링크 검사, 전체 시험(시험 환경은 HEJO-SMOOTH handoff v4)을 돌린다. 실패 집합을 `fc75697…`의 기록과 비교한다.
6. 통합 커밋을 만든다. AC-01·02·03의 검사 결과를 남긴다.

### TASK-S2-02 (계획 담당 체크아웃 — 쓰기는 이 단계만)
1. 시작 전 `main` 해시, 다른 작업 미커밋·스테이징 파일의 목록과 해시(`git diff`, `git diff --cached`, 해당 파일 SHA-256)를 기록한다.
2. `main`과 통합 커밋 사이에서 바뀌는 경로 중 미추적 파일과 겹치는 것을 모두 찾는다. 각 파일이 통합 커밋의 내용과 바이트 단위로 같으면 계획 담당 체크아웃의 무시되는 증거 폴더(`.build/smooth2-untracked-backup/`)로 경로를 유지한 채 옮긴다. 하나라도 다르면 아무것도 옮기지 않고 멈춰 보고한다. 추적 파일의 미커밋 변경과 겹치면 멈춘다.
3. `git merge --ff-only <통합 커밋>`. 실패하면 옮긴 파일을 원래 자리로 되돌리고 보고한다.
4. 다른 작업 미커밋·스테이징 변경이 1번 기록과 같은지 확인한다.
5. 디스코드 작업 공간·브랜치는 건드리지 않는다.

### TASK-S2-03 (개발 작업 공간, 통합 커밋)
HEJO-SMOOTH의 현실 workload와 하네스로 처음 보는 방 전환, 방 재방문, 알림 창 전환을 각각 5회 이상 잰다. 각 동작의 주 스레드 시간을 겹치지 않는 구간(모델 파생값, 카드 내용 조립, 본문 꾸미기, 높이 재기, 표 갱신·배치, 그리기, 설정 저장, 전환 단계·창 표시·애니메이션 층 갱신 등)으로 나누고, 구간 합과 전체의 차이도 기록한다. 스택 표본은 공식 표본과 분리한다. 항목별로 가장 큰 구간, 그 함수, 줄일 방법의 후보 2~3개와 각 후보가 바꾸는 동작(표시 시점, 저장 시점, 애니메이션 모양 등)을 보고한다. 제품 코드는 바꾸지 않는다(시험 전용 관측 지점 추가만, `HEJO_PERF_TESTING` 안).

결과는 `docs/changes/HEJO-SMOOTH2-20261125/impl-report.md`(계획 담당 체크아웃의 원본에 작성 후 다음 통합 때 반영)에 명령·종료 코드·로그 경로·원시 계측·전후 해시로 남긴다. 푸시는 없다.

## 보완 인계 v2 — TASK-S2-04a·04b (2026-11-25)
0. 기준: 개발 `main` = 개발 브랜치 `hejo-smooth-20261124` = `e54e1c70c3237c9d8662b019d8f959f56b8f19d8` / spec v2 / 사용자 승인 "너의 추천대로 진행해" / 연합개발.
1. 문서: [spec](spec.md) v2 절, [tasks](tasks.md) v2, [verdict](verdict.md) 1회, [구현 보고](impl-report.md) 계측 절, 계측 원시 자료(개발 작업 공간 `app/.build/smooth2/`). 재사용 계약은 [현재 명세](../../spec/current/hejo-performance.md)의 'HEJO-SMOOTH 파생값 재사용 계약'.
2. 요구: AC-07~10.
3. 유지: 화면 모양·글자 나타나는 느낌·스크롤 규칙·애니메이션 모양과 길이·저장 시점·서버. 표시 시점을 미루거나 당기지 않는다.
4. 흐름: 방 선택 → `ConversationView.refresh` → 카드별 `postPieces` → 카드 높이 → 표 배치. 바꾸는 곳은 `postPieces`와 그것이 부르는 순수 값.
5-1. 계획 검토 반영([plan-review](plan-review.md)):
   - `controller.avatar`의 `pictures.image`(Pictures.swift)는 순수 값이 아니다(받아오기 시작, 로그인·주소·계정·연결 회차 변화 시 기억 비우기). 이 호출은 지금처럼 매번 부른다. 재사용은 `person(matching:)`·`PictureCodec.color` 같은 순수 부분에만 한다.
   - `controller.palette`는 직원 전체를 정렬하고 색 배정(`CharacterPalette.hues`)을 다시 한다. 키는 직원 명부 전체(id·이름·색) + 대상 + 다크 여부. 명부 revision 값이 지금 없으므로, 명부 배열 자체를 비교하거나 명부가 바뀌는 곳에서 올리는 revision을 새로 둔다(어느 쪽인지와 근거를 보고).
   - `model.name`은 직원 이름 외에 홈 방의 펫 이름(`settings.petName`)과 그룹 제목에도 따른다. 이것들을 키에 넣는다.
   - 시각 표시를 더 싸게 하려고 날짜 변환기를 공유하면 지역·시간대 변경 때 다시 만든다.
   - 글마다 한 번 꼭 필요한 계산(`calendarActions`, `needsFolding`, `isConversational`, `fittedRules`, `strip`)은 재사용으로 줄지 않는다. 같은 결과를 더 싸게 계산하는 방법만 쓸 수 있고, 없으면 보고만 한다. 이 몫이 크면 0.2초 재질문이 예상된 결과임을 보고에 적는다.
   - `fittedRules`·`strip`은 지금 본문 꾸미기 구간 밖(`postPieces` 자기 구간)에 있다. 하위 구간 이름을 실제 함수 경계에 맞춘다.
5. 재사용 규칙: 키는 결과를 바꾸는 입력 전부(말하는 사람, 다크 여부, 외형 revision, 프로필·명부 변경 revision, 글 내용 등)다. 명부·프로필·외형이 바뀌면 무효화한다. 상한은 FIFO(HEJO-SMOOTH와 같은 방식)이며 상한값과 근거를 보고한다. 클로저·뷰 생성 자체를 캐시하지 않는다(`accessory`의 `view:` 클로저는 그대로). 결과가 같음을 보장할 수 없는 값은 재사용하지 않고 보고만 한다.
6. 위험도 일반(제품 코드 변경, 표시 동일 보장). 증거 1·2·3. 복구: 커밋 단위 되돌림.
7. 성격: 동작 보존 성능 개선 + 계측.
8. 시험: AC 표. 기대값 근거는 통합 커밋의 실제 출력(의미 동결 58단계, 전체 카드 대조). AC-08 판정 기준은 같은 세션 교대 계측(통합 커밋 빌드와 수정 커밋 빌드 각 5회, 하위 구간 관측은 양쪽 모두 빼고 기존 HEJO-SMOOTH 관측만)이다. 342.9ms는 참고값이다. 변형 시험은 키 입력마다 그 입력을 바꾸는 장면(명부 색 변경, 그림 도착, 지역·시간대 변경, 펫 이름·그룹 제목 변경, 다크 전환)을 새로 만들고, 바꾼 뒤 표시가 통합 커밋과 같음과 입력을 키에서 빼면 대조가 실패함을 함께 보인다.
9. 금지: 미리 계산·나중 계산·보이는 부분만 계산·구조 변경, 방 재방문 전용 수정, 애니메이션 변경, 공개 저장소·설치 앱·서버·운영 설정·디스코드 작업 공간, 다른 작업 변경의 stash·커밋·삭제, rebase·force, 푸시. 계획 담당 체크아웃의 `main`을 움직이지 않는다(통합은 검토 뒤 계획 담당이 지시).
10. 미확정: 04a 뒤에도 처음 보는 방의 경과 시간 중앙값이 0.2초를 넘으면 미리 계산 여부를 사용자에게 다시 묻는다(구현하지 않음). 04b의 수정 방법은 결과 뒤 결정.
11. 병렬 갈래: 없음(tasks v2).

### TASK-S2-04a (개발 작업 공간 `../.worktrees/hejo-smooth-20261124`, 브랜치 `hejo-smooth-20261124`)
1. HEAD가 `e54e1c7…`이고 작업 트리가 깨끗한지 확인한다.
2. 시험 빌드(`HEJO_PERF_TESTING`)에서 `postPieces` 자기 구간을 하위 구간으로 나눈다. 후보: `thinking` 판정, `streamReveal.frame`, `LongReply.needsFolding`·`preview`, `controller.palette`, `PostBodyInput` 생성·비교와 `checksMatch`, `controller.model.name`, `controller.avatar`, `displayTime`, `ThreadAppearance.isConversational`, `fold`·`openLink` 클로저 생성, `history.layouts` 접근, `calendarActions`, 첨부·나머지 accessory 조립, `effectiveAppearance` 판정. 남은 자기 구간 20ms 이하(AC-07). 계측 결과와 계획한 수정 목록을 먼저 커밋 메시지가 아닌 impl-report에 기록한다.
3. 5번 규칙에 맞는 값만 고친다. 제품 커밋과 시험 커밋을 나눈다.
4. AC-09: 의미 동결 58단계, 전체 카드 대조, 새 키별 변형 시험(입력 하나를 빼면 대조 실패), 전체 시험 두 명령, 독립 묶음.
5. AC-08: 통합 커밋과 수정 커밋을 같은 세션에서 번갈아 각 5회, HEJO-SMOOTH 여섯 동작·room_first·room_revisit·스크롤.

### TASK-S2-04b (같은 작업 공간, 04a 커밋 위 시험 빌드)
알림 창 전환 5회 이상. 최장 간격마다 미귀속 시간을 시험 전용 관측(런루프 모든 단계 관찰자, `CATransaction` 완료 블록과 제출 시각, 창·뷰 레이아웃/그리기 진입 시각, 타이머 예정 시각 대비 실제 발화 지연, 화면 갱신 주기 시각 등)으로 귀속한다(AC-10). 관측은 `HEJO_PERF_TESTING` 안에만 둔다. 제품 코드 무변경. 원인 후보별 고칠 방법과 바뀌는 동작을 적는다.

결과는 계획 담당 체크아웃의 `docs/changes/HEJO-SMOOTH2-20261125/impl-report.md`에 '04a·04b' 절로 덧붙인다(명령·실제 종료 코드·로그 경로·원시 계측·커밋 해시). 푸시 없음.

## 보완 인계 v3 — TASK-S2-06, S2-05a~c (2026-11-25)
0. 기준: 개발 브랜치 `hejo-smooth-20261124` HEAD `a9659d424b40184c65dd83c9794713ede2f7d616`(제품 `01d08769…`), 개발 `main` 착수 시 확인(계획 담당이 이 문서를 커밋함), 공개 원격 `github/main` `27e0e95fab5de0294ae925c188bb50f5ba361411`(착수 시 `git ls-remote`로 재확인) / spec v3 / 사용자 "1,2 모두 진행" / 연합개발.
1. 문서: [spec](spec.md) v3 절, [tasks](tasks.md) v3, [verdict](verdict.md) 2회, [구현 보고](impl-report.md) 04b 절, HEJO-SMOOTH [handoff](../HEJO-SMOOTH-20261124/handoff.md)의 공개 통합(TASK-10)·설치(TASK-11) 절.
2. 요구: AC-11~14.
3. 유지: 전환의 모양·총 길이·진행률 공식, 동작 줄이기 경로, 화면 모양, 서버.
4. 흐름: `PetController.setExpanded` → 시작 포즈 → 반복 `Timer`(1/60초, `.common`) + 첫 단계 `DispatchQueue.main.async` → `stepTransition`이 경과 시간으로 진행률 계산 → 끝나면 `timer=nil`, `endGenie`, `apply(target)`.
5. 설계:
   - 단계 구동만 바꾼다. 화면 주기 신호마다 주 스레드에서 `stepTransition`을 부른다. macOS 14 이상은 `NSView`/`NSWindow`/`NSScreen`의 `displayLink(target:selector:)`(패널 또는 그 화면 기준, `.common` 모드)를 쓰고, 배포 대상 macOS 13에서는 `CVDisplayLink` 콜백에서 주 스레드로 넘긴다(쌓이지 않게 한 번에 하나만 대기). 첫 단계 즉시 실행은 유지한다.
   - `timer`를 쓰던 "전환 진행 중" 판정(현재 `timer != nil`/`timer == nil`, `timer?.invalidate();timer=nil` 위치 전부: 93, 105, 209(deinit), 232~234, 280~293, 312, 331, 362, 366, 398, 435, 447행 부근)을 하나의 구동 객체나 상태로 바꾸고 의미를 그대로 유지한다. 새 전환이 앞선 구동을 확실히 멈추고, 끝난 전환의 콜백이 늦게 와도 무시한다(지금 `self.timer === t` 확인과 같은 보장).
   - 창이 화면을 옮기거나 화면 주기를 얻지 못하면 기존 `Timer` 경로로 대신한다(대체 경로가 쓰였는지 진단 기록).
   - `ThreeTapDiagnostics.firstTick`·`HejoSmoothProbe` 기록 위치는 의미를 유지한다.
5-1. 계획 검토 반영([plan-review](plan-review.md) v3):
   - `deinit`(209행 부근)에서도 구동을 멈춘다. `CVDisplayLink` 콜백에는 링크가 소유하는 약참조 상자를 넘기고, `displayLink(target:selector:)`는 대리 target을 둬 순환 참조를 막는다. 끝나는 모든 경로에서 무효화한다.
   - macOS 14 API는 `#available`로 감싼다. `CVDisplayLink`는 패널의 화면이 바뀌면 현재 디스플레이를 다시 지정한다. 주 스레드로 넘기는 대기 표시는 단계가 끝난 뒤 해제한다.
   - 원인 대조: 교대 계측에 세 갈래를 둔다. A 기준 `a9659d4`, B 화면 주기, C 기준 + 전환 동안만 `ProcessInfo.beginActivity(.latencyCritical·.userInitiated)`와 타이머 `tolerance=0`. 시험 빌드의 C는 비교용이다. B가 AC-12를 통과하면 B만 반영한다. B가 미달이고 C 방식을 B에 더해 통과하면 둘을 함께 반영하고 이유를 보고한다. 둘 다 미달이면 일정 버튼 개선만 반영한다.
   - 계측은 실제 화면에 붙은 패널로 하고, 표본마다 쓰인 경로(화면 주기/대체 Timer)를 기록한다. 대체 경로 표본은 B의 판정에 쓰지 않는다. 50ms 초과 간격 표본도 버리지 않고 집계한다(준비 1회 제외).
6. 위험도 일반(애니메이션 구동 변경, 복구는 커밋 되돌림). 증거 1·2·3.
7. 성격: 동작 보존(프레임 시점만 변경).
8. 시험: AC-11 단위 시험(되돌리기 중 새 전환, 끝난 구동의 늦은 콜백 무시, 대체 경로, 동작 줄이기). AC-12는 v2와 같은 교대 계측 방식(관측은 기존 단계 시각 기록만). AC-13은 v2와 같은 묶음. 기대값 근거는 `a9659d4`의 실제 출력.
9. 금지: 진행률 공식·길이·모양 변경, 다른 애니메이션(펫 이동·말풍선 등) 구동 변경, 미리 계산·나중 계산, 방 재방문 수정, 다른 작업 변경의 stash·커밋·삭제, rebase·force, 두 이력 merge, 서버·운영 설정, 디스코드 작업 공간, git push.

### TASK-S2-06 (개발 작업 공간 `../.worktrees/hejo-smooth-20261124`)
5번 설계대로 구현, 제품·시험 커밋 분리, AC-11~13 검증. AC-12 미달이면 원인과 수치를 보고하고, 화면 주기 커밋은 반영 대상에서 빼고(개발 브랜치에서 되돌림 커밋) 아래 단계를 일정 버튼 개선만으로 진행한다.

### TASK-S2-05a 개발 main 반영
1. 개발 브랜치에서 `git merge --no-ff main`(계획 담당의 SMOOTH2 문서 커밋을 받음). 충돌 시 `app/`은 개발 브랜치, 그 밖은 `main` 쪽. 전체 시험 실패 집합 확인.
2. 계획 담당 체크아웃: S2-02와 같은 보호 절차(다른 작업 변경 목록·해시 기록, 겹치는 미추적·수정 파일 검사, 다르면 멈춤) 뒤 `git merge --ff-only <통합 커밋>`. 전후 다른 작업 변경 동일 확인.

### TASK-S2-05b 공개 이식
HEJO-SMOOTH handoff의 TASK-10 방식. 공개 작업 공간 `../.worktrees/hejo-smooth-public-20261124`에서 원격 공개 tip(현재 `27e0e95`) 위 새 브랜치 `hejo-smooth2-public-20261125`를 만들고, 이번 제품·시험 커밋(`01d0876`, `a9659d4`의 시험, S2-06 커밋)을 cherry-pick 등으로 옮긴다. `docs/changes/HEJO-SMOOTH2-20261125/`(impl-report 포함)를 계획 체크아웃의 최신 내용으로 넣는다. 개인값 검사(실행 환경 Python), 전체 시험 두 명령, 의미 동결, 교대 계측 요약을 다시 돌린다. 실패 집합은 공개 기준 `27e0e95`의 기록과 같아야 한다. 결과 커밋이 `github/main`의 빨리감기인지 확인한다. 푸시하지 않는다.

### TASK-S2-05c 설치
HEJO-SMOOTH handoff의 TASK-11 절차 그대로: 공개 이식 커밋의 배포 빌드, 현재 설치 앱 새 백업, 정상 종료·교체·재실행, 대화 창 열림 확인, 복구 방법 기록.

결과는 계획 체크아웃의 `docs/changes/HEJO-SMOOTH2-20261125/impl-report.md`에 'v3' 절로 덧붙인다(명령·실제 종료 코드·로그 경로·원시 계측·커밋 해시·백업 위치). 공개 작업 공간 사본에도 같은 내용을 넣는다.

## 보완 인계 v4 — TASK-S2-07·08 (2026-11-25)
0. 기준: 개발 브랜치 `hejo-smooth-20261124` HEAD 착수 시 확인(현재 `2861fcd74cfca44d0a3b72bdfee7434b7426c076`, 개발 `main`과 같음), 공개 브랜치 `hejo-smooth2-public-20261125` `eb68ac320bf177b999c10028662cd95565517b29`(미푸시), 공개 원격 `github/main` `27e0e95…`(착수 시 `git ls-remote`로 재확인) / spec v4 / 사용자 "전환방식도 넣자" / 연합개발.
1. 문서: spec v4 절, tasks v4, [verdict](verdict.md) 3회, 보완 인계 v3(설계 5·5-1과 금지 9는 그대로 유효).
2. 요구: AC-11, AC-12(v4 조정), AC-13, AC-14.
3. 계획 담당 코드 검토(판정 3회 뒤): `b804566` 시점의 `PetTransitionClock.swift`와 `PetController.swift` diff를 읽었다. deinit 정리, 약참조 대리 target·상자, `#available` 분기, 화면 변경 재지정, 대체 Timer, 대체된 구동의 늦은 신호 무시, `timer` 사용처 전부 교체를 확인했다. 그대로 되살린다.
4. 위험도 일반. 증거 1·2·3. 복구: 커밋 되돌림, 설치는 새 백업으로 복구.

### TASK-S2-07 (개발 작업 공간)
1. `git revert --no-edit 970bffa`로 화면 주기 방식(B)을 되살린다. 결과의 `app/Sources/PetTransitionClock.swift`, `PetController.swift`가 `b804566`과 같은지 확인하고, 절전 해제(C) 코드가 없음을 확인한다.
2. AC-11 단위 시험, AC-12 실제 화면 교대 계측 1세션(A `2861fcd`, B 되돌림 커밋, 각 5회, 표본별 경로 기록), AC-13 비회귀(여섯 동작·room_first·room_revisit·스크롤, 의미 동결 58단계, 전체 카드 대조, 전체 시험 두 명령, 실패는 기존 Python 4건·AT-UC-32·설정 메타데이터 보호 밖에 없음).

### TASK-S2-08 반영·재설치
1. 개발 `main` 반영: v3의 S2-05a와 같은 방법(개발 브랜치에 `git merge --no-ff main` 후 시험, 계획 담당 체크아웃에서 보호 절차 뒤 `git merge --ff-only`).
2. 공개 이식: 공개 작업 공간의 `hejo-smooth2-public-20261125`(`eb68ac3`)에 이어서 `dba9586`, `3999dba`, `9d27892`, `b804566`(또는 같은 결과의 단일 이식)을 cherry-pick한다. `PetTransitionClock.swift`·`PetController.swift`가 개발 쪽과 같은지 확인한다. `docs/changes/HEJO-SMOOTH2-20261125/`를 계획 체크아웃 최신으로 갱신. 개인값 검사·전체 시험 두 명령·의미 동결·교대 계측 요약·AC-11 단위 시험 재실행. 결과가 `github/main`의 빨리감기인지 확인. 푸시하지 않는다.
3. 재설치: HEJO-SMOOTH handoff TASK-11 절차(배포 빌드, 지금 설치본 `4c10c82` 빌드의 새 백업, 정상 종료·교체·재실행, 대화 창 열림과 접기·펼치기 전환이 끝나는지 확인, 복구 방법 기록).

결과는 계획 체크아웃 `impl-report.md`에 'v4' 절로 덧붙이고 공개 사본에도 넣는다(명령·실제 종료 코드·로그 경로·커밋 해시·백업 위치). 금지는 v3 9번과 같다.
