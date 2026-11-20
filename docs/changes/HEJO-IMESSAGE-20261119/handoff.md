# 설계 인계: HEJO-IMESSAGE / TASK-02~06 아이메시지를 hejo 방의 두 번째 문으로

## 칸·원본·쓰기 주체·수명

[spec.md 첫 절](spec.md#칸원본쓰기-주체수명)을 따른다. 새 칸은 없다.

```text
[설계 인계: HEJO-IMESSAGE TASK-02~06 / 문·안내원·앱]
0. 기준: base_commit: 이 인계서를 담은 커밋(이 저장소 main HEAD, 계획 문서만 추가) / spec·design·수락 시험 명세 2판(계획 검증 1회차 반영)·tasks 1판 2026-11-19 /
   승인 상태: 브레인스토밍 결정 사용자 확정(2026-11-19), 계획 검증 1회차 BLOCKED 3건 수용·반영(plan-review.md), 재검증 대기 / 운영 모드: 연합개발(교차 모델 + 계획 검증)
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
8. 수락 시험: tests/acceptance/HEJO-IMESSAGE.md AT-HI-01~39, 42. 상태: 명세 완료·코드 미작성·미실행·미검토. 기대값 출처: spec 요구,
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
    - [한계, 요구로 확정] 문은 진행 글과 최종 답을 구분하지 못한다. 방에 남은 진행 글은 폰으로 간다(REQ-HI-05.AC-12, AT-HI-42).
      글 모양으로 진행 글을 걸러 내는 코드를 넣지 않는다.
    - [가정] 정착 시간 2초. TASK-04의 AT-HI-39로 재서 보고한다. 2초 이상이면 멈추고 보고(값은 계획 담당 승인 사항).
    - [가정] 다른 어댑터의 `_is_sender_authorized`를 읽기 전용으로 부를 수 있다. 안 되면 TASK-02에서 멈추고 보고.
    - [가정] 공장이 받은 photon 어댑터의 `handle_message`를 인스턴스 속성으로 바꾸면 photon 수신이 그 감싼 것을 탄다
      (team-kit 선례). 다르면 멈추고 보고.
    - `receive()`의 응답 대상 일반화 방식, 모듈 내부 구조, 앱 화면 배치·문구 세부는 구현 담당이 정한다(spec 문구는 고정).
    착수 차단 없음.
11. 사용자 확인: 브레인스토밍에서 연결 방식·방 바꾸는 곳·스레드 규칙·폰 보고·안내원·사장 확인·작업 범위를 사용자가 정했다
    (brainstorm.md 표). 에이전트 제안 5건(답장의 방, 이름표, 명령 문구, 남은 글만, 첨부 제외)은 계획과 함께 확인받는다.

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
| 05.AC-12 | AT-HI-42 | | |

## 보고

`docs/changes/HEJO-IMESSAGE-20261119/impl-report.md`에 TASK별로: 커밋, 바꾼 파일, 실행한 명령과 종료 코드, 도달한 증거 수준, AT별 결과, 가정 3건의 확인 결과, 미검증 범위, 멈춤 보고(있으면).

## 보완 지시 1: 구현 검토 1차 반영 (2026-11-20, 3판)

- **판정:** [verdict.md](verdict.md) 1차 — 부분 완료. 원인 분류: V-1~V-5 설계·계약 오류(요구 불변), V-6 수락 시험 오류 + 환경 요인. 문서를 먼저 고쳤다(spec·design·수락 시험 명세 3판). 기준 커밋: 이 지시를 담은 커밋.
- **고칠 것(hejo, `gate/imessage.py` 중심):**
  1. V-1·V-2 — 판정을 `claims_external` 하나로 모은다(REQ-HI-06.AC-01 3판, design 5절). 금고에 남은 코드와 같은 글은 유효 + 허용일 때만 참, 쓰인·만료된·허용 거부면 거짓(활성 대화창이어도). 감싼 처리기는 따로 허용 검사를 하지 않고 이 답만 쓴다. 코드 이력 저장, 코드 모양 추측, 원래 처리기 우회 호출은 넣지 않는다.
  2. V-3 — `sent.jsonl`·`settings.json`·`imessage.json` 손상이 문 시작과 앱 대화를 막지 않게 한다(NFR-HI-05, design 2절).
  3. V-4 — 방 삭제·보관으로 상태 값이 바뀌면 `imessage_status`를 방송한다(REQ-HI-02.AC-05).
  4. V-5 — 차지한 글 처리 중 예기치 않은 예외는 안내 + 로그 한 줄로 끝낸다(REQ-HI-03.AC-09, design 5절).
- **수락 시험:** AT-HI-11·19·31(보강), AT-HI-43·44(신규)를 코드로 옮기고, 구현 담당 진단 시험(`.build/HEJO-IMESSAGE/test_pair_replay_diagnostic.py`)의 경우는 AT-HI-43에 들어 있으므로 따로 추적하지 않는다. 기존 AT는 그대로 통과해야 한다.
- **TASK-05(team-kit):** 후보(`.build/HEJO-IMESSAGE/team-kit-candidate/`)를 실행 원본에 다시 적용해 AT-HI-33과 AT-HI-34(3판: 적용 전후 같은 환경에서 전체 시험, 실패 집합 동일·새 실패 0건)를 확인하고 두 결과를 보고한다. **그 뒤 실행 원본을 다시 복구한다.** `./sync`·`./airport-check`·운영 저장소 커밋은 이번에도 하지 않는다(기존 실패 1건에 대한 사용자 결정 대기). 후보가 3판 계약과 다르면 후보 파일을 고쳐 `.build`에 다시 보관한다.
- **검증:** `bash scripts/test.sh` 종료 0, 개인값 검사 종료 0(둘 다 Hermes venv·임시 `HERMES_HOME`), 인증 판정 mutation 1개(쓰인 코드 분기를 뒤집으면 AT-HI-43 실패) 기록. 필요 증거 수준 2.
- **금지:** 이전 지시와 같다(재시작·릴리스·앱 사본 교체·운영 설정·실제 발송·push·spec/design/수락 명세 수정 금지). 범위 밖 리팩토링 금지.
- **보고:** `impl-report.md`에 "보완 1" 절을 더한다(커밋, 지적별 고친 위치, 명령·종료 코드, team-kit 적용 전후 결과, 복구 확인).

## 보완 지시 2: 운영 저장소 기존 실패 해소 뒤 TASK-05 반영 (2026-11-20)

- **사용자 결정(2026-11-20):** team-kit 기존 시험 실패를 먼저 고친 뒤 양보 코드를 커밋한다. 이 결정으로 아래 TASK-05a를 이 작업 범위에 더한다. 판정: [verdict.md](verdict.md) 2차 — 부분 완료, 원인 분류 환경·외부 요인.
- **TASK-05a 기존 실패 해소(운영 저장소, 일반 · 증거 3 — 실제 운영 자료로 그 시험 실행):**
  - 현상(계획 담당이 무수정 원본에서 재현): `tests/test_all_profile_prompt_budget.py::test_current_profiles_worst_context_with_dynamic_deadline`의 프로필 한 건이 `slack` 문맥에서 합계 7771자로 한도 7600자를 넘는다. 그 프로필의 team-kit 안내문 구역(`team-kit.tools`, `team-kit.notion` 등)이 최근 운영 저장소 커밋들의 지시 보강으로 길어진 것으로 보인다(확인은 구현 담당이 `git log -p`로 한다).
  - 할 일: 넘친 원인 구역과 그 원본 위치를 찾아, **뜻을 바꾸지 않는 문장 다듬기만으로** 합계를 7600자 이하로 줄인다. 원본은 실행 중인 파일이다(운영 저장소 규칙).
  - 금지: 한도(7600)나 시험 기대값·입력 수정, skip·xfail, 규칙·금지 사항·도구 안내 항목의 삭제, 다른 프로필·다른 구역 변경, 직원의 행동이 달라지는 문구 변경. 다듬기만으로 안 되면 **멈추고** 어느 항목을 빼야 하는지 선택지와 함께 보고한다(무엇을 뺄지는 사용자 결정).
  - 보고: 바꾼 문장마다 전·후 원문과 글자 수, 그 시험의 전·후 결과(구역별 길이 포함).
- **TASK-05 반영(V-7 포함):** TASK-05a 뒤에 `.build/HEJO-IMESSAGE/team-kit-candidate/`의 두 파일을 실행 원본에 적용 → 운영 저장소 안내의 정식 방식으로 team-kit 전체 시험 → **실패 0건**이어야 한다(남으면 멈추고 보고) → 운영 저장소에서 `./sync` → `./airport-check` 통과 → `git commit --only`로 자기 경로만, TASK-05a와 TASK-05를 **별도 커밋**으로. `./sync`가 토큰 경고를 내면 커밋하지 않고 보고. `--rebaseline` 금지. 커밋 해시와 착수 시 운영 저장소 HEAD를 보고한다.
- **주의:** 운영 저장소에는 매일 자동 기록 커밋과 다른 작업의 변경이 들어온다. 자기 경로만 다루고, 겹치는 변경을 보면 멈추고 보고한다. 게이트웨이 재시작·`reload-plugins`는 하지 않는다(실행 중 동작은 다음 재시작 전까지 그대로이며, 양보 코드는 hejo 쪽이 적용되기 전에 실려도 기존 동작과 같다 — design 7절).
- **금지(공통):** hejo 제품 코드 변경, `install/hejo-release`, 앱 사본 교체, 운영 설정·비밀 파일 열기, 실제 아이메시지·Slack 발송, git push, spec·design·수락 명세 수정.
- **보고:** `impl-report.md`에 "보완 2" 절.
