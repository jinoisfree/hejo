# 설계 인계: HEJO-SLACK-MOVE / TASK-02~08 알림·보고·대화를 Slack 대신 hejo로

칸·원본·쓰기 주체·수명은 [spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-SLACK-MOVE TASK-02~08 / 문·team-kit·직원 플러그인]
0. 기준: 제품 코드 기준 cb06e7d(이 저장소 main) / 계획 문서 기준은 이 인계서를 담은 커밋 / <운영 저장소> 66f2a44c /
   spec·design·수락 시험 명세·tasks 4판 2026-11-22(계획 검증 1회차 4건·2회차 2건·3회차 1건 반영, plan-review.md) /
   승인 상태: 사장 브레인스토밍 결정(brainstorm.md) 기반, 계획 검증 켬(재검증 대기) / 운영 모드: 연합개발(교차 모델 + 계획 검증)
   <운영 저장소>는 매일 자동 기록 커밋으로 움직인다. 착수 때 HEAD를 impl-report에 적는다.
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-SLACK-MOVE-20261121/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-SLACK-MOVE.md, gate/README.md, schemas/hejo-wire-v1.json, <운영 저장소>/AGENTS.md,
   team-kit 개발·적용 절차는 docs/changes/HEJO-CONNECTIONS-20261120/design.md 7.1·7.2. ADR 없음.
2. 요구와 수락 기준: REQ-SM-01~09(SM-08.AC-05 제외), NFR-SM-01~06. SM-04·10·11의 운영 부분은 이번 지시 밖(TASK-10·11).
   핵심: 문에 서버 안 전용 Unix 소켓 입구를 만들고(직원 글만, 사장 글 불가, 네트워크에 안 열림), 예약 보고가 방으로 가고,
   방 스레드는 주인이 이어 받는다. team-kit은 지시서 값 하나(delivery.platform)로 Slack 또는 hejo 한 곳으로만 보내고,
   hejo일 때 Slack 쓰기는 0건이다. 값이 없으면 지금과 같은 Slack 호출을 한다(회귀 0).
   인스타: 새 DM → hejo 고객별 스레드 → 초안·버튼 → 사장 승인 → 전송 → 완료 표시. 승인 판정 규칙은 그대로, 자료만 hejo 스레드.
   버튼 승인은 누른 글 id가 지금 대기 초안 글 id와 같을 때만(design 5절 식별자 표). 다시 보내는 글은 요청 열쇠로 한 번만 올라간다
   (문이 기록장으로 중복 판정, 보내는 쪽이 보내기 전에 열쇠 저장: design 3.1·4.1). 입구의 올리기 한 번은 글 한 줄이고
   한도를 넘으면 거절한다. 긴 글은 공통 전송이 나눠 조각마다 다른 열쇠로 올린다. 열쇠에는 발생 건 값이 들어간다
   (인스타 초안은 초안 열쇠만으로 만들지 않는다. 네이버톡은 사건 행 id + approval + status이고 hejo일 때만 결과를 모르는
   알림을 같은 열쇠로 다시 올린다: design 4.1 발생 건 값 표). 방 만들기는 구성원·대표가 다르면 충돌로 멈춘다(design 3.1).
3. 유지할 기존 계약: 앱↔문 규격 hejo-wire-v1(파일 불변), 기록장 레코드 종류, 문의 기존 입구·오류 이름·권한 검사,
   hejo:<직원 id> 예약 대상, 1:1과 targeted 글의 받는 직원, team-kit의 Slack 동작 전부(delivery.platform이 없거나 slack일 때
   가짜 Slack이 받는 호출이 작업 전과 같음), 인스타·네이버 전송과 자동 전송 판정·학습 규칙, 승인 판정 규칙(send·show·ask),
   Hermes 본체 무수정, ddots 무수정.
4. 책임과 흐름: design 1절. 기록장 쓰기는 문, 어느 문으로 보낼지는 지시서 값 하나를 읽는 team-kit 함수 하나, 받을 곳 값은
   금고 hejo.*, 보내는 코드는 team-kit 공통 전송 한 곳, 답할 직원은 문의 recipients 한 곳.
5. 기존 경로 판정: design 6절(유지 4, 교체 2, 통합 2). 공존(Slack·hejo)의 권위 경로는 delivery.platform, 한 전송은 한 문으로만.
6. 위험도: 고위험(새 쓰기 권한인 입구, 모든 보고의 길, 고객 응대 승인 판정, 직원 도구 범위). 필요 증거 수준 2
   (임시 HERMES_HOME + 가짜 입구·가짜 Slack·가짜 인스타/네이버). 운영 적용(3)·실물(4)은 TASK-10·11.
   롤백: 이 저장소 커밋 되돌림. team-kit·직원 플러그인은 운영 원본을 바꾸지 않으므로(worktree 브랜치) 그 브랜치를 버리면 된다.
7. 변경 성격: 의미 변경(새 입구·대상·주인 규칙·hejo 전송). 보존 비교: AT-SM-40·59(가짜 Slack 호출이 작업 전 기록과 같음),
   AT-SM-12·22(문의 기존 동작), bash scripts/test.sh 전체, <운영 저장소> ./airport-check.
   team-kit 회귀 기준 기록은 고치기 전에 먼저 뜬다(작업 전 코드로 가짜 Slack 호출을 기록해 시험 자료로 둔다).
8. 수락 시험: tests/acceptance/HEJO-SLACK-MOVE.md AT-SM-01~08·10~12·20~22·30·31(문), 40~49·49b·50~59·51b·60~66·61b·68·70~72(team-kit·직원 플러그인).
   AT-SM-47·48·51·51b는 실제 문 어댑터와 team-kit을 묶는 통합 시험이다(tasks.md 끝 문단). 훅을 가짜 이벤트로 직접 부르는 시험으로 대신하지 않는다.
   AT-SM-67과 M1~M7은 이번 지시 밖. AC↔시험 연결표는 같은 파일 끝. 상태: 명세 완료·코드 미작성·미실행·계획 검증 대기.
   기대값 출처: spec 요구, design 3·4·5절 표. 기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md TASK-02~08 영향 파일. 순서는 02 → 03, 04 → 05 → 06 → 07, 08(인스타 최우선: 04 다음은 반드시 05).
   TASK마다 별도 커밋(이 저장소는 git commit --only), impl-report.md에 TASK별 절.
   병렬 갈래: 있음(tasks.md "병렬 갈래" — 문·입구 / 문·대상과 주인 / team-kit·공통 전송 / team-kit·도구 묶음).
   TASK-02 첫 커밋은 schemas/hejo-local-v1.json(design 3.1 표 그대로)이다. team-kit 갈래는 이 파일로 가짜 입구를 만든다.
   team-kit·직원 플러그인 절차: HEJO-CONNECTIONS design 7.1 그대로. 실행 중 원본(TK, CP)은 고치지 않는다. <운영 저장소> HEAD로
   임시 worktree를 만들고, 바꿀 파일마다 실행본과 worktree 기준 파일의 sha256이 같은지 확인해 impl-report에 적는다(다르면 멈추고 보고).
   게이트웨이 환경 Python과 임시 HERMES_HOME으로 시험한다(시스템 python3로는 이 저장소의 scan_private·test.sh가 실패한다.
   HEJO_PYTHON을 Hermes 설치의 게이트웨이 환경 Python으로 둔다). --rebaseline 금지.
   design 4.2·4.4 표의 [조사 보고] 줄은 착수 때 파일을 직접 읽어 확인하고, 표에 없는 Slack 쓰기 경로를 찾으면 같은 규칙으로 옮기고
   impl-report에 줄을 더한다. 조사가 못 본 곳(야간 일괄, 빈틈 검토, 기억 정리, 금고 백업 첫 질문, reply_buttons.py의 글 고치기)은
   TASK-06 첫 단계에서 읽는다. 다른 저장소·본체에 Slack 쓰기가 있으면 멈추고 보고.
   버튼 누름의 식별자는 design 5절 표로 확정했다(문과 hermes_reply의 hejo 설치는 바꾸지 않고, team-kit의 읽기 함수가
   _hermes_button.message_id를 읽는다. 인스타 승인 훅·감시의 draft_post·bind/refuse, proposal_decisions의 장부 찾기를 바꾼다).
   코드가 이 표와 다르게 움직이면 멈추고 보고.
   다시 보내는 호출자와 일회성 호출자의 구분을 경로마다 impl-report 표에 적는다(design 4.1).
   TASK-08: AT-SM-71에서 hejo·Slack 도구 집합이 같아지지 않으면 차이 목록을 보고하고 멈춘다(임의로 도구를 빼거나 넣지 않음).
   금지 범위:
   - 게이트웨이 재시작, reload-plugins, install/hejo-release, 상주 프로그램 재시작, 조립기 운영 실행(모두 TASK-10).
   - 운영 ~/.hermes의 지시서·금고·config.yaml·cron/jobs.json·상태 파일 쓰기. delivery.platform을 운영에 넣기.
   - 운영 ~/.hermes의 .env·auth.json·토큰 파일 열기. 운영 기록장·소켓에 글 올리기(운영 입구 호출 금지).
   - 실제 Slack 글, 실제 인스타·네이버 고객 글 보내기. 시험은 가짜 응답만.
   - 개인값(직원 id·이름·채널 이름과 id·주소·계정·절대 경로)을 이 저장소의 코드·시험·문서에 쓰기. Hermes 본체·ddots 수정. git push.
   - 앱(app/) 변경, 앱 버전 올리기. 수락 기준·수락 시험 명세·spec·design 본문 수정.
   - TASK-09(일 넘기기·프로젝트 허브) 착수. project_referral.py·project_threads.py·project_work.py·project_channel.py·
     project_alerts.py의 동작을 바꾸지 않는다.
   선행 작업: 없음.
10. 가정·미확정:
    - [미확정·착수 차단] REQ-SM-08.AC-05(일 넘기기·프로젝트 허브). 계획 담당이 TASK-09a로 조사해 보완한 뒤 따로 인계한다.
    - [가정] design 3.3: 다른 직원을 부른 뒤에도 스레드 주인은 바뀌지 않는다. 계획 검증에서 바뀌면 문서가 먼저 고쳐진다.
    - [가정] design 4.2 표가 직접 전송 경로의 전부다(조사 보고 기준). 더 찾으면 9번대로.
    - [미실행] hejo 세션의 실제 도구 목록. TASK-08의 AT-SM-71이 처음 잰다.
    - 함수 이름·배치·내부 구조·화면 문장 세부는 구현 담당이 정한다(design에 고정한 경로·필드·오류 이름·금고 키·직책 키 제외).
11. 사용자 확인: 범위·Slack 끝 상태·방 범위·전환 방식·시스템 보고 받을 곳·입구 방식·옮길 규칙·도구 묶음·재시작 알림은 사장이
    2026-11-21 질문 도구로 정했다(brainstorm.md). 계획 확인은 계획 검증 통과 뒤 사장의 구현 승인으로 한다.

[인계 전 점검]
- 현재 코드·계약·명세가 기준 커밋과 호환되는가? 예(이 저장소 cb06e7d에서 문 코드 확인, <운영 저장소> 66f2a44c에서 조사).
- G1–G4: G1 spec REQ·AC·범위 밖·사장 결정 기록, 미확정은 SM-08.AC-05 하나(착수 차단 표시).
  G2 현황 근거(파일:줄, [확인]/[조사 보고] 구분), 칸 표, 기존 경로 판정과 공존의 권위 경로·종료 조건.
  G3 AC↔AT 연결표(수락 시험 명세 끝), 계획 재검증 대기(1회차 지적 반영은 plan-review.md).
  G4 고위험 근거·롤백·전환 절차(design 7절). 운영 적용은 별도 인계(TASK-10).
```
