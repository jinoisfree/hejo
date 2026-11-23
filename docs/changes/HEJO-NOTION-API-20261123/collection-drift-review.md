# TASK-04C-R1 — 수집 차이5파일 검토

읽기 조사·자체 점검. [세 기준 해시와 구문 확인](logs/collection-drift-review/evidence.json) 종료0. 지정5파일만 격리 기준→현재 수집→설치 수락 후보 순으로 직접 비교했다. 관측 이후 해시 변동은 없었다. 변경 주체/실행 시점은 이 조사로 확정하지 않는다.

| 파일 | 수집 원본의 의미 | 수락 후보의 보존/대체 |
|---|---|---|
| lib/hermes_facility/app_connect.py | 빈 범위 선택 안내, 기존 grant의 원격 연결, Notion checkpoint 지연 및 기존 선택 누락 시 보존 | 해당 보호를 유지하고 신규 connect 진입·안전 오류 매핑·응답 크기 제한을 추가 |
| lib/hermes_packs/mac_apps/app_catalog.json | Notion의 local_install_required=false | 같은 값을 유지하며 표시 이름 추가 |
| lib/hermes_packs/mac_apps/catalog.py | 기존 grant용 remote_app metadata | API 신규 연결에도 사용하도록 일반화. 기본 로컬 설치 요구는 유지하고 이름/group 및 중복 키 구성을 정리 |
| lib/hermes_packs/mac_apps/discovery.py | 기존 원격 grant를 app_missing 상태로 유지하며 설정/진행을 표시 | 원격 후보를 주 목록에 넣고 connection_key로 중복 제거. 기존 연결은 공통 연결 목록 경로에서 처리. 옛 app_missing 우회를 병합해 되살리지 않음 |
| __init__.py | hejo pre_llm_call의 bound_hook_ids·소유자 메시지 문맥 보완 | _pre_llm_call/_pre_llm_context의 AST가 수락 후보와 동일함을 직접 확인. 수락 후보 차이는 Notion register_budget 호출 추가 |

이번5파일에서는 수락 후보와 충돌하는 별도 기능 변경을 발견하지 못했다. 기존 변경의 의도는 보존되거나 수락된 원격 서비스 경로로 대체되어 있다. 따라서 해당5파일의 새 합성 패치를 만들기보다 기존 수락 후보 전체를 격리 대상에 반영하는 것이 적절하다. 이는 다른 파일·다른 작업의 보존 검증이나 운영 checkout 덮어쓰기 허가가 아니다.

## 구체 반영 제안

기존 외부 격리 worktree에서만 logs/collection-plan/code-plan.json의13파일을 검증된 sync --code-plan 경로로 반영한다. source/target 해시·모드·링크를 실행 직전 전부 재확인하고 불일치 시 중단한다. 현재 변경 중인 수집 원본 checkout에는 쓰지 않는다. 운영 서비스나 설치 원본에는 쓰지 않는다. 전체 sync·prepare/publish를 실행하지 않는다.

추가 수락 시험5개는 test-preservation.json에 지정한 hejo 개발 worktree의 evidence/accepted-tests/*.py.txt 목적지에 원본 바이트와 해시로 보존한다. 목적지가 존재하면 덮어쓰지 않는다. 시험 실행은 기존 격리 kit 구조를 유지하며 공개 manifest에는 추가하지 않는다. 그 뒤 대상 코드와 기존 수락 후보의 일치·비대상 변경 목록·Git index 보존을 확인한다. 제품 바이트가 같으면 기존90/474시험을 무조건 반복하지 않고 반영된 경로의 import/대표 통합과 필요한 검증을 수행한다.

기존 사용자 진행 승인은 외부 격리의 수집기/설치기7파일 구현과 가짜 시험 범위였다. 이번 실제 코드13파일 수집 및 지정 hejo worktree의 증거5파일 생성은 추가 쓰기 범위이므로 구체 범위를 제시한 뒤 승인받는다. 커밋·푸시·운영 수집·공개 checkout·서비스 변경은 제안에 포함하지 않는다. 고위험 독립 최종 검토와 실제 공개 배포·Git은 여전히 남는다.
