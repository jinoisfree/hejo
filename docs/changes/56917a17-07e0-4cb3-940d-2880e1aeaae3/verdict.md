## 검증 판정: TASK-33 1차(보류 보고, D33-01) (2026-11-17)

1. **판정:** TASK-33 미완료.
   - 실행 담당이 D33-01로 보류했다. 커밋은 없고, 제품 파일은 기준 `bdffda2`로 되돌렸다.
   - 초안 19개는 `.build/task33/draft/`에 보존했다.
   - 작업 트리에는 보고 파일 2개(`copy-review.md`, `impl-report.md`)만 바뀌어 있다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다.
3. **설계 적합성(4.2):** 아직 판정하지 않는다. 초안이 제품에 적용되지 않았다.
   - 보고된 초안 범위는 다음과 같다: 30초·6시간 확인, 동의 창, 수동 버튼, 하루 숨기기, 주소·버전·크기 허용, Sparkle SDK 경계, 펫 알림, 0.2.0·빌드 2, hejo-ship.
   - 이 범위는 보완 36·REQ-HF-33과 맞는다. 정식 판정은 재개 결과에서 한다.
4. **직접 확인한 것**
   - `legacy-run.log`: `test_old_gate_new_app`이 종료 1로 실패했다. 옛 문은 `a4a80d5`다.
   - `hello-boundary.json`: `features`가 있으면 `invalid_frame`, 없으면 `welcome`이다.
   - `git log a4a80d5..aeaa652 -- gate/server.py`: `features`를 받는 처리는 `61a5548`(TASK-21)에 들어갔다. 운영 적용본 `aeaa652`의 `gate/server.py:373`도 `hello.get("features")`를 받는다.
   - `61a5548:app/Sources/GateClient.swift:118`: 0.1.0 앱도 이미 `features:["rooms"]`를 보낸다.
5. **원인 분류:** 계획 결함(기준 지정 오류).
   - 계획 담당이 보완 36에 옛 문 예시를 `a4a80d5`로 적었다. 이 문은 운영 중이 아니고, TASK-21 뒤로는 지원 밖이다.
   - 구현 결함이 아니다. 실행 담당이 계약을 마음대로 고치지 않고 멈춘 것은 맞는 처리였다.
6. **결정·보완:** 35판 보완 43.
   - 옛 문은 운영 공용 릴리스 `aeaa652`이고, 지원하는 가장 낮은 문은 `61a5548` 이후다.
   - 되돌림 연결은 만들지 않는다.
   - spec REQ-HF-33.AC-03과 AT-HF-84 문구를 갱신했다.
7. **운영 주의:** 롤백 자료 `task23-20261116-200307`(`a4a80d5`)은 지금 앱과 맞지 않는다. 0.2.x 반영 전에 `aeaa652` 기준으로 새로 백업한다.
8. **작업 56917a17 전체:** 부분 완료.

---

## 검증 판정: TASK-35 세 손가락 탭 (2026-11-17)

1. **판정:** TASK-35 완료(`91956f5640bbffeb04a6a1c99aacdde2aec32cbb`, 16개 파일). 증거 수준은 2이며 필요 수준 2를 채웠다. 차단 결함은 없다. 비차단 지적 N35-01이 1건 있다(TASK-42로 넘김).
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. ddots 원본(`ThreeTap.swift`·`ThreeTapReader.swift`·`ThreeTapController.swift`, `App.swift:1369-1406, 1947, 1982`)과 줄 단위로 비교했다.
3. **설계 적합성(4.2):** REQ-HF-35.AC-01을 충족한다.
   - 판정 상수·실패 판정·Touch Bar 거르기(행 10 미만)·기기 확인·잠자기 뒤 다시 연결은 ddots와 같다. 바뀐 것은 시험 주입(리더 프로토콜·시계·기호 찾기)뿐이다.
   - `ThreeTap.swift`
     - Slack 보고용 `valid`·`slackText`만 뺐다.
     - 요청문의 ddots를 hejo로 바꿨다(22판 용어 규칙).
   - 컨트롤러
     - `UserDefaults` 대신 이 Mac의 `LocalStore`에 저장한다(Mac별 값이라는 같은 뜻).
     - `onFailure`(Slack·원격 보고)를 없앴다.
   - 앱 연결
     - 탭은 펫 클릭 경로로 간다. 펫이 숨었거나 쉬는 중이면 무시한다(ddots `panel.isVisible, !pet.resting`과 같음).
     - 설정 툴팁·흐림 조건은 ddots `refreshThreeTapSettings`와 같다.
     - 실패 창에는 "수정 요청문 복사"와 "닫기"만 있다.
   - 비공개 프레임워크는 dlopen으로만 연다. 직접 링크와 외부 보고가 없음은 `final-checks.json`에서 확인했다.
   - 기록해 둔 hejo 고유 차이
     - 설정 저장이 실패하면 "설정을 저장하지 못했어요…" 안내를 낸다. `LocalStore`는 실패할 수 있어서 생긴 안내이고, 뜻은 바꾸지 않는다.
     - 시작할 때 저장이 실패하면 앱 시작 실패로 이어진다. 다른 `LocalStore` 쓰기와 같은 정책이라 받아들인다.
4. **직접 확인한 것**
   - `.build/foundation9-hejo.log`: 191 passed, `AT-HF-86 APP PASS`, `APP_TEST_OK`. 앱 반복 10회 기록이 모두 종료 0이고 입력은 바뀌지 않았다.
   - AT86 단언 범위
     - 0.2초 탭, 0.4초 오래 누름, 네 손가락, 두 손가락, 움직임, 쿨다운을 본다.
     - 29번째 이상 프레임은 통과하고 30번째에서 실패한다. 정상 프레임이 오면 연속 수가 초기화된다.
     - 시계 되돌림, Touch Bar·빈 센서 거르기, 기기 교체 시 다시 연결, dlopen 실패, 기호 없음 1회 보고를 본다.
     - 트랙패드 없음 안내, 펫 클릭 경로로 열고 닫기, 쉬는 중·숨김일 때 무시, 잠자기 뒤 다시 연결을 본다.
     - 설정 끔 저장·복원, 찾아보기 안내 1회, 실패 시 리더 정지와 설정 흐림을 본다.
   - 돌연변이 기록(`.build/task35/mutations.json`): 탭 허용 시간 확대, 실패 한도 변경이 각각 종료 1로 검출됐다.
5. **지적**
   - N35-01(비차단, 범위 경계): ddots 설정 "고급" 탭의 "수정 요청문 복사" 단추가 hejo에 없다(D:App.swift:1401·1982). 고급 탭은 TASK-42(G02·G07)가 만들므로 그때 같이 넣는다(handoff 보완 42). 실패 창의 복사 단추가 있어서 AC-01은 충족한다.
6. **남은 위험:** 실제 트랙패드 탭, 실제 비공개 ABI, 기기 교체·잠자기 깨기는 TASK-23 실물 확인 때 본다.
7. **작업 56917a17 전체:** 부분 완료. 남은 것은 TASK-33(0.2.0), TASK-48, TASK-49, TASK-36~47, TASK-23 실물, 비설계자 검토, 푸시 승인이다.

---

## 검증 판정: N34-01 스레드 범위 중지 시험 (2026-11-17)

1. **판정:** N34-01 완료. 시험만 보강했다(`e94ee2f6d03fd2e1914d2604a6d9b7cac5b8f5f7`, `gate/tests/test_progress.py` +41). 제품 코드는 바뀌지 않았다. 차단 결함은 없다.
2. **검증 조건:** 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5다. 깨끗한 임시 worktree에 시험 의존만 복사해 검토했다.
3. **설계 적합성(4.2):** 보완 39의 기대를 그대로 시험한다.
   - 같은 대화에서 A·B 두 스레드가 `final:false`로 흐르는 중에 A의 `thread_id`로 stop을 두 번 보낸다.
   - 새 edit는 A `final:true` 한 번뿐이다. A의 본문은 그대로 남는다.
   - B는 `final:false`이고 작성 중 등록도 남는다.
   - 기본 문과 보조 프로필 전달자 경로를 매개변수로 둘 다 시험한다.
4. **직접 확인한 것**
   - `foundation9_runner.py`(test_progress.py, e94ee2f): 종료 0, 7 passed.
   - 검토자 돌연변이(직접 실행, 원복 확인)
     - `stop_typing`의 `selected` 필터 제거 → primary·forwarder 2 failed, 검출.
     - 전달자 `_forward("stop_typing")` metadata를 `{}`로 되돌림 → forwarder 1 failed, 검출.
   - 실행 담당 돌연변이 기록 `.build/n34-01/mutations.json`과 일치한다.
5. **지적:** 없음.
6. **작업 56917a17 전체:** 부분 완료. 남은 것은 TASK-35, TASK-33(0.2.0), TASK-48, TASK-49, TASK-36~47, TASK-23 실물, 비설계자 검토, 푸시 승인이다.

---

## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-34 실물 지적 수정 (+ 작업 전체 현황)

1. **판정**
   - TASK-34: 완료. 범위는 REQ-HF-34.AC-01~07·09이고, AC-08은 33판 보완 38에 따라 TASK-38로 옮겼다. 증거 수준은 2이며 필요 수준 2를 채웠다. 차단 결함은 없다. 비차단 지적 N34-01이 1건 있다.
   - 작업 56917a17 전체: 부분 완료. 남은 것은 아래와 같다.
     - N34-01
     - TASK-35, TASK-33(0.2.0), TASK-36~47(33판)
     - TASK-23 실물: 0.2.0 운영 반영, 두 Mac에서 한글 입력기와 실제 차례 정리 확인
     - 비설계자 검토, 푸시 승인
2. **검증 조건**
   - 교차 모델이다. 구현은 codex gpt-6.1-sol, 검토는 Claude Opus 5.5(계획 담당)다.
   - 검토한 코드는 `44ab635fdf7ac77fd095533888fb80035a94d83b`다. 깨끗한 임시 worktree에 시험 의존만 복사해 검토했다.
3. **설계 적합성(4.2):** REQ-HF-34.AC-01~07·09와 보완 37 추가 1~3을 충족한다.
   - 문 `stop_typing`
     - 끝내는 범위는 그 직원·그 대화·`metadata.thread_id` 스레드다. Hermes `_stop_typing_with_metadata`(base.py 3027~3035)가 스레드별로 부르는 계약에 맞다.
     - 범위 안에서 `final`이 아닌 글을 마지막 본문으로 `edit final:true` 한 번 닫는다. 기다리는 편집은 정리한다.
     - 전달자는 `thread_id`를 보존한다. `_forward`가 `hermes_profile`를 덧붙인다.
   - `delete_message`
     - 자기 직원·같은 대화의 직원 글만 보통 `delete`로 지운다(25판 종류, seq 연속).
     - 사장 글·남의 글·없는 글은 기록하지 않는다.
   - 앱
     - 작성기 줄: 스위치는 왼쪽, 얼굴은 오른쪽 가로 스크롤이고 세로 가운데에 맞췄다.
     - 작업 줄: 간격 9, 중지 단추는 초 표시 오른쪽 6pt.
     - `finalized` 글은 생각 중이어도 작성 중으로 세지 않는다.
     - DM 기본 이름은 "DM"이고 얼굴·사진은 그리지 않는다.
     - + 버튼은 표의 마지막 40pt 행이고, 검색 중에는 없다.
     - 방 이름은 자유 글 80자다. 문 `room_save`도 앞뒤 공백 정리만 해서 한글을 받는다. Slack 안내는 없앴다. 제목·설명 창은 `RoomDialogs.header`로 옮겼다.
   - 설치 도우미
     - `display.platforms.hejo.cleanup_progress: true`를 값이 없을 때만 넣는다.
     - 홈 채널과 같은 `owner_may_change` 영수증·키 단위 되돌림·`--check`(두 키 따로)를 쓴다. `--uninstall-home-channel`은 홈 키만 다룬다.
   - 범위: 운영 홈·공용 릴리스·public·원격은 바뀌지 않았다(`final-verification.json`과 일치).
4. **직접 확인한 것**
   - `foundation9_runner.py hejo`(44ab635, 깨끗한 worktree): 종료 0, 189 passed. AT-HF-85 APP PASS와 기존 가짜 Hermes·앱·통신 시험이 모두 통과했다.
   - 검토자 돌연변이
     - 문 `_finish_streams` 호출 제거 → `test_progress.py` 3 failed, 검출.
     - `delete_message` 주소 검사 무력화 → 2 failed, 검출.
     - 앱 중지 단추를 줄 끝으로 되돌림 → `AT85 stop follows elapsed by six` 실패, 검출.
     - `stop_typing`의 `thread_id` 필터 제거 → 5 passed, **잡히지 않음**(N34-01).
     - 전달자 metadata 보존 되돌림 → 5 passed, **잡히지 않음**(N34-01).
     - 모두 원복했다.
   - 캡처 `evidence/HEJO-FOUNDATION/task34-hejo.png`와 `task34-ddots.png`
     - 작성기 줄·작업 줄·DM·+ 위치가 ddots 조각과 같다.
     - 상단의 큰 재시도 숫자는 합성 시계 때문이라 비교에서 뺐다. 실행 담당이 보고서에 적은 대로다.
     - 접힌 구획 얼굴은 33판 V03에서 TASK-38이 되돌린다.
5. **지적**
   - N34-01(비차단, 시험 공백): 스레드 범위 `stop_typing`을 시험하지 않는다.
     - 경우: 같은 대화에서 두 스레드가 동시에 흘러나오는 중이고, 한 스레드의 `thread_id`로 stop이 온다.
     - 기대: 다른 스레드의 `final:false` 글을 닫지 않고, 그 스레드의 작성 중 표시도 남긴다.
     - 같은 경우를 보조 프로필 전달자 경로에서도 시험한다.
     - 필터를 빼도 지금 시험이 통과한다.
6. **남은 위험·운영 주의**
   - 실제 한국어 입력기 조합과 실제 Hermes 성공·실패 차례의 진행 글 지우기는 0.2.0 운영 반영 때 실물로 확인한다. 이때 계획 담당과 사장이 설치 도우미 재실행과 게이트웨이 재시작을 한다.
   - `.build/task38-start.patch`는 32판 움직임 초안이다. 33판 REQ-HF-36.AC-03을 만족한다는 뜻이 아니다.
7. **원인 분류:** 결함 아님. N34-01은 시험 보강이다.
8. **다음**
   - N34-01 시험 보강(실행 담당, 시험만)
   - TASK-35 → TASK-33(0.2.0) → TASK-36~47(보완 38 순서)
   - 0.2.0 운영 반영과 실물 확인(사장)
   - 비설계자 검토, 푸시 승인(사장)
