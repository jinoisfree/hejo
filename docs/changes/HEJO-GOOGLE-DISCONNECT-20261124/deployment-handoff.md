# Google 개인 연결 배포 인계 — design8판 검토 후보

**왕복15 통합·명시적 최초 전환 구현/자체 시험 제출, Terra 재검토 대기. 운영 미적용.** [설계9판](design.md)·[작업](tasks.md)·[구현 보고](impl-report.md)를 따른다. D1/D2·IR-1 수용은 유지한다. 고정 후속 기능과 최초 전환을 구현했으나 기존 Notion12실패의 처분, 새 독립 검토·불변 후보/호환 복구 묶음·앱 운영 구성·사용자 GD-T19와 실제 운영 승인은 남는다. 앞선 r4 후보는 역사적 자료다.

## 소스와 산출물 경계

| 저장소 | 이번 구현 기준 HEAD | 브랜치 | 원격 이름 |
|---|---|---|---|
| hejo | `d25530649f7eb898e2f5cbc5cb471c1417823632` | `role-workflow/google-disconnect-c20a9994` | github |
| 운영 저장소 | `33d6671993473c0eb7ecb4087e0fe4edebc63050` | `role-workflow/google-disconnect-c20a9994` | origin |

8·9판과 왕복15 통합 변경은 위 커밋 위의 미커밋 작업 트리다. 기존 커밋을 amend/rebase하지 않았다. 실제 범위/파일별 지문은 `.build/google-disconnect-evidence/source-checkpoint-13.log`, 실행 argv/cwd/환경·결과는 round13 로그, 이전 문서/계획 보호는 round13-intake.json으로 대조한다. 개인 실제 경로·운영 앱 위치/영수증과 시설 지문은 ignored 로컬 증거에만 기록한다.

앱 안내 원문은 Resources/연결안내.html 하나다. 빌드 산출물/Bundle 조회는 ASCII connection-help.html이며 서명 전 NFC/NFD 옛 이름의 잔재만 제거한다. 일반/반복 빌드, 다른 임시 위치 압축 왕복 deep strict 서명 및 실제 HooksHelp Bundle 조회·원문 일치를 확인했다. `HEJO_SKIP_GOOGLE_SECRET=1`, `HEJO_SPARKLE_OFFLINE=1`인 검증 빌드이므로 운영 공유 Google 로그인·업데이트 구성 완료를 뜻하지 않는다. 비밀 주입/추출 후 재서명은 하지 않았다.

## bundle 선언과 원본 소유

기존 team-kit/google-connection-support.json의 bundle 항목은 version=1, kit_sha256, files(명시적5경로의 sha256/mode), predecessor(검토된 이전 키트/5파일의 식별)를 가진다. 금고/직원 설정 원본을 새로 만들지 않는다. 키트 식별은 지원 선언 자신·캐시를 제외한 시설 본문/모드/내부 링크를 포함한다. 정책/허용 경로의 원본은 기존 단일 hejo install/check_google_compat.py다. 지원 선언 생성도 그 원본의 식별 함수를 사용하며 producer는 ignored round13-support.py에 기록한다. 값/지원 버전/경로가 누락·변조되거나 묶음이 섞이면 쓰기 전에 거절한다.

첫 bundle 전환은 선언에 고정한 검토된 predecessor만 허용한다. 현재 소스 선언의 predecessor는 design9판 보완의 고정 legacy 커밋9488a060e7bf5646af69628b29b34c28cfc18109에서 재현한 kit/동반5경로 식별이다. 설치되어 있지 않던2경로는 부재로 고정한다. 이 출처 채택과 임시 홈 시험은 실제 운영 상태/실행 승인이 아니다. 이후 bundle은 현재 선언 전체가 실제 파일과 일치해야 한다. 동반이 필요한 현재/후보의 kit-only apply/rollback 및 restore-copies/migrate를 거절한다. 플래그를 모르는 옛 호출자도 단일 검사기의 기본 team-kit 검사에서 거절된다. 동반 필요가 없는 미전환 kit-only는 유지한다.

동일 금고 mutex/gateway 중지 조건에서 전체 stage와 사전 검사 뒤 kit/5파일/영향받는 overlay·links.json·선택된 매뉴얼 결과를 적용한다. 원본 manifest는 시설 선언, 기존 사용자 grant/선택/비관련 필드는 소유자 원본이다. config_assembly의 합성은 선택된 전환 직원의 네 도구 선언만 추가하고 grant/앱·팩 선택을 쓰지 않는다. 선택되지 않은 직원의 overlay manifest/스킬은 바꾸지 않는다. source link의 원본 선언 갱신은 grant 부여가 아니며 기존 runtime 권한 검사를 유지한다. 스킬은 기존 owner/skill-assembly.yaml에서 선택한 직원만 기존 prepare로 조립하고 사람이 편집한 결과는 거절한다.

쓰기 실패 시 고정한 이전 전체 시설/조립 결과의 본문·모드·존재/부재를 복구한다. 이미 이전 상태인 항목은 재쓰지 않는다. owner 금고/토큰/명부/정책/선택 원본은 복구 사본에 넣지 않고 입력 지문만 비교한다. 정책은 검증한 현재 설치 코드에서 메모리로 고정한다. 강제 종료/복구 실패의 stage가 남으면 성공/자동 복구로 간주하지 않고 다음 배포/토폴로지 변경·검사가 거절한다. 이전 시설과 transaction.json을 보존하며 무조건 재실행/삭제로 넘기지 않는다.

## 비밀 제외 운영 확인과 현재 전달 조건

실제 시설을 읽은 마지막 원본은 `.build/google-disconnect-evidence/round14-inventory.json`, `round14-provenance.json`, `round14-baseline-coverage.json`, `round14-profile-topology.json`이다. 이번에는 운영 시설/금고/비밀을 새로 읽거나 바꾸지 않았다. 실제 개인 경로/홈 이름은 ignored 증거만 참조한다.

- design9판에서 hejo a3df84e48fae8b36c27a572a5ee36247cc46acf3, 운영 저장소9488a060e7bf5646af69628b29b34c28cfc18109를 legacy 출처로 채택했다. 지정5/23파일을 후보에 보존 통합했다. 당시 hejo43파일·kit681항목·동반5경로의 식별은 미래 적용 시점의 동일성을 보증하지 않는다.
- 당시 installed/version2 영수증의6링크는 실제 gate와 일치했고 기본 홈+프로필6개 중1프로필은 hejo 미설치였다. 새 최초 전환은 그때의 이름/집합을 하드코딩하지 않고 실제 적용 직전에 전체 집합·영수증·설치된 링크와 기준 시설을 재확인한다. 미설치 프로필을 자동 편입하지 않는다.
- 현재 명시적 최초 전환은 구현됐고 임시 홈에서 release→새 검사기→전체 bundle을 확인했다. 링크/영수증 외 owner/admin/config/기기·자격은 쓰지 않는다. 영수증의 upgrading-legacy/legacy_upgrade는 중단 상태의 코드 경로·이전 링크만 기록하며 금고/자격 사본이 아니다.
- 일반 설치의 현재 검사기 규칙은 유지한다. 기존 검사기가 있는 홈, failed/uninstalled/중간 영수증, 지원/기준/상태·권한·경로를 판정할 수 없는 홈에 --upgrade-legacy를 사용하지 않는다. 전환 기록·전용 자격·활성 인증/worker·gateway PID·남은 배포/설치 흔적이 있으면 닫힌다. 원문 토큰/.env/auth.json을 읽거나 백업하지 않는다.
- 새 Terra 검토와 기존 Notion12실패 처분, 최종 두 소스 커밋/불변 hejo·bundle·앱·호환 복구 묶음 고정이 필요하다. 운영 앱의 Google 로그인/업데이트 구성·교체 대상과 승인된 중단/재개 명령도 미확정이다. 검사기/동반2파일만 복사하거나 영수증을 위조해 맞추지 않는다.

## 승인 뒤 사용할 현재 대상 절차 — 전부 미실행

위 전달 조건과 새 독립 검토를 완료한 뒤 모든 영향 홈·중단/재개 대상과 정확한 명령·새/복구 묶음을 사용자에게 제시해 별도 승인을 받는다. 개인 실제 변수는 ignored 로컬 인계에서 확정한다. HEJO_RELEASE는 서명/구성·소스가 검토된 새 release 디렉터리, TEAM_BUNDLE은 kit+동반5파일을 포함한 시설 루트다. 작업 체크아웃을 최초 전환 release로 사용하지 않는다.

```sh
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component hejo --target "$HEJO_RELEASE" --validate-build
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component team-kit --target "$TEAM_BUNDLE" --bundle --validate-build
```

승인된 gateway/영향 worker 중단을 먼저 확인한다. 설치된 검사기가 없고 고정 legacy 전체 식별·정상 installed/applied 영수증/실제 링크·전환 부재 조건이 충족된 **현재 대상**은 아래 명시적 경로만 쓴다. 명령은 거절 조건을 완화하거나 프로세스를 중단/재시작하지 않는다. --port/--hub/--force를 더하지 않는다.

```sh
"$HEJO_PYTHON" -B "$HEJO_RELEASE/install/hejo-install" --home "$AIRPORT_ROOT" --upgrade-legacy
```

성공 뒤 영수증과 모든 설치 링크가 새 release를 가리키며 일반 현재 검사기 탐색이 새 검사기로 확정되는지 확인한다. CURRENT_CHECKER는 실제 installed/applied 링크에서 찾으며 PATH/cwd로 대체하지 않는다. 같은 중단 상태에서 전체 bundle을 검사/적용한다. 이 대상에서는 이미 링크를 바꾼 뒤 일반 installer를 중복 실행하지 않는다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$TEAM_BUNDLE" --bundle
"$HEJO_PYTHON" -B "$TEAM_BUNDLE/bin/hermes-team-kit-deploy" apply --root "$AIRPORT_ROOT" --bundle "$TEAM_BUNDLE"
```

선택/권한 원본·manifest/등록·스킬/overlay·실행 모드·영수증/모든 링크·지원 선언과 새/복구 묶음 일관성을 확인하기 전 새 앱/코드를 실행하거나 gateway/worker를 재개하지 않는다. 이번 가짜 홈에서는 이 경로의 정상 및 각 실패를 검증했지만 실제 모든 홈의 상태·프로세스 중지나 사용자 GD-T19를 대신하지 않는다. 구체적인 운영 명령과 앱 교체/되돌림은 승인 자료에 확정한 뒤만 쓴다.

## 실패 복구와 중단 조건

복구 대상은 현재 정책으로 검증하고 독립 검토/사용자 승인을 받은 호환되는 **전체** hejo/bundle/app 묶음이어야 한다. 성공한 최초 전환 뒤 고정 legacy 코드로 되돌리는 운영 절차는 제공하지 않는다. 최초 전환 자체의 I/O 실패 복구와 구별한다. Google 전환 기록이 있는 홈에 지원 없는 옛 키트를 적용하지 않는다. 독립 검토/대상 확인 뒤 복구 묶음을 먼저 고정한다. 금고 연결/전용 자격을 과거 사본으로 되돌리지 않는다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component hejo --target "$RECOVERY_HEJO"
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$RECOVERY_BUNDLE" --bundle
"$HEJO_PYTHON" -B "$RECOVERY_HEJO/install/hejo-install" --home "$AIRPORT_ROOT"
"$HEJO_PYTHON" -B "$TEAM_BUNDLE/bin/hermes-team-kit-deploy" rollback --root "$AIRPORT_ROOT" --bundle "$RECOVERY_BUNDLE"
```

최초 전환 I/O 실패는 전환 부재/중지/잠금/입력 일관성을 재검사한 뒤 같은 실행 안에서 기존 링크·영수증만 복구한다. 그 도중 전환이나 집합 drift가 생기면 옛 코드 복구를 하지 않는다. upgrading-legacy 또는 orphan 설치 임시 흔적이 남으면 자료를 보존하고 다음 실행을 거절한다. 이후 전체 bundle의 일반 I/O 실패는 검증된 이전 전체 시설과 조립 결과를 복원한다. 복구 불가·중단 stage·검사기/영수증 불일치·지원 거절·동시 입력/대상 변경·symlink/경로 탈출·살아 있는 gateway·소유자 편집 충돌이면 닫히고 자료를 보존한다. 중단 stage 삭제, 영수증 수동 작성, 강제 링크, 금고 전환 삭제, 자격 복원으로 우회하지 않는다. 강제 종료 후 명시적 복구는 남은 자료와 실제 조합의 별도 기획/운영 판단이 필요하며 자동 성공으로 보고하지 않는다.

## 사용자 GD-T19 — 별도 승인 후 직접 수락

현재 전부 미실행이다. 대상 직원 한 명의 개인 연결 해제 확인→목록/상세 이메일 제거와 연결 버튼→Google 계정 선택에서 다른 계정 동의→새 계정 표시와 승인된 읽기 전용 확인→다른 직원 연결/접근 범위 불변을 사용자가 확인한다. 취소/실패를 성공으로 표시하지 않는다. 항목별 성공/실패·시각·최소 오류 종류만 기록하고 비밀/토큰·메일 본문·실제 이메일을 공개 증거로 요청하지 않는다. 실계정 뒤 TASK-07 현재 명세 승격/최종 판정은 기획 소유다. 운영과 푸시는 별도 승인이다.

## 왕복13 — 구현 전 동반5파일 대응표

아래는 design8판의 구현 경계다. 기존 r4 인계는 역사적 후보이며 운영 미적용이다. 원본 경로의 `hermes/` 아래가 bundle 입력 루트이고 대상은 승인된 임시/운영 루트 상대 경로다. 실제 운영 적용 승인은 추가되지 않았다.

| 저장소 원본 | 대상 상대 경로 | 조립·소유 경계 | 복구 단위 |
|---|---|---|---|
| hermes/bin/hermes-plugin-store | bin/hermes-plugin-store | 기존 plugin_store의 링크/overlay/links.json 검사·마이그레이션. 별도 정책 원본 없음 | 파일 존재/부재·본문·실행 모드 및 영향받는 links.json |
| hermes/bin/hermes-skill-assemble | bin/hermes-skill-assemble | owner/skill-assembly.yaml의 기존 직원 선택과 google_connection 투영. owner 원본·grant·사용 기록은 읽기 전용. 기존 soul 조립 코드 의존성은 새 배포 대상으로 만들지 않음 | 파일과 선택된 직원의 해당 스킬 결과 존재/부재·본문·모드 |
| hermes/bin/hermes-team-kit-deploy | bin/hermes-team-kit-deploy | 명시적 bundle 입력으로 키트+5파일을 같은 금고 mutex/gateway 중지 경계에서 stage/적용. 실행 코드·검사기는 시작 시 고정 | 파일 자신을 포함한 이전 전체 묶음; 실패한 stage는 명시적 복구 판단 전 보존 |
| hermes/plugin-store/team-delegation/plugin.yaml | plugin-store/team-delegation/plugin.yaml | 원본 provides_tools 선언과 사용자 overlay를 구분. config_assembly의 기존 manifest 합성에서 신규4선언만 반영하고 기존 도구 선택·grant·비관련 필드 보존. link는 원본 갱신, overlay는 합성/links.json 지문 함께 갱신 | 원본·영향받는 overlay·links.json; 사용자 권한 원본은 되돌리지 않음 |
| hermes/shared/secretary-skills/employee-google-workspace/SKILL.md | shared/secretary-skills/employee-google-workspace/SKILL.md | 기존 prepare의 선택 직원만 새 원문으로 조립. 이전 생성 원문과 다르게 사람이 편집한 결과는 거절. 선택 목록에 없는 직원에게 새 스킬을 설치하지 않음 | 원본과 선택된 조립 결과를 함께 복구; owner 선택/금고/토큰은 스냅샷 금지 |

키트 본문·동반5파일의 모드/본문 식별은 기존 google-connection-support.json의 bundle 선언에 포함한다. 새 소유자 설정 원본은 없다. 키트와 동반 파일이 요구되는 후보/현재 설치에서는 기존 kit-only apply/rollback을 거절하고 기존 비bundle 계약은 유지한다. 이전 묶음의 검증·stage가 완료되기 전 쓰지 않으며, 남은 중단 stage가 있으면 정상 재실행으로 위장하지 않는다. 새 manifest 필드나 사용자 편집이 원본 소유 선언과 충돌하면 쓰기 전에 거절한다.
