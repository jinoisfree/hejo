# HEJO-TELEGRAM 작업 분해

2판(2026-11-22, 계획 검증 1회차 반영: AT-HT-45 연결). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-TELEGRAM.md](../../../tests/acceptance/HEJO-TELEGRAM.md), 인계 [handoff.md](handoff.md). 저장소 약어: `H` = 이 저장소.

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 결정 요약·명세·설계·수락 시험 명세·작업 분해·인계서 | 전체 | `H/docs/changes/HEJO-TELEGRAM-20261122/`, `H/tests/acceptance/HEJO-TELEGRAM.md` | — | 문서 | 2판(1회차 반영), 재검증 대기 |
| TASK-02 | 문 바탕: 규격(텔레그램 프레임 6종·오류 2종, 아이메시지 정의 삭제), `gate/telegram.py` 새로(저장·짝짓기·해제·설정·상태·`claims_external`·공장·감싸기 뼈대), `gate/imessage.py`·`photon` 등록 삭제, adapter·server·rooms 호출 교체, `test_imessage.py` → `test_telegram.py` | HT-01, HT-02, HT-08.AC-01 / AT-HT-01~11, 26, 40(금고·설정), 42(문·규격) | `H/schemas/hejo-wire-v1.json`, `H/gate/{telegram.py(신규),imessage.py(삭제),__init__.py,adapter.py,server.py,rooms.py}`, `H/tests/acceptance/{test_telegram.py(신규),test_imessage.py(삭제)}` | TASK-01 계획 검증 통과 | 고위험(인증) · 2 | 검토 통과(verdict 2차, 53acb8e·1ef3ad2) |
| TASK-03 | 토픽 동기화와 수신: 동기화 작업자, 방 레코드 연결, 수신 판정 4단계, 본문·첨부, 답장 대상, 안내, 중복 | HT-03, HT-04 / AT-HT-12~16, 20~28, 45 | `H/gate/{telegram.py,adapter.py}`, `H/tests/acceptance/test_telegram.py` | TASK-02 | 고위험(운영 수신 경로) · 2 | 검토 통과(verdict 2차, 338c35a) |
| TASK-04 | 발신과 작성 중: 스레드 대기열(사장 즉시·직원 정착), 이름표·알림·닻, 첨부 발신, `sent.jsonl`, 실패, 작성 중 줄이기; 정착 측정 시험 이름·참조 이전 | HT-05, HT-06 / AT-HT-30~41, 44 | `H/gate/{telegram.py,adapter.py}`, `H/gate/tests/imessage_settling.py`(이름 변경 허용), `H/tests/acceptance/test_telegram.py` | TASK-03 | 일반 · 2 (AT-HT-44만 3) | 검토 통과(verdict 2차) |
| TASK-05 | 앱: `GateClient` 기능·프레임, 텔레그램 상태 모델, 설정 구역, 아이메시지 구역·메뉴·상태·시험 삭제, 고정물 `legacy_feature_fixture.py` 갱신 | HT-07, HT-08.AC-02(앱) / AT-HT-42(앱), 50~52 | `H/app/Sources/{GateClient,IMessageState(삭제),SettingsPages,PetSettingsWindow,RoomMenus,RoomDialogs,ConversationView,ConversationController,AppDelegate}.swift`, 새 상태 파일, `H/app/Tests/{IMessageTests.swift(→텔레그램),TestMain.swift,*_fixture.py}` | TASK-02(규격) | 일반 · 2 | 검토 통과(verdict 2차) |
| TASK-06 | 전체 시험·개인값 검사·보고 | NFR-HT-01·03 / AT-HT-43 | 없음(실행만) | TASK-04, TASK-05 | — | 통과(verdict 2차: 전체 427 passed·종료 0. HT-B02 수락 시험 해시 갱신. 개인값 검사는 다른 작업 4건, 이 작업 0건) |
| TASK-07 | 서버 적용(별도 허가 지시 뒤에만): 적용 전 기록, 사장 준비 확인(봇·포럼 그룹·관리자 권한·토큰·허용 계정 — 사장이 직접), Hermes 환경 텔레그램 의존성 설치, 공용 릴리스, 재시작, 로그, 롤백 절차 | HT-09.AC-01·02 / AT-HT-60·61 | 공용 릴리스 폴더, Hermes venv 패키지, `H/evidence/HEJO-TELEGRAM/` | TASK-06 검토 통과 | 고위험(운영) · 3 | 대기 |
| TASK-07b | 앱 공개(다음 판): 버전 올림, 공개 스냅샷, 서명, 사장 공개 | HT-07의 배포 | `H/app/Resources/Info.plist`, 공개 산출물 | TASK-07 | 고위험(공개) | 대기 |
| TASK-08 | 실물 수락 M1~M8(사장) | HT-09.AC-03 | `verdict.md` | TASK-07b | 고위험 · 4 | 대기 |
| (계획) | 검증 완료 뒤 현재 명세 반영: `ARCHITECTURE.md` 금고·공용 창고 칸의 아이메시지 값 → 텔레그램, 4절 아이메시지 문단 → 텔레그램 문단 | — | `H/docs/ARCHITECTURE.md` | TASK-08 | 문서 | 대기 |
| (후속 후보) | team-kit 안내원의 `photon` hejo 양보 검사 철거(이 작업 뒤 무동작) | — | `<운영 저장소>` team-kit | — | 범위 밖 | 기록만 |

## 병렬 갈래

병렬 갈래: 없음(갈래 3개 미만: TASK-02 뒤 문 갈래 TASK-03 → TASK-04는 `gate/telegram.py`·`gate/adapter.py`를 함께 고쳐 차례로 하고, 앱 갈래 TASK-05 하나뿐이다. 문과 앱 두 갈래는 담당 파일이 겹치지 않으므로 구현 담당이 동시에 해도 된다).
