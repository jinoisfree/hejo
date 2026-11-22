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

## TASK-05 — AppKit 설정·앱 계약 교체

- GateClient 기능은 `["rooms","telegram"]`이다. 새 TelegramState가 지원 여부·준비·짝·켜짐·토픽 문제·코드·남은 초를 표시하고 조회·코드·해제·켜기만 요청한다. 설정의 AppKit 구역을 고정 안내 문구와 여섯 상태로 교체했다. 서버 응답 전에는 켜짐 값을 확정하지 않는다.
- 옛 상태 파일·설정·방 메뉴 두 항목·방 선택 모델·시험을 제거했다. 방 메뉴에 새 메신저 항목은 추가하지 않았다. 기존 고정물의 선택 기능 거절을 텔레그램 조회 거절로 바꿨다. SwiftUI 예외 없음, 로컬 설정 저장 형식 변화 없음.
- 앱 수락 시험은 실제 native controls의 상태·코드 복사/만료·클릭 요청·서버 ACK·GateClient 디스패치와 옛 문 미지원 경로를 확인한다. 소스 검색은 AT-HT-42(문 시험)에 포함돼 허용된 서비스 아이콘 외 옛 문 문자열 0건과 방 메뉴 텔레그램 0건을 확인했다.
- `TZ=Asia/Seoul bash app/scripts/test.sh`(기존 Hermes venv/시험 의존성), 종료 0. 빌드·서명 검증·AT-HT-50~52·전체 native 앱 시험·대화/방/첨부/다운로드/WebKit/옛 문 통신 고정물·훅 9건 통과. 실제 CLI 설정 metadata 및 다운로드 이름 보존 guard도 통과. 로그 `.build/telegram-evidence/task05-app-final.log`. 최초 실행은 상태 문구 조사 오자로 AT-HT-50 실패(종료 1), 문구를 spec과 맞추고 최종 전체 앱 시험을 다시 실행했다.
- 증거 수준 2. 기존 소스의 Swift 경고(사용하지 않는 값·actor 격리·deprecated SDK 등)는 변경하지 않았다. 앱 기존 화면 시험은 렌더링 때문에 시간이 걸렸으나 완료했다. 설치된 앱 사본·버전·운영 홈은 변경하지 않았다.

### TASK-04 토픽 I/O 경계 보완

- 자체 점검에서 토픽 생성의 await 사이에 수정·작성 중 상태가 바뀔 수 있음을 확인했다. 발신 직전 최신 기록장 글·활성·방 생존·짝 표지를 다시 확인하고 새 수정의 정착/작성 중 종료를 기다리게 했다. 첫 정착은 토픽 생성 전에 유지한다(AT-HT-14 순서 보존). 외부 I/O 전후의 서로 다른 시점 검증이다.
- 토픽 응답을 지연시키고 그 사이 본문 수정·작성 중을 주입했다. 작성 중에는 0건, 종료 뒤 최신 본문 1건을 확인했다. Hermes venv 동일 문 시험(`--basetemp=/tmp/ht04io`), 종료 0, **38 passed**, `.build/telegram-evidence/topic-io-final.log`. 설계 차이 없음.

## TASK-06 — 검증 실행·보류(HT-B02)

### 현재 판단과 변경본

- TASK-02~05의 문·앱 구현과 새 수락 시험 이식은 수행했다. **전체 완료 판정은 보류**다. 아래 HT-B02와 다른 작업의 개인값 지적이 남아 AT-HT-43 전체 통과를 선언하지 않는다. tasks 상태 확정·최종 검토·운영 적용 판단은 계획 담당에게 넘긴다.
- 제품 코드 최종 커밋: `1ef3ad27fbe0e960fb542ea14bd0a3ef7d62262e`. TASK-03 `338c35a2d09fea34139207690bb1db64d2e3f2ab`, TASK-04 `c9a653a36b4355f7591ff1a086b77449edc905e4` 및 자체 점검 `9fd6512af6efccc0d81b783a12785364c787a740`, TASK-05 `0ded4b8a1b7bb2076c4232d378c1ab4ce4900fbb`.
- 최종 수락 시험 정합 점검에서 AT-HT-22(a)·23(b)의 실제 보낸 글 답장/삭제 절차, AT-HT-24(a)의 이미지 MIME, AT-HT-40의 깨진 중간 줄 뒤 유효 줄 읽기를 추가로 명확히 실행했다. 기대값·수락 명세는 바꾸지 않았다. 제품 코드는 위 커밋 이후 변하지 않았으며 이 보완은 시험·보고만의 마지막 커밋이다.

### HT-B02 — 승인된 규격 교체와 기존 전체 파일 해시 단정의 충돌

- 실패 위치: `tests/acceptance/test_slack_move_gate.py:60`, `test_at_sm_02_edit_state_buttons_images_delete`.
- 이 시험은 통신 규격 전체 SHA-256을 `4f365159c687db76249fed494627764f2e8fe741e89a56471642fe983371b7ce`로 고정한다. 착수 HEAD `d3f5b5f`의 규격이 실제로 이 값임을 읽기 명령으로 확인했다.
- 이번에 승인된 여섯 프레임 교체·필드 변경 뒤 규격은 `7b3c2db703a83824ee6d173262bbefec34b5210c74954d7c5dc8556c1fb0f75b`다. 착수 HEAD와의 규격 diff는 이 작업의 텔레그램 교체 부분이다. 기존 Slack 계약의 동작 검사가 실행되기 전에 전체 파일 해시 단정에서 멈춘다.
- 구현자가 기존 수락 시험의 기대 해시를 임의 갱신하거나 skip하지 않았다. 권고: 계획 담당이 이 단정의 보호 범위를 검토해 승인된 새 규격 기준으로 정합화한 뒤 재인계한다. 제품을 옛 규격으로 되돌리는 선택은 승인된 교체 목표와 충돌한다. 명세·설계·수락 시험 명세 수정 없음.

### 실행 증거

모든 명령은 이 저장소에서 실행했고, 기존 `.build/connections-env.sh`의 Hermes venv/기존 의존성 경로를 썼다. 패키지는 설치하지 않았다. 로그는 추적하지 않는 `.build/telegram-evidence/`에 있다.

| 명령/검사 | 실제 결과·변경본 | 로그 |
|---|---|---|
| `TZ=Asia/Seoul PYTEST_ADDOPTS=--basetemp=/tmp/htfull bash scripts/test.sh` | 최종 종료 **1**, Python **426 passed, 1 failed**(HT-B02만), 기존 async-mark 경고 1건. 제품 커밋 `1ef3ad2`. `set -e` 때문에 그 호출의 배달·앱 단계는 미실행 | `full-final.log`, `full-final.exit` |
| Hermes venv `python -m pytest tests/acceptance/test_telegram.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp=/tmp/httestfinal` | 종료 **0**, **38 passed**. 최종 절차 보완을 포함한 시험 작업 트리; 제품은 `1ef3ad2` | `acceptance-final.log`, `acceptance-final.exit` |
| `TZ=Asia/Seoul bash app/scripts/test.sh` | 종료 **0**. AT-HT-50~52 및 전체 앱·통신·훅 통과. 앱 변경본 `0ded4b8`; 이후 앱 diff 0건을 확인해 결과 재사용 | `task05-app-final.log` |
| Hermes venv `python -m gate.tests.telegram_settling` | 종료 **0**, AT-HT-44 수준 **3**, 5회 `[0.024027290986850858, 0.017138208961114287, 0.016871250001713634, 0.0187675419729203, 0.03308812482282519]`초, 전부 2초 미만. 제품 `1ef3ad2` | `settling-final.log`, `settling-final.exit` |
| Hermes venv `python -m gate.tests.gateway_delivery` | 종료 **0**, 실제 격리 게이트웨이 배달·오프라인 재생·중복 검사, 다른 플랫폼 실제 발송 0, 깨끗한 종료. 제품 `1ef3ad2` | `gateway-final.log`, `gateway-final.exit` |
| mutation check(계정 일치 제거·작성 중 대기 제거·텔레그램 수신 되보내기 허용) | 최종 제품의 세 변형 모두 의도한 단정에서 종료 **1**로 검출했다. 원복 후 제품 diff 0. 문 38건 최종 통과로 원복 확인 | `mutation.json`, `mutation-account.log`, `mutation-typing.log`, `mutation-echo.log` |
| 임시 빈 HERMES_HOME의 Hermes venv `python scripts/scan_private.py` | 종료 **1**, 다른 작업 문서의 절대 경로 4건. 이 작업 파일 지적 **0건**(아래). 전체 통과로 보고하지 않음 | `private-final.log`, `private-final.exit` |
| `git diff --check` | 종료 **0** | 도구 실행 결과 |

- 개인값 지적: `docs/changes/HEJO-DEADLINE-CLOSE-20261122/impl-report.md` 97·109행, 같은 폴더 `verdict.md` 127·146행. 범위 밖 문서는 수정하지 않았다. 이 작업의 문·앱·시험·보고 파일에는 지적이 없다.
- 이전에 다른 작업 보고에 적힌 locale 관련 기존 실패는 참고만 했다. 기준 계획 커밋을 임시 폴더에 추출한 `test_delivery_parity::test_native_labels_outcome_and_repeat_are_idempotent`는 이번 환경에서 종료 0/1 passed였다(`baseline-parity.log`). 최종 전체 실행의 실패는 HT-B02 하나다.
- 필요한 수준과 도달 수준: 문·앱 기능은 대역 통합 **2**, AT-HT-44만 **3**. 실제 텔레그램 SDK·봇·안드로이드 실물은 미검증이며 TASK-07·08 몫이다. 게이트웨이 재시작·설치·운영 설정/비밀 파일·본체/플러그인/team-kit/ddots 수정·실제 메시지 발송·푸시는 하지 않았다. 새 하위 에이전트도 사용하지 않았다.
- 다음 담당: HT-B02의 시험 계약을 판단해 보완하고, 이 작업 변경 코드와 위 로그를 검토한다. 전체 실행 실패와 다른 작업 문서의 개인값 지적이 남아 푸시 대상·승인 요청은 제안하지 않는다. 롤백은 운영 미적용 상태에서 이 작업 커밋 되돌림이다.


## TASK-07 — 서버 적용 전 보류(HT-B03)

- 받은 지시: `223a191accbb70c28f7b35cfdf2eee9490dfb109`의 [handoff-task07.md](handoff-task07.md), 사장 서버 적용 허가. 실제 적용·재시작·자동 의존성 설치 결과 확인을 맡았으나 아래 명령/금지 충돌로 운영 변경 전에 보류했다.
- 상세 사전 기록·실제 경로 변수의 로컬 위치·롤백 명령·명령별 실행/미실행은 [TASK-07 증거](../../../evidence/HEJO-TELEGRAM/TASK-07.md)에 있다. 공용 RELEASE `227ef160694635f8afde36f06515f5136f73dc30`와 착수 HEAD의 설치 범위 diff는 검증된 텔레그램 변경뿐이다.
- HT-B03: 인계에서 명시한 `hejo-install --check`는 운영 프로필 config.yaml 전체 읽기(`install/hejo-install:695`, `read_config:112`)와 영수증 상태에 따른 인증 토큰 파일 hejo/admin.json 지문 읽기(`install/admin_support.py:62~65`)를 수행한다. 같은 인계는 운영 설정·비밀 파일 열기를 금지한다. 명령 내부의 이 읽기를 예외로 간주할 권한이 명시되지 않아 임의로 실행하지 않았다. 운영 파일 내용은 열지 않고 설치 도우미 소스에서 확인했다.
- 도달 상태: 적용 전 읽기 조사·롤백 준비. `install/hejo-release`, `hejo-install --check`, 재시작과 재시작 뒤 검증은 미실행. 따라서 AT-HT-61 및 요구 수준 3은 미도달이다. 착수 상태는 gateway running·PID 생존·active_agents 1, Telegram 모듈 없음이다(재시작 직전 판정이 아님).
- 검증: 로컬 preflight 보조 명령 종료 0, Git diff/log 명령 각각 종료 0, Hermes venv 의존성 검사 명령 종료 0(모듈 부재 확인). 증거 폴더 `.build/HEJO-TELEGRAM/task07/`. 기록 파일을 포함한 개인값 검사는 종료 1(다른 작업 HEJO-DEADLINE-CLOSE 문서 절대 경로 4건, 이번 파일 0건; `private.log/.exit`), `git diff --check`는 종료 0이다.
- 권고/다음: 계획 담당이 지정 확인 명령의 정상 내부 읽기를 한정 허용할지, 파일 내용을 열지 않는 대체 확인을 쓸지 결정해 인계를 정합화한다. 재개 시 최신 RELEASE·HEAD와 재시작 직전 active_agents를 다시 확인한다. 텔레그램 패키지 직접 설치·앱 교체/공개·실제 발송·본체/플러그인/team-kit 변경·푸시는 수행하지 않았다. 다른 작업 미추적 문서는 보존했다.
