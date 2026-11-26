## 검증 판정: HEJO-BUBBLE-WIDTH-20261126 TASK-01 / 말풍선 최대 폭 75%와 폭 맞춤

1. **판정: 완료** (2026-11-26)
2. **검증 조건:** 교차 모델(설계·검증과 구현이 다른 모델, 다른 대화). 설계를 한 대화가 검증했으므로 인계서·수락 시험·변경 코드를 처음부터 다시 읽었다. 검토한 코드 상태: 공개 worktree `../.worktrees/hejo-bubble-width-public-20261126`, 브랜치 `hejo-bubble-width-public-20261126`, 시험 커밋 `aeb60c7defda19596fc5dfe03e4b4948c2fde30c`, 제품 커밋 `8095aa46ff0d728d5919a673c33a7438056b7e2d`(기준 `2dea766cbdbd5e179a6269aabbfefc750036b219`, 작업 트리 깨끗함).
3. **설계 적합성(4.2):** 적합.
   - 설계가 요구를 충족하는가: 최대 폭 식이 글 칸 기준 한 곳이라 내 글과 직원 글의 반대쪽 여백이 식으로 같다(REQ-BW-01). 자동 줄바꿈·표·코드 상자·왼쪽 정렬 아닌 문단이 없을 때만 좁히고, 좁힌 폭에서 다시 배치해 높이와 오른쪽 끝을 확인한 뒤에만 그 폭을 쓴다(REQ-BW-02). 사용자가 본 시안과 같은 모양을 실제 카드 그림으로 확인했다.
   - 구현이 설계대로인가: 숫자는 `ChatStyle.swift:54-55`, 식은 `NativeThreadCard.swift:304` 한 줄. `Content.bubbleWidth`와 `ConversationView`의 영역 × 0.82 계산, 시험 호출부 인자가 모두 지워졌다. `TextLayout.swift`·`AppearancePreview.swift`는 바뀌지 않았다. 써지는 중 폭은 높이와 같은 기억(`streamMeasurements`)에 두고 글씨 크기 변경 때 같이 비운다.
   - 설계와 달라진 점: 없음.
4. **직접 확인한 것** (증거 수준 2, 앱 시험 하네스)
   - 변경 전체 diff(`git diff 2dea766 8095aa4`) 9개 파일을 읽었다. 보고에 없는 변경은 없다. 기존 시험은 `bubbleWidth` 인자 제거와 `richBody`·`assertRichBody` 공개 범위 변경뿐이고 기대값은 그대로다.
   - 수락 시험 코드(`app/Tests/BubbleWidthTests.swift`)를 2판 명세와 대조했다. 기대값은 시험 안의 독립 식(`min(C, max(240, 0.75 × C))`)과 따로 잰 줄 폭에서 나오며 제품 상수를 가져오지 않는다.
   - 직접 실행: `app/.build/app-tests --bubble-width` 종료 0, 하위 관측 34개 PASS. AT-BW-10 관측 폭 456.75 / 681.75 / 321.75(목록 폭 700 / 1000 / 520, `show` 한 번).
   - 직접 실행: `--bubble-width-capture` 종료 0, 말풍선 폭 197 / 352 / 465 / 465. PNG를 눈으로 확인했고 시안 오른쪽과 같다(AT-BW-09).
   - 직접 실행(AT-BW-07): `grep -rn "bubbleWidth\|bubbleWidthFraction\|minimumBubbleWidth" app/Sources` → 정의 2줄과 식 1줄뿐.
   - 추가 확인(버리는 사본에서 별도 빌드): 실제 글 그리기 경로(`MessageFormat.renderNative` + `TextLayout.apply`)로 만든 제목·목록·굵은 글·인라인 코드·인용·번호 목록·링크 글 5종을 내 글·직원 글로 배치했다. 좁힌 글은 줄 수와 높이가 최대 폭에서 잰 값과 같고 글 뷰 밖으로 넘치지 않았다. 자동 줄바꿈이 있는 목록 글은 615.75(= B)였다.
   - 구현 담당 로그를 읽어 확인: 기준본 `baseline.log`는 재현 22건 실패·보존 12건 통과로 2판 "기준본 기대" 열과 같다. `regression.log`(최종 커밋 `bash scripts/test.sh`)는 종료 0, pytest 594 통과, `APP_TEST_OK`, AT-BW 실패 줄 없음. `private.log` 종료 0. 코드가 그 뒤 바뀌지 않아 전체 회귀는 다시 돌리지 않았다.
5. **지적:** 차단 없음. 비차단 없음. 기술 부채 없음.
6. **기획설계로 넘긴 것:** 없음.
7. **미검증 범위와 남은 위험**
   - 설치된 앱에서의 확인은 하지 않았다. 새 앱 버전 배포는 범위 밖 별도 릴리스 작업이고, 그 전에는 설치된 앱 화면이 바뀌지 않는다.
   - 써지는 중인 글의 측정 비용은 따로 재지 않았다. 기존 성능·흔들림 회귀(AT-WJ 등)가 통과한 것으로만 확인했다.
8. **미완료 원인 분류:** 해당 없음.
9. **현재 명세 반영 요청:** REQ-BW-01~03을 공개판 `docs/spec/current/hejo-owner-profile.md` "앱 화면"에 반영한다(TASK-02).

## TASK-02 현재 명세 반영 (2026-11-26, 기획설계)

- 공개 worktree에 문서 커밋을 추가했다: `docs/spec/current/hejo-owner-profile.md` "앱 화면"에 최대 폭·폭 맞춤·써지는 중 폭 규칙 한 항목, 이 작업 문서 폴더, `tests/acceptance/HEJO-BUBBLE-WIDTH.md`.
- 제품·시험 코드는 건드리지 않았다. 문서 커밋 뒤 개인값 검사를 다시 돌렸다(결과는 상태 보고의 checks).
- 푸시 대상은 그 문서 커밋이며 `github/main`(`2dea766`)의 fast-forward다. 푸시는 사용자 승인 대기다.
