# 설계 인계: HEJO-IMESSAGE / TASK-02~06 아이메시지를 hejo 방의 두 번째 문으로

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸은 없다.

```text
[설계 인계: HEJO-IMESSAGE TASK-02~06 / 문·안내원·앱]
0. 기준: base_commit: 이 인계서를 담은 커밋(이 저장소 main HEAD, 계획 문서만 추가) / spec·design·tasks·수락 시험 명세 1판 2026-11-19 /
   승인 상태: 브레인스토밍 결정 사용자 확정(2026-11-19), 계획 검증(교차 모델) 대기 / 운영 모드: 연합개발(교차 모델 + 계획 검증)
   운영 저장소 기준: 착수 시점의 <운영 저장소> HEAD를 impl-report에 적는다(매일 자동 기록 커밋으로 움직인다).
1. 공식 문서: docs/ARCHITECTURE.md, AGENTS.md, docs/changes/HEJO-IMESSAGE-20261119/{brainstorm,spec,design,tasks}.md,
   tests/acceptance/HEJO-IMESSAGE.md. team-kit은 <운영 저장소>/AGENTS.md. ADR 없음.
2. 요구와 수락 기준: REQ-HI-01~07, NFR-HI-01~04(REQ-HI-08은 이번 지시 밖). 핵심 정상: 코드로 짝지은 대화창의 글이
   연결된 방 새 스레드(답장이면 원래 스레드)의 사장 글이 되고, 완성된 직원 답이 이름표와 함께 답장으로 돌아간다.
   핵심 실패·보존: 활성이 아니면 photon 글은 원래 처리기로 같은 객체 그대로 한 번 간다(REQ-HI-03.AC-06). 판정 코드의 예외도
   통과로 끝난다. 발신 실패는 기록장·앱에 영향이 없다.
3. 유지할 기존 계약: Hermes 본체·photon 플러그인 무수정. 기록장 레코드 종류·형식 불변. 앱 수신(receive)·직원 발신(send·edit·
   delete·작성 중)의 앱 관측 동작 불변(AT-HI-30). 기능 `imessage`를 밝히지 않은 앱이 받는 프레임 불변. team-kit은 hejo가
   차지하지 않는 모든 글에서 동작 불변(AT-HI-33·34). 운영 설정(`config.yaml`·`.env`) 무변경.
4. 책임과 흐름: design 2절. 아이메시지 연결의 저장·판정·발신·상태는 새 모듈 하나가 맡고 adapter·server는 부르기만 한다.
   수신은 receive() 한 경로, 받은 글의 짝은 기록장 client_msg_id(`imessage:` 접두), 보낸 글의 짝은 sent.jsonl.
5. 기존 경로 판정: design 9절. receive()는 유지 + 응답 대상 일반화(두 번째 사장 글 기록 경로 금지). photon → 안내원 경로는
   유지하되 권위 판정은 claims_external 하나. 제거·교체되는 경로 없음.
6. 위험도: 고위험(인증 — 짝짓기가 사장을 정함, 운영 수신 경로를 감쌈). 필요 증거 수준 2(임시 HERMES_HOME + 실제 Hermes 모듈 +
   가짜 아이메시지 어댑터), AT-HI-39만 3(임시 홈 실제 게이트웨이). 운영 적용(3)·실물(4)은 TASK-07·08.
   롤백: 이 저장소 커밋 되돌림. team-kit은 TKL 파일을 고치기 전 내용으로 되돌리고 ./sync(재시작하지 않았으므로 실행 중 동작 무영향).
7. 변경 성격: 신규 기능(의미 추가). 보존 비교: AT-HI-30(기능 유무 기록장·프레임 동일), AT-HI-34(team-kit 기존 시험),
   `bash scripts/test.sh` 전체.
8. 수락 시험: tests/acceptance/HEJO-IMESSAGE.md AT-HI-01~39. 상태: 명세 완료·코드 미작성·미실행·미검토. 기대값 출처: spec 요구,
   design 3~7절. 코드는 구현 담당이 옮긴다(문: tests/acceptance/test_imessage.py, 앱: app/Tests/, 안내원: team-kit tests/).
   기대값·합격 기준을 바꾸지 말고, 바꿔야 하면 멈추고 보고.
9. 작업 범위: tasks.md 표의 TASK-02~06 영향 파일.
   순서: TASK-02 → (TASK-03 → TASK-04) / TASK-05 / TASK-06. TASK마다 별도 커밋, 끝날 때마다 impl-report.md에 절을 더한다.
   금지 범위:
   - 게이트웨이 재시작, `reload-plugins`, `install/hejo-release` 실행, 설치된 앱 사본 교체(모두 TASK-07).
   - 운영 `~/.hermes`의 설정·비밀 파일(`.env`, `auth.json`, 토큰 파일) 열기·쓰기. 예외는 TASK-05의 TKL 파일 수정뿐이다.
   - Hermes 본체·photon 플러그인·ddots 수정, 실제 아이메시지·Slack 발송, git push.
   - 개인값(실제 직원 id·이름·전화번호·대화창 id·절대 경로)을 코드·시험·문서에 쓰기.
   - 수락 기준·수락 시험 명세·spec·design 본문 수정.
   TASK-05 절차: TKL에서 고친다 → team-kit 시험(게이트웨이 환경 Python, <운영 저장소>/AGENTS.md의 pytest 안내) →
   <운영 저장소>에서 `./sync` → `./airport-check` 통과 → `git commit --only`로 자기 경로만 커밋(그 저장소에는 다른 작업의
   미커밋 변경이 있다. 건드리지 않는다). `./sync`가 토큰 경고를 내면 커밋하지 않고 보고. `--rebaseline` 금지.
   선행 작업: 없음. 병렬 갈래: 있음(tasks.md "병렬 갈래" 표 — 문 / 안내원 / 앱).
10. 가정·미확정:
    - [가정] 정착 시간 2초. TASK-04의 AT-HI-39로 재서 보고한다. 2초 이상이면 멈추고 보고(값은 계획 담당 승인 사항).
    - [가정] 다른 어댑터의 `_is_sender_authorized`를 읽기 전용으로 부를 수 있다. 안 되면 TASK-02에서 멈추고 보고.
    - [가정] 공장이 받은 photon 어댑터의 `handle_message`를 인스턴스 속성으로 바꾸면 photon 수신이 그 감싼 것을 탄다
      (team-kit 선례). 다르면 멈추고 보고.
    - `receive()`의 응답 대상 일반화 방식, 모듈 내부 구조, 앱 화면 배치·문구 세부는 구현 담당이 정한다(spec 문구는 고정).
    착수 차단 없음.
11. 사용자 확인: 브레인스토밍에서 연결 방식·방 바꾸는 곳·스레드 규칙·폰 보고·안내원·사장 확인·작업 범위를 사용자가 정했다
    (brainstorm.md 표). 에이전트 제안 5건(답장의 방, 이름표, 명령 문구, 완성된 글만, 첨부 제외)은 계획과 함께 확인받는다.

[인계 전 점검]
- 현재 코드·계약·명세가 base_commit과 호환되는가? 예(계획 문서만 추가).
- G1 요구: 범위 안·밖, REQ·AC 연결, 미확정 없음(가정 3건 표시). G2 현황·설계: design 1절 근거, 9절 판정, 11절 롤백.
  G3 시험: AC ↔ AT 연결(아래 표), 독립 검토는 계획 검증(교차 모델) 대기. G4: 위험도·롤백·TASK 연결·기준 커밋 있음.
```

## AC ↔ 수락 시험

| AC | 시험 | AC | 시험 |
|---|---|---|---|
| 01.AC-01 | AT-HI-01 | 04.AC-01·02 | AT-HI-20 |
| 01.AC-02 | AT-HI-02 | 04.AC-03·04 | AT-HI-21 |
| 01.AC-03 | AT-HI-03 | 05.AC-01·05 | AT-HI-22 |
| 01.AC-04 | AT-HI-04 | 05.AC-02 | AT-HI-23 |
| 01.AC-05 | AT-HI-05 | 05.AC-03 | AT-HI-24 |
| 01.AC-06 | AT-HI-06 | 05.AC-04 | AT-HI-25 |
| 01.AC-07 | AT-HI-07 | 05.AC-06·07 | AT-HI-26 |
| 02.AC-01 | AT-HI-08 | 05.AC-08 | AT-HI-27 |
| 02.AC-02·03 | AT-HI-09 | 05.AC-09 | AT-HI-28 |
| 02.AC-04 | AT-HI-10 | 05.AC-10 | AT-HI-29 |
| 02.AC-05 | AT-HI-11 | 05.AC-11 | AT-HI-30 |
| 03.AC-01 | AT-HI-12 | 06.AC-01 | AT-HI-31 |
| 03.AC-02 | AT-HI-13 | 06.AC-02·03 | AT-HI-33, 34 |
| 03.AC-03 | AT-HI-14 | 06.AC-04 | AT-HI-32 |
| 03.AC-04·05 | AT-HI-15 | 07.AC-01·03 | AT-HI-35 |
| 03.AC-06 | AT-HI-16 | 07.AC-02 | AT-HI-36 |
| 03.AC-07 | AT-HI-17 | 07.AC-04·05 | AT-HI-37 |
| 03.AC-08 | AT-HI-18 | 08.AC-01·02 | AT-HI-40, 41 (TASK-07) |
| 03.AC-09 | AT-HI-19 | 08.AC-03 | M1~M8 (TASK-08) |
| NFR-01~03 | AT-HI-38 | NFR-04 | AT-HI-07 |

## 보고

`docs/changes/HEJO-IMESSAGE-20261119/impl-report.md`에 TASK별로: 커밋, 바꾼 파일, 실행한 명령과 종료 코드, 도달한 증거 수준, AT별 결과, 가정 3건의 확인 결과, 미검증 범위, 멈춤 보고(있으면).
