# [설계 인계: HEJO-CARD-DONE TASK-01 / 가운데 칸 카드 ✓ 띠로 한 번에 종결]

0. **기준**: base_commit = 착수 시 `github/main` tip(설계 기준 `018036cbf24678ea3a29f826926531e8ab4d370b`). spec 2판·design 2판·수락 시험 2판(계획 검증 1회차 반영) / 작성 2026-11-26 / 승인: 사용자 결정 D-01~D-04([tasks.md](tasks.md)), 계획 검증 결과는 [plan-review.md](plan-review.md) / 운영 모드: 교차 모델(연합개발, 계획 검증 켜기).
   - 착수하면 `git fetch github` 뒤 tip 전체 해시를 base_commit으로 impl-report에 적고, design 2절 현황(파일·줄)이 그 커밋에서도 맞는지 확인한다. HEJO-JUMP-ONCE가 먼저 반영돼 카드창 경고 줄·카드 클릭 경로가 바뀌었으면 design 7절을 따른다(의도 판단이 필요한 충돌이면 멈추고 보고).
1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), 수락 시험 `tests/acceptance/HEJO-CARD-DONE.md`, `docs/ARCHITECTURE.md`, 칸 표 [brainstorm.md](brainstorm.md), 시안 [mock-card-done.png](mock-card-done.png)(C안). 이 문서들은 planner checkout(개발 `main`)에 있다.
2. **요구와 수락 기준**: (3판 추가) REQ-CD-06(알림 ✓ 즉시 읽음), REQ-CD-07(직접 선택 시 알림 읽음 결함 재현·수정). REQ-CD-01(마우스 올림 시 오른쪽 44pt 초록 띠, 답 요청은 연결 있을 때만, 알림 제외), REQ-CD-02(띠 누름 = 종결만. 답 요청은 5초 뒤 "확인" `send` 1건·`click` 0건, 마감은 완료로 닫기. 되돌리기·줄 하나·앱 종료 시 미전송·중복 없음), REQ-CD-03(결과 ①즉시 실패 ②사후 거절·재연결 실패 ③미확정 ④접수 표: 카드 복구 시점·경고·자동 재전송 0건), REQ-CD-04(초록 완결 기존 규칙 회귀), REQ-CD-05(VoiceOver 동작), NFR-CD-01(대기 자리 하나), NFR-CD-02(회귀 없음).
3. **유지할 계약**: design 5절. 프레임·회원 상태 키·카드 크기·색·우클릭 메뉴·마감 되돌리기·경고 글·5초·75초.
4. **책임·흐름**: 띠 그리기·누름 판정은 `TodoDrawerCardView`, 종결 가능 판정·대기·전송·숨김은 `ConversationController`의 진입점 하나(`completeCard` 또는 같은 뜻의 이름), 숨김 반영은 `TodoDrawerModel.snapshot`의 `hidden`.
5. **기존 경로 판정**: design 4절. `pendingClose`는 두 종류를 담는 한 자리로 통합(옛 마감 전용 자리 제거). `closeDeadline`·`sendClose`·`sendText`·우클릭·카드 클릭은 유지.
6. **위험도·증거**: 일반. 필요한 증거 수준 2(앱 시험 하네스). 실제 문·직원에게 보내지 않는다(가짜 전송만). 앱 설치·서버 작업 없음. 되돌리기는 커밋 되돌림.
7. **변경 성격**: 의미 변경(화면 동작 추가). 비교: 수락 시험 "기준본 기대" 열.
8. **수락 시험**: AT-CD-01~15, 03b, 09a~d(`tests/acceptance/HEJO-CARD-DONE.md` 2판). 기대값 출처: spec 3절·사용자 결정. 상태: 명세 확정 / 코드 미작성 / 미실행 / 계획 검증 중.
9. **작업 범위·순서**
   1. 공개 worktree를 착수 tip에서 만든다: **호스트 배정 worktree 안** `<배정 worktree>/.build/card-done/public`, 브랜치 `hejo-card-done-public-20261126`(판정 1회 [verdict.md](verdict.md)로 경로 변경). 증거는 배정 worktree의 `.build/card-done/`(커밋하지 않음). 배정 브랜치(개발 이력)에는 제품 커밋을 하지 않는다.
   2. **시험 먼저(수락 시험 머리말의 두 묶음)**: 묶음 B(AT-CD-11(a) gate pytest, 11(b) 앱 `ThreadTools`, AT-CD-14 회귀)는 기존 API만 쓰는 별도 파일로 쓰고 착수 커밋에서 실행한다. 묶음 N(나머지)은 다른 새 시험 파일로 쓰고 기존 실행 입구에 등록한다. 착수 커밋에서 묶음 N은 빌드 불가가 정상이며 그 사실과 컴파일 오류 첫 줄을 기록한다. 결과는 `.build/card-done/baseline.log`. AT-CD-11이 기준본에서 실패하면 제품을 고치지 말고 멈추고 보고한다. 전송 시험은 실제 `sendText`→`transmit` 경로와 실제 수신 경로로 관측한다(`false` 대역 금지).
   3. 제품: `TodoDrawerView.swift`(띠·누름·VoiceOver·되돌리기 줄 글·경고), `TodoDrawerModel.swift`(답 요청 숨김·경고·종류), `ConversationController.swift`(진입점·공용 대기 자리·전송·`client_msg_id` 결과 연결: 기존 접수·거절·재연결 실패 자리에서 알림만 추가), `ConversationView.swift`(콜백 연결).
   4. 묶음 N 전체와 묶음 B 재실행, AT-CD-13 grep, AT-CD-14 회귀, AT-CD-15 PNG. 실패 목록을 착수 커밋과 비교한다.
   5. 공개 worktree에 시험 커밋과 제품 커밋을 만든다(`git commit --only <정확한 파일 경로>`). 커밋 전 `github/main`이 바뀌었으면 그 위로 다시 올리고 AT-CD를 다시 돌린다. `impl-report.md`를 planner checkout의 이 폴더에 쓴다(자기 파일만).
   - 금지: 개발 `main`·planner checkout의 제품 코드 수정, 수락 시험 기대값 변경, `gate/`·`schemas/`·`hub/` 수정, 대화 안 "확인"·답 버튼 동작 변경, 우클릭 메뉴 항목 변경, 카드 크기·색 변경, `docs/spec/current` 수정(TASK-02), `~/.hermes` 설정·재시작·비밀 파일, 실제 문·직원에게 전송, 앱 설치, 버전 올리기, git push, 범위 밖 정리.
   6. **TASK-03(3판 추가)**: TASK-01 제품 커밋 뒤 같은 공개 브랜치에서 한다. 먼저 AT-CD-18을 착수 커밋(기준본)과 TASK-01 커밋에서 돌려 실패 경우를 기록한다. 그다음 AT-CD-16·17(알림 ✓)을 쓰고, 알림 띠(즉시 `markNoticeRead` 경로, 되돌리기 없음)와 AT-CD-18에서 재현된 결함만 원인 자리에서 고친다. AT-CD-18이 모두 통과하면 결함 수정 없이 보고한다. 별도 커밋으로 남긴다.
   - 선행: 없음(TASK-03은 TASK-01 뒤).
   - 병렬 갈래: 없음(갈래 3개 미만: 앱 카드창 한 갈래).
10. **가정·미확정**: [확인] 앱 시험에 가짜 문으로 실제 전송을 하는 하네스가 있다(`HistoryAlertSeenHarness.swift:141`, `HistoryTransportHarness.swift:571,617`), 거절 프레임은 `controller.receive`로 넣을 수 있다(`TodoDrawerTests.swift:166`). [가정] AT-CD-09d의 쓰기 시작 뒤 오류를 하네스로 만들 수 있다. 못 만들면 그 시험만 멈추고 방법을 보고한다. [확인] 일반 사장 글은 앞 요청의 답이 된다(`history_queries.py:52-66`). 착수를 막는 미확정은 없다.
11. **사용자 확인**: D-01~D-04를 2026-11-26 질문으로 받았고 시안 C를 골랐다. 사전 위임 없음.

## 인계 전 점검
- base_commit은 착수 때 고정한다(0절). design 2절은 `018036c` 기준으로 확인했다.
- G1: 요구·범위·제외·사용자 결정 기록. G2: 현황 근거(파일·줄), 원본 하나, 경로 판정·통합. G3: AC↔AT 연결, 사전 검토는 계획 검증으로. G4: 위험 일반, REQ→AC→AT→TASK 연결, 미확정 없음.
