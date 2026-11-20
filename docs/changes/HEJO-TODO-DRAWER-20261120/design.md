# HEJO-TODO-DRAWER 설계

1판 · 2026-11-20 · 명세 [spec.md](spec.md) · 칸 표는 [spec 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다.

## 1. 자료 흐름

```
직원 런타임 ─(기존 쓰기)→ <프로필 홈>/state/deadline-watch.json
                                   │ 읽기만
hermes-deadlines list --json (team-kit, 새 진입점)
                                   │ stdout JSON
문 gate/deadlines.py (실행·검사·묶기·공유 실행)
                                   │ deadlines_status 프레임
앱 TodoDrawerModel ← notices(모든 방) + 마감 목록 → TodoDrawerView (펫 패널 왼쪽 칸)
```

책임은 하나씩 둔다.
- 마감의 뜻(열림·닫힘·날짜)은 team-kit `deadline_watch`가 정한다.
- 실행 경계·크기 한도·이유 코드는 문 `Deadlines`가 정한다.
- 카드 묶기·정렬·문장은 앱 `TodoDrawerModel`이 정한다.
- 창 배치는 `PetPlacement`·`PetController`가 정한다.

## 2. team-kit: `hermes-deadlines` (운영 저장소, `HD` 규칙과 `./airport-check`를 따른다)

- 새 진입점 `HD/hermes/bin/hermes-deadlines`를 둔다. 머리는 `hermes-connections`와 같은 방식으로 게이트웨이 venv를 찾아 다시 실행한다. 본문은 `TKL`의 새 함수 하나만 부른다.
- 새 함수 `deadline_watch.open_items(home)`(이름은 구현 자유)를 둔다.
  - `load(path)`로 읽는다. 잠금을 잡지 않고, 폴더·파일·잠금 파일을 만들지 않는다. 심볼릭 링크는 거부한다(`snapshot`과 같은 검사).
  - `closed`가 비어 있는 항목만 고르고, `{id,title,due,deadline_at?,source}`만 돌려준다. `notifications`, `history`, `replies`, `source_check`는 내보내지 않는다.
  - 파일이 없으면 빈 목록이다.
- 명령 `list --json`의 출력:
  ```json
  {"version":1,"profiles":{"<직원 id>":[{"id":"notion:…","title":"…","due":"2026-11-20","deadline_at":"2026-11-20T18:00:00+09:00","source":"…"}]},"failed":[{"profile":"<직원 id>","reason":"deadline_state_corrupt|deadline_symlink_refused|read_failed"}]}
  ```
  - 대상 직원은 기본 프로필(`default`, 루트 홈)과 `owner/team.yaml`에 등록된 직원 전부다. 홈 경로는 `app_registry.profile_home`으로 만든다.
  - 직원 하나가 실패해도 나머지는 계속 읽는다. 종료 코드는 0이다.
  - 등록 명부를 읽지 못하면 `{"error":"TEAM_UNAVAILABLE"}`를 출력하고 종료 코드 1로 끝낸다.
- 명부를 읽는 함수, 홈 경로 규칙, `load`·`validate`는 새로 만들지 않고 기존 것을 부른다.

## 3. 문: `gate/deadlines.py`

- `Deadlines(home)`
  - `available`: `<HOME>/bin/hermes-deadlines`가 실행 가능한 파일인지로 판단한다. `TeamKit.available`과 같은 규칙이다.
  - `list()`: 위 명령을 `create_subprocess_exec`로 실행한다.
    - 실행 환경: `HERMES_HOME`, `HERMES_DISABLE_LAZY_INSTALLS=1`, `PYTHONDONTWRITEBYTECODE=1`. stdin은 DEVNULL, stderr는 버린다.
    - 10초를 넘기면 종료하고, 0.2초 안에 끝나지 않으면 강제로 끝낸다.
    - stdout이 512 KiB를 넘으면 `invalid_response`다.
  - 응답 검사: `version == 1`이어야 한다.
    - 각 항목은 `id`(문자열 1~300), `title`(1~300), `due`(ISO 날짜), 선택 `deadline_at`(ISO 시각), `source`(문자열 ≤1000)여야 한다.
    - 직원 id는 명부 규칙의 문자열이어야 한다.
    - 틀린 항목은 버리지 않고 전체를 `invalid_response`로 처리한다.
  - 이유 코드: `unavailable`(파일 없음), `command_failed`(실행 오류·종료 코드 ≠0·시간 초과), `invalid_response`.
  - 같은 때 들어온 요청은 진행 중인 실행 하나(`asyncio.Task`)의 결과를 함께 받는다(NFR-TD-02). 결과를 보관해 두지는 않는다.
- 앱에 보내는 링크: `source`가 `http://`·`https://`로 시작하는 URL일 때만 `url`로 보낸다. 그 밖의 `source` 원문은 앱에 보내지 않는다(NFR-TD-01, 앱은 링크 여부만 필요).
- 분배(`gate/server.py`): `connections` 분기 옆에 `deadlines` 분기를 둔다. 같은 연결의 다음 프레임을 막지 않도록 `asyncio.create_task`로 처리하고 연결이 끊기면 취소한다.
- 로그: `deadlines_read items=N failed=K`, 실패 시 `deadlines_failed reason=…`만 남긴다. 제목·출처는 넣지 않는다.

## 4. 통신 규격 (`schemas/hejo-wire-v1.json`)

- 앱 → 문 `{"v":1,"type":"deadlines","id":"<요청 id>"}`.
- 문 → 앱 성공 응답:
  ```json
  {"v":1,"type":"deadlines_status","ref":"<요청 id>","available":true,"items":[{"employee":"<직원 id>","id":"…","title":"…","due":"YYYY-MM-DD","deadline_at":"…?","url":"…?"}],"failed":["<직원 id>"]}
  ```
- 문 → 앱 실패 응답: `{"v":1,"type":"deadlines_status","ref":…,"available":true,"reason":"command_failed|invalid_response"}`.
- team-kit이 없을 때: `{"available":false,"items":[]}`.
- 기존 프레임은 바꾸지 않는다. 버전 `v`는 1 그대로이고, 새 종류만 더한다. 옛 문은 모르는 `type`에 기존 오류 프레임으로 답한다. 앱은 그 오류를 `available:false`처럼 다룬다(옛 문 호환).

## 5. 앱

### 5.1 모델 `TodoDrawerModel` (새 파일, AppKit 무관 순수 계산)

- 입력
  - `ConversationModel.notices(room)`: 모든 방(`rooms`)과 홈 방에서 모은다. 같은 글 id는 한 번만 넣고, muted 방은 뺀다.
  - 마감 목록과 그 상태(받은 적 없음 / 성공 / 실패 + 마지막 성공 목록 / 없음)
  - 현재 시각, 이름표·얼굴
  - 선택 칩
- 출력: 머리 개수, 칩별 개수, "급한 것"·"나머지" 카드 배열, 회색 안내 줄 여부, 빈 상태 여부.
- 카드 정렬·묶기는 spec REQ-TD-03 AC-02를 따른다.
- D-day는 앱의 현재 달력(`Calendar.current`) 날짜로 계산한다.
  - [가정] 사장의 Mac 시간대와 `deadline_watch`의 KST가 같다. 다르면 날짜 표시가 하루 어긋날 수 있으므로 위험 목록에 둔다.
- 답 요청 카드의 첫 줄과 시각은 `ConversationMessage.text` 첫 줄과 `timestamp`에서 만든다.
- 칸을 여닫는 상태(`open`)와 칩 선택은 이 모델이 아니라 아래 컨트롤러가 갖는다.

### 5.2 화면 `TodoDrawerView` (새 파일, AppKit)

- 세로 스크롤 목록(`NSScrollView` + 쌓기 보기)에 머리, 칩 줄, 묶음 제목, 카드를 둔다. 시안 v28의 배치를 따르지만 시안은 참고일 뿐 기준이 아니다.
- 카드 색은 다음과 같다.
  - D-DAY와 지남: 빨강 계열.
  - 답 요청: 기존 `ThreadAssessment.color`의 빨강.
  - 알림: 흐린 회색.
  - 선택된 카드: 강조색 테두리.
- 회색 안내 줄, 빈 상태 문장, Esc 처리, "‹ 접기" 단추를 둔다.
- SwiftUI는 쓰지 않는다.

### 5.3 열고 닫기와 창 배치

- `PetPlacement` 초기화에 `leading: CGFloat`(기본 0)을 더한다. 계산은 다음과 같다.
  - 채팅 거품 자리는 지금 계산(가운데 맞춤·`trailing`) 그대로 정한다.
  - 그 왼쪽에 `leading`만큼 붙인다. 그 결과 `bubble.minX - leading >= safe.minX`가 될 때만 늘린다.
  - 모자라면 `leading`을 0으로 두고 **덮기 모드**로 판정한다.
  - 판정 결과(늘림 / 덮기)는 `PetPlacement`가 하나만 가진다.
- `PetController`
  - `drawerOpen`, `drawerWidth = 290`을 둔다.
  - `placePet(at:)`에서 열려 있고 채팅이 펼쳐져 있으면 `leading`을 넘긴다.
  - 늘리고 줄이는 움직임은 기존 `bubbleMotion`의 retarget을 쓴다. 시간은 0.25초이고, 동작 줄이기면 즉시 바꾼다.
  - 채팅 영역의 화면 x는 바뀌지 않아야 한다(REQ-TD-02 AC-01). 넓어지는 동안 `ChatWidthSlide` 덮개는 쓰지 않는다. 채팅 내용은 그 자리에 있고 칸만 왼쪽에서 드러난다.
- `PetView`(또는 채팅을 담는 기존 보기)
  - 늘림 모드에서는 칸을 채팅 왼쪽 290pt에 두고, 채팅 보기는 그 오른쪽에 둔다.
  - 덮기 모드에서는 칸을 채팅 위 왼쪽에 겹치고 채팅에 어둡게 하는 막을 씌운다. 막을 누르면 닫힌다.
- 오른쪽 웹 칸 `paneSplit`의 `available`에서 늘림 모드의 `leading`을 뺀다. 두 칸이 같이 들어가지 않으면 할 일 칸이 덮기 모드로 바뀐다. 웹 칸이 줄어들지 않는다(REQ-TD-02 AC-04).
- 열림 여부는 `LocalSettings`에 새 선택 필드(예: `todoDrawerOpen: Bool?`)로 둔다. 바뀔 때 저장한다(REQ-TD-06). 허브 `MemberState`에는 넣지 않는다.

### 5.4 알약

- `IslandModel.Input`에 `drawerOpen: Bool`을 더한다.
- 열려 있으면 다음처럼 한다.
  - 사장 차례 칸 글자 끝에 " · 닫기 ‹"를 붙인다.
  - 사장 차례 칸이 없으면 "닫기 ‹" 칸을 만든다.
  - `Snapshot`에 `drawerOpen`을 실어 테두리를 강조색으로 그린다.
- 사장 차례 칸의 `action`은 새 `Action.drawer`로 바꾼다. 빈 알약도 누르면 `Action.drawer`를 낸다.
  - `.question` 경우는 아일랜드의 잠깐 늘어남 알림(새 `asked`) 클릭에서 계속 쓴다. 알림 중인 그 질문으로 가는 지금 동작을 유지한다.
  - 지금 사장 차례 칸 클릭 경로("가장 오래된 질문으로")는 칸의 맨 위 답 요청 카드로 옮긴다. 이 경로는 **교체**다.
- 올리기 미리보기(`hoverQuestion`)는 그대로 둔다.

### 5.5 마감 요청

- `ConversationController`(또는 `GateClient` 사용처)는 `deadlines` 요청을 보내고 `deadlines_status`를 받아 모델에 넣는다.
- 보내는 때는 칸이 열릴 때, 열려 있는 동안 5분마다, 다시 연결된 직후(열려 있을 때만)다(NFR-TD-03).
- 마감 목록은 메모리에만 두고 `cache/`에 저장하지 않는다.

## 6. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| 사장 차례 칸 클릭 → 가장 오래된 질문 (`IslandModel` 사장 칸 `action`) | 교체 | `Action.drawer`로 바꾸고, 같은 이동은 칸 맨 위 답 요청 카드가 맡는다. 옛 할당 코드는 같은 변경에서 지운다 |
| 아일랜드 잠깐 알림의 `.question` 클릭 | 유지 | 새 질문 알림 중 클릭은 그 질문으로 이동 |
| `notices(_:)` | 유지(재사용) | 칸이 같은 계산을 읽는다. 새 원본을 만들지 않는다 |
| `PetPlacement`·`paneSplit` | 유지 + 확장 | `leading` 인자 추가. 기본 0이면 지금과 같은 결과(회귀 시험) |
| team-kit `deadline_watch` 쓰기·Slack 보고 | 유지 | 바꾸지 않는다 |
| 문 `TeamKit` 실행기 | 유지 | 고정 명령 표가 연결 전용이라 섞지 않는다. 같은 실행 규칙을 `Deadlines`에 둔다. 공통 함수로 뽑을지는 구현 자유이며, 뽑으면 연결 시험(AT-HC 회귀)이 그대로 통과해야 한다 |

## 7. 대안

- **기각: 문이 장부 JSON을 직접 읽기.** 장부 모양·닫힘 규칙·심볼릭 링크 검사가 문에도 생겨 두 번째 해석기가 된다. team-kit 명령으로 읽으면 뜻의 원본은 하나다.
- **기각: 문이 마감을 기록장에 넣어 동기화하기.** 두 번째 원본이 된다.
- **기각: 앱이 주기적으로 항상 받기.** 칸이 닫혀 있으면 쓸모가 없고 서버에서 실행만 늘어난다.
- **채택: 요청-응답(`deadlines`)으로 열 때와 5분마다 받기.** `connections`와 같은 형태다.

## 8. 위험

- 위험도는 **일반**이다. 근거는 다음과 같다.
  - 읽기 전용 기능 추가다. 저장 형식, 권한, 비밀값 변경이 없다.
  - 통신 규격에는 새 종류만 더한다(되돌릴 수 있음).
- 단, TASK-05 서버 적용은 운영 시설 교체와 게이트웨이 재시작이므로 **고위험**이다. 롤백을 먼저 기록한다.
- 필요 증거 수준
  - 앱·문·team-kit: 2(가짜 홈·가짜 명령·가짜 모델).
  - 서버 적용: 3(운영 공항에서 `hermes-deadlines list --json` 실행과 문 응답).
  - 사장 확인: 4.
- 남는 위험
  - 시간대 가정(5.1).
  - 운영 장부의 실제 `source` 형태는 아직 모른다. 링크가 아니면 직원 방으로 가는 것으로 처리한다.
  - HEJO-CONN-MANAGE와 `gate/server.py`·`AppDelegate.swift`·통신 규격 파일이 겹칠 수 있다(tasks.md 동시 수정 절).
