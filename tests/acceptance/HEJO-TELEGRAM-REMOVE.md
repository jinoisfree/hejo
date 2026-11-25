# HEJO-TELEGRAM-REMOVE 수락 시험 — 3판(계획 검증 2회차 반영)

- 원본 요구: [spec.md](../../docs/changes/HEJO-TELEGRAM-REMOVE-20261125/spec.md). 상태: 모두 "명세 완료 · 코드 미작성 · 미실행 · 미검토".
- 코드는 구현 담당이 공개판·운영판 worktree에 옮긴다. 자동 시험은 `tests/acceptance/test_telegram_remove.py`(문)와 `app/Tests/`(앱, 기존 `DiscordTests.swift`에 더하거나 새 파일 — `TestMain.swift` 등록)에 둔다. 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 공통 환경: 임시 `HERMES_HOME`, HEJO-DISCORD 수락 시험과 같은 가짜 명부(`default`/`Main`, `alpha`/`Alpha`, `beta`/`Beta`), 실제 Hermes 모듈 import, `gate.tests.support` 러너. 증거 수준은 표시가 없으면 2.
- 기대값 근거: 사장 결정(brainstorm.md), 안내판 계약(`hejo-wire-v1.json`), 기존 서버 오류 계약(두 기준판 `server.py` 600~604행 — 제거된 기능 프레임은 `unexpected_frame`), HEJO-DISCORD 승인 기대값 중 텔레그램과 무관한 부분.

## 문·안내판

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HTR-01 | 01.AC-01 | 문 등록 뒤 `get_platform_handler_factories('telegram')`, `('discord')` | 텔레그램 0개, 디스코드 1개. `hejo` 플랫폼 등록 1개 |
| AT-HTR-02 | 01.AC-02, 05 | 저장소 추적 파일에서 대소문자 무시 `telegram` 검색(`docs/changes/` 제외. TASK-01·02 시점에는 계획 담당이 TASK-04에서 고칠 `docs/ARCHITECTURE.md`·`docs/spec/current/`도 제외하고, TASK-04 뒤 다시 제외 없이 실행) | 검사 제외 파일: `tests/acceptance/HEJO-TELEGRAM-REMOVE.md`·`test_telegram_remove.py`(이 시험 자신 — 부재 단언은 여기 AT-HTR-01에만 둔다). 나머지 모든 추적 파일에서 각 줄의 리터럴 `HEJO-TELEGRAM-REMOVE`·`HEJO-TELEGRAM`·`platform.telegram.`(Hermes 번역 키)을 지운 뒤 대소문자 무시 `telegram` 일치 0. 파일 `gate/telegram.py`·`gate/telegram_comments.py`·`app/Sources/TelegramState.swift` 없음 |
| AT-HTR-03 | 01.AC-03 | 홈에 옛 `hejo/telegram.json`(0600, 임의 내용)과 `shared/hejo/telegram/settings.json`·`topics.json`을 미리 둠 → 문 켜기, 앱 짝짓기·연결, 글 1개 왕복, 문 끄기 | 기동·왕복 정상. (읽기 0) 문 켜기 전에 `sys.addaudithook`으로 `open`·`os.listdir`·`os.scandir`·`os.stat`류 감사 이벤트를 기록하기 시작해 문 끄기까지, 경로 인자가 두 위치(`hejo/telegram.json`, `shared/hejo/telegram/` 아래) 중 하나로 해석되는 이벤트 0건(전체 이벤트 수가 0이 아님도 확인 — 훅 동작 증명). (변경 0) 두 경로의 파일 목록·바이트·mtime 전후 동일. (생성 0) 미리 두지 않은 별도 홈에서 같은 흐름 뒤 `shared/hejo/telegram/` 없음 |
| AT-HTR-04 | 02.AC-01 | `schemas/hejo-wire-v1.json` | `$defs`에 이름이 `telegram`으로 시작하는 정의 0, 파일 어디에도 `"#/$defs/telegram` 참조 0. 공개 main `c22e677`(운영판은 `7617b0d`) 판과 비교해 바뀐 것은 텔레그램 정의 6종과 그 참조 줄 제거뿐(JSON으로 읽어 그 키들만 뺀 기준 판과 같음) |
| AT-HTR-05 | 02.AC-02 | 연결된 앱 소켓에 `{"v":1,"type":T,"id":"x-T"}`(+ `telegram_save`는 `"enabled":true`)를 T = `telegram`·`telegram_pair`·`telegram_unpair`·`telegram_save` 순서로 보냄, 이어서 `discord` 상태 조회 | 각각 `{"type":"error","code":"unexpected_frame","ref":"x-T"}` 1개(네 `ref` 모두 확인). 이어서 같은 소켓으로 보낸 `{"v":1,"type":"discord","id":"dc-after"}`에 `discord_status`(ref `dc-after`) 응답, 소켓 닫힘 0. 기록장 불변 |
| AT-HTR-06 | 02.AC-03 | `client.pair(features=["rooms","telegram","discord"])` | 짝짓기·`welcome` 성공, 디스코드 상태 조회 정상 |
| AT-HTR-07 | 04.AC-02 | `gate.journal.RECORD_TYPES` | `{'message','edit','delete','state','room','room_delete'}`(AT-SM-02와 같음) |
| AT-HTR-08 | 01.AC-02 | `gate.adapter` 모듈의 어댑터 클래스 | `claims_external`·`telegram` 속성 없음. `send_typing`·`stop_typing`·기록 후크 동작은 기존 디스코드 시험 AT-HD-43(`send_typing` 차례·발신)과 AT-HD-31(직원 답 발신·기록 대응)이 개정 뒤에도 통과로 확인 |

## 앱

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-HTR-20 | 03.AC-01 | `GateClient.features` | `== ["rooms","discord"]` 정확 비교 |
| AT-HTR-21 | 03.AC-02 | 설정 창 생성 | "연결과 동기화" 페이지에 `discordSection`이 붙어 있음. 창 속성·하위 뷰에 텔레그램 구역 없음(타입 `TelegramSettingsSection` 정의 자체가 없어 빌드로 확인), 소스에 `TelegramState` 정의 0, SwiftUI import 0(이 작업이 건드린 파일) |
| AT-HTR-22 | 03.AC-03 | 앱 대역 게이트(기존 파이썬 픽스처)로 연결 → 첫 기록 적재까지 | (텔레그램 0) 앱이 보낸 프레임 종류에 `telegram`으로 시작하는 것 0. (디스코드 보존) 각 `welcome` 뒤 `discord` 조회 프레임 정확히 1개를 보내고, 대역이 `discord_status`로 응답한 뒤에도 기록 적재가 끝까지 진행(관측은 첫 기록 적재 완료까지, 조회 전에 끝내지 않음). `gate/tests/history_baseline.py`의 대역은 기록 외 요청 종류가 `discord`뿐이고 연결당 1건임을 단언하도록 갱신(조회 제거 금지) |

## 디스코드 개정(HEJO-DISCORD.md에 그대로 반영)

| ID | 바뀌는 점 |
|---|---|
| AT-HD-01 | 기대에서 "`telegram` 공장 1개 유지." 문장을 지운다(텔레그램 부재는 AT-HTR-01이 유일하게 확인). 나머지 동일 |
| AT-HD-34 | 행 내용을 "삭제 — HEJO-TELEGRAM-REMOVE"로 바꾼다(교차 반영 대상 없음) |
| AT-HD-37 | 기대를 원문으로: 덧붙임 줄 `선택: A / B`와 `(이 선택은 hejo 앱에서 눌러 주세요)`(HEJO-IMESSAGE REQ-HI-05.AC-08과 같음) |
| AT-HD-44 | 삭제(`test_telegram.py` 통과 조건). 같은 표시 |
| AT-HD-52 | `["rooms","discord"]` 정확 비교 |
| AT-HD-53 | "디스코드 구역이 '연결과 동기화' 페이지에 있음"(텔레그램 구역과 함께 → 삭제). 안내 문구 조건 동일 |
| 공통 환경 줄 | "HEJO-TELEGRAM 수락 시험과 같은 가짜 명부" → 명부 값을 그대로 적은 문장으로 |
| 관측 보충 줄 | AT-HD-52 보충(TelegramTests 갱신 언급) 삭제 |
| M8 | 삭제 표시 |
| `test_discord.py` | 251행을 `assert len(factory)==1`로(텔레그램 공장 조회 삭제), `test_at_hd_34_*` 함수 삭제. 그 외 수정 없음 |

## 기존 시험 정리

| ID | 대상 | 기대 |
|---|---|---|
| AT-HTR-30 | 삭제: `tests/acceptance/test_telegram.py`, `HEJO-TELEGRAM.md`, `app/Tests/TelegramTests.swift`(+`TestMain.swift` 등록), `gate/tests/telegram_settling.py`, `evidence/HEJO-TELEGRAM/`, 운영판은 `gate/tests/test_telegram_comments.py` 추가 | 파일 없음 |
| AT-HTR-31 | `test_slack_move_gate.py` 안내판 해시 | AT-HTR-04를 통과한 새 파일의 sha256으로 갱신, 주석 한 줄 "HEJO-TELEGRAM-REMOVE removed the HEJO-TELEGRAM definitions only". `HEJO-SLACK-MOVE.md` AT-SM-02 해시 이력에 같은 내용 추가 |
| AT-HTR-32 | 합격 판정(재량 없음) | 아래 (a)~(e)가 모두 참이어야 합격. (a) 필수 통과(실패·건너뜀 0): `tests/acceptance/test_telegram_remove.py`, `tests/acceptance/test_discord.py`, `tests/acceptance/test_slack_move_gate.py`, `gate/tests/test_delivery_parity.py`, `"$HEJO_PYTHON" -m gate.tests.gateway_delivery` 종료 0, `gate/tests/history_baseline.py`는 실제 앱 바이너리가 필요한 수동 측정 스크립트라 import 종료 0(`-c 'import gate.tests.history_baseline'`)만 필수, 앱 `bash app/scripts/build.sh`와 `bash app/scripts/test.sh` 각각 종료 0(공개판 기준선에서 이미 실패하면 고치기 전에 멈추고 보고). (b) 런타임 Python `scripts/scan_private.py` 종료 0. (c) 전체 실행: `scripts/test.sh`는 `set -e`라 pytest가 멈추면 뒤 검사가 돌지 않으므로, 기준선(같은 worktree 시작 커밋, 고치기 전)과 변경 후 각각 같은 환경에서 `"$HEJO_PYTHON" -m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider -rA --junitxml=<증거>/pytest-<baseline|after>.xml`을 따로 실행하고, 이어서 `-m gate.tests.gateway_delivery`, `bash app/scripts/test.sh`를 각각 실행해 종료 코드를 따로 기록한다. 판정: (c1) 두 pytest 실행 모두 끝까지 완료 — 종료 코드 0 또는 1만 허용(2 중단·3 내부 오류·4 사용법·5 수집 0 = 불합격), junit의 `errors` 0(수집·설정 오류 없음), 수집 수 > 0. 기준선에서 c1이 깨지면 고치기 전에 멈추고 보고. (c2) 수집 노드 ID: 변경 후 집합 = 기준선 집합 − 허용 삭제(AT-HTR-30 삭제 파일의 노드, `test_at_hd_34_*`) + 새 노드(`test_telegram_remove.py`, 앱 시험 추가분). 그 밖의 누락 1개 = 불합격. (c3) 실패 노드 ID ⊆ 기준선 실패 집합이고, 허용 기존 실패는 이 작업이 바꾸거나 지운 파일에 속하지 않으며 (a) 목록에 없는 것뿐. (c4) 건너뜀 노드 ID ⊆ 기준선 건너뜀 집합(새 건너뜀 0). 새 실패 1개 = 불합격. (d) 운영판 추가: `install/check_google_compat.py --component hejo --target <트리> --validate-build` 종료 0, 임시 위치 조립 종료 0·조립본에 `telegram*.py` 0. (e) 운영판 앱: 기준선에서 `app/scripts/build.sh`가 종료 0이면 (a)의 앱 항목이 필수. 기준선에서 이미 실패하면 운영판 REQ-HTR-03(AT-HTR-20~22)은 "미검증(운영판 앱은 배포되지 않음 — 릴리스에 app/ 없음)"으로 기록하고, 대신 AT-HTR-02 소스 검사만 필수. 이 경우도 TASK-03을 막지 않는다(서버 설치물은 gate·install·schemas·hub·config) |

## 서버(TASK-03, 증거 3·4)

| ID | AC | 관측 | 기대 |
|---|---|---|---|
| AT-HTR-40 | 07.AC-01 | `gateway_state.json` `platforms`, 설치 링크 6개, 공용 RELEASE, capabilities | `telegram` 없음. `discord`·`hejo`·프로필별 `hejo` 5개·`slack`·`photon` 있음. 링크·RELEASE = 운영판 새 커밋 Q. capabilities 200 |
| AT-HTR-41 | 07.AC-02 | `<HOME>/hejo/telegram.json`, `<HOME>/shared/hejo/telegram/` | 없음. 백업 해시 = 원본 해시 기록 |
| AT-HTR-42 | 07.AC-01 | 재시작 이후 게이트웨이 로그 | 새 ERROR/Traceback 0, 텔레그램 어댑터 연결 줄 0, 디스코드 봇 로그인 줄 있음. 토큰·id 원문이 hejo 로거 줄에 없음 |
| M1 | 07.AC-03 | 사장: 디스코드 방 채널에 직원 앞 글 1개 | hejo 앱과 디스코드에 직원 답이 보임 |
| M2 | 07.AC-03 | 사장: (TASK-04 새 앱 설치 뒤) 설정 → 연결과 동기화 | 텔레그램 구역 없음, 디스코드 구역 있음 |
| AT-HTR-43 | 07.AC-04 (운영 전 필수 리허설, 증거 3) | 운영 적용 전, 임시 `HERMES_HOME`(0700)에 가짜 `hejo/telegram.json`(0600)·`shared/hejo/telegram/{settings.json,topics.json,sent.jsonl}`(디렉터리 0700, 파일 0600, 가짜 내용)을 두고 design 4절 단계 4·5·7(백업 → `HERMES_HOME=<임시> hermes config set platforms.telegram.enabled false` → 원본 삭제) 뒤 [롤백]의 자료 복원·`hermes config unset platforms.telegram.enabled` 실행 | 경로별 sha256·권한 비트(파일·디렉터리)·파일 목록이 시작 기록과 같음. `HERMES_HOME=<임시> hermes config get platforms.telegram.enabled` 출력이 시작 기록과 같음(키 없음 상태). 운영 홈 접근 0(명령마다 `HERMES_HOME` 명시). 불일치면 운영 적용을 시작하지 않고 보고 |
| AT-HTR-44 | 07.AC-04 (롤백이 실행된 경우만) | 운영 롤백 뒤 | 경로별 sha256·권한이 사전 기록과 같음, `hermes config get platforms.telegram.enabled`가 사전 기록과 같음, 설치 링크 6개·공용 RELEASE = `7617b0d`, `gateway_state` platforms가 사전 기록과 같음(텔레그램 포함). 릴리스 되돌리기 자체는 `7617b0d` 릴리스의 같은 `hejo-install --home` 경로(현재 운영본을 설치한 경로)를 쓴다 |
| AT-HTR-45 | 07.AC-02 | 백업 삭제 시점 | M1(TASK-03)과 M2(TASK-04) 둘 다 사장 통과 기록 뒤에만 백업 폴더 삭제. 삭제 뒤 폴더 없음 확인 |
