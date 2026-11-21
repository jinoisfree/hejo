# HEJO-FINDER-FOLDERS 설계

2판 · 2026-11-21(계획 검증 1회차 PR-01~04 반영) · 상태: 초안(계획 재검증 대기) · 명세 [spec.md](spec.md). 약어: `H` 이 저장소, `HD` `<운영 저장소>`, `TKL` 실행 중인 team-kit 원본(`<HOME>/plugin-store/team-kit`), `TK` = `HD` worktree의 `hermes/plugin-store/team-kit`.

## 1. 책임과 흐름

```text
앱(바뀌지 않음) ─connection_action app_connect─▶ 문(바뀌지 않음) ─hermes-connections app connect --scope …─▶ team-kit app_connect
   ▲                                                                                                    │ adapters.scopes()
   └──────── next.kind=choose_scope, options[{id=서버 경로,label}], selected, hint ◀───────────────────────┘ Finder 갈래(이번 변경)
```

- 후보를 만드는 책임은 `TK/lib/hermes_facility/app_setup.py`의 `scopes()` Finder 갈래 한 곳이다. 함수로 떼어 낼지(같은 파일 안 새 함수 또는 `catalog.py`)는 구현 담당이 정하되, Finder 후보 규칙은 한 곳에만 둔다.
- Synology Drive 뿌리는 `synology_setup.candidates(home)`를 그대로 부른다. 같은 목록을 다시 만들지 않는다.
- `catalog.sync_folders`는 바꾸지 않는다. 이 함수는 다른 동기화 앱의 자동 분류(`catalog.py:26`)에도 쓰인다. Finder 갈래가 iCloud Drive 뿌리를 얻을 때 지금처럼 이 함수를 부르는 것은 괜찮다.
- 문·앱은 바뀌지 않는다. 후보의 `id`·`label`·`hint`·`selected`는 이미 문 공개 필드이고(`connection_manager.py:17`), 앱은 `options`를 켜고 끄는 목록으로 그리고 고른 `id`를 `scope`로 보낸다(`ConnectionsWindow.swift:191·445-452`).

## 2. Finder 후보 규칙

1. 뿌리 목록(순서대로, 실제 경로가 같으면 처음 것만):
   - `synology_setup.candidates(home)`의 경로
   - `home/Library/CloudStorage/` 바로 아래 폴더 중 위에 없는 것(이름 순서)
   - `catalog.sync_folders(app, home)`이 주는 iCloud Drive
   - `home`은 지금 함수들과 같이 기본값 `Path.home()`이고, 시험은 임시 폴더를 넘긴다.
2. 각 뿌리에서 깊이 2까지 하위 폴더를 깊이 우선으로 나열한다. 형제는 이름 `casefold()` 순서. 빼는 것: 이름이 `.`으로 시작, 자신 또는 부모가 심볼릭 링크(기존 `synology_setup.candidates`와 같은 검사: 후보와 그 모든 부모 `is_symlink()`. 세 종류 뿌리 모두와 하위 폴더에 같은 검사를 적용한다. CloudStorage 나열·iCloud 뿌리도 예외 없음), 꾸러미 확장자(spec REQ-FF-01.AC-03 목록), 폴더가 아닌 것. `PermissionError`·`OSError`가 나는 폴더는 그 아래만 건너뛴다. 파일은 열지 않는다(`os.scandir`의 항목 종류와 `is_symlink`·`is_dir` 검사만 쓴다. `open()`·`os.open`·내용 읽기·`stat` 이외 메타데이터 읽기 없음. 온라인 전용 항목을 내려받게 하는 읽기를 하지 않는다). 이 금지는 AT-FF-03의 감사 훅(`sys.addaudithook`의 `open` 사건)으로 관측한다.
3. 상한 300: 전체 후보를 모은 뒤, 깊이 0 전부 → 깊이 1 전부 → 깊이 2 순서로 자리를 준다. 한 깊이 안에서 자리가 모자라면 화면 순서(2항)에서 앞선 것부터. 보낼 목록은 뽑힌 것을 화면 순서로 다시 늘어놓은 것이다. 전체가 300을 넘을 때만 잘림이고, 그때만 spec AC-04 `hint`를 단다(정확히 300개는 잘림 아님). 상한 300은 [제안] 값이다(화면 목록이 스크롤로 다룰 수 있는 크기. 근거 수치 없음. 바꾸려면 사장 결정).
4. 라벨: 뿌리 이름(iCloud Drive는 "iCloud Drive", 나머지는 폴더 이름) + ` › ` + 하위 이름들.
5. 저장된 폴더: `selected.get('scope')`(설정 바꾸기·다시 연결 때 금고 값, `app_connect.py:568`)의 경로 중 서버에 있는 폴더이고 1~4에서 나오지 않은 것은 맨 뒤에 붙인다. 라벨은 위 뿌리 안이면 같은 규칙, 밖이면 폴더 이름. 상한에 세지 않는다.
6. 요청에 실려 온 경로(`_requested_scope`)는 지금 코드 그대로 받아들여 후보에 넣는다(`app_setup.py:146-149`. ddots 폴더 고르기 창 경로).
7. 후보 모양은 지금과 같다: `dict(id=경로, label=라벨, value=경로)`.
8. 안내 문장 전달 계약(PR-03):
   - `adapters.scopes(home, app, selected, config)`의 반환값은 지금처럼 후보 목록(list)이다. 다른 앱 갈래와 호출자는 바뀌지 않는다.
   - Finder 갈래만 `selected['_scope_hint']`에 안내 문장을 넣는다: 잘렸으면 spec AC-04 문장, 후보 0개면 spec AC-05 문장, 그 밖에는 키를 넣지 않는다. `_`로 시작하는 키는 저장되지 않는 임시 값이다(`app_connect.py:373·424`가 저장 때 뺌. `_requested_scope`·`_secrets`와 같은 통로).
   - `app_connect.py:694-698`의 고르기 대기 응답(`CHOOSE_SCOPE`·`SCOPE_EMPTY` 둘 다)은 `selected.get('_scope_hint')`가 있으면 그것을 `hint`로 쓰고, 없으면 지금 동작 그대로다(`SCOPE_EMPTY`의 기존 문장, `CHOOSE_SCOPE`는 hint 없음). 이 `app_connect.py` 변경은 TASK-02 범위에 반드시 들어간다.

## 3. 기존 경로 판정

| 경로 | 판정 | 이유 |
|---|---|---|
| `app_setup.scopes()` Finder 갈래(`catalog.sync_folders` + `_requested_scope`) | 교체 | 2절 규칙으로 바꾼다. `_requested_scope` 처리는 그대로 남긴다 |
| `catalog.sync_folders` | 유지 | 다른 동기화 앱 분류에 쓰임. 바꾸지 않음 |
| `synology_setup.candidates` | 유지(재사용) | Synology 뿌리의 유일한 목록 |
| 시놀로지 앱 연결의 NAS 폴더 후보(`synology_setup.folders`) | 유지 | 공유 링크가 필요한 사장을 위해 그대로 |
| ddots 폴더 고르기 창 | 유지 | ddots 무수정. team-kit이 같으므로 ddots Finder 화면에도 새 후보가 함께 보인다(의도된 변화) |
| 문·앱 | 유지 | 계약 그대로 |

## 4. 대안

| 대안 | 판단 |
|---|---|
| 2절 두 단계 목록(team-kit만) | 채택. 문·앱·공개 없이 해결. 위 폴더를 고르면 아래 전체를 쓴다 |
| 서버 폴더 탐색 동작(`app folders`)+문 중계+앱 탐색 화면 | 기각(지금). 새 계약 3곳·앱 공개가 필요. 두 단계가 실제로 부족하면 후속 작업 |
| 뿌리만 후보로(하위 없음) | 기각. Synology Drive 전체를 줘야 해서 직원 범위가 너무 넓다 |
| 전체 하위 폴더(Obsidian처럼 `rglob`) | 기각. 동기화 폴더는 커서 느리고 온라인 전용 항목 나열 비용이 크다 |

## 5. 작업 방식·서버 적용

- 만들기(TASK-02): [HEJO-CONNECTIONS design 7.1](../HEJO-CONNECTIONS-20261120/design.md#71-team-kit은-운영-원본을-고치지-않고-만든다-pr-03-반영) 그대로. `HD` 착수 HEAD로 임시 worktree, 바꿀 파일마다 `TKL` 실행본 sha256 = worktree 기준 파일 sha256 확인(다르면 멈춤). 게이트웨이 환경 Python + 임시 `HOME`·`HERMES_HOME`으로 시험. 운영 원본·`./sync` 금지.
- 서버 적용(TASK-03, 별도 인계로만 허가): [HEJO-CONNECTIONS design 7.2](../HEJO-CONNECTIONS-20261120/design.md#72-서버-적용-task-05)의 team-kit 절차(보관본·sha256·임시 파일 이름 바꾸기·`status`/`apps` 확인·실패 시 복원 → `HD` merge·`./sync`·`./airport-check`·`git commit --only`).
  - 문 릴리스·앱 교체·앱 공개 없음.
  - [가정] 게이트웨이 재시작이 필요 없다: 바뀌는 파일은 `hermes-connections` 명령(매 요청 새 프로세스)이 읽는다. TASK-02에서 바뀐 파일을 게이트웨이 프로세스가 import하는지 확인해 impl-report에 적는다. import하면 TASK-03 인계에서 재시작 여부를 다시 정한다.

## 6. 위험

- 일반(공통 4절): 기존 연결 흐름의 후보만 늘린다. 인증·재확인·저장 경로는 그대로다. 사장 기기 화면에 서버 동기화 폴더 이름이 더 보인다(문 공개 필드 안, 로그에는 안 남음: 문 감사 기록은 동작·결과만 `connection_manager.py:288`).
- 롤백: TASK-02는 worktree 브랜치 버림. TASK-03은 보관본 복원(7.2).
