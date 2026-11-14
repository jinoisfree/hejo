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
