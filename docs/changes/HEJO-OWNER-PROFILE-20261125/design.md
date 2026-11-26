# HEJO-OWNER-PROFILE 설계 (2판, 2026-11-25, 계획 검증 1회차 반영)

명세: [spec.md](spec.md). 행 번호는 기준 커밋 `github/main` `c22e677` 기준이며 착수 시 tip이 바뀌면 같은 함수를 따라간다.

## 1. 칸과 원본
| 정보 | 원본(유일) | 쓰기 주체 | 수명 |
|---|---|---|---|
| 사장 이름 | `<HOME>/shared/hejo/owner.json` `{"v":1,"name":"…"}` | 문(`PUT /v1/owner`) | 영구. 갱신·제거가 건드리지 않음 |
| 사장 사진 | `<HOME>/shared/hejo/pictures/owner.png` | 문(`/v1/pictures/owner/owner`) | 영구 |
| 앱 화면의 사장 프로필 | 사본 없음. welcome·roster의 `owner`를 메모리에만 둔다 | — | 연결 동안 |

- 공용 창고 칸(ARCHITECTURE 45행)의 "시설 런타임(문 단독 쓰기)"에 맞는다. 새 칸 없음. `<HOME>`은 그 회원의 문이 쓰는 `get_hermes_home()`이라 허브 회원마다 따로다.
- 앱의 로컬 설정(`hejo-local.json`)·허브 회원 설정에 이름을 복사하지 않는다(두 번째 원본 금지).

## 2. 문(gate) 설계
### 2.1 저장
- 새 모듈 `gate/owner.py`(사장 프로필 하나의 책임): `read(home) -> {"name": str|None}`, `write_name(home, name)`, `valid_name(value) -> str|None|ValueError`, `profile(home) -> {"name","avatar"}`.
  - 읽기: 파일·폴더(`shared/hejo`, `shared`)가 심볼릭 링크면, 또는 JSON·형식 위반이면 `name=None`(오류 기록만, 값 내용은 기록하지 않음).
  - 쓰기: `Pictures.put`과 같은 방식(같은 폴더 임시 파일 → fsync → `os.replace`, 파일 0600). `shared/hejo`가 없으면 `mkdir(mode=0o700)`(기록장 `journal.py:36`·첨부 `files.py:37`과 같은 값), 있으면 권한을 바꾸지 않는다(다른 기능이 함께 쓰는 폴더라 chmod하지 않음, spec REQ-OP-01.AC-01). 이름 지우기는 `{"v":1,"name":null}`을 쓴다.
  - `avatar`: `Pictures.path("owner","owner")`가 파일이면 `/v1/pictures/owner/owner?v=<st_mtime_ns>`, 아니면 None.
- `gate/pictures.py` `Pictures.path`: `kind=="owner"`는 identifier가 `owner`일 때만 `shared/hejo/pictures/owner.png`(room과 같은 심볼릭 링크 검사, 0700/0600). 그 밖의 id는 `KeyError`.
- `gate/server.py` `_picture`: `owner` 종류 허용. 성공한 PUT·DELETE 뒤 `roster`(`ref:"owner"`)를 모든 연결에 보낸다. 직원 사진 변경 roster에도 `owner`를 넣는다.

### 2.2 HTTP·wire
- `PUT /v1/owner` 본문 `{"name": string|null}` → 200 `{"ok":true,"owner":profile}` / 400 `invalid_name` / 401. `GET /v1/owner` → 200 `{"ok":true,"owner":profile}`. 인증은 사진 경로와 같은 `await self.http_auth(request)`(`server.py:451`).
- welcome(`server.py:671`)과 모든 roster 프레임(직원 사진 알림 `server.py:500`, 앱의 명단 요청 응답 `:709`, 새 사장 프로필 알림)에 `"owner": profile`. 스키마 `schemas/hejo-wire-v1.json`의 `welcome`·`roster` 정의에 선택 속성 `owner`(`{"name": string|null(1~20자), "avatar": string|null}`)를 더한다. `schemas/pictures.md`에 `owner` 종류를 적는다.

### 2.3 이름을 쓰는 곳(표시 이름 함수 하나)
- `adapter.owner_label(default)`: 이름이 있으면 이름, 없으면 `default`. 호출마다 `owner.read`를 한다(파일 하나, 글 보낼 때만; 캐시 없음 → 다른 기기에서 바꾼 값도 바로 반영).
- `context.conversation_lines(messages, names, *, owner="나", …)`: `owner` 인자를 받아 25행의 `"나"`를 대신한다. 호출부 `adapter.py:305`, `:772`, `rooms.py:103`은 `owner_label("나")`를 넘긴다.
- `telegram.py:431`, `discord.py:507`: `owner_label("사장")`.
- `buttons.py:6` `decision(button, owner="나")`: 호출부(`adapter.py:684`)가 `owner_label("나")`를 넘긴다.
- `adapter.py:762` `build_source(..., user_name=name)`: 이름이 있을 때만. Hermes는 이 값을 `_format_untrusted_prompt_value`로 감싸 `**User:**` 줄에 넣는다(본체 `gateway/session.py:430`, 읽기만 확인). 세션 키에는 쓰지 않는다.

## 3. 앱 설계
### 3.1 프로필 받기
- `ConversationModel`에 `owner: OwnerProfile?`(`name: String?`, `avatar: String?`). welcome·roster 처리(`ConversationModel.swift:682`)에서 `owner`가 있으면 갱신한다. 없을 때는 welcome이면 `nil`(옛 문), roster면 그대로 둔다(spec REQ-OP-02.AC-04). `ownerName`(표시 이름) = `owner?.name ?? "사장"`.
- `ConversationController.ownerAvatar() -> ProfileAvatar`: 색은 `PictureCodec.color(name: ownerName, hex: nil)`, 사진은 기존 `pictures.image(owner?.avatar)`(이미 welcome·roster 때 `pictures.invalidate()`가 돈다, `ConversationController.swift:546`).

### 3.2 저장 요청
- `GateHTTP`에 `setOwnerName(_:)`(PUT `/v1/owner`)을 더한다. 사진은 기존 `changePicture(kind:"owner", id:"owner", …)`(PictureCodec PNG 변환·512 KiB·오류 문구 재사용).
- 저장 응답의 `owner`를 바로 모델에 반영하고, 다른 기기는 roster로 받는다. 사진 주소는 `?v=<mtime_ns>`가 바뀌므로 새 사진이 이전 캐시 이미지와 구별된다. 앱 사진 캐시는 주소 기준이고 welcome·roster 때 비운다(`Pictures.swift:68`, `:74`, `ConversationController.swift:546`). 저장한 앱은 roster를 받기 전에도 응답 주소가 바뀌어 새 사진을 받는다. 이전 이미지가 남으면 이 캐시 자리에서 고친다(새 캐시 만들지 않음).

### 3.3 채팅 그리기 (`NativeThreadCard.swift`, `ConversationView.swift`, `ChatStyle.swift`)
- 말풍선 모양 상수 하나: `ChatMetrics.bubbleCorner = 12`, `ChatMetrics.bubbleInset = (12, 8)`(지금 직원 말풍선 값). 내 말풍선(지금 반지름 16, `NativeThreadCard.swift:793`)도 이 값을 쓴다.
- 직원 글: `Post.conversational` 조건(`ConversationView.swift:1286`)과 `ThreadAppearance.isConversational`(`ChatStyle.swift:158`)을 **제거**하고 직원 글은 항상 말풍선 배치(`NativeThreadCard.swift:250` 분기의 bubble 경로). 첫 글(`postPieces(…, conversational:false)` 호출들, `:1025`·`:1147`·`:1363`·`:1364`)도 같다. 표(TextKit 표, 폭 100%)와 코드 상자는 이미 받은 폭에서 줄바꿈하므로(`TextLayout.swift:3-6`, `:124`) 말풍선 안쪽 폭을 넘기면 된다. 스트리밍 높이 기억(`streamHeights`)은 말풍선 안쪽 폭 기준으로 그대로 쓴다. 첨부·버튼·칩·묶음 등 다른 Piece는 지금처럼 글 아래 별도 조각이다.
- 내 글: `Post`에 `avatar`(이미 있음)·`speaker`(표시 이름)·`continuation`을 쓴다. 배치는 직원 글의 좌우 대칭: 오른쪽 끝에 34pt 사진(`item.aside`의 역할을 사진으로 바꾸고 말풍선은 `item.bubble`로 옮김), 그 왼쪽 9pt에 머리줄(오른쪽 정렬, 이름 굵게 14pt + 6pt + 시간 11pt, 시간이 왼쪽 끝), 머리줄 아래 `nameBodyGap` 뒤 말풍선(오른쪽 끝이 사진 왼쪽 9pt). 이어 쓴 글이면 사진·머리줄 없이 말풍선만, 오른쪽 끝 정렬은 같다. 말풍선 아래 시간 줄(`item.time` 아래 배치)은 없앤다. "답이 중단됐어요"(`item.fold`)는 말풍선 아래 유지.
- 이어 쓰기 규칙(`ConversationView.swift:1160`): 사장 글도 바로 앞 보인 글이 사장 글이면 `continuation=true`.
- 이름·색: 내 머리줄 이름 색은 `.labelColor`(지금 `nameColor: mine ? .labelColor`), 시간은 `c.quiet`.
- 우클릭: 내 사진·머리줄 영역 우클릭 메뉴에 "내 프로필…"(기존 직원 사진 메뉴 방식, `ConversationView.swift:274` 부근).
- `AppearancePreview.swift`: 내 말풍선 위에 같은 머리줄, 두 말풍선 같은 반지름.

### 3.4 내 프로필 설정 화면
- 별도 창을 만들지 않고 기존 설정 창(`PetSettingsWindow`, `AppDelegate.showOptions`)에 "내 프로필" 영역을 더한다(AppKit). 내용은 시안 [mock-profile.png](mock-profile.png)와 같고 창 틀만 다르다. 우클릭 "내 프로필…"은 설정 창을 열고 이 영역으로 스크롤·초점 이동한다.
- 이름 입력 검증은 문과 같은 규칙을 앱에서 미리 보여 주되(20자 넘으면 저장 버튼 비활성), 최종 판정은 문이다.

### 3.5 "나" 표기
- `ConversationView.swift:878`(검색 화자), `ThreadTools.swift:46`(복사 글), `WorkspaceViews.swift:45`: `model.ownerName`.

## 4. 기존 경로 판정
| 대상 | 판정 | 내용 |
|---|---|---|
| `ThreadAppearance.isConversational`, `Post.conversational`, `postPieces(conversational:)` 인자 | 제거 | 모든 직원 글이 말풍선이 되어 조건이 필요 없다. 같은 변경에서 호출부·시험 기대값을 함께 고친다 |
| 내 말풍선 반지름 16·말풍선 아래 시간 줄 | 교체 | 공통 상수·머리줄로 |
| 사진 경로 `employee`·`room` | 유지 | `owner` 종류 추가만 |
| roster 프레임 | 유지(확장) | `owner` 속성 추가 |
| `conversation_lines`의 `"나"`, 텔레그램·디스코드 `'사장'`, 버튼 `"나"` | 교체 | 표시 이름 함수 하나로. 기본값은 지금 문자열 |
| 허브 회원 설정·펫 이름 | 유지 | 손대지 않음 |
| `HomeOwnerView` | 유지 | 받는 직원 표시라 범위 밖 |

이중 경로 없음.

## 5. 대안
- 이름을 허브 회원 설정에 두기: 문·텔레그램·직원이 못 읽어 기각.
- 이름을 `owner/policy.yaml`(사장 지시서)에 두기: 규칙 칸이고 사장이 손으로 쓰는 파일이라 앱 쓰기 주체와 섞여 기각.
- 사장 프로필 전용 wire 프레임 새로 만들기: roster가 이미 "사람 목록 바뀜" 알림이라 확장으로 충분해 기각.
- 별도 "내 프로필" 창: 설정 창이 이미 사장 설정 자리라 영역 추가로 충분해 기각(시안의 창 틀은 참고용).

## 6. 위험·실패
- 위험도 일반(공통 4절): 여러 모듈 기능 추가, wire 확장은 선택 속성이라 되돌릴 수 있다. 저장 파일 하나 추가(작은 JSON, 지워도 "설정 안 됨").
- 이름은 직원 프롬프트에 들어가는 사용자 입력이다. 길이 20자·제어 문자 금지로 제한하고, Hermes가 신뢰 불가 값으로 감싼다. 텔레그램·디스코드 표기도 같은 값.
- 되돌리기: 앱·문을 이전 판으로 되돌리면 `owner.json`·`owner.png`는 읽히지 않고 남는다(무해).
- 증거 수준: 3(임시 `HERMES_HOME`의 실제 문 loopback HTTP/WS 시험, 실제 앱 코드로 배치 계산·그리기 하네스). 실물(4)은 서버 설치가 범위 밖이라 요구하지 않는다.
