# HEJO-FOUNDATION 작업 분해

2판(계획 검증 1회차 반영). 4판 보완(2026-11-14, 사용자 지시: 펫 열기·닫기 구조 유지, REQ-HF-16) — 계획 재검증 대기, TASK-05 인계 전 확정. 5판(같은 날): 4.1 A 전달자 결정(사용자 승인). 명세 [spec.md](spec.md), 설계 [design.md](design.md), 수락 시험 [HEJO-FOUNDATION.md](../../../tests/acceptance/HEJO-FOUNDATION.md), 검토 기록 [plan-review.md](plan-review.md). 저장소: `H` = 이 저장소, `HD` = 운영자의 비공개 운영 저장소(team-kit·운영 설정 동기화).

| TASK | 내용 | REQ / 시험 | 영향 파일 | 선행 | 위험·증거 | 상태 |
|---|---|---|---|---|---|---|
| TASK-01 | 근간·명세·설계·수락 시험 문서 | 전체 | `H/docs/`, `H/tests/acceptance/`, `H/AGENTS.md` | — | 일반 · 문서 | 완료(기획, 2판) |
| TASK-02 | 통신 규격 v1(2·2.1·2.2절 전부) + 문 핵심: 플러그인 골격, 리스너(기본 프로필만, 보조는 비활성), 주소 검사, 허용 사용자 브리지, 페어링·출입증·취소, 직원 목록·roster 응답, 1:1 글 주고받기, 작성 중, 수정·스트리밍, 기록장(단독 쓰기 잠금·복구·쓰기 실패 되돌림)·재전송 경계 규칙, 확장 훅(2.2), CLI | HF-01~06, 07.AC-03 / AT-01~14, 32~37, 44~46 | `H/schemas/`, `H/gate/`(plugin.yaml, adapter, server, auth, journal, roster, hooks, cli), `H/gate/tests/`, `H/tests/acceptance/` | TASK-01 | 고위험 · 2 | 완료(검토 4차, `c6701af`) |
| TASK-03a | (완료, verdict 5차) 보조 프로필 배달 탐침(A 전달자 / B 단독 발신자). 임시 홈 실제 게이트웨이에서 시험, 결과만 보고. 운영 코드 채택 금지 | (REQ-HF-01·10 결정 자료) | `H/gate/probes/`, impl-report | TASK-02 | 고위험 · 3 | 대기 |
| (계획) | (완료, 5판) 4.1 A 전달자 결정·사용자 승인, spec·design·AT-02·22·27·28·49·50·tasks 개정 | — | `H/docs/`, `H/tests/acceptance/` | TASK-03a | — | 대기 |
| TASK-03b | 문 확장: 첨부 HTTP(직원 소유 검사), 직원 발송 파일 복사·등록, Hermes 기본 버튼 3종, 사진 경로, team-kit 없을 때 버튼 글자 대체, 보조 프로필 전달자(design 4.1 A 보강 4항) 승격과 `gate/probes/` 제거 | HF-01.AC-02~04, 07(AC-04 포함),08,09.AC-03,10 / AT-02, 15~18, 21, 22, 49~51 (사진 HTTP는 6판에서 범위 밖) | `H/gate/`(buttons, files, adapter 확장), `H/gate/tests/` | TASK-02, 4.1 결정(완료) | 고위험 · 2, AT-22는 3 | 완료(검토 8차, `820f23a`) |
| TASK-04 | team-kit hejo 답장 버튼: `controls()`를 `reply_buttons`로 이동(Slack 동작 보존), 2.2절 훅을 쓰는 hejo 등록, 시험 | HF-09.AC-01·02 / AT-19,20 | `HD`의 team-kit `lib/hermes_reply/`(운영 원본에서 수정 후 동기화), team-kit 시험 | TASK-02(2.2 훅 구현 완료) | 일반 · 2 | 완료(16차, 운영 392a2afb · hejo 846bd7c, 푸시 승인 대기) |
| TASK-05 | 앱 골격: 빌드·서명·시험 스크립트, 정체성, AppDelegate·메뉴 막대·단일 실행·로그인 시 실행, 설정 저장, 키체인 헬퍼, 연결 창, WebSocket 클라이언트(hello·welcome·2.1 재전송 규칙·재접속·송신 전 1 MiB 검사·1006 재접속), 펫 창과 대화 펼치기·접기(4판, design 6절). 베끼기 전 원본 전수 검토 기록 `copy-review.md`(design 6절 베끼기 원칙) | HF-11, HF-16 / AT-23~25, 47, 48 | `H/app/`(scripts, Resources, Sources 골격), `H/app/Tests/` | TASK-02(규격 파일) | 고위험(인증 저장) · 2 | 완료(검토 11차, `86bb82a`, AT-47 수동은 TASK-09) |
| TASK-06 | 앱 대화 화면 = ddots 현재 화면 그대로 AppKit으로(8판, design 6절; 베끼는 파일은 `copy-review.md` 전수 검토 기록 뒤): 중립 모델, 직원 사이드바·안 읽은 수, 스레드 목록·보기(베낀 AppKit 카드), 작성 중 점, 버튼 줄, 첨부 타일·업로드, 입력 줄, 새 스레드 | HF-12 / AT-26 | `H/app/Sources/`(대화 관련 새 파일), `H/app/Tests/` | TASK-05, TASK-03b(첨부 HTTP) | 일반 · 2 | 완료(검토 12차, `c5d2594`, 8판 ddots 화면; AT-26 수동은 TASK-09) |
| TASK-07 | 설치 도우미(영수증·충돌·실패 복구·비밀 파일 미접근, 기본 프로필 문 + 보조 프로필 전달자 설정), 개인값 검사(두 파일만 읽기)·pre-commit, 통합 시험 진입점 `scripts/test.sh`, README | HF-13,14 / AT-27~29, 38~43 | `H/install/`, `H/scripts/`, `H/githooks/`, `H/README.md` | TASK-02(설정 키 확정) | 고위험(인증 허용 설정·운영 설정 복구) · 2 | 완료(검토 10차, `b7212a9`) |
| TASK-08 | 캐시 `auto`(9판): 운영 루트와 모든 프로필 `config.yaml`의 `prompt_caching.cache_ttl` → `auto`, `HD` 동기화 커밋. 사장 승인 2026-11-15 | HF-15 / AT-30 | `~/.hermes/config.yaml`, `~/.hermes/profiles/*/config.yaml`, `HD` 동기화 사본 | — | 일반(실행 의미·비용 변화, 값 복원으로 되돌림) · 3 | 완료(17차) |
| TASK-10 | 로고 `HEJO.`(H 파랑) + 버전(9판) | HF-17 / AT-52 | `H/app/Sources/ConversationView.swift`, `H/app/Tests/` | TASK-06 | 일반 · 2 | 완료(17차) |
| TASK-11 | 아일랜드 1단계(9판, design 6절 "로고와 아일랜드"): IslandModel·IslandView, 칸·잠깐 늘어남·문제 칸·누르기·끌기 제외, 연결 끊김 띠 이전 | HF-18 / AT-53~56 | `H/app/Sources/`(Island*.swift, ConversationView·Controller 연결), `H/app/Tests/` | TASK-10 | 일반 · 2 | 완료(17차) |
| TASK-12 | 대화 안 작성 중 표시(9판, REQ-HF-12 예외): 기다림 = "작성 중" 반짝임 + 경과 초, 흘러나옴 = 깜빡이는 커서 | HF-19 / AT-57 | `H/app/Sources/ConversationView.swift`·`NativeThreadCard.swift`, 반짝임 부품(TASK-11과 함께 씀), `H/app/Tests/` | TASK-11 | 일반 · 2 | 완료(18차, 자체 점검) |
| TASK-13 | 자동 연결(10판, REQ-HF-20): 문의 로컬 일회용 코드 파일과 `auto` 페어링(Tailscale 같은 사용자 확인), 규격 hello `auto`·거부 이유 `untrusted`, 앱 AirportFinder(로컬 파일 → Tailscale 후보)·연결 창 "자동으로 찾기" | HF-20 / AT-58·59 | `H/gate/`(auth·server·tailnet), `H/schemas/`, `H/app/Sources/`(AirportFinder·GateClient·ConnectWindow·AppDelegate), 시험 | TASK-12 | 고위험(인증) · 2 | 완료(20차, 자체 점검; 노트북 실물은 TASK-09) |
| TASK-09 | 운영 설치·실기기 검증(9판: AT-56 수동 포함): 운영 공항에 설치, 사장 확인 뒤 게이트웨이 재시작, 노트북 페어링·대화·버튼·첨부·예약 보고, 지연 측정, 제거·복원 확인 | 전체 / AT-22(3), AT-26, AT-31(4) | 운영 설정(설치 도우미 경유), `H/evidence/` | TASK-02~08, 10~12 | 고위험 · 4 | 부분 완료(19차: 공항 설치·실물 완료, 노트북·눈 확인은 사장과) |

## 병렬 갈래

있음. TASK-02 완료 뒤 담당 파일이 겹치지 않는 네 갈래로 나눌 수 있다. 확장 훅(2.2)과 설정 키(7절)는 TASK-02에서 고정되므로 갈래가 추정 계약으로 진행하지 않는다.

| 갈래 | TASK | 담당 파일 | 선행 | 난이도 | 완료 조건 |
|---|---|---|---|---|---|
| 문 확장 | TASK-03a(완료) → 4.1 결정(완료) → TASK-03b | `H/gate/` | TASK-02 | 어려움 | AT-02, 15~18, 21, 22, 49, 50 통과 |
| team-kit | TASK-04 | `HD` team-kit `hermes_reply`와 시험 | TASK-02 | 보통 | AT-19,20 + 기존 Slack 답장 버튼 시험 통과, `HD` `./airport-check` 통과 |
| 앱 | TASK-05 → TASK-06 | `H/app/` | TASK-02 (TASK-06은 TASK-03b의 첨부 HTTP도) | 어려움 | AT-23~26 |
| 설치·검사 | TASK-07 | `H/install/`, `H/scripts/`, `H/githooks/`, `H/README.md` | TASK-02 | 보통 | AT-27~29, 38~43 |

TASK-08은 어느 갈래와도 파일이 겹치지 않는다. TASK-09는 모든 갈래 뒤에 한다. 보조 프로필 설치 설정은 5판에서 TASK-07 범위에 넣었다(design 7절 3-1).

## SwiftUI 예외

없음([design.md 6절](design.md#swiftui-예외-목록)).
