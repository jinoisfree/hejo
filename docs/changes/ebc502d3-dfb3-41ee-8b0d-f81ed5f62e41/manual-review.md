# 실제 입력 비교 진행 기록

사용자가 격리 시험 창을 직접 조작해 확인하겠다고 응답했다.

## 기준판
- 제품 기준: 6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0.
- 실행: 구현 worktree의 app/.build/pet-baseline-root가 가리키는 보존 기준판에서 `bash app/scripts/pet-position-manual.sh`.
- 실제 실행 핸들: exec session 61917. PET_POSITION_MANUAL_READY 출력 확인. 시작만 확인했으며 종료 코드·보호 검사·사용자 관측은 아직 없음.
- 이 실행은 자동 손 입력을 주입하지 않는다. 사용자 직접 개폐·드래그 관측을 기다린다. Control-Q로 종료한다.

## 수정판
- 대상 acf168c6999d74c91e9f54d4c8bbed0c4705614d. 기준판 확인 종료 뒤 순차 실행 예정, 아직 미실행.

## 다음 확인
기준판 종료 출력과 보호 검사 결과, 생성된 events.jsonl을 확인하고 개인값 없는 증거만 보존한다. 같은 화면·출발 조건으로 수정판을 실행하여 개폐 위치 변화·드래그 추종·놓은 뒤 튐을 비교한다. 운영 앱은 종료하거나 변경하지 않는다.

## 기준판 사용자 관측과 종료
사용자는 “테스트 펫 잘 작동된다”고 답했다. 이는 기준판에서 체감 문제가 재현되지 않았다는 관측이며 수정판 합격이 아니다. 기준판 시험 프로세스 신원/부모를 확인하고 SIGTERM으로 종료했다. wrapper 종료 코드 1, 설정 메타데이터 guard 실패, 다운로드 guard 통과. 운영 앱 변경·복원 없음. 좌표 증거와 요약은 logs/manual-baseline-user-events.jsonl 및 manual-baseline-user-summary.json. 설정 오염 없음 판정은 확보하지 못했다.

## 수정판 실행 시작
대상 acf168c6999d74c91e9f54d4c8bbed0c4705614d, 구현 worktree에서 `bash app/scripts/pet-position-manual.sh` 실행. exec session 87616, PET_POSITION_MANUAL_READY 확인. 사용자 직접 관측과 종료 검사는 대기 중이다.

## 기준판 입력 범위 분석
보존 JSONL 직접 분석: 펼침 상태 전환 5회, 열린 상태 drag 입력 405개, 닫힌 상태 20개를 확인했다. 상태가 바뀐 직전/직후 두 레코드의 sprite 차이는 각 전환에서 0이었다. 이것만으로 전환 전체 프레임 불변이나 모든 화면 위치의 결함 부재를 증명하지 않는다. 분석 원본은 logs/manual-baseline-coverage.json. 수정판 session 87616을 poll하여 계속 실행 중임을 확인했다.

## 사용자 확인 대기 재확인
수정판 exec session 87616 및 시험 프로세스 8171 실행 중을 직접 확인. 현재 JSONL에는 startup 1개와 frame 4327개만 있으며 마우스 입력 이벤트가 없다. 수정판 실입력 결과와 사용자 관측을 확보하지 못했다. 연속 목표 진행에서도 같은 사용자 확인 대기가 지속되어 자동 반복은 차단 상태로 전환하되 시험 창은 유지한다. 사용자 확인 후 같은 세션의 증거를 수집하고 후속 통합을 진행한다.

## 수정판 사용자 결과
사용자: “드래그 잘된다 근데 펫이 채팅창 내부로 가는 문제가 있다.” 첨부 화면에서 겹침 확인. logs/manual-fixed-user-events.jsonl에 실제 입력 보존, manual-fixed-user-summary.json에 교차 사례와 입력 수 집계. session 87616은 해당 시험 PID를 확인한 뒤 SIGTERM 종료. wrapper exit 1, 설정 guard 실패/다운로드 guard 통과. 손 입력 대기는 끝났고 겹침 결함 보완 단계로 전환한다.

## 겹침 수정판 재확인 준비
2026-11-24, 수정 소스 `5865aa6c6554f80d81dfbb5646f1c8dcdda539f6`. `bash app/scripts/pet-position-manual.sh --probe-fixtures --probe-duration 2` exit 0, 서랍/로컬 비영속 웹/입력 포커스 및 두 보호 검사 통과. 실제 손 입력 증거가 아니다. 이어서 옵션 없는 wrapper로 사용자 시험창 실행, READY 확인. 사용자 관측 및 종료 후 보호 검사는 대기 중이다.

## 위·아래 배치 요구 재확인
사용자는 5865aa6 시험에서 펫이 채팅 옆에 떨어져 있는 배치를 거절하고, 채팅 위쪽에 걸쳐 있거나 아래쪽에 있어야 한다고 명확히 했다. 실제 입력 로그에서 위/아래가 아닌 펼침 프레임을 별도 집계했다(logs/manual-lateral-review.json). 기존 시험 PID 44202를 명령 확인 후 TERM 종료했다. wrapper exit 1, 설정 guard 실패, 다운로드 guard 통과. 기존 비중첩 시험 합격은 이 수직 배치 요구의 합격이 아니다. 7판에서 좌우 후보를 제거하고 수직 위치 단정을 추가했다.


## 최종 사용자 실물 확인 — 2026-11-24
대상 `8df04a02f57ae1f3e07292969c52925724101e9b`. 사용자가 최종 시험창에 대해 “e됫다 만족함”으로 수락했다. 위쪽 헤더 걸침 또는 아래 배치와 드래그에 관한 사용자 재확인 대기는 해소됐다. 해당 시험 PID와 실행 명령을 확인한 뒤 시험 프로세스만 SIGTERM 종료했다. wrapper 종료 코드 1, 설정 metadata guard 실패, 다운로드 guard 통과. 사용자 수락과 보호 검사 실패를 구분한다. 로그는 logs/pet-vertical-user.log, 입력 사건 수집 요약은 logs/manual-vertical-user-summary.json에 기록했다.
