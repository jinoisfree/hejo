# HEJO-DISCORD 수락 시험 명세

- 소유: 기획설계. 2판(2026-11-24, 계획 검증 1회차 PR-01~05 반영 — AT-HD-01·04·09·16·17·20·27·30·33·42·50 고침/추가, M7 표현, M10 추가). 2회차 APPROVED 권고 PR-06~08: M6b 추가. 1판은 1회차 BLOCKED. 자동 시험은 문 41개(AT-HD-01~17, 20~45 중 삭제된 2개 제외)와 앱 4개(AT-HD-50~53). 기대값 근거: [spec.md](../../docs/changes/HEJO-DISCORD-20261124/spec.md) 요구와 [design.md](../../docs/changes/HEJO-DISCORD-20261124/design.md) 2~7절.
- 상태: 모두 "명세 완료 · 코드 미작성 · 미실행". 명세는 계획 검증 2회차·재시작 3회차 APPROVED로 검토를 마쳤고(plan-review.md), 시험 코드와 실행 결과는 아직 검토되지 않았다. 코드는 구현 담당이 `tests/acceptance/test_discord.py`(문)와 `app/Tests/`(앱)에 옮기며 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 관측 방법 보충(검증 1회, 기대값 변경 아님): AT-HD-14는 준비(ready) 전환이 끝난 뒤 방 명령만 보내고 수동 동기화 호출·추가 조회 없이 관측한다. AT-HD-22의 "받는 직원"은 기록 행의 `employee`가 아니라 넘겨진 이벤트의 프로필과 수신자(`recipients`)로 관측한다(단체방 행의 `employee`는 방 대표다).
- 기존 시험과의 관계(검증 2회, 기대값 변경 아님): 통신 규격에 정의 6종을 더하므로 AT-SM-02의 규격 전체 해시는 `c91a7a4f93a008028809871f377cf6b240c4a4095fab819b48fc69d122ce4bec`로 갱신한다(기존 정의 변경 0을 계획 담당이 직접 비교해 확인). AT-HD-45의 개인값 검사는 기존 mockup 14개 검출(이 작업 밖)이 기준 브랜치에서 정리된 뒤 종료 0으로 최종 확인하며, 그 전에는 "검출 집합이 기준과 같고 이번 변경 파일 검출 0"으로 중간 확인한다. 앱 전체 시험의 AT-UC-32는 기존 불안정 시험이며 그것만 실패하면 나머지 단계를 따로 실행해 확인한다.
- 공통 환경: 임시 `HERMES_HOME`, 가짜 명부(`default`/`Main`, `alpha`/`Alpha`, `beta`/`Beta`)와 단체방 `G`(제목 `Team`, 구성원 `alpha`·`beta`, 대표 `alpha`). 실제 Hermes 모듈 import(discord.py 없이 — 가짜 객체만), 기존 `gate.tests.support` 러너. 증거 수준은 표시가 없으면 2.
- **가짜 디스코드 어댑터 `F`:** `BasePlatformAdapter` 하위, 문 이름 `discord`. `handle_message`(원래 처리기, 받은 이벤트 기록), `_get_allow_bots()`(기본 `"none"`, 값 주입), `_is_allowed_user(user_id, author, *, guild, is_dm, channel_ids)`(기본 `False`, 값·예외 주입, 인자 기록), `is_connected` 참. AT-HD-30만 가짜 `F` 대신 실제 `DiscordAdapter`를 쓴다(그 시험 절차 참조).
- **가짜 봇 `N`(native):** `add_listener(fn, name)`(기록), `get_guild(id)` → 가짜 서버 `S`, `http.send_typing(channel_id)`(기록, 실패 주입). `S.create_category(name)`(돌려주는 id `cat-1`…), `S.get_channel(id)`(지운 채널은 `None` — 삭제 주입), `S.create_forum(name, category)`(돌려주는 채널 id `ch-1`, `ch-2`…, 실패 주입 시 예외 — 메시지에 서버 id 포함), 채널 `edit(name=..., category=...)`, `webhooks()`, `create_webhook(name)`, 웹후크 `send(content, username, thread=None, thread_name=None, files=None, allowed_mentions, wait)`(돌려주는 글 id `dc-out-1`…, 새 글 묶음이면 글 묶음 id `post-1`…, 실패 주입: 거짓·일반 예외·`NotFound`(글 묶음 없음, HTTP 404)). 모든 호출과 인자를 순서대로 기록한다. 채널 `send(text)`(안내·"연결됐어요" — 봇 발신 기록).
- **가짜 식별자:** 서버 `gld-A`, 다른 서버 `gld-B`; 사장 `usr-A`, 다른 사람 `usr-B`; 일반 글 채널 `txt-1`; 받은 글 id `dc-in-1`…; 사장이 만든 글 묶음 `post-in-1`….
- **글 만들기:** `message`(가짜): `id`, `content`, `author(id, bot)`, `webhook_id`, `guild(id)` 또는 `None`, `channel`(글 묶음이면 `id`·`parent_id`·`name`(제목)·`starter`여부, 아니면 채널 `id`), `attachments`(`filename`, `size`, `save(path)`/`read()`). 원래 처리 경로 시험은 `MessageEvent(source=SessionSource(platform=discord, chat_type, chat_id, user_id, thread_id, guild_id))`.
- **정착 시간:** 0.05초. **활성 준비:** 짝짓기(AT-HD-02) → `discord_save{enabled:true}` → 동기화 끝(`channels.json`에 방 4개 `default`·`alpha`·`beta`·`G`).

## 자동 시험 — 문

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HD-01 | 설계 2.1 | 문 등록 뒤 처리기 공장 목록 조회, 공장을 `F`·`N`에 두 번 적용 | `discord` 공장 1개. `N.add_listener` 1회(이름 `on_message`, 두 번 적용해도 1회), `F.handle_message`는 원래 메서드 그대로(감싸지 않음), 공장 안 네트워크 호출 0 |
| AT-HD-02 | 01.AC-01·02 | 앱1·앱2(기능 `discord`). 앱1 `discord_pair{id:"p1"}` → 코드를 `gld-A`/`usr-A`/`txt-1` 글로 듣기에 넣음 | 앱1만 `discord_code{ref:"p1", expires_in:600}`(code 12자). `discord.json.pair` = `{platform:"discord", guild_id:"gld-A", user_id:"usr-A", tag(8자)}`, 권한 0600, 코드 `used` 참. `txt-1`에 봇 `연결됐어요` 1회. 두 앱 `discord_status{paired:true, enabled:false}`(ref 없음). 기록장 행 증가 0. `F.handle_message` 원래 처리 0 |
| AT-HD-03 | 01.AC-01 | `discord_pair` 두 번(`p2`, `p3`) 뒤 `p2` 코드 | 짝 없음. `p3` 코드는 짝짓기 됨 |
| AT-HD-04 | 01.AC-03 | (a) 틀린 글 (b) 시계 +601초 뒤 맞는 코드 (c) 쓴 코드 다시 (d) 1:1(`guild` 없음) 맞는 코드 (e) `author.bot` 참 (f) `webhook_id` 있음 (g) `F._is_allowed_user`가 참 (h) `F._get_allow_bots()`가 `"all"` (i) `F._is_allowed_user`가 예외 (j) `settings.json` 깨짐 | 열 경우 모두 `discord.json.pair` 불변, 봇 발신 0, 기록장 불변. (g)(h)(i)에서 `F._is_allowed_user` 인자는 `guild` = 그 서버, `is_dm` 거짓, `channel_ids` ⊇ {그 채널 id} |
| AT-HD-05 | 01.AC-04 | 활성에서 `discord_unpair{id:"u1"}` 뒤 `alpha` 채널 글 묶음에 사장 글 | `discord_status{ref:"u1", paired:false, enabled:false}`, 기록장 불변, 봇·웹후크 발신 0, `channels.json` 바이트 불변 |
| AT-HD-06 | 01.AC-05 | 활성(`gld-A`, 표지 `T1`) 뒤 새 코드를 `gld-B`/`usr-B`로 짝짓고 켬. 이어 같은 `gld-B`로 다시 짝지음(`T3`) | 새 표지 ≠ 이전, `channels.json.tag` = 새 표지, 짝지을 때마다 `create_forum` 4회. `gld-A`의 사장 글은 기록장 불변 |
| AT-HD-07 | 01.AC-06 | 공장 미적용에서 `discord_pair{id:"p4"}`, `discord{id:"q1"}` | `error{ref:"p4", code:"discord_unavailable"}`, `discord.json` 코드 없음, `discord_status{ref:"q1", platform_ready:false}` |
| AT-HD-08 | 01.AC-07, NFR-04 | AT-HD-02 → 활성 → AT-HD-14(a)(b)(c) → AT-HD-20(`hello`) → AT-HD-30(`pong`). 모든 로거·앱별 프레임·기록장·네 파일 검색 | 코드 평문: 앱1 `discord_code` 1개에만. `gld-A`·`usr-A`: `discord.json`에만. 짝 표지·`ch-`·`post-`·`dc-` id: 허용 위치(spec 제약 표)에만, 로그 0건. 웹후크 id·토큰 값: 파일·로그·프레임 0건. `hello`·`pong`: 기록장·앱 `message`·웹후크 `send` 인자에만 |
| AT-HD-09 | 02.AC-01·02 | 앱1·앱2 연결. 앱1 `discord_save{id:"s1", enabled:true}` → 문 끊고 다시 연결 → 앱1 `discord{id:"q2"}` | 저장 뒤 앱1은 `discord_status` 정확히 1개(`ref:"s1"`), 앱2도 정확히 1개(`ref` 없음), 두 프레임의 `ref` 외 필드 같음. 재연결 뒤 앱1만 `discord_status{ref:"q2"}` 1개, 값 같음. `settings.json` 0600 |
| AT-HD-10 | 02.AC-02 | 짝 없이 `discord_save{enabled:true}` | `error(discord_unpaired)`, `settings.json` 불변, 방송 0 |
| AT-HD-11 | 02.AC-03 | 기능 `discord` 없는 앱3이 `discord{id:"q3"}`; 앱1이 짝짓기·저장 | 앱3은 `error{ref:"q3", code:"unexpected_frame"}`, `discord_status`·`discord_code` 0건 |
| AT-HD-12 | 03.AC-01 | 짝 뒤 켜기, 다시 끄고 켜기 | 분류 `hejo` 1회 만들기, `create_forum` 4회(이름 `Main`·`Alpha`·`Beta`·`Team`, 분류 = `hejo`), `channels.json`에 네 방. 두 번째 켬에 추가 만들기 0 |
| AT-HD-13 | 03.AC-04 | `create_forum` 실패 주입 후 켬 → `alpha` 직원 글 기록 → 주입 해제 → 끄고 켬 | 첫 켬 뒤 `discord_status{channel_problem:true}`, 경고 로그 1줄 이상(`gld-A`·id 0건), `alpha` 글 발신 0. 다시 켠 뒤 만들기 성공, `channel_problem:false` 방송 |
| AT-HD-14 | 03.AC-02 | 활성에서 (a) 단체방 `H`(`Ops`) 만들기 (b) `Ops2`로 (c) 보관 (d) 보관 풀기 (e) 삭제 | (a) `create_forum` `Ops` (b) `edit(name="Ops2")` (c) 분류 `hejo 보관` 1회 만들기 + `edit(category=보관)` (d) `edit(category=hejo)` (e) `edit(category=보관)`. 각 단계 `channels.json.H.closed` 일치 |
| AT-HD-15 | 03.AC-03·05 | 활성 뒤 명부에 `gamma` 추가 → `gamma` 직원 글. 별도로 `alpha` 채널을 가짜 서버에서 지움(조회 실패) → `alpha` 직원 글 | 각각 보내기 전 `create_forum` 1회(`Gamma` / `Alpha`) 다음 웹후크 발신 1회 |
| AT-HD-16 | 03.AC-05, 05.AC-01 | 활성. 앱이 `alpha` 방에 사장 글 `a1`(새 스레드 K) → 글 묶음 `post-1`(채널 = 현재 `alpha` 채널 C1) 생김. `S`에서 C1 삭제 주입 → 앱이 K에 `a2` → K에 `a3` → 문 다시 시작 → K에 `a4` → 사장이 디스코드 새 글 묶음 `post-2` 안에 `r1` | `a2` 전에 `create_forum` 1회(새 채널 C2, `channels.json.alpha.channel` = C2). `a2`는 `thread_name` 발신(새 글 묶음 `post-2`, `thread=post-1` 호출 0). `a3`·`a4`는 `thread=post-2`. `sent.jsonl`의 `a2`~`a4` 줄 `ch` = C2. `r1`은 K에 기록 |
| AT-HD-17 | 05.AC-01·06 | 활성. K의 글 묶음 `post-1`에 웹후크 발신이 `NotFound`가 되게 주입 → 앱이 K에 `b1` → K에 `b2`. 별도로 일반 예외 주입 → K에 `b3` | `b1`: `thread=post-1` 1회(실패) 다음 `thread_name` 1회(새 `post-2`), 같은 내용. `b2`: `thread=post-2`. `b3`: 1회 실패, 로그 1줄, 추가 발신 0 |
| AT-HD-20 | 04.AC-01 | 활성. `alpha` 채널에 사장이 새 포럼 글(제목 `hello`, 내용 `hello`, 글 `dc-in-1`, 글 묶음 `post-in-1`) | 기록장 사장 글 1행(`employee:"alpha"`, 새 `thread`, `text:"hello"`, `client_msg_id` = `discord:<tag>:<channels.json의 alpha 채널 id>:post-in-1:dc-in-1`), 앱 `message` 수신, 대역 처리기 이벤트 1, 웹후크·봇 발신 0(되보내지 않음) |
| AT-HD-21 | 04.AC-01 | (a) 제목 `Q`, 내용 `details` (b) 제목 `Q`, 내용 빈 문자열 | (a) `text:"Q\ndetails"` (b) `text:"Q"` |
| AT-HD-22 | 04.AC-01 | `G` 채널에 새 글 (a) `hi` (b) `@Beta hi` | 받는 직원 (a) `alpha` (b) `beta`, 행에 `room:"G"` |
| AT-HD-23 | 04.AC-02 | AT-HD-20 뒤 같은 글 묶음 `post-in-1`에 `more`(`dc-in-2`). 그다음 AT-HD-20 스레드를 `thread_delete` → 같은 글 묶음에 `again`(`dc-in-3`) → 같은 글 묶음에 `again2`(`dc-in-4`) | `more`는 AT-HD-20 스레드. `again`은 `alpha` 방 새 스레드 K2, `again2`는 K2 |
| AT-HD-24 | 04.AC-02 | 직원 글로 hejo가 만든 글 묶음(`post-1`)에 사장이 답 | 그 직원 글의 스레드에 사장 글 |
| AT-HD-25 | 04.AC-03 | (a) 내용 `look`+그림 1개 (b) 내용 없이 파일 1개 (c) `size` 50 MiB+1 파일 (d) 내려받기 예외 | (a) `text:"look"`, `files` 1개, 바이트 동일 (b) `text:""`, `files` 1개 (c)(d) 기록장 불변, 그 글 묶음에 봇 `지금은 받지 못했어요` 1회 |
| AT-HD-26 | 04.AC-04 | 활성. 사장이 (a) `txt-1`에 글 (b) 대응 없는 포럼의 글 묶음 (c) `H` 보관 뒤 `H` 채널 글 묶음에 글 | 셋 다 기록장 불변, 그 자리에 봇 `앱에서 만든 방 채널에 써 주세요` 1회 |
| AT-HD-27 | 04.AC-05 | (a) 짝 없음 (b) 짝 있고 꺼짐 (c) 활성에서 `usr-B` (d) 활성에서 `gld-B` (e) 활성에서 1:1 (f) `webhook_id` 있는 글 (g) 금고 파일을 읽을 수 없게 (h) 활성에서 `F._is_allowed_user` 참인 사장의 `alpha` 글 묶음 글 | 여덟 경우 모두 기록장 불변, 봇·웹후크 발신 0. (h)는 로그 `discord_core_open` 1줄(id 없음), 앱에 `discord_status{core_open:true}`(ref 없음) 방송 |
| AT-HD-28 | 04.AC-06 | AT-HD-20의 같은 글을 듣기에 한 번 더 | 기록장 행 증가 0 |
| AT-HD-29 | 04.AC-07 | 본문이 `text_bytes` 한도 초과 | 기록장 불변, 봇 `지금은 받지 못했어요` 1회 |
| AT-HD-30 | 04.AC-08, 설계 2.2 | **통합(수준 2, 실제 Hermes 디스코드 어댑터):** Hermes 시험 선례(`R/tests/gateway/test_discord_free_response.py`의 가짜 `discord` 모듈 방식)로 실제 `DiscordAdapter`를 만들고, 임시 `HERMES_HOME`·시험 안에서만 지운 환경으로 닫힘 운영(디스코드 허용 사용자·역할·채널·전체 허용·게이트웨이 전체 허용 없음, 짝 승인 없음, `allow_bots` 기본). 문 공장을 이 어댑터와 가짜 봇에 적용하고 활성. 같은 `message` 객체를 원래 경로(`_dispatch_discord_message`)와 hejo 듣기 **둘 다**에 넣는다(순서 두 가지 모두): (a) 일반 글 채널 `txt-1`에 `<@봇> hi` (b) `alpha` 글 묶음에 `<@봇> hi` (c) `alpha` 글 묶음에 첨부 1개와 `see` (d) hejo 웹후크 글(`author.bot` 참, `webhook_id` 있음). 이어 (e) 시험 환경에 디스코드 허용 사용자 = 사장 계정을 넣고 어댑터를 다시 만든 뒤 (b) | (a)~(d): 원래 경로 반환 거짓, `_handle_message` 호출 0(감시), 스레드 만들기 0, 원래 어댑터의 채널 발신 0, 첨부 `read`/`save` 원래 경로 호출 0, `message.content` 원문 그대로. hejo 쪽: (a) 봇 안내 `앱에서 만든 방 채널에 써 주세요` 1회만 (b) 기록장 1행 `text` = `<@봇> hi` (c) 1행, `files` 1개 (d) 기록 0·발신 0. 두 순서 결과 같음. (e): hejo 기록 0, `core_open:true` 방송, 로그 `discord_core_open` 1줄 |
| AT-HD-31 | 05.AC-01 | 활성. 앱이 `alpha` 방에 사장 글 `ping`(새 스레드) → `alpha`가 `pong` 기록, 작성 중 꺼짐, 정착 | 웹후크 발신 순서: ① `content:"ping"`, `username:"사장"`, `thread_name:"ping"`(새 글 묶음 `post-1`) ② `content:"pong"`, `username:"Alpha"`, `thread` = `post-1`. 둘 다 `allowed_mentions` 전부 꺼짐. `sent.jsonl` 2줄 |
| AT-HD-32 | 05.AC-01, 07 | `alpha` 작성 중 동안 `pong` 기록, 정착 3배 기다림 → 작성 중 끔 → 정착 | 작성 중 동안 발신 0, 끈 뒤 1회. 생각 중 글 0회 |
| AT-HD-33 | 05.AC-01 | 직원이 새 스레드 첫 글 (a) 120자 한 줄 (b) 빈 첫 줄 뒤 본문 (c) 본문 빈 문자열+파일 | `thread_name` (a) 앞 100자 (b) 다음 비지 않은 줄의 앞 100자 (c) `새 대화` |
| AT-HD-34 | 삭제 — HEJO-TELEGRAM-REMOVE | | |
| AT-HD-35 | 05.AC-03 | 직원 글 4500자(줄바꿈 포함) | 웹후크 발신 3회, 순서대로 이어 붙이면 원문, 각 2000자 이하, 첫 통만 `thread_name`, 나머지는 `thread` = 첫 통의 글 묶음. `sent.jsonl` 3줄(같은 `msg_id`) → 재시작 → 셋째 통 글 묶음에 사장 답 → 그 스레드 |
| AT-HD-36 | 05.AC-04 | (a) 그림 `p.png`·문서 `d.txt` (b) 없는 파일 `x.bin` (c) 8 MiB+1 파일 (d) 파일 발신 실패 주입 | (a) 본문 뒤 파일 발신 2회(같은 글 묶음) (b)(c) 본문 끝 `📎 이름 (hejo 앱에서 열기)`, 파일 발신 0 (d) 본문 1회, 파일 실패 로그 1줄(id·파일 이름 없음), 다시 보내지 않음 |
| AT-HD-37 | 05.AC-04 | 선택 버튼 `A`/`B` 글, 일반 버튼 글 | 덧붙임 줄 `선택: A / B`와 `(이 선택은 hejo 앱에서 눌러 주세요)` |
| AT-HD-38 | 05.AC-05 | 직원 글 `@everyone hi <@123>` | 웹후크 `allowed_mentions`가 everyone·users·roles 모두 거짓 |
| AT-HD-39 | 05.AC-06 | 웹후크 발신 실패 주입(거짓·예외) 뒤 같은 글 정착 | 로그 1줄씩(id·본문 없음), 다시 보내지 않음, 기록장·앱 영향 없음 |
| AT-HD-40 | 05.AC-07 | 꺼진 동안 `alpha` 글 → 켬 → 정착 3배 | 발신 0 |
| AT-HD-41 | 05.AC-08, NFR-03 | 두 홈(디스코드 활성 / 짝 없음)에 같은 hejo 쪽 대본(AT-HT-39와 같은 대본) | 두 홈 기록장 행(시각·uuid 제외)·앱 프레임 같음. 활성 홈에서만 웹후크 발신 |
| AT-HD-42 | NFR-05 | `sent.jsonl` 끝 덜 쓰인 줄·중간 깨진 줄, `channels.json`·`settings.json`·`discord.json` 각각 깨진 JSON으로 문 시작. 각 경우 유효 코드 글과 `alpha` 글 묶음 사장 글, 직원 글 기록 | 네 경우 모두 문 연결 성공. 금고·설정 손상이면 짝짓기 0·기록 0·발신 0. `channels.json` 손상이면 다음 동기화가 다시 씀. `sent.jsonl` 손상이면 성한 줄의 대응은 유지 |
| AT-HD-43 | 06.AC-01·02 | 활성. AT-HD-31 글 묶음이 있는 스레드에서 문 `send_typing` 3회 1초 안 → 9초 뒤 1회. 글 묶음 없는 새 스레드에서 `send_typing`. `N.http.send_typing` 실패 주입 | `send_typing` 호출 2회(`post-1`), 글 묶음 없는 스레드는 0회, 표시용 발신 0. 실패 때 차례·발신 정상, 경고 1줄 |
| AT-HD-44 | 삭제 — HEJO-TELEGRAM-REMOVE | | |
| AT-HD-45 | NFR-01·03 | `bash scripts/test.sh`, `python3 scripts/scan_private.py`(Hermes 환경 Python) | 둘 다 종료 0 |

## 자동 시험 — 앱

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-HD-50 | 08.AC-01 | `DiscordState`에 프레임을 차례로: 없음 / `error unexpected_frame`(조회) / `platform_ready:false` / `core_open:true, channel_problem:true` / `channel_problem:true` / `paired:true` / `paired:false` | 상태 글 `서버 연결 전` → `서버가 지원하지 않음` → `서버에 디스코드가 연결돼 있지 않음` → `Hermes 디스코드 허용이 열려 있음` → `채널 권한 문제` → `연결됨` → `연결 안 됨` |
| AT-HD-51 | 08.AC-01 | `requestCode` → `discord_code{expires_in:600}` → 시계 +30초 → `paired:true` 방송 | 코드 표시, 남은 초 570, 짝지은 뒤 코드 지워짐 |
| AT-HD-52 | 08.AC-02 | `GateClient.features` | `["rooms","discord"]` 정확 비교 |
| AT-HD-53 | 08.AC-01·03 | 설정 화면 생성 | 디스코드 구역이 ‘연결과 동기화’ 페이지에 있음, 준비 안내 문구에 `Message Content`·`커뮤니티`·`채널 관리`·`웹후크 관리` 포함, SwiftUI 사용 0 |

## 실물 확인 (사장, 안드로이드 폰, 수준 4)

| ID | 확인 | 합격 |
|---|---|---|
| M1 | 앱에서 코드 받기 → 디스코드 서버 `#일반`에 입력 | "연결됐어요", 앱 "연결됨" |
| M2 | 켜기 | 분류 `hejo` 아래 방마다 포럼 채널 |
| M3 | 폰에서 직원 채널에 새 포럼 글 | hejo 앱 그 방에 새 스레드, 직원이 답함 |
| M4 | 직원 답이 오는 동안 | 폰 글 묶음에 `hejo 입력 중` 표시, 답은 직원 이름으로 |
| M5 | hejo 앱에서 새 스레드 글 | 디스코드에 새 포럼 글(`사장`), 직원 답이 같은 글 묶음 |
| M6 | 폰에서 글 묶음 안에 답 | hejo 같은 스레드에 기록 |
| M6b | 폰에서 hejo가 만든 글 묶음 하나를 보관(archived)으로 바꾼 뒤, hejo 앱에서 그 스레드에 글 | 글이 같은 글 묶음에 올라가고 글 묶음이 다시 열림. 실패하면 로그 종류와 결과를 기록하고 spec 알려진 한계의 가정을 거짓으로 보고 |
| M7 | 폰에서 사진 보내기, 직원이 파일 보내기(5 MB, 9 MB) | hejo 첨부 저장. 5 MB 파일 보임, 9 MB는 📎 줄. 이것은 보수 상수(8 MiB) 동작 확인이며 디스코드 실제 한도 확인이 아니다(실제 한도는 [미확인]으로 남음) |
| M8 | 삭제 — HEJO-TELEGRAM-REMOVE | |
| M9 | 단체방 이름 바꾸기·보관 | 채널 이름 바뀜·`hejo 보관`으로 이동 |
| M10 | `#일반`에서 봇을 멘션해 `@hejo 안녕`, 방 채널 글 묶음에서도 멘션 | Hermes 답·자동 스레드 0. `#일반`엔 hejo 안내 하나, 글 묶음 글은 hejo에 그대로 기록. 앱 상태에 `Hermes 디스코드 허용이 열려 있음` 없음 |
