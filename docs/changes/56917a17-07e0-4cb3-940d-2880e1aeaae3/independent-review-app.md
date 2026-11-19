# 비설계자 검토 결과: 앱·배포 도구 (2026-11-20)

- 검토 범위: `app/Sources/`, `app/Tests/`, `install/hejo-ship`. TASK-20(앱 쪽), TASK-24(앱 `MemberState`), TASK-25(앱 스레드 카드), TASK-33.
- 서버(gate·hub·install)와 team-kit은 다른 검토자 몫이라 보지 않았다. 앱과 맞닿는 계약을 확인하려고 `hub/state.py`, `hub/server.py`, `gate/adapter.py`, `gate/rooms.py`의 해당 부분만 읽었다.
- 대상 트리: `main` `7df856b`. 저장소는 고치지 않았고 이 파일 하나만 만들었다.
- 확인 방법: 코드 읽기. IR-02~05는 저장소 밖 임시 폴더에서 `app/Sources/*.swift`(AppMain 제외)와 탐침 코드를 함께 컴파일해 임시 `LocalStore` 폴더와 가짜 허브로 실행했다(실제 서버·네트워크·`~/.hermes`·실제 다운로드 폴더 접근 없음, 탐침 파일은 실행 뒤 지움). IR-01과 IR-06은 코드 읽기만 했다.
- 요약: 차단 1건, 비차단 5건.

## 지적

### IR-01 · 차단 · TASK-25 — 단체방에서 "중지"·"되돌리기"·답 버튼·체크리스트 답이 일하는 직원이 아니라 대표 직원에게 간다

- 파일:줄
  - `app/Sources/ConversationController.swift:59-62` (`sendFields`: 방이면 `employee`를 항상 `room.lead`로 채움)
  - `app/Sources/ConversationController.swift:189-201` (`sendText`·`stop`: `/stop`을 `sendFields(key)`로 보냄)
  - `app/Sources/ConversationView.swift:857` (되돌리기), `:970` (체크리스트 답), `:992` (기본 답 낱말)
  - 받는 쪽: `gate/adapter.py:686` `targets = recipients(frame["text"], room, …)`, `gate/rooms.py:28` `return called or [room['lead']]`
- 실패 시나리오
  1. 대표가 A인 단체방에서 사장이 "@B 이 파일 정리해 줘"를 보낸다. B가 일하고, 그 스레드에 작업 중 줄과 "중지" 버튼이 보인다(`working(key)`는 B의 typing으로 참).
  2. 사장이 "중지"를 누른다. 앱은 `{"type":"send","text":"/stop","employee":<A>,"room":<방>}`을 보낸다. 글에 @가 없으므로 문은 대표 A에게만 넘긴다.
  3. 결과: B는 계속 일한다. 앱은 `stopped`에 넣고 "중지를 요청했어요"와 "되돌리기"를 보인다. "되돌리기" 글도 @가 없어 A에게 간다. A는 자기가 하지 않은 작업을 되돌리라는 요청을 받는다.
  4. 같은 경로로, B가 올린 승인 요청의 기본 답 낱말("승인" 등)과 체크리스트 답("선택: …")도 A에게 간다. 문 버튼 클릭(`gate/adapter.py:656`)도 `receive`를 거쳐 같은 `recipients` 규칙을 타므로 대표에게 간다(문 쪽 검토자 확인 필요).
- 근거
  - `sendFields`: `if let room=model.groups[key.employee] {return ["employee":room.lead ?? room.members[0],"room":room.id]}`
  - 앱은 누가 쓰는 중인지 안다(`canInterrupt`가 `model.typingPeople[key]`를 읽음, `:157-160`). 하지만 중지 대상에는 쓰지 않는다.
  - spec REQ-HF-27 "중지를 누르면 그 스레드에 `/stop`을 보내고", design 297행 "그 스레드 세션에 들어간다". 단체방에서는 세션이 받는 직원별(`source.profile = target`, `gate/adapter.py:715`)이다.
  - 시험은 1:1만 본다: `app/Tests/ThreadToolsTests.swift:103`(alpha DM), `gate/tests/test_threads.py:202`(`"employee":"alpha"`, 방 없음).
- 확인하지 못한 것: Hermes 본체가 대표 세션에 들어온 `/stop`으로 다른 직원 세션까지 멈추는지는 실행으로 확인하지 않았다. 문 코드상 `/stop`을 받는 것은 대표 한 명뿐이다.
- 차단으로 본 이유: 중지는 잘못 가는 작업을 멈추는 안전 장치인데, 멈추지 않으면서 화면은 요청됐다고 보여 준다.

### IR-02 · 비차단(우선 수정 권고) · TASK-24 — 허브 상태를 받기 전에 "처음 보는 방" 읽음을 심어, 다른 Mac의 안 읽음을 모두 읽음으로 올린다

- 파일:줄
  - `app/Sources/ConversationModel.swift:380-387` (`seedUnseenRooms`: 로컬 복제본에 `read:<방>`이 없으면 그 방 최대 seq를 읽음으로 씀), 호출 `:319`, `:324`
  - `app/Sources/AppDelegate.swift:132`, `:202-206` (자동 로그인: `client.resume()` 뒤 `syncMemberSettings`가 `bearer`를 0.5초 간격으로 기다리고 `hub.me`를 받은 다음에야 `join`·`configure`)
  - `app/Sources/MemberState.swift:153-167` (`set`은 로컬 `items`와만 비교), `hub/state.py:48-53` (읽음은 큰 값이 이김)
- 실패 시나리오
  1. Mac A에서 새 직원(또는 새 단체방) R에 글이 30개 쌓였고 사장은 10번까지 읽었다. 허브 `read:R = 10`.
  2. 그동안 꺼져 있던 Mac B를 켠다. B의 로컬 복제본에는 `read:R`이 없다.
  3. 문 재생이 끝나면(`sync_done`, `more:false`) `seedUnseenRooms`가 `read:R = 30`을 대기열에 넣는다. 이때 회원 상태는 아직 허브에 연결되지 않았다.
  4. 연결되면 대기열이 올라가고 허브는 큰 값을 받아 `read:R = 30`이 된다. 두 Mac 모두에서 11~30번 안 읽음이 사라진다.
  - 새 Mac 첫 로그인에서도 허브 첫 GET이 실패하거나 늦으면 모든 방에 같은 일이 생긴다.
- 근거(탐침 실행 결과)
  ```
  P1 pending before hub fetch: 30
  P1 hub read:beta after sync: 30 unread(beta) = 0
  P1 control hub read:beta: 10 unread(beta) = 20      # 허브 상태를 먼저 받은 대조군
  ```
- REQ-HF-36.AC-01 "처음 보는 방은 그 순간까지 읽음"은 회원 기준이어야 하는데, 코드는 이 Mac의 오래된 복제본 기준으로 판정한다. `AT-HF-74`에는 "받기 전 심기" 순서를 잡는 단언이 없다.

### IR-03 · 비차단 · TASK-24 — 허브 rev가 로컬보다 작아지면 서버 상태를 영영 받지 않고, 대기 요청이 쉬지 않고 돈다

- 파일:줄: `app/Sources/MemberState.swift:172` (`remote.rev > document.rev ? remote : document`), `:111-127` (대기 루프, 성공 경로에 쉬는 시간 없음), `hub/server.py:165-166` (`rev`가 다르면 바로 응답)
- 실패 시나리오: 허브 회원 상태 파일을 백업으로 되돌리거나 지워서(또는 같은 주소·같은 아이디로 회원을 다시 만들어) 서버 rev가 3, 로컬 rev가 500이 된다.
  1. 앱은 서버 문서를 무시하고 옛 로컬 값을 계속 보인다.
  2. 이 Mac에서 바꾼 값은 PATCH가 성공하면 대기열에서 빠지지만 응답(rev 4)도 무시돼 화면에서 사라진다. 서버에는 저장돼 있다.
  3. `wait=500` 요청은 서버가 바로 답하고 앱은 바로 다시 건다. 연결된 Mac마다 허브로 요청이 끊임없이 간다.
- 근거(탐침 실행 결과)
  ```
  P2 after hub reset: local rev 500 pin:alpha 1 pin:beta nil
  P2 after push: hub mute:alpha = 1 local mute:alpha = nil pending 0
  P2 wait requests in 0.3s while local rev > hub rev: 49650   # 가짜 허브(네트워크 없음) 기준 횟수
  ```
- 복제본 이름이 `허브 주소/회원 아이디`뿐이라(`MemberState.swift:66`) 서버 쪽 세대가 바뀐 것을 구분할 값이 없다.

### IR-04 · 비차단 · TASK-24 — 미래 시각이 찍힌 항목은 다른 Mac에서 바꿀 수 없고, 실패도 알리지 않는다

- 파일:줄: `app/Sources/MemberState.swift:44-48`, `:153-160` (`set`: 지면 조용히 버림), `hub/state.py:36` (`at`은 0 이상·유한만 검사, 상한 없음), `app/Sources/ConversationModel.swift:284` (숨긴 방에 새 글이 오면 `restore`)
- 실패 시나리오: Mac A의 시계가 하루 앞서 있을 때 방을 "목록에서 빼기" 하면 `hide:R`의 `at`이 내일이다. Mac B에서 그 방에 새 글이 와도 `restore`(지금 시각)가 져서 방이 목록에 돌아오지 않는다. 고정·알림 끄기·구획 편집·"화면 배치 동기화…"(`makeLayoutStandard`의 `set`)도 그 키에서는 아무 일 없이 끝나고, 동기화는 "저장됨"으로 안내된다.
- 근거(탐침 실행 결과): `P3 restore after future-stamped hide: pending 0 hide:alpha = 1`
- REQ-HF-21.AC-06 "숨긴 직원에게 새 글이 오면 목록에 다시 나타난다"가 이 경우 깨진다.

### IR-05 · 비차단 · TASK-20·24 — 구획 목록 전체가 한 항목이라, 오래된 복제본에서 접힘만 눌러도 다른 Mac의 구획 추가·이름·사진이 사라진다

- 파일:줄: `app/Sources/ConversationModel.swift:168-178` (`saveLayout`·`toggleSection`: `layout:sections` 배열 전체를 다시 씀), `:112` (`layout:home`도 같음)
- 실패 시나리오: Mac A에서 구획을 추가하고 이름을 붙인다. Mac B가 그 변경을 받기 전(오프라인이거나, 실행 직후 회원 상태 연결 전 — IR-02와 같은 틈)에 사장이 구획 머리줄을 눌러 접힘만 바꾼다. B는 옛 배열에 접힘만 바꿔 더 늦은 시각으로 쓰므로 이긴다. A의 새 구획과 이름이 없어지고, 그 구획에 넣은 방은 첫 구획으로 돌아가며, 구획 사진 파일은 문에 남는다.
- 근거(탐침 실행 결과)
  ```
  P4 hub sections after A: [… {"id":"5","open":false,"name":"중요"}]
  P4 hub sections after stale B toggle: [{"id":"1","open":true,…},{"id":"2",…},{"id":"3",…}]
  P4 A now sees sections: ["1:", "2:", "3:"]
  ```
- "항목별 LWW" 자체는 설계대로다. 지적은 자주 누르는 접힘 상태가 구획 정의와 한 값에 묶여 있어 덮어쓰기가 쉽게 일어난다는 점이다.

### IR-06 · 비차단 · TASK-33 — 기억해 둔 릴리스가 낡으면 "업데이트 x.y.z 설치…"가 계속 실패한다

- 파일:줄: `app/Sources/AppUpdate.swift:63-65` (`knownRelease`가 있으면 다시 조회하지 않고 설치 시작), `:78-82` (조회 성공 때만 갱신), `app/Sources/UpdateUserDriver.swift:83`, `:87-96` (피드는 `releases/latest`, 버전이 다르면 거절)
- 실패 시나리오: 앱이 0.2.1을 알린 뒤 사장이 "나중에"를 누른다. 그 뒤 0.2.2가 공개된다. 메뉴 "업데이트 0.2.1 설치…"를 누르면 Sparkle이 최신 피드(0.2.2)를 받고 `validate`가 버전 불일치로 거절한다. `knownRelease`는 그대로라 누를 때마다 실패한다. "업데이트 알림 받기"를 껐거나 "오늘 다시 보지 않음"이면 자동 조회가 없어 앱을 다시 켤 때까지 풀리지 않는다.
- 근거: 실패 경로(`report`·`didFinishUpdateCycleFor`)에 `knownRelease`를 지우거나 다시 조회하는 코드가 없다. `app/Tests/UpdateTests.swift`는 캐시된 릴리스로 설치 시작까지만 본다.
- 확인하지 못한 것: 거절 때 사용자에게 보이는 창이 앱 안내인지 Sparkle 기본 "업데이트 없음" 창인지는 실행하지 않아 모른다. 잘못된 설치로 이어지지는 않는다(닫힌 쪽으로 실패).

## 확인했지만 문제없는 항목

- TASK-33 다른 저장소·태그 수락: `UpdateRelease.decode`가 저장소 형식, `v` 태그, 초안·사전 공개 제외, 자산 이름·개수·상태·크기, 내려받기 주소 일치를 검사하고, `allows`가 서명된 피드의 주소·버전·크기·설치 종류·델타 없음을 다시 맞춘다(`UpdateRelease.swift:21-46`). 다른 저장소 주소를 넣은 피드는 거절된다.
- TASK-33 서명: `Info.plist`에 `SUPublicEDKey`, `SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`이 있고, 고정한 Sparkle 2.10.0 바이너리에 그 키 이름이 있는 것을 확인했다. `hejo-ship bundle()`은 두 설정이 없으면 준비를 거절한다.
- TASK-33 하위 버전: 앱은 릴리스 버전이 현재보다 클 때만 진행하고(`AppUpdate.swift:78`), `hejo-ship prepare`는 이전 공개본보다 버전·빌드 번호가 커야 한다. 옛 서명 피드 재전송은 버전 불일치로 거절된다.
- TASK-33 동의 없는 설치: 자동 확인·자동 내려받기가 꺼져 있고, `prepare`는 `shouldProceedWithUpdate`가 검증한 버전이 있을 때만 설치를 허락한다(`UpdateUserDriver.swift:67-70`). 검증을 못 거치면 설치하지 않는다.
- TASK-33 조회 요청: 리다이렉트 거절, 쿠키·캐시 없음, 인증 머리 없음, 1 MiB 상한(`UpdateRelease.swift:62-92`).
- TASK-33 `hejo-ship`: 실패 때 도구 출력을 내보내지 않음, 깨끗한 트리·공개본 트리·`BuildInfo` 일치, 키체인 공개 키 일치, 압축 풀어 재검증, `publish`는 승인 커밋·원격 `main` 일치·기존 태그와 초안 없음·올린 자산 크기와 지문 확인 뒤 공개. Sparkle 묶음은 SHA-256 고정(`fetch_sparkle.sh`).
- TASK-24 스냅숏 계약: 허브 GET(rev 다름)과 PATCH가 전체 문서를 돌려주므로 `accept`가 문서를 통째로 바꾸는 것과 맞는다. 보내는 중 다시 바꾼 값은 대기열에 남는다(`MemberState.swift:171`, `AT-HF-74`).
- TASK-24 회원 분리: 복제본·대기열이 `허브/회원`별이고, 주소가 바뀌면 `LocalStore.select`가 `stateAccount`를 비운다. `join`·`disconnect`가 세대를 올려 진행 중이던 응답을 버린다. 로그아웃은 가져오기·보내기 클로저를 지운다.
- TASK-24 저장: `hejo-local.json`은 임시 파일 뒤 이름 바꾸기, 0600. 토큰·비밀번호는 넣지 않는다. 처음 옮기기는 한 번의 저장으로 끝난다(`AT-HF-74` 재시작·실패 단언 확인).
- TASK-25 삭제 대상: 삭제는 카드의 `(방, 스레드)` 키로 확인과 요청을 묶는다. 두 번 누르는 사이 목록이 바뀌어 다른 카드를 눌러도 그 카드의 확인부터 다시 시작한다(`ConversationController.swift:181-188`). 로컬 캐시 지우기(`LocalStore.redacting`)와 모델 지우기도 같은 키를 쓴다.
- TASK-25 분기·링크: 분기는 6초 중복 방지와 `client_msg_id`를 쓴다. `hejo://` 링크는 호스트·항목 수·UUID를 검사하고 스레드 선택만 한다(`ThreadTools.swift:21-27`).
- TASK-25 체크 상태: `check:` 키는 글 본문 해시를 포함해, 글이 고쳐지면 옛 체크가 새 글에 붙지 않는다.
- TASK-20 사진: 주소는 `/v1/pictures/{employee|room}/<id>` 상대 경로만 받고 문 주소로만 인증 요청을 보낸다. 리다이렉트 거절, 캐시는 주소·자격·연결 세대별 메모리만 쓴다. 사진 바꾸기는 고르는 동안 주소·토큰·연결이 바뀌면 버린다. PNG 256×256, 512 KiB 상한.
- 자격 증명 노출: `app/Sources`에 `print`·`NSLog`·`os_log`가 없다. 토큰은 키체인에 표준 입력으로만 넣고(`GateCredential.swift`), 웹 화면 코드(`WebPane*.swift`)는 토큰·인증 머리를 쓰지 않는다. 파일·사진 요청은 리다이렉트를 따르지 않는다.

## 범위 밖 참고(지적 아님, 담당 검토자·계획 담당 판단)

- 직원이 보낸 첨부는 종류 제한 없이 내려받아 `NSWorkspace.open`으로 연다(`ConversationController.swift:212`, `:467-473`). 격리 표시(quarantine)를 붙이지 않는다. 직원 답이 오염됐을 때 열면 실행되는 종류의 파일이 올 수 있다.
- `GateKeychain.save`는 `[A-Za-z0-9_-]`만 받아(`GateCredential.swift:11-13`), 기호가 든 비밀번호는 "비밀번호 저장"을 켜도 조용히 저장되지 않는다(`LoginWindow.swift:247`).
- 허브 요청은 `http://`로 비밀번호·토큰을 보낸다(`HubClient.swift:16`). 설계상 전제(사설망)인지 확인만 권한다.

## TASK별 결론

| TASK | 결론 |
|---|---|
| TASK-20 (앱: 얼굴·색·사이드바 배치) | 지적 있음 — IR-05(비차단). 사진 요청·캐시는 통과 |
| TASK-24 (앱 `MemberState`) | 지적 있음 — IR-02(비차단, 우선), IR-03, IR-04, IR-05(비차단) |
| TASK-25 (앱 스레드 카드) | 지적 있음 — IR-01(차단). 삭제·분기·링크·체크는 통과 |
| TASK-33 (자동 업데이트·`hejo-ship`) | 지적 있음 — IR-06(비차단). 서명·저장소·하위 버전·동의 경로는 통과 |
