# 계획 검증 기록: HEJO-FOUNDATION 14판(TASK-20·21·22) — 작업 56917a17

이 작업은 HEJO-FOUNDATION을 이어 가는 Paseo 작업이다. 명세·설계·인계의 원본은 [HEJO-FOUNDATION-20261114](../HEJO-FOUNDATION-20261114/)에 있고, 이 파일은 이번 계획 검증의 처분만 기록한다.

## 1회차 (2026-11-15)

- 대상 planHash: `c0e1dd66d85f873942cd95648cc1b25babf8d51c1f149ef766e4327d3ed92eae`. 판정: BLOCKED(차단 4).
- 대상 기준 커밋: `48c4e6e`(23차 판정 뒤).

| ID | 처분 | 이유 | 반영 위치 |
|---|---|---|---|
| R1 설치 영수증이 있는 공항의 갱신 경로 없음 | **수용** | `install/hejo-install` `run()` 481~511: `installed`면 바로 끝나고 `--check`도 영수증 대상만 본다. 새 설치 시험만으로는 운영 공항(이미 설치)에 home_channel이 안 들어가도 통과한다. | design 'hejo 홈 채널' 절(영수증 대상, 갱신 경로, 갱신 중 실패는 키 단위 되돌림·파일 전체 복원 금지, 남은 `pending`/`applied` 처리, 제거 때 사장 값 보존 `preserved_owner_change`, `--check`의 `missing_target`/`owner_set`), spec REQ-HF-25.AC-01, AT-HF-72, handoff 14-1 |
| R2 단체방 삭제의 부분 실패·재시작·늦은 응답 계약 없음 | **수용** | `gate/journal.py` 80~112는 한 줄 추가만 원자적이다. 글마다 `delete`를 쓰는 설계는 중간 실패 때 부분 삭제가 남는다. | 설계 변경: `room_delete` 한 줄을 확정점으로 하고 글마다 delete 기록을 없앰, 재현·조회에서 지운 방 제외, 지운 방 id 묶음으로 늦은 답·작성 중·직원 첨부 버림, 지운 방 id 거절, 확정 뒤 멱등 파일 정리(`FileStore.cleanup`이 지운 방 기록을 살아 있지 않은 것으로 셈), 비가역 범위(첨부·사진 복구 불가, 기록장 원문 바이트는 남음) 명시. design 14판 '삭제 계약'·'위험·롤백', spec REQ-HF-24.AC-03, AT-HF-70(고장 주입·재시작·늦은 응답·재연결·첨부 보존), handoff 14 |
| R2 보충(계획 담당 발견) | 반영 | TASK-21 이전 문 코드는 모르는 기록 종류를 손상으로 보고 기록장 열기를 거부한다(`_recover`의 `RECORD_TYPES`). 그래서 문 코드만 되돌리는 롤백은 불가능하다. | design '위험·롤백': 운영 적용 전 `shared/hejo/` 사본, 롤백 = 이전 릴리스 + 사본 복원. handoff 보완 15 TASK-23 |
| R3 사진이 금고(`hejo/`)에 놓여 근간 칸과 어긋남 | **수용** | 근간 3절에서 `<HOME>/hejo/`는 사장 금고(출입증·포트)이고 앱 대화 자료는 공용 창고(`shared/`, 문 단독 쓰기)다. 사진은 대화 화면 자료이므로 공용 창고가 맞다. | 사진 위치를 `<HOME>/shared/hejo/pictures/`로 옮김. spec 칸 표에 사진·단체방 기록·구획·홈 채널 4행 추가(쓰기 주체·수명·방 삭제 때 수명 포함), design 14판 칸 배치, AT-HF-68 기대값, handoff 14 |
| R3 보충 | **보류(사장 승인 필요)** | 허브(`hub/`, 11판 승인)는 design에만 있고 근간 3절 표에는 행이 없다. 이번 구획은 이미 승인된 고정·알림·숨김과 같은 회원 설정 자리를 써서 새 원본을 만들지 않는다. 근간 문서 변경은 사장 승인이 필요하므로 이번 구현을 막지 않는다. | spec 칸 표 아래 주석. HEJO-FOUNDATION 종료 때 근간에 허브 행 추가 승인 요청 |
| R4 위험·증거·완료 경계 불일치 | **수용** | tasks(일반·높음 3)와 design(수준 4), 인계(대역까지)가 서로 달랐다. 공통 4절 기준으로 TASK-20(인증된 영구 저장·삭제), TASK-21(규격·전달·삭제·동시성), TASK-22(운영 게이트웨이 설정 변경)는 고위험이다. | handoff 보완 15: 세 TASK 고위험, 구현 인계 완료 = 수준 2, 최종 수락 = 수준 4(TASK-23). 계획 담당 판정은 최대 '부분 완료'이고, 비설계자 검토(30-verification 2절) 뒤에 완료한다. TASK-23(계획 담당 + 사장): 사본 → 릴리스 → 운영 설치 갱신 → 사장 확인 재시작 → 관측 → 롤백 절차. tasks.md 위험 칸·TASK-23 행 |

- 반박: 없음.
- 확인한 근거(읽기 전용): Hermes 본체 `gateway/config_loader.py` `merge_platform_sections` 140~174. `gateway.platforms.*` 다음 최상위 `platforms.*`를 키 단위로 얕게 병합하므로, 최상위 `platforms.hejo.home_channel`만 더해도 설치 도우미의 `gateway.platforms.hejo` `enabled`·`extra`가 지워지지 않는다. `gateway/config.py` `persist_home_channel`(`/sethome`)도 같은 최상위 자리에 쓴다.

## 2회차 (2026-11-15)

- 대상 planHash: `a1e915f95b18dbf4243c99e720c4214d2d48788e824ec4027f04fbd787dae456`. 판정: BLOCKED(차단 2). 기준 커밋 `da7341e`.

| ID | 처분 | 이유 | 반영 위치 |
|---|---|---|---|
| R1-2 갱신 중단 복구에서 `pending`+값 `after`, `pending`+사장 값 누락 | **수용** | 현재 `run()`은 config 적용(521~522)과 `applied` 영수증 저장(524) 사이에 끊길 수 있다. `restore()`는 `pending`을 건너뛰므로(441~445) 그 상태면 제거가 키를 남긴다. | design 'hejo 홈 채널': 쓰는 순서(대상 `pending` 영수증 먼저 → config → `applied`), 모든 명령이 먼저 하는 맞춤 표(pending/applied × 없음/after/다른 값), `released` 상태. AT-HF-72: 중단 3지점 주입 뒤 다시 실행·제거 기대값. spec REQ-HF-25.AC-01 |
| R5 롤백이 사장 값까지 지울 수 있음 | **수용** | 15판 롤백("키만 삭제")은 15판 보존 계약과 충돌한다. | 손 삭제를 없애고 `--uninstall-home-channel` 명령으로 바꿈: 맞춤 뒤 영수증 대상 중 `applied`이고 값이 `after`인 것만 지우고 `removed`로 표시, 나머지는 보존·보고, 다른 hejo 대상과 `installed`는 그대로. AT-HF-72에 A(설치 전 사장 값)·B(적용 뒤 변경)·C(그대로) 롤백 사례 추가. handoff 보완 15의 5번·14-1 |

- 반박: 없음.

## 3회차 (2026-11-15)

- 대상 planHash: `b30acc7f020bb22cfbebc59be4d1183fb4c27566fcae1f9b0acda82e2d642748`. 판정: **APPROVED**(권고 1). 기준 커밋 `2a6e8ec`.

| ID | 처분 | 이유 | 반영 위치 |
|---|---|---|---|
| C1(권고) 롤백 종료 코드에 config 읽기·키 삭제 실패 처리가 분명하지 않음 | **수용(검증 기준으로)** | design의 "영수증은 실제 config와 맞춘 상태로 저장한다"는 계약에 이미 따라 나오는 내용이다. 삭제가 실패한 대상을 `removed`나 성공으로 기록하면 계약 위반이다. 계획 문서를 다시 바꾸면 승인된 계획 해시가 달라진다. 그래서 문서는 그대로 두고 TASK-22 판정 기준에 넣는다. | TASK-22 검토 때 확인할 것: `--uninstall-home-channel`에서 config 읽기·쓰기 실패가 나면 그 대상은 `applied`로 남고 `removed`가 되지 않는다. 이때 종료 코드는 1이다. 실패 사례를 시험 하나로 넣었는지 impl-report에서 확인한다. 없으면 비차단 지적으로 보완을 요청한다. |

- 계획 유지. 구현 인계 대상은 `2a6e8ec` 기준 TASK-22 → TASK-20 → TASK-21이다.
