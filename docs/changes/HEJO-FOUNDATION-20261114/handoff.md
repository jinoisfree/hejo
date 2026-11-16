# 설계 인계: HEJO-FOUNDATION / TASK-02 문 핵심과 통신 규격 v1

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다(이번 TASK: 문·통신 규격·출입증·문 설정 값·기록장 행).

```text
[설계 인계: HEJO-FOUNDATION TASK-02 / 문 핵심과 통신 규격 v1]
0. 기준: base_commit: 이 인계서를 담은 커밋(이 저장소 main HEAD, 계획 문서만 있음) / spec·design·tasks·수락 시험 2판(+2회차 보완) 2026-11-14 /
   승인 상태: 사용자 승인 2026-11-14(계획 검증 3회차 APPROVED) / 운영 모드: 연합개발(교차 모델 + 계획 검증)
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-FOUNDATION-20261114/{brainstorm,spec,design,tasks,plan-review}.md,
   tests/acceptance/HEJO-FOUNDATION.md. ADR 없음.
2. 요구와 수락 기준: REQ-HF-01~06(AC 전부), NFR-HF-01·02. 핵심: 리스너는 기본 프로필 어댑터만(보조는 포트 미점유 + 비활성
   retryable=False), 페어링 코드→출입증(해시·취소·잠금), 루프백·Tailscale만, 허용 사용자 config 브리지(.env 미접근), 직원 목록·
   roster 응답, 1:1 글(source.profile), 작성 중·스트리밍, 기록장(flock 단독 쓰기·write+fsync·실패 시 ftruncate·시작 시 꼬리 복구)과
   design 2.1 재전송 경계 규칙, design 2.2 확장 훅.
3. 유지할 기존 계약: Hermes 본체 무수정(plugin 계약만), Slack 게이트웨이·ddots 무영향, 운영 ~/.hermes 무변경(이 TASK는 운영 설치
   금지), 운영자 비공개 저장소(team-kit) 무변경.
4. 책임과 흐름: 앱 프레임 → gate/server(주소 검사·인증) → adapter(build_source + source.profile → handle_message) → Hermes 차례 →
   adapter.send/edit/typing → journal(seq 배정·fsync) → 연결별 상태(재전송 중이면 대기열) → 앱. 직원 목록은 gate/roster.
5. 기존 경로 판정: 신규 경로. 기존 경로 변경 없음(유지).
6. 위험도: 고위험(네트워크 리스너, 인증·출입증, 기록장 동시성·무결성). 필요 증거 수준 2(실제 Hermes 모듈 + 시험 대역 러너, 임시
   HERMES_HOME). 실제 게이트웨이(3)는 TASK-03a·09. 롤백: 이 저장소 커밋 되돌림(운영 영향 없음).
7. 변경 성격: 신규 기능(의미 추가). 비교 대상 없음.
8. 수락 시험: tests/acceptance/HEJO-FOUNDATION.md의 AT-HF-01~14, 32~37. 상태: 명세 완료·코드 미작성·미실행·미검토.
   기대값 출처: spec 요구, design 2·2.1·2.2·3절, Hermes 공개 함수 계약. 기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: schemas/hejo-wire-v1.json(design 2절 표 전부 + 2.1 + 이후 TASK가 쓰는 첨부·버튼 필드 정의),
   gate/{plugin.yaml,__init__.py,adapter.py,server.py,auth.py,journal.py,roster.py,hooks.py(또는 adapter 안 2.2 공개 메서드),cli.py,
   README.md}, gate/tests/, tests/acceptance/(AT-HF-01~14, 32~37 코드).
   금지 범위: 운영 ~/.hermes 쓰기·플러그인 연결·게이트웨이 재시작, Hermes 본체·운영자 비공개 저장소·ddots 수정, 앱 코드,
   TASK-03a/03b 범위(탐침, 첨부 HTTP, Hermes 기본 버튼, 보조 프로필 배달), .env·auth.json·토큰 파일 열기, 개인값(실제 직원 id·이름·
   주소·절대 경로)을 코드·시험·문서에 쓰기.
   선행 작업: 없음(TASK-01 완료). 병렬 갈래: 있음(TASK-02 뒤 문 확장·team-kit·앱·설치검사 4갈래, tasks.md 표). 이번 지시는 TASK-02 단독.
10. 가정·미확정: 보조 프로필 배달(design 4.1)은 TASK-03a 탐침 뒤 계획 담당 결정 — 이 TASK는 보조 어댑터 비활성만 구현.
    허용 사용자 브리지(apply_yaml_config_fn + _shared.apply_yaml_bridge)가 대역 러너에서 기대대로 동작하지 않으면 멈추고 보고.
    착수 차단 없음.
11. 사용자 확인: 브레인스토밍 결정 확정. 이 계획(2판)은 계획 재검증 뒤 사용자 승인 필요. 대화 기록장 추가는 브레인스토밍 이후
    설계로 사용자 승인 대상.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? 예(저장소에 제품 코드 없음, Hermes 본체 HEAD ebb026e 기준 조사).
- G1~G4: G1 요구·범위·AC 연결 있음. G2 근거 경로·대안·기존 경로 판정·실패/복구 경로 있음. G3 AC↔시험 연결, 계획 재검증 대기.
  G4 위험도·롤백·TASK 연결·기준 커밋 있음. 미확정(4.1)은 TASK-03a·계획 결정으로 격리.
```

## 구현 메모(설계 범위 안의 자유)

- 테스트는 Hermes venv 파이썬으로 실행한다(본체 모듈 import 필요). 매 시험에서 임시 `HERMES_HOME`을 만든다. 실행 명령과 종료 코드를 impl-report에 남긴다.
- 대역 러너는 Hermes 시험 도우미 패턴(`R/tests/gateway/_plugin_adapter_loader.py`, `restart_test_helpers.py`, `test_irc_adapter.py`)을 참고한다. 본체 시험 파일을 고치지 않는다.
- 페어링 CLI는 게이트웨이 프로세스 밖에서 실행되므로 코드 발급·취소는 `<HOME>/hejo/` 파일(0600, 원자적 교체, 파일 잠금)로 문과 공유한다. 문은 파일 변경을 감지해 2초 안에 취소를 반영한다(AT-HF-05).
- 기록장 실패 주입·반쪽 줄·두 번째 프로세스 시험은 실제 파일 시스템(임시 디렉터리)으로 한다.

## 보완 지시 1 (TASK-02 1차 검토 뒤, 2026-11-14)

- 판정 보고: [verdict.md](verdict.md)(부분 완료, 원인 설계 누락). 기준: 구현 커밋 `0c21b769e3419710f9b956faad4e572f1cebf626` + 이 설계 보완 커밋.
- 설계 보완(승인된 범위 안의 누락 보충, 요구 변경 아님): design 2절 `typing.ttl_seconds`·작성 중 스레드 처리·`message.files[]` 항목, 2.1절 0항(welcome 우선·since 검사). spec REQ-HF-05.AC-05, REQ-HF-06.AC-08, REQ-HF-07.AC-03. 수락 시험 AT-HF-44~46(명세 완료·코드 미작성).
- 할 일: V-1(스키마 `$defs.file` 구현, `$comment: BLOCKED` 제거), V-2(인증 직후 재전송 중 상태 → welcome → since 또는 head로 재전송, `hello.since > head`는 `invalid_since` 후 닫기), V-3(직원별 작성 중 스레드 집합, `stop_typing`은 집합 전부 off, on에 `ttl_seconds: 6`), V-4(디스패치 실패에 예외 종류·스택 기록, 프레임 본문 비기록 유지). AT-HF-44~46 코드화. 기존 시험 기대값 변경 금지.
- 범위·금지는 위 인계서와 같다(첨부 HTTP 업로드·다운로드 자체는 TASK-03b).

## 보완 지시 2 (TASK-02 2차 검토 뒤, 2026-11-14)

- 판정 보고: [verdict.md](verdict.md) 2차(부분 완료, 원인 설계 오류: 너무 큰 프레임 알림 요구가 전송 한계와 맞지 않음). 설계 보완: design 2절 "크기 한도" 문단.
- 할 일(V-6):
  - (1) 1 MiB 초과 프레임: 최선 노력 `error(too_large)` 뒤 닫기 코드 1009로 닫는다(현재 `BoundedWebSocket` 동작 확인·필요 시 정리).
  - (2) `gate/tests/test_boundaries.py::test_bad_frames_are_isolated`의 1 MiB 단계를 보완 설계대로 바꾼다. 기대는 "`error(too_large)` 또는 닫기 코드 1009"이고, 닫기면 코드 1009를 확인한다. 이어서 새 연결로 roster 응답을 받아 문이 계속 동작함을 확인한다. 64 KiB 글 초과 단계(오류 프레임 + 연결 유지)는 바꾸지 않는다.
  - (3) 전체 시험 묶음(`gate/tests` + `tests/acceptance/test_gate_foundation.py`)을 20회 연속 실행해 매회 종료 0을 로그로 남긴다.
- 수락 시험 명세의 기대값은 바꾸지 않는다(이 시험은 구현 범위 시험이다). 범위·금지는 위 인계서와 같다.

## 보완 지시 3 (TASK-02 3차 검토 뒤, 2026-11-14)

- 판정 보고: [verdict.md](verdict.md) 3차(부분 완료, V-7, 원인 설계 오류). 설계 보완: design 2절 "크기 한도" 문단(3판). 기준: `818a647` + 이 검토 커밋.
- 할 일(V-7):
  - (1) `test_bad_frames_are_isolated`의 1 MiB 단계에서 앱 쪽 기대를 바꾼다. TEXT면 `code == "too_large"`이고, CLOSE/CLOSED면 `ws.close_code in {1009, 1006}`이다.
  - (2) 서버 쪽 닫기 코드 1009를 결정적으로 확인한다. 방법은 자유(예: `BoundedWebSocket.close` 감시로 code=1009 호출 기록 확인, 또는 서버 측 `close_code`). 이어지는 `gate.is_connected` 확인과 새 연결 roster 응답 확인은 유지한다. `server.py`의 동작은 바꾸지 않아도 된다.
  - (3) `-k bad_frames` 집중 실행 200회 실패 0과 전체 시험 묶음 20회 연속 종료 0을 로그로 남긴다. 둘 다 `HEJO_TEAM_KIT_LIB`를 지정한 같은 환경에서 실행한다.
- 64 KiB 단계·다른 시험·수락 명세 기대값은 바꾸지 않는다. 범위·금지는 위 인계서와 같다.

## 인계: TASK-03a 보조 프로필 배달 탐침 (2026-11-14)

- 기준: TASK-02 완료(verdict 4차). 이 인계를 담은 커밋.
- 근거: design 4.1. 수락 시험 기대값 출처는 AT-HF-02·22. 다만 이번 TASK는 탐침이라 시험 합격을 주장하지 않는다.
- 할 일:
  - (1) `gate/probes/`에 A(전달자 어댑터)와 B(단독 발신자)를 각각 최소 구현한다.
  - (2) 임시 `HERMES_HOME`에서 **실제 게이트웨이 프로세스**를 띄운다. 프로필은 둘이다. 기본 프로필은 hejo를 켜고, 보조 프로필은 가짜 Slack 등 자기 연결을 가진 것처럼 구성하되 실제 Slack 토큰과 연결은 쓰지 않는다. 그 상태에서 다음을 각 안별로 기록한다.
    - (a) 게이트웨이 시작·포트 점유. 리스너는 하나여야 한다.
    - (b) 중복 자격 검사(`run_adapters.py` 해당 부분) 통과 여부.
    - (c) 보조 프로필에서 `send_message`나 예약 작업 `deliver=hejo`가 유효 대상으로 인정되는지.
    - (d) 그 글이 기록장에 보조 직원 이름으로 기록되고, 연결된 시험 클라이언트가 해당 직원 스레드로 받는지.
    - (e) Slack 등 다른 플랫폼에 영향이 없는지.
  - (3) 결과·명령·종료 코드·로그 경로를 impl-report 'TASK-03a' 절에 남긴다. 각 안마다 "성공 / 실패 / 막힌 지점(파일:줄)"을 적는다.
- 금지:
  - 탐침 코드를 운영 경로(`gate/` 본 모듈)에 채택하는 것.
  - AC·수락 시험·설계 문서를 바꾸는 것(결정은 계획 담당이 한다).
  - 운영 `~/.hermes`를 쓰거나, 운영 게이트웨이를 재시작하는 것.
  - 실제 Slack·외부 메시지를 보내는 것.
  - 비밀 파일을 여는 것.
  - Hermes 본체·ddots·운영자 비공개 저장소를 수정하는 것.
  - 개인값을 넣는 것.
- 위험·증거: 고위험, 수준 3(임시 홈 실제 게이트웨이). 롤백은 탐침 커밋 되돌림이다.
- 멈춤 조건: 실제 게이트웨이를 임시 홈에서 띄우는 데 운영 자원(운영 홈·실제 토큰)이 필요하면 멈추고 보고한다.

## 인계: TASK-03b 문 확장 + 보조 프로필 전달자 (2026-11-14, 5판)

- 기준: 이 인계를 담은 커밋. 공식 문서는 spec 5판, design 4.1(결정·보강 4항)·2·2.2·3절, tasks TASK-03b, 수락 시험 AT-HF-02·15~18·21·22·49·50. verdict 5차를 참조한다.
- 할 일:
  - (1) tasks TASK-03b 행 전체를 구현한다: 첨부 HTTP(직원 소유 검사), 직원 발송 파일 복사·등록, Hermes 기본 버튼 3종, 사진 경로, team-kit 없을 때 버튼 글자 대체.
  - (2) 보조 프로필 전달자를 본 모듈에 구현한다. design 4.1 보강 4항을 따른다.
    - 보낼 때 허브를 조회한다.
    - 허브가 없으면 fail closed다.
    - send·edit·typing·버튼·첨부를 전달한다.
    - 직원 이름은 `_owner_profile`로 정한다.
    - 허용 사용자는 config 브리지만 쓴다. 탐침이 쓴 .env 변수 이름은 쓰지 않는다.
    - 예약 대상 등록에 필요한 플랫폼 등록 값(예약 기본 대상·대상 해석)은 공개 계약 안에서 정하고 README에 적는다.
  - (3) `gate/probes/`는 제거한다.
  - (4) AT-HF-02(개정)·49·50과 15~18·21을 자동 시험으로 만든다. AT-HF-22는 TASK-03a 러너 방식(임시 홈 실제 게이트웨이, 수준 3)으로 만든다.
  - (5) 기존 시험 묶음 전체와 AT-22 실행을 로그로 남긴다.
- 유지: TASK-02 시험 기대값은 개정된 AT-HF-02 외에는 변경 금지다. 리스너는 기본 프로필 하나라는 불변 조건을 지킨다.
- 금지: handoff 첫 인계서와 같다. 다음을 하지 않는다.
  - 운영 `~/.hermes` 쓰기·재시작
  - 실제 외부 메시지
  - 비밀 파일 열기
  - Hermes 본체·ddots·비공개 저장소 수정
  - 개인값 기록
  - 설치 도우미(TASK-07)·앱 코드 작성
- 위험·증거: 고위험이다. 증거는 수준 2, AT-22는 수준 3이다. 롤백은 커밋 되돌림이다.
- 멈춤 조건: 다음 경우에는 멈추고 보고한다.
  - 전달자 보강이 Hermes 공개 계약만으로 안 되는 경우
  - 첨부 경로가 design 2절 `files[]` 모양과 맞지 않는 경우

### 보완 지시 4 (TASK-03b 보류 뒤, 6판)

- 판정은 verdict 6차를 보라. 위 'TASK-03b' 인계를 그대로 수행하되 다음 두 결정을 따른다.
  - **T03B-01:** design 2.2 "첨부 등록 시점" 1~4항을 따른다. 업로드는 대기 칸에 두고, 등록은 `message` 행 메타로만 한다. `unknown_file` 오류 코드는 스키마 `error.code` 목록에 추가한다(새 기록 행 종류는 추가하지 않는다).
  - **T03B-02:** roster의 `avatar`는 항상 null이고 `/v1/avatars/*`는 404다. 사진 원본은 만들지 않는다.
- 시험: AT-HF-51을 추가한다(기존 AT-02·15~18·21·22·49·50과 함께).

### 보완 지시 5 (TASK-03b 7차 검토 뒤)

- 판정은 verdict 7차를 보라. 기준은 `537fd8d` + 이 검토 커밋이다.
- (1) T03B-03: `gate/tests/test_boundaries.py::test_secondary_with_independent_home_never_listens`는 5판으로 대체된 "비활성" 계약을 담고 있다. 이 시험의 기대값 변경을 **허가한다**. 새 기대는 다음과 같다.
  - `connect()`가 True다.
  - 그 다른 홈에 `journal/.lock`·`hejo/devices.json`·`shared/hejo/files`가 생기지 않는다.
  - 새 LISTEN 소켓이 없다.
  - `gate.adapter._primary`가 기본 문 그대로다.
  - 시험 이름과 설명 문장도 새 계약에 맞게 고친다.
- (2) V-8: 전달자의 `edit_message`가 대상 `message_id`의 기록장 `employee`가 `_owner_profile`과 다르면 `SendResult(success=False, error="message_not_found")`로 끝나게 한다. 기본 문으로는 넘기지 않는다. 다른 직원 글 수정 시도 시험을 추가한다.
- (3) 전체 묶음(`gate/tests` + `tests/acceptance`, `HEJO_TEAM_KIT_LIB` 지정)을 종료 0으로 실행하고, `python -m gate.tests.gateway_delivery`(AT-HF-22)를 재실행해 로그를 남긴다.
- 위 시험 하나 외의 기존 시험 기대값은 변경 금지다. 범위·금지는 원 인계와 같다.

## 인계: TASK-07 설치 도우미·개인값 검사 (2026-11-14, 5판 범위)

- 기준: 이 인계를 담은 커밋. TASK-02·03b 완료(verdict 4·8차)로 설정 키가 확정됐다.
- 근거 문서: spec REQ-HF-13·14(AC 전부), design 7절(3-1 보조 프로필 전달자 포함), tasks TASK-07.
- 수락 시험: AT-HF-27·28(5판 개정)·29·38~43.
- 할 일:
  - (1) `install/hejo-install [--home PATH] [--check] [--uninstall] [--force]`
    - 기본 프로필: 링크, `plugins.enabled`, `gateway.platforms.hejo` 문 블록.
    - 보조 프로필마다: 링크, `plugins.enabled`, `{enabled: true, extra: {role: forwarder}}`.
    - 보조 프로필 목록은 Hermes 프로필 API로 읽는다.
    - `<HOME>/hejo/`(0700)와 `devices.json`(0600)을 만든다.
    - 영수증: 변경 전에 쓰고, 단계별로 `applied`를 기록한다. 대상은 보조 프로필 항목까지 포함한다.
    - 재설치는 `before`를 바꾸지 않는다. 사장이 바꾼 값은 건드리지 않고 알린다.
    - 중간 실패는 역순으로 되돌리고 종료 1. 제거 때 값이 달라져 있으면 그 대상은 두고 종료 2.
    - `config.yaml`은 ruamel 왕복으로 쓰고, 임시 파일 + `os.replace`로 바꾼다.
    - 게이트웨이 재시작은 하지 않고 안내만 출력한다.
  - (2) `scripts/scan_private.py`, `scripts/scan_private_allow.txt`, `githooks/pre-commit`(design 7절 규칙 그대로)
    - 운영 홈에서는 `owner/team.yaml`·`owner/vault.yaml`만 연다.
    - 출력은 지문만 남긴다.
    - 예외는 줄 지문 단위로 건다. 허용 대상은 가짜 시험 값과 LICENSE 고지 줄뿐이다.
  - (3) `scripts/test.sh`: gate pytest 전체와 AT-22 러너를 실행한다. 앱 시험 자리는 TASK-05에서 붙이므로 지금은 "앱 시험 없음"을 명시한다.
  - (4) `README.md`(설치·제거·검사 사용법, 개인값 없이)
- 패턴 규칙을 운영 저장소 team-kit `airport_boundaries`에서 가져온다면 다음 순서를 지킨다.
  - 원본 파일 전체를 먼저 읽고 `copy-review.md`에 기록한다(사용자 지시: 다른 코드는 끝까지 읽고 기록한 뒤에만 베낀다).
  - hejo에는 복사본을 둔다. 운영 저장소를 import하거나 고치지 않는다.
- 검사기를 저장소 전체에 처음 돌려 위반이 나오면 다음 순서로 처리한다.
  - 값을 출력하지 않고 지문만 보고한다.
  - 실제 개인값이면 해당 파일에서 중립 값으로 고친다. 다만 승인 문서·수락 명세의 의미는 바꾸지 않는다.
  - LICENSE 고지 줄만 예외로 등록한다.
  - 판단이 애매하면 멈추고 보고한다.
- 시험: AT-HF-27·28·29·38~43을 자동화한다. AT-40·41은 파일 열기 감사 훅을 쓴다. 기존 59개 시험과 AT-22를 함께 통과해야 한다.
- 금지:
  - 운영 `~/.hermes`에 설치를 실행하는 것(시험은 임시 홈만 쓴다).
  - 운영 홈의 다른 파일이나 비밀 파일을 여는 것.
  - Hermes 본체·ddots·운영 저장소를 수정하는 것.
  - 개인값을 남기는 것.
  - 앱 코드를 쓰는 것.
- 위험·증거: 고위험, 수준 2. 롤백은 커밋 되돌림이다.

### 보완 지시 6 (TASK-07 9차 검토 뒤, 7판)

- 판정은 verdict 9차를 보라. 기준은 이 검토 커밋이다. 스테이징해 둔 8파일 작업은 이어서 쓴다.
- (1) T07-02: 금고 단어와 겹친 것은 운영자 비공개 저장소 이름이었다. 추적 문서는 이미 `<운영 저장소>`로 바꿨다. 남은 `copy-review.md` 1건도 같은 표기(`<운영 저장소>/…`)로 바꾼다.
  - 실제 경로가 필요하면 추적하지 않는 `AGENTS.local.md`를 본다.
  - 바꾼 뒤 `python3 scripts/scan_private.py`와 `githooks/pre-commit`가 **위반 0, 종료 0**이어야 한다.
  - 새 예외는 추가하지 않는다.
- (2) T07-01: design 7절 "기록 부트스트랩"과 AT-HF-39(7판)를 따른다.
  - `<HOME>/hejo/`는 영수증보다 먼저 만든다. 이 단계는 되돌림 대상이 아니다.
  - 실패 뒤에는 이 디렉터리와 `failed` 영수증만 남는다.
- (3) 원 인계의 설치 도우미 전체를 구현하고 AT-27·28·38·39·40을 자동화한다.
- (4) `bash scripts/test.sh`(기존 시험 + 새 시험 + AT-22)가 종료 0이어야 한다. 커밋하고 로그를 남긴다.
- 범위·금지는 원 인계와 같다. 운영 홈에 설치하지 않는다. 검사기는 두 파일만 읽는다.

## 인계: TASK-05 앱 골격 + 펫 창 (2026-11-14, 4~7판 기준)

- 기준: 이 인계를 담은 커밋. 게이트(TASK-02·03b)·설치(TASK-07)는 완료됐다.
- 계획 검증: 4판(펫 구조 REQ-HF-16, 베끼기 원칙)이 이 인계의 계획 재검증 대상이다. 검증에서 보완이 나오면 그 결과를 따른다.
- 근거 문서:
  - spec REQ-HF-11·16, design 2·2.1절(재전송·크기 한도 3판: 보내기 전 1 MiB 검사, 1006은 일반 끊김 후 재접속), design 6절(베끼기 원칙·펫 창 구조·SwiftUI 예외 없음)
  - tasks TASK-05
  - 수락 시험 AT-HF-23·24·25·47·48
  - UI 시안 `mockup/hejo-ui.html`(메뉴 막대·연결 창·끊김 안내)
- 할 일:
  - (0) **베끼기 전 전수 검토:** design 6절 후보 파일 전체와 그 의존을 끝까지 읽는다. 후보 파일은 펫 관련 `PetLayout`·`GenieView`·`PetAnimation`·`PetPointerInteraction`·`PetSprite*`·`PetCarrySmoke`·`ScreenWindowResolver`·`PetView`의 `PetPanel`/`PetView`, `App.swift`의 배치·열고닫기 로직, 그 밖에 `AppIdentity`·`LoginLaunch`·`MenuBarIcon`·`SmokeCheck`·키체인 방식 등이다. 읽은 내용은 `copy-review.md`에 파일별로 기록한다. 기록이 없는 파일은 베끼지 않는다. 원본 위치는 추적 파일에 `<운영 저장소>/ddots/…`로만 쓴다.
  - (1) `app/` 골격을 만든다.
    - `scripts/build.sh`: swiftc 단일 빌드. 번들 ID는 `io.github.hermes-hejo.hejo`, 서명은 기본 로컬 인증서 이름(환경 변수로 바꿀 수 있음)이다.
    - 정체성, AppDelegate·진입점, 메뉴 막대(보조 입구), 단일 실행, 로그인 시 실행.
    - `hejo-local.json` 설정 저장, 키체인 헬퍼(서비스 `io.github.hermes-hejo.hejo.gate-token`), 연결 창(주소·12자 페어링 코드·기기 이름, 실패 안내 3종).
  - (2) WebSocket 클라이언트(`URLSessionWebSocketTask`)를 만든다.
    - hello → welcome → 2.1 재전송 규칙(applied seq 저장, 빈칸이면 sync).
    - 지수 백오프 재접속(1, 2, 4… 최대 30초).
    - 보내기 전 1 MiB 검사.
    - 닫기 코드 1009와 `too_large`는 "너무 큼"으로 처리하고, 1006은 일반 끊김으로 처리한다.
  - (3) 펫 창: REQ-HF-16, design 6절 펫 창 구조를 따른다.
    - 한 `PetPanel`을 펫과 대화가 함께 쓴다. 0.30초 변형(genie)으로 펼치고 접는다.
    - 열기는 클릭·메뉴, 닫기는 다시 클릭·Esc·"펫으로 접기"다.
    - 4 px 넘게 끌면 이동이다. 여러 화면을 지원하고, 동작 줄이기 설정을 따르며, 다른 앱의 포커스를 뺏지 않는다.
    - 대화 영역은 TASK-06이 채울 빈 AppKit `NSView` 자리로 둔다(연결 상태 표시만).
    - 펫 그림은 LICENSE와 함께 가져오고, 펫 기본 이름은 중립값으로 둔다.
  - (4) 앱 시험(`app/Tests/`)을 `scripts/test.sh`에 연결한다("앱 시험 없음" 줄을 대체한다). AT-23·24·25·47(자동 부분)·48을 자동화하고, AT-47의 수동 체크리스트는 `evidence/HEJO-FOUNDATION/`에 스크린샷·녹화 자리를 마련해 보고한다.
- 유지할 것:
  - UI는 AppKit만 쓴다(SwiftUI 예외 없음).
  - ddots 파일은 수정하지 않고, 동기화 장치도 만들지 않는다.
  - 개인값 검사는 위반 0, 기존 80개 시험과 AT-22는 통과를 유지한다.
- 금지:
  - 운영 `~/.hermes` 쓰기와 게이트웨이 재시작.
  - 실제 운영 문에 페어링. 시험은 임시 문 대역만 쓴다.
  - 비밀 파일 열기.
  - Hermes 본체·ddots·운영 저장소 수정.
  - TASK-06 대화 화면 구현.
- 위험·증거: 고위험(인증 저장), 증거 수준 2. 롤백은 커밋 되돌림이다.
- 멈춤 조건: 다음 경우에는 멈추고 보고한다.
  - 베낄 코드가 SwiftUI·Slack과 떼어낼 수 없게 얽혀 있어 설계 범위를 넘는 경우.
  - 서명 인증서가 없어 빌드할 수 없는 경우.

## 인계: TASK-06 앱 대화 화면 (2026-11-14)

- 기준: 이 인계를 담은 커밋. 선행 TASK-05(앱 골격·펫 창)·TASK-03b(첨부 HTTP·버튼)는 완료됐다.
- 근거 문서:
  - spec REQ-HF-12(AC-01), design 2·2.1·2.2절(프레임·`files[]`·`buttons[]`·typing ttl·HTTP), design 6절(베끼기 원칙·베낄 후보와 다듬을 파일).
  - tasks TASK-06, 수락 시험 AT-HF-26.
  - UI 시안 `mockup/hejo-ui.html`의 ③ 대화 창(세 칸: 직원 → 스레드 → 대화, 입력 줄, 끊김 띠).
- 할 일:
  - (0) **베끼기 전 전수 검토**: design 6절 후보(`DdotsThreadWindow`, `MessageFormat`, `SlackLayout`→`TextLayout`, `ChatStyle`, `ClipboardAttachments`, `NativeThreadCard`, `NativeThreadList`, `DraftEditor`·`DraftFormat`, `AttachmentDrop`, `ProfileAvatar`, `Conversation.swift` 일부)와 그 의존을 끝까지 읽는다.
    - `copy-review.md`에 파일별로 기록한다. 기록 없는 파일은 베끼지 않는다.
    - SwiftUI·`NSViewRepresentable`·Slack 의존은 빼고, 원본은 `<운영 저장소>/ddots/…` 표기로만 쓴다.
  - (1) 중립 대화 모델을 만든다(직원·스레드·글·첨부·버튼·작성 중). 원본은 문의 기록장 프레임이고, 앱 캐시는 `~/Library/Application Support/hejo/cache/`다(지우면 `applied = 0`으로 다시 동기화).
  - (2) TASK-05의 펫 대화 자리(`PetView.conversation`)에 다음을 채운다.
    - 직원 사이드바(`NSTableView`, 안 읽은 수, 이름 첫 글자 아이콘. 사진은 1단계 근간에서 항상 없음).
    - 스레드 목록(검색·새 스레드).
    - 스레드 보기(서식 글, 스트리밍 `edit`, 작성 중 점 `ttl_seconds`, 버튼 줄 `click`, 첨부 타일 → `GET /v1/files/<직원>/<id>`).
    - 입력 줄(⏎ 보내기·⇧⏎ 줄바꿈, 첨부는 `POST /v1/files` 뒤 `send.files`, `unknown_file`·`too_large` 오류 표시, 1 MiB 사전 검사).
    - 끊김 띠.
  - (3) 시험:
    - 앱 시험에 모델·재전송 적용·안 읽은 수 증감·버튼 클릭 프레임·첨부 업로드/열기 흐름을 넣는다(문 대역 또는 실제 gate를 임시 홈에서 사용).
    - AT-HF-26은 수동 체크리스트와 증거 자리(`evidence/HEJO-FOUNDATION/TASK-06.md`, 스크린샷)를 만들고, 자동 캡처는 수동 증거와 구분해 표시한다.
- 유지할 것:
  - AppKit만 쓴다(SwiftUI 예외 없음).
  - `bash scripts/test.sh` 전체 종료 0을 유지한다.
  - 개인값 검사 위반 0을 유지한다.
  - TASK-05 동작(포커스 비탈취, Esc 접기, genie)을 깨지 않는다.
- 금지:
  - 운영 `~/.hermes` 쓰기·재시작, 실제 운영 문 페어링.
  - 비밀 파일 열기.
  - Hermes 본체·ddots·운영 저장소 수정.
  - 실제 직원 이름 등 개인값. 시험·캡처에는 가짜 명부만 쓴다.
  - 계정·직원 카드·공방 등 후속 기능.
- 위험·증거: 일반, 증거 수준 2. 롤백은 커밋 되돌림.
- 멈춤 조건: 베낄 코드가 SwiftUI·Slack과 떼어낼 수 없게 얽혀 설계 범위를 넘으면 멈추고 보고한다. 통신 규격에 없는 프레임이 필요해도 멈추고 보고한다.

### 보완 지시 7 (TASK-06 진행 중, 8판 — 사용자 지시로 화면 기준 변경)

- 사용자 지시: "현재 ddots의 화면을 그대로 가져와 새로 만들지 말고". 시안 1판 ③을 기준으로 지정한 원 인계는 계획 오류였다. 진행 중인 세 칸 배치(약 1000px 창)는 폐기한다.
- 화면 기준: design 6절 "대화 화면 = ddots 현재 화면 그대로"(8판)와 spec REQ-HF-12(8판), AT-HF-26(8판). 시안 파일은 기준이 아니다.
- 할 일:
  - (1) 그 항목의 원본 목록(ChatPanel `ChatView`, SlackPanel `ChatView` 확장의 sidebar·thread·composer·notice 부분, `SlackSidebar`·`SlackLayout` 상수, ChatPresentation, ChatWorkspace, NativeThreadList/Card와 그 안의 호스트 조각, ChatStyle, DraftEditor·SlackComposerInput, PetView 안 읽은 배지)을 끝까지 읽는다. `copy-review.md`에 SwiftUI 뷰 → AppKit 클래스 대응과 상수 출처를 기록한다.
  - (2) TASK-05의 펫 패널 대화 자리에 ddots와 **같은 크기·간격·색·글꼴·동작**으로 AppKit 재현한다.
    - 탭 줄 68px, 끌면 목록 180~300, 숨김.
    - 카드는 한 번에 하나만 펼치고, 접힌 답글 더미·레일·작성 중·배지를 둔다.
    - 입력 줄은 새 스레드/답장으로 전환된다.
    - 알림 띠, 머리글·"펫으로 접기", 닫힌 상태 안 읽은 배지를 둔다.
    - 탭의 '방'은 '직원'으로 바꾼다.
  - (3) design 6절의 뺄 것 목록만 뺀다. 빠진 자리는 ddots에서 그 요소가 없을 때의 모양을 따른다.
  - (4) 이미 만든 중립 대화 모델·GateClient·GateHTTP(첨부)·버튼 클릭·재전송 적용과 그 시험은 그대로 재사용한다.
  - (5) AT-HF-26: 같은 창 크기에서 hejo(가짜 명부·문 대역)와 ddots를 나란히 촬영할 자리와 체크리스트를 만든다. ddots 쪽 촬영은 사장 참여가 필요하면 TASK-09로 넘기고 그렇다고 표시한다. ddots 실행·설정 변경은 하지 않는다.
- 유지·금지는 원 인계와 같다. ddots 파일 수정 금지, SwiftUI 예외 없음, `scripts/test.sh` 종료 0, 개인값 위반 0.
- (8판 보완, 사용자 승인) 방 단위 모델: 탭·목록·안 읽은 수·카드 목록을 `Room{id, kind, title, members}`로 다룬다. 1단계에서는 `kind = direct`(직원 1:1)만 쓴다. 통신 규격은 바꾸지 않고, 앱에서 `employee`를 1:1 방에 대응시킨다. design 6절의 대화 화면 항목을 참고한다.

## 인계: TASK-04 team-kit hejo 답장 버튼 (2026-11-14)

- 사용자 결정(2026-11-14): 기초 공사는 지금의 ddots 화면 그대로 마무리한다. 화면 시안 개선은 별도로 계속하며, 이 TASK와 무관하다.
- 근거: spec REQ-HF-09(AC-01·02), design 5절·2.2절(문 공개 훅), tasks TASK-04, 수락 시험 AT-HF-19·20. 문 쪽 훅은 TASK-02·03b에서 완료됐다(`gate/adapter.py`: `metadata["hejo_buttons"]`, `metadata["hejo_reply_state"]`, `set_reply_state`, `register_click_handler`).
- 작업 위치: 운영 저장소의 규칙(`<운영 저장소>/AGENTS.md`, 실제 경로는 미추적 `AGENTS.local.md`)을 따른다. team-kit 원본은 실행 중인 `~/.hermes/plugin-store/team-kit`이다. 거기서 고치고, 운영 저장소에서 `./sync`로 모은다.
- 할 일:
  - (0) 착수 전 확인. 아래 셋 중 하나라도 해당하면 멈추고 보고한다.
    - team-kit 원본과 운영 저장소에 다른 작업의 미커밋 변경이 있다.
    - 처리 중인 작업이 있다.
    - `./sync`가 토큰 경고를 낸다.
  - (1) `controls()`를 `hermes_reply/plugin.py`에서 `reply_buttons`로 옮긴다. 동작을 그대로 두는 리팩터링이다. Slack이 이 함수를 계속 같이 쓰므로, 옮기기 전과 후에 기존 Slack 답장 버튼 시험이 같은 결과여야 한다.
  - (2) `plugin.py`의 플랫폼 등록부에 `register_platform_handler('hejo', hejo_factory)`를 더한다. 설치기가 할 일은 다음과 같다.
    - 어댑터의 `send`/`edit_message`(2.2절 서명 유지)를 감싼다.
    - `controls(content)`로 표식을 떼어 `metadata["hejo_buttons"]`(`label`·`style`, id는 문이 발급)와 `metadata["hejo_reply_state"]="asked"`로 넘긴다.
    - `register_click_handler("reply", …)`는 `False`를 돌려 문의 기본 처리를 쓰게 한다.
    - 클릭 뒤에는 `await set_reply_state(msg_id, "answered")`를 부르고, 최종 답장 때는 `"closed"`를 부른다.
    - 문 내부를 import하지 않는다.
  - (3) 시험을 만든다.
    - AT-HF-19·20을 team-kit 시험으로 만든다. hejo 저장소의 문 어댑터를 대역 러너로 쓰고, 임시 HERMES_HOME에서 돌린다.
    - 기존 team-kit 시험 전체를 돌린다.
    - hejo 저장소 `bash scripts/test.sh`를 돌린다. 문 쪽 AT-HF-21(team-kit이 없을 때 글자로 대체)이 그대로 통과해야 한다.
  - (4) 운영 저장소에서 다음 순서로 마무리한다.
    - `./airport-check`를 통과시킨다(`--rebaseline` 금지).
    - `./sync --split -m "…"`로 커밋하고, 푸시하지 않는다.
    - 커밋 해시와 변경 파일을 보고한다.
- 금지:
  - 게이트웨이 재시작과 `reload-plugins`. 새 코드는 다음 재시작 때 실려도 Slack 동작이 같아야 한다. 그래서 (1)의 비교 시험이 필수다.
  - hejo를 운영 설정에 연결하는 것. 이는 TASK-09에서 한다.
  - 실제 Slack이나 외부로 메시지를 보내는 것.
  - 비밀 파일을 여는 것.
  - Hermes 본체와 ddots 앱을 수정하는 것.
  - `usage_ledger`·`hermes_router` 변경. 이는 2단계에서 한다.
  - 버튼 허용 목록(`reply-buttons.json` labels)에 새 문구를 넣는 것.
  - git push.
  - hejo 저장소에 운영 저장소 이름이나 개인값을 쓰는 것.
- 위험·증거: 운영 플러그인 코드를 바꾸므로 고위험으로 다룬다. 증거 수준은 2다.
- 롤백: team-kit 원본 파일을 커밋 전 내용으로 되돌리고 `./sync`를 다시 실행한다. 이미 커밋했다면 운영 저장소에서 그 커밋을 되돌린다. 게이트웨이는 재시작하지 않았으므로 실행 중인 Slack은 영향받지 않는다.
- 멈춤 조건:
  - Slack 비교 시험에서 차이가 나면 멈춘다.
  - 버튼 정책(`button_policy`)과 hejo 버튼 모양이 맞지 않으면 멈춘다.
  - 운영 저장소 규칙과 이 인계가 충돌하면 멈춘다.

## 인계 보완: TASK-04 재개 (2026-11-14, 검증 13차 뒤)

1. **사용자 확인:** 운영 저장소의 다른 작업(DDOTS-DROP-MODEL, 167번 세션)은 끝났다. 사용자가 진행을 허가했다.
2. **남은 문서 2개는 손대지 않는다.** 그 작업이 남긴 미커밋 문서는 아래 두 개이며, 스테이징·커밋·정리·되돌리기를 하지 않는다.
   - `docs/changes/DDOTS-DROP-MODEL-20261113/impl-report.md`
   - `docs/changes/DDOTS-DROP-MODEL-20261113/verdict.md`
3. **(0)항 착수 조건을 바꾼다.**
   - 위 두 파일만 남아 있으면 진행한다.
   - 그 밖의 미커밋 변경이 있으면 멈춘다. 처리 중인 작업이나 원본 team-kit의 다른 변경이 있어도 멈춘다.
   - 이 확인은 착수 전과 커밋 전에 두 번 한다.
4. **(4)항 커밋 방법을 바꾼다. `./sync --split`은 쓰지 않는다.**
   - 이유: `--split`은 작업 트리의 모든 변경을 "공통" 묶음으로 커밋한다. 그러면 위 두 문서가 이번 커밋에 함께 들어간다.
   - 순서:
     1. `./airport-check` 통과(`--rebaseline` 금지)
     2. `./sync`(모으기만; `--commit`·`--split` 금지)
     3. 토큰 경고가 있으면 커밋하지 않고 멈춘다.
     4. `git status`로 바뀐 파일을 확인한다.
     5. **이번 작업 파일만** `git commit --only -m '…' -- <경로들>`로 커밋한다. 운영 저장소 AGENTS.md 50행의 "자기 작업 파일만 커밋" 규칙을 따른다.
   - 대상 경로는 `./sync`가 모은 team-kit 사본(`hermes/` 아래)과, 필요하면 운영 저장소의 관련 문서다.
   - `./sync` 뒤 이번 작업과 무관한 운영 사본의 변화가 보이면 커밋하지 않고 경로 목록만 보고한다.
5. **커밋 뒤 확인:** 위 두 문서가 여전히 ` M` 상태인지 `git status`로 확인하고 결과를 기록한다.
6. **나머지는 원래 인계(TASK-04) 그대로다.**
   - (1)~(3)항, 금지 사항, 롤백 절차는 바뀌지 않는다.
   - 푸시는 하지 않는다. 운영 저장소 AGENTS.md에 상시 푸시 승인이 있어도 이 작업은 플러그인 승인을 따른다.

## 보완 지시 8: TASK-04 마무리 (검증 14차)

기준은 hejo `a41ba00` 이후 HEAD다. 실행 원본 team-kit에 있는 이번 작업의 미커밋 3개 파일 위에서 이어간다.

1. **F3 — 버튼 처리는 경로마다 정확히 한 번**
   - 보조 프로필(전달자) 어댑터와 대표 어댑터가 모두 감싸져 있어도 아래가 각각 한 번만 일어나야 한다.
     - 표식 제거
     - `hejo_buttons`·`asked` 설정
     - `close_answered`
   - 방법은 둘 중 하나를 고른다.
     - (가) 감싸기가 이미 준비한 metadata 표식(예: `_hejo_reply_prepared`)이 있으면 안쪽 감싸기는 그대로 통과시킨다.
     - (나) 전달자 어댑터에는 설치하지 않고 대표 어댑터만 처리한다. 이때 판별은 공개 속성만 쓴다.
   - 시험 추가(`tests/test_reply_hejo.py`): 보조 프로필 직원이 아래를 해도 대표 프로필 직원과 결과(버튼·상태 순서)가 같아야 한다.
     - 버튼 질문 → 클릭 → 버튼 달린 새 질문(이때 answered가 유지되어야 함) → 최종 답(closed)
     - 버튼 질문을 edit로 보내는 경우
2. **F4:** closed 처리하거나 기록이 실패하면 `working`·`message_threads`에서 지운다. `message_threads`에는 최근 N개(예: 2048)만 남기는 상한을 둔다.
3. **F1:** team-kit `tests/test_org_review.py`의 `seed()`와 같은 날짜 키를 쓰는 곳을 고친다.
   - 오늘(KST) 기준 상대 날짜로 바꾸거나, `prune`의 `now`를 고정한다.
   - `lib/hermes_team_services/org_review.py`의 정책은 바꾸지 않는다.
   - 이 시험 파일은 이번 커밋 대상(자기 파일)에 포함한다.
4. **F2:** hejo `app/Tests/TestMain.swift`의 AT47 고정 `pause(0.4)` 검사를 바꾼다.
   - `transitionProgress == 0`이 될 때까지 짧게 반복 확인하고, 최대 2초까지 기다린다.
   - 같은 패턴의 다른 고정 대기 검사도 함께 고친다.
   - 펫 제품 코드는 바꾸지 않는다.
   - `app/scripts/test.sh`를 20회 연속 실행해 모두 종료 0이어야 한다. 로그를 남긴다.
5. **검증**
   - Slack 9개 파일 214 passed가 그대로 유지되는지 확인한다.
   - `tests/test_reply_hejo.py` 전체 통과.
   - **team-kit `pytest tests` 종료 0.**
   - hejo `bash scripts/test.sh` 종료 0. `HEJO_PYTHON`·`HEJO_TEAM_KIT_LIB`·`PYTHONPATH`를 설정해서 실행한다.
   - 개인값 검사 종료 0.
6. **커밋** — 보완 인계(재개)의 (4)항 그대로다.
   - 순서: airport-check → `./sync`(모으기만) → 토큰 경고 확인 → `git status` 확인 → 자기 파일만 `git commit --only`.
   - 커밋 대상: team-kit 사본의 plugin.py·reply_buttons.py·test_reply_hejo.py·test_org_review.py.
   - DDOTS-DROP-MODEL 문서 2개는 계속 손대지 않는다.
   - hejo 쪽(F2 시험 수정·보고서)은 hejo 저장소에 따로 커밋한다.
7. **금지 사항·롤백은 기존 인계와 같다.** 재시작·reload·운영 연결·외부 발송·비밀 파일·푸시는 하지 않는다.

## 보완 지시 9: TASK-04 커밋 마무리 (검증 15차)

1. **커밋 조건을 고친다.**
   - `./sync` 뒤 `hermes/profiles/*/memories/` 아래 기억 파일 변화는 실행 중인 직원 기억이다. 이번 작업과 무관하며, 매일 자동 기록이 처리한다. 이 경우 보류하지 않고 진행한다.
   - 그 밖에 예상하지 못한 경로가 있으면 여전히 멈춘다.
2. **운영 저장소:** 아래 4개 파일만 `git commit --only -m '…' -- <4개 경로>`로 커밋한다.
   - `hermes/plugin-store/team-kit/lib/hermes_reply/plugin.py`
   - `hermes/plugin-store/team-kit/lib/hermes_reply/reply_buttons.py`
   - `hermes/plugin-store/team-kit/tests/test_org_review.py`
   - `hermes/plugin-store/team-kit/tests/test_reply_hejo.py` (새 파일이라 그 경로만 먼저 `git add`)
   - 커밋하기 전에 원본·사본 해시가 `.build/task04-r8-source.json`과 같은지 다시 확인한다.
   - 다른 경로는 건드리지 않는다: DDOTS 문서 2개, 기억 파일, 그 밖의 모든 경로.
   - 커밋 메시지는 한국어로, 무엇을 왜 바꿨는지 적는다.
3. **커밋 뒤 확인:**
   - `git show --stat HEAD`에 위 4개 경로만 들어 있는지 확인한다.
   - `git status`에서 DDOTS 문서 2개와 기억 파일이 그대로 ` M`인지 확인한다.
4. **hejo 저장소:** `app/Tests/TestMain.swift`와 impl-report를 커밋한다. impl-report에는 운영 커밋 해시와 커밋 파일 목록을 추가한다. 시안 파일은 건드리지 않는다.
5. **푸시는 하지 않는다.** 두 저장소의 푸시 대상(저장소·원격·브랜치·전체 커밋)을 보고한다.
   - 운영 저장소 AGENTS.md에 상시 푸시 승인이 있더라도, 이 작업은 플러그인 승인을 따른다.
6. **금지:** 재시작·reload, 운영 hejo 연결, 외부 발송, 비밀 파일 열기, 기억 파일 열기·수정·되돌리기.

## 인계: TASK-08 캐시 auto → TASK-10 로고 → TASK-11 아일랜드 1단계 (9판, 2026-11-15)

사용자 승인: "캐시 진행 로고도 진행 다이나믹아일랜드도 진행하자". 아래 순서대로 진행하고, 작업마다 따로 커밋한다.

### TASK-08 (운영, 증거 수준 3) — REQ-HF-15, AT-HF-30

0. **착수 전 확인**
   - 운영 저장소(AGENTS.local.md의 `<운영 저장소>`)의 미커밋 변경이 허용 목록뿐인지 본다. 허용 목록은 DDOTS-DROP-MODEL 문서 2개와 `hermes/profiles/*/memories/`다.
   - 처리 중인 차례·작업이 0인지 본다.
   - 둘 중 하나라도 아니면 멈추고 보고한다.
1. **변경 전 기록:** 루트 `~/.hermes/config.yaml`과 `~/.hermes/profiles/*/config.yaml` 각각의 `prompt_caching.cache_ttl` 값(없음 포함)을 `.build/task08-before.json`에 적는다. 다른 키 내용은 출력하지 않는다.
2. **변경**
   - ruamel 왕복(주석·순서 보존)으로 각 파일의 `prompt_caching.cache_ttl`을 `auto`로 바꾼다. `prompt_caching`이 없으면 맵을 만든다.
   - 원자적으로 쓰고 파일 권한을 유지한다.
   - 파일마다 `cache_ttl`을 뺀 나머지 데이터가 바꾸기 전과 같은지 비교한다.
   - 텍스트 차이가 그 줄(또는 새 두 줄)뿐인지 확인한다.
3. **적용 시점 조사(재시작 금지):** Hermes 본체 코드를 읽기만 해서 `cache_ttl`을 언제 읽는지 확인한다(차례마다인지, 시작 때 한 번인지). 그 결과로 "즉시 적용" 또는 "다음 재시작(TASK-09) 때 적용"을 보고한다.
4. **운영 저장소 커밋**
   - 순서: `./airport-check`(`--rebaseline` 금지) → `./sync`(모으기만) → 토큰 경고가 나오면 멈춤 → `git status` 확인.
   - 바뀐 설정 사본 `hermes/config.yaml`과 `hermes/profiles/*/config.yaml`만 `git commit --only -m '<한국어>' -- <경로>`로 커밋한다.
   - 기억 파일과 DDOTS 문서는 손대지 않는다.
   - 예상하지 못한 경로가 있으면 멈춘다.
5. **롤백:** `.build/task08-before.json` 값으로 복원한다. 원래 없던 키는 지우고, 원래 없던 맵은 지운다.
6. **금지:** 게이트웨이 재시작·reload, 비밀 파일(`.env`·`auth.json`·토큰), 다른 설정 키 변경, Hermes 본체 수정, 푸시.

### TASK-10 (hejo, 증거 수준 2) — REQ-HF-17, AT-HF-52

1. `app/Sources/ConversationView.swift`의 `brand`를 속성 문자열 `HEJO.`로 바꾼다.
   - H는 `systemBlue`, 나머지는 기본 글자색이다.
   - 글꼴은 14 semibold이고 가운데 정렬을 유지한다.
2. 방이 없을 때의 머리글 대체 글자 `"hejo."`도 `HEJO.`로 바꾼다.
3. 버전 줄(10pt)은 그대로 둔다.
4. AT-52를 앱 시험에 추가하고 커밋한다.

### TASK-11 (hejo, 증거 수준 2) — REQ-HF-18, AT-HF-53~56

design 6절 "로고와 아일랜드"를 따른다.

1. **새 파일**
   - `IslandModel.swift`: 순수 상태 계산기. 입력은 모델·연결·실패·업로드·시계이고, 출력은 칸 목록·글자·늘어남 상태다. 시계는 주입할 수 있게 한다.
   - `IslandView.swift`: AppKit `NSView`. 높이 30, 칸·구분선, 도는 고리(동작 줄이기면 정지), 마우스 올림 추적, 누르기 이벤트를 맡는다.
2. **배치(`ConversationView.layout`)**
   - 알약 x = `left + 12`, 세로 가운데에 둔다.
   - 방 제목·부제는 알약 오른쪽 + 12에서 시작한다.
   - 최대 너비는 design의 식을 따르고, 넘치면 직원 칸부터 얼굴만 남긴다.
   - `headerDrag`가 알약 사각형 안의 이벤트를 받지 않게 한다.
3. **연결(`ConversationController`·`AppDelegate`)**
   - 사장 차례 A = 직원 글 중 `replyState == "asked"`인 수. U = 기존 안 읽은 합.
   - 일하는 직원은 `typing`에서 읽는다. 첫 켜짐 시각은 Island 쪽 상태로 기억한다.
   - `GateClient.status`에서 끊김과 재시도 초를 읽는다. 다시 연결되면 2초 동안 "다시 연결됨"을 보여 준다.
   - `transferFailed` 문구와 실패한 key를 알약으로 보낸다. 다시 보낼 수 있는 실패만 "다시 보내기"를 붙이고 `sendCurrent(for:)`를 부른다.
   - 업로드 k/n은 `sendCurrent`의 반복에서 내보낸다.
   - 연결 끊김 띠와 실패 notice는 알약으로 옮긴다. 다른 notice 용도는 유지한다.
3. **누르기**
   - 사장 차례 칸: 가장 오래된 `asked` 글의 방·스레드를 선택하고 카드를 펼친 뒤 1.5초 강조한다. 기존 선택·펼침·스크롤 경로를 쓴다.
   - 직원 칸: 그 직원 탭으로 간다.
   - 문제 칸: 즉시 재접속하거나 다시 보낸다.
   - 사장 차례 칸에 마우스를 올리면 최근 질문 한 줄과 "열기 ›"를 보여 준다. 답 버튼은 두지 않는다.
4. **잠깐 늘어남:** 새 `asked`는 4초, 다른 스레드의 직원 새 글은 3초다. 줄 세우기 순서는 문제 > 사장 차례 > 직원이다.
5. **시험:** AT-53~56을 앱 시험(가짜 모델·시계 주입)으로 만든다. 자동 캡처 2장(평소+직원 일하는 중, 연결 끊김)을 `evidence/HEJO-FOUNDATION/`에 둔다.
6. **범위 밖:** 알약 안 답 버튼·되돌리기, 할 일 칸, D-day·마감, 직원 작업 실패, 아침 요약, 펫 배지 색. 시안 v28·v31은 참고일 뿐이다.

### 공통

- 검증
  - hejo: `HEJO_PYTHON`·`HEJO_TEAM_KIT_LIB`·`PYTHONPATH`(.build deps + Hermes 소스 + 저장소)를 지정해 `bash scripts/test.sh`를 실행하고 종료 0이어야 한다.
  - `app/scripts/test.sh`를 10회 연속 실행해 모두 종료 0이어야 한다.
  - 게이트웨이 Python으로 `scripts/scan_private.py`를 실행해 0이어야 한다.
  - `import SwiftUI`가 0건이어야 한다.
- impl-report에 TASK-08·10·11 절을 나눠 명령·종료 코드·로그 경로·커밋을 적는다.
- 금지: git push, 운영 hejo 연결, 외부 발송, ddots 수정, 개인값.
- 시안 파일은 건드리지 않는다.

## 보완 지시 10: TASK-11 일하는 중 움직임 변경 (2026-11-15, 사용자 선택)

- **변경:** 직원 칸의 도는 고리를 없애고, "일하는 중"·"N명 일하는 중" 글자에 **반짝임**을 준다(시안 `mockup/hejo-ui-v32-typing-motion`의 3번).
  - 밝은 빛 띠가 글자 위를 왼쪽에서 오른쪽으로 지나가며, 1.6초마다 반복한다.
  - AppKit으로 만든다. 글자 모양 마스크를 씌운 `CAGradientLayer`의 위치만 움직이고, 글자 배치는 바뀌지 않는다.
  - 동작 줄이기 설정이면 흐린 글자로 멈춘다.
- **반영 기준:** spec REQ-HF-18.AC-02·06, design 6절, AT-HF-53(d)·56이 이번에 갱신됐다.
- **범위:** 대화 안의 작성 중 말풍선(ddots 그대로)은 이번에 바꾸지 않는다. 사용자가 따로 정하면 바꾼다.
- **작업 방식:** 진행 중인 TASK-11 작업 위에 이어서 반영한다. 계획 담당은 실행 담당의 파일을 건드리지 않는다.

## 보완 지시 11: TASK-12 대화 안 작성 중 표시 (2026-11-15, 사용자 선택 "1번과 4번을 모두")

TASK-11을 마친 뒤 이어서 한다. 커밋은 TASK-11과 따로 한다.

- **기준**: spec REQ-HF-19(REQ-HF-12 예외), design 6절 "대화 안 작성 중 표시", AT-HF-57.
- **기다릴 때**
  - `ConversationView`의 작성 중 줄 "● ● ●  작성 중"을 "작성 중" 반짝임 글자와 흐린 경과 초로 바꾼다.
  - 반짝임 부품은 아일랜드(보완 지시 10)와 같은 것을 함께 쓴다.
  - 경과 초는 그 스레드에서 작성 중이 처음 켜진 시각부터 센다. 60초 이상이면 "1분 5초"로 쓴다.
- **글이 흘러나올 때**
  - `NativeThreadCard`에서 `post.streaming`인 글의 본문 끝에 깜빡이는 커서(2pt, `systemBlue`, 0.5초 켜짐/꺼짐)를 덧그린다.
  - 커서는 문자열·속성·높이 계산에 넣지 않는다.
  - final 편집이 오면 커서를 없앤다.
- **동작 줄이기**: 반짝임과 깜빡임을 멈춘다. "작성 중"은 흐린 글자, 커서는 켜진 채로 둔다.
- **바꾸지 않을 것**: 중지 버튼, 작성 중 줄 높이(22), 흘러나오는 글의 기존 부드러운 덧붙임.
- **검증**: AT-57 앱 시험(시계 주입)을 추가한다. 나머지 검증·금지 사항은 9판 인계와 같다.

## TASK-09 실행 순서 (2026-11-15, 사장 참여 필요)

TASK-02~08·10~12가 끝났다(17·18차). TASK-09는 운영 공항을 바꾸고 게이트웨이를 다시 켜기 때문에, **사장이 자리에 있을 때만** 한다.

1. **사전 확인 (읽기만)**
   - 운영 푸시 `origin/main` ← `855149a4`가 승인되었는지 본다.
   - 처리 중인 차례·작업이 0인지 본다.
   - `install/hejo-install --check` 결과를 본다.
2. **설치**
   - `install/hejo-install`을 실행한다. 영수증 `<HOME>/hejo/install-receipt.json`이 생긴다.
   - 기본 프로필은 문, 보조 프로필은 전달자로 설치된다.
   - 재시작은 하지 않는다.
3. **재시작 (사장 확인 뒤)**
   - 게이트웨이를 한 번 재시작한다. 이것으로 함께 적용되는 것:
     - hejo 문
     - team-kit 답장 버튼(`392a2afb`)
     - 캐시 auto(`855149a4`)
   - Slack이 계속 동작하는지 바로 확인한다.
4. **노트북 앱**
   - 빌드한 앱을 설치하고 Tailscale 주소로 페어링한다.
   - AT-31: 실제 직원 1명과 대화·버튼·첨부·예약 보고를 하고, 지연을 5회 잰다.
   - AT-22(3): 보조 프로필 예약 보고를 확인한다.
5. **수동 체크리스트**
   - AT-26: ddots와 나란히 비교한다.
   - AT-47: 다른 앱 포커스를 유지하는지, 다중 화면에서 T11-01이 생기는지 본다.
   - AT-56: 아일랜드를 확인한다(`evidence/HEJO-FOUNDATION/TASK-11.md`).
   - AT-57: 작성 중 표시를 확인한다(`TASK-12.md`).
   - 밝은 모드에서 반짝임이 보이는지, 실제 앱의 버전 줄을 본다.
6. **되돌림 확인**
   - `install/hejo-install --uninstall`을 실행하고 재시작한다. Slack만 남는지 본다.
   - 다시 설치한다.
   - 캐시는 필요하면 before JSON대로 `5m`으로 복원한다.

금지(그대로): git push 직접 실행, 비밀 파일 열기, Hermes 본체·ddots 수정, 실제 Slack·고객 메시지 발송.

## 보완 지시 12: TASK-17 ddots 기능 이식 1단계 (2026-11-15, 사용자 지시 "ddots의 모든 기능을 가져온다", 연합개발)

- **배경:** ddots와 hejo를 82항목으로 비교했다. 그중 약 35가지가 없거나 일부만 있다(창 크기 기억, 말풍선, 펫 동작, 설정, 방 만들기, 오른쪽 옆 창 등). 1단계는 매일 체감되는 창·펫·알림이다. 작성기 HTML 전송 버그는 계획 담당이 이미 고쳤다(`5569f16`).
- **기준:** spec REQ-HF-21.AC-01~05, design 6절 "ddots 기능 전부 이식", AT-HF-61~65. ddots 위치는 아래와 같다(`<운영 저장소>/ddots/Sources`).
  - 창: `App.swift` 289(크기 불러오기)·956 `saveChatSize`·997 `toggleChatWidth`·1034 `resetChatSize`·753 / `ChatPresentation.swift` 102 `replyExtraHeight`·`slackFitHeight`
  - 말풍선: `PetView.swift` 454 `revealBubble`, `BubbleReveal.swift`, `App.swift` 458·1210
  - 펫 동작: `PetView.swift` 1410~1479(작업 상태), 1455 `doze.update`, `App.swift` 228(화면 꺼짐 정지)
  - 펫·메뉴: `App.swift` 2105 `resizePet`, `resetPosition`, 1334~1335(숨기기·쉬기), `toggleBubbleAlwaysShown`
  - 설정: `App.swift` 1870~1985, `SettingsPages.swift`
  - 다시 실행: `SlackController.swift` 1577
- **먼저 할 일:** 위 원본 파일과 의존을 끝까지 읽고 `copy-review.md`에 파일별로 가져올 범위·바꿀 점·뺄 Slack 부분을 기록한다(사용자 지시 2026-11-14).
- **구현 범위**
  - **창:** `PetController`가 크기를 `LocalSettings`에 저장하고 되살린다(화면 밖이면 맞춤). 머리줄(빈 곳) 두 번 누르기로 넓게↔원래 너비, 메뉴 "대화창 크기 초기화", 스레드를 펼치면 화면 안에서 높이를 자동으로 키우고 접으면 복귀한다(ddots 규칙 그대로).
  - **접힌 펫 말풍선:** 새 직원 글 3초(직원 이름과 첫 줄), 마우스 올림 → 상태, 누름 → 그 스레드 열기, "말풍선 항상 보이기". 시계를 주입한다.
  - **펫 상태 동작:** asked → 전화, typing → 노트북, 보내기 → 손 흔들기, 실패 → 실패, 3분 무조작 → 졸기, 동작 줄이기, 화면 꺼짐·잠김이면 정지. 자산은 이미 번들에 있다.
  - **설정 창:** AppKit으로 만든다(일반, 화면과 펫). 펫 크기 25~200%, 펫 이름, 말풍선 항상 보이기, 로그인 시 실행. 펫 이름·크기·항상 보이기는 허브 회원 설정(`HubClient.save`)으로 동기화한다. 메뉴에 "설정…", "펫 위치 초기화", "펫 숨기기", "잠시 쉬기", "대화창 크기 초기화"를 둔다. 펫 이름은 말풍선·안내 글에 보인다.
  - **키:** 편집 메뉴에 "다시 실행 ⌘⇧Z"를 둔다. Esc는 검색이 열려 있으면 검색을 먼저 닫는다.
- **바꾸지 않을 것:** 아일랜드(REQ-HF-18)·작성 중 표시(REQ-HF-19)·로그인(REQ-HF-20)·gate·hub·wire. 새 SwiftUI는 쓰지 않는다.
- **검증**
  - AT-61~65 앱 시험(시계·화면 상태 주입)
  - 환경 지정 `python3 .build/foundation9_runner.py hejo` 종료 0
    - 주의: Hermes 업데이트로 venv 경로가 바뀔 수 있다. `.build/task04-resume/python-path`가 없으면 `~/.hermes/installs/*/environments/*/venv/bin/python` 중 aiohttp·ruamel이 있는 것으로 갱신한다.
  - `app/scripts/test.sh` 10회 연속 0
  - 게이트웨이 Python `scripts/scan_private.py`(pre-commit) 0, `import SwiftUI` 0
  - 맥미니 화면 캡처(`screencapture`)로 말풍선·설정 창을 확인한다
- **적용:** `bash app/scripts/build.sh` → `/Applications/hejo.app`과 공용 `hejo.app`(Mac 공용 폴더 `Shared/hejo`)에 복사 → 실행. 앱만 바뀌므로 게이트웨이 재시작은 필요 없다.
- **커밋:** TASK-17만 `git commit --only`로 커밋하고, impl-report에 "TASK-17" 절(명령·종료 코드·로그·커밋·캡처 경로)을 쓴다.
- **금지:** git push(공개 GitHub 포함), 게이트웨이 재시작·reload, 비밀 파일, Hermes 본체·ddots 수정, 외부 발송, 허브·운영 설정 변경, 공개 `public` 브랜치 갱신(계획 담당이 한다).


## 보완 지시 13: TASK-18 앱 아이콘 `HEJO.` (2026-11-15, 사용자 지시 "hejo 앱의 아이콘은 HEJO. 글씨로 만들자", 연합개발)

- **배경:** 지금 번들에는 아이콘이 없어 Finder·Dock에 기본 앱 그림이 보인다. 로고(REQ-HF-17, `H`만 파랑)와 같은 글씨로 아이콘을 만든다.
- **기준:** spec REQ-HF-22.AC-01, AT-HF-66.
- **모양:** 1024px 캔버스, 흰 바탕 macOS 둥근 사각형(Apple 격자: 824px 정사각형을 가운데에 두고 모서리 반지름 약 185px, 아주 옅은 그림자는 선택). 가운데에 `HEJO.` 한 줄, 시스템 글꼴 heavy(또는 black) 굵기, 글자 폭이 둥근 사각형 폭의 약 78%. `H`는 `systemBlue`와 같은 sRGB 값, `EJO.`는 거의 검정(#1d1d1f 정도). 다크 모드용 별도 아이콘은 만들지 않는다.
- **구현**
  - 아이콘 그리기는 순수 AppKit 함수 하나로 둔다(예: `AppIcon.render(pixels:) -> NSBitmapImageRep`). 앱 시험에서 직접 부를 수 있게 앱 소스에 두되 런타임에 쓰지 않아도 된다. 앱 실행 중 Dock 아이콘을 바꾸지 않는다(`LSUIElement`는 그대로).
  - `app/scripts/build.sh`가 같은 함수를 쓰는 작은 생성 단계(예: `swiftc`로 만든 도구 또는 앱 실행 파일의 숨은 인자)로 `AppIcon.iconset`의 10장(16·32·128·256·512와 각 @2x)을 만들고 `iconutil -c icns`로 `Contents/Resources/AppIcon.icns`를 만든다. 생성물은 `.build/` 아래에 두고 저장소에 png·icns를 커밋하지 않는다.
  - `app/Resources/Info.plist`에 `CFBundleIconFile` = `AppIcon`을 넣는다.
  - 작은 크기(16·32)에서도 같은 그림을 축소한다(별도 글자 배치 불필요, 단 글자가 잘리지 않아야 한다).
- **바꾸지 않을 것:** 앱 안 로고·아일랜드·로그인·TASK-17 진행 중 파일(`AppDelegate`·`PetController`·`PetView`·`ConversationView`·`LocalStore` 등)의 동작. TASK-17 작업 트리 변경과 섞어 커밋하지 않는다.
- **검증**
  - AT-66 앱 시험: 1024px에서 네 모서리 화소 투명, 가운데 줄에 파랑·어두운 화소 존재, 좌우 끝 10% 열에 글자 화소 없음; 16px 그림 생성 성공
  - `bash app/scripts/build.sh` 종료 0, 번들에 `AppIcon.icns`, `plutil -extract CFBundleIconFile raw` = `AppIcon`
  - `app/scripts/test.sh` 10회 연속 0, `python3 .build/foundation9_runner.py hejo` 종료 0, pre-commit(개인값 검사) 0, `import SwiftUI` 0
  - `sips -s format png`로 1024px를 `.build/`에 뽑아 눈으로 확인하고, 설치 뒤 Finder 캡처(`screencapture`) 경로를 impl-report에 적는다. Finder 아이콘 캐시가 남으면 `touch /Applications/hejo.app`만 한다(캐시 삭제·`killall Dock` 금지).
- **적용:** TASK-17과 같은 방식으로 `/Applications/hejo.app`과 공용 `hejo.app`에 복사. 게이트웨이 재시작은 필요 없다.
- **커밋:** TASK-18 경로만 `git commit --only`, impl-report "TASK-18" 절.
- **금지:** git push, 게이트웨이 재시작·reload, 비밀 파일, Hermes 본체·ddots 수정, 외부 이미지·글꼴 파일 추가, 공개 `public` 브랜치 갱신.

## 보완 지시 12-1: TASK-17 메뉴 정리 (2026-11-15, 사용자 선택 "이대로 정리")

- **배경:** 사장이 펫 메뉴 캡처를 보고 "여기에 이런 옵션이 있는 게 맞냐"고 물었다. 설치된 앱 메뉴에 설정 항목(펫 이름…, 로그인 시 실행, 로그인 항목 설정…)과 계정 항목(로그인·계정…, 로그아웃)이 섞여 있다. ddots는 "자주 쓰는 동작은 메뉴, 설정과 미리보기는 설정 창"이 원칙이다(`App.swift` 1329 주석). 작업 트리의 TASK-17 진행분은 오히려 메뉴에 항목을 더 늘렸다(설정…·펫 위치 초기화·대화창 크기 초기화 추가, 기존 항목 유지).
- **바뀐 기준:** spec REQ-HF-21.AC-01·AC-04, AT-HF-61·64 (이 커밋에서 갱신). 보완 지시 12의 "메뉴에 … 펫 위치 초기화 … 대화창 크기 초기화를 둔다"는 이 절로 대체한다.
- **메뉴(상태 막대·펫 오른쪽 클릭이 같은 메뉴):** 대화 열기 / 구분선 / 펫 숨기기(숨김 상태면 "펫 보이기") / 잠시 쉬기(쉬는 중이면 "다시 움직이기") / 구분선 / 설정…(⌘,) / 흐린 `hejo <CFBundleShortVersionString> (빌드 <CFBundleVersion>)` / 구분선 / hejo 종료(⌘Q). 그 밖의 항목은 넣지 않는다.
- **설정 창 페이지(AppKit, ddots `SettingsPages.swift` 배치 참고):**
  - 일반: 로그인 시 실행(체크), 로그인 항목 설정 열기(버튼)
  - 화면과 펫: 펫 크기, 펫 이름, 말풍선 항상 보이기, 펫 위치 초기화(버튼), 대화창 크기 초기화(버튼)
  - 계정: 아이디, 공항 연결 상태(지금 메뉴의 상태 줄 글을 옮김, 실시간 갱신), 로그인·계정 창 열기(버튼, 기존 LoginWindow), 로그아웃(버튼)
- **시험:** 메뉴 항목 제목·구분선 순서를 그대로 확인하는 앱 시험을 AT-64에 더한다. 기존 시험 중 메뉴 항목 제목으로 찾는 것(로그아웃·로그인·계정 등)은 설정 창 버튼으로 옮긴다.
- 그 밖의 범위·검증·금지는 보완 지시 12와 같다.

## 보완 지시 12-2: TASK-17 우클릭 메뉴 1단계 (2026-11-15, 사장 승인 "좋다 구현해")

- **배경:** 사장 캡처에서 사이드바 직원 아이콘을 우클릭하면 앱 전체 메뉴(로그인·종료 등)가 떴다. 직원 줄에는 그 직원 메뉴가 떠야 한다. 계획 담당이 ddots 방 목록 메뉴(`SlackPanel.swift` 1987~2045 `.contextMenu`, `ChatWorkspace.swift` 33 머리줄 메뉴)를 기준으로 구성안을 내고 사장이 승인했다.
- **기준:** spec REQ-HF-21.AC-06, AT-HF-67. 먼저 위 ddots 두 곳과 `slackPinMenu`, `toggleMute`, `hide`, 사이드바 너비 전환 코드를 끝까지 읽고 `copy-review.md`에 기록한다. Slack API 호출 부분은 가져오지 않는다.
- **구현 범위(이번 1단계 몫만)**
  - 직원 셀(`EmployeeSidebarCell`/사이드바 표) `menu(for:)`: 대화 열기(지금 열린 직원이면 없음) / 구분선 / 맨 위에 고정·고정 해제 / 모두 읽음 / 알림 끄기·켜기 / 구분선 / 목록에서 빼기. 우클릭이 펫·앱 메뉴로 새지 않게 한다.
  - 사이드바 빈 곳: 숨긴 대화 다시 보이기 ▸(하위 메뉴, 숨긴 직원 없으면 흐림) / 구분선 / 목록 넓게·좁게(기존 사이드바 너비 규칙 사용).
  - 머리줄(`ConversationView` 77~78행 메뉴 교체): 알림 끄기·켜기 / 모두 읽음 / 구분선 / 방 목록 보이기·숨기기 / 구분선 / 펫으로 접기.
  - 동작: 고정은 목록 맨 위(고정 순서 유지), 모두 읽음은 그 직원 모든 스레드의 `readSeq`를 최신으로(ConversationModel 136행 규칙), 알림 끔은 사이드바 회색 숫자만·펫 숫자/접힌 펫 말풍선/아일랜드 강조 제외(단 asked는 아일랜드 사장 차례 칸에 셈), 목록에서 빼기는 숨김만(글 보존, 새 글 오면 다시 보임).
  - 저장: 고정·알림 끔·숨김을 허브 회원 설정(`HubClient.save`, 값은 문자열이므로 직원 id를 쉼표로 이은 `pinned`·`muted`·`hidden` 키)에 두고, 로그인 때 되살린다. 허브 서버 코드는 바꾸지 않는다(설정 크기 제한 안에서). 허브가 안 될 때는 로컬 값으로 동작하고 다음 저장 때 보낸다.
  - 2·3단계 항목(하던 일 멈추기, 직원 정보, 사진, 방 메뉴, 새 방, 전체 검색, 제목 바꾸기)은 이번에 넣지 않는다. 자리만 비워 둔다.
- **시험:** AT-67 앱 시험(메뉴 제목 순서, 고정 정렬, 모두 읽음, 알림 끔 집계, 숨김·재등장, 설정 직렬화 왕복; `StubHub`로 저장 요청 확인). 수동: 직원 우클릭·빈 곳·머리줄 메뉴 캡처.
- 그 밖의 검증·적용·커밋·금지는 보완 지시 12와 같다(TASK-17 커밋에 함께 넣는다).

## 보완 지시 13-1: TASK-17 V-1 정리 + TASK-18 재확정 (2026-11-15, 21차 판정 뒤)

- **순서:** ① TASK-17 V-1 정리 커밋, ② TASK-18 앱 아이콘(보완 지시 13 그대로) 커밋. 두 커밋은 분리한다.
- **① V-1:** `app/Sources/AppDelegate.swift`에서 호출처가 없어진 `@objc settings()`·`resetPosition()`·`resetChatSize()`·`loginSettings()`·`login()`·`rename()`을 지운다(먼저 `grep -n '#selector(<이름>)'`과 직접 호출 0을 다시 확인). `setLoginEnabled`·설정 창 연결은 그대로 둔다. 동작 변화가 없어야 하므로 시험 기대값은 바꾸지 않는다. 검증: `app/scripts/test.sh` 0(AT-61~65·67 PASS), 개인값 검사 0. impl-report에 "TASK-17 V-1" 줄을 더한다.
- **② TASK-18:** 보완 지시 13·spec REQ-HF-22.AC-01·AT-HF-66 그대로. 기준은 ① 커밋.
- **검토자 참고:** 분리 worktree에서 runner를 돌릴 때는 `.build/task02-deps`·`task03a-deps`·`task04-resume`를 함께 복사해야 한다(없으면 AT-HF-22가 yaml 없음으로 실패).

## 보완 지시 13-2: 쓰지 않는 코드 정리 확대 (2026-11-15, 사장 지시 "쓸데없는건 지우자")

- **범위:** 13-1의 ① V-1을 이 절로 넓힌다. 대상은 `app/Sources`, `gate/`, `hub/`, `install/` 전체에서 호출처·참조가 없는 함수·변수·타입·상수·옛 동작이다. ②(TASK-18 아이콘)는 그대로 그 뒤에 한다.
- **계획 담당 1차 후보** (앱 소스·시험에서 이름이 한 번만 나오는 것)
  - AppDelegate 셀렉터 `settings`·`resetPosition`·`resetChatSize`·`loginSettings`·`login`·`rename`
  - ConversationView `collapseConversation`(옛 머리줄 메뉴)
  - `GeniePictureKey`, `PetBubbleMotion`, `ScreenWindowResolver`, `actionRects`, `avatarNameGap`, `cachedCount`, `callerAvatar`, `cover`, `defaultPaneWidth`, `diagnosticButtonFrames`, `dozeZs`, `dragAnimation`, `extended`, `fadeDuration`, `firstText`, `glide`, `hasProfileColor`, `hsl`, `maximumChatSize`, `minimumPaneWidth`, `notificationAvatar`, `paneHeight`, `paneSplit`, `perchRect`, `rank`, `replyInset`, `reportHeight`, `retarget`, `searchHeight`, `sizes`, `slideWidth`, `speakerInset`, `statusTitle`, `thumbnailPixels`, `topInset`, `uniformSize`, `usablePaneWidth`
- **판정 규칙:** 후보마다 실제로 확인한다.
  - 지우지 않는 것:
    - AppKit·delegate가 이름으로 부르는 재정의·프로토콜 메서드(`canBecomeKey`, `cancelOperation`, `draggingUpdated`, `controlTextDidChange`, `menuNeedsUpdate`, `applicationWillTerminate`, `urlSession` 등)
    - `CodingKeys`
    - 셀렉터·키 경로·문자열로 부르는 것
    - 응답 체인 메뉴 동작(`pasteAsPlainText`·`pasteAsRichText`는 편집 메뉴나 작성기에서 쓰이는지 확인)
  - 다음 단계를 위해 남겨 두는 것도 지운다(필요해지면 그 단계에서 ddots에서 다시 가져온다).
  - gate·hub·install은 같은 방법(정의 이름 전역 검색, 동적 호출 확인)으로 찾는다.
  - 시험 전용 도우미는 시험이 쓰면 남긴다.
- **동작 불변:**
  - 시험 기대값을 바꾸지 않는다.
  - 지운 것 때문에 시험이 깨지면 그것은 쓰이는 코드이므로 되돌린다.
- **검증:**
  - `python3 .build/foundation9_runner.py hejo` 0
  - `app/scripts/test.sh` 0
  - 개인값 검사 0
  - 지운 이름 목록(파일·줄 수)과 남긴 후보·이유를 impl-report "코드 정리" 절에 적는다.
- **적용·커밋:**
  - 앱 설치본 교체는 TASK-18 적용 때 함께 한다.
  - gate·hub 파일을 지웠으면 공용 릴리스(`install/hejo-release`)·게이트웨이 재시작은 하지 않는다(다음 릴리스 때 반영).
  - 정리만 별도 `git commit --only`.

## 보완 지시 13-3: TASK-19 = 보완 13-2 실행 (2026-11-15, 22차 판정 뒤)

- 13-1 ①(V-1)과 ②(TASK-18)는 22차에서 완료로 판정했다. 13-2의 넓힌 정리를 TASK-19로 실행한다. 기준 커밋은 이 절을 담은 커밋이다.
- 13-2 후보 목록에서 V-1 6개(AppDelegate 셀렉터)는 이미 지워졌으니 뺀다. 새로 생긴 `AppIcon.render`는 시험·빌드 도구가 쓰므로 남긴다.
- 그 밖의 판정 규칙·검증·금지는 13-2와 같다. 정리 커밋 뒤 앱을 빌드해 `/Applications`와 공용 사본을 교체·실행한다(동작 불변 확인용). 게이트웨이·허브 재시작은 하지 않는다.

## 보완 지시 14: TASK-20 직원 사진·구획, TASK-21 단체방 (2026-11-15, 사장 지적·선택 "부른 직원만")

- **배경:** 사장 지적은 "에이전트 사진 교체, 채팅방 생성·삭제, 세션구획 세팅 등 전혀 구현이 안 되어 있다"이다. 3단계 계획이던 방·구획을 지금 순서로 당긴다. "세션"은 ddots 사이드바 구획(섹션)이다.
- **순서:** TASK-19(완료, 23차) → TASK-22(보완 14-1) → TASK-20 → TASK-21 → TASK-23(운영 적용·실물 수락, 보완 15). 각각 별도 커밋하고, 하나가 끝나면 impl-report를 쓴 뒤 다음으로 간다. 위험·증거·완료 경계는 보완 15가 기준이다.
- **기준:**
  - spec REQ-HF-23.AC-01·02, REQ-HF-24.AC-01~04
  - design 6절 "사진·구획·단체방(14판)"
  - AT-HF-68~71
- **ddots 원본(먼저 끝까지 읽고 copy-review.md 기록):**
  - `SlackPanel.swift` 1277~1346(sections·addSection·onRename·onPicture·onCreateRoom·onInviteAgents·onArchive·onDeleteRoom), 1955~2120(구획 배치·머리·끌어 옮기기·새 채널/섹션 버튼), 2249·2350
  - `SlackController.swift` 318~348과 `createRoom`·`invite`·`archive`·`deleteRoom`·`rename`·`choosePicture` 본문
  - `App.swift` 907(탭 사진)
  - `SlackRoomPictures`
  - `SettingsSync.swift` 11~20
  - ddots 멘션 자동 완성 원본(작성기 @ 처리)
  - Slack API 호출은 가져오지 않고 hejo 문 규격으로 바꾼다.
- **TASK-20**
  - 문: `/v1/pictures/<employee|room>/<id>` PUT(PNG만, 512 KiB 이하, 서명 바이트 확인)·DELETE·GET(인증), 명부 avatar 주소. 저장은 공용 창고 `<HOME>/shared/hejo/pictures/`(design 14판 — 금고 `hejo/`에 두지 않는다). 옛 `/v1/avatars`는 지우고 규격 문서를 갱신한다.
  - 앱:
    - 직원 우클릭 "사진 바꾸기…"(NSOpenPanel)·"사진 지우기"
    - 256px PNG 변환
    - 사진 표시(사이드바·카드·아일랜드 얼굴·접힌 말풍선)
    - 명부 새로 고침(연결 시·5분·메뉴 열 때)
  - 구획: AC-02 전부를 `ConversationModel`·`ConversationView`에 둔다. 허브 `sections` 키, 빈 곳·＋ 메뉴 "새 구획 만들기", 구획 머리 메뉴, 끌어 옮기기.
  - 2단계 몫이던 "직원 정보…"는 이번에 넣지 않는다.
- **TASK-21**
  - 규격: room 프레임·선택 필드, `hello.features`.
  - 문: 기록장 room·room_delete, 검증·거절 코드, 방송·재현, @/대표 전달(`chat_id=room:<id>`), 답·작성 중의 방 되찾기. 삭제는 design 14판 '삭제 계약' 그대로: `room_delete` 한 줄이 확정점(글마다 delete 기록 없음), 재현·조회에서 지운 방 제외, 지운 방 id 묶음으로 늦은 답·작성 중·직원 첨부 버림(`room_deleted_drop`), 지운 방 id 거절(`room_deleted`), 확정 뒤 그 방 전용 첨부·방 사진 정리(멱등, `FileStore.cleanup`이 지운 방 기록의 등록을 살아 있지 않은 것으로 셈).
  - 앱:
    - 새 방 만들기 창(AppKit: 이름·직원 체크·대표)
    - 단체방 우클릭 메뉴(AC-03 순서 그대로)
    - 머리줄 "제목과 설명 바꾸기…"
    - 보관한 방 하위 메뉴
    - 삭제 확인 창("직원이 이미 받은 내용은 직원 기억에 남을 수 있어요")
    - @ 자동 완성
    - 카드에 말한 직원 이름·얼굴
- **검증**
  - AT-68~71 자동(문 pytest + 앱 시험, 가짜 Hermes로 @ 전달 확인). AT-70은 고장 주입(`room_delete` 쓰기 실패, 정리 실패 뒤 재시작)·늦은 응답·재연결·첨부 보존을 모두 넣는다.
  - `python3 .build/foundation9_runner.py hejo` 0
  - `app/scripts/test.sh` 10회 연속 0
  - 개인값 검사·pre-commit 0
  - SwiftUI 0
  - 메뉴·창 캡처
  - TASK-21은 규격 시험(스키마 검증)과 옛 클라이언트 호환 시험을 반드시 넣는다.
- **적용**
  - 앱: `/Applications`·공용 사본 교체.
  - 문(gate) 변경은 공용 릴리스(`install/hejo-release`)로 반영해야 운영에 들어간다. 여기까지 준비하고, **게이트웨이 재시작은 하지 않는다.** 재시작은 사장 확인 뒤 계획 담당이 따로 안내한다(롤백: 이전 릴리스 디렉터리 복원 후 재시작).
- **금지:** git push, 게이트웨이 재시작·reload, `~/.hermes` 비밀 파일, Hermes 본체·ddots 수정, 허브 서버 코드 변경(설정 키만 사용), 외부 발송, public 브랜치 갱신, 문서·시험에 실제 직원 이름.

## 보완 지시 14-1: TASK-22 hejo 홈 채널 자동 설정 (2026-11-15, 사장 선택 "설치 때 자동 설정")

- **배경:** 새 세션마다 hejo 대화 첫머리에 "📬 Hejo에 홈 채널이 설정되어 있지 않아요 … /sethome" 안내가 붙는다.
  - 원인은 Hermes 본체 `gateway/run_turn.py`(약 1455~1479줄)다. 그 플랫폼의 홈 채널(환경 변수, 비밀 범위, `config.yaml`의 `platforms.<플랫폼>.home_channel`, 보조 프로필 설정)이 하나도 없으면 안내를 보낸다.
  - 본체는 고치지 않는다. 설정으로 해결한다. 저장 형식은 본체 `gateway/config.py` `persist_home_channel`·`HomeChannel.to_dict`와 같은 `{platform, chat_id, name}`이다.
- **순서:** TASK-19 다음, TASK-20 앞(작고 바로 체감됨). 별도 커밋.
- **구현:**
  - `install/hejo-install`에 위 AC를 넣는다. 영수증 대상·새 설치·이미 설치된 공항의 갱신 경로·갱신 중 실패(키 단위 되돌림, 파일 전체 복원 금지)·쓰는 순서(pending 영수증 먼저)·중단 뒤 맞춤 표·제거 때 사장 값 보존·`--check`의 `missing_target`/`owner_set`·롤백 명령 `--uninstall-home-channel`은 design 'hejo 홈 채널' 절 그대로다.
  - chat_id는 hejo 문이 쓰는 직원 id(프로필 이름, 기본 프로필은 `default`/주 프로필 id — `gate/roster.py` 규칙을 따른다)다.
  - `.env` 등 비밀 파일은 읽거나 쓰지 않는다. 그쪽에 `HEJO_HOME_CHANNEL`이 있는지는 알 수 없으므로 config 값만 본다.
- **검증:**
  - AT-72 자동(test_install.py에 추가): 옛 `installed` 영수증 갱신, 갱신 중 실패 주입, 남은 `pending`/`applied` 대상, 사장 값 보존까지 AT-72 표의 모든 입력.
  - `python3 .build/foundation9_runner.py hejo` 0
  - 개인값 검사 0
- **적용:**
  - 공용 릴리스(`install/hejo-release`) 갱신까지 한다.
  - 운영 `~/.hermes`에 설치 도구 실행·게이트웨이 재시작은 **하지 않는다.** 사장 확인 뒤 계획 담당이 안내한다.
    - 롤백: 설치 도구 `--uninstall`의 home_channel 되돌리기 또는 영수증 기준 복원 후 재시작.
- **금지:** 보완 지시 14와 같다.

## 보완 지시 15: 계획 검증 R1~R4 반영 — 위험·증거·완료 경계 (2026-11-15)

검증 기록: [../56917a17-07e0-4cb3-940d-2880e1aeaae3/plan-review.md](../56917a17-07e0-4cb3-940d-2880e1aeaae3/plan-review.md).

- **위험 재분류:** TASK-20·21·22 모두 **고위험**(TASK-20 인증된 영구 저장·삭제, TASK-21 규격·전달·삭제·동시성, TASK-22 운영 게이트웨이 설정 변경). 보완 14·14-1의 '일반'·'높음'을 대신한다.
- **증거 수준과 완료 경계(한 기준):**

| TASK | 구현 인계 완료(실행 담당 → 계획 담당 판정) | 최종 수락(TASK-23) |
|---|---|---|
| TASK-22 | 수준 2: 임시 HERMES_HOME + 실제 설치 도우미 실행 AT-72 자동 전부 | 수준 4: 운영 공항 갱신 실행 후 재시작, 직원 새 세션 첫 답에 안내 없음 |
| TASK-20 | 수준 2: 문 pytest + 앱 시험(AT-68·69 자동), 앱 두 사본 교체, 캡처 | 수준 4: 맥미니에서 바꾼 사진이 다른 Mac(맥북프로)에도 보임, 구획 왕복 |
| TASK-21 | 수준 2: 가짜 Hermes 대역 AT-70·71 자동(고장 주입 포함) | 수준 4: 실제 직원 2명 단체방에서 @한 명·@없음·삭제 |

- 실행 담당이 인계 완료를 보고하면 계획 담당 판정은 **'구현 완료, 실물 수락 대기'(부분 완료)**가 최대다. 고위험이므로 설계자(계획 담당)의 검토 뒤 설계에 참여하지 않은 검토(별도 리뷰 세션 또는 사장, 30-verification 2절·5.2)를 한 번 더 받는다. 그 검토와 TASK-23 실물이 끝나야 각 TASK를 완료로 판정한다.
- **TASK-23 운영 적용·실물 수락(계획 담당 + 사장, 실행 담당 아님):**
  1. 적용 전: 사장 확인(진행 중 차례 없을 때). 운영 `shared/hejo/`(journal·files·pictures)를 0700 사본으로 떠 두고 경로를 verdict에 적는다. 현재 공용 릴리스 디렉터리 위치를 적는다.
  2. `install/hejo-release`로 공용 릴리스 갱신 → 운영 `hejo-install`(TASK-22 갱신 경로) 실행·출력 보관 → `--check` 0.
  3. 사장 확인 뒤 게이트웨이 재시작 → `gateway.log`에 hejo 연결 확인.
  4. 관측: 새 세션 첫 답 안내 없음(TASK-22), 두 Mac 사진·구획(TASK-20), 직원 2명 단체방 @·대표·삭제·재연결(TASK-21). 캡처·로그를 evidence에 둔다.
  5. 롤백: TASK-22는 `install/hejo-install --uninstall-home-channel`(설치 도우미가 넣고 사장이 안 바꾼 값만 삭제, design 'hejo 홈 채널' 롤백) + 재시작. 손으로 키를 지우지 않는다. TASK-20·21은 이전 공용 릴리스 + 1의 사본 복원 + 재시작(적용 뒤 hejo 글 잃음, Slack 무관). TASK-21 뒤 문 코드만 되돌리면 기록장이 열리지 않으므로 사본 복원을 같이 한다.
- 맥북프로가 준비되지 않으면 TASK-20의 두 Mac 항목은 '실물 미검증'으로 남기고 나머지는 판정한다.

## 보완 지시 16: TASK-22 검토 V-1 — 홈 채널 롤백 중단 복구 (2026-11-15, 17판)

검토 기록: [../56917a17-07e0-4cb3-940d-2880e1aeaae3/verdict.md](../56917a17-07e0-4cb3-940d-2880e1aeaae3/verdict.md) V-1·V-2.

- **문제(재현됨):** `remove_home_channels`가 config 키를 지운 뒤 영수증을 `removed`로 저장하기 전에 끊기면, 다음 실행의 맞춤이 `applied`+값 없음을 사장 변경으로 보고 `released`로 바꾼다. 그 뒤 설치를 다시 해도 값이 돌아오지 않고, `--check`는 `owner_set`·종료 0이라 빠진 홈 채널을 알리지 않는다(REQ-HF-25.AC-01 '`--check`는 빠진 프로필을 알린다' 위반). TASK-23 롤백이 이 명령을 쓴다.
- **고칠 것(design 'hejo 홈 채널' 17판 그대로):**
  1. home_channel 삭제(`--uninstall-home-channel`, `--uninstall`, 실패 설치 되돌림의 home_channel 삭제 모두)를 `removing` 저장 → 키 삭제 → `removed` 저장 순서로 한다.
  2. 맞춤 표에 `removing` 3행을 더한다(롤백이면 이어서 지움, 설치면 `applied`, 값 없음이면 `removed`, 다른 값이면 `released`).
  3. `--check`: `released`+값 없음은 `owner_removed <경로>`·정상. 값 없는 프로필에 `owner_set`을 출력하지 않는다.
  4. 기존 동작(갱신 쓰기 순서, C1, A/B/C 롤백, `--force`의 사장 값 보존)은 바꾸지 않는다. 영수증 version 1 유지.
- **검증:** AT-72 17판 추가 입력(④·⑤ 중단, 사장이 지운 키)을 `test_install.py`에 더한다. 기존 AT-72 시험의 기대값은 바꾸지 않는다(단, 사장 삭제 사례 `test_at_hf_72_owner_change_check_and_forced_uninstall`의 `owner_set` 2개 기대는 17판에 따라 `owner_set` 1 + `owner_removed` 1로 바뀌므로 그 한 줄만 고치고 보고한다). `removing` 순서를 지운 돌연변이가 시험에 걸리는지 확인한다. `foundation9_runner.py hejo` 0, 개인값 검사 0. 공용 릴리스 갱신.
- **범위:** `install/hejo-install`, `tests/acceptance/test_install.py`, impl-report. TASK-20·21은 계속 보류(ddots-inventory.md Q1~Q4 사장 답 뒤 명세를 다시 고친다). 운영 `~/.hermes` 실행·재시작 금지.

## 보완 지시 17: ddots 전수 대조 반영 — TASK-20 재작성, TASK-24~27 추가 (2026-11-15, 18판)

사장 선택(2026-11-15):
- Q1 직원 사진 원본: 권장대로, 각 프로필 `assets/avatar.png`
- Q2 다른 Mac과 맞추기: 모두 맞춤
- Q3 홈 방: 가져옴
- Q4 대화 화면 핵심 누락: 단체방보다 먼저 채움

기준 문서는 다음과 같다.
- [ddots-inventory.md](ddots-inventory.md)(무엇을 옮길지)
- spec REQ-HF-23·26~29와 REQ-HF-24.AC-05(무엇이 맞는지)
- design '전수 대조 반영(18판)'(칸·소유·위험)
- AT-68·69·73~80(시험)

- **순서:** TASK-22 보완 16(커밋 22ebcb5, 계획 담당 검토 대기) → TASK-24 → TASK-20 → TASK-25 → TASK-26 → TASK-27 → TASK-21 → TASK-23. 각각 별도 커밋하고, 하나가 끝나면 impl-report를 쓴 뒤 다음으로 간다. 보완 14의 TASK-20 지시(직원 사진 `shared/hejo/pictures`, 구획 손 정렬, 회원 설정 `sections`)는 이 지시가 대신한다. TASK-21(단체방)은 보완 14·15 그대로이고 REQ-HF-24.AC-05를 더한다.
- **베끼기(필수):**
  - 각 TASK 착수 전에, design 18판 절이 가리키는 ddots 파일 전체와 의존을 끝까지 읽고 `copy-review.md`에 파일별로 기록한다(읽은 범위, 옮길 규칙, 바꿀 자료 구조, 뺀 것과 이유).
  - 대조표는 목록일 뿐이며, 수치·문구·순서는 원본에서 확인한다.
  - 명세의 문구·수치가 원본과 다르면 멈추고 보고한다(계획 담당이 고친다).
  - ddots 파일은 읽기만 한다.
- **TASK별 핵심**
  - TASK-24
    - 허브 회원 상태는 회원 설정 16 KiB와 분리한다.
    - 처음 옮기기는 시각 0으로 넣는다.
    - 로컬 `readSeq`는 옮긴 뒤 지운다.
    - `ConversationModel`이 고정·알림·숨김·읽음을 `MemberState`로 읽고 쓰게 바꾸고, 옛 회원 설정 키 쓰기를 지운다(두 번째 원본 금지).
    - 설정 창에 "연결과 동기화" 탭을 더한다(이번엔 "화면 배치 동기화…" 하나).
  - TASK-20
    - 문은 프로필 경로를 Hermes 프로필 API로 찾는다.
    - `avatar.png`만 쓰고 `slack-avatar.png`·`profile.yaml`은 쓰지 않는다.
    - 사진을 바꾸면 `roster`를 방송한다.
    - 앱의 `systemBlue` 고정 얼굴을 없앤다.
    - 사이드바는 `SidebarLayout` 출력만 그린다. 질문 수는 이번에, 알림 수는 TASK-26에 넣는다.
  - TASK-25
    - `create_handoff_thread`는 Hermes 공개 확장점으로만 구현한다. 본체 동작(`/branch`·`/stop`)은 읽기 전용으로 확인하고 가짜 게이트웨이 시험으로 고정한다. 동작이 명세와 다르면 멈추고 보고한다.
    - `thread_delete`는 `room_delete`와 같은 확정점 규칙을 따른다.
    - `hejo` 주소 체계를 Info.plist에 등록한다.
  - TASK-26: 검색은 `cache/` 복제만 대상으로 한다(서버 검색 없음).
  - TASK-27: 문 변경 없이 기존 send로 보낸다.
- **검증(각 TASK)**
  - 해당 AT 자동 시험
  - `python3 .build/foundation9_runner.py hejo` 0
  - 앱 시험(app/scripts/test.sh)
  - 개인값 검사 0
  - 고위험 TASK는 중요 경로 돌연변이 1개 이상이 검출되는지 확인한다.
  - 화면 변경은 ddots 같은 상태 캡처와 나란히 비교해 evidence에 둔다.
  - 공용 릴리스 갱신은 TASK-24·20·25·21 각각 뒤에 한다.
- **금지:** 운영 `~/.hermes` 실행·재시작(TASK-23에서 계획 담당+사장이 한다), ddots 파일 수정, Hermes 본체 수정, 비밀 파일 열기, push, 실제 Slack·고객 발송. TASK-28은 이 작업이 아니다(운영 저장소).
- **위험·증거:** TASK-24·20·25·21은 고위험이며, 인계 수준 2 / 최종 수준 4(TASK-23)다. TASK-26·27은 일반 · 2다.

## 보완 지시 18: TASK-24 보류 D24-01·02 해소, 사장 추가 선택 반영 (2026-11-15, 19판)

- **D24-01(확인 창 문구):** 구현 담당 지적을 받아들인다. REQ-HF-26.AC-04를 ddots `App.makeSyncStandard` 원문 구조에서 서비스 용어만 바꾼 문구로 고쳤다(19판). 그 문구를 쓴다.
- **D24-02(처음 옮기기 조건):** 구현 담당 권고(ddots `joinSettings`)를 받아들인다.
  - 조건: 이 Mac `hejo-local.json`의 `stateJoined.<회원>` 표시가 없을 때 한 번 옮긴다. 허브가 비었는지와는 상관없다.
  - 시각: 옮긴 값의 시각은 ddots 원본과 같은 1이다(18판의 0은 폐기).
  - 저장: 옮길 값, 표시, `readSeq` 삭제를 `pendingState`와 한 번의 원자적 저장으로 함께 쓴다(spec AC-03, design `MemberState`, AT-74 19판).
- **사장 추가 선택(2026-11-15)**
  1. 단체방 문맥 "좋다" → REQ-HF-24.AC-02 19판(부른 직원에게 받기 전 같은 스레드 글 최신 20줄·4,000자), TASK-21, AT-71.
  2. "펫이 알림하게 하자" → REQ-HF-30, TASK-29, AT-81. macOS 알림 센터는 쓰지 않는다.
  3. 말풍선에서 바로 답하기 "좋다" → REQ-HF-31, TASK-30, AT-82.
  4. 공개 전 정리 "정리해야지" → 확인 결과 할 일이 없다.
     - `install/hejo-publish`는 지금 작업 트리만 개인값 검사 뒤 `public` 브랜치에 커밋 하나로 올리고, 개인 작업 이력은 내보내지 않는다.
     - `public`(347a68a)은 커밋 2개이고 대조표 파일이 없으며, 개인값 검사는 0이다.
     - 따라서 3295bfe의 이름은 공개 이력에 들어가지 않는다. 다음 공개 때도 publish가 검사를 다시 한다.
- **순서(19판):** TASK-24 → TASK-20 → TASK-25 → TASK-26 → TASK-29 → TASK-30 → TASK-27 → TASK-21 → TASK-23. 베끼기·검증·금지·위험은 보완 17과 같다. TASK-29·30은 일반 · 2다.
- **이어서 할 일:** TASK-24의 남은 원본·의존 전체 독해와 copy-review부터 시작한다. 이미 남긴 보류 보고(impl-report)는 그대로 두고, TASK-24 절에 해소 결과를 이어서 적는다.

## 보완 지시 19: 직원별 도구 연결 — TASK-31 탐침 (2026-11-15, 20판)

- **사장 선택:** ddots 에이전트 연결을 가져온다.
  1. 누구나 앱만 설치하면 편하게 쓴다.
  2. 처음 설치하는 누구나 쉽게 쓴다.
  3. 위험 동작을 허용한다.
  - 서버(맥미니)은 24시간 켜져 있다.
- **기준:** spec REQ-HF-32, design '직원별 도구 연결(20판)', AT-83.
- **순서:** 지금 하는 TASK-24를 마친 뒤 TASK-31(탐침)을 하고 보고한다. 그다음 TASK-20부터 19판 순서대로 간다. TASK-32(구현)는 탐침 결과로 계획 담당이 확정한 뒤 TASK-21 다음에 한다.
- **TASK-31 탐침(읽기 전용, 제품 코드 변경 없음)**
  - 환경: 임시 HERMES_HOME(기본 + 보조 2 프로필)과 Hermes venv에서만 시험한다. 운영 `~/.hermes`에는 손대지 않는다.
  - 확인할 것:
    1. 문(같은 게이트웨이 프로세스의 플랫폼 플러그인)이 프로필별로 아래를 읽고 쓸 수 있는가. 방식 (a)·(b)·(c)를 각각 시험하고, 본체 무수정, 프로필·비밀 범위 분리, 오류 문구 비노출을 확인한다.
       - 도구 묶음 목록·켜짐·필요 키 충족(`/api/tools/toolsets`와 같은 결과)
       - 도구 묶음 켜기·끄기
       - 비밀값 쓰기·지우기(`/api/env`와 같은 공식 쓰기 경로)
       - MCP 목록·추가·시험·OAuth 시작
       - OAuth 제공자 목록·시작·폴링
       - 게이트웨이 다시 시작(드레인 포함)
    2. 다른 Mac(노트북)에서 동의해야 하는 OAuth를 끝낼 수 있는 흐름은 무엇인가. 장치 코드, 붙여넣기 제출(`/submit`), 루프백 콜백을 문이 중계하는 방법을 제공자별로 표로 정리한다.
    3. 다시 시작 중 문 연결이 끊긴 뒤, 앱이 결과(재연결된 채널 수)를 받는 방법은 무엇인가.
    4. team-kit `hermes-connections`가 있는 공항에서 문이 그 명령을 대신 실행해 `hermes-connections/1` 문서를 받을 수 있는가. 비밀 표준 입력 전달과 시간 제한을 포함하며, 운영 저장소 사본(읽기만)으로 확인한다.
  - 보고: `probe-connections.md`에 방식별 결과·근거 파일·줄·실패와 추천을 쓰고, impl-report에 요약한다. 비밀값·토큰은 가짜 값만 쓴다.
- **금지:** 보완 17과 같다. Hermes 본체와 운영 저장소 파일 수정, 비밀 파일 열기(가짜 홈의 가짜 `.env`만 허용), 운영 게이트웨이 재시작을 하지 않는다.

## 보완 지시 20: TASK-31 검토 뒤 — TASK-32 결정 기록, TASK-20 착수 (2026-11-16, 21판)

- **TASK-31:** 검토 통과(verdict). 결정 D1~D8은 design '직원별 도구 연결(20판)'의 '탐침 뒤 결정(21판)'에 있다. TASK-32는 순서대로 TASK-21 다음에 하고, 착수할 때 이 결정을 기준으로 한다. D1 첫 단계 확인(백엔드가 메시징 게이트웨이를 따로 띄우지 않는지)이 실패하면 멈추고 보고한다.
- **지금 할 일:** TASK-20(직원 사진·색·사이드바 배치)을 보완 17·18대로 시작한다. 그 뒤 25 → 26 → 29 → 30 → 27 → 21 → 32 순서로 각각 별도 커밋하고, 하나가 끝날 때마다 impl-report를 쓰고 보고한다.

## 보완 지시 21: D20-01 해소 — ddots 문구 변환 규칙 (2026-11-16, 22판)

- **D20-01:** 구현 담당 지적을 받아들인다. 구획 삭제 본문을 원문 구조에 맞춰 "섹션만 없어지고 방은 그대로예요."로 고쳤다(18판의 "방과 글"은 원문에 없는 덧붙임이었다). 이동 안내 " 안에 있는 방 N개는 ‘<첫 구획 이름>’로 옮겨져요."는 용어 변환(채널 → 방)이므로 그대로 둔다.
- **일반 규칙:** spec '수락 기준' 첫머리에 'ddots 문구 변환 규칙(22판)'을 두었다. 용어 표, Slack 전용 구절 빼기, 나머지는 원문 그대로다.
  - 앞으로 이 규칙으로 설명되는 차이는 멈추지 말고 copy-review에 "변환 규칙 n번"으로 적고 진행한다.
  - 규칙으로 설명되지 않는 차이만 멈추고 보고한다.
  - 사진 우선순위(avatar.png 먼저)는 사장 선택 Q1로 승인된 차이다.
- **이어서 할 일:** TASK-20을 남은 원본·의존 전체 독해와 copy-review 기록부터 이어서 구현한다. 그 뒤 25 → 26 → 29 → 30 → 27 → 21 → 32 순서다. 지금 미커밋인 보고 기록(copy-review·impl-report의 D20-01 절)은 보존하고, TASK-20 커밋에 해소 결과와 함께 넣는다.

## 보완 지시 22: D20-02 해소 — 명부 `avatar_custom` (2026-11-16, 23판)

- **D20-02:** 구현 담당 지적과 제안을 받아들인다. 명부 직원 항목에 선택 필드 `avatar_custom`(bool)을 더한다. 그 프로필의 `assets/avatar.png`가 있으면 true다.
  - 앱의 "사진 지우기" 표시는 이 값만 따른다.
  - 규격 `schemas/hejo-wire-v1.json`의 roster 항목에 선택 필드로 더한다(하위 호환).
  - 옛 문 호환: 필드가 없는 옛 명부면 앱은 "사진 바꾸기…"·"사진 지우기"를 모두 숨긴다. 옛 문에는 사진 쓰기 API가 없기 때문이다. 표시는 `avatar`가 있으면 그대로 한다.
  - 반영 위치: spec REQ-HF-23.AC-01, AT-68.
- **이어서 할 일:** TASK-20 구현을 계속한다(원본 전체 독해 기록은 이미 끝남). `.build/task20/draft` 초안을 쓸 수 있다. 초안 시험의 상대 import 수집 오류(종료 2)는 시험 위치·실행 방식을 기존 수락 시험과 같게 맞춰 해결한다. 그 뒤 25 → 26 → 29 → 30 → 27 → 21 → 32 순서다.

## 보완 지시 23: TASK-20 검토 통과 — TASK-25 착수, 흐름 규칙 (2026-11-16)

- **TASK-20(344cbbd):** 검토 통과. 판정은 고위험 상한으로 부분 완료다.
- **흐름 규칙(사장 질문 "왜 시작하지 않고 있지"):**
  - TASK 하나를 끝내고 커밋하면 status는 `result`로 보고하고 계획 담당 검토를 받는다. 푸시 승인 대기(`input`)로 멈추지 않는다.
  - 푸시는 이 작업의 진행 조건이 아니다. 사장이 원할 때 따로 승인한다.
- **지금 할 일:** TASK-25(스레드 카드·작업 제어, REQ-HF-27, AT-75·76)를 보완 17·21대로 시작한다. ddots 원본 전체 독해 → copy-review → 구현이며, 문구 차이는 22판 변환 규칙을 따른다. 그 뒤 26 → 29 → 30 → 27 → 21 → 32 순서다.

## 보완 지시 24: D25-01 해소 — 원문 우선(24판), TASK-25 재개 (2026-11-16)

- **D25-01 결정(계획 담당이 원본 직접 확인):**
  - 복사 형식의 첨부 줄은 ddots `SlackCopy.text`처럼 `📎 <파일 이름>`이다(이모지 뒤 공백 하나). spec REQ-HF-27.AC-01을 고쳤다.
  - 되돌리기 글은 ddots `AgentStop.undoRequest` 원문 그대로다(`메모·파일·Notion·NAS·보낸 메시지 등`). spec REQ-HF-27.AC-04를 고쳤다.
  - REQ-HF-24.AC-02 단체방 문맥 묶음의 `📎<파일 이름>`은 ddots에서 옮긴 문구가 아니라 hejo가 새로 정한 형식이라 그대로 둔다.
- **문구 변환 규칙 보강(24판):** 명세가 원문을 옮기다 빠뜨리거나 공백·부호를 틀린 것이 분명한 차이는 원문이 이긴다. 원문대로 구현하고 copy-review·impl-report에 기록한 뒤 멈추지 않고 진행하며 result에서 알린다. 원문에 없는 새 문구나 뜻이 바뀌는 차이만 멈춘다.
- **재개:** 기존 copy-review·impl-report의 D25-01 기록을 보존하고, 남은 의존 대조(종·날짜·접힌 답·표·상태·체크리스트)부터 이어 TASK-25 전체를 구현·검증한다. 끝나면 별도 커밋 뒤 result로 보고한다(보완 23 흐름 규칙).

## 보완 지시 25: D25-02~05 결정 — 25판, TASK-25 재개 (2026-11-16)

계획 담당이 Hermes 본체(ebb026e, 읽기만)·통신 규격·앱 GateClient·ddots 원본으로 네 쟁점을 직접 확인하고 정했다. 실행 담당의 재현(`.build/task25/test_contracts.py` 3 passed)과 일치한다.

- **D25-02 스레드 삭제와 seq 연속:** 새 기록 종류·새 프레임 종류를 만들지 않는다.
  - 확정점은 기존 `delete` 기록 한 줄 `{msg_id: 첫 글, scope:"thread", room, thread, at}`이다. 이어서 나머지 글마다 보통 `delete`를 쓴다. 중단되면 문 시작 때 빠진 것만 다시 쓴다.
  - 재현·동기화·페이지에서 확정점 앞의 그 스레드 기록은 같은 seq의 `delete {seq, msg_id}`로 바꿔 보낸다. seq 빈칸이 생기지 않는다.
  - 규격 `delete`에 선택 필드 `scope`·`thread`를 더한다. 새 앱은 스레드 전체를 화면·캐시에서 지운다(캐시는 같은 seq `delete`로 원자적 재작성). 옛 앱은 이어지는 `delete`로 지워진다.
  - 앱은 알 수 없는 종류의 seq 프레임을 적용한 것으로 세고 건너뛴다.
  - 허용 파일에 `schemas/hejo-wire-v1.json`(선택 필드·client `thread_delete`·`thread_branch`), `app/Sources/LocalStore.swift`·`GateClient.swift`·`ConversationModel.swift`를 포함한다.
- **D25-03 종 되돌림:** `bell:`을 큰 seq 우선에서 빼고 `(at, dev)` 나중 쓴 쪽 우선으로 바꾼다(null로 지움). `read:`·`thread:`는 그대로 큰 seq 우선이다. 허용 파일: `hub/state.py`, `app/Sources/MemberState.swift`와 그 시험. 이미 저장된 `bell:` 값은 그대로 읽힌다(형식 같음).
- **D25-04 분기:** Hermes `/branch`는 플러그인 플랫폼에서 어댑터를 부르지 않으므로(고정 목록) hejo는 `/branch`를 보내지 않는다. 앱 `thread_branch` → 문이 새 스레드·이어짐 글(`branch_from`) 기록 → 새 스레드 첫 사장 글에 원래 스레드 대화를 `[이전 스레드 대화]` 묶음(50줄·16,000자·줄 2,000자)으로 붙인다. 본체 우회는 하지 않는다. 이 묶음 코드는 TASK-21의 단체방 문맥이 함께 쓰도록 한 곳에 둔다. `create_handoff_thread`는 구현하지 않는다.
- **D25-05 질문 대기 색:** ddots 원문대로 빨강 `#E01E5A`다(24판 원문 우선).
- **재개:** 기존 copy-review·impl-report 기록을 보존하고 25판 기준으로 TASK-25 전체를 구현·검증한다. 별도 커밋 뒤 result로 보고한다.

## 보완 지시 26: TASK-25 검토 통과 — N25-01 시험 보강 후 TASK-26 (2026-11-16)

- **TASK-25(af39f96):** 검토 통과. 판정은 고위험 상한으로 부분 완료다. 155 passed, 검토자 돌연변이(첨부 정리)를 잡아냈다.
- **N25-01(비차단):** `Journal.replay`의 치환 대상에서 `edit`를 빼도 시험이 통과한다. 다음을 시험으로 더한다.
  - 지운 스레드에 편집이 있는 상태에서 sync·page 출력에 편집 본문이 없고, 그 seq가 `delete`로 나오는지 확인한다.
  - `edit`를 치환 대상에서 빼는 돌연변이가 이 시험에 걸리는지 확인한다.
  - 시험만 바꾸는 작은 커밋으로 하거나 TASK-26 커밋 앞에 따로 둔다.
- **시험 환경 메모:** `foundation9_runner.py`를 새 worktree에서 돌릴 때는 `.build/task04-resume/python-path`, `.build/task02-deps`, `.build/task03a-deps`가 있어야 한다(없으면 AT-HF-22가 `yaml` 없음으로 실패).
- **다음:** TASK-26(알림 막대·검색·머리줄·작성기, REQ-HF-28, AT-77~79)을 보완 17·21·24 방식으로 진행한다. 끝나면 result로 보고한다.

## 보완 지시 27: N25-01 확인, D26-01 해소 — 26판, TASK-26 재개 (2026-11-16)

- **N25-01(3928fad):** 해소됐다. 편집 본문이 page·sync에서 같은 seq의 `delete`로 나오는 시험이 생겼다. `edit` 치환을 빼는 돌연변이를 잡는다(`.build/task26/mutation-edit.log` 1 failed).
- **D26-01:** ddots `SlackSearch.swift:72~82`는 일치 글 중 최신 200개를 먼저 고르고, 묶은 뒤 구절 일치 묶음을 먼저 보인다. 명세를 원문대로 고쳤다(REQ-HF-28.AC-02).
- **규칙 보강(26판):** 명세가 ddots 동작(한도 단위·정렬·선택 순서·시간값)을 옮긴 문장이 ddots 코드와 다르면 ddots 코드가 이긴다. 원문대로 구현·기록하고 멈추지 않는다. 멈추는 경우는 둘뿐이다.
  - hejo 고유 계약(통신 규격·허브·기록장·Hermes 연동·보안)과 부딪칠 때.
  - 사장이 명시로 고른 차이를 바꿔야 할 때.
- **재개:** 미커밋 copy-review·impl-report 기록을 보존하고 TASK-26의 남은 원본 대조(알림 막대·작성기·유지 의존)부터 이어 전체를 구현·검증한다. 끝나면 result로 보고한다.

## 보완 지시 28: TASK-26 검토 통과 — TASK-29 착수 (2026-11-16)

- **TASK-26(feecf4f):** 완료. 156 passed, 검토자 돌연변이(검색 200개 선택 제거)가 앱 시험에 잡혔다.
- **다음:** TASK-29(펫 알림, REQ-HF-30, AT-81)를 보완 17·21·24·27 방식으로 진행한다.
  - ddots 원본 전체와 의존을 끝까지 읽고 copy-review에 적은 뒤 구현한다.
  - macOS 알림 센터는 쓰지 않는다.
  - ddots 동작은 코드 우선(26판)이다. hejo 고유 계약과 부딪치거나 사장이 고른 차이를 바꿔야 할 때만 멈춘다.
  - 끝나면 별도 커밋 뒤 result로 보고한다.
- **이어서:** 30 → 27 → 21 → 32.

## 보완 지시 29: TASK-29 검토 통과 — TASK-30 착수 (2026-11-16)

- **TASK-29(c437d72):** 완료. 156 passed, 검토자 돌연변이(알림 끈 방 제외 제거)가 앱 시험에 잡혔다.
- **다음:** TASK-30(말풍선에서 바로 답하기, REQ-HF-31, AT-82)을 보완 17·21·24·27 방식으로 진행한다.
  - ddots `BubbleReply` 원본 전체와 의존을 읽고 copy-review에 적은 뒤 구현한다.
  - 문 명부 `queued`는 `display.busy_input_mode`를 읽기만 한다.
  - ddots 동작은 코드 우선(26판)이다.
  - 끝나면 별도 커밋 뒤 result로 보고한다.
- **이어서:** 27 → 21 → 32.
