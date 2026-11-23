# TASK-04A-R1 — 수집 경계·신규 설치 보완

현재 대화의 직접 구현·자체 점검, 증거 수준2. 승인된 외부 격리 브랜치 `notion-distribution-c704553b`의 기존7파일 범위를 유지했다. 이번 delta는 sync와 tests/test_sync.py, tests/test_starter_runtime.py의3파일이다. [최종7파일 해시](logs/task04a-r1/candidate-hashes.json), [실행 결과](logs/task04a-r1/checks.json).

## 수정과 직접 검증

- V-HNA-04A-01: open에 O_NONBLOCK을 추가하고 descriptor fstat의 regular-file 거부를 유지했다. source/target FIFO 각각 실제 subprocess의5초 제한 안에 code-not-file로 실패하며 모든 일반 파일의 바이트·모드·mtime가 유지된다. 전체 pytest 종료0,134 passed. 실패를 timeout으로 통과시키는 시험이 아니다.
- AT-HNA-DIST-01: 임시 Git 저장소에서 staged 파일과 별도 unstaged 바이트를 만든 뒤 dry-run/실제 한정 수집 전후 index 바이트·mtime 및 비대상 편집 보존을 확인했다. fixture 밖 실제 수집은 하지 않았다.
- V-HNA-04A-02: 실제 modern_main의 --agents 신규 경로와 실제 config_assembly를 실행했다. 빈 임시 홈2개는 서로 다른 기본 직원과 별도 runtime 선택 경로를 가진다. 설치→영수증→--check→CLI 및 재설치 시 가짜 금고 보존을 확인했다. 별도 통합에서는 동일 신규 설치 fixture 뒤 실제 hejo TeamKit apps 호출까지 두 홈 모두 통과했다. receipt/default와 응답 home/인자를 직접 단언한다.

두 runtime 경로는 동일 검증 Python을 가리킨다. 가짜 connections 모듈은 요청/홈을 반환할 뿐이며 실제 Notion 계정·권한·API를 검증하지 않는다. 신규 설치의 JSON 설정 경로를 검증했으며 모든 OS·공식 runtime 다운로드·UI·실제 사용자 환경 성공으로 확대하지 않는다. 이전 충돌/롤백 시험을 포함한 관련3파일134시험을 변경 영향 때문에 재실행했다. 로그는 logs/task04a-r1/에 있다. 최종 git diff --check 종료0. 커밋은 없다.

## 공개 입력 목록과 남은 경계

[입력 목록](logs/task04a-r1/input-inventory.json)은 읽기로 확정했다. 설치13파일은 수락 해시와 모두 일치하며 제품11파일과 회귀2파일로 구분된다. 추가 수락 시험5파일은 기존 격리 후보 해시와 일치한다. 각 파일의 수집 사본 존재 여부·해시·모드도 기록했다. 관련 의존 코드14개와 manifest 관련5항목을 대조했다. 이 목록은 전체 transitive import closure의 검증 완료를 뜻하지 않는다.

공개 생성기는 tests를 제외하므로 개발 회귀2+추가5시험의 보존과 사용자 배포 제품11파일을 분리한다. 후보 시험은 개발 증거로 보존하며 배포 제품에 억지로 넣지 않는다. 없는 수집 파일을 현재 collect_code로 생성할 수 있다고 가정하지 않는다. CLI 템플릿은 commands를 거쳐 로컬 bin에 설치하고 연결 로직은 기존 라이브러리를 호출한다.

V-HNA-04A-03은 남아 있다. 실제 최종 제품/공유 라이브러리 전체를 사용하는 임시 공개 입력 구성과 생성→신규 설치→실제 connections import/apps 통합이 다음 검증 범위다. 입력 목록을 근거로 기존 생성기의 허용/치환 규칙을 적용해야 하며 공개 checkout을 직접 편집하거나 운영 수집을 먼저 실행하지 않는다. 이번에는 입력 복사·생성기·prepare/publish를 실행하지 않았다.

## 설계 적합성과 상태

기존 수집/설치 책임 안의 한정 수정으로 설계 적합성은 유지한다. FIFO 구현 오류와 index 시험 누락을 해소했고 신규 설치 호출 연결의 시험 공백을 보완했다. 전체 판정은 부분 완료·자체 점검이다. 공개 실제 입력 통합, 고위험 독립 최종 검토, 미래 하위 실제 발견·기존 연결 보존 구분·다른 사용자 실환경·배포/Git이 남는다.

정상 Notion 연결·서비스·본체·운영 수집·공개판·자격은 변경하지 않았다. 커밋·푸시도 하지 않았다. 과거 사용자 저장 전 상태로 롤백하지 않는다.
