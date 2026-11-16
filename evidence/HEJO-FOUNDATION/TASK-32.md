# TASK-32 연결 창 비교

필요/도달 증거 수준 2. 같은 가짜 직원 한 명·같은 키 연결 한 줄·unknown 상태·저장됨(확인 안 함) 안내다. 운영 앱이나 외부 계정을 실행한 비교가 아니다.

| 보기 | 근거 |
| --- | --- |
| [ddots 원본 조각](task32-ddots.png) | 전체 독해한 AgentConnectionsView의 avatar/header/summary/pill/tile/row/button/detail 함수는 그대로 두고 가짜 모델과 직원/계정 구역을 조립했다. 원본 앱 전체는 실행하지 않았다. |
| [hejo 연결 창](task32-hejo.png) | 실제 ConnectionsModel·ConnectionsView·입력·명부 사진 모델을 가짜 전송과 조립했다. AppKit 창 바탕을 넣어 투명 캡처의 검은 빈 부분을 없앴다. 그림을 후처리하지 않았다. |

둘 다 860×590, 밝은 화면이다. 직원 목록 200px, 22px 내용 여백, 이름·시각·확인 버튼, 0개 숨김 알약, 타일·상태·주 버튼 배치를 대조했다. hejo는 승인된 용어 ‘직원’, 기존 명부의 사진/색을 쓴다. 원본의 초록 성공 아이콘 대신 중립 안내를 보이며, 그 차이와 제목 아래 약 4px 간격 차이를 그대로 기록한다. 연결 상태 unknown을 연결됨으로 바꾸지 않는다.

생성기와 전체 로그는 추적하지 않는 `.build/task32/reference.py`, `reference.json`, `white_capture.py`, `white-capture.json`에 있다. 실제 앱의 재확인·입력 삭제·관리 응답 캐시 제외는 `app/Tests/ConnectionsTests.swift`로 별도 검사한다. 실제 Touch ID/Mac 암호, 다른 Mac 권한 창, 서버 OAuth 동의·재시작 결과 실물은 TASK-23에 남는다.
