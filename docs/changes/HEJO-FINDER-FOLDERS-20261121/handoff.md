# 설계 인계: HEJO-FINDER-FOLDERS / TASK-02 Finder 연결 서버 동기화 폴더 후보

칸·원본·쓰기 주체·수명은 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-02 / team-kit]
0. 기준: 이 저장소 main 9514f0f(제품 코드 기준) / 계획 문서는 이 인계서를 담은 커밋 / <운영 저장소> 66f2a44c /
   spec·design·수락 시험 명세·tasks 1판 2026-11-21 / 승인 상태: 사장 브레인스토밍 결정(brainstorm.md), 계획 검증 켬(검증 대기) /
   운영 모드: 연합개발(교차 모델 + 계획 검증). <운영 저장소>는 매일 자동 기록 커밋으로 움직이므로 착수 HEAD를 impl-report에 적는다.
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-FINDER-FOLDERS-20261121/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-FINDER-FOLDERS.md, <운영 저장소>/AGENTS.md, team-kit 개발 절차는
   docs/changes/HEJO-CONNECTIONS-20261120/design.md 7.1. ADR 없음.
2. 요구와 수락 기준: REQ-FF-01~04, NFR-FF-01·02(NFR-FF-03은 서버 적용 뒤 실측).
   핵심: Finder 연결 고르기 후보 = Synology Drive 뿌리(synology_setup.candidates) → 다른 CloudStorage 뿌리 → iCloud Drive,
   각 뿌리 아래 2단계까지, 숨김·심볼릭 링크·꾸러미 제외, 300개 상한(얕은 것부터)과 잘림 안내, 저장된 폴더는 상한 밖에서 유지·미리 선택,
   후보 0개일 때 Finder 전용 안내. 파일은 열지 않는다.
3. 유지할 기존 계약: 문·앱 프레임과 공개 필드(후보 {id,label,value}, next.hint, selected), Finder id/저장 값 = 서버 절대 경로,
   _requested_scope 수용(ddots 폴더 고르기 창), catalog.sync_folders 결과, 시놀로지 앱 연결 흐름, app connect 트랜잭션·되돌리기·
   바꾸기 모드(마지막 저장 전 쓰기 없음), 재확인 규칙, Hermes 본체·ddots·hejo gate/app 무수정.
4. 책임과 흐름: design 1절. Finder 후보 규칙은 app_setup.scopes() Finder 갈래 한 곳(함수 위치는 구현 담당), 빈 목록 hint는 app_connect 한 곳.
5. 기존 경로 판정: design 3절(교체 1, 유지 5).
6. 위험도: 일반(후보 목록만 늘어남, 인증·저장 경로 그대로). 필요 증거 수준 2(임시 HOME·HERMES_HOME, 가짜 폴더).
   롤백: worktree 브랜치 버림(운영 원본 무변경).
7. 변경 성격: 의미 변경(Finder 후보가 늘어남). 보존 비교: AT-FF-12(team-kit 기존 시험 전체, 기대값 수정 없음).
8. 수락 시험: tests/acceptance/HEJO-FINDER-FOLDERS.md AT-FF-01~13(M1~M3는 TASK-03 뒤 사장). 연결표는 같은 파일 끝.
   상태: 명세 완료·코드 미작성·미실행·계획 검증 대기. 기대값 출처: spec 요구, design 2절. 기대값·합격 기준을 바꾸지 말고,
   바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md TASK-02 영향 파일만. 절차는 HEJO-CONNECTIONS design 7.1 그대로:
   <운영 저장소> 착수 HEAD로 임시 worktree(브랜치 이름은 구현 담당), 바꿀 파일마다 실행본(<HOME>/plugin-store/team-kit/…)과 worktree
   기준 파일 sha256이 같은지 확인해 impl-report에 적는다(다르면 멈추고 보고). 게이트웨이 환경 Python + 임시 HOME·HERMES_HOME으로 시험.
   team-kit 기존 시험 전체와 ./airport-check(worktree에서 가능한 범위)를 돌린다. --rebaseline 금지.
   바뀐 파일을 게이트웨이 프로세스가 import하는지(재시작 필요 여부) 확인해 impl-report에 적는다(design 5절 [가정]).
   커밋은 worktree 브랜치에 자기 경로만(git commit --only). impl-report는 이 폴더의 impl-report.md(새 파일)에 쓴다.
   병렬 갈래: 없음(갈래 3개 미만: 코드 변경은 team-kit 한 갈래).
   금지 범위:
   - 실행본(<HOME>/plugin-store/team-kit) 교체, <운영 저장소> main 변경·./sync, 게이트웨이 재시작, 문 릴리스, 앱 빌드 교체·공개(TASK-03 이후, 별도 인계).
   - 운영 ~/.hermes의 .env·auth.json·토큰 파일·hejo/admin.json 열기, 운영에서 연결 실행.
   - 실제 서버 폴더(실제 Synology Drive·iCloud Drive)를 시험 입력으로 쓰기, 개인값(이름·계정·실제 경로)을 코드·시험·문서에 쓰기.
   - hejo gate/·app/·schemas/ 수정, Hermes 본체·ddots 수정, git push.
   - 수락 기준·수락 시험 명세·spec·design 본문 수정.
   선행 작업: 없음.
10. 가정·미확정:
    - [가정] 게이트웨이 재시작 불필요(design 5절). TASK-02가 확인.
    - [미확정] 실제 Synology Drive에서 후보 만들기 시간(NFR-FF-03). 착수 차단 아님(서버 적용 뒤 M1 실측).
    - [제안] 상한 300(design 2절 3항). 착수 차단 아님.
    - 함수 배치·내부 구조는 구현 담당이 정한다(design에 고정한 순서·제외 규칙·문장·상한 제외).
    착수 차단 없음.
11. 사용자 확인: 방향(A 먼저·B 따로, hejo는 다른 Mac에서만, 시놀로지는 동기화 폴더로)은 사장이 2026-11-21 질문 도구로 정했다(brainstorm.md).
    두 단계 목록으로의 구체화(탐색 화면 대신)는 계획 확인 때 사장이 함께 확인한다.

[인계 전 점검]
- 현재 코드·계약·명세가 기준 커밋과 호환되는가? 예(이 저장소 9514f0f, <운영 저장소> 66f2a44c에서 조사).
- G1–G4: G1 spec REQ·AC·범위 밖·사장 결정. G2 현황 근거(파일:줄), 칸 표, 기존 경로 판정. G3 AC↔AT 연결표, 계획 검증 대기.
  G4 위험도 근거·롤백, 기준 커밋, 미확정은 착수 비차단.
```
