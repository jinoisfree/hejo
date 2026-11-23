# 구현 인계: HEJO-SIDEBAR-SELECTION-20261123

## 기준·역할·판단

- 받은 설계: [handoff.md](handoff.md), spec/design v1. base_commit `6bf9c3c6f6b9c563e3b4d44bf69d1014569579c0`.
- 위험도 일반. 필요 증거 수준 1·2·3. 연합개발로 시작했으나 구현 담당 생성이 중단되어 사용자가 “너가 직접 개발진행해”라고 지시했다. 최초 담당이 명시적 역할 변경 요청에 따라 직접 구현했다. 아래 검사는 **자체 점검**이며 독립·교차 모델 검증이 아니다.
- 구현자 판단: 구현 및 관련 자체 점검 완료, 독립 최종 검토 대기. 제품 설치·운영 연결·게이트웨이 재시작·푸시는 수행하지 않았다.

## 실제 원인·변경

[확인] 가짜 명부의 실제 AppKit 창에서 사용자 화면과 같은 아래쪽 잘림을 재현했다. 좁은 목록에서 생성된 셀이 확장 후에도 높이 72pt로 남았지만 실제 행과 visibleRect는 58pt였다. 선택 레이어 높이 66pt가 행 밖으로 넘어가 아래 모서리가 잘렸다. 기본 셀 autoresizingMask 지정만으로는 해결되지 않아 그 시도는 제거했다.

- `app/Sources/ConversationChrome.swift`: `SidebarRowView.layout`이 단일 열의 기존 EmployeeSidebarCell을 실제 행 bounds에 맞춘다. 최종 확장 셀은 212×58, 배경은 (26,3,176,52)다. 너비 변경도 같은 행 책임에서 처리한다.
- 같은 파일: 셀 backing layer에 직접 그리던 방 얼굴·이름·핀·음소거를 입력을 받지 않는 `SidebarRoomInk` 전경 뷰로 옮겼다. 기존 draw의 동일 전경 경로는 제거했다. 선택 배경 z=0, 전경 z=1, 제목·숫자 배지·신호 점 z=2로 순서를 정한다. 선택 opacity spring·색상·자료 원본은 유지한다.
- `app/Sources/ConversationView.swift`: 기존 NSTableView delegate가 SidebarRowView를 공급한다. 행의 native 위치/삽입·제거 애니메이션과 선택 상태는 기존 경로를 쓴다. 전체 reload나 지연 재그리기는 추가하지 않았다.
- `app/Tests/SidebarTests.swift`: 기존 AT89 실행에 선택 배경 geometry/합성 회귀 검사를 연결했다. 기존 수락 기준/시험 명세는 변경하지 않았다.

## 자체 점검·증거

아래 경로는 모두 저장소 기준, 로그·이미지·탐색 실행 파일은 추적하지 않는 `.build/sidebar-selection/`에 있다. 모든 앱 실행은 임시 HERMES_HOME 및 임시 LocalStore·가짜 명부를 사용했고 운영 연결 없이 수행했다.

| 검사 | 명령/방법 | 결과 | 로그 |
|---|---|---|---|
| 변경 전 재현 | 로컬 Probe.swift를 현재 base의 Sources로 컴파일하여 실제 NSWindow 실행 | 종료 0, 72pt 셀/58pt 행 불일치와 잘림 재현 | before.log, before/expanded.png |
| 수정 후 실제 창 | `.build/sidebar-selection/probe .build/sidebar-selection/final` | 종료 0, 68/180/212/300pt 및 전환 중/후 geometry 기록, 사진·배지 포함 밝음/어두움 캡처 | final-probe.log, final/*.png |
| 관련 앱 시험 | `.build/sidebar-selection/app-tests --task38` | 종료 0, HSS와 기존 AT89 및 APP_TEST_OK | sidebar-tests.log |
| 개인정보 패턴 검사 | `python3 scripts/scan_private.py` (임시 HERMES_HOME·가짜 명부) | 종료 0 | private-scan.log |
| 시험 빌드 | `python3 .build/sidebar-selection/compile-tests.py` | 종료 0 | tests-build.log |
| 앱 빌드·서명 검증 | `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh` | 종료 0, BUILD_OK | build.log |

도달 증거: 1(앱 빌드), 2(가짜 자료 회귀), 3(실제 AppKit 창 합성). 사용자 운영 창을 변경하거나 그 창에서 검증한 것은 아니다.

새 회귀 검사는 폭 68→212→180→300→68, 전환 중 역전, 동작 줄이기, 홈/일반방/DM·밝음/어두움·얼굴 1/2/4/6명·방 사진의 불투명 흰 픽셀, 접근성·입력 대상, 섹션/검색/스크롤 복귀를 점검한다. 기존 AT89는 선택 spring·행 이동·메뉴·표식 계약을 계속 검사한다. 실제 창 캡처에서 선택 상자의 네 모서리, 흰 사진, 숫자 배지·핀·음소거의 앞뒤 순서를 직접 확인했다.

## 회귀 시험의 고장 검출 확인

- 새 geometry 검사를 기준 커밋의 제품 소스에 연결해 실행했다. 종료 1, `HSS cell follows native row height after width change`에서 예상대로 실패했다(`baseline-regression.log`).
- 실제 창의 흰 사진 중심 픽셀은 변경 전 RGB 약 (0.8321, 0.9165, 1.0), 변경 후 (1.0, 1.0, 1.0)였다(`pixels.log`, baseline-capture/photo-badges-dark.png, final/photo-badges-dark.png).
- 초기 NSView.cacheDisplay 기반 픽셀 시험은 의도적으로 전경 z를 뒤로 내린 변형을 놓쳤다. 최종 시험은 실제 가짜 자료 창 하나만 캡처해 합성된 픽셀을 검사하도록 보강했다. 제품 코드는 이 과정에서 변경하지 않았다.
- 보강한 최종 시험은 정상 제품에서 종료 0으로 통과하고, 격리된 소스 사본에서 전경 z를 -1로 바꾼 변형에서는 종료 1, `HSS opaque face stays white above selected background`로 실패했다(`composite-mutation.log`). 변형은 작업 트리 제품 코드에 적용하지 않았다.

## 남은 검토·범위

설계와 다른 외부 계약/저장 형식 변경 없음. 새 전경 뷰는 합성 책임 분리를 위한 것으로 데이터 원본을 추가하지 않는다. 임시 우회·이중 그리기 경로 없음. 다른 작업의 gate 변경과 미추적 문서는 보존했다.

최종 검토에서는 행을 재사용할 때 bounds 동기화와 전경/배지의 z 순서, 실제 캡처 및 자체 점검 로그를 대조해야 한다. 전체 서버 시험은 UI 범위 밖이라 실행하지 않았다. 구현 참여 대화가 독립 검증 완료를 선언하지 않는다. 현재 명세 반영과 verdict는 별도 검증 이후 작업이다.

## 검토 대상

브랜치 `main`, 이 보고서와 함께 커밋된 app/Sources/ConversationChrome.swift·ConversationView.swift 및 app/Tests/SidebarTests.swift. 전체 커밋 해시는 응답 인계 블록에 기록한다. 로그는 위 변경본을 빌드한 결과이며 제품 코드 검사 후 추가 제품 변경 없음. 문서/시험 수락 기준을 낮추거나 실패를 skip하지 않았다.
