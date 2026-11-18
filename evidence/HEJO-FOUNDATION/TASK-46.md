# TASK-46 · 내 캘린더 / N45-01

필요/도달 증거 수준: 2/2. 운영 캘린더·운영 앱 전체 비교가 아니라, 같은 가짜 공급자의 일정 값을 넣은 원본 SwiftUI 창과 제품 AppKit 창의 비교다. 원본 MacCalendar·CalendarMatch는 수정하지 않고 별도 실행했고, 제품은 앱 시험 실행 파일의 실제 보기다. 시스템 캘린더 권한 요청·쓰기·운영 반영은 하지 않았다.

| 상태 | ddots 원본 | hejo |
|---|---|---|
| 내 캘린더 / 밝게 | [원본](task46-ddots-light.png) | [제품](task46-hejo-light.png) |
| 내 캘린더 / 어둡게 | [원본](task46-ddots-dark.png) | [제품](task46-hejo-dark.png) |
| 옆 창 / 밝게 | [원본](task46-web-ddots-light.png) | [제품](task46-web-hejo-light.png) |
| 옆 창 / 어둡게 | [원본](task46-web-ddots-dark.png) | [제품](task46-web-hejo-dark.png) |

캘린더의 [행·단추 실측](task46-calendar-layout.json)은 폭 360에서 보통 행 73pt·긴 제목 행 105pt, 내용 단추 20pt+위 여백 2pt다. [월 제목 경계](task46-month-ink.json)도 원본 y=65~75에 맞췄다.

캘린더는 760×540, 같은 날짜의 합성 일정·제목·장소·메모·선택 상태를 사용한다. 이전/다음 달·검색·상세와 권한/삭제/변경/종일 표시는 가짜 공급자와 실제 AppKit 제어로 시험한다. 날짜 원본 실행값은 [날짜 대조](task46-original-dates.json)다. 제목·장소까지 맞아야 하며 일반 낱말 '회의'나 날짜만으로 일정을 만들지 않는다. 상대 날짜는 수신 글 날짜 기준이다.

옆 창은 로컬 가짜 웹 페이지에 연결한 720×1000 상태다. 원본의 실제 단추 프레임(x=12/30/48/690)과 주소 글자 칸(78,52,596,15)을 측정해 제품에 적용했다. 바탕의 10pt/5pt 안쪽 여백은 한 곳에서 계산한다. [실제 주소 글자 경계](task46-address-ink.json)는 원본·제품 모두 x=81, 위=55, 아래=65다. AT-96은 이 실제 그리기와 레이아웃 사각형을 함께 단언한다. 왼쪽 1pt 선은 원본의 overlay이므로 본문 폭을 줄이지 않고 유지한다.

웹 본문은 WebKit의 별도 스냅샷을 같은 페이지 사각형에 합성하고 투명한 창 바탕을 해당 테마의 기본 바탕에 내보냈다. 원본 앱 전체·픽셀 동일 비교를 주장하지 않는다. AppKit/SwiftUI의 글자 합성과 기본 제어 외관 차이는 남는다. 기본 NSTextField 안쪽 여백 때문에 상세 글자 시작이 약 2pt 다르고, 월 제목 오른쪽 잉크 끝은 원본 412/제품 413으로 1px 차이가 있다. 실제 서버·두 Mac·시스템 권한 전환·물리 입력기·VoiceOver는 운영 수락에 남는다.

실행·지문·서명 검사 로그는 로컬 `.build/task46/`의 frozen-progress.json·post-checks.json·image-check.json·mutation.json·final-verification.json을 따른다. 이전 TASK-45의 통과 캡처는 교체하지 않았다.
