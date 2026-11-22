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
