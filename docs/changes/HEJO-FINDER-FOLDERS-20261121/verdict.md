# HEJO-FINDER-FOLDERS 검증 판정

## 검증 판정 1차: HEJO-FINDER-FOLDERS TASK-02 (2026-11-21)

1. **판정: 부분 완료.** 구현은 요구·설계대로이고 수락 시험 AT-FF-01~11·13·14가 통과한다. 남은 것은 두 가지다. AT-FF-12 문장 오류(V-1, 계획 담당이 3판으로 정정함)와 커밋 미실행(V-2)이다.
2. **검증 조건:** 교차 모델. 계획 담당(Claude)이 같은 대화에서 검토했고, 구현은 별도 대화(codex)가 했다. 검토 시작 때 handoff 2판·impl-report·실제 diff를 다시 읽었다. 검토한 코드는 `<운영 저장소>` worktree `hejo-finder-folders-20261121`이다. HEAD는 `66f2a44c`이고 미커밋 3파일의 sha256은 `app_setup.py eff2a716…`, `app_connect.py e773e424…`, `test_finder_folders.py 45e09387…`로 보고와 같다.
3. **설계 적합성(4.2):** 적합하다.
   - 설계가 요구를 충족하는가: Finder 후보를 서버 동기화 뿌리와 2단계로 넓히면 사장이 다른 Mac에서 서버 폴더를 고를 수 있다. 연결이 막힌 원인(SCOPE_EMPTY)이 풀린다. 저장 경로(`files.folders`)는 직원 파일 도구가 실제로 쓰는 원본과 같다(`files.py:150-162`). 그래서 브레인스토밍의 목적(NAS 로그인 없이 그 폴더에서 저장·수정·삭제)에 이어진다.
   - 구현이 설계와 맞는가:
     - 후보 규칙은 `app_setup.finder_scopes` 한 곳에 있다.
     - Synology 뿌리는 `synology_setup.candidates`를 재사용한다.
     - `catalog.sync_folders`는 바뀌지 않았다. Finder 분기를 이 함수보다 앞으로 옮겨 다른 앱 경로는 그대로다.
     - 깊이 우선 나열, 숨김·꾸러미 확장자·자신과 모든 부모 링크 제외가 설계대로다.
     - 300 선발은 `sorted(rows, key=depth)`(안정 정렬이라 같은 깊이 안에서는 화면 순서)로 하고, 보낼 때 화면 순서로 되돌린다.
     - 잘림은 `len(rows) > 300`일 때만이다.
     - `_scope_hint`는 함수 시작 때 비우고 Finder만 넣는다. `app_connect`는 그 값이 있으면 우선 쓰고 없으면 기존 문장을 쓴다(design 2절 8항).
     - 저장 폴더는 상한 밖 맨 뒤에 붙고, `_requested_scope` 계약은 그대로다.
   - 설계와 달라진 점: 없다(커밋 보류만).
4. **직접 확인한 것(증거 수준 2):**
   - 게이트웨이 Python, 임시 `HOME`·`HERMES_HOME`(resolve), 관련 시험 실행: `test_finder_folders.py`, `test_app_catalog.py`, `test_app_connect.py`, `test_app_setup.py`, `test_synology_app_connect.py`, `test_app_registry.py` → **exit 0, 99 passed**. 로그: hejo 로컬 `.build/finder-folders-verify/related.log`.
   - 새 시험 코드를 읽었다. 기대값은 수락 명세의 글자 그대로다(`BASE`, `cap_expected`가 번호로 만든 기대 목록, 안내 문장). 제품 상수에서 가져오지 않았다.
   - AT-FF-03은 자식 프로세스에서 감사 훅을 먼저 걸고 실제 `hermes_facility.connections.main`을 대역 없이 실행한다. `home/Library` 아래 일반 파일 열기 0을 확인하고 전후 sha256도 비교한다(PR-01 요구대로).
   - 구현 담당의 mutation 기록이 있다. 링크 검사를 빼면 AT-FF-14 4건이 실패하고, 파일을 열게 하면 AT-FF-03이 실패한다(`.build/finder-folders-evidence/mutation*.log`).
   - 전체 회귀 로그(`full.log`)의 실패 29 node는 모두 임시 `HOME`에 없는 파일을 찾다가 났다. 해당 파일은 실제 프로필 `config.yaml`, `~/.local/share/hermes-docs/bin/python`, 운영 스크립트·플러그인 소스다. `failure-comparison.json`에서 착수 HEAD와 같은 집합(`same_nodes: true`, 29)이다. 관련 5파일은 실패 목록에 없다.
5. **지적:**
   - V-1(차단, 보낼 곳: 기획설계, 처분: **수정 완료**)
     - 위치: 수락 명세 AT-FF-12, spec REQ-FF-04.AC-01.
     - 근거: 그 문장은 team-kit 전체 시험이 임시 `HOME`에서 모두 통과한다고 전제했다. 실제로는 기존 시험 29개가 실제 서버 홈의 파일을 입력으로 쓴다. 이 시험들은 이번 변경과 관계없이 착수 HEAD에서도 실패한다. 실제 홈으로 돌리는 것은 handoff 금지(실제 경로·운영 입력)와 충돌한다. 계획 담당이 회귀 기준을 잘못 썼다.
     - 수정: 수락 명세 3판과 spec 3판. 기준을 "(가) 관련 기존 5파일 전부 통과 (나) 전체 실행의 실패·오류 node 집합이 착수 HEAD 기준 집합의 부분집합(새 실패 0), 기존 시험 수정·skip 금지"로 바꿨다. 기대값의 독립 근거는 착수 HEAD에서 실제로 다시 돌린 기준 집합이다(구현 결과에서 가져오지 않음).
     - 기존 증거(`full.log`·`baseline-failures.log`·관련 5파일 99 passed)는 정정된 기준을 충족한다. 단 커밋 뒤 최종 확인이 필요하다(V-2).
   - V-2(차단, 보낼 곳: 구현): 구현이 커밋되지 않았다. 검토 대상 변경본을 고정할 커밋이 필요하다(handoff 9항).
   - 기술 부채: team-kit 전체 시험 중 29개는 실제 운영 홈 입력에 의존해 임시 홈에서 돌 수 없다. 이번 작업 밖이므로 기록만 한다.
6. **기획설계로 넘긴 것:** V-1. 이 판정과 함께 정정했다.
7. **미검증 범위와 남은 위험:**
   - 실제 서버 동기화 폴더에서 후보가 나오는지, 걸리는 시간(NFR-FF-03), 사장 화면 확인(M1~M3)이 남았다. 이것은 수준 3·4이고 TASK-03 서버 적용 뒤에 본다.
   - 게이트웨이 재시작이 필요 없다는 판단은 소스 호출 경로 수준의 근거다. 바뀐 모듈은 `hermes-connections` 자식 프로세스만 import한다. TASK-03 인계에서 이 판단을 쓴다.
8. **원인 분류:** 시험 오류(V-1, 계획 담당 수정 완료). 완료까지 남은 조건은 둘이다. 구현 담당이 세 파일을 커밋하고, 그 커밋에서 정정된 AT-FF-12(가)(나)와 새 시험을 다시 실행한 결과를 보고하는 것이다.
9. 현재 명세 반영: 완료 판정 뒤.

## 검증 판정 2차: HEJO-FINDER-FOLDERS TASK-02 (2026-11-21)

1. **판정: TASK-02 완료.** 작업 전체는 아직 끝나지 않았다. TASK-03 서버 적용과 TASK-04 사장 확인이 남았다.
2. **검증 조건:** 교차 모델(계획 담당 Claude가 같은 대화에서 다시 읽고 검토, 구현은 codex). 검토한 코드는 `<운영 저장소>` 브랜치 `hejo-finder-folders-20261121`의 `f3318572b9cbd85fccb54347872feca8915532cd`이다(부모 `66f2a44c`).
3. **설계 적합성(4.2):** 1차 판정과 같다(적합). 코드는 1차 이후 바뀌지 않았다. 커밋한 세 파일의 blob sha256(`eff2a716…`, `e773e424…`, `45e09387…`)이 1차에 검토한 작업 파일과 같다는 것을 직접 확인했다(`git show HEAD:<파일> | shasum`).
4. **직접 확인한 것(증거 수준 2):**
   - 커밋 통계는 세 파일뿐이다(플러그인 수집 증거와 일치). worktree는 깨끗하다. 운영 저장소 main은 `66f2a44c` 그대로 깨끗하다.
   - 관련 6파일 99 passed: 1차에 직접 돌린 결과를 그대로 쓴다(같은 blob). 구현 담당이 커밋 HEAD에서 다시 돌린 `round2/related.log`도 99 passed다.
   - AT-FF-12(나): `round2/full.log`와 착수 기준 `baseline-failures.log`의 FAILED/ERROR node를 내가 따로 뽑아 비교했다. 29 대 29, 새 node 0으로 부분집합 조건을 충족한다(`round2/comparison.json`의 `subset: true`와도 같다).
5. **지적:** V-1은 수정됨(수락 명세 3판). V-2는 수정됨(커밋 `f3318572`). 새 지적은 없다.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위:** 실제 서버 폴더에서 나오는 후보와 걸리는 시간(NFR-FF-03), 사장 화면 확인(M1~M3). 이것은 TASK-03·04에서 본다.
8. 남은 조건: TASK-03(아래 handoff 3차 지시), TASK-04.
