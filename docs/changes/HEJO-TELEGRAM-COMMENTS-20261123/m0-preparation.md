# M0 로컬 후보·복구 준비 결과

기존 봇·서버 방식의 [실행 전 인계](handoff-m0.md)에 따라 로컬 준비만 수행했다. 운영 적용과 실제 M0는 미승인이다. 채널·연결 그룹·시험 방은 사용자 준비 중이며, 단일 수신자·active 작업 0·중단 창·클라이언트 화면 확인 정보도 실행 전에 확정해야 한다.

## 고정 후보와 설치 범위

- 후보 전체 커밋: `6621b74e0b78d1012d761924d9a664b8259534c1`.
- 복구 원본 전체 커밋 및 관측한 공용 RELEASE: `0bcf63535df381e491c99af9cbef41179b7cd79f`.
- 후보와 복구는 각각 별도 로컬 Git 저장소다. 원격 연결을 제거했고 작업 트리는 깨끗하다. 공유 작업 트리/인덱스에서 커밋하지 않았다. 이 커밋은 M0 후보 고정용이며 제품 최종 완료나 푸시 승인을 뜻하지 않는다.
- 후보는 복구 커밋에서 검토 3회차의 네 gate 파일만 변경했다. 기준 구현 커밋과 복구 커밋 사이 gate/hub/schemas/config/install 차이가 없음을 확인했다. 네 파일 SHA-256은 검토 기록과 일치한다.
- `install/hejo-release`의 파일 범위에 따라 시험·캐시를 제외하고 현재 설치 42개 파일의 내용과 실행 속성을 복구 원본과 대조했다. 누락·추가·차이 없음. 후보의 실제 제품 차이는 `gate/adapter.py`, `gate/telegram.py`, `gate/telegram_comments.py` 세 파일이다. 새 시험 파일은 후보 커밋에는 포함되지만 설치에서는 제외된다. 배포 시 RELEASE 표식도 후보 커밋으로 갱신될 예정이다.
- 앱·hub·schema·config·설치 스크립트의 제품 변경은 없다. 별도 앱 작업은 후보에 포함하지 않았다. 현재 설치 및 공유 인덱스의 준비 전후 불변을 확인했다. 실행 직전에 다시 확인해야 한다.

공개 가능한 해시는 [m0-preparation.json](logs/m0-preparation.json)에 있다. 실제 CANDIDATE/RELEASE_DIR/ROLLBACK_SOURCE, 명령별 종료 코드·전체 출력·manifest는 추적 제외 `.build/telegram-comments/m0/preparation.json`과 `.build/telegram-comments/m0-private.md`에 고정했다. 기존 비공개 초안의 개별 gate 복사 제안은 최신 handoff-m0.md의 전체 설치 범위 대조 및 release 절차로 대체했다. 설치 범위가 일치하므로 그 절차를 사용할 수 있지만 아직 실행하지 않았다.

## 안전한 receipt 요약 준비

로컬 전용 `.build/telegram-comments/m0/receipt_summary.py`를 준비했다. 제품 후보에는 포함하지 않았다. 별도로 승인·수집된 일관 스냅샷의 `telegram.json`과 `sent.jsonl`만 읽고 저장소/게이트웨이를 import하거나 실행하지 않는다. 운영 홈 기본값과 네트워크 기능이 없다. 운영 금고·비밀 파일은 이번 준비에서 열지 않았다.

출력은 고정된 상태 열거, 예약/계약/현재 짝/사장 일치 여부, 세 receipt 존재와 deadline 내 여부뿐이다. ID·probe tag·개인 이름·시각·경로·예외 원문은 출력하지 않는다. 파일 손상·중복 충돌·불완전 끝줄·변경 관측 시 실패한다. 승인 후 실행 명령은 `python3 receipt_summary.py <approved-snapshot-directory>`이며 출력은 기계 관측 보조 자료다.

이 요약은 native origin 검증을 새로 수행하거나 실행 봇의 동일성을 입증하지 않는다. 기존 처리기가 남긴 receipt와 상태의 제한된 요약이다. complete 표시만으로 권한·단일 수신자·직원 호출 0·앱 journal 무변경·사람 화면 통과를 주장하지 않는다. 일관 스냅샷 수집 방법 및 요약 도구를 검토한 후 사용하며 원본 전체 금고는 출력하지 않는다.

## 검증과 미실행

- 설치 범위 대조 Python: 종료 0, 42/42 파일 일치. `git diff <복구 커밋> <기준 구현 커밋> --stat -- gate hub schemas config install`: 종료 0, 출력 없음.
- 로컬 `prepare_m0.py`: 종료 0. clone/checkout/네 파일 add/후보 commit/원격 제거/상태 검사 각각 종료 0. 후보 변경 목록 정확히 네 파일, 실제 설치 영향 세 파일, 공유 인덱스 및 운영 설치 불변. 상세 명령은 비공개 preparation.json에 있다.
- `python3 .build/telegram-comments/m0/check_summary.py`: 종료 0, 가짜 자료 6개 사례 통과. complete/누락/기한 초과 및 손상/중복/미지원 상태를 검사했다. 정상 사례 도구 종료 0, 거부 사례 종료 1을 기대대로 확인했고 스냅샷 불변·식별자 비노출을 검사했다. 결과는 비공개 `summary-tests.json`에 있다.
- 기존 76개 회귀 시험은 제품 바이트가 검토본과 같으므로 반복하지 않았다. 후보와 복구의 실행/배포, gateway 재시작, 운영 스냅샷 수집, 실제 발신, bind, TASK 2~4, 푸시는 전부 미실행이다.

다음은 기획 담당이 이 후보와 복구 manifest, 요약 도구의 안전 범위, probe 후 롤백 시 업데이트 유입 차단을 검토하고 남은 비공개 대상 정보를 채우는 것이다. 구체적인 실행안을 사용자에게 승인받기 전 운영 작업을 하지 않는다.
