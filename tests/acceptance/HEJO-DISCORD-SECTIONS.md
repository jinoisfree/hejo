# HEJO-DISCORD-SECTIONS 수락 시험 명세

- 소유: 기획설계. 8판(2026-11-26 HEJO-TIDY 검증 2회 — 공개 줄 추적 파일 규칙 AT-HTR-02를 지키도록 영문 텔레그램 표기 3곳을 뜻 그대로 한글로 바꿈, 기대값 무변경) / 7판(2026-11-26 HEJO-TIDY 검증 1회 — 텔레그램 제거 줄과의 통합: AT-DK-22(c)·23 줄 기준판에 공개 텔레그램 제거판 추가, AT-DK-54를 줄 기준판의 기능 목록 보존으로 변경) / 6판(2026-11-26 V-05 AT-DK-22 구조 검사) / 5판(2026-11-26 검증 3회 V-04 — AT-DK-22·23 줄 기준판, HEJO-TELEGRAM-REMOVE AT-HTR-04 허용 추가 연동; 4판은 V-01 AT-DK-50) / 3판(2026-11-25, 계획 검증 1회차 DK-R1-01~04 반영 — AT-DK-03·09·13·19 고침, AT-DK-24~28 추가, 가짜 확장에 한도 강제·대기 제어 추가; 2회차 DK-R2-01·02 반영 — AT-DK-29·30 추가). 기대값 근거: [spec](../../docs/changes/HEJO-DISCORD-SECTIONS-20261125/spec.md) 사용자 결정 D-01~D-05와 요구, [design](../../docs/changes/HEJO-DISCORD-SECTIONS-20261125/design.md) 3~4절.
- 상태: 모두 "명세 완료 · 코드 미작성 · 미실행". 고위험(spec 2판)이므로 계획 검증(교차 모델 reviewer)이 사전 독립 검토이며 통과 전까지 G3 보류. 코드는 구현 담당이 문 시험을 새 파일 `tests/acceptance/test_discord_sections.py`(기존 `test_discord.py`의 가짜 객체·러너를 가져다 씀)에, 앱 시험을 `app/Tests/`에 옮긴다. 기대값·합격 기준은 바꾸지 않는다. 바꿔야 하면 멈추고 보고한다.
- 공통 환경: [HEJO-DISCORD 수락 시험](HEJO-DISCORD.md)의 공통 환경 그대로(임시 `HERMES_HOME`, 가짜 명부 `default`/`Main`·`alpha`/`Alpha`·`beta`/`Beta`, 단체방 `G`/`Team`, 가짜 어댑터 `F`, 가짜 봇 `N`, 서버 `S`=`gld-A`, 정착 0.05초). **활성 준비** = 짝짓기 → 켜기 → 동기화 끝(분류 `hejo`=`cat-1`, 방 4개 채널).
- **가짜 확장(구현 담당이 더함, 기대값 아님):** 분류·채널에 `position`(만든 순서로 증가)과 부모(`category`)를 두고, `S`가 분류의 자식 채널을 셀 수 있게 한다. 분류·채널 `edit(name=, category=, position=)`, `delete()`(기록 `('delete', id)`), `create_category(name, position=None)`. 실패 주입: 다음 n번 호출에 `RateLimited(retry_after)` 또는 `status == 429`인 `HTTPException`(본문 `retry_after`), 또는 `OSError`. **분류 한도 강제:** 자식이 이미 50개인 분류로의 만들기·이동은 `HTTPException(status=400)`으로 거절하고 거절 횟수를 기록한다(실제 디스코드와 같은 제약을 가짜가 지키게 함). **대기 제어:** 문 객체의 속도 제한 대기 함수(design 4.6)를 시험용으로 바꿔 받은 초를 기록하고, 기본은 즉시 반환, 지정한 시험에서는 시험이 신호를 줄 때까지 멈춘다(대기 진입 신호 포함).
- **배치 L1:** `discord_layout{id:"l1", sections:[{id:"1",name:"Work",rooms:["G"]},{id:"2",name:"Ops",rooms:["beta"]}], stack:{name:"DM",rooms:["alpha","default"]}}`.
- **분류 순서 관측:** 문이 만든 분류만 `position` 오름차순으로 나열한 이름 목록. **채널 순서 관측:** 한 분류의 자식 채널을 `position` 오름차순으로 나열한 이름 목록.

## 자동 시험 — 문

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-DK-01 | 02.AC-01, 03.AC-01, 03.AC-03 | 활성 준비 → 앱1(기능 `discord`) L1 | 앱1에 `discord_status{ref:"l1"}` 1개. `layout.json` = L1의 `sections`·`stack`(그 밖 키 없음), 0600. `create_category` 정확히 3회(`Work`·`Ops`·`DM`), `create_forum` 0회. 부모: `G`→`Work`, `beta`→`Ops`, `alpha`·`default`→`DM`. `hejo`(`cat-1`) 삭제 1회, `channels.json.category` = `null`, `channels.json.sections` 키 = {`1`,`2`,`~stack`}. `channel_problem:false` |
| AT-DK-02 | 03.AC-02 | AT-DK-01 뒤 L1에서 섹션 `1` 이름만 `Projects` | `Work` 분류(같은 id) 이름 바꾸기 1회, `create_category` 0, 채널 이동 0, 삭제 0 |
| AT-DK-03 | 03.AC-02 | AT-DK-01 뒤 `G`를 섹션 `2`로(섹션 `1` rooms 빈 배열 — 섹션은 남음) | `G` 채널 부모 `Ops` 이동 1회, `Work` 분류 **삭제 0**(자식 0개로 남음), `sections`에 `1` 유지, `create_category` 0 |
| AT-DK-04 | 03.AC-02 | AT-DK-01 뒤 섹션 `2`를 없애고 그 방 `beta`를 섹션 `1`로(= 앱의 섹션 삭제 결과) | `beta` → `Work` 이동, `Ops` 삭제 1회, `sections` 키 = {`1`,`~stack`} |
| AT-DK-05 | 03.AC-02 | AT-DK-01 뒤 `alpha`를 `stack.rooms`에서 섹션 `1`로(고정) | `alpha` → `Work` 이동 1회, `DM` 분류 유지(자식 `default`) |
| AT-DK-06 | 02.AC-01 | AT-DK-01 뒤 같은 L1을 `id:"l2"`로 다시 | `discord_status{ref:"l2"}` 1개. `layout.json` 바이트·수정 시각 불변, 디스코드 호출 0 |
| AT-DK-07 | 03.AC-03 | 사본 없이 활성 준비, 앱 보고 없음 | 분류는 `hejo` 하나, 네 채널 모두 그 아래, `layout.json` 없음, `channels.json.sections` 없음 또는 `{}` (AT-HD-12와 같은 결과) |
| AT-DK-08 | 03.AC-03 | AT-DK-01 뒤 새 단체방 `H`(제목 `Zed`) 생성(사본에는 없음) → 그 뒤 L1에 `H`를 섹션 `1`에 넣어 보고 | 첫 동기화: `hejo` 분류 새로 만들기 1회, `Zed` 채널이 그 아래. 보고 뒤: `Zed` → `Work`, `hejo` 다시 삭제, `category` = `null` |
| AT-DK-09 | 03.AC-01·03 | AT-DK-01 뒤 `G` 보관 → 보관 해제 | 보관: `G` → `hejo 보관`(새로 만듦), `Work`는 자식 0개로 **남음**(삭제 0). 해제: `G` → 같은 id의 `Work`, `create_category` 0. `hejo 보관`은 남음(삭제 0) |
| AT-DK-10 | 03.AC-04 | 활성 준비 전에 `S`에 사장 분류 `Mine`(`cat-x`)과 그 아래 채널 `txt-9`. AT-DK-01 뒤 `S`에서 채널 `txt-8`을 `Ops` 아래로 옮겨 둠 → AT-DK-04의 보고 | `Mine`·`txt-9`·`txt-8`에 대한 호출(이름·이동·위치·삭제) 0. `Ops`는 자식(`txt-8`)이 남아 삭제 0, `channels.json.sections`에 `2` 그대로 |
| AT-DK-11 | 04.AC-01·03 | AT-DK-01 직후 관측 → 섹션 순서를 바꾼 보고(`2` 먼저) → 같은 보고 다시 → `alpha` 직원 글 1개 발신 | 첫 관측 분류 순서 [`Work`,`Ops`,`DM`] (`hejo 보관` 있으면 맨 뒤). 순서 바꾼 뒤 [`Ops`,`Work`,`DM`]. 같은 보고 다시: 위치 변경 호출 0. 글 발신 동안 위치 변경 호출 0 |
| AT-DK-12 | 04.AC-02·03 | AT-DK-01 직후 `DM` 분류 채널 순서 관측 → `alpha` 직원 이름을 `Zulu`로 바꿔 동기화 → 다시 동기화 | 처음 [`Alpha`,`Main`]. 이름 바꾼 뒤 [`Main`,`Zulu`]. 마지막 동기화의 위치 변경 호출 0 |
| AT-DK-13 | 03.AC-05 | (a) 명부를 직원 52명(`E01`~`E52`, 단체방 `G` 유지)으로 하고 모두 `stack.rooms`인 보고 (b) 별도로 AT-DK-01 뒤 `S`에서 사장 채널 `txt-7`을 `DM` 분류에 넣고(자식 3), 명부에 직원 48명(`E01`~`E48`)을 더해 `stack.rooms` = `alpha`·`default`·`E01`~`E48`(50개)인 보고 | (a) `DM` 아래 `E01`~`E50`, `hejo` 아래 `E51`·`E52`·`G`, `channel_problem:true`. (b) `DM` 실제 자식 50(= `txt-7` + `Alpha`·`E01`~`E48`), 이름 순 마지막 `Main`(`default`)은 `hejo`로 이동, `txt-7` 호출 0, `channel_problem:true`. 둘 다 가짜의 한도 거절 0 |
| AT-DK-14 | 02.AC-02 | (a) 기능 `discord` 없는 앱3이 L1 (b) `stack` 빠진 L1 (c) 같은 방 id가 두 섹션에 (d) 섹션 id `~stack` (e) 섹션 id 중복 | (a) `error{code:"unexpected_frame"}` (b) 기존 규격 위반과 같은 오류 응답 (c)(d)(e) `error{ref, code:"bad_layout"}`. 모두 `layout.json` 불변, 디스코드 호출 0, 방송 0 |
| AT-DK-15 | 02.AC-03 | AT-DK-01 뒤 해제 → 다시 짝짓기(새 표지) → 켜기 | `layout.json` 바이트 불변. 새 표지로 채널 4개 새로 만들기, 부모는 L1대로(`Work`·`Ops`·`DM` 새로 만듦) |
| AT-DK-16 | 05.AC-01 | 활성 준비 뒤 다음 2회 `create_category`에 `RateLimited(retry_after=0.25)` 주입 → L1 | 대기 기록 [0.25, 0.25], 같은 이름 `create_category` 시도 3회 중 마지막 성공. 최종 상태 AT-DK-01과 같음, `channel_problem:false` |
| AT-DK-17 | 05.AC-01 | 같은 시험을 `status == 429`, 본문 `retry_after: 0.5`인 `HTTPException` 1회로 | 대기 기록 [0.5], 최종 상태 AT-DK-01과 같음 |
| AT-DK-18 | 05.AC-02 | (a) 다음 3회 채널 이동에 `RateLimited(retry_after=0.25)` → L1 (b) 같은 시험에서 `retry_after=90` | (a) 같은 호출 3번 시도 뒤 중단, 그 뒤 디스코드 호출 0, `channel_problem:true` 방송, 재예약 지연 60초 1개(대기 함수 또는 예약 함수의 인자로 관측). 주입 해제 뒤 예약된 동기화가 돌면 최종 상태 AT-DK-01과 같고 `channel_problem:false`. (b) 재예약 지연 90초. 예약은 동시에 1개 이하(재예약 중 또 실패해도 2개가 되지 않음). 문 `close()` 뒤 예약 작업 취소됨 |
| AT-DK-19 | 05.AC-03 | AT-DK-01 상태에서 다음 `edit`(분류 이름 바꾸기)에 `RateLimited(retry_after=0.5)` 1회 + 대기 함수를 멈춤 모드로 → 섹션 `1` 이름 `Projects` 보고 → 대기 진입 신호를 받은 뒤 `alpha` 직원 글 기록(대응 채널 있음) → 웹후크 `send` 기록을 기다림 → 대기 해제 | 대기 진입 뒤, 해제 전에 그 글의 웹후크 `send`가 기록됨(동기화 완료 기록보다 앞). 해제 뒤 이름 바꾸기 성공, `channel_problem:false` |
| AT-DK-20 | 05.AC-03 | `edit`(채널 이동) 한 방에 `OSError` 1회 → L1 | 그 방 이동 시도 1회(재시도 0), 다른 방 이동 성공, `channel_problem:true`, 재예약 0 |
| AT-DK-21 | 06.AC-01 | 위 시험 전부의 로그 수집 | 서버·채널·분류 id(`gld-`·`cat-`·`ch-`), 방 이름(`Work`·`Ops`·`Team`), 짝 표지가 로그 0건 |
| AT-DK-22 | 06.AC-02 | 규격 파일 구조 검사(기준 커밋 비교 없음 — 6판). 줄 기준판 = [`1ca2cbbf25ddf8da0697e03175fb25292dabf701`(공개 텔레그램 제거판, 7판 추가), `c22e6774604398f84351d69dd926ba3510d31aa2`(공개), `adf54d76c967707078f19c7dab09d8a50f44d489`(운영)] 중 HEAD의 조상인 첫 커밋(test_discord.py 비교에만 씀) | (a) `$defs.discord_layout`이 공개 `41e6765`의 정의와 같음(시험에 기대 정의를 글자로 둠) (b) `#/$defs/discord_layout` 참조가 `clientFrame.oneOf`와 루트 `oneOf`에 각 정확히 1개, `serverFrame`에는 0개 (c) 줄 기준판의 `tests/acceptance/test_discord.py`와 바이트가 같음. "이 작업은 정의 추가만"이라는 점(기존 정의 무변경)은 통합마다 검증 담당이 병합 부모 대비 JSON 비교로 확인해 verdict에 남긴다. (6판, 2026-11-26 검증 5회 V-05: 다른 작업이 뒤에 규격을 추가하면 기준판 비교가 거짓 실패하므로 구조 검사로 바꿈. 시험 코드는 텔레그램 시험 파일 이름을 쓰지 않음) |
| AT-DK-23 | 06.AC-01 | `pytest tests/acceptance/test_discord.py <텔레그램 시험 파일(그 줄에 있을 때)> tests/acceptance/test_slack_move_gate.py tests/acceptance/test_discord_sections.py` | 종료 0. `test_discord.py`·텔레그램 시험 파일 수정 0줄. 운영 줄(텔레그램 제거판)에서는 텔레그램 시험 파일이 없으므로 그 줄에 있는 디스코드·Slack 이동·텔레그램 제거 시험과 이 작업 시험으로 실행. 텔레그램 시험 파일 무수정은 공개 줄에서 `git diff --exit-code <줄 기준판> -- <그 파일>`로 검증 담당이 확인(시험 코드 안에서 이름을 쓰지 않음). 줄 기준판은 AT-DK-22와 같은 목록(7판). 텔레그램 제거판이 조상인 줄에서는 텔레그램 시험 파일이 없으므로 운영 줄과 같이 실행 |
| AT-DK-24 | 03.AC-05 | 명부를 직원 98명(`A01`~`A49`, `B01`~`B49`)으로, 단체방 없음. 섹션 `1`(`X`, `A01`~`A49`)·`2`(`Y`, `B01`~`B49`), 스택 빈 배열로 동기화. `S`에서 사장 채널 `txt-5`를 `X`에, `txt-6`을 `Y`에 넣어 두 분류를 꽉 채움(각 50) → `A49`↔`B49`를 맞바꾼 보고 | 최종: `A49`는 `Y`, `B49`는 `X`, 두 분류 자식 각 50, 잠시 쓴 `hejo`는 비어 삭제(`category` = `null`). 가짜의 한도 거절 0, 과정 중 어느 분류도 자식 51 이상 없음, `txt-5`·`txt-6` 호출 0, `channel_problem:false` |
| AT-DK-25 | 03.AC-05 | AT-DK-24 준비에 사본에 없는 단체방 `H` 하나를 더해 `hejo`가 생기게 하고, `S`에서 사장 채널 49개를 `hejo`에 넣어 자식 50으로 채움 → 같은 맞바꿈 보고 | 남은 이동 하지 않음: `A49`는 `X`, `B49`는 `Y` 그대로, 한도 거절 0, `channel_problem:true`, 재예약 0, 예외 없이 동기화 끝 |
| AT-DK-26 | 03.AC-05 | 사본 없는 활성 준비(모든 방 `hejo`, 자식 4) 뒤 `S`에서 사장 채널 46개를 `hejo`에 넣어 자식 50 → 새 단체방 `H` 생성 | `H` 채널 만들기 0, `hejo`의 기존 채널 호출 0, `channel_problem:true`, 한도 거절 0, 예외 없이 동기화 끝 |
| AT-DK-27 | 08.AC-01 | AT-DK-01 뒤 문을 닫고, 같은 홈에서 `c22e6774604398f84351d69dd926ba3510d31aa2`의 `gate/discord.py`(시험이 git에서 꺼내 임시 패키지로 적재)로 문을 다시 열어 활성 → 새 단체방 `H`(`Zed`) 생성 → 동기화 | 기존 네 방 `create_forum` 0, `G`·`beta`·`alpha`·`default` 채널 이동 0, `hejo` 분류 새로 만들기 1회 후 `Zed`가 그 아래, `channel_problem:false`, `channels.json`의 `sections` 키는 이전 문이 써도 남거나 사라지거나 무관(관측하지 않음) |
| AT-DK-28 | 05.AC-03 | AT-DK-19와 같이 대기 멈춤 상태에서, 대응 채널이 없는 새 단체방 `H`의 직원 글 기록 → 대기 해제 | 해제 전 `H` 웹후크 `send` 0. 해제 뒤 동기화가 끝나고 `H` 채널이 만들어진 뒤 `send` 1회 |
| AT-DK-29 | 05.AC-04 | AT-DK-01 상태에서 (a) 다음 `edit`(분류 이름 바꾸기)에 `RateLimited(retry_after=0.5)`, 대기 멈춤 → 섹션 `1` 이름 `Projects` 보고 → 대기 진입 뒤 `discord_unpair` → 대기 해제 (b) 같은 준비에서 대기 진입 뒤 `discord_unpair` → 새 코드로 `gld-B`/`usr-B` 짝짓기·켜기 → 대기 해제 (c) 같은 준비에서 이번에는 다음 채널 이동(`G`를 섹션 `2`로 보고)에 주입, 대기 진입 뒤 `discord_save{enabled:false}` → 해제 | (a)(c) 대기 해제 뒤 `gld-A`에 대한 변경 호출(만들기·이름·이동·위치·삭제) 0, 재시도 0, `channels.json` 바이트가 대기 진입 때와 같음, 재예약 0. (b) 해제 뒤 `gld-A` 변경 호출 0. `gld-B`에는 새 표지로 분류 `Projects`·`Ops`·`DM`과 네 채널이 사본대로 만들어지고 `channels.json.tag` = 새 표지, `channel_problem:false` |
| AT-DK-30 | 03.AC-06 | AT-DK-01 뒤 `beta` 직원 제거(→ `beta` 채널이 `hejo 보관`으로, 보관 분류 생김), `S`에서 사장 채널 49개를 `hejo 보관`에 넣어 자식 50 → `G` 보관 → `G` 방에 직원 글 기록 → `S`에서 사장 채널 하나를 지움 → 동기화 요청(아무 보고) | 꽉 찬 동안: `G` 채널 부모 `Work` 그대로, `channels.json`의 `G` 항목 `closed` 거짓·바이트 불변, `G` 웹후크 `send` 0, `hejo`로의 이동·`hejo` 만들기 0, `channel_problem:true`, 한도 거절 0. 자리 생긴 뒤: `G` → `hejo 보관` 이동 1회, `closed` 참, `channel_problem:false`, `Work`는 자식 0으로 남음 |

## 자동 시험 — 앱 (`app/Tests/`)

공통: 섹션 `[{id:"1",name:""},{id:"2",name:"Ops"}]`, 스택 이름 없음, `zone:G`=`2`, `zone:H`=`9`(없는 섹션), `pin:beta`=`1`, `zone:beta`=`2`, `hide:alpha`=`1`. 방: 직원 `default`·`alpha`·`beta`, 단체방 `G`·`H`, 보관한 단체방 `K`, 가상 홈 행, 펫 홈으로 지정한 단체방 `P`(`zone` 기록 없음).

| 시험 ID | AC | 절차 | 합격 기준 |
|---|---|---|---|
| AT-DK-50 | 01.AC-01 | 위 상태에서 보낼 배치 계산 | `sections` = [{`1`,`section 1`,[`H`,`P`]}, {`2`,`Ops`,[`G`,`beta`]}], `stack` = {`DM`,[`alpha`,`default`]}. 각 `rooms`는 id 오름차순. `K`·가상 홈 행 없음. (4판, 검증 1회 V-01·사용자 D-06: 펫 홈 단체방 `P`는 첫 섹션) 모든 방 id 한 번씩 |
| AT-DK-51 | 01.AC-01·03 | 가짜 문 연결. (a) `discord_status` 받기 전 (b) 허브 계정 있음·`hasFetched` 거짓 상태에서 `discord_status` 받음 (c) 허브에서 받음 (d) 허브 계정 없음 상태의 새 연결에서 `discord_status` 받음 | (a)(b) `discord_layout` 0개. (c) 1개(내용 = AT-DK-50). (d) 1개 |
| AT-DK-52 | 01.AC-02 | (c) 뒤 아무 변경 없이 회원 상태 갱신 알림 → `zone:H`=`2` → 연결 끊고 다시 연결해 `discord_status` 받음 | 갱신 알림: 0개. `zone` 변경: 1개(`H`가 섹션 `2`). 재연결: 1개 |
| AT-DK-53 | 01.AC-03 | (c) 뒤 문이 그 요청 `ref`로 `error{code:"unexpected_frame"}` → `zone` 변경 | 오류 뒤 `discord_layout` 0개, `DiscordState.problem` = `""`, 상태 문구 불변 |
| AT-DK-54 | 06.AC-01 | 기존 앱 디스코드 시험(그 줄에 있으면 텔레그램 시험도) | 수정 없이 통과. `GateClient.features`가 이 작업으로 바뀌지 않음: 줄 기준판(AT-DK-22 목록)의 `GateClient.features`와 같다 — 텔레그램 제거판이 조상인 줄은 [`rooms`,`discord`](HEJO-TELEGRAM-REMOVE AT-HTR-20), 그 전 공개 줄은 [`rooms`, 텔레그램 기능 이름, `discord`]. 앱 시험 코드는 그 줄의 기대 목록을 글자로 두되 텔레그램 이름을 쓰지 않는 줄에서는 AT-HTR-02를 지킨다(7판) |

## 실물 확인 (증거 수준 4)

| ID | 누가 | 절차 | 합격 기준 |
|---|---|---|---|
| M1 | 구현 담당 | 운영 문 설치(TASK-03) 직후, 앱 갱신 전 | `layout.json` 없음, `channels.json` 바이트 설치 전후 같음, 새 ERROR 0, discord·hejo 연결(그때 운영 줄에 텔레그램이 있었으면 그 연결도) |
| M2 | 사장 | 새 앱 실행 뒤 휴대폰 디스코드 | 앱 섹션 이름·순서대로 분류, 그 뒤 `DM`, 맨 뒤 `hejo 보관`. 각 방 포럼이 앱과 같은 섹션(고정 DM은 그 섹션, 나머지 DM은 `DM`). 분류 안 채널 이름 순. 모든 방이 배치됐으면 `hejo` 분류 없음 |
| M3 | 사장 | 앱에서 섹션 이름 바꾸기 → 방 하나 다른 섹션으로 → DM 하나 고정 → 섹션 하나 삭제 | 각 1분 안에 디스코드 반영(분류 이름, 채널 이동, 빈 분류 사라짐). 속도 제한 로그가 있으면 그 대기 뒤 반영 |
| M4 | 구현 담당 | M2·M3 동안 문 로그 | 새 ERROR 0, 경고는 종류 이름만, 속도 제한 뒤 끝내 `channel_problem:false` |

