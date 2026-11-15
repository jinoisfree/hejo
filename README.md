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

Hermes 모듈·pytest·pytest-asyncio·aiohttp·jsonschema·psutil·ruamel.yaml을 import할 수 있는 Python을 `HEJO_PYTHON`으로 정한다. Hermes 소스를 PYTHONPATH에, team-kit 라이브러리 위치를 `HEJO_TEAM_KIT_LIB`에 지정한다. `bash scripts/test.sh`는 gate/tests와 tests/acceptance 전체 및 AT-HF-22 실제 게이트웨이 러너를 실행한다. 시험은 임시 공항과 가짜 직원만 사용한다. 이어 macOS 앱 서명 빌드·AppKit 시험·임시 WebSocket 문 시험(AT-HF-23·24·25·47·48·52~56 및 대화 모델·첨부 왕복)을 실행한다. Xcode 명령행 도구와 아래 로컬 서명 인증서가 필요하다. 실제 로그인 항목 등록이나 운영 문 연결은 시험에서 하지 않는다.


## Mac 앱

`bash app/scripts/build.sh`는 swiftc 한 번으로 `app/.build/hejo.app`을 만들고 서명을 검사한다. 기본 인증서 이름은 `AIpet Local Development`이며 `HEJO_SIGNING_IDENTITY`로 바꾼다. 인증서가 없으면 빌드는 중단된다. 번들 식별자는 `io.github.hermes-hejo.hejo`다. 빌드한 앱은 응용 프로그램 폴더로 옮겨 실행할 수 있다.

펫을 누르면 대화 자리가 펼쳐진다. 다시 누르거나 Esc·“펫으로 접기”로 접는다. 4px 넘게 끌면 펫과 열린 자리가 함께 이동한다. 메뉴 막대는 보조 입구다. 로그인 시 실행은 설치한 앱에서만 선택하며 macOS의 승인이 필요할 수 있다. 펼친 화면은 ddots의 대화 배치를 AppKit으로 옮겼다. 왼쪽 직원 탭 줄(68px)은 가장자리를 끌어 목록(180~300px)으로 넓히거나 숨길 수 있다. 한 목록에서 스레드 카드를 열고 접으며 한 번에 하나만 펼친다. 입력 줄에서 새 글/답글을 전환한다. 직원별 안 읽은 수, 검색·서식·스트리밍·작성 중·버튼·첨부를 표시하며 접힌 펫에도 안 읽은 배지가 뜬다. 머리글의 오른쪽 클릭 메뉴로 “펫으로 접기”를 선택할 수 있다. Enter는 보내기, Shift Enter는 줄바꿈이다. 파일은 선택·놓기·붙여넣기로 첨부하며 업로드 뒤 문의 확인 글을 받아야 입력을 비운다. 끊기면 원래 입력을 보존하고 재동기화하며 자동으로 다시 보내지 않는다.

HEJO. 로고 옆 한 줄 알약에 연결·전송 문제, 사장 차례(답 요청·안 읽은 수), 일하는 직원을 모아 보여 준다. 답 요청 칸을 누르면 가장 오래된 질문을 펼치고, 직원 얼굴을 누르면 그 직원에게 이동한다. 마우스를 올리면 최근 질문 한 줄을 볼 수 있다. 일하는 직원 글자에는 밝은 띠가 지나가며, macOS 동작 줄이기에서는 흐린 글자로 멈춘다. 끊김은 주황 테두리와 재접속 안내로 표시하며, 보낼 수 있는 실패에는 “다시 보내기”가 붙는다. 파일을 올릴 때는 완료 수/전체 수를 표시한다. 알약은 옆으로만 늘어나며 그 위에서 끌어도 창이 이동하지 않는다. 수동 확인 항목과 자동 캡처는 [TASK-11 증거 자리](evidence/HEJO-FOUNDATION/TASK-11.md)에 있다.

처음 켜면 공항을 자동으로 찾는다. 공항 Mac에서는 문이 남긴 사장 전용 파일(`~/.hermes/hejo/local-pair.json`)의 일회용 코드로, 다른 Mac에서는 같은 사장 Tailscale 계정의 공항을 찾아 문이 Tailscale로 주인을 확인한 뒤 붙는다. 찾지 못하면 연결 설정에서 문 주소(포트 포함)·문에서 발급한 12자 코드·기기 이름을 입력한다. 코드의 `-`·`_`는 그대로 입력한다. 출입증은 Keychain 서비스 `io.github.hermes-hejo.hejo.gate-token`에만 저장한다. 앱의 Application Support 안 `hejo/hejo-local.json`에는 주소·기기 이름·적용 seq·읽은 seq·펫 위치·이름만 두며, `hejo/cache/`는 문의 기록장을 복제한 조회 캐시다. 캐시를 지우면 처음부터 다시 동기화한다. 출입증이 취소되면 새 코드로 연결한다.

`bash app/scripts/test.sh`는 앱 부분만 검사한다. 네트워크 시험은 루프백 임시 대역과 무작위 Keychain 시험 계정만 사용하고 마지막에 지운다. AT-HF-47의 실제 다른 앱 입력 중 포커스·동작 녹화 체크리스트는 [증거 자리](evidence/HEJO-FOUNDATION/TASK-05.md)에 있다.

대화의 원본은 문의 기록장이다. 앱의 읽음 seq는 스레드별로 저장하며 캐시에서 모델을 복원한다. 첨부는 출입증 헤더로 같은 문의 HTTP 경로를 사용하고, 내려받은 조회 복제는 `hejo/cache/files/`에 둔다. 다운로드는 클릭할 때 권한을 다시 확인하며 HTTP 리디렉션은 따르지 않는다. 대화 UI의 수동 점검은 [TASK-06 체크리스트](evidence/HEJO-FOUNDATION/TASK-06.md)를 따른다.
