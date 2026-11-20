# HEJO-CONNECTIONS 수락 시험 명세

4판 · 2026-11-20(계획 검토 1~3회차, 구현 검토 1차 V-1·V-2 반영) · 명세 [spec.md](../../docs/changes/HEJO-CONNECTIONS-20261120/spec.md), 설계 [design.md](../../docs/changes/HEJO-CONNECTIONS-20261120/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1회차 BLOCKED → 2판 반영, 2회차 BLOCKED → 3판 반영, 재검증 대기. 기대값 출처: spec 요구와 design 2~4절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통: 임시 `HERMES_HOME`, 가짜 직원 `alpha`·`beta`, 가짜 관리 서비스(경로별 응답·상태 지정), 가짜 team-kit 명령. 실제 토큰·직원 id·주소 금지.

## 문 (`tests/acceptance/test_connections_screen.py`)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HC-01 | HC-01.AC-01 | alpha의 묶음 `x`의 설정 요청만 400 | alpha 표가 나온다. `tool:x` 줄 있음, 다른 묶음 설정 정보 있음, `unread == [{'part':'toolset_config','reason':'admin_failed'}]` |
| AT-HC-02 | HC-01.AC-02 | 부분마다(toolsets, env, mcp, oauth, catalog, team_status, apps, runtime) 하나씩 실패(400 / 응답 모양 오류 / 시간 초과) | 실패한 부분 줄만 없고 나머지 부분 줄은 있다. `unread`에 그 부분 한 번 |
| AT-HC-03 | HC-02.AC-01 | AT-HC-01 | 문 로거에 `connections_part_failed profile=alpha part=toolset_config reason=admin_failed status=400` 한 줄. 로그에 응답 본문 문자열(가짜 관리 서비스가 넣은 표식 문자열)·토큰 없음 |
| AT-HC-04 | HC-01.AC-03 | 전체 요청(profile 없음), beta의 env만 실패 | alpha 표에 `unread` 없음, beta만 `unread` |
| AT-HC-05 | HC-02.AC-02·03, HC-05.AC-01 | (가) 관리 서비스 연결 거부 (나) 모든 요청 400 (다) team-kit 명령 실패로 통째 실패 유도가 가능한 경우 | (가)만 instruction "서버의 관리 기능에 닿지 못했어요…" 그리고 줄은 team-kit·채널·게이트웨이 줄 유지. (나)는 instruction 없음, `unread` 있음. 통째 실패 프레임은 실제 이유 코드와 `connections_failed` 로그 |
| AT-HC-06 | HC-03.AC-01 | env 10개(값 있음 2, 켠 묶음 필요 키 1, 끈 묶음 필요 키 1, 나머지 6) | 키 줄은 3개(값 있음 2 + 켠 묶음 필요 1) |
| AT-HC-07 | HC-03.AC-02 | apps: connected 1, connectable 2, unavailable 3; catalog 미설치 2 | unavailable 3·catalog 2 줄에만 `hidden_by_default: true`, 나머지 줄은 그 키 없음 |
| AT-HC-08 | HC-06.AC-03·04 | apps의 connectable 앱 하나에 `progress: {next:{kind:'resume'}, undo_until}` | 주 동작 `app_connect` 라벨 "이어서 하기", `app_undo` 라벨 "처음부터 다시". 연결된 앱의 `app_undo` 라벨은 "되돌리기" |
| AT-HC-09 | 회귀 | 실패 없는 정상 자료 | 지금 `gate/tests`·`tests/acceptance`의 연결 시험 전부 통과. 줄 id·동작 id 불변(키 줄 제외 규칙만 다름) |
| AT-HC-10 | NFR-HC-01·02 | 가짜 홈에 되돌리기 기록 2개(만료 1, 유효 1)와 값 있는 키 2개를 미리 두고 `document()` 실행. AT-HC-01~08 실행 중에도 같은 검사 | 실행 전후 가짜 홈 전체 파일 목록·내용·sha256 동일(만료 기록도 남음, 잠금 파일 새로 안 생김). 유효 기록 키 줄에만 "되돌리기", 만료 기록 키 줄에는 없음. 응답·로그에 입력 비밀값·본문 표식 없음 |
| AT-HC-11 | HC-02.AC-03·04 | 실제 `AdminClient`와 루프백 시험 HTTP 서버(임시 포트·임시 `admin.json`): (가) 200 + JSON 아님 (나) 200 + 1MB 초과 (다) 500 (라) 응답 지연으로 시간 초과(시험용으로 짧게 주입 가능) (마) 닫힌 포트 (바) `admin.json` 권한 0644 | (가)(나) `invalid_response`, (다) `admin_failed`·상태 500, (라)(마)(바) `admin_unavailable`. 이것을 `document()`로 부르면 (가)(나)(다)는 instruction 없음·`unread` 있음, (라)(마)(바)만 관리 기능 안내 |

## 앱 (`app/Tests/ConnectionsTests.swift`)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HC-20 | HC-01.AC-04 | 표에 alpha `unread: [{part:'toolset_config'}]` | 회색 안내 "일부 항목을 읽지 못했어요(도구 설정)" 계열 문장, 줄 그대로 |
| AT-HC-21 | HC-01.AC-05 | 첫 refresh 성공 → 둘째 refresh 실패(`reply.reason='admin_failed'`) | alpha 줄 유지, "마지막으로 확인한 내용이에요" + "연결 상태를 읽지 못했어요…" |
| AT-HC-22 | HC-05.AC-01 | refresh 실패 이유별: admin_unavailable / 연결 없음 / 그 밖 | 문장 셋이 design 3.1대로. admin_unavailable일 때만 "관리 기능" 문장 |
| AT-HC-23 | HC-05.AC-02 | 입력 창 열림 상태에서 refresh 실패 | 입력 창의 빨간 칸 문장은 비어 있다(표 읽기 문장 안 나옴) |
| AT-HC-24 | HC-03.AC-03 | `hidden_by_default` 줄 3개 포함 표 | 기본 목록·개수 요약에 없음. 토글 켜면 나옴 |
| AT-HC-25 | HC-06.AC-01 | 입력 창에서 주소 제출 → 응답 `outcome:'waiting', next:{kind:'secret_set', fields:[아이디, 비밀번호(secure)], guide:[…]}` | 입력 창이 열린 채 아이디·비밀번호 칸이 보인다 |
| AT-HC-26 | HC-06.AC-02 | 다음 단계가 `gateway_restart`인 응답 → 다시 시작 확인 | 확인 창이 연결 창의 sheet(앱 모달 아님). 시험은 확인 함수 주입으로 `runModal` 미호출 확인 |
| AT-HC-27 | HC-06.AC-02 | 입력 창이 닫힌(onDismiss) 직후 `show()` 호출 | 창이 보이고(key) 입력 상태 정리됨, 다음 동작 가능(busy false) |
| AT-HC-28 | HC-06.AC-03·04 | 줄의 주 동작 라벨 "이어서 하기", 다른 동작 "처음부터 다시" | "이어서 하기"는 그 라벨로 그려지고 누르면 `app_connect` 프레임. "처음부터 다시"는 확인(주입한 확인 함수) 뒤 `app_undo` 프레임, 확인 거절이면 프레임 없음 |
| AT-HC-29 | 회귀 | 기존 `ConnectionsTests` | 전부 통과 |

## team-kit (`TKL/tests/`의 새 시험 파일, 이름은 구현 담당)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HC-40 | HC-04.AC-01·06 | 가짜 홈: 직원 B의 시놀로지 연결됨(가짜 주소·가짜 아이디), 직원 A에 첫 연결 | A의 첫 응답이 로그인 단계(`next.kind:'secret_set'`, 칸에 비밀번호 보안 칸, 아이디 칸 `value`=B의 가짜 아이디), 주소 칸 없음. 초안에 `setup_done` `address` |
| AT-HC-41 | HC-04.AC-01, design 4.1 분류 | 다른 직원 없음, 가짜 Drive Client 자료(임시 경로 sqlite·log, 가짜 QuickConnect ID). (가) 완전 후보가 되는 자료 (나) `link_host`·아이디만 나오는 자료(부분 후보 1개) (다) 연결 행 둘이 서로 다른 `link_host`(부분 후보 2개) (라) `link_host` 값이 정책 밖(무효 후보) | (가) 주소 단계 없음, `setup_done`에 `address`, 로그인 칸 아이디 `value` 있음 (나) 주소 단계에 사람이 넣는 칸은 `api_base` 하나, `link_host`는 `value`로 채워짐, `setup_done`에 `address` **없음**. `api_base` 제출 후 검사 통과하면 그때 `address` 기록, 로그인 칸 아이디 채워짐 (다) 주소 두 칸 모두 비어 있고 아이디도 비어 있음, `address` 없음 (라) 후보 없음과 같음(주소 두 칸, 아이디 비어 있음), 무효 값은 응답·초안에 없음 |
| AT-HC-42 | HC-04.AC-01, NFR-HC-03 | Drive Client 자료 없음 / 깨진 sqlite / 정책 밖 주소 | 예외 없이 지금 주소 단계(쉬운 문장) |
| AT-HC-43 | HC-04.AC-03 | 주소가 정책 밖인 초안으로 로그인 제출 | 주소 단계로 돌아감, `input_error` 한 문장, `choose_sync_root` 아님 |
| AT-HC-44 | HC-04.AC-02 | AT-HC-40 | 응답·초안·로그에 B의 비밀번호 없음, B의 `.env`에서 비밀번호 이름을 읽지 않음(가짜 읽기 기록) |
| AT-HC-45 | HC-04.AC-04 | 가짜 `obsidian.json`에 보관함 2개(1개만 존재) | 고르기 옵션 1개 |
| AT-HC-46 | HC-04.AC-05 | design 4.4 판정표의 각 행을 가짜 홈으로 재현(시놀로지 후보 1·여럿·없음, Obsidian 찾음·못 찾음, Slack 봇, ddots Slack, Notion, X, Instagram, Mac 앱 1종 이상)하고 그 연결의 안내·칸을 받는다. 시놀로지는 판정표의 여섯 행(완전 1·완전 여럿·부분 1·부분 여럿·자기 초안 완전·후보 없음)을 각각 재현 | (1) 사람이 넣는 칸(보안 칸 + 값이 미리 채워지지 않은 일반 칸)의 id 집합이 표의 칸과 같다 (2) 안내 단계 수 ≤ 표의 최대(지금 단계 수는 고치기 전 코드에서 같은 시험으로 잰 값을 시험 안에 고정) (3) 페이지가 있는 단계는 `open_url`, 복사할 값이 있는 단계는 `copy`가 있다 (4) 금지어(`API`, `OAuth`, `manifest`, `scope`, 풀이 없는 `토큰`)가 화면 문장에 없다. 금지어 목록과 허용 풀이는 시험 안의 표로 둔다 |
| AT-HC-47 | NFR-HC-02 | `status`·`apps` 실행 | 가짜 홈 파일 변경 없음(값 찾기 포함) |
| AT-HC-48 | 회귀 | team-kit 기존 연결 시험 | 전부 통과 |
| AT-HC-49 | HC-06.AC-04 | 가짜 홈: 직원 A의 시놀로지 주소 초안을 실제 `app connect`로 만든다(주소만 제출). 다른 직원 C의 시놀로지 연결 값과 직원 A의 `.env` 다른 키를 미리 둔다. 그다음 실제 `app undo` | 직원 A의 금고 `app_setup` 칸 없음(초안 전 상태와 같음), 진행 기록 파일 없음, 직원 A `.env`·직원 C 값·명부·설정은 실행 전과 바이트 같음, 이어서 `apps --json`에서 그 앱은 `connectable`이고 `progress` 없음 |
| AT-HC-50 | HC-04.AC-01·02 | 연결된 다른 직원 둘이 서로 다른 NAS(가짜 주소 묶음 두 개) | 주소 단계에서 후보 2개를 고르기로 준다(라벨에 비밀값 없음). 하나를 고르면 그 묶음의 주소·아이디만 쓰이고 다른 묶음 값과 섞이지 않는다. 같은 묶음을 가진 직원 둘이면 후보 1개로 합쳐져 주소 단계를 건너뛴다 |
| AT-HC-51 | HC-04.AC-01 | (가) 이 직원 자신의 초안이 있고 다른 직원 연결도 있음 (나) 다른 직원은 진행 중 초안만 있음 (다) Drive Client 자료에 연결 행 둘, 로그에 ID 둘 | (가) 자신의 초안 값만 쓴다 (나) 그 초안은 후보가 아니다 (다) 행마다 후보, 로그의 ID는 행에 붙이지 않는다(하나일 때만 붙임) |
| AT-HC-52 | HC-04.AC-01·03, design 4.1 | (가) 이 직원 자신의 초안에 주소 두 개만 있고 검사를 통과(지금 직원 B와 같은 꼴, 가짜 값), 다른 출처 없음 (나) 같은 초안 + 같은 주소 묶음의 연결된 다른 직원 1명 (다) 자신의 초안 주소가 정책 밖(`api_base`가 http) | (가) 첫 응답이 로그인 단계, 사람이 넣는 칸은 아이디·비밀번호, `setup_done`은 `address` 유지 (나) 로그인 단계, 아이디 `value` = 그 직원의 가짜 아이디, 사람이 넣는 칸은 비밀번호 (다) 주소 단계로 돌아가 `input_error` 한 문장, `api_base` 칸은 비어 있고 `link_host`는 채워짐, `setup_done`에 `address` 없음, 폴더 고르기 아님 |
| AT-HC-53 | HC-04.AC-01·03·06, design 4.1(4판, 구현 검토 V-1) | (가) 자신의 초안 주소 두 칸이 모두 정책 밖(`setup_done`=`address`, 지금 직원 B와 같은 꼴, 가짜 값) + 연결된 다른 직원 1명(완전 후보, 가짜 아이디) (나) 같은 초안 + 서로 다른 완전 후보 2개 (다) `api_base`만 정책 밖인 자기 초안 + 다른 출처는 `link_host`만 있는 부분 후보 1개 | (가) 첫 응답이 로그인 단계, 사람이 넣는 칸은 비밀번호뿐, 아이디 `value`=그 후보 아이디, 초안 주소 = 후보 값, `setup_done`에 `address`, `hint`에 주소를 바꿨다는 문장, 초안의 옛 주소 값은 응답에 없음. 이어서 `app undo`하면 초안 칸이 처음 상태(이 시험이 만든 옛 초안 전)로 돌아감 (나) 후보 고르기 2개+직접 넣기, 라벨에 비밀값 없음, `input_error` 있음 (다) 주소 단계, `api_base` 칸 비어 있음, `link_host`는 부분 후보 값, `address` 없음 |
| AT-HC-54 | design 4.1 라벨(구현 검토 V-2) | 완전 후보 2개(가짜 `link_host` 서로 다름, 아이디 하나는 있음 하나는 없음), 그리고 `link_host`·아이디가 같은 후보 2개(출처 다름, `api_base` 다름) | 라벨이 "<link_host> · <아이디>" / "<link_host>" 꼴, 같은 라벨에는 출처 꼬리말, 라벨·옵션 어디에도 비밀번호 값·직원 id 없음 |

## 실물 확인 (사장, 서버 적용·0.2.2 설치 뒤)

| ID | 확인 |
|---|---|
| M1 | 직원 A 표가 보인다. 못 읽은 부분이 있으면 회색 안내만 있다 |
| M2 | 서버 `gateway.log`에 직원 A의 `connections_part_failed … part=toolset_config … status=400` 줄이 있는지(원인 확인) — 구현 담당이 로그 줄만 보고 |
| M3 | 한 직원의 기본 목록이 100줄 이하, 연결할 수 없는 앱은 토글로만 보인다 |
| M4 | 어느 직원을 골라도 빨간 "관리 기능이 꺼져 있어요"가 안 나온다 |
| M5 | 직원 B 시놀로지 줄에 "이어서 하기" → 로그인 단계(비밀번호만, 아이디는 후보가 있으면 채워짐) → 폴더 고르기 → 다시 시작 확인(연결 창 위) → 연결됨. 이어 가기 경로가 합격 조건이다. "처음부터 다시"는 AT-HC-49로 확인하며, 사장이 따로 시험하려면 새 시험용 연결에서 한다 |
| M6 | 연결 도중 창을 닫아도 메뉴·설정의 "에이전트 연결…"이 열린다 |
| M7 | 아이메시지 작성 중 표시가 0.2.2에서도 된다(HEJO-IMESSAGE M9와 같은 확인) |
