# 설계 인계: HEJO-UI-CLEAN / TASK-01~03

```text
[설계 인계: HEJO-UI-CLEAN TASK-01~03 / 앱]
0. 기준: main(이 인계 커밋) / spec·design·수락 시험 2판, tasks 1판 / 2026-11-23 / 승인: 사장 최종 시안 final-4와 결정들(brainstorm.md) / 운영: 연합개발.
   구현 worktree가 role-workflow/17-96051e66이면 먼저 최신 main을 merge(rebase·force 금지, 충돌 시 멈춤).
1. 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-UI-CLEAN-20261123/{brainstorm,spec,design,tasks}.md, tests/acceptance/HEJO-UI-CLEAN.md,
   시안 docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-4.png(기준). 앞선 작업: HEJO-DRAWER-INLINE(칸 배치·토글·고정 머리), HEJO-TODO-DRAWER(알약·칸), HEJO-DEADLINE-CLOSE(마감 카드 메뉴).
2. 요구: REQ-UC-01~06. 핵심: 제목 알약 하나(방 이름 + '│ ●' 2.4초 숨 쉬는 점 + 오른쪽 활동 하나, 제목 클릭=칸, 활동 클릭=행동),
   칸 머리 한 줄, 사진 카드 52pt(상태 한마디·오른쪽 시각), 급함 세로줄 공용 값(채팅 카드 같은 위치), 선택↔채팅 강조 유지·답글, 키보드, 중복 정리.
3. 유지: design 5절. 답글/새 글 토글·직원 얼굴 줄은 그대로(사장 결정).
4. 책임: 알약 상태 = IslandModel, 그리기 = IslandView, 카드 문장 = TodoDrawerModel, 카드 그리기 = TodoDrawerView, 세로줄 = 공용 값 하나, 선택 원본 = ConversationView.drawerSelectedID.
5. 기존 경로: design 4절(교체·제거 목록과 이관 대상 시험).
6. 위험도 일반, 증거 2 + 화면 사진(어둡게·밝게; 알약 상태별, 칸 열림/닫힘, 키보드 선택).
7. 의미 변경(표현·상호작용). 비교: AT-UC 전부 + 전체 앱 시험.
8. 수락 시험: tests/acceptance/HEJO-UI-CLEAN.md 4판 AT-UC-01~40. 기대값 변경 금지. 이관 허용은 design 3판 4.1 표(파일:줄·새 기대)의 기존 단언과 4.1 파생 수치 규칙뿐, 줄 번호가 밀리면 같은 단언 문자열로 찾는다(전후 목록 보고).
   [미확인] 두 건(분홍 표식, 접기 단추 주인)은 조사 결과를 보고. 그 밖에 기대·설계가 코드와 안 맞으면 멈추고 보고.
9. 범위: tasks.md 영향 파일만. 금지: gate/·schemas/·kit/·hub/, 운영 공항, Hermes 본체, 버전 올림·공개, tests/acceptance/*.md, 다른 작업 문서. main 병합·설치 금지(계획 담당이 검증 뒤 병합).
   병렬 갈래: 없음(ConversationView 겹침). 순서 TASK-01 → 02 → 03, TASK마다 커밋. 시험은 HEJO_PYTHON=<게이트웨이 venv python> bash app/scripts/test.sh.
   증거 .build/ui-clean-evidence/(추적 안 함), 보고는 docs/changes/HEJO-UI-CLEAN-20261123/impl-report.md.
10. 가정: 알약 점 = 처리할 일 total>0(알림 포함)[에이전트 제안, 시안 확인]. 묶음 글자 버그 원인 = cgColor 풀림 시점[가정, 확인 필요].
11. 사용자 확인: 사장이 시안 단계별로 결정(brainstorm.md 표).
```
