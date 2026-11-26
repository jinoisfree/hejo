# [설계 인계: HEJO-JUMP-ONCE TASK-01~06 / 카드 누름 한 번 이동·미리 받기·자리 없는 갱신 표시·써지는 중 갱신 안 함]

0. **기준**: base_commit = 착수 시 공개판 tip. 설계 기준은 `github/main` `2dea766cbdbd5e179a6269aabbfefc750036b219`. spec 5판·design 4판·수락 시험 5판(검증 1·2·3회차 GAP-JO-01·02, AT-JO-08·09·18 입력 보완, 사용자 결정 D-08~11 반영, [plan-review.md](plan-review.md)·[verdict.md](verdict.md)) / 작성 2026-11-26 / 승인: 사용자 결정 D-01~03·D-08~11([tasks.md](tasks.md)), 계획 검증 대기 / 운영 모드: 교차 모델(연합개발, 계획 검증 켜기).
   - **재개(5판)**: 1·2·3차 착수의 공개 worktree `../.worktrees/hejo-jump-once-public-20261126`(base_commit `018036cbf24678ea3a29f826926531e8ab4d370b`)와 미커밋 진단 시험 두 파일을 그대로 이어 쓴다. `git fetch github` 뒤 `github/main`이 바뀌었으면 그 위로 올리고 새 base_commit을 적는다.
   - (1차 기록) 착수하면 `git fetch github` 뒤 시작점을 정한다. HEJO-BUBBLE-WIDTH 제품 커밋 `8095aa46ff0d728d5919a673c33a7438056b7e2d`가 `github/main`에 들어 있으면 `github/main` tip에서, 아니면 브랜치 `hejo-bubble-width-public-20261126` tip에서 시작한다(같은 파일 `ConversationView.swift`·`NativeThreadCard.swift`를 고친 검증 완료 변경이다). 고른 시작점의 전체 해시를 base_commit으로 impl-report에 적는다.
   - design 2절 현황(파일·줄)이 시작점에서도 맞는지 확인한다. 이동·기록 조정자 코드가 설계와 다르게 바뀌어 있으면 멈추고 보고한다.
1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), 수락 시험 `tests/acceptance/HEJO-JUMP-ONCE.md`, `docs/ARCHITECTURE.md`, 관련 기준 `docs/changes/HEJO-WAIT-JITTER-20261125/spec.md`·`docs/changes/HEJO-AUTOLOAD-20261125/spec.md`. 이 문서들은 planner checkout(개발 `main`)에 있다.
2. **요구와 수락 기준**: REQ-JO-01(한 번 이동: 되튐 0, 0.30초 안 정착, 준비 안 됐으면 글이 그려질 때까지 자동 이동 0회·그려진 뒤 정확히 1회, 리더 입력이 요청을 취소, 다른 방은 첫 화면부터 대상), REQ-JO-02(카드창에 뜬 카드의 대상 스레드를 최근 쪽까지 미리 받아 구간 안 대상은 서버 응답 없이 이동, 구간 밖 대상은 누른 뒤 받아 한 번 이동, 부작용·중복·안내 없음), REQ-JO-03(갱신 표시 ↻와 안내가 내용 위치를 0.5pt 넘게 밀지 않음), REQ-JO-04(써지는 중 조각은 집계 갱신 0건 — 그 사이 안 읽음·종·알림·질문이 실제로 바뀌어도 미룸, 끝 조각 뒤 1~2회, 결과 값은 기준본과 같음), NFR-JO-01~03.
3. **유지할 계약**: design 5절. 문과의 통신·기록장·캐시 형식, 스크롤 최종 위치 규칙과 리더 입력 우선, HEJO-WAIT-JITTER·HEJO-AUTOLOAD 수락 기준, 카드 누름의 읽음·알림 확인·강조.
4. **책임·흐름**: 이동 요청은 `ConversationView` 한 곳이 갖고 목록을 그린 직후 한 번 실행한다. 한 번 이동과 위치 유지는 `NativeThreadList`, 미리 받기 대상 처리는 `HistoryCoordinator`(기존 `AutoLoad.thread`·`.content` 재사용, 글 지정 열기 안 씀), 표시와 안내 줄은 `TodoDrawerView`·`ConversationView`, "이 프레임이 집계를 바꾸는가" 판단은 `ConversationModel`의 함수 하나를 `apply`와 `ConversationController.onHistoryFrame`이 함께 쓴다.
5. **기존 경로 판정**: design 4절. 입구의 직접 `history.scrollTo`, `onAnchor`의 이동, `pendingRevealScroll`, `scrollTo`의 세 번 시작, 카드창 경고 줄 삽입, `history-status` 카드는 같은 변경에서 지운다. 선택 변경 때 전체 갱신은 그대로 둔다. 실시간 프레임마다의 `liveChanged`·`history.refreshing = true`는 써지는 중 조각만 빼도록 교체한다.
6. **위험도·증거**: 일반. 필요한 증거 수준 2(앱 시험 하네스와 가짜 서버). 앱 설치·서버 작업 없음. 되돌리기는 커밋 되돌림.
7. **변경 성격**: 의미 변경(화면 동작). 비교: 수락 시험의 "기준본 기대" 열과 AT-JO-10·16의 기준값.
8. **수락 시험**: AT-JO-01~18과 01b(`tests/acceptance/HEJO-JUMP-ONCE.md` 5판). 기대값 출처: spec 4·5절과 시험의 독립 계산. 상태: 명세 확정 / 코드 미작성 / 미실행 / 계획 검증 대기.
9. **작업 범위·순서**
   1. 공개 worktree를 0절 시작점에서 만든다: `../.worktrees/hejo-jump-once-public-20261126`, 브랜치 같은 이름. 증거는 그 worktree의 `.build/jump-once/`(커밋하지 않음).
   2. **TASK-01 시험 먼저**: AT-JO-01~15·17·18을 `app/Tests/`에 쓰고 기존 실행 입구에 등록한다. 가짜 서버가 필요한 시험은 기존 기록 하네스(`HistoryAutoloadHarness`와 그 가짜 서버)를 넓혀 쓴다. 제품 수정 전 시작점에서 돌려 `.build/jump-once/baseline.log`를 남기고 "기준본 기대"와 대조한다. 누름 한 번에 갱신이 몇 번 도는지, 요청 순서, 글 지정 열기가 사라지는 경우가 있는지를 기존 `ThreeTapDiagnostics`로 기록해 impl-report에 적는다. 어긋나면 제품을 고치지 말고 멈추고 보고한다.
      - **가정 확인**: G-1(확인), G-2·G-3(불성립, 3·4판에서 요구 조정)은 1·2차 진단을 재사용한다. 착수를 막는 가정은 더 없다. 4판 AT-JO-01·01b·09 기준본(`.build/jump-once/v4-baseline.log`)은 재사용하고, 5판에서 바뀐 AT-JO-08(글 대상·카드 대상 입구 구분)·AT-JO-18(첫 글은 규격대로 `final` 없는 `message`) 입력으로 기준본을 남기고, '기준본 기대'와 어긋나면 제품을 고치지 말고 멈추고 보고한다.
   3. **TASK-02 → TASK-03 → TASK-04 → TASK-05** 순서로 제품을 고친다. TASK마다 해당 AT를 돌려 `.build/jump-once/`에 로그를 남긴다. TASK-04는 갱신 중·실패 상태의 카드창과 대화창 PNG를 `.build/jump-once/`에 저장하고 impl-report에 경로를 적는다.
   4. **TASK-06**: AT-JO-16 전체 회귀. 실패 목록을 시작점과 비교한다. `history-status` 줄을 기대하던 기존 시험은 spec REQ-JO-03 기준으로 고치고 고친 항목을 줄별로 보고한다. 그 밖의 기존 기대값은 바꾸지 않는다.
   5. 공개 worktree에 시험 커밋과 TASK별 제품 커밋을 만든다(`git commit --only`로 자기 경로만). 커밋 전에 `github/main`이 바뀌었으면 그 위로 다시 올리고 AT-JO를 다시 돌린다. `impl-report.md`를 planner checkout의 이 폴더에 쓴다(자기 파일만).
   - 금지: 개발 `main`·planner checkout의 제품 코드 수정, 수락 시험 기대값 변경, `gate/`·`schemas/`·`hub/` 수정, 선택 변경 때 전체 갱신의 구조 변경, 새 설정·새 한도 값·새 지연 시간 상수 추가, 미리 받기에서 글 지정 열기 사용, 미리 받은 본문 고정(pin), `docs/spec/current` 수정(TASK-07), `~/.hermes` 설정·재시작·비밀 파일, 앱 설치, 버전 올리기, git push, 범위 밖 정리.
   - 선행: 없음.
   - 병렬 갈래: 없음(파일 겹침: `ConversationView.swift`를 TASK-02·03·04가, `HistoryCoordinator.swift`를 TASK-02·03이, `ConversationController.swift`를 TASK-02·05가 고친다).
10. **가정·미확정**: design 8절. G-1 확인. G-2 불성립 → 미리 받기는 최근 쪽만(D-08). G-3 불성립 → 써지는 중 집계 변화도 끝 조각 뒤로 미룸(D-11). 표시·안내 줄의 모양은 PNG로 사용자가 확인한다. 착수를 막는 미확정은 없다.
11. **사용자 확인**: D-01~03, D-08~11을 2026-11-26 대화로 받았다. 사전 위임 없음.

## 인계 전 점검
- base_commit은 착수 때 고정한다(0절). design 2절은 `2dea766` 기준으로 확인했다.
- G1: 요구·범위·제외·사용자 결정 기록. G2: 현황 근거(파일·줄), 원본 하나, 경로 판정. G3: AC↔AT 연결, 사전 검토는 계획 검증으로 받는다(1회차 BLOCKED 3건 반영, 2회차 APPROVED). G4: 위험 일반, REQ→AC→AT→TASK 연결, 착수 차단 미확정 없음.
