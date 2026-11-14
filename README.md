# hejo

Hermes 플랫폼 플러그인 문과 별도 Mac 앱을 만드는 프로젝트다. 근간과 현재 범위는 [구조 원본](docs/ARCHITECTURE.md), 진행 상태와 판단은 [작업 문서](docs/changes/HEJO-FOUNDATION-20261114/)를 따른다.

## 설치·제거

Hermes 모듈과 ruamel.yaml을 import할 수 있는 Python으로 실행한다. `HEJO_PYTHON`은 해당 Python, `HERMES_HOME`은 대상 공항의 기본 홈을 가리킨다. `--home`을 생략하면 Hermes 홈 찾기 규칙을 쓴다.

```sh
"$HEJO_PYTHON" install/hejo-install --home "$HERMES_HOME"
"$HEJO_PYTHON" install/hejo-install --home "$HERMES_HOME" --check
"$HEJO_PYTHON" install/hejo-install --home "$HERMES_HOME" --uninstall
```

설치는 기본 프로필의 문과 프로필 API가 나열한 보조 프로필의 전달자를 연결한다. 기본 문만 포트·주소를 설정하며 보조에는 `extra.role: forwarder`를 쓴다. 설치 도우미는 게이트웨이를 재시작하지 않는다. 운영 설치·재시작은 운영 단계에서 별도로 확인한다. 문 자체의 공개 계약은 [gate/README.md](gate/README.md)에 있다.

`hejo/install-receipt.json`은 최초 설정·플러그인 목록·링크를 보관한다. 재설치는 이 before를 바꾸거나 사장이 고친 값을 덮어쓰지 않는다. 실패하면 적용한 단계를 역순 복구하고 종료 1이다. 기록용 `hejo/`와 failed 영수증은 남는다. 원래 있던 금고 자료는 보존한다. 제거도 금고·기록장·첨부를 남긴다. 설치 뒤 바뀐 대상은 충돌 경로를 알리고 보존하며 종료 2다. 원래 값으로 강제 복구하기로 결정한 경우에만 `--uninstall --force`를 쓴다. `--check`는 설치 상태와 대상 값·권한을 읽기 전용으로 검사한다.

## 개인값 검사

Python 3와 ruamel.yaml이 필요하다. `python3 scripts/scan_private.py`는 Git 추적 텍스트 전체를 검사하며 운영 홈에서는 owner/team.yaml·owner/vault.yaml만 읽는다. `--home`과 `--repo`로 임시 공항·시험 저장소를 지정할 수 있다. 발견값은 출력하지 않고 종류·파일·줄·SHA-256 지문을 출력한다. 종료 0은 위반 없음, 1은 탐지, 2는 검사 오류다. 바이너리는 이름만 표시하고 생략한다.

`scripts/scan_private_allow.txt`의 예외는 탭으로 구분한 파일 경로·정확한 줄의 SHA-256·이유다. 이유는 `fake-test` 또는 `license-notice`이며, 가짜 시험 값과 LICENSE 저작권 고지 줄만 허용한다. 파일 전체 예외는 없다. 검사 결과가 판단을 필요로 하면 예외를 늘려 통과시키지 않고 작업 보고로 돌린다. 운영 저장소의 실제 이름·경로는 추적하지 않는 AGENTS.local.md에만 둔다.

훅을 적용하려면 `git config core.hooksPath githooks`를 실행한다. 훅은 `HEJO_PYTHON`으로 지정한 Python 또는 python3를 쓴다. 의존성이 있는 Python을 지정해야 하며, 위반·검사 오류가 있으면 커밋을 막는다. 저장소 검사에서 위반 0을 확인하기 전에는 훅 적용 완료나 공개 준비 완료를 주장하지 않는다.

## 시험

Hermes 모듈·pytest·pytest-asyncio·aiohttp·jsonschema·psutil·ruamel.yaml을 import할 수 있는 Python을 `HEJO_PYTHON`으로 정한다. Hermes 소스를 PYTHONPATH에, team-kit 라이브러리 위치를 `HEJO_TEAM_KIT_LIB`에 지정한다. `bash scripts/test.sh`는 gate/tests와 tests/acceptance 전체 및 AT-HF-22 실제 게이트웨이 러너를 실행한다. 시험은 임시 공항과 가짜 직원만 사용한다. 앱 시험은 TASK-05에서 추가한다.
