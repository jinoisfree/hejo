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
