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
