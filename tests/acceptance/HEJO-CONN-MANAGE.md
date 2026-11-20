# HEJO-CONN-MANAGE 수락 시험 명세

1판 · 2026-11-20 · 명세 [spec.md](../../docs/changes/HEJO-CONN-MANAGE-20261120/spec.md), 설계 [design.md](../../docs/changes/HEJO-CONN-MANAGE-20261120/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 대기. 기대값 출처: spec 요구와 design 2~5절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통: 임시 `HERMES_HOME`, 가짜 직원 `alpha`·`beta`, 가짜 주소·가짜 아이디·가짜 토큰 문자열, 가짜 team-kit 명령(문 시험), 가짜 문서(앱 시험). 실제 토큰·직원 id·주소·경로 금지. "바이트 그대로"는 실행 전후 sha256 비교.

## team-kit (`HD` worktree `hermes/plugin-store/team-kit/tests/`의 새 시험 파일, 이름은 구현 담당)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-CM-01 | CM-03.AC-01, NFR-CM-01·02 | alpha에 시놀로지 앱 연결됨(금고에 가짜 `api_base`·`link_host`·`sync_root`·`scope` 2개·`login_selected:true`, `.env`에 가짜 아이디·비밀번호 이름), 노트 앱(쓸 곳 1개) 연결됨, 저장 값 없는 앱 1개 연결됨. `apps --json` 실행 | 시놀로지 항목 `settings`의 `step` 순서 = `address, login, sync_root, values`, `login`의 `value`="저장됨", 비밀번호 문자열·`.env` 값 없음, 주소 값은 호스트 이름만. 노트 앱은 `values` 하나. 저장 값 없는 앱은 `settings` 없음 또는 빈 목록. 실행 전후 가짜 홈 전체 sha256 동일 |
| AT-CM-02 | CM-03.AC-02 | AT-CM-01 상태에서 `app connect --change values`(값 없음) | 응답 `next.kind:'choose_scope'`, `selected`에 지금 고른 2개의 옵션 id. 비밀번호 칸 없음, 주소 단계 아님 |
| AT-CM-03 | CM-03.AC-03·05 | AT-CM-02에 이어 쓸 곳 1개만 골라 제출 | `outcome` 완료(또는 기존 규칙상 다시 시작 대기). 금고 alpha 시놀로지 값에서 `scope`만 바뀌고 `api_base`·`link_host`·`sync_root`·`login_selected`는 같음. `.env`·beta 값·명부 바이트 그대로. 되돌리기(`app undo`) 하면 금고·설정이 바꾸기 전 바이트로 |
| AT-CM-04 | CM-03.AC-02 | AT-CM-01 상태에서 `--change sync_root` | 응답이 동기화 폴더 고르기(`choose_sync_root`), 비밀번호 칸 없음(가짜 로그인 함수 호출 1회 이하, 비밀번호 입력 요구 없음) |
| AT-CM-05 | CM-03.AC-02 | `--change login` | 응답이 로그인 단계, 아이디 칸 `value`=저장된 가짜 아이디, 비밀번호 칸은 보안 칸·값 없음 |
| AT-CM-06 | CM-03.AC-04 | AT-CM-02 뒤 제출하지 않고 끝냄. 이어서 `status`·`apps` | 명부·조립 설정·금고 `apps` 값 바이트 그대로, 앱은 `connected`. 진행 기록은 기존 규칙대로 `progress`로 보임 |
| AT-CM-07 | CM-03 | 연결 안 된 앱에 `--change values` / 표에 없는 단계 `--change foo` | 둘 다 `INVALID_ARGUMENTS`, 파일 변경 없음 |
| AT-CM-08 | CM-02.AC-02·03 | AT-CM-01 상태에서 `app disconnect` → 다시 시작 대기 완료 처리 → `app connect`(값 없음) | 해제 뒤 명부에서 빠지고 금고 alpha 시놀로지 값·`.env` 바이트 그대로. 다시 연결 응답은 사람 입력 단계(`secret_set`·`choose_*`) 없이 저장 또는 다시 시작 단계로 감 |
| AT-CM-09 | CM-02.AC-02·03·06, CM-01.AC-01 | alpha 설정에 Google(가짜 회사 계정 매핑), X(`x_read.enabled:true`), Instagram(`plugins.enabled`에 `instagram-dm`). 각각 `account disconnect` | 그때마다 alpha `config.yaml`만 바뀜: Google은 `team-delegation.settings.gmail.enabled:false`(계정 값 그대로), X는 `x_read.enabled:false`, Instagram은 `plugins.enabled`에서만 빠지고 `entries.instagram-dm` 그대로. 금고·`.env`·토큰 파일·beta 파일 바이트 그대로. 응답 `next.kind:'gateway_restart'`. `status`의 그 줄 `state:'off'`, 동작 `account_connect` 하나(주) |
| AT-CM-10 | CM-02.AC-03·05 | AT-CM-09 뒤 (가) `account connect` (나) 따로 시작한 해제에 10분 안 `account undo` (다) 그사이 `config.yaml`을 바꾼 뒤 `account undo` (라) 10분 지난 뒤 `account undo` | (가)(나) `config.yaml`이 해제 전 바이트로. (다) `UNDO_CONFLICT`, 파일 그대로. (라) `UNDO_EXPIRED` |
| AT-CM-11 | CM-02.AC-04 | `account disconnect` 중 `config.yaml` 원자 쓰기에서 예외 주입 | 파일 해제 전 바이트, 줄 상태 그대로, 이유 코드 응답 |
| AT-CM-12 | CM-02.AC-07 | AT-CM-09 상태의 설정으로 (가) team-delegation 도구 등록 함수 실행(가짜 등록기) (나) `news_watch.fetch_x` (다) Instagram 직접 싣기 3곳 (라) `personal_scopes.install_mail`·`wait_jobs.account`·`personal_review`·`mail_index`의 계정 결정 | (가) alpha에 `gmail_direct`·`google_reauth`·`google_calendar_*`·Google 쪽 `calendar_direct_*` 없음(X 도구도 없음) (나)(다)(라) 그 서비스를 건너뜀(호출 기록 없음). 같은 시험을 켜짐 설정으로 돌리면 지금과 같은 등록·호출 |
| AT-CM-13 | CM-02.AC-06 | 개인 역할 직원 beta 홈에 가짜 개인 토큰, alpha가 개인 Google을 씀. beta의 Google `account disconnect` | beta `config.yaml`만 바뀜. alpha의 토큰 위치 결정(`token_home`)·도구 등록은 그대로 |
| AT-CM-14 | design 3.2 | Drive·Sheets·Docs 확정 결과 (가)면 그 등록 지점, (나)면 끈 스킬 목록 | (가) 꺼짐에서 등록 없음 (나) 해제 때 목록에 `google-workspace` 추가, 연결·되돌리기 때 해제 전 바이트(원래 목록에 있었으면 연결 뒤에도 있음) |
| AT-CM-15 | CM-01.AC-03, NFR-CM-03 | 채널 줄(slack·photon)에 `account disconnect` | 거부(`INVALID_ARGUMENTS` 또는 기존 `invalid_action`), 파일 변경 없음 |
| AT-CM-16 | 회귀 | team-kit 기존 연결·앱 연결·Google·X·Instagram 시험 | 전부 통과 |

## 문 (`tests/acceptance/test_conn_manage.py`, 새 파일)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-CM-20 | CM-01.AC-01, design 2.4 | 가짜 `apps`: alpha 연결됨 앱 A(`settings` 2개), 연결됨 앱 B(`settings` 없음, 합칠 계정 줄 없음), 연결 가능 앱 C | A 주 동작 `app_connect` "설정 바꾸기", 다른 동작에 `app_disconnect` "해제". B 주 동작 없음, "해제" 있음. C 주 동작 "연결". 어떤 줄에도 "범위 바꾸기" 라벨 없음. A 줄에 `settings`가 그대로 전달됨 |
| AT-CM-21 | CM-04.AC-01 | 가짜 `status`에 alpha `synology`(group account, 직접 확인 기록 있음)·`notion` 줄, 가짜 `apps`에 alpha 시놀로지 앱(연결됨, `links`에 alpha `synology`)·Notion 앱(연결됨, `links`에 alpha `notion`) | 표에 `team:synology`·`team:notion` 없음. 두 앱 줄에 `check` "확인", 시놀로지 앱 줄 상태는 계정 줄의 직접 확인 결과(`verified_by` 포함) |
| AT-CM-22 | CM-04.AC-01 | AT-CM-21 표에서 시놀로지 앱 줄 `check` 요청 | 가짜 team-kit에 `check --profile alpha --connection synology` 한 번 |
| AT-CM-23 | CM-04.AC-02 | alpha 앱 연결 없음(`links` 없음), `synology` 계정 줄만 | `team:synology` 줄 그대로(동작도 지금 그대로) |
| AT-CM-24 | CM-03.AC-02 | 앱 줄에 `app_connect`, `values: {change: 'values'}` / `{change: 'foo'}` | 첫째는 가짜 team-kit 인자에 `--change values`, `change`가 표준 입력 값에 없음. 둘째는 `invalid_action`, 명령 실행 없음 |
| AT-CM-25 | CM-02, design 3.3 | team 줄 `account_disconnect`·`account_connect`·`account_undo`(줄에 그 동작이 있을 때) / 줄에 없는 동작 | 가짜 team-kit 인자 `account disconnect|connect|undo --profile alpha --connection <id> --json`. 없는 동작은 `invalid_action`. 재확인(`reauth`) 없는 요청은 `reauth_required` |
| AT-CM-26 | NFR-CM-01 | AT-CM-20~25 실행 중 문 로그·감사 기록 | 단계 id·동작 id만, `settings`의 `value` 문자열·가짜 주소·가짜 아이디 없음 |
| AT-CM-27 | 회귀 | `tests/acceptance/test_connections_screen.py`, `gate/tests` | 전부 통과(라벨 "범위 바꾸기" 기대가 있으면 이 설계로 바뀐 것만 기록) |

## 앱 (`app/Tests/ConnectionsTests.swift`)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-CM-30 | CM-01.AC-02 | 줄: 주 동작 "설정 바꾸기", 다른 동작 "해제"·"되돌리기" | 목록 줄에 주 버튼과 "⋯" 메뉴. 메뉴 항목 라벨 = 다른 동작 라벨. 다른 동작 없는 줄에는 "⋯" 없음 |
| AT-CM-31 | CM-02.AC-01 | "해제" 선택, 주입한 확인 함수가 (가) 거절 (나) 수락, 재확인 함수 수락 | (가) 프레임 없음, 재확인 호출 없음 (나) 확인 → 재확인 순서로 호출, `app_disconnect`(계정 줄은 `account_disconnect`) 프레임 한 번, `reauth:true`. 확인 문장에 "넣어 둔 값은 남아" 포함 |
| AT-CM-32 | CM-03.AC-01 | 자세히 화면, 줄 `settings` 3개 | "지금 설정" 절에 라벨·값 3줄과 "바꾸기" 3개 |
| AT-CM-33 | CM-03.AC-01·02 | (가) "바꾸기"(단계 `sync_root`) (나) `settings` 1개인 줄의 주 동작 "설정 바꾸기" | (가) `app_connect` 프레임 `values == {change:'sync_root'}` (나) 자세히 화면 거치지 않고 같은 모양의 프레임(그 단계) |
| AT-CM-34 | CM-03.AC-02 | 응답 `next:{kind:'choose_scope', options:[a,b,c], selected:[a,c]}` | 입력 창에서 a·c가 미리 선택 |
| AT-CM-35 | CM-05.AC-01 | 재확인 함수(주입)가 끝날 때 앱을 비활성으로 만든 상태를 흉내(시험용 활성화·앞으로 가져오기 함수 주입) (가) 성공 (나) 취소. 입력 창 열림/닫힘 두 경우 | 두 경우 모두 확인 뒤 활성화 함수 1회 호출, 연결 창(입력 창이 있으면 입력 창)이 key·보임 |
| AT-CM-36 | CM-05.AC-02 | 재확인 진행 중 | 연결 창 높이 `.normal`(지금 규칙 유지) |
| AT-CM-37 | 회귀 | 기존 `ConnectionsTests` | 전부 통과 |

## 사장 확인 (운영 적용 뒤, 실물)

| ID | 내용 | 합격 |
|---|---|---|
| M1 | 한 직원의 시놀로지 줄이 하나이고, 설정 바꾸기 → 폴더 고르기만 바꿈 | 비밀번호를 묻지 않고, 바꾼 폴더로 파일 도구가 동작 |
| M2 | 한 Mac 앱 해제 → 다시 연결 | 값을 다시 묻지 않고 연결됨 |
| M3 | 맥북에서 해제·설정 바꾸기 중 지문·암호 확인 | 확인 뒤 연결 창이 앞에 남고 다음 단계가 보임 |
| M4 | Google(테스트용으로 고른 직원 하나) 해제 → 다시 시작 → 그 직원에게 메일 확인 요청 | Google을 쓰지 않는다고 답함. 다른 직원 Google은 정상. 다시 연결 → 다시 시작 뒤 정상 |
