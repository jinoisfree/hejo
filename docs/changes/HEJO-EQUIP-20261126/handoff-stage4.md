[설계 인계: HEJO-EQUIP TASK-04 / 4단계(마지막) 도구 검색 자동 + 직책 이름 정리]

0. 기준: [spec-stage4.md](spec-stage4.md) 1.1판 / 2026-11-27 / 사장 결정(도구 검색 auto, 이름만 정리)·위임 / 연합개발
1. 문서: spec-stage4.md, 수락 시험 4단계 절(AT-EQ-21~26), verdict.md(3단계 절과 사장 결정), spec-stage2(AT-EQ-10 탐침 방식), 운영 저장소 AGENTS.md(재시작 148~151행)·docs/ARCHITECTURE.md, HEJO-REF-PHOTO handoff-task05 보완 1·2회(./sync·재시작 조건·실행 환경 재선택·로그 기준).
2. 요구: REQ-EQ-04·05, AC-21~26.
3. 유지할 계약: 출입증 질문의 답(이름만 바뀜), 등록 도구·스키마, `role_roster` 서비스 이름, photon·cron 목록.
4. 흐름: 지시서 `tools.tool_search.enabled` → `hermes-config-assemble` → 직원 설정. 출입증 질문은 `team_registry`의 새 이름.
5. 기존 경로 판정: 옛 함수 이름 = 교체(별칭 없음). 직원 설정의 손으로 쓴 `tool_search` 값 = 교체(조립 결과).
6. 위험도: 고위험. 재시작: 적용 1회 + 실패 시 롤백 1회(위임). 롤백: spec-stage4 3절.
7. 변경 성격: (가) 의미 변경(도구 검색) (나) 동작 보존(이름). 비교: AT-EQ-26.
8. 수락 시험: AT-EQ-21~26(명세·미작성·미실행).
9. 범위
   - worktree: 운영 저장소 `../.worktrees/hermes-hejo-jino-equip4-20261127`(HEAD에서). 증거 = `.build/equip4/`.
   - 착수: 실행본 `team_registry.py`·지시서 sha256을 spec 기준과 대조하고, 다르면 멈춘다.
   - 구현: 이름 변경(전 호출자·시험, `mini-maintenance`와 직원 플러그인 Instagram DM 감시기 포함. 응답 키 `role_hint`는 유지), 조립기에 `tool_search` 반영과 `--check`, airport-check, 근간 문서의 "이행 중(직책 키 = 칸 키)" 문구 정리(운영 저장소 AGENTS.md·docs/ARCHITECTURE.md). hejo 근간의 같은 문구는 계획 담당이 직접 고친다.
   - 적용: 사전 확인(유휴, 300초, 해시, 다른 작업의 plugin-store 변경 0, config·plist 수정 시각) → 보관 → 실행본 교체 → 지시서에 `auto` → 조립기 `--write` → `--check` 0 → 재시작 1회 → 실행 중 Python으로 AT-EQ-22·26 → 실패 시 롤백 → 기본 `./sync` → `./airport-check` → `git commit --only`.
   - AT-EQ-23은 자연 대화가 생길 때까지 "관측 대기"로 보고한다.
   - 금지: 메시지 발송, 금고·`.env`, 값 출력, push, `--rebaseline`, 허가 밖 재시작, hejo 앱·문, 출입증 세분화.
   - 병렬 갈래: 없음(team_registry를 모두가 씀).
10. 가정: Hermes `tools.tool_search.enabled`가 `auto`를 받는다(config_defaults 확인). 아니면 멈춘다.
11. 사용자 확인: 사장 결정 2건(verdict 3단계 절)과 위임.

[보완 1회 · 2026-11-27] TASK-04 보류 보고(호출 범위, `role_hint` 응답 계약)를 수용했다. 이미 만든 equip4 작업 트리의 도구 검색 조립(`hermes-config-assemble`, `core_toolsets.py`, 시험)을 이어 쓴다. `mini-maintenance` 실행 위치 파일과 직원 플러그인 감시기 파일을 보관·교체·롤백 목록에 넣는다. 운영 저장소 팩 이관 작업(보류)의 파일과 겹치는 직원 플러그인 파일은 함수 호출 이름만 바꾸고, 그 밖의 줄은 건드리지 않는다.

[보완 2회 · 2026-11-27 · 사장 결정: 기준선은 사장이 갱신]
- 원인: 이름 변경으로 기존 `fixed_home` 위반 12건의 줄 지문이 바뀌어 `airport-check`가 새 위반으로 센다(개수 동일, 일대일 대응은 `.build/equip4/airport-fingerprint-audit.json`).
- 순서(재시작 전에 기준선을 맞춤):
  1. 사전 확인을 다시 한다(보완 1회와 같음).
  2. 후보 실행본을 보관 뒤 교체하고, 지시서 `auto`를 쓰고, 조립기 `--write`로 반영한 뒤 `--check` 0을 확인한다. 아직 재시작하지 않는다.
  3. 기본 `./sync`로 미러를 모은다. 커밋은 아직 하지 않는다.
  4. 기본 `./airport-check`가 `fixed_home` 12건(지문 교체) 외에는 모두 PASS인지 확인한다. 그 밖의 FAIL이 있으면 보관본으로 복원하고 멈춘다.
  5. 여기서 멈추고 result로 "기준선 갱신 대기"를 보고한다. 바뀐 지문 12개 목록(파일, 옛→새)을 붙인다. 사장이 `./airport-check --rebaseline`과 그 커밋을 직접 한다. 에이전트는 `--rebaseline`을 실행하지 않는다.
  6. (다음 지시로) 계획 담당이 기준선 차이 = 지문 12개 교체, 개수 동일임을 확인하면, 재시작 1회 → AT-EQ-22·26 → 기본 `./airport-check` PASS → `git commit --only`(바꾼 경로 + 운영 기록) 순으로 이어 간다. 실패하면 보완 1회 범위로 롤백한다(기준선 커밋은 사장이 되돌린다).
- 5와 6 사이에 실행본은 바뀐 상태이고 재시작만 남아 있다. 그동안 예기치 않은 재시작이 일어나면 새 코드가 로드되며, 그 경우 6의 확인을 바로 한다.
