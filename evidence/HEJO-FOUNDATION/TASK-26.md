# TASK-26 알림·검색·작성기 화면 증거

필요/도달한 인계 증거 수준은 2다. 가짜 명부·고정 시각·가짜 글/첨부만 사용했다. 운영 앱·명부·게이트웨이는 실행하지 않았다.

| 파일 | 비교·확인한 내용 |
|---|---|
| [ddots 알림 막대](task26-ddots-notices.png) | 원본 SlackPanel.slackNoticeBar 함수를 불활성 모델로 실행. 직원 A 질문 2·알림 3 |
| [hejo 알림 막대](task26-hejo-notices.png) | 같은 질문 2·알림 3의 실제 AppKit 막대. 두 캡처 모두 내용 영역 808×23px |
| [ddots 검색 결과](task26-ddots-search.png) | 원본 SlackFindView와 검색·미리보기·하이라이트 함수를 불활성 명부/이동 콜백으로 실행. needle, 직원 A, plain body, needle.txt |
| [hejo 전체 검색](task26-search.png) | 같은 검색어·직원·본문·파일의 실제 결과. 날짜 오른쪽 정렬·첫 글·말한 이·시각·본문·파일 이름과 노랑/검정 하이라이트 |
| [hejo 작업 화면](task26-workspace.png) | 알림 분류·스레드 열기·이동 반짝임, 보관한 다른 방의 실패 글 안내, 작성기·첨부 |

검색 참조는 결과 부분만 832×420px이고 hejo는 전체 시험 창 900×720px이다. 검색 결과 내부를 나란히 보며 비교했다. 원본의 방/날짜 줄, 첫 글 미리보기, 일치 글·파일 이름, 선택 배경과 테두리를 AppKit으로 옮겼다. 날짜가 잘리거나 카드가 빈 공간까지 늘어나는 초기 배치를 고치고 실제 결과 폭·내용 높이를 자동 시험에 추가했다. 기본 컨트롤의 글꼴 측정·행 간격·종이클립 표현은 두 UI 도구에 따라 조금 다르며 픽셀 일치를 주장하지 않는다. hejo 캡처에는 실패 복구 시험에서 남긴 다른 방 실패 글·연결 안내도 보인다. 배경이 투명한 창을 임의로 보정한 이미지가 아니라, 시험 창의 흰 바탕 위에서 실제 NSView를 캡처했다.

머리줄 편집은 별도 가짜 계정에서 실제 editHeader의 NSAlert 저장·다른 값 입력 후 취소·기본값 복원을 네이티브 버튼으로 실행해 확인했다. 멘션 경계·초안 자리/얼굴·실패 합치기·첨부 10개 제한·지우기는 자동 시험에 있고, 답글 자동 전환과 자동 재전송 없음은 실제 루프백 WS에서 확인한다.

한계: ddots 원문 조각의 참조 창이며 원본 앱 전체·실제 Slack·월 기록·두 Mac을 실행한 것이 아니다. hejo도 가짜 계정의 AppKit 시험 실행 파일이다. 실제 단체방 명부는 TASK-21, 운영 연결·사장의 수동 실물 확인은 TASK-23에 남는다. 원본 파일은 읽기만 했다. SwiftUI 참조 호스트는 추적하지 않는 시험 도우미에만 있고 제품에는 없다.

재현·전체 로그는 미추적 `.build/task26/reference_capture.py`, `reference_search.py`, `reference-notice.json`, `reference-search.json`, `focused_check.py`, `focused-check.json`, `capture-final.log`, `native_modal_check.py`, `native-modal.json`에 있다.
