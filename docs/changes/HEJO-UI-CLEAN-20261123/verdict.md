# HEJO-UI-CLEAN 검증 기록

## 1회 · 2026-11-23 · TASK-01 판정: 미완료(구현 담당 착수 전 보류) — 원인: 설계 누락(계획 담당)

- 대상: 구현 worktree `role-workflow/17-96051e66` HEAD `aa65bfb`(main 계획 커밋 fast-forward), 미커밋 없음, 앱 변경 없음(`preflight.json`의 `git diff --exit-code HEAD -- app/` 종료 0). 검증 조건: 교차 모델.
- [확인] 보류 사유 R-UC-I1이 맞다. 1판 design 4절 이관 목록에 없는 기존 단언이 새 요구와 부딪힌다: AT-DI-12 카드 폭 262(`DrawerInlineTests.swift:213`), AT-DI-22 옛 배지 영역 픽셀(`:150-201`), AT-DC-21·21b `badge` 문장(`TodoDrawerTests.swift:252,259-260`).
- [확인] 계획 담당이 시험 전체를 다시 훑어 같은 종류의 누락을 더 찾았다: AT54·AT55·AT67(`parts`), AT52·AT79·`ScrollTests`·`ConversationUpdateTests`(`heading`·`subtitle`), AT-DC-23(1.5초), AT-DI-35·37(머리 두 띠 수치), 알약 클릭 좌표(`partRects`).
- [확인] 1판 요구 두 곳이 기존 계약과 부딪히거나 이미 되어 있었다: UC-04 AC-01 "칩 → 칸 필터 열기"는 AT77(칩 = 가장 오래된 질문 이동·1.6초)과 충돌하고 사장 결정에도 없던 에이전트 추가. UC-05 AC-02·03 툴팁은 이미 있다(`ConversationChrome.swift:64-65,178`, AT88·AT89).
- 조치(계획 2판): design 4.1에 TASK별 이관 허용 표(파일:줄·새 기대, 지키던 뜻 유지 원칙), spec 2판(칸 머리 수치 토글 x 14~244·✕ 24×24 x 252~276, 카드 폭 278, 알림 카드는 1.5초 규칙 유지, 칩 클릭 그대로, 툴팁 유지), 수락 시험 2판(AT-UC-10·14·17·30·34·40), handoff 8항, tasks TASK-03.
- 분홍 표식·접기 단추: 예비 정적 조사만(주인 미확정). TASK-03에서 실제 화면 관측으로 확정하는 지시 그대로.
- 설계 적합성(4.2): 판정 대상 코드 없음.

## 2회 · 2026-11-23 · TASK-01 판정: 미완료(구현 담당 착수 전 재보류) — 원인: 설계 누락(계획 담당)

- 대상: 구현 worktree HEAD `3587ff2`(fast-forward), 깨끗함, 앱 변경 없음(`resume-2-preflight.json`). 검증 조건: 교차 모델.
- [확인] R-UC-I2 두 항목 모두 맞다: AT-DI-39 `track.frame.width==262`(`DrawerHeaderTests.swift:104`)가 4.1 표에 없음. AT-TD-22·AT-DC-21·21b 시험 입력은 링크·notice가 없어 `linked==false`인데(AT-DC-22 `:263`가 직접 단언), 2판 표의 새 문장에 spec UC-03 AC-02의 " · 연결된 대화 없음" 접미사가 빠져 명세와 표가 서로 어긋났다.
- [확인] AT-DI-22 준비 코드가 첫 카드를 선택한 채 테두리 동등을 비교한다는 지적도 맞다(선택 테두리 강조색 요구와 충돌).
- 조치(design 3판·수락 시험 3판·handoff 8항): AT-DI-39 행(폭 230), 마감 문장 세 행에 연결 없음 접미사, AT-DI-22 테두리 비교는 선택 없음 상태. 같은 종류 반복을 막으려고 **파생 수치 규칙** 추가 — spec 수치에서 산수로 바로 나오는 숫자만 바뀌는 같은 뜻의 단언은 표에 없어도 옮기고 impl-report에 계산식과 함께 기록. AT-UC 기대값은 바꾸지 않았다.
- 설계 적합성(4.2): 판정 대상 코드 없음.
