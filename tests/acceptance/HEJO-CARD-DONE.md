# HEJO-CARD-DONE 수락 시험

- 3판(spec 3판과 짝) · 상태: 명세 확정 / 코드 작성(`app/Tests/CardDoneTests.swift`, `card_done_fixture.py`, `CardAlertHarness.swift`, `test_card_alert_transport.py`, 기대값 소유는 기획설계) / 실행: 묶음 N·B와 AT-CD-16~18 통과, AT-CD-18은 착수본에서도 18개 통과(검증 담당 로그 확인) / 독립 검토: 계획 검증 2회차 APPROVED(2판)
- 가짜 명부·가짜 글만 쓴다. 실제 문·직원에게 보내지 않는다. 증거 수준: 공통 5절 2(앱 시험 하네스).
- 시계는 `controller.clock` 주입, 주기는 기존 마감 닫기 시험(`TodoDrawerTests.swift` AT-DC 부분)과 같은 방법으로 돌린다.
- **전송 관측:** 답 요청 전송 시험(AT-CD-03·03b·06·08·09a~d)은 실제 `ConversationController.sendText`→`transmit` 경로를 쓴다. 나가는 프레임은 연결된 가짜 문(기존 `HistoryAlertSeenHarness`·`HistoryTransportHarness`가 띄우는 시험 문, 또는 `GateClient`가 실제로 쓴 프레임을 기록하는 시험 연결)에서 센다. 사후 결과는 실제 수신 경로(`controller.receive`/`GateClient` 수신)에 프레임을 넣어 만든다. `sendText`를 `false`를 돌려주는 대역으로 바꾸는 방식은 쓰지 않는다.
- **착수 커밋 실행(두 묶음):**
  - 묶음 B(기준본 실행 가능, 새 진입점 없음): AT-CD-11(a)(b), AT-CD-14. 기존 API만 쓰는 별도 시험 파일·pytest에 둔다. 착수 커밋에서 실행해 결과를 `.build/card-done/baseline.log`에 남긴다. AT-CD-11이 기준본에서 실패하면 제품을 고치지 말고 멈추고 보고한다.
  - 묶음 N(새 진입점 필요): 표에서 "기준본 기대"가 `N`인 시험만. AT-CD-13·15는 어느 묶음도 아니며 제품 수정 뒤 실행한다. 별도 시험 파일에 두며 착수 커밋에서는 빌드되지 않는 것이 정상이다. `baseline.log`에 "묶음 N: 새 진입점이라 착수 커밋 빌드 불가"와 컴파일 오류 첫 줄을 적는다. 아래 표의 "기준본 기대"가 `N`이면 이 뜻이다.

| 시험 | AC | 입력·절차 | 기대값(출처: spec 3절) | 기준본 기대 |
|---|---|---|---|---|
| AT-CD-01 | CD-01.AC-01·02 | 답 요청 카드 1(키·글 id 있음), 마감 카드 1(참조 있음), 마감 카드 1(참조 없음), 알림 카드 1, 연결됨. 각 카드 뷰를 폭 268·높이 52로 만들어 마우스 올림 전·후 관측 | 올림 전: 띠 없음, 시간 글자 그려짐. 올림 뒤: 답 요청·참조 있는 마감 카드에 띠 틀 = x `268−44`~268, y 0~52. 참조 없는 마감·알림 카드는 띠 없음. 띠가 있으면 시간 글자 안 그려짐, 상태 줄 폭 ≤ 268−50−44−8 | N |
| AT-CD-02 | CD-01.AC-03 | AT-CD-01 답 요청 카드, 연결 끊김(`canSend=false`) | 답 요청 카드 띠 없음, VoiceOver 동작 없음. 마감 카드 띠 있음 | N |
| AT-CD-03 | CD-02.AC-01 | 답 요청 카드(직원 E, 대화 K, 제목 T) 띠 누름(띠 안 좌표로 `mouseDown`) | 대화 이동(`onCard`) 없음. 즉시 스냅숏에서 카드 빠지고 계수 `답 요청` 1 감소. 되돌리기 줄 `‘T’ 확인 보냄 ·` + `되돌리기`. 4.9초까지 전송 0건. 5초 뒤 전송 정확히 1건: `type=send`, `thread=K.thread`, `text="확인"`, 받는 직원 = E(사장이 그 스레드에 쓸 때와 같은 필드) | N |
| AT-CD-03b | CD-02.AC-07 | 직원 버튼 2개(`kind`가 reply가 아닌 것 1개 포함)가 달린 답 요청 카드 띠 누름, 5초 | 나가는 프레임: `send` 1건(`text="확인"`), `click` 0건 | N |
| AT-CD-04 | CD-02.AC-02 | 마감 카드(참조 R, 제목 D) 띠 누름 | 대화 이동 없음. 우클릭 "완료로 닫기"와 같은 결과: 되돌리기 줄 `‘D’ 닫음 ·`, 5초 뒤 `deadline_close` 1건 `outcome=done`, `deadline=R.id` | N |
| AT-CD-05 | CD-02.AC-03 | AT-CD-03을 하고 2초 뒤 되돌리기 | 10초 지나도 전송 0건, 카드 다시 보임(원래 순서), 되돌리기 줄 없음 | N |
| AT-CD-06 | CD-02.AC-04 | 답 요청 A 띠 → 1초 뒤 마감 B 띠 → 1초 뒤 답 요청 C 띠 → 1초 뒤 마감 D 우클릭 "취소로 닫기" | 되돌리기 줄은 늘 하나(마지막 것). B 누를 때 A의 `send` 즉시 1건, C 누를 때 B의 `deadline_close` 즉시 1건, D 누를 때 C의 `send` 즉시 1건, D는 5초 뒤 `outcome=cancel` 1건. 같은 카드 두 번 전송 없음 | N |
| AT-CD-07 | CD-02.AC-05 | 답 요청 띠 누름 → 2초 뒤 `controller.stop()` → 시계 10초 | 전송 0건 | N |
| AT-CD-08 | CD-02.AC-06, CD-03.AC-01·04(④) | 답 요청 카드 X 띠 → 5초 뒤 실제 전송, 가짜 문이 같은 `client_msg_id`의 사장 글을 돌려줌(접수). (a) 문 답 요청 목록이 아직 X를 포함한 채 30초 (b) 이어서 목록에서 X 빠짐 → 그 뒤 X가 목록에 다시 생김 (c) 별도 카드 Y: 접수 뒤 목록이 계속 Y를 포함한 채 75초 | (a) X 숨김, 추가 `send` 0건 (b) 빠진 뒤 X 없음, 다시 생기면 X 보임(띠 있음) (c) 접수 75초 뒤 Y 보임(띠 있음), 경고 없음, 추가 `send` 0건 | N |
| AT-CD-09a | CD-03.AC-02(①) | 연결 끊긴 뒤(가짜 문 닫음, `canSend`가 바로 false가 되지 않게 띠를 먼저 누르고 5초 안에 끊음) 5초가 지나 전송 | `sendText` 실패, 카드 즉시 다시 보임(띠는 연결이 없으니 없음), 경고 줄 `확인을 보내지 못했어요. 다시 해 주세요.`, `transferFailure` 설정, 추가 `send` 0건. 카드창 다시 열면 경고 없음 | N |
| AT-CD-09b | CD-03.AC-02(②) | 전송 성공(`true`) 직후 가짜 문이 `{"type":"error","ref":<그 client_msg_id>,"code":"journal_write_failed"}` | 그 프레임 처리 뒤 카드 다시 보임(띠 있음), 경고 줄 있음, 그 스레드 실패 초안 = "확인"(기존 경로), 추가 `send` 0건. 다음 띠 누름으로 경고 지워짐 | N |
| AT-CD-09c | CD-03.AC-02(②, 재연결) | 기록 모드. 전송이 쓰기 시작 뒤 오류로 미확정(③)이 된 상태에서 재연결 → `welcome` … `sync_done(more=false)`까지 그 `client_msg_id` 접수 없음 | `sync_done` 처리 뒤 카드 다시 보임(띠 있음), 경고 줄 있음, 추가 `send` 0건 | N |
| AT-CD-09d | CD-03.AC-03(③) | 기록 모드(`HistoryTransportHarness`처럼 가짜 문). 쓰기를 시작한 뒤 소켓 쓰기 오류(`GateFailure`가 아닌 오류)로 `transmit`이 `true`·`pending` 유지·`전송 결과를 확인하고 있어요.` 상태. (a) 74초 (b) 76초 (c) 이어서 영수증 `not_found` (d) 이어서 영수증 `accepted` | (a) 카드 숨김 (b) 카드 보임, 띠 없음, VoiceOver 동작 없음, 경고 없음 (c) 그대로 (d) ④로 바뀜: 목록에 남아 있으면 숨김. 전 과정 추가 `send` 0건 | N |
| AT-CD-10 | CD-02 경계(띠 밖) | 띠가 보이는 답 요청 카드에서 띠 왼쪽(x = 268−44−1)을 누름 | 지금처럼 `onCard` 1회, 전송 0건, 되돌리기 줄 없음 | N |
| AT-CD-11 | REQ-CD-04 | (a) 문: `gate/history_queries.py` `assess`에 가짜 줄 [직원 요청(reply_state=asked), 사장 일반 글 "확인"] → 그 뒤 [직원 글(final)] 추가 (b) 앱: `ThreadTools`의 같은 판정에 같은 줄 | (a)(b) 첫 단계: 사장 글이 마지막 → 문 notice 없음. 둘째 단계: settled=true. 문과 앱 결과가 같음 | 보존(기존 규칙) |
| AT-CD-12 | REQ-CD-05 | AT-CD-01의 카드들의 `accessibilityCustomActions` | 답 요청 = 이름 `확인 보내기` 1개, 참조 있는 마감 = `완료로 닫기` 1개, 나머지 없음. 동작 호출 = 띠 누름과 같은 결과(AT-CD-03·04 기대) | N |
| AT-CD-13 | NFR-CD-01 | 정적 검사: 앱 소스에서 되돌리기 대기 자리와 5초 타이머 판정을 찾음 | 대기 자리 하나, 5초 상수 `closeUndoSeconds` 한 곳, `deadline_close` 프레임 만드는 곳 한 곳. 새 프레임 종류 없음(`schemas/` 변경 없음), `gate/` 변경 없음. 근거 grep을 구현 보고에 붙임 | 해당 없음 |
| AT-CD-14 | NFR-CD-02 | `bash scripts/test.sh`(Hermes 시험 venv + 실행 workspace `PYTHONPATH`), `scan_private.py`(Hermes 실행 venv python), 기존 `TodoDrawerTests`·`DrawerHeaderTests` | 착수 커밋 대비 새 실패 없음, 개인값 검사 통과 | 착수 커밋 실패 목록 기록 |
| AT-CD-15 | 화면 확인(수동) | 시험 하네스로 답 요청·마감 카드를 마우스 올림 상태로 그려 PNG 저장(밝은·어두운 화면) | [시안 C](../../docs/changes/HEJO-CARD-DONE-20261126/mock-card-done.png)와 같은 모양: 오른쪽 끝 초록 띠, 흰 ✓, 제목과 겹치지 않음. 경로를 구현 보고에 적음 | 해당 없음 |

## 3판 추가(D-06·D-07)

| 시험 | AC | 입력·절차 | 기대값(출처: spec 3판 REQ-CD-06·07) | 기준본 기대 |
|---|---|---|---|---|
| AT-CD-16 | CD-06.AC-01·03, CD-01.AC-01(c) | 기록 모드 하네스(`HistoryAlertSeenHarness` 방식). 알림 카드 A(대화 키 K) 띠 표시 확인 → 띠 누름 → 요청 진행 중 한 번 더 누름 | 띠 있음, VoiceOver `읽음으로 표시` 1개. `notice` 읽음 요청 1건(대상 K), 대화 이동 없음, `send` 0건, 되돌리기 줄 없음. 성공 뒤 A 없음, 문 상태에 `bell:K`·`thread:K` = 그 스레드 originalMaxSeq | N |
| AT-CD-17 | CD-06.AC-02 | AT-CD-16과 같되 읽음 요청이 실패(문 오류) | 키 변화 없음, A 남음. 다시 누르면 요청 1건 더 | N |
| AT-CD-18 | CD-07.AC-01·02·03 | 기록 모드 하네스. 알림이 울리는 스레드 S에 대해 spec REQ-CD-07.AC-01 (a)~(e) 각 상태 × 직접 선택 입구(카드 클릭, 채팅 스레드 클릭, 카드 Enter). 입구를 부르는 자리는 실제 뷰·컨트롤러 경로 | 각 경우 `notice` 읽음 요청 1건(대상 S), 응답 뒤 카드 없음. (a)의 자동 선택 순간에는 요청 0건(누를 때만) | 기준본에서 먼저 실행. 실패한 경우를 `.build/card-done/at18-baseline.log`에 원인 후보와 함께 기록. 모두 통과면 제품 미수정·보고(AC-03) |
