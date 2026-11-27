# HEJO-DISCORD-FOLLOW 구현 인계

명세 4판과 수락 시험 4판의 구현이다. [판정 1회차](verdict.md)의 DF-IMPL-01에 따라 실제로 남은 본문 통을 기준으로 고친다. 통이 전부 사라졌으면 한 줄을 기록하고 건너뛴다. 삭제 기준 기록과 대응표 형식은 그대로 사용한다.

## 공개판

- 공개 worktree `hejo-discord-follow-public-20261127`에서 기준 `db5a446f0280797359143ff9c58508e6b4cc9a75`에 커밋 `3fcf5d3df9040bc65c6275393c40e287efa1356f`를 만들었다.
- `gate/discord.py`의 기존 스레드 처리기에서 발신 뒤 고침·보관·삭제를 처리한다. 첫 채널 동기화 다음의 전체 맞추기는 같은 글 묶음 처리와 잠금을 사용한다. 원래 글이 확인된 삭제만 인정하며, 글 묶음 전체를 지우기 전에 디스코드 글 종류와 id 및 읽기 권한을 확인한다. 모르는 글이 들어오면 글 묶음은 남긴다.
- 이름 바꾸기는 Discord의 채널 수정 요청을 한 번씩 보낸다. SDK가 429 응답을 내부에서 이전 이름으로 자동 재시도하는 동작을 피하고, 대기 뒤 잠금을 획득해 최신 이름을 읽는다. 연결된 봇의 런타임 인증과 프록시 설정을 사용한다. 다른 요청의 SDK 설정을 변경하지 않는다. 보관된 글 묶음은 이름을 적용할 때 Discord가 요구하는 열린 상태를 함께 지정하고 작업 뒤 다시 보관한다. [Discord 채널 수정 계약](https://github.com/discord/discord-api-docs/blob/main/developers/resources/channel.mdx#modify-channel)
- `gate/adapter.py`의 `thread_delete`와 `_finish_thread_deletions`에는 기록과 방송 뒤 문 호출만 더했다.
- `app/Sources/SettingsPages.swift`의 봇 초대 안내에 스레드 관리를 넣었다. 앱 버전 차이는 0이다.
- `tests/acceptance/test_discord_follow.py`에 수락 시험과 가짜 포럼·글·웹후크를 넣었다. AT-DK-22가 바이트 일치를 검사하는 기존 `test_discord.py`는 그대로다. AT-DF-12는 스레드 삭제 후 읽기가 진행되는 동안 같은 디스코드 글 묶음에 새 사장 글이 들어오는 순서를 검증한다.

## 공개판 자체 시험

공개 worktree의 `.build/discord-follow/`에 로그를 보존했다. 앞선 문서에서 검증한 착수 기준과 같은 앱 소스 증거는 재사용했다.

| 확인 | 결과 |
|---|---|
| db5a446 기준 기존 디스코드·섹션 시험 및 AT-DF-03 | `baseline.log` 종료 0, 82개 통과 |
| 후보의 기존 디스코드·섹션 및 신규 시험 | `v4-focused-final.log` 종료 0, 117개 통과, 증거 수준 2 |
| `bash scripts/test.sh` | `v4-full-final.log` 종료 1, pytest 652개 통과 및 6개 실패. 실패 6개는 기준의 `full-baseline-failures.log` 노드와 모두 일치 |
| 앱 빌드와 시험 | 같은 앱 소스의 `app-tests.log`에서 빌드·서명 통과, 마지막 임시 경로 시험은 종료 1. `app-owner-transport.log`의 짧은 경로 재실행 종료 0, 4개 통과 |
| `scan_private.py --home <격리 홈>` | `v4-scan-final.log` 종료 0. 새 시험을 임시 인덱스에 넣어 검사 |
| AT-DF-13c 독립 스크립트와 AT-DF-18b | `v4-expect-edges.log` 종료 0. 원래 글 없는 삭제에서 대상 0개, 깨진 입력 세 종류는 각각 종료 2 및 표준 출력 없음 |
| 전체 삭제 읽기 판정 제거 mutation | 복사본에서 `v4-mutation.log` 종료 1. 모르는 일반 글·미분류 이름·미분류 정수 시험 3개 모두 후보 결함을 검출했고, 정상 판정 복구본은 focused에서 통과 |
| 중간 점검 | 첫 focused 중 AT-HD-46의 상태 프레임이 한 차례 더 들어왔다. 최종 focused와 전체 pytest에서는 통과했다 |

이전 단계의 기본 홈 정적 검사 시도(`scan-private.log` 종료 2)는 이번 실행에서 반복하지 않았다. 격리 홈을 명시했다.

## 운영 문과 적용

운영 문 작업 트리는 `hejo-discord-follow-ops-20261127`, 기준은 `c2b292d3adb051fe08156e63b6b1057bd1f5cc7d`다. 앱 소스와 앱 고유 시험을 제외하고 옮겼다. 기존 운영 이름표를 둔 상태에서 AT-DF-21의 두 제품 파일 변경 줄이 공개판과 일치했다(`.build/discord-follow/at-df-21.log`).

운영 문 커밋은 `9acf0567694a4bbfebb5b248fb937975624d7acd`다. `v4-ops-focused.log`는 종료 0 및 35개 통과다. `v4-ops-pytest.log`는 종료 1 및 888개 통과, 16개 실패다. 실패 노드 16개는 인계된 운영 기준 실패 증거와 일치한다.

| 단계 | 실제 결과 |
|---|---|
| AT-DF-18, 운영 문 커밋 기준 | `at-df-18.txt` 종료 0, 서버 사본 seq 1611. 독립 스크립트 종료 0, 후보 호출 목록 일치, 고정 승인 목록(seq 1608)과 일치, 추가·누락 0. 묶음 56개, 남는 16개 묶음의 글 26개, `kept_posts=0` 및 `failed=0`. 증거 수준 3. 원본 대조 후 사본 폴더 제거 |
| 릴리스 준비 | `v4-release-build.log` 및 `v4-release-import.log` 종료 0. 운영 커밋과 RELEASE 일치, gate 소스 일치 및 후보 경로 import 성공 |
| 설치와 첫 재시작 | `v4-apply.log`에 `v4-install.log` 종료 0, `v4-restart.log` 종료 0. 후보 링크 확인, PID 27345 → 1782. hejo 6·Slack 6·photon 1·Discord 1 |
| AT-DF-22 실제 맞추기 | `removed_posts=56 removed_messages=26 kept_posts=0 edited=18 renamed=6 archived=29 failed=0`. 삭제 수는 이미 없어 처리된 대상도 세며, 새로 지운 수만 따로 분리할 증거는 없다. 증거 수준 3 |
| 운영 판정과 롤백 | 관측 스크립트가 새 오류 6줄로 판정해 적용 단계 종료 1. 이전 릴리스 설치·재시작 각 종료 0, PID 1782 → 2997. 연결 줄 수 회복은 같은 실행에서 확인. 경고 분류 때문에 관측 스크립트는 회복 단계에서도 종료 1 |
| 로그 재분류와 복구 재확인 | `v4-log-record-recheck.json`에서 두 재시작 모두 같은 재시작 알림 경고 헤더에 이어 표시되는 세부 6줄을 확인했다. 이를 독립 오류로 센 집계가 잘못됐다. 이전 로그의 같은 헤더는 단일 줄이라 전체 레코드 형태에는 차이가 있다. 두 재시작에 추가된 ERROR·CRITICAL은 0. `v4-restored.json`은 기존 RELEASE, 실행 PID 및 문 리스너 일치, 플랫폼별 연결 줄 수 전부 일치를 확인했다 |

**구현 판단 상태는 운영 적용 보류다.** 실제 정리와 수정은 실행됐으며 롤백으로 삭제가 복원되지는 않는다. 현재 운영 문은 이전 `c2b292d3adb0-result-done`이다. 승인된 적용 재시작 1회와 롤백 재시작 1회를 모두 사용했다. AT-DF-23 사용자 관측은 미실행이다. 다음 검토에서는 제목 변경의 단발 429 처리와 실시간·시작 맞추기의 동일 글 묶음 직렬화, 비가역 처리 건수, 다중 줄 경고의 기준 판정을 우선 확인한다. 재적용의 새 조건과 재시작 권한은 운영 문과 승인 목록을 다시 대조한 뒤 확정한다.

운영 증거는 운영 저장소 로컬 커밋 `7cdc1f7e6e494d1e24555ce3ce01e566c6d47d0a`에 기록했다. 관측 스크립트의 실행 원본을 로컬 증거로 보존하고 수정본에서 게이트웨이 경고의 이어지는 줄을 묶어 처리한다. 실제 두 재시작의 로그를 재생해 알려진 경고로 분류하고, 별도로 넣은 무관한 ERROR 하나는 검출했다(`v4-observer-recheck.log`). 실행 서버에 변경을 추가로 적용하지 않았다.

## 재적용 (2026-11-27~28, KST)

[재적용 인계](handoff-reapply.md)에 따라 운영 후보 `9acf0567694a4bbfebb5b248fb937975624d7acd`의 기존 릴리스를 재적용했다. 증거 수준 3이다. 아래 로그는 운영 문 worktree의 `.build/discord-follow/reapply/`에 남겼다. 운영 저장소의 작업 문서와 증거 커밋은 `ba3aa47fe501efdb1faaa964b5834e652e237a57`이다.

| 확인 | 실제 결과 |
|---|---|
| 사전 확인 | `preflight.py` 종료 0. 유휴 상태·기존 링크·직전 시작 뒤 300초 초과 확인. 기존 후보 RELEASE 및 패키지 파일 50개 SHA-256 일치. `preflight.log`, `release-parity.log` |
| AT-DF-18 | `run-snapshot.sh` 종료 0. 서버 사본 seq 1611의 후보와 독립 계산 목록이 고정 승인 seq 1608과 일치. 56개 묶음·16개 묶음의 글 26개, 추가·누락 각 0, `kept_posts=0`, `failed=0`. `at-df-18.log`. 실제 id와 파일별 지문은 운영 저장소 `reapply/`에 보존 |
| 설치·재시작 | 후보 `hejo-install --home <루트 홈>` 종료 0, `hermes --profile default gateway restart` 종료 0. 적용 재시작 1회, 롤백 0회. PID 2997 → 63583. `install.log`, `restart.log` |
| AT-DF-22 | `removed_posts=56 removed_messages=26 kept_posts=0 edited=3 renamed=0 archived=0 failed=0`. hejo 6·Slack 6·iMessage 1·Discord 1로 전후 동일. 기준 밖 ERROR·CRITICAL과 그룹화된 기준 밖 로그 각각 0. 후보 링크·RELEASE 및 문 리스너 확인. `operations.jsonl` |
| 지속 관측 | 2026-11-27 23:52:18부터 2026-11-28 00:02:22까지 604초. `discord_*_failed` 0건, 새 ERROR·CRITICAL 0건. 같은 PID와 Discord 연결, 후보 RELEASE를 마지막에 확인. `run.log` 종료 0 |

기준과 실제 로그를 레코드 단위로 대조했다. 수정 관측 규칙 `apply-v4.py` 사본과 실제 실행에 쓴 `run-reapply.py` 사본은 운영 저장소의 `reapply/`에 보존했다. 이번에 승인 목록에 추가된 삭제 대상은 0개다. 정리 수치는 이전 적용에서 이미 없어 처리된 대상도 포함하며, 재적용 중의 새 삭제 건수와 구분한다. AT-DF-23 휴대폰 관측과 계획 담당의 검토가 남았다.
