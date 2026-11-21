# HEJO-FINDER-FOLDERS 수락 시험 명세

4판 · 2026-11-22(AT-FF-15~17·20~23 추가: 한글 정규화·연결 창 높이, 3판: 구현 검증 1차 V-1로 AT-FF-12 기준 정정, 계획 검증 1회차 PR-01~04 반영, [plan-review.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/plan-review.md)) · 명세 [spec.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/spec.md), 설계 [design.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/design.md).
상태: 명세 완료 · 코드 미작성 · 미실행 · 독립 검토: 계획 검증 1회차 BLOCKED → 2판 반영, 재검증 대기. 기대값 출처: spec 요구와 design 2절. 구현 담당이 코드로 옮기며 기대값·합격 기준을 바꾸지 않는다(바꿔야 하면 멈추고 보고).

공통: 임시 폴더를 서버 홈(`home`)으로 넘기고(`resolve()`한 경로. macOS 임시 폴더의 `/var` 링크가 부모 링크 검사에 걸리지 않게), 임시 `HERMES_HOME`에 가짜 직원 `alpha`. 폴더 이름은 `SynologyDrive-team`, `ExampleDrive-owner`, `Projects`, `2026` 같은 가짜 이름만. 실제 이름·경로 금지. "바이트 그대로"는 실행 전후 sha256 비교.

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
| AT-FF-03 | FF-01.AC-06, NFR-FF-02 | 기본 `home`에 파일을 더 둠(`SynologyDrive-team/Admin/a.txt`, `ExampleDrive-owner/Shared/b.txt`, iCloud Drive `Notes/c.txt`, 깊이 3의 `Projects/2026/Q1/d.txt`). (가) 시험 준비와 전 sha256 계산을 끝낸 뒤, 자식 프로세스 하나에서 `sys.addaudithook`으로 `open` 사건(경로·모드)을 모두 기록하는 훅을 먼저 걸고, 같은 프로세스에서 실제 `hermes-connections` 진입점(설치된 `bin/hermes-connections`가 부르는 것과 같은 모듈·함수)을 `app connect --profile alpha --app com.apple.finder --json`으로 실행한다. 후보 생성 함수·`os.scandir`를 대역으로 바꾸지 않는다. 기록은 자식 프로세스가 끝날 때 `home` 밖 임시 파일에 쓴다 (나) 자식 종료 뒤 후 sha256 계산 | (가) 응답 후보가 AT-FF-01과 같음. 기록된 `open` 사건 중 경로가 `home/Library` 아래이고 그 경로가 일반 파일인 것이 0개(읽기·쓰기 모드 모두). 기록된 `open` 사건 수는 0보다 큼(훅이 실제로 동작함. 예: 모듈 import·설정 읽기) (나) `home/Library` 아래 모든 파일·폴더 목록과 파일 sha256이 전과 같음 |
| AT-FF-04 | FF-01.AC-03 | 기본 `home` + `SynologyDrive-team/Locked`(권한 000, 아래에 `Inner`) | 후보에 `SynologyDrive-team › Locked`는 나오거나 빠질 수 있으나 `Locked › Inner`는 없음. 예외 없이 응답, 나머지 후보는 AT-FF-01과 같음(`Locked` 줄만 차이). 시험 끝에 권한 되돌림. root로 실행 중이면 `[미실행]` 표시 후 건너뜀 |
| AT-FF-05 | FF-01.AC-04 | 기본 `home`을 쓰지 않고 사례마다 새 `home`을 만든다. 폴더 이름은 `c01`…·`g01`…처럼 0을 채운 번호(이름 순서 = 번호 순서). 저장된 폴더 없음. (가) `SynologyDrive-team`만: 1단계 23개, 각 아래 2단계 12개(1+23+276=300) (나) (가)에서 마지막 1단계 `c23` 아래에 2단계 `g13` 하나 더(301) (다) `SynologyDrive-team`만: 1단계 20개, 각 2단계 20개(1+20+400=421) (라) 여러 뿌리: `SynologyDrive-team`(1단계 10개, 각 2단계 30개 → 311), `ExampleDrive-owner`(1단계 2개, 각 2단계 2개 → 7), iCloud Drive(1단계 1개, 그 아래 2단계 1개 → 3). 합계 321 | (가) 300개 전부, AT-FF-01 순서 규칙대로, `next.hint` 키 없음 (나) 300개, 빠진 하나 = `SynologyDrive-team › c23 › g13`(화면 순서 맨 뒤의 깊이 2), `next.hint` = "폴더가 많아 일부만 보여요. 위 폴더를 고르면 그 안의 폴더도 함께 쓸 수 있어요." (다) 300개 = 뿌리 1 + 1단계 20 + 깊이 2 중 화면 순서 앞 279개(`c01`~`c13` 아래 20개씩 260개 + `c14` 아래 `g01`~`g19`), 같은 `hint` (라) 300개 = 뿌리 3 + 1단계 13개(세 뿌리 모두) + 깊이 2 중 화면 순서 앞 284개(모두 `SynologyDrive-team` 것). `ExampleDrive-owner`, `ExampleDrive-owner › c01`, `› c02`, `iCloud Drive`, `iCloud Drive › c01`이 모두 있고 `ExampleDrive-owner`·iCloud의 깊이 2는 없음. 보낸 순서는 화면 순서(Synology 뿌리와 그 하위 → Example → iCloud). 같은 `hint` |
| AT-FF-06 | FF-01.AC-05 | `home`에 `Library` 없음, 저장된 폴더 없음 | `reason:'SCOPE_EMPTY'`, `next.hint` = "서버에서 고를 수 있는 폴더를 찾지 못했어요. 서버 Mac에 Synology Drive나 iCloud Drive 동기화 폴더가 있는지 확인해 주세요." 금고·설정·명부 바이트 그대로 |
| AT-FF-07 | FF-01.AC-02·03(같은 경로) | 기본 `home` + 실제 폴더 `home/SynologyDrive`(아래 `Team`) | 뿌리 순서: `SynologyDrive-team`, `SynologyDrive`(둘 다 Synology 뿌리, `synology_setup.candidates` 순서), `ExampleDrive-owner`, `iCloud Drive`. `SynologyDrive-team`은 `synology_setup.candidates`와 `CloudStorage` 나열 양쪽에서 나오지만 한 번만 나옴. `SynologyDrive › Team` 있음 |
| AT-FF-08 | FF-03.AC-01 | alpha Finder 연결됨, 금고 Finder `scope` = [`…/SynologyDrive-team/Projects/2026/Q1/deep`(깊이 4), 뿌리 밖 `home/Work`(존재)]. `app connect --change values`(값 없음) | 응답 후보 = AT-FF-01의 9개 + 그 두 경로(맨 뒤, 금고 순서), `selected`가 그 두 `id`. 상한에 세지 않음: AT-FF-05의 큰 `home`(1단계 20·2단계 20)에 뿌리 밖 `home/Work`만 저장된 상태로 같은 요청을 하면 후보 301개(300 + `home/Work`) |
| AT-FF-09 | FF-03.AC-02 | AT-FF-08에서 `home/Work`를 지운 뒤 같은 요청 | 후보에 `home/Work` 없음, `selected`는 남은 하나만. 파일 쓰기는 기존 바꾸기 규칙과 같음(마지막 저장 전 쓰기 없음) |
| AT-FF-10 | FF-02.AC-02 | `--scope`에 `home/NoSuch`(없음) | `SCOPE_INVALID`, 금고·설정·명부 바이트 그대로 |
| AT-FF-11 | FF-02.AC-03 | `--scope`에 뿌리 밖 실제 폴더 `home/Elsewhere` | 지금처럼 받아들여 저장(`files.folders`에 그 경로) |
| AT-FF-12 | FF-04.AC-01 | (가) 관련 기존 시험 파일 `test_app_catalog.py`, `test_app_connect.py`, `test_app_setup.py`, `test_synology_app_connect.py`, `test_app_registry.py` (나) team-kit 기존 시험 전체(`tests/` 전부). 둘 다 임시 `HOME`·`HERMES_HOME`, 새 시험과 같은 환경 | (가) 전부 통과, 기존 기대값 수정 없음 (나) 실패·오류 node ID 집합이 착수 HEAD(`66f2a44c`)의 두 구현 파일로 같은 환경에서 돌린 집합의 부분집합(새 실패·오류 0). 기준 집합은 착수 HEAD에서 실제로 다시 돌려 기록한다(임시 `HOME`에 없는 실제 프로필·문서 Python·스크립트를 찾는 기존 시험 29개, 2026-11-21 [verdict.md](../../docs/changes/HEJO-FINDER-FOLDERS-20261121/verdict.md) V-1). 기존 시험 수정·skip 추가 금지(바꿔야 하면 멈추고 보고) |
| AT-FF-14 | FF-01.AC-03(부모 링크) | 사례마다 새 `home`. 진짜 폴더 `home/Real/OtherDrive-x/A/B`를 둔다. (가) `home/Library/CloudStorage`가 `home/Real`을 가리키는 심볼릭 링크, iCloud Drive는 정상 폴더(`Notes`) (나) `home/Library/Mobile Documents`가 진짜 폴더 `home/RealDocs`(안에 `com~apple~CloudDocs/Notes`)를 가리키는 링크, CloudStorage는 정상(`ExampleDrive-owner/Shared`) (다) CloudStorage 정상(`ExampleDrive-owner/Shared`)이고 그 안에 `LinkedDrive-y` → `home/Real/OtherDrive-x` 링크 (라) 정상 `SynologyDrive-team/Projects`, `ExampleDrive-owner/Shared`, 그리고 `ExampleDrive-owner/Alias` → `home/Real/OtherDrive-x/A` 링크 | (가) CloudStorage에서 온 후보 0개(`OtherDrive-x`·`A`·`B` 없음), 후보 = `iCloud Drive`, `iCloud Drive › Notes` (나) iCloud 후보 0개, 후보 = `ExampleDrive-owner`, `ExampleDrive-owner › Shared` (다) `LinkedDrive-y`와 그 하위 없음, `ExampleDrive-owner`·`› Shared`는 있음 (라) `Alias`와 그 하위(`B`) 없음, 나머지(`SynologyDrive-team`, `› Projects`, `ExampleDrive-owner`, `› Shared`)는 있음. 네 사례 모두 `home/Real` 또는 `home/RealDocs` 아래 경로를 `id`로 가진 후보 없음 |
| AT-FF-13 | NFR-FF-01 | 새 시험 파일과 바뀐 코드 | `python3 scripts/scan_private.py`(H, 해당 파일 대상 가능하면) 또는 `HD`의 개인값 검사(`./airport-check` 포함)에 걸리지 않음 |

### 4판 추가: 한글 정규화 (team-kit, 같은 시험 파일 또는 새 파일)

`home` 준비: 기본 `home` + `SynologyDrive-team` 아래에 이름을 **조합형(NFD)으로** 만든 폴더 `팀폴더`(`os.mkdir`에 `unicodedata.normalize('NFD','팀폴더')`), 그 아래 조합형 `회의록` 폴더와 파일 `a.txt`, 그리고 완성형으로 만든 다른 폴더 `팀폴더2`.

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-FF-15 | FF-05.AC-01 | Finder `app connect`(scope 없음) | `팀폴더`·`팀폴더 › 회의록` 후보의 `id`·`value`·`label`이 모두 NFC 문자열(`unicodedata.is_normalized('NFC', …)` 참)이고 각 폴더는 한 번만 나온다. `팀폴더2`는 별도 후보 |
| AT-FF-16 | FF-05.AC-02 | `팀폴더` 후보(NFC)를 골라 저장. 그 직원 조립 설정으로 `files.folders(config)`를 만들고, 실제 파일 도구 처리기(`file_list`, `read_file`)를 (가) 완성형으로 적은 `…/팀폴더` (나) 완성형 `…/팀폴더/회의록/a.txt` (다) `file_list`가 (가)에서 돌려준 `회의록` 경로 그대로 (라) 완성형 `…/팀폴더2`로 부른다 | 저장된 `files.folders` 값이 NFC. (가)(나)(다) 성공(목록·내용 반환), (라) 허용 폴더 밖 오류(지금과 같은 문장). `files.py`는 바뀌지 않았다(`git diff` 대상 아님) |
| AT-FF-17 | FF-05.AC-03 | 금고 Finder `scope`에 같은 폴더를 섞인 형태(앞부분 NFC + `팀폴더` NFD)로 저장한 상태에서 `app connect --change values` | 후보에 그 폴더가 NFC로 한 번만 있고 `selected`에 그 `id`. 그대로 제출하면 금고·`files.folders`에 NFC 값 하나 |

## 앱 (`app/Tests/ConnectionsTests.swift`, 4판 추가)

| ID | AC | 입력 | 기대 |
|---|---|---|---|
| AT-FF-20 | FF-06.AC-01 | 실제 `ConnectionsWindow`, `setPreferredLevel(펫 높이+1)`(기존 시험처럼 26), 가짜 문에서 `waiting`·`secret_set` 응답으로 입력 창 열기 | 입력 창이 붙어 있는 동안 연결 창 `level` = 선호 높이(26), `.normal` 아님. 입력 창 보임 |
| AT-FF-21 | FF-06.AC-02 | AT-FF-20 상태에서 연결 창 순서를 뒤로 보낸 뒤(`orderBack`) `show()` | 연결 창 `level` = 26, `isVisible`, 입력 창 보임(`attachedSheet?.isVisible`) |
| AT-FF-22 | FF-06.AC-03 | 입력 창이 열린 상태에서 (가) `confirmRestart` 알림 시트 (나) 지문 확인(`confirm` 대역이 호출될 때의 높이 기록) | 확인 중에는 `.normal`(기존 AT-HC-26과 같음), 끝나면 26으로 돌아오고 입력 창이 보임. 기존 AT-HC-25~27·AT-CM 앱 시험 전부 통과 |
| AT-FF-23 | FF-06.AC-04 | 앱 비활성 높이(`setPreferredLevel(.normal)`)로 입력 창 열기 | `level == .normal` |

## 사장 확인(서버 적용 뒤, 증거 수준 4)
spec 4절 M1~M3과 5.3절 M4~M6. M1에서 고르기 화면이 뜨기까지 걸린 대략 시간을 사장이 알려 주면 NFR-FF-03에 적는다.

## AC ↔ 시험 연결

| AC | 시험 |
|---|---|
| FF-01.AC-01 | AT-FF-01 |
| FF-01.AC-02 | AT-FF-01 |
| FF-01.AC-03 | AT-FF-01, 04, 07, 14 |
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
| FF-05.AC-01 | AT-FF-15 |
| FF-05.AC-02 | AT-FF-16, M5 |
| FF-05.AC-03 | AT-FF-17 |
| FF-06.AC-01 | AT-FF-20, M4 |
| FF-06.AC-02 | AT-FF-21, M4 |
| FF-06.AC-03 | AT-FF-22 |
| FF-06.AC-04 | AT-FF-23 |
