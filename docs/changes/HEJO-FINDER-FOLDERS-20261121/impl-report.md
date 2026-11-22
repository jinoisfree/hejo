# HEJO-FINDER-FOLDERS TASK-02 구현 인계

## 판단과 차단

[확인] 지정된 Finder 후보 생성·hint 전달·새 시험은 구현했다. **부분 구현 / 검증 차단으로 커밋 보류**다. AT-FF-12의 기존 전체 시험 통과 조건은 충족하지 못했다. 운영 저장소 `AGENTS.md` 검증 절의 “실패가 있으면 커밋·푸시·재시작을 하지 않는다”를 적용했다. 서버 적용과 최종 완료 판정은 하지 않았다.

받은 기준은 [handoff.md](handoff.md) 2판, [수락 명세](../../../tests/acceptance/HEJO-FINDER-FOLDERS.md) 2판이다. 위험도 일반, 필요한 증거 수준 2, 연합개발 구현·자체 시험 역할이다. 호스트 인계의 계획 재검증 결과는 APPROVED였으나 명세·handoff의 대기 문구는 구현 역할에서 수정하지 않았다.

착수 HEAD: `66f2a44c190390edd2a8a8eab9b2c32cba20195a`(설계의 운영 저장소 기준과 같음). 브랜치: `hejo-finder-folders-20261121`. worktree: hejo 작업 폴더 기준 `../.worktrees/hejo-finder-folders-20261121`. 운영 원본의 위치는 추적하지 않는 `AGENTS.local.md`가 원본이다. 새 커밋은 없다.

## 변경과 책임

worktree의 `hermes/plugin-store/team-kit/` 아래 다음 세 파일만 제품·시험 변경이다.

| 파일 | 변경 이유 |
|---|---|
| `lib/hermes_facility/app_setup.py` | 기존 Finder 분기를 같은 파일의 `finder_scopes`로 교체. Synology 후보 함수를 재사용하고 CloudStorage·iCloud 뿌리와 깊이 2까지를 읽기 전용으로 나열한다. 숨김·자신과 부모 링크·꾸러미 제외, 얕은 깊이 우선 300개 선발 후 화면 순서 복원, 저장된 범위와 명시 요청 경로 유지, `_scope_hint` 생성 |
| `lib/hermes_facility/app_connect.py` | 고르기 대기 응답의 hint를 `_scope_hint` 우선으로 전달. 다른 앱의 기존 빈 목록 안내와 반환 계약 유지 |
| `tests/test_finder_folders.py` | AT-FF-01~11·14를 실제 연결 조립 경로와 임시 홈으로 시험. 경계의 매개변수 사례와 8종 꾸러미 대소문자 제외 시험 포함, 총 27개 |

[확인] 의미 변경은 Finder 후보 확장뿐이다. `catalog.sync_folders`, Synology 연결 흐름, 저장·트랜잭션 계약, 기존 시험 기대값은 수정하지 않았다. 새 옵션은 기존 `{id,label,value}`이고 `scopes()`는 list를 반환한다. 기존 Finder 분기의 제한된 목록 생성 코드는 제거했다. 새 칸·공개 계약·임시 호환 경로·기술 부채용 코드 없음.

iCloud 뿌리는 Finder 도우미 안에서 경로를 만들고 동일한 제외 검사를 적용한다. 다른 앱도 사용하는 `catalog.sync_folders`를 바꾸거나 호출 결과 전체를 Finder 목록으로 사용하는 방식은 쓰지 않았다. CloudStorage 열람 오류가 iCloud 후보까지 막지 않게 하는 내부 배치이며, 반환되는 뿌리 경로는 기존 함수의 iCloud 경로와 같다.

설계와 달라진 진행 결과: 구현 커밋은 전체 시험 차단 때문에 미실행. 수락 기준·명세는 그대로이며, 환경 문제를 기존 시험 수정·skip·기대값 변경으로 우회하지 않았다.

## 기준 일치와 변경본 식별

변경 전에 실행본과 worktree 기준 파일을 직접 해시했다. 신규 시험은 양쪽 모두 없었다. 전체 원본은 hejo의 로컬 `.build/finder-folders-evidence/baseline.json`이다.

| 파일 | 기준·실행본 SHA-256(일치) | 구현본 SHA-256 |
|---|---|---|
| `app_setup.py` | `17834aa1382c0e615f87f807a799baf27f58d2b8ec938172ae429c902f5aa649` | `eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6` |
| `app_connect.py` | `0af29766b4728d5c0574455d2000a7bbdec75a062230614d74e258727fcef489` | `e773e4244748feea273d9350a31f24ff3641f9597f8133de45c8308eb427cf1a` |
| `test_finder_folders.py` | 양쪽 없음(새 파일) | `45e0938735953c1ae78158829bab864ab5e5b6f2f43b8416ef0a926252a0caa6` |

기준 재현과 mutation 검사 때만 worktree의 두 구현 파일 또는 Finder 도우미를 일시 교체했다. 각 실행의 finally에서 구현본을 복원했고 위 해시를 다시 대조했다. 실행본 교체는 하지 않았다.

## 시험 명령과 실제 결과

아래 `E`는 hejo 작업 폴더의 로컬 `.build/finder-folders-evidence`다. `P`는 실행 중 설치의 `facts.json`에서 `packages.venv.environment`로 찾은 Python이다. 실제 절대 경로·argv·cwd·종료 코드는 E의 각 JSON에 있다. 추적 문서에는 개인 경로를 복제하지 않는다.

모든 pytest 실행은 `P -B`, 임시 HOME·HERMES_HOME·HERMES_ROOT의 resolve한 경로, `PYTHONDONTWRITEBYTECODE=1`, `HERMES_DISABLE_LAZY_INSTALLS=1`, Node PATH 및 worktree/lib·pytest·본체의 PYTHONPATH를 사용했다. 실행기는 `E/run_checks.py`이며 본체는 import만 하고 수정하지 않았다.

| 명령(별도 표기 없으면 worktree cwd) | 종료 코드 | 실제 결과 | 로그(hejo 기준) |
|---|---:|---|---|
| `P -B -m pytest hermes/plugin-store/team-kit/tests/test_finder_folders.py -q` | 0 | 27 passed, 1.83초 | `E/focused.log`, `E/focused.json` |
| `P -B -m pytest hermes/plugin-store/team-kit/tests -q` | 1 | 28 failed, 5010 passed, 64 skipped, 1 error, 58 subtests passed, 144.18초. 기존 경고 1개 | `E/full.log`, `E/full.json` |
| 착수 HEAD의 두 파일로 `P -B -m pytest -q -p no:cacheprovider <위 실패·오류 node ID 29개>` | 1 | 같은 28 failed, 1 error, 2.04초. node ID 집합까지 일치 | `E/baseline-failures.log`, `E/baseline-failures.json`, `E/failure-comparison.json`; 재현 실행기 `E/reproduce_baseline.py` |
| `P ./airport-check --snapshot .` | 0 | boundary 382, document 0, compartments 0. 기준선 감소 가능 4건은 변경하지 않음 | `E/airport.log`, `E/airport.json` |
| `P E/scan_changed.py`(hejo cwd) | 0 | hejo 개인값 검사 함수를 지정 세 파일에 적용. 신규 지적 0, 기준에도 있는 표준 드라이브 루트 문자열 지적 2건 구분 | `E/private-changed-final.log`, `E/private-changed-final.json` |
| `P -B -m pytest …/test_finder_folders.py -q -k at_ff_14 -p no:cacheprovider`(링크 검사 제거 mutation) | 1 | 의도대로 4 failed, 23 deselected | `E/mutation-links.log`, `E/mutation.json` |
| `P -B -m pytest …/test_finder_folders.py -q -k at_ff_03 -p no:cacheprovider`(동기화 파일 열기 mutation) | 1 | 의도대로 1 failed, 26 deselected | `E/mutation-file-open.log`, `E/mutation.json` |
| `git diff --check` | 0 | 공백 오류 없음 | `E/final-integrity.log` |

[확인] 개인값 추가 검사의 첫 시스템 Python 시도는 YAML 의존성 없음으로 종료 1이었다. 게이트웨이 Python으로 전체 세 파일을 검사한 초기 결과는 기준 코드의 표준 드라이브 루트 문자열 두 줄 때문에 종료 1(`E/private-changed.log`), 기준 원문과 대조해 **신규 변경분 지적 0**을 구분했다. airport-check의 기준선이나 제품·시험의 예외 목록을 바꾸지 않았다. 이 추가 검사는 tests를 제외하는 airport-check의 범위를 보완한다.

### 수락 항목별 관측

- AT-FF-01·02: 정확한 9개 후보·순서·서버 경로, 두 경로 선택 후 금고·조립 설정 저장과 files.enabled. 저장에 `_scope_hint` 같은 임시 키가 남지 않음.
- AT-FF-03: 실제 `hermes_facility.connections.main` 진입점에 import 전 감사 훅을 설치한 자식 프로세스. 후보·scandir·설정 경로를 대역으로 바꾸지 않음. open 사건 516건, 임시 `home/Library` 아래 일반 파일 열기 0건, 전후 목록·파일 SHA-256 같음. 원본 사건 `E/open-events.json`, 요약 `E/audit-summary.json`. 설치 CLI도 같은 main을 호출함을 소스 확인.
- AT-FF-04·05: 권한 000 시험은 비-root로 실행되어 통과. 정확히 300, 301, 421, 세 뿌리 합계 321의 지정 선발·순서·hint 통과.
- AT-FF-06·07: 빈 Finder 안내와 금고·명부·설정 불변, Synology 뿌리 우선·중복 제거.
- AT-FF-08·09: 깊이 4·뿌리 밖 저장 폴더의 마지막 추가·미리 선택, 상한 밖 301개, 삭제된 저장 폴더 제외와 마지막 저장 전 원본 불변.
- AT-FF-10·11: 없는 요청은 SCOPE_INVALID와 원본 불변, 존재하는 뿌리 밖 명시 경로는 기존대로 저장.
- AT-FF-12: **차단**. Finder 관련 기존 시험을 포함해 전체를 실제 실행했으나 위의 기존 환경 의존 실패가 남음. 64개 skip을 통과로 세지 않음.
- AT-FF-13: airport-check 및 새 시험을 포함한 변경분 검사에서 신규 개인값 지적 없음.
- AT-FF-14: CloudStorage 부모·Mobile Documents 부모·뿌리 자체·하위 링크의 네 사례 통과. 링크 검사 제거 mutation에서 네 사례가 모두 실패.

증거 수준은 임시 홈·가짜 직원 alpha의 통합 수준 **2**다. 재시작·OS 권한·검사 외부 단계만 대역으로 처리했다(감사 훅 CLI 시험에는 대역 없음). 실제 서버 동기화 폴더나 사용자 화면 수준 3·4 증거로 해석하지 않는다.

## 전체 회귀 차단의 근거와 다음 판단

[확인] 29개 실패·오류 node가 착수 HEAD에서도 그대로 재현된다. 이번 변경으로 새로 실패한 node는 없다. 다만 이것이 AT-FF-12 통과를 뜻하지 않는다.

기존 시험의 임시 HOME 비호환은 다음 네 종류다.

1. `test_all_profile_prompt_budget.py`: `Path.home()` 아래 실제 프로필 config·SOUL·플러그인·학습 입력을 요구하는 기존 시험. 파일 머리말도 live configured sections라고 명시한다. 가짜 명부·임시 홈만 쓰는 이번 조건에서 그 입력이 없다.
2. `test_document_review.py`, `test_doc_fill.py`, `test_files.py`: HOME 아래 별도 문서 Python 환경을 요구한다.
3. `test_connections_status.py`: HOME 아래 인증 도우미 **소스 코드**의 계약을 검사하는데 임시 홈에는 없다(비밀 파일 문제와 구분).
4. `test_morning_report.py`, `test_morning_system.py`, `test_night_schedule.py`: HOME 아래 다른 플러그인·정비·보존 스크립트 소스에 의존한다.

[제안] 계획 담당이 전체 회귀 시험의 입력·환경 계약을 먼저 처분해야 한다. 소스와 Python 의존성만 임시 홈에 준비할 수 있는 항목, 운영 프로필 자체를 입력으로 삼는 프롬프트 시험을 구분해 후자의 격리 fixture 또는 별도 검증 범위를 정하는 것이 좋다. 기존 시험 수정은 현재 허용 범위 밖이고 운영 입력으로 몰래 전환하거나 skip할 수 없다. 변경된 수락 계약이 필요하면 계획 담당 문서에서 먼저 확정한다.

남은 작업: 위 차단 처분 후 필요한 전체 검증 → 지정 세 파일 `git commit --only` → 구현 검토 → 별도 TASK-03 서버 적용 인계. M1~M3·실제 시간 NFR-FF-03은 서버 적용 뒤 사장 확인 항목이며 미실행이다.

## 게이트웨이 import와 재시작 판단

[확인] 설치된 문 `connection_runtime.py:142,182`는 고정 `bin/hermes-connections`를 `asyncio.create_subprocess_exec`로 매번 실행한다. 설치 CLI는 게이트웨이 환경 Python을 선택한 뒤 `hermes_facility.connections.main`을 부른다. `connections.py:451,462`에서 app_connect를 가져와 run을 호출하고, `app_connect.py:517`이 run 안에서 app_setup을 가져온다.

[확인] 실행본 team-kit 소스의 import 참조를 AST로 확인했다(`E/import-references.json`). 추가 진입은 CLI의 account/status/apps와 Synology 연결 설정 경로이며, team-kit 게이트웨이 등록 진입점에서 변경 두 모듈을 직접 가져오는 참조는 없었다. 문 실행본의 subprocess 경로도 직접 읽어 대조했다.

[추론] 이번 Finder 후보·hint는 새 CLI 프로세스가 읽으므로 해당 기능 적용에 게이트웨이 재시작은 필요하지 않은 구조다. **실행 중 프로세스의 sys.modules/메모리 내부는 미관측**이다. 이 확인은 소스 호출 경로 수준이며 운영에 진단 코드를 주입하지 않았다. TASK-03 담당은 이 범위와 운영 저장소의 일반 재시작 규칙을 구분해 적용 지시를 확정해야 한다.

## 보존·인계

[확인] 운영 실행본 교체·운영 main 변경·sync·게이트웨이 재시작·문 릴리스·앱 교체·공개·외부 메시지·push는 하지 않았다. 금지된 비밀 파일을 열지 않았다. hejo gate/app/schemas·Hermes 본체·ddots·수락 명세·spec·design은 수정하지 않았다. 다른 작업의 문서 폴더는 보존했다.

검토 담당은 worktree의 세 변경 파일과 위 로그를 직접 확인하고, AT-FF-12 처분을 우선해 달라. 최종 파일 해시 원본은 `E/final-sha256.json`, 최종 상태 확인은 `E/final-integrity.log`다. 구현본은 미커밋 상태로 보존하며, worktree를 지우면 현재 구현을 잃으므로 검토 전에 제거하지 않는다.

## 2차: 검토본 커밋과 정정된 회귀 기준 확인 (2026-11-21)

[확인] [handoff.md 2차 지시](handoff.md#2차-지시-2026-11-21-검증-1차-verdictmd-v-1v-2)와 [verdict.md 1차](verdict.md)를 적용했다. 수락 명세·spec 3판의 AT-FF-12가 이번 판정 기준이다. **배정된 TASK-02 구현·자체 시험 완료, 검토 대기**다. 1차 보고의 커밋 보류와 AT-FF-12 차단은 이 절의 결과로 해소됐으며 제품 전체 완료·서버 적용·푸시 완료를 뜻하지 않는다.

### 변경본 고정

- 구현 커밋: `f3318572b9cbd85fccb54347872feca8915532cd`.
- worktree·브랜치는 1차와 동일(`hejo-finder-folders-20261121`), 부모는 착수 HEAD `66f2a44c190390edd2a8a8eab9b2c32cba20195a`다.
- `git commit --only`로 지정 세 파일만 커밋했다. 새 시험만 먼저 `git add`했고, 기존 시험과 다른 파일은 포함하지 않았다.
- 내용 수정 없음. 커밋 전 작업 파일, 커밋 blob, 시험 뒤 작업 파일의 SHA-256이 모두 1차 검토본과 일치한다: `app_setup.py eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6`, `app_connect.py e773e4244748feea273d9350a31f24ff3641f9597f8133de45c8308eb427cf1a`, `test_finder_folders.py 45e0938735953c1ae78158829bab864ab5e5b6f2f43b8416ef0a926252a0caa6`.

### 커밋 HEAD에서 실행한 검증

이 절의 `E2`는 hejo 작업 폴더 기준 `.build/finder-folders-evidence/round2`다. 실행기 `E2/run_checks.py`와 각 JSON에 실제 argv·cwd·Python 경로·종료 코드·대상 커밋이 있다. `P`는 설치 facts의 게이트웨이 환경 Python이며, 기준 재현에 사용했던 Python 경로와 같음을 비교했다. 모든 pytest는 resolve한 임시 HOME·HERMES_HOME·HERMES_ROOT와 기존 격리 환경을 사용했다. 운영 홈 입력으로 전환하거나 기존 시험 수정·skip 추가를 하지 않았다.

| 명령 | 종료 코드 | 실제 결과 | 로그·증거(hejo 기준) |
|---|---:|---|---|
| `git commit --only -m <변경 이유> -- <지정 세 파일>` | 0 | 위 커밋 생성. pre-commit의 snapshot airport-check도 boundary 382·document 0·compartments 0 출력 후 완료. 기준선 변경 없음 | `E2/commit.log`, `E2/commit-command.json`, `E2/commit.json`, `E2/precommit-sha256.json` |
| `P -B -m pytest -q hermes/plugin-store/team-kit/tests/test_finder_folders.py hermes/plugin-store/team-kit/tests/test_app_catalog.py hermes/plugin-store/team-kit/tests/test_app_connect.py hermes/plugin-store/team-kit/tests/test_app_setup.py hermes/plugin-store/team-kit/tests/test_synology_app_connect.py hermes/plugin-store/team-kit/tests/test_app_registry.py` | 0 | **99 passed**, 3.09초. 새 시험과 AT-FF-12(가) 충족 | `E2/related.log`, `E2/related.json` |
| `P -B -m pytest hermes/plugin-store/team-kit/tests -q` | 1 | **28 failed, 5010 passed, 64 skipped, 1 error, 1 warning, 58 subtests passed**, 141.60초. 전체가 통과한 것은 아니며 아래 기준 집합과 비교 | `E2/full.log`, `E2/full.json` |
| `python3 .build/finder-folders-evidence/round2/compare_results.py`(hejo cwd) | 0 | 기준 29 node, 현재 29 node, 새 node 0, 해소 node 0. 현재 집합 = 기준 집합이므로 부분집합 조건 충족. 커밋·파일 해시와 깨끗한 worktree도 확인 | `E2/comparison.log`, `E2/comparison.json`, `E2/integrity.json` |
| `git diff --check`(worktree cwd, 비교 실행기에 포함) | 0 | 공백 오류 없음 | `E2/integrity.json` |

[확인] 기준은 착수 HEAD의 두 구현 파일로 실제 재현했던 `E/baseline-failures.log`와 `E/baseline-failures.json`이다. 2차 지시가 재사용을 허용했고 기존 기록은 덮어쓰지 않았다. 이번 전체 실행의 FAILED·ERROR 요약에서 node ID를 추출해 그 합집합을 기준과 비교했다. `E2/comparison.json`에는 두 집합과 차집합을 모두 기록했다. **AT-FF-12(나)는 새 실패·오류 0으로 충족**한다. pytest 자체 종료 코드 1을 종료 0이나 전체 통과로 바꿔 보고하지 않는다.

증거 수준은 요구된 **2**다. 1차의 실제 CLI 감사 훅·mutation·개인값 검사 증거는 코드와 시험 바이트가 동일하므로 그대로 유지한다. 29개 운영 홈 의존 시험은 명세 3판과 검증 1차가 처분한 기존 기술 부채이며 이번 코드에서 고치지 않았다.

### 남은 단계와 보존

[확인] 실행본 교체·운영 main 수정·sync·재시작·릴리스·공개·push·금지 경로 수정은 하지 않았다. 제품 worktree는 커밋 뒤 깨끗하다. 보고서의 이 2차 절은 hejo 작업 문서에 추가한 것으로, 제품 커밋에는 포함되지 않는다.

다음 담당은 위 커밋과 정정된 수락 기준·비교 증거로 V-2를 재검토한다. 이후 TASK-03 서버 적용은 별도 인계가 필요하며, M1~M3와 NFR-FF-03 실측은 여전히 미실행이다. 푸시 대상 제안과 승인은 검토 이후의 별도 단계다.

## 3차: TASK-03 서버 적용 (2026-11-21)

### 교체 전 착수 확인·롤백 기록

[확인] handoff 3차 지시에 따라 증거 수준 3의 운영 적용을 시작한다. 아래 보관과 복원 기록을 **실행본 교체 전에** 작성했다. 이 절의 `E3`는 hejo 작업 폴더 기준 `.build/finder-folders-evidence/round3`, `P`는 설치 facts의 게이트웨이 환경 Python이다.

- 운영 저장소 main 착수 HEAD: `66f2a44c190390edd2a8a8eab9b2c32cba20195a`, 미커밋 목록 없음. 검토 브랜치 tip: `f3318572b9cbd85fccb54347872feca8915532cd`. 기존 인계 값과 일치한다(`E3/preflight.json`).
- 실행본 `app_setup.py` SHA-256: `17834aa1382c0e615f87f807a799baf27f58d2b8ec938172ae429c902f5aa649`; `app_connect.py`: `0af29766b4728d5c0574455d2000a7bbdec75a062230614d74e258727fcef489`. 두 값 모두 교체 전 기준과 일치한다.
- 실제 보관 폴더: hejo 기준 **`.build/finder-folders-evidence/round3/rollback-n0ofur3z/`**(권한 0700). 파일은 `app_setup.py`, `app_connect.py`이며 SHA-256은 바로 위 실행본 기준값과 각각 같다. 작업 문서 폴더 밖이고 추적하지 않는다. 원래 파일 모드는 `E3/deployment.json`에 보관했다.
- 복원 명령(hejo cwd): `P .build/finder-folders-evidence/round3/restore.py`. 이 스크립트는 보관본 해시를 검증하고 실행본 `plugin-store/team-kit/lib/hermes_facility/`의 동일 파일 각각에 임시 파일·이름 바꾸기로 복원한 뒤 기준 해시를 확인한다. 계속 움직이는 운영 저장소 HEAD를 복원 기준으로 쓰지 않는다.
- 복구 조건: status/apps 실패 또는 finder_scopes 예외 시 즉시 두 파일 복원 → 같은 status/apps 확인 → 멈춤 보고. 후보 0개·150초 초과는 인계대로 복원 없이 보고한다.
- 교체 전 게이트웨이 공식 상태 파일에서 active_agents 0·active_work 0과 프로세스 생존을 확인했다(`E3/runtime-before.json`). 재시작하지 않는다.
- `sync` 소스 확인: 실행본에서 저장소로 수집한다. 먼저 저장소의 수집 폴더를 재생성하고 실행본을 복사하며, 인자 없는 실행은 커밋·푸시하지 않는다. 비밀 파일은 SKIP에서 제외한다. 운영에 배포하지 않는 새 시험은 수집 과정에서 사라질 수 있으므로 sync 뒤 검토된 커밋에서 해당 시험 파일만 저장소에 복원해 기록을 보존한다. sync 자체와 다른 파일의 내용을 고치지 않는다.

### 적용 결과·실측

[확인] 두 실행본을 같은 디렉터리의 임시 파일에 쓴 뒤 이름 바꾸기로 교체했다. 최종 실행본·운영 저장소 파일·커밋 blob의 SHA-256이 각각 일치한다(`E3/applied.json`, `E3/final-integrity.json`).

| 파일 | 적용 후 SHA-256 |
|---|---|
| `app_setup.py` | `eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6` |
| `app_connect.py` | `e773e4244748feea273d9350a31f24ff3641f9597f8133de45c8308eb427cf1a` |

게이트웨이 환경 Python으로 **실행본 lib의 `finder_scopes({})`를 실제 서버 홈에서 읽기 전용 1회** 호출했다. 후보 **75개**, 소요 **0.151799초**, `_scope_hint` **없음**이었다. 후보는 Synology 10개·다른 CloudStorage 0개·iCloud 65개·기타 0개이며, 후보가 속한 뿌리는 각각 2개·0개·1개·0개다(`E3/finder-metrics.json`). 폴더 이름·경로와 status/apps의 원문 응답은 기록하지 않았고, 운영 app connect는 실행하지 않았다.

[확인] status/apps 모두 종료 0이고 예상 JSON schema를 만족했다. 예외·후보 0개·150초 초과가 없어 복원 조건에 해당하지 않았다. 보관본은 유지하며 **복원은 미실행**이다. 전후 게이트웨이 pid·시작 식별자가 같고 프로세스 생존을 확인했다(`E3/runtime-before.json`, `E3/runtime-after.json`). 재시작·릴리스·앱 교체는 실행하지 않았다. 이 실측은 서버 한 번의 관측으로, 다른 Mac의 hejo 화면 확인 M1~M3를 대신하지 않는다.

### 운영 저장소 기록·검증 명령

| 명령 | 종료 코드 | 실제 결과 | 로그·증거(hejo 기준) |
|---|---:|---|---|
| `python3 E3/apply_and_check.py` | 0 | 원자 교체 및 아래 운영 읽기 확인 성공 | `E3/apply.log`, `E3/applied.json` |
| `hermes-connections status --json` | 0 | `hermes-connections/1`, stderr 0바이트 | `E3/live-checks.json` |
| `hermes-connections apps --json` | 0 | `hermes-installed-apps/1`, stderr 0바이트 | `E3/live-checks.json` |
| `P -B -c <finder_scopes 1회·집계만 출력하는 코드>` | 0 | 위 실측 수치. 실제 코드는 `apply_and_check.py`의 probe에 보존 | `E3/finder-metrics.json`, `E3/apply.log` |
| `git merge --ff-only hejo-finder-folders-20261121`(운영 저장소) | 0 | 착수 HEAD에서 검토 커밋으로 fast-forward. 변경 경로는 지정 세 파일뿐 | `E3/merge.log`, `E3/merge.json` |
| `./sync`(운영 저장소, 추가 인자 없음) | 0 | 1598파일 수집, 토큰 경고 없음. 실행본을 읽어 저장소로 수집 | `E3/sync.log`, `E3/sync.json` |
| `./airport-check`(운영 저장소, 게이트웨이 Python을 PATH 선두에 지정) | 0 | boundary 381, document 0, compartments 0, 세 assembly 검사 모두 0. 기준선 변경 없음 | `E3/airport-check.log`, `E3/airport-check.json` |
| `git commit --only -m <서버 적용 기록 이유> -- <지정 세 파일>`(운영 저장소) | 1 | 세 파일이 이미 병합된 HEAD와 같아 새로 커밋할 변경 없음. hook은 boundary 382·document 0·compartments 0으로 통과 | `E3/post-sync-commit.log`, `E3/post-sync-commit.json` |
| `git diff --check HEAD -- <지정 세 파일>`(운영 저장소) | 0 | 작업 범위 공백 오류 없음 | `E3/task-diff-check.log`, `E3/final-integrity.json` |
| `git diff --check`(운영 저장소 전체) | 2 | sync가 수집한 작업 밖 `hermes/owner/vault.yaml`의 기존 줄 끝 공백 1건. 값은 기록하지 않고 진단만 보존. 수정·커밋하지 않음 | `E3/final-diff-check.log`, `E3/final-integrity.json` |
| `P scripts/scan_private.py`(hejo) | 0 | 3차 보고서 포함 개인값 검사 통과 | `E3/scan-private.log`, `E3/scan-private.json` |

운영 main의 병합 후 HEAD와 최종 커밋은 모두 **`f3318572b9cbd85fccb54347872feca8915532cd`**다. fast-forward이므로 별도 merge 커밋은 없다. TASK-02에서 세 경로만 `git commit --only`로 기록한 커밋을 그대로 반영했으며, 중복·빈 커밋을 만들거나 커밋 종료 1을 성공으로 바꾸어 보고하지 않는다.

`sync`가 저장소에만 있던 새 시험을 제거했으므로, 교체 전 기록한 절차대로 해당 파일만 검토 커밋에서 복원했다. SHA-256은 `45e0938735953c1ae78158829bab864ab5e5b6f2f43b8416ef0a926252a0caa6`이며 실행본에는 새 시험을 추가하지 않았다(`E3/test-preservation.json`). 대상 세 파일의 HEAD 대비 차이는 없다.

수집 과정에서 이번 작업 밖 변경 10개(운영 owner 사본 3개, 플러그인 링크 사본 1개, 프로필 설정 사본 1개, 학습 사본 5개)가 드러났다. 운영 원본은 고치지 않았으며 이 사본들은 미커밋으로 보존했다. 스테이징한 변경은 없다. 실제 목록은 로컬 전용 `E3/after-sync-status.bin`에 있으며 공개 문서에는 프로필 식별자·값을 옮기지 않았다.

### 인계

배정된 TASK-03 서버 적용과 증거 수준 **3**의 읽기 확인을 마쳤다. 전체 회귀·수락 시험의 검토된 코드와 blob이 같아 TASK-02의 99개 통과·새 실패 0 증거를 재사용하며 같은 전체 시험은 반복하지 않았다. 운영 직원 설정·금고·명부의 원본, 본체·ddots·hejo gate/app, 수락 기준·시험 명세·spec·design은 수정하지 않았다. 외부 메시지·운영 연결 쓰기·푸시는 하지 않았다.

다음은 계획 담당의 TASK-03 result 검토 → 사장 M1~M3(다른 Mac hejo) → 현재 명세 반영 → 푸시 대상 확인·사용자 승인이다. 푸시 대상 제안은 이 검토 뒤 별도 단계이며, 이번 result는 제품 최종 완료나 푸시 완료 선언이 아니다. 롤백 보관본과 증거 폴더를 유지한다.


## 4차: TASK-05·06 구현·자체 시험 (2026-11-22)

### 착수와 범위

[확인] handoff 4차·spec/design/수락 명세 4판을 적용한다. 위험도 일반, 필요한 증거 수준 2. 이 절의 `E4`는 hejo 기준 `.build/finder-folders-evidence/round4`, `P`는 설치 facts에서 확인한 게이트웨이 환경 Python이다.

- TASK-05 worktree 브랜치 `hejo-finder-folders-20261121` 착수 HEAD: `f3318572b9cbd85fccb54347872feca8915532cd`, 작업 트리 깨끗함. 실행본 app_setup.py SHA-256 `eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6`으로 3차 적용값과 일치.
- TASK-06 hejo 착수 HEAD: `3e2dd7c32bcd5925c94a306d02cd0b2f16dae885`. 다른 작업의 gate 소스·수락 시험 변경은 건드리지 않는다.
- 착수 `hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py` SHA-256: `eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6`.
- 착수 `hermes/plugin-store/team-kit/tests/test_finder_folders.py` SHA-256: `45e0938735953c1ae78158829bab864ab5e5b6f2f43b8416ef0a926252a0caa6`.
- 착수 `app/Sources/ConnectionsWindow.swift` SHA-256: `a65e87bf14efb18487d6f578bf84fe6606e2828b04eb1a4fd9e47d098aba7b7a`.
- 착수 `app/Tests/ConnectionsTests.swift` SHA-256: `0c7557314d939f4cda053e6632c0d6773d8340e387a5f6b9685409d8c4bb63ad`.
착수 증거는 `E4/preflight.json`, 다른 작업 파일의 착수 지문은 로컬 전용 `E4/other-work.json`이다. 실행본 교체·운영 main 변경·sync·재시작·앱 버전/공개 후보/설치 앱 교체는 이번 배정 범위 밖이다.

### TASK-05 원인과 수정

[확인] 조합형 이름을 가진 임시 디스크 폴더와 완성형 요청이 같은 경로지만 문자열로 따로 남아, app_connect의 기존 NFC id 검사에서 중복으로 거절됐다. 새 AT-FF-15~17 시험은 수정 전 3개 모두 실패(기존 관련 99개 통과): 후보 중복 및 저장 시 SCOPE_INVALID. `E4/nfc-before.log`에 기록했다.

`finder_scopes`에서 원래 Path로 존재·디렉터리 확인을 유지하고 NFC 경로를 중복 판정 키로 사용했다. 후보 id/value/label과 메모리 selected.scope를 NFC로 맞춘다. 파일 권한 경계 files.py·files.inside 및 app_connect.selected_options는 그대로다. 새 시험은 조합형 임시 폴더의 후보·저장·미리 선택·재저장, 실제 file_list와 read_file_tool 및 기존 guard, 비슷한 이름의 이웃 폴더 거절을 검사한다. file_list가 반환하는 부모 path와 하위 항목 name을 그대로 이어 실제 반환 경로를 검사했다.

### TASK-06 수정 전 재현·원인

[확인] 제품 코드를 고치기 전에, 실제 PetPanel(대화 배치, 높이 25)과 실제 ConnectionsWindow(선호 높이 26)를 띄우고 가짜 문 waiting/secret_set 응답으로 입력 시트를 열었다. `E4/app-targeted.sh`(개발 시험 바이너리 빌드·실행) 종료 1, 관측값은 **대화 25·연결 0(.normal)·입력 시트 보임 true**였고 AT-FF-20이 실패했다(`E4/app-before.log`). 실제 운영 문 요청은 없다.

원인은 updateLevel이 confirming뿐 아니라 inputWindow/attachedSheet 존재만으로 높이를 0으로 내리는 조건이다. 높은 대화 패널 위로는 orderFront만으로 올라올 수 없다. 먼저 이 재현을 기록한 뒤 조건을 confirming만 남기고 show에서 높이를 다시 계산하도록 수정한다. 기존 확인 알림·인증 이후 restoreFocus 계약은 유지한다.

초기 시험 자료에는 행의 필수 checked_at가 없어 문서 디코딩에 실패했다. 제품 결함 재현으로 세지 않고 필드를 보충했다(`E4/app-fixture-initial.log`, 종료 1). 위 재현은 유효한 자료와 입력 시트가 실제 열린 상태에서 다시 얻은 결과다.

### TASK-05 검증·커밋

`E4/run_checks.py`는 2차와 같은 격리 환경으로 resolve한 임시 HOME·HERMES_HOME·HERMES_ROOT를 만든다. 게이트웨이 Python이 기존 기준 시험의 Python과 같음을 확인했다. 기존 시험 수정·skip 추가·운영 폴더 입력은 없다.

| 명령(작업 위치) | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `python3 E4/run_checks.py related`(hejo → team-kit worktree) | 0 | 새 AT-FF-15~17·기존 AT-FF-01~14·관련 5파일, **102 passed**, 4.51초 | `E4/related.log`, `E4/related.json` |
| `python3 E4/run_checks.py full`(동일) | 1 | **28 failed, 5013 passed, 64 skipped, 1 warning, 1 error, 58 subtests passed**, 160.90초 | `E4/full.log`, `E4/full.json` |
| FAILED/ERROR node 집합 비교(Python) | 0 | 기준 29개 = 현재 29개, 새 node 0. 정정된 AT-FF-12(나) 부분집합 조건 충족 | `E4/comparison.json` |
| `python3 E4/run_checks.py airport`(동일) | 0 | 게이트웨이 Python으로 `./airport-check --snapshot .`, 개인값·문서·칸 검사 통과. 기준선 수정 없음 | `E4/airport.log`, `E4/airport.json` |
| `git diff --check`(worktree) | 0 | 변경분 공백 오류 없음 | 커밋 실행 전 확인 |
| `git commit --only -m <NFC 중복 제거 이유> -- <app_setup.py·test_finder_folders.py 두 경로>`(worktree) | 0 | 지정 두 파일만 커밋, hook 통과 | `E4/team-commit.log`, `E4/team-commit.json` |

기준은 착수 HEAD `66f2a44c190390edd2a8a8eab9b2c32cba20195a`에서 같은 환경으로 이미 재현한 `E/baseline-failures.log`의 29개 집합을 재사용했다. 원래 전체 pytest 종료 1을 통과로 바꾸어 기록하지 않는다. AT-FF-03 실제 CLI 감사 훅도 위 관련·전체 시험에서 재실행됐다.

TASK-05 구현 커밋: **`e79900474219ac3dbd990e3e481e665909b6c06b`**. 이어 AT-FF-17의 저장 입력을 명세 그대로 섞인 형태 하나만 남겼다(NFC 복사본 없이도 미리 선택돼야 함). 관련·전체 시험을 다시 실행해 위 결과를 얻었고, 시험 파일만 `git commit --only`로 **`d7208c11c23ddb0dacddbe3e225864058f263006`**에 기록했다(종료 0, `E4/team-test-commit.log/json`). 최종 tip은 후자이며, 두 커밋을 합친 변경 경로는 app_setup.py와 새 시험 파일뿐이다. 최종 시험 뒤 내용 수정 없이 커밋했고 파일·커밋 blob을 대조했다. 아래는 최종 SHA-256이다.

- `hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py`: `12aeddba77c4052f35714800eea1c63c06587d0666d9b2baa3e49214817aa3ab`.
- `hermes/plugin-store/team-kit/tests/test_finder_folders.py`: `6f44156030bbe7934b06e7475dd385cbc399ada33d9ebedee40371338405740f`.

### TASK-06 수정 후 자체 시험

[확인] `bash E4/app-targeted.sh` 종료 **0**, 수정 후 같은 배치의 관측은 **대화 25·연결 26·입력 시트 보임 true**다(`E4/app-after.log`). AT-FF-20~23, 기존 AT-HC-20~29와 AT-CM-30~38이 모두 통과하고 APP_TEST_OK다.

- 입력 시트가 붙어도 선호 높이 26을 유지한다(AT-FF-20).
- orderBack 및 오래된 `.normal` 높이를 만든 뒤 show를 부르면 높이를 다시 계산하고 입력 시트와 함께 보인다(AT-FF-21).
- 입력 위의 실제 NSAlert 재시작 시트를 취소하는 동안만 `.normal`이고, 닫히면 26으로 복구한다. 인증 대역의 승인·취소 양쪽에서 같은 높이·포커스 복구를 확인했다(AT-FF-22, 기존 CM-35).
- 비활성 선호 높이 `.normal`을 주면 입력을 열어도 그대로다(AT-FF-23).

입력 때문에 별도로 `.normal`이어야 하는 이유는 이 시험 범위에서 재현되지 않았다. 실제 지문·암호 시스템 창과 자동 채움 UI는 호출하지 않았으므로 이 결과를 실물 검증으로 주장하지 않는다. 요구된 증거 수준 2이며 사장 확인은 후속 단계다.

### 전체 hejo 검사 환경 보완

첫 실행은 게이트웨이 Python에 pytest 경로를 붙이지 않아 `No module named pytest`로 종료 1(`E4/hejo-env-initial.log`). 기존 로컬 검증 환경에 맞춰 pytest·team-kit·검증 의존 경로를 연결했다. 라이브러리 경로가 없는 시도는 2 failed·225 passed·199 errors로 종료 1(`E4/hejo-library-initial.log`), 라이브러리를 붙인 시도는 227 passed·199 errors로 종료 1(`E4/hejo-long-path.log`)이었다.

남은 오류는 다른 작업이 추가한 Unix 소켓이 pytest 기본 임시 경로에서 macOS 경로 길이 제한에 걸린 것이다. 소스 수정 없는 예외 관측으로 `OSError: AF_UNIX path too long`을 확인했다(`E4/socket-fixture-diagnostic.log`, 진단 pytest 종료 1). 그 작업의 gate/코드는 건드리지 않고, 새로 만든 짧은 시험 전용 임시 디렉터리를 PYTEST_ADDOPTS의 --basetemp로 지정해 같은 전체 명령을 다시 실행했다. 시험 기대값·skip·제품 소켓 위치는 바꾸지 않았다.

### TASK-06 전체 결과·커밋·동시 작업의 범위

| 명령(hejo cwd) | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `HEJO_PYTHON=P bash scripts/test.sh`(위 라이브러리·짧은 임시 경로 환경) | **0** | gate/수락 pytest **426 passed**, 기존 경고 1개. gateway_delivery, 앱 개발 빌드·서명 검사, 앱 전체 본시험과 네트워크 fixture, hooks 9개 모두 통과. 실제 설정 메타데이터·Downloads 이름 보존 검사 통과 | `E4/hejo-full.log`, `E4/hejo-full.json`, `E4/hejo-test-env.json` |
| `bash E4/app-targeted.sh` | 0 | AT-FF-20~23·AT-HC-20~29·AT-CM-30~38, APP_TEST_OK | `E4/app-after.log` |
| `P -m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider`(짧은 임시 경로) | 0 | 다른 작업의 추가 변경 뒤 실행: **428 passed**, 경고 1개. 아래 동시 수정 제한 있음 | `E4/gate-current.log`, `E4/gate-current.json` |
| `git diff --check -- app/Sources/ConnectionsWindow.swift app/Tests/ConnectionsTests.swift` | 0 | 앱 변경분 공백 오류 없음 | 커밋 실행 전 확인 |
| `git commit --only -m <창 높이 수정 이유> -- app/Sources/ConnectionsWindow.swift app/Tests/ConnectionsTests.swift` | 0 | 앱 두 경로만 기록 | `E4/app-commit.log`, `E4/app-commit.json` |

TASK-06 커밋 전체 해시: **`b21dd94528981dddcfa98e5a9883e864442d243d`**. 부모는 `2911232cbea8c0e48fc26aeca2b925050194bd13`다. 착수 후 다른 작업의 gate 커밋이 들어왔지만 앱 두 파일의 수정 범위는 겹치지 않았다. 본 커밋 diff는 지정 앱 두 파일뿐이며 보고서는 이 커밋에 포함하지 않았다. 시험 후 앱 코드 변경 없이 커밋했고 파일·blob SHA-256이 같다.

- `app/Sources/ConnectionsWindow.swift`: `ab0465c84410cfb46c12f375fc576dc9356da202d790c6e480458a258d38fe86`.
- `app/Tests/ConnectionsTests.swift`: `d3b9e5a72c8a9f6ed944e533b5debdd6701738c36af64abe3a84a40eece563c6`.

[제한] 같은 저장소의 HEJO-SLACK-MOVE 담당이 검사 중에도 gate/local.py·adapter.py·rooms.py 및 해당 수락 시험을 수정했다. 추가 gate 검사도 전후 지문이 달랐다(`E4/gate-current.json`). 따라서 위 전체 명령 종료 0을 **이후 최신 gate 전체 변경본에 대한 고정 검증**으로 확대하지 않는다. 이번 앱 두 파일은 집중 시험과 전체 앱 시험에서 같은 바이트로 검증됐고, 다른 작업의 코드·시험·명세를 고치거나 이번 커밋에 섞지 않았다. 공개 후보를 만들 때 두 작업의 최종 통합 상태를 다시 확인해야 한다.

### 보존·남은 작업

TASK-05·06 배정 범위의 구현·자체 시험을 마쳤으며 계획 담당 검토 대기다. 증거 수준은 **2**다. 파일 도구 시험은 임시 HOME·HERMES_HOME의 가짜 자료만 사용했고, 앱 시험은 가짜 문·인증 대역과 실제 AppKit 창을 사용했다. 운영 문에 연결 동작을 보내지 않았고 실제 서버 폴더·직원 값을 시험에 넣지 않았다.

운영 main은 `f3318572b9cbd85fccb54347872feca8915532cd`, 실행본 app_setup.py는 착수 SHA-256 그대로다(`E4/team-final-integrity.json`). team-kit worktree는 최종 커밋 뒤 깨끗하다. files.py·files.inside·app_connect.selected_options·Hermes 본체·ddots, 수락 기준·시험 명세·spec·design, 앱 버전은 수정하지 않았다. sync·재시작·실행본 교체·설치 앱 교체·공개·push는 미실행이다.

다음은 계획 담당의 두 구현 커밋 범위·증거 검토 → 별도 TASK-07 실행본 적용·TASK-08 공개 후보 지시 → 사장 M1~M6 → 현재 명세 반영 → 푸시 승인이다. TASK-05의 운영 적용 대상 tip은 `d7208c11c23ddb0dacddbe3e225864058f263006`, TASK-06 앱 커밋은 위 해시다. 이 보고는 제품 최종 완료·운영 반영·푸시 완료 판정이 아니다.

최종 문서 검사: `P scripts/scan_private.py` 종료 0(`E4/scan-private.log`), 자기 변경 경로 `git diff --check` 종료 0(`E4/report-diff-check.log`). 최종 보고서 지문과 검사 결과는 `E4/final-report-checks.json`에 보관했다.

## 5차-TASK-07: NFC Finder 후보 실행본 적용

위험도 일반, 증거 수준 3. 아래 `E5`는 `.build/finder-folders-evidence/round5-task07`이며 `P`는 설치 메타데이터로 확인한 게이트웨이 Python이다.

### 착수 확인과 적용 전 롤백 기록

- 운영 main 착수 HEAD: `f3318572b9cbd85fccb54347872feca8915532cd`. 대상 브랜치 tip: `d7208c11c23ddb0dacddbe3e225864058f263006`. hejo 착수 HEAD: `d1668653d3b30bbbefe841d48dc9fd7ff6142c68`.
- 실행본 및 운영 HEAD의 app_setup.py SHA-256: `eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6`. 적용할 blob SHA-256: `12aeddba77c4052f35714800eea1c63c06587d0666d9b2baa3e49214817aa3ab`. 일치 확인 후 진행한다.
- 작업 밖 미커밋 목록 10개는 로컬 전용 `E5/operating-status-before.local`에 보관하고 커밋하지 않는다.
- 보관 디렉터리 `.build/finder-folders-evidence/round5-task07/rollback-cntadfts`는 권한 0700, app_setup.py 사본은 0600이며 SHA-256은 착수값과 같다. `E5/deployment.json`에 파일 모드와 복원 전후 해시를 적었다.
- **적용 전 작성한 복원 절차:** 검사 실패 시 `P E5/restore.py`로 사본 해시 확인 → 실행본 같은 디렉터리의 임시 파일에 쓰기·fsync·기존 모드 적용 → 이름 바꾸기 → 착수 해시 재확인. 이어 status·apps를 다시 확인하고 중단한다. 복원 스크립트는 준비만 했고 아직 실행하지 않았다.
- 적용은 `python3 E5/apply_and_check.py`가 동일한 임시 파일·이름 바꾸기로 app_setup.py 한 파일만 수행한다. status/apps 원문은 남기지 않고 종료 코드·schema만 기록한다. Finder는 실제 HOME에서 읽기 전용 1회, 수치와 NFC 참/거짓만 남긴다.
- merge 뒤 plain `./sync`는 실행본 → 저장소 방향이다. 실행본에 없는 새 시험 파일이 수집에서 사라지면 검토된 대상 커밋의 `tests/test_finder_folders.py` blob만 저장소에 복구한다. 시험 코드를 실행본에 설치하지 않는다. 자기 경로가 이미 HEAD와 같으면 빈 커밋은 만들지 않는다.

### TASK-07 실행 결과

| 명령 | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `python3 E5/apply_and_check.py` | 0 | 단일 파일 원자 교체 및 적용 해시 확인 | `E5/apply.log`, `E5/applied.json` |
| `hermes-connections status --json` / `apps --json` | 각각 0 | 예상 schema 확인, stderr 0바이트 | `E5/live-checks.json` |
| `P -B -c <실행본 finder_scopes 읽기 전용 1회>` | 0 | 후보 **75**, **0.111216초**, hint 없음, id/value 모두 NFC **true** | `E5/finder-metrics.json` |
| `git merge --ff-only hejo-finder-folders-20261121`(운영 저장소) | 0 | app_setup.py와 저장소 시험만 fast-forward | `E5/merge.log`, `E5/merge.json` |
| `./sync`(운영 저장소, 옵션 없음) | 0 | 실행본 → 저장소 수집. 저장소 전용 시험은 검토된 blob으로 복구 | `E5/sync.log`, `E5/sync.json` |
| `./airport-check`(운영 저장소, 게이트웨이 Python PATH) | 0 | 기준선 변경 없이 통과 | `E5/airport-check.log`, `E5/airport-check.json` |
| 자기 두 경로 `git diff --check`(운영 저장소) | 0 | 공백 오류 없음 | `E5/diff-check.log` |

후보 종류별 개수: Synology 10, iCloud 65, 기타 CloudStorage 0, 기타 0. 뿌리 종류별 개수: Synology 2, iCloud 1, 기타 0. 이름·경로는 기록하지 않았다.

운영 main 최종 전체 커밋: **`d7208c11c23ddb0dacddbe3e225864058f263006`**. merge 전후와 파일/커밋 blob은 `E5/final-integrity.json`에 기록했다. 지정 두 경로가 이미 HEAD와 같아서 추가 `git commit --only`는 실행하지 않았다(빈 커밋 금지). app_setup.py 실행본·저장소·커밋 SHA-256이 모두 적용값과 같으며 app_connect.py는 착수값 그대로다. 작업 밖 미커밋은 착수 10개에서 11개로 늘었으며 모두 커밋하지 않았다. 차이는 로컬 전용 전후 status 파일에 남겼다.

게이트웨이 pid·시작 식별자 불변, 복원 미실행. 보관본과 복원 절차는 유지한다. 게이트웨이가 요청마다 호출하는 CLI 자식 프로세스의 실행본 lib를 확인했으며, 게이트웨이 재시작·운영 app connect·메시지·앱 교체·릴리스·push는 실행하지 않았다. 사장 직원 A 설정 재저장·M5는 아직 남아 있다.

## 5차-TASK-09: 세 손가락 탭 구간 측정

착수 hejo HEAD: `fa0622250825112adad0e7a93df6345ec0df3d02`. 작업 도중 확인한 5차 정정 인계에 따라 실제 탭 대신 프레임 주입으로 진행한다. 위험도 일반, 증거 수준 **2**이며 실제 탭 M7은 설치 후 사장 확인으로 남긴다. 아래 `E9`는 `.build/finder-folders-evidence/round5-task09`다. 착수 소스 SHA-256은 `E9/preflight.json`, 수정 전 계측 소스 지문·사본은 `E9/before-source.json`과 `E9/before-source/`다.

### 측정 준비·격리

`HEJO_THREE_TAP_TRACE`가 `.build/` 아래 출력 파일을 가리킬 때만 구간 시각을 기록한다. 기본값은 꺼짐이다. 숫자 시각·열기 여부만 기록하며 좌표·기기 식별자·대화·실제 경로는 기록하지 않는다. 기록 쓰기는 애니메이션 완료 후 별도 큐로 보낸다. 판정 규칙과 애니메이션 길이를 아직 고치지 않았다.

`app/Tests/build_three_tap_latency.sh`는 AppDelegate 원문과 시험 전용 확장을 같은 파일로 이어 private 의존 자료만 가짜로 조립한다(제품의 접근 제어·메서드 본문을 치환하지 않음). 임시 LocalStore와 메모리 자격 대역, 가짜 직원·대화 20개를 사용하고 네트워크 연결·캘린더·운영 모니터·업데이트는 시작하지 않는다. 실제 AppDelegate.openBubble/refreshPetActivity 및 ConversationView, PetController를 사용한다. 고정 가짜 대상을 여는 클릭 콜백·확장 콜백은 평상시 시작과 같은 순서다.

읽기 대역은 기기 열거·콜백 등록 심벌만 제공한다. `ThreeTapReader.start()`가 실제로 등록한 C callback에 별도 읽기 큐에서 96바이트 접촉 3개(착지)와 80ms 뒤 0개(뗌)를 전달한다. 따라서 실제 `ThreeTapReader.callback → receive → ThreeTapFrames/ThreeTapGesture → DispatchQueue.main.async → ThreeTapController.tapped → PetController.threeFingerTapped → pet.onClick → AppDelegate.openBubble/접기 → setExpanded`를 지난다. 1.2초 이상 간격으로 열기·닫기 각 10회다.

시각 기준은 읽기 함수 입구의 systemUptime(해당 프레임이 탭으로 판정된 경우만 보존), 판정 직후, 메인 큐 작업 시작, setExpanded 진입, 첫 nonzero genie 갱신, 애니메이션 완료다. 첫 움직임은 앱 내부에서 첫 변화 프레임을 제출한 시점이며 물리 화면의 발광을 외부 장치로 잰 값은 아니다. 추가로 캡처·확장 콜백·타이머 대기 구간을 계측한다.

정정 전 준비한 실물용 진단 빌드는 종료 0이나 실행하지 않았다(`E9/diagnostic-build-before.log/json`). 사용자에게 직접 탭할 필요 없음을 안내했고, 정정된 주입 빌드로 측정을 진행한다.

### 수정 전 측정 결과와 중단 판단

`bash app/Tests/build_three_tap_latency.sh` 종료 0(`E9/injected-build-before.log/json`). `HEJO_THREE_TAP_TRACE=E9/before.jsonl app/.build/three-tap-diagnostic/three-tap-diagnostic <개발 리소스>` 종료 0, 주입 **20회(열기 10·닫기 10)** 완료(`E9/before-run.log/json`). `python3 app/Tests/three_tap_latency.py E9/before.jsonl` 종료 0, 원시 시각·요약은 `E9/before.jsonl`, `E9/before-summary.json`이다. 빌드 전 `pgrep -f app-tests`는 종료 1(다른 앱 시험 없음).

단위 ms, 각 칸은 중앙값 / 최댓값이다.

| 구간 | 열기 10회 | 닫기 10회 |
|---|---:|---:|
| 손 뗀 프레임 → 판정 | 0.008 / 0.011 | 0.008 / 0.020 |
| 판정 → 메인 큐 시작 | 0.038 / 0.669 | 0.037 / 2.277 |
| 메인 큐 시작 → setExpanded | 58.651 / 63.914 | 0.009 / 0.021 |
| setExpanded → 첫 움직임 | 100.820 / 223.201 | 147.565 / 170.273 |
| 첫 움직임 → 애니메이션 완료 | 288.855 / 307.565 | 304.027 / 362.709 |
| 손 뗀 프레임 → 첫 움직임 | 162.059 / 281.081 | 147.605 / 170.335 |
| 화면 캡처(위 구간에 포함) | 21.050 / 69.867 | 28.449 / 35.129 |
| 확장 콜백(위 구간에 포함) | 52.326 / 79.642 | 76.928 / 89.565 |
| 타이머 시작 → 첫 움직임(위 구간에 포함) | 18.478 / 55.987 | 18.968 / 22.299 |

[확인] 첫 움직임까지 중앙값은 열기 **162.059ms**, 닫기 **147.605ms**로 100ms를 넘는다. 판정·메인 큐 전달은 각각 1ms 미만이다. 첫 움직임 전 가장 큰 구간은 setExpanded 내부이며(열기 100.820ms·닫기 147.565ms), 그 안의 확장 콜백이 52.326ms·76.928ms를 차지한다. 열기 전 AppDelegate.openBubble의 준비도 58.651ms다.

[코드 확인] PetController.setExpanded에서 onDrawerStateChanged → onExpansionChanged가 동기로 호출된다. 전자는 ConversationController.setDrawerState의 onChange, 후자는 AppDelegate에서 ConversationView.folded(닫기) 및 ConversationModel.setVisible를 거쳐 여러 차례 onChange를 발생시킨다. ConversationView에 설치된 onChange는 refresh를 즉시 실행하며, openFromBubble도 refresh한다. [추론] 같은 사용자 동작의 중간 상태마다 대화 화면을 다시 만드는 비용이 첫 움직임 전 지연의 주요 원인 후보다. 각 개별 refresh의 독립 비용·호출 횟수까지 계측하지 않았으므로 이를 확정된 단일 병목으로 확대하지 않는다.

**중단 조건:** spec REQ-FF-07 AC-03은 “측정에서 애니메이션이 지연의 대부분이면 멈추고 보고”라고 지정했다. 첫 움직임 뒤 구간 중앙값은 열기 288.855ms·닫기 304.027ms로 단일 구간 중 가장 크며, 기존 genieDuration 0.30초와 부합한다. 이 조건에 따라 성능 동작 수정은 중단했다. 탭 규칙·애니메이션 길이·화면 갱신 순서를 임의 변경하지 않았다. 따라서 수정 후 측정은 **미실행**, AT-FF-30은 수정 전 절반만 완료, AT-FF-31은 **미실행/미충족**이다. 이 보고를 지연 개선 완료로 보지 않는다.

검토할 선택지: (1) 애니메이션 0.30초를 유지하고 **첫 움직임 전 지연**만 목표로 삼도록 중단 조건을 분명히 한 뒤, ConversationView/ConversationController/ConversationModel의 갱신 묶음 처리까지 범위를 열어 중복 화면 갱신을 원래 책임 자리에서 줄이기; (2) 사장이 애니메이션 길이·동작 변경을 결정하고 별도 수락 기준으로 진행. 구현자의 권고는 (1)이다. 현재 탭 판정·큐 전달은 지연 근거가 작으므로 이를 조정하거나, 화면 갱신을 임의 지연시켜 오래된 화면을 먼저 띄우는 우회는 하지 않는다. 판단 대기 중에는 측정 코드 회귀 시험·개인값 검사·기록만 마무리한다.

### 진단 경로 검사 보완

첫 `HEJO_PYTHON=P bash app/scripts/test.sh`는 종료 **1**이었다(`E9/app-full-initial.log/json`, 검사 중 앱 소스 변화 없음). 기존 시험에서 AT-FF-20~23 등은 통과했으나, 새 진단 경로 시험 `tap tracing rejects symlink escape`가 실패해 이후 시험·네트워크 fixture는 실행되지 않았다. 통과로 간주하지 않는다.

[재현] Foundation이 아직 없는 출력 파일까지 포함한 URL을 resolvingSymlinksInPath로 처리하면 중간 링크가 남았다. 별도 최소 재현에서 전체 경로는 `.build`를 유지했지만 기존 부모 디렉터리만 해석하면 밖으로 풀렸다. 실제 외부 로그 파일을 쓰지 않고 경로 함수만 검사했다.

진단 설정을 읽을 때 **이미 존재하는 부모 디렉터리**를 먼저 해석하고 `.build` 아래인지 확인하도록 고쳤다. 출력 파일 자체가 링크이면 거부한다. 출력 폴더는 실행자가 미리 만들어야 하며, 기본 꺼짐·없는 부모·부모 링크 탈출·아직 대상이 없는 파일 링크를 검사한다. `xcrun swiftc <진단 소스·최소 시험>` / `E9/trace-path-tests`는 각각 종료 **0**, TRACE_PATH_GUARDS_PASS(`E9/trace-path-check.log/json`). 이 보완은 기록 경로 검사만 바꾸며 탭·창 전환 성능 수정은 아니다. 다시 `pgrep -f app-tests` 종료 1을 확인한 뒤 전체 앱 시험을 재실행했다.

### TASK-09 회귀·커밋·인계

| 명령(hejo cwd) | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `HEJO_PYTHON=P bash app/scripts/test.sh`(보완 후) | **0** | 개발 빌드·서명, 앱 본시험 APP_TEST_OK, 기존 ThreeTap/펫 클릭·창 시험, AT-FF-20~23, 통신 fixture, hooks 9개 및 실제 설정 메타데이터·Downloads 이름 보존 검사 통과 | `E9/app-full.log/json` |
| `P scripts/scan_private.py`(새 경로 intent-to-add 뒤) | 0 | 새 계측·시험 파일까지 검사 | `E9/scan-private-code.log/json` |
| 자기 앱 경로 `git diff --check` | 0 | 새 파일 포함 공백 오류 없음 | 실행 결과 및 `E9/diff-check.log` |
| `git commit --only -- <자기 앱 7경로>` | 0 | 계측·시험만 커밋 | `E9/app-commit.log/json` |

앱 계측·시험 커밋 전체 해시: **`3ccda920f77530580c69d367da95d241c7da26ff`**. `E9/app-tested-source.json`은 전체 시험이 읽은 앱 소스·시험의 지문이며 검사 중 변경은 0개다. 자기 7개 파일의 최종 커밋 blob과 시험한 바이트가 같음을 확인했다(`E9/app-commit.json`). 커밋은 ThreeTapDiagnostics.swift(기본 꺼짐 숫자 계측), ThreeTapReader.swift(실제 읽기·메인 큐 시각), PetController.swift(확장·캡처·첫 프레임·완료 시각), ThreeTapTests.swift(진단 저장 경계), 시험 전용 주입 harness·빌드 스크립트·집계 스크립트뿐이다. 기존 시험 기대값을 바꾸지 않았다.

AT-FF-32 회귀는 통과했다. AT-FF-30 수정 후 표와 AT-FF-31 개선 기준은 중단 사유로 아직 미충족이다. 실제 탭·체감 M7은 미실행이다. 진단 빌드 스크립트는 개발 앱의 Pet 리소스와 Sparkle 프레임워크를 사용하므로, 재현 시 먼저 `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh` 또는 위 전체 시험으로 개발 산출물을 준비한다. 임시 자료만 쓰며 운영 문·실제 직원 자료를 불러오지 않는다.

TASK-07은 적용·자체 검증을 마쳤고 계획 담당 검토를 기다린다. TASK-09는 수정 전 계측·회귀만 완료한 **부분 결과**다. 다음 담당자는 중단 조건 해석과 대화 화면 갱신 책임 파일의 범위를 결정해야 한다. TASK-08 공개 후보는 이번 결과만으로 착수하지 않는다. hejo main의 다른 작업 커밋과 새 감사 문서가 함께 존재하므로, 향후 푸시·공개 대상 확정 때 포함 범위를 다시 확인해야 한다. 이번 앱 커밋과 보고서 변경에는 gate/·schemas/·다른 작업 문서를 넣지 않았다.

기존 ThreeTap 판정 규칙, ChatMorph.genieDuration, AppDelegate·PetView의 제품 동작, 수락 기준·시험 명세·spec·design, 앱 버전·설치 앱·Hermes 본체·ddots를 바꾸지 않았다. TASK-07의 명시 허가된 app_setup.py 교체 외 추가 실행본 교체·재시작·문 릴리스·운영 app connect·실제 메시지·push는 없다. 문서 최종 검사 명령·종료 코드·지문은 `E9/final-report-checks.json`에 남긴다.

## 6차-TASK-09 — 동기 갱신 묶음과 재측정

### 착수·판단

받은 설계는 handoff.md 6차, spec 5판 REQ-FF-07 AC-03·04다. 위험도 일반, 증거 수준 2(접촉 프레임 주입), 직접 구현·자체 시험이다. 착수 hejo main HEAD는 `a2ce8ea67d831fcb3a26d4b2d467e3f1f7f50ef8`. 다른 작업의 HEJO-SLACK-MOVE 문서 변경과 HEJO-AUDIT 새 폴더를 보존했다. TASK-07 완료 작업을 반복하지 않았다.

이 절의 `E6`은 hejo `.build/finder-folders-evidence/round6-task09`, `E9`는 앞 절의 round5-task09, `P`는 앞서 확인한 게이트웨이 Python이다. 착수 HEAD·미커밋 목록·주요 소스 SHA-256은 `E6/start.json`, 자기 7경로의 전후 전체 SHA-256은 `E6/change-integrity.json`에 있다. 전체 시험이 읽은 소스·시험 지문은 `E6/app-tested-source.json`이다.

**구현자 판단: 부분 구현.** 중복 화면 갱신은 한 번으로 모았고 첫 움직임 중앙값은 양쪽 모두 감소했지만, 열기 117.072ms·닫기 136.374ms로 AT-FF-31의 100ms 기준을 충족하지 못했다. handoff 6차 5항에 따라 남은 구간을 보고한다. 애니메이션·탭 판정 변경이나 기준 완화로 우회하지 않았다.

### 먼저 측정한 호출 횟수·비용

커밋 3ccda92의 실제 읽기 콜백 주입 harness를 그대로 사용했다. 제품 진단 설정 `HEJO_THREE_TAP_TRACE`가 켜진 경우에만 숫자 span을 더 기록한다. 모델 onChange가 컨트롤러에 들어오는 콜백, 컨트롤러 onChange가 뷰에 들어오는 콜백, 실제 refresh 본문의 횟수와 각 시간을 측정했다. 콜백 비용은 그 안의 refresh를 포함하므로 아래 행들을 더하지 않는다. 전체 컨트롤러 onChange 후속 구독자 비용을 독립적으로 측정한 값은 아니다.

수정 전 첫 열기·첫 닫기(`E6/first-pair-profile.json`, ms):

| 호출 | 열기 횟수·각 비용 | 닫기 횟수·각 비용 |
|---|---|---|
| 모델 onChange 콜백 | 2회: 22.517, 21.944 | 2회: 15.653, 9.553 |
| 컨트롤러 onChange의 뷰 콜백 | 3회: 27.919, 22.119, 21.531 | 4회: 36.737, 15.169, 10.428, 9.171 |
| 실제 refresh | 4회: 55.228, 27.917, 22.118, 21.530 | 4회: 36.735, 15.168, 10.428, 9.170 |

열기·닫기 각 10회까지 기록했다. 수정 전 열기는 첫 회 4회·이후 3회, 닫기는 매번 4회 갱신했다. 수정 후에는 양쪽 모두 매번 컨트롤러의 뷰 콜백 1회·refresh 1회였다. refresh 합계 중앙값은 열기 104.834→52.487ms, 닫기 73.234→24.010ms다(`E6/profile-counts.json`). 모델의 선택·읽음 등 부수 효과는 그대로 수행하고 화면 알림 전달만 묶는다.

[확인된 원인] openFromBubble의 직접 갱신, 서랍 확장 알림, 모델 표시·읽음 알림이 같은 열기 동작의 중간 화면을 각각 다시 만들었다. 닫기에서도 서랍·새 글 선택·folded·표시 상태 변경의 알림이 연달아 화면을 만들었다. 중복 갱신을 제거한 실측에서 전체 첫 움직임 지연이 줄었다. 이것을 유일한 지연 원인으로 단정하지 않는다.

수정 전 계측 빌드의 정확한 변경 소스 3개는 `E6/profile-sources/`, 착수본과의 관계 및 실행 전에 저장한 SHA와의 일치는 `E6/profile-source-reconstruction.json`에 있다. 나머지는 착수 HEAD와 같다. `E6/profile-source.json`은 측정 전 저장한 전체 앱 소스 지문이다.

### 변경 구조·동작 보존

- `ConversationController.swift`: 명시적인 동기 performUpdates 범위 안에서만 notifyChange를 모은다. 중첩 묶음의 마지막에 한 번 전달한다. 범위 밖에서는 종전처럼 즉시 onChange를 호출한다. 기존 직접 알림 호출 지점들을 같은 경로로 교체했다. ConversationModel의 상태 변경·읽음·저장은 수정하지 않았다.
- `ConversationView.swift`: 묶음 중 직접 refresh도 같은 알림으로 합친다. openFromBubble의 스크롤은 최종 refresh 직후 같은 호출 스택에서 맞춘다. 묶음 밖의 동작은 즉시 처리한다. 모델·컨트롤러·뷰 계측은 기본 꺼짐이다.
- `PetController.swift`, `AppDelegate.swift`: openBubble의 선택 준비를 확장 콜백과 같은 동기 묶음 안에서 실행한다. 최종 화면 갱신과 스크롤을 끝낸 뒤 기존 배치·열기 캡처를 수행한다. 이미 열린 창에서 다른 말풍선을 선택하는 준비도 실행한다. 닫기는 종전처럼 접기 전의 마지막 열린 화면을 먼저 캡처한다. 애니메이션 중 반전 시 현재 그림을 유지하는 기존 경로는 바꾸지 않았다.
- `ThreeTapDiagnostics.swift`: 활성 진단 샘플에 고정된 단계명·횟수·초만 기록한다. 실제 대화·직원·폴더 값을 기록하지 않는다.
- `ConversationUpdateTests.swift`, `TestMain.swift`: 가짜 대화에서 종전의 즉시 처리 순서와 실제 PetController의 묶음 처리 결과를 비교하는 시험을 추가했다. 열기·접기·재열기·열린 상태의 다른 스레드 선택에 대해 방·스레드 의미, 초안 선택·문구, 읽음 수, 서랍 표시, 카드 id·확장·답장 대상·구성 수를 비교한다. 최종 갱신이 열기 캡처보다 먼저 끝남, 닫기 그림 유지, 중첩 묶음 1회 전달, 묶음 밖 즉시 전달도 검사한다. 기존 시험 기대값은 수정하지 않았다.

새 원본·저장소·비동기 지연 갱신·임시 우회 경로는 없다. 동작 보존 리팩토링이며, 같은 사용자 동작 중간의 알림 횟수만 줄인다. mutation check는 별도 실행하지 않았다. 실제 창 경로와 이전 처리 순서의 결과 비교·기존 회귀·전후 주입 측정을 증거로 사용한다.

### AT-FF-30 전후 표

열기 10회·닫기 10회, 단위 ms, **중앙값 / 최대값**. 수정 전은 3ccda92의 `E9/before.jsonl`, 수정 후는 `E6/after.jsonl`이다. 이번 추가 계측만 넣은 수정 전 재측정도 첫 움직임 중앙값 열기 161.762ms·닫기 159.149ms였다(`E6/profile-before-summary.json`). 표에서 유리한 회차를 골라 빼지 않았다.

| 구간 | 열기 전 | 열기 후 | 닫기 전 | 닫기 후 |
|---|---:|---:|---:|---:|
| 손 뗀 프레임 → 판정 | 0.008 / 0.011 | 0.009 / 0.013 | 0.008 / 0.020 | 0.010 / 0.062 |
| 판정 → 메인 처리 | 0.038 / 0.669 | 0.053 / 0.063 | 0.037 / 2.277 | 0.053 / 0.217 |
| 메인 처리 → setExpanded | 58.651 / 63.914 | 0.013 / 0.113 | 0.009 / 0.021 | 0.017 / 0.019 |
| setExpanded → 첫 움직임 | 100.820 / 223.201 | 116.994 / 185.459 | 147.565 / 170.273 | 136.333 / 179.735 |
| 첫 움직임 → 전환 끝 | 288.855 / 307.565 | 303.578 / 334.934 | 304.027 / 362.709 | 285.560 / 306.390 |
| 손 뗀 프레임 → 첫 움직임 | 162.059 / 281.081 | 117.072 / 185.627 | 147.605 / 170.335 | 136.374 / 179.805 |
| genie 캡처 | 21.050 / 69.867 | 20.123 / 50.688 | 28.449 / 35.129 | 32.334 / 36.244 |
| 확장 콜백 묶음 | 52.326 / 79.642 | 63.669 / 68.198 | 76.928 / 89.565 | 27.714 / 30.950 |
| 타이머 등록 → 첫 움직임 | 18.478 / 55.987 | 18.334 / 45.687 | 18.968 / 22.299 | 44.518 / 72.511 |

선택 준비가 setExpanded 진입 뒤 동기 묶음으로 옮겨졌으므로 열기의 “메인 처리→setExpanded” 감소만으로 성능을 판단하면 안 된다. 수정 후 “확장 콜백 묶음”에는 그 준비 비용도 포함된다. 판정 기준은 이동하지 않은 전체 “손 뗀 프레임→첫 움직임”이다. 첫 움직임은 기존 계측처럼 내부 첫 genie 갱신 시각이며 물리 디스플레이 제시 시각이나 실물 탭 실측은 아니다.

AT-FF-31 비교는 **종료 1, 양쪽 미충족**(`E6/compare-result.json`, 값은 `E6/compare.json`). 기준 기록보다 열기 44.987ms(27.8%), 닫기 11.231ms(7.6%) 감소했지만 각각 100ms보다 17.072ms·36.374ms 크다. 닫기 최대값은 170.335→179.805ms로 더 컸으며 개선으로 표시하지 않는다.

남은 구간: 열기는 최종 갱신·준비 콜백 묶음 63.669ms(그 안의 refresh 52.487ms), 캡처 20.123ms, 타이머 등록→첫 움직임 18.334ms. 닫기는 캡처 32.334ms, 콜백 묶음 27.714ms(refresh 24.010ms), 타이머 등록→첫 움직임 44.518ms다. 타이머 구간에는 등록 뒤 남은 메인 작업·그리기와 실행 대기가 섞이므로 타이머 자체 지연으로 단정하지 않는다. 각 구간 중앙값은 서로 다른 표본에서 정해질 수 있어 합계가 전체 중앙값과 같지는 않다. 다음 판단은 최종 refresh 내부 비용과 닫기 첫 프레임 전 메인 작업을 더 나눌 범위이며, 애니메이션 길이나 수락 기준을 바꿀 근거로 삼지 않는다.


### 검증·커밋·인계

| 명령(hejo cwd) | 종료 코드 | 확인한 결과 | 로그 |
|---|---:|---|---|
| `bash app/Tests/build_three_tap_latency.sh` (계측만 추가 / 동작 수정 후) | 0 / 0 | 개발 진단 빌드·서명 | `E6/profile-build.log/json`, `E6/after-build.log/json` |
| `pgrep -f app-tests` (두 주입 실행 / 전체 시험 전) | 각 1 | 다른 앱 시험 프로세스 없음 | `E6/profile-pgrep.json`, `E6/after-pgrep.json`, `E6/app-pgrep.json` |
| `HEJO_THREE_TAP_TRACE=E6/profile-before.jsonl diagnostic <개발 리소스>` | 0 | 변경 전 계측 20행 | `E6/profile-run.log/json`, `E6/profile-before.jsonl` |
| `HEJO_THREE_TAP_TRACE=E6/after.jsonl diagnostic <개발 리소스>` | 0 | 변경 후 계측 20행 | `E6/after-run.log/json`, `E6/after.jsonl` |
| `python3 app/Tests/three_tap_latency.py E9/before.jsonl --after E6/after.jsonl` | **1** | AT-FF-30 전후 집계 완료, AT-FF-31 양쪽 100ms 미충족 | `E6/compare.json`, `E6/compare-result.json` |
| `HEJO_PYTHON=P bash app/scripts/test.sh` | **0** | 개발 앱 빌드·서명, APP_TEST_OK, AC-04 상태 비교, 기존 ThreeTap·펫 클릭/창·AT-FF-20~23, 통신 fixture, hooks 9개 통과 | `E6/app-full.log/json` |
| `P scripts/scan_private.py` (새 시험 intent-to-add 뒤) | 0 | 새 파일 포함 코드 검사 통과 | `E6/scan-private-code.log`, `E6/code-checks.json` |
| 자기 앱 경로 `git diff --check` | 0 | 공백 오류 없음 | `E6/diff-check.log`, `E6/code-checks.json` |
| `git commit --only -- <자기 앱 7경로>` | 0 | 아래 코드 커밋 | `E6/app-commit.log/json` |

코드 커밋은 **`3e9400b5624a6d24e6b987c7896c07d038b53192`** (hejo main)이다. 자기 7개 파일의 커밋 blob이 전체 앱 시험에서 읽은 바이트와 같고, 측정한 제품 소스 5개도 같은 바이트다. 전체 시험 중 앱 소스·시험 변경 0개, 실제 설정 메타데이터·Downloads 이름 보존 검사 통과. 기존 시험의 실패·기대값 수정은 없었다. 기존 Swift 6 모드 관련 경고와 사용하지 않는 지역 변수 경고, AppKit 입력 서비스 진단 메시지는 로그에 남았지만 현재 Swift 5 빌드·시험은 종료 0이다. 경고 해소는 이번 범위에 넣지 않았다.

AT-FF-32와 추가 AC-04 상태 비교는 통과했다. 검토자는 코드 변경, `E6/app-commit.json`의 blob 대조, `E6/app-full.log`, 전후 trace와 집계의 연결을 확인하면 된다. 전체 시험을 다시 돌리지 않아도 같은 변경본인지 확인할 수 있게 지문을 남겼다. 정적·문서 최종 검사는 `E6/final-report-checks.json`, 보고서 커밋 결과는 `E6/report-commit.json`에 기록한다.

**남은 일·다음 판단:** TASK-09는 100ms 목표 미충족으로 완료 판정을 요청하지 않는다. 계획 담당이 남은 최종 화면 준비 및 첫 프레임 전 메인 작업의 세분 계측·추가 수정 범위를 판단한다. 기준 완화, 애니메이션 단축, 오래된 화면 선표시를 제안한 것이 아니다. TASK-08 공개 후보로 자동 진행하지 않는다. 실제 트랙패드 M7은 기존 사장 지시대로 모든 작업의 마지막에 사장이 한다. 픽셀 단위 전후 스크린샷 비교와 물리 디스플레이 지연 실측은 미실행이며, 화면 동일성 증거는 상태 비교·실제 캡처 순서·기존 회귀 수준이다.

ThreeTap 판정·Reader·주입 harness·PetLayout의 0.30초 상수·기존 ThreeTap 시험·수락 명세/spec/design이 착수본과 같은 바이트임을 `E6/protected-source-check.json`으로 확인했다. 운영 실행본·운영 main·sync·게이트웨이 재시작·릴리스·앱 버전·설치 앱·Hermes 본체·ddots·gate/·schemas/는 이번 작업에서 변경하지 않았다. 운영 문 연결 동작·실제 메시지·git push도 실행하지 않았다. hejo main에는 다른 작업 커밋이 섞여 있으며, 추후 푸시 대상 승인은 별도로 필요하다.

## 7차-TASK-09 — 첫 프레임 전 비용 세분 및 마지막 한 차례 수정

### 착수·판단

handoff.md 7차와 verdict.md 검증 6차를 확인했다. 위험도 일반·증거 수준 2, 직접 구현·자체 시험이다. hejo main 착수 HEAD는 `4b12880eef414026f2cc753950dc62e7f85d2b31`. 착수 앱은 검토된 `3e9400b5624a6d24e6b987c7896c07d038b53192`와 같았다. 다른 작업의 HEJO-SLACK-MOVE 문서 변경과 HEJO-AUDIT 폴더를 보존했다. 완료된 TASK-07 적용이나 6차 검증을 반복하지 않았다.

이 절의 `E7`은 hejo `.build/finder-folders-evidence/round7-task09`, `E6`은 round6-task09, `E5`는 round5-task09, `P`는 확인된 게이트웨이 Python이다. 착수 상태·앱 전체 SHA-256은 `E7/start.json`, 자기 변경 경로의 전후 전체 SHA-256은 `E7/change-integrity.json`에 있다. 인계 상태 파일은 수정하지 않았다.

**구현자 판단: 부분 완료.** 마지막 한 차례 수정 후 첫 움직임 중앙값은 열기 **101.340ms**, 닫기 **94.633ms**다. 양쪽 모두 감소했고 닫기는 100ms 이하이지만, 열기는 **1.340ms 초과**다. AT-FF-31 전체 통과로 표시하지 않는다. 7차 5항에 따라 이 측정 뒤 추가 성능 수정·재측정 반복은 하지 않았으며, 회귀 검사·기록·커밋만 마무리했다. 수용 여부는 마지막 실제 탭 확인 M7에서 사장이 결정한다.

### 수정 전 세분 계측과 근거

같은 기본 꺼짐 `HEJO_THREE_TAP_TRACE` 설정과 3ccda92의 주입 harness를 사용했다. 실제 읽기 콜백 입구로 가짜 프레임을 넣고 열기·닫기 각 10회 기록했다. 진단에는 단계 이름·횟수·초만 기록하며 대화·직원·폴더 값은 넣지 않았다.

- 첫 틱 진입, 타이머 등록, 전환 준비 종료, 실제 탭 처리 반환을 구분했다. 진단이 활성화된 샘플에서만 CFRunLoop beforeWaiting/afterWaiting 관찰자를 설치해 등록부터 첫 틱까지의 대기 합계를 구했다. 나머지 경과는 메인 처리·스케줄링 등을 포함하며 순수 CPU 시간으로 해석하지 않는다.
- 실제 코드에서 `apply(open)`과 캡처는 **타이머 등록 전**이다. apply·대화 layout/draw는 첫 틱 전 구간 전체를 계측했고, 등록 뒤에 실행됐다고 잘못 분류하지 않았다. 등록 뒤 탭 처리 반환까지는 열기 0.674ms·닫기 0.098ms였다. 나머지에는 AppKit 작업·큐 처리·run loop 대기가 포함된다.
- captureGenie의 layout, cacheDisplay, 흐림 생성·설정을 분리했다. refresh는 선택·초안 준비, 사이드바, 카드 구성, 목록 반영, 작성 칸, 안내·검색, 섬, 처리할 일 칸, 마무리로 나눴다.

계측 전용 빌드 첫 시도는 **종료 1**이었다. 새 run loop 계측에서 같은 dictionary를 읽고 쓰는 식이 Swift exclusive-access 오류를 냈다(`E7/profile-build-initial.log/json`). 읽은 합계를 지역 값으로 분리했고 재빌드는 종료 0이었다. 제품 동작 수정 전 계측 소스는 `E7/profile-sources/`, 전체 지문은 `E7/profile-source.json`이다. 기존 시험 기대값의 실패나 변경은 아니다.

세분 구간 중앙값(ms), 원시 자료 `E7/profile.jsonl`·`after.jsonl`, 집계 `profile-details.json`·`after-details.json`:

| 하위 구간 | 열기 수정 전 | 열기 수정 후 | 닫기 수정 전 | 닫기 수정 후 |
|---|---:|---:|---:|---:|
| 등록 → 첫 틱 진입 | 22.353 | 8.874 | 29.269 | 8.159 |
| 그 사이 run loop 대기 | 1.003 | 0.000 | 17.759 | 0.000 |
| 대기를 뺀 나머지 경과 | 17.782 | 8.874 | 12.624 | 8.159 |
| 등록 → 탭 처리 반환 | 0.674 | 0.656 | 0.098 | 0.078 |
| 배치 apply 합계 | 10.382 | 10.070 | 13.707 | 11.491 |
| 대화 layout 합계 | 2.945 | 2.393 | 4.273 | 2.934 |
| 대화 draw 합계 | 0.466 | 0.449 | 2.428 | 1.812 |
| 캡처 직전 layout | 7.604 | 7.593 | 0.034 | 0.023 |
| cacheDisplay | 10.516 | 10.263 | 27.198 | 23.421 |
| 흐림 생성·설정 | 1.946 | 1.936 | 3.947 | 2.625 |
| refresh 선택·초안 준비 | 0.065 | 0.064 | 0.032 | 0.030 |
| refresh 사이드바 | 19.286 | 19.077 | 14.676 | 14.118 |
| refresh 카드 구성 | 27.208 | 27.144 | 4.854 | 4.594 |
| refresh 목록 반영 | 3.718 | 3.696 | 1.591 | 1.363 |
| refresh 작성 칸 | 0.334 | 0.332 | 2.171 | 2.029 |
| refresh 안내·검색 | 0.501 | 0.527 | 0.644 | 0.564 |
| refresh 섬 | 0.050 | 0.047 | 0.048 | 0.049 |
| refresh 처리할 일 칸 | 0.000 | 0.000 | 0.001 | 0.001 |
| refresh 마무리 | 0.012 | 0.011 | 0.010 | 0.009 |

이 표의 apply/layout/draw는 첫 틱 전 전체 합계다. 캡처·refresh 내부와 겹치는 하위 계측이 있으므로 모든 행을 합산하면 안 된다. 각 중앙값 역시 같은 표본에서 선택되는 값이 아니므로 구간 중앙값의 합이 전체 중앙값과 일치하지 않는다. 수정 후 첫 틱은 예약한 메인 큐 첫 프레임과 기존 타이머 중 먼저 실행된 처리다.

### 허용 범위에서 고친 곳

1. **첫 프레임 대기 제거 — PetController.** 전환을 설정한 즉시 메인 큐에 첫 프레임 처리를 예약한다. 60Hz 타이머 간격을 기다리지 않고 같은 `stepTransition`을 실행한다. 기존 `showChat()`의 동기 반환 시점은 접힌 진행률 0이라는 AT47 계약이 있으므로, 그 호출 안에서 진행률을 먼저 올리지 않는다. 프레임의 진행률은 기존 시작 시각과 실제 경과 시간으로 계산한다. 0.30초 상수·곡선·이후 타이머는 그대로다. 예약 뒤 전환이 바뀌었으면 타이머 identity를 대조해 옛 프레임을 버린다.
2. **바뀌지 않은 높이 재배치 요청 생략 — ConversationView.** 사이드바의 기본 rowHeight가 같으면 다시 설정하지 않는다. 행 id가 같을 때 이전에 전달한 실제 높이와 같은 행은 AppKit의 높이 무효화 요청에서 뺀다. 바뀐 높이·id·목록/탭 전환은 기존 경로로 반영하고, 검색 결과 행은 내용·줄바꿈 갱신을 보존하도록 기존 경로를 유지한다. 셀의 이름·선택·읽음·색 등 내용 갱신은 계속 한다. 새 화면 원본이나 데이터 모델은 만들지 않았다.
3. **흐림 지연은 적용하지 않았다.** 열기 진행률 0에서는 흐림 비율이 1이다. 닫기도 움직임이 시작되면 비율이 0보다 커진다. 첫 움직이는 프레임에 흐림이 필요하므로, 첫 프레임에 필요 없는 계산이라는 조건에 해당하지 않는다. PetView는 captureGenie의 세부 계측만 추가했다. GenieView·흐림 수식은 수정하지 않았다.

그 밖의 제품 동작 변경은 없다. ThreeTapDiagnostics는 활성 진단 샘플에서만 run loop 대기와 이름뿐인 하위 작업을 기록하고, ThreeTapReader는 탭 처리 반환 시각만 추가 기록한다. 내용·선택 갱신을 애니메이션 뒤로 미루거나 오래된 화면을 먼저 띄우지 않는다. 6차의 최종 갱신→캡처 순서는 그대로다.

**이득의 한계:** 수정 전/후 사이드바 구간은 열기 19.286→19.077ms, 닫기 14.676→14.118ms로 차이가 작다. 이 생략을 주요 개선 원인으로 주장하지 않는다. 큰 감소는 타이머 등록부터 첫 틱까지의 구간이며, 측정 변동이 있는 캡처 시간 변화와도 구분한다. 하위 모듈을 넓혀 카드 렌더 캐시 등을 더 넣지 않았다.

### AT-FF-30·31 전후 결과

동일 harness, 각 방향 10회, ms **중앙값 / 최대값**. 직전 검토본의 `E6/after.jsonl`과 이번 `E7/after.jsonl`을 비교한다.

| 구간 | 열기 6차 | 열기 7차 | 닫기 6차 | 닫기 7차 |
|---|---:|---:|---:|---:|
| 손 뗀 프레임 → 판정 | 0.009 / 0.013 | 0.009 / 0.014 | 0.010 / 0.062 | 0.010 / 0.014 |
| 판정 → 메인 처리 | 0.053 / 0.063 | 0.045 / 0.064 | 0.053 / 0.217 | 0.053 / 4.855 |
| 메인 처리 → setExpanded | 0.013 / 0.113 | 0.014 / 0.093 | 0.017 / 0.019 | 0.015 / 0.021 |
| setExpanded → 첫 움직임 | 116.994 / 185.459 | 101.264 / 144.350 | 136.333 / 179.735 | 94.548 / 110.544 |
| 첫 움직임 → 전환 끝 | 303.578 / 334.934 | 308.357 / 337.290 | 285.560 / 306.390 | 325.778 / 351.861 |
| 손 뗀 프레임 → 첫 움직임 | 117.072 / 185.627 | 101.340 / 144.501 | 136.374 / 179.805 | 94.633 / 110.635 |
| genie 캡처 | 20.123 / 50.688 | 20.485 / 49.288 | 32.334 / 36.244 | 27.993 / 36.594 |
| 최종 갱신 묶음 | 63.669 / 68.198 | 60.177 / 69.085 | 27.714 / 30.950 | 26.815 / 29.904 |
| 타이머 등록 → 첫 움직임 | 18.334 / 45.687 | 8.968 / 9.889 | 44.518 / 72.511 | 8.267 / 9.413 |

`python3 app/Tests/three_tap_latency.py E6/after.jsonl --after E7/after.jsonl`은 **종료 1**이다(`E7/compare-r6.json`, `compare-r6-result.json`). 원래 수정 전 `E5/before.jsonl`과의 비교도 **종료 1**이며, 열기 False·닫기 True다(`E7/compare.json`, `compare-result.json`). 반올림으로 열기를 100ms라고 표시하거나 기준을 완화하지 않았다.

이번 계측 전용 수정 전 기록 자체의 첫 움직임 중앙값도 열기 117.964ms·닫기 128.455ms로, 수정 후 양쪽 모두 감소했다. 첫 움직임 계측 정의는 기존과 같은 첫 비영(非零) 진행률의 genie 갱신 제출 시각이다. 물리 디스플레이 제시 시각이나 실제 손 탭 지연은 아니며, 첫 프레임 예약은 실제 제품 경로에 적용된다.

남은 구간은 열기 최종 refresh 51.166ms(카드 구성 27.144ms·사이드바 19.077ms), 캡처의 layout 7.593ms·cacheDisplay 10.263ms·흐림 1.936ms, 첫 틱 진입 8.874ms다. 닫기는 refresh 23.197ms, cacheDisplay 23.421ms·흐림 2.625ms, 첫 틱 진입 8.159ms다. 이 수치만 보고 추가 최적화를 이어가지 않았다.


### 시험·검증·커밋

새 `TransitionPreparationTests`는 다음을 보호한다. (1) showChat 동기 반환은 진행률 0, (2) 첫 메인 큐 프레임은 실제 경과 0.06초에서 기존 곡선의 0.2 진행률, (3) 전환을 교체한 뒤 옛 큐 프레임이 새 reduced-motion 상태를 바꾸지 않음, (4) 사이드바 반복 갱신·탭/목록 전환 뒤 AppKit 실제 행 높이가 현재 위임 높이와 같음. TestMain에는 이 시험 호출만 추가했고 기존 기대값은 바꾸지 않았다. 기존 ConversationUpdateTests의 열기·접기·재열기·대상 변경 내용 동일성 검사도 통과했다. 별도 mutation check는 미실행이다. 실제 콜백 주입·네이티브 창 및 기존 회귀를 증거로 삼았다.

| 명령(hejo cwd) | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `bash app/Tests/build_three_tap_latency.sh` (초기 계측 빌드) | 1 | 새 계측의 exclusive-access 컴파일 오류, 위에서 보완 | `E7/profile-build-initial.log/json` |
| 같은 진단 빌드 (계측 보완 후 / 동작 수정 후) | 0 / 0 | 개발 진단 바이너리·서명 | `E7/profile-build.log/json`, `E7/after-build.log/json` |
| `pgrep -f app-tests` (두 주입 실행·전체 시험 전) | 각각 1 | 다른 앱 시험 없음 | `E7/profile-pgrep.json`, `after-pgrep.json`, `app-pgrep.json` |
| `HEJO_THREE_TAP_TRACE=E7/profile.jsonl diagnostic <개발 리소스>` | 0 | 수정 전 세분 계측 20행 | `E7/profile-run.log/json` |
| `HEJO_THREE_TAP_TRACE=E7/after.jsonl diagnostic <개발 리소스>` | 0 | 수정 후 계측 20행 | `E7/after-run.log/json` |
| `python3 app/Tests/three_tap_latency.py E6/after.jsonl --after E7/after.jsonl` | **1** | 열기 100ms 미충족, 닫기 충족 | `E7/compare-r6.json`, `compare-r6-result.json` |
| 같은 비교 도구, 기준 `E5/before.jsonl` | **1** | 원래 수정 전 대비도 같은 수락 판정 | `E7/compare.json`, `compare-result.json` |
| `HEJO_PYTHON=P bash app/scripts/test.sh` | **0** | 앱 본시험·기존 ThreeTap/펫 클릭·AC-04·새 첫 프레임/사이드바·통신 fixture·hooks 9개 통과 | `E7/app-full.log/json` |
| `P scripts/scan_private.py` (새 시험 intent-to-add 뒤) | 0 | 코드 개인값 검사 | `E7/scan-private-code.log`, `code-checks.json` |
| `git diff --check -- app` | 0 | 공백 오류 없음 | `E7/diff-check.log`, `code-checks.json` |
| `git commit --only -- <자기 앱 7경로>` | 0 | 아래 코드 커밋 | `E7/app-commit.log/json` |

코드 커밋 전체 해시: **`b3fc5cb96b9e7ded138c4f6823eb5c446d5a2ba9`**, hejo main. 소스 5개(ConversationView·PetController·PetView·ThreeTapDiagnostics·ThreeTapReader), TestMain, 새 TransitionPreparationTests만 커밋했다. 부모는 `fbcbfed9707a4f497ba2a2cf3c95fa870c22abcf`이며 다른 작업의 문서 커밋이 착수 후 들어왔으나, 앱 측정·시험 대상 바이트는 바뀌지 않았다.

`E7/after-source.json`은 최종 측정 제품 소스, `E7/app-tested-source.json`은 전체 앱 시험의 소스·시험 지문이다. 시험 중 바뀐 파일 0개이며 커밋의 자기 7개 blob이 시험 바이트와 같음을 `E7/app-commit.json`으로 확인했다. 최종 측정 뒤 제품 소스를 바꾸지 않았다. 실제 설정 메타데이터·Downloads 이름 보존 검사도 통과했다. 로그의 기존 Swift 6 모드 경고·AppKit 입력/색 공간 진단은 남았으나 현재 Swift 5 빌드·실행은 종료 0이다.

AT-FF-30 측정과 AT-FF-32 회귀는 끝났고 AT-FF-31 전체는 **미충족**이다. 검토자는 코드·커밋 지문·전후 trace와 이 판정을 확인한다. 같은 변경본의 전체 시험을 반복할 필요는 없으며, 결과의 물리 디스플레이 제시 시각·실물 탭 체감은 검증하지 않았다. 다른 화면 규모·다른 Mac에서의 수치도 일반화하지 않는다.

보고서 최종 개인값·공백 검사 및 지문은 `E7/final-report-checks.json`, 보고서만의 커밋 결과는 `E7/report-commit.json`에 기록한다. 보호 대상(ThreeTap 판정, PetLayout 길이·곡선, GenieView, 주입 harness, 기존 ThreeTap·내용 동일성 시험, 수락 명세/spec/design)은 착수본과 같은 바이트다(`E7/protected-source-check.json`).

### 인계·남은 조건

7차는 마지막 성능 수정이다. **추가 성능 수정 없이 검토로 넘긴다.** 사장 M7은 기존 지시대로 모든 작업의 맨 마지막 실제 탭 확인이고, 거기서 수용 여부를 사장이 결정한다. 이번 결과만으로 TASK-09 최종 완료나 TASK-08 공개를 선언하지 않는다. TASK-08은 검토와 기존 HEJO-SLACK-MOVE 문 커밋 판정 확인 절차가 남아 있다.

운영 실행본·운영 main·sync·게이트웨이 재시작·릴리스·앱 버전·설치 앱·본체·ddots·gate/·schemas/·수락 기준은 건드리지 않았다. 비밀 파일·운영 연결 동작·실제 메시지·git push도 없다. hejo main에는 다른 작업 커밋이 섞여 있으므로 나중에 공개·푸시 대상을 승인받을 때 포함 범위를 명시해야 한다.

## 8차-TASK-10 — 처리할 일 칸 배경

### 착수·구현 판단

받은 설계는 handoff.md 8차, spec REQ-FF-08 및 수락 명세 AT-FF-40~42다. 위험도 일반, 증거 수준 2, 직접 구현·자체 시험이다. 착수 hejo main HEAD는 `df2d1a46df309777940985a49b02a1c230a01d59`. 착수 상태·제품 소스 지문은 `E8/start.json`, 자기 변경 4경로의 전후 전체 SHA-256은 `E8/change-integrity.json`에 있다. 여기서 `E8`은 hejo `.build/finder-folders-evidence/round8-task10`, `P`는 확인된 게이트웨이 Python이다.

[확인] TodoDrawerView는 scroll 배경을 끄고 카드만 그렸다. PetView의 겹침 배치는 서랍을 대화 영역 x=0에 올리므로, 서랍 빈 부분에 아래 방 목록이 비칠 수 있었다. 수정은 관제 화면(app/)의 기존 서랍 자신에게 배경 책임을 둔다.

- `TodoDrawerView.swift`: 직접 draw에서 전달받은 바탕색을 알파 1로 그린다. 전체 bounds를 칠하므로 isOpaque도 true다. 겹침·바깥 모두 같은 불투명 색이며, 글·카드·칩의 불투명도를 바꾸지 않는다. ChatAppearance.didChange와 유효 appearance 변경 때 다시 그린다. 알림 관찰자는 해제한다.
- `PetView.swift`: 기존 updateScrim에서 대화 창 tint에 쓰는 **동일한 color 값**을 설치된 서랍에 전달한다. 설치 때도 이 전달을 수행한다. tint 색 생성·대화 투명도 계산은 기존 자리 하나에 유지했고 새 테마 색 상수를 만들지 않았다. 서랍 단독 생성 시 기본값은 AppKit의 기존 windowBackgroundColor이며, 실제 설치 시 대화 tint로 바뀐다. 배치 좌표·겹침 판정·애니메이션은 바꾸지 않았다. 이 파일의 변경은 기존 색을 서랍에 전달하기 위한 설치·표시 연결 부분이다.
- `TodoDrawerBackgroundTests.swift`, `TestMain.swift`: 수락 명세의 실제 PetView 픽셀 시험을 앱 시험에 추가하고 전체 실행에 등록했다. 기존 HEJO-TODO-DRAWER 시험·기대값은 그대로다.

설계와 달라진 점·임시 우회·새 자료 원본은 없다. 의미 변경은 서랍 바탕이 불투명해지는 요청된 표시 동작뿐이다. TASK-09의 마지막 성능 수정 종료 상태는 유지한다. 코드 작성 중 다른 대화가 후속 계획 문서를 커밋했으나, 이번 구현은 TASK-10 범위만 처리한다. 호스트 상태 파일은 읽기 전용으로 확인했고 수정하지 않았다.

### AT-FF-40·41 픽셀 검사 방법

임시 LocalStore·가짜 명부로 실제 ConversationView와 PetController/PetView를 조립하고 `installConversation`·`installDrawer`를 호출한다. 실제 배치 결과의 drawerOverlay가 요청한 참/거짓인지 먼저 검사한다. 대화 영역에서 서랍 바로 아래에 선명한 자홍색/초록색 사각형을 번갈아 넣는다.

각 배치에서 어두운·밝은 테마로 바꾼 뒤, 글·카드와 떨어진 빈 여백을 `cacheDisplay` 비트맵에서 검사한다. 실제 부모 대화 영역을 캡처한 픽셀과 서랍 자체 캡처의 픽셀을 모두 검사한다. 알파 1(비트맵 오차 0.001 이내), 기존 대화 tint의 불투명 색과 일치(RGB 합 차이 0.025 이내), 아래 사각형과 큰 색 차이, 사각형 색을 바꿔도 픽셀 유지(RGB 합 차이 0.005 이내), 밝고 어두운 테마가 서로 다름을 검사한다. 테마 변경 알림의 needsDisplay 재설정도 확인한다.

네이티브 픽셀 비교이므로 화면을 눈으로만 본 결과나 배경 속성 검사만으로 통과시키지 않는다. 실제 카드 클릭·필터·접기·덮개·애니메이션은 기존 AT-TD-20~42 등에서 확인한다. 별도 mutation check와 사장의 설치 앱 M8은 미실행이다.


### 검증·커밋·인계

**구현자 판단: TASK-10 구현·자체 시험 완료, 검토 대기.** AT-FF-40·41은 겹침/바깥 × 어두운/밝은 네 조합 모두 PIXEL PASS, 서랍 자체 표본 알파는 모두 1.0이다. 두 아래색에 대한 부모 캡처 불변성·기존 tint와 일치·테마 간 차이·다시 그리기 알림도 통과했다. 기존 AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS 및 전체 앱 시험 종료 0으로 AT-FF-42를 충족했다. 기존 시험 기대값은 수정하지 않았다.

| 명령(hejo cwd) | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `pgrep -f app-tests` | 1 | 전체 시험 전 다른 앱 시험 없음 | `E8/app-pgrep.json` |
| `HEJO_PYTHON=P bash app/scripts/test.sh` | **0** | 개발 빌드·서명, AT-FF-40/41 네 조합 픽셀 검사, 기존 AT-TD-20~42·ThreeTap·앱 본시험 및 통신 fixture·hooks 9개 통과 | `E8/app-full.log`, `E8/app-full.json` |
| `P scripts/scan_private.py` (새 시험 intent-to-add 뒤) | 0 | 새 파일 포함 개인값 검사 | `E8/scan-private-code.log`, `E8/code-checks.json` |
| 자기 네 경로 `git diff --check` | 0 | 공백 오류 없음 | `E8/diff-check.log`, `E8/code-checks.json` |
| `git commit --only -- <자기 앱 네 경로>` | 0 | 아래 코드 커밋 | `E8/app-commit.log`, `E8/app-commit.json` |

코드 커밋 전체 해시: **`2fffbe0610053ca59d69e1f03b83a5c4b0f5ecff`** (hejo main). 부모는 `9ef6675ee72517b3b00aa46055ab7e5fefade774`이며, 착수 뒤 들어온 계획/다른 작업 문서 커밋은 그대로 보존했다. 자기 네 파일만 커밋했다. `E8/app-tested-source.json`은 시험이 읽은 전체 앱 소스·시험의 SHA-256이며, 시험 중 변경 0개다. 네 파일의 커밋 blob과 시험한 바이트가 같음을 `E8/app-commit.json`으로 확인했다.

실제 설정 메타데이터·Downloads 이름 보존 검사도 통과했다. 로그에 기존 Swift 6 모드 경고·AppKit 입력/색 공간 진단이 있으나 현재 Swift 5 빌드·시험은 종료 0이며 이번 범위에서 수정하지 않았다. 보고서 최종 개인값·공백 검사 결과 및 SHA는 `E8/final-report-checks.json`, 보고서만의 커밋은 `E8/report-commit.json`에 남긴다.

다음 담당자는 이 변경과 픽셀 시험 증거를 검토한다. 실제 설치 앱에서 사장이 보는 M8은 남아 있다. 0.2.4 공개 후보를 준비하는 다른 세션의 후보에 위 TASK-10 코드 커밋이 포함돼야 한다. 이 대화는 공개 후보·버전·설치 앱을 만들거나 교체하지 않았다. TASK-09의 기준 미충족 수용은 기존 지시대로 마지막 실제 탭 M7에서 사장이 판단한다. 후속 TASK-11 계획은 이번 TASK-10 결과에 섞지 않았다.

이 작업에서 gate/·schemas/·다른 작업 파일·운영 실행본·설정·게이트웨이·본체·ddots·수락 기준/시험 명세/spec/design은 바꾸지 않았다. 비밀 파일·운영 연결 동작·실제 메시지·git push 실행은 없다. main에 다른 작업 커밋이 함께 있으므로 향후 공개·푸시 승인 때 포함 범위를 명시해야 한다. 최종 완료 판정과 공개/푸시 승인은 별도다.

## 9차-TASK-11 — 색과 글자 사진·옵션창 높이

### 착수·구현 구조

받은 설계는 handoff.md 9차, spec REQ-FF-09·10, design 8절, 수락 명세 AT-FF-50~54·60~63이다. 위험도 일반, 증거 수준 2, 직접 구현·자체 시험이다. TASK-10 검토 완료를 확인했고 반복하지 않았다. 착수 hejo main HEAD는 `61a244101e20dd06f3570716c621d06f80552a99`. 착수 상태·앱 소스 SHA는 `E9/start.json`, 자기 변경 경로 전후 SHA는 `E9/change-integrity.json`에 있다. 이 절의 `E9`는 앞 절의 round5와 구별해 **hejo `.build/finder-folders-evidence/round9-task11`**, `P`는 확인된 게이트웨이 Python이다. 호스트 인계 상태 파일은 읽기 전용 참고로만 사용했다.

색·글자 사진은 app/의 기존 사진 원본으로 PNG만 올린다. 색·글자를 저장하는 두 번째 원본·설정 키·문 규격은 만들지 않았다. 창 정책은 새 OptionWindows 한 곳에 옮겼다.

- `Pictures.swift`의 PictureCodec에 256×256 sRGB PNG 생성을 추가했다. UserBubbleColor의 밝은 테마 값과 UserBubblePalette의 검정/흰색 규칙을 그대로 쓴다. 글자를 보이는 글자 기준 8개로 제한하고 줄바꿈을 공백으로 바꾼다. 굵은 시스템 글꼴의 실제 glyph 경계를 재며 각 변 18% 안전 영역에 맞도록 크기를 줄인다. 글자 alpha를 같은 전경색으로 칠해 색 이모지 역시 정해진 검정/흰색을 따른다. 빈 글자는 배경만 그린다. 기존 사진 파일의 center crop·PNG 변환 함수는 그대로다.
- `LetterPictureDialog.swift`: 기존 AppearanceSwatch를 재사용하는 14색 줄, 글자 칸(이름 첫 글자), 같은 PNG 함수의 미리보기를 NSAlert 부속 보기로 구성했다. 입력 조합 중 글자를 자르지 않고 확정 입력과 저장 시 최대 8글자를 적용한다. 매번 이름 첫 글자·기본색으로 시작하며 이전 PNG에서 값을 역산하지 않는다.
- 직원·그룹 방·홈의 메뉴는 하나의 pictureMenu(kind/id/name)로 하위 메뉴를 만든다. **상위 표시 이름 `사진 바꾸기…`와 메뉴 순서는 기존 그대로 유지**했다. 기존 AT68·AT70·AT80 시험이 이 이름·순서를 명시하기 때문이다. 그 아래에 명세의 `사진 고르기…`, `색과 글자로 만들기…` 두 항목을 둔다. 이는 제목의 생략 부호만 보존한 구현 세부 판단이며 수락 요구인 두 선택지를 모두 제공한다. 기존 기대값은 수정하지 않는다.
- 중복 `chooseGroupPicture`는 제거하고 공용 사진 고르기로 합쳤다. 파일 선택과 생성 PNG는 기존 ConversationController.changePicture → GateHTTP.setPicture를 공유한다. 기존 사진 변환·실패 문구·업로드 전후 address/token/epoch 검사도 같은 경로다. 홈·섹션 사진 결과를 반영하는 분기를 pictureUploaded로 함께 쓴다. 그룹 방은 종전처럼 서버의 사진 갱신을 따른다. 사진 선택이 열린 동안 연결이 바뀌면 이전 대상에 업로드하지 않는다. pictureSender와 chooser/presenter 주입은 시험 경계이며 실제 실행의 기본 경로는 기존 HTTP 업로드·AppKit이다.
- `OptionWindows.swift`: 앱 활성화 뒤 활성 높이를 펫 창 현재 높이+1로 정한다. 비활성 연결 창의 선호 높이는 .normal이다. AppDelegate가 기존 펫 창을 공급하고 updateConnectionsLevel도 이 공용 식을 사용한다. 독립 설정·로그인·달력·대시보드·세 손가락 안내창은 show, 사진/첨부 고르기는 prepare, NSAlert·웹의 파일 고르기/확인은 runModal을 쓴다. 기존 첨부 고르기의 생성 시 .modalPanel 값은 AT88 계약대로 유지하고 실제 표시 직전에 공용 높이를 적용한다.
- ConnectionsWindow의 confirming .normal·비활성 .normal과 입력/확인 시트 수명은 그대로다. AppDelegate.showConnections가 공용 선호 높이를 먼저 전달한다. 연결 창 자체의 updateLevel 구현은 바꾸지 않았고, 시트는 부모를 따른다. WebPane의 확인 보조 함수는 AppKit 콜백에서 쓰는 @MainActor 함수로 명시했다.

구조 변경은 기존 사진/옵션창 책임 안에서의 통합이다. 덧댄 비동기 표시 경로나 다른 저장 형식, 남긴 임시 코드는 없다. 과거 raw modal 호출은 공용 입구로 교체했다. 운영 연결·메시지 전송이나 실제 프로필 사진 변경은 하지 않았다.

### AT-FF-62 전체 검색 목록

수정 시작 전에 다음 검색을 실행해 `E9/inventory-before.txt`에 저장했다.

`rg -n 'NSOpenPanel\(|NSSavePanel\(|NSAlert\(|runModal|beginSheetModal|makeKeyAndOrderFront' app/Sources`

같은 검색의 최종 결과는 `E9/inventory-after.txt`다. 별도 `NSWindow`·`NSPanel` 생성 및 orderFront/showWindow 호출도 확인했다. 대시보드·달력·설정·로그인은 모두 공용 show로 들어가고, PetController/PetView의 orderFront는 높이 기준인 펫 자체여서 제외한다. 사진 파일 chooser 생성은 주입 factory로 이동했다. 아래에는 시작 목록의 **모든 일치 행**과 최종 목록을 위치별로 남긴다.

| 착수 위치 | 처리 |
|---|---|
| `app/Sources/AppDelegate.swift:137` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/AppDelegate.swift:316` | 독립 대시보드/달력: OptionWindows.show 적용 |
| `app/Sources/AppDelegate.swift:327` | 독립 대시보드/달력: OptionWindows.show 적용 |
| `app/Sources/AppDelegate.swift:396` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/AppDelegate.swift:398` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/AppDelegate.swift:401` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/AppDelegate.swift:402` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/ThreeTapController.swift:119` | notice 생성 후 OptionWindows.show에서 적용 |
| `app/Sources/ThreeTapController.swift:134` | notice 생성 후 OptionWindows.show에서 적용 |
| `app/Sources/LoginWindow.swift:44` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/LoginWindow.swift:45` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/LoginWindow.swift:107` | 로그인: OptionWindows.show 적용 |
| `app/Sources/AppUpdate.swift:31` | 업데이트 상자: 기본 present가 OptionWindows.runModal 적용, 기존 주입 시험 유지 |
| `app/Sources/AppUpdate.swift:103` | 업데이트 상자: 기본 present가 OptionWindows.runModal 적용, 기존 주입 시험 유지 |
| `app/Sources/AppUpdate.swift:110` | 업데이트 상자: 기본 present가 OptionWindows.runModal 적용, 기존 주입 시험 유지 |
| `app/Sources/PetController.swift:253` | 제외: 옵션창이 아니라 기준이 되는 펫/대화 창 자체 |
| `app/Sources/WebPane.swift:381` | 웹 파일 고르기/확인: OptionWindows.prepare·runModal 적용, presenting 수명 유지 |
| `app/Sources/WebPane.swift:385` | 웹 파일 고르기/확인: OptionWindows.prepare·runModal 적용, presenting 수명 유지 |
| `app/Sources/WebPane.swift:389` | 웹 파일 고르기/확인: OptionWindows.prepare·runModal 적용, presenting 수명 유지 |
| `app/Sources/WebPane.swift:395` | 웹 파일 고르기/확인: OptionWindows.prepare·runModal 적용, presenting 수명 유지 |
| `app/Sources/PetSettingsWindow.swift:131` | 설정: OptionWindows.show 적용 |
| `app/Sources/PetSettingsWindow.swift:195` | 상자 생성 함수. 호출자 AppDelegate의 OptionWindows.runModal에서 적용 |
| `app/Sources/PetSettingsWindow.swift:203` | 상자 생성 함수. 호출자 AppDelegate의 OptionWindows.runModal에서 적용 |
| `app/Sources/ConnectionsWindow.swift:288` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/ConnectionsWindow.swift:291` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/ConnectionsWindow.swift:296` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/ConnectionsWindow.swift:297` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/ConnectionsWindow.swift:310` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/ConnectionsWindow.swift:312` | 시트·입력창은 부모를 따름. 부모 preferredLevel은 AppDelegate에서 공용 식 적용, confirming .normal 예외 유지 |
| `app/Sources/HooksHelp.swift:7` | 설정 도움·결과·실패 상자: OptionWindows.runModal 적용 |
| `app/Sources/HooksHelp.swift:9` | 설정 도움·결과·실패 상자: OptionWindows.runModal 적용 |
| `app/Sources/HooksHelp.swift:17` | 설정 도움·결과·실패 상자: OptionWindows.runModal 적용 |
| `app/Sources/HooksHelp.swift:18` | 설정 도움·결과·실패 상자: OptionWindows.runModal 적용 |
| `app/Sources/HooksHelp.swift:20` | 설정 도움·결과·실패 상자: OptionWindows.runModal 적용 |
| `app/Sources/RoomDialogs.swift:5` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:38` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:48` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:50` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:56` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:62` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:64` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:69` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:77` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:83` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:117` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:118` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:120` | RoomDialogs.present 또는 OptionWindows.runModal에서 적용(생성 함수는 호출자에서 적용) |
| `app/Sources/RoomDialogs.swift:124` | 중복 사진 고르기 제거, ConversationView.choosePicture 공용 경로로 통합 |
| `app/Sources/ConversationView.swift:293` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/ConversationView.swift:295` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/ConversationView.swift:309` | 사진: 공용 choosePicture에서 OptionWindows.prepare 적용 |
| `app/Sources/ConversationView.swift:343` | OptionWindows.runModal에서 활성화·공용 높이 적용 |
| `app/Sources/ConversationView.swift:879` | 첨부 구성값 유지, 실제 chooseFiles 직전 OptionWindows.prepare 적용 |

착수 검색은 인계서 지정 정규식의 모든 일치 행을 담았다. `NSSavePanel(` 일치 0개.

추가/이동된 공용 입구와 시트:

| 최종 위치 | 처리 |
|---|---|
| `app/Sources/AppDelegate.swift:138` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppDelegate.swift:398` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppDelegate.swift:400` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppDelegate.swift:403` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppDelegate.swift:404` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ThreeTapController.swift:134` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/LetterPictureDialog.swift:36` | 새 색과 글자 창: 기본 present에서 OptionWindows.runModal |
| `app/Sources/LetterPictureDialog.swift:38` | 새 색과 글자 창: 기본 present에서 OptionWindows.runModal |
| `app/Sources/LoginWindow.swift:44` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/LoginWindow.swift:45` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppUpdate.swift:31` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppUpdate.swift:103` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/AppUpdate.swift:110` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/PetController.swift:253` | 제외: 기준이 되는 펫/대화 창 자체 |
| `app/Sources/WebPane.swift:381` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/WebPane.swift:385` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/WebPane.swift:389` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/WebPane.swift:395` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/OptionWindows.swift:16` | 공용 정책의 AppKit 호출 지점. runModal/show 전에 prepare |
| `app/Sources/OptionWindows.swift:18` | 공용 정책의 AppKit 호출 지점. runModal/show 전에 prepare |
| `app/Sources/OptionWindows.swift:19` | 공용 정책의 AppKit 호출 지점. runModal/show 전에 prepare |
| `app/Sources/OptionWindows.swift:22` | 공용 정책의 AppKit 호출 지점. runModal/show 전에 prepare |
| `app/Sources/OptionWindows.swift:23` | 공용 정책의 AppKit 호출 지점. runModal/show 전에 prepare |
| `app/Sources/PetSettingsWindow.swift:195` | 생성 전용 상자: AppDelegate의 공용 runModal에서 표시 |
| `app/Sources/PetSettingsWindow.swift:203` | 생성 전용 상자: AppDelegate의 공용 runModal에서 표시 |
| `app/Sources/ConversationView.swift:293` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ConversationView.swift:295` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ConversationView.swift:307` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ConversationView.swift:349` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ConversationView.swift:885` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:5` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:38` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:48` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:50` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:56` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:62` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:64` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:69` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:77` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:83` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:117` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:118` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/RoomDialogs.swift:120` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/HooksHelp.swift:7` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/HooksHelp.swift:9` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/HooksHelp.swift:17` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/HooksHelp.swift:18` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/HooksHelp.swift:20` | 공용 정책 적용; 생성 전용은 그 호출자에서 적용 |
| `app/Sources/ConnectionsWindow.swift:288` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |
| `app/Sources/ConnectionsWindow.swift:291` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |
| `app/Sources/ConnectionsWindow.swift:296` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |
| `app/Sources/ConnectionsWindow.swift:297` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |
| `app/Sources/ConnectionsWindow.swift:310` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |
| `app/Sources/ConnectionsWindow.swift:312` | 부모 공용 preferredLevel·확인 예외를 따르는 기존 시트/복귀 경로 |

추가 창 생성·표시 검색:

| 최종 위치 | 처리 |
|---|---|
| `app/Sources/AppDelegate.swift:312` | 생성 뒤 OptionWindows.show로 표시 |
| `app/Sources/AppDelegate.swift:324` | 생성 뒤 OptionWindows.show로 표시 |
| `app/Sources/LoginWindow.swift:64` | 생성 뒤 OptionWindows.show로 표시 |
| `app/Sources/PetView.swift:15` | 제외: 기준 펫 창 자체 |
| `app/Sources/PetController.swift:206` | 제외: 기준 펫 창 자체 |
| `app/Sources/PetSettingsWindow.swift:45` | 생성 뒤 OptionWindows.show로 표시 |
| `app/Sources/ConnectionsWindow.swift:232` | 부모 preferredLevel은 공용 식, 입력 시트는 부모·확인 예외를 따름 |
| `app/Sources/ConnectionsWindow.swift:276` | 부모 preferredLevel은 공용 식, 입력 시트는 부모·확인 예외를 따름 |


위 목록에서 실제 사용자 창을 띄우지 않은 경로의 근거: 시작 실패·설정 도움 프로세스 결과·업데이트 안내·로그인 네트워크 검색·대시보드/달력은 실제 외부 상태를 사용하지 않기 위해 호출 위치에서 공용 함수 사용을 검토했다. 공용 함수·실제 설정창·방 상자·색과 글자 상자 및 세 메뉴의 사진 chooser는 시험으로 높이·활성화 순서를 확인한다. 연결 창은 기존 실제 시트 시험 AT-FF-20~23을 그대로 실행한다. 메뉴 NSMenu 자체에는 창 높이를 적용하지 않는다.

### 시험 계약

- AT-FF-50: 실제 직원·그룹·홈 메뉴가 같은 두 하위 항목을 제공하고 각 항목이 그 대상 kind/id를 쓴다.
- AT-FF-51: 14색 × `가`/빈 글자를 PNG로 디코드해 256×256·512 KiB·알파·밝은 테마 배경 모서리·전경색·빈 그림 전체를 픽셀 검사한다. UI 색 목록 순서·이름과 미리보기, 이름 첫 글자도 확인한다.
- AT-FF-52: `가`, `AB`, 긴 한글, 8글자 초과의 다른 픽셀 경계 상자가 18% 안전 영역 안인지 검사한다. 긴 글자의 실제 높이 감소, 8글자와 초과 입력의 결과 동일성, 조합 이모지 한 글자 처리·전경색 규칙을 확인한다.
- AT-FF-53: 가짜 pictureSender로 세 대상의 저장·생성 PNG를 확인한다. 취소는 전송·모델 변경 0회, 실패는 기존 문구, 열려 있는 동안 연결 주소가 바뀌면 전송 0회다.
- AT-FF-54/60: 실제 공용 사진 chooser에 응답만 주입해 직원·그룹·홈의 취소/넣기를 각각 한 번 완료한다. 넣기에서는 임시 PNG가 기존 사진 변환을 거쳐 가짜 업로드로 들어간다. 기존 사진 시험도 그대로 실행한다.
- AT-FF-60/61: 펼친 PetView의 실제 펫 창 높이를 .floating과 mainMenu+1 두 가지로 두고 사진·글자·방 상자·설정·공용 독립창의 표시 전에 활성화·펫보다 높은 높이를 확인한다. 실제 AppKit 창을 쓰며 파일 선택/모달 응답과 업로드만 가짜다.
- AT-FF-63: 기존 첨부 설정·연결 입력/확인/비활성 예외 및 전체 앱 시험의 기대값을 유지한다.

별도 mutation check는 미실행이다. 실제 그림 픽셀, 실제 메뉴·창, 가짜 전송 경계와 기존 앱/통신 회귀를 증거로 사용한다. 운영 직원 사진 업로드·다른 Mac 동기화 실물 확인 M9, 설치 앱의 모든 옵션창 체감 M10은 미실행이다.

### 중간 실패와 보완 기록

최종 통과 결과와 구분해 기록한다.

1. 첫 전체 실행은 새 입력 코드가 NSText에 hasMarkedText를 호출해 **컴파일 종료 1**이었다(`E9/app-full-initial.log/json`). 실제 field editor를 NSTextView로 확인하도록 보완했다.
2. 다음 전체 실행은 WebPane의 기존 private ask 함수에서 @MainActor 공용 창 함수를 호출해 **컴파일 종료 1**이었다(`E9/app-full-second.log/json`). AppKit의 WKUIDelegate에서 호출되는 해당 보조 함수에 @MainActor를 명시했다. 이후 전체 제품·시험 `xcrun swiftc -typecheck`는 **종료 0**이었다(`E9/typecheck.log/json`).
3. 그 다음 전체 실행은 기존 AT-TD-20~42 및 AT-FF-40/41을 통과한 뒤 **새 AT-FF-51 시험**의 배경색 검사에서 종료 1이었다(`E9/app-full-pixel-failure.log/json`). 새 시험만 실행해도 같은 실패였다(`E9/focused-before-color-fix.log/json`).
4. [재현] PNG bitmap은 sRGB인데 `colorAt`의 반환 NSColor가 calibrated RGB 표기를 썼다. 이를 다시 usingColorSpace(.sRGB)로 바꾸면 원시 sRGB 성분이 재해석됐다. 파랑의 원시 G 약 0.462745는 기대 약 0.461414와 2/255 이내지만, 이중 변환 후 약 0.548793이 돼 실패했다(`E9/pixel-probe.log`).
5. PNG의 이미 sRGB인 표본 성분을 직접 비교하도록 **새 시험의 읽기 오류**를 고쳤다. 명세·허용 오차 2/255·기존 시험 기대값은 바꾸지 않았다. 같은 codec/palette와 새 픽셀 검사의 별도 실행은 **종료 0**, LETTER_PIXEL_PROBE_PASS였다(`E9/pixel-check.log/json`). 새 메뉴·전송·옵션창 시험을 포함한 집중 실행도 **종료 0**이었다(`E9/focused.log/json`, 빌드 `focused-build.log/json`).

기존 시험 기대값의 수정이 필요한 실패나 연결 창 예외 충돌은 발견하지 않았다. `--finder-picture`는 새 시험만 선택 실행하는 TestMain의 시험 전용 갈래이며 제품 앱에는 포함되지 않는다.


### 최종 검증·커밋·인계

**구현자 판단: TASK-11 구현·자체 시험 완료, 검토 대기.** 새 시험 집중 실행과 최종 전체 시험이 모두 통과했다. 코드 커밋 전체 해시는 **`5fc60b21a2952ddbf9f0879cd4759ff73ab2f341`**, hejo main이다. 공용 옵션창·색과 글자 사진 소스, 그 호출 지점, 새 시험과 TestMain을 포함한 자기 17경로만 commit --only했다. 실제 경로 목록과 각 blob 대조는 `E9/app-commit.json`에 있다.

| 명령(hejo cwd) | 종료 코드 | 결과 | 로그 |
|---|---:|---|---|
| `pgrep -f app-tests` | 1 | 최종 전체 시험 전 다른 앱 시험 없음 | `E9/app-pgrep.json` |
| `xcrun swiftc -typecheck <제품 소스·시험 전체>` | 0 | 앞 절의 컴파일 오류 보완 확인 | `E9/typecheck.log/json` |
| `xcrun swift E9/pixel-check.swift` | 0 | 새 픽셀 읽기 보완 후 전체 생성 그림 검사 통과 | `E9/pixel-check.log/json` |
| `xcrun swiftc <앱 소스·시험>` + `app-tests --finder-picture <개발 리소스>` | 0 / 0 | 새 AT-FF-50~54·60~61 집중 실행 통과 | `E9/focused-build.log/json`, `E9/focused.log/json` |
| **`HEJO_PYTHON=P bash app/scripts/test.sh` (최종)** | **0** | 개발 빌드·서명, APP_TEST_OK, 새 사진·옵션창, 기존 AT68/70/80 사진·메뉴, AT88 첨부, AT-FF-20~23, ThreeTap·서랍, 통신 fixture·hooks 9개 통과 | `E9/app-full.log/json` |
| `P scripts/scan_private.py` (새 경로 intent-to-add 뒤) | 0 | 새 소스·시험 포함 개인값 검사 | `E9/scan-private-code.log`, `E9/code-checks.json` |
| 자기 앱 경로 `git diff --check` | 0 | 공백 오류 없음 | `E9/diff-check.log`, `E9/code-checks.json` |
| `git commit --only -- <자기 앱 17경로>` | 0 | 위 코드 커밋 | `E9/app-commit.log/json` |

전체 시험의 제품 소스·시험 SHA는 `E9/app-tested-source.json`, 시험 중 변경 목록은 `E9/app-full.json`이며 변경 0개다. 커밋의 17개 blob이 이 시험 바이트와 같음을 확인했다. 기존 사진·홈·방·연결·첨부 시험 파일과 ConnectionsWindow 자체는 착수본과 같은 바이트다(`E9/protected-source-check.json`). 실제 설정 메타데이터·Downloads 이름 보존 검사도 통과했다. 기존 Swift 6 모드 경고와 AppKit 입력/색 공간 진단은 로그에 남았으나 현재 Swift 5 빌드·시험은 종료 0이다.

검토자는 코드, AT-FF-62 전후 위치 목록, 픽셀 읽기 보완 이유와 최종 전체 결과를 확인한다. 최종 코드에 추가 변경·실패·증거 누락이 없다면 같은 전체 시험을 다시 돌릴 필요는 없다. 보고서 최종 개인값·공백 검사 결과 및 SHA는 `E9/final-report-checks.json`, 보고서만의 커밋 결과는 `E9/report-commit.json`에 남긴다.

남은 확인은 설치 앱에서 사장 M9(색과 글자·다른 Mac 동기화)와 M10(모든 옵션창 앞에 표시)이다. 이 대화는 0.2.4 공개 후보를 만들지 않았다. 공개 후보를 준비하는 다른 세션에 위 코드 커밋을 포함해야 한다. TASK-09 성능 기준 미충족의 수용은 기존 지시대로 맨 마지막 실제 탭 M7에서 사장이 판단한다. TASK-10은 재구현하지 않았다.

운영 사진 업로드·연결 동작·메시지·실행본 교체·재시작·본체·ddots·gate/·schemas/·앱 버전·설치 앱·수락 기준/시험 명세/spec/design 변경과 git push는 없다. 추적하지 않는 다른 작업의 감사 문서는 보존했다. 원격 github·브랜치 main에는 다른 작업 커밋도 함께 있으므로, 향후 공개·푸시 대상 승인 때 전체 포함 범위를 명시해야 한다. 구현 결과와 최종 검토·푸시 완료는 구분한다.
