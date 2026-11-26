# [설계 인계: HEJO-WAIT-JITTER TASK-01 / 답 기다릴 때 화면 흔들림]

0. **기준**: base_commit = 착수 시 `github/main` tip(HEJO-AUTOLOAD TASK-01 커밋 포함이어야 함, 아래 착수 조건). 설계 작성 때 본 공개판은 `38885c6`. spec 5판·design 2판(계획 검증 1~4회차 반영, plan-review.md) / 작성 2026-11-25 / 승인: 사용자가 방식·범위·순서 결정(tasks D-01·D-02), 계획 검증 2회차 대기 / 운영 모드: 교차 모델(+계획 검증).
   - **착수 조건 2(차단, 2026-11-26 사용자 결정 D-03)**: `github/main`에 HEJO-OWNER-PROFILE 앱 변경(`f116bdc`)도 들어 있어야 한다. 확인: `git merge-base --is-ancestor f116bdc github/main` 종료 0(병합에서 함수 이름은 `outgoingReplyAnchor`로 남았으므로 이름 검색은 쓰지 않는다). 2026-11-26 계획 담당 확인: `github/main` `2237bf5af5773aeb50c72be7c3d8945ec391cc17`에 `f116bdc`·`7540da1` 모두 포함, `keep` 지연 4회 구조 유지. 없으면 아무것도 바꾸지 말고 `result`(보류: OWNER-PROFILE 미반영)로 보고한다.
   - **착수 조건(차단)**: `git fetch github` 뒤 `github/main`에 HEJO-AUTOLOAD TASK-01 앱 변경(`NativeThreadList.swift`의 `readerAnchor(allowAtEnd:)` 등, `docs/changes/HEJO-AUTOLOAD-20261125/verdict.md` 완료 판정)이 들어 있어야 한다. 없으면 아무것도 바꾸지 말고 `result`(보류: AUTOLOAD 미반영)로 보고한다.
   - 착수하면 그 tip의 전체 해시를 base_commit으로 impl-report에 적고, design 1절 현황이 그 커밋에서도 맞는지 확인한다. 기준점·지연 조정 구조가 design과 크게 다르면 멈추고 보고한다.
1. **공식 문서**: [spec.md](spec.md), [design.md](design.md), [tasks.md](tasks.md), [brainstorm.md](brainstorm.md), 수락 시험 `tests/acceptance/HEJO-WAIT-JITTER.md`, `docs/ARCHITECTURE.md`. 참고: `docs/changes/HEJO-AUTOLOAD-20261125/`(같은 파일 앞선 변경).
2. **요구와 수락 기준**: REQ-WJ-01(대화 목록 구간별 되튐 없음, AC-01~04), REQ-WJ-02(왼쪽 목록, AC-01~02), REQ-WJ-03(진단 기록·판정식, AC-01~02), REQ-WJ-04(설치 앱 실물, AC-01). 최종 위치 규칙은 그대로, 중간 왕복만 없앤다.
3. **유지할 계약**: AT91 전체, AT-ALD 전체, `HejoSmoothTests`, 게이트 프로토콜·스키마 무변경, 진단 환경 변수 이름 `HEJO_THREE_TAP_TRACE`와 기존 진단 줄 형식(새 줄 종류만 추가).
4. **책임·흐름**: 대화 목록 스크롤 원점은 `NativeThreadList`만 옮긴다. 새 갱신·리더 입력·`scrollTo`·진입이 이전 지연 조정을 무효화하고, 한 갱신의 기준(글/끝)은 그 갱신 안에서 고정. 왼쪽 목록은 `ConversationView.updateSidebarRows`가 책임.
5. **기존 경로 판정**: design 4절. `keep` 지연 재적용은 통합(무효화 규칙 하나), 나머지 유지. 대체한 경로는 같은 변경에서 지운다.
6. **위험도·증거**: 일반. 하네스 증거 수준 3, AT-WJ-09는 4. 앱만 바뀌므로 게이트웨이 재시작 없음.
   - **설치 대상 두 곳**: (A) `/Applications/hejo.app`, (B) Mac 공용 폴더 `Shared/hejo`의 `hejo.app`.
   - **보관**: 설치 전에 실행 중인 hejo를 종료하고, A·B 각각을 `ditto`로 `.build/wait-jitter/rollback/A/hejo.app`, `.build/wait-jitter/rollback/B/hejo.app`에 복사한다. 각 원본과 사본의 `Contents/MacOS/hejo`·`Contents/Info.plist` SHA-256과 버전을 `rollback/manifest.txt`에 적고 원본=사본을 확인한 뒤에만 설치를 시작한다. 한쪽이라도 보관·확인에 실패하면 설치하지 않는다.
   - **설치**: A, B 순서로 각각 새 빌드를 `ditto`로 임시 이름에 복사한 뒤 교체하고, 교체 뒤 해시가 새 빌드와 같은지 대상마다 확인한다.
   - **복원**: 어느 단계에서 실패하든(부분 설치 포함), 또는 AT-WJ-09 실패·앱 이상 시, 이미 바뀐 대상마다 자기 보관본으로 되돌리고 manifest의 원래 해시와 같은지 대상마다 확인한다. 바뀌지 않은 대상은 건드리지 않는다. 그 뒤 A를 실행해 뜨는지 확인하고 impl-report에 대상별 결과를 적는다.
7. **변경 성격**: 의미 변경(작음). 비교: 기준 커밋에서 AT-WJ 하네스를 먼저 돌려 실패(왕복) 수치와 "기존 규칙 결과" 위치를 로그로 남기고, 수정 뒤 같은 하네스로 비교.
8. **수락 시험**: AT-WJ-01~09(05a·b·c, 08b 포함, `tests/acceptance/HEJO-WAIT-JITTER.md` 5판). 기대값 출처: spec 용어 정의, 기준 커밋에서 따로 잰 구간별 목표 위치 로그(수정본에서 다시 만들지 않음), 실물 분석은 사용자 원본 영상 양성 대조. 상태: 명세 확정 / 코드 미작성 / 실행 전 / 독립 검토는 계획 검증.
9. **작업 범위·순서**
   1. 공개 worktree를 착수 tip에서 만든다: `../.worktrees/hejo-wait-jitter-public-20261125`, 브랜치 `hejo-wait-jitter-public-20261125`. 증거는 그 worktree의 `.build/wait-jitter/`.
   2. 기준 커밋에서 AT-WJ-01~07 하네스를 먼저 돌려 목표 위치 로그와 기준 결과를 남긴다(되튐을 재현하지 못하면 멈추고 보고). 그다음 진단 기록(REQ-WJ-03)을 넣는다. 실제 앱에서도 진단을 켜고 답 대기를 한 번 재현해 기록을 남긴다(사용자 Slack·고객 메시지 금지, hejo 안에서 직원에게 묻는 것만).
   3. impl-report에 원인을 기록 근거(이동 이유·순서)와 함께 적는다. 원인이 design 2절 범위(두 파일) 밖이면 멈추고 보고.
   4. 원인 자리에서 수정, AT-WJ 하네스 코드화(`app/Tests/`, `app/scripts/test.sh`에 연결), 회귀 실행.
   5. 공개 worktree에 커밋(`git commit --only`로 자기 경로만). `bash app/scripts/build.sh`로 빌드, 6절의 대상별 보관·설치·확인 절차로 A·B 설치, AT-WJ-09 수행(화면 기록·진단 로그·분석 스크립트·결과를 `.build/wait-jitter/`에, 커밋하지 않음).
   - 검사: `bash scripts/test.sh`(Hermes 시험 venv 필요, 실패 목록을 기준 커밋과 비교), `python3 scripts/scan_private.py`(Hermes 실행 venv의 python).
   - 금지: 개발 `main`·planner checkout 수정, 게이트·스키마·설치 스크립트 변경, `~/.hermes` 설정·재시작·비밀 파일, git push, 기존 시험 기대값 변경, CPU 개선 등 범위 밖 정리.
   - 선행: HEJO-AUTOLOAD TASK-01 반영.
   - 병렬 갈래: 없음(갈래 3개 미만: TASK-01 하나, 원인 확정 전 수정 갈래 분할 불가).
10. **가정·미확정**: 원인은 [가정](design 1절). 계측 결과가 가정과 달라도 범위(두 파일) 안이면 그 원인을 고친다. 범위 밖이면 차단.
11. **사용자 확인**: 방식·범위·순서 사용자 결정(tasks D-01·D-02). 사전 위임 없음.

## 인계 전 점검
- 2판: 계획 검증 1회차 지적 WJ-01~06 반영. 3판(spec·시험): 2회차 WJ-07 반영 — 사건 순번·서명·벽시계 시각 기록, 관측값 판정식, 휠 두 번으로 영상-기록 시각 맞춤. 4판: 3회차 WJ-08 반영 — 사건 경계를 넘는 결함을 잡는 설명 조건(대화·왼쪽), 판정식 다섯 값, 경계 횡단 결함·정상 대조 사례(AT-WJ-08b). 5판: 4회차 WJ-09 반영 — 따라가기 판정을 목표 거리 Fk 기준으로, 부분 이동 정상·역방향/넘침 결함 대조 추가(plan-review.md).
- base_commit은 착수 시 고정(착수 조건). design 1절 현황은 `38885c6` 기준으로 확인했고 AUTOLOAD 반영 뒤 재확인이 착수 조건에 포함됨.
- G1~G4: 요구·AC·시험·작업 연결 완료. G3 독립 검토는 계획 검증으로 진행.
