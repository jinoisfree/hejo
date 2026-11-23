# HEJO-DRAWER-INLINE TASK-01 구현 인계

> 최신 상태는 아래 **TASK-02 보완 2** 절이다. TASK-01은 검증 완료됐고 이번 추가 변경과 구분한다. 앞 절의 보류·충돌 기록은 각 회차 이력으로 보존한다.

## 기준과 판단

- 인계: [handoff.md](handoff.md) 2판 및 0항 갱신. 위험도 일반, 필요한 증거 수준 2 + M-DI 화면 이미지.
- 선행: main의 `0c85496` 앱 구현 및 HEJO-DEADLINE-CLOSE 검증 기록을 확인했다. 지정 앱 파일의 미커밋 변경 없음.
- 착수 기준: `9a10cffcd0f4cee21528e8762752309ba7b1564d`. 구현 브랜치 `role-workflow/17-96051e66`에서 `git merge main`을 실행했고 충돌 없이 fast-forward됐다.
- 구현자 판단: **보류(2절 보고)**. 제품 구현과 새 시험은 작성했으나 아래 R-DI-I1의 상충하는 회귀 기준 때문에 완료로 넘기지 않는다. 최종 판정은 검증 담당 소관이다.

## 구조와 변경

- `PetPlacement`가 오른쪽 넓힘·왼쪽 임시 이동을 판정한다. `contentBubble`은 열린 상자에서 오른쪽 칸 몫을 뺀 상자로 바꾸고 기존 `resized` 계산은 유지했다.
- `PetController`는 화면 폭에서 칸 몫을 먼저 빼고 기존 `paneSplit`을 호출한다. 표시 폭은 시작 폭에서 목표 폭까지 `PetBubbleMotion.easedWidthProgress`를 공유해 독립 보간한다. 표시 폭 전달과 기존 버튼·상태 콜백 배선만 담당한다.
- `ConversationView`가 칸을 소유하고 방 목록·칸·채팅 순서로 배치·그린다. 채팅 부속 프레임과 본문 폭 계산도 새 열을 반영한다. 표시 폭 변경 때 숨김 상태는 즉시 반영한다.
- `PetView`의 칸 설치·표시 판단·덮개·칸 배경 배선을 제거했다. 대화 보기는 원점 0에서 웹 칸을 제외한 폭을 쓴다. Esc는 기존 `PetPanel` 콜백을 유지했다.
- `SidebarTone`에서 열 바탕과 선택 채움 색을 공유한다. `TodoDrawerView`의 불투명 배경을 제거하고 내부 스크롤·쌓기 폭은 290으로 고정해 바깥 경계로 자른다. 카드 테두리는 공통 1pt, 선택은 강조색 채움, 급함은 배지 글자만 빨강이다.
- 마감 닫기 카드 메뉴·출처·연결 없음·되돌리기·숨김 관련 모델과 컨트롤러 코드는 변경하지 않았다.
- 설계와 다른 제품 구조·새 설정·통신 계약은 없다. 덧대기·임시 이중 경로·새 추상화는 없다.

## 시험 이관과 보호 계약

- 새 `app/Tests/DrawerInlineTests.swift`: AT-DI-01~14(독립 좌표·웹 분할 숫자·저장 불변·기존 크기 조절·프레임별 보간·고정 카드 폭), AT-DI-20~23(실제 부모 합성 및 카드 픽셀), AT-DI-31(실제 닫기·빈 채팅 클릭).
- 삭제: `DrawerOutsidePlacementTests.swift`의 AT-FF-90~93, `TodoDrawerBackgroundTests.swift`의 AT-FF-40·41. 새 AT-DI로 책임을 이관하고 `TestMain.swift` 등록도 교체했다.
- `TodoDrawerTests.swift`: AT-TD-30 덮개 단언과 AT-TD-31·33·34·35의 옛 배치 단언을 제거했다. 옛 AT-TD-32의 움직임 검사는 AT-DI-12·14로 이관했다.
- AT-TD-27·29·36·37·41·42의 알약 입력·표시·저장·요청 주기 계약은 유지한다. AT-TD-41의 합쳐진 단언에 있던 옛 왼쪽 넓힘 좌표(`closed.minX-290`, 빈 알약도 같음)는 **원래 기대값으로 유지했다**. PetView 하위 보기 참조만 ConversationView 소유 보기로 바꿨다. 아래 충돌을 계획 담당이 먼저 처분해야 한다.
- AT-DI-14 시험 작성 중 CoreGraphics가 폭 0인 사각형의 접촉도 `intersects`로 잡는 것을 확인했다. 기대값을 바꾸지 않고 칸 오른쪽 끝 ≤ 채팅 왼쪽 끝으로 겹침을 관측한다.
- Mutation check: 임시 소스 복사본에서 왼쪽 이동 방향 오류와 선형 완화 오류를 주입했다. 정상본 종료 0, 두 변이 모두 종료 1로 검출. 제품 소스는 변이하지 않았다. 증거: `.build/drawer-inline-evidence/mutation-results.json`, 같은 폴더의 baseline·wrong-shift·linear-easing 로그.

## 검증 기록

검토 대상은 기준 `9a10cffcd0f4cee21528e8762752309ba7b1564d` + 구현 worktree의 미커밋 12개 변경 파일이다. 변경본은 `.build/drawer-inline-evidence/candidate.patch`에도 보존했다. 수락 기준 충돌과 전체 시험 실패로 제품 커밋·푸시는 보류했다. 구현 worktree의 절대 위치는 호스트 상태 블록을 따른다.

로그 경로는 구현 worktree 루트 기준이다. 명령의 `HEJO_PYTHON`은 인계에서 지정한 게이트웨이 venv python을 사용했다. 임시 홈·가짜 명부만으로 픽셀·조립 시험을 실행했다. 아래 통과는 자체 점검이며 독립 검증이 아니다.

| 명령·관측 | 실제 결과 | 로그·증거 |
|---|---|---|
| `git merge main` | 종료 0, 충돌 없이 기준으로 fast-forward | 이 보고서 기준 절, Git 이력 |
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | 종료 1. 빌드·서명 성공 후 기존 AT-TD-41 사장 알약의 옛 왼쪽 이동 기대에서 실패. 그 뒤 묶음 및 네트워크 fixture는 실행되지 않음 | `.build/drawer-inline-evidence/app-tests-final.log` |
| 최종 시험 소스 재컴파일(`xcrun swiftc`, 기존 앱 시험과 같은 대상·프레임워크) 및 `codesign` | 둘 다 종료 0. 전체 스크립트 실행 후 새 픽셀 시험의 관측 fixture만 보완; 제품 소스는 동일 | `.build/drawer-inline-evidence/focused-build.log` |
| 앱 폴더에서 `.build/app-tests --drawer-inline .build/hejo.app/Contents/Resources/Pet` | 종료 0. AT-DI-01~14·20~23·31 모두 통과, `APP_TEST_OK` | `.build/drawer-inline-evidence/inline-focused.log` |
| 앱 폴더에서 `.build/app-tests .build/hejo.app/Contents/Resources/Pet` | 종료 1. 위와 같은 AT-TD-41에서 실패(최종 시험 소스에 대해서도 재확인) | `.build/drawer-inline-evidence/default-current.log` |
| AT-DI-30 `rg` 두 검색(제품 소스의 옛 경로 이름, TodoDrawerView의 backgroundColor) | 각 종료 1, 일치 0건 | `.build/drawer-inline-evidence/obsolete-search.log`(명령 포함) |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1. 선행 문서 9·11줄의 기존 절대 경로 2건. 기준과 지문 동일, 새 지적 0건 | `.build/drawer-inline-evidence/private-scan.log`, `private-baseline.log`, `private-comparison.log` |
| `git diff --check` | 종료 0 | `.build/drawer-inline-evidence/diff-check.log` |
| 이동 방향·완화 변이 검사 | 정상 종료 0, 변이 둘 각각 종료 1(예상 실패 검출), 드라이버 종료 0 | `.build/drawer-inline-evidence/mutation-results.json` 및 각 로그 |

- 도달 증거 수준: 새 AT-DI에 대해 2(가짜 화면·임시 저장소·실제 AppKit 조립과 비트맵). AT-DI-32 전체 종료 0은 미충족이며 M-DI 사람 확인은 미실행이다.
- 화면: `.build/drawer-inline-evidence/inline-right-edge-dark.png`, `inline-right-edge-light.png`, `cards-dark.png`, `cards-light.png`. 앱 시험이 `app/.build/drawer-inline-evidence/`에 생성한 원본을 로그 폴더로 복사했다. 구현자가 두 전체 화면 이미지를 직접 열어 방 목록 | 칸 | 채팅 순서·선택 채움·배지 빨강을 확인했다. 운영 자료가 아닌 가짜 명부·카드의 native-view capture다.
- 픽셀 시험 관측: 밝은 유리의 offscreen cache가 유리 밑 색 평면을 가릴 수 있어, 색 평면은 실제 유리 content 내부의 기존 tint 바로 아래에 넣었다. 실제 tint·대화 보기·칸 합성 경로와 고정 허용 오차(6/255)는 유지했다. 선택 색 참조는 같은 AppKit draw 환경에서 명세의 고정 알파 0.22/0.12를 그린 독립 사각형이며 제품 색 함수는 호출하지 않는다.
- 첫 전체 시험은 닫기 직후 숨김 상태가 늦는 회귀를 검출했고 즉시 반영으로 수정했다(`app-tests-second.log`). 첫 빌드 시 의존 파일 부재 및 빌드 중 소스 정리로 재실행했으며 마지막 빌드·서명은 성공했다.
- 개인값 검사 초기 호출은 `--home`을 지정하지 않은 기본 입력 실행이었다. 스캐너 코드를 확인한 뒤 위 임시 홈 검사로 재확인했다. 검사에서 원본 설정을 변경하거나 일치한 값 내용을 출력하지 않았다.
- main에는 `d88e2c8` 개인값 문서 수정 커밋이 추가됐으나, 최신 main의 해당 문서를 직접 검색한 결과도 97·109줄에 새 절대 경로 표식 2건이다(착수 기준의 9·11줄과 지문이 다름). 최신 main 병합 뒤 개인값 검사를 다시 실행하고 잔여 항목을 확인해야 한다. 이번 범위 밖 문서는 직접 고치지 않았다.

## R-DI-I1: 회귀 동결 대상에 새 배치와 모순되는 좌표가 섞임

- [확인] `tests/acceptance/HEJO-DRAWER-INLINE.md` AT-DI-32는 AT-TD-41이 기대값 수정 없이 통과하고, 열거한 교체 대상만 바꾸도록 요구한다.
- [확인] 기존 `app/Tests/TodoDrawerTests.swift` AT-TD-41 사장 알약·빈 알약 단언에는 열기 뒤 창 왼쪽 끝이 기존 왼쪽 끝 -290이어야 한다는 기대값이 있다. 이 두 기대값은 복원해 유지했다.
- [확인] REQ-DI-02 AC-01 및 AT-DI-05는 같은 충분한 화면에서 창 왼쪽 끝 불변·폭 +290을 요구한다. 같은 입력에서 두 좌표 기대를 동시에 만족시킬 수 없다.
- [제안/권고] 계획 담당이 AT-TD-41의 **알약 입력·열림·닫힘 계약은 동결**, 섞여 있던 **옛 배치 좌표는 AT-DI-05로 이관**하도록 AT-DI-32와 인계의 교체 허용 범위를 명시한다. AT-TD-32의 옛 왼쪽 이동 단언도 같은 이관 범위에 명시한다. 제품 분기나 시험 전용 동작으로 옛 좌표를 통과시키지 않는다.
- 대안: 전체 회귀 기대값을 절대 바꿀 수 없다면 새 오른쪽 넓힘 요구를 바꿔야 하므로 사장 결정이 필요하다. 구현자는 권고안을 임의 승인하지 않았다.
- 보류 중 진행한 독립 범위: 새 AT-DI 좌표·픽셀 시험과 증거 준비. 전체 시험은 원래 AT-TD-41 기대값을 보존한 상태로 실행한다. 수락 시험 문서·설계·상태 문서는 변경하지 않았다.

## 남은 확인과 검토 요청

- M-DI-1·2 사람 확인은 구현자가 대신 완료 판정하지 않는다. 가짜 명부로 실제 AppKit 보기를 캡처한 이미지를 제공한다.
- 작업 도중 main이 `a2caf0a2369cd694737d55f217cc932c705a34f9`로 진행됐다. 앱 쪽 차이는 `app/Resources/Info.plist` 공개 버전뿐이고 앱 소스 차이는 없다. `git merge-base --is-ancestor main HEAD` 종료 1: 아직 구현 브랜치에 포함되지 않았다. 검증 담당이 R-DI-I1 보완 계획에 최신 main 병합·전체 재시험을 포함해야 한다.
- 미검증 범위: AT-TD-41 뒤의 전체 시험 및 네트워크 fixture, M-DI 사람 확인. 운영 공항·실제 메시지·공개·버전 변경은 이번 범위 밖이다.
- 검토 요청: 좁은 화면에서 창/칸 폭의 독립 보간, `contentBubble` 기반 기존 크기 조절, 모든 채팅 부속 프레임 이관, 투명 합성 표본과 중립 카드 테두리, AT-TD-41 혼합 단언의 배치 부분 이관.

## 보완 1 · 2026-11-23 · 보류(2절 보고: R-DI-I2)

### 받은 지시와 실제 변경

- [확인] verdict 2회 및 수락 시험 3판의 AT-DI-33을 기준으로 보완했다. `git merge main`은 종료 0, `9a10cff`에서 `95680e911baf05366cd784a703d603af9bd72d54`로 충돌 없이 fast-forward됐다. 기존 미커밋 12개 파일은 보존했다.
- [확인] 보완 전 변경본은 `.build/drawer-inline-evidence/before-supplement-1.patch`에 보존했다. 그 변경본과 비교하면 이번 보완에서 추가로 달라진 파일은 `app/Tests/TodoDrawerTests.swift` 하나다(`supplement-1-scope.log`).
- [확인] 사장 칸·빈 알약의 두 열기 단언을 승인된 `minX` 불변·폭 +290·펫 `globalSprite` 불변으로 고쳤다. 각각 클릭 전에 닫힌 `globalBubble.maxX+290<=1428`도 단언했다. 나머지 AT-TD-41 상태·라벨·닫기 단언과 다른 시험 기대값은 변경하지 않았다.
- [확인] R-DI-I1은 정정된 명세에 따라 해소됐다. 새 AT-DI-33 두 경우가 실제 전체 시험에서 통과했다. 제품 코드는 1회차 구현과 동일하다.
- 구현자 판단: **보류(2절 보고)**. 아래 R-DI-I2 때문에 요구된 전체 종료 0을 달성하지 못했고, 커밋·푸시는 실행하지 않았다. 현재 변경본은 `.build/drawer-inline-evidence/supplement-1-candidate.patch`에 보존했다.

### 실행한 검증

로그 경로는 구현 worktree 루트 기준이다. 검증 변경본은 위 기준 커밋 + 현재 미커밋 12개 파일이며, 증거 수준은 가짜 화면·임시 저장소·실제 AppKit 조립에 대한 2다.

| 명령·관측 | 실제 결과 | 로그 |
|---|---|---|
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | 종료 1. 빌드·서명 성공, AT-DI-33 두 경우·AT-TD-20~42·AT-DC-21~34·새 AT-DI 배치/픽셀 시험 통과 후 `AT53 narrow header reserves title and right icons`에서 실패 | `.build/drawer-inline-evidence/supplement-1-app-tests.log` |
| AT-DI-30 `rg` 두 검색 | 각각 종료 1, 일치 0건 | `.build/drawer-inline-evidence/supplement-1-obsolete-search.log`(명령 포함) |
| `git diff --check` | 종료 0 | `.build/drawer-inline-evidence/supplement-1-diff-check.log` |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 선행 HEJO-DEADLINE-CLOSE 문서의 기존 절대 경로 4건. 구현 파일 지적 0건 | `.build/drawer-inline-evidence/supplement-1-private-scan.log` |
| 위 개인값 지적과 `git show HEAD:<해당 파일>` 줄 지문 대조 | 드라이버 종료 0. 네 지적 모두 병합 기준의 같은 줄과 동일(기존 부채), 새 지적 0건 | `.build/drawer-inline-evidence/supplement-1-private-baseline.log` |
| `git merge-base --is-ancestor 95680e911baf05366cd784a703d603af9bd72d54 HEAD` | 종료 0 | Git 상태 확인 |
| 확인 시점의 `git merge-base --is-ancestor main HEAD` | 종료 1. 지시받은 기준 병합 후 main에 추가 커밋이 생김 | 아래 남은 작업 |

개인값 기존 지적: `HEJO-DEADLINE-CLOSE-20261122/impl-report.md` 97·109줄, `verdict.md` 127·146줄이다. 이번 범위 밖 문서를 고치거나 예외를 추가하지 않았다.

### R-DI-I2: 열린 칸을 포함한 전체 보기 폭을 옛 채팅 폭으로 강제하는 AT53

- [확인] 전체 시험은 `app/Tests/IslandTests.swift`의 `AT53 narrow header reserves title and right icons`에서 실패했다. 해당 파일은 수정하지 않았다.
- [확인] 같은 시험은 앞에서 알약을 클릭해 칸을 열고(`pet.drawerOpen` 확인), 이를 닫지 않은 채 `ui.frame.size.width=428`로 보기 전체 폭을 강제한다. 그 뒤 알약 폭 ≤146·제목 폭 ≥120·알약 높이 30을 요구한다.
- [확인] 새 배치에서는 보기 전체 폭에 칸 290이 포함된다. 현재 `ConversationView.layout` 식에 대입하면 방 목록 68 + 칸 290을 뺀 채팅 몫은 70이다. 이 공간 안에서 기존 머리 구성과 제목 120 이상을 동시에 보존할 수 없다. 옛 배치는 칸이 대화 보기 바깥에 있어 같은 보기 폭 428이 채팅 몫 360을 뜻했다.
- [제안/권고] 계획 담당이 AT53의 입력 폭을 **칸을 뺀 기존 대화 폭** 기준으로 다시 정의한다. 열린 칸을 유지한다면 좁은 보기 폭은 고정 `428+290=718`, 뒤의 넓은 보기 폭은 `760+290=1050`으로 이관하고, 기존 머리 기대값은 유지하는 방안을 권고한다. 칸 열림·폭 290 전제도 고정 단언으로 추가할 수 있다. 대안은 이 머리 회귀 구간 전에 칸을 닫아 기존 닫힌 상태 입력으로 검증하는 것이다. 어느 쪽도 구현자가 임의 적용하지 않았다.
- 멈춘 이유: 이번 지시는 AT-TD-41 두 단언만 바꾸고 다른 기대값은 바꾸지 말라고 명시했다. 제품에서 제목의 숨은 프레임만 억지로 키우거나 시험용 분기를 넣어 통과시키지 않았다.

### 남은 작업과 인계

- 계획 담당이 R-DI-I2의 시험 입력·보호 계약을 처분한 뒤 보완 재인계가 필요하다. 그 뒤 전체 시험·정적 검사 재확인과 자기 경로 `git commit --only`를 수행한다.
- 전체 시험에서 실패 이후의 묶음과 Python 네트워크 fixture는 미실행이다. M-DI 사람 확인도 미실행이다. 기존 화면 사진 4개는 루트 `.build/drawer-inline-evidence/`에 그대로 보존했다. 제품 코드가 같아 기존 화면 증거를 유지하며, 자동 시험은 앱 쪽 증거 폴더에 같은 장면을 다시 생성했다.
- 확인 시점 main은 `c9a653a36b4355f7591ff1a086b77449edc905e4`로 진행됐다. 여기에 포함된 `01e5e47`은 로고·버전 가운데 배치(REQ-DI-07) 문서 변경이고 다른 작업의 gate 변경도 있다. 이번 지시의 두 단언 보완 외 신규 구현은 하지 않았다. 다음 지시는 최신 기준 병합과 적용할 문서 판을 명시해야 한다.
- 운영 공항·실제 메시지·버전 올림·공개는 수행하지 않았다. 모든 제품 변경은 지정 구현 worktree에만 남아 있다.

## 보완 2 · 2026-11-23 · 보류(2절 보고: R-DI-I3)

### 받은 지시와 변경

- [확인] 판정 3회, 수락 시험 5판 정정, REQ-DI-07·design 2.5·AT-DI-34를 읽었다. 기존 미커밋 변경을 보존한 채 지시한 `19e049520a2316a9301fb8e5ade83bc09614bf5c`를 병합했다. 종료 0, 충돌 없는 fast-forward. 현재 HEAD도 이 커밋이다.
- [확인] 보완 1 변경본은 `.build/drawer-inline-evidence/before-supplement-2.patch`로 보존했다. 추가 변경은 `ConversationView.swift`, `DrawerInlineTests.swift`, `IslandTests.swift` 세 파일뿐이다. 기존 다른 변경은 동일하다(`supplement-2-scope.log`).
- 입력 이관: `app/Tests/IslandTests.swift:133`의 428 → 718, `:135`의 760 → 1050. 기대값·나머지 시험은 그대로다. 아직 전체 회귀 재실행으로 통과를 확인하지는 못했다.
- 로고 원인 확인: 기존 `brand.attributedStringValue` 생성의 속성에는 문단 스타일이 없었다. 라벨의 alignment 속성만으로 두던 정렬에 가운데 문단 스타일을 추가했다. 정렬 값 원본은 로컬 `sidebarAlignment` 하나이며 로고 문단·로고 라벨·버전 라벨이 공유한다. 글꼴·크기·첫 글자 파랑·색·폭 0 숨김은 변경하지 않았다.
- AT-DI-34는 실제 1000×600 ConversationView, 버전 `0.2.5`, 같은 머리 영역에서 글자를 숨긴 바탕과 실제 글자가 그려진 비트맵의 차이로 경계 상자를 잰다. 정렬 속성으로 결과를 판정하지 않으며, 고정 오차 ±1.5pt·첫 글자 파랑 조건을 그대로 적용했다. 칸 표시 폭 0·290에서 각각 측정한다.
- 구현자 판단: **보류(2절 보고)**. 아래 고정 입력 140의 충돌을 확인해 다른 폭 규칙·기대값은 바꾸지 않고 멈췄다. 커밋·푸시 없음. 현재 미커밋 13개 파일은 `.build/drawer-inline-evidence/supplement-2-candidate.patch`에 보존했다.

### 실행한 검증과 화면

로그 경로는 구현 worktree 루트 기준이다. 검증 변경본은 기준 19e0495 + 위 미커밋 13개 파일이다.

| 명령·관측 | 실제 결과 | 증거 |
|---|---|---|
| 기존 앱 시험과 같은 대상·프레임워크로 `xcrun swiftc` 전체 Sources·Tests 컴파일, `codesign` | 각각 종료 0 | `.build/drawer-inline-evidence/supplement-2-build.log` |
| 앱 폴더에서 `.build/app-tests --drawer-inline .build/hejo.app/Contents/Resources/Pet` | 종료 1. 기존 AT-DI 배치·픽셀 통과 후 `AT-DI-34 requested sidebar width 140.0, actual 180.0`에서 실패 | `.build/drawer-inline-evidence/supplement-2-inline.log` |
| AT-DI-34에서 어두운 테마 폭 68·212, 칸 표시 폭 각각 0·290의 실제 글자 경계 | 네 조립 모두 로고·버전 중심이 각각 정확히 34·106pt. 첫 글자 파랑 조건 통과 | `.build/drawer-inline-evidence/logo-centers.json` |
| AT-DI-30 `rg` 두 검색 | 각 종료 1, 일치 0건 | `.build/drawer-inline-evidence/supplement-2-obsolete-search.log`(명령 포함) |
| `git diff --check` | 종료 0 | `.build/drawer-inline-evidence/supplement-2-diff-check.log` |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 기준의 HEJO-DEADLINE-CLOSE 문서 절대 경로 4건, 이번 변경 지적 0건 | `.build/drawer-inline-evidence/supplement-2-private-scan.log` |
| 위 지적과 기준 커밋의 해당 줄 지문 대조 | 드라이버 종료 0, 네 지적 모두 동일한 기존 부채 | `.build/drawer-inline-evidence/supplement-2-private-baseline.log` |
| 보완 전 patch 대조 | 드라이버 종료 0, 추가 변경은 위 세 파일뿐 | `.build/drawer-inline-evidence/supplement-2-scope.log` |

- 새 로고 사진은 `.build/drawer-inline-evidence/logo-sidebar-68-dark.png`, `logo-sidebar-212-dark.png`다. 구현자가 두 파일을 직접 열어 실제 가운데 배치를 확인했다. 앱 시험이 생성한 파일을 루트 증거 폴더로 복사했다. 기존 칸 화면 사진은 유지했다.
- 도달 증거 수준: 확인한 조립·픽셀에 대해 2. 밝은 테마와 140·0의 AT-DI-34 검증은 입력 전제 실패 뒤라 미실행이다. 전체 `HEJO_PYTHON=... bash app/scripts/test.sh`는 이 보완에서 미실행이며 전체 종료 0·새 AT53 통과를 선언하지 않는다.
- 개인값 기존 부채는 선행 `impl-report.md` 97·109줄 및 `verdict.md` 127·146줄이다. 해당 문서와 검사 예외는 변경하지 않았다.

### R-DI-I3: AT-DI-34의 140pt가 기존 방 목록 폭 규칙으로 만들어지지 않음

- [확인] `ConversationView.setSidebarWidth`는 `ConversationSidebar.snapped` 결과만 저장하며 `sidebarWidth`는 private(set)이다.
- [확인] `app/Sources/ConversationChrome.swift:10-13`의 기존 규칙은 124 이상 입력을 최소 180으로 보정한다. 따라서 140 요청은 180이 된다. 해당 규칙은 이번에 변경하지 않았다.
- [확인] 실제 시험에서도 고정된 1000pt 보기에서 `setSidebarWidth(140)` 뒤 폭이 180임을 관측했다. 140pt 전제를 만족시키기 위해 시험용 쓰기 경로나 별도 상태를 추가하지 않았다. 라벨 프레임만 140으로 덮어쓰면 실제 열 폭 검증을 우회하므로 적용하지 않았다.
- [제안/권고] 계획 담당이 AT-DI-34의 비표준 폭 입력 140을 기존 규칙으로 가능한 180 또는 240으로 정정하는 방안을 권고한다. 사장 요구인 실제 방 목록 열 가운데 정렬은 그대로 검증할 수 있다. 140pt 열 자체를 제품에 허용하려면 기존 폭·스냅 계약 변경이므로 별도 명세와 범위 승인이 필요하다.
- 지시의 다른 꼴 실패 멈춤 규칙에 따라 보류했다. 수락 시험 문서·폭 규칙·고정 기대값은 임의로 수정하지 않았다.

### 다음 작업

- 계획 담당이 R-DI-I3을 처분하고 허용할 폭 입력을 확정해 재인계한다. 그 뒤 AT-DI-34 전체 및 전체 앱 시험을 실행하고, 같은 꼴의 열린 칸 보기 폭 입력만 허용된 규칙으로 이관하며, 다른 꼴 실패는 다시 보고한다. 검사와 커밋은 전체 검증을 마친 뒤 수행한다.
- 확인 시점 main은 `0ded4b8a1b7bb2076c4232d378c1ab4ce4900fbb`로 지시 기준보다 앞서 있다. 다음 인계에서 병합 기준도 갱신해야 한다. 이번에는 지시한 19e0495만 병합했다.
- 제품 변경·시험은 지정 worktree에만 남아 있다. 운영 공항·실제 메시지·공개·버전 올림은 하지 않았다.

## 보완 3 · 2026-11-23 · 보류(2절 보고: R-DI-I4)

### 받은 지시와 보존·병합

- [확인] 판정 4회와 수락 시험 6판을 대조했다. 기존 13개 파일 변경을 패치(`.build/drawer-inline-evidence/before-supplement-3.patch`)와 이름 `HEJO-DRAWER-INLINE-supplement-3-preserved`의 Git stash로 보존했다. stash는 복원 후에도 안전 보관본으로 남겼다.
- 지시한 `bb14bd3d6e59d4e4d6361240af88c10b7e187bc7`을 `git merge`로 병합했다. 종료 0, fast-forward. 이어 stash 적용도 종료 0, 충돌 없음. 현재 HEAD는 이 기준이다. rebase·force·제품 커밋·푸시는 하지 않았다.
- `ConversationView.swift`의 기존 iMessage 메뉴 제거와 `TestMain.swift`의 telegram 시험 진입점·호출 변경을 보존했다. 보존본의 13개 경로와 현재 파일을 직접 대조했다. 위 텔레그램 변경과 이번 시험 정정 두 곳 외 차이 없음(`supplement-3-scope.log`, 종료 0).
- 추가 수정은 `app/Tests/DrawerInlineTests.swift:243`의 입력 140 → 240, `:274`의 사진 저장 대상에 240 추가뿐이다. 로고·버전 픽셀 중심 ±1.5pt, 첫 글자 파랑, 폭 0 숨김 기대값은 변경하지 않았다. 제품 소스는 보완 2 구현 그대로다.
- 이전 보완의 `IslandTests.swift:133` 428 → 718, `:135` 760 → 1050은 유지했다. 이번에는 해당 시험에 도달하기 전에 중단됐고, 같은 꼴의 추가 입력 이관은 없다.

### 검증 결과

대상은 위 기준 + 기존 13개 변경 파일이다. 현재 전체 변경본은 `.build/drawer-inline-evidence/supplement-3-candidate.patch`에 보존했다. 로그 경로는 구현 worktree 루트 기준이다.

| 명령·관측 | 실제 결과 | 증거 |
|---|---|---|
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | **종료 1**. 앱·시험 빌드와 서명 성공. AT-DI-33, AT-TD-20~42, AT-DC-21~34, AT-DI-01~14·31, AT-DI-20~23 통과 뒤 AT-DI-34의 버전 글자 픽셀 검출 실패 | `.build/drawer-inline-evidence/supplement-3-app-tests.log`, `supplement-3-app-tests.exit` |
| 어두운 테마 AT-DI-34 폭 68·212·240, 칸 표시 폭 각각 0·290 | 여섯 조립 모두 로고·버전 중심이 34·106·120pt. 첫 글자 파랑 통과. 이어 폭 0 숨김 통과 | `.build/drawer-inline-evidence/logo-centers.json` |
| AT-DI-30 `rg` 두 검색 | 각 종료 1, 일치 0건 | `.build/drawer-inline-evidence/supplement-3-obsolete-search.log` |
| `git diff --check` | 종료 0 | `.build/drawer-inline-evidence/supplement-3-diff-check.log` |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 선행 문서의 기존 절대 경로 4건 | `.build/drawer-inline-evidence/supplement-3-private-scan.log` |
| 개인값 지적과 `git show HEAD:<해당 파일>`의 같은 줄 지문 대조 | 드라이버 종료 0, 네 지적 모두 기준과 동일, 새 지적 0건 | `.build/drawer-inline-evidence/supplement-3-private-baseline.log` |
| 보존한 13개 파일의 내용 대조 | 드라이버 종료 0, 승인된 차이만 있음 | `.build/drawer-inline-evidence/supplement-3-scope.log` |
| `git merge-base --is-ancestor bb14bd3d6e59d4e4d6361240af88c10b7e187bc7 HEAD` | 종료 0 | Git 기준 확인 |

개인값 지적은 선행 HEJO-DEADLINE-CLOSE `impl-report.md` 97·109줄, `verdict.md` 127·146줄이다. 해당 문서나 검사 예외는 수정하지 않았다. 설정·다운로드 보호 검사는 로그에서 `ACTUAL_CLI_SETTINGS_METADATA_UNCHANGED`, `ACTUAL_DOWNLOADS_NAMES_UNCHANGED`를 확인했다.

사진은 `logo-sidebar-68-dark.png`, `logo-sidebar-212-dark.png`, `logo-sidebar-240-dark.png`를 같은 루트 증거 폴더로 복사했다. 새 240pt 사진을 직접 열어 로고·버전 가운데 배치를 확인했다. 기존 칸 사진은 유지했다. 밝은 테마는 아래 실패로 사진 저장까지 도달하지 못했다. M-DI 사람 확인과 전체 종료 0은 미충족이다.

### R-DI-I4: 밝은 테마에서 버전 글자 경계 상자를 검출하지 못함

- [확인] 최종 실패는 `APP_TEST_FAILED assertion("AT-DI-34 missing rendered ink 26..<38")`다. 여섯 어두운 조립만 JSON에 기록되어 있으며, 반복 순서상 그 다음 밝은 테마 폭 68·칸 0의 버전 영역에서 실패했다. 로고 경계 검출 이후 버전 경계를 구하는 단계다(`DrawerInlineTests.swift:266`).
- [확인] 시험은 테마를 바꿀 때 `window.appearance`·`view.appearance`만 지정한다(`:242`). 실제 제품의 `ConversationView.refresh`는 그 시점 테마로 `version.textColor=CardText.quiet(dark:)`를 정하며(`ConversationView.swift:584`), 실제 테마 설정 변경은 `ChatAppearance.didChange` → `applyChatAppearance()` → `refresh()`를 지난다. `CardText.quiet`는 지정 테마로 해석된 색을 반환한다.
- [가정/미확정] 시험이 실제 테마 변경의 refresh 경로를 거치지 않아 이전 테마의 버전 색을 남겼을 가능성이 있다. 캐시 갱신·픽셀 관측 문제나 제품 문제인지 추가 판정은 하지 않았다. 원인을 확정하기 위한 시험·제품 수정이나 기대 완화는 수행하지 않았다.
- 요청의 "다른 꼴 실패는 멈춤"에 따라 여기서 중단했다. 계획 담당이 시험의 테마 조립 보완을 허용할지, 제품 동작의 문제로 처리할지 판정해야 한다. 중심 오차·파랑·숨김 조건 및 입력 폭은 유지해야 한다.

### 남은 작업과 인계

- 제품 커밋은 없음. 지정 브랜치의 13개 변경 파일을 그대로 남겼다. AT-DI-34 밝은 테마를 포함한 전체 시험 종료 0, 여섯 로고 사진, 독립 검토가 남았다. 실패 뒤 IslandTests와 Python 네트워크 fixture는 미실행이다.
- 확인 시점 main은 `1150a27a495323eed3b4f926d4c0f8f76c13aa51`로 지정 기준보다 앞섰다. 다음 인계는 새 병합 기준과 R-DI-I4 처분을 명시해야 한다. 푸시 승인 전 로컬 기준·원격 tip 포함 재확인이 필요하다.
- 운영 공항·실제 메시지·버전 올림·공개는 수행하지 않았다.

## 보완 4 · 2026-11-23 · 구현·자체 시험 완료(독립 검토 대기)

### 기준·보존·커밋

- [확인] 판정 5회와 수락 시험 7판을 읽었다. 기존 13개 파일을 `before-supplement-4.patch`와 새 stash로 보존하고, 지정 기준 `ce0e3d40ca6aed18a602e323c530156cdba7874e`을 병합했다. merge·stash apply 각각 종료 0, 충돌 없이 fast-forward·복원했다. 기준 사이 app 변경은 없었다.
- 기존 `HEJO-DRAWER-INLINE-supplement-3-preserved`는 현재와 세 파일(ConversationView·TestMain의 텔레그램 변경, DrawerInlineTests의 240 입력 정정)이 달라 삭제하지 않았다. 보관 해시는 `28d3f78ba449abe1be4301d9f7ea177a68cec521`이다. 새 `HEJO-DRAWER-INLINE-supplement-4-preserved` 해시는 `6fe6329031dbab2f5d8348d8672bcf467265fd15`이며 역시 남겼다. **둘 다 이미 작업 트리에 복원한 과거 보관본이므로 다시 적용하지 않는다.**
- TASK-01 커밋: **`94b06efe92743f0439bb6190d2ddd8ab088a8ddd`**, 브랜치 `role-workflow/17-96051e66`. `git commit --only`로 아래 13개 경로만 커밋했다. 구현 worktree 상태는 깨끗하다. 푸시하지 않았다.
- 영향 파일: Sources의 ConversationChrome·ConversationView·PetController·PetLayout·PetView·SidebarMotion·TodoDrawerView, Tests의 DrawerInlineTests(추가)·DrawerOutsidePlacementTests(삭제)·IslandTests·TestMain·TodoDrawerBackgroundTests(삭제)·TodoDrawerTests. 이전 절에 적힌 칸 배치·색·회귀 이관 구현을 모두 포함한다.

### 이번 변경과 R-DI-I4 원인 확인

- 이번 보완 추가 변경은 `app/Tests/DrawerInlineTests.swift`뿐이다. 나머지 12개 경로는 보존본과 바이트 대조로 동일함을 확인했다(`supplement-4-scope.log`). 제품 코드는 추가 변경하지 않았다.
- AT-DI-20~23은 이미 임시 LocalStore에 묶인 `ChatAppearance.change(theme:)` → `pet.applyChatAppearance()`와 실제 부모의 배치·cacheDisplay 경로를 사용하고 있었다. 이 경로를 유지했다.
- AT-DI-34를 임시 LocalStore·가짜 명부·실제 PetController/PetPanel에 조립했다(`DrawerInlineTests.swift:219~250`). 실제 ConversationView 1000×600을 단언하며, 테마 전환은 같은 `ChatAppearance.change` → `pet.applyChatAppearance` 후 배치·그리기를 거친다. window/view.appearance를 직접 바꾸던 전환은 제거했다. 끝나면 이전 ChatAppearance 저장소를 복원한다.
- [확인] 실제 경로로 바꾼 첫 전체 실행에서도 버전 픽셀 검출 단언이 실패했다. 진단 사진·라벨 상태를 남겨 확인하니 버전은 `0.2.5`, 숨김 false, 프레임 (0,26,68,12), effective appearance Aqua, 색은 기존 CardText.quiet의 검정 RGB(0,0,0), alpha 약 0.593이었다. 실제 제품에서 글자가 사라진 것이 아니었다.
- [확인] 관측 코드가 RGB 차이만 계산해 투명 바탕 RGB(0,0,0)와 검정 글자 RGB(0,0,0)를 같다고 잘못 판단했다. 실패 원본의 버전 글자에는 RGB 차이가 없는 **알파 픽셀 105개**가 있고, 경계 (22,28)~(46,37)의 가운데는 정확히 34pt다. 증거: `logo-failed-light.png`, `logo-failed-state.json`, `supplement-4-alpha-diagnostic.json`.
- 원인 분류(구현자 확인): 시험 조립에 더해 **시험 픽셀 관측 구현 오류**였다. 승인된 "바탕과 다른 픽셀"을 투명 PNG에서도 관측하도록 RGBA 차이를 사용했다(`DrawerInlineTests.swift:268~270`). 이는 제품 색이나 기대값 변경이 아니다. 중심 오차 ±1.5pt·첫 글자 파랑·폭 0 숨김·68/212/240 입력 및 차이 판정 한계 0.05를 유지했다. 향후 같은 실패를 조사할 수 있도록 실패 때만 사진·상태 JSON을 저장한다.
- 앞선 "테마 경로를 거치지 않아 색이 남았을 가능성"은 원인으로 확정하지 않는다. 실제 경로에서 정상 검정색·그려진 글자를 확인했으므로 ConversationView 색·숨김·갱신 코드를 임의로 바꾸지 않았다. 수락 시험 Markdown도 변경하지 않았다.
- IslandTests 입력 이관은 이전 두 곳(133줄 428→718, 135줄 760→1050)뿐이며 이번에는 추가 충돌·기대 변경이 없었다.

### 실행한 검증

로그는 구현 worktree 루트의 `.build/drawer-inline-evidence/` 기준이다. 최종 전체 시험 변경본은 기준 ce0e3d4 + 위 13개 파일이며, 시험 시작 후 내용이 변하지 않았음을 patch로 대조한 뒤 동일 내용을 94b06ef로 커밋했다. 최종 커밋의 검증이며 이후 main 변경을 대신 검증한 것이 아니다.

| 명령·관측 | 실제 결과 | 로그·증거 |
|---|---|---|
| 최초 `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | 종료 1, 실제 테마 전환 후에도 RGB 관측 오류로 버전 픽셀 검출 실패 | `supplement-4-app-tests.log`, `supplement-4-app-tests.exit` |
| 진단용 전체 Sources·Tests `xcrun swiftc`, `codesign` | 각각 종료 0 | `supplement-4-diagnostic-build.log` |
| 진단 `.build/app-tests --drawer-inline .../Pet` | 종료 1, 같은 단언. 실패 사진·상태 확보 | `supplement-4-diagnostic-inline.log`, `supplement-4-diagnostic-inline.exit` |
| 실패 PNG의 알파 픽셀 독립 분석(venv Pillow) | 종료 0, 위 105개·경계·가운데 확인 | `supplement-4-alpha-diagnostic.json` |
| **최종 `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh`** | **종료 0**. 빌드·서명, 전체 기본 앱 시험, 모든 네트워크 fixture와 hook 시험 9개 통과. AT-DI-34·IslandTests도 통과 | **`supplement-4-final-app-tests.log`**, `supplement-4-final-app-tests.exit` |
| AT-DI-30 `rg` 두 검색 | 각 종료 1, 일치 0건 | `supplement-4-obsolete-search.log` |
| `git diff --check` | 종료 0 | `supplement-4-diff-check.log` |
| 임시 홈·가짜 명부 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 선행 문서의 기존 지적 4건 | `supplement-4-private-scan.log` |
| 개인값 지적과 기준 커밋 해당 줄 지문 대조 | 드라이버 종료 0, 네 지적 모두 기존과 동일, 새 지적 0건 | `supplement-4-private-baseline.log` |
| 보존본 내용 대조·최종 시험 patch 대조 | 종료 0, 추가 변경은 위 시험 하나이고 시험 후 커밋 내용 동일 | `supplement-4-scope.log`, `supplement-4-candidate.patch` |

개인값 지적은 HEJO-DEADLINE-CLOSE `impl-report.md` 97·109줄, `verdict.md` 127·146줄이다. 해당 문서나 검사 예외를 변경하지 않았다. 시스템 Python의 Pillow 분석 시도는 모듈 없음으로 종료 1이었고, 게이트웨이 venv로 다시 실행해 위 결과를 얻었다. 최종 로그에는 설정·다운로드 보호 검사 모두 UNCHANGED임을 확인했다. 기존 Swift 컴파일 경고·WebKit 환경 메시지가 있지만 최종 실행 종료는 0이다.

### 화면 증거와 남은 인계

- `logo-centers.json`: 어둡게·밝게 각각 폭 68·212·240, 칸 표시 폭 0·290의 12개 조립 모두 로고·버전 중심이 34·106·120pt로 정확히 일치한다. 첫 글자 파랑, 두 테마의 폭 0 숨김도 통과했다.
- 원본 사진 6개: `logo-sidebar-{68,212,240}-{dark,light}.png`. 밝은 테마의 투명 PNG는 열람 도구가 검정 바탕으로 보여 검정 글자가 안 보일 수 있다. 원본은 유지하고 흰 바탕에 합성한 열람용 사본 `logo-sidebar-{68,212,240}-light-on-white.png`를 추가했다. 측정은 투명 원본으로만 했다. 구현자는 밝은 사본 세 장을 직접 열어 로고·버전 가운데를 확인했다. 기존 칸 배치·카드 사진도 유지했다.
- 도달 증거 수준 2 + M-DI 확인용 사진 확보. M-DI 사람 확인·설계 적합성 최종 판정·푸시 승인은 검증 담당/사용자 단계에 남아 있다.
- 확인 시점 main은 `223a191accbb70c28f7b35cfdf2eee9490dfb109`로 지정 기준보다 앞섰다. ce0e3d4..main의 app 변경은 없지만 이 커밋은 아직 새 main을 포함하지 않는다. 계획 담당은 푸시 승인 전에 최신 로컬 main·원격 추적 tip 포함 요건을 확인하고 필요한 보완 병합을 지시해야 한다. 이번에는 지정한 ce0e3d4만 병합했다.
- 운영 공항·실제 메시지·버전 올림·공개는 수행하지 않았다. 보고 문서만 계획 checkout에 갱신했고 제품 변경은 지정 구현 브랜치에만 커밋했다.

## TASK-02 · 2026-11-23 · 보류(2절 보고: R-DI-I5)

### 받은 설계·기준·현재 변경

- 받은 설계: handoff.md 추가 인계 TASK-02, spec 4판 REQ-DI-08·09, design 4판 2.6, 수락 시험 8판 AT-DI-35~39, 시안 A. 위험도 일반, 필요 증거 2 + 어둡게·밝게 스크롤 전후 사진. 별도 하위 에이전트 없이 직접 구현했다.
- 기존 구현 worktree 상태가 깨끗함을 확인하고 지정 기준 `d94fb6b98e83b85417c227aaded4285acc35a59f`를 merge했다. 종료 0, 충돌 없이 fast-forward. 현재 HEAD·확인 시점 main 모두 이 기준이다. TASK-01 구현·설치·푸시는 반복하지 않았다.
- 현재 변경 파일 5개(미커밋): `app/Sources/TodoDrawerView.swift`, `ConversationChrome.swift`, `ConversationView.swift`, `app/Tests/DrawerInlineTests.swift`, 새 `DrawerHeaderTests.swift`. 모두 TASK-02 영향 범위 안이다. 전체 patch: `.build/drawer-inline-evidence/task-02-candidate.patch`.
- `TodoDrawerView`에 고정 제목·필터 영역을 배치했다. 각각 44pt, 카드 스크롤은 위 88pt·기존 되돌리기 바닥 줄을 뺀 영역이다. 문서 스택에서 옛 제목·필터 글자를 제거했다. 카드 그리기·메뉴·모델·onFilter/onCard/onClose·바닥 줄 로직은 유지했다.
- `ComposerModeTrack`을 공용 원본으로 추출했다. 채팅 토글과 필터가 트랙 그리기(labelColor 알파 0.1, 반원 모서리), 안쪽 2pt, 높이·11pt 글꼴 규칙, 칸 배치 함수를 공유한다. 단추는 기존 ComposerButton(mode:true)을 그대로 쓴다. 필터는 4칸/3칸 균등 폭, "전체 N" 포함 개수, chosen·접근성 선택 상태와 기존 onFilter 배선을 사용한다. 옛 TodoDrawerButton은 접기·되돌리기에만 남겼다.
- `DrawerHeaderTests`를 추가해 실제 임시 저장소·가짜 명부·ConversationView+PetController, 1440×900, 질문4·마감4·알림4(급한6·나머지6), 실제 테마 전환으로 AT-DI-35~39를 구현했다. DrawerInlineTests의 기존 묶음 끝에서 호출한다. 기대값·수락 시험 문서는 변경하지 않았다.
- 구현자 판단: **보류**. 아래 구분선 합성 색 조건을 충족하려면 현재 허용 범위 밖인 ConversationView.draw의 띠 바탕 처리를 바꿔야 한다고 판단해 멈췄다. 제품 커밋·푸시 없음.

### 실행 검증과 증거

대상 변경본은 기준 d94fb6b + 위 미커밋 5개 파일이다. 아래 로그 경로는 구현 worktree 루트 기준이다.

| 명령·관측 | 실제 결과 | 로그·증거 |
|---|---|---|
| 전체 Sources·Tests `xcrun swiftc` 및 `codesign` | 각각 종료 0 | `.build/drawer-inline-evidence/task-02-build.log` |
| `.build/app-tests --drawer-inline .../Pet` | 종료 1, AT-DI-35 구분선 픽셀 비교에서 실패. 제목 아래 선을 부모와 칸에서 이중으로 그렸음을 확인하고 중복 제거 | `task-02-focused.log`, `task-02-focused.exit` |
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | **종료 1**. 중복 제거 후에도 아래 R-DI-I5로 실패. 빌드·서명, 기존 AT-TD·AT-DC, AT-DI-01~14·20~23·31·33·34 통과 | **`task-02-app-tests.log`**, `task-02-app-tests.exit` |
| AT-DI-35 조립·프레임 | 카드12(6+6), 제목·접기 중심22±1, 필터 중심66±1, 스크롤 위88, 트랙 좌우14/276 단언 통과 | 같은 전체 로그가 실패한 위치 이전 단언 |
| `git diff --check` | 종료 0 | `task-02-diff-check.log` |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 기존 문서 지적4건 | `task-02-private-scan.log` |
| 위 지적과 `git show HEAD:<해당 경로>` 같은 줄 지문 대조 | 드라이버 종료 0, 네 건 모두 기준과 동일, 새 지적0 | `task-02-private-baseline.log` |
| 시험 이후 patch 대조 | 종료 0, 시험한 변경본과 현재 동일 | `task-02-candidate.patch` |

개인값 기존 지적은 선행 HEJO-DEADLINE-CLOSE impl-report.md 97·109줄과 verdict.md 127·146줄이다. 해당 문서·검사 예외는 변경하지 않았다. 전체 시험 종료 시 설정·다운로드 보호 검사 UNCHANGED도 확인했다.

사진 `header-before-dark.png`를 루트 증거 폴더로 복사해 직접 열었다. 제목·필터 띠 배치와 시안 A 토글은 그려져 있다. 그러나 AT-DI-35 색 비교에서 먼저 중단되어 스크롤 전후·밝은 테마 사진, AT-DI-36~39 실행 결과는 아직 없다. 코드 작성·빌드만으로 이들을 통과로 보고하지 않는다. 뒤의 기본 회귀와 네트워크 fixture도 이번 전체 실행에서는 미실행이다. mutation check는 수락 기준 차단으로 생략했다.

### R-DI-I5: 같은 선 그리기 값과 같은 합성 픽셀을 동시에 요구하지만 바탕이 다름

- [확인] `ConversationView.draw:761`은 채팅 머리에만 labelColor 알파 0.035를 더한다. 칸 제목 띠에는 이 바탕이 없고, 필터 띠 아래는 `:762~763`의 SidebarTone.column(dark:) 바탕이다(어둡게는 primary 알파 0.035, 밝게 0.025).
- [확인] `ConversationView.draw:769`는 이미 전체 열에 걸쳐 제목 아래 선을 SidebarTone.primary(0.1)로 그린다. 칸에서도 같은 선을 다시 그리면 중복이다. 이를 제거해 현재 TodoDrawerView.draw는 **필터 아래 선만** primary(0.1)로 그리며, 제목 아래는 기존 부모의 공통 선을 그대로 쓴다. 새 불투명 판이나 선 색 보정은 넣지 않았다.
- [확인] 그런데 AT-DI-35는 실제 합성 비트맵의 칸 좌표 y43~44·87~88 선과 채팅 머리 선의 RGB 차이 합을 6/255 이하로 요구한다. 같은 primary(0.1)를 써도 위 바탕 차이가 남는다. 현재 어두운 조립의 각 RGB 채널: 채팅 선 0.381534, 제목 선 0.310677, 필터 선 0.372655. 제목 차이 합 **0.2125704**, 필터 약 **0.026637**로 한계 **0.0235294**를 넘는다. 실제 값은 전체 로그와 `task-02-line-comparison.json`에 있다.
- 현재 지시는 ConversationView 변경을 "토글 공용 그리기 값만"으로 한정한다. 여기서 머리·필터 바탕을 맞추는 것은 그 범위를 넘는다. TodoDrawerView 안에 바탕 사본을 만들거나 선 알파를 조절하면 바탕 소유자·공용 색 계약을 우회하므로 하지 않았다.
- [권고] 계획 담당이 **ConversationView.draw의 칸 제목·필터 띠 바탕과 선 소유 정리까지** 영향 범위를 명시적으로 넓혀, 비교 대상 채팅 머리와 같은 바탕에서 primary(0.1)를 한 번씩 그리도록 설계를 보완한다. 칸 본문 바탕은 기존 방 목록 톤을 유지하고 토글·카드 계약은 유지할 수 있다. 이 방법은 픽셀 기대값을 그대로 지킬 수 있다.
- [대안/계획 담당 판단] 의도가 "같은 그리기 색"이고 다른 바탕 합성을 허용하는 것이라면 AT-DI-35의 관측 대상을 선 그리기 값/동일 바탕 렌더로 재정의해야 한다. 구현자는 기대값·오차·표본 위치를 임의 변경하지 않았다.
- 최초 제목 선 중복은 구현 오류로 제거했다. 남은 바탕/허용 범위 충돌은 위 근거로 보고하며, 원인 분류·설계 변경 최종 판단은 계획 담당에게 남긴다.

### 남은 작업

- 계획 담당이 R-DI-I5를 처분하고 범위 또는 관측 계약을 재인계한다. 현재 5개 파일을 보존한 채 이어가야 한다. 재인계 후 AT-DI-35~39·회귀·전체 시험, 정적 검사, 어둡게·밝게 스크롤 전후 사진과 자기 경로 git commit --only가 남았다.
- 새 통신·저장 계약, 권한, 플래그, 임시 제품 경로는 추가하지 않았다. 운영 공항·실제 메시지·설치·버전 올림·공개는 하지 않았다.

## TASK-02 보완 1 · 2026-11-23 · 보류(2절 보고: R-DI-I6)

### 받은 지시·기준·변경

- [확인] 판정 7회와 수락 시험 9판을 읽었다. 이전 R-DI-I5는 계획 담당이 수락 시험 오류로 분류하고 비교 기준을 방 목록 선으로 정정했다. 제품 바탕을 바꾸자는 이전 권고는 적용하지 않았다.
- 지정 기준 `3e8160e381ace9f7f52c742207917572cb30c1c4`를 기존 5개 미커밋 파일을 둔 채 merge했다. 종료 0, 충돌 없이 fast-forward. 병합 전 patch와 병합 직후 patch를 직접 대조해 5개 파일이 바이트 그대로임을 확인했다.
- 추가 수정은 `app/Tests/DrawerHeaderTests.swift`의 AT-DI-35 선 비교뿐이다. 제목 y43.5는 방 목록 가운데 x=S/2,y43.5, 필터 y87.5는 방 목록 경계 x=S−0.5,y200과 비교한다(차이 합 ≤6/255). 두 선 모두 같은 x의 바로 아래4pt 바탕과 차이 합 >6/255도 단언한다. 제품 파일·DrawerInlineTests·다른 기대값은 그대로다.
- 보존본: `.build/drawer-inline-evidence/task-02-before-supplement-1.patch`, 파일 지문 `task-02-supplement-1-preserved.json`. 현재 변경본: `task-02-supplement-1-candidate.patch`.
- 현재 HEAD는 지정 기준이며 변경 파일은 이전과 같은 5개다(Sources의 TodoDrawerView·ConversationChrome·ConversationView, Tests의 DrawerHeaderTests·DrawerInlineTests). 제품 커밋·푸시 없음. 위험도 일반 유지.

### 실제 검증

대상은 기준 3e8160e + 위 5개 미커밋 파일이다. 로그 경로는 구현 worktree 루트 `.build/drawer-inline-evidence/` 기준이다.

| 명령·관측 | 실제 결과 | 증거 |
|---|---|---|
| `git merge 3e8160e381ace9f7f52c742207917572cb30c1c4` | 종료 0, 충돌 없는 fast-forward | Git 기준, 보존 patch 대조 |
| `HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh` | **종료 1**, 밝은 테마 AT-DI-35 제목 선 가시성 단언에서 실패. 빌드·서명, 기존 AT-TD·AT-DC, AT-DI-01~14·20~23·31·33·34 통과 | **`task-02-supplement-1-app-tests.log`**, `task-02-supplement-1-app-tests.exit` |
| 어두운 AT-DI-35 두 선 비교·가시성 | 참조 차이 각각 0.0, 바탕 차이 각각 0.3719202·0.5578539, 모두 통과 | 같은 전체 로그의 line samples |
| 어두운 AT-DI-36·38 | 제목·접기·트랙 창 좌표 불변, 첫 카드 위 이동, 선택 채움·트랙 색·흰 글자 통과(그 다음 밝은 테마로 진행) | 같은 시험의 반복 순서·단언, 전후 사진 |
| 밝은 AT-DI-35 위치·제목 선 참조 비교 | 위치 통과, 제목 선↔방 목록 머리 선 차이0.0. 바로 아래 바탕과 RGB 차이는0.0이라 가시성 실패 | 같은 전체 로그 |
| `git diff --check` | 종료 0 | `task-02-supplement-1-diff-check.log` |
| 임시 홈·가짜 명부 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 기존 문서4건 | `task-02-supplement-1-private-scan.log` |
| 개인값 지적과 기준 해당 줄 지문 대조 | 드라이버 종료 0, 기존과 동일4건·새 지적0 | `task-02-supplement-1-private-baseline.log` |
| 제품 및 기존 시험 내용 보존·시험 이후 patch 대조 | 종료 0, 추가 변경은 위 선 비교뿐, 시험한 코드와 현재 동일 | `task-02-supplement-1-scope.log`, `task-02-supplement-1-candidate.patch` |

개인값 기존4건은 선행 HEJO-DEADLINE-CLOSE impl-report.md 97·109줄, verdict.md 127·146줄이다. 해당 문서·검사 예외는 변경하지 않았다. 전체 종료 시 설정·다운로드 보호 검사 모두 UNCHANGED였다.

### R-DI-I6: 밝은 투명 비트맵의 검정 선 가시성을 RGB만으로 재면 0

- [확인] 실패는 `AT-DI-35 band separator is visible light y=43.5`다. 선↔참조 비교 실패가 아니라 새 가시성 단언에서 멈췄다. 지시의 "다른 꼴의 실패는 고치지 말고 멈춤"에 따라 제품이나 관측 코드를 추가 변경하지 않았다.
- [확인] `DrawerHeaderTests.bitmap(view)`는 ConversationView 자체를 투명 비트맵으로 캡처한다. 그 부모의 유리·바탕은 이 비트맵에 포함되지 않는다. 밝은 테마 선·바탕은 모두 검정 RGB(0,0,0)이며 알파만 다르다.
- 원본 PNG를 venv Pillow로 독립 확인했다(종료0): 제목 선 RGBA=(0,0,0,22), 아래4pt 바탕=(0,0,0,5), 방 목록 제목 선=(0,0,0,22). 필터 선=(0,0,0,27), 아래 바탕=(0,0,0,5), 방 목록 경계=(0,0,0,27). 따라서 참조 색은 정확히 같지만 RGB 가시성 차이는 둘 다0이다. `task-02-supplement-1-light-pixels.json`에 원본 표본을 보존했다.
- [확인] 같은 원본을 흰 바탕에 합성한 열람용 사본에서는 선이 구분된다. 원본 PNG는 바꾸지 않았고 시험 기대값으로 사본을 사용하지 않았다. 이것을 실제 화면 확인으로 과장하지 않는다.
- 원인에 대한 구현자 확인: 밝은 투명 비트맵의 **측정 조립 문제**다. 제품 선 색을 밝게 바꾸거나 허용 오차를 완화해서는 안 된다. 원인 분류·관측 보완 승인 최종 판단은 계획 담당 소관이다.
- [권고] RGB 기대값·표본 좌표를 유지하고, 실제 부모 유리·바탕까지 포함한 native PetView/대화 부모 비트맵을 측정하게 보완한다(기존 AT-DI-20의 부모 캡처 방식 참고). 좌표는 현재 칸/대화 좌표에서 그 부모로 변환한다. 실제 표시되는 합성 색을 재면 RGB 가시성 조건의 의미를 보존할 수 있다.
- [대안/계획 담당 판단] 투명 원본을 계속 재려면 RGBA 차이로 가시성을 정의하거나 기준 바탕에 합성한 뒤 RGB를 재도록 수락 시험 관측 방법을 명시해야 한다. 이번에는 선 비교만 바꾸라는 범위를 넘기지 않았다.

### 사진·남은 작업

- 새 사진: `header-before-dark.png`, `header-after-dark.png`, `header-before-light.png`. 앱 증거 폴더에서 루트 증거 폴더로 복사했다. 밝은 원본의 열람용 흰 바탕 사본 `header-before-light-on-white.png`도 추가했다. 어두운 스크롤 후 사진과 밝은 열람용 사본을 직접 열어 제목·필터 고정 배치와 선을 확인했다.
- 밝은 스크롤 후 사진, 밝은 AT-DI-36·38, 두 테마 뒤 실행되는 AT-DI-37·되돌리기 바닥 줄 AT-DI-36·AT-DI-39는 미실행이다. 뒤 회귀·네트워크 fixture도 이번 실행에서는 미실행이다. TASK-02 전체 증거 수준2 완료로 보고하지 않는다.
- 계획 담당이 R-DI-I6의 측정 조립 보완을 명시해 재인계해야 한다. 이후 남은 수락 시험·전체 종료0·정적 검사·사진·자기 경로 git commit --only가 남았다. 현재 5개 미커밋 변경을 유지한다.
- 확인 시점 main은 `2cffac313cf006d6965e3617be19bc216be8b04f`로 지정 기준보다 앞섰다. 다음 인계는 새 병합 기준도 명시해야 한다. 이번에는 지정한 3e8160e만 병합했다.
- 운영 공항·실제 메시지·설치·버전 올림·공개는 수행하지 않았다.

## TASK-02 보완 2 · 2026-11-23 · 구현·자체 시험 완료(독립 검토 대기)

### 기준·보존·커밋

- [확인] 판정 8회와 수락 시험 10판을 읽었다. R-DI-I6는 계획 담당이 수락 시험 오류로 분류하고 픽셀 차이를 RGBA 네 성분으로 정정했다. 제품 코드 변경은 허용되지 않았다.
- 기존 미커밋 5개 파일을 `task-02-before-supplement-2.patch`와 파일 지문 `task-02-supplement-2-preserved.json`으로 보존한 뒤 지정 기준 `c5170dab71c160d7e90b6b7e383e51ddb690af94`를 merge했다. 종료 0, 충돌 없는 fast-forward. 병합 전후 patch 대조로 모든 파일이 동일함을 확인했다. 기준 사이 app 변경은 없었다.
- 이번 보완은 `app/Tests/DrawerHeaderTests.swift:48`의 delta 함수에 알파 차이 항을 더한 **한 줄**이다. 다른 4개 파일과 흰 글자 판정·기대 수치·표본 좌표는 지문 대조로 동일함을 확인했다. 제품 바탕·선·토글 코드는 추가 변경하지 않았다.
- TASK-02 커밋: **`e36c8a77c5fdedec7f8b7394ae0d55913d5502ee`**, 브랜치 `role-workflow/17-96051e66`. `git commit --only`로 자기 경로 5개만 커밋했다: Sources의 TodoDrawerView·ConversationChrome·ConversationView, Tests의 DrawerHeaderTests·DrawerInlineTests. 구현 worktree는 깨끗하다. 푸시하지 않았다.
- 변경 구조는 위 TASK-02 절과 같다. 고정 제목44·필터44, 카드만 스크롤, 기존 고정 되돌리기 바닥 줄, 공용 ComposerModeTrack·ComposerButton 토글이다. 옛 스택 머리·필터 글자 경로는 제거했다. 설계와 다른 제품 구조·임시 제품 코드·새 설정·통신·저장 계약은 없다.

### 최종 자체 검증

대상 변경본은 기준 c5170da + 위 5개 파일이다. 시험 시작 시의 `task-02-supplement-2-candidate.patch`와 커밋 직전 전체 diff가 동일함을 확인하고 그대로 커밋했다. 로그는 구현 worktree 루트 `.build/drawer-inline-evidence/` 기준이다.

| 명령·관측 | 실제 결과 | 증거 |
|---|---|---|
| **`HEJO_PYTHON=<gateway venv python> bash app/scripts/test.sh`** | **종료 0**. 빌드·서명, AT-DI-35~39, 기존 AT-TD·AT-DC·AT-DI와 전체 앱 회귀, 모든 네트워크 fixture·hook 시험9개 통과 | **`task-02-supplement-2-app-tests.log`**, `task-02-supplement-2-app-tests.exit` |
| AT-DI-35 선 비교·가시성 | 두 테마·두 선 모두 참조 RGBA 차이0. 어두운 바탕 차이0.4032927·0.6088343, 밝은 바탕 차이0.0666667·0.0862745(모두6/255 초과) | 같은 로그의 line samples |
| AT-DI-36 | 두 테마에서 스크롤 전후 제목·접기·트랙 창 좌표 불변, 첫 카드 위 이동. 실제 마감 닫기 후 되돌리기 바닥 줄도 스크롤 전후 불변 | `AT-DI-35..39 FIXED HEADER AND FILTER TOGGLE PASS`, 시험 코드의 고정 좌표 단언 |
| AT-DI-37 | 마감 지원 시4칸·미지원 시3칸, 개수·균등 폭·실제 클릭의 controller.drawerFilter/카드 종류·chosen/접근성 선택 상태 통과 | 같은 묶음 |
| AT-DI-38·39 | 두 테마 공용 토글의 선택 채움·트랙 RGBA·흰 글자, 중간 표시 폭145에서 트랙262 유지·경계 잘림 통과 | 같은 묶음 |
| `git diff --check` | 종료 0 | `task-02-supplement-2-diff-check.log` |
| 임시 홈·가짜 명부의 `scripts/scan_private.py --home <임시 홈>` | 종료 1, 선행 문서의 기존 지적4건 | `task-02-supplement-2-private-scan.log` |
| 위 지적과 기준 커밋 해당 줄 지문 대조 | 드라이버 종료 0, 기존과 동일4건·새 지적0 | `task-02-supplement-2-private-baseline.log` |
| 보존 파일·추가 수정 범위 대조 | 종료 0, delta 알파 항 하나 외 변경 없음 | `task-02-supplement-2-scope.log` |
| 최종 시험 이후 patch 대조·자기 경로 커밋 | 각각 종료 0, 시험 변경본 그대로5경로 커밋 | `task-02-supplement-2-candidate.patch`, Git 이력 |

개인값 기존4건은 HEJO-DEADLINE-CLOSE impl-report.md 97·109줄, verdict.md 127·146줄이다. 해당 문서·검사 예외는 변경하지 않았다. 최종 로그의 설정·다운로드 보호 검사 둘 다 UNCHANGED를 확인했다. 기존 Swift 경고·WebKit 환경 메시지가 있지만 종료 결과는0이다.

필요/도달 증거 수준은 **2(임시 저장소·가짜 명부와 실제 native UI의 대역 통합)**다. 실제 운영 메시지를 쓰지 않았다. 별도 mutation check는 미실행이며, 독립 고정 좌표·개수와 실제 클릭/스크롤·그려진 픽셀 비교로 보호 계약을 관측했다. 자체 점검이며 최종 검증 판정은 아니다.

### 화면·인계

- 네 원본 사진: `header-before-dark.png`, `header-after-dark.png`, `header-before-light.png`, `header-after-light.png`. 모두 이번 실행에서 생성해 루트 증거 폴더로 복사했다. 이전 사진은 `task-02-supplement-1-header-*.png` 이름으로 보존했다.
- 밝은 투명 PNG는 검정 배경 뷰어에서 글자가 안 보일 수 있어 원본을 유지하고 흰 바탕의 열람용 사본 `header-before-light-on-white.png`, `header-after-light-on-white.png`를 만들었다. 측정은 투명 원본으로 했다. 구현자는 어두운 전후 원본과 밝은 전후 열람용 사본을 모두 직접 열어 머리·필터 고정과 카드 이동을 확인했다. 사람의 실제 앱 확인과 구분한다.
- 도달 증거: 수준2 + 요청한 어둡게·밝게 스크롤 전후 사진. 남은 것은 독립 설계·코드 검토, 최종 main 반영 및 사용자 단계다. 작업 문서 상태·최종 판정은 검증 담당이 갱신한다.
- 확인 시점 main은 `de5f54c95475b7599f980ad5d3e2f46b7ee12e7b`로 앞서 있다. c5170da..이 main의 app 변경은 없지만 대상 커밋에는 새 main이 아직 포함되지 않는다. 계획 담당은 최종 반영/푸시 대상 확정 전에 최신 로컬 main·원격 추적 tip 포함 요건을 확인하고 필요한 보완을 지시한다. 이번에는 지정한 c5170da만 병합했다.
- 사용자 인계 조건: TASK-02 검증 후 main 병합이 끝나면 공개 담당 세션에 "공개 가능"·병합 해시·공개 노트 한 줄을 전달해야 한다. TASK-02 외 다른 앱 변경을 포함하려면 먼저 그 담당에 범위를 알려야 한다. 이번 지정 기준 병합에는 다른 앱 변경이 없었다. 이 후속 전달은 호스트가 담당하는 검증·반영 인계에 남긴다.
- 운영 공항·실제 메시지·설치·버전 올림·공개는 수행하지 않았다.
