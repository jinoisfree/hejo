# 독립 지적 한정 보완

현재 대화의 직접 구현·자체 시험. 외부 격리 worktree의 starter-templates/install_support.py,starter-templates/hermes-connections.py,tests/test_starter_runtime.py 세 파일만 수정했다. 나머지 외부17파일은 기존 수락 해시와 일치한다. [새 해시/검사](logs/independent-review-fix/final-check.json).

## V-IR-01

launcher는 선택 runtime을 단1회 실행하고 원시 stderr를 외부에 전달하지 않는다. stdout/명시 stdin/인자/종료 코드는 유지하며 비영 종료에는 고정된 안내를 출력한다. 정상 facility 실패 JSON도 그대로 통과한다. 실행 불가 경로는 기존 고정 안내를 유지한다. import 실패는 template의 bootstrap 경계에서 connection_start_failed JSON으로 반환한다. 정상 연결 로직은 그대로다.

gate의 terminate/kill 대상이 바뀌어 프로세스가 남지 않도록 launcher가 자기 runtime 자식만 관리한다. TERM/INT/HUP에서 자식을 강제 종료하고 wait로 회수한 뒤143/130/129로 종료한다. fallback/재시도/다운로드는 없다. SIGKILL 자체를 trap할 수 있다고 주장하지 않는다. 실제 gate는 TERM 후0.2초 대기 뒤KILL을 사용하는 기존 계약이며 정상 gate 취소 및30초 시간 초과 시험에서 자식 소멸을 직접 확인했다.

관련3시험 파일 최종141 passed,종료0: [실행](logs/independent-review-fix/test-run.json),[stdout](logs/independent-review-fix/tests.stdout). 새7사례는 고장 interpreter/loader,import-time 실패,stdin/인자/실패JSON,TERM 무시 자식 회수다. 기존 두 홈/receipt/업데이트/충돌/rollback 시험도 포함한다.

초기 시스템Python의pytest 부재,시험 환경 lib 누락,공개 scanner의새오류코드 매치 실패를 보존했다. 실제 오류코드는 소문자 connection_start_failed로 정했고 scanner/allowlist를 완화하지 않았다. 처음137/138통과 시도의원문은 private0600으로 보존하며 공개에는 [실패요약](logs/independent-review-fix/attempt01-summary.json)만 둔다. 생성기 fixture의cwd/import 위치 오류도 교정했고 제품 오류로 숨기지 않는다.

기존 임시 입력 복사본에 변경 template2개만 반영하여 기존 build/findings/write_output을 재실행했다. 옛 입력/출력은 보존했고 새 결과401파일 재현·개인값 scanner0이다. 실제 운영 원본/공개 checkout은 바꾸지 않았다. [생성](logs/independent-review-fix/build-result.json).

새 결과의두 임시 홈에 실제 modern_main→receipt/check→CLI→connections/gate를 실행했다. 홈별 요청 default가receipt와 같고 default프로필1개·미연결Notion후보 존재를 추가 단언했다. [통합](logs/independent-review-fix/fixture-result.json),[실제gate취소/timeout](logs/independent-review-fix/gate-abort-result.json). 실제 사용자 자격/계정 API를 호출하지 않았으며 독립 컴퓨터 증거가 아니다. raw trace는 차단됐으므로 missingModules 빈목록은 runtime 의존성 예외 부재의 증거로 해석하지 않는다.

## V-IR-02

기존5시험 원문을 바이트/해시 그대로 로컬 보존했다. git-document-scope.md의 공개 포함 제안을 명시 제외로 바꿨다. 개인 식별값이 있는 증거를 stage/공개 생성에 포함하지 않는다. 실제로 삭제/이동/치환하지 않았다. [제외 및 한정 식별값검사](logs/independent-review-fix/privacy-disposition.json).

독립 지적 위치에서 추출한 정확한 문자열을 문서32후보와 생성401파일에 대조했다. 검출은 기존 코드의날짜2종이며 사람/profile/DB식별값 검출0이다. 원문값은 보고에 복사하지 않았다. 이는 지적된 값의한정 검사이고 모든 사용자 고유값 검사라고 주장하지 않는다. 전체 공개 심사의독립 판정은 별도다.

## 상태

보완 자체 시험은 통과했다. 독립 검토자는 한정 delta와 새 증거를 재검토해야 한다. 현재 정상 연결/서비스/자격,운영 수집,공개checkout,merge/커밋/푸시는 변경하지 않았다. 공개 후보 해시가 바뀌었으므로 옛生成/시험 해시를 최종 후보로 사용하지 않는다.

독립 재검토의 SIGKILL 자식 종료 시 셸 wait 진단 노출을 시험으로 재현했다(1실패/1통과). wait의 stderr도 차단한 최종본은 TERM/KILL 종료코드와 고정 오류 출력을 보존하며141시험이 통과했다. 생성401파일 및 두 홈 실제 gate 취소/timeout 통합도 최종본으로 다시 통과했다. [신호 회귀](logs/independent-review-fix/signal-regression.json).
