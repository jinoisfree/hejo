# HEJO-DRAWER-INLINE 작업

2판 · 2026-11-22(계획 검증 1회차 반영) · [spec](spec.md) · [design](design.md) · [수락 시험](../../../tests/acceptance/HEJO-DRAWER-INLINE.md) · [인계](handoff.md)

| TASK | 내용 | REQ·시험 | 영향 파일 | 위험도·증거 | 선행 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 칸을 대화 보기 안 열로 옮기고 오른쪽 넓힘·왼쪽 비킴·좁은 화면 처리, 색 맞추기, 옛 경로·옛 시험 교체 | DI-01~06 / AT-DI-01~14·20~23·30~33 | `app/Sources/PetLayout.swift`, `PetController.swift`, `PetView.swift`, `ConversationView.swift`, `TodoDrawerView.swift`, `ConversationChrome.swift`·`SidebarMotion.swift`(공용 색 값만), `app/Tests/`(`TodoDrawerTests.swift`, `DrawerOutsidePlacementTests.swift`, `TodoDrawerBackgroundTests.swift`, 새 시험 파일, `TestMain.swift`) | 일반 · 2(+M-DI 사람 확인용 화면 사진) | HEJO-DEADLINE-CLOSE TASK-03 커밋이 main에 반영됨 | 대기(선행) |
| 반영 | 현재 명세 반영: TD spec REQ-TD-01 AC-04·REQ-TD-02 AC-01·03·04, FF spec REQ-FF-08·13, `tests/acceptance/HEJO-TODO-DRAWER.md` AT-TD-30·31·33·34·35, `HEJO-FINDER-FOLDERS.md` AT-FF-40·41·90~93에 "HEJO-DRAWER-INLINE로 대체" 표시, 이 문서들 상태 "적용" | — | `docs/`, `tests/acceptance/` | 계획 담당 | 검증 완료 | 대기 |
| 공개 | 다음 공개 판에 합침 | — | 공개 절차 | 사장 결정 | 검증 완료 | 이번 지시 밖 |

병렬 갈래: 없음(파일 겹침: 배치 계산·대화 보기·칸 보기가 한 흐름이고 `TodoDrawerTests.swift`·`PetController.swift`를 모든 갈래가 고친다. 갈래 3개 미만).

커밋: `git commit --only`로 자기 경로만. 다른 작업이 고친 `tests/acceptance/HEJO-TODO-DRAWER.md`와 HEJO-DEADLINE-CLOSE·HEJO-AUDIT 문서는 건드리지 않는다.
