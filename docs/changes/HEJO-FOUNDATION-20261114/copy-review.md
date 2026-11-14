# 외부 코드 복사 검토

## TASK-07 개인값 패턴

- 원본: `<운영 저장소>/hermes/plugin-store/team-kit/lib/hermes_facility/airport_boundaries.py` 전체(모듈 끝 `return findings`까지)를 실제로 읽었다. 의존은 표준 라이브러리 hashlib·json·pathlib·re다. YAML 입력에만 ruamel.yaml을 지연 import한다. 의존 소스 복사는 없다.
- 실제 원본 저장소 경로는 추적하지 않는 `AGENTS.local.md`에서 확인한다.
- 가져올 것: Slack ID·이메일·사용자/볼륨 절대 경로·fixed_home 정규식, 명부 단어 추출·단어 경계 처리, 금고 문자열 분류 규칙. 원본의 역할은 탐지이며 예외 정책은 호출자 책임이다.
- 가져오지 않을 것: 확장자 제한·시험 폴더 제외·디렉터리 순회·종류/경로/정규화 문장 기반 지문. hejo design 7절은 git 추적 텍스트 전체와 줄 내용 지문을 요구한다. 예약 id 패턴은 같은 절의 hejo 탐지 종류에 없으므로 가져오지 않는다.
- hejo 책임: `scripts/scan_private.py`가 추적 파일 분류·두 고정 입력·탐지·줄 단위 예외·출력을 소유한다. 원본 저장소 import·수정·동기화는 하지 않는다.
- 보안 경계: 운영 홈에서는 owner/team.yaml·owner/vault.yaml 두 파일만 연다. 값·원문·예외 이유는 출력하지 않는다. 예외는 가짜 시험 값 또는 LICENSE 저작권 고지 줄만 허용한다.
