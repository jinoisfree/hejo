# 구현 인계: 연결 재시작 단계 멈춤

최신 적용 상태: 공개 통합 회귀 차단으로 설치 보류. 상세는 마지막 TASK-CS-04~05 절을 따른다.

## 개발 구현·자체 시험 기록

1. 받은 설계: [handoff.md](handoff.md)의 현재 보완 지시, spec·design v3, [verdict.md](verdict.md)의 V-CS-02·03. 최초 기준 `236b0177468b90d9ea23a1b1190e996db78a0694`, 이번 보완 기준 `b10646760bf8424583db23b4ec4099ea18b03357`. 연합개발, 위험도 일반, 필요 증거 수준 1·2·3. 호스트 구현 승인 근거는 로컬 `approval.txt`에 보존했고 호스트 상태는 수정하지 않았다.
2. 구현자 판단: 구현·자체 시험 완료. IMPL-CS-01은 계획 담당이 HC-26 교체 범위 누락으로 수용했고 이번 보완으로 해소했다. 최종 판정과 현재 명세 반영은 검토 담당에게 남긴다.
3. 변경 후 구조: 기존 ConnectionsModel이 요청 당시 프로필·job과 읽기 전용 조회 수명을 관리하고, ConnectionsWindow가 내부 확인 sheet의 높이·키 포커스·종료를 맡는다. ConnectionInputView는 단계에 맞는 버튼과 안내를 표시한다. 서버·별도 장부·창 관리자는 추가하지 않았다.
4. 더한 것 / 뺀 것:
   - 선행 구현 `b10646760bf8424583db23b4ec4099ea18b03357`: `app/Sources/ConnectionsWindow.swift`, `app/Tests/ConnectionsTests.swift`, `app/Tests/TestMain.swift`. 내부 확인의 normal 전환을 제거하고, 응답 유실 시 재시작 재전송 안내를 기존 job_status 조회로 교체했다. 시스템 인증의 normal 전환·복원은 유지했다. 새 AC와 재현 probe를 시험 등록부에 연결했다.
   - 이번 보완 `app/Tests/ConnectionsTests.swift`: HC-26 내부 확인은 부모·sheet의 선호 높이 26, 가시성, 키 대상, 앱 모달 없음으로 판정한다. 기존 sheet 취소 완료와 시스템 인증 기준은 유지했다. 완료된 현재 요청의 추적 해제 및 응답 유실 뒤 최근 결과의 읽기 전용 재확인도 검사한다.
   - 이번 보완 `app/Sources/ConnectionsWindow.swift`: 현재 요청과 연결된 완료 응답에서만 추적 상태와 이전 재시작 입력 단계를 종료한다. 응답 유실 뒤 latest에서 얻은 최근 결과는 추적 상태를 유지한다. 시험 전용 제품 예외 분기는 없다.
5. 설계와 달라진 점: HC-26 정정 뒤 기존 CM-38에서 후속 독립 연결의 resume가 읽기 전용 조회로 바뀌는 결함을 발견했다. 선행 구현이 확정 완료 후에도 trackingRestart를 유지한 것이 원인이었다. 영향·원인을 작업 중 보고한 뒤, 기존 완료 계약을 복원하는 위 4줄을 같은 Model 책임에서 보완했다. 기존 CM-38 기대값은 바꾸지 않았다. 새 공개 계약·구조·설정·수락 기준을 도입하지 않았다. 이 추가 제품 수정의 적합성을 검토 요청한다.
6. 사용한 경계와 임시 코드: 전송 대역·짧은 제한 시간 주입은 실제 pending continuation과 타이머를 실행하는 고장 주입용이다. 제품 기본 180초, 조회 간격 2초·450회는 유지한다. 실제 AppKit이 중첩 sheet를 부모 표면에 합성하므로 노출된 sheet 조상 표면의 순서·영역도 관측한다. 제품 임시 경로는 없으며 재실행 도구·로그·가짜 홈은 추적하지 않는 로컬 증거다.
7. 변경 성격과 원인: 단계 라벨의 의미 변경을 포함한 버그 수정이다. 수정 전 `repro.log`는 종료 1로 부모·입력·확인 높이 0 대 대화창 25 및 일반 재시도 안내를 재현했다. 수정 후 `repro-after.log`는 종료 0으로 높이 26과 부작용 1회 후 조회 복구를 확인했다. 최초 조회 수에는 창 시작 시 latest 조회도 포함된다. 이번 보완은 `hc26-connections.log`의 기존 CM-38 실패에서 `completion-connections-pass.log` 통과로 비교한다.
8. 시험:
   - AT-CS-01: 재시작 단계의 버튼·안내와 일반 입력의 저장 문구 보존.
   - AT-CS-02: 일반/떠 있는 창에서 버튼의 화면 내 위치, 키 대상, 겹침과 실제 표면 순서를 검사한다. NSEvent down/up을 앱 큐에 넣어 수락·취소하며 performClick/endSheet로 수락 결과를 대신하지 않는다.
   - AT-CS-03a: 응답 대기와 진행 표시, resume-only 1회, 알려진 job·요청 프로필 유지, 확정 완료 후 기존 단계 종료.
   - AT-CS-03b: 직접 gateway_restart와 resume 각각의 타이머 만료·전송 후 끊김, 시나리오별 부작용 1회, latest→job 회복, 입력창 없는 notice, 최근 결과의 상관관계 한계와 후속 조회에서 부작용 요청 무송신.
   - AT-CS-03c: failed/refused/partial/unknown/timeout/UNKNOWN_JOB, 조회 실패·횟수 종료, 읽기 전용 재확인, 명시적 BUSY 미실행 복귀.
   - AT-CS-03d·04: 인증·원래 요청·latest 조회 중 닫기, 선택 변경·재열기, 늦은 응답, 확인 중 입력/부모 창 종료.
   - HC·CM·FF의 다른 기준은 유지했다. HC-26의 충돌 단언만 승인된 보완 기준으로 교체했다. 별도 mutation은 생략했고 대표 고장의 수정 전 실패·수정 후 통과를 보존했다. 수락 시험 명세는 구현자가 수정하지 않았다.
9. 실행한 검증:

| 명령 / 검증한 변경본 | 실제 결과 | 로그 |
|---|---|---|
| `bash app/scripts/test.sh` / 이번 보완 | 종료 0, 서명 빌드·기존 전체 앱 회귀·새 AC·모든 후속 fixture·9개 hooks 시험·보존 검사 통과 | `app-suite-completion-retry.log` |
| `app/.build/connection-stuck-evidence/app-tests-hc26 --connections` / 이번 보완 | 종료 0, HC·CM·FF·AT-CS-01~04 | `completion-connections-pass.log` |
| `TEST_PYTHON scripts/scan_private.py` / 이번 보완 | 종료 0, 텍스트 지적 없음·바이너리 생략 | `privacy-completion.log` |
| `git diff --check` / 이번 보완 | 종료 0 | `scope-completion.log` |
| `bash scripts/test.sh` / 선행 커밋의 증거 재사용 | 전체 명령 종료 1은 당시 HC-26 실패. 그 앞의 Python 427 passed·격리 gateway AT-HF-22는 통과 | `full-suite-short-temp.log` |

gate・schemas・scripts의 보완 기준 대비 diff가 비어 있음을 직접 확인했다. Python·gate 무변경이므로 허용된 427개·AT-HF-22 증거를 재사용했다. 이번 앱 전체 명령의 빌드가 별도 빌드를 포함한다. 최종 검토 로그는 `completion-final-review.log`다.

각 실행은 `python3 app/.build/connection-stuck-evidence/run-check.py <로그명> <명령...>`으로 격리 환경에서 수행했다. 실제 명령·작업 폴더·종료 코드는 로그에 기록했다. `TEST_PYTHON`은 기존 HEJO_PYTHON 실행 파일로 치환된다. 임시 HERMES_HOME·가짜 명부·짧은 TMPDIR를 사용했고 별도 에이전트를 사용하지 않았다.

실패·중단 이력도 보존한다. 첫 전체 앱 실행 `app-suite-completion.log`는 종료 1로 연결 시험보다 앞선 AT-UC-32에서 실패했다. 관련 파일은 최초 기준과 같고 새 연결 시험도 아직 실행되기 전이었다. 같은 실행 파일의 분리 `--ui-clean-polish`는 종료 0(`uc32-isolated.log`)이었다. 이전 전체 로그에도 해당 시험의 통과 기록이 있어 제품을 고치지 않고 전체를 1회 재실행했다. `hc26-connections.log` 종료 1은 위 CM-38 결함이다. `completion-connections.log` 종료 1은 새 읽기 전용 검사에서 자동 refresh 프레임을 마지막 요청으로 오인한 시험 관측 오류다. 마지막 connection_action을 선택하도록 고친 후 통과했다. `app-suite-hc26.log`는 CM 결함 발견 뒤 자기 시험 프로세스만 중단한 실행으로 자식 종료 -15(실행 래퍼 241)이며 통과 증거로 사용하지 않는다.

10. 증거 수준·미검증: 빌드 1, 가짜 연결·로컬 네트워크 통합 2, 실제 AppKit 이벤트·창 종료·키 대상·표면 순서 조작 3을 확보했다. 가짜 화면 PNG는 view.cacheDisplay 렌더이며 OS 전체 합성 캡처가 아니다. 가림 여부를 PNG만으로 판정하지 않았다. 운영 화면이 정확히 어느 await에서 멈췄는지는 미확정이다. 실제 운영 재시작·실제 메시지·설치는 수행하지 않았다.
11. 범위 밖 부채·환경: 기존 Swift concurrency·폐기 API·weak 변수 경고는 범위 밖이며 억제하지 않았다. 초기 전체 gate 실행은 긴 임시 경로의 AF_UNIX 제한으로 실패했고 짧은 경로에서 위 427개가 통과했다. 운영 설정·비밀 파일·Hermes 본체·team-kit·다른 앱은 수정하지 않았다.
12. 검토 요청: V-CS-02의 HC-26 교체와 V-CS-03의 전체 앱 실행 증거, 확정 완료와 최근 결과의 상태 수명 구별, CM-38을 복원한 추가 4줄을 확인한다. 현재 명세 반영·최종 판정·기준 브랜치 포함 확인·푸시 대상 확정은 검토 담당에게 남긴다.
13. 검토 대상: 브랜치 `role-workflow/30-f1c5ef47`, 최종 커밋 `fd49c1de12d3328a956df118bac8ffd3e6e7a6fe`. 이번 커밋은 제품·시험 2개 파일이며 누적 변경은 위 3개 파일이다. 배정 worktree 실제 위치는 호스트 인계를 따른다. 이 보고서는 계획 담당 원본 작업 문서 폴더에 갱신했다. 푸시는 하지 않았다.

모든 로그 경로는 배정 worktree 기준 `app/.build/connection-stuck-evidence/` 아래다. 원본 로그·재실행 도구·가짜 화면 자료를 로컬에 보존한다.

## 공개 통합·로컬 적용 — TASK-CS-04~05

현재 판단: 부분 구현·보류. [application-plan.md](application-plan.md)의 전체 시험 통과 조건이 미충족하여 공개 통합 커밋·새 앱 설치는 수행하지 않았다. 아래 기록은 앞 절의 개발 검증 이후 사용자가 ‘적용해’를 승인한 범위의 실행 결과다.

- 개발 브랜치 `role-workflow/30-f1c5ef47`와 검증 커밋 `fd49c1de12d3328a956df118bac8ffd3e6e7a6fe`, 개발 worktree·기존 증거를 보존했다.
- 실제 공개 `github/main`은 착수·후속 읽기에서 `c880e52c15a5ffafb187f04d7236232e40a5af08`이다. 같은 커밋 기반 별도 `role-workflow/30-f1c5ef47-public` 브랜치와 공개 통합 worktree를 만들었다. 실제 경로는 호스트 인계를 따른다.
- 제품 변경은 기존 3파일만 이식했다. ConnectionsWindow·ConnectionsTests는 개발 검증본과 바이트가 같으며 TestMain은 공개판 기존 분기 전체를 보존하고 새 진입점 6줄만 통합했다. 개발·공개 이력 merge와 전체 트리 치환은 하지 않았다.
- 이번 작업 문서 9개·수락 시험·현재 연결 명세 1개만 선별 복사했다. 공개 통합 worktree의 문서는 적용 전 원본의 배포용 스냅샷이다. 최신 구현·설치 결과의 작업 원본은 이 보고서다. 무관한 성능 명세·미추적 문서는 추가하지 않았다.
- 공개 브랜치 HEAD는 여전히 공개 기준 커밋이며 제품·시험 3파일과 문서 11파일이 staged 상태다. 전체 시험 통과 뒤 커밋한다는 지시를 유지했다.

### 실제 검증

아래 로그는 공개 통합 worktree의 `app/.build/connection-stuck-evidence/` 기준이며, 공개 기준 위의 위 14개 변경 파일을 검사했다. 개발 검사 결과로 대체하지 않았다.

| 실행 | 실제 결과 | 로그 |
|---|---|---|
| 격리 `bash scripts/test.sh` 최종 실행 | 종료 1. Python 427개·AT-HF-22·서명 빌드·성능/펫 위치 회귀 통과 후 AT-UC-32 실패. 실제 설정·Downloads 메타데이터 보존 검사와 외부 메타데이터 비교는 통과 | `public-full-final.log` |
| `app/.build/app-tests --connection-stuck app/.build/connection-stuck-evidence` | 종료 0. 새 AT-CS-01~04, 직접/resume 응답 유실·실제 AppKit 조작 통과 | `public-cs-ac.log` |
| `app/.build/app-tests --connections` | 종료 0. HC·CM·FF·TASK-13·새 AC 통과 | `public-connections.log` |
| 원본 앱 스크립트의 후속 fixture 명령과 보존 검사만 분리 실행 | 종료 0. network부터 review55까지 모든 후속 fixture·hooks 9개·보존 검사 통과. 전체 앱 단위 회귀 통과를 뜻하지 않음 | `public-remaining-fixtures.log` |
| 격리 `TEST_PYTHON scripts/scan_private.py` | 종료 0, 텍스트 지적 없음·바이너리 생략 | `public-privacy.log` |
| 제품 이식·TestMain 기존 분기·문서 링크·staged 공백 검사 | 종료 0 | `public-integration-static.log` |
| 공개 원본 3파일을 추출해 만든 기준 실행 파일 빌드·서명 | 각각 종료 0 | `public-baseline-build.log`, `public-baseline-sign.log` |
| 같은 공개 원본 실행 파일의 기본 앱 회귀 | 종료 0. AT-UC-32를 포함한 기본 앱 회귀와 설정 메타데이터 비교 통과 | `public-baseline-unit.log` |

원본 전체 명령은 `run-check.py`로 임시 HERMES_HOME·가짜 명부·짧은 TMPDIR를 적용해 실행했다. 후속 fixture 분리는 원본 `app/scripts/test.sh`의 fixture 명령과 설정·Downloads 검사 내용을 그대로 추출한 `remaining-fixtures.sh`다. 실패를 skip하거나 제품·시험 기준을 완화하지 않았다. 기준 비교는 공개 기준의 ConnectionsWindow·ConnectionsTests·TestMain만 별도 로컬 빌드 입력으로 추출했고, 나머지 Swift 입력은 공개 기준과 변경이 없는 파일이다. 실제 통합 소스를 원복하거나 개발 worktree를 바꾸지 않았다.

최초 전체 실행은 긴 macOS 기본 임시 경로에서 gate 준비 실패(243 passed·184 errors, 종료 1)였고, 긴 경로 진단에서 AF_UNIX path too long을 직접 확인했다. 짧은 경로 대표 시험은 종료 0이었다. 잘못된 파일명을 준 최초 대표 시험 명령은 종료 4·미수집이며 `public-gate-short-probe.log`에 남겼다. 이후 올바른 대표 시험과 전체 Python 427개는 통과했다. `public-full-short.log`는 AT-UC-32와 실제 설정 메타데이터 변경을 모두 감지해 종료 1이었다. 기존 앱을 정상 종료한 뒤의 분리 UI 시험은 종료 0이었으나, 최종 전체 순서에서는 같은 AT-UC-32가 다시 실패했다. 따라서 기존 앱 간섭만으로 원인을 확정하지 않는다. 설정 내용을 열지 않았으며 메타데이터 비교 원본은 로컬에만 보존한다.

### 로컬 앱 상태·복구

기존 실제 앱은 버전 `0.2.7`·빌드 `9`, 번들 ID `io.github.hermes-hejo.hejo`다. 격리 시험을 위해 앱만 정상 종료했고, 검증 차단 후 원본 번들을 정상 재실행했다. 실행 파일 SHA-256은 종료 전후 모두 `8cdfe0305fed219044f65e361493596224f1852635fdcf6e84a6d397732aa252`이며 서명 검증도 종료 0이다. 실제 설치·실행 경로와 새 PID는 `original-app-relaunch.json`, 명령·종료 코드는 `original-app-relaunch.log`에 기록했다. 번들은 교체하지 않았으므로 백업에서의 번들 복원은 불필요했고 새 백업도 만들지 않았다. 이전 작업의 백업을 덮지 않았다.

설치 전 배포 빌드의 Google 로그인 구성 보존, BuildInfo tree·깨끗한 커밋 대응, 리소스·서명·해시 확인, 정상 종료 거부 시 중단, 새 백업 보존 및 실패 시 원본 복구를 수행하는 로컬 도구를 준비했다. `deployment-build.py`, `install-app.py`, `restore-app.py`는 추적하지 않는 준비물이며 **미실행**이다. 신규 백업·후보 배포 빌드·앱 교체·새 앱의 연결창 열기/닫기 검사는 미실행이다. 테스트 빌드는 Google 비밀을 생략하므로 설치에 사용하지 않았다. 운영 게이트웨이·허브·운영 설정·Hermes 비밀 파일에는 손대지 않았고 실제 메시지는 전송하지 않았다.

### IMPL-CS-02 — 공개판 전체 회귀의 AT-UC-32 차단

[확인] `app/Tests/UICleanPolishTests.swift:94`의 ‘그림 없는 판단 버튼 4개’ 단언이 공개 통합본 전체 순서에서 반복 실패한다. 해당 시험과 화면은 이번 제품 수정 3파일 범위 밖이며 그대로 보존했다. 공개 원본의 같은 순서 회귀는 종료 0이었으나, 직후 통합본의 같은 순서 A/B 재확인은 종료 1이었다(`public-modified-unit-ab.log`). 공개판의 기존 결함이라고 확정하지 않았으며 통합본에서의 회귀 또는 시험 실행 조건 차이 가능성을 남긴다.

[미확정] 판단 버튼 UI 결함인지, 화면 실현 시점·시험 fixture/환경의 문제인지는 확정하지 않았다. 통과한 분리 실행만으로 전체 회귀를 합격 처리하지 않았다.

[권고] 계획 담당은 기준 비교·실패 로그를 검토하고 AT-UC-32 조사·수정 범위를 보완 인계한다. 기대값 완화·skip 없이 이 문제를 해결한 뒤 공개 통합본 전체를 재검증하고, 커밋·배포 빌드·백업·교체·실행 확인을 이어 간다. 읽기 전용 최신 공개 tip 확인과 별도 푸시 화면 승인도 여전히 필요하다. 현재 공개 통합 푸시 대상 커밋은 없다.


## V-CS-04 보완 실행 — 원인 관측과 fixture 수정

앞 공개 적용 절은 실패 당시의 이력이다. 이번 보완은 [regression-plan.md](regression-plan.md)에 따라 별도 공개 worktree에서 이어 진행한다. 개발 커밋과 worktree는 변경하지 않았다.

원인은 시험의 준비·관측 오류로 분류한다. 같은 가짜 홈·임시 환경·전체 기본 앱 순서로 진단한 기준본은 종료 0, 통합본은 종료 1이었다. 양쪽 모두 실제 모델의 질문 버튼은 승인·거절·의견·확인 네 개였고 assessment에도 질문이 남았으며, 창은 표시·키 상태였다. 두 번째 chooseThread는 양쪽에서 openThread를 nil로 접었다. 검사 직전 기준본의 대상 질문 행은 y=32..211, 표시 영역은 y=383..701로 대상 행이 미실현이었다. 그런데 다른 질문 행의 표준 버튼 네 개가 실현되어 우연히 통과했다. 통합본의 대상 행은 y=211..390, 표시 영역은 y=445..763이었고 실현된 버튼은 0개라 실패했다. 모두 같은 시각의 가짜 메시지이며 homeThreads는 같은 날짜의 항목을 임의 UUID 순서로 정렬한다. 따라서 실행별 UUID에 따라 다른 행의 버튼을 관측한 것이 직접 실패 원인이다. 단일 기준 실행의 통과를 제품 정상의 독립 증거로 쓰지 않는다.

수정은 app/Tests/UICleanPolishTests.swift에 한정했다. 기존 openFromBubble 경로로 질문을 명시적으로 열고, 기존 waitFor 기본 기한 8초 안에 창·대상 행의 표시와 실제 행 생성 완료를 기다린다. 임의 sleep 확대나 성공할 때까지 재시도하지 않는다. 대상 질문의 실현된 행 안에서만 버튼을 모으며 승인·거절·의견·확인의 정확한 순서와 모든 image==nil 단언을 그대로 유지한다. 실패 때도 모델·선택·열림·실현 영역·창·레이아웃 시점 진단을 남긴다. 제품 판단 버튼 로직과 ConnectionsWindow 추가 변경은 없다. 초기 원인 진단 입력 사본과 두 실행 파일·전체 로그는 로컬 증거에 보존했다.

관측 명령은 run-check.py로 같은 환경에서 guarded-native.py와 각 진단 실행 파일을 기본 인자로 실행했다. uc32-observed-baseline.log는 종료 0, uc32-observed-integration.log는 종료 1(AT-UC-32)이며 모두 설정 메타데이터 변경 범주가 비었다. 진단 빌드·서명은 각각 종료 0이다. 최초 진단 빌드 래퍼의 Python 괄호 오타는 컴파일 전 종료 1(uc32-build-baseline.log)이며 수정된 uc32-build-baseline-corrected.log가 실제 성공 빌드다.

현재 전체 공개 회귀·개인값 검사·커밋·배포 및 설치 검증을 이어 진행한다. 이 문장 시점에는 새 공개 커밋이나 앱 교체를 완료하지 않았다. 최종 결과는 아래 후속 기록으로 구별한다.


### 공개 전체 재검증 통과

격리 `python3 app/.build/connection-stuck-evidence/run-check.py public-regression-fixed-full.log python3 app/.build/connection-stuck-evidence/guarded-native.py bash scripts/test.sh`는 종료 0이다. Python 427개·AT-HF-22, 서명 빌드, 기본 앱 전체 순서의 UC-32·성능·펫 위치·HC/CM/FF·새 AT-CS-01~04, 모든 후속 fixture·hooks 9개가 통과했다. 실제 설정·Downloads 메타데이터와 외부 비교의 변경 범주도 비어 있다. 이번에는 앞 구간을 이전 증거로 대체하지 않았다.

수정 전 대상 행이 미실현이던 같은 전체 순서에서 수정 후 질문은 열린 상태를 유지하고 약 0.065초 뒤 실현됐다. 표시 영역 y=99.5..417.5 안에 대상 행 y=169..348이 들어왔으며 그 행의 원래 네 버튼 단언이 통과했다. 홈 목록에 다른 질문의 캐시된 버튼들이 남아 있어도 검사 결과에 섞이지 않는다. 새로운 제품 변경 없이 관측 책임만 바로잡았다.

`public-regression-fixed-privacy.log`의 격리 개인값 검사는 종료 0(텍스트 지적 없음·바이너리 생략)이다. `public-regression-fixed-static.log`는 종료 0으로 16개 선별 파일·문서 링크·공백, 개발 제품 2파일 동일성·공개 TestMain 기존 분기 보존·UC-32 원래 기대값 보존을 확인했다. 이번 보완의 추가 파일은 UICleanPolishTests와 승인된 regression-plan 문서이며 unrelated merge·트리 치환은 없다. 원인 자체의 실패·수정 후 성공과 기존 단언 보존을 직접 확인했으므로 별도 mutation 추가는 생략했다. 다음 단계는 공개 커밋과 배포·설치이며 아직 수행 결과를 선행 표시하지 않는다.
