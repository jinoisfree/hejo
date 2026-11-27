## 검증 판정: HEJO-EQUIP 1단계 TASK-01 (2026-11-27)

1. 판정: **완료(비차단 1건 이월)**. 다음 단계로 진행한다.
2. 검증 조건: 교차 모델(구현 codex, 검증 이 대화). 검토 대상: 작업 트리 후보 `3e2c9f8c`, 운영 저장소 main `0a2f933da9421f608f9fb86baf7ef1dc1bd90454`, team-kit 실행본.
3. 설계 적합성(4.2): 목록표의 원본이 칸 선언 하나로 줄었고(REQ-EQ-01), 어긋나면 기계 검사가 잡는다. 근간 2판 4절과 맞다.
4. 직접 확인한 것(게이트웨이 Python)
   - 실행본 `generate_catalog()` 출력 = 실행본 `catalog.json`(바이트 동일).
   - 기준 `39c2a393`의 목록표와 실행본 목록표의 `packs` JSON 값이 12개 모두 같다. 차이 0, `version` 1 동일(AT-EQ-02). diagnosis `requires.services`는 목록표 값 `source_adapters`로 정했고, 그 값을 읽어 동작을 정하는 소비자가 없다는 구현 근거를 수용한다(AT-EQ-03).
   - 운영 저장소 기본 `./airport-check` 종료 0, 새 `PASS pack-catalog count=0` 포함.
   - 작업 트리 `pytest tests/test_pack_selection.py tests/test_pack_contracts.py`: 7 passed.
   - 운영 커밋 파일 12개 = 바꾼 미러 9개 + `airport-check` + 근간 1줄 + 운영 기록(`git show --stat`). 재시작 0회.
5. 지적
   - V-1(비차단): AT-EQ-01 새 시험(`tests/test_pack_selection.py`의 `test_generated_catalog_uses_every_declaration_and_ignores_stale_output`)이 작업 트리 커밋에만 있고 실행본·운영 저장소에는 없다. 처분: 2단계 TASK-02의 첫 단계로 실행본에 반영한다(handoff-stage2 9번).
6. 미검증 범위: 없음(1단계 범위).

---

## 2단계 TASK-02 착수 보류 처리 (2026-11-27)
- 구현 담당 지적: spec-stage2 AC-07(옛 키 있으면 출입증 0)과 AT-EQ-07 (다)(혼합이면 `access` 사용)가 충돌한다. 확인 결과 맞다. 원인은 수락 시험 오류다(계획 담당 작성).
- 처분: 닫힘 쪽으로 정합화했다. `roles` 키가 남은 항목은 `access`가 있어도 출입증 0이고, 경고와 airport-check 실패를 낸다(spec 1.1판, 시험 명세 수정). 권한 판정 입력은 모호하면 닫는 쪽이 원칙(공통 4절 고위험)이다.
- 구현 담당의 준비 결과(기준 해시 3개 일치, AT-EQ-10 이관 전 탐침, V-1 시험 작업 트리 반영, `app_connect`의 `access` 보존 확인)는 그대로 이어 쓴다.

---

## 검증 판정: HEJO-EQUIP 2단계 TASK-02 (2026-11-27)
1. 판정: **완료**. 다음 단계로 진행한다.
2. 검증 조건: 교차 모델. 대상: 운영 저장소 main `04958c04a3eb0cf7c05465dff809a673e557a3ac`(55개 경로), 실행본, 운영 명부·지시서(구조만, 값 출력 없음).
3. 설계 적합성: 명부는 출입증만 담고, 기본 담당은 지시서에, 읽기는 `team_registry` 한 곳을 거친다(REQ-EQ-02). 혼합·옛 키는 닫힌다.
4. 직접 확인(게이트웨이 Python)
   - 운영 명부: `roles` 키 0, `access` 6명 전원. 각 직원 `access` = 이관 전(`9e208f77` 미러) `roles` − responder. 이관 전 responder 보유자 = 지시서 `routing.default_responder`, `team_registry.first_with('responder')`와 같다.
   - 기본 `./airport-check` 종료 0, `PASS roster-access`, 조립기 3종 PASS.
   - 재시작(09:57) 뒤 연결 줄 13개(hejo 6·Slack 6·photon 1). 새 오류 문장은 기준 문장(종료 맥락·`hejo_primary_unavailable`·텔레그램 비활성)뿐이다.
   - 구현 보고의 AT-EQ-10 탐침 9구획·등록 덤프 6개 동일, 전체 시험 후보 전용 실패 0을 로그 근거로 수용한다.
5. 지적: 비차단 V-2. 공개 설치 시험 14개가 임시 Hermes Python 부재로 실패했다(환경). 같은 범위를 준비된 임시 홈 101 passed와 `make-starter --check` 종료 0이 덮는다. 기록만 하고, 3단계 구현 때 같은 환경 준비로 다시 돌린다.
6. 푸시: 운영 저장소 커밋 `0a2f933d`·`04958c04` 등은 원격 미반영이며, 마지막에 한꺼번에 승인받는다.

---

## 검증 판정: HEJO-EQUIP 3단계 TASK-03 (2026-11-27)
1. 판정: **완료**.
2. 대상: 운영 저장소 main `9cea8e323a016d9088b06f547bbe0ada660a3b3d`(18개 경로), 실행본.
3. 설계 적합성: 직원 기본 도구의 원본이 칸 선언(`roles/<칸>/guide.yaml`, `pack.yaml` `core_toolsets`)이 됐고, 직원 설정은 조립 결과로 검사된다(REQ-EQ-03).
4. 직접 확인: 실행본 `hermes-config-assemble --check` → `{"checked": 6, "differences": []}` 종료 0. `roles/*/guide.yaml` 6개. 기본 `./airport-check` 종료 0, `PASS assembly:hermes-config-assemble`. 직원 `config.yaml` 6개의 수정 시각이 모두 작업 이전이다(쓰기 0). 재시작 0. 2단계 V-2 설치 시험 14개 포함 공개 설치·런타임 46 passed(구현 로그)를 수용해 V-2를 닫는다.
5. 지적: 없음.

## 사장 결정 (2026-11-27)
- 도구 검색: **자동(auto)**. 6명 모두 켠다. 재시작 1회가 필요하다.
- 4단계 범위: **이름만 정리**. 코드의 직책 질문 함수를 출입증 이름으로 바꾸고 동작은 보존한다. 출입증 세분화는 하지 않는다.

## 4단계 TASK-04 보류 처리 (2026-11-27)
- 구현 담당 지적 두 가지를 수용한다(원인: 설계 누락). (1) `mini-maintenance`와 직원 플러그인 Instagram DM 감시기가 옛 함수를 부른다. (2) `role_hint`는 hejo 문 허용 목록에 있는 응답 필드다.
- 처분: spec-stage4 1.1판·handoff 보완 1회·AT-EQ-24·25를 고쳤다. 함수 `role_hint`→`access_hint`, 응답 키 `role_hint`는 유지, 검색 예외는 `role_roster`·`"role_hint"`뿐이다.
- 이미 만든 도구 검색 조립(시험 20 passed, 운영 읽기 전용 --check 6명 차이 0)은 이어 쓴다.

---

## 검증 판정: HEJO-EQUIP 4단계 TASK-04 · 작업 최종 (2026-11-27)
1. 판정: **완료(도구 검색 실제 대화 관측 AT-EQ-23만 관측 대기)**. 고위험 작업 중 수준 4 증거는 AT-EQ-23 하나만 남았다. 이것은 사장의 자연 대화에 달려 있어 작업 완료 판정을 막지 않는 관측 항목으로 둔다(사용자 위임의 멈춤 조건에 해당하지 않음).
2. 대상: 운영 저장소 main `45d987f33b2263aa5c979b259ded96e58372c6e4`(121개 경로, 부모 `527d350b`), 실행본.
3. 설계 적합성: REQ-EQ-04(도구 검색은 지시서 값 하나), REQ-EQ-05(직책 이름 제거)를 충족한다. 근간 2판의 원칙 문장과 실제 구조가 일치한다.
4. 직접 확인: 지시서와 직원 설정 6개 모두 `tool_search` = `auto`. 옛 함수·상수 이름 검색 0건(응답 키 `"role_hint"` 제외). `hermes-config-assemble --check` 6명 차이 0. 기본 `./airport-check` FAIL 0. 재시작 뒤 연결 13개. 구현 보고의 AT-EQ-22·26 증거(지정 키만 변경, 탐침 9구획·등록 덤프 6개 동일, 커밋 훅 snapshot PASS)를 로그 근거로 수용한다.
5. 기준선: 사장 커밋 `08002d59`(--rebaseline이 snapshot 전용 32개를 함께 지움)는 `527d350b`(이전 기준선 − 옛 지문 12 + 새 지문 12, 113개)로 정정됐다. 정정본은 계획 담당 검증본과 바이트가 같다.
6. 현재 명세 반영: `docs/spec/current/staff-access.md` 작성, ADR-0001 결과 갱신, design.md 상태 "적용".
7. 남은 것: AT-EQ-23 관측(도구 검색이 문턱을 넘는 직원의 실제 대화에서 `Tool Search (tier` 줄과 오류 없는 `tool_search`/`tool_call`), 푸시 승인.
