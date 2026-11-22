# 설계 인계: HEJO-DRAWER-INLINE / TASK-01 처리할 일 칸을 방 목록과 채팅 사이로

```text
[설계 인계: HEJO-DRAWER-INLINE TASK-01 / 앱]
0. 기준: 이 저장소 main 0644e9e(설계 근거 줄 번호의 기준) / spec·design·수락 시험 2판, tasks 2판(계획 검증 1회차 반영, plan-review.md) / 작성 2026-11-22 /
   승인: 사장 결정 6개(brainstorm.md) + 계획 검증 2회차 APPROVED / 운영 모드: 연합개발(교차 모델, 계획 검증 켬)
   [갱신 2026-11-22] 착수 조건 충족 확인(계획 담당): HEJO-DEADLINE-CLOSE TASK-01~03 검증 완료(그 작업 verdict 2차), main 5a3f123에 병합,
   현재 main 95b9041. 0644e9e 이후 바뀐 앱 파일은 AppDelegate·ConversationController·ConversationView(+7/-?)·TodoDrawerModel·TodoDrawerView뿐이고
   PetLayout·PetController·PetView는 그대로다(design 1절 근거 줄 유효). TodoDrawerView·ConversationView 줄 번호는 옮겨졌을 수 있으니 이름으로 찾는다.
   새 기준: main 95b9041. worktree 브랜치는 0644e9e에 있으므로 먼저 main을 merge한 뒤 시작한다(rebase·force 금지).
   착수 조건: HEJO-DEADLINE-CLOSE TASK-03(앱: TodoDrawerView·ConversationView·TodoDrawerTests)이 main에 커밋돼 있어야 한다.
   `git log --oneline -- app/Sources/TodoDrawerView.swift`에 그 작업 커밋이 없거나 그 파일들에 다른 작업의 커밋 안 된 변경이 있으면
   손대지 말고 "보류(2절 보고)"로 멈춘다. 반영돼 있으면 그 HEAD를 새 기준으로 적고, design 1절 근거 줄이 옮겨졌는지만 확인해 계속한다.
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-DRAWER-INLINE-20261122/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-DRAWER-INLINE.md. 앞선 작업: docs/changes/HEJO-TODO-DRAWER-20261120/, HEJO-FINDER-FOLDERS-20261121(REQ-FF-08·13), HEJO-DEADLINE-CLOSE-20261122.
2. 요구와 수락 기준: REQ-DI-01~07. 정상: 방 목록 | 칸 | 채팅 | 웹 칸, 창은 오른쪽으로 290 넓어짐(웹 칸도 밀림),
   오른쪽 자리 없으면 창+펫이 모자란 만큼 왼쪽으로(저장 위치 불변, 닫으면 제자리), 칸 바탕은 방 목록과 같은 옅은 톤(불투명 판 없음), 카드는 부드러운 색.
   핵심 경계: 화면이 좁으면 칸 290 유지, 채팅이 좁아짐(덮기·막 없음), 저장된 chatWidth 불변.
3. 유지할 계약: design 5절(알약, 칸 모델, 마감 요청 시점, todoDrawerOpen, paneSplit 규칙, 290·0.25초, Esc·접기, 펫 저장 위치).
4. 책임과 흐름: 칸 폭 판정 = PetPlacement 한 곳, 칸 열 배치 = ConversationView.layout 한 곳, 칸 열 바탕·선 = ConversationView.draw(방 목록과 같은 공용 값),
   카드 색 = TodoDrawerView. PetView는 칸을 모른다(design 2절).
5. 기존 경로 판정: design 4절. 교체: leading/withLeading/drawerOverlay/shownLeading 역산 → 오른쪽 넓힘·칸 폭 독립 보간, contentBubble은 '칸 뺀 상자' 뜻으로 유지(크기 조절 계약 보존). 제거: PetView 칸 꽂기·덮개·TodoDrawerScrim·칸 불투명 배경.
   옛 시험 AT-FF-40·41·90~93, AT-TD-30(덮개)·31·33·34·35 단언은 AT-DI로 교체(옛 파일 지우거나 바꾸고 TestMain 등록 맞춤).
6. 위험도: 일반(공통 4절) — 여러 모듈 화면 배치, 저장·통신·권한 변화 없음, 커밋 되돌리기로 롤백. 필요 증거 수준 2 + M-DI 확인용 화면 사진.
7. 변경 성격: 의미 변경(칸 위치·창 넓힘 방향·색). 비교: AT-DI-05·09·10 좌표 비교, AT-DI-32 전체 시험.
8. 수락 시험: tests/acceptance/HEJO-DRAWER-INLINE.md 4판 AT-DI-01~14·20~23·30~34. 기대값 출처는 그 문서 머리.
   상태: 명세 완료 · 코드 미작성 · 미실행 · 계획 검증 통과(2회차). 시험 기대값은 바꾸지 않는다(틀렸다고 보면 멈추고 보고).
9. 작업 범위: tasks.md TASK-01 영향 파일만. 금지: gate/·schemas/·kit/·hub/, 운영 공항(~/.hermes), Hermes 본체, 운영 저장소, 버전 올림·공개,
   tests/acceptance/*.md(계획 담당 소유), 다른 작업 문서. 선행: 0항 착수 조건. 병렬 갈래: 없음(파일 겹침, tasks.md).
   커밋은 git commit --only로 자기 경로만. 보고는 이 폴더의 impl-report.md.
   시험은 Hermes 게이트웨이 venv python으로 실행한다(HEJO_PYTHON=<그 python> bash app/scripts/test.sh, 시스템 python3로는 실패할 수 있음).
   증거는 .build/drawer-inline-evidence/ 아래(추적 안 함)에 두고 impl-report에 상대 경로로 적는다.
10. 가정·미확정: 없음(칸 290 유지, 열린 동안 크기 조절은 칸 폭을 빼고 저장 — brainstorm 가정, spec에 반영).
11. 사용자 확인: 사장이 브레인스토밍에서 배치·넓힘 방향·자리 부족·좁은 화면·색·순서를 직접 골랐다(brainstorm.md).

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? → 착수 조건(0항) 확인 뒤 판단. 지금은 HEJO-DEADLINE-CLOSE TASK-03 대기.
- G1–G4: G1 spec·AC·사장 확인 있음 / G2 design 1절 근거·4절 판정 / G3 AC↔AT-DI 연결, 계획 검증 2회차 APPROVED(plan-review.md) / G4 위험도·롤백·연결 완비.
```

## 추가 인계: TASK-02 (4판, 2026-11-23)

```text
[설계 인계: HEJO-DRAWER-INLINE TASK-02 / 앱]
0. 기준: main(이 인계 커밋 이후 최신) / spec 4판 REQ-DI-08·09, design 4판 2.6, 수락 시험 8판 AT-DI-35~39, 시안 mockups/filter-options.png A안 /
   승인: 사장 요청(머리 고정·필터 띠 높이 44·단추 모양) + 시안 A 선택, 계획 검증 없음(TASK-01 계획 검증 통과분의 같은 칸 안 표현 변경) / 운영: 연합개발
1. 문서: 위 4판 절, TASK-01 결과 verdict.md 6회.
2. 요구: 제목 띠 44(가운데 정렬, 아래 1px 선) + 필터 띠 44(토글 가운데, 아래 1px 선) 고정, 카드 목록만 스크롤, 되돌리기 바닥 줄 고정 유지.
   필터는 '답글/새 대화' 토글과 같은 그리기(트랙 + 고른 칸 강조색·흰 글자), 칸 폭 균등, 마감 불가면 3칸.
3. 유지: TodoDrawerModel·필터 의미·개수 규칙, 카드 그리기·메뉴, onFilter/onCard/onClose, 290 폭 잘림, Esc.
4. 책임: 세 영역 배치 = TodoDrawerView 한 곳, 토글 모양 = ComposerButton·modeBackground와 같은 공용 원본.
5. 기존 경로: 스택 안 머리·필터 줄 → 고정 보기로 교체(스택에서 제거), TodoDrawerButton 필터 글자 제거.
6. 위험도 일반, 증거 2 + 화면 사진.
7. 의미 변경(표현). 비교: AT-DI-35~39, 전체 앱 시험.
8. 수락 시험: tests/acceptance/HEJO-DRAWER-INLINE.md 8판 AT-DI-35~39, 기대값 변경 금지.
9. 범위: tasks.md TASK-02 영향 파일만. 새 worktree면 최신 main에서 시작, 기존 role-workflow/17-96051e66을 쓰면 최신 main merge 후 시작.
10. 미확정: 없음.
11. 사용자 확인: 사장이 시안 A·높이 44를 골랐다.
```
