# HEJO-SLACK-MOVE 설계

1판 · 2026-11-21 · 상태: 초안(계획 검증 대기). 명세 [spec.md](spec.md), 작업 [tasks.md](tasks.md), 수락 시험 [HEJO-SLACK-MOVE.md](../../../tests/acceptance/HEJO-SLACK-MOVE.md). 약어는 spec 머리말과 같다.

칸·원본·쓰기 주체·수명은 [spec 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

## 1. 흐름: 전과 후

전

```text
예약 보고 ── 게이트웨이 ── Slack 문 ── Slack 채널
밖 프로그램(인스타·뉴스·학습 보고 등) ── Slack API 직접 ── Slack 채널
사장 답글(Slack 스레드) ── Slack 문 ── 안내원 ── 직원 / team-kit 훅
```

후

```text
예약 보고 ── 게이트웨이 ── hejo 문 ── 방 또는 1:1
밖 프로그램 ── team-kit 공통 전송 ── hejo 문의 서버 안 입구 ── 방 또는 1:1
사장 답글(hejo 스레드) ── hejo 문(스레드 주인) ── 직원 / team-kit 훅
Slack 문: 연결만 유지. 사장이 Slack에서 말을 걸 때만 답한다
```

책임은 하나씩이다. 글을 기록장에 쓰는 것은 문, 어느 문으로 보낼지 정하는 것은 지시서 값 하나, 받을 곳 값은 금고, 보내는 코드는 team-kit 공통 전송 한 곳이다.

## 2. 결정과 대안

| 결정 | 채택 | 기각한 대안과 이유 |
|---|---|---|
| 밖 프로그램이 hejo로 보내는 길 | 문의 Unix 소켓 입구(사장 결정) | 예약 전달만 쓰기: 글 고치기·버튼이 안 돼 승인 흐름을 못 옮김. 루프백 포트 + 토큰 파일: 같은 사용자 권한이라 보호 수준은 같고 포트·토큰이라는 관리 대상만 늘어남. 기록장 직접 쓰기: 문 단독 쓰기 원칙 위반 |
| 전환 스위치 | 지시서 `delivery.platform` 한 값 | 파일마다 설정: 빠뜨리기 쉽고 되돌리기가 여러 곳. 코드에서 Slack 경로 삭제: Slack을 비상 통로로 남긴다는 결정과 어긋남 |
| 스레드 주인 | 문이 기록장에서 계산(저장하지 않음) | team-kit 안내원을 hejo에 붙이기: hejo 이벤트는 안내원을 타지 않으며 붙이면 답할 직원을 정하는 곳이 둘이 됨. 주인 표를 따로 저장: 두 번째 원본 |
| 방 만들기 | 입구의 방 만들기(문의 기존 검사 재사용) | 사장이 앱에서 손으로 5개: 구성원 실수 위험, 대응표를 따로 적어야 함. CLI가 기록장에 직접 쓰기: 문 단독 쓰기 위반 |
| 재시작 알림 | 재시작·온라인 알림 끄기(사장 결정) | 문이 본체 내부 값 읽어 지우기: 플랫폼 플러그인 계약 밖 |

두 경로(Slack·hejo)의 공존은 사장 결정(Slack을 비상 통로로 유지)에 따른 것이다. 권위 경로는 `delivery.platform` 값 하나가 정하고, 한 번의 전송은 한 문으로만 간다(둘 다 보내지 않음). 종료 조건은 사장이 Slack 문을 끄기로 정할 때이며 이 작업 범위 밖이다.

## 3. 문

### 3.1 서버 안 전용 입구 (REQ-SM-01)

- 문의 기본 프로필 어댑터가 시작할 때 Unix 소켓 `<HOME>/hejo/post.sock`을 연다. 소켓 파일 권한 0600, 폴더는 기존 금고 폴더 권한을 따른다. 이미 파일이 있으면 살아 있는 문이 없는지 확인하고 지운 뒤 연다. 끝날 때 지운다. 네트워크 주소에는 이 경로를 등록하지 않는다.
- 인증은 파일 권한이다. 같은 서버 사용자 계정의 프로그램만 쓸 수 있고 토큰은 없다. 근거: 이 프로그램들은 이미 같은 계정으로 모든 직원 홈을 읽고 쓴다. 입구가 새로 주는 권한은 "직원 이름으로 hejo에 글 올리기"뿐이고 사장 글은 만들 수 없다.
- 규격 원본은 `schemas/hejo-local-v1.json`이다. HTTP + JSON, 소켓 위에서만.

| 동작 | 요청 | 응답 | 문 안에서 부르는 것 |
|---|---|---|---|
| 글 올리기 | `POST /local/v1/messages` `{employee, room?, thread?, text, buttons?, checklist?, reply_state?, images?}` | `{msg_id, thread}` | `send` |
| 글 고치기 | `PATCH /local/v1/messages/{msg_id}` `{employee, text?, buttons?, reply_state?}` | `{msg_id}` | `edit_message`, `set_reply_state` |
| 글 지우기 | `DELETE /local/v1/messages/{msg_id}` `{employee}` | `{}` | `delete_message` |
| 스레드 읽기 | `GET /local/v1/threads/{thread}` `?employee=` 또는 `?room=`, `&after=<순번>` | `{messages:[{msg_id, seq, role, employee, text, ts, reply_state}]}` | 기록장 읽기 |
| 방 만들기 | `POST /local/v1/rooms` `{title, members, lead}` | `{room, created}` | 방 저장(기존 검사) |

- `room`이 없으면 그 직원의 1:1이다. `buttons`·`checklist`·`reply_state`는 team-kit이 게이트웨이 안에서 `send`에 넘기는 `hejo_buttons`·`hejo_checklist`·`hejo_reply_state` 메타와 같은 모양이고, 입구는 이 허용 목록만 통과시킨다. 그래서 버튼 누름은 기존 누름 처리기(`register_click_handler("reply")`)로 간다.
- `images`는 서버의 그림 파일 경로 목록이고 문의 기존 그림 저장·등록 경로(`send_image_file`과 같은 한도·형식 검사)를 탄다.
- 고치기·지우기는 그 글을 쓴 직원이 `employee`와 같을 때만 된다(`message_not_found`).
- 방 만들기는 같은 제목의 살아 있는 방이 있으면 만들지 않고 그 id와 `created: false`를 준다.
- 오류는 `{error: <이름>}`과 4xx다. 이름은 문의 기존 값(`unknown_employee`, `room_not_found`, `room_member_required`, `room_deleted`, `thread_deleted`, `message_not_found`, `invalid_room`, `invalid_frame`, `journal_write_failed`)을 쓴다.
- 입구로 올린 글의 기록장 내부 메타에 출처 표시 하나를 남긴다(앱에 나가지 않음). 레코드 종류와 `hejo-wire-v1`은 그대로다.
- 소비자: team-kit 공통 전송(4.1)과 전환 도우미(7절). 그 밖의 소비자는 없다.

### 3.2 예약 보고의 방 대상 (REQ-SM-02)

- `parse_target`이 `room:<방 id>`도 받는다. 방 id 문법은 문이 방을 만들 때 쓰는 id 문법과 같다(경로 구분자 없음). 결과는 `("room:<id>", None)`이다.
- 전달자 어댑터는 이미 `room:` 대상을 그대로 넘기고 자기 직원을 글쓴이로 붙인다(`adapter.py:109`). `send`가 구성원 검사를 한다(`room_member_required`). 새 코드는 문법뿐이다.

### 3.3 방 스레드 주인 (REQ-SM-03)

- `recipients`의 순서를 이렇게 바꾼다: ① 글에 `@이름`이 있으면 그 직원들(지금과 같음) ② 없고 기존 스레드면 그 스레드의 주인 ③ 없으면 대표 직원.
- 주인은 기록장에서 계산한다. 스레드의 첫 글이 직원 글이면 그 직원 하나, 사장 글이면 그 글을 받은 직원들(내부 메타 `recipients`)이다. 저장하지 않는다.
- 주인 중 지금 방 구성원이고 명부에 있는 직원만 남긴다. 아무도 안 남으면 대표 직원이다.
- 앱이 받는 직원을 직접 고른 글(`targeted`)과 1:1은 그대로다.
- [가정] Slack은 다른 직원을 부른 뒤 주인이 바뀌는지를 안내원 내부 판단으로 정한다. hejo는 "부른 글에만 그 직원이 답하고 주인은 그대로"로 고정한다. 계획 검증에서 이견이 있으면 이 줄을 고친다.

### 3.4 방 5개 (REQ-SM-04)

방은 전환 때 입구의 방 만들기로 만든다(7절). 이름·구성원은 서버 설정에서 읽고, 대표 직원은 사장이 확인한 표의 값을 쓴다. 만든 방 id는 금고 `hejo.rooms.<Slack 채널 id>`에 적는다. 이 대응은 금고에만 있다.

## 4. team-kit

### 4.1 스위치·받을 곳·공통 전송 (REQ-SM-05)

- 지시서 `delivery.platform`(`slack` 기본, `hejo`)을 읽는 함수는 team-kit에 하나만 둔다.
- 받을 곳은 직책 키로 푼다. Slack 값은 기존 자리 그대로, hejo 값은 금고 `hejo.*`에 같은 키 이름으로 둔다. 값 형식은 `<직원 id>`(그 직원과의 1:1) 또는 `room:<방 id>`다.

| 직책 키 | 지금 Slack 값이 있는 곳 | hejo 값 |
|---|---|---|
| 보고 받을 곳 | 금고 `channels.reports`, 설정 `report_channel` | 금고 `hejo.channels.reports`, `hejo.report_channel` |
| 학습 보고 받을 곳 | 설정 `learning_report_channel` | 금고 `hejo.learning_report_channel` |
| 고객 방·업무 방 | 금고 `channels.customer_room`·`channels.work_room` | 금고 `hejo.channels.*` 같은 이름 |
| 진단 직원 DM·개인 비서 DM | 금고 `dms.doctor`·`dms.personal` | 금고 `hejo.dms.*`(그 직원 id) |
| 사장 DM(받을 곳이 없을 때의 기본) | Slack에서 DM 열기 | 보내는 직원과의 1:1 |
| 인스타·인스타 요약·네이버톡 | 코드 상수, 플러그인 설정, 다리 설정 파일 | 금고 `hejo.channels.instagram`·`instagram_digest`·`naver_talk` |

- 공통 전송은 "올리기·고치기·지우기·스레드 읽기·그림 붙이기" 다섯 동작을 가진 한 곳이다. `slack`이면 지금 함수가 하던 Slack 호출을 그대로 하고, `hejo`이면 입구를 부른다. 지금의 Slack 모양 함수(`TS/learning_report.py` `slack`·`upload_image`·`update_message`)를 부르던 곳과 독립 전송 7곳이 모두 이 한 곳을 부르게 옮긴다. 함수 이름·배치는 구현 담당이 정한다.
- 반환하는 식별자는 문에 따라 다르다(Slack은 채널+ts, hejo는 글 id+스레드 id). 상태 파일에 저장하는 곳은 항목마다 문 이름을 함께 적는다(REQ-SM-05.AC-05). 문 이름이 없는 옛 항목은 Slack 것으로 본다.
- `hejo`일 때 Slack 쓰기 함수가 불리면 예외를 낸다(조용히 보내지 않음). 시험이 이것으로 0건을 확인한다.
- 문이 없으면(소켓 없음·거절) 전송 실패를 그대로 올려 각 프로그램의 기존 실패 경로를 타게 한다. 새 재시도 큐는 만들지 않는다.

### 4.2 직접 전송 경로 전수 표 (REQ-SM-07, 대조표의 바탕)

[조사 보고] 줄 번호는 `HD` `66f2a44c` 기준이며 구현 착수 때 다시 확인한다. "공통"은 지금 공통 전송 함수를 쓰는 곳, "독립"은 자기 HTTP 호출을 가진 곳이다.

| 파일 | 보내는 것 | 지금 받을 곳(직책 키) | 실행 주체 | 종류 | hejo 받을 곳 |
|---|---|---|---|---|---|
| `TS/error_digest.py` | 예약 오류 요약 | 진단 직원 DM | 예약 | 공통 | 진단 직원 1:1 |
| `TS/eventkit_stall_watch.py` | 멈춤 경고 | 진단 직원 DM | 예약 | 공통 | 진단 직원 1:1 |
| `TS/doctor.py` | 매일 점검 | 진단 직원 DM | 예약(꺼짐)·야간 일괄 | 공통 | 진단 직원 1:1 |
| `TS/morning_system.py` | 아침 시스템 보고, 보류 글 일괄 | 진단 직원 DM, 보류 글의 저장 채널 | 예약 | 공통 | 진단 직원 1:1 |
| `TS/org_review.py` | 조직개편안 스레드·상태·답글 읽기 | 설정 채널, 기본 진단 직원 DM | 예약 | 공통 | 진단 직원 1:1 |
| `TS/starter_plugins.py` | 스타터 플러그인 보고·상태 | 보고 받을 곳 | 아침 시스템 보고가 부름 | 공통 | 보고 받을 곳 |
| `TS/paseo_autofix.py` | 자동수정 진행 답글·상태 | 작업에 저장된 스레드 | 상주 | 공통 | 같은 스레드(문 표시 따름) |
| `TS/personal_mail_summary.py` | 개인 메일 요약 | 보고 받을 곳, 없으면 개인 비서 DM | 예약 | 공통 | 보고 받을 곳 |
| `TS/learning_report.py` | 아침 학습 보고·검토 반영·그림 | 학습 보고 받을 곳, 없으면 사장 DM | 상주 | 공통(본체) | 학습 보고 받을 곳 |
| `TS/skill_report.py` | 스킬 보고 스레드 | 학습 보고 받을 곳 | 상주 | 공통 | 학습 보고 받을 곳 |
| `TS/ai_digest.py` | AI 소식 요약 스레드 | 보고 받을 곳 | 상주 | 공통 | 보고 받을 곳 |
| `TS/report_review.py` | 보고 검토 결과 답글 | 들어온 스레드 | 훅 | 공통 | 들어온 스레드 |
| `TS/vault_backup_approval.py` | 금고 백업 승인 답글·질문 고치기 | 들어온 스레드 | 훅 | 공통 | 들어온 스레드 |
| `TKL/hermes_packs/cctv/watch.py`, `now.py` | CCTV 경고·제안·그림 | 고객 방 | 예약 | 공통 | 고객 방 |
| `TKL/hermes_packs/linked_work/slack_report.py`와 그 호출자 | 완료 동기화·충돌·연결 결정 보고 | 보고 받을 곳, 없으면 사장 DM | 예약 | 공통 | 보고 받을 곳 |
| `TKL/hermes_packs/linked_work/work_scope_backfill.py` | 분류 완료 보고 | 보고 받을 곳 | 수동 | 공통 | 보고 받을 곳 |
| `TKL/hermes_governance/proposal_decisions.py` | 승인·거절 버튼 달린 제안 | 호출자가 준 곳 | CCTV | 전송 함수를 받음 | 호출자가 준 곳 |
| `TKL/hermes_packs/diagnosis/diagnosis_requests.py` | 진단 결과(요청 스레드 + 보고) | 요청 스레드, 보고 받을 곳 | 도구가 띄운 프로그램 | 독립 | 요청 스레드, 보고 받을 곳 |
| `TS/news_watch.py` | 뉴스 알림 | 보고 받을 곳, 없으면 사장 DM | 상주 | 독립 | 보고 받을 곳 |
| `TS/deadline_watch.py` | 마감 알림·버튼·상태 | 보고 받을 곳 | 도구 | 독립 | 보고 받을 곳 |
| `TKL/hermes_packs/files_docs/files.py` | `file_link` 파일 올리기 | 지금 대화 스레드 | 도구 | 독립 | 지금 대화 스레드(문 첨부) |
| `CP/plugins/instagram-dm/watch.py`, `feed_runner.py`, `learning_report.py` | 5절 | 코드 상수·플러그인 설정 | 상주 | 독립 | 5절 |
| `CP/scripts/naver-talk/bridge.py` | 5절 | 다리 설정 파일 | 상주 | 독립 | 5절 |
| 진단 직원 스크립트 `channel_autojoin.py` | 공개 채널 가입 | — | 예약 | 독립 | 옮기지 않음. 전환 때 예약을 끔 |

조사 보고가 확인하지 못한 곳은 구현 착수 때 같은 표에 줄을 더한다: 야간 일괄(`night_batch`), 빈틈 검토(`gap_review`), 기억 정리(`memory_tidy`), 금고 백업의 첫 질문을 올리는 곳, `hermes_reply/reply_buttons.py`의 글 고치기 경로. 표에 없는 Slack 쓰기를 찾으면 같은 규칙으로 옮기고 보고에 적는다. 다른 저장소나 본체에 있으면 멈추고 보고한다.

읽기만 하는 곳(`slack_read.py`, `diagnosis.py`, `connection_checks.py`, 사진 내보내기 스크립트)은 그대로 둔다.

### 4.3 Slack 꾸밈의 hejo 대응 (REQ-SM-05.AC-06)

| Slack | hejo |
|---|---|
| 스레드(첫 글의 ts에 답글) | 스레드 id에 글 올리기 |
| 답글을 채널에도 보이기 | 쓰지 않음(스레드 글만) |
| 글 고치기 | 글 고치기 |
| 색 막대·상태 이모지 제목(대기·처리 중·완료·실패) | 답장 상태(`reply_state`의 기존 값) |
| 버튼 블록 | `buttons` |
| 체크 목록 | `checklist` |
| 사장 멘션(알림 울리기) | 쓰지 않음(hejo는 직원 글이면 알린다) |
| 구획 블록·굵은 제목 | 글 그대로(문의 글 표시 규칙) |
| 그림 올리기 | `images` |
| 스레드 주소 링크 | 쓰지 않음. 글에 넣던 링크 줄은 뺀다 |
| 글에 숨긴 복구용 자료(metadata) | 상태 파일의 글 id·스레드 id |

### 4.4 들어오는 규칙의 hejo 대응 (REQ-SM-08)

hejo 이벤트는 플랫폼 `hejo`, 사용자 `owner`, 대화 id는 직원 id 또는 `room:<id>`, 스레드 id가 있다. 사장 확인은 기존 `hermes_owner_chat`의 hejo 분기를 쓴다.

| 규칙 | 지금 hejo에서 | 바꿀 것 | 근거 |
|---|---|---|---|
| 예약 관리 도구 | 거절 | 사장의 hejo 대화도 허용. 허용 대상을 `delivery.platform`에 맞춰 `local` + 보고 받을 곳으로 | [확인] `TS/cron_guard.py:43,141,168` |
| 금고 백업 승인 | 건너뜀 | 질문 올리기와 답장 처리를 공통 전송·hejo 이벤트로 | [조사 보고] `TS/vault_backup_approval.py:148,241-285` |
| 진단 사용량 조회 | 오류 | hejo 스레드의 글 순서로 이전 요청을 찾음 | [조사 보고] `TKL/hermes_packs/native_tools/__init__.py:61-82` |
| 진단 요청 접수 | Slack만 | hejo 대화에서도 접수, 결과는 4.2 | [조사 보고] `diagnosis_requests.py:236` |
| 보고 검토·스타터·조직개편안 답글 | 건너뜀 | hejo 스레드의 사장 글·버튼 누름으로 처리 | [조사 보고] `TS/report_review.py:279` 등 |
| 일 넘기기 안내·프로젝트 허브 | 건너뜀 | 4.5 | [조사 보고] `TS/project_referral.py:48`, `TKL/hermes_router/project_threads.py:24` |
| 대기 작업 결과 | 1:1은 됨 | 방에서 대기를 만든 직원 이름으로 오는지 시험으로 확인하고, 아니면 고침 | [조사 보고] `TS/wait_jobs.py:267-305` |

### 4.5 일 넘기기(프로젝트 허브) — 미확정

Slack 채널·스레드·안내원을 전제로 한 흐름이고(`project_work.py`, `project_channel.py`, `project_threads.py`, `project_alerts.py`), hejo는 안내원을 타지 않는다. 계획 담당이 이 흐름을 끝까지 읽은 뒤 이 절과 REQ-SM-08.AC-05를 보완한다(tasks TASK-09a). 그 전에는 TASK-09를 시작하지 않는다. 다른 작업은 이 절에 기대지 않는다.

### 4.6 도구 묶음 (REQ-SM-09)

- 조립기(`TKL/hermes_facility/config_assembly.py`)가 `platform_toolsets.hejo`를 Slack 목록에서 만든다. Slack 기본 묶음 이름은 hejo 기본 묶음 이름으로 바꾼다. 앱 설치 때 플러그인 묶음을 더하는 곳(같은 파일 92줄 근처)에 hejo를 넣는다.
- [미실행] hejo 기본 묶음은 본체의 핵심 도구 전부를 포함하므로, Slack 목록에 Slack 기본 묶음이 없던 프로필에는 hejo 기본 묶음도 넣지 않는다. 실제 켜진 도구 집합 비교(AT-SM-71)가 최종 기준이다. 맞출 수 없으면 멈추고 보고한다.

## 5. 인스타·네이버톡 (REQ-SM-06)

- 바뀌는 것은 화면 부분뿐이다. 받은함 읽기, 자동 초안 실행, 인스타·네이버 전송, 자동 전송 판정, 학습은 그대로다.
- 감시 프로그램의 Slack 호출 세 함수(올리기·읽기·고치기)를 공통 전송으로 바꾼다. 받을 곳은 금고 `hejo.channels.instagram`(방)이고 글쓴 직원은 고객 응대 직원이다. 코드 상수(채널, 멘션 대상, 작업 공간 주소)는 지운다. Slack일 때 값은 금고의 기존 자리나 플러그인 설정에서 읽는다.
- 고객별 스레드: 상태 파일의 스레드 항목에 문 이름을 적는다. hejo로 바뀐 뒤 처음 오는 글에서 그 고객의 hejo 스레드를 새로 만들고 이후 그 스레드를 쓴다.
- 승인 판정(`_thread_verdict`): 승인 글 바로 앞 글을 hejo 스레드 읽기로 가져온다. "앞 글이 직원 글이고 그 초안 글 id와 같으면 `send`, 초안 내용을 그대로 보여 준 다른 직원 글이면 `send`, 사장 글이면 `ask`, 그 밖은 `show`/`ask`"라는 지금 규칙을 그대로 둔다. Slack의 `bot_id` 검사는 hejo의 `role == employee`다.
- 승인 훅(`_approval_in_dm_thread`)과 문맥 훅(`_human_turn_notes`): 플랫폼 `hejo`, 대화 id가 인스타 방, 사용자 `owner`일 때 동작한다. 스레드 주인 규칙(3.3)으로 그 스레드의 사장 글은 고객 응대 직원에게 간다.
- 모델이 그 스레드에 썼는지 보는 조회(`_answered_since`)는 hejo 대화 id·스레드 id로 한다.
- 버튼: 기존 답장 버튼 묶음을 hejo `buttons`로 올리고, 누름은 문의 누름 처리기 → team-kit 답장 버튼 처리(`hermes_reply`의 hejo 설치)로 온다. 제안 버튼(`proposal_decisions`)의 hejo 누름에는 글 id가 따로 없다는 기존 주석(`:293`)이 있으므로 구현 착수 때 이 경로를 먼저 읽고, 맞지 않으면 멈추고 보고한다.
- 네이버톡 다리: 같은 방식. 받을 곳은 금고 `hejo.channels.naver_talk`. 다리의 Slack 함수와 스레드 답글 읽기를 공통 전송으로 바꾼다.
- 고객 응대 직원의 hejo 도구 목록에 인스타 도구 묶음이 들어간다(4.6으로 자동 충족).

## 6. 기존 경로 판정

| 경로 | 판정 | 내용 |
|---|---|---|
| 문의 앱 연결·첨부·사진 입구 | 유지 | 바꾸지 않음 |
| 문의 `recipients` | 교체 | 주인 단계 추가. 호출부는 `receive` 한 곳 |
| 문의 `parse_target` | 교체 | 방 문법 추가 |
| team-kit Slack 모양 공통 전송 함수와 독립 전송 7곳 | 통합 | 공통 전송 한 곳으로. 옛 함수는 같은 변경에서 지우거나 공통 전송의 Slack 쪽 구현으로만 남김(밖에서 직접 부르는 곳 0) |
| 받을 곳 풀이(설정·금고·상수에 흩어짐) | 통합 | 직책 키 풀이 한 곳. 인스타 상수 제거 |
| Slack 문과 Slack 쪽 team-kit 규칙 | 유지 | 비상 통로. 종료 조건은 범위 밖 |
| 공개 채널 자동 가입 예약 | 유지(끔) | 코드는 두고 전환 때 예약만 끔 |
| 재시작·온라인 알림 | 유지(끔) | 설정에서 종류만 뺌 |

## 7. 전환과 되돌리기 (REQ-SM-11)

절차의 틀은 [HEJO-CONNECTIONS design 7.1·7.2](../HEJO-CONNECTIONS-20261120/design.md#71-team-kit은-운영-원본을-고치지-않고-만든다-pr-03-반영)를 따른다. 만드는 동안 운영 원본은 고치지 않고(`HD` 임시 worktree, sha256 기준 확인), 운영 동작은 전환 전까지 그대로다.

전환 전(코드만 적용, 동작 불변)

1. team-kit·직원 플러그인·문을 적용한다. `delivery.platform`이 없으므로 모든 전송은 여전히 Slack으로 간다. 이 상태에서 하루 이상 Slack 보고가 평소대로 오는지 본다(회귀 확인).
2. 전수 대조표와 방 표(이름·구성원·대표 직원)를 만들어 사장이 확인한다.

전환(사장이 자리에 있을 때, 진행 중 턴 0, 승인 대기 0)

1. 지시서·금고·`config.yaml`·각 프로필 `cron/jobs.json`의 보관본을 0700 임시 폴더에 두고 경로와 sha256을 기록한다.
2. 입구로 방 5개를 만들고 금고 `hejo.*` 값을 쓴다.
3. 지시서: `delivery.platform: hejo`, 예약 보고의 받을 곳을 hejo 대상으로, 자동 가입 예약 끔. `config.yaml`: 시스템 알림을 hejo로, 재시작·온라인 종류 제거.
4. 조립기를 돌리고 게이트웨이를 재시작하고 상주 프로그램을 다시 띄운다.
5. 확인: 문 연결, 입구 응답, 직책 키마다 시험 글 한 줄(사장이 hejo에서 봄), 예약 보고 하나 수동 실행, 인스타는 가짜가 아닌 실제 받은함의 다음 DM을 사장과 함께 본다(보내기는 사장이 승인할 때만).

되돌리기: 보관본 복원 → 조립 → 재시작 → Slack으로 예약 보고 하나와 직접 전송 하나 확인. 만든 방과 hejo 글은 지우지 않는다(공용 창고 보존). 복구 조건: 재시작 뒤 문이 연결되지 않음, 입구 무응답, 직책 키 시험 글이 하나라도 안 옴, 인스타 새 DM이 10분 안에 안 올라옴.

전환 뒤: 다음 날 같은 시각까지 Slack 새 글 0건과 대조표 줄마다 hejo 도착을 확인한다.

## 8. 시스템 알림 (REQ-SM-10)

`gateway.system_notifications`의 `platform`을 `hejo`, `chat_id`를 시스템 보고를 맡은 직원 id, `profile`을 그 직원으로 하고 `events`에서 `gateway_restart`·`gateway_online`을 뺀다. 본체는 지정 플랫폼 어댑터의 `send`를 부르므로 코드 변경이 없다. `restart_quiet_seconds`는 hejo에서 쓰이지 않는다.
