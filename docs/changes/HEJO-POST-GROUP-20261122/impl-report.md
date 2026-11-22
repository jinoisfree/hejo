# 구현 인계: HEJO-POST-GROUP-20261122 TASK-01

1. **받은 설계:** [handoff.md](handoff.md), spec 2판·design 1판·수락 시험 2판. 기준 `84e64ac3bcd50c71e2bae3e720b76d84d57a9212`, 계획 2회차 APPROVED. 일반 위험도, 필요한 증거 수준 **2 + 빌드 1**, 연합개발. [확인] 착수 HEAD `302b0c6`의 대상 코드·기존 참조 시험은 설계 기준과 같았다. 다른 작업의 커밋은 보존했다.
2. **구현자 판단:** 구현·자체 시험 완료, 최종 검토 대기. 최종 완료 판정과 푸시 승인은 남았다.
3. **책임·흐름:** `ConversationView.threadContent`에서 타임라인 바로 앞 답글의 화면 표시 여부·직원 일치를 계산한다. `postPieces`는 그 결과를 기존 `Post.continuation`·시간 도움말·생각 중 조각 생성에 적용한다. 묶음 상태를 저장하지 않는다.
4. **변경:** `app/Sources/ConversationView.swift`의 답글·입력 중 표시 조건과 버튼 나눔 앞부분의 인자 전달을 수정했다. `app/Tests/PostGroupTests.swift`를 추가하고 `app/Tests/TestMain.swift` 기본 실행에 한 줄 등록했다. 기존 경로 철거는 없으며 NativeThreadCard·gate·hub·운영 홈·다른 앱은 수정하지 않았다. 기존 시험 기대값은 바꾸지 않았다.
5. **설계 차이:** 없음. 입력 중 끼어듦 시험은 private 상태를 직접 쓰지 않고 임시 루프백 대역에 실제 전송하여 상태를 만든다. 대역 확인 프레임으로 임시 사장 에코만 해소한 뒤, 마지막 답글이 같은 직원인 전제를 먼저 검사한다.
6. **덧대기·임시 제품 코드:** 없음. 기존 표시 책임·필드를 재사용했다. 시험용 로컬 서버와 mutation 사본은 검증에만 쓰며 제품 경로에는 없다.
7. **변경 성격:** 표시 의미 변경. 같은 직원의 연속 답글은 첫 이름 아래 이어지며 작업 줄은 유지한다. 사장·다른 직원·숨은 답글이 사이에 있으면 새 이름을 표시한다.

## 추가 시험과 결함 검출

기대값은 [수락 시험 2판](../../../tests/acceptance/HEJO-POST-GROUP.md)을 그대로 옮겼다. 임시 LocalStore·MemoryCredentials·가짜 alpha/beta 명부와 실제 ConversationView 조각을 사용한다. 답글 3개 이상은 기본 펼침이며 검사 전에 stack 없음 확인, AT-PG-05는 정확한 접힘 목록을 먼저 확인한다.

| 시험 | 보호하는 계약 |
|---|---|
| AT-PG-01 | 파일 다음 같은 직원 답의 이름 머리 중복 방지 |
| AT-PG-02 | 사장·다른 직원이 답글 묶음을 끊음 |
| AT-PG-03 | top과 첫 답글의 경계 보존 |
| AT-PG-04 | 접힘·펼침에 따른 바로 앞 답글의 표시 여부 반영 |
| AT-PG-05 | 숨은 beta·alpha 각각을 건너뛰어 묶지 않음 |
| AT-PG-06 | 버튼 나눔 앞·뒷부분 모두 이어짐 |
| AT-PG-07 | 파일 글 뒤 입력 머리 생략, 작업 줄 유지 |
| AT-PG-08 | 답글 없음·사장·다른 직원·끼어듦·복수 입력자의 이름 머리 구분 |
| AT-PG-09 | 연속 생각 중 조각 생략, 사장 뒤 생각 중 머리 보존 |
| AT-PG-10 | 생각 중 이름 아래 다음 답글 이어짐 |
| AT-PG-11 | 묶인 글 시간 도움말과 체크박스 도움말 우선순위 |
| AT-PG-13 | 파일→typing→생각 중→streaming edit→final edit 각 단계 이름 1개·작업 줄 수·시간 도움말 |

[확인] Mutation은 추적 소스를 수정하지 않고 `.build/post-group-evidence/ConversationView.swift` 사본에만 주입했다. 대조 실행은 종료 0, 아래 세 결함은 모두 종료 1로 검출했다. 기존 시험 삭제·통합 없음.

| 주입한 결함 | 실제 실패 |
|---|---|
| 답글 묶음 비활성화 | AT-PG-01 file then text |
| 입력 머리 생략 제거 | AT-PG-07 no duplicate typing head |
| 바로 앞 답글의 화면 표시 확인 제거 | AT-PG-04 folded last starts group |

## 실행 증거

로컬 증거 폴더 `E = .build/post-group-evidence/`(저장소 기준, 추적하지 않음). `P`는 Hermes venv Python이며 실제 경로·의존 경로는 `E/environment.json`에 있다. 기존 로컬 pytest·team-kit 의존 경로를 재사용했고 Unix 소켓 길이 제한을 피하도록 짧은 임시 HERMES_HOME·HERMES_ROOT·TMPDIR와 pytest basetemp를 썼다. 운영 설정·비밀 파일은 입력하지 않았다.

| 명령·대상 | 실제 종료 코드·결과 | 증거 |
|---|---|---|
| 첫 `HEJO_PYTHON=P bash scripts/test.sh` | **1**, pytest 모듈 경로 누락, 시험 미실행 | `E/test-env-initial.log`, `E/test-env-initial.exit` |
| 같은 명령, 위 로컬 의존·임시 경로 환경 | **0**, 434 passed·경고 1개, gateway clean, 앱 빌드·서명, AT-PG-01~11·13, 기존 앱·네트워크 fixture·hooks 9개 전부 통과 | `E/test.log`, `E/test.json` |
| `P scripts/scan_private.py`(임시 홈·빈 가짜 명부) | **0**, AT-PG-12 개인값 검사 | `E/private-initial.log`, `E/private-initial.json` |
| `python3 E/mutation.py` | **0**, 사본 컴파일·서명·대조 실행 0, 결함 세 실행 각각 1 | `E/mutation.py`, `E/mutation.diff`, `E/mutation-*.log/json` |
| `git diff --check -- <자기 경로>` | **0**, 공백 오류 없음 | 커밋 전 직접 확인 |

[확인] 전체 시험 중 조사 대상 소스 변경 0(`E/test.json`의 `changedDuringRun=[]`). 개발 앱 빌드는 시험 스크립트가 실행한 것이며 별도 정상 배포·설치 빌드를 실행했다고 주장하지 않는다. 기존 Swift 동시성·사용하지 않는 값·SDK 경고는 남았고 새 시험 파일 경고는 없다. 실제 CLI 설정 메타데이터·Downloads 이름 보존 guard도 통과했다. 필요한 증거 수준 **2 + 1**에 도달했다.

## 남은 범위와 검토 인계

- [미실행] 운영 앱 화면·실제 직원 작업 확인(수준 4, 완료 조건 아님), 운영 앱 설치·게이트웨이 재시작·실제 외부 메시지·푸시.
- 범위 밖 기술 부채: 새로 발견한 항목 없음. 다른 작업의 미추적 문서 폴더를 보존했으며 지정된 Connections 두 파일은 수정·커밋하지 않았다.
- 검토 요청: 접힘의 타임라인 인접 조건, 생각 중에서 edit로 바뀌는 단계별 머리 수, 버튼 나눔 앞부분과 도움말 우선순위를 확인한다. 최종 검토자는 실제 diff·시험·증거를 읽고 `verdict.md`를 작성한다.
- 코드 커밋: `aacf1686f8b361c08340d07434403918750be793`(main). 시험 바이트와 커밋 바이트 일치는 `E/tested-commit.json`. 변경 세 파일의 커밋 바이트·현재 바이트·전체 시험 시작 바이트가 같다. 작업 위치는 현재 hejo 저장소, 원격 이름은 `github`이며 원격 쓰기는 하지 않았다.
- 보고서 포함 최종 개인값 검사·자기 경로 diff 검사 결과는 `E/private-final.log/json`, `E/diff-final.log/json`으로 인계한다. 보고서까지의 최종 커밋은 실행 역할 상태 블록에서 전달한다.
