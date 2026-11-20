# HEJO-CONN-MANAGE 설계

1판 · 2026-11-20 · 명세 [spec.md](spec.md). 약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 실행 중인 team-kit 원본(`<HOME>/plugin-store/team-kit/lib`). 칸 배치는 spec 첫 절.

## 1. 책임과 흐름

```
앱(줄·버튼·입력 창) ──connection_action──▶ 문(줄 합치기, 동작 검사, 전달) ──hermes-connections──▶ team-kit(동작 목록 원본, 실행)
```
- **무엇을 할 수 있는가**는 team-kit 하나가 정한다(계정 줄: `actions_for`, 앱 줄: `apps --json` 항목의 새 `settings`·기존 상태). 문은 지금처럼 앱 줄의 동작을 상태에서 만들고(`connection_manager.py:184-189`) 라벨만 이 설계대로 바꾼다. 앱은 받은 동작만 그린다.
- **값**은 금고·`.env`·토큰 파일에 그대로 있다. 해제·설정 바꾸기는 기존 트랜잭션(`app_connect.transact`의 쓰기 전 되돌리기 기록)으로만 쓴다.

## 2. Mac 앱(Obsidian 서비스 포함)

### 2.1 설정 단계 표 (team-kit 한 곳)
`app_connect.py`에 단계 → 금고 값 키 표를 하나 둔다. 단계 id와 라벨은 기존 `steps_from`의 것을 그대로 쓴다.

| 단계 id | 해당 서비스 | 금고 키(`vault.apps.<직원>.<앱>`) | 바꾸기 때 지우는 키 |
|---|---|---|---|
| `address` | synology | `api_base`, `link_host` | 두 키 + `login_selected`(주소가 바뀌면 기존 규칙대로 로그인 다시) |
| `login` | synology | `login_selected`(비밀은 `.env`) | `login_selected` |
| `sync_root` | synology | `sync_root`, `drive_root` | 두 키 |
| `values` | 쓸 곳을 고르는 모든 앱(`scope` 있음), 계정 고르기(`accounts`/`account`), Obsidian(`vault`), Notion(비밀만) | `scope`, `default`, `accounts`, `account`, `vault` | 그 서비스에 있는 키 |

- 설정 단계는 그 앱의 저장 값에 키가 하나라도 있는 단계만이다. 없으면 "설정 바꾸기"를 주지 않고 주 동작은 "확인"이다(spec REQ-CM-01.AC-01).
- `apps --json`의 연결된 항목에 `settings: [{step, label, value}]`를 더한다. `value`는 쉬운 표시 문자열이다. 경로는 마지막 폴더 이름, 쓸 곳은 고른 개수와 첫 이름("받은편지함 외 2개"), 주소는 호스트 이름만, 로그인은 "저장됨". 비밀값은 넣지 않는다. 읽기만 한다(NFR-CM-02).

### 2.2 설정 바꾸기 실행
- 문 동작 id: 기존 `app_connect`를 쓰고 값에 `change: <단계 id>`를 붙인다. 새 명령 이름은 만들지 않는다. 문은 `change`를 `--change <단계>` 인자로 넘긴다(`connection_runtime.py` 인자 표에 추가, 단계 id는 위 표의 네 개만 허용).
- team-kit `run(action='connect', change=<단계>)`: 연결된 앱이고 단계가 표에 있을 때만 받는다(아니면 `INVALID_ARGUMENTS`). 시작값 `selected`를 **저장된 값**(`registry.values(...)[앱]`)으로 채우고, 표의 "지우는 키"만 뺀 뒤, `setup_done`에서 그 단계와 뒤 단계를 뺀다. 그다음은 지금 흐름 그대로다. 흐름은 빠진 첫 값에서 멈추므로 그 단계가 열린다.
- 고르기 단계(`choose_scope`·`choose_account`·`choose_sync_root`·보관함 고르기)는 응답의 `selected`에 지금 값의 옵션 id를 넣는다(지금은 항상 `[]`). 앱은 이미 `selected`를 미리 선택으로 그린다(`ConnectionsWindow.swift:108`).
- 바꾸는 동안 값은 기존 입력 초안(`stage_values`, `phase: choosing`)에 머문다. 연결 자체(명부·설정)는 저장 전까지 그대로다(spec REQ-CM-03.AC-04). 마지막 저장은 기존 `transact(action='connect')`이고, 앱이 이미 명부에 있으므로 명부는 그대로, 금고 값과 조립 설정만 바뀐다. 되돌리기 기록도 기존대로 생긴다(AC-05).
- 단계가 하나뿐이면 앱은 목록 없이 바로 `change`를 보낸다.

### 2.3 해제와 다시 연결
- 해제는 기존 `app disconnect` 그대로다. 금고 값과 `.env`를 지우지 않는 것을 [확인]했다(`transact`는 연결일 때만 금고·`.env`를 쓴다, `app_connect.py:399,405-408`). 이번 작업은 이를 시험으로 고정한다.
- 다시 연결(해제된 앱의 "연결"): 시작값을 저장된 값으로 채운다(2.2와 같은 함수, 지우는 키 없음). 저장 값이 없으면 지금처럼 처음부터. 값이 다 차 있으면 흐름은 바로 저장 → 다시 시작·권한·확인 단계로 간다.
- 시놀로지 로그인 재사용 조건: 저장 값의 `login_selected`가 참이고 `.env`에 아이디·비밀번호 이름이 있을 때만(기존 `credentials`의 `chosen` 규칙). 주소가 바뀌면 기존 `prepare`가 `login_selected`를 지운다.

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
- [미확인] Drive·Sheets·Docs는 Hermes 본체 스킬 `google-workspace`에서 오는 것으로 보이며, 일부 직원 설정의 끈 스킬 목록에 있다. 본체는 이 저장소 밖이다.
- [미확인] 본체가 `plugins.entries.<이름>.enabled`를 지키는지, 설정을 실행 중에 다시 읽는지.

### 3.1 서비스별 꺼짐 칸 (team-kit 한 곳의 표)
`connections.py`에 서비스 → 꺼짐 칸 표를 하나 둔다. 해제는 칸을 끄고, 연결은 켠다. 값(계정 주소·쿠키·토큰·`.env`)은 건드리지 않는다.

| 서비스(줄 id) | 꺼짐 칸(그 직원 `config.yaml`) | 함께 고칠 소비자(꺼짐을 지키게) |
|---|---|---|
| Google(`google-personal`·`google-company`·`google`) | `plugins.entries.team-delegation.settings.gmail.enabled: false`(새 칸. 없거나 `true`면 켜짐: 지금 설정을 바꾸지 않고 켜짐 유지) | `TD/__init__.py`의 `gmail_direct`·`google_reauth`·`google_calendar_*`·`calendar_direct_*`(Google 쪽) 등록 / `personal_scopes.install_mail` / `wait_jobs.account` / `personal_review` / `mail_index` / `connections.py:194-206`(꺼짐 줄 표시) / `app_registry.derived_settings`가 이 칸을 지우지 않음(`:186-188`) / Drive·Sheets·Docs는 3.2 |
| X(`x`) | `plugins.entries.team-kit.settings.x_read.enabled: false`(있는 칸) | `news_watch.fetch_x`가 `x_read` 꺼짐이면 X를 건너뜀 |
| Instagram(`instagram`) | 직원 `plugins.enabled` 목록에서 `instagram-dm` 빼기(설정 `entries.instagram-dm`은 그대로) | 파일 경로 직접 싣기 3곳이 그 직원의 `plugins.enabled`에 없으면 건너뜀. `connections.py:233-236` 꺼짐 판정을 목록 기준으로 |

- 꺼짐의 뜻: 그 직원이 그 서비스를 쓰는 도구·배경 작업이 다시 시작 뒤 없다. 다른 직원은 영향 없다. Google 토큰이 이 직원 홈에 있어도(개인 역할 직원) 다른 직원이 그 토큰을 쓰는 경로(`token_home`)는 그대로 둔다.
- 꺼짐 줄: `state: 'off'`, `reason: 'DISABLED'`, 동작 `account_connect` "연결"(주). 켜짐 줄: 지금 동작 + `account_disconnect` "해제". 10분 안이면 `account_undo` "되돌리기".

### 3.2 Google Drive·Sheets·Docs ([미확인] 해소 조건)
- 구현 담당은 TASK-02 첫 단계에서 Drive·Sheets·Docs 도구가 어디서 등록되는지 읽기 전용으로 확정해 impl-report에 쓴다.
  - (가) team-kit·team-delegation 안이면 위 표의 등록 지점에 같은 꺼짐 검사를 넣는다.
  - (나) Hermes 본체 스킬이고 직원 `config.yaml`의 기존 끈 스킬 목록으로 끌 수 있으면, Google 해제 때 그 목록에 `google-workspace`를 넣고 연결 때 해제 전 상태로 되돌린다(해제 전 목록에 있었으면 그대로 둔다. 되돌리기 기록에 해제 전 바이트가 있음).
  - (다) 둘 다 아니면 Google 부분(TASK-02의 Google 갈래)을 멈추고 보고한다. 본체는 고치지 않는다.

### 3.3 실행과 되돌리기
- 새 명령 `hermes-connections account disconnect|connect|undo --profile <직원> --connection <줄 id> --json`. 문은 `account_disconnect`·`account_connect`·`account_undo` 동작을 이 명령으로 넘긴다(`connection_runtime.py` 인자 표, 줄 id는 위 표의 것만).
- 쓰기는 `app_connect.transact`와 같은 방식이다: 잠금(`owner/.app-connect.lock`) → 쓰기 전 되돌리기 기록(`state/connections/account-<hash>.json`, 바꿀 파일의 전 바이트·후 지문) → 원자 쓰기 → `applied`. 되돌리기는 기존 `undo`와 같은 규칙(10분, 그사이 파일이 바뀌면 `UNDO_CONFLICT`). 같은 함수를 쓰고 두 번째 기록 형식을 만들지 않는다(구현 담당이 `transact`·`undo`에서 공통 부분을 빼낸다).
- 바꾸는 파일은 그 직원의 `config.yaml` 하나다(3.2(나)도 같은 파일). 금고·`.env`·토큰·명부·다른 직원 파일은 쓰지 않는다.
- 쓰고 나면 응답은 기존 다시 시작 단계(`next.kind: 'gateway_restart'`, `RESTART_REQUIRED`)로 이어진다. 앱은 지금처럼 다시 시작 확인을 띄운다.
- 이미 그 상태면(꺼진 줄에 해제 등) 쓰지 않고 `INVALID_ARGUMENTS`가 아니라 `outcome:'done', reason:'UNCHANGED'`.

## 4. 줄 합치기(시놀로지·Notion)
- 문 `document()`에서 앱 항목의 `links`(team-kit이 이미 주는 값: 같은 서비스의 계정 줄 id·상태, `discovery.py:133-135`) 중 같은 직원·`group=='account'` 줄이 있으면, 그 계정 줄(`team:<id>`)을 표에서 빼고 앱 줄에 합친다. 합칠 때 앱 줄에 `check` 동작("확인", 연결됨이면 주 동작 아님)을 붙이고, 계정 줄의 확인 기록(`state`·`reason`·`checked_at`·`verified_by`)이 "직접 확인"이면 앱 줄 상태 표시에 그대로 쓴다.
- 앱 줄의 `check`는 문이 `team.run('check', connection=<합친 계정 줄 id>)`로 넘긴다(새 명령 없음).
- 계정 줄의 "비밀번호 바꾸기"(`secret_set`)는 합친 줄에서는 설정 바꾸기의 `login` 단계로 대신한다(통합). 합치지 않은 옛 설정 줄에서는 그대로 남는다.
- 합치기는 화면 표의 표시 규칙이라 문 한 곳에만 둔다. team-kit `status`의 줄 자체는 바꾸지 않는다(다른 소비자: `docs/연결-상태.md`의 상태 명령 출력 유지).

## 5. 앱 화면
- 목록 줄: 주 동작 버튼 옆에 다른 동작이 있으면 "⋯" 메뉴 버튼(AppKit 메뉴 또는 SwiftUI `Menu`, 기존 화면이 SwiftUI이므로 같은 화면 안)을 둔다. 메뉴에 다른 동작(해제·되돌리기·확인 등) 라벨을 그대로 나열한다(spec REQ-CM-01.AC-02).
- 해제 확인: 기존 `ask(...)`(연결 창에 붙는 sheet)로 spec REQ-CM-02.AC-01 문장을 띄운다. 순서는 확인 → 재확인(지문·암호) → 요청.
- 설정 목록: 자세히 화면에 "지금 설정" 절을 더해 `settings`의 라벨·값·"바꾸기" 버튼을 그린다. "바꾸기"는 `app_connect`에 `values: {change: 단계}`를 보낸다. "설정 바꾸기" 주 동작은 자세히 화면을 연다(단계 하나면 바로 `change`).
- 확인 창 뒤 창 유지(REQ-CM-05): 구현 담당이 먼저 재현하고 원인을 impl-report에 쓴다. [제안] 재확인(`authenticated()`)과 확인 창(`ask`)이 끝나면(성공·취소 모두) `NSApp.activate(ignoringOtherApps:true)` 뒤 연결 창(입력 창이 있으면 입력 창)을 `makeKeyAndOrderFront`로 다시 앞에 둔다. 확인 중 높이 내리기(`updateLevel(confirming:)`)는 유지한다. 원인이 다르면 멈추고 보고한다.

## 6. 기존 경로 판정
| 경로 | 판정 | 내용 |
|---|---|---|
| 앱 줄 "범위 바꾸기"(`app_connect`, 빈 시작값) | 교체 | 설정 바꾸기(`change`)·저장 값 시작으로. 라벨 제거 |
| `app disconnect` | 유지 | 값 보존을 시험으로 고정 |
| 합쳐진 계정 줄 `team:synology`·`team:notion` 표시 | 통합 | 앱 줄로. 옛 설정 직원은 유지 |
| 합쳐진 줄의 `secret_set` "비밀번호 바꾸기" | 통합 | 설정 바꾸기 `login` 단계 |
| `actions_for` 계정 줄 | 교체(확장) | 해제·연결 동작 추가(3절) |
| 확인 뒤 창 처리 | 교체 | 5절 |

## 7. 위험·롤백·서버 적용
- 위험도: 고위험. 근거: Google 개인·회사 담당 범위(권한) 변경, 자격 값 흐름, 운영 시설 변경, 앱 공개.
- team-kit 개발·적용 절차는 [HEJO-CONNECTIONS design 7.1·7.2](../HEJO-CONNECTIONS-20261120/design.md#7-위험롤백서버-적용)를 그대로 따른다(운영 원본은 고치지 않고 `HD` 임시 worktree에서 개발, 적용 때 sha256 재확인·보관본·이름 바꾸기 교체·`status`·`apps` 읽기 확인·실패 시 즉시 복원, 그다음 `./sync`·`./airport-check`·`git commit --only`). 문은 공용 릴리스 → 한가할 때 재시작, 앱은 보관 사본 후 교체.
- 운영에서 해제·설정 바꾸기를 실제로 눌러 보는 것은 사장 확인(M 항목)에서만 한다.
