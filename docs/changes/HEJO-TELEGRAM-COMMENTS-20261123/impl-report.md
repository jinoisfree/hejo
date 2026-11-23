# TASK 1 구현 인계

## 범위·승인·판단

[설계 인계](handoff.md)의 최신 사용자 승인에 따라 4판 TASK 1 서버 구현과 대역 시험을 수행했다. 기준 HEAD는 `6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0`, 검토 대상은 이 커밋 위 작업 트리다. 연합개발·고위험이며 기능 전체에는 증거 수준 2와 4가 필요하다. TASK 1 준비 구현과 대역 시험을 마쳐 검토로 반환한다. 최종 제품 완료 판정은 하지 않는다.

## 변경 책임과 기존 경로

- `gate/telegram_comments.py`: 기존 Telegram 문이 소유하는 연결·권한 검사, native PTB 범위 선택, probe 예약 및 receipt, deadline, bind와 방 목적지 선택을 분리했다. 별도 서비스·폴링·대화 원본은 없다. 식별자는 기존 금고 `telegram.json`, probe 메시지 receipt는 기존 `sent.jsonl`에 저장한다.
- `gate/telegram.py`: native factory 연결, probe 예약을 보존하는 짝 해제·교체, 댓글 전환 방의 기존 토픽 수신·발신·typing·sync 제외, 종료 시 타이머 정리를 연결했다. 미전환 방의 포럼 경로와 기존 topic receipt 형식은 유지한다.
- `gate/adapter.py`: 기존 `receive` 진입부터 반환까지 방별 진행 수를 기록한다. journal 발행 이후 실제 gateway session guard가 생기기 전 틈에도 bind가 busy를 확인해야 하므로 원래 수신 책임 위치에서 추적한다. 앱 wire·수락 기준 변경은 없다.
- `gate/tests/test_telegram_comments.py`: 실제 gate 저장소와 PTB Application dispatcher를 사용하고 Bot API transport만 대역으로 교체한다. 모든 홈과 명부는 임시 시험용이다.

기존 경로를 복제한 새 전송기는 만들지 않았다. 댓글 정상 수신/발신은 TASK 2~3 전이므로 이 단계에서는 실행하지 않는다. 앱과 Hermes 본체, team-kit, 운영 설정은 변경하지 않았다. 하위 에이전트는 사용하지 않았다. 의미 변경이며 미전환 포럼 회귀와 비교한다.

## 주요 보호 계약

첫 probe 발신 전에 예약을 금고에 원자 저장한다. 예약된 입력은 pending·complete·실패·시간 종료·끄기·짝 해제 때에도 core 처리기로 넘기지 않는다. probe 명령 callback은 자동 전달을 기다리지 않고 반환하며 후속 callback이 receipt를 완결한다. 세 receipt의 기한 내 영속 완료가 bind 조건이고 complete에는 TTL이 없다. 실패 또는 불확실 발신은 자동 재발신하지 않는다.

bind는 현재 짝·사장·방·대상·봇·계약과 receipt를 확인하고 진행 차례·수신·전송이 없는 시점에 route epoch와 journal cutover를 원자 저장한다. 이전 기록은 재전송하지 않는다. probe 관찰 기본 기한은 60초이며 실제 M0 인계에서 이 관찰 시간을 명시해야 한다.

## 최초 구현 검증과 증거 (V-03/V-04 보완 전)

명령·종료 코드·제품 파일별 SHA-256·로그 연결은 [task1-runs.json](logs/task1-runs.json)에 기록한다. 시험 실행 Python은 Hermes venv이며 기존 로컬 의존성 및 설치된 PTB 22.8의 경로만 추가했다. 패키지 설치·환경 스크립트 source는 하지 않았다. 첫 실행의 Python 경로만으로는 telegram import가 실패하여 기존 설치본 경로를 보완했다. 긴 임시 경로에서 Unix socket 길이 제한으로 gate fixture가 실패하여 짧은 임시 pytest 경로를 사용했다. 시험 기준을 변경한 것은 아니다.

| 검증 | 실제 결과 | 증거 |
|---|---|---|
| 전체 `HEJO_PYTHON="$HEJO_PYTHON" bash scripts/test.sh` | 종료 0. Python 452개, gateway_delivery, Swift/AppKit 및 앱 fixture 통과. 아래 시작 시 보호 보완 전 변경본 | `logs/task1-check-02.log` |
| 최종 제품 변경본 `"$HEJO_PYTHON" -m pytest gate/tests tests/acceptance -q --basetemp=<temporary-basetemp> -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 455개 통과. 기존 hub 시험의 asyncio 표시 경고 1개 | `logs/task1-check-06.log` |
| 마지막 개발자 시험 보강 후 `"$HEJO_PYTHON" -m pytest gate/tests/test_telegram_comments.py tests/acceptance/test_telegram.py -q --basetemp=<temporary-basetemp> -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 68개 통과(신규 30개 + 기존 38개). 전체 서버 검사 이후 제품 코드는 그대로이며 두 시험만 추가 | `logs/task1-check-07.log` |
| 예약 소비 / receipt 완결성 변이 검사 | 각각 시험 종료 1로 변이 검출. 원복 해시 일치 확인 | `logs/task1-mutations.json`, `logs/task1-check-04.log`, `logs/task1-check-05.log` |

전체 검사 뒤 시작 시 primary 부재에도 금고 예약으로 native 입력을 소비하도록 보완했다. 금고의 비객체 JSON을 기존처럼 거부하고 누락 pair/code는 초기값으로 읽는다. 토픽 첨부 staging 이후 route 재검사와 bind 직전 명부 재검사도 수행한다. 이 보완은 최종 서버 전체 검사와 해당 Telegram 시험으로 검증했다. 앱 제품은 변경하지 않아 통과한 Swift/AppKit 전체 검사를 반복하지 않았다.

두 직원의 독립 연결과 대상 중복 거부, legacy/v2 혼합 receipt·불완전 끝 줄 복원·미지원 금고 버전, 실제 unpair 예약 보존도 검사했다. 일반 댓글의 bind 이후 정상 실행 부분(T24 중 TASK 2)은 아직 미실행이며 TASK 1 시험 성공으로 대신하지 않는다. 기존 전체 시험에서 나온 Swift 경고·시스템 UI 진단은 실패가 아니었으며 변경 대상이 아니라 유지했다.

개인값 검사는 새 제품 파일을 intent-to-add로 검사 대상에 포함한 상태에서 임시 홈으로 실행했다. 최종 정적 검사·diff 검사·보고 및 로그의 일반 개인값 패턴 점검은 `logs/task1-final-checks.json`과 `logs/task1-private.log`를 참조한다. 실제 개인 명부·금고를 읽는 검사는 하지 않았다.

## 미실행·다음 관문

실제 Telegram 메시지 발신, 운영 변경, M0, TASK 2~5, 운영 앱 설치, 커밋·푸시는 수행하지 않았다. 시험 스크립트가 만드는 임시 앱 빌드와 fixture 실행은 수행했다. 이 단계의 정상 bind는 준비 상태를 검증할 뿐 실제 댓글 실행 기능의 완성을 뜻하지 않는다. TASK 1 검토 뒤 실행 봇·수신 서버·단일 수신자·적용/롤백·발신 범위를 고정한 별도 M0 인계와 사용자 승인이 필요하다. 실물 M0 및 사람 화면 증거 전에 후속 구현을 시작하지 않는다.

검토자는 native 예약 소비, callback/타이머 직렬화, receipt 재시작 복원과 bind의 진행 상태 검사를 중점 확인해야 한다. 기술 부채를 추가로 정리하지 않았다. 타 작업 미추적 문서와 수락 시험은 보존했다.

## 검토 2회차 보완 — V-03 / V-04

검토의 두 결함을 TASK 1 승인 범위 안에서 보완했다. 기준 HEAD와 브랜치는 그대로이며 커밋하지 않은 작업 트리가 검토 대상이다. 설계·수락 기준·저장 형식 변경은 없다. 기존 `gate/adapter.py` 변경은 유지하고, 이번에는 `gate/telegram.py`, `gate/telegram_comments.py`, `gate/tests/test_telegram_comments.py`를 수정했다.

- V-03: `sync_topics`가 현재 명부에 존재하는 댓글/paused 방을 저장 토픽 순회에서도 건너뛴다. 그 방의 기존 토픽 이름·열림 상태는 바꾸지 않는다. 미전환 방의 생성·이름 변경·다시 열기와 실제 삭제 방의 닫기는 유지한다.
- V-04: 인증된 제어 명령에는 시험 시작, 연결 저장, 동일 연결, busy, probe_required, 권한 실패 결과를 안내한다. 로컬 거부 코드만 고정 문구로 변환하며 원격 예외 내용·식별자를 포함하지 않는다. 일반 예약 입력과 무권한 입력에는 안내를 추가하지 않는다. API 대기 후 소유자 권한을 다시 확인하고, 안내 발신은 작업 실행과 별도 예외 경계에서 한 번만 시도한다. 안내 실패가 probe/bind 재실행이나 저장 결과의 되돌림을 유발하지 않는다.

기존 개발자 시험의 무응답 기대는 인증된 명령에 한해서 새 안내 계약에 맞췄다. 첫 발신 전 예약과 명부/금고 불변 단정은 유지했다. 무권한 및 일반 입력의 무응답 단정은 보강했다. 수락 시험과 검토자의 재현 코드는 수정하지 않았다. 추가 시험은 active/paused 토픽 보존과 삭제, 미전환 토픽 회귀, 제어 결과 구분, 원격 예외 비노출, probe/bind 안내 실패 시 단일 실행을 보호한다.

| 실행 검사 | 실제 결과 | 증거 |
|---|---|---|
| `$HEJO_PYTHON -m pytest gate/tests/test_telegram_comments.py tests/acceptance/test_telegram.py docs/changes/a6291a01-a451-4239-b635-ac5ef2f23e69/logs/review-02/test_review.py -q --basetemp=/tmp/hejo-tgc-task1 -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` | 종료 0, 76개 통과. 기존 68개 + 신규 6개 + 검토 재현 2개 | `logs/task1-check-08.log`, `logs/task1-runs.json` |
| 토픽 제외 조건 제거 / 결과 안내 제거 변이 검사 | 각각 종료 1로 결함 검출, 두 파일 원복 확인 | `logs/task1-check-09.log`, `logs/task1-check-10.log`, `logs/task1-revision-mutations.json` |
| `$HEJO_PYTHON scripts/scan_private.py --home <temporary-home>` 및 `git diff --check` | 둘 다 종료 0, 문서·로그 개인값 패턴 발견 없음. 원복 후 네 파일 해시가 76개 통과 변경본과 일치 | `logs/task1-revision-final-checks.json`, `logs/task1-revision-private.log` |

검증은 임시 HERMES_HOME, 가짜 명부, 대역 Bot API로 수행했다. 위 최초 전체 검사 결과는 이전 변경본의 증거이며 이번 보완 변경본의 전체 서버/앱 검사로 주장하지 않는다. 이번에는 영향 범위인 Telegram 회귀와 정적 검사만 실행했다. 실제 발신·운영 변경·M0·TASK 2~5·커밋·푸시는 미실행이다. 실제 환경 증거 수준 4는 여전히 충족하지 않았으며, TASK 1 재검토 후 별도 승인된 M0와 사람 화면 확인 관문을 유지한다.

최종 상태 확인 중 `app/Sources/ConversationChrome.swift`의 별도 작업 변경이 새로 나타났다. 이 구현자가 수정한 파일이 아니며 이번 검토·검증 대상으로 포함하지 않는다. 변경은 보존했고 커밋/스테이징하지 않았다. 검토 대상은 최종 증거 JSON에 명시한 네 gate 파일로 한정한다.

## TASK 2 진행 경계 — native 댓글 수신

최신 handoff의 TASK 2~4 사용자 승인과 검토 7회차의 M0 핵심 관문 수락에 따라 순차 구현을 시작했다. 위 TASK 1 당시의 후속 승인 대기·M0 미실행 문구는 역사 기록이다. 현재 확인한 저장소 HEAD는 `236b0177468b90d9ea23a1b1190e996db78a0694`이며 검증 대상은 그 위의 미커밋 gate 변경본이다. TASK 1 변경과 타 작업 문서는 보존했다. 이번 단계에서 수정한 제품/시험은 `gate/telegram_comments.py`, `gate/tests/test_telegram_comments.py`다.

활성 연결의 자동 전달만 새 질문으로 받으며 channel origin id를 canonical client id로 사용한다. 개인 소유자의 댓글은 이미 대응된 같은 그룹 답장 또는 검증된 원문 닻을 통해 기존 thread로 연결한다. 두 참조가 충돌하거나 원문·스레드·방이 삭제되면 거부한다. 설정 원문, 활성화 전 원문, 편집, channel_post, 다른 발신자, 익명·수동 전달은 실행하지 않는다. 기존 PTB group 0 소비와 group 99 관측을 유지한다.

기존 sent.jsonl에 v2 input claim을 첨부 다운로드·receive 전에 fsync한다. journal commit 이후 별도 alias를 기록하며 channel/discussion 숫자 id가 같아도 구별한다. 재시작·중복 전달은 이미 실행한 직원 차례를 재실행하지 않는다. journal이 저장됐지만 alias 기록 전 중단된 입력은 같은 원본을 다시 관측할 때 대응만 복원한다. 실패한 claim의 자동 실행 재개는 보장하지 않는다. 중간 레코드 손상이나 충돌 alias는 댓글을 닫는다.

개별 사진·문서는 SDK 다운로드를 owner-only 임시 파일에 받고 20MB 및 기존 FileStore 제한·파일명 검사를 거쳐 stage한다. 미지원 미디어/앨범은 캡션만 실행하지 않는다. 다운로드와 receive 실패·권한 해제에도 임시 파일 및 승격되지 않은 stage를 정리한다. 기존 receive와 journal이 대화 원본이며 새 대화 저장소는 만들지 않았다.

| 검증 | 실제 결과 | 증거 |
|---|---|---|
| `$HEJO_PYTHON -m pytest gate/tests/test_telegram_comments.py tests/acceptance/test_telegram.py docs/changes/a6291a01-a451-4239-b635-ac5ef2f23e69/logs/review-02/test_review.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 99 passed | `logs/tasks234-check-09.log` |
| 다운로드 전 중복 차단 / 개인 소유자 검사 제거 변이 | 각각 종료 1로 검출, 원복 확인. 이후 최종 99개 통과 | `logs/tasks234-check-07.log`, `logs/tasks234-check-08.log`, `logs/tasks234-mutations.json` |
| `$HEJO_PYTHON scripts/scan_private.py --home <temporary-home>` | 종료 0. 환경의 임시 홈을 argv에 전달하는 Python 래퍼 사용 | `logs/tasks234-check-10.log` |

명령·실제 종료 코드·각 실행 시 네 gate 파일 SHA-256은 `logs/tasks234-runs.json`에 있다. 실행기는 임시 HERMES_HOME, 가짜 명부, Bot API 대역만 사용했다. 초기 새 시험의 실패(02~04)는 실제 Hermes 수신이 background task를 생성하는데 시험이 완료 전에 단정한 문제였다. 세션 종료를 제한 시간 내 기다리도록 고쳐 실제 직원 호출 수를 검증했다. 01은 새 수신 시험 추가 전 기존 74개 회귀, 05~06은 중간 변경본의 성공이다.

현재는 TASK 2 경계이며 TASK 3 발신·intent/receipt·불확실 결과 복구와 TASK 4 off/abort·운용 문서·전체 검사·커밋은 아직 남아 있다. TASK 2~4 전체 완료나 최종 검토 반환으로 판정하지 않는다. 다음 실행은 동일 승인으로 TASK 3을 이어간다. 기존 `_send_message`의 댓글 발신 제외는 아직 유지되므로 현재 변경본은 완성된 운영 후보가 아니다. 전체 scripts/test.sh는 마지막 TASK 4에서 실행한다. 이번 단계에서 운영 파일 변경·배포·재시작·실제 bind/발신·TASK 5·커밋·푸시는 하지 않았다.

## TASK 3~4 구현 인계 — 검토 대상 최종 변경본

### 범위·판단·책임

최신 TASK 2~4 승인에 따라 서버 구현과 대역 검증을 마쳤다. 4판 기능 계약은 유지했으며 기획 문서·수락 명세를 수정하지 않았다. M0 수락은 후속 구현 착수 근거이고, 최종 실물 M1~M6의 대체 증거가 아니다. 구현자 판단은 **TASK 2~4 구현·자동 검증 완료 / 전체 기능 실물 수락 미완료**다. 위험도는 고위험, 이번 증거 수준은 대역 통합 2이며 실제 사용 가능 여부는 별도 검토·운영 인계·실물 수락을 거쳐야 한다.

기존 Telegram settled queue가 목적지를 한 번 선택한다. `gate/telegram.py`의 본문·버튼·첨부 표현과 정착 판단을 topic/comments가 공유한다. 댓글 전송과 대응의 소유자는 `gate/telegram_comments.py`이며 별도 서비스·polling·대화 원본을 추가하지 않았다. 앱·wire·Hermes 본체·team-kit은 변경하지 않았다. 하위 에이전트는 사용하지 않았다.

이번 인계의 제품/시험 파일은 `gate/adapter.py`, `gate/telegram.py`, `gate/telegram_comments.py`, `gate/tests/test_telegram_comments.py`, `gate/README.md`다. adapter의 기존 TASK 1 수신 진행 수 추적은 유지했다. 이전 TASK 2 절의 댓글 발신 차단은 이번 구현으로 교체했다.

### 발신·영속성·복구

- 기존 정착·typing·삭제 검사를 거친 글을 해당 원문의 댓글로 보낸다. 앱/직원 시작 스레드는 채널 첫 조각을 만든 뒤 실제 자동 전달 닻을 확인해야 나머지를 보낸다. 4096자 분할, 사진·문서 각각에 같은 thread alias를 남긴다. 모든 댓글은 ReplyParameters의 `allow_sending_without_reply=false`이며 forum thread id나 일반 그룹 글 fallback을 사용하지 않는다.
- 기존 sent.jsonl v2를 input/alias, delivery, forward, topic epoch 기록으로 확장했다. delivery는 operation·조각 번호·상태·대응 id와 본문/파일 조각의 SHA-256 fingerprint만 저장한다. fingerprint는 변한 원문으로 복구하지 않기 위한 비교값이며 본문·파일 내용·실제 chat id를 복제하지 않는다. append/fsync 이전에 외부 호출하지 않는다.
- 발신 의도 뒤 응답 유실·중단·receipt 저장 실패는 자동 재발신하지 않는다. 재시작 후 미완료 intent는 unknown으로 해석·표시한다. 성공한 앞 조각은 재발신하지 않는다. queued와 waiting_anchor는 상태 명령으로 확인할 수 있다. 불확실 원문 전달은 직원 질문으로 실행하지 않고 held 안내를 한다.
- 같은 방의 outbound는 별도 lock으로 직렬화한다. native 수신 lock과 분리했고 자동 전달을 기다릴 때 outbound lock을 유지하지 않는다. 자동 전달이 응답보다 먼저 와도 기존 ledger에 저장한 뒤 응답 id와 연결한다. 이것은 별도 큐 서비스가 아니라 기존 settled queue의 외부 호출 경합 제어다.
- `/hejo_comments_status`는 현재 짝의 소유자에게 현재 짝에 속한 연결/operation만 보여 준다. `/hejo_comments_resolve <operation>`은 실제 봇 댓글/자동 전달 원문에 대한 개인 소유자의 답장과 현재 연결·세대·원문 조각을 확인해 receipt/alias만 복구한다. 대상 재사용·불일치·변경된 원문은 거부한다. 원격 글이 없는 경우 재발신 명령은 없다.

### 전환·해제·보존

route_epochs의 cutover와 현재 epoch별 닻을 사용한다. 전환 이전에 시작한 thread의 새 글은 현재 목적지에서 지정 이어쓰기 표시를 붙이고 새 내용만 보낸다. topic receipt도 기존 sent.jsonl에서 epoch를 구분하며 legacy topic 기록은 그대로 읽는다. 이미 있는 닻 삭제는 새 원문 생성으로 우회하지 않는다.

정상 off는 대기·불확실 발신/실행이 없는 경우만 가능하다. abort는 살아 있는 호출·직원 차례 동안 busy이며, 종료 후 미전송 항목을 cancelled로 기록하고 외부 쌍을 영구 retired 처리한다. 전체 끄기는 queued 조각을 취소하며 나중 켜거나 자동 전달이 도착해도 취소 글을 발신하지 않는다. 짝 해제/교체 후 예약된 외부 입력은 계속 소비하며 이전 연결을 자동 재사용하지 않는다. README에서 실행 전에 영구 은퇴와 새 쌍 필요성을 설명한다. 연결 권한 실패는 paused로 저장하고 기존 topic_problem에도 반영한다.

### 검증·실제 결과

명령·종료 코드·각 실행의 파일 SHA-256은 `logs/tasks234-runs.json`에 기록했다. 임시 HERMES_HOME, 가짜 명부, 실제 gate/PTB dispatcher와 대역 Bot API만 사용했다. 환경 스크립트 source·패키지 설치·실제 API 송신은 하지 않았다.

| 검사 | 실제 결과 | 증거 |
|---|---|---|
| `HEJO_PYTHON="$HEJO_PYTHON" bash scripts/test.sh` (동일 환경의 Python subprocess 래퍼) | 종료 0. 서버 506개, gateway_delivery, Swift/AppKit, 앱 네트워크 fixture 및 설정/다운로드 원상 보존 검사 통과 | `logs/tasks234-check-16.log` |
| 최종 `$HEJO_PYTHON -m pytest gate/tests tests/acceptance docs/changes/a6291a01-a451-4239-b635-ac5ef2f23e69/logs/review-02/test_review.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0. 515 passed, 기존 hub 시험의 async 표시 경고 1개 | `logs/tasks234-check-23.log` |
| 댓글 no-fallback / 봇 root echo / 방별 직렬화 / unknown 재발신 금지 변이 | 각각 종료 1로 검출, 원복 확인. 이후 최종 서버 전체 515개 통과 | `logs/tasks234-check-19.log`~`22.log`, `logs/tasks34-mutations.json` |

전체 스크립트 이후 자체 점검에서 방 안의 동시 스레드 발신이 서로의 intent를 보고 queued로 남을 수 있는 경계를 확인했다. 방별 outbound 직렬화와 관련 회귀를 보완하고, 발신 도중 짝 해제/끄기의 후속 조각 차단 및 새 짝의 과거 operation 조회 차단도 확인했다. 이후 제품 최종 상태로 서버 전체를 다시 검사했다. 앱 코드는 전후 동일하므로 이미 통과한 Swift/AppKit 검사는 반복하지 않았다. 전체 스크립트의 앱 검색 시험이 오래 걸렸지만 정상 종료했고, 시간을 이유로 종료하거나 건너뛰지 않았다. 기존 Swift 경고와 시스템 UI 진단은 이번 범위 밖이며 로그에 보존했다.

새 시험은 두 질문·두 binding의 같은 숫자 id 격리, 댓글/첨부 alias, early/late forward, 긴 글 부분 실패, receipt fsync 실패와 재시작, resolve 대상 불일치/중복, 실제 네트워크 호출 중 abort busy, 정상 off와 abort의 영구 은퇴, 끄기와 취소 조각, bind/off/새 bind의 epoch별 이어쓰기, 닻 삭제, native 재등록, typing/버튼/첨부 소유권 및 새 짝 상태 격리를 보호한다. 기존 수락 시험·검토 재현 코드는 변경하지 않았다.

공개 검사와 최종 범위/해시 증거는 `logs/tasks34-final-checks.json`을 참조한다. 격리 인덱스 전체 diff 검사에서는 보관한 원문 compiler/pytest 로그의 행 끝 공백만 지적됐다(`logs/tasks34-index-check.log`, 종료 2). 과거 검증 로그의 원문은 수정하지 않았다. 제품·문서·시험·JSON을 대상으로 한 diff 검사는 별도로 수행한다. 검사 기준이나 예외 설정을 바꾸지 않는다.

### 검토 대상·미실행·남은 위험

기준 HEAD는 `236b0177468b90d9ea23a1b1190e996db78a0694`다. TASK 4 후보는 별도 Git 인덱스로 작성하는 로컬 `hejo-telegram-comments-task234` 브랜치이며 정확한 전체 커밋은 최종 인계 상태와 `logs/tasks34-commit.json`에 기록한다. 커밋 후 생성하는 tasks34-commit.json은 순환 참조를 피하기 위한 로컬 후속 증거이며 해당 커밋에는 포함하지 않는다. 공유 HEAD/인덱스와 타 작업 파일을 바꾸지 않는다. 커밋 차이는 위 다섯 gate 파일, 이 작업의 계획/구현/검토 증거 문서, 기존 수락 명세로 한정한다. 부모에 이미 들어 있는 타 작업 앱 변경을 이번 변경으로 주장하지 않는다.

운영 M0 후보 갱신·배포·gateway 재시작·실제 bind·추가 실물 메시지·TASK 5·푸시는 **미실행**이다. 최종 실물 UI 수락, 운영 환경에서의 미디어/실패 복구는 아직 검증되지 않았다. journal commit 뒤 직원 실행 중 중단은 중복을 피하지만 자동 재개를 보장하지 않는다. 원격 exactly-once를 주장하지 않는다. 불확실 결과에 대응할 실제 게시물을 찾지 못하거나 원문이 바뀌었다면 자동 재발신 대신 명시적 abort가 필요하다.

검토자는 특히 native 수신과 outbound lock의 분리, early forward/receipt 순서, 불확실 조각 복구 및 취소, route epoch와 예전 thread의 새 닻, 새 짝의 상태/입력 격리를 확인해야 한다. 범위 밖 앱 검색 계산 비용은 관찰만 했으며 앱 수정은 하지 않았다. 기능 목표나 책임 배치를 바꾸는 설계 변경은 없다.
