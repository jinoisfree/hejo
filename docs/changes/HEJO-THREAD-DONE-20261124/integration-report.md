# 공개 이력 통합 보고 — TASK-03

## 범위와 결과

- [확인] 사용자 승인과 [보완 인계](handoff.md)에 따라 `github`를 fetch했다. 공개 기준 tip은 인계서와 같은 `3b0006179eef606ba3f3bf1de5230e8338f9cea7`이다. 이 tip에서 브랜치 `role-workflow/34-09c749f7-public`과 별도 worktree를 만들었다. 실제 로컬 경로는 호스트 인계 기록에만 남긴다.
- [확인] 개발 구현 `f1cb67d3dfbd74f7479566db5b6cb5c6da53b065`를 `git cherry-pick --no-commit`으로 적용하고 제품·시험 5개 파일만 `git commit --only -C f1cb67d... -- <5개 파일>`로 커밋했다. 공개 제품 커밋은 `872ab0e1c0da7d2377d868f40e2ce2562387998f`이다.
- 충돌은 `app/Tests/TestMain.swift` 첫 실행 분기 하나였다. 공개본 전체를 유지한 상태에 `--thread-done` 분기만 추가했다. 제품 코드 두 줄은 자동 적용됐다. 의도·구조·계약·수락 기준·기대값 변경은 없다.
- 계획 담당의 작업 문서 7개와 `docs/spec/current/hejo-thread-status.md`를 내용 그대로 복사하고 이 보고서를 추가했다. HEJO-FOUNDATION spec은 상태 막대의 대체 표시 한 줄만 옮겼다. 문서 10개는 제품 커밋과 분리하여 `git commit --only`로 커밋한다. 이 보고서의 자기참조를 피하기 위해 최종 문서 커밋 해시는 호스트 인계·로컬 검증 기록에서 식별한다.
- 구현자 판단: 공개 이력 통합·지정 자체 시험 완료. 위험도 일반, 필요한 증거 수준 3, 실제 도달 수준 3(가짜 자료로 실제 앱 모델·AppKit 카드 조립 실행). 최종 검토 판정은 계획 담당에게 남는다.

## 검증 근거

아래 로그는 **공개 통합 worktree 기준** `.build/thread-done-integration-logs/`에 있다. 각 실행의 실제 argv·종료 코드·실행 시 HEAD는 같은 이름의 JSON에 기록했다. `HERMES_PYTHON`은 운영 Hermes 본체의 기존 `venv/bin/python`을 뜻하며, 비밀 파일·본체·venv를 수정하지 않았다. 개인 절대 경로는 공개 문서에 싣지 않는다. 빌드·앱 시험의 대상은 위 제품 커밋이며, 이후 문서 커밋에서 제품·시험 5파일이 그대로인지 별도 확인한다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| `HEJO_SKIP_GOOGLE_SECRET=1 bash app/scripts/build.sh` | 종료 0, BUILD_OK·앱 서명 검증 통과. 기존 Swift 경고는 범위 밖이다. | `build.log` |
| `bash .build/thread-done-tests.sh` | 종료 0. 공개 `app/scripts/test.sh`의 swiftc 방식(HEJO_PERF_TESTING 포함)으로 전체 Sources(AppMain 제외)·Tests를 컴파일하고 서명·검증했다. | `compile-tests.log` |
| `bash .build/thread-done-execute.sh` | 종료 0. 내부에서 임시 HERMES_HOME으로 `app/.build/app-tests --thread-done <빌드앱 Pet 리소스>` 실행. AT_TD_01_06_PASS·AT-HF-87 APP PASS·THREAD_TOOLS_UNIT_PASS·AT-HF-57 PASS·TYPING_AUTOMATIC_CAPTURES_OK·APP_TEST_OK. AT76이 속한 기존 ThreadTools·typing 시험도 통과했다. 설정·다운로드 메타데이터 보존 guard 통과. | `thread-done.log` |
| `python3 .build/thread-done-patch-check.py` | 종료 0. 제품 2파일의 원본/통합 patch-id 모두 `6afb57cd16acdcee2597bc63ab4c07976c14f07a`. ThreadDoneTests·ReadNoticeTests 내용 동일, 공개 TestMain에서 추가 분기만 제거하면 원본과 byte 단위 동일. | `patch-check.log` |
| `HERMES_PYTHON scripts/scan_private.py`(최종 문서 포함) | 종료 1. 기존 검출 30건, 신규 0건. 새 문서도 인덱스에 먼저 추가해 검사했다. | `scan-private-final.log` |
| `HERMES_PYTHON scripts/scan_private.py --repo .build/thread-done-public-baseline` | 종료 1. 공개 기준 tip의 별도 detached worktree에서도 동일 30건. | `scan-private-baseline.log` |
| `python3 .build/thread-done-scan-compare.py`(최종 검사 로그 비교) | 종료 0. 지적 위치·fingerprint 일치. 작업 문서 8개·현행 명세·FOUNDATION spec 총 10파일 모두 ls-files 검사 범위에 있고 해당 파일 검출 없음. | `scan-comparison-final.log` |
| `python3 .build/thread-done-scope-check.py` | 종료 0. 원본 문서 내용 동일, FOUNDATION 한 줄만 대체, 공개 기준 대비 변경은 허용된 제품·시험 5파일과 문서 10파일뿐. | `scope-check-final.log` |
| `git diff --check 3b0006179eef606ba3f3bf1de5230e8338f9cea7` | 종료 0. | `diff-check-final.log` |

전체 5파일 patch-id는 원본 `2c0c5d5833efb928ba0fa112d32a4c44aa148ba3`, 통합 `3acbec87e8f52cbeda9e0ee01586b061bf8baccf`로 다르다. 차이는 TestMain의 공개 시험 분기를 보존한 문맥이며 제품 patch-id는 같다. 원본 시험의 기대값은 바뀌지 않았다. TASK-01의 mutation은 제품 패치와 시험 내용의 동일성을 확인하여 재실행하지 않았다.

## 잔여 범위와 인계

- 개인값 전체 검사는 통과로 보고하지 않는다. 공개 기준 tip에서도 같은 30건이 재현됐으며 허용 목록·검사기·기대값을 완화하지 않았다.
- [미실행] 전체 Gate/설치·전체 앱 시험. TASK-03이 지정한 빌드·범위 시험만 실행했으며 이전 개발 이력의 전체 시험 실패를 공개 기준에서도 재현했다고 주장하지 않는다.
- [미실행] 운영 앱 설치, 실제 신고 스레드 화면 확인, 게이트웨이 재시작, 메시지 송신, 원격 쓰기·푸시. 제품 롤백은 제품 커밋 되돌리기다. 본체·ddots·운영 설정·다른 작업의 변경은 수정하지 않았다.
- 계획 담당은 공개 제품 커밋과 문서 후속 커밋, 이 보고서 및 로컬 로그를 검토하고 최종 판정 뒤 공개 `github/main`을 대상으로 푸시 승인 절차를 진행한다. 기존 verdict·tasks·현재 명세의 개발 커밋 표기는 복사 원문이며 공개 통합 판정으로 조용히 바꾸지 않았다. 병합·rebase·force·push는 실행하지 않았다.
