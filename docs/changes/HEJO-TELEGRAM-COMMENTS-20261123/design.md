# 구조·계약 설계 5판

권위는 [spec](spec.md)와 [ARCHITECTURE](../../ARCHITECTURE.md). 4판의 사람별 외부 쌍·토픽 차단·채널 글 자동 실행 계약을 대체한다. 앱·wire·Hermes 본체는 변경하지 않는다.

## 1. 책임과 저장 원본

기존 Telegram/Comments가 유일한 소유자다. 금고 telegram.json은 pair와 외부 chat id·권한·예약 원본, 기존 sent.jsonl은 외부 대응 원본, journal과 FileStore는 대화/첨부 원본이다. 새 서비스·polling·저장 원본은 만들지 않는다.

금고 comments_version=2의 단일 hub에는 binding/generation/pair/owner/bot/channel/discussion, 명시 rooms 목록, state, activated_at을 둔다. route_epochs는 방별 cutover_seq와 epoch를 유지한다. 연결은 쌍 하나: 방 추가에 따라 쌍을 늘리지 않는다. 활성 상태 rooms 변경은 거부하고 1차 범위에 포함하지 않는다. 새 직원은 기존 토픽 모드로 남는다.

sent의 새 레코드는 v=3, binding/generation/room/thread/route_epoch/side/forum|channel|discussion/message_id/kind/operation/part/status를 쓴다. side와 message_id만으로 방을 결정하지 않는다. 외부 chat id·원문·초대 링크는 저장하지 않는다. question key=(binding,generation,room,thread,route_epoch). journal에서 room/thread 존재·소유 관계를 다시 검증한다. 레코드 alias와 발신 의도는 기존 파일에 append/fsync하며 index는 재구성 가능하다.

기존 topic 레코드는 유지, v2 probe receipt는 읽기 호환한다. v1 사람별 binding은 자동 hub 승격하지 않고 fail closed 및 명시 이전 안내한다. active/paused/unknown이 있으면 활성화를 거부한다. 기존 예약과 은퇴 tombstone은 삭제하지 않는다. 미지원 버전/중간 손상은 댓글 전체 닫힘이며 빈 상태로 복구하지 않는다. 운영 후보에는 probe만 있고 bind가 없었다는 과거 보고를 실제 전환 전 다시 확인한다.

## 2. 인증과 native 경계

기존 register_platform_handler 계약의 group 0/block=True 처리기로 관리/예약/은퇴 채널·그룹을 소비한다. ApplicationHandlerStop을 쓰지 않고 group-99 관찰과 본체 admission을 유지한다. 미관리 채팅은 기존 처리기에 한 번 전달한다. 참여 사람 토픽 입력은 같은 native handler가 core 다운로드 전에 소비한다. 비참여 토픽은 기존 포럼 wrapper를 유지한다. wrapper로 들어온 참여 입력도 같은 accept_input 경로를 사용하며 영속 claim으로 중복 실행을 막는다.

제어 명령과 사람 입력은 기존 pair 사장의 from_user이고 sender_chat 없음이어야 한다. 목록/status는 기존 짝 그룹, bind/off는 등록 공용 토론 그룹, abort는 짝 그룹의 인증된 명령만 허용한다. resolve는 4절의 작업 종류별 위치 검사를 따른다. 카드 복구는 기존 짝 포럼의 해당 사람 토픽, root/댓글 복구는 등록 공용 토론 그룹에서만 허용하며 다른 위치는 소비 후 거부한다. bind 인자는 명시한 방 목록이며 하나도 허용한다. 기존 한 방 입력을 새 쌍 여러 개 생성으로 해석하지 않는다. abort는 인자 없이 hub 전체 범위임을 안내한다. 지원하지 않는 옛 명령 형태는 변경 없이 거부한다.

getChat 양쪽 linked_chat_id, 비공개(username/active_usernames 없음), channel 및 non-forum supergroup, 사장 creator, 양쪽 봇 administrator와 채널 can_post_messages, getChatAdministrators(return_bots=true)에서 사장/현재 봇 외 관리자 없음, getMe 신원을 검사한다. 공식 클라우드 Bot API만 지원한다. 옵션 무시를 응답으로 탐지한다고 주장하지 않는다. 매 입력/발신 전 재검사 실패면 hub paused; 일반 토픽 답변으로 우회하지 않는다. 대화방 멤버 접근 격리는 제공하지 않는다.

자동 전달은 등록 그룹·sender_chat·MessageOriginChannel.chat·origin.message_id 및 is_automatic_forward 모두 검증한다. 봇 발행 성공 receipt와 일치할 때만 question key에 닻을 연결한다. 사람의 채널 게시물/미지 자동 전달은 소비만 한다. 제목·직원 이름·본문 서명에서 목적지를 추측하지 않는다.

## 3. 입력과 카드

참여 사람 토픽의 새 글은 기존 pair 인증 후 native handler에서 해당 room의 새 thread로 기존 adapter.receive를 한 번 호출한다. 알려진 질문 원문/card/reply alias는 동일 room·현재 pair와 journal 스레드 관계를 검증하여 후속으로 접수한다. 교차 방·미지 reply는 거부한다. 댓글은 개인 사장과 알려진 같은 그룹 reply alias 또는 검증된 raw thread root로 room/thread를 복원한다. 둘이 충돌하면 거부한다. 외부 답장·수동 전달·편집·활성 이전 입력은 실행하지 않는다.

claim 영속화와 journal client_msg_id 중복 검사는 첨부 다운로드/직원 호출보다 먼저다. journal commit 이후 중단된 직원 실행의 자동 재개는 보장하지 않는다. 텍스트/단일 photo/document만 기존 FileStore로 stage; getFile 20MB와 기존 한도 중 작은 값, 실패/앨범/미지원은 부분 실행 없이 거부하고 임시 파일을 정리한다.

질문 카드 제목은 질문 첫 줄의 제한된 길이(최대 80자)다. 닻 확인 전 준비 상태는 status의 waiting_anchor로 나타내며, URL을 확정한 뒤 카드 하나를 대화 가능 상태로 발행한다. 이후 전송이 불확실해지면 알려진 카드만 보류로 편집한다. 직원 완료 여부를 추측하지 않는다. 토픽 원래 사용자 글은 삭제하지 않고 봇 카드 하나를 그 글에 답장한다. 앱/직원 시작이면 카드 자체가 토픽 항목이다. 후속 답변은 카드 새 발행 없이 상태만 편집한다. 토픽의 사용자 후속 글은 남지만 봇 답변 전체는 댓글에서만 보인다.

공용 root에는 사람 이름(런타임 표시명)과 질문 제목/첫 새 본문을 표시한다. 각 질문은 원래 사람 토픽으로 돌아가는 링크를 제공한다. 실제 식별자 포함 링크는 Telegram 출력에만 생성하며 공개 로그/대응 파일에는 저장하지 않는다.

대화 열기 링크는 공식 [message links](https://core.telegram.org/api/links#message-links)의 private supergroup message link와 thread 파라미터를 이용해 검증된 discussion root를 가리킨다. Bot API id에서 MTProto id 변환은 공식 형식만 허용하고 임의 문자열 자르기를 일반화하지 않는다. 링크를 만들 수 없으면 카드 보류, 잘못된 일반 그룹 URL로 대체하지 않는다. 실제 클라이언트에서 댓글창이 열리는지는 M2에서 확인하며 단순 문자열 시험으로 수락하지 않는다.

## 4. 발신 순서·경합·복구

각 question key에 하나의 root 작업을 claim한다. journal 접수 이후 settled 직원 결과가 먼저 도착해도 질문의 journal 최초 새 글을 root 원본으로 선택한다. 원문 발신 intent fsync → API 성공 receipt fsync → 자동 전달 닻 확정 → 댓글 출력이다. 같은 question lock에서 의도만 직렬화하고 자동 전달을 기다리는 await로 native FIFO/lock을 막지 않는다. root를 먼저 받은 callback은 안전한 후보 receipt로 남기고 API receipt와 일치한 뒤 확정한다. echo는 어느 순서에도 직원 실행 0건이다.

카드는 별도 operation이며 root/anchor 성공 후 URL을 확정한다. 동일 토픽 질문의 카드 의도는 하나다. 카드 발신 결과 unknown이면 자동 재발신하지 않는다. root나 카드의 unknown은 hub 외부 작업을 보류하며 앱 journal은 보존한다. 링크 편집 실패도 보류로 표시할 수 있는 status 명령에 남기고 카드 복제는 하지 않는다. 다른 사람에게 보내는 fallback은 없다. 모든 전송 단계의 작업 종류(root/card/comment/edit)를 구분해 복구한다.

댓글은 ReplyParameters(discussion anchor, allow_sending_without_reply=false)로 보낸다. 포럼 message_thread_id를 댓글 전송에 쓰지 않는다. 긴 글은 4096자 이하 분할, 모든 텍스트/첨부 alias가 같은 question key다. Telegram에서 이미 수신한 댓글 본문은 다시 보내지 않는다. 토픽/앱 후속만 댓글로 출력한다. 기존 settled/typing/삭제/소유권 검사는 유지한다.

status는 hub와 방별 보류 operation을 안내한다. resolve는 사장 실제 메시지 답장과 operation을 대조하며 종류에 따라 짝 포럼의 카드 또는 등록 토론 그룹의 자동 전달 root/댓글만 허용한다. 봇 신원·chat·room/thread·세대·본문/첨부 조각을 대조하고 다른 작업의 receipt 재사용은 거부한다. 보이지 않는 메시지를 자동 재발신하는 resolve는 없다. abort는 quiescent 경계에서 hub 전체 은퇴·미전송 cancelled, 모든 참여 방 토픽 모드 복귀다. 늦은 입력은 소비하며 취소 본문을 재전송하지 않는다. exactly-once 원격 전송은 보장하지 않는다.

## 5. 전환·M0·운영

bind/off/abort는 참여 방 전체 barrier와 진행 차례/전송/unknown 검사 후 금고를 원자 전환한다. 네트워크 조회 뒤 commit 직전 pair/epoch를 재검사한다. 기존 토픽 sync를 중단하거나 토픽을 닫지 않는다. 비참여 방·단체방 경로는 유지한다. paused는 댓글 본문을 토픽으로 보내는 사유가 아니다.

전환 이전 스레드를 새 epoch에서 이어 쓰면 과거를 복사하지 않고 `이전 대화 이어쓰기 — 전환 이후 내용` root와 새 카드에 새 내용만 보낸다. 같은 epoch의 닻 삭제는 root 재생성 사유가 아니다. off 이후 댓글 입력은 소비하며 기존 토픽에 새로 쓴 글은 기존 경로를 따른다. 전체 끄기 중 신규 실행/전송 없음, 해제·재짝은 hub 무효화와 영구 예약 보존이다. off도 외부 쌍을 영구 은퇴시키므로 재사용에는 새 쌍이 필요함을 사전에 안내한다.

M0는 채널 root→자동 전달→댓글의 native 기술 관문이다. probe 예약은 첫 발신 전에 영속화, pending/complete/failed/cancelled/timed_out과 재시작/해제 뒤에도 입력을 소비한다. callback을 기다리며 같은 그룹 FIFO를 막지 않는다. deadline은 pending 완료 기한이며 complete에 TTL은 없다. 동일 probe의 채널 send/forward/comment receipt 완결, bot/owner/pair/채널/그룹/native 계약 일치가 필요하다.

기존 성공 M0는 해당 대상의 기술 가능성 증거만 재사용한다. 과거 probe의 room은 시험 출처로 보존하며 hub 방 목록 승인으로 확장하지 않는다. 새 bind는 native 계약 불변·기존 receipt 무결성과 현재 권한을 재검사하고 명시 rooms만 승인한다. bot/pair/대상/native 계약 변경이면 새 M0가 필요하다. 새 routing 저장 버전 변경만으로 native 계약 변경을 가장하거나 증거를 자동 승인하지 않는다. 사람 화면 확인은 기록된 검토 증거로 분리하며 공용 routing과 링크 UX는 M1~M6로 새로 확인한다.

이번 계획은 운영 쓰기를 승인하지 않는다. 기존 배포 후보와 예약은 유지한다. 수정본 배포/재시작/bind/실물 시험은 격리 릴리스·복구 원본·유일 수신자·발신 한도를 별도 인계하여 승인받는다. 구버전 rollback으로 예약 채팅이 core에 유입될 수 있으면 중단하고 운영 허용 채팅 경계를 먼저 확보한다. journal/첨부를 과거 백업으로 덮어쓰지 않는다.
