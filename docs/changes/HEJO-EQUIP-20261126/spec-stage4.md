# HEJO-EQUIP 4단계 명세(마지막): 도구 검색 자동 + "직책" 이름 정리

- 상태: 1.1판(TASK-04 보류 보고 반영: 호출 범위 확대, `role_hint` 응답 필드 예외) · 2026-11-27 · 근거: 사장 결정(verdict 3단계 절), design.md 2판, ADR-0001
- 작업 유형: (가) 의미 변경(도구 검색 켜기) + (나) 동작 보존 리팩토링(이름 변경) · 위험도: 고위험(재시작, 전체 직원) · 운영 모드: 교차 모델
- 기준: 운영 저장소 `9cea8e323a016d9088b06f547bbe0ada660a3b3d`, 실행본 `team_registry.py` `af63269cc6ab7e48a7c5dfaadf5c058a6a48fa417ccf6ee139dde6daa95343d8`, `owner/policy.yaml` `860beb0d363aea3fe4de8a466b29b7c82345692cdb33a34163eb4e442ddf9919`

## 0. 칸·원본·쓰기 주체·수명
| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 도구 검색 켜기 결정 | 사장 지시서 | `owner/policy.yaml` `tools.tool_search.enabled`(값 `auto`, 직원 공통) | 사장(위임으로 대리 기록) | 영구 |
| 직원 설정의 `tools.tool_search.enabled` | 조립 결과 | 직원 `config.yaml` — `hermes-config-assemble`이 지시서 값으로 씀 | 조립기 | 다시 생성 |
| 출입증 질문 함수 | 공항 시설 | `hermes_facility/team_registry.py` | 개발 | 갱신 때 교체 |

## 1. 요구와 수락 기준
### REQ-EQ-04 도구 검색은 사장 지시서 값 하나로 켜진다
- AC-21 `hermes-config-assemble`이 지시서 `tools.tool_search.enabled`를 6명 직원 설정에 쓴다. 지시서에 값이 없으면 직원 설정을 건드리지 않는다. `--check`는 이 값도 검사하고, airport-check가 어긋남을 잡는다.
- AC-22(운영) 지시서에 `auto`를 쓰고 조립기 `--write`로 6명 설정에 반영한다. 바뀌는 키는 `tools.tool_search.enabled` 하나뿐이다(파싱 비교). 재시작 1회 뒤 연결 수가 같고, 기준 밖 새 오류가 없다(REF-PHOTO AT-RP-15 4판 기준).
- AC-23(관측) 재시작 뒤 `gateway.log`·`agent.log`에서, 도구 설명이 문턱을 넘는 직원의 첫 턴에 `Tool Search (tier` 줄이 나타난다. 그 뒤 그 직원의 `tool_search` 또는 `tool_call` 호출이 오류 없이 끝난다. 자연 대화가 생길 때까지는 "관측 대기"다. 메시지를 대신 보내지 않는다.

### REQ-EQ-05 코드에서 "직책" 이름이 사라진다
- AC-24 `team_registry`의 공개 함수와 상수를 출입증 이름으로 바꾼다: `has_role`→`has_access`, `roles_of`→`access_of`, `home_of_role`→`home_of_access`, `home_has_role`→`home_has_access`, `role_hint`→`access_hint`, `ROLES`→`ACCESS`. `agents_with`·`first_with`는 유지한다. 모든 호출자(team-kit·team-delegation·조립기·설치기·airport-check·시험, 그리고 정비 격납고 `mini-maintenance`와 직원 플러그인 Instagram DM 감시기)를 같은 변경에서 바꾼다. 옛 이름의 별칭은 두지 않는다(이중 경로 금지).
- AC-25 검색 `grep -rnw "has_role\|roles_of\|home_of_role\|home_has_role\|role_hint\|ROLES"`(team-kit·team-delegation·bin·starter-templates·airport-check, 기록·변경 문서 제외)가 0건이다. 팩 선언의 서비스 이름 `role_roster`는 계약 이름이라 유지한다(근거: 칸 선언 `requires.services` 값, 바꾸면 목록표가 바뀜). 앱 연결·`mac_apps` 조회가 hejo 문으로 내보내는 응답 필드 `role_hint`도 문↔team-kit 계약(운영 문의 허용 목록)이라 이름을 유지한다. 함수 `role_hint`만 `access_hint`로 바꾸고, 그 함수가 채우는 응답 키는 그대로 `role_hint`다. 검색 예외는 이 두 이름(서비스 `role_roster`, 응답 키 문자열 `"role_hint"`)뿐이다.
- AC-26(동작 보존) 2단계 AT-EQ-10 탐침을 새 이름으로 다시 돌린 결과가 2단계 적용 뒤 기준과 같다. 등록 덤프는 도구 이름·스키마가 같다(도구 검색은 어떤 도구를 미루는지만 바꾸고 등록은 바꾸지 않는다). 전체 시험 후보 전용 실패 0. `make-starter --check` 종료 0.

## 2. 범위
- 안: 위 코드·조립기·설치기·시험·airport-check, `mini-maintenance`(정비 격납고 실행 위치가 원본, `./sync`가 모음)와 직원 플러그인 Instagram DM 감시기의 호출(보관·롤백 목록 포함), 지시서 값, 직원 설정 6개(조립기로만), 근간 문서의 "이행 중 직책 키" 문구 제거, 재시작 1회.
- 밖: 출입증 세분화(사장 결정으로 제외), photon·cron 목록, `packs.enabled` 조립.

## 3. 롤백
지시서·직원 설정 6개·바꾼 실행본을 0700 폴더에 보관한다(값 출력 없음, sha256 기록). 실패하면 전부 복원 → 재시작 1회 → 탐침·등록 덤프·`--check`가 적용 전과 같은지 확인한다.

## 4. 증거 수준
AC-21·24·25 = 2, AC-22·26 = 3, AC-23 = 4(자연 대화 관측).

## 5. 완료 뒤
작업 전체의 마지막 단계다. 검증 뒤 현재 명세 반영(두 근간의 "이행 중" 문구 정리 확인)을 하고, 푸시 승인을 한꺼번에 받는다.
