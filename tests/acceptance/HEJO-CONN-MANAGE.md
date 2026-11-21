# HEJO-CONN-MANAGE 수락 시험 명세

4판 · 2026-11-20(계획 검증 1·2회차, 구현 검증 2차 V-3 반영) · 명세 [spec.md](../../docs/changes/HEJO-CONN-MANAGE-20261120/spec.md), 설계 [design.md](../../docs/changes/HEJO-CONN-MANAGE-20261120/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1회차 BLOCKED → 2판, 2회차 BLOCKED → 3판 반영, 재검증 대기. 기대값 출처: spec 요구와 design 2~5절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통: 임시 `HERMES_HOME`, 가짜 직원 `alpha`·`beta`, 가짜 주소·가짜 아이디·가짜 토큰 문자열, 가짜 team-kit 명령(문 시험), 가짜 문서(앱 시험). 실제 토큰·직원 id·주소·경로 금지. "바이트 그대로"는 실행 전후 sha256 비교.

## team-kit (`HD` worktree `hermes/plugin-store/team-kit/tests/`의 새 시험 파일, 이름은 구현 담당)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-CM-01 | CM-03.AC-01, NFR-CM-01·02 | alpha에 시놀로지 앱 연결됨(금고에 가짜 `api_base`·`link_host`·`sync_root`·`scope` 2개·`login_selected:true`, `.env`에 가짜 아이디·비밀번호 이름), 노트 앱(쓸 곳 1개) 연결됨, 저장 값 없는 앱 1개 연결됨. `apps --json` 실행 | 시놀로지 항목 `settings`의 `step` 순서 = `address, login, sync_root, values`, `login`의 `value`="저장됨", 비밀번호 문자열·`.env` 값 없음, 주소 값은 호스트 이름만. 노트 앱은 `values` 하나. 저장 값 없는 앱은 `settings` 없음 또는 빈 목록. 실행 전후 가짜 홈 전체 sha256 동일 |
| AT-CM-02 | CM-03.AC-02 | AT-CM-01 상태에서 `app connect --change values`(값 없음) | 응답 `next.kind:'choose_scope'`, `selected`에 지금 고른 2개의 옵션 id. 비밀번호 칸 없음, 주소 단계 아님 |
| AT-CM-03 | CM-03.AC-03·05 | AT-CM-02에 이어 쓸 곳 1개만 골라 제출 | `outcome` 완료(또는 기존 규칙상 다시 시작 대기). 금고 alpha 시놀로지 값에서 `scope`만 바뀌고 `api_base`·`link_host`·`sync_root`·`login_selected`는 같음. `.env`·beta 값·명부 바이트 그대로. 되돌리기(`app undo`) 하면 금고·설정이 바꾸기 전 바이트로 |
| AT-CM-04 | CM-03.AC-02 | AT-CM-01 상태에서 `--change sync_root` | 응답이 동기화 폴더 고르기(`choose_sync_root`), 비밀번호 칸 없음(가짜 로그인 함수 호출 1회 이하, 비밀번호 입력 요구 없음) |
| AT-CM-05 | CM-03.AC-02 | `--change login` | 응답이 로그인 단계, 아이디 칸 `value`=저장된 가짜 아이디, 비밀번호 칸은 보안 칸·값 없음 |
| AT-CM-06 | CM-03.AC-04 | AT-CM-02 뒤 제출하지 않고 끝냄. 이어서 `status`·`apps` | 가짜 홈 전체 sha256 그대로(금고 `apps`·`app_setup`, 진행 기록 파일, `.env`, 설정, 명부). 앱은 `connected`, `progress` 없음 |
| AT-CM-07 | CM-03 | 연결 안 된 앱에 `--change values` / 표에 없는 단계 `--change foo` | 둘 다 `INVALID_ARGUMENTS`, 파일 변경 없음 |
| AT-CM-08 | CM-02.AC-02·03 | AT-CM-01 상태에서 `app disconnect` → 다시 시작 대기 완료 처리 → `app connect`(값 없음) | 해제 뒤 명부에서 빠지고 금고 alpha 시놀로지 값·`.env` 바이트 그대로. 다시 연결 응답은 사람 입력 단계(`secret_set`·`choose_*`) 없이 저장 또는 다시 시작 단계로 감 |
| AT-CM-09 | CM-02.AC-02·03·06, CM-01.AC-01 | alpha 설정에 Google(가짜 회사 계정 매핑), X(`x_read.enabled:true`), Instagram(`plugins.enabled`에 `instagram-dm`). 각각 `account disconnect` | 그때마다 alpha `config.yaml`만 바뀜: Google은 `team-delegation.settings.gmail.enabled:false`(계정 값 그대로), X는 `x_read.enabled:false`, Instagram은 `plugins.enabled`에서만 빠지고 `entries.instagram-dm` 그대로. 금고·`.env`·토큰 파일·beta 파일 바이트 그대로. 응답 `next.kind:'gateway_restart'`. `status`의 그 줄 `state:'off'`, 동작 id 집합 = {`account_connect`(주), `account_undo`}. 시계를 10분 넘기면 {`account_connect`(주)} |
| AT-CM-10 | CM-02.AC-03·05 | AT-CM-09 뒤 (가) 관계없는 칸(예: `display` 아래 가짜 키)을 바꾸고 11분 뒤(주입 시계) `account connect` (나) 따로 시작한 해제에 10분 안 `account undo` (다) 그사이 `config.yaml`을 바꾼 뒤 `account undo` (라) 10분 지난 뒤 `account undo` | (가) 꺼짐 칸만 켜짐으로(Google `gmail.enabled:true`, X `x_read.enabled:true`, Instagram 목록에 다시 있음), 관계없는 칸의 바뀐 값은 남음. (나) `config.yaml`이 해제 전 바이트로. (다) `UNDO_CONFLICT`, 파일 그대로. (라) `UNDO_EXPIRED`, 파일 그대로 |
| AT-CM-11 | CM-02.AC-04 | `account disconnect` 중 `config.yaml` 원자 쓰기에서 예외 주입 | 파일 해제 전 바이트, 줄 상태 그대로, 이유 코드 응답 |
| AT-CM-12 | CM-02.AC-07 | AT-CM-09 상태의 설정으로 (가) team-delegation 도구 등록 함수 실행(가짜 등록기) (나) `news_watch.fetch_x` (다) Instagram 직접 싣기 3곳 (라) `personal_scopes.install_mail`·`wait_jobs.account`·`personal_review`·`mail_index`의 계정 결정 | (가) alpha에 `gmail_direct`·`google_reauth`·`google_calendar_*`·Google 쪽 `calendar_direct_*` 없음(X 도구도 없음) (나)(다)(라) 그 서비스를 건너뜀(호출 기록 없음). 같은 시험을 켜짐 설정으로 돌리면 지금과 같은 등록·호출 |
| AT-CM-13 | CM-02.AC-06 | 개인 역할 직원 beta 홈에 가짜 개인 토큰, alpha가 개인 Google을 씀. beta의 Google `account disconnect` | beta `config.yaml`만 바뀜. alpha의 토큰 위치 결정(`token_home`)·도구 등록은 그대로 |
| AT-CM-14 | CM-02.AC-03, design 3.2 | (가) `skills.disabled` 없음 (나) `skills.disabled: ['다른스킬']` (다) `skills.disabled`에 이미 `google-workspace` (라) `skills.disabled`가 JSON 배열 문자열. 각각 Google `account disconnect` → 관계없는 칸 변경 → 11분 뒤 `account connect` | 해제 뒤: (가)(나)(라) `google-workspace` 들어가고 `gmail.off_added_skills == ['google-workspace']`, (다) 목록 그대로·표시 없음. 연결 뒤: (가)(나)(라) `google-workspace`만 빠지고(나는 `다른스킬` 남음) 표시 없음, (다) `google-workspace` 그대로. 넷 다 관계없는 칸 변경 남음. 설정 파일 기대값(증거 수준 2). 본체 소비자 확인은 AT-CM-14b로 따로 기록 |
| AT-CM-14b | CM-02.AC-07(Google 스킬) | AT-CM-14 (가)(라)의 해제 뒤·연결 뒤 가짜 홈을 `HERMES_HOME`으로 두고 Hermes venv Python에서 본체 `agent.skill_utils.get_disabled_skill_names()`를 실행(본체는 읽기·import만, 수정 금지) | 해제 뒤 집합에 `google-workspace` 있음, 연결 뒤 해제 전과 같은 집합. 실행할 수 없으면 이 시험은 `[미실행]`으로 기록하고 통과로 세지 않는다(AT-CM-14의 설정 파일 검사로 대신하지 않음). 그 경우 M4의 스킬 목록 확인이 유일한 소비자 증거다 |
| AT-CM-15 | CM-01.AC-03, NFR-CM-03 | 채널 줄(slack·photon)에 `account disconnect` | 거부(`INVALID_ARGUMENTS` 또는 기존 `invalid_action`), 파일 변경 없음 |
| AT-CM-17 | CM-02.AC-04·05(앱) | 앱 연결된 alpha에서 (가) `app disconnect` 중 원자 쓰기 예외 주입 (나) `app disconnect` 성공 뒤 10분 안 `app undo` | (가) 명부·설정·금고·`.env` 해제 전 바이트, 앱 `connected` (나) 명부·설정이 해제 전 바이트, 금고·`.env`는 내내 그대로 |
| AT-CM-18 | NFR-CM-01 | AT-CM-01~17·40~43 실행 중 표준 출력·표준 오류·team-kit 로그·기록 파일(`state/connections/*.json`) | 가짜 비밀번호·가짜 토큰 문자열 없음(기록 파일의 `.env` 전 바이트는 기존 0600 예외 규칙과 같게 이전 값만, 새로 넣은 비밀값 없음) |
| AT-CM-40 | CM-03.AC-02(주소) | alpha 시놀로지 연결됨(저장 주소 완전), 조립 설정의 `files.synology`에도 같은 주소, 다른 직원 beta의 연결·가짜 Drive Client 자료에 완전 후보 1개. `--change address`(값 없음) → 새 가짜 주소 제출 | 첫 응답이 주소 단계(`next.kind:'secret_set'`, 칸 id = `api_base`·`link_host`, `value` = 지금 저장 주소), 로그인 단계 아님, 고르기 옵션 없음. 제출 뒤 응답은 로그인 단계(아이디 미리 채움, 비밀번호 빈 보안 칸). 두 요청 동안 가짜 홈 sha256 그대로 |
| AT-CM-41 | CM-03.AC-02(Notion 로그인 열쇠) | alpha Notion 연결됨, `.env`에 가짜 열쇠, 가짜 확인 함수는 어떤 열쇠든 성공. (가) `apps` (나) `--change login`(값 없음) (다) 새 가짜 열쇠 제출 | (가) Notion `settings`에 `login`(라벨 "로그인 열쇠", 값 "저장됨"). (나) 응답이 열쇠 입력 단계(보안 칸 `token`, 값 없음), 저장 열쇠로 건너뛰지 않음, 파일 그대로. (다) 저장 완료, `.env`의 `NOTION_API_KEY`만 새 값, 되돌리기 기록 생김, 응답·로그에 열쇠 문자열 없음 |
| AT-CM-42 | CM-03.AC-04(비밀값) | alpha 시놀로지 연결됨. `--change address` → 새 주소 제출 → 로그인 단계에서 새 가짜 비밀번호 제출, 가짜 NAS 옵션에서 저장된 쓸 곳 하나가 사라져 고르기 단계에서 멈춤. 여기서 끝냄(창 닫기). 그다음 같은 바꾸기를 처음부터: 주소·아이디·비밀번호·쓸 곳을 모두 담아 제출 | 멈춘 시점: 가짜 홈 sha256 전부 그대로(`.env`에 새 비밀번호 없음, 입력 초안·진행 기록 없음), `status`·`apps`에서 연결됨·옛 주소. 응답에 남은 쓸 곳만 미리 선택. 두 번째: 한 번의 `transact`로 금고 주소·쓸 곳, `.env` 비밀번호가 함께 바뀜 |
| AT-CM-43 | CM-02.AC-06 | alpha·beta 모두 Google 회사 매핑. alpha `account disconnect` | beta `config.yaml`·회사 토큰 파일 sha256 그대로, beta 도구 등록(가짜 등록기) 그대로 |
| AT-CM-44 | CM-03.AC-03·05, PR-08 | alpha 쓸 곳 앱(저장 뒤 다시 시작 필요하게 가짜 `restart_required`) 연결됨. `--change values` + 새 쓸 곳 제출 → 응답 확인 → 재개(`--resume gateway_restart`, 칸 값 없음, 다시 시작 완료 가짜) → 완료 → `app undo`. 따로: `--change values --resume gateway_restart`를 함께 보냄 | 첫 제출 응답에 `committed: true`와 `next.kind:'gateway_restart'`. 재개 요청에서 `transact` 호출 0회(금고·설정 지문이 첫 저장 직후와 같음), 기록 파일의 되돌리기 전 바이트가 바꾸기 전 값 그대로. 완료 뒤 `undo`로 금고·설정이 바꾸기 전 바이트. 함께 보낸 요청은 `INVALID_ARGUMENTS`, 파일 변경 없음 |
| AT-CM-16 | 회귀 | team-kit 기존 연결·앱 연결·Google·X·Instagram 시험 | 전부 통과 |

## 문 (`tests/acceptance/test_conn_manage.py`, 새 파일)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-CM-20 | CM-01.AC-01, design 2.4 | 가짜 `apps`: alpha 연결됨 앱 A(`settings` 2개), 연결됨 앱 B(`settings` 없음, 합칠 계정 줄 없음), 연결 가능 앱 C | A 주 동작 `app_connect` "설정 바꾸기", 다른 동작에 `app_disconnect` "해제". B 주 동작 없음, "해제" 있음. C 주 동작 "연결". 어떤 줄에도 "범위 바꾸기" 라벨 없음. A 줄에 `settings`가 그대로 전달됨 |
| AT-CM-21 | CM-04.AC-01 | 가짜 `status`에 alpha `synology`(group account, 직접 확인 기록 있음)·`notion` 줄, 가짜 `apps`에 alpha 시놀로지 앱(연결됨, `links`에 alpha `synology`)·Notion 앱(연결됨, `links`에 alpha `notion`) | 표에 `team:synology`·`team:notion` 없음. 두 앱 줄에 `check` "확인", 시놀로지 앱 줄 상태는 계정 줄의 직접 확인 결과(`verified_by` 포함) |
| AT-CM-21b | CM-04.AC-01, design 4절 앱 파생 줄(V-3) | 실제 생산자 모양: 가짜 `status`에 alpha `synology`(account) + `app-com.synology.CloudStation`(group mac, `APP_CONNECTED`, `team_registry`) + 다른 앱 `app-<다른 키>`(`APP_CONNECTED`) + `app-<세 번째 키>`(`CONFIG_DRIFT`), beta에도 `app-com.synology.CloudStation`. 가짜 `apps`에 alpha 시놀로지 앱(연결됨, `links`에 계정 줄과 파생 줄)·다른 앱(연결됨) | alpha 표: 시놀로지 관련 줄은 `app:com.synology.CloudStation` 하나(`team:synology`·`team:app-com.synology.CloudStation` 없음). 다른 앱도 `app:` 줄 하나. `CONFIG_DRIFT` 줄은 남음. beta 표의 파생 줄은 beta 앱 항목 기준으로만 판단(alpha 처리로 사라지지 않음). 파생 줄에 직접 확인 기록을 넣은 경우 앱 줄 `verified_by`가 그 값 |
| AT-CM-22 | CM-04.AC-01 | AT-CM-21 표에서 시놀로지 앱 줄 `check` 요청 | 가짜 team-kit에 `check --profile alpha --connection synology` 한 번 |
| AT-CM-23 | CM-04.AC-02 | 실제 `apps` 모양: alpha에게 시놀로지 앱이 `connectable`(설치만, `progress` 없음)이고 `links`에 alpha `synology`(켜짐) 있음 | `team:synology` 줄과 앱 줄 둘 다 있음, 계정 줄 동작 지금 그대로 |
| AT-CM-23b | CM-04.AC-01 | (가) 앱 `connectable` + `progress` 있음 + `links` 켜진 계정 줄 (나) 앱 `connectable` + `links`의 계정 줄 `off` | 둘 다 계정 줄 없음, 앱 줄 하나((나)의 주 동작 "연결") |
| AT-CM-24 | CM-03.AC-02 | 앱 줄에 `app_connect`, `values: {change: 'values'}` / `{change: 'foo'}` | 첫째는 가짜 team-kit 인자에 `--change values`, `change`가 표준 입력 값에 없음. 둘째는 `invalid_action`, 명령 실행 없음 |
| AT-CM-25 | CM-02, design 3.3 | team 줄 `account_disconnect`·`account_connect`·`account_undo`(줄에 그 동작이 있을 때) / 줄에 없는 동작 | 가짜 team-kit 인자 `account disconnect|connect|undo --profile alpha --connection <id> --json`. 없는 동작은 `invalid_action`. 재확인(`reauth`) 없는 요청은 `reauth_required` |
| AT-CM-28 | CM-03.AC-04, NFR-CM-01, PR-09 | 같은 기기·직원·줄에서: (가) `{change}`만 보낸 요청 → 응답 보안 칸 `password` (나) `password` 포함 요청 → 응답 보안 칸 없음 (다) `password`를 다시 담은 요청(가짜 team-kit이 응답에 그 값을 되돌려 담음) → 응답 `committed:true` (라) `resume`만 보낸 요청 (마) 다른 기기에서 같은 줄 요청 (바) (다) 처리 중에 같은 기기의 (가)형 새 요청이 먼저 끝남 (사) 기기 연결 끊김 | (다)의 응답·로그·감사에 그 값 없음. (라) 이후 목록은 그 응답의 보안 칸만. (마)는 (가)~(다)의 목록과 섞이지 않음. (바)에서도 (다) 응답은 가려짐. (사) 뒤 그 기기 목록 없음 |
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
| AT-CM-38 | CM-03.AC-04·05, PR-08 | 바꾸기 세션: 1단계 칸(주소) 제출 → 응답 로그인 단계 → 비밀번호 제출 → 응답 고르기 단계 → 고르기 제출 → 응답 `committed:true`, `next.kind:'gateway_restart'` → 다시 시작 확인 수락 / 따로 중간에 창 닫기 | 둘째·셋째 프레임 `values`에 앞 단계 값 모두와 `change` 포함. `committed` 응답 직후 모은 값이 비고, 다시 시작 재개 프레임 `values`는 `resume`만(`change`·비밀번호 없음). 창 닫기 뒤에도 모은 값 비어 있음(새 바꾸기의 첫 프레임은 `{change}`만) |
| AT-CM-37 | 회귀 | 기존 `ConnectionsTests` | 전부 통과 |

## 사장 확인 (운영 적용 뒤, 실물)

| ID | 내용 | 합격 |
|---|---|---|
| M1 | 한 직원의 시놀로지 줄이 하나이고, 설정 바꾸기 → 폴더 고르기만 바꿈 | 비밀번호를 묻지 않고, 바꾼 폴더로 파일 도구가 동작 |
| M2 | 한 Mac 앱 해제 → 다시 연결 | 값을 다시 묻지 않고 연결됨 |
| M3 | 맥북에서 해제·설정 바꾸기 중 지문·암호 확인 | 확인 뒤 연결 창이 앞에 남고 다음 단계가 보임 |
| M5 | 앱 0.2.3 공개 준비(CM-06): HEJO-CONNECTIONS TASK-06 절차(빌드, `hejo-ship prepare`, 압축 해제본 `codesign --verify --deep --strict`, 앱 안 버전·빌드 번호) | 검사 통과, 버전 0.2.3·빌드 +1. 공개·푸시는 사장 |
| M4 | Google(테스트용으로 고른 직원 하나) 해제 → 다시 시작 → (가) 그 직원 홈 기준 본체 스킬 목록 보기(읽기 명령, 예: 그 프로필의 `hermes skills list`류) (나) 그 직원에게 메일 확인 요청 | (가) `google-workspace`가 꺼짐으로 나오거나 목록에 없음 (나) Google을 쓰지 않는다고 답함. 다른 직원 Google은 정상. 다시 연결 → 다시 시작 뒤 (가)(나) 해제 전과 같음. 읽기 명령이 없으면 그 사실을 기록하고 (나)만으로 스킬 미노출을 통과 처리하지 않는다 |

## AC ↔ 시험 연결 (PR-07)

| AC | 시험 |
|---|---|
| CM-01.AC-01 | AT-CM-09, 20, 23b, 30 |
| CM-01.AC-02 | AT-CM-30 |
| CM-01.AC-03 | AT-CM-15 |
| CM-02.AC-01 | AT-CM-31 |
| CM-02.AC-02 | AT-CM-08, 09 |
| CM-02.AC-03 | AT-CM-08, 09, 10(가), 14, M2 |
| CM-02.AC-04 | AT-CM-11(계정), 17(가)(앱) |
| CM-02.AC-05 | AT-CM-10(나~라)(계정), 17(나)(앱) |
| CM-02.AC-06 | AT-CM-13, 43 |
| CM-02.AC-07 | AT-CM-12, 14(설정), 14b(본체 소비자), M4 |
| CM-03.AC-01 | AT-CM-01, 32, 33, 41(가) |
| CM-03.AC-02 | AT-CM-02, 04, 05, 34, 40, 41, M1 |
| CM-03.AC-03 | AT-CM-03, 44 |
| CM-03.AC-04 | AT-CM-06, 42, 28, 38 |
| CM-03.AC-05 | AT-CM-03, 44, 38 |
| CM-04.AC-01 | AT-CM-21, 21b, 22, 23b, M1 |
| CM-04.AC-02 | AT-CM-23 |
| CM-05.AC-01 | AT-CM-35, M3 |
| CM-05.AC-02 | AT-CM-36 |
| CM-06.AC-01 | M5 |
| NFR-CM-01 | AT-CM-18, 26, 28 |
| NFR-CM-02 | AT-CM-01 |
| NFR-CM-03 | AT-CM-09, 13, 43 |
