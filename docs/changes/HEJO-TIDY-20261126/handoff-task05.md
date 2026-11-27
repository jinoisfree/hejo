[설계 인계: HEJO-TIDY TASK-05 / 공개판 코드 정리 감사(코드 변경 없음)]

**칸·원본·쓰기 주체·수명:** [design.md 1절](design.md). 감사는 읽기만 한다. 새 칸·원본은 없다.

0. **기준**
   - base_commit: 공개 `github/main` `878ce94fe228d274e6a33248e4e7d4a4d8e804d6`(푸시 2 반영, 2026-11-26 `ls-remote` 확인).
   - 문서: spec 3판 REQ-TIDY-07, design D-07, 수락 시험 AT-TIDY-15.
   - 운영 모드: 연합개발.
1. **공식 문서:** [spec](spec.md) REQ-TIDY-07, [design](design.md) D-07, `tests/acceptance/HEJO-TIDY.md` AT-TIDY-15·16, `docs/ARCHITECTURE.md`(공개판) 3·5절.
2. **요구:** REQ-TIDY-07 AC-01·03. AC-02는 TASK-06에서 다룬다.
3. **유지할 계약:** 이 작업은 코드를 바꾸지 않는다. 대상 저장소의 추적 파일 변경은 0이어야 한다.
4. **감사 범위(R1-01)**
   - `git ls-files`(공개 worktree, HEAD `878ce94`) 전체에서 다음을 뺀다: `docs/`, `evidence/`, `README.md`, `AGENTS.md`, `CLAUDE.md`, `LICENSE`, `.gitignore`.
   - 남는 범위: `app/`, `gate/`, `hub/`, `install/`, `scripts/`, `schemas/`, `tests/`, `githooks/`, `config/`.
   - 범위 표: 디렉터리별 파일 수를 적고, "전체 − 제외 = 범위"가 맞는지 보인다.
5. **후보 분류와 근거 기준**
   - **미사용:** 선언(함수·타입·속성·상수·Python 함수·모듈)이 정의 밖에서 참조되지 않는다.
     - 근거는 단어 경계 검색 명령과 결과(0건)다.
     - 다음 동적 참조도 확인한다: `@objc`·`#selector`·`NSMenuItem` action 문자열, 프로토콜 요구·`override`, `Codable` 키, Info.plist, 문자열 디스패치(`getattr`·딕셔너리 분기), pytest fixture 이름, Hermes 플러그인 계약 진입점(`gate/__init__.py`·`plugin.yaml` 등), 셸에서 부르는 경로, 규격 JSON의 `$defs` 참조, `TestMain.swift` 등록.
   - **중복:** 같은 의미의 구현이 두 곳 이상 있다. 두 구현과 입력·출력이 같다는 근거(코드 대조)를 적고, 하나로 합칠 원본 자리를 공항 칸 기준으로 제안한다.
   - **죽은 분기:** 도달할 수 없는 조건이다(제거된 기능의 플래그, 항상 참·거짓인 조건).
   - **제거된 기능의 잔재:** 텔레그램·Slack 이전 경로·레거시 참조 빌드 등. 남은 이유가 있으면 "유지"로 분류한다.
   - **조사 과제:** 사용처를 확정하지 못한 항목. 지우지 않는 후보다(AC-03).
6. **위험도와 증거:** 경미(읽기). 증거 수준 1(소스 검색).
7. **결과물:** 감사 문서 `docs/changes/HEJO-TIDY-20261126/cleanup-audit.md`(개발 main, `git commit --only`).
   1. 범위 표(4번).
   2. 후보 표. 열: `ID(CU-NN) | 칸 | 경로:줄 | 분류 | 근거(명령과 결과) | 지웠을 때 영향 | 함께 지울 시험 노드 | 권고(삭제/통합/유지/조사)`.
   3. 갈래 제안: 칸별로 겹치지 않는 묶음(예: 관제 화면 `app/`, 탑승교 `gate/`, 허브·정비 격납고 `hub/`·`install/`·`scripts/`·`githooks/`·`tests/`). 각 묶음의 예상 삭제 줄 수를 적는다.
   4. `tests/acceptance/`의 수락 시험 명세(`*.md`)·기대값 후보는 "기획 승인 필요"로 표시한다.
   - 보조 스크립트와 출력은 공개 worktree `.build/tidy/task05/`에 두고, 감사 문서에서 경로로 가리킨다.
   - `impl-report.md`에는 "TASK-05" 절을 짧게 두고 감사 문서를 링크한다.
8. **수락 시험:** AT-TIDY-15(계획 담당이 감사 문서를 검토한다).
9. **작업 범위**
   - 공개 worktree `../.worktrees/hejo-tidy-public-20261126`(HEAD = 원격 `878ce94`)에서 읽기만 한다.
   - 금지: 추적 파일 수정·커밋(공개 worktree), git push, 서버 쓰기, 앱 설치, 외부 패키지 설치(필요하면 표준 도구 `grep`·`git grep`·`python3 -m ast`·`swiftc -dump-ast` 등만).
   - 병렬 갈래: 없음(경미 변경, 읽기 전용 감사 1건).
10. **가정·미확정:** 없음. 후보마다 삭제할지 승인하는 것은 계획 담당이 TASK-06 인계 때 한다.
11. **사용자 확인:** 범위는 브레인스토밍에서 사용자가 정했다("공개판 전체 코드"). 이후 결정은 계획 담당 추천으로 진행한다(사용자 위임).
