# HEJO-TELEGRAM-COMMENTS 수락 시험 5판

요구 원본: [spec](../../docs/changes/HEJO-TELEGRAM-COMMENTS-20261123/spec.md). 기대값은 이 요구와 공식 Telegram/PTB 계약에서 가져온다. 구현의 내부 함수·상수를 답으로 복제하지 않는다.

상태: **5판 시험 명세 / 변경된 시나리오 미실행 / 독립 계획 재검토 대기**. 아래 모든 자동 시험은 임시 HERMES_HOME, 가짜 명부·사장·채널·그룹, 실제 gate와 실제 PTB dispatcher/메시지 객체를 사용한다. Bot API transport만 대역이며 소켓·실제 Telegram 요청은 차단한다. 이름만 모방한 handler 호출로 dispatcher 통합을 대신하지 않는다.

표의 AC는 `REQ-HTC-<번호>.AC-<번호>` 형식이다. N은 `NFR-HTC-01`이다.

| TEST | AC | 입력·관측 가능한 기대 결과 | TASK |
|---|---|---|---|
| T01 | 01.01 | 짝 사장의 목록 명령에 실제 1:1 방 목록, 타 계정·sender_chat·짝 없음에는 목록/금고 변경 없음 | 1 |
| T02 | 01.02 | 두 사람 방을 같은 공용 쌍에 원자 bind. 같은 목록은 idempotent, 목록 변경/두 번째 쌍은 거부. 방 수 증가에도 외부 쌍은 하나. | H1~H4 |
| T03 | 01.03 | 공개·forum·linked_chat 불일치·owner 불일치·다른 human/bot 관리자·대체 API endpoint·양쪽 중 한쪽 봇 관리자 누락·권한 부족·API 실패 각각 금고와 기존 목적지 불변 | 1 |
| T04 | 01.04 | 종료된 기록만 있으면 bind 성공, 진행/불확실 작업이면 busy. 토픽 수신과 sync 유지, 본문 미러 중지, 비참여/단체방 정상, 과거 재전송 0. | H1~H4 |
| T05 | 02.01 | 참여 토픽 새 글은 질문 1개/직원 호출 1회, 같은 토픽 원문/카드 답장은 같은 thread. channel_post·수동 채널 글·자동 전달은 질문 호출 0, 알려진 bot receipt의 닻만 등록. | H1~H4 |
| T06 | 02.02 | root 댓글, 직원 답장에 댓글, 파일 댓글, 댓글창 raw thread-only 글이 같은 스레드. 두 질문을 번갈아 넣어 서로 분리 | 2 |
| T07 | 02.03 | 타 계정·익명·수동 forward·origin 불일치·교차 채팅 reply·unknown root·edited update: journal/직원 호출/기본 handler 호출 0 | 2 |
| T08 | 02.04 | 텍스트·단일 사진/문서 성공과 본문/캡션 일치. 초과 파일·다운로드 실패·미지원 미디어·앨범은 부분 실행 0, 임시 파일 정리·거부 안내 | 2 |
| T09 | 02.05 | bind 뒤 creator/관리자/linked chat/봇 권한 변경 및 getChat 오류. 다음 입력/발신은 정지, 외부 본문 전송 0. 서명 위조로 통과 불가 | 1,2,3 |
| T10 | 03.01 | 두 사람 각각 질문 두 개: 답변/앱 후속/첨부는 각 댓글에만. 수신한 댓글 재미러 0, 토픽 후속은 댓글에 1번. 토픽 본문 답변과 추가 채널 root 0. | H1~H4 |
| T11 | 03.02 | 토픽/앱/직원 시작 각각 root와 올바른 사람 토픽 카드 1개. 자동 전달 선후 경합 모두 호출 0. 답변마다 카드 추가 0, root-first 결과-first 모두 원 질문이 root. | H1~H4 |
| T12 | 03.03 | 기존 settled/typing/삭제 규칙과 접두·버튼 안내·소유권 회귀. 긴 글은 4096자 내 조각, 모든 조각/파일에 답장하면 같은 thread | 3 |
| T13 | 03.04 | Bot API가 root 없음·권한 실패를 반환. message_thread_id 없음, allow_sending_without_reply=false. plain send/다른 topic fallback 0. 성공한 앞 조각은 중복 전송 0 | 3 |
| T14 | 04.01 | 동일 공유 그룹에서 두 방·여러 질문 병렬, forum/channel/discussion의 같은 message id, 중복 update/재시작: 올바른 room/thread, 파일/호출 중복 0. | H1~H4 |
| T15 | 04.02 | fault injection: intent fsync 직후, 원격 성공 응답 손실, receipt fsync 실패, anchor 전후 중단. 재시작 뒤 unknown 보존, 자동 재발신 0·봇 root의 사장 실행 0. early forward도 유실/오분류 없음 | 3 |
| T16 | 04.03 | 기존 topic 레코드만/혼합 v2/끝 불완전 줄/중간 손상/미지원 버전. 기존 topic 호환, 손상 댓글 닫힘, 원본 journal 불변 | 1,3 |
| T17 | 04.04 | 사장 reply+resolve 성공, 다른 대상/다른 operation/중복 복구 거부. unresolved abort는 살아 있는 실행 동안 busy, 종료 후 retired+cancelled. 늦은 forward 실행 0, 취소 글 재발신 0, 짝 교체 이후에도 같은 은퇴 대상 rebind 거부 | 3,4 |
| T18 | 05.01 | off는 모든 참여 방에 원자 적용. busy 중 일부만 전환 0, 안전한 경계에 토픽 본문 복귀, 기록/첨부 불변, 삭제 API와 보류 재전송 0. | H1~H4 |
| T19 | 05.02 | 앱 끄기/해제/재짝 및 재시작: 신규 댓글 실행·전송 0, 예약 대상 기본 handler 호출 0, 새 짝이 옛 연결 자동 사용 0, 시간 경과·재시작·해제 뒤 예약 지속, release 명령 없음 | 4 |
| T20 | N.01 | 변경 목록에 app·wire·본체·team-kit 없음. 0600 확인, 가짜 민감값 sentinel을 로그/오류/앱 프레임/금고 밖 파일에서 검사. 실제 비밀 입력을 읽지 않음 | 4 |
| T21 | N.02 | 실제 PTB 그룹 우선순위, native 재생성/late registration, group-99 관찰, admission receipt를 확인. 관리 밖 입력은 원래 handler 1번. 기존 Telegram/전체 시험 통과 | 4 |
| T22 | 03.05 | 전환 전에 종료된 스레드를 bind 후 앱/직원이 이어 씀, 정상 off/abort 후 이어 씀, 재bind 후 이어 씀: 현재 목적지 새 root에 지정 이어쓰기 표시, 새 글/새 파일만 포함, hejo thread 유지. 같은 epoch의 두 번째 글은 같은 root, 오래된 편집은 재발신 0, 기존 닻 삭제는 새 root 생성 0. 전환 barrier 경합도 두 목적지로 발신 0 | 1,3,4 |
| T23 | 01.02, 05.04 | 동일 M0 세 receipt와 bot/pair/owner/대상/native 계약 무결성 확인. 과거 시험 room은 출처로 보존하되 명시 rooms만 bind. 누락/손상/unknown/취소/기한 초과/계약 불일치 거부. complete TTL 없음, 늦은 receipt 승격 0. 단순 passed나 화면 메모는 대체 불가. | H1~H4 |
| T24 | 02.03, 05.04 | 실제 PTB dispatch에서 권한 검증된 probe 예약의 pending/complete/실패/취소/timed_out 및 재시작/끄기/짝 해제 상태에 일반 글·자동 전달·댓글·편집 주입: journal/직원/core handler 호출 0. 첫 시험 발신 전 예약 영속화 확인. 유효 bind 후의 새 입력만 정상 실행, 예약 기간 입력 소급 실행 0. 재시험과 첫 bind는 허용하되 retired 재등록은 거부 | 1,2 |
| T25 | 02.01, 02.02, 02.03 | 토픽 A의 카드에 방 B에서 답장, 위조 제목/이름, 미지 닻, 자동 전달 echo로 목적지 선택 시도: 실행 0. 댓글 root/reply가 충돌하면 거부. | H2 |
| T26 | 03.02, 03.04, 04.02 | 카드/root/comment 각 전송에서 성공 응답 손실 및 fsync 실패. unknown 자동 재발신 0, 카드 edit 실패에 복제 0, link는 검증 root만. status 보류 안내. | H3 |
| T27 | 03.02, 04.04 | private thread 링크와 복귀 링크가 해당 토픽/질문을 지시. 카드 resolve는 짝 포럼의 봇 카드만, 댓글/root resolve는 등록 그룹만; 다른 room/thread/세대 메시지 재사용 거부. | H3 |
| T28 | 01.02, 04.03, 05.02 | 옛 v1 active/paused/unknown 금고는 자동 hub 승격 0. v2 probe 읽기 호환·은퇴 예약 보존. 새 방은 자동 편입 0, 전체 off/abort 영향 명시. | H1,H4 |

## 사전 실물 M0 — REQ-HTC-05.AC-04

TASK 1의 probe 준비 후, 실행 봇·서버 및 단일 수신자를 정한다. 운영 갱신·재시작이면 롤백과 별도 승인이 필요하고, 격리 시험이면 별도 봇 토큰과 Hermes 인스턴스를 사용한다. 같은 봇 토큰의 두 수신 프로세스는 금지한다. 별도 인계에서 대상 private channel/discussion·동일 봇·native 계약 버전·사용자 승인·관측 시간을 고정한다. 기존 수락된 M0는 기술 증거로 보존하며 5판 재사용 조건은 design의 M0 절을 따른다. 사용자가 `/hejo_comments_probe <room>`을 보내고 봇이 게시한 시험 root를 같은 봇 native handler에서 수신하는지 원격 응답과 callback 증거로 대조한다. 자동 전달의 origin channel post id와 discussion message id가 연결되고 시험 답장 하나가 그 댓글에 표시되어야 통과다. 앱 journal/직원 호출은 0건. 시간 내 미수신은 미통과이며 실패 원인으로 곧바로 기능 부재를 단정하지 않는다. 시험 글은 자동 삭제하지 않는다.

M0 미실행/실패는 대역 성공으로 대체하지 않는다. 대상/봇/계약 버전 변경 시 재시험한다. 먼저 TASK 1 대역 시험에서 probe pending·callback 순서·같은 그룹 FIFO 비차단·시간 종료·늦은 update 비실행을 검증한다. 실패하면 기본 그룹 전송·새 polling·수동 닻으로 우회하지 않고 계획 담당에게 반환한다.

## 수동 실물 수락 — REQ-HTC-05.AC-03, 증거 수준 4

운영 적용 인계와 사장 준비 이후 **사장만 메시지를 보내며** 검토자는 비공개 증거를 확인한다. 공개 로그에는 실제 이름/id/본문/초대 링크를 남기지 않는다. 실행한 클라이언트·버전·날짜·검증 커밋을 기록한다. 요청의 Android 사용 맥락을 포함해 실제 사용할 모바일 Telegram에서 확인하고, 데스크톱 화면도 확인한다.

| TEST | 절차 | 기대 결과 |
|---|---|---|
| M1 | 두 직원 토픽과 공용 채널/그룹 하나를 준비, 명시 두 방을 bind | 앱 수정 없이 연결. 기존 다른 방 정상 |
| M2 | 서로 다른 사람 토픽에 질문 A, B 작성. 카드의 대화 열기와 복귀 링크 확인 | 사람 토픽 목록 유지, 외부 공간 고정 두 개, 클릭하면 해당 댓글만 열림. 보관/음소거 뒤 이동도 확인 |
| M3 | A 댓글에서 추가 질문·답장의 답장·단일 사진·문서 | A로만 이어지고 첨부 열림. B와 섞이지 않음 |
| M4 | 앱에서 새 질문, 직원의 새 보고, 긴 답변 | 해당 사람 토픽 카드 하나, 첫 게시물은 공용 채널, 후속 글·파일은 해당 댓글. 봇 echo 실행 0 |
| M5 | 승인된 시험 재시작, 원문 삭제 또는 봇 권한 회수 | 대응 유지 또는 명확한 정지. 다른 글/그룹으로 오배송 없음 |
| M6 | 실행 전에 정상 off도 영구 은퇴이며 재사용에는 새 채널/그룹이 필요함을 README로 안내. 정상 off와 전체 끄기 확인 | 옛 기록 보존, 참여 방 전체 경로 복귀/전체 중지, 비참여 방 정상. 기존 외부 쌍 재등록 거부 |

M 시험 결과가 없으면 최대 부분 완료다. 대역의 send 성공을 화면의 댓글 버튼/묶음 표시 증거로 세지 않는다. 시험을 위해 고객·Slack·기존 공개 채널에 메시지를 보내지 않는다.
