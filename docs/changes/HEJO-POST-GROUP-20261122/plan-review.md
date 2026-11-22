# HEJO-POST-GROUP 계획 검증 기록

## 1회차 (2026-11-22)

- 대상: 계획 1판(커밋 `dc7a4c4`), planHash `2aa6325993a3a75c43deace16991bd2e71bc10a7c33ef0b50c3406ab69bb6866`
- 판정: BLOCKED(차단 1, 권고 2)
- 처리: PG-R1 수용, PG-R2 일부 수용(점검표)·일부 반박(링크), PG-R3 수용 → 계획 2판(spec 2판, 수락 시험 2판, handoff·tasks 갱신)

| ID | 등급 | 지적 요약 | 처리 | 이유와 반영 위치 |
|---|---|---|---|---|
| PG-R1 | 차단 | AT-PG-05가 "구성이 다르면 그 구성의 값"을 허용해 화면 인접만 보고 묶는 잘못된 구현을 못 잡는다. AT-PG-02는 답글 3개라 기본 접힘에서 기대값이 성립하지 않는다 | 수용 | 맞다. `ConversationView.swift:902-904`는 답글 3개 이상이면 접고 마지막·버튼 글만 보인다. (1) 수락 시험 공통 준비에 "답글 3개 이상은 따로 적지 않으면 펼친 상태, 검사 전 `.stack` 없음 확인"을 넣었고 AT-PG-02에 펼침을 명시했다(AT-PG-11도 이 기본을 따른다). (2) AT-PG-05를 고정했다. A1 = 응답 버튼 하나가 있는 alpha 글(굵은 글씨 없음 → 나눔 없음, `ThreadAssessment.assess`에서 답 없는 유일한 요청이라 `buttons`에 들어감, `ThreadTools.swift:94-111`), A2 = alpha 일반 마지막 글. 가운데가 (가) beta 글 (나) alpha 글인 두 사례. 전제(더미 1개, 보이는 글 id가 정확히 [A1, A2])를 먼저 assert하고 안 맞으면 실패. 기대는 둘 다 [(A1,false),(A2,false)]. (가)는 "화면에서 이웃하면 묶기", (나)는 "보이는지 확인 없이 타임라인 앞 글만 보기" 잘못을 각각 잡는다 |
| PG-R2 | 권고 | ARCHITECTURE 8절 점검표가 spec·handoff에 없다. 수락 시험 상대 링크가 한 단계 모자라다 | 점검표 수용 / 링크 반박 | 점검표: spec.md 첫 절에 "칸·원본·쓰기 주체·수명" 표와 8절 다섯 물음 점검을 넣었다(관제 화면 칸, 개발, 앱 갱신 때 교체, 결과 저장 없음, 입력은 기존 기록장 읽기만). handoff 1항에서 참조한다. 링크: `docs/changes/HEJO-POST-GROUP-20261122/`에서 `../`=docs/changes, `../../`=docs, `../../../`=저장소 뿌리이므로 `../../../tests/acceptance/HEJO-POST-GROUP.md`가 맞다. [확인] 그 폴더에서 `ls ../../../tests/acceptance/HEJO-POST-GROUP.md` 성공, 제안한 `../../../../tests/...`는 "No such file". 링크는 바꾸지 않는다 |
| PG-R3 | 권고 | 핵심 문제는 작업 도중 전환 시점에 이름이 둘 보이는 것이므로 파일 → typing → 생각 중 → 스트리밍 edit → final 전환마다 머리 수·작업 줄 수를 보는 회귀 시험이 필요하다 | 수용 | 맞다. AT-PG-13을 추가했다. 한 스레드에서 (1) 파일 글 (2) typing on (3) 생각 중 글 (4) `edit final:false` (5) `edit final:true` + typing off를 차례로 넣고 단계마다 "alpha 이름 머리 수"(묶이지 않은 alpha 글 + Alpha 입력 머리) == 1, 작업 줄 수 0/1/1/1/0, 글 목록, 끝에서 시간 툴팁을 본다. edit가 `streaming = !final`, `finalized = final`로 바뀌는 것은 `ConversationModel.swift:316` [확인]. spec PG-02.AC-04에 "edit로 본문이 바뀌어도 기준 같음"을 적었다 |
