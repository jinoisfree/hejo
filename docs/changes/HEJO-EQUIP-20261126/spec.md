# HEJO-EQUIP 1단계 명세: 도구 목록의 원본을 칸 선언 하나로

- 상태: 1판 · 2026-11-27 · 근거 [design.md 2판](design.md) 6절 1단계, [ADR-0001](../../decisions/ADR-0001-staff-access-pass.md)
- 작업 유형: 동작 보존 리팩토링 · 위험도: 일반(도구 등록 필터의 입력 파일을 바꾸지만 내용은 같음) · 운영 모드: 교차 모델
- 기준: 운영 저장소 `39c2a393898232ab5d4739a4377b2829cc8301aa`, team-kit 실행본 `catalog.json` sha256 `723087d9f2fe57ff2c4e26149037b205aeb6917d4921e12d1549b26d4f0d6c60`, `pack_selection.py` `07841ef64f11bdcbaed72a05689d177f89ec23cc3ecd229cfe5247c2c90760b6`, 운영 저장소 `airport-check` `83c910cded238337e95dd3ebdb84dec8d60f8c717fac6dcef90a594af55ee742`

## 0. 칸·원본·쓰기 주체·수명
| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 칸의 도구 목록·필요 서비스 등 선언 | 도구 창고 | `<HOME>/plugin-store/team-kit/lib/hermes_packs/<칸>/pack.yaml` | 개발 | 갱신 때 교체 |
| 도구 목록표 | 조립 결과 | `lib/hermes_packs/catalog.json`(생성기 출력) | 생성기 `pack_selection.generate_catalog()` | 다시 생성 |
| 목록표가 생성 결과와 같은지 검사 | 정비 격납고 | 운영 저장소 `airport-check` 기계 검사 | 운영자 | 갱신 때 교체 |

점검표: 두 번째 원본을 없앤다(목록표는 생성 결과). 사장 칸은 건드리지 않는다. 코드·시험에 개인값 없음. 다른 사장의 공항에서도 같은 생성 규칙.

## 1. 현황 [확인] 2026-11-27
1. 팩 12개 모두 `pack.yaml`과 목록표에 같은 id로 있다. 5개(calendar, cctv, files-docs, mac-apps, mail)는 내용이 같다.
2. 7개는 `pack.yaml`에 `tools`가 없다(diagnosis, ego-browser, linked-work, native-tools, notes, notion, sns). diagnosis는 `requires.services`도 다르다(`pack.yaml` `host_bridge`, 목록표 `source_adapters`).
3. `generate_catalog()`(`pack_selection.py` 69-80행)는 `safety.workspace_commands == host_typed_approval_and_binding`인 팩만 갱신하고, 나머지는 기존 목록표 값을 남긴다.
4. 도구 등록 필터 `PackContext.register_tool`은 목록표만 읽는다. 시험 `tests/google_disconnect/test_native_workspace.py`의 `test_catalog_is_generated_from_changed_pack_declarations`가 "목록표 = 생성기 출력"을 확인한다.
5. 운영 저장소의 팩 이관 작업(판정 보류)은 새 팩(instagram, naver_talk)을 목록표에 더할 예정이었다.

## 2. 요구와 수락 기준
### REQ-EQ-01 목록표는 모든 칸 선언에서 생성된다
- AC-01 `generate_catalog()`가 `hermes_packs/*/pack.yaml` 전부를 읽어 목록표 전체를 만든다. 선언이 없는 팩의 옛 항목을 남기지 않는다.
- AC-02(동작 보존) 1단계 뒤 생성한 목록표를 JSON으로 읽으면 기준 목록표(sha256 `723087d9f2fe57ff2c4e26149037b205aeb6917d4921e12d1549b26d4f0d6c60`)와 `packs`의 키·값이 모두 같다. 다만 diagnosis `requires.services`는 AC-03 판정을 따른다. 바이트 차이(키 순서·공백)는 허용한다.
- AC-03 diagnosis `requires.services`의 올바른 값을 실제 소비자로 정한다. 코드가 이 값을 읽는 곳을 찾아, 실행 중 동작을 만드는 쪽의 값을 `pack.yaml`에 둔다. 읽는 곳이 없으면 목록표 값을 둔다. 양쪽을 다르게 읽는 소비자가 있으면 멈추고 보고한다.
- AC-04 7개 `pack.yaml`에 목록표의 `tools`를 같은 순서로 넣는다.
- AC-05(검사) 운영 저장소 `airport-check`에 "목록표 = 생성기 출력" 검사를 넣어, 어긋나면 실패하게 한다. 일부러 `pack.yaml` 하나의 도구를 하나 빼거나 목록표를 손으로 고친 사본에서 검사가 실패해야 한다.
- AC-06(보존) 실행본 6개 직원 등록 덤프가 적용 전후 같다(재시작 없이 읽기 전용 덤프 방법, PATH-NFC 방식, 적용 직후 새 프로세스에서 실행). team-kit 전체 시험의 실패 노드 집합이 기준과 같거나 줄었다.

## 3. 범위
- 안: `pack_selection.generate_catalog()`, 7개(+diagnosis requires) `pack.yaml`, `catalog.json` 재생성, 관련 시험, `airport-check` 검사 추가, 운영 저장소 근간 6절(기계 검사) 한 줄.
- 밖: 직책·출입증(2단계), 직원 설정 조립·기본 도구(3단계), 팩 이관 작업의 새 팩, 게이트웨이 재시작(내용이 같아 필요 없음, 다음 자연 재시작 때 새 생성기 코드가 로드됨).

## 4. 롤백
적용 전 실행본 `catalog.json`·`pack_selection.py`·7개 `pack.yaml`을 0700 임시 폴더에 보관한다. AC-06이 실패하면 보관본으로 되돌리고 운영 저장소 커밋을 하지 않는다.

## 5. 증거 수준
AC-01~05 = 2(임시 홈·사본), AC-06 = 3(실제 실행본 등록 덤프).
