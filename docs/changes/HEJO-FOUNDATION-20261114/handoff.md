# 설계 인계: HEJO-FOUNDATION / TASK-02 문 핵심과 통신 규격 v1

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다(이번 TASK: 문·통신 규격·출입증·기록장 행).

```text
[설계 인계: HEJO-FOUNDATION TASK-02 / 문 핵심과 통신 규격 v1]
0. 기준: base_commit b36c54597bc4ac33ae31d3e308b0e5b85d37a5e5 (hermes-hejo main) / spec·design 초안 2026-11-14 /
   승인 상태: 사용자 계획 승인 대기(계획 검증 켬) / 운영 모드: 연합개발(교차 모델 + 계획 검증)
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-FOUNDATION-20261114/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-FOUNDATION.md. ADR 없음.
2. 요구와 수락 기준: REQ-HF-01~06, NFR-HF-01·02. 핵심: 기본 프로필에서만 리스너 1개, 페어링 코드→출입증(해시 저장·취소),
   루프백·Tailscale 주소만, 직원 목록, 1:1 글(source.profile 찍기), 작성 중·수정, 기록장 seq·sync. 실패: 보조 프로필은 포트를
   묶지 않음, 잘못된 코드·출입증 거부, 기록장 쓰기 실패가 게이트웨이를 멈추지 않음.
3. 유지할 기존 계약: Hermes 본체 무수정(plugin 계약만), Slack 게이트웨이·ddots 무영향, 운영 ~/.hermes 무변경(이 TASK는 운영
   설치 금지), team-kit 무변경.
4. 책임과 흐름: 앱 프레임 → gate/server(주소·인증) → adapter(build_source + source.profile → handle_message) → Hermes 차례 →
   adapter.send/edit/typing → journal(seq, fsync) → 연결된 앱. 직원 목록은 gate/roster(profiles_to_serve + 명부 감지).
5. 기존 경로 판정: 신규 경로. 기존 경로 변경 없음(유지).
6. 위험도: 고위험(네트워크 리스너, 인증·출입증, 기록장 순번 동시성). 필요 증거 수준 2(대역 통합: 실제 Hermes 모듈 + 시험 대역
   러너). 실제 게이트웨이 실행(3)은 TASK-03·09에서. 롤백: 저장소 커밋 되돌림(운영 영향 없음).
7. 변경 성격: 신규 기능(의미 추가). 비교 대상 없음.
8. 수락 시험: tests/acceptance/HEJO-FOUNDATION.md의 AT-HF-01~14. 상태: 명세 완료·코드 미작성·미실행·미검토.
   기대값 출처: spec 요구, design 2절 규격, Hermes 공개 함수 계약(design 근거 경로). 구현 담당이 이 명세를 코드로 옮기며
   기대값·합격 기준은 바꾸지 않는다. AT-HF-02의 "4.1 결정" 부분은 이번 TASK에서 "포트 미점유 + retryable=False 실패"로 시험하고,
   TASK-03 탐침 결과로 전달자 모드가 채택되면 TASK-03에서 갱신한다.
9. 작업 범위: H/schemas/hejo-wire-v1.json(JSON Schema, design 2절 표 전부 포함, 이후 TASK가 쓰는 첨부·버튼 필드도 정의만),
   H/gate/{plugin.yaml,__init__.py,adapter.py,server.py,auth.py,journal.py,roster.py,cli.py}, H/gate/tests/, H/tests/acceptance/
   (AT-HF-01~14 코드), 최소 실행법을 적은 H/gate/README.md.
   금지 범위: 운영 ~/.hermes 쓰기·플러그인 연결·게이트웨이 재시작, Hermes 본체 수정, Hermes-ddots 수정, 앱 코드, 첨부 HTTP·
   Hermes 기본 버튼·보조 프로필 배달(TASK-03), 개인값(실제 직원 id·이름·주소·절대 경로)을 코드·시험에 쓰기.
   선행 작업: 없음(TASK-01 완료). 병렬 갈래: 있음(TASK-02 뒤 문 확장·team-kit·앱·설치검사 4갈래, tasks.md 표). 이번 지시는
   TASK-02 단독.
10. 가정·미확정: 보조 프로필 배달 방식(design 4.1)은 TASK-03 탐침에서 결정 — 이 TASK는 보조 프로필에서 "포트 미점유"만 보장.
    Hermes 허용 사용자 처리(allowed_users_env "HEJO_ALLOWED_USERS", 사용자 id "owner")가 대역 러너에서 기대대로 동작하지 않으면
    멈추고 보고. 착수 차단 없음.
11. 사용자 확인: 브레인스토밍 결정(brainstorm.md) 확정. 이 계획(spec·design·tasks)은 계획 검증 뒤 사용자 승인 필요.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? 예(저장소에 제품 코드 없음, Hermes 본체 HEAD ebb026e 기준 조사).
- G1~G4: G1 요구·범위·AC 연결 있음. G2 근거 경로·대안·기존 경로 판정 있음. G3 AC↔시험 연결, 사전 검토는 계획 검증 대기.
  G4 위험도·롤백·TASK 연결·기준 커밋 있음. 미확정(4.1)은 TASK-03으로 격리.
```

## 구현 메모(설계 범위 안의 자유)

- 테스트는 Hermes venv 파이썬으로 실행한다(본체 모듈 import 필요). 운영 홈을 건드리지 않도록 매 시험에서 임시 `HERMES_HOME`을 만든다. 실행 명령과 종료 코드를 impl-report에 남긴다.
- 대역 러너는 Hermes 시험 도우미 패턴(`~/.hermes/hermes-agent/tests/gateway/_plugin_adapter_loader.py`, `restart_test_helpers.py`, `test_irc_adapter.py`)을 참고한다. 본체 시험 파일을 고치지 않는다.
- 페어링 CLI는 게이트웨이 프로세스 밖에서 실행되므로 코드 발급·취소는 `<HOME>/hejo/` 파일(0600, 원자적 교체, 파일 잠금)로 문과 공유한다. 문은 파일 변경을 감지(최대 1초 지연)해 취소를 반영한다.
