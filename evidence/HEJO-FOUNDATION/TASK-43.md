# TASK-43 대화창 모양 비교

필요/도달 증거 수준: 2/2. 원본 함수 분리와 제품 AppKit 모양 묶음의 비교이며 운영 앱 전체 비교가 아니다.

- 원본: ddots `SettingsPages.swift`의 실제 `AppearancePreview`(SwiftUI)·`ChatAppearanceControls`, `ChatStyle.swift`의 테마/글씨/색/대비 계산, `BubbleOpacity.swift`를 분리 컴파일했다. 쓰이지 않는 직원 순서 계산만 제외했다. 시험용 일시 설정을 쓰며 원본 앱 파일·실제 설정은 고치지 않았다.
- 제품: 고정한 hejo 제품 소스로 실제 `PetSettingsWindow`의 **화면과 펫** 탭을 선택하고 AppKit 모양 묶음을 캡처했다. 임시 홈·가짜 직원 A·같은 210도 직원 색, 14pt·65%·기본 말풍선 색이다. 연결 상태에 따라 비활성화되는 기능이 아니며 실제 서버는 호출하지 않는다.
- macOS 외관은 양쪽 모두 라이트로 고정하고 대화창 테마만 시스템/라이트/다크로 바꿨다. 설정 창 자체는 원본처럼 시스템 모양을 유지하므로 다크 선택에서도 조절 묶음은 밝고 미리보기만 어둡다. 창/탭 소유 관계·표시·외관 범위·그리기 완료를 보장한 뒤 536×580 내용을 저장했다. 두 실행 모두 key=false·active=false·attached=true로 같은 비활성 창 상태다. 숨은 탭을 캐시한 초기 후보는 최종 증거에서 제외했다.
- 각 쌍에서 미리보기 536×184와 본문 사각형(직원 60,59,273,17 · 내 글 327,104,181,17)이 같다. 제목·샘플·원·슬라이더/단추·배치를 직접 비교한다. AppKit과 SwiftUI의 글자 그리기/모서리 안티앨리어싱 차이를 포함하므로 전체 픽셀 동일을 주장하지 않는다.

| 고른 테마 | ddots 원본 조립 | hejo 제품 조립 |
|---|---|---|
| 시스템 설정(macOS 라이트) | [원본](task43-ddots-system.png) | [제품](task43-hejo-system.png) |
| 라이트 | [원본](task43-ddots-light.png) | [제품](task43-hejo-light.png) |
| 다크 | [원본](task43-ddots-dark.png) | [제품](task43-hejo-dark.png) |

명령·원본 지문·측정값은 `.build/task43/capture.py`, `reference-inputs.json`, `ddots-capture-run.log`, `hejo-capture-run.log`, `capture.json`에 있다. 반복·돌연변이·서명·개인값 검사는 `impl-report.md`의 TASK-43과 최종 검증 파일을 따른다. 실제 서버·두 Mac·시스템 접근성 실물·물리 한글 입력기·VoiceOver는 운영 수락에 남는다.
