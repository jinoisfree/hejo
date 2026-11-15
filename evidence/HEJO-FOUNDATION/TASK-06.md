# TASK-06 대화 화면 수동 비교 증거 자리 (8판)

상태: 수동 미실행. 기준은 시안이 아닌 ddots의 현재 대화 화면이다. hejo는 가짜 명부·문 대역만 쓴다. ddots를 실행하거나 설정을 바꾸지 않았다. ddots 촬영·개인 내용 가림은 사장 참여가 필요한 TASK-09로 인계한다. 자동 캡처로 같은 모양·실기기 조작 완료를 판정하지 않는다.

비교 방법: 같은 크기의 대화 영역(기본 428×500pt, 탭 줄 포함)·같은 macOS 배율/외관으로 같은 상태를 나란히 촬영한다. 원본의 제외 요소는 design 6절 목록과 대조하고, 사진 대신 첫 글자·방 대신 직원·서버 버튼/첨부 데이터만 다르게 둔다. 스크린샷에서 개인 자료를 가리고 픽셀/포인트 크기·간격·색·글꼴과 아래 동작을 대조한다.

| 상태 | 조작·기대 | hejo 증거 자리 | ddots 비교 증거 자리 | 수동 상태 |
|---|---|---|---|---|
| 직원 전환 | 68px 탭·72px 행·첫 글자 아이콘·안 읽은 수, 해당 초안 유지 | `task06-tabs.png` | `task06-tabs-reference.png` | TASK-09 대기 |
| 탭 줄 끌기 | 180~300px 목록·58px 행, 34px 미만 숨김·머리글 복원 | `task06-sidebar.png` | `task06-sidebar-reference.png` | TASK-09 대기 |
| 스레드 열기·접기 | 한 개만 펼침, 접힌 이전 답글 더미·레일·선택 테두리·배경 클릭 접기 | `task06-thread.png` | `task06-thread-reference.png` | TASK-09 대기 |
| 새 글/답글 | 입력 줄 전환·독립 초안·대상, 머리글44px·카드 간격18px | `task06-compose.png` | `task06-compose-reference.png` | TASK-09 대기 |
| 보내기·줄바꿈 | Enter 전송·Shift Enter 줄바꿈·한글 조합, 확인 전 초안 보존 | `task06-send.png` | `task06-send-reference.png` | TASK-09 대기 |
| 스트리밍·작성 중 | 같은 글 갱신·서식/코드·6초 ttl, 동작 줄이기·카드 읽기 위치 | `task06-stream.mov` | `task06-stream-reference.mov` | TASK-09 대기 |
| 버튼·상태·알림 띠 | 서버 버튼 클릭·아이콘·만료·레일, 해당 스레드로 이동 | `task06-buttons.png` | `task06-buttons-reference.png` | TASK-09 대기 |
| 첨부 보내기·열기 | 선택·놓기·이미지 붙여넣기→업로드→글 확인, 파일/사진 타일 GET | `task06-file.png` | `task06-file-reference.png` | TASK-09 대기 |
| 닫힌 펫 | 새 글 수신→파란 안 읽은 배지·열면 숨김, 재시작 읽음 유지 | `task06-unread.png` | `task06-unread-reference.png` | TASK-09 대기 |
| 끊김·오류·펫 | 끊김 띠·unknown_file/too_large·초안 보존·재동기화, 머리글 드래그·접기·genie | `task06-reconnect.mov` | `task06-reconnect-reference.mov` | TASK-09 대기 |

자동 증거(수동과 구분): `task06-automatic.png`는 가짜 Alpha/Beta 명부·루프백 문 대역의 실제 AppKit 캡처다. `task06-cards-automatic.png`는 같은 네이티브 뷰에 가짜 긴 스레드·다른 카드·원본 배치를 적용한 자동 캡처다. ddots 비교 촬영·운영 연결·실기기 입력·외부 앱 파일 열기 완료 증거가 아니다. 자동 시험은 배치 상수·목록/숨김·한 카드 펼침·초안 문맥·배지 가시성을 별도로 확인한다.
