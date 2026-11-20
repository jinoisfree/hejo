# 구현 인계: HEJO-CONN-MANAGE-20261120

> 최신 진행: 2차 지시(`e96ca98`)로 재개. 아래 1차 보류 기록은 이력이며 현재 TASK별 결과는 문서 끝의 2차 절을 따른다.

## 판단 상태

**보류(구현 규칙 2절 보고 대기).** TASK-02 착수 전 기준 일치 검사에서 인계서 9항의 중단 조건을 확인했다. 제품 코드는 변경하지 않았다. TASK-02·03·04는 미구현이며, 제품 완료나 수락 시험 통과를 뜻하지 않는다.

## 받은 설계와 현재 기준

- [확인] 받은 설계: [handoff.md](handoff.md), 계획 3판 `da4592568a2da8122181fc7eb139f7f9e36132ee`. [plan-review.md](plan-review.md) 3회차 APPROVED 기록 확인.
- [확인] hejo 착수 HEAD: `251efabd2baa08f423e0da6b46e14fb8de582071` (`main`). 제품 기준 `63cbe2a` 이후 `gate/`·`app/`·`schemas/`·`scripts/` 차이 없음. 착수 시 hejo 작업 트리는 깨끗했다.
- [확인] 운영 저장소 착수 HEAD: `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`. 실제 경로는 추적하지 않는 `AGENTS.local.md`의 운영 저장소 항목을 따른다.
- 고위험, 필요 증거 수준 2, 연합개발의 구현·자체 시험 역할. 운영 적용·공개·설치·재시작은 이번 범위 밖이다.

## TASK-02: 기준 파일 불일치로 착수 중단

검사 대상은 `team-kit/lib/hermes_team_services/wait_jobs.py`다. 운영 저장소에서는 `hermes/plugin-store/` 아래에 있다. 실행본은 플러그인 창고의 같은 상대 경로다. 비밀 파일은 열지 않았다.

| 대상 | sha256 |
|---|---|
| 운영 저장소 HEAD의 파일 | `bf1dd9097a537b7f7999af93398b97386f6c3a24e3acc441b960b25bafd1ec83` |
| 운영 저장소 미커밋 파일 | `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d` |
| 실행 중인 파일 | `441a8501a4cefc146115bab154b5e939c8d59cd2e1d27d46661562a4f561a21d` |

[확인] 실행본과 미커밋 파일은 같고, HEAD 기준 파일과는 다르다. HEAD에서 임시 worktree를 만들면 이 파일의 기준 일치 조건을 만족하지 못한다. 새 worktree를 만들거나 운영 원본·미커밋 파일을 고치지 않았다. 다른 작업의 변경을 가져오거나 커밋하지 않았다.

인계서 9항은 이 파일을 특히 지목하며 “sha256 확인 결과를 반드시 적고 다르면 멈추고 보고”하도록 명시한다. 기존 변경을 무시한 HEAD 개발이나 미커밋 파일의 임의 반입은 승인된 절차에 없다.

### 계획 담당이 결정할 쟁점

1. 권고: 해당 미커밋 변경의 담당 작업이 검증·커밋으로 기준을 확정한 뒤, 갱신된 HEAD와 실행본을 다시 비교하여 새 worktree에서 시작한다. 다른 작업의 변경을 이 작업 커밋에 섞지 않는다.
2. 대안: 계획 담당이 현재 미커밋 변경의 소유권·상태·기준을 확인하고, 그 변경을 포함하는 별도 기준 수립 절차를 명시한다. 구현자가 임의로 파일을 복사하거나 기준 일치 요건을 생략하지 않는다.

## TASK-03·04

[미실행] 제품 변경과 수락 시험 코드 작성 전이다. TASK-03은 확정된 계약과 가짜 team-kit으로 독립 구현할 수 있다. TASK-04는 이 Mac에서 확인 창 뒤 창 사라짐을 먼저 재현해야 한다. 차단 해소를 위한 수정 지시에서 독립 갈래 선행 여부도 명시할 수 있다. 현재 응답에서는 인계서의 중단 요구에 따라 작업 경계에서 멈춘다.

## 변경·설계 차이·남긴 코드

- 추가: 이 구현 인계 보고서. 기존 제품 코드·시험·명세·설계 변경 없음.
- 설계 변경 없음. 계획이 요구한 착수 검사에서 중단했다.
- 새 구조·공개 계약·저장 형식·임시 제품 코드 없음. 롤백할 제품 변경 없음.
- 별도 에이전트 실행 없음. 운영 파일·설정·금고·명부·토큰·ddots·Hermes 본체 변경 없음.

## 검증과 증거

실행 기록은 로컬 `.build/conn-manage-evidence/`에 둔다. 개인 경로를 추적 문서에 넣지 않는다.

- [확인] 읽기 전용 sha256 비교: Python 표준 라이브러리로 `git show HEAD:<상대 경로>`의 바이트와 운영 저장소 작업본·실행본을 비교. 실행 종료 코드 0, 기준 일치 판정 BLOCKED. 원문 로그: `.build/conn-manage-evidence/preflight.log`. 이 보고서의 표는 해당 로그에서 직접 확인했다.
- [확인] `git diff --stat 63cbe2a HEAD -- gate app schemas scripts`: 종료 코드 0, 출력 없음. 원문 로그의 `product_changes_since_base`도 빈 목록.
- [확인] `python3 scripts/scan_private.py --home <임시 가짜 홈>` 첫 실행: 종료 코드 1. 가짜 명부의 `alpha`·`beta`가 기존 시험 식별자와 Swift 투명도 이름에 걸렸다. 제품 결함으로 판정하지 않는다. 로그: `.build/conn-manage-evidence/scan-initial.log`. 가짜 명부를 검사 전용 식별자로 분리해 최종 문서 상태에서 다시 실행한다. 실제 명부·금고의 개인값 대조는 수행하지 않는다. 최종 실행 결과는 `.build/conn-manage-evidence/scan-result.json`과 `scan.log`를 따른다.
- [미실행] AT-CM-01~18·14b·40~44·20~28·23b·30~38, 회귀 시험, 앱 빌드, `./airport-check`, mutation check. 제품 변경 전 중단했으므로 실행하지 않았다. 본체 소비자 시험 AT-CM-14b를 통과로 세지 않는다.
- 도달 증거: 착수 파일 비교만 확인. 필요한 제품 증거 수준 2는 아직 도달하지 않았다.

## 다음 인계

계획 담당은 기준 불일치 처리 방식을 확정해 구현 지시를 갱신한다. 이후 구현 담당은 실제 HEAD·실행본·작업 트리를 다시 확인한 뒤, 허가된 기준으로 TASK-02·03·04와 수락 시험을 진행한다. 현재 푸시 대상 커밋은 생성하지 않았다.


## 2차 구현 — TASK-03 문

[확인] 보완 인계 `e96ca98`에 따라 재개했다. 작업 기준은 같은 커밋이며 기존 제품 변경은 없었다.

- 구현자 판단: **TASK-03 구현·자체 시험 완료**(제품의 최종 완료 판정 아님).
- 변경: `gate/connection_manager.py`에서 `settings`·`committed` 공개 필드, 연결된 앱의 설정 바꾸기 라벨, 조건부 계정 줄 합치기와 확인 전달, `change` 전달, 기기별 보안 칸 누적과 세션 경계를 구현했다. 설정 표시 값은 공개하되 보안 입력 값은 기존 거부 원칙을 유지한다.
- `gate/connection_runtime.py`는 `--change`와 `account connect|disconnect|undo`의 고정 인자를 검증한다. 계정 저장 뒤 재개는 계정 변경을 다시 실행하지 않고 기존 다시 시작 작업으로 간다.
- `gate/server.py`의 소켓 종료 지점에서 해당 기기의 보호 목록을 비운다. 이는 인계서의 기기 연결 끊김 정리를 위한 실제 호출자 변경이다. 새 창 닫힘 프레임·저장 형식은 추가하지 않았다.
- 새 `tests/acceptance/test_conn_manage.py`: AT-CM-20~28·23b를 코드로 옮겼다. 설치만 된 앱은 기존 계정 줄을 유지하고, 설정 기준 확인 결과는 직접 확인 결과로 취급하지 않는다. 진행 중 요청은 시작 시점의 비밀값 집합을 유지하여 뒤 요청·기기 끊김에 영향받지 않는다.
- 기존 마지막 응답 덮어쓰기 경로를 세션 누적으로 교체했다. 새 세션·일반 요청·저장 완료·실패/거절·기기 끊김 경계에서 정리하며, 오래 걸린 이전 세션 응답이 새 세션 목록을 덮지 않도록 집합의 소유권도 검사한다.

### TASK-03 검증

| 명령 | 실제 결과 | 로그(hejo 기준) |
|---|---|---|
| gateway Python `-m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 397 passed, 기존 비동기 표시 경고 1 | `.build/conn-manage-evidence/gate-all-final.log` |
| gateway Python `-m gate.tests.gateway_delivery` | 종료 0, 격리된 가짜 홈·플랫폼의 게이트웨이 전달/종료 확인 | `.build/conn-manage-evidence/gateway-delivery.log` |
| 보안 칸 누적 제거 mutation | 시험 종료 1(예상대로 검출), 원복 | `.build/conn-manage-evidence/mutation-secure-field-accumulation.log` |
| 요청 비밀값 필터 제거 mutation | 시험 종료 1(예상대로 검출), 원복 | `.build/conn-manage-evidence/mutation-reflected-secret-filter.log` |

필요·도달 증거 수준은 2다. 운영 관리 서비스·실제 직원·메시지·게이트웨이는 사용하지 않았다. TASK-02·04 결과는 다음 절에 이어 기록한다.
