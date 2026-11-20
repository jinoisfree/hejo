# HEJO-IMESSAGE TASK-07 적용 기록

## 현재 상태

서버 적용·자체 검증 완료(검토 대기). 사용자 결정은 보완 지시 4대로 서버만 적용이다. 공용 RELEASE는 `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`이며 게이트웨이를 재시작해 새 코드를 반영했다. 앱 빌드·교체·화면 캡처는 이번 범위에서 제외했다. 앱 0.2.1 공개·독립 검토·폰 실물 수락은 남아 있다.

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
| 앱 빌드·교체 | 미실행·이번 범위 제외 | 사용자 결정: 보완 지시 4대로 서버만 적용 |
| 재시작 직전 처리 중 차례 확인 | 종료 0, active_agents 0·PID 생존·상태 갱신 120초 미만 | `restart-before.json`, UTC 04:32:05 확인 |
| `hermes --profile default gateway restart` | 종료 0, UTC 04:32:05 요청·04:32:08 명령 종료 | `restart-command.log/.exit`, `restart-command.json` |
| 재시작 뒤 연결·오류 확인 | 종료 0, 새 시작 UTC 04:32:23(릴리스 갱신 뒤). hejo 6·Slack 6·photon 1 연결 | `post-restart.json`, `connections.log`, `verify-restart.exit` |
| 앱 화면 캡처 | 미실행 | 보완 지시 4에서 제외·앱 공개 뒤 수행 |
| 롤백 실행 | 미실행·불필요 | 서버 적용·재시작·연결 검증 실패 없음 |

## 재시작 뒤 관측

- 사용자 결정: 보완 지시 4대로 서버만 적용. 빌드 입력 읽기 허용은 이번 서버 적용에서 사용하지 않았다.
- 새 게이트웨이 시작: UTC `2026-11-20 04:32:23.433`(한국 시각 13:32:23.433). 릴리스 갱신 완료 UTC 04:26:48.586보다 뒤다. PID 교체·프로세스 생존·runtime running 및 hejo/photon/Slack connected 확인.
- 최종 관측: UTC `2026-11-20 04:34:49.197`, 새 시작 뒤 약 146초. `gateway.log`는 재시작 직전 오프셋부터 9756바이트를 확인했고 `gateway.error.log`는 같은 구간 추가 0바이트다. 새 ERROR/CRITICAL 0, 역추적 0, WARNING 0, 아이메시지 실패 0, 플러그인 처리기 연결 실패 0. 이전 구간과 새 구간을 오프셋으로 분리해 이전 로그를 새 오류로 세지 않았다.
- 연결 로그(프로필 식별자와 본문 제거, 한국 시각):

```text
2026-11-20 13:32:26,135 hejo connected
2026-11-20 13:32:26,137 slack connected
2026-11-20 13:32:26,138 photon connected
2026-11-20 13:32:26,325 hejo connected
2026-11-20 13:32:26,628 slack connected
2026-11-20 13:32:26,841 hejo connected
2026-11-20 13:32:27,149 slack connected
2026-11-20 13:32:27,353 hejo connected
2026-11-20 13:32:27,659 slack connected
2026-11-20 13:32:27,910 hejo connected
2026-11-20 13:32:28,221 slack connected
2026-11-20 13:32:28,453 hejo connected
2026-11-20 13:32:28,744 slack connected
```

- 운영 저장소 HEAD는 `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495` 그대로이며 team-kit 세 경로가 실행 원본·운영 저장소 작업본·커밋과 같다(`source-final.json`). hejo 제품 코드·허브·설치 도우미·설정 예제는 착수 기준과 같다.
- AT-HI-40 서버 부분은 증거 수준 3으로 자체 검증했다. 앱 상태 화면은 0.2.1 공개 후 TASK-08에서 확인하며, 실제 폰 동작·발신은 검증하지 않았다. AT-HI-41은 적용 전 롤백 명령을 준비했으나 실패가 없어 실제 롤백하지 않았다.
- 허브 재시작·설치 적용·앱 교체·짝짓기·코드 발급·실제 아이메시지/Slack 발송·push는 실행하지 않았다. 운영 설정·비밀 파일 내용을 직접 열지 않았다.

## 다음 단계

계획 담당이 이 기록·로컬 연결/오류 증거·RELEASE와 새 게이트웨이 상태를 검토한다. 서버 적용을 반복하지 않는다. 이어 앱 0.2.1 공개 준비 범위를 사용자와 정하고, 설계에 참여하지 않은 검토 및 TASK-08 폰 M1~M8을 진행한다.
