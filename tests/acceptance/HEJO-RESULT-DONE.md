# HEJO-RESULT-DONE 수락 시험

- 4판(spec 4판과 짝, 계획 검증 1회차 RD-01~04·2회차 RD-05·3회차 RD-06 반영) · 상태: 명세 확정 / 코드 미작성(구현 담당이 `gate/tests/test_result_done.py`, `app/Tests/ResultDoneTests.swift`로 옮김. 기대값 소유는 기획설계) / 실행: 미실행 / 독립 검토: 계획 검증 4회차 APPROVED
- 가짜 명부(`alpha`)·가짜 글만 쓴다. 글 만들기는 `gate/tests/test_history_queries.py`의 `post`·`make_context` 방식과 같다. 버튼은 `{'id':…, 'label':…, 'kind':'reply', 'style':'default'}`.
- 기준본 실행은 두 부분으로 나눈다. **(가) 판정 부분**은 `assess` 세 반환값, `notice`, `bell`, `questions()`, `waitingButtonCount`이며 기준본에서도 실행한다. **(나) 새 필드 부분**은 `waitingButtonIDs`와 앱 버튼 그리기다. 기준본에는 이 필드가 없어서 실행하지 않는다. 기준본 기대 열은 (가)에만 적용한다. "기준본 기대: 통과" 행이 (가)에서 실패하면 멈추고 보고한다. "실패" 행이 (가)에서 통과해도 멈추고 보고한다. 기대값 출처는 spec 3절과 기준 커밋 `63e7bf9`의 동작이다.
- 시험 명령: Hermes venv 파이썬으로 `HEJO_PYTHON=<venv python> bash scripts/test.sh`(시스템 python3로는 실패함).

약어: Q = 직원 `asked`+[승인, 거절], R = 직원 `asked`+[확인, 되돌리기](결과 알림), O = 사장 일반 글(`answer_to` 없음), E = 버튼·상태 없는 직원 글.

| 시험 | AC | 입력 | 기대값 | 기준본 기대 |
|---|---|---|---|---|
| AT-RD-01 | AC-01 | Q(1) → O(2) → R(3) | `assess`: `requestID`=R, `pendingID`=null, `settled`=true, `working`=false, `approved`=false. `summary`: `notice`=null, `bell`=null, `waitingButtonIDs`=[R], `waitingButtonCount`=1. `HistoryQueries.notices([summary])`=[] | (가) 실패(`pendingID`=R) / (나) 미실행 |
| AT-RD-01b | AC-01·04 | AT-RD-01과 같은데 R의 라벨이 (a) `:white_check_mark: 확인`, `되돌리기` (b) `확인`, ` 되돌리기 ` | (가) 결과 알림이 아니다: `assess` 세 반환값·`notice`·`bell`·`waitingButtonCount`가 기준 커밋과 같다(`pendingID`=R, 질문 `notice`=R). (나) `waitingButtonIDs`=[R]. 앱(AT-RD-08 하네스)에서는 띠 빨강이고 R의 되돌리기 보기는 기존 규칙대로 `isEnabled`=false다. 문 판정과 앱 누름 규칙이 같은 입력에서 어긋나지 않는다 | (가) 통과 / (나) 미실행 |
| AT-RD-01c | AC-01·04 | AT-RD-01과 같은데 R의 버튼 순서가 [`되돌리기`, `확인`](역순), 본문에 "앱 쓰기 결과" 없음 | (가) 결과 알림이 아니다: `assess` 세 반환값·`notice`·`bell`·`waitingButtonCount`가 기준 커밋과 같다(`pendingID`=R, 질문 `notice`=R). (나) `waitingButtonIDs`=[R]. 앱(AT-RD-08 하네스)에서 띠는 빨강이고, R의 되돌리기 보기는 기존 규칙대로 `isEnabled`=false다 | (가) 통과 / (나) 미실행 |
| AT-RD-02 | AC-02 | R(1) 하나, `now` = R 시각 + 60초 | `pendingID`=null, `settled`=true, `requestID`=R, `notice`=null, `waitingButtonIDs`=[R] | (가) 실패 / (나) 미실행 |
| AT-RD-03 | AC-03 | Q(1) → R(2) | `pendingID`=Q, 질문 `notice`(id=Q, `questions`=true) 있음, `waitingButtonIDs`=[Q, R] | (가) 실패(`pendingID`=R) / (나) 미실행 |
| AT-RD-04 | AC-04 | 각각: (a) 직원 `asked`+[확인] (b) `asked`+[확인, 되돌리기, 수정] (c) Q (d) `asked`·버튼 없음 (e) 상태·버튼 없이 "승인해 줘" (f) Q(1) → O(2) → E(3) | (가) `assess` 세 반환값과 `notice`·`waitingButtonCount`가 기준 커밋과 같다. (a)~(e)는 `pendingID`=그 글, (f)는 `settled`=true. (나) `waitingButtonIDs`: (a)(b)(c)(d)(e)는 [그 글], (f)는 []. (d)(e)도 기준 `waiting` 규칙(2개 미만이면 `{pendingID}`)을 따른다 | (가) 통과 / (나) 미실행 |
| AT-RD-05 | AC-05 | (a) Q(1) → O(2) → R(3) → 사장 "되돌리기"(4, `answer_to`=R) (b) (a) 뒤 E(5) | (가) (a)(b) 모두 `pendingID`=null이고 `working`·`settled`·`approved`·`notice`·`waitingButtonCount`(0)가 기준 커밋과 같다. (b)는 `settled`=true. (나) (a)(b) 모두 `waitingButtonIDs`=[] | (가) 통과 / (나) 미실행 |
| AT-RD-06 | AC-06 | 방 `alpha`에 스레드 둘: 하나는 AT-RD-01, 하나는 Q 하나 | `questions()` 결과 id 집합 = {첫 스레드 Q(1), 둘째 스레드 Q}. 첫 스레드 Q(1)는 기준처럼 남는다(`asked`이고 `confirm:` 없음). R은 없다 | (가) 실패(R 포함) |
| AT-RD-07 | AC-07·08 | AT-RD-01·03·04(c) 요약 세 개와, 같은 요약에서 `waitingButtonIDs`를 지운 사본 | 여섯 개 모두 `schemas/hejo-history-v1.json` `$defs.summary` 검사 통과(`Draft202012Validator`). 필드 값 순서는 seq 오름차순 | (나) 미실행(기준 스키마는 필드 거부) |
| AT-RD-08 | AC-09 | 앱 시험(기록 모드 하네스, 연결된 가짜 문): AT-RD-01 요약(`waitingButtonIDs`=[R])과 글 3개. R 버튼 라벨은 실제와 같은 `확인`·`되돌리기`이고 본문에 "앱 쓰기 결과" 문구가 없다 | `assessment(key).buttons`=[R], 색=`#2EB67D`, `pendingID`=nil. R 아래 버튼 보기 2개(확인·되돌리기)가 있고 둘 다 `isEnabled`=true. Q 아래 버튼 보기는 0개다. 되돌리기 보기를 실제 누름 경로(보기의 `invoke`)로 누르면 가짜 문이 받은 프레임이 `type=click`, `msg_id`=R, `button_id`=R의 되돌리기 버튼 id로 정확히 1건이고 `send`는 0건이다 | (나) 미실행 |
| AT-RD-08b | AC-03·09 | 앱 시험(같은 하네스): AT-RD-03 요약(`pendingID`=Q, 질문 `notice`=Q, `waitingButtonIDs`=[Q, R]). Q 버튼은 [승인, 거절], R 버튼은 [확인, 되돌리기] | 띠 색=빨강(`pendingID`=Q). 가운데 칸 답 요청 카드가 1장이고 `messageID`=Q다. Q 아래 승인·거절 보기와 R 아래 확인·되돌리기 보기가 모두 `isEnabled`=true다. R의 되돌리기를 누르면 `click` 1건(`msg_id`=R, `button_id`=R의 되돌리기 id)이 가고, Q의 거절을 누르면 `click` 1건(`msg_id`=Q, `button_id`=Q의 거절 id)이 간다. 두 프레임이 서로 섞이지 않는다 | (나) 미실행 |
| AT-RD-09 | AC-10 | 앱 시험: `waitingButtonIDs` 없는 요약 JSON | 해석 성공, `assessment(key).buttons` 빈 집합, 버튼 보기 0 | 통과 |
| AT-RD-10 | AC-10 | 정적: `HistoryThreadSummary`에 `init(from:)` 사용자 정의가 없음(0.2.9와 새 앱 모두) | grep 결과 0줄 | 통과 |
| AT-RD-11 | AC-11 | 운영 문 줄 후보와 공개판 후보의 `git diff <각 기준> -- gate/history_queries.py schemas/hejo-history-v1.json` | 두 diff의 변경 줄(+/−)이 같음. 다르면 그 줄과 이유를 보고 | 해당 없음 |
| AT-RD-12 | AC-12 | 서버 기록장을 0700 임시 폴더에 읽기 사본으로 복사 → 기준 커밋과 후보 커밋의 `HistoryQueries`로 전체 스레드 요약 비교 | 대응표의 실제 스레드: `settled`=true, `pendingID`=null, `notice`=null, `waitingButtonIDs`=[그 결과 알림]. 바뀐 스레드 목록 전부 결과 알림이 들어 있는 스레드임. 임시 폴더는 판정 뒤 삭제 | 해당 없음 |
| AT-RD-13 | AC-13 | 운영 적용(handoff 5단계) | 링크 RELEASE = 후보, 재시작 1회. 플랫폼별 연결 줄 수(hejo·Slack·photon 등)가 적용 전과 **모두 같다**. 늘거나 줄면 실패다. 기준 밖 새 오류 줄 0. 실패하면 spec 5.3 롤백 | 해당 없음 |
| AT-RD-14 | AC-14 | 사장이 앱에서 그 스레드를 봄 | 초록, 빨간 띠 없음, 답 요청 카드 없음(0.2.9). 새 앱에서는 확인·되돌리기 버튼 보임 | 해당 없음(사장 관측) |
| AT-RD-15 | AC-15 | `bash app/scripts/build.sh`, `tests/acceptance/test_ship.py` | 빌드 종료 0, `CFBundleShortVersionString`=0.2.10, `CFBundleVersion`=12, 시험 통과 | 해당 없음 |


**실행 증거(RD-02):** 앱 시험은 `app/scripts/test.sh`가 부르는 실행 진입점(가짜 문 fixture 스크립트 + `app-tests` 모드)으로 실제로 실행한다. 시험마다 `AT-RD-08 PASS`·`AT-RD-08b PASS`·`AT-RD-09 PASS`·`AT-RD-10 PASS` 줄을 출력한다. 구현 보고에는 그 줄이 들어 있는 로그 `.build/result-done/app-tests.log`와 문 pytest 로그 `.build/result-done/gate-tests.log`(시험 함수 이름에 AT-RD 번호 포함, `-v` 출력)를 붙인다. 컴파일 성공만으로는 통과로 보지 않는다.