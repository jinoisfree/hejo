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
