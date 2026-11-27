# HEJO-EQUIP 2단계 명세: 명부의 직책을 출입증으로

- 상태: 1.1판(AC-07 혼합 항목 판정 정합화) · 2026-11-27 · 근거 [design.md 2판](design.md) 6절 2단계, [ADR-0001](../../decisions/ADR-0001-staff-access-pass.md), 사용자 위임([tasks.md](tasks.md))
- 작업 유형: 동작 보존 리팩토링(저장 형식 변경) · 위험도: 고위험(권한 판정의 입력, 사장 칸 이관) · 운영 모드: 교차 모델
- 기준: 운영 저장소 `9e208f776110865caaf5f8db860b20545a850ded`, 실행본 `team_registry.py` `42b7cef63ac0afe3ca622be4d6202fac6286c296ad35d982713095593a8dee60`, `owner/team.yaml` `09a0ba0f1bc500e19e7e8a26f8c72bffb6b14ab40a61470c52eacc8f882d1a21`, `owner/policy.yaml` `9f2d4faac2d8f9b16eb406cf56144a470836d1e13b8bc6dcb455a8f9e23e1909`

## 0. 칸·원본·쓰기 주체·수명
| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 출입증(직원별 창고 칸 목록) | 직원 명부 | `owner/team.yaml` 직원별 `access`(기존 `roles` 대체) | 사장(이번 이관은 사용자 위임으로 구현 담당이 대리 기록) | 영구 |
| 멘션 없는 새 글의 기본 담당 | 사장 지시서 | `owner/policy.yaml` `routing.default_responder`(직원 id 하나) | 사장(같은 대리 기록) | 영구 |
| 명부 읽기 | 공항 시설 | `hermes_facility/team_registry.py` 한 곳 | 개발 | 갱신 때 교체 |
| 공개판 설치기의 명부 쓰기 | 정비 격납고(공개 틀) | 운영 저장소 `starter-templates/install_support.py`·`installation.json` | 개발 | 갱신 때 교체 |

점검표: 출입증과 기본 담당의 원본은 하나씩이다. 옛 `roles` 키는 이관 뒤 남기지 않는다(두 번째 원본 금지). 코드·시험에 실제 직원 id 없음. 다른 사장의 공항도 설치기가 `access`로 쓴다.

## 1. 현황 [확인] 2026-11-27
1. 명부 `roles`는 칸 이름 personal·work·doctor·wiki·customers·sns·standby와 경로 결정 responder를 함께 담는다(`team_registry.ROLES`).
2. 명부 읽기는 `team_registry` 말고도 7곳이 더 한다. `hermes_router/owner_contract.py`(responder), `hermes_schedule/catalog.py`, `hermes_team_services/{file_drop_review,file_drop_suggest,work_metrics}.py`, `hermes_governance/app_undo.py`, `hermes_facility/app_registry.py`. 조립기 `~/.hermes/bin/hermes-skill-assemble` 107행도 `roles`를 읽고, `hermes-soul-assemble`은 명부를 읽는다.
3. 명부에 쓰는 곳: `app_connect.py`(앱 연결 때 `apps` 갱신, 다른 키 보존), 공개판 설치기(`install_support.py` 480행이 `roles`로 씀).
4. 시험 58개 파일이 `roles`를 쓴다.
5. hejo 앱·문·허브는 `roles`를 읽지 않는다.

## 2. 요구와 수락 기준
### REQ-EQ-02 명부는 출입증만 담고, 모든 읽기는 한 곳을 거친다
- AC-07 `team_registry`는 직원별 `access`를 읽는다. 옛 `roles` 키가 있는 항목은 출입증이 없는 것으로 본다(닫힘 실패). `access`가 함께 있어도 같다(혼합 항목도 출입증 0. 1회 정합화, TASK-02 보류 보고 반영). 경고를 한 번 남기고, `airport-check`가 실패한다.
- AC-08 기본 담당은 지시서 `routing.default_responder`에서 읽는다. 기존 질문 `has_role(x,'responder')`·`first_with('responder')` 같은 답은 이 값으로 같게 낸다. 값이 없거나 명부에 없는 id면 기존 `default_responder`의 대체 순서(default → 첫 직원)를 그대로 따른다.
- AC-09 1절 2·3의 직접 읽기·쓰기 곳이 모두 `team_registry`(읽기)나 `access`(쓰기)를 쓴다. 검색 `grep -rn "roles" <명부를 읽는 코드>`의 남은 줄은 근거와 함께 impl-report에 목록으로 남긴다(칸 이름 상수 `ROLES` 이름 정리는 4단계로 미룸).
- AC-10(동작 보존, 핵심) 모든 직원 × 모든 칸 이름(+responder)에 대해 `has_role`·`first_with`·`agents_with`·`roles_of`·`home_of_role`·`home_has_role`·`role_hint`, `owner_contract.default_responder`, `app_registry`의 직원별 결과가 이관 전후 같다. 실행본 기준 새 프로세스 탐침으로 비교한다.
- AC-11(동작 보존) 6개 직원 등록 덤프가 재시작 전후 같다. 조립기 3개 `--check`가 이관 전후 차이 0이다.
- AC-12(시험) 58개 파일의 가짜 명부를 `access`(+필요 시 가짜 지시서 `routing.default_responder`)로 옮긴다. team-kit·team-delegation 전체의 실패 노드 집합이 기준과 같거나 줄었다. 옛 `roles` 키를 넣은 가짜 명부는 출입증 0으로 읽힌다는 새 시험이 있다.
- AC-13(설치기) 공개판 설치기는 `access`와 `routing.default_responder`로 쓴다. `make-starter --target hermes-hejo-p --check` 종료 0.
- AC-14(운영) 운영 `owner/team.yaml`에서 `roles` → `access`(responder 제외 값 그대로), responder 담당 id → `owner/policy.yaml` `routing.default_responder`로 옮긴다. 다른 키·주석·순서는 보존한다. 적용 뒤 게이트웨이 재시작 1회, hejo·Slack·photon 연결 수 동일, 새 오류 줄은 기준 문장(REF-PHOTO AT-RP-15 4판 방식)뿐이다.

## 3. 범위
- 안: 위 코드·조립기·설치기·시험, 운영 명부·지시서 이관, 1단계 V-1 시험 반영, 근간 문서의 "이행 2단계 전까지는 기존 `roles` 키" 문구 정리.
- 밖: 직원 설정 조립·기본 도구(3단계), 코드의 칸 질문 함수 이름 변경(4단계), hejo 앱·문.

## 4. 롤백
적용 전 실행본(바꾼 코드·조립기)과 `owner/team.yaml`·`owner/policy.yaml`을 0700 폴더에 보관한다(내용은 출력하지 않음, sha256만 기록). 실패하면 전부 복원 → 재시작 1회 → AC-10 탐침이 적용 전과 같은지 확인한다.

## 5. 증거 수준
AC-07~09·12·13 = 2, AC-10·11·14 = 3.
