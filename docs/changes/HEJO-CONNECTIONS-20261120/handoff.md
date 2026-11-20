# 설계 인계: HEJO-CONNECTIONS / TASK-02~04 에이전트 연결 화면 고치기

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-CONNECTIONS TASK-02~04 / 문·앱·team-kit]
0. 기준: base_commit: 이 인계서를 담은 커밋(이 저장소 main, 계획 문서만 추가, 부모 1ca3f27) / <운영 저장소> 9e68b39b /
   spec·design·수락 시험 명세 1판·tasks 1판 2026-11-20 / 승인 상태: 사장 요청(2026-11-20) 기반, 계획 확인은 사장이 구현 담당을
   고르는 것으로 한다 / 운영 모드: 연합개발(교차 모델, 계획 검증 없음)
   <운영 저장소>는 매일 자동 기록 커밋으로 움직인다. 착수 때 HEAD를 impl-report에 적는다.
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-CONNECTIONS-20261120/{spec,design,tasks}.md,
   tests/acceptance/HEJO-CONNECTIONS.md, <운영 저장소>/AGENTS.md, <운영 저장소>/docs/연결-상태.md. ADR 없음.
2. 요구와 수락 기준: REQ-HC-01~06, NFR-HC-01~03(REQ-HC-07 공개는 이번 지시 밖).
   핵심: 부분 실패는 그 부분만 빠지고 unread·로그가 남는다. 키 줄은 값 있음 ∪ 켠 묶음 필요 키. 연결 불가 앱·미설치 MCP는 숨김.
   시놀로지 주소는 서버가 찾고 사람은 비밀번호만. 입력 창은 다음 단계로 이어지고 앱 전체가 막히지 않는다.
3. 유지할 기존 계약: 문↔앱 성공 프레임 모양(새 필드 unread·part·hidden_by_default만 추가), 줄 id·동작 id,
   connection_result outcome 값 목록, public() 허용 원칙, team-kit의 status·apps 읽기 전용, 비밀값 표준 입력·.env 허용 이름·
   저장 전 확인·되돌리기 규칙, Hermes 본체 무수정, ddots 무수정.
4. 책임과 흐름: design 1절. 부분 실패 판단·로그는 문 Connections 하나, 실패 문장 선택은 앱 ConnectionsModel 하나,
   값 찾기·안내 문장은 team-kit 시설 하나.
5. 기존 경로 판정: design 5절(교체 4, 제거 1, 통합 1, 유지 1, 결정 교체 1).
6. 위험도: 고위험(자격 값 찾기·비밀 입력 흐름·운영 시설 변경). 필요 증거 수준 2(임시 HERMES_HOME + 가짜 관리 서비스·가짜 명령,
   앱은 가짜 문서). 운영 적용(3)·실물(4)은 TASK-05~07.
   롤백: 이 저장소 커밋 되돌림. team-kit은 바꾼 TKL 파일을 <운영 저장소> 직전 커밋 내용으로 복원 → ./sync.
7. 변경 성격: 의미 변경(실패 처리·표시 줄·안내·흐름). 보존 비교: AT-HC-09·29·48 회귀, `bash scripts/test.sh` 전체.
8. 수락 시험: tests/acceptance/HEJO-CONNECTIONS.md AT-HC-01~10, 20~29, 40~48. 상태: 명세 완료·코드 미작성·미실행·미검토.
   기대값 출처: spec 요구, design 2~4절. 기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md TASK-02·03·04 영향 파일. TASK마다 별도 커밋, impl-report.md에 TASK별 절.
   병렬 갈래: 있음(tasks.md "병렬 갈래" — 문 / 앱 / team-kit).
   TASK-03 첫 단계: 멈춤 원인을 재현하고 impl-report에 원인·재현 절차를 쓴 뒤 고친다(design 3.3). 설명되지 않으면 멈추고 보고.
   TASK-04 절차: TKL에서 고친다 → team-kit 시험(게이트웨이 환경 Python, <운영 저장소>/AGENTS.md 안내) → <운영 저장소>에서
   ./sync → ./airport-check → git commit --only로 자기 경로만 커밋. 그 저장소에는 다른 작업의 미커밋 변경이 있다
   (hermes_governance/paseo_authority.py, hermes_owner_chat.py, hermes_reply/plugin.py, hermes_team_services/wait_jobs.py,
   tests/test_hejo_work_wait.py, tests/test_review55_hejo.py, 학습 파일). 건드리지 않는다. 같은 파일을 고쳐야 하면 멈추고 보고.
   ./sync가 토큰 경고를 내면 커밋하지 않고 보고. --rebaseline 금지. TKL 변경 중 게이트웨이가 import하는 파일이 있으면 보고에 적는다.
   금지 범위:
   - 게이트웨이 재시작, reload-plugins, install/hejo-release, 앱 사본 교체, 버전 올리기, hejo-publish·hejo-ship(모두 TASK-05·06).
   - 운영 ~/.hermes의 .env·auth.json·토큰 파일·hejo/admin.json 열기. 관리 서비스 직접 호출(토큰 필요).
   - 실제 Synology Drive Client 자료·Obsidian 설정·운영 금고 값을 시험·문서·보고에 옮기기(구조·존재 여부만 확인 가능).
   - 직원 B 초안 등 운영 연결 상태 변경, 실제 Slack·고객 메시지, Hermes 본체·ddots 수정, git push.
   - 개인값(직원 id·이름·주소·QuickConnect ID·절대 경로)을 코드·시험·문서에 쓰기.
   - 수락 기준·수락 시험 명세·spec·design 본문 수정.
   선행 작업: 없음.
10. 가정·미확정:
    - [가정] 직원 A 실패는 instagram-dm 묶음 설정 400. 토큰 없이 확인 못 함. 고친 문의 로그로 TASK-05에서 확인(M2). 틀려도 이번 설계는
      부분 격리로 같은 증상을 막는다.
    - [가정] Drive Client 자료만으로 정책에 맞는 api_base 전체를 만들 수 있는지 모른다. 못 만들면 api_base는 다른 직원의 연결에서만
      찾는다(AT-HC-41이 두 경우를 모두 다룸). 확인 결과를 impl-report에.
    - [미확인] 앱 멈춤의 정확한 원인. TASK-03이 재현으로 확정.
    - [사장 승인 대상] 시놀로지 아이디 미리 채우기(2026-11-08 결정 교체, REQ-HC-04.AC-02). 사장이 이 계획을 보고 구현 담당을 고르면 승인으로 본다.
    - 함수 배치·내부 구조·문장 세부는 구현 담당이 정한다(design에 고정한 문장·라벨·필드 이름 제외).
    착수 차단 없음.
11. 사용자 확인: 고칠 것 1~5와 기준(쉬운 말, 클릭, 서버가 아는 값은 묻지 않음, 비밀번호만 묻기, 연결 불가 앱 기본 숨김)은
    사장 요청 원문. 에이전트 제안: 미설정 키 줄 제거, 아이디 미리 채우기, X 쿠키 자동 읽기는 범위 밖 — 계획과 함께 확인받는다.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? 예(계획 문서만 추가).
- G1: 범위 안·밖, REQ·AC, 미확정 표시. G2: spec 1절 근거, design 5절 판정, 7절 롤백. G3: AC ↔ AT 연결(수락 시험 명세 표),
  독립 검토는 계획 검증 꺼짐으로 최종 검토에서. G4: 위험도·롤백·TASK 연결·기준 커밋 있음.
```

## AC ↔ 시험

| AC | 시험 |
|---|---|
| HC-01.AC-01~03 | AT-HC-01, 02, 04 |
| HC-01.AC-04·05 | AT-HC-20, 21 |
| HC-02 | AT-HC-03, 05, 10 |
| HC-03.AC-01·02 | AT-HC-06, 07 |
| HC-03.AC-03·04 | AT-HC-24, M3 |
| HC-04 | AT-HC-40~47 |
| HC-05 | AT-HC-05, 22, 23, M4 |
| HC-06 | AT-HC-08, 25~28, M5, M6 |
| HC-07 | TASK-06, M7 |
| NFR | AT-HC-10, 44, 47 |

## 그 다음 (이번 지시 밖)

TASK-02~04 검토 통과 뒤 계획 담당이 TASK-05(서버 적용, 롤백 먼저), TASK-06(0.2.2 공개 준비, 이전 TASK-07b 절차)을 보완 지시로 낸다. 공개(publish)와 푸시는 사장이 한다.
