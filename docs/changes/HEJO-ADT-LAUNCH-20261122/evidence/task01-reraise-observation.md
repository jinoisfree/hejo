# TASK-01 실물 관찰: 세션 창을 다시 올리면 hejo 창 위로 올라오는가 (2026-11-22)

방법: 읽기 전용. `focus.js focus`(직원 C와 같은 경로)와 System Events `AXRaise`를 실행하고 앞 순서(CGWindowList, 0~5층)만 읽었다.
Windows에는 입력을 보내지 않았고 창 제목·장치 이름은 기록하지 않는다. 실행한 hejo는 `/Applications/hejo.app`(2026-11-21 빌드)이다. 새 빌드는 설치하지 않았다.

| 상태 | 맨 앞부터 0층 창 주인 | 앞 앱 |
|---|---|---|
| 실행 전 | hejo, hejo, Windows App(얇은 도구줄), Windows App(세션) | Windows App |
| `focus.js focus` 직후 | 같음 | Windows App |
| `AXRaise` 직후 | 같음 | Windows App |

- [확인] Windows App이 맨 앞 앱인데도 hejo 창 둘이 Windows App 세션 창보다 위에 있었고, 다시 올려도 순서가 바뀌지 않았다. 즉 TASK-01의 "한 번 다시 올리기"는 이 상태에서는 가린 hejo 창을 치우지 못한다.
- [확인] 시험용 hejo 창 두 개(`OptionWindows.show`로 띄움, 활성 중 펫+1 층)를 같은 화면 공간에 두고 Windows App을 앞으로 올리면, 비활성 처리로 `.normal`이 된 그 창들은 Windows App 세션 창 **뒤**에 놓였다(레벨 내림 자체가 앞 순서를 뺏지 않음). 가설(1)은 이 실험에서 재현되지 않았다.
- [확인] 실험 중 진짜 hejo가 `focus.js focus` 1~2초 뒤 스스로 맨 앞 앱이 되는 일이 있었다(앞 앱이 hejo로 바뀌고 hejo 창이 하나 더 보임). 사용자 조작인지 hejo의 자기 활성화인지 구분하지 못했다. 후보는 `ConnectionsWindow.restoreFocus`(확인·인증 창이 끝날 때 `NSApp.activate`와 `makeKeyAndOrderFront`를 무조건 부름).
- [미확인] 새 빌드(AT-FF-64 이후)의 실물 순서. 새 빌드를 설치하지 않았고, 화면이 다른 사용 때문에 계속 바뀌어 한 번에 하나의 변수만 바꾸는 비교를 할 수 없었다. AC-AL-07은 [미실행].
