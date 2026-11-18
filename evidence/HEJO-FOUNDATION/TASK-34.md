# TASK-34 실물 지적 수정 비교

필요/도달 인계 증거 수준 2. 같은 가짜 직원 6명·선택 없는 새 글·0초 활동·기본 DM 상태를 대조했다. 원본/운영 앱 전체를 실행한 비교는 아니다.

| 보기 | 근거 |
| --- | --- |
| [ddots 표시 조각](task34-ddots.png) | 원본 slackComposer의 첫 HStack·slackModeButton·ddotsFaces, stopControl의 활동 HStack, slackFolded·slackAddRoom 표시와 WritingShimmer를 분리 실행했다. 명부·동작·진단 측정은 대역이다. |
| [hejo AppKit 보기](task34-hejo.png) | 실제 ConversationView·ComposerFaces·WorkingControlRow·표 행을 가짜 명부·기록으로 조립했다. 밝은 창 바탕만 지정했고 그림 후처리는 하지 않았다. |

원본은 비교 요소만 모은 638×230 창, hejo는 실제 850×620 대화창이다. 작성기 스위치 왼쪽·얼굴 오른쪽·가운데 정렬, 초 오른쪽 중지, 얼굴 없는 DM, 목록 바로 아래 +를 비교한다. 원본 홈 스위치 ‘새 대화’와 REQ-HF-34의 hejo ‘새 글’, 기존 얼굴 색·padding·글꼴 그리기 차이를 픽셀 일치로 주장하지 않는다.

AT-85 자동 시험은 AppKit marked text로 실제 방/제목/설명/검색 입력칸과 작성기를 확인하며, 물리 한글 입력기 확인은 TASK-23 실물에 남는다. 3/20개 방과 + 행은 `app/Tests/ProgressLayoutTests.swift`에서 검사한다. 실제 Hermes 성공/실패 정리 함수는 가짜 차례와 실제 문을 연결한 `gate/tests/test_progress.py`로 확인했다.

생성기·실행 기록은 추적하지 않는 `.build/task34/reference.py`, `reference.json`, `focused.py`, `focused.json`, `frozen-progress.json`에 있다. 운영 앱 사본·공용 릴리스·서버는 변경하지 않았다. 버전 0.2.0 반영과 세 손가락 탭은 후속 TASK-33·35다.

33판 보완 38에 따라 구획/DM 움직임(옛 AC-08)은 이번 TASK-34에서 제외했다. 초안과 중간 프레임 시험은 `.build/task38-start.patch`에 보존하며 TASK-38에서 새 기준으로 구현한다. 이 화면은 움직임 완성을 증명하지 않는다.

최종 PNG는 전체 검사·앱 10회가 끝난 빌드의 `--task34-capture`를 임시 HERMES_HOME에서 실행해 복사했다(`capture-final.json`, 종료 0). hejo 상단의 연결 끊김/큰 재시도 숫자는 합성 시계의 연결 상태 표시이며 이번 배치 비교 대상이 아니다. 실제 서버의 연결 상태를 나타내지 않는다.
