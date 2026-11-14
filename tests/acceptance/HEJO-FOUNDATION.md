# HEJO-FOUNDATION 수락 시험 명세

- 소유: 기획설계. 2판(계획 검증 1회차 반영). 기대값 근거: [spec.md](../../docs/changes/HEJO-FOUNDATION-20261114/spec.md) 요구와 [design.md](../../docs/changes/HEJO-FOUNDATION-20261114/design.md) 규격(2·2.1·2.2·3·7절), Hermes 공개 함수 계약(경로는 design 참조).
- 상태 열: 명세 / 코드 작성 / 실행 결과 / 독립 검토. 현재 모두 "명세 완료 · 코드 미작성 · 미실행 · 미검토". 코드는 구현 담당이 `tests/acceptance/`에 옮기며 기대값·합격 기준을 바꾸지 않는다. 바꿔야 한다고 판단되면 멈추고 보고한다.
- 공통 환경: 임시 `HERMES_HOME`(가짜 명부: 프로필 `alpha`, `beta`; 표시 이름 `Alpha`, 별칭 `al`), 실제 Hermes 본체 모듈 import(Hermes venv), 게이트웨이 러너는 시험 대역(`R/tests/gateway/restart_test_helpers.py` 방식) 또는 문 어댑터 단독. 운영 홈·실제 Slack 사용 금지. 증거 수준은 별도 표시가 없으면 2(대역 통합).

| 시험 ID | AC | 종류 | 절차 | 합격 기준 |
|---|---|---|---|---|
| AT-HF-01 | REQ-HF-01.AC-01 | 자동 | 기본 프로필 설정(`listen:[127.0.0.1]`, 임의 빈 포트)으로 connect | 그 주소·포트만 LISTEN(다른 인터페이스 없음), `is_connected` 참 |
| AT-HF-02 | REQ-HF-01.AC-02 | 자동 | 기본 문이 포트 P를 연 상태에서 `set_owner_profile("beta")`인 두 번째 어댑터 connect | 포트 P 외 새 LISTEN 없음, 두 번째 어댑터는 `retryable=False` 실패로 끝나고 재연결 예약 없음, 기본 문은 계속 응답. (탐침 뒤 전달자 결정 시 계획 담당이 이 행을 개정) |
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
| AT-HF-15 | REQ-HF-07.AC-01 | 자동 | `POST /v1/files?employee=alpha` 후 `send{employee:"alpha", files:[id]}` | 이벤트 `media_urls`에 저장 파일 절대 경로 1개, `media_types` 일치 |
| AT-HF-16 | REQ-HF-07.AC-02 | 자동 | `GET /v1/files/alpha/<미등록 id>`, `GET /v1/files/alpha/..%2F..%2Fx`, 출입증 없이 `GET /v1/files/alpha/<alpha id>`, **`beta` 소유로 등록된 id를 `GET /v1/files/alpha/<beta id>`** | 404, 404, 401, 404. 같은 id를 `GET /v1/files/beta/<beta id>`는 200 |
| AT-HF-17 | REQ-HF-08.AC-01 | 자동 | 대역이 `_send_exec_approval_prompt`, `send_clarify`, `send_slash_confirm` 호출 → 앱 `click` | 각각 `resolve_gateway_approval`(세션 키·choice), `resolve_gateway_clarify`(id·응답), `slash_confirm.resolve` 호출 인자 일치(모의 객체) |
| AT-HF-18 | REQ-HF-08.AC-02 | 자동 | `resolve_gateway_approval`가 0을 반환하게 하고 클릭 | 앱 `error(button_expired)`, 다른 호출 없음 |
| AT-HF-19 | REQ-HF-09.AC-01 | 자동(team-kit 시험) | team-kit hejo 등록 + 문 대역에 `"검토해줘\n[[버튼: 승인 \| 거절]]"` 전송 | 앱 `message.text`에 표식 없음, `buttons` 라벨 `["승인","거절"]`·`kind:"reply"`, `reply_state:"asked"` |
| AT-HF-20 | REQ-HF-09.AC-02 | 자동(team-kit 시험) | 위 글의 승인 버튼 클릭 → 대역 차례 → 최종 답장 | 이벤트 텍스트 "승인", `raw_message._hermes_button.label == "승인"`, 문맥에 누른 글 포함, `state answered` 뒤 `state closed` |
| AT-HF-21 | REQ-HF-09.AC-03 | 자동 | team-kit 없는 홈에서 같은 글 | `buttons` 비어 있음, 본문 끝에 `승인 / 거절` |
| AT-HF-22 | REQ-HF-10.AC-01 | 자동 + 실환경(3) | 결정된 4.1 안으로 보조 프로필 `beta`의 예약 작업 `deliver=hejo` 실행(임시 홈 실제 게이트웨이) | 앱이 `employee:"beta"`의 새 스레드 `message` 수신; 앱 끈 상태면 재접속 sync로 수신. (4.1 결정 전 미착수) |
| AT-HF-37 | REQ-HF-05(권한) | 자동 | 허용 사용자 `owner` 설정으로 send, 설정을 `["someone"]`으로 바꿔 send | 앞은 차례 실행, 뒤는 차례 미실행(허용 거부) |
| AT-HF-23 | REQ-HF-11.AC-01 | 자동 | `bash app/scripts/build.sh` | `CFBundleIdentifier == io.github.hermes-hejo.hejo`(ddots와 다름), `codesign --verify --strict` 0 |
| AT-HF-24 | REQ-HF-11.AC-02 | 자동(UI 점검 모드) | 임시 문(대역)에 페어링 → 앱 재시작 | 키체인 서비스 `io.github.hermes-hejo.hejo.gate-token`에 항목, `hejo-local.json`에 출입증 문자열 없음, 재시작 후 `welcome` 수신 |
| AT-HF-25 | REQ-HF-11.AC-03 | 자동(UI 점검 모드) | 문 중지 → 10초 → 문 시작 | 상태 표시 "연결 끊김", 재시도 간격 증가(1,2,4…최대 30초), 문 시작 후 30초 안에 자동 복구 |
| AT-HF-26 | REQ-HF-12.AC-01 | 수동(체크리스트) + UI 점검 | 직원 전환, 스레드 열기, 새 스레드, 보내기, 버튼 누름, 첨부 보내기·열기, 안 읽은 수 | 각 항목 기대 화면 일치, 스크린샷 증거 `evidence/HEJO-FOUNDATION/` |
| AT-HF-27 | REQ-HF-13.AC-01 | 자동 | 빈 임시 홈에 `hejo-install` 2회, `--check` | 링크·`plugins.enabled`·`gateway.platforms.hejo`·`<HOME>/hejo/`(0700)·`devices.json`(0600) 생성; 2회차 파일 변경 0(바이트 동일); `--check` 종료 0 |
| AT-HF-28 | REQ-HF-13.AC-02 | 자동 | 기존 `plugins.enabled: [x, y]`, 기존 `gateway.platforms.hejo: {enabled: false, extra: {port: 1}}`, 기존 `<HOME>/plugins/hejo` 링크(다른 대상)인 홈에서 설치 → `--uninstall` | 세 대상이 설치 전 값·링크 대상과 같음(주석 포함 `config.yaml` 해당 부분 동일), `<HOME>/hejo/`·`<HOME>/shared/hejo/` 남음, 영수증 `uninstalled` |
| AT-HF-38 | REQ-HF-13.AC-03 | 자동 | 설치 뒤 `extra.port`를 47999로 바꾸고 `--uninstall` | 종료 코드 2, `gateway.platforms.hejo` 그대로(47999), 나머지 대상은 되돌림, 충돌 보고에 대상 경로 |
| AT-HF-39 | REQ-HF-13.AC-04 | 자동 | 링크 단계 뒤 설정 쓰기에서 실패 주입 | 종료 코드 1, 홈의 대상 전부 설치 전과 같음, 영수증 `failed` |
| AT-HF-40 | REQ-HF-13.AC-05 | 자동 | 설치 → 사장이 `plugins.enabled`에 z 추가 → 재설치; 시험 내내 파일 열기 감사(`sys.addaudithook`의 `open`) | 영수증 `before` 불변, z 유지; 열린 경로에 `.env`·`auth.json`·`token`·`secret` 포함 0건 |
| AT-HF-29 | REQ-HF-14.AC-01 | 자동 | 가짜 명부 단어(`Alpha`)를 넣은 임시 추적 파일 | 종료 코드 ≠0, 출력에 `Alpha` 없음(지문만) |
| AT-HF-42 | REQ-HF-14.AC-03 | 자동 | 임시 저장소에 가짜 명부 단어 또는 `/Users/someone/x` 경로를 넣은 (a) `#!`로 시작하는 확장자 없는 파일 `install/fake-tool`, (b) `githooks/pre-commit`, (c) `notes.toml`, (d) 바이너리(NUL 포함) 파일을 각각 추적 | (a)(b)(c) 각각 검출·종료 코드 ≠0, (d)는 "바이너리 생략"으로 표시, 값 출력 없음 |
| AT-HF-43 | REQ-HF-14.AC-03 | 자동 | LICENSE 고지 줄을 예외 목록에 등록, 같은 LICENSE에 가짜 명부 단어 줄 추가; 다음으로 고지 줄 내용을 바꿈 | 추가한 줄 검출(종료 ≠0); 내용이 바뀐 고지 줄도 검출(지문 불일치) |
| AT-HF-41 | REQ-HF-14.AC-02 | 자동 | 가짜 운영 홈에 `owner/team.yaml`, `owner/vault.yaml`, `.env`, `auth.json`, `state.db`를 두고 검사, 파일 열기 감사 | 운영 홈에서 열린 경로 = 앞의 두 파일뿐 |
| AT-HF-30 | REQ-HF-15.AC-01 | 확인(3) | 운영 `~/.hermes/config.yaml` 읽기 | `prompt_caching.cache_ttl == "auto"`, 운영 저장소에 해당 동기화 커밋 |
| AT-HF-31 | REQ-HF-05·06·10, NFR-HF-04 | 실물(4) | 노트북 hejo ↔ Tailscale ↔ 공항 Mac 운영 공항, 실제 직원 1명과 대화·버튼·첨부·예약 보고 1건 | 모두 동작, 지연(보내기→첫 작성 중 표시, 보내기→답장 시작) 각 5회 측정 기록 |
