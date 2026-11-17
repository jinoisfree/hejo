# TASK-42 설정 페이지 비교

필요/도달 증거 수준: 2/2. 운영 앱 전체 비교가 아닌 원본 함수 분리와 제품 AppKit 페이지 조립 비교다.

- 원본: `App.swift`의 action/note·고급 단추·고정 채널·동기화 설명과 `SettingsPages.make`를 분리 컴파일했다. Slack 전용 연결 행은 제외하고 기본 채널 낱말은 승인된 hejo 변환을 적용했다.
- 제품: 고정한 제품 소스의 `PetSettingsWindow` 실제 페이지를 임시 홈에서 조립했다. 가짜 방을 고르고 세 손가락 탭 실패를 주입했다. 원본도 같은 표시 상태다. 운영 서버·Slack·실물 트랙패드는 사용하지 않았다.
- 창과 탭의 소유 관계를 유지하고 외관 범위 안에서 페이지를 캐시했다. 처음의 빈 PNG는 버렸다. 캡처는 페이지 내용이며 창 제목·탭 머리글은 포함하지 않는다.
- 600×594 PNG 여덟 개를 직접 표시해 단추·고정 채널·설명·색을 비교했다. 네 쌍의 최종 PNG 바이트가 같다. 이 결과는 선택한 두 페이지의 고정 표시 상태에 한정한다.

| 상태 | ddots 원본 조립 | hejo 제품 조립 |
|---|---|---|
| 고급 · 라이트 · 실패 있음 | [원본](task42-ddots-advanced-light.png) | [제품](task42-hejo-advanced-light.png) |
| 고급 · 다크 · 실패 있음 | [원본](task42-ddots-advanced-dark.png) | [제품](task42-hejo-advanced-dark.png) |
| 연결과 동기화 · 라이트 · 방 선택 | [원본](task42-ddots-sync-light.png) | [제품](task42-hejo-sync-light.png) |
| 연결과 동기화 · 다크 · 방 선택 | [원본](task42-ddots-sync-dark.png) | [제품](task42-hejo-sync-dark.png) |

원본 조립과 캡처 명령·지문은 `.build/task42/capture.py`, `capture.json`, `reference-inputs.json`에 있다. 최종 검사·반복·돌연변이는 `impl-report.md`의 TASK-42 기록을 따른다. 실제 로그인 항목 등록·두 Mac·물리 입력기·VoiceOver·운영 허브는 운영 수락에 남는다.
