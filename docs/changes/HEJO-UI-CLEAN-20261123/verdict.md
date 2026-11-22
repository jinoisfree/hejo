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

## 7회 · 2026-11-23 · TASK-01~03 판정: 부분 완료(구현 완료, 시험 일부 미도달) — 원인: 환경

- 대상: 구현 브랜치 `role-workflow/17-96051e66` 커밋 `cc68b1c`(TASK-01)·`28cc1bc`(TASK-02)·`31b9d92`(TASK-03, HEAD), 기준 `be67d01`. 작업 트리 깨끗함. 세 커밋 모두 `app/`만. 검증 조건: 교차 모델.
- [확인] 코드 직접 읽음:
  - TASK-02 `IslandModel.snapshot`: `title`·`dot(todoTotal>0)`·`activity` 하나, 우선순위 끊김 > 다시 연결됨 > 권한/저장 오류 > 전송 실패 > 올리는 중 > 미리보기(질문 "이름: 첫 줄 · 답하기", action은 가장 오래된 질문) > 일하는 중("이름 일하는 중 · N분"/"N명 일하는 중", 얼굴 3). `parts`·`iconOnly`·"닫기 ‹"·owner 개수 제거. `IslandView`: `titleRect`/`activityRect` 두 영역 클릭, 점 `CAKeyframeAnimation` opacity [1, 0.35, 1] 2.4초 반복, 칸 열림·동작 줄이기면 없음, 칸 열림 테두리 강조색, 말줄임. `ConversationView`: `heading`·`subtitle` 제거, 알약 폭 한도 `right-24`, 제목·할 일 개수 입력.
  - TASK-03: 칩 줄 `drawerOpen`이면 숨김(칩 클릭 경로 불변), 홈 줄 배지 3종 숨김, 판단 단추 표준 네 낱말은 글자만, `EmployeeSidebarCell.refreshChrome`을 `performAsCurrentDrawingAppearance` 안에서 실행(밝은 테마 묶음 글자 원인 = 색 풀림 시점, 그 자리 수정), 빈 `failureBar` 숨김(분홍 모서리 48→0 픽셀, 주인 확정). 접기 ⌄: 실제 펫 창의 옛 접기 단추는 숨김, 시안의 ⌄는 HTML 장식 — 해당 없음.
- [확인] 화면 증거 직접 열람: `task-03-open-dark.png`(칸 한 줄 머리·0개 아닌 필터·사진 카드·급함 세로줄이 채팅 카드와 같은 자리·칩 줄 없음·알약 "hejo │ ●" 파랑 테두리·단추 글자만), `task-02-question-dark.png`(알약 "시험 방 │ ● [사진] 직원 A: 첫 질문 · 답하기").
- [확인] 시험: 집중 실행 종료 0(AT-UC-01~06·10~19·30~35, AT88·89 포함). 전체 앱 실행은 변경본·기준 모두 같은 지점에서 종료 1 — AT-HC-27(`appActive=false`)과 `ConnectionsTests.swift:346` connectionManagementTests timeout(`verdict-6-candidate-app.log`·`verdict-6-baseline-app.log`). gate 422 통과·같은 5 실패(기준·최종 동일). 환경 예외 기준(6회) 충족.
- 남은 틈: `TestMain.swift:294` 이후 앱 시험(progressLayout·threeTap·rooms·bubbleReply·petNotification·picturesSidebar·appIcon·login·composer)과 네트워크 fixture가 **변경본에서 한 번도 돌지 않았다**. 이번 변경이 닿는 화면(방 목록·입력 줄·알약)과 겹치므로 main 병합 전에 확인이 필요하다.
- 관찰(범위 밖, 후속 후보): 칸 카드 제목이 시험 글의 마크다운 표시(`**…**`)를 그대로 보인다. 카드 제목 원본은 이번에 바꾸지 않았다.
- 설계 적합성(4.2): **적합**. 알약 상태 원본 `IslandModel` 하나·그리기 `IslandView` 하나, 카드 문장 `TodoDrawerModel`, 세로줄 `AttentionRail` 한 값, 선택 원본 `drawerSelectedID`, 0개 흐림은 공용 `ComposerButton`. 옛 표현 API(`heading`·`subtitle`·`parts`·`idleStripe`)는 시험용으로 남기지 않고 제거. 두 번째 원본 없음.
- 원격: 공개 원격 `github/main`(0.2.x 공개 스냅숏 이력, 로컬 main과 공통 조상 없음)은 직접 푸시 대상이 아니다. 공개는 릴리즈 총괄(18번)이 맡는다.

## 8회 · 2026-11-23 · 판정: 구현 검증 완료(조건: 교차 모델, 환경 예외 1건) — main 병합. 사장 확인 M-UC-1 남음

- 대상: 구현 브랜치 HEAD `1b26d789f99ad0d67f853b3a353ef77d56d7eb03`(앱 코드는 TASK-03 `31b9d92`와 동일, 문서 병합만). 기준 `be67d01`.
- [확인] 보완 실행(`connectionsTests()` 호출 한 줄만 임시 제외, 같은 명령·Python·호스트): 변경본·기준 모두 종료 0, 실패 0, 변경본에만 있는 실패 없음(`remaining-tests-comparison.json`, `remaining-tests-candidate.log` `APP_TEST_FAILED` 0건·마지막 `OK`). 임시 수정 복원: 추적 파일 665개 blob 차이 0, `git diff`·`git status` 비어 있음.
- 시험 종합: 집중 AT-UC-01~40 대상 통과, 연결 시험 앞뒤 앱 시험·네트워크 fixture·hook 통과. 미통과는 환경 예외 둘뿐이며 기준과 같은 값으로 재현된다 — AT-HC-27(`appActive=false`)과 `ConnectionsTests.swift:346` timeout. gate 5 실패(yaml·hermes_facility 없음, 승인 문구 번역 키)도 기준 동일이고, 이 작업은 `app/`만 바꿨다. 원래 main 병합 조건으로 걸었던 "정상 환경 전체 종료 0"은 환경 탓에 지금 얻을 수 없다. 변경 원인이 아님을 기준 비교로 보였으므로 병합하고, 정상 환경 재실행은 사장 확인(M-UC-1) 때 함께 한다.
- 설계 적합성(4.2): 적합(7회 판정, 이후 앱 코드 변화 없음).
- 병합: 계획 담당이 `1b26d78`을 로컬 main에 `--no-ff` 병합. 공개 원격 `github/main`은 별도 공개 스냅숏 이력이라 직접 푸시 대상 아님 — 공개는 릴리즈 총괄(18번)이 맡는다.
- 남은 것: M-UC-1(사장이 개발 빌드에서 알약·칸 카드를 어둡게·밝게로 보기), 정상 환경 전체 `test.sh` 재실행, 후속 후보(칸 카드 제목의 마크다운 `**` 노출).
