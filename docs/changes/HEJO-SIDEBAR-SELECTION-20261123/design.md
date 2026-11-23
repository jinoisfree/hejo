# 설계 v1

칸 배치는 [spec.md](spec.md) 첫 절, 근간은 [ARCHITECTURE](../../ARCHITECTURE.md).

## 확인한 현황
- ConversationChrome.swift EmployeeSidebarCell.init: 셀 backing layer에 selection CALayer를 추가한다. draw에서는 얼굴·방 이름·핀·음소거를 셀 자체에 그린다. 내용보다 상위 합성되는 배경 구조가 덮임 원인 후보다.
- 같은 셀 layout: 선택 영역은 bounds와 list 모드로 정한다. list의 높이는 bounds.height-6, 좌우 여백은 홈/일반방별로 다르다.
- ConversationView.setSidebarWidth → refresh → updateSidebarRows와 layout: 모드·행 높이·열 너비가 각각 갱신된다. SidebarMotion.update는 native 행 변경과 높이 애니메이션을 담당한다.
- SidebarTests의 AT89는 선택 opacity spring, 행 여백, native 행 애니메이션을 검사하지만 확장 과정의 최종 합성 색·배경 잘림을 직접 입증하지 않는다.
- 기존 계약: HEJO-FOUNDATION spec REQ-HF-36.AC-03의 움직임/재전환/동작 줄이기 유지.
- [미확인] 사용자 화면의 잘림은 실행 재현 전이다. 오래된 bounds·행 높이·clip 또는 전환 스냅샷이 원인인지 TASK-01에서 판별한다.

## 변경 방향
기존 AppKit 셀 안에서 배경과 내용의 책임을 분리해 배경 → 얼굴/이름/표식 → 배지 순서를 명확히 한다. foreground 전용 view/layer 또는 기존 row 배경을 사용하되 선택 표시 소유자는 하나만 둔다. 투명도를 낮추는 우회나 동일 배경을 두 번 그리는 방식은 쓰지 않는다. 접근성·마우스 이벤트는 기존 셀이 담당하고 장식은 입력을 가로채지 않는다.
너비 전환은 셀 실제 bounds·행 높이·선택 영역·상위 clip을 대조하여 낡은 영역이 남는 원래 레이아웃 책임에서 수정한다. 임의 지연 재그리기, 창 전체 reload, 전역 clipping 해제는 사용하지 않는다. 전환 페이드가 잘못된 스냅샷을 합성한다면 해당 전환 부분만 고치되 선택 spring 계약은 보존한다.

기존 경로 판정: SidebarLayout 자료/선택 상태/SidebarTone 색과 opacity/SidebarMotion 선택 spring은 유지. EmployeeSidebarCell의 배경과 전경 합성은 교체하며 이전 전경 그리기 경로 중 대체 부분은 동시에 제거. ConversationView의 레이아웃 갱신은 재현 근거가 있을 때만 국소 수정. 새 저장소·설정·외부 의존성 없음. SwiftUI 예외 없음.
대안: draw에서 배경을 먼저 직접 그리기. 단순하지만 기존 독립 opacity spring을 재구현해야 하므로 기본안으로 채택하지 않는다. 단순 zPosition 변경만으로 해결했다고 판단하지 말고 최종 렌더링으로 검증한다.
내부 UI 버그이므로 외부 사례 조사는 생략. 운영·보안·자료 변경이 없어 별도 고위험 검토 대상 아님. 계획 검증 설정은 호스트 선택을 따른다.
롤백: 이번 UI 변경 커밋만 되돌리며 다른 작업 변경·설정·자료는 보존한다.
