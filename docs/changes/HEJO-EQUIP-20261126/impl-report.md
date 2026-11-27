# HEJO-EQUIP TASK-01 구현 인계

## 적용 결과

명세 1판의 1단계를 운영에 적용했다. 기준 운영 소스는 `e9f3cbb5d11eda0881de2d3402344087e5e9f64f`였다. 명세의 실행본·미러 세 기준 SHA-256 및 변경할 선언 7개의 원본·작업 트리 일치를 착수 때 확인했다. 구현 후보는 `3e2c9f8c33707eb943d0f89c57cd5bc2c007cbc2`, 운영 저장소 `main` 커밋은 `0a2f933da9421f608f9fb86baf7ef1dc1bd90454`이다.

- 도구 창고의 12개 `pack.yaml`에서 카탈로그 전체를 만들도록 `generate_catalog()`를 바꿨다. 이전 카탈로그를 입력으로 읽는 방식과 선언 없는 항목 유지 동작을 제거했다.
- diagnosis, ego-browser, linked-work, native-tools, notes, notion, sns의 선언에 기존 카탈로그와 같은 순서로 `tools`를 넣었다. 생성 결과는 기존 카탈로그와 JSON 값 전체가 같다.
- AC-03은 기존 카탈로그의 `source_adapters`를 diagnosis 선언에 반영했다. `lib/hermes_facility/pack_selection.py:21,29`는 `requires.packs`를, 46행은 `tools`를 읽는다. 저장소의 카탈로그·팩 선언 소비자 검색에서 `requires.services`로 동작을 결정하는 곳은 없었다. `tests/test_pack_contracts.py:9,14`도 선언을 읽어 팩 의존성만 검사한다.
- `airport-check`는 실제 운영 경로와 커밋 스냅샷 각각의 카탈로그가 생성 출력과 같은지 검사한다. 근간 6절에 이 검사 한 줄을 추가했다.
- 새 자동 시험은 구현 후보의 `tests/test_pack_selection.py`에 있다. 운영 교체와 최종 수집은 승인된 실행본 9개로 한정해, 새 시험은 운영 미러 대신 작업 트리 커밋에 남겼다. 기존 생성기 대조 시험은 수정하지 않았다.

## 검증과 적용

증거는 `hermes-hejo-jino-equip-20261127` 작업 트리의 `.build/equip/`에 있다.

| 기준 | 실행 및 실제 결과 | 로그 |
|---|---|---|
| AT-EQ-01·관련 계약 | `pytest tests/test_pack_selection.py tests/test_pack_contracts.py tests/google_disconnect/test_native_workspace.py::test_catalog_is_generated_from_changed_pack_declarations` 종료 0, 8개 통과. 선언 없는 기존 항목을 제거하는 새 시험 포함 | `targeted.log` |
| AT-EQ-02·04 | 운영과 기준 JSON 전체 값 12개 및 보완한 도구 목록 7개 일치. 후보가 기존 도구·팩 선택 규칙을 바꾸지 않음 | `catalog-acceptance.log`, `verified-application.json` |
| AT-EQ-05 | 실제 `airport-check --snapshot`의 정상 사본 종료 0. 선언에서 도구 제거 및 카탈로그 단독 편집 사본은 각각 종료 1이며 카탈로그 검사만 실패 | `airport-equal.log`, `airport-manifest-drift.log`, `airport-catalog-drift.log` |
| AT-EQ-06 시험 묶음 | 동일 격리 환경의 `pytest tests` 기준·후보 모두 종료 1. 각각 5333·5334개 통과, 양쪽 모두 실패 74·오류 1·건너뜀 63. 실패·오류 노드 75개가 동일하며 비교 종료 0 | `baseline-team.log`, `candidate-team.log`, `full-node-delta.log` |
| AT-EQ-06 운영 등록 | 0700 보관 뒤 유휴 상태에서 9개를 임시 파일과 이름 바꾸기로 교체했다. PATH-NFC 방식의 새 프로세스 덤프 6개가 적용 전후 전체 JSON으로 동일하다. 게이트웨이 PID·시작 시각은 같으며 재시작 0회 | `operations.jsonl`, `before-registration.json`, `after-registration.json`, `verified-application.json` |
| 원본 수집과 커밋 | 기본 `./sync` 및 적용 전후 기본 `./airport-check` 종료 0. `git commit --only` 종료 0. 운영 커밋은 대상 미러 9개, `airport-check`, `docs/ARCHITECTURE.md`, 운영 기록 1개로 총 12개 | `sync.exit`, `airport-default-baseline.log`, `airport-default-applied.log`, `ops-commit.exit`, `verified-application.json` |

수집 직후의 확인 절차가 처음에는 plugin-store에 이번 경로만 변경된다고 잘못 가정해 종료 1이었다. 이번 파일 9개가 전부 수집됐고 다른 작업의 미러 2개가 추가로 모였음을 확인했다. 승인된 커밋 목록을 기준으로 후속 검사를 바로잡아 수집과 실행본 교체를 반복하지 않고 커밋했다. 다른 두 미러는 운영 작업 트리에 남겼다.

최종 카탈로그 SHA-256은 `1be55036d01ca11e6e49f230b1f262e40cc3e8987d5185cb81411f613c532521`, 생성기 SHA-256은 `a7bd241c35254fa0aab4c0eda4509c9cf9d380b9030d4a04204c8cf03d5c974f`, 검사기 SHA-256은 `369d70c8c16826b927f10d81195403aaa27a27f22e8e54d046d29c9adbd2cd3f`다. 실행본 9개 최종 해시와 검증 근거는 `verified-application.json`에 있다. 실제 등록 증거 수준은 3이다. 1단계 독립 검토와 그 뒤 단계는 남아 있다.

## TASK-02 · 2단계 착수 및 보류

작업 트리 `hermes-hejo-jino-equip2-20261127`의 기준은 운영 저장소 `9e208f776110865caaf5f8db860b20545a850ded`다. 적용 전에 설계와 수락 시험의 권한 판정이 충돌해 제품 코드와 운영 이관은 보류했다.

### 차단 근거

- `spec-stage2.md:26`의 AC-07은 옛 `roles` 키가 있는 항목의 출입증을 비우도록 한다. `tests/acceptance/HEJO-EQUIP.md:19`의 AT-EQ-07 (다)는 `roles`와 `access`가 함께 있을 때 `access`를 사용하도록 한다.
- 예를 들어 한 항목에 `roles: [personal]`과 `access: [work]`가 있으면, 명세대로는 `has_role(profile, 'work')`가 거짓이고 수락 시험대로는 참이다. 양쪽 모두 `airport-check`의 실패를 요구하지만, 검사 전이나 이후에 그 항목으로 도구 권한이 실제 열리는지가 달라진다.
- 검토 요청은 혼합 항목의 런타임 기대값을 한 가지로 확정하는 것이다. 폐쇄 기본값을 유지한다면 AT-EQ-07 (다)에 출입증 0을 명시한다. 반대 선택이라면 AC-07의 폐쇄 조건을 옛 키만 있는 경우로 좁히고 혼합 항목의 예외를 명시한다. 결정 이후 등록 경계와 검사를 함께 구현한다.

### 준비 결과

- 명세의 `team_registry.py`·`owner/team.yaml`·`owner/policy.yaml` 세 기준 SHA-256은 실행본과 작업 트리에서 모두 일치했다. 운영 저장소 plugin-store 미커밋 변경은 0이었다.
- `app_connect.py:418–426,448`은 기존 직원 dict에서 `apps`만 갱신하고 같은 명부 전체를 직렬화한다. 새 키 `access`는 그 경로에서 보존된다.
- V-1의 1단계 카탈로그 회귀 시험을 작업 트리의 `hermes/plugin-store/team-kit/tests/test_pack_selection.py`에 옮겼다. 5개 시험이 통과했다. 운영 실행본과 운영 main에는 아직 반영하지 않았다.
- AT-EQ-10 이관 전 탐침을 실제 활성 게이트웨이 환경과 실행본에서 새 프로세스로 실행했다. 직원 6개와 칸 질문 8개에 대해 7개 질의, 기본 담당, 앱 등록 결과를 9개 구획으로 기록했다. 개인별 응답 원문 대신 비교용 HMAC만 보관한다. 같은 명부와 실행본 해시가 유지되면 후속 실행에서 이 기준을 다시 쓸 수 있다.

| 검증 | 실제 결과 | 증거 |
|---|---|---|
| 기준 해시 읽기 전용 대조 | 종료 0, 실행본과 작업 트리 3개 일치 | `.build/equip2/pinned-inputs.json` |
| 활성 Python 환경 재확인 및 `registry-probe.py before` | 종료 0, AT-EQ-10 이관 전 기준 생성. 이관 후 대조는 미실행 | `.build/equip2/registry-before.json`, `registry-before.exit` |
| 격리 `pytest tests/test_pack_selection.py` | 종료 0, 5개 통과 | `.build/equip2/stage1-v1.log`, `stage1-v1.exit` |
| 작업 트리 `git diff --check` | 종료 0 | 변경 파일은 V-1 시험 1개 |

운영 명부·지시서, 조립기, 등록 필터와 게이트웨이는 초기 상태다. 재시작·수집·운영 커밋은 미실행이다. AT-EQ-07 판정 정합화 뒤 V-1 변경과 이관 전 기준을 이어 쓴다.

## TASK-02 · AC-07 정합화 뒤 구현 및 운영 적용

명세 1.1판에 따라 이관했다. 운영 저장소 기준은 `9e208f776110865caaf5f8db860b20545a850ded`, 적용·수집 커밋은 `04958c04a3eb0cf7c05465dff809a673e557a3ac`다. 구현 작업 트리의 `.build/equip2/`에 아래 증거를 남겼다.

- 명부의 출입증은 `access`로 읽는다. 옛 `roles` 키가 있으면 혼합 항목까지 출입증이 비고, 파일별 경고가 한 번만 남는다. `airport-check`는 이런 항목의 수를 보고하고 실패한다.
- 기본 담당의 원본은 지시서의 `routing.default_responder`다. 비어 있거나 유효한 직원이 아니면 `default` → 명부 첫 직원 순으로 대체한다. 기존 직책 조회와 앱 권한 조회의 반환 계약을 유지했다.
- 명부를 읽는 예약·파일 제안·앱·되돌리기 경로와 SOUL·스킬 조립은 `team_registry`를 경유한다. 공개 설치 틀에서 모집 템플릿의 분류 이름은 유지하고, 새 명부에는 `access`, 지시서에는 기본 담당을 쓴다.
- 실행본 42개와 명부·지시서를 0700 폴더에 보관하고, 임시 파일과 이름 바꾸기로 교체했다. 명부·지시서의 다른 값, 키 순서와 주석을 비교했다. 출입증 순서와 적용 전 기본 담당을 보존했다. 게이트웨이는 승인 범위에서 1회 재시작했다.
- 기본 `./sync` 뒤 실행본 44개와 미러의 해시가 일치했다. 소스·시험·설치 틀·근간 문구와 운영 기록까지 55개 경로가 `git commit --only`에 들어갔다. 범위 밖 미러와 별도 작업 문서는 작업 트리에 남겼다.

### AC-09 · 남은 명부 관련 `roles` 검색 결과

| 파일 | 남은 사용 근거 |
|---|---|
| `hermes_facility/team_registry.py` 88, 130–139, 176–192행 | 130행은 옛 저장 키의 존재 여부 검사다. 나머지는 정규화한 조회 결과와 기존 공개 함수 계약이다. |
| `hermes_router/owner_contract.py` | 명부 역할 키 조회가 없다. 기본 담당 선택을 `team_registry`로 위임한다. |
| `hermes_schedule/catalog.py` 49행 | `roster_at()`으로 받은 정규화 결과에서 예약 담당을 고른다. |
| `hermes_team_services/file_drop_suggest.py` 29–31, 249, 274, 280, 347, 354행, `file_drop_review.py` 85행 | `roster_at()`으로 받은 출입증을 파일 제안용으로 좁힌다. 검토기는 그 제안용 결과를 재사용한다. |
| `hermes_team_services/work_metrics.py` 69행 | 모델 호출 관측 결과의 분류 키다. 명부 조회가 없다. |
| `hermes_governance/app_undo.py` 34–38행 | 기존 플러그인 설정과 `roster_at()`의 조회 결과를 이용한다. |
| `hermes_facility/app_registry.py` 23–34, 56, 79, 88–89행 | 기존 앱 권한 추론과 도움말에 정규화 결과를 사용한다. 명시 앱 목록은 `team_registry.read_team()`을 통해 얻는다. |
| `hermes-skill-assemble` 108행, `hermes-soul-assemble` 79, 89–97행 | 정규화한 값으로 매뉴얼과 SOUL의 기존 치환 계약을 유지한다. 나머지 `roles/` 표기는 서가 경로다. |
| `starter-templates/install_support.py` 380, 480행, `installation.json` 4행 | 최상위 `roles`는 모집 템플릿을 분류하는 키다. 직원 명부를 쓰는 필드는 `access`다. |

### 검증

| 기준 | 실행 결과 | 증거 |
|---|---|---|
| 착수·이관 구조 | 고정 SHA-256 3개 일치, 플러그인 실행본의 작업 밖 차이 0, 유휴·300초·수정 시각 통과. 명부 6개와 기본 담당 1개의 이관, 주석 및 순서 보존 확인 | `preflight.log`, `owner-structure.log`, `applied-file-manifest.json` |
| AT-EQ-07~09 | 핵심 pytest 87개 통과. 실제 `airport-check --snapshot`에서 새 항목은 종료 0, 옛 항목과 혼합 항목은 각각 종료 1이며 `roster-access`만 실패 | `kit-target.log`, `airport-roster-{access,old,mixed}.log` |
| AT-EQ-10 | 활성 실행 환경의 새 프로세스에서 이관 전·후 JSON 바이트 동일. 직원 6개, 역할 질문 8개, 결과 9구획 | `registry-{before,after}.json`, `registry-after.log` |
| AT-EQ-11 | 조립기 3종 `--check` 적용 전후 모두 종료 0. 재시작 전후 직원 6개의 등록 덤프 JSON 동일 | `assembly-{before,after}.json`, `{before,after}-registration.json` |
| AT-EQ-12 | team-kit은 기준 5,332 통과·76 실패·1 오류에서 후보 5,339 통과·74 실패·1 오류로 바뀌었다. team-delegation은 양쪽 모두 2,891 통과·69 실패·264 오류다. 두 묶음의 pytest 종료 코드는 모두 1, 후보에만 있는 실패·오류 노드는 0개이며 비교 종료 0 | `{kit,delegation}-{before-comparable,after}.xml`, `full-node-delta-comparable.log` |
| AT-EQ-13 | 임시 배포 사본에 대해 `./make-starter --target hermes-hejo-p --check` 종료 0, 419개 파일·유출 탐지 0. 격리한 설치·조립·내보내기 pytest 101개 통과. 신규 설치 시험에서 `access` 및 사장 지시서의 기본 담당을 확인 | `starter-check.log`, `root-assembly-install.log` |
| AT-EQ-14 | 재시작 1회, 연결 수 hejo 6·Slack 6·photon 1 동일. 기준 밖 오류 0, Discord 실패 0. hejo 링크·릴리스·설치 영수증과 설정 파일·서비스 정의의 수정 시각은 전후 동일 | `rollout.log`, `after-log-check.json`, `rollout-result.json` |
| 수집·커밋 | 기본 `./sync`, 기본 `./airport-check`, 범위 한정 `git diff --check` 및 `git commit --only` 모두 종료 0 | `sync.log`, `airport-check.log`, `ops-commit.log`, `collection-result.json` |

명세에는 시험 이관 대상이 58개로 집계됐으나, 명부·설치 틀을 실제로 쓰는 fixture와 관련 회귀 시험을 확인해 시험 영역에서 40개 파일을 변경했다. 공용 fixture를 사용하는 파일과 정규화한 결과만 다루는 파일은 집계에 넣지 않았다. V-1에서 추가한 팩 카탈로그 회귀 시험도 40개에 포함된다.

별도 확장 시험인 `tests/test_public_installation.py` 포함 실행에서 14개가 임시 홈에 Hermes Python을 준비하지 못해 종료 1이었다. AT-EQ-13의 공개판 검사와 준비된 임시 홈의 신규 설치 시험은 통과했다. 운영 커밋은 로컬에 있으며 푸시는 별도 절차로 남아 있다.

## TASK-03 · 출입증에서 기본 도구 조립

명세 1판의 기준 운영 커밋은 `04958c04a3eb0cf7c05465dff809a673e557a3ac`다. 운영 적용 커밋은 `9cea8e323a016d9088b06f547bbe0ada660a3b3d`다. 구현 작업 트리 `.build/equip3/`에 명령별 로그와 적용 파일 해시를 남겼다.

- personal·work·doctor·wiki·customers·standby의 `roles/<칸>/guide.yaml` 6개와 SNS 팩의 빈 `core_toolsets`를 선언했다. 팩 목록표는 기존 생성기로 다시 만들었다. `toolsets.TOOLSETS`에서 명세의 기본 도구가 모두 확인됐고 기존 플러그인 도구셋은 기본 도구 키에 없었다.
- `hermes-config-assemble`은 명부 조회에서 출입증을 얻고 칸 선언의 합을 만든다. 유지할 Slack 항목과 플러그인 항목은 기존 상대 순서에서 보존하고, 새 기본 도구를 끝에 붙인다. 미선언 칸이면 쓰기 전 실패한다. 기존 Slack → hejo 복사 함수는 기존 설치·앱 연결 조립과 새 조립기가 공유한다.
- 공개 설치기는 신규 직원 설정에 같은 조립기를 사용하며 선언 파일도 관리 코드와 함께 설치한다. 기존 코드 업데이트 경로와 근간의 직원 설정 조립 문구를 확인했다.
- 실행본 검사에서 6명·차이 0을 확인한 뒤 기존 파일을 0700 폴더에 보관하고 실행본 12개를 설치했다. 교체 후 검사도 6명·차이 0이었다. 설정 파일 6개의 SHA-256·수정 시각·inode가 같아 photon·cron·cli와 도구 검색을 포함한 설정 변경은 0이다. 게이트웨이 PID·시작 시각은 그대로였고 재시작은 0회다.
- 처음 사전 확인에서 설정 파일이 없는 프로필 디렉터리를 수에 포함해 적용 전에 멈췄다. 실제 설정 파일이 있는 6개만 대조하도록 운영 증거 스크립트를 바로잡았다. 첫 시도에서 운영 파일을 교체한 적은 없다. `operation-initial-preflight.log`에 남겼다.

### 검증

| 기준 | 결과 | 증거 |
|---|---|---|
| 착수 | `config_assembly.py`와 `airport-check` 고정 SHA-256 일치 | `pinned-inputs.json` |
| AT-EQ-15·16 | 선언 표, 플러그인 상대 순서, 미선언 칸 오류, Slack → hejo, 기존 조립 회귀 시험 포함 19개 통과, 종료 0 | `kit-final-target.log` |
| AT-EQ-17 | 실제 홈의 적용 전·후 `hermes-config-assemble --check` 각각 종료 0, 검사 6명·차이 0 | `operating-check-before.log`, `operating-check-after.log` |
| AT-EQ-18 | 가짜 홈의 실제 `airport-check` 정상 상태 종료 0. 선언에서 도구를 뺀 사본과 설정에 도구를 더한 사본은 각각 종료 1이며 조립 검사만 실패 | `airport-clean.log`, `airport-declaration-edited.log`, `airport-config-edited.log` |
| AT-EQ-19 | 운영 설정 파일 6개 바이트·수정 시각·inode 동일. team-kit은 기준 5,339 통과·74 실패·1 오류, 후보 5,342 통과·74 실패·1 오류. 양쪽 pytest 종료 1, 실패·오류 노드 75개 동일, 비교 종료 0 | `rollout-result.json`, `kit-{before,after}.xml`, `node-comparison.log` |
| AT-EQ-19, 2단계 V-2 | 준비한 임시 런타임에서 `tests/test_public_installation.py` 20개와 `tests/test_starter_runtime.py` 26개, 총 46개 통과, 종료 0. 2단계에서 실패했던 14개를 포함한다. | `public-install.log`, `public-install.xml` |
| AT-EQ-20 | 임시 배포 사본에 대해 `make-starter --target hermes-hejo-p --check` 종료 0, 426개 파일·발견 0 | `starter-check.log` |
| 운영 수집 | 기본 `./sync`와 `./airport-check`, `git commit --only` 종료 0. 범위 18경로를 기록하고 실행본 미러 12개를 후보 해시와 대조했다. | `sync.log`, `airport-check.log`, `ops-commit.log`, `manifest.json`, `rollout-result.json` |

선언·조립·검사는 임시 홈 대역 수준 2, 실제 운영 환경의 동작 보존은 수준 3이다. 범위 밖 기존 미러와 작업 문서는 운영 작업 트리에 남았다. 푸시는 별도 승인 대기다.

## TASK-04 · 도구 검색 조립 부분 구현 및 운영 보류

운영 기준 `9cea8e323a016d9088b06f547bbe0ada660a3b3d`와 실행본 고정 해시 2개가 명세와 일치했다. Hermes 본체의 `config_defaults.py`와 `tools/tool_search.py`에서 `auto` 지원을 확인했다.

### 이름 정리 차단 근거

| 경계 | 실제 코드 | 현재 인계와의 충돌 |
|---|---|---|
| 운영 정비 실행기 | `local-bin/mini-maintenance:126–129`는 `team_registry.home_of_role()`을 직접 호출한다. 실제 실행본에서도 확인했다. | AC-24의 호출자 목록과 AC-25의 검색 범위 밖이다. 별칭 없이 함수를 제거하면 이 운영 호출을 함께 이관해야 한다. |
| 직원별 운영 플러그인 | `hermes/profiles/*/plugins/instagram-dm/watch.py:183–187`는 공유 Slack 블록 모듈의 `team.home_has_role()`을 호출한다. 같은 플러그인 시험에도 기존 이름이 있다. | 해당 실행본과 시험은 이번에 열거한 team-kit·team-delegation 경로 밖이다. 함수를 제거하면 공유 블록 처리가 기존과 달라진다. |
| 연결 응답 필드 | `hermes_facility/app_connect.py:576`과 `hermes_packs/mac_apps/discovery.py:143`은 함수 호출 결과를 응답 필드 `role_hint`로 보낸다. 운영 hejo 문의 `connection_manager.py:18` 허용 목록은 `role_hint`를 받으며 `access_hint`를 받지 않는다. | 함수의 이름만 바꾸면 기존 응답 필드가 AC-25의 단어 검색에 계속 잡힌다. 필드까지 바꾸면 현재 운영 문이 그 필드를 응답에서 제거한다. 문 변경은 9번 범위 밖이다. |

권고는 출입증 함수 이름과 응답 필드 계약을 구분하는 것이다. AC-25를 호출·정의·import 심볼 기준으로 보거나 `role_hint` 응답 필드만 명시적으로 남기고, 두 운영 호출자와 그 시험을 적용·보관·롤백 목록에 추가하면 기존 호출 동작과 응답을 유지할 수 있다. 응답 필드 자체를 바꾸려면 별도로 문과 공개 응답 호환 범위를 확정해야 한다.

### 부분 구현과 검증

기존 4단계 작업 트리에서 도구 검색 정책을 조립기에 연결했다. 정책에서 `tools.tool_search.enabled`를 읽어 직원 설정의 해당 잎 키를 투영한다. 값이 없으면 도구 검색 설정에 손대지 않는다. `--check`에서 값 자체를 출력하지 않고 어긋남을 표시하고, 기존 `airport-check` 조립 검사도 이를 감지한다. 이미 일치하는 hejo 목록의 YAML 주석을 보존한다.

| 항목 | 실제 결과 | 증거 |
|---|---|---|
| 착수 및 계약 | 고정 SHA-256 2개 일치. 범위 밖 실행 호출자 2곳과 연결 응답 생산자 2곳, 운영 hejo 허용 목록을 소스에서 대조 | `contract-audit.json` |
| AT-EQ-21, 대역 수준 2 | 핵심 pytest 20 passed, 종료 0. 임시 직원 6개에서 정책 적용 시 파싱상 해당 키만 변경, 값 부재 시 6개 바이트 동일, 수동 변경을 `--check`가 거부 | `kit-policy-target.log` |
| AT-EQ-21, 정비 검사 | 실제 `airport-check` 임시 홈에서 정상 종료 0, 정책과 직원 설정 불일치 종료 1. 조립 검사만 실패 | `airport-policy-{matched,drift}.log` |
| 기존 공개 설치 회귀 | 준비한 임시 런타임에서 공개 설치·런타임 pytest 46 passed, 종료 0. 임시 배포 사본 `make-starter --target hermes-hejo-p --check` 종료 0 | `public-install.log`, `starter-check.log` |
| 운영 읽기 전용 검사 | 기존 정책을 읽는 후보 `hermes-config-assemble --check` 종료 0, 6명 차이 0. 운영 커밋과 후보가 바꿀 실행본 3개는 기준과 동일 | `operating-readonly-check.log`, `readonly-result.json` |

증거는 구현 작업 트리의 `.build/equip4/`에 있으며 변경본은 `candidate-policy.diff`에 보관했다. 이름 변경, 지시서·직원 설정 쓰기, 실행본 교체, 게이트웨이 재시작, 운영 수집·커밋은 보류했다. AT-EQ-22·24~26은 통합 적용 뒤 검증 대상이다. AT-EQ-23은 운영 적용 후 자연 대화 관측 대기로 남긴다.

### 보완 1회 · 이름 정리 완료, 운영 적용 복원

1.1판에 따라 이름을 정리했다. 정비 실행기, Instagram DM 감시기 및 해당 시험의 변경은 각각 호출·참조 이름 한 곳이다. 연결 응답 `role_hint`와 팩 서비스 `role_roster`는 기존 계약을 유지했다. 운영 근간의 이행 중 문구도 작업 트리에서 정리했다. 후보 소스는 `.build/equip4/candidate-final.diff`에 있다.

| 항목 | 실제 결과 | 증거 |
|---|---|---|
| AT-EQ-21 | 핵심 pytest 39개 통과, 종료 0. 정책 일치 임시 홈의 `airport-check`는 종료 0, 직원 설정만 고친 사본은 종료 1 | `kit-final-target.log`, `airport-policy-{matched,drift}.log` |
| AT-EQ-24·25 | 옛 호출·정의·상수 0건. 남은 검색 결과는 기존 응답 필드 2곳이다. 정비 실행기·감시기·해당 시험의 Python 구문 검사 통과 | `name-scan.log`, `external-syntax.log` |
| AT-EQ-26 새 이름 탐침 | 운영 Python에서 후보 모듈을 읽기 전용으로 불러 조회 9개 구획을 실행했다. 종료 0, 2단계 적용 뒤 기준과 JSON 바이트가 같다 | `registry-candidate.log`, `registry-candidate.json` |
| AT-EQ-26 전체·공개판 시험 | team-kit 후보 5,343 passed, 기준 5,342 passed, 양쪽 실패·오류 75개 동일. team-delegation 양쪽 실패·오류 333개 동일. 전체 pytest는 기존 실패로 종료 1, 노드 집합 비교는 종료 0. 공개 설치·런타임 46개, 임시 공개판 426개 파일 검사 통과 | `node-comparison.log`, `kit-*.xml`, `install-final.log`, `starter-final.log` |
| AT-EQ-22, 재시작 전 | 직원 6명에 정책을 조립했고, 파싱상 바뀐 키는 `tools.tool_search.enabled` 하나뿐이었다. 조립기 4종 `--check`는 통과 | `config-assemble-write.json`, `config-before-restart.log`, `assembly-after-write.json` |
| 적용 차단 | 재시작에 앞서 후보 `airport-check` 종료 1. 파일 11개에 있던 `fixed_home` 기준선의 12개 지문이 함수 이름 변경 때문에 달라졌다. 변경된 줄 각각에서 함수 이름을 되돌린 내용은 기준 커밋의 줄과 같고, 예전 지문은 승인 기준선에 있다 | `airport-before-restart.log`, `airport-fingerprint-audit.json` |
| 자동 복원 | 0700 보관본 118개와 복원한 실행본의 SHA-256 일치. 직원 설정 6개 포함. 재시작 0회. 탐침 9구획과 직원 등록 덤프 6개가 기준과 같고, 기본 운영 `./airport-check` 종료 0 | `restoration-audit.json`, `rollout.log`, `airport-restored.log` |

새 고정 홈 사용은 추가되지 않았다. 검사는 경로 표현뿐 아니라 줄 전체를 지문화하므로 현재 명세의 이름만 변경한 후보는 기존 기준선으로 검사를 통과할 수 없다. 기준선·검사 로직은 그대로 두었다. 권고는 보완 설계에 기존 12개 지문의 일대일 이관 기준을 명시해 독립 검토하는 것이다. 실제 고정 홈 의존을 없애는 방안을 택하면 변경 범위와 영향 검증을 함께 정해야 한다.

기준 운영 커밋은 `9cea8e323a016d9088b06f547bbe0ada660a3b3d` 그대로다. 이번 시도에서 허가된 재시작을 소비하지 않았다. 수집·운영 커밋과 재시작 뒤 AT-EQ-22·26은 보류했다. AT-EQ-23은 운영 적용 후 자연 대화 관측 대기다.


### 보완 2회 · 기준선 갱신 대기

사장이 직접 기준선을 갱신하기 전 단계인 보완 2회 1~5를 마쳤다. 적용 후보가 앞서 시험한 소스와 바이트 단위로 같음을 확인했다. 실행본 118개를 0700 폴더에 보관한 뒤 승인된 파일을 교체하고 직원 설정 6개를 조립했다. 그 여섯 설정은 파싱상 지정한 잎 키만 바뀌었다. `hermes-config-assemble --check`는 종료 0, 직원 6명·차이 0이었다. 기본 `./sync`는 종료 0이며 적용한 파일 118개의 미러 해시가 실행본과 일치했다.

기본 `./airport-check`는 종료 1이었다. 아래 `fixed_home` 지문 12개(파일 11개)만 새 위반으로 집계됐고 문서·칸·팩 목록·명부와 조립기 4종 검사 8개가 모두 통과했다. 실제 실행본에서 발견된 새 지문을 기존 대응표와 비교했다. 기준선·검사기 바이트는 현재 커밋과 같다.

첫 사전 확인에서 이전 복원 작업이 갱신했던 설정 파일 6개의 수정 시각을 원래 보관본 기준으로 복원했다. 당시 복원 구간과 파일 해시·권한이 일치함을 확인했다. 첫 확인은 증거 폴더에 검증 보조 스크립트가 빠져 실행본 교체 전에 중단됐다. 누락을 바로잡고 다시 확인해 통과했다.

실행본과 수집 미러는 변경된 상태이며, 게이트웨이 PID와 운영 HEAD `9cea8e323a016d9088b06f547bbe0ada660a3b3d`는 그대로다. 재시작·커밋·에이전트 기준선 갱신은 0회다. 운영 저장소의 근간 문구 수정 두 파일과 운영 기록은 후속 커밋 단계에 반영한다. 사장 기준선 갱신 뒤 재시작 및 실제 등록 검증이 남았다. AT-EQ-23은 자연 대화 관측 대기다.

증거는 작업 트리의 `.build/equip4/supplement2/`에 있다. `backup-location.json`, `applied-file-manifest.json`, `config-assemble-check.json`, `config-before-restart.log`, `sync.log`, `airport-check.log`, `pending-fingerprints.json`, `rollout-result.json`을 대조하면 된다.

| 파일 (`hermes/plugin-store/` 아래) | 옛 지문 | 새 지문 |
|---|---|---|
| `team-delegation/zoom_alarm_sync.py` | `4a3ef9d8eee14520` | `15918ce892c6cfa4` |
| `team-kit/ai_digest.py` | `21afcd32b2710419` | `48f20c53757dad43` |
| `team-kit/file_link_cleanup.py` | `deac531800862f62` | `2123755650e1f886` |
| `team-kit/lib/hermes_packs/linked_work/migrate_link_health.py` | `2a9d4b5894a54596` | `14dc246438837730` |
| `team-kit/lib/hermes_packs/linked_work/notion_completion_sync.py` | `2e132df8adefa73a` | `7de9e8f539af0439` |
| `team-kit/lib/hermes_packs/linked_work/request_link_decisions.py` | `76600e1763b109aa` | `31550f38ea9bae2d` |
| `team-kit/lib/hermes_packs/linked_work/source_adapters.py` | `7fd7eb99bf76d7b3` | `f903ca0bd49eec63` |
| `team-kit/lib/hermes_packs/linked_work/work_scope_backfill.py` | `bab7440a6b0b289f` | `6e60d0ec975b615a` |
| `team-kit/lib/hermes_packs/notes/obsidian_store.py` | `df5f43af486b327b` | `3f108367fabaa920` |
| `team-kit/lib/hermes_packs/notes/obsidian_store.py` | `1278f736e5ef60d7` | `52afaca2f17cec20` |
| `team-kit/lib/hermes_team_services/news_watch.py` | `9012bed04f1b4386` | `06e4d73abaa7f970` |
| `team-kit/lib/hermes_team_services/watchers_runner.py` | `cb1457eb00e2cfff` | `f8938ece6042c1bf` |

### 보완 2회 6단계 · 재시작·운영 검증·커밋

사장 기준선 정정본 `527d350b1369d3d29f55744780ad2b919a171fa7`을 확인했다. 중간 커밋 `08002d592440ef8d9000e9a3a842919da7bb318a`을 포함한 전체 기준선 차이는 보고한 지문 12개의 일대일 교체이며, 개수는 113개로 같다. 운영 기준선 내용과 두 검사 파일의 해시를 보존했다.

- 기존 준비본의 실행 원본·미러·보관본 118개 해시를 다시 대조했다. 유휴와 직전 시작 후 300초 조건을 확인했다. 임시 인덱스에서 실제 스냅샷 훅의 사전 검사를 통과한 뒤 게이트웨이를 승인 범위에서 1회 재시작했다.
- 재시작 뒤 현재 게이트웨이 프로세스가 쓰는 Python으로 재선택했다. 직원 설정 6개에서 승인된 도구 검색 키만 달라졌고, 조회 9구획은 2단계 기준과 바이트 단위로 같았다. 직원 6개 등록 덤프도 재시작 전과 바이트 단위로 같았다.
- 재시작 뒤 연결 수 hejo 6·Slack 6·photon 1을 확인했다. 기준 밖 오류, 중복 기준 경고, Discord 장애 표지는 모두 0건이었다. 기본 `./airport-check`는 종료 0이고 경계 집계는 79건이었다.
- 운영 저장소 `main`의 로컬 커밋은 `45d987f33b2263aa5c979b259ded96e58372c6e4`다. 부모는 사장 기준선 정정 커밋이다. `git commit --only`가 실행본 미러 118개, 운영 근간 파일 2개, 운영 기록 1개만 기록했다. 실제 커밋 훅의 스냅샷 검사는 종료 0이고 경계 집계는 80건이었다. 커밋·실행본 해시를 대조했다.
- 적용 보조 스크립트는 커밋 성공 뒤 훅 출력을 stdout에서만 찾는 오류로 종료 1을 냈다. 실제 `git commit --only`는 종료 0이었다. stdout·stderr를 합친 원본 커밋 로그에서 훅의 PASS를 확인했고, 독립 감사에서 커밋 범위·실행본·기준선·재시작 수를 재검증해 종료 0을 얻었다. 적용이나 재시작을 반복하지 않았다.

| 항목 | 증거 (`.build/equip4/supplement2-finish/` 아래) |
|---|---|
| 기준선 113개 및 12개 치환, 사전 확인·재시작 | `baseline-verification.json`, `operations.jsonl` |
| AT-EQ-22 설정 파싱, 로그 및 조립 4종 | `config-after-restart.log`, `after-log-check.json`, `assembly-after-restart.json` |
| AT-EQ-26 실행 중 Python과 조회·등록 비교 | `runtime-after.json`, `registry-after.json`, `after-registration.json` |
| 운영 검사, 사전 및 커밋 시 스냅샷 훅 | `airport-after.log`, `snapshot-preflight.log`, `ops-commit.log` |
| 커밋과 해시 재검증 | `final-audit.json` |

운영 검증은 수준 3이다. 재시작은 적용 1회·롤백 0회였다. AT-EQ-23은 자연 대화 관측 대기다. 운영 커밋은 로컬에 있으며 푸시는 별도 승인 절차로 남았다.
