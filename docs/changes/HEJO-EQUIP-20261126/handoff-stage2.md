[설계 인계: HEJO-EQUIP TASK-02 / 2단계 명부의 직책 → 출입증]

0. 기준: [spec-stage2.md](spec-stage2.md) 1판(기준 해시는 상단) / 2026-11-27 / 사용자 위임(tasks.md) / 연합개발
1. 공식 문서: spec-stage2.md, 수락 시험 `tests/acceptance/HEJO-EQUIP.md` 2단계 절, design.md 2판, ADR-0001, 1단계 [verdict.md](verdict.md)(V-1), 운영 저장소 AGENTS.md(재시작 절차)·docs/ARCHITECTURE.md, HEJO-CONNECTIONS design 7.1·7.2, PATH-NFC impl-report(등록 덤프), HEJO-REF-PHOTO handoff-task05 보완 1·2회(./sync·재시작 조건, 실행 환경 재선택, 로그 기준).
2. 요구: REQ-EQ-02, AC-07~14.
3. 유지할 계약: `team_registry`의 공개 함수 이름·인자·반환, 기본 담당 대체 순서, 명부의 다른 키(`name`·`label`·`aliases`·`apps`), 등록 도구.
4. 흐름: 명부 `access` → `team_registry`(유일한 읽기) → 기존 직책 질문 함수. 기본 담당: 지시서 → `team_registry`/`owner_contract`.
5. 기존 경로 판정: 명부 `roles` = 교체(이관 뒤 거부). 직접 읽는 7곳 + 조립기 = 통합(`team_registry` 경유). 설치기 `roles` 쓰기 = 교체.
6. 위험도: 고위험. 증거: AC-07~09·12·13 = 2, AC-10·11·14 = 3. 롤백: spec-stage2 4절. 재시작: 적용 1회 + 실패 시 롤백 1회(사용자 위임).
7. 변경 성격: 동작 보존(저장 형식만 변경). 비교: AT-EQ-10·11.
8. 수락 시험: AT-EQ-07~14(명세, 코드 미작성, 미실행).
9. 범위
   - worktree: 운영 저장소 `../.worktrees/hermes-hejo-jino-equip2-20261127`(운영 저장소 HEAD에서). 증거 = `.build/equip2/`.
   - 먼저: 1단계 V-1의 새 시험(`tests/test_pack_selection.py`)을 이 작업의 바꿀 파일에 포함해 함께 적용한다.
   - 착수: 실행본 `team_registry.py`·명부·지시서 sha256을 spec 기준과 대조하고, 다르면 멈춘다. 명부·지시서는 해시와 파싱한 구조(키 이름·직원 수)만 본다. 값을 출력하지 않는다.
   - 구현: spec 2절. 시험 58개 이관은 기계적 치환 + 직접 확인. AT-EQ-10 탐침 스크립트를 이관 전 실행본으로 먼저 돌려 기준을 남긴다.
   - 적용: 사전 확인(유휴, 300초, 실행본 해시, 다른 작업의 plugin-store 변경 0, config·plist 수정 시각) → 보관 → 코드·조립기 교체 + 명부·지시서 이관(임시 파일 + 이름 바꾸기, 주석·순서 보존) → 조립기 `--check` → 재시작 1회 → 실행 중 프로세스의 Python으로 AT-EQ-10·11·14 → 실패 시 4절 롤백(재시작 1회) → 기본 `./sync` → `./airport-check` → `git commit --only`(바꾼 미러·`starter-templates`·근간 문구·운영 기록). 공개판 틀 바꿈은 `make-starter --check`까지만 하고 공개판 생성·푸시는 하지 않는다.
   - 보고: 이 폴더의 `impl-report.md`에 2단계 절을 덧붙인다. 실제 직원 id·이름은 비공개 `<운영 저장소>/docs/changes/HEJO-EQUIP-20261126/ops-application.md`에만 적는다.
   - 금지: 직원 설정(config.yaml) 내용 변경, 금고·`.env` 열람, 명부·지시서 값 출력, 실제 메시지 발송, git push, `--rebaseline`, 허가 밖 재시작, hejo 앱·문.
   - 병렬 갈래: 없음(파일 겹침: `team_registry.py`를 모든 갈래가 기준으로 씀, 적용은 한 번).
10. 가정·미확정: `app_connect`가 명부를 쓸 때 다른 키를 보존하는 방식이 `access`에도 맞는지 착수 때 확인한다. 맞지 않으면 멈춘다.
11. 사용자 확인: 위임(tasks.md 2026-11-27). 사장 칸(명부·지시서) 대리 기록도 이 위임에 포함한다.
