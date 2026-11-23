# 공개 이력 통합 기록

## 범위와 결과

사용자의 직접 진행 승인에 따라 원격 `github/main`의 `740f5be61f0f9826eae991039992fb17a57788f2`에서 별도 작업 공간을 만들고 이번 구현·검토 커밋 두 개만 cherry-pick했다. 충돌 없이 적용됐으며 제품 코드의 추가 수정은 없다. 기존 개발 이력 전체를 공개 이력으로 보내지 않는다.

| 기존 커밋 | 통합 커밋 | stable patch-id 비교 |
|---|---|---|
| `2240e44881274077bca3a2ffe636a597fb1a4a42` | `c569609b6f2638fb11c4257c0e849e262cbf5aa7` | 동일 |
| `236b0177468b90d9ea23a1b1190e996db78a0694` | `aa346db974e1645b18569ebe62654ce709356a84` | 동일 |

`integration-preservation.json`에서 두 패치의 동일성과 변경 파일 범위를 확인했다. ConversationView 변경은 SidebarRowView delegate 3줄뿐이다. 원격의 성능 개선·fixture·시험 코드 등 이번 작업 밖의 추적 파일은 기준 원격과 동일하다. 통합본은 기준 원격의 후손이므로 기존 이력 분기는 승인 대상에서 제거됐다.

## 통합본 자체 점검

검사 대상 제품·시험 변경본은 `aa346db974e1645b18569ebe62654ce709356a84`. 아래 증거 경로는 저장소의 `.build/sidebar-selection/` 기준이다. 임시 HERMES_HOME과 가짜 자료를 사용했다.

| 실행 | 결과 | 증거 |
|---|---|---|
| HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh | 종료 0, BUILD_OK | build.log |
| python3 .build/sidebar-selection/compile-tests.py | 종료 0, HEJO_PERF_TESTING 포함 | tests-build.log |
| python3 .build/sidebar-selection/compile.py | 종료 0 | probe-build.log |
| .build/sidebar-selection/app-tests --task38 | 종료 0, HSS/AT-HF-89/APP_TEST_OK | sidebar-tests.log |
| .build/sidebar-selection/app-tests --hejo-perf-regression app/.build/hejo.app/Contents/Resources/Pet | 종료 0, AT-HP-01_02_03_VIEW_REGRESSION_PASS, AT-FF-AC04 UPDATE_CONTENT_EQUIVALENCE PASS | perf-regression.log |
| .build/sidebar-selection/probe .build/sidebar-selection/final | 종료 0, PROBE_DONE | final-probe.log |

실제 AppKit 창의 final/expanded.png와 final/photo-badges-light.png, final/photo-badges-dark.png를 직접 확인했다. 선택 배경의 네 모서리가 온전히 보이고 사진·방 이름·핀·음소거·숫자 배지가 전경에 표시된다. 창 픽셀 수락 시험도 통과했다. 기존 검토 증거는 original-reviewed-evidence/에 구분해 보존했다.

기존 [최종 판정](verdict.md)의 단일 모델 검증은 원본 패치에 대한 판정으로 유지한다. 이번 통합 확인은 구현 담당의 **자체 점검**이며 새로운 독립 검토로 표시하지 않는다. 고의 변형 시험·전체 서버 시험·운영 설치는 반복하지 않았다. 성능 회귀는 동작 보존 검사이며 성능 수치 재측정은 아니다.

## 전달

통합 코드와 관련 검사는 통과했다. 문서 포함 개인값 검사 및 공백 검사의 최종 결과는 private-scan.log와 diff-check.log에 남긴다. 원격 쓰기·설치는 수행하지 않았다. 최종 문서 커밋을 포함한 새 전체 해시를 화면 승인 대상으로 제시하며, 기존 대상에 대한 승인을 새 대상 승인으로 재사용하지 않는다.
