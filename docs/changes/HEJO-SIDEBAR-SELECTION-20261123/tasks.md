# 작업과 증거

- TASK-01 완료(impl-report.md): 가짜 자료의 실제 AppKit 창에서 좁음→확장·드래그·재전환을 재현하고 크기/clip/합성 근거 확보. REQ-HSS-01·02.
- TASK-02 완료(impl-report.md): 기존 셀의 배경/전경 순서와 확인된 크기 갱신 원인 수정. ConversationChrome.swift, 필요시 ConversationView.swift·SidebarMotion.swift. REQ-HSS-01·02.
- TASK-03 완료(impl-report.md, 자체 점검): SidebarTests.swift에 의미 있는 렌더링·전환 회귀 검사 보강, 수락 절차 실행, 앱 시험/빌드·개인값 검사, impl-report.md 작성. REQ-HSS-01~03.
- TASK-04 완료([verdict.md](verdict.md)): 대상 커밋 코드·실행 증거 검토 및 관련 수락 시험 직접 통과. 단일 모델 검증, 차단 지적 없음. [현재 명세](../../spec/current/hejo-sidebar.md)에 반영. 원본 패치 검토 완료. 공개 이력 통합 및 자체 점검은 [integration-report.md](integration-report.md) 참조. 새 대상의 화면 푸시 승인은 대기.

병렬 갈래: 없음(독립 갈래 3개 미만, 동일 셀과 전환 레이아웃을 순차 조사·수정·검증).
