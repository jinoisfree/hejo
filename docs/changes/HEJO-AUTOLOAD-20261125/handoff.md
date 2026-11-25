# [설계 인계: HEJO-AUTOLOAD TASK-01 / 화면에 닿으면 자동으로 불러오기]

0. **기준**: base_commit 공개판 `570c611f11fb531a8a98eff9823348ea5c0d9f37`(작성 때의 `github/main`). 2026-11-25 현재 원격 `github/main`은 `c22e6774604398f84351d69dd926ba3510d31aa2`로 4커밋 앞서 있다. 앱 소스 중 이 작업이 고친 6개 파일과 겹치는 변경은 없다(`git diff --stat 570c611..github/main`). 푸시 후보는 이 tip을 merge한 뒤 다시 검증한다 / spec·design 10판(verdict.md V-12 반영) / 작성 2026-11-25 / 승인 상태: 사용자가 방식·범위 결정, 계획 검증 4회차 통과(APPROVED) / 운영 모드: 교차 모델(+계획 검증)

1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), [수락 시험](../../../tests/acceptance/HEJO-AUTOLOAD.md), 근간 `docs/ARCHITECTURE.md`. 기록 나눠 받기의 현재 명세 문서는 공개판에 아직 없다(TASK-02에서 만든다).

2. **요구와 수락 기준**: REQ-ALD-01~07(spec 5절). 정상: 받는 범위의 미로딩 카드·긴 원문·이전 답글·최근 답글·비워진 본문이 클릭 없이 채워지고 불러오기 버튼 다섯 종류가 없다. 핵심 실패: 한 대상의 실패는 그 대상에만 "다시 시도"로 보이고 다른 대상을 막지 않으며 자동 재요청하지 않는다.

3. **반드시 유지할 계약**: 문과의 HTTP/WS 규약 전부(문 코드 변경 0), 본문 상주 한도 5MiB·500개와 고정 규칙, "전체 복사"는 명시 동작, 전량 수신 모드 동작, 직접 열기·검색 열기의 선택·펼침·스크롤, 미로딩·실패를 빈 대화·삭제로 바꾸지 않음.

4. **변경 후 책임과 흐름**: 대화 목록이 받는 범위의 카드와 펼친 스레드의 위·아래 끝 닿음을 알리고, 대화 화면이 이를 조정자에 "지금 필요한 것 목록"으로 넘기며, 조정자가 유일한 요청 주체로 한 번에 하나씩 받는다. 자동 요청은 선택·펼침·읽음·스크롤을 건드리지 않는다(design 3절의 조건 1~15). 선택 스레드 요청과 목록 창 넓히기·이전 스레드 쪽 요청은 기존 소유 경로(목록 갱신, `loadOlder`)에 남는다.

5. **기존 경로 판정**: design 4절. 버튼 다섯 종류와 "원문을 아직 불러오지 않았어요" 문구는 교체(같은 변경에서 삭제). 맨 위 닿음 처리 중 비워진 본문 복원만 받는 범위 알림으로 통합하고, 목록 창 넓히기·이전 스레드 쪽 요청·"이전 글 보기" 줄·선택 스레드 요청은 유지. `open`·`messages`·`content`·`restore` 요청 종류와 전체 실패 카드는 유지. 공존하는 이중 경로 없음.

6. **위험도**: 일반(여러 모듈의 기능 수정, 앱만 되돌리면 복구). 필요한 증거 수준: 3(실제 loopback HTTP/WS 시험 문과 실제 앱 코드로 실행한 하네스 결과).

7. **변경 성격**: 의미 변경. 비교 방법: 기준 커밋에서 기존 하네스·기본 시험 통과 수를 먼저 기록하고, 구현 뒤 기존 시험이 그대로 통과하는지와 새 AT-ALD 시험 결과를 함께 보고한다.

8. **수락 시험**: `tests/acceptance/HEJO-AUTOLOAD.md`의 AT-ALD-01~41과 같은 문서의 "기존 회귀 시험의 기대값 변경" 절. 기대값 출처는 명세 AC와 시험 문 fixture, 쪽 크기 50. 상태: 명세 확정 / 코드 미작성(구현 담당이 `app/Tests/HistoryTransportHarness.swift`로 옮김) / 실행 전 / 독립 검토는 계획 검증으로 진행. 기대값·합격 기준은 바꾸지 않는다. 시험 명세가 틀렸다고 판단되면 멈추고 보고한다.

9. **작업 범위**
   - 범위: `app/Sources/`의 `ConversationView.swift`, `HistoryCoordinator.swift`, `NativeThreadList.swift`, 필요하면 `ConversationModel.swift`·`HistoryProjection.swift`·`NativeThreadCard` 계열, `app/Tests/`의 기록 하네스와 그 실행 스크립트, `tests/acceptance/HEJO-AUTOLOAD.md`의 공개판 사본(내용 그대로).
   - 허용 예외(6판): `gate/tests/history_transport_app.py`와 `app/Tests/HistoryTransportHarness.swift`의 기존 복원 시험 다섯 fixture를, 수락 시험 명세 "기존 회귀 시험의 기대값 변경" 절의 항목에 한해 고친다. 그 밖의 기존 단언은 그대로 둔다.
   - 보고 형식: 새 하네스 시나리오마다 대응하는 AT-ALD 번호를 impl-report에 표로 적는다(시나리오 이름 ↔ AT 번호 ↔ 결과 ↔ 로그).
   - 금지: `gate/`·`schemas/`·`install/`의 제품 파일 변경, 메모리 한도 값 변경, 전량 수신 모드 화면 변경, 새 설정·새 저장 파일, SwiftUI 도입, 운영 서버(`~/.hermes`) 설정·설치·재시작, 실제 메시지 전송, 버전 번호·배포 피드 변경, 개인값(이름·계정·절대 경로) 기록.
   - 작업 공간: 이 계획 폴더(개발 `main`)에는 기록 나눠 받기 코드가 없다. `github/main`(`570c611`)에서 새 worktree와 브랜치를 만들어 그 안에서만 고치고 커밋한다. 경로와 브랜치 이름은 추적하지 않는 `AGENTS.local.md`의 HEJO-AUTOLOAD 줄을 따른다. 작업 문서(`impl-report.md`)는 이 계획 폴더의 `docs/changes/HEJO-AUTOLOAD-20261125/`에 쓴다.
   - 시험 환경: 기록 하네스는 `HEJO_HISTORY_SPARKLE`(이미 있는 Sparkle 프레임워크 폴더)이 필요하다. 문 시험과 개인값 검사는 Hermes 실행 환경의 Python이 필요하다(시스템 `python3`로는 실패). 두 환경 모두 읽기만 하고 아무것도 설치하지 않는다.
   - 기준 커밋의 기존 실패(구현과 무관, 구현 담당 측정): `bash scripts/test.sh`는 문 시험 5개 실패로 종료 1(`test_delivery_parity`·`test_gateway_progress`·`test_at_hf_22`·`test_at_hf_08[True]`·`test_at_sm_10_11_12`), `bash app/scripts/test.sh` 단독은 종료 때 실제 설정 메타데이터 보호 검사에서 종료 1. 이 실패들을 고치지 않는다. 구현 뒤 같은 명령의 실패 목록이 기준과 같고 새 실패가 없음을 보인다. 설정 메타데이터 검사는 실패 원인(어느 항목이 바뀌었는지)을 읽기만으로 확인해 보고한다.
   - 실행할 검사: 기록 하네스(`bash app/Tests/HistoryTransport.sh` 뒤 생성된 실행 파일), `bash scripts/test.sh`, `python scripts/scan_private.py`. 로그는 worktree의 `.build/autoload/` 아래에 두고 경로를 보고한다.
   - 선행 작업: 계획 검증 통과.
   - 병렬 갈래: 없음(파일 겹침: `ConversationView.swift`·`HistoryCoordinator.swift`를 모든 요구가 함께 수정).

10. **가정·미확정**
    - [제안] 받는 범위는 보이는 영역 ± 그 높이 1배, 허용 오차 1pt. 구현 중 이 값으로 AC를 못 맞추면 값을 바꾸지 말고 측정값과 함께 보고한다.
    - [확인] 착수 전 측정(2026-11-25, 구현 worktree `.build/autoload/baseline-anchor.log`, 검증 담당 재실행 일치): 위쪽 카드가 커질 때 읽던 글 이동 0pt, 목록 맨 끝에서 아래에 답글 쪽이 붙을 때 3,283pt. 뒤 경우는 design 3절 조건 12로 고친다. 이전 답글이 앞에 붙는 경우(AT-ALD-12)는 아직 재지 않았으므로 구현 중 먼저 재고, 1pt를 넘으면 값을 바꾸지 말고 보고한다.
    - 착수 차단 범위: 없음.

11. **사용자 확인**: 방식(A)·버튼 전부 자동·연합개발·계획 검증 켜기를 2026-11-25 질문 도구로 확인했다.

## 인계 전 점검

- 현재 코드·계약·명세가 base_commit과 호환되는가: 원격 `github/main`이 `570c611`임을 읽기로 확인했다.
- G1 요구 명세: spec 5절, 미확정 없음, 사용자 결정 기록(brainstorm).
- G2 현황·설계: design 2~5절에 경로 근거와 경로 판정.
- G3 시험: AC 39개 ↔ AT-ALD-01~41. 독립 검토는 계획 검증 4회차 통과. 1~3회차 지적 처리는 [plan-review.md](plan-review.md).
- G4 위험·인계: 일반, 증거 3, REQ→AC→시험→TASK 연결(tasks.md).
