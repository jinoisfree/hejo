# TASK-07 서버 적용 — 적용 전 보류

## 허가·대상·적용 전 기록

- 받은 인계: [handoff-task07.md](../../docs/changes/HEJO-TELEGRAM-20261122/handoff-task07.md), 사장 서버 적용 허가. 위험도 고위험, 필요 증거 수준 3, 수락 시험 AT-HT-60·61.
- 착수/적용 대상: `223a191accbb70c28f7b35cfdf2eee9490dfb109`. 제품 코드 기준 `1ef3ad27fbe0e960fb542ea14bd0a3ef7d62262e`, 판정 2차 통과를 직접 읽었다.
- 현재 공용 RELEASE·롤백 대상: `227ef160694635f8afde36f06515f5136f73dc30`.
- 관측 시각: `2026-11-22T15:37:25.667349+00:00`. 작업 트리는 다른 작업의 미추적 `docs/changes/HEJO-AUDIT-20261122/`만 있으며 추적 파일 변경 없음.
- `git diff --stat <현재 RELEASE> HEAD -- gate schemas hub install config`: 종료 0, 8파일 변경. 커밋 목록은 이 작업의 `53acb8e`·`338c35a`·`c9a653a`·`9fd6512`·`1ef3ad2`뿐이다. gate 6개 파일 교체·수정, 정착 시험 이름 이전, 규격 변경이며 hub/install/config 차이 0. 미검증 다른 작업 변경은 발견하지 않았다.
- 게이트웨이: `running`, 기존 PID 생존, 착수 시 active_agents `1`. 재시작 직전 검사는 아직 수행하지 않았다.
- 금고·공용 창고는 아래 존재·수정 시각만 확인했고 내용은 열지 않았다.

| 홈 기준 위치 | 존재 | mtime ns |
|---|---|---|
| `hejo/imessage.json` | 있음 | 1795152269339528958 |
| `shared/hejo/imessage/settings.json` | 있음 | 1795328089396864480 |
| `shared/hejo/imessage/sent.jsonl` | 있음 | 1795341916322951179 |
| `hejo/telegram.json` | 없음 | — |
| `shared/hejo/telegram/settings.json` | 없음 | — |
| `shared/hejo/telegram/topics.json` | 없음 | — |
| `shared/hejo/telegram/sent.jsonl` | 없음 | — |
| `shared/hejo/journal` | 있음 | 1794677212047049301 |

실제 경로 변수는 추적 제외 `.build/HEJO-TELEGRAM/task07/paths.sh`(0600)에 채웠다. `HEJO_REPO`는 작업 저장소, `RELEASE_DIR`은 현재 공용 릴리스, `ROLLBACK_WORKTREE`는 이 작업의 임시 롤백 worktree, `HERMES_PYTHON`은 Hermes venv다. 개인 절대 경로는 추적 문서에 넣지 않는다.

## 적용 전 작성한 롤백 명령

```bash
source .build/HEJO-TELEGRAM/task07/paths.sh
git -C "$HEJO_REPO" worktree add --detach "$ROLLBACK_WORKTREE" 227ef160694635f8afde36f06515f5136f73dc30
(cd "$ROLLBACK_WORKTREE" && install/hejo-release "$RELEASE_DIR")
hermes --profile default gateway restart
```

이는 준비만 했고 실행하지 않았다. 롤백 시 RELEASE·공용 gate를 위 worktree와 대조하고 새 프로세스의 hejo(기본·보조)·photon·Slack 연결 및 새 오류·역추적 0건을 확인한다. 옛 아이메시지 짝·설정과 새 텔레그램 저장 파일에는 조치하지 않는다. 텔레그램 의존성 부재만으로는 인계 9(2)에 따라 롤백하지 않는다.

## HT-B03: 지정 확인 명령과 금지 범위 충돌

[확인] 인계 9(4)는 운영 홈의 `hejo-install --check`를 명시하지만 같은 인계 3·9절은 운영 설정·비밀 파일을 열지도 쓰지도 말라고 한다.

- `install/hejo-install:678`의 `run(check=True)`는 각 프로필 `config.yaml`을 `read_config`로 연다(695행). `read_config`는 `os.open` 후 전체 내용을 읽는다(112~119행). 그 밖에 소유 대상 비교에서도 설정 내용을 읽는다.
- 같은 분기는 `install/admin_support.py:62`의 `check(home, receipt)`도 부른다. 영수증 상태가 적용 중/적용 완료라면 `hejo/admin.json`을 `read_bytes()`로 읽어 지문을 비교한다. 이 파일은 같은 모듈의 `prepare()`가 포트와 인증 토큰을 넣는 파일이다. 읽은 값이 출력되지 않더라도 파일 열기 자체는 일어난다.
- 허가된 명령의 통상 내부 읽기를 금지의 예외로 볼지 인계에 명시돼 있지 않다. 고위험 운영에서 구현자가 임의로 예외를 만들지 않고 적용 전에 보류했다. 이 내용을 알아보기 위해 운영 설정·영수증·admin.json을 열지는 않았다(설치 도우미 소스만 읽음).
- 권고: 계획 담당이 `--check`에 한정된 정상 내부 읽기를 허용하는지 명시하거나, 운영 설정/비밀 파일을 열지 않는 대체 확인 절차를 확정한다. 그때까지 설치·재시작은 실행하지 않는다.

## 실행·미실행 증거

로그 기준 폴더는 추적 제외 `.build/HEJO-TELEGRAM/task07/`다.

| 검사 | 실제 결과 | 로그 |
|---|---|---|
| `python3 preflight.py`(로컬 기록 보조) | 종료 0, 현재 RELEASE·HEAD·작업 트리·상태·파일 metadata 기록 | `before.json`, `paths.sh` |
| 두 Git diff/log 명령 | 각각 종료 0, 위 적용 범위 확인 | `release-diff-stat.log/.exit`, `release-diff-commits.log/.exit` |
| Hermes venv Python의 telegram spec/import/패키지 판 확인 | 검사 명령 종료 0, 모듈 없음·판 없음·import 불가. 직접 설치 미실행 | `dependency-before.json` |
| `install/hejo-release` | 미실행(HT-B03 보류) | — |
| `hejo-install --check` | 미실행(HT-B03 보류) | — |
| 재시작 직전 active_agents 확인·대기 및 gateway restart | 미실행 | — |
| 재시작 뒤 자동 설치·연결·로그·telegram_status | 미실행 | — |
| 롤백 | 미실행(운영 변경 없음) | — |
| 임시 HERMES_HOME 개인값 검사 | 종료 1, 다른 작업 문서 4건·이번 파일 0건 | `private.log/.exit` |
| `git diff --check` | 종료 0 | 도구 결과 |

도달 증거는 적용 전 읽기 조사뿐이다. AT-HT-60의 사전 기록·롤백 준비는 수행했고 AT-HT-61·서버 적용 수준 3은 미도달이다. 운영 설정·비밀 파일·본체·플러그인·team-kit·앱 사본·앱 공개·실제 발송·푸시는 변경/실행하지 않았다. 다음 담당은 HT-B03의 허가 범위를 정리한 뒤 같은 적용 대상에서 이어간다. 재개할 때는 최신 RELEASE·HEAD·active_agents를 다시 확인한다.
