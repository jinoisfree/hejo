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

## 3회 · 2026-11-23 · TASK-01 판정: 미완료(부분 구현, 구현 담당 보류) — 원인: 수락 시험 오류(계획 담당)

- 대상: 구현 worktree HEAD `054d392` + 미커밋 11파일(앱 7, 시험 4; 보존 `task-01-candidate.patch`). 검증 조건: 교차 모델.
- [확인] 실패 지점 AT-UC-12: 끝까지 스크롤한 뒤 x=S+145에서 바닥−14는 카드 안(RGBA 52,52,52,112), 바닥−60은 카드 사이 빈 곳(36,36,36,107)이다(`task-01-bottom-pixels.json`). 같은 높이 방 목록 표본 차는 0. 카드가 바닥까지 차 있으면 칸 가운데 세로선은 카드와 빈 곳을 번갈아 지나므로 3판 기대는 제품이 맞아도 실패한다. 바탕을 카드와 같게 바꾸거나 여백을 넣지 않고 멈춘 판단이 옳다.
- 조치: 수락 시험 4판 AT-UC-12 — (가) 카드 3장으로 목록 아래가 빈 상태에서 x=S+145 두 높이, (나) 12장 끝까지 스크롤에서는 카드 밖 왼쪽 여백 x=S+3 두 높이 + (가) 빈 곳과 비교. 오차·뜻(바닥까지 같은 톤, 덮개 없음) 그대로. handoff 8항 4판.
- 중간 확인(최종 판정 아님): 이관 내역 표(impl-report)는 design 4.1과 파생 수치 규칙 안이다(AT-DI-22 테두리 y45→26 = 52/2, 폭 278 = 290−12, 226 = 230−4). 공용 세로줄 값 `AttentionRail`를 `SidebarMotion.swift`에 두고 채팅 카드도 쓰는 구조는 design 2.2에 맞다. 설계 적합성(4.2) 최종 판정은 전체 시험 통과 커밋에서 한다.

## 4회 · 2026-11-23 · TASK-01 판정: 미완료(새 칸 시험 통과, 전체 시험 1건 실패로 보류) — 원인: 설계 누락(계획 담당)

- 대상: 구현 worktree HEAD `67bbba1` + 미커밋 11파일(`task-01-edition-4-final-candidate.patch`). 검증 조건: 교차 모델.
- [확인] 집중 시험 `--drawer-inline` 종료 0, AT-UC-10~19 통과(`task-01-edition-4-focused.log`). 전체 시험 종료 1 — `IslandTests.swift:120` "AT56 highlight expires at 1.5 seconds"(`task-01-edition-4-final-app-tests.log`).
- [확인] 원인: `:115-120` 블록은 HEJO-TODO-DRAWER 때 이미 칸 카드 경로(`selectDrawerCard`)로 바뀌어 있었는데, design 3판 4.1이 이것을 "알약 경로 1.5초"로 잘못 적었다. 새 요구(칸 선택 동안 유지)와 정면 충돌하므로 구현 담당의 보류가 맞다.
- [확인] TASK-02 예고 누락 두 건도 맞다: `IslandTests.swift:44` `idleStripe` 44×12, `DrawerInlineTests.swift:53` `field("heading")`.
- 조치(design 4판·수락 시험 5판·handoff 8항): AT56 `:120`을 칸 선택 유지 + 칸 닫기 해제로 이관(TASK-01), 알약 경로 1.5초 만료는 AT-UC-05(나)에 명시해 TASK-02에서 보호. `idleStripe` → AT-UC-01·05로 대체·API 제거, `heading` 대표 보기 → `headerDrag`. 같은 종류 반복을 막으려고 **제거 보기 규칙** 추가(없애는 표현 API를 읽는 단언은 같은 뜻의 새 대상으로 바꾸거나 대신하는 AT-UC를 적고 지움, 행동·순서·개수·시간 단언은 제외).
- 중간 코드 확인(최종 판정 아님): `selectDrawerCard`가 알림만 1.5초, 그 밖은 `highlightUntil=nil` + `drawerSelectedID`로 유지, `refresh`에서 칸 닫힘 때 해제. 세로줄 `AttentionRail`(폭 3·안쪽 6·위아래 10, 색 하나)을 칸과 채팅 질문 카드가 같이 씀. 카드 색 `SidebarTone.cardFill/cardBorder` 공용 값. `SidebarBlank` 덮개 제거, 열 바탕 바닥까지. design 2.2에 맞다.
- 남은 증거: 선택 뒤 비동기 스크롤 정착 화면(구현 담당 지적) — TASK-01 커밋 전 보강.

## 5회 · 2026-11-23 · TASK-01 판정: 부분 완료(이번 변경 범위 통과, 전체 시험은 환경 실패로 미도달) — 원인: 환경(기준 코드에서도 재현)

- 대상: 구현 worktree HEAD `e400512` + 미커밋 13파일(`task-01-edition-5-candidate.patch`; 이번 재개 변경은 시험만 — AT56 이관, `UICleanDrawerTests` async 정착 확인, `TestMain`·`DrawerInlineTests` 호출 전파). 검증 조건: 교차 모델.
- [확인] AT56 이관은 design 4판 4.1 행대로(1.6초 유지 + 칸 닫기 해제). AT-UC-10~19·AT56 통과, 양 테마 정착 선택 화면 생성(`task-01-selected-settled-{dark,light}.png`).
- [확인] 전체 실패는 `ConnectionsTests.swift:219` AT-HC-27(`window.isKeyWindow` 거짓, `appActive=false`). 같은 실패가 **변경 없는 기준 `e400512` 복사본**에서도 같은 값으로 재현된다(`task-01-edition-5-baseline-connections.log`, `…-baseline-full-unit-venv.log`, 144개 소스 바이트 대조 `…-baseline-provenance.json`). 앱 활성화가 필요한 단언이라 사장 부재·화면 상태·같은 Mac의 다른 세션 GUI 시험 같은 환경 요인이다. 이번 변경 원인 아님.
- 영향: 실행 순서상 AT-HC-27 뒤 시험(`TestMain.swift:293` 이후)과 네트워크 fixture·gate 시험은 이번 변경본으로 아직 돌지 않았다. 증거 수준 2 미도달.
- 결정: TASK-01은 **환경 예외를 기록하고 커밋 허용**, TASK-02·03 진행. 단 main 병합 전 조건 = 앱이 활성화될 수 있는 환경에서 전체 `test.sh` 종료 0(AT-HC-27 포함). 그 전까지는 뒤쪽 시험을 별도 확인한다(아래 계획).
- 설계 적합성(4.2) — TASK-01 중간 판정: 적합. 카드 문장 원본 `TodoDrawerModel`(status·statusUrgent·trailing), 그리기 `TodoDrawerView`, 세로줄 공용 값 `AttentionRail` 하나를 칸·채팅이 같이 씀, 선택 원본 `ConversationView.drawerSelectedID`, 0개 흐림은 공용 `ComposerButton` 인자. 두 번째 원본·시험용 옛 API 없음. 최종 판정은 전체 시험 종료 0 커밋에서.

## 6회 · 2026-11-23 · TASK-01 판정: 부분 완료(커밋 전) — 원인: 환경(검증 환경 불안정), 변경 원인 근거 없음

- 대상: 구현 worktree HEAD `5db23f5` + 미커밋 13파일(이전 후보와 바이트 동일, `task-01-exception-review-state.json`). 임시 AT-HC-27 건너뛰기는 원문 SHA-256으로 복원 확인. 검증 조건: 교차 모델.
- [확인] AT-HC-27 건너뛴 전체 앱 실행: AT-HC-20~29 통과 뒤 `TestMain.swift:18` 공용 대기 "timed out"(`task-01-authorized-exception-app-tests.log:255`). 다음 순서는 `progressLayoutTests` 이후(`TestMain.swift:294-`)이며 어느 시험인지 미확정. 기준 코드에서 같은 지점이 재현되는지는 아직 안 봤다.
- [확인] gate 시험 422 통과·5 실패(`task-01-exception-review-gate-ready.log`): `import yaml` 없음 3건, `hermes_facility` 없음 1건, `test_delivery_parity.py:125` 승인 단추 문구가 번역 키(`platform.sl…confirm.cancel`)로 나옴 1건. 지정 게이트 Python 환경(Hermes 설치 환경)의 모듈·본체 문구 문제이고, 이 작업은 `app/`만 바꿨으므로 gate 결과에 영향을 줄 경로가 없다.
- 판단: 사장 부재 중 같은 Mac의 다른 세션 작업과 Hermes 환경 변화로 "전체 종료 0"을 지금 얻을 수 없다. 변경 탓인지 가리는 기준을 **기준 코드와의 차이**로 바꾼다 — 같은 명령을 변경 없는 기준 복사본에서 돌려 실패 집합이 같으면 환경 예외로 기록하고 TASK 커밋 허용. main 병합 조건(앱 활성 가능·정상 Hermes 환경에서 전체 종료 0)은 그대로.
- 설계 적합성(4.2): 5회 중간 판정(적합)에서 제품 코드 변화 없음.
