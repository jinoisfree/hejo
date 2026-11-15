# hejo 브레인스토밍 결정 요약 (2026-11-13~14)

- 상태: 확정(사용자 결정). 진행 방식: 연합개발, 계획 검증 켬.
- 이 문서는 개인값을 뺀 공개용 요약이다. 실제 운영 값이 든 원본은 운영자의 비공개 저장소에 있다. 근간 원본은 [docs/ARCHITECTURE.md](../../ARCHITECTURE.md), 작업 명세는 같은 폴더의 spec·design·tasks를 따른다.

## 칸·원본·쓰기 주체·수명

| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| hejo 문(게이트 플랫폼 플러그인) | 공항 시설 | `hermes-hejo/gate/` | 개발 | 갱신 때 교체 |
| 앱↔문 통신 규격 | 공항 시설 | `hermes-hejo/schemas/` | 개발 | 갱신 때 교체 |
| 답장 버튼·안내원의 hejo 등록 | 공항 시설(선택 확장) | 운영 저장소 `team-kit` | 개발 | 갱신 때 교체 |
| 기본 가이드북·도구·세트 | 기본 선반(키트) | `hermes-hejo/kit/` | 개발 | 갱신 때 교체 |
| 사장이 만든 가이드북·도구 상자·세트 | 사장 공방(새 칸) | `<HERMES_HOME>/owner/workshop/` | 사장(앱·Paseo 공방) | 영구 |
| 직원 카드(성격·두뇌·장착 목록) | 직원 명부·직원 성격 | 조립 층 원래 자리(`owner/team.yaml`, `soul/personas/`, 지시서) | 사장(앱) | 영구 |
| 사장 계정·기기 출입증·문 번호 | 사장 금고 | 각 공항 금고 | 사장 / 문 | 영구 / 취소 때까지 |
| 공항 기본 두뇌·캐시 auto·보고 받을 곳 | 사장 지시서 | `owner/policy.yaml`, `config.yaml` | 사장 | 영구 |
| 단체방 목록(2단계)·행동 기록 | 공용 창고 | `<HERMES_HOME>/shared/` | 시설 런타임 | 영구 |
| 대화 원본 | 직원 사물함 | 각 직원 세션 | 런타임 | 영구 |
| hejo 앱·화면 설정 | 관제 화면 | `hermes-hejo/app/`, `hejo-local.json` | 개발 / 사장 | 교체 / 영구 |
| 설치 도우미·개인값 검사 | 정비 격납고 | `hermes-hejo/install/`, 검사 스크립트 | 운영자 | 갱신 때 교체 |

## 목적

사장이 Slack 없이 hejo 앱으로 Hermes 직원과 대화하고, 직원을 만들고 키우고 관리한다. 나중에 누구나 사장이 되는 공항 키트로 공개한다.

## 하는 것 / 하지 않는 것

- 한다: 새 저장소 `hermes-hejo`(비공개 시작)에 앱·문·통신 규격·설치 도우미. ddots 코드를 한 번 베껴 오되 별도 앱으로 따로 관리. 모든 기능을 UI/UX로 보고 고친다.
- 하지 않는다: Slack 대화 이관, Hermes 본체 개조, 코드에 개인값, 인터넷 전체 공개 포트, hejo가 구독 로그인 창구·토큰 보관, hejo가 연합개발 결정(구현 담당 선택·승인) 대행, 도구별 두뇌, 클라우드 계정, 손님 계정, ddots iCloud 대화 기록·HermesRelay·ddots-config iCloud 내보내기·Slack ID 기반 설정 동기화.

## 핵심 구조

사장이 직원을 고용해 가이드북을 읽히고 도구를 쥐여 주며 사장 규칙을 지키게 한다.

| 단어 | 정의 |
|---|---|
| 사장 계정 | 공항 금고 안의 계정. 새 기기 등록에만 아이디·비밀번호 또는 구글 로그인, 평소는 기기 출입증, 위험한 일은 Touch ID 재확인 |
| AI 연결 | 공항당 Claude 1 + Codex 1 구독. 로그인은 공식 도구. hejo는 연결 여부·계정·사용량만 표시 |
| 직원 | 직무 없는 빈 사람 + 성격(SOUL 조각, AI 초안) |
| 두뇌 | 모델+추론. 가이드북 > 직원 > 공항. 가이드북 두뇌는 시간표 일에만 적용(캐시 보존) |
| 가이드북 | 일하는 방식 + 이럴 땐 이렇게 + 필요한 도구 + 시간표 = 기존 직책 명세서 |
| 도구 | 할 수 있는 행동. 필요한 능력·안전 수준만 선언(두뇌 없음) |
| 세트 | 성격+가이드북+도구+두뇌 틀. 기존 직원 한 명의 현재 업무 전부를 담은 세트(개인값 제외) |

선반: 기본 선반(키트, 개발) / 내 선반(사장 공방, 영구) / 직원 선반(사물함). 기본 선반 물건을 고치면 내 선반에 복사본. 직무는 저장하지 않는다. SOUL.md·설정은 조립 결과(공통 → 성격 → 가이드북, 매번 바뀌는 글 제외).

공항은 조립식 한 종류로 통일한다. 운영 중인 두 공항 모두 조립식이며, 조립 층이 없는 공항에는 hejo 키트가 조립 층을 함께 설치한다.

## 단계

1. 1단계: 내 공항(Mac mini) + MacBook, Slack 병행. 문·1:1 대화·스레드·버튼·예약 보고, 계정·기기(구글 로그인은 마지막), 직원 카드·세트, 공방(도구 묶기·Paseo 의뢰), AI 연결, 펫·말풍선·업데이트·작업 상태.
2. 2단계: 단체방+안내원, ddots 부가 기능(클립보드·파일 드롭·캘린더·쉬림프 볼트·세 손가락 탭·웹 패널), 같은 Mac의 두 번째 사장 공항 + 두 번째 노트북(늘 켜짐, 우선 두 계정 로그인 유지 방식), MCP 연결, 직원별 캐시·사용량 그래프.
3. Slack 은퇴: 6·7번(단체방·ddots 부가 기능)이 hejo에서 매일 쓸 수 있게 된 뒤.
4. 3단계: 공개 검토(라이선스 쪽지, 공식 도장).

## 실측 근거(브레인스토밍 당시)

- Hermes 플랫폼 플러그인 `kind: platform` + `ctx.register_platform`(본체 무수정) — `~/.hermes/hermes-agent/gateway/platforms/ADDING_A_PLATFORM.md`.
- team-kit `hermes_reply`는 slack만, `hermes_router`는 slack·photon·bluebubbles만 등록(`hermes_reply/plugin.py:41`, `hermes_router/plugin.py:22`).
- 프로필별 모델·`reasoning_effort`, `delegation.provider/model`, `auxiliary.*`, `prompt_caching.cache_ttl: auto`(`agent/prompt_caching.py`) 존재.
- Claude 구독 공식 플러그인(공식 `claude` CLI 사용), Codex OAuth(`hermes auth add openai-codex`).
- ddots 계정별 고정 포트(`ddots/Sources/HermesRelay.swift`), 사용량 코드(`Usage.swift`, `UsageSources.swift`).
- `paseo` CLI(run·ls·inspect·pair) 존재. 두 번째 macOS 계정에 Hermes 홈 존재(내부 권한 없음, 사용자 확인: 조립식).
- Anthropic: 사전 승인 없이 제3자 제품의 claude.ai 로그인 제공 불가(code.claude.com/docs/en/agent-sdk/overview). 캐시 5분 쓰기 1.25배, 1시간 2배, 읽기 0.1배(platform.claude.com prompt-caching).

## 선행 조사

| 이름 | URL@커밋 | 별 | 마지막 커밋 | archived | 라이선스 | 관련도 | 판정 |
|---|---|---|---|---|---|---|---|
| Hermes-Desktop | github.com/jeromeleeqy-hash/Hermes-Desktop@2c3da47d38ba575780a425e8085800ec28d01701 | 5 | 2026-10-09 | 아니오 | 없음 | 인접 | 참고만 |
| hermes-pllla-plugin | github.com/crostime/hermes-pllla-plugin@9157ebd257b1902bc1676b7b75ba18656e178429 | 0 | 2026-09-11 | 아니오 | 없음 | 직접 해당(플랫폼 플러그인·페어링) | 패턴만 참고 |

## 대안과 선택

- 게이트: 플랫폼 플러그인 채택. api_server(요청-응답, 먼저 보내기·team-kit 버튼 불가), ddots 연결 통로 확장(보내기 경로 없음, 두 번째 원본) 기각.
- 계정: 공항 안 계정 채택. 클라우드 계정(서버 운영·개인정보) 기각.
- 공방 다리: 의뢰+상태 보기 채택(hejo가 작업 공간 생성·첫 메시지 "연합개발로 진행해줘…"·읽기 전용 상태 표시, 결정은 Paseo 앱). hejo가 연합개발 화면 대행 기각. 실측 실패 시 의뢰서 복사로 축소.
- 코드: ddots를 한 번 베껴 와 별도 앱으로(번들 ID·설정·키체인·업데이트 경로 분리).

## 가정

- 사용자 결정: 병행 후 이행, 저장소 분리(문도 hejo 저장소), ddots와 hejo는 다른 앱, 대화 새로 시작, 사장마다 자기 노트북, 두 번째 공항 늘 켜짐, 공개 전제·비공개 시작, All rights reserved, 내 서명 인증서(공식 Developer ID 보류), 직무 없는 직원·앱에서 생성/편집/해고(사물함 보존), 성격 SOUL 활용·AI 초안, 기존 직원 세트, 사장 제작 가이드북·도구·세트, 가이드북 = 직책 명세서, 계정 도입, 구글 로그인(1단계 마지막), 두뇌 3단계·도구별 두뇌 없음, 캐시 auto, 구독 로그인은 공식 도구로·연결/계정/사용량 표시, 공항당 Claude 1·Codex 1, Paseo 공방·의뢰+상태 보기, UI/UX 전부, 빼기 1~5·단순화 11~13, 조립식 통일, 6·7은 2단계·Slack 은퇴 조건.
- 에이전트 제안(사용자 수용): 앱 1개 = 공항 1개(전환은 로그인), Tailscale·로컬에서만 접속, Mac mini에서 앱 상시 실행 불필요, 문이 쓰는 한 줄 행동 기록.

## 열린 질문(계획 단계)

- 게이트웨이 실행 중 새 직원(프로필) 즉시 연결 가능 여부.
- 멀티플렉스에서 포트 하나로 모든 프로필을 받는 방법.
- `paseo run`·작업 공간 생성 에이전트에 연합개발 규칙 적용 여부.
- Claude CLI·Codex의 계정 이름·사용량·캐시 수치를 읽는 공식 명령.
- OpenAI Codex 구독 로그인 관련 약관.
- 두 번째 공항 상시 실행 B안(LaunchDaemon), 공개 시 라이선스 쪽지, 운영 저장소 근간 문서 개정 문구.

## 위험도 1차 판단

고위험: 보안·인증·권한(계정·원격 쓰기), 저장 구조 변경(사장 공방·조립 층 쓰기), 게이트웨이 동시성, 공개 배포. 작업 단위로 나눠 진행한다.
