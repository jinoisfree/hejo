# HEJO-CONNECTIONS 설계

2판 · 2026-11-20(계획 검토 1회차 반영, [plan-review.md](plan-review.md)) · 명세 [spec.md](spec.md). 칸 표는 spec 첫 절. 저장소 약어: `H` = 이 저장소, `HD` = `<운영 저장소>`, `TKL` = 실행 중인 team-kit 원본(`<HOME>/plugin-store/team-kit`, `HD`의 사본은 `./sync`가 채움).

## 1. 자료 흐름(바뀐 뒤)

```text
앱 refresh ──connections{profile}──▶ 문 Connections.document(profile)
   부분마다 따로 읽기: toolsets / toolset_config(묶음마다) / env / mcp / oauth / catalog / team_status / apps / runtime
   실패한 부분 → 그 부분 줄만 빠짐 + agent.unread[] + 로그 connections_part_failed
   키 줄 = 값 있음 ∪ 켠 묶음이 필요로 하는 키
   연결 불가 앱·미설치 MCP 목록 → hidden_by_default
◀──connections_status{document}── (통째 실패면 connection_result{failed, 실제 이유} + 로그 connections_failed)
앱: 직원별 마지막 표 유지, unread·실패는 회색 안내, 숨김 줄 토글
```

연결 동작은 지금처럼 `connection_action` → `perform()` → team-kit `app connect`. 바뀌는 것은 실패 이유 전달, 이어 하기·처음부터 다시 버튼, 앱의 입력 창 처리다.

## 2. 문(`H/gate`)

### 2.1 부분 실패 격리 (REQ-HC-01·02)
- `document()`의 직원별 `try` 하나를 부분별 읽기로 나눈다. 부분 이름은 고정 목록: `toolsets`, `toolset_config`, `env`, `mcp`, `oauth`, `catalog`, `team_status`, `apps`, `runtime`.
- 부분이 `ConnectionFailure`(이유 무관)나 응답 모양 오류(KeyError·TypeError·필수 필드 없음)로 실패하면 그 부분의 줄만 빠진다. `toolset_config`는 묶음 하나 단위다. 실패한 묶음 줄은 남고 설정 정보(capabilities 추가분)만 빠진다.
- 직원 객체에 `unread: [{'part': 이름, 'reason': 이유 코드}]`를 붙인다(같은 부분 이름은 한 번만, `toolset_config`는 개수 대신 한 번). 실패가 없으면 키를 넣지 않는다.
- `team_status`·`apps`는 지금처럼 모든 직원에 한 번씩 부르는 명령이다. 실패하면 그 명령에 기대는 모든 직원에 같은 `unread`가 붙는다. `apps`는 직원 반복 밖에서 한 번만 부른다(지금은 직원마다 다시 부름 — 같은 결과라 한 번으로 합친다, 동작 보존).
- 로그: 문 모듈 로거(기존 `log`)로 `log.warning("connections_part_failed profile=%s part=%s reason=%s status=%s", ...)`. 상태가 없으면 `-`. 응답 본문·예외 문자열은 쓰지 않는다.
- 문서 전체 `instruction`은 그 요청의 모든 관리 서비스 부분이 `admin_unavailable`일 때만 넣고, 문장은 "서버의 관리 기능에 닿지 못했어요. 읽은 항목만 보여 드려요."로 바꾼다.
- 1MB 검사(`too_large`)는 남긴다(줄이 줄어 실제로는 걸리지 않는다).

### 2.2 통째 실패의 이유와 로그 (REQ-HC-02.AC-02·03, REQ-HC-05.AC-01)
- `server.py`의 `connections`/`connection_action` 처리에서 `ConnectionFailure`의 실제 `reason`을 보낸다(`admin_unavailable`, `admin_failed`, `invalid_response`, `command_failed`, `too_large`, `UNKNOWN_PROFILE`, `invalid_action`, `FORMAT_INVALID`). `OSError`/`ValueError`는 `invalid_response`로 보낸다.
- 같은 자리에서 `log.warning("connections_failed type=%s profile=%s reason=%s", ...)`.
- `perform()`의 `except ConnectionFailure` 매핑(`CONNECTIONS_READ_FAILED`로 뭉침)도 실제 이유 코드를 유지하고 같은 로그를 남긴다. `perform()` 안의 `await self.document(profile)`은 2.1로 부분 실패에 강해진다.
- 계약 유지: 성공 프레임 모양, `connection_result.reply.outcome` 값 목록, `public()` 허용 필드 원칙(새 필드 `unread`, `part`, `hidden_by_default`만 추가).

### 2.2a 관리 서비스 응답의 이유 구분 (계획 검토 PR-01 반영)
- 이유는 실패가 생긴 자리인 `gate/connections.py` `AdminClient.request()`에서 정한다:
  - `admin_unavailable`: `admin.json` 문제(없음·링크·권한·형식·값), 연결 거부·주소 오류 등 `OSError`(응답을 받기 전), 시간 초과.
  - `admin_failed`(+상태): 2xx가 아닌 응답(지금 그대로).
  - `invalid_response`: 2xx 응답인데 본문이 1MB를 넘거나(지금 그대로), JSON이 아니거나, 그 밖의 응답 해석 오류.
- `admin.json`의 `json.loads`와 응답 본문의 `json.loads`를 같은 `except ValueError`로 묶지 않는다. 예외 문자열은 지금처럼 버린다.
- 실제 클라이언트 경로로 시험한다: 루프백에 띄운 시험용 HTTP 서버(임시 포트, 임시 `admin.json`)가 200 + 잘못된 JSON, 200 + 1MB 초과, 500, 응답 지연(시간 초과), 닫힌 포트를 각각 돌려주고 `AdminClient`가 위 이유를 내는지 본다.

### 2.2b 표 조회는 쓰지 않는다 (계획 검토 PR-02 반영)
- 지금 `document()`는 값 있는 키마다 `SecretTransactions.undo_available()`을 부르고, 이 함수가 `purge()`로 만료된 되돌리기 파일을 지우며 잠금 파일을 만들 수 있다(`gate/connections.py:72-85`, `gate/auth.py:38`).
- 바꾼 뒤: `undo_available()`은 되돌리기 파일을 읽기만 한다(지우기·잠금 파일 만들기 없음). 만료 기록은 "없음"으로 판정한다. 읽다가 파일이 사라지거나 반쯤 보이면 "없음".
- 만료 기록을 지우는 주체는 지금처럼 문의 주기 작업(`gate/server.py:293-296`의 `secrets.purge()`)과 `save()`·`undo()` 시작 때의 `purge()` 둘뿐이다.

### 2.3 줄 줄이기 (REQ-HC-03)
- 키 줄: `env` 항목 중 `is_set`이 참인 키 ∪ 그 직원의 **켜진** 도구 묶음 설정(`providers[].env_vars[].key`)에 나오는 키. 나머지 키는 줄을 만들지 않는다. 값 있는 키의 되돌리기 동작은 지금 그대로.
- `catalog` 줄(미설치 MCP)과 `apps`의 `unavailable` 줄에 `hidden_by_default: true`.
- 다른 줄의 모양·id·동작은 그대로(동작 보존).

### 2.4 이어 하기·처음부터 다시 (REQ-HC-06.AC-03·04)
- 앱 줄에 `progress.next`가 있으면 주 동작을 `action('app_connect','이어서 하기',True)`로 한다(동작 id는 그대로 `app_connect`, 시설이 초안에서 재개한다).
- `progress.undo_until`이 있는 진행 중(아직 연결 안 됨) 줄의 `app_undo` 라벨은 "처음부터 다시", 연결된 줄은 지금처럼 "되돌리기".

## 3. 앱(`H/app`)

### 3.1 표 읽기 실패 (REQ-HC-01.AC-04·05, REQ-HC-05)
- `refresh()`는 실패 응답(`connection_result`의 `reply.reason`)을 읽어 이유별 문장을 고른다: `admin_unavailable` → "서버의 관리 기능에 닿지 못했어요", 연결 끊김·시간 초과 → "서버에 연결되지 않았어요", 그 밖 → "연결 상태를 읽지 못했어요. 서버 기록에 이유를 남겼어요".
- 실패해도 `known[직원]`과 `document`를 지우지 않는다. 마지막 표가 있으면 "마지막으로 확인한 내용이에요"를 함께 보인다.
- `unread`가 있으면 회색 한 줄 "일부 항목을 읽지 못했어요(부분 이름을 쉬운 말로)". 부분 이름 → 말: toolsets "도구 목록", toolset_config "도구 설정", env "키", mcp "MCP", oauth "로그인 연결", catalog "추가할 수 있는 MCP", team_status "연결 상태", apps "앱 목록", runtime "대화 채널".
- 표 읽기 문장(`notice`)과 입력 결과 문장을 나눈다. 입력 창의 빨간 칸은 입력 결과 문장만 그린다(새 상태값, 예: `inputError`).

### 3.2 숨김 줄 (REQ-HC-03.AC-03)
- 검색 줄 옆에 "연결할 수 없는 항목도 보기" 체크(기본 꺼짐). 꺼져 있으면 `hidden_by_default` 줄을 목록·개수 요약·직원 요약 점에서 뺀다.

### 3.3 입력 창이 닫혀도 멈추지 않기 (REQ-HC-06.AC-01·02)
- 먼저 재현한다: 개발 빌드 + 가짜 문(앱 시험 도구) 또는 서버에 영향 없는 방법으로, 주소 단계 제출 → `outcome: waiting`, `next.kind: secret_set`(아이디·비밀번호 칸, guide 7단계) 응답을 받는 경로를 그대로 재현해 창이 닫히는 원인과 버튼 무반응 원인을 찾는다. 원인·재현 절차·고친 방법을 impl-report에 쓴다. 원인이 아래 고침으로 설명되지 않으면 멈추고 보고한다.
- 확인 창: `confirmRestart`의 `NSAlert.runModal()`을 연결 창에 붙인 확인 창(`beginSheetModal(for:)`)으로 바꾼다. 연결 창이 열려 있는 동안 앱 전체를 막는 모달을 쓰지 않는다.
- 창 단계: 확인·인증 창이 연결 창 뒤에 가려지지 않게 한다. 인증·확인 동안에는 연결 창 단계를 `.normal`로 낮추고 끝나면 되돌린다(또는 같은 효과의 방법, 구현 담당 선택).
- `show()`: 창에 남은 sheet가 보이지 않거나 입력 상태가 어긋나 있으면 입력 상태를 정리하고 창을 앞으로 가져온다. 메뉴·설정 버튼은 언제나 창을 보이게 한다.
- 입력 창의 `onDismiss`/`onDisappear`가 진행 중인 요청(`busy`)의 다음 단계 표시를 막지 않게 한다. 응답이 다음 단계를 가져오면 입력 창을 다시 띄운다.

### 3.4 이어 하기 (REQ-HC-06.AC-03·04)
- 줄의 주 버튼은 문이 준 라벨을 그대로 그린다("이어서 하기"). 자세히 화면에 `next`가 있으면 "멈춘 단계: (단계 이름)"을 보인다.
- "처음부터 다시"는 확인(인증) 뒤 `app_undo`를 보낸다.

### 3.5 SwiftUI
연결 창은 기존 SwiftUI 화면(HEJO-FOUNDATION SwiftUI 예외 목록의 기존 항목)이다. 새 SwiftUI 화면을 만들지 않는다. 확인 창은 AppKit `NSAlert` sheet.

## 4. team-kit(`TKL/lib/hermes_facility`)

### 4.1 시놀로지 값 찾기 (REQ-HC-04.AC-01·02·06)
- 새 함수(위치는 `synology_setup.py` 또는 `app_setup.py`, 구현 담당 선택) `discover(root, profile)` → 후보 목록 `[{api_base?, link_host?, username?, source}]`. 읽기만 한다.
- **후보 하나는 한 연결에서 온 값 묶음이다.** 주소 두 개와 아이디는 같은 출처의 같은 연결에서만 가져오고, 서로 다른 연결의 값을 섞지 않는다(PR-05 반영).
- 출처와 우선순위. 앞 단계에서 후보가 하나라도 나오면 다음 단계는 보지 않는다.
  0. 이 직원 자신의 초안(금고 `app_setup`)이나 이전 설정 값. 지금 동작 그대로이며 있으면 그 값만 쓴다.
  1. 같은 `HERMES_HOME`의 다른 직원 중 시놀로지가 **연결됨**인 직원. 주소는 기존 `legacy_values`·금고 `apps`에서 읽는 같은 경로, 아이디는 그 직원 `.env`의 아이디 이름 값만 읽는다(비밀번호 이름은 읽지 않는다). 직원마다 후보 하나. 진행 중 초안은 출처로 쓰지 않는다.
  2. 서버 사용자의 Synology Drive Client 자료(`~/Library/Application Support/SynologyDrive/data/db/sys.sqlite`를 `mode=ro`로). 연결 표의 행마다 후보 하나: 그 행의 사용자 이름과 QuickConnect ID. ID가 행에 없으면 같은 폴더 `log/daemon.log`의 `<…>.<ID>.direct.quickconnect.to`에서 찾되, 로그에 ID가 하나뿐일 때만 그 행에 붙인다. `link_host = <ID>.quickconnect.to`. `api_base`는 Drive Client 자료에서 정책에 맞는 주소 전체를 찾을 수 있을 때만 만든다. [가정] 만들 수 없으면 그 후보는 `link_host`·아이디만 채우고, 주소 단계는 `api_base` 칸 하나만 남긴다. 구현 담당이 확인해 impl-report에 쓴다. 이름 해석용 외부 요청은 하지 않는다.
- 같은 (api_base, link_host, username) 후보는 하나로 합친다. 정책 검사(`nas.settings`)를 통과하지 못한 후보는 버린다.
- 남은 후보가 **하나**면 주소 단계를 건너뛴다(`setup_done`에 `address` 표시, 초안에 저장 — 기존 `stage_values` 경로). 그리고 로그인 단계로 가서 아이디를 로그인 칸의 `value`로 미리 채운다(보안 칸 아님).
- 남은 후보가 **둘 이상**이면 주소 단계에서 후보를 클릭으로 고르게 한다(`options`. 라벨은 "NAS 주소 · 아이디" 꼴로 비밀값 없이). 고른 후보를 위처럼 저장한다. "직접 넣기"도 고를 수 있다.
- 후보가 **없으면** 지금처럼 주소 단계에서 쉬운 문장으로 묻는다.
- 로그인 단계 안내는 한두 문장: "시놀로지에 로그인할 비밀번호를 넣어 주세요. 아이디는 서버에서 찾아 채웠어요(다르면 고쳐 주세요)." 2단계 인증이 켜진 계정이면 기존 실패 안내(`TWO_FACTOR`)를 쉬운 말로.

### 4.2 주소 오류 바로잡기 (REQ-HC-04.AC-03)
- `app_connect.py:557-559`: `adapters.synology`의 `ValueError('invalid NAS config')`는 주소 단계(`wait(result,'address','secret_set', 'ADDRESS_INVALID', input_error=…)`)로 돌린다. 다른 `ValueError`는 지금처럼 폴더 단계.
- 주소 형식 검사를 주소 제출 때(로그인 전) 같은 `nas.settings` 규칙으로 한다.

### 4.3 Obsidian 보관함 찾기 (REQ-HC-04.AC-04)
- 서버 사용자의 `~/Library/Application Support/obsidian/obsidian.json`의 보관함 경로 목록을 읽어(존재하는 폴더만) 고르기(`choose_sync_root`와 같은 고르기 모양 또는 `options`)로 준다. 없으면 지금처럼 폴더 입력.

### 4.4 안내 문장 (REQ-HC-04.AC-05)
- 원본은 `connection_guides.py`, `app_setup.py`의 칸 이름, `app_connect.py`의 `HINTS`, `connection_secrets.py`의 칸 이름 — 그 자리에서 고친다(ddots도 같은 문장을 받는다. ddots 코드는 고치지 않는다).
- 기준: (1) 사람이 해야 하는 일만 단계로 둔다 (2) 한 단계 한 문장, 쉬운 말 (3) 서버가 아는 값은 묻지 않는다 (4) 기술 용어는 쓰지 않거나 처음 한 번 풀어 쓴다(예: "토큰(로그인 열쇠 글자)") (5) 열 곳이 있으면 `open_url`, 복사할 값이 있으면 `copy`.
- 연결별 판정표. 이 표가 시험(AT-HC-46)과 검토의 기준이다(PR-04 반영). "사람이 넣는 칸"은 서버가 값을 찾은 경우다. "안내 단계 최대"는 지금 단계 수를 넘지 않는다. 바꿀 문장은 구현 담당이 쓰고 impl-report에 연결마다 전후 표를 남긴다.

| 연결 | 사람이 넣는 칸(이것만) | 미리 채우거나 클릭으로 끝나는 것 | 안내 단계 최대 | 사람만 할 수 있는 이유 |
|---|---|---|---|---|
| 시놀로지(후보 1개) | 비밀번호 | 주소 2개(건너뜀), 아이디(미리 채움), 폴더(클릭), 다시 시작(확인 클릭) | 3 | 비밀번호 |
| 시놀로지(후보 여럿) | 비밀번호 | 후보 고르기(클릭), 나머지는 위와 같음 | 3 | 비밀번호 |
| 시놀로지(후보 없음) | 주소 2개(또는 `api_base` 1개), 아이디, 비밀번호 | 폴더(클릭) | 4 | 서버가 주소를 모름 |
| Obsidian(보관함 찾음) | 없음 | 보관함 고르기(클릭) | 1 | — |
| Obsidian(못 찾음) | 보관함 폴더 | — | 2 | 서버가 보관함을 모름 |
| Slack 직원 봇 | 값 2개(봇 값, 앱 값) | 매니페스트 열기(`open_url`)·복사(`copy`) | 지금 단계 수 이하 | Slack 사이트에서 사장이 설치·발급 |
| ddots Slack | 값 1개 | 열기·복사 | 지금 단계 수 이하 | 같음 |
| Notion | 값 1개 | 발급 페이지 열기 | 지금 단계 수 이하 | 사장이 발급 |
| X | 값 2개(쿠키) | 로그인 페이지 열기 | 지금 단계 수 이하 | 브라우저 쿠키 자동 읽기는 범위 밖(보안 결정 필요) |
| Instagram | 값 1개 | 발급 페이지 열기 | 지금 단계 수 이하 | 사장이 Meta에서 발급 |
| Mail·메모·캘린더·연락처 | 없음 | 계정·범위 고르기(클릭), Mac 권한 허용(클릭) | 지금 단계 수 이하 | — |

- 단계 하나는 사람의 행동 하나다("열기를 눌러 …에서 …를 누르세요"). 서버가 하는 일, 설명뿐인 단계는 단계로 세지 않는다.

### 4.5 바꾸지 않는 것
- 목록 조회(`status`, `apps`)는 쓰지 않는다. 값 찾기도 읽기만.
- 비밀번호·토큰은 표준 입력으로만, `.env` 허용 이름만, 저장 전 확인·되돌리기 규칙 그대로.
- 다른 직원의 비밀번호를 읽거나 복사하지 않는다.

## 5. 기존 경로 판정

| 경로 | 판정 | 이유·조치 |
|---|---|---|
| `document()` 직원별 통째 try | 교체 | 부분별 읽기로. 옛 `except ... if error.reason!='admin_unavailable':raise` 제거 |
| `server.py` 실패를 `admin_unavailable`로 덮기 | 교체 | 실제 이유 전달 + 로그 |
| `AdminClient`의 응답 JSON 오류를 `admin_unavailable`로 묶기 | 교체 | 2.2a. 응답 해석 오류는 `invalid_response` |
| `undo_available()` 안의 `purge()`(표 조회 중 지우기) | 교체 | 2.2b. 읽기만, 정리는 주기 작업·`save`·`undo` |
| team-kit을 실행 중 원본에서 바로 고치기 | 교체 | 7.1. `HD` worktree에서 만들고 TASK-05에서 보관본·확인과 함께 적용 |
| 미설정 키 전체를 줄로 만들기 | 제거 | 사용 근거: 사장이 아무 키나 넣는 입구였으나 450줄 문제의 주원인. 켠 묶음이 필요로 하는 키는 남기므로 필요한 입력은 가능. 그 밖의 키는 서버 `hermes` 명령으로 |
| 직원마다 `team.run('apps')` 반복 | 통합 | 한 번 읽어 나눠 씀 |
| 앱 `refresh()` 실패 문장 하나 | 교체 | 이유별 문장, 표 유지 |
| `confirmRestart`의 `runModal` | 교체 | 연결 창 sheet |
| 시놀로지 주소 사람 입력 | 유지(대체 경로) | 찾지 못할 때만 |
| 2026-11-08 "아이디를 미리 채우지 않는다" | 교체(사장 승인 대상) | REQ-HC-04.AC-02. `HD/docs/연결-상태.md` 해당 문장을 같은 변경에서 고친다 |

## 6. 대안

- 키 줄을 숨김 줄로 남기기(기각): 352줄을 매번 보내고 그리는 비용, "자기 것만" 요구와 맞지 않음.
- 문에서 400을 주는 묶음만 건너뛰기(기각): 같은 종류의 다른 실패(다른 부분)를 다시 표 전체 실패로 만든다. 부분 격리가 원인 자리다.
- Hermes 본체의 묶음 이름 검사 고치기(범위 밖): 본체 수정 금지. `HD` 쪽 별도 작업 후보로 보고만 한다.
- 시놀로지 주소를 QuickConnect 공용 서버에 물어 찾기(기각): 외부 요청이 생기고 응답 형식이 공개 계약이 아니다.

## 7. 위험·롤백·서버 적용

- 위험도: 고위험. 근거: 비밀값을 받는 연결 흐름과 자격 값 찾기(아이디 미리 채우기, 다른 직원 금고 값 읽기), 운영 시설(team-kit은 실행 중인 원본) 변경, 공개.
### 7.1 team-kit은 운영 원본을 고치지 않고 만든다 (PR-03 반영)
- TASK-04는 실행 중인 원본(`TKL`)을 고치지 않는다. 대신 `HD`에 임시 worktree를 만들고(착수 때 `HD` HEAD 기준, 브랜치 이름은 구현 담당), 그 worktree의 `hermes/plugin-store/team-kit`에서 고치고 시험한다. 시험은 게이트웨이 환경 Python과 임시 `HERMES_HOME`만 쓴다.
- 착수 때 기준 일치를 확인한다. 바꿀 파일마다 `TKL` 실행본과 worktree 기준 파일의 sha256이 같아야 한다. 다르면(다른 작업이 실행본을 고쳤지만 아직 동기화 안 됨) 멈추고 보고한다.
- TASK-04 결과물은 worktree 브랜치의 커밋과 바꿀 파일 목록이다. `HD` main, `./sync`, `TKL`은 건드리지 않는다. 운영 동작은 TASK-04 내내 그대로다.

### 7.2 서버 적용 (TASK-05)
- 직원이 일하지 않을 때 한다(진행 중 턴 0, 기존 `gateway restart`의 BUSY 검사). 적용 전 롤백 기록을 impl-report에 먼저 쓴다. 기록에는 명령마다 대상 경로·커밋·sha256을 채우고 빈 칸을 남기지 않는다.
- **team-kit**
  1. 바꿀 파일마다 `TKL`의 sha256이 TASK-04 착수 때 기록한 기준 값과 같은지 다시 확인한다. 다르면 멈추고 보고한다.
  2. 바꿀 파일의 실행본을 그대로 보관한다(작업 문서 밖의 0700 임시 폴더, 경로와 sha256 기록). 이 보관본이 복원 기준이다. 계속 움직이는 `HD`의 "직전 커밋"을 복원 기준으로 쓰지 않는다.
  3. 파일마다 임시 파일에 쓴 뒤 이름 바꾸기로 교체한다(반쯤 쓴 파일이 읽히지 않게).
  4. 읽기 명령 `hermes-connections status --json`과 `apps --json`이 성공하는지 확인한다. 하나라도 실패하면 즉시 보관본으로 되돌리고 같은 확인을 다시 한 뒤 멈추고 보고한다.
  5. 그다음 `HD`에서 `./sync` → `./airport-check` → `git commit --only`로 자기 경로만 커밋한다.
  - 파일 사이 교체 간격 동안의 호출은 한가한 때를 골라 줄이고, 4번 확인으로 잡는다. 게이트웨이가 import하는 파일이 바뀌면 문 재시작 때 함께 적용된다(구현 담당이 파일마다 판정해 적는다).
- **문:** 적용 전 공용 릴리스의 `RELEASE` 커밋을 기록 → `install/hejo-release` → 게이트웨이 재시작. 되돌리기는 기록한 커밋을 임시 worktree로 꺼내 `install/hejo-release` → 재시작.
- **앱:** 적용 전 사본 보관 → 새 빌드로 교체. 되돌리기는 보관 사본 복원.
- **복구 조건:** 재시작 뒤 채널 재연결이 확인되지 않거나, 연결 화면이 표를 하나도 못 받거나, `status`·`apps`가 실패하면 그 단계의 보관본으로 되돌린다.
- 직원 B 초안은 건드리지 않는다. 사장이 고친 화면에서 이어 가거나 "처음부터 다시"를 고른다(M5).
