# 펫 변경 공개판 통합

사용자는 최신 공개판 변경을 보존하고 이번 펫 변경만 통합하는 방식을 승인했다. 공개 기준은 `dbc512be27804fa5b0dd36507eabc069b93f1293`, 원본 개발 결과는 `8df04a02f57ae1f3e07292969c52925724101e9b`, 공개 제품 통합 커밋은 `7db94ee0fb4220525dbcf5072ee79668a9f9a63c`이다.

별도 공개 브랜치 `role-workflow/25-ebc502d3-public`을 공개 기준에서 만들었다. 개발 main 대비 펫 변경 11개 파일만 적용했고 TestMain 충돌은 양쪽 시험 진입점을 모두 보존해 해결했다. 펫 제품 소스 두 파일은 사용자가 실물 수락한 개발 결과와 바이트 단위로 같다. ConversationView·ConversationModel·ConversationController·DraftEditor 및 기존 타이핑/성능 시험은 공개 기준과 같다. 두 비교의 git diff --exit-code는 각각 0이다.

개발 이력과 공개 이력을 병합하지 않았다. 원본 개발 브랜치·worktree·실물 검증 증거는 보존한다. 공개 tree는 개발 전체 tree의 스냅샷이 아니므로 snapshot 모드로 표시하지 않는다. 이 공개 통합본을 개발 main으로 ff하거나 개발 worktree를 자동 정리하지 않는다.

과거 시행착오 전체 증거는 원본 작업 문서 폴더에 보존하고, 이 공개 커밋에는 최종 위아래 배치 증거와 통합 검사 결과를 포함한다. 사용자 실물 수락은 원본 개발 결과에 대한 것이며 공개 통합본에서 같은 손 입력을 재실행했다고 주장하지 않는다.

검증 조건은 자체 점검이다. 첫 전체 시험은 시험용 라이브러리 경로 오지정으로 Python 426 통과/1 실패(exit 1)였다. 경로 수정 후 전체 검사를 재실행한다. 개인값 검사와 git diff --cached --check는 exit 0이다.


## 공개 통합 최종 자체 점검
대상 제품 커밋: `7db94ee0fb4220525dbcf5072ee79668a9f9a63c`. 공개 기준의 타이핑·성능 제품 및 시험 코드는 그대로 유지했다. 펫 제품 두 파일은 사용자 수락 개발판과 동일하다. TestMain은 두 시험 진입점을 모두 유지한다. 설계 적합성: 개폐 위치 보존·포인터 추종·위쪽 헤더 걸침/아래 배치 요구를 충족하는 구현을 보존했다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| 임시 홈·HEJO_PYTHON·올바른 HEJO_TEAM_KIT_LIB·짧은 pytest basetemp로 bash scripts/test.sh | exit 1. Python 427 통과, gateway delivery·제품 build·시험 compile 통과, 성능 회귀 AT-HP 통과. AT-UC-32 실패로 이후 전체 네트워크 fixture 미실행. 설정 guard 실패, 다운로드 guard 통과 | logs/public-full.log |
| bash app/.build/run-pet-tests.sh --pet-position | exit 1. T1~T6/APP_TEST_OK, 설정 guard 실패, 다운로드 guard 통과 | logs/public-pet-position.log |
| 같은 실행기 --drawer-inline | exit 0, 기능·두 guard 통과 | logs/public-drawer-inline.log |
| 같은 실행기 --task41 | exit 0, 기능·두 guard 통과 | logs/public-task41.log |
| 같은 실행기 --hejo-typing-boundaries (임시 홈 marker 포함) | exit 0, AT-HT-01/02/03·두 guard 통과 | logs/public-hejo-typing-boundaries.log |
| 임시 홈 HEJO_PYTHON으로 scripts/scan_private.py | exit 0 | logs/public-scan.log |

검증 판정: 부분 완료·자체 점검. 사용자 기능 수락은 완료됐으나 전체 검사 합격은 아니다. AT-UC-32는 수정 전에도 같은 실패가 관측된 시험/환경 문제이며 관련 공개 UI 코드를 바꾸지 않았다(logs/pet-ui-polish-baseline.log). 설정 guard는 hejo 범주 metadata 변화이며 원래 운영 앱이 시험 없이도 쓰는 관측이 있다(logs/pet-settings-background-observation.log). 이번 개별 실패가 모두 외부 쓰기였다고 확정하지 않으며 guard를 완화하지 않았다. 운영 앱/설정을 변경하지 않았다.

사용자는 위 제한이 남아 있는 상태에서 푸시 준비를 명시 요청했고, 최신 공개판을 보존한 펫 변경 통합을 승인했다. 이에 부분 완료 사실을 표시한 푸시 후보를 제출한다(40-paseo-role-workflow 4절의 명시 요청 예외). 실제 푸시는 별도 화면 승인으로만 수행한다. 개발 checkout으로 공개 후보를 ff하거나 원본 개발 worktree를 지우지 않는다.
