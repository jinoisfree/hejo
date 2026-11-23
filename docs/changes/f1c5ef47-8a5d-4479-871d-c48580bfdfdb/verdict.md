# 4회차 판정 — 공개 통합 부분 완료, 설치 미완료

대상은 공개 기준 c880e52c15a5ffafb187f04d7236232e40a5af08 위의 staged 14파일이다. 공개 통합 커밋은 아직 없다. 개발 fd49c1de 검증 완료는 유지하지만 공개 통합·설치의 완료로 대체하지 않는다. 검증 조건은 단일 모델·별도 구현 대화다.

## 직접 확인·설계 적합성(4.2)
원본 handoff/application-plan과 impl-report의 최신 공개 적용 절, 실제 staged 목록·TestMain diff, 관련 시험·제품 함수, 전체 및 A/B 로그를 직접 확인했다. 3개 제품 파일 이식·공개 시험 분기 보존 방향은 승인 계획과 일치한다. 설치 전 전체 검사에서 멈추고 기존 번들을 재실행한 처리는 적합하다.

공개 작업 공간 app/.build/connection-stuck-evidence/ 로그:
- public-full-final.log: 종료 1, AT-UC-32 실패. 설정·Downloads 메타데이터 보존 통과.
- public-baseline-unit.log: 종료 0. public-modified-unit-ab.log: 종료 1, 같은 AT-UC-32 실패. 이것만으로 변경의 인과관계나 기존 결함을 확정할 수 없다.
- public-cs-ac.log: 종료 0, 새 AC 통과. public-remaining-fixtures.log: 종료 0. 전체 회귀 성공과 구별한다.
- git diff --cached --check: 검토자 실행 종료 0. 새 코드 변경 없이 이미 반복된 실패 시험을 다시 돌리지 않았다.

## V-CS-04 — 공개 전체 회귀 차단
IMPL-CS-02 수용. 원인 분류는 **미확정(구현 회귀/시험 fixture·실행 조건)**이다. UICleanPolishTests.swift:94는 관측한 버튼 목록·이미지 상태를 출력하지 않고 복합 단언만 검사한다. 같은 시험에서 초기 및 중간에 chooseThread(question.key)를 호출하며 ConversationView.chooseThread는 같은 key 재호출 시 openThread를 nil로 토글한다. 가상화·레이아웃과 이 토글의 영향은 가설이며 아직 원인으로 단정하지 않는다. 해당 검사는 연결 시험보다 먼저 실행되므로 새 연결 시험 실행 자체가 직접 원인이라는 주장도 근거가 없다.

조치는 regression-plan.md에 기록했다. 기대값·버튼 수·순서·이미지 없음 요구를 완화하지 않는다. 원인 없는 반복 전체 실행이나 관련 없는 판단 버튼 기능 재설계는 하지 않는다. 원인 확인 후 범위 내 수정과 전체 검증을 마치고 이미 승인된 설치를 진행한다.

## 완료까지 남은 조건
V-CS-04 원인과 최소 수정 증거 → 공개 통합 전체 검사 통과 → 공개 커밋·배포 빌드 → 백업·설치·실행 확인 → 검토. 기존 앱은 교체되지 않았다는 구현 보고와 로그가 있으며 사용자에게 적용 완료로 알리지 않는다. 푸시 대상 없음. 과거 개발 판정은 아래에 이력으로 보존한다.

---
# 검증 판정: 연결 재시작 단계 멈춤

## 3회차 — 개발 수정 검증 완료, 공개 반영 결정 대기
1. 개발 변경 판정: **완료**. 대상 `fd49c1de12d3328a956df118bac8ffd3e6e7a6fe`, 브랜치 role-workflow/30-f1c5ef47. 작업 전체의 공개 반영·푸시는 미완료다.
2. 검증 조건: **단일 모델**, 별도 구현 대화와 최초 계획·검토 대화. 제품 변경 3개와 보완 diff, handoff·impl-report, 실제 로그를 직접 확인했다. 미해결 제품 차단 지적 없음.
3. 설계 적합성(4.2): 기존 책임 안의 확인창 높이·키 대상·종료 처리, 단계별 문구, 응답 유실의 기존 job_status 조회가 AC를 충족한다. CM-38이 드러낸 확정 완료 후 추적 잔류를 고친 4줄은 기존 정상 완료 계약의 복원으로 수용한다. current.recent=false의 done에서만 추적·이전 입력을 종료하며 latest에서 얻은 결과는 계속 읽기 전용이다. 응답 유실을 현재 요청 성공으로 단정하지 않는다. 서버 계약·인증·저장 구조 변경 없음.
4. 증거: 아래 로그는 배정 worktree의 app/.build/connection-stuck-evidence/ 기준이다. 전체 앱 검사는 통과 로그를 재사용하고, 제품 보완에 영향을 받는 새 AC는 검토자가 다시 실행했다.

| 명령/확인 | 실제 결과 | 로그 |
|---|---|---|
| 검토자: python3 app/.build/connection-stuck-evidence/run-check.py planner-final-cs.log app/.build/app-tests --connection-stuck app/.build/connection-stuck-evidence | 종료 0, AT-CS-01~04 실제 AppKit·가짜 연결 통과 | planner-final-cs.log |
| 구현자: bash app/scripts/test.sh, 최종 로그 열람 | 종료 0, 빌드·HC/CM/FF·새 AC·전체 후속 fixture·hooks 9개·보존 검사 통과 | app-suite-completion-retry.log |
| 구현자: 연결 회귀 분리, 최종 로그 열람 | 종료 0 | completion-connections-pass.log |
| 개인값 검사, 최종 로그 열람 | 종료 0, 텍스트 지적 없음·바이너리 생략 | privacy-completion.log |
| 무변경 gate/Python 이전 증거 재사용 | Python 427개·AT-HF-22 통과. 당시 전체 명령 종료 1은 HC-26 실패이며 전체 통과로 바꾸어 보고하지 않음 | full-suite-short-temp.log |

5. V-CS-01~03 모두 해소. 증거 수준 1(빌드)·2(가짜 서비스)·3(실제 AppKit) 확보. 운영 화면의 정확한 대기 위치는 미확정이며 운영 재시작·설치는 범위 밖이다. 초기 AT-UC-32 실패는 보존됐고 무변경 분리/전체 재실행 통과를 확인했다. 해당 간헐성의 원인 규명은 이번 변경 완료 조건이 아니다.
6. 현재 명세: docs/spec/current/hejo-connections.md에 검증된 개발 동작을 반영했다. 공개판 적용 완료로 표시하지 않는다.

## 공개 반영 경계
- 읽기 전용 ls-remote 결과 공개 github/main은 `c880e52c15a5ffafb187f04d7236232e40a5af08`이다.
- 로컬 main은 개발 대상의 조상(종료 0). github/main 추적 tip과 실제 공개 tip은 개발 대상의 조상이 아니다(각 종료 1). 실제 공개 tip과 개발 대상의 merge-base도 없음(종료 1). 로그: planner-remote-check.log.
- 이번 3파일 변경만 공개 tip에 적용하는 읽기 전용 git apply --check는 TestMain.swift 문맥 차이로 종료 1이다. 로그: planner-public-patch-check.log. 공개 파일은 수정하지 않았다.
- 개발·공개 이력을 임의로 병합하거나 강제 푸시하지 않는다. 권고안은 현재 공개 main에서 별도 통합 작업 공간을 준비해 이번 수정만 이식하고 TestMain 등록을 기존 공개 시험과 함께 보존한 뒤 다시 빌드·회귀·개인값 검사를 수행하는 것이다. 사용자 결정 전 공개 후보나 pushTargets를 만들지 않는다.
- 계획 담당 원본의 작업 문서·현재 명세는 아직 미추적 상태다. 공개 반영 시 이번 문서만 선별하여 보존할 필요가 있다. 타 작업 파일은 포함하지 않는다.

---
## 이전 2회차 기록
# 검증 판정: 연결 재시작 단계 멈춤

## 2회차: 부분 완료
- 대상: 배정 worktree 브랜치 role-workflow/30-f1c5ef47, 커밋 `b10646760bf8424583db23b4ec4099ea18b03357`. 작업 상태 깨끗함과 변경 파일 3개를 직접 확인했다.
- 검증 조건: 단일 모델, 별도 구현 대화의 코드·보고서를 최초 계획 대화에서 검토했다. 제품 코드는 검토자가 고치지 않았다.
- handoff·impl-report·제품 diff·신규 시험·실행 로그를 직접 확인했다. 이전 V-CS-01(구현 미착수)은 해소됐다.

## 설계 적합성(4.2)
재시작 단계 표현, 시스템 인증과 앱 내부 확인창 처리 분리, 읽기 전용 job 조회, latest 결과의 상관관계 한계 표현, 창 종료와 늦은 응답 처리 방향은 요구·AC에 맞는다. 재시작 프레임은 직접/재개 경로의 기존 계약을 보존한다. 앱 내부 확인창을 preferredLevel에서 유지하고 인증 중에만 normal로 낮추는 수정은 가시성 목표에 부합한다.

다만 인계서가 AT-FF-22만 기대값 교체를 허용하고, 같은 내부 확인창을 검사하는 AT-HC-26의 normal 단언을 빠뜨렸다. tests/acceptance/HEJO-CONNECTIONS.md AT-HC-26 원본은 sheet·앱 모달 아님을 요구할 뿐 normal 레벨을 요구하지 않는다. 정상 UI를 기존 normal 단언에 맞추는 예외 분기는 필요하지 않다. 이는 요구 변경이 아니라 설계의 기존 경로 판정 누락이다.

## 직접 확인한 증거
아래 로그는 배정 worktree의 app/.build/connection-stuck-evidence/ 기준이다.

| 확인 | 결과 | 로그 |
|---|---|---|
| 검토자 직접 실행: python3 app/.build/connection-stuck-evidence/run-check.py planner-cs-review.log app/.build/app-tests --connection-stuck app/.build/connection-stuck-evidence | 종료 0. AT-CS-01~04, 직접/재개 timeout·끊김·조회, 실제 AppKit 이벤트·창 종료 통과 | planner-cs-review.log |
| 구현자 전체 실행 로그 직접 열람: bash scripts/test.sh | 종료 1. Python 427 passed, AT-HF-22, BUILD_OK, AT-HF-23 이후 HC-26 실패 | full-suite-short-temp.log |
| 연결 회귀 분리 로그 열람 | 종료 1. 같은 HC-26 실패 | connection-regression.log |
| 개인값 검사 로그 열람 | 종료 0. 바이너리 생략·텍스트 지적 없음 | privacy-final.log |

증거 수준 1(빌드), 2(가짜 통합), 3(실제 AppKit 창·클릭)을 확인했다. 렌더 캡처는 OS 전체 합성 화면이 아니며 가림은 창 순서·영역과 함께 검사한다. 운영 화면의 직접 원인을 확정한 증거는 아니다. 제품 시험은 해당 커밋에서 생성된 실행 파일로 직접 실행했으며 전체 재빌드는 중복하지 않았다.

## 차단 지적과 처분
**V-CS-02 / IMPL-CS-01 수용 — 설계 오류(요구 불변).** ConnectionsTests.swift의 AT-HC-26 normal 단언이 AC-02와 충돌한다. 기대값을 sheet 존재·앱 모달 없음·가시성·키 대상·선호 높이 유지로 교체하도록 design·handoff·수락 시험 보완절에 명시했다. 취소 continuation 완료와 시스템 인증의 normal 전환은 그대로 검사한다. 시험 삭제·skip·제품 예외 분기는 금지한다.

**V-CS-03 — 미실행 회귀 증거 보강.** HC-26에서 종료돼 기존 CM 및 후속 앱 fixture가 실행되지 않았다. V-CS-02 보완 후 bash app/scripts/test.sh를 끝까지 실행해 성공을 확인한다. Python/gate 변경이 없으면 통과한 427개·AT-HF-22 증거를 재사용한다. 새 AC는 앱 시험에 포함해 실행하고 실패는 그대로 보고한다.

## 남은 조건
구현 담당이 HC-26 구현 시험만 승인된 기준으로 교체 → 앱 전체 빌드·회귀·fixture 실행 → 변경 커밋과 impl-report 갱신 → 재검토. 제품 코드 추가 변경이 필요하면 영향과 이유를 보고한다. 현재 명세는 최종 통과 후 반영한다. 운영 재시작·실제 메시지·푸시 없음. 전체 완료 및 푸시 대상 제안은 보류한다.
