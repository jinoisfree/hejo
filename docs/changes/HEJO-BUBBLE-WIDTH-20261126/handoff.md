# [설계 인계: HEJO-BUBBLE-WIDTH TASK-01 / 말풍선 최대 폭 75%와 폭 맞춤]

0. **기준**: base_commit = 착수 시 `github/main` tip(설계 기준 `2dea766cbdbd5e179a6269aabbfefc750036b219`). spec 2판·design 2판·수락 시험 2판(계획 검증 1회차 반영, [plan-review.md](plan-review.md)) / 작성 2026-11-26 / 승인: 사용자 결정 D-01·D-02([tasks.md](tasks.md)) / 운영 모드: 교차 모델(연합개발, 계획 검증 켜기).
   - 착수하면 `git fetch github` 뒤 tip 전체 해시를 base_commit으로 impl-report에 적고, design 2절 현황(파일·줄)이 그 커밋에서도 맞는지 확인한다. 말풍선 폭 계산이 설계와 다르게 바뀌어 있으면 멈추고 보고한다.
1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), 수락 시험 `tests/acceptance/HEJO-BUBBLE-WIDTH.md`, `docs/ARCHITECTURE.md`, 시안 [mock-bubble.png](mock-bubble.png). 이 문서들은 planner checkout(개발 `main`)에 있다.
2. **요구와 수락 기준**: REQ-BW-01(최대 폭 `B = min(C, max(240, 0.75 × C))`, 내 글·직원 글 같은 여백), REQ-BW-02(자동 줄바꿈·표·코드·왼쪽 정렬이 아닌 문단이 없으면 가장 긴 줄에 맞춤, 있으면 `B`. "더 보기/접기" 글자 수용이 맞춤보다 먼저), REQ-BW-03(써지는 중 폭은 줄지 않음, 다 써지면 제 폭), NFR-BW-01(원본 하나), NFR-BW-02(회귀 없음).
3. **유지할 계약**: design 5절. 모서리·안쪽 여백·머리줄 배치·정렬 방향, 표·코드의 안쪽 폭 줄바꿈, "더 보기/접기" 위치, 써지는 중 높이 동작, 측정 캐시 상한.
4. **책임·흐름**: 숫자는 `ChatMetrics`, 식과 폭 맞춤은 `NativeThreadCard.layout`의 글 배치 한 곳. 호출부는 폭을 넘기지 않는다.
5. **기존 경로 판정**: design 4절. `Content.bubbleWidth`와 `ConversationView`의 영역 × 0.82 계산은 같은 변경에서 지운다. `TextLayout.swift`·`AppearancePreview.swift`는 고치지 않는다.
6. **위험도·증거**: 일반. 필요한 증거 수준 2(앱 시험 하네스). 앱 설치·서버 작업 없음. 되돌리기는 커밋 되돌림.
7. **변경 성격**: 의미 변경(화면 배치). 비교: 수락 시험의 "기준본 기대" 열.
8. **수락 시험**: AT-BW-01~10(`tests/acceptance/HEJO-BUBBLE-WIDTH.md` 2판). 기대값 출처: spec 3·4절과 독립 계산. 상태: 명세 확정 / 코드 미작성 / 미실행 / 계획 검증 2회차 APPROVED.
9. **작업 범위·순서**
   1. 공개 worktree를 착수 tip에서 만든다: `../.worktrees/hejo-bubble-width-public-20261126`, 브랜치 같은 이름. 증거는 그 worktree의 `.build/bubble-width/`(커밋하지 않음).
   2. **시험 먼저**: AT-BW-01~06·10을 `app/Tests/`에 새 시험 파일로 쓰고 기존 실행 입구에 등록한다. 제품 코드 수정 전 착수 커밋에서 돌려 `.build/bubble-width/baseline.log`를 남긴다. 옛 `bubbleWidth` 인자가 있어야 빌드되는 기준본 실행에서는 `OwnerProfileTests`의 배치 도우미와 같은 값(`width × bubbleWidthFraction`)을 넣는다. "기준본 기대" 열과 다르면 제품을 고치지 말고 멈추고 보고한다.
   3. 제품: `ChatStyle.swift`(0.75), `NativeThreadCard.swift`(식, 폭 맞춤, 써지는 중 폭, `Content.bubbleWidth` 제거), `ConversationView.swift`와 시험 호출부의 인자 제거.
   4. AT-BW-01~07·10 실행, AT-BW-09 PNG 저장, AT-BW-08 회귀 실행. 실패 목록을 착수 커밋과 비교한다.
   5. 공개 worktree에 시험 커밋과 제품 커밋을 만든다(`git commit --only`로 자기 경로만). 커밋 전에 `github/main`이 바뀌었으면 그 위로 다시 올리고 AT-BW를 다시 돌린다. `impl-report.md`를 planner checkout의 이 폴더에 쓴다(자기 파일만).
   - 금지: 개발 `main`·planner checkout의 제품 코드 수정, 수락 시험 기대값 변경, 옛 폭 규칙과 무관한 기존 시험 기대값 변경, `TextLayout.swift`·`AppearancePreview.swift` 수정, 색·모서리·안쪽 여백·머리줄 변경, `docs/spec/current` 수정(TASK-02), `~/.hermes` 설정·재시작·비밀 파일, 앱 설치, 버전 올리기, git push, 범위 밖 정리.
   - 선행: 없음.
   - 병렬 갈래: 없음(갈래 3개 미만: 앱 배치 한 갈래).
10. **가정·미확정**: [가정] 자동 줄바꿈 여부를 글 배치 안에서 판정할 수 있다. [확인] 대화 목록은 자기 폭이 바뀌면 스스로 다시 잰다(design 4절). AT-BW-10이 수정본에서 실패하면 멈추고 보고한다. 착수를 막는 미확정은 없다.
11. **사용자 확인**: D-01·D-02를 2026-11-26 질문으로 받았고 시안을 보고 "좋다"고 했다. 사전 위임 없음.

## 인계 전 점검
- base_commit은 착수 때 고정한다(0절). design 2절은 `2dea766` 기준으로 확인했다.
- G1: 요구·범위·제외·사용자 결정 기록. G2: 현황 근거(파일·줄), 원본 하나, 경로 판정. G3: AC↔AT 연결, 사전 검토는 계획 검증으로. G4: 위험 일반, REQ→AC→AT→TASK 연결, 미확정 없음.
