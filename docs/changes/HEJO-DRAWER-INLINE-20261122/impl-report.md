# HEJO-DRAWER-INLINE TASK-01 구현 인계

> 최신 상태는 아래 **보완 2** 절이다. 앞 절의 보류·충돌 기록은 각 회차 이력으로 보존한다.

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
