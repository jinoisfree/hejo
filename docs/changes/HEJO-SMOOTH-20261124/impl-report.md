# 구현 인계: HEJO-SMOOTH-20261124 / v7 공개 통합·설치 결과

## 현재 판단

최신 실행은 아래 **보완 인계 v7 실행 결과**다. 공개 통합 커밋 `e745466bc9772819626ee80cbefc442b02322da4`에서 spec v5 자체 검증을 마쳤고 정상 배포 빌드의 로컬 설치·실행·대화 창 열림을 확인했다. TASK-10·11은 구현 담당 수행 완료이며, 사용자 체감 확인(TASK-12)과 계획 담당의 최종 검토·현재 명세 반영·푸시 대상 확정은 남았다. 실제 메시지 전송과 git push는 하지 않았다. 전체 시험의 기존 실패를 통과로 바꾸어 보고하지 않는다.

아래 v4·v5 본문은 당시의 변경·원시 결과 기록이며 최신 판정은 v6 절을 따른다.

## 변경 파일과 책임

- `app/Sources/ConversationView.swift`: 기존 postPieces에서 글별 최신 표시 입력과 불변 본문·체크 메타데이터 재사용. 매번 가변 본문을 새로 만들던 경로는 miss에서만 실행한다. 동작 클로저·카드 전체를 저장하지 않는다.
- `app/Sources/NativeThreadCard.swift`: 기존 textSize의 객체 식별자·폭 기준 기억을 유지한다. 가변 문자열 제외 규칙도 유지한다. 256개 초과 시 전부 비우던 처리를 4,096개 FIFO 교체로 바꿨다.
- `app/Sources/HejoSmoothProbe.swift`: HEJO_PERF_TESTING에서만 본문·높이 횟수, refresh, 스크롤 시작, 실제 전환 시각을 관측한다.
- `app/Sources/NativeThreadList.swift`, `app/Sources/PetController.swift`: 조건부 관측 지점만 추가. 스크롤 방식·알림 전환 동작은 바꾸지 않았다(TASK-03 미착수).
- `app/Tests/HejoSmoothTests.swift`, `app/Tests/hejo_smooth.py`, `app/Tests/TestMain.swift`: 실제 View 계측·동결·새 View 대조·스트리밍 비교. 기존 최적화 빌드 하네스를 재사용한다.
- 계획 담당 체크아웃 `impl-report.md`와 `tasks.md` 상태 칸: 결과 기록. 그 외 공용 작업 트리 파일은 수정하지 않았다.

본문의 최종 표시 입력 목록: 글 id, 원문, 실제 표시 문자열(스트리밍 단계·긴 답글 미리보기 반영), 내 글 여부, pending, streaming/revealing, 밝기 테마, 발신자 name/link 색, 가장자리 색, ChatAppearance.revision(글자 크기·말풍선 설정 변경 경로), 해당 글의 검색 강조어, 각 체크 항목의 위치·원래 값·현재 모델 값. 체크 상태는 hit마다 현재 모델 값과 대조한다. 창 폭은 기존 높이 기억의 입력이다. 글 이름·시각·첨부·클로저 등 나머지 Post 표시값은 매번 현재 상태로 조립한다.

본문 상한은 View당 2,048개, 높이 상한은 기존 전역 소유 자리에서 4,096개다. 글의 표시 입력이 달라지면 그 글의 본문을 교체한다. 저장하지 않는 파생값이며 새 원본·계층·설정이 없다. 금지된 보이는 카드만 그리는 개조는 하지 않았다.

## 실행 증거

로그는 별도 표기 없으면 **전용 worktree 루트 기준** `app/.build/hejo-smooth/` 아래다. 아래의 `<시험용 Python>`은 Hermes test-environment 현재 세대 venv, `<실행 workspace>`는 Hermes environments 현재 실행 환경의 workspace다. 실제 개인 경로는 추적하지 않는 `task00/v4-clean/environment.local.json`에만 있다. 두 환경은 읽기 전용으로 사용했으며 설치·수정하지 않았다. Python 기준 시험은 임시 HERMES_HOME·짧은 TMPDIR·짧은 pytest basetemp를 사용했다. Swift 계측은 `/tmp` 아래 임시 HERMES_HOME과 Foundation의 임시 LocalStore를 사용했으며 TMPDIR을 별도로 바꾸지는 않았다(전후 동일 조건, 소켓 없음).

| 명령 | 실제 종료 코드 | 대상 | 로그·결과 |
|---|---|---|---|
| `HEJO_PYTHON=<시험용 Python> PYTHONPATH=<실행 workspace> HEJO_TEAM_KIT_LIB=<운영 키트 lib> bash scripts/test.sh` | 1 | 수정 전 기준(제품은 ac212cf와 동일) | `task00/v4-clean/full.log`, `full.exit`: 423 통과·4 실패 |
| 같은 격리 환경에서 `bash app/scripts/test.sh` | 1 | 수정 전 기준 | `task00/v4-clean/app.log`, `app.exit`: 서명 앱 BUILD_OK·AT-HF-23 이후 기존 AT-UC-32 단정 실패 |
| `python3 app/Tests/hejo_smooth.py baseline` | 0 | ac212cf에 TASK-01 관측만 추가한 상태(이후 5cfb121로 커밋) | `task01-baseline.log`, `task01-baseline.exit`, `baseline/execution.json`, `baseline/run.log`. 최적화 Swift 빌드·실제 View 실행·기준 기록 성공. 기준 예산 통과라는 뜻은 아님 |
| `python3 app/Tests/hejo_smooth.py cache` | 1 | TASK-02 초기 비교 코드 | `task02-cache.log`, `task02-cache.exit`, `cache/run.log`: AT-SM-01 통과 뒤 장식 객체 identity 비교 오류 |
| `python3 app/Tests/hejo_smooth.py cache --output app/.build/hejo-smooth/cache-values` | **1** | f7398989aec4a87527c60e510f914ddd39f91b39와 동일한 소스 | `task02-cache-values.log`, `task02-cache-values.exit`: runner의 AT-SM-05 예산 단정 실패. 내부 실제 AppKit 실행은 **0**(`cache-values/execution.json`) |
| `sample <시험 프로세스> 2 1 -file <증거 파일>` | 0 | 같은 TASK-02 실행 파일, 스트리밍 재그리기 중 | `task02-stack-sample.txt`, `task02-stack-sample.log`, `task02-stack-sample.exit`. 공식 5회 지연 표본을 모두 확보한 뒤 관측 |
| `hejo-perf-tests --hejo-perf <동결 input> <output> semantic` | 0 | f7398989aec4a87527c60e510f914ddd39f91b39와 동일한 소스 | `semantic-after/run.log`, `semantic-after/result.json`: 기존 동결 58단계 expected와 byte 일치 |
| `<실행 환경 venv Python> scripts/scan_private.py --home <임시 빈 홈>` | 0 | TASK-02 최종 추적 파일 전체 | `task02-scan.log`, `task02-scan.exit`: 지적 없음. 운영 명부·비밀 파일 미사용 |
| `git diff --check` | 0 | TASK-02 최종 변경 | 도구 출력, 별도 로그 없음 |

최적화 옵션은 전후 모두 Swift 5, `-O`, `HEJO_PERF_TESTING`, arm64/macOS 13 대상이다. 실제 ConversationView를 840×760 창에 붙였으며 지연 계측 창은 표시하지 않았다. `probe/build.json`과 `probe/compile.log`는 현재 수정 후 빌드의 영수증·로그다. 기준 실행의 binary SHA와 제품 관측 diff는 `baseline/execution.json`에 있다. `tested-revision.json`으로 최종 커밋의 소스·실행 파일이 시험 빌드와 일치하고 기준 파일이 동결 뒤 그대로임을 확인했다.

### 기준의 기존 실패와 무효 시도

기준 Python 실패 4건은 `test_delivery_parity.py::test_native_labels_outcome_and_repeat_are_idempotent`의 승인 버튼 라벨 불일치 1건과, `test_gateway_progress.py::test_real_gateway_progress`, `test_gate_delivery.py::test_at_hf_22`, `test_slack_move_gate.py::test_at_sm_10_11_12_actual_gateway_scheduler`의 subprocess `yaml` 누락 3건이다. gate 코드를 바꾸거나 실패를 허용 처리하지 않았다.

기준 앱은 `APP_TEST_FAILED assertion("AT-UC-32 four word-only judgment buttons without image")`로 끝났다. 뒤쪽 앱 시험·네트워크 fixture는 그 실행에서 건너뛰어졌다. 이후 수정 후 전체 앱 회귀는 예산 중단으로 미실행이다.

초기 `task00/v4/` 시도는 키트 import 경로를 잘못 지정해 Python 422 통과·5 실패였고, 제가 기준 앱 빌드와 계수기 편집을 겹쳐 `input file was modified during the build`로 중단시켰다. 계수기 diff를 보관하고 원래 네 소스를 복원한 뒤 `v4-clean`에서 다시 실행했다. `v4`는 유효한 기준 결과로 사용하지 않았다. v3의 pytest 부재 기록도 `task00/baseline-full.*`에 보존돼 있다.

## 전후 계측과 원시값

현실 workload는 8개 방 × 100개 스레드 × 4개 글, 길이 200·800·3,000자 고정 반복이다. 합성 목록·코드·링크·체크를 포함한다. workload SHA-256: `a8e8427067a871449d33b96059a3342df8ed310713ecc4ffc11cf8db81946eac`.

수정 전 `baseline/performance.json`과 수정 후 `cache-values/performance.json`에 준비 실행 1회와 실제 5회의 전체 원시 시각·횟수·스크롤 표본을 보존했다. `workload-frames.json`은 두 실행에서 byte 일치한다. 기준 동결 목록은 `baseline-frozen.json`이다. 아래 중앙값·최대는 읽기용 ms 반올림이며 전체 정밀도 원본은 JSON이다.

| 동작 | 전 중앙값 / 최대(ms) | 후 중앙값 / 최대(ms) | AC-05 |
|---|---:|---:|---|
| 스레드 선택 | 638.979 / 664.453 | 559.942 / 609.542 | 미달 |
| 답글 더미 펼치기 | 592.838 / 620.933 | 500.526 / 541.338 | 미달 |
| 답글 더미 접기 | 606.251 / 620.156 | 502.239 / 523.551 | 미달 |
| 새 글 전환 | 601.318 / 628.326 | 489.352 / 549.829 | 미달 |
| 방 재방문 | 629.452 / 642.360 | 550.262 / 568.316 | 미달 |
| 처음 보는 방 | 614.303 / 660.492 | 633.569 / 726.725 | 충족 |
| 편집 프레임 수신 | 594.905 / 621.085 | 525.607 / 553.461 | 미달 |
| 알림 이동 준비 | 876.542 / 901.778 | 790.495 / 809.366 | 미달 |


절대 예산은 중앙값 50ms·최대 100ms다. **처음 보는 방만** 수정 후 중앙값을 수정 전 최대 660.491792ms와 비교하며 이 조건은 충족했다. 다른 7개 동작은 예산 미달이다. 입력 규모·기대값·예산·기존 동결 fixture를 바꾸지 않았다.

### 원시 5회(초, 표시 자릿수만 9자리)

| 동작 | 수정 전 5회(초) | 수정 후 5회(초) |
|---|---|---|
| 스레드 선택 | 0.639132333, 0.636760250, 0.638979458, 0.624043708, 0.664452667 | 0.566199917, 0.559942333, 0.547324333, 0.609541542, 0.550202708 |
| 답글 더미 펼치기 | 0.591663875, 0.620933250, 0.578887583, 0.592837583, 0.603647917 | 0.496533583, 0.499315583, 0.500525750, 0.541338417, 0.515618125 |
| 답글 더미 접기 | 0.620156167, 0.583614792, 0.589248750, 0.606251292, 0.619044250 | 0.489894792, 0.502239417, 0.523550833, 0.508602000, 0.497319250 |
| 새 글 전환 | 0.628326125, 0.589066125, 0.601317583, 0.584583625, 0.615645208 | 0.485667459, 0.549828583, 0.511231625, 0.482090958, 0.489351667 |
| 방 재방문 | 0.616206625, 0.642360208, 0.633968583, 0.615750833, 0.629451583 | 0.568315667, 0.537740250, 0.557850750, 0.509318416, 0.550261833 |
| 처음 보는 방 | 0.612695042, 0.647910833, 0.612196000, 0.614302708, 0.660491792 | 0.617359167, 0.640343042, 0.633568833, 0.726725250, 0.630967417 |
| 편집 프레임 수신 | 0.601004292, 0.583676458, 0.583448750, 0.621084708, 0.594904708 | 0.519879583, 0.525606792, 0.553460917, 0.529965792, 0.492480458 |
| 알림 이동 준비 | 0.862602083, 0.869003208, 0.876541875, 0.901778250, 0.887425333 | 0.792940375, 0.781738167, 0.809366458, 0.790495417, 0.772280625 |


### 횟수·스트리밍 결과와 시험 한계

- AT-SM-01: 같은 상태 다시 그리기, 스레드 펼침·접기, 새 글, 다른 스레드에서 기존 글의 꾸미기·높이 계산 0회 통과. 새로 보인 글은 각각 1회 이하다.
- 계측의 새 글·더미 접기·재방문은 수정 전 각각 본문/높이 100/100회에서 수정 후 0/0회다. 수신은 100/100회에서 바뀐 글 1/1회, 펼침·알림 준비는 새로 보인 글 2/2회다.
- AT-SM-02의 구현한 자동 대조: 편집, 스트리밍 3단계·완료, 삭제, 긴 답글 펼침·접기, 체크, 검색 켜기·끄기·변경, 테마, 글자 크기, 말풍선 색, 창 폭, 명부 색, 같은 id 다른 내용, 방 왕복, 오래된 글 드러내기, 8개 방 순회 후 상한 단정은 통과했다. 새 View에는 표시 상태·시계만 옮기며 본문·높이 기억값은 옮기지 않는다.
- 대조 시험의 TextLayout.Decoration은 NSObject identity가 달라도 같은 장식을 나타낸다. box와 모든 quote의 run·color를 값으로 바꿔 비교하고 나머지 문자열·속성·카드 높이·글 위치는 그대로 비교한다. 최초 실패는 이 시험 비교 방식의 오류였으며 수락 기대값 변경이 아니다.
- **AT-SM-02 잔여 검증:** pending→sent는 실제 postPieces의 본문/속성 단위 대조만 했다(무송신). 실제 전송 전이의 카드 전체 대조는 미실행. 빈 방·1개 글 방은 실제 View 재그리기 smoke만 했고 새 View 전체 대조가 남았다. 이전 글 보기 버튼 이후의 직접 대조도 별도로 남았다(50개 이전 대상 드러내기는 대조함). 자동 PASS 출력이 수락 명세 전체 완료를 뜻하지 않는다.
- AT-SM-03: 네 편집 프레임과 그 사이 주입 시계 재그리기마다 다른 글의 본문·높이 계산 0을 단정했다. 124개 단계의 표시 문자열 순서가 기준과 같고 위치 차이가 모두 1pt 미만이다. 완료 후 최종 본문과 정착 뒤 바닥 거리 1pt 미만도 확인했다. 근거는 `baseline/stream.json`, `cache-values/stream.json` 및 비교를 통과한 runner다.
- mutation check는 미실행이다. 예산 중단 상태에서 중요한 누락 키 검출을 고의 변형으로 확인하지 못했으며 후속 검증 항목으로 남긴다.

### 전환과 스크롤 기준 관측

`baseline/transitions.json`에 준비 실행과 실제 전환 5회를 모두 남겼다. 5회 단계 수는 11·15·16·18·16이고 최대 간격은 약 106.932·64.560·27.523·28.265·52.420ms다. 실제 종료는 약 308.824·308.118·308.143·313.646·324.480ms다. 간격 50ms 조건에 미달한 표본을 버리거나 대체하지 않았다. 목적지 스크롤 애니메이션은 전환 중에도 시작됐다. 이는 수정 전 기준 관측이며 TASK-03 미착수로 수정 후 AT-SM-04·06 결과는 없다.

스크롤 기준은 5회 합계 2,625걸음, 중앙값 0.020292ms·최대 10.247167ms다(`baseline/performance.json`, `baseline/summary.json`). 창을 표시하지 않은 실제 View의 60pt 이동·layout·displayIfNeeded 관측이며 실제 설치 앱의 체감 근거가 아니다. GAP-SM-01에 따라 합격/불합격 판정과 전용 수정은 하지 않았다.

## 남은 병목과 재개 판단

본문·높이 재사용만으로 목표 지연에 들지 못했다. 공식 5회 확보 뒤 `sample`의 2초 호출 스택에서 주 스레드 refresh 아래 표본 1,145개 중 사이드바 경로가 629개였고, 카드 쪽 calendarActions 경로도 215개였다. 중첩 호출의 통계 표본으로 실제 구간별 소요 시간과 같지 않으며 서로 합산하지 않는다.

직접 읽은 책임 자리:

- `ConversationModel.swift:244` sidebar: 방별 메시지·안 읽음·질문·알림을 매 렌더 범위에서 다시 산출한다. 스택의 notices 경로가 큰 비중을 차지했다.
- `ConversationController.swift:128` calendarActions: 본문 재사용 뒤에도 글마다 달력 관련 내용 검사를 실행한다.

두 경로는 이번에 수정하지 않았다. **권고:** 계획 담당이 이 원시 계측과 스택을 읽고 이 경로들의 파생값 재사용·갱신 범위를 기존 책임 안에서 확정한다. 예산을 유지하고 본문·높이만으로 해결한다는 가정을 재검토해야 한다. TASK-03은 별도 전환 개선이며 현재 동기 지연 예산 미달을 먼저 판단한 뒤 재개 지시가 필요하다.

## 증거 수준·미실행·복구

도달한 제품 증거는 1(최적화 Swift 시험 빌드), 2(임시 저장소·가짜 프레임·메모리 자격 통합), 3(실제 AppKit View와 run loop 실행)이다. 최종 서명 제품 빌드·실제 보이는 창 반복 관측·설치 앱 체감 확인은 수행하지 않았다. 자체 시험이며 독립 검토가 아니다.

TASK-03, TASK-05 전체 회귀·입력/스크롤/세 번 누르기 전체 재실행, 격리 실제 창 관측 준비, AT-SM-09, 공개 통합·설치·개발 main 반영·푸시는 미실행이다. 서버·문·Hermes 본체·두 venv·비밀 파일·운영 설정은 바꾸지 않았다. 수락 기준·예산·fixture도 그대로다. 이번 제품 변경은 본문·높이 동작 보존 최적화이며 복구는 TASK-02 커밋의 diff 역적용이다.

검토자는 키의 누락 여부와 ChatAppearance.revision 변경 경로, 불변 본문의 속성 보존, 높이 상한, 새 View 대조의 표시 상태 복사와 남은 시험 범위를 특히 확인해야 한다. 이 보고는 예산 미달에 따른 중단 인계다.

## v5 보완 구현·자체 시험 결과

현재 결과는 부분 구현·검증이다. AC-05 절대 예산 7개 중 6개, AC-06 실제 5회 중 3회가 미달이고 native 실패 집합도 달라 수락 완료 조건은 남아 있다.

최종 판정은 검토 담당에게 넘긴다. 구현과 시험은 전용 작업 공간에서만 수행했다. 공용 main, 설치 앱, 서버·문·Hermes 본체, 운영 설정과 비밀 파일을 변경하지 않았고 실제 서비스 메시지와 git push를 실행하지 않았다. 계획 담당 체크아웃에는 이 보고와 tasks 상태 칸만 갱신한다.

### 변경과 커밋

개발 기준은 `ac212cfe911168e576e2e24df5d2b6f7f30ff9b4`, 브랜치는 `hejo-smooth-20261124`다. 전용 작업 공간은 계획 담당 체크아웃 기준 `../.worktrees/hejo-smooth-20261124`다. 앞서 수락된 `5cfb121796bf0ecb53a446fd4f0b11ab0b14a8ff`와 `f7398989aec4a87527c60e510f914ddd39f91b39`를 그대로 유지했고 TASK-01 기준 계측을 다시 동결하지 않았다.

| 커밋 | 작업 | 내용 |
|---|---|---|
| `30eb64de49ffc9236583cc98b61455853b2af5c8` | TASK-02B | 판정·달력 버튼, 본문의 생각 중 판정, 시각 표시 재사용과 계측 |
| `0d46051d12e95d8944e3c7239e26872a26244d6e` | TASK-02C | 빈 방·한 글·보내는 중 전이·이전 글 버튼 전체 대조와 입력 누락 변형 |
| `90971219e06c9fff7c21ebcc4356aeed99d7258c` | TASK-03 | 여는 알림의 즉시 배치와 전환 경계 시험 |
| `730f205edd51d95194b848288e3d6690c31f3146` | TASK-05 | 독립 회귀 실행기와 실제 창 관측 준비 |
| `c40e55ddf9e3e0e4e44d6029f14b42a69f10f918` | TASK-05 시험 보강 | 실제 알림 24시간 경계, 생각 중 변화와 시각 표시 독립 대조 |
| `1202ef9bec3efb04dc7d82a6b31819f8b69d374d` | TASK-05 증거 경로 | 사용자 지정 probe의 실제 build.json 경로 기록. 앱·Swift 시험 소스 변화 없음 |

이번 보완에서 변경한 제품 파일은 `app/Sources/ConversationModel.swift`, `ConversationController.swift`, `ConversationView.swift`, `WorkspaceTools.swift`, `PetController.swift`다. `HejoSmoothProbe.swift`와 `ThreeTapDiagnostics.swift`의 관측·변형 장치는 `HEJO_PERF_TESTING` 안에만 존재한다. 시험은 `app/Tests/HejoSmoothTests.swift`, `hejo_smooth.py`, `hejo_smooth_regression.py`에 추가했다. 기존 의미 fixture, workload 생성, 수락 명세, 기존 회귀 기대값은 변경하지 않았다. NativeThreadList의 스크롤 정책과 genie 모양·길이도 변경하지 않았다.

### 재사용 값의 소유·입력·제거

| 값 | 소유 자리 | 입력 전부 | 제거·상한 |
|---|---|---|---|
| 스레드 판정 | `ConversationModel.assessment` | 정렬된 글 배열의 id·key·role·text·files·buttons·replyState·streaming·finalized·seq·latestSeq·timestamp·clientMessageID·checklist·branchFrom·employee·answerTo·pending, 확인된 글 id 집합. 알고리즘은 role·text·replyState·buttons·checklist·id·answerTo를 읽으며, request/pending에 글 전체를 반환하므로 나머지 필드도 비교한다 | 입력 차이 때 교체. 삭제·방 제거·replica 초기화 때 없는 스레드 제거. FIFO 2048. 렌더 범위의 중복 사본 제거 |
| 달력 버튼 | `ConversationController.calendarActions` | 본문·timestamp·role·pending·현재 Calendar. 일정 배열 전체 값과 순서는 calendarEvents의 didSet에서 비교하여 무효화한다. CalendarEntry의 반환값까지 포함하는 전체 필드를 비교한다 | 글 입력 차이 때 교체, 일정 변경 때 전체 제거, 글/임시 전송 삭제 때 제거. FIFO 2048 |
| 생각 중 본문 판정 | `ConversationModel.thinking` | 글 id를 찾는 키, 원문 text 전체. 기존 `ThreadTools.thinking` 계산을 그대로 호출한다 | 본문 차이 때 교체, 글 삭제·replica 초기화 때 제거. FIFO 4096 |
| 시각 표시 | `ConversationView.displayTime` | 글 id를 찾는 키, timestamp·Locale.current·TimeZone.current·Calendar.current | 입력 차이 때 교체, 갱신 때 삭제된 글 제거. FIFO 2048. 원래 fractional/whole 파서와 localizedString을 그대로 호출 |

알림 목록 자체는 시각 의존이므로 기존 렌더 범위 안에서만 기억한다. 순수 파생값 외의 계산 미루기·갱신 횟수 줄이기·보이는 부분만 계산·표시 생략·구조 변경은 하지 않았다.

### 기능 대조와 변형 시험

최종 `final-values/run.log`의 실제 AppKit probe는 종료 0으로 AT-SM-01, AT-SM-02 정상 대조와 AT-SM-03을 통과했다. 빈 방·한 글 방의 카드 전체, 임시 pending 자료에서 실제 controller 확인 프레임으로 전이한 카드 전체(송신 API 호출 없음), 활성화된 이전 글 보기 버튼 뒤 전체를 새 View와 대조했다. 스트리밍은 기준의 124단계 문자열과 주입 시계 위치가 같고 오차는 모두 1pt 미만이다. 최종 runner 종료 1은 이 대조가 아니라 AC-05 예산 미달이다.

`final-derived-v2/derived.json`은 27개 변화의 새 모델 대조를 통과했다. 판정의 request/pending 전체 글 값·buttons·working·settled·approved·color, 사이드바 행/배지, 종, 알림 식별자/순서/개수, 글별 달력 버튼, 서랍 수를 비교했다. 실제 새 알림은 `alert-boundaries.json`에서 발생 전 false, 24시간 직전 true, 정각 false, 직후 false다. 생각 중 본문도 변화시키고 직접 판정과 비교했으며, 시각 표시는 새 parser/formatter 결과와 비교했다. 같은 상태의 판정·달력 계산 0회, 한 글 추가 시 해당 스레드/글만 1회를 단정했다. 추가 값인 생각 중 판정·시각 표시도 최종 5회의 안 바뀐 글 전환에서 계산 0임을 원시 계수기로 확인했다. 삭제 후 스레드/달력/생각 중 항목 제거와 상한도 확인했다.

입력 누락 변형은 정상 빌드에서는 동작하지 않는다. 시험에서만 비교 입력 하나를 생략하고, 실제 재사용 결과와 빈 기억값의 화면 또는 직접 순수 계산을 대조했다. 변형 상태는 종료 때 되돌린다. 실행 결과의 exit 0은 기록 성공이며 모든 변형 검출 성공을 뜻하지 않는다.

최종 `final-mutations-v2/mutations.json`: 37개 중 32개 검출. 미검출은 `assessment.key`, `body.original`, `body.id`, `body.nameColor`, `body.linkColor`다.

- assessment.key: 글의 스레드가 바뀌면 별도의 삭제/유효 키 제거 경로가 옛 항목을 없앤다. 이 비교 입력만 빼도 실제 결과가 틀려지지 않았다.
- body.original: 본문을 바꾼 표본은 shown도 바뀌어 다른 비교 입력이 재생성을 보장했다.
- body.id: 사전 자체가 글 id를 키로 사용한다. 속성 문자열은 같은 표본이었다.
- body.nameColor·body.linkColor: 변형 표본에서 독립된 색 변화가 발생하지 않았다. 실제 명부 색 변화의 정상 대조는 AT-SM-02에 있지만 이 두 변형의 별도 색 변화 분리는 미실행이다.

따라서 “각 항목 누락 시 모두 대조 실패”라는 V-SM-04의 엄격한 절차를 완료했다고 하지 않는다. 중복 보호가 있는 입력의 판정 방법과 색 변형 보강은 검토에 남긴다. 추가한 지역/시간대/Calendar 입력의 시스템 설정 변경 변형도 미실행이며 실제 시스템 설정을 바꾸지 않았다. 초기 변형의 냉간 기준에 있던 사전 예열 문제는 빈 본문 사전에서 직접 계산하도록 보강했다. 앞선 `mutations/`, `mutations-v2/`, `mutations-cold-reference/`도 보존했다.

### 전후 원시 계측과 예산

모든 경로는 전용 작업 공간 기준이다. TASK-01 원본 `app/.build/hejo-smooth/baseline/`과 `baseline-frozen.json`은 그대로 보존했다. 원시 동작 시간·글별 계산 횟수·구간별 시간·모든 스크롤 걸음은 각 결과 폴더의 `performance.json`에 있다. 5회 표본을 골라 바꾸거나 예산을 완화하지 않았다.

최종 원시 파일은 `app/.build/hejo-smooth/final-values/performance.json`, 집계는 `summary.json`, 스트리밍 단계별 관측은 `stream.json`이다. 단위는 초다.

| 동작 | 기준 중앙값 / 최대 | 최종 중앙값 / 최대 | 판정 |
|---|---:|---:|---|
| 스레드 선택 | 0.638979458 / 0.664452667 | 0.062574458 / 0.069696000 | 미달 |
| 더미 펼치기 | 0.592837583 / 0.620933250 | 0.052430667 / 0.054843000 | 미달 |
| 더미 접기 | 0.606251292 / 0.620156167 | 0.048025250 / 0.049000667 | 통과 |
| 새 글 | 0.601317583 / 0.628326125 | 0.050159792 / 0.051004125 | 미달 |
| 방 재방문 | 0.629451583 / 0.642360208 | 0.079044083 / 0.080945292 | 미달 |
| 처음 보는 방 | 0.614302708 / 0.660491792 | 0.358606917 / 0.380458833 | 통과 |
| 스트리밍 수신 | 0.594904708 / 0.621084708 | 0.058950958 / 0.065132042 | 미달 |
| 알림 준비 | 0.876541875 / 0.901778250 | 0.356028708 / 0.358019833 | 미달 |

절대 예산 7개 중 더미 접기 1개만 충족했다. 새 글은 중앙값 0.05015979171730578초로, 반올림하여 통과 처리하지 않았다. 처음 보는 방은 중앙값이 기준 5회의 최대값 0.6604917915537953초 이하이므로 악화 금지를 충족했다.

원시 5회(준비 실행 제외, 측정 순서):

| 동작 | 기준 5회 | 최종 5회 |
|---|---|---|
| 스레드 선택 | 0.6391323334537446, 0.6367602499667555, 0.6389794582501054, 0.6240437084343284, 0.6644526666495949 | 0.06101654167287052, 0.06276262504979968, 0.06257445830851793, 0.06203520833514631, 0.06969600007869303 |
| 더미 펼치기 | 0.591663874918595, 0.6209332500584424, 0.5788875832222402, 0.5928375832736492, 0.603647916810587 | 0.05176054174080491, 0.052914041792973876, 0.05243066651746631, 0.05135316657833755, 0.05484300013631582 |
| 더미 접기 | 0.6201561666093767, 0.5836147917434573, 0.5892487501259893, 0.6062512916978449, 0.6190442501101643 | 0.04798670834861696, 0.0488319166470319, 0.0480252499692142, 0.04700304172001779, 0.04900066670961678 |
| 새 글 | 0.6283261249773204, 0.5890661249868572, 0.6013175833504647, 0.5845836249645799, 0.6156452083960176 | 0.049815291771665215, 0.04949200013652444, 0.05018699984066188, 0.05015979171730578, 0.051004125038161874 |
| 방 재방문 | 0.6162066250108182, 0.6423602083232254, 0.6339685833081603, 0.6157508331816643, 0.6294515831395984 | 0.08094529155641794, 0.07904408336617053, 0.07809783332049847, 0.07800716650672257, 0.08039575000293553 |
| 처음 보는 방 | 0.612695041578263, 0.6479108333587646, 0.6121960000600666, 0.6143027083016932, 0.6604917915537953 | 0.36740545835345984, 0.3578455832321197, 0.35860691661946476, 0.35686145815998316, 0.38045883318409324 |
| 스트리밍 수신 | 0.6010042917914689, 0.5836764583364129, 0.5834487499669194, 0.6210847082547843, 0.5949047084432095 | 0.05588425020687282, 0.05858295829966664, 0.059868958313018084, 0.05895095830783248, 0.06513204169459641 |
| 알림 준비 | 0.862602083478123, 0.8690032083541155, 0.876541875069961, 0.9017782500013709, 0.8874253332614899 | 0.35602870816364884, 0.34825112484395504, 0.35277633322402835, 0.3563897081185132, 0.3580198334529996 |

AT-SM-07: 최종 2625걸음 중앙값 3.258325159549713e-05초, 최대 0.024862416787073016초로 0.0167/0.050초 예산을 충족한다. 기준은 중앙값 0.000020291656초·최대 0.010247166734초다. 모든 걸음 값은 양쪽 performance.json에 있다. 창을 표시하지 않은 관측이라 실제 픽셀 그리기 체감의 증거는 아니다. 스크롤 전용 수정은 하지 않았다.


본문·높이 다음의 첫 두 파생값만 적용한 `derived-values/`에서는 중앙값이 약 0.27~0.60초였다. 구간 계측으로 사이드바 약 0.20초, 카드 약 0.06초를 확인했고, `task02b-premeasure-stack.txt`에서 본문 생각 중 판정과 시각 표시 반복을 확인하여 같은 원칙으로 재사용했다. 이후 `pure-values/`의 알림 준비 구간은 사이드바 0.2026초·island 0.0970초가 남았다. 서로 중첩된 구간은 합산하지 않는다. `MemberState.items`가 확인·읽음 상태 조회 때 merge를 반복하는 코드는 확인했지만, 현재 잔여 시간의 함수별 원인 확정은 미실행이다. 상태 병합은 글 내용 파생값과 다른 책임이므로 이번 범위에서 바꾸지 않았다. 추가 범위와 병목 확정은 검토 판단을 요청한다.

### 알림 전환

`app/.build/hejo-smooth/transition-values/transitions.json`의 준비 1회와 실제 5회를 모두 보존했다. 5회 모두 준비 재그리기 1회, 스냅샷 위치 오차 0, 전환 중 전체 재그리기 0회·스크롤 시작 0회였다. 기준 최종 위치와의 차이는 0·0·0·-0.5·0pt로 모두 1pt 미만이다. 다른 방·홈·맨 아래·50개 이전을 포함한다.

| 실제 표본 | 단계 수 | 최대 간격(초) | 실제 종료(초) | AC-06 |
|---|---:|---:|---:|---|
| 1 | 12 | 0.08558408333919942 | 0.3273738333955407 | 불합격 |
| 2 | 14 | 0.04065191652625799 | 0.31297708326019347 | 통과 |
| 3 | 14 | 0.09746075002476573 | 0.3501499998383224 | 불합격 |
| 4 | 14 | 0.06119229178875685 | 0.3223337917588651 | 불합격 |
| 5 | 17 | 0.040813333354890347 | 0.30565220839343965 | 통과 |

시작→첫 단계도 원시 gaps에 포함했다. 표본 3은 종료 0.350초 기준도 초과했다. 불합격을 재실행으로 대체하지 않았다. `transition-boundaries.json`은 실제 전환 도중 수신 갱신 1회·내용 반영, 이미 열린 창의 스크롤 시작 1회, 애니메이션 줄이기 즉시 위치 오차 0을 확인했다. 따라서 AT-SM-04는 충족하고 AT-SM-06은 미달이다. 전환 모양·기간·렌더 구조를 바꾸는 후속 수정은 하지 않았다.

`task03-tested-revision.json`은 TASK-03 커밋과 시험한 전체 Swift 입력의 일치를 기록한다. 이후 최종 커밋까지 제품 소스가 같음을 최종 검증에서 확인했으므로, 이 실패 표본은 최종 제품의 증거로 유지하며 다시 뽑지 않았다.

### 전체·독립 회귀

Python 전체는 기준/최종 모두 423개 통과·4개 실패, 종료 1이다. `regression-comparison.json`에서 실패 id 집합 동일을 확인했다. 실패는 기존의 delivery_parity 라벨 1건과 gateway_progress·test_gate_delivery AT-HF-22·test_slack_move_gate AT-SM-10/11/12 3건이다. 기대값과 제품을 고치지 않았다.

기준의 독립 native 26묶음(`regression-baseline-with-resources-at-root/`)과 추가 capture 진입점 8묶음(`capture-baseline/`)은 모두 통과했다. 최종은 native 26 중 23개, 추가 8개 모두 통과했다. 격리 loopback/후크 13묶음은 양쪽 모두 통과했다(`network-baseline/`, `network-final-v2/`). 총 47개 독립 묶음 기준 통과 47, 최종 통과 44·실패 3이다. 의미 동결 58단계의 observed.json은 양쪽 모두 원본과 바이트 단위로 같다.

최종 native 첫 실행의 실패:

- `hejo-perf-regression`: `HP-02 assessments share grouped timelines`. 이전 시험은 assessment 파생 사전이 존재하고 값이 1이어야 통과한다. 한 번 그린 뒤 계산 0회를 요구하는 v3에서는 관측 사전이 없으므로 실패한다. 기대값을 바꾸거나 가짜 계수를 보내지 않았다. v3와 기존 HP-02의 충돌 처분을 요청한다.
- `ui-clean-polish`: `AT-UC-32 four word-only judgment buttons without image`. TASK-00 기준 전체 앱 시험에서도 같은 assertion이 실패했다. 이번 독립 기준에서는 통과, 최종에서는 실패했으므로 독립 묶음의 실패 집합이 같다고 하지 않는다.
- `task41`: `AT92 faded surface stowed`. 앞선 최종 후보의 같은 제품 소스에서는 통과했고 이번에는 실패했다. 다른 시험/빌드가 끝난 뒤 동일 기준·최종 실행 파일로 한 번씩 관측한 `task41-idle-results.json`은 둘 다 종료 0이다. 원인은 확정하지 못했고 첫 실패는 삭제하지 않았다.

따라서 실패 집합 비교는 Python·loopback은 같음, native는 다름이며 비교 명령은 종료 1이다. 최종 `bash app/scripts/test.sh`는 BUILD_OK·AT-HF-23 뒤 HP-02에서 종료 1이다. 이로써 기존 AT-UC-32 뒤의 시험뿐 아니라 HP-02 뒤도 전체 실행에서 건너뛰어졌다. 빌드 자체의 실패로 분류하지 않는다.

추가 8개 진입점은 progress·connections·rooms·home·bubble·notification·workspace·thread-tools다. 중복 capture 진입점은 다시 실행하지 않았다. 독립 진입점이 없거나 선행 assertion에 막혀 따로 완주하지 못한 것은 unit 안의 저장소/단일 인스턴스/endpoint·auth·기초 펫 배치 블록, conversationUnitTests, transitionPreparationTests, islandTests, typingTests, postGroupTests, task17Tests, picturesSidebarTests, appIconTests, loginTests, composerTests다. task17Capture는 별도 함수라 task17Tests 완주 증거로 삼지 않았다. 최종 hejo-perf-regression의 HP-02 뒤와 conversationUpdateTests, polish의 AT-UC-32 뒤도 완주하지 못했다. 임의 skip/새 진입점/기대값 변경으로 우회하지 않았다.

### 명령·종료 코드·로그

아래 경로는 전용 작업 공간 기준이다. 기록용 wrapper가 0으로 끝나도 하위 시험의 실제 종료 코드를 따로 보고한다.

| 명령(전용 작업 공간 cwd) | 실제 종료 | 로그/결과(모두 app/.build/hejo-smooth/ 아래) |
|---|---:|---|
| `python3 app/Tests/hejo_smooth.py derived --output .../derived-extras` | 0 | task02b-extras.log·exit, derived-extras/ |
| `python3 app/Tests/hejo_smooth.py cache --no-build --output .../pure-values` | 1 | task02b-pure-measure.log·exit, pure-values/ (AppKit probe 0, 지연 예산 미달) |
| `python3 app/Tests/hejo_smooth.py cards --output .../cards-complete-v2` | 0 | task02c-cards-v2.log·exit, cards-complete-v2/ |
| `python3 app/Tests/hejo_smooth.py transitions --output .../transition-values` | 1 | task03-transitions.log·exit, transition-values/ (원시 5회 보존) |
| `python3 app/Tests/hejo_smooth_regression.py final --output app/.build/hejo-smooth/regression-final-v2` | 0(기록 완료) | task05-final-groups-v2.log·exit, regression-final-v2/results.json (하위 3개 종료 1) |
| `python3 app/.build/hejo-smooth/network_groups.py final-v2 app/.build/hejo-smooth/regression-final-v2/build` | 0 | task05-final-network-v2.log·exit, network-final-v2/results.json (13개 모두 0) |
| `python3 app/.build/hejo-smooth/capture_groups.py` | 0 | task05-capture-groups.log·exit, capture-baseline/·capture-final/ (16개 모두 0) |
| `bash scripts/test.sh` (v4 HEJO_PYTHON/PYTHONPATH, 임시 홈·짧은 basetemp) | 1 | task05-final/full.log·exit (423 통과·4 실패) |
| `bash app/scripts/test.sh` (별도 실행) | 1 | task05-final/app.log·exit (빌드 성공 표식, HP-02 실패) |
| 실행 환경 Python으로 `scripts/scan_private.py` (임시 홈) | 0 | task05-final/private.log·exit |
| `python3 app/Tests/hejo_smooth.py derived --no-build --probe .../regression-final-v2/build --output .../final-derived-v2` | 0 | task05-derived-v2.log·exit, final-derived-v2/ |
| 같은 binary의 `mutations ... --output .../final-mutations-v2` | 0(기록 완료) | task05-mutations-v2.log·exit, final-mutations-v2/ (32/37 검출) |
| 같은 binary의 `cache ... --output .../final-values` | 1 | task05-final-measure.log·exit, final-values/ (AppKit probe 0, 비교 후 AC-05 불합격) |
| Python 원시 실패 집합 비교 | 1 | regression-comparison.json·exit (native 실패 집합 다름) |
| Python SHA256·원본·현재 소스·실행 파일·제품 동일성·작업 트리 확인 | 0 | final-integrity.log·exit, final-tested-revision.json |

`.../`는 이 표에서 `app/.build/hejo-smooth/`를 줄인 표기다. 모드·커밋·실행 파일 SHA256은 각 execution.json에, native 묶음의 명령은 results.json에 있다. 전체 CLI는 이 표의 줄임 경로를 치환하면 된다. 전체 회귀·최종 시간 계측은 c40e55dd…에서 실행했다. 이후 최종 커밋 1202ef9b…는 Python 실행기의 영수증 경로 한 행만 고쳤으며 앱과 모든 Swift 시험 소스는 같다. 이 최종 커밋에서 같은 실행 파일의 derived 모드를 다시 실행해 종료 0과 올바른 경로를 확인했다(`task05-receipt-check.log·exit`, `final-receipt-check/`). 모든 Swift 입력과 실행 파일의 일치는 build.json과 최종 무결성 기록으로 확인했다. Hermes 시험/실행 환경은 읽기만 했으며 실제 설치 경로는 이 보고에 쓰지 않았다. 로컬 환경 설정은 기존 추적 제외 `task00/v4-clean/environment.local.json`을 사용했다.

실패한 준비 실행도 보존했다. `task02b-derived-v1`은 작은 fixture의 seq 오류, `task02c-derived`는 변형 생성 시험 구문 오류(`task02c-compile-v1.log`), `task02c-cards`는 삭제 기록 누락으로 확인 프레임의 저장 커서가 어긋난 시험 오류다. 모두 제품/수락 기대값 변경 없이 시험을 고쳤다. 독립 기준 실행의 첫 두 시도는 리소스 상대 경로 준비 오류이며, 같은 원본 실행 파일과 실제 작업 폴더를 사용한 `regression-baseline-with-resources-at-root/`를 유효 기준으로 삼았다. 이 준비 오류를 제품의 기준 실패로 집계하지 않았다.

### 증거 메타데이터 보정

`--probe`를 쓴 앞선 execution.json의 build_receipt 필드는 기본 probe/build.json 경로로 고정돼 있었다. 원시 실행 기록은 바꾸지 않았다. 해당 실행 폴더 안에 복사된 build.json과 tested-binary가 실제 사용한 증거이며, SHA256은 `regression-final-v2/build/`와 일치한다. 1202ef9b…에서 이 필드를 실제 선택한 경로로 고쳤고 `final-receipt-check/execution.json`의 올바른 상대 경로를 확인했다. 이는 표본/기대값 변경이 아니다.

최종 소스 개인값 검사와 계획 문서 두 개의 임시 인덱스 검사는 `task05-private-last.log·exit`, `task05-report-scan.json`에 남긴다. 실제 main 인덱스를 수정하지 않고 임시 인덱스에서 이 보고와 tasks만 추가해 검사한다.

### 증거 수준·관측 준비·미완료

필요 수준 1·2·3 중, 빌드(1), 가짜 데이터와 격리 통합(2), 실제 AppKit 텍스트/레이아웃·run loop·전환 타이머 실행(3)의 증거를 남겼다. 이 수준은 수락 조건 전체 통과를 뜻하지 않는다. 실제 사용자 창에서의 유연함을 관측한 수준 4는 달성하지 않았다.

AT-SM-09는 `hejo_smooth.py manual`로 임시 홈·동결 workload의 제품 View를 별도 창에 띄우고 여섯 동작을 각각 10회 누를 수 있게 준비했다. 실제 GateClient 소켓을 시작하지 않으며 보내기는 비활성이다. 알림 버튼은 접기→열기를, 수신 버튼은 로컬 프레임 주입을 수행한다. 버튼 횟수/시각은 `manual-actions.json`에 기록하지만 체감 합격을 자동 선언하지 않는다. 창을 닫거나 300초 뒤 종료한다.

관측 실행 방법(새 결과 폴더 사용):

```sh
python3 app/Tests/hejo_smooth.py manual --no-build   --probe app/.build/hejo-smooth/regression-final-v2/build   --output app/.build/hejo-smooth/manual-observation
```


이 관측 실행과 사람의 멈춤·튐·늦은 따라오기 판단은 미실행이다. 사용자 확인 요청은 인계대로 기획설계가 담당한다. 설치 앱 교체·개발 main 반영·공개 이력 통합·현재 명세 갱신·푸시는 미실행이다. 현재 명세 `docs/spec/current/hejo-performance.md`의 렌더 범위 폐기 계약 갱신은 TASK-06에 남긴다.

남은 판단: AC-05 예산, AC-06 프레임 실패, 기존 HP-02와 v3 계산 0회 계약 충돌, 입력 누락 변형 잔여 항목, 실제 창 관측, 처음 보는 방의 후속 범위(GAP-SM-02). TASK-04는 닫힌 상태를 유지한다.

## 보완 인계 v6 실행 결과 (최신, 2026-11-24)

기준 `ac212cfe911168e576e2e24df5d2b6f7f30ff9b4`, 최종 `fc756976ff5e52ed7498fcfd8231a37f05fdc59f`. 전용 worktree `../.worktrees/hejo-smooth-20261124`, 브랜치 `hejo-smooth-20261124`, 원격 이름 `github`. 아래 로그 경로는 모두 이 worktree 루트 기준이다. **부분 완료, 검토 인계이며 푸시 승인 요청이 아니다.**

계약은 spec v4·design v3·수락 시험 v4·tasks v5·handoff v6이다. 예산·동결 입력은 유지했다. TASK-02D·07·09의 구현/지정 시험은 수행했고 TASK-08은 계측과 한계 보고까지다. AC-05는 절대 예산 7개 중 6개 충족, 방 재방문 미달이다. AC-06은 3/5 충족이다. AC-08 독립 실패 집합은 기준과 다르며 AT-UC-32 불안정 실패가 남는다. AT-SM-09 실제 사람의 체감 관측은 미실행이다.

### 변경 파일·커밋

- `app/Sources/ConversationController.swift`
- `app/Sources/ConversationModel.swift`
- `app/Sources/ConversationView.swift`
- `app/Sources/HejoSmoothProbe.swift`
- `app/Sources/LocalStore.swift`
- `app/Sources/MemberState.swift`
- `app/Sources/PetController.swift`
- `app/Tests/HejoPerfRegressionTests.swift`
- `app/Tests/HejoSmoothTests.swift`
- `app/Tests/hejo_smooth.py`

역할: LocalStore는 상태 입력 변경 번호만 발급하고 저장 형식은 유지한다. MemberState는 병합 결과를 소유한다. ConversationModel은 렌더 범위 판정을 복원하고 날짜 파싱 결과를 재사용한다. ConversationView의 카드 날짜는 같은 모델 파서를 조회한다. Controller/View/Model의 변형 분기는 제거했다. PetController/Probe의 전환 추가 코드는 HEJO_PERF_TESTING 관측뿐이다. HP-02 외 기존 기대값·fixture는 변경하지 않았다.

기준 뒤 전체 커밋(앞 8개는 이전 실행, 새 7개는 v6):

- `5cfb121796bf0ecb53a446fd4f0b11ab0b14a8ff test: freeze realistic conversation rendering and transition observations`
- `f7398989aec4a87527c60e510f914ddd39f91b39 perf: reuse immutable post bodies and bound height measurements`
- `30eb64de49ffc9236583cc98b61455853b2af5c8 Reuse unchanged thread assessments and message derived values`
- `0d46051d12e95d8944e3c7239e26872a26244d6e Strengthen cold view comparisons and input omission probes`
- `90971219e06c9fff7c21ebcc4356aeed99d7258c Place notification destinations before opening snapshots`
- `730f205edd51d95194b848288e3d6690c31f3146 Prepare isolated smoothness observation and independent regressions`
- `c40e55ddf9e3e0e4e44d6029f14b42a69f10f918 Assert actual alert boundaries and derived presentation values`
- `1202ef9bec3efb04dc7d82a6b31819f8b69d374d Record the build receipt actually used by each probe`
- `7a89631d9c0b2e1b0f4c13374ad438ccfdcb3c0d Reuse merged member state and render scoped assessments`
- `9a4b596707003b90f89f9262a5a7362bbc9e216c Align HP-02 assessment count with at most once contract`
- `db8238262c5b08390bf1e37e9510adf4931cfff5 Remove input omission branches after independent color mutation checks`
- `b76f42d59a54fbbbbc83e9a28e8e728ada30c199 Check state lifecycle against fresh replicas and preserve equal merge inputs`
- `629f4e016ffb7f4b9c1f534f8c4dc49e27c1d3bd Observe transition step work and run loop gaps in test builds`
- `95ba0f5224bb7e4bb18f5aecc9eb85ac8e849dda Use the current Swift common run loop mode spelling`
- `fc756976ff5e52ed7498fcfd8231a37f05fdc59f Reuse pure parsed timestamps across conversation queries and cards`

### 새 재사용 값과 입력을 바꾸는 모든 경로

| 값·소유 자리 | 입력·상한 | 무효화·교체·종료 |
|---|---|---|
| 렌더 범위 스레드 판정 / ConversationModel.assessment | 스레드 키, timeline 전체 값, 확인 집합. 기존 지속 값 2,048개 위의 렌더 범위 기억 | 기존 invalidateRenderValues(글·명부·선택/회원 상태 변화), 범위 종료. 같은 상태의 한 범위에서는 입력 수집·비교 1회 이하 |
| 병합 결과 / MemberState.items | 현재 계정의 document.items + pending. 파생 사본 1개 | LocalStore.settings observer가 현재 계정·두 사전 변경을 검출하면 토큰 무효화, 다음 조회에서 교체. rev만 바뀌면 유지. 객체 종료 때 소멸 |
| 날짜 파싱 / ConversationModel.date | 날짜 문자열, FIFO 4,096개 | 다른 문자열은 별도 계산, 용량 초과 시 가장 오래된 항목 제거, 모델 종료 시 제거. 날짜가 시간 경과로 달라지지 않아 시각은 입력이 아님. 삭제 글의 날짜 문자열도 상한 안에서 보관 |

상태 쓰기 경로 전수 확인: MemberState.persist(accept 수신·sync/flush 전송 확인·reconcile·makeLayoutStandard 수신), set(로컬 전송 대기 변경), join(계정 참여·이관), 일반 LocalStore.update(계정/상태 직접 갱신), LocalStore.select(연결 대상 변경으로 stateAccount 초기화), init(디스크 재읽기, 새 MemberState는 비어 있는 기억). settings는 외부 쓰기가 차단돼 있어 모두 observer 또는 초기화로 수렴한다. 다른 계정 항목은 현재 값에 영향을 주지 않고 계정 선택이 바뀔 때 토큰이 바뀐다. 상태값·read·confirmed, sidebar 순서/배지·알림·판정·drawer를 빈 상태의 모델/디스크 재읽기/직접 merge와 비교했다. `v6/derived-dates/member-state.json`은 초기 및 8개 변화, 같은 입력 반복 조회의 병합 0회를 기록한다.

### 구간 계측과 범위 판단

회원 상태/렌더 기억 적용 직후 `v6/values/`에서는 5/7 통과였다. 알림 준비 중앙값 0.051878초(사이드바 0.010557초, 섬 0.002840초), 방 재방문 0.066717초(그리기 0.033176초)였다. 반복 날짜 파싱은 입력 문자열만으로 결과가 같은 계산이므로 승인된 동일 원칙으로 소유 모델에 재사용을 추가했다. 최종 알림 준비는 0.046403083초로 통과했다. 방 재방문은 0.064590750초(그리기 중앙값 0.029555초)로 미달이다. 그리기 밖 약 0.035초가 남았다. 추가 실제 cache 실행에 sample(100초·1ms)을 붙인 `v6/profile-room.py`와 sample 명령은 각각 0, native도 0이었다. 원시 자료는 `v6/profile-room/{stack.txt,performance.json,execution.json,saves.json}`에 있다. smoothMeasure의 직접 호출 아래 재귀 NSView.layoutSubtreeIfNeeded와 AppKit 제약/행 배치가 관측됐고, 방 선택→entry→selectAutomatic→ConversationModel.select→LocalStore.update/save 경로도 관측됐다. 후자의 저장은 실제 부작용이지만 소수 표본이어서 남은 35ms 전부를 저장 비용으로 단정할 수 없다. 기존 refresh 밖의 전체 subtree 배치·선택 비용을 더 잘라 계측하는 일은 남았다. 이 구간에서 추가로 적용할 순수 파생값의 지배적 병목은 확인하지 못했으므로 구조/뷰 재사용이나 저장 미루기·횟수 줄이기·저장 의미 변경을 임의로 하지 않고 보고한다. 진단 표본의 성능 수치로 공식 표본을 교체하지 않았다.

### 명령·실제 종료 코드

| 명령 / 대상 | 종료 코드·실제 결과 | 로그(앞에 app/.build/hejo-smooth/ 추가) |
|---|---|---|
| `bash scripts/test.sh`, 최종 | 1; 423 통과·기존 4 실패, Python 실패 집합 동일. 이 중간 실패 때문에 셸의 앱 단계는 미실행 | `v6/full-dates/full.log`, `full.exit` |
| `bash app/scripts/test.sh`, 최종 | 1; BUILD_OK·AT-HF-23 뒤 AT-UC-32 실패. 운영 설정/다운로드 메타데이터 불변 guard 통과 | `v6/full-dates/app.log`, `app.exit` |
| 실행 환경 Python `scripts/scan_private.py`, 최종 | 0 | `v6/full-dates/private.log`, `private.exit` |
| `python3 app/Tests/hejo_smooth_regression.py final --output app/.build/hejo-smooth/v6/regression-dates` | 기록기 0; 하위 26개 중 25 통과·ui-clean-polish 실패, 58단계 의미 동결 byte 일치. HP-02와 이어지는 conversationUpdateTests 통과 | `v6/regression-dates.log`, `v6/regression-dates/results.json` |
| `python3 app/Tests/hejo_smooth.py derived --no-build --probe app/.build/hejo-smooth/v6/regression-dates/build --output app/.build/hejo-smooth/v6/derived-dates` | 0; AT-SM-10 27개 변화·실제 알림 경계·회원 상태/날짜 대조와 상한 통과 | `v6/derived-dates.log`, `derived-dates/{derived,member-state,alert-boundaries}.json` |
| 같은 실행기 `cache`, output `v6/values-dates` | 1; AppKit 0, AT-SM-01·02와 AT-SM-03 124단계/1pt 미만 대조 통과, AC-05 방 재방문 미달 | `v6/cache-dates.log`, `v6/values-dates/{execution,performance,summary,stream}.json` |
| 같은 실행기 `transitions`, output `v6/transitions-dates` | 1; AppKit 0, AT-SM-04 조건 5/5·경계 대조 통과, AC-06 3/5 | `v6/transitions-dates.log`, `v6/transitions-dates/{transitions,transition-boundaries}.json` |
| `python3 app/.build/hejo-smooth/v6/capture.py` / network_groups.py v6-final | 두 기록기 0; 추가 capture 8묶음·loopback/hook 13묶음 모두 통과 | `capture-v6-final/results.json`, `network-v6-final/results.json` |
| `python3 app/.build/hejo-smooth/v6/compare.py` | 1; Python/추가 capture/loopback 실패 집합 같음, native는 기준 0 실패·최종 AT-UC-32 1 실패. 총 47 중 기준 47·최종 46 통과 | `v6/regression-comparison.{json,log,exit}` |
| `python3 app/.build/hejo-smooth/v6/integrity.py` | 0; 151개 Swift 입력·실행 파일·동결 파일·4개 fixture 불변, 실행 커밋 일치·작업 트리 깨끗 | `v6/integrity.{log,exit}`, `tested-revision.json` |

시험 환경은 v4와 같고 Hermes 두 환경은 읽기만 했다. 위 전체 시험은 임시 HERMES_HOME·짧은 pytest basetemp·가짜 명부로 실행했다. 전체 로그와 실행기 안의 실제 로컬 경로는 추적하지 않는다.

중간 실패 보존: `v6/build02d.log`/`derived02d/run.log`(새 상태 시험에서 비교 화면의 두 번째 그리기까지 계수한 시험 오류; 집계 경계 수정 후 통과), `v6/regression/build/compile.log` 및 `v6/baseline-profile/compile-first.log`(오래된 CF 상수 표기 컴파일 오류, `.commonModes`로 수정). `v6/full/`은 629f4e0로 시작해 앱 시험 전 테스트 상수 표기만 95ba0f5로 고쳐 앱 0이었으나 최종 결과 대신 쓰지 않는다. `v6/values/`, `v6/transitions/`, `v6/repeats/`는 날짜 재사용 전 95ba0f5의 중간 결과다. 모든 실패 표본을 남겼다.

### 전후 원시 계측

| 동작 | 기준 5회(초) | 최종 5회(초) | 최종 중앙값 / 최대(초) | 판정 |
|---|---|---|---|---|
| select | 0.639132333, 0.636760250, 0.638979458, 0.624043708, 0.664452667 | 0.044376292, 0.045608125, 0.043368333, 0.044253125, 0.044231792 | 0.044253125 / 0.045608125 | 통과 |
| pile_open | 0.591663875, 0.620933250, 0.578887583, 0.592837583, 0.603647917 | 0.034546250, 0.038124458, 0.034093500, 0.034600375, 0.035067000 | 0.034600375 / 0.038124458 | 통과 |
| pile_close | 0.620156167, 0.583614792, 0.589248750, 0.606251292, 0.619044250 | 0.030324333, 0.032471625, 0.030145625, 0.030137917, 0.030844792 | 0.030324333 / 0.032471625 | 통과 |
| new_post | 0.628326125, 0.589066125, 0.601317583, 0.584583625, 0.615645208 | 0.032272625, 0.034248833, 0.032221083, 0.031533750, 0.033056583 | 0.032272625 / 0.034248833 | 통과 |
| room_revisit | 0.616206625, 0.642360208, 0.633968583, 0.615750833, 0.629451583 | 0.064590750, 0.064954375, 0.064087625, 0.065590292, 0.064492917 | 0.064590750 / 0.065590292 | 미달 |
| receive | 0.601004292, 0.583676458, 0.583448750, 0.621084708, 0.594904708 | 0.039033583, 0.040422375, 0.039098458, 0.039716292, 0.038726208 | 0.039098458 / 0.040422375 | 통과 |
| notification_prepare | 0.862602083, 0.869003208, 0.876541875, 0.901778250, 0.887425333 | 0.046403083, 0.048314833, 0.046191125, 0.049115042, 0.045648542 | 0.046403083 / 0.049115042 | 통과 |
| room_first | 0.612695042, 0.647910833, 0.612196000, 0.614302708, 0.660491792 | 0.340745875, 0.344151041, 0.341536333, 0.347870833, 0.353567750 | 0.344151041 / 0.353567750 | 통과 |

스크롤은 2625걸음, 중앙값 0.000032958342초, 최대 0.011765583185초로 통과. 전용 수정 없음. 처음 보는 방의 기준 최대값과의 비교만 악화 금지이고 나머지 7행은 절대 예산이다. 원시 시각·계수·구간 값은 performance.json에 있다. 기준 동결 파일은 그대로 유지했다.

### 전환 원인 계측(동작 수정 없음)

| 최종 공식 표본 | 단계 수 | 최대 간격(초) | 종료(초) | AC-06 |
|---|---|---|---|---|
| 1 | 12 | 0.070825917 | 0.320351375 | 실패 |
| 2 | 17 | 0.049303333 | 0.343886583 | 통과 |
| 3 | 15 | 0.042166083 | 0.306904542 | 통과 |
| 4 | 11 | 0.096733167 | 0.333528167 | 실패 |
| 5 | 15 | 0.044733125 | 0.303048250 | 통과 |

공식 표본 모두 전환 전 refresh 1·전환 중 refresh 0·scroll 시작 0·즉시 배치 일치. 이미 열린 창의 scroll·수신 중 갱신·reduce motion 경계는 별도 JSON에 통과했다. 원시 5회를 교체하지 않았다.

진단은 기준 제품과 동작이 같은 계수기 커밋 5cfb121의 보관 사본과 최종 제품을 같은 관측 지점으로 비교했다. 기준 보관 사본에는 이벤트 관측 및 profile 실행 분기만 덧붙였고 실제 원시 기준/fixture는 건드리지 않았다. 전용 함수 처리, show 직후, apply 비용, 실행 루프 활동(1 진입·2 타이머 전·4 sources 전·32 대기 전·64 대기 후·128 종료)을 기록했다. `run_profile.py baseline/final` 각각 0이며 `v6/profile-{baseline,final}/{execution,profile-0~5,transitions}.json`, `stack-0~5.txt`와 `sample-0~5.log`에 원시 자료가 있다. 각 0.033초 초과 구간의 이전 단계 처리·그 외 경과·show·실행 루프 시각은 `v6/profile-analysis.json`의 gaps_over_033에 빠짐없이 있다. `analyze_profile.py` 종료 0.

- baseline: step 중앙값 0.000145958·최대 0.002677042초, 타이머 등록 뒤 show 중앙값 0.000109458·최대 0.000197000초, apply 최대 0.023705125초.
- final: step 중앙값 0.000275188·최대 0.002663667초, 타이머 등록 뒤 show 중앙값 0.000105313·최대 0.001607167초, apply 최대 0.008686833초.

관측: 긴 간격은 대부분 단계 함수 밖이다. 일부는 실행 루프 종료→재진입 사이 약 35~47ms, 일부는 sources/대기/다음 timer 사이에 있다. 스택에는 QuartzCore transaction flush/display, AppKit control·NSTextView 그리기와 background text layout, GenieView.updateStrips/층 변경이 있다(예: profile-final/stack-2.txt). `show()` 자체가 50ms를 점유하는 패턴은 아니다. 가능한 조사 위치는 PetView/GenieView의 동일 그림 계산·CoreAnimation 층 갱신, AppKit의 배치/그리기 및 실행 루프 타이머 실행 조건이다. 같은 입력의 순수 계산 재사용만 범위 적합 후보이고, 모양/길이·렌더 횟수·타이머 정책·배치 미루기는 현재 승인 밖이다. **스택 표본은 준비 작업도 포함하고 개별 stack에 절대 시각이 없어 각 초과 간격과 1:1로 원인을 확정하지 못했다. sample 도구의 부하가 있는 진단 실행은 공식 AC-06 수치 대신 사용하지 않는다. GAP-SM-03의 최종 원인/수정 범위는 여전히 사용자·계획 담당 판단이 필요하다.**

### 변형과 불안정 시험

색 전용 임시 관측 표본을 기존 입력 누락 변형 위에서 먼저 실행했다. 이름 색만 magenta로 변경하면 이름은 실제로 달라지고 본문 속성은 같았다. 기존 본문이 재사용돼도 Post.nameColor를 매번 새로 설정해 표시가 올바르므로 이 누락은 검출되지 않는 중복 보호다. 링크 색만 green으로 바꾼 표본은 이름 색이 그대로이고 본문 링크 속성이 달라져 누락을 검출했다. `v6/colors/{execution,colors}.json`(native 0), `temporary-color-sample.patch`, `v6/color-build/build.json`에 결과와 재현용 패치를 보존했다. 이전 32/37 결과는 그대로이며 새 링크 검출 1개와 독립 이름 색 중복 보호를 구분한다. 승인된 기존 중복 보호 3개는 다시 다루지 않았다.

그 뒤 제품의 mutation 필드·입력 누락 matcher/분기·smoothReplace를 제거했고 HEJO_PERF_TESTING 계수/관측은 유지했다. 의존 시험과 실행기의 mutations mode도 제거했다. 지난 실행기/결과는 이전 커밋·v6/retired-mutation-tests.swift.txt 등에 남아 있다. 마지막 제품과 시험에서 `HejoSmoothProbe.mutation`, 입력 누락 matcher가 없음을 rg로 확인했다.

| 묶음 | 기준 10회 통과 | 최종 10회 통과 | 결과 파일 |
|---|---|---|---|
| --ui-clean-polish | 5/10 | 7/10 | v6/repeats/results.json(기준), v6/repeats-dates/results.json(최종) |
| --task41 | 10/10 | 10/10 | v6/repeats/results.json(기준), v6/repeats-dates/results.json(최종) |

두 실행기는 기록 완료 0이며 하위 실패를 성공으로 취급하지 않았다. 기준과 최종은 같은 실제 resources/cwd, 격리 홈, 다른 빌드/시험이 없는 상태에서 한 번에 한 프로세스씩 실행했다. baseline binary는 ac212cf 보관 빌드, final binary는 최종 커밋과 영수증/해시 일치다. 이전 95ba0f5는 AT92 9/10이었고 최종은 10/10이지만 불안정 원인이 해소됐다고 선언하지 않는다. AT-UC-32는 기준·최종 모두 재현돼 원인 미확정이다.

### 증거·미실행·인계

증거 수준 1(소스·제품 빌드)·2(합성 프레임·독립 파서/merge/새 모델 대조)·3(실제 AppKit View·타이머·로컬 loopback 실행)에 도달했다. 요구 전체의 수락/체감 통과 선언은 아니다. 독립 회귀 실패 집합 동일성은 미충족이고 원인 확정이 남았다. AT-SM-09는 무연결 실제 창의 합성 관측 실행 코드만 유지했으며 사람이 여섯 동작을 각 10회 관측하지 않았다.

계획 담당이 AC-05 방 재방문(그리기 밖 비용), GAP-SM-03 전환 원인·후속 범위, AT-UC-32/과거 AT92 불안정성, AC-09를 검토한다. 현재 명세 갱신·개발 main 반영·공개 이력 통합·설치·운영 변경·실제 메시지 전송·git push는 하지 않았다. 커밋/로그는 worktree에서 직접 확인한다. 원격 포함 확인이나 푸시 승인을 아직 요청하지 않았다.

마지막 확인: AT-SM-04는 AC-06 불합격 때문에 실행기의 통합 비교가 첫 행에서 멈추므로, inline Python으로 다섯 행의 배치·횟수·기준 최종 위치를 별도 전수 대조했다(종료 0). 차이는 0, 0, 0, 0.5, 0pt이고 모두 1pt 미만이다. `v6/transitions-dates/placement-comparison.json`에 보존했다. 보고서·tasks를 임시 Git index에만 올린 개인값 검사도 종료 0(`v6/report-private.log`, `report-private.json`). 실제 공용 main HEAD·인덱스는 작업 시작과 같고 공용 app 변경 없음, 최종 worktree 깨끗함과 소스 일치 재확인도 종료 0(`v6/integrity-last.log`).


## 보완 인계 v7 실행 결과 — 공개 통합·로컬 설치

### 대상·이식
- 기준은 handoff v7·spec v5·수락 시험 v5다. 공개 원격 tip을 `git ls-remote github refs/heads/main`으로 확인한 값은 `dba49a7ccea4b4212618ecf773e40c4e18f6bb67`이다. 낡은 추적 참조만 fetch하고 그 tip에서 새 공개 통합 worktree·브랜치 `hejo-smooth-public-20261124`를 만들었다. 개발 worktree와 `fc756976ff5e52ed7498fcfd8231a37f05fdc59f`는 보존했다. 이력을 merge하거나 개발 트리로 덮지 않았다.
- 공개 통합 커밋: `e745466bc9772819626ee80cbefc442b02322da4`. 제품 11파일과 시험 5파일만 포함하며 문서는 없다. 파일 목록은 `git diff --stat dba49a7 HEAD`와 `port-files.json`을 참고한다. 아래 로그는 모두 공개 통합 worktree의 `app/.build/hejo-smooth-public/` 기준이다.
- 손으로 옮긴 곳: ConversationController.notifyChange에 달력 값 제거를 넣되 공개판 historyChangePending 일괄 전달을 유지했다. PetController.setExpanded의 expanded 인자와 관측만 옮기고 공개판 placePet(old.anchorOrigin)·펫/대화 분리 좌표를 유지했다. TestMain 맨 앞에 smooth 시험 분기만 더하고 공개판의 연결·재연결·완료·위치 시험 분기를 보존했다. `manual-port.json`, `rejected-hunks/`에 원래 문맥과 조치를 보존했다.
- 공개 고유 기능: ConnectionsWindow·GateClient·PetLayout·ThreadTools는 공개 tip과 바이트 동일하다. Controller의 performUpdates/paused/historyChangePending와 View의 요청 유무별 tone 경로도 보존했다(`public-preservation.json`).

### 공개 코드의 재사용 입력 재확인
| 값 / 소유 자리 | 입력 | 버리는 때 / 상한 |
|---|---|---|
| 본문 / ConversationView | 글 id·원문·표시 문자열·본인 여부·pending·streaming·밝기·발신자/링크/가장자리 색·appearance revision·강조·체크 값 | 입력 변경 시 교체, 삭제/표시 변경 때 제거, 2048 |
| 높이 / NativeThreadCard | 불변 NSAttributedString 객체와 폭 | 같은 객체의 폭 변경 시 교체, FIFO 4096; mutable 문자열은 기억 안 함 |
| 판정 / ConversationModel | 스레드의 전체 ConversationMessage 배열과 확인 id 집합; 공개판의 종료 판정이 읽는 streaming도 전체 구조 비교에 포함 | 입력 변경 시 교체, 스레드 삭제 시 제거, 2048; 렌더 범위 기억은 상태 변경/렌더 종료 때 폐기 |
| 달력 버튼 / ConversationController | 글 text·timestamp·role·pending·현재 Calendar, calendarEvents | calendarEvents 변경 시 전체 제거, 글 삭제 시 제거, 입력 변경 시 교체, 2048 |
| 생각 중 판정 / ConversationModel | 글 text | 글 삭제/입력 변경, 4096 |
| 시각 표시 / ConversationView | timestamp·Locale·TimeZone·Calendar | 삭제/표시 변경 또는 입력 변경, 2048 |
| 날짜 / ConversationModel | timestamp 원문 | FIFO 4096, 모델 수명 |
| 회원 상태 병합 / MemberState·LocalStore | 선택 계정·그 계정 document.items·pending; settings didSet의 비저장 revision | 계정/원격 항목/대기 항목 변경 때 다음 조회에서 교체, 병합 결과 한 개 |

전체 공개 MemberState/LocalStore 쓰기 경로가 개발판과 같은 것을 확인했다. 전송 대기 변경·확인·원격 수신·계정 전환 대조도 공개 실행 파일의 derived 모드에서 통과했다. 새 최적화는 추가하지 않았다.

### 공개 기준 전후 계측
입력은 8방 × 100스레드 × 4글, 길이 200/800/3000의 기존 workload다. `baseline-values/workload-frames.json`을 동결하고 원시 파일 해시를 `baseline-frozen.json`에 기록했다. 전후 각 준비 1회와 본 표본 5회이며 표본을 교체하지 않았다. 턴 중단으로 완료 영수증이 없는 첫 기준 실행은 `baseline-interrupted/`에 부분 자료를 보존하고 처음부터 재실행했다(`interruption.json`, 종료 코드 미확인).

| 동작 | 수정 전 중앙값 / 최대 (초) | 수정 후 중앙값 / 최대 (초) | spec v5 |
|---|---:|---:|---|
| new_post | 0.640741 / 0.666711 | 0.035065 / 0.036265 | 통과 |
| notification_prepare | 0.927178 / 0.968851 | 0.047687 / 0.056075 | 통과 |
| pile_close | 0.631463 / 0.658761 | 0.033251 / 0.033637 | 통과 |
| pile_open | 0.622788 / 0.676246 | 0.037621 / 0.037839 | 통과 |
| receive | 0.637371 / 0.709433 | 0.040460 / 0.042207 | 통과 |
| room_first | 0.675609 / 0.680519 | 0.355813 / 0.373415 | 통과 |
| room_revisit | 0.661761 / 0.688224 | 0.063990 / 0.076049 | 통과 |
| select | 0.683448 / 0.706712 | 0.049196 / 0.050295 | 통과 |

- 원시 5회 값과 스크롤 2625걸음은 `baseline-values/performance.json`, `final-values/performance.json` 및 양쪽 `summary.json`에 보존했다. 최종 스크롤 중앙값·최대는 각각 0.00003262 / 0.01679421초로 예산 안이다.
- 전환: 공개 기준 프레임 합격 0/5 → 최종 4/5. 최종 5회 모두 즉시 목적지 배치, 전환 전 refresh 1, 중간 refresh 0, 중간 scroll 시작 0이며 최종 위치 차이 1pt 미만이다. 원시 단계·간격·종료는 양쪽 transitions.json에 있다. 이식에서 모양·길이·스크롤 규칙은 추가 변경하지 않았다.
- 실행: `python3 app/Tests/hejo_smooth.py baseline --no-build --source <공개 기준 관측 사본> --probe <baseline-build> --output <baseline-values>` 종료 0, `... check --no-build --probe <final-build> --output <final-values>` 종료 0. 로그 `baseline-measure-resumed.log`, `final-measure-resumed.log`, 실제 실행 영수증은 양쪽 execution.json. AT-SM-01·02 PASS, 스트리밍 124단계·전체 카드·즉시 배치/경계 대조 포함.
- `... derived --no-build --probe <final-build> --output <derived-final>` 종료 0 (`derived-command.log`, derived-final/execution.json). AT-SM-10 변화·계산 횟수·삭제·상한과 회원 상태 대조 자료는 derived-final/에 있다.

### 전체 시험·실패 집합 비교
- 공개 기준·최종에서 `bash scripts/test.sh` 각각 종료 1, 모두 423 통과·동일한 기존 Python 4 실패다. 로그 baseline-full/full.log, final-full/full.log.
- 중간 실패로 생략될 앱 묶음은 `bash app/scripts/test.sh`를 양쪽에서 따로 실행했다. 각각 종료 1이며 앱 단위와 loopback/hook 묶음은 끝까지 실행됐고 종료 trap의 `Real settings metadata changed` 보호 단언이 실패했다. 다운로드 메타데이터 보호는 양쪽 통과했다. 로그 baseline-full/app.log, final-full/app.log. 설정 내용을 열거나 복원하지 않았으며 원인 귀속은 미확정이다.
- 독립 시험은 수정 전·후 각각 native 31 + capture 8 + loopback/hook 13 = 52묶음 전부 통과했다. HP-02와 공개 고유 기능 5묶음도 포함하며 의미 동결 58단계는 expected와 바이트 일치한다. 전후 독립 실패 집합은 모두 공집합이다. 일부 기준 묶음 도중 턴 중단이 있어 완료된 4묶음은 반복하지 않고 미완료 로그를 `.interrupted.log`로 보존한 뒤 나머지만 이어갔다. recorder 종료 0을 하위 시험 통과의 대용으로 삼지 않고 각 results.json의 실제 하위 종료 코드를 확인했다.
- 모든 시험 실행 파일이 멈춘 30초 동안 기존 앱을 계속 실행한 채 내용 없이 lstat만 비교했다. 시험 프로세스는 시작·종료 모두 0개였고 hejo 설정 메타데이터가 바뀌었다(`idle-settings-clean.local.json`, `idle-metadata-clean-command.log`, 종료 0). 따라서 보호 단언 실패는 공개 기준에서도 발생하고 시험 부재 중에도 재현되는 환경 관측이다. 정확한 쓰기 주체·내용은 추적하지 않았으며 그 파일을 열거나 복원·수정하지 않았다. 앞선 계측 동시 관측은 원인 증거로 쓰지 않았다.
- 푸시 후보: 공개 통합 worktree, 원격 `github`, 브랜치 `hejo-smooth-public-20261124`, 커밋 `e745466bc9772819626ee80cbefc442b02322da4`. 후보 기록이며 승인 요청이나 푸시 완료가 아니다.


### 검증 명령·종료 코드·증거
검증 대상은 별도 표시가 없으면 공개 통합 커밋 `e745466bc9772819626ee80cbefc442b02322da4`다. 아래 로그 경로는 공개 통합 worktree의 `app/.build/hejo-smooth-public/` 기준이다. `<...>`는 실제 경로 대신 쓴 증거 폴더 표기이며 실제 실행 인자는 해당 로컬 영수증에 있다.

| 명령 | 실제 종료 | 증거 / 판정 |
|---|---|---|
| `bash scripts/test.sh` (공개 기준 / 최종) | 1 / 1 | baseline-full/full.log, final-full/full.log: 양쪽 423 통과·동일 4 실패 |
| `bash app/scripts/test.sh` (공개 기준 / 최종) | 1 / 1 | baseline-full/app.log, final-full/app.log: 앱·fixture 실행 뒤 같은 설정 메타데이터 보호 실패. 전체 통과 아님 |
| `hejo_smooth.py baseline/check --no-build ...` | 0 / 0 | baseline-measure-resumed.log, final-measure-resumed.log, 양쪽 execution.json·원시 JSON. AT-SM-01~04·05·06·07 |
| `hejo_smooth.py derived --no-build ...` | 0 | derived-command.log, derived-final/: 27개 변화, 회원 상태 9전이, 알림 시각 4경계. AT-SM-10 |
| `hejo_smooth_regression.py baseline/final`와 중단 후 잔여 기록기 | 기준 잔여 0 / 최종 0 | native-baseline-resumed-command.log, native-final-command.log; regression-baseline/results.json, regression-final/results.json: 각 31/31 |
| `capture_groups.py` | 0 | capture-command.log, capture-baseline/results.json, capture-final/results.json: 각각 8/8 |
| `network_groups.py baseline/final` | 0 / 0 | network-baseline-command.log, network-final-command.log, 각각 results.json: 각 13/13 |
| 실행 환경 Python `scripts/scan_private.py` | 0 | final-full/private.log, 최종 제품·시험 변경 없음 |
| `integrity.py` | 0, 설치 후 재확인 0 | integrity-command.log, final-integrity.log, tested-revision.json: Swift 입력 156개·실행 파일·fixture·공개 기준 동결·개발 worktree·공용 main 인덱스/HEAD/app 보존 |
| `assess.py` | 영수증 완성 전 1, 완성 후 0 | acceptance-before-integrity.log(아직 없는 영수증), acceptance-command.log, acceptance-result.json: TASK-10 통과 |

Python 실패 id 4개는 acceptance-result.json에 정확히 기록했다. AT-UC-32와 AT92는 이번 공개 기준/최종 독립 묶음과 전체 앱에서 통과했으며 이전 개발 기준의 불안정 이력은 없애지 않는다. 수락 기준·입력 규모·기대값·동결 fixture는 바꾸지 않았다.

### TASK-11 배포 빌드·백업·설치
- 정상 배포 빌드 `bash app/scripts/build.sh` 종료 0. `HEJO_SKIP_GOOGLE_SECRET`·시험 옵션 없이 실행했고 고정 Sparkle 의존성만 오프라인 재사용했다. 기존 프로젝트의 무시된 정상 Google 입력을 가리키는 무시된 로컬 링크를 빌드 도구가 소비했다. 그 값은 직접 열거나 출력·기록·수동 복사하지 않았다. 기존 배포 기록에 있는 방법을 재사용했으며 운영 Hermes 비밀 파일은 열지 않았다. 로그 install/normal-build.log·normal-build.exit·prepare-command.log·candidate.json.
- BuildInfo는 dirty=false, tree `8e6f138728513e00a70026e4b1bcd6be184d63b6`이며 공개 커밋과 일치한다. 버전 0.2.7 / 빌드 9를 유지했다. 시험용 실행 파일을 설치하지 않았다. Google·업데이트 기능 구성 키의 존재, 서명, 기존 리소스 9개 바이트 보존을 확인했다(`install/resources.json`).
- 기존 앱의 실행 경로와 번들 id를 다시 확인하고 `install/backup/hejo.app`에 새 백업을 만들었다. 이 위치는 공개 통합 worktree의 무시된 증거 폴더이며 이전 백업을 덮지 않았다. 백업 서명 검증과 전체 파일 manifest 일치 뒤에만 종료·교체했다.
- 최초 설치 도구는 작업 공간과 설치 앱이 다른 파일시스템이라는 사전 조건에서 종료 1로 멈췄다. 이때 백업·앱 종료·교체는 미실행이었다(`install/install-initial-command.log`). 설치 도구의 임시 교체 경로를 설치 앱과 같은 디렉터리로 바꾸고, 작업 증거 폴더로의 검증된 백업 복사와 같은 파일시스템 안의 rename 교체를 사용했다. 제품·후보 빌드는 바꾸지 않았다.
- 수정한 로컬 설치 도구 종료 0 (`install/install-command.log`, install-command.exit). 기존 앱 정상 종료 요청이 수락되고 종료를 기다린 뒤, 원본 번들을 별도 작업 전용 이름으로 보존하고 서명 확인한 후보를 같은 설치 위치로 rename했다. 강제 종료는 하지 않았다. 정상 재실행 후 실제 실행 경로·실행 파일 해시·번들 manifest가 후보와 일치했다. 표준 ‘대화 열기’ 메뉴를 눌렀으며 화면에 1103×777 대화 창이 표시됨을 좌표 메타데이터로 확인했다. 메시지나 대화 내용은 읽거나 보내지 않았다. 실제 경로는 install/transaction-paths.local.json·lifecycle.local.json에만 있다.

| 설치 증거 | SHA-256 |
|---|---|
| 기존 / 백업 실행 파일 | `1576290a0e9c54689929ce1c50ad656d651a0d24023f445b338a1628d39fc53d` |
| 후보 / 설치 후 실행 파일 | `3294cc8a443f6dde7cad127510a0689d2bc547ef34a566b0f41e615be94dcec9` |
| 기존 / 백업 번들 파일 manifest | `aeb4fceeebfd921f1015ba469a79d68de67f48b862a52a4dd6e236be439350d4` |
| 후보 / 설치 후 번들 파일 manifest | `3f4f9cbe46ae93861c0723e46eb24ac0dc9945d857532eb6683d2a43a42e2f82` |

서명 `codesign --verify --deep --strict`는 기존·백업·후보·설치 후 모두 종료 0이다. 기존/후보 서명 상세는 install/before-signature.log·candidate-signature.log, 버전과 해시는 existing.json·candidate.json·installed.json, 백업 파일 manifest는 backup-manifest.json에 있다. 복구는 실제로 필요하지 않아 미실행이다.

복구 방법: `install/transaction-paths.local.json`의 원래 설치 경로와 보존 원본을 사용한다. 새 앱을 **정상 종료**하고 종료를 확인한 뒤 현재 후보를 작업 전용 별도 이름으로 보존하고 같은 디렉터리의 원본 번들을 원래 위치로 rename한다. 그 원본을 쓸 수 없으면 검증한 `install/backup/hejo.app`를 같은 설치 파일시스템의 새 임시 번들에 복사·서명/manifest 확인 후 원래 위치로 rename한다. 백업 해시와 서명을 재확인하고 정상 실행한다. 정상 종료가 거부되면 강제 종료하지 않고 멈춘다. 운영 설정·키체인·대화 저장소는 복원 대상으로 삼지 않는다.

### 도달 수준·인계 범위
- 필요 증거 1·2·3을 확보했다: 공개 소스와 정상 빌드, 가짜 입력/loopback 통합, 실제 AppKit 계산·실행 환경의 계측과 동작 확인. 실제 로컬 앱 번들 교체·실행·대화 창 표시는 설치 증거로 따로 보존했다.
- 사용자 체감 관측은 미실행이다. AT-SM-09는 계획 담당이 설치 앱에서 여섯 동작 확인을 요청해야 한다. 복구 실행, 실제 Google 서비스 연결/인증 새 시험, 실제 메시지 전송은 미실행이다.
- 계획 담당 체크아웃은 impl-report와 tasks 상태 칸만 변경했다. 공용 main 인덱스·HEAD·app과 개발 worktree·브랜치·증거를 보존했다. 현재 명세 갱신·개발 main 반영·공개 main 반영·서버/게이트웨이/허브/플러그인 재시작·운영 설정/키체인 수동 변경·git push는 하지 않았다.
- 다음은 TASK-12 사용자 확인과 계획 담당 검토·현재 명세 반영·문서 공개 포함 여부·푸시 방식 결정이다. 푸시 후보는 위 공개 통합 커밋 그대로이며 사용자 화면 승인 전에는 보내지 않는다.

마지막 문서 검사: `scan_report.py`가 두 문서를 임시 인덱스에만 올려 실행 환경 Python의 개인값 검사를 실행했고 종료 0이었다(`report-private.json`, `report-private.log`). 실제 공용 main 인덱스는 보존했다. 설치 후 source/실행 파일 무결성 재확인도 종료 0이며 공개 작업 트리는 깨끗하다. 마지막 읽기 확인에서 원격 공개 main은 여전히 `dba49a7ccea4b4212618ecf773e40c4e18f6bb67`이고 공개 통합 후보 브랜치의 원격 참조는 없었다. 푸시는 미실행이다.
