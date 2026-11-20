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

## 검증 판정: HEJO-CONNECTIONS-20261120 — 2차 (보완 1 재검토)

1. **판정: 부분 완료.** TASK-02~04는 검토를 통과했고 V-1~V-3도 해결됐다. 서버 적용(TASK-05), 0.2.2 공개 준비(TASK-06), 사장 확인 M1~M7(TASK-07)은 아직이다.
2. **검증 조건:** 교차 모델. 검토 대상은 hejo `20adc4d`(앱 V-3, impl-report 보완 1), 운영 저장소 worktree `hejo-connections-20261120` `fe697e3b5a0805ec9ab80f63b2fcf9d3f3e53573`(V-1·V-2).
3. **설계 적합성(4.2):** design 4판은 REQ-HC-01~06을 충족한다. 직원 B의 실제 경우(틀린 자기 초안 + 다른 직원 완전 후보 1개)가 비밀번호만 묻는 로그인 단계로 이어지는지는 다음으로 확인했다.
   - 가짜 자료로 AT-HC-53(가)를 확인했다.
   - 구현 담당의 운영 읽기 전용 시뮬레이션은 주소 교체와 로그인 칸 전환까지만 봤다. 아이디 미리 채움은 비밀 파일을 열지 않으려고 꺼서 운영에서는 확인하지 않았다(M5에서 확인).
4. **직접 확인한 것(증거 수준 2):**
   - 코드 읽기:
     - `synology_setup.prepare()`: 자기 값은 `address_problems`가 비어 있을 때만 출처로 쓴다. 틀리면 `discover` → 완전 후보 1개면 교체, 여럿이면 `candidate_options` 고르기, 없으면 칸별 채움.
     - `app_connect.py`: 고르기에 `input_error`를 붙인다. 자동 교체일 때만 로그인 `hint`를 붙이고, 사람이 주소를 제출한 경우에는 붙이지 않는다.
     - 앱 `confirmUndo(label)`: 진행 중은 "처음부터 다시", 연결됨은 "마지막 연결 변경을 되돌릴까요?".
   - 시험 교체 2건은 승인된 4판의 반대 기대였던 것이라 정당하다: 3판의 "틀린 자기 초안은 다른 출처를 보지 않음", AT-HC-50의 번호 라벨 기대.
   - AT-HC-53(가)는 실제 `app undo`로 초안 칸·진행 기록이 사라지는지 본다. 수락 시험 명세·spec·design은 바뀌지 않았다.
   - team-kit(worktree, 임시 HOME) `test_connections_screen.py` 외 4개 파일: 종료 0, 111 통과. 그중 AT-HC-53·54 4사례 통과. 로그 `.build/verify/teamkit-s1.log`.
   - 전체 `bash scripts/test.sh`(대상 `20adc4d` + worktree `fe697e3b` lib): 종료 0, Python 381 통과, 앱 시험 통과. 로그 `.build/verify/full-s1.log`.
   - 구현 담당 보고 중 직접 다시 하지 않은 것(로그로만 확인): `airport-check` 종료 0, 관련 27개 파일 451 통과, V-1 mutation 검출.
5. **지적 처분:** V-1 수정 수락, V-2 수정 수락, V-3 수정 수락. 새 지적 없음.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위와 남은 위험:**
   - 운영 적용과 M1~M7.
   - 운영 아이디 미리 채움(M5).
   - 직원 A의 400 원인(M2).
   - team-kit 확장 전체 시험의 운영 HOME 의존 실패(이번 범위 밖, 기록만).
8. **남은 조건:** TASK-05 서버 적용(handoff "보완 지시 2"), TASK-06 0.2.2 공개 준비, TASK-07 사장 확인과 현재 명세 반영. 원인 분류는 해당 없음(남은 것은 계획된 후속 작업).

## 검증 판정: HEJO-CONNECTIONS-20261120 — 3차 (TASK-05 서버 적용)

1. **판정: 부분 완료.** TASK-05는 통과했다. 0.2.2 공개 준비(TASK-06)와 사장 확인 M1~M7(TASK-07)은 아직이다.
2. **검증 조건:** 교차 모델. 검토 대상은 다음과 같다.
   - hejo `713d4ad`(TASK-05 보고만 추가, 제품 코드는 `1c6b3e2`와 같다)
   - 운영 저장소 main `7ae2b0138725ad7cde44d4842950d2ffb7cc99b8`
   - 공용 릴리스, 운영 실행본, 운영 게이트웨이
3. **설계 적합성(4.2):** design 7.2 순서대로 적용했다. 롤백 기록 → team-kit sha256 재확인·보관·교체·읽기 확인 → 운영 저장소 sync·커밋 → 문 릴리스 → BUSY 거절이 있는 표준 재시작 → 확인.
4. **직접 확인한 것(읽기만, 증거 수준 3):**
   - 공용 릴리스 `RELEASE` = `1c6b3e2`이고, 공용 `gate/`가 `1c6b3e2`의 `gate/`와 같다(시험·캐시 폴더 제외, `diff -rq`).
   - team-kit 변경 11개 파일의 운영 실행본 sha256 = worktree `fe697e3b` = 운영 저장소 `7ae2b013`.
   - `7ae2b013`은 자기 12개 경로만 담는다. `docs/연결-상태.md` 변경은 worktree 판과 같다.
   - 게이트웨이 pid 31964가 hejo 문 포트를 LISTEN 중이다.
   - `hermes-connections status --json`·`apps --json` 모두 종료 0, 직원 6명·앱 80개.
   - impl-report TASK-05 "적용 전 롤백 기록"에 이전 RELEASE·pid·파일별 sha256·보관 폴더·복원 명령이 실제 값으로 있다.
   - `gateway.log`에 `connections_part_failed`·`connections_failed` 줄은 아직 없다. 재시작 뒤 연결 창을 연 요청이 없었던 것으로 보이며, M2에서 확인한다.
5. **지적:** 없음.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위:** M1~M7(0.2.2 설치 뒤). 0.2.1 앱은 새 문에 붙어도 실패를 여전히 "관리 기능 꺼짐"으로 표시한다(TASK-06에서 해소).
8. **남은 조건:** TASK-06(handoff "보완 지시 3"), TASK-07.
