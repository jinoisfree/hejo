# TASK-03R 진단 기록 (2026-11-22)

방법: 설치본 `/Applications/hejo.app`(pid 1개, 2026-11-21 15:39 시작)의 30초 측정 뒤 `kill -TERM`으로 끄고(`osascript quit`은 -128로 거절됨), worktree 빌드 `app/.build/hejo.app`에 임시 진단 코드(`NSWindow`의 `makeKeyAndOrderFront`·`orderFront`·`orderFrontRegardless`·`setLevel`·`orderOut`, `NSApp.activate(ignoringOtherApps:)` 가로채기 로그, 창별 `level`·`collectionBehavior`·`isOnActiveSpace` 1초 로그)를 넣어 띄웠다.
진단 코드와 로그는 커밋하지 않았고 지웠다. Windows에는 입력하지 않았다. 증거에는 주인 앱·층·순서만 있다(창 제목·장치 이름 없음).

## 1. 창이 화면 공간(Space)을 따라오는가 → 아니다 (가설 기각)

| 관찰 | 값 |
|---|---|
| 옵션·연결·입력 시트·설정 창의 `collectionBehavior` | 0(기본). 펫 패널만 337(`canJoinAllSpaces`·`fullScreenAuxiliary`·`stationary`·`ignoresCycle`) |
| 시험용 전체 화면 공간(자체 만든 창 하나)을 앞으로 띄움 | hejo 창들 `isOnActiveSpace=false`, CGWindowList에 hejo 창은 펫(층 3)뿐 |
| 그 상태에서 hejo를 앞 앱으로 만듦(System Events `frontmost`) | 창들은 계속 `isOnActiveSpace=false`(공간이 옮겨 오지도, 공간이 전환되지도 않음), 앞 앱만 hejo |
| 시험 때 Windows App 세션 | 1280×720 일반 창(전체 화면 공간 아님). hejo 창들과 같은 바탕화면 공간이라 `isOnActiveSpace=true`가 계속 유지됨 |

→ 창은 만들어진 공간에 남는다. 따라오지 않는다. (처음 검증자 관찰의 "두 공간에서 같은 창"은 같은 공간이었을 가능성이 크다. 사용자가 Windows App 전체 화면 공간에서 hejo 창을 열었다면 그 창은 그 공간에 속해 세션 창 위에 뜬다. 이것은 따라오기가 아니라 사용자 배치다.)

## 2. 확인된 결함: 활성화가 일어나지 않았는데 창이 펫+1(층 4)에 남는다

- 조건: 시스템 보안 창(SecurityAgent. 새로 만든 빌드를 처음 띄울 때마다 떴고 내용은 열어 보지 않았다. 사용자 확인 창일 가능성이 크지만 [미확인])이 앞에 있어 `NSApp.activate(ignoringOtherApps:true)`가 받아들여지지 않은 채(`NSApp.isActive == false`) hejo가 옵션 창을 연다.
- 수정 전 관찰: `hejo 설정` 창 `lvl=4`, `active=false`가 몇 십 초 이어졌고(진단 로그 `state` 줄), CGWindowList에서 `hejo@4`가 Windows App 창보다 위(`ac-al-06r-newbuild-prefix-securityagent.txt`의 첫 줄 `order=hejo@4,hejo@3,hejo@0,Windows App@0`).
- 원인: `OptionWindows.prepare`가 활성화 결과와 상관없이 `level(active:true)`를 건다. 활성화 알림이 오지 않으면 비활성 알림도 오지 않아 `updateLevels(active:false)`가 불리지 않는다.
- 수정 후 같은 조건: `hejo 설정` `0->0`(로그), `lvl=0`, `ac-al-06r-newbuild-postfix-securityagent.txt`의 첫 줄 `order=hejo@3,hejo@0,Windows App@0,hejo@0`(층 4 창 없음).
- 이 결함은 직원 C의 `click.js` 검사(첫 0층 창)가 막는 `SESSION_WINDOW_NOT_FRONT`의 원인이 아니다(층 4 창은 0층 목록에 안 잡힌다). 대신 층 4 창이 세션 창을 가려도 `click.js`가 못 보는 별개의 구멍이다(기록만, `click.js`는 건드리지 않음).

## 3. 관찰만 하고 원인으로 확정하지 못한 것

- `ConnectionsWindow.restoreFocus()`(인증·확인 창이 끝나면 무조건 `NSApp.activate`+`makeKeyAndOrderFront`)가 사용자 동작 뒤 hejo를 앞 앱으로 되돌린다(진단 로그 `NSApp.activate ... authenticated`, 그 뒤 `active=true`). 실험 중 측정 도중 hejo가 앞으로 돌아온 것은 이 경로와 사용자 메뉴 조작이었다(사용자 사용과 겹쳐 구분 못함). AT-CM-35가 의도로 고정한 동작이라 이번에 바꾸지 않았다.
- 원래 증상(Windows App 세션 위에 0층 hejo 창)은 새 빌드 30초 측정에서 재현되지 않았다. 설치본 30초 측정(`ac-al-06r-installed-idle.txt`)과 새 빌드(수정 전·후)에서 활성화·비활성화 뒤 Windows App이 첫 0층 창이었다.
