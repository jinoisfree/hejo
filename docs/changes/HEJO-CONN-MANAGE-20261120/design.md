# HEJO-CONN-MANAGE 설계

3판 · 2026-11-20(계획 검증 1·2회차 반영, [plan-review.md](plan-review.md)) · 명세 [spec.md](spec.md). 약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 실행 중인 team-kit 원본(`<HOME>/plugin-store/team-kit/lib`). 칸 배치는 spec 첫 절.

## 1. 책임과 흐름

```
앱(줄·버튼·입력 창) ──connection_action──▶ 문(줄 합치기, 동작 검사, 전달) ──hermes-connections──▶ team-kit(동작 목록 원본, 실행)
```
- **무엇을 할 수 있는가**는 team-kit 하나가 정한다(계정 줄: `actions_for`, 앱 줄: `apps --json` 항목의 새 `settings`·기존 상태). 문은 지금처럼 앱 줄의 동작을 상태에서 만들고(`connection_manager.py:184-189`) 라벨만 이 설계대로 바꾼다. 앱은 받은 동작만 그린다.
- **값**은 금고·`.env`·토큰 파일에 그대로 있다. 해제·설정 바꾸기는 기존 트랜잭션(`app_connect.transact`의 쓰기 전 되돌리기 기록)으로만 쓴다.

## 2. Mac 앱(Obsidian 서비스 포함)

### 2.1 설정 단계 표 (team-kit 한 곳)
`app_connect.py`에 단계 → 금고 값 키 표를 하나 둔다. 단계 id는 기존 `steps_from`의 것을 쓴다(`login`은 Notion에도 쓰도록 넓힌다, 2판 PR-02).

| 단계 id | 해당 서비스 | 라벨 | 저장 위치 | 바꾸기 진입 때 다시 받는 것 |
|---|---|---|---|---|
| `address` | synology | 주소 | 금고 `api_base`, `link_host` | 주소 두 칸(지금 값 미리 채움, 2.2 주소 규칙) |
| `login` | synology | 로그인 | 금고 `login_selected`, `.env` 아이디·비밀번호 | 아이디(지금 값 미리 채움)·비밀번호(빈 보안 칸) |
| `login` | notion | 로그인 열쇠 | `.env` `NOTION_API_KEY` | 로그인 열쇠(빈 보안 칸) |
| `sync_root` | synology | 동기화 폴더 | 금고 `sync_root`, `drive_root` | 동기화 폴더 고르기(지금 값 미리 선택) |
| `values` | 쓸 곳을 고르는 앱(`scope`), 계정 고르기(`accounts`/`account`), Obsidian(`vault`) | 쓸 곳 / 계정 / 보관함 | 금고 그 키 | 고르기(지금 값 미리 선택) |

- 설정 단계는 그 앱에 저장 값(금고 키 또는 `.env` 이름)이 있는 단계만이다.
- `apps --json`의 연결된 항목에 `settings: [{step, label, value}]`를 더한다. `value`는 쉬운 표시 문자열이다. 경로는 마지막 폴더 이름, 쓸 곳은 고른 개수와 첫 이름("받은편지함 외 2개"), 주소는 호스트 이름만, 로그인·로그인 열쇠는 "저장됨". 비밀값은 넣지 않는다. 읽기만 한다(NFR-CM-02).

### 2.2 설정 바꾸기 실행 (바꾸기 모드)
- 문 동작 id: 기존 `app_connect`를 쓰고 값에 `change: <단계 id>`를 붙인다. 문은 `change`를 `--change <단계>` 인자로 넘기고 표준 입력 값에서는 뺀다(`connection_runtime.py` 인자 표에 추가, 단계 id는 위 표의 네 개만 허용).
- team-kit `run(action='connect', change=<단계>)`은 연결된 앱이고 그 앱에 그 단계가 있을 때만 받는다(아니면 `INVALID_ARGUMENTS`).
- **바꾸기 모드는 마지막 저장 전까지 서버에 아무것도 쓰지 않는다(PR-03).** 입력 초안(`stage_values`)·진행 기록·`.env`를 쓰지 않는다. 한 바꾸기 동안 앞 단계에서 받은 값(비밀값 포함)은 앱이 들고 있다가 다음 요청에 함께 다시 보낸다(5절). team-kit은 요청마다 "저장 값 + 이번 요청 값"으로 처음부터 흐름을 다시 계산한다. 그래서 창을 닫거나 실패하면 연결은 바꾸기 전 그대로이고 정리할 것이 없다(spec REQ-CM-03.AC-04).
- 흐름 계산 규칙:
  1. 시작값 `selected` = 저장 값(`registry.values(...)[앱]`).
  2. 바꾸는 단계는 이번 요청에 그 단계 값이 없으면 **반드시 그 단계 응답을 낸다**. 다른 출처로 자동으로 건너뛰지 않는다.
     - `address`: `nas.prepare`의 설정·후보 자동 채우기를 쓰지 않고, 지금 저장 주소를 미리 채운 주소 칸(`address_fields`)을 낸다(PR-01). 제출된 주소는 기존 주소 검사를 거친다. 주소가 바뀌면 기존 규칙대로 `login`도 다시 받는다.
     - `login`: 저장된 `.env` 값으로 확인하지 않고 그 서비스의 자격 칸을 낸다(시놀로지 아이디·비밀번호, Notion 로그인 열쇠, PR-02). 제출 값은 기존 `checks.candidate_values`로 쓰기 없이 확인한다. 실패하면 같은 단계로 돌아간다.
     - 고르기 단계: 지금 값의 옵션 id를 `selected`에 넣어 낸다.
  3. 바꾸지 않는 단계는 저장 값으로 채운다. 쓸 곳은 저장 값을 지금 옵션 id로 바꿔 넘긴다. 저장 값 중 지금 옵션에 없는 것이 있으면 그 고르기 단계에서 멈추고, 남아 있는 값만 미리 선택한다(사람이 다시 골라야 함).
  4. 모두 채워지면 기존 `transact(action='connect')`로 한 번에 저장한다. 비밀값은 이때 처음 `.env`에 쓰이고, 되돌리기 기록도 기존대로 생긴다(AC-05). 앱이 이미 명부에 있으므로 명부는 그대로다.
- **저장 전과 저장 후를 나눈다(PR-08).** 바꾸기 세션은 "저장 전 재계산"만이다. 흐름 계산 규칙 4의 `transact`가 성공한 응답에는 `committed: true`가 붙는다(새 공개 필드, 문 `PUBLIC_KEYS`에 추가). 그 뒤의 다시 시작·권한·확인 대기는 바꾸기 세션이 아니라 기존 "이어서 하기"와 같은 재개다.
  - 앱: `committed: true`를 받으면 그 자리에서 모은 값(비밀값 포함)과 `change`를 지운다. 이어지는 재개 요청은 지금처럼 `resume`만 보내고 `change`·칸 값을 보내지 않는다. `committed`가 없는 응답이면 모은 값을 유지한다.
  - team-kit: `--change`와 `--resume`이 함께 오면 `INVALID_ARGUMENTS`(재개에서 다시 저장할 길을 막음). 재개는 기존 `pending` 판정(`app_connect.py:515`, 값·계정·쓸 곳이 없을 때만 재개)으로 처리되어 `transact`를 다시 부르지 않는다. 따라서 되돌리기 기록의 전 바이트는 바꾸기 전 값으로 남는다.
  - 저장 전에 실패·닫힘이면 저장된 것이 없으므로 정리할 것도 없다. 저장 뒤 후속 단계에서 멈추면 지금처럼 줄에 "이어서 하기"와(10분 안) "되돌리기"가 보인다.
- 앱은 저장 전 바꾸기 세션 동안 제출한 모든 칸 값을 다음 요청마다 함께 보낸다(같은 `change` 값).
- **문 보호 목록의 세션 경계(PR-09).** 문은 앱의 창 닫힘을 알 수 없고(서버 알림 계약 없음) 알 필요도 없다. 보호 목록에는 칸 id만 있고 값은 없다.
  - 열쇠는 지금처럼 `(device, profile, connection)`이다(`connection_manager.py:247,258`).
  - 누적: 요청 값에 `change`가 있으면 그 응답의 보안 칸 id를 기존 목록에 더한다(지금은 덮어씀).
  - 비움: 요청 값이 `change` 하나뿐(새 세션 시작)이거나 `change`가 없는 요청이 오거나, 응답에 `committed: true`가 있거나 `outcome`이 `failed`·`refused`이면 그 요청 처리 뒤 목록을 그 응답의 보안 칸만으로 다시 둔다. 기기 연결이 끊기면 그 기기의 목록을 지운다.
  - 가림 값은 요청 시작 때 계산해(`secrets`) 그 요청이 끝날 때까지 쓴다. 다른 요청이 목록을 비워도 진행 중인 요청의 가림은 그대로다.
- 앞 연결의 되돌리기 기한(10분) 안에도 바꾸기는 된다. 마지막 `transact`가 새 되돌리기 기록을 쓴다. 지금 `stage_values`의 `CONNECTION_IN_PROGRESS` 막음은 바꾸기 모드에 걸리지 않는다(초안을 쓰지 않으므로).

### 2.3 해제와 다시 연결
- 해제는 기존 `app disconnect` 그대로다. 금고 값과 `.env`를 지우지 않는 것을 [확인]했다(`transact`는 연결일 때만 금고·`.env`를 쓴다, `app_connect.py:399,405-408`). 이번 작업은 이를 시험으로 고정한다(AT-CM-08·17).
- 다시 연결(해제된 앱의 "연결"): 시작값을 저장 값으로 채운다. 저장 값이 없으면 지금처럼 처음부터(초안·후보 찾기 포함). 저장 값으로 다 채워지면 사람 입력 없이 저장 → 다시 시작·권한·확인 단계로 간다. 고르기 단계의 저장 값이 지금 옵션에 없으면 2.2-3과 같이 그 단계에서 멈춘다.
- 시놀로지 로그인 재사용 조건: 저장 값의 `login_selected`가 참이고 `.env`에 아이디·비밀번호 이름이 있을 때만(기존 `credentials`의 `chosen` 규칙).

### 2.4 라벨
| 상태 | 주 동작 | 다른 동작 |
|---|---|---|
| 연결됨, 설정 단계 있음 | `app_connect` "설정 바꾸기" | `app_disconnect` "해제", (10분 안) `app_undo` "되돌리기", (계정 줄과 합쳐졌으면) `check` "확인" |
| 연결됨, 설정 단계 없음 | 합쳐진 계정 줄이 있으면 `check` "확인", 없으면 주 동작 없음("설정 바꾸기"를 두지 않음) | "해제" |
| 진행 중 | 지금대로 "이어서 하기"·"처음부터 다시" | |
| 연결 가능(해제됨 포함) | "연결" | |

"범위 바꾸기" 라벨은 없어진다(교체).

## 3. 계정 줄(Google 개인·회사, X, Instagram)

조사(2026-11-20, 읽기 전용, `HD` `7ae2b013`의 `hermes/plugin-store/` 기준, 경로는 `TK`=team-kit, `TD`=team-delegation):
- [확인] 켜짐 판정 `app_registry.enabled`는 `enabled is True`만 켜짐(`TK/lib/hermes_facility/app_registry.py:6-7`). `actions_for`는 꺼짐 줄에 동작을 주지 않는다(`connections.py:117`). `find_connection`은 꺼짐 줄도 찾고(`:249-260`), `connection_ids`는 꺼짐을 뺀다(`:272`, `check_all`·재시작 기대 채널에 쓰임).
- [확인] Google은 직원별 꺼짐 칸이 없다. `gmail` 설정의 `enabled`는 없고, 도구는 무조건 등록된다(`TD/__init__.py:2536-2564,2589,2740`). 토큰은 직원이 아니라 범위별로 공유된다(회사 토큰은 루트, 개인 토큰은 개인 역할 직원 홈, `TK/lib/hermes_execution/personal_scopes.py:398-401`).
- [확인] X는 `team-kit.x_read.enabled`가 등록 때와 호출 때 모두 지켜진다(`TK/__init__.py:952-966`, `sns/x_read.py:448-450`). 예외: `news_watch.fetch_x`가 X 로그인을 `x_read` 확인 없이 쓴다(`hermes_team_services/news_watch.py:124-139`).
- [확인] Instagram은 직원 `config.yaml`의 `plugins.enabled` 목록으로 실린다. `entries.instagram-dm.enabled` 칸은 지금 없다. 파일 경로로 직접 싣는 곳이 있다(`morning_report.py:108`, `report_review.py:44-54`, `connection_checks.py:197`).
- [확인] 세 서비스 모두 켜고 끈 결과는 게이트웨이 재시작 뒤 적용된다(도구 등록·토큰 적재가 시작 때).
- [확인] Drive·Sheets·Docs(그리고 Gmail·Calendar의 다른 길)는 Hermes 본체 스킬 `google-workspace`다(`~/.hermes/hermes-agent/skills/productivity/google-workspace/SKILL.md`). 본체는 그 직원 홈 `config.yaml`의 `skills.disabled`(과 `skills.platform_disabled`)에 있는 스킬을 끈다(`agent/skill_utils.py:261-273`, `tools/skills_tool.py:171`). 값은 목록 또는 JSON 배열 문자열일 수 있다(`skill_utils.py` `parse_config_string_list`). 본체는 고치지 않고 이 칸만 쓴다.
- [확인된 한계] 꺼짐은 그 직원에게 도구·스킬을 내주지 않는 것이다. 토큰 파일 자체는 남으므로(사장 결정: 값 남김) 터미널 같은 일반 도구로 토큰 파일을 직접 읽는 것까지 막는 보안 경계는 아니다. 화면 문장은 "이 직원이 Google을 쓰지 않게 해요"로 하고 "접근 차단"이라고 하지 않는다.
- [미확인, 설계가 기대지 않음] 본체가 `plugins.entries.<이름>.enabled`를 지키는지, 설정을 실행 중에 다시 읽는지. 이 설계는 다시 시작 뒤 적용만 약속한다.

### 3.1 서비스별 꺼짐 칸 (team-kit 한 곳의 표)
`connections.py`에 서비스 → 꺼짐 칸 표를 하나 둔다. 해제는 칸을 끄고, 연결은 켠다. 값(계정 주소·쿠키·토큰·`.env`)은 건드리지 않는다.

| 서비스(줄 id) | 꺼짐 칸(그 직원 `config.yaml`) | 함께 고칠 소비자(꺼짐을 지키게) |
|---|---|---|
| Google(`google-personal`·`google-company`·`google`) | ① `plugins.entries.team-delegation.settings.gmail.enabled: false`(새 칸. 없거나 `true`면 켜짐: 지금 설정은 바꾸지 않아도 켜짐) ② `skills.disabled`에 `google-workspace`(3.2) | `TD/__init__.py`의 `gmail_direct`·`google_reauth`·`google_calendar_*`·`calendar_direct_*`(Google 쪽) 등록 / `personal_scopes.install_mail` / `wait_jobs.account` / `personal_review` / `mail_index` / `connections.py:194-206`(꺼짐 줄 표시) / `app_registry.derived_settings`가 이 칸과 3.2 표시를 지우지 않음(`:186-188`) |
| X(`x`) | `plugins.entries.team-kit.settings.x_read.enabled: false`(있는 칸) | `news_watch.fetch_x`가 `x_read` 꺼짐이면 X를 건너뜀 |
| Instagram(`instagram`) | 직원 `plugins.enabled` 목록에서 `instagram-dm` 빼기(설정 `entries.instagram-dm`은 그대로) | 파일 경로 직접 싣기 3곳이 그 직원의 `plugins.enabled`에 없으면 건너뜀. `connections.py:233-236` 꺼짐 판정을 목록 기준으로 |

- 꺼짐의 뜻: 그 직원이 그 서비스를 쓰는 도구·배경 작업이 다시 시작 뒤 없다. 다른 직원은 영향 없다. Google 토큰이 이 직원 홈에 있어도(개인 역할 직원) 다른 직원이 그 토큰을 쓰는 경로(`token_home`)는 그대로 둔다.
- 꺼짐 줄: `state: 'off'`, `reason: 'DISABLED'`, 동작 `account_connect` "연결"(주). 켜짐 줄: 지금 동작 + `account_disconnect` "해제". 어느 쪽이든 마지막 해제·연결의 되돌리기 기록이 살아 있으면(10분) `account_undo` "되돌리기"가 더 붙는다.

### 3.2 Google 스킬 칸과 "해제가 넣은 것" 표시 (PR-04)
- 해제: `skills.disabled`에 `google-workspace`가 없을 때만 넣고, 넣었다는 표시를 같은 파일의 `gmail` 칸에 `off_added_skills: ['google-workspace']`로 남긴다. 이미 있었으면 넣지 않고 표시도 없다. 문자열 형식 목록은 목록으로 읽어 목록으로 쓴다.
- 연결: `gmail.enabled: true`, 표시에 적힌 이름만 `skills.disabled`에서 빼고 표시를 지운다. 사장이 따로 넣어 둔 스킬·다른 설정은 그대로다.
- 표시의 칸·쓰기 주체·수명: 그 직원 `config.yaml`의 `gmail` 칸 안(새 파일 없음) / team-kit `account` 명령만 씀 / 해제부터 다음 연결까지. 되돌리기 기록(10분)과 따로 산다. 그래서 10분이 지난 뒤 연결해도 해제 전 스킬 상태로 돌아간다.

### 3.3 실행과 되돌리기
- 새 명령 `hermes-connections account disconnect|connect|undo --profile <직원> --connection <줄 id> --json`. 문은 `account_disconnect`·`account_connect`·`account_undo` 동작을 이 명령으로 넘긴다(`connection_runtime.py` 인자 표, 줄 id는 3.1 표의 것만).
- **해제·연결은 칸 단위로 고친다.** 그 직원 `config.yaml`을 읽어 3.1·3.2의 칸만 바꾸고 나머지 내용은 읽은 그대로 쓴다(전체 파일을 예전 바이트로 되돌리지 않음). 그래서 해제 뒤 사장이나 다른 동작이 바꾼 설정은 연결 뒤에도 남는다.
- 쓰기 보호는 `app_connect.transact`와 같다: 잠금(`owner/.app-connect.lock`) → 쓰기 전 기록(`state/connections/account-<hash>.json`, 전 바이트·후 지문, `phase applying→applied`) → 원자 쓰기. 중간에 죽으면 기존 `recover`가 전 바이트로 돌린다. 같은 기록 형식·함수를 쓰고 두 번째 형식을 만들지 않는다(구현 담당이 `transact`·`undo`에서 공통 부분을 빼낸다).
- **되돌리기(10분)**는 기존 `undo` 규칙 그대로다: 그사이 파일 지문이 바뀌었으면 `UNDO_CONFLICT`로 거절하고 아무것도 쓰지 않는다(다른 변경을 덮어쓰지 않음). 10분이 지나면 `UNDO_EXPIRED`. 되돌리기 동작은 기록이 살아 있을 때만 줄에 나온다.
- 바꾸는 파일은 그 직원의 `config.yaml` 하나다. 금고·`.env`·토큰·명부·다른 직원 파일은 쓰지 않는다.
- 쓰고 나면 응답은 기존 다시 시작 단계(`next.kind: 'gateway_restart'`, `RESTART_REQUIRED`)로 이어진다. 앱은 지금처럼 다시 시작 확인을 띄운다.
- 이미 그 상태면(꺼진 줄에 해제 등) 쓰지 않고 `outcome:'done', reason:'UNCHANGED'`.

## 4. 줄 합치기(시놀로지·Notion)
- 문 `document()`에서 같은 직원의 앱 항목과 계정 줄을 합친다. `links`는 앱 연결 여부와 관계없이 같은 서비스면 만들어진다([확인] `discovery.py:130-141`, PR-05). 그래서 `links`만으로 합치지 않는다. 합치는 조건(모두 만족):
  1. 앱 항목의 `links`에 같은 직원·`group=='account'` 줄이 있다.
  2. 그 앱이 그 직원에게 실제로 걸려 있다: 앱 항목이 `connected` 무리에 있거나, `progress`가 있거나(진행 중), 계정 줄이 `off`이다(앱 해제로 꺼진 경우. 다시 켜는 길이 앱 줄의 "연결" 하나가 되게).
  - 조건 2를 못 채우면(설치만 된 미연결 앱 + 켜진 옛 계정 줄) 두 줄을 모두 지금처럼 둔다.
- 합칠 때 그 계정 줄(`team:<id>`)을 표에서 빼고 앱 줄에 합친다. 합칠 때 앱 줄에 `check` 동작("확인", 연결됨이면 주 동작 아님)을 붙이고, 계정 줄의 확인 기록(`state`·`reason`·`checked_at`·`verified_by`)이 "직접 확인"이면 앱 줄 상태 표시에 그대로 쓴다.
- 앱 줄의 `check`는 문이 `team.run('check', connection=<합친 계정 줄 id>)`로 넘긴다(새 명령 없음).
- 계정 줄의 "비밀번호 바꾸기"(`secret_set`)는 합친 줄에서는 설정 바꾸기의 `login` 단계로 대신한다(통합). 합치지 않은 옛 설정 줄에서는 그대로 남는다.
- 합치기는 화면 표의 표시 규칙이라 문 한 곳에만 둔다. team-kit `status`의 줄 자체는 바꾸지 않는다(다른 소비자: `docs/연결-상태.md`의 상태 명령 출력 유지).

## 5. 앱 화면
- 목록 줄: 주 동작 버튼 옆에 다른 동작이 있으면 "⋯" 메뉴 버튼(AppKit 메뉴 또는 SwiftUI `Menu`, 기존 화면이 SwiftUI이므로 같은 화면 안)을 둔다. 메뉴에 다른 동작(해제·되돌리기·확인 등) 라벨을 그대로 나열한다(spec REQ-CM-01.AC-02).
- 해제 확인: 기존 `ask(...)`(연결 창에 붙는 sheet)로 spec REQ-CM-02.AC-01 문장을 띄운다. 순서는 확인 → 재확인(지문·암호) → 요청.
- 설정 목록: 자세히 화면에 "지금 설정" 절을 더해 `settings`의 라벨·값·"바꾸기" 버튼을 그린다. "바꾸기"는 `app_connect`에 `values: {change: 단계}`를 보낸다. "설정 바꾸기" 주 동작은 자세히 화면을 연다(단계 하나면 바로 `change`).
- 바꾸기 세션: 같은 입력 창에서 이어지는 동안 앱은 제출한 칸 값(보안 칸 포함)을 메모리에만 모아 다음 요청마다 `change`와 함께 모두 보낸다(design 2.2). `committed: true` 응답, 창 닫힘, `outcome` 완료·실패 중 먼저 오는 때에 모은 값과 `change`를 지운다. 저장 뒤 재개는 `resume`만 보낸다. 디스크·로그에 쓰지 않는다.
- 확인 창 뒤 창 유지(REQ-CM-05): 구현 담당이 먼저 재현하고 원인을 impl-report에 쓴다. [제안] 재확인(`authenticated()`)과 확인 창(`ask`)이 끝나면(성공·취소 모두) `NSApp.activate(ignoringOtherApps:true)` 뒤 연결 창(입력 창이 있으면 입력 창)을 `makeKeyAndOrderFront`로 다시 앞에 둔다. 확인 중 높이 내리기(`updateLevel(confirming:)`)는 유지한다. 원인이 다르면 멈추고 보고한다.

## 6. 기존 경로 판정
| 경로 | 판정 | 내용 |
|---|---|---|
| 앱 줄 "범위 바꾸기"(`app_connect`, 빈 시작값) | 교체 | 설정 바꾸기(`change`)·저장 값 시작으로. 라벨 제거 |
| 입력 초안 `stage_values`(`choosing`) | 유지 | 처음 연결·다시 연결에서만 씀. 바꾸기 모드는 쓰지 않음(2.2) |
| 문 `input_fields`(마지막 응답의 보안 칸) | 교체(확장) | 바꾸기 세션 동안 누적(2.2) |
| `app disconnect` | 유지 | 값 보존을 시험으로 고정 |
| 합쳐진 계정 줄 `team:synology`·`team:notion` 표시 | 통합 | 앱 줄로. 옛 설정 직원은 유지 |
| 합쳐진 줄의 `secret_set` "비밀번호 바꾸기" | 통합 | 설정 바꾸기 `login` 단계 |
| `actions_for` 계정 줄 | 교체(확장) | 해제·연결 동작 추가(3절) |
| 확인 뒤 창 처리 | 교체 | 5절 |

## 7. 위험·롤백·서버 적용
- 위험도: 고위험. 근거: Google 개인·회사 담당 범위(권한) 변경, 자격 값 흐름, 운영 시설 변경, 앱 공개.
- team-kit 개발·적용 절차는 [HEJO-CONNECTIONS design 7.1·7.2](../HEJO-CONNECTIONS-20261120/design.md#7-위험롤백서버-적용)를 그대로 따른다(운영 원본은 고치지 않고 `HD` 임시 worktree에서 개발, 적용 때 sha256 재확인·보관본·이름 바꾸기 교체·`status`·`apps` 읽기 확인·실패 시 즉시 복원, 그다음 `./sync`·`./airport-check`·`git commit --only`). 문은 공용 릴리스 → 한가할 때 재시작, 앱은 보관 사본 후 교체.
- 운영에서 해제·설정 바꾸기를 실제로 눌러 보는 것은 사장 확인(M 항목)에서만 한다.
