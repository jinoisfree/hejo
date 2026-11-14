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
