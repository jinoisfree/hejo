# [설계 인계: HEJO-OWNER-PROFILE TASK-01·02 / 사장 이름·사진과 말풍선 통일]

0. **기준**: base_commit 공개판 `github/main` `c22e6774604398f84351d69dd926ba3510d31aa2`(2026-11-25 `git fetch` 뒤 읽기로 확인). TASK-02 시작 때는 그때의 `github/main`(AUTOLOAD 반영분)을 작업 브랜치에 merge하고 그 해시를 impl-report에 적는다 / spec·design 2판·수락 시험 2판 / 작성 2026-11-25 / 승인 상태: 사용자가 방향·범위 결정(brainstorm), 계획 검증 1회차 BLOCKED 지적 5건 수용·반영(plan-review.md), 2회차 대기 / 운영 모드: 교차 모델(+계획 검증)

1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), [수락 시험](../../../tests/acceptance/HEJO-OWNER-PROFILE.md), [brainstorm.md](brainstorm.md), 시안 [mock-chat.png](mock-chat.png)·[mock-profile.png](mock-profile.png), 근간 `docs/ARCHITECTURE.md`, 계약 `schemas/hejo-wire-v1.json`·`schemas/pictures.md`.

2. **요구와 수락 기준**: REQ-OP-01~07(spec). 정상: 이름·사진을 정하면 모든 기기 앱, 텔레그램·디스코드 표기, 직원 맥락·Hermes `user_name`에 쓰이고, 채팅의 모든 글이 같은 모양 말풍선이며 내 글 머리줄은 `시간 이름 [사진]`. 핵심 실패: 잘못된 이름·사진·인증은 저장값을 바꾸지 않고, 깨진 저장 파일·옛 문/옛 앱은 연결을 막지 않는다.

3. **반드시 유지할 계약**: 기존 wire 프레임·HTTP 경로의 기존 필드와 의미(`owner`는 선택 속성 추가만), 직원·방 사진 경로와 파일 위치, 설정 안 됨일 때의 기존 표기(텔레그램·디스코드 `사장`, 맥락·버튼 `나`), Hermes 세션 키·`user_id`, 기록장 레코드 종류(늘리지 않음), 사용자 말풍선 색 설정, 표·코드의 TextKit 그리기.

4. **변경 후 책임과 흐름**: 사장 프로필의 유일한 원본은 문의 공용 창고(`shared/hejo/owner.json`, `pictures/owner.png`)이고 문만 쓴다. 앱은 welcome·roster의 `owner`를 메모리에만 두고 HTTP로 바꿔 달라고 요청한다. 문 안의 사장 표기는 `adapter.owner_label(기본값)` 하나를 거친다. 앱의 말풍선 배치는 `NativeThreadCard` 한 곳에서 내 글·직원 글 모두 같은 상수로 한다.

5. **기존 경로 판정**: design 4절. `isConversational`·`Post.conversational`·`postPieces(conversational:)`는 제거(같은 변경에서 호출부·시험 정리), 내 말풍선 반지름 16과 말풍선 아래 시간 줄은 교체, 사진·roster는 유지·확장, 사장 표기 문자열 세 곳은 표시 이름 함수로 교체. 이중 경로 없음.

6. **위험도**: 일반(여러 모듈 기능 추가, 선택 속성 wire 확장, 작은 저장 파일 추가, 앱·문 되돌리면 복구). 필요한 증거 수준: 3(임시 `HERMES_HOME`의 실제 문 loopback HTTP/WS 시험, 실제 앱 코드 배치·그리기 시험). 서버 설치는 범위 밖이므로 4는 요구하지 않는다.

7. **변경 성격**: 의미 변경. 비교 방법: 기준 커밋에서 `bash scripts/test.sh`와 앱 시험의 통과·실패 목록을 먼저 기록하고(AUTOLOAD 인계서가 적은 기존 실패가 있을 수 있음), 구현 뒤 같은 명령의 실패 목록이 기준과 같고 새 실패가 없음을 보인다. 기대값을 바꾼 기존 시험은 수락 시험 문서 "기존 회귀 시험의 기대값 변경" 절 범위만.

8. **수락 시험**: `tests/acceptance/HEJO-OWNER-PROFILE.md` AT-OP-01~14(문), AT-OP-20~36(앱, 35는 앱 둘↔실제 loopback 문 왕복). 기대값 출처는 spec AC와 사용자 결정. 상태: 명세 확정 / 코드 미작성(구현 담당이 `gate/tests/test_owner_profile.py`, `app/Tests/OwnerProfileTests.swift`, `app/Tests/OwnerProfileTransport.sh`(기존 HistoryTransport 하네스 방식)로 옮기고 시험 스크립트에 등록) / 실행 전 / 독립 검토는 계획 검증. 기대값·합격 기준은 바꾸지 않는다. 틀렸다고 판단되면 멈추고 보고한다. impl-report에는 시험 함수 ↔ AT 번호 ↔ 결과 ↔ 로그 표를 적는다.

9. **작업 범위**
   - 범위: tasks.md "영향 파일". 수락 시험 문서의 공개판 사본(내용 그대로)을 작업 브랜치에 넣는다.
   - 허용 예외(tasks D-03): AT-SM-02의 wire 스키마 SHA-256 기대값과 설명 주석 한 줄만 갱신.
   - 금지: Hermes 본체(`~/.hermes/hermes-agent`) 변경(읽기만), `hub/` 변경, 새 wire 프레임 종류·기록장 레코드 종류, 앱 로컬 설정·허브 설정에 이름 복사, SwiftUI 도입, 운영 서버(`~/.hermes`) 설정·설치·재시작·비밀 파일 열기, 실제 메시지 전송, 버전 번호·배포 피드 변경, 개인값(실제 이름·계정·절대 경로) 기록, 개발 `main`·계획 폴더의 제품 파일 수정.
   - 작업 공간: `github/main`(base_commit)에서 새 worktree와 브랜치를 만들어 그 안에서만 고치고 커밋한다. 경로·브랜치 이름은 추적하지 않는 `AGENTS.local.md`의 HEJO-OWNER-PROFILE 줄. 호스트가 배정하는 `role-workflow/…` worktree는 개발 `main` 이력이라 제품 변경·커밋에 쓰지 않는다(verdict 1차). 기준 시험은 impl-report 1차 표를 비교 기준으로 쓴다. 작업 문서(`impl-report.md`)는 이 계획 폴더의 `docs/changes/HEJO-OWNER-PROFILE-20261125/`에 쓴다. 로그·증거 PNG는 worktree의 `.build/owner-profile/`.
   - 순서: TASK-01(문) → TASK-02(앱). TASK-02는 HEJO-AUTOLOAD TASK-01이 `github/main`에 반영된 뒤에만 시작한다(확인: `git fetch github` 뒤 `git grep -c 'readerAnchor(allowAtEnd:' github/main -- app/Sources/NativeThreadList.swift`가 1 이상). 반영 전이면 TASK-01까지 커밋한 뒤(사용자 지시 2026-11-25: 순차 진행, 2번은 감지하다가 끝나면 시작) 10분 간격으로 `git fetch github`와 위 확인 명령을 반복해 반영을 감지하고, 반영되면 바로 TASK-02를 시작한다. 감지는 읽기 명령만 쓴다. 3시간 안에 반영되지 않으면 TASK-01 결과와 함께 "TASK-02 대기"로 result를 낸다. 반영됐으면 최신 `github/main`을 작업 브랜치에 merge한 뒤 TASK-02를 한다.
   - 시험 환경: 문 시험·개인값 검사는 Hermes 실행 환경 Python이 필요하다(시스템 `python3`는 실패). 읽기만 하고 아무것도 설치하지 않는다. 기록 하네스가 필요하면 AUTOLOAD 인계서의 `HEJO_HISTORY_SPARKLE` 방식을 따른다.
   - 실행할 검사: `bash scripts/test.sh`(문 pytest + 앱 시험), `bash app/scripts/build.sh`, 개인값 검사 `scripts/scan_private.py`. 로그 경로를 보고한다.
   - 눈 증거: 수락 시험 문서 "눈으로 보는 증거"의 PNG 두 장.
   - 병렬 갈래: 없음(갈래 2개: 문·앱, 3개 미만).

10. **가정·미확정**
    - [제안] 말풍선 공통 값은 지금 직원 말풍선 값(반지름 12, 여백 12×8). 시안 그림의 수치(14×12)는 참고용이다.
    - [제안] "내 프로필"은 기존 설정 창의 영역(시안의 별도 창 틀은 참고용).
    - [가정] 텔레그램·디스코드에서 들어온 사장 글도 `adapter.py`의 같은 사장 글 처리 경로로 Hermes에 간다. 다르면 그 경로에도 같은 `user_name`을 넣고 보고한다(새 경로 만들지 않음).
    - 착수 차단 범위: TASK-02만 AUTOLOAD 반영 대기.

11. **사용자 확인**: 방향·범위·연합개발·계획 검증 켜기를 2026-11-25 질문 도구와 대화로 확인(brainstorm.md).

## 인계 전 점검
- 현재 코드·계약·명세가 base_commit과 호환되는가: `github/main`이 `c22e677`임을 읽기로 확인. 인용 행 번호는 그 커밋 기준.
- G1: spec 요구·범위·제외, 미확정 없음(제안 표시만).
- G2: design 1~4절에 칸·경로 근거·판정.
- G3: AC ↔ AT-OP 연결(수락 시험 문서). 독립 검토는 계획 검증 2회차 통과(APPROVED, 기록 plan-review.md).
- G4: 일반, 증거 3, REQ→AC→시험→TASK(tasks.md), 기준 커밋 고정.
