# HEJO-UI-CLEAN 구현 인계

## TASK-01 · 착수 전 보류(2절 보고: R-UC-I1)

### 받은 지시와 현재 코드

- 받은 설계: handoff.md TASK-01~03, spec·design·수락 시험1판, 시안 final-4. 위험도 일반, 필요한 증거 수준2 + 사진. 순서대로 구현하고 각 TASK마다 전체 시험 종료0 뒤 자기 경로만 커밋한다는 지시다.
- 기존 구현 브랜치 `role-workflow/17-96051e66` 상태가 깨끗하고 HEAD가 앞선 작업 커밋 e36c8a7임을 확인했다. 지정 기준 `aa65bfb5769ed1dc041576307734289f150fe914`를 merge했다. 종료0, 충돌 없는 fast-forward. 이 명령은 main을 구현 브랜치로 받는 작업이며 main으로 구현을 병합한 것이 아니다.
- 현재 HEAD는 위 지정 기준이며 worktree가 깨끗하다. 제품 코드·시험 변경·새 커밋 없음. 시안은 직접 열어 확인했고, 실제 소스·기존 수락 시험 코드를 대조했다.
- 구현자 판단: **보류**. 아래 기존 단언은 새 요구와 맞지 않지만 design 4절의 허용된 시험 이관 목록에 없다. 사용자가 "그 밖에 설계와 코드가 안 맞으면 멈추고 보고"라고 명시했으므로, 구현 뒤 임의로 기대값을 바꾸거나 옛 경로를 보존하는 우회를 하지 않았다.

### R-UC-I1: 카드 폭·그리기·문장 시험의 이관 허용 목록 누락

| 실제 기존 단언 | 새 요구와 충돌 | 계획 담당이 정할 내용 |
|---|---|---|
| `app/Tests/DrawerInlineTests.swift:213`, AT-DI-12, 칸 일부 표시 때 실제 cardViews.first.frame.width == 262 | REQ-UC-03 AC-01의 칸290·좌우 여백6이면 카드 폭은278이다. 기존262는 이전 좌우14를 고정한다. 이관 허용 목록 design.md:59에는 AT-DI-12가 없다 | 실제 카드 폭278을 독립 상수로 단언하도록 이관 허용을 명시하고, 칸 폭 보간·겹치지 않음·잘림 계약은 유지 |
| 같은 파일 `:187~201`, AT-DI-22, 옛 배지 영역(y10~26)에 빨강, 세 카드 테두리 동일(`:201`), 선택 채움 옛 비교 | 새 카드52pt·상태 아래 줄·사진26·급함 세로줄·선택 강조색 테두리(REQ-UC-03 AC-04·06)와 관측 위치/같은 테두리 기대가 다름. AT-DI-22는 목록에 없음 | AT-UC-14·16으로 대체할 단언 범위를 지정. 색·선택·급함 보호는 새 독립 픽셀 시험으로 유지 |
| `app/Tests/TodoDrawerTests.swift:252`, AT-DC-21, Card.badge == D+1/D-DAY/D-4 + 출처 문자열 | design 4절은 Card.badge/time을 status/statusUrgent/trailing으로 교체한다. 새 문장(마감 N일 지남/오늘 마감/마감 N일 남음·출처·연결 없음)과 기존 완전 일치 문장이 다름. 목록에는 AT-TD-20·22만 있고 AT-DC-21은 없음 | 출처 종류·연결 없음·날짜 계약을 유지한 새 status 문장 기대와 이관 허용 범위 |
| 같은 파일 `:259~260`, AT-DC-21b, 모든 출처 종류에서 badge == D-DAY + 출처 | 같은 API 제거·문장 변경 영향. 알려진7종 출처 및 알 수 없는 종류의 보호는 보존해야 함 | AT-UC-13에 모든 출처 매핑을 유지하거나 기존 시험의 문장 부분만 이관하도록 허용 |

- [확인] design.md:53의 `Card.badge/time` 교체와 `:59`의 시험 이관 목록을 대조했다. 속성 교체의 호출자 수정과 기존 단언의 의미 변경을 구분해야 한다. 특히 AT-DI-12의 숫자262는 단순 속성 이름 변경으로 보존할 수 없다.
- [권고] 위 누락을 design 4절·수락 시험 이관 허용 목록에 추가하고, TASK-01에서 허용할 파일:줄·전후 기대를 명시해 보완 인계한다. 앞서 계획된 UC 수치(52/6/7/26/6/10/3)와 기존 배치·마감 닫기 기능 계약은 유지하는 방안이다.
- 새 카드 폭을262로 남기거나, API 별칭 badge/time을 임시로 유지하거나, 기존 시험을 skip하거나, 픽셀 표본·오차를 임의 바꾸지 않았다. 설계·수락 시험 문서는 수정하지 않았다.

### 실행한 확인과 미실행

로그 위치는 구현 worktree의 `.build/ui-clean-evidence/`다.

| 명령·관측 | 실제 결과 | 증거 |
|---|---|---|
| `git status --short`, `git rev-parse HEAD main` | 최초 상태 깨끗함, 구현 e36c8a7·지정 main aa65bfb 확인 | 도구 출력 |
| `git merge aa65bfb5769ed1dc041576307734289f150fe914` | 종료0, 충돌 없는 fast-forward | Git 이력·현재 HEAD |
| `git diff --exit-code HEAD -- app/` | 종료0, 기준 대비 앱 변경 없음 | `preflight.json` |
| 기존 단언 `rg` 및 파일:줄 대조 | 종료0, 위 네 누락 단언 확인 | `preflight.json`, 위 표 |
| 분홍 색·아래 화살표 정적 검색 | 종료0, 아래 조사 결과 | `preflight.json` |

전체 `HEJO_PYTHON=... bash app/scripts/test.sh`, 빌드·새 수락 시험·scan_private는 **미실행**이다. 제품 코드를 바꾸기 전에 허용 범위 충돌로 중단했으므로 앞선 TASK-02 시험 결과를 이번 작업의 완료 증거로 재사용하지 않는다. 도달한 것은 소스·계약 조사이며 새 TASK의 증거 수준2는 아직 없다. 새 앱 사진도 미생성이다.

## TASK-02·TASK-03 · 미착수

TASK-01 전체 시험·커밋이 선행 조건이므로 제목 알약·중복 정리 제품 구현은 시작하지 않았다. TASK별 커밋·시험 순서를 바꾸지 않았다.

### 요청된 미확인 두 건의 정적 조사(예비 결과)

- **분홍 표식: 주인 미확정.** 앱 소스의 pink/systemPink/magenta 검색에서는 사용자 말풍선 색 선택(ChatStyle.swift)과 연결 아이콘 색(ConnectionsWindow.swift)만 나왔다. DraftTextView의 커스텀 입력/붙여넣기 경로와 PetView의 커서 그리기에서도 해당 분홍 표식을 그리는 지점을 확정하지 못했다. 검색0건만으로 "hejo 아님"을 단정하지 않는다. 실제 재현·뷰 계층/레이어 관측이 남았고 임의 제거는 하지 않았다.
- **아래 가운데 둥근 ⌄ 단추: 주인 미확정.** hejo에는 PetView.collapseButton(`PetView.swift:87`, 생성·배치 `:250`, `:338`, controller action `PetController.swift:190`)이 있으나 문자열은 "펫으로 접기"이고 `PetView.swift:203`에서 숨김 처리한다. `NativeThreadCard.StackButton`의 chevron.down(`NativeThreadCard.swift:555~558`)은 접힌 답글 더미 안 그림이며 전역 창 아래 둥근 단추와 같다고 확정할 근거가 없다. 이 후보들을 실제 화면의 단추와 대조해야 한다. 이동·삭제하지 않았다.
- 두 조사는 AT-UC-35 완료 증거가 아니라 예비 정적 조사다. TASK-03에서 실제 주인과 조치를 확정해 보고해야 한다.

## 다음 인계와 릴리즈 총괄 보고

- 계획 담당이 R-UC-I1의 시험 이관 범위를 보완하고 새 기준을 지정하면, 현재 깨끗한 구현 브랜치에서 TASK-01 →02 →03 순서로 이어간다. 각 TASK 전체 시험 종료0 뒤 자기 경로만 커밋하고 이 보고서에 결과를 추가한다.
- 릴리즈 총괄에 전달할 실제 상태: 브랜치 `role-workflow/17-96051e66`, 기준 HEAD `aa65bfb5769ed1dc041576307734289f150fe914`, **새 구현/릴리즈 후보 커밋 없음**, 로그 `.build/ui-clean-evidence/preflight.json`, 차단 R-UC-I1. 검증 완료·푸시·설치·운영 반영·공유 게이트웨이 재시작 없음. 기준 해시를 완료 후보 해시로 오인하면 안 된다.
- 릴리즈는 사용자가 지정한18번 총괄 대화에서 조율한다. 이 구현 대화는 별도 통합 릴리즈를 하지 않으며, 보고 전달은 호스트 인계로 남긴다. main으로의 병합·설치·버전 올림·공개·원격 쓰기는 하지 않았다.


## TASK-01 · 2판 재개 조사 보류(2절 보고: R-UC-I2)

- 받은 기준: handoff 2판 8항, spec·design·수락 시험 2판, verdict 1회. 지정 main `3587ff23f9cb742bc09d5cc4d531f65ee764224a`를 깨끗한 구현 브랜치에 merge했다(종료0, 충돌 없는 fast-forward). 제품·시험 변경 없음, 새 구현 커밋 없음. 현재 HEAD는 이 기준이다.
- 1판 보류 R-UC-I1의 누락이 4.1 표에 반영된 것은 확인했다. 다만 아래 추가 누락/기대 충돌 때문에 사용자 지시 “표에 없는 단언이 새 요구와 부딪히면 멈추고 보고”와 구현 규칙 2절에 따라 착수 전에 다시 보류한다.

### 확인한 충돌과 권고

| 구분 | 실제 근거 | 충돌 및 권고 |
|---|---|---|
| 이관 목록 누락 | `app/Tests/DrawerHeaderTests.swift:104` AT-DI-39의 `track.frame.width==262` | spec UC-02 AC-01·AT-UC-10 토글 x14~244면 폭230. design 4.1에는 AT-DI-35·37만 있고 AT-DI-39가 없다. 이 단언의 숫자만262→230 이관을 명시할 것을 권고한다. drawer 폭145·visibleRect 잘림·masksToBounds 조건은 그대로 유지한다. |
| 이관 표의 기대 문장과 명세 충돌 | `TodoDrawerTests.swift:34~37,42` AT-TD-22, `:229,252` AT-DC-21, `:255~260` AT-DC-21b | 해당 마감 입력들은 링크·notice가 없으므로 `linked==false`다. AT-DC-22(`:263`)도 미리알림 마감이 연결 없음임을 직접 단언한다. spec UC-03 AC-02·AT-UC-13은 연결 없는 카드의 **status 끝에** ` · 연결된 대화 없음`을 붙이라고 하지만, design 4.1의 위 세 이관 행은 그 접미사 없는 완전 일치 문장을 지정했다. AT-DC-21b의 모든 출처도 링크가 없다. 명세·새 시험의 접미사 계약에 맞게 이관 표 완전 일치 기대에 접미사를 더할 것을 권고한다. 출처 매핑·linked·날짜·순서 계약은 유지한다. |

추가로 AT-DI-22의 기존 준비 코드(`DrawerInlineTests.swift:183`)는 첫 카드를 선택한 채 세 카드 테두리를 같다고 비교(`:201`)한다. 새 요구는 선택 테두리 강조색이며 AT-UC-14는 **평소** 테두리를 비교한다. 4.1 표가 평소 테두리 비교를 유지하도록 적은 취지에 맞게, 테두리 동등 비교를 `selected:nil`에서 하고 선택 검사는 AT-UC-16으로 분리하도록 준비 상태 변경까지 명시하면 해석 여지가 없다. 현재 시험 입력/단언은 수정하지 않았다.

### 실제 확인·미실행

- `git merge 3587ff23f9cb742bc09d5cc4d531f65ee764224a`: 종료0, fast-forward. 최신 main HEAD 전체를 임의로 병합하지 않고 지정 커밋만 받았다.
- `git rev-parse HEAD`, `git status --porcelain`, `git diff --exit-code HEAD -- app/`: 각각 종료0. HEAD는 지정 기준, worktree 깨끗함, 앱 변경 없음. 로그 `.build/ui-clean-evidence/resume-2-preflight.json`.
- 실제 단언 및 2판 이관 표·명세 파일:줄 대조: 종료0. 같은 로그에 핵심 검색 결과 저장.
- 전체 앱 시험·scan_private·빌드·새 화면 사진: **미실행**. 이번 단계에서 제품·시험 파일은 바꾸지 않았으며 증거 수준2에 도달하지 않았다.
- TASK-02·03: 선행 TASK-01 미완료로 미착수. 분홍 표식·접기 단추 실제 화면/뷰 계층 관측은 TASK-03에 남았다. 이전의 정적 조사만으로 주인을 확정하지 않는다.
- 보고서만 canonical 작업 문서에 이 절을 추가했다. 제품 변경을 main에 병합·설치·공개·푸시·운영 반영하거나 공유 서비스를 재시작하지 않았다.

### 다음 인계

계획 담당은 R-UC-I2 두 항목을 보완한 뒤 지정 기준으로 재인계한다. 그 뒤 TASK-01→02→03 순서, TASK별 전체 앱 시험·개인값 검사·diff 검사 통과 후 자기 경로 커밋 조건은 그대로다. 릴리즈 총괄에 전달할 상태는 기준 HEAD `3587ff23f9cb742bc09d5cc4d531f65ee764224a`, 새 구현/릴리즈 후보 없음, 차단 R-UC-I2, 검증 미실행이다. 전달은 호스트가 담당한다.


## TASK-01 · 3판 재개: 부분 구현 / 보류(2절 보고 R-UC-I3)

### 받은 설계·현재 상태

- 기준 `054d3924b002f7bd6caa12c4f6f7ad63ffd5f969`를 구현 브랜치에 merge했다. 종료0, 충돌 없는 fast-forward. handoff 8항·design 3판 4.1·수락 시험3판·verdict2회를 확인했다.
- 위험도 일반, 필요한 증거 수준2 + 어둡게·밝게 사진. **현재는 부분 구현·자체 시험 실패로 보류**다. 기준 위 11파일 미커밋 변경이며 새 구현 커밋 없음. 현재 변경은 `.build/ui-clean-evidence/task-01-candidate.patch`로 보존했다. stash를 다시 적용하거나 변경을 폐기하지 않았다.
- TASK-02·03은 미착수다. main으로 구현 병합·설치·공개·푸시·운영 반영·공유 서비스 재시작은 하지 않았다.

### 더한 것·뺀 것·책임

- `TodoDrawerModel.swift`: badge/time을 status/statusUrgent/trailing으로 교체. 상태 문장·출처·연결 없음 접미사와 상대 시각·마감일 시각을 모델에서 생성. 필터·개수·정렬·urgent·마감 연결 판단은 유지했다.
- `TodoDrawerView.swift`: 제목 보기·두 번째 띠·묶음 제목 제거, 44pt 토글+✕ 고정 머리, 0개 글자 흐림, 52pt 사진 카드·묶음 사이 선·추적 영역 올림/선택 색·NSResponder 키보드 이동을 구현했다. 카드 사진은 기존 ProfileAvatar/직원 avatar 경로이며 26pt·모서리7. 되돌리기 바닥 줄·메뉴 경로는 유지했다. 키보드 선택은 기존 ConversationView 선택 원본으로 보내며 Enter는 클릭 동작, 화살표만으로 외부 URL을 열지 않는다.
- `SidebarMotion.swift`: 공용 카드 색과 AttentionRail(색·폭3·안쪽6·위아래10)을 두고 SidebarBlank의 검정 덮개만 제거했다. 기존 너비 전환 동작은 남겼다.
- `NativeThreadCard.swift`·`ConversationView.swift`·`ChatStyle.swift`: 채팅 상태 줄에 공용 기하 값을 적용하고 질문 급함 색도 같은 원본을 사용, 옛 statusWidth 상수 제거. 칸 선택 강조는 선택 동안 유지하며 알림 카드의 1.5초는 유지. 칸 닫힘 때 선택 강조 해제. 열 바탕은 아래 끝까지 그린다. 답글/새 글 토글·얼굴 줄은 수정하지 않았다.
- `ConversationChrome.swift`: 기존 ComposerButton 그리기에 기본1인 글자 알파를 추가해 0개 필터만0.4로 그린다. 공용 토글 모양은 그대로다.
- `app/Tests/UICleanDrawerTests.swift`: 모델 문장과 실제 ConversationView/PetController 조립으로 AT-UC-10~19를 코드화했다. 임시 LocalStore·가짜 직원·1440×900 화면·실제 테마 경로를 쓴다. 화면 사진은 요청한 저장소 루트 증거 폴더에 쓴다. 기존 `DrawerInlineTests`가 새 시험을 호출한다.
- 설계와 달리 승인받아 바꾼 사항 없음. 새 저장 값·통신 필드·두 번째 상태 원본 없음. 의미 변경 작업이며 기존 계약의 이관은 아래 목록뿐이다. 아직 전체 시험을 통과하지 않아 최종 구현 적합성을 주장하지 않는다.

### 기존 시험 이관 내역(design 4.1)

줄은 기준 커밋의 번호다. 줄이 밀린 현재 위치는 같은 ID/단언 문자열로 찾는다.

| 파일:기준 줄 / ID | 전 → 후 | 유지한 뜻·근거 |
|---|---|---|
| `TodoDrawerTests.swift:42` AT-TD-22 | D+1/D-DAY/D-4, 오늘18시까지·11월24일까지 → 마감1일지남/오늘마감/마감4일남음 + 연결 없음, 18:00·11/24 | 날짜·정렬·시각의 뜻 유지, 표의 명시 기대 |
| 같은 파일 `:73` AT-TD-25, `:295` AT-DC-23 | 1.51초 뒤 강조nil → 원래 질문/마감 messageID 유지 | 칸 선택 동안 유지, 알림 AT-TD-39 단언 불변 |
| 같은 파일 `:252` AT-DC-21 | badge의 D+1/D-DAY/D-4 → status의 마감 문장·출처, 연결 없는 미리알림에는 접미사 | 출처·연결·날짜 계약 유지 |
| 같은 파일 `:259~260` AT-DC-21b | badge D-DAY+출처 → status 오늘마감+출처+연결없음 | 원래 7종 입력/매핑과 완전 일치 비교 유지 |
| `DrawerInlineTests.swift:156` 준비 | badge/time 생성 인자 → status/statusUrgent/trailing | 4.1 준비 코드 기계적 교체 허용 |
| 같은 파일 `:183~201` AT-DI-22 | 선택된 첫 카드 → selected:nil; 옛 빨강 배지·선택 채움 단언 → AT-UC-14/16; 테두리 y45 → y26 | 평소 세 종류 테두리 동등 비교는 유지. y26=새 높이52/2(파생 수치). 새 선택/급함 픽셀 시험으로 보호 |
| 같은 파일 `:213` AT-DI-12 | 카드 폭262 →278 | 290−6×2=278. 나머지 잘림·배치 조건 불변 |
| `DrawerHeaderTests.swift:32,36,53~54` AT-DI-35 | 제목 찾기·기록 제거, 닫기 문자열✕; 토글 중심66→22, 스크롤 시작88→44, 토글 maxX276→244 | 제목 띠 제거, 한 줄 머리. 토글 폭=244−14=230 |
| 같은 파일 `:55~63` AT-DI-35 | y43.5·87.5 두 선 → y43.5 한 선 | 방 목록 선 참조·RGBA 비교·가시성 오차는 그대로 |
| 같은 파일 `:86` AT-DI-37 | 균등 칸 폭 합258 →226 | 230−2×2=226. 필터·개수·접근성·누르기 조건 그대로 |
| 같은 파일 `:104` AT-DI-39 | 토글 폭262 →230 | 244−14=230. 칸145·잘림·masksToBounds 불변 |

옛 선택 채움·급한 배지 단언을 대체한 새 AT-UC-14/16이 해당 지점까지 실행돼 통과했다. 다만 AT-UC-16의 **선택 테두리**는 뒤쪽에 있어 아직 실행되지 않았다. 최종 이관 검증 완료로 간주하면 안 된다.

### 실행·진단 결과

모든 로그는 구현 worktree 루트 `.build/ui-clean-evidence/` 아래다.

| 실행 | 실제 종료 | 검증한 변경본·결과 / 로그 |
|---|---|---|
| 지정 기준 merge | 0 | 위 기준, fast-forward |
| 첫 전체 앱 시험 | 1 | 실행 중 구현자 편집이 겹쳐 컴파일러가 수정 감지. 완료 증거 아님. `task-01-build-interrupted.log` |
| 전체 앱 시험(2번째) | 1 | 새 접근성 이름에서 연결 없음 문장 뒤에 시각을 붙여 AT-DC-22 실패. 시험은 그대로 두고 제품의 읽기 순서를 고침. `task-01-accessibility-failure.log` |
| 전체 앱 시험(3번째, 지정 HEJO_PYTHON으로 test.sh) | 1 | 현재 제품 소스와 동일. 기존 AT-TD·AT-DC·AT-DI·로고·머리 시험 통과 후 새 AT-UC-14 색 비교에서 실패. 당시 새 시험은 채팅 카드를 창 밖에 따로 그렸음. `task-01-app-tests.log` |
| 동일 시험 컴파일 명령 + `app-tests --drawer-inline` 집중 진단1 | 1 | 진단값 추가, 위 분리 보기의 DeviceRGB 표본이 달랐음. `task-01-focused-compile.log`·`task-01-focused.log` |
| 동일 시험 컴파일 명령 + `app-tests --drawer-inline` 집중 진단2 | 1 | **현재 미커밋11파일**. 채팅 목록의 실제 카드와 같은 창에서 비교하도록 시험 조립을 고침(기대/오차 유지). 급함 색 RGBA가 정확히 일치. 그 뒤 AT-UC-12에서 실패. `task-01-focused-compile-2.log`·`task-01-focused-2.log` |
| lldb 진단 시도 | 143 | 지정 중단점까지 진행되지 않아 실행자가 이 진단의 lldb/자식 프로세스만 종료. 시험 통과 근거 아님. `task-01-rail-debug.log` |
| scan_private.py, 임시 가짜 owner 입력 | 0 | 최신 변경본, 새 지적 없음. `task-01-private-scan.log` |
| git diff --check | 0 | 최신 변경본. `task-01-diff-check.log` |
| PNG RGBA 표본 분석 | 0 | 아래 수치. `task-01-bottom-pixels.json` |

실패 진단에서 새 시험의 창 밖 카드 조립을 실제 창 안 카드로 바꾼 이유: 수락 시험이 요구한 실제 ConversationView+PetController 조립을 지키기 위해서다. 별도 보기와 창 안 보기는 캐시 비트맵의 색 변환이 달랐다. 같은 창의 실제 카드에서는 두 표본 모두 RGBA `(0.912082,0.222331,0.426862,1)`로 일치했다. 제품 바탕·선 색이나 오차를 조정하지 않았다.

### R-UC-I3: AT-UC-12 바탕 표본이 카드/빈 공간을 서로 비교함

- [확인] 현재 사진 `task-01-after-dark.png`는718×500, 방 목록 폭68이다. 지정 x=S+145=213의 y=바닥−14=486은 마지막 알림 카드 안쪽이며, y=바닥−60=440은 바로 위 카드 사이 빈 공간이다. 두 사진(`task-01-before-dark.png`, `task-01-after-dark.png`)을 직접 열어 확인했다.
- PNG 표본 RGBA: `(213,486)`=(52,52,52,112), `(213,440)`=(36,36,36,107). 네 성분 차이 합은53/255=0.207843으로 기대6/255=0.023529보다 크다. 같은 두 높이의 방 목록 x34 표본은 모두(36,36,36,107), 차이0이다. `task-01-bottom-pixels.json`에 원본 좌표·수치 저장.
- [판단 요청] 이 지점은 서로 다른 표면(카드 바탕과 열 바탕)을 비교하므로, “열 바탕이 아래까지 같다”는 계약의 관측 위치를 보장하지 못한다. 카드/열 바탕을 같게 바꾸거나 바닥에 큰 빈 여백을 넣어 단언을 통과시키는 변경은 하지 않았다. 오차·기대값·현재 실패 단언도 그대로다.
- [권고] 계획 담당이 열 바탕 표본은 카드가 없는 지점/빈 상태로 명시하고, 별도로 마지막 카드의 동일 상대 픽셀이 스크롤 전후 같다는 조건을 검사하도록 입력·표본 조건을 보완한다. 또는 현재 표본 위치를 반드시 유지하려는 의도라면 카드 배치/아래 여백 요구를 확정한다. 비교 종류/시험 입력 해석 판단이 필요하므로 구현자가 선택하지 않았다.
- 남은 실행: 밝은 테마 새 사진·AT-UC-11·15·17~19 및 선택 테두리·키보드·새 빈 문구·전체 앱 종료0. AT-UC-13과 어두운 AT-UC-10·14(실행된 형상·급함색)·16(올림)은 실패 전 통과했으나 TASK 완료를 뜻하지 않는다. 기존 마감 닫기/되돌리기 회귀와 고정 머리 회귀는 전체3번째 실행에서 통과했다.
- 필요한 증거 수준2 + 양 테마 사진은 **미충족**. 현재는 어두운 스크롤 전후 사진과 급함 표시 진단 사진만 있다. mutation check도 수락 시험 충돌로 중단해 미실행이며 통과 변경본이 없으므로 수행했다고 주장하지 않는다.

### 다음 인계

R-UC-I3의 입력/바탕 표본 조건 판정 뒤 **현재 미커밋11파일을 보존**하고 재개한다. 그 전 TASK-01 커밋을 하지 않으며 TASK-02·03을 앞당기지 않는다. 검토자는 `task-01-candidate.patch`, 집중 진단2 로그, 스크롤 후 사진과 표본 JSON을 함께 확인하면 된다. 릴리즈 총괄에 보낼 상태는 기준 HEAD 위 부분 구현·시험 실패·새 후보 커밋 없음·푸시/운영 반영 없음이다.


## TASK-01 · 4판 재개: 신규 칸 시험 통과 / 전체 시험 보류(R-UC-I4)

### 기준과 보존

- 지정 기준 `67bbba19d49bb69ba0d9594cf350c9df6f2b153c`를 미커밋11파일이 있는 상태 그대로 merge했다. 종료0, 문서만 fast-forward, 충돌 없음. 폐기·stash는 하지 않았다.
- 이전 후보 patch와 대조해 UICleanDrawerTests 외 10파일 변경이 동일함을 확인했다(`task-01-edition-4-preservation.json`). 최초 시험 수정은 AT-UC-12 블록뿐(`task-01-edition-4-test-only.diff`)이며, 이후 아래 강조색 참조 조립을 보완했다. 제품 코드는 이번 재개에서 바꾸지 않았다.
- 현재11파일 전체 후보: `.build/ui-clean-evidence/task-01-edition-4-final-candidate.patch`. HEAD는 위 기준, 새 구현 커밋 없음. TASK-01 전체 종료0 조건 미충족이므로 커밋하지 않았다. TASK-02·03 제품 수정은 시작하지 않았다.

### 이번에 바꾼 시험·확인한 결과

- AT-UC-12는 수락 시험4판 그대로: 실제 모델 카드에서 3장/12장 입력을 조립했다. 3장은 x=S+145의 바닥−14/−60, 12장은 끝까지 스크롤 후 x=S+3의 두 높이를 비교하며 3장의 빈 바탕 표본과도 비교한다. 두 입력의 방 목록 표본도 비교한다. 같은 마지막 카드의 상대 좌표(200,45)를 3장일 때의 실제 viewport와 12장 스크롤 후 실제 viewport에서 비교한다. 오차는 모두6/255다.
- 어둡게·밝게의 AT-UC-12 및 스크롤 전후 머리 좌표 검사는 통과했다. 이전 R-UC-I3의 표본 충돌은 수정된 시험 조립으로 해소됐다. 제품 바탕·카드 값은 조정하지 않았다.
- AT-UC-16 선택 테두리는 처음에 동적 NSColor를 창 밖에서 DeviceRGB로 풀어 비교해 실패했다. 강조색 참조를 **같은 창 안**의 NSColor.controlAccentColor 그리기로 해석하도록 새 시험의 참조 조립만 보완했다(UICleanAccentReference). 기대 색·비교 종류·오차는 그대로다. 최종 픽셀은 테두리와 참조 모두 `(0,0.569464,1,1)`로 정확히 같았다. 기존 InlineAccentReference와 같은 이유이며 제품 값을 참조한 기대가 아니다.
- 집중 시험 `--drawer-inline` 종료0, AT-UC-10~19 전부 통과. 선택 유지/다른 카드/닫기 해제·키보드·빈 문구·기존 마감 닫기 회귀가 실행됐다.
- 사진: `task-01-three-cards-{dark,light}.png`, `task-01-before-{dark,light}.png`, `task-01-after-{dark,light}.png`, `task-01-selected.png`. 밝은 테마 원본은 반투명 RGBA이므로 원본은 보존하고 검토용 흰 바탕 합성 사본 `*-light-on-white.png`, `task-01-selected-on-white.png`도 만들었다. 원본과 사본을 직접 열어 칸·사진·상태·선택·고정 머리를 확인했다.
- 미검증 주의: 선택 사진은 동기 캡처다. history.scrollTo는 main queue에 지연 배치를 예약하므로, 선택된 스레드의 실제 화면 위치가 완전히 정착한 뒤의 사진·보이는 카드 관측은 추가로 남겨야 한다. 현재 자동 시험은 선택 messageID·replyMode·composeKey·contents의 강조 스타일을 검사했다. 이 제한을 실제 화면의 선택 연결 완료 증거로 과장하지 않는다.

### 실제 실행

위치: 구현 worktree 루트 `.build/ui-clean-evidence/`.

| 명령 | 종료 | 변경본·로그·판정 |
|---|---|---|
| 전체 `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh`(4판 최초) | 1 | AT-UC-12 양 테마 통과, 선택 강조색의 시험 참조 해석에서 실패. `task-01-edition-4-app-tests.log` |
| 동일 swiftc 시험 컴파일 + `app-tests --drawer-inline` | 0 | 현재11파일. `task-01-edition-4-focused-compile.log`, `task-01-edition-4-focused.log`: APP_TEST_OK·AT-UC-10..19 PASS |
| 지정 전체 앱 시험(최종) | **1** | 현재11파일. `task-01-edition-4-final-app-tests.log`: AT-TD·AT-DC·AT-DI·AT-UC-10~19 통과 뒤 IslandTests의 AT56에서 실패(아래). 이후 기본 시험 및 네트워크 fixture 미실행 |
| scan_private.py, 임시 fake owner 입력 | 0 | 현재11파일, `task-01-edition-4-final-private-scan.log`. 새 지적 없음 |
| git diff --check | 0 | 현재11파일, `task-01-edition-4-final-diff-check.log` |
| 현재 HEAD·status·미이관 단언 rg | 각각0 | `task-01-edition-4-state.json` |

신규 칸 시험의 통합 실행과 사진은 확보했지만 전체 종료0은 확보하지 못했다. mutation check는 여전히 미실행(시험 계약 충돌에서 보류). 설치·공개·main으로 구현 병합·푸시·운영 변경 없음.

### R-UC-I4: 전체 시험의 실제 경로와 이관 표가 다름 / TASK-02 잔여 누락

| 위치 | 확인한 사실 | 필요한 판정·권고 |
|---|---|---|
| `app/Tests/IslandTests.swift:116~120` AT56 | `ui.selectDrawerCard(firstQuestion)`로 **칸 카드**를 고른 후, 1.6초 뒤 highlightedMessageID==nil을 요구한다. design 4.1은 :120을 **알약 경로**의1.5초 단언이라고 적고 유지하라고 했다. REQ-UC-03 AC-07·AT-UC-17·이관된 AT-TD-25는 같은 칸 선택의 강조를 유지하도록 요구한다. 실제 전체 시험이 여기서 실패했다 | 현재 코드는 알약 activateIsland(.question)의1.5초를 그대로 유지하고 칸 선택만 지속시킨다. [권고] TASK-01 단계에서 이 AT56 준비 동작을 알약 action 처리 경로 `activateIsland(.question(...))`로 옮기도록 명시해 :118~120의 질문 이동·2pt 강조·1.5초 만료를 유지한다. 또는 칸 선택 시험으로 남길 의도면 :120을 지속 기대로 이관하고 알약1.5초는 별도 보호해야 한다. 구현자가 고르지 않았다 |
| `IslandTests.swift:43~44` AT53, TASK-02 | 빈 상태의 `idleStripe.size == CGSize(width:44,height:12)`를 요구한다. 제목 알약은 빈 처리할 일 상태에서도 제목을 그리므로 옛 빈 띠가 교체된다. 4.1 표에는 이 :44 단언이 없고, 문자열 폭을 갖는 제목 알약은 spec 수치 산수만으로 옛 빈 띠 기대를 옮길 수 없다 | [권고] 옛 빈 띠 단언을 AT-UC-01의 제목 알약·점 없음·제목 영역 누르기 보호로 교체하도록 명시. 시험만 만족하는 미사용 idleStripe API를 남기지 않도록 허용 범위를 확정 |
| `app/Tests/DrawerInlineTests.swift:49,53,57` AT-DI-05, TASK-02 | 대표 보기 배열이 Mirror로 `field("heading")`을 강제 추출하고 모든 보기의 화면좌표 +290을 단언한다. heading 제거 후 준비 코드가 실패한다. 해당 배열은4.1 표에 없다 | [권고] `field("heading")`을 `view.headerDrag`로 대체해 채팅 머리 대표 보기의 +290 계약을 유지하도록 명시. 나머지 배열·화면좌표 비교는 불변. 단순 숫자 이관이 아니라 대상을 바꾸므로 파생 수치 규칙으로 임의 처리하지 않음 |

- 위 사실은 실제 코드와 4.1 표를 대조한 것이며 제품 설계/기대값을 변경한 것이 아니다. 특히 AT56 만료 실패는 아직 TASK-02를 구현하지 않은 TASK-01 전체 시험에서 발생하므로 지금 해소할 인계가 필요하다.
- TASK-02·03은 선행 TASK-01 미완료 및 위 이관 범위 누락으로 미착수. 분홍 표식·접기 단추 실제 화면/뷰 계층 주인 확정은 TASK-03에 남아 있다. 밝은 사진에 보이는 묶음 글자의 낮은 가시성도 TASK-03 대상이며 이번 TASK-01에서 수정하지 않았다.

### 다음 인계

계획 담당이 R-UC-I4의 실제 AT56 준비 경로와 TASK-02 이관 두 곳을 명시한 뒤 재인계한다. 현재 미커밋11파일을 보존한다. 그다음 선택 스크롤 정착의 화면 증거를 보강하고 TASK-01 전체 종료0·정적 검사 후 자기 경로만 커밋, 이후 TASK-02→03을 진행한다. 현재 HEAD는 기준일 뿐 릴리즈 후보가 아니며 새 구현 커밋·푸시·운영 반영은 없다. 총괄 전달은 호스트 담당이다.


## TASK-01 · 5판 재개: AT56·정착 화면 통과 / 범위 밖 포커스 시험 실패(R-UC-I5)

### 기준·변경·보존

- 지정 문서 커밋 `e4005125d8c0c3662412b71d08d77e909ecde313` merge 종료0, fast-forward, 충돌 없음. 기존 미커밋11파일을 폐기하거나 stash하지 않았다.
- 이번 추가 변경은 시험뿐이다. design 4판4.1대로 `IslandTests.swift:120` AT56을1.6초 뒤 같은 messageID 유지로 이관하고, 칸 닫기→nil 검사를 더했다. 뒤쪽 기존 worker/좁은 머리 시험은 칸 열림을 전제하므로 닫기 검사 직후 다시 열어 원래 준비 상태를 복원했다. 다른 행동·개수·시간 기대를 바꾸지 않았다.
- 선택 스크롤의 실제 정착 사진을 얻도록 UICleanDrawerTests를 async로 바꿨다. 실제 질문 카드 선택 뒤 기존 waitFor로 viewport에 해당 스레드 중심이 들어오는지 기다리고, scrollTo가0.45초까지 재배치하는 점을 따라0.5초 뒤 실제 보이는 NativeThreadCard의 강조2pt·강조색을 검사한다. 주입 시계의2초 유지 검사는 그대로다. 어둡게·밝게 모두 검사·캡처했다.
- async 전파에 필요한 `DrawerInlineTests` 호출과 `TestMain` 호출만 await로 바꿨다. 따라서 현재 미커밋은 기존11파일 + IslandTests·TestMain = **13파일**이다. 제품7파일은 앞선 후보에서 바뀌지 않았다. 이번에 새 제품 경로·저장/통신 형식·운영 변경을 추가하지 않았다.
- 현재 후보 `.build/ui-clean-evidence/task-01-edition-5-candidate.patch`, HEAD는 위 기준. 전체 종료0 조건이 남아 새 커밋 없음. TASK-02·03 미착수.

### 선택·화면 증거

- `task-01-selected-settled-dark.png`, `task-01-selected-settled-light.png`를 직접 열어 확인했다. 선택한 질문 카드와 실제 viewport의 같은 스레드에 강조가 함께 보이고, 답글 모드·해당 직원 얼굴이 표시된다. 밝은 원본은 RGBA이며 검토용 흰 바탕 사본 `task-01-selected-settled-light-on-white.png`도 보존했다. 원본의 픽셀 검사는 원본 RGBA로 수행했다.
- 기존 AT-UC-10~19, AT-TD·AT-DC·AT-DI 및 이관한 AT56이 이번 전체 실행에서 통과했다. R-UC-I4의 칸 선택 만료 충돌과 선택 스크롤 정착 증거 누락은 해소됐다.

### R-UC-I5: 변경하지 않은 연결 창 포커스 시험 실패

- 전체 실행은 이후 `app/Tests/ConnectionsTests.swift:219`의 **AT-HC-27 show after onDismiss clears input and remains usable**에서 종료1이었다. 연결 제품 코드·시험 단언은 수정하지 않았다.
- 해당 단언은 `window.isVisible && window.isKeyWindow && live.fields.isEmpty && !live.busy`다. 기준 코드의 진단 값은 visible=true, **key=false**, fieldsEmpty=true, busy=false, **appActive=false**다. 표시·입력 초기화·비동기 처리 종료는 충족하고 키 창/앱 활성화가 충족되지 않았다.
- 변경본의 동일 연결 시험을 기존 `--task32-capture` 분기로 분리 실행해도 같은 단언에서 종료1이었다.
- 기준 커밋의 Sources/Tests를 추적하지 않는 증거 폴더로 `git archive`해 별도 바이너리를 만들었다. 연결 시험에 위 Boolean 출력 한 줄만 더했고, 그 줄을 제외한 **Swift144파일 전체가 기준 원본과 동일**함을 바이트 대조했다(`task-01-edition-5-baseline-provenance.json`, unexpectedDifferences=[]). 추적 파일을 체크아웃/폐기/수정한 것이 아니다.
- 기준 바이너리의 연결 분리 실행도 같은 값/단언에서 종료1. 이어 지정 venv를 사용한 기본 Swift 시험 전체 순서도 같은 AT-HC-27 및 같은 값으로 종료1이었다. **본 작업의 제품 변경 없이도 재현되는 실패**다. 기준 전체 test.sh(빌드+네트워크 fixture)를 통과시켰다는 뜻은 아니다.
- 원인은 활성화 가능한 GUI 세션 조건·시험의 고정0.1초 대기·기존 연결 창 문제 중 아직 확정하지 못했다. 화면 잠금 메타데이터 읽기는 unknown이었으므로 잠금 때문이라고 단정하지 않는다. 테스트 앱의 실제 관측이 비활성이었다는 사실까지만 확인했다.
- [권고] 계획 담당이 활성화가 가능한 시험 환경에서 기준의 이 단언을 확인하거나, 별도 연결 창/시험 조립 보완 범위를 판정한다. 이 작업에서 연결 제품 코드·기존 단언·대기를 고치거나 skip하지 않았다. 앱 활성화를 우회하기 위한 시스템 설정·공유 서비스 재시작도 하지 않았다.

### 명령·실제 결과

로그는 구현 worktree 루트 `.build/ui-clean-evidence/` 아래다.

| 실행 | 종료 | 변경본·결과·로그 |
|---|---|---|
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | **1** | 기준+현재13파일. 신규 AT-UC-10~19·AT56 통과 뒤 AT-HC-27 실패. `task-01-edition-5-app-tests.log`. 이후 나머지 기본 시험·네트워크 fixture 미실행 |
| 변경본 `app-tests --task32-capture <temporary evidence>` | 1 | 현재13파일 바이너리, 동일 AT-HC-27. `task-01-edition-5-connections-isolation.log` |
| 기준 복사본 Swift 컴파일 | 0 | 기준+진단 출력1줄. `task-01-edition-5-baseline-compile.log` |
| 기준 `ui-clean-baseline-tests --task32-capture` | 1 | 동일 AT-HC-27, key=false/appActive=false. `task-01-edition-5-baseline-connections.log` |
| 기준 기본 Swift 전체(첫 비교, venv 지정 누락) | 1 | 실행자 환경 지정 오류로 AT-PG-08의 Python fixture 시작 실패. 제품/기준 회귀 증거로 쓰지 않음. `task-01-edition-5-baseline-full-unit.log` |
| `HEJO_PYTHON=<gateway venv python> ui-clean-baseline-tests <resources>` | 1 | 기본 순서에서도 동일 AT-HC-27 및 위 Boolean 값 재현. `task-01-edition-5-baseline-full-unit-venv.log` |
| 기준 원본144 Swift파일 바이트 대조 | 0 | 진단 출력1줄만 제외, 예상 밖 차이0. `task-01-edition-5-baseline-provenance.json` |
| scan_private.py, 임시 fake owner | 0 | 현재13파일, 새 지적 없음. `task-01-edition-5-private-scan.log` |
| git diff --check | 0 | 현재13파일. `task-01-edition-5-diff-check.log` |

이번 UI 표현 변경의 독립 수치·문장·RGBA·실제 보기 계약 시험은 실행됐으나 전체 통과 조건은 충족하지 못했다. mutation check는 새 중요 알고리즘을 도입하지 않은 표현 작업이며 미실행이다. 밝은/어두운 스크롤 전후·정착 선택 사진은 확보했다. 전체 앱 검증 완료·TASK-01 완료/커밋으로 보고하지 않는다.

### 다음 인계

R-UC-I5 판정 전 **미커밋13파일 보존**, 새 후보 커밋 없음. 연결 시험 실행 조건/범위가 해소되면 같은 후보의 전체 test.sh 종료0을 확보하고 자기13경로만 commit --only 한다. 이어 TASK-02→03을 진행한다. 4판의 제거 보기 규칙과 알약 경로1.5초 유지 조건은 그대로다. 분홍 표식·접기 단추 주인 확정은 TASK-03에 남았다. main으로의 구현 병합·설치·공개·푸시·운영 반영 없음. 릴리즈 총괄에 전달할 후보 해시는 없으며 위 기준 위 미커밋 상태·공통 포커스 시험 실패를 호스트가 전달한다.


## TASK-01 · 환경 예외 재개: 추가 실패로 커밋 보류(R-UC-I6)

### 기준·보존·실행 범위

- 지정 문서 커밋 `5db23f5e08f5fafc9b211116e078f934bb73f6b8`을 구현 브랜치에 merge했다(종료0, 문서만, 충돌 없음). 구현을 main에 병합한 것이 아니다.
- 기존 미커밋13파일을 폐기하거나 stash하지 않았다. 이번 제품 변경·영구 시험 변경은 없다. 최종 후보 `task-01-exception-review-candidate.patch`는 이전 `task-01-edition-5-candidate.patch`와 바이트가 같다(`task-01-exception-review-state.json`). HEAD는 위 기준이며 새 구현/릴리즈 후보 커밋이 아니다.
- 승인된 절차대로 전체 앱 스크립트를 한 번 재실행한 뒤, AT-HC-27 단언 한 곳만 임시 출력으로 교체해 다시 실행했다. 임시 수정은 복원했고 커밋하지 않았다. 다른 단언을 건너뛰거나 기대값을 바꾸지 않았다.

### 앱 시험: 허용한 단언 뒤 추가 timeout

- 원문 전체 실행은 다시 `ConnectionsTests.swift:219` AT-HC-27에서 종료1. 새 AT-UC-10~19와 앞선 이관/회귀 시험은 통과했으나 뒤쪽 기본 시험과 네트워크 fixture는 미도달이다.
- 임시 실행에서 해당 단언의 실제 값은 **visible=true, key=false, fieldsEmpty=true, busy=false, appActive=false**였다. verdict5의 기준 재현 값과 같다.
- 그 뒤 **AT-HC-20~29 APP PASS**까지 진행한 다음 `APP_TEST_FAILED assertion("timed out")`으로 종료1. `AT-CM-30~38 APP PASS`는 출력되지 않았다. 정적 호출 순서는 connectionsScreenTests → connectionManagementTests이며, 뒤 함수의 `ConnectionsTests.swift:346`은 `NSApp.isActive && foremost.isVisible && foremost.isKeyWindow`를 기다린다. 이 대기가 후보지만 실행 스택/각 피연산자는 새로 수집하지 않아 정확한 실패 줄·원인은 확정하지 않는다. 다른 실패이므로 추가 skip/제품 수정/단언 변경 없이 멈췄다.
- 임시 diff `task-01-authorized-skip.diff`는 원래 단언 한 줄을 Boolean 출력 한 줄로 바꾼 것뿐이다. 원문은 `task-01-connections-original.swift`에 보존했다. 실행 후 바이트 SHA-256 일치, `git diff -- app/Tests/ConnectionsTests.swift` 빈 출력·종료0, 복원 결과 `task-01-authorized-exception-result.json`의 restored=true/restoredDiffEmpty=true를 확인했다.
- 따라서 **예외를 둔 전체 앱 스크립트도 통과하지 않았다**. Connections 이후 기본 시험 및 네트워크 fixture는 이번 실행에서 여전히 미도달이다. 전체 종료0이나 나머지 앱 전체 통과로 보고하지 않는다.

### 별도 게이트 시험

- app/scripts/test.sh에는 gate pytest 실행이 없으므로, 나머지 gate 결과를 얻기 위해 README에 있는 gate/tests + tests/acceptance 범위를 별도로 실행했다.
- 지정 venv에는 pytest가 없어 첫 시도는 No module named pytest로 종료1(미실행). pip도 없어 해당 의존성 설치 시도는 실행되지 않았다. 이어 uv로 pytest/pytest-asyncio와 의존성을 **무시되는 증거 폴더 test-python-deps/**에만 준비했다. 운영 venv·Hermes 본체·운영 설정은 바꾸지 않았다.
- 지정 venv + 위 임시 PYTHONPATH에서 pytest는 **422 passed, 5 failed**, 종료1이었다. 실패 목록:
  - `gate/tests/test_delivery_parity.py:125` test_native_labels_outcome_and_repeat_are_idempotent: 예상 한국어 버튼 문구 대신 `platform.slack.confirm.*` 키 문자열. 원인 미확정, 코드/기대 수정 없음.
  - `gate/tests/test_gateway_progress.py:228`, `tests/acceptance/test_gate_delivery.py:18`, `tests/acceptance/test_slack_move_gate.py:547`: 자식 러너에서 No module named yaml.
  - `tests/acceptance/test_gate_foundation.py:168` test_at_hf_08[True]: No module named hermes_facility.
- 게이트 코드·시험은 이 작업에서 바꾸지 않았지만 새 실패들의 기준 비교는 미실행이다. 환경/본 작업 무관으로 모두 면제하지 않는다. 추가 모듈 설치·team-kit 연결·게이트웨이 러너 단독 재실행·기대값 변경은 하지 않았다. 다른 실패는 멈추라는 지시에 따라 판정을 요청한다.

### 검증 명령·실제 결과

로그 경로는 구현 worktree 루트 `.build/ui-clean-evidence/` 기준이다. 검증본은 위 HEAD + 보존된13파일이며, 예외 실행에만 승인된 임시 단언 교체가 더해졌다.

| 명령 | 종료 | 증거·결과 |
|---|---|---|
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` 원문 | 1 | `task-01-exception-review-full.log`, AT-HC-27 실패 |
| 같은 전체 명령, AT-HC-27 단언 하나 임시 skip | 1 | `task-01-authorized-exception-app-tests.log`, 같은 key=false/appActive=false 관측 뒤 AT-HC-20~29 통과·추가 timeout |
| 원문 복원 후 `git diff --exit-code -- app/Tests/ConnectionsTests.swift` | 0 | `task-01-connections-restored.diff` 빈 파일, 원문 SHA-256 확인 JSON |
| 지정 venv `-m pytest gate/tests tests/acceptance -q --basetemp=<temporary test directory> -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider`, 임시 시험 의존성 PYTHONPATH | 1 | `task-01-exception-review-gate-ready.log`, 422통과·5실패 |
| 지정 venv `scripts/scan_private.py --home <temporary fake owner>` | 0 | `task-01-exception-review-private-scan.log`, 지적 없음 |
| `git diff --check` 원문 복원 후 | 0 | `task-01-exception-review-diff-check.log` |
| 최종 후보/이전13파일 patch 바이트 대조 | 0 | `task-01-exception-review-state.json`, candidateMatchesPrevious13Files=true |

### 미완료·다음 인계·릴리즈 총괄 전달

- TASK-01 커밋 조건(예외 외 나머지 통과)이 충족되지 않아 새 커밋 없음. **TASK-02·03 미착수**, 분홍 표식·접기 단추 실제 관측 확정도 남았다. 기존 양 테마 정착/스크롤 사진은 보존됐다.
- 계획 담당은 추가 연결 관리 timeout의 처리 범위와 올바른 게이트 시험 환경/번역 문구 실패를 판정해야 한다. AT-HC-27 외 추가 skip·시험 기대 수정은 승인되지 않았다. 재개 시13파일을 그대로 보존하고 이번 실패 로그부터 확인한다.
- main 병합 전에는 활성 가능한 앱 환경에서 AT-HC-27을 포함한 원문 전체 test.sh 종료0이 여전히 필수다. 앱 빌드 산출물은 임시 skip 실행본이므로 최종 검증/설치 산출물로 쓰지 않는다.
- 저장소 구현 브랜치는 `role-workflow/17-96051e66`, HEAD는 기준 `5db23f5e08f5fafc9b211116e078f934bb73f6b8`; 새 구현 후보 해시 없음. 제품 변경은 미커밋13파일에만 있다. 푸시·main으로의 구현 병합·설치·공개·운영 반영 없음. 릴리즈 총괄18에 완료로 전달하지 말고 이 미완료/차단 상태와 로그를 호스트가 전달한다.17 제외나 운영 변경 승인을 추정하지 않는다.
