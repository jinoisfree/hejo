## 검증 판정: HEJO-CONNECTIONS-20261120 / 에이전트 연결 화면 고치기 — 1차 (TASK-02~04)

1. **판정: 부분 완료.** TASK-02(문)·TASK-03(앱)은 설계대로이고 시험도 통과했다. TASK-04(team-kit)에서 설계 결함 2건이 나왔다(V-1 차단, V-2 비차단). V-1 때문에 실제 서버에서 직원 B가 다시 주소 두 개를 입력해야 한다. TASK-05~07(서버 적용·0.2.2·사장 확인)은 아직이다.
2. **검증 조건:** 교차 모델. 계획·검증은 이 대화(Claude), 구현은 별도 대화(codex). 계획 검증 3회차 APPROVED(plan-review.md). 검토한 코드는 다음과 같다.
   - 이 저장소 `33814a7`(TASK-02), `f294ad6`(TASK-03, impl-report 포함)
   - 운영 저장소 worktree 브랜치 `hejo-connections-20261120` `1c0ea8a5a6d7247c3e62e46fec4307c145baefc6`(기준 `9e68b39b`)
3. **설계 적합성(4.2):** 1~3판 설계는 REQ-HC-01~03·05·06을 충족한다. REQ-HC-04.AC-01·06("서버가 아는 값은 묻지 않는다")은 충족하지 못했다.
   - design 3판 4.1은 "자기 초안이 있으면 그 값만 쓴다"를 우선으로 두었다. 그래서 초안 주소가 틀렸을 때 서버가 아는 맞는 주소를 보지 않는다(V-1).
   - 3판을 고치면서 후보 라벨 규칙도 설계에서 빠졌다(V-2).
   - 둘 다 이 대화의 설계 결함이다. 4판(design 4.1, AT-HC-53·54)으로 고쳤다.
4. **직접 확인한 것(증거 수준 2):**
   - 문 수락 시험과 기존 연결 시험: `tests/acceptance/test_connections_screen.py gate/tests/test_connections.py` 종료 0, 58 통과. 로그 `.build/verify/gate-at.log`.
   - team-kit worktree: `test_connections_screen.py`, `test_synology_app_connect.py`, `test_app_connect.py`, `test_connection_guides.py`, `test_connections_secret.py`(임시 HOME) 종료 0, 108 통과. 로그 `.build/verify/teamkit-at.log`.
   - 전체 `bash scripts/test.sh`(구현 담당의 `.build/connections-env.sh` 환경, 대상 `f294ad6` + worktree team-kit lib): 종료 0, Python 381 통과, 게이트웨이 대역·앱 빌드/서명·앱 시험 통과. 로그 `.build/verify/full.log`.
   - 코드 읽기:
     - 부분 격리와 `unread`·로그(`connection_manager.py` `failed()`)를 확인했다. 로그에는 이유 코드와 상태만 쓰고 본문은 쓰지 않는다.
     - `AdminClient`는 `admin.json` 오류와 응답 JSON 오류를 나눈다.
     - `undo_available()`은 지우지도 잠그지도 않는다.
     - `server.py`는 실제 이유를 전달하고 로그를 남긴다.
     - 키 줄은 값 있음 ∪ 켠 묶음 필요 키로 필터한다.
     - 숨김 표시와 이어서 하기·처음부터 다시 라벨이 있다.
     - 앱의 이유별 문장, 표 유지, AppKit sheet 소유, `beginSheetModal` 확인 창, 인증 중 창 단계 낮춤을 확인했다.
     - team-kit의 `address_problems`는 `nas_settings`와 한 규칙이다. 후보 분류, 비밀번호 이름 무조회, Obsidian 고르기를 확인했다.
   - 기존 시험 수정 확인:
     - `gate/tests/test_connections.py` CatalogAdmin: 새 키 필터 아래에서 같은 보상 시나리오를 유지한다.
     - team-kit 4개 파일: 엄격 주소 규칙에 맞춘 가짜 값과 승인된 새 동작(완전 주소는 로그인으로 건너뜀)을 반영했다.
     - 기대값을 약하게 하거나 skip한 것은 없다.
   - 수락 시험 명세·spec·design은 구현 커밋에서 바뀌지 않았다.
   - 운영 자료 읽기 확인(값 출력 없이 칸 이름·개수만):
     - 직원 B 초안의 주소 두 칸이 모두 `address_problems`에 걸린다.
     - 다른 직원의 완전 후보가 1개 있다(아이디 있음).
     - Drive Client 후보는 0개다.
5. **지적 목록**

| 번호 | 위치 | 위반 기준 | 근거 | 등급 | 보낼 곳 |
|---|---|---|---|---|---|
| V-1 | team-kit `synology_setup.py` `prepare()`(자기 값이 있으면 `discover`를 부르지 않음), design 3판 4.1 0번과 경우별 표 | REQ-HC-04.AC-01·06, M5 | 운영 읽기 확인에서 직원 B 초안 주소는 두 칸 모두 정책 밖이고, 다른 직원의 완전 후보가 1개 있다. 3판 규칙으로는 주소 단계로 돌아가 두 칸을 다시 묻는다. 사장 요청 3번과 M5에 어긋난다 | 차단 | 기획설계(설계 오류) → 4판 반영 후 구현 |
| V-2 | `synology_setup.py` 후보 옵션 라벨 "시놀로지 연결 N" | REQ-HC-04.AC-06(클릭으로 고를 수 있어야 함) | 라벨로는 어느 NAS·계정인지 알 수 없다. 1판 design의 "NAS 주소 · 아이디" 라벨 규칙이 3판 고침에서 빠졌다 | 비차단 | 기획설계(설계 누락) → 4판 반영 후 구현 |
| V-3 | `ConnectionsWindow.swift:119,210` | design 3.4 | 연결된 앱의 "되돌리기"도 "이 연결을 처음부터 다시 할까요?"로 묻는다. 확인 문구가 동작 라벨과 다르다 | 비차단 | 구현 |

처분 상태: 모두 미처리.

후보였지만 지적에서 뺀 것:
- `key_rows`의 `info['is_set']` 엄격 접근: Hermes `config_env.py`의 `_row`가 모든 줄(사용자 키 포함)에 `is_set`을 넣으므로 결함이 아니다.

6. **기획설계로 넘긴 것:** V-1·V-2. 이 대화에서 design 4판 4.1(자기 값은 완전할 때만 출처, 틀린 자기 값 + 완전 후보 처리, 라벨 규칙)과 판정표 1행, 수락 시험 AT-HC-53·54를 이미 고쳤다.
7. **미검증 범위와 남은 위험:**
   - 운영 적용과 실물 M1~M7.
   - 원래 운영 사건(창이 저절로 닫힘)은 재현하지 못했다. 앱 전체 모달이 가려지는 원인은 재현했고 고쳤다.
   - 직원 A의 400 원인은 아직 가정이다(M2로 확인).
   - team-kit 확장 전체 시험은 임시 HOME에서 29 실패·1 오류였다. 운영 HOME에 기대는 기존 시험이라 이번 변경 범위 밖이지만, 전체 통과는 확인하지 않았다.
8. **미완료 원인 분류:** V-1·V-2는 설계 오류(요구 불변)다. V-3은 구현 오류다. 완료까지 남은 것:
   - V-1~V-3 수정, AT-HC-53·54 통과, 재검토.
   - TASK-05 서버 적용(design 7.2).
   - TASK-06 0.2.2 공개 준비.
   - TASK-07 사장 확인과 현재 명세 반영.
9. **현재 명세 반영:** 아직 아니다(완료 판정 뒤).
