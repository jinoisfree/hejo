# HEJO-WAIT-JITTER 설계 (2판, 2026-11-25, 계획 검증 1회차 반영)

## 1. 현황 (공개판 `38885c6` = 0.2.8 + 문서·게이트 안내 기준, AUTOLOAD 반영 뒤 착수 시 재확인)
- [확인] 대화 목록의 스크롤 위치는 `app/Sources/NativeThreadList.swift`만 옮긴다(`move(to:)`). 호출 경로: `apply`→`keep(anchor)`/`keep(place)`/`startFollowing`/`restore`, `scrollTo`, `enter`/`placeEntry`, `remeasure`→`restoreResize`·`placeEntry`.
- [확인] `apply`는 갱신마다 `keep`으로 0·0.06·0.2·0.4초 지연 이동 4개를 `DispatchQueue.main.asyncAfter`로 예약한다. 이전 갱신의 예약은 취소하지 않는다. 두 `keep` 모두 리더 입력 수·`scrollRevision`을 검사한다(`keep(anchor)`는 클로저 안, `keep(place)`는 `restore` 안, 공개판 `38885c6` `NativeThreadList.swift:208-209`). 그러나 `scrollRevision`은 방 전환·`scrollTo`·진입에서만 오르고 같은 방의 연속 갱신에서는 그대로라서, 앞 갱신의 지연 이동이 뒤 갱신 뒤에도 유효하다 — 예약 세대가 구분되지 않는다는 것은 [가정]으로 계측에서 확인한다.
- [확인] `readerAnchor()`는 끝에서 2pt 이내면 nil → 끝 거리 기준으로 바뀐다. 갱신마다 두 기준이 번갈아 고를 수 있다.
- [확인] `remeasure`는 `NativeThreadCard.settle`과 축소 애니메이션(1/60초 재측정)에서도 불린다. 줄 높이가 바뀌면 `onMeasured`가 다음 런루프에 불린다.
- [확인] 갱신 원천: `ConversationView.refresh()`가 `history.show`와 왼쪽 목록 `updateSidebarRows()`를 함께 부른다. 스트리밍 공개 중 `streamTimer`가 1/30초마다 `refresh()`, 섬 타이머 0.1초, 모델 0.5초 타이머(`expireTyping`), 게이트 `typing` 프레임(ttl 6초).
- [확인] 왼쪽 목록: id가 같고 높이가 바뀐 줄만 0.24초 애니메이션 `noteHeightOfRows`, id가 바뀌면 `SidebarMotion.update`.
- [가정] 왕복의 원인은 겹친 지연 예약끼리의 경쟁 또는 두 기준점의 교대. 왼쪽 목록은 같은 갱신에서 줄 id/높이가 일시적으로 바뀌는 것. 둘 다 계측 전까지 미확정.
- [확인] HEJO-AUTOLOAD TASK-01이 같은 파일의 `readerAnchor(allowAtEnd:)`·`apply`를 바꾸는 중(미커밋). 그래서 이 작업은 AUTOLOAD 반영 뒤 착수한다(사용자 결정).

## 2. 구조
- 책임 그대로: 대화 목록 위치 = `NativeThreadList`, 왼쪽 목록 = `ConversationView.updateSidebarRows`. 새 계층·설정 없음.
- 진단: 기존 `ThreeTapDiagnostics`(환경 변수 `HEJO_THREE_TAP_TRACE`)에 이동 이벤트를 추가한다. 새 진단 장치·두 번째 기록 파일을 만들지 않는다.
- 수정 방향(계측으로 원인 확정 뒤 원인 자리에서): 자동 위치 조정은 "현재 유효한 조정 하나"만 살아 있게 한다. 새 갱신·리더 입력·`scrollTo`·진입은 이전 지연 조정을 무효화한다. 기준 선택(글/끝)은 한 갱신 안에서 한 번 정하고 그 갱신의 지연 재적용에서 바꾸지 않는다. 구체 구현(취소 토큰, revision 공유 등)은 구현 담당이 정한다.
- 원인이 위 두 파일 밖(창 크기·펫 배치·카드 내부 레이아웃 등)으로 확인되면 고치지 말고 멈추고 보고한다.

### 2.1 소유 칸 점검표
| 대상 | 원본·쓰기 주체 | 수명 |
|---|---|---|
| 대화 목록 스크롤 원점 | `NativeThreadList.move(to:)` 하나 | 화면 상태, 저장 안 함 |
| 지연 자동 조정(예약 세대) | `NativeThreadList` 인스턴스 하나가 만들고 무효화 | 다음 `apply`·리더 입력·`scrollTo`·진입·방 전환·인스턴스 해제 중 먼저 오는 때까지. 저장 안 함 |
| 왼쪽 목록 줄 배치 | `ConversationView.updateSidebarRows`(→ `SidebarMotion.update`/`noteHeightOfRows`) 하나 | 화면 상태, 저장 안 함 |
| 진단 기록 | 기존 `ThreeTapDiagnostics`, `HEJO_THREE_TAP_TRACE`가 가리킨 파일에만 | 환경 변수를 준 실행 동안만 씀. 시험은 임시 경로, 실물 확인은 worktree `.build/wait-jitter/`(git 무시) |
| 실물 화면 기록·프레임 분석 | 구현 담당이 `.build/wait-jitter/`에 저장 | 로컬 전용, 커밋 안 함. 검증 판정 완료 뒤 사용자가 지울 수 있음. 판정 문서에는 경로와 수치만 |

## 3. 대안
| 대안 | 판정 |
|---|---|
| A. 원인 자리에서 지연 조정 단일화·기준 고정(위) | 채택 |
| B. 답하는 중엔 내용 같으면 `show` 건너뛰기 | 기각: 원인 잔존, 다른 갱신 원천에서 재발 |
| C. 지연 재적용(`keep`) 제거, 즉시 1회만 | 기각: 늦은 레이아웃(이미지·settle)에서 위치가 어긋나는 기존 이유가 있음(AT91 "delayed layout passes") |

## 4. 기존 경로 판정
| 경로 | 판정 |
|---|---|
| `keep(place)`·`keep(anchor)` 지연 4회 | 통합: 같은 무효화 규칙 하나로. 겹친 예약 경쟁 제거 |
| `scrollTo`·`enter`·따라가기 | 유지(무효화 규칙만 공유) |
| 왼쪽 목록 `updateSidebarRows` | 유지, 원인에 해당하는 부분만 수정 |

## 5. 변경 성격
의미 변경(작음): 최종 위치 규칙은 보존, 중간 프레임의 왕복만 없앤다. 비교: AT91·AT-ALD·HejoSmooth 기존 시험 그대로 통과 + 새 AT-WJ.

## 6. 위험도·증거
일반(버그 수정, 인터페이스 동작 변경, 되돌릴 수 있음). 필요 증거: 목록 단위 실제 AppKit 하네스 3, 설치 앱 실제 답 대기 화면 기록 4.
