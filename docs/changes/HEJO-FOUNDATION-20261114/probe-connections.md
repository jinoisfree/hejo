# TASK-31: 직원별 도구 연결 탐침

구현 담당의 자체 탐침 결과. 보완 지시 19·REQ-HF-32의 방식 선택 자료이며 **TASK-32 설계 확정이나 제품 완료 판정이 아니다.** 제품 코드는 변경하지 않았다. 필요한 증거 수준 2, 도달 수준 2다.

## 결론과 추천

**[제안] 방식 (b), 서버의 루프백 대시보드 백엔드를 문이 호출하는 경로를 기본으로 권한다.** 실제 CLI로 백엔드를 띄워 토큰 인증·프로필별 조회·쓰기까지 확인했다. 도구·환경값·MCP·OAuth의 공식 저장 책임을 그대로 쓰고, 대시보드의 모듈 전역 상태를 게이트웨이에서 분리할 수 있다. 설치 도우미의 백엔드 수명·토큰 보관·기동 실패 처리는 TASK-32 계획에서 확정해야 한다. 자동으로 운영 서버에 설치하지 않았다.

- (a)는 같은 Python 이벤트 루프에서 공식 라우터 함수를 호출할 수 있지만 내부 함수·대시보드 전역 변수·스킬 모듈 잠금에 의존한다. 제품 문에 아직 붙이지 않았고, 실제 게이트웨이에서 Hermes 대화와 동시에 돌리는 검증은 하지 않았다.
- (c)는 도구 켜기·끄기와 환경값 쓰기·지우기는 가능하다. MCP 추가·인증은 대화형 입력이 남아 있고 OAuth는 출력과 대기형 CLI다. 모든 관리 동작을 위한 비대화 JSON 계약으로 채택하기 어렵다. 비밀값을 `config set` 인수로 넘기는 방식은 값이 프로세스 인수에 남으므로 채택하면 안 된다.
- team-kit이 제공하는 연결은 **그 명령의 문서를 받아 처리**할 수 있다. 공식 환경값 경로와 team-kit 조립 설정을 서로 덮어쓰지 않는 구분은 기존 설계대로 필요하다.
- **그대로 전달하면 안 되는 응답이 있다.** 임의의 예외 문자열·토큰 미리보기·원시 작업 로그를 앱이나 행동 기록으로 전달하지 않도록 문에서 허용 필드·이유 코드만 선택해야 한다. `configured`를 곧바로 “필요 키 충족”으로 번역해서도 안 된다.

## 환경과 검증 범위

| 항목 | 직접 확인한 조건 |
|---|---|
| hejo 기준 | `39e45b55306eafa0b2c913665273d74722c77794`, 시작 작업 트리 깨끗함 |
| Hermes 읽기 전용 소스 | `ebb026eef8e800e1b7471ed147b7287e878f8aa4`; 아래 핵심 라우터·범위·게이트웨이 파일의 HEAD 대비 변경 없음 |
| team-kit 읽기 전용 소스 | 운영 저장소 사본 `208f6e6322f593729c9ef6ac16ac903be4c3692b`; 명령·connections·connection_secrets·gateway_restart의 HEAD 대비 변경 없음 |
| 실행 | Hermes venv Python 3.14.7, 임시 `HERMES_HOME`·`HERMES_ROOT`, 기본+`alpha`+`beta` 가짜 프로필 |
| 의존성 조건 | 원래 venv에는 `fastapi`·`pydantic`가 없어 첫 import 실패. 본체·venv 대신 `.build/task31/deps`에만 설치. Hermes `pyproject.toml:495`의 web 핀(fastapi 0.133.1, uvicorn 0.41.0, starlette 1.3.1, python-multipart 0.0.32) 사용. 설치 로그에 전이 의존성 기록 |
| 격리 | 부모 환경의 인증 변수를 넘기지 않음. 탐침 자식에 감사 훅을 적용해 임시 폴더 밖 쓰기·운영 개인 파일 읽기·비루프백 접속·서비스 신호 차단. Python 바이트코드 저장·지연 설치 끔 |
| 실제 실행 | 프로필 범위·공식 설정/환경값 파일 쓰기·삭제, 도구 목록·토글, MCP 설정 목록·추가, 루프백 백엔드와 토큰/Host 검사, 드레인 표식 생성·취소, team-kit 명령 진입·런타임 재실행·JSON/표준 입력 |
| 대역 | 공급자 HTTP, 외부 CLI 자격증명 상태, MCP 원격 전송·OAuth 작업자, 서비스 관리자 실행. 승인 상태를 넣은 라우터 시험과 실제 공급자 시작 함수 시험을 별도 기록 |
| 미실행 | 실제 공급자 동의·토큰 교환/갱신, 실제 MCP 서버 연결, 운영 설치·게이트웨이 재시작, 실제 문/앱 재연결과 두 Mac 실물. Slack 발송 없음 |

원본은 읽기만 했다. `.build/task31`의 탐침 코드·가짜 홈·로그는 추적하지 않는다. 앱 변경·빌드·배포·공용 릴리스 갱신은 이 읽기 전용 탐침에 해당하지 않는다. 기존 TASK-24 검사·적용을 반복하지 않았다.

## 방식별 실행 결과

표의 **실행**은 공식 함수/파일 또는 실제 루프백 HTTP를 뜻한다. **대역**은 그 경계의 성공 흐름을 확인했으며 실제 외부 서비스 성공을 뜻하지 않는다. **부분**은 아래의 실패·제약이 있다.

| 기능 | (a) 같은 프로세스 함수 | (b) 루프백 백엔드+토큰 | (c) Hermes CLI |
|---|---|---|---|
| 도구 묶음·켜짐·키 상태 | 세 프로필 각 28행, enabled/available/configured/tools 등 실제 반환. 필요한 특정 키의 프로필별 존재 확인 | 실제 HTTP 200, 세 프로필 각 28행 | 세 프로필 `tools list` 종료 0. 화면용 텍스트이며 라우터의 키/제공자 상태와 같은 JSON은 아님 |
| 켜기·끄기 | `memory` off/on, 다른 두 프로필 유지 | `PUT /api/tools/toolsets/memory` 200, 지정 프로필 쓰기 | `tools disable/enable memory` 각 0 |
| 비밀값 쓰기·지우기 | 공식 `/api/env` 함수로 세 프로필 저장, 한 프로필 삭제, 다른 값 보존 | `PUT`/`DELETE /api/env` 200, 대상 파일 분리 | `config set/unset` 0, 임시 `.env` 적용. 입력용 stdin 옵션 없음; 값이 argv에 들어감 |
| MCP 목록·추가 | alpha 추가, beta 목록 비어 있음 | `/api/mcp/servers` GET/POST 200, beta에 별도 이름 추가 | `mcp list` 0. `mcp add`는 인증 질문·비밀 입력, 5초 외부 제한으로 종료 |
| MCP 시험 | 공식 라우터+전송 대역의 도구 목록 반환; 실패 문구 노출 재현 | 공식 시험 라우터 HTTP 200, 전송 대역 | 연결 불가능한 가짜 루프백 대상 `mcp test`는 5초 제한. 전체 전송 성공 미확인 |
| MCP OAuth 시작·상태·콜백 | 실제 flow 레지스트리·대상 홈·상태 검사, 원격 작업자만 대역. 잘못된 state 404, 맞는 콜백 200·approved | 시작·상태·콜백 HTTP 확인, 원격 작업자 대역 | `mcp login --help` 0. 실제 인증은 대화형/브라우저 경로라 미실행 |
| OAuth 제공자 목록·시작·폴링 | 목록과 8개 제공자 분기 실행. 장치 코드 4개 start/poll, 다른 profile poll 400; 공급자 대역 | 목록과 장치 코드 4개 start/poll 200, 다른 profile poll 400; 공급자 대역 | `auth add --help` 0. Nous 가짜 루프백 시작은 연결 거절로 1, 원시 traceback 포함. 별도 JSON start/poll 명령은 확인 못 함 |
| 다시 시작 | 공식 라우터에서 서비스 실행만 대역, `{ok,pid,name}` 반환 | HTTP 재시작 서비스 대역, 같은 반환 | 실제 CLI restart 분기에서 서비스 관리자 호출만 대역, 0. 실제 서비스 변경 없음 |
| 드레인 | 실제 `.drain_request.json` 생성·취소 | 실제 HTTP drain/cancel로 표식 확인 | 독립 `gateway drain` 하위 명령 없음. restart의 서비스별 graceful drain 경로는 소스 확인, 실제 서비스 드레인 미실행 |

### 프로필·비밀 범위와 실패 관측

1. **[확인] 프로필 격리:** `_config_profile_scope`에서 홈과 비밀 contextvar를 함께 전환·복원한다. 세 프로필 60개 읽기를 작업자 6개에서 병행해 자기 값만 읽었다. API/CLI 쓰기도 명시적 프로필을 사용했다. MCP OAuth flow의 대상 홈은 alpha였고 OAuth 공급자 poll의 beta 접근은 400이었다. “같은 게이트웨이의 실제 동시 대화” 검증으로 확대 해석하지 않는다.
2. **[확인] 인증:** 실제 백엔드를 `dashboard --no-open --skip-build --host 127.0.0.1 --port <임시 포트>`로 기동. `X-Hermes-Session-Token` 없으면 목록·OAuth poll 모두 401, 잘못된 Host는 400. 세션 토큰은 모든 관리 권한을 가지므로 앱으로 배포하지 말고 문만 사용해야 한다. 프로필별 권한 확인은 hejo가 별도로 맡아야 한다.
3. **[실패] 오류 비노출을 일반적으로 보장하지 않음:** alpha의 공식 환경값 경로에 넣은 가짜 값과 같은 문자열로 예외를 주입했다. MCP 시험의 `error`, OAuth 시작 500 `detail`에 그 문자열이 남았다. OAuth 시작은 Python 로그에도 traceback을 남긴다. 공급자별 redactor가 일부 헤더/형식을 가리는 것과 모든 비밀값·경로의 비노출은 다르다. 원본 수정 없이 허용 필드·이유 코드로 변환하고 원시 예외를 hejo 로그에 복사하지 않아야 한다. 기존 대시보드 자체 로그의 비노출까지 충족할 방법은 계획 담당이 검토해야 한다.
4. **[확인] 키 유무와 사용 가능은 다름:** `FIRECRAWL_API_URL`은 alpha만 보유했지만 도구 목록의 web `configured`는 세 프로필 모두 true였다. `_toolset_has_keys`가 키 없는 managed provider 행도 `all([])`로 참으로 계산하는 경로다. 서버의 공식 제공자별 상태와 필요한 env 이름의 **존재 여부**를 사용하고, 값·미리보기는 전달하지 않는 설계가 필요하다. 키 검증 API는 저장과 분리돼 있으므로 저장 성공도 실제 연결 성공이 아니다.
5. **[부분] MCP:** 라우터의 설정 저장·프로필 분리는 실제 실행했다. 도구 발견과 OAuth 승인 작업자는 대역이다. CLI의 연결 실패·대화형 입력·제한시간 만료를 성공으로 세지 않았다. 초기 venv와 탐침 의존성만으로 전체 MCP 런타임 준비가 끝났다고 주장하지 않는다.
6. **[부분] 설치별 목록:** 일부 브라우저·이미지 제공자 플러그인은 `requests` 미설치로 로드에 실패했다(로그에 기록). 28행은 이번 격리 환경에서 받은 값이며 모든 설치의 완전한 제공자 수가 아니다. 설치 도우미가 관리 런타임과 제공자 의존성을 준비하는 범위도 계획 검토에 남긴다.

## 다른 Mac에서 OAuth를 끝내는 흐름

공급자 목록은 현재 소스의 8행이다. API가 외부 CLI로 분류한 제공자를 앱에서 임의로 우회하지 않는다. 실제 계정 동의는 하지 않았다.

| 제공자 | 공식 대시보드 경로 | 다른 Mac의 동의·종료 | `/submit` | 루프백 콜백 중계 |
|---|---|---|---|---|
| Nous Portal | device_code | 서버가 시작·폴링, 다른 Mac에서 verification URL+코드 동의 | 400 | 장치 코드에는 불필요. guest 승격 분기는 이번 실행에서 미검증 |
| OpenAI Codex | device_code | 같은 흐름. 공급자 계정의 장치 인증 허용 조건은 실제 확인 필요 | 400 | 대시보드 흐름에는 불필요. CLI `--browser`의 localhost:1455/auth/callback은 별도 경로이며 중계 미구현·미검증 |
| MiniMax | device_code+PKCE 결합 | 서버가 verifier/state를 보유, 다른 Mac에서 URL+코드 동의 | 400 | 불필요. PKCE라고 붙여넣기 흐름으로 바꾸지 않음 |
| xAI | device_code | 서버 시작·폴링, 다른 Mac URL+코드 동의 | 400 | 불필요 |
| Qwen OAuth | external | 기존 Qwen CLI 자격증명을 서버에서 사용. 현재 대시보드 start 400 | 400 | 앱에서 끝내는 공식 중계 경로 확인 못 함 |
| GitHub Copilot ACP | external | 서버의 `copilot login` 안내. 대시보드 start 400 | 400 | 앱 중계 미지원·실제 CLI 인증 미실행 |
| Anthropic | external | 서버의 공식 `hermes auth add anthropic` 안내. 대시보드 start 400 | 400 | 대시보드에서 자동 발급하는 경로 없음 |
| Claude Code | external | 서버의 `claude setup-token` 안내. 대시보드 start 400 | 400 | 대시보드에서 자동 발급하는 경로 없음 |
| MCP OAuth(제공자별 서버) | auth URL+state+callback | 서버 flow가 URL을 주고 콜백의 code/state/iss를 받음. 잘못된 state 거절 확인 | 공급자 `/submit`과 별개 | **[제안]** 앱의 로컬 수신기가 콜백 query를 문으로 보내고, 문이 원래 서버의 callback에 전달. 원래 redirect URI·포트·state·1회성 검증을 유지해야 함. 공급자 등록 redirect 제한과 포트 충돌은 미검증 |

추가 실행에서는 실제 `_start_device_code_flow`와 네 공급자 시작 함수를 사용하고 HTTP client만 가짜로 바꿨다. Nous·Codex·xAI의 요청 필드와 MiniMax의 PKCE/state 검사를 통과했다. MiniMax 2000ms→2초 변환도 확인했다. poll 작업자는 실행하지 않거나(Codex 이외) 승인 없음으로 종료(Codex `expired`)시켰으며, 실제 토큰 교환·저장을 검증한 것은 아니다. 라우터의 approved 시험은 별도의 상태 대역이다.

## 재시작 뒤 앱에 결과를 주는 방법

**[확인] 재시작 응답의 PID/종료 0은 채널 재연결 성공이 아니다.** 대시보드 재시작 API는 `name=gateway-restart`만 돌려준다. `/api/actions/gateway-restart/status`는 작업자 상태와 로그를 읽을 수 있지만 레지스트리는 메모리이고, `hermes-update`와 달리 gateway restart에는 영속 완료 영수증이 없다. 백엔드도 재시작되면 exit code를 잃을 수 있다. 로그 원문은 비밀 비노출 응답으로 쓰면 안 된다.

**[제안, TASK-32 계획 확정 필요]** 문은 기존 행동 기록에 재확인한 요청과 미완료 작업 식별자를 먼저 남긴다. 재연결한 앱은 그 식별자로 결과를 다시 요청한다. 문은 이전 프로세스의 “connected”를 재사용하지 말고, 새 게이트웨이의 PID/시작 시각이 맞는 공식 runtime 상태와 활성 프로필별 플랫폼을 확인해 수를 계산한다. 결과도 행동 기록에 남겨 중복 재시작 없이 다시 전달한다. `unknown`·부분 복구·제한시간 만료를 구분해야 한다. 새 연결 상태 원본이나 독자적인 채널 목록은 만들지 않는다.

- 공식 `_spawn_gateway_restart`는 진행 중 요청·짧은 cooldown을 합치고, 보조 프로필이 기본 multiplexer에서 돌면 기본 프로필 재시작으로 보낸다. 기존 60분 제한·재확인·처리 중 거절을 대신하지 않는다.
- drain API는 표식을 쓸 뿐 실제 watcher의 드레인 종료를 기다리지 않는다. restart는 drain의 force override다. drain 요청 직후 restart를 보내는 동작을 “유휴 상태 확인”으로 간주하면 안 된다.
- team-kit `gateway_restart.restart`는 실행 중 turn lease를 확인하고, 재시작 이후 새 로그의 시작 표식 뒤 채널 연결만 센다. 가짜 runner가 새 로그를 만들었을 때 3개 복구, busy 거절, 새 사건이 없을 때 `NOT_RECONNECTED`·0개를 확인했다. 실제 서비스·문 연결 단절·앱 재연결은 미검증이다.

## team-kit 명령 탐침

읽기 전용 운영 저장소의 `hermes/bin/hermes-connections` 진입점을 그대로 실행했다. 임시 홈의 `installs/*/facts.json`으로 Hermes venv를 찾게 했고 실제 `execv` 재실행을 거쳤다. 원본 lib 경로는 탐침 자식의 `PYTHONPATH`로만 제공했다. 원본 파일과 운영 설치는 수정하지 않았다.

| 입력/고장 | 관측 |
|---|---|
| `status --json` | 0, `schema=hermes-connections/1`, 가짜 프로필 3개 |
| `secret guide` | 0, 허용 입력 필드·안내 반환, 값 없음 |
| `secret set`, 가짜 JSON stdin | 0, `outcome=done`, alpha `.env` 0600 저장. Notion HTTP만 대역, beta 불변 |
| `secret undo` | 0, `done`, 이전 파일 값 복원 |
| 16,385자 stdin | 프로세스 0이나 `refused/FORMAT_INVALID`; 실행 종료 코드만으로 성공 판정하면 안 됨 |
| 가짜 예외 주입 | 프로세스 1, 고정 `CONNECTIONS_READ_FAILED`, 원시 문자열·값 미노출 |
| 시작 지연 주입 | 호출자의 0.4초 제한으로 중단. 일반 명령 호출은 5초 제한. 제품의 작업별 시간 제한은 계획에서 확정 |

비밀값은 명령 인수에 없었고 stdout/stderr에도 없었다. guide/set/undo 응답은 상태 문서 전체가 아니므로 행동 결과를 처리한 뒤 `status --json`을 다시 받아야 한다. 문에서 명령을 대행할 때 고정 허용 하위 명령·프로필 검증·한정된 stdin·작업별 제한시간을 써야 한다. 실제 명령의 내부 재시작 제한(90초)+채널 대기(120초)를 5초 탐침 제한으로 제품에 복사하지 않는다. 비밀값의 실패 경로·자식 종료·재접속 후 결과 복구는 TASK-32 수락 시험에 포함할 검토 사항이다.

## 근거 위치와 재현 기록

아래 소스 위치는 해당 저장소 기준 상대 경로다. 운영자의 실제 경로·계정·비밀값을 문서에 담지 않는다.

| 책임 | 근거 파일·줄 |
|---|---|
| 프로필·비밀 범위/스킬 전역 잠금 | Hermes `hermes_cli/web_server_profiles.py:243`, `:277`; `hermes_cli/web_deps.py:28` |
| 도구 목록·토글·키 판정 | Hermes `hermes_cli/web_routers/tools.py:230`, `:280`; `hermes_cli/tools_config.py:754`, `:759`; `tools_config_providers.py:130` |
| 공식 환경값 쓰기·삭제 | Hermes `hermes_cli/web_routers/config_env.py:327`, `:1036`; `hermes_cli/credential_lifecycle.py:163`, `:202` |
| MCP 설정·시험·OAuth | Hermes `hermes_cli/web_routers/mcp.py:95`, `:111`, `:205`, `:255`, `:314`, `:340`; `hermes_cli/mcp_config.py:120`; `tools/mcp_dashboard_oauth.py:42` |
| OAuth 목록·분기·submit·poll·오류 | Hermes `hermes_cli/web_server_oauth.py:144`; `hermes_cli/web_routers/oauth.py:419`, `:501`, `:528`, `:564`, `:670`, `:793`, `:845`, `:854` |
| 루프백 토큰·Host·API 인증 | Hermes `hermes_cli/web_server.py:367`, `:452`, `:478`, `:625`, `:697`; `hermes_cli/subcommands/dashboard.py:16` |
| 드레인·재시작·상태 | Hermes `hermes_cli/web_routers/actions.py:140`, `:167`, `:346`; `hermes_cli/web_server.py:907`; `hermes_cli/web_server_gateway.py:139`, `:519`; `gateway/status.py:1595` |
| CLI 가능 범위·대화형 MCP | Hermes `hermes_cli/subcommands/tools.py:8`, `subcommands/config.py:27`, `subcommands/auth.py:8`, `subcommands/mcp.py:27`; `hermes_cli/config.py:3611`; `hermes_cli/mcp_config.py:611`; `hermes_cli/gateway.py:5543`; `hermes_cli/gateway_launchd.py:768` |
| team-kit 문서·stdin·고정 오류 | 운영 저장소 `hermes/bin/hermes-connections:8`; `hermes/plugin-store/team-kit/lib/hermes_facility/connections.py:276`, `:416`, `:460`; 같은 디렉터리 `connection_secrets.py:86`, `:197`; `gateway_restart.py:29`, `:57`, `:117` |

| 직접 실행한 명령 | 결과·로컬 로그 |
|---|---|
| `python3 .build/task31/launch.py probe` | 0; `.build/task31/probe.log`, `probe-results.json` (오류 주입의 traceback은 예상 관측) |
| `python3 .build/task31/launch.py backend` | 0; `.build/task31/backend.log`, `backend-server.log`, `backend-results.json` |
| `python3 .build/task31/launch.py provider_starters` | 0; `.build/task31/provider_starters.log`, `provider-starters-results.json` |
| `python3 .build/task31/launch.py cli_matrix` | 0; `.build/task31/cli_matrix.log`, `cli-results.json`, `cli-*.log`; 개별 명령의 실패/시간 만료는 위 표대로 |
| `python3 .build/task31/launch.py team` | 0; `.build/task31/team.log`, `team-results.json`, `team-*.log` |
| `python3 .build/task31/launch.py reconnect` | 0; `.build/task31/reconnect.log`, `reconnect-results.json` |

탐침 절차는 `launch.py`의 환경 격리·가짜 홈 생성 → `guard.py` → 각 탐침 모듈 순서다. 외부 작업자 대역은 `api_stubs.py`, team-kit 자식용 대역은 `team.py`가 생성하는 `child/sitecustomize.py`에 있다. 탐침 스크립트를 제품 설치물에 포함하지 않는다. 계획 담당은 (b)의 로그 비노출 처리 가능 여부, external 제공자 UX, MCP 콜백 중계, 영속 재시작 결과의 칸을 확정한 뒤 TASK-32를 인계할 것. TASK-20부터 이어가는 작업은 이번 탐침 검토 뒤에 한다.
