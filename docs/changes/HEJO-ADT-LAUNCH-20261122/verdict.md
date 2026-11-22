## 검증 판정: HEJO-ADT-LAUNCH-20261122 / 직원 C가 ADT-EYE를 직접 켜서 CCTV 확인 (1차 검증, 2026-11-22)

1. **판정: 부분 완료**
   - 충족: REQ-AL-01은 대역(수준 2)으로 충족했다.
   - 미충족:
     - REQ-AL-02는 착수하지 못했다.
     - REQ-AL-03은 원인을 찾지 못해 생산 코드가 바뀌지 않았다.
     - 목적 AC-AL-08(직원 C가 스스로 켜서 판독 성공)은 증거가 없다. plan-review 1회차 PR-01에 따라 이것만으로 최대 부분 완료다.

2. **검증 조건**
   - 교차 모델: 계획·검증은 Opus 5.5, 구현은 Sonnet 5.5다. 같은 대화가 설계와 검증을 함께 맡았으므로 설계 적합성을 3번에서 따로 판정했다.
   - 검토한 코드 상태
     - 운영 저장소: worktree `.worktrees/adt-launch-20261122`, 브랜치 `adt-launch-20261122`, 커밋 `1d0f111a`(기준 `dba8f4fb`).
     - hejo: worktree `.worktrees/31ptpirh/role-workflow-13-fde6554d`, 브랜치 `role-workflow/13-fde6554d`, 커밋 `f234d0b`(기준 main `911d921`).
     - 확인 시점에 hejo main은 `56ddfcd`로 앞서 있다(FINDER-FOLDERS 9판 문서).

3. **설계 적합성(4.2)**
   - REQ-AL-01의 설계(가려지면 `focus.js focus`로 한 번 다시 올리고 다시 입력)는 실제 막힘을 풀지 못한다. [확인] 구현 담당의 실물 관찰(`evidence/task01-reraise-observation.md`)에서 Windows App이 맨 앞 앱인 상태로 `focus.js focus`와 `AXRaise`를 해도 hejo 창 둘이 세션 창 위에 남았다. 재시도는 막힌 이유를 남기는 데까지만 쓸모가 있고, 켜기 성공은 hejo 쪽 원인 제거에 달려 있다. **설계 결함 → 기획설계.**
   - REQ-AL-03의 설계 가정 두 가지가 모두 근거를 잃었다.
     - 가정 (1) ".normal로 내려도 앞 순서에 남는다": 시험용 창에서 재현되지 않았다.
     - AC-AL-06: 생산 코드를 고치지 않은 지금도 통과한다. 즉 실제 결함을 잡는 시험이 아니다.
     - **시험 설계 결함 → 기획설계.**
   - [확인] 검증자 관찰(2026-11-22, 읽기 전용 CGWindowList): Finder가 맨 앞이고 Windows App 창이 화면에 없는 바탕화면 공간에서도 hejo '연결'·'에이전트 연결'·'hejo 설정' 창(0층)이 화면에 있었다. 앞서 Windows App 세션 화면에서도 같은 창이 보였다.
   - [가정] 새 원인 후보: hejo 옵션·연결 창이 어느 화면 공간(Space)에서나 보인다. 실제 hejo는 `.accessory` 앱이고(`AppMain.swift:13`), 펫 패널만 `canJoinAllSpaces`를 명시한다(`PetController.swift:178`). 그런데도 옵션 창이 공간을 따라다닌다. 그래서 Windows App 세션 공간에 hejo 창이 함께 떠서 앞을 가리는 것으로 보인다.

4. **직접 확인한 것**
   - 운영 저장소 `cctv/tests` 전체: 게이트웨이 Python과 운영 규칙의 PYTHONPATH로 실행, exit 0, 570 passed(`/tmp/adt-verify/cctv.log`). 수준 2다.
   - hejo `bash app/scripts/build.sh`: exit 0. `app/.build/app-tests --finder-picture <Pet 리소스>`: exit 0이며 `AT-FF-64`·`AT-AL-06`·`APP_TEST_OK`가 찍혔다(`/tmp/adt-verify/app2.log`). 리소스 인자 없이 실행했을 때는 펫 이미지 오류로 exit 1이었고, 이는 실행 방법 문제다.
   - 코드 읽기
     - `click.js`: 검사 항목과 순서는 그대로이고 오류 문장에 앱 이름만 붙었다.
     - `screen.Session.input`: `SESSION_WINDOW_NOT_FRONT`만 1회 재시도한다. 두 번째 입력도 `screen.input`의 창 재확인과 `click.js` 검사를 다시 거친다. `refocus`는 `previous`를 덮지 않는다.
     - 비대상 오류인 `WINDOWS_APP_NOT_FRONT`는 문자열에 `SESSION_WINDOW_NOT_FRONT`가 들어 있지 않아 재시도되지 않는다.
     - 시험 대역은 osascript·screencapture만 대신하고 기대값은 handoff 숫자에서 왔다.
   - 보고에 없는 변경은 없다(`git show --stat` 5파일 = 보고 5파일).
   - 실물 수준 4: 미도달. AC-AL-07·08 미실행.

5. **지적**

   | 번호 | 위치 | 기준 | 근거 | 등급 | 보낼 곳 |
   |---|---|---|---|---|---|
   | V-1 | 설계 REQ-AL-01·AC-AL-08 | 목적, PR-01 | 실물에서 다시 올리기가 hejo 창을 치우지 못한다. 켜기 성공 증거가 없다 | 차단 | 기획설계 |
   | V-2 | 설계 REQ-AL-03·AC-AL-06 | 10-planning 5절(거짓 통과) | AC-AL-06이 수정 전 코드로도 통과해 결함을 관측하지 않는다. 원인 가설이 틀렸다 | 차단 | 기획설계 |
   | V-3 | TASK-02 | REQ-AL-02 | 운영 저장소 cctv `now.py`·`reference.py`·`settings.py`·`watch.py`의 다른 작업 미커밋 변경이 그대로라 착수 조건이 안 풀렸다(검증 시점 `git status`) | 차단 | 환경(다른 작업) |
   | V-4 | `screen.Session.input` | `watch.py` 주석 "Escape itself is never retried" | 가려진 Escape도 1회 재시도된다. 첫 시도는 보내지지 않은 것이라 실제 Escape는 최대 1번이며 위험은 낮다. 하지만 주석·README와 어긋난다 | 비차단 | 구현 |
   | V-5 | 운영 저장소 `./airport-check` | — | 작업 전부터 `assembly:hermes-soul-assemble` FAIL, 작업 전후 동일 | 기술 부채 | 기록만 |

6. **기획설계로 넘긴 것**: V-1, V-2. hejo 창이 Space를 따라다니는 원인의 진단 방법과 AC 재설계.

7. **미검증 범위와 남은 위험**
   - 새 hejo 빌드의 실물 창 동작은 미설치라 미확인이다.
   - click.js의 실제 `kCGWindowOwnerName` 값은 대역으로만 확인했다.
   - hejo 전체 `scripts/test.sh`는 미실행이다(변경이 시험 1파일뿐이라 영향 범위 시험만 돌림).

8. **원인 분류와 남은 조건**
   - V-1·V-2는 설계 오류(요구 불변)다. hejo 창이 다른 공간·다른 앱 위에 남는 진짜 원인을 실제 앱 조건에서 진단하고, 결함을 실패로 관측하는 AC로 다시 설계해야 한다. 실제 앱을 다시 띄우는 진단·설치에는 사장 승인이 필요하다.
   - V-3은 환경·외부 요인이다. 다른 작업이 cctv 파일을 커밋해야 풀린다.
   - 완료까지 남은 조건: hejo 원인 수정 + AC-AL-07 실물, TASK-02, TASK-04 배포(승인), AC-AL-08 성공.

9. **현재 명세 반영 요청**: 해당 없음(완료 아님).

---

## 검증 판정 2차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, TASK-03R 검토)

1. **판정: 부분 완료** (1차 판정 유지). 남은 조건은 8번에 적었다.

2. **검증 조건**
   - 교차 모델이다.
   - 검토한 코드
     - hejo: 브랜치 `role-workflow/13-fde6554d`, 커밋 `d01b4fe1959ace091a2d9c13b8f8da4e95c139ec`. merge 커밋 `e56dec8`이 main `56ddfcd`를 포함한다.
     - 운영 저장소: `1d0f111a`, 이번 회차에 바뀌지 않았다. 플러그인 수집 증거 "변경 없음"과 일치한다.

3. **설계 적합성(4.2)**
   - [확인] 3판 REQ-AL-03R의 원인 가설(창이 화면 공간을 따라온다)은 구현 담당 진단으로 기각됐다. `collectionBehavior 0`이고, 전체 화면 공간에서 `isOnActiveSpace=false`였다. 1차 검증 때 내 관찰("두 공간에 같은 창")은 같은 공간을 잘못 본 것으로 받아들인다.
   - [확인] 대신 별개의 결함이 확정·수정됐다. 활성화가 거절되거나 지연돼도 `OptionWindows.prepare`가 창을 펫+1(층 4)에 고정하던 문제다.
     - 수정 전 증거: `order=hejo@4,…,Windows App@0`.
     - 수정 후 증거: 층 4 없음.
     - 이 층 4 창은 `click.js`의 0층 검사에는 잡히지 않는다. 세션 창을 실제로 덮어 클릭을 가로챌 수 있는 구멍이었으므로 고친 것이 맞다.
   - [미확정] 원래 증상의 원인은 새 빌드에서 재현되지 않았다. 그 증상은 Windows App이 맨 앞 앱인데도 hejo 0층 창이 세션 창 위에 있던 것이다.
   - 따라서 켜기 성공의 판단은 실물 AC-AL-08과, TASK-01이 남기는 가린 앱 이름으로 넘긴다. 설계를 더 추측해 보정하지 않는다.
   - [확인] 지금 화면 상태(검증자 읽기, 설치본 hejo 재실행 뒤): 첫 0층 창이 Windows App 세션(1280×720)이다. hejo 0층 창은 없다.

4. **직접 확인한 것**
   - hejo `d01b4fe` `bash app/scripts/build.sh`: exit 0.
   - `app-tests --finder-picture <Pet>`: exit 0. AT-FF-50..54, AT-FF-64, AT-AL-06U, AT-AL-06, AT-FF-60..61이 통과하고 `APP_TEST_OK`가 찍혔다(`/tmp/adt-verify/app3.log`).
   - diff 확인
     - 생산 코드: `OptionWindows`에 `isActive` 훅 하나와 `prepare` 한 줄이 바뀌었다.
     - 시험: AT-AL-06U가 추가됐다. AT-FF-60·61·64와 AT-AL-06에는 `isActive={true}` 설정만 더해졌고 기대값은 바뀌지 않았다.
     - 보고된 변경과 실제 변경이 같다. 진단 코드는 남아 있지 않다(`git status` 깨끗함).
   - AT-AL-06U의 수정 전 실패는 구현 담당 기록으로만 확인했다. 기대값은 handoff 3판 REQ에서 왔다.
   - 운영 저장소: cctv 4파일의 다른 작업 미커밋이 `340b8274`(HEJO-SLACK-MOVE)로 커밋되어 git status가 깨끗하다. 운영 main은 `d3632cbe`다. **TASK-02 착수 조건이 풀렸다.**
   - `SecurityAgent` 프로세스(pid 71168)가 아직 떠 있다. hejo 전체 `test.sh`의 AT-HC-27 실패는 변경 전 코드도 똑같이 실패해 환경 탓으로 판단한다. 사용자가 그 창을 닫아야 다시 돌릴 수 있다.

5. **지적**

   | 번호 | 내용 | 등급 | 보낼 곳 | 상태 |
   |---|---|---|---|---|
   | V-1 | 켜기 성공(AC-AL-08) 증거 없음 | 차단 | — | 미해결. 배포(TASK-04) 뒤 실물로 판정 |
   | V-2 | AC-AL-06 거짓 통과 | 차단 | 기획설계 | 처리됨: AT-AL-06U는 수정 전 실패·수정 후 통과로 결함을 관측한다. 원래 증상 원인은 미확정으로 남는다 |
   | V-3 | TASK-02 미착수 | 차단 | 구현 | 착수 조건 풀림, 다음 회차 |
   | V-4 | Escape 재시도 주석 불일치 | 비차단 | 구현 | TASK-02에서 처리 |
   | V-6 | `prepare`가 활성화 직후 `isActive`가 아직 false인 정상 경우에도 창을 `.normal`로 연다. `applicationDidBecomeActive → updateLevels(true)`가 뒤에 올려 주는 것은 AT-AL-06U가 함수 단위로 보장한다. 실제 앱에서 REQ-FF-10(옵션 창이 대화 창 앞)이 유지되는지는 실물 확인이 없다 | 비차단 | 구현 | TASK-04 실물 확인 항목에 추가 |
   | V-5 | airport-check 기존 FAIL | 기술 부채 | — | 기록만 |

6. **기획설계로 넘긴 것**: 없음(V-2 처리됨).

7. **미검증 범위**
   - hejo 전체 `test.sh`: SecurityAgent 창 때문에 막혔다.
   - AC-AL-06R의 수정 후 유효 측정.
   - AC-AL-07, AC-AL-08.

8. **원인 분류와 남은 조건**
   - TASK-02: 환경 요인이 풀렸으니 이제 구현한다.
   - SecurityAgent: 환경 요인이다. 사용자가 닫아야 한다.
   - 남은 조건
     - TASK-02 완료와 검증.
     - hejo main 최신(`d58248c` 이상) merge 뒤 전체 `test.sh` 통과.
     - TASK-04 배포(사장 승인) 뒤 AC-AL-08 성공과 V-6 실물 확인.

---

## 검증 판정 3차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, TASK-02 검토)

1. **판정: 부분 완료.** 코드와 자동 시험 범위(TASK-01·02·03R)는 모두 충족했다. 남은 것은 배포(TASK-04)와 실물 AC-AL-08뿐이며, 둘 다 사장 승인이 필요하다.

2. **검증 조건**: 교차 모델이다. 검토한 코드는 아래와 같다.
   - 운영 저장소: 브랜치 `adt-launch-20261122`, 커밋 `06c0ed194e258aadf78663827a50ab10a65b28c2`. merge `16d39cd4`가 main `5348909a`를 포함한다.
   - hejo: 브랜치 `role-workflow/13-fde6554d`, 커밋 `14f1946381d3526ffe970fe847e199110d380d47`. merge가 main `d58248c`를 포함한다.

3. **설계 적합성(4.2)**: REQ-AL-02를 충족한다.
   - `fail` 알림에서 "직접 눌러 주세요"가 빠졌다.
   - `_focus_alert`는 실제 오류(`{error}`)를 알리고 "가져와 주세요"가 빠졌다.
   - `now.py` 도구 설명에 보고 지시가 들어갔다.
   - 범위 밖으로 정한 화면 공유 끊김 알림과 재연결 제안은 그대로 두었다.
   - V-4 Escape 주석도 고쳤다.

4. **직접 확인한 것**
   - TASK-02 diff(`16d39cd4..06c0ed19`): `watch.py`, `now.py`, `README.md`, 새 시험 `test_no_ask_for_help.py`, `test_channel_messages.py`가 바뀌었고 보고와 일치한다.
     - `test_channel_messages.py`의 삭제된 단정은 옛 부탁 문장("직접 눌러 주세요")을 요구하던 것이다. 승인된 REQ-AL-02로 계약이 바뀐 결과라 수락한다. 나머지 단정(번호·멈춘 이유)은 남았다.
   - cctv pytest(`06c0ed19`, 게이트웨이 Python): exit 1, 7 failed / 570 passed(`/tmp/adt-verify/cctv3.log`).
     - 실패 7건은 `test_channel_index` invalid_vault_index 6건과 `test_startup` missing_optional_icon 1건이다.
     - 검증자가 임시 worktree에서 main `5348909a`를 직접 돌려 같은 7건 실패를 확인했다. 확인 뒤 worktree는 지웠다. 이 작업과 무관한 기존 실패다.
   - AT-AL-04·04b(`test_no_ask_for_help.py` 7개)와 AT-AL-09는 위 실행에 포함되어 통과했다. 기대값은 handoff 문구에서 왔다. mutation 3건은 구현 담당 기록으로 확인했다.
   - hejo `bash app/scripts/test.sh`(`14f1946`, HEJO_PYTHON=게이트웨이 Python): exit 0(`/tmp/adt-verify/hejo-full.log`).
   - 운영 실행본(`~/.hermes/plugin-store/team-kit/.../cctv`)의 `watch.py`·`now.py`·`screen.py`·`click.js`는 운영 main과 같다. 이 작업의 변경은 아직 운영에 없다.
   - 운영 저장소 주 작업 폴더의 미커밋 변경: 0건.
   - 기준 브랜치가 다시 앞섰다. hejo main은 `648ea17`, 운영 main은 `4a462420`이다. 푸시 전에 merge가 필요하다.

5. **지적**

   | 번호 | 상태 |
   |---|---|
   | V-1(AC-AL-08 실물 성공 없음) | 미해결. TASK-04 뒤 판정 |
   | V-3(TASK-02) | 해결 |
   | V-4(Escape 주석) | 해결 |
   | V-6(REQ-FF-10 실물) | 미해결. hejo 새 빌드를 설치한 뒤 확인 |
   | V-5(airport-check) | 해소됨. 이번 실행은 exit 0이었다(구현 보고) |

6. **남은 조건**
   - 두 브랜치에 기준 브랜치 최신을 merge하고 다시 시험한다.
   - 사장 승인 뒤 TASK-04를 한다: 운영 저장소 main 반영, 운영 실행본 반영, 게이트웨이 재시작, 확인.
   - AC-AL-08: 사장이 hejo에서 "지금 낙화 하냐"고 물어 직원 C가 켜기·판독에 성공하는지 본다.
   - 그 뒤 hejo 변경은 hejo 정식 배포 경로로 설치하고 V-6을 확인한다.

---

## 검증 판정 4차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, TASK-04 검토)

1. **판정: 부분 완료.** TASK-04 배포는 확인됐다. 목적 AC-AL-08(실물 켜기·판독 성공)의 증거가 아직 없어 PR-01 기준에 따라 완료가 아니다.

2. **검증 조건**: 교차 모델.
   - 운영 저장소 주 작업 폴더 main: `a566566737fde11e95cbc41eba0ba3bfe13a4d84`.
   - hejo 브랜치 `role-workflow/13-fde6554d`: `afd4837ff918fac1306481a38fa856b4ecabc889`.

3. **설계 적합성**: 바뀐 점 없음. 배포가 handoff 9절 TASK-04 착수 조건(보관, 반영, 재시작 1회, 시작 시각과 로그 확인)대로 진행됐다.

4. **직접 확인한 것**
   - 운영 저장소 HEAD는 `a566566`이고 미커밋 0이다. `4a462420`(원격 main)의 후손이라 빨리 감기로 올릴 수 있다.
   - `a566566`과 `06c0ed19`의 cctv 차이는 merge로 들어온 main 변경뿐이다.
   - 운영 실행본 cctv ↔ 운영 main cctv: `diff -rq`(캐시 제외) 차이 없음.
   - 게이트웨이 pid 83889의 시작 시각은 2026-11-22 17:57:23이다. 운영 실행본 `watch.py` 수정 시각 17:56:24보다 뒤이므로 새 코드가 실린 프로세스다.
   - 플랫폼 재연결과 오류 로그는 구현 담당 기록으로 확인했다. 검증자는 비밀 파일이 아닌 로그도 이번에는 다시 열지 않았다.
   - hejo `afd4837`은 로컬 main `648ea17`을 포함하고 미커밋 0이다. test.sh exit 0은 구현 담당 기록이다(코드 변화가 merge뿐이라 3차 검증자 실행 결과를 이어서 인정).
   - [확인] hejo 원격 `main`이 `f397bdb`로 앞서 있고 `afd4837`에 포함되지 않는다. 푸시 전 merge가 필요하다.

5. **지적**

   | 지적 | 상태 |
   |---|---|
   | V-1 | 미해결. 사장 실물 질문 대기 |
   | V-6 | 미해결. hejo 정식 배포 뒤 확인 |
   | 그 밖 | 해결 |

6. **남은 조건**
   - AC-AL-08
     - 조건: 원격 화면이 Windows 바탕화면(ADT-EYE 꺼짐)이다.
     - 사장이 hejo에서 직원 C에게 "지금 낙화 하냐"고 묻는다.
     - 그 회차 `last_ask`에 `relived: true`, `relive_result: "ok"`, `ok: true`가 있고, 켜기 뒤 캡처가 ADT-EYE 화면이어야 한다.
     - 실패하면 `relive_result`의 이유(가린 앱 이름 포함)로 원인을 분류한다.
   - 푸시 전에 hejo 브랜치에 원격 main 최신을 merge하고 다시 시험한다.
   - 운영 저장소 `a566566`과 hejo 브랜치의 푸시 승인.

---

## 검증 판정 5차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, 실물 확인)

1. **판정: 완료(코드·운영 반영·실물 켜기).** 남은 것은 hejo 브랜치의 원격 main merge와 두 저장소 푸시 승인이다.

2. **검증 조건**: 교차 모델.
   - 운영 저장소 main: `a566566737fde11e95cbc41eba0ba3bfe13a4d84`.
   - hejo 브랜치: `afd4837ff918fac1306481a38fa856b4ecabc889`.

3. **실물 증거 (수준 4)**
   - [확인] 직원 C 상태 파일 `relive`: count 4, `last_result: "ok"`, `last_reason: "빈 화면"`. 캡처 기록은 아래와 같다.
     - 17:30:38 예약 감시가 바탕화면에서 ADT-EYE 아이콘을 눌렀다(`173038-launch1/2.png`). 켜기 뒤 캡처에 ADT-EYE 3.0이 로딩 중이다.
     - 17:45:12 장비 목록을 펼쳤다(`174512-expand1.png`).
     - 18:00:03 지정 채널을 다시 틀었다(`180003-relive.png`). 영상 시각 2026-11-22 18:00:26, LIVE.
     - 사장이 앱을 열거나 누르지 않았다.
   - [확인] 18:06:43 사장 질문(`cctv_now`) 결과: `reason: 원격 연결이 끊겨 있어요`, `relived: false`, `capture: null`. 원격 세션 창이 없는 상태(`WINDOW_MISSING`)라 켜기 대상이 아니었다.
     - 재연결은 사장 승인 계약(3절 유지 계약)이라 범위 밖이다.
     - 직원 C 답에 켜기·누르기 부탁은 없었다. 재연결을 할 수 없다는 사실만 알렸다.
   - 차이와 사장 결정
     - AC-AL-08 문구는 "배포 뒤, 사장 질문 경로"다. 실제 켜기 성공은 배포(17:56) 전 예약 감시 경로에서 나왔다. 켜기 흐름(`_relive`의 launch)은 두 경로가 같다.
     - 당시 가림 창이 없어 재시도가 필요 없었다. 그래서 TASK-01 재시도의 실물 효과는 아직 관찰되지 않았다.
     - **사장 결정(2026-11-22 18:1x): 이 증거로 켜기 성공을 인정하고 마무리한다.**

4. **지적 처분**
   - V-1: 사장 결정으로 해결.
   - V-6(REQ-FF-10 실물): hejo 정식 배포 뒤 확인할 남은 위험으로 기록한다. 기능 차단은 아니다.
   - 그 밖은 해결.

5. **남은 위험**
   - 다른 앱 창이 가리는 상황의 재시도 실물 효과는 미관찰이다. 실패하면 가린 앱 이름이 기록된다.
   - hejo 옵션 창 높이(V-6)는 정식 배포 뒤 실물 확인이 필요하다.
   - 원격 세션 끊김의 원인(18:00~18:06)은 이 작업 범위 밖이다.

6. **푸시 전 조건**
   - hejo 브랜치에 로컬 main(`648ea17`)과 원격 main(`f397bdb`)을 모두 merge하고 전체 시험을 다시 돌린다. 지금 `afd4837`은 `f397bdb`를 포함하지 않는다.
   - 운영 저장소 `a566566`은 원격 main `4a462420`의 후손이라 그대로 푸시할 수 있다.

7. **현재 명세 반영 요청**
   - cctv README에는 이미 반영돼 있다. 재시도 한 종류·한 번, 실패 알림이 사장에게 부탁하지 않는다는 계약이다.
   - hejo `OptionWindows`의 "실제 활성일 때만 펫+1" 규칙은 hejo 현재 명세의 옵션 창 절(REQ-FF-10)에 반영할 후보다.

---

## 검증 판정 6차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, 반영 경로)

1. **판정**: 완료 판정(5차)을 유지한다. 남은 것은 반영 절차뿐이다.

2. **hejo**
   - [확인] `github/main`(`f397bdb`, hejo 0.2.3)은 공개 릴리스 전용 이력이다. 로컬 개발 `main`과 공통 조상이 없다. 로컬 `public` 브랜치와 같은 커밋이고, 로컬 `main`에는 upstream이 없다.
   - 구현 담당이 `--allow-unrelated-histories`를 쓰지 않고 멈춘 것은 옳다.
   - **사장 결정(2026-11-22): hejo 수정은 로컬 main에만 반영한다.** GitHub에는 다음 공개 릴리스(기존 배포 절차) 때 함께 나간다. 따라서 이 작업의 hejo 푸시 대상은 없다.
   - `c8009e0`: main `94d03ba`를 merge했다. 앱 코드 변동은 없다(문서만). test.sh exit 0과 scan exit 0은 구현 담당 기록이다.
   - 확인 시점에 로컬 main이 `6c68e29`로 앞서 있다. `git merge-tree`로 충돌이 없음을 확인했다. 브랜치 차이는 `OptionWindows.swift`와 `OptionWindowTests.swift`뿐이다.
   - 로컬 main checkout에는 다른 작업의 미커밋 변경(`HEJO-FINDER-FOLDERS` `impl-report.md`)이 있다.

3. **운영 저장소**
   - 푸시 대상: `origin` `main` `a566566737fde11e95cbc41eba0ba3bfe13a4d84`.
   - `4a462420..a566566`은 이 작업 커밋 4개뿐이다(`1d0f111a`, `16d39cd4`, `06c0ed19`, `a5665667`).
   - 그 뒤 운영 main에 생긴 `b95e31a2`(connections manifest)는 다른 작업 커밋이며 이 푸시 대상에 들지 않는다.

4. **남은 절차**
   - hejo 브랜치에 최신 로컬 main을 merge하고 전체 시험을 다시 돌린다.
   - 그 뒤 로컬 main을 그 커밋으로 빨리 감기(ff-only)한다.
   - 이 작업 문서를 자기 경로만 커밋한다.
   - 운영 저장소 푸시 승인.

---

## 검증 판정 7차: HEJO-ADT-LAUNCH-20261122 (2026-11-22, 최종 반영)

1. **판정: 완료.** 교차 모델 검증이다.
   - 코드, 운영 반영, 실물 켜기(사장 결정으로 인정)를 모두 확인했다.
   - hejo 로컬 main 반영까지 끝났다.
   - 남은 것은 운영 저장소 푸시 승인뿐이다.

2. **hejo**
   - 브랜치 `8a1399f2094d8d00f41499d5e8597a8de0798139`: 구현 담당 `test.sh` exit 0(`/tmp/adt-launch/t6-app-test-full.log`), scan exit 0. 6c68e29를 포함한다.
   - 로컬 main이 그 사이 `3bb1489`로 앞섰다. `6c68e29..3bb1489`는 HEJO-FINDER-FOLDERS 문서 3파일뿐이고 앱 코드 변경은 없다.
   - 빨리 감기가 불가능해 계획 담당 checkout에서 `git merge --no-ff`로 반영했다. merge 커밋은 `09d9c9cd4937803ee03b980992950ad4a231328a`이고 충돌은 없었다.
   - 반영 결과의 `app/`는 시험한 `8a1399f`와 차이가 없다(`git diff 8a1399f HEAD -- app` 비어 있음). 그래서 시험 결과를 그대로 인정한다.
   - GitHub hejo는 사장 결정대로 다음 공개 릴리스 때 반영한다. 이 작업의 hejo 푸시 대상은 없다.

3. **운영 저장소**
   - 푸시 대상: `origin` `main` `a566566737fde11e95cbc41eba0ba3bfe13a4d84`. 원격 main `4a462420`의 후손이고, 이 작업 커밋 4개만 더해진다.
   - 그 뒤 운영 main에 생긴 `b95e31a2`, `65342f44`, `f0844bdc`와 작업 트리 변경(OPS-REPO-RENAME 등)은 다른 작업이다. 이 푸시에 포함되지 않는다.

4. **남은 위험**(작업 범위 밖이거나 후속)
   - 가림 재시도의 실물 효과는 아직 관찰하지 못했다.
   - V-6: hejo 공개 릴리스 뒤 옵션 창 높이를 실물로 확인해야 한다.
   - 원격 끊김 때 재연결 제안(`cctv_now`)은 사장이 제안한 새 작업 후보다.

5. **현재 명세 반영**
   - cctv README에 반영돼 있다.
   - hejo 옵션 창 규칙은 HEJO-FINDER-FOLDERS 명세(REQ-FF-10) 담당 작업에 알릴 후보다.
