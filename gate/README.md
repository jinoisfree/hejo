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
그래서 예약 보고마다 문이 새 UUID 스레드를 만든다. 대상 문법은 `hejo:<직원 id>`이며
`parse_target_ref_fn`·`validate_target_ref_fn`으로 경로 구분자 없는 프로필 id 문법을 검사한다.
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
