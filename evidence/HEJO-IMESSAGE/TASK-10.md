# TASK-10: 폰의 작성 중 표시 서버 적용

## 적용 전 기록

- 허가: handoff 보완 지시 7, verdict 8차 TASK-09 통과. 고위험(운영), 필요 증거 수준 3. 실물 M9는 사장이 확인한다.
- 적용 대상: `95074cbafda3a5e16d1fd2e9a580b24abe667021`(제품 코드 `05107d59a23c27a4dea946c566b00d7e3df81696`). 착수 작업 트리 깨끗.
- 직전 공용 RELEASE·롤백 대상: `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`.
- `git diff --stat ea31736 HEAD -- gate schemas hub install config`: `gate/adapter.py`·`gate/imessage.py` 두 파일만. `git diff --stat 05107d5 HEAD -- gate app schemas install scripts hub config`: 변경 0건. 각 읽기 명령 종료 0.
- 경로 변수는 추적 제외 `.build/HEJO-IMESSAGE/task10/paths.sh`에 기록했다(권한 0600). 착수 상태와 짝·설정 파일의 존재 여부·수정 시각은 `before.json`에 기록했다. 두 파일의 내용은 열지 않았다.
- 앱·허브·team-kit·설정은 적용 대상이 아니다. 데이터 복원은 없다.

## 실패 시 코드 롤백

아래 명령은 적용 전에 작성했다. `HEJO_REPO`는 작업 저장소, `RELEASE_DIR`은 공용 릴리스, `ROLLBACK_WORKTREE`는 이 작업의 추적 제외 임시 worktree를 가리킨다. 경로 변수에는 실행할 실제 경로를 채워 두었다.

```bash
source .build/HEJO-IMESSAGE/task10/paths.sh
git -C "$HEJO_REPO" worktree add --detach "$ROLLBACK_WORKTREE" ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae
(cd "$ROLLBACK_WORKTREE" && install/hejo-release)
hermes --profile default gateway restart
```

롤백 뒤 RELEASE가 위 커밋인지, 시험·캐시를 제외한 공용 gate가 롤백 worktree와 같은지 확인한다. 새 게이트웨이 시작 뒤 hejo(기본·보조)·photon·Slack 연결과 새 오류·역추적 0건을 확인한다. 앱 롤백은 해당 없음(미교체). 짝·설정·기록장·team-kit에는 조치하지 않는다.

공용 릴리스 점검이 실패하면 설치·재시작하지 않고 보고한다. 처리 중 차례가 있으면 2분 간격으로 다시 확인하며 10분을 넘기면 재시작하지 않고 릴리스 갱신 사실과 함께 보고한다. 재시작 후 검증 실패는 위 코드 롤백 및 연결·오류 확인 뒤 보고한다.

## 실행 결과

| 절차·명령 | 종료 코드·결과 | 로컬 근거(`.build/HEJO-IMESSAGE/task10/` 기준) |
|---|---|---|
| 착수 HEAD·작업 트리·두 diff 확인 | 0, 위 조건 충족 | `before.json` |
| `install/hejo-release` | 0, UTC 2026-11-20 06:05:37.303 완료 | `release.log/.exit`, `release.json` |
| RELEASE·공용 gate 대조 | 0, 대상 RELEASE 일치·시험/캐시 제외 gate 19개 파일 및 파일 집합 동일 | `release.json` |
| Hermes venv Python `<release>/install/hejo-install --check` | 0, 출력 없음. 설치 실행 없음 | `install-check.log/.exit`, `install-check.json` |
| 재시작 직전 상태 확인 | 0, active_agents 0·runtime running·PID 생존·상태 갱신 약 9초 전 | `restart-before.json` |
| `hermes --profile default gateway restart` | 0, UTC 06:05:58.463 요청·06:06:00.792 명령 종료 | `restart-command.log/.exit`, `restart-command.json` |
| Hermes venv `verify-restart.py` | 0, 새 시작·기본/보조 연결·처리기 연결·오류·수정 시각 모두 통과 | `post-restart.json`, `connections.log`, `verify-restart.exit` |
| 코드 롤백 | 미실행(검증 실패 없음) | 아래 관측 결과 |

## 재시작 뒤 관측

- 새 시작: UTC `2026-11-20 06:06:16.152`(한국 시각 15:06:16.152). 릴리스 갱신 완료 UTC 06:05:37.303보다 뒤다. 이전 PID와 다른 프로세스가 살아 있고 runtime running, hejo/photon/Slack 상태가 모두 connected다.
- 최종 관측: UTC `2026-11-20 06:08:25.386`, 새 시작 뒤 약 129초. hejo 기본 1·보조 5, Slack 기본 1·보조 5, photon 1 연결을 확인했다. 로그에서 프로필 식별자를 제거한 연결 줄은 `connections.log`에 있다.
- 재시작 직전 로그 inode·오프셋부터 관측했다. `gateway.log` 추가 9756바이트, `gateway.error.log` 추가 0바이트. 새 ERROR/CRITICAL 0, 역추적 0, WARNING 0, 아이메시지 실패 0, 처리기 연결 실패 0. 이전 구간과 새 구간을 분리했으며 이전 로그를 새 오류로 세지 않았다.
- 아이메시지 처리기가 photon 문에 연결된 로그 1건(한국 시각):

```text
2026-11-20 15:06:19,006 [Photon] Wired native handlers from plugin 'hejo'
```

- 짝·설정 파일은 각각 존재하며 재시작 직전과 관측 종료의 수정 시각이 동일하다. 파일 내용은 열지 않았다. 착수 때의 수정 시각과도 같다. RELEASE도 적용 대상 그대로다.
- 서버 적용 자체 검증은 증거 수준 3에 도달했다. 실제 폰의 기본 작성 중 표시는 보내거나 시험하지 않았으며 사장 M9와 계획 담당 검토가 남는다. 롤백은 준비만 했고 실행하지 않았다.
- 앱·허브·설치 적용·짝짓기·코드 발급·설정 변경·실제 아이메시지/Slack 발송·push는 실행하지 않았다. 제품 코드·명세·Hermes 본체·photon·team-kit은 수정하지 않았다.

## 인계

계획 담당은 이 기록과 로컬 관측 증거·RELEASE를 검토한다. 적용과 재시작을 반복하지 않는다. 그 뒤 사장 M9, 설계에 참여하지 않은 검토 주체 결정, ARCHITECTURE 반영을 진행한다. 공개 브랜치는 이번 적용에서 변경하지 않았다.
