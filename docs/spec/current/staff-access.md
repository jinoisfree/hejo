# 현재 명세: 직원 · 가이드북 · 도구 창고(출입증)

- 적용: 2026-11-27, [HEJO-EQUIP](../../changes/HEJO-EQUIP-20261126/design.md), [ADR-0001](../../decisions/ADR-0001-staff-access-pass.md). 실행 위치는 운영 공항의 team-kit이며 hejo 앱·문은 이 값을 읽지 않는다.

## 원본과 조립 결과
| 정보 | 원본 | 조립 결과 |
|---|---|---|
| 직원이 들어갈 수 있는 창고 칸(출입증) | 명부 `owner/team.yaml` 직원별 `access` | — |
| 멘션 없는 새 글의 기본 담당 | 지시서 `owner/policy.yaml` `routing.default_responder` | — |
| 도구 검색 켜기 | 지시서 `tools.tool_search.enabled`(현재 `auto`) | 직원 `config.yaml` `tools.tool_search.enabled` |
| 칸의 도구 목록·필요 서비스 | `hermes_packs/<칸>/pack.yaml` | `hermes_packs/catalog.json`(`generate_catalog()`) |
| 칸이 필요한 Hermes 기본 도구 | `pack.yaml` `core_toolsets`, 도구 없는 칸은 `roles/<칸>/guide.yaml` | 직원 `config.yaml` `platform_toolsets.slack`·`hejo`의 기본 도구 항목(`hermes-config-assemble`) |
| 가이드북 | 스킬(`roles/<칸>/skills`, `shared/secretary-skills`) | 직원 `skills/` |

## 규칙
- 직책은 저장하지 않는다. 코드는 `team_registry`의 출입증 질문(`has_access`, `access_of`, `home_of_access`, `home_has_access`, `access_hint`, `agents_with`, `first_with`)만 쓴다. 옛 `roles` 키가 남은 명부 항목은 `access`가 있어도 출입증 0이다.
- 기계 검사(`airport-check`): `pack-catalog`(목록표 = 생성 출력), `roster-access`(옛 키 없음), `assembly:hermes-config-assemble`(직원 기본 도구·도구 검색 = 조립 결과).
- 계약 이름 예외: 서비스 이름 `role_roster`, 앱 연결 응답 필드 `"role_hint"`(문 허용 목록).
- 범위 밖(현재 직원 설정에 손으로 남은 것): photon·cron·cli 플랫폼 목록, `packs.enabled`.
