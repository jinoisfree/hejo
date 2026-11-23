# 계획 검토 기록

## 1회 — 2026-11-23
- 대상: v1, planHash `f45fcd319ecf93c711aa8a2fad2c834e340fff2d8886521d0cd9e28b8b0e6b00`.
- 호스트 전달 판정: APPROVED, 권고 4건. 이는 제품 검증이나 구현 승인이 아니다.
- 계획 담당 처리: 아래와 같이 v2 수정. 이전 계획 통과/승인은 v2에 재사용하지 않으며 호스트의 재검토 대상이다.

| 지적 | 처리 | 이유와 반영 |
|---|---|---|
| R1 기준 브랜치를 첫 계획에서 사용자에게 질문 | 보류(질문 시점), 기준 불일치 사실 수용 | 설치 빌드·진행 작업·통합 영향을 확인하지 않은 채 두 브랜치 중 하나를 고르게 하면 불완전한 선택이다. TASK-00을 읽기 조사/격리 계측만 하는 필수 반환 단계로 명확히 하고, 기준 확정 전 제품 변경을 차단했다. 비교 결과를 바탕으로 계획 담당이 구체적인 기준을 제안한다. |
| R2 성능 측정 도구 재사용 여부 명시 | 수용 | 현재 HEAD에는 성능 시험 파일이 없고 성능 커밋에 존재함을 git ls-tree로 재확인했다. design/tasks에 기준 결정과 하네스 재사용 의존 조사·이관 범위를 묶고, 무단 제품 코드 이관과 fixture 재생성을 금지했다. |
| R3 공백 초안 버튼 기대값 모호 | 수용 | refresh의 trimmed 조건과 textDidChange의 raw 조건이 다르다. sendCurrent도 공백/줄바꿈 제거 뒤 빈 본문·첨부 없음이면 반환한다. spec AC-02와 AT-HT-02에 refresh 기준의 단일 버튼 조건을 명시하고, 버튼 불일치 수정이라는 의미 변경임을 기록했다. |
| R4 방 종류별 기준 실패 기대 구분 | 수용 | 홈 조건에서만 refresh를 부른다. AT-HT-01은 홈의 기준 실패와 직접방/단체방의 기존 통과를 구별하며 TASK-00에서 방별 지연·다른 병목을 따로 보고한다. |

## 직접 대조한 근거
- 기준 HEAD의 ConversationView.swift:677, 886–894 및 ConversationController.swift:550–560 읽기.
- git branch --contains 221e84082a4230caca6b450cb3b2e0ee9d085ee8: role-workflow/20-60f149af.
- git show 해당 커밋의 ConversationView.swift:893에도 홈 refresh 호출이 남아 있다. 버튼 조건 불일치도 680/894행에 존재한다.
- git ls-tree의 app/Tests 목록: 성능 커밋에는 HejoPerfTests.swift, HejoPerfRegressionTests.swift, hejo_perf.py, Fixtures/HejoPerf가 있고 HEAD에는 perf 이름 파일 없음(필터 종료 1).
- 제품 변경·빌드·앱 시험·성능 계측은 미실행. 수정은 이 작업 문서와 수락 시험 명세에 한정한다. 다른 작업의 미추적 gate/telegram_comments.py는 수정하지 않았다.

## 후속 검토
2회(v2) 검토 결과와 문서 경로 안내의 원본은 [호스트 지정 검토 기록](../26405dfc-f5c9-4243-ab07-fa756b3c00bb/plan-review.md)이다.
