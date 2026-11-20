# 설계 인계: HEJO-CONN-MANAGE / TASK-02~04 연결 해제·설정 바꾸기·확인 창 뒤 창 유지

칸·원본·쓰기 주체·수명은 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-CONN-MANAGE TASK-02~04 / team-kit·문·앱]
0. 기준: 제품 코드 기준 63cbe2a(이 저장소 main) / 계획 문서 기준은 이 인계서를 담은 커밋 / <운영 저장소> 7ae2b013 /
   spec 3판·design 3판·수락 시험 명세 3판·tasks 3판 2026-11-20(계획 검증 1회차 7건·2회차 3건 반영, plan-review.md) /
   승인 상태: 사장 브레인스토밍 결정(brainstorm.md) 기반, 계획 검증 켬(재검증 대기) / 운영 모드: 연합개발(교차 모델 + 계획 검증)
   <운영 저장소>는 매일 자동 기록 커밋으로 움직인다. 착수 때 HEAD를 impl-report에 적는다.
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-CONN-MANAGE-20261120/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-CONN-MANAGE.md, <운영 저장소>/AGENTS.md, <운영 저장소>/docs/연결-상태.md,
   team-kit 개발·적용 절차는 docs/changes/HEJO-CONNECTIONS-20261120/design.md 7.1·7.2. ADR 없음.
2. 요구와 수락 기준: REQ-CM-01~05, NFR-CM-01~03(REQ-CM-06 공개는 이번 지시 밖).
   핵심: 앱·계정 줄에 연결/설정 바꾸기/해제. 해제는 값(금고·.env·토큰)을 남기고 연결만 끊으며 다시 연결은 남은 값으로 바로.
   설정 바꾸기는 기존 연결 단계를 저장 값으로 다시 열어 고른 단계를 반드시 열고, 마지막 저장 전까지 서버에 아무것도 쓰지 않는다. 시놀로지·Notion 계정 줄은 앱 줄로 합친다.
   지문·암호 확인 뒤에도 연결 창이 앞에 남는다.
3. 유지할 기존 계약: 문↔앱 성공 프레임 모양(새 필드 settings만 추가), 기존 줄 id·동작 id(새 동작 account_connect·
   account_disconnect·account_undo 추가, app_connect 라벨만 바뀜. 새 응답 필드: settings, committed, 계정 줄 off 상태), connection_result outcome 값 목록, public() 허용 원칙,
   team-kit status·apps 읽기 전용, app connect/disconnect/undo 트랜잭션·되돌리기 규칙, 비밀값 표준 입력, 재확인(reauth) 규칙,
   team-kit status 출력의 줄(합치기는 문 표시에서만), 처음 연결·다시 연결의 입력 초안(stage_values) 동작, Hermes 본체 무수정, ddots 무수정.
4. 책임과 흐름: design 1절. 동작·설정 단계·꺼짐 칸은 team-kit 한 곳(단계 표 design 2.1, 꺼짐 칸 표 design 3.1), 줄 합치기는 문
   document() 한 곳, 그리기와 확인 순서는 앱 한 곳.
5. 기존 경로 판정: design 6절(교체 4, 유지 2, 통합 2).
6. 위험도: 고위험(Google 개인·회사 담당 범위 끄기, 자격 값 흐름, 운영 시설 변경). 필요 증거 수준 2(임시 HERMES_HOME + 가짜 명령·
   가짜 문서). 운영 적용(3)·실물(4)은 TASK-05~07.
   롤백: 이 저장소 커밋 되돌림. team-kit·team-delegation은 운영 원본을 바꾸지 않으므로(worktree 브랜치) 그 브랜치를 버리면 된다.
7. 변경 성격: 의미 변경(동작·라벨·흐름·꺼짐 칸 추가). 보존 비교: AT-CM-16·27·37 회귀, `bash scripts/test.sh` 전체,
   꺼짐 칸이 없는 지금 설정에서 등록·호출이 같음(AT-CM-12 켜짐 대조).
8. 수락 시험: tests/acceptance/HEJO-CONN-MANAGE.md AT-CM-01~18·14b, 40~44, 20~28·23b, 30~38(사장 확인 M1~M5는 TASK-05~07).
   AC↔시험 연결표는 같은 파일 끝. 상태: 명세 완료·코드 미작성·미실행·계획 검증 재검토 대기.
   기대값 출처: spec 요구, design 2~5절. 기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md TASK-02·03·04 영향 파일. TASK마다 별도 커밋(이 저장소는 git commit --only), impl-report.md에 TASK별 절.
   병렬 갈래: 있음(tasks.md "병렬 갈래" — team-kit / 문 / 앱).
   design 3절 [미확인] 두 가지(본체의 entries.enabled 처리, 설정 실시간 읽기)는 설계가 기대지 않도록 짰다. 기대야 하는 상황이
   나오면 멈추고 보고. Google Drive·Sheets·Docs는 본체 스킬 google-workspace이고 skills.disabled로 끈다([확인], design 3절).
   TASK-02 절차: HEJO-CONNECTIONS design 7.1 그대로. 실행 중 원본(TKL)과 team-delegation 실행본은 고치지 않는다. <운영 저장소>
   HEAD로 임시 worktree를 만들고, 바꿀 파일마다 실행본과 worktree 기준 파일의 sha256이 같은지 확인해 impl-report에 적는다
   (다르면 멈추고 보고). 그 저장소 main에는 다른 작업의 미커밋 변경이 있다(특히 hermes_team_services/wait_jobs.py — 이번 영향 파일,
   그리고 hermes_governance/paseo_authority.py, hermes_owner_chat.py, hermes_reply/plugin.py, 시험 파일). wait_jobs.py는 실행본과
   커밋본이 다를 수 있으니 sha256 확인 결과를 반드시 적고 다르면 멈추고 보고. team-kit 최상위의 같은 이름 파일(예: team-kit/
   wait_jobs.py)은 lib 파일을 싣는 껍데기인지 확인하고 실제 코드 위치만 고친다. 게이트웨이 환경 Python과 임시 HERMES_HOME으로
   시험한다. 게이트웨이가 import하는 바뀐 파일은 보고에 적는다. --rebaseline 금지.
   AT-CM-14b(본체 소비자)는 실행 못 하면 [미실행]으로 적고 통과로 세지 않는다. 바꾸기 세션은 committed 응답에서 끝나고 재개는 resume만
   보낸다(design 2.2, PR-08).
   TASK-04 첫 단계: 확인 창 뒤 창이 사라지는 것을 이 Mac에서 재현(암호 입력 창도 같은 시스템 확인 창)하고 원인·재현 절차를
   impl-report에 쓴 뒤 고친다(design 5절 [제안]). 설명되지 않으면 멈추고 보고.
   금지 범위:
   - 게이트웨이 재시작, reload-plugins, install/hejo-release, 앱 사본 교체, 버전 올리기, hejo-publish·hejo-ship(모두 TASK-05·06).
   - 운영 ~/.hermes의 .env·auth.json·토큰 파일·hejo/admin.json 열기. 관리 서비스 직접 호출.
   - 운영 직원 설정·금고·명부 바꾸기, 운영에서 해제·설정 바꾸기 실행. 실제 Slack·고객 메시지. Google 토큰 폐기.
   - 개인값(직원 id·이름·주소·계정·절대 경로)을 코드·시험·문서에 쓰기. Hermes 본체·ddots 수정. git push.
   - 수락 기준·수락 시험 명세·spec·design 본문 수정.
   선행 작업: 없음.
10. 가정·미확정:
    - [가정] 확인 창 뒤 창 사라짐의 원인(spec 1절 6번). TASK-04가 재현으로 확정.
    - [가정] 꺼짐 칸을 지켜야 할 소비자는 design 3.1 표가 전부다. 구현 중 더 찾으면 같은 규칙으로 막고 impl-report에 목록을 적는다
      (새 소비자가 다른 칸·다른 저장소에 있으면 멈추고 보고).
    - [확인된 한계] 해제는 도구·스킬을 내주지 않는 것이고 토큰 파일 직접 읽기를 막는 보안 경계가 아니다(spec 3절). 화면 문장에
      "차단"을 쓰지 않는다.
    - 함수 배치·내부 구조·문장 세부는 구현 담당이 정한다(design에 고정한 동작 id·필드·칸·문장 핵심 제외).
    착수 차단 없음(1판의 Google 갈래 차단 조건은 design 3절 [확인]으로 해소).
11. 사용자 확인: 방법·범위·해제 뒤 값·시놀로지 한 줄·Google 포함은 사장이 2026-11-20 질문 도구로 정했다(brainstorm.md).
    계획 확인은 계획 검증 통과 후 자동 진행 예약 또는 사장의 구현 승인으로 한다.

[인계 전 점검]
- 현재 코드·계약·명세가 기준 커밋과 호환되는가? 예(이 저장소 63cbe2a 이후 제품 코드 변경 없음, <운영 저장소> 7ae2b013에서 조사).
- G1–G4: G1 spec REQ·AC·범위 밖·사장 결정 기록. G2 현황 근거(파일:줄), 칸 표, 기존 경로 판정. G3 AC↔AT 연결표(수락 시험 명세 끝), 계획 재검증 대기.
  G4 고위험 근거·롤백·운영 적용 절차 링크. 1판의 Google 미확인은 본체 읽기로 해소([확인] skill_utils.py:261-273).
```

## 2차 지시 (2026-11-20, 검증 1차 [verdict.md](verdict.md) V-1·V-2)

```text
[보완 인계: HEJO-CONN-MANAGE TASK-02(wait_jobs.py 제외)·03·04, 이후 TASK-02b]
- 원인: 환경 차이. <운영 저장소> main의 다른 작업 미커밋 변경으로 wait_jobs.py만 HEAD ≠ 실행본(bf1dd909… vs 441a8501…).
  그 밖의 TASK-02 영향 파일 12개는 HEAD = 실행본(검증 1차에서 확인, 착수 때 다시 확인해 impl-report에 적을 것).
- TASK-02: <운영 저장소> 현재 HEAD로 임시 worktree를 만들고 wait_jobs.py를 뺀 영향 파일로 진행한다. 바꿀 파일마다 HEAD = 실행본
  sha256을 다시 확인하고 다르면 그 파일만 멈추고 보고한다. team-delegation __init__.py는 링크이므로 실제 파일
  team-kit/lib/hermes_execution/__init__.py를 고친다(V-2). AT-CM-12(라)의 wait_jobs.account 부분은 TASK-02b로 넘긴다.
- TASK-03·04: 변경 없음. 지금 진행.
- TASK-02b 시작 조건: <운영 저장소> HEAD의 wait_jobs.py sha256 = 실행본 sha256(다른 작업의 커밋 또는 매일 자동 기록 커밋 뒤).
  충족하면 worktree 브랜치에 <운영 저장소> main을 merge(이 작업 파일과 겹치지 않아야 함, 충돌이면 멈추고 보고) → 전체 TASK-02 시험
  재실행 → wait_jobs.py 수정·시험. 이 작업 커밋에 다른 작업의 변경을 새로 넣지 않는다(merge로 들어온 그 작업 커밋만 조상).
  응답 시점까지 조건이 안 되면 TASK-02b는 "대기(기준 불일치)"로 보고하고 나머지 결과를 result로 낸다.
- 위험도·증거 수준·금지 범위·수락 시험 기대값은 1차 지시와 같다.
```

## 3차 지시 (2026-11-20, 검증 2차 [verdict.md](verdict.md) V-3)

```text
[보완 인계: HEJO-CONN-MANAGE TASK-03 보완 1]
- 원인: 설계·계약 오류(요구 불변). design 3판 4절이 team-kit status의 앱 파생 줄(app-<연결 키>, group mac)을 빠뜨렸다.
- 할 일: design 4판 4절 "앱 파생 줄" 규칙대로 gate/connection_manager.py의 줄 합치기를 보완한다. 수락 시험 명세 4판 AT-CM-21b를
  tests/acceptance/test_conn_manage.py에 옮기고, 실제 생산자 진단(.build/conn-manage-evidence/probe-derived-row.py)을 다시 돌려
  oneRowCriterionMet:true를 보고한다. 기존 AT-CM-20~28·23b와 bash scripts/test.sh 전체 재실행.
- 범위: 이 저장소 gate/와 tests/acceptance/만. team-kit·앱 변경 없음(status 출력 유지). 별도 커밋(git commit --only).
- TASK-02b: 2차 지시의 시작 조건 그대로(아직 불일치면 '대기(기준 불일치)'로 보고).
- 위험도 고위험, 증거 수준 2, 금지 범위는 1차 지시 9항 그대로.
```
