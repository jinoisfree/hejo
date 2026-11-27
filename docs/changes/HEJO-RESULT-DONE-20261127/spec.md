# HEJO-RESULT-DONE 명세·설계

- 4판 · 상태: 초안(계획 검증 3회차 BLOCKED 반영, 재검증 대기) · 2026-11-27 · 변경 이력: [plan-review.md](plan-review.md)
- 기준: 공개 `github/main` `63e7bf9da0789be6128f10afe8e5bb8ccda6fe90`, 운영 문 줄 `hejo-ref-photo-ops-20261126` `f7fdc1a6a43e04a34dc90385fe3193427d393414`(서버에서 실행 중인 공용 릴리스 `f7fdc1a6a43e-ref-photo`와 같은 커밋)
- 결정 근거: [brainstorm.md](brainstorm.md)
- 위험도: 일반(공통 4절). 문 판정과 앱 표시가 바뀌고 안내판에 선택 필드 하나가 추가된다. 운영 문을 교체한다(재시작 1회, 롤백 재시작 1회 허가). 저장 형식·권한·금고는 바뀌지 않는다.

## 0. 칸·원본·쓰기 주체·수명

| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 스레드 판정(요청·대기·끝남), 섬 질문 목록, 답 버튼 글 목록 | 공항 시설 · 탑승교(hejo 문) | `gate/history_queries.py` `assess`·`summary`·`questions` | 개발 | 갱신 때 교체 |
| 요약 프레임의 새 필드 `waitingButtonIDs` | 공항 시설 · 안내판 | `schemas/hejo-history-v1.json` `$defs.summary` | 개발 | 갱신 때 교체 |
| 요약 해석·답 버튼 표시 | 관제 화면(hejo 앱) | `app/Sources/HistoryProjection.swift`, `app/Sources/ConversationModel.swift` `assessment(_:)` | 개발 | 앱 갱신 때 교체 |
| 문 릴리스 만들기·설치 | 정비 격납고 | `install/hejo-release`, `hejo-install`(코드 변경 없음), 공용 릴리스 폴더 | 운영자 / 설치 도우미 | 릴리스 폴더는 불변, 링크만 바뀜 |
| 대화 글·버튼·`reply_state` | 공용 창고 | `<HOME>/shared/hejo/journal` | 시설 런타임(읽기만 함, 이 작업은 쓰지 않음) | 영구 |

점검표(ARCHITECTURE 8절):
1. 판정 원본은 문 `assess` 하나다. 앱 `ThreadAssessment.assess`는 옛 기준본 빌드(`HEJO_LEGACY_REFERENCE` 등) 전용 비교 자료라서 두 번째 원본이 아니며 고치지 않는다. 답 버튼 글 목록도 문이 만들고 앱은 그대로 쓴다.
2. 쓰기 주체: 문은 기록장을 쓰지 않고 읽기 결과만 바꾼다. 사장 칸(금고·지시서·회원 상태)은 쓰지 않는다.
3. 갱신: 문은 새 공용 릴리스 폴더 + 링크 교체, 롤백은 이전 릴리스 폴더로 다시 연결한다. 앱은 새 버전 설치로 교체한다. 기록장은 그대로 둔다.
4. 개인값: 시험은 가짜 명부·가짜 글만 쓴다. 실제 스레드 id·직원 id는 운영 저장소 대응표에만 둔다.
5. 다른 공항: 버튼 라벨만으로 판정하므로 코드 수정 없이 같게 동작한다.

## 1. 현황 [확인]
- 문 `assess`(공개 `gate/history_queries.py:44-89`)는 `reply_state`·`buttons`·`checklist`·승인 문구 중 하나가 있는 직원 글을 요청으로 본다. 마지막 요청에 사장 답이 없으면 `pendingID`가 된다. `summary`는 `pendingID`가 있으면 질문 `notice`를 만들고, 앱은 `pendingID`로 빨간 띠와 답 요청 카드를 그린다.
- 답 버튼 글: `assess`가 `waiting` 집합을 만들지만 `summary`는 그 개수(`waitingButtonCount`)만 보낸다. 앱 이력 분기 `assessment(_:)`는 `buttons`를 비워 두고(`ConversationModel.swift` 이력 분기의 `.init(...)`), 화면은 `assessment.buttons.contains(message.id)`일 때만 답 버튼을 그린다(`ConversationView.swift` `postPieces`). 그래서 지금은 어느 글에도 답 버튼이 나오지 않는다.
- 섬 질문 `questions()`는 `reply_state == 'asked'`이고 `confirm:`이 없으면 모두 넣는다.
- 버튼 누름은 사장 글(`text` = 라벨, `answer_to` = 그 글 id)로 기록된다(`gate/adapter.py` `click`).
- GAP-RD-01: 현재 명세 [hejo-thread-status.md](../../spec/current/hejo-thread-status.md)는 "상태는 `ThreadAssessment.assess` 한 곳에서 파생"이라고 적지만, 이력 모드 출시본의 실제 원본은 문 `assess`다. 이 작업 판정 뒤 현재 명세 반영 때 원본 위치를 문으로 고친다.
- 운영 문 줄 `f7fdc1a`의 `history_queries.py`는 공개판과 `thinking` 가져오는 곳·알림 미리보기 두 군데만 다르고 `assess`·`questions`는 같다.

## 2. 용어
- **결과 알림:** 직원 글이면서 버튼 라벨 목록이 가공 없이 이 순서 그대로 정확히 [`확인`, `되돌리기`]인 글이다(두 개, 순서 고정, 접두·공백 정규화 없음). 역순 [`되돌리기`, `확인`]은 결과 알림이 아니며 기존대로 판정한다(앱 `script`가 라벨을 순서대로 이어 `^확인 \| 되돌리기$`와 비교하기 때문, 3회차 RD-06). `reply_state`는 무엇이든 된다. 이 정의는 앱의 누름 규칙 `ReplyButtonPolicy.script`의 `확인 | 되돌리기`(원래 라벨 그대로 비교)와 같은 입력에서 성립한다. 그래서 문이 결과 알림으로 판정한 글은 앱에서도 되돌리기를 누를 수 있다(2회차 RD-05). `:이름:` 접두가 붙거나 공백이 섞인 라벨은 결과 알림이 아니다. 기존처럼 판정되며 앱 누름 규칙도 바꾸지 않는다. [확인] 2026-11-27 서버 기록장 전체에서 접두나 앞뒤 공백이 있는 버튼 라벨은 0개다.

## 3. 요구와 수락 기준

**REQ-RD-01 결과 알림은 대답을 기다리는 질문이 아니다.**
- AC-01(정상, 실제 사례): 직원 `asked`+[승인, 거절] → 사장 일반 글 → 직원 `asked`+[확인, 되돌리기]. `assess`: `pendingID = null`, `settled = true`, `working = false`. `summary`: `notice = null`, `bell = null`. 방 합계 질문 수 0.
- AC-02(경계): 사장 글 없이 직원 `asked`+[확인, 되돌리기] 한 글만 있는 스레드. `pendingID = null`, `settled = true`, `notice = null`(질문·알림 카드 둘 다 없음).
- AC-03(실패 방지): 답 없는 직원 `asked`+[승인, 거절] 뒤에 결과 알림이 온 스레드. `pendingID` = 앞 질문 글 id, 질문 `notice` 있음. 결과 알림이 진짜 질문을 가리지 않는다.
- AC-04(회귀): 버튼이 [확인]만, [확인, 되돌리기, 수정], [승인, 거절], 버튼 없이 `asked`만, 승인 문구만인 스레드는 기준 커밋의 `assess`와 결과(`assess` 세 반환값 전부)가 같다.
- AC-05(누른 뒤): 결과 알림에 사장이 버튼을 눌러(사장 글 `answer_to` = 결과 알림 id) 아직 직원 답이 없는 상태, 그리고 그 뒤 직원 답이 온 상태. 두 경우 모두 `pendingID = null`이고 기준 커밋 `assess`와 `working`·`settled`·`approved`가 같다.

**REQ-RD-02 섬 질문에서 결과 알림을 뺀다.**
- AC-06: `questions()`는 결과 알림을 넣지 않는다. 같은 방의 `asked`+[승인, 거절] 글은 지금처럼 들어간다.

**REQ-RD-03 답 버튼을 보여 줄 글 목록을 문이 보내고 앱이 그린다.**
- AC-07(문): `summary`에 `waitingButtonIDs`(글 id 문자열 배열, 정렬: seq 오름차순)가 있다. 값 = 기준 커밋의 `waiting` 규칙 결과 ∪ {사장 답이 없고 `reply_state`가 `answered`·`closed`가 아닌 결과 알림}. `waitingButtonCount` = 그 배열 길이. AC-01 스레드에서는 결과 알림 id 하나, AC-05의 누른 뒤에는 빈 배열이다. 평범한 답 없는 [승인, 거절] 질문 하나면 그 글 id 하나다(기준과 같음).
- AC-08(안내판): `$defs.summary.properties`에 `waitingButtonIDs`(문자열 배열)를 더하고 `required`에는 넣지 않는다. 새 필드가 있는 요약과 없는 요약이 둘 다 스키마 검사를 통과한다. 문 요약 출력이 스키마를 통과한다.
- AC-09(앱): 이력 모드에서 `assessment(key).buttons` = 그 스레드 요약의 `waitingButtonIDs`(없으면 빈 집합). AC-01 스레드의 결과 알림 글에 확인·되돌리기 버튼이 그려지고 스레드 색은 초록(`#2EB67D`)이다. 버튼의 누름 가능 여부와 누름 동작은 기존 규칙(`ReplyButtonPolicy.pressable`, `controller.click`)을 그대로 쓴다. 실제 라벨 [확인, 되돌리기]는 기존 `ReplyButtonPolicy.script`의 `확인 | 되돌리기` 규칙으로 누를 수 있다. 앞에 답 없는 질문이 함께 있는 경우(AC-03)에도 두 글의 버튼이 각자 활성이고, 누르면 각자 자기 글 id로 `click`이 간다.
- AC-10(호환): 필드 없는 요약(옛 문)을 받은 새 앱은 오류 없이 답 버튼 0개로 동작한다. 0.2.9 앱의 `HistoryThreadSummary`는 모르는 키를 무시하므로 새 문 요약을 그대로 읽는다(정적 확인: 커스텀 디코더 없음).

**REQ-RD-04 운영 공항에 적용한다.**
- AC-11: 운영 문 줄에 REQ-RD-01~03의 문·안내판 변경과 시험이 같은 내용으로 들어간다(공개판과 `assess`·`questions`·`summary`의 변경 부분 diff가 같음).
- AC-12(실제 자료, 재시작 전): 서버 기록장의 임시 읽기 사본으로 새 `HistoryQueries`를 돌리면 대응표의 실제 스레드가 `settled = true`, `pendingID = null`, `notice = null`, `waitingButtonIDs` = [그 결과 알림 id]다. 같은 사본에서 바뀐 스레드 목록(기준 커밋 대비 `pendingID`·`notice`·`settled`가 달라진 스레드)을 뽑아, 모두 결과 알림이 원인인지 확인한다.
- AC-13(적용): 새 공용 릴리스로 링크가 바뀌고(`<HOME>/plugins/hejo` RELEASE = 후보 커밋), 재시작 1회 뒤 플랫폼별 연결 줄 수가 적용 전과 모두 같고(늘거나 줄면 실패) 기준 밖 새 오류 줄이 0이다. 실패하면 5.3 롤백.
- AC-14(실물, 사장 관측): 사장 앱(0.2.9 그대로)에서 그 스레드가 빨간 띠 없이 초록이고 가운데 칸 답 요청 카드에서 빠진다. 새 앱 설치 뒤에는 결과 알림 글에 확인·되돌리기 버튼이 보인다.

**REQ-RD-05 앱 새 버전.**
- AC-15: 앱 버전을 0.2.10으로 올리고 `app/scripts/build.sh`가 성공한다. 기존 배포 시험(`tests/acceptance/test_ship.py`)이 새 버전으로 통과한다. GitHub 릴리스 게시는 사장 단계다.

## 4. 설계

### 4.1 흐름
기록장 → 문 `assess`(결과 알림 예외 포함) → `summary`(`assessment`, `notice`, `waitingButtonIDs`) / `questions()` → 안내판 프레임 → 앱 `HistoryThreadSummary` → `assessment(key)`(`buttons` 포함) → 띠 색·카드·답 버튼.

### 4.2 문 변경(설계 범위, 내부 구조는 구현 담당이 정함)
- 결과 알림 판정 함수 하나를 `history_queries.py`에 두고 `assess`와 `questions`가 함께 쓴다.
- `assess`: 결과 알림은 "답 없는 요청"으로 고르지 않는다. 다만 답이 붙은 결과 알림(AC-05)은 지금처럼 요청 후보로 남아 기준과 같은 결과를 낸다. 스레드의 마지막 요청성 글이 답 없는 결과 알림이고 그보다 앞에 답 없는 진짜 질문이 없으면 `settled = true`, `requestID` = 그 결과 알림 id로 둔다(`requestID`가 있어야 알림 카드 조건에서 빠진다, AC-02).
- `waiting`: 기준 규칙 그대로 계산한 뒤 답 없는 결과 알림을 더한다(AC-07).
- `summary`: `waitingButtonIDs`를 넣고 `waitingButtonCount`는 그 길이로 맞춘다.

### 4.3 앱 변경
- `HistoryThreadSummary`에 `waitingButtonIDs: [String]?`를 더한다.
- `ConversationModel.assessment(_:)` 이력 분기에서 `buttons`를 그 값으로 채운다. 다른 화면 코드는 바꾸지 않는다.

### 4.4 기존 경로 판정
| 경로 | 판정 | 이유 |
|---|---|---|
| 문 `assess`·`questions` | 유지(수정) | 판정 원본. 같은 자리에서 고친다 |
| `waitingButtonCount` | 유지 | 기존 계약. 값만 새 목록 길이로 맞춘다 |
| 앱 `ThreadAssessment.assess`(옛 기준본) | 유지(변경 없음) | 기준본 빌드 전용 비교 자료. 판정 원본이 아니다 |
| 앱 `ReplyButtonPolicy`·`controller.click` | 유지 | 누름 가능 여부와 전송은 기존 규칙 |

### 4.5 대안
- 앱이 요약 대신 글마다 버튼 대기 여부를 계산: 기각. 판정이 문과 앱 두 곳으로 갈라진다.
- `waitingButtonCount`를 id 배열로 바꿈: 기각. 0.2.9 앱이 필수 필드를 잃어 요약 해석에 실패한다.

## 5. 운영 적용

### 5.1 대상
- 문: 운영 문 줄 후보 커밋으로 새 공용 릴리스 `<공용 릴리스 폴더>/<후보 앞 12자>-result-done/hejo`를 만들고 `hejo-install`로 링크한다. 절차 원본은 [HEJO-REF-PHOTO handoff-task05.md](../HEJO-REF-PHOTO-20261126/handoff-task05.md) 5번 (1)·(3)~(7)의 문 부분과 같다(team-kit 부분 없음).
- 실제 스레드 id·대상 표: 운영 저장소 `docs/changes/HEJO-RESULT-DONE-20261127/ops-targets.md`(구현 담당이 만든다, 비공개).

### 5.2 재시작
운영 저장소 `AGENTS.md`의 재시작 절차(처리 중 턴·작업 0, 직전 게이트웨이 시작 뒤 300초 초과)만 쓴다. 허가: 적용 1회 + 실패 시 롤백 1회(사용자 2026-11-27 "설치까지" 선택).

### 5.3 롤백
적용 전 `<HOME>/plugins/hejo` 대상(현재 `f7fdc1a6a43e-ref-photo`)을 기록한다. 되돌릴 때는 그 폴더의 `hejo-install`로 다시 링크한다 → 재시작 → 연결 줄 수·오류 줄로 회복을 확인한다. 조건(AC-13 실패와 같음): 플랫폼별 연결 줄 수가 적용 전과 다름(증가·감소 모두), 기준 밖 새 오류 줄, 문 기동 실패 중 하나. 롤백 뒤 회복 판정도 같은 기준(적용 전과 모두 같음)을 쓴다. 기록장은 건드리지 않으므로 자료 복구는 없다.

### 5.4 앱
새 버전 빌드와 버전 커밋까지 구현 담당이 한다. 앱 설치·GitHub 릴리스 게시는 사장 단계다. 서버 Mac에서 앱을 바꿔 시험할 때는 기존 앱 백업을 `~/Library/Application Support/hejo-backups/`에 두고 판정 뒤 지운다(AGENTS.md).

## 6. 증거 수준(공통 5절)
AC-01~10·15 = 2(가짜 기록·시험 하네스, 스키마 검사, 빌드), AC-11 = 1·2(diff와 운영 줄 시험), AC-12 = 3(실제 기록장 읽기 사본 + 실제 문 코드), AC-13 = 3(실제 게이트웨이), AC-14 = 4(사장 관측).
