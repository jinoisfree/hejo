# 구현 인계 · HEJO-WAIT-JITTER TASK-01

- 설계는 [handoff.md](handoff.md), 명세 5판과 설계 2판을 따른다. 위험도 일반, 운영 모드 교차 모델, 필요 증거는 실제 AppKit 3과 설치 앱 4다.
- `base_commit`은 `2237bf5af5773aeb50c72be7c3d8945ec391cc17`이다. `git fetch github` 후 `7540da1`과 `f116bdc`가 각각 `github/main`의 조상임을 확인했다.
- 공개 작업 트리는 `../.worktrees/hejo-wait-jitter-public-20261125`, 브랜치는 `hejo-wait-jitter-public-20261125`다. 증거는 이 작업 트리의 `.build/wait-jitter/` 기준이다.

## 기준 코드 대조

`NativeThreadList.apply`에서 일반 끝 거리와 기록 모드 기준점을 선택하고, 두 `keep`이 각각 0·0.06·0.2·0.4초 지연 복원을 예약한다. 같은 방의 연속 `apply`에서 이 예약을 무효화하는 세대는 없다. 선행 작업으로 기록 모드의 기하가 같을 때 이미 `keep`을 건너뛰며, 새 답글 확인의 `outgoingReplyAnchor` 및 로드 뷰포트 안정화 분기가 추가됐다. 기록 모드 끝 기준점의 `allowAtEnd` 예외와 보내기 확인 위치는 보존 대상이다. `ConversationView.refresh`는 대화와 왼쪽 목록을 함께 갱신하며, 일반 왼쪽 목록은 ID 변화나 높이 변화 시에만 재배치를 호출한다. 지연 복원 경쟁과 일반 목록 위치 변동은 실행으로 확인할 가설이다.

## 사용자 원본 영상 대조

사용자 첨부 영상은 640×416, 11.408초다. 30fps 회색조로 다시 표본화하고 고정 영역의 평균 절대차가 가장 작은 세로 변위를 구했다. 대화 영역은 프레임 16·17에서 −11/+11px, 왼쪽 목록은 프레임 156·157에서 −7/+7px였다. 각 시점에 헤더·입력창·창 왼쪽 경계·바탕화면 대조 영역의 변위는 0px였다. 두 영역에서 별개로 관측되는 위치 왕복이며, 원인 코드의 위치는 이 영상만으로 확정할 수 없다. `source-motion.c`와 `source-motion.tsv`는 로컬 증거다.

## 기준 실행 및 원인 관측

- `base-results/`에 진단 코드를 넣기 전 구간별 별도 실행에서 정착시킨 원점과 1/60초 관측값을 보관했다. 예를 들어 일반 모드의 끝 거리 0pt에서는 2개 구간에서 각각 1회 반전했으며 이동 폭은 44pt였다. 시험의 34pt 답하는 중 줄과 카드 내부 10pt 간격을 합친 문서 높이 변화다. 기준 `ConversationView`의 AT-WJ-06·07에서는 줄 좌표와 원점 변화가 0pt였다.
- 기준 동작을 유지한 채 진단만 덧댄 하네스에서, 동일 사건 2번의 일반 모드 복원이 `2814 → 2858 → 2814` 순서로 반복됐다. 높이 변화 직후 남아 있는 위치 보정과 그 적용 전 원점을 다시 읽은 위치 보정이 서로 다른 끝 거리를 적용한다. 기록 모드의 끝 여백 2.5pt에서는 AppKit 콜백에서 `2811.5 → 2810.5`, 기준점 복원에서 `2810.5 → 2811.5`가 확인됐다. 스트리밍이 끝날 때의 추종 방향 반전도 정해진 입력에서 관측했다.
- 진단 전용 앱을 따로 빌드해 실제 연결의 1:1 대화 경로에서도 확인했다. `trace/live-before.jsonl`에서 사건 14의 끝 거리 보정이 `930.12 → 1189pt`를 적용한 뒤, 사건 13에 예약된 기준점 보정이 `1189 → 930.12pt`로 돌렸고, 사건 14가 다시 `1189pt`를 적용했다. `NativeThreadList`의 두 지연 보정이 같은 갱신에서 경쟁하는 원인이다. 왼쪽 목록의 실물 원인은 별도로 확인 중이다.
- AT-WJ-05 하네스는 두 번 시도했다. 클릭과 키는 후속 실행에서 입력으로 각각 30pt 이동했고 이후 0pt였다. 휠은 시험 프로세스로 합성 이벤트를 배달했지만 기대한 원점 이동이 관측되지 않았다. AT-WJ-05a를 통과로 세지 않는다.

## 수정과 자체 시험 진행

- `NativeThreadList.swift`에서 글 기준점과 끝 거리 보정을 한 예약 경로로 합쳤다. 기하가 바뀌면 첫 보정을 다음 스냅숏 전에 적용하며 지연 보정은 새 갱신·리더 입력·명시적 이동·진입에서 무효화한다. 재측정 동안은 현재 원점과 실제 문서 경계를 쓰고, 스트리밍 축소 중에는 사라질 높이를 따라 올라가지 않는다. 줄 높이 변경도 실제로 바뀐 행만 AppKit에 전달한다.
- `ConversationView.swift`에는 왼쪽 행 좌표·측정 높이·재배치 호출의 진단을 추가했다. 기준 하네스와 실제 질문 대기 구간에서 같은 행의 되튐이 재현되지 않아 왼쪽 동작 자체는 추정으로 바꾸지 않았다. `ThreeTapDiagnostics.swift`는 기존 파일에 이벤트 줄을 쓴다.
- `app/Tests/WaitJitterTests.swift`에는 AT-WJ-01~07, `wait_jitter_trace.py`와 `wait_jitter_trace_test.py`에는 다섯 지표와 AT-WJ-08b 대조를 추가했다. `WaitJitterTargets.json`의 목표 오프셋은 기준 소스로 사건 갱신만 한 번씩 적용하고 각 구간을 0.5초 동안 정착시켜 얻었다. 이전 구간의 잘못된 실측 원점을 다음 구간의 기준으로 옮기지 않는다. 원본 로그는 `reference-targets/`에 있다.
- 첫 후보의 AT-WJ-01~07은 전부 통과했다. 실제 AppKit 휠, 클릭, 방향키에서 입력 이동은 각각 30pt, 이후 원점 변화는 각각 0pt였다. AT-WJ-08의 다섯 지표는 0이고 기록을 끈 재실행에서 켠 로그의 해시는 그대로였다. 이때 AT91도 통과했다. 이 결과는 명시적 검색 이동 보호를 넣기 전 후보의 결과다.
- 첫 후보의 AUTOLOAD 회귀에서 69개 중 3개가 실패했다. `regression/ald-explicit.jsonl`에서 검색 `scroll_to`가 `5974 → 0pt`를 적용하는 동안 새 갱신의 끝 거리 복원이 `0 → 5974pt`를 적용했다. 명시적 `scrollTo`의 재시도·애니메이션 중에는 일반 위치 보정과 그 보정의 뷰포트 예약을 보류하도록 수정했다. 기준판의 연관 9개는 모두 통과했다. 최신 후보를 별도로 검증한다.
- `HejoSmoothTests`의 `check`는 같은 실행 조건에서 기준판과 첫 후보 모두 `AT-SM-02 card height stream completion`에서 멈췄다. 시험과 기대값을 유지했다. `bash scripts/test.sh`도 두 실행에서 같은 5개 게이트 시험이 실패해 앱 단계에 도달하지 않았으며, 별도 앱 시험으로 확인했다.

## 공개 후보 검증

코드 후보는 `5ba45e83d442cdea9a96260dd67dcbd183f4d7b3`이다. `git commit --only`로 앱과 시험 9개 경로를 커밋했다. 명세·기존 시험 기대값에는 손대지 않았다.

| 실행 | 결과 | 증거 |
|---|---|---|
| 후보 Swift 시험 바이너리 빌드 및 `app-tests --wait-jitter` | 종료 0. AT-WJ-01~07 전체 통과. AT-WJ-05a·b·c 모두 30pt 입력 이동, 이후 0pt | `verification/build.log`, `verification/enabled.log` |
| `python3 app/Tests/wait_jitter_trace.py <기록> --harness`, `python3 app/Tests/wait_jitter_trace_test.py` | 각 종료 0. 다섯 지표 모두 0, AT-WJ-08b 정상·결함 13개 판정 일치 | `verification/verdict.json`, `verification/controls.log` |
| 진단 없이 `app-tests --wait-jitter ... --trace-subset`, `shasum -a 256 -c` | 각 종료 0. 시험 통과, 진단 로그 미변경 | `verification/disabled.log`, `verification/disabled-trace.log` |
| `app-tests --task40` | 종료 0. AT91 통과 | `verification/at91.log` |
| `pytest app/Tests/HistoryAutoloadFixture.py gate/tests/history_transport_app.py` | 종료 0. 명시적 이동 보호 수정 후 69개 통과. 이 실행 뒤 기록 전용 필드와 하네스 입력 전달 보강을 추가했다 | `regression/history-final.log` |
| `app-tests --hejo-smooth check`, `app-tests --hejo-smooth transitions` | `check`는 기준·후보 둘 다 종료 1, 같은 `AT-SM-02` 단언. 후보 `transitions` 종료 0 | `regression/smooth-base.log`, `regression/smooth-final.log`, `regression/smooth-transitions.log` |
| `bash scripts/test.sh` 기준·후보 비교 | 각각 종료 1. 561개 통과, 같은 5개 게이트 시험 실패 | `regression/base-standard.log`, `regression/candidate-standard.log` |
| `python3 scripts/scan_private.py`, `git diff --check` | 커밋된 후보 개인값 검사 종료 0, 변경본 공백 검사 종료 0 | `regression/private-final-scan.log`, 셸 출력 |
| `bash app/scripts/build.sh`, `codesign --verify --deep --strict` | 종료 0. 커밋과 빌드 소스 트리 일치. A의 기존 Google 메타데이터를 보존해 재서명했다 | `build.log`, `build-config.log` |

## 설치 및 AT-WJ-09

- A는 `/Applications/hejo.app`, B는 Mac 공용 폴더의 `Shared/hejo/hejo.app`이다. 설치 전에 기존 앱을 종료하고 A·B의 원본을 각각 `rollback/A/hejo.app`, `rollback/B/hejo.app`에 보관했다. 원본·사본의 버전과 바이너리·Info.plist SHA-256이 각각 일치했다. 두 곳을 순서대로 교체하고 새 빌드와의 해시 및 코드 서명을 확인했다. `install.log`, `rollback/manifest.txt`, `rollback/installed.json`.
- 설치된 A에서 1:1 대화를 열어 내부 확인 메시지를 보냈고, 제출 후 두 번째 휠까지 22.181초를 기다렸다. 녹화는 29.967초, 두 휠로 맞춘 시각 오프셋 차는 16.667ms다. 적용한 영역과 배율은 `installed/regions.json`과 `installed/geometry.json`에 있다.
- 최초 판정 시 휠 직후의 지연 AppKit 원점 이동을 판정기가 휠과 연결하지 못했다. A·B를 각자 보관본으로 복원했고 원래 해시와 일치함을 확인한 뒤 A를 실행했다. `AT-WJ-09.log`, `restore.log`, `restore.exit`.
- 같은 영상과 기록을 다시 분석해 두 휠 입력 후 8ms·14ms에 기록된 같은 뷰의 원점 이동을 확인했다. 대화 영상의 후보 한 건(336·344번 프레임)은 30fps 프레임 사이에 들어온 연속 원점 변화와 각각 −45.48px·−11.05px로 대응했다. 두 구간 모두 같은 `scroll_to` 이동으로 설명됐다. 왼쪽 후보 0건, 설명되지 않는 영상 후보 0건, 기록 판정 다섯 값 모두 0이다. `installed/verdict-frame-spans.json` 및 종료 0 로그.
- 같은 영상 검출기를 사용자 원본에 적용했을 때 대화 12건, 왼쪽 1건을 잡았다. 후보 집계는 이번에 사용한 고정 영역의 결과다. `source-conversation.tsv`, `source-sidebar.tsv`, `video-motion.c`.
- 재분석 뒤 복원된 원본과 보관본 해시를 다시 확인하고, 증거를 만든 동일한 빌드를 A·B에 다시 설치했다. 두 대상의 해시·코드 서명이 일치하며 A의 평상시 실행과 창 표시를 확인했다. `reinstall.log`. 진단 환경 변수는 녹화 실행에만 설정했다.

## 인계 판단

구현·자체 시험을 마쳤다. 도달 증거 수준은 AppKit 하네스 3 및 설치 앱 실물 4다. 계획 담당이 공개 후보를 교차 검토할 때 실제 답글 대기 영상의 유일한 후보와 `scroll_to` 기록 대응, 왼쪽 목록 재현 범위, 기존 HejoSmooth 실패를 확인하면 된다. 왼쪽 목록의 과거 흔들림 원인은 별도로 특정하지 못했다. 공개 `github/main`은 `2237bf5af5773aeb50c72be7c3d8945ec391cc17`이며 이 후보의 조상이다. 푸시 승인 대기다.
