[설계 인계: HEJO-TIDY TASK-04 / hejo 0.2.9 릴리스 준비(게시는 사장)]

**칸·원본·쓰기 주체·수명:** [design.md 1절](design.md). 정비 격납고(`install/hejo-ship`, `install/hejo-publish`)이고, 준비는 운영자(구현 담당), 게시는 사장이 한다.

0. **기준**
   - base_commit: 공개 `github/main` `4443ff2ef8558420496996d5cd0a49513f2a1996`(푸시 3 반영, 2026-11-26 `ls-remote` 확인).
   - `refs/heads/public`은 지금 `570c611f11fb531a8a98eff9823348ea5c0d9f37`(태그 v0.2.8)이다. `4443ff2`의 조상임을 확인했다.
   - 문서: spec 3판 REQ-TIDY-06, design D-08, 수락 시험 AT-TIDY-14. 절차 원본은 `docs/changes/HEJO-RELEASE-20261125/handoff.md` v1·v2.
1. **요구:** REQ-TIDY-06 AC-01·02. AC-03(게시 뒤 관측)과 M-01은 사장 게시 뒤 계획 담당이 확인한다.
2. **할 일**
   1. 공개 worktree `../.worktrees/hejo-tidy-public-20261126`(HEAD `4443ff2`)에서 시작한다.
      - `git ls-remote github refs/heads/main`이 `4443ff2`인지 확인한다. 다르면 멈추고 보고한다.
   2. 버전 커밋 R을 만든다.
      - `app/Resources/Info.plist`: `CFBundleShortVersionString` `0.2.8`→`0.2.9`, `CFBundleVersion` `10`→`11`.
      - `tests/acceptance/test_ship.py` 218행 단언: `'0.2.8'`·`'10'`→`'0.2.9'`·`'11'`.
      - 이 두 파일만 바꾼다. 커밋 메시지는 `hejo 0.2.9`.
      - 과거 문서의 버전 표기는 바꾸지 않는다.
   3. R을 시험한다.
      - `bash scripts/test.sh`(기존 실패 `test_at_hf_08[True]`만 허용, 4443ff2 대비 JUnit 비교).
      - `bash app/scripts/test.sh`.
      - 런타임 Python `scan_private`.
      - `pytest tests/acceptance/test_ship.py`.
   4. `git update-ref refs/heads/public R 570c611f11fb531a8a98eff9823348ea5c0d9f37`을 실행한다. 이전 값이 다르면 멈추고 보고한다.
   5. 작업 트리가 깨끗한 상태에서 `bash app/scripts/build.sh`로 배포 빌드한다.
      - Google OAuth 비밀은 기존 빌드와 같은 방식으로 주입하고, 값을 출력·기록하지 않는다.
      - `BuildInfo.json`의 tree가 R의 트리이고 dirty가 false인지 확인한다.
   6. `install/hejo-ship prepare --output <공개 worktree>/.build/ship-0.2.9`를 실행한다.
      - 키체인 서명 허가 창이 뜨면, 사용자 승인이 필요하다고 보고하고 기다린다.
      - 키체인 도구의 출력·비밀은 기록하지 않는다.
   7. AT-TIDY-14 확인:
      - `git diff --name-only R^ R` = 두 파일.
      - `codesign --verify --deep --strict` 0.
      - 출력 폴더에 zip과 `prepared.json` 정확히 둘.
      - `prepared.json` commit = R, version 0.2.9, build 11, sha256 = `shasum -a 256 <zip>`.
3. **유지할 계약:** 버전 두 값 외에 제품·시험·문서는 바뀌지 않는다. 기존 태그·릴리스는 건드리지 않는다.
4. **위험도·증거:** 일반. 로컬 준비만 하고 원격 쓰기는 0이다. 증거 수준 1·3(실제 서명 도구 실행).
5. **결과물**
   - 개발 main `impl-report.md` "TASK-04" 절(`git commit --only`)에 남길 것: 명령·종료 코드·로그 경로, R 전체 해시, `prepared.json` 경로와 commit·version·build·archive·sha256.
   - 증거는 `.build/tidy/task04/`.
6. **금지:** git push(R은 푸시 4 대상으로 보고만 한다), `hejo-ship publish`, `gh release`·태그 생성 등 원격 쓰기, 앱 설치, 서버 쓰기, rebase·force, 다른 체크아웃 변경.
7. **병렬 갈래:** 없음(순차 절차 1개).
8. **다음(계획 담당):**
   - R 검증 → 푸시 4(R) 사용자 승인.
   - 사장이 `install/hejo-ship publish --approve-commit R`로 게시.
   - AT-TIDY-14b(릴리스 자산 확인).
   - M-01(서버 Mac·맥북 실물).
   - TASK-07.
