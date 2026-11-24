# 구현 인계: Google 개인 연결 해제·계정 선택

## 현재 판단과 범위

**왕복19 지정 시험 통합·지원 식별 갱신 검증 제출.** 고정3adfa6c9의 지정5시험만 통합하고 운영 전체 기준은 고정8bf1ef46에서 재현했다. 관련4파일296경우와 Google/Notion 통합13경우가 통과했고 이전12실패 노드도 각각 통과했다. 실행 제품 코드·앱·검사 강도는 바꾸지 않았다. 최초 전환→전체 bundle 및 거절/CAS/복구 표적7경우도 통과했다. 전체 team 성공을 주장하지 않는다. 전달/복구 후보와 후속 커밋·읽기 전용 시설 대조 결과는 왕복19 최종 증거에 고정하며 실제 운영 적용은 검토 뒤로 남긴다.

원래 목표는 해당 직원 Google 개인 연결·이메일·전용 자격을 제거하고 다음 연결에서 계정을 선택하는 것이다. 기존 금고 원본과 전용 저장 배치, 공식 도구 4개, gate/AppKit 구현을 보존했다. 본체·ddots·sandbox 정책·운영 비밀 파일·Paseo 상태 JSON·계획/수락 명세 Markdown은 변경하지 않았다. 기존 구현을 유지하며 왕복11에서 인증 시트의 명시적 닫기 동작과 취소된 폴링의 응답 후 보호, 해당 표적 시험을 보완했다. 원래 폴더의 다른 작업도 보존했다. 구현 소유 보고·배포 인계와 [명령 대응표](workspace-command-map.md)를 canonical 폴더에서 관리한다.

## 저장소·검토 변경본

| 저장소 | HEAD/기준 커밋 | 브랜치 | 격리 위치 |
|---|---|---|---|
| hejo | `236b0177468b90d9ea23a1b1190e996db78a0694` | `role-workflow/google-disconnect-c20a9994` | `.build/google-disconnect-work/hejo` |
| 운영 저장소 | `4bbc16ddba02236fe4645ab7244603c44a78af91` | `role-workflow/google-disconnect-c20a9994` | `.build/google-disconnect-work/team` |

경로는 원래 작업 폴더 기준이다. 위 표는 구현 전 기준이며 현재 실행 소스 커밋은 hejo `09a5d31db54620814203fc079f706501b2b92bb0`, 운영 저장소 `1af03d46dabdbe49f4e3ef3ca92aaaf2b321371d`다. 제품·시험은 source-checkpoint-13.log와 같고 최종 변경 집합은 hejo54/team88파일이다. canonical 최신 검토 문서4개와 구현 보고/배포 인계2개만 전달 준비에서 갱신했다. 왕복17 앱 빌드 소스는 hejo ac4643abdbe05be788ebbb31ece600cd808cf8de의 clean 상태다. 왕복17 고정 파일 지문은 source-checkpoint-15.log와 round17-closure.json이다. 이번 왕복18 중단 보고는 같은 HEAD 위의 문서2개 미커밋 변경이며 source-checkpoint-16.log와 round18-final-check.json에 기록한다. 제품/시험/지원 선언과 시설/앱 실행 소스는 그대로다. 기존 커밋을 amend/rebase/pull/merge하지 않았다.

## 왕복19 — 승인된 시험 보존과 고정 시설 식별 갱신

checkpoint16의 두 HEAD/142파일 및 기존 미커밋 보고2개를 보존한 뒤 tasks 왕복19를 실행했다. 시험 출처는3adfa6c9c1ffcb794f73cfb56a0cea2b04363acb이며 지정 helper와4시험5본문만 반영했다. 해당5본문이8bf1ef46d12aae051b61e07d6632a08a6bb95831과 같은 것도 대조했다. 두 커밋 사이의 다른6제품/시험 경로는 checkpoint16 그대로 보존했다. 전체 merge/pull/rebase/reset이나 다른 작업의 main/푸시는 실행하지 않았다.

기존 단일 정책/installer는 불변이다. hejo legacy 선언과 team predecessor의 전체 기준만 고정8bf1ef46의 Git archive에서 재현했다. hejo 고정 출처 a3df84e48fae8b36c27a572a5ee36247cc46acf3는 그대로다. 기준 kit 식별은26dbd3ced1ae525f91a2cf5bf62a4c7403f95bfbeadda73036ed5eac352244b2, 시험 보존 candidate는c1b1a81e4dda23858ff0cb84e48432658ae06cf97bbc3e8b9305443d527ef5f0다. 허용 경로/지원 버전/검사 강도를 바꾸거나 운영 바이트로 즉석 허용 목록을 만들지 않았다.

| 검증 | 실제 결과 | ignored 증거 |
|---|---|---|
| round19-intake.py | 종료0. checkpoint16·원문5blob/두 출처 동일성·나머지6차이·최신 문서 대조 | round19-intake.json/log |
| round19-support.py | 종료0. 고정 Git으로 전체 legacy/predecessor/candidate 선언 재현·지원 검증 | round19-support.json/log |
| round19-tests.py 최종 실행 | 종료0,309 passed/skip0. 임시 plugin-store/두 플러그인·가짜 홈에서 기존 conftest 사용, hejo gate PYTHONPATH 제공 | round19-tests-03.json/log,round19-tests-03-junit.xml |
| round19-legacy.py | 종료0,7 passed. 실제 release 최초 전환→설치된 checker→전체 bundle, 코드/동반/전환 거절·team CAS·쓰기 실패 원상 복구·지속 복구 실패 닫힘 | round19-legacy.json/log |

JUnit에서 이전12노드의 현재 정확한 이름을 각각 찾아 모두 통과했음을 확인했다. 이는 승인된 원문5시험을 통합한 이 후보의 표적 해소 증거다. 타 작업296통과를 승계하지 않았고 전체 team 시험을 새로 통과했다고 표시하지 않는다. 기존 Google/Notion13경우의 기대값은 불변이다.

초기 준비 실패를 보존한다. 첫 실행은 러너가 기존 pytest 의존 경로를 누락해 pytest 시작 전에 종료1이었고 JUnit 부재를 읽다가 driver도 종료1이었다. 다음 실행은308통과/Google 조립1실패였다. 납작한 임시 kit 사본이 형제 team-delegation과 원래 team-kit 경로를 빠뜨려 실제 조립을 못 한 시험 환경 문제였다. 원래 plugin-store 계층의 사본으로 보완한 최종 실행에서309개가 모두 통과했다. 제품/기대값 수정·skip·새 의존성 설치는 하지 않았다. 기존 conftest의 쓰기 대상은 사본 fixture와 임시 홈으로 격리했고 실행 뒤 worktree kit 지문 불변을 확인했다.

실제 source 커밋·새 hejo/team/전체 복구·manifest 식별과 읽기 전용 사전 검사 결과는 round19 최종 JSON/로그와 [배포 인계](deployment-handoff.md)에 고정한다. 정식 앱은 round17 압축0ef168c84e8109755c6cc2aeca4e82495a8b86855948b8a597a5d76ccc8211fa를 그대로 재사용하며 재빌드/재서명하지 않는다. 이전 후보/실패 증거는 보존한다. 기존 운영 승인 대상/중단·재개 범위는 확대하지 않으며 이번 보완에서는 운영 쓰기·서비스 중단·실계정·메시지·푸시를 실행하지 않는다. 적용 재개·GD-T19·TASK07은 갱신 후보 검토 뒤 단계다.

## 왕복18 — 승인된 운영 적용의 사전 검사 중단

[확인] 사용자는 고정 후보 ac4643abdbe0-1af03d46dabd-configured-round17의 기존 대상 적용·기존 앱 정상 종료·메일 신호/gateway 중단·재개 및 인계서의 조건부 복구를 승인했다. 허브 재시작·미설치 프로필 추가·메시지 발송·자동 실계정 동의·푸시는 제외했다. round17-approval-proposal.json의 false 표시는 제안 작성 당시 기록이며 이번 사용자 승인으로 해석한다. 원본 제안/호스트 상태 파일은 수정하지 않았다.

[확인] 운영 쓰기 전에 승인된 manifest SHA-256 `66712741c306079ca9a930732893a53f57adcf0d32f932159294637942233539`와 전달/복구 압축3개씩을 대조했다. checkpoint15의 두 HEAD/142파일·clean도 일치했다. 전체 hejo 시설·고정 RELEASE·홈 집합·installed 영수증·기존6링크·기존 서비스 plist2개는 승인 기준과 같았다. **team-kit 전체 식별이 달라 GOOGLE_BUNDLE_KIT_MISMATCH로 거절돼 적용하지 않았다.**

| 시설 | 고정 legacy 기준 식별 | 실제 관측 식별 | 결과 |
|---|---|---|---|
| hejo | `27fdfaa498dbfd1b5cf8fee3e79bdbbf9fb6b66acffab97a0b5bfc90754fe767` | `27fdfaa498dbfd1b5cf8fee3e79bdbbf9fb6b66acffab97a0b5bfc90754fe767` | 일치 |
| team-kit | `bb999c4c0934d202c01f94da5554584e33d65dd72ce241da841be99c75061da5` | `26dbd3ced1ae525f91a2cf5bf62a4c7403f95bfbeadda73036ed5eac352244b2` | 불일치 |

읽기 전용 상세 대조에서 차이는 테스트5파일뿐이었다. 기준705항목과 실제708항목은3추가/2변경이며 나머지 시설 항목과 동반5경로는 같았다. 아래 실제5본문은 운영 저장소 후속 HEAD `8bf1ef46d12aae051b61e07d6632a08a6bb95831`의 Git blob과 일치했다. 이 출처 확인은 새 legacy 기준 채택이나 덮어쓰기 승인이 아니다.

| team-kit 상대 경로 | 기준 대비 |
|---|---|
| tests/hna_connections.py | 추가 |
| tests/test_app_scope.py | 본문 변경 |
| tests/test_hna.py | 추가 |
| tests/test_hna_r1.py | 추가 |
| tests/test_notion.py | 본문 변경 |

검사기는 테스트도 포함한 전체 시설 식별을 요구한다. 테스트만의 변경이라는 이유로 제외/삭제하거나 지원 선언을 늘려 승인한 것으로 만들지 않았다. 후속 테스트를 격리 후보에 복사하지 않았고, 기존 Notion12실패가 해소됐다는 검증도 수행하지 않았다. 기대값/skip은 수정하지 않았다.

| 명령 | 실제 결과 | ignored 증거 |
|---|---|---|
| python3 -B .build/google-disconnect-evidence/round18-preflight.py | 종료2. 전달/복구 지문·hejo/설치/토폴로지/서비스 설정은 일치, team 전체 식별 불일치로 사전 중단 | round18-preflight.log/json |
| python3 -B .build/google-disconnect-evidence/round18-drift.py | 종료0. 전체 식별 재현,5테스트 본문/모드·추가 항목 대조, 후속 Git 본문 출처·동반5경로 확인 | round18-drift.log/json |

[미실행] 작업/인증 유휴·현재 서비스 프로세스 상태 확인은 선행 시설 조건 실패 뒤 진행하지 않았다. 기존 앱 정상 종료, 서비스 중단/재개, 새 공유 release/bundle 경로 준비, --upgrade-legacy, bundle apply, 앱 교체, 조건부 복구를 모두 실행하지 않았다. 운영 시설/설정/키체인/권한/자격에 쓰지 않았고 비밀 파일을 열지 않았다. GD-T19는 적용 성공 뒤 사용자 직접 계정 선택/동의 단계로 남는다. TASK07·실계정·허브 재시작·메시지·푸시도 미실행이다.

[미확정] 기획·검증 담당이 이5테스트와 고정 legacy 전체 식별의 처분을 판단해야 한다. 선택지는 후속5테스트를 보존할 원본/후보 통합과 고정 기준의 최소 보완을 검토하거나, 현재 후보 적용을 보류하는 것이다. 구현 권고는 출처가 확인된5테스트를 보존하는 좁은 보완 판단이며 테스트 삭제나 식별 검사 완화가 아니다. 현재 지원 기준과 실제 시설이 같다는 근거 없이 이 후보를 재실행하지 않는다. 제품 소스·후속 기준/후보를 바꾸는 판단은 이번 운영 실행 역할에서 임의로 하지 않았다. 후보/복구 파일은 그대로 보존했다. 개인 실제 경로/파일별 SHA·영수증/홈 대응은 위 ignored 증거에만 기록했다.

## 왕복17 — 승인된 기존 입력으로 정식 앱 빌드

checkpoint14의142파일·hejo HEAD ac4643abdbe05be788ebbb31ece600cd808cf8de·team HEAD 1af03d46dabdbe49f4e3ef3ca92aaaf2b321371d 및 clean을 먼저 확인했다. 제품/시험/지원 선언을 바꾸지 않았다. 원래 작업 폴더의 기존 빌드 입력은 존재했고, 격리 worktree에는 자격 파일을 복사하지 않았다. 빌드 도구 안에서만 기존 입력을 소비해 HEJO_GOOGLE_CLIENT_SECRET 자식 환경으로 전달했다. 값·전체 환경·Info.plist 원문은 출력/추적하지 않았다. 운영 비밀은 열지 않았다.

| 실행 | 실제 결과 | ignored 근거 |
|---|---|---|
| python3 -B round17-build-intake.py | 종료0. 두 HEAD/142파일·clean·빌드 입력 가용성 메타데이터 확인 | round17-build-intake.json/log |
| HEJO_PYTHON -B round17-build.py → bash app/scripts/build.sh | 종료0. skip 변수 제거, 기존 승인 입력, 정식 빌드/서명 성공. 원본 구성 두 필드 존재=true. BuildInfo dirty=false | round17-build.json/log |
| HEJO_PYTHON -B round17-package.py → test_help_package.py --verify-existing --artifact-out | 종료0. 시험 전후 실행 파일/Info.plist 불변, 실제 압축 추출 strict 서명·HooksHelp Bundle 조회·원문 일치. 추출본 두 필드 존재=true | round17-package.log,round17-package-driver.log,round17-artifacts.json |

시험 기본 모드는 비밀 제외 재빌드를 수행하므로 실행하지 않았다. --verify-existing 안의 시험용 환경 플래그는 빌드를 호출하지 않았고 기존 정식 앱의 지문/두 필드를 유지했다. 빌드 출력은 도구에서 수집해 입력값이 진단에 섞이면 기록 전에 제거하도록 했으며 실제 redactedDiagnostic=false였다. 입력 자체의 별도 내용/비밀 지문은 수집하지 않았다. 새 앱 BuildInfo는 clean tree `2347cb9a389c96bbbca9c9c3f3ded09d66837a28`다.

후보는 `.build/google-disconnect-delivery/ac4643abdbe0-1af03d46dabd-configured-round17`이며 manifest SHA-256은 `66712741c306079ca9a930732893a53f57adcf0d32f932159294637942233539`다. 새 앱 압축 SHA-256은 `0ef168c84e8109755c6cc2aeca4e82495a8b86855948b8a597a5d76ccc8211fa`다. 동일 앱을 포함한 전체 지원 복구 manifest SHA-256은 `7d36a565d85644ba116deae8a3742666904c3fd505ac2a2cfc55deab4abd0817`다. 기존 hejo/team 압축은 왕복16 SHA와 같은 바이트를 재사용했고 이전 후보는 불변이다. 시설 소스 두 커밋은 왕복16 값이며 앱 빌드 소스는 위 hejo clean 커밋으로 구분한다.

최신 검토 문서는 보호 원문 그대로 후보에 반영했다. 실제 경로·기존 서비스 stop/resume argv·앱 구성 보완이 반영된 승인안은 ignored round17-approval-proposal.json에 있고 [배포 인계](deployment-handoff.md)에 공개용 절차/지문/한계를 갱신했다. 후속 문서만 로컬 커밋하고 최종 전체 범위·clean·소스/압축 지문·문서/AC16행·공개 검사 결과는 round17-closure.json/log와 source-checkpoint-15.log에 기록한다.

두 구성 필드의 존재는 실제 Google 로그인/허브 audience 일치/실계정 동의 성공 증거가 아니다. 실제 로그인·사용자 GD-T19·운영 적용/재시작·메시지·업데이트 게시/원격 조회·푸시는 미실행이다. 구성 결정은 승인된 정식 빌드로 보완했고 운영 승인은 여전히 필요하다. Notion12실패의 코드/기대값/skip과 이전 전체 회귀 결과는 불변이며 무변경 전체 UI/회귀는 반복하지 않았다. 이번 공개 검사는 가짜 owner 입력의 일반 개인값 범위이고 실제 운영 명부/금고 검사를 새로 수행하지 않았다.

## 왕복16 — 검토된 통합본의 전달 고정

[작업 왕복16](tasks.md)을 실행했다. 실제142파일/HEAD와 지원 선언을 먼저 대조한 뒤 최신 handoff·tasks·independent-review·UUID verdict4개를 원문 그대로 후보에 반영했다. 제품·시험·지원 선언을 새로 고치지 않았다. hejo22파일/운영 저장소31파일을 후속 로컬 커밋으로 고정했다. 구현 전 기준 대비 범위는 hejo54/team88파일이며 상세 목록은 기존 보고 마지막 목록과 round16-closure.json을 사용한다. 최종 보고/이 배포 인계는 후속 문서 전용 커밋으로 보존한다.

| 검증/산출 | 실제 결과 | ignored 근거 |
|---|---|---|
| python3 -B round16-intake.py | 종료0,checkpoint13 142파일·두 HEAD/빈 index·지원 선언 및 bundle 식별 일치, 최신 문서4개 반영, 앱 입력99개/기존 압축본 일치 | round16-intake.json/log |
| python3 -B round16-metadata.py | 종료0. 전달 앱의 비밀 없는 구성, 기존 LaunchAgent2파일과 검토된 템플릿 바이트 일치. 서비스 명령 미실행 | round16-metadata.json/log |
| python3 -B round16-private.py source hejo | 종료0,전체 추적 후보 일반 개인값 검사/가짜 owner 입력, 실제 index 불변 | round16-private-source-hejo.json/log |
| HEJO_PYTHON -B round16-commit.py team/hejo | 각각 종료0. stage blob/범위·diff 검증 후 로컬 커밋. team 사전 hook snapshot은 boundary80/document0/compartments0 PASS | round16-commit-{team,hejo}-source.json/log |
| HEJO_PYTHON -B round16-package.py | 종료0. 고정 Git의 실제 release 및 bundle 조립/지원 검사, 본문·모드·링크 압축 왕복, 동일 앱 압축본 추출 후 deep strict codesign·안내 본문, 복구 사본3파일 일치 | round16-package.log,round16-package-driver.log,round16-artifacts.json |

정확한 argv/cwd/환경/실행 파일·전체 커밋·입력/전달 지문은 위 JSON/로그에 있다. source hejo 커밋 `09a5d31db54620814203fc079f706501b2b92bb0`, team `1af03d46dabdbe49f4e3ef3ca92aaaf2b321371d`다. 후보 식별자는 `09a5d31db546-1af03d46dabd-round16`, manifest SHA-256은 `667a40da2990c623d2fca7aea52258015a70dbc0625b7722fd2ca8da13235c7d`다. 실제 전달/복구 파일의 전체 SHA-256과 승인용 적용·중단·복구 명령은 [배포 인계](deployment-handoff.md)에 제출했다. 기존 r4/round13 후보는 이전 증거로 보존한다.

앱 입력99개가 기존 통과본과 같아 앱/전체 UI/회귀를 새로 반복하지 않았다. 실제 전달 앱 SHA는 `f400c82904e24961efbbc9078f3e34e661153c7097e87343d8b0da64f4fab581`이며 내장 BuildInfo의 이전 dirty tree를 그대로 보존했다. 신규 빌드로 위장하지 않는다. 공유 Google 앱 로그인 구성은 없는 검증 앱이다. 업데이트 저장소/ED키/framework/서명 검사 조건은 이미 있으며 offline 의존성 옵션이 updater를 끄지 않는다. 정식 빌드 경로로 Google 앱 로그인 구성을 확정하거나 현 구성을 사용자에게 명시적으로 수용받는 운영 결정이 필요하다. 비밀 열람/주입/서명 후 수정은 하지 않았다.

이번 전체 공개 검사는 가짜 임시 HERMES_HOME의 일반 패턴 검사다. 실제 운영 owner/vault 입력을 새로 읽지 않았으므로 실제 명부/금고의 현재 개인값 전부에 대한 새 검사는 아니다. 비밀/운영 자료를 읽지 않는 전달 준비 범위를 유지했고, 보고는 기존 비밀 제외 inventory의 실제 개인 경로/프로필 문자열도 별도 대조했다. private team 소스는 기존 snapshot airport-check 기준을 유지한다. 최종 문서 반영 뒤 round16-private.py final hejo/canonical의 전체 일반 개인값 검사는 각각 종료0이었다. 실제 owner 입력은 사용하지 않았고 실제 index는 불변이다. round16-finalize.py의 링크/AC16행·문서 보호·변경 지문/clean·후보 해시·후속 문서 커밋 결과는 round16-closure.json과 round16-finalize.log에 기록한다.

Terra 왕복16과 기획 처분에 따라 기존 Notion12실패는 신규 회귀 차단으로 취급하지 않지만 미해결로 유지한다. round15-existing-failures.json에12개 전체 node와 candidate/baseline의 같은 assertion 지문이 있으며 원인/정상 동작을 확정하지 않는다. 원래 실패 코드·기대값·skip은 불변이다. 전체 team 성공이나 전체 suite 재실행을 주장하지 않는다. 이번 회귀 증거는 앞선241통과+마지막11표적·지정 기능148통과·새 소비자13통과 및 독립5통과의 각 실제 범위로 유지한다.

복구 후보는 같은 지원 버전의 전체 코드 복원이며 이전 기능으로 돌아가는 rollback 후보는 아니다. 지원 없는 legacy로 복귀하거나 전용 자격/금고를 복원하지 않는다. 현재 policy/receipt/전체 묶음을 확인할 수 없으면 자동 복구/강제 재실행하지 않는다. 실제 개인 경로를 포함한 승인용 제안은 ignored round16-approval-proposal.json에 고정했다. 운영 승인안은 배포 인계에 구체화했고 운영·실계정 GD-T19·재시작·메시지·푸시와 TASK07 최종 명세 승격은 미실행으로 남긴다.

## 왕복15 — 후속 기능 보존과 명시적 최초 전환

[설계9판 보완](design.md)·[tasks 왕복15](tasks.md)의 hejo `a3df84e48fae8b36c27a572a5ee36247cc46acf3`, 운영 저장소 `9488a060e7bf5646af69628b29b34c28cfc18109`를 사용했다. 운영 파일은 다시 읽거나 복사하지 않았다. 원래 Git 기준과 지정 blob을 직접 대조하고 현재와 동일한 내용은 재작성하지 않았다. hejo5파일과 겹치지 않는 team21파일은 지정 blob 그대로이며, 겹치는 두 파일은 원래 기준을 공통 조상으로 의미를 대조했다. 실제 입력·합성 diff는 ignored round15-intake-integrate.json과 round15-merge-inputs에 있다.

| 겹치는 소비자 | 후속 동작 보존 | Google 동작 보존 |
|---|---|---|
| hermes_facility/app_connect.py | 로컬 설치 없는 Notion 탐색, 범위 조회의 권한/토큰/네트워크 오류, 불완전 기존 범위 거절, 조회 성공 뒤 checkpoint, 응답 크기 경계 | transact에서 같은 금고의 직원 entry를 읽어 google_binding_present를 기존 config 조립기에 전달. 명시적 해제 후 다른 앱을 연결해도 legacy Gmail 투영은 다시 켜지지 않음 |
| hermes_facility/connection_checks.py | Notion의 PRIVATE_WORK_NOTION_REFUSED/CONNECTIONS_READ_FAILED를 안전한 상태로 분류 | 개인 Google의 entry 부재에만 legacy 검사를 허용. null은 미연결, 새 연결은 직원 probe, 손상/오류는 실패로 닫고 공용 자격으로 재시도하지 않음 |

새 test_notion_integration.py의13경우는 원격 Notion 정상 조립+Google 명시적 해제 보존, 범위 조회 실패/부분 목록의 쓰기 없음, 후속 probe 오류2종, Google 연결/해제/손상/legacy 부재의 분기를 함께 검사했다. 운영 명부/금고나 실제 API를 사용하지 않았다. 지정 시험/등록/소비자 외 추가 제품 의존 파일은 도입하지 않았다.

### 최초 전환의 책임과 실패 처리

기존 `install/hejo-install --upgrade-legacy --home <승인된 홈>`만 명시적 최초 도입을 실행한다. 새 installer·설정 원본·임의 expected-hash/force 우회는 없다. 이 동작은 완성된 release 디렉터리를 받으며 일반 설치 경로의 현재 검사기 탐색은 바꾸지 않았다. 현재 검사기가 있거나 failed/uninstalled/중간 상태이면 이 예외로 우회하지 못한다. 일반 failed/uninstalled 복구의 기존7판 계약은 유지했다.

단일 `check_google_compat.py`의 LegacyUpgrade는 정상 installed/version1·2/applied 영수증, 기존 실제 링크 전체와 동일 release, 현재 검사기 부재, Git 기준의 전체 hejo 시설/kit·동반5경로·모드·내부 링크를 확인한다. 지원 선언의 legacy.version=1에는 두 기준 commit과 재현한 식별만 둔다. 기존 bundle 선언의 predecessor도 같은 고정 legacy kit/3파일+부재2경로로 바꿨다. candidate kit 식별은 통합 후보로 갱신했다. 선언의 허용5경로/형식을 먼저 검증해 손상 선언이 비밀 파일을 검사 대상으로 만들지 못하게 했다. producer는 기존 정책 함수를 사용한 round15-support.py이고 최초/최종 결과는 round15-support.json 및 round15-support-final.json이다. Git 추출의 디렉터리0755/정규 파일0644·실행0755 정규화와 실제 옛 release 명령으로 재현했으며 운영 바이트를 허용 목록으로 채집하지 않았다.

금고 mutex 안에서 전체 프로필 집합(미설치 프로필 포함)·영수증·링크·양쪽 release·kit/동반 파일을 쓰기 직전마다 재검사한다. Google 전환/null 항목·전용 자격·활성/미완료 인증 장부, 모든 프로필 gateway PID, 관측된 영향 worker, 미완료 team 배포/설치 임시 흔적을 거절한다. 프로세스 관측 실패는 중지로 간주하지 않으며, 프로세스 중지/신호는 수행하지 않는다. `.env`/auth.json/토큰 원문을 읽거나 백업하지 않는다. 전환 유무를 판정하는 기존 금고 구조 검사와 안전한 장부/PID 메타데이터만 사용한다.

쓰기 대상은 **이미 설치된 코드 링크와 기존 설치 영수증**뿐이다. 첫 링크 변경 전에 영수증 status=upgrading-legacy와 코드 경로/이전 링크만 든 legacy_upgrade 표식을 내구성 있게 기록한다. 프로필 링크부터 루트 링크까지 순서대로 교체하고 각 영수증 진행을 기록한다. 모든 검증 뒤 installed로 마무리한다. 미설치 프로필을 plan에 넣거나 owner/config/admin/기기·권한/자격을 조립하지 않는다.

일반 I/O 실패는 같은 잠금·중지 조건과 현재 전환 부재를 재확인한 뒤 링크와 영수증의 기존 본문/모드만 복구한다. 부분 쓰기 뒤 전환/집합 drift가 생기거나 입력·코드·복구가 불확실하면 옛 코드로 복구하지 않고 중간 영수증을 보존한다. 강제 종료/지속 복구 실패는 재실행에서 거절한다. 이 구현은 성공한 최초 전환 뒤 legacy 운영 복귀를 승인하는 경로가 아니다. 실제 적용·복구의 사용자 승인 조건은 [배포 인계](deployment-handoff.md)를 따른다.

### 실제 검증과 남은 실패

모든 증거는 원래 폴더 `.build/google-disconnect-evidence/` 기준이다. round15-run 계열 JSON/로그에는 실제 argv/cwd/환경·실행 당시 변경 파일 지문과 종료 코드를 기록했다. 뒤의 원본 소스 지문/표적 추가 결과와 구분하며 여러 실행을 하나의 전체 통과로 합산하지 않는다.

| 실행 | 실제 결과 | 근거 |
|---|---|---|
| round15-intake-integrate.py | 종료0. checkpoint12 HEAD/114파일 일치, 지정28파일 선택 통합과 보호 문서 기록 | round15-intake-integrate.json/log |
| round15-run.py integration-hejo-03 | 종료0,148 passed/기존 warning1. 후속 댓글·기존 토픽·방 | round15-integration-hejo-03.json/log |
| round15-run.py integration-team | 종료1,936 passed/96 failed/11 skipped. Google suite 포함, 초기 격리 명부/금고 값 부족 | round15-integration-team.json/log |
| round15-run.py integration-team-fixtures-02 | 종료1,537 passed/22 failed/11 skipped. 실패한 파일 범위만 기존 추적 fixture를 가짜 홈에 제공 | round15-integration-team-fixtures-02.json/log |
| round15-team-control.py candidate 및 baseline-02 | 각각 종료1,10 passed/12 failed. 문서 runner의 임시 interpreter 위치를 보완해 기존10실패 해소. 나머지12는 동일 고정 후속 Git 원본에서도 재현 | round15-team-control-{candidate,baseline-02}.json/log, round15-existing-failures.json |
| Google 별도 test_notion_integration.py 표적 pytest | 종료0,13 passed. 격리 Google fixture/외부 네트워크 금지 | round15-notion-google-01.log |
| round15-run.py legacy-regression-final | 종료0,241 passed. 실제 release→최초 전환→설치된 검사기→전체 bundle, 각 쓰기 전/후 실패, 기본 설치/release/deploy/bundle 회귀 | round15-legacy-regression-final.json/log |
| test_google_legacy.py 후속 표적 pytest | 종료0,11 passed/53 deselected. 기존 설치의 orphan 임시 파일/시설 루트 모드 거절을 추가한 뒤 정상 전체 전환·중단·복구 실패·비밀 미접근·worker 관측도 함께 확인 | round15-legacy-04.log |
| round15-mutations.py | driver 종료0. 격리 사본에서 전환 거절 검사와 최초 내구 표식을 각각 제거했을 때 해당 표적 시험이 의도대로 종료1 | round15-mutations-02.json, round15-mutation-*-02.log |
| round15-airport.py | 종료0. snapshot boundary80/document0/compartments0 PASS. 기준선 변경 없음 | round15-airport.json/log |

241시험 실행 뒤 최종 제품 차이는 기존 정책의 orphan 설치 흔적/시설 루트 모드 거절뿐이다. 이 추가 분기와 정상 전환을 위11경우로 검증했으며241개 전부를 최종 코드에서 새로 실행했다고 바꾸어 쓰지 않는다. Apps/IR-1/D1의 입력은 checkpoint12와 동일하므로 통과한 UI/서명/압축 왕복을 반복하지 않았다. 새 최초 전환은 가짜 홈의 실제 파일 시스템/프로세스 관측(수준2·3)이며 운영/실계정 수준4 증거가 아니다.

잔여12실패는 기존 `test_app_scope.py`1개와 `test_notion.py`11개다. 두 Git 버전 대조에서 노드 id와 임시 경로/객체 주소만 정규화한 실제 assertion 출력이 일치했다. 페이지네이션 fixture/읽기 결과/오류 문구·등록·업로드 거절 기대와 후속 코드의 차이이며, 구현자가 기대를 수정하거나 skip/xfail하지 않았다. 제품 결함/옛 기대값 문제의 최종 분류와 수락 여부는 기획/독립 검토에 반환한다. 따라서 전체 team 회귀 통과를 주장하지 않고 커밋/푸시도 하지 않았다.

초기 준비 실패도 보존한다. integration-hejo 종료4는 옛 파일명 지정 오류, -02 종료2는 PTB import 경로 누락으로 시험 미실행이며 기존 설치 의존 경로를 명시한 -03에서 통과했다. team-fixtures 첫 시도 종료4는 공백을 포함한 parametrized node id 추출 오류로 시험 미실행이고 파일 범위를 정확히 지정한 -02와 후속 대조로 구분한다. legacy-01은 신규 release fixture의 LICENSE 누락으로21실패/24통과, 보완 뒤 legacy-02는44통과/기존 backup 코드 파일을 잘못 센 시험1실패였다. 기존 파일 집합 불변으로 바로잡은 -03의9경우는 통과했다. mutation 첫 준비 및 Git 참조 환경 오류는 child의 의미 있는 실패가 아니며 초기 JSON/로그에 보존했다. 최종 -02는 fixture의 고정 Git 원본 조회만 원래 저장소로 지정하고 제품/성공 단언을 바꾸지 않은 격리 사본에서 의도된 실패를 관측했다.

최종 공개 패턴/기록된 개인 식별자 검사, 전체 변경 범위·compile·diff·AC16행·문서/증거/지문 대조는 round15-private와 round15-final-check에 기록한다. canonical 설계/수락/독립 리뷰/판정은 수정하지 않았다. 이 결과는 Terra 재검토 제출이며 독립 완료 판정이나 운영 허가가 아니다. GD-T19·TASK07 승격·후속 커밋/최종 불변 후보·앱 운영 로그인/업데이트 구성은 남는다.

## 이전 왕복14 — 실제 legacy 시설 대조와 구현 보류

[설계9판](design.md)과 [tasks 왕복14](tasks.md)에 따라 예외 구현 전에 비밀 제외 시설 전체를 대조했다. 결과는 다음과 같다. 이는 전환 실행, 전환 자격 부여 또는 고위험 수락 증거가 아니다.

| 범위 | 원래 검토 기준과 실제 대조 | 추가로 확인한 Git 출처 |
|---|---|---|
| hejo release 시설 gate/hub/schemas/config/install/LICENSE | 42파일 중39일치,3본문 차이,1추가. RELEASE 메타데이터와 캐시는 별도 | 실제43파일은 기록된 릴리스 `a3df84e48fae8b36c27a572a5ee36247cc46acf3`와 모두 일치. 원래 hejo 기준의 후속 커밋이며 현재 Google 후보에 그 후속 변경을 통합한 증거는 없음 |
| team-kit 전체(캐시 제외) | 681항목 중658일치,23본문 차이. 추가/부재·모드/내부 링크 차이는 없음. 내부 링크96개도 확인 | 23차이는 운영 저장소 후속 커밋 `9488a060e7bf5646af69628b29b34c28cfc18109`의 blob과 모두 일치. 해당 커밋이 원래 기준과 다른 kit 경로도 정확히 이23개이므로 전체681항목의 출처를 식별. 해당 후속 코드는 Git status상 clean |
| 동반5파일 | 원래 기준과5경로 모두 일치. 기존3파일 본문/모드, 나머지2파일의 부재까지 일치 | 위 후속 운영 저장소 커밋과도5경로 일치. 이 일치만으로 kit/현재 검사기 도입을 승인하지 않음 |
| 영향 홈/영수증/연결 | 기본 홈+프로필6개를 이름·파일형식·링크 메타데이터로 조사. installed/version2 영수증의6링크는 모두 applied/실제 gate 링크와 일치. 나머지1프로필은 hejo 링크·해당 영수증 항목 없음 | hejo/team-kit/team-delegation의 관측된 최상위 링크는 기대 시설을 가리킴. team-delegation overlay1개는 manifest 일반 파일과 원본 코드 링크로 구성. 프로필 선택/권한 원본은 읽거나 승인하지 않음 |

hejo의 본문 차이는 `gate/README.md`, `gate/adapter.py`, `gate/telegram.py`이고 추가 경로는 `gate/telegram_comments.py`다. 원래 기준에서 추가 경로는 내용 없이 형식만 기록했고, Git에 존재하는 기록된 release와의 두 번째 대조에서 코드로 확인했다. RELEASE가 있다는 이유만으로 전체 일치를 가정하지 않았다. 앱 bundle 내부의 운영 로그인/업데이트 구성과 자격은 열지 않았고, 기존 앱 수락/운영 배포 승인을 확장하지 않았다.

team-kit의23본문 차이는 다음과 같다(키트 루트 기준).

- `__init__.py`
- `lib/hermes_facility/app_connect.py`
- `lib/hermes_facility/app_scope.py`
- `lib/hermes_facility/app_setup.py`
- `lib/hermes_facility/connection_checks.py`
- `lib/hermes_governance/contracts.py`
- `lib/hermes_owner_chat.py`
- `lib/hermes_packs/diagnosis/diagnosis_runtime.py`
- `lib/hermes_packs/files_docs/files.py`
- `lib/hermes_packs/mac_apps/app_catalog.json`
- `lib/hermes_packs/mac_apps/catalog.py`
- `lib/hermes_packs/mac_apps/discovery.py`
- `lib/hermes_packs/notion/api.py`
- `lib/hermes_packs/notion/operations.py`
- `lib/hermes_team_services/error_digest.py`
- `lib/hermes_team_services/memory_live.py`
- `lib/hermes_team_services/work_runtime.py`
- `tests/test_app_catalog.py`
- `tests/test_app_registry.py`
- `tests/test_error_digest.py`
- `tests/test_files.py`
- `tests/test_hejo_session_proof.py`
- `tests/test_owner_provenance_hejo.py`

파일별 기대/실제 SHA-256, 모드·존재/부재·내부 링크, 실제 개인 경로/홈 대응은 ignored `.build/google-disconnect-evidence/round14-inventory.json` 및 `round14-profile-topology.json`에만 둔다. 후속 Git 출처의 개별 blob 대응은 `round14-provenance.json`, 전체 트리/동반5경로의 추론 대조는 `round14-baseline-coverage.json`이다. 운영 코드를 수집해 새 allowlist/지원 선언으로 등록하지 않았다.

**보류 사유와 반환 판단:** design9판의 현재 검토 기준과의 전체 일치 조건이 충족되지 않았다. 출처 불명의 운영 바이트라고 단정할 상태도 아니다. Git 출처는 확인됐지만 후속 hejo/kit 변경을 현재 Google 후보와 호환 복구 후보에서 어떻게 보존할지, 그 버전을 최초 전환 기준으로 채택할지의 기획·검토 처분이 없다. 기존 후보를 그대로 덮어쓰면 후속 시설 변경이 사라질 수 있으므로 기준을 임의로 바꾸거나 --upgrade-legacy/새 predecessor를 구현하지 않았다. 현재 검사기가 없는 installed 상태의 거절을 유지한다.

권고: 기획·검증 담당이 위 두 후속 Git 버전과 원래 기준 사이의 차이를 검토해 현행 기능 보존/통합 범위와 legacy 기준을 확정한 뒤 재인계한다. 또는 이미 검토된 다른 일치 기준이 있다면 그 정확한 커밋/릴리스와 전체 시설 대응을 제공한다. 운영을 원래 기준으로 되돌리거나 누락2파일/검사기만 복사해 맞추는 선택은 하지 않는다. 승인을 기다리지 않고 할 수 있는 이번 범위인 차이·증거 기록과 최신 문서 후보 반영은 완료했다.

**실행/미실행 구분:** `python3 .build/google-disconnect-evidence/round14-inventory.py`, `round14-provenance.py`, `round14-baseline-coverage.py`는 각각 종료0이며 조사/출처 검사의 성공이다. 정확한 argv/cwd/대상 버전은 각 JSON, 출력은 대응 log에 있다. inventory의 baselineProven=false는 거절 조건 확인이며 전환 성공을 뜻하지 않는다. canonical 문서 후보 반영은 round14-report.py/round14-protected.json으로 확인한다. 제품 무변경·문서 링크/AC16행·개인값·두 diff --check와 최신 지문은 round14-final-check.py 및 round14-private 로그로 검증한다.

왕복14 공개 검사는 격리된 가짜 home의 고정 입력으로 전체 후보의 일반 패턴을 검사하고, 이번 두 보고에는 inventory 메타데이터의 실제 프로필 식별자/개인 경로가 없음을 별도로 검사한다. 운영 금고/명부를 새로 읽는 전수 비교를 반복하지 않으며 이전 전체 공개 검사 증거와 구분한다.

명시적 최초 전환·임시 홈의 상태/잠금/중지/CAS/각 쓰기 실패복구·전체 bootstrap→bundle 시험은 선행 조건 보류로 **코드 미작성/미실행**이다. 운영 금고/자격/전환 상태·활성 작업/중지 상태는 이번 시설 inventory로 조사하지 않았고 없다고 주장하지 않는다. 기존 전체 UI/Google/deploy 회귀는 무변경이므로 반복하지 않았다. 독립 검토 완료·수준4·GD-T19 완료는 주장하지 않는다. 기존 D1/D2·IR-1 수용과 과거 실패 로그/산출물을 보존한다.

## 왕복13 — D-1/D-2 구현과 실제 검증

승인된 범위는 design8판·tasks 왕복13이다. 구현 전에 deployment-handoff에 동반5파일의 원본/대상/manifest·선택 소유/복구 대응표를 기록했다. 기준 HEAD는 hejo d25530649f7eb898e2f5cbc5cb471c1417823632, 운영 저장소33d6671993473c0eb7ecb4087e0fe4edebc63050이며 기존 커밋/두 worktree를 보존했다. 이번 변경은 미커밋으로 Terra에 반환한다. 구체적 범위/파일별 지문은 source-checkpoint-11.log가 원본이다.

D-1: build.sh는 기존 한글 HTML 원문을 ASCII connection-help.html로 복사하고 서명 전에 그 리소스의 옛 NFC/NFD 이름만 지운다. HooksHelp의 실제 Bundle 조회도 함께 맞췄다. 안내 본문/한국어 표시는 유지했다. 실제 일반/반복 빌드와 타 임시 위치의 압축 해제 후 strict 서명·실제 조회/원문 대조를 확인했다. 별도 원본, 추출 뒤 재서명/단언 완화는 없다.

D-2: 기존 deploy의 --source는 legacy kit-only, --bundle은 허용된 전체 시설 루트를 받는다. 기존 단일 hejo 검사기가 kit/5파일의 본문·모드·내부 링크와 지원 선언을 검증하며, 기본 검사도 옛 호출자의 부분 배포를 거절한다. 새 installer/금고 원본/운영 우회는 없다. 현재 정책·실행 코드를 시작 시 고정하고 금고 mutex/중단 조건 안에서 전체 stage→사전 검사→CAS 쓰기→전체 확인을 한다. 기존 plugin_store의 pending 검사와 overlay/ledger, config_assembly의 선언 합성, skill assembler의 순수 prepare를 확장했다. owner grant·앱/팩/직원 선택·무관 필드는 쓰지 않는다. 선택된 전환 직원만 네 도구 선언/매뉴얼을 반영한다. 자동 복구는 이전 전체 본문/모드·존재/부재를 보존하고 owner 원본은 되돌리지 않는다. 중단/복구 실패 stage는 보존·재실행 거절한다.

표적 시험 과정에서 실제 발견/수정한 문제: 루트 plugin link 아래의 manifest를 일반 파일로 읽으려던 경로는 검증된 원본에서 읽도록 맞췄다. source 지원 선언 없는 미전환 predecessor의 전체 snapshot은 기존 버전 검사와 명시적 식별을 함께 사용한다. 최초 부재의 지속 I/O 실패 시험은 이미 원상태인 항목까지 재쓰려다 복구를 멈추는 문제를 검출했다. 복구 시 현재==이전 상태면 그대로 두고 나머지 항목을 복구하도록 고쳤다. 각각 최초 실패 로그와 수정 후 결과를 구분한다. 시험 초기 package fixture 미가져오기, 가짜 금고 필수 manuals.repository_name 누락 및 Swift 조회 보조 코드의 throwing autoclosure 오류도 수정했으며 제품 단언을 약화하지 않았다.

검증 로그는 원래 작업 폴더의 `.build/google-disconnect-evidence/` 아래다. 정확한 argv/cwd/환경·입력 지문을 round13-run 계열 JSON/로그 및 source-checkpoint-11.log와 대조한다. 앱은 실제 서명/Bundle 실행(수준3), 임시 홈 bundle은 실제 파일 시스템/프로세스와 가짜 자료(수준2·3)이며 운영/실계정 수준4가 아니다.

- app/Tests/test_help_package.py: 첫 실행은 일반/반복 빌드0·압축/추출/strict 서명0 뒤 보조 Swift 컴파일1. 동일 빌드의 --verify-existing 후속 실행은0, BUNDLE_HELP_LOOKUP_OK와 안내 원문 SHA 일치. round13-app-package-01.log/02.log. 통과한 제품 빌드를 보조 코드 수정만으로 반복하지 않았다. 최종 --verify-existing --artifact-out 실행(HEJO_PYTHON)은 종료0, round13-app-package-03.log. 검토용 압축은 `.build/google-disconnect-delivery/round13-review/hejo.app.tar.gz`, SHA-256 `f400c82904e24961efbbc9078f3e34e661153c7097e87343d8b0da64f4fab581`이다. 같은 실행에서 타 임시 위치의 strict 서명/실제 Bundle 조회까지 통과한 압축을 보존했다. 최종 커밋의 생산 배포본으로 주장하지 않는다.
- 기존 Google/설치/release 회귀142통과: round13-hejo-regression.log/JSON. 기존 team Google158통과: round13-team-google.log/JSON. 이후 배포 경계 변경은 아래 별도 표적 검증으로 확인한다.
- 최신 단일 검사기와 bundle/기존 배포 회귀112통과: round13-bundle-accepted.log/JSON. 최초 부재 정상/지속 실패 추가 시험은 round13-bundle-absence.log에서1통과/1실패였고, 원상태 재쓰기 수정 뒤 영향받는 복구/rename/경합/부재 시험15개(기존13+추가2)가 종료0으로 통과했다. round13-recovery-final.log. 이를 최종 전체 시험의 단일 실행으로 합산하지 않는다. 앞선 round13-bundle-01~08 및 bundle-final 로그는 보존한다.
- 설치된 라이브러리/manifest의 실제 register를 프로필의 실제 팩 설정으로 실행한 후속2경우는 종료0(4개 팩 선택→4도구, mail 선택→기존 files-docs 의존성을 포함한2도구). 적용 전후 config 바이트/기존 grant 불변을 단언했다. round13-register-final-02.log. 최초 mail 기대를1도구로 둔 시험은 기존 mail/pack.yaml의 files-docs 의존성을 누락해 실패했으며 제품/선택/승인 정책을 바꾸지 않고 기존 계약에 맞춰 정정했다. round13-register-final.log는 보존한다.
- 중단 표식/동반 검사를 제거한 격리 mutation은 각각 수락 시험 종료1을 확인했다. 최종 코드의 round13-mutations-03.json과 각 mutation-03 로그(두 자식 시험 종료1, driver0). 이전 round13-mutations-02.json도 보존한다. 최초 단일 중단 guard 제거는 다른 유효 guard 때문에 시험이 통과해 보호 규칙 전체의 변이를 다시 확인했다. 작업 트리를 변이하지 않았다.
- snapshot airport-check는 baseline 변경 없이 boundary80/document0/compartments0 PASS. 최종 복구 수정 뒤 round13-airport-closure.log/JSON(종료0). round13-private.py hejo/canonical은 각각 종료0으로 전체 공개 검사와 실제 index 불변을 확인했다. 최종 보고 기록 뒤 hejo 후보를 다시 검사하며 round13-private-final-hejo.log/JSON에 보존한다. 두 worktree diff --check와 변경 Python compile·로컬 링크·보호 문서·source 지원 선언 검증의 최종 기록은 source-checkpoint-11.log와 round13-final-check.json이다.

비밀 제외 실제 대상 읽기 전용 확인: round13-target-readonly.json. installed 영수증의 현재 검사기가 없고 동반2파일이 부재다. 후보 검사기 대체 탐색/운영 파일 복사로 해결하지 않았다. 선언의 검토된 predecessor와 실제 운영 묶음은 다른 상태이며 기획/운영의 안전한 전환 결정이 필요하다. 시스템 앱 메타데이터는 발견했지만 교체/서명/운영 로그인·업데이트 구성과 호환 복구 묶음은 미승인이다. [최신 배포 인계](deployment-handoff.md)의 명령은 현재 차단 처분/재검토/고정 및 별도 사용자 승인 뒤에만 실행한다. 운영 설치/apply/rollback/재시작·실계정·메시지·푸시는 하지 않았다.

## 이전 왕복12 — 로컬 커밋·격리 후보와 운영 인계

[배포 인계](deployment-handoff.md)에 후보 식별자·정확한 명령 템플릿·적용/복구/중단 조건·사용자 GD-T19 체크리스트를 작성했다. 실제 운영 설치/apply/rollback/재시작·실계정·푸시는 미실행이다. 제품/시험 입력은 checkpoint-10과 동일하므로 통과한 전체 suite/UI/빌드를 반복하지 않았다. 기존 AC16행 처분과 Terra 최종 검토를 유지하며 운영/실계정 수락을 완료로 바꾸지 않는다.

| 저장소 | 결과 소스 커밋 | 범위 | 원격 이름 |
|---|---|---|---|
| hejo | `78b3634bd50110a0a989146405ee454476a14f62` | 검토된29파일 + 최신 작업/판정/수락 문서13파일 =42 | github |
| 운영 저장소 | `33d6671993473c0eb7ecb4087e0fe4edebc63050` | 검토된65파일 그대로 | origin |

두 브랜치는 `role-workflow/google-disconnect-c20a9994`다. hejo에는 후속 문서 전용 커밋으로 최종 보고/배포 인계를 추가한다. 산출물의 실행 소스 커밋은 위 값으로 고정하며 후속 문서 HEAD와 구분한다. 후속 문서 커밋의 전체 해시·최종 clean 상태·후보 지문 재독 결과는 `.build/google-disconnect-evidence/delivery-final.json`에 고정한다. 실제 전체 커밋/파일별 SHA-256/argv/cwd/종료 코드/원격 이름은 `.build/google-disconnect-evidence/delivery-commit-{hejo,team}-source.{json,log}` 및 최종 인계 기록에 있다. 실제 원격 URL·개인 경로는 공개 문서에 넣지 않았다.

- `python3 .build/google-disconnect-evidence/delivery-intake.py`: 종료0. 두 HEAD·전체 changed/untracked 집합과 checkpoint-10의94파일 지문 일치, 초기 index 비어 있음·diff --check0, 최신 문서13개의 충돌 없음. 로그 `delivery-intake.json`.
- `python3 .build/google-disconnect-evidence/close-private.py hejo`: 종료0. 코드/문서 후보19개 intent-to-add를 별도 index에 포함한 전체 공개 검사 통과, 실제 index 불변. 전달 결과는 `delivery-private-hejo-source.{log,json}`로 보존했다. 처음 기존 로그 이름을 재사용한 기록 실수는 전달 로그로 분리하고 기존 승인 로그의 바이트를 기록된 SHA-256과 동일하게 복구했다. `delivery-evidence-path-correction.json`에서 확인한다.
- `python3 .build/google-disconnect-evidence/delivery-commit-source.py team` 및 `... hejo`: 각각 종료0. 작업 범위만 명시적으로 stage하고 staged blob 지문·파일 집합/diff --check 확인 후 로컬 커밋했다. 운영 저장소의 기존 사전 커밋 hook은 snapshot airport-check를 실행해 boundary80/document0/compartments0 PASS. 검사기나 baseline을 완화하지 않았다. 두 worktree는 소스 커밋 직후 clean이다.
- 최초 `python3 .build/google-disconnect-evidence/delivery-artifacts.py`: 종료1. Git archive 내부의 기존 team-kit symlink를 일괄 거절한 준비 드라이버의 보수적 조건에 걸렸다. hejo release 자체는 종료0이며 운영 출력은 없었다. 실패 산출물/로그 `delivery-artifacts.log`는 보존하고 사용 후보로 지정하지 않았다.
- `python3 .build/google-disconnect-evidence/delivery-artifacts-02.py`: 종료0. 별도 새 디렉터리에서 실제 hejo-release, 고정 커밋의 제한 경로 git archive, 내부 symlink 경계 검사, hejo/team 지원 build 검사, 기존 앱 입력/실행 파일 지문 일치·원본/복사본 codesign strict 검증, 패키지/트리 지문을 기록했다. 로그 `delivery-artifacts-02.log`, 파일별 원본 `delivery-artifacts.json`.

- `python3 .build/google-disconnect-evidence/delivery-private-final.py hejo` 및 `... canonical`: 각각 종료0. 최종 배포 인계/보고를 포함한 전체 공개 검사 통과, 실제 index 불변. hejo의 새 문서1개와 canonical 후보14개를 각각 별도 index에 포함했다. 로그 `delivery-private-final-{hejo,canonical}.{log,json}`. 후보14개 Markdown의 로컬 링크는 누락0이다. 이후 이 결과 기록만 보고에 추가하며 커밋 직전 최종 변경 범위를 다시 확인한다.

최종 후보 ID는 `78b3634bd501-33d667199347-r4`다. r2/r3은 아래 포장 검증 결과로 제외했다. hejo release45파일/team616파일/app98파일의 본문 지문과 내부 링크/모드를 보존했다. team 후보에는 team-kit 밖 동반5파일도 포함했다. 현재 배포 명령은 이5파일을 설치하지 않으므로 **운영 적용/복구 단위 미확정**을 발견했다. 기존 선택/승인을 보존하는 설치 절차와 앱 운영 배포 구성·설치 대상, 현재 설치 검사기/호환 복구 묶음을 기획/운영 담당이 먼저 확정해야 한다. 이를 이유로 새 installer·무검사 복사·제품 변경을 임의 도입하지 않았다.

추가 압축 내용 대조에서 r2의 macOS AppleDouble 메타데이터가 manifest 밖에 있음을 발견해 제외했다. `COPYFILE_DISABLE=1`로 만든 r3의 hejo/team은 불필요 항목0·파일/링크/모드 일치다. 그러나 `python3 .build/google-disconnect-evidence/delivery-package-final.py`는 앱 압축을 실제 임시 볼륨에 풀고 codesign strict를 실행하는 단계에서 종료1이다. 원본/동일 볼륨 복사본은0, 압축 해제본은1이며 한글 리소스 파일명 NFC→NFD와 봉인된 NFC 경로의 불일치를 직접 관측했다. 파일 본문/링크 대조는 동일하다. 로그 `delivery-package-final.log`, `delivery-package-signature-diagnostic.json`, `delivery-unicode-resource.json`에 실제 argv/cwd/결과와 이름 정규화 증거를 남겼다. 기존 제품 파일명/서명은 변경하지 않았다.

`python3 .build/google-disconnect-evidence/delivery-package-submit.py`: 종료0. 최종 r4에는 내용/모드/링크 대조를 통과한 hejo45파일·team616파일 압축만 포함하고, 앱은 codesign0인 동일 볼륨 로컬 bundle만 보존했다. 앱 압축본은 포함하지 않는다. 최종 파일별 지문 원본 `delivery-artifacts-final.json`, 압축 대조 `delivery-archive-roundtrip.json`, 로컬 앱 서명 `delivery-package-submit.log`. 앱의 다른 볼륨 전달/설치 성공은 **미충족**이며 포장/서명 방식 처분이 운영 승인 전 추가 선행 조건이다. 통과한 제품/UI 시험을 반복하거나 임의 제품 수정을 하지 않았다.

앱은 `HEJO_SKIP_GOOGLE_SECRET=1`, `HEJO_SPARKLE_OFFLINE=1`의 기존 검증 빌드다. 비밀 없는 로컬 후보이며 운영용 공유 Google 로그인/업데이트 구성을 완성한 배포본으로 주장하지 않는다. 전체 운영 적용 승인 요청은 이 경계 처분 뒤이며 GD-T19는 사용자 직접 실행, 최종 명세 승격은 기획 소유다.

## 이전 왕복11 — IR-1 실제 사용자 창 닫기 보완

승인 원본은 tasks의 ‘왕복11 IR-1 창 닫기 최소 보완’과 Terra checkpoint-09 재검토다. 위험도/증거 수준 및 설계7판은 유지한다. 앞선 삭제·새 계정·만료 전체 화면 시나리오는 반복하지 않았다.

### 제품 변경과 발견한 결함

기존 증거에서 인증 시트가 붙은 부모 performClose는 진행되지 않았고 시트의 표준 닫기 버튼도 노출되지 않았다. 왕복11 허용 범위에 따라 기존 AppKit NSPanel 안에 ‘창 닫기’ NSButton을 추가했다. 기존 ‘인증 취소’와 함께 놓고, 툴팁으로 인증 취소와 창 닫기를 설명한다. 새 버튼의 실제 target/action은 부모 window.close로 연결하며 기존 windowWillClose→model.close→closeGeneration/소유 account_cancel을 그대로 사용한다. 별도 취소 구현·새 창·원본·권한·서버 경로는 없다. Escape의 기존 인증 취소 동작은 유지한다.

표적 시험 첫 실행(close-ui-01.log, 종료1)은 닫기 성공/연결 끊김 실패/기존 취소를 통과한 뒤 늦은 poll 승인 응답에서 실제 안내가 ‘연결을 확인했어요.’로 바뀌는 결함을 검출했다. 원인은 취소된 Task가 요청 continuation의 응답을 받은 직후 취소 상태를 다시 확인하지 않기 때문이다. ConnectionsModel.startPolling의 await send 다음에 기존 Task.isCancelled 검사를 추가했다. 닫기/새 polling이 취소한 옛 작업은 늦은 응답의 안내·목록 처리를 진행하지 않는다. 같은 시험/서버/컨트롤을 유지한 재실행은 종료0이다. 초기 실패와 수정 후 성공을 다른 바이너리/소스 지문으로 구분한다.

### 실제 컨트롤·서버 관측

기존 실제 AppKit+loopback fixture에 closeOnly 제한 모드와 --google-disconnect-close-ui 진입점만 추가했다. 새 시험은 시트에서 실제 노출된 NSButton을 찾아 enabled를 확인하고 performClick으로 누른다. 사용자 닫기 검증을 window.close/model.close 직접 호출로 대신하지 않는다. 공통 defer의 종료 정리는 수락 동작과 별개다. 재인증/브라우저/기존 polling 시간만 대역이며 제품 send/ref 경로와 clientFrame/serverFrame 검사를 유지한다.

| 경우 | 실제 관측 | 서버 프레임/실패 경계 |
|---|---|---|
| 닫기 성공 | 실제 ‘창 닫기’ 버튼 후 부모/시트 종료. 재열면 ‘인증을 취소했어요.’와 연결 버튼 | 첫 소유 세션 취소 1회, reauth=false/profile=alpha, 이후 목록 재조회 |
| 취소 전송 불가 | 시트 표시 후 가짜 소켓만 끊고 실제 ‘창 닫기’를 누름. 재열기에서 ‘취소 확인 안 됨’, 서버 연결 실패 안내가 표시됨. 재접속·조회 뒤에도 실패 의미 유지 | 두 번째 세션의 cancel은 전송되지 않음. 서버 성공으로 위장하지 않음. 실제 연결 상태로 send guard가 실패하는 경로 |
| 기존 인증 취소 | 실제 ‘인증 취소’ 버튼은 시트만 닫고 부모 창은 계속 보이며 취소 성공 안내 | 세 번째 세션 취소 1회, 기존 재인증 불필요 경계 유지 |
| 늦은 응답 | 네 번째 세션의 실제 poll 응답을 보류하고 실제 ‘창 닫기’를 누름. 재열기 후 늦은 승인 프레임과 그 다음 실제 새로 확인 왕복을 통과해도 취소 안내/시트 없음이 유지 | 소유 세션 취소 1회. 취소 뒤 늦은 승인 전송과 다음 목록 응답을 파일 장벽으로 확인. 임의 고정 대기로 성공 판정을 대신하지 않음 |

가짜 서버는 이 모드에서 네 인증만 시작하며 삭제/새 계정/만료 전체 흐름은 실행하지 않는다. 계정은 미연결로 유지한다. 최종 frames.json에서 cancel은 세션1·3·4이고 전송 불가 세션2는 없다. 화면 증거는 close-ui-02/의 실제 NSView 캐시 렌더/접근성 텍스트8쌍이다. 이 렌더는 앞선 제출과 같은 합성/애니메이션 한계가 있으며, 실제 컨트롤과 상태는 접근성 관측 및 전송 프레임으로 함께 확인했다. 성공/실패 재열기·늦은 응답 뒤 렌더와 텍스트를 직접 확인했다.

### 명령과 실제 결과

원래 작업 폴더에서 기존 connections-env.sh를 source하고 HEJO_TEAM_KIT_LIB/PYTHONPATH를 기존 team worktree로 지정했다. runner의 자식 cwd는 hejo worktree의 app이며 가짜 HOME/HERMES_HOME·정확한 argv/환경·컴파일 입력/실행 파일 지문은 각 로그 첫 JSON, 결과는 마지막 JSON에 있다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| python3 .build/google-disconnect-evidence/close-ui-build.py | 최종 Swift 시험 컴파일/서명/서명 검증 각각0 | close-ui-build-02.log |
| python3 .build/google-disconnect-evidence/close-run.py ui 01 | 종료1. 사용자 닫기/전송 실패/취소 회귀 후 늦은 승인 덮어쓰기 검출. fake 서버 오류0 | close-ui-01.log, close-ui-01/ |
| python3 .build/google-disconnect-evidence/close-run.py ui 02 | 종료0. 사용자 닫기 AppKit·APP_TEST_OK·loopback frame 계약 PASS, 자식0/fixture 오류0 | close-ui-02.log, close-ui-02/ |
| python3 .build/google-disconnect-evidence/close-run.py google 01 | 종료0. 기존 Google 모델·실제 인증 시트 회귀 PASS | close-google-01.log |
| python3 .build/google-disconnect-evidence/close-product-build.py | 종료0. bash scripts/build.sh 컴파일·앱/중첩 서명·deep strict 검증, BUILD_OK. secret 읽기 제외/offline 옵션 사용, 설치/실행 안 함 | close-product-build-01.log |
| python3 .build/google-disconnect-evidence/close-checkpoint.py | 종료0. 두 HEAD·94파일, checkpoint-09 대비 지정4파일, 기존 시험 본문/단언 보존·diff --check·Python compile | source-checkpoint-10.log |
| python3 .build/google-disconnect-evidence/close-private.py hejo 및 canonical | 각각 종료0. 최신 전체 추적 파일/미추적 작업 후보, 임시 index·실제 index 불변 | close-private-hejo.log/.json, close-private-canonical.log/.json |

최종 변경본·보호 문서·제품/시험 빌드와 전후 실패/성공·프레임/렌더·보고 대조는 close-final-check.json이다. 변경 없는 team/설치·배포/Python 전체/앞서 수용된 IR-1 전체 화면은 이전 증거를 유지했다. 독립 검토·GD-T19 운영 실계정 증거를 이 자체 시험으로 대신하지 않는다. 다음은 같은 Terra의 잔여 IR-1 재검토이며 판정/계획/수락 원본은 구현자가 갱신하지 않는다. 운영·실계정·재시작·커밋·푸시는 실행하지 않았다.


## 이전 독립 리뷰 IR-1 — checkpoint-09 제출

받은 인계는 tasks의 ‘독립 리뷰 IR-1 보완 인계’와 [Terra 독립 검토](independent-review.md)다. 위험도 고위험/증거 수준2·3·4 경계를 유지한다. 이번 보완은 GD-T17 수준3 화면/전송 관측이며 GD-T19 수준4 실계정 증거를 대신하지 않는다. IR-1 종료 판정은 Terra 재검토에 맡긴다.

### 변경과 실제 경로

ConnectionsTests의 새 googleDisconnectUITests는 실제 ConnectionsWindow/NSHostingView·NSAlert·인증 NSPanel을 띄운다. SwiftUI 버튼은 노출된 실제 접근성 노드의 press, AppKit 기본 버튼은 실제 NSButton.performClick으로 조작한다. 이 fixture 프로세스의 AXEnhancedUserInterface/AXManualAccessibility만 켜 SwiftUI가 실제 컨트롤을 노출하도록 했다. 시스템 접근성 권한·보안 창·창 활성화 정책·제품 코드는 바꾸지 않는다. SwiftUI 노드가 프로토콜 채택 없이 노출되므로 Objective-C의 실제 접근성 selector를 사용하며, 값 대입으로 UI를 꾸미지 않는다. AppKit 속성 노출 호출의 deprecated 경고는 이 시험 경계의 기존 API 사용 사유이며 억제하지 않았다.

새 google_connection_fixture.py는 127.0.0.1 임의 포트의 aiohttp WebSocket 가짜 서버다. 앱의 GateClient→ConversationController→ConnectionsWindow 요청/ref 응답 경로를 그대로 사용하며 model.send·모델 문서·계정 값을 주입하지 않는다. 가짜 서버만 계정/세션 상태를 소유한다. 공용 스키마의 clientFrame/serverFrame으로 송수신을 각각 검사한다. 재인증 승인과 브라우저 미실행, 기존 pollingWait 시간만 주입한다. 실제 Keychain/Google/API/운영 홈은 사용하지 않는다.

원본 TestMain에 --google-disconnect-ui 제한 진입점만 추가했다. 기존 Google·기본 연결 시험의 기대값·skip·기본 실행 흐름은 그대로다. 새 시험은 임시 HOME/HERMES_HOME/LocalStore/메모리 자격을 사용한다. 제품 동작의 의미 변경은 없다.

### 실제 화면과 전송 관측

| 범위 | 화면/동작 확인 | 가짜 서버의 독립 확인 |
|---|---|---|
| 삭제 확인 거절/수락 | 실제 확인 시트의 직원 연결·이메일·전용 인증 삭제, 다른 직원/회사 보존, 다음 계정 선택 문구와 버튼. 거절 후 실제 목록 유지 | 확인 수락 뒤 reauth=true와 forget_account 값. 전체 해제 프레임은 의도한 두 번뿐이며 거절의 추가 전송 없음 |
| 해제 후 상세·목록 | 기존 이메일이 없고 실제 연결 버튼 존재. 뒤로/새로 확인 버튼을 눌러 목록 재조회 후에도 이메일 없음 | 해제 응답 뒤 새 connections 요청과 미연결 문서 |
| 다시 연결 성공 | 실제 인증 시트의 서버 Mac/다른 Mac 안내. 승인 후 실제 목록에 가짜 새 계정, 이전 이메일 없음. 새로 확인 후에도 유지 | 시작/폴링 프레임과 서버의 새 계정 승인·재조회. AppKit 모델 대입 없음 |
| 취소 실패와 성공 | 실제 인증 취소 버튼. 실패는 ‘취소 확인 안 됨’, 성공은 ‘인증을 취소했어요.’. 시트 종료와 연결 상태 표시 | 소유 세션별 account_cancel/reauth=false, 실패/성공 응답을 각각 구분 |
| 만료 | 인증 시트 관측 후 기존 pollingWait를 가속. 실제 시트가 닫히고 ‘동의 시간이 초과됐어요.’가 표시되며 계정 없음 | 세 번째 세션의 실제 oauth_poll 정확히450회, 뒤 소유 세션 취소와 목록 재조회 |
| 창 종료·재열기 | 인증 중 실제 부모 NSWindow.close가 windowWillClose를 발생시킴. 창/시트 종료 뒤 재열고 실제 연결 버튼·계정 없음 확인 | 네 번째 세션만 취소, 종료 후/재열기 후 connections 재조회 |

창 종료 시험은 NSWindow.close의 실제 수명 이벤트를 검증한다. 인증 시트가 붙은 부모 performClose는 진행되지 않으며 이 시트에는 닫기 버튼이 없다. 따라서 사용자 빨간 닫기 버튼이 인증 중 활성화됐다고 주장하지 않는다. 직접 model.close 호출로 창 종료 증거를 대체하지 않았다. 이 구체적 관측 범위를 Terra가 GD-T17에 대조해야 한다.

화면 증거는 실제 NSView 캐시 렌더 PNG와 실제 접근성 트리 텍스트13쌍이며 `ir1-ui-07/`에 있다. 해제 목록·가짜 새 계정 목록·취소 실패·만료·재열기 렌더를 직접 확인했다. 캐시 렌더의 합성/애니메이션 한계와 접근성 관측을 구분한다. 전송 원본은 같은 폴더 frames.json이다.

### 실행 결과와 한계

원래 작업 폴더에서 기존 connections-env.sh를 source하고 HEJO_TEAM_KIT_LIB/PYTHONPATH를 격리 team worktree로 명시했다. 아래 runner 로그의 첫 JSON에 정확한 argv/cwd/선택 환경·HEJO_PYTHON·서명 바이너리/Swift/fixture 지문, 마지막 JSON에 종료 코드가 있다. 자식 cwd는 hejo worktree의 app이다.

| 명령 | 실제 결과 | 증거 |
|---|---|---|
| python3 .build/google-disconnect-evidence/ir1-ui-build.py | 최종 Swift 컴파일·서명·codesign 검증 각각0 | ir1-ui-build-07.log |
| python3 .build/google-disconnect-evidence/ir1-run.py ui 07 | 종료0. 실제 AppKit 왕복·APP_TEST_OK·loopback frame 계약 PASS, 자식0/fixture 오류0 | ir1-ui-07.log, ir1-ui-07/ |
| python3 .build/google-disconnect-evidence/ir1-run.py google 01 | 종료0. 기존 Google 모델/실제 시트 PASS | ir1-google-01.log |
| python3 .build/google-disconnect-evidence/ir1-run.py connections 01 | 종료0. 원본 연결 전체·관리·불완전 응답·Google 모델 PASS | ir1-connections-01.log |
| python3 .build/google-disconnect-evidence/ir1-checkpoint.py | 종료0. hejo29/team65, checkpoint-08 대비 시험3파일만 변경, 원래 시험 본문 보존·두 diff --check·새 Python compile | source-checkpoint-09.log |
| python3 .build/google-disconnect-evidence/ir1-private.py hejo 및 canonical | 각각 종료0. 전체 추적 파일과 미추적 작업 후보를 임시 index로 검사, 실제 index 불변 | ir1-private-hejo.log/.json, ir1-private-canonical.log/.json |

초기 실패 증거는 지우지 않았다. build-01은 접근성 프로토콜 이름 컴파일 오류(종료1) 후 수정했다. ui-01/02는 방향별 스키마 선택 누락, ui-03은 SwiftUI 노드 노출 누락, ui-04는 기본 버튼의 접근성 press 경로, ui-05/06은 시트가 붙은 창의 performClose 관측에서 종료1이었다. 최종 fixture는 이 원인을 고쳤으며 기존 단언을 완화하거나 제품 실패를 무시하지 않았다. 각각의 파일·바이너리 지문으로 초기 후보와 최종 결과를 구분한다. 무변경 Python522/team/배포/제품 빌드/기본9함수는 이전 증거를 유지했다. 단일 앱 기본 모드 전체 성공이나 실제 OAuth 성공을 추가로 주장하지 않는다.

실제 화면 관측의 결함 검출도 확인했다. 공개 fixture의 임시 사본에서만 해제 뒤 옛 계정을 남기도록 한 번 바꿨다. 같은 서명 바이너리가 실제 해제 상세/연결 버튼 관측에서 종료1로 실패했고 driver는 기대한 검출을 확인해 종료0이다. 로그 `ir1-ui-mutation-stale-01.log`, 처분 `ir1-mutation-01.json`; 원본 fixture/제품/시험 바이너리는 불변이며 임시 변형은 제거했다. 정상 시험 성공을 뒤집는 결함이 실제 화면 단언에 잡힌다는 증거이며 독립 검토를 대신하지 않는다.

문서/증거·실제 변경본 최종 대조는 `ir1-final-check.json`에 남긴다. 전체 공개 검사 뒤 결과 설명만 보완한 보고서는 별도 범위 검사 `ir1-report-private.log`로 확인했다.

다음은 같은 Terra 독립 리뷰의 IR-1 재검토다. independent-review.md·verdict/tasks/handoff의 검토 처분은 구현자가 대신 수정하지 않는다. GD-T19 운영/실계정 승인과 푸시 승인은 별개이며 이번에는 요청하거나 실행하지 않았다.


## 이전 사용자 완료 지시 후 — checkpoint-08 마무리 기록

### 개인값 정리

승인 원본은 tasks 마지막 절과 `task05-private-baseline-01.json`이다. 원문 값은 출력/인계하지 않고 기존 검사기의 변경 없는 내부 비교 함수를 사용해 지정된 30개 행의 실제 일치 부분만 가짜 값으로 치환했다. 전체14파일·변경30행을 원래 행 지문과 대조했다. HTML 태그·속성·style/script 블록을 원본과 바이트 비교해 그대로임을 확인했다. 파일 삭제·레이아웃/기능 변경·스캐너/허용 목록 변경은 없다. 치환 내역은 원문 없는 행 지문과 위치만 `finish-redaction.json`에 있다.

hejo 전체 공개 검사는 실제 owner 입력을 내부 비교에만 사용했고, 별도 index에 HEAD와 미추적 후보 5개를 포함해 실행했다. 실제 index는 전후 동일하다. `finish-private-hejo.log`/`.json`은 종료 0이다. canonical 원래 폴더도 task 문서11개까지 포함한 전체 검사 종료 0이다(`finish-private-canonical.log`/`.json`). 두 실제 index 모두 불변이다. 이후 보고 결과 문구만 갱신한 부분은 보고서 범위 검사로 확인했다. 이전 30건 실패는 정리 전 이력이며, 범위 검사0으로 전체 실패를 대체하지 않았다.

### UI 시험 보완과 실제 결과

`app/Tests/ConnectionsTests.swift`는 AT-HC-27 성공 조건 visible/key/입력 정리/busy 해제를 그대로 유지한다. show 다음 임의 0.1초 관측만 기존 waitFor(5)의 유한 상태 관측으로 바꿨고, 활성/비활성·key 전환·sheet 종료 알림의 시간을 기록한다. 관측 코드는 창을 key로 강제하거나 앱을 별도로 활성화하지 않는다. 기한 내 성공 조건이 오지 않으면 실패한다. 제품 show/restoreFocus는 수정하지 않았다.

제한 실행 진입점은 `--connection-supplement management|incomplete`와 `--remaining-basic <원래 함수명>`이다. 원래 private 연결 관리/불완전 응답 함수를 직접 호출하며 내부 단언·흐름은 그대로다. 불완전 응답의 기존 문서 fixture는 원본 literal 하나를 공용 함수로 옮겨 동일 데이터를 재사용한다. 기본 모드의 호출 순서·실패 중단 동작은 변경하지 않았다. 별도 모드 성공을 원본 연결 suite 전체 성공으로 표시하지 않는다.

| 실행 범위 | 실제 결과 | 로그 |
|---|---|---|
| Swift 시험 실행 파일 빌드·기존 인증서 서명·서명 검증 | 각각 종료 0. 제품 빌드/설치 반복 아님 | `finish-ui-build.log` |
| GUI 준비 전 원본 connectionsTests 전체, --task32-capture | 종료 1. sheet 종료 알림만 두 번 관측, 5초 동안 활성/key 조건이 오지 않음. active=false, visible=true, key=false, fields=0, busy=false, sheets=0, canKey=true, keyWindowPresent=false, securityAgentFront=true | `finish-ui-connections.log` |
| GUI 준비 전 원본 connectionManagementTests 전체, --connection-supplement management | 종료 1, 약8초 후 기존 waitFor의 timed out. 이 원본 함수에서 해당 wait는 AT-CM-35의 NSApp.isActive/visible/key 조건 한 곳이다. 그 전 모델 단언은 통과했지만 실제 focus 네 조합 전부 성공은 아님 | `finish-ui-management.log` |
| 원본 connectionIncompleteReplyTests | 종료 0, TASK-13 INCOMPLETE REPLY PASS | `finish-ui-incomplete.log` |
| 원본 Google 모델·실제 인증 시트 대역 | 종료 0, 두 PASS와 APP_TEST_OK | `finish-ui-google.log` |
| progressLayoutTests | 종료 0 | `finish-ui-progressLayoutTests.log` |
| threeTapTests | 종료 0 | `finish-ui-threeTapTests.log` |
| roomsTests | 종료 0 | `finish-ui-roomsTests.log` |
| bubbleReplyTests | 종료 0 | `finish-ui-bubbleReplyTests.log` |
| petNotificationTests | 종료 0 | `finish-ui-petNotificationTests.log` |
| picturesSidebarTests | 종료 0 | `finish-ui-picturesSidebarTests.log` |
| appIconTests | 종료 0 | `finish-ui-appIconTests.log` |
| loginTests | 종료 0, 기존 대역 로그인/발견 fixture | `finish-ui-loginTests.log` |
| composerTests | 종료 0 | `finish-ui-composerTests.log` |

GUI 준비 전 합산 실행 driver는 종료 1이다. 정확한 argv/cwd/선택 환경·기존 HEJO_PYTHON·서명한 바이너리 지문과 각 종료 코드는 `finish-ui-results.json` 및 각 로그에 있다. 모두 가짜 HERMES_HOME/LocalStore/명부/서버/자격으로 격리했다. 외부 보안 대화를 조작하거나 실계정 동의를 하지 않았다. 변경 없는 gate/Python 전체522·team·제품 빌드·배포·기존 후속13fixture·airport-check는 이전 증거를 재사용한다.

### 사용자 GUI 준비 후 재검증과 다음 경계

사용자가 SecurityAgent 보안 대화를 직접 처리했고 GUI 세션이 준비됐다고 확인했다. 비밀값/대화 내용은 받지 않았으며 자동 조작도 하지 않았다. checkpoint-08의 두 HEAD·93파일 집합/지문, 빌드 입력 전체와 기존 서명 실행 파일 지문을 대조하고 codesign --verify --strict 종료 0을 확인했다. 재컴파일·재서명·제품 변경 없이 실패 두 범위만 실행했다.

| 재검증 범위 | 실제 결과 | 로그 |
|---|---|---|
| 원본 connectionsTests 전체, --task32-capture | 종료 0. AT-HC-20~29, AT-CM-30~38, 불완전 응답, Google 모델 및 APP_TEST_OK. 활성/key 이벤트 관측, HC27 뒤 재시작 확인·undo 단언까지 도달 | `finish-ui-resume-connections.log` |
| 원본 connectionManagementTests 전체, --connection-supplement management | 종료 0. AT-CM-30~38 APP PASS와 APP_TEST_OK. 기존 실제 focus 조건 포함 | `finish-ui-resume-management.log` |

`source .build/connections-env.sh` 후 HEJO_TEAM_KIT_LIB/PYTHONPATH를 기존 team worktree로 명시한 `python3 .build/google-disconnect-evidence/finish-ui-resume.py`는 종료 0이다. 자식 실행 cwd는 hejo worktree의 app이며, 정확한 argv/선택 환경·가짜 HOME/HERMES_HOME·서명 바이너리 지문은 각 로그에 있다. 선행 지문/서명 검사는 `finish-ui-resume-preflight.json`, 합산 결과는 `finish-ui-resume-results.json`이다. 기존 11개 성공 범위는 반복하지 않았다.

이번 환경 준비 후 같은 실행 파일에서 두 실패 범위가 통과했다. 이전 실패의 세부 원인을 제품 결함이나 SecurityAgent 하나로 확정하지 않는다. 원본 연결 전체와 기본9함수의 미실행 범위는 각각 실제 성공 증거로 해소했으며, 단일 기본 모드 전체를 새로 실행해 성공했다고 주장하지 않는다. 실제 사용자 OAuth와 운영 적용은 미실행이다.

독립 리뷰는 구현·설계 비참여 다른 모델을 호스트가 별도로 배정해야 한다. 최신 검토 대상은 checkpoint-08과 canonical 계약/보고/로그이며 checkpoint-07 대비16파일의 제한 변경을 포함한다. 독립 리뷰 결과와 구체적 지적 처분 뒤 결과 커밋·운영/복구·푸시 승인 자료를 고정한다. 아직 커밋/푸시 준비 완료가 아니며 운영 적용·실계정 OAuth·재시작·푸시는 실행하지 않는다.


## 이전 왕복 6 — UI 실행 경계 조사와 독립 리뷰 인계

**제품·시험 원본은 checkpoint-07 그대로다.** 이번에는 구현 참여자의 제한적 UI 원인 조사만 수행했다. 새 구현·전체 pytest·전체 UI·설치/배포·제품 빌드를 반복하지 않았다. 독립 검토를 대신하지 않으며 `independent-review.md`는 구현자가 작성하지 않았다. 호스트가 구현 비참여 다른 모델 및 설계 비참여 조건을 충족하는 리뷰를 배정해야 한다. 기존 UI 작업의 예외 처분을 이 Google 작업에 자동 적용하지 않는다.

### AT-HC-27: 관측된 조건과 미확정 원인

- [확인] 왕복 5의 원본 전체 실행 및 서명한 현재/기준 HEAD는 같은 AT-HC-27에서 종료 1이었다. 원본 관측은 visible=true, key=false, fields=0, busy=false, sheets=0이다. 입력 정리 실패와 창 미표시 실패는 이 관측과 다르다.
- [확인] `app/Sources/ConnectionsWindow.swift:381`의 show는 이미 NSApp.activate와 makeKeyAndOrderFront를 호출한다. 해당 활성화 호출은 기준 HEAD에도 있다. Google 인증 작업이 없는 이 fixture를 보고 활성화 호출 누락이나 새 Google 회귀라고 판단하지 않는다.
- [확인] 시험은 `app/Tests/TestMain.swift:341`의 accessory 앱으로 실행되며 `ConnectionsTests.swift:290`에서 입력 종료 후 show 전후 각각 0.1초만 기다린다. 이 지점에 앱 활성/key 이벤트 장벽은 없다. 입력 sheet의 종료는 Combine 구독이 만든 MainActor Task와 AppKit sheet completion에서 비동기로 처리한다.
- [확인] 현재 실행 조건을 관측하려고 임시 시험 사본에 출력 한 줄만 추가했다. 원본 소스·단언·대기·호출 순서는 유지했고 기존 테스트 하네스처럼 서명한 진단 바이너리의 `--task32-capture`만 실행했다. 컴파일/서명 종료 0, 시험 종료 1로 같은 단언이 재현됐다. active=false, canKey=true, frontmostIsSelf=false, keyWindowClass=none, parentLevel=0, authenticating=false였으며 전면은 외부 SecurityAgent였다. 보안 대화를 열람·승인·종료하지 않았다. 진단 사본/바이너리는 로컬 증거용이며 release 산출물이 아니다.
- [미확정] 앱이 활성화 요청 뒤에도 비활성인 구체적 이유, 보안 에이전트 전면 상태와의 인과관계, sheet 종료 타이밍의 기여는 이 관측만으로 확정하지 못한다. 현재는 시험이 요구하는 활성/key 조건을 충족하지 못한 상태로 분류한다. 제품 창 처리의 기존 결함 여부와 실제 사용 환경의 성공 조건은 별도 UI 담당의 판단이 필요하다.

기존 [UI-CLEAN 판정](../HEJO-UI-CLEAN-20261123/verdict.md)과 [TODO-DRAWER 보고](../HEJO-TODO-DRAWER-20261120/impl-report.md)에도 과거 비활성 앱/동일 단언 기록이 있다. 이는 조사 방향의 참고이며 다른 HEAD의 결과를 현재 성공 증거로 가져오지 않았다. 과거 진단 원본 로그는 현재 폴더에서 확인하지 못했고, 현재 진단의 활성 상태는 새 로그에서 직접 확인했다. 과거 연결 시험 제외 방식도 이번에 반복하지 않았다.

UI 후속 범위는 활성화·key/sheet 이벤트의 실제 순서 관측이다. 동일한 서명/격리/원본 fixture를 쓰고 다른 GUI 실행과 겹치지 않게 하며, 외부 보안 대화의 사유 확인·처리는 사용자가 판단해야 한다. 원본 show 뒤 실제 활성/key 상태가 성립하는지 확인하고, 활성=true인데도 key=false가 유지될 때 기존 창/sheet 처리 수정이 필요한지 UI 담당에게 반환한다. 별도 승인 없이 활성 정책·단언·고정 대기·코드 흐름을 바꾸지 않는다. 통과한 실행 조건을 확보했다고 주장하지 않는다.

### 원본 기본 모드에서 실패 이후 미실행

`connectionsTests()`는 connectionsScreenTests → connectionManagementTests → connectionIncompleteReplyTests → googleDisconnectTests 순서다. AT-HC-27는 **connectionsScreenTests 안**에 있다. 따라서 connectionManagementTests 전체도 미실행이며, 이미 그 앞에서 출력한 AT-HF-83 PASS는 연결 suite 전체 완료를 뜻하지 않는다.

| 중단 위치 뒤 범위 | 해당 기본 실행의 상태 |
|---|---|
| connectionsScreenTests 나머지 | 재시작 확인 sheet의 level/취소, unknown/connected 행별 undo 제목·버튼, 정상 정리/PASS 미실행 |
| connectionManagementTests 전체 | AT-CM-30~38 메뉴·설정 변경·해제 확인/재인증 순서·입력 수명·실제 focus 복원 미실행. 특히 AT-CM-35의 NSApp.isActive/key wait도 미도달 |
| connectionIncompleteReplyTests | 불완전 응답 처리 미실행 |
| googleDisconnectTests | 기본 모드에서는 미실행. 이전 별도 --google-disconnect 성공과 구분 |
| progressLayoutTests | AT-HF-85 미실행 |
| threeTapTests | AT-HF-86 미실행 |
| roomsTests | AT-HF-70/71/80 기본 단위/UI 시험 미실행 |
| bubbleReplyTests | AT-HF-82 기본 단위/UI 시험 미실행 |
| petNotificationTests | AT-HF-81 미실행 |
| picturesSidebarTests | AT-HF-68/69 sidebar 기본 시험 미실행 |
| appIconTests | AT-HF-66 미실행 |
| loginTests | AT-HF-58/59/60 대역 로그인/발견·설정 이전 시험 미실행 |
| composerTests | COMPOSER_PLAIN_PASS 해당 시험 미실행 |

기본 모드의 connectionsTests 다음 직접 호출은 위 마지막 9개다(`TestMain.swift:303` 이후). 최종 기본 PASS/APP_TEST_OK도 미도달이다. googleDisconnectSheetTests는 기본 unit에 편성되어 있지 않고 별도 --google-disconnect 분기에서 실행되므로, 그 별도 성공을 기본 모드 성공으로 세지 않는다.

### 후속 fixture가 실제로 확인한 경로

아래는 왕복 5의 실제 성공 증거를 재사용한 범위다. 이번에 다시 실행하지 않았다. 동일 이름의 기능 일부가 겹쳐도 위 기본 시험 함수의 성공을 대신하지 않는다.

| fixture | 실제 AppKit/Python 진입점·확인 범위 |
|---|---|
| network | network(args): 임시 게이트 짝짓기/키체인/재개·단절 복구 |
| conversation | conversationNetwork: 대화 HTTP/WS·업로드/버튼/전송/다운로드 |
| pictures | pictureNetwork: 이미지 HTTP/cache; picturesSidebarTests 전체 아님 |
| thread | threadNetwork: 스레드 전송/UI 경계 |
| workspace | workspaceNetwork: workspace 전송/UI 경계 |
| bubble_reply | bubbleReplyNetwork: 답글 전송/UI; bubbleReplyTests 전체 아님 |
| home_room | homeRoomNetwork: 홈 방 전송/UI |
| rooms | roomsNetwork: 실제 gate+가짜 Hermes의 방 전송; roomsTests 전체 아님 |
| composer_target | composerTargetNetwork: 입력 대상 전송; composerTests 아님 |
| downloads | downloadsNetwork: 첨부 다운로드 경계 |
| web_pane | webPaneNetwork: 루프백 WebKit/다운로드·자격 비전달 |
| review55 | review55Network: 해당 네트워크 회귀 |
| hooks | Python HookTests와 기존 제품 --hook 경로; 기본 UI 9함수 아님 |

### 검증·호스트에 남긴 범위

- `python3 .build/google-disconnect-evidence/round06-ui-audit.py`: 종료 0. 두 HEAD/79개 지문·실제 호출 순서·fixture 진입점·이전 실패/성공 로그 대조. 로그 `round06-ui-readonly-audit.json`.
- 기존 HEJO_PYTHON의 `round06-focus-probe.py`: 진단 사본 컴파일/서명 종료 0, 대상 시험 종료 1, 기록 driver 종료 0. 정확한 argv/cwd/환경/소스·바이너리 지문과 stderr는 `round06-focus-probe.log`. 원본 79개 지문은 그대로다.
- 독립 리뷰는 호스트 배정 대상이다. canonical 계약·수락 명세와 실제 checkpoint-07 코드/로그를 읽고 OAuth·금고/전용 자격·binding/승인·파일 권한·배포 복구의 생산자/소비자를 확인한 뒤 independent-review.md에 범위·지적·근거·모델/역할 독립성을 기록해야 한다. 이 구현 대화의 조사나 진단은 그 조건을 충족하지 않는다.
- 기존 mockup 14파일/30건 정리는 별도 담당 또는 사용자 범위 승인 대상으로 유지한다. 이번에는 관련 원문 복제·수정/삭제·허용 목록 변경·전체 공개 검사 재실행을 하지 않았다. 구체적 독립 지적이나 승인된 정리 범위 없이 제품 구현을 재개하지 않는다. 운영·실계정 OAuth·재시작·커밋·푸시는 미실행이다.

## 왕복 5 보완과 검증

- `test_cm24_25_actual_cli_arguments`의 Google 개인 해제만 `options.disconnect_mode=forget_account`와 정확한 `--disconnect-mode forget_account` argv로 이관했다. connect/undo의 기존 argv·stdin 계약을 유지하고 다른 서비스 해제에는 새 플래그가 붙지 않는지 확인했다. 별도 5개 매개변수 시험은 누락/빈 값/잘못된 문자열/boolean을 `UPDATE_REQUIRED`로 거절하고 CLI 실행 표시 파일이 생성되지 않는지 검사한다. gate/시설의 삭제 확인 검사는 약화하지 않았다.
- 기존 환경 파일에서 `HEJO_PYTHON`을 명시 export하고 `HEJO_TEAM_KIT_LIB`/PYTHONPATH의 첫 경로를 실제 team worktree로 고정했다. 같은 실행 환경에서 `sys.executable`과 aiohttp 3.14.5 import 성공을 먼저 기록했다. 새 패키지를 설치하지 않았다.
- AppKit 전체 기본 모드는 hejo worktree의 `app` cwd에서 기존 Swift 시험 실행 파일과 제품 Pet 리소스를 사용했다. 임시 HOME/HERMES_HOME에 격리했으며 부모와 자식 stderr를 같은 로그로 받았다. `PostGroupTests.swift`는 명시한 HEJO_PYTHON을 선택하고 부모 환경을 복사한 뒤 자신의 임시 HERMES_HOME만 덮어쓴다. 실제 자식 PID의 실행 명령과 cwd도 ps/lsof로 확인했다. 정확한 로컬 실행 파일·전체 argv·선택 환경 값은 공개 문서 대신 아래 로컬 로그에 있다.
- 새 전체 실행은 `AT-PG-01...11,13 PASS` 후 AT-HC-27에서 종료 1이다. 이전 aiohttp import 실패는 해소됐다. 현재 key=false 관측과 기존 assertion을 유지했다. 기존 하네스처럼 서명한 현재/대조 실행 파일을 같은 격리 환경에서 `--task32-capture`로 실행해 둘 다 같은 AT-HC-27 종료 1을 확인했다. 대조 Sources/Tests 147개가 기준 HEAD와 일치함을 git show로 확인하고 이전 대조 빌드 산출물을 재사용했다. 전체 UI 성공이나 그 뒤 기본 모드 시험 실행을 주장하지 않는다.
- app/scripts/test.sh의 후속 UI fixture 13개를 별도로 실행했다. 임시 HOME에서 11개 성공, network/conversation 2개는 테스트 자격 저장 실패·시간 초과로 종료 1이었다. 기존 하네스의 인증서 서명과 기본 키체인 실행 환경을 적용한 재실행에서 두 fixture가 성공했고 무작위 테스트 계정 자격 정리도 확인했다. 이 두 실행만 기존 HOME의 키체인을 사용했으며 HERMES_HOME·LocalStore·명부·서버·토큰은 모두 대역/임시 값이다. CLI 설정은 내용 열람 없이 metadata, Downloads는 항목 이름만 전후 비교해 무변경을 확인했다. 서명과 HOME의 개별 기여는 분리 시험하지 않았다.
- 제품 빌드·독립 배포 suite·변경 없는 team suite·airport-check·네 결함 주입은 기존 증거를 유지했다. 요청한 hejo 전체 Python 회귀에는 release/설치 시험도 포함된다. 새로운 전체 공개 검사를 반복해 통과로 표시하지 않았다. 현재 hejo 14파일과 canonical 문서 11파일 범위 검사만 추가했고 아래 전체 실패와 구분한다.

| 이번 실행 | 실제 결과 | 로그(원래 폴더의 `.build/google-disconnect-evidence/` 기준) |
|---|---|---|
| 기존 HEJO_PYTHON의 `-c` aiohttp import 및 hejo `-m pytest gate/tests tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --basetemp <짧은 임시 경로>` | import 종료 0, 전체 pytest 종료 0, **522 passed / 기존 warning 1개** | `round05-python-01.log` |
| app cwd의 `.build/google-disconnect-tests <제품 Pet 리소스>` 전체 기본 모드 | 종료 1. AT-PG 성공, AT-HC-27 실패. 바이너리·Swift 파일 지문과 환경 기록 | `round05-app-full-01.log` |
| 실제 PostGroup 자식 ps/lsof 관측 | 종료 0. 지정 Python·실제 argv/cwd 확인, 자식 stderr는 위 전체 로그 | `round05-app-child-processes.log` |
| 후속 UI fixture 13개 최초 실행 | 11개 종료 0, network/conversation 2개 종료 1. 합산 driver 종료 1 | `round05-app-fixtures-results.json`, `round05-app-<fixture>-01.log` |
| 기존 하네스 서명·키체인 환경의 network/conversation 재실행 및 보호 검사 | 서명/검증·두 fixture·설정/Downloads 보호 검사 모두 종료 0. 테스트 자격 정리 성공 | `round05-app-keychain-environment.log` |
| 서명한 현재/기준 HEAD `--task32-capture` | 각각 종료 1, 같은 AT-HC-27. 대조/관측 driver 종료 0 | `round05-app-hc27-control.log` |
| 두 worktree diff --check·Python compile·전체 변경 지문 | 종료 0, hejo 14/team 65. checkpoint-06 대비 시험 파일 1개만 변경 | `source-checkpoint-07.log` |
| 현재 hejo 14파일에 기존 공개 검사기 적용, 실제 owner 내부 비교·임시 index | 종료 0. 실제 index 불변. 범위 검사이며 전체 검사 아님 | `round05-private-hejo-scope-02.log` |
| 현재 canonical 문서 11파일의 같은 범위 검사 | 종료 0. 실제 index 불변. 전체 실패를 대체하지 않음 | `round05-private-canonical-scope.log` |

범위 검사 첫 시도 `round05-private-hejo-scope.log`는 기본 Python의 YAML 의존성 누락으로 종료 2였다. 기존 환경 파일의 PATH를 적용하고 python3의 ruamel import를 확인한 뒤 위 재실행했다. 검사기·허용 목록·owner 입력은 변경하지 않았다.

## 7판 변경과 이유

- `install/check_google_compat.py`: 일반 installed 영수증 탐색을 유지하면서 failed/uninstalled 로컬 설치 재실행에만 좁은 bootstrap 예외를 추가했다. 지원 영수증·실제 root/profile 코드 링크 복구·전환 기록 부재·잔존 전용 자격/미완료 Google 장부 부재를 읽기 전용 검사한다. 상태 문자열만 믿지 않으며 설치 중간 상태·읽기 실패·중복 키·알 수 없는 버전/형식·symlink는 거절한다. 과거 before 대상은 검사기로 실행하지 않는다.
- 같은 검사기의 `deployment_guard`: 기존 금고 쓰기 잠금 `owner/.app-connect.lock`을 배포 배타 처리에 재사용한다. 새 상태 저장 원본은 없다. 검사기를 한 번 고정한 뒤 잠금 아래 변경 직전 재확인하고 트랜잭션 동안 잠금을 유지한다. 전환 삽입/잠금 점유 시 설정·링크·영수증·금고·자격을 바꾸지 않는다. 이 잠금 경로는 비밀 내용이 없는 기존 시설 mutex다.
- `install/hejo-install`: 후보 지원 선언과 일반 파일을 검사기 실행보다 먼저 검사한다. 검사기 소스는 정확한 패키지 파일에서 읽어 메모리에 로드하여 Python module cache나 cwd/PATH에 의존하지 않는다. 영수증 업그레이드 쓰기보다 먼저 preflight/잠금/재확인을 수행한다. 기존 사용자 config 비교·conflict/--force·device 보존·durable rollback을 유지한다.
- 같은 installer의 `update_code_links`: 호환 release A에서 새 release B로 root/profile link와 영수증 after를 갱신한다. 기존 코드 링크를 모두 비교하고 원래 패키지도 고정된 현행 검사기로 확인한다. 프로필을 먼저, 루트를 마지막에 갱신하며 I/O 예외에는 호환 이전 링크/영수증을 복구한다. 사용자 변경 링크를 덮어쓰지 않는다.
- 운영 `hermes-team-kit-deploy`: 기존 금고 잠금 안에서 검사 후 시설 트리를 교체하고, 기존 `plugin_store` snapshot/overlay/restore_host를 재사용해 profile overlay의 신규/삭제 항목을 반영한다. 직원 plugin.yaml은 보존한다. 실패하면 고정된 검사기로 이전 시설을 확인한 뒤 코드와 overlay를 복구한다. 미지원 구 시설은 자동 복구하지 않는다.
- 운영 `hermes-plugin-store`: migrate/restore-copies/실패 복구도 같은 기존 mutex 안에서 공통 검사를 사용한다. team의 검사기 탐색에는 hejo 로컬 복구 예외를 확대하지 않았다.
- `tests/acceptance/test_google_deployment.py`: failed/uninstalled 긍정·부정·경합, 후보 코드 실행 전 지원 선언 검증, 정상 owner_vault YAML serializer 왕복, 실제 release A→B root/profile 갱신, 호환 예외 복구와 overlay 추가/삭제·실패 복구를 추가했다. 가짜 소스에서 실제 hejo-release를 실행하며 수동 검사기 복사 fixture는 없다.
- 운영 `hermes_governance/google_calendar_undo.py`: 확대 회귀에서 기존 호출자가 새 td.personal_scopes.current 인터페이스를 갖지 않는 문제를 발견했다. 실제 인증된 직원 home의 기존 root_of/profile_of를 원본으로 binding을 확인하도록 고쳤다. 기존 company/legacy 호출 계약을 유지하고, 전환 전 승인/undo와 동일 이메일 재연결을 계속 거절한다. 기존 시험은 수정하지 않았고 `test_queued.py`에 두 binding 회귀를 추가했다.
- `schemas/hejo-wire-v1.json`: 설명문만 추가했던 변경이 기존 wire 전체 바이트 해시 시험을 깨뜨려 이번 작업 변경을 제거했다. 기존 string/values 구조가 이미 새 동작을 담으며 삭제 의미·재인증·작업 소유권은 gate/시설이 검사한다. wire 해시 기대값은 바꾸지 않았다.

## 유지한 기존 구현

TASK-02/03: `google_connection*.py`의 직원 금고 연결·전용 봉투·장부 barrier·요청 lease·CAS·OAuth worker/state/PKCE/신원 검증과 기존 account/조립/메일·Calendar/승인·대기/undo/review/worker/진단 소비자를 유지했다. 회사/미전환의 기존 자격 선택과 금고 밖 두 번째 계정 원본을 만들지 않는 원칙을 유지한다.

TASK-03A: 기존 register wrapper·scoped_context·실제 승인 hook/middleware에 typed 도구 4개를 연결했다. 선택 팩/manifest·역할·소유자 대화·배경·파일 경계와 정확한 명령/인자/binding/승인 시점을 검사한다. 업로드 파일 descriptor와 다운로드 parent descriptor를 고정한다. Calendar 쓰기는 기존 승인/undo를 재사용한다. 현재 개인 직원 gmail modify는 기존 회사 업무 전용 제한으로 거절하며 새 도구 노출은 권한 부여가 아니다. SDK 24명령 보존과 모든 직원의 모든 명령 허용을 구분한다. 전환 personal 직원용 스킬만 기존 조립 경로에 추가했고 sandbox/자격 사본/본체 우회는 없다.

TASK-04: gate 삭제 의미·재인증, 기기/직원별 status/cancel 세션과 AppKit 삭제 확인·서버 Mac 안내·취소·늦은 응답·900초 만료 처리를 유지했다. 다른 서비스/구 서버 capability 문구는 보존한다. 새 인증 화면은 AppKit NSPanel이다.

TASK-05 공통 검사기는 hejo `install/check_google_compat.py` 하나다. 각 저장소의 지원 선언은 별개다. release는 source/artifact 필수 파일을 검사하고 scripts/ 없이 동작한다. 연결된 홈 전체를 확인할 수 없는 기존 비어 있지 않은 공유 출력 교체는 계속 거절한다. 새 release 생성→각 홈 installer 갱신이 정상 경로다.

## 이전 구현·검증 기록

로그는 원래 폴더의 `.build/google-disconnect-evidence/` 기준이다. HEJO_PYTHON은 기존 `.build/connections-env.sh`를 사용하며 HEJO_TEAM_KIT_LIB/PYTHONPATH는 실제 team worktree lib로 고정했다. 새 테스트와 실행 대역은 임시 HERMES_HOME·가짜 명부/금고/자격을 사용했다. HOME은 기본 격리하며 위에서 명시한 두 키체인 fixture와 인증서 서명만 기존 HOME을 사용했다. HEJO_SKIP_GOOGLE_SECRET=1로 비밀 config를 읽지 않았다.

| 실행 명령/범위 | 실제 결과 | 로그 |
|---|---|---|
| hejo `$HEJO_PYTHON -m pytest tests/acceptance/test_google_deployment.py tests/acceptance/test_install.py --confcutdir=tests/acceptance -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 124 passed. 기존 설치 52개 포함. 최종 후보 선언 검증까지 반영 | `task05-v7-final-install-01.log` |
| v7 첫 단계: install/release/deployment | 종료 0, 81 passed. 기존 3실패 해소 | `task05-v7-install-01.log` |
| v7 복구/경합/A→B/overlay 경계 첫 실행 | 종료 0, 69 passed. 이후 후보 선언 부정 3개 추가 | `task05-v7-boundaries-01.log` |
| team 기존 관련 7파일 pytest --noconftest | 종료 0, 82 passed. app_connect/config_assembly/calendar_scope_writable/google_calendar_app_undo/app_scope/app_scope_unicode/app_input_scope. 실제 argv 로그에 있음 | `task05-team-regression-02.log` |
| 같은 기존 회귀 최초 | 종료 1, 3 failed / 79 passed. Google undo의 새 td 인터페이스 의존 결함을 제품에서 수정 | `task05-team-regression-01.log` |
| team `$HEJO_PYTHON -m pytest hermes/plugin-store/team-kit/tests/google_disconnect --confcutdir=hermes/plugin-store/team-kit/tests/google_disconnect -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 종료 0, 156 passed. undo 수정 후 실제 등록/승인/파일/조립/sandbox 회귀 | `task05-team-google-01.log` |
| 위 test_queued.py -k calendar_undo_binding_uses_authenticated_employee_home | 종료 0, 2 passed / 17 deselected. 회사/legacy 호출 보호와 별개로 실제 home의 옛 binding 거절 | `task05-calendar-binding-01.log` |
| hejo `bash scripts/test.sh`, 짧은 임시 basetemp | 종료 1, pytest 2 failed / 510 passed. 이후 단계는 이 명령에서 실행되지 않음. 아래 실패 처분 참조 | `task05-full-hejo-01.log` |
| hejo pytest test_google_disconnect.py·gate/tests/test_connections.py·test_connections_screen.py·test_slack_move_gate.py, 짧은 basetemp | 종료 0, 87 passed. 이전 gate51의 argv 누락을 명령/대상 기록으로 보완하고 원래 wire 해시 회귀 성공 확인 | `task05-gate-final-01.log` |
| hejo `$HEJO_PYTHON -m gate.tests.gateway_delivery` | 종료 0. 실제 격리 multiplex gateway/플랫폼 전달, 외부 소켓·운영 비밀·격리 밖 쓰기 거절 audit 활성. 운영 gateway 재시작 아님 | `task05-delivery-01.log` |
| `HEJO_SKIP_GOOGLE_SECRET=1 HEJO_SPARKLE_OFFLINE=1 bash app/scripts/build.sh` | 종료 0, BUILD_OK, codesign verify 성공. 기존 keychain 사용·HERMES_HOME 격리 | `task05-product-build-02.log` |
| 위 제품 빌드 첫 시도 | 종료 1. 임시 HOME에서 서명 인증서를 찾지 못함. 기존 keychain으로 실행 환경만 고쳐 재실행 | `task05-product-build-01.log` |
| team `./airport-check --snapshot "$PWD"` | 종료 0. boundary 80, document/compartments 0. 기준선 증가/재생성 없음 | `task05-airport-01.log` |
| 두 worktree git diff --check·변경 Python compile·SHA-256 생성/재독 | 종료 0, hejo 13개/team 65개. Python 각각 7/49개 compile | `source-checkpoint-06.log` |

실제 호출은 원래 폴더에서 worktree 경로를 지정한 경우도 있다. 표는 각 worktree 기준이며 정확한 argv/cwd가 새 실행 로그에 들어 있다. 오래된 로그의 argv를 추정해 만들지 않았다. 왕복 5에서 요청한 전체 Python 회귀는 위 최신 로그로 별도 수행했고, 변경 없는 나머지 범위는 증거를 재사용했다.

## 실패와 미완료의 처분

이전 `test_cm24_25_actual_cli_arguments`의 무확인 Google 개인 해제 성공 기대는 승인된 왕복 5 처분에 따라 위 시험으로 이관했고 전체 회귀에서 통과했다. 제품 거절은 그대로다. 이전 full pytest의 wire 설명 해시 실패도 기존 바이트 계약을 복원한 뒤 이번 전체 회귀에서 통과했다. 과거 `task05-full-hejo-01.log`의 2실패를 지우지 않고 최신 종료 0 증거와 구분한다.

AppKit AT-HC-27 창 활성 실패는 앞선 변경 전 HEAD 대조 빌드에서도 같은 assertion으로 재현됐으며 기존 로그를 유지한다. 새 Google NSPanel의 삭제 확인·취소·만료/늦은 응답은 `task04-app-build-07.log`/`task04-app-ui-04.log`에 수준2/3 증거와 실제 화면이 있다. v7은 Swift를 변경하지 않았다. 전체 AppKit 추가 실행 결과와 최종 개인값 결과는 아래 최종 증거 절에서 기록한다.

team의 기존 상위 conftest는 운영과 같은 값의 명부/금고 fixture를 강제로 지정한다. 이를 실행하지 않고 읽기 검토한 안전한 7파일을 --noconftest와 가짜 owner 값으로 검사했다. 따라서 전체 기존 team-kit suite를 통과했다고 하지 않는다. 새 Google suite의 전용 conftest와 실제 sandbox 시험은 그대로 실행했다.

강제 프로세스 종료가 release 링크와 영수증 원자 쓰기 사이에 발생하면 installed 링크/영수증 불일치로 닫히며 7판 복구 예외로 우회하지 않는다. 이번 release 갱신 실패 시험은 I/O 예외 복구이며 이 구간의 강제 종료 후 자동 복구 성공까지 입증하지 않는다. 운영 인계에서 호환 수정 패키지를 이용한 복구 판단이 필요하다. 기존 인증 자격/금고의 저장 단계 프로세스 종료 시험과 이 한계를 혼동하지 않는다.

검사기는 JSON과 기존 정상 serializer의 block YAML을 지원한다. flow/merge/alias·중복 키·알 수 없는 형식을 ‘전환 없음’으로 추정하지 않으며 운영 적용 전 정상 원본 형식의 적합성은 별도 확인한다. 실제 금고 원문을 반환하지 않는다. 자격 백업 자동 복원·원본 전환 항목 자동 삭제·검사기 수동 복사/우회는 금지한다.

## AC별 자체 처분

아래는 구현자의 증거 처분이며 독립 최종 수락 판정이 아니다. 수준4 운영 시험을 수준2 대역으로 대체하지 않는다.

| AC | 증거/처분 |
|---|---|
| REQ-GD-01.AC-01 | GD-T01/17: CLI/목록 투영·기존 모델 증거 유지. IR-1 실제 AppKit 상세/목록의 이메일 제거·연결 버튼·재조회 증거 추가. 실계정은 미확인 |
| REQ-GD-01.AC-02 | GD-T01/02: 취소·재인증 거절 불변, 전용 자격 삭제/legacy 해제. 수준2 증거 |
| REQ-GD-01.AC-03 | GD-T03/20: 소비자·조립/스킬·worker·실제 sandbox/공식 도구 경계. 수준2 증거 |
| REQ-GD-02.AC-01 | GD-T04: 실제 OAuth 라이브러리 대역의 계정 선택/신원 검증. 실제 계정 선택은 미실행 |
| REQ-GD-02.AC-02 | GD-T05/17: 취소·만료·권한/신원/저장 실패와 AppKit 만료 대역. 실환경 미확인 |
| REQ-GD-02.AC-03 | GD-T06/07: state/PKCE·세대·기기/직원별 poll/cancel·늦은 응답. 수준2 증거 |
| REQ-GD-03.AC-01 | GD-T08: 다른 직원/회사/공용 자격 지문과 company/legacy 회귀. 실제 계정 불변은 미확인 |
| REQ-GD-03.AC-02 | GD-T09/20: SDK24명령·실제 등록→승인→handler/worker·조립, 기존 제한을 보존. 수준2 증거 |
| REQ-GD-03.AC-03 | GD-T10: 권한/배경·단건/계획 승인·저장 대기·메일/Calendar undo의 옛 binding 거절. 이번 Calendar 회귀 보완 |
| REQ-GD-04.AC-01 | GD-T11/12: 기존 인증 저장 단계 프로세스 종료·CAS/lease, 이번 복구 삽입/잠금 경합·I/O 복구. 배포 강제 종료 자동 복구는 위 한계 |
| REQ-GD-04.AC-02 | GD-T03/13: 단일 금고 원본·조립, absent/null/손상/unknown 분기와 읽기 무변경. 수준2 증거 |
| REQ-GD-04.AC-03 | GD-T14: 기존 R10/7·8판 독립 수용 유지. 왕복15 명시적 최초 전환/각 쓰기 실패복구/강제 종료 거절과 실제 release→전체 bundle 시험241 및 후속11 표적 통과. 새 독립 재검토·운영 수락은 남음 |
| NFR-GD-01.AC-01 | GD-T15/20: 기존 권한/경로·도구 보호 증거 유지. 승인된 공개 값 정리와 최신 격리/canonical 전체 검사0. Terra checkpoint-10 최종 재검토에서 IR-1 해소 |
| NFR-GD-02.AC-01 | GD-T16: 임시 홈/가짜 데이터·외부 API 금지, 82+156+2와 gate87/설치124. 기존 hejo 전체522·후속13fixture 증거 유지. 이번 기본9/불완전 응답/Google 시트 통과. GUI 준비 후 원본 연결 전체·연결 관리 종료0, 기존 HC27/CM35 실패 해소. 왕복15 고정 후속 원본에서도 재현된 Notion12실패 처분이 남으며 전체 team 통과를 주장하지 않음 |
| REQ-GD-05.AC-01 | GD-T17/18: 앞선 화면 증거 유지. 왕복11의 노출된 창 닫기 버튼·전송 불가/재열기·늦은 응답 보호와 기존 취소 회귀 통과. 실제 늦은 poll 안내 결함 수정. Terra checkpoint-10 최종 재검토에서 IR-1 해소, GD-T19 별개 |
| REQ-GD-05.AC-02 | GD-T19: 미실행. 별도 운영 인계 승인 뒤 사용자가 실계정 교체와 다른 직원 불변을 확인해야 함 |

요구된 네 결함 주입은 아래 별도 격리 실행으로 확인했다. 고위험 Terra 독립 검토는 checkpoint-10에서 수용됐으며 최종 제품 수락·현재 명세 반영·운영 적용/사용자 OAuth/화면 푸시 승인은 미완료다. 기획/검토 담당이 공개 검사/UI 최신 증거와 나머지 증거 한계를 처분한 뒤 TASK-06 운영 인계를 준비한다. 구현자는 운영/푸시를 실행하지 않는다.


## 최종 추가 증거

| 실행 | 실제 결과 | 로그 |
|---|---|---|
| 최종 Swift 시험 실행 파일의 전체 기본 모드, 정상 app cwd·새 제품 리소스·임시 HOME/HERMES_HOME | 종료 1. AT-PG-08 interruption fixture running에서 실패. 과거 결과다. 직접 선행 오류는 aiohttp import 실패였고 왕복 5에서 환경을 고쳐 AT-PG를 통과했다 | `task05-app-full-02.log` |
| 전체 AppKit 첫 시도 | 종료 1. 잘못 지정한 cwd의 .build에 스냅샷 파일을 만들지 못했다. runner cwd를 기존 app/scripts/test.sh와 맞춰 위 재실행. 제품 수정 없음 | `task05-app-full-01.log` |
| 별도 임시 프로세스의 메모리 내 결함 주입: T03 resolver fallback 허용 | 해당 수락 시험 종료 1로 결함 검출 | `task05-mutation-fallback.log` |
| T07 session/세대 비교 제거(restart 후 늦은 완료) | 해당 시험 종료 1로 결함 검출 | `task05-mutation-generation.log` |
| T09 worker credential을 공용 가짜 자격으로 교체 | 해당 시험 종료 1로 결함 검출 | `task05-mutation-worker-token.log` |
| T10 승인 binding 검사 제거 | 해당 시험 종료 1로 결함 검출 | `task05-mutation-approval-binding.log` |
| 위 네 결함 주입 driver | 종료 0. 네 기대 실패 모두 확인, 제품 소스 변경 없음 | `task05-mutations-01.json` |

네 주입은 임시 HOME/HERMES_HOME·가짜 명부/자격에서만 실행했고 실제 코드 파일을 고치지 않았다. 각각은 앞선 정상 Google suite에 포함된 시험으로 정상 통과와 주입 시 실패를 구분했다. 이 자체 점검을 독립 검증으로 부르지 않는다. 과거 AT-PG 실패와 현재 AT-HC-27 실패를 분리했다. 최신 실행 및 대조는 왕복 5 표를 따른다.

## 정리 전 공개 검사와 당시 차단

`python3 scripts/scan_private.py`를 실제 운영 owner 비교 입력으로 두 번 실행했다. 가짜 HERMES_HOME을 제거했고 검사기가 명부/금고를 내부 비교하는 기존 동작만 사용했다. 원문·일치 값·비밀 파일은 반환/열람하지 않았다. hejo worktree와 canonical 문서가 있는 원래 저장소 모두 종료 1이다. 각각 30건/14파일이며 전부 기존 HEJO-DRAWER-INLINE·HEJO-UI-CLEAN mockup이다. `git show HEAD:<파일>`의 줄 지문과 내부 대조하여 모든 검출 줄이 기준 HEAD에도 있음을 확인했다. 이번 작업 파일에서는 검출되지 않았다. 이 사실은 전체 공개 검사 통과가 아니다. 범위 밖 mockup을 임의 수정하거나 허용 목록/검사 기준을 완화하지 않았다.

새 미추적 코드·문서까지 검사하도록 별도 임시 Git index에 intent-to-add만 넣어 실행했다. 실제 index는 SHA-256 전후 동일하다. 스캐너는 수정하지 않았다. 로그는 `task05-private-hejo-01.log`, `task05-private-canonical-01.log`, 범위/종료 코드는 `task05-private-01.json`, 원문 없는 기준 HEAD 대조는 `task05-private-baseline-01.json`이다. 두 전체 검사는 checkpoint-05 시점이며 이후 작은 영수증 타입/secret 제외 변경과 최종 문서는 추가 범위 검사로 구분한다.

마지막 정적 확인에서 boolean 영수증 버전이 정수 버전으로 취급되는 Python 비교를 hejo/운영 bootstrap 모두에서 거절하도록 보강했다. 설치된 검사기 위치 거절 9개는 `task05-receipt-format-01.log`에서 종료 0(64 deselected)이다. release의 기존 secret 사후 삭제를 rsync 입력 제외로 바꿔 secret 파일을 복사하거나 열지 않게 했다. 읽기 권한이 없는 가짜 secret config를 심은 시험과 실제 배포본/두 위치/A→B 경계 7개가 `task05-release-final-01.log`에서 종료 0(72 deselected)이다. 이 변경은 실제 secret 파일을 사용해 시험하지 않았다.

추가 범위 검사 결과는 hejo 변경 13개와 canonical 작업 문서 11개 각각 종료 0이다. 실제 owner 비교를 유지하며 임시 index로 해당 범위만 선택했다. `task05-private-scope-hejo-01.log`, `task05-private-scope-canonical-01.log`, `task05-private-scope-01.json`에 범위를 기록했다. 이 축소 검사는 실패한 전체 공개 검사를 대체하지 않는다. 최종 코드에 대한 airport-check도 `task05-airport-final-01.log`에서 종료 0이다.

## 이전 운영 인계 초안 — 현재 실행 절차로 사용 금지

1. 최종 검토·공개 검사 차단을 처분한 뒤 각 저장소의 승인된 코드/전체 커밋과 배포 산출물을 고정한다. 지원 선언과 공통 검사기 지문을 기록한다. 현재는 결과 커밋이 없어 이 단계가 끝나지 않았다.
2. 사용 중인 공유 출력에 덮어쓰지 않고 `install/hejo-release <새 배포 위치>`로 새 산출물을 준비한다. 각 홈은 그 배포본 `install/hejo-install --home <설치 홈>`으로 검사·갱신한다. 실제 운영에서는 별도 승인 없이 실행하지 않는다.
3. team-kit은 정지/동시 작업 여부를 확인한 승인된 유지 시간에 `hermes-team-kit-deploy apply --source <검증 kit> --root <설치 홈>`으로 적용한다. 원래 manifest와 직원 데이터는 보존한다. 연결 저장소 배치 변경이 필요한 경우에만 검사된 plugin-store migrate/restore-copies를 쓴다.
4. 실패 복구는 고정된 현행 검사기로 호환 이전 산출물을 검사하는 `rollback --source <검증 복구 kit>`/installer 복구 경로만 사용한다. 구버전·전환 기록/잔존 인증·검사기 오류·불완전 installed 링크는 우회하지 않는다. 전용 자격 백업을 되살리거나 전환 항목을 지워 초기 설치로 위장하지 않는다. 복구 불확실 시 기능을 닫고 운영 판단을 받는다.
5. gateway 재시작·실계정 해제/계정 선택은 TASK-06 별도 승인 뒤 사용자 직접 수행한다. 새 계정 표시와 해당 직원 읽기 전용 확인·다른 직원 불변을 비밀/메일 본문 없이 확인한다. 푸시는 검토·검증·커밋 뒤 사용자 화면 승인으로 플러그인만 실행한다.

현재 커밋 검토 후보는 checkpoint-13의 각 worktree 파일과 최신 canonical 작업 문서/수락 명세다. 위 초안은 과거 기록이며 실제 적용에는 최신 deployment-handoff만 사용한다. 다른 작업의 변경은 포함하지 않는다. UI 활성 조건은 사용자 GUI 준비 후 실제 성공을 확인했다. Terra IR-1은 해소됐다. 운영 GD-T19와 최종 전달 절차가 남으며 푸시 준비 완료로 먼저 보고하지 않는다.

## 전체 변경 파일

현재 원본은 source-checkpoint-13.log다. 아래는 원래 구현 전 기준부터 현재 작업 트리까지의 전체 집합(문서 포함)이며, HEAD 위의 미커밋 집합과 구분한다. 지정 Git 통합/기존 구현/최초 전환/문서의 변경 이유는 위 책임 설명을 따른다.

hejo (54개):

- `app/Sources/ConnectionModels.swift`
- `app/Sources/ConnectionsWindow.swift`
- `app/Sources/HooksHelp.swift`
- `app/Tests/ConnectionsTests.swift`
- `app/Tests/TestMain.swift`
- `app/Tests/google_connection_fixture.py`
- `app/Tests/test_help_package.py`
- `app/scripts/build.sh`
- `docs/changes/HEJO-DRAWER-INLINE-20261122/mockups/filter-options.html`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/brainstorm.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/deployment-handoff.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/design.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/handoff.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/impl-report.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/independent-review-request.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/independent-review.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/plan-review.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/spec.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/tasks.md`
- `docs/changes/HEJO-GOOGLE-DISCONNECT-20261124/workspace-command-map.md`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/clean.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/clean2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/composer.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-3.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final-4.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/final.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/improve-1-6.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/improve-all.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/pill-replace.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/simple.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/title-pill-2.html`
- `docs/changes/HEJO-UI-CLEAN-20261123/mockups/title-pill.html`
- `docs/changes/c20a9994-041b-4225-bc8f-f457d10cf651/plan-review.md`
- `docs/changes/c20a9994-041b-4225-bc8f-f457d10cf651/verdict.md`
- `gate/README.md`
- `gate/adapter.py`
- `gate/connection_manager.py`
- `gate/connection_runtime.py`
- `gate/telegram.py`
- `gate/telegram_comments.py`
- `gate/tests/test_telegram_comments.py`
- `install/check_google_compat.py`
- `install/google-connection-support.json`
- `install/hejo-install`
- `install/hejo-release`
- `tests/acceptance/HEJO-GOOGLE-DISCONNECT.md`
- `tests/acceptance/test_conn_manage.py`
- `tests/acceptance/test_google_bundle.py`
- `tests/acceptance/test_google_bundle_absence.py`
- `tests/acceptance/test_google_deployment.py`
- `tests/acceptance/test_google_disconnect.py`
- `tests/acceptance/test_google_legacy.py`
- `tests/acceptance/test_google_release.py`

team (88개):

- `hermes/bin/hermes-plugin-store`
- `hermes/bin/hermes-skill-assemble`
- `hermes/bin/hermes-team-kit-deploy`
- `hermes/plugin-store/team-delegation/plugin.yaml`
- `hermes/plugin-store/team-kit/__init__.py`
- `hermes/plugin-store/team-kit/google-connection-support.json`
- `hermes/plugin-store/team-kit/lib/hermes_execution/__init__.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/personal_roles.py`
- `hermes/plugin-store/team-kit/lib/hermes_execution/personal_scopes.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/account_connect.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_connect.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_scope.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/app_setup.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/config_assembly.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/connection_checks.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/connections.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection_auth.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_connection_sdk.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/google_deployment.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/pack_selection.py`
- `hermes/plugin-store/team-kit/lib/hermes_facility/plugin_store.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/approval.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/calendar_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/contracts.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/google_calendar_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/mail_undo.py`
- `hermes/plugin-store/team-kit/lib/hermes_governance/request_approvals.py`
- `hermes/plugin-store/team-kit/lib/hermes_owner_chat.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/google_calendar_accounts.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/calendar/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/catalog.json`
- `hermes/plugin-store/team-kit/lib/hermes_packs/diagnosis/diagnosis_runtime.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/files.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/files_docs/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/app_catalog.json`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/catalog.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/discovery.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mac_apps/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/GOOGLE-WORKSPACE-LICENSE`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/__init__.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/full_mail_tools.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/gmail_extra.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/gmail_watch.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/google_workspace.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/organization_state.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/pack.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/mail/plugin.yaml`
- `hermes/plugin-store/team-kit/lib/hermes_packs/notion/api.py`
- `hermes/plugin-store/team-kit/lib/hermes_packs/notion/operations.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/doctor.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/error_digest.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/mail_waiting_worker.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/memory_live.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/personal_mail_summary.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/personal_review.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/secret_guard.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/wait_jobs.py`
- `hermes/plugin-store/team-kit/lib/hermes_team_services/work_runtime.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/conftest.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_cli.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_connection.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_consumers.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_native_workspace.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_notion_integration.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_oauth.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_queued.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_recovery.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_skill_boundary.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_workspace.py`
- `hermes/plugin-store/team-kit/tests/google_disconnect/test_workspace_assembly.py`
- `hermes/plugin-store/team-kit/tests/test_app_catalog.py`
- `hermes/plugin-store/team-kit/tests/test_app_registry.py`
- `hermes/plugin-store/team-kit/tests/test_error_digest.py`
- `hermes/plugin-store/team-kit/tests/test_files.py`
- `hermes/plugin-store/team-kit/tests/test_hejo_session_proof.py`
- `hermes/plugin-store/team-kit/tests/test_owner_provenance_hejo.py`
- `hermes/shared/secretary-skills/employee-google-workspace/SKILL.md`
