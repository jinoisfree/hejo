# HEJO-IMESSAGE TASK-07 적용 기록

## 현재 상태

적용 전 기록과 롤백 준비 완료. 기본 앱 빌드의 비밀 입력 읽기 허용 범위를 확인 중이다. 릴리스 갱신·앱 교체·재시작은 아직 실행하지 않았다.

## 적용 전 기록

- 기록 시각(UTC): `2026-11-20T03:53:07.898861+00:00`.
- 대상 hejo 커밋: `d0d1a58451c73a18c2af3dd545b76e34660e4666`. 착수 시 작업 트리 깨끗, `git diff --stat abf68d9 HEAD -- gate app schemas install scripts` 출력 0건.
- 직전 공용 RELEASE: `25600732ef822ffea155cd26d31b7f23114ff29f`. 해당 커밋 객체 존재 확인.
- 운영 저장소 HEAD: `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`. team-kit 롤백용 직전 커밋: `4f79decae030eb63f3f0f52e8c8517226748b876`.
- 운영 shared/hejo 보존 사본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/shared-hejo`. 사본 루트·하위 디렉터리 0700, 일반 파일 0600. 원본을 변경하지 않았다.
- 설치 앱 사본: 시스템 Applications/hejo.app, 버전 0.2.0, 빌드 2. 보존본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/apps/system-hejo.app`.
- 공용 릴리스 hejo.app: 버전 0.1.0, 빌드 1. 보존본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/apps/release-hejo.app`.
- 로컬 실행 경로 변수는 `.build/HEJO-IMESSAGE/task07/paths.sh`에 실제 값으로 채웠다(0600, 추적 제외). 아래 명령은 저장소 작업 폴더에서 실행하며 빈 경로·빈 커밋 값이 없다. 공개 증거에는 개인값·절대 경로를 쓰지 않는다.

## 적용 전 확정한 롤백 명령

급할 때: 새 앱 설정에서 아이메시지 연결을 끄거나 연결 해제한다. 메시지·코드를 보내는 확인은 하지 않는다.

코드 롤백:

```bash
source .build/HEJO-IMESSAGE/task07/paths.sh
git -C "$HEJO_REPO" worktree add --detach "$ROLLBACK_WORKTREE" 25600732ef822ffea155cd26d31b7f23114ff29f
(cd "$ROLLBACK_WORKTREE" && install/hejo-release)
git -C "$OPS_REPO" show 4f79decae030eb63f3f0f52e8c8517226748b876:hermes/plugin-store/team-kit/lib/hermes_packs/notion/api.py > "$TEAM_ROOT/lib/hermes_packs/notion/api.py"
git -C "$OPS_REPO" show 4f79decae030eb63f3f0f52e8c8517226748b876:hermes/plugin-store/team-kit/lib/hermes_router/ingress.py > "$TEAM_ROOT/lib/hermes_router/ingress.py"
rm -f "$TEAM_ROOT/tests/test_router_hejo_imessage.py"
(cd "$OPS_REPO" && ./sync)
hermes --profile default gateway restart
```

앱 롤백(위 경로 변수를 불러온 같은 셸):

```bash
osascript -e 'tell application id "io.github.hermes-hejo.hejo" to quit'
rm -rf "$SYSTEM_APP"
ditto "$BACKUP/apps/system-hejo.app" "$SYSTEM_APP"
rm -rf "$SHARED_APP"
ditto "$BACKUP/apps/release-hejo.app" "$SHARED_APP"
open "$SYSTEM_APP"
```

롤백 후에는 RELEASE가 `25600732ef822ffea155cd26d31b7f23114ff29f`인지, 앱 버전·빌드가 위 적용 전 값인지, 재시작 뒤 hejo·photon·Slack 연결 및 새 오류·역추적 0건인지 확인한다. 새 imessage 파일은 남겨도 된다. 기록장 형식은 같으므로 운영 기록을 자동으로 과거 사본으로 되돌리지 않는다.

## 절차별 실행 기록

| 절차 | 결과 | 근거 |
|---|---|---|
| 착수 조건 | 통과, 읽기 명령 종료 0 | `.build/HEJO-IMESSAGE/task07/before.json` |
| shared/hejo 및 앱 두 사본 보존 | ditto 3회 종료 0, 개인 사본 디렉터리 0700 | 같은 파일과 보존 사본 |
| 보존 앱 서명 검사 | codesign --verify --deep --strict 각 종료 0 | `.build/HEJO-IMESSAGE/task07/backup-system-signature.log`, `backup-release-signature.log` |
| install/hejo-release | 미실행 | 빌드 입력 계약 확인 대기 |
| 앱 빌드·교체 | 미실행 | 기본 빌드는 config/google-oauth-secret.json을 읽음. 비밀 주입 생략은 기존 공유 앱의 Google 입력 유무를 바꿈 |
| 직원 차례 없음 확인·재시작 | 미실행 | 적용 단계 미진입 |
| 재시작 뒤 연결·오류·앱 화면 캡처 | 미실행 | 적용 단계 미진입 |
| 롤백 실행 | 미실행·불필요 | 운영 릴리스·앱·게이트웨이 변경 없음 |
