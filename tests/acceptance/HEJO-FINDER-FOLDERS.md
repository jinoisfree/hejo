# HEJO-FINDER-FOLDERS 수락 시험 명세

1판 · 2026-11-21 · 명세 [spec.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/spec.md), 설계 [design.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 대기. 기대값 출처: spec 요구와 design 2절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통: 임시 폴더를 서버 홈(`home`)으로 넘기고, 임시 `HERMES_HOME`에 가짜 직원 `alpha`. 폴더 이름은 `SynologyDrive-team`, `ExampleDrive-owner`, `Projects`, `2026` 같은 가짜 이름만. 실제 이름·경로 금지. "바이트 그대로"는 실행 전후 sha256 비교.

## team-kit (`HD` worktree `hermes/plugin-store/team-kit/tests/`의 새 시험 파일, 이름은 구현 담당)

`home` 준비(AT-FF-01~06 공통 기본):
`home/Library/CloudStorage/SynologyDrive-team/{Projects/{2026/{Q1/deep}, 2025}, Admin, .hidden/x, Photos.photoslibrary/y}`,
`home/Library/CloudStorage/ExampleDrive-owner/{Shared}`,
`home/Library/Mobile Documents/com~apple~CloudDocs/{Notes}`,
`home/Library/CloudStorage/SynologyDrive-team/Projects/link` → `home/Library/CloudStorage/ExampleDrive-owner`(심볼릭 링크),
파일 `home/Library/CloudStorage/SynologyDrive-team/Projects/readme.txt`.

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-FF-01 | FF-01.AC-01·02, FF-02.AC-01 | 기본 `home`. Finder 앱(`com.apple.finder`)을 alpha에 `app connect`(scope 없음) | 응답 `next.kind:'choose_scope'`. 후보 라벨 목록이 정확히 순서대로: `SynologyDrive-team`, `SynologyDrive-team › Admin`, `SynologyDrive-team › Projects`, `SynologyDrive-team › Projects › 2025`, `SynologyDrive-team › Projects › 2026`, `ExampleDrive-owner`, `ExampleDrive-owner › Shared`, `iCloud Drive`, `iCloud Drive › Notes`. 각 `id`는 해당 폴더의 절대 경로. `Q1`·`deep`(깊이 3 이상), `.hidden`, `Photos.photoslibrary`, `link`, `readme.txt` 없음. 잘림 `hint` 없음 |
| AT-FF-02 | FF-02.AC-01 | AT-FF-01에 이어 `SynologyDrive-team › Projects › 2026`의 `id`와 `ExampleDrive-owner`의 `id`를 `--scope`로 제출(재시작·권한 단계는 기존 Finder 시험과 같은 가짜 처리) | 연결 완료. alpha 조립 설정 `team-kit.files.folders` = 두 절대 경로(제출 순서), `files.enabled: true`. 금고 Finder 값 `scope` = 같은 두 경로 |
| AT-FF-03 | FF-01.AC-06, NFR-FF-02 | AT-FF-01 전후 | `home/Library` 아래 모든 파일·폴더 목록과 파일 sha256이 같음(`readme.txt` 포함) |
| AT-FF-04 | FF-01.AC-03 | 기본 `home` + `SynologyDrive-team/Locked`(권한 000, 아래에 `Inner`) | 후보에 `SynologyDrive-team › Locked`는 나오거나 빠질 수 있으나 `Locked › Inner`는 없음. 예외 없이 응답, 나머지 후보는 AT-FF-01과 같음(`Locked` 줄만 차이). 시험 끝에 권한 되돌림. root로 실행 중이면 `[미실행]` 표시 후 건너뜀 |
| AT-FF-05 | FF-01.AC-04 | `SynologyDrive-team` 아래 1단계 폴더 20개, 각 아래 2단계 폴더 20개(총 1+20+400) | 후보 정확히 300개. 뿌리 1개와 1단계 20개가 모두 들어 있음. `next.hint` = "폴더가 많아 일부만 보여요. 위 폴더를 고르면 그 안의 폴더도 함께 쓸 수 있어요." 같은 시험을 1단계 10개·2단계 10개(111개)로 돌리면 111개 전부, 잘림 `hint` 없음 |
| AT-FF-06 | FF-01.AC-05 | `home`에 `Library` 없음, 저장된 폴더 없음 | `reason:'SCOPE_EMPTY'`, `next.hint` = "서버에서 고를 수 있는 폴더를 찾지 못했어요. 서버 Mac에 Synology Drive나 iCloud Drive 동기화 폴더가 있는지 확인해 주세요." 금고·설정·명부 바이트 그대로 |
| AT-FF-07 | FF-01.AC-02·03(같은 경로) | 기본 `home` + 실제 폴더 `home/SynologyDrive`(아래 `Team`) | 뿌리 순서: `SynologyDrive-team`, `SynologyDrive`(둘 다 Synology 뿌리, `synology_setup.candidates` 순서), `ExampleDrive-owner`, `iCloud Drive`. `SynologyDrive-team`은 `synology_setup.candidates`와 `CloudStorage` 나열 양쪽에서 나오지만 한 번만 나옴. `SynologyDrive › Team` 있음 |
| AT-FF-08 | FF-03.AC-01 | alpha Finder 연결됨, 금고 Finder `scope` = [`…/SynologyDrive-team/Projects/2026/Q1/deep`(깊이 4), 뿌리 밖 `home/Work`(존재)]. `app connect --change values`(값 없음) | 응답 후보 = AT-FF-01의 9개 + 그 두 경로(맨 뒤, 금고 순서), `selected`가 그 두 `id`. 상한에 세지 않음: AT-FF-05의 큰 `home`(1단계 20·2단계 20)에 뿌리 밖 `home/Work`만 저장된 상태로 같은 요청을 하면 후보 301개(300 + `home/Work`) |
| AT-FF-09 | FF-03.AC-02 | AT-FF-08에서 `home/Work`를 지운 뒤 같은 요청 | 후보에 `home/Work` 없음, `selected`는 남은 하나만. 파일 쓰기는 기존 바꾸기 규칙과 같음(마지막 저장 전 쓰기 없음) |
| AT-FF-10 | FF-02.AC-02 | `--scope`에 `home/NoSuch`(없음) | `SCOPE_INVALID`, 금고·설정·명부 바이트 그대로 |
| AT-FF-11 | FF-02.AC-03 | `--scope`에 뿌리 밖 실제 폴더 `home/Elsewhere` | 지금처럼 받아들여 저장(`files.folders`에 그 경로) |
| AT-FF-12 | FF-04.AC-01 | team-kit 기존 시험 전체(`test_app_catalog.py`의 `sync_folders` 기대 포함, `test_app_connect.py`, `test_app_setup.py`, `test_synology_app_connect.py`) | 전부 통과. 기존 기대값 수정 없음(바꿔야 하면 멈추고 보고) |
| AT-FF-13 | NFR-FF-01 | 새 시험 파일과 바뀐 코드 | `python3 scripts/scan_private.py`(H, 해당 파일 대상 가능하면) 또는 `HD`의 개인값 검사(`./airport-check` 포함)에 걸리지 않음 |

## 사장 확인(서버 적용 뒤, 증거 수준 4)
spec 4절 M1~M3. M1에서 고르기 화면이 뜨기까지 걸린 대략 시간을 사장이 알려 주면 NFR-FF-03에 적는다.

## AC ↔ 시험 연결

| AC | 시험 |
|---|---|
| FF-01.AC-01 | AT-FF-01 |
| FF-01.AC-02 | AT-FF-01 |
| FF-01.AC-03 | AT-FF-01, 04, 07 |
| FF-01.AC-04 | AT-FF-05 |
| FF-01.AC-05 | AT-FF-06 |
| FF-01.AC-06 | AT-FF-03 |
| FF-02.AC-01 | AT-FF-02, M1 |
| FF-02.AC-02 | AT-FF-10 |
| FF-02.AC-03 | AT-FF-11 |
| FF-03.AC-01 | AT-FF-08, M3 |
| FF-03.AC-02 | AT-FF-09 |
| FF-04.AC-01 | AT-FF-12 |
| NFR-FF-01 | AT-FF-13 |
| NFR-FF-02 | AT-FF-03 |
| NFR-FF-03 | M1(실측) |
