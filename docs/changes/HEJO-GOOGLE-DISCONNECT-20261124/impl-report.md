# 구현 인계: Google 개인 연결 해제·계정 선택

## 현재 판단과 범위

**checkpoint-10 로컬 구현·Terra 독립 검토 통과, 왕복12 전달 준비 중이다.** IR-1은 독립 최종 재검토에서 해소됐다. 검토된 코드와 최신 작업 문서를 로컬 커밋/격리 배포 후보로 고정하는 단계이며 제품 코드를 추가 변경하지 않는다. 운영 승인·사용자 GD-T19·최종 명세 승격·푸시는 미완료다. 운영 설치/apply/재시작·실계정·푸시는 실행하지 않는다.

원래 목표는 해당 직원 Google 개인 연결·이메일·전용 자격을 제거하고 다음 연결에서 계정을 선택하는 것이다. 기존 금고 원본과 전용 저장 배치, 공식 도구 4개, gate/AppKit 구현을 보존했다. 본체·ddots·sandbox 정책·운영 비밀 파일·Paseo 상태 JSON·계획/수락 명세 Markdown은 변경하지 않았다. 기존 구현을 유지하며 왕복11에서 인증 시트의 명시적 닫기 동작과 취소된 폴링의 응답 후 보호, 해당 표적 시험을 보완했다. 원래 폴더의 다른 작업도 보존했다. 구현 소유 보고와 [명령 대응표](workspace-command-map.md)만 canonical 폴더에서 관리한다.

## 저장소·검토 변경본

| 저장소 | HEAD/기준 커밋 | 브랜치 | 격리 위치 |
|---|---|---|---|
| hejo | `236b0177468b90d9ea23a1b1190e996db78a0694` | `role-workflow/google-disconnect-c20a9994` | `.build/google-disconnect-work/hejo` |
| 운영 저장소 | `4bbc16ddba02236fe4645ab7244603c44a78af91` | `role-workflow/google-disconnect-c20a9994` | `.build/google-disconnect-work/team` |

경로는 원래 작업 폴더 기준이다. **결과 커밋 없음.** 최신 검토 대상은 `.build/google-disconnect-evidence/source-checkpoint-10.log`의 미커밋 작업 트리다. 두 HEAD/브랜치를 유지하며 hejo29/team65 파일 지문을 기록했다. checkpoint-09 대비 app/Sources/ConnectionsWindow.swift와 app/Tests/ConnectionsTests.swift·TestMain.swift·google_connection_fixture.py 네 파일만 변경했다. team 전체·다른 제품 파일·기존 시험 단언·기본 모드 호출 순서를 보존했다. canonical 계획·수락 명세·독립 리뷰 원본과 다른 작업의 변경은 수정하지 않았다.

## 이전 왕복11 — IR-1 실제 사용자 창 닫기 보완

승인 원본은 tasks의 ‘왕복11 IR-1 창 닫기 최소 보완’과 Terra checkpoint-09 재검토다. 위험도/증거 수준 및 설계7판은 유지한다. 앞선 삭제·새 계정·만료 전체 화면 시나리오는 반복하지 않았다.

### 제품 변경과 발견한 결함

기존 증거에서 인증 시트가 붙은 부모 performClose는 진행되지 않았고 시트의 표준 닫기 버튼도 노출되지 않았다. 왕복11 허용 범위에 따라 기존 AppKit NSPanel 안에 ‘창 닫기’ NSButton을 추가했다. 기존 ‘인증 취소’와 함께 놓고, 툴팁으로 인증 취소와 창 닫기를 설명한다. 새 버튼의 실제 target/action은 부모 window.close로 연결하며 기존 windowWillClose→model.close→closeGeneration/소유 account_cancel을 그대로 사용한다. 별도 취소 구현·새 창·원본·권한·서버 경로는 없다. Escape의 기존 인증 취소 동작은 유지한다.

표적 시험 첫 실행(close-ui-01.log, 종료1)은 닫기 성공/연결 끊김 실패/기존 취소를 통과한 뒤 늦은 poll 승인 응답에서 실제 안내가 ‘연결을 확인했어요.’로 바뀌는 결함을 검출했다. 원인은 취소된 Task가 요청 continuation의 응답을 받은 직후 취소 상태를 다시 확인하지 않기 때문이다. ConnectionsModel.startPolling의 await send 다음에 기존 Task.isCancelled 검사를 추가했다. 닫기/새 polling이 취소한 옛 작업은 늦은 응답의 안내·목록 처리를 진행하지 않는다. 같은 시험/서버/컨트롤을 유지한 재실행은 종료0이다. 초기 실패와 수정 후 성공을 다른 바이너리/소스 지문으로 구분한다.

### 실제 컨트롤·서버 관측

기존 실제 AppKit+loopback fixture에 closeOnly 제한 모드와 --google-disconnect-close-ui 진입점만 추가했다. 새 시험은 시트에서 실제 노출된 NSButton을 찾아 enabled를 확인하고 performClick으로 누른다. 사용자 닫기 검증을 window.close/model.close 직접 호출로 대신하지 않는다. 공통 defer의 종료 정리는 수락 동작과 별개다. 재인증/브라우저/기존 polling 시간만 대역이며 제품 send/ref 경로와 clientFrame/serverFrame 검사를 유지한다.

| 경우 | 실제 관측 | 서버 프레임/실패 경계 |
|---|---|---|
| 닫기 성공 | 실제 ‘창 닫기’ 버튼 후 부모/시트 종료. 재열면 ‘인증을 취소했어요.’와 연결 버튼 | 첫 소유 세션 취소 1회, reauth=false/profile=alpha, 이후 목록 재조회 |
| 취소 전송 불가 | 시트 표시 후 가짜 소켓만 끊고 실제 ‘창 닫기’를 누름. 재열기에서 ‘취소 확인 안 됨’, 서버 연결 실패 안내가 표시됨. 재접속·조회 뒤에도 실패 의미 유지 | 두 번째 세션의 cancel은 전송되지 않음. 서버 성공으로 위장하지 않음. 실제 연결 상태로 send guard가 실패하는 경로 |
| 기존 인증 취소 | 실제 ‘인증 취소’ 버튼은 시트만 닫고 부모 창은 계속 보이며 취소 성공 안내 | 세 번째 세션 취소 1회, 기존 재인증 불필요 경계 유지 |
| 늦은 응답 | 네 번째 세션의 실제 poll 응답을 보류하고 실제 ‘창 닫기’를 누름. 재열기 후 늦은 승인 프레임과 그 다음 실제 새로 확인 왕복을 통과해도 취소 안내/시트 없음이 유지 | 소유 세션 취소 1회. 취소 뒤 늦은 승인 전송과 다음 목록 응답을 파일 장벽으로 확인. 임의 고정 대기로 성공 판정을 대신하지 않음 |

가짜 서버는 이 모드에서 네 인증만 시작하며 삭제/새 계정/만료 전체 흐름은 실행하지 않는다. 계정은 미연결로 유지한다. 최종 frames.json에서 cancel은 세션1·3·4이고 전송 불가 세션2는 없다. 화면 증거는 close-ui-02/의 실제 NSView 캐시 렌더/접근성 텍스트8쌍이다. 이 렌더는 앞선 제출과 같은 합성/애니메이션 한계가 있으며, 실제 컨트롤과 상태는 접근성 관측 및 전송 프레임으로 함께 확인했다. 성공/실패 재열기·늦은 응답 뒤 렌더와 텍스트를 직접 확인했다.

### 명령과 실제 결과

원래 작업 폴더에서 기존 connections-env.sh를 source하고 HEJO_TEAM_KIT_LIB/PYTHONPATH를 기존 team worktree로 지정했다. runner의 자식 cwd는 hejo worktree의 app이며 가짜 HOME/HERMES_HOME·정확한 argv/환경·컴파일 입력/실행 파일 지문은 각 로그 첫 JSON, 결과는 마지막 JSON에 있다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| python3 .build/google-disconnect-evidence/close-ui-build.py | 최종 Swift 시험 컴파일/서명/서명 검증 각각0 | close-ui-build-02.log |
| python3 .build/google-disconnect-evidence/close-run.py ui 01 | 종료1. 사용자 닫기/전송 실패/취소 회귀 후 늦은 승인 덮어쓰기 검출. fake 서버 오류0 | close-ui-01.log, close-ui-01/ |
| python3 .build/google-disconnect-evidence/close-run.py ui 02 | 종료0. 사용자 닫기 AppKit·APP_TEST_OK·loopback frame 계약 PASS, 자식0/fixture 오류0 | close-ui-02.log, close-ui-02/ |
| python3 .build/google-disconnect-evidence/close-run.py google 01 | 종료0. 기존 Google 모델·실제 인증 시트 회귀 PASS | close-google-01.log |
| python3 .build/google-disconnect-evidence/close-product-build.py | 종료0. bash scripts/build.sh 컴파일·앱/중첩 서명·deep strict 검증, BUILD_OK. secret 읽기 제외/offline 옵션 사용, 설치/실행 안 함 | close-product-build-01.log |
| python3 .build/google-disconnect-evidence/close-checkpoint.py | 종료0. 두 HEAD·94파일, checkpoint-09 대비 지정4파일, 기존 시험 본문/단언 보존·diff --check·Python compile | source-checkpoint-10.log |
| python3 .build/google-disconnect-evidence/close-private.py hejo 및 canonical | 각각 종료0. 최신 전체 추적 파일/미추적 작업 후보, 임시 index·실제 index 불변 | close-private-hejo.log/.json, close-private-canonical.log/.json |

최종 변경본·보호 문서·제품/시험 빌드와 전후 실패/성공·프레임/렌더·보고 대조는 close-final-check.json이다. 변경 없는 team/설치·배포/Python 전체/앞서 수용된 IR-1 전체 화면은 이전 증거를 유지했다. 독립 검토·GD-T19 운영 실계정 증거를 이 자체 시험으로 대신하지 않는다. 다음은 같은 Terra의 잔여 IR-1 재검토이며 판정/계획/수락 원본은 구현자가 갱신하지 않는다. 운영·실계정·재시작·커밋·푸시는 실행하지 않았다.


## 이전 독립 리뷰 IR-1 — checkpoint-09 제출

받은 인계는 tasks의 ‘독립 리뷰 IR-1 보완 인계’와 [Terra 독립 검토](independent-review.md)다. 위험도 고위험/증거 수준2·3·4 경계를 유지한다. 이번 보완은 GD-T17 수준3 화면/전송 관측이며 GD-T19 수준4 실계정 증거를 대신하지 않는다. IR-1 종료 판정은 Terra 재검토에 맡긴다.

### 변경과 실제 경로

ConnectionsTests의 새 googleDisconnectUITests는 실제 ConnectionsWindow/NSHostingView·NSAlert·인증 NSPanel을 띄운다. SwiftUI 버튼은 노출된 실제 접근성 노드의 press, AppKit 기본 버튼은 실제 NSButton.performClick으로 조작한다. 이 fixture 프로세스의 AXEnhancedUserInterface/AXManualAccessibility만 켜 SwiftUI가 실제 컨트롤을 노출하도록 했다. 시스템 접근성 권한·보안 창·창 활성화 정책·제품 코드는 바꾸지 않는다. SwiftUI 노드가 프로토콜 채택 없이 노출되므로 Objective-C의 실제 접근성 selector를 사용하며, 값 대입으로 UI를 꾸미지 않는다. AppKit 속성 노출 호출의 deprecated 경고는 이 시험 경계의 기존 API 사용 사유이며 억제하지 않았다.

새 google_connection_fixture.py는 127.0.0.1 임의 포트의 aiohttp WebSocket 가짜 서버다. 앱의 GateClient→ConversationController→ConnectionsWindow 요청/ref 응답 경로를 그대로 사용하며 model.send·모델 문서·계정 값을 주입하지 않는다. 가짜 서버만 계정/세션 상태를 소유한다. 공용 스키마의 clientFrame/serverFrame으로 송수신을 각각 검사한다. 재인증 승인과 브라우저 미실행, 기존 pollingWait 시간만 주입한다. 실제 Keychain/Google/API/운영 홈은 사용하지 않는다.

원본 TestMain에 --google-disconnect-ui 제한 진입점만 추가했다. 기존 Google·기본 연결 시험의 기대값·skip·기본 실행 흐름은 그대로다. 새 시험은 임시 HOME/HERMES_HOME/LocalStore/메모리 자격을 사용한다. 제품 동작의 의미 변경은 없다.

### 실제 화면과 전송 관측

| 범위 | 화면/동작 확인 | 가짜 서버의 독립 확인 |
|---|---|---|
| 삭제 확인 거절/수락 | 실제 확인 시트의 직원 연결·이메일·전용 인증 삭제, 다른 직원/회사 보존, 다음 계정 선택 문구와 버튼. 거절 후 실제 목록 유지 | 확인 수락 뒤 reauth=true와 forget_account 값. 전체 해제 프레임은 의도한 두 번뿐이며 거절의 추가 전송 없음 |
| 해제 후 상세·목록 | 기존 이메일이 없고 실제 연결 버튼 존재. 뒤로/새로 확인 버튼을 눌러 목록 재조회 후에도 이메일 없음 | 해제 응답 뒤 새 connections 요청과 미연결 문서 |
| 다시 연결 성공 | 실제 인증 시트의 서버 Mac/다른 Mac 안내. 승인 후 실제 목록에 가짜 새 계정, 이전 이메일 없음. 새로 확인 후에도 유지 | 시작/폴링 프레임과 서버의 새 계정 승인·재조회. AppKit 모델 대입 없음 |
| 취소 실패와 성공 | 실제 인증 취소 버튼. 실패는 ‘취소 확인 안 됨’, 성공은 ‘인증을 취소했어요.’. 시트 종료와 연결 상태 표시 | 소유 세션별 account_cancel/reauth=false, 실패/성공 응답을 각각 구분 |
| 만료 | 인증 시트 관측 후 기존 pollingWait를 가속. 실제 시트가 닫히고 ‘동의 시간이 초과됐어요.’가 표시되며 계정 없음 | 세 번째 세션의 실제 oauth_poll 정확히450회, 뒤 소유 세션 취소와 목록 재조회 |
| 창 종료·재열기 | 인증 중 실제 부모 NSWindow.close가 windowWillClose를 발생시킴. 창/시트 종료 뒤 재열고 실제 연결 버튼·계정 없음 확인 | 네 번째 세션만 취소, 종료 후/재열기 후 connections 재조회 |

창 종료 시험은 NSWindow.close의 실제 수명 이벤트를 검증한다. 인증 시트가 붙은 부모 performClose는 진행되지 않으며 이 시트에는 닫기 버튼이 없다. 따라서 사용자 빨간 닫기 버튼이 인증 중 활성화됐다고 주장하지 않는다. 직접 model.close 호출로 창 종료 증거를 대체하지 않았다. 이 구체적 관측 범위를 Terra가 GD-T17에 대조해야 한다.

화면 증거는 실제 NSView 캐시 렌더 PNG와 실제 접근성 트리 텍스트13쌍이며 `ir1-ui-07/`에 있다. 해제 목록·가짜 새 계정 목록·취소 실패·만료·재열기 렌더를 직접 확인했다. 캐시 렌더의 합성/애니메이션 한계와 접근성 관측을 구분한다. 전송 원본은 같은 폴더 frames.json이다.

### 실행 결과와 한계

원래 작업 폴더에서 기존 connections-env.sh를 source하고 HEJO_TEAM_KIT_LIB/PYTHONPATH를 격리 team worktree로 명시했다. 아래 runner 로그의 첫 JSON에 정확한 argv/cwd/선택 환경·HEJO_PYTHON·서명 바이너리/Swift/fixture 지문, 마지막 JSON에 종료 코드가 있다. 자식 cwd는 hejo worktree의 app이다.

| 명령 | 실제 결과 | 증거 |
|---|---|---|
| python3 .build/google-disconnect-evidence/ir1-ui-build.py | 최종 Swift 컴파일·서명·codesign 검증 각각0 | ir1-ui-build-07.log |
| python3 .build/google-disconnect-evidence/ir1-run.py ui 07 | 종료0. 실제 AppKit 왕복·APP_TEST_OK·loopback frame 계약 PASS, 자식0/fixture 오류0 | ir1-ui-07.log, ir1-ui-07/ |
| python3 .build/google-disconnect-evidence/ir1-run.py google 01 | 종료0. 기존 Google 모델/실제 시트 PASS | ir1-google-01.log |
| python3 .build/google-disconnect-evidence/ir1-run.py connections 01 | 종료0. 원본 연결 전체·관리·불완전 응답·Google 모델 PASS | ir1-connections-01.log |
| python3 .build/google-disconnect-evidence/ir1-checkpoint.py | 종료0. hejo29/team65, checkpoint-08 대비 시험3파일만 변경, 원래 시험 본문 보존·두 diff --check·새 Python compile | source-checkpoint-09.log |
| python3 .build/google-disconnect-evidence/ir1-private.py hejo 및 canonical | 각각 종료0. 전체 추적 파일과 미추적 작업 후보를 임시 index로 검사, 실제 index 불변 | ir1-private-hejo.log/.json, ir1-private-canonical.log/.json |

초기 실패 증거는 지우지 않았다. build-01은 접근성 프로토콜 이름 컴파일 오류(종료1) 후 수정했다. ui-01/02는 방향별 스키마 선택 누락, ui-03은 SwiftUI 노드 노출 누락, ui-04는 기본 버튼의 접근성 press 경로, ui-05/06은 시트가 붙은 창의 performClose 관측에서 종료1이었다. 최종 fixture는 이 원인을 고쳤으며 기존 단언을 완화하거나 제품 실패를 무시하지 않았다. 각각의 파일·바이너리 지문으로 초기 후보와 최종 결과를 구분한다. 무변경 Python522/team/배포/제품 빌드/기본9함수는 이전 증거를 유지했다. 단일 앱 기본 모드 전체 성공이나 실제 OAuth 성공을 추가로 주장하지 않는다.

실제 화면 관측의 결함 검출도 확인했다. 공개 fixture의 임시 사본에서만 해제 뒤 옛 계정을 남기도록 한 번 바꿨다. 같은 서명 바이너리가 실제 해제 상세/연결 버튼 관측에서 종료1로 실패했고 driver는 기대한 검출을 확인해 종료0이다. 로그 `ir1-ui-mutation-stale-01.log`, 처분 `ir1-mutation-01.json`; 원본 fixture/제품/시험 바이너리는 불변이며 임시 변형은 제거했다. 정상 시험 성공을 뒤집는 결함이 실제 화면 단언에 잡힌다는 증거이며 독립 검토를 대신하지 않는다.

문서/증거·실제 변경본 최종 대조는 `ir1-final-check.json`에 남긴다. 전체 공개 검사 뒤 결과 설명만 보완한 보고서는 별도 범위 검사 `ir1-report-private.log`로 확인했다.

다음은 같은 Terra 독립 리뷰의 IR-1 재검토다. independent-review.md·verdict/tasks/handoff의 검토 처분은 구현자가 대신 수정하지 않는다. GD-T19 운영/실계정 승인과 푸시 승인은 별개이며 이번에는 요청하거나 실행하지 않았다.


## 이전 사용자 완료 지시 후 — checkpoint-08 마무리 기록

### 개인값 정리

승인 원본은 tasks 마지막 절과 `task05-private-baseline-01.json`이다. 원문 값은 출력/인계하지 않고 기존 검사기의 변경 없는 내부 비교 함수를 사용해 지정된 30개 행의 실제 일치 부분만 가짜 값으로 치환했다. 전체14파일·변경30행을 원래 행 지문과 대조했다. HTML 태그·속성·style/script 블록을 원본과 바이트 비교해 그대로임을 확인했다. 파일 삭제·레이아웃/기능 변경·스캐너/허용 목록 변경은 없다. 치환 내역은 원문 없는 행 지문과 위치만 `finish-redaction.json`에 있다.

hejo 전체 공개 검사는 실제 owner 입력을 내부 비교에만 사용했고, 별도 index에 HEAD와 미추적 후보 5개를 포함해 실행했다. 실제 index는 전후 동일하다. `finish-private-hejo.log`/`.json`은 종료 0이다. canonical 원래 폴더도 task 문서11개까지 포함한 전체 검사 종료 0이다(`finish-private-canonical.log`/`.json`). 두 실제 index 모두 불변이다. 이후 보고 결과 문구만 갱신한 부분은 보고서 범위 검사로 확인했다. 이전 30건 실패는 정리 전 이력이며, 범위 검사0으로 전체 실패를 대체하지 않았다.

### UI 시험 보완과 실제 결과

`app/Tests/ConnectionsTests.swift`는 AT-HC-27 성공 조건 visible/key/입력 정리/busy 해제를 그대로 유지한다. show 다음 임의 0.1초 관측만 기존 waitFor(5)의 유한 상태 관측으로 바꿨고, 활성/비활성·key 전환·sheet 종료 알림의 시간을 기록한다. 관측 코드는 창을 key로 강제하거나 앱을 별도로 활성화하지 않는다. 기한 내 성공 조건이 오지 않으면 실패한다. 제품 show/restoreFocus는 수정하지 않았다.

제한 실행 진입점은 `--connection-supplement management|incomplete`와 `--remaining-basic <원래 함수명>`이다. 원래 private 연결 관리/불완전 응답 함수를 직접 호출하며 내부 단언·흐름은 그대로다. 불완전 응답의 기존 문서 fixture는 원본 literal 하나를 공용 함수로 옮겨 동일 데이터를 재사용한다. 기본 모드의 호출 순서·실패 중단 동작은 변경하지 않았다. 별도 모드 성공을 원본 연결 suite 전체 성공으로 표시하지 않는다.

| 실행 범위 | 실제 결과 | 로그 |
|---|---|---|
| Swift 시험 실행 파일 빌드·기존 인증서 서명·서명 검증 | 각각 종료 0. 제품 빌드/설치 반복 아님 | `finish-ui-build.log` |
| GUI 준비 전 원본 connectionsTests 전체, --task32-capture | 종료 1. sheet 종료 알림만 두 번 관측, 5초 동안 활성/key 조건이 오지 않음. active=false, visible=true, key=false, fields=0, busy=false, sheets=0, canKey=true, keyWindowPresent=false, securityAgentFront=true | `finish-ui-connections.log` |
| GUI 준비 전 원본 connectionManagementTests 전체, --connection-supplement management | 종료 1, 약8초 후 기존 waitFor의 timed out. 이 원본 함수에서 해당 wait는 AT-CM-35의 NSApp.isActive/visible/key 조건 한 곳이다. 그 전 모델 단언은 통과했지만 실제 focus 네 조합 전부 성공은 아님 | `finish-ui-management.log` |
| 원본 connectionIncompleteReplyTests | 종료 0, TASK-13 INCOMPLETE REPLY PASS | `finish-ui-incomplete.log` |
| 원본 Google 모델·실제 인증 시트 대역 | 종료 0, 두 PASS와 APP_TEST_OK | `finish-ui-google.log` |
| progressLayoutTests | 종료 0 | `finish-ui-progressLayoutTests.log` |
| threeTapTests | 종료 0 | `finish-ui-threeTapTests.log` |
| roomsTests | 종료 0 | `finish-ui-roomsTests.log` |
| bubbleReplyTests | 종료 0 | `finish-ui-bubbleReplyTests.log` |
| petNotificationTests | 종료 0 | `finish-ui-petNotificationTests.log` |
| picturesSidebarTests | 종료 0 | `finish-ui-picturesSidebarTests.log` |
| appIconTests | 종료 0 | `finish-ui-appIconTests.log` |
| loginTests | 종료 0, 기존 대역 로그인/발견 fixture | `finish-ui-loginTests.log` |
| composerTests | 종료 0 | `finish-ui-composerTests.log` |

GUI 준비 전 합산 실행 driver는 종료 1이다. 정확한 argv/cwd/선택 환경·기존 HEJO_PYTHON·서명한 바이너리 지문과 각 종료 코드는 `finish-ui-results.json` 및 각 로그에 있다. 모두 가짜 HERMES_HOME/LocalStore/명부/서버/자격으로 격리했다. 외부 보안 대화를 조작하거나 실계정 동의를 하지 않았다. 변경 없는 gate/Python 전체522·team·제품 빌드·배포·기존 후속13fixture·airport-check는 이전 증거를 재사용한다.

### 사용자 GUI 준비 후 재검증과 다음 경계

사용자가 SecurityAgent 보안 대화를 직접 처리했고 GUI 세션이 준비됐다고 확인했다. 비밀값/대화 내용은 받지 않았으며 자동 조작도 하지 않았다. checkpoint-08의 두 HEAD·93파일 집합/지문, 빌드 입력 전체와 기존 서명 실행 파일 지문을 대조하고 codesign --verify --strict 종료 0을 확인했다. 재컴파일·재서명·제품 변경 없이 실패 두 범위만 실행했다.

| 재검증 범위 | 실제 결과 | 로그 |
|---|---|---|
| 원본 connectionsTests 전체, --task32-capture | 종료 0. AT-HC-20~29, AT-CM-30~38, 불완전 응답, Google 모델 및 APP_TEST_OK. 활성/key 이벤트 관측, HC27 뒤 재시작 확인·undo 단언까지 도달 | `finish-ui-resume-connections.log` |
| 원본 connectionManagementTests 전체, --connection-supplement management | 종료 0. AT-CM-30~38 APP PASS와 APP_TEST_OK. 기존 실제 focus 조건 포함 | `finish-ui-resume-management.log` |

`source .build/connections-env.sh` 후 HEJO_TEAM_KIT_LIB/PYTHONPATH를 기존 team worktree로 명시한 `python3 .build/google-disconnect-evidence/finish-ui-resume.py`는 종료 0이다. 자식 실행 cwd는 hejo worktree의 app이며, 정확한 argv/선택 환경·가짜 HOME/HERMES_HOME·서명 바이너리 지문은 각 로그에 있다. 선행 지문/서명 검사는 `finish-ui-resume-preflight.json`, 합산 결과는 `finish-ui-resume-results.json`이다. 기존 11개 성공 범위는 반복하지 않았다.

이번 환경 준비 후 같은 실행 파일에서 두 실패 범위가 통과했다. 이전 실패의 세부 원인을 제품 결함이나 SecurityAgent 하나로 확정하지 않는다. 원본 연결 전체와 기본9함수의 미실행 범위는 각각 실제 성공 증거로 해소했으며, 단일 기본 모드 전체를 새로 실행해 성공했다고 주장하지 않는다. 실제 사용자 OAuth와 운영 적용은 미실행이다.

독립 리뷰는 구현·설계 비참여 다른 모델을 호스트가 별도로 배정해야 한다. 최신 검토 대상은 checkpoint-08과 canonical 계약/보고/로그이며 checkpoint-07 대비16파일의 제한 변경을 포함한다. 독립 리뷰 결과와 구체적 지적 처분 뒤 결과 커밋·운영/복구·푸시 승인 자료를 고정한다. 아직 커밋/푸시 준비 완료가 아니며 운영 적용·실계정 OAuth·재시작·푸시는 실행하지 않는다.


## 이전 왕복 6 — UI 실행 경계 조사와 독립 리뷰 인계

**제품·시험 원본은 checkpoint-07 그대로다.** 이번에는 구현 참여자의 제한적 UI 원인 조사만 수행했다. 새 구현·전체 pytest·전체 UI·설치/배포·제품 빌드를 반복하지 않았다. 독립 검토를 대신하지 않으며 `independent-review.md`는 구현자가 작성하지 않았다. 호스트가 구현 비참여 다른 모델 및 설계 비참여 조건을 충족하는 리뷰를 배정해야 한다. 기존 UI 작업의 예외 처분을 이 Google 작업에 자동 적용하지 않는다.

### AT-HC-27: 관측된 조건과 미확정 원인

- [확인] 왕복 5의 원본 전체 실행 및 서명한 현재/기준 HEAD는 같은 AT-HC-27에서 종료 1이었다. 원본 관측은 visible=true, key=false, fields=0, busy=false, sheets=0이다. 입력 정리 실패와 창 미표시 실패는 이 관측과 다르다.
- [확인] `app/Sources/ConnectionsWindow.swift:381`의 show는 이미 NSApp.activate와 makeKeyAndOrderFront를 호출한다. 해당 활성화 호출은 기준 HEAD에도 있다. Google 인증 작업이 없는 이 fixture를 보고 활성화 호출 누락이나 새 Google 회귀라고 판단하지 않는다.
- [확인] 시험은 `app/Tests/TestMain.swift:341`의 accessory 앱으로 실행되며 `ConnectionsTests.swift:290`에서 입력 종료 후 show 전후 각각 0.1초만 기다린다. 이 지점에 앱 활성/key 이벤트 장벽은 없다. 입력 sheet의 종료는 Combine 구독이 만든 MainActor Task와 AppKit sheet completion에서 비동기로 처리한다.
- [확인] 현재 실행 조건을 관측하려고 임시 시험 사본에 출력 한 줄만 추가했다. 원본 소스·단언·대기·호출 순서는 유지했고 기존 테스트 하네스처럼 서명한 진단 바이너리의 `--task32-capture`만 실행했다. 컴파일/서명 종료 0, 시험 종료 1로 같은 단언이 재현됐다. active=false, canKey=true, frontmostIsSelf=false, keyWindowClass=none, parentLevel=0, authenticating=false였으며 전면은 외부 SecurityAgent였다. 보안 대화를 열람·승인·종료하지 않았다. 진단 사본/바이너리는 로컬 증거용이며 release 산출물이 아니다.
- [미확정] 앱이 활성화 요청 뒤에도 비활성인 구체적 이유, 보안 에이전트 전면 상태와의 인과관계, sheet 종료 타이밍의 기여는 이 관측만으로 확정하지 못한다. 현재는 시험이 요구하는 활성/key 조건을 충족하지 못한 상태로 분류한다. 제품 창 처리의 기존 결함 여부와 실제 사용 환경의 성공 조건은 별도 UI 담당의 판단이 필요하다.

기존 [UI-CLEAN 판정](../HEJO-UI-CLEAN-20261123/verdict.md)과 [TODO-DRAWER 보고](../HEJO-TODO-DRAWER-20261120/impl-report.md)에도 과거 비활성 앱/동일 단언 기록이 있다. 이는 조사 방향의 참고이며 다른 HEAD의 결과를 현재 성공 증거로 가져오지 않았다. 과거 진단 원본 로그는 현재 폴더에서 확인하지 못했고, 현재 진단의 활성 상태는 새 로그에서 직접 확인했다. 과거 연결 시험 제외 방식도 이번에 반복하지 않았다.

UI 후속 범위는 활성화·key/sheet 이벤트의 실제 순서 관측이다. 동일한 서명/격리/원본 fixture를 쓰고 다른 GUI 실행과 겹치지 않게 하며, 외부 보안 대화의 사유 확인·처리는 사용자가 판단해야 한다. 원본 show 뒤 실제 활성/key 상태가 성립하는지 확인하고, 활성=true인데도 key=false가 유지될 때 기존 창/sheet 처리 수정이 필요한지 UI 담당에게 반환한다. 별도 승인 없이 활성 정책·단언·고정 대기·코드 흐름을 바꾸지 않는다. 통과한 실행 조건을 확보했다고 주장하지 않는다.

### 원본 기본 모드에서 실패 이후 미실행

`connectionsTests()`는 connectionsScreenTests → connectionManagementTests → connectionIncompleteReplyTests → googleDisconnectTests 순서다. AT-HC-27는 **connectionsScreenTests 안**에 있다. 따라서 connectionManagementTests 전체도 미실행이며, 이미 그 앞에서 출력한 AT-HF-83 PASS는 연결 suite 전체 완료를 뜻하지 않는다.

| 중단 위치 뒤 범위 | 해당 기본 실행의 상태 |
|---|---|
| connectionsScreenTests 나머지 | 재시작 확인 sheet의 level/취소, unknown/connected 행별 undo 제목·버튼, 정상 정리/PASS 미실행 |
| connectionManagementTests 전체 | AT-CM-30~38 메뉴·설정 변경·해제 확인/재인증 순서·입력 수명·실제 focus 복원 미실행. 특히 AT-CM-35의 NSApp.isActive/key wait도 미도달 |
| connectionIncompleteReplyTests | 불완전 응답 처리 미실행 |
| googleDisconnectTests | 기본 모드에서는 미실행. 이전 별도 --google-disconnect 성공과 구분 |
| progressLayoutTests | AT-HF-85 미실행 |
| threeTapTests | AT-HF-86 미실행 |
| roomsTests | AT-HF-70/71/80 기본 단위/UI 시험 미실행 |
| bubbleReplyTests | AT-HF-82 기본 단위/UI 시험 미실행 |
| petNotificationTests | AT-HF-81 미실행 |
| picturesSidebarTests | AT-HF-68/69 sidebar 기본 시험 미실행 |
| appIconTests | AT-HF-66 미실행 |
| loginTests | AT-HF-58/59/60 대역 로그인/발견·설정 이전 시험 미실행 |
| composerTests | COMPOSER_PLAIN_PASS 해당 시험 미실행 |

기본 모드의 connectionsTests 다음 직접 호출은 위 마지막 9개다(`TestMain.swift:303` 이후). 최종 기본 PASS/APP_TEST_OK도 미도달이다. googleDisconnectSheetTests는 기본 unit에 편성되어 있지 않고 별도 --google-disconnect 분기에서 실행되므로, 그 별도 성공을 기본 모드 성공으로 세지 않는다.

### 후속 fixture가 실제로 확인한 경로

아래는 왕복 5의 실제 성공 증거를 재사용한 범위다. 이번에 다시 실행하지 않았다. 동일 이름의 기능 일부가 겹쳐도 위 기본 시험 함수의 성공을 대신하지 않는다.

| fixture | 실제 AppKit/Python 진입점·확인 범위 |
|---|---|
| network | network(args): 임시 게이트 짝짓기/키체인/재개·단절 복구 |
| conversation | conversationNetwork: 대화 HTTP/WS·업로드/버튼/전송/다운로드 |
| pictures | pictureNetwork: 이미지 HTTP/cache; picturesSidebarTests 전체 아님 |
| thread | threadNetwork: 스레드 전송/UI 경계 |
| workspace | workspaceNetwork: workspace 전송/UI 경계 |
| bubble_reply | bubbleReplyNetwork: 답글 전송/UI; bubbleReplyTests 전체 아님 |
| home_room | homeRoomNetwork: 홈 방 전송/UI |
| rooms | roomsNetwork: 실제 gate+가짜 Hermes의 방 전송; roomsTests 전체 아님 |
| composer_target | composerTargetNetwork: 입력 대상 전송; composerTests 아님 |
| downloads | downloadsNetwork: 첨부 다운로드 경계 |
| web_pane | webPaneNetwork: 루프백 WebKit/다운로드·자격 비전달 |
| review55 | review55Network: 해당 네트워크 회귀 |
| hooks | Python HookTests와 기존 제품 --hook 경로; 기본 UI 9함수 아님 |

### 검증·호스트에 남긴 범위

- `python3 .build/google-disconnect-evidence/round06-ui-audit.py`: 종료 0. 두 HEAD/79개 지문·실제 호출 순서·fixture 진입점·이전 실패/성공 로그 대조. 로그 `round06-ui-readonly-audit.json`.
- 기존 HEJO_PYTHON의 `round06-focus-probe.py`: 진단 사본 컴파일/서명 종료 0, 대상 시험 종료 1, 기록 driver 종료 0. 정확한 argv/cwd/환경/소스·바이너리 지문과 stderr는 `round06-focus-probe.log`. 원본 79개 지문은 그대로다.
- 독립 리뷰는 호스트 배정 대상이다. canonical 계약·수락 명세와 실제 checkpoint-07 코드/로그를 읽고 OAuth·금고/전용 자격·binding/승인·파일 권한·배포 복구의 생산자/소비자를 확인한 뒤 independent-review.md에 범위·지적·근거·모델/역할 독립성을 기록해야 한다. 이 구현 대화의 조사나 진단은 그 조건을 충족하지 않는다.
- 기존 mockup 14파일/30건 정리는 별도 담당 또는 사용자 범위 승인 대상으로 유지한다. 이번에는 관련 원문 복제·수정/삭제·허용 목록 변경·전체 공개 검사 재실행을 하지 않았다. 구체적 독립 지적이나 승인된 정리 범위 없이 제품 구현을 재개하지 않는다. 운영·실계정 OAuth·재시작·커밋·푸시는 미실행이다.

## 왕복 5 보완과 검증

- `test_cm24_25_actual_cli_arguments`의 Google 개인 해제만 `options.disconnect_mode=forget_account`와 정확한 `--disconnect-mode forget_account` argv로 이관했다. connect/undo의 기존 argv·stdin 계약을 유지하고 다른 서비스 해제에는 새 플래그가 붙지 않는지 확인했다. 별도 5개 매개변수 시험은 누락/빈 값/잘못된 문자열/boolean을 `UPDATE_REQUIRED`로 거절하고 CLI 실행 표시 파일이 생성되지 않는지 검사한다. gate/시설의 삭제 확인 검사는 약화하지 않았다.
- 기존 환경 파일에서 `HEJO_PYTHON`을 명시 export하고 `HEJO_TEAM_KIT_LIB`/PYTHONPATH의 첫 경로를 실제 team worktree로 고정했다. 같은 실행 환경에서 `sys.executable`과 aiohttp 3.14.5 import 성공을 먼저 기록했다. 새 패키지를 설치하지 않았다.
- AppKit 전체 기본 모드는 hejo worktree의 `app` cwd에서 기존 Swift 시험 실행 파일과 제품 Pet 리소스를 사용했다. 임시 HOME/HERMES_HOME에 격리했으며 부모와 자식 stderr를 같은 로그로 받았다. `PostGroupTests.swift`는 명시한 HEJO_PYTHON을 선택하고 부모 환경을 복사한 뒤 자신의 임시 HERMES_HOME만 덮어쓴다. 실제 자식 PID의 실행 명령과 cwd도 ps/lsof로 확인했다. 정확한 로컬 실행 파일·전체 argv·선택 환경 값은 공개 문서 대신 아래 로컬 로그에 있다.
- 새 전체 실행은 `AT-PG-01...11,13 PASS` 후 AT-HC-27에서 종료 1이다. 이전 aiohttp import 실패는 해소됐다. 현재 key=false 관측과 기존 assertion을 유지했다. 기존 하네스처럼 서명한 현재/대조 실행 파일을 같은 격리 환경에서 `--task32-capture`로 실행해 둘 다 같은 AT-HC-27 종료 1을 확인했다. 대조 Sources/Tests 147개가 기준 HEAD와 일치함을 git show로 확인하고 이전 대조 빌드 산출물을 재사용했다. 전체 UI 성공이나 그 뒤 기본 모드 시험 실행을 주장하지 않는다.
- app/scripts/test.sh의 후속 UI fixture 13개를 별도로 실행했다. 임시 HOME에서 11개 성공, network/conversation 2개는 테스트 자격 저장 실패·시간 초과로 종료 1이었다. 기존 하네스의 인증서 서명과 기본 키체인 실행 환경을 적용한 재실행에서 두 fixture가 성공했고 무작위 테스트 계정 자격 정리도 확인했다. 이 두 실행만 기존 HOME의 키체인을 사용했으며 HERMES_HOME·LocalStore·명부·서버·토큰은 모두 대역/임시 값이다. CLI 설정은 내용 열람 없이 metadata, Downloads는 항목 이름만 전후 비교해 무변경을 확인했다. 서명과 HOME의 개별 기여는 분리 시험하지 않았다.
- 제품 빌드·독립 배포 suite·변경 없는 team suite·airport-check·네 결함 주입은 기존 증거를 유지했다. 요청한 hejo 전체 Python 회귀에는 release/설치 시험도 포함된다. 새로운 전체 공개 검사를 반복해 통과로 표시하지 않았다. 현재 hejo 14파일과 canonical 문서 11파일 범위 검사만 추가했고 아래 전체 실패와 구분한다.

| 이번 실행 | 실제 결과 | 로그(원래 폴더의 `.build/google-disconnect-evidence/` 기준) |
|---|---|---|
| 기존 HEJO_PYTHON의 `-c` aiohttp import 및 hejo `-m pytest gate/tests tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp <짧은 임시 경로>` | import 종료 0, 전체 pytest 종료 0, **522 passed / 기존 warning 1개** | `round05-python-01.log` |
| app cwd의 `.build/google-disconnect-tests <제품 Pet 리소스>` 전체 기본 모드 | 종료 1. AT-PG 성공, AT-HC-27 실패. 바이너리·Swift 파일 지문과 환경 기록 | `round05-app-full-01.log` |
| 실제 PostGroup 자식 ps/lsof 관측 | 종료 0. 지정 Python·실제 argv/cwd 확인, 자식 stderr는 위 전체 로그 | `round05-app-child-processes.log` |
| 후속 UI fixture 13개 최초 실행 | 11개 종료 0, network/conversation 2개 종료 1. 합산 driver 종료 1 | `round05-app-fixtures-results.json`, `round05-app-<fixture>-01.log` |
| 기존 하네스 서명·키체인 환경의 network/conversation 재실행 및 보호 검사 | 서명/검증·두 fixture·설정/Downloads 보호 검사 모두 종료 0. 테스트 자격 정리 성공 | `round05-app-keychain-environment.log` |
| 서명한 현재/기준 HEAD `--task32-capture` | 각각 종료 1, 같은 AT-HC-27. 대조/관측 driver 종료 0 | `round05-app-hc27-control.log` |
| 두 worktree diff --check·Python compile·전체 변경 지문 | 종료 0, hejo 14/team 65. checkpoint-06 대비 시험 파일 1개만 변경 | `source-checkpoint-07.log` |
| 현재 hejo 14파일에 기존 공개 검사기 적용, 실제 owner 내부 비교·임시 index | 종료 0. 실제 index 불변. 범위 검사이며 전체 검사 아님 | `round05-private-hejo-scope-02.log` |
| 현재 canonical 문서 11파일의 같은 범위 검사 | 종료 0. 실제 index 불변. 전체 실패를 대체하지 않음 | `round05-private-canonical-scope.log` |

범위 검사 첫 시도 `round05-private-hejo-scope.log`는 기본 Python의 YAML 의존성 누락으로 종료 2였다. 기존 환경 파일의 PATH를 적용하고 python3의 ruamel import를 확인한 뒤 위 재실행했다. 검사기·허용 목록·owner 입력은 변경하지 않았다.

## 7판 변경과 이유

- `install/check_google_compat.py`: 일반 installed 영수증 탐색을 유지하면서 failed/uninstalled 로컬 설치 재실행에만 좁은 bootstrap 예외를 추가했다. 지원 영수증·실제 root/profile 코드 링크 복구·전환 기록 부재·잔존 전용 자격/미완료 Google 장부 부재를 읽기 전용 검사한다. 상태 문자열만 믿지 않으며 설치 중간 상태·읽기 실패·중복 키·알 수 없는 버전/형식·symlink는 거절한다. 과거 before 대상은 검사기로 실행하지 않는다.
- 같은 검사기의 `deployment_guard`: 기존 금고 쓰기 잠금 `owner/.app-connect.lock`을 배포 배타 처리에 재사용한다. 새 상태 저장 원본은 없다. 검사기를 한 번 고정한 뒤 잠금 아래 변경 직전 재확인하고 트랜잭션 동안 잠금을 유지한다. 전환 삽입/잠금 점유 시 설정·링크·영수증·금고·자격을 바꾸지 않는다. 이 잠금 경로는 비밀 내용이 없는 기존 시설 mutex다.
- `install/hejo-install`: 후보 지원 선언과 일반 파일을 검사기 실행보다 먼저 검사한다. 검사기 소스는 정확한 패키지 파일에서 읽어 메모리에 로드하여 Python module cache나 cwd/PATH에 의존하지 않는다. 영수증 업그레이드 쓰기보다 먼저 preflight/잠금/재확인을 수행한다. 기존 사용자 config 비교·conflict/--force·device 보존·durable rollback을 유지한다.
- 같은 installer의 `update_code_links`: 호환 release A에서 새 release B로 root/profile link와 영수증 after를 갱신한다. 기존 코드 링크를 모두 비교하고 원래 패키지도 고정된 현행 검사기로 확인한다. 프로필을 먼저, 루트를 마지막에 갱신하며 I/O 예외에는 호환 이전 링크/영수증을 복구한다. 사용자 변경 링크를 덮어쓰지 않는다.
- 운영 `hermes-team-kit-deploy`: 기존 금고 잠금 안에서 검사 후 시설 트리를 교체하고, 기존 `plugin_store` snapshot/overlay/restore_host를 재사용해 profile overlay의 신규/삭제 항목을 반영한다. 직원 plugin.yaml은 보존한다. 실패하면 고정된 검사기로 이전 시설을 확인한 뒤 코드와 overlay를 복구한다. 미지원 구 시설은 자동 복구하지 않는다.
- 운영 `hermes-plugin-store`: migrate/restore-copies/실패 복구도 같은 기존 mutex 안에서 공통 검사를 사용한다. team의 검사기 탐색에는 hejo 로컬 복구 예외를 확대하지 않았다.
- `tests/acceptance/test_google_deployment.py`: failed/uninstalled 긍정·부정·경합, 후보 코드 실행 전 지원 선언 검증, 정상 owner_vault YAML serializer 왕복, 실제 release A→B root/profile 갱신, 호환 예외 복구와 overlay 추가/삭제·실패 복구를 추가했다. 가짜 소스에서 실제 hejo-release를 실행하며 수동 검사기 복사 fixture는 없다.
- 운영 `hermes_governance/google_calendar_undo.py`: 확대 회귀에서 기존 호출자가 새 td.personal_scopes.current 인터페이스를 갖지 않는 문제를 발견했다. 실제 인증된 직원 home의 기존 root_of/profile_of를 원본으로 binding을 확인하도록 고쳤다. 기존 company/legacy 호출 계약을 유지하고, 전환 전 승인/undo와 동일 이메일 재연결을 계속 거절한다. 기존 시험은 수정하지 않았고 `test_queued.py`에 두 binding 회귀를 추가했다.
- `schemas/hejo-wire-v1.json`: 설명문만 추가했던 변경이 기존 wire 전체 바이트 해시 시험을 깨뜨려 이번 작업 변경을 제거했다. 기존 string/values 구조가 이미 새 동작을 담으며 삭제 의미·재인증·작업 소유권은 gate/시설이 검사한다. wire 해시 기대값은 바꾸지 않았다.

## 유지한 기존 구현

TASK-02/03: `google_connection*.py`의 직원 금고 연결·전용 봉투·장부 barrier·요청 lease·CAS·OAuth worker/state/PKCE/신원 검증과 기존 account/조립/메일·Calendar/승인·대기/undo/review/worker/진단 소비자를 유지했다. 회사/미전환의 기존 자격 선택과 금고 밖 두 번째 계정 원본을 만들지 않는 원칙을 유지한다.

TASK-03A: 기존 register wrapper·scoped_context·실제 승인 hook/middleware에 typed 도구 4개를 연결했다. 선택 팩/manifest·역할·소유자 대화·배경·파일 경계와 정확한 명령/인자/binding/승인 시점을 검사한다. 업로드 파일 descriptor와 다운로드 parent descriptor를 고정한다. Calendar 쓰기는 기존 승인/undo를 재사용한다. 현재 개인 직원 gmail modify는 기존 회사 업무 전용 제한으로 거절하며 새 도구 노출은 권한 부여가 아니다. SDK 24명령 보존과 모든 직원의 모든 명령 허용을 구분한다. 전환 personal 직원용 스킬만 기존 조립 경로에 추가했고 sandbox/자격 사본/본체 우회는 없다.

TASK-04: gate 삭제 의미·재인증, 기기/직원별 status/cancel 세션과 AppKit 삭제 확인·서버 Mac 안내·취소·늦은 응답·900초 만료 처리를 유지했다. 다른 서비스/구 서버 capability 문구는 보존한다. 새 인증 화면은 AppKit NSPanel이다.

TASK-05 공통 검사기는 hejo `install/check_google_compat.py` 하나다. 각 저장소의 지원 선언은 별개다. release는 source/artifact 필수 파일을 검사하고 scripts/ 없이 동작한다. 연결된 홈 전체를 확인할 수 없는 기존 비어 있지 않은 공유 출력 교체는 계속 거절한다. 새 release 생성→각 홈 installer 갱신이 정상 경로다.

## 이전 구현·검증 기록

로그는 원래 폴더의 `.build/google-disconnect-evidence/` 기준이다. HEJO_PYTHON은 기존 `.build/connections-env.sh`를 사용하며 HEJO_TEAM_KIT_LIB/PYTHONPATH는 실제 team worktree lib로 고정했다. 새 테스트와 실행 대역은 임시 HERMES_HOME·가짜 명부/금고/자격을 사용했다. HOME은 기본 격리하며 위에서 명시한 두 키체인 fixture와 인증서 서명만 기존 HOME을 사용했다. HEJO_SKIP_GOOGLE_SECRET=1로 비밀 config를 읽지 않았다.

| 실행 명령/범위 | 실제 결과 | 로그 |
|---|---|---|
| hejo `$HEJO_PYTHON -m pytest tests/acceptance/test_google_deployment.py tests/acceptance/test_install.py --confcutdir=tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 124 passed. 기존 설치 52개 포함. 최종 후보 선언 검증까지 반영 | `task05-v7-final-install-01.log` |
| v7 첫 단계: install/release/deployment | 종료 0, 81 passed. 기존 3실패 해소 | `task05-v7-install-01.log` |
| v7 복구/경합/A→B/overlay 경계 첫 실행 | 종료 0, 69 passed. 이후 후보 선언 부정 3개 추가 | `task05-v7-boundaries-01.log` |
| team 기존 관련 7파일 pytest --noconftest | 종료 0, 82 passed. app_connect/config_assembly/calendar_scope_writable/google_calendar_app_undo/app_scope/app_scope_unicode/app_input_scope. 실제 argv 로그에 있음 | `task05-team-regression-02.log` |
| 같은 기존 회귀 최초 | 종료 1, 3 failed / 79 passed. Google undo의 새 td 인터페이스 의존 결함을 제품에서 수정 | `task05-team-regression-01.log` |
| team `$HEJO_PYTHON -m pytest hermes/plugin-store/team-kit/tests/google_disconnect --confcutdir=hermes/plugin-store/team-kit/tests/google_disconnect -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 156 passed. undo 수정 후 실제 등록/승인/파일/조립/sandbox 회귀 | `task05-team-google-01.log` |
| 위 test_queued.py -k calendar_undo_binding_uses_authenticated_employee_home | 종료 0, 2 passed / 17 deselected. 회사/legacy 호출 보호와 별개로 실제 home의 옛 binding 거절 | `task05-calendar-binding-01.log` |
| hejo `bash scripts/test.sh`, 짧은 임시 basetemp | 종료 1, pytest 2 failed / 510 passed. 이후 단계는 이 명령에서 실행되지 않음. 아래 실패 처분 참조 | `task05-full-hejo-01.log` |
| hejo pytest test_google_disconnect.py·gate/tests/test_connections.py·test_connections_screen.py·test_slack_move_gate.py, 짧은 basetemp | 종료 0, 87 passed. 이전 gate51의 argv 누락을 명령/대상 기록으로 보완하고 원래 wire 해시 회귀 성공 확인 | `task05-gate-final-01.log` |
| hejo `$HEJO_PYTHON -m gate.tests.gateway_delivery` | 종료 0. 실제 격리 multiplex gateway/플랫폼 전달, 외부 소켓·운영 비밀·격리 밖 쓰기 거절 audit 활성. 운영 gateway 재시작 아님 | `task05-delivery-01.log` |
| `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh` | 종료 0, BUILD_OK, codesign verify 성공. 기존 keychain 사용·HERMES_HOME 격리 | `task05-product-build-02.log` |
| 위 제품 빌드 첫 시도 | 종료 1. 임시 HOME에서 서명 인증서를 찾지 못함. 기존 keychain으로 실행 환경만 고쳐 재실행 | `task05-product-build-01.log` |
| team `./airport-check --snapshot "$PWD"` | 종료 0. boundary 80, document/compartments 0. 기준선 증가/재생성 없음 | `task05-airport-01.log` |
| 두 worktree git diff --check·변경 Python compile·SHA-256 생성/재독 | 종료 0, hejo 13개/team 65개. Python 각각 7/49개 compile | `source-checkpoint-06.log` |

실제 호출은 원래 폴더에서 worktree 경로를 지정한 경우도 있다. 표는 각 worktree 기준이며 정확한 argv/cwd가 새 실행 로그에 들어 있다. 오래된 로그의 argv를 추정해 만들지 않았다. 왕복 5에서 요청한 전체 Python 회귀는 위 최신 로그로 별도 수행했고, 변경 없는 나머지 범위는 증거를 재사용했다.

## 실패와 미완료의 처분

이전 `test_cm24_25_actual_cli_arguments`의 무확인 Google 개인 해제 성공 기대는 승인된 왕복 5 처분에 따라 위 시험으로 이관했고 전체 회귀에서 통과했다. 제품 거절은 그대로다. 이전 full pytest의 wire 설명 해시 실패도 기존 바이트 계약을 복원한 뒤 이번 전체 회귀에서 통과했다. 과거 `task05-full-hejo-01.log`의 2실패를 지우지 않고 최신 종료 0 증거와 구분한다.

AppKit AT-HC-27 창 활성 실패는 앞선 변경 전 HEAD 대조 빌드에서도 같은 assertion으로 재현됐으며 기존 로그를 유지한다. 새 Google NSPanel의 삭제 확인·취소·만료/늦은 응답은 `task04-app-build-07.log`/`task04-app-ui-04.log`에 수준2/3 증거와 실제 화면이 있다. v7은 Swift를 변경하지 않았다. 전체 AppKit 추가 실행 결과와 최종 개인값 결과는 아래 최종 증거 절에서 기록한다.

team의 기존 상위 conftest는 운영과 같은 값의 명부/금고 fixture를 강제로 지정한다. 이를 실행하지 않고 읽기 검토한 안전한 7파일을 --noconftest와 가짜 owner 값으로 검사했다. 따라서 전체 기존 team-kit suite를 통과했다고 하지 않는다. 새 Google suite의 전용 conftest와 실제 sandbox 시험은 그대로 실행했다.

강제 프로세스 종료가 release 링크와 영수증 원자 쓰기 사이에 발생하면 installed 링크/영수증 불일치로 닫히며 7판 복구 예외로 우회하지 않는다. 이번 release 갱신 실패 시험은 I/O 예외 복구이며 이 구간의 강제 종료 후 자동 복구 성공까지 입증하지 않는다. 운영 인계에서 호환 수정 패키지를 이용한 복구 판단이 필요하다. 기존 인증 자격/금고의 저장 단계 프로세스 종료 시험과 이 한계를 혼동하지 않는다.

검사기는 JSON과 기존 정상 serializer의 block YAML을 지원한다. flow/merge/alias·중복 키·알 수 없는 형식을 ‘전환 없음’으로 추정하지 않으며 운영 적용 전 정상 원본 형식의 적합성은 별도 확인한다. 실제 금고 원문을 반환하지 않는다. 자격 백업 자동 복원·원본 전환 항목 자동 삭제·검사기 수동 복사/우회는 금지한다.

## AC별 자체 처분

아래는 구현자의 증거 처분이며 독립 최종 수락 판정이 아니다. 수준4 운영 시험을 수준2 대역으로 대체하지 않는다.

| AC | 증거/처분 |
|---|---|
| REQ-GD-01.AC-01 | GD-T01/17: CLI/목록 투영·기존 모델 증거 유지. IR-1 실제 AppKit 상세/목록의 이메일 제거·연결 버튼·재조회 증거 추가. 실계정은 미확인 |
| REQ-GD-01.AC-02 | GD-T01/02: 취소·재인증 거절 불변, 전용 자격 삭제/legacy 해제. 수준2 증거 |
| REQ-GD-01.AC-03 | GD-T03/20: 소비자·조립/스킬·worker·실제 sandbox/공식 도구 경계. 수준2 증거 |
| REQ-GD-02.AC-01 | GD-T04: 실제 OAuth 라이브러리 대역의 계정 선택/신원 검증. 실제 계정 선택은 미실행 |
| REQ-GD-02.AC-02 | GD-T05/17: 취소·만료·권한/신원/저장 실패와 AppKit 만료 대역. 실환경 미확인 |
| REQ-GD-02.AC-03 | GD-T06/07: state/PKCE·세대·기기/직원별 poll/cancel·늦은 응답. 수준2 증거 |
| REQ-GD-03.AC-01 | GD-T08: 다른 직원/회사/공용 자격 지문과 company/legacy 회귀. 실제 계정 불변은 미확인 |
| REQ-GD-03.AC-02 | GD-T09/20: SDK24명령·실제 등록→승인→handler/worker·조립, 기존 제한을 보존. 수준2 증거 |
| REQ-GD-03.AC-03 | GD-T10: 권한/배경·단건/계획 승인·저장 대기·메일/Calendar undo의 옛 binding 거절. 이번 Calendar 회귀 보완 |
| REQ-GD-04.AC-01 | GD-T11/12: 기존 인증 저장 단계 프로세스 종료·CAS/lease, 이번 복구 삽입/잠금 경합·I/O 복구. 배포 강제 종료 자동 복구는 위 한계 |
| REQ-GD-04.AC-02 | GD-T03/13: 단일 금고 원본·조립, absent/null/손상/unknown 분기와 읽기 무변경. 수준2 증거 |
| REQ-GD-04.AC-03 | GD-T14: 직접 Google undo 거절·각 배포 진입점·실제 release 설치/갱신/복구·R10/7판 예외. 124 통과 증거, 고위험 검토 필요 |
| NFR-GD-01.AC-01 | GD-T15/20: 기존 권한/경로·도구 보호 증거 유지. 승인된 공개 값 정리와 최신 격리/canonical 전체 검사0. Terra 독립 검토 제출 후 IR-1 재검토 대기 |
| NFR-GD-02.AC-01 | GD-T16: 임시 홈/가짜 데이터·외부 API 금지, 82+156+2와 gate87/설치124. 기존 hejo 전체522·후속13fixture 증거 유지. 이번 기본9/불완전 응답/Google 시트 통과. GUI 준비 후 원본 연결 전체·연결 관리 종료0, 기존 HC27/CM35 실패 해소. 전체 team 범위 제한 남음 |
| REQ-GD-05.AC-01 | GD-T17/18: 앞선 화면 증거 유지. 왕복11의 노출된 창 닫기 버튼·전송 불가/재열기·늦은 응답 보호와 기존 취소 회귀 통과. 실제 늦은 poll 안내 결함 수정. Terra 잔여 IR-1 재검토 대기, GD-T19 별개 |
| REQ-GD-05.AC-02 | GD-T19: 미실행. 별도 운영 인계 승인 뒤 사용자가 실계정 교체와 다른 직원 불변을 확인해야 함 |

요구된 네 결함 주입은 아래 별도 격리 실행으로 확인했다. 고위험 독립 검토·최종 제품 검토·현재 명세 반영·운영 적용/사용자 OAuth/화면 푸시 승인은 이 제출로 완료되지 않는다. 기획/검토 담당이 공개 검사/UI 최신 증거와 나머지 증거 한계를 처분한 뒤 TASK-06 운영 인계를 준비한다. 구현자는 운영/푸시를 실행하지 않는다.


## 최종 추가 증거

| 실행 | 실제 결과 | 로그 |
|---|---|---|
| 최종 Swift 시험 실행 파일의 전체 기본 모드, 정상 app cwd·새 제품 리소스·임시 HOME/HERMES_HOME | 종료 1. AT-PG-08 interruption fixture running에서 실패. 과거 결과다. 직접 선행 오류는 aiohttp import 실패였고 왕복 5에서 환경을 고쳐 AT-PG를 통과했다 | `task05-app-full-02.log` |
| 전체 AppKit 첫 시도 | 종료 1. 잘못 지정한 cwd의 .build에 스냅샷 파일을 만들지 못했다. runner cwd를 기존 app/scripts/test.sh와 맞춰 위 재실행. 제품 수정 없음 | `task05-app-full-01.log` |
| 별도 임시 프로세스의 메모리 내 결함 주입: T03 resolver fallback 허용 | 해당 수락 시험 종료 1로 결함 검출 | `task05-mutation-fallback.log` |
| T07 session/세대 비교 제거(restart 후 늦은 완료) | 해당 시험 종료 1로 결함 검출 | `task05-mutation-generation.log` |
| T09 worker credential을 공용 가짜 자격으로 교체 | 해당 시험 종료 1로 결함 검출 | `task05-mutation-worker-token.log` |
| T10 승인 binding 검사 제거 | 해당 시험 종료 1로 결함 검출 | `task05-mutation-approval-binding.log` |
| 위 네 결함 주입 driver | 종료 0. 네 기대 실패 모두 확인, 제품 소스 변경 없음 | `task05-mutations-01.json` |

네 주입은 임시 HOME/HERMES_HOME·가짜 명부/자격에서만 실행했고 실제 코드 파일을 고치지 않았다. 각각은 앞선 정상 Google suite에 포함된 시험으로 정상 통과와 주입 시 실패를 구분했다. 이 자체 점검을 독립 검증으로 부르지 않는다. 과거 AT-PG 실패와 현재 AT-HC-27 실패를 분리했다. 최신 실행 및 대조는 왕복 5 표를 따른다.

## 정리 전 공개 검사와 당시 차단

`python3 scripts/scan_private.py`를 실제 운영 owner 비교 입력으로 두 번 실행했다. 가짜 HERMES_HOME을 제거했고 검사기가 명부/금고를 내부 비교하는 기존 동작만 사용했다. 원문·일치 값·비밀 파일은 반환/열람하지 않았다. hejo worktree와 canonical 문서가 있는 원래 저장소 모두 종료 1이다. 각각 30건/14파일이며 전부 기존 HEJO-DRAWER-INLINE·HEJO-UI-CLEAN mockup이다. `git show HEAD:<파일>`의 줄 지문과 내부 대조하여 모든 검출 줄이 기준 HEAD에도 있음을 확인했다. 이번 작업 파일에서는 검출되지 않았다. 이 사실은 전체 공개 검사 통과가 아니다. 범위 밖 mockup을 임의 수정하거나 허용 목록/검사 기준을 완화하지 않았다.

새 미추적 코드·문서까지 검사하도록 별도 임시 Git index에 intent-to-add만 넣어 실행했다. 실제 index는 SHA-256 전후 동일하다. 스캐너는 수정하지 않았다. 로그는 `task05-private-hejo-01.log`, `task05-private-canonical-01.log`, 범위/종료 코드는 `task05-private-01.json`, 원문 없는 기준 HEAD 대조는 `task05-private-baseline-01.json`이다. 두 전체 검사는 checkpoint-05 시점이며 이후 작은 영수증 타입/secret 제외 변경과 최종 문서는 추가 범위 검사로 구분한다.

마지막 정적 확인에서 boolean 영수증 버전이 정수 버전으로 취급되는 Python 비교를 hejo/운영 bootstrap 모두에서 거절하도록 보강했다. 설치된 검사기 위치 거절 9개는 `task05-receipt-format-01.log`에서 종료 0(64 deselected)이다. release의 기존 secret 사후 삭제를 rsync 입력 제외로 바꿔 secret 파일을 복사하거나 열지 않게 했다. 읽기 권한이 없는 가짜 secret config를 심은 시험과 실제 배포본/두 위치/A→B 경계 7개가 `task05-release-final-01.log`에서 종료 0(72 deselected)이다. 이 변경은 실제 secret 파일을 사용해 시험하지 않았다.

추가 범위 검사 결과는 hejo 변경 13개와 canonical 작업 문서 11개 각각 종료 0이다. 실제 owner 비교를 유지하며 임시 index로 해당 범위만 선택했다. `task05-private-scope-hejo-01.log`, `task05-private-scope-canonical-01.log`, `task05-private-scope-01.json`에 범위를 기록했다. 이 축소 검사는 실패한 전체 공개 검사를 대체하지 않는다. 최종 코드에 대한 airport-check도 `task05-airport-final-01.log`에서 종료 0이다.

## 운영 인계 초안 — 실행 미승인

1. 최종 검토·공개 검사 차단을 처분한 뒤 각 저장소의 승인된 코드/전체 커밋과 배포 산출물을 고정한다. 지원 선언과 공통 검사기 지문을 기록한다. 현재는 결과 커밋이 없어 이 단계가 끝나지 않았다.
2. 사용 중인 공유 출력에 덮어쓰지 않고 `install/hejo-release <새 배포 위치>`로 새 산출물을 준비한다. 각 홈은 그 배포본 `install/hejo-install --home <설치 홈>`으로 검사·갱신한다. 실제 운영에서는 별도 승인 없이 실행하지 않는다.
3. team-kit은 정지/동시 작업 여부를 확인한 승인된 유지 시간에 `hermes-team-kit-deploy apply --source <검증 kit> --root <설치 홈>`으로 적용한다. 원래 manifest와 직원 데이터는 보존한다. 연결 저장소 배치 변경이 필요한 경우에만 검사된 plugin-store migrate/restore-copies를 쓴다.
4. 실패 복구는 고정된 현행 검사기로 호환 이전 산출물을 검사하는 `rollback --source <검증 복구 kit>`/installer 복구 경로만 사용한다. 구버전·전환 기록/잔존 인증·검사기 오류·불완전 installed 링크는 우회하지 않는다. 전용 자격 백업을 되살리거나 전환 항목을 지워 초기 설치로 위장하지 않는다. 복구 불확실 시 기능을 닫고 운영 판단을 받는다.
5. gateway 재시작·실계정 해제/계정 선택은 TASK-06 별도 승인 뒤 사용자 직접 수행한다. 새 계정 표시와 해당 직원 읽기 전용 확인·다른 직원 불변을 비밀/메일 본문 없이 확인한다. 푸시는 검토·검증·커밋 뒤 사용자 화면 승인으로 플러그인만 실행한다.

커밋 후보는 checkpoint-10의 각 worktree 파일과 canonical 작업 문서/수락 명세다. 다른 작업의 변경은 포함하지 않는다. UI 활성 조건은 사용자 GUI 준비 후 실제 성공을 확인했다. Terra IR-1은 해소됐다. 운영 GD-T19와 최종 전달 절차가 남으며 푸시 준비 완료로 먼저 보고하지 않는다.

## 전체 변경 파일

현재 원본은 checkpoint-10다. 아래 경로는 각 저장소 기준이며 변경 이유는 위 책임 설명과 이전 구현 항목을 따른다.

hejo (29개):

- `app/Sources/ConnectionModels.swift`
- `app/Sources/ConnectionsWindow.swift`
- `app/Tests/ConnectionsTests.swift`
- `app/Tests/TestMain.swift`
- `app/Tests/google_connection_fixture.py`
- `docs/changes/HEJO-DRAWER-INLINE-20261122/mockups/filter-options.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/clean.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/clean2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/composer.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-3.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-4.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/improve-1-6.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/improve-all.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/pill-replace.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/simple.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/title-pill-2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/title-pill.html`
- `gate/connection_manager.py`
- `gate/connection_runtime.py`
- `install/check_google_compat.py`
- `install/google-connection-support.json`
- `install/hejo-install`
- `install/hejo-release`
- `tests/acceptance/test_conn_manage.py`
- `tests/acceptance/test_google_deployment.py`
- `tests/acceptance/test_google_disconnect.py`
- `tests/acceptance/test_google_release.py`

team (65개):

- `hermes/bin/hermes-plugin-store`
- `hermes/bin/hermes-skill-assemble`
- `hermes/bin/hermes-team-kit-deploy`
- `hermes/plugin-store/team-delegation/plugin.yaml`
- `hermes/plugin-store/team-kit/google-connection-support.json`
- `hermes/plugin-store/team-kit/lib/hermes_execution/__init__.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/personal_roles.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/personal_scopes.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/account_connect.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_connect.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/config_assembly.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/connection_checks.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/connections.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection_auth.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection_sdk.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_deployment.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/pack_selection.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/approval.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/calendar_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/google_calendar_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/mail_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/request_approvals.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/google_calendar_accounts.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/catalog.json`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/__init__.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/full_mail_tools.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/gmail_extra.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/gmail_watch.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/organization_state.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/doctor.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/mail_waiting_worker.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/personal_mail_summary.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/personal_review.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/secret_guard.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/wait_jobs.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/conftest.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_cli.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_connection.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_consumers.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_native_workspace.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_oauth.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_queued.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_recovery.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_skill_boundary.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_workspace.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_workspace_assembly.py`
- `hermes/shared/secretary-skills/employee-google-workspace/SKILL.md`
