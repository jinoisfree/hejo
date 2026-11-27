## 구현 인계: HEJO-RESULT-DONE-20261127 TASK-01~04 / 결과 알림(확인·되돌리기)을 질문에서 빼고 답 버튼 복구

1. 받은 설계: [handoff.md](handoff.md)(spec 4판, 수락 시험 4판), 기준 공개 `github/main` `63e7bf9da0789be6128f10afe8e5bb8ccda6fe90`, 운영 문 줄 `f7fdc1a6a43e04a34dc90385fe3193427d393414`. 위험도 일반. 필요 증거: AC-01~10·15 = 2, AC-12·13 = 3, AC-14 = 4(사장 관측, 구현 범위 밖). 연합개발.
2. 구현자 판단 상태: **구현 완료**(TASK-01~04 전부). AC-14만 사장 관측 대기. 최종 완료 판정은 검증 역할.
3. 변경 후 구조: 판정 원본은 문 `gate/history_queries.py` 한 곳(`result_notice` → `assess`·`questions`)이고, `summary`가 `waitingButtonIDs`(seq 순)를 안내판으로 보낸다. 앱은 `HistoryThreadSummary.waitingButtonIDs`를 `ConversationModel.assessment` 이력 분기의 `buttons`로 넘겨 답 버튼을 그린다. 앱 `ThreadAssessment.assess`·`ReplyButtonPolicy`는 변경 없음.
4. 더한 것 / 뺀 것:
   - 공개 `2595200`(TASK-01): `gate/history_queries.py`(`RESULT_LABELS`·`result_notice`, `assess`의 요청 선택을 `request_for`·`judge`로 나누고 답 없는 결과 알림을 제외, `waiting`에 답 없는 결과 알림 합집합, `summary`의 `waitingButtonIDs`·`waitingButtonCount`, `questions`에서 결과 알림 제외), `schemas/hejo-history-v1.json`(선택 필드), `app/Sources/HistoryProjection.swift`, `app/Sources/ConversationModel.swift`(이력 분기), 새 시험 `gate/tests/test_result_done.py`·`app/Tests/ResultDoneTests.swift`·`app/Tests/result_done_fixture.py`, 앱 시험 연결 `app/Tests/TestMain.swift`(모드 1줄)·`app/scripts/test.sh`(1줄). 지운 것 없음(옛 `assess` 본문은 `judge`로 같은 자리에서 대체).
   - 운영 문 줄 `c2b292d3adb051fe08156e63b6b1057bd1f5cc7d`(TASK-02): 문·안내판·문 시험만(`git apply`로 같은 패치).
   - 공개 `740f3af`(TASK-04): `app/Resources/Info.plist` 0.2.10 / 12, `tests/acceptance/test_ship.py` 기대값.
   - 운영 저장소 `a64ecfe9`(TASK-03): `docs/changes/HEJO-RESULT-DONE-20261127/ops-targets.md` 적용 결과, `at-rd-12.json`(실제 id, 비공개).
5. 설계와 달라진 점: 없음. 구현 세부 판단 두 가지(설계가 내부 구조를 구현 담당에게 맡긴 부분): (가) 마지막 요청성 글이 답 없는 결과 알림이고 그 앞 요청들 가운데 답 없는 진짜 질문이 없으면 `requestID`=결과 알림, `settled`=true. 진짜 질문이 있으면 그 질문이 `pendingID`다. 마지막이 아닌 답 없는 결과 알림(그 뒤에 다른 요청이 있는 경우)도 요청 후보에서 빠진다. (나) `waiting`은 기준 규칙(2개 미만이면 `{pendingID}`, 새 `pendingID` 기준)을 먼저 계산한 뒤 답 없고 상태가 `answered`·`closed`가 아닌 결과 알림을 더한다.
6. 6절 형태: 없음(옛 경로 공존·플래그 없음). 임시 코드 없음.
7. 변경 성격: 의미 변경(판정·표시). 비교 증거: 기준본 (가) 실행 `.build/result-done/baseline.log`, 무작위 스레드 20000개 중 결과 알림이 없는 16816개에서 새 `assess`가 기준본과 완전히 같음(일회성 차분 시험, 커밋하지 않음), AT-RD-12 실제 기록 사본 비교.
8. 시험:
   - `gate/tests/test_result_done.py`(28개): AT-RD-01·01b·01c·02·03·04·05·06·07과 seq 순서 시험. 각 시험이 보호하는 계약은 spec 3절 AC 한 줄과 같다(함수 이름에 AT 번호 포함). `*_judgement`는 기준본에서도 실행할 수 있는 판정 부분, `*_waiting_ids`는 새 필드 부분.
   - 앱: `ResultDoneTests.swift`+`result_done_fixture.py`(가짜 문, 실제 이력 모드 대화 화면·버튼 보기 `invoke` 누름): AT-RD-08·08b·09·10·01b/01c 앱 부분.
   - mutation check: (문) `questions`의 결과 알림 제외 제거 → AT-RD-06 실패, `waiting` 합집합 제거 → 3개 실패. (앱) `buttons`를 빈 집합으로 → AT-RD-08 실패. 모두 원복.
   - 지우거나 합친 시험 없음.
9. 실행한 검증(`.build/result-done/`, 공개 worktree):
   - 기준본 (가): `baseline.log` — 기대와 일치(01·02·03·06 실패, 01b·01c·04·05 통과).
   - 문: `gate-tests.log`(pytest -v, 공개) 616 통과·6 실패, 6개는 기준본 `63e7bf9`에서도 같은 6개가 실패함(`baseline-known-failures.log`: delivery_parity 1, gateway_progress 1, gate_delivery 1, gate_foundation 1, slack_move_gate 1, telegram_remove 1, 환경 의존). 운영 줄: `ops-evidence/ops-gate-tests.log` 853 통과·16 실패, 16개 모두 기준본 `f7fdc1a`에서도 같은 항목이 실패함(`ops-evidence/ops-baseline-known-failures.log`). 새 시험 실패 0.
   - 앱: `app/scripts/test.sh` 전체 종료 0(`app-full.log`), `app-tests.log`에 AT-RD-10·08·08b·01b(접두·공백·역순 앱 부분)·09 PASS 줄과 `RESULT_DONE_WIRE_PASS`.
   - 정적 분석: `python3 scripts/scan_private.py`(Hermes 운영 venv) 종료 0, 개인값 지적 0(`scan-private.log`).
   - AT-RD-11: `ops-evidence/at-rd-11.log` 두 diff의 변경 줄(+/−) 66줄씩 동일.
   - AT-RD-12(서버 기록장 읽기 사본, 증거 수준 3): 스레드 193개, 바뀐 스레드 4개(전부 결과 알림 포함), 섬 질문에서 빠진 글 4개(전부 결과 알림), 관측 스레드 `settled`=true·`pendingID`=null·`notice`=null·`waitingButtonIDs`=[그 결과 알림]. 임시 폴더 삭제. 실제 id 상세는 비공개 `at-rd-12.json`.
   - AT-RD-13(증거 수준 3): `<HOME>/plugins/hejo` → `c2b292d3adb0-result-done`(RELEASE = 후보), 재시작 1회(롤백 0회, 게이트웨이 pid 59156 → 9240), 연결 줄 수 적용 전 {hejo 6, slack 6, photon 1} = 적용 후 같음, 기준 밖 새 오류 줄 0, discord 429 재시도·`discord_follow_failed` 0, 기동 뒤 3분 시점 재확인도 같음, `/v1/history/capabilities` 200 `history-v1`. 설정·금고·admin 파일은 열지 않고 크기·모드·수정 시각만 전후 비교(같음). 롤백 대상 `f7fdc1a6a43e-ref-photo` 폴더는 그대로 둠.
   - AT-RD-15: `bash app/scripts/build.sh` 종료 0(`build-final.log`), `CFBundleShortVersionString`=0.2.10·`CFBundleVersion`=12, `tests/acceptance/test_ship.py` 17개 통과(`ship-tests.log`).
   - 도달 증거 수준: AC-01~10·15 = 2(+AC-15 빌드 1), AC-11 = 1·2, AC-12·13 = 3. AC-14 = 미도달(사장 관측).
10. 미검증 범위와 남은 위험: AC-14(사장 앱 0.2.9에서 초록·카드 사라짐, 새 앱에서 버튼 표시)는 사장이 앱을 보기 전까지 미확인. 앱 설치·GitHub 릴리스 게시는 하지 않았다. 문은 서버에 적용됐지만 사장 앱 새 버전은 아직 설치 전이라 버튼 복구는 보이지 않는다. 실제 `waitingButtonIDs` 와이어 응답은 서버에서 인증된 질의로 확인하지 않았다(AT-RD-12가 같은 코드로 실제 기록 사본을 계산).
11. 범위 밖 기술 부채: 환경 의존 실패(공개 6·운영 16)는 이 작업과 무관하다. `docs/spec/current/hejo-thread-status.md`의 "상태 원본" 문장(GAP-RD-01)은 계획 담당이 판정 뒤 고친다. 시험 실행 환경 메모: 이 서버에서 pytest는 `TMPDIR=/tmp/`(또는 짧은 `--basetemp`)가 필요하다. 기본 임시 경로는 AF_UNIX 경로 길이 제한으로 문 시험 다수가 setup 오류가 된다.
12. 검증 역할이 특히 봐 줬으면 하는 곳: `gate/history_queries.py` `assess`의 `held`/`real` 처리(마지막이 아닌 결과 알림, 결과 알림 앞의 `answered` 상태 질문), `waiting` 합집합과 `{pendingID}` 대체 규칙의 순서, 운영 적용 로그 `ops-evidence/operations.jsonl`.
13. 검토 대상 코드 상태: 공개 worktree `../.worktrees/hejo-result-done-public-20261127` 브랜치 `hejo-result-done-public-20261127` 커밋 `2595200`(TASK-01)·`740f3af7f27fb213a98c683066268ccc35b9834f`(TASK-04), 시작 `github/main` `63e7bf9`. 운영 문 worktree `../.worktrees/hejo-result-done-ops-20261127` 브랜치 같은 이름 `c2b292d3adb051fe08156e63b6b1057bd1f5cc7d`(시작 `f7fdc1a`). 운영 저장소 `a64ecfe9`. 증거 폴더: 각 worktree `.build/result-done/`(공개 쪽 `ops-evidence/`에 운영 적용 개수·판정). 푸시 없음.
