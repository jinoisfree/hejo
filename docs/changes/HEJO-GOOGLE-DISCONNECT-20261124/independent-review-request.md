# 독립 최종 검토 요청 — checkpoint-08

호스트 배정 대상: 구현에 참여하지 않은 다른 모델이며 설계에도 참여하지 않은 리뷰 세션. 구현자의 자체 보고나 기획자의 추가 자기 검토로 대체하지 않는다. 30-verification 2·4.2·5.2 적용. 배정이 불가능하면 같은 구현 루프로 보내지 말고 사용자에게 역할 배정 결정을 요청한다.

## 입력과 고정 대상

canonical spec/design7판/tasks/handoff/impl-report/workspace-command-map, 수락 명세 `tests/acceptance/HEJO-GOOGLE-DISCONNECT.md`, UUID 폴더 verdict를 읽는다. 실제 대상은 원래 폴더 아래 `.build/google-disconnect-work/hejo` 및 `team`이다. 기준 HEAD는 각각 `236b0177468b90d9ea23a1b1190e996db78a0694`, `4bbc16ddba02236fe4645ab7244603c44a78af91`; 미커밋93파일 지문은 `.build/google-disconnect-evidence/source-checkpoint-08.log`. 읽기 시작/종료 시 지문을 확인한다. 요약만 보고 판정하지 않는다.

## 확인 범위

1. 금고 연결·토큰·OAuth 생산자부터 SDK/공식 도구/메일·Calendar·Workspace·worker·undo 소비자까지 직원/home/binding 경계. 해제 직후 이메일·자격 제거, null/손상/구버전 fallback 거절, 타 직원 보존, 늦은 인증·refresh·대기 승인 경쟁.
2. 공식 도구 등록·권한·파일 선택·승인 경계와 스킬 조립. sandbox/본체 우회나 두 번째 인증 원본 유무. 명령24개 대응과 실제 소비자 누락.
3. gate/AppKit forget capability·소유 세션 status/cancel·취소/만료 및 구앱 거절. UI 원본 단언과 유한 대기 적절성.
4. 실제 release/install/team deploy/plugin-store 검사기 탐색·지원 선언·failed/uninstalled 예외·mutex·overlay/링크/영수증 복구. 실패를 조용히 통과시키는 경로 유무.
5. AC16개의 시험 독립성·mutation4개·안전한 관련 team 회귀 범위 충분성. 성공한 전체 검사를 무조건 반복하지 말고 결함 의심 경계만 임시 홈/가짜 명부에서 직접 실행한다. 운영 자격·본체·ddots·외부 메시지·실계정 OAuth·보안 창 조작 금지.

최신 증거: review-09-integrity.json, finish-ui-resume-results.json 및 실제 로그, finish-private-hejo/canonical 로그. 이전 Python522/team156·관련82/배포124/빌드·mutation 증거의 명령·제한은 impl-report에 있다. 초기 실패를 최신 성공으로 지우거나 별도 함수 실행을 단일 전체 실행으로 바꾸지 않는다.

## 산출물과 이후 단계

`independent-review.md`에 실제 모델/세션의 비참여 조건, 검토 파일/지문, 별도 설계 적합성, 실행 명령·종료 코드·로그, 지적별 위치·근거·AC·등급, 미검증 범위를 남긴다. 제품 코드는 고치지 않는다. 호스트 리뷰 역할이 파일 쓰기를 금지하면 구조화된 리뷰를 반환하고 기획자가 출처를 보존해 기록한다. 미해결 지적은 기획 검토로 반환한다. 통과해도 GD-T19 운영/실계정 증거와 푸시 승인은 별개다.
