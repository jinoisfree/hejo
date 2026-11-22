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


## 10차-TASK-11 보완 (2026-11-22)

**구현자 판단: 구현·자체 시험 완료, 검토 대기.** 받은 설계는 `handoff.md` 10차 지시, spec 8판 REQ-FF-10 AC-05, 수락 명세 AT-FF-64, 검증 9차 V-5다. 위험도 일반, 필요한 증거 수준 2이며 앱 창과 대역 통합 시험으로 수준 2를 확인했다. 설계와 달라진 점은 없다.

착수 hejo main HEAD는 `c6636dd7cc88da037dfe65799d7f53b726406fa5`다. 자기 앱 3경로만 커밋한 코드 전체 해시는 **`da3cf0b4369ed374f59f35efa06f3b1242159409`**다. 아래 `E10`은 `.build/finder-folders-evidence/round10-task11`, `P`는 게이트웨이 Python을 뜻한다. 착수 상태·세 파일 SHA-256은 `E10/start.json`, 시험 소스 목록은 `E10/tested-sources.json`, 커밋 경로·blob 대조는 `E10/app-commit.json`에 있다.

### 변경과 보호 계약

- 원인: `OptionWindows.prepare/show`가 옵션창을 올리지만 앱 활성 상태가 바뀔 때 그 높이를 다시 맞추지 않았다. `OptionWindows.swift`가 올린 창을 `NSHashTable`의 약한 참조로 기억하고, 공용 `updateLevels(active:)`가 보이는 창만 기존 `level(active:)` 값으로 맞춘다. 닫힌 창의 높이는 갱신하지 않으며 창 수명은 기존 소유자가 관리한다.
- `AppDelegate.swift`는 기존 `updateConnectionsLevel()` 옆의 비활성·활성 처리 두 곳에서만 공용 함수를 호출한다. 연결 창은 공용 목록에 넣지 않았으며 확인 중 `.normal`을 포함한 자기 규칙을 유지한다. 별도 알림 등록·창 소유자·두 번째 높이 계산 규칙은 만들지 않았다.
- `OptionWindowTests.swift`에 AT-FF-64를 옮겼다. 실제 NSOpenPanel과 독립 창을 열어 펫 높이 `.floating`·`mainMenu+1` 각각에서 공용 함수로 비활성→활성을 전달하고 `.normal`→펫+1을 검사한다. 닫은 뒤 높이 변경 횟수가 늘지 않는지, 마지막 강한 참조를 해제하면 약한 참조가 nil인지도 검사한다. 기존 시험 기대값은 수정하지 않았다.
- 회귀 검출 확인: 추적 소스를 건드리지 않고 `E10/OptionWindows-mutant.swift` 사본에서 비활성 때도 활성 높이를 쓰게 바꿨다. 같은 새 시험이 `AT-FF-64 inactive options return to normal` 단언에서 예상대로 종료 1이었다. 변이 빌드·서명은 각각 종료 0이며 정상 소스는 그대로다.

### 명령·결과·증거

모든 명령의 cwd는 hejo다. 전체 시험은 지정한 게이트웨이 Python 환경으로 실행했다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `pgrep -f app-tests` | 1 | 전체 시험 전 다른 실행 없음 | `E10/app-pgrep.json` |
| `HEJO_PYTHON=P bash app/scripts/test.sh` | 0 | AT-FF-64, AT-FF-50~54·60~63·20~23, 기존 앱·통신 fixture·hooks 9개 통과 | `E10/app-full.log/json` |
| 변이 사본을 넣은 `xcrun swiftc <앱 소스·시험>` / `codesign` | 0 / 0 | 정상 소스를 보존한 별도 변이 실행 파일 | `E10/mutation-build.log/json`, `E10/mutation-sign.log/json` |
| 변이 시험 전 `pgrep -f app-tests` | 1 | 전체 시험과 겹치지 않음 | `E10/mutation-pgrep.json` |
| 변이 `app-tests-mutant --finder-picture <개발 리소스>` | 1 (예상) | 새 AT-FF-64가 원래 결함을 검출 | `E10/mutation-run.log/json` |
| `P scripts/scan_private.py` | 0 | 자기 앱 변경 개인값 검사 통과 | `E10/scan-private-code.log`, `E10/code-checks.json` |
| 자기 앱 3경로 `git diff --check` | 0 | 공백 오류 없음 | `E10/diff-check.log`, `E10/code-checks.json` |
| 자기 앱 3경로 `git commit --only` | 0 | 위 코드 커밋 생성, 시험한 blob과 동일 | `E10/app-commit.log/json` |

최종 보고서를 포함한 `P scripts/scan_private.py`와 보고서 `git diff --check`도 각각 종료 0이다(`E10/scan-private-report.log`, `E10/report-diff-check.log`, `E10/report-checks.json`).

전체 시험 소스 변경 목록은 빈 목록이다. 변이 확인 뒤에도 전체 시험 소스 바이트가 유지됐고, 커밋한 세 파일은 시험 당시 SHA-256과 모두 일치했다. 컴파일의 기존 경고는 남았지만 새로운 컴파일 오류·회귀 실패는 없었다.

미검증: 설치 앱에서 다른 앱으로 전환하는 사장 확인과 0.2.4 공개 후보 포함 여부는 후속 검토·공개 담당 범위다. 추가 기술 부채·설계 변경·임시 제품 코드는 없다. 다른 작업의 미추적 문서 두 폴더는 보존했다. 운영 적용·게이트웨이 재시작·앱 버전 변경·공개 후보·설치 앱 교체·push는 실행하지 않았다. 검토자는 공용 목록에 연결 창이 들어가지 않는 점, 보이는 창만 갱신하는 점, AT-FF-64의 닫힘·수명 검사를 확인하면 된다.


## 11차-TASK-12 (2026-11-22)

**구현자 판단: 구현·자체 시험 완료, 검토 대기.** 받은 설계는 `handoff.md` 11차 지시, spec 9판 REQ-FF-11, 수락 명세 AT-FF-70·71이다. 위험도 일반, 필요한 증거 수준 2이며 가짜 연결 응답과 실제 ConnectionsWindow·입력 시트·확인 알림을 사용하는 앱 시험으로 수준 2를 확인했다. 설계와 달라진 점은 없다.

착수 hejo main HEAD는 `56ddfcd8a0f18e61c5bdda0f3891e0fc17e7a50a`다. 코드 커밋 전체 해시는 **`52e25116ff43a51d0d2be16493885c6d331cd145`**다. 아래 `E11`은 `.build/finder-folders-evidence/round11-task12`, `P`는 게이트웨이 Python이다. 착수 상태·두 파일 SHA-256은 `E11/start.json`, 시험 소스 목록은 `E11/tested-sources.json`, 커밋 경로·blob 대조는 `E11/app-commit.json`에 있다.

### 변경과 보호 계약

- `ConnectionsWindow.swift`: 연결 창·시트를 `.none`으로 만들던 `model.privacy` 창 연결을 삭제하고, 입력 시트의 `.none` 지정도 삭제했다. 이제 기본 공유 설정을 유지한다. 아무 일도 하지 않는 창 콜백은 남기지 않았다. 모델의 privacy 계약과 기본 콜백, secure 입력·값 삭제·오류 표시·창 높이 처리 코드는 바꾸지 않았다.
- `ConnectionsTests.swift`: 기존 실제 연결 창과 가짜 비밀 입력 fixture에 AT-FF-70 관측을 추가했다. 가짜 비밀 값을 넣고 secure 필드를 확인하며, 입력 시트 부착 뒤·확인 알림이 열린 동안·입력 닫힘 뒤에 연결 창과 모든 하위 시트의 `sharingType != .none`을 검사한다. 확인 알림의 관측값은 알림이 열린 동안 구한 뒤 닫힘을 마쳐 단언한다. 입력을 닫으면 시트가 없고 값이 비어 있는지도 확인한다. 기존 시험 기대값·수락 명세는 수정하지 않았다.
- 회귀 검출 확인: 추적 소스를 바꾸지 않고 착수 HEAD의 ConnectionsWindow를 `E11/ConnectionsWindow-baseline.swift`에 추출해 새 시험과 빌드했다. 수정 전 사본은 새 AT-FF-70의 입력 단계 공유 단언에서 예상대로 종료 1이었다. 정상 소스로 실행한 최종 전체 시험은 통과했다.

### 명령·결과·증거

모든 명령의 cwd는 hejo다. 전체 시험은 지정한 게이트웨이 Python 환경으로 실행했다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| 수정 전 사본을 넣은 `xcrun swiftc <앱 소스·현재 시험>` / `codesign` | 0 / 0 | 정상 추적 소스를 보존한 별도 실행 파일 | `E11/baseline-build.log/json`, `E11/baseline-sign.log/json` |
| 수정 전 사본 시험 전 `pgrep -f app-tests` | 1 | 다른 실행 없음 | `E11/baseline-pgrep.json` |
| 수정 전 사본 `app-tests-baseline --task32-capture <가짜 자료 출력 폴더>` | 1 (예상) | `AT-FF-70 input stage shares connection window and every sheet`에서 기존 결함 검출 | `E11/baseline-run.log/json` |
| 최종 전체 시험 전 `pgrep -f app-tests` | 1 | 다른 실행 없음 | `E11/app-pgrep.json` |
| **`HEJO_PYTHON=P bash app/scripts/test.sh`** | **0** | AT-FF-70·71, AT83 등 기존 연결 시험, AT-FF-20~23·50~54·60~64, 전체 앱·통신 fixture·hooks 9개 통과 | `E11/app-full.log/json` |
| `P scripts/scan_private.py` | 0 | 자기 앱 변경 개인값 검사 통과 | `E11/scan-private-code.log`, `E11/code-checks.json` |
| 자기 앱 두 경로 `git diff --check` | 0 | 공백 오류 없음 | `E11/diff-check.log`, `E11/code-checks.json` |
| 자기 앱 두 경로 `git commit --only` | 0 | 위 코드 커밋 생성, 시험한 blob과 동일 | `E11/app-commit.log/json` |

전체 시험의 소스 변경 목록은 빈 목록이고, 커밋한 두 파일의 SHA-256은 시험 당시와 모두 일치한다. 기존 컴파일 경고는 남았지만 전체 시험은 오류 없이 끝났다. 보고서를 포함한 최종 `P scripts/scan_private.py`·보고서 `git diff --check`의 명령·종료 코드·로그 경로는 `E11/report-checks.json`에 기록한다.

미검증: 실제 화면 공유로 설치 앱을 보는 사장 확인(M11)은 0.2.4 설치 후 남아 있다. 이 시험은 창 공유 속성 계약을 검사한 수준 2이며 실제 화면 공유 관측으로 주장하지 않는다. 추가 기술 부채·임시 제품 코드·설계 변경은 없다. 검토자는 두 숨김 지정이 제거됐는지, 모델 계약과 보안 입력·높이 규칙이 그대로인지, 세 시점에서 하위 시트까지 검사했는지 확인하면 된다. 다른 작업의 미추적 문서 두 폴더는 보존했다. 운영 적용·재시작·릴리스·앱 버전 변경·공개 후보·설치 앱 교체·push는 실행하지 않았다.


## 12차-TASK-13 (2026-11-22)

**구현자 판단: 부분 구현 — 운영 진단·앱 표시 수정의 모델 시험 완료, 팀키트 수정은 2절 보고로 보류, 전체 앱 시험 미통과.** 받은 설계는 `handoff.md` 12차 지시다. 위험도 일반(허가된 운영 명령 1회), 필요한 증거 수준 3이다. 직원 D의 저장 성공(M6)은 아직 달성하지 못했다. 아래 `E12`는 `.build/finder-folders-evidence/round12-task13`, `P`는 게이트웨이 Python이다. 개인값은 추적하지 않는 진단 증거에만 남겼으며 이 절에는 직원 D/B로 적는다.

착수 hejo main은 `84e64ac3bcd50c71e2bae3e720b76d84d57a9212`, HD worktree는 `d7208c11c23ddb0dacddbe3e225864058f263006`이다. 착수·소스 해시는 `E12/start.json`, 실행본 대조는 `E12/backend-source-sha.json`에 있다. 착수 뒤 다른 작업의 문서 커밋이 main에 추가됐지만, 앱 제품 파일의 커밋 내용은 바뀌지 않았다.

### 허가된 운영 제출 1회와 실제 원인

- 고르기 응답의 지정 항목 id를 프로그램으로 하나만 선택했다. `hermes-connections app connect --profile <직원 D> --app com.apple.finder --scope <선택 후보 id> --json`을 HERMES_HOME=운영 홈, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1, 200초 제한으로 **한 번만** 실행했다.
- 실제 종료 코드 **0**, 약 **0.648초**, 응답 **waiting / UNDO_CONFLICT**, steps 빈 목록, stderr 없음이었다. stdout 최상위 키는 profile·app·outcome·reason·steps·next·undo_until이다. RESTART_REQUIRED나 성공 응답은 아니었다. 원래 문 로그의 command_failed와 같은 실패는 이 1회 실행에서 재현되지 않았으며, 과거 프로세스의 비JSON·비정상 종료·시간 초과 중 어느 것이었는지는 확정하지 않는다.
- 운영 파일의 수집한 전후 메타데이터 차이는 **0개**였다. 새 Finder 기록은 없고, 실패는 `transact`가 desired 파일을 구성하는 동안 `config_assembly.app_manifests`의 기존 충돌 검사에서 발생해 쓰기 단계로 들어가지 못했다. 명령을 반복하거나 app undo·잠금 삭제·메타데이터 재작성·재시작을 하지 않았다.
- 단계: enable/values 선택 검사 뒤, restart/permission/check 전에 트랜잭션 구성의 manifest 원본 기억 검사에서 거절된다. 잠금은 읽기 전용 진단 시 다른 프로세스가 보유하지 않았다.

| 관측 | 직원 D | 직원 B |
|---|---|---|
| 도구 묶음의 team-kit | hejo·slack·photon에 있음 | hejo·slack·photon에 있음 |
| files 활성 / 기존 폴더 개수 | true / 2 | true / 3 |
| 앱 grant 개수 / Finder grant | 7 / 없음 | 8 / 있음 |
| Finder 진행 기록 | 없음 | applied, 다섯 단계 완료 |
| team-kit host | 공용 창고를 가리키는 정상 링크 | 공용 창고를 가리키는 정상 링크 |
| 저장된 원본 기억과 현재 manifest | 불일치(1222→1254바이트, 도구 2개 추가) | 일치(1254바이트) |

직원 D는 같은 정상 링크 뒤 공용 창고가 갱신됐지만 이전 manifest 해시가 남아 있다. `config_assembly.py`의 `app_manifests`는 이를 외부 수정으로 보고 UNDO_CONFLICT로 거절한다. 실행본과 HD의 config_assembly 전체 파일은 다른 작업의 hejo toolset 반영 때문에 다르지만, 원인이 된 app_manifests 함수 본문 SHA-256은 같다. app_setup·app_connect 실행본은 HD와 같다.

증거: `E12/operation-started.json`, `operation-result.json`, `operation-stdout.json`, `operation-stderr.log`, `operating-before-metadata.json`, `operating-after-metadata.json`, `changed-operating-files.json`, `manifest-baseline-comparison.json`, `profile-comparison.json`, `all-record-metadata.json`, `lock-status.json`.

### 가짜 홈 재현과 팀키트 보류 사유

`E12/test_manifest_drift_repro.py`는 실제 프로필을 쓰지 않는다. 임시 HOME·HERMES_HOME을 resolve하고 기존 시험 fixture의 플러그인 원본을 임시 홈 안으로 복사한다. 가짜 연결로 원본 기억을 만든 뒤 공용 manifest에 가짜 도구 하나를 더하면, 새 Finder 연결이 기록 생성 전에 같은 UNDO_CONFLICT로 거절된다. 원래 manifest 바이트를 복원한 대조 실행은 성공했다. 운영 폴더를 입력으로 쓰거나 실행본을 바꾸지 않았다. 이는 결함 재현 증거이며 수락 시험 통과나 수정된 서버 동작으로 주장하지 않는다.

**멈춘 근거:** `app_manifests`의 해시 비교는 개인 오버레이·외부 수정을 보존하는 기존 계약이다. 기존 `test_removing_one_app_preserves_other_app_tools_and_external_changes`도 외부 수정 시 UNDO_CONFLICT를 기대한다. 비교를 단순히 없애거나 원본 기억을 자동으로 현재 값에 맞추면, 권한의 기준과 원래 상태로 되돌리는 의미를 바꿀 수 있다. 인계서의 원인 범위는 찾았지만 이 경우의 기준 갱신 계약은 정해지지 않았다. `20-implementation.md` 2절의 설계에 없는 의미 변경에 해당해 팀키트 코드는 고치지 않았다.

- 권고: 계획 담당이 정상 공용 창고 링크의 갱신과 개인 오버레이의 외부 수정을 구분하는 조건을 확정한다. 원본 링크·창고 대상을 검증하고, 기존 정책의 기본 도구 권한과 새 창고 도구 중 무엇을 유지할지, 원본 기억·링크 장부를 어떻게 원자적으로 갱신할지 정해야 한다. 개인 오버레이 외부 수정은 계속 거절하는 시험을 유지해야 한다.
- 다른 선택: 명시적 원본 기억 갱신 절차를 별도 설계한다. 운영 기억 파일을 수동으로 고쳐 우회하는 작업은 하지 않았다.
- 팀키트 제품·시험의 추적 변경과 커밋은 없다. 전체 team-kit의 AT-FF-12(나) 재실행은 미실행이다. 서버 적용도 별도 지시가 필요하다.

### 앱 수정과 실행한 검증

`ConnectionsWindow.swift`는 UNDO_CONFLICT에 저장이 멈춘 이유를 안내하고, pending에는 진행 중 문장을 표시한다. 나머지 비완료 응답은 기존 이유별 실패 문장을 쓰되 ConnectionSentence가 성공 문장을 돌려주면 비완료 안내로 바꾼다. 정상 done·비밀 칸·값 삭제·원시 오류 비노출·창 높이 코드는 유지한다. `ConnectionsTests.swift`에 waiting·failed·refused·partial·pending 응답과 정상 done 대조를 추가했다. 기존 시험 기대값은 바꾸지 않았다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| 위 운영 app connect 1회 | 0 | waiting / UNDO_CONFLICT, 수집 메타데이터 변화 0 | `E12/operation-result.json`, `operation-stdout.json`, `operation-stderr.log` |
| `P -m pytest -q -s -p no:cacheprovider E12/test_manifest_drift_repro.py` | 0 | 1 passed, 정상 창고 링크 갱신 충돌 재현과 원본 일치 대조 성공 | `E12/manifest-drift-repro.log/json` |
| 관련 5파일 + test_finder_folders + test_app_manifests | 0 | 107 passed, HD d7208c11, 임시 resolve HOME·HERMES_HOME. AT-FF-08·12(가) 포함 | `E12/team-related.log/json` |
| `HEJO_PYTHON=P bash app/scripts/test.sh` | 1 | 기존 AT-HC-27에서 멈춤, 실행 중 소스 변경 없음 | `E12/app-full.log/json` |
| 같은 전체 시험 바이너리 `--task32-capture` | 1 | 기존 AT-HC-27 동일 실패 | `E12/focused.log/json` |
| 착수 소스·기존 시험 사본 빌드 / 서명 / 연결 시험 | 0 / 0 / 1 | 기대값 그대로, AT-HC-27 동일 실패. visible=true, key=false, fieldsEmpty=true, busy=false, appActive=false | `E12/baseline-probe-build.log/json`, `baseline-probe-sign.log/json`, `baseline-probe-run.log/json` |
| `P scripts/scan_private.py`, 자기 앱 경로 `git diff --check` | 0 / 0 | 자기 변경 개인값·공백 검사 통과 | `E12/code-checks.json` |

AT-HC-27은 수정 전 코드에서도 앱이 비활성이어서 키 창이 아닌 상태로 실패한다. 이 기존 조건을 완화하거나 제품의 활성화 처리를 범위 밖에서 바꾸지 않았다. 새 시험 실행과 최종 커밋 상태는 아래 최종 인계에 이어 적는다.


### 최종 인계 — 부분 구현

앱 수정 커밋 전체 해시는 **`f03b93a0963c5510fb995288db939f9aaaa2de56`**다. ConnectionsWindow.swift·ConnectionsTests.swift 두 경로만 commit --only했다. 전체 시험에서 사용한 자기 두 파일과 커밋 blob SHA-256은 같으며, 전체 시험 실패를 통과로 주장하지 않는다(`E12/app-commit.log/json`).

| 추가 확인 | 종료 코드 | 범위와 결과 | 로그 |
|---|---:|---|---|
| 수정본 모델 전용 실행기 빌드 / 실행 | 0 / 0 | 새 시험 본문 그대로, 여섯 비완료 응답과 정상 완료 대조 통과. NSApplication을 초기화하거나 창을 띄우지 않음 | `E12/model-unit-build.log/json`, `model-unit-run.log/json` |
| 착수 표시 코드 + 같은 새 모델 시험 빌드 / 실행 | 0 / 1 (예상) | `TASK-13 conflict explains why saving stopped`에서 원래 결함 검출 | `E12/model-baseline-build.log/json`, `model-baseline-run.log/json` |
| 수정본 GUI 개별 실행기 빌드 / 서명 | 0 / 0 | 기존 HC27 관측과 새 시험을 분리할 수 있게 준비. 다른 app-tests 빌드·실행 감지로 **실행은 미실행** | `E12/current-probe-build.log/json`, `current-probe-sign.log/json`, `current-probe-pgrep.json`, `current-probe-pgrep-retry.json`, `current-probe-pgrep-final.json` |

모델 전용 실행기의 첫 빌드는 지원 파일에서 @main을 떼며 사라진 actor 문맥 때문에 종료 1이었다(`E12/model-unit-build-first-failure.log/json`). 추적하지 않는 지원 파일의 호출되지 않는 기존 main에 @MainActor를 붙여 고친 뒤 최종 빌드·실행이 각각 종료 0이었다. 제품 코드나 기존 시험 기대값은 바꾸지 않았다. 모델 실행 전 pgrep 결과와 UI를 쓰지 않는 격리는 `E12/model-unit-pgrep.json`·`model-baseline-pgrep.json`에 있다. 이 단위 실행은 전체 앱 시험 통과를 대신하지 않는다.

최종 보고서를 포함한 개인값 검사와 자기 보고서 공백 검사의 명령·종료 코드·로그는 `E12/report-checks.json`에 기록한다. 증거 수준 3은 허가된 운영 명령을 실제 환경에서 실행해 거절 결과를 관측한 진단에 한정한다. 앱 수정의 모델 시험과 가짜 홈 재현은 수준 2다. 저장 성공·서버 적용·사장 M6은 미완료다.

**다음 판단:** 정상 창고 링크 갱신 시 원본 기억·권한·복원 기준을 어떻게 유지할지 계획 담당이 확정해야 한다. 앱 전체 회귀도 앱 활성화와 독립된 시험 실행 구간을 확보한 뒤 다시 확인해야 한다. 팀키트 수정이 정해지면 가짜 재현을 회귀 시험으로 옮기고 관련 시험·AT-FF-12(나)·airport-check를 실행한다. 허가된 운영 제출 1회는 이미 소진됐으므로 새 지시 없이 같은 명령을 반복하지 않는다.

운영의 추가 변경·복원·실행본 교체·게이트웨이 재시작·실제 메시지·앱 공개·버전 변경·push는 하지 않았다. 운영 저장소의 다른 세션 변경과 HD worktree는 손대지 않았고, hejo의 다른 작업 미추적 문서 두 폴더도 보존했다. 안전한 독립 부분(진단·앱 표시)만 처리했으며, 실패한 기존 시험을 완화하지 않았다.


## 13차-TASK-13 (2026-11-22)

**구현자 판단: 팀키트 구현·지정 검증 및 앱 전체 회귀 완료, 검토·서버 적용 대기.** 받은 설계는 `handoff.md` 13차 지시, spec 10판 REQ-FF-12, design 9절, AT-FF-80~83이다. 위험도 일반, 필요한 증거 수준 2다. 12차에 허가된 운영 명령은 반복하지 않았다. 서버 적용·운영 명령·실행본 교체는 이번 범위에서 하지 않는다.

착수 hejo HEAD는 `648ea17c7f7d34b49216d2e9ba830c453feaf05c`, HD worktree 브랜치 `hejo-finder-folders-20261121`의 착수 HEAD는 `d7208c11c23ddb0dacddbe3e225864058f263006`이다. HD 코드·시험 커밋 전체 해시는 **`6602c04098393eff0d2a2c4ee0afd90ce5b88b76`**다. 자기 config_assembly.py·새 test_finder_manifest_updates.py 두 경로만 commit --only했고, 커밋 blob은 시험한 바이트와 같다. 아래 `E13`은 `.build/finder-folders-evidence/round13-task13`, `P`는 게이트웨이 Python이다. 착수·커밋·시험 바이트 대조는 `E13/start.json`, `HD-commit.log/json`, `tested-HD-sha256.json`에 있다.

### 한 곳의 변경과 실행본 대조

app_manifests의 지문 거절 조건만 다음과 같이 바꿨다.

```python
if store.fingerprint(before)!=baseline['after'] and not (
    'link' in before_host and entry is not None and entry.get('overlay') is False
    and before==canonical.read_bytes()
):raise ValueError('UNDO_CONFLICT')
```

링크 대상은 기존 store.snapshot이 검증한다. 세 조건 중 하나라도 맞지 않으면 기존 거절을 유지한다. template·original_host·app_tool_defaults·declared/additions·트랜잭션/undo 경로는 바꾸지 않았다. 새 함수·기록·저장 형식·제품 임시 코드는 없다. 설계와 달라진 점도 없다.

실행본 전체 파일은 다른 작업의 hejo toolset 변경 때문에 HD와 다르지만, 변경 전 app_manifests 본문은 동일했다. 위 한 곳 diff를 실행본 함수의 문자열 사본에만 적용하면 수정 worktree 함수와 정확히 같았다. 실행본에는 쓰지 않았다.

| 함수 본문 | SHA-256 |
|---|---|
| HD 착수·현재 실행본 | `4a2a74b64516d74f2c12f9c7ce41ce5c8241a8694a04f00a5fc658bab46b54de` |
| HD 수정본·실행본 함수에 diff를 가상 적용한 결과 | `540a263dc2903ac4e76f839460cac59c291b8f2305ce01526a1faffa863bee7e` |

전체 파일 SHA와 비교 방법은 `E13/function-parity.json`, 실제 함수 diff는 `E13/function.diff`에 있다. 후속 서버 적용은 다른 세션의 변경을 보존하도록 별도 지시로 진행해야 한다.

### 새 시험과 기존 기준 유지

새 시험 6개는 전부 임시 resolve HOME·HERMES_HOME과 가짜 자료를 쓴다. 기존 TASK-13 재현에서 공용 manifest 갱신 fixture를 옮겼고, 실제 운영 폴더는 입력으로 쓰지 않았다.

- AT-FF-80: 검증된 공용 링크와 overlay false 장부에서 창고 manifest에 가짜 도구를 추가한 뒤 Finder 연결이 성공하고 기록이 생성되는지 확인한다. 저장된 after 지문은 실제 적용된 host manifest와 같아야 한다. 가짜 새 도구를 기본 도구 권한에 자동 추가하지 않는 것도 확인한다(기존 declared/additions 규칙 유지).
- AT-FF-81: 개인 오버레이 외부 수정과 창고 밖 링크를 각각 거절하고 가짜 운영 파일 바이트가 그대로인지 확인한다. 장부가 없거나 overlay true인 경우도 거절한다. 두 읽기 사이 창고 바이트가 달라지는 경우도 대역으로 주입해 세 번째 조건을 검사한다.
- AT-FF-82: Finder 저장 동안 원래 before·host가 유지되고, app undo 뒤 Finder 연결 전 host·manifest·정책 바이트와 기존 앱 grant가 그대로인지 확인한다.
- 수정 전에는 정상 연결/undo 시험 하나가 실패하고 나머지 거절 시험 5개가 통과했다(`E13/red.log/json`). 수정 후 관련 113개가 통과했다. 이는 새 시험이 원래 거절 결함을 검출한다는 비교다. 기존 기대값·skip·수락 명세는 바꾸지 않았다.

### team-kit 검증 명령·종료 코드

검증은 게이트웨이 Python, 저장소 지침의 PYTHONPATH(HD lib·기존 pytest 의존성·본체 import 경로), Node PATH, 임시 resolve HOME·HERMES_HOME·HERMES_ROOT로 실행했다. 본체 파일은 수정하지 않았다. 기준 재확인은 추적하지 않는 사본에 추출한 `66f2a44c190390edd2a8a8eab9b2c32cba20195a`의 라이브러리로 기존 29개 node를 실행했다. 선택한 기존 시험 파일도 그 커밋과 바이트가 같음을 확인했다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| 수정 전 새 시험 6개 | 1 (예상) | 정상 연결 1 failed, 보호 경계 5 passed | `E13/red.log/json` |
| `P -B -m pytest` 관련 5파일 + test_finder_folders + test_app_manifests + 새 시험 | 0 | 113 passed | `E13/related.log/json` |
| `66f2a44c` 라이브러리로 원래 실패 node 재확인 | 1 (예상 기준) | 28 failed·1 error, 기존 29개 | `E13/baseline66-failures.log/json`, `legacy-baseline-nodes.json` |
| `P -B -m pytest` team-kit 전체 | 1 (기존 실패) | 5019 passed·64 skipped·28 failed·1 error, 실패/오류 node 29개 | `E13/full.log/json` |
| 실패 node 집합 비교 | 조건 충족 | 기준 29, 수정본 29, 새 node 0·제거 0, 부분집합 true | `E13/failure-comparison.json` |
| `P ./airport-check --snapshot .` | 0 | boundary 382·document 0·compartments 0 PASS | `E13/airport.log/json` |
| 자기 HD 두 경로 `git diff --check` | 0 | 공백 오류 없음 | `E13/diff-check.log/json` |
| 자기 HD 두 경로 `git commit --only` | 0 | 위 6602c040 커밋, 시험 blob과 일치 | `E13/HD-commit.log/json` |

공항 검사는 운영 명령 금지에 맞춰 저장소 스냅샷 모드로 실행했다. baseline 줄이기 가능 4건 안내만 있었고 기준선 파일은 바꾸지 않았다.

초기 전체 실행에는 앱 시험용 PYTHONPATH를 함께 사용해 선택적 문 통합 시험이 추가됐다. 그때는 착수 사본·수정본 모두 28 failed·48 errors였다. 원래 AT-FF-12 기준 환경이 아니어서 해당 결과를 29개 기준 통과로 쓰지 않았고, 모두 `E13/initial-app-pythonpath-*`에 보존했다. 규정된 team-kit 환경으로 재실행하고 66f2a44c의 원래 29개 기준도 재확인한 것이 위 최종 결과다. 시험에 skip을 추가하거나 실패 기준을 바꾸지 않았다.

### 앱 전체 회귀와 최종 인계

다른 GUI 시험이 실행 중이어서 종료를 기다렸다(`E13/app-resource-wait.json`). 대기 뒤 `pgrep -f app-tests` 종료 1과 다른 GUI 빌드 없음이 확인된 때에만 실행했다(`E13/app-pgrep.json`, `gui-builds.json`). 제품 앱 변경 없이 hejo HEAD `648ea17c7f7d34b49216d2e9ba830c453feaf05c`에서 실행했다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `HEJO_PYTHON=P bash app/scripts/test.sh` | 0 | 322.846초, 기본 GUI·통신 fixture·마지막 Python 9시험 통과 | `E13/app-full.log/json` |

기존 AT-HC-27을 포함한 기본 GUI 시험이 `APP_TEST_OK`로 끝났고, AT-FF-20~23·40~41·50~54·60~64·70~71 회귀도 통과했다. 기존 기대값은 바꾸지 않았다. 시험 중 앱 Sources/Tests 변경 목록은 빈 배열이다(`E13/tested-sources.json`, `app-full.json`). 마지막 설정 메타데이터·다운로드 이름 보존 검사도 통과했다.

V-7의 앱 비활성 실패가 이번에는 재현되지 않아 조건부 수정 전 사본 대조는 실행하지 않았다. 이전 실패 원인이 확정됐다는 뜻은 아니다. 대조 사본·바이너리 무결성 사전 확인은 `E13/app-probe-integrity.json`에 남겼다. 대기 중 프로세스 샘플 시도는 이미 해당 시험 프로세스가 종료돼 코드 255였으며 판정에 쓰지 않았다(`E13/sample-attempt.json`).

게이트웨이 Python의 `scripts/scan_private.py`와 자기 보고서 `git diff --check` 결과는 `E13/report-checks.json`에, 보고서 한 경로만 `git commit --only`한 명령·종료 코드·전체 hejo 커밋 해시는 `E13/hejo-commit.log/json`과 최종 result에 기록한다.

운영 저장소 main·실행본·다른 세션 파일은 건드리지 않았고 운영 명령도 실행하지 않았다. HD worktree는 커밋 후 깨끗했다. hejo의 다른 작업 미추적 문서 두 폴더도 보존했다. 재시작·릴리스·설치 앱 교체·push는 하지 않았다. 남은 일은 이 변경과 증거 검토 후, 다른 세션 변경을 보존하는 별도 서버 적용 지시 및 직원 D의 M6 확인이다. 기존 사용자 확인·공개·푸시 승인도 별도다.


## 14차-TASK-14 (2026-11-22)

**구현자 판단: 서버 파일 적용·허가된 연결 제출 완료, 연결 완료는 RESTART_REQUIRED로 보류.** 받은 설계는 handoff 14차이며 위험도 일반(운영 적용), 필요한 증거 수준 3이다. 착수 hejo HEAD `6c68e29984a530b94996f04d8dfe18989120cce1`, 운영 main HEAD `a566566737fde11e95cbc41eba0ba3bfe13a4d84`에서 시작했다. 이하 `E14`는 `.build/finder-folders-evidence/round14-task14`, `P`는 게이트웨이 Python이다.

### 교체 전 롤백 기록

운영 main에 지정 HD 커밋을 cherry-pick한 결과는 `b95e31a2e212521ee29ba3493193a217c6820eff`이다. 바뀐 경로는 config_assembly.py와 새 test_finder_manifest_updates.py 두 곳뿐이다. 실행본 교체 직전 SHA-256은 `2684eb46e088356e4a159d1a424669b6917224c8065c4fe128416bec7c28dfde`이며 지정 기준과 같다.

실행본 변경 전에 보관한 0700 디렉터리는 `E14/rollback-3aby0zh8`이며, 안의 config_assembly.py SHA는 위 착수값과 같다. 실패 시 이 보관 파일을 실행본 옆 임시 파일에 복사·fsync한 뒤 이름 바꾸기로 복원하고 착수 SHA를 다시 확인한다. 재시작은 하지 않는다. 기계 판독용 기록은 `E14/rollback-record.json`이다. 교체는 운영 main 파일 한 개만 하며 시험 파일은 실행본에 넣지 않는다.

### 적용·검증 결과

운영 cherry-pick 커밋은 **`b95e31a2e212521ee29ba3493193a217c6820eff`**이며 부모는 위 착수 main이다. 다른 세션의 기존 toolset 변경은 그대로 유지했다. 변경 경로는 team-kit lib/hermes_facility/config_assembly.py와 tests/test_finder_manifest_updates.py뿐이다(`E14/cherry-pick.log/json`). merge·rebase·sync는 하지 않았다.

운영 main에는 `test_finder_folders.py`가 자동 기록 커밋 `5824d602`에서 제거되어 없었다. 초기 보조 실행은 존재하는 7파일만 골라 84 passed였으므로 지정 8파일 완료로 쓰지 않았다(`E14/related.log/json`). 운영 저장소에 세 번째 경로를 추가하는 대신, HD 검토 커밋의 해당 시험 바이트를 임시 시험 트리에 그대로 복사하고 그 트리의 lib·manifest·다른 플러그인을 운영 main에 연결했다. 시험의 `__file__` 상대 경로로 실행되는 감사 훅 자식 프로세스도 main lib를 읽는다. 이 임시 시험을 기존 7파일과 함께 실행한 최종 결과가 아래 114 passed다. 시험 기대값·skip·운영 저장소 파일은 바꾸지 않았다(`E14/missing-test-source.json`, `run_backend.py`). 진행 안내에서 말한 113개는 이전 HD 결과를 잘못 인용한 것으로, 이번 main의 실제 결과는 114개다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `git cherry-pick 6602c04098393eff0d2a2c4ee0afd90ce5b88b76` | 0 | 위 main 커밋, 허용된 두 경로만 | `E14/cherry-pick.log/json` |
| `P -B -m pytest -q -p no:cacheprovider` 관련 8파일 | 0 | 114 passed, 임시 resolve HOME·HERMES_HOME·HERMES_ROOT, 운영 main lib | `E14/related-complete.log/json` |
| `P ./airport-check --snapshot .` | 0 | 공항 스냅샷 검사 통과 | `E14/airport.log/json` |
| 실행본 한 파일 임시 복사·fsync·이름 바꾸기 | 0 | 실행본 = 운영 main = 커밋 파일, 시험 파일 미설치 | `E14/replacement.json`, `final-integrity.json` |

실제 교체 후 SHA-256은 **`f2c64d1d908f26f5954c59d770bf8b9bdba29815e50ef14c35c48260788e7df3`**다. 교체 직전에 지정 착수 SHA를 다시 검사했다. 파일 교체 복원은 실행하지 않았고 보관본은 유지한다. 보관본은 이번 코드 파일만 되돌리는 용도이며, 아래 연결 설정 변화까지 되돌리는 사본은 아니다.

### 재시작 판단의 범위

`E14/restart-analysis.json`과 `function-callers.log`에 실행본 소스의 호출 경로를 기록했다. hejo connection_runtime.TeamKit.run은 hermes-connections를 요청마다 새 자식 프로세스로 실행하고, 그 진입점은 설치된 게이트웨이 Python으로 exec한 뒤 실행본 lib의 connections.main을 가져온다. app 요청의 run_command → app_connect.run → transact → app_manifests 경로이므로 이번 함수 수정 자체를 읽는 데 게이트웨이 재시작은 필요하지 않다.

게이트웨이 도구의 mac_apps/discovery가 읽기용 pending_progress·legacy_values·settings_for를 쓰려고 app_connect를 import할 수는 있다. 검색한 소스에서 app_manifests 호출은 CLI 연결 트랜잭션 한 곳뿐이다. 이 판단은 소스 경로 수준이며, 게이트웨이 메모리를 검사하거나 재시작한 증거라는 뜻은 아니다. 아래 연결 조립 결과의 RESTART_REQUIRED는 별도 런타임 단계다.

### 직원 D 연결 1회와 멈춤

12차와 동일한 선택 항목 id로 허가된 제출을 **한 번** 실행했다. 환경은 HERMES_HOME=<HOME>, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1이고 200초 제한을 걸었다. 원시 응답의 개인값은 기록하지 않고 stdout 키와 판정에 필요한 필드만 남겼다.

```text
<HOME>/bin/hermes-connections app connect --profile <직원 D> --app com.apple.finder --scope <12차와 동일 항목 id> --json
```

- 종료 코드 0, 0.701초, 시간 초과 아님, stderr 없음.
- outcome=waiting, reason=RESTART_REQUIRED, next.kind=gateway_restart, committed=true.
- enable·values는 done이며 restart·permission·check는 todo다. 기존 UNDO_CONFLICT 거절은 발생하지 않았다.
- 결과는 `E14/operation-result.json`, 1회 제출 표식은 `operation-started.json`, 실행 방법은 `submit_once.py`에 있다. 표식이 있으면 재실행하지 못하게 했다.

인계의 멈춤 조건을 충족해 추가 운영 동작을 하지 않았다. 재시작·권한 창 조작·이어서 제출·app undo는 실행하지 않았다. 연결 성공(done)이 아니므로 조건부 저장 폴더 읽기 확인도 미실행이다. 코드 파일 교체는 검증된 SHA 상태로 유지했다.

연결 전후 lstat(내용 미열람)에서 메타데이터가 바뀐 운영 경로는 9개다. owner의 policy.yaml·team.yaml·vault.yaml, plugin-store/links.json, 직원 D의 config.yaml, team-kit 호스트 경로와 그 plugin.yaml, Finder 연결 기록과 manifest-bases.json이다. 원시 파일 내용 변화 9건으로 단정하지 않는다. 해당 목록과 메타데이터는 `E14/changed-operating-files.json`, `operating-before-metadata.json`, `operating-after-metadata.json`에 있다. 비밀 파일·연결 기록 안의 undo 원문은 열지 않았다.

되돌리기는 기존 `app undo` 경로이며 이번에는 실행하지 않았다.

```text
<HOME>/bin/hermes-connections app undo --profile <직원 D> --app com.apple.finder --json
```

응답에 기록된 undo_until은 **2026-11-22 18:26:54 +09:00**이다(기존 600초 계약). 시간 만료나 후속 변경으로 거절되면 수동으로 원문을 덮어쓰지 않고 별도 지시를 받아야 한다. 코드 파일 복원 방법은 위 롤백 기록과 별개다.

### 최종 상태와 남은 일

운영 저장소 main은 위 cherry-pick 커밋이고 작업 트리는 깨끗하다. 운영 명령이 바꾼 설정은 실행 환경에 있으며 sync로 사본을 수집하거나 이번 커밋에 넣지 않았다. 실행본 config_assembly.py와 main·커밋 바이트 일치, 새 시험 파일의 실행본 부재를 다시 확인했다(`E14/final-integrity.json`).

위험도 일반, 실제 도달 증거 수준 3(운영 파일 교체와 실제 CLI 응답)이다. 연결 완료·권한 확인·저장 폴더 읽기 완료 증거는 아니다. 설계의 분기와 달라진 동작은 없으며, 시험 파일 부재는 위 임시 소스로 보완했다. 게이트웨이 재시작·릴리스·설치 앱 교체·실제 메시지·push는 하지 않았다. 다른 세션 파일과 hejo 미추적 문서 두 폴더는 보존했다.

남은 일은 검토 후 RESTART_REQUIRED에 대한 다음 운영 지시와 직원 D M6이다. 기존 0.2.4 및 사용자 확인·푸시 승인도 별도다. 보고서의 개인값 검사·공백 검사와 자기 한 경로 commit --only 결과는 `E14/report-checks.json`, `hejo-commit.log/json` 및 최종 result에 기록한다.


## 15차-TASK-14 계속 (2026-11-22)

**구현자 판단: 승인된 재시작 이어 하기와 연결 설정 확인 완료, 검토·사장 M6 대기.** 받은 설계는 handoff 15차, 사장 승인 시각은 2026-11-22 18:20이다. 위험도 일반(운영 재시작), 필요한 증거 수준과 실제 도달 수준은 3이다. 다른 hejo 세션의 겹침 없음 회신은 인계서에 기록돼 있다. 이번에 다시 메시지를 보내거나 다른 재시작 방법을 쓰지 않았다.

착수 hejo HEAD는 `3bb1489984484260a2a98c0aa7b3d41b1ec8b8f1`, 운영 main은 `b95e31a2e212521ee29ba3493193a217c6820eff`다. 이하 `E15`는 `.build/finder-folders-evidence/round15-task14`다. 제품 코드·시험·수락 기준 변경은 없다. 앞선 적용 SHA `f2c64d1d908f26f5954c59d770bf8b9bdba29815e50ef14c35c48260788e7df3`를 착수·종료 때 확인했으며 실행본과 운영 main이 같다.

### 재시작 직전 확인과 1회 실행

게이트웨이 Python으로 기존 gateway_restart.running_turns를 읽기 호출한 결과 0건이었다. state/connections/restart.json은 읽기만 했고 기록된 시각은 60분 제한 밖이었다. gateway.pid의 kind=hermes-gateway, PID=83899였고 ps가 보여 준 시작 시각은 17:57:24였다. 로그의 7155줄·801365바이트 지점을 직전 위치로 기록했다(`E15/preflight.json`, `gateway-before.json`).

다음 명령을 **한 번** 실행했다. HERMES_HOME=<HOME>, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1을 지정하고 외부 제한은 200초로 뒀다. 1회 표식이 있으면 다시 제출하지 못하도록 했다.

```text
<HOME>/bin/hermes-connections app connect --profile <직원 D> --app com.apple.finder --resume gateway_restart --json
```

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| 위 app connect 이어 하기 | 0 | 40.670815초, timeout 없음, stderr 없음, done/OK | `E15/operation-started.json`, `operation-result.json`, `operation-stderr.log` |
| 게이트웨이 Python 저장 폴더 읽기·is_dir 확인 | 0 | 선택 항목 포함, 폴더 3개·전부 존재·전부 NFC, files.enabled=true | `E15/saved-folder-check.json` |
| PID·재연결 로그 판독 | 0 | PID 변경, hejo 6·Slack 6·iMessage 1, NOT_RECONNECTED 없음 | `E15/gateway-after.json`, `reconnection-check.json` |

응답의 enable·values·restart·permission·check는 모두 done이고 next.kind=done이다. 별도 gateway restart 명령·kill·launchctl·hejo-release를 쓰지 않았다. BUSY·RATE_LIMITED·RESTART_FAILED·권한 대기 응답은 없었으며 재시도도 없다. 기존 drain 재시작 경로에서 권한·최종 확인까지 이어진 결과다. 원시 응답의 개인값은 남기지 않고 stdout 키와 단계·판정 필드만 기록했다.

### 재시작 전후 PID·로그 줄

- 전: PID **83899**, 시작 17:57:24, gateway.log **7155줄**까지 기록.
- 후: PID **43422**, ps 시작 **18:24:41**, 명령 반환 시 **7240줄**, 읽기 검증 시 **7247줄**.
- 같은 로그 inode에서 **7200줄**에 Starting Hermes Gateway가 나왔다.
- **7226·7229·7231·7233·7235·7237줄**에 hejo 어댑터 연결 6건.
- **7227·7230·7232·7234·7236·7238줄**에 Slack 연결 6건, **7228줄**에 iMessage(photon) 연결 1건.
- 추가된 로그 구간에 NOT_RECONNECTED가 없었다. 직원·프로필 이름이나 실제 로그 본문은 옮기지 않고 줄 번호·서비스 종류만 기록했다. 이는 어댑터 재연결 증거이며 다른 Mac의 앱 화면이나 실제 메시지 송수신을 검증한 것은 아니다.

### 저장 폴더 확인과 보존 범위

직원 D의 config.yaml에서 files 설정만 읽어, 12차 선택 항목 id와 같은 경로가 folders에 있는지 확인했다. 총 3개이며 전부 존재하고 NFC 형식이다. 폴더 안의 파일은 열지 않았고 비밀 파일·연결 기록의 undo 원문도 열지 않았다.

첫 보조 확인에서는 일반 option의 해시 id라고 잘못 가정해 일치 비교가 실패했다(종료 1, `E15/initial-hash-assumption-folder-check.json`). 실제 finder_scopes는 id=value인 NFC 경로를 반환한다는 코드를 확인한 뒤, 제품·시험·설정은 바꾸지 않고 그 계약대로 직접 비교해 종료 0을 확인했다. 최초 실패도 보존했다. 시험 기대값 완화나 연결 재제출이 아니다.

착수 때 운영 작업 트리는 인계 시점 3개보다 늘어난 32개 변경·삭제와 다른 작업 문서가 있었다. 이번 작업은 이 경로를 수정·스테이징·커밋·sync하지 않았다. 진행 중 다른 세션의 OPS-REPO-RENAME 커밋이 들어와 운영 main은 `f0844bdcc43efc192f7cae9ffe399c5b8104bd23`로 바뀌었고 작업 트리 상태도 달라졌다. 이 작업의 b95e31a2는 현재 main의 조상이고 config_assembly.py의 바이트는 그대로다. 착수에 별도 해시를 기록한 owner/policy.yaml·owner/team.yaml 사본도 동일하다. 현재 상태와 대조 범위는 `E15/start.json`, `final-integrity.json`을 따른다. 다른 세션 변경을 되돌리거나 이 작업 것으로 합치지 않았다.

이번에 자기 hejo impl-report 한 경로만 commit --only한다. 개인값·공백 검사와 커밋 결과·전체 해시는 `E15/report-checks.json`, `hejo-commit.log/json` 및 최종 result에 기록한다. 운영 저장소 커밋은 이번에 만들지 않았다. 새 테스트 실행은 요구되지 않았고 제품 바이트도 바꾸지 않아 전체 회귀를 반복하지 않았다.

남은 일은 이 운영 증거 검토, 호스트/계획 담당의 다른 세션(d2) 완료 알림, 직원 D의 실제 파일 읽기 사장 M6다. 기존 0.2.4 및 사용자 확인·마지막 M7·푸시 승인도 별도다. 추가 재시작·실제 메시지 발송 명령·릴리스·push는 하지 않았다.


## 16차-TASK-15 (2026-11-22)

**구현자 판단: 보류(구현 규칙 2절 보고).** handoff 16차 2항의 "기존 기대값은 바꾸지 않는다(정책 바이트 불변을 단언한 기존 시험이 이 보정과 부딪히면 멈추고 보고)"에 해당하는 충돌을 실제 코드에서 확인했다. 제품 코드·기존 시험·수락 명세를 바꾸지 않고 운영 적용 전에 멈췄다.

받은 설계는 spec 11판 REQ-FF-12 AC-05·06, design 9.1, AT-FF-84~86이다. 위험도 일반(운영 적용·정책 한 곳), 요구 증거 수준 3이다. 착수 hejo HEAD `a502285492efa1ad0c016c31399cdb136cec3165`, HD 브랜치 hejo-finder-folders-20261121 HEAD `6602c04098393eff0d2a2c4ee0afd90ce5b88b76`이다. HD 작업 트리는 깨끗했다. 이하 `E16`은 `.build/finder-folders-evidence/round16-task15`다.

### 충돌 근거

기존 `tests/test_finder_manifest_updates.py::test_store_update_connects_finder_and_undo_preserves_originals`는 가짜 창고에 fixture_store_tool을 더한 뒤 Finder 연결을 제출한다. 16차가 바꾸려는 바로 그 검증된 공용 창고 갱신 상황이다.

| 위치 | 현재 단언/계약 | 16차 보정과 관계 |
|---|---|---|
| 시험 52줄 | 연결 뒤 policy.yaml 바이트가 연결 전 before_policy와 같음 | 새 창고 도구를 app_tool_defaults 끝에 더하면 정책 바이트가 달라지므로 동시에 만족할 수 없음 |
| 시험 53줄 | 그 새 가짜 도구는 연결 전 기본 도구에 없음 | 기존 도구를 다시 더하는 무변경 사례로 해석할 수 없음을 보여 줌 |
| 시험 51줄 | 저장한 before는 원래 baseline before, host도 원래 host와 같음 | 현행 app_manifests는 before에 template.hex()를 저장함. template을 새 창고 바이트로 바꾸는 지시를 현행 저장 경로에 그대로 적용하면 before 단언도 달라짐. 복구 바이트와 조립 template의 관계를 명확히 해야 함 |
| spec REQ-FF-12 AC-03 | 기본 도구 권한은 바뀌지 않음 | design 9.1의 검증된 창고 새 도구 추가 예외와 적용 범위 정리가 필요함 |

AT-FF-84는 동일 상황에서 새 창고 도구를 기본 도구에 추가하고 링크를 유지하라고 한다. 기존 정책 불변 시험을 삭제·완화하거나 fixture를 다른 사례로 바꾸면 "기존 기대값 불변"을 위반한다. 따라서 구현자가 임의로 해결하지 않았다. `E16/conflict-evidence.json`에 충돌 내용과 변경 없음 대조를 남겼다.

### 실제 확인과 미실행

기존 단언이 현재 변경본에서 활성 상태로 통과하는지는 원래 시험 하나를 그대로 실행해 확인했다. 게이트웨이 Python, 임시 resolve HOME·HERMES_HOME·HERMES_ROOT, 기존 팀키트 PYTHONPATH, Node PATH, 바이트코드 쓰기 금지 환경을 사용했다.

```text
P -B -m pytest -q -p no:cacheprovider hermes/plugin-store/team-kit/tests/test_finder_manifest_updates.py::test_store_update_connects_finder_and_undo_preserves_originals
```

종료 0, **1 passed**, 시험 자체 1.78초다(`E16/unchanged-baseline.log/json`). 이는 HD 6602c040의 기존 계약 확인이며 새 TASK-15 구현 통과 증거가 아니다. 도달 증거는 소스 대조 수준 1·기존 가짜 시험 수준 2이며, 요구한 새 운영 실행 수준 3에는 도달하지 않았다.

- HD 제품·시험 수정 및 새 코드 커밋: 미실행. AT-FF-84 코드 추가도 미실행.
- 관련 전체·team-kit 전체·airport-check: 미실행. 변경 전 계약의 충돌을 먼저 보고하는 단계이므로 전체 검사를 반복하지 않았다.
- 실행본 config_assembly.py·시험 설치·운영 정책 보정·연결 재제출·plugin-store 검사·sync: 모두 미실행. 운영 명령 0회다.
- 운영 main 커밋: 없음. 코드 교체·정책 변경 전후 값·보관본은 해당 없음(변경 자체를 하지 않음).
- 실행본 config_assembly.py SHA는 착수·종료 모두 `f2c64d1d908f26f5954c59d770bf8b9bdba29815e50ef14c35c48260788e7df3`다. HD 제품·시험 SHA와 깨끗한 상태도 그대로다(`E16/start.json`, `conflict-evidence.json`).
- 다른 세션 파일·플러그인 폴더·비밀 파일에 손대지 않았고 재시작·실제 메시지·릴리스·push도 하지 않았다.

### 계획 담당에게 필요한 결정과 다음 범위

권고는 새 목표(검증된 창고 갱신 시 실효 도구와 링크 유지)를 유지하면서, REQ-FF-12 AC-03 및 기존 AT-FF-80/82 시험의 정책 불변 적용 범위와 저장 before의 의미를 먼저 정리하는 것이다. 기존 시험의 어떤 단언을 어떤 독립된 기대값으로 바꿔야 하는지 새 인계에 명시해야 한다. 오버레이 외부 변경·창고 밖 링크 거절 및 undo 복원 보호는 계속 보존해야 한다.

기존 시험 변경이 명시적으로 허용되기 전에는 이 구현·운영 적용을 이어갈 수 없다. 이후에는 AT-FF-84 구현·지정 회귀를 통과한 뒤 실행본/시험 설치 → 정책 한 곳 보정 → 연결 1회 → 검사/동기/자기 경로 커밋 순서로 돌아가야 한다. 이번에는 OPS-REPO-RENAME에 새로 넘길 운영 소유 경로나 커밋이 없다.

이번 보고서 한 경로의 개인값·공백 검사와 commit --only 결과·전체 해시는 `E16/report-checks.json`, `hejo-commit.log/json` 및 최종 result에 기록한다. 판정·명세·수락 시험 문서는 구현자가 고치지 않았다.


## 17차-TASK-15 (2026-11-22)

**구현자 판단: HD 구현·지정 회귀 완료, 운영 복구는 저장 후 RESTART_REQUIRED로 부분 완료.** handoff 17차와 spec 12판·design 9.1/9.2를 따르며 위험도 일반, 요구 증거 수준 3이다. E17은 `.build/finder-folders-evidence/round17-task15`다.

### 운영 변경 전 보관 기록

실행본 교체 직전 SHA는 `f2c64d1d908f26f5954c59d770bf8b9bdba29815e50ef14c35c48260788e7df3`다. 0700 보관본은 `E17/rollback-rxdnlsto`이며 코드·기존 시험 유무·정책을 먼저 기록했다(`E17/rollback-record.json`). 코드/기존 시험은 보관 파일을 임시 형제 파일에 복사·fsync·이름 바꾸기로 복원하고, 원래 없던 자기 시험만 제거한다. 정책은 별도 보관본으로 복원한다. 연결 트랜잭션의 되돌리기는 코드 파일 복원과 별개다. 재시작은 하지 않는다.

### 착수·변경·커밋

착수 hejo HEAD는 `d913d77359e9d7f6182dac503545c71525d0c08c`, HD 착수 HEAD는 `6602c04098393eff0d2a2c4ee0afd90ce5b88b76`다. HD 새 커밋 전체 해시는 **`5bd1da2be2ea6c8088163757dbcfab6adf0440a0`**이며 자기 config_assembly.py·test_finder_manifest_updates.py 두 경로만 commit --only했다. 커밋 blob은 시험한 바이트와 같다(`E17/HD-commit.log/json`, `tested-HD-sha256.json`).

검증된 창고 갱신의 기존 세 조건은 유지했다. 그 갈래에서만 현재 창고 manifest를 조립용 template으로 쓰고, 옛 template에 없던 새 도구를 기존 기본 도구 끝에 창고 순서로 추가한다. recovery_template을 별도로 두어 manifest-bases의 before·host·이전 링크 복구 정보는 바뀌지 않게 했다.

기존 52줄의 단언 한 곳만 허가대로 고쳤다. 이전 정책을 읽어 해당 기본 도구 목록 끝에 가짜 새 도구 하나를 더한 기대 바이트와 전체 정책을 비교한다. 나머지 기존 before/host 보존·새 도구의 연결 전 미포함·undo 뒤 복원 단언은 그대로다. 같은 시험에 심링크·overlay false를 더했다(AT-FF-84).

기존 오버레이를 정책 보정 뒤 원래 공용 링크로 복구하는 가짜 시험 하나도 더했다. 이때 YAML의 서식만 달라 바이트 비교만으로 링크가 되지 않는 경우가 있어, 원래 host가 링크이고 조립 결과의 YAML 내용이 창고 전체와 같을 때만 창고 바이트·원래 링크를 사용하게 했다. 이 분기는 외부 변경 지문 검사를 통과한 뒤 실행한다. 제한된 개인 manifest가 창고 전체와 다르면 기존 오버레이 조립을 유지한다. 별도 플러그인 폴더 편집 경로는 만들지 않았다.

새 정책 단언은 수정 전 구현에서 실패했다(`E17/red.log/json`: 1 failed·5 passed). 초기 통합에서 새 오버레이 복구 시험만 실패한 결과도 `related-initial.log/json`에 보존했다. YAML 내용 일치 처리 후 아래 관련 시험이 모두 통과했다. 다른 기존 시험 기대값은 고치지 않았다.

### HD 검증 명령·실제 결과

게이트웨이 Python, 임시 resolve HOME·HERMES_HOME·HERMES_ROOT, 팀키트 lib·기존 pytest 의존성·본체 import 경로, Node PATH, PYTHONDONTWRITEBYTECODE=1·HERMES_DISABLE_LAZY_INSTALLS=1을 사용했다. 본체 파일은 수정하지 않았다.

| 명령 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `P -B -m pytest -q -p no:cacheprovider` 관련 8파일 | 0 | 114 passed | `E17/related.log/json` |
| `P -B -m pytest -q -p no:cacheprovider` team-kit 전체 | 1 (기존 실패) | 5020 passed·64 skipped·28 failed·1 error, 58 subtests passed | `E17/full.log/json` |
| 전체 실패 집합 비교 | 조건 충족 | 기존 66f2a44c 기준 29개 = 현재 29개, 새 node 0·부분집합 true | `E17/failure-comparison.json` |
| `P ./airport-check --snapshot .` | 0 | 공항 스냅샷 검사 통과 | `E17/airport.log/json` |
| 자기 HD 두 경로 `git diff --check` | 0 | 공백 오류 없음 | `E17/HD-diff-check.log/json` |
| 자기 HD 두 경로 `git commit --only` | 0 | 위 HD 커밋·시험 blob 일치 | `E17/HD-commit.log/json` |

관련 파일은 test_app_catalog·test_app_connect·test_app_setup·test_synology_app_connect·test_app_registry·test_finder_folders·test_app_manifests·test_finder_manifest_updates다. 기존 29개 기준은 13차에서 재확인한 baseline66-failures.log를 재사용했다. 전체 실패 기준·skip을 바꾸지 않았다. 기존 pytest 시험 파일은 허용한 한 단언 외에 바꾸지 않았다.

### 실행본·시험 설치·정책 보정

실행본과 HD의 app_manifests 본문이 변경 전 같음을 확인한 뒤, 실행본 사본의 그 함수만 HD 함수로 바꿨다. 함수 밖 다른 작업의 기존 코드는 바이트 그대로 보존했다. 완성 파일을 임시 형제 파일·fsync·이름 바꾸기로 설치했다. 운영 main을 cherry-pick하거나 실행본을 오래된 HD 전체 파일로 덮지 않았다(`E17/runtime-preflight.json`, `deploy/config_assembly.py`).

| 항목 | 변경 전 | 변경 후 |
|---|---|---|
| 실행본 config_assembly.py SHA-256 | `f2c64d1d908f26f5954c59d770bf8b9bdba29815e50ef14c35c48260788e7df3` | `5f1bb8da1cf0bc919d1221e68a7bee597848ec7c7ed167affe66bce633beca7c` |
| 직원 D 기본 team-kit 도구 수 | 40 | 42 |
| 직원 D 기본 도구 추가분 | 없음 | 창고 순서대로 cctv_reference, cctv_now |
| 직원 D 플러그인 자리 | 오버레이 | 원래 공용 창고 심링크 |
| 직원 D links.json 항목 | overlay true | overlay false |

교체 직전에도 지정 SHA를 검사했다. 정책은 그 프로필 목록 끝에 **두 줄만 삽입**했다. 파싱한 나머지 내용 동일 및 삽입 두 줄을 제외한 바이트 동일을 확인했다. 연결 제출 뒤 정책 SHA도 그 두 줄 보정 결과와 같다(`E17/deployment.json`, `final-integrity.json`). 정책 변경 전 SHA는 `421dab9abbe10e98f19a594d67734c10ea561d20cafeaa870dd83a43f278161d`, 변경 후 SHA는 `9f2d4faac2d8f9b16eb406cf56144a470836d1e13b8bc6dcb455a8f9e23e1909`다. 실제 도구 차이를 다시 계산한 결과 위 두 개뿐이었다. 처음 보조 preflight가 제시된 도구 이름의 순서까지 고정해 실패한 것은 `runtime-preflight-initial.json`에 보존했고, 실제 창고 순서를 쓰도록 확인 코드를 정정했다. 운영 쓰기는 그 뒤에만 했다.

보관본은 위 `E17/rollback-rxdnlsto`이며 policy.yaml 보관 파일은 0600이다. 코드·정책·기존 시험 복원은 보관 기록의 임시 복사+이름 바꾸기 절차를 따른다. 새로 설치한 자기 시험이 원래 없었다면 그것만 제거한다. 이번에 복원은 하지 않았다. 운영 연결 트랜잭션 복구·만료된 undo는 코드 파일 복원만으로 대체하지 않는다.

실행본 tests에 test_finder_folders.py(검토된 HD 바이트, SHA `6f44156030bbe7934b06e7475dd385cbc399ada33d9ebedee40371338405740f`)와 새 test_finder_manifest_updates.py(SHA `9d4f7639124087e365e2b0f302fe40dbc8fe3dda0396df8702f4bbf6c35e25dc`)를 설치했다. HD 바이트와 같으며 다른 시험은 건드리지 않았다.

### 직원 D 연결 1회 결과와 멈춤

14차와 동일 환경(HERMES_HOME=<HOME>, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1)·동일 선택 항목 id·200초 제한으로 다음 명령을 한 번 제출했다. 표식으로 재실행을 막았다.

```text
<HOME>/bin/hermes-connections app connect --profile <직원 D> --app com.apple.finder --scope <14차와 동일 항목 id> --json
```

종료 **0**, **0.727118초**, stderr 없음, outcome=waiting·reason=RESTART_REQUIRED·committed=true·next.kind=gateway_restart다. enable·values done, restart·permission·check todo다(`E17/operation-started.json`, `operation-result.json`). 재시작 요구가 나와 지시대로 추가 쓰기를 멈췄다. 재시작·resume·undo·재제출은 하지 않았다.

그 뒤에는 멈춤 보고용 읽기 확인만 했다. 플러그인 자리 심링크가 공용 창고를 가리키며, 장부 overlay false·host manifest와 창고 바이트 일치·정책 두 줄 보정 유지가 확인됐다. 저장 폴더 3개·선택 항목 포함·NFC·존재가 유지됐고 전후 목록 지문도 같다. 폴더 안 파일 내용·비밀 파일·undo 원문은 열지 않았다(`E17/final-integrity.json`, `saved-folders-before.json`, `saved-folders-after.json`).

읽기 명령 `<HOME>/bin/hermes-plugin-store --check`는 종료 0이었다(`E17/plugin-store-check.log/json`). 이는 AT-FF-85의 링크/장부/저장 폴더 복구 확인이며, 재시작 뒤 실제 도구 로드나 직원의 파일 읽기 완료 증거는 아니다.

### 미완료·운영 소유 경로·다음 인계

RESTART_REQUIRED 멈춤 조건 때문에 뒤따르는 **./sync와 운영 저장소 commit은 미실행**이다. 따라서 AT-FF-86의 실제 sync 뒤 시험 보존·운영 미커밋 0 목표는 아직 충족하지 않았다. 실행본 시험 설치는 완료했으므로 후속 sync 때 수집할 준비는 됐다. 운영 main은 이 작업 착수 때와 같은 `3ef4105de4e377bd1230464945db09a644be6996`이며 이번 운영 커밋 전체 해시는 해당 없음이다. 다른 세션 변경·삭제는 그대로 남겼다.

계획 담당이 OPS-REPO-RENAME에 알릴 이 작업 소유 목록은 다음과 같다(원본은 실행본, 운영 저장소 경로는 다음 sync의 사본).

- team-kit/lib/hermes_facility/config_assembly.py: app_manifests 함수 변경만. HD 커밋 `5bd1da2be2ea6c8088163757dbcfab6adf0440a0`. 함수 밖 다른 작업의 코드는 보존.
- team-kit/tests/test_finder_folders.py·test_finder_manifest_updates.py: 실행본 설치 완료, HD 바이트 일치.
- owner/policy.yaml: 직원 D app_tool_defaults.team-kit에 위 두 도구만 추가.
- 직원 D plugins/team-kit 링크와 plugin-store/links.json의 해당 항목: 연결 트랜잭션으로 복구, 손 편집 없음.
- 연결 트랜잭션이 갱신한 설정·장부 메타데이터 9경로 목록은 `E17/changed-operating-files.json`에 있다. 미허가 비밀 파일을 직접 수집·검토·커밋하지 않는다.

다음은 재시작 필요에 대한 사장 승인/새 운영 지시 → 허용된 이어 하기 → 저장/링크 재확인 → sync·자기 경로만 커밋·AT-FF-86 확인이다. 같은 파일에 다른 세션 변경이 섞이면 해당 파일을 커밋하지 않고 보고해야 한다. 운영 저장소 미커밋 0을 만들려고 다른 세션 파일을 되돌리거나 커밋하지 않는다. 계획 담당의 d2 알림은 이 대화가 직접 보내지 않았다.

실제 도달 증거 수준은 3(실행본 설치·정책 한 곳 보정·실제 연결 응답)이다. 요구 중 재시작 뒤 도구 사용·실제 파일 읽기와 AT-FF-86은 남아 있다. 제품 구조/수락 기준/기존 다른 시험 변경은 없고, 명시된 목표의 링크 복구를 위해 app_manifests 안에서 YAML 내용이 같은 원래 링크를 선택하는 구현 세부를 더했다. 전체 앱 회귀는 앱 변경이 없어 반복하지 않았다. 재시작·릴리스·실제 메시지·push는 하지 않았다. 자기 보고서만 commit --only한 hejo 커밋과 개인값/공백 검사 결과는 `E17/hejo-commit.log/json`, `report-checks.json` 및 최종 result에 기록한다.


## 18차-TASK-15 마무리 1 (2026-11-22)

**구현자 판단: 동기화·자기 경로 커밋 완료, 전체 미커밋 0 조건은 범위 밖 변경 1개 때문에 미충족.** handoff 18차를 따랐다. 위험도 일반, 실제 도달 증거 수준 3(실행본 수집·실제 Git 변경/커밋 확인)이다. 직원 D 적용용 재시작은 사장 결정대로 d2 예정 재시작에 합치며, 이번에는 재시작·resume·연결 명령을 실행하지 않았다.

착수 hejo HEAD는 `ca28b09bebd9bc5ff9d59b40034b6a0b58d9c828`, 운영 main HEAD는 `3ef4105de4e377bd1230464945db09a644be6996`다. 아래 `E18`은 `.build/finder-folders-evidence/round18-task15`, `P`는 게이트웨이 Python이다.

### 동기화와 경로별 소유 확인

./sync는 실행본을 읽어 운영 저장소 사본을 다시 채우는 방향임을 소스로 확인했다. 커밋/푸시 옵션 없이 `P ./sync`를 실행해 종료 **0**, **1.543680초**, 토큰 경고 없음이었다(`E18/sync.log/json`). 비밀 파일 내용이나 vault diff 값은 열지 않았다.

동기화 후 변경 경로 9개 중 8개가 이 작업이었다. 나머지 직원 기억 사본 1개는 범위 밖이므로 내용 미열람·미수정·미커밋으로 보존했다. 검토 스크립트와 결과는 `E18/review_paths.py`, `path-review.json`, `path-review-result.json`에 있다. vault는 numstat와 메타데이터만 확인했다. 첫 보조 메타데이터 검사에서 st_inode 오타로 종료 1이 난 것은 보존했고 st_ino로 바로잡은 최종 검토는 종료 0이다(`path-review-initial.json`). 제품이나 시험 기대값을 바꾼 것이 아니다.

| 운영 저장소 경로 | 확인한 변경과 소유 근거 |
|---|---|
| `hermes/plugin-store/team-kit/lib/hermes_facility/config_assembly.py` | app_manifests 함수만 HD 5bd1da2의 검토된 함수로 바뀜. 함수 밖 바이트 보존·실행본 일치 |
| `hermes/plugin-store/team-kit/tests/test_finder_folders.py` | 삭제됐던 시험 복원, HD·실행본 바이트 일치 |
| `hermes/plugin-store/team-kit/tests/test_finder_manifest_updates.py` | 17차 허용 단언 및 링크 복구 시험 갱신, HD·실행본 바이트 일치 |
| `hermes/owner/policy.yaml` | 직원 D 기본 team-kit 목록에 cctv_reference·cctv_now 두 개만 추가, 다른 정책 내용 동일. diff 2줄 추가 |
| `hermes/plugin-store/links.json` | 직원 D team-kit 항목만 변경, overlay false·창고 manifest 지문 일치. 다른 항목·상위 필드 동일 |
| `hermes/profiles/<직원 D>/config.yaml` | 같은 선택 Finder 폴더 한 개만 기존 목록 끝에 추가, 나머지 설정 내용 동일. diff 1줄 추가 |
| `hermes/owner/team.yaml` | 직원 D apps에 Finder 한 개만 추가, 나머지 명부 내용 동일. diff 1줄 추가 |
| `hermes/owner/vault.yaml` | 허가된 연결 기록 경로. diff 4줄 추가·삭제 0줄, 원본 메타데이터가 17차 허가된 트랜잭션 직후와 동일. 값·내용은 열지 않음 |

직원 D `plugins/team-kit`은 동기화 뒤 공용 창고 심링크로 돌아왔고 기존 HEAD와 이미 같아 새 diff가 없었다. 따라서 별도 커밋 경로에는 들어가지 않았다. 다른 세션 변경이 섞인 것으로 확인된 자기 파일은 없었다. vault는 지시된 제한 때문에 경로·줄 수·메타데이터로만 소유 근거를 확인했으며 값 검토를 했다고 주장하지 않는다. 정확한 로컬 경로 목록은 비공개 `E18/owned-paths.json`, `operating-commit.json`에 있다.

### 운영 커밋과 남은 변경

자기 8개 경로만 한국어 메시지 "Finder 창고 링크 복구와 두 회귀 시험을 실행본에서 모아 보존"으로 `git commit --only`했다. 운영 커밋 전체 해시는 **`f1507977e7702dd9e0725c5eac605f8eb62f5473`**다. 부모는 착수 운영 main이며, 커밋 경로가 검토한 8개와 정확히 같음을 확인했다(`E18/operating-commit.log/json`). 직원 기억 사본을 스테이징하거나 포함하지 않았다.

| 명령/확인 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| `P ./sync` | 0 | 경고 없음, 두 시험 수집 | `E18/sync.log/json` |
| 비밀 아닌 자기 경로 `git diff --check` | 0 | 공백 오류 없음, vault 내용 검사 제외 | `E18/own-diff-check.log/json` |
| 자기 8경로 `git commit --only` | 0 | 위 운영 커밋, 경로 일치 | `E18/operating-commit.log/json` |
| 자기 경로 `git diff --quiet HEAD -- ...` | 0 | 작업 변경 남지 않음 | `E18/final-integrity.json` |
| `git diff --cached --quiet` | 0 | 스테이징 변경 없음 | `E18/final-integrity.json` |
| 전체 `git status --porcelain` | 0 (명령 성공) | **미커밋 1개**, 범위 밖 직원 기억 사본 | `E18/after-commit-status.log`, `final-integrity.json` |

두 시험은 삭제(D)나 미추적 상태가 아니며 실제 운영 커밋에 들어 있다. 저장소 파일·커밋 blob·실행본의 SHA가 모두 같다. Finder 시험 SHA `6f44156030bbe7934b06e7475dd385cbc399ada33d9ebedee40371338405740f`, manifest 시험 SHA `9d4f7639124087e365e2b0f302fe40dbc8fe3dda0396df8702f4bbf6c35e25dc`다. 따라서 AT-FF-86의 시험 보존 부분은 확인했다.

전체 미커밋 0은 달성하지 못했다. 남은 것은 이 작업 밖 직원 기억 사본 1개뿐이다. 이를 0으로 만들려고 다른 세션/직원의 파일을 되돌리거나 커밋하지 않았다. 실행본 config_assembly.py는 운영 main과 같은 SHA `5f1bb8da1cf0bc919d1221e68a7bee597848ec7c7ed167affe66bce633beca7c`이고 제품 바이트를 새로 고치지 않았다. 따라서 17차의 관련 114 passed·전체 새 실패 0·airport 통과 증거를 재사용하고 같은 전체 시험을 반복하지 않았다.

### 인계와 미실행

계획 담당은 d2에 운영 커밋 `f1507977e7702dd9e0725c5eac605f8eb62f5473`와 자기 8경로 수집 완료·범위 밖 기억 사본 1개 남음을 알려야 한다. 남은 기억 사본의 처리 주체를 결정한 뒤 d2의 재시작·폴더 이동/repair 순서를 진행해야 한다. 이 대화는 다른 세션에 직접 메시지를 보내지 않았다.

운영 소유 범위는 위 표 8개와 이미 HEAD와 같은 직원 D 플러그인 링크다. 범위 밖 변경의 정확한 로컬 경로는 `E18/after-commit-status.log`에만 남겼으며 기억 내용은 열지 않았다. 새 재시작·resume·연결 재제출은 0회다. d2 재시작 완료 뒤 다음 지시에서 기존 완료 증거를 확인하고 permission·check만 이어가야 한다. 기존 공개·사장 확인·푸시 승인은 별도다.

이번 hejo 보고서 한 경로만 commit --only하며 전체 해시는 `E18/hejo-commit.log/json`과 최종 result에 기록한다. 보고서 개인값 검사·공백 검사 결과는 `E18/report-checks.json`에 있다. push·릴리스·실제 메시지·본체/ddots·수락 기준/설계 변경은 하지 않았다.


## 19차-TASK-15 마무리 2 (2026-11-22)

**구현자 판단: 이어 하기·연결 완료 확인, 공용 확인 기록 추가 갱신을 명시해 검토 대기.** handoff 19차를 따랐다. 위험도 일반, 필요한 증거 수준과 실제 도달 수준은 3이다. 사장 결정대로 d2의 재시작 증거를 재사용했으며 이번에는 재시작하지 않았다.

착수 hejo HEAD는 `9cb1406a2d54336c94ee76cf9b5817c086b101f5`다. 이하 `E19`는 `.build/finder-folders-evidence/round19-task15`다. 제품 코드·수락 기준·시험 변경은 없다. 운영 저장소의 sync·커밋도 하지 않았다.

### 읽기 preflight

직원 D Finder 기록의 첫 at 필드만 읽었다(첫 40바이트, undo 원문 미열람). 적용 시각은 `2026-11-22T19:14:32.133302+09:00`다. gateway.pid는 kind=hermes-gateway·PID **18074**였고, ps 프로세스 시작은 **19:35:23**으로 적용 시각보다 뒤였다. 인계서의 19:35:53은 프로세스 시작 시각이 아니라 gateway.log **7298줄**의 Starting Hermes Gateway 표시(`19:35:53,995`)다. 두 시각을 구분했다.

게이트웨이 Python으로 `gateway_restart.completed_since(root, 적용 시각)`을 실제 읽기 호출한 결과 **True**였다. PID·로그·완료 증거를 바꾸지 않았으며, False일 때 실행을 막도록 했다(`E19/preflight.py`, `preflight.json`).

### 이어 하기 1회와 결과

다음 명령을 17차와 같은 환경 HERMES_HOME=<HOME>, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1 및 200초 제한으로 **한 번** 실행했다. 실행 직전 PID 18074와 preflight True를 다시 확인하고, 제출 표식이 있으면 재실행하지 못하도록 했다.

```text
<HOME>/bin/hermes-connections app connect --profile <직원 D> --app com.apple.finder --resume gateway_restart --json
```

종료 코드 **0**, **1.051206초**, timeout 없음, stderr 없음, outcome=**done**·reason=**OK**·next.kind=done이다. enable·values·restart·permission·check 모두 done이었다. 명령 전후와 읽기 검증 시점 모두 PID **18074**로 같아 새 재시작은 발생하지 않았다(`E19/operation-started.json`, `operation-result.json`, `gateway-before.json`, `gateway-after.json`).

### 변경된 운영 파일 — 두 기록 파일

운영 설정·장부·플러그인 host·연결 상태 경로의 전후 lstat를 비교했다. 관측된 변경은 다음 **2개**다.

1. 직원 D의 `state/connections/` Finder 진행 기록: 이어 하기 단계 완료를 저장했다.
2. 공용 `state/connections/checks.json`: 최종 앱 확인 결과를 저장했다.

예상한 Finder 진행 기록 하나 외에 공용 확인 기록도 갱신됐으므로 이를 추가 변화로 보고한다. 실행본 app_setup.Adapters.check의 local_files 갈래는 저장 폴더의 is_dir·디렉터리 접근을 확인한 뒤 `checks.save_check(... state=connected, reason=APP_VERIFIED ...)`를 호출한다. connection_checks.save_check가 이 공용 checks.json을 쓰는 기존 경로다. 이번에 코드를 고치거나 수동으로 기록을 쓴 것이 아니다. 공용 기록의 직원 D Finder 항목도 state=connected·reason=APP_VERIFIED·verified_by=app_read임을 읽기로 확인했다(`E19/shared-check-record.json`).

그 밖에 관측 대상으로 둔 owner/policy.yaml·team.yaml·vault.yaml, plugin-store/links.json, 프로필 config/profile/env 메타데이터, 플러그인 host/manifest 등은 변하지 않았다. 비밀 값이나 비밀 파일 내용은 열지 않았다. 전체 파일 시스템 무변경이라고 주장하는 것이 아니라 정해진 연결 트랜잭션 경로를 비교한 결과다(`E19/operating-before-metadata.json`, `operating-after-metadata.json`, `changed-operating-files.json`, `final-integrity.json`). 이상을 감추거나 추가 제출로 덮지 않았다.

### done 이후 읽기 확인

- 저장 폴더 3개, 기존 선택 항목 포함, 모두 NFC·존재. 17차 저장 목록 지문과 같음(`E19/saved-folders-after.json`, `folder-comparison.json`). 파일 내용은 열지 않았다.
- 직원 D 플러그인 자리는 공용 창고 심링크이며 links.json 항목은 overlay false다. host manifest 바이트도 창고와 같다(`E19/final-integrity.json`).
- `<HOME>/bin/hermes-plugin-store --check`: 종료 **0**(`E19/plugin-store-check.log/json`).
- 실행본 config_assembly.py SHA는 `5f1bb8da1cf0bc919d1221e68a7bee597848ec7c7ed167affe66bce633beca7c` 그대로다.

| 명령/확인 | 종료 코드 | 실제 결과 | 로그 |
|---|---:|---|---|
| 게이트웨이 Python preflight | 0 | 적용 시각 < PID 시작, completed_since True | `E19/preflight.json` |
| 위 app connect --resume gateway_restart | 0 | done/OK, 모든 단계 done, PID 18074 유지 | `E19/operation-result.json` |
| 저장 폴더 읽기 확인 | 0 | 3개·이전 목록 유지·NFC·존재 | `E19/saved-folders-after.json`, `folder-comparison.json` |
| hermes-plugin-store --check | 0 | 창고 연결 검사 통과 | `E19/plugin-store-check.log/json` |
| PID·심링크·장부·변경 경로 확인 | 0 | 공용 확인 기록 포함 두 기록만 변화 | `E19/final-integrity.json` |

### 인계

실제 계산 환경에서 새 재시작 없이 기존 완료 증거로 permission·check를 끝낸 수준 3 증거다. 직원 D의 실제 파일 읽기는 사장 M6로 남아 있다. 제품 바이트 변화가 없어 같은 전체 시험은 반복하지 않았다. 추가 재시작·resume 재시도·연결 재제출·sync·운영 커밋·실제 메시지·릴리스·push는 하지 않았다.

관측한 운영 저장소 HEAD는 `e5d13980d1d65be9be2392db0c964f20f42a015f`이며 상태 경로 1개다. 이는 다른 세션이 관리한 상태를 읽은 것이고 이번 작업에서 운영 커밋을 만든 것은 아니다. 계획 담당이 이 결과와 공용 checks.json 갱신을 검토한 뒤 d2에 마무리 완료를 알려야 한다. d2가 폴더 이동·worktree repair를 마치면 다음 작업 전에 AGENTS.local.md의 운영 저장소 경로를 확인/갱신해야 한다. 이 대화는 직접 다른 세션 메시지를 보내거나 저장소 폴더를 옮기지 않았다.

자기 hejo impl-report 한 경로만 commit --only한다. 개인값·공백 검사와 보고 커밋 전체 해시는 `E19/report-checks.json`, `hejo-commit.log/json` 및 최종 result에 기록한다. 기존 공개·사장 확인·마지막 M7·푸시 승인은 별도다.


## 20차-TASK-08 — 0.2.4·빌드 6 공개 후보 준비

### 받은 지시·판단·범위

[확인] handoff 20차, HEJO-CONNECTIONS 보완 지시 3·HEJO-CONN-MANAGE 8차 선례를 따랐다. 고위험(공개 배포물), 필요/도달 증거 수준 **2/2**. 구현자 판단은 **후보 준비·자체 검증 완료, 독립 검토·실제 공개·설치 확인 대기**다. 직접 수행했으며 하위 에이전트를 쓰지 않았다.

- 착수 main: `4af8c11d8b71d46e6b363cd84963e3135180cc06`. 버전 커밋: `7c9aae9a094d5658eab488812b2492bee9b60b34`. 자기 경로 `app/Resources/Info.plist`의 버전·빌드와 `tests/acceptance/test_ship.py`의 현재 버전 단언만 0.2.4·6으로 올려 `git commit --only`했다. 제품 동작 코드·기존 시험의 기능 기대값·수락 명세·spec·design은 변경하지 않았다.
- 공개본 생성은 기존 `install/hejo-publish`를 사용했다. 선례의 로컬 gh 대역이 이전 public 커밋의 작성자 정보로 두 조회에 응답했다(`offline-gh.jsonl`: 두 건 모두 `network:false`). 실제 gh·원격 Git·curl/wget은 차단했고 Sparkle는 기존 고정 지문 SDK를 오프라인으로 사용했다. 차단된 원격 시도도 없으며 GitHub 조회·쓰기·publish·push는 미실행이다.
- 다른 작업의 미추적 문서 폴더를 보존하기 위해 `E20/public-worktree`에 깨끗한 분리 checkout을 만들었다. 원래 저장소에서 해당 폴더를 지우거나 커밋하지 않았다. 정상 배포 빌드만 무시된 Google 입력을 기존 빌드 경로로 사용했다(작업 사본에 입력 파일을 가리키는 무시된 링크). 값 직접 열람·출력·기록·수동 복사는 하지 않았다. 키 생성·setup·비밀 키 내보내기도 하지 않았다.

### 공개본·준비물·연속성

- 새 public: **`eb5e62afd8ad6205e40d79386e34641d077ab898`**, 부모: `f397bdb7bedfc766c2116ecdd07118cb3afdfc32`(0.2.3). 동일 제품 트리: `c4d9b98bf57c030d272222313942ab93c8eadcc2`. 부모 이후 커밋은 새 public 하나이며 개인 개발 이력은 포함하지 않는다.
- 원본 main은 `b21dd94`·`3ccda92`·`3e9400b`·`b3fc5cb`·`2fffbe0`·`5fc60b2`·`da3cf0b`·`52e2511`·`f03b93a`의 조상 검사를 모두 통과했다. public 전체 트리 및 `app/`은 버전 커밋의 main과 같다. `ConnectionsWindow.swift`에 `sharingType`이 없고 `OptionWindows.swift`·`LetterPictureDialog.swift`가 있다(`snapshot.json`, `ancestor-*.json`).
- 인계서의 “public 트리가 앱 커밋을 조상으로 포함”은 선례처럼 **원본 main 조상 관계 + public 트리 일치**로 확인했다. public 커밋 자체에 개인 커밋 조상을 넣으면 공개 이력 분리 조건을 위반하므로 그렇게 만들지 않았다. 보고서만 추가하는 후속 main 커밋은 이 고정 후보 트리에 포함하지 않으며 public을 재생성하지 않는다.
- 준비물: `.build/release-0.2.4/prepared.json`, `.build/release-0.2.4/hejo-0.2.4-arm64.zip`(**6,390,405 bytes**), 압축 SHA-256 `a123bb0f85dbfe9ddbc6684b654c89fc3b9af22093fabdb6172baad200ac56b1`.
- 배포용 앱·압축 해제본 BuildInfo는 위 트리·`dirty=false`, 실행 파일 바이트가 같다. 후보 0.2.4·6은 설치본 0.2.3·5보다 각각 크다. 후보·0.2.3 준비물·설치본의 업데이트 공개 키와 설치본의 코드 서명 Authority가 같다. 기존 키체인 키를 재사용했다. 압축 해제본 codesign, Sparkle 검증과 별도 Ed25519 공개 키 검증이 모두 통과했다.
- 설치 앱 메타데이터, 게이트웨이 PID/시작 식별자, 공용 릴리스 식별자, 운영 저장소 HEAD/상태는 착수와 같다(`before.json`, `final-integrity.json`). 설치 앱 교체·공용 릴리스 변경·운영 홈 변경·문 설치·재시작·실제 메시지는 미실행이다.

### 검증·환경 오류 처분

아래 증거 `E20`은 `.build/finder-folders-evidence/round20-task08/`다. 검사 대상은 위 새 public과 동일 트리의 깨끗한 공개 checkout이다. 전체 시험 전 `pgrep -f app-tests` 종료 1(다른 실행 없음), 다른 GUI 빌드 없음. 시험 중 추적 소스 변경 0이며 시험 바이트를 public blob과 직접 대조했다(`tested-sources.json`, `final-integrity.json`).

| 명령·조건 | 실제 종료 코드·결과 | E20 증거 |
| --- | --- | --- |
| `git commit --only` 버전 두 경로, 자기 경로 `git diff --check` | 각각 0 | `version-commit.log/json`, `version-diff-check.log/json` |
| `install/hejo-publish`(로컬 작성자 대역), 공개본 개인값 검사 | 각각 0 | `publish-local.log/json`, `public-private.log/json`, `snapshot.json` |
| 첫 `HEJO_PYTHON=<게이트웨이 Python> bash scripts/test.sh` | **1**, 229 passed·205 setup errors, 앱 단계 미실행 | `full.log/json` |
| 같은 실패 node의 실제 예외 관측, 짧은 임시 경로 대조 | **1**(AF_UNIX path too long, 148바이트), **0**(1 passed) | `fixture-path-diagnosis.log/json`, `fixture-short-path.log/json` |
| 같은 전체 명령, 짧은 `TMPDIR`·`PYTEST_ADDOPTS=--basetemp=<임시 경로>`, 임시 `HERMES_HOME`·`HERMES_ROOT` | **0**, 434 passed·게이트웨이 정상 종료·앱 전체 및 통신 시험 통과, 404.074초 | `full-short-tmp.log/json` |
| CLI 설정 메타데이터·다운로드 이름 전후 guard | 모두 0, 내용 미조회·불변 | `settings-*-short-tmp.log/json`, `downloads-*-short-tmp.log/json` |
| 같은 깨끗한 트리 `bash app/scripts/build.sh`(기본 배포 빌드) | 0 | `default-build.log/json` |
| `install/hejo-ship prepare --output <준비물 폴더>` | 0 | `prepare.log/json`, `prepared-verification.json` |
| `ditto -x -k`, 해제본 `codesign --verify --deep --strict` | 각각 0 | `extract.log/json`, `archive-codesign.log/json` |
| 기존 계정 `sign_update --verify <archive> <prepared signature>`, 별도 `cryptography` Ed25519 공개 키 검증 | 각각 0 | `archive-sparkle.log/json`, `independent-signature.json` |
| main·public 최종 개인값 검사, 자기 경로 `git diff --check` | 모두 0 | `main-private-final.log/json`, `public-private-final.log/json`, `report-private.log/json`, `report-diff-check.log/json` |

첫 실패는 새 Unix 입구가 macOS 기본 긴 시험 임시 경로에서 소켓을 열지 못한 환경 조건이었다. 관측과 대조 뒤 실행 임시 경로만 줄였으며 제품·시험 기대값·오류 처리·기준을 바꾸거나 skip하지 않았다. 기존 Swift 동시성 경고 등 빌드 경고는 남아 있으며 이번 버전 올림에서 새로 수정하지 않았다. 개인값 검사는 비밀 파일을 입력하지 않는 임시 홈으로 실행했다.

전체 로그의 실제 PASS 줄(일부 묶음 시험은 개별 번호를 따로 출력하지 않으므로 해당 기존 묶음 줄을 인용):

```text
AT-FF-20~23 APP PASS
AT-FF-70 CONNECTION SHARING PASS; AT-FF-71 regression in full suite
AT-FF-50..54 LETTER PICTURE PASS
AT-FF-64 OPTION ACTIVATION PASS
AT-FF-60..61 OPTION WINDOW PASS; AT-FF-63 regression in full suite
AT-FF-AC04 UPDATE_CONTENT_EQUIVALENCE PASS
AT-FF-FIRST-FRAME AND SIDEBAR_GEOMETRY PASS
AT-HF-86 APP PASS
AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS
APP_TEST_OK
AT-FF-40 dark PIXEL PASS alpha=1.0
AT-FF-40 light PIXEL PASS alpha=1.0
AT-FF-41 dark PIXEL PASS alpha=1.0
AT-FF-41 light PIXEL PASS alpha=1.0
```

AT-FF-32는 위 ThreeTap·펫/첫 프레임·내용 동일성과 앱 전체 시험, AT-FF-42는 AT-TD-20..42와 전체 시험, AT-FF-63·71은 기존 묶음과 전체 회귀에 대응한다. AT-FF-62는 9차 보고의 적용 분류와 이번 후보 검색 `options-inventory.log/json`으로 대조할 수 있다. **AT-FF-30·31의 성능 PASS를 만들거나 주장하지 않는다.** 7차 기록의 마지막 주입 측정은 열기 101.340ms·닫기 94.633ms로 열기 기준 미충족이다. 이번 후보에서 추가 성능 수정·재측정은 하지 않았고, 마지막 실제 탭 M7 수용 판단은 사장에게 남아 있다.

### 서버 문과의 차이·인계

공용 릴리스의 현재 문과 후보를 내용으로 비교했다. 실행 코드와 `schemas/` 차이는 0이다. 문서는 `gate/README.md` 하나가 다르고, 아래 `gate/tests/` 20개는 서버 릴리스에서 의도적으로 제외되는 후보 시험 파일이다(`server-gate-diff.json`). 파일 목록만 기록한다.

```text
gate/README.md
gate/tests/conftest.py
gate/tests/extension_support.py
gate/tests/gateway_delivery.py
gate/tests/imessage_settling.py
gate/tests/support.py
gate/tests/test_answer_targets.py
gate/tests/test_boundaries.py
gate/tests/test_connections.py
gate/tests/test_delivery_parity.py
gate/tests/test_employee_query.py
gate/tests/test_extensions.py
gate/tests/test_gateway_progress.py
gate/tests/test_owner_query.py
gate/tests/test_pictures.py
gate/tests/test_progress.py
gate/tests/test_report_query.py
gate/tests/test_review55.py
gate/tests/test_review56.py
gate/tests/test_rooms.py
gate/tests/test_threads.py
```

사장용 공개 명령(독립 검토·플러그인 푸시 승인 및 실행 뒤 사장이 직접 실행; **이번에는 실행하지 않음**):

```sh
install/hejo-ship publish --approve-commit eb5e62afd8ad6205e40d79386e34641d077ab898 --prepared .build/release-0.2.4/prepared.json
```

푸시 대상은 **hejo 저장소의 로컬 public `eb5e62afd8ad6205e40d79386e34641d077ab898` → `github/main`**이다. 개인 main 이력·이 보고서 커밋을 공개 원격으로 보내지 않는다. 원격 포함은 조회 금지 범위이므로 확인하지 않았다. 실제 공개·업데이트 설치(수준 4), 문 서버 설치·재시작은 별도 사용자 승인, M4·M8~M11 및 맨 마지막 M7, 최종 명세 반영·푸시 완료 판정이 남아 있다. 독립 검토자는 고정 후보 트리/준비물 지문, 서명 연속성, 초기 환경 오류 대조, 남은 AT-FF-31을 확인한다. 배포 전 실패 시 공개하지 않고 준비물을 보존한다. 운영 롤백은 이번에 운영 변경이 없어 해당하지 않는다.


## 21차-TASK-16 — 처리할 일 칸 바깥 배치: 기존 시험 충돌로 보류

### 받은 지시·현재 상태

[확인] handoff 21차·spec 13판 REQ-FF-13·design 10절·AT-FF-90~93과 실제 코드를 대조했다. 착수 main은 `913ad22eb2f0bcbf0d8829a65871e44fea917c2c`이다. 0.2.4 공개와 M1~M11 통과는 최신 verdict의 기록을 확인했으며 반복하지 않았다. 위험도 일반, 필요 증거 수준 2. 이번 범위의 구현자 판단은 **보류(멈춤 조건 해당)**다. 제품·시험·운영 변경은 0이며 보고서만 추가했다. 다른 작업의 미추적 문서 폴더는 보존했다.

21차 지시와 이번 실행 요청의 **“기존 기대값 변경 필요하면 멈추고 보고”** 조건에 따라, 아래 충돌을 발견한 시점에 제품 수정을 시작하지 않았다. 수락 기준이나 기존 시험을 임의로 바꾸지 않았다.

### 직접 확인한 충돌

| 실제 기존 시험 | 현재 요구 | REQ-FF-13 규칙을 적용하면 |
| --- | --- | --- |
| `app/Tests/TodoDrawerTests.swift:95` AT-TD-33 | 1440폭 화면, 펫 x=200에서 `drawerOverlay=true`, 패널 프레임 불변, scrim 표시 | 오른쪽 여유가 충분하므로 203만큼 이동해 바깥 칸, overlay=false여야 함 |
| `app/Tests/TodoDrawerTests.swift:116` AT-TD-35 | 왼쪽으로 끈 뒤 overlay=true | 같은 넓은 화면에서 오른쪽 이동으로 칸을 넣을 수 있어 기존 겹침 기대와 충돌 |
| `app/Tests/TodoDrawerTests.swift:118` AT-TD-35 | 접고 다시 열어도 overlay=true | 다시 열 때도 바깥 배치를 재계산하므로 기존 겹침 기대와 충돌 |
| `app/Tests/TodoDrawerBackgroundTests.swift:45~50` AT-FF-40 fixture | 1440폭 화면, 펫 x=100으로 overlay=true 사례를 만들고 이를 단언 | 오른쪽 여유가 충분하므로 290만큼 이동해 overlay=false, 픽셀 검사 전 fixture 단언부터 실패하게 됨 |

현재 `PetLayout.swift`를 그대로 컴파일한 별도 기하 진단에서 실제 `withLeading` 반환값과 지시된 shift 수식을 대조했다. 대화 크기는 실제 기본값 428×500(360+사이드바 68), 칸 290, 화면 1440×900인 가짜 입력이다. AT-TD-33과 배경 시험 사례 모두 현재 overlay=true였고, 새 수식의 이동 후 대화 오른쪽 끝은 730으로 화면 제한 1428 안에 들어간다. 따라서 새 규칙은 두 사례 모두 overlay=false를 요구한다. 진단은 제품 구현이나 전체 AppKit 시험이 아니며, 새 수락 시험 통과로 세지 않는다.

`PetController.placePet`는 leading을 `PetPlacement` 생성자에 전달하고 그 target으로 패널을 배치한다. `moveChatDrag` 역시 `withLeading`을 직접 사용한다. 칸 열기/닫기의 `setDrawerOpen`은 target.anchorOrigin을 다음 배치에 사용한다. 저장 기준 보존은 구현 재개 뒤 실제 컨트롤러 시험으로 확인해야 하며 이번에는 수정하지 않았다.

### 검증·미실행

증거 `E21` = `.build/finder-folders-evidence/round21-task16/`.

| 명령·확인 | 실제 결과 | 증거 |
| --- | --- | --- |
| `xcrun swiftc -swift-version 5 -parse-as-library app/Sources/PetLayout.swift <로컬 기하 진단> -o <진단 실행 파일>` | 종료 0, 현재 제품 코드 그대로 컴파일 | `geometry-build.log/json` |
| 위 진단 실행 파일 | 종료 0, 현재 반환값과 새 규칙의 상반된 요구 확인 | `geometry-conflict.log/json` |
| 착수 이후 제품 파일 SHA-256 대조·`git diff` | 제품 변경 0 | `start.json`, `source-integrity.json` |
| 보고서 개인값 검사·`git diff --check` | 최종 실제 결과는 `report-checks.json` | `report-private.log`, `report-diff-check.log` |

[미실행] AT-FF-90~93 앱 시험 작성·전체 앱 시험·app-tests 실행 전 pgrep. 기존 기대값 변경을 허가받지 못한 상태에서 멈추었으므로 실행하거나 통과로 표시하지 않는다. 새 제품 구현 및 대역 통합 수준 2 증거도 아직 없다. 앱 버전·공개 후보·설치 앱·운영 홈·게이트웨이·본체·다른 앱·원격은 변경하지 않았다. 푸시도 하지 않았다.

### 계획 담당에게 필요한 결정

[제안] AT-TD-33·35의 위 단언만 새 오른쪽 이동/바깥 배치·닫기 복원 계약에 맞게 바꾸도록 허가하고, AT-FF-40은 실제로 공간이 부족한 좁은 가짜 화면에서 overlay fixture를 만들도록 허가한다. 픽셀·불투명도·테마 단언은 그대로 유지하고, 다른 시험 기대값은 바꾸지 않는다. 이는 제안이며 아직 적용하지 않았다. 계획 담당이 해당 허용 범위와 수락 명세의 “기존 기대값 수정 없음” 예외를 확정해 새 인계로 주면 TASK-16 구현과 AT-FF-90~93·전체 앱 회귀를 재개한다. 이번 제품 커밋은 없고 보고서 커밋 전체 해시는 result에 기록한다.


## 22차-TASK-16 — 처리할 일 칸 바깥 배치

### 인계·구현 상태

[확인] handoff 22차(21차 2~6항 포함), design 10·10.1, REQ-FF-13, AT-FF-90~93을 따랐다. 착수 main `d0cabc7b5d10077ef4d7d726f3036715ff5b2f51`, 코드 커밋 **`3695d5e195144857700daf67bdfe1c17628797fd`**. 위험도 일반, 필요/도달 증거 수준 **2/2**. 구현자 판단은 구현·자체 시험 완료, 독립 검토와 0.2.5 설치 후 M12 대기다. 직접 수행했고 하위 에이전트는 쓰지 않았다.

- 자리 결정은 `PetPlacement.withLeading` 하나에 유지했다. 원래 들어가는 경우는 그대로, 왼쪽 자리가 부족하면 지시된 shift만큼 sprite·bubble을 함께 오른쪽으로 옮기고 leading=290으로 바깥 칸을 붙인다. 옮긴 대화 오른쪽 끝도 여백 12를 넘으면 기존 겹침을 유지한다.
- `PetPlacement` 내부의 표시 전용 `drawerShift`를 `anchorOrigin`에서 빼서 저장 기준을 유지한다. Codable·LocalSettings·새 설정 키는 없다. `PetController`의 `setDrawerOpen`, `placePet`, `moveChatDrag`, `endPetDrag`는 target/anchorOrigin을 그대로 사용하므로 수정하지 않았다.
- 새 `app/Tests/DrawerOutsidePlacementTests.swift`를 `TestMain.swift`에 등록했다. 0·음수 화면 원점, 오른쪽 여백의 정확한 경계 및 바로 부족한 경우, 기존에 들어가는 배치, 실제 PetController의 바깥 칸·저장 좌표·세 번 열고 닫기 복원을 확인한다. 기존 픽셀 검사는 실제 PetView에서 좁은 화면 겹침·넓은 화면 바깥 배치의 두 테마 모두를 그대로 검사한다.
- 바깥 칸을 추가하면 패널 폭도 290 늘어난다. 따라서 패널 오른쪽 끝은 shift만큼, 왼쪽 원점은 shift−290만큼 바뀌며, 실제 펫과 대화 영역은 모두 shift만큼 오른쪽으로 옮겨진다. 시험은 이 좌표 관계와 대화 크기 불변, 칸 바깥 배치 및 닫기 복원을 직접 확인한다.
- 바꾼 파일은 위 제품 1파일, 기존 시험 3파일 및 새 시험 1파일뿐이다. 기존 기능 경로를 대체하거나 새 설정·공개 계약을 만들지 않았다. 설계의 허용 범위 밖 기대값 변경은 없다. 버전·공개 후보·설치 앱·운영·본체·다른 앱·원격 변경은 하지 않았다.

### 허가된 기존 단언 전후

기준 줄 번호는 착수 HEAD 기준이다. 기존 시험의 다른 단언과 AT-TD-35 접기 단언(117줄)은 유지했다(`scope-check.json`).

| 자리 | 전 | 후 |
| --- | --- | --- |
| `TodoDrawerTests.swift:95` AT-TD-33 | 왼쪽 공간 부족 시 overlay=true·패널 프레임 불변·scrim 표시 | 같은 배치에서 overlay=false·펫/대화 오른쪽 shift·오른쪽 패널 경계 shift·칸 바깥·scrim 숨김. 닫기 뒤 원래 프레임 단언 추가 |
| `TodoDrawerTests.swift:116` AT-TD-35 | 왼쪽으로 끌면 overlay=true | 끌면 leading=290·overlay=false·대화 왼쪽은 화면 여백+칸 너비, 표시 sprite가 저장 anchor보다 오른쪽 |
| `TodoDrawerTests.swift:118` AT-TD-35 | 다시 열 때 overlay=true | 다시 열 때 leading=290·overlay=false 및 실제 칸 표시 |
| `TodoDrawerBackgroundTests.swift:48~50` AT-FF-40 고정물 | 화면 1440폭에서 펫 x=100으로 겹침 유도 | 겹침 쪽만 가짜 화면 폭 700(428+290+24보다 작음). 배치 단언·픽셀 알파/테마/아래 색 차단 기대값은 불변 |

### 실행·증거

증거 `E22` = `.build/finder-folders-evidence/round22-task16/`. 전체 시험 대상은 코드 커밋의 다섯 파일과 같은 바이트이며 시험 중 소스 변경 0, 커밋 blob 대조 일치(`tested-sources.json`, `code-commit.json`).

| 명령·확인 | 실제 결과 | E22 증거 |
| --- | --- | --- |
| `pgrep -f app-tests` 및 다른 GUI 빌드 조사 | 종료 1(다른 실행 없음), 빌드 겹침 없음 | `app-pgrep.log/json`, `gui-builds.json` |
| `HEJO_PYTHON=<게이트웨이 Python> bash app/scripts/test.sh` | **종료 0**, 앱 전체·통신 fixture·기존 ThreeTap/펫 끌기·HEJO-TODO-DRAWER·AT-FF-40~42·새 AT-FF-90~93 통과, 330.741초 | `app-full.log/json` |
| 기존 접기 단언·픽셀 기대값·PetController·버전 보존 대조 | 통과 | `scope-check.json` |
| 게이트웨이 Python 개인값 검사·자기 경로 `git diff --check` | 각각 종료 0 | `code-private.log`, `code-diff-check.log`, `code-checks.json` |
| 다섯 자기 경로만 `git commit --only` | 종료 0 | `code-commit.log/json` |

시험은 기존 0.2.4에서 확인한 Unix 소켓 경로 길이 문제를 피하도록 처음부터 짧은 임시 TMPDIR 및 resolve한 HERMES_HOME/HERMES_ROOT로 실행했다. 이번에 소켓 길이 오류나 실패 실행은 없었고, 같은 시험을 불필요하게 반복하지 않았다. CLI 설정 메타데이터·다운로드 이름 보존 guard도 전체 시험 안에서 통과했다. 기존 Swift 동시성 등 경고는 남아 있으며 이번 소스 변경에서 범위 밖 수정을 하지 않았다.

실제 로그 줄:

```text
AT-FF-90/92/93 PLACEMENT BOUNDARIES PASS
AT-FF-91 NATIVE OUTSIDE AND RESTORE PASS; AT-FF-93 regression in full suite
AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS
AT-HF-86 APP PASS
AT-FF-FIRST-FRAME AND SIDEBAR_GEOMETRY PASS
AT-FF-40 dark PIXEL PASS alpha=1.0
AT-FF-40 light PIXEL PASS alpha=1.0
AT-FF-41 dark PIXEL PASS alpha=1.0
AT-FF-41 light PIXEL PASS alpha=1.0
```

별도 mutation 빌드는 생략했다. 경계 양쪽과 음수 화면 좌표, 표시/저장 좌표 차이, 실제 컨트롤러·디스크 재조회·반복 복원, 기존 끌기·애니메이션·픽셀 회귀로 이번 일반 위험 변경의 주요 실패를 직접 검사했다. 새 수락 기준·기존 기대값 완화·skip·추가 성능 수정은 없다.

### 남은 일

독립 검토자는 shift/오른쪽 여백 비교, 저장 anchor와 표시 sprite의 분리, 허가된 단언 전후 표와 실제 커밋 diff를 확인한다. TASK-17(0.2.5·빌드 7 공개 후보)은 별도 지시이며 아직 수행하지 않았다. 사용자 M12와 현재 명세 반영, 푸시 승인은 남아 있다. 다른 작업의 미추적 문서 폴더는 보존했다. 보고서만의 후속 커밋은 제품 변경을 포함하지 않으며 전체 해시는 result에 기록한다.


## 23차-TASK-17 — 0.2.5·빌드 7 공개 후보 준비

### 인계·구현자 판단

[확인] handoff 23차 및 20차 공개 후보 선례를 따랐다. 착수 main `031a14fe2a638a51c73f29c70af380106dc649fe`. 고위험(공개 배포물), 필요/도달 증거 수준 **2/2**. 구현자 판단은 **후보 준비·자체 검증 완료, 독립 검토·실제 공개·사용자 M12 대기**다. 직접 수행했으며 하위 에이전트를 쓰지 않았다.

- 버전 커밋 **`666726c5098deb3cc13e870ed6a36056ddf127ce`**: `app/Resources/Info.plist`를 0.2.5·7로, `tests/acceptance/test_ship.py`의 현재 버전 단언 한 줄을 같은 값으로 올려 두 경로만 `git commit --only`했다. 다른 현재 버전 고정 문서는 없으며 과거 이력은 고치지 않았다. 제품 동작 코드·기능 기대값·spec·design·수락 명세는 불변이다.
- 기존 `install/hejo-publish`를 사용했다. 선례의 로컬 gh 대역이 이전 public 작성자 정보로 두 조회에 응답했다(`offline-gh.jsonl`, 모두 `network:false`). 원격 Git·실제 gh·curl/wget은 차단하고 고정 지문의 기존 Sparkle SDK를 오프라인으로 사용했다. GitHub 조회·쓰기·publish·push는 하지 않았고 차단된 원격 시도도 없다.
- 다른 작업의 미추적 문서 폴더를 보존하기 위해 `E23/public-worktree`에 깨끗한 분리 checkout을 만들었다. 기본 배포 빌드만 무시된 Google 입력을 기존 경로로 사용했다(무시된 로컬 링크). 비밀 값 직접 열람·출력·기록·수동 복사, setup·키 생성·비밀 키 내보내기는 하지 않았다.

### 후보·준비물·연속성

- 새 public **`47a424564d4067c697b17b23aedcc0af9ab160ee`**, 부모 `eb5e62afd8ad6205e40d79386e34641d077ab898`(0.2.4). 동일 트리 `9d4de75724f1fe24269320f5225b58b8deb52389` = 위 버전 커밋 트리. 부모 뒤 공개 커밋 하나만 추가했고 개인 개발 이력은 넣지 않았다.
- 원본 main은 TASK-16 `3695d5e195144857700daf67bdfe1c17628797fd`를 조상으로 포함한다(`ancestor-task16.log/json`). 같은 public 트리의 `app/`은 버전 커밋 main과 바이트가 같고 `app/Sources`·`app/Tests`는 TASK-16 검토본과 같다. 선례대로 “public 트리에 조상 포함”은 원본 main의 조상 관계와 공개 트리 일치로 확인하며, public 자체에 개인 개발 커밋을 연결하지 않는다.
- 준비물: `.build/release-0.2.5/prepared.json`, `.build/release-0.2.5/hejo-0.2.5-arm64.zip`(**6,392,474 bytes**), 압축 SHA-256 **`4e2aefec91e018995d77d0a46549d500d713e3fb144945d714a4521fef3b5336`**.
- 기본 배포 빌드와 압축 해제본 BuildInfo는 위 트리·`dirty=false`이고 실행 파일 바이트가 같다. 후보 0.2.5·7은 이전 public/준비물 및 설치본 0.2.4·6보다 각각 크다. 후보·0.2.4 준비물·설치본의 업데이트 공개 키가 같고 코드 서명 Authority도 설치본과 같다. 기존 키체인 키를 재사용했다. 압축 해제본 codesign, Sparkle 서명과 별도 Ed25519 공개 키 검증을 모두 통과했다.
- 설치 앱 메타데이터, 게이트웨이 PID/시작 식별자, 공용 릴리스 식별자, 운영 저장소 HEAD/상태는 착수와 같다(`before.json`, `final-integrity.json`). 설치 앱·공용 릴리스·운영 홈·문 설치·재시작·실제 메시지는 변경/실행하지 않았다. 이 보고서 후속 커밋은 제품 변경을 포함하지 않으며 고정 후보를 재생성하지 않는다.

### 검증

증거 `E23` = `.build/finder-folders-evidence/round23-task17/`. 대상은 위 새 public과 같은 트리의 깨끗한 checkout이다. 전체 시험은 처음부터 짧은 TMPDIR·pytest basetemp 및 resolve한 임시 HERMES_HOME/HERMES_ROOT, 게이트웨이 Python으로 실행했다. 시험 소스 변경은 0이고 public blob과 대조했다(`tested-sources.json`, `final-integrity.json`).

| 명령·확인 | 실제 결과 | E23 증거 |
| --- | --- | --- |
| `git commit --only` 버전 두 경로 및 자기 경로 `git diff --check` | 각각 0 | `version-commit.log/json`, `version-diff-check.log/json` |
| `install/hejo-publish`(로컬 작성자 대역)·공개본 개인값 검사 | 각각 0, 부모·트리·개인 이력 분리 확인 | `publish-local.log/json`, `public-private.log/json`, `snapshot.json` |
| 시험 전 `pgrep -f app-tests` 및 다른 GUI 빌드 조사 | 종료 1(다른 실행 없음), 빌드 겹침 없음 | `app-pgrep-short-tmp.log/json`, `gui-builds.json` |
| `HEJO_PYTHON=<게이트웨이 Python> bash scripts/test.sh` | **종료 0**, 434 passed, 게이트웨이 정상 종료, 앱 전체·통신 회귀 통과, 404.074초 | `full-short-tmp.log/json` |
| 실제 CLI 설정 메타데이터·다운로드 이름 전후 guard | 모두 0, 내용 미조회·불변 | `settings-*-short-tmp.log/json`, `downloads-*-short-tmp.log/json` |
| 같은 깨끗한 트리 `bash app/scripts/build.sh`(기본 배포 빌드) | 0 | `default-build.log/json` |
| `install/hejo-ship prepare --output <준비물 폴더>` | 0 | `prepare.log/json`, `prepared-verification.json` |
| `ditto -x -k`·해제본 `codesign --verify --deep --strict` | 각각 0 | `extract.log/json`, `archive-codesign.log/json` |
| 기존 계정 Sparkle `sign_update --verify`·별도 cryptography Ed25519 공개 키 검증 | 각각 0 | `archive-sparkle.log/json`, `independent-signature.json` |
| main/public 개인값 검사 및 자기 경로 diff 검사 | 모두 0 | `main-private-final.log/json`, `public-private-final.log/json`, `report-private.log/json`, `report-diff-check.log/json` |

기존 Swift 동시성 등 경고는 남아 있다. 새 제품 알고리즘이나 서명 규칙은 변경하지 않았으므로 추가 mutation 빌드는 생략했다. 개인값 검사는 비밀 파일을 입력하지 않는 임시 홈으로 실행했다. 실패·skip·기준 완화로 통과시키거나 추가 성능 작업을 하지 않았다. M7은 이미 사용자가 수용한 기록을 유지하며 이번 남은 사용자 확인은 M12다.

실제 전체 시험 로그의 PASS 줄:

```text
AT-FF-90/92/93 PLACEMENT BOUNDARIES PASS
AT-FF-91 NATIVE OUTSIDE AND RESTORE PASS; AT-FF-93 regression in full suite
AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS
AT-PG-01...11,13 PASS
APP_TEST_OK
AT-FF-40 dark PIXEL PASS alpha=1.0
AT-FF-40 light PIXEL PASS alpha=1.0
AT-FF-41 dark PIXEL PASS alpha=1.0
AT-FF-41 light PIXEL PASS alpha=1.0
```

AT-TD-33·35는 개별 PASS 문자열을 출력하지 않는 기존 묶음 시험에 들어 있다. 따라서 위 `AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS`를 인용하며, 해당 단언이 TASK-16 검토본과 같은 바이트임을 별도로 확인했다. AT-FF-93 전체 회귀는 이 묶음·픽셀·전체 명령 종료 0에 대응한다.

검증 중 계획 담당의 문서 커밋 `d5292fa139fe8b20bb7a0c49bcb5cac768800682`가 main에 추가됐다. 처음 최종 처리의 HEAD 고정 확인은 종료 1로 멈췄다(`finish-head-guard.json`). diff가 verdict.md 4줄뿐이고 제품 차이 0임을 확인한 뒤, 고정 후보는 유지하고 문서만 추가된 경우를 허용해 이어 갔다(`concurrent-docs.json`). 추가 문서의 HEJO-POST-GROUP 확인도 기존 후보 전체 로그의 `AT-PG-01...11,13 PASS`로 충족한다. `aacf168`이 고정 버전 커밋의 조상임을 별도 종료 0으로 확인했다(`ancestor-post-group.log/json`). 제품 코드·준비물·시험 입력이 같아 전체 시험이나 후보 생성을 반복하지 않았다.

### 서버 문 차이·인계

후보 `gate/`·`schemas/`를 공용 릴리스 실행본과 실제 바이트로 대조했다(`server-gate-final.json`). **실행 코드·schemas 차이 0, 문서 `gate/README.md` 하나만 다르다.** 아래 `gate/tests/` 20개는 기존 hejo-release에서 의도적으로 제외하는 시험 파일이며 실행본 변경으로 세지 않는다. README 외 실행용 차이는 없으므로 중단 조건에 해당하지 않는다. 파일 목록만 기록한다.

```text
gate/README.md
gate/tests/conftest.py
gate/tests/extension_support.py
gate/tests/gateway_delivery.py
gate/tests/imessage_settling.py
gate/tests/support.py
gate/tests/test_answer_targets.py
gate/tests/test_boundaries.py
gate/tests/test_connections.py
gate/tests/test_delivery_parity.py
gate/tests/test_employee_query.py
gate/tests/test_extensions.py
gate/tests/test_gateway_progress.py
gate/tests/test_owner_query.py
gate/tests/test_pictures.py
gate/tests/test_progress.py
gate/tests/test_report_query.py
gate/tests/test_review55.py
gate/tests/test_review56.py
gate/tests/test_rooms.py
gate/tests/test_threads.py
```

요청된 사장용 명령 두 줄(이번에는 모두 미실행):

```sh
git push github 47a424564d4067c697b17b23aedcc0af9ab160ee:refs/heads/main
install/hejo-ship publish --approve-commit 47a424564d4067c697b17b23aedcc0af9ab160ee --prepared .build/release-0.2.5/prepared.json
```

푸시 대상은 **hejo 저장소 로컬 public `47a424564d4067c697b17b23aedcc0af9ab160ee` → `github/main`**이다. 개인 main 이력이나 이 보고서 커밋을 공개 원격에 보내지 않는다. 실제 푸시는 사용자 승인 화면의 대상 확인 절차를 따르며 에이전트는 실행하지 않는다. 원격 포함은 이번에 조회하지 않았다. 공개·실제 업데이트 설치(수준 4)·M12·현재 명세 반영·푸시 완료 판정은 남아 있다. 서버 문 설치·재시작은 실행하지 않았으며 실행 코드 차이 0이라는 증거를 다음 담당에게 넘긴다. 검증자는 후보 트리·준비물 지문·서명 연속성·서버 차이 목록과 실제 단언 포함을 확인한다. 배포 전 검증 실패 시 공개하지 않고 준비물을 보존한다. 운영 변경은 없어 운영 롤백은 해당하지 않는다.
