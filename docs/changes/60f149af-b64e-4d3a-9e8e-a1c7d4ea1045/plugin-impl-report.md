# 플러그인 구현 보고: 공개 스냅샷 푸시 지원

## 현재 반환: P4 로컬 운영 적용 성공 — 두 저장소 공개 승인 대기

handoff 마지막 'P4 prepared 기록 분류 후 재개'와 verdict 12회의 조건을 적용했다. 기존 6개 미참조 prepared 기록의 바이트/해시·approvedAt=null·claim 없음·대상 시작/종료/종료코드 없음·일반 형식·참조 부재를 적용 직전에 재확인했다. 기록을 삭제·취소·편집하지 않고 그대로 백업한 뒤 로컬 적용했다. **원격 쓰기·승인 execute RPC·버튼 대행·데몬 재시작은 하지 않았다.**

### 적용·복구 준비와 실제 운영 확인

- 기존 활성 운영 clone에 `git merge --ff-only 6beb8a090e568d61ac936677442cb47cb4203ef2`를 실행했다. 종료 0, 운영 `main`은 검토된 전체 커밋이며 tree `5b673264fdcdbe0e23bd495956973e46e1a13aba`, 깨끗한 상태다. 개발 worktree를 운영 경로로 등록하지 않았고 등록 경로/identity는 그대로다. 의존성/잠금 파일이 불변이므로 재설치하지 않았다.
- 적용 전에 기준 `8c620391b013cbf52e24ed2b1e3a9afd84820b48`의 별도 운영 복구 clone과 기존 의존성 사본을 준비했다. 기존 등록 정보 및 상태/영수증/인계 226개 파일을 공개 저장소 밖의 소유자 전용 디렉터리에 백업했다. 정확한 복구 clone/백업 경로와 manifest는 비공개 증거 `p4/backup.json`을 따른다. 상태 백업을 되쓰지 않았다.
- 운영 의존성으로 typecheck 종료 0을 확인하고 공식 `paseo plugin reload role-workflow --json`을 **한 번** 실행했다. 종료 0, `running`. 로그의 정상 stop→load→ready와 이후 새 플러그인 오류 0개를 확인했다. 과거 알림 HTTP 503 로그는 reload 전의 기존 기록으로 구분했다. 운영 데몬/worker PID는 그대로다. 복구 등록/reload는 필요하지 않아 미실행이다.
- 읽기 전용 `workflow.status` RPC가 오류 없이 작업 50개와 기존 계약 1/5/7을 반환했다. 등록 경로의 소스 tree/입력 해시, 공식 reload, 새로 비치된 규칙 `bea05cb3c2f9`의 8개 파일 전체 일치를 대조했다. 해당 등록 revision에서 snapshot.developmentCommit 스키마가 유지되는 것도 확인했다. CLI는 별도 메모리 내 Git revision을 반환하지 않으므로 revision 대응은 등록 소스/재로드/런타임 규칙 증거를 조합한 것이다. 운영 스냅샷 승인 실행이나 실제 화면 조작을 검증했다고 확대하지 않는다.
- 기존 작업 50개의 ID·계약·방식·배치·작업 공간·담당 ID/설정과 pushTargets/managedPush/epoch/승인 대기 필드, 동결 설정이 보존됐다. 영수증 디렉터리의 기존 175개 파일이 백업과 바이트 단위로 같고, 그중 6개 prepared는 같은 미참조/미승인/미실행 상태다. 새 snapshot 영수증은 0개다. 현재 구현 대화도 계속 실행됐고 중복 실행하지 않았다.

### HEJO·원격 대응 및 남은 승인

- HEJO 개발 `b2e485110b49f6ed5c19d5e9c32b11ba2d46b079`, 공개 후보 `740f5be61f0f9826eae991039992fb17a57788f2`, 전체 tree `0857b4a1d84611c27d9cebe29119de4e7e241d90`가 그대로이며 두 tree는 같다. 실제 `github/main`은 `3f5cb6bd35c6f57e862d09f809f9b1e2b1dd1f9c`이고 공개 후보의 단일 부모다. 개발 main 포함은 별도로 통과했다. 설치 앱/기존 패키징 후보 바이너리 SHA-256과 BuildInfo가 이전 검증과 같고 기존 PID 86124의 실행 경로도 일치한다. HEJO 앱을 종료·교체·재실행하지 않았으며 후보를 재생성하지 않았다.
- 플러그인 코드의 공개 예정 대상은 시설 저장소 `origin/main`과 검토 커밋 `6beb8a090e568d61ac936677442cb47cb4203ef2`다. 실제 원격 tip은 기존 `8c620391b013cbf52e24ed2b1e3a9afd84820b48`이며 대상의 조상이다.
- HEJO 공개 예정 대상은 HEJO 저장소 `github/main`과 공개 커밋 `740f5be61f0f9826eae991039992fb17a57788f2`, 대응 개발 커밋은 위 b2e4851이다. 개발 커밋을 공개 main 대상으로 바꾸지 않는다. 두 저장소는 각각 기획 검토 및 별도 사용자 화면 승인이 필요하다. 이번 결과는 푸시 승인이나 원격 반영 완료가 아니다.

### 이번 실행 증거

플러그인 worktree의 `evidence/snapshot-push/p4/` 기준이다. 동일 제품의 기존 전체 시험/독립 검토는 재사용하고 반복하지 않았다.

| 명령/검증 | 실제 결과 | 로그 |
|---|---|---|
| verify-resume.py, 적용 직전 재실행 | 각각 종료 0. 6개 영수증 분류/해시·현재 참조·writer/lock·기준/깨끗한 상태·검사 입력 대조 | resume-preflight.log, resume-preflight-immediate.log, resume-preflight.json |
| prepare-backup.py 및 로컬 git clone/checkout | 종료 0. 복구 clone·기존 등록·비공개 상태/영수증 백업·해시/권한 확인 | backup.log/json, recovery-clone.log |
| git merge --ff-only 검토 커밋 | 종료 0, 운영 HEAD/tree·깨끗한 상태 확인 | ff-only.log/json |
| 운영 clone에서 npm run typecheck | 종료 0, 기존 의존성으로 두 workspace 통과 | operating-typecheck.log |
| 공식 plugin reload role-workflow --json | 종료 0, 한 번 실행, 등록 그대로 running | reload.json, reload-output.json, reload-stderr.log |
| 공식 plugin ls/logs·daemon status·ls JSON 조회 | 각각 종료 0, ready·신규 오류 0·데몬 PID 불변·대화 확인 | plugins-final.json, logs-final.json, daemon-final.json, agents-after.json |
| node --import tsx observe-runtime.mjs | 종료 0, 읽기 전용 status·새 규칙 8개/등록 소스 계약 확인 | runtime-observation.log/json, runtime-status.json |
| verify-applied.py | 종료 0, 작업/영수증 보존·운영 소스·HEJO 앱/후보·원격/조상 관계 확인 | applied-verification.log/json, origin-ls-remote.log, github-ls-remote.log |

운영 적용 실패나 복구 실행은 없었다. 새 snapshot 영수증이 없는 동안 문제가 확인되면 준비된 이전 revision 운영 복구 clone을 공식 install/reload하는 기존 인계 절차를 따른다. 이후 snapshot 기록이 생성되면 구 버전으로 내려 읽게 하지 않고 기록 호환성을 먼저 판단한다. 상태 편집·백업 되쓰기·데몬 재시작을 복구 수단으로 쓰지 않는다. 기획 담당은 위 운영 증거를 검토한 뒤 두 공개 대상을 사용자에게 각각 제시한다.

---

## 이전 반환: P4 실행 전 중단 — 이후 12회에서 분류 조건 보완

handoff의 마지막 P4 절과 verdict 11회의 독립 재검토 수락을 확인하고 로컬 적용 전 조건을 조사했다. **P4 1항의 중단 조건에 해당하여 ff-only 반영과 plugin reload를 실행하지 않았다.** 운영 기준과 검토된 구현 커밋은 그대로다.

- 활성 등록은 기존 운영 clone의 `plugin/role-workflow`, 상태는 `running`이다. 운영 HEAD `8c620391b013cbf52e24ed2b1e3a9afd84820b48`, 브랜치 `main`, 작업 트리는 깨끗하다. 전역 pluginsEnabled는 이미 true이며 수정하지 않았다.
- 구현 worktree HEAD는 검토된 `6beb8a090e568d61ac936677442cb47cb4203ef2`이며 깨끗하다. 대상은 운영 기준의 후손이고 의존성/잠금 입력은 불변이다. 기존 검사 입력 해시와 전체 검증 성공 기록을 대조했다. 전체 시험을 반복하지 않았다.
- 조회 시 운영 checkout에 연결된 실행 중 대화와 Git lock은 발견되지 않았다. 현재 workflow의 managedPush 중 prepared/running/checking/unknown은 0개다. 그러나 **별도 실행 영수증 원본 `role-workflow/pushes/*/record.json`에는 prepared 6개가 남아 있다.** 생성 시각은 2026-11-07~13 UTC이며 현재 workflow의 managedPush가 이 6개를 참조하지 않는다. 참조 부재를 취소·만료·실행 안전으로 해석하지 않는다.
- 이전 기획 조회의 '미완결 없음'과 이번 결과의 차이는 현재 workflow 필드 외에 별도 영수증 원본도 확인했다는 점이다. 6개의 ID·시각·대상 커밋·승인/검증/종료 정보와 현재 참조 여부는 비공개 증거 `evidence/snapshot-push/p4/blocker.json`에 기록했다. 공개 보고서에는 해당 운영 기록 값을 복사하지 않는다.
- 이 조건이 해소되기 전 운영 복구 clone·비공개 상태 백업 준비 및 코드 반영/reload 단계로 진행하지 않았다. 등록·상태·영수증·의존성을 변경하지 않았고 복구 동작도 필요하지 않았다. 승인 execute RPC·버튼 대행·원격 쓰기·데몬 재시작·HEJO 후보 재생성은 하지 않았다.
- HEJO 개발 `b2e485110b49f6ed5c19d5e9c32b11ba2d46b079`과 공개 후보 `740f5be61f0f9826eae991039992fb17a57788f2`는 그대로다. P4 성공 후 수행할 tree/실제 원격 tip 재검증과 새 계약의 운영 로드 확인은 미실행이다. 플러그인 코드 원격 반영과 HEJO 공개의 사용자 승인은 각각 남아 있다.

이번 증거 위치는 플러그인 worktree의 `evidence/snapshot-push/p4/`다.

| 명령/검증 | 실제 결과 | 로그 |
|---|---|---|
| 공식 CLI daemon status·plugin ls·ls JSON 조회 | 각각 종료 0. 기존 운영 등록/running·데몬·실행 대화 확인 | daemon-preflight.json, plugins-preflight.json, agents-preflight.json |
| preflight.py | 종료 1, 미완결 prepared 영수증 6개로 의도한 적용 게이트 거절. 원격/운영 쓰기 없음 | preflight.log, preflight.json |
| inspect-blocker.py | 종료 0. 영수증 6개·현재 참조 0·운영/구현 HEAD/깨끗한 상태·기존 등록/running·HEJO 후보 불변 확인 | blocker.json, plugins-blocked.json |

초회 진단 스크립트는 영구 실행 claim의 단순 존재를 실행 중 상태로 가정하여 중간에 멈췄다. 미완결 영수증과 연결된 claim을 구분하도록 진단을 바로잡았고 실제 중단 근거는 prepared 영수증 6개다. 초회 로그는 `preflight-initial-claim-check.log`에 남겼다. 후속 상세 진단의 첫 호출도 미생성 결과 파일로 종료 1이었으며, 진단 결과 파일을 생성한 뒤 최종 호출이 종료 0이었다. 제품 코드·운영 상태를 고쳐 검사를 통과시키지 않았다.

다음은 기획 담당이 위 영수증의 승인/실행 사실과 현재 요청의 관계를 읽기로 판단하고 P4 중단 조건에 대한 처리 계획을 확정하는 것이다. 오래된 미참조 영수증을 임의 취소·삭제하거나 상태 JSON을 편집하지 않는다. 이번 결과를 운영 적용 완료로 표시하지 않는다.

---

## 이전 반환: V-PS-01 보완 — 이후 독립 재검토 수락됨

[독립 검토 기록](plugin-independent-review.md)과 [handoff](handoff.md)의 마지막 수정 인계를 따랐다. 수락 기준·스키마·승인 계약을 변경하지 않고 기존 정리 책임 자리에서 수동 보관 우회를 수정했다. 고위험 자체 점검이며 독립 재검토의 합격 판정은 남아 있다. **운영 적용·reload·운영 데몬 재시작·원격 쓰기·HEJO 후보 재생성은 하지 않았다.**

### 변경본과 지적 처분

- 저장소는 기존 별도 worktree `plugin-snapshot-60f149af`, 브랜치는 `fix/snapshot-push-60f149af`다. 실제 절대 경로는 호스트 result와 무시된 증거의 audit에 기록한다.
- 새 전체 커밋: `6beb8a090e568d61ac936677442cb47cb4203ef2`, tree `5b673264fdcdbe0e23bd495956973e46e1a13aba`. 부모는 독립 검토 대상 `9f7a763f7a53b8807bfb2c5e2d4373aaadcee692`다. 관련 파일 4개만 커밋했다.
- V-PS-01: `WorktreeCleanup`의 기존 보존 분기를 `run()`과 `manuallyArchived()`가 공유한다. 직접 호출도 대상·영수증·영속 표식에서 보존 정책을 확정하고 `skipped`를 기록하며 수동 보관 성공을 반환하지 않는다. 이미 디렉터리가 사라진 경우에도 증거 보존을 확인했다고 표시하지 않는다.
- `engine.ts`의 새 구현 회차는 일반 정리 예산을 초기화하되 `preserveSnapshot`이 있는 기록은 유지한다. 저장 원본과 형식은 기존 worktreeCleanup 그대로다. 현재 대상·영수증이 비어도 표식의 수명이 끝나지 않는다.
- 변경 파일은 `server/worktree-cleanup.ts`, `server/engine.ts`, `tests/worktree-cleanup.test.mjs`와 자체 변경 문서 `docs/changes/public-snapshot-push.md`다. 앞의 세 경로는 `plugin/role-workflow/` 아래다. 별도 상태·보관 실행기를 추가하지 않았고 수락 시험을 완화하지 않았다.
- 소유 칸은 기존 시설/정리 집행, 원본은 workflow 정리 기록, 쓰기 주체는 기존 WorktreeCleanup/engine이다. 설계 변경이나 범위 밖 정리는 없다. 일반 작업의 수동 보관 관측·작업 공간 재배치·정리 예산 초기화는 기존 동작을 유지한다.

### 실행 증거

이번 보완의 로그는 해당 worktree의 `evidence/snapshot-push/v-ps-01/`에 별도로 보존했다. 이전 구현·독립 검토 원시 증거를 덮어쓰지 않았다.

| 명령/검증 | 실제 결과 | 로그 |
|---|---|---|
| V-PS-01 회귀 11개, 기존 9f7a763 제품 소스로 실행 | 종료 1, 11개 모두 실패. 차단 결함 검출이며 제품 합격이 아님 | regression-before-final.log |
| 같은 회귀, 수정본 실행 | 종료 0, 11/11 통과 | regression-after-final.log, regression.json |
| verify-regression.py | 종료 0. 기존 소스 임시 복원 → 실패 확인 → 수정 소스 복구 → 통과, 복구된 소스/시험 해시 기록 | regression.json |
| node의 snapshot-push·worktree-cleanup·archive·push-recovery 시험 | 종료 0, 177개 통과 | related.log/json |
| npm test | 종료 0, role-workflow 1,420개 및 codex-usage 1개 통과 | npm-test.log/json |
| npm run typecheck | 종료 0, 두 workspace 통과 | typecheck.log/json |
| python3 -m unittest discover -s scripts -p 'test_*.py' | 종료 0, 142개 통과 | python-tests.log/json |
| npm run e2e | 종료 0, 임시 홈·포트·가짜 모델의 격리 데몬에서 27/27 통과 | e2e.log/json |
| python3 scripts/privacy_scan.py --staged | 종료 0, 실제 커밋할 변경 포함 | privacy.log, staged-audit.json |
| git diff --cached --check | 종료 0 | diff-check.log, staged-audit.json |
| audit-staged.py | 종료 0, 지정 4개만 staged·검사한 소스/시험 해시 일치·필수 검사 종료 코드 확인 | staged-audit.json |
| audit-final.py | 종료 0, 최종 커밋/부모/tree·4개 파일/검사 입력 일치·깨끗한 worktree·운영 checkout/HEJO 후보 불변·공식 보고서 링크/개인값 검사 | final-audit.json, report-validation.json |

추가 회귀는 보존 표식/현재 대상/저장 영수증 각각과 과거 `skipped`/`done`, `observe()` 직접 호출, `done`/`pushed`/`no_push`, JSON 저장·엔진 재생성 두 차례, 자동/오래된 후보의 일괄 보관 차단, 새 구현 회차의 기존/사라진 디렉터리를 검사한다. 일반 작업의 수동 보관과 정상 정리는 기존 시험 및 격리 e2e로 확인했다. 결함 소스로 실행한 실패가 이번 변경의 mutation check를 겸한다. 초회 11개 중 8개 실패/수정 후 11개 통과 뒤, observe의 직접 경계를 명시한 최종 시험으로 기존 소스에서 11개 모두 실패함을 확인했다. 초회 로그도 regression-before.log·regression-after.log에 유지한다.

최초 로그 디렉터리를 잘못 지정한 명령은 종료 1로 시험을 실행하지 못했다. 저장소 루트의 증거 폴더를 생성하고 다시 실행했으며 staged-audit.json에 구분했다. 실패를 skip하거나 기대값을 완화하지 않았다. e2e의 임시 Git 쓰기·데몬 재시작은 격리 fixture에만 해당한다. 운영 snapshot 실행이나 운영 자료 보존을 실물로 재검증한 결과가 아니다.

### 남은 경계

기획 담당은 실제 수정 코드와 실패/통과 증거를 검토한 뒤 지정된 Terra high 독립 검토자에게 같은 지적의 처분을 재확인한다. P4는 그 뒤에 판단한다. 기존 운영 적용/롤백안은 아래 초기 보고의 해당 절을 유지하며 이번에는 실행하지 않았다. 운영 checkout은 기존 기준이고 HEJO 개발·공개 후보도 그대로다. 새 공개 후보나 푸시 승인 대상을 만들지 않았다.

---

## 이전 반환: P1~P3 최초 구현 기록

P1~P3 구현·격리 검증·커밋을 마쳤다. 자체 점검이며 고위험 독립 검토나 운영 수락을 대신하지 않는다. [plugin-plan](plugin-plan.md)의 승인 범위 안에서 기존 시설/위험 행동 집행 경로를 확장했다. **운영 등록/reload·운영 데몬 재시작·실제 외부 원격 쓰기는 미실행**이다.

## 실제 저장소와 변경본

- 저장소: Paseo 시설 저장소의 별도 Git worktree `plugin-snapshot-60f149af`. 활성 checkout이나 HEJO worktree에서 플러그인 코드를 수정하지 않았다. 실제 절대 경로는 호스트 result의 repositories와 무시 경로 `evidence/snapshot-push/final-audit.json`에 기록한다. 공개 문서에는 운영 개인 경로를 넣지 않는다.
- 브랜치: `fix/snapshot-push-60f149af`, 원격 이름 `origin`(이번 원격 쓰기/푸시 대상 승인은 없음).
- 기준: `8c620391b013cbf52e24ed2b1e3a9afd84820b48`.
- 최종 커밋: `9f7a763f7a53b8807bfb2c5e2d4373aaadcee692`, 전체 tree `3169ba6f1f48cd09b5d7211101733b017b3fc069`. 기준의 직접 자식이며 17개 관련 파일만 바뀌었다. 커밋된 입력과 검사 입력 해시가 같고 worktree는 깨끗하다.
- 로컬 HANDOFF.md를 갱신하고 Git info/exclude로 추적에서 제외했다. 기존 운영 checkout은 기준 HEAD 및 깨끗한 상태 그대로다. 그 checkout의 플러그인 코드·등록·의존성은 수정하지 않았다.

## 구현과 책임 배치

| 기존 책임/변경 파일 | 최종 변경 |
|---|---|
| shared/artifacts.ts, shared/managed-push.ts | 선택 속성 snapshot.developmentCommit 및 준비 영수증의 snapshotTree. 없는 과거 대상은 기존 계약 유지, 불완전 확장 영수증 거절 |
| server/push-review.ts, managed-pushes.ts | 모드·개발 커밋을 승인 키에 포함, 준비/실행 직전 기존 검증 경로 호출, 완료/복구에도 snapshot 보존. 원격 선행 때 unrelated merge를 지시하지 않음 |
| server/git.ts, worktree.ts | 같은 저장소·배정 branch/HEAD·깨끗한 트리·로컬 main 포함, 공개/개발 tree·추적 tip·실제 원격 단일 부모를 분리 검증. 실패 시 일반 경로로 fallback하지 않음 |
| server/managed-push.ts, git-environment.ts | 기존 runner가 HEAD/tree/부모/목적지를 다시 검사. 실제 원격에 포함된 후보는 쓰기 없이 성공 확인하며 exitCode는 null/미실행으로 유지. 실제 Git 객체/그래프를 쓰도록 대체 객체를 무시하고 status의 fsmonitor 실행을 차단 |
| server/engine.ts, archive.ts, worktree-cleanup.ts | 기존 정리 기록의 preserveSnapshot으로 보존 방침 영속화. planner ff-only·자동 정리·일괄 보관을 건너뛰고 integration.ok를 성공으로 꾸미지 않음. 대상 변경/복구 뒤에도 증거 보존 |
| client/managed-push-panel.tsx | 공개 전체 커밋·대응 개발 전체 커밋·검증 tree·checkout/증거 유지 방침 표시 |
| rules/40-paseo-role-workflow.md 및 생성 rules-content.ts | 일반/스냅샷 인계·검증·보존 계약 구분. 공통 프롬프트와 기존 기본 승인 키는 보존 |
| tests/snapshot-push.test.mjs, managed-push-ui.test.mjs | 실제 임시 Git 이력·bare remote·준비/승인/실행/복구·거절 및 실제 화면 회귀 |
| docs/changes/public-snapshot-push.md | 소유·계약·시험 매핑·운영 적용/롤백 경계 |

별도 푸시 실행기·제2 상태 파일·경로/HEJO 이름 기반 자동 감지는 없다. 새 상태는 기존 workflow/managedPush/정리 기록에만 속한다. 기존 URL 검증·셸 push 차단·일반 푸시 ff-only/cleanup 경로를 유지한다. 새 SDK API나 의존성 변경은 없다. 격리 worktree의 잠금 파일 기준 npm ci로 의존성을 준비했고 활성 설치본에 적용하지 않았다.

## 수락 시험과 실제 결과

아래 로그는 플러그인 구현 worktree 기준 `evidence/snapshot-push/`에 있다. 전체 원시 로그·가짜 화면 이미지는 추적하지 않는다.

| 명령/검증 | 실제 결과 | 증거 |
|---|---|---|
| npm test | 종료 0. role-workflow 1,409개 및 codex-usage 1개 통과 | npm-test-final.log |
| npm run typecheck | 종료 0. 두 workspace 통과 | typecheck-final.log |
| python3 -m unittest discover -s scripts -p 'test_*.py' | 종료 0. 142개 통과 | python-tests.log |
| npm run e2e | 종료 0. 가짜 모델·임시 홈/포트의 격리 데몬 27/27 통과, 플러그인 오류 없음 | e2e-final.log |
| snapshot-push.test.mjs | 종료 0. AT-PS-01~05의 실제 Git 분리 이력/로컬 bare remote·승인 모사·재시작/저장 영수증·거절·보존 검사 | snapshot-final.log 및 최종 전체 시험 로그 |
| managed-push-ui.test.mjs | 종료 0. 실제 React 승인 UI 1280/390 폭에서 두 전체 커밋·tree·보존 문구 표시, 좁은 실패 화면의 오류와 실행 버튼 부재 확인 | ui-final.log 및 최종 전체 시험 로그, approval-wide.png·approval-narrow.png·approval-narrow-error.png |
| mutations.py | 검사 종료 0. tree/main 포함/단일 부모 검사를 각각 제거하면 해당 거절 시험이 종료 1의 assertion으로 실패. 원본 복구 해시가 최종 소스와 동일 | mutations.json, mutation-tree.log·mutation-base.log·mutation-parent.log |
| python3 scripts/privacy_scan.py --staged | 종료 0. 실제 staged 변경 포함 검사 | privacy.log, staged-checks.json |
| git diff --cached --check | 종료 0 | diff-check.log, staged-checks.json |
| audit_final.py | 종료 0. 최종 커밋·부모·17개 입력 해시·깨끗한 상태·운영 checkout/HEJO 후보 보존 확인 | final-audit.json |

AT-PS-02는 tree 한 파일 변경, 다른 저장소/개발 커밋, 배정 HEAD 불일치, 기준 main 미포함, 잘못된/없는/다중 부모, dirty, 조회 실패/빈 원격, Git 대체 객체로 잘못된 tree를 감추는 경우를 거절한다. AT-PS-03은 모드 제거·개발/공개 커밋·목적지 변경의 오래된 승인을 거절하고, 같은 후보가 이미 반영됐으면 실제 쓰기를 반복하지 않는다. AT-PS-04의 쓰기 대상은 시험이 생성한 임시 bare remote뿐이다. 운영 외부 Git 푸시를 실행한 결과가 아니다. AT-PS-05는 실제 planner/개발 HEAD 및 파일 보존과 영속 보존 표시를 검사하며 기존 일반 ff-only/정리 회귀도 전체/e2e에서 통과했다.

화면 스크린샷을 직접 확인했다. 넓은 화면에서 두 커밋과 tree가 구별되고 좁은 화면에서는 전체 해시가 줄바꿈되며 보존 방침과 실패 안내가 읽힌다. 이는 격리된 실제 웹 UI 렌더 관측이며 운영 Paseo/모바일 기기에 새 플러그인을 올려 검증한 것은 아니다. 새 snapshot 모드 전체를 운영 데몬에서 실행하는 검증은 의도적으로 하지 않았다. e2e의 임시 데몬 재시작/등록은 운영 행위와 구분한다.

### 실패와 처분

초회 전체 npm test는 기존 공통 자동화 프롬프트의 고정 해시 한 건에서 종료 1이었다. 기대 해시를 갱신하거나 기준을 완화하지 않고, 기존 공통 프롬프트를 복구하고 snapshot 설명을 작업별 인계/규칙에 배치했다. 이후 전체 시험이 통과했다. 초기 로그는 npm-test-initial.log에 보존한다.

초회 로컬 커밋에 Git 자동 장치 신원이 붙어 공개 기준 noreply 신원으로 해당 미공개 커밋 메타데이터만 정정했다. 파일 tree와 검사 입력은 동일하고 저장소/전역 identity 설정은 바꾸지 않았다. 최종 대상은 위 전체 해시만 사용한다. commit-identity-correction.json/log에 처분을 기록했으며 그 로그는 공개하지 않는다. 푸시 승인 대상 변경이나 이미 실행한 원격 동작은 없다.

## 운영 적용 및 롤백안 — 이번 단계 미실행

1. 구현에 참여하지 않은 다른 모델의 독립 검토 등 고위험 검토 조건을 먼저 충족한다. 검토자 지정은 호스트/사용자 결정이다. P1~P3 자체 점검을 독립 검토나 운영 적용 승인으로 표시하지 않는다.
2. P4에서 운영 등록 경로·기존 revision과 실행 중/확인 불가 요청을 읽기로 확인하고 복구 자료를 보존한다. 검토된 시설 revision을 개발 worktree와 다른 운영 clone에 배치하는 방식을 확정한다. 개발 원본이나 이번 worktree를 운영에 직접 등록하지 않는다.
3. 플러그인 코드의 원격 반영과 HEJO 공개 승인은 별도 대상으로 처리한다. 검토된 코드의 푸시도 사용자 플러그인 화면 승인을 별도로 받아야 하며 에이전트가 직접 실행하지 않는다. 공식 reload 경로를 사용하고 운영 데몬을 재시작하지 않는다. 운영 적용/상태 확인은 후속 승인 범위에서만 실행한다. 참고: [공식 plugin reference](https://paseo.sh/docs/plugins/reference.md).
4. snapshot 요청 생성 전 문제가 생기면 이전 운영 등록/revision으로 복귀·reload하는 코드 롤백이 가능하다. snapshot 기록 생성 뒤에는 확장 필드를 모르는 구 버전으로 곧바로 내려 기록을 읽게 하지 않는다. 요청/영수증/원격 상태를 읽기로 대조하고 해당 기록을 지원하는 검토된 버전으로 복구한다. 상태 JSON 수동 편집·필드 삭제·재푸시·worktree/증거 삭제는 롤백 절차가 아니다.
5. 운영 적용 뒤 HEJO 개발 `b2e485110b49f6ed5c19d5e9c32b11ba2d46b079`과 공개 후보 `740f5be61f0f9826eae991039992fb17a57788f2`의 tree/실제 원격 tip을 읽기로 재검증하고 snapshot.developmentCommit을 포함한 별도 HEJO 승인 화면을 준비한다. 이번 보고 때문에 HEJO 문서 커밋이나 공개 후보를 재생성하지 않는다.

남은 일은 독립 검토와 P4 운영 적용 판단이다. HEJO 제품·후보·기존 수락 판정은 보존하며 이번 결과를 전체 완료/푸시 완료로 선언하지 않는다.
