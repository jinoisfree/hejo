# 설계 인계: HEJO-CONNECTIONS / TASK-02~04 에이전트 연결 화면 고치기

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸 없음.

```text
[설계 인계: HEJO-CONNECTIONS TASK-02~04 / 문·앱·team-kit]
0. 기준: 제품 코드 기준 1ca3f27(이 저장소 main, HEJO-IMESSAGE 완료 시점. 그 뒤 커밋은 이 작업의 계획 문서뿐) / 계획 문서 기준은
   이 인계서를 담은 커밋(3판, 부모 4d2fd88) / <운영 저장소> 9e68b39b /
   spec 2판·design 3판·수락 시험 명세 3판·tasks 3판 2026-11-20(계획 검토 1·2회차 반영, plan-review.md) / 승인 상태: 사장 요청(2026-11-20) 기반, 계획 확인은 사장이 구현 담당을
   고르는 것으로 한다 / 운영 모드: 연합개발(교차 모델 + 계획 검증, 1회차 6건·2회차 2건 수용·반영, 재검증 대기)
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
5. 기존 경로 판정: design 5절(교체 7, 제거 1, 통합 1, 유지 1, 결정 교체 1).
6. 위험도: 고위험(자격 값 찾기·비밀 입력 흐름·운영 시설 변경). 필요 증거 수준 2(임시 HERMES_HOME + 가짜 관리 서비스·가짜 명령,
   앱은 가짜 문서). 운영 적용(3)·실물(4)은 TASK-05~07.
   롤백: 이 저장소 커밋 되돌림. team-kit은 이번 지시에서 운영 원본을 바꾸지 않으므로(worktree 브랜치) 그 브랜치를 버리면 된다.
   운영 적용 때의 보관본·sha256 기반 롤백은 design 7.2(TASK-05).
7. 변경 성격: 의미 변경(실패 처리·표시 줄·안내·흐름). 보존 비교: AT-HC-09·29·48 회귀, `bash scripts/test.sh` 전체.
8. 수락 시험: tests/acceptance/HEJO-CONNECTIONS.md AT-HC-01~11, 20~29, 40~52. 상태: 명세 완료·코드 미작성·미실행·미검토.
   기대값 출처: spec 요구, design 2~4절. 기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md TASK-02·03·04 영향 파일. TASK마다 별도 커밋, impl-report.md에 TASK별 절.
   병렬 갈래: 있음(tasks.md "병렬 갈래" — 문 / 앱 / team-kit).
   TASK-03 첫 단계: 멈춤 원인을 재현하고 impl-report에 원인·재현 절차를 쓴 뒤 고친다(design 3.3). 설명되지 않으면 멈추고 보고.
   TASK-04 절차(design 7.1): 실행 중 원본(TKL)은 고치지 않는다. <운영 저장소> HEAD로 임시 worktree를 만들고, 바꿀 파일마다
   TKL 실행본과 worktree 기준 파일의 sha256이 같은지 확인해 impl-report에 적는다(다르면 멈추고 보고). worktree의
   hermes/plugin-store/team-kit에서 고치고, 게이트웨이 환경 Python과 임시 HERMES_HOME으로 시험한다. 결과는 worktree 브랜치
   커밋(바꿀 파일 목록·기준 sha256 포함 보고). <운영 저장소> main·./sync·TKL은 건드리지 않는다(TASK-05에서 적용).
   그 저장소 main에는 다른 작업의 미커밋 변경이 있다(hermes_governance/paseo_authority.py, hermes_owner_chat.py,
   hermes_reply/plugin.py, hermes_team_services/wait_jobs.py, 시험·학습 파일). 이번에 바꿀 파일과 겹치면 멈추고 보고.
   바꾸는 파일 중 게이트웨이가 import하는 파일이 있으면 보고에 적는다. --rebaseline 금지.
   TASK-02 추가 범위: gate/connections.py의 응답 해석 오류 구분(design 2.2a)과 undo_available 읽기 전용화(2.2b).
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
      찾는다(AT-HC-41이 두 경우를 모두 다룸. 후보 규칙·완전/부분/무효 분류는 design 4.1, AT-HC-41·50~52). 확인 결과를 impl-report에.
    - [미확인] 앱 멈춤의 정확한 원인. TASK-03이 재현으로 확정.
    - [사장 승인 대상] 시놀로지 아이디 미리 채우기(2026-11-08 결정 교체, REQ-HC-04.AC-02). 사장이 이 계획을 보고 구현 담당을 고르면 승인으로 본다.
    - 함수 배치·내부 구조·문장 세부는 구현 담당이 정한다(design에 고정한 문장·라벨·필드 이름 제외).
    착수 차단 없음.
11. 사용자 확인: 고칠 것 1~5와 기준(쉬운 말, 클릭, 서버가 아는 값은 묻지 않음, 비밀번호만 묻기, 연결 불가 앱 기본 숨김)은
    사장 요청 원문. 에이전트 제안: 미설정 키 줄 제거, 아이디 미리 채우기, X 쿠키 자동 읽기는 범위 밖 — 계획과 함께 확인받는다.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? 예(계획 문서만 추가).
- G1: 범위 안·밖, REQ·AC, 미확정 표시. G2: spec 1절 근거, design 5절 판정, 7절 롤백. G3: AC ↔ AT 연결(수락 시험 명세 표),
  독립 검토는 계획 검증 1·2회차 BLOCKED → 반영, 재검증 대기. G4: 위험도·롤백·TASK 연결·기준 커밋 있음.
```

## AC ↔ 시험

| AC | 시험 |
|---|---|
| HC-01.AC-01~03 | AT-HC-01, 02, 04 |
| HC-01.AC-04·05 | AT-HC-20, 21 |
| HC-02 | AT-HC-03, 05, 10, 11 |
| HC-03.AC-01·02 | AT-HC-06, 07 |
| HC-03.AC-03·04 | AT-HC-24, M3 |
| HC-04 | AT-HC-40~47, 50~52 |
| HC-05 | AT-HC-05, 22, 23, M4 |
| HC-06 | AT-HC-08, 25~28, 49, M5, M6 |
| HC-07 | TASK-06, M7 |
| NFR | AT-HC-10, 44, 47 |

## 그 다음 (이번 지시 밖)

TASK-02~04 검토 통과 뒤 계획 담당이 TASK-05(서버 적용, 롤백 먼저), TASK-06(0.2.2 공개 준비, 이전 TASK-07b 절차)을 보완 지시로 낸다. 공개(publish)와 푸시는 사장이 한다.

## 보완 지시 1 (구현 검토 1차, [verdict.md](verdict.md))

- 기준: 이 저장소는 이 지시를 담은 커밋(design 4판·수락 시험 명세 4판), 운영 저장소는 worktree 브랜치 `hejo-connections-20261120` `1c0ea8a5`.
- 할 일:
  1. **V-1(차단, 설계 오류)** team-kit `synology_setup.prepare()`를 design 4판 4.1에 맞춘다.
     - 자기 초안·이전 설정은 주소 두 개가 함께 검사를 통과할 때만 출처로 쓴다.
     - 불완전하거나 틀리면 다른 직원·Drive Client 후보를 찾는다.
     - 완전 후보가 1개면 초안 주소를 그 값으로 바꿔 저장(`stage_values`)하고, `address`를 기록하고, 로그인 단계 `hint`를 보인다.
     - 완전 후보가 여럿이면 고르기와 `input_error`.
     - 완전 후보가 없으면 칸별로 채우고 주소 단계로 간다.
  2. **V-2(비차단, 설계 누락)** 후보 라벨은 "<link_host> · <아이디>" 꼴로, 같은 라벨이면 출처 꼬리말을 붙인다. 비밀값·직원 id는 넣지 않는다.
  3. **V-3(비차단, 구현)** 앱의 `app_undo` 확인 문구를 동작에 맞춘다. 진행 중인 연결은 "처음부터 다시", 연결된 앱은 "되돌리기"(예: "마지막 연결 변경을 되돌릴까요?").
  4. AT-HC-53·54를 team-kit 새 시험에 옮기고, V-3은 앱 시험에 한 사례를 더한다.
- 검사: 같은 worktree에서 team-kit 관련 시험(이전 27개 파일 + 새 사례), `airport-check --snapshot <worktree>`, 이 저장소 `bash scripts/test.sh`, `scripts/scan_private.py`. mutation 1회: V-1 규칙을 되돌리면 AT-HC-53(가)가 실패해야 한다.
- 운영 자료 확인(읽기만, 값 출력 금지): 고친 `prepare()`를 운영 홈에 대해 읽기 전용으로만 시뮬레이션해 직원 B의 첫 응답 꼴(단계 종류·사람이 넣는 칸 id)을 impl-report에 적는다. 초안·금고·`.env`를 쓰는 호출(`app connect` 실행)은 금지다. 쓰기 없이 할 방법이 없으면 생략하고 이유를 적는다.
- 금지: 앞 인계서 9항과 같다(운영 원본·main·sync·재시작·공개·푸시 금지, 직원 B 초안 변경 금지).
- 보고: impl-report.md에 "보완 1" 절. 커밋은 이 저장소(앱)와 worktree 브랜치(team-kit)에 각각.

## 보완 지시 2 — TASK-05 서버 적용 (검토 2차 통과 뒤, [verdict.md](verdict.md) 2차)

- 근거: 사장 요청 원문("서버 재시작이 필요하면 직원이 일하지 않을 때 하고, 되돌리는 방법을 먼저 적어 둔다"), design 7.2. 위험도 고위험, 필요 증거 수준 3(실제 운영 서버에서 실행·관측).
- 대상:
  - 문은 hejo main HEAD(이 지시를 담은 커밋. 제품 코드는 `20adc4d`와 같다).
  - team-kit은 worktree 브랜치 `hejo-connections-20261120` `fe697e3b`의 `hermes/plugin-store/team-kit/` 아래 변경 파일 전부(`git diff --name-only 9e68b39b..fe697e3b`: lib 6개, tests 5개).
  - 운영 저장소 문서 `docs/연결-상태.md`.
- 순서. 각 단계의 실패 조건에 걸리면 그 단계의 되돌리기를 하고 멈춘 뒤 보고한다.
  1. **롤백 기록 먼저.** impl-report "TASK-05" 절에 아래를 실제 값으로 적는다. 빈 칸이 있으면 진행하지 않는다.
     - 공용 릴리스 폴더의 현재 `RELEASE` 커밋
     - 게이트웨이 pid·시작 시각(`gateway.status` 런타임 정보)
     - team-kit 바꿀 실행본마다 경로(`<HOME>` 상대)·sha256
     - 보관 폴더 경로(작업 문서 밖, 0700 임시 폴더)
     - 운영 저장소 main HEAD
     - 되돌리기 명령. design 7.2의 세 줄(team-kit 보관본 복원 / 문은 기록한 `RELEASE` 커밋을 임시 worktree로 꺼내 `install/hejo-release` → 재시작 / 앱은 이번에 바꾸지 않음)을 실제 경로·커밋으로 채운다.
  2. **team-kit 적용.**
     - 바꿀 실행본의 sha256이 impl-report TASK-04 표의 기준 값과 같은지 다시 확인한다. 새 파일은 실행본에 아직 없어야 한다. 다르면 멈춘다.
     - 실행본을 보관 폴더에 복사하고, 보관본의 sha256이 실행본과 같은지 확인한다.
     - 파일마다 같은 폴더의 임시 파일에 쓴 뒤 이름 바꾸기로 교체한다.
     - 교체 뒤 실행본의 sha256이 `fe697e3b`의 파일과 같은지 확인한다.
     - 읽기 확인: `~/.hermes/bin/hermes-connections status --json`과 `apps --json`이 종료 0이고 JSON으로 읽히는지 본다. 출력 내용은 보고에 옮기지 않고 직원 수·앱 수만 적는다.
     - 실패하면 보관본으로 즉시 복원하고 같은 확인을 다시 한 뒤 멈춘다.
  3. **운영 저장소 기록.**
     - 운영 저장소 main에서 `./sync`를 실행한다. 토큰 경고가 나면 커밋하지 않고 보고한다.
     - `docs/연결-상태.md`는 main의 같은 파일이 `9e68b39b`와 같을 때만 worktree 판으로 바꾼다. 다르면 멈춘다.
     - `./airport-check`가 통과해야 한다. `--rebaseline`은 금지다.
     - `git commit --only <이번 경로들>`로 자기 경로만 커밋한다. 다른 작업의 미커밋 파일은 건드리지 않는다.
     - 푸시하지 않는다.
  4. **문 적용과 재시작.**
     - `install/hejo-release`(기본 대상)를 실행한다.
     - 공용 릴리스의 `RELEASE`가 대상 커밋인지, 공용 릴리스 `gate/`가 대상 커밋의 `gate/`(시험 폴더 제외)와 같은지 확인한다.
     - 재시작은 `~/.hermes/bin/hermes-connections gateway restart --json`으로만 한다. 이 명령이 처리 중인 대화를 BUSY로 거절한다.
     - BUSY면 10분 간격으로 최대 3번 다시 시도한다. 그래도 BUSY면 멈추고 보고한다. 이미 바꾼 team-kit은 그대로 둬도 된다(명령이 호출마다 읽는다).
     - 강제 종료·다른 재시작 방법은 쓰지 않는다.
  5. **확인.**
     - 새 pid·시작 시각
     - 재시작 명령이 알려 준 채널 재연결 결과
     - `gateway.log`의 hejo 문 시작 줄(포트 바인딩)
     - `status`·`apps` 읽기
     - 재연결이 확인되지 않으면 1번에 적은 되돌리기를 실행하고 보고한다.
- 하지 않는 것:
  - 앱 사본 교체·버전 올림·공개(TASK-06)
  - 직원 B 초안 변경, `app connect` 실행
  - 운영 `config.yaml`·`.env`·`auth.json`·토큰·`hejo/admin.json` 열기
  - 관리 서비스 직접 호출
  - Hermes 본체·ddots 수정
  - git push
  - spec·design·수락 시험 명세 수정
  - 실제 Slack·고객 메시지
- 참고: 0.2.2 설치 전까지는 0.2.1 앱이 새 문과 통신한다. 새 필드(`unread`·`hidden_by_default`)는 옛 앱이 무시하고, 키 줄만 줄어든다. 옛 앱은 실패를 여전히 "관리 기능 꺼짐"으로 표시하는데, 이는 TASK-06에서 해소된다.
- 보고: impl-report "TASK-05" 절. 운영 저장소 커밋 해시, 각 명령의 종료 코드·로그 경로를 적는다. 로그 줄에는 직원 id·주소·토큰을 넣지 않는다.
