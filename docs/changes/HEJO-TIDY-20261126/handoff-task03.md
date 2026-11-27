[설계 인계: HEJO-TIDY TASK-03 / 이전판 사본 정리 + 백업 절차 + V-3 + V-4]

**칸·원본·쓰기 주체·수명:** [design.md 1절](design.md)(ARCHITECTURE 8절 점검표). 새 칸·두 번째 원본 없음.

0. **기준**
   - base_commit: 공개 `github/main` `a90dc1d4c767add55a3e7c41c5638430be854dec`. 푸시 1이 반영됐다(2026-11-26 `ls-remote` 확인).
   - 문서: spec 3판, design 2판, 수락 시험 HEJO-TIDY 3판(계획 검증 3회차 APPROVED).
   - 운영 모드: 연합개발(교차 모델).
1. **공식 문서**
   - [spec](spec.md) REQ-TIDY-02~05, [design](design.md) D-02~D-06.
   - 수락 시험 `tests/acceptance/HEJO-TIDY.md` AT-TIDY-04~13·04b·08b.
   - HEJO-ALERT-SEEN spec REQ-AS-01·02, `tests/acceptance/HEJO-ALERT-SEEN.md`.
2. **요구**
   - REQ-TIDY-02 AC-01~07·01b·09·10. AC-08은 TASK-04의 M-01에서 확인한다.
   - REQ-TIDY-03 AC-01.
   - REQ-TIDY-04 AC-01.
   - REQ-TIDY-05 AC-01~03.
3. **유지할 계약**
   - 설정 파일·저장소 칸·통신 규격 무변경. 새 설정 키 0, 새 저장 파일 0.
   - `install/get-hejo` 무변경(D-03).
   - HEJO-ALERT-SEEN AT-AS-01~13 기대값.
   - REQ-AS-02의 판정 규칙과 300 글자 묶음.
4. **책임과 흐름**
   - 이전판 정리(관제 화면 칸):
     - 앱 시작 직후 한 번, 메인 스레드를 막지 않고 실행한다.
     - 설치 위치는 `LoginLaunch.isInstalled`와 같은 기준으로 판정한다. 판정을 복제하지 말고 재사용하거나 한곳으로 묶는다.
     - 대상 폴더 `/Applications`와 `~/Applications`를 각각 최상위만 독립적으로 처리한다.
     - 조건 1~4(같은 ID, 자기 아님, 정수 `CFBundleVersion`이 더 작음, 실행 중 아님)를 모두 만족하는 번들만 `FileManager.trashItem`으로 휴지통에 옮긴다.
     - 사본마다 `Logger(subsystem: <번들 ID>, category: "stale-copies")`로 한 줄 남긴다. 내용은 원래 경로, 빌드, 결과 경로 또는 오류다.
     - 시험을 위해 폴더 목록, 자기 정보, 실행 중 번들 경로, 휴지통 처리기, 기록기를 주입할 수 있게 한다.
   - V-4(문): `gate/history_queries.py` 요약 쪽 172~177행 근처에서 이어 붙일 때, 멘션 줄의 앞뒤 공백을 뺀 값 + `' · '` + 다음 줄로 만든다.
   - V-3(시험):
     - `gate/tests/history_transport_app.py` `test_alert_seen` 매개변수에 `bubble`(펫 말풍선 클릭)과 `island`(섬 클릭) 시나리오를 추가한다.
     - `app/Tests/HistoryAlertSeenHarness.swift`에 같은 이름의 동작을 추가한다. 실제 앱 경로를 그대로 탄다: 말풍선 클릭 → `BubbleReveal` → `ConversationView.reveal(direct:true)`, 섬 클릭 → `IslandModel` 경로.
     - 출발점: `../.worktrees/hejo-alert-seen-public-20261125/.build/alert-seen/bubble-probe/`(`test_bubble.py`, `HistoryAlertSeenHarness.swift`). 코드를 옮기기 전에 그 보조 시험 전체를 읽는다.
   - 절차(REQ-TIDY-03): 공개 `AGENTS.md`에 개발 `AGENTS.md`의 `hejo-backups` 줄을 그대로 추가한다.
5. **기존 경로 판정**
   - `LoginLaunch.isInstalled`: 유지·재사용.
   - `get-hejo`: 유지(정리 로직 추가 금지, AT-TIDY-09).
   - bubble-probe 보조 시험: 저장소 시험으로 교체. 보조 시험 폴더는 `.build`라 추적 대상이 아니다.
6. **위험도와 증거**
   - 위험도: 일반. 앱이 다른 번들을 휴지통으로 옮긴다. 복구 가능하고 대상 조건이 좁다.
   - 필요한 증거 수준: 2. 실물(4)은 TASK-04의 M-01이다.
   - 이 작업에서 실제 `/Applications`·`~/Applications`를 건드리는 실행은 금지한다. 시험은 임시 폴더와 주입만 쓴다. 빌드한 앱을 응용 프로그램 폴더에서 실행하지 않는다.
7. **변경 성격**
   - 이전판 정리·로그: 의미 변경(새 동작).
   - V-4: 의미 변경(공백 한 칸).
   - V-3: 동작 보존 시험. 현재 코드에서 통과해야 하며, 실패하면 제품을 고치지 말고 멈추고 보고한다.
   - 비교: 기준(`a90dc1d`)과 후보의 전체 pytest JUnit, `bash app/scripts/test.sh`.
8. **수락 시험**
   - AT-TIDY-04·04b·05~08·08b(앱 단위 시험, `app/Tests`에 새 시험 파일과 `TestMain.swift` 등록).
   - AT-TIDY-09(정적), AT-TIDY-10(`AGENTS.md`), AT-TIDY-11(V-3), AT-TIDY-12·13(`test_history_queries.py` AT-AS-09 표에 행 추가).
   - 기준본 실행:
     - 재현 시험(04~08b·12)은 제품을 고치기 전에 써서 실패를 확인한다.
     - 보존 시험(09·11·13)은 `a90dc1d`에서 통과를 확인한다.
     - 로그는 `.build/tidy/task03/before/`에 둔다.
9. **작업 범위**
   - worktree: 같은 공개 worktree `../.worktrees/hejo-tidy-public-20261126`(HEAD = 원격 `a90dc1d`)에서 이어 간다.
   - 증거: `.build/tidy/task03/`.
   - 커밋: 논리 단위로 2~4개(정리 기능, V-4, V-3, `AGENTS.md`).
   - 회귀:
     - 전체 pytest와 기준선 JUnit 비교(새 실패 0, 노드는 추가만).
     - `bash app/scripts/build.sh`, `bash app/scripts/test.sh`.
     - 런타임 Python `scan_private`.
     - `history_transport_app.py` 전체.
   - 금지: git push, 서버 `~/.hermes` 쓰기, 앱 설치, 실제 응용 프로그램 폴더 변경, 버전 번호 변경(TASK-04), 코드 정리(TASK-05·06), rebase·force.
   - 병렬 갈래: 없음(갈래 3개 미만 — 독립 갈래는 앱 정리와 V-4 두 개뿐이고, V-3은 앱 시험 등록 파일 `TestMain.swift`·하네스를 정리 기능 시험과 함께 쓴다).
10. **가정·미확정**
    - [가정] 섬 클릭은 `IslandModel`에서 `reveal`로 이어진다. 경로가 다르면 실제 경로를 impl-report에 적는다. 그 경로가 알림을 확인하지 않아 AT-TIDY-11이 실패하면 멈추고 보고한다.
11. **사용자 확인:** 브레인스토밍에서 결정했다(휴지통 이동만, 같은 ID·더 낮은 빌드·두 폴더 최상위만).

결과는 개발 main `impl-report.md`에 "TASK-03" 절로 남긴다(`git commit --only`).
