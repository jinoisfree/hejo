# HEJO-DRAWER-INLINE TASK-01 구현 인계

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
