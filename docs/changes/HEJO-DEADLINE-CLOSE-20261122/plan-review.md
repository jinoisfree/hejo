# HEJO-DEADLINE-CLOSE 계획 검증 기록

## 1회차 · 2026-11-22 · BLOCKED

- planHash `ee001aaf24f6d7a7af482565e4f46c88a9207ba8f80ffbd7dbcc6d511ec0a940`(1판)
- 반영본: spec·design·tasks·handoff·수락 시험 2판

| 지적 | 심각도 | 판단 | 이유와 반영 |
|---|---|---|---|
| PR-01 목록 수신 때 `closing` 전체 해제 | 차단 | **수용** | 근거가 맞다. 1판 design 5절은 새 목록이 오면 `closing`을 통째로 비워서, 응답 대기 중인 B가 다시 보인다. 2판에서 바꾼 것: <br>• 상태를 `pendingClose`/`inFlight`(요청별 ref·75초)/`confirming`(성공 뒤 목록 번호)로 나눴다. <br>• 목록 요청마다 단조 번호를 붙인다. 숨김을 푸는 응답은 성공 뒤 번호 이상이고, 유효하며, 그 직원이 `failed`에 없는 것뿐이다. `inFlight`는 목록으로 풀지 않는다. <br>• spec AC-04를 고치고 AC-10을 더했다. 시험 AT-DC-27b(늦은 목록·실패·부분 실패·재등장)와 27c(A 성공/B 대기)를 더했다. 성공 직후 확인 요청은 칸이 닫혀 있어도 1회 보낸다 |
| PR-02 잠금 대기와 60초 제한 | 차단 | **수용** | 1판은 실행만 60초로 제한해서 대기 시간이 쌓일 수 있었다. 2판에서 바꾼 것: <br>• 요청 수신부터 총 60초 = 잠금 대기 ≤20초 + 실행 40초로 나눴다. <br>• 대기가 만료되면 자식 프로세스를 만들지 않고 `busy`로 답한다(미실행 보장). <br>• 실행 시작 뒤의 실패나 응답 상실은 "실행됐을 수 있음"으로 보고 다음 목록으로 확인한다. <br>• 앱 75초는 문 총 60초보다 길다. <br>• 안내판 reason에 `busy`를 더했다. 시험 AT-DC-16b(긴 요청 3개, 미실행 표식 확인)를 더했다 |
| PR-03 `already_closed` 원자적 판정 | 차단 | **수용** | 1판이 권장한 전후 비교는 잠금 밖이라 경합한다. 2판에서 바꾼 것: <br>• 허용 변경 범위를 정확히 정했다. team-kit `perform`의 close 분기(이미 잠금 안)가 반환에 `closed_now`를 더하는 것만 허용한다. <br>• CLI는 `closed_now`가 참일 때만 다시 칠한다. <br>• spec DC-05 AC-03·AC-05를 고쳤다. 시험 AT-DC-09b(close 2개 동시, close와 직원 close 동시 → 새 닫힘·다시 칠하기 정확히 1번)를 더했다 |
| PR-04 `origin`·`notice`와 기존 허용 키 충돌 | 차단 | **수용** | `tests/acceptance/test_deadlines.py:57` 허용 키에 두 키가 없어 확인했다. 2판에서 바꾼 것: <br>• 계획 담당이 수락 시험 쓰기 허가로 그 줄을 직접 고쳤다(`origin`·`notice` 추가). HEJO-TODO-DRAWER.md AT-TD-10·AT-TD-01 행에 대체 표시를 했다. <br>• handoff 3번에 바뀌는 기존 기대값을 정확히 셋으로 나열했다: AT-TD-26 일부, AT-TD-10 허용 키, AT-TD-01 키 집합. <br>• AT-TD-01은 운영 저장소 시험이라 TASK-01 영향 파일에 명시했다. AT-DC-20에도 같은 내용을 적었다 |
| PR-05 수동 시험의 직원 id 기록 | 권고 | **수용** | 사용자 제약과 충돌했다. M-DC-1은 "개수와 가명(직원 A·B…)만"으로 바꿨다 |
| PR-06 일부 분기 관측 누락 | 권고 | **수용** | 시험을 더했다. <br>• 심볼릭 링크 거부: AT-DC-06(마) <br>• 앱 종료 전 대기 미전송: AT-DC-34. design에 "정지 때 pendingClose 버림"을 명시했다 <br>• 출처 열기 실제 실행: AT-DC-26 확장 <br>• 인증되지 않은·틀린·취소된 출입증 연결의 미실행: AT-DC-35. spec NFR-DC-02에 명시했다 |

반박·보류: 없음.

### 확인한 것

- `scan_private.py`(Hermes venv): 종료 0
- `git diff --check`: 종료 0
- [미실행] `pytest tests/acceptance/test_deadlines.py`: 두 Hermes venv 파이썬 모두 pytest 모듈이 없다(`/tmp/dc-plan2-test_deadlines.log`). 고친 줄은 허용 키 집합을 넓히는 부분집합 검사뿐이라 기존 출력에서 거짓 실패가 생기지 않는다. 구현 담당이 전체 시험에서 실행한다.

## 2회차 · 2026-11-22 · BLOCKED

- planHash `c6dc6e350c1d7bc6c5a0d90f616301d4e94c4d87fa0507d32ee2f94607d9f07c`(2판)
- 반영본: spec·design·tasks·handoff·수락 시험 3판
- 1회차 PR-02·04·05·06은 통과했고, PR-01·03은 후속 지적으로 다시 열렸다.

| 지적 | 심각도 | 판단 | 이유와 반영 |
|---|---|---|---|
| PR-01-R2 공유 읽기로 옛 결과가 확인 요청에 쓰임, 역전 도착 | 차단 | **수용** | `gate/deadlines.py:75-79`에서 `_running`을 공유하는 것을 확인했다. 닫기 전에 시작한 읽기에 성공 뒤 요청이 합류할 수 있다. 3판에서 바꾼 것: <br>• **문**: `close_generation`을 둔다. 닫기 실행이 끝나면 응답 전에 세대를 올린다. 목록 읽기 공유는 세대가 같을 때만 하고, 다르면 새 읽기를 시작한다(spec DC-04 AC-07, design 3절). <br>• **앱**: `lastAppliedSeq`보다 앞 번호의 목록 응답은 통째로 버린다(spec DC-03 AC-11, design 5절). <br>• 목록에 항목이 남아 있어도 원인(다시 엶)을 추정하지 않고 장부대로 보여 준다는 문구로 고쳤다. <br>• 시험: AT-DC-16c(실제 `Deadlines.list` 공유 경로, 세대별 실행 횟수·결과), AT-DC-27d(R1→R0 역전 도착 폐기) |
| PR-03-R2 직원 도구 `handle`의 중복 다시 칠하기 | 차단 | **수용** | `deadline_watch.py:450-451`이 `ok`만 보고 다시 칠하는 것을 확인했다. 요구(정확히 1번)와 "handle 불변"이 충돌했다. 요구를 유지하고 보존 계약을 좁혔다: handle의 다시 칠하기 조건을 `ok and closed_now`로 바꾸는 한 줄만 허용한다(이미 닫힘이면 `status_updated:false`). spec DC-05 AC-05, design 2·6절, handoff 3번에 반영했다. 사장 결정 범위 안의 내부 부작용 정리라 사용자 재승인 대상이 아니다. AT-DC-09b는 실제 `handle(kind="chat")` 진입과 CLI를 두 순서로 동시에 실행해 다시 칠하기 횟수를 관측하도록 바꿨다(+이미 닫힌 항목에 handle만 다시 호출하는 경우) |

반박·보류: 없음.

## 3회차 · 2026-11-22 · APPROVED

- planHash `f6f0e36358b56bb19f68ae6fb4dfc0a7233d1003825cfe47a298f851f8952978`(3판)
- 지적 없음. 계획은 3판 그대로 유지하고, G3(사전 별도 검토)를 통과했다.
