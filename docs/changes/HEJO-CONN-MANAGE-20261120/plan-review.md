# HEJO-CONN-MANAGE 계획 검증 기록

## 1회차 (2026-11-20)

- 대상: 계획 1판(커밋 `5a8117c`), planHash `86c8a90f1097b831052b863a1a264fe3ce579ff9bd3ee258aac0399d170126c1`
- 판정: BLOCKED(차단 5, 권고 2)
- 처리: 7건 모두 수용. 지적마다 `<운영 저장소>` `7ae2b013` 코드에서 사실을 다시 확인하고 2판(spec·design·수락 시험 명세·tasks·handoff)에 반영했다.

| ID | 등급 | 처리 | 확인한 사실과 이유 | 반영 위치 |
|---|---|---|---|---|
| PR-01 | 차단 | 수용 | [확인] `synology_setup.py:276-277`은 주소가 비면 `legacy_values(config)`로 다시 채우고, `app_connect.py:542-558`은 주소가 완전하면 주소 단계를 내지 않는다. 1판처럼 키만 지우면 주소 바꾸기가 옛 주소로 건너뛴다. 자동 찾기(처음 연결)와 명시적 바꾸기는 다른 계약이어야 한다. | design 2.2 흐름 계산 규칙 2(바꾸는 단계는 그 단계 값이 요청에 없으면 반드시 그 단계 응답, 주소는 `prepare` 자동 채우기를 쓰지 않고 지금 주소를 미리 채운 칸), spec REQ-CM-03.AC-02, AT-CM-40 |
| PR-02 | 차단 | 수용 | [확인] `app_connect.py:53-57` `steps_from`의 `login`은 시놀로지만, `app_setup.py:51-59`는 입력 열쇠가 없으면 저장 열쇠로 확인하고 통과시킨다. 합친 Notion 줄에서 열쇠를 바꿀 길이 없어진다. | design 2.1 표에 `login`(Notion "로그인 열쇠", `.env` `NOTION_API_KEY`), 2.2 규칙 2(`login`은 저장 값으로 확인하지 않고 자격 칸을 냄, `candidate_values`로 쓰기 없이 확인), spec REQ-CM-03.AC-02, AT-CM-41 |
| PR-03 | 차단 | 수용 | [확인] `app_connect.py:317-366` `stage_values`는 `choosing` 중에도 비밀값을 실제 `.env`에 쓴다. 1판의 "저장 전 연결 유지"와 모순이다. 또 `:328`은 앞 연결의 되돌리기 기한 안에서는 초안 저장을 막는다(`CONNECTION_IN_PROGRESS`). | design 2.2: 바꾸기 모드는 마지막 `transact` 전까지 어떤 파일도 쓰지 않음, 앱이 세션 값을 메모리에 모아 요청마다 다시 보냄(5절), 문이 세션 동안 보안 칸 보호 목록을 누적. spec 1절 5c, REQ-CM-03.AC-04, 칸 표(세션 값=앱 메모리). AT-CM-06(전체 sha256), AT-CM-42(새 비밀번호 제출 뒤 멈춤), AT-CM-28(문 가림), AT-CM-38(앱 값 모으기·비우기). design 6절에 `stage_values` 유지(처음·다시 연결 전용)·`input_fields` 교체 |
| PR-04 | 차단 | 수용 | [확인] `app_connect.py:38-44` `read_record`는 600초 뒤 `undo`를 지운다. 1판은 다시 연결도 전 바이트 복원에 기대어, 10분 뒤 Google 스킬 상태를 잃고, 해제 뒤 바뀐 다른 설정을 덮어쓸 수 있었다. | design 3.2(해제가 넣은 스킬을 같은 `config.yaml`의 `gmail.off_added_skills`에 표시, 칸·쓰기 주체·수명 명시, 되돌리기 기록과 분리), 3.3(해제·연결은 칸 단위로 고침, 되돌리기는 기존 지문 충돌 거절만), spec 칸 표·REQ-CM-02.AC-03, AT-CM-10(11분 뒤 연결·관계없는 칸 보존), AT-CM-14(네 경우) |
| PR-05 | 차단 | 수용 | [확인] `discovery.py:130-141`은 연결 판정 전에 서비스 기준으로 `links`를 만들고 미연결 항목에도 복사한다. 1판 조건이면 설치만 된 앱 때문에 옛 계정 줄이 사라진다. | design 4절 합치기 조건 2(연결됨·진행 중·계정 줄 꺼짐일 때만), spec REQ-CM-04.AC-02, AT-CM-23(실제 모양: 설치만 된 앱 + `links`), AT-CM-23b |
| PR-06 | 권고 | 수용 | [확인] 1판 spec REQ-CM-01.AC-01은 "설정 단계 없으면 확인", design 2.4·AT-CM-20은 "합칠 계정 줄 없으면 주 동작 없음"으로 달랐다. AT-CM-09는 `account_connect` 하나만 기대해 design 3.1의 10분 되돌리기와 충돌했다. | spec REQ-CM-01.AC-01을 design 2.4·3.1 표에 맞춤, design 3.1 되돌리기 문장 명확화, AT-CM-09(10분 안 {연결, 되돌리기}, 지난 뒤 {연결}) |
| PR-07 | 권고 | 수용 | [확인] 1판은 CM-02.AC-04·05의 앱 쪽, CM-06, team-kit 출력의 비밀값 검사가 구체 시험에 이어지지 않았고, 계정 기록의 칸이 표에 없었다. Google Drive 미확인은 G4를 막는 조건이었다. Google 미확인은 이번에 본체 코드를 읽기만 해서 해소했다: [확인] Drive·Sheets·Docs는 본체 스킬 `google-workspace`(`skills/productivity/google-workspace/SKILL.md`), 본체가 직원 홈 `config.yaml`의 `skills.disabled`를 지킨다(`agent/skill_utils.py:261-273`). | spec 칸 표(계정 기록·스킬 표시·세션 값), AT-CM-17(앱 해제 실패·되돌리기), AT-CM-18(출력·로그·기록 파일 비밀값), M5(공개 준비), 수락 시험 명세 끝 AC↔시험 연결표, design 3절 [확인]·[확인된 한계](토큰 파일 직접 읽기까지 막는 경계는 아님), handoff 10항(착수 차단 해소) |

반박한 지적과 보류한 지적은 없다.

## 2회차 (2026-11-20)

- 대상: 계획 2판(커밋 `fc959cc`), planHash `7bbed3ac3756c66252b3f6a96375d2222901b3f725881ce6862e287943f49460`
- 판정: BLOCKED(차단 1, 권고 2)
- 처리: 3건 모두 수용. 3판(spec·design·수락 시험 명세·tasks·handoff)에 반영.

| ID | 등급 | 처리 | 확인한 사실과 이유 | 반영 위치 |
|---|---|---|---|---|
| PR-08 | 차단 | 수용 | [확인] 앱은 후속 `next` 단계도 같은 동작으로 제출하고(`app/Sources/ConnectionsWindow.swift:133-136,161-166`), team-kit은 값이 있으면 `pending`을 거짓으로 보고(`app_connect.py:515`) 다시 `transact`한다(`:639-640`). 2판은 "완료·실패까지 값을 모아 다시 보냄"이라 저장 뒤 재개 때 다시 저장되어 되돌리기 기준이 바뀐 값으로 덮일 수 있었다. | design 2.2 "저장 전과 저장 후": `transact` 성공 응답에 `committed: true`(새 공개 필드), 앱은 그때 모은 값·`change`를 지우고 재개는 `resume`만, team-kit은 `--change`+`--resume`을 거절. design 5절, spec REQ-CM-03.AC-05, AT-CM-44(저장→다시 시작 대기→재개→완료→되돌리기, 재개 중 `transact` 0회, 되돌리기 전 바이트 유지), AT-CM-38(재개 프레임에 `change`·비밀번호 없음) |
| PR-09 | 권고 | 수용 | [확인] 앱의 창 닫기는 앱 안 상태만 지우고(`ConnectionsWindow.swift:97-101,113`), 문에 알리는 계약은 없다. 문 보호 목록 열쇠는 `(device, profile, connection)`이고 응답마다 덮어쓴다(`gate/connection_manager.py:247,258`). 목록에는 칸 id만 있어 창 닫힘 알림 없이도 다음 요청 경계로 정리할 수 있다. | design 2.2 "문 보호 목록의 세션 경계"(누적 조건, 비움 조건: 새 세션 시작·`change` 없음·`committed`·실패/거절·기기 끊김, 진행 중 요청은 시작 때 계산한 가림 유지), AT-CM-28을 (가)~(사)로 확장 |
| PR-10 | 권고 | 수용 | [확인] 2판 AT-CM-14는 본체 함수를 못 부르면 설정 목록 검사로 대신하게 해, 설정 검사(증거 수준 2)와 본체 소비자 확인을 섞었다. M4는 메일 요청만 관측했다. | AT-CM-14는 설정 파일 기대값만, 새 AT-CM-14b(본체 `get_disabled_skill_names`를 가짜 홈으로 실행, 못 하면 `[미실행]`이고 통과로 세지 않음), M4에 그 직원 홈 기준 스킬 목록 읽기 확인 추가(없으면 기록하고 메일 답만으로 통과 처리 안 함), AC↔시험 표, handoff 9항 |

반박한 지적과 보류한 지적은 없다.

## 3회차 (2026-11-20)

- 대상: 계획 3판(커밋 `da45925`), planHash `0d2978f0360c2d935159d6ccb5d8fa66340b98830db4ab20810fe84b02e924ec`
- 판정: APPROVED(지적 없음)
- 처리: 지적이 없어 수용·반박·보류할 항목이 없다. 계획 3판을 그대로 유지한다. 계약7 사전 검토(교차 모델)는 통과다(10-planning STEP 5, G3).
