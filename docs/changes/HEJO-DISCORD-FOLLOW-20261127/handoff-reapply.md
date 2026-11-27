[설계 인계: HEJO-DISCORD-FOLLOW TASK-03 재적용 / 롤백된 운영 문을 같은 후보로 다시 설치]

0. 기준: 운영 후보 `9acf0567694a4bbfebb5b248fb937975624d7acd`, 이미 만든 공용 릴리스 `<공용 릴리스 폴더>/9acf0567694a-discord-follow/hejo`(RELEASE = 후보, 2026-11-27 계획 담당 확인), 현재 링크 `c2b292d3adb0-result-done` / spec 4판 / 2026-11-27 / [verdict.md](verdict.md) 2회차(부분 완료, 원인: 관측 도구 구현 오류) / 사용자 허가: 2026-11-27 계획 담당 질문 (1)에 사용자가 "1"로 답함 = 재설치·재시작 1회 + 실패 시 롤백 재시작 1회.
1. 공식 문서: [spec.md](spec.md) 5절(5.3 롤백, 5.4 승인 범위), [handoff.md](handoff.md) 9번 TASK-03, 수락 시험 AT-DF-18·22, 운영 저장소 `docs/changes/HEJO-DISCORD-FOLLOW-20261127/`(approved-snapshot.json, ops-targets.md).
2. 범위: 제품 코드 변경 없음. 같은 후보·같은 릴리스 폴더를 다시 링크한다. 새 릴리스를 만들지 않는다(폴더 RELEASE·소스 해시가 후보와 다르면 멈춤).
3. 절차
   (1) 사전 확인: 유휴(처리 중 턴·작업 0), 직전 게이트웨이 시작 뒤 300초 초과, 링크 = `c2b292d3adb0-result-done`. 다르면 멈춘다.
   (2) AT-DF-18 다시: 서버 사본(0700 임시 폴더) + `discord_follow_expect.py <사본> 1608` + 후보 시작 맞추기(가짜 디스코드). 통과 조건 (1)~(3) 그대로이며, 승인 대조는 같은 `approved-snapshot.json`이다. 차이는 seq 1608 뒤 삭제 레코드(`since_seq`)만 허용. 결과 id는 운영 저장소에만 둔다. 실패면 적용하지 않고 멈춘다.
   (3) 적용 전 기준 고정: 플랫폼별 연결 줄 수, 그리고 **로그 레코드 단위**(여러 줄 경고는 머리 줄 하나로 묶음)의 ERROR·CRITICAL 기준. 관측은 수정한 `apply-v4.py` 규칙(재시작 알림 경고 "Dedicated gateway_restart notification was not delivered"와 딸린 줄은 알려진 경고)을 쓰고, 그 파일을 운영 저장소 작업 폴더에 증거로 복사한다.
   (4) `9acf0567694a-discord-follow`의 `hejo-install --home <루트 홈>` 1회 → 재시작 1회(운영 `AGENTS.md` 절차).
   (5) AT-DF-22: 링크 RELEASE = 후보, 디스코드 연결, `discord_reconcile` 한 줄. 기대값: `removed_posts` = 56 + (2)의 since_seq 글 묶음 수, `removed_messages` = 26 + since_seq 디스코드 글 수(이미 지운 것은 "없음"으로 셈), `kept_posts=0`, `failed=0`(edited·renamed·archived는 이미 맞췄으므로 0 또는 그 사이 새 변화 수 — 값만 기록). 플랫폼별 연결 줄 수 적용 전과 같음, 기준 밖 새 ERROR·CRITICAL 레코드 0.
   (6) 실패 판정이면 spec 5.3 롤백(재시작 1회) 뒤 멈추고 보고한다. 관측 도구의 판정이 로그 원문과 어긋나 보이면 롤백 전에 로그 레코드를 직접 읽어 판단 근거를 남긴다(같은 오판 반복 금지). 확실한 문 기동 실패·연결 감소·새 ERROR면 바로 롤백한다.
   (7) 적용 뒤 10분 동안 `discord_*_failed` 줄 수를 세어 기록한다(종류만).
   (8) ops-targets.md에 결과를 적고 운영 저장소에 `git commit --only docs/changes/HEJO-DISCORD-FOLLOW-20261127/`.
4. 금지: handoff.md 9번 금지 목록 그대로. 허가 밖 추가 재시작, 새 릴리스 만들기, 제품 코드 수정, 디스코드 시험 글, git push.
5. 위험도: 고위험(같은 비가역 삭제 경로. 이번에 새로 지울 것은 since_seq 항목뿐). 증거 수준 3.
6. 보고: impl-report.md에 "재적용" 절을 덧붙인다.
