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
| `P E/scan_changed.py`(hejo cwd) | 0 | hejo 개인값 검사 함수를 지정 세 파일에 적용. 신규 지적 0, 기준에도 있는 표준 `/mydrive` 문자열 지적 2건 구분 | `E/private-changed-final.log`, `E/private-changed-final.json` |
| `P -B -m pytest …/test_finder_folders.py -q -k at_ff_14 -p no:cacheprovider`(링크 검사 제거 mutation) | 1 | 의도대로 4 failed, 23 deselected | `E/mutation-links.log`, `E/mutation.json` |
| `P -B -m pytest …/test_finder_folders.py -q -k at_ff_03 -p no:cacheprovider`(동기화 파일 열기 mutation) | 1 | 의도대로 1 failed, 26 deselected | `E/mutation-file-open.log`, `E/mutation.json` |
| `git diff --check` | 0 | 공백 오류 없음 | `E/final-integrity.log` |

[확인] 개인값 추가 검사의 첫 시스템 Python 시도는 YAML 의존성 없음으로 종료 1이었다. 게이트웨이 Python으로 전체 세 파일을 검사한 초기 결과는 기준 코드의 표준 `/mydrive` 두 줄 때문에 종료 1(`E/private-changed.log`), 기준 원문과 대조해 **신규 변경분 지적 0**을 구분했다. airport-check의 기준선이나 제품·시험의 예외 목록을 바꾸지 않았다. 이 추가 검사는 tests를 제외하는 airport-check의 범위를 보완한다.

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
