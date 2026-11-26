# 구현 인계 · HEJO-BUBBLE-WIDTH-20261126 TASK-01

1. **받은 설계** · [handoff.md](handoff.md), [design.md](design.md) 2판과 [수락 시험](../../../tests/acceptance/HEJO-BUBBLE-WIDTH.md) 2판. 연합개발 교차 모델, 위험도 일반, 필요 증거 수준 2. 착수 시 `git fetch github`로 고정한 base_commit은 `2dea766cbdbd5e179a6269aabbfefc750036b219`이며 설계 기준과 일치했다.
2. **구현자 판단** · 구현 및 자체 시험 완료. 독립 검토와 TASK-02가 남았다.
3. **변경 후 구조** · 관제 화면에서 `ChatMetrics`가 75%와 240pt를 정의하고 `NativeThreadCard.layout`이 글 칸에서 최대 폭을 계산한다. 기존 TextKit 측정 캐시에 맞춤 폭을 함께 기록한다. 줄 조각의 문자 범위를 원문의 줄 범위와 대조해 자동 줄바꿈을 판정하고, 좁힌 폭에서 높이와 가로 경계를 확인한다. 작성 중 폭은 같은 카드·글·카드 폭에서만 이어 받고, 기존 높이 완화는 유지한다.
4. **변경 위치** · `app/Sources/ChatStyle.swift` 비율 변경. `NativeThreadCard.swift` 폭 맞춤 및 작성 중 폭 상태, `Content.bubbleWidth` 제거. `ConversationView.swift`에서 영역 폭 계산과 네 호출 인자 제거. `app/Tests/BubbleWidthTests.swift`와 `TestMain.swift`에 수락 및 캡처 입구 추가. `HistoryTransportHarness.swift`, `OwnerProfileTests.swift`, `ScrollTests.swift`, `WaitJitterTests.swift`의 옛 인자 제거. 표·코드 시험 자료와 검사는 기존 `OwnerProfileTests` 것을 공유한다.
5. **설계 대조** · 2판의 책임 배치, 우선순위, 범위에 맞춰 구현했다. 기존 시험 기대값 변경 없음.
6. **임시 경로** · 제품 코드에 임시 경로 없음. 기준본 시험 커밋에서 사용한 옛 인자는 제품 커밋에서 제거했다.
7. **의미 변경** · 폭 900pt 카드의 긴 글은 738pt에서 615.75pt로 바뀐다. 명시적으로 끊은 네 줄 예제는 738pt에서 152pt로 맞춰진다. 기준본 재현과 수정본 비교는 9번 로그를 참조한다.
8. **추가한 시험 계약**
   - AT-BW-01~03 · 내 글·직원 글 최대 폭과 양 끝 정렬, 좁은 카드 경계, 폭 재계산.
   - AT-BW-04 · 명시 줄바꿈의 가장 긴 줄과 글 높이, 한 줄 맞춤의 보존.
   - AT-BW-05 · 자동 줄바꿈, 표·코드, 접기 글자, 가운데 정렬의 우선순위와 가로 넘침 방지.
   - AT-BW-06 · 작성 중 같은 글의 폭 유지, 확정·카드 폭·글씨 크기 변경 시 초기화.
   - AT-BW-10 · 목록에 글을 한 번 넣은 뒤 창의 폭만 바꿨을 때 보이는 두 글 뷰의 폭과 위치.
   - 착수 기준본이 22개 재현 항목에서 실패하고 12개 보존 항목에서 통과해 결함 검출을 확인했다. 별도 인위적 결함 주입은 생략했다.
9. **실행한 검증** · 직접 실행, 앱 하네스 증거 수준 2. 로그 경로는 아래 공개 worktree의 루트 기준이다.
   | 대상 | 명령 | 종료 코드 및 결과 | 로그 |
   | --- | --- | --- | --- |
   | 시험 커밋, 제품은 base_commit | `app/.build/app-tests --bubble-width` | 1, 수락 시험 2판에 정해진 재현·보존 분류와 전부 일치 | `.build/bubble-width/baseline.log` |
   | 기준본 회귀 | `bash scripts/test.sh` 첫 시도 | 1, `hermes_facility` import 경로 누락으로 1건 실패. 기존 팀 키트 라이브러리 경로를 시험 환경에 추가 | `.build/bubble-width/baseline-regression.log` |
   | 기준본 회귀 | Hermes 시험 venv로 `python -m pytest gate/tests tests/acceptance -q -o asyncio_default_fixture_loop_scope=function -p no:cacheprovider` 및 `python -m gate.tests.gateway_delivery` | 0, 594개 통과, 게이트웨이 정상 종료 | `.build/bubble-width/baseline-gate.log` |
   | 시험 커밋, 제품은 base_commit | `bash app/scripts/test.sh` | 0, 앱 회귀 통과 | `.build/bubble-width/baseline-app.log` |
   | 수정본 | `bash .build/bubble-width/compile-tests.sh`, `.build/bubble-width/app-tests --bubble-width` | 0, AT-BW-01~06·10 하위 관측 34개 통과. 목록 폭 700 → 1000 → 520pt에서 양쪽 말풍선 각각 456.75 → 681.75 → 321.75pt | `.build/bubble-width/compile-tests.log`, `.build/bubble-width/acceptance.log` |
   | 수정본 AT-BW-07 | `grep -rn "bubbleWidth\|bubbleWidthFraction\|minimumBubbleWidth" app/Sources` | 0, 정의 둘과 식 한 줄 | `.build/bubble-width/width-source.log` |
   | 최종 커밋 AT-BW-08 | `bash scripts/test.sh` | 0, 594개 통과, 게이트웨이 정상 종료, 앱 빌드·회귀·전송·AT-WJ 통과. 기존 컴파일 경고와 pytest 경고 유지 | `.build/bubble-width/regression.log` |
   | 최종 커밋 AT-BW-08 | Hermes 실행 venv로 `python scripts/scan_private.py` | 0, 임시 홈과 가짜 명부로 통과 | `.build/bubble-width/private.log` |
   | 최종 커밋 AT-BW-09 | `.build/bubble-width/app-tests --bubble-width-capture .build/bubble-width/bubble-width.png` | 0, PNG에서 짧은 줄 글 두 개는 197·352pt, 긴 글 두 개는 각각 465pt 확인 | `.build/bubble-width/screenshot.log`, `.build/bubble-width/bubble-width.png` |

   AT-BW-07 관측

   ```text
   app/Sources/NativeThreadCard.swift:304:                let maximum = min(columnWidth, max(ChatMetrics.minimumBubbleWidth, columnWidth * ChatMetrics.bubbleWidthFraction))
   app/Sources/ChatStyle.swift:54:    static let minimumBubbleWidth: CGFloat = 240
   app/Sources/ChatStyle.swift:55:    static let bubbleWidthFraction: CGFloat = 0.75
   ```

10. **미검증 범위** · 설치 앱 확인은 별도 릴리스 단계다. 현재 명세 반영은 TASK-02에서 진행한다.
11. **범위 밖 기술 부채** · 이번 회귀에서 새로 확인한 사항 없음.
12. **독립 검토 지점** · 글 줄 조각의 자동 줄바꿈 판정과 최대 폭 고정 조건, 작성 종료 시 폭은 즉시 풀고 높이만 완화하는 경계, AT-BW-10의 실제 표시 중인 텍스트 뷰 관측을 검토한다.
13. **검토 대상** · 공개 worktree는 이 작업 문서를 둔 체크아웃 기준 `../.worktrees/hejo-bubble-width-public-20261126`, 브랜치는 `hejo-bubble-width-public-20261126`. 시험 커밋 `aeb60c7defda19596fc5dfe03e4b4948c2fde30c`, 수정·최종 검증 커밋 `8095aa46ff0d728d5919a673c33a7438056b7e2d`. 작업 트리 깨끗함. `github/main` 원격 확인 결과는 착수 기준 해시와 같다.
