# 설계 인계: HEJO-TELEGRAM / TASK-07 서버 적용

```text
[설계 인계: HEJO-TELEGRAM TASK-07 / 서버 적용]
0. 기준: 적용 대상 = 이 인계서를 담은 커밋(main). 제품 코드 기준 1ef3ad27fbe0e960fb542ea14bd0a3ef7d62262e(verdict 2차 통과,
   검증 커밋 adac5cb). 승인: 사장 허가(2026-11-23 "준비끝" — 봇·포럼 그룹·봇 관리자 권한·토큰·허용 계정 준비 완료 보고).
   운영 모드: 연합개발(교차 모델).
1. 공식 문서: spec.md REQ-HT-09, design.md 11절(위험·적용 순서·롤백), tasks.md TASK-07, 수락 시험 AT-HT-60·61,
   선례 evidence/HEJO-IMESSAGE/TASK-10.md(절차·기록 형식).
2. 요구와 수락 기준: REQ-HT-09.AC-01·02. 적용 전 기록과 롤백 절차를 먼저 쓰고, 공용 릴리스 갱신 → 게이트웨이 재시작 →
   hejo·telegram·Slack 연결과 새 오류 0건 확인.
3. 유지할 계약: 운영 설정·비밀 파일(.env·config.yaml·auth.json·토큰 파일)을 열지도 쓰지도 않는다(사장이 이미 넣음).
   Hermes 본체·플러그인·team-kit·ddots 무수정. 기록장·금고·공용 창고 자료 무조치(옛 imessage.json·shared/hejo/imessage 지우지 않음).
   실제 텔레그램·아이메시지·Slack 메시지를 에이전트가 보내지 않는다(짝짓기·실물은 사장 M1~M8).
4. 흐름: (1) 적용 전 기록 → (2) 텔레그램 의존성 확인 → (3) install/hejo-release → (4) hejo-install --check →
   (5) 처리 중 차례 0 확인 뒤 게이트웨이 재시작 1회 → (6) 재시작 뒤 확인.
5. 경로 판정: 공용 릴리스 교체(아이메시지 문 → 텔레그램 문). 적용 순간 hejo의 아이메시지 연결이 사라지고 photon은
   hejo 이전 경로(안내원·Hermes)로 돌아간다(사장 결정).
6. 위험도: 고위험(운영 게이트웨이·인증). 필요 증거 수준 3. 롤백 조건: 아래 6번 확인 중 하나라도 실패.
7. 변경 성격: 의미 변경 적용. 비교: 재시작 전후 연결 목록(photon 연결은 유지되어야 함 — Hermes 쪽 문은 그대로).
8. 수락 시험: AT-HT-60(적용 전 기록·롤백 절차 빈칸 0), AT-HT-61(연결·오류·telegram_status). 기대값 출처: spec REQ-HT-09.
9. 작업 범위와 절차(증거는 evidence/HEJO-TELEGRAM/TASK-07.md, 로그는 추적 제외 .build/HEJO-TELEGRAM/task07/):
   (1) 적용 전 기록: 착수 HEAD·작업 트리 상태, 현재 공용 RELEASE 커밋(= 롤백 대상), 게이트웨이 상태,
       금고·공용 창고 파일의 존재 여부·수정 시각(내용 열지 않음).
       `git diff --stat <현재 RELEASE> HEAD -- gate schemas hub install config`를 기록한다. 이 작업(HEJO-TELEGRAM)과
       이미 공개·적용 완료로 판정된 작업 외의 미검증 변경이 들어 있으면 설치하지 않고 멈춰 보고한다.
       롤백 명령(경로 변수 채움)을 적용 전에 문서에 쓴다.
   (2) 텔레그램 의존성: Hermes venv Python으로 `import telegram` 가능 여부와 판(22.8)을 확인한다. Hermes는 텔레그램을
       처음 쓸 때 스스로 설치한다(security.allow_lazy_installs 기본 참, telegram/adapter.py check_telegram_requirements).
       없으면 직접 설치하지 말고 재시작 뒤 Hermes의 자동 설치 결과를 확인한다. 재시작 뒤에도 없고 텔레그램이 연결되지 않으면
       롤백하지 말고(hejo 문 자체는 텔레그램 없이도 정상 — 상태 platform_ready:false) 보고한다. 본체가 정한 판
       `python-telegram-bot[webhooks]==22.8`을 Hermes venv에 설치하는 것은 그 보고 뒤 사용자 허가가 있을 때만.
   (3) `install/hejo-release`, RELEASE·공용 gate 파일 집합 대조.
   (4) Hermes venv Python `<release>/install/hejo-install --check`(설치 실행 없음).
   (5) 재시작 직전 active_agents 0 확인. 처리 중이면 2분 간격 재확인, 10분 넘으면 재시작하지 않고 보고.
       `hermes --profile default gateway restart` 1회.
   (6) 확인: 새 프로세스 시작, hejo(기본·보조)·telegram·photon·Slack 연결 로그, 재시작 이후 새 오류·역추적 0건,
       hejo의 telegram 처리기 등록(로그 또는 상태), 로컬 앱 연결로 `telegram{id}` 조회 → `telegram_status{platform_ready:true,
       paired:false}`(앱 0.2.6은 telegram 기능을 모르므로 시험 클라이언트로 조회). 로그에서 그룹 id·계정 id·토큰 노출 여부를
       hejo 로거 줄에 대해 확인(0건).
   금지: 운영 설정·비밀 파일 열기/쓰기, 앱 사본 교체·앱 공개(TASK-07b), 실제 메시지 발송, Hermes 본체·플러그인·team-kit 수정,
   git push, 재시작 2회 이상(롤백 재시작 제외).
   병렬 갈래: 없음(운영 단일 절차).
10. 가정·미확정:
    - [가정] 사장이 넣은 토큰·허용 계정이 Hermes 설정에 올바르게 들어 있다. 에이전트는 내용을 보지 않고 연결 로그로만 판단한다.
    - [가정] 앱 0.2.6은 텔레그램 설정 화면이 없다. 짝짓기는 TASK-07b(앱 공개) 뒤 M1에서 한다.
11. 사용자 확인: 사장이 서버 적용을 허가했다(2026-11-23).

[롤백]
- 조건: (6)의 연결·오류 확인 실패(텔레그램 의존성 부재만은 제외 — (2)대로 보고).
- 절차: 적용 전 RELEASE 커밋을 임시 worktree로 꺼내 install/hejo-release → 게이트웨이 재시작 1회 → RELEASE·gate 대조,
  hejo·photon·Slack 연결과 새 오류 0건 확인. 옛 아이메시지 짝·설정 파일은 그대로 남아 있으므로 아이메시지 연결이 돌아온다.
  새 파일(telegram.json, shared/hejo/telegram/)은 남겨도 된다.
```
