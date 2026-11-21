# HEJO-FINDER-FOLDERS 명세: Finder 연결에서 서버 동기화 폴더 고르기

3판 · 2026-11-21(계획 검증 1회차 PR-01~04, 구현 검증 1차 V-1 반영) · 상태: 승인(계획 검증 2회차 APPROVED), 구현 검증 중 · 기준 커밋: 이 저장소 `9514f0f`, `<운영 저장소>` `66f2a44c`
요청 원문과 사장 결정: [brainstorm.md](brainstorm.md). 설계 [design.md](design.md), 작업 [tasks.md](tasks.md), 인계 [handoff.md](handoff.md), 수락 시험 [HEJO-FINDER-FOLDERS.md](../../../tests/acceptance/HEJO-FINDER-FOLDERS.md).

## 칸·원본·쓰기 주체·수명

| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| Finder 연결의 고르기 후보 만들기 | team-kit 시설(`<운영 저장소>` 칸) | `team-kit/lib/hermes_facility/app_setup.py`의 Finder 갈래(design 2절) | 개발(운영 저장소 규칙) | 갱신 때 교체 |
| Synology Drive 동기화 폴더 위치 찾기 | team-kit 시설 | 기존 `synology_setup.candidates`(유일한 목록, 새로 만들지 않음) | 개발 | 갱신 때 교체 |
| 고른 폴더 | 사장 금고 `owner/vault.yaml` `apps`(Finder 값) → 조립 결과 직원 `config.yaml` `team-kit.files.folders` | 기존 그대로 | 시설(사장 요청) | 영구 |
| 문·앱 | 바뀌지 않음 | — | — | — |

새 칸·두 번째 원본 없음. 문(`gate/`)·안내판(`schemas/`)·앱(`app/`)은 바꾸지 않는다.

## 1. 현황 (근거)

| # | 사실 | 근거 |
|---|---|---|
| 1 | [확인] 직원 파일 도구는 `files.folders`에 있는 서버 폴더를 쓴다. NAS 로그인은 공유 링크(`file_location`)에만 쓴다 | `files.py:150-162`, `:349-400`, `:424-470` |
| 2 | [확인] Finder 연결(`com.apple.finder`, `scope: folders`)의 후보는 `catalog.sync_folders`가 주는 서버 iCloud Drive와, 요청에 실려 온 절대 경로(`_requested_scope`)뿐이다 | `app_catalog.json:285-296`, `catalog.py:59-72`, `app_setup.py:142-150`, `app_connect.py:676-678` |
| 3 | [확인] 후보가 0개면 `SCOPE_EMPTY`로 고르기 단계에서 멈춘다. hejo 앱은 고른 것이 없으면 "확인하고 저장"을 끈다 | `app_connect.py:694-698`, `ConnectionsWindow.swift:463` |
| 4 | [확인] ddots는 서버 Mac에서 돌기 때문에 기본 폴더 고르기 창으로 경로를 `scope`에 실어 보낸다. hejo에는 그 단추가 없고, 사장은 다른 Mac에서만 hejo를 쓴다 | ddots `AgentAppConnections.swift:236-237·305-311`, brainstorm 사장 결정 |
| 5 | [확인] Synology Drive 동기화 폴더 후보는 이미 `synology_setup.candidates(home)`가 만든다(`Library/CloudStorage/SynologyDrive-*`, `SynologyDrive`, `Synology Drive`, 심볼릭 링크 제외) | `synology_setup.py:51-57` |
| 6 | [확인] 앱이 보낸 고른 id(절대 경로)는 문이 그대로 `--scope`로 넘기고, team-kit이 후보 id와 맞춰 저장한다. 후보 `id`·`label`은 문 공개 필드다 | `gate/connection_runtime.py:161-170`, `gate/connection_manager.py:17·322-333`, `app_connect.py:699-716` |
| 7 | [확인] 하위 폴더를 후보로 펼치는 선례: Obsidian 보관함 | `app_setup.py:109-113` |

## 2. 범위

- 안: team-kit Finder 고르기 후보(뿌리 폴더 + 두 단계 하위 폴더, 저장된 폴더 유지), 안내 문장, team-kit 시험, 서버 적용(team-kit 실행본 교체).
- 밖: 문·앱·안내판 변경, 앱 공개, 시놀로지 계정 연결 동작, 공유 링크, 서버 폴더 탐색 화면, 경로 직접 입력, 마감 알림 hejo 이전(B, 별도 작업), ddots 수정.

## 3. 요구와 수락 기준

### REQ-FF-01 서버 동기화 폴더가 Finder 후보로 나온다
- AC-01(정상): Given 서버 홈에 Synology Drive 동기화 폴더(`synology_setup.candidates`가 찾는 것), `Library/CloudStorage/` 아래 다른 동기화 폴더, iCloud Drive(`Library/Mobile Documents/com~apple~CloudDocs`)가 있다. When Finder 연결의 고르기 단계를 연다. Then 후보에 각 뿌리 폴더와, 뿌리 아래 1단계·2단계 하위 폴더가 나온다. 후보 `id`와 저장 값은 서버 절대 경로다(지금 Finder 후보와 같은 형식). `label`은 "뿌리 이름 › 하위 › 하위"이고, iCloud Drive 뿌리 이름은 "iCloud Drive", 나머지 뿌리는 폴더 이름 그대로다.
- AC-02(정상): 순서는 Synology Drive 뿌리 → 다른 `CloudStorage` 뿌리 → iCloud Drive. 같은 뿌리 안에서는 부모 바로 뒤에 자식이 오고(깊이 우선), 형제끼리는 이름 대소문자 무시 순서다.
- AC-03(경계): 이름이 `.`으로 시작하는 폴더, 자신이나 부모(서버 홈 위까지 모든 부모. 뿌리 자체와 `Library/CloudStorage`·`Library/Mobile Documents` 같은 중간 폴더 포함)가 심볼릭 링크인 폴더, macOS 꾸러미 폴더(이름이 `.app`·`.bundle`·`.framework`·`.photoslibrary`·`.musiclibrary`·`.tvlibrary`·`.pkg`·`.plugin`으로 끝남)는 후보와 하위 탐색에서 빠진다. 읽을 수 없는 폴더(권한 오류)는 그 폴더 아래만 건너뛰고 나머지는 나온다. 같은 실제 경로는 한 번만 나온다.
- AC-04(경계): 후보가 300개를 넘으면 300개만 보낸다. 고르는 규칙: 모든 뿌리의 깊이 0을 먼저, 그다음 모든 뿌리의 깊이 1, 남은 자리를 깊이 2로 채운다. 한 깊이 안에서 자리가 모자라면 AC-02의 화면 순서(뿌리 순서 → 깊이 우선)에서 앞선 것부터 넣는다. 보낸 목록의 순서는 AC-02 그대로다. 이때 고르기 응답 `next.hint`가 "폴더가 많아 일부만 보여요. 위 폴더를 고르면 그 안의 폴더도 함께 쓸 수 있어요."다. 300개 이하(정확히 300개 포함)이면 전부 보내고 이 안내가 없다.
- AC-05(실패): 뿌리가 하나도 없고 저장된 폴더도 없으면 기존처럼 `SCOPE_EMPTY`로 멈추되, Finder의 `hint`는 "서버에서 고를 수 있는 폴더를 찾지 못했어요. 서버 Mac에 Synology Drive나 iCloud Drive 동기화 폴더가 있는지 확인해 주세요."다. 파일 변경은 기존 `SCOPE_EMPTY`와 같다(진행 기록만).
- AC-06(경계): 후보 만들기는 폴더 항목 이름만 읽는다. 뿌리 폴더 아래의 어떤 파일도 만들거나 바꾸거나 열지 않는다(실행 전후 그 아래 sha256·목록 같음).

### REQ-FF-02 고른 폴더가 저장된다
- AC-01(정상): AC-01 후보 중 하나 이상(하위 폴더 포함)을 골라 제출하면 연결이 기존 Finder 연결과 같은 단계로 끝나고, 그 직원 조립 설정 `team-kit.files.folders`에 고른 서버 절대 경로가 들어가며 `files.enabled`가 켜진다(기존 `app_registry.file_settings`).
- AC-02(실패): 서버에 없는 경로를 `scope`로 보내면 기존과 같이 `SCOPE_INVALID`이고 금고·설정·명부 바이트가 그대로다.
- AC-03(회귀): 요청에 실린 서버의 기존 절대 경로(ddots의 폴더 고르기 창 경로)는 뿌리 밖이어도 지금처럼 받아들인다.

### REQ-FF-03 설정 바꾸기에서 고른 폴더가 유지된다
- AC-01(정상): Finder가 이미 연결돼 있고 고른 폴더가 두 단계보다 깊거나 뿌리 밖에 있어도(서버에 있음), "설정 바꾸기"의 고르기 단계 후보에 그 폴더가 나오고 미리 선택된다(`selected`). 이 후보는 300개 상한에 세지 않는다.
- AC-02(경계): 고른 폴더가 서버에서 사라졌으면 후보에 나오지 않고 미리 선택되지 않는다(기존 `selected_options` 규칙. 남은 것만 미리 선택).

### REQ-FF-04 다른 연결은 그대로다
- AC-01(회귀): `catalog.sync_folders`의 결과(다른 동기화 앱의 자동 분류, `test_app_catalog.py:103-111`), 다른 앱의 고르기 후보, 시놀로지 앱 연결의 `folders` 후보, 문·앱 프레임은 바뀌지 않는다. 관련 기존 시험은 모두 통과하고, team-kit 기존 시험 전체에는 이 변경으로 새로 생긴 실패가 없다(착수 HEAD 기준 집합 대비, AT-FF-12).

### NFR
- NFR-FF-01(개인값): 코드·시험에 실제 사람 이름·계정·경로를 넣지 않는다. 시험은 임시 `HOME`·`HERMES_HOME`과 가짜 폴더만 쓴다.
- NFR-FF-02(읽기 전용): REQ-FF-01.AC-06.
- NFR-FF-03(시간): [미확정] 실제 Synology Drive 폴더(온라인 전용 항목 포함)에서 후보 만들기에 걸리는 시간. 문의 `app connect` 제한 180초(`gate/connection_runtime.py:162`) 안이어야 한다. 서버 적용 뒤 사장 확인 M1에서 실제로 본다. 넘으면 멈추고 보고(깊이 줄이기는 사장 결정).

## 4. 사장 확인(서버 적용 뒤)
- M1: 다른 Mac의 hejo → 직원 연결 → Finder → "연결"을 누르면 서버의 Synology Drive 폴더와 그 하위 폴더가 보이고, 하나를 골라 저장하면 연결됨으로 바뀐다.
- M2: 그 직원에게 그 폴더에 시험 파일을 만들고 고치고 휴지통으로 옮기라고 시키면 된다(사장이 Finder에서 확인).
- M3: "설정 바꾸기"를 열면 고른 폴더가 미리 선택돼 있다.
