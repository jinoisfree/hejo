# 구현 인계: HEJO-ADT-LAUNCH-20261122 / 직원 C가 ADT-EYE를 직접 켜서 CCTV 확인 (1차 구현 보고, 2026-11-22)

1. **받은 설계:** `handoff.md` 2판(+`plan-review.md` 2회차 APPROVED와 PR-05 정정). base_commit: hejo `c6636dd`(작업 중 main `911d921`로 fast-forward), 운영 저장소 `dba8f4fb`. 위험도 일반(정정된 근거 3가지), 증거 수준 목표 2·4. 연합개발.
2. **구현자 판단 상태:** TASK-01 구현 완료(수준 2 대역·mutation까지, 실물 효과는 미확인 — 아래 4번 발견). TASK-02 **보류**(착수 조건 미충족). TASK-03 **부분**(AT-AL-06 시험만, 원인 미확인이라 생산 코드 미변경, AT-AL-07 미실행). TASK-04는 지시대로 하지 않음.
3. **변경 후 구조:** 입력 직전 검사는 그대로 `click.js`가 맡고 오류 문장만 `SESSION_WINDOW_NOT_FRONT:<맨 앞 창 주인 앱 이름>`이 됐다. `screen.Session.input`이 그 오류(`COVERED`)에 한해 `Session.refocus()`(= 기존 `focus.js focus` 경로, `remember`·복원 대상은 건드리지 않음)로 세션 창을 한 번 다시 올린 뒤 같은 `screen.input`을 한 번만 다시 부른다. 두 번째 입력도 Python 쪽 창 위치·크기 재확인과 `click.js` 검사를 전부 다시 거친다. 재시도 판단은 `watch.py`에 두지 않았다.

## 4. 더한 것 / 뺀 것

운영 저장소 worktree `../.worktrees/adt-launch-20261122`(브랜치 `adt-launch-20261122`, 기준 `dba8f4fb`), 커밋 `1d0f111a`.
- `cctv/click.js`: `SESSION_WINDOW_NOT_FRONT` 오류에 맨 앞 창 주인 앱 이름(없으면 `?`, 창이 하나도 없으면 `(none)`) 추가. 검사 항목·순서는 그대로.
- `cctv/screen.py`: `COVERED` 상수, `Session.focus()`(활성화에서 `focus.js focus` 호출을 뽑아낸 것, `activate`가 이를 쓰도록 바꿈), `Session.refocus()`, `Session.input` 재시도. 옛 "한 번 실패면 끝" 경로는 같은 함수 안에서 바뀌어 공존하는 옛 경로는 없다.
- `cctv/README.md`: 재시도 한 문장 추가(코드와 같은 변경에서 갱신).
- `cctv/tests/test_cover_retry.py`(새, 23개): AT-AL-01·02·03·03b·09와 click.js 앱 이름 시험.
- `cctv/tests/test_relive.py`: 기존 JXA 하네스에 `cover`·`noWindow` 옵션만 추가(기존 시험은 그대로).
- hejo worktree(브랜치 `role-workflow/13-fde6554d`): `main`(`911d921`)을 merge(fast-forward), 커밋 `f234d0b0c076e6cbbdd0c74ebb2107215d45e7c0`: `app/Tests/OptionWindowTests.swift`에 AT-AL-06만 추가. 생산 코드 변경 없음.
- 지운 것: 없음(대체한 구 경로가 없다).

**미착수(지시대로 멈춤):**
- TASK-02: 운영 저장소 주 작업 폴더에 `cctv/now.py`·`reference.py`·`settings.py`·`watch.py`의 **다른 작업 미커밋 변경**이 아직 남아 있다(`git status`, 이 보고 시점). handoff 10절에 따라 `watch._relive.fail`·`watch._focus_alert` 문장과 `now.py` SCHEMA 설명 변경, AT-AL-04·04b는 하지 않았다. 그 변경이 커밋되면 재착수 가능하다.

## 5. 설계와 달라진 점

- 설계 변경은 없다. 다만 발견(아래 10번 첫 항목) 때문에 **REQ-AL-01의 "한 번 다시 올리기"가 실제 hejo 창이 위에 있는 상태에서는 효과가 없다**는 사실이 새로 확인됐다. 설계 조건("앱 활성화만 다시는 효과가 없을 수 있다, 근거를 남긴다")에 따라 근거를 남기고 판단은 기획설계에 넘긴다.
- AC-AL-02 문구의 "`cctv_now` 결과의 `relive_result`에 `FakeCover`"는 AT-AL-09(전체 경로)로 확인했다.

## 6. 6절 형태를 쓴 곳 / 임시 코드

없음. `Session.focus()`는 `activate`와 `refocus`가 함께 쓰는 한 번의 `focus.js focus` 실행(같은 일을 하는 두 번째 경로가 아니라 하나로 합친 것)이다.

## 7. 변경 성격

의미 변경(입력이 막히면 1회에 한해 다시 올리고 다시 입력). 비교: AT-AL-01·02·03·03b 대역 시험의 전후와 기존 547개 시험 불변.

## 8. 시험

- `test_cover_retry.py` 23개. 각각 보호 계약:
  - 켜기(더블클릭)가 가려져 첫 입력이 막히면 올리기 2번·같은 좌표 입력 2번·복원 1번·횟수 1·다음 확인으로 이어짐(AC-AL-01).
  - 두 번 모두 가려지면 입력 2번만, `FakeCover`가 `last_result`·알림·`now.inspect` 결과에 남고 `ok:false`(AC-AL-02·09).
  - 다른 click 거부 6종과 창 변경 4종은 1번에 끝, 올리기 1번뿐(AC-AL-03).
  - 올리는 동안 창이 이동·리사이즈·소멸·화면 밖이면 두 번째 입력 없음, 올리기 실패(FocusFailed)면 입력 추가 없음·복원 1번·`last_error` 기록(AC-AL-03b, 전체 켜기 경로 포함).
  - click.js가 앱 이름을 붙이고 입력 이벤트는 보내지 않음.
  - 기대값은 이 문서·handoff의 숫자와 문구(좌표는 창 원점+비율 식으로 독립 계산).
- Mutation check(5개, 모두 시험이 실패하고 원복 확인): 재시도 제거(10 실패), 모든 실패를 재시도(10), 올리기 뒤 복원 대상 덮어쓰기(8), 입력 3번 허용(6), click.js 앱 이름 제거(3). hejo: `OptionWindows.updateLevels(false)`에 `makeKeyAndOrderFront` 삽입 → AT-AL-06 "never raises" 실패, 원복 확인.
- 지우거나 합친 시험: 없음.

## 9. 실행한 검증 (모두 이 작업 폴더·worktree에서)

운영 저장소 시험 환경: 게이트웨이 Python(`~/.hermes/installs/*/environments/*/venv/bin/python`) + `PYTHONPATH=~/.local/share/hermes-pytest:$HOME/.hermes/hermes-agent`, `PATH=/opt/homebrew/bin:$PATH`(운영 저장소 AGENTS.md 규칙).

| 항목 | 작업 전 | 작업 후 |
|---|---|---|
| `cctv/tests` 전체(pytest) | 547 passed, exit 0 (`/tmp/adt-launch/baseline-cctv.log`) | 570 passed, exit 0 (547+23, `/tmp/adt-launch/after-task01-cctv.log`) |
| `./airport-check` | exit 1: `FAIL assembly:hermes-soul-assemble count=1`, "기준선 줄이기 가능: 5건" (`/tmp/adt-launch/baseline-airport.log`). 같은 FAIL이 운영 저장소 주 작업 폴더에서도 남(작업 전부터, 이 작업과 무관) | exit 1, 항목·줄 수 동일(`/tmp/adt-launch/after-task01-airport.log`) |
| hejo 앱 시험 | — | `app/.build/app-tests --finder-picture`(빌드 `bash app/scripts/build.sh` 성공 후): `AT-FF-64 OPTION ACTIVATION PASS`, `AT-AL-06 OPTION DEACTIVATION PASS`, `APP_TEST_OK`, exit 0 (`/tmp/adt-launch/app-finder-picture.log`) |
| `python3 scripts/scan_private.py`(Hermes venv python) | — | exit 0, 지적 없음(바이너리 생략 줄만) |

- 증거 수준: TASK-01 수준 2(대역, 실제 `Session`·`screen.input`·`watch._relive`·`now.inspect`·click.js를 실행하고 `osascript`/`screencapture`만 대역). 수준 4는 미도달.
- **실행하지 않은 것:** hejo 전체 `bash scripts/test.sh`(gate pytest + 앱 전체)는 돌리지 않았다. 앱은 변경이 시험 한 파일뿐이라 `--finder-picture` 경로와 빌드만 확인했다. 검증 담당이 전체를 돌려 주길 바란다. `./airport-check` 작업 전 FAIL은 해소되지 않았다.
- 하위 에이전트 사용 없음(직접 구현).

## 10. 미검증 범위, 남은 위험, 발견

1. **[중요·확인] 다시 올리기가 실제 hejo 창을 치우지 못했다.** 현재 실행 중인 hejo(`/Applications/hejo.app`, 11-21 빌드)가 창 둘을 Windows App 세션 창 위에 두고 있고, Windows App이 맨 앞 앱인 상태에서 `focus.js focus`와 `AXRaise`를 실행해도 순서가 바뀌지 않았다([evidence/task01-reraise-observation.md](evidence/task01-reraise-observation.md)). 그대로면 같은 상황에서 두 번째 입력도 같은 이유로 막히고, 이제 막힌 이유(`...:hejo`)가 남는 것까지만 된다. 즉 AC-AL-08(스스로 켜서 성공)은 TASK-03의 hejo 쪽이 실제로 해결돼야 가능하다. 재시도 자체는 다른 앱 창이 가릴 때(예: 일반 창) 효과가 있을 수 있으나 그것도 실물로 확인하지 못했다.
2. **[확인] TASK-03 가설(1)이 재현되지 않았다.** 시험용 창(`OptionWindows.show`로 띄운 것)에서는 활성 중 펫+1 → 비활성 `.normal`로 내려도 새로 올라온 Windows App 세션 창 **뒤**에 놓였다. 진짜 hejo는 같은 동작인데도 위에 남았다. 차이 후보: 진짜 hejo의 ConnectionsWindow(첨부된 입력 시트 포함)·`restoreFocus`(= `NSApp.activate(ignoringOtherApps:true)` + `makeKeyAndOrderFront`를 확인·인증 창이 끝날 때 무조건 부름, AT-CM-35가 의도로 고정함), 진짜 hejo가 accessory 앱이라는 점. 실험 중 진짜 hejo가 스스로 앞 앱이 되는 순간이 두 번 보였다(사용자 조작과 구분하지 못함). 원인을 확정하지 못해 생산 코드를 바꾸지 않았다. 추측으로 순서 보정을 덧대지 않는다.
3. **[미실행] AC-AL-07**(새 빌드의 실물 창 순서, 증거 `evidence/`), **AC-AL-08**(사장 수동 질문). AC-AL-07은 새 빌드를 설치하지 않고는 정직하게 할 수 없고(지시: 설치 금지), 화면이 다른 사용으로 계속 바뀌어 한 변수 비교가 어려웠다.
4. [미검증] click.js의 `kCGWindowOwnerName` 실제 값(우리 시험은 대역 JXA). 실물에서는 위 관찰의 `listing`이 `kCGWindowOwnerName`을 쓰므로 키는 맞다.
5. 운영 저장소 커밋 `1d0f111a`는 **별도 브랜치** `adt-launch-20261122`에 있다. 주 작업 폴더 `main`에 다른 작업의 미커밋 변경이 많아 거기서 커밋하지 않았고 푸시도 하지 않았다. `main`으로의 반영(cherry-pick 등)과 운영 실행본 반영은 TASK-04 몫이다.
6. 같은 `.py`를 TASK-02가 `watch.py`·`now.py`에서 이어 고치므로, 위 미커밋 변경이 커밋된 뒤 이 브랜치를 그 위로 맞춰야 한다.

## 11. 범위 밖 기술 부채

- 운영 저장소 `./airport-check`가 작업 전부터 `assembly:hermes-soul-assemble count=1`로 실패한다(주 작업 폴더도 동일).
- `click.js`는 `runningApplications`에서 `Windows App`을 이름으로 첫 번째만 찾는다. 이름이 같은 프로세스가 둘이면 어긋날 수 있으나 현재는 하나만 보였다(관찰만).

## 12. 검증 역할이 특히 봐 줬으면 하는 곳

- `Session.input`이 `COVERED not in str(error)`로 오류를 구분하는 방식(stderr 꼬리 200자 안에 코드가 들어오는 것에 의존, 앱 이름은 코드 뒤라 잘리지 않음).
- `refocus`가 `previous`를 덮어쓰지 않는 것(두 번째 `focus.js focus`의 `previous`는 Windows App 자신이라 덮으면 복원이 틀어진다 — mutation 시험으로 고정).
- 10번의 1·2: 설계 판단이 필요한 쟁점(아래 요청).

**기획설계에 요청하는 판단**
- (A) TASK-03 원인 확인을 어떻게 이어갈지: ① 새 빌드를 임시로(설치 없이 `app/.build/hejo.app`) 띄워 화면 공간·입력 시트까지 갖춘 상태를 재현, ② 먼저 hejo를 새 빌드로 설치한 뒤 AC-AL-07 실행(설치 승인 필요), ③ `ConnectionsWindow.restoreFocus`의 무조건 활성화를 "hejo가 비활성이고 사용자가 다른 앱으로 간 경우에는 하지 않는다"로 바꾸는 설계 변경(AT-CM-35와 충돌 소지, 승인 필요).
- (B) 다시 올리기를 hejo가 위에 있는 경우에도 듣게 만들려면 다른 앱 창을 치우는(숨기거나 뒤로 보내는) 동작이 필요한데 그것은 다른 앱을 건드리는 것이라 하지 않았다. 유지할지, 다른 방법이 있는지 판단 요청.
- (C) TASK-02는 운영 저장소 미커밋 변경이 정리된 뒤 재착수.

## 13. 검토 대상 코드 상태

- hejo: worktree `../.worktrees/31ptpirh/role-workflow-13-fde6554d`, 브랜치 `role-workflow/13-fde6554d`, 커밋 `f234d0b0c076e6cbbdd0c74ebb2107215d45e7c0`(기준 main `911d921` 포함, 푸시 안 함).
- 운영 저장소: worktree `../.worktrees/adt-launch-20261122`, 브랜치 `adt-launch-20261122`, 커밋 `1d0f111a`(기준 `dba8f4fb`, 푸시 안 함).

---

# 2차 구현 보고: TASK-03R (2026-11-22, handoff 3판)

1. **판단 상태:** 부분 구현. Space 가설은 **기각**했고, 진단 중 **다른 확정 결함 하나**(활성화 없이 창이 층 4에 남음)를 찾아 고쳤다. 원래 증상(세션 창 위에 0층 hejo 창)은 새 빌드에서 재현하지 못했다. AC-AL-06R의 수정 후 유효 측정은 **미완료**(아래 사유). TASK-02는 운영 저장소 cctv 4파일 미커밋이 그대로라 하지 않았다. TASK-04·푸시·설치·재시작·Windows 입력 없음.
2. **base:** hejo main `56ddfcd`를 worktree 브랜치에 merge(`e56dec898a4b05ba40b6f1400f4f8127ffa94c9d`, 문서만 바뀌어 앱 코드 변동 없음). 이후 커밋 `d01b4fe1959ace091a2d9c13b8f8da4e95c139ec`. 운영 저장소 커밋 `1d0f111a` 불변.

## 진단 (증거: [evidence/task03r-diagnosis.md](evidence/task03r-diagnosis.md))
- 설치본 hejo는 pid 79124(2026-11-21 15:39 시작)로 켜져 있었다. `osascript quit`은 -128로 거절돼 `kill -TERM`으로 끄고, 임시 진단 빌드(가로채기 로그·창별 `level`·`collectionBehavior`·`isOnActiveSpace`)를 띄웠다. 진단 코드(`ZDiag.swift`와 `AppDelegate` 한 블록)는 커밋하지 않았고 지웠다(`git status` 깨끗, 작업 트리에 진단 흔적 없음).
- **Space 따라오기: 기각.** 옵션·연결·시트·설정 창 `collectionBehavior=0`(펫만 `canJoinAllSpaces`). 시험용 전체 화면 공간을 앞에 두면 hejo 창은 `isOnActiveSpace=false`이고 CGWindowList에 없다. hejo를 앞 앱으로 만들어도 창은 오지 않는다. 시험 때 Windows App 세션은 전체 화면이 아닌 1280×720 창이라 같은 공간이었다. 처음의 "두 공간에서 같은 창"은 같은 공간이었을 가능성이 크고, 사용자가 전체 화면 공간 안에서 연 창은 그 공간에 속하는 것이 정상이다.
- **확정 결함(고침):** `OptionWindows.prepare`가 활성화 성공 여부와 무관하게 `level(active:true)`(펫+1, 층 4)를 건다. 시스템 보안 창(SecurityAgent)이 앞에 있어 `NSApp.activate`가 안 먹히면(`NSApp.isActive=false`) 창이 층 4에 남아 다른 앱 위에 뜬다. 활성화가 없으면 비활성 알림도 없어 `updateLevels(active:false)`가 불리지 않는다. 수정 전 관찰: `hejo 설정 lvl=4 active=false`, CGWindowList `hejo@4`가 Windows App 위. 수정 후 같은 조건: `0->0`, 층 4 창 없음.
- **원인으로 확정 못 한 것:** `ConnectionsWindow.restoreFocus`(인증·확인 창이 끝나면 hejo를 무조건 앞으로, AT-CM-35 의도)와 사용자 메뉴 조작이 측정 중 hejo를 앞 앱으로 되돌렸다(사용자 사용과 겹쳐 구분 못함). 바꾸지 않았다.
- 한계: 이 결함은 `click.js`의 `SESSION_WINDOW_NOT_FRONT`(첫 **0층** 창 검사)의 원인이 아니다. 층 4 창은 0층 검사에 안 잡힌다(오히려 층 4 창이 세션 창을 가려도 `click.js`가 모르는 별개의 구멍이다, 기록만, `click.js` 변경 금지). 따라서 **AC-AL-08(켜기 성공)을 풀어 줄지는 이 수정만으로 보장되지 않는다.**

## 변경 (커밋 `d01b4fe`, `app/` 두 파일)
- `OptionWindows.swift`: `isActive` 훅(기본 `NSApp.isActive`) 추가, `prepare`가 `level(active:isActive())`를 쓴다. 활성화가 실제로 일어나면 기존 `applicationDidBecomeActive → updateLevels(active:true)`가 펫+1로 올린다. `ConnectionsWindow`는 이미 같은 방식이라 바꾸지 않았다. 다른 앱 창을 숨기거나 옮기는 코드 없음.
- `OptionWindowTests.swift`: AT-AL-06U 추가. AT-FF-64·AT-FF-60/61·AT-AL-06은 **기대값 불변**, 설정 부분에서 `OptionWindows.isActive={true}`(그 시험의 전제인 "활성")를 추가하고 `defer`로 되돌린다.

## 시험과 증거
- **AC-AL-06U 수정 전 실패·수정 후 통과:** 훅만 넣고 `prepare`를 안 고친 상태에서 `AT-AL-06U windows opened while the app is inactive stay normal` 실패(exit 1). `prepare` 수정 뒤 `AT-AL-06U INACTIVE OPEN PASS`, `APP_TEST_OK`(exit 0). 이 실패 실행이 mutation 확인을 겸한다.
- `app-tests --finder-picture <Pet>`(커밋 `d01b4fe`, 이 보고 직전 재실행): AT-FF-50..54, AT-FF-64, AT-AL-06U, AT-AL-06, AT-FF-60..61 PASS, `APP_TEST_OK`, exit 0.
- `bash app/scripts/test.sh`(HEJO_PYTHON=게이트웨이 Python): **exit 1**, `APP_TEST_FAILED assertion("AT-HC-27 show after onDismiss clears input and remains usable")`(`/tmp/adt-launch/app-test-full.log`). AT-HC-27은 연결 창이 키 창이 되어야 하는데, 이때 **SecurityAgent 대화상자(pid 71168, 17:10:31부터, 새 빌드 첫 실행 때 뜬 것)가 앞에 있어 앱 활성화가 막혔다.** 같은 환경에서 **변경 전 코드**(`HEAD` 앱 소스를 따로 빌드한 `app-tests-base`)도 똑같이 AT-HC-27에서 실패했다(`/tmp/adt-launch/app-test-base.log`). 즉 이번 변경 탓이 아니라 환경 문제다. 이 시험 뒤의 항목은 **실행되지 않았다.** 보안 대화상자가 닫힌 뒤 전체를 다시 돌려야 한다.
- `scan_private.py`(Hermes venv python): exit 0.
- **AC-AL-06R:** 증거 `evidence/ac-al-06r-*.txt`(주인 앱·층·순서만).
  - 설치본(11-21 빌드), 창 열린 채 `focus.js focus` 30초: 샘플 30개 모두 첫 0층 창이 Windows App, hejo 창은 모두 그 아래. 통과(원래 증상 재현 안 됨).
  - 새 빌드 수정 전(사용자 조작과 겹친 측정, `...prefix-userclicks`): 첫 0층 Windows App, 끝 구간 hejo가 층 4로 다시 앞(사용자 메뉴 조작·restoreFocus). 수정 전 보안 창 조건(`...prefix-securityagent`): 시작 시 `hejo@4`가 Windows App 위(결함), 포커스는 보안 창 때문에 `FOCUS_TIMEOUT`.
  - 새 빌드 수정 후(`...postfix-securityagent`): 같은 보안 창 조건에서 층 4 창 없음(`hejo@3,hejo@0,Windows App@0`)이나, 보안 창이 앞이라 `focus.js focus`가 `FOCUS_TIMEOUT`이라 **유효한 30초 측정이 아니다.** 보안 창이 닫혀야 "깨끗한 빌드로 수정 후 측정"을 다시 할 수 있고, 깨끗한 빌드는 첫 실행 때 또 보안 창이 뜰 가능성이 크다(사용자 확인 필요).
- 설치본 hejo는 측정 후 `/Applications/hejo.app`을 다시 켰다(새 pid 89437, 17:20:47). 끄고 켜는 사이 열려 있던 hejo 창 상태는 복구되지 않는다(앱 재시작 동작).

## 미검증·남은 것
1. 사용자 확인 필요: 화면에 SecurityAgent 대화상자(434×182, 층 1000)가 17:10:31부터 남아 있다. 내용은 열어 보지 않았고 건드리지 않았다. 닫힌 뒤: (a) `bash app/scripts/test.sh` 전체, (b) 깨끗한 빌드로 AC-AL-06R 수정 후 측정(`/tmp/adt-launch/scenario.sh`는 진단 훅이 필요해 쓸 수 없고, 깨끗한 빌드는 `measure.sh` 절차만 쓴다).
2. REQ-AL-03R의 원래 증상 원인은 **미확정**이다. 후보(다음 가설): (i) 사용자가 Windows App 전체 화면 공간에서 연 hejo 창은 그 공간에 속해 세션 창 위에 뜬다(따라오기가 아님, 코드 결함 아님), (ii) `restoreFocus`의 무조건 활성화·앞으로 올리기가 직원 C 작업 중 hejo를 앞으로 되돌린다(AT-CM-35 의도와 충돌, 설계 판단 필요).
3. 층 4 hejo 창이 세션 창을 가려도 `click.js`는 알지 못한다(`click.js`는 0층만 본다). 입력 직전 검사를 강화할지는 별도 판단(고위험 재분류 가능).
4. TASK-02는 운영 저장소 cctv 4파일 미커밋이 정리된 뒤.

---

# 3차 구현 보고: TASK-02 + hejo main 병합 (2026-11-22)

1. **판단 상태:** TASK-02 구현 완료(수준 2). hejo는 main(`d58248c`)을 merge하고 전체 `app/scripts/test.sh` exit 0을 얻었다. TASK-04·배포·게이트웨이 재시작·운영 실행본 반영·hejo 설치·Windows 입력·푸시 없음.
2. **코드 상태**
   - 운영 저장소 worktree `../.worktrees/adt-launch-20261122`, 브랜치 `adt-launch-20261122`: main `5348909a`(`d3632cbe` 이상, cctv 4파일이 `340b8274`로 커밋된 뒤)를 merge `16d39cd4`(충돌 없음, rebase 아님). TASK-02 커밋 `06c0ed194e258aadf78663827a50ab10a65b28c2`. 운영 저장소 주 작업 폴더는 건드리지 않았다. 아직 main에 반영·푸시되지 않았다.
   - hejo worktree `../.worktrees/31ptpirh/role-workflow-13-fde6554d`, 브랜치 `role-workflow/13-fde6554d`: main `d58248c`를 merge `14f1946381d3526ffe970fe847e199110d380d47`(충돌 없음). 이 merge가 앱 코드 2파일(`ConnectionsWindow.swift` 3줄, `ConnectionsTests.swift`, FINDER-FOLDERS 쪽 변경)을 가져왔다.

## TASK-02 변경 (`cctv/`)
- `watch._relive.fail`: "ADT-EYE에서 N번을 직접 눌러 주세요" 줄을 지우고 이유 + "오늘은 더 알리지 않아요"만 남긴다(이유 `why`는 가린 앱 이름·포커스·입력 오류 등 실제 값).
- `watch._focus_alert`: "세션 창을 앞으로 가져와 주세요"를 지우고 `원격 화면을 앞으로 가져오거나 캡처하지 못했어요: {실제 오류}`로 바꿨다. `data['last_error']` 기록은 그대로.
- `now.SCHEMA` 설명: "켜기·다시 틀기에 실패하면 시도한 것과 막힌 이유를 보고하고 사장에게 켜기·누르기를 부탁하지 않는다." 추가(지시문 그대로).
- `watch.py` 주석: "Escape itself is never retried" → "실패한 Escape는 다시 보내지 않는다(가려져 보내지지 않은 경우만 Session.input이 1회 재시도)".
- 그대로 둔 것: 화면 공유 끊김 알림(`SHARING_LOST`, 맥 로그인 요청)·재연결 제안. 이 둘은 에이전트가 할 수 없는 조치라 2판 범위 밖이다.
- `README.md`에 한 문장 추가.
- **같은 변경에서 지운 것:** 기존 `test_channel_messages.py`의 `ADT-EYE에서 {index}번을 직접 눌러 주세요` 단정(지운 문장을 고정하던 것)과 그 시험 이름의 `instruction`. 나머지 단정(제목·멈춤 이유에 채널 번호 사용)은 그대로다.
- **시험(새 파일 `tests/test_no_ask_for_help.py`, 7개):** AT-AL-04(입력 실패에 `FakeCover`, 꺼짐·하루 한도, 켜기 못 시작하는 이유), AT-AL-04b(`FocusFailed('FOCUS_TIMEOUT')`가 문장과 `last_error`에 있고 "가져와 주세요" 없음, `_look` 경로의 `SESSION_NOT_VISIBLE`), `cctv_now` 설명 지시. 금지 문구: `직접 눌러`·`켜 주`·`눌러 주세요`·`가져와 주세요`. 기대값 문구는 handoff AC에서 왔다.
- **Mutation(3개, 모두 실패 확인 후 원복):** 옛 "직접 눌러 주세요" 복원(4 실패), `_focus_alert`에 이유 대신 옛 문장 복원(2 실패), SCHEMA 지시 제거(1 실패).
- **AT-AL-09 재실행:** `test_cover_retry.py` 23개 전부 통과(전체 경로 `now.inspect`의 `relive_result`에 `FakeCover`, `ok:false` 포함).

## 검증 (게이트웨이 Python + PYTHONPATH 규칙, 운영 저장소 worktree)
| 항목 | merge 직후·변경 전 | 변경 후(`06c0ed19`) |
|---|---|---|
| `cctv/tests` | exit 1, **7 failed**, 563 passed(`/tmp/adt-launch/t2-baseline-cctv.log`) | exit 1, **같은 7 failed**, 570 passed(`/tmp/adt-launch/t2-after-cctv.log`) |
| `./airport-check` | exit 0, 기준선 줄이기 가능 5건, 모두 PASS | exit 0, 항목 동일(`t2-after-airport.log`). 커밋 훅에서도 통과 |
- 7 failed는 이번 변경과 무관한 **main의 기존 실패**다: `test_channel_index.py::test_site_rejects_invalid_vault_index[6개]`, `test_startup.py::test_missing_optional_icon_does_not_invalidate_site_settings`. main `5348909a` 순수 체크아웃에서도 같은 7개가 실패했다(`7 failed, 540 passed`). 원인은 `delivery.py`의 `missing delivery target` 오류로, 다른 작업(`HEJO-SLACK-MOVE` 340b8274 전환)이 설정 읽기에 배달 대상을 요구하게 만들어 이 시험의 금고 대역과 맞지 않게 됐다. 이 작업이 고치지 않았다(범위 밖, 기술 부채). 1차 보고의 570 passed는 그 전 기준이다.
- 이전 `./airport-check` FAIL(`assembly:hermes-soul-assemble`)은 main 쪽에서 해소돼 이번에는 PASS다.

## hejo (브랜치 `14f1946`)
- `bash app/scripts/test.sh`(HEJO_PYTHON=게이트웨이 Python): **두 번 실행**.
  - 첫 실행 exit 1, `AT-HC-27 show after onDismiss ...` 실패(`/tmp/adt-launch/t2-app-test-full.log`). 이때 SecurityAgent(pid 71168)가 앞에 있었다. 같은 시각 **변경 전 코드(`main` 앱 소스를 따로 빌드한 `app-tests-base`)**는 전부 통과(`APP_TEST_OK`, exit 0)해 단순 환경 탓으로 단정하지 못했다.
  - 같은 `app-tests` 이진을 두 번 더 실행: 둘 다 `APP_TEST_OK`, exit 0(`t2-branch-run1/2.log`).
  - **재실행 전체 `test.sh`: exit 0**(`/tmp/adt-launch/t2-app-test-full2.log`), AT-FF-64·AT-AL-06U·AT-AL-06 PASS. 이때 SecurityAgent는 이미 사라진 뒤였다.
  - 판단: AT-HC-27은 키 창·활성화 의존이라 앞에 시스템 대화상자가 있으면 간헐 실패한다. 우리 변경과 무관해 보이나 첫 실패의 정확한 원인(`restoreFocus` 타이밍인지 보안 창인지)은 분리하지 못했다. 재현되면 보고한다.
- `scripts/scan_private.py`(Hermes venv python): exit 0. 루트 `bash scripts/test.sh`의 gate pytest는 이 변경과 무관(gate 불변)해 돌리지 않았다.
- hejo 앱 코드는 이번 차례에 직접 바꾸지 않았다(merge만).

## 남은 것
1. 운영 저장소 브랜치 `adt-launch-20261122`(`06c0ed19`)를 main으로 반영하는 일은 배포(TASK-04) 몫이다. main에 다른 작업 미커밋(`airport` 점검에서 다른 세션의 앱 연결 4건 보고)이 있으면 그것과 겹치지 않는 파일만 다뤘다.
2. SecurityAgent가 닫혔으므로 AC-AL-06R의 깨끗한 빌드 수정 후 측정은 가능해졌다. 새 빌드를 첫 실행하면 키체인 확인 창이 다시 뜰 수 있어 사용자 시점 확인이 필요하다(이번에는 하지 않음).
3. V-6(활성화 지연 때 옵션 창이 잠시 `.normal`로 열림, REQ-FF-10) 실물 확인은 TASK-04 항목이다.
4. AC-AL-07·08, TASK-04(사장 승인) 미실행.

---

# 4차 구현 보고: TASK-04 운영 반영·게이트웨이 재시작 (2026-11-22, 사장 승인)

1. **판단 상태:** TASK-04 team-kit CCTV 운영 반영과 게이트웨이 재시작 1회 완료. hejo 앱 설치·Windows 입력·실제 고객 메시지·git push 없음. AC-AL-08(사장이 hejo에서 묻기)과 V-6 실물 확인은 남았다(아래).

## 반영 (운영 저장소)
- 브랜치 `adt-launch-20261122`에 운영 main `4a462420`을 merge(`a566566737fde11e95cbc41eba0ba3bfe13a4d84`, 충돌 없음, rebase 아님). 브랜치와 main의 차이는 정확히 내 cctv 9파일(`click.js`·`screen.py`·`watch.py`·`now.py`·`README.md`·`tests/test_relive.py`·`tests/test_channel_messages.py`·새 `tests/test_cover_retry.py`·`tests/test_no_ask_for_help.py`)뿐이었다.
- 시험: cctv tests **7 failed, 570 passed**. 실패 7건은 main `4a462420` 주 작업 폴더(깨끗)에서 돌려도 **같은 7건**(`7 failed, 540 passed`)이다(`test_channel_index` invalid_vault_index 6건, `test_startup` missing_optional_icon 1건). `./airport-check` exit 0, 모두 PASS(`/tmp/adt-launch/t4-after-cctv.log`, `t4-airport.log`).
- AGENTS.md 규칙 확인: 원본은 실행 중인 파일(`~/.hermes/plugin-store/team-kit`)이고 저장소 `hermes/`는 `./sync`가 채우는 사본이다. 그래서 **운영 실행본을 먼저 고치고**, 저장소 main은 브랜치로 맞췄다. 착수 전 `diff -r 운영 실행본 team-kit/…/cctv  운영 main …/cctv`가 완전히 같았고(다른 작업 미커밋 없음), 운영 주 작업 폴더 `git status` 미커밋 0이었다.
- **보관(롤백용):** `/tmp/adt-launch/backup-20261122-175618/`(`click.js`, `screen.py`, `watch.py`, `now.py`, `README.md`, `tests/test_relive.py`, `tests/test_channel_messages.py`, 수정 시각 보존 `cp -p`; 새 시험 2개는 "원래 없음, 되돌릴 때 삭제"를 `README-rollback.txt`에 적음).
- **운영 실행본 반영 17:56:24** (`~/.hermes/plugin-store/team-kit/lib/hermes_packs/cctv`의 위 9파일을 브랜치 내용으로 교체).
- **운영 main 반영:** 주 작업 폴더에서 `git merge --ff-only adt-launch-20261122`(main이 `4a462420` 그대로임과 미커밋 0을 확인한 직후). 새 main = **`a566566737fde11e95cbc41eba0ba3bfe13a4d84`**(내 커밋 `1d0f111a`, `06c0ed19`와 merge 커밋 2개 포함, 다른 작업 파일을 만지지 않음, 푸시하지 않음, `./sync`는 운영 실행본 = main이라 변화가 없어 돌리지 않음). `diff -rq 운영 실행본 cctv ↔ 운영 main cctv`: 차이 없음, `click.js`·`screen.py`·`watch.py`·`now.py` `cmp` 같음. 운영 실행본 경로에서 돌린 cctv tests도 같은 `7 failed, 570 passed`.

## 게이트웨이 재시작 (1회)
- 직전 상태: 게이트웨이 pid 33793/33801이 **17:42:32에 시작**(내 반영 17:56:24보다 앞) → 옛 코드. 처리 중인 턴: `gateway.log`·`agent.log`에 17:43 이후 대화 활동 없음.
- **17:57:22 `hermes --profile default gateway restart` 실행**(exit 0, 한 번만). 로그 `Shutdown phase: drain ... active_at_start=0, active_now=0, cron_at_start=0` → 진행 중인 턴·cron 없이 정지.
- **새 프로세스(launchd 관리) pid 83889, 시작 17:57:23 > 반영 파일 수정 17:56:24.** `gateway running with 13 platform(s)` 17:58:01. 재연결: `hejo`·`slack`·`photon` + 프로필 5개의 `hejo`·`slack` 모두 `✓ connected`(Slack 6개, iMessage photon 연결 로그 확인). cron 스케줄러 6개 프로필 tick 재개 17:58:02.
- `gateway.error.log`: 재시작 이후 새 줄은 **1줄**, `17:57:23 WARNING gateway.run: Dedicated gateway_restart notification was not delivered`(재시작 알림 대상 미설정, 이전 재시작 17:42:31에도 똑같이 찍힌 줄, 기능 오류 아님). 그 밖의 새 줄 없음. `hermes-plugin-store --check`: 연결 11곳 확인.
- 롤백은 필요하지 않았다(필요 시: 보관본 복원 → 새 시험 2개 삭제 → 같은 재시작·확인).

## hejo
- main `648ea17` merge: 브랜치 `role-workflow/13-fde6554d` = **`afd4837ff918fac1306481a38fa856b4ecabc889`**(충돌 없음, 앱 코드 `ConnectionsWindow.swift`·`ConnectionsTests.swift`가 FINDER-FOLDERS REQ-FF-12 변경으로 따라옴). `bash app/scripts/test.sh`(HEJO_PYTHON=게이트웨이 Python): **exit 0**(`/tmp/adt-launch/t4-app-test-full.log`, AT-AL-06U·AT-AL-06 PASS, SecurityAgent 없음). `scan_private.py` exit 0. 앱 설치는 하지 않았고, 설치본 hejo는 계속 pid 89437로 실행 중이다.

## 남은 것
1. **AC-AL-08(실물 켜기 성공):** 사장이 hejo에서 직원 C에게 "지금 낙화 하냐"고 묻고, `watch.json last_ask`에서 `relived: true`, `relive_result: "ok"`, `ok: true`와 켜기 뒤 캡처가 ADT-EYE인지 검증 담당이 확인한다. 이번에는 Windows에 입력하지 않았다. 지금 운영에서는 새 코드가 이미 돌고 있어, 이 질문이 막히면 `relive_result`에 가린 앱 이름이 남는다.
2. V-6(REQ-FF-10 옵션 창이 대화 창 앞): hejo 정식 배포 경로로 새 빌드를 설치한 뒤 실물 확인.
3. 운영 저장소 main(`a566566…`)과 hejo 브랜치(`afd4837…`)의 푸시는 사용자 승인 뒤 플러그인이 한다.

---

# 5차 구현 보고: hejo 기준 브랜치 merge (2026-11-22)

1. **판단 상태:** 로컬 main merge는 완료했다. **GitHub 원격 main(`github/main`)은 merge하지 못하고 멈췄다**(공통 조상 없음, 판단 필요). 운영 저장소·운영 실행본·게이트웨이·hejo 앱 설치·push는 건드리지 않았다.
2. **로컬 main merge:** `git merge main`(`94d03ba`, 변경은 FINDER-FOLDERS `impl-report.md` 한 파일) → 브랜치 `role-workflow/13-fde6554d` = **`c8009e0ce736c2e3039adc6eb19ca7cdfe81e639`**(충돌 없음, rebase·force 없음). 직전 `afd4837`에서 앱 코드 변동 없음.
3. **GitHub 원격 main:** `git fetch github` 성공(tip `f397bdb7bedfc766c2116ecdd07118cb3afdfc32`, "hejo 0.2.3"). `git merge github/main`은 **`fatal: refusing to merge unrelated histories`**로 거절됐다.
   - 근거: `git merge-base main github/main` 결과 없음(exit 1). 계획 담당 체크아웃(`~/paseo-work/hermes-hejo`)에서도 같다. `github/main`은 7커밋짜리 "hejo 0.1.0…0.2.3" 공개 릴리스 이력이고(루트 커밋 `c98de86`), 로컬 main은 465커밋 개발 이력(루트 `1ee8b99`)이다. 계획 담당 저장소에 별도 브랜치 `public`(= `f397bdb`)·`archive/public-0.2.0-before-parity`가 있어 공개 이력이 개발 이력과 따로 관리되는 것으로 보인다 [추정].
   - 두 트리는 같은 디렉터리 구성이지만 `git diff --shortstat github/main main`이 70파일 +7763/-134로 크다. `--allow-unrelated-histories`로 억지로 merge하면 겹치는 모든 파일이 add/add 충돌이 되고, 결과 이력은 공개 이력과 개발 이력을 영구히 이어 붙인다.
   - 그래서 `--allow-unrelated-histories`는 쓰지 않았다(지시: 충돌에서 두 작업 의도 판단이 필요하면 멈춤, rebase·force 금지). "푸시 대상이 `github`의 main인가"는 승인 정책 질문이다. 현재 `github` 원격의 푸시 URL은 플러그인 승인 화면 대리 주소다.
4. **시험(merge 후 `c8009e0`)**
   - `bash app/scripts/test.sh`(HEJO_PYTHON=게이트웨이 Python): **exit 0**, `APP_TEST_FAILED` 없음. 로그 `/tmp/adt-launch/t5-app-test-full.log`.
   - `scripts/scan_private.py`(Hermes venv python): **exit 0**. 로그 `/tmp/adt-launch/t5-scan.log`.
5. **선택지(계획 담당·사용자 판단):**
   - (a) 푸시 대상은 개발 이력의 별도 원격(또는 `github`의 새 브랜치)이다. 공개 `main`은 릴리스 절차로만 갱신한다. 이 경우 이 브랜치는 이미 개발 `main`(94d03ba) 기준으로 준비됐다.
   - (b) `github/main`에 이 개발 이력을 이어 붙이는 bridge merge를 한다(`--allow-unrelated-histories`, 70파일 add/add 충돌 정리와 공개 이력 영구 결합). 명시 승인과 충돌 해소 방침이 필요하다.
   - (c) 공개 `main`에는 릴리스 방식(앱 변경은 새 "hejo 0.x" 스냅샷)으로 반영하고 이 브랜치의 앱 변경(`d01b4fe` OptionWindows 외)을 포함시킨다. 별도 릴리스 작업이다.
   - 구현 담당 권고: (a) 또는 (c). (b)는 비가역적이다.

---

# 6차 구현 보고: hejo 로컬 main merge (2026-11-22)

1. **상태:** hejo 로컬 main `6c68e29`를 브랜치 `role-workflow/13-fde6554d`에 merge했다. `github/main`은 merge하지 않았고 `--allow-unrelated-histories`·rebase·force를 쓰지 않았다. 운영 저장소·운영 실행본·게이트웨이·hejo 앱 설치·push는 건드리지 않았다.
2. **merge 커밋:** **`8a1399f2094d8d00f41499d5e8597a8de0798139`**(충돌 없음). 직전 `c8009e0`과의 차이는 FINDER-FOLDERS 문서 3파일(`handoff.md`·`tasks.md`·`verdict.md`, +52/-2)뿐이고 앱 코드·이 작업의 변경은 그대로다. `git merge-base --is-ancestor main HEAD` 참. 작업 트리 깨끗.
3. **시험(`8a1399f`)**
   - `bash app/scripts/test.sh`(HEJO_PYTHON=게이트웨이 Python): **exit 0**, `APP_TEST_FAILED` 없음. 로그 `/tmp/adt-launch/t6-app-test-full.log`.
   - `scripts/scan_private.py`(Hermes venv python): **exit 0**. 로그 `/tmp/adt-launch/t6-scan.log`.
4. 이 브랜치에 이 작업의 hejo 변경은 `f234d0b`(AT-AL-06)와 `d01b4fe`(OptionWindows `isActive`, AT-AL-06U)이며, 로컬 main으로 빨리 감기할 수 있는 상태다(main은 이 브랜치의 조상).
