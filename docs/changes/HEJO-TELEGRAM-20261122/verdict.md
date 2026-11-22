# HEJO-TELEGRAM 검증 판정

## 1차 (2026-11-23) — 미완료(구현 보류 처리)

- 대상: 구현 보고 [impl-report.md](impl-report.md)(보류 보고 커밋 `a2caf0a`), TASK-02 커밋 `53acb8e4ee5c4b79aa01e23320851a0c62648092`, 작업 트리의 미커밋 `gate/telegram.py`·`tests/acceptance/test_telegram.py`(TASK-03 작성 중). 기준 계획 `29326c5`(2판).
- 판정: **미완료**. 완료 조건(TASK-02~06 구현·AT-HT-01~45, 50~52 통과·전체 시험·개인값 검사)에 아직 이르지 않았다. 검증 조건: 교차 모델(계획 Claude, 구현 Codex).

### 보류 HT-B01 확인과 원인 분류

- 보고 내용: 공통 환경의 쓸 수 있는 방은 `default`·`alpha`·`beta`·`G` 4개인데 수락 시험(활성 준비, AT-HT-05·12)은 토픽 3개를 요구한다.
- 직접 확인: `gate/roster.py` `employees()`(26-38행)는 `profiles_to_serve`의 모든 프로필을 직원으로 돌려주고 기본 프로필을 빼는 규칙이 없다. spec 용어 "쓸 수 있는 방 = 명부에 있는 직원의 1:1 방 + 살아 있는 단체방"과 사장 결정 "모든 방 전부"에 따르면 기본 프로필 방도 포함이다. 수락 시험 공통 환경은 `default`를 명부에 넣으면서 기대값에서 빠뜨렸다.
- **원인 분류: 수락 시험 오류**(10-planning 7절). 요구·설계·구현은 맞고, 기대값이 spec 용어와 명부 계약에서 독립적으로 정해지는 값(4)과 달랐다. 구현자 권고 (A)를 채택한다. 제품에서 `default`를 빼는 (B)는 사장 결정("모든 방 전부")을 바꾸므로 기각한다.
- 조치(기획설계, 이 판정과 같은 커밋): 수락 시험 명세 3판 — 공통 환경 `default` 표시 이름을 `Main`으로 정하고, 활성 준비·AT-HT-05·AT-HT-12·AT-HT-45의 토픽 수와 이름을 4개(`Main`·`Alpha`·`Beta`·`Team`)로 고쳤다. 합격 기준의 엄격함은 그대로다. spec·design 변경 없음. handoff 0·8번 판 표기 갱신(계획 검증 PR-06 권고 정리 포함), tasks 상태 갱신.

### TASK-02 확인 (최종 판정은 TASK-06 뒤)

- 직접 읽은 것: `53acb8e`의 `gate/telegram.py`(공장·감싸기·짝짓기·금고·설정·상태·`claims_external`), `gate/rooms.py`(방 레코드를 잠금 밖에서 `recorded`로 전달), `gate/__init__.py`·`server.py`·`adapter.py` 호출 교체, 규격 프레임 교체, `gate/imessage.py`·`test_imessage.py` 삭제.
- 설계 적합성(4.2): 칸 배치·책임 분리 맞음(새 모듈 하나가 소유, adapter·server·rooms는 부르기만). 공장 안 네트워크 호출 없음. 짝 표지 8자(`token_hex(4)`), 그룹·계정 id는 금고에만. `claims_external` 하나가 판정 권위이고 예외는 통과, 차지 뒤 예외는 안내 후 끝(design 5절). 차지 시 `_accept_update` 호출. 위반 없음.
- 관찰(차단 아님, 최종 검토에서 다시 봄): 짝짓기 경합으로 `receive_external`이 코드를 못 쓰면 아무 응답 없이 끝난다 — 코드가 이미 쓰인 경우라 AC-03의 "통과"가 아니라 무응답이 된다. TASK-03의 수신 완성 때 이 경로가 안내 또는 통과 중 무엇인지 정해 시험으로 보이게 할 것(design 5절 2단계: 쓰인 코드는 통과).
- 증거: 구현 보고의 `pytest tests/acceptance/test_telegram.py` 9 passed(로그 `.build/telegram-evidence/task02.log`), 수준 2. 검증 역할은 같은 시험을 반복하지 않았다(코드 변경 뒤 TASK-06 전체 실행에서 확인).

### 개인값 검사 실패

- 구현 보고의 `scan_private.py` 종료 1은 다른 작업(HEJO-DEADLINE-CLOSE) 문서의 절대 경로 4건이다. 이 작업 파일 지적 0. 그 작업이 이미 자리표시자로 바꾸는 커밋(`d88e2c8`)을 냈으므로 TASK-06에서 다시 실행해 이 작업 기준으로 판정한다. 남으면 다른 작업 몫으로 보고만 한다.

### 다음

- 구현 담당: 수락 시험 명세 3판에 맞춰 미커밋 TASK-03 시험을 고치고 TASK-03 → TASK-04, TASK-05 → TASK-06을 이어 간다(보완 plan).

## 2차 (2026-11-23) — TASK-02~06 완료(작업 전체는 부분 완료: TASK-07·07b·08 남음)

- 대상: 구현 보고 [impl-report.md](impl-report.md) TASK-03~06 절(보고 커밋 `1150a27`), 제품 최종 `1ef3ad27fbe0e960fb542ea14bd0a3ef7d62262e`(TASK-03 `338c35a`, TASK-04 `c9a653a`·`9fd6512`·`1ef3ad2`, TASK-05 `0ded4b8`). 검증 시점 HEAD `ce0e3d4`(그 뒤 커밋은 다른 작업 문서뿐 — `git diff 1150a27 HEAD -- gate schemas app tests`는 다른 작업 수락 시험 명세 1개).
- 판정: **이번 지시 범위(TASK-02~06) 완료.** 작업 전체 완료 조건(서버 적용·앱 공개·실물 M1~M8·현재 명세 반영)은 남아 **부분 완료**다. 검증 조건: 교차 모델(계획 Claude, 구현 Codex).

### HT-B02 판정과 조치

- 실패: `tests/acceptance/test_slack_move_gate.py` AT-SM-02가 통신 규격 전체 SHA-256을 `4f365159…`로 고정. 이 단정의 뜻은 "Slack 이전이 앱 통신 규격을 바꾸지 않는다"이고, HEJO-DEADLINE-CLOSE도 정의 추가 때 같은 방식으로 갱신했다(그 작업 verdict V-2).
- 직접 확인: `git diff d3f5b5f HEAD -- schemas/hejo-wire-v1.json`의 바뀐 줄은 모두 아이메시지 프레임 삭제와 텔레그램 프레임 추가(spec REQ-HT-02, design 4절)다. Slack 관련 정의 변화 0. 현재 규격 SHA-256 `7b3c2db703a83824ee6d173262bbefec34b5210c74954d7c5dc8556c1fb0f75b`.
- **원인 분류: 수락 시험 오류**(다른 작업의 불변 조건이 이 작업의 승인된 규격 변경을 반영하지 못함). 기획설계가 고정 해시를 새 값으로 갱신하고 근거 주석을 달았다(`test_slack_move_gate.py`), 명세 `HEJO-SLACK-MOVE.md` AT-SM-02에 같은 근거를 적었다. 레코드 종류 불변 단정과 나머지 Slack 동작 단정은 그대로다.

### 직접 확인한 것

- 코드: `gate/telegram.py` 전체 흐름(수신 판정·경합 재확인·`_accept_update`·답장/토픽 대상·본문/첨부·중복, 토픽 동기화는 `_bot` 네 Bot API만·예외 종류만 로그·I/O 전후 짝 표지 재확인, 스레드 대기열·사장 즉시/직원 정착·`notify`·닻·버튼 줄·첨부 사전 판별 📎/실행 실패 로그·`sent.jsonl` 0600·손상 처리, 작성 중 4초 줄이기), `gate/adapter.py` 시작 실패 정리, 앱 `TelegramState`·설정 구역·방 메뉴 제거.
- 설계 적합성(4.2): 칸·책임 분리 맞음(모듈 하나가 소유, adapter·server·rooms는 부르기만). 그룹·계정 id는 금고에만, 밖은 짝 표지. 감싼 처리기 하나·`claims_external` 하나가 판정 권위. 아이메시지 모듈·`photon` 등록·규격·앱 화면·시험 제거(AT-HT-42). 본체·플러그인·team-kit 무수정. 기록장 레코드 종류 불변. 위반 없음.
- 1차 관찰(짝짓기 경합 무응답)은 해소: 금고 잠금 안 재판정, 이미 쓰인 코드면 원래 처리기로 같은 이벤트 한 번(`test_pair_consumed_between_claim_and_admission`).
- 수락 시험 대응: 시험 이름의 AT 번호로 AT-HT-01~45, 50~52 모두 대응을 확인했다(묶은 시험 포함). AT-HT-12·05는 3판 기대(4개, `Main`) 그대로.
- 경미 관찰(차단 아님): AT-HT-05의 "옛 그룹 글은 통과" 단정은 재짝짓기 시험에 직접 없고, `claims_external`의 짝 일치 규칙과 AT-HT-26(d)(다른 그룹 통과)로 보장된다. 수신 중복 판정·닻·답장 찾기가 기록장 전체를 훑는다 — 방이 많아지면 느려질 수 있는 최적화 후보로 남긴다(HEJO-AUDIT 몫).

### 검증 증거

| 검사 | 결과 | 비고 |
|---|---|---|
| `TZ=Asia/Seoul PYTEST_ADDOPTS=--basetemp=/tmp/ht-v2full bash scripts/test.sh`(검증 역할 실행, 해시 갱신 뒤 작업 트리, 제품 `1ef3ad2`) | 종료 **0**, Python **427 passed**, 앱·통신 고정물·훅 단계 모두 PASS | `.build/telegram-evidence/verdict2-full.log`, `verdict2-full.exit` |
| `pytest tests/acceptance/test_slack_move_gate.py`(해시 갱신 뒤) | 종료 0, 18 passed | `.build/telegram-evidence/verdict2-slackmove.log` |
| 구현 보고 증거(직접 로그 확인, 반복 안 함): 문 수락 시험 38 passed, 앱 전체 종료 0, AT-HT-44 수준 3(5회 0.017~0.033초), 게이트웨이 배달 종료 0, mutation 3종 검출 | 보고와 로그 일치 | `.build/telegram-evidence/` |
| 임시 HERMES_HOME `scan_private.py` | 종료 **1**: 다른 작업 `HEJO-DEADLINE-CLOSE-20261122/impl-report.md` 97·109행, `verdict.md` 127·146행 절대 경로 4건. **이 작업 파일 0건** | 그 작업 커밋은 main에 있고 원격(`github/main`)에는 아직 없다. 푸시 전에 그 작업이 고쳐야 한다 — 사용자에게 보고 |

- 도달 증거 수준: 기능 2(대역 통합), AT-HT-44 3. 실제 텔레그램 SDK·봇·안드로이드 실물은 미검증(TASK-07·08).

### 남은 일

1. TASK-07 서버 적용(사용자 별도 허가 필요): 사장 준비(봇·포럼 그룹·봇 관리자 권한·`TELEGRAM_BOT_TOKEN`·허용 계정 `group_allow_from`) → Hermes 환경 텔레그램 의존성 설치 → 공용 릴리스 → 게이트웨이 재시작 → AT-HT-60·61. 적용 순간부터 hejo의 아이메시지 연결이 사라진다(아이메시지는 Hermes 직통).
2. TASK-07b 앱 공개, TASK-08 실물 M1~M8, 현재 명세(ARCHITECTURE) 반영.
3. 푸시는 사용자 화면 승인. 단, main에는 다른 작업의 개인값 검사 지적 4건이 있어 공개 저장소 푸시 전에 정리가 필요하다.

## 3차 (2026-11-23) — TASK-07 미완료(보류 처리)

- 대상: TASK-07 보류 보고(커밋 `3c299bb`, [impl-report.md](impl-report.md) TASK-07 절, [evidence/HEJO-TELEGRAM/TASK-07.md](../../../evidence/HEJO-TELEGRAM/TASK-07.md)). 인계 [handoff-task07.md](handoff-task07.md) 1판(`223a191`).
- 판정: **미완료**(운영 변경 전 보류). 서버는 바뀌지 않았다: 구현 보고의 `stopped-state.json` — RELEASE·게이트웨이 PID·보호 파일 메타데이터가 착수 전과 같다.
- 확인한 것: 적용 전 기록과 롤백 명령이 증거 문서에 먼저 쓰였다. 현재 공용 RELEASE `227ef160…`와 착수 HEAD의 설치 범위 차이는 이 작업 커밋뿐이다(보고 로그 `release-diff-commits.log`). Hermes venv에 텔레그램 모듈 없음(직접 설치 안 함 — 인계대로).

### HT-B03 원인 분류

- 보고: 인계가 실행하라고 한 `hejo-install --check`는 운영 `config.yaml`을 읽고 출입증 파일(`hejo/admin.json`) 지문을 비교한다. 같은 인계 3번이 "설정·비밀 파일을 열지 않는다"고 해서 충돌한다.
- 직접 확인: `install/hejo-install:678-736`의 `--check`는 상태 이름·경로만 출력한다(`changed <path>`, `owner_set <label>` 등). 값을 출력하지 않는다. 같은 명령은 HEJO-IMESSAGE TASK-10에서도 실행됐다. 게이트웨이 재시작도 같은 파일을 읽는다 — 인계 3번 문구대로라면 재시작 자체가 불가능해진다.
- **원인 분류: 설계·계약 오류(인계 문구)**. 금지의 뜻은 "에이전트가 내용을 보거나 옮기지 않는다"(AGENTS.md)인데 문구가 도구 내부 읽기까지 막는 것처럼 적혔다. 요구 불변.
- 조치: [handoff-task07.md](handoff-task07.md) 2판 3번에 예외를 명시했다 — 정해진 운영 도구(`hejo-release`, `hejo-install --check`, 게이트웨이 재시작)의 내부 읽기는 허용, 에이전트 직접 열람은 계속 금지, 도구 출력에 값처럼 보이는 줄이 있으면 옮기지 말고 멈춤.

### 재개 조건

- 최신 RELEASE·HEAD 차이를 다시 확인한다(그 사이 다른 작업 커밋이 들어왔으면 설치 범위에 미검증 변경이 없는지 다시 판단).
- 착수 때 active_agents 1이었다. 재시작 직전 0 확인 규칙은 그대로다.

## 4차 (2026-11-23) — TASK-07 부분 완료(릴리스 설치됨, 재시작 대기)

- 대상: 보고 커밋 `ffba8c1`, [evidence/HEJO-TELEGRAM/TASK-07.md](../../../evidence/HEJO-TELEGRAM/TASK-07.md) "보완 2" 두 절, 인계 [handoff-task07.md](handoff-task07.md) 2판.
- 판정: **부분 완료**. 파일 설치는 끝났고 런타임 전환(재시작)은 하지 않았다. AT-HT-60 충족(적용 전 기록·롤백 명령 선기록), AT-HT-61·증거 수준 3 미도달.
- 확인한 것(증거 문서·보고 로그 대조):
  - 공용 RELEASE `227ef160…` → `0bcf63535df381e491c99af9cbef41179b7cd79f`. 설치 범위(gate·schemas·hub·install·config)는 검증 제품 `1ef3ad2`와 차이 0. 그 사이 커밋은 다른 작업(HEJO-DRAWER-INLINE, 검증·적용 완료)의 앱·문서뿐이라 설치 범위 밖이다. 41개 파일 대조 일치.
  - `hejo-install --check`: 첫 호출의 `ModuleNotFoundError`는 셸 검색 경로 문제(환경)이며, 같은 venv에 Hermes 모듈 경로를 준 재실행이 종료 0·출력 없음. 패키지·본체 무변경. 인계 2판 범위 안.
  - 재시작 직전 규칙(active_agents 0, 10분 한도)을 지켰다: 634초 동안 6회 모두 1 → 재시작 0회, 강제 종료·롤백 없음. 실행 중 게이트웨이는 옛 코드(아이메시지 문)다. **다음 재시작(누가 하든)부터 텔레그램 문이 적용된다.**
- 설계 적합성(4.2): 절차·금지 범위 준수. 설정·비밀 파일 직접 열람 없음.
- **지적 V4-1(시정 필요)**: 상태 조회를 위해 기존 앱의 로컬 연결 설정과 **Keychain의 출입증**으로 시험 클라이언트를 만들려 했다(시간 초과로 미조회, 값 출력 없음). 사장 기기의 인증 정보를 쓰는 것은 인계가 허가한 범위가 아니다(인계 9(6)은 "시험 클라이언트로 조회"라고만 적어 모호했다 — 인계 문구 보완 대상). 다음 지시에서 Keychain·앱 출입증 사용을 금지하고, AT-HT-61의 상태 확인은 게이트웨이 로그(텔레그램 연결·hejo 처리기 등록)로 하고 앱 화면 상태는 TASK-07b 뒤 M1에서 사장이 본다.
- 원인 분류: **환경·외부 시스템 차이**(재시작 시점 내내 처리 중 차례 1). 그 사이 사장 준비가 끝나지 않았던 것도 확인됐다(사장 대화: 2026-11-23 그룹·토픽·봇 관리자·토큰·허용 계정 설정, `.env`에 잘못 저장된 home channel 한 줄 삭제 대기).

### 재개 조건(사용자 결정 필요)

1. 사장이 `.env`의 `TELEGRAM_HOME_CHANNEL=n` 한 줄을 지웠다고 보고.
2. 처리 중 차례가 계속 1이면: 더 기다릴지, 그 차례를 끊고 재시작할지 사장 결정.

## 5차 (2026-11-23) — TASK-07 완료(서버 적용)

- 사장 요청으로 계획 담당이 재시작을 직접 수행했다(역할 변경 요청, 기록: [evidence/HEJO-TELEGRAM/TASK-07.md](../../../evidence/HEJO-TELEGRAM/TASK-07.md) 보완 4). 같은 사람이 실행·확인했으므로 이 단계의 검증은 **단일 모델 자체 확인**이다. 확인은 운영 상태 파일과 로그로만 했다.
- 결과: RELEASE `0bcf635` 일치 → 재시작 종료 0 → slack·photon·hejo(기본·보조 5)·telegram 모두 connected, 재시작 이후 오류·역추적 0, 텔레그램 의존성 Hermes 자동 설치, hejo 텔레그램 처리기 등록, hejo 로그 id·토큰 0. **AT-HT-60·61 충족, 증거 수준 3.**
- 지금 서버 상태: hejo의 아이메시지 연결은 빠졌고(아이메시지는 Hermes 직통), 텔레그램 문이 켜져 있다. 짝짓기는 텔레그램 설정 화면이 있는 새 앱이 필요하다(TASK-07b).
- 남은 일: TASK-07b 앱 공개, TASK-08 실물 M1~M8, 현재 명세 반영, 푸시(다른 작업 개인값 4건 정리 필요).

## 6차 (2026-11-23) — TASK-07 교차 확인 완료

- 대상: 구현 담당 보고 커밋 `8615f67`([evidence/HEJO-TELEGRAM/TASK-07.md](../../../evidence/HEJO-TELEGRAM/TASK-07.md) 마지막 절), 로그 `.build/HEJO-TELEGRAM/task07/resume3/`.
- 의미: 5차의 재시작은 계획 담당이 사장 지시로 직접 했다(단일 모델 자체 확인). 구현 담당(다른 모델)이 그 재시작을 다시 설치·재시작하지 않고 독립 확인했다 → **TASK-07 교차 모델 확인 완료**. 구현 담당 쪽 설치·재시작·롤백 0회.
- 직접 대조한 것: `release-comparison.json` RELEASE `0bcf635`·41파일 일치, `telegram-state-summary.json` telegram connected·오류 코드/메시지 없음·active 0, `post-restart.json` 390초 관측 hejo/Slack 기본·보조 5개씩·telegram·photon 연결·처리기 등록·ERROR/CRITICAL/Traceback 0, `selected-dependency.json` python-telegram-bot 22.8 import 성공(Hermes 자동 설치).
- 경고 검토(계획 담당이 재시작 이후 로그를 다시 묶어 봄, 124줄): 텔레그램 네트워크 경로 경고(IPv4 고정 경로·DNS 우회 경로 `ConnectError`, 재연결 예약)와 "전송 복구됨" 안내가 짝으로 있다. Hermes 텔레그램 어댑터의 자체 재연결 동작이며 현재 상태는 connected다. hejo 코드와 무관. 판정에 영향 없음 — 실물 확인(M3·M8)에서 글이 늦거나 빠지면 다시 본다.
- 판정: **TASK-07 완료(교차 모델, 증거 수준 3)**. AT-HT-60·61 충족.
- 이전 실행과 충돌로 보류된 "보완 4(재시작)" 계획은 이미 수행됐으므로 폐기한다. 다음 실행은 TASK-07b([handoff-task07b.md](handoff-task07b.md))다.
