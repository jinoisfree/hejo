# HEJO-CONNECTIONS 수락 시험 명세

1판 · 2026-11-20 · 명세 [spec.md](../../docs/changes/HEJO-CONNECTIONS-20261120/spec.md), 설계 [design.md](../../docs/changes/HEJO-CONNECTIONS-20261120/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토 없음(계획 검증 꺼짐). 기대값 출처: spec 요구와 design 2~4절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

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
| AT-HC-10 | NFR-HC-01·02 | AT-HC-01~08 실행 중 | 가짜 홈 파일 쓰기 없음(표 읽기), 응답·로그에 입력 비밀값·본문 표식 없음 |

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
| AT-HC-28 | HC-06.AC-03 | 줄의 주 동작 라벨 "이어서 하기" | 그 라벨로 그려지고 누르면 `app_connect` 프레임 |
| AT-HC-29 | 회귀 | 기존 `ConnectionsTests` | 전부 통과 |

## team-kit (`TKL/tests/`의 새 시험 파일, 이름은 구현 담당)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HC-40 | HC-04.AC-01·06 | 가짜 홈: 직원 B의 시놀로지 연결됨(가짜 주소·가짜 아이디), 직원 A에 첫 연결 | A의 첫 응답이 로그인 단계(`next.kind:'secret_set'`, 칸에 비밀번호 보안 칸, 아이디 칸 `value`=B의 가짜 아이디), 주소 칸 없음. 초안에 `setup_done` `address` |
| AT-HC-41 | HC-04.AC-01 | 다른 직원 없음, 가짜 Drive Client 자료(임시 경로 sqlite·log, 가짜 QuickConnect ID) | 찾은 값이 정책 검사를 통과하면 쓰고, `api_base`를 만들 수 없으면 주소 단계는 남되 찾은 `link_host`는 미리 채움 |
| AT-HC-42 | HC-04.AC-01, NFR-HC-03 | Drive Client 자료 없음 / 깨진 sqlite / 정책 밖 주소 | 예외 없이 지금 주소 단계(쉬운 문장) |
| AT-HC-43 | HC-04.AC-03 | 주소가 정책 밖인 초안으로 로그인 제출 | 주소 단계로 돌아감, `input_error` 한 문장, `choose_sync_root` 아님 |
| AT-HC-44 | HC-04.AC-02 | AT-HC-40 | 응답·초안·로그에 B의 비밀번호 없음, B의 `.env`에서 비밀번호 이름을 읽지 않음(가짜 읽기 기록) |
| AT-HC-45 | HC-04.AC-04 | 가짜 `obsidian.json`에 보관함 2개(1개만 존재) | 고르기 옵션 1개 |
| AT-HC-46 | HC-04.AC-05 | 모든 안내 문장 | 금지어 목록(`API`, `OAuth`, `manifest`, `scope`, `토큰` 단독 — 풀이 없는 경우)이 화면 문장에 없음. 금지어 목록과 허용 풀이는 시험 안의 표로 둔다 |
| AT-HC-47 | NFR-HC-02 | `status`·`apps` 실행 | 가짜 홈 파일 변경 없음(값 찾기 포함) |
| AT-HC-48 | 회귀 | team-kit 기존 연결 시험 | 전부 통과 |

## 실물 확인 (사장, 서버 적용·0.2.2 설치 뒤)

| ID | 확인 |
|---|---|
| M1 | 직원 A 표가 보인다. 못 읽은 부분이 있으면 회색 안내만 있다 |
| M2 | 서버 `gateway.log`에 직원 A의 `connections_part_failed … part=toolset_config … status=400` 줄이 있는지(원인 확인) — 구현 담당이 로그 줄만 보고 |
| M3 | 한 직원의 기본 목록이 100줄 이하, 연결할 수 없는 앱은 토글로만 보인다 |
| M4 | 어느 직원을 골라도 빨간 "관리 기능이 꺼져 있어요"가 안 나온다 |
| M5 | 직원 B 시놀로지 줄에 "이어서 하기" → 로그인 단계(아이디 채워짐, 비밀번호만) → 폴더 고르기 → 다시 시작 확인(연결 창 위) → 연결됨. 또는 "처음부터 다시"로 초안이 사라짐 |
| M6 | 연결 도중 창을 닫아도 메뉴·설정의 "에이전트 연결…"이 열린다 |
| M7 | 아이메시지 작성 중 표시가 0.2.2에서도 된다(HEJO-IMESSAGE M9와 같은 확인) |
