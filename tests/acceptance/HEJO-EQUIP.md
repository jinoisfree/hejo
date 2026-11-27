# HEJO-EQUIP 수락 시험 명세(1단계)

- 대상: [spec](../../docs/changes/HEJO-EQUIP-20261126/spec.md) 1판. 상태: 명세 / 코드 미작성 / 미실행.
- 조건: 생성·검사 시험은 team-kit 작업 트리 사본에서. AT-EQ-06만 실행본을 읽기 전용으로 본다.

| 시험 | AC | 입력 | 합격 기준 |
|---|---|---|---|
| AT-EQ-01 | AC-01 | 가짜 `hermes_packs`(선언 2개 + 선언 없는 옛 항목 1개가 든 목록표) | 생성 결과에 선언 2개만 있음 |
| AT-EQ-02 | AC-02 | 기준 목록표 사본, 1단계 뒤 생성 결과 | JSON 비교에서 `packs` 키·값 모두 같음(diagnosis `requires.services`만 AT-EQ-03 판정대로) |
| AT-EQ-03 | AC-03 | `requires.services` 소비자 검색 결과(파일:줄) | 정한 값과 근거가 impl-report에 있음. 소비자가 두 값을 다르게 읽으면 멈춤 보고 |
| AT-EQ-04 | AC-04 | 7개 `pack.yaml` | 각 `tools` = 기준 목록표의 같은 팩 `tools`(순서 포함) |
| AT-EQ-05 | AC-05 | (가) 그대로 (나) `pack.yaml` 하나에서 도구 하나 삭제한 사본 (다) 목록표를 손으로 고친 사본 | (가) 검사 통과 (나)(다) 검사 실패 |
| AT-EQ-06 | AC-06 | 적용 전후 6개 직원 등록 덤프, team-kit 전체 시험 기준·후보 | 덤프 동일. 후보에만 있는 실패 노드 0 |

## 2단계

| 시험 | AC | 입력 | 합격 기준 |
|---|---|---|---|
| AT-EQ-07 | AC-07 | 가짜 명부 (가) `access: [work]` (나) `roles: [work]`만 (다) 둘 다 | (가) `has_role(x,'work')` 참 (나) 출입증 0, 경고 1회, airport-check 실패 (다) 출입증 0(옛 키가 남은 항목은 `access`가 있어도 닫힘), 경고 1회, airport-check 실패 |
| AT-EQ-08 | AC-08 | 가짜 지시서 `routing.default_responder` = 명부 직원 / 없음 / 명부에 없는 id | 첫째는 그 직원이 기본 담당. 나머지는 기존 대체 순서(default → 첫 직원) |
| AT-EQ-09 | AC-09 | 1절 2·3의 파일 목록 검색 | 명부 `roles`를 직접 읽는 줄 0(남은 줄은 근거 목록) |
| AT-EQ-10 | AC-10 | 이관 전후 실행본 새 프로세스 탐침(직원 × 칸 이름 × 함수 7개 + `default_responder` + `app_registry`) | 결과 JSON 동일 |
| AT-EQ-11 | AC-11 | 등록 덤프 6개, 조립기 3개 `--check` | 덤프 동일, 조립 차이 0 |
| AT-EQ-12 | AC-12 | 기준·후보 team-kit·team-delegation 전체 | 후보에만 있는 실패 노드 0, AT-EQ-07 새 시험 포함 |
| AT-EQ-13 | AC-13 | `make-starter --target hermes-hejo-p --check` | 종료 0, 생성 틀의 명부에 `roles` 없음 |
| AT-EQ-14 | AC-14 | 운영 명부·지시서 이관 전후(파싱 비교, 내용 출력 없음), 재시작 전후 로그 | `roles` 0개, `access` 값 = 기존 roles − responder, 기본 담당 id 동일, 연결 수 동일, 기준 밖 새 오류 0 |

## 3단계

| 시험 | AC | 입력 | 합격 기준 |
|---|---|---|---|
| AT-EQ-15 | AC-15 | 선언 파일 6개 + `pack.yaml` `core_toolsets` | 칸별 합이 spec-stage3 1절 표와 같음(집합) |
| AT-EQ-16 | AC-16 | 가짜 홈: 출입증 [work], slack 목록에 플러그인 2개 + 기본 도구 일부·여분 1개 | 기본 도구 = 선언 합, 플러그인 자리·순서 보존, 여분 제거, hejo 복사 일치. 선언 없는 칸 이름이면 오류 |
| AT-EQ-17 | AC-17 | 실행본 `hermes-config-assemble --check`(6명) | 차이 0. 아니면 쓰기 0, 차이 표 보고 후 멈춤 |
| AT-EQ-18 | AC-18 | (가) 그대로 (나) 선언 사본에서 도구 1개 삭제 (다) 직원 설정 사본에서 기본 도구 1개 추가 | (가) PASS (나)(다) FAIL |
| AT-EQ-19 | AC-19 | 적용 전후 photon·cron·cli 목록, `tools.tool_search`, 전체 시험, 설치 시험 14개 | 값 동일, 후보 전용 실패 0, 설치 시험 통과(또는 원인 보고) |
| AT-EQ-20 | AC-20 | `make-starter --target hermes-hejo-p --check` | 종료 0 |

## 4단계

| 시험 | AC | 입력 | 합격 기준 |
|---|---|---|---|
| AT-EQ-21 | AC-21 | 가짜 홈 지시서 (가) `auto` (나) 값 없음 (다) 직원 설정만 손으로 `off`로 바꾼 사본 | (가) 직원 설정 6개에 `auto` (나) 직원 설정 불변 (다) `--check`와 airport-check 실패 |
| AT-EQ-22 | AC-22 | 운영 적용 전후 직원 설정 6개 파싱 비교, 재시작 전후 로그 | 바뀐 키 = `tools.tool_search.enabled` 하나. 연결 수 동일, 기준 밖 새 오류 0 |
| AT-EQ-23 | AC-23 | 재시작 뒤 자연 대화의 `gateway.log`·`agent.log` | 문턱을 넘는 직원의 `Tool Search (tier` 줄, 이후 `tool_search`/`tool_call` 오류 없음. 대화 전이면 관측 대기 |
| AT-EQ-24·25 | AC-24·25 | 이름 검색(mini-maintenance·직원 플러그인 포함) | 옛 함수·상수 이름 0건. 예외는 서비스 `role_roster`와 응답 키 문자열 `"role_hint"`뿐. 응답 키는 기존 문 허용 목록과 같음 |
| AT-EQ-26 | AC-26 | 새 이름 탐침 vs 2단계 적용 뒤 기준, 등록 덤프, 전체 시험, make-starter | 탐침 동일, 도구 이름·스키마 동일, 후보 전용 실패 0, make-starter 종료 0 |
