[설계 인계: HEJO-TIDY TASK-06 / 승인된 정리 적용(동작 보존)]

**칸·원본·쓰기 주체·수명:** [design.md 1절](design.md). 새 칸·원본은 없다. CU-07의 원본은 탑승교 칸 안 `gate/context.py` 하나로 둔다.

0. **기준**
   - base_commit: 공개 `github/main` `878ce94fe228d274e6a33248e4e7d4a4d8e804d6`.
   - 감사: [cleanup-audit.md](cleanup-audit.md)(`ce27bdc`).
   - 승인: [verdict.md](verdict.md) 5회 5번(계획 담당 추천, 사용자 위임).
1. **요구:** REQ-TIDY-07 AC-02·03. 시험은 AT-TIDY-16.
2. **적용 목록(이것만)**
   - CU-01: `BubbleOpacity.worstContrast`와 그 전용 주석을 삭제한다.
   - CU-02: `ConversationModel.togglePin`을 삭제한다.
   - CU-03: `ConversationView.deleteSectionPicture`를 삭제한다.
   - CU-04: `ConversationView.smoothClearBodies`·`smoothHighlight`를 삭제한다(PERF 빌드 블록 안).
   - CU-05: `ScreenFocus.fromOutput`을 삭제한다.
   - CU-06: 감사 표의 미사용 import 이름만 지운다. 같은 줄의 다른 이름은 그대로 둔다.
   - CU-07:
     - `gate/history_queries.py`의 `thinking` 정의를 지우고 `from .context import thinking`으로 바꾼다.
     - `server.py:316`의 `from .history_queries import thinking`은 그대로 동작해야 한다.
     - 순환 import가 생기지 않는지 확인한다.
   - CU-08: `TypingTests.swift:41`과 `IslandTests.swift:169`의 같은 캡처 함수를 `app/Tests` 공용 보조 한 곳으로 옮긴다. 호출 시점과 PNG 파일 이름은 그대로다.
   - 그 밖의 정리(감사 밖 발견 포함)는 하지 않는다. 새로 발견한 것은 impl-report에만 적는다.
3. **유지할 계약:** 외부 동작 전부, `schemas/` 바이트(AT-SM-02 해시 `966e53c3…` 그대로), 시험 노드 목록(삭제 0).
4. **변경 성격:** 동작 보존 리팩토링.
   - 비교 기준: 기준(`878ce94`)과 후보에서 다음이 같아야 한다.
     - 전체 pytest JUnit의 노드와 결과 집합.
     - `bash app/scripts/test.sh` 종료 코드(흔들리는 TD-1 시험은 재실행 규칙).
     - `bash app/scripts/build.sh`.
     - 런타임 Python `scan_private`.
     - `history_transport_app.py` 전체.
     - `-m gate.tests.gateway_delivery`.
     - `git diff --exit-code 878ce94 HEAD -- schemas/`.
   - PERF 빌드: `app/scripts/test.sh` 안에 PERF 조건 빌드가 있으면 그 결과를 따로 적는다.
5. **위험도·증거:** 일반, 증거 수준 2.
6. **작업 범위**
   - 공개 worktree `../.worktrees/hejo-tidy-public-20261126`(HEAD = 원격 `878ce94`)에서 한다.
   - 커밋은 갈래별로 하나씩: 관제 화면 제품, 관제 화면 시험, 탑승교.
   - 증거는 `.build/tidy/task06/`, 보고는 개발 main `impl-report.md` "TASK-06" 절(`git commit --only`).
   - 금지: 목록 밖 삭제, 시험 노드 삭제, 규격·수락 시험 기대값 변경, git push, 서버 쓰기, 앱 설치, 버전 변경, rebase·force.
   - 병렬 갈래: 있음. 담당 파일이 서로 겹치지 않는다.
     - 갈래 A(관제 화면 제품): `app/Sources/BubbleOpacity.swift`, `ConversationModel.swift`, `ConversationView.swift`, `ScreenFocus.swift`. 단순. 완료 조건은 앱 빌드 0.
     - 갈래 B(관제 화면 시험): `app/Tests/TypingTests.swift`, `IslandTests.swift`, 공용 보조 파일 1개. 단순. 완료 조건은 앱 시험 0, PNG 경로가 같음.
     - 갈래 C(탑승교): `gate/connection_manager.py`, `connections.py`, `connection_runtime.py`, `server.py`, `adapter.py`, `history_queries.py`. 단순. 완료 조건은 pytest 노드·결과가 같음.
     - 선행 관계는 없다. 마지막 통합 비교는 한 번 한다. 실제로 나눠 실행할지는 구현 담당이 판단한다(20-implementation 4.10).
7. **가정·미확정:** 없음.
8. **사용자 확인:** 승인 목록은 사용자 위임에 따라 계획 담당이 결정했다.
