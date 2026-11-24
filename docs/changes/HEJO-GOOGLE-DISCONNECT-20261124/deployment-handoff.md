# Google 개인 연결 배포 인계 — design9판 전달 후보

**왕복17 정식 앱 빌드·압축 검증 제출. 운영·실계정 미실행.** checkpoint14 제품과 기존 독립 검토 수용을 유지한다. 사용자는 현재 작업 흐름에서 기존 입력을 사용하는 정식 빌드/서명/압축 검증을 승인했다. 새 앱의 Google 로그인 구성 두 필드 존재와 추출 후 서명·실제 Bundle 안내 조회를 확인했다. 기존 Notion12실패는 원인 미확정 기존 불일치이며 전체 team 성공으로 표시하지 않는다. [구현 보고](impl-report.md)·[작업](tasks.md)을 따른다. 운영 승인·사용자 GD-T19·TASK07·푸시는 남는다.

## 고정 소스와 전달 지문

| 저장소 | 전달 실행 소스 커밋 | 브랜치 | 원격 이름 |
|---|---|---|---|
| hejo | `09a5d31db54620814203fc079f706501b2b92bb0` | role-workflow/google-disconnect-c20a9994 | github |
| 운영 저장소 | `1af03d46dabdbe49f4e3ef3ca92aaaf2b321371d` | role-workflow/google-disconnect-c20a9994 | origin |

기존 커밋 위에 각각22/31파일을 후속 커밋했다. 구현 전 기준 대비 최종 범위는 hejo54/team88파일이다. checkpoint13의 제품·시험은 동일하며 최신 검토 문서4개를 반영했다. 이 시설 실행 소스는 왕복16에서 고정했다. 새 앱의 빌드 소스 커밋은 `ac4643abdbe05be788ebbb31ece600cd808cf8de`이며 빌드 당시 clean이었다. 최신 검토 문서와 이 인계/구현 보고를 담는 후속 문서 커밋은 실행 소스와 구분하며 전체 HEAD·파일별 지문·clean 상태는 `.build/google-disconnect-evidence/round17-closure.json`에 고정한다. 실제 경로와 명령·환경은 ignored 증거에만 둔다.

후보 디렉터리는 `.build/google-disconnect-delivery/ac4643abdbe0-1af03d46dabd-configured-round17`이며 운영 경로에서 사용하지 않았다. hejo/team 압축은 왕복16의 고정 Git 입력에서 실제 release/전체 bundle 조립·압축 왕복을 통과한 파일을 지문 대조 후 바이트 그대로 재사용했다. 이전 후보는 변경하지 않았다. manifest SHA-256은 `66712741c306079ca9a930732893a53f57adcf0d32f932159294637942233539`다.

| 구성 | 파일 | SHA-256 |
|---|---|---|
| hejo | `hejo.tar.gz` | `beb7e733b11c69aea4a41793507671ba6677dbc82d90a2f6594d1a128445bc75` |
| team-bundle | `team-bundle.tar.gz` | `7f50b3f93bd5d5846618fd5c3f2062463725cd6dfb10c21f5237a020f0c949b9` |
| hejo.app | `hejo.app.tar.gz` | `0ef168c84e8109755c6cc2aeca4e82495a8b86855948b8a597a5d76ccc8211fa` |

위 hejo/bundle은 작업 트리/운영 설치를 참조하지 않는 압축본이다. 새 앱은 위 clean 커밋에서 기존 app/scripts/build.sh로 빌드했다. 빌드에서는 HEJO_SKIP_GOOGLE_SECRET를 제거했고 기존 고정 Sparkle 의존성을 재사용했다. 원래 작업 폴더의 기존 config/google-oauth-secret.json을 빌드 도구가 소비해 자식 빌드 환경으로만 전달했다. 자격 파일을 격리 worktree에 복사하거나 비밀/전체 환경·Info.plist 원문을 출력하지 않았다.

app/Tests/test_help_package.py를 **--verify-existing --artifact-out <새 ignored 후보>**로 실행했다. 기본 모드/비밀 제외 재빌드는 실행하지 않았다. 시험 전후 실행 파일·Info.plist 파일 지문은 같고 추출본의 Google 두 필드도 존재했다. strict deep 서명·실제 HooksHelp Bundle 안내 조회·원문 본문 일치가 통과했다. 내장 BuildInfo는 빌드 당시 clean tree 식별을 가지며 두 필드의 실제 값은 보고하지 않는다. 실행 명령·종료 코드·소스 입력/산출물 지문은 round17-build.json/log·round17-package.log·round17-artifacts.json에 있다.

### 호환 복구 후보

`recovery/`에는 위 세 압축본과 바이트가 같은 별도 사본을 고정했다. recovery/manifest.json SHA-256은 `7d36a565d85644ba116deae8a3742666904c3fd505ac2a2cfc55deab4abd0817`다. 현재 지원되는 전체 시설 코드와 같은 정식 구성 앱의 재설치/복원을 위한 후보이며 이전 기능 버전으로 되돌리는 후보가 아니다. 본문·모드·링크·지원 선언이 같은 세 파일을 함께 확인한다. 더 오래된 지원 버전의 별도 운영 복귀 후보는 검토·고정하지 않았다.

Google 전환 후 legacy hejo/kit로 복귀하지 않는다. owner 금고/전용 자격/직원 선택/권한의 사본은 후보에 없고 과거로 복원하지 않는다. 실제 설치의 지원·입력·stage가 불확실하면 같은 지원 버전이라는 이유로 강제 덮어쓰지 않는다. 현재 검사기가 검증할 수 있는 정상 상태에서만 아래 복구 명령을 사용한다. 앱 운영 구성을 다시 빌드하면 새 앱 파일을 전달/복구 양쪽에 함께 고정하고 새 지문·서명을 재검토한다.

## 지원 선언과 전체 bundle 경계

단일 정책 원본은 hejo `install/check_google_compat.py`다. 양쪽 지원 선언은 google-connection-support/1, versions=[1], disconnect_mode=forget_account를 유지한다. legacy.version=1의 고정 기준은 hejo a3df84e48fae8b36c27a572a5ee36247cc46acf3와 team 9488a060e7bf5646af69628b29b34c28cfc18109다. 출처 채택은 운영 승인이 아니다. 지원 선언 producer는 round15-support.py, 최종 값/대조는 round15-support-final.json과 round16-intake.json이다. round13의 옛 predecessor 생산물을 다시 사용하지 않는다.

현재 bundle kit_sha256은 `db43f0d07d74d1ba28f8fbcac4b233474a0c172215c995b07c76b82d76d2184f`다. 지원 선언 자신/캐시를 제외한 kit 본문·모드·내부 링크와 명시적5파일 식별을 확인한다. predecessor는 위 고정 legacy kit 및 기존3파일/부재2경로다. 선언/식별/모드·버전 누락, 섞인 묶음, 외부 링크는 쓰기 전에 거절한다. bundle이 필요한 현재/후보의 kit-only apply/rollback·restore-copies/migrate는 옛 호출자도 거절한다.

동일 금고 mutex/모든 영향 gateway 중지 조건에서 전체 stage·사전 검사·CAS·전체 결과 검사를 한다. owner 선택/grant·비관련 필드는 쓰지 않고 선택된 직원의 기존 overlay·links.json·매뉴얼만 기존 조립기로 갱신한다. 임시 stage에는 시설/조립 결과만 있고 owner/토큰 사본은 없다. 실패/중단 stage는 자료 보존 및 재실행 거절의 근거다. 중단 흔적을 지우거나 영수증/링크를 손으로 만들어 통과시키지 않는다.

## 현재 대상과 승인안 — 아직 실행하지 않음

비밀 제외 시설/전체 홈 조사는 round14-inventory.json·round14-profile-topology.json·round14-provenance.json·round14-baseline-coverage.json을 사용한다. 당시 루트+프로필6개 중 installed 영수증의6링크는 실제와 같고1프로필은 hejo 미설치였다. 적용 직전 전체 홈 집합·기존 링크·installed/applied 영수증·전체 양쪽 시설의 고정 기준 일치 여부를 다시 검사한다. 자동으로 미설치 프로필을 편입하지 않는다. 이후 운영 상태의 불변을 가정하지 않는다.

왕복16에서 기존 gateway/메일 신호 LaunchAgent2개의 **파일 지문만** 검토된 Git 템플릿과 대조해 일치를 확인했다. 실제 label/plist·중지/재개 argv는 ignored round16-metadata.json에 있다. 제안한 새 공유 release/bundle·기존 앱 대상·기록된 홈과 승인 조건은 round17-approval-proposal.json에 고정했으며 아직 승인된 운영 경로가 아니다. launchctl·프로세스/로그 조회·비밀/금고 열람·중지/재시작은 실행하지 않았다. 아래 GATEWAY_LABEL/GATEWAY_PLIST와 MAIL_SIGNAL_LABEL/MAIL_SIGNAL_PLIST는 그 확인된 두 대상만 사용한다. 추가 gateway/인증·메일/문서 worker 또는 예약 실행이 발견되면 임의 종료하지 않고 해당 대상과 중지 방법을 승인 범위에 추가하기 전 멈춘다.

승인 요청은 다음 묶음으로 제시한다.

1. 기존 설치6링크/실제 전체 홈을 새 **별도** 공유 release 경로로 전환하고 전체 team bundle을 적용한다. 기존 공용 디렉터리의 제자리 교체나 미설치 프로필 추가는 포함하지 않는다. 개인 실제 경로는 ignored 로컬 인계와 승인 화면에서 확인한다.
2. 진행 중 턴/작업이0이고 인증 작업이 없는 유지보수 창에 기존 앱을 정상 종료하고 메일 신호→gateway 순서로 내린다. 적용/검사 후 gateway→메일 신호 순서로 재개한다. 기존 채널의 수신 서비스 재개와 실제 메시지 발송 시험은 구분하며 고객/Slack 메시지를 보내지 않는다. 허브는 변경·재시작하지 않는다.
3. 이번에 고정한 정식 구성 앱을 운영 승인 후 기존 앱 설치 위치의 동일 bundle ID 앱으로 교체한다. 앱 파일만 복구하고 설정/키체인/로그인 항목을 덮어쓰지 않는다. 기존 앱 파일의 별도 보존은 운영 승인 후 결정하며 비밀이 내장될 수 있는 기존 앱을 공개 후보로 수집하지 않는다.
4. 각 단계의 중단·복구 조건을 허용하고 마지막에 사용자가 GD-T19를 직접 수행한다. 운영 적용 승인과 Google 실계정 동의·푸시 화면 승인은 각각 구분한다.

### 앱 운영 구성 보완 결과와 한계

정식 원본은 app/scripts/build.sh·fetch_sparkle.sh, GoogleSignIn/로그인창, UpdateRelease/AppUpdate, Resources/Info.plist다. 공유 Google 앱 로그인 두 구성 필드는 빌드본과 압축 추출본에서 각각 존재=true다. bundle ID io.github.hermes-hejo.hejo, 버전0.2.7/build9의 기존 설정과 서명을 유지했다. 새 OAuth 앱 생성·운영 자격 복사·서명 후 plist 수정은 하지 않았다. 기존 입력의 실제 값/내용 지문을 별도 수집하지 않고 필드 존재 여부와 전체 앱/압축 지문만 기록했다. 이전 왕복16의 ‘구성 없는 앱을 수용할지/다시 빌드할지’ 결정은 이번 승인·정식 빌드로 보완됐다.

이 결과는 필드 존재와 전달 무결성의 증거다. 실제 Google 앱 로그인 성공·허브 client ID/audience 일치·원격 OAuth 정책·직원 Google 동의는 검증하지 않았다. 앱 로그인과 직원 Workspace 연결은 서로 다른 기존 경로다. 운영 적용 후 별도 승인된 최소 로그인 확인과 사용자 GD-T19가 필요하다. 구성 존재를 실제 인증 성공으로 표시하지 않는다.

업데이트 저장소 선언·ED 공개키·Sparkle framework·서명 feed/추출 전 검증 조건은 유지됐다. HEJO_SPARKLE_OFFLINE=1은 고정 의존성 다운로드만 막으며 updater를 끄지 않는다. Sparkle 자체 자동 확인/자동 설치 plist 값은 false이고 앱의 기존 UpdateRelease/AppUpdate 경로는 유지한다. 실제 원격 feed 조회·새 업데이트 릴리스 게시/다운로드·실계정은 이번에 실행하지 않았다. 기존 서비스/앱 교체·재개는 새로운 운영 승인 후만 진행한다.

## 승인 후 적용 명령과 단계별 중단

아래는 승인용 템플릿이며 **전부 미실행**이다. 승인 화면에서 지정한 새 빈 staging 경로로 세 압축본을 해제하고 manifest/위 SHA-256·본문/모드/링크·codesign을 대조한다. HEJO_RELEASE는 새 hejo 디렉터리, TEAM_BUNDLE은 새 team-bundle 시설 루트다. 현재 작업 checkout이나 기존 운영 디렉터리 위로 해제하지 않는다. 압축 해제/검증만으로 운영 설치하지 않는다.

```sh
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component hejo --target "$HEJO_RELEASE" --validate-build
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component team-kit --target "$TEAM_BUNDLE" --bundle --validate-build
codesign --verify --deep --strict "$APP_CANDIDATE"
```

기존 제어 status에서 active_agents=0·active_work 없음 및 전체 홈/인증 장부의 유휴 상태를 확인한다. 기존 앱을 사용자가 정상 종료한 뒤 승인된 두 서비스만 내린다. bootout은 비동기일 수 있으므로 프로세스/PID가 실제 종료됐는지 확인한다. 해석 불가·활성/추가 worker는 즉시 중단 조건이다. 정책은 프로세스를 자동 중지하거나 신호를 보내지 않는다.

```sh
launchctl bootout "gui/$MAINTENANCE_UID/$MAIL_SIGNAL_LABEL"
launchctl bootout "gui/$MAINTENANCE_UID/$GATEWAY_LABEL"
```

정상 installed/applied 영수증·기존 checker 부재·전체 고정 legacy 코드·전환/null/자격/미완료 인증/배포 흔적 부재 조건인 현재 대상에만 명시적 최초 전환을 사용한다. --port/--hub/--force를 더하지 않는다. 다른 상태이면 중지하고 새 판정을 받는다.

```sh
"$HEJO_PYTHON" -B "$HEJO_RELEASE/install/hejo-install" --home "$AIRPORT_ROOT" --upgrade-legacy
```

성공하면 영수증과 원래 설치된 모든 링크가 새 release를 가리키고 정상 installed 탐색의 checker가 HEJO_RELEASE/install/check_google_compat.py와 같은지 확인한 뒤 CURRENT_CHECKER로 고정한다. 후보 경로를 현재 설치 검사기 대신 사용하는 fallback은 없다. 같은 중단 상태에서 전체 bundle만 적용한다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$TEAM_BUNDLE" --bundle
"$HEJO_PYTHON" -B "$TEAM_BUNDLE/bin/hermes-team-kit-deploy" apply --root "$AIRPORT_ROOT" --bundle "$TEAM_BUNDLE"
"$HEJO_PYTHON" -B "$HEJO_RELEASE/install/hejo-install" --home "$AIRPORT_ROOT" --check
"$HEJO_PYTHON" -B "$TEAM_BUNDLE/bin/hermes-plugin-store" --root "$AIRPORT_ROOT" --check
```

전부 성공한 뒤 owner 선택/grant 불변·선택/권한에 맞는 공식4도구 manifest 선언·선택 직원 스킬/overlay·links.json·지원 선언·영수증/프로필 링크 및 중단 흔적 부재를 확인한다. 그 다음 승인된 구성의 앱을 같은 설치 위치에 교체하고 다시 서명을 확인한다. 앱/코드를 먼저 실행해 상태를 추측하지 않는다. 원본 성공 조건에서 벗어나면 재개하지 않는다.

```sh
launchctl bootstrap "gui/$MAINTENANCE_UID" "$GATEWAY_PLIST"
# 새 gateway 시작 시각·기존 채널 재연결·새 오류 없음 확인 뒤만 다음 실행
launchctl bootstrap "gui/$MAINTENANCE_UID" "$MAIL_SIGNAL_PLIST"
```

새 프로세스의 시작이 배포 파일보다 뒤이고 승인된 기존 채널이 연결되는지, 공식 도구가 선택/권한에 맞게 실제 등록됐는지 최소 상태/오류 종류로 확인한다. 원문 로그/메일/토큰을 공개 문서에 남기지 않는다. 앱은 그 뒤 정상 실행하고 사용자 GD-T19로 진행한다. 이번에는 위 명령을 실행하지 않았다.

## 실패 복구 표

| 시점/실패 | 허용된 처리 | 중단 조건 |
|---|---|---|
| stage/압축/서명/지원 검사 실패 | 설치 전이므로 운영 파일을 바꾸지 않고 후보 재검토 | 지문·파일/모드·구성 불일치 |
| 최초 전환의 I/O 실패 | 같은 실행의 잠금·전환 부재·CAS 재검사 후 원래 코드 링크/영수증만 자동 복구. 기존 상태 복구 증거를 확인할 때만 이전 서비스 재개 여부를 판단 | upgrading-legacy/부분 표식·orphan 흔적·프로필/입력 drift·복구 실패이면 자료 보존/재실행 금지 |
| 최초 전환 성공, bundle 적용 실패 | 전체 이전 시설/조립 결과가 같은 실행에서 복구됐는지 확인. checker와 이전 team 조합을 유지한 중단 상태로 반환. legacy hejo 링크로 되돌리지 않음 | stage 남음/권한·선택 충돌/CAS 또는 복구 불확실이면 중지 유지 |
| 정상 지원 bundle에서 시설 복원 필요 | recovery의 같은 지원 버전 전체 hejo/bundle/app을 현재 checker로 검증한 뒤 아래 명령. 사용자 데이터/자격은 복구하지 않음 | 현재 시설 손상으로 policy/현재 묶음을 검증할 수 없으면 강제 복원 불가, 별도 판단 |
| 앱 교체/재개 후 실패 | 서비스/앱을 승인된 방법으로 멈추고 전체 지원 조합을 다시 확인. 승인된 구성의 앱 사본만 재설치 | 보안/로그인 대화는 사용자 결정; 외부 대화 자동 조작 금지. 기존12 Notion 불일치를 정상으로 간주하지 않음 |

정상 설치 정책이 승인하는 상태에서만 RECOVERY_HEJO/RECOVERY_BUNDLE을 같은 recovery 압축본으로 새 별도 경로에 해제한다. 설치된 checker·bundle이 손상됐거나 남은 stage가 있으면 이 명령으로 우회하지 않는다. 같은 지원 소스 복원도 별도 운영 승인이 필요하다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component hejo --target "$RECOVERY_HEJO"
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$RECOVERY_BUNDLE" --bundle
"$HEJO_PYTHON" -B "$RECOVERY_HEJO/install/hejo-install" --home "$AIRPORT_ROOT"
"$HEJO_PYTHON" -B "$TEAM_BUNDLE/bin/hermes-team-kit-deploy" rollback --root "$AIRPORT_ROOT" --bundle "$RECOVERY_BUNDLE"
```

복구 후보는 같은 지원 코드의 시설 복원 범위다. 지속적인 입력 경합/중단으로 정상 조합을 확인할 수 없으면 코드·영수증·금고를 손으로 고치지 않고 자료를 보존해 별도 판단을 받는다.

## 사용자 GD-T19 — 별도 승인 후 직접 수락

현재 미실행이다. 대상 직원 한 명의 개인 연결 해제 확인→목록/상세 이메일 제거와 연결 버튼→Google 계정 선택에서 다른 계정 동의→새 계정 표시와 승인된 읽기 전용 확인→다른 직원 연결/접근 범위 불변을 사용자가 확인한다. 취소/실패를 성공으로 표시하지 않는다. 항목별 성공/실패·시각·최소 오류 종류만 남기고 비밀/토큰·메일 본문·실제 이메일을 공개 증거로 요청하지 않는다. 실계정 뒤 TASK-07 현재 명세 승격/최종 판정은 기획 소유다. 푸시는 화면 승인 후 플러그인이 수행한다.

## 동반5파일의 원본·조립·복구 대응표

아래 상대 경로는 검토된 기존 책임 경계다. 현재 실제 소스는 위 왕복16 두 커밋이며 최초 작성 시점의 round13 소스를 배포 기준으로 사용하지 않는다.

| 저장소 원본 | 대상 상대 경로 | 조립·소유 경계 | 복구 단위 |
|---|---|---|---|
| hermes/bin/hermes-plugin-store | bin/hermes-plugin-store | 기존 plugin_store의 링크/overlay/links.json 검사·마이그레이션. 별도 정책 원본 없음 | 파일 존재/부재·본문·실행 모드 및 영향받는 links.json |
| hermes/bin/hermes-skill-assemble | bin/hermes-skill-assemble | owner/skill-assembly.yaml의 기존 직원 선택과 google_connection 투영. owner 원본·grant·사용 기록은 읽기 전용. 기존 soul 조립 코드 의존성은 새 배포 대상으로 만들지 않음 | 파일과 선택된 직원의 해당 스킬 결과 존재/부재·본문·모드 |
| hermes/bin/hermes-team-kit-deploy | bin/hermes-team-kit-deploy | 명시적 bundle 입력으로 키트+5파일을 같은 금고 mutex/gateway 중지 경계에서 stage/적용. 실행 코드·검사기는 시작 시 고정 | 파일 자신을 포함한 이전 전체 묶음; 실패한 stage는 명시적 복구 판단 전 보존 |
| hermes/plugin-store/team-delegation/plugin.yaml | plugin-store/team-delegation/plugin.yaml | 원본 provides_tools 선언과 사용자 overlay를 구분. config_assembly의 기존 manifest 합성에서 신규4선언만 반영하고 기존 도구 선택·grant·비관련 필드 보존. link는 원본 갱신, overlay는 합성/links.json 지문 함께 갱신 | 원본·영향받는 overlay·links.json; 사용자 권한 원본은 되돌리지 않음 |
| hermes/shared/secretary-skills/employee-google-workspace/SKILL.md | shared/secretary-skills/employee-google-workspace/SKILL.md | 기존 prepare의 선택 직원만 새 원문으로 조립. 이전 생성 원문과 다르게 사람이 편집한 결과는 거절. 선택 목록에 없는 직원에게 새 스킬을 설치하지 않음 | 원본과 선택된 조립 결과를 함께 복구; owner 선택/금고/토큰은 스냅샷 금지 |

키트 본문·동반5파일의 모드/본문 식별은 기존 google-connection-support.json의 bundle 선언에 포함한다. 새 소유자 설정 원본은 없다. 키트와 동반 파일이 요구되는 후보/현재 설치에서는 기존 kit-only apply/rollback을 거절하고 기존 비bundle 계약은 유지한다. 이전 묶음의 검증·stage가 완료되기 전 쓰지 않으며, 남은 중단 stage가 있으면 정상 재실행으로 위장하지 않는다. 새 manifest 필드나 사용자 편집이 원본 소유 선언과 충돌하면 쓰기 전에 거절한다.
