# TASK-07 서버 적용 기록

현재 상태(보완 2): 공용 릴리스 설치·대조·설치 검사는 통과했다. active_agents가 10분을 넘겨 계속 1이어서 게이트웨이 재시작 없이 중단했다. 아래 첫 시도 기록은 당시 상태이며, 최신 상태는 마지막 절을 따른다.

## 첫 시도 — 적용 전 보류(이력)

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

## 보완 2 — 적용 재개 전 기록

- 인계 2판 `246caecda2e676a24df153355dfc4d7737a48c11`과 verdict 3차를 읽었다. HT-B03은 인계 문구 오류로 해소됐다. 지정 운영 도구의 내부 읽기는 허용하며, 에이전트의 직접 설정·비밀 파일 열람은 계속 금지한다.
- 재개 착수 HEAD·실제 설치 대상은 `0bcf63535df381e491c99af9cbef41179b7cd79f`다(인계 커밋 이후 다른 작업 커밋 포함). 적용 직전 RELEASE는 계속 `227ef160694635f8afde36f06515f5136f73dc30`이며, 설치 범위는 검증된 텔레그램 변경뿐이다. 제품 기준 `1ef3ad2`와 실제 대상의 gate/schemas/hub/install/config 차이 0건을 확인했다. 다른 작업의 앱·문서 변경은 설치 범위에 들어가지 않으며 보존했다.
- 실제 경로 변수의 `APPLY_COMMIT`을 최신 값으로 갱신했다. 기존 롤백 명령과 롤백 RELEASE는 그대로 유효하다. 적용 전에 이 절을 작성했으며, 새 사전 기록은 `resume-before.json`, `resume-diff-stat.log`, `resume-diff-commits.log`다(앞선 시도 기록 보존).
- 도구 출력은 메모리에서 민감값 형태를 검사한 뒤 상태·경로만 기록한다. 토큰·id·주소 값 형태가 있으면 해당 값을 증거에 쓰지 않고 중단한다.

## 보완 2 — 설치 후 활성 작업 대기 한도 초과

- `2026-11-22T15:42:37.810365+00:00`에 설치를 시작해 같은 초에 종료 0으로 끝났다. 실제 RELEASE는 `0bcf63535df381e491c99af9cbef41179b7cd79f`다. 설치 대상 다섯 디렉터리의 공용 파일 41개가 대상 Git 객체와 모두 일치했다(누락·추가·불일치 0, 시험·캐시는 설치기 제외 기준 적용).
- 첫 `hejo-install --check`는 `install_error ModuleNotFoundError`, 종료 1이었다. 원시 venv에서 `hermes_constants` 검색 경로가 없음을 확인했다. 패키지나 본체를 바꾸지 않고 해당 호출의 `PYTHONPATH`에 Hermes 본체 위치를 지정한 같은 venv 재실행은 종료 0, 출력 없음이었다. 이 환경 보완은 셸 호출에만 적용했다.
- 활성 작업 관측은 아래와 같다. 첫 관측부터 마지막 관측까지 **634.246초**다. 대기는 120초 간격을 기준으로 했으며 초기 관측 사이 실제 간격은 123초·151초, 이후 약 120초였다. 모든 관측에서 running·기존 PID 생존·상태 갱신 56초 이내였고 active_agents 0은 관측하지 못했다.

| UTC 관측 시각(2026-11-22) | active_agents |
|---|---|
| 15:44:03.796355 | 1 |
| 15:46:06.913678 | 1 |
| 15:48:37.727037 | 1 |
| 15:50:37.860937 | 1 |
| 15:52:38.003271 | 1 |
| 15:54:38.039403 | 1 |

- 인계 9(5)에 따라 **재시작 0회**, 강제 종료·롤백도 하지 않았다. 설치된 릴리스는 새 버전이고 실행 프로세스는 재개 전 PID 그대로다. 파일 설치와 런타임 전환을 구분해야 한다. `15:54:49.270597+00:00` 최종 관측에서도 active_agents 1·running·PID 생존, RELEASE 일치, 사전 기록한 보호 파일 존재/mtime/mode 동일을 확인했다.
- AT-HT-60 사전 기록·롤백 준비는 갖췄으나 **AT-HT-61·서버 적용 증거 수준 3은 미도달**이다. 재시작 후 hejo(기본·보조)·telegram·photon·Slack 연결, 새 오류/역추적 0건, SDK 자동 설치 결과, 처리기 등록, `telegram_status`, hejo 로그의 id/토큰 0건은 아직 검증하지 않았다. 착수 전 Telegram 모듈 부재 결과를 재시작 후 결과로 대신하지 않는다.
- 상태 조회 준비 중 기존 앱의 로컬 연결 설정과 Keychain을 이용한 추적 제외 native 시험 클라이언트를 만들었으나 출입증 검색 단계가 8초 제한에 걸렸다. 보조 시험 프로세스만 종료했고 실제 WebSocket 조회는 하지 않았다. 비밀 파일을 직접 열거나 인증값을 출력·기록하지 않았다. 향후 AT-HT-61을 마치려면 기존 앱 연결 권한으로 조회 가능한 시험 클라이언트 경로도 확인해야 한다.

### 보완 2 실행 증거

아래 로그는 모두 `.build/HEJO-TELEGRAM/task07/` 기준이다. 제품 변경본은 설치 대상 전체 커밋, 이번 추적 변경은 증거와 구현 보고 두 문서뿐이다.

| 명령/검사 | 실제 결과 | 로그 |
|---|---|---|
| `python3 resume-preflight.py`, 설치 범위 Git diff/log | 종료 0, 설치 범위는 이 작업 5개 커밋뿐. 제품 기준과 실제 대상의 설치 범위 diff 0 | `resume-before.json`, `resume-diff-stat.log/.exit`, `resume-diff-commits.log/.exit` |
| `install/hejo-release "$RELEASE_DIR"` | 종료 0, 실제 대상 위 전체 커밋, 출력 민감값 패턴 없음 | `release.json/.log/.exit` |
| `python3 compare-release.py`(설치 직후·중단 직후) | 모두 종료 0, RELEASE·41개 파일 일치 | `release-comparison.json` |
| Hermes venv Python `"$RELEASE_DIR/install/hejo-install" --check` | 첫 호출 종료 1(ModuleNotFoundError), 해당 호출에 Hermes 모듈 경로를 제공한 재실행 종료 0. 두 호출 모두 출력 민감값 패턴 없음 | `install-check.json/.log/.exit`, `install-check-env.json/.log/.exit` |
| `python3 wait-idle.py` | 종료 2(대기 한도 초과), 관측 보조 명령은 모두 종료 0, 재시작 미실행 | `idle-observations.json`, `idle-timeout.json` |
| 상태 조회 클라이언트의 출입증 검색 준비 | 제한 시간 초과, 상태 조회 미실행 | `probe-discovery.json`, `probe-build.log`, `probe-sign.log` |
| `python3 final-state.py` | 종료 0, 새 RELEASE·기존 실행 PID·보호 파일 metadata 동일·재시작 기록 없음 | `resume-final-state.json` |
| 임시 빈 HERMES_HOME의 Hermes venv `python scripts/scan_private.py` | 종료 1, 다른 작업 HEJO-DEADLINE-CLOSE 문서 절대 경로 4건(impl-report 97·109행, verdict 127·146행). 이 작업 파일 지적 0건 | `private-resume.log/.exit` |
| `git diff --check` | 종료 0 | 도구 실행 결과 |

다음 단계는 활성 작업이 없는 시점에 인계 9(5)부터 이어가는 것이다. 설치를 반복하지 말고 최신 HEAD·RELEASE·공용 설치 파일과 현재 프로세스를 먼저 확인한다. 현재 롤백 대상은 여전히 `227ef160694635f8afde36f06515f5136f73dc30`이며 앞서 준비한 명령을 유지한다. 설정·비밀 파일 직접 열람/쓰기, 직접 패키지 설치, 본체/플러그인/team-kit 변경, 앱 사본 교체·공개, 실제 메시지 발송, git push는 수행하지 않았다.
