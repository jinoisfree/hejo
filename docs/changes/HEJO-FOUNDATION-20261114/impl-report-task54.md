# TASK-54 — 보완 69 구현 인계

1. **받은 설계:** [handoff.md](handoff.md) 보완 69, [spec.md](spec.md) REQ-HF-32.AC-05, [verdict.md](verdict.md) TASK-54 1차의 V54-01 해소 지시. 연합개발, 위험도 일반, 필요/도달 증거 수준 **2/2**. 착수 때 `git merge --ff-only main`이 종료 0으로 성공하여 기준은 `d56f42863508a1a986602008107ec783ee8bc794`에서 `d5c9133e12cc51b35efaa306f3263034f1a28d73`으로 전진했다. 보고 위치 정정과 보완 68 커밋을 그대로 포함하며 그 파일들은 수정하지 않았다.
2. **구현자 판단:** 구현·자체 시험 완료, 계획 담당 검토 대기. 최종 수락·푸시 완료 판정은 하지 않는다.
3. **변경 후 구조:** `ConnectionsModel.searchText`·`connectedOnly`가 메모리 원본이고 `visibleGroups` 한 곳이 검색·연결 상태 필터·이름순 정렬·빈 묶음 제거를 계산한다. 화면은 그 결과를 그리고 모델 값에 직접 바인딩한다. 디스크 저장이나 서버 설정·요청 변경은 없다.
4. **더한 것/뺀 것:** `app/Sources/ConnectionsWindow.swift`의 기존 뷰 내부 묶음별 필터와 묶음 정의를 모델 계산으로 교체했다. 요약 아래 검색칸과 체크박스, 전체 빈 안내를 더했고 상세 화면에서는 숨긴다. 검색칸·체크박스의 접근성 이름은 각각 `연결 검색`·`연결된 것만`이다. `app/Tests/ConnectionsTests.swift`에 AT-101과 기존 `--task32-capture` 경로의 사진 두 장을 더했다. `TestMain.swift`는 바꾸지 않았다. 보고서는 이 파일로 분리하고 `tasks.md`의 TASK-54 상태만 갱신한다.
5. **설계와 달라진 점:** 기능·계약·수락 기준의 차이는 없다. 허용된 입력 순서 중 동명 연결 `c`를 `a`보다 먼저 넣어 id 동률 정렬도 실제로 검출한다. 사진에서 투명 배경 때문에 글자가 보이지 않는 문제는 캡처용 호스팅 뷰에 창 배경색을 지정해 해결했다. 제품의 창 크기·상세·버튼·요약 계산은 유지했다.
6. **덧대기/임시 코드:** 대체된 뷰 필터는 제거했다. 제품에 임시 코드·새 저장 원본·동기화 경로를 남기지 않았다. 돌연변이는 추적하지 않는 `.build/task54/mutation/ConnectionsWindow.swift` 사본에만 적용했다.
7. **변경 성격:** 의미 변경. 문서 입력 순서 대신 `localizedStandardCompare` 이름 오름차순과 동률 id 순서를 적용한다. 비교 기대값은 인계서 8번 그대로이며 시험에서 literal로 단언한다.
8. **시험:** AT-101은 연결 10개로 묶음·이름순·동명 id 순서, 이름/id/service/account 검색, 대소문자와 앞뒤 공백, 빈 검색어, 설명 제외, 빈 묶음/전체 빈 결과, 연결됨 외 네 상태 제외, 검색과 연결 필터 교집합, 직원 전환 시 값 유지, 전체 요약 4·2·3과 요약 점 불변, 필터 요청 미전송을 검사한다. 기존 AT-HF-83은 유지한다. 정렬만 제거한 사본은 `AT-101 case-insensitive natural label order and equal-label id order` 단언에서 종료 1로 실패했다. 정상 사본은 같은 진입점에서 종료 0이다. 원본 파일에는 돌연변이를 적용하지 않았다.
9. **실행한 검증:** 직접 구현·자체 점검이며 하위 에이전트는 사용하지 않았다. 아래 모든 경로는 구현 worktree 기준이다.

   | 명령/대상 | 실제 결과 | 증거 |
   |---|---|---|
   | `git merge --ff-only main` | 종료 0, fast-forward | 위 기준 커밋과 Git 이력 |
   | `bash app/scripts/test.sh` | 종료 0, AT-HF-83·AT-101 및 통신·AT-HF-96·훅 9개 통과 | `.build/task54/app-test.log`, `.build/task54/app-test-result.json` |
   | `app/.build/app-tests --task32-capture .build/task54/screenshots` | 종료 0, AT-HF-83·AT-101 통과 | `.build/task54/capture.log`, `.build/task54/focused-results.json` |
   | 정렬 제거 사본 컴파일·서명 | 종료 0 | `.build/task54/run-mutation.sh --build-only`, `.build/task54/mutation-build.log` |
   | `app/.build/task54-mutant --task32-capture .build/task54/mutation/screenshots` | 종료 1, 지정 AT-101 단언 실패로 검출 | `.build/task54/mutation-test.log`, `.build/task54/focused-results.json` |
   | `"$HEJO_PYTHON" scripts/scan_private.py` | 종료 0 | `.build/task54/scan.log`, `.build/task54/scan-result.json` |

   최종 전체 시험은 임시 `HERMES_HOME`·`HERMES_ROOT`, 실제 사용 가능한 Hermes Python을 `HEJO_PYTHON`으로 지정하고 기존 검증의 모듈 경로를 재사용했다. 운영 Python이나 본체 파일을 변경하지 않았고 `PYTHONDONTWRITEBYTECODE=1`로 실행했다. 실제 CLI 설정의 lstat 메타데이터와 다운로드 폴더 이름 불변도 전체 시험 로그에서 확인했다.

   환경 준비 중 실패 두 번을 통과 근거와 분리했다. `.build/task54/app-test-missing-dependency.log`는 AT-HF-83·AT-101 통과 뒤 `aiohttp` 누락으로 전체 명령 종료 1, `.build/task54/app-test-missing-hermes.log`는 통신 시험 일부 통과 뒤 방 시험의 `hermes_cli` 경로 누락으로 종료 1이다. 처음 만든 로컬 시험용 venv만으로는 방 시험을 실행할 수 없어 기존 검증의 Hermes Python·경로를 채택했다. 필요한 import 사전 검사는 종료 0(`.build/task54/python-preflight.log`), 방 시험 사전 실행도 종료 0(`.build/task54/rooms-preflight.log`)이다. 최종 전체 명령은 같은 제품·수락 시험으로 통과했다. 범위 밖 Swift 파일의 컴파일 경고와 WebKit 진단 문구는 원문에 보존했으며 실패를 무시하거나 검사를 완화하지 않았다.
10. **화면 증거/미검증:** `.build/task54/screenshots/task54-hejo.png`를 직접 열어 검색 `google`, 체크 끔, Google AI Studio 두 줄만 표시, 계정과 서비스 제목, 요약 4·2·3을 확인했다. `task54-detail.png`는 연결 `c` 상세이며 검색칸·체크박스가 보이지 않는다. 사진은 760×560이며 최종 캡처 로그는 종료 0이다. 바인딩과 접근성 이름은 변경 코드를 직접 확인했다. 실제 손 조작·실서버 확인은 미실행이며 수준 2 증거를 그 확인으로 대신하지 않는다.
11. **범위 밖 부채:** 코드 변경이 필요한 새 부채는 발견하지 않았다. 시험 실행 환경의 의존성·모듈 경로 차이는 위 준비 기록에 남겼다.
12. **검토 요청:** 모델의 단일 계산과 뷰의 기존 경로 제거, 검색 대상 네 필드와 설명 제외, 요약 전체 기준 유지, 직접 바인딩·접근성, 최종 사진 두 장을 확인해 달라. 롤백은 이 보고서와 함께 생성되는 TASK-54 구현 커밋 하나의 revert다.
13. **검토 대상:** 브랜치 `role-workflow/3-d98f9311`의 이 보고서와 함께 커밋한 두 코드 파일 및 `tasks.md` 상태 행. 전체 커밋 해시는 인계 상태 블록에 기록한다. `impl-report.md`와 계획 담당 checkout은 수정하지 않았다. 푸시·운영 적용은 미실행이다.
