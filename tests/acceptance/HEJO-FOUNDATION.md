# HEJO-FOUNDATION 수락 시험 명세

- 소유: 기획설계. 2판(계획 검증 1회차 반영). 기대값 근거: [spec.md](../../docs/changes/HEJO-FOUNDATION-20261114/spec.md) 요구와 [design.md](../../docs/changes/HEJO-FOUNDATION-20261114/design.md) 규격(2·2.1·2.2·3·7절), Hermes 공개 함수 계약(경로는 design 참조).
- 상태 열: 명세 / 코드 작성 / 실행 결과 / 독립 검토. 현재 모두 "명세 완료 · 코드 미작성 · 미실행 · 미검토". 코드는 구현 담당이 `tests/acceptance/`에 옮기며 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 공통 환경: 임시 `HERMES_HOME`(가짜 명부: 프로필 `alpha`, `beta`; 표시 이름 `Alpha`, 별칭 `al`), 실제 Hermes 본체 모듈 import(Hermes venv), 게이트웨이 러너는 시험 대역(`R/tests/gateway/restart_test_helpers.py` 방식) 또는 문 어댑터 단독. 운영 홈·실제 Slack 사용 금지. 증거 수준은 별도 표시가 없으면 2(대역 통합).

| 시험 ID | AC | 종류 | 절차 | 합격 기준 |
|---|---|---|---|---|
| AT-HF-01 | REQ-HF-01.AC-01 | 자동 | 기본 프로필 설정(`listen:[127.0.0.1]`, 임의 빈 포트)으로 connect | 그 주소·포트만 LISTEN(다른 인터페이스 없음), `is_connected` 참 |
| AT-HF-02 | REQ-HF-01.AC-02 | 자동 | (a) 기본 문이 포트 P를 연 상태에서 `set_owner_profile("beta")`인 두 번째 어댑터 connect; (b) 기본 문보다 먼저 보조 어댑터 connect 후 기본 문 connect; 시험 내내 파일 열기 감사 | (a)(b) 모두 포트 P 외 새 LISTEN 없음, 보조 어댑터 연결됨, 보조 어댑터가 기록장·`devices.json`·`pairing.json`을 열지 않음, 기본 문 계속 응답. (5판 개정: 비활성 → 전달자) |
| AT-HF-49 | REQ-HF-01.AC-03 | 자동 | 보조 어댑터(`beta`)로 `send`, `edit_message`, `send_typing`/`stop_typing`, `metadata.hejo_buttons` 글, 첨부 1개 글 | 앱이 각각 `employee:"beta"`의 `message`·`edit`·`typing`·버튼 포함 `message`·`files[]` 포함 `message` 수신, 기록장 행의 직원도 `beta` |
| AT-HF-50 | REQ-HF-01.AC-04 | 자동 | 기본 문 없이(또는 disconnect 뒤) 보조 어댑터로 `send` | `SendResult.success == False`, 실패 이유 로그, 기록장 행 0, 다른 어댑터 송신 0 |
| AT-HF-03 | REQ-HF-02.AC-01 | 자동 | CLI `pair`로 코드 발급 → `hello{pair_code}` | `welcome.token` 길이 ≥ 43(base64url 256비트), 같은 코드 재사용 시 `pair_rejected(used)` |
| AT-HF-04 | REQ-HF-02.AC-02 | 자동 | 만료(시계 +601초), 틀린 코드 5회 후 올바른 코드 | 각각 `expired`, `wrong`×5, `locked`; 출입증 0개 추가 |
| AT-HF-05 | REQ-HF-02.AC-03 | 자동 | 연결 중 CLI `revoke <device_id>` | 2초 안에 소켓 닫힘, 같은 출입증 `hello` → `auth_rejected(revoked)` |
| AT-HF-06 | REQ-HF-03.AC-01 | 자동 | 상대 주소를 192.168.0.10, 100.100.1.1, 127.0.0.1로 각각 주입 | 192.168.0.10만 핸드셰이크 전 닫힘 |
| AT-HF-07 | REQ-HF-03.AC-02 | 자동 | AT-HF-03~05 뒤 로그 캡처·기록장·`devices.json` 검색 | 코드·출입증 평문 0건, `devices.json` 권한 0600 |
| AT-HF-08 | REQ-HF-04.AC-01 | 자동 | 명부 있는 홈 / 명부 없는 홈에서 `welcome`, 이어서 `roster{id:"r1"}` | 두 응답의 직원 id 집합 = {default, alpha, beta}; `roster.ref == "r1"`; 명부 있을 때 `alpha.name == "Alpha"`, `aliases == ["al"]`; 없을 때 `name == id` |
| AT-HF-09 | REQ-HF-04.AC-02 | 자동 | 연결 중 프로필 `gamma` 생성(`create_profile`) 뒤 `roster` | 응답에 `gamma` 포함 |
| AT-HF-10 | REQ-HF-05.AC-01 | 자동 | `send{employee:"alpha", thread:T}` → 대역 핸들러가 받은 이벤트 확인, 대역이 `send(chat_id="alpha", metadata={"thread_id":T,"hermes_profile":"alpha"})` 호출 | 이벤트 `source.profile == "alpha"`, `user_id == "owner"`, 세션 키 `agent:alpha:hejo:dm:alpha:T` 형태; 앱이 `message{employee:"alpha", thread:T, role:"employee"}` 수신 |
| AT-HF-11 | REQ-HF-05.AC-02 | 자동 | 스레드 T1, T2로 각각 send | 두 세션 키가 다름 |
| AT-HF-12 | REQ-HF-05.AC-03 | 자동 | 대역이 `send_typing`→`send`→`edit_message`×3→`edit_message(finalize=True)`→`stop_typing` | 앱 수신: `typing on`, `message`, `edit`(1~3개, 마지막 `final:true` 본문 = 최종 본문), `typing off`; 모든 edit의 `msg_id` 동일 |
| AT-HF-13 | REQ-HF-06.AC-01 | 자동 | 앱 끊음 → 대역이 답장 3개 생성 → `hello{token, since:N}` | 빠진 3프레임을 seq 오름차순으로 수신, `sync_done{through:N+3, more:false}`, 중복 0 |
| AT-HF-14 | REQ-HF-06.AC-02 | 자동 | 기록장 파일 쓰기 실패 주입 후 답장 | 그 프레임 미전송, 앱 `error(journal_write_failed)`, 파일 길이 추가 전과 같음, 어댑터·대역 러너 예외 없이 계속, 다음 정상 프레임 seq = 실패 전 마지막 seq + 1 |
| AT-HF-32 | REQ-HF-06.AC-03 | 자동 | 기록 1,203개 상태에서 `hello{since:0}` 후 앱이 `more`가 거짓이 될 때까지 `sync{since:through}` 반복 | `sync_done` 3회(`through` 500, 1000, 1203; `more` 참, 참, 거짓), 받은 seq = 1..1203 정확히 한 번씩 |
| AT-HF-33 | REQ-HF-06.AC-04 | 자동 | 재전송 1페이지 전송 중 대역이 새 기록 프레임 20개 생성 | 앱이 2.1 규칙으로 적용한 seq 열이 1..(1203+20) 빈칸·중복 없이 연속, 실시간 대기열 프레임은 마지막 `sync_done(more:false)` 뒤에만 도착 |
| AT-HF-34 | REQ-HF-06.AC-05 | 자동 | 기기 두 대(출입증 2개) 동시 연결, 대역이 프레임 10개 생성 | 두 기기 수신 seq 열 동일·같은 순서 |
| AT-HF-35 | REQ-HF-06.AC-06 | 자동 | 기록장에 완전한 줄 5개 + 끝 `\n` 없는 반쪽 줄을 만든 뒤 문 시작, 새 프레임 1개 | 반쪽 줄 제거 로그, 새 프레임 seq = 6, `sync{since:0}`로 1..6 수신. 월 파일이 둘(이전 달 1..5, 이번 달 비어 있음)인 경우도 seq 6 |
| AT-HF-36 | REQ-HF-06.AC-07 | 자동 | 같은 `HERMES_HOME`으로 문 두 개를 시작 | 두 번째는 리스너를 열지 않고 `retryable=False` 실패, 첫 번째 계속 |
| AT-HF-44 | REQ-HF-06.AC-08 | 자동 | 연결 인증 처리 중(welcome 전송 직전)에 대역이 기록 프레임 3개 생성, `since` 없는 hello; 별도로 `hello{since: head+5}` | 첫 수신 프레임이 `welcome`; 그 뒤 `sync_done`까지 `welcome.head_seq` 다음 프레임 전부 순서대로(빠짐·중복 0); 두 번째는 `error(invalid_since)` 후 닫힘 |
| AT-HF-45 | REQ-HF-05.AC-05 | 자동 | `send_typing("alpha", {thread_id:T1})`, `send_typing("alpha", {thread_id:T2})`, `stop_typing("alpha")` | `typing on`(T1, `ttl_seconds:6`), `typing on`(T2), 이어서 T1·T2 각각 `on:false` |
| AT-HF-46 | REQ-HF-07.AC-03 | 자동(스키마) | 스키마로 `message{files:[{file_id, name, mime, size}]}` 검증, 필드 하나 빠짐·추가 필드·`name`에 `/` 포함 | 앞은 유효, 뒤 셋은 무효 |
| AT-HF-15 | REQ-HF-07.AC-01 | 자동 | `POST /v1/files?employee=alpha` 후 `send{employee:"alpha", files:[id]}` | 이벤트 `media_urls`에 저장 파일 절대 경로 1개, `media_types` 일치 |
| AT-HF-16 | REQ-HF-07.AC-02 | 자동 | `GET /v1/files/alpha/<미등록 id>`, `GET /v1/files/alpha/..%2F..%2Fx`, 출입증 없이 `GET /v1/files/alpha/<alpha id>`, **`beta` 소유로 등록된 id를 `GET /v1/files/alpha/<beta id>`** | 404, 404, 401, 404. 같은 id를 `GET /v1/files/beta/<beta id>`는 200 |
| AT-HF-51 | REQ-HF-07.AC-04 | 자동 | (a) `POST /v1/files?employee=alpha` 직후 `GET /v1/files/alpha/<id>`; (b) 같은 id로 `send{employee:"beta", files:[id]}`; (c) 업로드 → 문 재시작(같은 홈) → `send{employee:"alpha", files:[id]}` → `GET /v1/files/alpha/<id>`; (d) 대기 칸 항목 시각을 25시간 전으로 바꾸고 문 재시작 | (a) 404; (b) `error(unknown_file)`, 기록장 행 증가 0, 직원 이벤트 0; (c) 사장 `message`의 `files[]` 1개, GET 200·내용 일치; (d) 그 항목 삭제 |
| AT-HF-17 | REQ-HF-08.AC-01 | 자동 | 대역이 `_send_exec_approval_prompt`, `send_clarify`, `send_slash_confirm` 호출 → 앱 `click` | 각각 `resolve_gateway_approval`(세션 키·choice), `resolve_gateway_clarify`(id·응답), `slash_confirm.resolve` 호출 인자 일치(모의 객체) |
| AT-HF-18 | REQ-HF-08.AC-02 | 자동 | `resolve_gateway_approval`가 0을 반환하게 하고 클릭 | 앱 `error(button_expired)`, 다른 호출 없음 |
| AT-HF-19 | REQ-HF-09.AC-01 | 자동(team-kit 시험) | team-kit hejo 등록 + 문 대역에 `"검토해줘\n[[버튼: 승인 \| 거절]]"` 전송 | 앱 `message.text`에 표식 없음, `buttons` 라벨 `["승인","거절"]`·`kind:"reply"`, `reply_state:"asked"` |
| AT-HF-20 | REQ-HF-09.AC-02 | 자동(team-kit 시험) | 위 글의 승인 버튼 클릭 → 대역 차례 → 최종 답장 | 이벤트 텍스트 "승인", `raw_message._hermes_button.label == "승인"`, 문맥에 누른 글 포함, `state answered` 뒤 `state closed` |
| AT-HF-21 | REQ-HF-09.AC-03 | 자동 | team-kit 없는 홈에서 같은 글 | `buttons` 비어 있음, 본문 끝에 `승인 / 거절` |
| AT-HF-22 | REQ-HF-10.AC-01 | 자동 + 실환경(3) | 전달자(4.1 A)로 보조 프로필 `beta`의 예약 작업 `deliver=hejo` 실행과 `send_message` 실행(임시 홈 실제 게이트웨이, 자기 시험 연결을 가진 보조 프로필) | 앱이 `employee:"beta"`의 새 스레드 `message` 수신; 앱 끈 상태면 재접속 sync로 수신; 리스너 1개; 다른 연결 송신 0 |
| AT-HF-37 | REQ-HF-05(권한) | 자동 | 허용 사용자 `owner` 설정으로 send, 설정을 `["someone"]`으로 바꿔 send | 앞은 차례 실행, 뒤는 차례 미실행(허용 거부) |
| AT-HF-23 | REQ-HF-11.AC-01 | 자동 | `bash app/scripts/build.sh` | `CFBundleIdentifier == io.github.hermes-hejo.hejo`(ddots와 다름), `codesign --verify --strict` 0 |
| AT-HF-24 | REQ-HF-11.AC-02 | 자동(UI 점검 모드) | 임시 문(대역)에 페어링 → 앱 재시작 | 키체인 서비스 `io.github.hermes-hejo.hejo.gate-token`에 항목, `hejo-local.json`에 출입증 문자열 없음, 재시작 후 `welcome` 수신 |
| AT-HF-25 | REQ-HF-11.AC-03 | 자동(UI 점검 모드) | 문 중지 → 10초 → 문 시작 | 상태 표시 "연결 끊김", 재시도 간격 증가(1,2,4…최대 30초), 문 시작 후 30초 안에 자동 복구 |
| AT-HF-26 | REQ-HF-12.AC-01 | 수동(체크리스트) + 나란히 비교 | 직원 전환, 스레드 열기, 새 스레드, 보내기, 버튼 누름, 첨부 보내기·열기, 안 읽은 수, 탭 줄 끌기(목록·숨김), 끊김 띠, 닫힌 상태 안 읽은 표시를 hejo(가짜 명부·문 대역)와 ddots에서 같은 창 크기로 촬영 | 각 상태에서 배치·크기·간격·색·글꼴이 ddots와 같음(빠진 것은 design 6절의 제외 목록뿐). 나란히 비교 스크린샷 `evidence/HEJO-FOUNDATION/`(ddots 쪽은 개인 내용이 보이지 않게 가림) |
| AT-HF-47 | REQ-HF-16.AC-01 | 자동(배치·상태) + 수동(체크리스트) | 앱 시험: 펫 클릭·메뉴 "대화 열기"·다시 클릭·Esc·"펫으로 접기"를 차례로 실행하고, 동작 줄이기를 켠 상태로 반복; 수동: 다른 앱에 입력 중 펫 클릭 | 열림/닫힘 상태가 각 동작대로 바뀜, 변형 시작·끝 사각형이 펫 발치 기준(`PetPlacement`) 값과 같음, 동작 줄이기면 변형 단계 0; 열기·닫기 동안 다른 앱 포커스 유지, 스크린샷·화면 녹화 증거 `evidence/HEJO-FOUNDATION/` |
| AT-HF-48 | REQ-HF-16.AC-02 | 자동(배치) | 펫 3 px·5 px 끌기, 대화 연 채 끌기, 가짜 화면 2개에서 두 번째 화면 가장자리로 이동, 화면 구성 변경 알림 | 3 px는 클릭(열림), 5 px는 이동(상태 불변); 대화 창이 펫과 함께 이동; 대화 창 사각형이 펫 발치 화면의 보이는 영역 안; 변경 알림 뒤 화면 안으로 다시 맞춤 |
| AT-HF-27 | REQ-HF-13.AC-01 | 자동 | 보조 프로필 1개(`beta`)가 있는 빈 임시 홈에 `hejo-install` 2회, `--check` | 기본·보조 프로필 각각의 링크·`plugins.enabled`·`gateway.platforms.hejo`(보조는 `extra.role: forwarder`, 포트 없음)·`<HOME>/hejo/`(0700)·`devices.json`(0600) 생성; 2회차 파일 변경 0(바이트 동일); `--check` 종료 0 |
| AT-HF-28 | REQ-HF-13.AC-02 | 자동 | (보조 프로필 대상도 같은 방식으로 영수증에 포함) 기존 `plugins.enabled: [x, y]`, 기존 `gateway.platforms.hejo: {enabled: false, extra: {port: 1}}`, 기존 `<HOME>/plugins/hejo` 링크(다른 대상)인 홈에서 설치 → `--uninstall` | 세 대상이 설치 전 값·링크 대상과 같음(주석 포함 `config.yaml` 해당 부분 동일), `<HOME>/hejo/`·`<HOME>/shared/hejo/` 남음, 영수증 `uninstalled` |
| AT-HF-38 | REQ-HF-13.AC-03 | 자동 | 설치 뒤 `extra.port`를 47999로 바꾸고 `--uninstall` | 종료 코드 2, `gateway.platforms.hejo` 그대로(47999), 나머지 대상은 되돌림, 충돌 보고에 대상 경로 |
| AT-HF-39 | REQ-HF-13.AC-04 | 자동 | 링크 단계 뒤 설정 쓰기에서 실패 주입 | 종료 코드 1, 홈의 대상 전부 설치 전과 같음(예외: `<HOME>/hejo/` 디렉터리와 그 안의 `install-receipt.json`만 남고 `devices.json`은 없음, 7판), 영수증 `failed` |
| AT-HF-40 | REQ-HF-13.AC-05 | 자동 | 설치 → 사장이 `plugins.enabled`에 z 추가 → 재설치; 시험 내내 파일 열기 감사(`sys.addaudithook`의 `open`) | 영수증 `before` 불변, z 유지; 열린 경로에 `.env`·`auth.json`·`token`·`secret` 포함 0건 |
| AT-HF-29 | REQ-HF-14.AC-01 | 자동 | 가짜 명부 단어(`Alpha`)를 넣은 임시 추적 파일 | 종료 코드 ≠0, 출력에 `Alpha` 없음(지문만) |
| AT-HF-42 | REQ-HF-14.AC-03 | 자동 | 임시 저장소에 가짜 명부 단어 또는 `/Users/someone/x` 경로를 넣은 (a) `#!`로 시작하는 확장자 없는 파일 `install/fake-tool`, (b) `githooks/pre-commit`, (c) `notes.toml`, (d) 바이너리(NUL 포함) 파일을 각각 추적 | (a)(b)(c) 각각 검출·종료 코드 ≠0, (d)는 "바이너리 생략"으로 표시, 값 출력 없음 |
| AT-HF-43 | REQ-HF-14.AC-03 | 자동 | LICENSE 고지 줄을 예외 목록에 등록, 같은 LICENSE에 가짜 명부 단어 줄 추가; 다음으로 고지 줄 내용을 바꿈 | 추가한 줄 검출(종료 ≠0); 내용이 바뀐 고지 줄도 검출(지문 불일치) |
| AT-HF-41 | REQ-HF-14.AC-02 | 자동 | 가짜 운영 홈에 `owner/team.yaml`, `owner/vault.yaml`, `.env`, `auth.json`, `state.db`를 두고 검사, 파일 열기 감사 | 운영 홈에서 열린 경로 = 앞의 두 파일뿐 |
| AT-HF-30 | REQ-HF-15.AC-01 | 확인(3) | 운영 루트 `~/.hermes/config.yaml`과 `~/.hermes/profiles/*/config.yaml`을 YAML로 읽기, 변경 전후 다른 키 비교 | 모든 파일 `prompt_caching.cache_ttl == "auto"`, 다른 키 차이 0, 운영 저장소에 해당 동기화 커밋 |
| AT-HF-31 | REQ-HF-05·06·10, NFR-HF-04 | 실물(4) | 노트북 hejo ↔ Tailscale ↔ 공항 Mac 운영 공항, 실제 직원 1명과 대화·버튼·첨부·예약 보고 1건 | 모두 동작, 지연(보내기→첫 작성 중 표시, 보내기→답장 시작) 각 5회 측정 기록 |
| AT-HF-52 | REQ-HF-17.AC-01 | 자동 | 앱 시험: 대화 창을 펼친 뒤 로고 칸 글자와 속성, 버전 글자, 방 없음 머리글을 읽음 | `HEJO.`, 첫 글자 색 systemBlue, 나머지 기본 글자색; 버전 = 번들 `CFBundleShortVersionString`; 방 없음 머리글 `HEJO.` |
| AT-HF-53 | REQ-HF-18.AC-01·02·06 | 자동 | 가짜 모델 상태: (a) A=2,U=5; (b) A=0,U=3; (c) A=0,U=0, 작성 중 없음; (d) A=2,U=5와 작성 중 직원 1명(경과 2분); (e) 작성 중 4명; (f) 머리글 폭을 좁혀 최대 너비 초과; (g) 상태 바꾸기를 반복 | 알약 x = 로고 칸 오른쪽+12, 높이 30 유지; (a) 빨간 점·"2"·"5"; (b) 점 없음·"3"; (c) 44×12 띠; (d) 두 칸이 선으로 나뉨·"일하는 중"·"2분"·반짝임 빛 띠 위치가 시계 주입 0/0.8초에서 다름(도는 고리 보기 없음); (e) 얼굴 3개·"4명 일하는 중"; (f) 직원 칸 얼굴만, 알약이 최대 너비 안; (g) 높이 변화 0, 방 제목 시작 x = 알약 오른쪽+12 |
| AT-HF-54 | REQ-HF-18.AC-03 | 자동(시계 주입) | 새 `asked` 글 도착; 3.9초·4.1초 시점 상태; 다른 스레드에서 작성 중이던 직원의 새 글 도착; 3.1초 시점; 두 사건 겹침 | 4초 동안 "답 요청" 늘어남 → 그 뒤 기본; 3초 동안 "답글 · 보기 ›" → 기본; 겹치면 차례대로, 늘어난 동안 다른 칸은 아이콘만 |
| AT-HF-55 | REQ-HF-18.AC-04·06 | 자동 | 연결 → 끊김(재시도 3초) → 재연결; 보내기 실패 글 1건 → 다시 보내기 성공; 첨부 3개 올리기 중 2개 완료 | 끊김: 알약 하나·주황 테두리·"3초 뒤 다시 연결"·A/U 숨김, 연결 끊김 띠 표시 0; 재연결: 2초 "다시 연결됨"; 실패: "보내지 못함"과 첫 말 유지 → 성공 뒤 사라짐; 업로드 "2/3" |
| AT-HF-56 | REQ-HF-18.AC-05·06 | 자동 + 수동(TASK-09) | 사장 차례 칸 클릭(asked 3건, 서로 다른 방); 직원 칸 클릭; 문제 칸 클릭(끊김·실패); 사장 차례 칸에 마우스 올림; 알약 위에서 끌기; 동작 줄이기 | 가장 오래된 asked 글의 방이 선택되고 카드가 펼쳐지며 1.5초 강조; 그 직원 탭 선택; 즉시 재접속 시도 1회·다시 보내기 1회; 질문 한 줄과 "열기 ›", 버튼 0개, 높이 30; 창 위치 변화 0; 너비 애니메이션 단계 0·글자 반짝임 정지(흐린 글자) |
| AT-HF-57 | REQ-HF-19.AC-01~03 | 자동(시계 주입) | (a) 작성 중 켜짐, 흘러나오는 글 없음, 0초·12초·65초 시점; (b) 같은 스레드에 `streaming` 글 도착 → 0초·0.6초 시점; (c) final 편집; (d) 동작 줄이기 | (a) 작성 중 줄 글자 "작성 중"·"12초"·"1분 5초", "● ● ●" 없음, 반짝임 빛 위치가 0초와 0.8초에서 다름; (b) 작성 중 줄 없음, 커서 보기가 본문 끝 글자 오른쪽에 있음, 0초와 0.6초에서 켜짐/꺼짐이 다름, 글 높이는 커서가 없을 때와 같음; (c) 커서 없음; (d) 반짝임·깜빡임 단계 0, 커서 켜짐 고정 |
| AT-HF-58 | REQ-HF-20.AC-01·04 | 자동 | 문 시작 뒤 로컬 파일 권한·포트; 그 코드로 루프백 페어링; 같은 코드 재사용; 새 코드를 Tailscale 주소에서 사용; 앱의 파일 파싱·잘못된 파일·파일 우선 | 0600·포트 일치; welcome; 파일 코드 교체·재사용 `wrong`; Tailscale 주소 `wrong`; 앱은 파일이 있으면 Tailscale을 보지 않고 `127.0.0.1:port`로 페어링 |
| AT-HF-59 | REQ-HF-20.AC-02·03 | 자동 + 실물(TASK-09) | 문: Tailscale 주소 + 같은 사용자 → `auto`; 다른 사용자; 루프백 `auto`; whois 응답 누락. 앱: status JSON에서 후보 순서, 열린 첫 기기 선택, tailscale 없음 | welcome·기기 이름 = Tailscale 이름; `untrusted`; `untrusted`이고 tailscale 호출 0; 거부. 후보 = 온라인·Mac 먼저·IPv4; 연결 주소 = 열린 기기:47820; 찾지 못함 |
