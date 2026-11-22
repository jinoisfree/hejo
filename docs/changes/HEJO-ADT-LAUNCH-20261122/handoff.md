# [설계 인계: HEJO-ADT-LAUNCH-20261122 / 직원 C가 ADT-EYE를 직접 켜서 CCTV 확인]

작은 일반 작업이라 spec·design·tasks를 이 문서 한 곳에 둔다(공통 6.4). 결정 근거는 [brainstorm.md](brainstorm.md).

## 0. 기준

| 항목 | 값 |
|---|---|
| hejo base_commit | `c6636dd7cc88da037dfe65799d7f53b726406fa5` (+ 다른 작업의 미커밋 변경, 아래 10절) |
| 운영 저장소 base_commit | `dba8f4fb8b4e832383d834e2863c1883d06885db` (+ 다른 작업의 미커밋 변경, 아래 10절) |
| 문서 판 | 3판, 2026-11-22 (2판 + 1차 검증 [verdict.md](verdict.md) 반영, 맨 끝 "3판 보완" 절) |
| 승인 | 범위·막힘 처리·두 저장소를 이 작업에서 모두 진행(사장, 2026-11-22). 계획 검증 켜기 |
| 운영 모드 | 연합개발(교차 모델 + 계획 검증) |

## 1. 공식 문서

- hejo 근간: `docs/ARCHITECTURE.md`. 운영 저장소 근간: `<운영 저장소>/AGENTS.md`, `<운영 저장소>/docs/ARCHITECTURE.md`, CCTV 팩 `hermes/plugin-store/team-kit/lib/hermes_packs/cctv/README.md`, `<운영 저장소>/docs/직원 C.md`.
- `<운영 저장소>`의 로컬 경로는 `AGENTS.local.md`에 있다. 추적 파일에 쓰지 않는다.
- 관련 진행 작업: `docs/changes/HEJO-FINDER-FOLDERS-*`의 TASK-11 보완(AT-FF-64, 비활성 때 옵션 창 내리기).

## 2. 요구와 수락 기준

문제: 직원 C가 `cctv_now`로 CCTV를 확인하다가 화면이 Windows 바탕화면(`ADT-EYE 꺼짐`)이면 ADT-EYE 아이콘을 더블클릭해 켠다. 2026-11-22 16:19에 클릭 직전 검사(`click.js`)가 `SESSION_WINDOW_NOT_FRONT`로 막혔다. 그러자 직원 C가 사장에게 "켜 주면 다시 볼게"라고 넘겼다.
- [확인] 같은 시각 `focused: true`.
- [확인] 2026-11-22 확인 시점에 Windows App이 맨 앞 앱인데도 0층 창 순서가 hejo '연결', hejo '에이전트 연결', Windows App 툴바, Windows App 세션 순이었다. 지금 바로 클릭하면 같은 오류가 난다.
- [가정] 16:19에도 같은 hejo 창이 가렸다.

| ID | 요구 |
|---|---|
| REQ-AL-01 | 켜기·다시 틀기 입력 직전 검사가 "다른 앱 창이 맨 앞"으로 막히면, 원격 세션 창을 한 번 더 앞으로 올리고 검사·입력을 한 번만 다시 한다. 그래도 막히면 맨 앞 창의 앱 이름을 실패 이유에 남긴다. 입력 직전 검사(맨 앞 0층 창이 Windows App 것인지, 점이 세션 안인지, 창 위치·크기 불변)는 약화하지 않는다. |
| REQ-AL-02 | 켜기·다시 틀기가 실패해도 직원 C는 사장에게 ADT-EYE를 켜거나 채널을 눌러 달라고 부탁하지 않는다. 무엇을 시도했고 무엇에 막혔는지(가린 앱 이름 포함)만 보고한다. 해당 문장: `watch._relive`의 `fail` 알림, `watch._focus_alert` 알림(재포커스 실패 포함, 지금은 "세션 창을 앞으로 가져와 주세요"라고 부탁하고 실제 이유를 보이지 않음), `cctv_now` 도구 설명. `_focus_alert`는 실제 오류 이유를 문장에 넣는다. 범위 밖: 화면 공유 끊김 알림(`SHARING_LOST`, 맥 로그인 필요)과 재연결 승인 제안은 에이전트가 할 수 없는 조치라 그대로 둔다. |
| REQ-AL-03 | hejo가 비활성이 된 뒤 hejo의 옵션 창·연결 창(입력 시트 포함)이 새로 활성화된 다른 앱의 창보다 위(같은 0층 안의 앞 순서 포함)에 남지 않는다. |

| AC | 종류 | Given / When / Then |
|---|---|---|
| AC-AL-01 | 정상 | Given 첫 입력 직전 검사가 `SESSION_WINDOW_NOT_FRONT`(맨 앞 앱 이름 포함)로 실패하고 두 번째는 성공하는 대역 실행기. When `ADT-EYE 꺼짐`으로 켜기 시도. Then 앞으로 올리기가 정확히 2번, 같은 좌표의 입력 스크립트 호출이 정확히 2번이고 켜기 흐름이 다음 확인으로 이어진다. 이전 앱 복원은 끝에서 1번. 하루 사용 횟수는 1만 늘어난다. |
| AC-AL-02 | 실패 | Given 두 번 모두 `SESSION_WINDOW_NOT_FRONT`이고 맨 앞 앱이 가짜 이름 `FakeCover`인 대역. When 켜기 시도. Then 입력 스크립트 호출은 2번뿐이다. `relive.last_result`와 `cctv_now` 결과의 `relive_result`에 `FakeCover`가 들어간다. 하루 사용 횟수는 1만 늘어난다. 이전 앱 복원은 1번. |
| AC-AL-03 | 경계 | Given 입력 직전 검사가 `INPUT_OUTSIDE_SESSION`, `WINDOWS_APP_MISSING`, `ACCESSIBILITY_PERMISSION_REQUIRED`, `SESSION_WINDOW_REQUIRED`, `WINDOWS_APP_NOT_FRONT` 중 하나로 실패하거나 Python 쪽 `INPUT_WINDOW_CHANGED`. When 입력. Then 다시 올리기·다시 입력 없이 1번에 실패한다(기존 동작 유지). |
| AC-AL-04 | 정상 | Given 켜기·다시 틀기 실패 사유 하나. When 예약 감시 알림 문장을 만든다. Then 문장에 사유가 들어가고 "직접 눌러"·"켜 주"·"눌러 주세요"가 없다. `cctv_now` 도구 설명에 "다시 틀기·켜기에 실패하면 시도한 것과 막힌 이유를 보고하고, 사장에게 켜기·누르기를 부탁하지 않는다"는 지시가 있다. |
| AC-AL-05 | 회귀 | CCTV 팩 기존 시험(`cctv/tests/`) 전체와 `./airport-check`가 통과한다. 실패가 작업 전부터 있던 것이면 작업 전 결과를 함께 남긴다. |
| AC-AL-06 | 정상 | Given hejo 시험 하네스에서 옵션 창 하나와 연결 창(입력 시트 포함)이 보이는 상태. When 비활성 처리(`applicationDidResignActive` 경로). Then 각 창의 level이 `.normal`이다. 그리고 비활성 처리 뒤 hejo가 이 창들을 앞으로 다시 올리는 호출(`makeKeyAndOrderFront`·`orderFront*`)을 하지 않는다. 재활성 때는 펫+1로 돌아온다. |
| AC-AL-07 | 실물(수준 4) | Given 실제 화면에서 hejo '에이전트 연결' 창과 입력 시트가 열려 있고 hejo가 맨 앞. When 직원 C와 같은 경로로 Windows App 세션 창을 앞으로 올린다(`focus.js focus …` 실행 뒤 `focus.js restore`). Then 그 사이 읽은 화면 순서(CGWindowList)의 첫 0층 창 주인이 Windows App이다. 그 전후 창 목록을 증거로 남긴다. Windows에는 입력을 보내지 않는다. |
| AC-AL-03b | 경계 | Given 첫 입력이 `SESSION_WINDOW_NOT_FRONT`. When (a) 재포커스 뒤 세션 창이 이동·리사이즈·소멸했거나 (b) 재포커스 자체가 실패(`FocusFailed`). Then 두 번째 입력 스크립트 호출이 없다. (a)는 `INPUT_WINDOW_CHANGED`로 `fail`, (b)는 `FocusFailed`로 `_focus_alert` 경로에 가며 `relive.last_result`에 그 이유가 남는다. 두 경우 모두 이전 앱 복원은 끝에서 1번, 하루 사용 횟수는 1만 늘어난다. |
| AC-AL-04b | 정상 | Given `FocusFailed('FOCUS_TIMEOUT')` 같은 포커스 실패. When `_focus_alert` 문장을 만든다. Then 문장에 그 이유가 들어가고 "가져와 주세요"·"직접 눌러"·"켜 주"·"눌러 주세요"가 없다. `data['last_error']` 기록은 기존대로다. |
| AC-AL-08 | 실물 성공(수준 4, 사장 수동 질문) | Given 배포(TASK-04) 뒤 원격 화면이 Windows 바탕화면(ADT-EYE 꺼짐), 원격 세션 연결됨, 화면 공유 정상, hejo 연결 창이 열려 있음, 오늘 다시 틀기 한도 남음. When 사장이 hejo에서 직원 C에게 "지금 낙화 하냐"고 묻는다. Then 그 회차 `last_ask`에서 `relived: true`, `relive_result: "ok"`, `ok: true`(판독불가 아님)이고, 켜기 뒤 캡처가 ADT-EYE 화면이다. 사장이 앱을 열거나 누르지 않는다. **이 성공 증거가 없으면 작업 판정은 최대 부분 완료다.** 실패 문장만 맞는 것으로는 통과하지 않는다. |
| AC-AL-09 | 실패 보고(수준 2 + 관측) | Given 켜기 입력이 두 번 모두 막히는 대역(`FakeCover`). When `now.inspect` 전체 경로. Then 결과 `relive_result`에 `FakeCover`가 있고 `ok: false`다. 실물에서 실패가 나면 직원 C 답에 켜기·누르기 부탁이 없는지 그 답글로 확인한다(관측됐을 때만 기록, 일부러 실패를 만들지 않는다). |

## 3. 반드시 유지할 기존 계약

- `cctv_now` 도구 이름·인자 없음·결과 키(`relived`, `relive_result`, `focus`, `capture` 등)·180초 제한. 상태 파일 `watch.json` 형식. `relive` 하루 한도와 "입력 전에 예산 저장".
- 재연결은 사장 승인 뒤에만 한다(`executor.py`). 이 작업은 재연결을 바꾸지 않는다.
- `click.js`가 허용하는 명령(right/left/double/escape)과 입력 직전 검사 항목. 오류 코드 이름 `SESSION_WINDOW_NOT_FRONT`은 유지하고 뒤에 `:<앱 이름>`만 붙인다.
- `Session`의 한 번 깨어날 때 포커스 한 번 기억·끝에서 한 번 복원.
- hejo: 활성 때 옵션 창 높이 = 펫+1(REQ-FF-10, AT-FF-60·61), 연결 창 확인 중 `.normal` 예외.

## 4. 책임과 흐름

- 입력 직전 검사는 `click.js`가 맡는다. 앞으로 올리기와 한 번 다시 시도는 `screen.Session`이 맡는다(지금도 활성화·복원 담당). 다시 시도 판단을 `watch.py`에 두지 않는다.
- 실패 문장은 두 곳이다. 입력·판독 실패는 `watch._relive`의 `fail`, 포커스 실패(재포커스 실패 포함)는 `watch._focus_alert`. 재시도 중 재포커스 실패는 `Session.activate`가 내는 `FocusFailed` 그대로 `_relive`의 `except FocusFailed` 경로로 간다(새 오류 종류를 만들지 않음). 대화 답의 말투는 `now.py` `SCHEMA` 설명이 지시한다.
- hejo 창 높이·순서는 `OptionWindows`(공용)와 `ConnectionsWindow`(예외)가 맡고, 활성 변화 알림은 `AppDelegate`가 전한다.

## 5. 기존 경로 판정

| 경로 | 판정 |
|---|---|
| `click.js` 맨 앞 검사 | 유지. 오류 문장에 앱 이름만 붙임 |
| `screen.Session.input` | 교체: 앞의 한 가지 오류에 한해 한 번 다시 올리고 다시 입력. 옛 "한 번 실패면 끝" 경로는 같은 함수 안에서 바뀌므로 공존 없음 |
| `watch._relive.fail` 문장 | 교체: 부탁 문장 제거 |
| hejo 비활성 때 창 내리기 | HEJO-FINDER-FOLDERS AT-FF-64 보완이 같은 파일에서 진행 중. 그 결과를 유지하고, 이 작업은 "내린 뒤 순서가 다른 앱 위에 남는 문제"만 더한다 |

## 6. 위험도와 증거 수준

- 위험도: 일반. 근거(실패 영향과 복구):
  - 최악의 실패는 클릭 한 번이 다른 창에 가는 것이다. 대상은 원격 Windows의 CCTV 보기 프로그램 화면 또는 이 맥의 다른 앱 창이다. 카메라·녹화 장치 설정, 자료 삭제, 사람 안전에 닿는 동작이 아니며, 잘못된 클릭은 창 닫기·Escape로 되돌릴 수 있다.
  - 재시도는 입력 전 거부 검사를 하나도 빼지 않는다. 두 번째 입력 직전에도 Python 쪽 창 위치·크기 재확인과 `click.js` 맨 앞·세션 안 검사가 그대로 다시 돈다(AC-AL-03b). 재시도 대상은 `SESSION_WINDOW_NOT_FRONT` 하나, 횟수는 1번이다.
  - 하루 한도·입력 전 예산 저장·재연결 사장 승인 경계는 바뀌지 않는다(3절).
  - 따라서 "안전 동작" 자체(입력 전 거부)는 바뀌지 않아 고위험으로 올리지 않는다. 구현 중 검사 항목을 바꿔야 하면 그 자리에서 멈추고 고위험으로 재분류한다.
- 필요한 증거 수준
  - team-kit TASK: 2(대역), 그리고 배포 뒤 4(AC-AL-08 성공, 사장 수동 질문). AC-AL-08 없이는 최대 부분 완료.
  - hejo TASK: 2(시험 하네스), 그리고 4(AC-AL-07).
- 롤백
  - team-kit: 배포 전 운영 실행본의 바뀌는 파일을 작업 폴더 밖 임시 위치에 복사해 두었다가 되돌린다.
  - hejo: 이전 `/Applications/hejo.app`을 보관했다가 되돌린다.

## 7. 변경 성격

의미 변경이다. 비교는 AC-AL-01~03의 대역 시험과 기존 CCTV 시험의 전후 결과로 한다.

## 8. 수락 시험

| 시험 | 위치 | 기대값 출처 | 명세 / 코드 / 실행 / 독립 검토 |
|---|---|---|---|
| AT-AL-01~03 | `<운영 저장소>` `team-kit/lib/hermes_packs/cctv/tests/test_relive.py`(또는 같은 폴더 새 파일) | 이 문서 AC, `click.js` 오류 코드 | 명세 완료 / 구현 담당 작성 / 미실행 / 검증 때 |
| AT-AL-03b | 같은 폴더 | AC-AL-03b | 같음 |
| AT-AL-04 | 같은 폴더 | AC-AL-04, AC-AL-04b 문구 | 같음 |
| AT-AL-09 | 같은 폴더(`test_now.py` 등) | AC-AL-09 | 같음 |
| AT-AL-05 | 기존 `cctv/tests/`, `./airport-check` | 기존 | 작업 전 결과를 먼저 기록 |
| AT-AL-06 | `app/Tests/OptionWindowTests.swift` | AC-AL-06 | 명세 완료 / 구현 담당 작성 / 미실행 / 검증 때 |
| AT-AL-07 | 수동 실물. 증거는 `docs/changes/HEJO-ADT-LAUNCH-20261122/evidence/` | AC-AL-07 | 명세 완료 / 미실행 |
| AT-AL-08 | 사장 수동 질문, 상태 파일·캡처 확인은 검증 담당 | AC-AL-08 | 명세 완료 / 미실행 |

수락 시험 코드는 구현 담당이 이 명세대로 쓴다. 검증은 기대값이 이 문서에서 왔는지 독립 확인한다.

## 9. 작업 범위

| TASK | 내용 | 파일 | 선행 |
|---|---|---|---|
| TASK-01 | REQ-AL-01: `click.js` 오류에 맨 앞 앱 이름, `Session.input` 한 번 다시 올리기·다시 입력, AT-AL-01~03 | `cctv/click.js`, `cctv/screen.py`, `cctv/tests/` | 없음 |
| TASK-02 | REQ-AL-02: `watch._relive.fail`·`watch._focus_alert` 문장, `now.py` `SCHEMA` 설명, AT-AL-04, AT-AL-09 | `cctv/watch.py`, `cctv/now.py`, `cctv/tests/` | TASK-01. 아래 10절 동시 수정 조건 |
| TASK-03 | REQ-AL-03: hejo 비활성 때 창 순서. 원인 확인 → 수정 → AT-AL-06, AT-AL-07 | `app/Sources/OptionWindows.swift`, `ConnectionsWindow.swift`, `AppDelegate.swift`, `app/Tests/OptionWindowTests.swift` | HEJO-FINDER-FOLDERS AT-FF-64 보완 커밋 |
| TASK-04 | 배포(이번 구현 인계에 포함하지 않음, 별도 승인). 아래 착수 조건 | 운영 실행본, `/Applications/hejo.app` | TASK-01~03 검증 통과 + 사장 승인 |

**TASK-01 세부**
- 앞으로 올리기는 지금의 `focus.js focus`와 같은 경로를 다시 쓰거나, 세션 창을 실제로 같은 층 맨 앞으로 올리는 방법을 쓴다.
- 확인된 상태에서는 Windows App이 이미 맨 앞 앱인데도 hejo 창이 위에 있었다. 그래서 "앱 활성화만 다시"는 효과가 없을 수 있다. 실제로 순서를 바꾸는지 구현 담당이 근거를 남긴다.

**TASK-03 세부**
- 먼저 원인을 확인한다. 후보 [가정]
  - 활성 때 펫+1 층에 있던 창이 `.normal`로 내려오면서 0층의 맨 앞 순서에 남는다.
  - 비활성 중 `ConnectionsWindow`의 `restoreFocus`·`show` 등이 `makeKeyAndOrderFront`를 부른다.
- 확인 결과와 수정 방식을 impl-report에 적는다.

**TASK-04 착수 조건(배포 인계 전에 확정)**
- 운영 저장소 `AGENTS.md`의 플러그인 코드 로드 규칙을 따른다. `now.py` 도구 설명은 게이트웨이 프로세스에 실리므로 파일 반영만으로 바뀌지 않는다. `cctv_now` 작업자(`python -m …now`)와 예약 감시는 호출마다 새 프로세스로 코드를 읽는지 확인해 적는다.
- 절차: 사장의 게이트웨이 재시작 승인 → 처리 중인 턴과 다른 작업의 미커밋 변경이 없음을 확인 → 바뀌는 운영 실행본 파일을 작업 폴더 밖에 보관 → 반영 → `hermes --profile default gateway restart` 한 번 → 새 프로세스 시작 시각이 파일 수정 시각보다 뒤인지 확인 → `gateway.log`의 플랫폼 재연결과 `gateway.error.log` 새 줄 없음 확인.
- hejo 앱: 이전 `/Applications/hejo.app` 보관 → 새 빌드 설치 → 앱 재시작(사장 사용 중이면 시점 승인).
- 롤백: 보관본 복원 → 같은 재시작·확인 절차를 다시 한다. 파일 복사만으로 배포 완료를 판정하지 않는다.

**금지 범위**
- `click.js` 검사 항목 완화, 재연결 자동화, 하루 한도 변경, 지시서·금고 값 변경.
- Hermes 본체, ddots. TASK-01~03에서 게이트웨이 재시작·운영 실행본 반영·hejo 앱 설치(TASK-04에서만, 승인 뒤).
- 실제 고객 메시지와 Windows 세션 입력. AC-AL-07은 포커스·창 목록만 다룬다. 사장의 AT-AL-08은 예외다.

**병렬 갈래: 없음**(갈래 3개 미만: team-kit TASK-01→02는 선행 관계, hejo TASK-03은 1갈래).

## 10. 가정·미확정과 착수 차단

- 운영 저장소: `cctv/now.py`·`reference.py`·`settings.py`·`watch.py`에 다른 작업(hejo 이전)의 미커밋 변경이 있다. 운영 실행본 `~/.hermes/plugin-store/team-kit`도 같은 내용이다.
  - TASK-01은 겹치지 않는 파일만 고친다. 별도 worktree(`<운영 저장소>` 기준 `origin/main` 또는 HEAD)에서 구현·시험한다.
  - TASK-02는 그 미커밋 변경이 커밋된 뒤 착수한다. 아직이면 멈추고 보고한다. 다른 작업의 변경을 덮어쓰거나 함께 커밋하지 않는다.
- hejo: `AppDelegate.swift`·`OptionWindows.swift`·`OptionWindowTests.swift`에 HEJO-FINDER-FOLDERS TASK-11 보완(AT-FF-64)의 미커밋 변경이 있다. TASK-03은 그 커밋 뒤에 착수한다. 아직이면 멈추고 보고한다.
- 운영 저장소 반영·푸시는 그 저장소 규칙(`AGENTS.md`의 자기 파일만 커밋, `./airport-check`, 기준선 증가 금지)을 따른다. 에이전트는 git push를 하지 않는다.
- 16:19의 가린 창이 hejo였다는 점은 [가정]이다. TASK-01의 앱 이름 기록으로 다음 실패 때 확인된다.

## 11. 사용자 확인

사장이 2026-11-22 브레인스토밍에서 범위, 막힘 처리, 한 작업에서 두 저장소 진행을 정했다. 운영 저장소의 "Hermes 작업은 그 프로젝트에서" 규칙은 사장 지시로 이 작업만 예외로 한다.

## 인계 전 점검

- [확인] hejo `c6636dd`, 운영 저장소 `dba8f4fb`.
  - 위 미커밋 변경 외에는 바뀐 계약이 없다.
  - 미커밋 변경은 10절의 착수 조건으로 다룬다.
- G1~G4: 요구·AC·시험·TASK가 연결되어 있다. 미확정 사항은 착수 조건으로만 남는다. 계획 검증 1회차 BLOCKED 지적 5건을 모두 반영했다(2판). 재검증을 기다린다.

## 3판 보완 (1차 검증 부분 완료 반영, 2026-11-22)

근거: [verdict.md](verdict.md) V-1·V-2(설계 오류), V-3(환경), V-4(비차단). 이 절이 2판의 REQ-AL-03·AC-AL-06·TASK-03보다 우선한다. 나머지 2판 내용과 plan-review 정정은 그대로다.

**사장 승인(2026-11-22):** 진단·수정을 위해 실행 중인 hejo 앱을 잠깐 끄고 새 빌드를 띄워 시험해도 된다. Windows에는 입력하지 않는다. 끝나면 원래 `/Applications/hejo.app`을 다시 켠다. 새 빌드 설치(교체)는 이 승인에 들지 않는다(TASK-04, 별도 승인).

**새 원인 후보 [가정]:** hejo 옵션·연결·설정 창이 사용자가 간 화면 공간(Space)으로 따라와서 Windows App 세션 공간에서도 앞에 뜬다.
- [확인] 검증자 관찰: 바탕화면 공간(Finder 맨 앞)과 Windows App 세션 공간 양쪽에서 같은 hejo 창이 0층에 보였다.
- 후보 기전
  - `.accessory` 앱(`AppMain.swift:13`)이 비활성 중 기존 창에 `makeKeyAndOrderFront`·`orderFront`·`NSApp.activate`를 부르면 창이 현재 공간으로 옮겨진다. 해당 호출: `ConnectionsWindow.restoreFocus`·`show`·`presentInput`, `OptionWindows.show` 등.
  - 창 `collectionBehavior` 기본값과 레벨 변경의 상호작용.

| ID | 요구·기준 (2판 REQ-AL-03·AC-AL-06 대체) |
|---|---|
| REQ-AL-03R | 사용자가 hejo 밖의 다른 앱·다른 화면 공간으로 가 있는 동안 hejo의 옵션·연결·설정 창(입력 시트 포함)은 그 공간으로 따라오지 않고 그 앱의 창 위에 남지 않는다. hejo를 다시 열면 지금처럼 펫 위에 보인다(AT-FF-60·61·64 유지). |
| AC-AL-06R | 실물(수준 3, 새 빌드). 진단 전(설치본)과 수정 후(worktree 빌드)에 같은 절차로 측정한다. Given hejo '에이전트 연결' 창(입력 시트 포함)과 'hejo 설정' 창이 열려 있음. When 직원 C 경로로 Windows App 세션 창을 앞으로 올리고(`focus.js focus`), 30초 동안 hejo가 메시지 수신·연결 새로 고침을 겪게 둔다(가짜 홈이 아닌 실제 연결이면 실제 고객에게 보내지 않는다). Then 그동안 1초 간격으로 읽은 CGWindowList의 첫 0층 창이 늘 Windows App 것이다. 수정 전 측정은 실패, 수정 후 측정은 통과해야 한다. 끝에 `focus.js restore`로 원래 앱에 돌려준다. 증거: `evidence/`에 전후 창 목록(창 제목·장치 이름 제외, 주인 앱·층·순서만). |
| AC-AL-06U | 자동 시험. 진단으로 확정한 기전 그대로를 시험 하네스에서 관측한다. 예: 비활성 중 특정 호출이 창을 앞으로 올리거나 공간을 옮기는지. 수정 전 코드에서 실패하고 수정 후 통과함을 기록한다(mutation 또는 전후 실행). 2판 AT-AL-06은 회귀 시험으로 남긴다. |

**TASK-03R**
1. 먼저 worktree 브랜치에 hejo `main` 최신(확인 시점 `56ddfcd`)을 merge한다.
2. 진단
   - 설치본 hejo가 켜져 있는지 기록하고 끈 뒤, worktree 빌드 `app/.build/hejo.app`을 띄운다.
   - 창별 `collectionBehavior`·`level`·`isOnActiveSpace`와 비활성 중 앞으로 올리는 호출을 확인한다.
   - 임시 진단 로그는 커밋하지 않고 끝나면 지운다.
3. 확정한 원인 자리에서 고친다. 공용 규칙은 `OptionWindows`, 예외는 `ConnectionsWindow`다. 다른 앱 창을 숨기거나 옮기는 방식은 금지한다.
4. AC-AL-06U와 AC-AL-06R의 수정 전·후를 측정하고, 끝나면 설치본 hejo를 다시 켠다.
5. 원인이 공간 이동이 아니면 그 근거와 다음 가설을 적고 멈춘다(추측 보정 금지).

**TASK-01 보완(V-4, 비차단)**
- `Session.input`이 가려진 Escape도 1회 재시도하는 것은 유지한다. 첫 시도는 보내지지 않았으므로 실제 Escape는 최대 1번이다.
- `watch.py`의 "Escape itself is never retried" 주석은 TASK-02에서 "실패한 Escape는 다시 보내지 않는다(가려져 보내지지 않은 경우만 1회 재시도)"로 고친다.

**TASK-02**: 착수 조건 그대로. 운영 저장소 cctv 4파일의 다른 작업 미커밋 변경이 커밋되기 전에는 하지 않는다. 시작하면 `adt-launch-20261122` 브랜치를 그 커밋 위로 맞춘다.

**REQ-AL-01**: 유지한다. 막힌 이유(가린 앱 이름)를 남기고, 일반 창이 가린 경우에는 효과가 있을 수 있다. 켜기 성공(AC-AL-08)의 열쇠는 REQ-AL-03R이다.
