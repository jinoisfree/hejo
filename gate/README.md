# hejo 문

Hermes 플랫폼 플러그인. 시설 코드는 이 폴더, 프레임 계약 원본은
[hejo-wire-v1.json](../schemas/hejo-wire-v1.json), 권한·기록장 계약은
[승인 설계](../docs/changes/HEJO-FOUNDATION-20261114/design.md)를 따른다.
운영 설치는 TASK-07·09에서 한다.

Hermes Python 환경에서 저장소를 현재 폴더로 두고 실행한다.

```sh
python -m gate.cli pair
python -m gate.cli devices
python -m gate.cli revoke DEVICE_ID
python -m gate.cli status
python -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
  tests/acceptance/test_gate_extensions.py tests/acceptance/test_gate_delivery.py -q
```

`HERMES_HOME`은 Hermes의 홈 해석을 따른다. `pair`는 일회용 코드만 터미널에 출력한다.
`status`는 저장된 기기 개수와 취소 여부 요약이며 리스너 생존을 보증하지 않는다.
인증 파일은 홈의 `hejo/`에 잠금·원자적 교체로 저장한다. 인증 원문은 저장·로깅하지 않는다.

기본 프로필만 리스너·기록장·출입증 파일을 연다. `extra.listen`, `extra.port`,
`extra.allowed_users`를 읽으며 허용 사용자는 기존 YAML 브리지로 Hermes 권한 검사에 전달한다.
허용 사용자 값은 config에만 두고 `.env`를 설정하거나 열지 않는다.
보조 프로필은 `set_owner_profile`로 식별하며 `extra.role: forwarder`로 설치한다.
시작 순서와 무관하게 연결됨으로 표시하고, 송신마다 모듈 허브의 현재 기본 문을 찾는다.
기본 문이 없으면 `hejo_primary_unavailable` 실패와 로그로 끝난다.
전달자의 직원 신원은 `_owner_profile`로 고정되어 호출자의 chat_id·메타로 바뀌지 않는다.

예약 기본 대상은 각 프로필의 `platforms.hejo.home_channel`에
`{platform: hejo, chat_id: <그 직원 id>}`로 둔다. 스레드 값은 넣지 않는다.
그래서 예약 보고마다 문이 새 UUID 스레드를 만든다. 대상 문법은 `hejo:<직원 id>` 또는 `hejo:room:<방 UUID>`이며
`parse_target_ref_fn`·`validate_target_ref_fn`으로 프로필 id와 방 UUID 문법을 검사한다.
방 글에 직원 표시가 없으면 기본 프로필 자신이 글쓴이다. 방 대표로 대체하지 않으며
구성원이 아니면 `room_member_required`로 거절한다. 파일·그림과 입력 중 표시도 같은 작성자 계산을 쓴다.
방에서 사장 글을 받을 직원은 멘션, 스레드 주인, 대표 순으로 정한다. 스레드 주인은
첫 직원 글의 작성자 또는 첫 사장 글의 수신자이며 현재 구성원·명부에 남은 직원만 선택한다.
다른 직원을 부른 글 뒤에도 주인은 유지된다. 1:1과 직접 고른 수신자는 기존 규칙을 따른다.
등록의 `cron_deliver_env_var="HEJO_DELIVERY_TARGET"`는 Hermes가 예약 플랫폼을 인식하는
공개 등록 키다. 본 플러그인은 해당 환경 값을 만들거나 읽지 않고 config의 home_channel을 쓴다.
별도 단독 발신자나 다른 플랫폼으로의 대체 송신은 없다.

team-kit 확장은 `send(..., metadata=...)`,
`edit_message(..., *, finalize=False, metadata=None)`,
`await set_reply_state(msg_id, state)`, `register_click_handler("reply", handler)`를 사용한다.
`set_reply_state`는 fsync 완료 뒤 반환하고 기록 실패에는 `HejoJournalError`를 던진다.
버튼 해석 자료는 내부 메타에만 보관한다. Hermes 기본 승인·질문·슬래시 확인은 공개
resolver로 넘기며 만료되면 `button_expired`다. 답장 버튼 메타가 없는 글의 `[[버튼: A | B]]`는
`A / B`로 표시한다. Slack과 hejo 대화를 동기화하지 않는다.

첨부 POST는 Bearer 출입증과 `employee` 쿼리, multipart의 단일 `file` 필드를 받는다.
파일 이름은 1~255자이며 점 경로·구분자·NUL을 거부하고, 데이터는 50 MiB까지다.
응답은 `{file_id, name, mime, size}`다. MIME은 검증된 이름의 확장자에서 판단하며
알 수 없는 형식은 `application/octet-stream`이다. 대기 칸은 재시작 뒤에도 남는다.
사장 글의 files id를 모두 확인한 뒤 이동하고, 그 message 행 메타에 소유를 등록한다.
없거나 다른 직원의 id는 `unknown_file`이며 아무 글·차례도 생성하지 않는다.
기록 실패 시 파일 이동을 되돌린다. 직원 파일·로컬 이미지는 동일한 저장·등록 경로를 쓴다.
다운로드는 등록된 직원과 id가 일치해야 하며, 대기 칸·경로 탈출·심볼릭 링크는 내주지 않는다.
시작·하루 한 번 24시간 넘은 대기 항목과 미등록 목적지 항목을 정리한다.
1단계 근간의 직원 avatar는 null이고 사진 HTTP는 항상 404다.

AT-HF-22의 실행기는 `gate.tests.gateway_delivery`다. 기존 탐침을 제거하고 실제 제품 플러그인을
임시 홈의 실제 게이트웨이에 등록한다. HOME과 HERMES_HOME을 서로 다른 임시 경로로 두어
Hermes의 운영 DB 보호 검사를 유지한다. 실제 Slack·모델·예약 시간 트리거는 실행하지 않는다.
Unix 소켓용 짧은 임시 위치는 `HEJO_GATE_TEST_TMPDIR`로 지정할 수 있다.
Hermes 게이트웨이 의존성 및 소켓 관측용 psutil이 필요하고 자동 설치는 끈다.

```sh
HERMES_DISABLE_LAZY_INSTALLS=1 python -m gate.tests.gateway_delivery
```

스레드 제어는 인증된 같은 WS 연결의 `thread_delete`·`thread_branch`로 요청한다.
삭제는 기존 delete 기록의 scope로 확정하고, 재전송은 같은 seq의 delete로 치환한다.
분기는 문이 새 스레드를 만들며 첫 사장 글에만 이전 대화 문맥을 붙인다.
Hermes `/branch`나 세션 DB를 우회하지 않으므로 도구 호출 기록·`/resume` 계보는 복제하지 않는다.
`metadata.hejo_checklist`는 message/edit의 선택 checklist 필드로 전달한다.
정확한 필드와 한도는 [통신 규격](../schemas/hejo-wire-v1.json)을 따른다.

`deadlines`는 team-kit의 `hermes-deadlines list --json`을 읽기 전용으로 실행하며, 문 전체의 진행 중 실행 하나를 공유한다.

서버 안 전용 전송은 기본 프로필 문이 여는 `<HOME>/hejo/post.sock`의 HTTP JSON을 쓴다.
같은 공항의 team-kit·보고·감시 프로그램이 사용하는 입구이며 TCP에는 등록하지 않는다.
소켓 권한은 0600이다. 사장 글·임의 메타를 받지 않고, 직원 글의 작성자와 방 구성원 자격을
검사하며 고치기·지우기는 작성자만 할 수 있다.

주소는 메시지·스레드·방의 세 자원으로 나뉜다. 정확한 요청·응답 필드, 한도와 중복·충돌
규칙의 원본은 [hejo-local-v1.json](../schemas/hejo-local-v1.json)의 `x-routes`·`x-semantics`다.

| 자원 | HTTP 주소 |
|---|---|
| 메시지 | `POST /local/v1/messages`, `PATCH`·`DELETE /local/v1/messages/{msg_id}` |
| 스레드 읽기 | `GET /local/v1/threads/{thread}` |
| 방 만들기·재사용 | `POST /local/v1/rooms` |

스레드 읽기는 `employee`와 `room` 중 하나만 지정한다. 요청·권한·방 충돌의 거절은 4xx,
기록 실패는 `503 journal_write_failed`다. 거절을 성공으로 간주해 다음 처리를 진행하지 않는다.
`client_id`는 직원별 요청 열쇠로 기록장 내부 메타에 남는다. 같은 열쇠의 재전송은 원래 글과
스레드를 반환하고 삭제된 글을 되살리지 않는다. 긴 글의 분할과 조각별 열쇠·재시도 상태는
호출자가 보존한다. 별도 중복 장부를 두지 않는다.

입구 시험을 포함한 전체 pytest에는 짧은 임시 기본 경로를 지정한다(예: `PYTEST_ADDOPTS`의 `--basetemp`).

## Telegram 게시물별 댓글

사람별 비공개 채널과 연결된 일반 토론 그룹을 사용하면 질문은 채널 게시물로,
답변과 후속 대화는 그 게시물의 댓글로 묶인다. hejo 앱 변경은 필요 없다.
실제 사용 전에는 별도 운영 인계와 승인을 거쳐 한 방에서 실물 수락을 마쳐야 한다.
자동 시험 통과만으로 운영 적용하지 않는다.

**전체 끄기와 댓글 연결 해제는 다르다.** 앱의 Telegram 끄기는 모든 Telegram
입력·발신을 멈추지만 연결과 외부 채팅 예약은 유지한다. 끄기 중 글과 취소된
대기 조각은 다시 켜도 재발신하지 않는다. 정상 `off`와 복구용 `abort`는 기존
채널·토론 그룹을 **영구 은퇴**시키고 해당 방을 기존 포럼 토픽으로 돌린다.
다시 댓글 방식을 쓰려면 새 채널·그룹 쌍을 준비해야 한다. 짝을 바꿔도 은퇴한
쌍을 다시 등록할 수 없으며 예약 해제 명령은 없다. 과거 게시물·댓글과 hejo
대화 원본은 삭제하지 않고 조회용으로 남긴다.

- 기존 짝 그룹의 개인 소유자 계정에서 `/hejo_comments_rooms`로 방 키를 확인한다.
- 채널과 토론 그룹은 비공개이며 서로 연결돼 있어야 한다. 토론 그룹은 forum이
  아닌 supergroup이어야 하고 관리자는 짝 소유자와 동일 봇만 있어야 한다.
  소유자는 creator, 봇은 양쪽 관리자이며 채널 게시 권한이 필요하다.
- 익명 관리자·채널 명의가 아닌 기존 짝 개인 계정으로 토론 그룹에서
  `/hejo_comments_probe <room>`을 보낸다. 실행 봇과 시험 발신은 먼저 승인받는다.
  이 명령은 직원 실행 없이 시험 게시물과 댓글의 실제 전달을 확인한다.
- 같은 대상의 완료된 시험 및 사람 화면 확인 뒤 별도 승인 범위에서
  `/hejo_comments_bind <room>`으로 연결한다. 실행·수신·발신 중이면 busy다.
  예약 기간이나 전환 전 글을 소급 실행하지 않는다.
- 개인 계정의 댓글은 이미 대응된 원문·답변·첨부에 대한 답장이어야 한다.
  단일 사진 또는 문서를 보낼 수 있으며 다운로드 한도는 20MB다.
  앨범·미지원 미디어는 캡션만 실행하지 않는다.
- `/hejo_comments_status`는 기존 짝 그룹 또는 등록 그룹의 소유자에게 연결과
  발신 operation 상태를 보여 준다. `queued`는 아직 발신하지 않은 조각,
  `intent`는 진행 중 의도, `receipt`는 성공 응답 기록이다. 재시작 때 미완료
  intent는 `unknown`으로 표시한다. receipt 원문에 댓글 닻이 없으면
  `waiting_anchor`로 표시하며 정상 off는 busy다. 불확실한 발신은 자동 재시도하지 않는다.
- 원격 글이 실제로 존재하면 등록 그룹에서 그 자동 전달 원문 또는 봇 댓글에
  답장하여 `/hejo_comments_resolve <operation>`을 보낸다. 대상·세대와 원문 조각을
  대조해 대응만 복구한다. 원본 조각이 바뀌었으면 복구를 거부한다. 원격 글이
  없을 때 재발신하는 명령은 제공하지 않는다.
- 정상 종료는 등록 그룹에서 `/hejo_comments_off <room>`이다. 불확실 전송이나
  대기 조각이 남으면 busy다. 복구할 글을 찾을 수 없으면 기존 짝 그룹에서
  `/hejo_comments_abort <room>`을 명시한다. 살아 있는 호출·직원 차례가 끝난 뒤
  미전송 항목을 취소하고 영구 은퇴한다. 취소 글을 토픽으로 옮겨 재발신하지 않는다.

전환 전 스레드를 새 글로 이어 쓰면 현재 목적지에
`이전 대화 이어쓰기 — 전환 이후 내용` 표시가 붙은 새 묶음을 만든다.
과거 본문·첨부는 복사하지 않는다. 이미 있는 닻이 삭제되면 새 묶음이나 일반
그룹 글로 우회하지 않는다. 권한 검증 실패는 댓글 연결을 일시 정지하며
토픽으로 자동 대체하지 않는다. 앱의 기존 연결 문제 표시로도 이 상태를 알린다.

외부 식별자는 기존 금고, 대응과 조각별 intent/receipt는 기존 `sent.jsonl`,
대화 본문은 기존 journal이 소유한다. 대응 파일에는 본문·파일 내용·실제 chat id를
저장하지 않는다. 중복 수신은 기록 전에 차단하지만 journal commit 뒤 직원
실행 도중 중단된 차례의 자동 재개나 전체 exactly-once 실행을 보장하지 않는다.
