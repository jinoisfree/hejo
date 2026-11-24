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

## 왕복13 전달 수정안 독립 검토

동일한 GPT-6.1 Terra high 독립 세션에서 계획을 읽기 전용으로 검토했다. 대상 소스 HEAD는 hejo `d25530649f7eb898e2f5cbc5cb471c1417823632`, team `33d6671993473c0eb7ecb4087e0fe4edebc63050`이다. 제품 수정·운영 접근·실계정·푸시는 하지 않았다. 이 절은 구현 완료 판정이 아니다.

진단은 타당하다. `app/scripts/build.sh:20`은 한글 리소스를 원래 이름으로 복사하고 `app/Sources/HooksHelp.swift:11`은 같은 이름을 찾는다. `delivery-unicode-resource.json`과 `delivery-package-signature-diagnostic.json`에는 압축 해제 후 파일명 정규화 차이 및 `codesign --verify --deep --strict` 종료 1이 기록돼 있다. 앱 빌드 산출물의 리소스 이름과 lookup을 일치하는 ASCII 이름으로 바꾸고 서명 전 오래된 이름을 제거하는 방향은 기존 앱 칸 안의 최소 보완이다. 문서 내용과 UI 문구는 유지한다. 새 빌드뿐 아니라 이전 빌드 잔재가 있는 반복 빌드에서도 옛 리소스가 남지 않아야 한다. 새 산출물을 실제 압축·다른 임시 위치에 풀어 서명을 확인하고, 추출된 앱에서 번들 리소스 lookup과 원래 안내 내용이 일치함을 확인해야 한다. 기존 로컬 번들 서명 성공만으로 압축 배포 성공을 대체하지 않는다.

`hermes/bin/hermes-team-kit-deploy`의 현행 `deploy_locked`는 team-kit과 team-kit overlay만 다룬다. 제안된 기존 deploy의 명시적 bundle 모드와 지정된 동반 5파일을 키트와 함께 처리하는 방향은 별도 installer나 인증 원본 없이 현행 책임 안에서 문제를 해결할 수 있다. 단, 아래 조건을 설계와 수락 시험에 구체화해야 한다.

1. **bundle 호환성과 구 진입점.** 현재 `google-connection-support.json`과 설치된 검사기는 team-kit 대상만 검사하므로 그 통과를 동반 5파일 전체의 조합 적합성으로 간주할 수 없다. 다섯 파일과 키트가 같은 검증된 후보/복구 묶음에 속하는지 확인하고 누락·변조·불일치 시 쓰기 전에 닫는다. 기존 `--source` kit 전용 계약은 유지하되 전환된 홈에서 kit만 교체·롤백해 동반 파일과 호환되지 않는 조합을 만드는 경로는 허용하지 않도록 조건을 명시해야 한다. 기존 미전환 사용 사례까지 일괄 차단하자는 뜻은 아니다.
2. **선택·manifest.** `plugin_store.py:37` 이후의 overlay는 각 호스트의 `plugin.yaml`을 별도 파일로 보존한다. `team-delegation/plugin.yaml`의 새 네 도구 선언은 원본만 바꿔서는 기존 overlay manifest에 전파되지 않을 수 있고, 실행은 `hermes_execution/__init__.py:2451` 및 `google_workspace.py:278`에서 선언을 참조한다. 루트·프로필의 link/overlay 각각에서 기존 권한·선택·무관 필드를 보존하면서 필요한 선언만 반영하는 명확한 소유·병합 규칙이 필요하다. 충돌·불명확 형식은 거절하고 grant나 스킬 선택을 자동으로 늘리지 않는다. 선택된 직원만 기존 조립 경로로 갱신하며, 미선택 직원과 비전환 직원의 동작도 확인한다.
3. **부분 실패·경합·복구.** 현재 `deploy_locked`는 키트 rename 및 기존 team-kit overlay 복구만 다룬다. 새 범위에서는 다섯 파일의 기존 존재/부재·내용·실행 권한과 관련 overlay까지 같은 트랜잭션에 포함해 모든 교체 단계의 실패와 중단을 다뤄야 한다. 현재 검사기 캡처·호환 검사·gateway 중단 확인 및 기존 잠금을 유지하고, 심링크·경로 탈출·대상 바뀜을 거절한다. 복구할 이전 묶음 역시 현재 검사기로 확인하고, 복구 실패나 강제 종료로 상태가 불확실하면 성공을 알리지 않고 복구 자료를 남긴다. 금고·자격·직원 자료를 옛 사본으로 되돌리지 않는다.
4. **시험 범위.** 임시 홈에서 실제 bundle apply/rollback의 정상·누락·구버전/불일치·각 쓰기 단계 실패 및 재실행, lock/gateway/symlink 거절, 원래 kit-only 호환성, root/profile link 및 overlay와 선택·권한 보존, 실행 파일 모드를 확인한다. 테스트는 가짜 자료만 사용하고 실제 운영 배포를 대신했다고 주장하지 않는다. 앱은 정규화가 재현되는 임시 볼륨/압축 해제 경로의 strict 서명과 lookup을 함께 확인한다.

위 사항은 방향의 보완 조건이며 현재 수정안이 이미 구현·검증됐다는 주장이나 새 제품 버그의 확정 판정이 아니다. 운영 적용·GD-T19 및 푸시는 별도 승인과 증거가 필요하다.

## 왕복14 — design8 D1/D2 독립 구현 재검토

동일 GPT-6.1 Terra high 독립 세션에서 checkpoint-11을 검토했다. **D1/D2 구현은 검토 범위에서 수용하며 새 차단 코드 지적은 없다.** 이는 운영 적용 가능 또는 GD-T19 완료 판정이 아니다. 설계8판의 기존 앱 빌드·기존 배포 진입점·단일 현행 검사기·금고와 권한 원본 보존이라는 배치는 요구에 부합한다. 현재 설치 검사기 부재와 선언된 이전 묶음 불일치를 후보 검사기로 우회하지 않고 중단한 운영 인계의 처분도 기존 계약에 맞다. 다만 이 상태에서 정상 경로만으로 최초 전환할 수 있다는 근거는 없으며, 별도 기획에서 실제 이전 상태의 검증·안전한 전환·복구 계약을 정하고 독립 검토와 사용자 승인을 받아야 한다. 실제 운영 상태에 대한 상세 주장은 제출된 비밀 제외 읽기 전용 보고에 의존하며 이 리뷰에서 운영 홈을 다시 열지 않았다.

D1의 `app/scripts/build.sh`는 서명 전 해당 한글 리소스의 정규화된 옛 이름을 제거하고 기존 HTML 원문을 ASCII 이름으로 복사하며, `HooksHelp.guideURL`의 조회도 일치한다. D2의 기존 deploy는 kit-only와 명시적 bundle 경로를 구분하고, 설치된 검사기의 고정된 정책으로 키트와 다섯 동반 파일의 식별·모드를 검사한다. stage와 기존 금고 잠금, gateway 중지 확인, 입력 및 대상 비교, 부분 실패 복구와 중단 표식 거절을 코드와 관련 시험에서 확인했다. 선택된 직원의 manifest·manual을 기존 조립 경로로 합성하고 사용자 grant·소유자 설정은 갱신하지 않는 경계도 확인했다. 기존 kit-only 호출은 후보 또는 현재 상태가 bundle을 요구하면 거절한다. 제출된 mutation 두 사례는 의도된 시험 실패 1 및 driver 0으로 기록됐다. 이 검토는 모든 가능한 I/O 장애나 운영 토폴로지의 실행을 뜻하지 않는다.

- 변경본: hejo HEAD `d25530649f7eb898e2f5cbc5cb471c1417823632`, team HEAD `33d6671993473c0eb7ecb4087e0fe4edebc63050`; 미커밋은 각각 13·7파일. checkpoint SHA-256 `53173380963aff46cc442428491467d4020db2865acd18abcdc67cfbfbf98353`. 시작과 종료의 직접 지문 대조에서 checkpoint 목록 hejo 48·team 66파일과 HEAD 일치, 불일치 0. 시작 로그 `.build/google-disconnect-evidence/independent-review-11-fingerprint.log`는 제출 로그 12개 해시도 확인한다. 목록 밖 변경 여부는 이 지문 검사만으로 증명하지 않는다.
- 직접 실행: 격리 HOME/HERMES_HOME에서 `test_google_bundle.py`의 정상 전체 적용·롤백, 강제 종료 표식, 소유자 선택 경합, 구 호출자 차단 4개를 pytest로 실행해 종료 0, 4 passed. 정확한 대상은 `.build/google-disconnect-evidence/independent-review-11-targeted.log`와 이 네 시험명에 해당하는 기존 시험 함수다. 운영 홈·외부 메시지는 사용하지 않았다.
- 직접 실행: 격리 HOME/HERMES_HOME에서 `python3 app/Tests/test_help_package.py --verify-existing` 종료 0. 기존 검증 빌드를 새 임시 위치에 압축·추출해 deep strict 서명과 실제 `HooksHelp.guideURL` 조회·HTML 원문 바이트 일치를 확인했다. `.build/google-disconnect-evidence/independent-review-11-app.log`. 이 명령은 새 제품 빌드나 운영용 로그인 구성의 증거가 아니다.
- 제출 증거: `round13-bundle-accepted.log`의 112개 성공 뒤 복구 수정에 대한 별도 `round13-recovery-final.log`의 15개 성공을 단일 전체 실행으로 합치지 않는다. 기존 Google 회귀·실제 등록·공개 검사와 앱 반복 빌드 로그는 제출 증거로 확인했으며 무조건 반복하지 않았다.

새 커밋·푸시·운영 변경·실계정 OAuth는 이 독립 검토에서 실행하지 않았다. 추가 운영 전환 설계, 승인된 호환 복구 묶음, 사용자 직접 GD-T19 및 푸시 승인 조건은 남는다.

## 왕복15 — 실제 legacy 기준과 후속 기능 보존 검토

GPT-6.1 Terra high 독립 세션에서 운영 파일을 다시 열지 않고 제출된 inventory/provenance/coverage 메타데이터와 두 저장소의 Git diff를 대조했다. **두 후속 커밋을 legacy 시설의 고정 식별 기준 후보로 조건부 채택하는 방향에 동의한다.** 이는 두 버전의 전체 안전성 인증이나 운영 전환 승인이 아니다. 보고된 시설 일치 범위와 실행 시점에 다시 검증할 전체 전제조건을 구별해야 한다.

- 제출 metadata의 세 출처 검사는 종료 0이고 운영 쓰기·비밀 파일 열기 없음으로 기록됐다. 보고된 범위에서 hejo 시설 43개는 `a3df84e48fae8b36c27a572a5ee36247cc46acf3`, team-kit 681항목과 동반 경로는 `9488a060e7bf5646af69628b29b34c28cfc18109`의 식별 결과와 일치한다. inventory의 기존 기준 `baselineProven`은 false이며 후속 기준의 승인 여부도 false로 기록돼 있다. 이 판독은 기록된 파일 범위의 출처 증거이지 영수증·모든 홈·전환 기록·실행 중 작업이나 미래 시점의 불변성을 입증하지 않는다. 개인 경로·실제 식별자는 복제하지 않는다.
- 두 저장소에서 각각 `git merge-base --is-ancestor`로 원래 기준 `236b0177468b90d9ea23a1b1190e996db78a0694` → 위 hejo 커밋, `4bbc16ddba02236fe4645ab7244603c44a78af91` → 위 team 커밋이 모두 후손임을 직접 확인했다(각 종료 0). 전체 merge/rebase 지시는 아니다. 별도로 `git diff --name-status`와 관련 코드 diff를 읽었고, 시설 범위 밖 전체 커밋을 도입하는 것이 아니라 필요한 파일과 의존·시험을 선별하는 계획이 적절하다.
- hejo 시설 차이는 `gate/README.md`, `gate/adapter.py`, `gate/telegram.py`, 신규 `gate/telegram_comments.py`, 관련 시험이다. 댓글 라우팅·기존 토픽 전환과 epoch/전송 기록·수신 중 카운트 및 방 대표 변경 검사·typing 처리를 같이 보존해야 한다. 단일 파일만 옮기면 import나 기존 토픽 경로가 깨질 수 있다. 신규 댓글 시험과 기존 텔레그램/방 회귀 및 수락 명세를 통합 후보에서 실행한다. 파일 일치는 실제 Telegram 외부 전송 검증이 아니다.
- team-kit의 후속 차이 23파일에는 Notion 원격 앱 연결·페이지/데이터베이스 범위와 조상 검증·페이지네이션/시간 예산·오류 및 checkpoint 처리, hejo 사장 발화의 session/turn 준비 증명, 직원별 첨부 읽기, 앱 catalog, 전송 오류 분류 및 관련 시험이 포함된다. 종속된 등록·실행·권한 경계를 묶어 보존해야 한다. 현재 Google 후보와 파일 단위 중복은 `hermes_facility/app_connect.py`, `hermes_facility/connection_checks.py` 두 파일이다. 이 두 파일은 어느 한 버전을 덮어쓰지 말고 후속 Notion 처리와 Google의 직원별 해제·인증·실패 경계를 모두 통합해야 한다. Google 변경과 별도 동작도 사용처·호출자와 함께 확인한다.
- 관련 시험은 후속 변경된 6개 team 시험을 포함하고 기존 Notion API/권한·범위·연결·승인, hejo session/turn 및 첨부 격리, Google 연결/소비자/승인·배포 회귀를 선택해 실제 통합 후보에서 수행한다. 기존 성공 로그는 변경 없는 범위의 증거로만 재사용한다. 충돌 파일의 양쪽 기능과 실패 동작은 대역을 포함해 독립 기대값으로 검증한다. 이번 읽기 검토에서 제품 시험은 실행하지 않았다.

최초 전환 계약은 별도의 설계9 검증 대상이다. Git 커밋을 변경 불가능한 기준으로 고정하고 적용 직전 실제 시설 전체·모드/링크·동반 파일의 존재/부재 및 영수증/링크를 재검사한다. 검사기 부재 예외는 명시적으로 범위를 제한하고 전환 기록·전용 자격·활성 인증/미완료 배포 부재, gateway 중단, 잠금과 CAS 및 호환 복구 묶음을 확인해야 한다. 임의 현재 운영 바이트를 지원 선언으로 승인하거나 구 버전 fallback으로 우회하지 않는다. 이 증거만으로 기준 채택에 필요한 나머지 조건을 충족했다고 판단하지 않는다. 통합 후 후보/시험·지원 선언/복구 묶음 지문을 새로 고정하고 독립 재검토한 뒤 운영·실계정·푸시를 각각 별도 승인받는다.

## 왕복16 — checkpoint-13 최초 전환·통합 재검토

동일한 GPT-6.1 Terra high 독립 세션에서 왕복15 구현 보고, design9, `LegacyUpgrade`와 `hejo-install --upgrade-legacy`, 관련 시험 및 Notion 대조 증거를 검토했다. **검토한 최초 전환·지정 후속 기능 통합 범위에서 새로운 차단 지적은 발견하지 못했다.** 코드·격리 시험의 수용이지 운영 대상에 대한 적용 허가나 전체 최종 완료는 아니다.

명시적 최초 전환은 기존 설치의 영수증·링크와 고정된 legacy 시설/동반 파일 식별, 전환·자격·진행 작업 부재, 프로필 집합 및 gateway/worker 상태를 검사한다. 금고 잠금 아래 쓰기 전마다 재검사하고 최초 변경 전에 중단 표식을 영수증에 남긴다. 일반 실패에서는 기존 링크·영수증만 복구하며, 전환 발생이나 상태 불확실성은 이전 코드 자동 복구 대신 중단한다. 일반 설치의 검사기 누락 거절을 바꾸지 않는 별도 경로다. 일부 환경/장애의 동시성은 시험으로 관측한 범위에 한정하며 실제 운영 적용 시에도 승인된 대상과 중단·복구 전제를 다시 확인해야 한다.

후속 Notion 관련 기존 시험 12개는 통합 후보와 고정 후속 Git 기준에서 동일한 노드 및 정규화된 assertion 실패로 재현됐다. 직접 두 로그의 종료 1·`12 failed, 10 passed`와 비교 보고를 확인했다. **이번 Google 통합이 새로 만든 회귀로 분류할 근거는 없으며, 기존 기준의 시험과 동작 불일치로 기록한다.** 실패 원인이 제품 결함인지 구형 fixture/기대인지 확정하지 않고, 실패 전제 너머의 동작이 정상이라는 증거로도 삼지 않는다. 기존 실패를 삭제·skip하거나 전체 team 회귀 통과로 표시하지 않는다. 별도 범위의 원인 처분은 해당 기능의 소유자가 결정하며 이 비교만으로 이번 작업의 새로운 Notion 수정 범위를 만들지는 않는다.

- checkpoint SHA-256 `d3ce712dab0bb77269471425dbcba0db86271d1b0ab1ce17b7bc74757e51aa4c`. hejo HEAD `d25530649f7eb898e2f5cbc5cb471c1417823632`, team HEAD `33d6671993473c0eb7ecb4087e0fe4edebc63050`. 시작·종료 시 목록의 hejo 54·team 88 파일 지문 및 HEAD 일치, 불일치 0. 시작 검사의 명령 결과 `.build/google-disconnect-evidence/independent-review-13-fingerprint.log`. 목록 밖 변경 전체를 이 검사만으로 보증하지 않는다.
- 직접 실행: 임시 HOME/HERMES_HOME의 `test_google_legacy.py`에서 실제 release CLI→전체 bundle, 실패 중 전환, 프로세스 종료 표식, worker 관측 실패/실행 중 거절, 비밀 비접근 시험 5개 실행. 종료 0, 5 passed. `.build/google-disconnect-evidence/independent-review-13-legacy.log`. 기존 전체 suite를 반복하지 않았다.
- 제출 로그의 241개 성공은 이후 orphan/시설 모드 검사가 추가되기 전 실행이며, 최종 변경분의 별도 11개 표적 성공과 하나의 최종 전체 실행으로 합산하지 않는다. Notion+Google 교차 표적 13개 성공 및 제출 mutation 결과는 제출 기록으로 확인한 범위다.

실제 운영 시설·비밀·실계정 OAuth·푸시를 다루지 않았다. 운영 최초 전환은 고정된 최종 후보 및 호환 복구 묶음, 실제 대상의 재확인과 별도 승인 이후에만 가능하다. GD-T19, 명세 승격 및 푸시 승인도 여전히 남는다.
