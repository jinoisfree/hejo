# [설계 인계: HEJO-ALERT-SEEN TASK-01 / 직접 고른 알림 확인 + 카드 제목 구분]

0. **기준**: base_commit = 착수 시 `github/main` tip. 설계 근거로 본 공개판은 `c22e677`. spec 3판·design 3판·수락 시험 3판(검증 2차 V-1 반영, verdict.md. 2판은 계획 검증 APPROVED) / 작성 2026-11-25 / 승인: 사용자 결정 D-01·D-02(tasks.md), 계획 승인은 이 계획 전달로 / 운영 모드: 교차 모델(연합개발).
   - **착수 조건(차단)**: `git fetch github` 뒤 `github/main`에 HEJO-AUTOLOAD TASK-01 앱 변경이 들어 있어야 한다(`docs/changes/HEJO-AUTOLOAD-20261125/verdict.md` 완료 판정 + 공개판 반영). 없으면 아무것도 바꾸지 말고 `result`(보류: AUTOLOAD 미반영)로 보고한다.
   - **착수 조건 확인(2026-11-26, 계획 담당):** 충족. HEJO-AUTOLOAD TASK-01 완료 판정(verdict 7차, 커밋 `5a4b3f7`)과 후속 TASK-03~06 완료가 공개 `github/main` `7540da13639b1094774195ea6815b3d0d4cdf826`에 들어 있다(`onLoadViewport`·`autoloadAppended` 존재). 이 tip에서 "원문 불러오기" 버튼은 없어졌고 남은 "다시 시도"는 `historyLoading.retry`만 부르며 선택을 하지 않는다(10절 가정 확인). `markAlertSeen` 호출은 여전히 `reveal`·`chooseThread` 두 곳, `writeReply`는 확인 없음, 문 notice 미리보기는 첫 줄 그대로다(design 1절 현황 유지). HEJO-WAIT-JITTER도 같은 tip에서 착수할 수 있으니 9절 6의 "커밋 전 tip 재확인"을 지킨다.
   - 착수하면 tip 전체 해시를 base_commit으로 impl-report에 적고, design 1절 현황(선택 경로 목록, notice 미리보기 계산)이 그 커밋에서도 맞는지 확인한다. 다르면 다른 점을 impl-report에 적고, 직접 선택/자동 선택 구분이 설계 표로 판정되지 않는 새 경로가 있으면 멈추고 보고한다.
1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), 수락 시험 `tests/acceptance/HEJO-ALERT-SEEN.md`, `docs/ARCHITECTURE.md`. 참고 계약: `docs/changes/HEJO-TODO-DRAWER-20261120/spec.md`(AT-TD-39), `docs/changes/HEJO-UI-CLEAN-20261123/spec.md`(REQ-UC-03 AC-07).
2. **요구와 수락 기준**: REQ-AS-01(사장이 직접 고른 알림 스레드는 확인 처리, 자동 선택은 제외, 질문은 답해야 빠짐; AC-01~06·05a, 실패 AC-07a~c, 일반 스레드 읽음 보존 AC-08, 옛 의도 버림 AC-09). 3판 핵심: 울리는 알림을 직접 고르면 읽음 요청은 `notice` 한 건만(그것이 `thread:`·`bell:`을 함께 씀), 조정자는 선택·입력 변경 때 지금 세대의 읽음 요청은 남긴다. REQ-AS-02(notice 미리보기 첫 줄이 멘션뿐이면 " · 다음 줄"; AC-01~08).
3. **유지할 계약**: `bell:`·`thread:` 키와 읽음 계획(`read_plan`), 알림·질문 판정, 자동 선택 동작, 문 HTTP 규격(필드 추가·삭제 없음), 섬 질문 미리보기 24자, 요약 `title`·`preview`·`rootPreview`, 기존 시험 AT-TD-39·AT-UC-17·AT77 기대값.
4. **책임·흐름**: 사장 직접 선택은 앱의 단일 입구 하나가 "선택 + (울리는 알림이면 `notice` 한 건, 아니면 경로별 `thread` 읽음)"을 한다. 요청은 `HistoryCoordinator.read` → 문 `read_plan` → 앱이 한 번에 적용. 조정자 `inputsChanged`는 새 세션이 아니면 지금 `intentGeneration`의 읽음 요청을 남기고 옛 세대만 버린다(design 2.1). 카드 제목 원본은 문의 notice `preview` 한 곳.
5. **기존 경로 판정**: design 4절. `reveal`·`chooseThread`의 직접 `markAlertSeen` 호출은 지운다(호출은 입구 한 곳만, AT-AS-08). 조정자 `inputsChanged`의 세션 외 `reads = []`는 세대 필터로 교체. 자동 선택 경로·레거시 참조 제목·보내기 직전 세대 검사는 유지.
6. **위험도·증거**: 일반. 필요한 증거 수준 2(대역 문 + 앱 하네스, 문 pytest). 설치·게이트웨이 재시작 없음(범위 밖). 롤백: 커밋 되돌림은 동작만 되돌리고 이미 쓴 회원 읽음 상태는 남는다(design 5절). 허브 상태를 손으로 고치지 않는다.
7. **변경 성격**: 의미 변경(작음). 비교: 수락 시험 3판의 "기준본 기대" 열. 2판 기준본 실행에서 이미 관측한 값이 3판 열에 들어 있다. 시험 코드를 3판 기대값으로 고친 뒤 착수 커밋에서 다시 돌려 그 열과 맞는지 확인하고 `.build/alert-seen/baseline-v3.log`에 남긴다. 기대와 다르면 제품을 고치지 말고 멈추고 보고한다.
8. **수락 시험**: AT-AS-01~06·07a~c·08~13(`tests/acceptance/HEJO-ALERT-SEEN.md` 3판). 기대값 출처: spec 3판 4절·사용자 결정. 상태: 명세 확정 / 2판 기준 코드 미커밋(공개 worktree) / 2판 기준본 실행 완료 / 3판 고침은 검증 담당.
9. **작업 범위·순서**
   1. 공개 worktree를 착수 tip에서 만든다: `../.worktrees/hejo-alert-seen-public-20261125`, 브랜치 `hejo-alert-seen-public-20261125`. 증거는 그 worktree의 `.build/alert-seen/`(커밋하지 않음).
   2. **시험 먼저(제품 코드 수정 전):** 공개 worktree에 이미 있는 미커밋 시험 파일 4개(`app/Tests/HistoryAlertSeenHarness.swift`, `app/Tests/HistoryTransportHarness.swift`, `gate/tests/history_transport_app.py`, `gate/tests/test_history_queries.py`)를 3판 기대값으로 고치고 AT-AS-12·13을 추가한다. 착수 커밋(제품 무변경)에서 돌려 `.build/alert-seen/baseline-v3.log`를 남기고, 7번과 맞으면 시험 전용 첫 커밋을 만든다. 착수 tip이 `7540da1`보다 앞서 있으면 그 tip으로 worktree를 옮긴 뒤 한다.
   3. 문: `gate/history_queries.py` notice 미리보기 규칙. 2번의 AT-AS-09·10을 다시 돌린다.
   4. 앱: 직접 선택 단일 입구(울리는 알림이면 `notice` 한 건, 아니면 경로별 `thread`), 경로 이관(`reveal`·`chooseThread`·`writeReply`), 조정자 `inputsChanged`의 세대 필터. 2번의 시험을 그대로 다시 돌린다(시험 기대값은 바꾸지 않음).
   5. 회귀: `bash scripts/test.sh`(Hermes 시험 venv + 실행 workspace PYTHONPATH 필요), 기록 하네스 전체, `scan_private.py`(Hermes 실행 venv python). 실패 목록을 착수 커밋과 비교.
   6. 공개 worktree에 제품 수정을 두 번째 커밋으로(`git commit --only`로 자기 경로만). 커밋 전에 `github/main`이 바뀌었으면 그 위로 다시 올리고 AT-AS 재실행. impl-report.md를 이 폴더에 쓴다(planner checkout의 이 폴더, 자기 파일만).
   - 금지: 개발 `main`·planner checkout의 제품 코드 수정, 알림·질문 판정 변경, 새 저장 키·문 HTTP 필드, 자동 선택 동작 변경, 레거시 참조 경로 제목 변경, `~/.hermes` 설정·플러그인 연결·재시작·비밀 파일, 앱 설치, git push, 기존 시험 기대값 변경, 범위 밖 정리.
   - 선행: HEJO-AUTOLOAD TASK-01 반영(0절).
   - 병렬 갈래: 없음(갈래 3개 미만: 앱·문 두 갈래).
10. **가정·미확정**: [확인 2026-11-26] AUTOLOAD 뒤 "원문 불러오기"는 없고 "다시 시도"는 선택하지 않는다. [가정] 대역 문에서 요청을 붙잡아 AT-AS-13을 만들 수 있다(불가능하면 멈추고 보고). [가정] 세대 필터로 남긴 요청이 취소된 작업 뒤 다시 시작돼 나간다. 나가지 않으면 그것도 같은 자리(`inputsChanged`·`start`)에서 고친다.
11. **사용자 확인**: D-01·D-02를 2026-11-25 질문으로 받음. 사전 위임 없음.

## 인계 전 점검
- base_commit은 착수 때 고정(0절). design 1절은 `c22e677` 기준으로 확인했고 착수 tip 재확인이 착수 조건에 포함됨.
- G1: 요구·범위·제외·사용자 결정 기록. G2: 현황 근거·단일 입구·경로 판정. G3: AC↔AT 연결(사전 검토 생략 이유 tasks.md). G4: 위험 일반, REQ→AC→AT→TASK 연결.
