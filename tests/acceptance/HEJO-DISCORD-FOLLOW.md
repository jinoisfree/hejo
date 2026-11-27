# HEJO-DISCORD-FOLLOW 수락 시험

- 4판(spec 4판과 짝, 계획 검증 1회차 DF-R1-01~03, 2회차 DF-R2-01·02, 구현 보고 DF-IMPL-01 반영) · 상태: 명세 확정 / 코드: 기대값 스크립트 `tests/acceptance/discord_follow_expect.py`만 작성(나머지는 구현 담당이 `tests/acceptance/test_discord_follow.py`로 옮김, 기대값 소유는 기획설계) / 실행: 기대값 스크립트만 서버 사본으로 실행(seq 1608, 글 묶음 56 · 남는 16개 글 묶음의 디스코드 글 26, 깨진 줄 넣은 사본은 종료 2) / 독립 검토: 계획 검증 3회차 APPROVED
- 하네스: `tests/acceptance/test_discord.py`의 가짜 `Native`·`Guild`·`Channel`·`Hook`과 `pair`·`activate`·`settled` 도우미를 쓴다. 구현 담당이 가짜에 글 묶음(이름·`archived`·`auto_archive_duration`·`edit`·`delete`), 웹후크 `edit_message`·`delete_message`·`fetch_message`, "없음"·권한 없음·속도 제한 실패 주입을 더한다. 가짜의 모든 바꾸는 호출은 순서대로 기록한다.
- 가짜 명부(`alpha`)·가짜 서버 id만 쓴다. 실제 id·본문을 시험 파일에 넣지 않는다.
- 기준본(`db5a446`)에서는 새 동작이 없으므로 AT-DF-01~20은 실패가 정상이다. 단 **AT-DF-03과 기존 `test_discord.py`·`test_discord_sections.py`는 기준본에서도 통과**해야 한다(착수 때 `.build/discord-follow/baseline.log`).
- 시험 명령: `HEJO_PYTHON=<Hermes 시험 venv python> PYTHONPATH=<Hermes workspace> bash scripts/test.sh` 전체, `<Hermes 런타임 venv python> scripts/scan_private.py`. 시험 임시 폴더는 pytest `tmp_path`만 쓴다.

약어: E(t) = 직원 글(본문 t), Q = 직원 `asked`+[승인, 거절], O = 사장 일반 글. "보냄" = 정착 뒤 웹후크 발신으로 글 묶음 P가 생김. 바꾸는 호출 = send·edit_message·delete_message·글 묶음 edit·delete·채널 edit.

| 시험 | AC | 입력 | 기대값 |
|---|---|---|---|
| AT-DF-01 | AC-01·07 | Q(본문 `🔴 A`) 보냄 → 고침(본문 `✅ A`, 버튼 []) → `state closed` | 정착 뒤 호출 순서: edit_message(Q의 dc, 내용 `✅ A`, `선택:` 줄 없음) → 글 묶음 이름 `✅ A` → `archived=True`. 각 1번. send 0번 추가. `sent.jsonl` 줄 수 그대로 |
| AT-DF-02 | AC-02 | (a) E(`첫`) 보냄 → 같은 스레드 E(`둘째`) 보냄 → 둘째 고침 (b) 사장이 디스코드에서 연 글 묶음(사장 글 기록) → 직원 답 E 보냄 → E 고침 | (a)(b) 모두 edit_message 1번, 이름 바꾸기 0번 |
| AT-DF-03 | AC-03 | E 기록 → 정착 시간 안에 고침 2번 → 정착 | send 1번(마지막 본문), edit_message 0번. **기준본에서도 통과** |
| AT-DF-04 | AC-04 | (a) 3000자 E 보냄(본문 통 2개) → 100자로 고침 (b) 100자 E 보냄 → 4500자로 고침(통 3개) (c) 첨부 1개 있는 E 보냄 → 본문만 고침 (d) 같은 본문으로 고침 (e) `A×2000+B×1000`(통 2) 보냄 → `A×2000`으로 고침 → 문을 다시 만듦(재시작) → `A×2000+C×1000`으로 고침 (f) (e)와 같되 둘째 고침 대신 문이 꺼진 동안 가짜 디스코드에서 둘째 통을 지움 → 재시작 → `A×2000+C×1000`으로 고침 | (a) 첫 통 edit 1, 둘째 통 delete_message 1 (b) 첫 통 edit 1, 같은 글 묶음에 send 2(`thread`=P), `sent.jsonl` 2줄 늘어남 (c) 본문 통 edit 1, 첨부 통 호출 0 (d) 바꾸는 호출 0 (e)(f) 마지막 고침에서 둘 다 같은 호출: 첫 통 edit 0(내용 같음), 같은 글 묶음에 send 1(`C×1000`), `sent.jsonl` 1줄 늘어남, 실패 로그 0 |
| AT-DF-05 | AC-05·20 | 가짜 이름 바꾸기가 속도 제한(대기 600초 가짜 시계)으로 막힌 동안 같은 스레드에 E 새 글, 다른 방에 E 새 글 → 그 뒤 제목 글을 두 번 더 고침 → 대기 끝 | 두 새 글 send가 대기 끝 전에 일어남. 대기 끝 뒤 이름 바꾸기는 마지막 제목으로 1번만 |
| AT-DF-06 | AC-06 | (a) 한 통짜리 보낸 글이 가짜 디스코드에서 지워짐(읽기 "없음") → 고침 (b) 고치기 호출이 권한 없음 (c) 읽을 때는 있었는데 고치기 호출이 "없음" | (a) `discord_update_failed kind=NotFound` 1줄, edit 0·send 0 (b)(c) 각각 `discord_update_failed kind=<이름>` 1줄, 그 통을 대신하는 send 0. 모두 id·본문 없음, 다음 스레드 발신 정상 |
| AT-DF-07 | AC-07·08 | (a) Q 보냄 → O(답) → E(뒤 직원 글) 보냄 (b) Q 보냄만 (c) (a) 글 묶음이 이미 보관됨 | (a) `archived=True` 1번 (b) 보관 호출 0 (c) 보관 호출 0 |
| AT-DF-08 | AC-08 | Q 보냄 → 가짜가 글 묶음을 자동 보관(archived=True) → `state asked` 기록 | 보관 풀기 호출 0 |
| AT-DF-09 | AC-09 | (a) 새 방 동기화 (b) 기존 방 채널 `default_auto_archive_duration`=4320 (c) 이미 1440 | (a)(b) 채널 edit(`default_auto_archive_duration=1440`) 1번씩 (c) 0번. 분류·순서 호출은 기존 시험과 같음 |
| AT-DF-10 | AC-10 | (a) 보관된(종결 아님) 글 묶음의 글 고침 (b) 보관된 종결 글 묶음의 글 고침 (c) 보관된 글 묶음에서 글 하나 삭제(다른 글 살아 있음) | (a) archived=False → edit → archived=True (b) 같은 순서, 끝 상태 보관 (c) archived=False → delete_message → archived=True |
| AT-DF-11 | AC-11 | (a) 한 글 묶음에 E1(본문 통 1), E2(3000자 → 본문 통 2 + 첨부 통 1) 보냄 → E2 글 삭제(`_record`) (b) 이어서 E1 삭제 | (a) delete_message 대상 = E2의 `sent.jsonl` `dc` 3개와 정확히 같은 집합(E1의 dc는 0번), 글 묶음 삭제 0, 시작 맞추기라면 `removed_messages=3` (b) 글 묶음 delete 1번 |
| AT-DF-12 | AC-12 | (a) 스레드 K에 E1·E2 보냄 → 앱 `thread_delete`(K) (b) 사장이 디스코드 글 묶음 P에 쓴 글로 K 생성 → K 삭제 → 같은 P에 사장이 또 써서 K2 생성·직원 답 보냄 → K2는 살아 있음 | (a) P delete 1번(`thread_delete`와 `_finish_thread_deletions`가 문에 알림) (b) K 글만 지우고 P는 남음. 사장 디스코드 글 개별 delete_message 0 |
| AT-DF-13 | AC-13 | (a) 방 삭제 (b) `sent.jsonl`에 기록장에 없는 `msg_id` 줄 (c) 다른 짝 표지 줄 (d) 디스코드 사장 글 하나만 hejo에서 삭제(직원 글은 살아 있음) | (a) 기존처럼 채널을 `hejo 보관`으로 이동, 글·글 묶음 delete 0 (b)(c)(d) delete 호출 0 |
| AT-DF-13b | AC-13b | 모두 E 하나씩인 글 묶음 셋을 보낸 뒤 각 E 글 삭제를 기록(실시간 처리 끔)하고 시작 맞추기: (a) 가짜 디스코드 글 묶음에 시스템 글(참가자 추가) 하나가 더 있음 (b) 문이 보낸 일반 글이 하나 더 있는데 그 `sent.jsonl` 줄이 깨져 문이 건너뜀(살아 있는 hejo 글 E2의 줄) (c) 디스코드 글 읽기가 실패 (d) 글 묶음에 목록 밖 종류의 글 하나(가짜 종류 `thread_created`, 그리고 정수 99 같은 알 수 없는 종류 각각) (e) 글 묶음에 이름 바꿈 알림(`channel_name_change`)·고정 알림(`pins_add`) 하나씩 | (a) 글 묶음 delete 1번 (b) 글 묶음 delete 0, 지워진 E의 dc만 delete_message 1번, `kept_posts=1`, `discord_remove_kept` 1줄 (c) 글 묶음 delete 0, `failed=1` (d) 두 경우 모두 글 묶음 delete 0, 지워진 E의 dc만 delete_message 1번, `kept_posts=1` (e) 글 묶음 delete 1번 |
| AT-DF-13c | AC-13·2절 | 글 묶음 P에 문 글 E 하나를 보냄. 그 뒤 기록장 사본에서 E의 `message` 레코드는 없고 E의 글 삭제 레코드만 있게 만든다(실시간·시작 맞추기 모두) | 글 묶음 delete 0, delete_message 0. 같은 입력으로 `discord_follow_expect.py <사본> <승인 seq>`의 `remove_posts`·`remove_messages`·`since_seq`에 P가 없음 |
| AT-DF-14 | AC-14·15 | 지울 글 묶음이 (a) 이미 없음 (b) 권한 없음 | (a) 오류 로그 0, 시작 맞추기 `removed_posts`에 셈 (b) `discord_remove_failed kind=Forbidden` 1줄, `failed`에 셈, 다음 글 묶음 계속 |
| AT-DF-15 | AC-16 | 가짜 기록장(아래 만듦) + 문 시작 → 첫 동기화 | 순서와 대상이 AC-16 (1)~(6)과 같음. 로그 `discord_reconcile removed_posts=2 removed_messages=1 kept_posts=0 edited=1 renamed=1 archived=1 failed=0` 1줄 |
| AT-DF-16 | AC-17 | AT-DF-15 직후 같은 자료로 문을 다시 만들어 시작 | 바꾸는 호출 0. 로그 `removed_posts=2 removed_messages=1`(이미 없음으로 셈) `kept_posts=0 edited=0 renamed=0 archived=0 failed=0` |
| AT-DF-17 | AC-19 | AT-DF-15 자료에서 (a) 첫 지우기가 실패 (b) 두 번째 호출 직전에 짝 해제 | (a) 나머지 계속, `failed=1` (b) 그 뒤 바꾸는 호출 0 |
| AT-DF-18 | AC-18 | 서버 공유 폴더 사본(0700 임시 폴더, 기록장·`sent.jsonl`·`channels.json`) + `discord_follow_expect.py <사본> 1608` + 후보 문 코드 시작 맞추기(가짜 디스코드: 사본 `sent.jsonl`의 모든 글 묶음·`dc` 글과 디스코드 사장 글이 일반 글로 있고, 글 묶음마다 참가자 추가 시스템 글 1개) | (1) 스크립트 종료 0 (2) 가짜가 받은 글 묶음 delete 목록 = `remove_posts`, delete_message 목록(글 묶음별 dc) = `remove_messages`, `kept_posts=0` (3) `remove_posts`·`remove_messages`가 운영 저장소 `approved-snapshot.json`과 같거나 차이가 모두 `since_seq`에 있음. 하나라도 아니면 멈춤. 결과 JSON은 운영 저장소 작업 폴더에만, 공개 증거에는 개수만. 임시 폴더는 판정 뒤 삭제 |
| AT-DF-18b | AC-18 | 정적 사본에 (a) `sent.jsonl` 깨진 줄 (b) 기록장 깨진 줄 (c) `dc` 필드 빠진 줄을 각각 넣고 스크립트 실행 | 셋 다 종료 2, 표준 출력 없음 |
| AT-DF-19 | AC-20 | 같은 스레드에 발신 대기 중인 E와 이미 보낸 글의 고침이 함께 있음 + 시작 맞추기 진행 중 | 가짜 호출 기록에서 같은 글 묶음 호출이 겹치지 않음(각 호출 시작·끝 사이에 같은 글 묶음 다른 호출 없음), 순서는 기록장 순서 |
| AT-DF-20 | AC-24 | 정적: `SettingsPages.swift` 디스코드 준비 안내 | "스레드 관리" 포함 1곳. `Info.plist` 버전 변경 없음 |
| AT-DF-21 | AC-21 | `git diff <각 기준> -- gate/discord.py gate/adapter.py`(공개 `db5a446` 대비 공개 후보, `c2b292d` 대비 운영 후보) | 두 diff의 변경 줄이 같다. 다르면 그 줄과 이유 보고 |
| AT-DF-22 | AC-22 | 운영 적용(handoff TASK-03) | 링크 RELEASE = 후보, 재시작 1회, 디스코드 연결 줄 있음, `discord_reconcile`의 `removed_posts` = AT-DF-18 글 묶음 수, `removed_messages` = AT-DF-18 디스코드 글 id 수(사이에 생긴 새 삭제는 더하고 ops-targets에 적음), `kept_posts=0`, `failed=0`, 플랫폼별 연결 줄 수 적용 전과 같음, 기준 밖 새 오류 줄 0 |
| AT-DF-23 | AC-23 | 사장 휴대폰 관측 | 11-26 인스타 상태 알림 글 묶음 없음, 11-27 인스타 DM 알림(승인 뒤 ✅로 고쳐진 글, 실제 대상은 ops-targets) 글 묶음 이름 `✅`로 시작·활성 목록에서 내려감 |

AT-DF-15 가짜 기록장(방 `alpha`, 모두 보냄 뒤 기록장에 추가해 만든다):
- P1: E 하나 → 글 삭제. (지울 글 묶음)
- P2: 스레드 K2의 E 둘 → `thread_delete`(K2). (지울 글 묶음)
- P3: E1·E2 → E2만 글 삭제. (E2 글 지우기 = `removed_messages=1`)
- P4: Q(`🔴 B`) → 고침 `✅ B` → `state closed`. 단 가짜 디스코드에는 고치기 전 본문·이름이 남아 있다(실시간 처리를 끈 상태에서 기록해 재현). (edit 1, rename 1, archive 1)
- P5: E 하나, 종결 아님, 변화 없음. (호출 0, 자동 보관 시간이 이미 1440)

## 실행 증거(구현 담당이 채움)
- `.build/discord-follow/baseline.log`: 기준본 실행(AT-DF-03, 기존 디스코드 시험 통과)
- `.build/discord-follow/gate-tests.log`: `pytest -v` 전체
- `.build/discord-follow/at-df-18.txt`: 개수와 일치 여부만(실제 id는 운영 저장소)
