# HEJO-DISCORD-FOLLOW 계획 검증 기록

## 1회차 (2026-11-27) — BLOCKED, planHash `b2d5705cc09a7e76548ab2ba2e90aafcc356c244a283aea3db8a3476c1f7f75f` (spec 1판)

| 지적 | 처리 | 이유와 반영 |
|---|---|---|
| DF-R1-01 (차단) 승인 범위에 일부 삭제가 빠졌고, 설치 직전 대상이 바뀌어도 바뀐 목록끼리 다시 비교해 통과할 수 있다 | 수용 | 맞다. 1판 TASK-03 (2)·(4)는 시점마다 새로 계산한 값과 비교만 해서, 승인 뒤 대상이 늘어나도 막지 못했다. 반영: spec 5.4 "승인 범위와 대조"를 새로 둠. 허가 범위 = (가) 승인 기준 목록(seq 1608, 글 묶음 56개 통째 + 남는 16개 글 묶음의 디스코드 글 26개, 실제 id는 운영 저장소 `approved-snapshot.json`) + (나) 그 뒤 새 삭제 레코드를 따라 지우는 것. AC-18 통과 조건 (3)과 handoff TASK-03 (2)는 늘 같은 기준 목록과 대조하며, 차이는 seq 1608 뒤 삭제 레코드(`since_seq`)일 때만 허용한다. 다르면 적용하지 않고 사용자 확인. handoff 11번에 허가 범위의 두 숫자를 적었고, 계획 응답 본문에도 적는다 |
| DF-R1-02 (차단) 기대값 스크립트가 깨진 줄을 건너뛰어 살아 있는 대응 글을 잃고 글 묶음 전체를 지울 대상으로 잘못 볼 수 있다 | 수용 | 맞다. 스크립트에서 깨진 줄은 `ValueError`로 건너뛰었다. 문 `_load_sent`도 깨진 줄을 건너뛰므로 같은 위험이 실제 문에도 있다. 반영: (1) 스크립트는 깨진 줄·빠진 필드에서 종료 2로 멈추고 아무것도 출력하지 않는다(AT-DF-18b, 세 경우 모두 직접 실행해 종료 2 확인). (2) 문 쪽 안전 확인 AC-13b: 글 묶음째 지우기 직전에 디스코드 글을 읽어 모든 일반 글이 지워진 글의 id일 때만 지운다. 모르는 글이 있으면 그 글 묶음은 남기고 지워진 글만 지운다(`kept_posts`). 시스템 글(참가자 추가)은 세지 않는다. 섞인 글 묶음 시험은 AT-DF-13b (b)(대응표 줄이 깨져 살아 있는 문 글을 문이 모르는 경우). AC-18·22 통과에 `kept_posts=0` 추가 |
| DF-R1-03 (차단) 일부 삭제의 기대값 단위(hejo msg_id)와 실제 디스코드 글 수가 다를 수 있다 | 수용 | 맞다. 한 hejo 글은 본문 여러 통과 첨부 통으로 디스코드 글 여러 개가 된다(`db5a446` `_send_message`, `_save_sent`). 반영: `removed_messages`의 단위를 **디스코드 글 id**로 정했다(spec AC-16). 스크립트는 글 묶음별 `dc` 목록을 낸다. AT-DF-18은 가짜가 받은 delete_message 목록을 글 묶음별 dc 목록과 정확히 비교한다(누락·초과 검출). AT-DF-11은 본문 2통 + 첨부 1통인 글을 지울 때 정확히 그 dc 3개만 지우는지 본다. 실측 seq 1608: 지울 hejo 글 26개 = 디스코드 글 26개(모두 한 통, 첨부 없음) |

바뀐 파일: spec.md(2판: 1절 실측·`_load_sent` 위험·시스템 글, AC-11·13b·16·18·22, 5.3, 5.4 신설, 6절), tests/acceptance/HEJO-DISCORD-FOLLOW.md(2판: AT-DF-11·13b·15·16·18·18b·22), tests/acceptance/discord_follow_expect.py(엄격 입력, dc 단위, `since_seq`), handoff.md(0·2·8·9 TASK-03·11), 운영 저장소 `docs/changes/HEJO-DISCORD-FOLLOW-20261127/approved-snapshot.json`(새로 만듦, 비공개).

## 2회차 (2026-11-27) — BLOCKED, planHash `cced42cf847870d1d8980372db42eee59ee728536700d086409c77d58e41665a` (spec 2판)

| 지적 | 처리 | 이유와 반영 |
|---|---|---|
| DF-R2-01 (차단) 원래 message 레코드가 없는 msg_id에 삭제 레코드만 있어도 기대값 함수가 삭제로 인정한다(seq 1609 재현에서 글 묶음째 승인 뒤 새 삭제로 분류됨) | 수용 | 맞다. `deleted_at`이 `thread_of`(원래 글 존재)를 확인하지 않았다. 반영: spec 2절 "지워진 글"을 "원래 `message` 레코드가 있고 삭제 레코드도 있는 글"로 좁혔다. 삭제 레코드만 있는 id는 살아 있는 것으로 보고 그 글 묶음을 지우지 않는다(AC-13에도 명시). 스크립트도 원래 글이 없으면 삭제로 보지 않는다. 같은 재현(`ghost` 대응 줄 + seq 999999 삭제 레코드)을 다시 돌려 `remove_posts`·`remove_messages`·`since_seq` 어디에도 그 글 묶음이 없음을 확인했다. 시험은 AT-DF-13c(문 코드·스크립트 모두). 실제 사본(seq 1608)의 결과는 승인 기준 목록과 같다(56·16·26, 차이 0) |
| DF-R2-02 (차단) AC-13b가 default·reply 밖의 글 종류를 모두 시스템 알림으로 보고 무시한다 | 수용 | 맞다. 알 수 없는 종류를 무시하면 지우면 안 될 글 묶음을 지울 수 있다. 반영: 글 종류를 셋으로 나눴다. 일반 글(`default`·`reply`), 무시해도 되는 시스템 알림 네 종류(`recipient_add`·`recipient_remove`·`channel_name_change`·`pins_add`), 그 밖의 모든 종류(알 수 없는 종류 포함)인 미분류. 미분류가 하나라도 있으면 글 묶음째 지우지 않고 지워진 문 글만 지운다(`kept_posts`). 시험은 AT-DF-13b (d)(목록 밖 종류·알 수 없는 정수 종류 → 남김)와 (e)(허용 네 종류 중 둘 → 지움) |

바뀐 파일: spec.md(3판: 2절 지워진 글, AC-13, AC-13b), tests/acceptance/HEJO-DISCORD-FOLLOW.md(3판: AT-DF-13b (d)(e), AT-DF-13c), tests/acceptance/discord_follow_expect.py(원래 글 확인), handoff.md(0·2·8). 운영 저장소 `approved-snapshot.json`은 바꾸지 않았다(새 규칙으로 다시 계산해도 같음).

## 3회차 (2026-11-27) — APPROVED, planHash `ebbcfd537f69ed6f8de8a765fff791c90f7d1136c79a00c8402325fc5d13bb73` (spec 3판)

지적 없음. 계획(spec 3판, 수락 시험 3판, handoff)을 그대로 유지하고 구현을 시작한다. 이 통과를 계약7 사전 별도 검토(교차 모델)로 인정한다(10-planning 계약7 첫 계획 사전 검토).
