# 구현 보고 — HEJO-SMOOTH2-20261125

[설계 인계](handoff.md) v1의 개발 main 통합과 세 동작 계측. 위험도 일반, 필요 증거 수준 1·2·3. TASK-S2-01의 통합과 검증, TASK-S2-02의 빨리감기, TASK-S2-03의 계측과 방법 후보 정리를 완료했다. 프레임 간격의 미귀속 원인과 실제 사용자 환경에서의 재현은 미확정이다. TASK-S2-04는 사용자 결정 전 착수 차단이다.

이 문서의 증거 경로는 개발 worktree `../.worktrees/hejo-smooth-20261124`의 루트를 기준으로 한다. 별도 표기가 없으면 로그와 JSON은 그곳의 `app/.build/smooth2/` 아래에 있다.

## 통합과 다른 작업 보존

- 개발 브랜치는 깨끗한 `fc756976ff5e52ed7498fcfd8231a37f05fdc59f`에서 시작했다. 착수 시 `main`은 인계의 `431d0dd`보다 디스코드 문서 커밋 한 건이 앞선 `71ba68e`였다. 시험 중 디스코드 인계 문서 한 건이 더 들어와 `1ea45ff29dcab1225b9fbdbcf2fbc39abfc34e63` 기준으로 개발 worktree의 미커밋 병합만 취소하고 다시 병합했다. 두 업데이트 모두 앱·게이트·시험 코드를 바꾸지 않았다. 계획 담당 체크아웃의 디스코드 변경과 별도 worktree는 직접 편집하지 않았다.
- 통합 커밋 **`e54e1c70c3237c9d8662b019d8f959f56b8f19d8`**, 트리 `493e478eae5537bf96655ca25bc614779b643c5a`. 부모는 검증된 개발 커밋과 `1ea45ff`다. `app/`은 개발 커밋과 동일(AC-01). README, ARCHITECTURE, 텔레그램·사이드바 선택 문서, UI-CLEAN 판정 및 main에서 바뀐 모든 경로는 최신 main과 동일(AC-02). 개발 브랜치에만 있던 사이드바 통합 보고 사본은 main의 경로 상태를 따랐다.
- 작업 문서·수락 시험·현재 명세 37개를 지정 경로에서 복사했다(AC-03). 파일별 SHA-256과 커밋 blob을 대조했다. 상대 링크 검사에서 작은 JSON 검토 영수증 한 건이 빠진 것을 발견해 해당 작업 문서의 JSON 두 개를 함께 반영했다. 큰 원시 증거는 복사하지 않았다.
- 빨리감기 직전 65개 유입 경로를 검사했다. 수정된 추적 파일과 겹침은 0개, 겹친 미추적 파일 37개는 전부 유입 내용과 바이트 동일했다. 경로를 보존해 계획 담당 체크아웃의 `.build/smooth2-untracked-backup/`에 옮긴 뒤 `git merge --ff-only e54e1c70c3237c9d8662b019d8f959f56b8f19d8` 종료 0. 위 백업과 `ff-apply.json`의 이전 HEAD는 복구 근거이며 복구 실행은 사용자 승인 뒤에만 한다.
- AC-04. `ff-apply.json`과 `ff-after.json`에서 다른 작업의 변경 파일 8개 내용·모드, 남은 미추적 파일 2,867개 내용·모드, 옮긴 37개와 백업의 SHA-256이 일치한다. 실제 실행 시점의 인덱스 패치는 비어 있었다. staged patch 양쪽 SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, unstaged patch 양쪽 `664c97e9d358867d7299a8ccef7ea210a5ab2658b71980e87aedda7848ba857a`.

## 실행한 검사

| 명령 | 실제 종료 | 대상·로그 |
|---|---:|---|
| `git merge --no-ff --no-commit main` | 0 / 0 | `71ba68e` 시도 및 최종 `1ea45ff`. merge-71ba68e.log, merge.log |
| `git merge --abort` | 0 | 개발 worktree에서 첫 미커밋 병합만 취소. merge-abort-stale.log |
| `python3 app/.build/smooth2/prepare.py <계획 체크아웃>` | 0 | AC-01~03. prepare.log, candidate-tree.json, commit.json |
| `python3 app/.build/smooth2/links.py <계획 체크아웃>` | 최초 1 / 최종 0 | 변경 문서 상대 파일 링크 122개, 최종 끊김 0. links-initial.log, links.log |
| `<실행 환경 Python> scripts/scan_private.py --home <임시 홈>` | 0 | 최종 통합 트리의 개인값 검사. private-final.log |
| `bash scripts/test.sh` | 1 | Python 423 통과·기존 4 실패. checks/full.log |
| `bash app/scripts/test.sh` | 1 | 별도 실행에서 빌드·서명 통과 후 기존 `AT-UC-32 four word-only judgment buttons without image` 실패. checks/app.log |
| `python3 app/.build/smooth2/verify_candidate.py` | 0 | 시험 대상 app/gate/scripts/수락 시험을 통합 트리와 대조. 전체 두 명령의 실패 집합은 `fc75697`과 일치. verify-candidate.log, candidate-checks.json |
| `git commit -m 'Integrate verified hejo smoothness changes into development history'` | 0 | commit.log, commit.json |
| `python3 app/.build/smooth2/ff.py <계획 체크아웃> apply <통합 커밋>` | 0 | 내부 git 빨리감기 종료 0, AC-04. ff-apply.log, ff-merge.log, ff-after.json |

전체 시험은 HEJO-SMOOTH 인계 v4의 시험용 Python·실행 workspace와 짧은 임시 홈을 사용했다. 실행 뒤 바뀐 경로는 비시험 문서이며 시험 입력 트리는 통합 커밋과 일치한다. Python 실패의 정확한 ID는 candidate-checks.json에 있다. 기존 실패가 남아 있으므로 전체 시험은 통과로 기록하지 않는다.


## 세 동작 계측 — TASK-S2-03 / AC-06

통합 커밋의 추적 소스를 무시되는 작업 폴더에 복제했다. 제품 소스 쪽 관측은 모두 `HEJO_PERF_TESTING` 안에 있고 시험 진입점도 그 조건에서만 빌드했다. 계측 패치와 파일별 입력 해시는 `profile-only.patch`, `instrumentation-identity.json`, `profile-build/build.json`에 있다. 본 계측과 스택 표본은 서로 다른 실행이다. 임시 저장소·가짜 명부와 기존 현실 workload(8방 × 100스레드 × 4글, 글자 수 200/800/3000)를 썼으며, 생성한 fixture JSON이 동결 입력과 바이트 일치한다.

AppKit 기존 핸들러와 동기 레이아웃을 실행했다. 방 표본은 핸들러 호출부터 기존 fixture의 동기 레이아웃이 끝날 때까지다. 알림은 클릭 동작에 해당하는 `showChat` 호출부터 종료를 관측할 때까지이며, 실제 타이머 등록·종료와 관측 지연은 별도로 기록했다. 표본마다 준비 1회와 본 표본 5회, 표본 폐기 없음. 알림의 다섯 목적지는 기존 하네스의 서로 다른 분기이며 1번은 모아보기 분기다. 실제 사용자의 메시지나 네트워크는 사용하지 않았다.

주 스레드 CPU 시간은 `CLOCK_THREAD_CPUTIME_ID`, 경과 시간은 단조 시계로 관측했다. 중첩 구간에서는 가장 안쪽으로 계상해 중복을 제거했다. 전체에서 이름 붙은 구간을 뺀 시간은 미귀속으로 남겼다. 스레드 CPU 시간은 외부 렌더 서버의 CPU를 포함하지 않는다. 방 계측은 원래 하네스와 같은 화면 밖 AppKit 배치이고 강제 그리기는 넣지 않았다.

| 동작 | 경과 시간 5회(ms) | 주 스레드 CPU 5회(ms) | 경과 / CPU 중앙값(ms) |
|---|---|---|---:|
| 처음 보는 방 | 348.18, 339.75, 342.95, 340.50, 377.57 | 348.00, 339.44, 342.88, 340.29, 377.35 | 342.95 / 342.88 |
| 방 재방문 | 63.27, 63.08, 63.01, 62.48, 71.83 | 62.59, 63.03, 62.97, 62.27, 71.79 | 63.08 / 62.97 |
| 알림 창 전환 | 6406.78, 841.42, 574.89, 925.76, 576.44 | 6179.43, 672.67, 459.04, 747.23, 359.75 | 841.42 / 672.67 |

표본별 구간 합과 실제 전체의 최대 차이는 경과·CPU 모두 0초(기록 해상도)다. 미귀속 시간을 포함하는 등식이며 함수 귀속이 끝났다는 뜻은 아니다. 준비 표본 포함 원시 구간은 `profile-formal/intervals.json`, 동결 fixture는 `profile-formal/workload-frames.json`, 구간별 절대값·5회 통계·잔차는 `profile-analysis.json`에 있다. 표의 중앙값을 서로 더해 전체를 대신하지 않는다.

| 겹치지 않는 구간 | 처음 보는 방 CPU 중앙값(ms) | 재방문 | 알림 전환 |
|---|---:|---:|---:|
| 모델 파생값 | 3.253 | 2.822 | 3.598 |
| 카드/글 내용 조립 | 191.087 | 13.176 | 167.444 |
| 캐시 미스 본문 꾸미기 | 24.151 | 관측 없음 | 19.886 |
| TextKit 높이 | 76.679 | 관측 없음 | 238.407 |
| 표/카드/대화 배치 | 12.485 | 12.237 | 14.909 |
| 그리기 | 관측 없음 | 관측 없음 | 2.927 |
| 설정 저장 | 0.569 | 0.665 | 1.167 |
| 화면 갱신의 나머지 | 14.873 | 14.054 | 15.272 |
| 방 선택 핸들러 나머지 | 1.585 | 1.597 | 관측 없음 |
| 알림 핸들러 나머지 | 관측 없음 | 관측 없음 | 1.782 |
| 창 표시·배치 | 관측 없음 | 관측 없음 | 9.672 |
| 창 스냅샷 | 관측 없음 | 관측 없음 | 17.623 |
| 전환 준비 나머지 | 관측 없음 | 관측 없음 | 6.072 |
| 전환 단계 나머지 | 관측 없음 | 관측 없음 | 0.377 |
| 애니메이션 층 갱신 | 관측 없음 | 관측 없음 | 2.986 |
| 런루프 대기 구간의 CPU | 관측 없음 | 관측 없음 | 0.857 |
| 미귀속 | 18.663 | 18.571 | 147.683 |

### 어디에 시간이 들었는지

- **처음 보는 방.** 카드·글 조립 191.09ms가 가장 컸다. 이 중 `ConversationView.postPieces`의 다른 이름으로 분리되지 않은 부분은 183.79ms였다. 다음은 `NativeThreadCard.layoutSize`의 TextKit 높이 76.68ms, 계측한 본문 꾸미기 24.15ms다. `postPieces`의 자기 구간은 카드 내용 생성과 안쪽 관측이 없는 접기·본문 전처리·달력값·표시값 등의 호출을 포함한다. 어느 하나가 183.79ms 전체라는 근거는 없다.
- **재방문.** `ConversationView.chooseEmployee` 복귀 뒤 fixture의 동기 레이아웃 구간 전체는 29.81ms CPU였다. 겹치지 않는 분류에서는 미귀속 18.57ms가 가장 크다. 이름 붙은 구간은 `ConversationView.refresh` 나머지 14.05ms, 카드 조립 13.18ms, 표·배치 12.24ms 순이다. 배치의 가장 큰 함수는 `NativeThreadCard.layout()` 8.69ms였다. `LocalStore.save`는 경과 0.70ms, CPU 0.67ms여서 이 입력에서 주원인으로 보이지 않는다. 미귀속 내부의 AppKit 호출은 아직 특정하지 못했다.
- **알림 클릭부터 열림까지.** 전체 CPU에서 가장 큰 이름 붙은 구간은 `NativeThreadCard.layoutSize`의 높이 238.41ms, 다음은 카드 조립 167.44ms다. 높이 계산은 대부분 타이머 이전에 발생했다. 표본 1의 모아보기에서만 타이머 전 6.087초(높이 3.181초, `postPieces` 2.355초)가 걸렸다. 이 값은 모아보기 분기의 해당 관측이며 일반 방 여는 속도를 뜻하지 않는다.
- **알림 전환 중 끊김.** 실제 타이머부터 종료는 301~309ms, 최대 단계 간격은 67~74ms였다. 이번 계측 복제본에서는 이전 간격 기준을 만족한 표본이 0/5였다. 가장 긴 간격마다 58~71ms가 이름 붙은 함수와 런루프 대기 구간 바깥에 남았다. 같은 간격에 `GenieView.updateStrips`로 관측된 시간은 전부 0.27ms 이하였다. 따라서 열기 전 높이 비용과 열리는 중 끊김을 구분한다. 이번 측정의 목적은 구간 진단이며 설치된 공개판의 과거 4/5 판정을 재시험한 결과가 아니다. 미귀속에는 AppKit/합성 작업·스케줄 지연 등 가능성이 있고 정확한 함수는 확정하지 못했다. `transition-gap-analysis.json`에 타이머 전·타이머 후·최장 간격별 함수와 대기 시간을 따로 기록했다.

### 다음 단계에서 비교할 후보

| 동작 | 후보 | 달라질 수 있는 동작 |
|---|---|---|
| 처음 보는 방 | `postPieces` 안의 순수 전처리·달력값 의존을 더 세분해, 비용이 큰 부분을 처음부터 한 번만 계산 | 표시 시점과 모양은 유지할 수 있다. 최초 계산 자체가 필요한 값은 이득이 작을 수 있다. |
| 처음 보는 방 | 유휴 시간에 자주 열 방의 폭별 카드·높이 값을 제한적으로 준비 | 첫 클릭에 드는 계산이 유휴 시간으로 이동한다. 백그라운드 CPU·메모리와 사용자 입력 우선순위가 달라진다. |
| 처음 보는 방 | 첫 화면과 이동 목적지 우선 배치, 나머지 카드·높이는 필요할 때 계산 | 보이지 않는 카드의 배치 시점, 초기 스크롤 막대 길이 또는 이후 위치 보정이 달라질 수 있다. |
| 재방문 | 동일한 폭·글·표시 입력의 행 배치 결과를 재사용하고 변경 행만 다시 배치 | 맞는 무효화 기준이라면 표시 시점·저장 순서를 유지한다. 폭·테마·접기 상태 입력이 바뀌면 다시 계산한다. |
| 재방문 | 제목·컴포저·사이드바가 실제로 바뀐 경우만 AppKit 레이아웃 요청 | 화면 상태가 같을 때 반복 배치만 줄인다. 변경 판정이 빠지면 내용 표시가 늦거나 낡을 수 있다. |
| 알림 창 전환 | 창 패널을 올리기 전에 대상 카드·필요 높이를 제한적으로 준비하거나 재사용 | 클릭부터 첫 프레임까지 줄일 수 있다. 준비를 다른 때로 옮기면 자원 사용 시점이 바뀌고, 타이머 중 끊김은 별도 검증이 필요하다. |
| 알림 창 전환 | 단계 사이 미귀속을 AppKit 삽입점과 합성 제출 시점으로 더 좁힌 뒤, 확인된 부수 작업만 실제 종료 뒤로 이동 | 발견한 작업에 따라 초점·레이아웃·기타 갱신의 적용 시점이 늦어질 수 있다. |
| 알림 창 전환 | 원인이 단계 예약·프레임 제출 경합으로 좁혀질 때 현재 곡선의 시간 기반 단일 제출 경로를 시험 | 프레임 스케줄·첫 프레임 시점이 달라진다. 모양·총 길이 보존 여부는 별도 계약과 계측이 필요하다. |

권고: 최초 방에서는 `postPieces` 안쪽 호출을 먼저 분리하고, 재방문에서는 AppKit 배치의 외곽 시간을 확인한 뒤 같은 입력의 행 재사용을 검토한다. 알림은 프레임 간격의 미귀속을 좁히기 전 애니메이션 모양이나 길이 변경을 고르기 어렵다. 모두 다음 단계의 선택지다.

### 시험 및 계측 영수증

| 명령 | 실제 종료 | 원시 로그·판정 |
|---|---:|---|
| `python3 app/.build/smooth2/regress.py` | 0 | regression-command.log, regression/results.json, regression/revision.json. native 26/26. 최적화 시험 바이너리는 기존 빌드의 소스·옵션·컴파일러·실행 파일 SHA-256 검사가 모두 맞을 때만 재사용했다. |
| `python3 app/.build/smooth2/capture.py` | 0 | capture-command.log, capture-s2/results.json. 8/8 |
| `python3 app/.build/smooth2/network.py s2 app/.build/hejo-smooth/v6/regression-dates/build` | 0 | network-command.log, network-s2/results.json. 임시 loopback/hook 13/13 |
| `python3 app/.build/smooth2/compare.py` | 1 | compare.log, regression-comparison.json. 기준 독립 시험의 `ui-clean-polish` 실패가 이번 표본에서는 통과해 전체 독립 실패 집합의 엄격한 일치 판정은 실패했다. 새 실패는 없다. 의미 동결 58단계는 기준 관측 및 기댓값과 바이트 일치했다. |
| `python3 app/.build/smooth2/run_profile.py build` | 최초 1 / 최종 0 | profile-build-initial/compile.log, profile-build/compile.log. 첫 계측용 관측이 Swift if/else 사이에 삽입돼 실패했고 관측 위치만 고쳤다. 새 바이너리 입력과 SHA-256은 profile-build/build.json. |
| `python3 app/.build/smooth2/run_profile.py formal` | 0 | profile-formal-command.log, profile-formal/execution.json, intervals.json, transitions.json. 통합 커밋 기반 공식 계측. |
| `python3 app/.build/smooth2/analyze.py` | 0 | profile-analysis-command.log, profile-analysis.json. 동결 입력과 비교 후 CPU/경과 구간·합계 계산. |
| `python3 app/.build/smooth2/analyze-gaps-fast.py` | 0 | analyze-gaps-fast.log, transition-gap-analysis.json. 타이머 앞·뒤와 최장 간격별 경과 시간. |
| `python3 app/.build/smooth2/run_profile.py stack` | 제품 시험 0 / sample 0 | profile-stack-command.log, profile-stack/execution.json·stack.txt. 별도 25초 스택, fixture 준비가 섞여 있어 공식 시간의 비율로 쓰지 않았다. |
| `python3 app/.build/smooth2/transition_stack.py` | 시험 0 / 표본 6개 모두 0 | transition-stack-command.log, transition-stack/execution.json·run-*.stack.txt. 알림 분기별 준비 시작부터 1초 스택. |

**AC-05 대조.** 전체 Python과 앱 시험의 실패 집합은 이전 최종 개발 커밋과 동일하다. 독립 시험 47개 중 전부 통과했으나, 독립 `ui-clean-polish` 한 건은 이전 개발 기록에서 실패했다. 이전 반복 시험에서 같은 시험이 통과·실패를 오갔고 이번 전체 앱에서도 같은 AT-UC-32 단언이 실패했다. 어느 실패도 숨기거나 재표본으로 바꾸지 않았다.

분기별 알림 스택에서 `NativeThreadCard.layoutSize`, `ConversationView.postPieces` 및 Core Animation의 `CA::Transaction::commit` / `CA::Context::commit_transaction`이 관측됐다. 모아보기 1초 스택은 주로 준비 단계의 `postPieces`를 잡았다. 다른 분기에서는 레이어 제출도 관측됐지만 공식 표본과 별개여서 해당 최장 간격을 특정 Core Animation 호출로 귀속할 수 없다.

### 종료 범위

증거 수준 1(검증된 소스·빌드), 2(가짜 데이터와 임시 loopback), 3(실제 AppKit 계산·시간 관측)을 확보했다. 임시 계측 코드는 무시되는 복제본에만 있고 통합 커밋의 제품·시험 코드는 `fc75697`의 `app/`과 같다. 계획 체크아웃의 이 보고서는 인계서대로 원본에만 작성했으며 후속 작업에서 반영한다. 공개 저장소·설치 앱·서버·운영 설정·디스코드 worktree는 변경하지 않았다. 푸시 없음. 다음 단계는 이 자료를 검토하고 사용자가 개선 방식과 동작 변경 허용 범위를 결정하는 것이다.

## 04a·04b — 보완 인계 v2

### 제품 변경 전 04a 분해 계측과 수정 목록

기준 `e54e1c70c3237c9d8662b019d8f959f56b8f19d8`. 동일한 동결 workload에서 준비 1회와 본 표본 5회. 가장 안쪽 구간에 CPU를 한 번만 계상했다. 원시 로그는 개발 worktree `app/.build/smooth2-v2/` 기준이다. `run_profile.py build` 최초 종료 1(시험 관측 때문에 암묵적 return이 사라짐), 명시적 return을 넣은 시험 복제본 빌드 종료 0. `run_profile.py formal`과 최종 `analyze_subspans.py` 종료 0. `profile-build-initial/compile.log`, `subspans-build.log`, `subspans-run.log`, `profile-formal/intervals.json`, `subspans-analysis.json`에 보존했다. 완료 전 분석 시도 종료 1은 `subspans-analysis-pending.log`에 보존했다.

| 하위 구간 | 배타 CPU 중앙값(ms) | 본 표본 호출 수 |
|---|---:|---|
| `calendar_actions` | 143.595 | 100, 100, 100, 100, 100 |
| `display_time` | 37.634 | 100, 100, 100, 100, 100 |
| `body_styling` | 26.739 | 100, 100, 100, 100, 100 |
| `needs_folding` | 1.270 | 124, 124, 124, 124, 124 |
| `fold_preview` | 1.269 | 49, 49, 49, 49, 49 |
| `fitted_rules` | 0.993 | 100, 100, 100, 100, 100 |
| `conversational` | 0.837 | 50, 50, 50, 50, 50 |
| `strip_text` | 0.567 | 100, 100, 100, 100, 100 |
| `person_lookup` | 0.504 | 175, 175, 175, 175, 175 |
| `post_content` | 0.153 | 100, 100, 100, 100, 100 |
| `body_input_and_render` | 0.150 | 100, 100, 100, 100, 100 |
| `post_initializer` | 0.143 | 100, 100, 100, 100, 100 |
| `post_tail` | 0.130 | 100, 100, 100, 100, 100 |
| `appearance` | 0.109 | 100, 100, 100, 100, 100 |
| `palette` | 0.100 | 100, 100, 100, 100, 100 |
| `avatar` | 0.067 | 100, 100, 100, 100, 100 |
| `model_assessment` | 0.048 | 100, 100, 100, 100, 100 |
| `calendar_call` | 0.047 | 100, 100, 100, 100, 100 |
| `probe_and_body_lookup` | 0.035 | 100, 100, 100, 100, 100 |
| `thinking_path` | 0.034 | 100, 100, 100, 100, 100 |
| `folding_preview` | 0.034 | 100, 100, 100, 100, 100 |
| `streaming` | 0.027 | 100, 100, 100, 100, 100 |
| `speaker_name` | 0.025 | 75, 75, 75, 75, 75 |
| `speaker_palette_call` | 0.025 | 100, 100, 100, 100, 100 |
| `post_flags` | 0.024 | 100, 100, 100, 100, 100 |

`postPieces` 남은 자기 구간은 0.153ms로 AC-07의 20ms 이하다. 가장 큰 항목은 일정 버튼 143.595ms, 시각 표시 37.634ms였다. 수정 후보는 (1) 일정 버튼 경로에서 제거되는 링크 검출을 수행하지 않고, 일정이 없으면 동일한 빈 결과를 바로 계산, (2) 시각 표시의 ISO 날짜를 기존 날짜 파서 자원으로 처리할 수 있는지 검토다. 기존 현지화 표시를 다르게 할 수 있는 포매터 변경은 하지 않는다. 명부 색·이름·아바타 조회 비용의 합이 작아 새 재사용 키를 두지 않는다. 특히 그림 조회는 매번 유지한다. 파생값 상한·FIFO는 기존 값 그대로 유지한다. 달력 일정이 채워진 경우에는 날짜 해석과 일정 검색이 그대로 필요하므로 빈 입력의 측정만으로 그 비용을 없앴다고 판단하지 않는다.

### 04a 변경 및 표시 검증

- 제품 커밋 `01d08769acdfb800bd0a6b54beacb6df18bf014f`. `ConversationController.calendarActions`에서 일정이 없으면 빈 결과를 바로 계산한다. 일정이 있으면 기존의 `CalendarMatch.related`만 호출해 같은 이벤트 배열의 일정 버튼을 만든다. 원래는 같은 함수의 이벤트를 배열에 더한 뒤 링크 결과를 버렸다. 알림 말풍선의 링크 검출은 원래 경로에서 계속된다. 날짜 변환기·시각 표시·이름·색·아바타는 바꾸지 않았다. 새 재사용 값이나 키를 추가하지 않았고 기존 일정 버튼 FIFO 2,048개와 글·지역 달력·역할·대기 상태, 일정 목록 변경 시 무효화 규칙을 보존했다.
- 시험 커밋 `a9659d424b40184c65dd83c9794713ede2f7d616`. 같은 시험 파일을 기준 소스 사본에도 적용했다. 컴파일 옵션과 151개 Swift 입력 중 150개가 같고, 유일한 차이는 제품이 수정된 Controller다. `pair-source-comparison.json`과 양쪽 `pair-*-build/build.json`에 입력·실행 파일 해시를 보존했다.
- `python3 app/.build/smooth2-v2/check_scenes.py` 종료 0. 양쪽 전체 카드 대조(`AT-SM-02`)가 통과했고, 첫 방문 때 모든 표시 카드의 본문·속성·치수 스냅샷과 일정 장면 출력이 바이트 일치했다. `scene-comparison.json`, `base-scenes/`, `final-scenes/`, `base-cards/run.log`, `final-cards/run.log`. 일정 도착·삭제, 같은 글의 본문·시각·역할·전송 대기 상태 변경에서 기존 경로의 결과와 비교하고, 각각 이전 입력의 결과를 잘못 재사용하면 대조가 실패하는지 확인했다. 새 캐시 키나 프로필·날짜 경로를 만들지 않아 그것의 입력 제거를 위한 제품 변형은 없다.
- `bash scripts/test.sh` 종료 1. Python 423 통과, 기준과 같은 네 실패. `bash app/scripts/test.sh` 종료 0. 기준의 전체 앱 시험은 간헐적 AT-UC-32 실패로 종료 1이었다. 이번 앱 실행에 새 실패는 없지만 전체 실패 목록의 엄격 일치 조건을 충족하지 않았다. `checks/full.log`, `checks/app.log`, 기준 `app/.build/smooth2/checks/`. 첫 시험 때 기록한 트리는 제품 커밋이고 앱 빌드 전에 시험 파일만 추가했다. 추가 모드는 전용 실행 인자로 분리돼 있다.

- 독립 묶음 기록기 `regress.py`, `capture.py`, `network.py` 각각 종료 0. 하위 시험은 native 25/26, 캡처 8/8, 임시 loopback/hook 13/13. `ui-clean-polish`의 AT-UC-32만 종료 1이며 기준 e54 독립 묶음에서는 통과했다. 이전 기준 전체 시험에서 같은 단언이 실패한 기록은 유지한다. 의미 동결 58단계는 이전 e54 실측과 기댓값에 각각 바이트 일치한다. `regression/results.json`, `capture-s2/results.json`, `network-s2/results.json`, `compare-regression.log`와 `regression-comparison.json`. 엄격 실패 집합 대조가 일치하지 않아 비교 도구 종료 1(AC-09 부분 충족).

### 04a 교대 지연 계측

`python3 app/.build/smooth2-v2/pair.py run` 종료 0(AC-08). 같은 세션에서 기준 e54e1c7과 수정 a9659d4, 순서 AB/BA-AB/BA-AB, 각 5회. 각 실행은 준비 1회와 본 표본 1회다. 두 실행 파일에 같은 하네스를 적용했고 하위 구간 관측을 빼고 기존 HEJO-SMOOTH 관측만 유지했다. 원시 자료는 `pair-results/samples.json`, 각 실행의 `performance.json`, 요약은 `pair-results/summary.json`, 로그는 `paired-command.log`에 보존했다.

| 동작 | 기준 경과 중앙값(ms) | 수정 경과 중앙값(ms) | 기준 최대(ms) |
|---|---:|---:|---:|
| new_post | 32.3635 | 31.3678 | 37.6262 |
| notification_prepare | 45.2302 | 44.4975 | 46.2094 |
| pile_close | 30.5173 | 30.4914 | 35.3797 |
| pile_open | 34.7066 | 32.1407 | 39.2088 |
| receive | 38.0600 | 36.8553 | 38.7281 |
| room_first | 337.5872 | 192.3735 | 352.1237 |
| room_revisit | 60.5117 | 60.7063 | 62.4733 |
| select | 44.2824 | 35.0713 | 46.7158 |
| scroll | 0.0190 | 0.0191 | 9.3685 |

- 처음 보는 방 경과 5회(ms): 기준 334.861, 339.846, 352.124, 337.587, 333.147 / 수정 191.378, 191.531, 192.373, 194.709, 200.681. 중앙값 337.587 → 192.373ms.

- 처음 보는 방 주 스레드 CPU 5회(ms): 기준 334.805, 339.615, 351.896, 337.376, 332.944 / 수정 191.319, 191.511, 192.179, 194.673, 200.601. 중앙값 337.376 → 192.179ms.

처음 보는 방의 수정 경과 중앙값은 0.2초 이하다. 한 표본은 200.681ms였으며 표본을 빼지 않았다. 기준과 동일한 workload에서의 값이고, 일정이 있는 경로는 기존 달력 매칭 비용이 남는다. 승인 범위 안에서 유휴 미리 계산이나 방 재방문 전용 수정을 추가하지 않았다.

### 04b 알림 창 전환 원인 계측

`a9659d424b40184c65dd83c9794713ede2f7d616`에서 복제한 무시되는 소스에만 관측을 추가했다. `transition-source.py`, `run04b.py build`, `run04b.py run`, `analyze04b.py` 각각 종료 0. 대응 로그 `transition-source.log`, `transition-build/compile.log`, `transition-run.log`, `transition-analysis.log`. 실제 빌드 입력과 실행 파일 해시 `transition-build/build.json`, `transition-results/execution.json`, 전체 관측 diff `transition-only.patch`. 제품이나 저장소의 시험 코드는 04b에서 바뀌지 않았다.

준비 1회와 본 표본 5회. 동결 workload 바이트 일치. 두 순서의 CFRunLoopObserver로 각 단계의 시작과 끝을 기록하고 창 표시·갱신, 대화/이력/카드 배치·그리기, 전환 단계와 레이어 갱신, 명시적 CATransaction 제출과 완료 블록을 기록했다. 타이머 예정 시각은 Foundation의 fireDate를 단조 시계로 옮긴 값이고 콜백 실제 진입을 별도로 기록했다. 화면 주기 CVDisplayLink 설치와 시작은 6회 모두 성공했다. 화면 주기 신호는 물리 화면의 후보 갱신 시각이며 새 프레임이 그려졌다는 증거로 사용하지 않았다. 완료 블록은 앱에서 받은 시각이며 합성기의 실제 제출 시간으로 해석하지 않았다.

| 표본 | 최장 단계 간격(ms) | 대기 경계 사이(ms) | 간격 끝 타이머 지연(ms) | 화면 주기 신호 | 기존 구간 제외 미귀속(ms) | 추가 귀속률 | 남은 시간(ms) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 93.113 | 86.870 | 80.149 | 6 | 5.974 | 1.35% | 5.893 |
| 2 | 93.964 | 92.274 | 80.284 | 5 | 0.803 | 7.38% | 0.744 |
| 3 | 90.791 | 82.157 | 77.591 | 5 | 8.361 | 1.17% | 8.264 |
| 4 | 91.542 | 88.676 | 77.527 | 5 | 1.151 | 13.59% | 0.995 |
| 5 | 77.454 | 75.385 | 65.194 | 5 | 0.801 | 13.39% | 0.694 |

최장 간격 77~94ms 중 75~92ms가 `beforeWaiting` 후반에서 `afterWaiting` 초반 사이였고, 간격을 끝낸 시험 타이머의 보고된 지연은 65~80ms였다. 각 간격에 화면 주기 신호 5~6개가 있었다. 화면 갱신 신호가 멈춘 것이 아니라 시험 타이머 콜백 간격이 길어진 정황이다. 운영 환경에서 타이머가 왜 늦는지, 합성기가 어느 시각에 실제로 이전·새 프레임을 표시했는지는 미확정이다. 관측 빌드에서 이전 구간 계측보다 최장 간격이 길어졌고, 런루프·완료 콜백 관측 자체가 스케줄링에 영향을 줄 수 있다. 이전 S2-03의 미귀속 수치와 이 실행의 분모를 같은 표본처럼 직접 빼지 않았다.

AC-10의 **미귀속 80% 귀속은 미달**이다. 같은 새 표본에서 기존에도 이름을 붙일 수 있었던 작업과 대기 경계 사이를 먼저 제외했다. 추가 직접 관측과 같은 런루프 단계의 앞·뒤 관측으로 묶인 작업만 새 귀속으로 세었다. 남은 0.69~8.26ms는 주로 깨운 뒤 콜백까지 또는 소스 처리 경계 사이였다. 그 시간 전체를 타이머 또는 Core Animation에 중복 귀속하지 않았다. 표본별 겹치지 않은 구간 합은 실제 간격과 일치한다. `transition-results/trace-0.json`~`trace-5.json`에 원시 시간, `transitions.json`에 모든 단계 간격, `transition-analysis.json`에 미귀속·귀속 분할과 타이머 시각이 있다.

| 원인 후보 | 다음에 검토할 방법 | 달라질 수 있는 동작 |
|---|---|---|
| 앱 타이머 스케줄링/기동 지연 | 실제 설치와 같은 별도 정상 실행 환경에서 관측 부하를 낮추고 재확인한 뒤, Timer 발화 정책 또는 화면 주기 구동을 비교 | 최초/중간 프레임 제출 시점, 전력과 CPU 사용, 백그라운드에서의 애니메이션 처리 |
| 깨운 뒤 소스·블록 처리 | 최대 간격에 포함된 메인 큐 소스와 AppKit 이벤트를 더 좁힌 뒤, 확인된 부수 작업에 한해서만 다른 시점 검토 | 적용 시점이 바뀌는 초점·뷰 업데이트 등이 있을 수 있어 항목별 설계 필요 |
| 레이어 제출·합성 과정 | 화면 주기와 명시적 제출/완료에 시스템 추적을 연결해 병목이 합성으로 확인될 때 레이어 변경 수를 줄이는 후보 비교 | 실제 제출 프레임 수와 연속성, 이미지·그림자 등 모양이 동일한지 별도 검증 필요 |

필요 증거 수준 1·2·3을 확보했다. AC-07·08은 통과, AC-09는 표시·동결은 일치했으나 실패 집합 엄격 일치 미달, AC-10은 계측과 한계 보고 완료 및 80% 목표 미달이다. 개발 브랜치의 두 커밋만 만들었다. 개발 main 통합·공개판·설치 앱·서버·운영 설정·디스코드 작업 공간 및 푸시는 이번 단계에서 수행하지 않았다.

## v3 — 전환 구동·개발 통합·공개 반영

착수 기준은 개발 브랜치 `a9659d424b40184c65dd83c9794713ede2f7d616`(깨끗함), 계획 체크아웃 `2b0946d90fc2c5cf8bb407047e356bdaeed5279f`, 공개 원격 main `27e0e95fab5de0294ae925c188bb50f5ba361411`(ls-remote 종료 0)이다. 위험도 일반, 요구 증거 1·2·3. 개발 증거는 `../.worktrees/hejo-smooth-20261124/app/.build/smooth2-v3/` 아래에 둔다.

- 제품 커밋 `dba95860128463bd8a266aaef27507855cab2eeb`. `PetTransitionClock`이 기존 전환 Timer의 소유 자리와 진행 중 판정을 맡는다. macOS 14 이상 Window display link와 약참조 target, macOS 13 CoreVideo 링크와 링크가 보유하는 약참조 상자를 쓴다. 상자는 주 스레드에서 단계가 끝날 때까지 추가 작업을 하나만 허용한다. 창 display link는 창이 있는 화면을 따르며 CoreVideo는 화면 변경 알림에서 재지정한다. 화면이 없거나 CoreVideo 시작·재지정이 실패하면 기존 60Hz Timer를 사용하고 진단에 경로를 남긴다.
- 반전·완료·끌기·화면 설정 갱신·소멸에서 기존 구동을 정리한다. 반전 때 진행률 유지, 첫 main.async 단계, 기존 진행률·총 길이, 동작 줄이기, 스냅샷과 배치는 그대로다. 펫 이동·미리보기 등 다른 타이머는 같은 코드로 남았다.
- 시험 커밋 `3999dba497ae708d5a3e06cea3ce480b149f99dc`. AC-11용 무화면 대체 경로, 멈춘 콜백, 반전, 종료, 동작 줄이기와 실제 화면의 교대 계측 시작점. 비교 A·C는 a9659d4 소스 사본에 같은 하네스와 시험 전용 경로 기록만 사용했다. C에서만 전환 중 latencyCritical/userInitiated와 tolerance 0을 적용한다. 해당 비교용 코드는 제품 커밋에 없다.
- 숨김 메뉴가 `orderOut`을 직접 호출하는 경로를 확인해 제품 커밋 `9d2789243c9c5e01ac40cf3b3e5375cc0f867523`에서 macOS 14 이상 백엔드를 현재 화면의 display link로 바꿨다. 화면 변경 때 이전 링크를 무효화하고 세대로 이전 콜백을 차단한다. 시험 커밋 `b8045667aa2a2b1ad54e1e36aa9118f05ebfe15c`는 패널을 숨겨도 진행 중인 닫기가 끝나는지 확인한다. 처음 Window 백엔드의 전체 앱 빌드는 소스 갱신과 겹쳐 종료 1(`window-link-checks/app.log`). 검증은 소스를 고정한 화면 백엔드의 새 실행을 사용한다.

`runner.py build A/B` 각각 종료 0(`build-A.log`, `build-B.log`, 양쪽 build.json). 배포 대상 macOS 13으로 두 화면 구동 분기가 컴파일됐고 실행 호스트 macOS 27.2에서는 NSScreen 경로를 밟았다. `runner.py unit` 종료 0(`unit/run.log`), `HEJO_S3_DRIVER_PASS screen_display_link`. macOS 13의 실제 CVDisplayLink 실행·다중 화면 이동은 이 호스트에서 미검증이다.

최종 후보 `b8045667`에서 `bash scripts/test.sh` 종료 1(423 통과, 기준 Python 4건 실패), 별도 `bash app/scripts/test.sh` 종료 1(빌드·서명 후 기존 AT-UC-32 단언). 보호 검사 통과. `screen-checks/full.log`, `screen-checks/app.log`. 실행 환경 Python 개인값 검사 종료 0(`screen-checks/private.log`).

### S2-06 교대 계측과 채택 결정

`python3 app/.build/smooth2-v3/runner.py frames` 종료 0(모든 계측 완료). 실제 화면 패널에 붙은 본 표본 한 실행당 준비 1회 후, 갈래마다 5개를 집계했다. 대체 Timer로 판정에서 제외한 B·D 표본은 0개다. 모든 50ms 초과 간격을 그대로 넣었다.

| 갈래 | 최장 간격 5회(ms) | 중앙값(ms) | 총 시간 중앙값(ms) |
|---|---|---:|---:|
| A 기준 세 갈래 세션 | 75.53, 102.41, 46.75, 46.12, 75.39 | 75.39 | 336.88 |
| B 화면 주기 | 32.94, 38.52, 46.99, 41.01, 49.43 | 41.01 | 315.33 |
| C 타이머+지연 제어 | 50.64, 71.90, 63.29, 125.49, 87.67 | 71.90 | 339.06 |
| A 기준 조합 세션 | 84.64, 31.67, 82.55, 82.84, 48.62 | 82.55 | 324.42 |
| D 화면 주기+지연 제어 | 53.98, 39.91, 47.65, 48.77, 45.50 | 47.65 | 308.27 |

B·D 모두 25ms 기준 미달이므로 화면 드라이버와 관련 시험을 되돌리고 일정 버튼 개선만 반영한다. 별도 지연 제어도 채택하지 않는다. B의 최장 간격은 5회 중 4회가 전환 시작부터 첫 단계까지였고, 이후 화면 간격은 대체로 16.67ms에 모였다. 첫 단계 제출 시점을 변경해 통과시키지 않았다. `frames.log`, `frames/{samples,summary}.json`, `frames-combined/{samples,summary}.json`과 각 실행의 `transitions.json`, `execution.json`이 원시 근거다. 화면 주기 후보의 별도 카드·의미·동작 교대 시험은 채택되지 않아 진행하지 않고, 되돌린 실제 반영 코드의 나머지 검증으로 이어간다.

### S2-05a 개발 main 반영

전환 제품·시험 네 커밋의 되돌림 `970bffa97e04ed84d790d751e842252dbfe642a4`, `git revert --no-commit` 및 커밋 종료 0(`revert.log`). 검증된 일정 버튼·시험의 `a9659d4`와 앱·게이트·스크립트·시험 트리가 동일하다. `git merge --no-ff --no-commit main` 종료 0, 검사 뒤 통합 커밋 `2861fcd74cfca44d0a3b72bdfee7434b7426c076` (main 부모 `9bf18368873135c79ab0b9763da365f7ead5dd33`, `merge-main.log`). 추가된 main 문서는 다른 작업의 커밋이며 수정하지 않았다.

통합 커밋에서 `bash scripts/test.sh` 종료 1(423 통과, 기준과 같은 Python 4건), `bash app/scripts/test.sh` 종료 0, 개인값 검사 종료 0. `integrated-checks/{full,app,private}.log`, `integrated-acceptance.json`. 의미 동결·전체 카드·비회귀 교대 시험은 위 v2에서 시험한 코드와 정확히 같다.

계획 체크아웃에서 `git merge --ff-only 2861fcd74cfca44d0a3b72bdfee7434b7426c076` 종료 0. 유입 파일 두 개, 추적 수정·미추적 겹침 모두 0개, 옮긴 파일 없음. 이번 보고 1개와 다른 작업 9개를 합친 추적 변경 10개의 해시와 남은 미추적 파일 해시·모드를 검사했다. staged patch SHA-256 전후 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, unstaged patch SHA-256 전후 `17f3dee77b2bd135fda65e216ba3208276dda15a17719c740fc9d89d5210abd7`(이번 보고의 단계별 기록 포함). `ff-preflight.log`, `ff-apply.json`, `ff-merge.log`, `ff-after.json`.

### S2-05b 공개 이식과 재검증

공개 worktree `../.worktrees/hejo-smooth-public-20261124`, 새 브랜치 `hejo-smooth2-public-20261125`. `git ls-remote --exit-code github refs/heads/main` 종료 0으로 `27e0e95fab5de0294ae925c188bb50f5ba361411`을 재확인했다. `git switch -c` 및 두 커밋 cherry-pick 종료 0. 제품 `abc4ba0c5541d3b72886e7ce25700e3f805e9f19`, 시험 `4eeb260aed473d9d55d9873a777e6f2375d876ae`, 검증·배포 빌드 대상 `4c10c825dbe7bdd0746b3ab33efbca81bb69662e`. 공개판 전환·레이아웃에 손으로 옮긴 변경은 없었다. 공개 기준과 제품 차이는 ConversationController 일정 구간 하나다. 계획 문서 섹션을 복사해 별도 커밋했고 27개 상대 링크를 확인했다. 이번 공개 로그는 공개 worktree `app/.build/smooth2-v3-public/` 기준이다. `public-tip.log`, `switch.log`, `cherry-pick.log`, `docs-commit.log`, `relative-links.log`.

기존 공개 v7 로그는 그때 시험한 `e745466`과 현재 공개 기준 `27e0e95` 사이 앱·게이트·스크립트·수집되는 Python 시험 입력이 같음을 확인하고 사용했다(`reference-equivalence.log`, git diff 종료 0). 새 공개 후보의 `bash scripts/test.sh` 종료 1은 두 버전에서 같은 기존 Python 4건(각 423 통과)이다. `bash app/scripts/test.sh` 종료 1은 기준·후보 모두 시험과 임시 통합 fixture 완료 뒤의 같은 설정 메타데이터 보호 단언이며 앱 시험 본문은 통과했다. 운영 설정의 값을 열거나 바꾸지 않았다. 실행 환경 Python 개인값 검사 종료 0. `final-full/full.log`, `final-full/app.log`, `final-full/private.log`, `public-assess.log`.

기준·후보에 같은 시험 파일·빌드 옵션. 양쪽 최적화 시험 빌드 종료 0, Swift 156개 중 제품 Controller만 다르다. `verify_public.py semantic A B` 및 `cards A B` 종료 0. 의미 동결 58단계가 양쪽 모두 기대 바이트와 일치했고 전체 카드 대조도 통과했다. `semantic.log`, `semantic/*/observed.json`, `cards.log`, `cards-*/run.log`, 양쪽 build.json. `verify_public.py bench A B` 종료 0. 같은 세션 각 5본 표본, 제외는 준비뿐이다. 아래 시간은 ms이고 기준 최대는 비회귀 상한이다.

| 동작 | 기준 중앙값 | 후보 중앙값 | 기준 최대 |
|---|---:|---:|---:|
| new_post | 32.677 | 32.737 | 34.033 |
| notification_prepare | 45.746 | 44.100 | 47.769 |
| pile_close | 30.790 | 30.681 | 31.528 |
| pile_open | 34.006 | 33.143 | 35.377 |
| receive | 38.217 | 37.671 | 39.819 |
| room_first | 338.608 | 194.952 | 339.410 |
| room_revisit | 61.510 | 61.175 | 61.926 |
| select | 43.462 | 36.367 | 46.388 |
| scroll | 0.019 | 0.019 | 13.953 |

- 공개 A 첫 방 원시 5회(ms): 334.176, 330.195, 338.608, 338.649, 339.410.

- 공개 B 첫 방 원시 5회(ms): 194.952, 208.693, 193.205, 194.183, 196.990.

`nonregression/samples.json`, 표본별 `performance.json`, `nonregression/summary.json`, `bench.log`. `public-assess.py` 종료 0. 직전 원격 main 읽기 및 그 후손인지 검사도 종료 0(`pre-install-tip.log`).

### S2-05c 배포 빌드·로컬 설치

공개 검증 대상 `4c10c825dbe7bdd0746b3ab33efbca81bb69662e`에서 정상 배포용 `bash app/scripts/build.sh` 종료 0. 기존 무시된 배포 빌드 입력과 고정 Sparkle을 사용하고 시험 옵션을 쓰지 않았다. 설치 전후 버전 0.2.7 / 빌드 9을 유지했다. Google·업데이트 구성 키의 존재, 기존 리소스 13개의 바이트 동일성, 서명 종료 0, BuildInfo의 `dirty=false` 및 트리 `5c36badb84a17e4657fa6b6b3e3c38f4bd88f77b`와 해당 커밋 일치를 확인했다. 입력 값은 열람·출력하지 않았다. `install/normal-build.log`, `normal-command.log`, `install/candidate.json`, `install/resource-compare.json`.

`python3 app/.build/smooth2-v3-public/public-install.py` 종료 0. 실행 중이던 앱의 서명과 해시를 다시 확인하고 `app/.build/smooth2-v3-public/install/backup/hejo.app`(공개 작업 공간 기준)에 기존 앱을 새로 백업했다. 서명과 파일 manifest 검증 뒤 앱만 정상 종료하고 같은 설치 파일시스템에서 교체했다. 정상 재실행 뒤 실행 경로와 실제 바이너리의 해시가 후보와 일치한다. 표준 메뉴로 대화 창을 열어 창이 표시됨을 확인했다. 메시지는 전송하지 않았다. 운영 서버·설정은 변경하지 않았다. `install/install-command.log`, `install/installed.json`, `install/lifecycle.local.json`, `install/backup-manifest.json`.

| 설치 증거 | SHA-256 |
|---|---|
| 기존 및 백업 실행 파일 | `3294cc8a443f6dde7cad127510a0689d2bc547ef34a566b0f41e615be94dcec9` |
| 후보 및 설치 실행 파일 | `20bbb3a29868c67839b21290f8497e89b9074e20f20243a0c0bddc15f0cad4ed` |
| 기존 백업 번들 manifest | `3f4f9cbe46ae93861c0723e46eb24ac0dc9945d857532eb6683d2a43a42e2f82` |
| 후보 및 설치 번들 manifest | `50ea49e2ab01c2d8cc5f8343b28d4272b79fd944e27c1262562ee17d3b335d9d` |

복구는 미실행(교체 성공). 필요하면 새 앱을 정상 종료하고, `install/transaction-paths.local.json`이 가리키는 같은 파일시스템의 보존 원본을 원래 설치 경로로 되돌린다. 또는 위 백업을 같은 설치 파일시스템에 준비해 manifest·서명 대조 뒤 되돌린다. 정상 재실행과 기존 실행 파일 해시를 확인한다. 강제 종료나 운영 자료 복원은 하지 않는다. 실제 절대 경로는 추적하지 않는 로컬 영수증에만 있다.

이 보고서를 공개 작업 공간에 문서 전용 후속 커밋으로 반영한다. 설치 영수증의 커밋은 실제 빌드에 사용한 위 커밋이며, 후속 문서 커밋에서 앱·시험·게이트·스크립트의 내용은 같다. 공개 main의 후손임을 읽기 확인했다. 설치 후 사용자의 체감 확인과 플러그인 푸시 승인은 계획 담당 단계에 남아 있다.

## v4 — 화면 주기로 대화 창 전환 구동

개발 브랜치 `hejo-smooth-20261124`에서 `2861fcd74cfca44d0a3b72bdfee7434b7426c076`을 기준으로 `git revert --no-edit 970bffa`를 실행했다(종료 0, `revert.log`). 재채택 커밋은 `0c60efaa8d305fd789b4c896d0907e12721b2776`다. `git diff --exit-code b804566 HEAD -- app gate scripts tests` 종료 0. 전환 구동을 화면 주기에 맞추고, 동작 줄이기 설정, 처음 단계 즉시 실행, 진행률과 전환 길이, 다른 애니메이션을 유지했다. 제품에서 절전 해제 호출이나 Timer 허용 오차 지정이 없음을 확인했다.

아래 개발 로그는 개발 작업 공간의 `app/.build/smooth2-v4/` 기준이다. 교대 계측에는 동일한 경우별 Swift 입력, 컴파일러와 옵션, 실행 파일 해시를 확인한 기존 최적화 시험 빌드를 사용했다. 기준 빌드의 시험용 절전 실험 스위치는 양쪽에서 껐다.

### TASK-S2-07 개발 검증

| 명령 | 종료 | 로그와 결과 |
|---|---:|---|
| `python3 runner.py unit` | 0 | `unit.log`. AC-11 통과, `unit/run.log` |
| `python3 runner.py frames` | 0 | `frames.log`. AC-12 v4 통과, `frames/samples.json`·`frames/summary.json` |
| `python3 verify_driver.py bench A B` | 1 | `bench.log`. AC-13 첫 세션 8/9, `nonregression/samples.json`·`nonregression/summary.json` |
| `python3 verify_driver.py semantic A B` | 0 | `semantic.log`. 기대 58단계와 기준·후보 모두 바이트 일치, `semantic/*/observed.json` |
| `python3 verify_driver.py cards A B` | 0 | `cards.log`. 전체 카드 대조 양쪽 통과, `cards-*/run.log` |
| `bash scripts/test.sh` | 1 | `checks/full.log`. 기준 실패 집합 동일 4건이며 423 passed |
| `bash app/scripts/test.sh` | 1 | `checks/app.log`. assertion("AT-UC-32 four word-only judgment buttons without image") |
| `실행 환경 Python scripts/scan_private.py` | 0 | `checks/private.log`. 통과 |

| 전환 표본 | 기준 최장 간격 ms | 후보 최장 간격 ms | 기준 총 시간 ms | 후보 총 시간 ms |
|---|---:|---:|---:|---:|
| 1 | 59.390 | 51.753 | 317.434 | 318.047 |
| 2 | 37.583 | 37.607 | 305.222 | 309.677 |
| 3 | 51.665 | 42.713 | 303.437 | 313.810 |
| 4 | 46.088 | 39.877 | 309.463 | 303.931 |
| 5 | 35.353 | 46.273 | 302.784 | 316.015 |
| 중앙값 | 46.088 | 42.713 | 305.222 | 313.810 |

실제 화면에서 양쪽 각 5회, 매 실행의 준비 1회만 제외했다. 기준 5회 모두 `timer_baseline`, 후보 5회 모두 `screen_display_link`였다. 후보의 최장 간격 중앙값은 기준보다 작았고 총 시간 중앙값은 기준 +17ms 이하였다. macOS 13 CoreVideo와 실제 다중 화면 이동은 미검증이다(TD-S2-01).

비회귀 첫 세션에서 글 묶음 펼치기의 후보 중앙값 32.653ms가 기준 최대 32.529ms를 넘었다. 나머지 8개는 기준을 충족했다. 묶음 펼치기가 실행되는 시험 fixture는 전환 컨트롤러를 생성하지 않는다. 타이밍을 제외한 묶음 펼치기 계수는 10개 표본에서 동일했다. 이 첫 실패와 원시 표본을 보존했다.

동일 기준 바이너리 대조의 묶음 펼치기 기준 5회(ms) 31.668, 32.488, 34.807, 32.716, 32.365, 상대 5회(ms) 32.398, 31.874, 33.092, 31.301, 35.244. 각 동작 판정은 `nonregression-identical-binary/summary.json`, 실행 종료 값과 요약은 `repeatability.json`·`repeatability.log`에 있다.

독립 A/B 재현의 묶음 펼치기 기준 5회(ms) 31.343, 31.195, 31.840, 31.389, 34.039, 상대 5회(ms) 31.595, 34.932, 31.561, 33.414, 32.202. 각 동작 판정은 `nonregression-replication/summary.json`, 실행 종료 값과 요약은 `repeatability.json`·`repeatability.log`에 있다.

| 동작 | 기준 중앙값 ms | 기준 최대 ms | 후보 중앙값 ms | 판정 |
|---|---:|---:|---:|---|
| `new_post` | 32.033 | 34.544 | 32.500 | 통과 |
| `notification_prepare` | 43.661 | 46.589 | 45.028 | 통과 |
| `pile_close` | 30.019 | 32.790 | 30.820 | 통과 |
| `pile_open` | 31.389 | 34.039 | 32.202 | 통과 |
| `receive` | 36.928 | 39.294 | 37.470 | 통과 |
| `room_first` | 194.205 | 194.803 | 192.307 | 통과 |
| `room_revisit` | 60.031 | 60.407 | 60.215 | 통과 |
| `select` | 35.213 | 41.297 | 35.656 | 통과 |
| `scroll` | 0.019 | 10.543 | 0.020 | 통과 |

동일 바이너리 대조의 열 번은 SHA-256이 하나였고 답변 수신은 37.740ms 대 기준 최대 37.163ms로 판정선을 넘었다. 실제 후보를 쓴 독립 교대 시험에서는 모든 동작이 원래 기준을 충족했다. 첫 결과는 미달로 유지하고 재현 시험과 대조 증거를 함께 검토해 개발 반영을 진행했다. `check_repeatability.py` 기록기는 종료 0, 동일 바이너리와 독립 재현의 하위 판정은 각각 1·0이다.

### TASK-S2-08 개발 main 반영

개발 작업 공간에서 `git merge --no-ff --no-commit main` 및 통합 커밋 종료 0. `merge-main.log`, `candidate-tree.json`. 통합 HEAD는 `8cfa49a4810f9cc0f5debbab1d2341a2349b7af3`다. `git diff --exit-code 0c60efa HEAD -- app gate scripts tests` 종료 0. 같은 해시의 시험 바이너리로 통합 뒤 AC-11을 실행해 종료 0(`integrated-test.log`, `integrated-unit/run.log`). 전체 두 명령의 대상 입력도 통합 전 시험과 동일하다.

계획 체크아웃은 `c1086738ee16b6b967019c8e1ec900bdf2c5a621`에서 위 통합 커밋으로 빨리감기했다. 들어올 경로 7개, 기존 추적 변경 또는 미추적 파일과 겹치는 경로 0개. `git merge --ff-only` 종료 0. 전후 작업 파일 해시·미추적 목록·스테이징 및 미스테이징 패치 해시가 동일하다. `ff-preflight.json`, `ff-apply.json`, `ff-merge.log`, `ff-after.json`. 옮긴 파일은 없다.

### TASK-S2-08 공개 통합과 검증

로그는 공개 작업 공간의 `app/.build/smooth2-v4-public/` 기준이다. 후보 브랜치 `hejo-smooth2-public-20261125`에서 `eb68ac320bf177b999c10028662cd95565517b29` 위에 `dba9586`·`3999dba`·`9d27892`·`b804566`의 순변경을 한 커밋 `15861e286059932154c4a32bab1608f38278f0af`으로 이식했다(종료 0, `port.log`·`port-commit.log`). 공개판 `PetController.swift`의 기존 창 배치·다시 열기 기준점·웹 패널 조정은 유지했다. 전환 구동을 교체한 추가·삭제 행은 개발판과 같고, `PetTransitionClock.swift` 전체는 개발판과 바이트 동일하다. `TestMain.swift`의 새 시험 분기도 양쪽이 같고 공개판의 다른 분기는 유지했다. `port-equivalence.json`·`clock-equivalence.log`. 시험 커밋은 `b5d89ba84f5315d6356ebdf1dc984722b3c695f9`이다.

| 명령 | 종료 | 결과와 로그 |
|---|---:|---|
| `python3 runner.py build A` | 0 | `build-A.log`. 타이머 기준 시험 빌드. 동일한 하네스와 시험 전용 경로 라벨을 사용 |
| `python3 runner.py build B` | 0 | `build-B.log`. 화면 주기 후보 시험 빌드 |
| `python3 runner.py unit` | 0 | `unit.log`. AC-11 |
| `python3 runner.py frames` | 0 | `frames.log`. AC-12, `frames/samples.json`·`frames/summary.json` |
| `python3 verify_driver.py bench A B` | 0 | `bench.log`. AC-13, `nonregression/samples.json`·`nonregression/summary.json` |
| `python3 verify_driver.py semantic A B` | 0 | `semantic.log`. 의미 동결 58단계, `semantic/*/observed.json` |
| `python3 verify_driver.py cards A B` | 0 | `cards.log`. 전체 카드 대조, `cards-*/run.log` |
| `bash scripts/test.sh` | 1 | `final-full/full.log`. 423건 통과·기존 4건 실패. 직전 공개 후보와 실패 집합 동일 |
| `bash app/scripts/test.sh` | 1 | `final-full/app.log`. 실패 집합은 직전 공개 후보와 같다 (Real settings metadata changed) |
| `실행 환경 Python scripts/scan_private.py` | 0 | `final-full/private.log`. 통과 |

실제 화면 각 5회에서 최장 단계 간격 중앙값 76.888 → 42.895ms, 총 전환 시간 중앙값 329.968 → 313.204ms였다. 경로 기록은 기준 `timer_baseline`, 후보 `screen_display_link`다. 각 5회 원시 기록은 `frames/samples.json`. AC-12 v4 통과.

| 동작 | 기준 5회 최대 ms | 후보 5회 중앙값 ms | 판정 |
|---|---:|---:|---|
| `new_post` | 36.014 | 32.202 | 통과 |
| `notification_prepare` | 46.467 | 45.162 | 통과 |
| `pile_close` | 31.595 | 30.047 | 통과 |
| `pile_open` | 33.131 | 31.872 | 통과 |
| `receive` | 39.097 | 38.122 | 통과 |
| `room_first` | 202.663 | 193.590 | 통과 |
| `room_revisit` | 67.062 | 60.052 | 통과 |
| `select` | 35.861 | 35.327 | 통과 |
| `scroll` | 9.421 | 0.019 | 통과 |

`python3 public-integrity.py` 종료 0. 실제 Swift 입력 156·158개와 두 실행 파일의 SHA-256, 작업 트리 청결, 시험 커밋과 제품 입력 동일성, `git ls-remote` 및 `merge-base --is-ancestor`로 공개 원격 `github/main`의 빨리감기 가능 여부를 확인했다. 원격 tip `27e0e95fab5de0294ae925c188bb50f5ba361411`. `integrity.log`·`integrity.json`.

격리 환경의 개인값 검사 종료 0. 평소 명부·목록 기준으로 같은 검사기를 실행하면 종료 1이며 기존 명부 28건과 목록 2건을 표시했다. 표시된 파일은 모두 공개 원격 tip과 바이트 동일하며, 이번 이식 파일과 보고서의 새 지적은 0건이다. `report-private.log`·`report-private-delta.json`. 기존 파일은 이번 작업 범위 밖이다.

### TASK-S2-08 재설치

첫 설치 확인에서 대화 창은 열렸지만 Escape 입력 뒤 편집기가 그대로 보였고 접기 관측이 시간 초과했다. `python3 public-install.py` 종료 1. 자동 복구에서 새 앱을 정상 종료한 뒤 이전 앱을 복원·실행했고 서명과 기존 해시 `20bbb3a29868c67839b21290f8497e89b9074e20f20243a0c0bddc15f0cad4ed` 일치를 확인했다. `install/install-command.log`·`install/restore.json`. 복원한 이전 앱에서 펫 버튼의 접근성 동작을 보내고 창 축소·편집기 숨김을 확인한 뒤 같은 서명된 배포 후보로 다시 시도했다. 접근성 응답 코드와 실제 끝 상태를 각각 기록했다(`install-retry/previous-app-ax-fold.log`).

정상 배포용 `bash app/scripts/build.sh` 종료 0. 시험 빌드 옵션 없이 프로젝트의 기존 배포 입력을 사용했다. 새 앱의 서명 검증 종료 0, `BuildInfo` 트리 `701c29b79e7f622b53278bfc42824783fdbeb11d`와 시험한 커밋 `b5d89ba84f5315d6356ebdf1dc984722b3c695f9` 연결을 확인했다. `install/normal-build.log`·`install/candidate.json`.

`python3 public-install-retry.py` 종료 0. 이전 `4c10c825dbe7bdd0746b3ab33efbca81bb69662e` 앱을 새 위치 `app/.build/smooth2-v4-public/install-retry/backup/hejo.app`에 복제하고, 원본과 백업 파일 해시·서명 일치를 확인했다. 실행 파일 SHA-256은 설치 전 `20bbb3a29868c67839b21290f8497e89b9074e20f20243a0c0bddc15f0cad4ed`, 설치 후 `1c727a9922389522ddcea625af34483eb9e13167cd71002ce182911f0ddc258f`이다. 백업 번들 목록 SHA-256은 `50ea49e2ab01c2d8cc5f8343b28d4272b79fd944e27c1262562ee17d3b335d9d`. 정상 종료와 교체·재실행을 확인했고 경로와 해시가 배포 후보와 일치했다. 대화 창 열기 → 접기 → 다시 펼치기의 끝 상태를 창 크기와 편집기 접근성 식별자로 확인했다. `install-retry/installed.json`·`install-retry/install-command.log`·`install-retry/lifecycle.local.json`.

복구할 때는 현재 hejo를 정상 종료하고 서명 검사를 통과한 백업 번들을 설치 위치와 같은 디렉터리의 임시 경로에 복제한다. 현재 번들은 별도 이름으로 보존하고 백업 복제를 설치 위치로 옮긴 다음, 서명과 이전 실행 파일 SHA-256을 확인하고 앱을 연다. 실제 이름은 로컬 `install-retry/transaction-paths.local.json`, 백업 목록은 `install-retry/backup-manifest.json`에 있다. 성공한 두 번째 교체를 되돌리는 복구는 필요하지 않았다.

필요 증거 1·2·3과 로컬 설치·실행 확인을 남겼다. 실제 대화에서 전환이 얼마나 부드러운지 사용자 확인은 남았다. macOS 13 CoreVideo와 여러 화면을 오가는 전환은 실물 미검증이다. 공개 푸시는 사용자 화면 승인 단계가 남았다.

푸시 검토 대상은 공개 통합 브랜치 마지막 보고서 커밋의 제품·시험 트리이며, 원격 이름은 `github`, 대상 브랜치는 `main`이다. 보고서 반영 전 시험·설치 커밋의 전체 해시는 위에 기록했다. 최종 후보의 전체 해시와 원격 확인 결과는 인계 기록에 남긴다.
