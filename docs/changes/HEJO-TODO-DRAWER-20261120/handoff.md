# 설계 인계: HEJO-TODO-DRAWER / TASK-02~04 왼쪽 할 일 칸

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음, 두 번째 원본 없음. 마감은 읽기만 한다.

```text
[설계 인계: HEJO-TODO-DRAWER TASK-02~04 / team-kit·문·앱]
0. 기준: 제품 코드 기준 63cbe2a(이 저장소 main), 운영 저장소 7ae2b013 / spec·design·tasks·수락 시험 1판 /
   작성 2026-11-20, 2판(계획 검증 1회차 반영, plan-review.md) / 승인: 사장 결정 5개(brainstorm.md) + 계획 승인 대기(이 plan) / 운영 모드: 연합개발(교차 모델 기본)
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-TODO-DRAWER-20261120/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-TODO-DRAWER.md. team-kit은 <운영 저장소>/AGENTS.md와 ./airport-check 규칙.
2. 요구와 수락 기준: REQ-TD-01~06, NFR-TD-01~03(REQ-TD-07 서버 적용·공개는 이번 지시 밖).
   정상: 알약 사장 차례 칸·빈 알약으로 칸 토글, 창이 왼쪽으로 290pt 늘어나고 0.25초, 답 요청·알림·마감 카드.
   핵심 실패: 왼쪽 자리 없음 → 덮기, team-kit 없음 → 마감 숨김, 읽기 실패 → 마지막 목록 + 회색 줄.
3. 유지할 기존 계약: 기존 프레임·필드 불변(v 1, 새 type만 추가), deadline_watch 장부 형식·쓰기·Slack 보고 불변,
   hermes-connections 명령 표 불변, notices() 결과 불변, PetPlacement leading=0일 때 기존 결과 동일,
   직원 얼굴·문제 칸 클릭 동작 불변, 사장 칸 미리보기 중 클릭은 가장 오래된 질문으로(IslandModel.swift:143, IslandTests AT56 불변).
4. 책임과 흐름: design 1절. 마감 뜻 = team-kit deadline_watch, 실행 경계·이유 코드 = 문 Deadlines,
   카드 묶기·문장 = 앱 TodoDrawerModel, 창 배치(늘림/덮기 판정) = PetPlacement 하나.
5. 기존 경로 판정: design 6절(교체 1: 사장 차례 칸 클릭 → Action.drawer, 옛 할당 제거. 나머지 유지·확장).
6. 위험도: TASK-03 문은 고위험(동시성: 문 전체 공유 실행·연결 종료 취소·자식 프로세스 회수, design 3절 계약) → 다른 모델 독립 검증 필수,
   복구는 문 릴리스 롤백(TASK-05). TASK-02·04는 일반. 필요 증거 수준 2. TASK-05·06은 고위험(이번 지시 밖).
   응답 허용 필드와 로그·문서·시험 금지 범위는 NFR-TD-01(2판)로 구분했다.
7. 변경 성격: 의미 변경(알약 사장 차례 칸 클릭의 결과). 보존 비교: AT-TD-05·17·28·29·38, bash scripts/test.sh 전체.
8. 수락 시험: tests/acceptance/HEJO-TODO-DRAWER.md 2판 AT-TD-01~05(team-kit), 10~19(문), 20~41(앱).
   기대값 출처 spec·design. 상태: 명세 완료·코드 미작성·미실행·계획 검증 1회차 BLOCKED 반영, 재검증 대기.
9. 작업 범위: tasks.md TASK-02·03·04 영향 파일만. TASK마다 별도 커밋(git commit --only로 자기 경로만),
   impl-report.md에 TASK별 절. 금지: 운영 공항(~/.hermes) 파일 변경·게이트웨이 재시작·운영 team-kit 원본 수정
   (team-kit은 <운영 저장소> 임시 worktree에서만, 착수 때 기준 sha256 기록), Hermes 본체, ddots, 비밀 파일 열기,
   실제 Slack·고객 메시지, git push. 병렬 갈래: 있음(tasks.md 표, team-kit/문/앱 파일 겹침 없음).
10. 가정·미확정: [가정] 사장 Mac 시간대 = deadline_watch KST(D-day 표시). [미확인] 운영 장부의 source 실제 형태
    (링크 아니면 직원 방 이동으로 처리, 차단 아님). 창 배치 세부(움직임 곡선, 막의 투명도)는 구현 자유.
    시안 v28은 참고일 뿐 기준이 아니다. 착수 차단 없음.
11. 사용자 확인: 칸 내용·여는 곳·웹 칸 동시·출처·칸 배치 '가'는 사장 답(brainstorm.md). 범위·AC는 이 plan 승인으로 확인.

[인계 전 점검]
- 현재 코드·계약·명세가 base 63cbe2a와 호환: 예(작성 시점 main HEAD, 미추적 문서는 HEJO-CONN-MANAGE 계획뿐).
- G1–G4: 요구·범위·제외 확정, 현황 근거(spec 1절), 경로 판정, AC↔시험 연결, 위험·증거 수준 지정. 통과.
```

## AC ↔ 시험

| AC | 시험 |
|---|---|
| TD-01.AC-01·03 | AT-TD-27·41 |
| TD-01.AC-02 | AT-TD-28·29 |
| TD-01.AC-04 | AT-TD-30 |
| TD-02.AC-01 | AT-TD-31 |
| TD-02.AC-02 | AT-TD-32 |
| TD-02.AC-03 | AT-TD-33 |
| TD-02.AC-04 | AT-TD-34 |
| TD-02.AC-05 | AT-TD-35 |
| TD-03.AC-01·02 | AT-TD-20 |
| TD-03.AC-03 | AT-TD-21 |
| TD-03.AC-04 | AT-TD-22 |
| TD-03.AC-05·06 | AT-TD-23·37·39 |
| TD-04.AC-01 | AT-TD-25·39 |
| TD-04.AC-02·03 | AT-TD-26 |
| TD-05.AC-01 | AT-TD-01·10 |
| TD-05.AC-02 | AT-TD-11·24 |
| TD-05.AC-03 | AT-TD-12·24 |
| TD-05.AC-04 | AT-TD-02·13·40 |
| TD-05.AC-05 | AT-TD-03 |
| TD-06 | AT-TD-36 |
| NFR-TD-01 | AT-TD-10(응답 허용 필드)·15(로그), 개인값 검사 |
| NFR-TD-02 | AT-TD-14·18·19 |
| NFR-TD-03 | AT-TD-37 |
| TD-07 | M1·M2(TASK-05), TASK-06 |

## 구현 담당 보고

`impl-report.md`에 TASK별로 아래를 적는다.
- 바꾼 파일과 커밋.
- 시험 명령, 종료 코드, 로그 경로(`.build/` 아래).
- 도달 증거 수준.
- 남은 문제.
- team-kit worktree 경로와 커밋.

검사 명령:
- `bash scripts/test.sh`
- `python3 scripts/scan_private.py`. 둘 다 Hermes venv 파이썬(`~/.hermes/installs/*/environments/*/venv/bin/python`, `HEJO_PYTHON`)으로 실행한다. 시스템 python3에서는 `scan_error`로 실패한다.
- `HD` 쪽은 `./airport-check`.
