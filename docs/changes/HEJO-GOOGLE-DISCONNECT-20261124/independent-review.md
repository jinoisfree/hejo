# Google 개인 연결 독립 검토

- 검토자: GPT-6.1 Terra, high. 별도 리뷰 세션으로 설계·구현에 참여하지 않았으며 구현자 대화 추론을 받지 않았다.
- 대상: `source-checkpoint-08.log`에 기록된 미커밋 worktree. hejo 기준 `236b0177468b90d9ea23a1b1190e996db78a0694`, team 기준 `4bbc16ddba02236fe4645ab7244603c44a78af91`. 시작과 종료 시 기록된 hejo 28개·team 65개 파일의 해시 및 HEAD 일치를 확인했다. checkpoint SHA-256 `7f197c271032437b1fd51dd3b5b7ae2afebea2646ea24fdcd75beb1887003aa4`. 종료 결과: `.build/google-disconnect-evidence/independent-review-fingerprint.log`. 이는 목록 외 추가 변경이 없다는 별도 증명은 아니다.
- 판정: **부분 완료**. 아래 실제 AppKit 수락 증거 부족과 별도 승인 후 GD-T19가 남는다. 원인 분류는 시험 증거 부족 및 환경·외부 요인이다. 제품 전체 최종 완료, 운영 적용, 푸시를 판정하지 않는다.

## 설계 적합성

금고의 직원별 명시적 미연결과 직원 홈 전용 자격을 binding으로 결합하고, 기존 공용 경로는 항목 부재에만 남기는 설계는 직원 격리·재선택·복구 방지 요구에 부합한다. 인증 세션, 승인·대기 작업 binding, 배포 호환 검사까지 요구를 확장한 것도 적절하다. 다만 실제 AppKit 전체 흐름과 운영 실계정 증거가 갖춰지지 않아 설계 이행 전체를 확정할 수 없다. 이 검토 범위에서 별도의 설계 결함을 특정하지 못했다.

## 확인 범위

요청서, spec·design·tasks·handoff·impl-report·명령 대응표와 수락 명세를 기준으로 직원별 `google_connection.py`의 금고·장부·자격·잠금·갱신·세션, OAuth worker의 PKCE·신원·권한 검증, Workspace 명령 어댑터, 배포 검사기, AppKit 시험 및 관련 기록을 확인했다. 금고의 null/손상 거절, binding 및 장부 일치, 요청 중 lease와 새 인증의 세션 검사 경로를 읽었고 아래 선택 시험을 실행했다. 전체 소비자와 모든 배포 실패 분기를 각각 독립 실행한 것은 아니다. 기존 검증의 전체 시험 결과와 독립 실행 결과를 구분한다.

기존 증거에서 `task05-mutations-01.json`의 네 결함 주입은 각 시험 종료 1 및 driver 종료 0으로 기록돼 있고, `finish-ui-google.log`는 모델 및 실제 인증 시트 대역의 별도 성공을 기록한다. `finish-ui-resume-results.json`은 connections와 management 재실행 성공을 기록한다. 각각 전체 기본 앱 명령의 단일 성공으로 합산하지 않는다. GUI 준비 전 focus 실패와 이후 connections·management 재실행 성공은 별개이며, 그 해소가 IR-1의 실제 화면 관측 공백을 채우지는 않는다. 개인정보 검사 보고 `finish-private-hejo.json`, `finish-private-canonical.json`의 종료 0을 확인했다. 기존 증거 로그의 모든 내용이나 정적 분석 처분을 재현한 것은 아니다.

## 지적

- **IR-1 — 차단, 시험 증거 부족.** 기준: REQ-GD-05.AC-01, GD-T17, 검증 규칙 4.5·4.7. 위치: `app/Tests/ConnectionsTests.swift:70`, `app/Tests/ConnectionsTests.swift:523`, `app/Tests/TestMain.swift:53` (hejo worktree 기준). 실제 AppKit 시트 시험은 브라우저 안내와 취소 버튼을 확인한다. 해제 확인 문구와 이메일 제거는 주입된 `ConnectionsModel` 시험에서 확인하며, 성공 후 새 계정 표시와 실제 AppKit 만료 표시를 관측하는 흐름은 해당 시험들에 없다. `finish-ui-google.log`의 두 PASS는 이 범위를 넘는 실제 화면 왕복을 입증하지 않는다. 이는 제품 동작 오류의 단정이 아니라 명시된 수준 3 수락 증거 누락이다. 보낼 곳: 기획·검증 담당. 실제 AppKit과 가짜 서버를 사용해 GD-T17의 해제 확인·이메일 제거·연결 버튼·성공 후 새 계정·취소/만료·창 닫기와 목록 갱신을 관측하고 기존 기준에 따라 처분해야 한다.

## 직접 실행

- checkpoint 파일의 각 경로 SHA-256과 두 HEAD를 Python으로 대조: 시작·종료 모두 종료 0, 28/65 불일치 0. 종료 로그는 위 fingerprint 로그.
- 가짜 임시 `HOME`/`HERMES_HOME`, 네트워크를 호출하지 않는 기존 fixture, bytecode 및 pytest cache 비활성 상태에서 team-kit cwd의 `pytest tests/google_disconnect/test_oauth.py tests/google_disconnect/test_connection.py tests/google_disconnect/test_queued.py tests/google_disconnect/test_native_workspace.py --confcutdir=tests/google_disconnect -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp <임시경로>`: 종료 0, 103 passed. `.build/google-disconnect-evidence/independent-review-targeted-02.log`. 기존 연결 환경의 Python 및 의존성 경로를 사용했다.
- 첫 동일 시도는 의존성 `PYTHONPATH`를 덮어써 pytest를 찾지 못해 종료 1이며 `.build/google-disconnect-evidence/independent-review-targeted.log`에 보존했다. 시험 자체는 실행되지 않았다. 다음 시도에서 기존 의존성 경로를 유지했다.

## 한계

실제 Google OAuth/API, 운영 공항·비밀, 보안 창, 외부 메시지 및 운영 배포를 실행하지 않았다. GD-T19는 별도 운영 인계 승인과 사용자의 직접 행동을 기다리는 수준 4 증거이며 구현 버그로 분류하지 않는다. 모든 24개 명령의 실서비스 동작, 모든 승인·배포 분기의 개별 독립 실행, AppKit 전체 화면 왕복은 직접 검증하지 않았다. 기존 전체 검사와 mutation 실행을 무조건 반복하지 않았다. 제품·시험 파일은 수정하지 않았다.

## IR-1 재검토 — checkpoint-09

같은 독립 리뷰 세션(GPT-6.1 Terra high)에서 제출된 시험 변경과 증거를 검토했다. `source-checkpoint-09.log` SHA-256은 `79ba0d27c3534d60aa9c92f447040c9bf5f4c633e75429ffb8da8ba4eca39905`다. 시작·종료 지문 검사는 hejo 29개·team 65개와 두 기준 HEAD 일치, checkpoint-08 대비 `app/Tests/ConnectionsTests.swift`, `app/Tests/TestMain.swift`, `app/Tests/google_connection_fixture.py` 세 시험 파일만 변경됨을 확인했다. 기록된 목록 밖 파일의 추가 여부를 별도로 증명하지는 않는다. `ir1-final-check.json`의 증거 지문 11개와 렌더·텍스트·frames 지문 27개도 일치했다. 종료 검사 명령은 Python `hashlib.sha256`·`git rev-parse HEAD` 대조, 종료 0, 로그 `.build/google-disconnect-evidence/independent-review-09-fingerprint.log`다. 제품·team 파일의 기록된 지문은 checkpoint-08과 동일하다.

**처분: IR-1은 화면 관측의 대부분을 수용하되 창 닫기 항목이 남아 차단을 유지한다.** 추가 시험은 실제 `ConnectionsWindow`, AppKit 시트와 SwiftUI 접근성 컨트롤, loopback WebSocket 가짜 서버를 사용하며 서버 송수신을 공용 wire schema로 검사한다. 재인증·브라우저·polling 시간은 대역이다. 삭제 확인 거절/수락, 이전 이메일 제거와 연결 버튼, 재연결 뒤 새 가짜 계정 표시, 취소 확인 실패/성공, 만료, 목록 갱신은 시험 코드의 실제 관측 단언과 `ir1-ui-07.log`, 13개 렌더·접근성 텍스트, `frames.json`을 대조해 확인했다. 렌더는 NSView 캐시 이미지이며 실제 데스크톱 합성 화면의 완전한 재현이라고 보지 않는다. 프레임은 477개이며 세션 2·3·4·5에 대한 취소 요청과 개인 삭제 요청 두 번을 확인했다. 옛 계정 잔존 변이의 시험 종료 1과 driver의 기대 실패 확인을 기존 로그에서 확인했다. 전체 UI 기본 모드 단일 실행 또는 실계정 증거로 취급하지 않는다.

- **IR-1 잔여 — 차단, 사용자 창 닫기 경로의 수락 증거 부족.** 기준: `design.md:81`의 인증 중 창 닫기 시 account_cancel과 실패 안내, GD-T17의 창 닫기. 위치: hejo worktree `app/Tests/ConnectionsTests.swift`의 `googleDisconnectUITests` 창 닫기 부분 및 `app/Sources/ConnectionsWindow.swift:338`, `:375`, `:380`. 이전 `ir1-ui-06.log`는 부모 `performClose` 시 제한 시간 초과를 기록하고 최종 시험은 `window.close()`를 코드에서 직접 호출한다. 후자는 `windowWillClose`에 이은 소유 세션 취소와 재열기만 입증하며, 사용자가 실제 창 닫기 동작을 실행할 수 있고 그 동작이 같은 경로에 도달함을 입증하지 않는다. 시트의 인증 취소 버튼은 별도로 성공·실패를 검증하지만 창 닫기와 같은 사용자 행동으로 바꾸어 세지 않는다. 제품 결함으로 확정하지는 않는다. 최소 보완은 실제 노출된 창 닫기 사용자 액션을 수행하고 해당 소유 세션의 account_cancel 프레임을 관측하는 것이다. 실패 표시의 공통 경로가 동일함도 확인한다. 경로가 설계상 존재하지 않는다면 기획 담당이 근거와 승인된 계약 처분을 제시해야 한다. 이미 입증된 삭제·새 계정·만료 시나리오는 이 지적만을 위해 반복하지 않는다. 구현자가 임의로 수락 기준을 완화하지 않는다.

직접 실행한 것은 위 지문·HEAD·증거 해시와 프레임 집계의 읽기 전용 검사다. 기존 통과 UI suite는 재실행하지 않았으며, 보고된 UI 실행 및 mutation 결과는 제출 로그를 직접 읽어 확인한 증거다. 운영·실계정·보안 창은 다루지 않았다. GD-T19와 푸시의 별도 승인·증거 조건은 그대로 남는다.

## IR-1 최종 재검토 — checkpoint-10

같은 GPT-6.1 Terra high 독립 리뷰 세션에서 제품 코드, 세 시험 파일, 실제 AppKit 증거와 프레임을 재검토했다. **IR-1의 처분을 수용하며 이 지적을 닫는다.** `ConnectionsWindow.swift`의 인증 시트에 노출된 ‘창 닫기’ 버튼이 기존 부모 창 종료·`windowWillClose`·소유 인증 취소 경로로 이어진다. 실제 `NSButton.performClick`으로 창과 시트를 닫은 후 해당 직원·세션의 `account_cancel`, `reauth=false`가 전송됐으며 재열기 결과도 관측됐다. 끊어진 소켓에서는 취소 성공으로 표시하지 않고 재열기 후 확인 불가를 표시한다. 기존 인증 취소 버튼은 부모 창을 유지한다.

늦은 poll 응답에 대한 `await send` 직후 취소 확인은 취소된 작업이 성공 안내를 덮어쓰는 것을 막는다. 제출된 수정 전 `close-ui-01.log`는 해당 단언 실패와 종료 1을 기록하고, 수정 후 `close-ui-02.log`는 동일 경계에서 자식·fixture·driver 종료 0을 기록한다. 시험의 서버 장벽과 늦은 응답 후 실제 재조회 단언을 확인했다. 변경 관련 새로운 차단 지적은 발견하지 못했다. 기존 Google 모델·시트 회귀 `close-google-01.log`, 제품 빌드·서명 `close-product-build-01.log`의 종료 0은 제출 기록을 직접 확인한 결과이며 본 검토에서 재실행하지 않았다.

`source-checkpoint-10.log` SHA-256 `451b76c2b6b2bc828f70861d5fd0dae72b7d9819d178aa3c2c0538a5301f913b`. Python SHA-256 및 `git rev-parse HEAD` 대조 종료 0: hejo 29개·team 65개 지문과 기준 HEAD 일치, checkpoint-09 대비 제품 `app/Sources/ConnectionsWindow.swift`와 시험 3파일만 변경. `close-final-check.json`에 기록된 로그·기타 증거 10개 및 렌더·텍스트·프레임 17개 해시가 일치했고 cancel 프레임은 가짜 세션 1·3·4, 직원 alpha, reauth=false다. 직접 검사 로그: `.build/google-disconnect-evidence/independent-review-10-fingerprint.log`. 파일 목록 밖의 추가 변경 여부는 이 지문 대조만으로 증명하지 않는다.

8쌍의 캐시 렌더와 접근성 텍스트를 확인했다. 일부 캐시 렌더는 애니메이션·합성으로 화면 요소가 빠지므로 화면 상태 판단은 컨트롤 단언과 접근성 텍스트·프레임을 함께 근거로 삼았다. 실제 실계정 인증, 운영 적용, 전체 앱 기본 모드 단일 실행은 이 재검토의 범위가 아니다. GD-T19와 푸시 승인 조건은 여전히 별개이며 전체 작업의 최종 완료를 선언하지 않는다. 제품·시험 파일은 검토자가 수정하지 않았다.
