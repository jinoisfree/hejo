# TASK-55 구현·자체 시험

보완 70의 칸은 기존 문 어댑터·허브 인증·설치 영수증, 앱 Controller·회원 상태, team-kit 원문 증명·대기 관리다. 새 영구 원본은 없다. 운영 반영은 하지 않는다.

| 지적 | 수정 | 수정 전 근거 | 집중 통과·변형 |
|---|---|---|---|
| IR-01 | 제어·답 버튼에 직원 대상을 붙이고 문이 그 대상을 보존. 일반 글은 기존 대표 규칙 유지 | task55/route-before2.log, app-route-before.log | server-final.log, app-route-after.log, mutation-IR01.log·mutation-app-route.log |
| IR-S01 | 둘째 이후 키 저장 예외에도 앞선 키 전부 공식 보상. 보상 예외를 모아 write_partial | server-before.log | server-final.log, mutation-IRS01.log |
| IR-S02 | 기존 연결은 마지막 성공부터 300초 유예, 새 연결은 hub_unavailable 오류. 앱은 revoked만 자격 삭제 | server-before.log, app-unit-before.log | server-final.log, app-unit-after.log, mutation-IRS02.log·mutation-app-unit.log |
| IR-02 | 초기 회원 상태 수신 뒤 처음 방 읽음 심기 | app-unit-before.log | app-unit-after.log, mutation-app-unit.log |
| IR-S06 | 구성원 아닌 직원의 방 송신·수신 대상 거절 | server-before.log | server-final.log, mutation-IRS06.log |
| IR-S10 | 영수증 v2에는 소유 키의 이전 값만 남김. v1 로드 때 전문·written 제거, 빈 부모 구조 보존 | server-before.log | server-final.log, mutation-IRS10.log |
| IRT-01 | 공개 처리 시작/끝 훅으로 실제 대기열 사건마다 증명 바인딩 교체 | team-before.log | team-after2.log, mutation-IRT01.log |
| IRT-03 | 환경 세션 ID 대신 인자로 받은 세션과 저장된 user 사건 증명 | team-before.log | team-after2.log, mutation-IRT03.log |
| IRT-04 | 명시 answer_to 우선, 없으면 현재 사장 사건 앞의 같은 직원·대화·스레드 최신 살아 있는 글 공개 조회 | latest-before.log, team-before.log | server-final.log, team-after2.log, mutation-IRT04.log |
| IRT-02 | 같은 profile의 hejo 대화 전체 목록/취소/정리, 종료 상태 cron 정리. 다른 profile·Slack 분리 | team-before.log | team-after2.log, mutation-IRT02.log |

표의 경로 접두어는 `.build/`다. 표에 적힌 로그는 `.build/task55/` 아래에 있다. 변형은 해당 제품 파일을 수정 전 코드로 되돌린 임시 사본에서 같은 새 시험이 종료 1인지 확인한다. 정상본 집중 시험 종료는 모두 0이다. 앱 변형은 컴파일 성공 뒤 IR-01·IR-02·IR-S02 단언 실패를 확인한다.

## 계약·이전

- 일반 작성기 전송과 제어 전송을 `send.targeted` 선택 필드로 구분한다. 새 문은 필드 없는 옛 앱을 그대로 받는다. 새 앱의 제어는 이 문과 함께 배포해야 한다. 옛 문은 새 필드를 닫힌 실패로 거절하며 일반 글로 바꿔 보내지 않는다. native click은 문 내부에서 targeted로 변환한다.
- hub_unavailable은 기존 일반 error 틀을 쓰므로 auth_rejected 이유 목록은 늘리지 않는다. 옛 앱도 연결 실패를 재시도하며 토큰은 지우지 않는다. 유예 중 네트워크 실패는 마지막 확인 시각을 갱신하지 않고, 명시 폐기는 즉시 끊는다. 300초 뒤에는 1001 재접속으로 닫는다.
- 영수증 v2는 전체 원문 복원을 지원하지 않는다. 설치 소유 키만 원래 값으로 돌리며 관련 없는 설정은 건드리지 않는다. 기존 영수증은 읽을 때 축소 저장한다. 옛 설치 도우미는 v2를 거절하므로 되돌림에도 새 도우미를 사용한다.
- 최신 직원 글 조회는 사장 글 ID의 기록장 seq로 상한을 둔다. UUID를 시간처럼 비교하지 않는다. 역할·살아 있음·방 수신자·직원·스레드 검사는 기존 공개 조회와 같다. 명시된 answer_to가 잘못되면 최신 글로 대체하지 않는다.
- team-kit은 실제 BasePlatformAdapter 대기열과 GatewayRunner 세션 환경 설정을 거쳐 도구 executor 스레드의 원문 증명을 확인한다. 본체 비공개 함수에 새 훅을 달지 않는다. Slack 경로는 변경하지 않는다.

## 검증 주의

전체 시험·패치 지문·dry-run·개인값·커밋 지문은 `.build/task55/final-verification.json`을 기준으로 한다. 최초 전체 team-kit 실행은 주변 저장소 자료를 빠뜨린 사본에서 실행돼 실패했다. 이후 기존 검증의 격리 저장소 자료를 복사하고 가짜 HOME을 사용한다. 실제 설정·학습 본문을 시험의 원본으로 삼지 않는다. 중간 실패 로그는 최종 통과와 구분해 보존한다.

앱·문은 임시 홈과 루프백, team-kit은 가짜 사건·세션 DB만 사용한다. 실제 CLI 설정은 lstat, 실제 다운로드 폴더는 항목 이름만 비교한다. 운영 배포·실물 수락은 남는다. 앱 버전·public은 유지한다.
