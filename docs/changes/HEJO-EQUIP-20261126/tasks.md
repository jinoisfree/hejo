# HEJO-EQUIP 작업

| 단계·TASK | 내용 | 근거 | 위험도·증거 | 상태 |
|---|---|---|---|---|
| 0 | 두 근간 문서·AGENTS 원칙·ADR-0001 반영 | design 2판 | 경미 | 완료(계획 담당 직접): 운영 저장소 `39c2a393`, hejo `6adf608` |
| 1 / TASK-01 | 목록표를 모든 칸 선언에서 생성, 7개 `pack.yaml` 보완, `airport-check` 검사, 실행본 적용(재시작 없음) | [spec.md](spec.md), [handoff.md](handoff.md) | 일반 · 2·3 | 완료(verdict, 운영 `0a2f933d`) |
| 2 / TASK-02 | 명부 `roles` → 출입증 `access`(동작 보존) | [spec-stage2.md](spec-stage2.md), [handoff-stage2.md](handoff-stage2.md) | 고위험 · 2·3 | 완료(운영 `04958c04`) |
| 3 / TASK-03 | 출입증 → 직원 기본 도구 조립(`core_toolsets`, 차이 0) | [spec-stage3.md](spec-stage3.md), [handoff-stage3.md](handoff-stage3.md) | 고위험 · 2·3 | 완료(운영 `9cea8e32`) |
| 4 / TASK-04 | 도구 검색 auto(사장 결정) + 직책 이름 정리(이름만, 사장 결정) | [spec-stage4.md](spec-stage4.md), [handoff-stage4.md](handoff-stage4.md) | 고위험 · 2·3·4 | 완료(운영 `45d987f3`, 기준선 사장 커밋 `08002d59`·`527d350b`). AT-EQ-23 관측 대기 |

## 겹침
- 운영 저장소 팩 이관 작업(판정 보류): 같은 `catalog.json`·`pack_selection.py`를 쓴다. 1단계 착수·적용 때 실행본 해시가 spec 기준과 다르면 멈추고 보고한다. 1단계가 끝나면 그 작업은 새 팩의 `pack.yaml`만 두고 생성기를 돌리면 된다(목록표 손 편집 금지).
- HEJO-REF-PHOTO(실물 관측 대기): 파일 겹침 없음(cctv `pack.yaml`은 이미 목록표와 같음).

## 병렬 갈래
없음(갈래 3개 미만: 생성기 → 선언 보완 → 검사 → 적용이 순서로 이어짐).

## 사용자 위임 (2026-11-27)
- 사용자: "최종까지 개발 진행해". 0~4단계를 끝까지 진행하는 것을 승인했다. 각 단계는 그대로 계획 → 구현 → 검증 순서로 하되, 단계 사이에 다시 승인을 묻지 않는다.
- 유지하는 멈춤 조건: 승인된 범위·계약 밖의 변경이 필요할 때, 3단계의 직원별 도구 범위가 지금과 달라지는 차이 표(사장 결정 사항), 실제 메시지 발송, 푸시(화면 승인). 게이트웨이 재시작은 각 단계 인계서가 정한 한도 안에서 허가된 것으로 본다(적용 1회 + 실패 시 롤백 1회).
