# hejo 작업 규칙

근간 원본은 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)다. 모든 기획·설계·구현·검토는 이를 따른다.

- 새 기능은 먼저 칸을 정하며 새 칸·두 번째 원본을 만들지 않는다. 맞지 않으면 덧대지 말고 멈춘 뒤 칸 배치를 보고한다.
- 이 저장소는 공개판 그 자체다. 사람 이름, 직원 id, 계정, 이메일, 주소, 절대 경로, 토큰을 코드·시험·키트·문서 예시에 넣지 않는다. 시험은 임시 `HERMES_HOME`과 가짜 명부만 쓴다.
- Hermes 본체(`~/.hermes/hermes-agent`)를 고치지 않는다. 문은 플랫폼 플러그인 계약만 쓴다.
- 운영 공항(`~/.hermes`)의 설정·플러그인 연결·게이트웨이 재시작은 인계서가 허가한 작업에서만, 롤백 절차와 함께 한다. 실제 Slack·고객 메시지를 보내지 않는다.
- `~/.hermes`의 비밀 파일(`.env`, `auth.json`, 토큰 파일)을 열지 않는다.
- UI는 AppKit 기본. SwiftUI는 작업 문서의 SwiftUI 예외 목록에 이유가 적힌 화면에만 쓴다.
- ddots(`<운영 저장소>/ddots`)와 hejo는 다른 앱이다. ddots에서 코드를 베껴 올 수 있지만 ddots 파일을 고치거나 두 앱 사이에 동기화 장치를 만들지 않는다.
- `<운영 저장소>`는 운영자의 비공개 운영 저장소다. 이름·경로는 개인값이라 추적 파일에 쓰지 않고, 로컬 경로는 추적하지 않는 `AGENTS.local.md`에 적는다.
- team-kit 변경은 운영 저장소 저장소의 규칙(`<운영 저장소>/AGENTS.md`, `./airport-check`)을 따른다.
- 검증 중 hejo 앱을 실제로 설치·교체할 때 기존 앱 백업은 `/Applications`·`~/Applications` 밖(`~/Library/Application Support/hejo-backups/`)에 두고, 작업 판정 뒤 지운다.
- 푸시는 사용자가 화면에서 승인하면 플러그인이 실행한다. 에이전트는 git push를 하지 않는다.

## 프로젝트 설정

| 항목 | 값 |
|---|---|
| 현재 명세 | `docs/spec/current/` |
| 작업별 문서 | `docs/changes/<작업ID>/` |
| 결정 기록 | `docs/decisions/` |
| 전역 구조 | `docs/ARCHITECTURE.md` |
| 수락 시험 위치 | `tests/acceptance/` |
| 기획설계의 수락 시험 쓰기 허가 | 허용 |
| 사전 위임 범위 | 없음 |
| ID 발급 방식 | 작업 ID 접두어(예: HEJO-FOUNDATION 작업의 요구는 `REQ-HF-01`) |
| 빌드 명령 | `bash app/scripts/build.sh` (HEJO-FOUNDATION TASK-05에서 생성) |
| 시험 명령 | `bash scripts/test.sh` (gate pytest + app swiftc 시험, TASK-02·05에서 생성) |
| 정적 분석 명령 | `python3 scripts/scan_private.py` (개인값 검사, TASK-07에서 생성) |
| 건드리면 안 되는 경로 | `~/.hermes/hermes-agent/`(본체), `<운영 저장소>/ddots/`(다른 앱), `~/.hermes`의 비밀 파일 |
| 위험 정책 위치 | 없음(공통 4절) |
| 규제 대상 여부 | 아니오 |
| 기본 진행 방식 | 연합개발 |
