# HEJO-IMESSAGE 작업 분해

2판(2026-11-19, 계획 검증 1회차 반영: AT-HI-42 추가). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-IMESSAGE.md](../../../tests/acceptance/HEJO-IMESSAGE.md), 인계 [handoff.md](handoff.md). 저장소 약어: `H` = 이 저장소, `HD` = `<운영 저장소>`, `TKL` = 실행 중인 team-kit 원본(`<HOME>/plugin-store/team-kit`).

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 결정 요약·명세·설계·수락 시험 명세·작업 분해·인계서 | 전체 | `H/docs/changes/HEJO-IMESSAGE-20261119/`, `H/tests/acceptance/HEJO-IMESSAGE.md` | — | 문서 | 완료(기획 1판, 계획 검증 대기) |
| TASK-02 | 규격·저장·짝짓기·설정: 규격 프레임 6종·오류 코드 3종, 금고·설정 저장, 아이메시지 문 붙이기(공장·감싸기 뼈대, 통과만), 짝짓기·해제, 설정 저장·조회·방송, 기능 가림, `claims_external` | HI-01, HI-02, HI-06.AC-01 / AT-HI-01~11, 31 | `H/schemas/hejo-wire-v1.json`, `H/gate/`(`imessage.py` 신규, `__init__.py`, `adapter.py`, `server.py`), `H/gate/tests/`, `H/tests/acceptance/test_imessage.py` | TASK-01 | 고위험(인증) · 2 | 대기 |
| TASK-03 | 수신·명령: 판정 순서, `receive()` 응답 대상 일반화, 새 글·답장·안내, `/방` 명령, 중복·첨부·탭백·실패 | HI-03, HI-04, HI-06.AC-04(hejo 쪽) / AT-HI-12~21, 32 | `H/gate/`(`imessage.py`, `adapter.py`), 시험 | TASK-02 | 고위험(운영 수신 경로) · 2 | 대기 |
| TASK-04 | 발신: 후보·정착 규칙·이름표·나누기·답장 대상·`sent.jsonl`·실패 처리, 정착 시간 측정 | HI-05 / AT-HI-22~30, 39, 42 | `H/gate/`(`imessage.py`, `adapter.py`), 시험 | TASK-03 | 일반 · 2 (AT-HI-39만 3) | 대기 |
| TASK-05 | team-kit 안내원 양보: `ingress.py` 감싼 처리기 앞 검사, team-kit 시험. `TKL`에서 고치고 `HD`에서 `./sync`·`./airport-check`·자기 경로만 커밋. 재시작·`reload-plugins` 없음 | HI-06.AC-02·03 / AT-HI-33, 34 | `TKL/lib/hermes_router/ingress.py`, team-kit 시험, `HD` 동기화 사본 | TASK-01(계약은 design 7절로 확정) | 일반(없으면 기존 동작) · 2 | 대기 |
| TASK-06 | 앱: `GateClient` 프레임·기능 표시, 아이메시지 상태 모델, 설정 구역, 방 메뉴 두 항목, 앱 시험 | HI-07 / AT-HI-35~37 | `H/app/Sources/`(`GateClient.swift`, `SettingsPages.swift`, `RoomMenus.swift`, 새 모델 파일), `H/app/Tests/` | TASK-02(규격) | 일반 · 2 | 대기 |
| TASK-07 | 서버 적용: 적용 전 기록, 공용 릴리스·앱 사본 갱신, 게이트웨이 재시작, 로그 확인, 롤백 절차. TASK-02~06이 계획 담당 검토를 통과한 뒤 별도 지시로만 시작 | HI-08.AC-01·02 / AT-HI-38, 40, 41 | 공용 릴리스 폴더, 앱 사본 2곳, `H/evidence/HEJO-IMESSAGE/` | TASK-02~06 검토 통과 | 고위험(운영) · 3 | 대기 |
| TASK-08 | 실물 수락: 사장이 폰으로 M1~M8 확인, 결과를 verdict에 기록 | HI-08.AC-03 / M1~M8 | `H/docs/changes/HEJO-IMESSAGE-20261119/verdict.md` | TASK-07 | 고위험 · 4 | 대기(사장 + 계획 담당) |
| (계획) | 검증 완료 뒤 현재 명세 반영: `ARCHITECTURE.md` 칸 표(금고·공용 창고의 "둘 것")와 4절에 아이메시지 문 한 줄 | — | `H/docs/ARCHITECTURE.md` | TASK-08 | 문서 | 대기 |

## 병렬 갈래

병렬 갈래: 있음. TASK-02 뒤 세 갈래이며 담당 파일이 겹치지 않고 따로 시험할 수 있다.

| 갈래 | TASK | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|---|
| 문 | TASK-03 → TASK-04 | `H/gate/`, `H/tests/acceptance/test_imessage.py` | TASK-02 | 어려움 | AT-HI-12~30, 32, 39, 42 |
| 안내원 | TASK-05 | `TKL/lib/hermes_router/`, team-kit 시험, `HD` 사본 | 없음(계약 확정) | 단순 | AT-HI-33, 34, `./airport-check` |
| 앱 | TASK-06 | `H/app/` | TASK-02 | 보통 | AT-HI-35~37, `bash app/scripts/test.sh` |

TASK-03과 TASK-04는 `gate/imessage.py`·`gate/adapter.py`를 함께 고치므로 차례로 한다.
