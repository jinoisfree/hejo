# HEJO-DISCORD 작업과 상태 — 2판(계획 검증 1회차 반영)

| 작업 | 연결 | 범위 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|
| TASK-01 | REQ-HD-01~07, NFR-HD-01~05 / AT-HD-01~17·20~45(43개) | 문: `gate/discord.py`(새), `gate/__init__.py`(공장 등록), `gate/adapter.py`(디스코드 다리 생성·종료·`_record`·`send_typing`·`stop_typing` 깨우기; `claims_external`은 바꾸지 않음), `gate/rooms.py`(`room_command`의 텔레그램 알림 옆에 디스코드 알림 한 곳 — 검증 1회 V-1), `gate/server.py`(프레임 넘기기), `schemas/hejo-wire-v1.json`(프레임 6종·기능 `discord`), `gate/README.md`(운용 안내), `tests/acceptance/test_discord.py`(명세를 코드로), 필요한 `gate/tests/` | 없음 | 고위험 · 수준 2(대역), 정착 측정 3 | 검증 완료(verdict 4회, 커밋 `3b9da3d`) |
| TASK-02 | REQ-HD-08 / AT-HD-50~53 | 앱: `app/Sources/DiscordState.swift`(새), `SettingsPages.swift`(디스코드 구역), `PetSettingsWindow.swift`(구역 속성·"연결과 동기화" 페이지 배치 — 검증 1회 V-2), `GateClient.swift`(기능·프레임 넘기기), `AppDelegate.swift`·`ConversationController.swift`(구역 연결·갱신), `app/Tests/`(새 디스코드 시험, 그리고 `TelegramTests.swift`의 `features` 정확 비교를 `["rooms","telegram","discord"]`로 갱신 — 검증 1회 V-3) | 프레임 계약은 spec·schema 기준(TASK-01과 파일 겹침 없음, 순서는 TASK-01 뒤 권장) | 일반 · 수준 1~2 | 검증 완료(verdict 4회, 커밋 `3b9da3d`) |
| TASK-03 | REQ-HD-09 / M1~M10·M6b | 서버 적용(닫힘 운영): 적용 전 기록(설정 복사본·해시·`pip freeze`)·복원 절차(design 10절), discord.py 설치(Hermes 공식 방법), 기본 프로필 디스코드 켜기, 공용 릴리스 갱신, 재시작, 로그 확인, 사장 실물 확인 | TASK-01·02 검증 완료, 사장 준비(봇·서버·커뮤니티·초대·토큰) | 고위험 · 수준 3~4 | 미착수 — 별도 인계서(`handoff-task03.md`)로 허가 |

병렬 갈래: 없음(갈래 3개 미만: 코드 갈래는 TASK-01 문·TASK-02 앱 둘뿐이고 TASK-03은 둘에 의존).

## 지적·결정 기록

- 계획 검증 1회차 BLOCKED → 2판: [plan-review.md](plan-review.md).

남은 작업(검증 4회 기준):
- TASK-04 공개 통합·현재 명세 반영 — 검증 완료(verdict 6회, 공개 커밋 `86fb981` + 문서 커밋), 푸시 승인 대기: 개발 커밋 `3b9da3d`를 공개 원격(`github/main`, 개발 main과 공통 조상 없음)의 현재 tip 위로 옮겨 다시 검증하고, `docs/ARCHITECTURE.md`(디스코드 창: 칸·저장 위치·닫힘 운영)와 `docs/spec/current/`에 반영한다. 사용자 허가 뒤 별도 인계.
- TASK-03 운영 적용·실물 확인: `handoff-task03.md`로 별도 허가.
