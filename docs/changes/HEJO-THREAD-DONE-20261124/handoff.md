# 설계 인계: TASK-01 / 완결 스레드의 초록 상태 막대

0. 기준: base_commit `236b0177468b90d9ea23a1b1190e996db78a0694`, spec 2판, 2026-11-24, 연합개발, 사장 결정(완결 기준 A) 확인, 계획 검증 통과 전 구현 금지.
1. 공식 문서: 프로젝트 AGENTS, `docs/ARCHITECTURE.md`, 이 폴더 [brainstorm](brainstorm.md)·[spec](spec.md)·[tasks](tasks.md). 기존 규칙은 `docs/changes/HEJO-FOUNDATION-20261114/spec.md` REQ-HF-27.AC-03 상태 막대 줄.
2. 요구·AC: REQ-TD-01(AC-01~05), REQ-TD-02(AC-06~07). 핵심: 사장 답 → 작성이 끝난 직원 글이 있으면 완결 초록. 요청이 있던 스레드는 제목 🔴 색으로 되돌아가지 않음.
3. 유지 계약: 기록장·gate·reply_state 형식, 버튼 노출·숨김, 대상 지정 답(answer_to) 의미, 질문 대기 빨강(`AttentionRail.color`), 처리 중 노랑, closed 초록, 요청 없는 보고의 제목 색, 종·알림 목록이 같은 판정을 쓰는 구조.
4. 책임·흐름: 완결 판정은 `app/Sources/ThreadTools.swift`의 `ThreadAssessment.assess` 한 곳에서 한다(종 `ConversationModel.bell`, 알림 `WorkspaceTools` notices, 카드 색이 이 결과를 그대로 소비). 카드 상태 색 결정은 `app/Sources/ConversationView.swift` 카드 조립의 `tone` 한 곳에서 하며, 제목 표시 색 대체는 `state.request == nil`일 때만 쓴다. 시험이 카드 색을 관측해야 하면 그 한 곳을 시험 가능한 함수로 옮겨 화면과 시험이 같은 경로를 쓰게 한다(복사 경로 금지).
5. 기존 경로 판정: `finished`의 승인 단어 조건은 교체(사장 답 뒤 작성 끝난 직원 글 존재). `approved`(승인 단어 직후 초록)는 유지. 제목 색 대체는 유지하되 요청 없는 스레드로 범위 축소. 새 경로 공존 없음.
6. 위험도 일반(표시·종·알림 목록 동작 변경, 저장·권한 영향 없음, 되돌리기 쉬움). 증거 수준 3(앱 시험에서 실제 모델·판정 코드 실행). 롤백은 커밋 되돌리기.
7. 의미 변경. 비교: AT-TD-01~06 신규, 기존 AT87·AT76 기대값 불변 통과.
8. 수락 시험: spec의 AT-TD-01~07. 구현 담당이 `app/Tests/`의 기존 시험 파일(예: ReadNoticeTests.swift의 가짜 저장소 도우미)에 작성한다. 기대값은 spec 고정이며 바꾸지 않는다. 상태: 명세 작성, 코드 미작성, 미실행.
9. 허용: `app/Sources/ThreadTools.swift`, `app/Sources/ConversationView.swift`(필요 시 카드 색 함수를 둘 기존 파일 하나), `app/Tests/` 시험, 이 폴더 `impl-report.md`. 금지: gate·Hermes 본체·ddots·운영 `~/.hermes` 설정·비밀 파일, 다른 작업의 미커밋 변경(작업 트리에 gate/·docs/ 변경이 있음), 개인값(직원 id·이름·실제 스레드 id)을 코드·시험·문서에 넣기. 병렬 갈래: 없음(단일 판정 수정).
10. 미확정: 없음. 판정 소비자에서 이 설명과 다른 사용처가 나오면 멈추고 보고.
11. 사용자 확인: 브레인스토밍에서 완결 기준 "직원이 다시 답하면 완결" 선택, 연합개발·계획 검증 켬 선택.

## 검증·보고
`bash app/scripts/build.sh`, `bash app/scripts/test.sh`(가능하면 `bash scripts/test.sh` 전체), 개인값 검사 `scripts/scan_private.py`를 Hermes venv Python으로 실행하고 명령·종료 코드·로그 경로를 impl-report에 남긴다. 시스템 python3 실행 실패를 통과로 적지 않는다. 기존 실패는 base_commit에서 재현해 구분한다. 커밋은 자기 파일만 `git commit --only <경로>`로 하고 푸시는 하지 않는다. 실물 앱 화면 확인은 미실행이면 미실행으로 적는다.

[인계 전 점검] base_commit 이후 app/ 변경 없음 확인(작업 트리의 미커밋 변경은 gate/·docs/뿐). G1 사용자 결정 기록, G2 판정 소비자 3곳 확인, G3 AC↔AT 연결·기대값 출처 spec, G4 위험·범위·기준 기록. 계획 검증 대기.

## 보완 인계: TASK-03 공개 이력 통합 (2026-11-24 사용자 승인 "1 추천")

- 이유: 검증 완료 커밋 `f1cb67d3dfbd74f7479566db5b6cb5c6da53b065`의 기준(로컬 main `236b017`)과 공개 `github/main`이 공통 조상이 없다. 판정은 [verdict](verdict.md).
- 할 일: `github`를 fetch해 최신 `github/main`(조회 시 `3b0006179eef606ba3f3bf1de5230e8338f9cea7`, 다르면 최신 tip 사용·보고)에서 새 브랜치/작업 공간을 만들고 `f1cb67d`를 cherry-pick한다. 이어서 계획 담당 체크아웃의 작업 문서와 현재 명세를 별도 문서 커밋으로 넣는다: `docs/changes/HEJO-THREAD-DONE-20261124/`의 brainstorm·spec·handoff·tasks·plan-review·impl-report·verdict·(작성할) integration-report, `docs/spec/current/hejo-thread-status.md`, `docs/changes/HEJO-FOUNDATION-20261114/spec.md`의 상태 막대 줄 대체 표시 1줄(공개본에도 같은 원문 줄이 있다. 그 줄만 바꾸고 파일의 다른 차이는 가져오지 않는다).
- [확인] 공개본의 대상 줄은 이번 수정 전과 같다(ThreadTools.swift `let finished=` 101행, ConversationView.swift `let tone=` 981행). 충돌이 나면 같은 두 줄 의미만 옮긴다. TestMain.swift 등 시험 연결 충돌은 공개본 기존 분기를 보존하며 `--thread-done` 분기만 더한다. 두 작업의 의도 판단이 필요한 충돌이면 멈추고 보고한다.
- 검증: 공개본 기준 `HEJO_SKIP_GOOGLE_SECRET=1 bash app/scripts/build.sh`, 공개본 시험 빌드 방식으로 `--thread-done` 실행(AT-TD-01~06·AT87·AT76 통과), 제품 패치의 원본 대비 patch-id 비교, 개인값 검사(Hermes venv Python, 새 문서 포함 범위 확인), `git diff --check`. 전체 검사 잔여 실패가 나오면 공개 기준 tip에서 재현해 구분한다. 결과는 같은 폴더 `integration-report.md`에 남긴다.
- 금지: 개발 이력 전체 병합·rebase·force·push, 기대값 변경, 범위 밖 파일, 개인값. 커밋은 자기 파일만 `git commit --only`.
