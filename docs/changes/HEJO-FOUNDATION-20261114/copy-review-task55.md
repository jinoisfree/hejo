# TASK-55 원문·기존 계약 대조

새 화면 문구는 만들지 않는다. 되돌리기·답·체크리스트의 기존 문구를 보존하고 전달 대상만 고친다. ddots `NativeThreadContent.swift:111-112`의 작업 중 스레드 제어, 기존 답 단추 경로를 읽고 일하는 직원/질문한 직원으로 묶는 원칙을 따른다. 일반 작성기 답은 이름을 부르지 않으면 대표가 받는 사장 선택을 유지한다.

허브 장애에는 기존 연결 실패 안내를 사용한다. 출입증 폐기 안내는 명시 revoked에만 쓴다. 방 구성원 거절은 기존 일반 전송 실패 경로를 사용한다. 설치 영수증 버전은 화면 계약이 아니며 공개 앱 버전은 바꾸지 않는다.

새 공개 조회는 `latest_employee_message(profile, chat_id, thread_id, before_msg_id)`다. 기존 owner_message·employee_message와 같은 forwarder 경계를 사용하며 호출자가 프로필을 바꿔 조회할 수 없다. 본문은 공개 조회 결과만 소비하고 세션 DB content를 읽는 경로는 늘리지 않는다.
