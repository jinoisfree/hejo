# 설계 v3

칸 배치는 [spec](spec.md)을 따른다. 내부 버그 조사이므로 외부 기술 탐색은 생략했다.

## 현황과 가설
- ConnectionsModel.perform은 busy=true 후 인증, 재시작 확인, send, refresh를 기다리고 defer로 해제한다.
- ConnectionsWindow.ask는 inputWindow ?? window에 NSAlert sheet를 붙인다. updateLevel은 확인 중 부모를 normal로 낮추며 restoreFocus는 입력창까지만 올린다.
- ConnectionInputView는 모든 단계에 저장 안내·같은 주 버튼을 사용한다.
- app/Tests/ConnectionsTests.swift의 finderConnectionsLevelTests는 입력 sheet의 attachedSheet 존재와 level을 검사하고 프로그램으로 종료한다. 사용자가 실제 볼 수 있고 클릭할 수 있는지 보장하는 증거가 아니다.
- [미확정] 실제 원인은 확인창 가림, 인증 대기, 요청 대기 중 하나일 수 있다. 새 테스트에서 재현한 대기 단계와 창 관계를 먼저 기록한다. 기존 코드를 추측으로 전면 교체하지 않는다.

## 책임·수정 방향
UI 단계 표현은 ConnectionInputView, 작업 상태는 ConnectionsModel, sheet 소유·포커스·닫기는 ConnectionsWindow가 계속 책임진다. 별도 창 관리자나 서버 상태 원본을 만들지 않는다.
재시작 단계는 기존 next.kind에서 버튼·설명을 파생한다. 인증과 앱 내부 확인의 창 처리를 구분하고, 실제로 가려지는 조건이 확인되면 기존 ask/updateLevel/restoreFocus에서 고친다. 필요하면 입력 sheet를 안전하게 내린 뒤 같은 연결 부모에 확인 sheet 하나를 표시하고 취소 시 원래 단계를 복원한다. 두 경로를 영구 병행하지 않는다.
취소·닫기·실패는 기존 pending 요청 및 확인 continuation의 수명에 맞춰 정확히 한 번 마무리한다. 이미 전송한 서버 작업은 취소했다고 주장하거나 재전송하지 않는다. 재시작 상태는 기존 job_status 경로를 유지한다.
대안: 버튼 잠금만 없애기 — 중복 실행·확인 우회가 생기므로 기각. 재시작 자동 실행 — 사용자 확인 계약을 깨므로 기각.

## 기존 경로 판정
유지: connection_action, resume=gateway_restart, 재인증, 확인, job_status, 요청 제한 시간, 서버 BUSY 검사, 저장값 제거.
교체: 단계 구분 없는 주 버튼·저장 안내. 확인된 원인에 해당하는 기존 sheet 표시·종료 처리만 같은 자리에서 수정한다.
금지: gate·team-kit·Hermes 본체·운영 설정 변경. 원인이 그쪽이면 증거를 남기고 범위 재설계를 요청한다.
SwiftUI 예외: 기존 ConnectionInputView/ConnectionsView만 유지한다(HEJO-CONNECTIONS design 3.5). 새 화면은 만들지 않고 확인창은 AppKit을 유지한다.
위험도 일반: UI 표시·복귀 수정이며 인증 정책·실행 동시성 계약은 유지한다. 인증 우회나 서버 작업 취소·동시성 변경이 필요하면 중단·재분류한다.
복구: 이 작업의 UI 변경만 되돌린다. 운영 변경은 없으므로 운영 롤백 작업 없음.

## 계획 검증 1회차 보완
- [확인] gate/connection_runtime.py RestartJobs.start는 pending 기록을 먼저 남기고 restart를 await한 뒤에야 job 응답을 반환한다. TeamKit 재시작 제한은 150초, 앱 요청 제한은 180초다. 따라서 확인 수락 후 원래 응답을 못 받는 경로를 별도 재현해야 한다.
- ConnectionsModel의 기존 resumeRestart/startPolling을 보완해 수락 후 전송 오류·시간 초과에서 읽기 전용 추적으로 이어 간다. 기존 show 진입도 같은 결과 처리 경로를 사용한다. 원래 요청이 지연 중이면 대기 표시와 닫기 동작을 유지한다. 알려진 job을 우선하며 job을 받지 못한 경우 기존 latest 조회를 사용한다. 재시작 요청을 다시 보내지 않는다.
- latest는 기기 기준 최근 기록이며 현재 요청과의 상관관계를 보장하지 않는다(RestartJobs.result). latest에서 찾은 결과는 ‘최근 재시작 결과’로 표시하고 이번 요청의 성공이라고 단정하지 않는다. UNKNOWN_JOB 또는 읽기 실패도 미실행의 증거가 아니다. 요청 프로필·알려진 job은 요청 시점 값으로 추적하며 화면 선택 변경으로 바꾸지 않는다.
- 기존 조회 간격·횟수 한도를 재사용한다. pending 이외 모든 종료 상태와 조회 기한 종료를 명시적으로 표시한다. OAuth 동의 만료용 ‘다시 연결’ 안내는 재시작 추적에 사용하지 않는다. 닫기는 로컬 화면/조회 수명만 끝내며 서버 취소를 뜻하지 않는다. 늦은 원래 응답과 조회 결과는 이미 닫은 입력창을 다시 열거나 부작용을 재전송하지 않는다.
- 기존 경로 판정 추가: 일반 catch의 재시도 안내는 재시작 수락 후 불확실 결과에 한해 위 조회 흐름으로 교체한다. OAuth 등 다른 작업 계약은 유지한다. 새로운 서버 동시성 제어나 저장 구조는 만들지 않는다.
- AT-FF-22 중 앱 내부 NSAlert 확인 동안 normal 레벨을 강제하는 기대값은 교체 대상이다. 새 기준은 AT-CS-02의 실제 가시성·조작성이다. 시스템 인증 동안 normal 전환·이후 복원 기준은 유지하고 앱 내부 확인과 구분한다. 기존 tests/acceptance의 과거 FF 기록은 소급 수정하지 않으며 이번 승인 기준으로 해당 구현 시험 기대값을 교체한다.
- 대역은 즉시 오류 반환만으로 끝내지 않는다. 제어 가능한 지연/무응답 send와 요청 timeout 경로를 연결해 인증 대기, 확인 대기, 전송 응답 대기를 각각 구분한다. 시험만 제한 시간을 주입해 실제 timeout 처리 경로를 실행하고 제품 기본 180초는 유지한다. 프레임 종류·횟수, 단계, 가짜 창 번호·순서와 종료 상태를 기록한다. 대역 재현은 원래 운영 화면의 원인 확정과 구별해 보고한다.

## 계획 검증 2회차 보완
게이트웨이 줄의 직접 gateway_restart도 같은 RestartJobs.start를 거친다(gate/connection_manager.py execute). 입력창 유무와 관계없이 수락 후 전송 오류·시간 초과는 위 읽기 전용 추적 계약을 적용한다. 입력창이 없는 경우 연결창 notice에 진행·최근 결과·확인 불가를 표시한다. 직접 실행에는 resume 값을 추가하지 않는다.
작업 문서 원본은 이 작업 ID 폴더 하나로 통일했다. 이전 이름의 폴더는 이동했으며 사본이나 별도 인계서는 남기지 않는다.

## 구현 검토 보완 — V-CS-02
IMPL-CS-01 수용. 기존 경로의 교체 대상에 AT-HC-26의 앱 내부 확인 normal 단언도 포함한다. 원래 수락 명세는 sheet·앱 모달 금지이며 normal 자체는 외부 계약이 아니다. preferredLevel=26에서 부모·확인 sheet가 선호 높이를 유지하고 실제 보임·키 대상임을 검사한다. NSApp.modalWindow==nil, 취소 후 continuation 완료를 유지하고 시스템 인증 normal 전환은 변경하지 않는다. FF-22와 같은 가시성 기준을 적용하며 시험을 제거하거나 시험별 제품 분기를 만들지 않는다. 요구·AC·서버 계약 변경 없음.
