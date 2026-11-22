# 설계 인계: HEJO-FINDER-FOLDERS / TASK-02 Finder 연결 서버 동기화 폴더 후보

칸·원본·쓰기 주체·수명은 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-02 / team-kit]
0. 기준: 이 저장소 main 9514f0f(제품 코드 기준) / 계획 문서는 이 인계서를 담은 커밋 / <운영 저장소> 66f2a44c /
   spec·design·수락 시험 명세·tasks 2판 2026-11-21(계획 검증 1회차 반영, plan-review.md) / 승인 상태: 사장 브레인스토밍 결정(brainstorm.md), 계획 검증 켬(재검증 대기) /
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
4. 책임과 흐름: design 1절. Finder 후보 규칙은 app_setup.scopes() Finder 갈래 한 곳(함수 위치는 구현 담당). 안내 문장은 Finder 갈래가 selected['_scope_hint']로 넘기고
   app_connect.py:694-698 고르기 대기 응답이 그것을 hint로 쓴다(design 2절 8항, app_connect.py 변경은 필수 범위). scopes() 반환형(list)은 그대로.
5. 기존 경로 판정: design 3절(교체 1, 유지 5).
6. 위험도: 일반(후보 목록만 늘어남, 인증·저장 경로 그대로). 필요 증거 수준 2(임시 HOME·HERMES_HOME, 가짜 폴더).
   롤백: worktree 브랜치 버림(운영 원본 무변경).
7. 변경 성격: 의미 변경(Finder 후보가 늘어남). 보존 비교: AT-FF-12(team-kit 기존 시험 전체, 기대값 수정 없음).
8. 수락 시험: tests/acceptance/HEJO-FINDER-FOLDERS.md AT-FF-01~14(M1~M3는 TASK-03 뒤 사장). 연결표는 같은 파일 끝.
   상태: 명세 2판 완료·코드 미작성·미실행·계획 재검증 대기. AT-FF-03은 실제 hermes-connections 진입점을 감사 훅을 건 자식 프로세스로 돌려
   파일 열기를 관측한다(후보 생성 경로를 대역으로 바꾸지 않음). 기대값 출처: spec 요구, design 2절. 기대값·합격 기준을 바꾸지 말고,
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
- G1–G4: G1 spec REQ·AC·범위 밖·사장 결정. G2 현황 근거(파일:줄), 칸 표, 기존 경로 판정. G3 AC↔AT 연결표, 계획 검증 1회차 지적 반영·재검증 대기.
  G4 위험도 근거·롤백, 기준 커밋, 미확정은 착수 비차단.
```

## 2차 지시 (2026-11-21, 검증 1차 [verdict.md](verdict.md) V-1·V-2)

```text
[보완 인계: HEJO-FINDER-FOLDERS TASK-02 마무리]
- 원인: 시험 오류(V-1). AT-FF-12가 임시 HOME에서 team-kit 전체 통과를 요구했으나 기존 29개 시험은 실제 홈 입력에 의존한다.
  수락 명세 3판·spec 3판으로 정정했다: (가) 관련 기존 5파일(test_app_catalog·test_app_connect·test_app_setup·test_synology_app_connect·
  test_app_registry) 전부 통과 (나) 전체 실행의 실패·오류 node 집합 ⊆ 착수 HEAD 66f2a44c 기준 집합(새 실패 0). 기존 시험 수정·skip 금지.
- 할 일(V-2): 구현 세 파일(app_setup.py, app_connect.py, tests/test_finder_folders.py)을 지금 내용 그대로 worktree 브랜치에
  git commit --only로 커밋한다. 커밋 sha256이 검증 1차 기록(eff2a716… / e773e424… / 45e09387…)과 같은지 확인한다(다르면 이유 보고).
  커밋 HEAD에서 새 시험 + AT-FF-12(가) 실행, AT-FF-12(나) 전체 실행 후 실패·오류 node 집합을 기준 집합과 비교한다(기존 baseline-failures 기록 재사용 가능,
  다시 돌린 결과 파일 경로 기록). impl-report.md에 '2차' 절(커밋 전체 해시, 명령·종료 코드·로그 경로, 비교 결과)을 추가하고 result로 보고.
- 범위·금지·위험도·증거 수준은 1차 지시와 같다(실행본 교체·운영 main·./sync·재시작·릴리스·공개·push 금지).
```

## 3차 지시 (2026-11-21): TASK-03 서버 적용 (team-kit만, 재시작 없음)

허가: 사장이 승인한 계획(tasks.md TASK-03 "TASK-02 검토 통과 + 별도 인계")에 따른 운영 공항 변경의 유일한 인계다. 검증 2차에서 TASK-02 완료를 판정했다([verdict.md](verdict.md)).

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-03 서버 적용]
0. 절차 원본: HEJO-CONNECTIONS design 7.2의 team-kit 부분. 대상 파일은 2개뿐이다:
   hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py, app_connect.py
   (시험 파일 test_finder_folders.py는 운영 저장소 기록에만 들어간다).
   문 릴리스·앱 교체·공개·게이트웨이 재시작은 하지 않는다. 바뀐 모듈은 hermes-connections 자식 프로세스만 import한다(impl-report 1차 근거).
1. 착수 확인(하나라도 다르면 아무것도 바꾸지 말고 멈추고 보고):
   - 실행본(<HOME>/plugin-store/team-kit/lib/hermes_facility/)의 두 파일 sha256이 착수 기준과 같다:
     app_setup.py 17834aa1382c0e61…, app_connect.py 0af29766b4728d5c…(impl-report 1차 표 전체 값).
   - 운영 저장소 HEAD와 미커밋 목록을 기록한다. HEAD가 66f2a44c가 아니면 66f2a44c..HEAD에서 두 파일이 바뀌지 않았는지 확인한다.
   - 브랜치 hejo-finder-folders-20261121 tip = f3318572b9cbd85fccb54347872feca8915532cd.
2. 롤백 기록 먼저(impl-report '3차' 절, 빈 칸 금지): 두 실행본 파일 보관본(작업 문서 밖 0700 임시 폴더) 경로·sha256, 복원 명령.
3. 교체: 파일마다 f3318572의 내용을 같은 폴더 임시 파일에 쓴 뒤 이름 바꾸기로 교체. 교체 뒤 sha256 = eff2a716…/e773e424… 확인.
4. 확인(증거 수준 3, 운영 쓰기 없이 읽기만):
   - hermes-connections status --json, apps --json 둘 다 성공.
   - 실제 서버 홈으로 후보 만들기를 읽기 전용으로 한 번 실행한다. 게이트웨이 Python에서 실행본 lib을 PYTHONPATH로
     hermes_facility.app_setup.finder_scopes({})를 부르고 다음만 기록한다: 후보 수, 걸린 초, _scope_hint 유무(잘림/빈 목록), 뿌리 종류별 개수
     (Synology·다른 CloudStorage·iCloud 각각 몇 개). 폴더 이름·경로는 출력·기록하지 않는다(개인값). app connect는 실행하지 않는다(진행 기록 쓰기 방지).
   - 복구 조건: status·apps 실패, 또는 finder_scopes 예외 → 2의 보관본으로 즉시 복원, 같은 확인 재실행, 멈추고 보고.
     후보가 0개이거나 걸린 시간이 150초를 넘으면 복원하지 말고 보고한다(사장 판단).
5. 운영 저장소 기록: 브랜치를 운영 저장소 main에 merge(충돌이면 멈춤) → ./sync가 실행본과 저장소를 어느 방향으로 맞추는지 먼저 확인해 기록
   → ./sync → ./airport-check → 이 작업 세 경로만 git commit --only(다른 작업의 미커밋 변경은 넣지 않음).
   merge 커밋도 이 작업 경로만 바꾸는지 확인. ./sync 뒤 저장소와 실행본의 두 파일 차이 없음 확인.
6. 금지: 게이트웨이 재시작, install/hejo-release, 앱 교체·공개, 비밀 파일(.env·auth.json·토큰·admin.json) 열기, 운영 직원 설정·금고·명부 변경,
   운영에서 app connect·연결 실행, 실제 Slack·고객 메시지, 폴더 이름·경로 기록, Hermes 본체·ddots·hejo gate/app 수정, git push.
7. 보고: impl-report.md '3차' 절(착수 확인값, 롤백 기록, 명령·종료 코드·로그 경로, 4의 수치, 운영 저장소 merge·커밋 전체 해시), result.
   위험도 일반(운영 실행본 교체, 롤백 있음), 필요 증거 수준 3.
```

## 4차 지시 (2026-11-22): TASK-05·06 — 한글 정규화(team-kit), 연결 창 숨음(앱)

배경: 사장 확인 중 두 문제가 나왔다(spec 4판 5.1절 8~10번). 사장 결정(2026-11-22): 앱 수정도 이 작업에 포함한다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-05·06]
0. 기준: hejo main(착수 HEAD 기록), 운영 저장소 main f3318572(= 브랜치 hejo-finder-folders-20261121 tip). spec·design·수락 명세 4판 / 계획 검증 대기 후 승인.
1. 문서: spec 5절, design 7절, 수락 명세 4판 AT-FF-15~17·20~23(AT-FF-12 재확인 포함).
2. 요구: REQ-FF-05(Finder 후보 값 NFC, 중복 합치기, 섞인 저장 값 미리 선택. files.inside는 바꾸지 않음), REQ-FF-06(입력 단계·다시 열기에서 연결 창이 대화 창 앞, 시스템 확인 중만 .normal).
3. 유지할 계약: 1~3차 지시의 모든 계약, files.py·files.inside 무수정, app_connect.selected_options 무수정, AT-HC-25~27·HEJO-CONN-MANAGE 앱 시험(확인 중 .normal, restoreFocus).
4. 책임: 정규화는 app_setup.finder_scopes 한 곳. 창 높이는 ConnectionsWindow.updateLevel 한 규칙(+show()가 다시 계산).
5. 기존 경로 판정: updateLevel의 '입력 창·시트 있으면 .normal' 조건 교체(confirming만 남김). 나머지 유지.
6. 위험도 일반, 증거 수준 2. 롤백: 브랜치·커밋 되돌림(운영 미적용).
7. 의미 변경. 비교: 기존 시험 전체(team-kit AT-FF-12 기준, hejo bash scripts/test.sh).
8. 수락 시험: 명세 4판 완료·코드 미작성. 기대값 출처 spec 5절·design 7절. 바꿔야 하면 멈추고 보고.
9. 범위·순서:
   - TASK-05: 운영 저장소 worktree ../.worktrees/hejo-finder-folders-20261121(브랜치 tip f3318572, 운영 main과 같음)에서 app_setup.py와 시험만. 착수 때 실행본 app_setup.py sha256 = eff2a716…(3차 적용값) 확인. 새 커밋(git commit --only).
     AT-FF-15~17 + 기존 AT-FF-01~14 + AT-FF-12(가)(나) 재실행(임시 HOME·HERMES_HOME, 게이트웨이 Python).
   - TASK-06: hejo 저장소에서 앱만. 먼저 대화 창(펫 패널)이 열린 배치에서 입력 단계를 열어 연결 창이 뒤로 가는 것을 시험 코드나 개발 빌드로 재현하고 원인을 impl-report에 적은 뒤 고친다.
     실제 운영 문에 연결 동작(이어서 하기·연결·설정 바꾸기)을 보내지 않는다(가짜 문·시험 대역만). AT-FF-20~23과 bash scripts/test.sh 전체(HEJO_PYTHON=게이트웨이 Python).
     입력 창 때문에 .normal이 필요한 다른 이유가 재현되면 멈추고 보고. 커밋은 자기 경로만 git commit --only(다른 대화가 같은 저장소에서 일할 수 있음).
   - 병렬 갈래: 없음(두 갈래, 3개 미만).
   - 금지: 실행본 교체·운영 main 변경·./sync·재시작(TASK-07), 앱 버전 올리기·공개 후보·설치 앱 교체(TASK-08), 비밀 파일, 개인값(실제 폴더 이름·경로 포함), Hermes 본체·ddots·files.py 수정, 수락 기준·시험 명세·spec·design 수정, git push.
   - 보고: impl-report.md '4차' 절(TASK별 착수 HEAD·sha256, 재현·원인, 명령·종료 코드·로그 경로, 커밋 전체 해시), result.
10. 가정·미확정: design 7.2 [가정](입력 창 .normal의 원래 이유는 confirming이 덮음). TASK-06 재현으로 확인. 착수 차단 없음.
11. 사용자 확인: 앱 포함은 사장 결정(2026-11-22). files.inside 미수정·직원 A 재저장 방식은 계획 확인 때 사장 확인.
```

## 5차 지시 (2026-11-22): TASK-07 서버 적용(app_setup.py) + TASK-09 세 손가락 탭 지연

허가: 검증 4차에서 TASK-05 완료를 판정했다. TASK-07은 tasks.md TASK-07 "검토 통과 + 별도 인계"의 인계다. TASK-09는 사장 결정(2026-11-22: 0.2.4에 포함)으로 추가했다. 두 갈래는 파일이 겹치지 않으니 TASK-07을 먼저 끝내고 TASK-09를 한다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-07]
0. 절차: 3차 지시(TASK-03)와 같다. 대상 파일은 hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py 하나뿐이다
   (test_finder_folders.py는 운영 저장소 기록에만 들어간다). 재시작·문 릴리스·앱 없음.
1. 착수 확인(다르면 멈춤):
   - 실행본 app_setup.py sha256 = eff2a716b30fd2e1eb165ca295fa84da56be4db86e1b9602b477d56a67fd4be6.
   - 운영 저장소 HEAD와 미커밋 목록을 기록한다(f3318572 이후 다른 작업 커밋이 있으면 app_setup.py가 안 바뀌었는지 확인).
   - 브랜치 hejo-finder-folders-20261121 tip = d7208c11c23ddb0dacddbe3e225864058f263006.
   - 같은 저장소의 HEJO-SLACK-MOVE 세션이 team-kit 실행본 sha를 기준으로 쓰고 있다. app_setup.py 교체는 미리 알려 두었다.
     그 밖의 실행본 파일은 건드리지 않는다.
2. 롤백 기록 → 3. 임시 파일+이름 바꾸기로 교체, sha256 = 12aeddba77c4052f35714800eea1c63c06587d0666d9b2baa3e49214817aa3ab 확인
   → 4. status·apps 성공, 실행본 finder_scopes({}) 읽기 전용 1회(후보 수·초·hint·뿌리 종류별 개수, 그리고 id·value가 모두 NFC인지 참/거짓만.
   이름·경로 기록 금지) → 실패 시 복원
   → 5. 운영 저장소 main에 브랜치 merge(ff 가능하면 ff, 충돌이면 멈춤)·./sync 방향 확인·./sync·./airport-check·
   자기 경로 git commit --only(이미 커밋된 내용이면 빈 커밋 만들지 않음). ./sync가 가져온 다른 운영 기록은 커밋하지 않는다.
6. 금지: 3차 지시 6항과 같다(운영 app connect 금지. 사장이 직원 A를 "설정 바꾸기"로 다시 저장하는 것은 사장이 한다).
7. 보고: impl-report.md '5차-TASK-07' 절. 위험도 일반, 증거 수준 3.

[설계 인계: HEJO-FINDER-FOLDERS TASK-09 세 손가락 탭 지연]
1. 문서: spec REQ-FF-07, 수락 명세 AT-FF-30~32.
2. 순서: (가) 측정을 먼저 한다. 손 뗀 프레임 시각(읽기 스레드) → 판정 → 메인 스레드 처리 시작 → setExpanded 진입 → 첫 창 움직임 → 애니메이션 끝.
   진단 기록은 기본 꺼짐이고, 시험·진단 설정(환경 변수 등, 구현 담당이 정함)일 때만 .build/ 아래 파일에 쓴다. 개인값은 넣지 않는다.
   열기·닫기 각 10회, 고치기 전 표를 impl-report에 적는다.
   (나) 가장 큰 구간을 원인으로 기록한 뒤 그 자리에서 고친다(덧대기 금지).
   예: 판정 뒤 메인 스레드 대기, openBubble의 동기 작업, 첫 프레임 그리기 지연.
   애니메이션 길이(ChatMorph.genieDuration)나 탭 판정 규칙(0.3초·이동·간격)을 바꿔야 하면 멈추고 보고(사장 결정).
   (다) 고친 뒤 같은 측정. 손 뗀 프레임 → 첫 창 움직임 중앙값이 줄고 100ms 이하인지 확인.
3. 회귀: AT-FF-32. 앱 시험은 `pgrep -f app-tests`로 다른 실행이 없을 때만 돌리고, HEJO_PYTHON=게이트웨이 Python으로 돌린다.
   다른 세션(HEJO-SLACK-MOVE)과 포커스 충돌을 피하기 위해서다.
4. 범위: hejo app/Sources의 ThreeTap*.swift·PetController.swift·AppDelegate.swift 중 필요한 곳, app/Tests. 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일은 건드리지 않는다.
5. 금지: 앱 버전 올리기·공개 후보·설치 앱 교체(TASK-08), 운영 문에 연결 동작 보내기, 개인값, Hermes 본체·ddots 수정,
   수락 기준·시험 명세·spec·design 수정, git push.
6. 보고: impl-report.md '5차-TASK-09' 절(측정 방법, 전후 표, 원인, 고친 곳, 명령·종료 코드·로그 경로, 커밋 전체 해시), result.
   위험도 일반, 증거 수준 4. 실제 트랙패드 측정이므로 이 Mac의 실물 측정이다.
   단, 사장 체감(M7)은 0.2.4 설치 뒤 사장이 확인한다.
```

## 5차 지시 정정 (2026-11-22, 사장 지시 "탭 테스트는 가장 마지막에")

TASK-09의 측정은 실제 트랙패드 탭이 아니라 수락 명세 AT-FF-30(정정판)대로 한다. 트랙패드 읽기 콜백과 같은 입구에 접촉 프레임을 주입하고, 그 뒤 경로는 실제 코드로 지나게 해서 잰다. 에이전트는 손으로 탭하지 않는다. 실제 탭 확인(M7)은 0.2.4 설치 뒤 맨 마지막에 사장이 한다. 증거 수준은 2(주입)다. 나머지 5차 지시는 그대로다.
사장 관측: 지금은 "한 박자 느리게 열린다". 열기 쪽 구간을 특히 본다.

## 6차 지시 (2026-11-22): TASK-09 계속 — 첫 움직임 전 지연 줄이기

원인: 명세 오류(verdict 5차 V-4). spec 5판 REQ-FF-07 AC-03 정정, AC-04 추가.

```text
[보완 인계: HEJO-FINDER-FOLDERS TASK-09]
1. 목표: 주입 측정(AT-FF-30 방식, 커밋 3ccda92의 계측·harness 그대로)에서 손 뗀 프레임 → 첫 움직임 중앙값을 열기·닫기 모두 줄이고 100ms 이하로.
   애니메이션(0.30초)·탭 판정 규칙은 바꾸지 않는다.
2. 측정된 원인 구간(수정 전, 중앙값):
   - 열기: openBubble 준비 58.7ms.
   - setExpanded → 첫 움직임: 열기 100.8ms·닫기 147.6ms. 그 안에 확장 콜백 52~77ms, 화면 캡처 21~28ms, 타이머 대기 18ms.
   먼저 한 번의 열기·닫기에서 onChange·refresh가 몇 번, 각각 얼마나 걸리는지 같은 진단 설정으로 잰다(기본 꺼짐 유지).
3. 고치는 자리(원래 책임 자리에서, 덧대기 금지): 같은 사용자 동작 안에서 생기는 중복 화면 갱신을 한 번으로 모은다.
   범위는 ConversationView·ConversationController·ConversationModel의 갱신 묶음, AppDelegate.openBubble, PetController.setExpanded 순서.
   조건(spec AC-04):
   - 열린 뒤 보이는 내용(대화·처리할 일 칸·선택 상태)이 고치기 전과 같다.
   - 오래된 화면을 먼저 띄우고 애니메이션 뒤에 갱신하는 방식은 쓰지 않는다.
   - 화면 캡처(genie 그림)는 최종 내용으로 찍힌다.
   - 갱신 묶음이 다른 곳의 동기 갱신 기대(기존 시험)를 깨면 그 시험이 무엇을 보장하는지 먼저 확인한다. 기대값은 바꾸지 말고 멈추고 보고한다.
4. 확인: 수정 후 AT-FF-30 표(전후), AT-FF-31(중앙값 감소·100ms 이하), AT-FF-32(기존 ThreeTap·펫 클릭·앱 전체 시험,
   HEJO_PYTHON=게이트웨이 Python, 시험 전 pgrep -f app-tests). 열기 뒤 내용 동일성은 기존 시험과, 가능하면 고치기 전후 같은 가짜 대화에서
   화면 상태(선택된 방·스레드, 처리할 일 칸 표시 여부)를 비교하는 시험으로 본다.
5. 100ms를 못 맞추면 어디까지 줄었는지와 남은 구간을 보고한다(기준 완화 금지, 사장 결정).
6. 범위·금지: 5차 지시 TASK-09와 같다(gate/·schemas/ 금지, 앱 버전·공개 후보·설치 앱 교체 금지, 자기 경로 git commit --only, git push 금지).
   위험도 일반(화면 갱신 순서 변경), 증거 수준 2. impl-report.md '6차-TASK-09' 절, result.
```

## 7차 지시 (2026-11-22): TASK-09 마지막 한 차례 — 첫 프레임 전 남은 구간

검증 6차(verdict.md): 갱신 묶음(3e9400b)은 적합하다. 첫 움직임 중앙값이 열기 162→117ms, 닫기 148→136ms로 줄었다. 100ms까지 남은 구간을 한 차례만 더 줄인다.

```text
[보완 인계: HEJO-FINDER-FOLDERS TASK-09 7차]
1. 남은 구간(수정 후 중앙값, round6-task09/compare.json):
   - 열기: 최종 갱신 묶음 63.7ms(그 안 refresh 52.5ms), 캡처 20.1ms, 타이머 등록→첫 움직임 18.3ms.
   - 닫기: 캡처 32.3ms, 콜백 묶음 27.7ms, 타이머 등록→첫 움직임 44.5ms.
2. 먼저 더 나눠 잰다(같은 진단 설정, 기본 꺼짐):
   (가) 타이머 등록 뒤 첫 틱 전 메인 작업(apply(open)·레이아웃·그리기)과 틱 대기를 나눈다.
   (나) captureGenie 안의 cacheDisplay와 blurred 계산을 나눈다.
   (다) refresh 안에서 큰 하위 작업을 나눈다(목록 다시 만들기·처리할 일 칸·섬 등. 이름만, 내용 없음).
3. 고치는 자리(원래 책임 자리, 화면 내용·애니메이션 길이·탭 규칙 불변):
   - 첫 틱이 전환 시작 시각을 기다리지 않게, 전환 시작 직후 첫 프레임을 바로 적용하는 것은 허용한다(애니메이션 길이·곡선은 그대로).
   - 캡처의 흐림 계산이 첫 프레임에 필요 없으면, 필요한 시점까지 늦추는 것은 허용한다. 첫 프레임에 필요하면 바꾸지 않는다.
   - refresh 하위 작업 중 화면 밖이거나 바뀌지 않은 부분의 재생성을 건너뛰는 것은 허용한다(결과 동일, AC-04).
   - 그 밖의 방법이 필요하면 멈추고 보고.
4. 확인: AT-FF-30(수정 후)·AT-FF-31·AT-FF-32. 앱 시험 전 pgrep -f app-tests, HEJO_PYTHON=게이트웨이 Python.
5. 이번에도 100ms를 못 맞추면 더 진행하지 않는다. 남은 수치를 보고하면, 실제 탭으로 체감을 보는 사장 M7에서 받아들일지를 사장이 정한다
   (기준 완화를 에이전트가 하지 않음).
6. 범위·금지: 6차 지시와 같다. impl-report.md '7차-TASK-09' 절, result.
```

## 8차 지시 (2026-11-22): TASK-10 처리할 일 칸 배경

사장 결정(2026-11-22): 처리할 일 칸이 방 목록 위에 비쳐 겹치는 문제도 이 작업에 넣어 0.2.4에 담는다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-10]
1. 문서: spec REQ-FF-08(현황 근거 포함), 수락 명세 AT-FF-40~42.
2. 원인: TodoDrawerView가 배경을 그리지 않는다. 겹침 배치(PetView.swift:353 drawerOverlay)에서 아래 방 목록이 비친다.
3. 고치는 자리: TodoDrawerView 한 곳(배경 책임은 칸 자신). 배경색은 대화 창 바탕과 같은 테마 색. 겹침 배치에서는 알파 1.
   대화 창 바탕색을 정하는 기존 함수·값(ChatAppearance 등)을 재사용하고 새 색 상수를 따로 만들지 않는다.
   테마가 바뀌면(ChatAppearance.didChange) 다시 그린다.
4. 확인: AT-FF-40~42. 앱 시험 전 pgrep -f app-tests, HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh.
5. 범위: app/Sources/TodoDrawerView.swift(필요하면 PetView.swift 배치 부분), app/Tests. 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일 금지. 앱 버전·공개 후보는 이 작업이 하지 않는다(0.2.4는 다른 세션이 준비 중. 순서는 사장 경유로 맞춘다).
6. 금지: 개인값, 본체·ddots, 수락 기준·시험 명세·spec·design 수정, git push. 위험도 일반, 증거 수준 2.
7. 보고: impl-report.md '8차-TASK-10' 절(커밋 전체 해시, 명령·종료 코드·로그 경로), result.
```

## 9차 지시 (2026-11-22): TASK-11 색과 글자 사진, 옵션창 높이

사장 결정(2026-11-22): 둘 다 이 작업에 넣어 0.2.4에 담는다. 색을 고르면 "색 안에 글자를 넣고, 글이 컬러 네모를 벗어나지 않게 크기를 조절"한다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-11]
0. 순서: 8차(TASK-10)를 먼저 끝내고 이어서 한다. 파일은 겹치지 않는다.
1. 문서: spec REQ-FF-09·10(현황 근거 포함), design 8절, 수락 명세 AT-FF-50~54·60~63.
2. 색과 글자(REQ-FF-09): 세 곳의 "사진 바꾸기…"를 같은 하위 메뉴 함수로 "사진 고르기… / 색과 글자로 만들기…"로 바꾼다.
   색과 글자 창: UserBubbleColor 14색, 글자 칸(처음 값은 이름 첫 글자, 최대 8글자), 미리보기.
   PictureCodec에 256×256 PNG 만들기 함수를 더한다(밝은 테마 색 고정, 안전 영역 각 변 18%, 글꼴 자동 축소, 글자색은 UserBubblePalette 규칙).
   올리기는 기존 changePicture/setPicture 길. 문·schemas·저장 형식은 바꾸지 않는다.
3. 옵션창 높이(REQ-FF-10): AppDelegate.updateConnectionsLevel의 "활성이면 펫 창 높이+1" 식을 공용 함수로 옮기고,
   사진 고르기 창·색과 글자 창·NSAlert 상자·설정/로그인/달력/대시보드 창 등 모든 옵션창이 앱 활성화 + 그 높이로 뜨게 한다.
   연결 창의 확인 중 .normal 예외(REQ-FF-06)는 그대로. 먼저 AT-FF-62 검색 목록을 만들고 시작한다.
4. 확인: AT-FF-50~54·60~63. 앱 시험 전 pgrep -f app-tests, HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh 전체.
5. 범위: app/Sources(위 파일과 옵션창을 띄우는 파일), app/Tests. 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일 금지. 앱 버전·공개 후보는 하지 않는다(0.2.4는 다른 세션).
   기존 시험 기대값을 바꿔야 하거나 공용 규칙이 연결 창 예외와 부딪히면 멈추고 보고한다.
6. 금지: 개인값(시험 이름은 가짜만), 본체·ddots, 수락 기준·시험 명세·spec·design 수정, git push. 위험도 일반, 증거 수준 2.
7. 보고: impl-report.md '9차-TASK-11' 절(AT-FF-62 목록, 커밋 전체 해시, 명령·종료 코드·로그 경로), result.
```

## 10차 지시 (2026-11-22): TASK-11 보완 — 비활성 때 옵션창 내리기 (검증 9차 V-5)

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-11 보완]
1. 문서: spec 8판 REQ-FF-10 AC-05, 수락 명세 AT-FF-64, verdict 9차 V-5.
2. 원인: OptionWindows.show/prepare가 창을 펫 창+1로 올린 뒤, hejo가 비활성이 돼도 내리지 않는다.
   그래서 설정·로그인·달력·대시보드·사진 고르기 창이 다른 앱 위에 떠 있다.
3. 고치는 자리: OptionWindows 한 곳. show/prepare로 올린 창을 약한 참조로 기억한다.
   AppDelegate.applicationDidResignActive에서는 보이는 창을 .normal로, applicationDidBecomeActive에서는 level(active:true)로 맞춘다.
   두 함수가 이미 부르는 updateConnectionsLevel 옆에서 공용 함수 하나를 부른다. 닫힌 창은 붙잡지 않는다.
   NSAlert.runModal 중에는 앱이 활성이라 따로 손대지 않는다.
   연결 창은 지금 자기 규칙을 그대로 쓴다(공용 목록에 넣지 않거나, 넣더라도 확인 중 .normal 예외를 깨지 않는다).
4. 확인: AT-FF-64 새 시험, 기존 AT-FF-50~54·60~63·20~23. 앱 시험 전 pgrep -f app-tests,
   HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh 전체.
5. 범위: app/Sources/OptionWindows.swift, AppDelegate.swift(활성 처리 두 곳), app/Tests. 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일, 앱 버전·공개 후보 금지.
6. 금지: 개인값, 본체·ddots, 수락 기준·시험 명세·spec·design 수정, git push. 위험도 일반, 증거 수준 2.
7. 보고: impl-report.md '10차-TASK-11 보완' 절(커밋 전체 해시, 명령·종료 코드·로그 경로), result.
```

## 11차 지시 (2026-11-22): TASK-12 연결 창 화면 공유 숨김 없애기

사장 보고: "에이전트 연결을 눌러도 창이 뜨지 않는다"(서버, 화면 공유로 보는 중). 사장 결정: 숨김 기능을 없애고, 이 작업에 넣어 0.2.4에 담는다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-12]
1. 문서: spec 9판 REQ-FF-11(현황 근거 포함), 수락 명세 AT-FF-70·71.
2. 원인: 입력 단계에서 model.privacy(true) → ConnectionsWindow.swift:250이 연결 창·시트 sharingType을 .none으로 바꾼다.
   :277 입력 시트도 처음부터 .none이다. 화면 공유로 보는 사람에게 창이 보이지 않는다.
3. 고치는 자리: ConnectionsWindow.swift의 두 곳. sharingType을 .none으로 두지 않는다(기본값 그대로).
   model.privacy 콜백 자체는 모델 계약(기존 AT83이 호출을 확인함)이라 남겨도 된다. 창 연결 쪽만 바꾼다.
   이제 아무 일도 하지 않는 연결이면 지운다. 기존 시험 기대값은 바꾸지 않는다.
   비밀 칸 secure, 값 지우기, 원시 오류 비노출, 창 높이 규칙은 건드리지 않는다.
4. 확인: AT-FF-70(실제 ConnectionsWindow, 세 시점 sharingType != .none), AT-FF-71 회귀.
   앱 시험 전 pgrep -f app-tests, HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh 전체.
5. 범위: app/Sources/ConnectionsWindow.swift, app/Tests(ConnectionsTests 또는 새 파일 + TestMain 등록). 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일, 앱 버전·공개 후보 금지.
6. 금지: 개인값, 본체·ddots, 수락 기준·시험 명세·spec·design 수정, git push. 위험도 일반, 증거 수준 2.
7. 보고: impl-report.md '11차-TASK-12' 절(커밋 전체 해시, 명령·종료 코드·로그 경로), result.
```

## 12차 지시 (2026-11-22): TASK-13 직원 D Finder 연결이 저장되지 않음 (M6 막힘)

**사장 보고:** 직원 D 에이전트 연결에서 Finder 폴더(SynologyDrive-… › 시놀로지(…) › 0. 공용자료_PF)를 고르고 '확인하고 저장'을 누르면 연결되지 않는다. 입력 창에는 빨간 글씨로 "마쳤어요."가 뜬다. 직원 B는 다른 폴더로 저장한 뒤 파일을 잘 읽는다(M1~M3 일부 통과).

**계획 담당 확인(읽기만):**
- 문 로그: `2026-11-22 17:05:46 connections_failed type=connection_action profile=<직원 D 프로필> reason=command_failed`. 직원 B는 17:02:10에 설정 변경이 반영됐다(`Re-scanned profile '<직원 B 프로필>' after config/.env change`).
- `command_failed`는 문 `connection_runtime.py:196·205`에서 난다. 경우는 셋이다: 출력이 JSON이 아님, 0이 아닌 종료인데 outcome이 없음, 180초 초과.
- 직원 D 프로필에는 Finder 기록 파일(`state/connections/app-27cf6ce8eea3870712b51e12.json`)이 없다. 직원 B에는 있다(17:01). 그래서 저장(transact) 전에 실패한 것으로 보인다.
- 고르기 단계(scope 없이) 명령을 같은 환경으로 직접 돌렸다: `~/.hermes/bin/hermes-connections app connect --profile <직원 D 프로필> --app com.apple.finder --json` → exit 0, 0초, `waiting/CHOOSE_SCOPE`. 실패는 고른 값을 제출하는 단계에서 난다.
- 앱 표시: outcome이 done이 아니고 아는 reason도 없으면 `ConnectionSentence`가 check 없는 응답을 "마쳤어요."로 만든다. 그 글이 입력 창 오류 칸에 빨갛게 뜬다(`ConnectionsWindow.swift:184`). 실패를 "마쳤어요"로 보이는 것도 결함이다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-13]
1. 목표: 직원 D에서 Finder 폴더를 골라 저장하면 연결된다(M6). 실패하면 그 이유가 사장이 알아들을 문장으로 보인다.
2. 진단(먼저): 사장이 요청한 바로 그 연결을 한 번 실행해 재현한다.
   ~/.hermes/bin/hermes-connections app connect --profile <직원 D 프로필> --app com.apple.finder --scope <고르기 응답에서 '0. 공용자료_PF' 항목의 id> --json
   (환경은 문과 같게: HERMES_HOME=~/.hermes, HERMES_DISABLE_LAZY_INSTALLS=1, PYTHONDONTWRITEBYTECODE=1, 200초 제한)
   종료 코드·걸린 시간·stdout 키·stderr 마지막 줄을 .build 증거에 남긴다(경로 문자열은 증거에만 쓰고 문서에는 쓰지 않는다).
   - RESTART_REQUIRED가 나오면 거기서 멈춘다. 게이트웨이를 다시 시작하지 않고 보고한다.
   - 성공하면 그것이 사장이 원한 연결이다. 바뀐 운영 파일 목록과 되돌리는 방법(app undo)을 기록한다.
   - 실패·멈춤이면 어느 단계(enable/values/restart/permission/check, transact, 잠금)에서 왜 멈추는지 찾는다.
     직원 B와 직원 D 프로필의 차이(도구 묶음, files 설정, 기록 상태, 잠금)를 비교한다.
3. 수정: 원인이 team-kit이면 HD worktree에서 고치고 재현 시험을 더한다(가짜 HERMES_HOME). 관련 5파일 시험과 AT-FF-08·12 기준으로 회귀를 확인한다.
   원인이 앱 표시("마쳤어요" 오표시)면 app/Sources/ConnectionsWindow.swift에서 실패·대기 응답을 "마쳤어요"로 보이지 않게 고치고 시험을 더한다.
   실행본 교체는 하지 않는다. 고친 뒤 보고만 하고, 서버 적용은 다음 지시로 한다(3차 절차).
4. 금지: 게이트웨이 재시작, install/hejo-release, 비밀 파일 열기(.env·auth.json·토큰), 실제 Slack·고객 메시지, 본체·ddots 수정, 수락 기준·spec·design 수정, git push.
   운영 파일은 위 명령 한 번이 바꾸는 것 외에는 바꾸지 않는다. 다른 세션의 운영 저장소 미커밋 파일(files_docs/files.py 등)은 건드리거나 커밋하지 않는다.
5. 범위: 진단 증거 .build/finder-folders-evidence/round12-task13/, 수정은 HD worktree(team-kit)·app/(필요 시). 자기 경로만 git commit --only.
6. 위험도 일반(운영 명령 1회), 증거 수준 3.
7. 보고: impl-report.md '12차-TASK-13' 절(재현 결과, 원인, 수정 커밋 전체 해시, 명령·종료 코드·로그 경로, 운영에 바뀐 것), result.
```

## 13차 지시 (2026-11-22): TASK-13 계속 — 공용 창고 갱신 뒤 앱 연결 거절 해소 (검증 12차 V-6·V-7)

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-13 계속]
1. 문서: spec 10판 REQ-FF-12, design 9절, 수락 명세 AT-FF-80~83, verdict 12차.
2. team-kit 수정(HD worktree, d7208c11 브랜치에 새 커밋): config_assembly.app_manifests의 지문 비교(:155) 한 곳.
   baseline 지문이 달라도 (1) before_host가 링크, (2) links.json 그 경로 항목 overlay false, (3) 지금 manifest 바이트 == plugin-store/<plugin>/plugin.yaml 바이트,
   셋을 모두 만족하면 거절하지 않는다. template·original_host는 기존 baseline 값을 그대로 쓴다. 하나라도 아니면 지금처럼 UNDO_CONFLICT.
   기본 도구 권한(app_tool_defaults)·declared/additions 규칙은 바꾸지 않는다.
3. 시험: TASK-13 가짜 재현을 회귀 시험으로 옮겨 AT-FF-80~82를 만들고 AT-FF-83(관련 5파일+test_finder_folders+test_app_manifests,
   team-kit 전체 실패 집합 ⊆ 착수 기준, ./airport-check)을 실행한다. 기존 기대값은 바꾸지 않는다.
4. 앱 전체 회귀(V-7): pgrep -f app-tests와 다른 GUI 시험·빌드가 없는 때 HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh를 다시 실행한다(f03b93a 이후 HEAD).
   AT-HC-27이 또 앱 비활성으로 실패하면, 같은 때 착수 사본(f03b93a 이전)도 실행해 환경 문제인지 대조하고 멈춰 보고한다. 기대값을 완화하지 않는다.
5. 서버 적용은 하지 않는다. 운영 저장소에 다른 세션의 config_assembly.py 미커밋 변경이 있으므로 실행본 교체·운영 저장소 커밋은 다음 지시로 한다.
   대신 impl-report에 함수 한 곳 diff와, 그 변경이 실행본 config_assembly.py의 app_manifests 본문에도 그대로 붙는지(함수 본문 SHA 비교) 기록한다.
6. 금지: 운영 명령 실행(이번엔 없음), 게이트웨이 재시작, 비밀 파일, 실제 메시지, 본체·ddots, 수락 기준·spec·design 수정, git push, 다른 세션 파일.
   문서에는 직원 이름·프로필 id·경로 대신 '직원 D/B'. 자기 경로만 git commit --only. 위험도 일반, 증거 수준 2.
7. 보고: impl-report.md '13차-TASK-13' 절(커밋 전체 해시 — HD·hejo, 명령·종료 코드·로그 경로), result.
```

## 14차 지시 (2026-11-22): TASK-14 서버 적용(config_assembly 한 곳) + 직원 D 연결

계획 담당 확인(읽기만): 운영 저장소 작업 트리 깨끗함. 실행본 `config_assembly.py` = 운영 main 파일(SHA-256 `2684eb46e088356e4a159d1a424669b6917224c8065c4fe128416bec7c28dfde`). `origin/main` ⊂ 로컬 main. `d7208c11`은 원격에 있음.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-14]
1. 운영 저장소 main에 HD 커밋 6602c040을 cherry-pick한다(두 경로만). 충돌·다른 경로 변경이 생기면 멈추고 보고한다(merge·rebase·강제 해결 금지).
   main에서 관련 8파일 pytest(임시 resolve HOME·HERMES_HOME)와 ./airport-check --snapshot . 를 실행한다.
2. 실행본 교체: ~/.hermes/plugin-store/team-kit/lib/hermes_facility/config_assembly.py가 교체 직전에도 SHA 2684eb46…인지 확인한다.
   다르면 멈추고 보고한다. 같으면 롤백 보관본을 .build/finder-folders-evidence/round14-task14/rollback-* 에 두고, cherry-pick 뒤 main 파일로 바꾼다.
   교체 뒤 실행본 SHA = main 파일 SHA를 확인한다. 테스트 파일은 실행본에 넣지 않는다(3차·7차 절차와 같음).
3. 재시작 판단: 연결은 요청마다 hermes-connections 하위 프로세스가 새로 읽는다. 게이트웨이 프로세스가 config_assembly를 import해 이 함수를 쓰는 경로가 있는지 코드로 확인해 기록한다.
   게이트웨이 재시작은 하지 않는다(필요하다고 판단되면 멈추고 보고).
4. 직원 D 연결 1회(사장이 요청한 그 연결): 12차와 같은 환경·명령으로 --scope '0. 공용자료_PF' 항목 id를 한 번 제출한다.
   결과·바뀐 운영 파일 목록·app undo 방법을 기록한다. RESTART_REQUIRED·PERMISSION 대기면 거기서 멈추고 보고한다(재시작·권한 창 조작 금지).
   성공하면 직원 D 프로필에서 그 폴더가 저장됐는지 읽기로 확인한다(파일 내용·비밀 값은 열지 않음).
5. 금지: 게이트웨이 재시작, install/hejo-release, 비밀 파일, 실제 메시지, 본체·ddots, 수락 기준·spec·design 수정, git push, 다른 세션 파일.
   문서에는 '직원 D'. 자기 경로만 git commit --only(운영 저장소 cherry-pick 커밋, hejo impl-report).
6. 위험도 일반(운영 적용), 증거 수준 3.
7. 보고: impl-report.md '14차-TASK-14' 절(운영 main 커밋 전체 해시, 교체 전후 SHA, 롤백 경로, 연결 결과, 명령·종료 코드·로그 경로), result.
```

## 15차 지시 (2026-11-22): TASK-14 계속 — 사장 승인 재시작으로 직원 D 연결 마무리

사장 결정(2026-11-22 18:20): "에이전트가 지금 재시작". 다른 hejo 세션(d2·10·02)에 재시작 예정을 알렸다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-14 계속]
1. 재시작 직전 확인: 게이트웨이가 처리 중인 대화가 있으면(BUSY) 억지로 하지 않는다. 기존 drain 재시작 경로만 쓴다.
   ~/.hermes/state/connections/restart.json 등 재시작 60분 제한 상태는 읽기만 한다.
2. 이어 하기: 14차와 같은 환경으로 직원 D Finder 연결을 --resume gateway_restart로 한 번 이어 한다
   (~/.hermes/bin/hermes-connections app connect --profile <직원 D 프로필> --app com.apple.finder --resume gateway_restart --json, 200초 제한).
   이 명령이 기존 재시작 경로(gateway_restart.restart)로 게이트웨이를 다시 시작하고 permission·check로 이어 간다. 별도 kill·launchctl·hejo-release는 쓰지 않는다.
3. 결과 처리:
   - done이면 직원 D에 저장된 Finder 폴더를 읽기로 확인하고(비밀·파일 내용 열지 않음), 재시작 뒤 게이트웨이 로그에서 hejo·채널이 다시 연결됐는지 확인한다(NOT_RECONNECTED 여부).
   - PERMISSION 대기(Mac 권한 창)면 멈추고 보고한다(권한 창 조작 금지).
   - BUSY·RATE_LIMITED·RESTART_FAILED면 멈추고 보고한다. 재시도하지 않는다.
4. 실제 확인(파일 읽기)은 사장 M6로 남긴다. 실제 Slack·고객 메시지는 보내지 않는다.
5. 금지: 다른 재시작 방법, install/hejo-release, 비밀 파일, 본체·ddots, 수락 기준·spec·design 수정, git push, 다른 세션 파일(운영 저장소 작업 트리의 M 3개 포함).
   문서에는 '직원 D'. 자기 경로만 git commit --only.
6. 위험도 일반(운영 재시작, 사장 승인), 증거 수준 3.
7. 보고: impl-report.md '15차-TASK-14 계속' 절(명령·종료 코드·시간, 재시작 전후 게이트웨이 PID·로그 줄 번호, 연결 결과, 로그 경로), result.
```

## 16차 지시 (2026-11-22): TASK-15 링크 유지 보정 + 직원 D 링크 복구 + 시험 파일 보존 (검증 15차 V-8·V-9)

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-15]
1. 문서: spec 11판 REQ-FF-12 AC-05·06, design 9.1, 수락 명세 AT-FF-84~86, verdict 14차 V-8·15차 V-9.
2. 코드(HD worktree 새 커밋): app_manifests의 '검증된 창고 갱신 수락' 갈래에서 template=지금 창고 manifest 바이트,
   창고 provides_tools 중 옛 template에 없던 도구를 그 프로필 app_tool_defaults[plugin] 끝에 순서대로 더한다. original_host는 baseline 그대로.
   AT-FF-84 시험을 test_finder_manifest_updates.py에 더한다. 기존 기대값은 바꾸지 않는다(정책 바이트 불변을 단언한 기존 시험이 이 보정과 부딪히면 멈추고 보고).
   관련 8파일 + test_finder_manifest_updates + team-kit 전체(실패 집합 ⊆ 기준) + ./airport-check.
3. 운영 적용 순서(운영 AGENTS.md 39·40줄: 실행본이 원본, 저장소는 ./sync 사본):
   a. 실행본 config_assembly.py가 교체 직전 SHA f2c64d1d…인지 확인 → 보관본 → 새 파일로 교체.
   b. 실행본 ~/.hermes/plugin-store/team-kit/tests/에 test_finder_folders.py(HD에서 검토된 바이트)와 새 test_finder_manifest_updates.py를 설치한다.
   c. 직원 D 복구: 운영 owner/policy.yaml의 직원 D app_tool_defaults.team-kit에 창고에만 있는 도구(cctv_now, cctv_reference — 실행 시 다시 계산해 확인)만 더한다(보관본 포함, 그 밖의 줄 변경 금지).
      그 뒤 직원 D Finder 연결을 14차와 같은 환경·같은 --scope로 한 번 제출한다. 결과 플러그인 자리가 심링크·links.json overlay false인지, hermes-plugin-store --check, 저장 폴더 유지를 확인한다(AT-FF-85).
      RESTART_REQUIRED면 거기서 멈추고 보고한다(재시작은 사장 승인 뒤).
   d. ./sync 후 git status로 이 작업 경로만 확인하고 자기 경로만 git commit --only(config_assembly.py, 두 시험 파일, 직원 D 링크·links.json·policy.yaml 중 이 작업 변경분).
      다른 세션(OPS-REPO-RENAME 등)의 변경이 같은 파일에 섞여 있으면 그 파일은 커밋하지 말고 보고한다.
4. 조율: 운영 저장소 작업 트리에 OPS-REPO-RENAME 세션(hermes-hejo-d2)의 미커밋 변경이 있다. ./sync 전후로 그 세션 파일을 되돌리거나 커밋하지 않는다.
   끝나면 hermes-hejo-d2에 이 작업 소유 운영 경로와 커밋을 한 줄로 알린다(계획 담당이 대신 알려도 됨 — 보고에 목록만 남겨라).
5. 금지: 게이트웨이 재시작, install/hejo-release, 비밀 파일, 실제 메시지, 본체·ddots, 수락 기준·spec·design 수정, git push, 플러그인 폴더 손 편집.
   문서에는 '직원 D'. 위험도 일반(운영 적용·정책 한 곳), 증거 수준 3.
6. 보고: impl-report.md '16차-TASK-15' 절(HD·운영 커밋 전체 해시, 교체 전후 SHA, 보관본, 정책 변경 전후, 연결 결과, 명령·종료 코드·로그 경로), result.
```

## 17차 지시 (2026-11-22): TASK-15 다시 — 설계 모순 정리 반영 (검증 16차 V-10)

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-15 다시]
1. 문서: spec 12판 REQ-FF-12 AC-03·05·06, design 9.1·9.2, 수락 명세 AT-FF-84~86, verdict 16차.
2. 코드(HD worktree 새 커밋): 수락 갈래에서 조립용 template = 지금 창고 manifest 바이트, 새 창고 도구를 그 프로필 app_tool_defaults[plugin] 끝에 순서대로 추가.
   manifest-bases.json의 before·host(되돌리기 기준)는 기존 baseline 값을 그대로 기록한다(:199의 before=template.hex()와 분리).
3. 시험 수정 허가(이 한 곳만): tests/test_finder_manifest_updates.py의 test_store_update_connects_finder_and_undo_preserves_originals 52줄
   "연결 뒤 정책 바이트 불변"을 "그 프로필 app_tool_defaults.team-kit = 이전 목록 + 새 창고 도구(순서대로), 그 밖의 정책 내용 같음"으로 바꾼다.
   51줄·53줄·undo 뒤 단언(55~57줄)은 그대로 둔다. 같은 시험에 플러그인 자리 is_symlink·links.json overlay false 단언을 더한다(AT-FF-84).
   다른 시험의 기대값은 바꾸지 않는다. 또 부딪히면 멈추고 보고한다.
4. 이후는 16차 지시 2항 끝(관련 8파일+test_finder_manifest_updates+team-kit 전체 ⊆ 기준+airport-check)과 3·4·5·6항(운영 적용 a~d, d2 조율, 금지, 보고)을 그대로 따른다.
   보고 절 이름은 '17차-TASK-15'.
```

## 18차 지시 (2026-11-22): TASK-15 마무리 1단계 — ./sync·운영 커밋 (재시작 없음)

사장 결정(19:2x): 직원 D 적용용 재시작은 OPS-REPO-RENAME 세션(d2)의 예정 재시작에 합친다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-15 마무리 1단계]
1. 운영 저장소(AGENTS.local.md의 `<운영 저장소>`)에서 ./sync를 실행한다(토큰 경고가 나오면 커밋하지 않고 멈춤).
2. git status·git diff로 바뀐 경로가 이 작업 것인지 하나씩 확인한다:
   실행본 config_assembly.py(이 작업 app_manifests 변경), team-kit tests 두 파일(test_finder_folders.py 복원, test_finder_manifest_updates.py 갱신),
   직원 D 플러그인 링크, plugin-store/links.json 직원 D 항목, owner/policy.yaml 직원 D 기본 도구, 직원 D config.yaml·owner/team.yaml·owner/vault.yaml의 Finder 연결 기록.
   다른 세션의 변경이 같은 파일에 섞였으면 그 파일은 커밋하지 말고 보고한다.
3. 이 작업 경로만 git commit --only(한국어 메시지, 무엇을 왜). 커밋 뒤 운영 저장소 미커밋이 0인지 확인한다(AT-FF-86).
4. 재시작·--resume·연결 재제출은 하지 않는다(d2 재시작 뒤 다음 지시로).
5. 금지: 게이트웨이 재시작, install/hejo-release, 비밀 파일 내용 열기(diff는 경로·줄 수만 보고, vault 값은 보고서에 쓰지 않음), 실제 메시지, 본체·ddots, 수락 기준·spec·design 수정, git push.
6. 보고: impl-report.md '18차-TASK-15 마무리 1' 절(운영 커밋 전체 해시, 커밋 경로 목록, 미커밋 0 확인, 명령·종료 코드·로그 경로), result.
```

(2단계, d2 재시작 뒤 별도 지시: `--resume gateway_restart` 1회 → `completed_since`로 새 재시작 없이 permission·check → done 확인.)

## 19차 지시 (2026-11-22): TASK-15 마무리 2단계 — d2 재시작 뒤 직원 D 연결 마무리

d2 알림(19:37): 게이트웨이 재시작 완료(새 PID 18074, 로그 7298줄 시작 19:35:53, 13 platform 재연결, 새 오류 없음). 계획 담당이 gateway.pid·로그로 확인함.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-15 마무리 2단계]
1. 먼저 읽기 확인: gateway.pid의 PID가 18074이고, 직원 D Finder 기록의 적용 시각이 그 프로세스 시작보다 앞서는지 본다.
   gateway_restart.completed_since(root, 그 적용 시각)을 읽기로 계산해 True인지 기록한다. False면 멈추고 보고한다(재시작 금지).
2. 17차와 같은 환경으로 직원 D Finder 연결을 --resume gateway_restart로 한 번 이어 한다(200초 제한).
   PID가 18074에서 바뀌면(새 재시작) 이상이므로 결과와 함께 보고한다.
3. 결과: done/OK면 저장 폴더 유지, 플러그인 심링크·links.json overlay false, hermes-plugin-store --check를 읽기로 확인한다.
   PERMISSION·CHECK 실패·대기면 멈추고 보고한다.
4. 금지: 게이트웨이 재시작, ./sync·운영 커밋(이번엔 바뀌는 운영 파일이 기록 파일뿐이어야 함 — 다른 파일이 바뀌면 보고), 비밀 파일, 실제 메시지, git push.
   문서에는 '직원 D'. 위험도 일반, 증거 수준 3.
5. 보고: impl-report.md '19차-TASK-15 마무리 2' 절(completed_since 결과, 명령·종료 코드·시간, PID 전후, 결과, 바뀐 운영 파일, 로그 경로), result.
```

## 20차 지시 (2026-11-22): TASK-08 앱 0.2.4(빌드 6) 공개 후보 준비

사장 결정(2026-11-22 19:5x): 0.2.4를 준비하던 다른 세션이 없으므로 이 작업이 직접 만든다. main의 HEJO-SLACK-MOVE 문(gate) 변경도 함께 담는다. 사장 확인 M5·M6 통과.

- 선례: [HEJO-CONNECTIONS handoff "보완 지시 3"](../HEJO-CONNECTIONS-20261120/handoff.md) 절차와 [HEJO-CONN-MANAGE 8차 지시](../HEJO-CONN-MANAGE-20261120/handoff.md)를 **0.2.4·빌드 6**으로 그대로 따른다. 다른 점만 적는다.
- 들어가는 것: 착수 때 `main` HEAD 전체. 새 `public`의 부모는 지금 로컬 `public`(0.2.3 `f397bdb`).
- 확인 추가:
  1. 새 `public` 트리가 이 작업 앱 커밋 `b21dd94`·`3ccda92`·`3e9400b`·`b3fc5cb`·`2fffbe0`·`5fc60b2`·`da3cf0b`·`52e2511`·`f03b93a`를 모두 조상으로 포함한다. `app/`이 main HEAD와 바이트가 같다.
  2. `app/Sources/ConnectionsWindow.swift`에 `sharingType`이 없다. `OptionWindows.swift`·`LetterPictureDialog.swift`가 있다.
  3. 공개 후보 트리의 전체 시험 로그에서 AT-FF-20~23·30~32·40~42·50~54·60~64·70·71 관련 PASS 줄을 impl-report에 인용한다.
  4. 준비물 버전·빌드(0.2.4·6)가 설치본(0.2.3·5)보다 크고, 업데이트 서명 키가 0.2.3과 같다.
  5. 문(gate) 변경 목록: 새 `public`의 `gate/`·`schemas/`가 지금 서버 문 실행본(공용 릴리스 폴더의 `gate`)과 어떻게 다른지 파일 목록만 적는다. 서버 문 설치(`install/hejo-release`)와 게이트웨이 재시작은 이번에 하지 않는다. 공개 뒤 사장 승인으로 별도 지시한다.
- 보고: 버전 올림 커밋, 새 `public` 전체 커밋, 준비물 경로, 사장용 공개 명령 한 줄(`install/hejo-ship publish --approve-commit <새 public 커밋> --prepared .build/release-0.2.4/prepared.json`), 푸시 대상, 검증 명령·종료 코드. impl-report '20차-TASK-08' 절, result.
- 금지: 선례와 같다(GitHub 조회·쓰기·publish·push 금지, 설치된 앱 사본 교체·공용 릴리스·운영 홈 변경·`install/hejo-release`·게이트웨이 재시작 금지, 비밀 값 열람 금지, 제품 동작 코드·spec·design·수락 시험 명세 수정 금지). 앱 시험 전 `pgrep -f app-tests`.
- 위험·증거: 고위험(공개 배포물), 증거 수준 2. 실제 공개·업데이트 설치(수준 4)는 사장이 한 뒤 M4·M7~M11로 본다.

## 21차 지시 (2026-11-22): TASK-16 처리할 일 칸 바깥 배치

사장 결정: 칸은 대화 창을 덮지 않고 바깥에 연다. 왼쪽 자리가 없으면 펫과 창을 오른쪽으로 옮긴다. 이 작업에 넣어 0.2.5에 담는다.

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-16]
1. 문서: spec 13판 REQ-FF-13, design 10절, 수락 명세 AT-FF-90~93.
2. 고치는 자리: PetPlacement.withLeading(PetLayout.swift) 한 곳. fits가 거짓이면 shift=(visibleFrame.minX+12)−(globalBubble.minX−width)만큼 펫·대화 창 전체를 오른쪽으로 옮긴
   배치에 바깥 칸(leading=width, drawerOverlay=false)을 붙인다. 옮긴 오른쪽 끝이 visibleFrame.maxX−12를 넘으면 지금처럼 겹침.
   저장 위치(anchorOrigin·설정 저장)는 옮기기 전 기준을 유지해 칸을 닫으면 제자리로 돌아오게 한다. 새 설정 키 금지.
   PetController가 withLeading 결과로 패널 위치를 정하는 곳(303줄 근처)이 이 규칙을 그대로 쓰는지 확인하고, 필요한 최소만 고친다.
3. 확인: AT-FF-90~93을 앱 시험으로 옮긴다. 앱 시험 전 pgrep -f app-tests, HEJO_PYTHON=게이트웨이 Python bash app/scripts/test.sh 전체
   (깊은 경로에서 소켓 경로 길이 오류가 나면 0.2.4 때처럼 짧은 TMPDIR로 같은 트리를 다시 실행하고 둘 다 기록).
4. 범위: app/Sources/PetLayout.swift, 필요하면 PetController.swift, app/Tests. 자기 경로만 git commit --only.
   gate/·schemas/·다른 작업 파일, 앱 버전·공개 후보 금지(TASK-17에서).
5. 금지: 개인값, 본체·ddots, 수락 기준·spec·design 수정, git push. 기존 기대값 변경이 필요하면 멈추고 보고. 위험도 일반, 증거 수준 2.
6. 보고: impl-report.md '21차-TASK-16' 절(커밋 전체 해시, 명령·종료 코드·로그 경로), result.
```

## 22차 지시 (2026-11-22): TASK-16 다시 — 기존 시험 기대값 변경 허가 (검증 21차 V-11)

```text
[설계 인계: HEJO-FINDER-FOLDERS TASK-16 다시]
1. 문서: spec REQ-FF-13, design 10절·10.1, 수락 명세 AT-FF-90~93, verdict 21차.
2. 21차 지시 2·3·4·5·6항을 그대로 따르되, 기대값 변경은 design 10.1의 세 곳만 허가한다:
   TodoDrawerTests AT-TD-33(95줄)·AT-TD-35(116·118줄)를 새 규칙으로, TodoDrawerBackgroundTests AT-FF-40 고정물(48·50줄)의 겹침 사례를 좁은 가짜 화면으로.
   AT-FF-40 픽셀 기대값, AT-TD-35 117줄, 그 밖의 기존 기대값은 바꾸지 않는다. 또 부딪히면 멈추고 보고한다.
3. 보고 절 이름 '22차-TASK-16'. 바꾼 기존 단언마다 전후를 표로 남긴다.
```
