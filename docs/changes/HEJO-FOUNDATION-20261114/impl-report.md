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
