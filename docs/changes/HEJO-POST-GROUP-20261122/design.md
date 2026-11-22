# HEJO-POST-GROUP 설계 (1판 · 2026-11-22)

명세 [spec.md](spec.md). 기준 커밋 `84e64ac3`(줄 번호는 3dc155dd 기준, 그 뒤 변경은 다른 작업 문서뿐).

## 1. 현재 흐름 [확인]
- `app/Sources/ConversationView.swift:899` `threadContent`: `replies = messages.dropFirst()`, 접힘이면 `shown`은 마지막 답글과 버튼 답글만(`:904`), "이전 답글 N개" 더미(`:912`) 뒤 `for message in shown {answer += postPieces(...)}`(`:916`). 끼어듦 줄(`:917`), 작업 중이면 입력 중 직원마다 `TypingBubbleView`(`:936`)와 `WorkingControlRow`(`:939`).
- `:963` `postPieces`: 직원 "생각 중" 글은 `TypingBubbleView` 조각 하나만 돌려줌(`:965`). 그 밖은 `.post(Post)` + 달력·파일·체크리스트·버튼 조각. 버튼 나눔이면 앞부분·뒷부분 두 글(`:1074-1080`, 뒷부분 `continuation=true`).
- `app/Sources/NativeThreadCard.swift:30` `Post.continuation`: 얼굴·이름·시간을 그리지 않고 글을 바로 위에 붙임(배치 `:271-287`, 그리기 `:768`). `Post.textHelp`는 글 칸 툴팁(`:630`).

## 2. 바뀐 뒤
책임 자리는 그대로 `ConversationView.threadContent`(묶을지 판단)와 `postPieces`(판단을 받아 글·생각 중 조각에 적용). `NativeThreadCard`는 바꾸지 않는다.

1. `threadContent`가 `shown`을 돌 때, 각 메시지의 바로 앞 답글(spec 용어: `replies`에서의 바로 앞 원소, 화면에 보이는 경우만)과 같은 직원인지 계산해 `postPieces`에 넘긴다(인자 이름은 구현 자유). 더미 뒤 첫 글은 바로 앞 답글이 숨었으므로 자연히 묶이지 않는다.
2. `postPieces`가 묶음 표시를 받으면:
   - 생각 중 글이면 빈 조각 목록을 돌려준다.
   - 일반 글이면 `Post.continuation = true`, `textHelp`가 nil이면 `Post.time`을 넣는다. 사장 글(`mine`)에는 적용하지 않는다.
   - 버튼 나눔 경로(`extras:false`로 앞부분을 다시 부름)에도 같은 표시를 넘겨 앞부분이 묶이게 한다.
3. 입력 중 표시(`:935-937`): 끼어듦 줄이 없고 `shown.last`가 직원 글이며 그 `speaker == person`이면 그 사람의 `TypingBubbleView`를 만들지 않는다.

## 3. 유지할 계약
문·기록 프레임, `ConversationMessage`, `NativeThreadCard.Piece`·`Post` 필드, 스레드 첫 글 표시(`CardTests.swift:120` 생각 중 top 기대 포함), 작업 줄, 접힘 규칙, 사장 말풍선.

## 4. 기존 경로 판정
- `postPieces`의 생각 중 조각, 입력 중 `TypingBubbleView` 생성: **유지**(조건만 추가).
- `Post.continuation`: **유지**·재사용(새 필드 없음).
- 버튼 나눔 뒷부분 `continuation`: **유지**.
철거할 구 경로 없음.

## 5. 대안
- (기각) `NativeThreadCard` 배치 단계에서 앞 글 `speaker` 이름을 비교해 묶기: 이름은 표시 문자열이라 같은 이름 다른 직원을 묶을 수 있고, 접힘·타임라인 인접 정보가 없다.
- (기각) 문에서 파일을 최종 답에 합치기: brainstorm.md 대안 2.

## 6. 변경 성격
의미 변경(표시). 비교: 수락 시험 AT-PG-*의 조각 검사 + 기존 앱 시험 전부.
