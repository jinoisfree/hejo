# 작업 분해

7판 · TASK-03A/04 구현·부분 검증 확보. TASK-05의 기존 설치 복구 3시험 실패로 보류. 현재 코드/증거는 impl-report와 왕복 4 verdict를 따른다.
REQ·AC 원본은 [spec](spec.md), 시험 번호는 [수락 명세](../../../tests/acceptance/HEJO-GOOGLE-DISCONNECT.md).

| TASK | 요구·시험 | 책임·파일 | 선행·완료 조건 |
|---|---|---|---|
| TASK-01 | 전체 AC, GD-T01~20 | 수락 시험 코드와 가짜 홈/인증 공급자. hejo tests/acceptance/test_google_disconnect.py, app/Tests/ConnectionsTests.swift, 운영 team-kit/tests의 새 시험 | 계획 검증 통과·격리 기준 확정 후. 명세 기대값 그대로 코드화, 최초 예상 실패 기록. 실환경 T17/T19 절차 준비 |
| TASK-02 | 01·02·04·NFR, T01~08,T11~15 | 운영 hermes_facility/google_connection.py, account_connect.py, connections.py, owner_vault.py, config_assembly.py, connection_checks.py; 인증 worker 및 CLI 고정 진입점 | 01 후. 직원 원본·자격·OAuth 상태·원자성·복구·비밀 보호 구현. app_connect의 토큰 장부 재사용 금지. 변경 범위 내 기존 공용 경로 대체 |
| TASK-03 | 01.03·03·NFR, T03,T08~10,T15,T20 | design 소비자 표의 메일·캘린더·worker·승인/undo·secret_guard·doctor 및 Workspace 팩/조립 스킬 | 02 후. 코드 작성 전 workspace-command-map.md를 선행 산출물로 작성(기존 명령/인자/출력/승인·인증·refresh/새 어댑터/시험 대응). 이전 불가 명령·라이선스 문제·본체 수정 또는 권한 완화 필요 시 해당 TASK 중단·기획 반환. 대응 가능할 때만 새 인증 공급자로 연결, 옛 경로 우회 제거, 기존 기능/승인 불변 증거 |
| TASK-04 | 01·02·05, T01~07,T17,T18 | gate/connection_runtime.py, connection_manager.py, app/Sources/ConnectionModels.swift, ConnectionsWindow.swift, schemas/hejo-wire-v1.json | 02 후. capability와 삭제 의미 확인 값의 왕복 검증·Touch ID 없는 소유 세션 cancel·직원별 poll·확인 문구·목록 갱신·구버전 호환. AppKit 가짜 서버 실물 증거 |
| TASK-05 | 전체, T01~18,T20 | 통합·회귀·빌드·개인값 검사·install/check_google_compat.py, install/google-connection-support.json(지원 버전 산출물), install/hejo-install, install/hejo-release; 운영 hermes/bin/hermes-team-kit-deploy(신규 apply/rollback), hermes/bin/hermes-plugin-store(--migrate/--restore-copies/실패 복구)의 공통 검사 호출·impl-report.md | 03/04 후. design 배포 진입점 표의 파일·명령별 산출물과 GD-T14 실행 증거(누락 0). 실제 hejo-release로 만든 배포본에 검사기·지원 버전 메타데이터가 포함되고 scripts/·작업본 없이 설치·검사가 동작함을 확인. 전체 실행 증거, 실패 0 또는 원인과 차단 기록. 운영 인계 초안·롤백·지원 명령 대응표·커밋 대상 정리. 운영 적용/푸시 실행 금지 |
| TASK-06 | 05.02, T19 | 별도 승인된 운영 인계·사용자 직접 OAuth 확인 | 개발 검증·고위험 독립 검토 후, 실제 운영 변경 승인 필요. 본 TASK는 첫 구현 인계 실행 범위 밖 |
| TASK-07 | 전체 | 최종 검토·verdict.md·docs/spec/current/google-connections.md·hejo docs/ARCHITECTURE.md 사장 금고 행에 owner/vault.yaml 및 직원 홈 hejo/ 배치 반영·운영 근간 참조 일치 확인 | 기획설계·검증 담당 소유. 실제 적용 뒤 Target→Baseline, 미완료 조건 남기지 않고 푸시 승인 대기 보고 |

병렬 갈래: 없음(독립 구현 갈래 3개 미만). TASK-02가 인증·금고 계약을 먼저 고정하고 TASK-03/04 두 갈래가 이를 소비한다. TASK-03의 조립/등록은 다른 작업의 team-kit 초기화 변경과도 겹칠 수 있다. 각 TASK를 직렬로 인계하며 모델·대화 생성은 호스트만 담당한다.

시험 명령: hejo `bash scripts/test.sh`, `bash app/scripts/build.sh`, `python3 scripts/scan_private.py --home <임시 홈>`; 운영 저장소는 해당 AGENTS.md의 검증 Python으로 team-kit 관련 pytest와 `./airport-check --snapshot`. 실제 명령·환경·종료 코드·커밋·로그를 구현 보고에 기록한다. 임시 홈 검사는 일반 패턴/가짜 값에 대한 축소 검사로 명시한다. 최종 공개 검증에서는 AGENTS.md의 python3 scripts/scan_private.py를 실제 운영 홈 기준으로 별도 실행한다(상속된 가짜 HERMES_HOME이 없는지 확인). 이 검사는 기존 검사기가 owner/team.yaml과 owner/vault.yaml을 내부 비교용으로 읽고 일치 원문을 출력하지 않는 동작에 한정한다. 에이전트에게 원문을 반환하거나 .env/auth.json/토큰을 읽지 않는다. 접근 불가 시 전체 검사를 통과로 대체하지 않고 최종 완료를 보류한다. 신규 문서도 최종 검사 대상 Git 파일에 포함되었는지 확인한다. 원격 푸시는 플러그인 화면 승인만 허용한다.

동시 변경: 조사 시 hejo의 Telegram 변경과 운영 저장소 app_connect.py·team-kit/__init__.py 등에 미커밋 변경 존재. 호스트 격리 공간에서 작업하되 두 저장소를 모두 격리하거나 겹치는 작업 완료를 기다린다. 미커밋 변경을 임의 복사/커밋하지 않는다. 최신 기준과 영향 파일을 비교해 의미 변화가 있으면 기획에 반환한다.


TASK-05 경로 규칙(R10): design의 ‘공통 검사기 경로 결정’을 적용한다. 운영 명령은 루트 홈의 plugins/hejo 설치 링크와 hejo/install-receipt.json을 대조하고 설치된 gate의 부모에서 install/check_google_compat.py를 찾는다. 최초 hejo 설치만 검증된 설치 패키지 상대 경로를 사용한다. 개인 절대 경로·운영 저장소 위치 하드코딩, PATH/cwd/대상 구버전에서의 대체 탐색은 금지한다. GD-T14는 서로 다른 임시 홈·설치본 위치에서 같은 결과, 링크/영수증 불일치·누락·검사기 symlink·대체 탐색 거절을 확인한다.


## 왕복 2 수정 계획 — TASK-03A

TASK-03 내부의 선행 보완으로 design의 ‘6판 보완’을 구현한다. 기존 두 worktree와 source-checkpoint-03 변경을 보존한다. worktree 생성·TASK-02 전체 재구현은 반복하지 않는다.

1. 현재 manifest/pack catalog 생성 흐름 및 선택 스킬 조립기의 실제 파일을 workspace-command-map에 연결한다. 명령별 기존 권한·승인·파일 범위를 표에 덧붙인다. 기존 권한의 교집합으로 표현할 수 없는 명령은 먼저 기획에 반환한다.
2. 새 공식 도구 4개의 typed schema와 거절 시험을 먼저 작성한다. 변경 범위는 운영 hermes_execution의 등록/Workspace 내부 어댑터, 각 소유 팩 pack.yaml/plugin.yaml과 catalog 생성 원본, 호스트 manifests, personal_roles/personal_scopes/app 권한 판정, approval/request_approvals, 기존 선택 스킬 조립 경로다. 새로운 허용 grant를 자동 생성하지 않는다. 임의 shell/자격 복제 없이 기존 24개 업무 함수를 연결한다.
3. GD-T20 확장 시험을 실제 등록·hook/middleware로 실행한다. 직접 함수 호출만 하는 fixture를 제품 경로 증거로 대체하지 않는다. GD-T09/10/15/16의 binding·파일·회사/미전환 회귀를 함께 검사한다. 기존 105개 시험과 판정 시 추가된 시험을 포함한 변경본 지문을 보고한다.
4. TASK-03 소비자 통합 통과 후 TASK-04, TASK-05를 직렬 진행한다. 기존 gate/release/AppKit의 예상 실패를 실제 성공으로 바꾸고 정상 release 설치/복구 및 안전한 전체 검증을 수행한다. 운영 적용과 실계정 OAuth는 TASK-06 별도 승인이다.

spec AC는 그대로 유지한다. 실행 경계 변경으로 5판 승인만 사용해 TASK-03A를 착수하지 않는다. 호스트 수정 계획 승인 흐름을 거친다.


## 왕복 4 수정 계획 — TASK-05 복구·갱신 완료

- design의 7판 좁은 복구 예외를 install/check_google_compat.py와 hejo-install에 구현한다. 기존 test_install.py 세 실패의 기대값/skip을 바꾸지 않는다. 정책 원본은 검사기 하나며 installer는 기존 영수증·파일 상태를 제공한다. 새 상태 파일/우회 옵션을 만들지 않는다.
- tests/acceptance/test_google_deployment.py에 failed/uninstalled 긍정·부정·동시 전환 경계와 사용자 설정 --force 의미를 추가하고 기존 설치 52시험을 재실행한다. 기존 29개 배포 경계도 함께 검증한다.
- 새 release A→B의 root/profile link·receipt 갱신 및 team apply/rollback 뒤 overlay 신규·삭제 파일 반영을 구현/검증한다. 중단 시 기존 영수증·데이터 보존과 호환 버전 복구를 확인한다. 기존 공유 폴더의 무조건 교체로 해결하지 않는다.
- owner_vault 정상 YAML 생성과 검사기 읽기의 가짜 데이터 왕복 시험, 전체 안전한 회귀·제품 빌드·최종 개인값 검사·airport-check를 마친다. gate 51시험 로그의 argv 누락은 실제 명령·대상·변경 지문이 있는 재검증 로그로 보완한다. AppKit AT-HC-27는 대조 HEAD에도 같은 실패임을 별도로 처분하며 전체 UI 통과라고 보고하지 않는다.
- impl-report에 AC별 증거, 남은 운영 승인 범위, 고위험 독립 검토용 정확한 변경본을 제출한다. 기획/검증은 추가 검토 및 TASK-06 운영 인계를 그 뒤 처리한다. 기존 worktree를 재사용하며 다른 작업·실운영·푸시를 건드리지 않는다.


## 왕복 5 잔여 작업 — 설계 7판 유지

1. 수락 명세의 ‘왕복 5’ 처분에 따라 test_cm24_25_actual_cli_arguments의 Google 개인 해제 분기만 새 삭제 확인 argv로 이관한다. 누락/오류 값에서 CLI 미실행도 검증하고 다른 서비스·connect/undo 기대는 유지한다. 이를 이유로 제품 검사를 약화하지 않는다.
2. AppKit 전체 시험 자식 프로세스에 aiohttp가 설치된 기존 HEJO_PYTHON을 명시적으로 상속시킨다. 정확한 실행 파일·cwd·환경 전달·자식 stderr를 기록한다. task05-app-full-02.log의 ModuleNotFoundError와 PostGroupTests.swift의 HEJO_PYTHON/default 분기를 근거로, 먼저 같은 실행 환경에서 import 확인 후 격리 전체 UI 시험을 재실행한다. 새 패키지 설치나 UI 코드 수정부터 시작하지 않는다. AT-HC-27 및 이후 실패는 각각 현재/대조 HEAD와 구분해 처분한다.
3. 새 시험 변경을 반영한 전체 Python 회귀와 필요한 AppKit 검증을 실행해 명령/종료 코드/변경 지문을 보고한다. 이미 통과한 무변경 제품 빌드·배포 시험을 이유 없이 반복하지 않는다. 독립 검토용 코드/로그 상태와 운영 인계 초안을 갱신한다.
4. 전체 공개 개인값 검사 실패는 기존 mockup 14개 파일의 30건이다. 현재 작업 밖이므로 임의 수정/삭제/허용 목록 추가를 하지 않는다. 별도 정리 담당 또는 사용자의 제한적 정리 범위 승인을 호스트에 요청할 대상으로 남긴다. 정리가 승인되면 기존 기준선의 검출 부분만 가짜 값으로 교체하고 최신 변경과 충돌 확인 후 전체 검사로 검증한다. 범위별 0건을 전체 통과로 바꾸지 않는다. 이 결정 대기는 1~3의 이미 승인된 시험·환경 보완을 막지 않는다.
5. 최종 완료 전 고위험 독립 검토·설계 비참여 추가 검토, 별도 운영 적용 승인과 사용자 직접 GD-T19를 확보한다. 현재 코드의 강제 종료 후 installed 링크/영수증 불일치는 자동 복구 성공이 아니라 fail-closed 운영 복구 필요 상태임을 유지한다. 커밋/푸시 준비 완료로 먼저 올리지 않는다.


## 왕복 6 — 재구현 없이 남은 검토·처분

왕복 5의 전송 시험 이관과 Python 환경 보완은 수락했다. checkpoint-07 기준 제품 소스는 checkpoint-06과 같고 test_conn_manage.py만 바뀌었다. 같은 수정·전체 pytest를 반복 인계하지 않는다.

1. 호스트가 구현 비참여 다른 모델 및 설계 비참여 검토 조건을 충족하는 읽기 전용 리뷰를 배정한다. 대상은 두 worktree의 checkpoint-07(79개 파일), canonical spec/design/수락 명세/impl-report와 실제 로그다. 요약만 검토하지 않고 OAuth·금고/자격·binding/승인·파일 권한·배포 복구의 실제 생산자/소비자를 확인한다. 결과는 이 폴더 independent-review.md에 지적/근거/범위/모델·역할 독립성으로 인계한다. 에이전트가 직접 별도 대화를 만들지 않는다.
2. AT-HC-27는 현재와 기준 HEAD의 서명한 실행 파일에서 동일 실패하므로 Google 변경의 새 회귀로 단정하지 않는다. 기존 UI 담당 또는 읽기 전용 조사에서 창 활성/세션 환경/fixture 조건을 구분하고, assertion을 우회하지 않은 실행 조건 또는 필요한 별도 수정 범위를 제시한다. 같은 전체 UI 재실행만 반복하지 않는다. 기본 모드에서 실패 이후 실행되지 않은 시험 목록과 후속 fixture의 실제 커버리지도 보고한다. 현재 Google 시트 통과와 후속 13개 성공은 전체 기본 모드 성공을 대체하지 않는다.
3. 기존 mockup 14파일30건 정리는 별도 담당/사용자 범위 승인으로 해결한다. 원문을 인계에 복제하지 않는다. 별도 수정이 승인되기 전 다른 작업 파일을 건드리거나 검사기를 완화하지 않는다. 전체 공개 검사는 정리된 최종 변경본에서 다시 확인한다.
4. 독립 검토의 구체적 지적 또는 승인된 정리 결과가 생긴 뒤에만 필요한 구현·영향 시험을 다시 배정한다. 모든 로컬 완료 조건을 처분한 뒤 고정된 결과 커밋과 실운영 적용/복구 계획을 준비하고 TASK-06 사용자 직접 OAuth 승인을 받는다. 운영·푸시를 먼저 실행하지 않는다.


## 왕복 7 — 호스트가 먼저 처리할 배정

1. checkpoint-07 고정 변경본의 고위험 독립 리뷰를 구현·설계 비참여 다른 모델에 배정한다. 기존 구현 담당은 자기 구현의 독립 리뷰 작성자가 될 수 없다. canonical independent-review.md에는 실제 파일·시험/로그 참조, 발견별 등급/위치/근거, 검토 범위와 모델/역할 독립성을 기록한다. 호스트가 배정하지 못하면 사용자 배정 결정으로 올리고 동일 구현자에게 조사 반복을 보내지 않는다.
2. UI 조사 제출은 수락했다. 독립 리뷰가 AT-HC-27의 코드/fixture/실행 환경을 판단하도록 원본 호출 순서와 round06-focus-probe.log를 제공한다. 외부 SecurityAgent 전면은 관측 사실이며 원인 확정이 아니다. 보안 대화 자동 승인·종료나 assertion 삭제/대기 무한 확대는 하지 않는다. 성공 가능한 UI 실행 환경 또는 필요한 제한적 수정안을 먼저 결정한 뒤 재검증한다.
3. 해당 환경이 확보되면 원본 connectionsTests 전체와 기본 모드의 이후 9함수를 검증한다. 독립 함수별 실행이 필요하면 기존 진입점을 사용하고, 진입점이 없는 연결 관리/불완전 응답 시험은 원본 단언·의존성을 유지하는 별도 시험 하네스 범위를 검토자가 명시한다. 후속 네트워크 fixture 13개로 이 범위를 대체하지 않는다.
4. 기존 mockup14파일/30건 정리의 담당/범위 승인과 이후 전체 공개 검사는 별도 미해결 조건이다. 현재 구현자에게 무단 정리를 지시하지 않는다. 독립 지적·환경 결정·정리 승인 중 실행 가능한 새로운 근거가 생기면 해당 부분만 인계한다. 그 전 제품 재구현·무변경 전체 시험·커밋·운영·푸시를 반복하지 않는다.


## 사용자 완료 지시 후 — 제한적 마무리 범위

사용자가 ‘완료되게끔해줘’라고 지시했다. 이를 로컬 완료에 필요한 다음 최소 보완을 진행할 권한으로 해석한다. 이전의 mockup 정리 범위 결정 대기를 아래 특정 범위로 해소하며, 실제 운영·실계정 동의·푸시 승인은 포함하지 않는다.

1. 기존 격리 hejo worktree에서 task05-private-baseline-01.json이 지정한 mockup14파일의 검출30건만 공개용 가짜 값으로 치환한다. 파일 삭제/레이아웃 변경/기능 변경은 하지 않는다. 대응 문서가 있는 원래 작업 폴더에는 동시 변경 여부를 먼저 비교하고 다른 작업을 덮어쓰지 않는다. 충돌 시 격리 수정본을 유지하고 충돌 부분만 보고한다. 검출 원문을 로그/보고서에 복제하지 않고 스캐너/허용 목록은 유지한다. 미추적 문서까지 포함한 전체 공개 검사를 최종 후보에서 통과시킨다.
2. UI 시험의 실행 가능 조건을 먼저 확인한다. 기존 서명된 실행 파일과 HEJO_PYTHON을 유지하며, 외부 보안 대화를 조작하지 않는다. 앱 활성화/키 윈도 전환의 event timeline을 관측한다. AT-HC-27의 임의 0.1초 뒤 확인은 AppKit 활성화 완료를 보장하지 않으므로 기존 테스트 waitFor를 사용한 유한 event wait(상한 명시)로 관측 시점을 맞추는 시험 하네스 보완을 허용한다. 성공 조건인 visible/key/입력 정리/busy 해제는 그대로 유지한다. 테스트가 대신 창을 key로 강제하거나 show의 제품 결함을 가리는 방식은 금지한다. 이벤트가 오지 않으면 timeout 실패와 환경 이유를 보고한다. 실제 제품 show/restoreFocus 결함이 입증되면 해당 원인/최소 수정 위치를 기획에 반환한다.
3. 원본 connectionsTests 전체와 이후 기본9함수를 실행한다. 전체 기본 모드가 외부 활성화 조건으로 중단되면 각 독립 시험을 기존 진입점 또는 원본 함수를 호출하는 제한된 실행 모드로 실행해 미실행 범위를 해소한다. 이 방식은 AT-HC-27 실패를 성공으로 바꾸지 않으며 UI 전체 성공/부분 검증을 구분한다. 실패 환경에 사용자 조치가 꼭 필요하면 해당 조치만 요청하고 완료를 주장하지 않는다.
4. 수정된 시험/문서에 필요한 회귀·전체 공개 검사와 지문을 제출한다. 제품 무변경 통과 시험의 반복은 피한다. 호스트는 이 보완과 별도로 독립 리뷰를 구현·설계 비참여 다른 모델에 배정한다. 구현 담당은 독립 리뷰를 대신하지 않는다. 새로운 검토 지적을 해결한 뒤 결과 커밋·운영 인계·푸시 대상 확인 자료를 준비한다. 운영과 푸시는 사용자 별도 승인 단계로 남긴다.


## 왕복 9 — UI·공개 검사 해소, 독립 검토로 전환

checkpoint-08의 hejo28/team65 실제 지문과 최신 성공 로그를 대조했다. GUI 준비 후 원본 연결 전체·관리 시험 성공, 기존 후속 함수 성공과 전체 공개 검사0을 수락해 V-GD-12/15를 닫는다. 최신 판정은 UUID 폴더 verdict.md의 부분 완료다. 설계7판 유지. 다음 작업은 [독립 검토 인계](independent-review-request.md)의 호스트 배정이며 같은 구현자에게 통과한 UI 조사나 자체 독립 리뷰를 반복시키지 않는다. 그 결과 처분 뒤 운영 인계·사용자 GD-T19 승인 단계로 진행한다. 운영/실계정/푸시 승인은 추가되지 않았다. 검토 로그: `.build/google-disconnect-evidence/review-09-integrity.json`.


## 독립 리뷰 IR-1 보완 인계

Terra 6.1 high의 independent-review.md를 수용한다. 독립 리뷰 배정 대기는 해소됐고 이제 구현 담당의 구체적 시험 보완 작업이다. 설계7판/제품93파일 기준을 보존한다.

- 기존 ConnectionsTests.swift의 실제 AppKit 창·시트와 가짜 서버 fixture를 확장해 GD-T17의 삭제 확인 의미, 해제 뒤 실제 목록/상세 이메일 제거와 연결 버튼, 재연결 성공 후 새 계정, 취소 실패 안내, 만료, 창 닫기 및 목록 갱신을 관측한다. 가짜 계정·임시 홈만 사용한다.
- 실제 NSView/컨트롤과 사용자 동작 및 전송 frame을 함께 검증한다. 모델 값을 단순 대입하거나 confirm callback만으로 실제 화면 확인을 대체하지 않는다. 기존 시간/서버 주입점을 사용하고 원래 단언·skip·실패 의미를 완화하지 않는다. 외부 SecurityAgent는 자동 조작하지 않는다.
- 새 시험과 관련 Google/연결 회귀를 실행하고 변경 파일 지문·정확한 실행 명령/환경·종료 코드·증거를 impl-report에 추가한다. 제품 변경이 필요하면 이유/범위를 명시한다. 무관한 전체 suite 재실행은 하지 않는다.
- 보완 제출 후 Terra 독립 리뷰의 IR-1 재검토를 요청한다. GD-T19와 운영/푸시는 별도 승인으로 유지한다.


## 왕복11 IR-1 창 닫기 최소 보완

checkpoint-09와 Terra independent-review.md 재검토를 기준으로 다음 범위만 수행한다.

1. 기존 인증 시트/연결 창의 실제 사용자 닫기 동작을 확인한다. 노출된 표준 닫기 경로가 작동하면 그 실제 컨트롤/메뉴 액션을 시험에서 실행한다. 시트 부착 때문에 표준 경로를 사용할 수 없으면 기존 AppKit 인증 시트 안에 명시적인 ‘창 닫기’ 동작을 제공하는 최소 제품 보완을 한다. 새 창·저장 원본·인증 경로는 만들지 않는다.
2. 창 닫기는 기존 closeGeneration/model.close 및 소유 작업 account_cancel 경로로 연결하고 늦은 응답/재열기 보호를 보존한다. 실제 취소 전송 실패는 기존 ‘취소 확인 안 됨’ 의미를 유지한다. 새 별도 취소 구현이나 서버 성공 위장 금지. 제품 변경 범위와 이유를 보고한다.
3. 실제 노출된 닫기 컨트롤을 눌러 창/시트 종료 및 정확한 소유 세션 cancel frame을 관측한다. 시험에서 window.close/model.close 직접 호출로 사용자 액션을 대신하지 않는다. 성공 및 실패 뒤 재열기에서 상태/실패 안내가 정확함을 확인한다. 기존 인증 취소 버튼 동작도 영향 회귀로 확인한다.
4. 임시 홈·가짜 loopback만 사용하고 관련 표적 시험·필요 빌드·공개 검사·새 파일 지문을 제출한다. 앞서 수용한 삭제/새 계정/만료의 전체 시나리오를 이 지적만을 이유로 반복하지 않는다. Terra에 잔여 IR-1 처분 재검토를 반환한다. 운영·실계정·푸시 승인 경계 유지.


## 왕복12 — 로컬 검토 통과 후 전달 준비

Terra checkpoint-10 재검토로 IR-1을 닫는다. 새 제품 구현 지시가 아니라 검토된 산출물 고정 단계다. 기존 두 격리 worktree와 소스를 보존한다.

1. checkpoint-10의94개 파일뿐 아니라 실제 git status의 전체 변경/미추적 집합을 비교해 후보 밖 변경 유무를 확인한다. canonical 작업 문서·UUID 판정·수락 명세의 최신본을 hejo 후보에 충돌 없이 포함한다. 원래 작업 폴더의 다른 작업은 가져오지 않는다. 운영 저장소/개인 절대 경로·비밀을 공개 문서에 넣지 않는다.
2. 포함할 문서/코드의 공개 검사 및 diff --check를 마친 뒤 각 저장소에서 이 작업 범위만 로컬 커밋으로 고정한다. 제품 코드가 검토 지문과 다르면 커밋 준비를 멈추고 차이를 보고한다. 결과 전체 커밋·브랜치·원격 이름·파일 목록과 checkpoint 대응을 기록한다. git push는 금지다.
3. 운영 출력·연결·설정에 쓰지 않는 새 로컬 경로에 고정된 후보로 release를 만들고 검사기/지원 선언 포함과 산출물 지문을 기록한다. 기존 패키지/빌드 검증은 입력이 같으면 재사용한다. 실제 설치·apply·rollback·재시작·실계정은 실행하지 않는다.
4. canonical deployment-handoff.md에 후보 두 전체 커밋/산출물 식별자, 적용 순서·예상 영향·중단 조건, 승인 뒤 사용할 정확한 명령 템플릿, 호환되는 복구 대상 선택/검증 절차와 복구 불가 시 닫힘을 작성한다. 전용 자격이나 금고 연결을 과거로 되돌리는 복구는 금지한다. 개인 실제 경로가 필요한 정보는 ignored 로컬 인계로 분리한다. 불명확한 운영 대상을 추측해 실행하지 않는다.
5. GD-T19 사용자 체크리스트를 붙인다: 직원 한 명의 해제 후 이메일 제거, Google 계정 선택, 다른 계정 연결/표시·읽기 전용 확인, 다른 직원 연결 불변. 비밀/메일 본문/토큰 증거를 요청하지 않는다. 실행 승인 전 미실행으로 표시한다. 최종 현재 명세/ARCHITECTURE 반영은 TASK-07 기획 소유이며 실계정 검증 전 완료로 승격하지 않는다.
6. impl-report에 결과 커밋·후보/검증/운영 인계 준비 결과를 제출한다. 기획 검토 후 사용자에게 구체적 운영 승인 결정을 요청한다. 푸시 화면 승인은 별도이며 커밋만으로 최종 완료를 선언하지 않는다.


## 왕복13 / 8판 구현 계획 — 전달 차단2건 해소

- 범위는 design8판과 deployment-handoff의 대응표다. 기존 검토된 Google 인증 구현/IR-1을 유지하고 기존 두 worktree에서 후속 커밋으로 작업한다. 기준 hejo `d25530649f7eb898e2f5cbc5cb471c1417823632`, team `33d6671993473c0eb7ecb4087e0fe4edebc63050`. 기존 커밋을 amend/rebase하지 않는다.
- 먼저 동반5파일 각각의 원본·실제 대상·조립/사용자 필드 소유·복구 단위를 코드에서 추적해 deployment-handoff에 명시한다. 원본 manifest와 사용자 overlay·선택 스킬을 구별한다. 기존 칸 밖 추가 원본이 필요하면 구현 전에 반환한다.
- app/scripts/build.sh의 산출물 ASCII 이름·낡은 리소스 정리, app/Sources/HooksHelp.swift의 조회를 함께 보완한다. 임시 볼륨에서 실제 압축 왕복·서명·안내 조회를 검증한다. 성공한 로컬 bundle만으로 완료하지 않는다.
- 기존 team deploy 및 필요한 기존 조립기/지원 선언/단일 호환 검사기에 bundle 경계를 구현한다. kit-only 호환/거절 조건, 명시적5경로, 전체 사전 검사·잠금·stage·실패복구·중단 검출, grant/선택 보존을 함께 완성한다.
- 가짜 홈에서 전체 bundle apply/rollback 후 실제 등록4도구·선택된 스킬을 확인한다. 미선택 직원/사용자 grant/비관련 manifest 불변, 각 교체 지점 I/O 실패 복구, 중간 종료 후 거절, 지원 누락·섞인 bundle·경로 탈출·로컬 충돌·kit-only 부분 rollback 거절, 기존 미전환 kit-only 계약을 시험한다. 임의 운영 복사/설치/재시작 금지.
- 해당 변경의 독립 Terra 검토·표적 회귀/airport-check/공개 검사 후 후속 커밋과 새 배포 후보·복구 묶음을 고정한다. 전달 인계에서 앱 구성·설치 대상·검사기 탐색·중단/재개·복구 미확정을 남김없이 열거하되 운영값을 추측하거나 비밀을 열지 않는다. 승인할 실운영 대상 확인은 필요한 읽기 전용 비밀 제외 정보로 준비한다. GD-T19·TASK07 승격·운영·푸시는 여전히 별도다.


## 왕복14 / 9판 — 실제 legacy 설치의 안전한 최초 전환 준비

1. source-checkpoint-11과8판 구현은 보존한다. 새 로컬 검토의 D1/D2는 해소됐으며 기존 전체 UI/team 회귀를 반복하지 않는다. impl-report의 상단 ‘현재 검토 원본 checkpoint10’ 잔재를 checkpoint11로 정정한다.
2. design9판의 비밀 제외 시설 비교를 먼저 수행한다. 운영 설치가 원래 hejo/team 도입 전 커밋/릴리스와 전체적으로 일치하는지, 영수증·프로필 링크가 같은지 확인해 ignored 인계에 기록한다. 이미 확인된3파일만으로 전체를 승인하지 않는다. 불일치는 목록/비밀 없는 해시로 반환하며 운영 수정은 하지 않는다.
3. 식별 가능한 검토 기준이 확보된 경우만 기존 hejo-install/단일 검사기/기존 지원 선언에 명시적 최초 전환을 구현하고 team bundle predecessor를 올바른 기준으로 고정한다. 새 저장 원본이나 일반 fallback은 금지한다. 기준이 불명확하면 임의로 allowlist를 늘리지 말고 기획에 반환한다.
4. 임시 홈에서 정상 legacy 전환, checker 존재 시 우회 거절, 영수증/링크/코드/프로필 drift, 전환·자격·활성job 존재, 중단 표식, CAS 경합, 각 쓰기 실패/복구와 재실행 거절을 시험한다. 토큰 내용 읽기/백업 없음과 owner 원본 보존을 검증한다. 최초 검사기 설치 후 실제 bundle apply까지 안전한 전체 경로와 실패 시 닫힘을 확인한다.
5. Terra 독립 검토로 반환하고 통과 뒤 후속 커밋/불변 앱·hejo·bundle·호환 복구 후보를 고정한다. 앱 운영 Google 로그인·업데이트 구성과 실제 적용/중단/재개 대상은 승인 자료에 명시한다. 실제 운영 설치·재시작·실계정·푸시는 하지 않는다. GD-T19와 TASK07 완료 승격은 여전히 이후 단계다.


## 왕복15 — 후속 기능 보존 후 최초 전환 구현

기존 worktree/커밋과8판 미커밋 변경을 보존한다. amend/rebase/pull 또는 무관 브랜치 전체 merge를 하지 않는다. design9판 보완의 두 고정 커밋을 기준으로 아래 순서로 진행한다.

1. 아래 hejo5/team23파일을 지정 커밋의 Git blob에서 선택 통합한다. 동일 바이트는 재작성하지 않는다. team app_connect.py와 connection_checks.py 두 충돌은 양쪽 분기·호출자·거절 동작을 보존하고 대응표를 기록한다. 추가 의존 파일이 필요하면 근거와 범위를 기획에 반환한다.
2. 가짜 홈에서 후속 Telegram 댓글 시험, 변경된 team6시험과 관련 Notion API/범위/승인·원격 앱·첨부/세션 증명 회귀, Google 연결/소비자/승인 회귀를 실행한다. 운영 상위 conftest를 실행하지 않고 격리 fixture를 쓴다. 충돌2파일의 양쪽 정상·실패 동작을 검증한다.
3. 통합 검증 뒤 왕복14의 명시적 최초 전환 구현·임시 홈 시험을 진행한다. predecessor는 고정 legacy 커밋에서 재현하고 candidate kit 식별은 통합 후보로 갱신한다. 미설치 프로필 자동 편입 금지 및 전체 집합 drift 거절을 포함한다. 검사기만 복사하거나 fallback으로 우회하지 않는다.
4. 최종 공개 검사·airport-check·영향 회귀·최초 전환 실패복구 증거와 새 checkpoint를 제출한다. Terra 재검토 뒤 후보·호환 복구 묶음을 고정한다. 운영용 앱 로그인/업데이트 구성의 미확정 항목을 인계한다. 운영·실계정·재시작·푸시는 하지 않는다.

선택 통합 범위(hejo5파일은 hejo 고정 커밋, 나머지23파일은 team 고정 커밋):

- `gate/README.md`
- `gate/adapter.py`
- `gate/telegram.py`
- `gate/telegram_comments.py`
- `gate/tests/test_telegram_comments.py`
- `hermes/plugin-store/team-kit/__init__.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_connect.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_scope.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/connection_checks.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/contracts.py`
- `hermes/plugin-store/team-kit/lib/hermes_owner_chat.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/diagnosis/diagnosis_runtime.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/files.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/app_catalog.json`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/catalog.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/discovery.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/notion/api.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/notion/operations.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/error_digest.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/memory_live.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/work_runtime.py`
- `hermes/plugin-store/team-kit/tests/test_app_catalog.py`
- `hermes/plugin-store/team-kit/tests/test_app_registry.py`
- `hermes/plugin-store/team-kit/tests/test_error_digest.py`
- `hermes/plugin-store/team-kit/tests/test_files.py`
- `hermes/plugin-store/team-kit/tests/test_hejo_session_proof.py`
- `hermes/plugin-store/team-kit/tests/test_owner_provenance_hejo.py`


## 왕복16 — 검토된 통합본의 전달 준비 재확정

적용되지 않은 응답의 통합/최초 전환 재실행 지시는 폐기하고 이번 결과를 기준으로 한다. 지정5/23파일 통합 및 legacy 구현은 제출·검토됐으므로 다시 구현하지 않는다. Notion12실패는 같은 고정 후속 원본에서도 동일하게 재현된 기존 시험/동작 불일치로 기록하며 이번 작업의 신규 회귀 차단으로 다루지 않는다. 원인 미확정이며 정상 동작/전체 team 통과로 표시하거나 기대값/skip을 바꾸지 않는다.

1. checkpoint13 제품을 보존하고 최신 판정·독립 검토·인계를 후보에 반영한다. Notion12노드와 기준 대조 로그를 미해결 기존 사항으로 명시한다. 새 검토 지적이 없으면 제품 수정을 추가하지 않는다.
2. 두 저장소의 최종 변경 집합·개인값 검사 범위·diff 및 지원 선언 식별을 확인한 후 작업 범위만 후속 로컬 커밋으로 고정한다. 이전 커밋을 수정하거나 푸시하지 않는다. 실제 owner 입력 검사를 하지 못하면 가짜 홈 검사와 구분해 이유/미검사 범위를 남긴다. 비밀 파일을 열지 않는다.
3. 고정 소스로 앱·hejo release·team bundle 및 호환 복구 후보를 준비한다. 바뀌지 않은 앱 입력의 기존 서명/압축 시험은 재사용하되 실제 전달 파일 지문·입력 동일성을 확인한다. 바뀐 release/bundle의 묶음 식별·압축 왕복을 확인한다. Google 전환 뒤 legacy 복구는 허용하지 않는다.
4. deployment-handoff의 오래된 round13 출처 표기를 최신 증거로 정리한다. 실제 적용 전 중지/재개·명시적 최초 전환·전체 bundle·앱 교체 순서, 단계별 실패 시 복구 가능 범위와 중단 조건을 구체화한다. 앱 운영 Google 로그인/업데이트 구성은 기존 정식 빌드 경로와 비밀 없는 메타데이터로 확인하고 미충족 조건만 명시한다. 비밀 열람/임의 주입·운영 설치는 금지한다.
5. 커밋 전체 해시·불변 전달/복구 산출물 지문·검증 결과·구체 운영 승인안을 제출한다. 검토된 변경 없는 전체 UI/회귀를 반복하지 않는다. 운영·실계정·재시작·메시지·푸시는 실행하지 않는다. GD-T19와 TASK07은 승인 뒤 실제 확인 단계로 남긴다.
