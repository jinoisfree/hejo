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
