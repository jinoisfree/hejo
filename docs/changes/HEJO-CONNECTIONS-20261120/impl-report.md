# HEJO-CONNECTIONS 구현 인계

## 받은 범위와 현재 상태

- 설계: [handoff.md](handoff.md), design 3판과 계획 검토 3회차 APPROVED(`2776ab1`). 제품 기준 `1ca3f27`, 운영 저장소 기준 `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`.
- 연합개발 구현·자체 시험, 고위험, 필요 증거 수준 2. 모든 갈래를 구현 담당이 직접 처리한다. 최종 독립 검토와 운영 적용은 별도다.
- 이번 범위는 TASK-02~04. 버전·배포·설치·재시작·운영 초안 변경·푸시는 범위 밖이다.

## TASK-02 문

[확인] 구현 완료, 자체 시험 수준 2. `Connections.document()`가 부분마다 읽기·변환을 원자적으로 처리하고 실패 부분만 제외한다. 묶음 설정 실패는 그 묶음 줄을 보존한다. 공유 status/apps는 요청마다 한 번, 직원별 결과와 실패 표시는 각 직원에 귀속한다.

- 변경: `gate/connection_manager.py` 부분 읽기·허용 필드·키 필터·숨김 표시·이어 하기 라벨, `gate/server.py` 전체 실패 실제 이유와 로그, `gate/connections.py` 응답 JSON 오류 구분과 undo 읽기 전용화.
- 제거: 직원 단위 통째 실패 처리, 전체 미설정 키 줄, 직원마다 apps 호출, 조회 중 purge/잠금 생성, 오류 이유를 하나로 덮는 경로.
- 의미 변경은 design 2절 그대로다. 추가 구조·공개 계약 변경 없음. 요청별 helper는 실제 오류 격리·변환 경계이며 대체 경로를 남기지 않았다.
- 새 수락 시험 `tests/acceptance/test_connections_screen.py`: AT-HC-01~08·10·11을 40사례로 구현. HTTP/모양/시간 초과 부분 실패, 직원 격리, 비밀·본문 무노출, 실제 루프백 AdminClient 실패 분류와 모든 가짜 홈 파일 hash 불변을 검사한다. AT-HC-09는 기존 연결 시험을 포함한 전체 Python 회귀로 확인했다.
- 기존 `CatalogAdmin` fixture의 켜진 묶음 설정에 `SYNTHETIC_KEY` 요구를 명시했다. 미설정 키 전체가 제거된 새 계약 아래에서 기존 보상 트랜잭션 시험의 쓰기/복원 조건과 기대값을 그대로 유지하기 위해서다.

| 실행 명령(게이트웨이 Python) | 실제 결과 | 로그(저장소 기준, 추적 안 함) |
|---|---|---|
| `python -m pytest tests/acceptance/test_connections_screen.py gate/tests/test_connections.py -q -p no:cacheprovider` (초회) | 종료 1, 57 통과·기존 보상 fixture 1 실패. 위 요구 키 누락을 보완 | `.build/connections-evidence/task02-targeted.log` |
| `python -m pytest gate/tests tests/acceptance -q -p no:cacheprovider` (초회) | 종료 1, 377 통과·4 실패. 기존 시험 경로에서 PyYAML/team-kit 경로 누락 | `.build/connections-evidence/task02-python.log` |
| 같은 전체 Python 명령(기존 로컬 시험 의존 경로와 worktree team-kit lib 지정, 임시 홈) | 종료 0, 381 통과·기존 pytest 경고 1 | `.build/connections-evidence/task02-python2.log` |
| 부분 실패 격리를 제거한 mutation, `test_hc01_03_config_isolation_and_safe_log` | 종료 1(의도대로 검출), 코드 원복 | `.build/connections-evidence/task02-mutation.log` |

정확한 로컬 환경은 추적하지 않는 `.build/connections-env.sh`에 있다. Python은 설치 facts의 `packages.venv.environment`, PYTHONPATH는 기존 시험 의존성·Hermes 소스·worktree team-kit·저장소다. 실패 기록도 보존했다. 고위험 변경의 운영 관측·실물 M1~M7은 미실행이며 TASK-05 이후다. 롤백은 이 TASK 커밋 되돌림이다.

## TASK-03 앱

[진행] 수정 전 개발 시험 도구로 재현 중. 결과 확인 전 앱 제품 코드는 변경하지 않았다.

## TASK-04 team-kit

[진행] 운영 저장소의 실제 착수 HEAD는 위 기준과 같다. 그 HEAD에서 `hejo-connections-20261120` worktree 브랜치를 만들었다. 로컬 위치는 `AGENTS.local.md`에 기록한다. 다른 작업의 main 변경은 보존한다.

운영 실행본과 기준 사본의 SHA-256 일치(모두 확인):

| team-kit 상대 파일 | 기준 SHA-256 |
|---|---|
| `lib/hermes_facility/synology_setup.py` | `58d6bc483e0090cb9889cfde3b132c3ae8525934de78bb57da1a5e04bd33a189` |
| `lib/hermes_facility/app_setup.py` | `f1dd31b34c8087da0ea7faafa94c5b5f705e11c6403407ad5d99b17b39ee8124` |
| `lib/hermes_facility/app_connect.py` | `4598709c56f52eed69eaa66079f2313365ec681371d7becc1d67bfa5fcb18849` |
| `lib/hermes_facility/connection_guides.py` | `15347bda0b8a0c5becb2695e52086b8b703ffeb5c0552ba14efecccfd13b903a` |
| `lib/hermes_facility/connection_secrets.py` | `841f51fb79855776ecd67f91c83e136ec55d7fc555be17175bccf5d345a43277` |
| `lib/hermes_packs/files_docs/files.py` | `fb306ff396ee1e0d8832d2c3f80a38ff0ce6bf1c8c54ca0f5a21acb4d5a250e7` |

원본 기록: `.build/connections-evidence/task04-baseline.json`. 운영 원본 교체·sync·restart는 하지 않았다.
