# 현황 조사 — 구현 전

- 조사일: 2026-11-23
- hejo 기준 커밋: `6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0`
- 제품 변경·운영 변경·외부 메시지 전송: 없음.
- 작업 시작 시 다른 작업의 미추적 문서와 수락 시험이 존재했다. 수정하지 않았다.

## 확인한 경로

`gate/__init__.py`는 `register_platform_handler("telegram", attach_telegram)`을 등록한다. `gate/telegram.py::attach_telegram`은 기존 어댑터의 `handle_message`를 감싸며 `claims_external`이 참일 때만 문이 처리한다.

`claims_external`은 group/forum 및 하나의 짝지은 그룹·사장 계정만 수용한다. 짝짓기는 포럼 여부를 요구한다. `sync_topics`는 각 방에 포럼 토픽을 생성한다. `_send_message`는 하나의 짝지은 그룹과 해당 토픽으로 발신한다.

`reply_thread`, `anchor`, `_save_sent`의 외부 메시지 식별은 현재 짝 표지+메시지 id 기준이다. 여러 채팅을 수용하면 메시지 id가 충돌할 수 있으므로 채팅 범위가 식별에 포함되어야 한다. 개인 채팅 id를 공용 기록에 넣지 않는 기존 금고 계약도 보존해야 한다.

기존 적용 계약: `docs/changes/HEJO-TELEGRAM-20261122/spec.md`. 원문·파일은 기존 기록장과 첨부 저장소를 사용한다. 앱 프레임과 기록장 레코드 종류를 늘리지 않는 계약이 있다. 현재 구조를 바꾸는 목표 설계가 확정되기 전 근간의 현행 설명을 덮어쓰지 않는다.

## Hermes 플랫폼 읽기 전용 확인

경로 약어 R은 프로젝트 규칙에서 지정하는 Hermes 본체다. 개인 절대 경로는 이 문서에 기록하지 않는다.

- `R/plugins/platforms/telegram/adapter.py::_effective_update_message`: 일반 메시지 및 채널 게시물을 수용하는 effective_message 사용.
- `_source_from_message_for_auth`: 채널 게시물에 from_user가 없으면 sender_chat 신원을 인증에 사용한다. 채널 게시물을 사장의 개인 계정 발신으로 간주하면 안 된다.
- `_effective_message_thread_id`: 일반 그룹 댓글의 raw thread id를 포럼 발신 thread id로 취급하지 않는다. raw_message와 reply 관계를 별도로 조사해야 한다.
- `_handle_text_message`: 인증과 그룹 trigger 검사 이후에 이벤트를 구성한다. 문이 handle_message를 감싼다는 사실만으로 모든 댓글이 도착한다고 볼 수 없다.
- `_wire_plugin_handlers`: 공식 플랫폼 처리기 factory에서 native handler를 등록할 수 있는 경로가 존재한다. 그 사용이 필요한지, 기존 수신과 중복되지 않는지는 미검증이다.

## 다음 설계에서 해결할 사항

1. 채널 게시물과 토론 그룹 자동 전달을 동시에 받아도 질문은 한 번만 실행되어야 한다.
2. 댓글의 댓글, 사진·파일, 앱에서 시작한 질문, 직원이 먼저 보낸 보고의 닻을 정의해야 한다.
3. 채널 게시자에게 개인 계정 정보가 없을 수 있다. 자동 전달 채널 검증과 허용 관리자 정책이 필요하다.
4. 서로 다른 그룹의 동일 메시지 id 및 재시작 후 중복을 분리해야 한다.
5. 익명/타 계정/허용되지 않은 채널, 연결 해제·권한 상실·닻 삭제 시 처리 경계를 정해야 한다.
6. 별도 polling이나 본체 패치 없이 현재 플랫폼 계약으로 해결할 수 있는지 확인해야 한다.
7. 운영 전환은 기존 기록을 보존하고 복구 가능한 단계로 분리해야 한다. 현 시점에는 운영 변경을 허가하지 않는다.

## 검사 상태

소스 조사만 수행했다. 테스트·빌드·개인값 검사·실물 검증은 미실행이다. 기존 소스 경로를 `gateway/platforms/telegram.py`로 조회한 명령은 파일 없음으로 종료 코드 2였으며, 실제 위치인 `plugins/platforms/telegram/adapter.py`를 찾아 재조사했다. 이 실패를 기능 검사 실패로 해석하지 않는다.

## 1판 설계 전 추가 확인

Hermes 커밋 `ebb026eef8e800e1b7471ed147b7287e878f8aa4`를 읽었다. `R/hermes_cli/plugins.py::register_platform_handler`는 native Application factory와 범위 제한을 공식 계약으로 제공하며 adapter는 read-only다. 기존 wrapper 동작을 새 댓글 경로에서 확대하지 않는다.

`R/plugins/platforms/telegram/update_admission.py::TelegramApplication._admit_callbacks`가 native plugin callback 진입을 admission으로 기록한다. 따라서 새 handler가 본체 admission 변수를 직접 조작할 필요가 없다. `PerChatUpdateProcessor`는 채팅별 FIFO지만 channel/group 사이의 순서까지 보장하지 않는다. 설계에 교차 채팅 경합 검사를 포함했다.

공식 문서 4회 조회 범위에서 확인한 계약:

| 출처 | 설계 근거 |
|---|---|
| https://core.telegram.org/bots/api#message | message_id는 채팅 범위, is_automatic_forward/forward_origin/sender_chat 구분, reply 객체는 재귀 답장 전체를 포함하지 않음 |
| https://core.telegram.org/bots/api#chatfullinfo | linked_chat_id로 채널/토론 연결 대조 가능 |
| https://core.telegram.org/bots/api#getchatadministrators | return_bots=true를 생략하면 현재 봇 외 관리자 봇이 누락됨 |
| https://core.telegram.org/bots/api#sendmessage | message_thread_id는 forum 또는 봇 private topic용. 일반 댓글에는 reply_parameters 사용 |
| https://core.telegram.org/bots/api#replyparameters | 원문 없는 전송을 허용하지 않는 옵션 존재 |
| https://core.telegram.org/bots/api#getfile | 기본 Bot API 수신 파일 20MB 제한 |
| https://docs.python-telegram-bot.org/en/stable/telegram.ext.application.html#telegram.ext.Application.add_handler | 한 그룹 첫 매치만 실행, 다른 그룹 계속 처리 |
| https://docs.python-telegram-bot.org/en/stable/telegram.ext.applicationhandlerstop.html | Stop은 다른 그룹도 중단. 새 경로에서는 사용하지 않음 |

실제 SDK 객체와 Bot API 응답은 미실행이다. 1판은 옵션 미지원 오류로 fail-closed할 수 있다고 가정했으나, R1 검토에서 무시된 옵션을 응답으로 탐지할 수 없음을 지적받았다. 2판은 공식 클라우드 Bot API만 지원하고 대체 endpoint를 사전에 거부하는 계약으로 수정했다. 공식 API에 createChannel이나 자동으로 개인 UI를 바꾸는 가정을 두지 않았다. 채널/그룹 준비는 사용자가 한다.

경로 탐색 중 `hermes_plugin_manager.py`, `hermes_plugins`, `telegram_update_admission.py`는 존재하지 않아 조회 실패했다. 실제 위치 `hermes_cli/plugins.py`, `plugins/platforms/telegram/update_admission.py`에서 계약을 확인했다. 일부 셸 glob 조회도 해당 파일 없음으로 실패했다. 이들은 제품 시험 결과가 아니다.

## 2판 환경 확인

R5 수용을 위해 실행 파이썬을 확인했다. Hermes 소스의 `.venv/bin/python`은 없었고(조회 종료 1), `venv/bin/python`은 있으나 PYTHONPATH 없이 pytest import는 실패했다(종료 1). 기존 로컬 시험 설정에서 파이썬/PYTHONPATH 선언만 읽고, 기존 시험 의존성 폴더와 Hermes 소스를 명시하여 같은 가상환경 Python에서 `import pytest, ruamel.yaml`을 확인했다(종료 0). 비밀 파일 열람·환경 스크립트 source·패키지 설치는 하지 않았다. 개인 경로는 이 공개 문서에 쓰지 않는다.
