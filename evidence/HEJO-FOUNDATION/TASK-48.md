# TASK-48: 같은 상태의 원본·문 동작 비교

이번 범위는 문만이며 앱·화면은 바꾸지 않았다. 새 UI 캡처 대신 같은 가짜 입력의 원본 함수와 문 출력 비교를 남긴다. 실제 Slack·운영 서버 실행을 주장하지 않는다.

- `task48-comparison.json`: 수정하지 않은 Slack adapter의 `_has_active_session_for_thread` 함수를 분리 실행하고, 같은 공식 SessionStore 상태에서 실제 문 수신의 `channel_context`를 관측했다. 없음/활성/명시 중단에서 각각 복원/생략/복원이다. 원본 confirm 결과 낱말 키와 문 결과 줄도 한국어 입력에서 같다.
- `.build/task48/comparison.json`, `.build/foundation9-task48-reference-final.log`: 위 실행의 원본 결과와 종료 0 근거다. 비교 도우미는 비추적이며 제품 진입 경로가 아니다.
- `.build/task48/foundation.log`: 실제 공식 가짜 게이트웨이의 정기 보고 5,000자와 도구의 한글 3만 자를 전달하고, 기록된 조각의 합·바이트 한도·동일 스레드·seq를 확인하는 `AT99_OFFICIAL_DELIVERY_PASS`를 포함한다.
- `gate/tests/test_delivery_parity.py`: 스트리밍 반복 최종 편집과 축소, 마지막 조각 버튼, 중간 기록 실패, 문맥 한도, 단추 처리 후 재누름, 사진·음성·영상 첨부, SSRF 리다이렉트·크기 초과 거절을 관측한다.

인계 필요/도달 수준은 2/2다. 실제 운영 정기 보고와 화면에서 긴 글·첨부를 보는 수준 4는 TASK-23에서 확인한다. public의 0.2.0 준비물·앱 두 사본·공용 릴리스는 갱신하지 않는다.
