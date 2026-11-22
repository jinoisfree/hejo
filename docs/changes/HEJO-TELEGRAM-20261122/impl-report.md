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

## TASK-03 — 보류(구현 규칙 2절 보고)

[확인] 토픽 작업자·Bot API 직접 호출·토픽 저장·수신/첨부·기존 receive 경로 연결을 작업 트리에 작성했으나 TASK 완료로 판정하지 않는다. 다음 충돌 때문에 TASK-03 추가 구현 및 TASK-04~06을 멈췄다. TASK-03 제품·시험은 미커밋이며 수정 상태 그대로 보존했다.

### 차단 HT-B01: 쓸 수 있는 방 수와 수락 시험 기대값 불일치

- 수락 명세 공통 환경은 기본 프로필 `default`와 `alpha`, `beta`, 단체방 `G`다(`tests/acceptance/HEJO-TELEGRAM.md:5`). spec 용어의 쓸 수 있는 방은 명부에 있는 직원의 1:1 방과 삭제·보관되지 않은 단체방 모두다.
- 실제 `gate/roster.py:26`은 `profiles_to_serve`의 모든 프로필을 직원으로 반환한다. 기준 커밋과 현재 코드 모두 같다. `default`를 빼는 계약은 없다. 기존 외부 문 `rooms()` 역시 명부 전부를 사용했다.
- 지정 환경에서 실제 생성된 대응은 `default`, `alpha`, `beta`, 단체방의 **4개**다. 관측 파일은 추적하지 않는 `/tmp` 시험 홈의 `shared/hejo/telegram/topics.json`이고, 오류 로그는 아래 파일이다.
- AT-HT-05는 그룹별 만들기 3회, AT-HT-12는 만들기 3회 및 Alpha·Beta·Team 각각 1회만을 요구한다. 이를 그대로 옮긴 시험은 3개 대응을 기다리다가 시간 초과했다. 시험을 4개로 바꾸거나 대역 명부에서 default를 빼면 현재 수락 명세 입력/합격 기준을 바꾸게 된다. 제품에서 default를 제외하면 spec의 모든 쓸 수 있는 방 계약을 바꾸게 된다.
- 선택지: (A) 모든 프로필 포함을 유지하고 AT-HT-05·12 및 공통 활성 준비의 3개 기대를 4개로 정합화. (B) default를 외부 토픽 대상에서 제외하는 명시적 요구·설계·시험 입력을 계획 담당이 확정. 구현자 권고는 A(기존 명부와 모든 방 결정 유지)다. 승인 전 어느 쪽도 구현하지 않았다.
- 보고 대기 중 진행 가능한 별도 부분은 앱이지만, TASK-02 규격 이후 TASK-03의 차단 경계에서 인계하기 위해 아직 착수하지 않았다. 이 대화에서 하위 에이전트는 사용하지 않았다.

### 작성 중인 시험과 실행 증거

- TASK-03 시험은 토픽 만들기·이름·보관·해제·삭제, 재짝짓기, 같은 객체 통과, 수신 본문·방 대표/멘션·답장·중복·첨부·오류를 명세대로 옮기는 중이다. 전체 이식 완료 또는 통과라고 보고하지 않는다.
- 명령: 기존 `.build/connections-env.sh`로 Hermes venv 및 기존 시험 의존성 경로를 설정하고 `"$HEJO_PYTHON" -m pytest tests/acceptance/test_telegram.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp=/tmp/ht03`.
- 실제 결과: 종료 1, **9 failed, 11 passed**. 실패 9건은 공통 활성 준비에서 세 토픽을 기다린 시간 초과다. 이 단계 뒤의 수신·첨부 단정은 도달하지 못했으므로 미검증이다. 로그 `.build/telegram-evidence/task03.log`.
- `git diff --check`: 종료 0. 대상 변경본은 TASK-02 커밋 `53acb8e` 위 `gate/telegram.py`, `tests/acceptance/test_telegram.py` 작업 트리다. 문서 추가 외 다른 작업의 변경은 미포함이다.
- TASK-04~06, mutation check, 전체 시험·AT-HT-44 측정 미실행. 도달 증거는 TASK-02 대역 통합 수준 2에 한정한다. 운영 적용·설치·재시작·패키지 설치·실제 발송·푸시는 하지 않았다.

- 중단 시 개인값 사전 검사: 임시 빈 HERMES_HOME, 기존 Hermes venv `python scripts/scan_private.py`, 종료 1. 다른 작업 `HEJO-DEADLINE-CLOSE-20261122/impl-report.md` 97·109행 및 `verdict.md` 127·146행의 절대 경로 4건이 보고됐다. 이번 TASK-02·03 파일에서는 지적이 없었다. 범위 밖 동시 작업 문서는 수정하지 않았다. 로그 `.build/telegram-evidence/private-stop.log`. 전체 검사 통과로 보고하지 않는다.
- TASK-02 전체 커밋: `53acb8e4ee5c4b79aa01e23320851a0c62648092`. 중단 시 다른 작업 커밋이 더해진 HEAD는 `df79b7f6ea2b82ee5ad053b8ff6e50d9fadfd533`이었다. 이 작업의 미커밋 제품·시험은 앞서 지정한 두 파일뿐이다.

## 보완 1 / TASK-03 — 토픽·수신

- 받은 보완: 판정 1차와 `8148ca4792914f721f9ee4623e2d09f58dd1c5d5`의 수락 명세 3판. HT-B01은 시험 오류로 해소됐으며 default 표시 이름 Main, 토픽 4개로 이식했다. spec·design·시험 명세는 수정하지 않았다.
- 구현: 직렬 작업자·연결 감시가 활성 전환과 방 레코드에서 토픽을 동기화한다. `_bot`의 네 Bot API만 호출하며 예외 종류만 로그한다. 수신은 현재 표지의 답장/토픽을 판정하고 첨부를 기존 파일 대기에 넣어 기존 receive 한 경로로 보낸다. 중복은 첨부 대기보다 먼저 판정한다.
- 짝짓기 경합 관찰 처리: 금고 잠금 안에서 소유 판정을 재확인한다. 이미 쓰인 코드면 원래 처리기에 동일 이벤트를 한 번 전달한다. 최종 차지한 경우에만 `_accept_update`를 호출한다. 판정 후 코드 사용을 주입한 시험으로 무응답·중복 차지가 없음을 확인했다.
- 시험: 코드/설정 시험과 토픽 생명주기, 실패 로그 비노출, 수신·멘션·답장·삭제 스레드·첨부·중복·무소유 통과를 검사한다. 송신 대응 답장·새 직원 발신은 TASK-04에서 이어 검사한다.
- 명령: 기존 `.build/connections-env.sh` 환경으로 Hermes venv `python -m pytest tests/acceptance/test_telegram.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp=/tmp/ht03r`. 종료 0, **21 passed**, 로그 `.build/telegram-evidence/task03r.log`, 증거 수준 2. 중간 실행의 삭제 스레드 시험 입력은 기존 public API의 room 필드를 사용하도록 바로잡았다(기대값 불변).
- 설계 차이 없음. 감시 간격 0.25초·작업자 방식은 위임된 내부 세부다. 위험·롤백·금지 범위는 기준 절과 같다. TASK-04~06과 전체·mutation 검사는 남았다.

## TASK-04 — 발신·작성 중

- 스레드별 기록 순서 대기열에서 앱 사장 글은 즉시, 직원 글은 작성 중이 끝나고 마지막 기록의 정착 시간이 지난 뒤 보낸다. 전송 시 기록장 최신 글을 읽으며 생각 중·삭제·비활성 기록은 보내지 않는다. 기록 당시 짝 표지를 대기열에 고정해 재짝짓기 뒤 옛 대기가 새 그룹으로 가지 않는다.
- 직원/사장 이름표·알림·가장 이른 대응 닻·버튼 덧붙임, 파일 사전 판별 및 파일 발신을 구현했다. 나눠진 본문·첨부 id 전부를 표지와 함께 sent.jsonl에 저장한다. 손상 줄 건너뛰기·덜 쓰인 꼬리 절단·0600을 유지한다. 파일 실행 중 실패는 재시도/안내 없이 종류 로그 한 줄이다.
- 작성 중은 토픽마다 4초에 한 번 이하로 비동기 요청한다. 정지 요청은 없고 앱의 기존 정지/스트림 처리 뒤 정착 대기만 깨운다. 기존 정착 측정 시험은 `gate/tests/telegram_settling.py`로 이름·참조만 옮겼다.
- 설계 차이 없음. 대기열·파일 저장과 네트워크 경계를 기존 책임 모듈 하나에 유지했다. 되보내기·수정/삭제 반영 경로는 만들지 않았다.
- 검증: Hermes venv `python -m pytest tests/acceptance/test_telegram.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp=/tmp/ht04`, 종료 0, **34 passed**, 로그 `.build/telegram-evidence/task04.log`, 수준 2. AT-HT-07의 모든 로거/저장소/앱 프레임 허용 위치, AT-HT-39의 두 임시 홈 기록장·실제 앱 프레임 비교 포함. 중간 이식 오류(버튼의 실제 style/kind, delete의 기존 호출 범위, 비교용 uuid 키 정규화)를 고쳤고 대역 러너 차례 종료 후 같은 대본을 순차 입력했다(기대값 불변).
- AT-HT-44 수준 3·mutation·앱·전체 검사는 TASK-05·06에서 남았다.

### TASK-04 자체 점검 보완

- 경합 뒤 원래 처리기로 넘긴 경우 그 처리기의 예외는 원래 경로로 전파되도록 외부 호출을 차지한 수신의 예외 경계 밖으로 옮겼다. 리스너 시작 실패 시 새 작업자를 닫아 자원 누수를 막았다.
- 실제 문 재연결의 설정 보존, 기능 없는 연결에 텔레그램 프레임 0건, 옛 구현 검색(AT-HT-42)을 추가 확인했다. 옛 연결에 전달되는 기존 방 레코드의 delete 투영은 그대로 허용하며 텔레그램 상태/코드만 0건으로 단정한다.
- Hermes venv의 같은 명령(`--basetemp=/tmp/ht04f`), 종료 0, **37 passed**, 로그 `.build/telegram-evidence/task04-final.log`. 앱 코드까지 교체한 작업 트리를 검사했으나 앱 자체 검증은 아래 TASK-05에 따로 적는다.
