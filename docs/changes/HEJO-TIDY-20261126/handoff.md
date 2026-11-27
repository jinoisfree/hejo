[설계 인계: HEJO-TIDY TASK-01 / 공개 통합(DISCORD-SECTIONS + TELEGRAM-REMOVE)]

0. **기준**
   - base_commit: 공개 `github/main` `425d5650a1ab520ac9746c7f26a4a26299c80a48`, 개발 main `4ab06ca9d2946965ddea2243d37ba6fc9867a83d`.
   - 문서: spec·design 2판(계획 검증 1회차 반영), 작성 2026-11-26.
   - 승인: 사용자가 범위를 정했고(브레인스토밍), 계획 검증 대기 중이다.
   - 운영 모드: 연합개발(교차 모델).
1. **공식 문서**
   - 이 작업: [spec](spec.md), [design](design.md), [tasks](tasks.md), [수락 시험](../../../tests/acceptance/HEJO-TIDY.md).
   - 통합할 두 작업:
     - HEJO-DISCORD-SECTIONS: verdict 6차, 수락 시험 6판(`tests/acceptance/HEJO-DISCORD-SECTIONS.md`).
     - HEJO-TELEGRAM-REMOVE: verdict 11회, 수락 시험 5판, `handoff-task04.md` 2판.
     - HEJO-OWNER-PROFILE AT-OP-10·14 개정판.
2. **요구와 수락 기준**
   - REQ-TIDY-01 AC-01~04.
   - 정상: 두 후보를 모두 품은 통합 커밋이 원격 tip의 fast-forward 자손이다.
   - 핵심 실패: 어느 한쪽의 승인 동작이 사라지면 멈춘다.
3. **유지할 계약**
   - 두 작업의 수락 시험 기대값.
   - 규격 `schemas/hejo-wire-v1.json`: spec REQ-TIDY-01 AC-01a의 세 비교를 따른다.
     - 병합 1: 첫 부모 T0 대비 `discord_layout` 추가만.
     - 병합 2: 첫 부모 M1에서 텔레그램 6종과 참조만 뺀 값.
     - 최종: T0 대비 합성 차이만.
     - AT-HTR-04의 "원격 tip"은 병합 2에서 M1로 읽는다.
   - OWNER-PROFILE의 `owner_label`, 사장 프로필 Discord 경로.
4. **책임과 흐름**
   - 새 공개 worktree `../.worktrees/hejo-tidy-public-20261126`(브랜치 같은 이름, 시작 `github/main`)을 쓴다.
   - `a6d5e9a`를 merge한 뒤 `1ca2cbb`를 merge한다.
   - 증거는 worktree의 `.build/tidy/task01/`에 둔다.
5. **기존 경로 판정**
   - 두 후보 브랜치: 통합(이 worktree가 권위 경로).
   - `hejo-smooth2-public-20261125`: 대상 아님. 이미 반영됐다.
   - 기존 후보 worktree는 고치지 않는다.
6. **위험도와 증거**
   - 위험도 일반. 근거: 공개 푸시, 여러 모듈.
   - 필요한 증거 수준: 2.
   - 서버·설치 앱 변경은 없다.
7. **변경 성격**
   - 통합만 한다(새 의미 변경 없음).
   - 비교 방법: AT-TIDY-03 기준선 JUnit 비교, AT-TIDY-02a 규격 세 비교(병합 1 첫 부모, 병합 2 첫 부모, T0 대비 최종 합성), 최종 트리에서 AT-HTR-04 상시 검사와 AT-DK-22 6판 구조 검사.
8. **수락 시험**
   - AT-TIDY-01~03과 02a(`tests/acceptance/HEJO-TIDY.md` 2판).
   - 상태: 명세 확정, 코드는 기존 시험을 쓴다, 미실행, 독립 검토는 계획 검증 대기.
9. **작업 범위**
   - 할 일:
     - 위 두 merge와 충돌 해결(design D-01 규칙).
     - AT-SM-02 해시 갱신.
     - 두 작업 문서 중 공개판에 들어가는 현재 명세의 충돌만 해결.
     - 시험 실행, `impl-report.md`에 "TASK-01" 절 작성.
   - 금지:
     - 새 기능, 코드 정리, rebase·force.
     - git push(푸시는 사용자 승인으로 플러그인이 한다).
     - 서버 `~/.hermes` 쓰기, 앱 설치.
     - 기존 후보 worktree 수정.
   - 선행 작업: 없음.
   - 병렬 갈래: 없음(갈래 3개 미만. 두 merge가 같은 파일 `gate/server.py`·`TestMain.swift`를 순서대로 바꾼다).
   - 시험 환경:
     - 짧은 `/tmp` `HERMES_HOME`·`--basetemp`를 쓴다(HEJO-TELEGRAM-REMOVE `task04b-merge/run-check.sh` 방식).
     - pytest는 Hermes test-environment venv + runtime workspace `PYTHONPATH`, `scan_private`는 runtime venv Python으로 돌린다.
     - AT-CS-02가 실패하면 같은 실행기로 한 번 다시 돌리고, 두 결과를 모두 적는다(TD-1).
10. **가정·미확정**
    - [가정] 원격이 TASK-01 중에 다시 움직일 수 있다. 끝에 `git ls-remote`로 확인하고, 움직였으면 한 번 더 merge·재시험한다.
    - 착수를 막는 미확정 사항: 없음.
11. **사용자 확인:** 브레인스토밍에서 범위·순서를 결정했다. 푸시는 사용자가 화면에서 승인한다.

[인계 전 점검]
- base 호환: [확인] 원격 tip `425d565`. 두 후보 모두 `f8d91c5` 위에 있고, `425d565`는 `f8d91c5`의 자손이다(ALERT-SEEN만 추가).
- G1~G4: 명세·설계·시험 연결 완료. 계획 검증 결과를 기다린다.

---

TASK-03 이후는 TASK-02 푸시가 끝난 뒤 `handoff-task03.md`로 따로 인계한다. 설계는 design.md 2절 D-02~D-06에 고정돼 있다.
