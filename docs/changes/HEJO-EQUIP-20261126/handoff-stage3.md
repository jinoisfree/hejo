[설계 인계: HEJO-EQUIP TASK-03 / 3단계 출입증 → 직원 기본 도구 조립]

0. 기준: [spec-stage3.md](spec-stage3.md) 1판 / 2026-11-27 / 사용자 위임 / 연합개발
1. 문서: spec-stage3.md, 수락 시험 3단계 절(AT-EQ-15~20), design.md 2판, ADR-0001, verdict.md(2단계 V-2), 운영 저장소 AGENTS.md·docs/ARCHITECTURE.md, 기존 조립기 3종(`hermes-*-assemble`, `--check` 방식 참고), HEJO-REF-PHOTO handoff-task05 보완 1회(./sync·커밋 규칙).
2. 요구: REQ-EQ-03, AC-15~20.
3. 유지할 계약: 직원 설정의 플러그인 항목·다른 플랫폼 목록·`tools.tool_search`, `config_assembly.assemble_config`의 기존 동작(설치·앱 연결 경로).
4. 흐름: 출입증(명부) → 칸 선언(`roles/<칸>/guide.yaml`, `pack.yaml`) → `hermes-config-assemble` → 직원 `config.yaml` slack/hejo 기본 도구 항목.
5. 기존 경로 판정: 직원 설정에 손으로 쓴 기본 도구 = 교체(조립 결과로). `config_assembly` 118-123행 slack→hejo 복사 = 유지(조립기가 다시 부름).
6. 위험도: 고위험. 증거: spec 5절. 재시작 없음(차이 0일 때). 차이가 0이 아니면 쓰지 말고 차이 표를 보고하고 멈춘다(사장 결정).
7. 변경 성격: 동작 보존. 비교: AT-EQ-17.
8. 수락 시험: AT-EQ-15~20(명세·미작성·미실행).
9. 범위
   - worktree: 운영 저장소 `../.worktrees/hermes-hejo-jino-equip3-20261127`(HEAD에서). 증거 = `.build/equip3/`.
   - 착수: 실행본 `config_assembly.py`·`airport-check` sha256을 spec 기준과 대조하고, 다르면 멈춘다.
   - 구현: 선언 6개 + 필요한 `pack.yaml` `core_toolsets`, 조립기(원본 위치는 기존 조립기와 같은 곳, ./sync 수집 대상인지 확인), 시험, airport-check 검사, 설치기 연결.
   - 적용: 사전 확인 → 실행본 `--check` 6명 차이 0 확인 → 코드·선언·조립기 파일 교체(보관 뒤, 임시 파일 + 이름 바꾸기) → `--check` 다시 0 → 기본 `./sync` → `./airport-check` → `git commit --only`(바꾼 경로 + 운영 기록). 직원 `config.yaml`은 쓰지 않는다(차이 0이므로).
   - 보고: impl-report.md 3단계 절. 실제 직원 id는 비공개 ops-application.md에만 둔다.
   - 금지: 직원 `config.yaml` 쓰기(차이가 0이 아닌데 쓰기 포함), 도구 검색 값 변경, 금고·`.env`, 메시지, push, `--rebaseline`, 재시작.
   - 병렬 갈래: 없음(조립기를 모두가 씀).
10. 가정: `toolsets.TOOLSETS` 키로 기본/플러그인 구분이 된다. 안 되면 멈춘다.
11. 사용자 확인: 위임. 차이 0이 아니면 멈춤(사장 결정).
