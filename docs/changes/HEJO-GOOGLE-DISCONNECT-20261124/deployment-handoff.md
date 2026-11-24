# Google 개인 연결 배포 후보 인계 — 왕복12

상태: **로컬 후보 고정·운영 미적용**. [설계7판](design.md), [왕복12 작업](tasks.md), [독립 검토](independent-review.md), [구현 보고](impl-report.md)를 따른다. Terra checkpoint-10 재검토에서 IR-1이 해소됐다. 사용자 GD-T19·운영 승인·TASK-07 명세 승격·푸시는 미완료다. 이 문서는 실행 승인이나 운영 적용 완료 기록이 아니다.

## 고정한 소스와 후보

| 저장소 | 실행 소스 후보 전체 커밋 | 브랜치 | 원격 이름 |
|---|---|---|---|
| hejo | `78b3634bd50110a0a989146405ee454476a14f62` | `role-workflow/google-disconnect-c20a9994` | `github` |
| 운영 저장소 | `33d6671993473c0eb7ecb4087e0fe4edebc63050` | `role-workflow/google-disconnect-c20a9994` | `origin` |

실행 소스는 checkpoint-10의 hejo29/team65 파일과 일치한다. hejo 소스 커밋에는 최신 canonical 작업 문서10개·UUID 판정/검토2개·수락 명세1개도 포함했다(전체42파일). 이 문서와 최종 구현 보고는 후속 문서 전용 커밋으로 추가한다. 후속 커밋의 실행 소스는 위 후보와 같으며 실제 전달 HEAD는 ignored 로컬 최종 기록과 호스트 제출 자료에서 확인한다. 자기 커밋 해시를 문서에 쓰기 위한 반복 amend는 하지 않는다. 운영 저장소 전체65파일의 경로/지문과 각 커밋의 실제 argv/cwd/결과는 `.build/google-disconnect-evidence/delivery-commit-{hejo,team}-source.{json,log}`에 있다.

후보 ID: `78b3634bd501-33d667199347-r4`. 운영에 쓰지 않는 새 로컬 디렉터리에 작성했다. `hejo/RELEASE`는 위 hejo 전체 커밋이다. 공개 문서에는 개인 실제 경로를 기록하지 않는다. ignored `.build/google-disconnect-evidence/delivery-artifacts-final.json`에 실제 위치·파일별 모드/링크/지문을 기록한다. 두 압축 파일은 최상위 `hejo/`, `team/`를 각각 포함한다. 내부 파일/링크/모드와 압축 내용을 대조해 불필요한 macOS 메타데이터 항목이 없음을 확인했다.

| 압축 산출물 | 바이트 | SHA-256 |
|---|---:|---|
| `hejo.tar.gz` | 100817 | `9fd1629ef07e548c61617f865f74ffc2296dda093ee1fc403165cebed0e8f757` |
| `team.tar.gz` | 2034997 | `cb6e1ef7cf7473c62545f23b2f7c016669a0c2e2a073cc5656adb4094cd5adb8` |

앱은 압축 배포 후보에서 제외했다. 동일 볼륨의 서명 검증된 로컬 `hejo.app/`만 보존한다.

트리 지문은 상대 경로별 종류·모드·파일 SHA/크기 또는 symlink 대상의 JSON을 키 정렬/공백 없는 직렬화 후 SHA-256한 값이다. hejo `8dfa68512627ee7b3bad7ea76c1820abfb076cf42c09ce51ba70ed51ce09a46e`, team `a07773722064459cb88b9978f83bdc469fbe083b709c4a376bb87da2142911ef`, app `7451970e0a903e25cb2266fc5479d077e9b95152168be8884ff9403a1987314c`. hejo release는 gate/hub/schemas/config/install/라이선스를 담고 앱을 포함하지 않는다. team은 커밋의 team-kit 전체와 아래 동반5파일만 담으며 owner/프로필/자격은 담지 않는다. 운영 저장소 전체를 공개 패키지로 만들지 않았다.

검사기 원본은 hejo의 `install/check_google_compat.py` 하나다. 후보 검사기 SHA-256은 `dc0b0cb9496261d64c9c2cbecbf4c20c970e442f8be438d8f2021e2aed2b18d4`이다. hejo `install/google-connection-support.json`과 team-kit `google-connection-support.json`은 각각 자신의 component, `versions:[1]`, `disconnect_mode:forget_account`를 선언한다. 두 패키지 build 검사는 통과했다. 운영 검사는 설치 링크/영수증으로 찾은 **현재 설치 검사기**를 사용하며 후보 검사기로 대체 탐색하지 않는다.

앱은 기존 검토 완료 빌드의 복사본이다. 원본/복사본 `codesign --verify --deep --strict`가 통과했고 실행 파일 SHA-256은 `a097e08950e2745e838724d929dba98e651bb2a675093d61f2b3e81b3b348a71`이다. 빌드 입력은 후보 커밋과 일치한다. `HEJO_SKIP_GOOGLE_SECRET=1`, `HEJO_SPARKLE_OFFLINE=1`인 로컬 검증 빌드이며 공유 Google 로그인 비밀을 포함하지 않는다. 실제 임시 볼륨에 압축을 풀면 기존 한글 리소스 `연결안내.html`의 파일명이 NFC에서 NFD로 바뀌어 CodeResources의 봉인 경로와 달라지고 codesign strict 검증이 종료1이다. 파일 본문/링크는 같아도 서명 수락을 통과하지 못하므로 압축 앱은 배포 후보에서 제외했다. 진단은 `delivery-package-signature-diagnostic.json`·`delivery-unicode-resource.json`, 실패 실행은 `delivery-package-final.log`에 보존했다. 파일명 변경/재서명/제품 재빌드는 하지 않았다. 운영용 앱 포장 방식과 Google 로그인/업데이트 구성·설치 대상은 별도로 확인해야 한다. 현재 앱을 생산 배포 준비 완료로 간주하지 않는다. 비밀을 열거나 후보에 추가하지 않았다.

## 운영 승인 전에 확정할 경계

**현재 운영 적용은 아래 사유로 중단 상태다.** 준비한 후보 자체와 로컬 커밋은 유효하지만, 첫 운영 명령을 실행하기 전에 기획/운영 담당이 다음 적용·복구 절차를 확정해야 한다.

- 기존 `hermes-team-kit-deploy`는 team-kit와 기존 루트/프로필 plugin overlay만 갱신한다. 후보의 `hermes/bin/hermes-plugin-store`, `hermes/bin/hermes-skill-assemble`, `hermes/bin/hermes-team-kit-deploy`, `hermes/plugin-store/team-delegation/plugin.yaml`, `hermes/shared/secretary-skills/employee-google-workspace/SKILL.md`는 그 배포 범위 밖이다. 공식 도구 등록/승인·스킬 조립에 필요한 이5파일의 기존 권한/선택을 보존하는 적용·검증·복구 단위가 미확정이다. 키트 배포 성공만으로 제품 전체 적용을 선언하지 않는다. 무검사 cp/rsync/git checkout이나 새 installer를 임의로 도입하지 않는다.
- 앱 배포는 한글 리소스의 NFC/NFD 변경에 따른 서명 실패 처분이 선행 조건이다. 로컬 bundle의 codesign 성공을 압축 해제 후 성공으로 대체하지 않는다. 기존 제품 파일명을 임의 변경하지 않고 기획/앱 배포 담당에게 포장/서명 방식 결정을 반환한다.
- 실제 루트/모든 직원 홈, hejo 현재 링크·영수증·검사기 상태, 설치 대상 앱과 서명/Google 로그인/업데이트 구성, 작업 중단/재개 명령을 승인 자료에 확정한다. 이 단계에서는 운영 홈이나 비밀을 조사/변경하지 않았다.
- 설치 영수증이 installed인데 현재 검사기가 없거나 링크/영수증이 불일치하면 기존 R10에 따라 거절한다. 새 패키지로 대체 탐색해 구버전 설치를 강제로 올리지 않는다. 최초 설치 또는 전환 전 failed/uninstalled의7판 복구 조건만 기존 installer가 판정한다. 실제 설치가 어느 경우인지는 미확인이다.
- 복구용 hejo/team-kit/동반5파일/앱의 호환되는 버전 묶음과 적용 절차를 먼저 확보한다. 과거 운영 버전을 호환 복구 대상으로 확인하지 않았다. 지원 선언 없는 옛 버전은 전환 기록이 있는 홈의 복구 대상으로 사용할 수 없다.

## 승인 뒤 적용 순서와 명령 템플릿

아래는 **미실행 템플릿**이다. 앞 절이 모두 확정되고 사용자에게 대상/중단 영향/복구 묶음을 제시해 별도 승인을 받은 뒤 실행한다. 승인 자료의 변수는 해당 후보와 실제 설치 대상을 가리키게 한다. `HEJO_PYTHON`은 필요한 Hermes 모듈을 가진 기존 인터프리터, `HEJO_RELEASE`는 새 공유 release 위치, `TEAM_ARTIFACT`는 `team/hermes` 위치, `AIRPORT_ROOT`는 승인한 루트 홈이다. 개인 실제 값은 ignored 로컬 인계에만 둔다.

1. 산출물 해시와 소스 커밋·실행 모드, 읽기 권한을 대조하고 패키지 build 검사부터 한다. 후보를 승인한 새 불변 공유 위치에 배치하는 절차도 운영 승인 범위에 포함한다. 기존 release 디렉터리를 덮어쓰지 않는다.

```sh
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component hejo --target "$HEJO_RELEASE" --validate-build
"$HEJO_PYTHON" -I -B "$HEJO_RELEASE/install/check_google_compat.py" --component team-kit --target "$TEAM_ARTIFACT/plugin-store/team-kit" --validate-build
```

2. 사용자가 승인한 방법으로 앱/게이트웨이와 영향받는 작업자를 중단한다. 예상 영향은 적용 동안 관련 직원 연결/업무 기능의 일시 중단이다. 중단 명령/재시작 대상은 미확정이므로 이 문서에서 추측하지 않는다. gateway가 살아 있으면 team-kit 배포는 거절한다.
3. 현재 installed/applied 영수증과 실제 `plugins/hejo` 링크가 일치하는지 확인한다. 현재 gate의 부모에 있는 일반 파일 검사기만 `CURRENT_CHECKER`로 선택한다. symlink 검사기·PATH/cwd/후보/구버전 대체 탐색은 금지한다. 승인된 모든 루트/직원 홈에 현재 정책으로 새 후보의 호환성을 검사한다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component hejo --target "$HEJO_RELEASE"
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$TEAM_ARTIFACT/plugin-store/team-kit"
```

최초/복구 설치는 임의 CURRENT_CHECKER로 이 과정을 흉내내지 않고 기존 installer의 엄격한 preflight를 사용한다. 현재 검사기가 누락된 installed 설치는 중단 조건이다.

4. 모든 전제 충족 뒤 hejo 링크/영수증을 먼저 갱신하고 키트를 적용한다. 아래 deploy 명령은 자기 패키지의 시설 코드를 불러오지만 호환 정책은 설치된 hejo에서 검증/캡처한다. 설치는 대상 홈마다 승인한 범위에서 실행하며 기존 installer의 프로필 갱신/실패 복구 경계를 따른다. `--force`로 설치 검사를 우회하지 않는다.

```sh
"$HEJO_PYTHON" "$HEJO_RELEASE/install/hejo-install" --home "$AIRPORT_ROOT"
"$HEJO_PYTHON" "$TEAM_ARTIFACT/bin/hermes-team-kit-deploy" apply --root "$AIRPORT_ROOT" --source "$TEAM_ARTIFACT/plugin-store/team-kit"
"$HEJO_PYTHON" "$HEJO_RELEASE/install/hejo-install" --home "$AIRPORT_ROOT" --check
```

5. **미확정인 동반5파일·앱 적용/복구 절차가 먼저 승인되어야4번에도 진입할 수 있다.** 그 절차와 기존 권한/선택에 따른 스킬·manifest 조립을 완료하고, 실제 등록된 공식 도구/직원별 접근 범위, overlay 신규/삭제 반영, 링크/영수증·지원 버전 일치를 확인한다. 새로운 grant를 자동 생성하거나 자격 사본을 만들지 않는다. 현재 선택 스킬 조립과 별개로 무조건 전체 스킬을 적용하지 않는다.
6. 승인된 재개/재시작 절차 후 앱을 열고 GD-T19를 사용자가 직접 수행한다. 이 로컬 후보 준비에서 재시작/설치/실계정 접속은 하지 않았다.

## 실패 시 복구와 닫힘

- 적용 전 검증된 **호환 복구 묶음**을 지정한다. 복구는 코드/링크/overlay/영수증의 일관성을 회복하며, owner 금고·직원 연결 원본·전용 자격을 과거 사본으로 되돌리지 않는다. 실패했다고 google_connections 기록을 삭제하거나 토큰을 복사하지 않는다.
- 기존 hejo installer는 시작 시 검증한 현재 검사기를 메모리에 캡처하고 잠금 안에서 영수증/홈 상태를 재검사한다. team deploy도 설치 검사기를 캡처하고 실패 복구의 이전 artifact를 같은 정책으로 검사한다. 실패를 임의 영수증 재작성/강제 링크 교체로 우회하지 않는다. 정상 예외는 기존 구현의 복구 절차에 맡긴다.
- 명시적 복구가 필요하면 사용자 승인한 중단 상태를 유지한다. 현재 유효한 설치 검사기로 **복구 대상 hejo와 team-kit 모두**를 먼저 확인한다. 이후 호환 hejo 설치와 team rollback의 승인된 순서를 따른다. 이 템플릿은 실제 현재 설치/검사기가 유효할 때만 사용한다.

```sh
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component hejo --target "$RECOVERY_HEJO"
"$HEJO_PYTHON" -I -B "$CURRENT_CHECKER" --home "$AIRPORT_ROOT" --component team-kit --target "$RECOVERY_TEAM/plugin-store/team-kit"
"$HEJO_PYTHON" "$RECOVERY_HEJO/install/hejo-install" --home "$AIRPORT_ROOT"
"$HEJO_PYTHON" "$TEAM_ARTIFACT/bin/hermes-team-kit-deploy" rollback --root "$AIRPORT_ROOT" --source "$RECOVERY_TEAM/plugin-store/team-kit"
"$HEJO_PYTHON" "$RECOVERY_HEJO/install/hejo-install" --home "$AIRPORT_ROOT" --check
```

- 동반5파일/앱도 같은 승인된 복구 묶음으로 되돌릴 수 있어야 한다. 프로필 사용자 plugin manifest/선택/파일 권한을 보존한다. 이 부분의 정확한 명령은 미확정이며 임의 복사 명령으로 메우지 않는다.
- 강제 종료 후 링크/영수증이 불일치하거나 현재 검사기를 검증할 수 없으면 자동 복구 성공이 아니다. 전환 전 failed/uninstalled 예외는 전환 기록/잔존 자격 없음과 실행 코드 링크의 실제 복구까지 installer가 확인할 때만 허용한다. 조건 미충족·복구 대상 미확보·정책/버전 거절·YAML 불명확/중복·동시 전환/잠금·살아 있는 gateway·대상 변경이면 멈추고 기획/운영 담당에게 증거를 반환한다. 다른 버전 fallback이나 재시작으로 넘기지 않는다.

## 사용자 GD-T19 — 별도 승인 후 직접 수락

현재 전 항목 **미실행**이다. 운영 적용과 사용자의 Google 동의가 각각 승인된 뒤 실제 계정 한 명만 대상으로 한다.

- 대상 직원의 Google 개인 연결을 해제한다. 삭제 확인 문구와 해제 뒤 목록/상세 이메일 제거·연결 버튼 표시를 확인한다.
- 다시 연결해 Google 계정 선택이 나타나는지 보고 다른 Google 계정을 직접 선택/동의한다.
- 앱 목록/상세에 새 계정이 표시되고 승인한 읽기 전용 기능이 동작하는지 확인한다. 메일 발송/수정 작업으로 대신하지 않는다.
- 다른 직원의 연결/계정 표시와 접근 범위가 변하지 않았는지 확인한다. 취소/실패를 확인한 경우 완료로 표시하지 않는다.
- 결과는 항목별 성공/실패와 시각·필요한 최소 오류 종류만 기록한다. 비밀/토큰·메일 본문·실제 이메일 문자열을 공개 보고에 요구하지 않는다.

GD-T19 뒤 호스트가 최종 판정과 TASK-07 현재 명세 승격을 처리한다. 푸시는 사용자 `/push` 또는 푸시 대상 확인 화면의 별도 승인을 통해 플러그인이 실행한다. 로컬 커밋은 최종 완료나 푸시 완료가 아니다.
