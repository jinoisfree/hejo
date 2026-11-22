[설계 인계: HEJO-POST-GROUP-20261122 TASK-01 / 같은 직원 연속 답글 한 이름으로 묶기]
0. 기준: base_commit `84e64ac3bcd50c71e2bae3e720b76d84d57a9212`(3dc155dd 뒤 바뀐 것은 HEJO-FINDER-FOLDERS 문서 2개뿐, 이 작업 무관) / spec 2판·design 1판·수락 시험 2판 / 2026-11-22 / 승인: 사장 브레인스토밍 결정, 계획 검증 켬(통과 전 착수 금지) / 운영 모드: 연합개발(교차 모델)
1. 공식 문서: 칸·원본·쓰기 주체·수명 표는 [spec.md](spec.md) 첫 절(관제 화면 칸, 개발, 앱 갱신 때 교체, 저장 없음). [brainstorm.md](brainstorm.md), [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), 수락 시험 [tests/acceptance/HEJO-POST-GROUP.md](../../../tests/acceptance/HEJO-POST-GROUP.md), 전역 [docs/ARCHITECTURE.md](../../ARCHITECTURE.md). ADR 없음.
2. 요구와 수락 기준: REQ-PG-01(답글 칸에서 타임라인상 바로 앞 답글이 같은 직원이면 `Post.continuation=true`, 사장 글·다른 직원·더미·접힘 비인접은 끊음, top과 답글 사이는 안 묶음), REQ-PG-02(마지막 답글이 같은 직원이면 입력 중 `TypingBubbleView` 생략, 생각 중 글도 바로 앞이 같은 직원이면 조각 없음, 작업 줄 유지), REQ-PG-03(묶인 글 `textHelp`=시간, 체크박스 도움말 우선), REQ-PG-04(전체 시험·개인값 검사 통과).
3. 유지할 계약: 문·기록 프레임, `ConversationMessage`, `NativeThreadCard`의 `Piece`·`Post` 필드와 배치·그리기 코드, 스레드 첫 글 표시(`CardTests.swift:120`), `WorkingControlRow`, 접힘 규칙, 사장 말풍선.
4. 책임·흐름: `ConversationView.threadContent`가 shown 답글마다 "바로 앞 답글이 같은 직원(화면에 보임)"을 계산해 `postPieces`에 넘기고, `postPieces`가 글은 continuation·시간 툴팁으로, 생각 중 글은 빈 조각으로 바꾼다. 입력 중 머리 생략도 `threadContent`에서 판단한다. design.md 2절.
5. 기존 경로 판정: 생각 중 조각·입력 중 머리 생성·`Post.continuation`·버튼 나눔 뒷부분 모두 유지(조건만 추가). 철거 없음.
6. 위험도: 일반(공통 4절: 표시 동작 변경, 저장·계약·보안 영향 없음, 되돌리기 쉬움). 필요한 증거 수준: 2(실제 `ConversationView`·가짜 문 프레임의 앱 시험) + 1(빌드). 사장 화면 확인(4)은 완료 조건 아님. 롤백: 커밋 되돌리기.
7. 변경 성격: 의미 변경(표시). 비교: AT-PG-01~11·13 + 기존 앱 시험 전부.
8. 수락 시험: AT-PG-01~13, `tests/acceptance/HEJO-POST-GROUP.md`. 상태 명세 완료·코드 미작성·미실행·계획 검증 1회차 BLOCKED 반영 후 재검증 대기. 답글 3개 이상 시험은 펼친 상태가 기본(수락 시험 공통 준비), AT-PG-05는 접힘 전제를 먼저 assert. 코드는 구현 담당이 새 `app/Tests/PostGroupTests.swift`로 옮기고 `TestMain.swift` 기본 실행(typingTests·cardTests 옆)에 등록. 기대값 변경 금지.
9. 범위: `app/Sources/ConversationView.swift`, 새 `app/Tests/PostGroupTests.swift`, `app/Tests/TestMain.swift` 등록 줄. 금지: `NativeThreadCard.swift`·gate·hub·Hermes 본체·ddots·`~/.hermes` 변경, 기존 시험 기대값 수정. 선행 없음. 병렬 갈래: 없음(갈래 3개 미만: TASK 1개).
10. 가정·미확정: [가정] 시험에서 `ReplyButtonPolicy.split`·버튼 글 판정 입력은 기존 `CardTests.swift` 형태로 만들 수 있음 — 안 되면 해당 AT만 멈추고 보고. 미확정 없음.
11. 사용자 확인: 2026-11-22 사장이 범위(연속 글 모두 묶기)·끝난 모습(이름 한 번 아래 이어짐)·연합개발·계획 검증 켬을 선택.

[인계 전 점검]
- base_commit 호환: 3dc155dd..84e64ac3 차이는 다른 작업 문서뿐 [확인] `git diff --stat`.
- G1–G4: 요구·AC·시험·TASK 연결 완료, G3 독립 검토는 계획 검증 결과 대기.

검증 명령 안내: `HEJO_PYTHON=$(ls -d ~/.hermes/installs/*/environments/*/venv/bin/python | head -1) bash scripts/test.sh`, 같은 Python으로 `scripts/scan_private.py`(시스템 python3는 scan_error).
