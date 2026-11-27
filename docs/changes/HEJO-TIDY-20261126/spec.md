# HEJO-TIDY 명세

- 판: 3판(계획 검증 1회차 R1-01~04, 2회차 R2-01 반영, [plan-review.md](plan-review.md)) · 상태: 초안(사용자 범위 확인 완료, 계획 검증 대기) · 작성 2026-11-26
- 기준: 공개 `github/main` `425d5650a1ab520ac9746c7f26a4a26299c80a48`, 개발 main `4ab06ca9d2946965ddea2243d37ba6fc9867a83d`
- 결정 요약: [brainstorm.md](brainstorm.md)

**칸·원본·쓰기 주체·수명:** [design.md 1절](design.md)(ARCHITECTURE 8절 점검표). 새 칸·두 번째 원본 없음.

## 1. 문제

1. 공개판에 올라가지 못한 검증 완료 작업이 두 개 있다. 둘 다 원격이 앞서가서 fast-forward가 아니다.
   - [확인] HEJO-DISCORD-SECTIONS 후보 `a6d5e9a`(verdict 6차 "푸시 후보 확정").
   - [확인] HEJO-TELEGRAM-REMOVE 후보 `1ca2cbb`. verdict 11회에서 남긴 조건은 "정리 커밋"이고, 그 정리 커밋이 `1ca2cbb`다. `merge-base --is-ancestor github/main <후보>`는 둘 다 1이다.
   - [확인] 두 후보끼리도 충돌한다: `app/Tests/TestMain.swift`, `gate/server.py`, `tests/acceptance/test_slack_move_gate.py`(`git merge-tree`).
   - [확인] HEJO-SMOOTH2 공개 브랜치 `f80736c`는 이미 반영돼 있다. 제품 파일(`PetTransitionClock.swift`·`HejoSmoothProbe.swift`·`PetController.swift`)과 작업 문서가 `github/main`과 같고, 다른 파일은 뒤 작업이 바꾼 것이다. 따라서 푸시 대상이 아니다.
   - [확인] HEJO-ALERT-SEEN `425d565`는 이미 원격 tip이다.
2. 사장의 맥북에서 업데이트 뒤에도 이전판 hejo가 남아 보인다.
   - [확인] 원인은 검증 담당의 수동 설치가 `/Applications`에 남긴 `hejo-…-previous.app` 백업이다. 번들 ID는 현재판과 같다.
   - [확인] Sparkle은 실행 중인 번들 자리만 교체하므로 이런 사본을 모른다. 이 서버 Mac에도 0.2.7(9) 사본 두 개가 남아 있다.
3. 공개판 코드에 쓰이지 않거나 중복된 코드가 쌓였다. 텔레그램 제거, 여러 번의 이식 때문이다. [가정] 구체 목록은 TASK-05 감사로 확정한다.
4. HEJO-ALERT-SEEN 후속 과제:
   - V-3: 말풍선·섬 클릭으로 연 알림의 확인 처리를 지키는 시험이 저장소 밖 보조 시험뿐이다.
   - V-4: 멘션 줄 끝에 공백이 있으면 카드 제목이 `@acct  · …`처럼 공백 두 칸이 된다.

## 2. 범위

- **안:**
  - 두 후보를 공개 tip에 통합해 푸시한다.
  - 개발 저장소의 미커밋 문서는 로컬에서만 커밋한다. 계획 담당이 한다.
  - 앱의 이전판 사본 정리(REQ-TIDY-02).
  - 검증 설치 백업 절차(REQ-TIDY-03).
  - V-3·V-4(REQ-TIDY-04·05).
  - 앱 릴리스 준비(REQ-TIDY-06).
  - 동작 보존 코드 정리(REQ-TIDY-07).
- **밖:**
  - 서버 문 설치·게이트웨이 재시작. 서버 운영 줄은 별도 줄이다(HEJO-DISCORD D-03).
  - 릴리스 게시. 사용자가 `hejo-publish`를 직접 실행한다.
  - 다른 번들 ID나 두 응용 프로그램 폴더 밖의 파일.
  - 서버 공용 폴더의 설치본(`<공용 폴더>/hejo/hejo.app`).
  - 영구 삭제.
  - 코드 정리 중의 의미 변경.
  - Hermes 본체, ddots.

## 3. 요구와 수락 기준

### REQ-TIDY-01 대기 공개 작업 통합

`github/main` tip 위에 HEJO-DISCORD-SECTIONS(`a6d5e9a`)와 HEJO-TELEGRAM-REMOVE(`1ca2cbb`)를 차례로 합친다. 두 작업의 승인된 수락 시험이 그대로 통과해야 한다.

- AC-01 (정상) 통합 커밋은 원격 tip의 fast-forward 자손이고, 두 후보를 모두 조상으로 가진다.
- AC-01a (정상·규격 비교, R1-02) 규격 `schemas/hejo-wire-v1.json`을 세 번 비교한다. 모두 JSON 의미 비교다.
  - 병합 1(DISCORD-SECTIONS): 첫 부모 T0(시작 원격 tip) 대비 결과 M1의 차이는 `$defs.discord_layout` 추가와 `clientFrame.oneOf`·루트 `oneOf` 끝의 참조 추가뿐이다. AT-DK-22 6판의 "통합마다 병합 부모 대비 추가만" 확인을 이것으로 한다.
  - 병합 2(TELEGRAM-REMOVE): 첫 부모 M1 대비 결과 M2는 M1에서 텔레그램 정의 6종과 그 `$ref`만 뺀 것과 같다. AT-HTR-04 5판의 "합치는 시점의 원격 tip"은 이 통합에서 병합 2의 첫 부모 M1로 읽는다. M1이 공개판에 들어갈 새 tip이기 때문이다.
  - 최종 합성: T0 대비 M2 = T0 + `discord_layout`(정의·참조 2) − 텔레그램 정의 6종과 그 참조. 다른 차이는 0이다.
  - AT-SM-02 해시 = M2 규격 sha256.
- AC-02 (정상) 통합 트리에서 다음이 모두 종료 0이다:
  - HEJO-DISCORD-SECTIONS 수락 시험 6판
  - HEJO-TELEGRAM-REMOVE 수락 시험 5판(AT-HTR-04 통합 비교 포함)
  - HEJO-OWNER-PROFILE AT-OP-10·14 개정판
  - HEJO-ALERT-SEEN 수락 시험
  - 개인값 검사
  - 앱 빌드
- AC-03 (경계) 전체 pytest와 앱 시험의 실패 목록이 원격 tip 기준선보다 늘지 않는다. 기존 실패 `test_at_hf_08[True]`와 TD-1의 흔들리는 AT-CS-02는 기준선 비교로 판단한다.
- AC-04 (실패) 충돌 해결이 어느 한쪽의 승인된 동작을 잃게 하면 멈추고 보고한다. 예: Discord 섹션 동기화, 텔레그램 흔적 부재, 사장 프로필.

### REQ-TIDY-02 이전판 hejo 사본 정리

hejo 앱은 실행될 때마다, 자기가 `/Applications` 또는 `~/Applications`에 설치돼 있으면 두 폴더 최상위에서 아래 조건을 **모두** 만족하는 `.app` 번들을 휴지통으로 옮긴다.

1. `CFBundleIdentifier`가 자기와 같다.
2. 자기 자신(심볼릭 링크를 푼 경로 기준)이 아니다.
3. 정수로 읽은 `CFBundleVersion`이 자기보다 작다.
4. 그 번들로 실행 중인 프로세스가 없다.

두 폴더는 각각 독립적으로 처리한다. 화면을 막지 않고, 실패해도 앱 동작에 영향이 없다. 옮긴 사본과 실패한 사본마다 통합 로그(`Logger`, subsystem = 앱 번들 ID, category `stale-copies`)에 한 줄씩 남긴다. 내용은 원래 경로, `CFBundleVersion`, 결과(휴지통 경로 또는 오류 종류)다. 개인값은 경로 외에 없다(R1-03: 휴지통은 에이전트 셸에서 읽을 수 없어 이동 증거가 필요하다).

- AC-01 (정상) Given 임시 폴더에 같은 번들 ID의 빌드 9 사본 `hejo-x-previous.app`과 빌드 10인 자기. When 정리를 실행. Then 사본은 휴지통 처리기로 넘어가고, 자기는 남는다.
- AC-01b (정상·두 폴더, R1-03) Given 시스템 폴더 역할 A와 사용자 폴더 역할 B 각각에 빌드 9 사본 하나씩. 자기는 A에 있을 때와 B에 있을 때 두 경우. When 정리. Then 두 경우 모두 A·B의 빌드 9 사본이 각각 한 번씩 처리기로 넘어간다.
- AC-02 (경계·같거나 높은 판) 같은 번들 ID의 빌드 10·11 사본은 남는다.
- AC-03 (경계·다른 앱) 다른 번들 ID(빌드 1)는 남는다. Info.plist가 없거나 읽을 수 없는 번들, `CFBundleVersion`이 정수가 아닌 번들도 남는다.
- AC-04 (경계·설치 위치) 자기가 두 응용 프로그램 폴더 밖에서 실행되면 아무것도 옮기지 않는다. 예: 빌드 폴더, 공용 서버 폴더.
- AC-05 (경계·하위 폴더) 하위 폴더 안의 번들, 두 폴더 밖의 번들은 건드리지 않는다.
- AC-06 (경계·실행 중) 실행 중인 프로세스의 번들 경로와 같은 사본은 남는다.
- AC-07 (실패) 휴지통 이동이 실패하면 그 사본은 그대로 남는다. 앱은 계속 실행되고 다음 실행 때 다시 시도한다. 사본 하나의 실패가 다른 사본의 처리를 막지 않는다.
- AC-08 (실물, R1-03) 새 릴리스로 갱신한 실제 Mac에서 다음을 모두 관측한다. 대상은 이 서버 Mac(관측: 0.2.7 사본 2개)과 사장의 맥북이다.
  - 설치 전: 두 폴더 최상위 번들마다 경로·번들 ID·`CFBundleVersion`을 기록하고, 갱신 직전 실행 중인 hejo 번들 경로를 기록한다.
  - 분류(R2-01). N = 새 빌드 번호.
    - **갱신 경로** = 갱신이 교체한 번들. Sparkle이면 실행 중이던 번들, `get-hejo`면 `/Applications/hejo.app`.
    - **적격** = 갱신 경로가 아니고, 같은 ID이고, 빌드 < N이고, 새 판 실행 시점에 실행 중이 아닌 번들(조건 2·3·4).
    - **보존** = 그 밖의 모든 번들. 실행 중이던 낮은 빌드 사본도 여기 든다(AC-06).
  - 설치·실행 뒤 같은 목록으로 확인한다:
    - 갱신 경로: 같은 자리에 빌드 N이 있고, 실행 중 hejo의 실행 파일이 그 번들 안이다.
    - 적격: 원래 경로에 없다. 통합 로그에 그 경로의 휴지통 이동 줄이 있고, 사용자가 Finder 휴지통에서 같은 이름을 확인한다.
    - 보존: 원래 경로에 그대로 있고, 로그에 이동 줄이 없다.
- AC-10 (정상·기록) 옮긴 사본과 실패한 사본마다 로그 한 줄이 있다. 대상이 없으면 로그는 0줄이다.
- AC-09 (유지) `get-hejo`는 설치 뒤 `/Applications/hejo.app`을 연다(현재 동작). 그래서 같은 정리가 돈다. `get-hejo`에 별도의 정리 코드를 두지 않는다.

### REQ-TIDY-03 검증 설치 백업 절차

hejo 앱을 실제로 설치·교체하는 검증 절차는 기존 앱 백업을 `/Applications`·`~/Applications` 밖에 둔다(권장 `~/Library/Application Support/hejo-backups/`). 작업을 판정한 뒤에는 그 백업을 지운다.

- AC-01 공개 `AGENTS.md`와 개발 `AGENTS.md`에 이 규칙이 한 줄 있다.

### REQ-TIDY-04 말풍선·섬 클릭 알림 확인 시험(V-3)

- AC-01 저장소 수락 시험 1건 이상이 다음을 관측한다. 시험 위치는 `app/Tests` 또는 `tests/acceptance`이고, 출시 경로인 기록 나눠 받기 모드에서 관측한다.
  - 대상: 펫 말풍선 클릭과 섬(아일랜드) 클릭으로 알림 스레드를 연다.
  - 관측: 그 key의 `notice` 읽음 요청 1건, `thread` 0건, 그 뒤 카드 없음.
  - 기대값 출처: HEJO-ALERT-SEEN spec REQ-AS-01 직접 선택 목록과 AT-AS-01.
  - 동작 보존 시험이라 현재 코드에서 통과해야 한다. 실패하면 제품을 고치지 말고 멈추고 보고한다.

### REQ-TIDY-05 멘션 줄 끝 공백(V-4)

HEJO-ALERT-SEEN REQ-AS-02의 "이어 붙인" 결과는 멘션 줄의 앞뒤 공백을 뺀 값 + `" · "` + 다음 줄이다.

- AC-01 (정상) `"@acct \n요약: 가짜"` → `"@acct · 요약: 가짜"`(공백 한 칸).
- AC-02 (정상) `"  @a @b\t\n본문"` → `"@a @b · 본문"`.
- AC-03 (유지) HEJO-ALERT-SEEN AT-AS-09·10의 기존 기대값은 바뀌지 않는다.

### REQ-TIDY-06 앱 릴리스 준비

REQ-TIDY-01·02·04·05가 든 공개 커밋에서 다음 버전의 앱 릴리스를 준비한다. 절차는 HEJO-RELEASE-20261125 인계(v1·v2)와 같다. 다음 버전은 그때 `github/main`의 `CFBundleShortVersionString`·`CFBundleVersion` 다음 번호다. 게시(`hejo-ship publish`, appcast 생성·서명·업로드)는 사용자가 한다(R1-04: appcast는 `publish`가 만든다, `install/hejo-ship` 223~224줄).

- AC-01 (준비) 버전 커밋 R이 있다. Info.plist 두 값과 `tests/acceptance/test_ship.py`의 버전 단언만 바뀐다. `refs/heads/public`이 R을 가리킨다.
- AC-02 (준비 산출물) 깨끗한 트리에서 빌드한 앱이 다음을 모두 만족한다:
  - `codesign --verify --deep --strict` 종료 0.
  - `BuildInfo.json`의 tree = R 트리, dirty false.
  - `hejo-ship prepare --output <새 폴더>` 종료 0이고, 그 폴더에 `hejo-<버전>-arm64.zip`과 `prepared.json`이 있다.
  - `prepared.json`의 commit = R, version·build = 새 값, sha256 = zip의 sha256.
  - `sign_update --verify <zip> <signature>` 종료 0(`prepare`가 안에서 한다).
- AC-03 (게시 뒤, 사용자 게시 후 관측) GitHub 최신 릴리스 태그 `v<버전>`에 zip과 `appcast.xml`이 있다. 이것이 M-01의 선행 조건이다.

### REQ-TIDY-07 공개판 코드 정리(동작 보존)

대상은 `github/main`의 추적 파일 중 실행되거나 시험되는 코드 전부다: `app/`·`gate/`·`hub/`·`install/`·`scripts/`·`schemas/`·`tests/`·`githooks/`·`config/`(R1-01).

- 제외 1: `docs/`·`evidence/`·`README.md`·`AGENTS.md`·`CLAUDE.md`·`LICENSE`·`.gitignore`. 기록과 안내라 실행 코드가 아니다.
- 제외 2: `tests/acceptance/`의 수락 시험 명세(`*.md`)와 그 기대값. 수락 시험 소유는 기획설계다. 감사에서 후보로 올릴 수는 있지만, 지우려면 그 작업의 기획 승인이 필요하다. 쓰이지 않거나 중복된 코드를 감사해 목록으로 만들고, 계획 담당이 승인한 항목만 지운다. 중복은 같은 의미의 구현만 하나로 합친다.

- AC-01 감사 목록(TASK-05)에는 항목마다 다음이 있다:
  - 경로:줄
  - 분류: 미사용, 중복, 죽은 분기, 제거된 기능의 잔재
  - 사용처가 없다는 근거: 검색 명령과 결과. 문자열 디스패치, `@objc`·셀렉터, Info.plist·Hermes 플러그인 계약의 동적 참조도 확인한다.
  - 지웠을 때의 영향
- AC-02 정리 뒤 다음이 모두 기준선과 같다:
  - 전체 pytest와 앱 시험의 통과·실패 노드 목록. 지운 코드 전용 시험이 함께 빠지는 경우만 목록에 적힌 대로 허용한다.
  - 개인값 검사
  - 앱 빌드
  - 공개 계약 파일(`schemas/`)의 의미
- AC-03 (실패) 사용처를 확정하지 못한 항목은 지우지 않는다. "조사 과제"로 남긴다.
