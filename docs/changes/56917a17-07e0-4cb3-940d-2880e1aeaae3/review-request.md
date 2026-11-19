# 비설계자 검토 요청 (2026-11-18)

규칙 30-verification 2절·5.2에 따른 고위험 작업의 독립 검토다. 이 작업의 설계(계획 담당)와 구현(실행 담당)에 참여하지 않은 **새 세션**이 맡는다. 이전 대화 내용은 보지 않는다. 설계 문서·인계 보고·실제 코드만 읽는다.

## 대상

- 저장소: 이 저장소 `main`. 공개본 v0.2.0과 같은 트리 `1886a991`이며, 운영 서버에 0.2.0으로 반영된 코드다.
- 고위험 TASK(근거 `docs/changes/HEJO-FOUNDATION-20261114/tasks.md` 위험 칸):

| TASK | 내용 | 주로 볼 곳 |
|---|---|---|
| TASK-20 | 직원 사진·색·사이드바 배치, 사진 PUT/DELETE | `gate/`(사진·명부), `app/Sources/` 사이드바 |
| TASK-21 | 단체방: 기록장·전달(@/대표)·방송·삭제(room_delete) | `gate/`(journal·room), `schemas/hejo-wire-v1.json` |
| TASK-22 | 설치 도우미의 홈 채널 자동 설정·되돌림 | `install/hejo-install` |
| TASK-24 | 회원 상태 동기화(항목별 LWW·읽음 seq·대기) | `hub/state.py`, `hub/server.py`, 앱 `MemberState` |
| TASK-25 | 스레드 분기·삭제(thread_delete)·중지·되돌리기 | `gate/`, 앱 스레드 카드 |
| TASK-32 | 직원별 도구 연결, 비밀값 공식 경로 쓰기·보상 | `gate/`(도구 연결), `install/hejo-admin`, `install/admin_support.py` |
| TASK-33 | 앱 자동 업데이트(Sparkle), `install/hejo-ship` | `app/Sources/Update*.swift`, `install/hejo-ship` |

## 읽을 문서

- `docs/ARCHITECTURE.md`(근간), `docs/spec/current/`(요구·수락 시험), `docs/changes/HEJO-FOUNDATION-20261114/design.md`, `spec.md`
- 결정·보완: 같은 폴더 `handoff.md`(보완 지시들)·`impl-report.md`
- 계획 담당 판정: `docs/changes/56917a17-07e0-4cb3-940d-2880e1aeaae3/verdict.md`. 계획 담당이 무엇을 놓쳤는지 보는 데 쓰고, 그 결론을 기준으로 삼지 않는다.

## 볼 것(설계 결함 위주)

1. **인증·권한:** 출입증·허브 토큰·관리 토큰 검사 우회, 다른 직원·다른 회원의 글·사진·방·상태 접근.
2. **영구 저장:** 기록장 쓰기 잠금·실패 되돌림, seq 빈칸·중복, 삭제 확정점(room_delete·thread_delete)이 중간에 끊긴 경우.
3. **동시성:** 허브 상태 대기·PATCH 경합, 같은 기록에 두 쓰기.
4. **운영 설정 복구:** `hejo-install`의 영수증·되돌림이 사장 값을 지우거나 덮지 않는지(`--uninstall-home-channel` 포함).
5. **비밀값:** 비밀값이 로그·기록·응답·영수증에 남지 않는지, 보상 실패 공개(write_partial).
6. **업데이트:** 서명 검증 우회, 다른 저장소·태그 릴리스 수락, 하위 버전 설치.
7. **명세와 코드의 어긋남:** 요구의 수락 기준을 코드가 실제로 만족하는지, 시험이 그 기준을 실제로 잡는지(약한 단언).

## 지킬 것

- 읽기 전용이다. 코드·문서·운영 서버(`~/.hermes`)를 바꾸지 않는다. Hermes 본체·`<운영 저장소>/ddots`도 건드리지 않는다.
- `~/.hermes` 비밀 파일(`.env`, `auth.json`, 토큰 파일, `admin.json`)과 실제 `~/.codex`·`~/.claude` 설정을 열지 않는다.
- GitHub에 쓰지 않는다. 실제 Slack·고객 메시지를 보내지 않는다.
- 시험을 돌리려면 임시 `HERMES_HOME`과 가짜 명부만 쓴다.

## 결과 형식

`docs/changes/56917a17-07e0-4cb3-940d-2880e1aeaae3/independent-review.md`에 쓴다(이 파일 하나만 만든다). 커밋은 하지 않는다.

- 지적마다: ID(IR-01…), 심각도(차단·비차단), TASK, 파일:줄, 실제 실패 시나리오(입력·상태 → 잘못된 결과), 근거(코드 인용 또는 실행 결과).
- 확인했지만 문제없는 항목은 한 줄씩 적는다(무엇을 어떻게 봤는지).
- 마지막에 TASK별 결론: 통과 / 지적 있음.

## 추가 범위 (2026-11-20)

- **문(gate) 최근 변경:** 사장 원문·직원 글 공개 조회 `owner_message`·`employee_message`, 수신 `source.message_id`, 보조 문 post-delivery 콜백, 차례별 삭제 범위 `_delivery_scope`(`gate/adapter.py`, 커밋 `5fb0407`·`8de89b9`·`518d67f`·`d5c9133`, 시험 `gate/tests/test_owner_query.py`·`test_employee_query.py`·`test_progress.py`·`test_gateway_progress.py`).
- **team-kit 패치(운영 저장소 코드, 이 저장소 밖):** `.build/task50/team-kit.patch` → `.build/task52/team-kit.patch` → `.build/task53/team-kit.patch` → `.build/n52-02/team-kit.patch` 순서. 결정 근거는 `handoff.md` 보완 62~67, D50-01·D51-01. 실제 적용된 코드는 `~/.hermes/plugin-store/team-kit`(읽기만). 볼 것: hejo 대화를 사장 대화로 인정하면서 배경·예약 거절이 유지되는지, 원문·세션 증명이 가짜 글·다른 방·다른 세션으로 뚫리지 않는지, 대기 작업 결과가 다른 곳으로 새지 않는지.
- 결과 파일은 검토자별로 `independent-review-<영역>.md`를 써도 된다.
