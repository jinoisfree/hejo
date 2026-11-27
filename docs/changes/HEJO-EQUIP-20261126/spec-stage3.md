# HEJO-EQUIP 3단계 명세: 출입증에서 직원 기본 도구를 조립

- 상태: 1판 · 2026-11-27 · 근거 design.md 2판 6절 3단계, ADR-0001, 사용자 위임
- 작업 유형: 동작 보존 리팩토링(조립 결과가 지금 값과 같아야 함) · 위험도: 고위험(직원별 도구 범위의 원본 변경) · 운영 모드: 교차 모델
- 기준: 운영 저장소 `04958c04a3eb0cf7c05465dff809a673e557a3ac`, 실행본 `config_assembly.py` `2e299d806861ed1667e7710f8bdfe478bf7f0207615fd577847ab7e8008d9ed5`, `airport-check` `6617efd6cb2d100427037bfcee82b75b793c21e03bdbe69baf7ab0b9d12dfc55`

## 0. 칸·원본·쓰기 주체·수명
| 다루는 것 | 칸 | 원본 위치 | 쓰기 주체 | 수명 |
|---|---|---|---|---|
| 도구 창고 칸(팩)이 필요한 Hermes 기본 도구 | 도구 창고 | `hermes_packs/<칸>/pack.yaml` `core_toolsets` | 개발 | 갱신 때 교체 |
| 도구 없는 칸(personal·work·doctor·wiki·customers·standby)이 필요한 기본 도구 | 직책 명세서 | `roles/<칸>/guide.yaml`(새 파일, 키 `core_toolsets`만) | 개발 | 갱신 때 교체 |
| 직원 설정의 기본 도구 목록 | 조립 결과 | 직원 `config.yaml` `platform_toolsets.slack`의 기본 도구 항목(+`hejo`는 기존 복사 규칙) | 새 조립기 `hermes-config-assemble` | 다시 생성 |

점검표: 기본 도구의 원본은 칸 선언 하나다. 직원 설정은 결과다. 플러그인 도구셋 항목(team-kit 등)과 다른 플랫폼(photon·cron·cli)은 이번에 바꾸지 않는다. 개인값 없음. 다른 사장도 칸 선언만으로 같은 결과가 나온다.

## 1. 현황 [확인] 2026-11-27(값은 칸 이름으로만 적음)
| 출입증 | 지금 slack 기본 도구 |
|---|---|
| personal | terminal, image_gen, vision, skills, memory, session_search, web, browser, file, kanban, cronjob |
| work | terminal, skills, memory, session_search, file, vision, web, browser, cronjob |
| doctor | terminal, cronjob, memory, session_search, skills |
| customers + sns | memory, session_search |
| standby | memory, session_search |
| wiki(루트) | hermes-slack, memory, session_search |
- 6명 모두 `hejo` 목록 = `slack` 목록(`hermes-slack` → `hermes-hejo`). 도구 검색 `tools.tool_search.enabled`는 6명 모두 `off`다.
- 기본 도구 이름은 Hermes `toolsets.TOOLSETS`의 키로 판정한다. 플러그인 도구셋(team-kit, team-delegation, instagram-dm)은 그 밖이다.

## 2. 요구와 수락 기준
### REQ-EQ-03 직원 기본 도구는 출입증 칸 선언의 합이다
- AC-15 `roles/<칸>/guide.yaml`(6개)과 필요한 팩의 `pack.yaml` `core_toolsets`가 1절 표를 재현하도록 선언한다(칸마다 그 칸에 맞는 목록. customers가 memory·session_search를 갖고 sns 팩은 빈 목록).
- AC-16 새 조립기 `hermes-config-assemble --check|--write [--profile ID]`가 직원마다 출입증 칸 선언의 합을 계산한다. slack 목록의 기본 도구 항목을 그 합으로 맞춘다(기존 항목 순서 유지, 없던 것은 뒤에 추가, 빠질 것은 제거). 플러그인 항목은 자리와 순서를 그대로 둔다. hejo는 기존 복사 규칙을 다시 적용한다. 출입증에 선언 없는 칸 이름이 있으면 멈춘다(오류).
- AC-17(동작 보존, 핵심) 운영 6명에 대해 `--check`의 차이가 0이다. 0이 아니면 쓰지 않고 차이 표(칸 이름·도구 이름만)를 보고하고 멈춘다(사장 결정).
- AC-18(검사) `airport-check`에 `assembly:hermes-config-assemble`을 넣는다. 선언에서 도구 하나를 뺀 사본과 직원 설정을 손으로 고친 사본에서 실패해야 한다.
- AC-19(보존) photon·cron·cli 목록과 `tools.tool_search` 값이 바뀌지 않는다. team-kit 전체 실패 노드가 기준과 같거나 줄었다. 2단계 V-2 설치 시험 14개를 준비된 환경에서 다시 돌려 통과시킨다(실패하면 원인 보고).
- AC-20(설치기) 공개판 설치기가 같은 조립기로 기본 도구 목록을 만든다. `make-starter --target hermes-hejo-p --check` 종료 0.

## 3. 범위
- 안: 선언 파일, 조립기와 그 시험, airport-check 검사, 설치기 연결, 근간 문서의 "직원 설정 조립 결과" 문구 확인.
- 밖: 도구 검색 켜기(사장 결정, 4단계 앞에서 묻는다), 팩 목록 `packs.enabled` 조립(4단계), photon·cron 목록, 칸 질문 함수 이름 변경(4단계).

## 4. 적용과 롤백
`--check` 차이가 0이면 직원 설정을 쓰지 않으므로 재시작하지 않는다(코드·선언·조립기 파일만 교체). 교체한 실행본은 0700 폴더에 보관한다. 문제가 생기면 복원하고, 재시작이 필요 없음을 `--check`로 확인한다.

## 5. 증거 수준
AC-15·16·18·20 = 2, AC-17·19 = 3(실행본 `--check`).
