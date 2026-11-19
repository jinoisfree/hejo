# 비설계자 독립 검토 — 서버 영역 (2026-11-20)

- 검토자: 설계·구현에 참여하지 않은 새 세션. 이전 대화는 보지 않았다.
- 범위: `gate/`, `hub/`, `schemas/hejo-wire-v1.json`, `install/hejo-install`, `install/hejo-admin`, `install/admin_support.py`. TASK-21·22·24(허브)·25(문)·32·20(문)과 추가 범위의 문 변경(`owner_message`·`employee_message`·`source.message_id`·보조 문 post-delivery 콜백·`_delivery_scope`).
- 범위 밖: macOS 앱, team-kit 패치, TASK-33(다른 검토자).
- 방법: 대상 코드 전부 읽기, 기존 시험 실행, 의심 지점마다 임시 `HERMES_HOME`·가짜 명부로 탐침 시험 실행. 탐침 파일은 저장소 밖 임시 폴더에 두었고 저장소·운영 서버·Hermes 본체·ddots는 바꾸지 않았다. 비밀 파일은 열지 않았다.
- 기존 시험: `gate/tests` + `tests/acceptance` 257개 중 255 통과, 2 실패. 두 실패는 시험 환경 탓으로 보인다(제품 결함으로 세지 않음).
  - `test_native_labels_outcome_and_repeat_are_idempotent`: `PYTHONPATH=.build/task02-deps`를 주면 Hermes 번역 목록이 0건으로 읽혀 버튼 글자가 키 이름 그대로 나온다. 이 경로 없이 같은 키를 읽으면 한국어 글자가 정상으로 나온다.
  - `test_at_hf_08[True]`: `HEJO_TEAM_KIT_LIB`가 없어 `hermes_facility`를 찾지 못한다.

## 요약

| ID | 심각도 | TASK | 한 줄 |
|---|---|---|---|
| IR-S01 | 차단 | TASK-32 | 카탈로그 설치에서 둘째 키 저장이 예외로 끝나면 첫째 키는 바뀐 채 `failed`로 보고한다(보상 없음, `write_partial` 아님) |
| IR-S02 | 차단 | TASK-24(허브 연동, REQ-HF-20) | 허브에 닿지 못하면 문이 토큰을 `unknown`으로 거절해 앱이 저장한 출입증을 지운다 |
| IR-S03 | 비차단 | TASK-21·25 | 첨부 올리기가 끝날 때까지 `files.lock`을 잡아, 멈춘 올리기 하나가 모든 보내기·삭제를 막는다 |
| IR-S04 | 비차단 | TASK-21·25 | 글을 읽지 않는 기기 하나가 방송을 막아 문 전체의 기록 발행이 멈춘다(pong 미확인) |
| IR-S05 | 비차단 | TASK-32 | 비밀값 되비침 검사가 비밀이 아닌 선택값에도 걸려, 정상 응답을 `admin_unavailable`로 바꾸고 행동 기록을 빠뜨린다 |
| IR-S06 | 비차단 | TASK-21 | 방 구성원이 아닌 직원이 그 방에 글을 쓸 수 있다(문 `send`, 앱 `send` 둘 다) |
| IR-S07 | 비차단 | TASK-25 | 글 하나만 지운 경우 그 글의 첨부가 계속 내려받아지고 정리되지 않는다 |
| IR-S08 | 비차단 | TASK-21 | 기록장 파일 이름을 벽시계 달로 정해, 월 경계에서 시계가 뒤로 가면 다음 시작 때 `journal_seq_order`로 문이 뜨지 않는다 |
| IR-S09 | 비차단 | TASK-22 | 설정 쓰기와 영수증 저장 사이에 죽은 뒤 바로 `--uninstall`하면 종료 0인데 `gateway.platforms.hejo`가 남는다 |
| IR-S10 | 비차단 | TASK-22·32 | 영수증이 설치 전 `config.yaml` 전문을 제거 뒤에도 보관한다. 되돌림 금고는 문이 켜져 있을 때만 10분 뒤 지워진다 |
| IR-S11 | 비차단 | TASK-24 | LWW 시각에 상한이 없어 시계가 앞선 기기의 값이 계속 이긴다 |

차단 2건, 비차단 9건.

## 지적

### IR-S01 — 차단 — TASK-32

- **파일:줄:** `gate/connection_manager.py:220-230`(키 반복), `gate/connections.py:122-126`(검증·이전 값 읽기가 예외를 던짐), `gate/connection_manager.py:160-162`(예외를 `failed`로 바꿈)
- **시나리오:** 카탈로그 항목이 `KEY_A`, `KEY_B` 두 키를 요구한다. `KEY_A` 저장은 끝났다. `KEY_B`의 `/api/providers/validate`(또는 `/api/env/reveal`)가 2xx가 아니거나 시간 초과다. `SecretTransactions.save`는 결과를 돌려주지 않고 `ConnectionFailure`를 던진다. 반복문은 돌려받은 `outcome`만 보고 되돌리므로 이 경로에서는 `changed`를 되돌리지 않는다.
- **잘못된 결과:** `KEY_A`는 새 값으로 남는다. 앱에는 `{'outcome':'failed','reason':'CONNECTIONS_READ_FAILED'}`가 가고 행동 기록도 `failed`다. REQ-HF-32.AC-04("기존 값을 그대로")와 design 384행("보상까지 실패하면 `write_partial`… 숨기지 않는다")에 어긋난다. 되돌리기 항목은 10분 동안 남지만 사용자는 바뀐 줄 모른다.
- **근거(탐침 실행):** 가짜 관리 경로에서 `KEY_B` 검증만 502로 실패시켰다.
  `reply {'outcome': 'failed', 'reason': 'CONNECTIONS_READ_FAILED'} env {'KEY_A': 'new-a-value', 'KEY_B': 'old-b'}`, 행동 기록 `outcome: failed`.
- **같은 뿌리:** 232-237행의 설치 요청 실패는 되돌리지만, 반복문 안 예외와 226-228행 되돌리기 도중 예외(`secrets.undo`가 던지는 경우)는 잡지 않는다.

### IR-S02 — 차단 — TASK-24(허브 연동, REQ-HF-20.AC-03)

- **파일:줄:** `gate/hub.py:44-47`, `gate/server.py:236-242`(30초 재확인), `gate/server.py:368-372`(hello 거절), 앱 쪽 `app/Sources/GateClient.swift:161-165`(읽기만 함)
- **시나리오:** 허브가 잠깐 꺼져 있다(허브 재시작, 서버 재부팅 뒤 문이 허브보다 먼저 뜸, 5초 시간 초과). 그 사이 (a) 연결 중인 허브 로그인 기기의 30초 재확인이 돌거나 (b) 앱이 다시 연결한다.
- **잘못된 결과:** `HubLink.verify`가 통신 실패를 `AuthRejected("unknown")`으로 바꾼다. (a)에서는 문이 그 연결을 1008로 끊고, 이어지는 재연결과 (b)에서는 `auth_rejected{reason:"unknown"}`을 보낸다. 앱은 `auth_rejected`를 받으면 이유와 무관하게 Keychain 출입증을 지우고 `revoked`가 된다. 폐기되지 않은 정상 토큰이 허브 장애만으로 지워져, 허브가 돌아와도 모든 기기가 다시 로그인해야 한다. 같은 파일 `reset`은 이 경우를 `hub_unavailable`로 구분하는데 `verify`는 구분하지 않는다.
- **근거:** 탐침으로 닫힌 포트를 가리키는 `hub.json`에서 `verify(..., fresh=True)`가 `reason == 'unknown'`임을 확인했다. 앱 쪽 동작은 코드 읽기로만 확인했다(앱 검토자 영역). 허브 장애 때의 동작은 spec·design에 정해져 있지 않다(spec 246행은 화면 상태 맞춤만 다룸).
- **심각도 판단:** 권한 우회가 아니라 가용성 문제다. 운영 적용 때마다 허브·문을 재시작하므로 차단으로 올렸다. 앱이 저장한 비밀번호로 자동 재로그인하는 경로가 있으면 체감은 줄 수 있으나 확인하지 않았다.

### IR-S03 — 비차단 — TASK-21·25(삭제·보내기 잠금)

- **파일:줄:** `gate/server.py:143-147`(본문을 받는 동안 `files.lock` 유지), 같은 잠금을 기다리는 곳 `gate/adapter.py:666`(`receive`), `gate/adapter.py:237`(`thread_delete`), `gate/rooms.py:33`(방 명령), `gate/server.py:169`(방 사진)
- **시나리오:** 기기 하나가 `POST /v1/files`를 시작하고 본문 일부만 보낸 채 멈춘다(노트북 잠자기, 약한 망). 본문 읽기에 시간 제한이 없다.
- **잘못된 결과:** 올리기가 끝나거나 TCP가 끊길 때까지 모든 기기의 `send`·`click`·`thread_delete`·`room_save/archive/delete`·방 사진 변경이 대기한다. 보낸 기기의 웹소켓 읽기 루프도 그 프레임에서 멈춘다.
- **근거(탐침 실행):** 본문 1,000바이트만 보낸 올리기를 열어 둔 상태에서 다른 연결의 `send`가 2초 동안 응답이 없었고 `journal.head`는 0으로 남았다. `gate.files.lock.locked()`는 참이었다.

### IR-S04 — 비차단 — TASK-21·25

- **파일:줄:** `gate/server.py:259-273`(방송이 연결마다 차례로 `await conn.send`), `gate/adapter.py:188-203`(`_publish_lock`을 잡은 채 방송), `gate/server.py:430`(pong을 받아도 아무 확인 없음), `gate/server.py:243-245`(ping만 보냄)
- **시나리오:** 기기 하나가 소켓을 읽지 않는다(잠든 Mac의 반쯤 열린 연결). 직원 답·편집이 이어져 그 연결의 보내기 버퍼가 찬다.
- **잘못된 결과:** `send_json`이 배수를 기다리며 멈추고, `_record`가 `_publish_lock`을 쥔 채 멈춘다. 기록장에는 이미 쓴 글도 다른 기기에 가지 않고, 이후 모든 직원 글·편집·삭제·방 삭제 확정이 그 연결이 끊길 때까지 막힌다. design 49행은 ping/pong을 "30초 생존 확인"이라 하지만 문은 pong이 없어도 연결을 끊지 않는다.
- **근거(탐침 실행):** 읽지 않는 연결 하나를 두고 60,000자 글을 400번 보냈다. 34번째까지 돌아왔고 35번째는 8초 동안 돌아오지 않았다(`head`는 35, 즉 기록은 됐고 방송에서 멈춤).

### IR-S05 — 비차단 — TASK-32

- **파일:줄:** `gate/connection_manager.py:21-22`, `gate/connection_manager.py:165-168`
- **시나리오:** `app_connect`에서 앱이 `values.default`로 고른 항목 id(예: 캘린더 id)를 보낸다. team-kit이 `SCOPE_INVALID`와 함께 고를 수 있는 목록(`options[].id`)을 돌려준다(기본 캘린더가 읽기 전용인 경우 등, 운영 team-kit `app_connect.py`의 해당 분기를 읽어 확인). `values`의 모든 문자열을 비밀값으로 보고 응답에 들어 있으면 `ConnectionFailure('invalid_response')`를 던진다.
- **잘못된 결과:** 165행은 `try` 밖이라 예외가 `gate/server.py:410-412`까지 올라가 `{'outcome':'failed','reason':'admin_unavailable'}`가 된다. 사용자는 "다시 골라 주세요" 안내 대신 관리 기능 꺼짐 안내를 본다. 168행 행동 기록도 건너뛴다. 동작이 이미 실행된 뒤에 걸리면 실행됐는데 기록이 없다.
- **근거(탐침 실행):** `public({'outcome':'waiting','reason':'SCOPE_INVALID','options':[{'id':'cal-1',…}]}, ('cal-1',))`이 `ConnectionFailure`를 던졌다. 비밀 칸(`secure`)만 검사 대상으로 삼지 않는 것이 원인이다.

### IR-S06 — 비차단 — TASK-21

- **파일:줄:** `gate/adapter.py:318-327`(방이 있는지만 봄), `gate/adapter.py:108`(보조 문이 `room:` 주소를 그대로 넘김), `gate/adapter.py:674-678`·`705`(앱 `send`의 `employee`가 명부에만 있으면 통과)
- **시나리오 (a):** 구성원이 `default`·`alpha`인 방에, 구성원이 아닌 `beta` 프로필의 답(예약·늦은 답·도구 전송)이 `chat_id = room:<id>`로 온다. → 기록되고 방송된다.
- **시나리오 (b):** 앱이 `send{room:<id>, employee:"beta"}`를 보낸다. → 사장 글이 `employee: beta`로 기록된다(첨부 소유도 beta).
- **잘못된 결과:** 방에서 뺀 직원이나 다른 방 직원의 글이 그 방에 나타난다. 읽기(`owner_message`·`employee_message`·`first_thread_message`)는 직원 범위로 막혀 있어 유출은 아니다.
- **근거(탐침 실행):** (a) `success=True`, 방송 프레임 `employee == 'beta'`, `room` 일치. (b) `message` 프레임 `employee == 'beta'`, 오류 없음.

### IR-S07 — 비차단 — TASK-25(삭제·첨부 정리)

- **파일:줄:** `gate/journal.py:101-103`(`hidden`은 스레드·방 삭제만 봄), `gate/files.py:153-161`(`registered`), `gate/files.py:179-181`(`cleanup`), `gate/adapter.py:483`(글 단위 삭제)
- **시나리오:** 첨부가 달린 직원 글을 `delete_message`로 지운다(진행 글 정리, 나눠 보낸 글의 남는 조각 삭제).
- **잘못된 결과:** `journal.message()`는 그 글을 돌려주지 않지만 `GET /v1/files/<직원>/<file_id>`는 계속 파일을 준다. `cleanup`도 등록된 첨부로 세어 스레드나 방을 지울 때까지 남긴다.
- **근거(탐침 실행):** `send_document` → `delete_message`(참) → `message()`는 없음 → `cleanup()` 뒤에도 `registered()`가 경로를 돌려주고 파일이 있다.

### IR-S08 — 비차단 — TASK-21(기록장)

- **파일:줄:** `gate/journal.py:137-138`(쓸 때의 UTC 달로 파일 선택), `gate/journal.py:53`(이름순으로 읽음), `gate/journal.py:77-79`
- **시나리오:** 12월 1일 00:00:05(UTC)에 seq N을 `2026-12.jsonl`에 쓴 뒤 시계가 몇 초 뒤로 맞춰져, seq N+1이 `2026-11.jsonl` 끝에 붙는다.
- **잘못된 결과:** 실행 중에는 문제없지만 다음 시작 때 `journal_seq_order`로 `connect()`가 실패한다(`retryable=False`). 손으로 고치기 전까지 문이 뜨지 않는다.
- **근거(탐침 실행):** `gate.journal.datetime`을 바꿔 12월 → 11월 순서로 두 글을 쓴 뒤 새 `Journal.open()`이 `HejoJournalError: journal_seq_order`를 냈다.
- **덧붙임(읽기만):** 새 달 파일을 만든 뒤 디렉터리 fsync가 없다(`gate/journal.py:141-146`). 달의 첫 기록 직후 전원이 나가면 확정했다고 답한 기록이 파일째 없을 수 있다.

### IR-S09 — 비차단 — TASK-22

- **파일:줄:** `install/hejo-install:701-704`(쓰기 → 상태 → 영수증 저장 순서), `install/hejo-install:588-590`(`applied`만 되돌림), `install/hejo-install:458`(파일 전체 복원 조건)
- **시나리오:** 첫 설치 중 `gateway.platforms.hejo`를 `config.yaml`에 쓴 직후, 그 대상의 `applied`를 영수증에 저장하기 전에 프로세스가 죽는다. 그 뒤 바로 `--uninstall`을 한다.
- **잘못된 결과:** 영수증에는 그 대상이 `pending`이라 되돌림에서 빠진다. `text != written`이라 파일 전체 복원도 하지 않는다. 종료 0, 충돌 보고 없음, 영수증 `uninstalled`인데 `gateway.platforms.hejo` 블록이 남는다. 다시 설치하면 이 블록을 "설치 전 사장 값"으로 영수증에 적는다.
- **근거(탐침 실행):** 해당 지점에서 죽인 뒤 `run(home, uninstall=True)` → 반환 0, `config.yaml`에 `gateway: platforms: hejo: enabled: true …`가 남았다. 대상 상태는 `config.yaml#gateway.platforms.hejo: pending`.
- **참고:** 죽은 뒤 설치를 먼저 다시 실행하면("unresolved_receipt"로 1을 반환하지만 home_channel 맞춤이 `written`을 새로 고쳐) 이어지는 `--uninstall`이 파일 전체를 설치 전 원문으로 되돌린다. 순서에 따라 결과가 갈린다. 플러그인 링크도 같은 창이 있다(링크 생성 뒤 저장 전).

### IR-S10 — 비차단 — TASK-22·32(비밀값 잔류)

- **파일:줄:** `install/hejo-install:370`(`configs[file].before`·`written`에 `config.yaml` 전문), `install/hejo-install:682-683`(제거 뒤에도 영수증 유지), `gate/connections.py:72-78`·`gate/server.py:247`(되돌림 금고 지우기는 문 유지 루프에서만)
- **시나리오 1:** `config.yaml`에 키 값이 직접 적혀 있다(예: 모델 제공자 키). 설치 뒤 사장이 그 키를 바꾸거나 `.env`로 옮긴다.
- **잘못된 결과 1:** 옛 값이 `hejo/install-receipt.json`(0600)에 `--uninstall` 뒤에도 남는다. `admin_support.py:47`은 "영수증에 토큰을 넣지 않는다"고 하지만 설정 전문 사본은 예외가 된다. design 7절의 영수증 항목은 대상별 `before/after`만 말한다.
- **근거 1(탐침 실행):** 가짜 값이 든 `config.yaml`로 설치 → 제거 후 영수증에 그 값이 그대로 있었다.
- **시나리오 2:** 키를 바꾼 뒤 10분 안에 게이트웨이가 멈추거나 hejo를 제거한다.
- **잘못된 결과 2:** 이전 키 평문이 든 `hejo/undo/*.json`은 문이 다시 뜰 때까지 남는다(spec 368행 "10분 보관한 뒤 지운다"). `--uninstall`은 이 폴더를 지우지 않는다(읽기로 확인).

### IR-S11 — 비차단 — TASK-24

- **파일:줄:** `hub/state.py:36`(시각은 0 이상 유한수면 통과), `hub/state.py:53`
- **시나리오:** 시계가 앞선 기기(또는 잘못 만든 값)가 `pin:*`·`layout:*` 항목을 `at`이 먼 미래인 값으로 보낸다.
- **잘못된 결과:** 다른 기기의 이후 변경은 `at`이 작아 계속 진다. 허브는 200과 새 판 번호를 돌려주므로 보낸 쪽은 반영됐다고 본다. 그 항목은 앞선 기기가 다시 쓰기 전까지 바뀌지 않는다.
- **근거:** 코드 읽기(`wins`는 `(at, dev)` 비교뿐이고 서버 시각과 견주지 않는다). 실행하지 않았다.

## 확인했지만 문제없는 항목

- **문 주소 경계:** `/v1/ws`·`/v1/files`·`/v1/pictures` 모두 실제 TCP 상대 주소로 루프백·Tailscale 대역만 받고 전달 헤더를 믿지 않는다(`gate/server.py:41-46`, `122-131`, `337`).
- **출입증:** 토큰·짝 코드는 해시로만 저장하고 `hmac.compare_digest`로 견준다. 짝 코드는 쓰기 전에 `used`를 먼저 저장하고 5회 실패 잠금이 있다. 폐기는 0.5초마다 반영된다(`gate/auth.py`).
- **로컬 재설정:** 루프백 + 허브 연결 + 0600 일회용 증표가 모두 맞아야 하고, 쓰면 증표가 바뀐다(`gate/server.py:358-364`, `gate/auth.py:89-98`).
- **다른 회원 토큰:** 허브 `/v1/gate/verify`가 문 열쇠의 회원과 토큰의 회원이 다르면 `unknown`으로 거절한다. 문 경로는 루프백만 받는다(`hub/server.py:193-214`). 기존 시험 통과.
- **허브 회원 상태 격리:** 회원 id는 토큰에서만 나오고 파일 이름은 `uuid.UUID`로 한 번 더 거른다. 대기자도 회원별 묶음이다(`hub/state.py:62`, `hub/server.py:145-189`).
- **허브 대기·PATCH 경합:** 대기 등록 → 판 읽기 → 대기 사이에 `await`가 없고 파일 연산이 동기라 PATCH를 놓치지 않는다. 깨어난 뒤 기기 폐기를 다시 확인한다. PATCH는 회원별 `flock` 안에서 읽기·병합·원자적 교체를 한다(`hub/server.py:160-177`, `hub/state.py:97-116`). `test_state_wait.py`·`test_member_state.py` 통과.
- **읽음 seq:** `read:`·`thread:`는 큰 값만 이긴다. 값 형식·크기·한도 잘라내기 확인.
- **허브 로그:** 메서드·경로·상태·거절 이유만 남기고 본문·토큰·아이디는 남기지 않는다(`hub/server.py:62-77`).
- **기록장 쓰기:** 한 잠금 안에서 `head+1` 부여 → 쓰기 → fsync. 실패하면 잘라 되돌리고, 되돌림도 실패하면 `faulted`로 이후 쓰기를 막는다. 정상 경로에서 seq 빈칸·중복이 생기지 않는다(`gate/journal.py:129-162`). 복구는 꼬리 손상만 자르고 중간 손상은 거절한다.
- **재현 seq 연속:** 지운 방·스레드의 기록을 빼지 않고 같은 seq의 `delete`·`room{deleted}`·`room_deleted`로 바꿔 보낸다. 옛 클라이언트에도 같은 seq의 `delete`로 보낸다(`gate/journal.py:115-127`, `gate/server.py:275-279`).
- **room_delete 확정점:** 기록 한 줄이 확정이다. 쓰기 실패면 아무것도 지우지 않고 `journal_write_failed`. 확정 뒤 정리가 실패해도 시작 때 `cleanup_rooms()`가 다시 한다. 지운 방 id 재사용·보내기·늦은 답·편집·작성 중·상태는 모두 거절하거나 버린다(`gate/rooms.py:32-75`, `gate/adapter.py:186-196`, `123`). `test_rooms.py` 통과.
- **thread_delete 확정점:** 범위 `delete` 한 줄이 확정이다. 나머지 글 `delete`가 중간에 끊겨도 `hidden()`·`replay()`가 범위 기록으로 가리고, 시작 때 `_finish_thread_deletions()`가 이어 쓴다. 같은 요청을 다시 보내면 확정 기록을 돌려준다(`gate/adapter.py:224-261`). `receive`와는 `files.lock`, 직원 글과는 `_publish_lock`으로 순서가 정해진다. `test_threads.py` 통과.
- **분기:** `branch_client_msg_id`로 중복을 막고 지운 방·스레드는 거절한다(`gate/adapter.py:263-294`).
- **보내기 중복:** `client_msg_id` 확인과 기록이 같은 `files.lock` 안에 있어 같은 글이 두 번 기록되지 않는다(`gate/adapter.py:682-709`).
- **owner_message / employee_message:** 글의 역할·스레드·대화 주소를 모두 확인한다. 방은 그 글의 `recipients`에 든 직원만, 1:1은 그 직원만 읽는다. 지운 스레드·방의 글은 `message()`가 돌려주지 않는다. 보조 문은 호출자가 준 프로필을 버리고 자기 `_owner_profile`을 넣는다(`gate/adapter.py:94-95`, `527-564`). `test_owner_query.py`·`test_employee_query.py` 통과.
- **_delivery_scope:** `asyncio.gather`가 직원마다 따로 태스크를 만들어 범위가 섞이지 않는다. 범위가 있으면 다른 대화·다른 스레드·다른 직원 글은 지우지 못한다. 보조 문 경로는 자기 프로필 글만 지운다(`gate/adapter.py:461-486`, `727-735`). `test_progress.py`·`test_gateway_progress.py` 통과.
- **post-delivery 콜백:** 보조 문이 등록·꺼내기를 기본 문으로 넘긴다. 세션 키에 프로필 이름 공간이 들어 있어 같은 방·같은 스레드의 두 직원이 겹치지 않는다(Hermes 본체 `build_session_key`를 읽어 확인, 본체는 고치지 않음).
- **보조 문 전달:** 편집·상태 변경은 그 글의 `employee`가 자기 프로필일 때만 넘긴다. `hermes_profile`은 어댑터가 덮어쓴다(`gate/adapter.py:96-108`, `589-603`).
- **첨부 경로:** 직원 id·파일 id를 정규식으로 거르고 심볼릭 링크·`..`를 거절한다. 내려받기는 기록장에 등록된 경로와 정확히 같을 때만 준다(`gate/files.py`).
- **사진 경로:** 식별자는 `[A-Za-z0-9_-]{1,128}`만 받고 심볼릭 링크 구성 요소를 거절한다. PNG는 틀·CRC·압축 풀기까지 한도 안에서 확인한다. 방 사진 변경은 기록장 쓰기가 실패하면 이전 파일로 되돌린다(`gate/pictures.py`, `gate/server.py:165-187`). `test_pictures.py` 통과.
- **도구 연결 권한:** 명부에 없는 프로필 거절, 쓰기 동작은 `reauth` 필요, 허용 동작은 문이 방금 다시 읽은 목록에서만 고른다. OAuth 세션·재시작 작업은 요청한 기기만 조회한다. team-kit 실행은 고정 실행 파일과 인자 목록이고 값은 stdin으로만 간다(`gate/connection_manager.py:136-170`, `gate/connection_runtime.py:147-200`).
- **비밀값 노출:** `values`는 처리 뒤 프레임에서 지운다. 응답은 허용 키만 통과시키고 `secure` 칸의 `value`는 뺀다. 행동 기록에 값이 없다. 관리 토큰은 요청 헤더로만 쓰고 예외 문자열을 버린다. 디스패치 예외 로그는 형식과 스택만 남긴다(`gate/server.py:402-414`, `432-437`, `gate/connections.py:30-58`). `test_connections.py` 통과.
- **단일 키 보상:** 쓰기 실패 → 공식 경로로 되돌림 → 존재 여부 확인 → 실패면 `write_partial`과 되돌림 파일 유지(`gate/connections.py:117-141`). 기존 시험 통과. (여러 키 경로만 IR-S01.)
- **hejo-admin·admin_support:** `admin.json`은 0600·심볼릭 링크 아님을 확인하고 127.0.0.1만 연다. 영수증에는 파일 지문만 넣는다. 영수증 없이 이미 있는 파일은 `preserved_owner_change`로 두고, 제거는 지문이 같을 때만 지운다.
- **home_channel 영수증:** 설치 전에 값이 있으면 대상을 만들지 않는다. 사장이 바꾸거나 지운 값은 `released`로 놓아 제거·롤백·`--force`에서도 건드리지 않는다. `removing` 단계로 쓰기와 영수증 사이 끊김을 구분한다. `--uninstall-home-channel`은 그 키만 지우고 다른 대상과 `installed` 상태를 둔다(`install/hejo-install:472-539`, `664-674`). `test_install.py` 통과.
- **--uninstall의 다른 대상:** 현재 값이 `after`와 같을 때만 되돌리고 다르면 충돌(종료 2)로 남긴다. 파일 전체 복원은 현재 글이 설치 도구가 마지막에 쓴 글과 바이트까지 같을 때만 한다. `--force`가 사장이 나중에 바꾼 `plugins.enabled`를 설치 전 목록으로 되돌리는 것은 design 434행에 적힌 동작이다.
- **줄 단위 편집:** ruamel이 그대로 재현하지 못하는 파일은 hejo 키의 줄만 고치고, Hermes 읽기 결과와 왕복 결과를 모두 견준 뒤에만 쓴다(`install/hejo-install:270-303`).

## TASK별 결론

| TASK | 결론 |
|---|---|
| TASK-20(문: 사진·명부) | 통과 |
| TASK-21(단체방: 기록장·전달·방송·삭제) | 지적 있음 — IR-S03·S04·S06·S08(모두 비차단). `room_delete` 확정점 자체는 통과 |
| TASK-22(홈 채널 설치·되돌림) | 지적 있음 — IR-S09·S10(비차단). 사장 값 보존은 통과 |
| TASK-24(허브: 회원 상태) | 지적 있음 — IR-S02(차단, 허브·문 연동), IR-S11(비차단). 대기·PATCH 경합과 회원 격리는 통과 |
| TASK-25(문: 분기·삭제) | 지적 있음 — IR-S03·S04·S07(비차단). `thread_delete` 확정점은 통과 |
| TASK-32(도구 연결·비밀값) | 지적 있음 — IR-S01(차단), IR-S05·S10(비차단) |
| 추가 범위(문 최근 변경) | 통과 |
