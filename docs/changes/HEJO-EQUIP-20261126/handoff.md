[설계 인계: HEJO-EQUIP TASK-01 / 도구 목록의 원본을 칸 선언 하나로]

0. 기준: spec 1판(기준 해시는 spec 상단) / 2026-11-27 / 사용자 승인("구현진행해", 근간 개정안 2판과 단계 진행) / 연합개발
1. 공식 문서: [spec.md](spec.md), [수락 시험](../../../tests/acceptance/HEJO-EQUIP.md), [design.md](design.md), [ADR-0001](../../decisions/ADR-0001-staff-access-pass.md), 운영 저장소 `AGENTS.md`·`docs/ARCHITECTURE.md`(6절 기계 검사), team-kit worktree 개발 절차 [HEJO-CONNECTIONS design 7.1](../HEJO-CONNECTIONS-20261120/design.md), 등록 덤프 방법 `<운영 저장소>/docs/changes/PATH-NFC-20261122/impl-report.md`
2. 요구와 수락 기준: REQ-EQ-01, AC-01~06. 핵심 실패: 생성한 목록표의 내용이 기준과 달라 도구 등록이 바뀌거나, 어긋남을 검사가 잡지 못하면 실패.
3. 유지할 계약: 목록표 JSON 형식(`version`, `packs.<id>` 전체 선언), `PackContext`·`selected()` 동작, 각 직원의 등록 도구·스키마.
4. 흐름: `pack.yaml`(원본) → `generate_catalog()`(전부) → `catalog.json`(결과) → 등록 필터. `airport-check`가 결과 = 생성 출력을 확인한다.
5. 기존 경로 판정: `generate_catalog()`의 "일부 팩만 갱신, 옛 항목 유지" = 교체(전부 생성). 7개 팩의 목록표 전용 `tools` = 통합(`pack.yaml`로). 목록표 손 편집 = 제거(검사로 금지).
6. 위험도: 일반. 증거 수준: AC-01~05 = 2, AC-06 = 3. 롤백: spec 4절.
7. 변경 성격: 동작 보존 리팩토링. 비교: AT-EQ-02(JSON 동치), AT-EQ-06(등록 덤프 동일).
8. 수락 시험: AT-EQ-01~06(명세, 코드 미작성, 미실행).
9. 작업 범위
   - worktree: 운영 저장소 `../.worktrees/hermes-hejo-jino-equip-20261127`(시작 운영 저장소 HEAD, spec 기준 `39c2a393` 이후면 바꿀 파일 해시만 확인), 증거 = 그 worktree의 `.build/equip/`.
   - 착수 확인: 실행본 `catalog.json`·`pack_selection.py`와 운영 저장소 사본, `airport-check`의 sha256이 spec 기준과 같다. 다르면 멈춘다.
   - 구현: worktree의 `hermes/plugin-store/team-kit`에서 `generate_catalog()`를 전부 생성하게 바꾼다. 7개 `pack.yaml`에 `tools`를 넣고, AC-03으로 diagnosis `requires.services`를 정한다. 목록표를 생성기로 다시 만든다. 시험(AT-EQ-01·02·04·05·06 중 자동 부분)을 넣고, 기존 `test_catalog_is_generated_from_changed_pack_declarations`는 유지한다. 운영 저장소 `airport-check`에 검사를 넣고, 근간 6절에 한 줄 추가한다.
   - 검사: team-kit 전체 시험은 기준·후보 실패 노드를 대조한다(HEJO-REF-PHOTO와 같은 방식). `./airport-check`는 기본 모드로 돌린다.
   - 적용(재시작 없음): 유휴일 때 바꿀 실행본(`catalog.json`, `pack_selection.py`, `pack.yaml` 8개 이내)을 0700 폴더에 보관하고, 임시 파일 + 이름 바꾸기로 교체한다. 새 프로세스에서 등록 덤프로 AT-EQ-06을 확인하고, 실패하면 spec 4절로 롤백한다. 이어서 운영 저장소 main에서 기본 `./sync` → 기본 `./airport-check` → `git commit --only`(바꾼 미러 경로 + `airport-check` + `docs/ARCHITECTURE.md` + 이 작업 운영 문서)를 한다. 다른 미러 변경은 남긴다.
   - 보고: `impl-report.md`(이 폴더). 실제 직원 이름·경로는 쓰지 않는다.
   - 금지: 게이트웨이 재시작, 직책·명부·직원 설정 변경, 팩 이관 작업의 파일, Hermes 본체, 금고·`.env`·`config.yaml` 열람, 메시지 발송, git push, `--rebaseline`.
   - 선행: 없음. 병렬 갈래: 없음(tasks.md).
10. 가정·미확정: diagnosis `requires.services` 값은 AC-03으로 정한다(착수 차단 아님). 팩 이관 작업이 그 사이 같은 파일을 바꾸면 멈춘다.
11. 사용자 확인: 2026-11-27 "구현진행해"로 근간 개정안 2판과 단계 진행을 승인했다. 1단계는 재시작 없는 동작 보존 적용이다.
