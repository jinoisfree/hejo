# TASK-03a 탐침

[설계 4.1](../../docs/changes/HEJO-FOUNDATION-20261114/design.md)의 A/B 비교 전용이다.
운영 플러그인은 이 패키지를 import하지 않는다. 계획 담당이 결정한 뒤 TASK-03b에서
제거하거나 승인된 부분만 승격한다. 수락 시험이나 제품 구현이 아니다.

- A: 두 프로필에 hejo를 켠다. 보조 어댑터는 포트를 열지 않고 같은 프로세스의 기본 문에 `send`를 넘긴다.
- B: 기본 프로필에만 hejo를 켠다. 보조 프로필에는 명시적으로 `enabled: false`를 쓴다.
  단독 발신자를 등록하되 실제 `send_message`·예약 배달 진입점의 설정 검사를 유지한다.
- 두 프로필 모두 `probe_peer`라는 별도 시험 연결을 가진다. 자격 문자열은 가짜이며,
  이 어댑터는 외부 통신을 구현하지 않는다. 실제 Slack의 무영향 시험을 대신하지 않는다.

Hermes 소스와 그 시험용 Python을 각각 `HERMES_SOURCE`, `HERMES_PYTHON`에 지정한다.
필요한 의존성은 aiohttp, jsonschema, pytest/pytest-asyncio 및 Hermes 게이트웨이의 의존성,
소켓 관측용 psutil이다. 저장소의 무시된 시험 의존성 폴더를 쓸 수 있다.
`HEJO_PROBE_TMPDIR`에는 Unix 소켓 경로 길이를 넘지 않는 짧은 임시 폴더를 지정한다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
"$HERMES_PYTHON" -m gate.probes.run --mode A
"$HERMES_PYTHON" -m gate.probes.run --mode B
```

상위 러너는 새 임시 HOME·HERMES_HOME·상태/잠금 경로와 정리된 환경으로 자식을 만든다.
자식은 실제 `gateway.run.start_gateway()`를 실행한다. 시작·종료·중복 자격 검사·
프로필별 어댑터 선택·`send_message_tool`·예약 결과 배달은 실제 Hermes 코드다.
원본을 호출하는 감시 함수로 중복 검사 결과와 시작 완료 경계를 관측한다.
예약은 실제 타이머의 다음 주기를 기다리지 않고 `_deliver_result`에 고정 결과를 넘긴다.
모델 실행·예약 생성·시간 트리거·프로세스 밖 단독 발신자는 검증하지 않는다.

리스너 수는 해당 프로세스의 실제 TCP LISTEN 소켓으로 확인한다. 시험 클라이언트는
실제 WebSocket에 페어링하고, 받은 프레임을 기록장 JSONL 파일과 대조한다.
별도 연결의 어댑터 동일성·hejo 배달 중 무송신·대조 송신을 확인한다.
외부 소켓/DNS, 임시 홈 밖의 비밀 파일 읽기와 파일/DB 쓰기는 감사 훅에서 거부한다.
Hermes의 자동 설치는 꺼 둔다. 종료 시 실제 게이트웨이를 정지하고 임시 홈을 제거한다.

`PROBE_RESULT`는 관측 결과이며 `GATEWAY_EXIT clean`은 정상 정리 표시다.
B의 설정 차단을 재현해도 탐침 자체는 종료 0이다. 이는 B의 배달 성공을 뜻하지 않는다.
로그에는 임시 홈 경로가 들어가므로 로컬 `.build/`에 보관한다.
