# HEJO-TELEGRAM 구현 인계

## 기준과 범위

- 받은 설계: [handoff.md](handoff.md), 기준 `29326c53e893bd0db14bc78b5b63c6f75dd98351`, spec·design·수락 시험 명세·tasks 2판. 계획 검증 2회차 APPROVED는 [plan-review.md](plan-review.md)에 확인했다(PR-06의 읽는 법 적용).
- 고위험, 필요 증거 수준 2(AT-HT-44만 3), 연합개발 구현·자체 시험. TASK-02~06만 수행한다. 운영 적용·실물·공개는 범위 밖이다.
- 착수 HEAD `d3f5b5f`: 기준 뒤 마감 닫기 등 다른 작업의 변경은 보존했다. 겹치는 server·schema·앱 파일의 추가는 외부 메신저 경로와 직접 충돌하지 않는다. 다른 작업 문서의 미커밋 변경은 건드리지 않는다.
- Hermes base/event SDK 없는 import 성공. 실제 포럼 이벤트·재접속의 외부 가정은 운영 미실행으로 직접 관측하지 않았다. 코드가 확인한 공장 호출은 연결 표시 전이다.

## TASK-02 — 규격·저장·짝짓기 바탕

[확인] 문은 `telegram` 공장 하나를 등록한다. `gate/telegram.py`가 금고·켜짐·판정·짝짓기·상태를 소유한다. 금고 밖 짝 식별은 매번 새 8자 표지다. adapter·server·rooms 호출을 교체했고 옛 문 모듈과 시험 코드를 삭제했다. 규격의 여섯 프레임을 교체하고 더 이상 정의되지 않은 프레임에는 일반적인 `unexpected_frame` 처리를 적용했다. 방 레코드 알림은 잠금 밖에서 한 번 전달한다.

- 판단 상태: 부분 구현. 수신·토픽·발신·작성 중 자리의 뼈대는 TASK-03·04에서 완성한다. 앱은 TASK-05다.
- 설계 변경 없음. 공장 감싸기는 플랫폼 수신 경계에서 소유 판정·오류 격리를 맡는다. 사장 글은 기존 `receive` 한 경로를 유지한다.
- 시험 보호 계약: 코드 회전·한 번 사용·포럼/계정 허용·만료, 요청 연결에만 코드, 기능 협상·옛 프레임 거절, 금고 0600, 설정 보존. 옛 메신저 시험은 새 수락 명세로 대체한다.
- 검증: 기존 로컬 의존성 경로만 사용한 Hermes venv `python -m pytest tests/acceptance/test_telegram.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp=/tmp/ht02`, 종료 0, 9 passed. 로그 `.build/telegram-evidence/task02.log`. 최초 venv 직접 실행은 pytest 모듈 부재로 종료 1; 설치 없이 기존 시험 의존성 경로를 재사용했다.
- 증거 수준 2. mutation check·전체 검사·개인값 검사는 TASK-06에서 남은 변경본에 수행한다. 설치·재시작·패키지 설치·실물 발송 미실행. 롤백은 이 작업 커밋 되돌림(운영 미적용)이다.
