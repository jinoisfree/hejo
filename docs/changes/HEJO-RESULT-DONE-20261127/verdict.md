## 검증 판정: HEJO-RESULT-DONE-20261127 / 결과 알림(확인·되돌리기)을 질문에서 빼고 답 버튼 복구

1. **판정: 완료.** AC-14(사장 실물 관측)는 handoff 10번에 따라 구현 범위 밖의 사장 단계로 남긴다. 앱 GitHub 릴리스 게시·설치도 사장 단계다.
2. **검증 조건:** 교차 모델. 계획·검증은 Claude Opus, 구현은 Claude Sonnet의 별도 대화다. 이 대화가 설계도 했으므로 4.2를 따로 판정했다. 검토한 코드 상태:
   - 공개 worktree `hejo-result-done-public-20261127`: `2595200`(TASK-01), `740f3af7f27fb213a98c683066268ccc35b9834f`(TASK-04, HEAD, 작업 트리 깨끗함)
   - 운영 문 worktree `hejo-result-done-ops-20261127`: `c2b292d3adb051fe08156e63b6b1057bd1f5cc7d`
   - 서버 링크 `<HOME>/plugins/hejo` → 공용 릴리스 `c2b292d3adb0-result-done`
   - 운영 저장소 `a64ecfe9`(비공개 적용 기록)
3. **설계 적합성(4.2): 충족.**
   - 사장 요구는 "답이 더 필요 없는 글은 초록, 가운데 카드에서 빠짐, 되돌리기는 예외"였다. 판정 원본인 문 `assess`·`questions`에서 결과 알림을 질문 후보에서 뺐다. 그래서 띠 색·답 요청 카드·방 숫자·섬이 한 원본을 따른다.
   - 결과 알림 정의는 앱 누름 규칙(`ReplyButtonPolicy.script`, 원래 라벨을 순서대로 비교)과 같은 입력에서만 성립한다(계획 검증 2·3회차). 따라서 초록인데 되돌리기를 못 누르는 경우가 생기지 않는다.
   - 앞선 답 없는 질문은 가리지 않는다(AC-03).
   - 실제 기록 비교(AT-RD-12)에서 바뀐 스레드 4개가 모두 결과 알림 스레드였다. 의도하지 않은 영향이 없다는 근거다.
   - 설계와 달라진 점은 보고에 없고 diff에서도 찾지 못했다.
4. **직접 확인한 것**
   - **코드 읽기:** 공개 `63e7bf9..740f3af` 전체 diff와 운영 `f7fdc1a..c2b292d` diff를 읽었다.
     - `assess`: 답 없는 결과 알림을 `held`로 빼고 나머지로 기존 판정을 한다. 마지막 요청성 글이 결과 알림이고 `pendingID`가 없을 때만 그 글로 `settled`가 된다.
     - `waiting`: 기존 규칙에 답 없는 결과 알림을 더한다.
     - `summary`: `waitingButtonIDs`를 seq 순으로 보내고, `waitingButtonCount`는 그 길이다.
     - `questions`: 결과 알림을 뺀다.
     - 앱: 이력 분기에서 `buttons`를 `waitingButtonIDs`로 채운다. `ReplyButtonPolicy`는 변경되지 않았다.
   - **문 시험:** `gate/tests/test_result_done.py` + `test_history_queries.py`를 공개 worktree에서 실행했다. 66개 통과, 증거 수준 2.
   - **앱 시험:** `compile-tests.sh`로 `app-tests`를 다시 컴파일했다(종료 0). `result_done_fixture.py`를 직접 실행했고 종료 0이었다. 출력: AT-RD-10·08·08b·01b(접두·공백·역순)·09 PASS, `RESULT_DONE_WIRE_PASS`. 증거 수준 2.
   - **운영 줄 동일성:** 문 3개 파일의 변경 줄을 비교했고 공개 `2595200`과 운영 `c2b292d`가 같다(AT-RD-11). 릴리스 폴더 `gate/`(tests 제외)는 운영 worktree와 차이가 없고, RELEASE = `c2b292d3…`다.
   - **실제 기록:** 설치된 릴리스 코드의 `assess`로 서버 기록장 0700 임시 사본의 관측 스레드를 계산했다. 결과는 `settled`=true, `pendingID`=null, `requestID`=결과 알림, 버튼 대기 = 결과 알림 하나다. 임시 사본은 지웠다. 증거 수준 3.
   - **서버 기동:** 게이트웨이 pid 9240이 2026-11-27 16:48:33부터 실행 중이다. 링크는 새 릴리스를 가리킨다. 연결 줄 수·오류 줄 판정(AT-RD-13)은 구현 보고와 `.build/result-done/ops-evidence`를 근거로 수락했고, 다시 재시작하지는 않았다(허가 밖).
   - **수락 시험 무변경:** 개발 main의 `tests/acceptance/HEJO-RESULT-DONE.md`가 `ba7dfa2` 이후 바뀌지 않았다(`git diff ba7dfa2 HEAD`에서 impl-report만 바뀜). 시험 기대값은 spec 3절과 일치한다.
5. **지적:** 없음(차단 0, 비차단 0).
   - 기술 부채: 공개 6개·운영 16개 시험이 환경 때문에 실패하는데, 기준 커밋에서도 같다(구현 보고 9번).
   - 기술 부채: 앱 fixture는 요약을 직접 만드는 대역이다. 문 실제 요약과의 연결은 문 시험·스키마 시험·`RESULT_DONE_WIRE_PASS`로 보완된다.
6. **남은 조건(사장 단계):**
   - AC-14: 사장 앱에서 그 스레드가 초록이고 카드가 빠졌는지 본다. 0.2.9로도 문 적용만으로 보인다.
   - 0.2.10 GitHub 릴리스 게시·설치 뒤에는 확인·되돌리기 버튼이 보여야 한다.
   - 공개 푸시는 사용자 화면 승인 뒤 한다.
7. **현재 명세 반영: 완료.** 공개 `docs/spec/current/hejo-thread-status.md`에 REQ-RD-01~03 절을 더하고 상태 원본 문장을 문 `assess`로 고쳤다(GAP-RD-01 해소). 작업 문서·수락 시험과 함께 공개 docs 커밋으로 냈다.
