# HEJO-FOUNDATION 작업 분해

2판(계획 검증 1회차 반영). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-FOUNDATION.md](../../../tests/acceptance/HEJO-FOUNDATION.md), 검토 기록 [plan-review.md](plan-review.md). 저장소: `H` = 이 저장소, `HD` = 운영자의 비공개 운영 저장소(team-kit·운영 설정 동기화).

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 근간·명세·설계·수락 시험 문서 | 전체 | `H/docs/`, `H/tests/acceptance/`, `H/AGENTS.md` | — | 일반 · 문서 | 완료(기획, 2판) |
| TASK-02 | 통신 규격 v1(2·2.1·2.2절 전부) + 문 핵심: 플러그인 골격, 리스너(기본 프로필만, 보조는 비활성), 주소 검사, 허용 사용자 브리지, 페어링·출입증·취소, 직원 목록·roster 응답, 1:1 글 주고받기, 작성 중, 수정·스트리밍, 기록장(단독 쓰기 잠금·복구·쓰기 실패 되돌림)·재전송 경계 규칙, 확장 훅(2.2), CLI | HF-01~06 / AT-01~14, 32~37 | `H/schemas/`, `H/gate/`(plugin.yaml, adapter, server, auth, journal, roster, hooks, cli), `H/gate/tests/`, `H/tests/acceptance/` | TASK-01 | 고위험 · 2 | 대기 |
| TASK-03a | 보조 프로필 배달 탐침(A 전달자 / B 단독 발신자). 임시 홈 실제 게이트웨이에서 시험, 결과만 보고. 운영 코드 채택 금지 | (REQ-HF-01·10 결정 자료) | `H/gate/probes/`, impl-report | TASK-02 | 고위험 · 3 | 대기 |
| (계획) | 4.1 결정 → spec·design·AT-02·AT-22·tasks 개정, A면 사용자 승인 | — | `H/docs/`, `H/tests/acceptance/` | TASK-03a | — | 대기 |
| TASK-03b | 문 확장: 첨부 HTTP(직원 소유 검사), 직원 발송 파일 복사·등록, Hermes 기본 버튼 3종, 사진 경로, team-kit 없을 때 버튼 글자 대체, 결정된 보조 프로필 배달 | HF-07,08,09.AC-03,10 / AT-15~18,21,22 | `H/gate/`(buttons, files, adapter 확장), `H/gate/tests/` | 4.1 결정(배달 부분만), 나머지는 TASK-02 | 고위험 · 2, AT-22는 3 | 대기 |
| TASK-04 | team-kit hejo 답장 버튼: `controls()`를 `reply_buttons`로 이동(Slack 동작 보존), 2.2절 훅을 쓰는 hejo 등록, 시험 | HF-09.AC-01·02 / AT-19,20 | `HD`의 team-kit `lib/hermes_reply/`(운영 원본에서 수정 후 동기화), team-kit 시험 | TASK-02(2.2 훅 구현 완료) | 일반 · 2 | 대기 |
| TASK-05 | 앱 골격: 빌드·서명·시험 스크립트, 정체성, AppDelegate·메뉴 막대·단일 실행·로그인 시 실행, 설정 저장, 키체인 헬퍼, 연결 창, WebSocket 클라이언트(hello·welcome·2.1 재전송 규칙·재접속) | HF-11 / AT-23~25 | `H/app/`(scripts, Resources, Sources 골격), `H/app/Tests/` | TASK-02(규격 파일) | 고위험(인증 저장) · 2 | 대기 |
| TASK-06 | 앱 대화 화면: 중립 모델, 직원 사이드바·안 읽은 수, 스레드 목록·보기(베낀 AppKit 카드), 작성 중 점, 버튼 줄, 첨부 타일·업로드, 입력 줄, 새 스레드 | HF-12 / AT-26 | `H/app/Sources/`(대화 관련 새 파일), `H/app/Tests/` | TASK-05, TASK-03b(첨부 HTTP) | 일반 · 2 | 대기 |
| TASK-07 | 설치 도우미(영수증·충돌·실패 복구·비밀 파일 미접근, 기본 프로필만), 개인값 검사(두 파일만 읽기)·pre-commit, 통합 시험 진입점 `scripts/test.sh`, README | HF-13,14 / AT-27~29, 38~43 | `H/install/`, `H/scripts/`, `H/githooks/`, `H/README.md` | TASK-02(설정 키 확정) | 고위험(인증 허용 설정·운영 설정 복구) · 2 | 대기 |
| TASK-08 | 캐시 `auto`: 운영 `~/.hermes/config.yaml` 한 키 변경 → `HD` 동기화 커밋 | HF-15 / AT-30 | `~/.hermes/config.yaml`, `HD` 동기화 사본 | — | 일반(실행 의미·비용 변화, 값 복원으로 되돌림) · 3 | 대기 |
| TASK-09 | 운영 설치·실기기 검증: 운영 공항에 설치, 사장 확인 뒤 게이트웨이 재시작, 노트북 페어링·대화·버튼·첨부·예약 보고, 지연 측정, 제거·복원 확인 | 전체 / AT-22(3), AT-26, AT-31(4) | 운영 설정(설치 도우미 경유), `H/evidence/` | TASK-02~08 | 고위험 · 4 | 대기(사장 참여 필요) |

## 병렬 갈래

있음. TASK-02 완료 뒤 담당 파일이 겹치지 않는 네 갈래로 나눌 수 있다. 확장 훅(2.2)과 설정 키(7절)는 TASK-02에서 고정되므로 갈래가 추정 계약으로 진행하지 않는다.

| 갈래 | TASK | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|---|
| 문 확장 | TASK-03a → (계획 결정) → TASK-03b | `H/gate/` | TASK-02 | 어려움 | AT-15~18,21,22 통과 |
| team-kit | TASK-04 | `HD` team-kit `hermes_reply`와 시험 | TASK-02 | 보통 | AT-19,20 + 기존 Slack 답장 버튼 시험 통과, `HD` `./airport-check` 통과 |
| 앱 | TASK-05 → TASK-06 | `H/app/` | TASK-02 (TASK-06은 TASK-03b의 첨부 HTTP도) | 어려움 | AT-23~26 |
| 설치·검사 | TASK-07 | `H/install/`, `H/scripts/`, `H/githooks/`, `H/README.md` | TASK-02 | 보통 | AT-27~29, 38~43 |

TASK-08은 어느 갈래와도 파일이 겹치지 않는다. TASK-09는 모든 갈래 뒤에 한다. 보조 프로필 설치 설정은 4.1 결정·승인 뒤 TASK-07 추가 지시로 다룬다.

## SwiftUI 예외

없음([design.md 6절](design.md#swiftui-예외-목록)).
