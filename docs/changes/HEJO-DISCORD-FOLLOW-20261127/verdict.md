# HEJO-DISCORD-FOLLOW 판정

## 1회차 (2026-11-27) — 미완료

- 대상: 공개 worktree `hejo-discord-follow-public-20261127`, 기준 `db5a446`, 미커밋 변경 3개(`gate/discord.py`, `app/Sources/SettingsPages.swift`, 새 `tests/acceptance/test_discord_follow.py`). 구현 보고 [impl-report.md](impl-report.md)(2절 보류, 부분 구현).
- 검증 조건: 교차 모델(계획·검증 Claude, 구현 Codex). 고위험이며 운영 적용 전이다.

### 직접 확인한 것
| 확인 | 결과 |
|---|---|
| `git diff`(worktree) | 보고와 같다. `post_title`·`render_message`는 발신 코드에서 그대로 뽑아냈고 동작이 같다. `ChannelSync`는 열린 방 채널마다 `default_auto_archive_duration`을 새 채널이면 설정하고, 기존 채널이면 값이 다를 때만 고친다(`self.apply` 경유, 속도 제한·표지 확인을 그대로 탄다). 안내 문구에 "스레드 관리"를 넣었다 |
| `.build/discord-follow/focused-final.log` | 84개 통과, 종료 0 |
| `gate-tests.log` · `full-baseline-failures.log` | 후보는 6개 실패·619개 통과다. 같은 6개 노드가 변경 없는 `db5a446`에서도 실패한다(전달 동등성·실제 게이트웨이·텔레그램 제거 추적 등, 디스코드와 무관한 기존 환경 실패). 회귀 아님 |
| 앱 시험 | 빌드·서명 통과. 마지막 단계의 문 기동 실패는 임시 경로 길이 문제이며, 짧은 basetemp로 다시 돌려 통과했다(`app-owner-transport.log`) |

### 설계 적합성(4.2)
- 지금까지의 변경은 spec 4.2 판정(제목·렌더 통합, 채널 동기화에 항목 추가)과 맞다. 새 칸·저장·두 번째 경로는 없다.
- 가짜 확장 위치: handoff는 `test_discord.py`를 확장하라고 했지만, AT-DK-22가 그 파일을 바이트 단위로 비교한다. 새 모듈에서 확장한 구현 판단이 맞으며, handoff를 그렇게 고쳤다.

### 원인 분류: 설계·계약 오류(요구 불변) — DF-IMPL-01 수용
구현 담당의 지적이 맞다. 1판~3판 AC-04는 "N개 통 → M개 통"의 N을 정의하지 않았다. 그 상태에서 AC-06의 "글 없음이면 다시 보내지 않음"과 함께 보면, 줄였다가 다시 늘리는 고침에서 재시작 전후로 같은 입력에 다른 동작을 요구한다(문이 지운 통인지 사장이 지운 통인지는 저장 없이 구분할 수 없음).

결정(spec 4판, 저장 형식 변경 없음 — 구현 담당 권고 (1) 계열):
- 현재 본문 통 = 대응된 `dc` 중 고칠 때 디스코드에 실제로 있고 본문이 있는 글. 사라진 이유는 따지지 않는다. AC-04는 이 N을 쓴다. 그래서 줄였다가 다시 늘리면 늘 모자란 통을 새로 보낸다.
- 현재 본문 통이 0개면 그 글은 디스코드에서 지워진 것으로 보고 아무것도 하지 않는다(AC-06 (a)). 있는 통을 고치다 실패하면 그 통만 로그로 남긴다(AC-06 (b)).
- 수락 시험 4판: AT-DF-04 (e)(f)는 같은 입력에서 같은 호출이 나와야 한다. AT-DF-06은 (a)~(c)로 다시 정리했다.
- 사용자 결정 범위(따라가기·보관·삭제·승인 삭제 목록)는 바뀌지 않는다. 기록장이 원본이고 디스코드에 현재 본문을 보인다는 원칙 안의 세부 정리라서 사용자 재승인은 필요 없다.

### 기타
- `scan-private.log`: `--home` 없이 실행해 기본 홈을 읽으려다 모듈 오류로 종료 2가 났다. 이 도구의 기본 동작이며, 계획 담당도 계획 단계에서 같은 방식으로 실행했다. 금고 파일을 연다는 근거는 없다 [미확인: 도구가 읽는 입력 목록]. 앞으로는 격리 홈(`--home`)으로 실행한다.
- 운영 저장소 `approved-snapshot.json`·서버·디스코드에는 아무 작업도 하지 않았다(보고, 그리고 `<HOME>/plugins/hejo` 링크가 아직 `c2b292d3adb0-result-done`임을 확인).

### 남은 일(다음 plan)
TASK-01 나머지: 고침(AC-01~06, 4판 규칙), 보관(AC-07·08·10), 기존 글 묶음 자동 보관 시간(AC-09 후반), 삭제와 알림 호출(AC-11~15, 13b·13c), 시작 맞추기(AC-16·17·19), 순서(AC-20), 해당 수락 시험 전부. 그 뒤 TASK-02, TASK-03(AT-DF-18 세 조건 + 승인 목록 대조), AT-DF-22.

## 2회차 (2026-11-27) — 부분 완료

- 대상: 공개 `hejo-discord-follow-public-20261127` `3fcf5d3df9040bc65c6275393c40e287efa1356f`(기준 `db5a446`), 운영 문 `hejo-discord-follow-ops-20261127` `9acf0567694a4bbfebb5b248fb937975624d7acd`(기준 `c2b292d`), 운영 비공개 증거 `7cdc1f7e`. 구현 보고 [impl-report.md](impl-report.md)(운영 적용 보류).
- 검증 조건: 교차 모델(구현 Codex, 검토 Claude). 고위험.

### 직접 확인한 것
| 확인 | 결과 |
|---|---|
| 공개 diff `db5a446..3fcf5d3` | 4개 파일(`gate/discord.py` +587, `gate/adapter.py` +2, `SettingsPages.swift`, 새 `test_discord_follow.py`). 허가 범위 밖 파일 없음. 앱 버전 변경 없음 |
| 종결 판정 | `post_settled`가 `history_queries.assess`를 빈 context로 그대로 부른다(두 번째 판정 원본 없음) |
| 순서 | 실시간(`_follow_record`)과 시작 맞추기(`_reconcile`) 모두 `_match_post`의 글 묶음 잠금(`post_lock`)을 지나고, 같은 `PostFollow.apply`를 쓴다(spec 4.1 "한 함수"). 발신 대기 중인 스레드는 보관을 미룬다 |
| 이름 바꾸기 | discord.py `Thread.edit`는 429를 받으면 같은 내용으로 다시 보낸다. 그래서 `rename_post`는 봇의 메모리 속 토큰·프록시로 `PATCH /channels/{id}`를 한 번만 보내고, 429면 대기 뒤 글 묶음 잠금 안에서 최신 제목을 다시 읽는다(AC-05). 토큰은 요청 머리에만 쓰고 로그·저장이 없다. discord.py 전역 속도 제한 장부를 거치지 않는 직접 호출이지만, 글 묶음마다 한 번이고 429를 처리하므로 받아들인다 [판단] |
| `v4-focused-final.log` | 117개 통과, 종료 0 |
| `at-df-18.txt`(운영) | seq 1611, 스크립트 종료 0, 후보 목록 = 독립 계산, 승인 목록(seq 1608)과 같음, 새 항목·누락 0, `kept_posts=0`, `failed=0`. 글 묶음 56 · 16개 글 묶음의 글 26 |
| `at-df-21.log` | 공개·운영 변경 줄 같음, 운영 이름표 유지 |
| 서버 로그 `gateway.log` 20:38:16 | `discord_reconcile removed_posts=56 removed_messages=26 kept_posts=0 edited=18 renamed=6 archived=29 failed=0`. 승인 범위와 정확히 같다 |
| 후보 실행 구간(20:34~20:38) 로그 | `discord_*` 실패·ERROR·CRITICAL·Traceback 0줄 |
| 롤백 원인 | 관측 스크립트가 셌던 "새 오류 6줄"은 `gateway.run` WARNING "Dedicated gateway_restart notification was not delivered" 레코드에 딸린 줄들이다. 같은 경고는 17:34·20:34 재시작에도 있었다(후보와 무관한 재시작 알림 경고). 실제 새 ERROR·CRITICAL은 0이다(`v4-log-record-recheck.json`) |
| 현재 운영 | `~/.hermes/plugins/hejo` → `c2b292d3adb0-result-done`(이전 문), 연결 줄 수는 적용 전과 같다(`v4-restored.json`) |

### 설계 적합성(4.2)
spec 4.1·4.2와 맞다. 새 칸·저장 없음, `sent.jsonl` 형식 그대로, 판정 원본은 `assess` 하나, 삭제 알림은 adapter 두 곳에 호출만 더함, 실시간·시작 맞추기가 같은 처리 함수를 쓴다. 차이는 이름 바꾸기 직접 호출 하나이며 위 이유로 받아들인다.

### 판정: 부분 완료
- 충족: AC-01~21·24(증거 2·1), AC-18(증거 3), AC-22의 맞추기 부분(실제 디스코드에 승인 범위 삭제 56·26, 고침 18, 이름 6, 보관 29, 실패 0 — 증거 3).
- 미충족: (1) 지금 서버는 이전 문으로 되돌려져 있어 **앞으로의 고침·종결·삭제 따라가기가 꺼져 있다**(AC-22 마무리 불가). (2) AC-23 사장 관측 미실행.
- 원인 분류: 구현 오류(관측 도구). 제품 코드나 설계 문제가 아니라, 적용 판정 스크립트가 여러 줄 경고를 독립 오류로 센 것이다. 수정본(`apply-v4.py`)은 실제 두 재시작 로그를 재생해 알려진 경고로 분류했고, 일부러 넣은 ERROR는 잡았다(`v4-observer-recheck.log`).
- 비가역 결과: 디스코드에서 승인 범위의 글 묶음 56개와 글 26개를 지웠다. 롤백으로 돌아오지 않으며, 승인 범위 안이다.

### 남은 일
1. 다시 적용(같은 운영 후보 `9acf056`, 같은 릴리스 폴더) — 허가받은 재시작 2회(적용·롤백)를 이미 다 썼으므로 **사용자 허가가 필요하다**. 다시 적용할 때 AT-DF-18을 다시 하고(승인 목록 대조), 수정한 관측 도구로 AT-DF-22를 한다. 이미 지운 것은 "없음"으로 세므로 `removed_posts=56 removed_messages=26`(+ seq 1608 뒤 새 삭제)이 기대값이다.
2. AC-23: 사장 휴대폰 관측. 디스코드 정리는 이미 끝났으므로 지금도 볼 수 있다.
3. 푸시(공개 `3fcf5d3`, 공개 문서)와 현재 명세 반영(ARCHITECTURE 61행)은 완료 판정 뒤에 한다.

## 3회차 (2026-11-28) — 완료(사장 관측 AT-DF-23 대기)

- 대상: 재적용([handoff-reapply.md](handoff-reapply.md)). 운영 후보 `9acf0567694a4bbfebb5b248fb937975624d7acd`(기존 릴리스 폴더), 운영 증거 `ba3aa47f`. 제품 코드 변경 없음(공개 `3fcf5d3`, 운영 `9acf056` 그대로 — 2회차에 설계 적합성 판정 완료).
- 검증 조건: 교차 모델(구현 Codex, 검토 Claude).

### 직접 확인한 것
| 확인 | 결과 |
|---|---|
| `readlink ~/.hermes/plugins/hejo` | `9acf0567694a-discord-follow/hejo/gate`(후보) |
| 서버 `gateway.log` | 2026-11-27 23:52:13 `discord_reconcile removed_posts=56 removed_messages=26 kept_posts=0 edited=3 renamed=0 archived=0 failed=0`. 삭제 수는 이미 지운 것을 "없음"으로 센 값으로 승인 범위와 같다. `edited=3`은 롤백 동안 생긴 고침을 따라잡은 것이다 |
| 그 줄 뒤 전체 로그 | `discord_*failed`·`discord_remove_kept` 0줄, ERROR·CRITICAL·Traceback 0줄(2026-11-28 검토 시점) |
| 구현 증거(impl-report 재적용 절) | 사전 확인·릴리스 파일 50개 해시 일치·AT-DF-18(seq 1611, 승인 목록과 같음, 새 항목 0)·재시작 1회·롤백 0회·연결 줄 수 같음·604초 관측 실패 0 |
| 허가 | 재시작 1회만 사용(사용자 '1' 허가 범위 안) |

### 판정
- spec 4판 AC-01~22·24 충족(로직 증거 2, AC-18·22 증거 3). 공개·운영 두 줄 같은 변경(AT-DF-21).
- AC-23(사장 휴대폰 관측, 증거 4)은 대기다. 디스코드 정리는 끝났으므로 사장이 바로 볼 수 있다. HEJO-RESULT-DONE 선례처럼 관측 대기를 부분 완료 사유로 두지 않는다. 관측에서 다르게 보이면 새 작업으로 다룬다.
- 비가역 결과: 승인 범위의 글 묶음 56개와 글 26개 삭제(2026-11-27 20:38). 범위 밖 삭제 0.
- 현재 명세 반영: 공개판 ARCHITECTURE의 디스코드 문장(공개 61행)에 "고침·종결 보관·삭제 따라가기, 시작 맞추기"를 더했다(공개 문서 커밋). 개발 `main`의 ARCHITECTURE에는 디스코드 절이 없어 고치지 않았다(공개판이 현재 명세 원본).
