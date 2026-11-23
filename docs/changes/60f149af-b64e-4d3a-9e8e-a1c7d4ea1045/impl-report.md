# 현재 구현 인계: 승인된 공개 스냅샷 후보 준비

[확인] 사용자가 기존 공개 스냅샷 방식을 승인했으며 [handoff 마지막 절](handoff.md#현재-후속-인계-승인된-공개-스냅샷-후보-준비)을 따른다. 제품·실사용 수락과 기존 개발 이력은 유지한다. 최신 handoff·verdict 승인 기록과 본 보고서만 개발 브랜치에 반영한다. 제품·버전·fixture·설치 앱을 변경하지 않는다.

## 공개 범위와 개인정보 검토

공개 범위는 최종 개발 tree 전체다. 원격 0.2.7 이후의 DRAWER-INLINE·UI-CLEAN·성능 구현/시험/문서도 포함한다. 이전 개발 커밋 `32e1c3a2aaaba31be1aef654ce67d7b16073fc80`과 승인된 원격 tip의 차이 89개 파일 목록을 확인했다. 내용 검토와 추적 텍스트 개인값 검사에 더해 새 PNG 시안 15개를 각각 직접 열었다. 실제 인물 사진·개인 이름·계정/이메일·개인 경로·인증정보는 관측되지 않았다. 짝을 이루는 HTML의 UI 시안과 역할 캐릭터·일반 직원 표기·고정 예시 문구를 확인했으며 실제 앱 캡처를 새로 넣지 않았다. 관측 범위를 넘어 모든 업무 연관성이 없다고 보장하는 검사는 아니다.

PNG의 56바이트 EXIF도 따로 파싱했다. Exif IFD 포인터와 pixel X/Y dimension 태그뿐이며 작성자·날짜·위치·주석·문자열 metadata는 없다. 이 이미지나 HTML을 삭제/정리하지 않고 승인된 전체 tree를 보존한다. `.build/hejo-perf-evidence/public-candidate/binary-review.json`에 파일별 해시·metadata 및 직접 관측 범위를 기록한다. 실제 앱 관측 이미지·원시 표본·배포 비밀·로컬 증거는 무시 경로에 있고 공개 후보에 추가하지 않는다.

## 로컬 공개 후보의 계약과 증거 위치

후보 준비는 기존 [install/hejo-publish](../../../install/hejo-publish)를 사용한다. 개발 문서 커밋 뒤 깨끗한 상태에서 `git ls-remote github refs/heads/main`과 로컬 public이 승인 시 값 `3f5cb6bd35c6f57e862d09f809f9b1e2b1dd1f9c`인지 재확인한다. 달라지면 후보를 생성하지 않고 보고한다. 도구의 기존 GitHub 계정 조회·공개 작성자 계약을 유지하며 원격 쓰기는 실행하지 않는다. 버전은 기존 0.2.7(9)을 유지하며 새 앱 배포/릴리즈 산출물을 만들지 않는다.

최종 개발 커밋의 로컬 main 포함과 공개 후보의 실제 원격 tip 포함을 구분한다. 공개 후보는 원격 tip 하나만 부모로 갖고 최종 개발 tree와 정확히 같아야 한다. 개발 커밋을 부모로 연결하거나 공개 원격 main에 개발 이력을 올리지 않는다. 후보 생성 뒤 문서에 후보 해시를 넣기 위한 추가 커밋/후보 재생성은 하지 않는다. 실제 최종 개발/공개 전체 해시·부모·tree·검사 종료 코드는 로컬 `receipt.json`, `verification.json`과 호스트 result가 원본이다. 확인하지 않은 실행을 이 본문에서 통과로 선언하지 않는다.

로그 및 실행 증거는 구현 worktree의 `.build/hejo-perf-evidence/public-candidate/` 기준이다.

| 검사·실행 | 증거 및 확인 범위 |
|---|---|
| 최신 문서 복사본·상대 링크·수락 명세 보존·변경 범위 | `document-validation.json`, `document-validation.log` |
| 가짜 HERMES_HOME·확인된 같은 Python의 `scripts/scan_private.py`, diff 검사 | `scan-private.log`, `diff-check.log`, `checks.json` |
| 원격 대비 파일 목록·추가 바이너리 검토 | `initial-scope.json`, `binary-review.json` |
| 승인된 원격/public 시작 조건·기존 publish 실행 | `preconditions.json`, `publish.log`, `publish-exit.json` |
| 최종 개발/공개 커밋·단일 부모·tree·조상·제품/fixture·설치본 대응 | `verification.json`, `receipt.json` |
| 설치된 플러그인 지원 범위·읽은 소스 발췌와 해시 | `plugin-compatibility.json`, `plugin-list.local.json` |

보조 contact sheet 도구는 PIL 부재로 종료 1이어서 설치 없이 원본 이미지 15개를 직접 확인했다. 초기 PNG 검사에서 EXIF가 없다고 가정한 assertion도 종료 1이었으며 실제 EXIF를 파싱해 픽셀 치수뿐임을 확인하고 종료 0으로 재검사했다. 제품 시험 실패가 아니며 `inspection-attempts.json`에 보존한다.

## 플러그인 호환성 확인과 남은 차단

[확인] 설치된 role-workflow 플러그인은 running이며 읽기 전용으로 활성 소스와 계약을 확인했다. `shared/artifacts.ts`의 PushTarget은 저장소·원격·브랜치·전체 커밋을 받아 공개 후보를 지정할 수 있다. 그러나 연합개발의 실제 승인 경로는 공개 스냅샷 계약을 지원하지 않는다.

- `server/managed-pushes.ts`는 준비 및 실행 전에 `checkWorktreeBase`를 호출한다. `server/worktree.ts`의 이 검사는 대상 공개 커밋에 개발 main도 조상으로 포함하도록 요구하므로 별도 public 이력 후보를 차단한다.
- 푸시 뒤 `integrateWorktree`는 대상 브랜치 main이 planner 브랜치 main과 같으면 공개 커밋으로 ff-only를 시도한다. 별도 개발 커밋을 사용하거나 planner checkout을 유지하는 옵션이 현재 PushTarget 계약에 없다.

따라서 전체 커밋 지정은 지원하지만 이 작업의 승인된 부모/tree 분리 검증·개발 checkout 유지까지 지원한다고 표시할 수 없다. 플러그인을 고치거나 상태·설정·Git 이력을 바꾸어 우회하지 않았고, 푸시 준비/실행 RPC도 호출하지 않았다. 후보 생성 여부와 정확한 해시는 result/영수증에서 구분하며, 계획 담당은 로컬 후보를 검토한 뒤 플러그인 지원 미비를 별도 승인 범위에서 해결해야 한다. 일반 개발 커밋으로 푸시 대상을 대체하거나 불필요한 unrelated merge를 하지 않는다.

## 제품·운영 보존

제품 소스는 검토 커밋 `221e84082a4230caca6b450cb3b2e0ee9d085ee8`과 동일하고 기존 v3·packaging·live 및 검토자 증거를 재사용한다. 제품 소스 tree는 `511b92f6362a244be7de02f949c7cefd481fbc2f`다. 문서가 바뀐 최종 개발/공개 전체 tree와 설치본 BuildInfo의 제품 전체 tree `0beece585454a2410e835ddbdaeed60e0cc4181f`를 혼동하지 않는다. 설치 실행 파일 SHA-256은 `01827d9ce8acbe89c631e477f66977caaf2ce8e934aeefebcac13f510b57ca65`이며 로컬 영수증에서 대응을 확인한다.

전체 회귀·성능·빌드 반복, 앱 재시작/재설치/GUI 입력, 실제 메시지 전송, 게이트웨이·운영 설정 변경, 원격 쓰기는 이번 범위가 아니다. 자연 수신 빈도·장시간 관측과 실환경 CPU 비교의 기존 한계는 유지한다. 제품 수락과 원격 반영 완료를 구분하며 구현 결과를 계획 담당에게 반환한다.

---

# 이전 구현 인계: 최종 문서 반영·원격 이력 확인 (5회 검토 수락)

[확인] 원래 목표는 사용 불가능할 정도로 느린 HEJO의 응답성 회복이다. [verdict 4회 검토](verdict.md)의 제품·실제 앱 수락 결과를 유지하고 [handoff 마지막 절](handoff.md#현재-후속-인계-최종-문서-반영원격-이력-확인)에 따라 지정된 문서만 반영한다. 이번 단계는 문서 커밋과 읽기 전용 이력 조사이며 제품·fixture·설치 앱을 변경하지 않는다. 최종 문서 커밋 전체 해시는 호스트의 result 인계를 따른다. 제품 검토 커밋은 `221e84082a4230caca6b450cb3b2e0ee9d085ee8`이다.

## 문서 반영 범위와 상태 구분

공식 작업 폴더의 spec·design·tasks·handoff·plan-review·impl-report·verdict 7개와 `tests/acceptance/HEJO-PERF.md`, `docs/spec/current/hejo-performance.md` 총 9개만 배정 worktree에 반영했다. 이전 단계의 미실행·차단·설치 전 상태는 검토 회차 당시 기록으로 표시한다. 현재 작업 표와 수락 명세의 상태 설명을 4회 수락 결과에 맞추며 요구·기대값·수치 예산은 변경하지 않는다. 검증자의 기존 판정·지적 처분은 그대로 보존하고 이번 구현 결과의 재검토를 요청한다. 공식 보고서와 worktree 복사본은 같은 내용이다.

## 원격 이력 조사: 확인한 원인과 차이

원시 읽기 결과는 구현 worktree의 `.build/hejo-perf-evidence/final-docs/history.json`에 보관한다. 원격 주소·작성자 개인값은 공개 문서에 기록하지 않는다.

| 구분 | 확인 값 / 제품 커밋과 관계 |
|---|---|
| 로컬 main | `39f954c1bd3a50fd27d4f11a3b03774d0e74aa41`, 제품 커밋의 조상(종료 0) |
| 기존 추적 github/main | `98a9f242a74a97a2af6885264cac49da241ad7fa`(0.2.6), 조상 아님(종료 1) |
| `git ls-remote github refs/heads/main` | 종료 0, `3f5cb6bd35c6f57e862d09f809f9b1e2b1dd1f9c`(0.2.7), 로컬 public과 같음 |
| 실제 원격 tip ↔ 제품 커밋 | 조상 검사·merge-base 각각 종료 1, 공통 조상 없음 |
| 저장소 깊이 | `--is-shallow-repository` false, 누락된 shallow 이력 때문이 아님 |
| 개발 이력 root / 공개 이력 root | `1ee8b992dcec825a1f6aa365b8acdce09e6636fd` / `c98de86f3630e38835f238ba334e0e18d0c377f9` |

이 분리는 기존 배포 방식에 의한 것이다. [install/hejo-publish](../../../install/hejo-publish)는 개발 HEAD의 tree만 `git commit-tree`로 공개 커밋에 넣고 부모를 기존 public으로 삼는다. 비공개 개발 커밋 이력은 공개하지 않으며 공개 작성자도 별도로 설정한다. 이번 조사에서는 도구를 실행하지 않았다. [0.2.7 검증·공개 기록](../HEJO-TELEGRAM-20261122/verdict.md)도 이 절차와 일치한다.

직접 확인한 0.2.7 공개 커밋의 부모는 `98a9f242a74a97a2af6885264cac49da241ad7fa`, tree는 `6ea58c4ca582c38b26b45c52d7bd1b96371a6fab`이다. 이 tree는 당시 개발 버전 커밋 `c3475bb95489150497f0a4d365523f0941ac2034`와 완전히 같으며 그 개발 커밋은 이번 제품 커밋의 조상이다(종료 0). 따라서 원격 0.2.7의 파일 기준점은 개발 이력에도 존재한다. 추적값만 0.2.6에 머물러 있으며 이를 갱신하는 fetch는 하지 않았다. 공통 조상 부재를 단순 원격 선행이나 우발적인 이력 손상으로 분류하지 않는다.

문서 반영 전 제품 커밋과 실제 원격 tip의 파일 차이는 80개, +25,991/-514줄이다. 제품 소스 12개, 앱 시험·fixture·시험 실행 스크립트, HEJO-DRAWER-INLINE·HEJO-UI-CLEAN 및 공개 기록 문서가 포함된다. `gate/`, `hub/`, `schemas/`, `config/`, `install/`에는 차이가 없다. 이후 개발 이력의 DRAWER-INLINE TASK-02와 UI-CLEAN 병합·시험·검증 및 이번 기준 동결/성능 수정을 보존해야 한다. 이번 커밋은 이 기존 차이를 재작성하거나 되돌리지 않고 지정된 9개 문서만 더한다. 최종 파일 목록은 `history.json`과 `commit-audit.json`을 함께 확인한다.

## 안전한 후속 선택지와 권고

1. **기존 공개 스냅샷 절차 유지(권고):** 계획 담당이 최종 개발 트리와 공개 범위를 검토한 뒤, 실제 원격 main tip을 부모로 하는 새 public 후보를 별도 승인 범위에서 준비한다. 개발 이력은 현재 브랜치에 보존한다. public 후보의 트리·개인값·원격 선행 여부와 필요한 배포 검증을 확인하고 사용자가 플러그인의 푸시 대상 화면에서 승인해야 한다. 이 경우 원격 main의 대상은 개발 커밋이 아니라 검토된 새 public 커밋이다.
2. **개발 이력 보관 목적의 별도 비공개 원격/브랜치:** 비공개 대상과 공개 범위가 명시적으로 정해졌을 때만 계획한다. 공개 저장소에 이름만 다른 개발 브랜치를 올리면 전체 개발 이력과 작성자 정보도 공개되므로 기존 배포 방식을 대체하는 안전한 해결이 아니다. 현재는 대상이 확정되지 않았다.

일반 인계의 “원격 tip을 개발 대상 커밋에 포함” 조건은 이 저장소의 별도 public 이력과 충돌한다. 부모 연결을 억지로 추가하지 말고 계획 담당과 사용자가 공개 후보의 부모·대상 브랜치 계약을 결정해야 한다. 공통 조상 없는 병합·rebase·reset·강제 갱신·원격 쓰기와 public ref 변경은 모두 미실행이다. `install/hejo-ship` 공개/배포도 실행하지 않았다. 이번 결과로 푸시 승인이나 전체 완료를 요청하지 않는다.

## 제품·기존 검증·설치본 대응

제품 소스 tree는 `511b92f6362a244be7de02f949c7cefd481fbc2f`이다. 설치 후보의 99개 제품 소스와 6개 빌드 입력을 현재 파일 및 제품 커밋과 대조했고, 설치본과 후보의 실행 파일·BuildInfo 및 PID 86124의 실행 경로가 일치함을 읽기 전용으로 확인했다. 검증 결과는 아래 표와 `correspondence.json`을 따른다.

설치 실행 파일 SHA-256은 `01827d9ce8acbe89c631e477f66977caaf2ce8e934aeefebcac13f510b57ca65`이며 BuildInfo는 dirty=false, tree `0beece585454a2410e835ddbdaeed60e0cc4181f`이다. 이는 제품 커밋의 전체 tree이며 문서 커밋의 전체 tree와 같다고 주장하지 않는다. 문서 커밋은 동일 제품·빌드 입력을 유지하므로 v3의 전체 회귀·직접방/홈 각 5회 예산, packaging 검증, live 실제 앱 관측 및 검토자 검증을 재사용한다. 전체 시험·빌드·성능 계측·앱 재종료/교체/입력은 반복하지 않는다.

실환경 CPU는 조건이 달라 전후 개선율을 계산하지 않았고, 자연 수신 종류/빈도와 장시간 관측의 한계는 그대로다. 이를 새 완료 조건으로 추가하지 않는다. 실제 메시지 전송·게이트웨이/설정 변경·푸시는 하지 않는다. 다음 담당은 이 문서 커밋과 설치 대응을 재검토하고 V-HP-06의 남은 이력 처리 결정을 사용자에게 제시한다.

## 이번 단계 검사

아래 로그는 구현 worktree의 `.build/hejo-perf-evidence/final-docs/` 기준이다. 문서 검사는 가짜 HERMES_HOME·명부/보관함과 확인된 같은 Python을 사용한다.

| 검사 | 실제 결과 | 증거 |
|---|---|---|
| `validate_docs.py` | 종료 0. 9개 공식 복사본 동일·상대 링크 37개/anchor 정상·문서 개인값 패턴 없음·지정 파일만 staged·수락 기준/예산 본문 불변 | `document-validation.json`, `document-validation.log` |
| `HERMES_HOME=<가짜 홈> "$hejo_python" scripts/scan_private.py` | 종료 0. staged 9개를 포함한 추적 텍스트 검사 | `scan-private.log`, `checks.json` |
| `git diff --cached --check` | 종료 0 | `diff-check.log`, `checks.json` |
| `check_correspondence.py` | 종료 0. 99개 소스·6개 빌드 입력·설치/후보 해시·BuildInfo·실행 PID 경로 일치. 9개 문서 밖 제품/fixture diff 종료 0 | `correspondence.json`, `correspondence.log`, `product-diff.log` |
| 원격 tip·각 이력 root/tree·조상·파일 차이 읽기 | ls-remote 등 조회 종료 0. 공통 조상 없음·공개 tip 비포함은 예상한 종료 1이며 별도 기록 | `history.json`, `remote-directories.log` |
| 문서 커밋 이후 최종 HEAD·부모·변경 경로·제품 tree·공식 사본 대조 | 후속 감사 결과와 전체 커밋 해시는 호스트 result에서 보고 | `commit-audit.json` |

대응 검사 초회는 index의 디렉터리를 `git rev-parse :app/Sources`로 조회하는 잘못된 명령 때문에 Git 종료 128·검사 종료 1이었다. 디렉터리 대신 검토 커밋과 staged 소스 diff를 비교하도록 검사 도구를 수정해 종료 0을 확인했다. 제품 검사 실패로 분류하지 않으며 `correspondence-initial.json`에 보존한다. 이번 제품 전체 시험·성능·빌드·설치/GUI 조작은 미실행이며 위의 기존 제품 검증을 재사용한다.

---

# 이전 구현 인계: TASK-04 로컬 설치·실제 앱 관측 (4회 검토 수락)

[확인] [handoff](handoff.md)의 TASK-04 및 [verdict](verdict.md) 3회 검토에 따라 검토된 packaging 후보를 앱 설치 위치에 교체·정상 실행했다. 실제 표시된 앱에서 홈·직접방 입력/삭제·스크롤·전환을 각각 3회 관측했고 모두 반영됐다. 관측 중 입력이나 전환이 멎는 현상은 재현되지 않았다. **이는 구현자의 실제 관측 결과이며 최종 완료 판정은 계획 담당에게 반환한다.** 운영 수신 빈도·별도로 식별한 자연 수신 중 반응과 장시간 사용은 미검증이다.

제품 커밋 `221e84082a4230caca6b450cb3b2e0ee9d085ee8`, 브랜치 `role-workflow/20-60f149af`를 유지한다. 제품·시험 코드 변경, 새 커밋, 전체 회귀/합성 성능 재실행 및 푸시는 없다. 변경된 것은 로컬 설치 번들·무시 경로의 실행 증거·이 공식 보고서다. 아래 과거 보고의 설치 미실행 표시는 해당 회차 기록이며 현재 설치 상태는 이 절을 따른다.

## 보존·정상 종료·설치 대응

- 사용자가 모든 방·계정의 미전송 글·첨부·전송 중/실패 대기를 별도로 보존했거나 남아 있지 않음을 명시적으로 확인했다. 빈 화면만 보고 메모리 초안이 없다고 추측하지 않았다.
- 기존 설치본·packaging 후보·v3 복구본 해시 및 deep/strict 서명을 재확인했다. 기존 설치본은 복구본과 같은 실행 파일이었다. 다른 작업에 의한 교체는 확인되지 않았다.
- 기존 PID `4535`를 NSRunningApplication의 정상 종료 요청으로 종료했다. 요청 종료 0, 실제 종료 확인. 강제 종료 없음.
- 검토된 후보를 설치 위치의 임시 번들에 ditto로 준비하고 서명/해시를 확인한 뒤 설치 번들을 교체했다. 기존 번들은 `live/displaced-original.app`에도 보존하며 `v3/rollback/hejo.app`도 유지한다.
- `open` 정상 실행 종료 0. 새 PID `86124`의 실행 경로가 설치 위치의 실행 파일과 일치한다. 설치 파일 SHA-256은 `01827d9ce8acbe89c631e477f66977caaf2ce8e934aeefebcac13f510b57ca65`, BuildInfo는 `dirty=false`, tree `0beece585454a2410e835ddbdaeed60e0cc4181f`이며 검토 후보·커밋과 같다.
- 시작 직후 macOS 키체인 시스템 확인 창 때문에 연결이 대기했다. SecurityAgent 창의 HEJO/키체인 언급과 보안 입력 필드 존재만 확인했으며 입력 값은 읽지 않았다. 사용자가 Mac의 시스템 창을 직접 처리했다고 확인했고 창이 닫힌 뒤 연결 문제 표시가 사라졌다. 에이전트가 암호·토큰을 요청하거나 직접 읽고 입력하지 않았다. 정상 로그인/키체인 동작을 우회하지 않았다.
- 연결 후 기존 대화 기록·명부·알림이 실제 화면에 표시됐다. 전체 운영 저장소 바이트 동일성을 검사했다고 주장하지 않는다. 게이트웨이 재시작이나 운영 설정 수정 명령은 실행하지 않았다. 정상 앱 사용에 따른 연결·읽음·화면 상태 처리는 기존 앱 동작을 따른다.

## 실제 표시 앱 관측

실제 설치 앱의 창을 열고 Accessibility와 OS CGEvent를 사용했다. 합성 LocalStore/숨겨진 시험 창을 재실행한 결과가 아니다. 화면 이미지와 AX 역할/상태 기록은 무시 경로에만 보관하고 개인 대화·이름을 공개 보고에 복사하지 않는다.

시험은 홈↔첫 직접방을 3회 왕복하고 각 화면에서 입력과 스크롤을 3회씩 실행했다. 입력은 비어 있음을 확인한 실제 편집기에 Unicode 키 이벤트를 보내고, AX 값이 시험 문구와 일치하는지 확인했다. Return/전송 동작은 실행하지 않았다. 시험 문구만 선택해 Backspace로 삭제하고 원래 빈 값으로 복원됨을 매번 확인했다. 첨부를 추가·제거하지 않았다. 스크롤은 실제 기록 영역에 OS 휠 이벤트를 보내 스크롤바 값의 변화를 관측한 뒤 원래 위치로 복원했다.

| 실제 앱 관측(초) | 직접방 중앙값 / 최소~최대 | 홈 중앙값 / 최소~최대 |
|---|---:|---:|
| 키 이벤트 전송→AX 편집기 값 반영 | 0.050171 / 0.032822~0.056581 | 0.193401 / 0.158885~0.203601 |
| 사이드바 클릭→화면 모드 표시 변경 | 0.092152 / 0.075475~0.098549 | 0.185041 / 0.184611~0.297538 |

각 모드에서 입력 문구 반영·원래 빈 초안 복원 3/3, 스크롤 이동·원위치 복귀 3/3, 화면 모드 전환 3/3을 확인했다. 종료 시 홈 화면으로 돌아왔고 시험 전 접혀 있던 DM 목록도 다시 접었다. 최초 직접방 준비 관측도 별도 보존하지만 위 집계에는 정해진 3회만 사용한다.

이 수치는 OS 이벤트를 보낸 뒤 Accessibility에서 값을 관측하기까지의 왕복 상한이며 픽셀의 첫 표시 프레임이나 사용자 체감의 정밀 계측이 아니다. 전환은 기존 '새 글/새 대화' 버튼 문구로 홈/직접방 모드 변경을 확인했다. helper 전체 실행 시간에는 AX 트리 탐색·앱 활성화도 포함되므로 그 시간을 제품 렌더 시간으로 쓰지 않는다. 화면 캡처로 연결된 홈과 기록 표시도 직접 확인했다.

## CPU·sample과 남은 한계

설치 전 PID `4535`의 ps CPU 표본 3개는 35.7/43.8/35.6%였고 3초 sample을 수집했다. 새 앱의 키체인 확인 대기 상태 표본은 22.7/46.5/27.4%, 연결 후 UI 시험 인접 표본은 88.4/34.8/32.2%였다. 각각의 원시 조건과 PID를 분리했다. 연결 후에도 3초 sample을 수집했다.

관측 단계의 표시 화면과 입력/전환 부하가 달라 CPU 백분율의 전후 비율을 개선 폭으로 계산하지 않는다. 실제 앱 CPU가 0에 가깝다거나 합성 시험의 99.866% CPU 작업량 감소가 그대로 실환경에서 재현됐다고 주장하지 않는다. sample에는 날짜 해석·주기적인 알림/펫 갱신 비용이 여전히 보인다. 이번 실제 입력·전환 검사에서는 수십 초 정지나 재현 가능한 무응답이 관측되지 않았다.

운영 프레임의 종류별 도착 빈도는 측정하지 않았다. 연결/기록 복구는 확인했으나 관측 구간의 자연 수신 프레임을 독립적으로 식별해 그때의 반응을 측정하지는 못했다. 이를 시험 메시지 전송으로 보완하지 않았다. 장시간 사용·다른 모든 방·전송 경로도 이번 무송신 시험의 검증 범위가 아니다. 불명확한 값을 합격으로 만들지 않고 최종 검토에 남긴다.

## 실행 증거

아래 경로는 구현 worktree의 `.build/hejo-perf-evidence/` 기준이다. 개인 경로를 포함하는 sample과 실제 화면 이미지는 추적하지 않는다.

| 실행·검사 | 실제 결과 | 로그 |
|---|---|---|
| 후보·설치본·복구본 SHA/BuildInfo 및 codesign 재확인 | 서명 각각 종료 0, 기대 해시 일치 | `live/pre-install.json`, `live/*-codesign.log` |
| 사용자 미전송 항목 보존 확인 및 정상 종료 요청 | 사용자 확인, 요청 종료 0·PID 종료 확인, 강제 종료 없음 | `live/preservation-confirmation.json`, `live/terminate.log`, `live/termination.json` |
| ditto·스테이징 서명·번들 교체·open 및 설치/실행 대응 | copy/서명/open 각각 종료 0, 설치 해시·BuildInfo·새 PID 경로 일치 | `live/install-copy.log`, `live/install-codesign.log`, `live/installation.json`, `live/launch.log` |
| 키체인 시스템 창 상태·사용자 처리 확인 | 보안 입력을 읽지 않고 창 닫힘·연결 복구 확인 | `live/security-ax-confirmed.json`, `live/keychain-confirmation.json`, `live/after-auth-ax.json` |
| 로컬 LiveActions 도구 및 홈/직접방 3회 왕복·입력/스크롤 | 최종 컴파일·반복 실행 종료 0, 18개 동작 성공·복원 확인 | `live/live-actions-compile.log`, `live/round-*.json`, `live/live-results.json` |
| 실제 화면 관측 | 설치 앱 창 캡처 종료 0, 연결 후 홈·기록 표시 확인 | `live/after-auth.png`, `live/after-tests.png` |
| 설치 전·키체인 대기·연결 후 ps 및 3초 sample | ps 각각 종료 0, sample 세 번 각각 종료 0 | `live/pre-install.json`, `live/after-cpu-initial.json`, `live/after-cpu-connected.json`, `live/before-sample*`, `live/after-sample*`, `live/after-connected-sample*` |
| 최종 커밋·깨끗한 트리·설치/후보/복구 대응·원래 편집기 및 UI 상태·문서 검사 | 종료 0 | `live/final-validation.json` |

로컬 관측 도구의 첫 JXA 함수 노출 오류 및 Swift 문법/CF 캐스팅 컴파일 오류는 수정 후 재실행했다. 제품 코드를 수정한 실패가 아니다. 최초 부가 rg 조사에서 없는 소스 파일 이름을 사용한 경로 오류도 있었다. 실제 설치/관측 결과와 섞어 통과로 표시하지 않는다. 관련 초기 도구 로그를 보존한다.

## 반환과 복구

후보가 정상 실행되고 실제 UI 동작이 반영돼 악화에 따른 복구는 실행하지 않았다. 복구가 필요하면 새 미전송 항목의 보존을 다시 확인하고 앱을 정상 종료한 뒤 `v3/rollback/hejo.app`을 복원·정상 실행하고 기존 해시를 확인한다. 강제 종료·게이트웨이·운영 설정 변경은 하지 않는다.

계획 담당이 설치/실행 대응, 사용자 보존 확인, 실제 GUI 관측·CPU/sample 및 미검증 범위를 검토한다. 실제 사용 중 멎음이 다시 나타나면 그 조건을 근거로 원인을 재조사한다. 현재 명세 반영·최종 완료·푸시 대상/승인 판정은 계획 담당에게 남긴다. 직접 푸시하지 않았다.

---

# 이전 구현 인계: V-HP-05 패키징 보완 (3회 검토 수락)

[확인] [handoff](handoff.md)의 현재 후속 인계와 [verdict](verdict.md) 2회 검토에 따라 패키징만 보완했다. 새 후보의 Google 두 설정이 모두 존재하며 기존 설치본·복구본과 일치한다. 정상 배포 입력으로 빌드·서명 및 관련 로컬 부트스트랩 검사를 통과했다. **실제 앱 교체·응답성 확인은 미실행이므로 전체 목표는 미완료**다. 설치·재시작·실제 메시지 전송·푸시를 하지 않았다.

제품 커밋은 `221e84082a4230caca6b450cb3b2e0ee9d085ee8`, 브랜치는 `role-workflow/20-60f149af` 그대로다. 제품 소스 99개·빌드 입력의 전후 해시와 깨끗한 worktree를 확인했다. 추적 파일 변경과 새 커밋은 없다. 이번 변경은 무시되는 패키징 산출물과 계획 담당 공식 폴더의 이 보고서뿐이다. 기존 전체 회귀·성능 검증 및 동결 fixture는 반복하거나 수정하지 않았다.

## 정상 배포 입력과 산출물

기존 계획 담당 checkout의 무시되는 `config/google-oauth-secret.json`이 정상 배포 입력으로 존재했다. 구현 worktree에는 이 파일과 사전 설정된 배포 환경 변수가 없었다. 기존 파일을 빌드 제어 프로세스의 메모리에서 읽고 `HEJO_GOOGLE_CLIENT_SECRET` 환경으로 빌드 하위 프로세스에 전달했다. 비밀 입력 파일을 복사하지 않았으며 운영 비밀·다른 앱에서 값을 가져오지 않았다. 공개 입력은 두 checkout에서 일치했다. `HEJO_SKIP_GOOGLE_SECRET`은 설정하지 않고 기존 `app/scripts/build.sh`를 실행했다. 검사 로그에는 값을 출력·기록하지 않았고 빌드 로그도 구성 값을 가려 저장했다. 입력 파일·제품 빌드 스크립트·운영 설정은 변경하지 않았다.

현재 설치 검토용 후보는 구현 worktree의 **`.build/hejo-perf-evidence/packaging/artifacts/hejo.app`**이다. 기존 `v3/artifacts/hejo.app`과 v3 원시 증거는 그대로 보존했으며, 기존 시험용 후보를 설치에 사용하지 않는다. 아래 이전 보고서의 v3 후보 설명은 해당 회차 기록으로만 보존한다.

- 검토 커밋: `221e84082a4230caca6b450cb3b2e0ee9d085ee8`.
- BuildInfo: `dirty=false`, tree `0beece585454a2410e835ddbdaeed60e0cc4181f`. 검토 커밋의 전체 tree와 일치한다.
- 새 후보 실행 파일 SHA-256: `01827d9ce8acbe89c631e477f66977caaf2ce8e934aeefebcac13f510b57ca65`.
- Google 설정: ClientID·ClientSecret 모두 존재. 정상 배포 입력·현재 설치본·기존 복구본과 각각 동일. 존재·동일 여부만 기록한다.
- 소스·입력 해시: `packaging/inputs.json`, 산출물 대응: `packaging/artifacts/receipt.json`. 비밀 입력 값이나 개별 비밀값 해시는 기록하지 않는다.
- 기존 복구 번들은 `v3/rollback/hejo.app` 그대로다. 설치본·복구본 실행 파일이 기존 준비 기록과 같음을 확인했다. 초안 보존 후 정상 종료·백업 복원·정상 실행이라는 복구 절차를 유지한다. 이번 단계에서 실행하지 않았다.

## 이번 검증

다음 경로는 구현 worktree의 `.build/hejo-perf-evidence/` 기준이다. 자체 점검이며 최종 검토 판정은 계획 담당에게 반환한다.

| 명령·검사 | 실제 결과 | 로그 |
|---|---|---|
| 확인된 Python으로 `packaging/build_package.local.py` → 정상 `bash app/scripts/build.sh` | 종료 0. 생략 옵션 없이 배포 입력 반영, 최적화 빌드·서명·deep/strict 검증 | `packaging/build.log`, `packaging/build-exit.json`, `packaging/inputs.json` |
| `codesign --verify --deep --strict` 새 후보 | 종료 0 | `packaging/codesign.log`, `packaging/artifacts/receipt.json` |
| 확인된 Python으로 `packaging/verify_package.local.py` | 종료 0. 커밋·99개 제품 소스/빌드 입력·BuildInfo·바이너리 해시, Google 구성 존재/동일 및 기존 증거 보존 대조 | `packaging/verification.log`, `packaging/artifacts/receipt.json`, `packaging/bundle-capabilities.json`, `packaging/prior-evidence.json` |
| `xcrun swiftc`로 변경 없는 `GoogleSignIn.swift`와 로컬 bootstrap probe 빌드 | 종료 0 | `packaging/bootstrap-compile.log`, `packaging/bootstrap-compile.exit` |
| 네트워크 차단 하의 구성 포함/누락 시험 번들 실행 | 각각 종료 0. 구성 포함은 production `GoogleSignIn.bundled` 읽기·후보 값 일치·인증 URL/토큰 요청 구성·기존 PKCE 벡터 통과. 두 키를 제거한 대조 번들은 bundled client가 nil임을 확인 | `packaging/bootstrap-results.json`, `packaging/bootstrap/with-google.log`, `packaging/bootstrap/without-google.log` |
| `git diff --exit-code 221e84082a4230caca6b450cb3b2e0ee9d085ee8 -- app/Sources gate hub` | 종료 0. 제품 무변경 | `packaging/final-validation.json` |

부트스트랩 검사는 별도 로컬 시험 번들에 후보의 구성을 적용하고, 변경 없는 제품의 Google 설정 소비자 및 순수 요청 구성을 실행했다. OS sandbox로 네트워크를 차단했다. 후보 앱 자체나 기존 설치 앱을 실행하지 않았고, 브라우저·Google 인증·토큰 교환·실제 메시지를 실행하지 않았다. 실제 로그인 성공이나 실제 앱 응답성을 검증한 것으로 표시하지 않는다. 제품이 그대로이므로 기존 전체 회귀·성능 검증을 재사용했으며 새 전체 검사는 실행하지 않았다.

## 남은 작업

계획 담당이 V-HP-05 보완 후보·구성 동등성·서명·소스 대응·로컬 부트스트랩 근거를 검토한다. 수락 후 TASK-04의 실제 설치·초안 보존·정상 재실행 및 입력/스크롤/방 전환·CPU/sample 관측을 별도로 진행해야 한다. V-HP-03 실환경 검증과 전체 완료·푸시 판정은 남아 있다.

---

# 이전 구현 인계: HEJO-PERF / TASK-01B~03 (2회 검토 수락)

## 결과와 검토 대상

[확인] v3 인계 범위의 제품 수정·자체 검증·실제 앱 검증 준비를 마쳤다. **전체 목표는 부분 구현 상태**다. 설치 앱 교체와 실제 입력·스크롤·방 전환 관측은 TASK-04 검토 뒤에 남아 있다. 합성 시험 통과를 실제 앱 응답성 회복이나 최종 완료로 판정하지 않는다. 푸시 미실행이며 승인 요청 단계가 아니다.

- 받은 설계: [handoff](handoff.md), [design](design.md), [verdict](verdict.md)의 V-HP-02·04와 [수락 명세 v3](../../../tests/acceptance/HEJO-PERF.md). 호스트가 TASK-01B~03 실행을 전달했으며 기존 승인을 변경 인계에 임의 승계하지 않았다.
- 착수 커밋: `977cecd903a51538e2817331fe107dccf0a3267a`. 원래 제품 기준: `39f954c1bd3a50fd27d4f11a3b03774d0e74aa41`.
- 검토 커밋: `221e84082a4230caca6b450cb3b2e0ee9d085ee8`, 브랜치 `role-workflow/20-60f149af`. 구현 worktree는 호스트가 배정한 경로이며 깨끗하다. 본 공식 보고서는 계획 담당 작업 폴더에만 있고 구현 커밋에는 포함되지 않는다.
- 변경 성격·위험: 동작 보존 성능 수정, 일반 위험 유지. 프레임 순서·저장·권한·동시성 계약과 수락 기준을 바꾸지 않았다. 게이트웨이·본체·ddots·운영 설정 변경과 실제 메시지 전송 없음. 하위 에이전트 없음. 자체 점검이며 독립 검토가 아니다.

## 구현과 책임 배치

기존 Controller의 `performUpdates`로 receive 전체와 전용 응답·조기 반환을 감싸 최종 화면 통지를 반환 전에 전달한다. 전역 notifyChange를 지연시키지 않으며 저장·적용·전송 확인 부작용도 유지한다. 별도의 수신 스케줄러·debounce·비동기 투영을 만들지 않았다.

Model이 한 동기 조회 범위에서 메시지 분류·정렬, 스레드, assessment, notices, 날짜 해석·홈 정렬 키와 sidebar 결과를 공유한다. 범위가 끝나면 폐기하며 직원·방·메시지·회원 상태 변경 시 기존 범위를 비운다. 범위의 시각은 고정하고 명시적 now는 별도 키로 구별한다. View 렌더 도중 동기 상태 변경이 있으면 변경된 상태로 렌더를 마친다. 이 반복은 렌더에만 적용되며 수신 프레임이나 사용자 변경 동작을 다시 실행하지 않는다. 장기 캐시·디스크 캐시·전역 버전 장부·새 서비스 없음.

홈 정렬은 스레드별 최신 날짜를 먼저 구하고 기존 날짜·ID 비교를 유지한다. 직접방 replyButton은 홈 여부를 먼저 분기한다. 전환 중 최신 스레드 조회도 한 범위를 공유한다. 정규 초 단위 UTC 날짜는 Foundation의 빠른 파서가 정확히 같은 문자열로 왕복되는 경우 사용하며, 다른 형식·정규화 사례는 기존 ISO8601DateFormatter 해석을 유지한다. 소수 초·시차·윤초·잘못된 날짜와 달력 경계 840개를 기존 ThreadTools.date와 대조했다.

| 변경 파일 | 이유 |
|---|---|
| `app/Sources/ConversationController.swift` | 기존 동기 transaction에 수신 통지 통합, 서랍의 시각을 렌더 범위와 공유 |
| `app/Sources/ConversationModel.swift`, `WorkspaceTools.swift` | 원본 모델 안에서 파생값 재사용·상태 변경 시 폐기, notices 중복 도출 제거 |
| `app/Sources/ConversationView.swift` | 렌더 범위 적용·중첩 상태 변경 반영, 직접방 홈 정렬 제거, 최신 스레드 조회 공유 |
| `app/Sources/TodoDrawerModel.swift` | 같은 렌더의 날짜 해석 결과 소비 |
| `app/Tests/HejoPerfRegressionTests.swift` | 최종 통지와 실제 View·시각·읽음·확인·오류·홈 범위·첨부·버튼 회귀 |
| `app/Tests/HejoPerfTests.swift`, `TestMain.swift`, `hejo_perf.py`, `app/scripts/test.sh` | 별도 홈/회귀 실행, 테스트 전용 도출 계측, v3 예산 검사·원본 증거 보호 |
| `app/Tests/Fixtures/HejoPerf/README.md` | V-HP-02 측정 구간 정정 및 비교 명령 설명 |

대체한 중복 경로는 해당 호출자에서 통합·제거했다. ThreadAssessment 판단 의미와 ThreadTools.date의 원래 구현은 유지한다. 테스트 전용 관측자는 일반 제품 빌드에 포함되지 않는다. 원래 기준 입력·기대값·manifest JSON과 기존 기준 계측·실행 파일은 보존했으며 재동결하지 않았다.

## 검증 기록

이하 로그 경로는 구현 worktree의 `.build/hejo-perf-evidence/` 기준이다. 최종 비교·후속 산출물은 `v3/`에만 둔다. 컴파일 당시 HEAD를 기록한 check/regression의 실행 기록은 착수 커밋과 제품 diff를 포함한다. 최종 `v3/artifact-audit.json`에서 전체 Swift 입력·실행 파일·현재 커밋의 대응을 직접 확인했다. measure/home 실행 기록은 검토 커밋을 기록한다.

| 명령·검사 | 실제 결과 | 로그 |
|---|---|---|
| 확인된 Python의 의존성 import 및 로컬 PyYAML 설치 | 종료 0. Python 3.14.7, PyYAML 6.0.3은 무시되는 작업 폴더에만 설치. SDK·기존 가상환경 무변경 | `v3/dependencies-with-sdk.log`, `v3/python-local-install.log`, `v3/pyyaml-import.log` |
| `HEJO_PERF_SPARKLE_DIR=<캐시> "$hejo_python" app/Tests/hejo_perf.py check --evidence .build/hejo-perf-evidence/v3` | 종료 0. 최적화 Swift 빌드·58단계 동결 기대값 바이트 일치 | `v3/compile.log`, `v3/build.json`, `v3/check-command.log`, `v3/check/` |
| 같은 runner의 `regression --no-build --evidence .build/hejo-perf-evidence/v3` | 종료 0. 실제 View HP-01~03 및 기존 열기/닫기 캡처 검사 통과 | `v3/regression-command.log`, `v3/regression/run.log`, `v3/regression/execution.json` |
| 같은 runner의 `measure --no-build --evidence .build/hejo-perf-evidence/v3` | 종료 0. warm-up 1회 제외 5회, 의미·부하 동일, 모든 v3 예산 통과 | `v3/measure-command.log`, `v3/measure/{run.log,execution.json,performance.json,summary.json,budgets.json}` |
| 같은 runner의 `home --no-build --evidence .build/hejo-perf-evidence/v3` | 종료 0. 같은 입력으로 홈에서 시작한 별도 5회, 의미·부하 동일, 예산 통과 | `v3/home-command.log`, `v3/home/{run.log,execution.json,performance.json,summary.json,budgets.json}` |
| `HEJO_PYTHON="$hejo_python" bash scripts/test.sh` | 종료 0. Python 427개, 격리 실제 gateway 전달, 전체 AppKit 단위·로컬 네트워크 fixture·hook 9개 통과. 실제 CLI 설정 메타데이터·다운로드 이름 보존 | `v3/full-regression.log`, `v3/full-regression.exit` |
| 위 전체 시험 안의 `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash scripts/build.sh` (app 폴더) | 종료 0. 최적화 앱 생성·서명·deep/strict 검증. 별도 전체 재빌드 중복 실행 안 함 | 같은 로그의 BUILD_OK 및 AT-HF-23 |
| `"$hejo_python" .build/hejo-perf-evidence/v3/mutation_check.py` | 종료 0. 두 변이 컴파일 0, 실행 각각 1로 해당 결함 검출. 원본 제품은 수정하지 않고 무시 폴더의 소스 사본만 사용 | `v3/mutation-command.log`, `v3/mutations/*/{compile.log,run.log,result.json}`, `v3/mutations/summary.json` |
| `HERMES_HOME=<가짜 홈> "$hejo_python" scripts/scan_private.py` | 종료 0. 본 작업 staged 11개 포함. 가짜 team/vault만 사용 | `v3/scan-private.log`, `v3/scan-private.exit` |
| `git diff --cached --check` | 종료 0 | `v3/diff-check.log` |
| 기본 증거 경로에서 `hejo_perf.py check --no-build` | 의도한 종료 1. 수정 빌드가 기존 기준 증거를 덮어쓰기 전에 거부 | `v3/baseline-write-guard.log`, `v3/baseline-write-guard.exit` |
| `"$hejo_python" .build/hejo-perf-evidence/v3/audit_final.py` | 종료 0. 원시 5회·요약 재계산·동결/부하/기존 증거/전체 입력/바이너리/커밋·앱/복구 번들 대조 | `v3/artifact-audit.log`, `v3/artifact-audit.json` |

전체 시험은 짧은 임시 HERMES_HOME·TMPDIR·pytest basetemp와 가짜 입력을 사용했다. Python은 같은 확인된 인터프리터를 사용하며 SDK 소스와 선택 team-kit 라이브러리를 읽기 전용 import 경로로 지정했다. 실제 운영 명부·비밀 파일은 열지 않았다. 임시 전체 시험 홈은 종료 뒤 제거했다. 재현 환경 설명은 `v3/environment-summary.local.json`이며 개인 경로를 포함하므로 추적하지 않는다.

HP-01은 welcome/roster/message/edit/state/delete/typing/sync_done, 오류·전용 응답과 최종 커서를 반환 전에 관측한다. HP-02는 실제 sidebar·카드·drawer의 방별 notices, assessment와 전체 분류 도출 횟수를 검사한다. HP-03은 같은 범위·렌더 중 상태 변경, 다음 렌더, 다른 모델, 명시적 now, 24시간 만료, 읽음·확인, roster·홈 범위, 스트리밍·삭제·오류 뒤 정상 입력, 날짜·ID 정렬을 검사한다. 실제 첨부 타일·서버 버튼 문구·직접방 답글 버튼 상태와 기존 ConversationUpdateTests의 동기 열기/닫기 캡처를 포함한다. 변이는 수신 batching 제거와 캐시 무효화 제거를 각각 검출했다.

### 실패 기록과 처분

- `v3/attempt01/`: 최초 Swift 컴파일 실패를 sidebar 내부 함수의 MainActor 지정으로 수정했다.
- `v3/attempt02/`: 수신·전환·CPU 예산 미달. 프로파일과 날짜 파서 비교에서 반복 날짜 해석 비용을 확인하고 렌더 범위 날짜 공유를 보완했다.
- `v3/attempt03/`: 전환 동작 중앙값 약 0.311초로 예산 미달. 최신 스레드 선택의 조회 범위가 분리된 것을 통합했다. 기준·입력을 줄이거나 예산을 바꾸지 않았다.
- `v3/attempt04/`: 합격한 중간 빌드와 결과를 보존한다. 이후 프레임별 통지·버튼 회귀와 증거 덮어쓰기 방지를 추가한 최종 변경본으로 다시 검증했다.
- `v3/full-regression-attempt01.log` 종료 1: 240 통과·3 실패·184 오류. AF_UNIX 경로 길이와 PyYAML 누락을 진단했다. 짧은 임시 경로 및 작업 폴더 내 PyYAML로 해결했다. `attempt02` 종료 1: 426 통과·1 실패, 선택 team-kit 모듈 누락. 기존 라이브러리의 읽기 전용 경로 연결 후 관련 2개 검사와 전체 427개가 통과했다. 제품 게이트 코드를 고치지 않았다.
- 기존 Swift 경고·SDK deprecated 경고는 로그에 보존한다. 추가 단위 프로세스 sample 시도는 프로세스가 이미 종료돼 255였으며 표본이 없다(`v3/unit-sample-command.log`). 이를 성능·실앱 증거로 사용하지 않는다.

## 성능 비교

[확인] 같은 머신·Swift 5 언어 모드·최적화 `-O`·macOS 13 이상 대상에서 가짜 방 8개 × 스레드 100개 × 글 4개를 사용했다. 초기 로딩·최초 layout은 측정 밖이며 각 모드에서 warm-up 1회 뒤 5회를 집계한다. 수락 명세가 합격선 원본이며 아래는 관측값이다. CPU 시간은 같은 완료 구간의 user+system 증가량이다.

**V-HP-02 정정:** receive 타이머는 `store.append` 직전부터 Controller.receive의 동기 화면 통지 반환까지다. append를 포함한다. 기존 원시 수치는 바꾸지 않았고 README와 이 보고서의 설명을 바로잡았다. 전체 벽시계에는 큐와 입력·전환 동작이 포함된다.

| 초 단위 지표 | 기존 직접방 중앙값 | 수정 직접방 중앙값 / 최대 | 수정 홈 중앙값 / 최대 |
|---|---:|---:|---:|
| receive 개별 20개 | 96.558 | 0.107790 / 0.123695 | 0.108031 / 0.109485 |
| 입력 큐 대기 | 96.703 | 0.109722 / 0.136960 | 0.114708 / 0.120548 |
| 방 전환 큐 대기 | 96.704 | 0.109912 / 0.137287 | 0.222043 / 0.231240 |
| 방 전환 동작 | 48.309 | 0.111253 / 0.114271 | 0.111082 / 0.115999 |
| 편집 4개 전체 벽시계 | 434.694 | 0.588173 / 0.617615 | 0.697890 / 0.708334 |
| 프로세스 CPU 시간 | 434.344 | 0.581187 / 0.612249 | 0.696229 / 0.705315 |

직접방 CPU 작업량은 기준 대비 **99.866% 감소**했다. 홈의 CPU 시간도 같은 기준보다 99.840% 적다. 5회 모두 입력·방 전환이 수신 종료 전에 실행됐으며 음수·누락이 없다. 편집 4개당 화면 통지는 기준 8회에서 4회로 줄었다. 원시 5회·요약·개별 receive 20개를 직접 대조했고 workload SHA는 기준과 동일하다. 비교 원본과 정확한 최소/최대는 원시 결과·audit가 원본이다.

840×760 NSWindow에 실제 View를 붙였지만 화면에 표시하지 않은 AppKit 측정이다. 홈 모드는 홈에서 시작하고 동일한 큐 동작이 다른 직접방으로 전환한다. OS 키보드·픽셀 표시 지연·실제 socket 빈도·설치 앱 체감의 측정이 아니다. 완료 구간 CPU 비율은 직접방 중앙값 약 99.234%, 홈 약 99.536%로 여전히 높다. 이는 작업 시간이 짧아진 완료 구간 비율이며 CPU 시간 감소와 구별한다.

## 검증 산출물과 복구 준비

- 설치 후보: 구현 worktree의 `.build/hejo-perf-evidence/v3/artifacts/hejo.app`. `artifacts/receipt.json`에 전체 제품 소스·실행 파일 SHA와 검토 커밋 대응을 기록했다. deep/strict 서명 검증 종료 0.
- BuildInfo: `dirty=false`, tree `0beece585454a2410e835ddbdaeed60e0cc4181f`, 위 검토 커밋의 전체 tree와 일치한다. 후보 실행 파일 SHA-256: `4b086223f11d14fa4471e146b24375decf091b3a74a26861fe0c0ddcea6300c8`.
- 기존 설치 앱 백업: `.build/hejo-perf-evidence/v3/rollback/hejo.app`. 복사 종료 0, 설치본과 실행 파일·BuildInfo 일치, deep/strict 서명 검증 종료 0. `rollback/preparation.json`과 `codesign.log` 참조. 기존 설치본은 dirty 빌드이므로 원래 기준 소스와 같다고 주장하지 않는다.
- 복구: 초안 보존을 확인하고 정상 종료한 뒤 백업 번들을 설치 위치에 ditto로 복원하고 정상 실행한다. 운영 기록·설정과 게이트웨이는 건드리지 않는다. 강제 종료하지 않는다.

[미실행] 설치 앱 교체·재실행, 실제 포화 상황 CPU 및 3초 sample 재수집, 실제 입력·스크롤·방 전환 반복 관측. 운영 프레임 종류/빈도도 기존 전용 집계 부재로 미측정이며 합성 부하를 운영 빈도로 간주하지 않는다. 기존 모델 오류 안내가 다음 정상 프레임 뒤에도 남는 기준 동작은 보존했다.

## 다음 검토

계획 담당이 위 커밋의 코드·수락 명세·원시 결과·산출물·복구 준비를 검토한다. TASK-04에서 검증된 후보의 설치와 실제 앱 관측 범위를 이어갈지 판단하며, 문제가 남으면 새 원인을 조사한다. 실제 앱 개선과 현재 명세 반영 전 전체 완료를 선언하지 않는다. 푸시 검토 단계에서는 기준 브랜치의 로컬·원격 추적 tip 포함 여부를 다시 확인하고, 사용자가 화면에서 승인한 대상만 플러그인이 푸시한다.
