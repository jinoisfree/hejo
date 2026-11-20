# HEJO-IMESSAGE TASK-07 적용 기록

## 현재 상태

공용 릴리스 갱신과 설치 상태 점검은 통과했다. 현재 RELEASE는 `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`이다. 게이트웨이는 아직 재시작하지 않아 실행 중 코드는 이전 상태다. 사용자는 기본 빌드의 입력 읽기를 허용했지만, 그 사이 보완 지시 4가 앱을 별도 공개 절차로 분리했다. 이 범위 차이를 확인하는 질문을 제출했으며 앱 빌드·교체·재시작 전에 답변을 기다린다.

## 적용 전 기록

- 기록 시각(UTC): `2026-11-20T03:53:07.898861+00:00`.
- 대상 hejo 커밋: `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`(보완 지시 4). 재개 시 작업 트리 깨끗, `git diff --stat abf68d9 HEAD -- gate app schemas install scripts`와 `git diff --stat 2560073 HEAD -- hub install config` 모두 출력 0건. 기존 보존본의 권한과 직전 RELEASE 불변을 다시 확인했다.
- 직전 공용 RELEASE: `25600732ef822ffea155cd26d31b7f23114ff29f`. 해당 커밋 객체 존재 확인.
- 운영 저장소 HEAD: `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`. team-kit 롤백용 직전 커밋: `4f79decae030eb63f3f0f52e8c8517226748b876`.
- 운영 shared/hejo 보존 사본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/shared-hejo`. 사본 루트·하위 디렉터리 0700, 일반 파일 0600. 원본을 변경하지 않았다.
- 설치 앱 사본: 시스템 Applications/hejo.app, 버전 0.2.0, 빌드 2. 보존본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/apps/system-hejo.app`.
- 공용 릴리스 hejo.app: 버전 0.1.0, 빌드 1. 보존본(홈 기준 상대): `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58/apps/release-hejo.app`.
- 로컬 실행 경로 변수는 `.build/HEJO-IMESSAGE/task07/paths.sh`에 실제 값으로 채웠다(0600, 추적 제외). 아래 명령은 저장소 작업 폴더에서 실행하며 빈 경로·빈 커밋 값이 없다. 공개 증거에는 개인값·절대 경로를 쓰지 않는다.

## 적용 전 확정한 롤백 명령

앱 0.2.1 공개 전에는 짝짓기 화면이 없으며 연결을 만들지 않는다. 이후 급할 때는 앱 설정에서 아이메시지 연결을 끄거나 연결 해제한다. 메시지·코드를 보내는 확인은 하지 않는다.

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

앱 롤백: 해당 없음(앱 미교체). 기존 보존 사본은 그대로 둔다.

롤백 후에는 RELEASE가 `25600732ef822ffea155cd26d31b7f23114ff29f`인지, 재시작 뒤 hejo·photon·Slack 연결 및 새 오류·역추적 0건인지 확인한다. 새 imessage 파일은 남겨도 된다. 기록장 형식은 같으므로 운영 기록을 자동으로 과거 사본으로 되돌리지 않는다.

## 절차별 실행 기록

| 절차 | 결과 | 근거 |
|---|---|---|
| 착수 조건 | 통과, 읽기 명령 종료 0 | `.build/HEJO-IMESSAGE/task07/before.json` |
| shared/hejo 및 앱 두 사본 보존 | ditto 3회 종료 0, 개인 사본 디렉터리 0700 | 같은 파일과 보존 사본 |
| 보존 앱 서명 검사 | codesign --verify --deep --strict 각 종료 0 | `.build/HEJO-IMESSAGE/task07/backup-system-signature.log`, `backup-release-signature.log` |
| `install/hejo-release` | 종료 0, UTC 2026-11-20 04:26:48 완료 | `.build/HEJO-IMESSAGE/task07/release.log/.exit`, `release.json` |
| RELEASE·배포 gate 대조 | 종료 0, RELEASE 대상 일치·시험 제외 gate 19개 파일 및 파일 집합 동일 | `release.json` |
| Hermes venv Python `<release>/install/hejo-install --check` | 종료 0, 출력 없음. 설치 실행 안 함 | `install-check.log/.exit`, `install-check.json` |
| 앱 빌드·교체 | 미실행 | 보완 지시 4와 사용자 빌드 답변의 범위 차이 확인 대기 |
| 처리 중 차례 확인 | 읽기 종료 0, gateway_state running·active_agents 0·PID 생존 | 재개 때 및 UTC 04:26:57 갱신 상태 확인. 재시작 직전에 다시 확인 필요 |
| 게이트웨이 재시작 | 미실행 | 앱 범위 답변 대기 |
| 재시작 뒤 연결·오류 확인 | 미실행 | 재시작 미실행 |
| 앱 화면 캡처 | 미실행 | 보완 지시 4에서 제외·앱 공개 뒤 수행 |
| 롤백 실행 | 미실행 | 릴리스 갱신·설치 상태 점검 실패 없음. 앱 미교체·게이트웨이 재시작 전 |

## 재개 지점

범위 답변을 확인한다. 서버만 적용이면 보완 지시 4의 3번부터: 최신 `active_agents` 0 확인 → 게이트웨이 재시작 → 새 시작 시각이 위 릴리스 갱신 뒤인지, hejo·photon·Slack 연결 및 새 오류·역추적 0건인지 확인한다. 허브는 재시작하지 않는다. 릴리스 갱신·설치 점검은 이미 끝났으므로 반복하지 않는다. 앱까지 지시하면 현재 배포 계약과의 차이를 먼저 계획 담당에게 전달한다.
