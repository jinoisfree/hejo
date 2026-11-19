# 구현 인계: HEJO-FOUNDATION TASK-02

1. **받은 설계**: [handoff.md](handoff.md), 기준 커밋 `48e03cb5b0b277867c38abb93ddf3b01838d79bf`. 연합개발의 구현·자체 시험 역할, 고위험, 필요 증거 수준 2. 착수 당시 HEAD와 기준 커밋이 같았고 작업 트리는 깨끗했다. 실제 import한 Hermes 소스 HEAD는 `ebb026eef8e800e1b7471ed147b7287e878f8aa4`로 설계 근거와 같다.
2. **구현자 판단 상태**: **부분 구현 / 파일 항목 계약은 보류(20-implementation 2절 보고)**. 아래 GAP-T02-01 결정이 필요하다. 수락 시험 통과를 TASK-02 전체 완료나 독립 검토 완료로 판정하지 않는다.
3. **변경 후 구조**: `server`가 주소·프레임·인증·연결별 재전송을, `adapter`가 실제 Hermes `build_source` → `handle_message`와 송신·확장 훅을 맡는다. 송신 기록은 `journal`의 JSONL 추가·fsync 완료 후에만 연결로 보낸다. `auth`는 CLI와 게이트웨이가 같은 파일 잠금으로 발급·취소 상태를 공유하며, `roster`는 실제 `profiles_to_serve` 및 선택적 team-kit 명부를 읽는다.
4. **더한 것 / 뺀 것**:
   - `schemas/hejo-wire-v1.json`: design 2절 프레임 종류, 송수신 구분, 버튼·직원·스레드·순번, 2.1 한도와 적용 규칙, 2.2 훅 metadata. `message.files` 항목 모양은 미확정 표시만 두었다.
   - `gate/{plugin.yaml,__init__.py,adapter.py,server.py,auth.py,journal.py,roster.py,cli.py,README.md}`: 새 플러그인·게이트웨이·CLI. 2.2 훅은 별도 hooks 파일 없이 어댑터의 공개 메서드에 둔다(인계서가 허용한 배치).
   - `gate/tests/`: 대역 러너와 고장·계약 시험. `tests/acceptance/{conftest.py,test_gate_foundation.py}`: 지정된 수락 시험 코드화.
   - 삭제·교체한 기존 경로 없음. 앱·다른 저장소·Hermes 본체 소스·운영 설정은 수정하지 않았다. 운영 연결·재시작·실제 메시지 발송은 실행하지 않았다.
5. **설계와 달라진 점**: GAP-T02-01을 확정하지 않은 점 외에 승인된 구조·수락 기대값 변경 없음. `spec.md`, `design.md`, `tasks.md`, `handoff.md`, 기존 수락 시험 명세는 수정하지 않았다. 임시 홈에서는 첨부 id 수신을 명시적 오류로 거부하며 첨부 HTTP는 열지 않는다(TASK-03b 범위).
6. **경계 계층과 임시 코드**: Hermes의 플랫폼 어댑터는 외부 인터페이스 변환 경계, `Connection`은 기기별 재전송 상태, `BoundedWebSocket`은 프레임 조립 중 크기 제한 및 오류 후 닫기를 맡는다. 별도 원본·전달자·이중 경로·탐침 코드는 없다. `.build/task02-deps`는 본체 venv를 수정하지 않기 위한 로컬 시험 의존성이고 추적하지 않는다. `$defs.file`의 미확정 표시 제거 조건은 GAP-T02-01 결정과 구현이다.
7. **변경 성격**: 신규 기능(의미 추가). 이전 제품 코드가 없어 동작 보존 비교 대상은 없다. 기존 Slack·ddots 경로를 수정하거나 대체하지 않는다. 롤백은 이번 저장소의 TASK-02 변경을 되돌리는 것으로 한정되며 운영 롤백은 필요하지 않다.
8. **시험 보호 계약**:

   | 시험 | 보호 계약 |
   |---|---|
   | AT-HF-01·02 | 설정된 루프백 소켓만 LISTEN, 보조 프로필은 포트 미점유·재시도 불가. AT-02는 실제 `GatewayAdapterLifecycleMixin`의 시작·실행 중 재연결 예약이 없음을 추가 확인 |
   | AT-HF-03~07 | 별도 CLI 발급·취소, 256비트 출입증, 코드 재사용·만료·5회 잠금, 2초 내 연결 닫힘, 허용 주소, 평문 미저장·0600 |
   | AT-HF-08·09 | 실제 프로필 집합과 실제 선택적 team-kit 명부, welcome/roster 응답 일치, `create_profile` 후 목록 갱신 |
   | AT-HF-10~12·37 | 실제 Hermes 이벤트·세션 키·허용 사용자 브리지·권한 검사, 스레드 분리, 작성 중과 최종 스트리밍 수정 |
   | AT-HF-13·14·32~36 | 끊김 후 재전송, 쓰기 실패 무송신·길이 복원, 500개 페이지, 재전송 중 새 기록, 두 기기 순서, 꼬리·월 복구, 별도 프로세스 flock 거부 |
   | `gate/tests/test_boundaries.py` | 스키마 필수 종류·불량 입력, 포트 충돌, fsync·ftruncate·open 실패, 순번 중복·역순 거부, 재시작 후 훅·버튼 복원, 상태 기록 완료·실패, 프레임 크기·hello 기한, 대기열 상한, 인증 파일 읽기 실패 시 닫기, env 우선순위, 독립 홈 보조 어댑터 미점유 |

   수락 명세의 입력·기대값·합격 기준은 유지했다. 실제 기본 어댑터가 자동 생성하는 작성 중 프레임은 메시지 수신 시험에서 별도로 소비한다. skip·xfail·허용 오차 확대 없음. 삭제·통합한 시험 없음.

   Mutation check: 주소 허용 검사, 커밋 fsync, 보조 프로필 차단, 취소 반영을 하나씩 끈 변형에서 해당 시험이 각각 종료 1로 실패했다. 러너는 종료 1 및 FAILED(수집 ERROR 없음)를 확인하고 원본 바이트를 복원했다. 전체 조정 실행 종료 0. 로그 `.build/task02-mutations.log`, 세부 로그 `.build/task02-mutation-{peer_policy,durable_commit,secondary_guard,revocation}.log`. 이 변형 러너는 로컬 증거이며 제품에 포함하지 않는다.
9. **실행한 검증 / 도달 증거 수준**: **수준 2 도달**. 매 시험 임시 `HERMES_HOME`, 가짜 명부·프로필만 사용했다. 실제 Hermes `PluginContext`·`PluginManager`·`BasePlatformAdapter`·`MessageEvent`·`GatewayAuthorizationMixin`·`GatewayAdapterLifecycleMixin`·프로필 API·YAML 브리지를 import했다. 대역은 직원 차례 처리만 대체하며 주소·인증·기록장·소켓·세션 키·권한 검사는 실제 경로다. 팀 명부 시험도 실제 `hermes_facility.team_registry`를 사용했다. 다른 에이전트를 실행하지 않았다.

   Hermes venv에는 pytest/aiohttp/jsonschema 등이 없었다. 시스템 pip의 `--target .build/task02-deps`로 pytest, pytest-asyncio, aiohttp, jsonschema, ruamel.yaml, python-dotenv, rich, pydantic, pyyaml, requests, httpx, packaging을 설치했고 종료 0이었다. Hermes venv 자체와 의존성 파일은 수정하지 않았다.

   재현 명령의 `HERMES_PYTHON`, `HERMES_SOURCE`, `HEJO_TEAM_KIT_LIB`는 각각 검사에 사용할 Hermes venv 실행 파일, 해당 소스 루트, team-kit `lib`를 가리킨다. 아래 명령의 작업 폴더는 이 저장소 루트다. 운영 홈을 시험 홈으로 지정하지 않는다.

   ```sh
   HERMES_HOME="$(mktemp -d)" \
   PYTHONPATH="$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD" \
   "$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
     -q -o asyncio_default_fixture_loop_scope=function
   ```

   | 검사 | 실제 결과 | 로그(저장소 기준, 로컬 파일) |
   |---|---|---|
   | 위 pytest 전체 | 종료 0, **38 passed**(지정 수락 22 경우 + 추가 경계 16 경우) | `.build/task02-final-pytest.log` |
   | 같은 환경에서 AT-HF-02 단독(`::test_at_hf_02`) | 전체 실행 뒤 재연결 예약 검증을 추가, 종료 0, **1 passed** | `.build/task02-reconnect-contract.log` |
   | 같은 환경에서 로컬 mutation 러너 | 종료 0, 네 변형 각각 예상 종료 1 검출·원복 | `.build/task02-mutations.log` 및 위 세부 로그 |
   | `python3 scripts/scan_private.py` | **실행 불가, 종료 2**. TASK-07에서 생성할 파일이 아직 없음 | `.build/task02-scan-private.log` |
   | 변경 소스·계약·시험 15파일 보조 정규식 검사 | 종료 0, 사용자·볼륨·홈 절대 경로, 이메일, Slack ID 모양 **0건**. 명부·금고 기반 필수 검사 대체 아님 | `.build/task02-public-patterns.log` |
   | Python AST 구문 검사 | 종료 0, Python 소스 12파일 해석 성공 | `.build/task02-syntax.log` |
   | `git diff --cached --check` | 종료 0, 이번 추가 파일의 공백 오류 없음 | `.build/task02-diff-check.log` |
   | 기준 커밋과 승인 문서 6개 `git diff --exit-code` | 종료 0, 근간·spec·design·tasks·handoff·수락 명세 변경 없음 | `.build/task02-spec-preserved.log` |

   초기 시험 실패의 로그는 `.build/task02-{first,second,third,boundaries,boundaries2}.log`에 남겼다(각 종료 1). 시험 하네스의 자동 typing 소비, roster 수신 대상, 자식 프로세스 플러그인 등록, 홈 변경 API, 초과 프레임 송신 중 연결 종료를 정리했다. 이후 `.build/task02-fourth.log`(수락 22개), `.build/task02-boundaries3.log`(33개), `.build/task02-selftest.log`(36개)는 각각 종료 0이다. 최종 전체 로그와 AT-02 추가 로그가 현 변경본의 근거다.
10. **미검증 범위와 남은 위험**:
    - GAP-T02-01로 완전한 첨부 항목 스키마가 없다. 현재 시험은 `files: []`이며 첨부 계약 완료를 주장하지 않는다.
    - 필수 개인값 검사기 미생성: 명부·금고 단어 검사는 미실행. TASK-07 구현 후 적용해야 한다.
    - 실제 게이트웨이 러너·모델 차례·멀티플렉스 운영·Tailscale 실접속(수준 3/4), 실제 노트북·Slack 병행·지연, 설치·제거는 미실행.
    - 첨부 HTTP·사진 HTTP·Hermes 기본 버튼·보조 배달·탐침·실제 team-kit 래퍼는 다음 TASK 범위다.
    - 고위험 독립 검토는 미실행. 본 보고의 자체 시험을 교차 모델 검토로 간주하지 않는다.
11. **범위 밖 기술 부채**: 별도 발견 없음. 설치기·공식 시험 진입점·필수 개인값 검사기는 tasks.md의 후속 작업이며 여기서 대신 만들지 않았다.
12. **검토 역할 주의점**: GAP 결정, fsync 이전 무송신·실패 시 길이/순번 보존, 잠금 실패 시 리스너 미생성, 연결별 재전송/실시간 전환, YAML 브리지와 실제 권한 검사, 훅의 서명·기록 완료 의미를 직접 읽어 달라. 상태 문서의 TASK 완료 처리·푸시 제안은 하지 않았다.
13. **검토 대상 코드 상태**: `main`, 위 기준 커밋 이후 이 보고와 함께 추가한 TASK-02 변경. 정확한 전체 커밋 해시·실행 검사·증거 로그는 최종 인계 상태 블록에 제공한다. 변경 파일은 4번 목록이며 `git show <대상 커밋>`으로 확인할 수 있다. 운영 배포·푸시 없음.

## GAP-T02-01: `message.files[]` 항목의 공개 모양 미정

- **발견 사실**: design 2절의 `send.files[]`는 업로드 id로 명시돼 있다. `message.files[]`는 배열 이름만 있으며 항목 필드와 필수 여부가 없다. design 2.2절의 `{file_id, employee, owner}`는 기록장 내부 등록 정보다. 이를 앱 공개 항목으로 간주할 근거가 없다. 인계서는 TASK-02에서 이후 앱·첨부 TASK가 공유할 첨부 필드까지 확정하도록 지시한다.
- **중단한 부분**: `$defs.file`에 미확정 `$comment`만 두었고 임의의 필수 필드·객체 타입을 정하지 않았다. 이 정의는 완성된 공개 계약이 아니며 첨부 HTTP 구현도 없다. `message.files`의 빈 배열을 쓰는 독립 범위만 구현·검증했다.
- **선택지**: (A) 발신·수신 모두 파일 id 문자열 배열로 통일하고 앱이 파일 정보를 얻는 계약을 별도로 정한다. (B) 문→앱 항목을 설명 객체로 정하고 공개 id·이름·미디어 종류·크기·접근 경로 중 필요한 필드와 필수 여부를 확정한다. 둘 다 계획 담당이 design·수락 기준과 연결해 결정해야 한다.
- **구현자 권고**: 앱 첨부 타일·다운로드 소비자가 필요한 값을 정한 뒤 B의 최소 필드를 설계에서 명시한다. 지금 내부 메타를 공개 항목으로 복사하지 않는다.
- **진행한 독립 부분**: 인증·주소 검사·직원 목록·텍스트 라우팅·기록장·재전송·훅·지정 수락 시험. 이를 근거로 TASK-02 전체 완료나 TASK-03a/03b 착수는 선언하지 않았다. 다음 담당은 이 보고를 검토하고 첨부 항목 결정과 필요한 보완 지시를 내려야 한다.

## 보완 1: V-1~V-4 반영 (2026-11-14)

위 본문은 최초 구현 보고의 기록이다. 이 절이 보완 1의 현재 인계 상태다.

- **받은 지시**: 기준 `d9f9817f02643bd49be04839519ac90c0ed3e1b4`, [verdict.md](verdict.md)와 [handoff.md 보완 지시 1](handoff.md#보완-지시-1-task-02-1차-검토-뒤-2026-11-14). 위험도 고위험, 필요 증거 수준 2, 구현·자체 시험 역할 유지. 착수 HEAD가 기준과 같고 작업 트리가 깨끗함을 확인했다.
- **구현자 판단**: **지시된 V-1~V-4는 반영했으나, 전체 시험 조건은 보류**. 기존 초과 프레임 시험의 간헐 실패가 현재 변경본과 기준 커밋 양쪽에서 재현됐다(OBS-T02-R1-01). 기대값을 바꾸거나 이 실패를 통과로 처리하지 않았다. 최종 완료 판정은 검토 담당에게 남긴다.
- **설계와 달라진 점**: 없음. welcome 전에는 연결을 broadcast 목록에 넣지 않고 재전송 상태의 연결 객체만 만든다. welcome의 head 스냅샷 이후 기록은 이어지는 재전송에서 회수한다. 이 배치로 기록 프레임뿐 아니라 비기록 프레임도 welcome을 앞서지 않는다.
- **변경 파일**: `schemas/hejo-wire-v1.json`, `gate/{server.py,adapter.py}`, `gate/tests/{support.py,test_boundaries.py}`, `tests/acceptance/test_gate_foundation.py`, 이 보고서. 기존 문서·시험 원본·Hermes 본체·다른 앱·운영 설정은 수정하지 않았다. 첨부 HTTP·기본 버튼·보조 배달·앱은 여전히 범위 밖이다.

### 지적별 처분

| 지적 | 반영 내용 | 근거 |
|---|---|---|
| V-1 | `$defs.file`에 UUID `file_id`, 1~255자·경로 구분자 없는 `name`, 문자열 `mime`, 정수≥0 `size`를 모두 필수로 정의하고 추가 필드를 금지. BLOCKED 주석 제거. UUID 길이도 36자로 제한 | AT-HF-46: 정상 항목, 필드별 누락, 추가 필드, 양쪽 경로 구분자, 이름 길이 경계, 잘못된 UUID·끝 개행, 잘못된 크기·형식 |
| V-2 | 인증 직후 연결 객체는 항상 재전송 중. welcome 전송 후 등록·재전송. since가 없으면 welcome.head_seq를 사용하며 미래 since는 welcome 다음 invalid_since 후 닫음 | AT-HF-44: welcome 직전 실제 기록 3개 생성, 첫 프레임·누락/중복 없는 순번·sync_done, 미래 since 오류와 닫힘 |
| V-3 | 직원별 스레드 집합을 기억하고 stop_typing에서 모두 off 후 제거. on에 ttl_seconds=6, 스키마도 on일 때 필수. 연결 종료 시 메모리의 작성 중 집합 제거 | AT-HF-45: T1/T2 on 및 각각 off. 기존 AT-HF-12 기대값 유지 |
| V-4 | 디스패치 실패 로그에 예외의 모듈·종류와 호출 스택을 기록. 본문이 들어갈 수 있는 예외 메시지·로컬 변수·프레임은 기록하지 않음 | 추가 경계 시험: 본문을 예외 메시지로 던져도 로그에 본문 없음, 예외 종류·실패 함수 스택 있음, 오류 응답 후 roster 처리 계속 |

GAP-T02-01의 설계 공백은 이번 V-1 구현으로 해소했다. V-5(기록장 전체 메모리·선형 탐색)는 지시대로 후속 기술 부채로 남겼다.

### 시험·검사와 증거

기존 38개 시험의 함수 34개는 AST를 기준 커밋과 비교해 **모두 불변**임을 확인했다. 기존 시험 도우미 `Client.open`만 새 계약의 초기 빈 sync_done을 확인·소비하도록 바꿨다. 수락 기대값·입력·합격 기준을 바꾸지 않았다. AT-HF-44는 이 도우미를 거치지 않는 실제 소켓으로 첫 수신 프레임부터 검사한다. skip·xfail·오류 허용 추가 없음.

실행 환경은 최초 보고의 Hermes venv·소스와 기존 `.build/task02-deps`를 재사용했다. 실행 시 `PYTHONDONTWRITEBYTECODE=1`, 프로세스 시작용 임시 `HERMES_HOME`, 시험별 별도 임시 홈, 실제 Hermes 모듈·인가 믹스인·프로필 API·명부 모듈과 차례 대역을 사용했다. 필요 수준 **2에 도달**했으며 실제 게이트웨이·실기기(3/4) 실행이나 독립 검토를 주장하지 않는다. 다른 에이전트를 실행하지 않았다.

공통 명령 환경(경로 변수 의미는 최초 보고와 같음):

```sh
PYTHONDONTWRITEBYTECODE=1 HERMES_HOME="$(mktemp -d)" \
HEJO_TEAM_KIT_LIB="$HEJO_TEAM_KIT_LIB" \
PYTHONPATH="$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD" \
"$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
  -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
```

| 검사 | 실제 결과 | 로그(저장소 기준) |
|---|---|---|
| 보완 초기 변경본 전체 시험(위 명령) | 종료 0, 42 passed | `.build/task02-r1-suite.log` |
| 최종 코드 전체 시험(위 명령) | **종료 1, 1 failed / 41 passed**. 실패는 기존 `test_bad_frames_are_isolated`의 초과 프레임 오류 수신 | `.build/task02-r1-final.log` |
| 최종 새 수락·로그 시험: 같은 환경에서 `-m pytest tests/acceptance/test_gate_foundation.py gate/tests/test_boundaries.py -k '44 or 45 or 46 or dispatch_logs' -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, **4 passed / 38 deselected** | `.build/task02-r1-targeted-final.log` |
| 같은 환경에서 `python .build/task02-r1-mutations.py` | 종료 0. 첨부 추가 필드 허용, welcome 이후 현재 head로 since 변경, off를 한 스레드로 제한, 예외 본문 로깅 변형에서 각각 관련 시험 종료 1. 매번 소스 바이트 원복 | `.build/task02-r1-mutations.log`, `.build/task02-r1-mutation-{file_shape,welcome_boundary,typing_threads,dispatch_privacy}.log` |
| 같은 환경에서 `python .build/task02-r1-frame-race.py` | 조정 러너 종료 0. 현재 변경본 단독 시험 5회 `[0,0,1,0,0]`, 기준 커밋 사본 5회 `[0,1,1,0,0]`. 기준 사본은 로컬 임시 아카이브이며 검사 후 제거 | `.build/task02-r1-frame-race.log`, `.build/task02-r1-frame-{current,baseline}-{0..4}.log` |
| Python AST 기반 기존 시험 비교·기준 대비 승인 문서 diff | 종료 0. 기존 시험 함수 34개, 근간·spec·design·tasks·handoff·verdict·수락 명세 7문서 불변 | `.build/task02-r1-preserved.log` |
| 변경 파일 AST 구문·절대 경로/이메일/Slack ID 모양 보조 검사 | 종료 0. 필수 명부·금고 검사 대체 아님 | `.build/task02-r1-static.log` |
| `git diff --cached --check` | 종료 0 | `.build/task02-r1-diff-check.log` |

필수 `scripts/scan_private.py`는 여전히 미생성(TASK-07)임을 확인했으며 이번 보완에서는 실행하지 않았다. 위 보조 검사를 필수 검사 통과로 간주하지 않는다. 초기 mutation 조정 러너는 로그의 ERROR 등급 문자열을 수집 오류로 잘못 구분해 종료 1이었다(`.build/task02-r1-mutations-first.log`). 실제 네 변형의 실패를 직접 읽고 수집 오류와 로그 등급을 구분하도록 로컬 조정 코드만 고쳤으며, 제품 코드와 시험 기대값은 바꾸지 않았다.

### OBS-T02-R1-01: 기존 초과 프레임 시험의 간헐 실패 — 판단 요청

- **[확인] 현상**: 1 MiB+1 메시지를 전송한 뒤 앱 오류 `too_large`를 기대하는 기존 시험이 때때로 CLOSED를 받아 실패한다. 현재 변경본 단독 반복은 1/5회, 기준 `d9f9817` 단독 반복은 2/5회 실패했다. 따라서 이번 보완에서 처음 생긴 결함이라고 단정할 수 없다. 실제 TCP 패킷 원인은 측정하지 않았다.
- **근거 위치**: 변경하지 않은 `gate/tests/test_boundaries.py`의 `test_bad_frames_are_isolated`, `gate/server.py`의 `BoundedWebSocket.close`와 프레임 크기 제한. 실패 로그는 위 반복 검사 파일이다.
- **[추정] 경계**: aiohttp가 초과 프레임의 헤더에서 제한을 판단해 닫는 경로와 클라이언트의 대형 송신 완료가 겹치며 오류 프레임을 읽기 전에 연결 종료가 관측된다. 일반 JSON/글 크기 오류·새 수락 시험은 통과했다.
- **선택지**: (A) 오류 프레임 배달 계약을 그대로 유지하고, bounded 수신·전송/닫기 경계와 시험 클라이언트의 송수신 순서를 추가 조사하도록 후속 보완 범위를 지정한다. (B) 파서 단계 초과 프레임은 WebSocket 1009 닫기로 구분할지 계획 담당이 계약·시험의 타당성을 판정한다. 구현자가 B를 채택하거나 시험을 완화하지 않았다.
- **권고·중단 범위**: 우선 A의 경계를 검토하되, 운영 배포·범위 밖 전송 계층 변경은 진행하지 않는다. V-1~V-4 변경은 보존하고 이 관측을 검토 담당에게 넘긴다. 전체 검사 조건을 안정적으로 충족했다고 선언하지 않는다.

이번 보완의 롤백은 이 저장소 보완 커밋을 되돌리는 것이다. 최초 보고의 미검증 범위(필수 개인값 검사·실제 게이트웨이/기기·첨부 HTTP·운영 설치)는 유지된다. 정확한 검토 대상 커밋은 최종 상태 블록에 남긴다. 커밋은 검토용이며 푸시·운영 반영은 실행하지 않았다.

## 보완 2: V-6 초과 프레임 알림·닫기 계약 정렬 (2026-11-14)

이 절이 TASK-02 보완 2의 현재 구현 인계다. 앞 절의 간헐 실패·보류는 당시 상태 기록이며, 이번 보완에서는 아래 20회 검사를 모두 통과했다.

1. **받은 지시·판단**: 기준 `05b0c11952e0decf6556e20327b19893c7f1a686`, verdict 2차·handoff 보완 지시 2·design 2절 크기 한도. 착수 HEAD는 기준과 같고 작업 트리는 깨끗했다. 고위험·필요 증거 수준 2 유지. **배정된 보완 구현·자체 시험 완료**로 인계하며 최종 완료 판정은 검토 역할에 남긴다.
2. **V-6 처분 / 구조**:
   - `gate/server.py`의 `BoundedWebSocket.close`: 파서의 1009 닫기 경로에서 오류 프레임 전송은 최선 노력이다. 상대 연결 종료 등으로 `send_json`이 `ConnectionError` 또는 `RuntimeError`를 던져도 동일한 1009 코드로 상위 닫기 처리를 계속한다. 본문을 추가로 읽거나 프레임 크기 한도를 늘리지 않는다.
   - `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`: 1 MiB+1 송신을 별도 태스크로 시작하고 동시에 실제 소켓의 응답을 읽는다. `error(too_large)` 또는 CLOSE/CLOSED와 `close_code == 1009`를 확인한다. 일반 종료·1006 등 다른 닫기 코드는 허용하지 않는다. 이어 새 페어링 연결에서 roster 응답을 받아 문이 계속 동작함을 확인한다.
   - 같은 파일의 추가 시험 `test_oversize_close_survives_error_frame_failure`: 오류 프레임 전송에 연결 오류를 주입해도 상위 WebSocket 닫기가 코드 1009로 호출됨을 확인한다.
3. **설계 차이·범위**: 없음. 이번 시험 변경은 인계서가 지정한 구현 범위 시험의 1 MiB 단계에 한정한다. 64 KiB 글 초과 검사와 앞선 검사들은 AST 비교로 불변임을 확인했다. 나머지 기존 시험 함수 37개와 승인·참고 문서 7개도 기준 대비 불변이다. 수락 시험 코드·명세의 입력·기대값·합격 기준은 변경하지 않았다. 새 칸·대체 경로·구버전 경로·임시 제품 코드 없음. 변경 파일은 서버·구현 시험·이 보고서 세 개다.
4. **실행 환경·증거 수준**: 최초 보고의 Hermes venv, 실제 Hermes 모듈·프로필 API·권한 검사와 차례 대역을 재사용해 **수준 2 도달**. 각 반복 실행의 프로세스 시작 홈과 각 시험의 홈은 각각 임시 디렉터리다. `PYTHONDONTWRITEBYTECODE=1`을 적용했다. 운영 설정·플러그인 연결·재시작·실제 메시지 발송·본체·다른 앱·TASK-03 범위에는 변경·실행 없음. 다른 에이전트를 실행하지 않았다.
5. **검증 명령·실제 결과**(작업 폴더는 저장소 루트, 경로 변수 의미는 최초 보고와 같음):

   ```sh
   PYTHONDONTWRITEBYTECODE=1 \
   HEJO_TEAM_KIT_LIB="$HEJO_TEAM_KIT_LIB" \
   PYTHONPATH="$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD" \
   "$HERMES_PYTHON" .build/task02-r2-repeat.py
   ```

   로컬 반복 러너는 다음 명령을 새 임시 프로세스 홈으로 20번 차례로 실행한다. 실패하면 즉시 멈추며 재시작한 통과 구간을 합치지 않는다.

   ```sh
   "$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
     -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
   ```

   | 검사 | 실제 종료·결과 | 로그(저장소 기준) |
   |---|---|---|
   | 위 전체 시험 묶음 20회 연속 | 반복 러너 종료 0. **01~20회 각각 종료 0·43 passed**. 총 860개 시험 실행. 회차 기록과 로그 20개를 직접 대조함 | `.build/task02-r2-repeat.log`, `.build/task02-r2-results.json`, `.build/task02-r2-run-01.log` ~ `.build/task02-r2-run-20.log` |
   | 사전 영향 시험 `-m pytest gate/tests/test_boundaries.py -k 'bad_frames or oversize_close' -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 2 passed / 16 deselected | `.build/task02-r2-targeted.log` |
   | 같은 시험 환경에서 `python .build/task02-r2-mutation.py` | 조정 실행 종료 0. 상위 닫기를 1009 대신 1000으로 바꾸면 새 시험이 예상 종료 1로 실패. 원본 바이트 복원 후 위 전체 20회 실행 | `.build/task02-r2-mutation.log`, `.build/task02-r2-mutation-close-code.log` |
   | Python AST 비교·승인 문서 `git diff --exit-code` | 종료 0. 64 KiB 단계·앞선 검사, 나머지 기존 시험 함수 37개, 참고 문서 7개 보존 | `.build/task02-r2-preserved.log` |
   | 변경 파일 AST 구문·보조 개인값 패턴 검사 | 종료 0. 세 변경 파일의 구문 및 절대 경로·이메일·Slack ID 모양 위반 없음. 필수 검사 대체 아님 | `.build/task02-r2-static.log` |
   | `git diff --cached --check` | 종료 0 | `.build/task02-r2-diff-check.log` |

6. **미검증·남은 위험·검토 요청**: 이번 보완에서 새로 남긴 차단 사항 없음. 최종 검토자는 변경 두 코드 파일과 20회 결과를 읽고 V-6 처분을 판정해 달라. V-5 기록장 메모리·선형 탐색은 후속 기술 부채로 유지한다. 필수 개인값 검사기(TASK-07 미생성)는 이번에도 미실행이며, 실제 게이트웨이·Tailscale·실기기·첨부 HTTP·운영 설치·독립 검토 완료를 주장하지 않는다. 롤백은 이번 보완 커밋 되돌림이며 운영 롤백은 필요하지 않다. 정확한 검토 대상 커밋은 최종 상태 블록에 제공한다. 푸시는 실행하지 않았다.

## 보완 3: V-7 앱 관측과 서버 닫기 보장 분리 (2026-11-14)

이 절이 보완 3의 현재 구현 인계다. 앞 절의 완료·보류 기록은 당시의 보고이며 최종 판정은 verdict.md를 따른다.

- **받은 지시·상태**: 기준 `a1825ccb57d6928d9db09a39158878464c9d820f`, verdict 3차, handoff 보완 지시 3, design 2절 크기 한도 3판. 착수 HEAD와 기준 일치, 작업 트리 깨끗함을 확인했다. 구현자 판단은 **배정된 시험 보완·자체 검증 완료, 재검토 대기**다. 고위험·필요 증거 수준 2 유지.
- **V-7 처분**: `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`의 1 MiB 단계만 보완했다. 앱이 TEXT를 받으면 `code == "too_large"`, CLOSE/CLOSED를 받으면 `ws.close_code in {1009, 1006}`을 확인한다. 해당 연결의 서버 WebSocket 객체를 식별하고 `BoundedWebSocket.close` 호출의 코드 1009를 별도로 단언한다. 감시는 인자를 기록한 뒤 원래 메서드를 그대로 await하므로 실제 서버의 전송·닫기를 대체하지 않는다. 클라이언트 관측이 1006이어도 서버 쪽 1009 검사는 생략되지 않는다.
- **보존·변경 범위**: `gate.is_connected`, 새 연결의 welcome·roster 확인, 64 KiB 글 초과 검사와 앞선 검사, 다른 기존 시험 함수 38개는 AST 비교로 불변이다. 제품 코드·스키마·수락 시험 코드·수락 명세·승인 문서는 수정하지 않았다. 변경 파일은 위 구현 시험과 이 보고서뿐이다. 설계와 달라진 점·새 칸·새 실행 경로·임시 제품 코드 없음.
- **증거 수준**: 실제 Hermes 모듈·명부 모듈·프로필 API·인가 검사와 차례 대역을 쓰는 기존 시험 환경을 유지해 **수준 2 도달**. 모든 실행에 `HEJO_TEAM_KIT_LIB`를 명시했다. 반복마다 새 프로세스 시작용 임시 홈, 시험마다 별도의 임시 `HERMES_HOME`을 사용하고 `PYTHONDONTWRITEBYTECODE=1`을 적용했다. 다른 에이전트는 실행하지 않았다.

공통 실행 환경은 최초 보고의 `HERMES_PYTHON`(Hermes venv 실행 파일), `HERMES_SOURCE`(Hermes 소스 루트), `HEJO_TEAM_KIT_LIB`(team-kit lib)와 기존 로컬 시험 의존성을 사용한다. 작업 폴더는 저장소 루트다.

```sh
PYTHONDONTWRITEBYTECODE=1 \
HEJO_TEAM_KIT_LIB="$HEJO_TEAM_KIT_LIB" \
PYTHONPATH="$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD" \
"$HERMES_PYTHON" .build/task02-r3-repeat.py
```

로컬 반복 러너는 아래 집중 명령을 200회, 이어 전체 명령을 20회 순차 실행한다. 환경 설정은 두 단계가 같고, 각 실행은 새 임시 홈을 받는다. 실패하면 즉시 멈추도록 했으며 실패 구간을 지우거나 다시 시작한 연속 구간을 합치지 않았다.

```sh
"$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
  -k bad_frames -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
"$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
  -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
```

| 검사 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 집중 반복 200회 | **001~200회 모두 종료 0, 각 1 passed / 42 deselected, 실패 0회** | `.build/task02-r3-focused-001.log` ~ `.build/task02-r3-focused-200.log` |
| 전체 시험 20회 연속 | **001~020회 모두 종료 0, 매회 43 passed** | `.build/task02-r3-full-001.log` ~ `.build/task02-r3-full-020.log` |
| 반복 러너·결과 대조 | 러너 종료 0. 결과 목록의 회차·종료 코드·통과 수와 로그 220개를 직접 읽어 대조 | `.build/task02-r3-repeat.log`, `.build/task02-r3-results.json` |
| 사전 영향 시험: 같은 환경에서 `-m pytest gate/tests/test_boundaries.py -k bad_frames -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 1 passed / 17 deselected | `.build/task02-r3-targeted.log` |
| AST 기존 시험 비교·기준 대비 참고 문서 diff | 종료 0. 64 KiB 단계·이후 연결 유지/새 roster 검사·다른 기존 시험 함수 38개, 서버·스키마·참고 문서 7개 불변 | `.build/task02-r3-preserved.log` |
| 변경 두 파일 AST 구문·개인값 패턴 보조 검사 | 종료 0, 절대 경로·이메일·Slack ID 모양 위반 없음. 필수 검사 대체 아님 | `.build/task02-r3-static.log` |
| `git diff --cached --check` | 종료 0 | `.build/task02-r3-diff-check.log` |

제품 코드는 불변이므로 기존 1009→1000 변형 검사와 기존 닫기 보장 단위 시험은 변경·반복하지 않았다(보완 2 절의 증거 유지, 단위 시험은 위 전체 묶음에서 실행됨). 추가 변형 검사는 미실행이다. 필수 개인값 검사기는 TASK-07 미생성으로 이번에도 미실행이며 보조 검사와 구분한다.

**검토 요청·남은 범위**: V-7 시험 변경과 집중 200회·전체 20회 결과를 검토해 TASK-02 완료 조건을 판정해 달라. V-5 기술 부채, 실제 게이트웨이·Tailscale·실기기·첨부 HTTP·운영 설치 및 TASK-05 앱 송신 전 크기 검사는 후속 범위로 유지한다. 운영 변경·비밀 파일 접근·본체·다른 앱 수정·실제 메시지 발송·푸시는 실행하지 않았다. 롤백은 이번 시험·보고 커밋 되돌림이며 운영 영향은 없다. 정확한 검토 대상 커밋은 최종 상태 블록에 제공한다.

작업 중 별도 커밋 `72683e4ae5642f810819ed9212b255455232bd84`가 UI 시안 HTML·PNG 두 파일을 추가했다. 제품·스키마·시험에는 차이가 없음을 커밋 간 diff로 확인했으며 해당 변경을 보존한다. 이번 보완 커밋은 이 커밋 뒤에 시험·보고서 두 파일만 기록한다. 보조 검사 초회에는 기준 이후 전체 변경 목록에 이 PNG까지 들어와 UTF-8 해석 오류가 났다. 이후 검사 대상을 이번에 stage한 두 파일로 한정했고 통과했다. 시험 실행 중 제품·시험 코드의 추가 변경은 없으므로 위 반복 검증 근거는 유지된다.

## TASK-03a: 보조 프로필 배달 탐침 (2026-11-14)

**탐침 결과: A 성공, B 실패(배달 전 설정 검사에서 차단).** 이 절은 구현자의 관측 보고다. 안 채택·AC 개정·운영 설정 변경 승인은 계획 담당과 사용자에게 남긴다. 수락 시험 합격을 주장하지 않는다.

### 범위·실행 구조

- 기준 `65a7d442804462f720552a212f2665dfe9888a3f`와 착수 HEAD 일치, 작업 트리 깨끗함을 확인했다. 근거는 handoff 마지막 TASK-03a와 design 4.1이다.
- 추가 파일은 `gate/probes/{__init__.py,candidates.py,run.py,README.md}`다. 운영 `gate/__init__.py`·어댑터·서버·스키마·설계·수락 시험은 변경하지 않았다. 탐침은 본 모듈에서 import하지 않으며 결정 후 TASK-03b에서 제거 또는 승인 부분만 승격한다.
- 두 안 모두 새 임시 HOME·HERMES_HOME·잠금/상태 폴더, 정리된 자식 환경에서 **실제 `gateway.run.start_gateway()`**를 실행했다. 원본 `GatewayRunner`의 프로필 검색·설정 로드·플러그인 발견·중복 검사·연결·cron ticker·종료를 사용했다. 대역 게이트웨이는 없다. 감시는 원래 중복 검사와 `wait_for_shutdown`을 호출하며 판정·연결을 대신하지 않는다.
- 기본 프로필과 가짜 보조 프로필 `alpha`를 사용했다. 두 프로필은 별도 시험 플랫폼 `probe_peer`의 서로 다른 가짜 자격과 자기 어댑터를 가진다. 실제 Slack SDK·토큰·접속은 쓰지 않았다. 이 시험 플랫폼은 메모리에만 송신을 기록한다.
- A는 두 프로필에서 hejo를 켜고 보조 어댑터의 `send`를 모듈 허브의 기본 문으로 전달한다. 보조 어댑터는 리스너·기록장·출입증 파일을 열지 않는다. B는 기본 프로필에서만 hejo를 켜고 보조 프로필은 명시적으로 끈다. 두 안의 탐침 등록에는 `cron_deliver_env_var`와 `parse_target_ref_fn`을 넣어 표준 대상 해석을 사용했다. 이는 본 플러그인에 채택한 변경이 아니다.
- `send_message_tool`은 보조 프로필 런타임 범위의 작업 스레드에서 호출했다. 예약은 같은 범위에서 고정 결과를 실제 `_deliver_result`에 넘기고 보조 프로필 어댑터 지도와 실제 게이트웨이 루프를 제공했다. 다음 시간 주기·모델 실행은 기다리거나 호출하지 않았다.

### 각 안의 관측

| 항목 | A: 전달자 어댑터 | B: 단독 발신자 |
|---|---|---|
| (a) 시작·리스너 | 성공. 4개 연결(두 프로필 각각 hejo·시험 플랫폼), 실제 TCP LISTEN **1개** | 성공. 3개 연결(기본 hejo·시험 플랫폼, 보조 시험 플랫폼), 실제 TCP LISTEN **1개** |
| (b) 중복 자격 검사 | 성공. 보조 hejo의 credential/listener 검사를 실제 통과. 둘 다 claim 없음, 거부 false. 보조 시험 플랫폼은 다른 자격 claim으로 통과 | 성공. 보조 시험 플랫폼 검사 통과. 보조 hejo는 꺼져 있어 생성·검사하지 않음 |
| (c) `send_message` | 성공. `hejo:alpha`가 유효 대상으로 처리되고 성공 영수증 반환 | 실패. 대상 파서는 인식하지만 플랫폼 설정 검사에서 차단. 단독 발신 함수 호출 **0회** |
| (c) 예약 `deliver=hejo` | 성공. 보조 프로필 home target과 고정 스레드로 해석, 실제 배달 반환 오류 없음 | 대상 이름·home target 해석 성공. 이후 `platform 'hejo' not configured/enabled`로 실패, 단독 발신 함수 호출 **0회** |
| (d) 기록장·클라이언트 | 성공. 두 글 모두 `employee=alpha`, 직접 글은 새 스레드, 예약 글은 고정 스레드로 도착. 실제 JSONL 두 행·메모리 기록·클라이언트 수신 내용 일치 | 실패. 위 설정 차단 때문에 배달·JSONL 메시지·수신 모두 0건. B 허브 함수 자체는 실제 경로에서 도달 불가 |
| (e) 다른 플랫폼 | hejo 배달 동안 두 시험 플랫폼 어댑터의 객체·연결 유지, 송신 0건. 이후 보조 시험 플랫폼 대조 송신 1건 성공, 기본 시험 플랫폼 0건 유지 | 같은 결과 |

B의 막힌 지점(아래 `R`은 Hermes 소스 루트, HEAD `ebb026eef8e800e1b7471ed147b7287e878f8aa4`):

- `R/tools/send_message_tool.py:228-230` → `_resolve_platform_config`, `:319-323`: 꺼진 보조 hejo 설정을 거부한다. `:541-585`의 live adapter/standalone 분기에 도달하기 전이다.
- `R/cron/scheduler_delivery.py:420-423`: 등록된 `cron_deliver_env_var` 덕분에 이름은 유효하다. 그러나 `:1407-1408`에서 보조 설정이 꺼져 있어 배달을 거부한다.
- A가 통과한 실제 중복 검사는 `R/gateway/run_adapters.py:1294-1312`이며, 자격 지문·리스너 claim 생성은 `:1819-1856`이다. hejo는 자격 문자열·Photon 리스너 claim이 없어서 중복 자원으로 판정되지 않는다. 소켓 검사를 별도로 해서 기본 문의 실제 리스너 하나를 확인했다.

**구현자 권고:** 현재 탐침 증거로는 A를 계획 담당의 선택 후보로 넘긴다. B를 살리려면 보조 설정 enablement 또는 Hermes의 배달 전 검사 계약을 다시 정해야 하며 이번 범위에서는 우회하지 않았다. A의 보조 hejo 켜기는 사용자 승인 대상이다.

### 명령·종료 코드·로그

작업 폴더는 저장소 루트. `HERMES_SOURCE`·`HERMES_PYTHON`은 앞 절의 실제 Hermes 소스·venv Python이고, `HEJO_PROBE_TMPDIR`에는 짧은 임시 폴더를 지정했다. `HEJO_TEAM_KIT_LIB`는 회귀 검사에만 지정했다. 추가로 필요한 psutil은 시스템 Python의 pip로 무시된 `.build/task03a-deps`에만 설치했다(종료 0, `.build/task03a-deps.log`). 본체·본체 venv를 수정하지 않았다.

```sh
export HEJO_PROBE_TMPDIR
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
"$HERMES_PYTHON" -m gate.probes.run --mode A
"$HERMES_PYTHON" -m gate.probes.run --mode B
HEJO_TEAM_KIT_LIB="$HEJO_TEAM_KIT_LIB" "$HERMES_PYTHON" -m pytest \
  gate/tests tests/acceptance/test_gate_foundation.py \
  -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
```

| 실행 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 최종 A | 종료 **0**, 위 A 결과·`GATEWAY_EXIT clean` 확인 | `.build/task03a-A-final.log` |
| 최종 B | 종료 **0**, 위 B 실패 원인을 재현·`GATEWAY_EXIT clean` 확인. 탐침 종료 0은 B 배달 성공을 뜻하지 않음 | `.build/task03a-B-final.log` |
| 직원 식별 변형 | 조정 실행 종료 0. A의 전달 metadata를 기본 직원으로 바꾸면 수신 프레임 직원 단언이 **종료 1**로 실패. 원본 바이트 복원 확인 | `.build/task03a-mutation.log`, `.build/task03a-mutation-gateway.log` |
| 기존 전체 회귀 | 종료 **0**, **43 passed**. 기존 수락·구현 시험은 수정하지 않음 | `.build/task03a-regression.log` |

탐침 준비 중 실패도 보존했다. 첫 A(`.build/task03a-A.log`, 종료 1)는 임시 홈의 자동 의존성 설치·재실행이 PYTHONPATH를 교체해 탐침을 import하지 못했다. 이후 공식 `HERMES_DISABLE_LAZY_INSTALLS=1`을 적용했다. A run2(종료 1)는 psutil 미설치, run3(종료 1)은 시험 home_channel의 platform 필드 누락, run4(종료 1)는 시험 어댑터의 추상 메서드 누락과 긴 임시 경로의 Unix 소켓 한도, run5(종료 1)는 시험 플랫폼의 대상 파서 누락이었다. run6은 종료 0으로 A 경로를 사전 확인했다. 로그는 `.build/task03a-A-run2.log` ~ `-run6.log`다. B run1(종료 1)은 생략된 보조 hejo 설정이 기본 enablement로 켜져 secondary_disabled를 유발한 탐침 설정 문제였다. 명시적 false로 정렬한 run2는 종료 0이다(`.build/task03a-B-run1.log`, `-run2.log`). 최종 두 안은 모든 탐침 보완 뒤 실행했다. 본체 수정이나 설정 검사 완화는 하지 않았다.

최종 로그의 공통 경고: 미사용 번들 wecom 플러그인의 cryptography 미설치, 대화 세션이 없는 시험 글의 mirror 경고. 해당 외부 플랫폼을 켜거나 연결하지 않았다. mirror는 이번 배달 성공·JSONL 저장·수신 검증과 별개이며, 실패를 숨기기 위해 의존성을 설치하거나 검사를 바꾸지 않았다.

### 도달 증거·미검증·다음 판단

- **증거 수준 3 도달(임시 홈 실제 게이트웨이의 시작·프로필·배달·저장·수신·종료 경계).** 고위험 탐침의 자체 증거이며 독립 검토 완료가 아니다. A/B 전체 로그와 직접 관측을 검토해 계획 담당이 design 4.1의 다음 결정을 내려야 한다.
- 실제 Slack 및 다른 외부 플랫폼 무영향, 실제 모델, 예약 생성·시간 트리거·외부 worker/별도 프로세스 단독 발신, 리스너 재접속·프로필 hot reload·스트리밍/첨부/버튼 전달은 **미검증**이다. A의 최소 `send` 탐침만으로 다른 메서드의 제품 적합성을 주장하지 않는다.
- 운영 홈 쓰기·플러그인 연결·운영 재시작·실제 외부 메시지·운영 비밀 파일 접근·본체·ddots·비공개 저장소 수정·푸시는 하지 않았다. 자식 감사 훅은 임시 폴더 밖의 비밀 파일 읽기·파일/DB 쓰기와 외부 소켓/DNS를 거부한다. 첫 자동 설치도 임시 데이터 루트에서 실행됐고 임시 홈과 함께 제거됐다.
- 필수 개인값 검사기 `scripts/scan_private.py`는 TASK-07 미생성으로 미실행이다. 보조 패턴 검사는 이를 대체하지 않는다. V-5 기술 부채는 그대로다.
- 롤백은 이번 탐침·보고 커밋 되돌림이다. 운영 변경은 없으므로 운영 롤백은 필요하지 않다. 후속 결정 전 탐침을 본 모듈에 넣거나 수락 기대값을 변경하지 않는다.

최종 보조 확인: Python AST·개인값 기본 패턴·변경 범위·A/B 관측 JSON·종료 표시·변형/회귀 로그 직접 대조는 종료 0(`.build/task03a-static.log`, 관측 추출 `.build/task03a-results.json`). `git diff --cached --check`도 종료 0(`.build/task03a-diff-check.log`). 이 검사는 필수 개인값 검사기의 대체가 아니다.

작업 중 별도 커밋 `65d1a35fca4230e1ee59087ff073f653ab6bb6f9`가 design 6절·tasks·plan-review에 TASK-05·06의 원본 전수 검토 기록 의무를 추가했다. 변경 상세를 확인했고 TASK-03a의 design 4.1·운영 모듈·시험과 무관해 보존했다. 최초 변경 범위 검사에서 기준 이후 이 계획 문서 변경까지 불변으로 기대해 종료 1이 났다(`.build/task03a-static-initial.log`). 이후 제품·시험은 작업 기준과, 이번 자체 변경에 포함하지 않은 계획 문서는 현재 HEAD와 대조해 종료 0을 확인했다. 제품 실행 검증을 다시 해야 할 변경은 없다. 이번 커밋에는 탐침 네 파일과 이 보고서만 담는다.

## TASK-03b: 착수 전 계약 확인·보류 (2026-11-14)

**구현자 상태: 보류(설계 결정 필요).** 기준 `dae1eede66b478bac54e7a6c933d579fcef4f628`과 착수 HEAD가 같고 작업 트리는 깨끗했다. handoff 끝의 TASK-03b, spec 5판, design 2·2.2·3·4.1, AT-HF-02·15~18·21·22·49·50, verdict 5차를 대조했다. A 채택은 이미 사용자 승인되었으므로 다시 승인받을 사안이 아니다. 아래 두 저장·원본 계약은 그 승인에 정의되어 있지 않다.

### 차단 T03B-01: 업로드 응답 전 첨부 등록을 담을 기록 행 미정

- **확인:** design 2.2 HTTP 표(`design.md:85`)는 파일을 저장하고 기록장 메타에 `{file_id, employee, owner: "owner"}`를 등록한 **뒤** POST 응답으로 id를 반환하도록 한다. 클라이언트의 `send{files:[id]}`는 그 뒤의 별도 요청이다. 이 시점에는 연결할 대화 글·스레드·msg_id가 아직 없다.
- **확인:** design 3절(`design.md:93-98`)은 JSONL 자체를 복구 원본으로 정하고, 한 줄을 `message/edit/delete/state` 기록 프레임과 내부 메타로 한정한다. 모든 기록 순번은 재전송되며, 첨부 등록도 같은 행의 메타로 복구해야 한다.
- **실제 구현:** `gate/journal.py:12`의 RECORD_TYPES와 `:57-58`의 복구 검사는 위 네 종류만 받는다. `:114-119`는 메타만 제거한 기록 프레임을 페이지로 내보낸다. 스키마의 serverFrame에도 업로드 등록용 프레임은 없다.
- 따라서 별도 등록 행을 추가하면 저장 형식과 재전송 계약을 정해야 한다. 기존 `message(role=system)`를 쓰려면 업로드만으로 생기는 새 글의 스레드·본문·클라이언트 표시를 정해야 한다. 메모리에만 등록하거나 `send` 때까지 영구 등록을 미루면 POST 응답 전 등록 및 재시작 복구 계약이 달라진다. 파일 옆 별도 등록 원본을 만드는 것도 JSONL 원본 계약과 맞지 않는다.
- `files[]`의 네 필수 필드 자체는 이미 확정되어 있고 문제가 없다. 차단은 그 모양을 바꾸자는 것이 아니라, **send 이전 업로드 등록의 기록 시점·행 종류·공개 동작**이 없다는 점이다. 임의의 등록 프레임이나 가짜 대화 글을 제품에 추가하지 않았다.

**계획 담당 결정 요청:** POST 응답 전 영구 등록을 유지할 경우 등록 행의 종류와 seq·재전송/표시 의미를 명시해 달라. 또는 등록을 실제 사장 글 기록 시점으로 옮길 경우 POST 이후 send 전의 재시작·GET·소유 검사 의미를 명시하고 관련 기대값을 조정해야 한다. 구현자 권고는 JSONL 단일 원본·소유 검사·재시작 복구를 유지하고, 별도 원본이나 임의의 대화 글을 만들지 않는 계약을 먼저 확정하는 것이다.

### 차단 T03B-02: 직원 사진의 원본 위치 미정

- **확인:** `design.md:51`과 `:87`에는 사진이 있으면 roster의 avatar URL과 `GET /v1/avatars/<직원 id>`로 제공한다는 계약만 있다. 근간·brainstorm·spec·design에서 사진 원본 경로나 설정 키는 찾지 못했다.
- **실제 구현:** `gate/roster.py:14-15`는 avatar를 null로 둔다. 현재 참조하는 team-kit 공개 `hermes_facility.team_registry.roster()`의 반환 항목은 name·label·roles·aliases뿐이다(해당 모듈 `:64-71`). 사진 경로를 제공하지 않는다. 실제 명부·비밀 파일은 열지 않고 라이브러리 소스만 읽었다.
- 원본 위치를 새 설정 키나 파일 규칙으로 추측하면 승인되지 않은 설정·저장 계약을 만드는 것이므로 사진 HTTP 구현을 보류했다.

**계획 담당 결정 요청:** 사진 원본 칸·경로/키와 읽기 계약을 정하거나 이번 TASK의 사진 범위를 명시적으로 보류해 달라. 이미지 경로 탈출·외부 파일 노출을 막을 경계도 함께 정해야 한다.

### 실행 증거·범위·다음 작업

제품 코드·스키마·수락 명세·기존 수락 시험은 변경하지 않았다. 전달자·첨부·버튼 본 구현과 AT-HF-02 개정 코드화·AT-22 실행은 모두 **미실행**이며 완료를 주장하지 않는다. `gate/probes/`도 대체 구현이 생기기 전에 제거하지 않고 그대로 유지했다. A 전달자의 공개 메서드 서명 조사와 기존 시험·러너 위치 확인까지만 진행했다. 독립 범위로 분리해 인계하면 전달자·기본 버튼·버튼 글자 대체는 이 두 결정을 기다리는 동안 구현할 수 있다.

읽기 조사 외에는 임시 `HERMES_HOME`에서 기록장·스키마 계약을 직접 확인했다. 실행 명령(저장소 루트, 환경 변수의 의미는 앞 절과 같음):

```sh
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPATH="$PWD/.build/task02-deps:$PWD" \
"$HERMES_PYTHON" - <<'PY'
import asyncio, json, os, tempfile
from pathlib import Path
from jsonschema import Draft202012Validator
from gate.journal import Journal, RECORD_TYPES
schema = json.loads(Path('schemas/hejo-wire-v1.json').read_text())
validator = Draft202012Validator({**schema, 'oneOf': [{'$ref': '#/$defs/serverFrame'}]})
# 채택하지 않은 진단용 데이터다.
row = {'v': 1, 'type': 'file_registered', '_meta': {
    'file_id': '00000000-0000-4000-8000-000000000001', 'employee': 'alpha', 'owner': 'owner'}}
assert not validator.is_valid(row) and row['type'] not in RECORD_TYPES
async def inspect():
    with tempfile.TemporaryDirectory(prefix='hejo-contract-') as temporary:
        os.environ['HERMES_HOME'] = temporary
        journal = Journal(temporary)
        journal.open()
        await journal.append(row)
        journal.close()
        recovered = Journal(temporary)
        recovered.open()
        assert recovered.records == []
        recovered.close()
asyncio.run(inspect())
PY
```

실제 실행은 같은 진단에 record_types·스키마 필드·유효성·복구 건수 출력까지 포함했다. **종료 0**, `.build/task03b-preflight.log`: 기록 종류 네 개, file 필수 필드 네 개·추가 필드 금지, 진단용 새 등록 프레임 무효, 재시작 복구 0행(`journal_tail_recovered`)을 확인했다. 이는 새 형식을 넣으려면 승인된 계약 변경이 필요하다는 진단이며, 새 등록 프레임을 제안·채택한 것이 아니다. 전체 제품 기능 불가능을 증명하거나 수락 시험 합격을 뜻하지 않는다.

필요 증거 수준은 2(AT-22는 3), 실제 도달은 **1(소스·스키마·로컬 기록장 진단)**이다. 실제 Hermes 통합·게이트웨이·전체 회귀는 제품 변경 전 설계 보류라 실행하지 않았고, 앞선 TASK-03a의 43 passed를 이번 TASK의 결과로 쓰지 않는다. 필수 개인값 검사기는 TASK-07 미생성으로 미실행이다. 운영 홈 쓰기·운영 재시작·외부 메시지·본체/다른 저장소 수정·설치 도우미/앱 변경·비밀 파일 열기는 하지 않았다. 이 보고서만 변경하며 롤백은 보고 커밋 되돌림이다.

20-implementation 2절의 '설계에 없는 공개 인터페이스·저장 형식·설정 키 변경이 필요'할 때 멈추는 규칙에 따라 계획 담당에게 돌려보낸다. 다음 인계는 T03B-01·02 결정과 해당 설계·시험 연결을 명시하거나, 영향을 받지 않는 독립 범위를 분리해야 한다. 푸시는 실행하지 않았다.

## TASK-03b: 6판 구현·자체 시험 인계 (보완 지시 4, 2026-11-14)

이 절이 TASK-03b의 현재 보고다. 앞의 착수 보류는 당시 기록이며 T03B-01·02는 6판 결정대로 구현했다. **구현자 상태는 부분 완료다. 기능 구현과 새 수락 시험은 진행했으나 전체 묶음에 기존 시험 기대값 충돌 1건(T03B-03)이 남았다. 전체 통과·최종 완료를 주장하지 않는다.**

### 받은 설계·변경과 책임

- 기준 `d544ad9035d9e0dd6571ad7474dfc2378111feff`과 착수 HEAD 일치, 작업 트리 깨끗함을 확인했다. handoff TASK-03b와 보완 지시 4, verdict 6차, design 2.2 첨부 등록 시점 1~4항·4.1을 따랐다. 고위험, 필요 증거 수준 2와 AT-HF-22 수준 3이다.
- `gate/files.py`: 대기 저장(파일 쓰기·fsync·디렉터리 이름 바꾸기), 50 MiB 제한, 직원/id/이름·심볼릭 링크 검사, 일괄 승격과 실패 복구, 기록장 메타 소유 조회, 직원 파일 복사, 시작·하루 한 번 정리의 파일 책임을 맡는다. 별도 등록 파일·새 기록 행·가짜 대화 글은 없다.
- `gate/adapter.py`: 기본 문만 파일 저장소·리스너·인증·기록장을 연다. 보조 연결은 파일을 열지 않고 성공하며, 송신마다 현재 기본 문을 찾아 `_owner_profile` 신원으로 넘긴다. send·edit·typing·stop_typing·문서·로컬 이미지·기본 버튼 3종을 전달하고, 허브가 없으면 `hejo_primary_unavailable` 실패·로그로 끝낸다. 기본 문 재연결 뒤 기존 전달자를 재사용한다. reply 상태 갱신에도 직원 소유를 확인한다.
- 사장 첨부는 모든 id를 확인한 뒤 이동하고 message 메타에만 등록한다. 하나라도 없거나 다른 직원의 대기 파일이면 `unknown_file`, 글·차례 0건이다. 기록장 실패 시 대기 칸으로 되돌린다. 이벤트의 `media_urls`는 등록된 로컬 경로, `media_types`는 MIME이다. 직원 파일도 동일 등록 경로로 복사한 뒤 message.files에 네 필수 필드만 보낸다.
- `gate/server.py`: 같은 리스너에 Bearer 인증 첨부 POST/GET과 사진 404를 추가했다. POST는 multipart의 `file`을 받고 대기 칸에만 저장한다. GET은 기록장 소유만 인정하며 대기 파일·다른 직원·경로 탈출은 404다. roster는 기존 null을 유지한다.
- `gate/buttons.py`: 기본 승인·질문·슬래시 버튼을 실제 공개 resolver로 넘긴다. 만료 시 `button_expired`이며 다른 차례를 만들지 않는다. 해석 자료는 기존 message 메타에 저장한다. 답장 버튼 메타가 없는 표식은 라벨 글자로 바꾼다.
- `gate/__init__.py`·`gate/README.md`: 공개 등록의 예약 플랫폼 키 `cron_deliver_env_var="HEJO_DELIVERY_TARGET"`와 대상 파서를 정했다. 기본 대상은 프로필 config의 home_channel, 스레드 없음이다. 허용 사용자는 기존 config YAML 브리지만 쓰고 .env는 쓰지 않는다. 등록 키의 환경 값을 직접 만들거나 읽는 새 경로는 없다. README에 실제 등록 의미·대상 문법·첨부 입력/MIME·실행 전제를 적었다.
- `schemas/hejo-wire-v1.json`: 기존 error.code는 열린 문자열이므로 기존 코드를 제한하지 않고 `examples` 목록에 `unknown_file`을 추가했다. 기록 프레임 종류와 files[] 모양은 불변이다.
- `gate/probes/` 네 파일을 제거했다. 대체 실제 환경 시험은 `gate/tests/gateway_delivery.py`이고 제품 플러그인 `gate.register`를 그대로 쓴다. 탐침 전용 A/B 어댑터·단독 발신자·등록 값을 남기지 않았다. 시험 플랫폼만 러너 안의 별도 가짜 연결로 유지한다.
- 기존 동작에서 의미가 바뀐 곳은 승인된 전달자·첨부·기본 버튼·표식 대체다. 새로운 칸·두 번째 원본·운영 우회 경로는 없다. 설치 도우미·앱·다른 저장소는 변경하지 않았다. Slack과 hejo 대화 동기화도 만들지 않았다.

### 시험과 실제 경계

- AT-HF-02는 개정 명세대로 코드화했다. 두 시작 순서, 기본 문 응답·리스너 한 개를 확인하고 시험 동안 파일 열기를 감시한다. 보조의 기록장·devices.json·pairing.json 접근은 없음을 검사한다. Hermes 자체의 gateway_state 상태 게시 파일은 이 금지 대상이 아니다.
- `tests/acceptance/test_gate_extensions.py`: AT-HF-15(로컬 media 경로·MIME·wire 파일), 16(미등록/탈출/무인증/다른 직원/정상 GET), 17(기본 버튼 3종 resolver 인자), 18(만료 거부), 21(버튼 글자 대체), 49(직원 고정·수정·typing·버튼·첨부 전달), 50(허브 없음), 51(대기 GET 거부·다른 직원 거부·재시작 뒤 send·24시간 정리)을 추가했다.
- edit 프레임은 기존 규격대로 msg_id로 원래 message에 연결된다. AT-HF-49는 그 msg_id의 직원이 beta임을 확인하며, 스키마에 없는 employee 필드를 edit에 추가하지 않는다.
- `gate/tests/test_extensions.py`: 실제 파일 이동의 기록 실패 되돌림, 심볼릭 링크·경로 탈출, 50 MiB 초과 정리, 고아 삭제·등록/최근 대기 보존, 허브 교체/없음·이미지 경로, avatar 없음·POST 인증을 확인한다. HTTP 공통 도우미는 `gate/tests/extension_support.py`다.
- AT-HF-22는 실제 `start_gateway()` 프로세스, 기본+보조 beta, 각자의 시험 연결을 사용한다. 실제 중복 자격 검사·send_message·예약 `_deliver_result`·JSONL·WebSocket을 통과했다. 온라인 직접/예약 2건, 앱 끈 뒤 직접/예약 2건을 만들고 재접속 sync로 2건을 받았다. 네 글은 beta의 서로 다른 새 UUID 스레드, seq 1~4이며 리스너 1개·다른 연결 송신 0건이다. 정상 종료도 확인했다.
- 실제 환경 러너는 HOME과 HERMES_HOME을 다른 임시 경로로 둔다. pytest 조상에서 실행돼도 Hermes의 운영 DB 보호를 끄지 않는다. 자동 설치를 끄고 임시 폴더 밖 비밀 파일 읽기·쓰기 및 외부 소켓/DNS를 감사 훅에서 거부한다. 공개 gateway lifecycle/배달 경로를 대역으로 바꾸지 않는다. 기본 문 등록과 시작 경계 감시는 원본 함수를 그대로 호출한다.
- 변형 3건: 다운로드 직원 일치 조건 제거 → AT-16 실패, 전달 직원 고정을 alpha로 변경 → AT-49 실패, 사장 첨부 기록 실패의 되돌림 제거 → 구현 경계 시험 실패. 모두 대상 pytest 종료 1을 확인하고 원본 바이트를 복원했다.

### 차단 T03B-03: 기존 TASK-02 구현 시험과 전달자 계약의 충돌

`gate/tests/test_boundaries.py:264-275`의 `test_secondary_with_independent_home_never_listens`는 보조 어댑터 connect에 **False**와 retryable=False를 기대한다. 5·6판 REQ-HF-01.AC-02와 개정 AT-HF-02는 기본 문 유무·시작 순서와 무관하게 **True**를 요구한다. 해당 시험도 `set_owner_profile("beta")`를 사용하므로 전달자 계약과 동시에 충족할 수 없다.

이번 지시는 'TASK-02 시험 기대값은 AT-HF-02 개정분 외 변경 금지'다. 따라서 이 구현 시험을 수정·삭제·skip·xfail하지 않았고, 홈이나 시험 이름으로 제품 동작을 갈라 실패를 피하지 않았다. AT-HF-02 이외의 기존 시험 함수는 AST로 불변을 대조한다.

**계획 담당 요청·권고:** 이 한 구현 시험도 개정 AC-02의 보존 항목(리스너·기록장·출입증 미접근)은 유지하며 연결 성공으로 바꿀 수 있도록 인계의 시험 변경 허용 범위를 명시해 달라. 판단 전에는 전체 시험 통과로 판정할 수 없다. 이후 이 시험 보완과 전체 묶음 재실행이 남는다. 제품을 옛 비활성 방식으로 되돌리는 것은 승인된 전달자 계약과 맞지 않는다.

### 실행 명령·종료 코드·로그

저장소 루트에서 앞 절의 Hermes venv Python·소스 및 기존 로컬 시험 의존성을 썼다. 실제 Hermes HEAD는 `ebb026eef8e800e1b7471ed147b7287e878f8aa4`다. HEJO_TEAM_KIT_LIB도 명시했다. 매 시험 임시 HERMES_HOME을 사용했다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
export HEJO_TEAM_KIT_LIB
"$HERMES_PYTHON" -m pytest gate/tests tests/acceptance/test_gate_foundation.py \
  tests/acceptance/test_gate_extensions.py tests/acceptance/test_gate_delivery.py \
  -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
"$HERMES_PYTHON" -m gate.tests.gateway_delivery
```

| 실행 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 최종 전체 묶음 | **종료 1, 57 passed / 1 failed**. 실패는 T03B-03 한 건 | `.build/task03b-final-2.log` |
| AT-HF-22 단독 실제 게이트웨이 | **종료 0**. 리스너 1, beta 4건·새 스레드 4개, 오프라인 재전송 2건, 타 연결 송신 0, 정상 종료 | `.build/task03b-at22.log` |
| 직원 소유·전달 신원·파일 되돌림 변형 | 조정 실행 **종료 0**, 각 변형 pytest **종료 1** 및 원본 복원 | `.build/task03b-mutations.log`, `.build/task03b-mutant-{ownership,identity,rollback}.log` |

중간 실행도 보존했다. first는 모듈 이름과 로컬 buttons 변수 충돌 등 구현 오류로 종료 1(21 failed / 30 passed), second는 위 오류 수정 뒤 종료 1(3 failed / 49 passed), third는 종료 1(1 failed / 57 passed)이었다. AT-15는 시험 허용 사용자를 config 브리지로 설정했고, AT-22는 임시 HOME과 별도 HERMES_HOME으로 운영 DB 보호를 유지했다. 최초 final 및 impact 실행에서는 AT-02의 새 파일 감사가 허용된 gateway_state 게시까지 금지한 시험 코드 오류가 있어 종료 1이었다. 금지 대상을 개정 명세의 기록장·출입증 파일로 맞춘 최종 결과가 위 final-2다. 로그는 `.build/task03b-{first,second,third,final,impact}.log`다. 기존 기대값을 완화한 처분은 없으며 실패 구간을 지우지 않았다.

**도달 증거:** 수준 2(실제 Hermes 모듈·프로필·대역 차례와 실제 파일/HTTP/소켓), AT-22는 수준 3(임시 홈 실제 게이트웨이)이다. 전체 묶음 실패가 있으므로 구현 완료·독립 검토 완료가 아니다. 실제 Slack·실제 모델·예약 시간 트리거·별도 worker·실기기/Tailscale·운영 설치·24시간 실시간 대기는 미검증이다. 파일 TTL 삭제는 시각을 과거로 바꿔 시작 경계에서 검증했다. 필수 개인값 검사기는 TASK-07 미생성으로 미실행이며 보조 검사와 구분한다. V-5 기록장 메모리·선형 탐색 부채는 유지한다.

운영 홈 쓰기·재시작·플러그인 연결·외부 메시지·비밀 파일 열기·Hermes 본체/다른 저장소 수정·다른 에이전트 실행·푸시는 하지 않았다. 롤백은 이번 문 확장·시험·보고 커밋 되돌림이며 운영 롤백은 필요하지 않다. 검토자는 파일 소유·복구 경계, 전달자 직원 고정, native 버튼 메타·resolver, 그리고 T03B-03의 시험 변경 권한을 우선 확인해 달라.

최종 보조 검사도 실행했다. 변경된 텍스트 14개 파일의 AST/JSON 구문·개인값 기본 패턴, 기존 시험 함수 불변(AT-02 제외), 설계·수락 명세 불변, 스키마의 unknown_file 주석 외 불변, probes 제거, 최종 전체·AT-22·변형 로그 직접 대조는 **종료 0**(`.build/task03b-static.log`). `git diff --cached --check`도 **종료 0**(`.build/task03b-diff-check-final.log`)이다. 이 보조 검사는 필수 개인값 검사기를 대체하지 않는다. 정확한 검토 대상 전체 커밋은 최종 상태 블록에 제공한다.

### 보완 5: 전달자 시험 계약 개정·수정 소유 검사 (2026-11-14)

기준 커밋은 `ab26bc504d592605759268d650dc79b2dc1fa070`이며 착수 HEAD 일치·깨끗한 작업 트리를 확인했다. verdict 7차와 handoff 끝의 보완 지시 5에 따른다. **구현자 판단은 구현·자체 시험 완료, 검토 대기다.** 앞 절의 T03B-03 차단은 이번 명시적 허가에 따라 해소했다. 최종 판정은 검토 역할이 한다. 위험도 고위험, 필요 증거 수준 2와 AT-HF-22 수준 3은 그대로다.

- **T03B-03:** 옛 비활성 시험을 `test_forwarder_with_independent_home_preserves_primary_resources`로 교체했다. 연결 성공, 보조 홈의 잠금·출입증·첨부 경로 미생성, LISTEN 소켓 집합 불변, 연결·해제 후 `_primary`가 기본 문 그대로임을 확인한다. 보조의 journal/files/auth/server도 생성되지 않음을 검사한다. 이 함수 외 기존 시험 기대값·수락 명세는 바꾸지 않았다.
- **V-8:** `gate/adapter.py::_forward`에서 현재 기본 문을 찾은 뒤, edit 대상 기록장의 employee를 `_owner_profile`과 대조한다. 없거나 다른 직원의 글이면 `message_not_found`로 끝내고 기본 문의 edit를 호출하지 않는다. 기본 문 부재 시 기존 `hejo_primary_unavailable` 처리는 유지한다. 새 저장소·공개 계약·우회 경로를 만들지 않았다.
- `test_forwarder_edit_rejects_other_employee_before_dispatch`는 다른 직원·없는 글 수정의 실패와 기본 문 무호출·기록장 불변을 확인한다. 이어 자신의 글 수정은 정상 전달되고 직원 고정이 유지됨을 확인한다. 소유 검사 블록을 제거한 변형은 기본 문 무호출 단언에서 종료 1로 검출했고, 원본 바이트 복원까지 확인했다.

전체 묶음과 단독 AT-HF-22는 앞 절과 같은 Hermes venv·소스·로컬 의존성을 사용했다. `HEJO_TEAM_KIT_LIB`를 지정했으며 각 시험은 임시 HERMES_HOME, 실제 게이트웨이는 임시 HOME과 HERMES_HOME을 사용했다. 아래 변수는 실행 환경의 실제 경로를 가리키며 공개 문서에 개인 절대 경로를 적지 않는다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
export HEJO_TEAM_KIT_LIB
"$HERMES_PYTHON" -m pytest gate/tests tests/acceptance \
  -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider
"$HERMES_PYTHON" -m gate.tests.gateway_delivery
```

| 실행 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 전체 묶음 | **종료 0, 59 passed** | `.build/task03b-r5-full.log` |
| AT-HF-22 단독 실제 게이트웨이 | **종료 0**. 리스너 1, 보조 직원 배달 4건·새 스레드 4개, 오프라인 재전송 2건, 다른 플랫폼 송신 0, 정상 종료 | `.build/task03b-r5-at22.log` |
| V-8 소유 검사 제거 변형 | 조정 실행 **종료 0**, 변형 pytest **종료 1**, 원본 바이트 복원 확인 | `.build/task03b-r5-mutation.log`, `.build/task03b-r5-mutant-edit.log` |
| AST·기존 시험 불변·허용 변경 범위·개인값 보조 검사·실행 로그 대조 | **종료 0** | `.build/task03b-r5-static.log` |
| `git diff --cached --check` | **종료 0** | `.build/task03b-r5-diff-check.log` |

도달 증거는 **수준 2**, AT-HF-22의 실제 시작·프로필·배달·저장·수신·종료 경계는 **수준 3**이다. 나머지 미검증 범위·V-5 기술 부채는 앞 절과 같다. 필수 개인값 검사기는 TASK-07 미생성으로 미실행이며 보조 검사가 이를 대체하지 않는다. 운영 자원 쓰기·재시작, 본체·다른 저장소·설치 도우미·앱 수정, 비밀 파일 열기, 실제 외부 메시지 발송, 푸시는 하지 않았다. 롤백은 이번 보완 커밋 되돌림이다. 검토자는 허가된 기존 시험 교체와 전달 전 edit 소유 검사·무호출 증거를 확인해 달라. 검토 대상 전체 커밋은 인계 상태 블록에 기록한다.

## TASK-07: 개인값 검사 부분 구현·설치 계약 보류 (2026-11-14)

### 받은 설계·현재 변경본

기준 `30fea35354b43b89fbf7346a20dff4f4cde6fb34`와 착수 HEAD가 같고 작업 트리가 깨끗함을 확인했다. handoff 끝 TASK-07, design 7절·3-1, spec REQ-HF-13·14, AT-HF-27·28·29·38~43을 읽었다. TASK-03b 완료 판정과 구현 커밋이 현재 기준에 포함됨도 대조했다. 위험도 고위험, 필요 증거 수준 2다.

**현재 판단은 부분 구현·설계 판단 대기다. 설치 도우미는 작성하지 않았다.** 아래 두 쟁점은 20-implementation 2절의 계약 충돌·애매한 개인값 처분에 해당하므로 임의의 의미 변경을 하지 않는다. 자체 시험 통과는 TASK-07 완료가 아니다. 변경은 main 작업 트리에 있으며 커밋·푸시하지 않았다. 기존 게이트 코드·설계·수락 명세는 바꾸지 않았다.

### T07-01: 실패 영수증과 새 디렉터리 복구의 충돌

- 근거: design.md:181·184~187은 `<HOME>/hejo/` 생성 여부도 영수증 대상으로 삼으며, 최초 변경 전에 그 디렉터리 안에 영수증을 만들고 실패 때 applied 대상을 before로 되돌린 뒤 영수증은 `failed`로 남기라고 한다. AT-HF-39(수락 명세 52행)는 홈의 대상 전부가 설치 전과 같아야 한다.
- 빈 홈에서는 hejo 디렉터리의 before가 없음이다. 그 디렉터리를 되돌려 없애면 안의 실패 영수증도 없어지고, 실패 영수증을 남기면 디렉터리의 before를 복원하지 못한다. 또한 영수증을 처음 쓰기 전에 그 부모 디렉터리를 만들어야 하므로 문자 그대로의 '변경 전 영수증'에도 부트스트랩 예외가 필요하다.
- 임시 디렉터리 진단은 실패 영수증이 있으면 디렉터리가 남고, 디렉터리 복구 후에는 실패 영수증이 없음을 확인했다. `.build/task07-receipt-contract.log`, 종료 0이다. **실제 설치 실패 시험이나 AT-39 통과가 아닌 계약 진단**이다.
- 계획 담당 판단 요청·권고: 영수증용 hejo 디렉터리 생성을 명시적인 기록 부트스트랩으로 두고, 실패 뒤에는 디렉터리와 `failed` 영수증만 남기며 이번에 만든 빈 devices 파일·링크·설정은 되돌리는 안을 권고한다. design과 AT-39가 이 잔존 예외를 명시해야 한다. 대안은 실패 영수증 위치·보존 계약 변경이다. 구현자는 어느 안도 채택하지 않았다.
- 미구현: 프로필 API 설치 대상 연결·영수증·재설치·제거·실패 복구 전부, AT-27·28·38·39·40. 현재 원본 프로필 API의 list_profile_names/get_profile_dir가 비밀 파일을 읽지 않는 경로임은 소스로 확인했지만 설치에 채택하지 않았다.

### T07-02: 최초 개인값 검사와 필수 원본 참조의 충돌

- 최초 추적 파일 검사 `.build/task07-private-initial.log`는 **종료 1**이다. `vault` 15건과 수락 명세 AT-42의 명시된 가짜 경로 1건을 탐지했다. 값·일치 문자열·원문은 출력하지 않고 종류·파일·줄·SHA-256만 남겼다.
- vault 15건은 전부 이미 지시·승인 문서에서 요구하는 원본 저장소 참조와 겹친다. 확인은 실제 값 출력 없이 수행했다(`.build/task07-collision-diagnosis.log`, 종료 0). 예: AGENTS.md:11의 줄 지문 `bad0433a5f171770786f12fb890f1a2239f16dc72b400b32d2e4faf5cec34694`. 원본 복사 검토에 필요한 새 copy-review.md:5도 같은 문제에 포함된다.
- AT-42의 가짜 경로는 현 지시가 허용한 `fake-test` 줄 지문 예외로 등록했다. 수락 명세 원문·의미는 바꾸지 않았다. vault 15건은 실제 개인값인지, 탐지 입력의 비개인 메타인지 판단이 필요하므로 치환·허용하지 않았다. 파일 전체 예외·새 예외 종류·탐지 약화·기준선은 만들지 않았다.
- 최종 `python3 scripts/scan_private.py`와 pre-commit 훅은 각각 **종료 1**, vault 15건을 계속 차단한다. 로그는 `.build/task07-private-final.log`, `.build/task07-hook.log`다. 위반 0·공개 준비 완료를 주장하지 않는다.
- 계획 담당 판단 요청: 참조도 개인값으로 분류한다면 승인 문서·프로젝트 지침·복사 기록의 중립 참조 표현을 정해 달라. 비개인 메타라면 원본 단어 입력 분류 정책을 명시해 달라. 가짜 시험 값·LICENSE 고지 이외의 일반 예외를 구현자가 추가하는 것은 권고하지 않는다.

### 독립 범위 구현·책임

- `scripts/scan_private.py`: `git ls-files -z`의 모든 추적 텍스트를 확장자 없이 검사한다. 앞 8 KiB NUL 또는 UTF-8 해독 실패는 바이너리로 표시한다. 명부·금고·Slack ID·이메일·절대 경로를 검사하고 fixed_home만 코드(.py/.swift/.sh 또는 shebang)에 한정한다. 운영 홈은 고정된 owner/team.yaml·owner/vault.yaml만 열고 디렉터리 순회는 하지 않는다. 이 두 입력의 심볼릭 링크는 거부하고 추적 심볼릭 링크는 대상 파일을 열지 않고 링크 문자열을 검사한다. 오류에도 예외 원문을 출력하지 않는다.
- `copy-review.md`: 외부 패턴 모듈 전체와 의존을 먼저 읽고 기록한 뒤 패턴·단어 추출 규칙을 복사했다. 확장자·시험 폴더 제외·기존 지문 규칙은 가져오지 않았다. 외부 저장소 import·수정·동기화는 없다.
- `scripts/scan_private_allow.txt`: 정확한 줄 내용의 SHA-256에만 예외를 연결한다. 허용 이유는 fake-test·license-notice이고 고지는 LICENSE 저작권 줄로 제한한다. 현재 예외는 명시된 AT-42 가짜 경로 한 줄뿐이다.
- `githooks/pre-commit`: 검사기의 종료를 그대로 전달한다. 로컬 Git hooksPath 설정은 바꾸지 않았다. 실제 훅 실행으로 탐지 종료 1이 전파됨을 확인했다.
- `scripts/test.sh`: 기존 gate/tests + tests/acceptance 전체를 실행한 다음 실제 게이트웨이 AT-22 러너를 실행한다. 앱 시험은 TASK-05에서 붙인다고 명시한다. HEJO_PYTHON으로 의존성이 있는 Python을 지정한다.
- `README.md`: 현재 설치 보류 상태, 개인값 검사·훅·시험 사용법과 의존을 기록했다. 제공하지 않는 설치 도우미를 실행 가능하다고 안내하지 않는다.

### 실행 명령·결과·증거

앞 TASK-03b와 같은 Hermes venv Python·소스·로컬 시험 의존성을 썼다. HEJO_TEAM_KIT_LIB를 지정했고 기존 통합 시험은 임시 HERMES_HOME, AT-22는 임시 HOME과 HERMES_HOME에서 실행했다. 검사기의 실제 운영 입력 읽기는 이번 인계가 허가한 두 파일뿐이며 값은 로그에 남기지 않았다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
export HEJO_TEAM_KIT_LIB
export HEJO_PYTHON="$HERMES_PYTHON"
bash scripts/test.sh
python3 scripts/scan_private.py
githooks/pre-commit
```

개인값 검사 실행의 python3는 Hermes venv bin을 PATH 앞에 두어 ruamel.yaml이 있는 해석기를 사용했다. 기본 시스템 python3에는 ruamel이 없어 이 의존성 조건을 README에 명시했다.

| 실행 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 개인값 수락·경계 시험 | 종료 0, **9 passed**(AT-29·41·42·43, 원문 비출력·링크 경계) | `.build/task07-scan-tests.log` |
| `bash scripts/test.sh` | 종료 0, **68 passed**(기존 59 포함), 이어 AT-22 실제 리스너 1·배달 4·새 스레드 4·재전송 2·다른 플랫폼 0·정상 종료 | `.build/task07-full.log` |
| 허용 밖 state 파일 읽기 변형 | 조정 종료 0, AT-41 pytest 종료 1로 검출, 원본 바이트 복원 | `.build/task07-scan-mutation.log`, `.build/task07-scan-mutant-owner.log` |
| 개인값 검사·훅 | 각각 종료 1, 판단 대기 vault 15건 | `.build/task07-private-final.log`, `.build/task07-hook.log` |
| AST·쉘 구문·기존 파일/시험 불변·지문 로그 대조·diff 검사 | 종료 0 | `.build/task07-static.log` |

도달 증거는 검사기의 임시 공항·Git·감사 훅 경계 **수준 2**, 기존 AT-22의 실제 게이트웨이 경계는 **수준 3**이다. 설치 도우미는 미구현·미검증이며 해당 증거 수준에 도달하지 않았다. V-5 부채와 앞 절의 실제 외부 연결·모델·운영 설치 미검증 범위도 그대로다. 운영 홈 설치·재시작·본체/다른 저장소/앱 수정·비밀 파일 열기·실제 외부 메시지·푸시는 하지 않았다. 변경 전 작업 트리가 깨끗했으므로 롤백은 이번에 추가한 파일과 impl-report의 TASK-07 절만 제거하는 것이다. 다음 인계에는 T07-01의 영수증 부트스트랩/실패 잔존 정책과 T07-02의 참조 분류 결정을 명시해야 한다.

### 보완 6: 설치 도우미 구현·개인값 위반 해소 (2026-11-14)

이 절이 TASK-07의 현재 보고다. 위 보류 절은 당시 기록이다. **구현자 판단은 구현·자체 시험 완료, 검토 대기다.** 기준 `6a58e48469979912b05a8dfa5aaa64017d848069`의 verdict 9차·handoff 보완 6·design 7판과 AT-HF-39 개정을 확인하고 기존 스테이징 8파일을 보존해 이어갔다. 고위험·필요 증거 수준 2다. 설계와 달라진 결정·새 예외·남긴 탐침 코드는 없다.

#### T07-01·02 처분과 책임

- **T07-02 해소:** copy-review.md의 남은 원본 참조를 `<운영 저장소>/…`로 고쳤다. 실제 경로는 미추적 AGENTS.local.md에만 둔다. 예외 목록은 이전 AT-42 가짜 줄 1개 그대로이며 새 예외를 추가하지 않았다. 검사기와 훅 모두 위반 0·종료 0이다. 과거 Git 이력 정리는 3단계 공개 전 과제로 남고 이번에 이력을 다시 쓰지 않았다.
- **T07-01 해소:** `install/hejo-install`이 hejo 디렉터리를 0700 기록 부트스트랩으로 먼저 준비하고 영수증에는 path·existed만 정보로 둔다. devices·링크·설정은 최초 pending 영수증을 원자적으로 저장한 뒤 변경하고 단계마다 applied를 저장한다. 실패하면 적용 단계를 역순 복구하고 failed 영수증을 남겨 종료 1이다. 새 홈에서는 hejo 디렉터리와 영수증만 남는다. 원래 있던 기기 자료는 읽거나 덮어쓰지 않고 실패 때 원래 권한을 복원한다.
- 프로필 목록과 홈은 실제 Hermes 공개 `list_profile_names`·`get_profile_dir`, 기본 홈은 `get_default_hermes_root`를 사용한다. 기본 문과 각 보조 전달자의 링크·plugins.enabled·platform 블록을 영수증 대상으로 삼는다. 조립 여부는 team.yaml 존재만 감지하고 조립 층은 설치하지 않는다. 비밀 파일·명부·금고 내용은 설치 도우미가 읽지 않는다.
- 재설치는 installed 영수증과 before를 쓰지 않고 현재 값이 달라진 대상만 알린다. 두 번째 설치는 파일 바이트·mtime·링크가 그대로다. `--check`는 설치 값과 금고/영수증 권한을 읽기만 한다.
- 제거는 현재 값이 after와 같은 설정·링크만 되돌린다. 다른 대상은 보존하고 경로를 출력하며 종료 2다. `--uninstall --force`만 충돌 대상도 원래 값으로 복원한다. 금고·기록장·첨부는 남고 영수증은 uninstalled로 표시한다. 삭제한 키의 새 빈 부모와 이번에 만든 빈 plugins 디렉터리도 정리한다.
- 설정은 ruamel 왕복 자료로 수정한다. 영수증의 원문은 주석과 설치 전 바이트 복원에 사용하며 별도 설정 원본이 아니다. 설치 이후 문서가 정확히 설치 결과와 같을 때만 원문 전체를 복원하고, 달라졌으면 해당 키만 복원해 사장 변경을 보존한다. 쓰기는 임시 파일·flush/fsync·os.replace를 거친다. config 심볼릭 링크와 홈 밖/별칭 부모는 거부한다. 원래 플러그인 심볼릭 링크 대상은 상대 경로·끊긴 링크도 그대로 보존·복원한다.
- 설치 도우미는 게이트웨이 제어를 호출하지 않고 재시작 안내만 출력한다. README의 보류 문장을 실제 설치·검사·제거·강제 복구 사용법으로 교체했다. 앱 시험은 기존 scripts/test.sh의 TASK-05 추가 표시를 유지한다.

#### 시험·실행 증거

`tests/acceptance/test_install.py`에 12개 실행 사례를 추가했다. AT-27은 기본+beta 설치·권한·재설치 무변경·check, AT-28은 양쪽 홈의 원래 설정 주석·링크와 영수증 상태, AT-38은 port 변경 보존·나머지 복원·명시적 force를 확인한다. AT-39는 새/기존 설정 각각 초반/후반 쓰기 실패 4가지로 영수증 선행·applied·역순 복구·failed 잔존을 검증한다. AT-40은 설치 모듈 로드 전부터 `sys.addaudithook`의 open을 감시하며 설치·사장 z 추가·재설치 동안 비밀 파일 열기 0과 before 불변을 확인한다. 추가 경계는 미설치 check 무쓰기, 원래 기기 자료 보존, 사장이 바꾼 설정 부모 보존, config 링크 거부다. 모두 임시 HERMES_HOME과 가짜 프로필을 사용한다.

기존 59개 시험·기존 수락 기대값은 바꾸지 않았다. 앞 절의 검사기 시험 9개와 합해 전체 80개다. 검사기 AT-41의 두 운영 입력 제한 시험도 전체 묶음에 포함된다. 사장 변경 무시 변형과 기기 파일 복구 생략 변형은 각각 AT-38·39 종료 1로 검출했고 원본 바이트를 복원했다. 앞 절의 허용 밖 입력 읽기 변형 증거도 그대로다.

실행 환경은 앞 절과 같은 Hermes venv·실제 소스·로컬 pytest/HTTP 의존성이다. HEJO_TEAM_KIT_LIB를 지정한다. 아래 python3는 ruamel.yaml이 있는 Hermes venv의 bin을 PATH 앞에 두어 선택했다. source·Python 경로의 실제 개인값은 공개 문서에 적지 않는다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
export HEJO_TEAM_KIT_LIB
export HEJO_PYTHON="$HERMES_PYTHON"
bash scripts/test.sh
python3 scripts/scan_private.py
githooks/pre-commit
```

| 실행 | 실제 종료·결과 | 로그(저장소 기준) |
|---|---|---|
| 설치 수락·경계 시험 | 종료 0, 12 passed | `.build/task07-r6-install-final.log` |
| AT-40 모듈 로드부터 감사 재확인 | 종료 0, 1 passed / 11 deselected | `.build/task07-r6-open-audit.log` |
| `bash scripts/test.sh` | 종료 0, **80 passed**. 이어 AT-22 실제 리스너 1·배달 4·새 스레드 4·오프라인 재전송 2·다른 플랫폼 0·정상 종료 | `.build/task07-r6-full.log` |
| `python3 scripts/scan_private.py` | 종료 0, 위반 0(바이너리 생략 안내만) | `.build/task07-r6-private.log` |
| `githooks/pre-commit` | 종료 0 | `.build/task07-r6-hook.log` |
| 사장 변경·기기 복구 변형 | 조정 종료 0, 각 변형 pytest 종료 1, 원본 바이트 복원 | `.build/task07-r6-mutations.log`, `.build/task07-r6-mutant-{owner_conflict,device_rollback}.log` |
| AST·쉘 구문·변경 범위·기존 gate/schema/tests 불변·실행 로그·diff 확인 | 종료 0 | `.build/task07-r6-static.log` |

첫 설치 시험은 5 passed / 1 failed였다(`.build/task07-r6-install-first.log`, 종료 1). 감사가 표준 라이브러리 tokenize 소스 이름을 비밀 파일로 분류한 시험 준비 문제였다. 표준 lexer를 감사 전 준비하되 실제 설치 모듈 로드와 모든 main 실행은 감사 안으로 두었다. 비밀 경로 기대값은 완화하지 않았다. 중간에 분리한 시험 모듈의 import 수집 오류(종료 2)는 같은 시험 파일로 합쳐 해결했고 해당 임시 파일은 제거했다.

도달 증거는 설치·개인값 감사의 **수준 2**, AT-22의 실제 게이트웨이 경계 **수준 3**이다. 운영 설치·재시작·운영 프로필 변경, 실제 외부 메시지·모델·실기기, 전원 중단/디스크 고장·동시 설치 경쟁은 미검증이다. V-5 부채는 유지한다. 설치 시험은 모두 임시 홈이며 운영 홈에는 설치하지 않았다. 검사기는 허가된 두 입력만 읽었다. 본체·다른 저장소·앱 수정, 비밀 파일 열기, 푸시는 하지 않았다. 롤백은 이번 구현 커밋 되돌림이며 운영 롤백은 필요 없다. 검토자는 영수증 선행·부트스트랩 예외·설정 주석 복원·사장 변경 충돌 보존과 파일 열기 감사 증거를 우선 확인해 달라. 전체 검토 커밋은 최종 인계 상태 블록에 기록한다.

## TASK-05 앱 골격 + 펫 창 (2026-11-14)

### 받은 설계와 구현자 판단

기준 `77b2232aae7ada75a1753a70a3c2503403dadc87`, handoff 마지막 TASK-05, spec REQ-HF-11·16, design 2·2.1·6절과 AT-HF-23·24·25·47·48을 따랐다. 이전 TASK-07 완료와 TASK-05 대기 상태를 실제 HEAD·작업 문서·읽기 전용 인계 기록과 대조했다. **구현·자체 시험 완료, 검토 대기**다. 고위험(인증 저장), 요구 증거 수준 2다. 4판 계획 재검증 및 최종 판정은 검토 담당의 몫이며 tasks·판정·수락 명세는 바꾸지 않았다.

### 책임과 변경

- `app/Sources/AppMain.swift`·`AppDelegate.swift`: AppKit 진입점, 메뉴 막대 보조 입구, 기본 편집 메뉴, 단일 실행 잠금, 로그인 시 실행 메뉴다. 실행 잠금은 설정을 읽거나 쓰기 전에 잡는다. 로그인 등록은 설치한 앱에서 사용자가 선택할 때만 SMAppService로 한다. 시험에서 실제 등록하지 않았다.
- `LocalStore.swift`: `hejo-local.json`의 주소·기기 이름·Keychain 계정 식별자·applied·읽은 seq·펫 위치/이름을 원자 저장한다. 토큰은 없다. 캐시 JSONL은 문의 조회 복제다. 시작할 때 연속된 완전한 줄에서 applied를 복구하며 캐시 삭제 시 0으로 되돌린다. 문 주소를 바꾸면 캐시를 비운다.
- `GateCredential.swift`: 서비스 `io.github.hermes-hejo.hejo.gate-token`에만 출입증을 저장한다. security의 비밀 입력은 stdin으로 주고 출입증을 인자·로그에 넣지 않는다. 계정 인자에는 앱이 만든 무작위 식별자만 쓴다. 계정과 토큰의 명령 문자 입력을 거부한다. 읽기·저장·취소 삭제는 UI 밖에서 실행하고 저장 뒤 읽기 확인을 한다. 이전 앱의 Keychain 항목이나 설정을 읽지 않는다.
- `GateClient.swift`: URLSessionWebSocketTask 하나로 hello→welcome을 처리한다. applied+1만 저장, 중복 무시, 빈칸에서 sync, more 페이지 요청, ping/pong, 최대 30초 백오프를 담당한다. 송신 JSON의 UTF-8 바이트가 1 MiB를 넘으면 소켓에 보내지 않는다. 1009·too_large는 크기 안내, 비정상 끊김은 재접속이다. 연결 시도와 welcome 대기는 5초로 제한하고 새 연결/취소 후 옛 작업의 상태 적용을 막는다.
- `ConnectWindow.swift`: 주소·12자 base64url 코드·기기 이름을 받는 AppKit 연결 창이다. 코드 오류, 끊김/재시도, 출입증 취소 안내를 구분한다. `-`·`_`를 코드에서 제거하지 않는다. 코드 입력은 저장하지 않는다.
- `PetController.swift`·`PetView.swift`: 펫과 빈 AppKit 대화 자리가 한 PetPanel을 쓴다. 열고 닫을 때 key/activate를 요청하지 않는다. 실제 편집 가능한 대화 입력을 클릭할 때만 키 창을 요청하는 자리를 마련했다. 0.30초 genie는 NSView cacheDisplay로 캡처하며 동작 줄이기에서는 즉시 전환한다. 클릭/메뉴, 재클릭/Esc/접기 버튼, 4px 초과 끌기, 대화 크기 조절, 화면 변경을 연결했다. 대화 내용은 연결 상태만 표시하며 TASK-06 UI는 만들지 않았다.
- 펫의 순수 배치·변형·애니메이션·래스터 코드는 검토 후 독립 복사했다. 원본 전체 읽기·의존·가져온/제외한 범위는 `copy-review.md`의 파일별 표에 있다. PetView/App의 SwiftUI·Slack 호스트는 제외했고 배치·입력·열고닫기만 새 책임 자리로 옮겼다. PetCarrySmoke는 현재 PetController 시험으로 이식했다. 그림 네 파일과 LICENSE를 동반하고 기본 이름은 hejo로 중립화했다. 원본 저장소 수정·동기화는 없다.
- `app/scripts/build.sh`: 제품은 swiftc 단일 호출로 빌드한다. 번들 ID `io.github.hermes-hejo.hejo`, 기본 인증서 `AIpet Local Development`(HEJO_SIGNING_IDENTITY 변경 가능), 인증서 없으면 종료 1이다. 실제 인증서가 있었고 서명 검증을 통과했다. `app/scripts/test.sh`를 `scripts/test.sh`의 옛 “앱 시험 없음” 자리에 연결했다. README 사용법도 갱신했다.

별도 권위 원본·이전 앱 호환 경로·SwiftUI 예외·탐침 제품 채택은 없다. 새 동작 추가이며 기존 gate/schema/수락 시험과 기대값은 불변이다. 시험용 문 대역은 앱의 실제 URLSession·Keychain·설정 저장을 통과하는 외부 네트워크 경계다. 가짜 화면은 배치만 격리한다. 임시 시험 자원 외 남긴 탐침은 없다.

### 시험과 실제 실행

`app/Tests/TestMain.swift`는 AppKit 이벤트 경로와 상태/배치를 검사한다. AT-47 자동 부분은 열기·접기·Esc·버튼·동작 줄이기·발치 변형 사각형과 비활성 창을, AT-48은 3px 클릭/5px 이동·열린 대화 동반 이동·가짜 두 화면·화면 변경 알림을 확인한다. 원본 PetCarrySmoke의 상단에서 아래로 끌 때 바닥 유지/높이 축소, 화면 상단 너머로 끌 때 아래로 높이 증가도 확인한다. 추가로 단일 실행 경쟁·캐시 꼬리 복구/삭제·백오프 상한·UTF-8 크기 제한·코드 오류/취소·중립 이름을 확인한다.

`app/Tests/network_fixture.py`는 공유 JSON Schema로 양방향 대역 프레임을 검사한다. AT-24는 실제 Keychain 시험 계정에 페어링→평문 설정에 출입증 없음→별도 앱 시험 프로세스 재시작→welcome이다. 중복·누락·페이지·ping도 실제 소켓으로 확인한다. AT-25는 리스너를 10초 내리고 비정상 TCP 끊김을 주어 1·2·4·8초 재시도와 리스너 재개 후 30초 안 복구를 확인한다. 1009 닫기와 too_large 프레임의 안내도 별도로 확인한다. 무작위 시험 계정은 finally에서 삭제한 뒤 정확히 그 계정의 항목 없음(종료 44)을 재확인하고 임시 설정/캐시도 지운다. 실제 운영 문·운영 계정으로 연결하지 않았다.

실행 환경은 기존 Hermes venv·실제 모듈과 로컬 의존 경로다. HEJO_TEAM_KIT_LIB를 명시했고 전체 실행 바깥도 임시 HERMES_HOME으로 뒀다. 개인 경로를 공개 문서에 옮기지 않는다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1
export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
export HEJO_TEAM_KIT_LIB
export HEJO_PYTHON="$HERMES_PYTHON"
bash app/scripts/build.sh
bash app/scripts/test.sh
bash scripts/test.sh
python3 scripts/scan_private.py
githooks/pre-commit
```

| 명령·검사 | 종료·실제 결과 | 로그(저장소 기준) |
|---|---|---|
| `bash app/scripts/build.sh` | 0, 번들·로컬 서명·strict 검증 | `.build/task05-build.log` |
| `bash app/scripts/test.sh` | 0, AT-23·24·25·47 자동·48 및 앱 경계 검사 | `.build/task05-app-final.log` |
| `bash scripts/test.sh` | 0, 기존 **80 passed** + AT-22 실제 게이트웨이 + 위 앱 검사 | `.build/task05-full.log`, `.build/task05-full-result.json` |
| AT-22(통합 명령 안) | 리스너 1·배달 4·새 스레드 4·오프라인 재전송 2·다른 플랫폼 0·GATEWAY_EXIT clean | `.build/task05-full.log` |
| `python3 .build/task05_mutations.py` | 조정 0. 세 변형 모두 컴파일 0·대상 실행 1로 검출. 제품 원본은 바꾸지 않고 임시 복사본만 변경 | `.build/task05-mutations.log`, `.build/task05-mutation-results.json` |
| 1 MiB 송신 제한 제거 변형 | UTF-8 크기 단언 실패 | `.build/task05-mutant-frame_limit.log` |
| 끌기 임계값 4→2 변형 | AT-48 3px 클릭 단언 실패 | `.build/task05-mutant-drag_threshold.log` |
| 중복 seq 무시 제거 변형 | 적용/저장 실패로 재시작 시험 실패 | `.build/task05-mutant-duplicate_seq.log` |
| 임시 AppKit cacheDisplay 촬영 | 0, 펫·빈 대화 자리 화면 직접 확인 | `.build/task05-preview.log`, `evidence/HEJO-FOUNDATION/task05-automatic-open.png` |
| `python3 scripts/scan_private.py` | 0, 위반 0. 새 예외 없음 | `.build/task05-scan.log` |
| `githooks/pre-commit` | 0, 위반 0 | `.build/task05-hook.log` |
| AST·쉘·plist·복사 원본/변경 범위·최종 로그·diff 검사 | 0 | `.build/task05-static.log` |

초기 앱 시험 작성 중 throwing-autoclosure 컴파일 오류와 aiohttp 의존 경로 누락이 있었고 수정했다. 최종 앱/전체 실행은 위 환경으로 통과했다. 원래 제품 코드를 바꾸지 않는 변형 세 개 외의 UI/플랫폼 상태에는 변형을 중복 추가하지 않았다. 실제 시스템 설정 등록이나 다른 앱 입력을 고장 주입 대상으로 삼지 않는다.

### 증거 범위·남은 검토

도달 수준은 앱의 실제 AppKit·URLSession·Keychain과 임시 문 경계 **수준 2**다. 기존 AT-22는 실제 게이트웨이 경계 **수준 3**로 별도 구분한다. 최종 제품의 운영 설치·실제 운영 문 페어링·모델·실제 외부 메시지는 미검증이며 실행하지 않았다. 로그인 항목의 실제 등록/사용자 승인, 실제 다중 모니터 이동, 다른 앱에 입력 중 포커스와 0.30초 화면 녹화는 수동 미검증이다. `evidence/HEJO-FOUNDATION/TASK-05.md`에 체크리스트·파일 자리를 두었다. 자동 캡처를 수동 포커스/녹화 증거로 취급하지 않는다.

V-5 기록장 메모리/선형 탐색과 과거 이력 개인값 정리 부채는 유지한다. 권위 원본은 문이고 캐시는 복제다. 검토자는 Keychain stdin·시험 계정 정리, applied와 캐시 복구, 연결 취소 세대 경계, 비활성 패널/펫 입력·화면 배치, 복사 제외 범위와 4판 계획 재검증을 우선 확인해 달라. TASK-06 후보 대화 코드는 아직 복사하지 않았다.

운영 홈 쓰기·재시작, 본체/다른 저장소 수정, 비밀 파일 열기, 실제 외부 메시지, git push는 없다. 검사기는 허가된 두 운영 입력만 읽었다. 롤백은 이번 구현 커밋 되돌림이며 운영 롤백은 필요 없다. 검토 대상은 main에서 이 절을 담은 구현 커밋(전체 해시는 최종 인계 상태 블록)이다. Git 원격은 미등록이므로 푸시 대상이 확정되지 않았으며 푸시 불필요나 최종 완료 판정을 내리지 않는다.

## TASK-06 앱 대화 화면 (2026-11-14, 보완 지시 7·방 단위 모델 포함)

### 받은 기준·실제 변경

최초 기준은 `91c2938a4736b0b7f62c170001c3bba2ac0aaec2`였다. 작업 중 별도 계획 커밋 `3e83fd0a63d3edf285bb556d616b4865bd76f4bd`(시안 2판), `8e89e808c14bd596e26398b72c7bdc8deb106c9f`(8판·보완 지시 7), `007b68f592ee3c549d7a407bcbcf53117e22f262`(방 단위 모델 인계 보완·시안 3판)을 직접 확인했다. 최신 spec REQ-HF-12·design 6절·handoff 보완 지시 7·AT-HF-26을 따라 **세 칸 배치를 제거하고 ddots 현재 화면을 AppKit으로 이식했다. 시안 파일을 화면 기준으로 채택하지 않았다.** 시안 4·5·6·7 추가 커밋도 변경 범위가 시안 두 파일뿐임을 확인해 보존했다. 현재 계약은 8판 그대로다. 외부 계획 변경은 보존했으며 구현자가 수락 명세나 판정 문서를 고치지 않았다. 구현·자체 시험 결과를 아래에 기록하며 최종 완료 판정은 검토 담당에게 맡긴다.

원본 커밋·전체 읽기·의존·제외·상수 출처·SwiftUI → AppKit 대응은 복사 전에 `copy-review.md`에 기록했다. 기존 TASK-06 후보에 더해 ChatPanel·SlackPanel·ChatWorkspace·ChatPresentation·NativeThreadContent·SlackThreads·PetView를 끝까지 읽었다. 원본 코드·설정·실행에는 쓰지 않았다.

- `ConversationModel.swift`: 직원·방·스레드·글·파일·버튼·작성 중의 중립 조회 모델이다. `Room{id, kind, title, members}`는 welcome/roster 직원에서 파생하는 1:1 direct 방이며 별도 저장/권위 원본을 만들지 않았다. 탭·목록·카드·안 읽은 수가 방을 쓰고, 송신은 기존 employee·thread 규격에 대응한다. 기록장 seq 순서로 message/edit/delete/state 적용, 중복 무시·빈칸 거부, 캐시 재구성, 스레드별 readSeq 저장, ttl 만료를 구현했다. 사진은 첫 글자 아이콘으로 대체했다.
- `ConversationController.swift`: 초안·첨부·확인 대기를 직원/스레드별 메모리에 둔다. 업로드 중 직원 전환은 송신 대상을 바꾸지 않는다. 주소/연결 epoch가 바뀌면 전송을 멈추며 같은 client_msg_id의 확인 글이 와야 바뀌지 않은 초안을 비운다. 미확인 끊김 뒤 재동기화에도 확인이 없으면 초안을 보존하고 명시적 재전송을 기다린다. 자동 재송신은 없다. unknown_file·too_large·만료 버튼·파일 실패를 안내한다.
- `GateHTTP.swift`·`GateClient.swift`: 같은 문의 인증 HTTP POST/GET, 50 MiB·메타·이름·바이트 수 검사, 리디렉션 거부·원자 다운로드 캐시를 구현했다. 읽기/큰 multipart 조립/파일 쓰기는 UI 밖에서 한다. 출입증은 요청 헤더에만 넣는다. 기존 1 MiB 사전 검사·applied 재전송·백오프는 유지하고, 실제 transport/안내 상태 분리·마지막 sync_done 전 송신 차단·연결 epoch만 확장했다. 새 프레임·새 공개 저장 형식은 없다.
- `ConversationView.swift`·`ConversationChrome.swift`: 원본의 68px 탭 줄(72px 행), 끌면 180~300px 목록(58px 행)/숨김, 44px 브랜드/제목 머리글, 검색, 한 목록의 스레드 카드·한 개 펼침·이전 답글 더미·상태 레일·작성 중 점·버튼·첨부 타일, 새 글/답글 입력 전환·독립 초안, 끊김/오류/알림 띠를 AppKit으로 옮겼다. 원본의 간격·폰트·표면 상수와 NativeThreadCard의 네이티브 TextKit/카드/스트리밍/더미 그리기를 사용한다. 첨부·버튼·작성 중의 hosted 조각은 NSView로 바꿨다. Slack 링크·분기·삭제 API는 가져오지 않았고 새 규격을 만들지 않았다. 복사·접기는 로컬 동작이다. Enter/Shift Enter는 실제 키 이벤트, 한글 marked text는 AppKit 처리를 유지한다.
- `PetView.swift`·`PetController.swift`·`AppDelegate.swift`: 단일 PetPanel·genie·4px 끌기·포커스 비탈취는 유지했다. 대화 내용을 패널 전체에 넣고 중복 머리글을 없앴다. 원본 기본 대화 폭 360+탭68, 높이500, glass/vibrancy·65% tint·투명도 줄이기를 사용한다. 머리글의 드래그와 “펫으로 접기” 문맥 메뉴, 닫힌 펫의 13px 파란 안 읽은 배지를 연결했다. 별도 SwiftUI 미니 펫은 원본 맥에서도 꺼져 있어 추가하지 않았다.
- AppKit 파서·서식·입력·붙여넣기·드롭·아이콘·카드·리스트는 독립 복사/이식했다. SwiftUI·NSViewRepresentable·NSHosting·SlackModel·개인 설정·계정/직원 카드/공방은 없다. README와 앱 시험 진입점을 갱신했다. gate/schema/설치 코드/기존 TASK-05 기대값은 불변이다. 테스트 대역 외 운영 연결은 하지 않았다.

### 시험·명령·로그

일반 위험·필요/도달 증거 **수준 2**: 실제 AppKit·URLSession·Keychain·파일 저장과 임시 루프백 문 대역을 실행했다. 기존 AT-22의 실제 게이트웨이 경계는 수준 3이며 새 화면의 운영 검증으로 확대하지 않는다. 바깥 HERMES_HOME도 임시 폴더이고 HEJO_TEAM_KIT_LIB를 지정했다. 시험용 붙여넣기 영역도 각 시험 폴더에 주입했다.

```sh
export HERMES_DISABLE_LAZY_INSTALLS=1 PYTHONDONTWRITEBYTECODE=1
export HEJO_PYTHON="$HERMES_PYTHON"
export HEJO_TEAM_KIT_LIB
export PYTHONPATH="$PWD/.build/task03a-deps:$PWD/.build/task02-deps:$HERMES_SOURCE:$PWD"
# HERMES_HOME은 호출 조정기의 TemporaryDirectory
bash scripts/test.sh
python3 .build/task06_mutations.py
python3 scripts/scan_private.py
githooks/pre-commit
```

| 명령·검사 | 종료·실제 결과 | 로그(저장소 기준) |
|---|---|---|
| `bash scripts/test.sh` | 0, 기존 **80 passed** + AT-22 + AT-23·24·25·47 자동·48 + 대화 모델/Room/배치/HTTP·WS + Keychain 정리 | `.build/task06-r7-full.log`, `.build/task06-r7-full-result.json` |
| `python3 .build/task06_mutations.py` | 0, 세 변형 각각 컴파일 0 / 대상 시험 1로 검출, 제품 원본 불변 | `.build/task06-r7-mutations.log`, `.build/task06-mutation-results.json` |
| `python3 scripts/scan_private.py` | 0, 위반 0·새 예외 없음 | `.build/task06-scan.log` |
| `githooks/pre-commit` | 0, 위반 0 | `.build/task06-hook.log` |
| AST·쉘·복사/변경 범위·TASK-05 기대값 불변·로그·diff | 0 | `.build/task06-static.log` |

모델 시험은 seq·중복·빈칸·edit/state/delete·readSeq/재시작·캐시 삭제 후 applied=0·typing ttl·방 대응을 확인한다. 화면 시험은 원본 메트릭·탭/목록/숨김·한 개 펼침·긴 답글 더미·새 글/답글 초안 격리·닫힘/열림 배지·여는 동작의 키 포커스 비탈취를 확인한다. 기존 TASK-05 시험은 그대로 유지했다. AT-22는 리스너 1·배달 4·새 스레드 4·오프라인 재전송 2·다른 플랫폼 0·GATEWAY_EXIT clean이었다.

루프백 시험은 공유 JSON Schema로 양방향 프레임을 검증한다. 재전송→클릭→unknown_file 초안 보존→업로드 중 직원 전환→원래 문맥으로 송신/확인→파일 원본 바이트 GET/열기 콜백→다른 직원 GET 거부→64 KiB 사전 차단→서버 too_large 뒤 초안/연결 보존→정상 송신→리디렉션 차단→미확인 TCP 끊김/재접속/자동 재송신 0을 확인했다. 최종 대역 관측은 업로드 2·클릭 1·보내기 요청 5·성공 다운로드 1·리디렉션 후속 요청 0이다. 마지막 요청은 끊김 주입이며 배달 성공이 아니다. Keychain 시험 항목은 삭제 후 없음(종료 44)을 확인한다.

변형은 임시 소스 복사본에서만 실행했다. 읽음 계산의 직원/스레드 필터 제거는 격리 단언으로, HTTP 리디렉션 허용은 후속 요청/파일 열기 단언으로, 원본 표 스타일 plain→inset은 실제 배치 후 양쪽 12pt 여백 단언으로 검출했다. 최초 여백 검사가 화면 갱신 전 셀 폭만 보아 세 번째 변형을 놓쳤다(조정 종료 1). AppKit의 실제 배치가 끝난 뒤 셀을 실현하고 viewport 좌표의 양쪽 여백을 검사하도록 강화했으며, 최종 세 변형은 모두 실패를 검출했다. `.build/task06-mutant-{unread_isolation,redirect_policy,card_clipping}.log`에 대상 종료 1의 원인이 있다. 자동 캡처도 배치 후 촬영했다. 다른 화면 조합은 같은 성질의 변형을 중복 추가하지 않았고 TASK-05 크기·끌기·seq 근거를 유지한다. 초기 구현 중 줄바꿈 시험의 잘못된 이벤트 준비와 선택 client_msg_id에 null을 넣은 대역을 고쳤다. 공유 Schema와 기존 수락 기대값은 바꾸지 않았다.

### 미검증·검토·롤백

`evidence/HEJO-FOUNDATION/TASK-06.md`에 AT-26 8판의 같은 창 크기 나란히 비교 자리·체크리스트를 마련했다. ddots 촬영은 개인 내용 가림과 사장 참여가 필요한 TASK-09로 인계한다. ddots를 실행/설정 변경하지 않았다. 두 자동 AppKit 캡처는 가짜 명부/대역이며 수동·ddots와 시각 동등 판정 증거가 아니다. **실행 중 ddots와의 크기·간격·색·글꼴·애니메이션 시각 동등성은 수동 미검증**이다.

운영 페어링·실제 직원/외부 메시지·운영 설치/재시작, Finder/클립보드 실조작·한글 입력기·외부 앱 파일 열기, 포커스/녹화·다중 화면·최대 이력/파일 성능은 미검증이다. 파일 열기는 콜백과 바이트만 검사하고 실제 다른 앱은 실행하지 않았다. TASK-05 수동 4항목·V-5 기록장 성능·과거 이력 개인값 정리 부채는 유지한다.

검토자는 8판 원본 이식/제외 경계와 Room 대응, 조회 모델/readSeq 복원, 업로드/초안/재접속 문맥, HTTP 권한/리디렉션, 패널 포커스/카드 조작, 자동·수동 증거 구분을 우선 확인해 달라. 운영 홈 쓰기·재시작·비밀 파일 열기·본체/다른 저장소 수정·실제 메시지·푸시는 없다. 개인값 검사기는 허가된 두 운영 입력만 읽었다. 롤백은 구현 커밋 되돌림이다. 원격은 미등록이며 제품 최종 완료·푸시 불필요 판정을 내리지 않는다. 구현 커밋 전체 해시와 저장소 상태는 최종 인계 블록에 기록한다.

## TASK-04 team-kit hejo 답장 버튼 — 착수 전 보류 (2026-11-14)

### 확인·멈춤 근거

hejo 기준 `b039368825dd59f88c824123351b4e8bc1953460`, handoff 마지막 TASK-04와 운영 저장소 AGENTS.md·CLAUDE.md·로컬 HANDOFF.md, 실제 Git 상태를 확인했다. hejo 작업 트리는 착수 시 깨끗했다. 운영 저장소 HEAD는 `36c5aee148b952d0a068c1832df21d3ba7efe20d`였고, 다른 작업의 미커밋 변경이 아래 두 파일에 있었다.

- `<운영 저장소>/docs/changes/DDOTS-DROP-MODEL-20261113/impl-report.md`
- `<운영 저장소>/docs/changes/DDOTS-DROP-MODEL-20261113/verdict.md`

인계 (0)항은 “team-kit 원본과 운영 저장소에 다른 작업의 미커밋 변경이 있다”면 멈추도록 명시한다. 따라서 **보류(착수 전)**다. 두 파일의 변경을 손대거나 스테이징·커밋·정리하지 않았다. 운영 저장소/원본 team-kit의 제품 코드에는 쓰지 않았다.

### 실행·미실행

| 명령·확인 | 실제 결과 | 로그(hejo 저장소 기준) |
|---|---|---|
| hejo `git status --short`·`git rev-parse HEAD` | 각 종료 0, 상태 출력 없음·기준 해시 일치 | `.build/task04-preflight.json` |
| 운영 저장소 `git status --short`·`git rev-parse HEAD` | 각 종료 0, 위 두 파일 수정 상태·위 HEAD 확인 | `.build/task04-preflight.json` |
| `python3 scripts/scan_private.py` | 종료 0, 보고서 포함 개인값 위반 0·새 예외 없음 | `.build/task04-scan.log` |
| `githooks/pre-commit`·`git diff --cached --check` | 각각 종료 0 | `.build/task04-hook.log`, `.build/task04-diff-check.log` |

controls 이동·hejo 등록·Slack 전후 비교 시험·AT-HF-19/20·team-kit 전체 시험·hejo 전체 시험·airport-check·sync는 **미실행**이다. 제품 변경이 없고 착수 조건에서 중단했으므로 기존 검사를 반복하지 않았다. sync를 실행하지 않아 토큰 경고 여부는 미확인이다. 원본 team-kit 변경/처리 중 턴 여부도 추가 조사하지 않았다. 필요 증거 수준은 2이며 이번에는 도달하지 않았다. 운영 저장소 커밋은 새로 만들지 않았다.

### 재개 조건·인계

다른 작업 담당자가 위 미커밋 작업을 마무리한 뒤 TASK-04를 다시 인계한다. 재개 시 실제 상태를 다시 확인하고 원본 team-kit의 변경·처리 중 작업·sync 토큰 경고까지 착수 조건을 확인해야 한다. 보류를 우회해 다른 작업을 정리하거나 임의 worktree에서 진행하지 않는다.

게이트웨이 재시작/reload·운영 연결·실제 Slack/외부 메시지·비밀 파일 열기·Hermes 본체/ddots/운영 저장소 수정·푸시는 없다. 이번 hejo 변경은 이 보류 보고뿐이다. 최종 완료나 푸시 불필요 판정을 내리지 않는다.

### TASK-04 재개 — 구현 후 전체 시험 차단 (2026-11-14)

기준 `7d81a0134b061cfa601a4349e3cde1be3d5f3ab5`와 재개 보완 인계를 확인하고 진행했다. 착수 시 운영 저장소 HEAD는 `36c5aee148b952d0a068c1832df21d3ba7efe20d`였고, 허용된 DDOTS-DROP-MODEL 문서 두 개만 ` M`이었다. 원본 team-kit은 추적 사본과 바이트 단위로 일치했으며 원본의 추가 소스 파일은 없었다. 게이트웨이 상태의 처리 중 차례·작업은 0건이었다. 상태 파일은 읽기만 했다.

#### 구현한 변경과 위치

실행 원본 `~/.hermes/plugin-store/team-kit`의 아래 세 파일만 변경했다. 아직 운영 저장소 사본으로 모으지 않았다.

- `lib/hermes_reply/reply_buttons.py`: `controls()`와 글 나누기 표식 제거를 공유 위치로 이동했다. `clicked_context()`에 기본값이 기존 Slack 표기인 선택 인수를 더해 hejo도 같은 문맥 생성을 사용한다.
- `lib/hermes_reply/plugin.py`: 기존 Slack 등록을 유지하고 hejo 플랫폼 설치기를 추가했다. 공개 `send`·확장 `edit_message` 서명을 보존하며 표식을 제거하고 버튼 메타·`asked`를 전달한다. 클릭은 `set_reply_state(..., 'answered')` 기록 후 False를 반환해 문 기본 처리를 사용한다. 공개 `handle_message`를 감싸 누른 글 문맥을 붙이며, 성공한 최종 답장에서 같은 직원·스레드의 답변받은 글을 `closed`로 기록한다. 중간·실패·다른 대화의 발송은 닫지 않는다. metadata 없는 최종 스트리밍 edit도 앞선 send의 스레드로 연결한다. 문 내부 import는 없다.
- `tests/test_reply_hejo.py`: AT-HF-19·20 및 공개 서명·메타 보존·격리·정책 거부·기록 실패·중복 설치를 확인하는 시험 8개를 추가했다. 실제 gate 어댑터·WebSocket과 임시 프로필을 사용하고 차례 처리만 대역으로 바꿨다. gate 시험 지원 모듈은 시험 의존성으로만 사용한다. hejo 체크아웃이 시험 경로에 있어야 하며, 이번 실행은 8개 모두 실행됐다.

버튼 허용 목록·usage_ledger·hermes_router·Hermes 본체·ddots·hejo 앱·기존 시험 기대값·수락 명세는 바꾸지 않았다. 실행 중 게이트웨이는 재시작/reload하지 않았다. 운영 연결·실제 외부 발송·비밀 파일 열기·푸시는 없다.

#### 실행 명령과 결과

모든 pytest 실행은 임시 `HERMES_HOME`·`HERMES_ROOT`를 사용했다. `HEJO_PYTHON`은 설치 facts의 `packages.venv.environment`가 가리키는 게이트웨이 Python으로 설정했고, `HEJO_TEAM_KIT_LIB`는 원본 team-kit의 `lib`로 설정했다. `PYTHONPATH`에는 시험용 pytest 경로·Hermes 소스·hejo 체크아웃을 넣었다. 정확한 인자·환경 구성은 `.build/task04-resume/run_tests.py`와 각 JSON 기록에 있다. 기존 team-kit 시험의 명부·금고는 그 시험의 fixture로 지정됐다. 새 문 시험은 가짜 프로필만 사용했다.

| 명령·범위 | 종료 코드·실제 결과 | hejo 기준 로그 |
|---|---|---|
| 변경 전후 `"$HEJO_PYTHON" -m pytest` 기존 reply/plugin/split/thread/이전 Slack/button_policy 시험 9개 파일 | 각각 0, **214 passed → 214 passed**. 기존 시험은 수정하지 않음 | `.build/task04-resume-slack-before.log`, `.build/task04-resume-slack-after.log` |
| 최종 변경 뒤 같은 Slack 시험 9개 파일 | 0, **214 passed** | `.build/task04-resume-slack-final.log` |
| 원본 team-kit에서 `"$HEJO_PYTHON" -m pytest tests/test_reply_hejo.py -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 0, **8 passed**. AT-19의 버튼·표식 제거와 AT-20의 기본 이벤트·문맥·answered/closed 순서를 실제 문에서 확인 | `.build/task04-resume-hejo-buttons.log` |
| 원본 team-kit에서 같은 옵션의 `pytest tests` | **1**, **8 failed, 4784 passed, 3 skipped, 58 subtests passed**. 아래 기존 날짜 의존 문제에서 실패. 이 실행 뒤 metadata 없는 최종 edit의 스레드 추적을 보완하고 새 시험 8개·Slack 214개를 다시 통과시켰으므로 전체 결과를 최종 코드의 전체 통과로 표시하지 않음 | `.build/task04-resume-team-full.log` |
| 변경 전 운영 저장소 사본에서 같은 옵션의 `pytest tests/test_org_review.py` | **1**, **같은 8 failed, 83 passed**. 원래 사본·기존 시험을 고치지 않고 재현 | `.build/task04-resume-baseline-org.log` |
| 최종 변경본으로 `bash scripts/test.sh` | **1**. gate **80 passed**, AT-22 리스너 1·배달 4·정상 종료까지 통과. 앱 AT-23 뒤 기존 AT-47 `AT47 closing ends folded`에서 실패해 이후 앱 시험은 미실행 | `.build/task04-resume-hejo.log` |
| `"$HEJO_PYTHON" scripts/scan_private.py` · `HEJO_PYTHON` 지정 `githooks/pre-commit` | 각각 0, 개인값 위반 0·추가 예외 없음 | `.build/task04-resume-scan.log`, `.build/task04-resume-hook.log` |
| `python3 .build/task04-resume/static.py` | 0. AST·원본 변경 세 파일·허용 문서 두 개 바이트 보존·운영 HEAD/상태·처리 중 차례 0 확인 | `.build/task04-resume-static.log`, `.build/task04-resume-final-source.json` |

최초 Slack 실행은 예전 소스 쪽 venv를 사용해 `slack_sdk` 부재로 3개가 실패했다. 설치 facts로 실제 게이트웨이 Python을 확인해 고친 뒤 위 변경 전 214개 기준을 확보했다. 새 hejo 시험의 초기 실패는 작성 중 프레임 수신 처리와 시험 명부 권한 설정을 보완했고, 최종 8개는 모두 통과했다. 최초 hejo 전체 묶음은 0으로 통과했으나 최종 재실행 로그는 위 실패 결과이며, 이를 전체 통과로 대체하지 않는다.

#### 차단 사항과 처분

- **T04-01 — 기존 team-kit 날짜 의존 시험 실패:** `tests/test_org_review.py:266`의 `seed()`는 날짜를 `2026-10-14`로 고정한다. `lib/hermes_team_services/org_review.py:118-125`의 보존 정책은 현재 날짜 기준 30일 이전 기록을 지운다. `send()`·`deliver()`가 저장하며 `prune()`를 적용하므로(`:816`, `:828`) 그 날짜 행이 없어지고 이후 조회가 KeyError로 실패한다. 변경 전 사본에서도 같은 8건을 재현했다. 이 기존 시험/정책은 TASK-04 수정 범위 밖이므로 고치거나 실패를 제외하지 않았다. 계획 담당이 날짜 fixture 보완을 별도로 지시해야 한다.
- **T04-02 — 기존 앱 접힘 완료 단언 실패:** `app/Tests/TestMain.swift:92`는 0.4초 뒤 접힘 완료를 검사하며 최종 전체 실행에서 실패했다. 이 파일과 펫 코드는 이번에 불변이다. 시점 의존 가능성은 있으나 원인을 확정하지 않았고, 시험을 느슨하게 바꾸거나 재시도 결과로 덮지 않았다. TASK-05/06 검증 범위로 별도 판단이 필요하다.

운영 저장소 규칙은 시험 실패 상태에서 커밋을 금지한다. 따라서 **TASK-04는 구현 후 검증 차단·미완료**로 인계한다. 증거 수준 2는 새 hejo 버튼·클릭의 실제 Hermes import/문 전송/대역 차례 경계에 도달했으나, 전체 시험 합격 조건은 미충족이다. Slack 변경 전후 차이는 없었다.

#### 커밋·보존·재개

- `./airport-check`, `./sync`, 운영 저장소 커밋은 **미실행**이다. sync 토큰 경고는 아직 확인하지 못했다. `--split`·`--commit`·`--rebaseline`은 사용하지 않았다.
- 새 운영 저장소 커밋 해시와 커밋 파일 목록은 **없음**이다. 운영 HEAD는 위 기준 그대로이고, `git status`는 허용 문서 두 개만 여전히 ` M`이다. 두 문서는 시작 때 기록한 SHA-256과 일치한다.
- 실행 원본에는 위 team-kit 세 파일의 이번 작업 변경이 남아 있다. 변경 전 두 소스는 `.build/task04-resume/original/lib/hermes_reply/`에 보관했고, 소스 diff·최종 SHA-256은 `.build/task04-resume/` 및 `.build/task04-resume-final-source.json`에 있다. 원본을 되돌리지 않았으며 실행 중 Slack에는 새 코드를 로드하지 않았다.
- 재개 시 두 차단 사항에 대한 계획 담당 처분을 먼저 받고, 원본의 이번 세 파일 외 변경과 처리 중 작업을 다시 확인한다. 최종 전체 시험 종료 0 뒤에만 airport-check → sync 모으기 → 토큰 경고/변경 범위 확인 → 자기 파일만 `git commit --only` 순서를 실행한다. 허용 문서 두 개는 계속 보존한다.

진행 중 hejo HEAD에 별도 시안 전용 커밋 `27fcead`·`dc4cd6d95f9870d72694b88ca2a05a12297351ac`가 추가됐다. 차이는 v14 HTML/PNG 두 파일뿐이며 보존했다. 이번 구현 계약·앱/문 코드에는 영향이 없다. 보류 보고만 hejo에 별도 커밋하고, 운영 제품 코드는 커밋하지 않는다. 재현 가능한 변경 패치는 `.build/task04-resume/work.patch`, 최종 소스 사본은 `.build/task04-resume/current/`에도 보관했다.

### TASK-04 보완 지시 8 — F1~F4 처분 (2026-11-14~15)

기준 `d53529923056f648555bdf3a29b89597baf45cf1`, verdict 14차와 handoff 보완 지시 8을 확인했다. 착수 전 원본 세 파일의 해시가 직전 보고와 일치하고, 운영 저장소에는 허용 문서 두 개만 ` M`이며 처리 중 차례·작업은 0건이었다. 기존 문서 두 개의 바이트를 보존했다.

- **F3:** 보완안 (나)를 선택했다. 공개 `forwarder` 속성이 True인 전달자에는 감싸기를 설치하지 않고, 대표 어댑터에서 표식·메타·상태 종료를 한 번 처리한다. 대표/보조 직원 각각의 질문→클릭→버튼 달린 새 질문→최종 답 흐름과 edit 질문을 시험했다. 새 질문 때 기존 answered가 유지되고 최종 답에서만 closed가 되며, 각 발송에서 `controls()` 호출이 한 번임을 확인한다. 전달자와 대표 양쪽에서 설치기를 호출하는 조건이다.
- **F4:** 어댑터별 `_HejoReplyTracking`으로 최근 메시지 2,048개만 보관한다. 오래된 항목을 내보낼 때 working도 함께 지운다. closed 처리와 send/edit/상태 기록 실패 때 해당 스레드의 추적을 정리한다. 정상 종료·실패 네 경로·상한/최근 항목 보존을 시험했다. 기록장 정책이나 공개 통신 규격은 바꾸지 않았다.
- **F1:** 기존 보고서 시험의 키를 KST 기준 어제로 바꿨다. `prune` 정책은 불변이며, 과거 `now`를 명시적으로 주입하는 스냅샷 시험의 날짜는 유지했다. 시험 기대값의 의미를 바꾸지 않았다.
- **F2:** AT-47 펼침/접힘 완료 검사의 고정 0.4초 대기를 10ms 간격·단조 시계 기준 최대 2초의 조건 확인으로 바꿨다. 최종 progress 1/0 단언은 유지했다. `app/Tests/TestMain.swift`만 수정했으며 펫 제품 코드는 불변이다.

추가 변경은 원본 team-kit `lib/hermes_reply/plugin.py`, `tests/test_reply_hejo.py`, `tests/test_org_review.py`와 hejo `app/Tests/TestMain.swift`다. 원본 `reply_buttons.py`의 직전 공유 이동도 이번 운영 커밋 대상에 포함한다. 새로운 설정 키·버튼 허용 문구·SwiftUI·운영 연결은 추가하지 않았다.

#### 보완 8 검증

실행 환경은 설치 facts가 지정한 게이트웨이 Python, `HEJO_PYTHON`·`HEJO_TEAM_KIT_LIB`·`PYTHONPATH` 지정이며 각 실행은 임시 `HERMES_HOME`·`HERMES_ROOT`를 사용했다. 정확한 환경 구성과 명령은 `.build/task04-r8/run_tests.py` 및 각 JSON 로그에 있다. 새 문 시험은 실제 Hermes 모듈/문 어댑터/WebSocket과 대역 차례를 사용하므로 해당 경계의 증거 수준은 2다. 운영 Slack·실제 모델 차례·운영 hejo 연결은 시험하지 않았다.

| 명령·범위 | 실제 결과 | hejo 기준 로그 |
|---|---|---|
| 게이트웨이 Python `-m pytest tests/test_reply_hejo.py tests/test_org_review.py -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, **108 passed**(hejo 17 + 기존 보고서 91) | `.build/task04-r8-focused.log` |
| 같은 옵션, 기존 Slack 관련 9개 시험 파일 | 종료 0, **214 passed**, 변경 전 기준과 동일 | `.build/task04-r8-slack.log` |
| 같은 옵션, 최종 `pytest tests/test_reply_hejo.py` | 종료 0, **17 passed** | `.build/task04-r8-hejo-buttons.log` |
| 같은 옵션, team-kit `pytest tests` | 종료 0, **4801 passed, 3 skipped, 58 subtests passed** | `.build/task04-r8-team-final.log` (최종 변경본), `.build/task04-r8-team-full.log` |
| `python3 .build/task04-r8/mutations.py` | 조정 종료 0. 전달자 중복 감싸기와 추적 상한 제거 변형은 각각 대상 시험 종료 1로 검출. 디스크의 제품 코드는 변형하지 않음 | `.build/task04-r8-mutations.json`, `.build/task04-r8-mutation-{forwarder,bounded}.log` |
| `bash app/scripts/test.sh` 20회 순차 반복 | **20/20 모두 종료 0**, 중간 실패 없음 | `.build/task04-r8-app-repeat.log`, `.build/task04-r8-app-results.json`, `.build/task04-r8-app-01.log`~`20.log` |
| `bash scripts/test.sh` | 종료 0. gate **80 passed**, AT-22 리스너 1·배달 4·정상 종료, 앱·연결·대화 시험 통과 | `.build/task04-r8-hejo.log` |
| 원본 변경 범위·AST·정책 불변·기존 문서 해시 대조 | 종료 0 | `.build/task04-r8-static.log`, `.build/task04-r8-source.json` |

개인값 검사(`"$HEJO_PYTHON" scripts/scan_private.py`)·`githooks/pre-commit`·`git diff --check`는 각각 종료 **0**, 개인값 위반 **0**이다. 추가 예외는 없다. 로그 `.build/task04-r8-scan-final.log`·`task04-r8-hook-final.log`·`task04-r8-diff-check.log`, 명령·종료 코드는 `.build/task04-r8-final-checks.json`에 있다.

#### 보완 8 커밋·인계

- `./airport-check`는 종료 **0**이다. `--rebaseline`을 사용하지 않았다. 로그 `.build/task04-r8-airport.log`, 명령·종료 코드 `.build/task04-r8-airport.json`.
- 이어 `./sync`를 옵션 없이 실행했다. 종료 **0**, 토큰 경고 **없음**이다. `--split`·`--commit`은 사용하지 않았다. 로그 `.build/task04-r8-sync.log`, 명령·종료 코드 `.build/task04-r8-sync.json`.
- **커밋 전 중단:** sync 뒤 상태에 허용한 문서 두 개·이번 team-kit 네 파일 외에 `hermes/profiles/<보조 프로필>/memories/MEMORY.md` 사본 변경 1건이 추가됐다. 개인값이 들어간 실제 상대 경로는 미추적 `.build/task04-r8-post-sync.json`의 `unexpected_paths`에 기록했다. 그 기억 파일의 내용을 열거나 고치거나 되돌리지 않았다. 인계 보완 TASK-04 재개 (4)-4항의 “이번 작업과 무관한 운영 사본의 변화가 보이면 커밋하지 않고 경로 목록만 보고” 조건에 따라 중단했다.
- 운영 저장소 HEAD는 **`36c5aee148b952d0a068c1832df21d3ba7efe20d`** 그대로다. **이번 운영 커밋 해시·커밋 파일 목록은 없음**이다. team-kit 네 파일 사본은 최종 시험한 원본 SHA-256과 일치한다. DDOTS-DROP-MODEL 문서 두 개는 계속 ` M`이며 최초 해시와 일치한다. 대조 결과는 `.build/task04-r8-post-sync.json`이다.
- hejo에서는 F2 시험 수정과 이 보고서가 미커밋 상태다. 진행 중 추가된 별도 시안 커밋·파일은 보존하고 이번 변경에 포함하지 않았다. 새 예외·수락 명세·제품 앱/문 코드 변경은 없다.
- **상태: 구현·자체 시험 완료, 커밋 절차 보류.** F1~F4 기술 보완과 필수 시험은 통과했으나 무관한 운영 사본 변경을 처리할 권한은 이 인계에 없다. 다음 담당자는 해당 변경의 처분을 사용자에게 확인한 뒤 원본/사본·문서 보존·동시 작업 상태를 다시 대조하고 커밋 절차만 이어간다. 무관한 변경을 임의로 제외·되돌려 중단 조건을 우회하지 않는다.

게이트웨이 재시작/reload·운영 hejo 연결·외부 발송·비밀 파일 열기·푸시는 하지 않았다. 실제 Slack 동작·운영 연결은 미검증이며 기존 TASK-09 범위다. V-5와 과거 공개 이력 개인값 정리 부채는 유지한다.


### TASK-04 보완 지시 9 — 지정 파일 커밋 (2026-11-15)

verdict 15차와 handoff 보완 지시 9에 따라 기억 파일 변화를 보류 사유에서 제외하고 커밋 절차만 재개했다. 기억 파일은 열기·수정·되돌리기·스테이징하지 않았다. 추가 제품 코드나 시험 수정은 없다.

1. 원본·사본 네 파일 SHA-256을 `.build/task04-r8-source.json`과 다시 대조했다. 모두 일치했고 허용한 문서·기억 파일 외 예상 밖 경로는 없었다. 처리 중 차례/작업은 0건이었다. DDOTS 문서 두 개의 해시도 최초 기록과 일치했다. 로그 `.build/task04-r9-preflight.json`.
2. 새 파일 `hermes/plugin-store/team-kit/tests/test_reply_hejo.py` 경로만 `git add`한 다음 아래 네 경로를 명시해 `git commit --only`를 실행했다. 명령은 모두 종료 **0**이다. 커밋 메시지는 `hejo 답장 버튼을 연결하고 전달자 중복 처리와 추적 누적을 방지`다. 로그 `.build/task04-r9-operating-commit.log`·`task04-r9-operating-commit.json`.
3. 운영 저장소 커밋은 **`392a2afb46338b86ace632b185e63941114dcc77`** (`main`, 원격 `origin`)이다. 커밋 파일 목록:
   - `hermes/plugin-store/team-kit/lib/hermes_reply/plugin.py`
   - `hermes/plugin-store/team-kit/lib/hermes_reply/reply_buttons.py`
   - `hermes/plugin-store/team-kit/tests/test_org_review.py`
   - `hermes/plugin-store/team-kit/tests/test_reply_hejo.py`
4. `git show --stat HEAD`와 `git diff-tree`로 위 네 파일만 포함됐음을 확인했다. `git status`에는 DDOTS 문서 두 개·기억 파일이 계속 ` M`으로 남고, 문서 바이트도 보존됐다. 로그 `.build/task04-r9-operating-stat.log`·`task04-r9-operating-result.json`.
5. 시험한 코드가 바뀌지 않아 이미 통과한 전체 검사를 반복하지 않았다. 보완 8의 team-kit 전체 **4801 passed·3 skipped·58 subtests passed**, Slack **214 passed**, hejo 버튼 **17 passed**, 앱 **20/20 종료 0**, hejo 전체 **종료 0** 로그와 종료 코드 기록을 다시 확인했다. 도달 증거 수준은 2이며 운영 연결·실제 Slack·모델 차례는 미검증이다.

hejo 커밋 대상은 `app/Tests/TestMain.swift`와 이 보고서 두 파일뿐이다. 진행 중 추가된 시안 파일·커밋은 보존한다. 최종 hejo 커밋 해시·파일 목록·두 저장소 상태는 `.build/task04-r9-git-final.json`, 커밋 명령·종료 코드는 `.build/task04-r9-hejo-commit.log`에 기록한다. 보고서 갱신 뒤 개인값 검사·pre-commit·공백 검사는 각각 종료 **0**, 개인값 위반 **0**이었다. 결과는 `.build/task04-r9-final-checks.json` 및 해당 로그에 둔다.

앞선 보완 8의 커밋 보류 사유는 이 지시로 해소됐다. 구현·검증·커밋 결과를 검토 담당에게 인계하며 제품 최종 완료 판정은 하지 않는다. 푸시는 사용자 화면 승인 대기이며 실행하지 않았다. hejo에 원격이 없으면 임의로 등록하지 않고 대상 미확정으로 보고한다. 재시작/reload·운영 hejo 연결·외부 발송·비밀 파일 열기는 하지 않았다.


### TASK-08 — 운영 캐시 auto (9판, 2026-11-15)

착수 전 허용 문서·기억 파일 외 미커밋 변경 없음, 처리 중 차례/작업 0을 확인했다(`.build/task08-preflight.json`). 루트와 모든 프로필 설정 **6개**의 `prompt_caching.cache_ttl`을 `auto`로 바꿨다. 변경 전 값·키/맵 존재 여부·권한·해시는 로컬 전용 `.build/task08-before.json`(0600)에 기록했다. 다른 키 내용은 출력하지 않았다.

ruamel로 허용 블록만 왕복 처리하고 임시 파일 쓰기→fsync→os.replace했다. 다른 데이터·텍스트·권한 불변을 파일마다 검증했다. 전체 문서 왕복의 최초 dry run은 무관한 서식 변경을 검출해 종료 1이었으며 운영 파일은 쓰지 않았다. 허용 블록만 왕복하도록 조정한 최종 dry run과 적용은 각각 종료 0이다. 재현 코드 `.build/task08/change.py`, 로그 `.build/task08-dry-run.log`·`task08-change.log`, 결과 `.build/task08-change-result.json`.

**적용 시점:** Hermes `agent/agent_init.py:665`의 `_init_prompt_cache_config`가 새 에이전트 생성 때 설정을 읽는다. `gateway/run_turn_runner.py:1055`의 캐시 재사용 경로와 `gateway/run.py:4434`의 캐시 무효화 키에 cache_ttl 갱신은 없다. 따라서 새 에이전트에는 생성 시 적용되고 기존 캐시된 대화에는 즉시 반영을 보장하지 않는다. 전체 운영 적용은 **다음 재시작(TASK-09) 때 확인**한다. 재시작/reload는 실행하지 않았다. 실제 외부 요청/비용 변화는 시험하지 않았다.

`./airport-check` → 옵션 없는 `./sync`는 각각 종료 0, 토큰 경고 없음이다. 로그 `.build/task08-airport.log`·`task08-sync.log`, 명령/결과 `.build/task08-operating-checks.json`. 원본과 사본 6개 해시 일치 및 허용 외 경로 없음 확인 후 **설정 사본 6개만** `git commit --only`했다. 운영 커밋 **`855149a4d1713804fec77bb2c8fd4ff370a6b04f`**, 종료 0, 로그 `.build/task08-commit.log`·`task08-commit.json`. 실제 프로필 경로가 포함된 파일 목록은 미추적 JSON에만 둔다. DDOTS 문서 두 개와 기억 파일은 그대로 보존했다.

AT-HF-30: 운영 원본 전부 auto·다른 키 차이 0·동기화 커밋 확인으로 증거 수준 3에 도달했다. 롤백은 before JSON에 따라 각 값을 복원하고 원래 없던 키/맵을 지운 뒤 같은 검증·동기화 절차를 따른다. 본체 수정·비밀 파일 열기·운영 hejo 연결·외부 발송·푸시는 없다.


### TASK-10 — HEJO. 로고 (9판, 2026-11-15)

`ConversationView` 로고를 속성 문자열 `HEJO.`로 바꿨다. H만 systemBlue, 나머지는 labelColor, 14pt semibold·가운데 정렬이다. 10pt 번들 버전 줄은 유지하고 방이 없을 때 머리글도 HEJO.로 바꿨다. AT-HF-52는 실제 ConversationView의 글자·색·글꼴·정렬·버전·빈 방 대체 글자를 확인한다. SwiftUI나 시안 파일 변경은 없다.

환경 지정 `bash app/scripts/test.sh`: 종료 **0**, AT-HF-52 및 기존 앱·네트워크·대화 시험 통과. 로그 `.build/foundation9-app-task10.log`, 명령/종료 코드 `.build/foundation9-app-task10.json`; 실행 환경은 `.build/foundation9_runner.py`에 있다. 임시 홈·대역 문만 사용했고 운영 페어링은 없다. 증거 수준 2다. 커밋 대상은 ConversationView.swift·ConversationTests.swift·이 보고서 세 파일이다.

### TASK-11 — 아일랜드 1단계와 일하는 중 글자 반짝임 (9판·보완 10, 2026-11-15)

**구현·자체 시험 완료, 검토 대기.** 기준은 `379a43edfe37cf3db88a98bab40735cd3d3c7423`의 9판 인계와 이후 승인된 보완 지시 10, REQ-HF-18·AT-HF-53~56이다. TASK-08 보고 커밋은 `9f4ae9303a5a94e16dd533167882456195c55c2e`, TASK-10은 `cc128208f844f6c5f800b11a49d372ad640e9b63`다. TASK-11 구현과 아래 증거를 별도 커밋으로 검토에 넘긴다. 제품 최종 완료·운영 연결·푸시는 별도다.

#### 변경과 책임

- `IslandModel.swift`: 주입 시계로 칸·질문/안 읽은 수·작성 중 경과·연결 안내·업로드·4초/3초 우선순위를 계산한다. 원본 메시지·읽음·초안은 기존 모델/컨트롤러에 남고 아일랜드에는 표시용 입력과 일시 상태만 둔다.
- `IslandView.swift`: AppKit 한 줄 30pt 알약, 44×12 빈 띠, 칸 구분선·첫 글자 얼굴·가로 전환·호버·클릭을 맡는다. 보완 지시 10에 따라 도는 고리를 없애고 글자 모양 마스크를 씌운 `CAGradientLayer`의 위치만 1.6초마다 왼쪽→오른쪽으로 옮긴다. 경과 시간 글자는 반짝임 대상에서 제외했다. 최대 너비에서는 직원 칸부터 압축한다. 동작 줄이기는 즉시 너비 전환·흐린 글자로 정지다. 여러 직원 얼굴은 각각 해당 직원으로 이동한다.
- `ConversationView.swift`·`ConversationChrome.swift`: 로고 오른쪽+12 배치와 제목 공간, 오래된 asked 카드 펼침·스크롤·1.5초 강조, 직원 이동·재접속·저장된 대상 재전송을 연결했다. 알약은 머리글 끌기에서 제외한다. 기존 연결 banner·답변 대기/알림 noticeBar와 해당 배치/갱신 코드는 제거했다.
- `ConversationController.swift`: 실패 문구·첫 말·재전송 대상과 첨부 k/n을 제공한다. 초안·확인 후 비우기·중복 전송 방지·HTTP 권한 검사·송신 크기 제한은 기존 경로를 유지한다. unknown_file·too_large 등 표시 위치는 notice에서 알약으로 옮겼고 다른 notice 용도는 유지했다.
- `IslandModel.swift`는 `GateClient.status == .tooLarge`도 문제 칸으로 표시한다. 서버 1009나 `error(too_large)` 뒤의 TASK-05 안내가 연결 띠 제거와 함께 사라지지 않도록 AT-HF-55 앱 시험으로 확인한다.
- 시험 파일은 `IslandTests.swift`, `ConversationTests.swift`, `TestMain.swift`, `conversation_fixture.py`다. 기존 대화 시험의 오류 관측 위치만 새 표시 원본으로 옮겼다. 대역 send 기대 횟수 5→6은 알약 재전송 동작 1회를 추가했기 때문이며, 기존 5회 동작·첨부/클릭/다운로드 검사는 유지한다. TASK-05의 AT47 기대값·대기 함수는 바꾸지 않았다.
- README와 `evidence/HEJO-FOUNDATION/TASK-11.md`·자동 PNG 두 장을 추가/갱신했다. 실제 수동 클릭·시스템 동작 줄이기·다중 화면·운영 연결 검사는 TASK-09에 남는다. 자동 캡처는 가짜 명부 AppKit 자료로 표시했다.

이번 구현은 설계·수락 명세·wire·gate·설치기·시안·다른 앱을 바꾸지 않았다. 계획 담당의 별도 커밋에서 보완 지시 10에 따른 REQ-HF-18·AT-HF-53/56이 갱신된 것을 확인하고 반영했다. 새 공개 계약/저장 형식·SwiftUI·외부 연결·임시 호환 경로는 없다. 새 코드의 상태 원본과 책임은 받은 설계대로다.

#### 실행 증거

환경은 `.build/foundation9_runner.py`에서 HEJO_PYTHON·HEJO_TEAM_KIT_LIB·PYTHONPATH를 지정하고 매 실행 임시 HERMES_HOME/HERMES_ROOT를 만든다. 실제 명령·종료 코드는 각 JSON에 있다.

| 실행 | 종료·결과 | 로그 |
|---|---|---|
| `bash scripts/test.sh` (최종 소스, 임시 홈·환경 지정) | **0** — gate/수락 80 passed, AT-22 리스너 1·배달 4·정상 종료, 기존 앱·AT-52~56·HTTP/WS 대역 통과 | `.build/foundation9-hejo.log`·동명 JSON |
| `bash app/scripts/test.sh` 10회 연속 (최종 소스) | **10/10 모두 종료 0**, 동일 앱 소스 해시; 각 회차에서 AT47·AT52~56·임시 HTTP/WS 대역 통과 | `.build/task11-repeat-verified.log`·`task11-repeat-verified-results.json`, `foundation9-app-task11-verified-01.log`~`10.log` |
| 최초 개발본의 `bash app/scripts/test.sh` 연속 시도 | **0, 0, 1** — AT47 펼침 완료 단언 실패로 즉시 중단. 이 소스는 최종 반짝임·too_large 보완 전이다 | `.build/task11-repeat.log`·`task11-repeat-results.json`, `foundation9-app-task11-01.log`~`03.log` |
| `python3 .build/task11_mutations.py` | 조정 실행 **0**; 답 요청 4초→1초 변형과 oldest→latest 이동 변형 모두 컴파일 0·대상 시험 **1**, 의도한 단언으로 검출 | `.build/task11-mutations.log`·`task11-mutations.json` 및 각 mutation 로그 |
| 기준 커밋 앱 단위 시험 진단 사본 30회 | **30/30 종료 0**. 진단 출력만 추가, 기대값 불변; 원래 간헐 실패의 자연 재현은 못 함 | `.build/task11-baseline-probe.log`·`task11-baseline-results.json`·`task11-baseline-probe/run-*.log` |
| 기준 커밋 펼침 중 화면 변경 알림 주입 | 컴파일 **0**, 대상 시험 **1**, 조정 스크립트 **0**. 진행 0·단계 0·타이머 있음에서 화면 변경 뒤 진행 0에 머물러 같은 단언 실패 | `.build/task11-screen-change.log`·`task11-screen-change.json` |

새 시험은 실제 AppKit 배치/클릭, 주입 시계 우선순위와 TTL, 글자 빛 띠의 0초/0.8초 위치·1.6초 반복·동작 줄이기 정지, 1009/too_large 문제 표시, 루프백 HTTP 업로드 진행, WebSocket 재연결 뒤 원래 방 재전송·성공 시 실패 표시 제거까지 확인했다. 최종 소스의 자동 캡처 두 장을 직접 확인했다. 증거 수준 **2**와 필수 연속 통과 조건에 도달했다. 초기 개발 중 문법 오류 두 건·시험 좌표계 오류·반짝임 시험의 접힌 너비 준비 오류는 수정했다. 실패 로그 `foundation9-app-task11-dev.log`·`dev2.log`·`task11-first-full-build-error.log`·`foundation9-app-task11-shimmer.log`·`shimmer2.log`를 최종 성공 로그와 구분해 보존했다.

#### 잔여 위험 T11-01: 기존 AT47 전환 완료의 간헐 실패

실패 위치는 `app/Tests/TestMain.swift:95`의 `transitionProgress == 1 && transitionSteps > 0` 단언이다. 이 단계는 대화/아일랜드 객체를 만들기 전이며, 이번 변경은 해당 시험 뒤에 아일랜드 시험 호출만 추가했다. 2초 조건 폴링과 기존 펫 제품 코드는 그대로다.

기준 커밋의 `PetController.swift:124` `screensChanged()`는 전환 타이머를 무효화하고 시각 상태를 마무리하지만 `transitionProgress`를 완료 값으로 갱신하지 않는다. 펼침 중 그 알림을 주입하면 같은 단언 실패를 결정적으로 재현했다. **최초 자연 발생 실패에 그 알림이 왔다는 관측은 없으므로 원인 확정은 아니다.** 기준 단위 진단 30회는 통과했고, 최종 변경본의 10회 연속 시험도 통과했다. AT47 기대값·대기 함수·펫 제품 코드는 바꾸지 않았다. 이 간헐 위험은 후속 검토에서 실제 알림/전환값을 기록해 판단할 수 있다. TASK-09의 수동 펼침·다중 화면 확인에도 인계한다.

게이트웨이 Python의 `scripts/scan_private.py`, `bash githooks/pre-commit`, `git diff --cached --check`는 각각 종료 **0**, 개인값 위반 **0**이다. 앱 소스 해시는 최종 10회 반복 결과와 같고 `import SwiftUI`는 0건이다. TASK-11에서 gate·schemas·install·수락 명세·펫 전환 소스·시안은 수정하지 않았다. 정적 검사 명령·종료 코드·로그는 `.build/task11-final-checks.json`과 `.build/task11-final-{scan,hook,diff}.log`에 있다.

운영 커밋은 TASK-08의 `855149a4d1713804fec77bb2c8fd4ff370a6b04f`다. 허용 밖 운영 변경 없음과 DDOTS 문서 바이트 보존을 확인했다(`.build/task11-operating-status.json`·`task11-preservation.json`). 기억 파일은 열거나 수정하지 않았다. V-5 및 과거 공개 이력 개인값 부채는 유지한다. 재시작/reload·비밀 파일 열기·운영 hejo 연결·외부 발송·푸시는 없다. TASK-11 커밋 정보는 `.build/task11-git-final.json`에 남긴다.

### TASK-12 — 대화 안 작성 중 표시 (9판·보완 11, 2026-11-15)

**구현·자체 시험 완료.** 실행 담당이 착수하지 않아 사용자 지시("남은 순서도 너가 모두 직접 해라")로 계획 담당이 직접 구현했다. 기준 커밋 `9c2b9068af9c74d1d0cbdf48ebe6f32fa5ccf771`, 근거는 REQ-HF-19·design 6절·AT-HF-57.

#### 변경과 책임

- **`Shimmer.swift`(새 파일): 공용 반짝임 부품 `ShimmerLayer`.**
  - 글자 마스크 위의 빛 띠를 1.6초 주기로 옮긴다. 움직이는 것은 띠 위치뿐이다.
  - `IslandView`는 자체 반짝임 층 세 개를 이 부품으로 바꿨다. 동작은 같으며 AT-53·56으로 확인했다.
- **`TypingRow.swift`(새 파일): 대화 안 기다림 줄.**
  - 높이 22, x=43 그대로다.
  - "작성 중"은 흐린 바탕 글자 위에 `ShimmerLayer`를 얹고, 옆에 흐린 경과 초를 쓴다.
  - 시계, 애니메이션 시각, 동작 줄이기는 주입받는다.
  - 창에 붙어 있을 때만 30fps 타이머를 돌린다.
- **`ConversationModel`:** `typingSince[key]`를 둔다.
  - 꺼져 있다가 켜질 때 기록하고, 갱신(on 재수신)으로는 바꾸지 않는다.
  - `on:false`, 만료, 복제본 초기화 때 지운다.
  - 경과 초의 원본이다.
- **`ConversationView`:** 작성 중 accessory를 `TypingRow`로 바꿨다.
  - `motionTime`·`reduceMotion` 주입 지점을 추가했다.
  - 표시 조건(작성 중이고 흘러나오는 글이 없음)은 바꾸지 않았다.
- **`NativeThreadCard.Text`: 흘러나올 때 커서.**
  - 별도 2pt `systemBlue` 하위 보기다. 마지막 글자 glyph의 오른쪽에 놓이고 줄 높이를 쓴다.
  - 문자열·속성·`streamHeights`·Layout 계산에는 들어가지 않는다.
  - 0.5초 켜짐/꺼짐으로 깜빡이고, 동작 줄이기면 켜진 채 멈춘다.
  - `setText`가 `streaming`일 때만 켜므로 final 편집에서 꺼진다. 숨는 글 보기도 끈다.
  - 부드러운 덧붙임(`softenAppend`)은 그대로다.
- **중지 버튼:** hejo 앱에는 지금 중지 버튼이 없다(grep 0). 그래서 유지할 대상이 없고, 새로 만들지도 않았다.
- **시험:** `Tests/TypingTests.swift`(AT-HF-57 a~d와 typingSince 수명), `TestMain.swift` 호출 한 줄을 더했다. 자동 캡처 두 장은 `evidence/HEJO-FOUNDATION/TASK-12.md`에 있다.

#### 실행 증거

환경은 `.build/foundation9_runner.py`다. HEJO_PYTHON·HEJO_TEAM_KIT_LIB·PYTHONPATH를 지정하고, 실행마다 임시 HERMES_HOME을 만든다.

| 실행 | 종료·결과 | 로그 |
|---|---|---|
| 첫 빌드 | 1: `CALayer.position` 이름 충돌 컴파일 오류. 속성 이름을 `bandX`로 바꿔 해결 | `.build/task12-app-1.out` |
| `bash app/scripts/test.sh` 10회 연속(최종 소스) | 10/10 모두 0, 매 회 AT-HF-52~57 PASS | `.build/task12-repeat.log`, `.build/task12-app-01.log`~`10.log` |
| `bash scripts/test.sh`(최종 소스) | 0: gate 80 passed, AT-22 정상 종료, 앱·네트워크·HTTP/WS 대역 통과, AT-HF-57 PASS | `.build/task12-hejo.log` |
| 게이트웨이 Python `scripts/scan_private.py` | 0 | `.build/task12-scan.log` |
| `import SwiftUI` 수 / `git diff --check` | 0 / 0 | — |

최종 소스 해시는 `.build/task12-source-hashes.txt`에 있다. 증거 수준은 2다.

**미실행:** 실제 직원 답의 반짝임·깜빡임 눈 확인과 밝은 모드 가시성. 이 둘은 TASK-09 수동으로 넘긴다.

**하지 않은 것:** gate·wire·설치기·명세·시안 수정, 운영 `~/.hermes` 변경, 재시작, 비밀 파일, 외부 발송, 푸시.


### TASK-09 1단계 — 게이트웨이 재시작 (2026-11-15, 사장 지시 "재시작해")

- **사전 확인:** `gateway_state.json`에서 active_agents 0, active_work 0이었다. 운영 저장소의 미커밋 파일은 허용된 DDOTS 문서 2개와 직원 기억 파일 1개뿐이다.
- **재시작:** `hermes --profile default gateway restart`, 종료 0.
  - 새 프로세스 시작 시각은 02:12:25이다. team-kit `hermes_reply/plugin.py`가 바뀐 시각(23:43)보다 뒤라서, 새 코드가 로드됐다.
- **재시작 뒤 확인:** `gateway.log`에 `✓ slack connected`가 6번(루트와 프로필 5개), `✓ photon connected`가 있다. "Gateway running with 7 platform(s)"이다.
  - `gateway.error.log`에는 재시작 이후 새 줄이 0개다.
- **함께 적용된 것:**
  - team-kit 답장 버튼(`392a2afb`)
  - 캐시 auto(`855149a4`)
- **아직 하지 않은 것:** hejo 문 설치(`install/hejo-install`). 설치 뒤에는 한 번 더 재시작해야 한다. 노트북 페어링과 실물 확인도 남았다.

### TASK-09 2단계 이후 — 설치기 수정·설치·재시작·실물 확인 (2026-11-15, 사장 지시 "마지막 단계까지")

- **설치기 결함·수정 (hejo `a30c28b`)**
  - **결함:** 전체 ruamel 왕복이 운영 설정 6개를 각각 6~452줄 다시 썼다. YAML 1.1 reader에서 따옴표가 빠진 값의 뜻이 바뀔 위험도 있었다.
  - **수정:** 바이트 그대로 왕복되지 않는 파일은 대상 줄만 고친다(목록 항목 추가·삭제, 매핑 끝 삽입, 빈 인라인 부모 한 줄 교체). `hermes_yaml.safe_load`로 다시 읽어 hejo 키 밖 차이 0을 검증한다. 모양이 맞지 않으면 쓰지 않고 거부한다.
  - **시험:** `tests/acceptance/test_install.py`가 15개 통과했다(새 3개 포함). 환경 지정 `bash scripts/test.sh`는 0이다(gate 83, `.build/task09-installer-hejo.log`).
- **운영 설치와 기록**
  - 운영 설치: 6개 설정에 hejo 줄만 더해졌고, `--check`는 0이다(`.build/task09-install.log`).
  - 운영 저장소: `./airport-check` 0, `./sync` 0, 설정 사본 6개만 `--only` 커밋 `8fad28e65ada45da578fa8ea1fe3af73723fa6c7`. 원본과 사본 일치를 확인했다.
- **재시작 ②**
  - 13 플랫폼(hejo 6, Slack 6, photon 1)이다. `127.0.0.1:47820` 리스너가 1개이고, 오류 로그 새 줄은 hejo와 무관한 기존 homeassistant 경고 1건뿐이다.
- **실물 확인 (루프백)**
  - `.build/task09/e2e.py`: 기본 직원 5회, 보조 직원 1회. 실제 답, 작성 중 표시, 다시 받기 순서를 확인했다(`.build/task09-e2e*.json`).
  - `.build/task09/files.py`: 첨부 업로드·읽기·다운로드, 무출입증 401(`.build/task09-files.json`).
  - 시험 기기 3개는 모두 취소했다(활성 0).
- **되돌림**
  - 설치 전 사본으로 설치·제거를 돌렸다(`.build/task09/uninstall-dryrun.sh`). 설치 결과는 운영 파일과 바이트가 같았고, 제거하면 원본과 바이트가 같았다.
- **남은 것:** 노트북 Tailscale·눈 확인 항목. `evidence/HEJO-FOUNDATION/TASK-09.md` 체크리스트에 있다.

### TASK-13 — 자동 연결 (10판, 2026-11-15, 사장 선택 "자동 연결")

- **변경:** 커밋 `b2d3b8b`.
  - 문 `auth.local_code`·`pair(local=True)`·`pair_trusted`, `server` hello `auto`·연결 주소 판정, `tailnet.owner_device`
  - 규격 hello 세 번째 변형과 거부 이유 `untrusted`
  - 앱 `AirportFinder`, `GateClient.autoPair`, 연결 창 "자동으로 찾기"와 기기 이름 기본값(Mac 이름), 첫 실행 자동 찾기
- **시험:** 환경 지정 `bash scripts/test.sh` 0이다(gate 86, AT-HF-58·59 앱 PASS, `.build/task13-hejo.log`). pre-commit과 diff --check도 0이다.
- **운영 적용**
  - 게이트웨이를 재시작했다(16:37, 13 플랫폼). `local-pair.json`이 0600으로 생겼다. 리스너는 루프백과 Tailscale 2개다.
  - 맥미니 앱을 다시 빌드·설치·실행했더니 **입력 없이 페어링**됐다. `gate.cli status` 활성 기기 1, 앱 주소 `127.0.0.1:47820`.
- **남은 것:** 노트북 실물(AT-59 실물). 앱을 복사해 실행하면 Tailscale로 공항을 찾아 붙어야 한다.

### TASK-14 — 사장 계정 로그인, 각자 자기 공항 (10판 개정, 2026-11-15)

- **사장 결정:** 자동 입장은 없앤다. 로그인은 아이디·비밀번호와 Google 둘 다 둔다. 재설정은 Google과 공항 Mac에서 한다. 전화 인증은 하지 않는다. 각자 자기 공항을 두고 누구나 가입한다. 맥미니에는 macOS 사용자별 공항이 둘이다(관리자 ↔ 맥북프로, 다른 사용자 ↔ 맥북에어).
- **커밋:** `c8557f7`(계정 1차), `6771b55`(첫 가입·공용 Google·여러 공항). TASK-13 자동 입장은 이 작업으로 대체됐다.
- **시험:** 환경 지정 `bash scripts/test.sh` 0이다(gate 88, AT-HF-57·58·59 PASS, `.build/task14-hejo.log`). pre-commit과 diff --check도 0이다.
- **운영 적용 (관리자 공항)**
  - 활성 기기를 모두 취소했다(이전 자동 입장 기기 포함). 게이트웨이를 재시작했고(17:05, 13 플랫폼, 오류 새 줄 0) 앱을 다시 빌드·설치했다.
  - `/v1/auth`는 계정 없음, Google 클라이언트 없음, 공항 이름 있음이다.
  - 맥미니 화면 캡처로 "가입하기" 창(아이디·비밀번호·확인·가입)이 뜬 것을 확인했다.
- **남은 것**
  - 사장이 가입한다.
  - 공용 Google 데스크톱 OAuth 클라이언트를 등록하고 ID·비밀을 넣은 뒤 다시 빌드한다.
  - 다른 사용자 공항에 hejo를 설치한다(그 macOS 세션에서).
  - 노트북 실물을 확인한다.

### TASK-15 — 허브와 회원 (11판, 2026-11-15, 사장 결정 B)

- **사장 결정:** 회원마다 따로 가입하고, 각 Hermes는 그 회원의 hejo로 쓰고, 설정도 회원마다 둔다. 맥미니 하나를 서버로 쓴다.
  - 맥북에어(다른 Mac 계정 회원)에는 앱만 깔고, 그 회원 Hermes에는 연결 부품을 한 번 넣는다.
- **커밋:** `ae9ce0c`(허브·문 연결·설치기·앱), `095b18c`(운영자 연결).
  - 허브: `hub/` 회원·기기·설정·Google·문 API
  - 문: `gate/hub.py` 토큰 확인·포트 등록·증표 재설정. 계정 코드는 허브로 옮겼다.
  - 설치: `install/hejo-release`, `hejo-hub`, `hejo-join`, `hejo-install --hub/--port`
  - 앱: `HubClient`, `LoginWindow`, `GateClient.adopt`, 회원 설정(펫 이름) 동기화
- **시험:** 환경 지정 `bash scripts/test.sh` 0이다(gate+hub 91, AT-HF-58·59·60 앱 PASS, `.build/task15-hejo.log`). 허브 시험 7개, 설치기 17개, pre-commit 0, diff --check 0.
- **운영 적용 (관리자 Mac 계정)**
  - `hejo-release`로 공용 폴더에 배포했다(RELEASE = `095b18c`).
  - `hejo-hub`를 launchd 에이전트로 올렸다(127.0.0.1·Tailscale 47800, `/v1/hub` 응답 확인).
  - 관리자 Hermes를 작업 트리에서 공용 복사본으로 다시 설치했다(`--uninstall` 뒤 `--port 47820`). 설정 6개는 이전과 바이트가 같고 링크만 공용 복사본으로 바뀌었다. 그래서 운영 저장소에 커밋할 것은 없다.
  - 게이트웨이를 재시작했다(17:34, 13 플랫폼, 오류 새 줄 0).
  - 앱을 다시 빌드·설치하고 로컬 설정을 초기화했다. 맥미니 화면에서 "hejo 로그인"(허브 찾음)을 확인했다. 앱 사본은 공용 폴더 `hejo/hejo.app`에 있다.
- **남은 것**
  - 관리자 회원 가입 → 운영자 연결(`python -m hub --link`) → 재시작
  - 다른 사용자: 노트북에서 가입하고, 서버 Mac의 그 사용자 계정에서 `hejo-join`을 실행한다
  - 공용 Google 클라이언트 등록
  - 노트북 실물 확인

### TASK-17 — ddots 기능 이식 1단계 (12판·보완 12-1·12-2, 2026-11-15)

**구현·자체 시험 완료, 최종 검토 대기.** 받은 설계는 `handoff.md`의 보완 지시 12·12-1·12-2, 기준 커밋 `de6170203c42adf31c9aff9924ecb047b7898c4f`다. 진행 중 추가된 계획 커밋의 메뉴·알림 기준을 반영했다. 위험도 일반, 필요·도달 증거 수준은 2다. 실제 운영 앱의 설치·실행은 별도로 확인했지만 실제 직원·다른 Mac 동작을 증거 수준 4로 주장하지 않는다. 제품 변경 커밋은 `e90681281196be1b66f18c3b934b41cbd5d0c1fb`다.

- `PetController`·`LocalSettings`: 대화 창 크기 저장·복원, 머리줄 두 번 클릭 넓게 전환, 설정 창 초기화, 펼친 스레드에 맞는 화면 내 자동 높이, 펫 크기와 위치를 맡는다. 창 위치·크기는 이 Mac의 설정에만 둔다.
- `BubbleReveal`·`PetView`·`PetActivity`: 접힌 펫 말풍선의 3초/호버/항상 보이기/스레드 열기와 사장 차례·작성 중·전송·실패·3분 졸기·동작 줄이기·화면 잠금 정지를 맡는다.
- `PetSettingsWindow`·`AppDelegate`: AppKit 일반/화면과 펫/계정 페이지, 자주 쓰는 명령만 있는 펫·상태 막대 메뉴, 다시 실행 ⌘⇧Z를 연결한다. 펫 이름·크기·말풍선 선호와 고정·알림·숨김은 기존 허브 회원 설정 키에 저장하며, 로컬 값은 오프라인 화면용 복제본이다. `ConversationView`는 검색을 먼저 닫는 Esc와 직원·빈 곳·머리줄의 각 우클릭 메뉴를 맡는다. 숨긴 방의 글은 보존하고 새 글에 다시 보이며, 마지막 방을 숨기면 선택만 비운다. 알림 끈 직원의 안 읽은 수는 회색으로 남기되 펫·아일랜드 안 읽은 합계와 강조에서 제외하고, asked 건수는 남긴다.
- `copy-review.md`에 ddots 원본 파일별 전체 검토·유지 의존·Slack 제거 경계를 기록했다. ddots와 Hermes 본체는 수정하지 않았고, SwiftUI·Slack 호출은 앱에 들이지 않았다.
- `app/scripts/test.sh`는 시험 빌드에 `HEJO_SKIP_GOOGLE_SECRET=1`을 지정한다. 제품 빌드의 기존 동작은 유지하면서 시험이 미추적 OAuth 비밀 설정 파일을 자동으로 읽지 않게 한 경계다.

| 실행·관측 | 종료 코드·결과 | 로그·증거 |
|---|---|---|
| `python3 .build/foundation9_runner.py hejo` (임시 `HERMES_HOME`, Hermes Python·team-kit 경로 지정) | **0**; gate·hub·수락 93 passed, AT-HF-22 정상 종료, 앱 AT-HF-61~65·67와 기존 대역 시험 통과 | `.build/foundation9-hejo.log`·`foundation9-hejo.json` |
| `bash app/scripts/test.sh` 10회 연속 (같은 최종 소스, 임시 `HERMES_HOME`) | **10/10 모두 0**; 매 회 AT-HF-61~65·67 및 대화 HTTP/WebSocket 대역 시험 통과 | `.build/task17-app-repeat-results.json`, `.build/task17-app-repeat-01.log`~`10.log` |
| 게이트웨이 Python `scripts/scan_private.py`, `githooks/pre-commit`, `git diff --cached --check`, SwiftUI import 검색 | **각 0**; 개인값 위반 0·SwiftUI import 0건 | `.build/task17-scan-final.log`, `task17-hook-final.log`, `task17-swiftui-check.log` |
| 앱 시험 실행 파일의 창 단위 `screencapture` | **0**; 가짜 직원 말풍선·화면과 펫·계정 창 직접 확인 | `evidence/HEJO-FOUNDATION/task17-bubble.png`·`task17-settings.png`·`task17-account.png`, `.build/task17-capture-final.log` |
| 우클릭 메뉴 화면 캡처 3종 | **각 0**; 직원·빈 곳·머리줄 메뉴 직접 확인. 화면 전체에 다른 앱이 섞여 비추적 `.build/`에만 보관 | `.build/task17-menu-{employee,blank,header}.log`, `.build/task17-menu-captures/` |
| 서명된 앱 두 사본 적용·실행 | **0**; 설치 전 백업, 두 사본 코드 서명·실행 파일 해시 일치, 앱 프로세스 1개 실행 확인 | `.build/task17-deploy.log`, `.build/task17-release-binary-hashes.log` |

초기 반복 시도 한 번은 `HOME`까지 임시로 바꾸어 로컬 서명 인증서를 못 찾아 종료 1이었다(`.build/task17-app-repeat-env-fail.log`). `HOME`은 유지하고 `HERMES_HOME`만 임시로 바꾼 뒤 위 10회가 연속 통과했다. 또한 초기 직접 빌드/시험 호출에서 기존 빌드 스크립트가 미추적 OAuth 비밀 설정 파일을 **간접 읽었다**. 에이전트가 그 내용을 열거나 출력하지는 않았으나 금지 경계 위반 가능성을 발견해 사용자에게 알렸고, 시험 경로를 고쳐 최종 전체·반복 시험은 그 파일을 읽지 않게 했다. 설치 후보는 앞서 만들어진 서명 번들의 설정을 불투명하게 보존하고 최종 시험 소스의 실행 파일로 교체해 다시 서명했다. 이 경위를 검토 대상으로 남긴다.

실제 회원 설정의 다른 Mac 간 동기화, 물리 다중 화면·잠금, 실제 직원 메시지에서의 말풍선·펫 동작, 우클릭 메뉴의 실사용 조작은 자동 대역·캡처 범위 밖이다. 앱 적용 과정에서 게이트웨이 재시작·reload, 허브·운영 설정 변경, 외부 발송, 다른 저장소 수정, 공개 브랜치 갱신, 푸시는 하지 않았다.

### TASK-17 V-1 — 이전 메뉴 동작 정리 (2026-11-15)

`AppDelegate.swift`에서 호출처가 없는 여섯 메뉴 메서드를 제거했다. 설정 창의 로그인 항목·펫 위치·창 크기 콜백은 유지했다. 코드 커밋은 `39f7e4bc9fcadfab44b9dcebc477cac060503a01`이며 `HEJO_PYTHON`·`PYTHONPATH` 지정 `bash app/scripts/test.sh` 종료 0(`.build/task18-v1-app.log`), Hermes Python `scripts/scan_private.py` 종료 0(`.build/task18-v1-scan.log`)이다. 시험 기대값과 기존 화면은 바꾸지 않았다.

### TASK-18 — HEJO. 앱 아이콘 (2026-11-15)

AppKit `AppIcon.render(pixels:)`가 투명 1024px 캔버스의 흰 둥근 사각형과 파란 `H`·어두운 `EJO.`를 그린다. 빌드가 16~1024px 아이콘셋 10장을 `.build/`에 생성하고 `iconutil`로 `AppIcon.icns`를 번들에 넣는다. plist의 `CFBundleIconFile`은 `AppIcon`이다. 런타임 Dock 아이콘 설정과 기존 앱 로고는 변경하지 않았다. 제품·시험·빌드 커밋은 `e485b2276bdc0ba6c618a27383d0f92b261aa109`이며 PNG·icns·글꼴 파일은 커밋하지 않았다.

| 실행·관측 | 종료 코드·결과 | 로그·증거 |
|---|---|---|
| `HEJO_SKIP_GOOGLE_SECRET=1 bash app/scripts/build.sh`, `iconutil` 왕복, `plutil -extract CFBundleIconFile raw` | **각 0**; iconset 10장·번들 icns·`AppIcon` 키 확인 | `.build/task18-build.log`, `app/.build/AppIcon.iconset/`, `app/.build/task18-preview.png` |
| 임시 `HERMES_HOME`·Hermes Python으로 `app/scripts/test.sh` 10회 연속(최종 소스, 02~11) | **10/10 모두 0**; AT-HF-66·AT-HF-61~65·67 통과 | `.build/task18-app-repeat.log`, `.build/foundation9-app-task18-02.log`~`11.log` |
| `python3 .build/foundation9_runner.py hejo` | **0**; gate·hub 93 passed, AT-HF-22 정상 종료, 앱 AT-HF-66 통과 | `.build/foundation9-hejo.log`, `.build/foundation9-hejo.json` |
| Hermes Python `scripts/scan_private.py`, `githooks/pre-commit`, `git diff --cached --check`, SwiftUI import 검색 | **각 0**; 개인값 위반 0·SwiftUI import 0건 | `.build/task18-scan-final.log`, `.build/task18-precommit-final.log`, `.build/task18-swiftui.log` |
| 서명 후보 생성·앱 두 사본 적용·Finder 캡처 | **각 0**; 두 앱 서명 및 아이콘 해시 일치, 실행 프로세스 1개 | `.build/task18-candidate-sign.log`, `.build/task18-deploy.log`, `app/.build/task18-finder.png` |

1024px와 16px 그림을 직접 확인했다. 첫 개인값 검사에서는 아이콘셋의 `@2x` 파일명이 이메일로 오인되어 종료 1이었고, 생성 파일명 표기를 유니코드 이스케이프로 바꾼 뒤 최종 검사에서 위반 0을 확인했다. 설치 후보는 기존 설치본의 plist를 내용을 출력하지 않고 복사해 아이콘 키만 추가한 뒤 다시 서명했다. Finder 선택 항목에서 새 아이콘을 확인했다. 이 앱은 `LSUIElement`이므로 실행 중 Dock 타일이 없으며 Dock 표시 여부는 실물에서 별도 관찰할 수 없다. Finder의 아이콘 보기 전환은 macOS 자동화 권한으로 거부되어 목록 보기 캡처를 남겼다. 게이트웨이·허브 재시작, 운영 설정·다른 저장소 수정, 외부 발송, 공개 브랜치 갱신, 푸시는 하지 않았다.

### TASK-19 — 코드 정리 (보완 지시 13-2·13-3, 2026-11-15)

`app/Sources`의 선언 이름을 앱 소스·시험 전체에서 조회하고, `gate/`·`hub/`·`install/`의 Python 최상위 정의도 전역 참조를 검사했다. 아래는 호출처가 없는 앱 코드만 지운 결과다. 줄 수는 정리 전후 `git diff --numstat`의 삭제 행 기준이다.

| 파일 | 지운 이름·역할 | 삭제 행 |
|---|---|---:|
| `ChatStyle.swift` | `callerAvatar`, `notificationAvatar`, `thumbnailPixels`, `avatarNameGap`, `speakerInset`, `replyInset`, `PaletteRGB.hsl` | 13 |
| `ConversationChrome.swift` | `searchHeight`, `topInset` | 2 |
| `ConversationView.swift` | 옛 머리줄의 `collapseConversation` 셀렉터 | 1 |
| `MessageFormat.swift` | `uniformSize`, `sizes`, `extended` | 11 |
| `NativeThreadCard.swift` | `reportHeight`, `statusTitle`, `diagnosticButtonFrames`, `firstText` | 8 |
| `PetAnimation.swift` | `allowsLook`, `dragAnimation`, `dozeZs` | 14 |
| `PetLayout.swift` | `maximumChatSize`, 옛 오른쪽 창의 `defaultPaneWidth`·`defaultPaneHeight`·`paneHeight`·`minimumPaneWidth`·`usablePaneWidth`·`paneSplit`, 옛 말풍선 버튼의 `actionRowHeight`·`maximumActions`·`bubbleSize(actionCount:)`·`actionRects`, `effectiveScale`, `perchRect`, `ChatWidthSlide`, `PetBubbleMotion`, `GeniePictureKey` | 120 |
| `PetSpritePresentation.swift` | `contentBounds` | 5 |
| `PetSpriteRasterizer.swift` | `cachedCount` | 1 |
| `PetState.swift` | 포커스 탐지에서만 쓰던 `Provider`, `WorkState.rank` | 16 |
| `ProfileAvatar.swift` | `hasProfileColor` | 1 |
| `ScreenFocus.swift` | 쓰이지 않는 `ScreenTarget`·`ScreenFocus`·`ScreenWindow`·`ScreenWindowSelection` 묶음 | 83 |
| `ScreenWindowResolver.swift` | 쓰이지 않는 `ScreenWindowResolver` | 32 |

남긴 후보는 AppKit·대리자 메서드(`cancelOperation`, 드래그·텍스트·메뉴·URL 세션 콜백), `CodingKeys`, 셀렉터로 부르는 버튼 동작, 응답 체인의 `pasteAsPlainText`·`pasteAsRichText`다. `AppIcon.render`는 빌드 도구와 시험이 사용한다. `gate/`·`hub/`·`install/`에서는 시험과 동적 등록을 포함해 안전하게 지울 미참조 최상위 정의가 확인되지 않아 제품 코드를 바꾸지 않았다. 기존 시험 기대값은 변경하지 않았다.

| 실행·관측 | 종료 코드·결과 | 로그 |
|---|---|---|
| `python3 .build/foundation9_runner.py hejo` (임시 `HERMES_HOME`) | **0**; gate·hub·수락 93 passed, AT-HF-22 및 앱·네트워크 대역 통과 | `.build/task19-full.log`, `.build/foundation9-hejo.log` |
| `python3 .build/foundation9_runner.py app-task19` (임시 `HERMES_HOME`, 내부 명령 `bash app/scripts/test.sh`) | **0**; 앱 시험·네트워크 대역 통과 | `.build/task19-app.log`, `.build/foundation9-app-task19.log` |
| Hermes Python `scripts/scan_private.py`, `githooks/pre-commit`, `git diff --check` | **각 0**; 개인값 위반 0·공백 오류 0 | `.build/task19-scan.log`, `.build/task19-precommit.log` |
| 서명 후보 생성·앱 두 사본 교체·실행·독립 서명/해시/프로세스 확인 | **각 0**; 서명 2개·실행 파일 해시 동일·앱 프로세스 1개 | `.build/task19-deploy.log`, `.build/task19-install-verify.log` |

기본 `python3 scripts/scan_private.py` 첫 실행은 환경에 `ruamel`이 없어 종료 2(`.build/task19-scan-initial.log`로 보존); 기존 Hermes Python으로 재실행해 종료 0을 확인했다. 설치 후보는 시험 빌드에 기존 설치본의 plist를 내용을 표시하지 않고 복사해 기존 로그인 설정을 보존하고 다시 서명했다. 게이트웨이·허브 재시작, 운영 설정·다른 저장소·공개 브랜치 변경, 외부 발송, 푸시는 하지 않았다.

### TASK-22 — hejo 홈 채널 설치·갱신·안전한 제거

1. **받은 설계:** handoff 보완 14-1·15, design의 'hejo 홈 채널'(16판), AT-HF-72와 계획 검증 C1. 기준 `e9a4285c12ebbe2f6fa7a48d06c923a9b7a775b7`, 연합개발·고위험. 필요 증거는 구현 인계 수준 **2**, 최종 수락 수준 **4**다.
2. **구현자 판단:** TASK-22 구현·자체 시험 완료. 운영 적용·실물 수락과 독립 검토는 미실행이다. TASK-20·21은 아직 착수하지 않았다.
3. **구조·변경:** `install/hejo-install`이 기존 영수증 version 1 안에 `owner_may_change` 홈 채널 대상을 저장한다. 새 설치·옛 installed 영수증 갱신 모두 최상위 `platforms.hejo.home_channel`이 없는 프로필에만 쓴다. 이름은 허용된 직원 id 대체값을 사용한다. pending 영수증 선저장 → config → applied 순서이며, 기존 대상·`configs.before`는 유지한다.
4. **더한 것·지운 것:** 기존 installed 즉시 반환을 빠진 홈 채널 갱신으로 교체했다. 명령 시작의 맞춤, released 소유권 포기, 키 단위 되돌림, `--uninstall-home-channel`, 점검의 `missing_target`/`owner_set`을 추가했다. README·문의 설정 설명도 같은 키로 맞췄다. 파일 전체 복원은 기존 일반 설치 대상의 되돌리기에만 남겼으며, 홈 채널 소유권이 남았거나 원문과 현재 홈 채널이 다르면 그 최적화를 쓰지 않는다.
5. **설계와 차이:** 없음. C1대로 config 읽기·쓰기 실패는 종료 1이며 해당 대상은 applied로 남는다. `--force`도 사장 홈 채널 변경값을 지우지 않는다. 옛 원문에 있던 사장 값이 갱신 전에 삭제된 경우, 갱신 제거가 그 옛 값을 되살리지 않도록 시험을 더했다.
6. **덧대기·임시 코드:** 별도 영수증·설정 원본·우회 설치 경로 없음. 기존 원자적 쓰기·줄 단위 YAML 편집에 홈 채널 키를 통합했다. pending/applied/released/removed는 중단 복구와 소유권 판단에 쓰이며 임시 분기가 아니다.
7. **성격:** 의미 변경. 설치가 홈 채널도 설정하며, 재설치는 기존 연결을 보존한 채 빠진 값만 보강한다. 갱신 실패는 이번 대상만 키 단위로 되돌리고 installed를 유지한다.
8. **시험:** `test_install.py`에 AT-72 실행 시험 15사례를 추가했다. 기본+보조 2개 설치·재설치·기존 사장 값·제거, 옛 영수증의 점검·갱신·두 번째 프로필 쓰기 실패, 중단 3지점에서 재설치/즉시 제거, 읽기 전용 점검, A/B/C 롤백·재설치, C1 읽기/쓰기 실패, 사장 삭제값·강제 제거·맞춤 직후 사장 변경·옛 사장 값 비복원을 보호한다. 기존 수락 기준·기존 실행 시험 기대값은 바꾸지 않았다. 영수증 선저장 제거·쓴 값 맞춤 오판·삭제 직전 사장 값 검사 제거의 3 mutation은 각각 시험 실패(종료 1)로 검출했고 소스를 원복했다.
9. **증거:** 필요한 수준 **2**, 도달 수준 **2**(임시 HERMES_HOME에서 실제 설치 도우미·가짜 프로필 실행). 아래 검증은 동일한 최종 제품·시험 소스로 직접 실행했다. 다른 에이전트는 쓰지 않았다.

| 명령·관측 | 실제 결과 | 로그 |
|---|---|---|
| `python3 .build/foundation9_runner.py task22-install <저장소>/tests/acceptance/test_install.py` | 종료 **0**, 설치 시험 **32 passed** | `.build/task22-focused.log`, `.build/foundation9-task22-install.log` |
| `python3 .build/foundation9_runner.py hejo` | 종료 **0**, pytest **108 passed**, AT-22 가짜 게이트웨이 정상 종료, 앱·HTTP/WebSocket 대역 통과 | `.build/task22-full-final.log`, `.build/task22-full-detail.log` |
| `python3 .build/task22_legacy.py` | 종료 **0**, 기준 커밋의 실제 옛 설치 소스로 만든 영수증 → missing_target 3개 → 갱신·점검·제거 통과 | `.build/task22-legacy.log` |
| `python3 .build/task22_mutation.py` | 실행기 종료 **0**, mutant 3종 각각 pytest 종료 **1**, 소스 원복 확인 | `.build/task22-mutation.log`, `.build/task22-mutation-results.json`, `.build/foundation9-task22-mutant-*.log` |
| Hermes venv Python `scripts/scan_private.py`, `HEJO_PYTHON` 지정 `sh githooks/pre-commit`, `git diff --check` | 각각 종료 **0** | `.build/task22-check-results.json`, `.build/task22-{scan,precommit,diff-check}.log` |
| `rg -n '^\s*import\s+SwiftUI\b' app/Sources` | 검색 종료 **1**(일치 없음), import **0건** | `.build/task22-swiftui.log` |

10. **미검증·적용:** 운영 홈에서 설치 도우미·게이트웨이 재시작/reload는 실행하지 않았다. 실물 첫 응답 확인은 TASK-23이다. 앱 소스 변경이 없어 10회 반복·새 화면 캡처·앱 사본 교체는 해당하지 않는다. 공용 릴리스는 커밋 뒤 `install/hejo-release`로 갱신하고 결과를 `.build/task22-release.log`에 남긴다. 실제 Slack·고객 발송, 비밀 파일 열기, Hermes 본체·ddots 수정, 허브 코드·public 브랜치 변경, push 없음.
11. **부채:** 기존 전체 시험의 비동기 pytest 표시·Swift Sendable 경고는 이번 변경과 무관하여 그대로 남겼다.
12. **검토 요청:** 맞춤 표의 pending+없음과 applied+없음 구분, check가 영수증을 쓰지 않는 경로, config 삭제 실패 뒤 applied 보존, 사장 값과 설치 전 원문을 갱신 실패·제거가 건드리지 않는지 확인할 것.
13. **대상 변경본:** main의 TASK-22 단독 커밋(이 절을 포함한 커밋). 실제 전체 해시·릴리스 결과는 최종 인계의 pushTargets·checks로 전달한다. 다음 구현은 승인된 순서대로 TASK-20 → TASK-21이다.

초기 집중 시험 호출 한 번은 runner의 비-hejo 모드가 다른 작업 디렉터리를 사용해 상대 시험 경로를 찾지 못해 종료 4였다(`.build/task22-focused-initial.log`). 절대 시험 경로로 바꾼 최종 명령이 위 32개 통과다. 개발 중 발견한 실패와 최종 결과를 구분하며, 이 로그들은 공개 추적 파일에 넣지 않는다.

### TASK-20·21 착수 보류 기록 — 계획 담당의 원본 독해·기능 대조표 전제

보완 16 시점 후속 상태: 아래는 `b1ae3b2` 당시의 보류 근거다. 이후 계획 담당이 `3295bfe`에서 `ddots-inventory.md`를 작성해 원본 독해·대조표 근거를 보완했다. 현재 TASK-20·21은 그 대조표 Q1~Q4에 대한 사장 답과 명세 재인계를 기다리며, 이번 보완 16 범위에는 넣지 않는다.

- **판단:** 보류(구현 규칙 2절에 따른 계획 담당 보완 요청). 최신 사용자 제약은 "ddots 이식 계획은 계획 담당이 ddots 원본을 끝까지 읽고 기능 대조표를 만든 뒤 명세화한다(줄 범위 인용만으로 명세 금지)"다. 구현 담당의 copy-review는 이 계획 단계 전제를 대신하지 못한다.
- **확인한 근거:** 현재 hejo HEAD는 `b1ae3b2354babb50b7477ed5dfefb19c8027b055`다. handoff 보완 14는 원본 줄 범위와 구현 목록을 제공하고 design '사진·구획·단체방'과 REQ-HF-23·24는 목표를 정하지만, TASK-20·21의 원본 기능별 유지·변경·제외 및 REQ/AC/AT 대응 대조표는 작업 문서에서 확인되지 않는다. 기존 copy-review의 전체 독해 기록은 구현 담당의 이전 TASK-05·06·17 범위이며, TASK-20·21 계획 담당의 전제 충족 증거로 쓰지 않았다. 문서가 없다는 이유로 계획 담당이 실제로 읽지 않았다고 단정하지 않는다.
- **이번 조사 범위:** ddots 원본 HEAD `208f6e6322f593729c9ef6ac16ac903be4c3692b`, 지정 네 파일의 작업 트리 변경 없음을 읽기 명령으로 확인했다. SlackPanel의 구획·사진 콜백 일부, SlackController의 콜백 연결 일부, SettingsSync 앞부분만 읽었다. 전체 독해·의존 검토를 마쳤다는 기록은 남기지 않았고 복사하지 않았다. hejo 제품 코드·실행 시험·설계·수락 기준 변경, 설치·릴리스·커밋·푸시 없음. 이번 변경은 이 보류 보고뿐이다.
- **계획 담당에게 요청:** 지정 원본 파일 전체와 유지 의존을 직접 읽고 원본 커밋·파일·독해 범위를 기록한다. 기능별로 원본 동작, hejo 유지/변경/제외 및 이유, 책임 칸, REQ/AC/AT를 연결한 대조표를 작성하고 기존 명세·설계와 맞춰 재인계한다. 특히 사진 대상·표시·동기화, 구획 생성/접기/삭제/이동/순서/고정, 방 관리·멘션 전달의 이식 경계를 확인한다. 필요하면 이미 기록된 독해 증거의 위치를 명시하는 것으로 누락을 해소할 수 있다. 구현 담당이 이 대조표를 대신 확정하거나 수락 기준을 바꾸지 않는 방안을 권고한다.
- **그동안 진행 가능한 부분:** TASK-22의 기존 검증·릴리스 증거는 그대로 유지한다. 사진 HTTP 계약 자체는 승인돼 있으나 앱 이식과 함께 TASK-20으로 묶인 구현은 보완 인계 뒤 시작한다. 같은 전체 검사는 반복하지 않는다. 새 제품 변경이 없으므로 새 기능 시험·앱 10회 반복·캡처·배포는 미실행이다.

### TASK-22 보완 16 — 롤백 중단과 사장 키 삭제 구분

1. **받은 설계:** handoff 보완 16, design 'hejo 홈 채널' 17판 맞춤 표·삭제 순서, AT-HF-72 ④·⑤·사장 키 삭제 사례. 검토 V-1·V-2의 설계 보완이며 기준 HEAD는 `0fa3d1b6cb7449518e867cdd0c7e56976033f0c6`다. 연합개발·고위험, 필요한 인계 증거 **수준 2**, 최종 수락 **수준 4**다.
2. **구현자 판단·변경 후 구조:** 보완 16 구현·자체 시험 완료. 설치 도우미의 기존 영수증 version 1과 동일한 홈 채널 대상에서 삭제 의도를 먼저 기록한다. `remove_home_channels`가 `removing` 저장 → 키 삭제 → `removed` 저장을 맡으므로 선택 제거·전체 제거·신규 설치 실패 되돌림·기존 설치 갱신 실패 되돌림 모두 같은 순서를 쓴다. config 쓰기 실패는 C1대로 applied로 되돌려 저장하고 종료 1로 알린다.
3. **더한 것·교체·설계 차이:** `reconcile_home_channels`가 removing+after는 applied, removing+없음은 removed, removing+다른 값은 released로 맞춘다. 제거 명령은 applied를 이어 지우며, 설치·갱신은 맞춤을 먼저 해서 removed 대상의 빠진 키를 다시 넣는다. 점검은 영수증을 쓰지 않고 같은 판단을 사용한다. released+값 없음은 `owner_removed`, 실제 사장 값은 `owner_set`으로 구분한다. 일반 대상의 파일 전체 복원도 removing 홈 채널이 남으면 쓰지 않는다. 이전 '먼저 삭제하고 저장' 경로를 같은 함수에서 교체했으며 설계 차이는 없다.
4. **덧대기·성격:** 새 파일·영수증 버전·설정 원본·공개 설치 경로 없음. 기존 복구·제거 책임에 상태 전이만 통합한 의미 변경이다. 기존 영수증과 pending/applied/released/removed, C1, A/B/C 롤백·강제 제거의 사장 값 보존 계약을 유지한다. 임시 제품 코드 없음.
5. **시험:** 기존 시험은 허가된 `test_at_hf_72_owner_change_check_and_forced_uninstall`의 기대 한 줄만 `owner_set` 2개에서 `owner_set` 1개+`owner_removed` 1개로 바꿨다. 다른 기존 시험 바이트는 변경하지 않았음을 기준 커밋과 직접 대조했다. 새 실행 사례 18개는 두 제거 명령 × 중단 ④·⑤ × 설치/선택 제거/전체 제거 복구 12개, removing 뒤 사장 변경값의 세 복구 경로 3개, 신규 설치·옛 설치 갱신 실패의 삭제 순서 2개, 사장 키 삭제의 released 유지·owner_removed·읽기 전용 점검 1개다. 제거 전 의도 선저장, 제거 뒤 사장 변경 오판 금지, config·영수증의 다른 대상과 원문 보존을 관측한다. `removing` 선저장 두 줄을 제거한 돌연변이는 14개 시험이 실패했고, 최종 전체 검사 전에 원복했다.
6. **직접 실행한 검증·증거:** 필요한 수준 **2**, 도달 수준 **2**. 임시 HERMES_HOME·가짜 기본+보조 2개 프로필에서 실제 설치 도우미를 실행했다. 다른 에이전트는 쓰지 않았다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| `python3 .build/foundation9_runner.py task22-r16-install <저장소>/tests/acceptance/test_install.py` | 종료 **0**, 집중 시험 **49 passed**(마지막 독립 owner_removed 사례 추가 직전) | `.build/task22-r16-focused.log`, `.build/foundation9-task22-r16-install.log` |
| `python3 .build/task22_r16_mutation.py` | 실행기 종료 **0**, removing 선저장 제거 시 **14 failed / 36 deselected**, pytest 종료 **1**, 소스 원복 확인 | `.build/task22-r16-mutation.log`, `.build/task22-r16-mutation.json`, `.build/foundation9-task22-r16-mutant.log` |
| `python3 .build/foundation9_runner.py hejo`(최종 제품·시험 소스) | 종료 **0**, pytest **126 passed**(설치 시험 50개 포함), AT-22 가짜 게이트웨이 정상 종료, 앱·HTTP/WebSocket 대역 통과 | `.build/task22-r16-full.log`, `.build/task22-r16-full-detail.log` |
| Hermes venv Python `scripts/scan_private.py --repo .`, `HEJO_PYTHON` 지정 `sh githooks/pre-commit`, `git diff --check` | 각각 종료 **0** | `.build/task22-r16-checks.json`, `.build/task22-r16-{scan,precommit,diff-check}.log` |
| 기존 시험 바이트 대조 | 허가된 기대 한 줄 외 기존 바이트 변경 **0** | `.build/task22-r16-test-contract.json` |

7. **범위·남은 위험·검토 요청:** 앱 소스 변경이 없어 새 캡처·10회 반복·앱 사본 교체는 해당하지 않는다. TASK-20·21은 착수하지 않았다. 운영 홈 설치·게이트웨이 재시작/reload·실제 발송·비밀 파일 열기·Hermes 본체·ddots·허브 코드 수정·push는 하지 않았다. 비설계자 검토와 TASK-23 수준 4는 여전히 필요하다. 검토자는 removing+after의 설치/제거 분기, removing+없음에서 새 대상 생성 전에 맞추는 순서, 점검의 읽기 전용·owner_removed, 쓰기 실패 C1과 기존 기대 한 줄 외 시험 불변을 확인할 것. 기존 pytest 비동기 표시·Swift Sendable 경고는 이번 변경과 무관한 부채로 유지했다. 제품 코드·시험·이 보고와 이전 보류 보고를 함께 TASK-22 보완 단독 커밋으로 넘긴다. 공용 릴리스 갱신은 커밋 직후 수행하며 결과는 `.build/task22-r16-release.log`와 최종 인계에 남긴다.

### TASK-24 착수 대조 — 보완 17의 원본 문구·이전 조건 확인 요청

- **상태:** 보류(제품 구현 전). 기준은 `705c240a26c616b307afbf947d565b43a3f35baf`이며 시작 작업 트리는 깨끗했다. 보완 17의 "명세의 문구·수치가 원본과 다르면 멈추고 보고한다"에 따라 다음 두 항목을 계획 담당에게 넘긴다. 구현 담당은 명세·수락 기준을 바꾸지 않았다.
- **D24-01 — 확인 창 문구:** spec REQ-HF-26.AC-04(218행)는 "이 Mac의 화면 배치로 다른 Mac을 맞출까요?"다. ddots 원본 `App.swift` 1687행은 "이 Mac 화면을 다른 Mac에도 맞출까요?"이며, 설명도 원본 1688행과 명세가 다르다. 원본에는 Slack 계정·섹션·채널 표현과 읽음 병합 안내가 있고, 명세에는 hejo 표현과 다른 Mac 전용 배치 삭제 안내가 있다. 서비스 용어 변경은 필요한 이식이지만, 이 차이를 허용한 변환인지 원문을 더 유지해야 하는지 보완 17의 일치 조건 아래 구현자가 임의 확정하지 않았다. 선택지: 원문 구조를 유지하며 서비스 용어만 바꾸도록 명세를 고치거나, 현재 명세 문구를 승인된 이식 차이로 명시한다. 후자를 권고한다.
- **D24-02 — 처음 옮기기 조건:** design 303행은 "회원 상태가 비었을 때 한 번"이라고 한다. spec AC-03(212~216행)은 앱 첫 실행에 기존 값을 옮겨 이미 다른 Mac이 정한 배치와 병합하도록 하며, AT-74(81행)는 허브에 이미 B 배치가 있는 경우의 A 이전을 요구한다. 원본 `SlackSettingsSync.swift` 73~84행의 `joinSettings`는 회원 저장소가 비었는지를 조건으로 쓰지 않고 이 Mac의 계정별 joined 표시로 한 번 이전한다. design의 '비었을 때'가 허브 전체가 비었다는 뜻인지, 이 Mac의 이전이 아직 끝나지 않았다는 뜻인지 명확히 해야 한다. 전자로 구현하면 AT-74 상황에서 A 읽음·옛 배치가 이전되지 않을 수 있다. 선택지: design을 '이 Mac에서 해당 회원의 이전 미완료 시 한 번, 허브 비어 있음과 무관'으로 명시하거나 AC·AT를 바꾼다. 전자를 권고한다. 로컬 readSeq를 지우는 완료 시점도 이 이전 표시·대기열 영속화와 함께 명시하면 검토 가능하다.
- **이미 명확한 이식 차이:** 처음 이전 시각은 원본 `SlackSettingsSync.swift` 78~79행의 1과 다르지만, 최신 실행 지시가 명시적으로 0을 요구하므로 0이 기준이다. 이를 별도 차단 사유로 삼지 않았다. 허브 LWW·seq·한도·30초 규칙도 승인된 hejo 계약으로 읽었으며 원본과 같다고 주장하지 않는다.
- **읽은 범위·보존:** ddots HEAD는 `208f6e6322f593729c9ef6ac16ac903be4c3692b`, 관련 SettingsSync·SlackSettingsSync·App 파일의 작업 트리 변경은 없다. SettingsSync 145행과 SlackSettingsSync 173행을 읽었고, App은 해당 확인 창·설정 페이지 부분만 읽었다. App 전체·모든 유지 의존 독해는 아직 끝나지 않았으며 복사·구현은 하지 않았다. copy-review에 미완료 독해를 완료로 기록하지 않았다. TASK-20 이후 작업도 착수하지 않았다.
- **진행 가능한 부분·다음 행동:** 원본 대조 근거는 위에 보존했다. 계획 담당이 D24-01의 허용 문구와 D24-02의 이전 조건을 명시해 재인계하면, 나머지 원본·의존 전체 독해와 copy-review 기록부터 이어서 TASK-24를 구현한다. 기존 TASK-22 검사·공용 릴리스를 반복하지 않는다. 이번 변경은 이 보고뿐이며 제품·실행 시험·설계·수락 문서·운영 환경·다른 저장소·커밋·푸시 변경은 없다.


## 구현 인계: TASK-24 회원 상태 동기화 — 보완 18 / 19판

1. **받은 설계·판단:** handoff 보완 17·18, REQ-HF-26.AC-01~05, design '전수 대조 반영', AT-HF-73·74. 고위험, 인계 필요 수준 **2** / 최종 필요 수준 **4**. 위 D24-01·02 보류 보고는 보존한다. 문구·처음 옮기기 조건은 19판으로 해소했고 구현을 재개했다. 검토 기준 계획은 `7c2969f35980832d0907d1ef96d9e7b22c02c457`; 진행 중 `a201b46`·`2bd9a74860f3018441b5a5a53868a547c8474d66`의 도구 연결 계획·서버 용어 변경이 추가됐으나 TASK-24 계약은 바뀌지 않았다. 해당 문서는 수정하지 않았다.
2. **책임·흐름:** 허브 `hub/state.py`가 회원별 잠금 안에서 읽기·항목 병합·한도 검사·0600 임시 파일 fsync·rename을 맡는다. `/v1/me/state`는 회원 출입증에서 소유 회원을 구하며, 다른 회원을 지정하는 입력은 없다. 앱 `MemberState`는 허브 자료의 복제와 로컬 대기열만 맡고 `ConversationModel`이 고정·알림 끔·숨김·읽음을 여기로 읽고 쓴다. 창 열기·활성화·30초 타이머·PATCH 응답을 연결했다.
3. **이전·제거:** 회원별 `stateJoined`가 없을 때만, 허브 내용과 무관하게 옛 회원 설정·로컬 읽음을 시각 1로 옮긴다. 앞의 고정 5개를 자리 1~5에 놓고 초과 수를 한 번 안내한다. 옮긴 값·대기열·표시·옛 `readSeq` 삭제는 `LocalStore.update`의 단일 원자적 저장이며, 저장 실패 시 메모리도 옛 값이다. 옛 고정·알림·숨김 필드는 이전 입력으로만 남기고 이전 뒤 nil로 지운다. 옛 회원 설정 쓰기와 `preferenceSettings`·`applyMemberSettings` 경로는 제거했다. 펫 이름·크기·말풍선의 기존 회원 설정은 유지한다.
4. **UI·연결:** AppKit 설정에 '연결과 동기화'와 '화면 배치 동기화…'를 추가했다. 확인 창은 19판 원문이며 미연결 안내도 그대로다. 배치 덮어쓰기는 fetch 전 이 Mac 배치를 잡고 원격에만 있는 배치 키를 null로 보낸다. 읽음 계열은 수정하지 않는다. 실패는 아일랜드 '화면 상태를 맞추지 못했어요'로 알리고 대기열을 유지한다. 모두 읽음은 스레드 위치와 방 `read:` 위치를 함께 갱신해 스레드 항목 잘라내기 뒤에도 읽음이 유지된다. 로그인 완료 알림은 새 회원 자격증명 저장·채택 뒤로 옮겨, 이전 회원 토큰으로 상태를 요청하거나 새 상태 선택을 다시 지우지 않게 했다.
5. **설계 차이·임시 경로:** 기능 계약 차이 없음. ddots의 Slack 계정·relay·UserDefaults 의존을 승인된 허브·HubClient·LocalStore로 대체했다(`copy-review.md` 파일별 전체 독해 기록). 회원 복제·대기열을 허브 주소와 회원으로 나눠 다른 계정 자료를 보내지 않는다. 옛 필드는 최초 이전을 위한 읽기 호환뿐이다. 새 기록 원본·동기화 서버·SwiftUI 화면은 없다. 화면 비교는 원본 확인 창 내용을 분리한 시험 창이며 운영 ddots 실행 증거로 쓰지 않는다.
6. **시험과 기존 시험 조정:** AT-73은 항목 LWW·같은 시각 기기 순서·읽음 역행·null·4종 잘라내기·형식/용량 거절·동시 PATCH·회원 분리·쓰기 실패 이전 바이트/0600 보존을 검사한다. AT-74는 앱 둘의 대역 허브·오프라인/재연결·전송 도중 추가 변경·최초 이전 후 즉시 종료/재실행·로컬 저장 실패·배치 덮어쓰기·실제 30초 타이머 콜백/활성화·방 읽음과 스레드 항목 잘라내기·확인 문구·HubClient GET/PATCH를 검사한다. 이전 앱 시험의 로컬 readSeq·옛 회원 설정 전송 단언은 같은 동작의 새 회원 상태 저장 단언으로 교체했고, 기존 메뉴 순서·안 읽음·숨김/복원·고정 순서 단언은 유지했다. 설정 탭 수는 새 탭을 포함해 4로 바꿨고 로그인 시험은 실제 완료 알림을 기다린 뒤 같은 기대값과 새 토큰 준비를 확인한다. 수락 문서의 기준은 바꾸지 않았다.
7. **직접 실행한 검증:** 도달 증거 **수준 2**, 자체 시험이며 다른 에이전트는 쓰지 않았다. 실행 결과는 아래 표와 로컬 로그에 둔다. 최초 앱 빌드 중 시험 보강으로 입력 변경 오류 1회, 로그인 완료 알림 순서 변경 뒤 기존 시험의 이른 관측 1회를 확인했고, 변경과 관측 순서를 고쳐 재실행했다. 자체 대조에서 방 읽음 키 갱신을 보강해, 이전 반복 실행 8회 통과 뒤 그 묶음을 중단하고 최종 코드의 전체 검사·10회 반복을 새로 시작했다. 실패를 숨기거나 기대값을 완화하지 않았다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| `python3 .build/foundation9_runner.py hejo` | **0**, Python **139 passed**, 가짜 Hermes 전달·앱/네트워크 시험 통과 | `.build/task24-foundation-final.log`, `.build/task24-full-final.log` |
| 읽음 큰 값 비교를 제거한 독립 사본 돌연변이 | pytest **1**, **1 failed / 12 passed**로 검출; 원본 파일 불변 | `.build/task24-mutation.log`, `.build/task24-mutation.json` |
| 개인값 검사(새 파일 추적 등록 뒤) | **0** | `.build/task24-private.log` |

8. **미검증·남은 것:** 실제 두 Mac 동기화·운영 회원 이전·운영 허브 재시작·실물 첫 응답은 실행하지 않았다(TASK-23, 계획 담당+사장). 인계 수준 2를 최종 수준 4로 주장하지 않는다. 공용 릴리스와 앱 사본 교체는 이 TASK의 검증 완료 뒤 별도로 기록한다. 운영 홈 설치 도우미·게이트웨이 재시작/reload·실제 외부 발송·비밀 파일 열기·Hermes 본체·ddots 수정·public 갱신·push는 하지 않는다.
9. **부채·검토 요청:** 기존 Swift 동시성 경고와 pytest 비동기 표시 경고는 범위 밖이다. 검토자는 최초 이전의 단일 저장, pending 변경을 오래된 PATCH 응답이 지우지 않는지, 회원 전환 중 응답 세대 확인, 회원별 잠금·이전 파일 보존, 배치 null과 읽음 불변을 특히 확인할 것. TASK-24 자체 판단·최종 커밋·나머지 검사와 적용 결과는 검증 종료 뒤 아래에 확정한다. 다음 순서에 TASK-31 탐침을 추가한 20판 문서도 계획 담당이 현재 인계와 대조할 필요가 있다.


### TASK-24 최종 자체 시험·적용 확정

구현자 판단은 **TASK-24 구현·자체 시험 완료, 검토 대기**다. D24-01·02의 해소와 원본 전체 독해를 반영했다. 아래는 방 읽음 보강까지 포함한 최종 코드의 결과다. 위 표의 전체 검사도 같은 최종 코드로 다시 실행했다.

| 검사·적용 | 실제 결과 | 증거 |
|---|---|---|
| 전체 검사 `python3 .build/foundation9_runner.py hejo` | **0**, **139 passed**, 가짜 Hermes·앱·실제 루프백 HTTP/WS 시험 통과 | `.build/task24-foundation-final.log`, `.build/task24-full-final.log` |
| `app/scripts/test.sh` 최종 코드 10회 연속 | **10/10 종료 0**; 매번 AT-74·네트워크 고장/복구·전송 크기·대화 통신 시험 통과 | `.build/task24-app-final-repeat-results.json`, `.build/foundation9-app-task24-final-repeat-01.log`~`10.log` |
| 개인값 검사·`githooks/pre-commit` | **각 0**; 새 제품·시험·보고·증거 파일을 추적에 넣고 실행 | `.build/task24-private.log`, `.build/task24-hook.log` |
| SwiftUI import·diff 공백 검사 | **각 0**; SwiftUI import 0건 | `.build/task24-swiftui.log`, `git diff --check` |
| ddots/hejo 같은 연결 상태 확인 창·설정·미연결 캡처 | **각 0**; 원본 NSAlert 내용을 같은 비활성 시험 창에 렌더링해 직접 비교 | [화면 비교·한계](../../../evidence/HEJO-FOUNDATION/TASK-24.md), `.build/task24-capture.log`, `.build/task24-reference-capture.log` |
| 앱 두 사본 교체 | **0**; 백업 뒤 새 실행 파일 적용, 서명 2개·실행 파일 해시 일치, 기존 번들 설정 보존 | `.build/task24-deploy.log`, `.build/task24-deploy.json`, `.build/task24-deploy-backup/` |

앱 교체에서 운영 앱을 종료·재실행하지 않았다. 설치한 새 코드를 운영 회원으로 실행해 이전하는 확인은 TASK-23에 남는다. 허브 자료·로컬 설정·금고는 적용하지 않았고, 공용 릴리스는 이 TASK 단독 커밋 직후 `install/hejo-release`로 파일만 갱신한다. 결과·이전 릴리스 사본은 `.build/task24-release.log`·`task24-release-verify.json`·`task24-release-backup/`에 남기고 최종 인계에 확인값을 보고한다. 운영 허브·게이트웨이는 재시작하지 않는다.

롤백·남은 위험: 허브 상태 파일은 이전 허브가 무시하는 새 파일이다. 앱 사본은 위 백업으로 되돌릴 수 있다. TASK-23에서 실제 Mac의 처음 옮기기를 실행하기 전에는 로컬 `hejo-local.json`도 보존할지 계획 담당이 확인해야 한다(새 앱이 옛 readSeq를 지우므로 이전 앱만 되돌리면 새 회원 상태를 읽지 못함). 이 실행에서는 운영 Mac의 이전을 하지 않았다. 고위험 최종 판정·비설계자 검토·실제 두 Mac 수준 4는 남아 있다.

검토 대상은 `main`의 **이 절·제품·시험·캡처를 함께 담은 TASK-24 단독 커밋**이며 전체 해시는 최종 역할 인계에 기록한다. 계획 담당은 tasks.md의 TASK-24 대기 표기를 이 구현 결과와 대조하고, 새 보완 19의 TASK-31 탐침을 다음 순서로 인계할지 확인할 것. TASK-20·25·26·29·30·27·21·31·32는 이번 커밋에서 착수하지 않았다.

## 구현 인계: TASK-31 도구 연결 탐침(보완 지시 19)

1. **받은 설계·기준:** handoff 보완 19, REQ-HF-32·design '직원별 도구 연결(20판)'. 기준 `39e45b55306eafa0b2c913665273d74722c77794`, 연합개발 구현·자체 시험 역할. 일반 위험, 필요한 수준 **2**, 도달 수준 **2**다. 이번 지시는 읽기 전용 탐침이며 제품 구현은 하지 않는다.
2. **구현자 판단:** **탐침·문서화 완료, 계획 담당 검토 대기.** [probe-connections.md](probe-connections.md)에 방식별 결과·실패·OAuth 제공자 표·재시작 후 결과 복구 제안·근거 파일/줄을 남겼다. (b) 루프백 백엔드가 기본 후보지만 로그 비노출·설치/수명·external 제공자·콜백 중계·영속 재시작 결과는 계획 확정 사항이다.
3. **변경·책임 배치:** 추적 변경은 탐침 보고 신설과 이 인계 절뿐이다. 공식 관리 함수/루프백 API/CLI가 각자 실제 Hermes 설정·환경값을 쓰는 것을 임시 홈에서 확인했다. team-kit이 관리하는 연결은 그 명령에서 문서와 결과를 받는다. 제품 원본·공개 규격·설정·시험·작업 판정은 변경하지 않았다. 삭제/교체한 제품 경로, 덧댄 계층, 제품 의미 변경은 없다.
4. **실행 근거:** `.build/task31/launch.py`가 Hermes venv와 가짜 기본+보조 2개 프로필을 준비한다. `probe.py`, `backend.py`, `provider_starters.py`, `cli_matrix.py`, `team.py`, `reconnect.py`를 직접 실행했다. 감사 훅·최소 환경으로 운영 비밀 읽기·임시 폴더 밖 쓰기·비루프백 접속·실제 서비스 신호를 제한했다. 필요한 web 의존성은 탐침 폴더에만 설치했으며 원래 venv는 바꾸지 않았다. 하위 에이전트는 쓰지 않았다.
5. **관측한 제약:** MCP 시험과 OAuth 시작에 주입한 가짜 비밀 문자열이 원시 오류에 남는다. 대시보드 자체 오류 로그의 비노출도 미해결이다. web `configured`는 필요한 특정 키가 없는 프로필에서도 true일 수 있다. CLI MCP 추가·시험은 대화형/대기 경로가 있어 제한시간을 넘겼다. 일부 제공자 의존성 미설치도 기록했다. 이 결과를 성공한 실제 연결로 세지 않았다.
6. **검증:** 아래 명령의 실행 결과와 개별 실패/대역 범위는 탐침 보고의 표·로그에 있다. 기능/제품 시험을 추가하거나 기존 수락 시험을 바꾸지 않았다. 제품 변경이 없어 전체 제품 시험·앱 10회·캡처·배포·공용 릴리스·돌연변이는 반복하지 않는다. 이번 목적은 채택 가능성과 한계를 관측하는 것이며 외부 경계 고장 주입을 사용했다.

| 명령 | 실제 결과 | 로컬 증거 |
|---|---|---|
| `python3 .build/task31/launch.py probe` | 0, 함수 경로·세 프로필·60개 병행 비밀 범위 읽기·오류 노출·드레인 표식 | `.build/task31/probe.log`, `probe-results.json` |
| `python3 .build/task31/launch.py backend` | 0, 실제 루프백 백엔드·토큰/Host·HTTP 쓰기. 외부 인증/전송·서비스 실행만 대역 | `.build/task31/backend.log`, `backend-server.log`, `backend-results.json` |
| `python3 .build/task31/launch.py provider_starters` | 0, 실제 공급자 4개 시작 함수+가짜 HTTP; 토큰 교환 미실행 | `.build/task31/provider_starters.log`, `provider-starters-results.json` |
| `python3 .build/task31/launch.py cli_matrix` | 0, 개별 명령의 1/시간 만료는 예상 관측으로 구분 | `.build/task31/cli_matrix.log`, `cli-results.json` |
| `python3 .build/task31/launch.py team` | 0, 문서·stdin·0600 저장/되돌림·큰 입력 거절·고정 오류·시간 제한 | `.build/task31/team.log`, `team-results.json` |
| `python3 .build/task31/launch.py reconnect` | 0, 가짜 서비스 runner에서 3채널/처리 중 거절/새 연결 없음 판정 | `.build/task31/reconnect.log`, `reconnect-results.json` |
| Hermes venv `scripts/scan_private.py --repo .`·`HEJO_PYTHON` 지정 `githooks/pre-commit` | 각각 0, 새 보고서를 추적에 넣고 실행 | `.build/task31/private.log`, `hook.log`, `private-results.json` |

7. **미검증·남은 위험:** 실제 게이트웨이에서 실행되는 문과 Hermes 대화의 동시 관리, 실제 제공자 인증/토큰 교환, 실제 MCP 전송, 운영 재시작·앱 재연결·두 Mac 실물은 미실행이다. 재시작 후 결과 복구는 제안이며 구현하지 않았다. 운영 홈 설치·재시작/reload·비밀 파일 열기·본체/ddots/운영 저장소 수정·외부 메시지·public 갱신·push는 하지 않았다.
8. **검토 요청·다음 순서:** 계획 담당이 탐침의 대역 범위와 원시 오류/로그 노출, `configured` 의미, OAuth external 4종·MCP 콜백, 영속 작업 결과의 칸을 검토하고 TASK-32 계획을 확정해야 한다. TASK-20부터의 실행은 이 탐침 검토 뒤에 보완 17·18대로 이어간다. 이번에는 후속 TASK를 착수하지 않았다. TASK-24 및 앞선 보류/해소 보고는 그대로 보존했다. 검토 대상은 두 문서를 담은 별도 `git commit --only` 커밋이며 전체 해시는 최종 역할 인계에 기록한다.

## TASK-20 착수 전 보류: D20-01 구획 삭제 문구(2026-11-16)

- **받은 지시·현재 상태:** 기준 `40c137f4b3c67384972bda64829eec950f28d10b`, handoff 보완 20에 따라 TASK-20의 원본 대조를 시작했다. TASK-31 검토 완료는 verdict/tasks와 대조했다. TASK-20은 고위험, 인계 필요 수준 2 / 최종 수준 4다. **원본 대조 중 보류이며 제품 구현·자체 시험 완료가 아니다.**
- **D20-01 근거:** spec REQ-HF-23.AC-02(181행)의 삭제 본문은 “섹션만 없어지고 방과 글은 그대로예요.”, 이동 안내는 “ 안에 있는 방 N개는 ‘<첫 구획 이름>’로 옮겨져요.”다. ddots 원본 `SlackController.swift:328~329`는 각각 “섹션만 없어지고 슬랙 채널은 그대로예요.”와 “ 안에 있는 채널 N개는 ‘<첫 구획 이름>’로 옮겨져요.”다. 제목·버튼은 같다. AT-HF-69는 삭제 확인 문구의 **원문 일치**를 요구하고 handoff 보완 17(799행)은 **명세 문구·수치가 원본과 다르면 멈추고 보고**하도록 한다.
- **확인이 필요한 결정:** hejo 서비스 용어로 바꾼 명세 문구를 승인된 이식 차이로 쓸지, ddots 원문 구조를 더 유지해 문구를 고칠지 계획 담당이 확정해야 한다. **권고:** 현재 hejo 문구를 승인된 변환으로 명시하고 AT-69의 일치 대상을 그 문구로 확정한다. 구현자는 spec·AT를 바꾸거나 원문 일치 조건을 완화하지 않았다. 앞선 D24-01의 문구 변환 허가는 회원 상태 확인 창에 대한 것이므로 이 삭제 창 전체에도 자동 적용하지 않았다.
- **별도 승인된 차이:** ProfileAvatar.swift:49의 사진 우선순위는 slack-avatar.png → avatar.png이나, 이번 지시·사장 선택 Q1은 avatar.png 우선을 명시한다. 따라서 이 차이는 보류 원인이 아니며 승인된 hejo 규칙을 적용할 수 있다.
- **실제 변경·증거:** copy-review.md에 ProfileAvatar 115줄 전체 확인과 나머지 전체 독해 미완료를 구분해 기록했다. 이번 변경은 copy-review와 이 보류 절뿐이다. 제품 코드·실행 시험·설계·수락 문서·앱 사본·공용 릴리스는 바꾸지 않았다. 현재 증거는 소스 대조 **수준 1**이며 요구한 수준 2의 통합 시험·AT-68/69·전체 검사·앱 10회·돌연변이·캡처는 미실행이다.
- **재개 조건·다음 행동:** 계획 담당이 D20-01의 허용 문구와 원문 일치 기준을 확정해 재인계하면 나머지 지정 ddots 파일 전체·유지 의존 독해와 copy-review 기록을 마친 뒤 사진·색·SidebarLayout 구현으로 이어간다. 후속 TASK-25 이후는 아직 시작하지 않는다. 운영 홈 실행·재시작/reload·비밀 파일 열기·ddots/본체/운영 저장소 수정·외부 발송·커밋·push는 하지 않았다. 두 보고 파일의 미커밋 변경은 실행 담당 소유이며 다음 구현 커밋에서 보존·정리한다.

### TASK-20 보완 21 재개 — D20-01 해소·전체 독해 완료·D20-02 보류

- **기준·완료 조건:** 계획 `817a8e743ccd08f91558f667c22ac7b5f59a3e2a`의 REQ-HF-23(22판)·AT-68/69. 고위험, 필요 증거 수준 2. 사진·색·SidebarLayout·앱 적용·공용 릴리스·별도 커밋까지가 배정 범위이며 이번에는 미완료다.
- **D20-01 해소:** 22판 삭제 본문과 변환 규칙을 적용한다. 기존 보류 보고는 보존했다. copy-review의 새 표에 지정 원본 8개 파일의 전체 독해와 유지 의존·대체·제외 경계를 기록했다. ddots 원본 HEAD 대비 변경 없음도 확인했다.
- **D20-02 확인:** spec REQ-HF-23.AC-01은 명부에 `avatar`(선택된 사진의 주소와 수정 시각)·`color`를 보내되, “사진 지우기”는 `assets/avatar.png`가 있을 때만 보이도록 요구한다. design의 전수 대조 반영 절도 명부 추가 필드를 `avatar`·`color`로 정한다. 두 필드에는 현재 선택된 파일이 avatar.png인지 slack-avatar.png인지 구분하는 정보가 없다. 신규 연결한 다른 Mac은 로컬 PUT 이력도 없다.
- **재현:** 임시 디렉터리의 가짜 프로필 자료로 avatar.png만 / slack-avatar.png만 / 둘 다 / 없음 4가지를 만들었다. 파일 바이트·수정 시각을 같게 놓으면 앞의 세 경우는 명세의 명부 JSON과 GET 대상 주소가 같지만, 요구한 메뉴 표시는 각각 보임 / 숨김 / 보임으로 다르다. 주소나 이미지 바이트에서 원본 파일 종류를 추측하면 이 경우를 구별할 수 없다. `.build/task20/probe_avatar_visibility.py`와 `avatar-visibility.json`에 입력·결과가 있다. **이는 명세 직렬화 모형의 관측 가능성 재현이며 제품 API 실행 시험이 아니다.**
- **계획 담당에게 필요한 결정(제안):** 직원 명부에 선택적 `avatar_custom: boolean`을 명시해 avatar.png 존재 여부를 전달하고, 앱은 true일 때만 삭제 메뉴를 보이게 한다. 기존 필드·사진 주소·사진 원본은 유지하며 새 저장소는 필요 없다. 이 정보가 없는 옛 문과 연결한 앱의 기본값/메뉴 정책도 정해야 한다. 같은 사실을 전달하는 다른 공식 계약도 가능하다. 구현 역할의 공개 인터페이스 변경 금지(20-implementation 1·2절)에 따라 임의로 채택하지 않았다. 수락 문서는 수정하지 않았다.
- **실제 변경본:** 현재 추적 변경은 copy-review와 impl-report뿐이다. 사진 API·규격·시험 초안은 `.build/task20/draft/`에 격리했다. 원래 제품 파일은 이번 시작 HEAD로 복구했고 신규 제품 파일도 작업 트리에서 제거했다. 앱·앱 사본·공용 릴리스는 변경하지 않았다. 초안은 설계 준수·실행 통과를 주장하는 구현물이 아니며 재개 시 다시 검토해야 한다.
- **검증과 한계:** 관측 가능성 재현 종료 0. 초안의 사진 시험을 foundation runner로 시도했으나 수집 중 상대 import 오류로 종료 2(시험 본문 미실행, `.build/foundation9-task20.log`·`.json`); 이 초안은 위와 같이 제품에서 제거했다. AT-68/69 통합·foundation hejo 전체·앱 10회·돌연변이·캡처·사본 교체·릴리스 갱신은 미실행이다. 도달 증거 수준은 소스/명세 대조 수준 1이다. 제품 구현 커밋은 없다.
- **보고 파일 검사:** Hermes venv의 `scripts/scan_private.py --repo .`와 HEJO_PYTHON 지정 `githooks/pre-commit`은 각각 종료 0, `git diff --check` 종료 0. 로그는 `.build/task20/private.log`·`hook.log`·`diff.log`, 실행 요약은 `report-checks.json`이다. 검사 대상은 위 기준 HEAD 위의 보고 파일 변경본이며, TASK-20 제품 검증 통과를 뜻하지 않는다.
- **재개 조건:** 계획 담당이 D20-02의 명부/API 전달 방법·옛 문 호환 정책·해당 AT 입력을 확정하면 완료한 전체 독해 기록을 재사용해 TASK-20을 구현한다. TASK-25 이후는 미착수다. 운영 홈 실행·비밀 파일 열기·재시작/reload·ddots/본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다.

### TASK-20 보완 22 — 직원 사진·색·사이드바 배치 구현

**기준과 보류 해소.** 기준 계획은 `8703b8806b2bb9e8833a5d34d7ad789de79db581`(23판)이다. D20-01·02의 이전 보고를 보존하고, 승인된 문구 변환과 avatar_custom 계약으로 해소했다. 원본 8개 전체 독해 기록을 재사용했다. 필요 증거 수준은 고위험 인계 **2**, 최종은 비설계자 검토·TASK-23 실물 **4**다. 아래 자동 시험·가짜 자료 화면은 수준 2 근거이며 운영 적용·두 Mac 확인을 대신하지 않는다.

**칸과 구현.**

- `gate/pictures.py`가 프로필 사진 선택·중첩 색 읽기(ruamel)·원자적 쓰기·삭제를 맡는다. 사진 순서는 avatar.png → slack-avatar.png이며 색이 없거나 다른 키뿐이면 null이다. 직원 사진은 프로필 assets에만 쓰고, 공용 사진은 shared/hejo/pictures에 쓴다. 임시 파일 fsync → rename, 직원 0644/새 assets 0755, 공용 0600/폴더 0700이다. 쓰기 실패 때 기존 파일을 남기고 임시 파일을 치운다.
- `GateServer`는 기존 출입증 인증 뒤 GET·PUT·DELETE를 처리한다. 512 KiB 초과 413, PNG 서명·청크 CRC·압축 스트림이 틀리면 415다. PNG 검사는 출력을 작은 덩어리로 읽어 메모리를 제한하며 압축 스트림 끝까지 확인한다. 옛 avatars 라우트는 제거했다. 직원 변경 뒤 모든 연결에 새 roster를 보낸다. 응답의 공용 사진 주소는 서버 파일 수정 시각을 사용한다.
- 규격의 직원 color·avatar_custom은 선택 필드다. 앱은 필드 없는 옛 문에서 직원 사진 쓰기 메뉴를 숨긴다. 새 문에서는 false이면 바꾸기만, true이면 지우기도 보인다. 지우기는 avatar.png만 지우므로 대체 사진으로 돌아간다.
- 앱의 PictureCodec은 png·jpg·heic를 중앙 정사각형의 256px PNG로 바꾼다. 인증 주소별 메모리 캐시는 명부·접속·회원 전환 때 분리하며 리디렉션·외부 주소는 거절한다. 파일 선택·변환 중 연결이 바뀌면 다른 연결에 이어서 쓰지 않는다. 기존 직사각형 사진 표시도 원본처럼 비율을 유지해 채운다.
- ProfileAvatar를 사이드바·카드·접힌 답 더미(중복 제외 최대 3)·아일랜드·접힌 펫 말풍선·작성기 얼굴 줄에 전달했다. 직원 색은 명부 값, 없으면 이름 UTF-8 기반 고정 해시 색이다. 카드·직원 행·펫의 이름도 그 색을 쓴다. 파란색 고정 얼굴을 제거했다.
- SidebarLayout은 홈 자리 → 구획 → 1:1 묶음을 계산한다. 실제 홈 대화 조립은 TASK-27, 단체방은 TASK-21이다. 기본 세 구획·기본 이름·다섯 고정 자리·빈 자리 메움·최신 순·명부 순서를 순수 모델로 옮겼다. 구획 목록·이름·접힘·사진 주소와 1:1 묶음 이름·접힘, 방 소속·고정은 MemberState에만 쓴다. 앱에 두 번째 설정 원본을 만들지 않았다.
- AppKit 머리 메뉴·사진·삭제 확인·＋ 메뉴와 구획 간 끌기를 연결했다. 1:1 묶음에서 끌기는 거절하고 놓일 구획에 2pt 선을 보인다. 마지막 구획 삭제는 흐리며 지울 구획의 사진을 인증 경로로 지운 뒤 첫 남은 구획으로 방을 옮긴다. 실패하면 삭제하지 않고 안내한다. 신호 점은 안 읽음·질문·알림 순서, 합에서 알림 끈 방을 제외한다. 후속 알림 메타(TASK-26)의 자리는 준비하되 새 휴리스틱 판정은 만들지 않았다.

**기존 시험 변경 근거.** 수락 기준 문서·계획 문서는 바꾸지 않았다. 기존 앱 시험의 직원 행 개수·고정 삽입 순서·빈 곳 메뉴·행 번호 가정은 REQ-HF-23.AC-02가 대체하므로 구획/1:1 묶음과 1~5 자리 메뉴로 바꿨다. 기존 모두 읽음·알림·숨김·재실행·원문/첨부 보존 검사는 유지했다. 추가 AT-68/69 시험은 실제 루프백 HTTP/WS·가짜 프로필·허브·AppKit·ImageIO를 사용하며 외부 서비스는 쓰지 않는다.

**검증 진행 기록.** 최종 코드의 `python3 .build/foundation9_runner.py hejo`는 종료 0, **148 passed**, 가짜 Hermes·앱 통신 시험 통과(`.build/task20/verified-foundation.log`). 사진 인증 제거 돌연변이는 **1 failed / 7 passed**, pytest 종료 1로 검출했고 원본은 불변이다(`.build/task20/mutation-release.json`·`.log`). 초안의 상대 import 수집 오류는 수정했으며 앞선 실패 기록은 이력으로 남긴다. 앱 최종 10회·캡처·적용·보고 파일 검사는 아래 최종 확인 결과에 이어 기록한다.

**최종 자체 시험 결과.**

| 검사·적용 | 실제 결과 | 근거 |
|---|---|---|
| 전체 검사(최종 반복 뒤 같은 코드 재확인) | 종료 **0**, **148 passed**, 가짜 Hermes·실제 루프백 앱 통신 통과 | `.build/task20/release-foundation.log`·`release-foundation-run.log` |
| `app/scripts/test.sh` 최종 변경본 10회 연속 | **10/10 종료 0**, 모든 실행에서 앱·HTTP·WS·사진·구획 시험 통과 | `.build/task20/verified-app-results.json`, `.build/foundation9-app-task20-release-01.log`~`10.log` |
| 사진 인증 제거 돌연변이 | pytest **1**, **1 failed / 7 passed**, 원본 불변 | `.build/task20/mutation-release.log`·`.json` |
| SwiftUI import·고정 파란 얼굴 검사 | 각각 **0건**, 최종 앱 소스 해시 불변 | `.build/task20/static.json`·`verified-app-code-hashes.json` |
| 가짜 자료 캡처 | 종료 **0**, 사진 여섯 자리·탭/목록·접힌 말풍선 확인 | `.build/task20/capture-final.log`·`capture-execution.log`, `evidence/HEJO-FOUNDATION/TASK-20.md` |
| 앱 두 사본 교체 | 종료 **0**, 서명 두 개·실행 파일 해시 일치·기존 번들 설정 보존 | `.build/task20/deploy.json`·`deploy-execution.log`, `deploy-backup/` |

검사 과정에서 방 행의 질문·알림 숫자 표시를 보강하고 AppKit 픽셀 검사로 확인했다. 기존 직사각형 사진의 비율 유지, 소수 초 시각 정렬, 업로드 제한과 별개인 큰 기존 사진 GET, 64px 메모리 썸네일도 확인했다. 앞선 변경본의 반복 시험은 최종 열 번에 포함하지 않았다.

**인계·적용 경계.** 구현·자체 시험의 도달 수준은 **2**다. 고위험 최종 완료 판정은 하지 않는다. 비설계자 검토·실제 두 Mac·운영 문에 연결한 확인은 TASK-23에 남는다. 홈 대화·단체방·후속 알림 원본은 각 TASK 범위대로 남겨 두었다. 허브 서버 코드·운영 홈·설정·플러그인 연결·게이트웨이 재시작/reload·비밀 파일·ddots/본체/운영 저장소·외부 발송·public 브랜치·push는 건드리지 않았다. 앱 교체에서 운영 앱을 종료하거나 재실행하지 않았다.

공용 릴리스는 이 TASK 단독 커밋 직후 `install/hejo-release`로 갱신한다. 기존 사본·실행 결과·커밋 표식과 파일 해시 대조는 `.build/task20/release-backup/`·`release.log`·`release.json`·`release-verify.json`에 남기고 최종 인계에서 실제 값을 확인한다. TASK-25 이후는 아직 착수하지 않았다.

최종 사진·코드·시험·보고 파일을 Git 검사 대상에 넣은 뒤 Hermes venv `scripts/scan_private.py --repo .`, HEJO_PYTHON 지정 `githooks/pre-commit`, `git diff HEAD --check`는 각각 종료 **0**이었다(`.build/task20/private-final.log`·`hook-final.log`·`diff-final.log`·`final-checks.json`). 바이너리는 검사기가 생략하므로 가짜 자료 캡처를 직접 확인했다. 지정 원본 8개는 승인된 ddots 기준 커밋과 파일 diff가 없음을 다시 확인했다.

## TASK-25 착수 — D25-01 문구 계약 대조 보류

- **받은 설계·판단:** 보완 23, 기준 `4c875301429dfdbe7d519de57c2eb4f074b19316`, REQ-HF-27·AT-75/76. 고위험·필요 인계 증거 수준 2. 현재 판단은 **보류(계획 담당 결정 대기)**, 도달 수준은 원본 대조·분리 실행의 **1**이다. TASK-20은 검토 통과 상태를 보존하고 재구현·재시험하지 않았다. 푸시 승인을 진행 조건으로 삼지 않는다.
- **확인한 사실:** 원본 전체 독해 재사용 가능 여부와 새 의존 독해를 copy-review에 파일별로 기록했다. 원본 작업 트리의 해당 다섯 파일은 기존 기준과 diff가 없다. 제품의 기록장·어댑터도 읽었으며 `thread_delete`는 아직 구현하지 않았다.

| 지점 | 원본 근거 | 명세 근거 | 규칙 밖 차이 |
|---|---|---|---|
| 첨부 복사 줄 | `<운영 저장소>/ddots/Sources/SlackThreads.swift:974`, SlackCopy.text가 `"📎 " + 파일 이름` 생성 | spec.md:235는 `"📎<파일 이름>"`, AT-75는 복사 형식 원문 일치 | 이모지 뒤 U+0020 공백 유무. 용어 치환·Slack 전용 사실 제거가 아님. |
| 중지 되돌리기 글 | `<운영 저장소>/ddots/Sources/AgentStop.swift:9`, 괄호 안 `메모·파일·Notion·NAS·보낸 메시지 등` | spec.md:254는 `메모·파일·보낸 메시지 등`, AT-76은 되돌림 글 원문 | `Notion·NAS·` 삭제. 두 항목은 Slack 전용 사실이 아니며 현재 변환 규칙에 삭제 예외가 없음. |

- **재현·검사 범위:** `.build/task25/probe_text.py`가 원본 SlackCopy enum을 그대로 추출해 Foundation만 쓰는 가짜 글 한 개·첨부 sample.txt의 Swift 실행 파일을 만들었다. 컴파일·실행은 각각 종료 0이고, 실제 출력 `📎 sample.txt`와 명세 입력 `📎sample.txt`가 다름을 확인했다. 상태·생각 중 줄은 이 입력에 없고 해당 외부 의존은 대역이다. AgentStop.undoRequest는 원문 문자열을 추출해 명세와 비교했고 `Notion·NAS·`만 제거하면 일치했다. 결과는 `.build/task25/text-comparison.json`, 전체 로그는 `text-probe.log`·`text-compile.log`, 실제 복사 출력은 `copy-output.txt`다. **제품/API/앱 수락 시험으로 주장하지 않는다.**
- **결정 요청·권고:** (1) 첨부는 원본처럼 `📎 <파일 이름>`으로 명세를 고친다. (2) 되돌리기 글은 원본 전체를 유지하거나, 현재 hejo 문구를 의도한 차이로 명시 승인한다. 구현자는 (1)의 원문 공백 복구와 (2)의 의도적 서비스 예시 간소화 승인 여부를 계획 담당이 함께 확정하기를 권고한다. 원문을 고치거나 수락 기대값을 임의로 선택하지 않았다.
- **멈춤 근거·재개:** spec.md:167~172의 22판 규칙은 위 세 변환으로 설명되지 않는 문구 차이를 보고하도록 정한다. 공통 규칙과 구현 역할 2절도 충돌하는 수락 기준을 임의 수정하지 않도록 한다. 결정 뒤 기존 독해 기록을 보존하고 종·날짜·표 등 남은 의존 대조부터 이어 TASK-25 전체 구현·시험을 수행한다. 분리 가능한 상세 조사 외 제품 구현은 보류했다.
- **이번 변경·미실행:** 추적 변경은 copy-review·impl-report 두 보고 파일뿐이다. AT-75/76 통합, 전체 foundation 검사, 앱 시험 10회, 돌연변이, 화면 캡처, 앱 두 사본 교체, 공용 릴리스 갱신·커밋은 미실행이다. 후속 TASK도 미착수다. 운영 홈 실행·재시작/reload·비밀 파일 열기·ddots/본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. 두 보고 파일은 실행 담당 소유이며 재개 후 TASK-25 커밋에 보존한다.
- **보고 파일 검사:** Hermes venv `scripts/scan_private.py --repo .`、HEJO_PYTHON 지정 `sh githooks/pre-commit`、`git diff --check`는 각각 종료 0이다. 로그는 `.build/task25/private.log`·`hook.log`·`diff-check.log`에 있다. 검사 대상은 위 기준 커밋 위 보고 파일 두 개이며 제품 동작 검증을 대신하지 않는다.

## TASK-25 보완 24 재개 — D25-01 해소·의미 계약 보고

**기준·판단.** `cf0a23cd0778a57b5cc69b3933e5380099b2075d`, REQ-HF-27(24판)·AT-75/76, 고위험·필요 수준 2. D25-01은 해소됐고 기존 기록을 보존했다. 남은 원본·유지 의존을 copy-review에 추가 대조했다. 다음 쟁점은 공백·부호·문구 누락이 아니라 공개 통신·회원 상태 의미·공식 확장점의 충돌이다. 구현 역할 2절에 따라 해당 계약 구현을 보류하며, 승인 없이 수락 기준·허브 병합·Hermes 본체를 바꾸지 않았다.

| 번호 | 확인된 충돌과 근거 | 결정 선택지·구현자 권고 |
|---|---|---|
| D25-02 삭제 뒤 sync의 seq | REQ-HF-27.AC-02는 지운 스레드 기록을 재현·동기화·페이지에서 제외한다. 반면 REQ-HF-06.AC-04와 schemas/hejo-wire-v1.json의 x-sync는 빈칸 없는 연속 seq다. GateClient.swift:166~174은 빈칸이면 sync 재요청, LocalStore.swift:63/83와 ConversationModel.swift:210은 연속만 허용한다. seq 1을 삭제 대상으로 빼고 남은 seq 2부터 보내면 적용할 수 없고, head_seq/through만으로 삭제된 빈칸임을 구별할 수도 없다. | 삭제로 건너뛴 범위를 인증된 문이 명시하는 통신 계약과 캐시 복구 규칙을 설계하거나, 재현 제외 요구를 바꿔야 한다. 권고는 원문 제외를 지키되 명시적 생략 범위를 규격에 추가하고 설명되지 않는 빈칸의 기존 재동기화는 유지하는 쪽이다. 정확한 프레임·영속 복구·옛 앱 호환 판정은 계획 담당 결정이 필요하다. |
| D25-03 종 읽음 되돌리기 | REQ-HF-26.AC-01은 bell:도 큰 seq 우선이다. hub/state.py:15/48~53, MemberState.swift:38~43이 이를 구현한다. REQ-HF-27.AC-03은 종을 다시 누르면 읽지 않음으로 되돌리도록 한다. 이미 100을 저장한 뒤 더 늦은 null·0·같은 100을 보내도 기존 100이 이겨 해제되지 않는다. ddots는 SlackController.swift:361~367·SlackSettingsSync.swift:107~109에서 dismissed:를 null로 만들고 SettingsSync의 LWW로 동기화한다. | 권고는 read:/thread:의 큰 seq 우선은 유지하고 bell:만 원본처럼 LWW로 분리하는 것이다. REQ-HF-26·한도 정리 기준·hub/state.py·앱 MemberState·시험 변경 범위의 명시 승인이 필요하다. 새 숨은 키나 Mac별 두 번째 원본으로 우회하지 않는다. |
| D25-04 실제 /branch의 확장점 미호출 | Hermes 기준 `ebb026eef8e800e1b7471ed147b7287e878f8aa4`. gateway/slash_commands_branch_thread.py:18/38~39의 집합은 Discord/Telegram/Slack/Matrix뿐이고 hejo면 parent=None이다. slash_commands_session.py:1148~1151은 adapter를 찾기 전에 반환하므로 create_handoff_thread를 구현해도 호출되지 않는다. 같은 파일:1083~1087은 None이면 제자리 분기다. 공개 PluginContext.register_command도 plugins.py:688~693에서 기본 /branch 이름 충돌을 거절한다. | 현재 Hermes에서 신규 스레드 분기를 보장할 공식 경로를 계획 담당이 확정해야 한다. 권고는 실제 지원 버전/공식 확장점 탐침을 선행 조건으로 두고, 확보 전에는 제자리 분기를 새 스레드 성공으로 표시하지 않는 것이다. 내부 집합 monkey patch·플랫폼 위장·Hermes 세션 DB 복제는 승인 범위 밖이며 사용하지 않는다. 가짜 Hermes가 임의로 hook을 호출하게 해 실물 지원을 주장하지 않는다. |
| D25-05 질문 대기 rail 색 | spec REQ-HF-27.AC-03은 질문 대기 노랑이다. ddots SlackThreads.swift:633~636은 pending이 있으면 askingColor를 쓰고 DdotsConfig.swift:122은 #E01E5A(빨강)다. NativeThreadContent.swift:30~33도 이 경로를 쓴다. 네 보고서 이모지 색 hex 자체는 명세와 일치한다. | 질문 대기 노랑을 hejo의 의도적 상태 매핑 차이로 승인할지, 원본 빨강으로 명세를 맞출지 확정 요청한다. 이는 문자열 옮김 누락이 아니라 색의 상태 의미 변경이다. |

**분리 재현(제품 수락 시험과 구별).** `.build/task25/test_contracts.py`를 Hermes venv·임시 HERMES_HOME/HERMES_ROOT에서 실행했다. 최종 **종료 0, 3 passed**다. (1) 실제 LocalStore.swift를 가짜 의존·임시 캐시와 컴파일해 seq 2 단독 append 거절과 seq 2부터 시작한 캐시 재열기 시 잘라내기를 확인했다. seq 1→2는 성공하는 대조군이다. 서버 삭제는 아직 없으므로 필터된 입력만 모형화했다. (2) 실제 MemberStateStore.patch/get에서 bell=100 뒤 더 늦은 null·0·100이 모두 무시됨을 관측했다. 일반 LWW 키의 null은 반영되는 대조군이다. (3) 실제 Hermes GatewaySessionCommandsMixin._branch_open_thread를 호출해 hejo의 어댑터 호출 0회·결과 None, Slack 대조군 호출 1회·새 id를 관측했다. 전송 어댑터만 대역이며 전체 /branch 세션 복제나 운영 게이트웨이 실행 시험은 아니다. D25-05는 소스 대조만 했고 화면 재현은 미실행이다.

최초 탐침은 공식 hejo 플랫폼 등록 누락으로 **1 failed / 2 passed**였으며 제품 결함으로 세지 않는다. 기존 시험과 같은 PluginContext 등록 후 다시 실행했다. 최초 로그는 `.build/task25/contracts-first-failure.log`, 최종은 `.build/foundation9-task25-contracts.log`·`.build/task25/contracts-run.log`, 결과는 `.build/task25/replay-contract.json`·`bell-contract.json`·`branch-contract.json`, Swift 컴파일/실행 로그는 `contracts-swift-compile.log`·`contracts-swift.log`다.

**변경·재개 경계.** 추적 변경은 기존 보류 기록을 보존한 copy-review.md·impl-report.md뿐이며 제품·수락 기준·기존 시험·커밋은 바꾸지 않았다. 필요 수준 2, 도달 수준은 제한된 계약 재현의 1이다. 계획 담당이 D25-02~05의 계약과 허용 파일을 정하면 그 기준으로 TASK-25 전체 구현·AT-75/76·전체 검사·앱 반복·돌연변이·같은 상태 캡처·앱 두 사본 교체·공용 릴리스·단독 커밋까지 이어간다. 후속 TASK는 미착수다. 현재는 전체 검사·앱 반복·돌연변이·캡처·적용·릴리스 갱신을 하지 않았다. 운영 홈 실행·재시작/reload·비밀 파일 열기·ddots/본체/운영 저장소 수정·외부 발송·public 갱신·push도 하지 않았다. result로 계획 담당에게 넘기며 푸시 승인 대기로 멈추지 않는다.

**보고 변경본 검사.** 위 기준 커밋 위 두 보고 파일의 Hermes venv 개인값 검사·HEJO_PYTHON 지정 pre-commit·diff 공백 검사는 각각 종료 0이다. 근거는 `.build/task25/private-v24.log`·`hook-v24.log`·`diff-v24.log`와 `report-checks-v24.json`이다. D25-01 해소 문자열 확인은 `.build/task25/text-v24.json`에 있다. 상태 파일은 읽기만 했고 tasks의 보완 24 진행 상태와 현재 HEAD를 대조했다.


## TASK-25 보완 25 — 스레드 카드·작업 제어 구현 인계

**받은 설계·판단.** 기준 `eac02ca5b6a0eee05af3e02971ab394959a7b717`, handoff 보완 25·24·23과 REQ-HF-27·AT-73/75/76. 고위험, 필요 인계 수준 **2**. D25-01~05의 기존 보고는 당시 상태로 보존했고 24·25판의 해소 계약을 적용했다. 구현자 판단은 **구현·자체 시험 완료**, 실제 도달 수준 **2**다. 비설계자 검토·TASK-23 실물 수준 4·최종 판정은 남는다. 푸시를 진행 조건으로 삼지 않는다.

**구조와 자료 흐름.** 기록 원본은 Journal 하나다. message 위치·삭제된 스레드 표는 기록장에서 복구하는 파생 인덱스이며 별도 영구 원본이 없다. 문맥 묶음은 gate/context.py 한 곳에 두고 TASK-21이 재사용하도록 했다. 앱은 기존 LocalStore 복제와 MemberState를 사용한다. 새 저장소·Hermes 본체 수정·플랫폼 위장·세션 DB 복제·create_handoff_thread 구현은 없다.

- 삭제: 기존 delete의 scope 한 줄을 fsync한 뒤 방송한다. 그 전 실패는 journal_write_failed이며 삭제·첨부 정리를 하지 않는다. 확정 뒤 남은 글 delete를 보충하고, 중간 실패는 재시작 때 빠진 것만 처리한다. replay/page는 원문·수정·상태를 같은 seq의 delete로 치환하며 message()는 돌려주지 않는다. 공개 순번의 빈칸은 만들지 않는다. 늦은 답·수정·상태·작성 중·첨부는 thread_deleted_drop으로 버리고 지운 스레드 입력은 thread_deleted로 거절한다. 공유 첨부의 다른 살아 있는 등록은 유지한다.
- 앱 삭제: scope 수신 때 스레드 투영·초안·대기 전송·미전송 체크리스트 선택을 지운다. 캐시는 같은 seq delete로 0600 임시 파일→fsync→rename 재작성한다. 전용 다운로드 캐시는 지우며 공유 캐시는 남긴다. 다운로드가 진행 중이면 등록이 지워졌는지 다시 확인하고 캐시 게시를 같은 main actor에서 직렬화한다. 알 수 없는 durable 종류도 순번을 저장·적용하고 화면에서는 건너뛴다.
- 종: bell:은 hub/state.py·MemberState 모두 (at,dev) LWW·null 삭제다. read:/thread:의 큰 seq 우선과 기존 값의 숫자 형식 검사는 유지한다. 종을 읽음으로 하면 스레드 읽음 위치도 전진하고, 다시 누르면 종만 되돌린다.
- 분기: thread_branch의 client_msg_id로 중복 확정을 막고 새 UUID·이어짐 직원 글·branch_from을 기록한다. 분기 순간의 살아 있는 대화에서 생각 중·지운 글을 빼 최신 50줄·16,000자·본문 줄 2,000자로 묶는다. 새 스레드 첫 사장 글의 Hermes 이벤트에만 문맥을 붙이고 기록장·앱에는 원문을 남긴다. **도구 호출 기록·Hermes 세션·/resume 계보를 복제하지 않는다.**
- UI: hejo 주소 선언·파싱·기존/없는 목표 이동, 링크/복사 1.6초 표시, 분기 6초 중복 방지·50개 주황, 삭제 4초 재확인·처리 중 표시를 연결했다. 날짜 줄·최대 세 얼굴·네 보고서 색·질문 대기 빨강·처리 완료·TextKit 표·작업 활동 문구/경과 초/2×3 점 꼬리·중지/되돌리기·끼어들기 캡션을 AppKit으로 조립한다. 의견은 작성칸을 열고 확인은 confirm:만 쓴다. checklist 메타는 message/edit에 전달하고 체크 글은 check:만 쓴다. 미전송 선택은 같은 글의 화면 재생성 때 보존하고 서버 메타 변경·스레드 삭제 때 버린다.

**계약·기존 시험의 변경 근거.** 새로운 의미는 승인된 25판 그대로다. 첨부 복사 공백과 Notion·NAS 예시는 24판 원문이다. spec/design/handoff/tasks/수락 명세 Markdown은 구현자가 고치지 않았다. 기존 ConversationTests의 행 수 가정은 REQ-HF-27 날짜 행을 구분하도록 바꿨다. TypingTests의 옛 ‘작성 중’·분/초 표시·스트리밍 동안 대기 행 없음은 REQ-HF-27.AC-04가 요구하는 활동 문구·경과 초·작업 제어 한 줄로 대체했다. 타자 시작 시각·갱신·만료·줄 높이·shimmer·동작 줄이기·스트리밍 캐럿·선택·첨부·재연결 검사는 유지했다. 기존 시험 삭제·skip·오차 완화는 없다.

**보호하는 시험.** gate/tests/test_threads.py는 확정 전 쓰기 실패·같은 seq 치환·늦은 출력·재연결·누락 delete 복구·정리 실패 재시작·공유 첨부 보존·분기 스냅샷/첫 글 한 번·공식 busy stop 경로·체크리스트 프레임과 프레임 한도를 검증한다. AT-73 추가 시험은 종 null/늦은 과거 값과 read 전진을 구분한다. ThreadToolsTests는 복사 원문·주소·종·색·얼굴·체크·날짜·실제 TextKit 표·캐시 소거·미전송 선택·unknown seq를 검사한다. thread_fixture.py는 실제 루프백 WS에서 의견/확인 무송신, 중지/되돌리기/분기/삭제 각 한 번, 끼어들기 해소를 관측한다.

**최종 검사·적용 결과.** 아래 결과는 최종 변경본의 로그를 확인하고 기입했다.

| 검사·적용 | 실제 결과와 로그 |
|---|---|
| 전체 검사 `python3 .build/foundation9_runner.py hejo` | 종료 0, Python 155 passed와 가짜 Hermes·앱·통신 시험 통과. `.build/task25/release-foundation.log`, `release-foundation-run.log` |
| 최종 앱 시험 `bash app/scripts/test.sh` 10회 | 모두 종료 0. `.build/task25/verified-app-results.json`, `.build/foundation9-app-task25-verified-01.log`~`10.log`; 소스 해시 불변 확인 |
| 삭제 seq 치환·종 병합 돌연변이 | 격리 사본에서 각각 pytest 종료 1로 검출, 제품 원본 불변. `.build/task25/mutations.json`, `mutation-projection.log`, `mutation-bell.log` |
| 옛 코드 호환 탐침 | 이전 Journal 열기·이전 LocalStore/ConversationModel live/replay 컴파일·실행 0. `.build/task25/compatibility.json` |
| 같은 상태 원본/이식 카드·실제 대화 캡처 | 컴파일·실행·루프백 시험 모두 0. `.build/task25/reference-capture.json`, `post-checks.json`; 캡처 한계는 증거 문서 참조 |
| 앱 두 사본 교체 | 종료 0, 서명 두 개·실행 파일 해시 일치·hejo 주소 등록. 기존 두 사본의 동일한 번들 설정을 보존했고 운영 앱을 실행하지 않음. `.build/task25/deploy.json`, `deploy-execution.log` |
| 개인값·커밋 전 훅·정적 검사 | Hermes venv 개인값 검사·HEJO_PYTHON 지정 훅·diff 검사 각각 종료 0, 제품 SwiftUI import 0건. `.build/task25/final-checks.json`, `private-final.log`, `hook-final.log`, `diff-final.log`, `static.json` |

**증거와 한계.** 화면 근거는 evidence/HEJO-FOUNDATION/TASK-25.md다. ddots와 hejo 카드에 같은 가짜 상태를 넣은 원본 코드 실행 비교이며 운영 ddots나 실제 두 Mac 화면이 아니다. 별도의 hejo 실제 대화 조립 캡처에 날짜·표·제어 상태를 남겼다. legacy 탐침은 이전 Journal 파서와 이전 LocalStore/ConversationModel의 live/replay 적용을 확인한다. 옛 앱의 캐시는 원문 소거 기능이 없으며 옛 코드의 늦은 출력 차단까지 보장하지 않는다. 실제 모델·도구 부작용·두 Mac·운영 문 재시작·OS의 콜드 URL 실행은 TASK-23에 남는다. stop 시험은 실제 busy 명령 함수와 가짜 interrupt 경계이며 실제 도구 실행을 중단한 증거가 아니다.

**실패 이력·판단.** 초반 시험은 날짜 행·작업 제어로 대체된 옛 UI 기대값, 고정 TTL과 다른 가짜 값, 기존 자동 typing/허용 사용자 설정을 소비하지 않은 시험 도우미에서 실패했고 각각 위 계약에 맞춰 고쳤다. 반복 중 소스 보강으로 생긴 빌드 입력 변경 실패도 최종 열 번에 넣지 않았다. 마지막 연속 열 번의 소스는 해시로 불변을 확인했다. AirportFinder/기존 시험의 Swift 6 경고와 기존 비동기 표시 pytest 경고는 이 작업 밖이며 기준을 낮추지 않았다.

**인계·롤백 경계.** 검토 대상은 이 절을 포함한 TASK-25 단독 커밋이다. 기존 D25 보류 기록을 함께 보존했다. 허브 서버의 state 병합만 승인 범위대로 고쳤으며 운영 허브·설치·게이트웨이 재시작/reload·비밀 파일·ddots/본체/운영 저장소·외부 발송·public·push는 건드리지 않았다. 앱 두 사본은 기존 번들 설정을 보존해 교체하고 운영 앱은 시작하지 않는다. 공유 릴리스는 이 단독 커밋 직후 install/hejo-release로 갱신하며 실행·표식·파일 대조 결과를 .build/task25/release*.json/log에 둔다. TASK-23은 배포 전 공용 창고·앱 사본과 설치 도우미의 정해진 롤백을 확인해야 한다. 기록 종류는 기존 delete이므로 옛 문이 파일을 열 수 있지만, 이 사실을 옛 런타임의 소거·차단 기능 보장으로 확장하지 않는다. 후속 TASK-26 이후는 미착수다.


## N25-01 보완 26 — 편집 기록 치환 시험 보강

받은 기준은 `880b1aedd5258c0472f23f6eb379e58390734c08`이며 제품 동작 변경이 없는 시험 보강이다. `gate/tests/test_threads.py`에 실제 edit를 finalize하여 기록한 뒤 스레드를 지우고, 그 edit 순번이 page와 실제 WS sync 모두에서 정확히 delete로 나오며 본문·첨부·버튼을 내보내지 않는 시험을 추가했다. 기존 시험·제품 코드는 바꾸지 않았다. 필요/도달 증거 수준은 2다. 시험 전용 커밋은 `3928fad46789021080b0281b587e189394730d2b`다.

- `python3 .build/foundation9_runner.py task26-n25 <저장소>/gate/tests/test_threads.py`: 종료 0, 7 passed. `.build/task26/n25-tests-run.log`, `.build/foundation9-task26-n25.log`. 최초 상대 경로 실행은 runner의 작업 디렉터리가 달라 종료 4(수집 전)였고 절대 시험 경로로 바로잡았다.
- `python3 .build/task26/n25_mutation.py`: 종료 0. 격리 사본에서 Journal.replay의 edit만 치환 대상에서 뺀 pytest가 종료 1, 새 시험 1 failed/6 deselected로 검출됐다. 제품 원본 불변. `.build/task26/mutations.json`, `mutation-edit.log`.
- 개인값 검사·HEJO_PYTHON 지정 훅·diff 검사·`git commit --only` 각각 종료 0. `.build/task26/n25-checks.json`, `n25-commit.log`. 커밋은 시험 파일 하나만 포함한다.

## TASK-26 보완 26 착수 대조 — D26-01 보고

**받은 설계·판단.** REQ-HF-28·AT-77~79, 보완 26·17·21·24. 일반, 필요 수준 2. TASK-25 기존 검토 결과는 보존했다. 현재는 원본 함수 실행 대조까지이며 TASK-26 제품 구현·수락 통합의 도달 수준은 1이다. 구현자 판단은 **보류(검색 결과 포함 범위 결정 대기)**다.

**확인 사실.** spec.md REQ-HF-28.AC-02는 '구절이 일치하는 것을 먼저, 그다음 최신 순으로 최대 200묶음'을 요구한다. 원본 SlackSearch.swift:72는 최신 순 글 정렬, 74는 found.prefix(limit=200), 75~79는 그 글들만 그룹화, 80~82는 만들어진 그룹의 구절 우선 정렬이다. 같은 200이라도 적용 단위와 선택 순서가 다르다. 원본의 121줄 전체와 직접 호출자인 SlackFind·SlackFindView, SlackDrafts·ChatWorkspace를 끝까지 읽고 copy-review에 기록했다. 알림·작성기의 나머지 대조는 아직 완료하지 않았다.

**실행 근거.** 원본 SlackSearch의 groups까지를 그대로 추출하고 메시지·스레드 자료형/생각 중 판별만 불활성 대역으로 둔 Swift 실행이다. 원본 앱·제품 API 시험은 아니다. `swiftc .build/task26/search-limit-probe.swift -o .build/task26/search-limit-probe` 종료 0, 실행 종료 0. `.build/task26/search-limit-compile.log`, `search-limit-result.json`, `search-probe-checks.json`.

| 가짜 입력 | 실제 원본 결과 | 계약에서 결정할 차이 |
|---|---|---|
| 한 스레드 안의 일치 글 500개 | 1묶음, 그 안에 200개만 포함 | 200이 글 한도이면 +197건, 묶음 한도이고 모든 일치를 보존하면 +497건 |
| 최신 단어 분산 일치 200개 + 오래된 정확 구절 일치 1개(각 별도 스레드) | 최신 200개만 후보, 정확 구절 일치는 결과에 없음 | 전체 구절 우선으로 200묶음을 고르면 오래된 정확 일치를 포함 |

**선택지·권고.** (A) ddots 동작을 유지: 최신 일치 글 200개를 먼저 고르고 그 안에서 묶음·구절 우선 정렬한다는 계약을 명시한다. (B) 명세 문장 순서를 유지: 전체 일치를 그룹화·구절 우선 정렬한 뒤 200묶음을 고르며 ddots와 다른 결과를 승인한다. 원본 동작 보존이라는 목표에는 A를 권고한다. 상한의 단위와 선택 순서는 수치·결과의 의미이므로 서비스 용어 치환이나 명백한 공백/누락 복원으로 조용히 처리하지 않았다. 계획 담당이 선택과 AT-78 입력/기대를 확정하면 그 계약으로 이어간다.

**변경·미실행·남은 일.** TASK-26 제품 코드는 바꾸지 않았다. 새 저장소·원본·공개 인터페이스·설정 키를 만들지 않았으며 설계·수락 명세를 수정하지 않았다. 두 보고 파일만 미커밋으로 남겨 다음 TASK-26 커밋에 보존한다. 전체 검사·앱 시험·AT-77~79·캡처 비교·앱 교체·릴리스 갱신은 TASK-26에 대해 미실행이다. N25-01 완료와 별개다. 운영 홈 실행·재시작/reload·비밀 파일·ddots/본체/운영 저장소 수정·외부 발송·public·push는 하지 않았다. 푸시 승인은 이번 보류 원인이 아니다. 보류 보고의 개인값·훅·diff 결과는 `.build/task26/report-checks.json`에 둔다. 재개 시 남은 알림 분류·머리줄 편집/작성기/실패 목록·유지 의존 독해부터 이어가고, 미커밋 보고 기록을 보존한다.


## TASK-26 보완 27 — 알림 막대·검색·머리줄·작성기 구현 인계

받은 기준은 `7e71fc501b937287b341d306ae33a0fc626923ab`, REQ-HF-28(26판), AT-77~79와 보완 27·17·21·24다. 일반, 필요한 인계 수준 2. 구현자 판단은 구현·자체 시험 완료이며 실제 도달 수준 2다. 앞의 N25-01·D26-01 당시 보고를 보존했고, D26-01은 26판대로 해소했다. N25-01 시험 전용 커밋은 별도로 유지한다.

**칸과 변경.** 원본은 기존 문 기록장·허브 회원 상태 그대로다. WorkspaceTools는 ConversationModel의 캐시 투영에서 검색·알림을 계산한다. WorkspaceViews·ConversationView는 AppKit 표시·이동·초안을 맡는다. 추가한 실패 목록·얼굴 선택·검색 작업/세대는 실행 중 메모리이며 새 영구 원본·통신·서버 검색을 만들지 않는다. 제목/설명만 기존 title: 회원 키에 JSON 값으로 저장한다. 운영 허브·문 코드는 바꾸지 않았다.

- 알림: asked·확인 상태·종 위치·답글·24시간을 기존 기록에서 분류한다. 질문→알림 순, 원본의 스레드 첫 글 날짜 순으로 순환한다. 알림 클릭과 모두 읽음은 기존 bell:/thread:에 기록한다. 질문·알림 수는 같은 계산을 사이드바에 전달하고 알림 끈 방도 자기 건수를 유지한다. 막대는 원본 색·점/제목/수/› 캡슐과 모두 읽음 버튼이다. 이동은 스레드를 열고 해당 글 위치·1.6초 반짝임을 적용한다.
- 검색: 본문·첨부 이름·말한 이·상태 메모에서 최신 일치 글 200개를 먼저 뽑은 뒤 묶고, 구절 일치 묶음→최신 순이다. 0.25초 뒤 별도 작업에서 검색하며 입력/기록/회원/주소/명부/숨김이 바뀌면 세대로 이전 결과를 버린다. 최대 3개+N, 원문 유니코드 하이라이트, ↑↓·Return·⌘F/ㄹ·Esc를 연결했다. 검색 선택은 긴 글도 펼치고 메시지 anchor로 이동한다. 목록 사이드바는 이름 필터와 별개로 최신 30글·2줄 미리보기를 보인다. 월 보관함·원격 Slack API는 복사하지 않았다.
- 머리줄: 원본 순서 메뉴·제목/설명·저장/취소/기본값 복원, 목록 너비 전환·빈 곳 두 번 누름을 연결했다. ‘이 Mac’ 한정은 사장 Q2에 따라 회원 상태로 바뀐다. 서버 연결 문구도 사용자 지정 용어로 바꿨다.
- 작성기: 얼굴 누름은 원본 멘션 경계로 넣고 빼며, 고른 얼굴은 글·첨부와 함께 자리별로 보관한다. 방을 떠났다 오면 초안 자리로 복귀한다. 새 글의 실제 확인 뒤 직원 답이 오면 비어 있는 작성기만 답글로 전환하고, 사용자 선택·작성 중 글은 보호한다.
- 실패: 전송 실패/확인 없는 글은 원래 자리·내용·첨부를 실행 중 실패 목록에 남기고 자동 재전송하지 않는다. 되살리기는 원래 자리 초안 앞에 합치고 중복 첨부를 제거하며 10개를 넘으면 실패 항목을 보존해 거절한다. 지우기·다른 방 보기·원문 안내 문구를 표시한다. 기존 아일랜드의 명시적 다시 보내기는 먼저 저장한 실패 글을 되살리고 나서 보낸다. 스레드 삭제/연결 변경 때 관련 임시 상태를 지운다.

**기존 시험 변경 근거.** REQ-HF-28이 대신한 기대만 고쳤다. ConversationTests의 실패 시 현재 초안 보존은 실패 목록 보존/명시적 되살리기로 바꾸고 실제 업로드·버튼·다운로드·연결 끊김·자동 재전송 없음 검사를 유지했다. IslandTests는 실패 글 보관 위치·안내와 새 알림 막대 높이를 반영했다. Task17Tests의 옛 머리줄 순서는 새 원본 메뉴 순서로 대체했다. 시험 삭제·skip·오차 확대는 없다. 다른 기존 동작과 TASK-25 검토 결과는 유지한다.

**원본 차이 처리.** 검색 상한은 D26-01 결정을 따른다. ddots의 알림 모두 읽음 버튼 문구는 ‘모두 읽음’이고 n건은 도움말/접근성에 있으므로 원문을 따른다. 머리줄 메뉴의 ‘방 목록 보이기 / 숨기기’·‘전체 검색 (⌘F)’ 띄어쓰기도 원문이다. 알림 색은 원본 #36C5F0, 질문은 #ECB22E다. 제목의 Mac 한정 제거는 사장 Q2 차이이며, Slack 동작/영구 설정 경로는 hejo 기존 책임으로 대체했다. hejo 고유 계약·사장 선택을 임의 변경하지 않았다.

**보호하는 시험.** WorkspaceTests는 AT-77 분류/답한 것/오래된 것/종/알림 끔/탭 건수/순환/반짝/모두 읽음, AT-78 500글·200후보·구절 순서·첨부/말한 이/상태·겹침/유니코드 하이라이트·30건·지연·이동·키, AT-79 메뉴/회원 제목/기본값/너비/초안과 얼굴/실패 합치기/첨부 한도/다른 방을 검증한다. workspace_fixture.py는 실제 루프백 WS에서 빈/작성 중 초안 자동 전환과 실패 안내·재전송 없음, 전송 건수를 확인한다. 실제 editHeader의 NSAlert 저장·다른 값 입력 뒤 취소·기본값 복원은 별도의 가짜 계정 실행에서 네이티브 버튼으로 확인했다. 일반 위험 TASK이므로 별도 제품 돌연변이는 요구되지 않으며, 선행 N25-01 돌연변이는 앞 절에 있다.

**최종 검사·적용 결과.** 중간 개발 실행과 구분해 아래 최종 로그만 판정 근거로 사용한다.

| 검사·적용 | 실제 결과·로그 |
|---|---|
| `python3 .build/foundation9_runner.py hejo` | 종료 0, 156 passed 및 앱·가짜 Hermes·통신 시험 통과. `.build/task26/frozen-foundation.json`, `frozen-foundation.log`, `frozen-foundation-run.log` |
| `bash app/scripts/test.sh` 최종 10회 연속 | 모두 종료 0. `.build/task26/frozen-app-results.json`, `frozen-progress.log`, `.build/foundation9-app-task26-frozen-01.log`~`10.log`; 79개 입력 소스 해시 불변 |
| 실제 AppKit 화면·캡처 | 컴파일·실행 0, AT-77/78/79 통과. `.build/task26/focused-check.json`, `focused-compile.log`, `capture-final.log`; 결과 폭/날짜와 카드 내용 높이 검사 포함 |
| 원문 참조 화면 | 알림·검색 참조 컴파일·실행 각각 0. `.build/task26/reference-notice.json`, `reference-search.json` |
| 실제 네이티브 제목 편집 | 가짜 계정에서 저장·다른 값을 입력한 뒤 취소·기본값 복원 모두 통과. `.build/task26/native-modal.json`, `native-modal.log` |
| 앱 두 사본 | 교체 종료 0, 서명 2개·후보와 설치 사본 해시 일치. 임시 사본의 서명을 제거한 코드 해시는 최종 빌드와도 일치. `.build/task26/deploy.json`, `deploy-execution.log`, `binary-verification.json` |
| 개인값·훅·diff·SwiftUI | Hermes venv 개인값 검사·HEJO_PYTHON 지정 훅·diff 검사 각각 종료 0, 제품 SwiftUI import 0건. `.build/task26/final-checks.json`·`private-final.log`·`hook-final.log`·`diff-final.log`·`static.json` |

**개발 중 실패와 처분.** 새 메뉴·실패 글 보관 위치·알림 막대가 대신한 옛 UI 기대는 위 계약대로 바꿨다. 개발 중 선택값 unwrap·시험의 private clock 접근/리터럴/where 라벨 컴파일 오류와 가짜 명부의 필수 avatar 누락·규격에 없는 error.message는 수정했다. 캡처에서 확인한 날짜 폭과 카드가 빈 공간까지 늘어나는 문제는 배치 수정과 재발 시험으로 처리했다. 이전 시험의 자식 빌드가 남아 겹친 실행도 정리했다. 이 중간 실행·소스 변경 뒤의 이전 반복은 최종 10회에 넣지 않았고, 최종 반복의 해시는 고정했다. 검사 실패를 삼키거나 기준을 낮추지 않았다.

**증거·한계.** 화면은 evidence/HEJO-FOUNDATION/TASK-26.md다. ddots 알림 막대 원문을 불활성 모델로 분리 실행한 참조와 실제 hejo 가짜 계정 화면을 비교했다. 원본 앱 전체·실제 두 Mac·운영 Hermes 연동을 실행한 것은 아니다. 멘션 얼굴은 현재 1:1 명부와 기존 Room.members 경계를 소비하며, 둘 이상의 실제 단체방 명부는 TASK-21에 남는다. 네이티브 편집 창은 대역 계정에서 실제 UI를 실행한 수준 2이며 사장의 수동 실물 확인을 대신하지 않는다. 기존 Swift 6 경고·비동기 pytest 경고는 유지하며 새 지적은 숨기지 않았다.

**검토·롤백.** 이 절과 기존 보류 기록을 포함하는 TASK-26 별도 커밋을 검토한다. 앱 두 사본은 기존 번들 설정을 보존해 교체했으며 운영 앱은 재실행하지 않는다. 공용 릴리스는 단독 커밋 직후 갱신해 RELEASE·파일 대조 결과를 미추적 .build/task26/release*.json/log에 둔다. 공용 릴리스·앱 사본의 교체 전 백업도 .build/task26/ 아래에 있다. 되돌릴 때는 이 사본을 사용하며 회원 title:/bell:/thread: 값은 기존 허브 상태로 남는다. 운영 홈 설치·재시작/reload·비밀 파일·ddots/본체/운영 저장소 수정·실제 발송·public·push는 하지 않았다. TASK-29 이후는 미착수다.

## 구현 인계: TASK-29 펫 알림(보완 28)

**받은 설계·판단.** 기준 `005d3c15a47ddbc8b9e60c06679aeff0ee49d25a`, handoff 보완 28과 17·21·24·27, REQ-HF-30, AT-HF-81이다. 일반 위험·필요 증거 수준 2, 임시 홈/가짜 명부만 사용했다. 구현자 판단은 구현·자체 검증 완료이며 최종 판정은 계획 담당에게 넘긴다. TASK-26 이하 기존 기록은 보존했다.

**책임과 자료 흐름.** 기존 BubbleReveal을 승인 요청 > 실패 > 작성 중 > 새 답 > 평소의 한 가지 말풍선 선택기로 확장했다. AppDelegate는 기존 ConversationModel/IslandModel 입력과 notices·회원 읽음 위치를 전달한다. 새 답 감지는 replay를 기준으로 잡은 후 새 직원 글의 seq만 쓰며 기존 원문을 조회한다. 본문·명부·읽음 원본을 추가하지 않는다. 이 Mac의 LocalSettings.reminders에는 메시지 id와 시각만 원자적으로 저장한다. 새 통신·허브·기록장·Hermes 계약 변경은 없다.

- 승인 요청은 기존 질문 분류/확인/답글을 따르고 스레드를 열면 이 Mac의 표시를 해제한다. 알림 끈 방은 말풍선·펫 전화/작성·답 뛰기에서 빠지며 아일랜드는 기존 분류를 유지한다.
- 새 답은 12초, 버튼은 웹 링크가 있으면 링크 열기 → 대화 열기 → 나중에 알려줘다. 대화 창 열림·앱 시작 전/replay 글·알림 끈 방·쉬기는 새 답을 띄우지 않는다. 나중에 알림은 1800초 뒤 재표시하고 재시작 때 복원하며 읽음/대화 열기/삭제로 취소한다. 저장 실패는 예약을 완료한 것으로 처리하지 않고 기존 말풍선을 남겨 재시도를 허용한다.
- FoldedBubbleView에 기본 AppKit 버튼과 상태 점·반짝임을 연결했다. 작업 중 점은 0.8초 opacity, 부제는 원본 1.8초 주기다. 숨긴 말풍선 대신 머리 옆 파랑/흰 테 9+ 배지를 보이며, 보이는 말풍선에는 안 읽음 수가 남는다. 배치 크기는 버튼 유무에 따라 231×56/90이고 머리·말풍선 사이 점은 7/11/16pt다.
- PetView는 기존 PetChatPlayback으로 포인터·답 도착의 한 번 뛰기를 합친다. 동작 줄이기·쉬기·화면 정지와 승인 전화 우선순위를 지킨다. 기존 AppKit 창·atlas·ShimmerLayer·프로필 얼굴/색·대화 열기 경로를 재사용하며 macOS 알림 센터 API를 쓰지 않는다. TASK-30 입력은 남겼다.

**교체·설계 차이.** AppDelegate의 예전 latest-message/seen-seq 말풍선 경로와 PetView의 별도 3초 타이머·showMessage 경로를 제거했다. 기존 TASK-17 시험의 3초 기대와 마우스 올림 때 대상 글을 상태 문구로 덮던 기대는 REQ-HF-21.AC-02의 19판 대체 명시/REQ-HF-30에 따라 12초·대상 글 유지로 변경했다. 기존 닫힌 펫 unread 시험은 말풍선이 보이면 내부 수, 숨기면 머리 배지로 확인한다. 기존 동작 보존 리팩토링이 아니라 승인된 알림 의미 변경이다. 26판 원문 우선으로 생각 점은 숨긴 동안이 아닌 말풍선이 보일 때만 그린다. 문구 변환·원문 대조는 copy-review TASK-29에 기록했고 hejo 고유 계약·사장 선택은 바꾸지 않았다. 임시 제품 경로나 새 실행 우회는 없다.

**보호 시험.** PetNotificationTests는 시작/replay 기준·우선순위·승인 유지/스레드 열기·12초 경계·버튼 집합/순서/비웹 거절·30분/재시작/읽음 취소·알림 끈 방·쉬기·다른 방 예약의 진행·원자적 저장 실패/회복·기본 버튼 클릭/펫 hit-test·배지/생각 점·반짝임 줄이기·머리에서 버튼으로의 hover 유지·실제 PetView 한 번 뛰기를 보호한다. 승인 선택을 지운 돌연변이는 `AT81 approval wins all priorities`에 실패해 검출했다. 전체 로그는 추적하지 않는 `.build/task29/`에 둔다.

**최종 검사.** 제품 소스를 고정해 검사했다. 10회 반복 뒤 새 시험의 합성 이메일을 개인값 검사가 금지해 주소 입력 한 줄만 바꿨고(단정·제품 코드 불변), 집중 시험과 앱 전체 시험을 추가로 한 번 실행했다. 전후 해시는 fixture-fix.json·commit-snapshot-hashes.json에 남겼다.

| 검사 | 실제 결과·근거 |
| --- | --- |
| 전체 `python3 .build/foundation9_runner.py hejo` | 종료 0, 156 passed 및 AT-81·기존 앱/가짜 Hermes/통신 통과. `.build/task29/frozen-foundation.json`, `frozen-foundation.log` |
| 앱 `bash app/scripts/test.sh` 10회 연속 | 10회 모두 종료 0, 그동안 입력 80개 파일 해시 불변. 이후 합성 주소 입력 한 줄 정리 뒤 집중 시험·앱 전체 추가 1회도 0, 제품 소스 불변. `.build/task29/fixture-fix.json`, `.build/foundation9-app-task29-fixture-clean.json`; `.build/task29/frozen-app-results.json`, `frozen-progress.log`, `.build/foundation9-app-task29-frozen-01.log`~`10.log` |
| AT-81 집중·캡처 | 컴파일·실행 각각 0, `.build/task29/focused-check.json`, `capture-final.log` |
| 승인 우선순위 돌연변이 | 컴파일 0·시험 종료 1(검출), 원본 불변. `.build/task29/mutation.json`, `mutation-priority.log` |
| 원문 참조 캡처 | 컴파일·실행 0, `.build/task29/reference.json` |
| 개인값·훅·diff·SwiftUI | Hermes venv 개인값 검사·HEJO_PYTHON 지정 훅·diff 각각 종료 0, SwiftUI/알림 센터 API 0건. `.build/task29/final-checks.json`, `static.json` |
| 앱 두 사본·공용 릴리스 | 앱 두 사본 서명 2개·기존 번들 설정 보존·후보 해시와 일치·임시 사본의 서명 제거 뒤 코드 해시가 빌드와 일치. `.build/task29/deploy.json`, `binary-verification.json`; 공용 릴리스는 아래 절차대로 커밋 직후 실행하고 `release-verify.json`에 기록 |

**중간 실패 처분.** 집중 시험 초안의 ConversationMessage 인자 순서 오류를 고쳤다. 돌연변이 실행 파일 이름이 대소문자를 구분하지 않는 Mac에서 Tests 폴더와 충돌해 링크 실패한 것은 출력 이름 변경으로 해결했다. 첫 전체 실행은 시험은 통과했지만 실행 중 알림 끈 방 전화 동작 필터를 보강해 소스 해시 불변 검사가 실패했으므로 최종 근거에서 제외했다. 머리/말풍선 hover 연결·알림 끈 방의 지난 예약 제거·화면 정지의 점 애니메이션도 보강했다. 이전 반복 중 그 파일을 수정해 Swift가 ‘input file modified during build’로 거절한 실행은 개발 중 실행으로 제외했다. 최종 전체 검사·반복은 이 경계 시험까지 통과한 소스로 고정했다. 최종 stage 개인값 검사에서 새 시험의 합성 이메일 1건을 검출했다. 사전 검사는 아직 추적하지 않던 새 시험을 포함하지 못했으므로 최종 검사로 쓰지 않는다. 이메일 없는 비웹 URI로 시험 입력만 바꾸고 다시 확인했다. 시험 단정·수락 기준을 완화하거나 실패를 숨기지 않았다.

**증거·미검증·검토점.** 필요/도달 수준 2다. 화면은 evidence/HEJO-FOUNDATION/TASK-29.md에 있고 같은 가짜 상태의 원본 AppKit 그리기와 hejo 제어·펫 조립 시험이다. 운영 앱 전체·두 Mac·실제 Hermes 답 도착·실제 브라우저 외부 열기를 시험하지 않았다. 링크 시험은 NSWorkspace 실행 대신 콜백 대상/허용 체계까지 확인하며 실제 열기는 TASK-23에 남는다. 기존 Swift 6 경고와 pytest 경고는 유지한다. 별도 에이전트는 쓰지 않았다. 검토자는 replay→새 답 경계·예약의 읽음/삭제 취소·알림 끈 방의 펫 동작과 26판 생각 점 차이를 특히 확인해 주면 된다. 범위 밖 새 부채는 발견하지 않았다.

**검토 대상·적용·롤백.** 이 절·copy-review·캡처·앱 변경을 포함하는 TASK-29 단독 커밋이다. 앱 두 사본은 기존 번들 설정을 보존해 교체하고 재실행하지 않는다. 공용 릴리스는 커밋 직후 갱신해 RELEASE와 파일을 대조한다. 교체 전 백업은 `.build/task29/deploy-backup`·`release-backup`이다. 앱 코드 롤백 때 이 사본을 사용하며 reminders는 선택 필드이므로 옛 앱이 무시한다. 운영 홈 설치·재시작/reload·비밀 파일 열기·ddots/본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. TASK-30 이후는 미착수다.

## 구현 인계: TASK-30 말풍선에서 바로 답하기(보완 29)

- 기준: TASK-29 검토 뒤 `6b1e27b`. 요청 범위 TASK-30만 구현했고 다음 TASK-27·21·32는 미착수다. 필요 증거 수준 2 / 도달 수준 2이며 실제 서버·운영 앱 실물은 TASK-23에 남는다.
- 칸: 기존 ConversationController.drafts·pending 확인 ID·interruptions를 재사용한다. BubbleReplyCard는 hover·포커스·표시 오류만 가지며 별도 초안 저장소·전송 경로를 만들지 않는다. 말풍선은 텍스트만 보내고 대화창 첨부는 보존한다. 늦은 거절/재연결 미확인은 원래 스레드 입력으로 복원하고 자동 재전송하지 않는다.
- AppKit: 0.3초 hover·빈 입력 0.6초·설정/연결/쉬기/대화 열림/대상 조건, 일반/작성 중/queue 안내, Return·⇧Return, 스레드별 초안, Esc 입력 먼저, 접근성 이름을 연결했다. 마우스로 실제 입력을 누를 때만 키 창이 되며 열림 자체는 포커스를 훔치지 않는다. IME 조합은 재발행으로 덮어쓰지 않는다. 끼어들기 표시는 기존 작업 제어 상태를 사용한다.
- 명부: gate/roster.py가 각 프로필 config.yaml의 display.busy_input_mode를 원본 규칙으로 읽기만 하고 queued boolean을 보낸다. 필요 동반 변경으로 규격 employee 선택 필드·앱 Codable을 추가했다. 필드 없는 옛 명부는 false, 추가 필드는 옛 앱이 무시한다. Hermes 본체·설정 쓰기는 없다.
- 설정: ‘화면과 펫’의 ‘말풍선에서 바로 답하기’ 기본 켬. 기존 펫 설정 허브 원본/로컬 오프라인 사본 경로를 사용한다.
- 원본 대조: copy-review에 파일별 전체 독해·의존 경계·변환 규칙을 기록했다. 원본 3줄은 표시 높이 제한이고 넘는 글을 스크롤하므로 같은 동작을 유지했다(26판). 원본의 한 칸 초안 비우기 대신 승인된 hejo 계약대로 기존 스레드별 초안을 복원한다. 새 계약·사장 선택 변경은 없다.
- 화면: evidence/HEJO-FOUNDATION/TASK-30.md. 원본 BubbleReplyView·NativeDraft 전체 분리 실행과 실제 hejo AppKit 조립을 같은 가짜 입력·231pt로 비교했다. 서식/테마/붙여넣기 변환은 불활성 대역이며 원본 앱·운영 앱 전체 비교가 아니다. 이 상태의 원본 60px·hejo 57px 높이 차이도 증거 문서에 명시했고 화소 완전 일치로 주장하지 않는다.

검증은 아래 최종 변경본 기준이다.

| 검사 | 실제 결과·증거 |
| --- | --- |
| AT-82·전체 | 종료 0, 157 passed 및 AT-82·기존 앱/가짜 Hermes/통신 통과. `.build/task30/frozen-foundation.json`, `frozen-foundation.log` |
| 앱 반복 | 10회 모두 종료 0, 최종 입력 83개 파일 해시 불변. `.build/task30/frozen-app-results.json`, `frozen-progress.log`, `.build/foundation9-app-task30-frozen-01.log`~`10.log` |
| 돌연변이 | hover dwell 비교 제거 시 즉시 열림을 ‘AT82 hover does not take keyboard before dwell’가 검출(컴파일 0·시험 1). 원본 바이트 불변, `.build/task30/mutation.json`, `mutation-hover.log`. |
| 캡처·루프백 | 최종 소스로 캡처 종료 0, 같은 상태 원본 분리 컴파일·실행 0; 최종 전체/반복 검사 안의 루프백 전송·거절 통과. `.build/task30/capture-final.json`, `reference.json`, `network.json` |
| 개인값·훅·정적 | Hermes venv 개인값 검사·HEJO_PYTHON 지정 훅·diff 각각 종료 0, SwiftUI/알림 센터 API 0건. `.build/task30/final-checks.json`, `static.json` |
| 적용 | 앱 두 사본 서명 2개·기존 번들 설정 보존·후보 해시와 일치·임시 사본의 서명 제거 뒤 코드 해시가 빌드와 일치. `.build/task30/deploy.json`, `binary-verification.json`; 공용 릴리스는 커밋 직후 실행하고 `release-verify.json`에 기록 |

개발 중 오류: 첫 새 시험은 비동기 호출을 동기 단정 autoclosure에 넣어 컴파일되지 않았고, 가짜 문 typing TTL을 규격 6 대신 10으로 넣어 거절됐다. 시험 코드를 고쳐 집중 검증했다. 전체 검사 중 시험 진입점 수정이 겹친 첫 실행은 컴파일러의 ‘input file modified during build’로 실패했다. 이후 최종 소스를 고정해 전체 검사와 반복 검사를 새로 실행했으며 실패 실행을 통과 근거로 세지 않았다.

위험·롤백: 실제 서버 busy queue/steer·한국어 장기 입력·운영 창 결합은 TASK-23에서 확인한다. 필요하면 앱 두 사본은 `.build/task30/deploy-backup`을 사용해 원래 위치로 돌리고 공용 릴리스는 `release-backup`으로 복원한다. 재실행·운영 설치·게이트웨이 재시작 없이 파일 사본만 교체했다. 운영 홈 실행·비밀 파일 열기·ddots/본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. 별도 커밋 뒤 계획 담당 검토를 요청한다.

## 구현 인계: TASK-27 홈 방(보완 30)

1. 받은 설계: handoff.md 보완 30·REQ-HF-29·AT-80, 기준 `cfe7e920e44891b40f6062b9a64431dadfa0fe59`. 연합개발 구현·자체 시험, 일반·필요 증거 수준 2 / 도달 수준 2다. 구현자 판단은 구현·자체 시험 완료이며 최종 판정은 계획 담당에게 넘긴다.
2. 책임·칸: HomeRoom은 기존 직원 명부·기록장 투영을 받아 구성원/대상/활동 순서를 계산한다. 설정은 허브 회원 상태의 승인된 `layout:home` 하나다(members·recipient·muted·picture). 사진 바이트는 TASK-20의 인증된 room API와 `home-main` 경로를 써서 공용 창고 `shared/hejo/pictures/home-main.png`에 둔다. 새 영구 원본·문/허브/규격 변경은 없다.
3. 구현: ConversationModel의 홈 선택·합친 목록·사진 주소·직원 포함/제외·기본 대상·알림 설정, ConversationController의 기존 초안/선택/전송 연결, ConversationView의 홈 행·사진/설정 메뉴·카드 직원 얼굴/이름·작성기 얼굴을 추가했다. 기존 ComposerFaces에 홈의 24px 얼굴·밝기·명시 선택 링을 반영했다. AppDelegate의 펫 배지·말풍선·작성 중 필터는 홈 소속 직원의 알림 끔을 반영한다. 펫 이름이 바뀌면 홈도 즉시 갱신한다. 화면의 기존 연결 문구 두 곳은 사용자 지시에 따라 ‘서버’로 맞췄다.
4. 전송·초안: 홈 새 글은 기존 메모리 초안의 임시 위치를 쓰고 직원과 새 UUID를 정한 뒤 기존 send/첨부/pending 경로로 보낸다. 첫 글 확인 뒤에도 화면이 새 글 모드라면 그 의도를 전달해 다음 직원·새 UUID를 다시 정하며 답글과 구별한다. 임시 `@home`은 Hermes 프로필 이름 규칙 밖의 UI 식별자이며 문/기록장에 보내지 않는다. 얼굴 > @이름/별칭 > 기본 순서, 두 명/제외 대상 거절, 얼굴 다시 누르기 해제, 홈에서 연 스레드 답글·읽음의 원래 1:1 키를 유지한다. 뺀 얼굴의 오래된 명시 선택도 다른 직원으로 바꾸지 않고 거절한다. 기존 대체 경로를 남기지 않았고 별도 초안/기록 사본은 없다.
5. 원본·차이: copy-review.md에 파일별 전체 독해 재사용 근거와 재대조·유지 의존을 기록했다. 26판에 따라 원본 byActivity 오름차순(최신 활동이 아래)을 유지했다. 승인된 Q2/Q3에 따라 로컬 제외/기본 대상 대신 회원 상태를 쓰며 한 명만 보낸다. Slack 공용 채널·업무별 자동 라우팅·개인 설정은 제외했다. 고정 채널 메뉴는 명시된 TASK-21 뒤에 남긴다. 그 밖의 새 계약 변경은 없다. 기능 추가이며 동작 보존만의 리팩토링이 아니다.
6. 시험: HomeRoomTests는 활동 순서·기록 중복 없음·대상 우선순위·거절 문구·얼굴 토글/링·읽음 공유·홈 알림 끔·회원 상태 복원·메뉴 체크를 보호한다. home_room_fixture는 실제 루프백 WebSocket에서 새 스레드/원래 답글/거절 무송신을 관측하고 기존 사진 API의 인증·PUT·실패/성공 DELETE와 주소 보존을 검증한다. 기존 수락 기준·시험 기대값은 바꾸지 않았다.

| 검사 | 실제 결과·증거 |
| --- | --- |
| 전체 검사 | 종료 0, 157 passed 및 AT-80·기존 앱/가짜 Hermes/통신 통과. `.build/task27/frozen-foundation.json`, `frozen-foundation.log` |
| 앱 반복 | 10회 모두 종료 0, 최종 입력 86개 파일 해시 불변. `.build/task27/frozen-app-results.json`, `frozen-progress.log`, `.build/foundation9-app-task27-frozen-01.log`~`10.log` |
| 핵심 돌연변이 | 명시 얼굴을 무시한 HomeRoom 사본은 우선순위 시험에 검출됐고, 최종 Controller에서 빈 입력 검사를 지운 사본은 ‘AT80 empty Return keeps home draft and receiver’에 검출됐다. 각각 컴파일 0·시험 1·원본 불변. `.build/task27/priority-mutation.json`, `mutation.json`, `mutation-priority.log`, `mutation-empty.log`. |
| 화면·루프백 | 최종 코드 캡처·원본 분리 실행·가짜 문 집중 시험 각각 종료 0. `.build/task27/capture-final.json`, `reference.json`, `reference.log`, `network.json`. |
| 개인값·정적 | Hermes venv 개인값 검사·HEJO_PYTHON 지정 훅·diff 각각 종료 0, SwiftUI/알림 센터 API 0건. `.build/task27/final-checks.json`, `static.json` |
| 적용 | 앱 두 사본 서명 2개·기존 번들 설정 보존·후보 해시와 일치·임시 사본의 서명 제거 뒤 코드 해시가 빌드와 일치. `.build/task27/deploy.json`, `binary-verification.json`; 공용 릴리스는 커밋 직후 실행하고 `release-verify.json`에 기록 |

증거는 evidence/HEJO-FOUNDATION/TASK-27.md다. 원본 ddotsFaces·avatarBadge와 실제 ComposerFaces를 같은 직원·색·@직원 B/명시 선택 상태로 비교했고 원본 byActivity를 실행했다. 원본 앱·운영 앱 전체 비교는 아니다. 얼굴 PNG는 시험 창과 같은 흰 배경에 합성했으며 내용·배치를 고치지 않았다. 전체 hejo 그림은 실제 AppKit 보기 조립이다.

개발 중 오류는 최종 근거에서 제외했다. 초기 컴파일의 선택 방 optional 타입 오류, 초안이 없을 때 얼굴 선택의 nil 접근, 명부 없이 재시작 복원을 단정한 시험 구성, 가짜 welcome의 필수 avatar 누락을 고쳤다. 원본 얼굴 크기·링 모양을 대조했다. 이후 코드 대조에서 빈 Return 때 홈 작성 키가 직원 키로 먼저 바뀌어 다음 @대상을 잘못 보낼 수 있는 경계를 발견했다. 진행 중 반복 검사는 자식 검사가 끝난 경계에서 중단했고 `.build/task27/pre-empty-guard/`에 보존해 최종 근거에서 제외했다. 빈 입력 검사 순서를 고치고 작성 위치·선택 보존 시험과 돌연변이를 추가했다. 첫 글 확인 직후 연속 새 글도 UI 모드대로 별도 직원/UUID로 보내는 루프백 경계를 더한 뒤 최종 소스로 전체/10회 반복을 새로 실행했다. 선택 링 분리 캡처의 첫 컴파일은 Chrome의 불필요 의존을 포함해 실패했으며 실제 ComposerFaces 전체만 분리해 해결했다. 제품 시험 실패를 수락 기준 완화로 처리하지 않았다.

미검증·위험: 실제 서버·두 Mac 상태 맞춤·실물 사진/긴 입력은 TASK-23에 남는다. 단체방과 고정 채널 결합은 TASK-21 범위다. 범위 밖 새 부채·임시 제품 코드·하위 에이전트 사용은 없다. 검토자는 홈 임시 작성 위치가 전송/기록장에 나가지 않는지, 제외 대상 무송신, 읽음 공유, 홈 알림 필터를 특히 확인해 주면 된다.

검토 대상은 이 절·copy-review·화면 증거·제품/시험을 포함한 TASK-27 별도 커밋(main)이다. 앱 두 사본은 기존 번들 설정을 보존해 교체하고 재실행하지 않는다. 공용 릴리스는 커밋 직후 갱신하고 RELEASE/파일을 대조한다. 교체 전 사본은 `.build/task27/deploy-backup`·`release-backup`이며 롤백 시 이 사본을 복원한다. 운영 홈 설치·재시작/reload·비밀 파일 열기·ddots/Hermes 본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. TASK-21·32는 미착수다.

## 구현 인계: TASK-21 착수·D21-01 보류(보완 31)

1. 받은 설계: handoff.md 보완 31(27판), REQ-HF-24·29, AT-70·71. 기준 `df7709dc4543f0ba6492a5f2fd53aa527c42f38f`. 고위험, 필요 증거 수준 2 / 이번 작업 인계 도달 수준 1(착수 조사·원본 함수 재현; 단체방 통합 수락은 미완료). 구현자 판단은 **보류(구현 규칙 2절, hejo 전달 계약 충돌)**다.
2. 완료한 조사: TASK-27 완료 판정과 실제 HEAD·깨끗한 작업 트리를 대조했다. copy-review.md에 원본 전체 독해 재사용·diff 0·이번 방 창/메뉴/홈 고정 채널의 유지 의존과 재대조를 파일별로 기록했다. 제품 초안은 기존 Journal·Files·Pictures·Context·Room/캐시·MemberState를 확장하는 방식으로 작성했다. 새 영구 원본·운영 변경은 없다.
3. **D21-01 확인:** 고정 채널을 고른 홈에서 A 얼굴을 누르고 `@B 질문`을 쓴다. REQ-HF-29.AC-01(spec.md:299), 기존 HomeRoom.destination(HomeRoom.swift:33~42)은 A 한 명을 선택한다. 그런데 REQ-HF-24.AC-02(spec.md:194)는 본문에 부른 B에게만 전달한다. 기존 send의 employee는 1:1 대상이고, room을 더하는 설계에는 별도의 단일 수신자 우선 필드·원문과 전달 호출을 분리할 규칙이 없다. 단체방에서 employee를 임의로 우선시하면 같은 AC-02를 깨므로 구현자가 의미를 바꾸지 않았다.
4. **재현:** 기준 커밋의 Employee·HomeRoom 실제 구조체를 분리 컴파일·실행하면 A가 나온다. 작성 중이던 방 호출 초안(AC-02 그대로)은 본문 `@B 질문`에서 B, 선택 얼굴을 단순 덧붙인 `@A @B 질문`에서 A/B 둘 다를 고른다. 원본 ddots도 SlackPanel.swift:534~538 → SlackThreads.swift:768~784에서 기존 호출이 있으면 선택 얼굴을 추가하지 않아 B로 간다. 즉 원본 그대로·본문 앞 호출 추가 모두 홈의 승인된 ‘얼굴 우선·한 명’을 만족하지 못한다. `.build/task21/home-contract.json`, `home-contract.swift`, `home-compile.log`, `probe_home_contract.py`. 원본 HomeRoom의 실행+단체방 전달 초안의 규칙 재현이며 제품 전체 수락 시험은 아니다.
5. **계획 담당 결정 필요:** (A) 고정 채널을 선택하면 일반 단체방 작성기로 전환하고 얼굴 우선·한 명 규칙의 적용 범위를 명시, (B) 홈 규칙을 유지하되 인증된 send에 방 구성원 한 명을 명시할 선택 필드와 우선순위·검증·원문 보존·하위 호환·AT를 설계, (C) 고정 채널은 홈 조회에만 결합하고 쓰기는 기존 1:1로 유지. 고정 채널에서도 홈의 얼굴 우선·한 명을 유지하려면 B를 권고한다. 어느 것도 채택하지 않았다. 임의로 본문 @를 지우거나 다른 직원에게 보내지 않는다.
6. **실제 변경 상태:** 미완성 제품·시험 초안 15개를 추적하지 않는 `.build/task21/draft/`와 `draft-snapshot.json`에 보존했다. 제품은 착수 HEAD로 되돌렸고 추적 변경은 copy-review.md·이 보고 두 파일뿐이다. 초안의 AppKit 메뉴/창/자동 완성은 미완성이며 앱 컴파일·수락·배포 대상이 아니다. 이 두 보고는 실행 담당 소유이며 재개 뒤 TASK-21 커밋에 보존한다. 기존 TASK 보고·판정은 건드리지 않았다. 새 커밋은 없다.

| 실행 | 실제 결과·한계 |
| --- | --- |
| `python3 .build/task21/probe_home_contract.py` | 종료 0. 기준 HomeRoom의 swiftc·실행 각각 0, A/B 전달 차이 재현. `.build/task21/home-contract.json`. |
| `python3 .build/foundation9_runner.py task21-gate …/gate/tests/test_threads.py` | 종료 0, 기존 스레드 시험 7 passed(제품 초안 변경본). `.build/foundation9-task21-gate.log`. |
| `python3 .build/foundation9_runner.py task21-rooms-draft …/gate/tests/test_rooms.py` | 종료 0, 초안 4 passed(실제 루프백·가짜 Hermes, 방 기록/seq 치환/옛 연결/실패·늦은 출력/재시작 정리/@/전달자). 제품 전체 AT-70·71 완료를 뜻하지 않는다. 최초 실행은 PNG 상수 이름 import 오류로 1 failed/3 passed, 기존 png() 도우미로 수정한 뒤 재실행했다. `.build/foundation9-task21-rooms-draft.log`. |

전체 foundation hejo·앱 반복·고위험 돌연변이·최종 캡처·앱 두 사본 교체·공용 릴리스 갱신·TASK-21 커밋은 미실행이다. 최종 보고 변경본 개인값 검사·훅·diff 결과는 `.build/task21/report-checks.json`에 둔다. 새 제품 코드는 남기지 않았으며 TASK-27 설치본/공용 릴리스는 그대로다. 운영 홈 실행·설치·재시작/reload·비밀 파일 열기·ddots/Hermes 본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. TASK-32는 미착수다. 푸시 승인이 아니라 D21-01 전달 계약 결정 때문에 멈춘다.

## TASK-21 재개 상태(28판, 보완 32)

D21-01은 계획 커밋 `0c5a3bd573172c2dfdcdbb196c82c743295163c0`의 고정 채널 규칙으로 해소했다. 앞 보류 기록은 당시 결과로 보존한다. 초안을 복원해 문·규격·AppKit·루프백 시험을 구현했고 최종 전체/반복 검사·캡처·적용·커밋을 진행한다. 완료 결과는 아래 최종 인계 절에 기록한다. TASK-32는 아직 착수하지 않는다.

## 구현 인계: TASK-21 단체방 최종(보완 31·32, 27·28판)

1. 받은 설계: handoff.md 보완 31·32, REQ-HF-24·29, AT-70·71·80, 기준 `0c5a3bd573172c2dfdcdbb196c82c743295163c0`. 고위험, 연합개발 구현·자체 시험이다. **필요·도달 증거 수준 2**이며 자체 판단은 구현·자체 시험 완료다. 최종 수준 4(TASK-23)와 비설계자 검토는 남고 최종 판정은 계획 담당에게 넘긴다. D21-01의 앞 보류 기록은 당시 근거로 보존했다.
2. 문·영구 원본: 기존 Journal에 room 전체 상태·room_delete 확정 한 줄을 더했다. room/deleted_rooms는 기록장에서 재구성하는 인덱스다. RoomCommands는 사장 요청 검증·직원 호출·수신 문맥을 맡는다. 방을 지울 때 글마다 delete를 쓰지 않는다. 확정 뒤 page/sync/live 재현은 글·편집·상태를 같은 seq delete로, room은 id/deleted만, room_delete는 room_deleted로 투영한다. message 조회와 파일 등록/조회에서 지운 방은 빠진다. 기존 FileStore·Pictures를 통해 전용 파일/사진만 정리하며, 확정 뒤 정리 실패는 재시작 때 재시도한다. 늦은 답·편집·상태·작성 중·직원 첨부는 room_deleted_drop으로 버린다. 큰 늦은 편집도 내용 검사 전에 버린다.
3. 규격·전달: v1에 승인된 room 프레임·선택 필드·hello.features rooms를 추가했다. welcome의 방 목록과 sync는 기록장을 쓴다. rooms 없는 옛 연결에는 방 내용을 같은 seq delete로 바꾸고 작성 중은 보내지 않는다. 방 글은 구성원 이름/별명으로 부른 직원만, 없으면 대표에게 source.profile과 chat_id room:<id>로 넘긴다. 보조 프로필 전달자도 방 주소를 보존한다. 직원이 받지 못한 앞 글은 기존 gate/context.py로 20줄·4,000자·본문 500자까지 묶는다. 수신 대상은 같은 사장 글의 내부 기록 메타에 남아 문맥을 계산하며, 앱·기록장 본문은 원문이다. 새 저장소·본체 우회·외부 발송 경로는 없다.
4. 사진: 기존 인증 room 사진 API는 실제 방 id를 확인한다(구획/홈 예약 이름은 기존 경로). PUT/DELETE 뒤 같은 room 상태를 기록·방송한다. 메타 기록 실패 때 이번 사진만 원복하며 파일 전체/다른 방을 복원하지 않는다. 직원 사진·색 원본은 TASK-20 그대로다.
5. 앱: 기존 Room·ConversationMessage에 단체방과 실제 발화자를 구분하고 기존 LocalStore의 원자적 같은-seq 캐시 치환을 방 삭제에 재사용했다. 읽음·배치는 기존 MemberState 키다. 새 방은 첫 구획, 보관은 고정 해제·목록 제외, 되살리면 열기, 삭제는 방·캐시·작성 중·초안/대기 전송을 소거한다. 지운 방 고정 자리도 풀어 남은 자리를 막지 않는다. 보관에 따른 고정 해제는 최신 welcome/동기화 완료 상태를 확인한 뒤 처리하며, 과거 보관 기록을 재생해 나중의 활성 방 고정을 지우지 않는다. AppKit 새 방/직원 초대/대표 메뉴/사진/제목·설명/보관·삭제 확인과 방 구성원만의 @ 자동 완성, 말한 직원 이름·색·얼굴을 연결했다. 직원 빼기는 작성기 얼굴 우클릭에서 하며, 대표 또는 두 명 미만이 되는 제거는 비활성이다. AC-03 주 메뉴 순서는 바꾸지 않았다. 직접 대화와 단체방 모두 기존 카드·표·버튼·첨부·작업 제어를 쓴다.
6. 홈 28판: 고정 채널 새 글은 그 방 새 UUID 스레드다. 본문 호출이 있으면 그대로, 시작 별명은 이름으로, 호출 없을 때만 선택 얼굴을 앞붙이고 둘 다 없으면 대표가 받는다. 1:1 홈 제외/기본 받을 직원/단일 수신자 규칙을 채널 모드에 적용하지 않는다. 채널 모드 얼굴·자동 완성은 방 구성원을 쓴다. 기존 초안 사전에 홈의 작성 위치를 채널별로 나눠, 다른 채널/1:1로 바꿨다 돌아와도 글을 보존한다(새 영구 초안 원본 없음). 홈 알림 끔은 포함된 1:1과 선택 채널을 함께 조용히 한다.
7. 유지·대체: 직접 대화 경로를 별도로 복사하지 않고 기존 send/pending/files·MessageEvent 전달·캐시·기록장 투영을 확장했다. SidebarLayout·허브 상태·설치 도우미·Hermes 본체·ddots는 변경하지 않았다. copy-review.md에 지정 원본 전체 독해 재사용과 SlackBridge 전체 추가 독해·이식/제외를 기록했다. D21-01 외 새 계약 변경은 없다. 기능 추가이며 동작 보존 리팩토링이 아니다.

| 검사 | 실제 결과·증거 |
| --- | --- |
| 전체 | `python3 .build/task21/frozen_full.py` 내부 foundation9_runner.py hejo 종료 0, 164 passed 및 앱·가짜 Hermes·통신·AT-70/71/80 통과. `.build/task21/frozen-foundation.log`, `frozen-foundation.json`. |
| 앱 반복 | `python3 .build/task21/frozen_repeat.py` 종료 0, 실제 bash app/scripts/test.sh 10회 연속 0, 최종 입력 89개 해시 불변. `.build/task21/frozen-app-results.json`, `frozen-progress.log`, `.build/foundation9-app-task21-frozen-01.log`~`10.log`. |
| 고위험 돌연변이 | 삭제 방 seq 투영 제거 / 옛 연결 내용 치환 제거 사본을 각각 실행했다. 도우미 종료 0, pytest 각각 1·1 failed로 검출, 원본 불변. `.build/task21/mutations.json`, `mutation-room-seq.log`, `mutation-legacy-seq.log`. 과거 보관 기록에서 고정을 지우는 동작을 되넣은 사본도 컴파일 0·시험 1의 ‘AT70 history replay preserves newer active-room pin’에 검출했다(`mutation-archive.json`, `mutation-archive.log`). |
| 문 AT-70·71 | 루프백 2개 새 연결·옛 연결, 이름/설명/대표/보관/복원·삭제, fsync 실패 원문 바이트 보존, 정리 실패 뒤 두 번 재시작, 늦은 답/편집/상태/작성 중/파일, 같은 seq page/sync·welcome, 첨부 공유 보존, 사진 인증/존재/실패 원복, 받은 뒤 놓친 5줄·다른/지운 스레드 제외·20줄/4,000자/500자 입력을 관측했다. `.build/foundation9-task21-rooms-final.log`(7 passed), 최종 전체 로그에도 포함. |
| AppKit ↔ 실제 문 ↔ 가짜 Hermes | `app/Tests/rooms_fixture.py`에서 실제 인증·WebSocket·앱 캐시로 13개 직원 전달, @/얼굴/대표/별명/밖 직원/다중 호출/빈 글·보관/복원/삭제를 확인했다. 최종 전체/반복 로그의 `ROOMS_GATE_APP_FIXTURE_PASS 13`. 실제 Hermes 추론·외부 전송은 대역이다. |
| 화면 | 원본/제품 창 내용 분리 컴파일·실행 각각 0. 최종 제품 보기 조립·캡처 컴파일/실행 각각 0, 제품 소스 불변. `.build/task21/dialog-comparison.json`, `capture-final.json`, `white-capture.log`. |
| 개인값·정적 | Hermes venv scripts/scan_private.py·HEJO_PYTHON 지정 githooks/pre-commit·diff 각각 종료 0, 제품 SwiftUI·알림 센터 API 0건. `.build/task21/final-checks.json`, `static.json`. |
| 적용 | 앱 두 사본 서명 2개·후보/빌드 코드 대조·기존 번들 설정 보존. `.build/task21/deploy.json`, `binary-verification.json`. 공용 릴리스는 커밋 직후 갱신해 `release-verify.json`에 표식·파일 결과를 남긴다. |

기존 앱 시험 중 승인된 기능 추가에 직접 대응하는 자료만 바꿨다: Task17Tests의 빈 곳 메뉴·PicturesSidebarTests의 ＋ 메뉴에 새 방 항목, HomeRoomTests 메뉴에 고정 채널 항목을 더했다(AC-05·REQ-HF-29). ThreadToolsTests의 가짜 답한 얼굴은 새 발화자 필드에도 같은 가짜 직원 값을 넣었다. 얼굴 기대값 세 개·수치·수락 기준은 그대로다. 기획설계 AT 문서·spec·design은 수정하지 않았다.

개발 중 초안의 문자열 prefix API/실수 리터럴·픽스처 PNG 이름 오류를 고쳤다. 옛 메뉴 기대는 위 승인 기능에 맞게 추가했고, 가짜 발화자 자료는 새 모델에 맞췄다. 실제 문 픽스처 종료 때 Hermes 진단 상태 쓰기가 남는 문제는 공식 background 취소·runtime status flush를 기다려 해결했다(오류 억제/임의 sleep 아님). NSAlert 자체 캡처는 내용이 빠졌고, 비동기 시험 안의 모달 캡처 시도는 정지해 해당 시험 자식만 종료했다. 모달 캡처를 최종 시험에서 제거하고 실제 셀·문구의 분리 시험 창을 썼다. 초기 전체 실패와 수정 중 해시 불일치 실행은 최종 증거에서 제외했다. 복구 검토에서 발견한 과거 보관 기록의 고정 소거는 최신 상태 확인 뒤로 옮기고 회귀·돌연변이 시험을 더했다. 그 전 반복 5회 통과·6번째 실행의 소스 변경 검출 기록은 `.build/task21/pre-archive-replay/`에 보존하고 최종 10회 근거에서 제외했다. 별도 소켓이 없는 단위 시험에서 최신 동기화 완료 상태 대신 물리 소켓을 요구하던 고정 해제 조건을 바로잡았다. 최종 전체·10회 반복은 고정 소스로 새로 실행했다.

화면 근거는 evidence/HEJO-FOUNDATION/TASK-21.md다. 실제 제품 보기와 같은 상태의 원본/제품 초대 셀 비교이며 원본·운영 앱 전체 실행은 아니다. 대화 그림은 시험 창의 밝은 배경만 지정해 다시 그렸고 PNG 사후 수정은 하지 않았다. 초대 그림은 실제 NSAlert 외곽의 픽셀 일치를 주장하지 않는다.

위험·미검증: 실제 서버 직원 2명·두 Mac·바쁜 세션/긴 한국어 입력·운영 적용은 TASK-23에 남는다. 새 앱을 운영 문에 연결하는 실물 호환은 그때 맞는 공용 릴리스로 적용한 뒤 확인한다. room/room_delete가 기록된 뒤 문 코드만 되돌리면 안 된다. **design 15판의 운영 shared/hejo 자료 사본(기록장·첨부·사진)과 이전 릴리스를 함께 복원**해야 한다. 이번 `.build/task21/deploy-backup`·`release-backup`은 앱/공용 릴리스 교체용이고 TASK-23 운영 자료 사본을 대신하지 않는다. 설치·제거·운영 데이터 롤백은 이번에 실행하지 않았다.

검토자는 GateServer.project·Journal.replay·RoomCommands.room_context, 늦은 출력과 보조 전달자의 방 주소, LocalStore.redacting·홈 작성 위치를 특히 확인하면 된다. TASK-21 별도 커밋 대상은 이 절·copy-review·제품/시험·화면 증거다. 앱 두 사본은 기존 번들 설정을 보존하고 재실행하지 않는다. 공용 릴리스는 커밋 뒤 표식/파일을 대조한다. 운영 홈 설치·실행·재시작/reload·비밀 파일 열기·ddots/Hermes 본체/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. TASK-32는 미착수다. 계획 담당 검토로 넘기며 푸시 승인 대기로 멈추지 않는다.


## 구현 인계: TASK-32 착수·D32-01 보류(보완 33)

1. 받은 설계: REQ-HF-32·AT-83, design 20판·21판 D1~D8, handoff 보완 33, 기준 `b19e03720dda05525db92de472fdbf2004c8ac72`. 고위험이며 인계 필요 수준 2 / 현재 TASK-32 전체 도달 수준 1(착수 대조)이다. 아래 실제 공식 함수·HTTP 재현은 해당 경계의 조사 근거이며 제품 AT-83 통과가 아니다. 구현자 판단은 **보류(구현 규칙 2절, 공식 쓰기 경로와 hejo 보안·무결성 계약 충돌)**다.
2. D1 관측: 임시 HERMES_HOME 기본+alpha+beta에서 Hermes venv로 `hermes serve --isolated --host 127.0.0.1 --port <임시>`를 실행했다. 실제 도구 목록 HTTP 200·28행, 메시징 게이트웨이 실행 시도 없음. 모든 자식 실행을 차단·기록하는 감사 훅에서 Git 버전 조회 시도만 관측했다. 허용한 자식 서비스가 뒤에서 실행됐다는 뜻이 아니다. 실제 외부 계정·MCP·재시작은 하지 않았다. 탐침 자식만 종료했다. 기존 venv의 fastapi·uvicorn은 없으며, task31의 별도 deps를 탐침 PYTHONPATH에서만 재사용했다. 제품 설치에서는 D1의 업데이트 안내·skipped가 필요하다는 조건은 바꾸지 않았다.
3. **D32-01 — 단일 키 쓰기와 실패 불변:** 공식 `PUT /api/env`는 Hermes config_env.py:328~349 → credential_lifecycle.py:163~201로 간다. save_env_value 뒤 이전 값과 같은 config.yaml api_key 거울을 `_scrub_config_yaml_mirrors`(:82~138)로 갱신한다. 임시 alpha 프로필의 같은 가짜 이전 값으로 실행하면 응답 ok=true, config_updates=[model.api_key]이고 config.yaml이 실제 변경된다. 그 atomic_config_replace 한 지점만 메모리 대역으로 실패시키면 공식 라우터 함수가 status_code=500 예외를 내지만 .env 바이트는 달라지고 새 값이 남으며 config.yaml은 이전 바이트다. 본체 파일은 수정하지 않았다.
4. 충돌 계약: REQ-HF-32.AC-03은 지정 이름의 줄만 원자적으로 쓰고, AC-04·AT-83은 쓰기 실패 시 기존 값 바이트 불변을 요구한다. 근간 설계는 조립 결과 직접 수정도 금지한다. D1·보완 33은 공식 루프백 백엔드 경로·본체 무수정을 고정한다. 이 공식 동작을 성공으로 숨기거나, .env만 독자적으로 쓰거나, config 전체를 복원하거나, 본체를 고치는 선택은 채택하지 않았다. 실제 등록 제공자 키는 auth pool 등 추가 저장소에도 영향을 줄 수 있다(credential_lifecycle 설명과 호출 근거); 이번 재현은 합성 일반 키로 config 거울과 후속 실패만 확인했고 운영 auth 파일은 열지 않았고 auth pool 갱신 결과를 실물 검증했다고 주장하지 않는다.
5. 추가 검증 경계: config_env.py:965~1032의 `/api/providers/validate`는 검사 표에 없는 키에 ok=true/reachable=false를 반환한다. 합성 일반 키로 실제 인증 검사를 거쳐 이 반환을 확인했다(네트워크 호출 없음). D3의 ‘키 저장됨(확인 안 함)’ 표시와 별개로, AC-03의 ‘실제 읽기 확인을 통과한 값만 저장’에 대해 지원하지 않는 키의 허용/거절 정책이 필요하다. ok만 검사해 검증 완료로 표시하면 안 된다.
6. 계획 담당에게 넘길 선택: (A) 공식 관리 경로의 다중 저장소 효과를 계약에 명시하고, 해당 파일·키의 사전 확인/동시성/실패 복구/되돌림 경계를 설계한다. (B) 단일 키 쓰기·실패 불변을 유지한다면 이를 실제로 보장하는 공식 실행 경로와 지원 키 범위를 다시 정한다. 권고는 **먼저 공식 경로의 실제 쓰기 집합과 실패 원자성을 확정**하는 것이다. 검사 없는 키는 확인을 통과한 것으로 간주하지 않는 정책도 명시해야 한다. 어느 선택도 구현자가 채택하지 않았다.

| 실행 | 실제 결과·한계 |
| --- | --- |
| `python3 .build/task32/probe_backend.py` | 종료 0. 실제 serve 기동·임시 프로필 목록 HTTP, 메시징 게이트웨이 자식 실행 시도 없음. `.build/task32/serve-result.json`, `serve.log`, `spawn-attempts.jsonl`. 종료 시 소유 탐침 자식에만 SIGTERM을 보냈고 종료 코드는 143이다. |
| `python3 .build/task32/run_probe.py probe_write_contract` | 종료 0. 실제 공식 라우터·프로필 쓰기, config 거울 변경, 후속 쓰기 실패의 status_code=500 예외/.env 변경 잔류, 검사 없는 키 ok/reachable 경계 재현. `.build/task32/write-contract.json`, `probe_write_contract.log`. 최초 실행은 가짜 Request에 app이 없어 검사 단계에서 종료 1, 실제 Starlette Request로 고친 최종 실행은 0이다. |

제품 변경·설치 도우미·규격·AT-83 코드·전체 검사·앱 반복·돌연변이·캡처·배포·릴리스·TASK-32 커밋은 미실행이다. ddots 지정 원본 중 모델/동작 두 파일 전체 독해와 일부 공식 경로 대조만 했으며 나머지 유지 의존은 미완료다. 보고 파일 copy-review.md·impl-report.md 두 개만 실행 담당 소유 변경으로 남겨 재개 뒤 TASK-32 커밋에 보존한다. 기존 TASK-21 설치본·공용 릴리스·검증 근거는 그대로다. 최종 보고 변경본의 개인값·훅·diff 검사는 `.build/task32/report-checks.json`에 기록한다.

운영 홈·실제 비밀 파일 열기·게이트웨이 재시작·launchd 등록·Hermes venv 설치·본체/ddots/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. 푸시 승인이 아닌 D32-01 설계 계약 때문에 멈춘다.

## TASK-32 보완 34 구현 진행 기록

D32-01은 29판 D9로 해소했다. 위 보류 기록은 당시 근거로 보존한다. 현재 main의 기준은 `4fe20c13bca8a558bf1a0ad1681d8c3d81d0e8d0`이며 TASK-32 커밋·배포는 아직 하지 않았다. 구현 파일과 시험은 작업 트리에 있다. 고위험의 필요 증거 수준은 인계 2 / 최종 4이며, 아래 경계별 근거가 TASK-32 전체 최종 검증·실물을 대신하지 않는다.

- 문: `connections.py`(공식 루프백·D9·10분 금고), `connection_runtime.py`(행동 기록·재시작 판정·고정 명령), `connection_manager.py`(명부 범위·허용 동작·문서·OAuth/MCP/team-kit)를 추가했다. 기존 인증된 연결에만 응답하고 대화 기록장·방송에 넣지 않는다. 비밀값 입력은 공식 reveal/validate/PUT/DELETE, 실패는 공식 보상만 쓴다. partial은 값 없는 행동 기록과 승인된 문장으로 드러낸다. hejo의 env/config 직접 쓰기는 없다.
- 앱: 예외 범위 SwiftUI 연결 창·입력기를 기존 AppKit 설정/직원 메뉴와 연결했다. LocalAuthentication 취소면 프레임이 없다. 앱 연결 이어가기에서 재시작하는 경우도 같은 재시작 확인창을 거친다. 화면 공유 제외·성공/닫기 입력 삭제·원시 오류 비노출·관리 응답 캐시 제외를 연결했다. 선택 직원의 문서만 요청하고 직원 목록은 기존 명부를 읽는다.
- 설치: `admin_support.py`·`hejo-admin`과 기존 설치 영수증에 private 토큰/KeepAlive plist의 준비·점검·제거를 추가했다. 영수증에는 토큰 대신 파일 해시만 둔다. 소유자가 바꾼 파일은 보존한다. 의존성이 없으면 업데이트 안내와 skipped다. 래퍼는 토큰을 환경에만 놓고 공식 serve를 loopback으로 실행하며 stdout/stderr를 버린다. 실제 launchd 등록과 운영 적용은 TASK-23이다.
- 기존 시험 변경: `Task17Tests.swift`의 정확한 메뉴 목록에 승인된 ‘도구 연결…’ 한 항목만 추가했다(REQ-HF-32.AC-01). 나머지 기대값과 단정은 유지했다. 수락 기준 문서는 바꾸지 않았다.

현재 확인한 근거:

| 실행 | 결과·범위 |
| --- | --- |
| `python3 .build/foundation9_runner.py task32-api-final <gate 시험>` | 종료 0, 16 passed. D9 보상/partial/만료, 인증된 루프백 응답 격리, 토큰/오류 미노출, chunked JSON, 고정 명령 stdin/한도/제한 시간/outcome, 재시작 바쁨·유실 채널·명령 거절, OAuth/MCP, 용어 변환. `.build/foundation9-task32-api-final.log`. |
| `python3 .build/task32/run_probe.py official_management` | 종료 0. 실제 공식 serve + 임시 기본/alpha/beta의 목록, 실제 공식 키 저장/되돌리기·프로필 분리. 1,368행·553,466바이트. 메시징 게이트웨이 실행 시도 없음. `.build/task32/official-management-result.json`. 실제 OAuth 토큰 교환·MCP 외부 전송·게이트웨이 재시작은 하지 않았다. |
| `python3 .build/task32/run_probe.py official_compensation` | 종료 0. 실제 공식 함수의 env 저장 뒤 config 거울 실패를 메모리 대역으로 주입하고 D9 보상을 실행했다. env/config 바이트가 모두 원래와 같다. `.build/task32/official-compensation.json`. 본체 파일은 바꾸지 않았다. |
| `python3 .build/task32/mutations.py` | 종료 0. 보상 제거·바쁨 거절 제거 사본이 각각 pytest 1로 검출됐다. 실제 소스는 바꾸지 않았다. `.build/task32/mutations.json`. |
| `python3 .build/task32/wrapper_probe.py` | 종료 0. exec를 메모리 대역으로 바꿔 공식 serve 인수·환경 토큰·0600 거절을 확인했다. 실제 launchd 등록 없음. `.build/task32/wrapper.json`. |
| `reference.py`·`white_capture.py` | 각각 종료 0. 같은 가짜 상태의 원본 보기 조각/실제 hejo 보기 조립. 운영 앱 전체 비교가 아니다. `evidence/HEJO-FOUNDATION/TASK-32.md`. |
| `python3 .build/task32/byte_search.py` | 종료 0. 실제 시험의 hejo 행동 기록/일반 지속 파일에 가짜 비밀값 바이트 0. 승인된 admin 토큰·이전 값 금고와 외부 Hermes 로그는 구분했다. 통신·방송·로그·인수는 자동 시험에서 따로 검사한다. `.build/task32/byte-search.json`. |

중간 전체/앱 검사는 구현 보강 중 입력 변경을 감지한 것이 있어 최종 실적으로 세지 않는다. 최종 소스를 고정한 `frozen.py`의 전체 검사·앱 시험 10회, 최종 개인값/훅, 앱 두 사본·공용 릴리스, 별도 커밋 결과는 이 아래에 이어 기록한다. 현재 이 작업 전체가 검증 완료됐다는 뜻은 아니다.

남은 실물: 실제 키 넣기/되돌리기, OAuth 동의, 실제 게이트웨이 새 PID/채널 재연결, 다른 Mac의 서버 권한 창, launchd 활성화와 창 결합은 TASK-23이다. Hermes 자체 로그에 원시 오류가 남을 수 있는 D2의 받아들인 위험은 유지한다. 운영 홈 실행/설치·재시작·launchd 등록·비밀 파일 열기·본체/ddots/운영 저장소 수정·Hermes venv 설치·외부 발송·public 갱신·push는 하지 않았다.

### TASK-32 최종 검증 진행 경계

고정 입력 148개 파일 기준 `python3 .build/foundation9_runner.py hejo`는 종료 0, 180 passed와 가짜 Hermes/앱/통신 검사를 통과했다. AT-HF-83 APP PASS도 확인했다. `.build/task32/frozen-progress.json` 첫 행의 `inputsUnchanged=true`, `.build/task32/frozen-inputs.json`의 소스 해시가 근거다. 같은 드라이버가 `app-task32-verified-01`부터 10회 연속을 이어 실행 중이다. 10회 완료를 아직 선언하지 않는다.

`python3 .build/task32/final_checks.py`는 종료 0이다(개인값 검사, HEJO_PYTHON 지정 커밋 훅, diff 검사 각각 0). 제품 SwiftUI import는 승인된 연결 창/입력기 두 파일뿐이며 알림 센터 API는 0이다. 이 경계에서 TASK-32 커밋·앱 교체·공용 릴리스 갱신은 아직 하지 않았다. 반복 검사 완료 뒤 그 결과와 교체/커밋/릴리스 근거를 이어 적는다.


### TASK-32 구현·자체 검증 인계 결과

위 진행 경계 이후 기존 `frozen.py` 실행을 그대로 기다렸다. 완료한 검사를 다시 시작하지 않았다. 전체 검사 1행과 앱 시험 10행이 모두 종료 코드 0·`inputsUnchanged=true`이며, 고정 입력 148개가 끝까지 같다. 인계 필요/도달 증거 수준은 **2/2**다. 고위험 최종 완료에는 비설계자 검토와 TASK-23 실물 수준 4가 남으며, 구현자가 최종 완료를 판정하지 않는다.

| 최종 실행 | 실제 결과·근거 |
| --- | --- |
| `python3 .build/task32/frozen.py` | 종료 0. 내부 `python3 .build/foundation9_runner.py hejo`는 종료 0, 180 passed·AT-HF-83 APP PASS·가짜 Hermes/통신 통과. `.build/task32/frozen-progress.json`, `frozen-inputs.json`, `.build/foundation9-hejo.log`. |
| `bash app/scripts/test.sh` 10회 연속 | 기존 드라이버의 `app-task32-verified-01`~`10`에서 모두 종료 0·입력 불변. `.build/foundation9-app-task32-verified-01.log`~`10.log`와 `frozen-progress.json`. |
| `python3 .build/task32/deploy.py` | 종료 0. 앱 두 사본 교체·서명 2개 확인·기존 번들 설정/주소 체계 보존·운영 앱 재실행 없음. `.build/task32/deploy.json`; 백업 `deploy-backup`. |
| `python3 .build/task32/verify_binary.py` | 종료 0. 임시 사본의 서명을 제거한 빌드/후보/배치 코드 해시가 모두 같다. 후보와 두 배치 실행 파일 해시도 같고 기존 Info.plist 바이트를 보존했다. `.build/task32/binary-verification.json`. |

보상 제거·바쁨 거절 제거 돌연변이, 가짜 비밀값 바이트 검색, 공식 백엔드/실제 공식 보상 경계, 원본 분리 캡처는 위 표의 같은 구현 근거를 재사용한다. 기획설계 문서·수락 기준은 수정하지 않았다. D32-01 보류·29판 해소와 원본 독해 기록을 보존한 보고 파일을 포함해 소유 파일 24개만 `git commit --only` 대상으로 삼는다.

이 보고 추가 뒤 `final_checks.py`와 커밋 도우미로 개인값/훅/diff를 확인한다. 커밋 실행 결과는 `.build/task32/commit-result.json`·`commit.log`에 남긴다. 이어 `release.py`로 공용 릴리스를 갱신하고 `final_verify.py`로 RELEASE 표식·전체 릴리스 파일·앱 서명/설정·검증 소스·깨끗한 작업 트리를 대조한다. 실제 커밋과 릴리스 최종 결과는 `release-verify.json`·`final-verification.json` 및 result 인계에서 확인한다. 이 문서 작성 시점에는 커밋/릴리스 이후 결과를 미리 통과로 세지 않았다.

구현 범위는 문 공식 관리 경계·설치 준비/점검/제거·승인된 연결 UI 예외와 시험/증거다. 실제 서버 키·OAuth 동의·게이트웨이 재시작·두 Mac·권한 창·launchd 활성화·운영 창 결합은 TASK-23에 남는다. 운영 홈 설치/실행·재시작·launchd 등록·실제 비밀 파일 열기·Hermes venv 설치·본체/ddots/운영 저장소 수정·외부 발송·public 갱신·push는 하지 않았다. 운영 자료 롤백은 기존 design 15판대로 shared/hejo 사본과 이전 릴리스를 함께 복원해야 하며 이번 앱/릴리스 백업이 운영 자료 사본을 대신하지 않는다. 계획 담당 검토로 인계하고 푸시 승인 대기로 진행을 멈추지 않는다.


## N32-01 시험 보강 인계

기준 `37fb43f06507176d6b4244a5a252c5ef339c5c51`. 보상 PUT/DELETE가 성공 응답을 보내지만 이전과 다른 키 존재 상태를 남기는 두 입력을 gate/tests/test_connections.py에 추가했다. `write_partial`·승인된 문장·행동 기록 partial·값 미노출을 확인한다. 제품 변경 없이 시험 한 파일만 `git commit --only`로 `e77a5f7bf150e59a237e10a6c86ea7e5ccb2bf8b`에 기록했다.

- `foundation9_runner.py task34-n32 <test_connections.py>` 종료 0, 18 passed(`.build/foundation9-task34-n32.log`).
- `mutation_n32.py` 종료 0. compensate의 is_set 비교를 제거한 사본은 pytest 종료 1로 새 두 입력에 검출됐다(`.build/task34/n32-mutation.json`, `mutation-presence.log`). 실제 소스 불변이다.
- 개인값·HEJO_PYTHON 지정 훅·diff 각각 종료 0(`.build/task34/n32-checks.json`), 커밋 결과 `n32-commit.json`.

## TASK-34 보완 37 구현·자체 검증

REQ-HF-34.AC-01~09·AT-85와 보완 37 추가 1~3을 따른다. 버전 올리기는 AC-04대로 TASK-33에 남긴다. 필요/도달 증거 수준은 최종 검사 결과를 아래에 이어 적는다. 원본 전체 독해 재사용·추가 의존은 copy-review.md에 있다.

- 문: 기존 edit 대기열을 그 직원/스레드 범위로 끝내고, 마지막 본문을 edit final:true로 추가한다. 반복 stop은 같은 글을 다시 닫지 않고 늦은 편집은 평소처럼 받는다. 보조 전달의 thread_id를 보존했다. delete_message는 자기 직원·대화·직원 글만 보통 delete로 지우며, 사장/남의/없는 글은 기록하지 않는다. 실제 Hermes 성공 차례 post-delivery 정리 함수와 가짜 차례를 연결했고 실패 차례 보존도 검사한다.
- 앱: 얼굴을 스위치와 같은 세로 가운데의 오른쪽 가로 스크롤로 옮겼다. 작업 중 줄은 9pt 간격, 중지는 초 오른쪽 6pt·18px 영역/9pt 그림이다. 완료된 생각 줄도 작성 중으로 세지 않으며 늦은 final:false는 다시 작성 중이다. DM은 사장 이름을 보존하고 기본 DM·이름만 표시한다. + 고정 뷰를 없애고 표 마지막 40px 행으로 옮겼다. 방 이름 변환/Slack 안내를 없애고 제목/설명 폼 생성은 RoomDialogs로 옮겨 실제 입력기를 시험한다. 구획/DM의 행·레일은 0.24 easeInEaseOut, 선택은 0.34/0.88 spring이며 움직임 줄이기는 즉시다. 같은 내용 재갱신이 진행 중 움직임을 끊지 않는다.
- 설치: 기존 owner_may_change 영수증·pending/applied/removing/removed 맞춤/키 단위 되돌림을 정리 설정에도 재사용한다. 값 없을 때만 display.platforms.hejo.cleanup_progress=true를 넣고, 사장 값·전역/Slack 설정을 보존한다. --check는 두 키를 따로 확인하며 --uninstall-home-channel은 홈 키만 다룬다. 운영 설치 도우미는 실행하지 않았다.

기존 시험 조정은 승인된 계약 변경 범위다. PicturesSidebarTests의 기본 DM 이름 기대 한 줄을 AC-05로 바꿨다. HomeRoomTests의 얼굴 조회 두 곳은 가로 스크롤 안의 실제 같은 뷰를 재귀 조회하도록 바꿨고 단정은 유지했다. test_install.py의 home_targets는 새 정리 설정을 홈 채널로 잘못 세지 않도록 정확한 홈 키만 고른다(기존 수치/단정/입력 완화 없음). 수락 기준 Markdown·spec·design은 수정하지 않았다.

집중 근거: 문·설치 57 passed(`.build/foundation9-task34-progress-final.log`, 설치만 52 passed `foundation9-task34-install.log`). AppKit 집중 시험은 컴파일/실행 0이며 얼굴 1/6/넘침·중지 간격·완료/늦은 편집·한글 marked text 5개 native field와 작성기·DM·3/20 방·중간 alpha/행 y/레일 높이·움직이는 중 선택·즉시 접기를 검사한다(`.build/task34/focused.json`). 소유자 검사와 final 닫기 제거 돌연변이는 각각 pytest 1로 검출했다(`mutations.json`). 최초 홈 명부 aliases 누락과 개발 중 파일 변경 빌드 실패는 최종 근거에서 제외했다. ＋를 임의 문서 자식으로 두던 초안은 실제 표 행으로 대체했다. 실패를 skip/xfail로 넘기거나 수락 기준을 완화하지 않았다.

같은 가짜 직원 6명과 초/DM/버튼 상태의 원본 표시 조각을 분리 실행했다(`reference.json`). 원본/운영 앱 전체 비교나 실제 한국어 입력기·두 Mac 실물 확인은 아니다. 시스템 조합 입력·실제 성공/실패 차례는 TASK-23 실물에서 확인한다. 전체·10회 반복은 고정 입력 드라이버가 진행 중이며 완료 후 결과를 이어 적는다. 운영 홈·앱 사본·공용 릴리스·게이트웨이·launchd·ddots/본체/운영 저장소·원격은 변경하지 않았다. TASK-35·33은 미착수다.


### TASK-34 진행 중 계획 변경(33판 보완 38)

현재 기준은 계획 커밋 `a0b3782e9fbe77608478aed5a3f3a4a167444927`다. 실행 담당의 N32-01 커밋 위에 추가된 계획 문서 여섯 파일을 보존한다. 보완 38은 TASK-34 AC-08을 TASK-38로 옮기므로, 위 움직임 구현·중간 프레임 시험은 이번 커밋에서 제외했다. 원복 전 세 파일과 전체 변경은 `.build/task34/pre-scope38/`에, 움직임만 다시 적용하는 패치는 `.build/task38-start.patch`에 있다(적용 점검 0). 보관은 출발 자료이며 33판 움직임 완성 판정이 아니다.

이 변경 전 최종 드라이버는 전체 189 passed 및 앱 7회 종료 0이었다. 마지막 회차의 inputsUnchanged는 계획 담당이 AT 문서를 갱신해 false가 됐고 드라이버가 종료 1로 멈췄다. 실행 담당 제품 소스가 임의로 바뀐 것이 아니다. 원래 기록과 로그는 pre-scope38에 보존하고 새 범위의 최종 결과로 세지 않는다. 계약과 실제 움직임 코드를 바꿨으므로 새 고정 입력으로 전체·10회를 다시 수행한다. 나머지 문/설치·돌연변이 근거는 관련 코드가 같아 재사용한다.


현재 재개 경계: AC-08 분리 후 집중 AppKit 컴파일/실행은 0이다. 분리 뒤 diff 검사에서 끝줄 빈 줄 한 건을 발견해 정리했다. 그 짧은 초기 검증 자식만 종료했고(`format-restart.json`, 세션 종료 143), 소유 검증 외 프로세스는 건드리지 않았다. 이후 최종 개인값·훅·diff는 모두 0(`final-checks.json`)이다. 새 고정 입력은 150개, 실행은 `.build/task34/frozen.py`이며 전체/10회가 진행 중이다. 최종 소스의 전체·반복 완료를 아직 선언하지 않는다. 진행·다음 절차는 `.build/task34/checkpoint.json`과 `frozen-progress.json`에 있다. TASK-34 커밋·앱 사본/공용 릴리스/공개본 갱신은 아직 하지 않았다.


33판 범위의 새 고정 입력 150개로 전체 검사 종료 0(189 passed·AT-HF-85 APP PASS·기존 가짜 Hermes/앱/통신 통과)을 확인했다. `.build/task34/frozen-progress.json` 첫 행은 inputsUnchanged=true이며 전용 전체 로그는 `frozen-foundation.log`다. 같은 드라이버가 앱 10회를 이어 실행 중이다. 아직 최종 반복·TASK-34 커밋·최종 캡처 결과는 미완료이며, 기존 세션을 이어 기다려야 한다. 현재 움직임 코드가 이번 제품 변경에 남지 않았고, 패치 적용 점검은 0이다.

### TASK-34 최종 구현 인계 결과

기존 세션 20606의 `frozen.py`가 종료 0으로 끝났다. 완료 행을 재실행하지 않았다. 전체 1행과 앱 10행 모두 `exitCode=0`, `inputsUnchanged=true`이며 입력 150개가 끝까지 같다. 이번 인계 범위는 REQ-HF-34.AC-01~07·09이며, 필요/도달 증거 수준은 **2/2**다. AC-08은 승인된 33판 보완 38에 따라 TASK-38로 옮겼다. 위 초안 움직임 구현·시험 설명은 진행 이력이고 이번 제품 변경에는 포함하지 않는다.

| 최종 실행 | 실제 결과·근거 |
| --- | --- |
| `python3 .build/task34/frozen.py` | 종료 0. 전체 검사 189 passed·AT-HF-85 APP PASS·기존 가짜 Hermes/앱/통신 통과. `.build/task34/frozen-foundation.log`, `frozen-progress.json`, `frozen-inputs.json`. |
| `bash app/scripts/test.sh` 10회 연속 | 같은 드라이버의 `app-task34-verified-01`~`10` 모두 종료 0·입력 불변. `.build/foundation9-app-task34-verified-01.log`~`10.log`. |
| 최종 빌드 `app/.build/app-tests --task34-capture` | 임시 HERMES_HOME에서 종료 0·AT-HF-85 APP PASS. `capture-final.py`가 두 PNG를 evidence에 복사했고 소스 불변을 확인했다. `.build/task34/capture-final.json`, `capture-final.log`. |

문/설치 집중 검사(57 passed, 설치만 52 passed)와 소유자 검사·진행 글 닫기 돌연변이 검출은 같은 문/설치 코드의 위 근거를 재사용한다. N32-01은 앞의 시험 전용 커밋 그대로다. 최종 hejo 캡처는 실제 AppKit 조립 보기이며, 원본 표시 조각과 함께 직접 확인했다. 상단 연결 끊김/재시도 숫자는 합성 시계 상태에서 나온 표시로 비교 대상이 아니다. 실제 운영 연결·원본 앱 전체·물리 한글 입력기 확인을 증명하지 않는다.

이 보고 추가 뒤 `final_checks.py`로 개인값·HEJO_PYTHON 지정 훅·diff를 검사하고, 소유 파일 20개만 `git commit --only`로 기록한다. 이후 `final_verify.py`가 실제 커밋 파일·검증 입력·캡처 바이트·깨끗한 main을 대조한다. 실행 이후의 실제 전체 커밋과 결과는 `.build/task34/commit-result.json`, `final-verification.json`과 result 상태 블록에 기록한다. 이 문서에서 아직 실행하지 않은 검사를 통과로 세지 않는다.

실물 성공/실패 차례와 시스템 한글 조합은 TASK-23에 남는다. TASK-35·33 제품 구현은 미착수이며 계획 담당 검토 뒤 순서대로 진행한다. 운영 홈 설치/변경·실행·재시작·launchd 등록, 앱 사본 교체, 공용 릴리스/public 갱신, ddots/본체/운영 저장소 수정과 원격 쓰기는 하지 않았다. `.build/task38-start.patch`는 새 움직임 계약의 완성본이 아니라 후속 출발 자료다.

## N34-01 시험 보강 결과

시험 전용 커밋 `e94ee2f6d03fd2e1914d2604a6d9b7cac5b8f5f7`는 gate/tests/test_progress.py 한 파일만 바꿨고 계획 담당이 `10ce6701e09c0f2dc5b62ed4649332a969646007`에서 검토를 마쳤다. 두 스레드 모두 진행 편집 중일 때 A 중지 두 번이 A의 final:true 한 번만 남기며 B 편집 0·작성 중 유지를 기본/전달자 경로로 확인했다. 집중 검사 7 passed와 필터 제거/metadata 되돌림 돌연변이 검출 근거는 `.build/n34-01/`에 있다. 이 검사를 TASK-35에서 반복하지 않는다.

## TASK-35 구현·자체 검증

받은 설계는 보완 37·38·40·41의 TASK-35, REQ-HF-35.AC-01·AT-HF-86이며 기준은 `10ce6701e09c0f2dc5b62ed4649332a969646007`다. 일반 위험·필요 인계 증거 수준 2다. 구현은 작업 트리에 있고 최종 전체·반복·커밋 결과는 아래에 이어 기록한다. 하위 에이전트를 쓰지 않았다.

- 원래 책임: ThreeTapGesture·Frames·DeviceIdentity가 접촉을 판정하고, ThreeTapReader가 private ABI/기기 수명·콜백을 소유한다. dlopen/dlsym만 쓰며 프레임워크를 링크하지 않는다. ThreeTapController가 설정·OS 점검·알림·복사를 맡고 AppDelegate가 시작/종료·설정 창에 연결한다. 유효 탭은 PetController의 기존 펫 클릭 경로로 보내며 숨김/쉬는 중이면 무시한다.
- 저장: UserDefaults 저장 경로를 가져오지 않고 기존 LocalSettings의 Mac별 hejo-local.json에 켬·마지막 OS·실패 키·OS 변경 대기·찾아보기 안내 표시만 둔다. 새 파일·허브 상태·기록장 원본은 없다. 저장 실패는 안내하고 켬/끔 값을 바꾸지 않는다.
- 유지/제외: 원본 0.3초·0.04·정확히 3개·0.4초, 30연속 검사, 10초 기기 목록 확인, 잠자기 깨기, 실패 창 대기열과 복사를 유지했다. ThreeTapCommand·Sender·Slack/원격 보고와 원격 보고 전용 필드는 제외했다. 새 기능의 꺼짐은 기존 클릭을 바꾸지 않는다. 버전 변경은 TASK-33이다.
- 원본과 차이: 트랙패드 없음은 명세의 '흐리게' 대신 원본 App.refreshThreeTapSettings대로 체크 조작을 허용하고 도움말을 보인다(26판 코드 우선). 실패 상태만 비활성이다. 설정 창의 기존 배치는 유지하면서 새 체크 한 줄을 추가하고 초기화 버튼 두 개를 아래로 옮겼다. 원본 전체 독해·의존 기록은 copy-review.md에 있다.
- 시험 경계: ThreeTapReading·시각/라이브러리 기호/시스템 설정 조회 주입은 하드웨어·시스템 설정을 대역으로 격리하는 경계다. 제품의 탭/프레임 판정과 실제 설정 창·실패 창·펫 클릭을 그대로 실행한다. 새 시험을 TestMain에 연결했다. 기존 수락 기준·기존 시험 기대값은 바꾸지 않았다.

초기 앱 빌드는 시험 파일 수정과 겹쳐 입력 변경을 감지해 종료 1이었다(`foundation9-app-task35-first.log`); 통과 근거로 세지 않는다. 수정이 끝난 집중 컴파일/실행은 각각 0·AT-HF-86 APP PASS다(`focused.json`). 처음 캡처의 투명 배경 때문에 읽기 어려운 글자는 보기의 흰 배경으로 보강했고, 이후 최종 캡처를 사용한다. 원본 분리 컴파일/실행은 각각 0(`reference.json`), 운영 앱 전체 비교가 아니다.

탭 허용 시간을 0.5초로 늘린 사본과 실패 한도를 31로 바꾼 사본은 실제 ThreeTapTests의 순수 판정 단정을 추출한 집중 실행에서 각각 종료 1로 검출했다. 같은 단정의 무변경 사본은 0이고 제품 원본은 불변이다(`.build/task35/mutations.json`). 이 결과는 전체 앱·하드웨어 검증을 대신하지 않는다.

남은 실물은 실제 트랙패드 탭과 잠자기 깨기/기기 교체에서 private ABI가 맞는지 확인하는 것이다. 인계 도달 수준 2를 실물 수준 4로 주장하지 않는다. 운영 홈·앱 사본·공용 릴리스/public·원격·Hermes 본체/ddots는 수정하지 않았다. 후속 TASK-33·48·49·36~47은 착수하지 않는다. 임시 대조/검증 도우미는 `.build/task35/`의 비추적 자료이며 제품 진입 경로가 아니다.

### TASK-35 최종 결과

고정 입력 154개로 `frozen.py`가 종료 0으로 끝났다. 전체 1행과 앱 10행 모두 `exitCode=0`·`inputsUnchanged=true`다. 필요/도달 인계 증거 수준은 **2/2**, 구현자 판단은 구현·자체 검증 완료이며 최종 판정은 계획 담당에게 넘긴다.

| 실행 | 실제 결과·근거 |
| --- | --- |
| `python3 .build/task35/frozen.py` | 종료 0. 내부 foundation9_runner hejo는 191 passed·AT-HF-86 APP PASS·기존 가짜 Hermes/앱/통신 통과. test_install도 이 전체 실행에 포함했다. `.build/task35/frozen-foundation.log`, `frozen-progress.json`, `frozen-inputs.json`. |
| `bash app/scripts/test.sh` 10회 연속 | 같은 드라이버에서 모두 종료 0·고정 입력 불변. `.build/foundation9-app-task35-verified-01.log`~`10.log`. 완료 행을 다시 실행하지 않았다. |
| `python3 .build/task35/capture_final.py` | 종료 0. 최종 빌드 app-tests의 AT-86 캡처와 별도 native 설정 내용 캡처를 임시 HERMES_HOME에서 실행하고 원본 조각을 포함한 PNG 4개를 evidence에 복사했다. `capture-final.json`, `capture-final.log`, `settings-final.log`. |

최종 캡처를 직접 대조했다. 실패 창의 문장·복사/닫기 순서·요청문 구조가 같고 서비스 이름만 바뀐다. 설정은 원본 체크 조각과 실제 hejo 펫 설정 내용이다. NSTabView 전체를 바로 캐시하면 일부 배경이 투명하게 나오는 한계가 있어, 실제 선택된 내용 뷰를 흰 바탕으로 옮겨 그렸고 탭 머리는 제외했다. 그림 후처리나 다른 UI 재구현이 아니다. 전체 원본 앱·운영 앱 비교나 실제 트랙패드 실행을 주장하지 않는다.

집중 돌연변이와 원본 분리 실행은 위의 같은 소스 근거를 재사용한다. 이번 변경에서 새 컴파일 경고는 없으며 기존 AirportFinder Sendable·Task17Tests NSMenu·TypingTests 미변경 변수 경고는 범위 밖으로 남겼다. 실패를 skip/xfail로 넘기거나 기대값을 바꾸지 않았다. 구현자가 특히 검토를 요청하는 곳은 private ABI 수명/세대 차단, Mac별 설정 연결과 원본 우선으로 처리한 트랙패드 없음 표시다.

이 최종 보고 추가 뒤 `final_checks.py`로 개인값·HEJO_PYTHON 지정 훅·diff, MultitouchSupport 직접 링크 없음·외부 보고 코드 없음·읽기 전용 원본 해시를 확인한다. 이어 소유 파일 16개만 `git commit --only`로 기록하고 `final_verify.py`가 실제 커밋 파일·고정 입력·PNG·깨끗한 main을 대조한다. 실행 이후의 실제 전체 커밋·최종 결과는 `.build/task35/commit-result.json`, `final-verification.json`과 result 상태 블록에 남긴다. 아직 실행하지 않은 검사를 여기서 통과로 세지 않는다. 앱 사본·공용 릴리스·public 갱신·원격 쓰기는 하지 않는다.

## TASK-33: 자동 업데이트 부분 구현·D33-01 보류

1. **받은 설계·기준:** handoff 보완 36(30·31판)·38·40·41·42, REQ-HF-33, design 11절, AT-84. 기준 `bdffda276c7cb1eff7bb82c01a76a6fb9cb3a612`. 고위험, 필요 인계 증거 수준 2. 운영 적용·원격 공개는 범위 밖이다.
2. **판단 상태:** 부분 구현 뒤 보류. D33-01은 아래의 hejo 통신 계약 충돌이며 최종 완료·배포 준비를 주장하지 않는다. 제품 파일은 기준으로 복구했고 보고 파일만 변경했다. 새 커밋 없음.
3. **보존 초안:** `.build/task33/draft/`에 제품·시험 19개 파일 사본, `draft-files.json`에 기준·파일별 지문, `draft.patch`에 추적 파일 차이가 있다. 사본 바이트 대조 후 복구했다. 실제 개수와 목록은 `draft-preserved.json`·`draft-files.json`을 우선한다. 재개 때 이 자료를 사용하며 완료한 원본 독해는 `copy-review.md`와 `source-notes.json`을 재사용할 수 있다.
4. **구현한 범위(현재 제품에 적용 안 됨):** AppUpdate의 30초/6시간·명시 동의·수동 버튼·하루 숨기기, UpdateRelease 공개 메타데이터·주소/버전/크기 허용, SparkleInstaller/UserDriver의 SDK 경계, 설치 버전·빌드 일치 후 펫 알림, 메뉴/일반 탭, 버전 0.2.0/빌드 2, 고정 SDK·안쪽부터 코드 서명·BuildInfo, hejo-ship setup/prepare/사장 전용 publish와 get-hejo 자산 이름 변경을 초안으로 작성했다. SDK만 다운로드·교체·재실행을 맡으며 별도 앱 교체기를 만들지 않았다. Task17 메뉴 기대값은 업데이트 항목 추가에 따라 9→10개로 바꾼 초안을 포함한다.
5. **독해·설계 차이:** copy-review의 원본 전체 독해 표 참조. 설치 위치는 ddots 및 기존 LoginLaunch의 시스템·사용자 Applications 판정을 유지했다(26판). 공개 저장소 설정은 Info.plist에서만 읽는다. 조용한 설치·토큰·relay·update-feed 원격 쓰기는 제외했다. 원본 설치 완료 알림 우선순위와 10초를 이식했다. 새 영구 원본은 만들지 않았다.
6. **D33-01 확인 사실:** TASK-21 이전 문 `a4a80d5431ca378f7818d2bb8dc75475e658b2cb`은 hello에서 features를 금지한다(옛 schema 181~241, server 261~276·308~320). 현재 GateClient 118줄은 features:[rooms]를 무조건 넣는다. 실제 옛 문+현재 앱의 인증 전 연결이 실패했고, 별도 같은 입력 대조에서 features 있음→invalid_frame·없음→welcome을 확인했다. 통신 규격 v1의 하위 호환이라는 AC-03과 현재 단체방 capability 계약이 충돌한다. TASK-33의 업데이트 UI나 Sparkle 오류는 아니다.
7. **선택지·권고(미채택):** 계획 담당이 (A) 구문 거절된 첫 hello에 한해 features 없는 호환 연결을 한 번만 허용하고 그 연결에서는 단체방 기능을 제한하는 계약 또는 (B) 지원하는 문 최소 버전을 명시하고 서버 선갱신을 배포 조건으로 삼는 계약을 정해야 한다. 권고는 AC-03의 목적을 보존하는 A이며, 인증 전/후 구분·재시도 횟수·pair code 보존·기존 캐시의 방 표시·재연결을 명세와 AT로 확정한 뒤 구현한다. 구현자는 임의 fallback·검사 완화·옛 문 수정·수락 기준 변경을 하지 않았다.
8. **실행한 검사:** 고정 Sparkle 압축 지문 및 SDK 서명 검사 0. `python3 install/hejo-ship setup` 0: 승인된 일반 계정 키체인에 키를 만들고 공개 키만 초안 Info.plist에 보존했다. 키를 내보내거나 출력하지 않았다. `foundation9_runner.py task33-ship <수락 시험 절대 경로>` 0/7 passed(`.build/foundation9-task33-ship.log`). 초기 앱 전체 시험 `foundation9_runner.py app-task33-first` 0(`.build/foundation9-app-task33-first.log`); 이후 집중 시험에 호환 연결·펫 알림 단언을 추가했으므로 최종 전체 통과로 쓰지 않는다. 최종 초안 집중 컴파일/AT-84 앱 실행 0(`focused.json`). 주소 허용 비교 제거 사본은 컴파일 0·시험 1, `AT84 address version size boundary`로 검출·원본 불변(`mutations.json`). 실제 옛 문+새 앱은 1(`legacy.json`, 최초 실행은 시험 환경 변수를 fixture가 지운 준비 오류였고 수정 뒤 연결 실패 재현). raw hello 대조는 0/1 passed(`hello-probe.json`, `hello-boundary.json`). 원본 알림 함수 분리 컴파일/실행은 0이지만 PNG의 텍스트/배경 렌더링이 유효하지 않아 화면 비교 통과로 사용하지 않는다.
9. **미실행·증거 수준:** 최종 foundation9_runner hejo·test_install·앱 10회·유효한 캡처 비교·실제 prepare·공개본 갱신·커밋은 미실행. 계약 충돌 보류 때문에 인계 필요 2에 아직 도달하지 못했고 전체 도달 수준은 1이다. 실제 두 Mac 업데이트·디스크 실패·재실행 경계는 TASK-23 수준 4에 남는다. 경고는 기존 AirportFinder의 Swift 6 Sendable과 새 시험에서 쓰는 SDK dictionary 초기화의 deprecated API다. 후자는 시스템/앱 버전에 의존하는 SDK 속성을 시험하지 않고 공개 enclosure 해석에만 썼으며, 제품 경로에는 추가하지 않았다.
10. **운영·인계:** 앱 사본·공용 릴리스·public 가지·운영 홈·본체·ddots·원격은 변경하지 않았다. 로컬 키체인 서명 키는 승인 범위에서 생성된 상태로 유지하며 재개 때 기존 키를 재사용해야 한다. 비밀 키 출력·내보내기·publish·외부 발송 없음. TASK-48 이후 미착수. 계획 담당이 D33-01을 결정한 뒤 초안을 재적용하고 남은 검사를 수행한다.

복구 뒤 보고 파일 최종 검사 근거는 `.build/task33/report-checks.json`이다(개인값·HEJO_PYTHON 지정 훅·diff 검사 각각 종료 0). 제품 초안 전체의 최종 검증을 뜻하지 않는다.

## TASK-33 재개: 보완 43·35판 D33-01 해소

기준은 `3d7e1c07b30e924fd16b4e75aed501b4619a3d07`이다. 위 보류 기록은 당시 사실로 보존한다. 계획 담당이 지원 문 범위를 TASK-21 이후로 정했고, 운영 적용본 aeaa652를 옛 문으로 지정했다. 초안 19개를 지문 대조하고 제품 충돌 없이 다시 적용했다. GateClient·문·규격 변경이나 features 없는 되돌림 연결은 추가하지 않았다. 원본 전체 독해와 주소 검사 돌연변이 근거는 동일 제품 입력임을 확인해 재사용한다.

옛 문 시험은 `.build/task33/supported-release/gate/tests/test_update_compat.py`에서 실제 옛 gate 소스·출입증·기록장·WebSocket과 현재 앱의 GateClient/ConversationController를 실행한다. Hermes 턴만 대역이다. 새 앱은 짝맺기·송신·수신 후 가짜 단체방 목록도 받았으며 종료 0이다(`supported-legacy.json`). 첫 시도 마지막 단언은 빈 team registry를 쓰는 별도 Hermes 권한 대역 때문에 실패했다. 해당 권한 대역을 송수신 호환 시험 범위에서 분리하고, 받은 실제 이벤트를 기록하는 가짜 턴으로 고쳤다. 문 자체의 인증·검증·기록·전송은 대체하지 않았다.

유효한 캡처는 evidence/HEJO-FOUNDATION/TASK-33.md에 있다. 원본과 hejo의 실제 automaticAlert 함수를 그대로 분리 실행하고 하네스에서 흰 불투명 배경을 주었다. 초기의 빈 PNG는 제외했다. 실제 설정 보기 캡처도 포함하며 운영 앱 전체 비교를 주장하지 않는다. 배포 준비·서명에 필요한 기존 키체인 키를 재사용한다. 새 키 생성·비밀 키 출력·내보내기·원격 공개는 하지 않는다.

최종 전체 검사와 앱 10회는 `.build/task33/frozen.py`가 제품·시험·빌드/설치 도구·규격·Resources 입력을 고정해 실행 중이다. 완료한 행을 재실행하지 않는다. 운영 홈·앱 사본·공용 릴리스는 바꾸지 않는다. 최종 결과는 아래 후속 기록과 `.build/task33/final-verification.json`을 함께 대조해야 한다.

### TASK-33 코드·자체 시험 최종 기록(커밋 경계)

- **구현:** AppUpdate가 발견·시각·매번 동의·수동 버튼·중복 방지를, UpdateRelease가 공개 릴리스·주소/버전/크기를, SparkleInstaller/UserDriver가 검증된 SDK 설치 경계를 소유한다. UserDefaults는 design 11절대로 이 Mac 알림 설정·오늘 숨기기·설치 대기 버전/빌드만 저장한다. 서버·허브·기록장·통신 규격 변경은 없다. 업데이트 성공은 기존 펫 말풍선을 재사용한다.
- **빌드·배포:** 0.2.0/빌드 2에 TASK-34·35를 포함한다. Sparkle 2.10.0 고정 지문·프레임워크/rpath·안쪽부터 서명·LICENSE·BuildInfo를 추가했다. hejo-ship은 setup/prepare/사장 전용 publish를 나누며, 기존 공개 키 불일치·더러운 트리·공개본/빌드 트리 불일치·변조 압축을 거절한다. get-hejo는 새 자산 이름과 같은 태그 서버 소스를 쓰고 교체 전 코드 서명을 확인한다. 공개는 초안→자산 지문/크기 확인→서명 피드 확인→latest이며 실패 초안은 지우지 않는다. 공개 함수 시험의 원격 명령은 모두 대역이고 실제 publish는 실행하지 않았다.
- **수락·회귀:** 최종 고정 소스의 foundation9_runner hejo 종료 0, Python 198 passed 및 공식 가짜 Hermes·앱·통신 시험 통과. 이 전체 검사에 test_install.py가 포함된다. 최종 앱 시험 10회 연속 종료 0, 11행 모두 inputsUnchanged=true다. 근거 `.build/task33/frozen-progress.json`, `frozen-inputs.json`, `frozen-foundation.log`, `.build/foundation9-app-task33-verified-01.log`~`10.log`.
- **독립 기준·고장 주입:** 공개 metadata·배포 도구 AT-84 시험 7개는 최종 전체 검사에도 포함됐다. 실제 SDK appcast decoder/delegate와 Sparkle 버전 비교를 사용했다. 주소 허용 비교 제거 돌연변이의 컴파일 0·시험 1 검출은 해당 제품 파일 지문이 같아 재사용했다(`mutations.json`, `static-final.json`). 범위는 주소·버전·크기·메타데이터와 명시 동의 경계이며 실제 앱 교체를 대역으로 통과시켰다고 주장하지 않는다.
- **기존 시험 변경:** Task17 메뉴 기대는 승인된 업데이트 항목 때문에 9→10개·버전 아래 항목으로 바꿨다. 수락 문서·AT 기대는 바꾸지 않았다. SwiftUI 예외는 기존 연결 창 두 파일만 유지하며 새 화면은 AppKit이다. 제품의 기존 AirportFinder Swift 6 Sendable 경고와 시험의 SDK dictionary 초기화 deprecated 경고는 기준 완화 없이 남겼다.
- **최종 후검사:** 개인값·HEJO_PYTHON 지정 훅·diff·앱 코드 서명 결과는 `.build/task33/final-checks.json`에 기록한다. 원본 SDK 서명과 고정 지문, ddots 원본 불변은 `static-final.json`이다. 커밋 뒤 같은 제품 소스를 깨끗하게 다시 빌드해 BuildInfo를 공개본 트리에 맞추며, 로컬 public 커밋·prepare 실제 압축/서명 결과는 `post-commit.json`과 `final-verification.json`을 확인해야 한다. 이 문서의 커밋 시점에는 키체인 사용자 인증을 기다려 최종 배포물 서명은 아직 검증하지 못했다. 이를 통과 전부터 완료로 표시하지 않는다.
- **증거·남은 것:** 필요 인계 수준 2, 최종 도달 여부는 후검사에서 실제 배포물 서명이 확인됐을 때 판정한다. 그 전에는 서명 경계가 미검증이다. evidence/HEJO-FOUNDATION/TASK-33.md의 유효한 함수/설정 캡처는 운영 앱 전체 비교가 아니다. 실제 두 Mac 다운로드·교체·재실행·디스크 실패는 TASK-23 수준 4와 비설계자 검토에 남는다. 운영 반영 전 롤백 자료는 35판의 aeaa652 기준 새 백업을 계획 담당+사장이 준비해야 한다.
- **소유·금지 준수:** 소유 파일만 git commit --only로 기록한다. 앱 사본·공용 릴리스·운영 홈·launchd·Hermes 본체·ddots·운영 저장소·원격은 변경하지 않는다. 기존 키를 재사용하며 새 키 생성·비밀 키 출력·내보내기·원격 공개 없음. TASK-48 이후는 이 결과의 계획 담당 검토 뒤다.

## TASK-33 보완 44: N33-01 초안 조회 수정

- **받은 설계·판단:** handoff 보완 44, 기준 `7d0eb07f731e91c7aba50cd992e5899b36bdda2a`. 고위험 배포 경계의 국소 수정이며 필요한 인계 증거 수준은 2다. 앞선 TASK-33의 키체인 대기는 당시 기록으로 보존하며, 기존 `.build/task33/final-verification.json`에서 실제 서명 성공을 확인했다.
- **책임·변경:** `install/hejo-ship`의 배포 도구 안에서 초안을 조회한다. 두 `releases/tags/<tag>` 조회를 제거하고 `gh api repos/{repo}/releases --paginate --slurp`의 페이지를 합쳐 `tag_name`과 `draft == true`로 고른다. 자산·피드 업로드 각각 뒤 정확히 한 초안만 허용하고 0개·중복이면 초안을 보존한 채 멈춘다. 기존 태그 보호·자산 상태/크기/지문·서명 피드·latest 공개 순서는 유지한다. 같은 태그 초안은 생성 전 확인하며, 원격 태그까지 함께 있는 경우에도 지정된 초안 안내문으로 멈춘다. 삭제·덮어쓰기·자동 재시도는 없다.
- **시험 대역 교체:** `tests/acceptance/test_ship.py`의 경로 무관 초안 응답을 제거했다. 태그 조회는 초안에 404 명령 실패, 페이지 목록은 초안을 포함하는 대역으로 교체했다. 선택 초안을 두 번째 페이지에 두고 다른 태그·같은 태그의 공개 릴리스와 구별한다. 기존 승인/태그 거절과 자산 변조 단언을 보존하고, 보관 초안 1/2개·태그 동시 존재·각 업로드 뒤 0/2개·피드 변조 거절을 추가했다. 초안 조회가 생겨 기존 태그 시험의 관측은 '명령 0회'에서 '읽기 목록 조회 1회·원격 쓰기 0회'로 명확히 바꿨다. 이는 보완 44의 생성 전 초안 확인에 필요한 변경이며 거절·무쓰기 기준은 완화하지 않았다.
- **집중 검증:** `foundation9_runner.py n33-01-ship` 종료 0, 17 passed. `mutation.py`는 무변경 사본 종료 0, 업로드 뒤 조회를 태그 조회로 되돌린 사본 종료 1로 결함을 검출했다. 제품 원본은 불변이다. 초기 돌연변이 하네스는 venv에 pytest가 없어 본문 미실행이었고, 기존 별도 pytest 의존 경로를 지정해 고쳤다. Hermes venv에는 설치하지 않았다. 로그는 `.build/foundation9-n33-01-ship.log`, `.build/n33-01/mutation.json`, `mutation-baseline.log`, `mutation-tag-lookup.log`다.
- **앱·운영 경계:** 앱 소스·통신·문·규격·버전/빌드·키는 변경하지 않았다. 기존 TASK-33 앱 10회·캡처 근거는 같은 앱 입력의 증거로 보존한다. 이번 수정은 화면 변경이 아니므로 새 캡처는 만들지 않는다. 실제 GitHub 목록/초안 공개는 미실행이며 시험 대역 수준 2를 실제 원격 공개 수준으로 주장하지 않는다.
- **공개본·준비물 재생성 방법:** 실제 gh/GitHub 읽기도 금지되어 `install/hejo-publish`의 계정 조회 두 번만 기존 로컬 public 커밋의 작성자 정보로 응답하는 비추적 대역을 사용한다. 실제 gh 실행은 하지 않는다. 이전 로컬 0.2.0 후보는 보관 참조에 남기고 같은 0.1.0 부모에서 대체 후보를 만든다. 그래야 버전/빌드 증가 검사를 완화하지 않고 같은 0.2.0·빌드 2 준비물을 다시 만들 수 있다. 새 공개본과 깨끗한 빌드의 트리를 맞춘 뒤 기존 키체인 키로 새 출력 폴더에 prepare한다. 이전 후보·준비물은 지우지 않는다. 실제 결과는 후속 최종 기록을 따른다.

### N33-01 최종 자체 검증·커밋 경계

최종 소스의 전체 실행 `python3 .build/n33-01/verify.py`는 종료 0이다. 내부 `python3 .build/foundation9_runner.py hejo`는 Python 208 passed와 가짜 Hermes·앱·통신 전체 시험을 통과했다(test_install 포함). 실행 중 고정 입력은 불변이다. 첫 전체 실행은 초안/태그 동시 존재 안내를 보강하기 전 Python 206 passed였으므로 최종 근거로 쓰지 않으며, 변경 뒤 전체를 한 번 더 실행한 결과를 `.build/n33-01/foundation-result.json`, `foundation.log`에 별도로 보존했다. 완료 행을 이유 없이 반복하거나 시험을 skip하지 않았다.

고정 소스의 집중 시험은 17 passed이고 태그 조회로 되돌린 돌연변이는 1 failed/16 deselected로 검출됐다. 필요/도달 인계 증거 수준은 **2/2**다. 실제 원격 API·사장 publish·두 Mac 업데이트 실물은 미실행이며 계획 담당 검토·TASK-23에 남는다. 앱 화면·원본 독해·같은 상태 캡처는 앱 소스 불변이므로 기존 TASK-33 근거를 재사용한다. 실제 공개가 통과했다고 주장하지 않는다.

이 보고 뒤 개인값·HEJO_PYTHON 지정 훅·diff를 검사하고 소유 파일 세 개(배포 도구·시험·이 보고)만 `git commit --only`로 기록한다. 이어 비추적 로컬 계정 대역으로 public 후보 생성, 깨끗한 앱 빌드·코드 서명 검사, 기존 키로 새 ZIP 서명과 독립 검증을 수행한다. 커밋 시점에 후검사는 아직 미실행이며 실제 커밋·public·트리·서명·깨끗한 main은 `.build/n33-01/commit-result.json`, `post-commit.json`, `final-verification.json`과 최종 result 보고를 따른다. 새 키 생성·내보내기·비밀 키 출력·실제 gh/GitHub 호출·앱 사본 교체·공용 릴리스/운영 홈 변경은 하지 않는다. TASK-48 이후는 검토 뒤에 시작한다.

## TASK-48: 문 Slack 경로 동등(I01~I06)

1. **받은 설계:** 보완 45·40, REQ-HF-42.AC-01, design 12-1, 대조표 2.1판 §0-4-3, AT-99. 기준 `763c839b359842e50ac2503db68198ddd74728ef`. 일반·필요 인계 수준 2. 구현자 판단은 구현·자체 검증이며 최종 판정은 계획 담당에게 넘긴다.
2. **원본·칸:** copy-review의 TASK-48 절처럼 Hermes Slack 유지 메서드와 공식 어댑터·저장소·지역 낱말표·미디어 의존을 대조했다. 문 기존 책임 안에서 처리하며 Hermes 본체·앱·허브·규격은 바꾸지 않았다. 새 영구 원본은 없다.
3. **I01:** 공식 set_session_store로 받은 저장소의 exact-key 조회와 suspended를 읽고, 세션 없는 1:1 앞 글을 기존 context.py 한도로 복원한다. 조회는 세션을 만들거나 활동 시각을 갱신하지 않는다. Slack 수신처럼 공식 MessageEvent.channel_context를 써 원래 본문·명령 위치를 보존한다. 기존 방 문맥과 25판 분기 문맥은 유지하며 첫 분기 글에 복원 문맥을 겹치지 않는다. 물리 파일·삭제된 글을 새 원본으로 읽지 않고 Journal의 현재 투영을 사용한다. Slack의 활성 세션 watermark/재시작 delta는 '활성 세션이면 붙이지 않음'이라는 이번 hejo AC 범위에 포함하지 않는다.
4. **I02·03:** splits_long_messages를 선언했다. context.py가 줄을 우선해 UTF-8 바이트 한도로 손실 없이 나누고, send가 같은 스레드의 보통 message로 기록한다. 기본 단추·명시 단추·첨부 메타는 마지막 조각에 둔다. 편집 넘침은 기존 edit 지연 작업을 정리하고 조각을 편집·추가하며 축소 때 남은 꼬리를 보통 delete로 지운다. 조각 인덱스는 프로세스 메모리에만 두고 disconnect에서 없앤다. 같은 최종 편집을 반복해도 새 꼬리를 중복 생성하지 않으며 기존 단추는 마지막 조각으로 옮긴다. 편집 예정인 긴 최초 보냄은 첫 조각을 편집 anchor로 반환하고, 보통 긴 최종 보냄은 Slack처럼 마지막 조각 id를 반환한다. 중간 기록 실패는 이미 커밋한 조각을 보존하고 기존 실패 결과를 반환한다. seq를 미리 예약하지 않는다.
5. **I04·05:** 기존 resolver는 유지하고 공식 지역 낱말표로 slash 확인·기타 단추를 만든다. 성공한 기본 단추 클릭은 결과 줄 edit와 buttons=[]로 닫는다. 원래 내부 단추 매핑이 있는 이미 닫힌 글의 재누름은 무시하며, 모르는 단추·실제로 만료된 resolver의 오류 처리는 유지했다. native 클릭 잠금으로 동시 두 번 해석을 막는다. 기존 AT-17에는 승인된 결과 edit를 읽고 단추 비움을 단언하는 세 줄을 추가했다. 기존 resolver 호출·barrier 단언을 없애거나 완화하지 않았다.
6. **I06:** 링크 사진은 공식 SSRF-safe HTTP 클라이언트·redirect 검사·30초 한도와 FileStore의 스트리밍 크기 한도·0700/0600·원자적 등록을 사용한다. image MIME이 아니거나 안전하지 않거나 받기에 실패하면 공식 미디어 실패 글로 알리고 URL·서버 파일 경로는 노출하지 않는다. 음성·영상은 기존 send_document의 검증·등록·삭제 방어·전달자 경로를 재사용한다. 별도 파일 저장소는 없다.
7. **시험·초기 오류 처분:** 새 집중 시험 14개와 기존 확장 시험을 함께 실행해 22개가 통과했다. 초기 하네스의 replay 호출 인자, 페어링 재현 순서, 가짜 게이트웨이 사장 허용 설정을 고쳤다. SessionStore 시험은 실제 multiplex 설정과 맞췄고, 한국어 입력은 공식 display.language 위치를 사용했다. 원본 비교 도우미의 상대 출력 경로 오류는 도우미 위치 기준으로 고쳤다(출력 파일 생성 전 실패, 운영 파일 쓰기 없음). 제품 계약이나 합격 기준을 낮추지 않았다. 바이트 분할 제거 돌연변이는 무변경 사본 0·변경 사본 1로 검출했고 제품 원본은 불변이다(`.build/task48/mutation.json`).
8. **같은 상태 비교:** evidence/HEJO-FOUNDATION/TASK-48.md와 task48-comparison.json을 참조한다. 앱 파일이 없는 문 작업이어서 UI를 새로 그리거나 기존 캡처를 새 증거로 바꾸지 않았다. 실제 원본 함수·공식 세션 저장소와 문 수신을 같은 가짜 상태로 비교했다. 정기 보고·메시지 도구는 공식 가짜 게이트웨이 통합에서 확인한다. 도달 수준은 대역 통합 2이며 실제 Slack/운영 실행·실물 4를 주장하지 않는다.
9. **미검증·검토 요청:** 실제 운영 정기 보고·두 Mac 긴 글/첨부 보기는 TASK-23에 남는다. 검토자는 편집 anchor/꼬리 인덱스·반복 최종 편집, 프로필별 세션 키, 기본 단추 클릭 순서, 파일 등록 실패 시 롤백을 특히 확인한다. 프로세스 재시작 후 예전 스트리밍 편집 체인을 복원하는 새 영구 인덱스는 만들지 않았다. 범위 밖 UI·team-kit 변경은 없다.
10. **소유·금지:** 소유 파일만 git commit --only로 기록한다. public `f716bdff38af3d8c2cb2cdf4502e080ecbecb2bc`와 준비물은 그대로 둔다. 운영 홈·설치 도우미 운영 실행·게이트웨이 재시작·공용 릴리스·앱 사본·GitHub 조회/원격 쓰기·본체/ddots/운영 저장소 변경·비밀 키 접근은 하지 않았다. TASK-49는 계획 담당 검토 뒤다.

### TASK-48 최종 실행 결과

- `python3 .build/task48/verify.py` 종료 0. 내부 `foundation9_runner.py hejo`는 Python **222 passed**와 가짜 Hermes·앱·루프백 통신 시험을 모두 통과했다. test_install이 포함된다. 고정 입력 불변·public 불변을 확인했다(`.build/task48/foundation-result.json`, `foundation.log`). 앱 소스가 바뀌지 않아 앱 10회 반복은 추가하지 않았으며 이 전체 실행의 앱 시험을 사용한다.
- 집중 실행은 새 시험 14개와 기존 확장 시험을 합쳐 **22 passed**다(`.build/foundation9-task48-execution.log`). 바이트 분할 제거 돌연변이는 시험 종료 1로 검출했고 무변경 사본은 0이다(`.build/task48/mutation.json`). 같은 공식 저장소 상태·한국어 단추의 원본 비교는 종료 0/1 passed다(`.build/foundation9-task48-reference-final.log`, `comparison.json`).
- 필요/도달 인계 증거 수준 **2/2**. 실제 운영·Slack·두 Mac 실물은 미실행이다. 초기 집중 시험 실패는 위 7항에 처분했고 마지막 실행의 실패·skip·xfail은 없다. 기존 앱 Sendable/SDK deprecated 및 기존 비동기 마커 경고는 이번 변경에서 생긴 것이 아니며 억제하지 않았다.

이 최종 보고 뒤 개인값·HEJO_PYTHON 지정 훅·diff 검사를 수행한다. 커밋은 소유 파일 10개만 `git commit --only`로 남기고, 실제 전체 커밋·파일 목록·입력 불변·깨끗한 main·public 고정·0.2.0 준비 ZIP 불변은 `.build/task48/final-checks.json`, `commit-result.json`, `final-verification.json`과 최종 result 보고를 대조한다. 운영 적용·공용 릴리스·public 갱신·원격 쓰기는 하지 않는다.

## TASK-48 보완 46: N48-01·02

- **받은 설계·기준:** handoff 보완 46, 기준 `b9d5e3632f4da018f94c1ee708f2ee48b0d0a708`. 일반·인계 필요 수준 2. 작은 문구·호환 보완을 한 커밋으로 넘긴다.
- **N48-01:** buttons.decision의 승인·확인 결과를 이름 없는 공식 Telegram 낱말표 키로 교체했다. 이름·조사를 끼워 넣던 Slack 결과 키 매핑은 제거했다. 낱말은 여전히 `agent.i18n.t`의 현재 지역 설정에서 읽으며 새 한국어 문구를 만들지 않았다. clarify의 Slack 공식 결과·직접 입력 안내와 `user="나"`는 그대로다. 클릭 잠금·resolver·결과 edit·단추 비움·재누름 처리는 변경하지 않았다.
- **N48-02:** send_video가 공식 Base 서명처럼 추가 키워드 인자를 받고 기존 send_document 경로로 전달한다. 별도 첨부 경로나 영구 원본은 만들지 않았다.
- **집중 검증:** `foundation9_runner.py n48-focused-final` 종료 0, test_delivery_parity.py **24 passed**. 승인 네 종류·확인 세 종류는 지정 공식 키의 실제 낱말과 같고 `이(가)`가 없음을 확인한다. clarify 결과/대기 두 종류는 기존 공식 문구와 같음을 확인한다. 실제 클릭 WebSocket 결과 줄에도 공식 낱말 일치·조사 없음 단언을 추가했다. 영상은 `supports_streaming=True`를 주어 실제 임시 파일 첨부와 등록 바이트를 확인한다. 기존 시험을 삭제하거나 합격 기준을 완화하지 않았다. 로그 `.build/foundation9-n48-focused-final.log`.
- **성격·증거:** 문구와 Python 호출 호환의 승인된 의미 변경이다. 원본 대조는 copy-review의 보완 46 절에 있으며 수정 전 TASK-48의 결과 문구 비교는 역사 기록으로 유지한다. 이번 인계는 대역 통합 수준 2이며 실제 운영 실행을 뜻하지 않는다. 앱·화면·규격·허브·설치 도구 변경은 없다. 범위가 작고 기존 resolver·권한·분할 알고리즘은 그대로라 별도 돌연변이 검사는 추가하지 않는다. 현행 문구·키워드 경계를 집중 시험과 전체 회귀로 확인한다.
- **금지·남은 것:** 운영 홈·공용 릴리스·public·준비물·앱 사본·Hermes 본체·ddots·운영 저장소·원격은 바꾸지 않는다. 실제 GitHub/gh 조회·비밀 키 접근·운영 실행은 없다. TASK-49는 이 보완의 계획 담당 검토 뒤 시작한다. 최종 검증·실제 커밋은 아래 기록과 `.build/n48/final-verification.json`을 따른다.

### N48-01·02 최종 자체 검증

`python3 .build/n48/verify.py`는 종료 0이다. 내부 `python3 .build/foundation9_runner.py hejo`는 **232 passed**와 앱·공식 가짜 Hermes·루프백 통신을 모두 통과했다(test_install 포함). 고정 입력 171개가 불변이며 public도 그대로다. 근거는 `.build/n48/foundation-result.json`, `foundation.log`다. 필요/도달 인계 증거 수준은 **2/2**이며 운영 실물은 미실행이다. 변경한 앱 소스가 없어 앱 10회 반복은 추가하지 않았다.

이 보고 뒤 개인값 검사·HEJO_PYTHON 지정 훅·diff를 실행하고 소유 파일 다섯 개만 `git commit --only`로 기록한다. 실제 결과·전체 커밋·파일 목록·깨끗한 main·고정 public와 0.2.0 준비 ZIP 불변은 `.build/n48/final-checks.json`, `commit-result.json`, `final-verification.json`과 최종 result 보고를 대조한다. 후속 TASK-49는 이 결과의 계획 담당 검토 뒤다.


## TASK-49 착수 보류: 운영 원본과 worktree 사본 불일치

- **받은 지시·기준:** 보완 41·45·40·38, REQ-HF-43·AT-100. hejo 기준 `3c9a0f6d10c147c145b6d8c2b79d50895f39e5bf`, public 후보는 기존 f716bdf 고정이다. 운영 저장소 임시 worktree에서만 개발하고, 시작 사본이 운영 원본과 다르면 멈추라는 조건을 먼저 검사했다.
- **확인 사실:** 별도 detached worktree의 team-kit 소스 656개와 운영 원본 657개를 비교했다. `lib/hermes_packs/cctv/now.py`·`watch.py` 두 본문이 다르고, 운영 원본에만 `lib/hermes_packs/cctv/tests/test_channel_messages.py`가 있다. 생성 캐시만 제외했으며 파일 종류·실행 비트·링크 대상도 비교했다. 지문과 기준 전체 커밋은 `.build/task49/initial-comparison.json`에 있다.
- **멈춤 판단:** 작업 대상 reply/report_status와 다른 모듈의 차이지만, 인계의 시작 일치 조건에는 예외가 없다. 구현자가 무시·복사·sync·기준 커밋 변경으로 우회하지 않았다. 새 설계 결함으로 단정하지 않으며 운영 원본에 진행 중인 별도 작업이 있는지는 미확인이다.
- **변경·미실행:** hejo 추적 변경은 이 보고와 copy-review의 착수 대조 기록뿐이다. 제품·시험·규격·운영 원본·운영 저장소 작업 파일은 바꾸지 않았다. 임시 worktree는 무변경 상태로 보존한다. TASK-49 구현 패치 `team-kit.patch`는 아직 없으며 team-kit 시험·airport-check·AT-100·foundation·앱·test_install·돌연변이·비교 화면은 미실행이다. 필요 인계 수준 2, 현 단계는 소스 대조만 수행하여 수준 1이다.
- **다음 담당 판단:** 계획 담당과 사장이 별도 운영 변경의 반영 상태를 확인하고, 운영 원본과 일치하는 사본 기준 또는 불일치 처분을 확정한 뒤 재인계해야 한다. 실행 담당은 새 기준으로 첫 대조부터 확인하고 원본 독해→공개 메서드 필요성 판단→구현·시험을 진행한다. 현재 커밋·푸시·후속 TASK는 하지 않았다. 운영 홈 실행·재시작·설치 도우미·sync·공용 릴리스·public·GitHub 조회/쓰기·실제 발송·비밀 파일 열기 없음.

보고 검사: 보고 파일 변경본의 Hermes venv `scripts/scan_private.py --repo .`, `HEJO_PYTHON` 지정 `sh githooks/pre-commit`, `git diff HEAD --check`는 각각 종료 0이었다. 임시 worktree의 `git status --porcelain` 출력은 없고 hejo 변경은 위 보고 두 파일뿐이며 HEAD·public 후보는 불변이다. 최종 로그·종료 코드는 `.build/task49/report-checks.json`과 `private.log`·`hook.log`·`diff.log`를 따른다.


## TASK-49 재개·보류: 보완 47 해소 뒤 D49-01 맞춤 제출 계약

- **시작 대조 해소:** hejo 기준 `6e316a241f962fb864ab2158a444182b7a0d10cc`. 보완 47의 변경·의존 범위 373개는 운영 원본과 일치해 착수 조건을 충족했다. 앞선 cctv now.py·watch.py·tests/test_channel_messages.py 불일치는 범위 밖으로 기록만 유지한다. 원본·worktree를 서로 덮지 않았다.
- **원본 독해:** copy-review의 재개 표와 `.build/task49/source-map.json`에 지정 plugin 전체·report_status 전체, 체크리스트 controls/제출/이벤트 생성과 호출 의존을 기록했다. 아직 구현하지 않은 코드의 이식 완료를 주장하지 않는다.
- **발견(D49-01):** REQ-HF-43.AC-01의 맞춤 submits를 Slack과 같은 의미로 보존할 때 현재 hejo checklist 계약에는 제출 선택이 없다. 같은 일정 체크도 원본 lv1/lv2/확인 단추는 서로 다른 답을 만들지만 현재 앱은 `선택: 일정`만 만든다. gate는 submits 필드를 거절하고 규격에도 허용되지 않는다. 제출 낱말을 items에 섞으면 전체 특례가 제출값을 지우고, 단일 제출 단추 둘을 함께 고를 수 있어 원문 의미를 조용히 바꾸게 된다.
- **직접 재현:** `.build/task49/probe_checklist.py` 종료 0. 원본 rb.controls·checklist_blocks·checklist_update·synthetic_event의 6가지 답을 단언했고, 현재 제품 ThreadTools.answer를 분리한 Swift 컴파일/실행 각각 0으로 두 대안 반례를 확인했다. gate 실제 _checklist 함수도 임의 submits를 invalid_checklist로 거절했다. 근거 `checklist-probe.log`·`checklist-contract.json`. 대역/분리 실행 근거 수준 2이며 AT-100 제품 전체의 통과는 아니다.
- **선택지·권고(미채택):** A는 checklist 선택 필드 submits와 앱의 제출 단추/답 생성 의미를 명세·AT에 추가하고 gate·앱 변경을 허용하는 방법이다. B는 맞춤 submits 변형만 명시된 글자 대체로 낮추되, 보여줄 선택·답 형식·빈 확인/건너뛰기와 asked→answered→closed 기대를 계획에서 정하는 방법이다. 원문 의미 보존에는 A를 권고한다. 공개 메서드 하나만 더하거나 wire 밖 임시 추적 표를 만들어 제출 선택을 추측하지 않았다.
- **변경·미실행:** 이번 경계는 원본 대조·재현·보고뿐이다. hejo 제품·시험·규격·앱, 운영 원본, 임시 worktree 제품 파일은 무변경이다. `.build/task49/team-kit.patch`는 아직 없고 적용 dry-run·team-kit 전체 tests·airport-check·foundation·앱·test_install·고위험 돌연변이·화면 비교는 미실행이다. 부분 J01/J02 초안도 적용하지 않았다. TASK-49 전체의 필요한 증거 수준 2에는 미도달이다.
- **인계:** 기존 보류 기록과 이번 결과를 보고 두 파일만의 git commit --only로 남긴다. public 후보 f716bdf 고정, 앱 사본·공용 릴리스·운영 홈·본체·ddots·원격은 바꾸지 않는다. sync·재시작·설치 도우미·실제 발송·비밀 파일 열기 없음. 다음은 계획 담당의 D49-01 계약 처분이며, 그 전 후속 TASK는 진행하지 않는다.


## TASK-49 최종 구현·자체 시험(보완 48·47·41)

- **기준·해소:** `afc019d56724621784d72a0137e0f92a4486becd` 위에서 D49-01을 승인된 ddots 방식으로 해소했다. 기존 시작 보류·맞춤 제출 보류 기록은 보존한다. 재개 직전 변경/의존 373개 일치. 범위 밖 `cctv/now.py`·`watch.py`·`tests/test_channel_messages.py` 차이는 이전 목록대로이며 이번 패치에 없다.
- **책임·파일:** 문에는 `gate/adapter.py` 공개 조회 메서드와 `gate/tests/test_report_query.py`만 더했다. 현재 투영에서 자기 직원의 첫 글을 읽으며 기록장·캐시·통신 규격은 바꾸지 않는다. team-kit 변경은 임시 worktree의 `lib/hermes_reply/plugin.py`, `lib/hermes_team_services/report_status.py`, `tests/test_hejo_parity.py`, `tests/test_reply_hejo.py` 네 파일이고 결과 패치는 `.build/task49/team-kit.patch`다. 운영 저장소에는 커밋하지 않는다.
- **J01:** Slack과 공통인 조각 결과 집계, 조각별 prepare, 같은 스레드·마지막 성공 id/이전 id 목록, 중간 실패 후 다음 조각 시도/partial_overflow를 구현했다. interim·expect_edits·열린 흐름은 한 글로 보낸다. 새 글의 스레드 id와 흐름·질문 추적은 기존 어댑터별 한도 2048의 힌트를 확장하며 영구 원본을 추가하지 않는다.
- **J02:** 공식 현재 턴의 소유자·프로필·대화·세션이 맞는 hejo 도구 실행만 현재 연결로 보낸다. 첫 직원 글에 pending/failed→asked, partial→answered, done/declined→closed 및 제목 🔴/🟡/🟢를 적용한다. 단추는 부분 상태에서 id까지 보존하고 종결 때 비운다. 상태 안내 줄·시각·note는 보이지 않는다. 공개 어댑터 조회·edit_message·set_reply_state만 쓰며 gate 내부 import는 없다. 기존 Slack handle/repaint는 유지한다.
- **J03:** 일반 체크리스트는 items·빈 selected·can_skip=true, 맞춤 제출 변형은 체크 항목만·빈 selected·can_skip=false다. 맞춤 제출 낱말은 실제 hejo 프레임 어느 곳에도 없다. 앱의 선택/전체/건너뛰기 답을 해당 직원·스레드의 asked→answered→closed로 연결했다. 스레드 없는 첫 글도 답 추적을 검증했다. usage_ledger의 hejo 제외를 고정했다.
- **수락·회귀(최종 변경본):** 집중 시험 154 passed. worktree team-kit tests 전체 4878 passed·3 skipped·58 subtests passed. `./airport-check --snapshot <임시 worktree>` 종료 0, boundary 382·document 0·compartments 0이며 기준선은 바꾸지 않았다. cctv 범위 밖 차이로 인한 실패는 없었다. hejo foundation9_runner 전체 종료 0, 235 passed 및 가짜 Hermes·AppKit·루프백 통신 APP_TEST_OK. test_install.py도 이 전체 검사에 포함됐다. `.build/task49/frozen-progress.json` 세 행 모두 exitCode=0·inputsUnchanged=true, 입력 721개 불변이다. runner는 기존 foundation9_runner의 team-kit 라이브러리 경로만 worktree로 지정한 격리 사본이다. Hermes venv에 설치하지 않았다.
- **기존 시험 처분:** test_reply_hejo의 65537자 실패 기대는 TASK-48의 바이트 나누기 이후 유효하지 않았다. 실패 보냄이 answered를 닫지 않는 기존 단언은 그대로 두고, 임시 기록장 append 실패를 직접 주입했다. 수락 문서의 기대 완화는 없다. 보완 48이 지정한 일반 skip=true·맞춤 skip=false/제출 낱말 미전송 두 경우를 새 AT-100 매핑 시험으로 고정했다. 초기 시험의 fixture 호출 착오는 공개 메서드/공식 session_context 실제 시그니처에 맞게 바로잡았다.
- **돌연변이:** 자기 직원 필터 제거와 맞춤 can_skip 판정 제거 사본은 각각 baseline 0·mutation 1로 검출했다. 원본 불변을 확인했다. `.build/task49/mutations.json`, query-owner/custom-skip 로그 참조.
- **같은 상태 비교:** ddots의 실제 파서·checklistAnswer와 제품 ThreadTools.answer를 분리 컴파일/실행하고 같은 가짜 입력의 실제 hejo 프레임을 비교했다. 비교 시험 1 passed, Swift 컴파일·실행 각각 0, DDOTS_HEJO_CONTROL_PARITY_PASS. `.build/task49/parity-comparison.json`·comparison.log. 새 화면/레이아웃 변경이 없어 GUI 캡처는 만들지 않았다. 운영 앱 전체·실제 서버·Slack 비교를 주장하지 않는다.
- **패치 적용성:** 운영 원본을 임시 디렉터리에 cp -R로 복사한 뒤 patch --dry-run -p1 종료 0. 네 파일 모두 적용 가능했고 운영 원본에는 적용하지 않았다. `.build/task49/patch-dry-run.json`·patch-dry-run.log. 배포 때는 이 패치와 문 공개 메서드 커밋이 함께 필요하다.
- **증거·남은 범위:** tasks.md의 최종 요구 수준은 일반·3이다. 이번 구현/대역 통합 도달 수준은 2이며 실제 운영 원본 교체·서버 재시작 후 상태 보고는 계획 담당+사장의 승인된 운영 단계에 남는다. 기존 2048개 힌트는 프로세스 수명 추적이므로 재시작 뒤 답 추적 복구 실물도 검토 대상이다. 현재 어댑터·앱·통신 계약의 확장은 공개 조회 메서드 외에 없다.
- **최종 확인·인계:** 보고 추가 뒤 개인값·HEJO_PYTHON 지정 훅·hejo/worktree diff 검사를 실행하고 `.build/task49/final-checks.json`에 실제 결과를 남긴다. hejo 소유 네 파일만 git commit --only로 기록한다. 운영 원본·본체·ddots·운영 저장소 작업 파일·공용 릴리스·앱 사본·public·원격은 바꾸지 않는다. sync·재시작·설치 도우미 운영 실행·실제 발송·GitHub 조회/쓰기·비밀 파일 열기 없음. 최종 커밋/패치 지문·원본 보존은 `.build/task49/final-verification.json`에서 확인한다. 다음은 계획 담당 검토이며 TASK-36 이후는 아직 시작하지 않았다.

## TASK-36 착수 대조·부분 초안 — D36-01(A07 통신 계약 공백) 보류

- 기준: `05cc1fba76bd2df65038ae80174599c5635679f5`, 보완 38·49와 대조표 2판 §A·§0-4 2.1판. TASK-49 완료 근거는 재실행하지 않았다. 공통 규칙·현재 인계·실제 깨끗한 main을 대조한 뒤 시작했다.
- 원래 자리: 읽음·종·확인·체크는 기존 MemberState 키, 스레드 상태는 기록장 투영에서 계산, 마지막 방은 기존 LocalSettings의 Mac 화면 설정, 표시는 기존 AppKit 카드·단추다. 새 영구 자료 원본은 만들지 않았다.
- 작성한 초안: 처음 동기화의 과거 읽음, 방 진입 때 종 스레드 제외, 처음 message seq·생각 줄 제외, 보낸 뒤 읽음, 텍스트 승인 정규식·기본 단추·상태 막대·질문 기여 순서, 마지막 방, 별명·본문 revision별 체크·내 글 색을 기존 경로에 연결했다. `answered`는 사장 답을 받고 처리 중인 원래 차례 뜻이므로 ddots working(노랑), closed는 종결(초록)에 대응시켰다.
- 기존 시험의 명시적 대체: A03에 따라 편집 뒤 unread 증가 단정을 0으로, V01에 따라 처리 중 조용한 종 단정을 없음으로 바꾼 초안을 보존했다. A11에 따라 직접방 메뉴 시험은 방을 명시적으로 고르는 준비를 추가했다. 기존 AT 문서의 기준·입력은 바꾸지 않았다.

### D36-01 사실과 결정이 필요한 범위

A07의 원본은 한 스레드에 여러 요청이 있을 때 어느 요청에 단추로 답했는지 구분한다. 근거는 ddots `SlackPanel.swift`의 answerHermes·onClickSend, `SlackBridge.swift`의 post(clickedPost:), `SlackThreads.swift`의 clickBlocks·answers·pendingPosts다. 클릭 대상이 있으면 그 요청만, 없는 직접 쓴 글이면 해당 글 앞 요청 모두를 답한 것으로 본다.

현재 hejo는 `gate/adapter.py:560` click에서 대상 msg_id를 알고 Hermes 이벤트에는 넘기지만 `receive`의 사장 기록(642행 부근)에는 보존하지 않는다. `gate/journal.py:165` public·page 및 `schemas/hejo-wire-v1.json` message에도 대상 필드가 없다. 앱은 state(A=answered), B=asked 뒤의 사장 '승인'이 A 버튼 클릭인지 직접 쓴 글인지 재현만으로 구별할 수 없다. state 변화의 인접 순서로 추정하면 report_status 같은 독립 상태 갱신·다른 Mac·재접속 순서에서 다른 뜻을 만들므로 채택하지 않았다.

- 실제 어댑터 탐침: 요청 A·B 생성, A만 answered로 바꾸는 허용 클릭 callback, A 단추 클릭. Hermes raw 이벤트에는 A가 있지만 앱용 사장 기록에는 대상 필드 없음, B는 asked 유지. 대상 필드를 덧붙이면 현행 스키마 거절. `.build/task36/button-target-boundary.json`, `.build/foundation9-task36-boundary.log`.
- 원본 함수 분리 실행: A=working·B=asking 뒤 같은 사장 본문 '승인'. 직접 쓴 답이면 pending=[], A 대상 클릭이면 pending=[B]. 원본 함수는 변경하지 않고 가짜 메시지·스레드 타입만 제공했다. `.build/task36/target-comparison.json`, `target-run.log`.
- 판단 요청: 기록·재현·통신에서 대상 요청 id를 선택적으로 보존·전달하는 계약과 옛 앱/문 호환을 계획 담당이 정해 주면 A07을 원본대로 이식할 수 있다. 권고는 이 계약을 명시하는 것이다. 여러 요청을 모두 답한 것으로 취급하는 차이는 원본 동등 동작이 아니므로 사장 선택 없이는 적용하지 않는다. 구현자가 규격을 바꾸지 않았다.

### 실제 검증·현재 상태

- `python3 .build/task36/focused.py`: 컴파일 0·집중 실행 0(`AT-HF-87 APP PASS`). 단일 요청·읽음·본문 승인·색·체크·별명·마지막 방의 초안 시험이다. 새로 발견한 항목별 대상 구분은 포함하지 않아 TASK-36 수락 완료 근거로 쓰지 않는다. 로그 `focused-compile.log`, `focused-run.log`, `focused.json`.
- 앱 전체 1차: 종료 1, 편집 시 unread를 다시 늘리는 기존 단정. 앱 전체 2차: 종료 1, 첫 선택을 첫 직원으로 가정한 기존 메뉴 단정. 위에서 적은 명시적 대체만 초안에 반영했다. 그 뒤 앱 전체 재실행·foundation 전체·test_install·돌연변이·원본과 같은 상태 화면 대조는 미실행이다. 집중 실행에서 만든 PNG도 원본 비교 통과 증거로 쓰지 않는다.
- 진단 시험 최초 실행은 Journal.replay 인자 사용 오류로 종료 1, 실제 page(0) 경로로 고친 재실행은 종료 0·1 passed다. 이는 제품 변경이 아닌 계약 탐침이다. 원본 함수 탐침 컴파일·실행 각각 0.
- A07을 보류했고, 나머지 행의 초안 14개를 `.build/task36/draft/`·`draft-files.json`·`draft.patch`에 보존했다. 보존 사본과 지문 대조 뒤 제품 파일은 착수 HEAD로 복구했다. 보고 두 파일만 미커밋 변경이며 새 커밋은 없다. 필요/도달 증거 수준은 2/1이다. 후속 TASK는 미착수다.
- 운영 홈·비밀 파일·본체·ddots·운영 저장소 수정, 재시작·운영 설치·실제 발송·GitHub 조회/쓰기·public·공용 릴리스·앱 사본 변경은 하지 않았다. 공개 후보는 고정값 그대로다. 이 보류는 푸시와 무관하다.

보고 변경본의 개인값 검사·HEJO_PYTHON 지정 pre-commit·diff 검사와 최종 파일 범위 확인은 `.build/task36/report-checks.json`에 실제 종료 코드로 기록한다. 이 검사는 복구 뒤의 보고 변경본 검사이며 제품 수락 시험을 대신하지 않는다.


## TASK-36 최종 구현·자체 시험 — 보완 50 D36-01 해소

- **기준·초안:** 기준은 `a7cae0ce0a1898afc400843b3655f55f0a9c4bdd`다. 기존 D36-01 보류·독해 기록을 보존했다. 보존한 14개 초안은 manifest 지문과 대조하고, 이전 기준에서 제품 차이가 없음을 확인해 복원했다. 기존 TASK 완료 검사를 반복하지 않았다.
- **원본 자리·구현:** 읽음·종·확인·체크는 기존 MemberState 키, 요청/답/상태는 기록장 투영, 마지막 방은 LocalSettings의 Mac 화면 설정을 쓴다. 처음 보는 방의 과거 글만 처음 seq로 읽고, 빈 방은 read:0을 남겨 나중 글을 재접속이 지우지 않게 한다. 방 진입 때 종 스레드는 제외하며, 편집/state/생각 줄을 새 글로 세지 않는다. 전송 성공 뒤 읽음을 연결했다. 새 영구 원본은 없다.
- **A05~16:** 원본 승인 정규식·직접 답 낱말·요청별 대기·기본 네 단추·누를 수 없음 안내, 알림 기여 순서, 상태 색을 이식했다. answered는 사장 답을 받고 처리 중인 노랑, asked는 빨강, closed는 초록이며 생성된 “처리 완료” 줄은 없다. 받은 확인 단추는 그 단추 답을 전송하고 기본 추론 확인만 로컬 처리한다. 별명 조회는 공백·하이픈·밑줄을 무시한다. 본문 revision/문자 위치별 체크와 내 글의 지정 색을 보존하며, 옛 화면의 체크 행동도 그 화면 본문에만 적용한다. AppKit 기호·단추 기하도 원본과 대조했다.
- **D36-01·통신:** 승인된 wire v1 message 선택 필드 answer_to만 추가했다. reply 클릭의 요청 id를 사장 message 기록에 남기고 Journal/page/sync가 그대로 전달한다. send에는 필드가 없으며 위조 입력은 거절된다. 앱은 대상이 없으면 앞 요청 모두, 있으면 해당 요청만 답한 것으로 계산한다. A가 working/B가 asking일 때 A 버튼 “승인”은 B를 남기고, 같은 말을 직접 쓰면 B도 답해진다. 빈 캐시 재접속에서도 같다.
- **호환성:** 최종 app-tests 빌드와 현재 문·실제 옛 문 aeaa652를 각각 임시 홈의 실제 루프백으로 시험해 종료 0이다. 옛 문의 필드 없음은 승인된 직접 입력 취급이며 오류가 없다. 기존 a7cae0c의 GateClient·LocalStore·ConversationModel 소스를 따로 컴파일해 새 문의 실제 answer_to 포함 기록을 읽었고 컴파일/실행 모두 0이다. 운영 홈·통신의 되돌림 연결은 만들지 않았다. 근거 `.build/task36/compatibility.json`, `compatibility-final.log`, `old-app.json`, `old-app-final.log`.
- **최종 전체·반복:** `python3 .build/task36/frozen.py` 종료 0. 내부 foundation9_runner hejo는 236 passed 및 앱·가짜 Hermes·루프백 통신을 통과했다. tests/acceptance/test_install.py도 이 전체 검사에 포함됐다. 이후 같은 최종 빌드의 앱 단위 시험과 여덟 루프백 시나리오를 세 차례 반복했고 모두 종료 0이다. 전체 1행+앱 3행의 inputsUnchanged=true, 검증 입력 159개 불변이다. 로그 `frozen-progress.json`, `final-foundation.log`, `app-repeat-01.log`~`03.log`.
- **시험 처분:** 이전의 편집 unread 증가·첫 직원 기본 선택·edit/state까지 포함한 읽음 seq 단정은 대조표 A03·A11과 원본으로 명시적으로 대체했다. 평범한 글 수신 뒤 읽음은 그 방에 머문 채 수신을 확인한 다음 이동하도록 시험 순서를 고쳤다. 초기 전체 실패는 이 옛 단정/준비 순서였고, 마지막 본문 revision 보강 도중 완료한 실행은 입력 불변이 아니므로 최종 근거에서 제외했다. 최종 소스로 전체/반복을 다시 완료한 결과가 위 근거다. 수락 문서 기대값은 완화하지 않았다.
- **돌연변이:** answer_to 기록을 제거한 임시 사본은 baseline 종료 0, 돌연변이 종료 1로 요청 대상 보존 단언에 걸렸다. 원본 불변. `.build/task36/mutation.json`, `mutation-missing-target.log`. 이 근거의 gate 구현·시험은 최종 소스와 같다.
- **화면·서명:** 최종 빌드 `--task36-capture`와 원본 NativeThreadCard·ReplyActionIcon·ConversationRules·slackApproval 분리 실행은 각각 종료 0이다. 같은 가짜 상태·14pt/파랑·밝은 화면의 PNG 두 개를 evidence로 보존했다. 유효한 620×560 PNG와 빨강/노랑/초록 막대를 확인하고 직접 표시를 대조했다. 실제 hejo Content 조립 대 원본 조각 비교이며 운영 앱 전체·픽셀 동일 비교는 아니다. 세부 범위는 `evidence/HEJO-FOUNDATION/TASK-36.md`, 지문/실행은 `.build/task36/post-checks.json`, `image-check.json`. `codesign --verify --deep --strict app/.build/hejo.app`도 종료 0이다.
- **수준·인계:** 필요한/도달 증거 수준은 2/2다. 실제 서버·두 Mac·실물 입력 결합과 최종 제품 판정은 별도 운영/검토 단계에 남는다. 최종 보고 뒤 개인값·HEJO_PYTHON 지정 훅·diff 검사를 실행하고 소유 파일만 git commit --only로 기록한다. 실제 종료 코드·전체 커밋·입력/캡처 바이트·깨끗한 main은 `.build/task36/final-checks.json`, `commit-result.json`, `final-verification.json`에서 확인한다.
- **변경 금지 보존:** public 후보 f716bdf 고정, 앱 사본·공용 릴리스·운영 홈·본체·ddots·운영 저장소·원격을 바꾸지 않았다. 재시작·운영 설치·sync·실제 발송·GitHub 조회/쓰기·비밀 파일 열기·키 출력은 없다. TASK-37 이후는 아직 시작하지 않았으며 계획 담당 검토 뒤 이어간다.


## TASK-37 진행 기록 — 작성기·전송 경계(보완 51·38)

기준은 f1dbde2이며 TASK-36 판정은 유지한다. 작성기 값은 기존 Controller의 초안/실패/전송 메모리, 확정 글은 기존 기록장·복제본, 읽음은 기존 회원 상태다. 새 영구 원본·통신 필드는 없다. 원본 독해와 B05/N36-01의 코드 대조 사실은 copy-review에 이어 적었다.

초안 자리는 auto/new/thread로 유지하고, 새 글의 실제 전송 UUID와 구분한다. 확인 전 글·첨부는 pending 메모리에서 기존 Post.pending으로 보이며, 확인되면 기록장 글로 바뀐다. 이후 입력을 늦은 확인이 지우지 않고, 실패 글은 원래 연결·보던 방·초안 자리와 함께 남는다. 자동 답글 대상의 선택은 읽음 처리와 분리한다. 날짜 이름의 옛 범례 상수는 제거하되 무조건 적용되던 allowed 본문 맥락은 결과 불변 지시대로 보존한다.

아직 최종 완료 근거가 아니다. 초기 전체 검사의 gate/수락 236개는 통과했으나 앱의 연결 전 아일랜드 오류 표시 누락과 마지막 방 숨김 뒤 선택 재생성 회귀를 발견해 수정했다. 그 실행은 최종 통과로 쓰지 않는다. 새 기본 진입 시험에는 앞 경우에서 남긴 초안이 있어 자동 기본값보다 복원이 우선됐으며, 빈 자리를 남기는 준비로 바로잡았다. 기대값은 바꾸지 않았다. 현재 소스의 최종 전체·반복·돌연변이·같은 상태 캡처·개인값 검사는 계속 진행한다. 실제 명령/종료와 미완료는 추적하지 않는 .build/task37/checkpoint.json 및 로그에서 대조한다. 운영 자료·앱 사본·공용 릴리스·public·원격은 변경하지 않았다.


## TASK-37 최종 구현·자체 시험 — 보완 51·38

- **기준·책임 자리:** 부모는 f1dbde24efa1b136212864b11f9a712989b0b105다. 기존 독해/진행 기록을 보존했다. 대상·초안·실패·확인 전 글은 기존 ConversationController 메모리, 확정 글은 기존 기록장 복제본, 읽음은 MemberState다. 새 영구 원본·규격·문·Hermes 본체 변경은 없다.
- **B01~06:** 홈을 제외한 기본 답글은 최근 활동 스레드의 직원 첫 글로 정한다. 명시적 답글도 최근 활동을 기준으로 고르며, 새 글 모드라도 열린 작업 스레드로 보낸다. auto/new/thread 초안 자리는 연결별 메모리에 남기고 실제 새 글 UUID와 구분한다. 사라진 대상의 초안은 방의 현재 자리로 옮긴다. 자동 대상 변경은 종이 울린 요청을 읽음 처리하지 않고 명시적 누름만 읽는다.
- **전송·실패:** pending을 실제 카드에 0.6 흐림·“보내는 중”으로 먼저 보이며 작성기를 즉시 비운다. 확인은 그 글만 교체하고 후속 입력을 지우지 않는다. 실패는 원래 주소·방·자리·글·파일·얼굴을 보존한다. 되살리기는 원래 방 확인 후 정확한 자리에 합친다. 새 글/홈 글의 늦은 거절, 다른 방에서의 명시적 재전송, 재접속 뒤 확인 없는 글 보존을 실제 루프백으로 검증했다. 자동 재전송은 없다. 전송 중 표시는 현재 연결의 실제 pending으로 계산해 새 글 UUID·다른 방 보기에도 맞춘다.
- **B07~18:** queue 직원의 끼어들기 표시는 생략한다. 표시는 답들 뒤·작업 줄 앞의 왼쪽이다. 홈 “새 대화”·빈칸 안내·실패 문구, 원본 모드 선택/접근성, 얼굴 24pt+각4pt·2pt 간격·가로 스크롤, 홈의 개별 단추·30pt 고리·0.5 흐림·0.24초 전환(동작 줄이기는 즉시)을 연결했다. 파일은 모두 크기를 확인한 뒤 하나씩 읽고 이름 있는 오류를 보인다. 고르기 창 문구/첨부 버튼/modalPanel/기본 저장 폴더와 고르는 동안 대화 접힘 방지를 연결했다. 첨부 50MiB·통신 64KiB·고정 채널/대표 직원 계약은 유지한다.
- **원본 대조 판단:** B05의 replyInterrupted 생산자는 별도 Hermes 기록 보기의 SQL이고 Slack 방 경로는 기본 false다. 기존 그리기는 보존하고 새 wire 이벤트나 추정을 만들지 않았다. N36-01은 날짜 분기·상수를 지우되 실제로 날짜와 무관한 allowed 범례 본문을 유지한다. 원본/제품 분리 실행 compile/run 각각 0, valid-date 범례 판정 true/true다(`policy-probe.json`, `policy-comparison.json`). 자세한 근거는 copy-review에 이어 적었다.
- **최종 전체·반복:** `python3 .build/task37/frozen.py` 종료 0. foundation9_runner hejo는 236 passed(test_install 포함), 앱 전체 단위 시험·기존 통신 시나리오·AT-88 실제 루프백을 통과했다. 이어 같은 빌드의 TASK-37 앱 집중 시험과 다섯 전송 경우(delay/reject/unconfirmed/new-reject/home-reject)를 세 차례 반복해 모두 종료 0이다. 앱 전체를 세 번 반복했다고 세지 않는다. 전체 1행+집중3행 모두 inputsUnchanged=true, 입력 164개 불변. `frozen-progress.json`, `final-foundation.log`, `app-focused-01.log`~`03.log`.
- **실패 후 처리:** 초기 아일랜드 연결 전 오류·마지막 방 숨김·다른 방 재전송 표시 회귀를 제품 책임 자리에서 수정했다. 기존 AT55 재전송 단정은 유지했다. queue 표시 단정만 B07 원문대로 바꾸고, WorkspaceTests는 고정 초안 UUID 대신 실제 확인 글의 UUID를 얻도록 준비를 바꿨다. 캡처 연결이 빈 방 읽음을 먼저 seed하던 준비 문제는 최초 빈 명부로 연결한 뒤 합성 이력을 넣도록 고쳤으며, 그 최종 시험 파일까지 포함해 전체/반복을 다시 완료했다. 옛 실패·이전 통과 로그는 first-full/second-full/third-full-failure/pre-capture-fixture-final에 보존하며 최종 통과와 구분한다.
- **돌연변이:** 새 글에 고정 초안 UUID를 그대로 보내도록 바꾼 임시 소스는 compile 0·시험 1로 `AT88 new-post draft place stays fixed while wire gets a separate UUID`에 걸렸다. 정상 경로는 최종 전체/반복 0이고 원본 소스는 불변이다. `mutation.json`, `mutation-new-place.log`.
- **화면·N36-02·서명:** `post_checks.py` 종료 0. 최종 빌드의 TASK-36 PNG는 실제 연결(canSend=true)로 교체했다. TASK-37은 같은 가짜 상태의 원본 조각과 실제 AppKit 카드/작성기 줄을 비교한다. 유효한 620×560 한 개·620×240 두 개·592×36 두 개를 직접 표시 확인했다. 제품 줄의 투명 배경은 흰 캔버스로 source-over 내보냈으며 내용/기하 보정은 없다. 선택 캡슐의 SwiftUI 비활성 농도와 끝 여백 2pt 차이를 TASK-37.md에 명시했다. 운영 앱 전체·픽셀 동일 비교가 아니다. codesign --verify --deep --strict도 0이다. `post-checks.json`, `capture-product.json`, `reference.json`, `image-check.json`.
- **수준·금지 보존·인계:** 필요/도달 수준은 2/2다. 물리 입력기·실제 서버·두 Mac 결합은 운영 수락에 남는다. public f716bdf·운영 홈·앱 사본·공용 릴리스·본체·ddots·운영 저장소·원격을 바꾸지 않았고 GitHub 조회·push·실제 발송·비밀 파일 열기/키 출력은 없다. 최종 보고 뒤 개인값/훅/diff 검사와 소유 파일만 git commit --only를 수행한다. 실제 전체 커밋·파일 범위·입력/캡처 일치·깨끗한 main은 `final-checks.json`, `commit-result.json`, `final-verification.json`에 기록한다. TASK-38 이후는 계획 담당 검토 뒤 진행한다.


## TASK-38 — 구현·자체검증 결과(보완 38·52)

기준 7c8e953에서 기존 SidebarLayout·ConversationModel/MemberState·ConversationView의 투영을 확장한다. 화면 임시 행(검색·틈·글 결과)과 구획별 CAShapeLayer는 조회용이며 새 영구 원본이 아니다. NSTableView 안정 id 차이 갱신을 넣고 직접 reloadData 경로를 제거했다. 접힌 구획의 사진/얼굴·메뉴 사진 항목과 별도 검색 결과 패널을 원본 자리에서 대체했다. 원본 독해와 유지 차이는 copy-review의 TASK-38 표에 있다. 구현과 아래 자체 검증을 마쳤으며 최종 판정은 계획 담당 검토로 넘긴다. 운영 홈·공용 릴리스·앱 사본·본체·ddots·원격·public은 변경하지 않았다.


최종 변경은 작성기/전송 원본을 늘리지 않고 관제 화면의 사이드바 자리에서 마쳤다. 글자·얼굴·핀/종·수·구획/레일/선/끌기 강조·맨 아래 띠·검색칸과 글 결과·메뉴/대화상자를 원문 값으로 옮겼다. 구획의 얼굴/사진·사진 메뉴, 홈의 직원 제외 메뉴, 빈 곳 메뉴, 1:1의 대체된 메뉴와 별도 검색 결과 패널은 제거했다. 1:1 사진·대표/직원 빼기·기본 받을 직원·DM 이름·로고는 사장 계약을 유지한다. 고정 홈은 기존 허브 배치에서 그 방의 숨김/알림 끔을 풀고 일반 목록에서 제외하며, 사진 없는 선택 방에 기본 홈 사진을 빌려 주지 않는다. 새 기록 종류·wire·영구 원본·문 변경은 없다.

행 차이는 안정 id의 NSTableView insert/remove(effectFade)/move로 처리한다. 직접 reloadData 호출은 0이다. 구획마다 연속 CAShapeLayer 하나를 두고 같은 0.24 easeInEaseOut로 레일·색을 보간한다. 선택은 두 셀의 opacity spring(response 0.34, damping 0.88)이며 위치를 건너 움직이지 않는다. 동작 줄이기는 즉시다. 화면에 보이는 행의 presentation 좌표를 클릭/메뉴/끌기 대상으로 쓰며, 전환을 거꾸로 바꿔도 기존 셀과 현재 위치를 재사용한다.

검증 변경본은 최종 verification-inputs.json의 166개 입력이다. python3 .build/task38/frozen.py 종료 0: foundation9_runner hejo 236 passed(test_install 포함), 앱 전체·기존 통신 시험 통과, AT-89를 3회 반복해 모두 종료 0·입력 불변. 로그는 .build/task38/frozen-progress.json, final-foundation.log, app-focused-01.log~03.log다. 중간 옛 시험 실패 2건과 소스 대조 보강을 위한 미완료 실행은 별도 로그로 보존했으며 최종 통과 근거에 섞지 않았다. 이전 직원 제외 준비는 실제 한 명 명부로, 보관 복원 준비는 고정 홈이 아닌 일반 방으로 바꿔 각 본래 기능 단정을 유지했다.

python3 .build/task38/mutation.py compile/verify 각각 종료 0. 같은 소스의 baseline은 0, insertRows를 slideDown으로 바꾼 임시 사본은 컴파일 0·시험 1로 ‘AT89 inserted row fades at final y without slide or clipping’에 검출됐다. 원본 입력은 불변이다(.build/task38/mutation.json).

python3 .build/task38/post_checks.py 종료 0. 최종 빌드의 실제 가짜 루프백 연결 캡처·원본 분리 그리기·PNG 유효성/전체 픽셀 불투명/내용 검사·codesign --verify --deep --strict 모두 0이다. 화면은 evidence/HEJO-FOUNDATION/TASK-38.md와 8개 PNG다. 필요한/도달 증거 수준은 2/2다. 원본과 정적 행/얼굴/표식/선택/레일/띠 배치를 직접 비교했으며 네이티브 글꼴 획과 강조색의 최종 합성 농도 차이는 남는다. 픽셀 동일성·운영 앱 전체 비교를 주장하지 않는다. 원본 검색 TextField의 정적 대체 범위는 화면 문서와 copy-review에 명시했다. 물리 입력기·VoiceOver 실사용·실제 서버·두 Mac 결합은 운영 수락에 남는다.

이 결과 뒤 개인값 검사·pre-commit·diff와 소유 파일만의 git commit --only, 커밋/검증 입력/PNG 지문·깨끗한 main·고정 public 대조를 진행하며 실제 커밋은 .build/task38/commit-result.json과 final-verification.json에 남긴다. 앱 사본/공용 릴리스/public/운영 홈/운영 저장소/본체/ddots 변경, 실제 발송, 비밀 파일 열기, GitHub 조회/쓰기와 push는 하지 않았다. TASK-39 이후는 미착수다.


## TASK-39 1차: D39-01로 보류

- 목표: 보완 38·52·53의 카드·글·파일 이식(REQ-HF-36.AC-04, AT-90), N37-01·N38-01 포함. 기존 카드 엔진·기록장·회원 상태를 재사용하고 새 영구 원본을 두지 않는 범위다.
- 발견: 대조표 D11의 삭제된 사진/파일은 ddots가 Slack의 명시 tombstone/is_deleted를 읽어서 표시한다. hejo wire file에는 해당 정보가 없고 추가 필드는 스키마에 거절된다. 미등록 첨부와 기록 뒤 파일 유실은 같은 404이며, 후자는 기존 message 파일 정보가 page에 그대로 남는다. 스레드 삭제는 글 전체를 delete로 치환한다. 추정으로 삭제 상태를 만들면 파일 소실·권한 문제를 삭제로 오인할 수 있다.
- 판단 요청: (권고) D11의 명시 삭제 표식은 현재 hejo에 생산자가 없음을 기록하고 적용 범위를 정한다. 또는 계획 담당이 파일 삭제 표식의 생산·재현·보안 계약을 따로 승인한다. 실행 담당은 wire·문·기록장을 바꾸지 않았다.
- 실제 변경: 제품 초안 4개를 로컬 `.build/task39/draft/`에 보존(팔레트·링크/스트림 표시·얼굴 바탕·본문 분할)하고 제품은 착수 HEAD로 복구했다. 추적 변경은 이 보고와 copy-review뿐이다. N37-01·N38-01 포함 나머지 구현은 미완료다.
- 검증: 임시 HERMES_HOME의 실제 문·HTTP·기록장·스키마 경계 시험 1건 통과. 삭제 표식 거절·404 동일·유실 뒤 page 불변·스레드 삭제 시 글 전체 치환을 확인했다. 전체 foundation/test_install·앱 반복·돌연변이·유효한 원본/제품 캡처 비교·제품 커밋은 미실행이다. 필요 증거 수준 2, 전체 도달 수준 1. 이번 경계 재현이 AT-90 완료 근거는 아니다. 로그는 로컬 `.build/foundation9-task39-file-boundary.log`, `.build/task39/file-boundary.json`.
- 미수행: 운영 홈·앱 사본·공용 릴리스·본체·ddots·운영 저장소·원격 변경, GitHub 조회, push, 실제 발송, 비밀 파일 열기. public 후보는 그대로다. 계획 담당이 D39-01을 정한 뒤 같은 TASK를 재개한다.


## TASK-39 최종 구현·자체 검증

- 기준은 보완 54·53·52·38과 대조표 §D·2.1판 정정이다. 부모는 `d7d12f9f5490b35748dcab0ff81b86f08efe337e`. D39-01 보류 기록을 보존하고 승인된 제외를 적용했다. wire·문·기록장·새 영구 원본 변경은 없다. 기존 Model/Controller·NativeThreadCard·TextLayout·MemberState를 재사용했다.
- 카드 내용 조립을 글 머리→답 단추→자세한 내용으로 맞추고 분기·삭제 조건, quiet/accent/orange/red, 복사 머리 #/@·접근성 이름·단추 줄 누름 차단, 날짜·빈 방·불러오는 중 줄, 인용 색·자동 링크·obsidian·대비 계산을 연결했다.
- 파일 타일·실제 404 실패·비율 유지 확대/중앙 정렬·크기/PDF·처리 중/손 커서, 별도 빼기 단추인 첨부 칩, 오른쪽 칸 전체 끌기 강조·Divider·info 안내·작성기 안 실패/보러 가기, 넓음/좁음 체크리스트를 native 보기로 옮겼다. AppKit 제어의 미세한 베젤·기준선 차이는 화면 문서에 명시했다.
- 작업 중 얼굴 34·이름/접근성·생각 중, 두 줄 활동/quiet/1.8초 shimmer·중지/되돌리기, 표시 전용 StreamReveal·uniformSize·최종 본문의 bounded reveal·따라 읽던 답 펼침 유지·6pt 행 높이 양보를 연결했다. 별도 작성 중 1.6초와 커서는 보존했다. 사진 얼굴 바탕 색을 제거했다.
- N37-01 카드 단추와 N38-01 그림 intrinsic 크기·quiet·방 추가 8pt 간격을 같은 변경에 포함했다. 기존 시험의 대체된 보기 구조·시간/스트림 가정만 copy-review의 원문 근거대로 갱신하고 전송·초안·커서·체크리스트 단언은 유지했다. AT-90 문서는 승인된 D04·404 정정만 반영했다.
- 변경 자리는 app/Sources의 기존 보기·Controller와 표시 계산용 CardRendering.swift, 앱 회귀/수락 시험, 공식 AT-90 정정, copy-review/이 보고, evidence/HEJO-FOUNDATION/TASK-39.md와 PNG다. TASK-40 이후는 미착수이며 tasks.md 판정은 계획 담당이 갱신한다.

검증 결과(최종 고정 입력):

- `python3 .build/task39/frozen.py` 종료 0. 내부 `foundation9_runner.py hejo` 종료 0, 236 passed(test_install 포함)·앱 전체·통신 시나리오 통과. AT-90 앱 집중 3회 모두 종료 0·inputsUnchanged=true, 검증 입력 168개 불변. `.build/task39/frozen-progress.json`, `final-foundation.log`, `app-focused-01.log`~`03.log`.
- `mutation.py compile`·`verify` 종료 0. 삭제 대상 조건을 제거한 사본은 컴파일 0·시험 1로 “AT90 no replies deletes only my post”에 검출, 정상 사본 0·제품 입력 불변. `.build/task39/mutation.json`.
- `post_checks.py` 종료 0. 최종 빌드의 실제 가짜 루프백 연결 캡처·404 실패·원본 분리 실행·사이드바 보완 비교·PNG 8개 유효성·`codesign --verify --deep --strict` 각각 0. `.build/task39/post-checks.json`, `image-validation.log`, `static.json`. 원본 파일 불변·새 SwiftUI import 0·gate/schema 변경 0. 그림은 직접 표시해 비교했다.
- 첫 appearance 중복 컴파일, 이전 시간/실패 줄 단정 실패, 사진 비율 마지막 보정 이전 실행은 `intermediate-*`에 보존하고 최종 통과와 구분했다. 삭제 표식 계약 경계 재현은 기존 기록을 재사용했다.

필요/도달 인계 증거 수준은 2/2다. 캡처는 가짜 연결 상태의 실제 AppKit 조립과 원본 함수 분리 비교이며 원본/운영 앱 전체·픽셀 동일 비교가 아니다. 실제 서버·두 Mac·물리 입력기·VoiceOver·운영 수락은 남는다. 최종 보고 추가 뒤 개인값·HEJO_PYTHON 지정 훅·diff 검사를 하고 소유 파일만 별도 git commit --only로 기록한다. 실제 커밋·입력·그림 바이트 대조와 깨끗한 main 확인은 `.build/task39/final-verification.json`에 둔다. public 후보 `f716bdff38af3d8c2cb2cdf4502e080ecbecb2bc`는 유지한다. 운영 홈·앱 사본·공용 릴리스·운영 저장소·본체·ddots·원격 변경, GitHub 조회·push·실제 발송·비밀 파일 열기는 하지 않았다.


## TASK-40 최종 구현·자체 검증

- 받은 기준: 보완 38·55와 대조표 §E·V07·V15, 2.1판 E09·E14~17. 부모는 `2ab15395d537a074804f29237a34dcfaecf1b24c`. 일반 작업, 필요 증거 수준 2, 자체 구현·시험이며 최종 판정은 계획 담당에게 맡긴다. 하위 에이전트는 쓰지 않았다.
- 기존 NativeThreadList의 무조건 마지막 행 이동을 가운데/끝 요청·120pt 바닥 따라가기·glide·keep·입력 취소로 교체했다. 0/0.15/0.45 요청과 0/0.06/0.2/0.4 보존 재관찰은 입력/요청 세대가 바뀌면 폐기한다. 휠 중 최신 표시 갱신은 0.25초, 연속 입력은 최대 2초까지 미룬다. 방 재진입은 가장 최근 활동으로 가고 크기 변경은 행 id/offset 또는 바닥을 보존한다. 기록·통신·읽음 원본은 그대로다.
- flash는 accent 2·본문 0.18·둥근 8, 원래 1.6초/아일랜드 1.5초다. 검색어는 이 타이머와 분리해 해당 스레드를 접을 때까지 남긴다. 알림 막대 가로 스크롤·툴팁/접근성·quiet 화살표·위쪽 이동/opacity 0.24를 연결했다. A17 개수는 스레드당 하나인 기존 notices의 대표 글 수를 재사용한다.
- 머리줄 오른쪽 단추 두 개를 없애고 기존 메뉴·⌘F로 연결했다. 홈 제목 2.1판 순서·단체방 기본 설명·끌기/문맥 메뉴 도움말, 평평한 검색 줄·닫기·첫 글 14 medium·실제 speaker·@/#/홈 이름·파일 노트 paperclip을 적용했다. 테마가 바뀌면 보조 글자/그림과 검색 상자 색도 다시 계산한다.
- 모드 선택 색·바탕과 칩·알림은 같은 easeInOut 0.24, 홈 얼굴은 기존 ComposerFaces의 0.24를 재사용했다. 기존 PetController가 창 높이를 τ0.065로 추종한다. 더 보기 전 실측 높이·창 높이를 잠시 보유하고 늘어난 높이만 합산하며 접거나 수동 크기 조절하면 해제한다. 새 영구 원본·wire·문·기록장 변경은 없다. 날짜 비교는 기존 ThreadTools의 두 ISO 파서 자원만 잠금 아래 재사용하고, 표시 갱신 안의 알림 조회 결과는 한 번만 계산한다. 기존 fractional/whole/실패 결과를 동시 호출로 대조했으며 날짜 값 캐시는 없다.
- N39-01은 원본 bordered 실제 크기와 비교해 native regular 버튼의 글꼴·intrinsic 폭·fixedSize를 적용했다. 원문 12pt 환경이 macOS bordered 기본 제어에서 실제 13pt/61×24·47×24·69×24가 되는 실측 근거와 차이는 copy-review에 있다. AT-90에 실제 항목·작성·건너뛰기 치수 단언을 추가했다.
- 추가 시험은 ScrollTests.swift(AT-91)에 실제 native clip 좌표·중간 프레임·취소·지연·따라가기·자리 보존·요청 수·검색 강조/테마·모드/칩·긴 글/창 높이를 관찰한다. 수락 문서를 바꾸지 않았다. IslandTests의 옛 2.5pt 강조 단언은 명시적 V15 대체에 따라 2pt와 accent 결합 검사로 교체했으며 그 밖 단언은 유지했다.

검증 결과(최종 고정 입력):
- `python3 .build/task40/frozen.py` 종료 0. 내부 `foundation9_runner.py hejo` 종료 0, 236 passed(test_install 포함), 앱 전체·통신 시험 통과. AT-91 집중 3회 모두 0·inputsUnchanged=true. 검증 입력 169개 불변. `.build/task40/frozen-progress.json`, `final-foundation.log`, `app-focused-01.log`~`03.log`.
- `mutation.py compile`·`verify` 종료 0. 가운데 이동을 바닥 이동으로 되돌린 사본은 컴파일 0·시험 1로 “AT91 jump centers the thread”에 검출, 정상 사본 0·제품 입력 불변. `.build/task40/mutation.json`.
- `post_checks.py` 종료 0. 실제 가짜 루프백 연결의 최종 빌드 캡처·원본 함수 분리 실행·원본 glideStep/native 좌표 대조·PNG 10개 유효성·codesign deep strict 각각 0. `.build/task40/post-checks.json`, `scroll-comparison.json`, `image-validation.log`, `static.json`. 원본 불변·추가 SwiftUI import 0·gate/schema 변경 0. 그림은 라이트/다크로 직접 비교했다.
- `event_probe.py` 종료 0. 같은 제품 소스의 실제 AppKit Space/화살표/Home/End/Page 키 9종·클릭·휠 진입 경로가 예약된 먼 이동을 취소했다. 휠의 실제 10pt 이동(30→20)은 유지됐다. `.build/task40/event-results.json`, `event-run.log`.
- 단독 단체방 루프백의 지연은 단계 로그·프로세스 sample로 날짜 파서 반복 생성에 좁혔고, 수정 뒤 기존 8초/90초 기준으로 13개 전송 경우가 통과했다. `.build/task40/room-probe-result.json`, `room-probe-run.log`.
- 앞선 집중 시도의 시험 초기 상태 오류·중간 렌더·테마 색 수정 전 중단 전체는 최종 근거가 아니다. 마지막 고정 소스의 위 결과만 인계한다. 운영 앱 전체·픽셀 동일 비교는 아니다. 원본 ScrollView는 ImageRenderer에 빈 화면이 나와 정적 같은 내용 틀로 바꾸고 TextField만 정적 글자로 대체했다. hejo 왼쪽 목록/아일랜드/작성기와 원본의 비교 대상 범위 차이, native 제어의 기준선·높이 차이는 evidence/HEJO-FOUNDATION/TASK-40.md에 명시했다.

필요/도달 인계 증거 수준은 2/2다. 실제 서버·두 Mac·손 트랙패드/물리 한글 입력·VoiceOver와 운영 결합은 TASK-23에 남는다. TASK-41 이후는 미착수다. 최종 보고 추가 뒤 개인값·HEJO_PYTHON 훅·diff 검사, 소유 파일 git commit --only, 커밋 입력·그림 바이트 대조를 수행하고 실제 커밋은 `.build/task40/final-verification.json`에 둔다. public `f716bdff38af3d8c2cb2cdf4502e080ecbecb2bc`는 불변이다. 운영 홈·앱 사본·공용 릴리스·운영 저장소·Hermes 본체·ddots·원격 변경, GitHub 조회·push·실제 발송·비밀 파일 접근은 없다.


## TASK-41 최종 구현·자체 검증

보완 38·56의 §F·V08·V10·V14 및 F05·F06·F20~25, N40-01을 기존 AppKit 책임 자리에서 구현했다. PetController의 단일 배치에 원본 PetBubbleMotion을 연결하고 높이 추종도 합쳤다. 머리줄 끌기는 dragged(by:)와 재배치 보류로 높이를 유지하며 펫 끌기와 구별한다. 지니 흐림/바탕 합성·현재 진행도 반전·0.3 폭/0.06 덮개·0.8 추종, 커서·초기화·층·위치와 화면 변경을 연결했다.

유리 말풍선·3초 표면/12초 내용·0.18 페이드·hoverArmed·승인 유지·버튼/문구·홈 행동·걷기·Zzz·졸기, 키 창/작성기·말풍선 대상·접기 정리·한글 키코드/조합 Esc·편집 메뉴·접근성을 연결했다. 실패 알림은 제거하고 인라인 답 실패의 기존 대상/초안/문제 줄은 보존했다. 검색 공용 강조는 systemYellow다. 새 영구 원본·wire·문·기록장·SwiftUI import는 없다. 대체된 옛 단정의 원문 근거는 copy-review에 적었다.

최종 검증(입력 170개):

- `python3 .build/task41/frozen.py` 종료 0. foundation9_runner hejo 236 passed(test_install 포함), 앱 전체/통신 통과. AT-92 세 번 모두 종료 0·inputsUnchanged=true. 로그 frozen-progress.json·final-foundation.log·app-focused-01~03.log.
- `mutation.py compile`·`verify` 각각 종료 0. 반전 때 현재 진행도를 버리는 사본은 compile 0·시험 1, 정상 사본 0으로 검출했다. 원본 입력 불변. mutation.json.
- `post_checks.py` 종료 0. 최종 고정 제품 입력의 native 보기 조립 캡처·원본 조각 실행·4개 PNG 유효성·독립 수치 대조·codesign deep/strict 통과, 원본 지문 불변·gate/schema 변경 0. 원시 캡처의 외관 범위 오류를 별도 조립으로 보완했고 제품 입력은 불변이다. 그림을 직접 표시해 비교했다. post-checks.json·image-check.json·motion-comparison.json.
- 첫 전체 실행은 AT-92까지 통과 후 N40-01로 바뀐 공용 색을 옛 AT-78이 기대해 실패했다. 원문상 명시된 색 단정과 머리줄 재배치 보류를 더한 뒤 새 입력으로 검증했다. 숨김 억제 뒤 창을 다시 보이는 초기 프레임의 AT-82 실패도 확인해 창 수명 경계에서 갱신했고, 그 hover/포커스 단언은 보존했다. 마지막 배지 숨김의 가짜 시계도 3초 기한 이후로 옮겼다. 이전 행/지문/로그는 intermediate-before-color-guard·intermediate-before-bubble-show·intermediate-before-pop-clock에 보존했다.

필요/도달 증거 수준은 2/2다. 화면은 동일 합성 상태의 원본 함수/실제 AppKit 조립 비교이며 운영 앱 전체·실제 두 Mac 검증이 아니다. 보완 조립은 `python3 .build/task41/native_capture.py` compile/run 0(`native-capture.json`), 단추 바탕 라이트/다크 표본은 원본과 같음(`capsule-colors.json`)을 확인했다. 실제 서버·입력기·VoiceOver·다중 화면 실물은 운영 수락에 남는다. evidence/HEJO-FOUNDATION/TASK-41.md와 PNG에 범위를 명시했다. 최종 보고 뒤 개인값·HEJO_PYTHON 훅·diff 검사와 소유 파일 git commit --only 및 커밋/입력/그림 바이트 검증을 한다. 그 실제 커밋과 결과는 .build/task41/final-verification.json에 둔다. tasks.md 판정은 계획 담당이 갱신하며 TASK-42 이후는 미착수다. public f716bdf는 고정했다. 운영 홈·앱 사본·공용 릴리스·운영 저장소·본체·ddots·원격 변경, GitHub 조회·push·실제 발송·비밀 파일 열기는 하지 않았다.

## 구현 인계: TASK-42 설정·메뉴·대기 동기화

1. 받은 설계: handoff 보완 38·42(N35-01), 대조표 §G·V11 및 2.1판 G04/G09/G11~G13, REQ-HF-36.AC-07·AT-93. 기준 `cd6db146cb4b286d20b2e5c036e4fd6207bc947f`. 일반 위험, 필요 증거 수준 2, 임시 홈·가짜 명부·루프백만 사용했다.
2. 구현자 판단: 구현 완료(자체 판단), 계획 담당 검토 대기. tasks의 대기 표시는 검토자가 갱신한다.
3. 책임 배치: 기존 PetSettingsWindow·AppDelegate가 설정과 메뉴를, PetController/PetView가 일시적 미리보기를 맡는다. 기존 MemberState 복제본·outbox와 HubClient·hub/server.py가 동기화를 맡으며 새 영구 원본·상태 키를 만들지 않았다.
4. 추가/제거: 620 폭·탭별 스크롤·화면 맞춤·이름 검사·연속 크기·로그인 상태/실패 문구·고급 두 미리보기·실패 때만 요청문 복사·고정 채널 팝업·동기화 결과 창을 연결했다. 작업 목록/내 캘린더 메뉴는 후속 TASK 자리로 비활성 상태다. 연결 창 760×560/최소 760×500·활성 앱 층과 테마, 쉬기 중 화면 전달 보류/재개를 연결했다. 조용한 이름 자름·고정 네 탭·늘 보이는 로그인 설정 단추·등록 실패 경고창을 대체했다. 클립보드·끌어놓기 탭은 넣지 않았다.
5. 설계 차이: 2.1판과 원문 코드 우선 사항은 copy-review에 적었다. N35-01 단언 추가는 명시 인계 범위다. 통신 프레임·문·기록장은 바꾸지 않았다.
6. 호환: 새 wait GET은 `X-Hejo-State-Wait: 1`로 지원을 알리고 25초 뒤 빈 상태를 돌려준다. 옛 앱의 since GET/PATCH는 그대로다. 옛 허브는 wait 쿼리를 무시하므로 한 번 받은 뒤 기존 30초 받기를 쓴다. 새 허브에서는 대기 요청 하나만 유지하고 30초 경로를 끈다. 보내기는 기존 outbox에 1.5초 묶음이며 진행 중인 PATCH와 겹치지 않는다. 늦은 낮은 rev 응답은 최신 복제본을 되돌리지 않는다.
7. 변경 성격: 승인된 의미 변경이다. 미리보기는 동작 9개·방향 2개 각 2초, 졸기는 dozeCycle, 시선은 15초다. 쉼은 문 연결·캐시를 유지하고 화면 전달과 작업 소비만 멈춘다.
8. 시험: SettingsTests는 실제 native controls의 오류·스크롤·크기·팝업·복사·미리보기·쉼을, 실제 HubClient 요청 대역은 wait 쿼리/인증/지원 헤더를, 지연 네트워크 대역은 송신 묶음/중복 요청 없음/낮은 rev/옛 허브를 보호한다. test_state_wait.py 8개는 실제 임시 허브 HTTP에서 회원 격리·변경 즉시 깨우기·25초 기본/빈 응답·옛 GET·잘못된 요청/인증·종료를 보호한다. 알림 깨우기 제거 돌연변이는 정상 0·변형 1로 검출했다.
9. 최종 검증: `.build/task42/frozen.py` 종료 0, foundation9_runner hejo 244 passed(test_install 포함), 앱 전체와 기존 통신 시험 종료 0. AT-93 집중 3회 모두 0·입력 180개 불변. `.build/task42/mutation.py` 종료 0, 원본 불변. `.build/task42/capture.py` 및 post_checks.py 종료 0, 유효 PNG 8개 직접 비교·4쌍 바이트 일치·codesign deep/strict 통과. 상세는 frozen-progress.json, final-foundation.log, mutation.json, capture.json, post-checks.json, image-check.json에 있다. Swift 5 빌드의 actor 격리·SDK deprecated 경고는 원 로그에 남겼다. 개인값·훅·diff 최종 결과는 아래 최종 기록과 final-checks.json을 따른다.
10. 미검증: 실제 로그인 항목 등록, 운영 허브/서버, 두 Mac, 물리 입력기와 VoiceOver. 필요/도달 증거 수준 2/2이며 화면은 원본 분리와 제품 AppKit 페이지 조립이다. 운영 앱 전체 비교가 아니다.
11. 중간 실패: 시험 자원 경로의 실행 위치 가정과 가짜 허브의 응답/저장 판 번호 불일치를 고쳤다. 기존 단언은 완화하지 않았다. 앞 실행은 intermediate-resource-path·intermediate-fixture-revision에 보존했다. 초기 빈 캡처는 intermediate-capture에 격리했고 창/탭 수명·외관·레이아웃을 보장한 최종 그림만 증거로 썼다.
12. 검토 요청: 대기 지원 선언/옛 허브 분기·rev 경합·쉼의 화면 전달 경계·이름 조합 보호와 N35-01 조건을 봐 달라. 운영 적용·공용 릴리스/앱 사본·public/원격·본체/ddots 변경은 없다.
13. 검토 코드: main의 TASK-42 소유 파일 별도 commit-only 결과는 `.build/task42/commit-result.json`, 입력/그림 일치 및 깨끗한 작업 트리 확인은 final-verification.json이다. TASK-43 이후는 미착수다.

### TASK-42 최종 정적 검사

개인값 검사·HEJO_PYTHON 지정 pre-commit·diff는 각각 종료 0이다. 최종 owned 목록은 29개이며 commit-only 대상 목록을 `.build/task42/owned-files.json`에 남겼다. 서명 검증·PNG 직접 비교·검증 입력 불변은 post-checks.json에서 확인했다. 커밋 뒤 verify가 기록한 실제 전체 커밋을 계획 담당에게 인계한다.


## 구현 인계: TASK-43 대화창 모양·N42-01 대기 경합

1. 받은 설계: 보완 38·57, 대조표 H01과 2.1판 정정, REQ-HF-38·AT-94. 기준 e7cfa7ae219d3a9ab6be7247b93bf54f19c00caa. 일반 위험, 필요 증거 수준 2, 임시 홈·가짜 명부·루프백만 썼다.
2. 구현자 판단: 구현·자체 검증 완료, 계획 담당 검토 대기. tasks의 판정은 검토자가 갱신한다.
3. 책임 배치: LocalStore의 기존 hejo-local.json에 선택 필드 네 개만 더했다. ChatAppearance는 그 원본의 읽기·원자적 쓰기 투영이며 별도 복제 저장소가 아니다. PetSettingsWindow의 기존 화면과 펫 탭에 AppKit 모양 묶음을 넣었다. PetController·ConversationView·ConnectionsWindow가 자기 창/내용을 갱신하며 NativeThreadList의 기존 높이 계산을 재사용한다.
4. 화면: 시스템 설정/라이트/다크, 55~100 불투명도(기본 65), 글씨 12·13·14·15·16·18·20(기본 14), 내 말풍선 14색·대비 글자·미리보기·기본값으로를 연결했다. 대화창 크기 초기화는 모양 묶음으로 옮겼다. 투명도 줄이기면 불투명이다. 설정 창 자체는 시스템 모양을 유지한다. 원본의 사용되지 않는 양 끝 불투명도 문구는 넣지 않았다.
5. 변경 성격: 승인된 의미 변경이다. 모양은 허브 회원 상태/outbox에 보내지 않는다. 작성기는 마지막 표시 기본 크기로 초안을 직렬화하고 한글 조합 중 내용 교체를 보류한다. 카드의 기존 내용도 글씨 변경 즉시 다시 측정한다. 새 SwiftUI import·문·wire·기록장 변경은 없다. 대체한 고정 14pt·65% 소비는 지웠으며 범위 밖 부채를 새로 발견하지 않았다. 기존 연결 창의 승인된 SwiftUI는 유지한다.
6. N42-01: 회원별 공유 Event를 요청별 Future 집합으로 바꿨다. 읽기 전 등록, PATCH 때 등록된 대기 모두 깨우기, 취소/종료 때 정리를 구현했다. GET/PATCH·지원 헤더·옛 앱/허브 계약은 그대로다. 운영 허브에는 적용하지 않았다. AppKit 미리보기는 승인된 네이티브 이식이며 새 SwiftUI 예외가 아니다. 투명도 정책 주입은 실제 시스템 설정을 바꾸지 않고 같은 유리 계산을 검사하는 격리 목적이다. 하위 에이전트는 쓰지 않았다.
7. 자동 시험: 실제 native controls를 눌러 테마 창 반영·세 불투명도·접근성 투명도 정책·7단계 글씨/기존 카드 높이·14색 실제 본문 대비·다시 읽은 로컬 파일·회원 상태 불변·기본값·한글 조합을 단언했다. N42-01은 PATCH와 뒤 대기가 앞 대기의 알림을 지우는 순서를 실제 임시 허브 HTTP에서 만든 뒤 1초 안 새 rev를 받는지 검사한다.
8. 최종 검증: python3 .build/task43/frozen.py 종료 0, foundation9_runner hejo 245 passed(test_install·허브 시험 포함), 앱 전체·기존 통신 시험 통과. AT-94 집중 3회 모두 0·inputsUnchanged=true, 입력 184개 불변. frozen-progress.json·final-foundation.log·app-focused-01~03.log. mutation.py 종료 0: 정상 0, 옛 공유 Event 사본은 1초 경합 단언으로 종료 1, 원본 불변. mutation.json.
9. 화면·서명: capture.py·post_checks.py 종료 0. 원본 SettingsPages/ChatStyle/BubbleOpacity 분리와 제품 AppKit 모양 묶음의 세 테마 PNG 여섯 개를 직접 확인했다. 미리보기 536×184, 14pt 글자 두 사각형은 원본/제품 일치다. 범위·그림 차이는 evidence/HEJO-FOUNDATION/TASK-43.md에 적었다. codesign --verify --deep --strict 종료 0. capture.json·post-checks.json·image-check.json. 운영 앱 전체·픽셀 동일 비교를 주장하지 않는다.
10. 중간 근거: 새 메서드의 메인 액터 호출을 명시한 뒤 집중 컴파일을 통과했다. 회원 상태 비교 기준은 방 선택/읽음 변경이 끝난 뒤로 옮겼다. 첫 전체 결과는 원본 불투명도 숫자 글꼴을 맞추기 전이며 intermediate-before-value-font에 보존했다. 그 뒤 최종 고정 입력으로 검사했다. 숨은 탭의 부품을 캡처한 초기 그림은 최종 증거로 쓰지 않고, 보이는 탭·창 수명·같은 비활성 창 상태를 맞춘 그림만 사용했다.
11. 미검증: 운영 허브/서버, 두 Mac, 실제 시스템 접근성 전환·로그인 항목 등록, 물리 입력기와 VoiceOver. 필요/도달 증거 수준 2/2, 실물은 운영 수락에 남는다. TASK-44 이후는 미착수다.
12. 검토 요청: LocalStore 한 원본과 허브 분리, 한글 조합/기본 크기 직렬화, 모양 revision 높이 무효화, Future 경합/정리 경계를 봐 달라. public f716bdf는 고정했고 운영 홈·앱 사본·공용 릴리스·운영 저장소·본체/ddots·원격 변경과 GitHub 조회·실제 발송·비밀 파일 열기는 없었다.
13. 최종 정적 검사·커밋: 개인값 검사·HEJO_PYTHON 지정 훅·diff는 각각 종료 0이다. 소유 파일 27개만 git commit --only 대상으로 정했다. 실제 전체 커밋과 커밋된 입력/그림 바이트 일치·깨끗한 main·고정 public은 .build/task43/final-checks.json·commit-result.json·final-verification.json을 따른다.


## 구현 인계: TASK-44 다운로드 폴더 저장

1. 받은 설계: handoff 보완 38 및 대조표 H02/H02+, REQ-HF-37·AT-95와 이번 직접 지시. 기준 7f23b69bb370eb63c492928ada5494ed53d46008. 일반 위험, 필요 증거 수준 2, 임시 홈·명시적 임시 다운로드 위치·루프백만 사용했다.
2. 구현자 판단: 구현·자체 검증 완료, 계획 담당 검토 대기. tasks 판정은 검토자가 갱신한다.
3. 책임 배치: 기존 GateHTTP 안의 DownloadFileStore가 사용자 사본의 이름·충돌·저장을, 기존 ConversationController가 사장 열기와 client_msg_id 송신 확인 뒤 보관을 맡는다. 파일 ID·이름·날짜·직원 범위는 기존 조회 복제본에서 읽는다. 새 영구 색인·LocalStore 필드·원본·허브/wire/문/기록장 변경은 없다.
4. 추가/제거: 받은 파일은 현지 시각 yyyy-MM-dd HHmm와 원본 named의 ID/확장자 규칙으로 저장 후 연다. 같은 파일 진행 중 누름은 한 번만 받고, 저장된 사본의 재열기는 받지 않는다. 보낸 파일은 송신 확인 뒤 ID 없는 이름으로 보관하며 같은 내용 재사용·다른 내용 2~99 번호·이미 다운로드 안인 원본 보존을 적용한다. 사본 보관 큐는 직렬이다. 그림 미리보기의 download는 기존 캐시만 쓴다.
5. 설계 차이: 원본 받은 파일 저장 실패는 안내만 표시하지만 이번 직접 지시대로 캐시로 열기를 더했다. 원본 `파일을 저장하지 못했어요. …` 문구를 그대로 사용하고 다음 열기 시 이전 안내를 지운다. 원본의 Slack 200MB·보관하지 않기·별도 ddots 기록장은 제외했다. hejo 50MiB·변경된 업로드·출입증/리디렉션/크기 검사는 유지했다.
6. 사용 형태: 다운로드 위치 주입은 실제 사용자 폴더에 쓰지 않는 시험 격리다. 사본은 사용자 소유 산출물이며 파일 공급자의 두 번째 원본으로 쓰지 않는다. 서버 조회용 cache/files는 그대로다. 하위 에이전트·새 SwiftUI·시험 전용 제품 분기는 없다.
7. 변경 성격: 승인된 의미 변경이다. 기존 열기 요청이 사용자 사본을 남기며 확인된 전송도 이 Mac에 사본을 남긴다. 업로드 성공만으로는 저장하지 않고 거절된 전송 사본은 남기지 않는다. 보낸 사본 실패가 성공한 전송을 실패로 뒤집지 않는 원문 동작은 유지했다.
8. 시험: DownloadsTests는 현지 날짜/ID/한글 UTF-8/확장자·위험 이름·같은 내용 재사용/번호/폴더 안 파일·한도를 단언한다. downloads_fixture.py는 실제 GateClient/Controller/HTTP와 가짜 문에서 동시 누름·재열기 각 한 번 받기, 다른 ID, 직원 범위, 불가 폴더 안내+캐시 열기, 확인된 전송/거절된 전송을 보호한다. 기존 실제 파일 송수신 시험들도 다운로드 위치를 임시 홈에 명시했다. 통과한 시험의 단언은 완화하지 않았다.
9. 실행 검증: frozen.py 종료 0. foundation9_runner hejo 245 passed(test_install·허브 포함), 앱 전체·기존 통신·새 AT-95 루프백 통과. 파일 함수+실제 AT-95 루프백 반복 3회 모두 0·inputsUnchanged=true, 입력 186개 불변. frozen-progress.json·final-foundation.log·app-focused-01~03.log. reference.py 종료 0: 읽기 전용 ddots 원본과 실제 제품 파일 함수를 각각 컴파일·실행한 이름/파일 본문 결과가 같다. mutation.py 종료 0: 파일 ID를 빼는 사본 compile/run 0, 원본 비교 단언은 정상 0·변형 1로 검출했다. 원본과 실제 제품은 변형하지 않았다. post_checks.py 종료 0: 같은 입력·원본 불변·산출물 지문·codesign deep/strict 통과. 로그는 .build/task44에 있다.
10. 미검증: 실제 사용자 다운로드 폴더·운영 서버·두 Mac 실물. 필요/도달 수준 2/2다. 새 제품 화면이 없는 I/O 변경이므로 화면 사진 대신 원본/제품의 같은 파일 이름·본문 비교를 evidence/HEJO-FOUNDATION/TASK-44.md·task44-files.json에 남겼다. 운영 앱 전체 비교를 주장하지 않는다.
11. 중간 근거: 첫 단위 시험의 임시 루트 생성 누락과 새 가짜 welcome의 avatar 필드 누락을 고쳤다. 실제 제품 오류가 아닌 시험 초기 상태였고 원문/통신 계약은 바꾸지 않았다. 저장 실패 안내 초기화를 더하기 전 전체 검사는 소유 실행만 중단하고 intermediate-before-notice-clear에 보존했다. 선택한 글 날짜를 직접 전달하도록 호출자를 맞추기 전 실행은 intermediate-before-message-date에 보존했다. 이후 최종 입력으로 재검증했다. 기존 Swift 5 actor/SDK 경고는 원 로그에 남겼다. 범위 밖 부채는 새로 발견하지 않았다.
12. 검토 요청: 사용자 사본과 조회 캐시 구분, 재열기의 직원/삭제 범위, 기존 소수 초 날짜 파서, 송신 확인 경계·직렬 사본 큐, 오류 안내/캐시 fallback을 봐 달라. public f716bdf는 고정했고 운영 홈·앱 사본·공용 릴리스·운영 허브·운영 저장소·본체/ddots·원격 변경, GitHub 조회·실제 발송·비밀 파일 열기는 없다. TASK-45 이후 미착수다.
13. 최종 정적 검사·커밋: 보고 추가 뒤 개인값·HEJO_PYTHON 지정 훅·diff 검사를 하고 소유 파일만 git commit --only로 기록한다. 실제 전체 커밋·소유 파일·입력/산출물 지문 일치·깨끗한 main·고정 public은 .build/task44/final-checks.json·commit-result.json·final-verification.json을 따른다.


## TASK-45 · N44-01 구현 인계

1. 받은 설계: handoff 보완 38·58, REQ-HF-39/AT-96, H03·H03+. 기준 main ca80a9d. 일반 위험, 필요 증거 수준 2. 운영·공개본 반영 없이 로컬 구현·시험이다.
2. 구현자 판단 상태: 구현·자체 시험 완료, 계획 담당 검토 대기.
3. 변경 후 구조: 기존 ConversationView/AppDelegate의 링크와 접힌 말풍선 행동을 PetController의 옆 창 열기로 연결했다. WebPaneModel은 일시 탭·WebKit 요청·그림을, 기존 DownloadFileStore는 다운로드 위치를, LocalStore는 Mac별 칸 크기만 맡는다. 문·허브·기록장·wire는 바꾸지 않는다.
4. 더한 것/뺀 것: WebPane·WebAddress·WebPicture·WebTabBlank 원본의 기능을 옮기고 WebPaneView를 AppKit으로 작성했다. 기존 외부 링크 바로 열기를 ⌘/옆 칸 분기로 대체했다. 문 첨부는 기존 GateHTTP로 받은 로컬 파일을 별도 nonPersistent 저장소에서 연다. 기존 50MiB 첨부 한도와 Info.plist는 유지한다. WebKit 프레임워크를 기존 빌드/시험 명령에 더했다.
5. 설계 차이: 첫 탐색 실패 시 원본은 tab.url=nil이라 밖에서 열기 제어가 비활성이다. 원본 분리 실행으로 확인하고 26판 코드 우선으로 유지했으며 copy-review와 TASK-45 화면 문서에 기록했다. AT-96 문서는 수정하지 않았다. 이 해석은 검토자가 확인해 주어야 한다.
6. 경계/임시 코드: AppKit UI와 원본의 관찰 모델 사이에는 onChange로 화면 갱신을 연결한다. 시험 전용 testConversation 생성 함수는 실제 Controller에 임시 다운로드 경로를 주입하며 본문 로직을 바꾸지 않는다. 원본 화면 분리 실행의 주변 대역과 그림 내보내기 도우미는 로컬 빌드 자료에만 있다. 제품의 두 번째 영구 원본은 없다.
7. 변경 성격: 의미 변경(외부 링크만 열던 동작을 옆 창으로 대체). 원본의 탭·탐색·파일·그림 수명과 폴더 이름 규칙을 대조했다. Mac별 웹 칸 크기는 hejo-local.json의 기존 창 크기 자리다.
8. 추가 시험: WebPaneTests/web_pane_fixture는 실제 WebKit의 새 창·탭 한도·선택 스크롤·주소/검색 계산·탐색·한글 키 위치 단축키·다운로드·문 첨부 로컬 보기·실패·접힌 말풍선 열기·폭/높이·그림 재사용을 보호한다. 서버는 웹 요청의 Authorization 부재와 앱 파일 요청의 인증을 따로 검사한다. N44-01은 모든 시험 Controller를 임시 경로에 묶고 앱 시험 진입점이 실제 다운로드 폴더의 항목 이름 불변을 검사한다. 이름이나 내용은 로그에 쓰지 않는다.
9. 최종 검증: frozen.py 종료 0. foundation9_runner hejo 245 passed(test_install·허브 포함), 앱 전체/통신·AT-96 반복 3회 모두 종료 0·inputsUnchanged=true, 입력 194개 불변. 앱 전체 시험의 실제 다운로드 폴더 항목 이름 불변도 통과했다. mutation.py compile/verify 각각 0: 정상 0·탭 한도 13개 변형 1로 검출. post_checks.py 0: 최종 연결 캡처·PNG 4개(720×1000, 불투명, 제어 줄 아래 페이지)·codesign deep/strict 통과. 원본 분리 실행 0, 라이트/다크 직접 표시 비교 완료. 제품 주소칸 왼쪽 약 20pt·글자 기준선 약 5pt와 페이지 왼쪽 선 1pt 차이는 TASK-45 화면 문서에 명시했다. 개인값/HEJO_PYTHON 지정 훅/diff의 실제 종료 결과는 final-checks.json, 별도 커밋·입력/그림 일치는 final-verification.json에 기록한다. 중간 실패·중단 실행은 로컬 intermediate-*에 보존했으며 최종 통과 근거로 세지 않는다. 하위 에이전트는 쓰지 않았다.
10. 미검증: 실제 서버·운영 허브·두 Mac·임의 웹 사이트 로그인·시스템 브라우저 실행·물리 입력기·VoiceOver. 운영 설치·공용 릴리스·public 변경·원격 조회/쓰기·실제 발송·비밀 파일 접근은 하지 않았다.
11. 범위 밖 부채: 이번에는 없음. 첫 실패의 밖에서 열기 동작은 5항의 원본 대조/검토 사항이다.
12. 검토 초점: AppKit 폭 변화 때 살아 있는 페이지의 배치 지연과 흐린 그림, 첨부의 비영구 저장소, 원본 실패 경계, 시험 다운로드 격리. 필요/도달 증거 수준은 2/2다. 실제 운영·두 Mac 결합을 확인했다는 뜻은 아니다.
13. 대상 변경본: 기준 ca80a9d 위의 TASK-45 소유 파일 별도 commit-only 대상. tasks.md의 TASK-45 대기는 계획 담당 판정에서 갱신한다. TASK-46 이후 미착수이며 public f716bdf는 고정이다.

TASK-45 최종 서식 보완: WebPane.swift EOF의 빈 줄 한 개를 제거했다. 전체/반복 실행 중 입력 194개는 불변이었고, 최종 커밋에서는 이 1개 파일만 끝 LF 1바이트 차이가 있다. `.build/task45/finalization-whitespace.json`과 시험본 사본으로 정확히 대조한다. 나머지 193개 입력은 시험 지문과 같으며 실행 코드 변경은 없다.


## TASK-46 · N45-01 구현 인계

1. 받은 설계: handoff 보완 38·59, REQ-HF-40/AT-97, H04·H04+. 기준 main 985d9d8. 일반 위험, 필요 증거 수준 2(실물 권한 확인은 별도). 운영·공개본 반영 없이 로컬 구현·시험이다.
2. 구현자 판단 상태: 구현·자체 시험 완료, 계획 담당 검토 대기.
3. 변경 후 구조: MacCalendar가 EventKit을 직렬 조회해 일시 값만 내고 CalendarMatch가 수신 글 시각과 실제 일정의 제목/장소를 맞춘다. 기존 ConversationController·BubbleReveal.Action이 같은 값을 화면에 전달하며 AppDelegate가 AppKit 캘린더 창을 소유한다. 일정은 LocalStore·문·허브·기록장에 저장하지 않는다.
4. 더한 것/뺀 것: MacCalendar/CalendarMatch 원본을 이식하고 MacCalendarView를 AppKit으로 만들었다. 메뉴의 비활성 캘린더 자리를 실제 창으로 채웠다. 월 이동·제목/장소 검색·상세·종일·삭제/이동 재조회·권한 안내와 카드/말풍선 단추를 연결했다. Info.plist에 원본 캘린더 문구 두 키, 기존 빌드/시험에 EventKit 링크를 더했다. N45-01은 WebPaneView의 단추·주소칸 프레임과 셀 가운데 정렬을 고쳤고 선은 원본처럼 폭을 차지하지 않는 overlay로 옮겼다.
5. 설계 차이: 날짜만으로 일정이 생기는 것으로 해석하지 않았다. 원본은 일반 제목 '회의'를 제외하고 구체적 제목 또는 날짜+장소가 맞아야 한다. '대화 열기'를 빼는 조건도 일정 개수가 아니라 링크+일정의 내용 단추 둘이다. REQ-HF-40의 구체 문장과 원본을 따라 copy-review에 기록했다. 수락 기준 문서는 바꾸지 않았다.
6. 경계/임시 코드: 공급자 프로토콜은 권한/조회만 노출한다. EventKit은 운영 앱에서만 실제 공급자를 쓰고 모든 시험은 가짜 공급자·observe:false다. SwiftUI/ObservableObject 발행은 AppKit onPresentation으로 대체했다. 캡처/원본 분리 실행 도우미는 로컬 빌드 자료이며 제품에 시험 분기를 넣지 않았다. 하위 에이전트·새 영구 원본·SwiftUI 추가는 없다.
7. 변경 성격: 새 기능과 주소줄 배치 수정이다. 기존 일반 링크/파일·50MiB 한도·전송/기록장 계약·허브 동작을 유지했다. 기존 링크 내용 단추를 공용 Action.content에 합쳐 캘린더와 함께 최대 세 단추를 만든다.
8. 시험: CalendarTests는 원본 날짜 예, 짧은 제목 경계·일반 낱말·중복/다른 캘린더·장소+날짜·1/2 일정·실제 카드 누름·말풍선 단추 수·월/검색/상세·종일 종료일·삭제/이동·권한 없음/미정/있음과 메뉴 연결을 보호한다. N45-01은 원본에서 측정한 제어 프레임과 실제 그려진 주소 글자 경계(x=81, 위=55, 아래=65)를 독립 literal로 단언한다. 기존 WebKit 통합/한글 키 위치 단축키와 임시 다운로드 격리는 그대로 검사한다.
9. 최종 검증: frozen.py 종료 0. foundation9_runner hejo 245 passed(test_install·허브 포함), 앱 전체·기존 통신·AT-97/AT-96 통과. 집중 반복 3회 모두 0·inputsUnchanged=true다. 실제 다운로드 폴더 항목 이름 불변도 통과했다. 원본 분리 실행은 수정하지 않은 MacCalendar/CalendarMatch와 WebPane 계열에 가짜 공급자/로컬 페이지를 넣었다. 최종 그림·서명·읽기 전용 EventKit 호출·Info.plist·돌연변이·개인값/훅/diff 결과는 .build/task46/post-checks.json·mutation.json·final-checks.json·final-verification.json을 따른다. 시험 중 동결 입력은 바꾸지 않았다.
10. 미검증: 실제 EventKit 권한 요청/운영 캘린더·실제 서버/허브·두 Mac·물리 입력기·VoiceOver. 필요/도달 수준 2/2다. 화면은 같은 합성 상태의 원본 함수/창과 제품 AppKit 보기 비교이며 운영 앱 전체·픽셀 동일 비교가 아니다. 원본과 같은 글꼴/크기를 지정해도 AppKit/SwiftUI 글자 합성과 기본 제어 외관 차이가 남는다.
11. 중간 근거: 첫 날짜 단추 시험의 시간대 기준을 이 Mac 달력과 일치시켰다(제품 판정은 원본 그대로). 셀 교체 때 빠진 편집 가능 속성으로 ⌘W 회귀가 실패해 복구했다. 주소 셀 여백 중복은 실제 잉크 경계 검사로 고쳤다. 잘못 시작한 중복 집중 컴파일은 소유 프로세스만 중단했다. 초기 실패/보조 탐침은 최종 통과로 세지 않는다. 기존 SDK/Swift 5 actor 경고는 원 로그에 남겼으며 이번 변경 때문에 억제하지 않았다. 범위 밖 부채는 새로 발견하지 않았다.
12. 검토 초점: 이 Mac 일정의 비영구 투영·수신 시각 기준·정확한 반복 일정 재조회·권한 후 캐시 제거·실제 카드/말풍선 연결과 N45-01 실제 글자 위치를 봐 달라. 화면 증거는 evidence/HEJO-FOUNDATION/TASK-46.md다. 운영 홈·앱 사본·공용 릴리스·운영 저장소·운영 허브·본체/ddots·원격 변경, GitHub 조회·실제 발송·비밀 파일 접근은 없다.
13. 대상 변경본: 기준 985d9d8 위의 TASK-46/N45-01 소유 파일만 별도 git commit --only 대상이다. 전체 커밋·입력/그림 지문 일치·깨끗한 main은 .build/task46/final-verification.json을 따른다. tasks.md의 대기 표시는 계획 담당 판정에서 갱신한다. public f716bdf는 고정이며 TASK-47은 미착수다.

TASK-46 최종 UI 보완: 원본 실측에 따라 월 제목 3pt, 카드 일정 단추 줄 22pt/위 2pt, 목록 보통 73pt/긴 제목 105pt를 맞췄다. 긴 제목은 줄 수로 높이를 계산하며 권한 설명도 내용 높이 다음 14pt에 기본 크기 단추를 놓는다. 이전 통과/중단 자료는 intermediate-before-*에 보존했으며 이 보완 뒤 전체/반복 실행을 최종 근거로 사용한다. 최종 검증 입력에는 Info.plist도 포함한다.

TASK-46 최종 확인: 마지막 입력 199개를 동결한 전체 검사와 집중 3회가 모두 종료 0이며 실행/커밋 사이 입력도 그대로다. 시작 시각이 다른 같은 식별자의 일정을 여는 변형은 종료 1로 검출했다. post_checks.py는 캡처 8개·실제 주소 잉크 경계·월 제목 y=65~75·두 캘린더 사용 키·읽기 전용 EventKit 호출·codesign deep/strict를 확인했다. 최종 8개 PNG를 직접 표시해 비교했다. NSTextField의 기본 안쪽 여백/합성에 따른 약 2pt 글자 시작 차이와 월 제목 오른쪽 끝 1px 차이는 플랫폼 표시 차이로 남기며 픽셀 동일을 주장하지 않는다. 긴 제목·조회 중 월 이동·네이티브 스트리밍 일정 단추는 최종 회귀에 포함한다. 개인값/훅/diff 및 별도 커밋의 실제 결과는 final-checks.json·final-verification.json을 따른다.


## TASK-47 구현·자체 시험

- H05·H05+: 기존 관제 화면 칸에서 작업 메타데이터·세션 꼬리 읽기·공식 훅 상태·화면 도구 관측과 AppKit 작업 목록을 연결했다. 세션은 읽기만 하고 본문·추론·도구 인자·사용량은 보관하지 않는다. 메뉴 ‘작업 목록’과 설정 ‘승인 알림 연결 안내’가 실제 동작한다.
- 원본 Dashboard·Monitor·HookBridge·TranscriptDecoder·ScreenFocus·ComputerUseActivity·configure_hooks·안내·시험과 호출부 전체 독해는 copy-review에 있다. 세션 검색 15초/상태 읽기 2초, stale 300초·응답 동작 20초·하루 보존·각 200개·화면 호출 수명 60초/결과 뒤 3초를 유지했다.
- 훅 진입은 GUI 초기화 전에 끝나며 상태 파일만 쓴다. 훅 연결은 원본 create-only와 같은 충돌 정책을 유지한다. 설정 변경 전 비공개 백업·영수증, 중간 실패 보상, 원래 바이트·권한 복원, 사용자가 나중에 바꾼 설정 보호를 추가했다. 사장이 안내에서 연결·연결 해제를 고를 때만 설정에 접근한다.
- 원본 우선 기록: App.swift updatePet·PetView의 승인/실패 동작은 화면 시선보다 앞선다. 화면 조작 중인 작업의 명확한 창만 바라보며 승인 창은 추정하지 않는다. 접근 실패는 ‘연결 안 됨’과 원본 상세를 함께 표시한다. FileDrop·사용량·원본의 연결 제안은 제외 결정대로 넣지 않았다.
- 모든 시험은 임시 홈과 가짜 세션/설정이다. 실제 CLI 설정 본문을 읽지 않고 메타데이터 지문을 비교하며 내용 바이트 비교는 임시 설정에만 한다. 실제 다운로드는 이름만 비교한다. 운영 홈·배포·공용 릴리스·운영 허브·본체·ddots·원격·고정 public 변경과 실제 발송은 없다.
- 증거: [TASK-47](../../../evidence/HEJO-FOUNDATION/TASK-47.md). 필요/도달 3/2이며 실제 설정 연결/해제·작업 창·물리 입력기·VoiceOver 실사용은 운영 수락에 남는다. 최종 명령 결과와 커밋 대조는 추적하지 않는 `.build/task47/final-verification.json`에 기록한다.

### 최종 자체 검증 기록

- 착수 기준 `b0d6a9a9ac4904ba25402f9f1430d07571f5fe39`. 최종 `frozen.py` 종료 0: Python 245 passed(test_install·허브 포함), 앱 전체·기존 통신 시험과 새 훅 시험 9개 통과. AT-98 및 훅 시험을 3회 반복해 모두 종료 0·inputsUnchanged=true. 고정 입력 213개, 별도 안내 HTML은 시험 시작 이전 메타데이터와 빌드 사본의 바이트 일치를 확인했다. 로그 `.build/task47/final-foundation.log`·`frozen-progress.json`.
- `mutation.py` 종료 0: 정상본 0, 실패 보상 제거 사본 1로 중간 실패 복원 단언에 검출했다. 제품 입력 불변. `.build/task47/mutation.json`.
- `post_checks.py` 종료 0: 최종 제품 조립 캡처·원본 규칙 분리 실행 68개·원본 Dashboard 분리 캡처·6개 PNG(710×610·불투명·내용)·codesign deep/strict 통과. 최종 그림을 직접 비교했다. 원본 규칙 네 파일은 제품과 바이트가 같고, gate·hub·schemas 변경은 없다. `.build/task47/post-checks.json`·`image-check.json`.
- 실제 CLI 설정은 내용을 열지 않고 지정된 설정 파일들의 lstat 메타데이터 지문 불변을 확인했다. 이는 실제 설정 내용 SHA와 다르다. 실제 다운로드는 이름 목록 불변을 확인했다. 가짜 설정의 정확한 원래 바이트·권한 복원과 실패 보상은 실행해 확인했다.
- 중간 전체 검사 중단 3건과 자원 경로 오류 실행 1건은 `intermediate-*`에 보존했다. 경로 오류는 제품 변경 없이 시험 자원 위치를 실행 파일 기준으로 고쳐 해소했으며 최종 통과 자료와 구분한다.
- 구현자 인계 상태: 배정 코드·자체 시험은 수준 2 통과, 필요한 수준 3의 실제 설정 연결/해제·실제 작업 창 결합은 미실행. 독립 검토·운영 수락이 남는다. 소유 파일만 commit-only하며 최종 커밋·깨끗한 작업 트리·고정 public·입력/그림 대조는 `.build/task47/final-verification.json`을 따른다.

- 정적 진단 처분: 새 monitor 캡처의 Swift 6 Sendable 경고는 현재 Swift 5 빌드에서 관측됐다. 가변 모니터는 전용 직렬 큐에서만 poll하고 main의 monitorBusy가 중복을 막는다. UI에는 값 스냅샷만 넘기는 의도된 소유 경계로 분류했고 경고를 억제하지 않았다. 나머지 기존 actor/미사용 변수 진단은 범위 밖 부채로 남겼다.


## 보완 60 구현·자체 시험: N47-01·02

- 착수 기준 `41644e8b50e1968a78e0f89a7d87b9b42a21c2e8`. 기존 TASK-47 기록은 당시 이력으로 보존한다. 계획 담당이 정정한 AT-98에 따라 Dashboard의 ‘연결 안 됨 · ’ 앞붙임을 제거하고 Monitor의 detail 원문만 그린다. 사용 가능 여부의 teal/gray 점은 그대로다. 감시·훅·상태·저장·문·허브 계약 변경은 없다.
- 아래 세 단추는 AppKit rounded 기본 13pt로 맞췄다. 원본 Dashboard의 같은 SwiftUI 구성을 별도 실행한 결과 새로고침 69×24, 동작 미리보기 96×24, 승인 알림 연결 안내 125×24pt이며 제품과 같다. AT-98에는 글꼴·세 크기 실측 단언을, Monitor 시험에는 ‘기록 폴더에 접근할 수 없음’ 원문 단언을 추가했다. 실측 자료는 evidence/HEJO-FOUNDATION/task47-footer-metrics.json이다.
- 집중 컴파일·실행은 `.build/n47/focused.py` 종료 0, AT-HF-98 MONITOR/APP PASS·APP_TEST_OK다. 원본 단추 분리 실측 compile/run은 각각 종료 0이며 `.build/n47/button-reference.log`에 있다. 이후 검증과 최종 커밋은 아래 최종 기록과 `.build/n47/final-verification.json`을 따른다.
- 실물 훅 연결/해제·실제 작업 창·물리 입력기·VoiceOver는 미실행이며 필요/도달 증거 수준은 3/2다. 실제 CLI 설정은 내용 접근 없이 lstat 메타데이터만, 실제 다운로드는 이름만 대조한다. 실제 내용 SHA 불변을 주장하지 않는다. 운영 반영은 보완 60의 계획 담당+사장 점검에 남긴다.

### 보완 60 최종 검증

- `.build/n47/frozen.py` 종료 0: foundation9_runner hejo 245 passed(test_install·허브 포함), 앱 전체·기존 통신·훅 9개 통과. 집중 3회 모두 종료 0이며 실행 중 입력 214개 불변이다. 실제 CLI 설정 lstat 메타데이터·실제 다운로드 이름 불변 단언도 통과했다. 로그는 `.build/n47/final-foundation.log`·`frozen-progress.json`·`app-focused-01.log`~`03.log`다.
- `.build/n47/post_checks.py` 종료 0: 최종 제품·원본의 일반/고정/빈 목록 캡처 여섯 개를 다시 만들고 직접 비교했다. 원본 세 그림은 이전과 바이트가 같고 제품 세 그림은 두 지적을 반영한다. 단추 글자 크기·높이는 원본 분리 실측과 같으며 ‘기록 폴더에 접근할 수 없음’ 앞에 새 낱말이 없다. 기존 AppKit 기본 단추 바탕·선택 구획의 플랫폼 차이는 그대로 문서화했다. PNG 유효성·원본 불변·codesign deep/strict 통과, 운영 앱 전체·픽셀 동일 비교를 주장하지 않는다.
- `.build/n47/finalize.py`의 checks·commit·verify가 정적 검사와 소유 파일 commit-only·커밋/입력/그림 대조를 맡는다. 실제 결과와 전체 커밋은 `.build/n47/final-checks.json`·`commit-result.json`·`final-verification.json`을 따른다. public 후보 고정, 운영 홈·앱 사본·공용 릴리스·운영 허브·본체/ddots·원격·실제 발송·비밀 파일 접근은 없다. 계획 담당의 N47-01·02 검토와 보완 60 수준 3 실물 수락은 남긴다.


## 보완 61 — 0.2.0 공개 후보 재생성

- 받은 설계: handoff 보완 61, 사장 결정에 따라 TASK-36~47을 포함한 main 전체를 새 0.2.0 후보로 만든다. 버전 0.2.0·빌드 2를 유지하며 제품 코드 변경은 없다. 이 보고만 먼저 commit-only한 깨끗한 main을 공개·빌드·검증의 기준으로 고정한다.
- 기존 public은 archive/public-0.2.0-before-parity로, 더 앞선 archive/task33-before-n33-01도 그대로 보존한다. hejo-publish는 기존 public 작성자 정보를 로컬에서 재사용하는 gh 대역으로 실행한다. 실제 GitHub 조회·원격 쓰기는 하지 않는다. 부모는 이전 공개 계보 0.1.0 f90bf08이며 개인 main 계보는 포함하지 않는다.
- 준비물 위치는 `.build/release-0.2.0/`, 실행 근거·전체 커밋·트리·개인 이력 배제·공개본 검사·서명·반복·호환성·보호 검사 결과의 원본은 `.build/release-0.2.0-work/final-verification.json`과 `checkpoint.json`이다. 새 후보의 트리와 고정 main 트리, 앱 BuildInfo의 트리를 대조한다. 공개본 자체도 별도 worktree에서 개인값 검사한다.
- 같은 트리의 foundation9_runner hejo(test_install 포함), 전체 앱 실행 3회, aeaa652 옛 문과 새 앱의 실제 루프백 짝맺기·송수신을 검사한다. 모든 실행은 가짜 홈·명부·세션·설정·임시 다운로드·로컬 웹/문만 쓴다. 실제 CLI 설정은 lstat만, 실제 다운로드 폴더는 이름만 대조하며 실제 내용 SHA 불변을 주장하지 않는다.
- hejo-ship prepare는 기존 키체인 키를 재사용한다. 새 키 생성·비밀 키 출력/내보내기·setup은 실행하지 않는다. 압축을 다시 풀어 codesign deep/strict·실행 파일 지문·Sparkle 서명을 검사한다. 기존 Sparkle 고정 캐시를 사용해 외부 다운로드를 하지 않는다.
- 이번 단계는 로컬 공개 후보·배포 준비와 자체 검증(필요/도달 수준은 최종 근거 기준)이다. 사장 public 푸시 승인·publish, aeaa652 기준 새 롤백 백업, 운영 허브/문·team-kit 반영·TASK-23·실물 훅 연결/해제·두 Mac 자동 업데이트·비설계자 검토는 수행하지 않는다. 고위험 운영 수락 완료를 주장하지 않는다. 운영 홈·공용 릴리스·본체/ddots는 바꾸지 않는다.


## TASK-50 구현·자체 시험 — 보완 62

1. 받은 설계: handoff 보완 62, 기준 c554077f6ba1dc1513deb08683f425cb933fdd1b. 고위험(권한), 인계 필요/도달 2/2이며 운영 실물 수준 3은 계획 담당+사장에게 남긴다. 구현자 판단은 패치·자체 시험 완료, D50-02 경계와 운영 수락은 미완료다.
2. 책임 배치: team-kit 공용 라이브러리의 경량 플랫폼 집합을 기존 governance·execution·mail·회상 소비자가 참조한다. 새 권한 원본·hejo 규격·문·Hermes 본체 변경은 없다. 기존 메일 계정/프로필·배경·승인/범위 경계는 유지하고 사장 대화 전송에 hejo만 추가했다.
3. 변경본: `.build/task50/team-kit.patch`, 15개 파일. SHA-256 `70597129d464c9dd94193482828038de85d6db1d76d644ec6dad14991dbf2398`. 분류표 `.build/task50/classification.md`(146행, 원본 기준 줄 번호), 변경 표현식 목록 `changed-predicates.json`. 운영 원본과 같은 658개 항목을 대조했고 root 별칭 링크는 그대로 보존했다.
4. 시험 경계: 가짜 홈·설정·명부·SQLite 기록·메일 공급자만 썼다. Mail 다른 계정 읽기는 실제 `_gmail_direct`의 문제 분기를 호출해 허용 때만 가짜 읽기 공급자에 도달하고, 예약·배경·빈 chat_id면 호출 0임을 단언한다. 다른 권한 함수도 Slack/hejo 동일 결과와 원래 거절을 검사한다. 대화 태그·기록 필터와 실제 쓰기 권한은 구분했다.
5. 집중 검증: 게이트웨이 Python으로 `run_tests.py focused` 종료 0, 194 passed. 원본 메일 공급자·앱·외부 서비스는 호출하지 않았다. 실행 줄 추적도 종료 0이며 공용 집합 소비 27개 줄(26개 교체 표현식 및 공용 상수/SQL 바인딩을 포함)이 실행됨을 확인했다. `focused.log`·`predicate-coverage.json`·`predicate-coverage.log`.
6. 전체 검증: `run_tests.py full` 종료 0, 5024 passed·5 skipped·58 subtests passed, 기존 SyntaxWarning 1개. 환경은 게이트웨이 Python과 요구된 pytest/core PYTHONPATH다. 임시 운영 저장소 worktree의 형제 플러그인·스키마·프로필 소스 문맥을 갖췄으며 team-kit 사본만 변경했다. `.build/task50/full.log`·`full-result.json`. 시험의 skip·기대값·허용 오차는 바꾸지 않았다.
7. 돌연변이: `mutate.py` 종료 0. 별도 정상 사본은 0, 공용 집합에서 hejo 제거 사본은 1, Mail 배경 검사 제거 사본도 1로 재현 시험에 검출했다. 제품/운영 원본은 변형하지 않았다. `mutations.json`·`baseline.log`·`missing-hejo.log`·`missing-background.log`.
8. 정적/적용 확인: 임시 worktree의 `airport-check --snapshot` 종료 0, baseline 증가/재생성 없이 PASS. 운영 원본에 `patch -p1 --dry-run` 종료 0이며 적용은 하지 않았다. `airport.log`·`airport-result.json`·`patch-dry-run.log`·`patch-result.json`. 실제 적용·재시작·메일 실물은 미실행이다.
9. D50-02 후보: wait_jobs의 Slack 정규식/알림, 원문 증명에 의존한 work_capture·선택·workspace/관리 학습, Slack 블록 승인 수신, Notion conversation 및 Slack 단일 플랫폼 인증 경계. 네 경로의 hejo 거절/미처리를 가짜 입력으로 재현해 `d50-02.json`에 남겼으며 해당 코드는 고치지 않았다. 분류표를 보고 계획 담당이 후속 계약을 판단해야 한다.
10. 중간 실행: 단독 team-kit 사본 첫 전체 검사는 형제 플러그인·스키마·프로필 문맥 누락으로 53 failed·4967 passed·9 skipped였다. 이후 동일 제품/시험 코드를 완전한 임시 문맥에서 실행해 해소했다. 첫 원시 로그는 다음 실행 때 대체됐고 요약은 `intermediate-first-full.json`에 남겼다. 초기 집중 실패는 새 대역 속성/호출 이름 누락과 Kanban 프로세스 문맥 보완으로 해소했으며 제품 판정은 완화하지 않았다. 기존 file_drop_readers의 escape 경고는 이번 변경과 무관해 억제하지 않았다.
11. 최종 검토 초점: hejo 문 인증을 신뢰하는 범위와 user_id=owner 확인, 사장 기록 필터와 플랫폼 전용 동작 분류, 원래 배경 예외 보존, D50-02 미지원 경계를 봐 달라. hejo 커밋에는 이 보고와 copy-review만 넣는다. public·운영 원본/저장소 본문·게이트웨이·본체/ddots·실제 메일·Slack은 바꾸지 않는다. 최종 커밋·입력/패치 지문·원본 불변은 `.build/task50/final-verification.json`·`checkpoint.json`을 따른다.


## TASK-51 조사·제안 — 보완 63

- 받은 범위: 기준 `58b52ae56ba54ed885f11bbd5c21b83622749d01`, TASK-50 운영 적용 뒤의 D50-02 읽기 전용 조사다. 제품·운영 코드와 계약은 바꾸지 않았다. 구현자 판단은 조사 인계이며, 후속 설계·권한 확대·운영 수락은 계획 담당에게 남긴다. 기존 TASK-50 보고는 당시 실행 이력으로 보존한다.
- 상세 원본은 추적하지 않는 `.build/task51/survey.md`다. 이전 분류의 D50-02 28행·23개 함수 묶음을 현 운영 소스와 다시 대조했다. 항목마다 사장에게 주는 기능, Slack 증명 사실과 생산자/소비자, hejo 증명 출처의 코드 줄, 제안과 위조 차단 위험을 적었다. 전수 대응은 `candidate-coverage.json`에 있다.
- 제안은 공용 사장 인증으로 가능한 업무 안내·메일 읽기·Notion 대화 키, 문 원문 증명이 필요한 학습·기억·업무 선택·대기 작업, 현재 Slack 전용으로 남길 백업 질문 승인·지정 방 제한·Slack 사용량 조회로 구분했다. 선택 스킬·workspace의 단순 신원 판정과 원문 검증 소비자를 구별했고, native_tools 후보는 블록 승인 대신 실제 사용량 원장 조회라는 점을 정정했다. 제안은 구현 지시나 새 승인으로 취급하지 않는다.
- 문 기록장에는 전처리 전 사장 글과 답 버튼의 answer_to가 있으나 공개 first_thread_message는 직원 글만 조회한다. team-kit이 내부 기록장을 가져오지 않고 현재 사건·방·스레드·직원 수신 범위에 묶인 공개 원문 조회를 쓰는 방안을 제안했다. DB 전송 ID와 환경 MESSAGE_ID의 생산 경로도 구별했다. 일반 hejo source 생성에는 message_id/scope_id를 넣지 않아 현재 환경 ID를 보장할 수 없다는 코드상 빈틈과, 이를 후속 가짜 수신 시험으로 확인할 필요를 기록했다. 실제 turn 환경 탐침은 하지 않았다.
- 운영 세션 DB 6개를 immutable 읽기 전용·query_only로 열었다. WAL이 비어 있음을 먼저 요구했고 본문·실제 식별자 값 대신 열 이름과 집계만 조회했다. hejo 세션 16개는 chat/thread NULL·공백 0개, user 행 23개는 platform_message_id NULL·공백 0개였다. 전체 message 행 87개 중 해당 ID NULL은 64개이므로 모든 행을 사장 요청 증거로 볼 수 없다. 조회 전후 DB/WAL/SHM 크기·mtime·inode는 같았다. 실행과 집계 원본은 `db_metadata.py`·`db-metadata.json`·`db-metadata.log`다.
- 검증은 조사 범위 대응·지문·문서 개인값/훅/diff 검사로 한정했다. 제품 코드가 같으므로 앱·전체 team-kit 시험·돌연변이는 실행하지 않았다. 운영 소스 파일/링크 660개 대조와 실제 검사 종료값, 소유 보고 파일만 commit-only한 커밋·깨끗한 작업 트리·public 불변은 `.build/task51/final-checks.json`·`final-verification.json`을 따른다. 대화 본문·비밀 파일·실제 메일·Slack·재시작·운영 변경·원격 작업은 없다. 권한 경계 구현과 실물 증거는 미완료다.

## TASK-52 구현·자체 시험 — 보완 64

1. 받은 설계: 보완 64·D51-01, 기준 b6d4e23dd11182a29cc81f88a6286979729e14c7. 권한 경계의 코드·가짜 통합 증거를 인계하되 필수 전체 검증은 AT-96 실패로 보류한다. 운영 적용·실물 수준 3과 독립 검토는 계획 담당+사장에게 남긴다. 이전 TASK-51 조사는 당시 이력으로 보존한다.
2. 문 변경: gate/adapter.py의 수신 build_source에 같은 사건의 message_id를 넣고 scope_id는 넣지 않았다. owner_message는 기존 기록장의 살아 있는 owner 글을 현재 profile·chat·thread·msg_id와 실제 방 수신자에 한정해 복사해 반환한다. forwarder는 기존 경계에서 자기 profile로 고정한다. wire·영구 저장소·Hermes 본체 변경은 없다. gate/tests/test_owner_query.py가 정상 복사·거절·삭제·방·forwarder·실제 게이트웨이 환경 바인딩을 검사한다.
3. team-kit 변경: 운영 원본 660항목과 같음을 대조한 임시 사본에서 가 5곳에 공용 인증을 연결했다. 기존 configured owner 검사는 각 legacy 콜백에 보존했고, 원래 별도 목록을 검사하지 않던 소비자는 기존 판정을 유지한다. hejo는 owner·chat와 배경 거절을 공용 함수로 검사한다. 역할·경로·심링크·승인·원래 flag 처리는 남겼다. 공용 원문 공급자는 install_hejo의 현재 adapter/event/loop와 환경을 결합하고 공개 owner_message만 호출하며 실패는 None이다. DB content·모델 인자·Slack 헤더 모양으로 대체하지 않는다.
4. 원문 소비자: learning·request_source 일반 원문·memory_live·owner_context·paseo_authority가 hejo 원문을 재사용한다. 프로젝트 영수증과 학습 보고 전송 위치는 Slack 경로 그대로다. 검증된 사건에 묶이지 않은 hejo steer/redirect는 학습·선택 근거를 공급하지 않으며, bare approval·배경도 계속 거절한다. 학습 소비자가 숫자 행 순서를 쓰므로 공개 원문 증명 뒤 동일 전송 ID의 messages.id만 메타데이터로 읽는다. 문 UUID를 숫자 행 번호로 쓰지 않는다. owner_context의 hejo 선택은 원문과 전송 ID만 주고 row_id=None으로 두어 TASK-53의 기존 DB 본문 대상 추정을 열지 않는다.
5. 제출 패치: .build/task52/team-kit.patch, 12개 파일. SHA-256 660142a0533936ef78d30970209a5b81ea0c9c93ef34cf2db0c20cd87aa16ee5. 새 저장소나 문 내부 import는 없다. 운영 원본에 patch -p1 --dry-run 종료 0, 실제 적용은 하지 않았다. patch-result.json·patch-dry-run.log.
6. team-kit 최종 검증: 게이트웨이 Python과 지정된 pytest/core PYTHONPATH, 가짜 홈·설정·세션 DB만 사용했다. 집중 32 passed, 전체 5058 passed·5 skipped·58 subtests passed, 각각 종료 0. 기존 file_drop_readers escape SyntaxWarning 1개는 범위 밖 진단으로 보존했다. 검사 중 최종 canonical 입력 565개는 불변이다. focused.log·full.log·full-result.json·verification-inputs.json. 임시 운영 저장소 문맥에서 airport-check --snapshot 종료 0, 기준선 증가/재생성 없이 PASS(줄이기 가능 4건 안내만). airport.log·airport-result.json.
7. 돌연변이: 정상 team-kit/문 사본 각각 0, hejo 사용자 검사 제거·방 수신자 검사 제거·원문 공급자를 DB content로 대체한 사본은 각각 1로 검출했다. 컴파일/수집 실패가 아닌 해당 권한·원문 단언 실패를 확인했다. mutations.json과 mutation-*.log. 원본은 변형하지 않았다.
8. 문·결합 시험: 문 집중 3 passed(종료 0). 새 문과 수정 team-kit의 install_hejo를 실제 가짜 루프백 수신에 연결해 worker가 공개 조회로 같은 문 UUID·원문을 받는 별도 시험 1 passed(종료 0). 게이트웨이 자체의 환경 바인딩 메서드를 사용했다. integration.log·integration-result.json, .build/foundation9-task52-gate.log.
9. hejo 전체 검증 **미통과·검토 보류**: foundation9_runner hejo 두 실행 모두 Python 248 passed(test_install·허브 포함) 뒤 기존 AT-96 ‘newly selected tab scrolls into the strip’ 단언으로 전체 종료 1이었다. 앱 소스는 기준 HEAD와 같고 원인은 이번 범위에서 확정하지 못했다. 단독 웹 시험은 처음 0이었으나 최신 실행도 같은 단언으로 1이었다. 앱 제품·기대값·시간 조건은 바꾸지 않았으며 범위 밖 수정 판단을 계획 담당에게 넘긴다. 두 전체 실패는 intermediate-foundation-01/02.log/json, 최신 단독 실패는 web-probe.log/json이다. 첫 단독 성공의 전체 원시 파일은 후속 실행으로 대체됐고 도구 출력에서 관측한 값/발췌만 intermediate-web-first-observation.json에 구별해 남겼다. 중복 앱 전용 빌드는 중단했다. 최종 foundation-result.json·final-foundation.log에는 실제 종료 1을 기록하며, 개별 통과를 전체 성공으로 합치지 않는다.
10. 정적·최종 기록: 개인값·HEJO_PYTHON 지정 훅·diff 검사와 소유 파일만 commit-only한 전체 커밋, 운영 소스 불변·public 불변·깨끗한 main·패치/입력 대조는 .build/task52/final-checks.json·final-verification.json·checkpoint.json을 따른다. 운영 원본·운영 홈·공용 릴리스·운영 허브·재시작·운영 저장소 커밋/푸시·GitHub·비밀 파일·실제 대화 본문·실제 발송·본체/ddots 변경은 없다.
11. TASK-53 메모: linked_work의 선택 대상·Decimal ts, diagnosis_records의 Slack DM/permalink, wait_jobs의 형식·cron origin 전달을 다음 설계에서 이식해야 한다. 해당 파일과 D51-01의 Slack 전용 세 경계는 바꾸지 않았다. 단, wait_jobs.handle의 list/cancel·prune은 공통 learning.source를 쓰므로 hejo 인증 입구를 통과할 수 있다는 코드상 영향을 TASK-53에서 확인해야 한다(이번 실행 없음). 임의 answer_to 대상 직원 글의 내용 증명은 first_thread_message만으로 충분하지 않아 후속 설계가 필요하다. 운영 적용은 새 문 공개 메서드가 있는 릴리스와 team-kit 패치를 함께 검토·반영하고 계획 담당+사장이 재시작·실물 확인한다. 공개 메서드가 없는 옛 문에서는 원문 공급자가 실패 폐쇄한다.
