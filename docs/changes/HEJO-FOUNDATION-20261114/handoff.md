# 설계 인계: HEJO-FOUNDATION / TASK-02 문 핵심과 통신 규격 v1

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다(이번 TASK: 문·통신 규격·출입증·문 설정 값·기록장 행).

```text
[설계 인계: HEJO-FOUNDATION TASK-02 / 문 핵심과 통신 규격 v1]
0. 기준: base_commit 1ee8b992dcec825a1f6aa365b8acdce09e6636fd (이 저장소 main) / spec·design·tasks·수락 시험 2판 2026-11-14 /
   승인 상태: 계획 검증 1회차 BLOCKED 반영 후 재검증·사용자 승인 대기 / 운영 모드: 연합개발(교차 모델 + 계획 검증)
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
