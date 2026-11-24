# Workspace 명령 대응표 — TASK-03 선행 산출물

## 칸·원본·쓰기 주체·수명

[design.md](design.md)의 칸 배치를 따른다. 업무 코드는 기존 mail/calendar/files-docs/mac-apps 팩, 인증·refresh는 직원 Google 시설이 소유한다. 계정·토큰 사본을 만들지 않는다.

## 조사 근거와 범위

[확인] 설치된 본체의 google-workspace 스킬과 scripts/google_api.py를 읽기 전용으로 조사했다. 본체 파일은 수정하지 않았다. 조사한 google_api.py SHA-256: `c4e01550ab333fd1e5caf4f48bb60f9fd821397a854b6ddb9f41ddb197cfef2c`. 명령 24개는 실제 argparse 등록에서 추출했다. 인자 기본값·선택지·출력 형식은 해당 함수와 parser를 같은 변경에서 이식하며 GD-T09/T20 대역 시험으로 확인한다.

[확인] 스킬이 제시하는 업무 진입점은 google_api.py다. gws는 그 내부 backend이며 gws_bridge.py는 공용 토큰을 읽는 별도 helper다. helper의 임의 argv 전체를 새 기능으로 확대하지 않는다. Slides 전용 argparse 명령은 없고 기존 Slides 기능은 Drive의 메타데이터/다운로드/export에 포함된다. Contacts list는 실제 명령이므로 포함한다.

## 명령·인자·출력·새 위치

표의 인자는 기존 철자다. 새 직원 진입점만 직원/현재 binding을 검증하며 요청자가 자격 경로를 지정하지 못한다.

| 기존 명령 | 기존 인자 | 출력 계약 | 새 업무 어댑터 | 시험 |
|---|---|---|---|---|
| `gmail search` | `query`, `--max` | id/threadId/from/to/subject/date/snippet/labels 목록 | `hermes_packs.mail.google_workspace.gmail_search` | GD-T09/T20 |
| `gmail get` | `message_id` | id/threadId/from/to/subject/date/body/labels | `hermes_packs.mail.google_workspace.gmail_get` | GD-T09/T20 |
| `gmail send` | `--to`, `--subject`, `--body`, `--cc`, `--from`, `--html`, `--thread-id` | id/threadId/status | `hermes_packs.mail.google_workspace.gmail_send` | GD-T09/T20 |
| `gmail reply` | `message_id`, `--body`, `--from` | id/threadId/status | `hermes_packs.mail.google_workspace.gmail_reply` | GD-T09/T20 |
| `gmail labels` |  | id/name/type 목록 | `hermes_packs.mail.google_workspace.gmail_labels` | GD-T09/T20 |
| `gmail modify` | `message_id`, `--add-labels`, `--remove-labels` | id/labels | `hermes_packs.mail.google_workspace.gmail_modify` | GD-T09/T20 |
| `calendar list` | `--start`, `--end`, `--max`, `--calendar` | id/summary/start/end/location/description/status/htmlLink 목록 | `hermes_packs.calendar.google_workspace.calendar_list` | GD-T09/T20 |
| `calendar create` | `--summary`, `--start`, `--end`, `--location`, `--description`, `--attendees`, `--calendar` | id/summary/start/end/htmlLink/status | `hermes_packs.calendar.google_workspace.calendar_create` | GD-T09/T20 |
| `calendar delete` | `event_id`, `--calendar` | status | `hermes_packs.calendar.google_workspace.calendar_delete` | GD-T09/T20 |
| `drive search` | `query`, `--max`, `--raw-query` | files 목록(요청 fields 유지) | `hermes_packs.files_docs.google_workspace.drive_search` | GD-T09/T20 |
| `drive get` | `file_id` | 선택한 파일 메타데이터 | `hermes_packs.files_docs.google_workspace.drive_get` | GD-T09/T20 |
| `drive upload` | `path`, `--name`, `--parent`, `--mime-type` | id/name/mimeType/webViewLink/status | `hermes_packs.files_docs.google_workspace.drive_upload` | GD-T09/T20 |
| `drive download` | `file_id`, `--output`, `--export-mime` | id/name/mimeType/path/status; Docs/Sheets/Slides/Drawings export 포함 | `hermes_packs.files_docs.google_workspace.drive_download` | GD-T09/T20 |
| `drive create-folder` | `name`, `--parent` | id/name/webViewLink/status | `hermes_packs.files_docs.google_workspace.drive_create_folder` | GD-T09/T20 |
| `drive share` | `file_id`, `--role`, `--type`, `--email`, `--domain`, `--notify` | permissionId/role/type/status | `hermes_packs.files_docs.google_workspace.drive_share` | GD-T09/T20 |
| `drive delete` | `file_id`, `--permanent` | fileId/permanent/status | `hermes_packs.files_docs.google_workspace.drive_delete` | GD-T09/T20 |
| `contacts list` | `--max` | name/emails/phones 목록 | `hermes_packs.mac_apps.google_workspace.contacts_list` | GD-T09/T20 |
| `sheets get` | `sheet_id`, `range` | 2차원 values 배열 | `hermes_packs.files_docs.google_workspace.sheets_get` | GD-T09/T20 |
| `sheets update` | `sheet_id`, `range`, `--values` | updatedRange/updatedCells | `hermes_packs.files_docs.google_workspace.sheets_update` | GD-T09/T20 |
| `sheets append` | `sheet_id`, `range`, `--values` | updatedCells | `hermes_packs.files_docs.google_workspace.sheets_append` | GD-T09/T20 |
| `sheets create` | `--title`, `--sheet-name` | spreadsheetId/spreadsheetUrl/status | `hermes_packs.files_docs.google_workspace.sheets_create` | GD-T09/T20 |
| `docs get` | `doc_id`, `--tab` | 문서/탭 제목·본문·탭 목록; 다중 탭 선택 오류 유지 | `hermes_packs.files_docs.google_workspace.docs_get` | GD-T09/T20 |
| `docs create` | `--title`, `--body` | documentId/title/url/status | `hermes_packs.files_docs.google_workspace.docs_create` | GD-T09/T20 |
| `docs append` | `doc_id`, `--text`, `--tab` | documentId/characters/inserted_at/status | `hermes_packs.files_docs.google_workspace.docs_append` | GD-T09/T20 |

## 승인·권한·인증·refresh

- 기존 Workspace 스킬의 발송·이벤트 생성/삭제·Drive 삭제/공유·Docs/Sheets 수정 확인 문구와 시설의 역할·사장 대화·배경 쓰기 제한을 유지한다. 이식한 업무 함수가 스스로 승인됐다고 간주하거나 정책을 우회하지 않는다. 메일·일정의 기존 승인/undo 생산자는 기존 시설을 계속 사용하며 binding을 작업에 결합한다.
- 전환 직원은 직원별 request lease 안에서 시설이 제공한 Credentials만 쓴다. refresh 저장도 현행 binding 재검증 뒤 전용 봉투로 원자 교체한다. 공용 TOKEN_PATH·CLIENT_SECRET_PATH를 새 어댑터에 복사하지 않는다.
- SDK가 있는 기존 Python 분기를 보존한다. 기존 gws 분기는 평문 자격 파일을 요구하므로 이식 함수에서는 SDK 분기를 사용한다. 조사한 24개 명령에는 모두 SDK 구현이 있어 기존 명령을 제거하지 않는다. gws_bridge 직접 호출은 전환 직원의 경로에서 제거하고 본체 helper는 고치지 않는다.
- 계정 교체 전 승인/undo/worker의 binding이 현재와 다르면 새 계정으로 실행하지 않는다. 회사/미전환 직원의 원래 구현과 자격은 유지한다.

## 라이선스와 구현 전 판정

[확인] 본체의 MIT LICENSE는 복제·변경·배포를 허용하며 고지 보존이 조건이다. 이식하는 업무 함수와 argparse 계약의 출처·SHA-256을 이 문서에 남기고 원 라이선스 전문을 새 어댑터와 함께 보존한다. 본체 import 후 함수/상수를 바꾸는 runtime monkeypatch는 하지 않는다.

조사한 공개 명령에는 SDK 이전 불가 명령·본체 수정·권한 완화가 필요한 항목을 발견하지 않았다. TASK-03 업무 코드 작성 전에 이 대응표를 확정했다. 실제 소비자 전환·기능 보존 시험은 후속 구현이며 아직 통과를 주장하지 않는다. 추가 명령·호출자·계약 차이가 발견되면 해당 부분을 중단하고 기획에 보고한다.

## 구현 중 발견: 선택 스킬 실행 계약 보류

[확인] 위 ‘권한 완화가 필요한 항목을 발견하지 않았다’는 판정은 SDK 함수/라이선스 조사 범위였다. 실제 직원 스킬 terminal의 실행 권한 조사가 누락됐다. 현재 `hermes_governance/selected_skills.py::sandbox_argv` 및 `selected-skills-chat.sb`는 직원 skills/workspace 일부 이외의 공항 시설 코드·금고·전용 자격 읽기를 막는다. 조립 스크립트만 붙이면 새 어댑터를 실행할 수 없다.

실제 macOS sandbox 대역 시험 `tests/google_disconnect/test_skill_boundary.py`에서 스킬 사본 읽기 성공, 시설/가짜 금고/가짜 자격은 모두 거절을 확인했다. 로그: `.build/google-disconnect-evidence/task03-workspace-boundary-01.log` (종료 0, Workspace와 경계 30시험 통과). 기존 24개 명령의 SDK 출력 fixture는 확보했지만 제품 스킬 진입 완료를 뜻하지 않는다.

TASK-03의 중단 조건에 따라 공개 도구/호출 계약을 임의로 추가하거나 sandbox 권한을 완화하지 않는다. 권고와 선택지는 [impl-report.md](impl-report.md)의 중단 보고에 둔다. 승인된 계약을 받은 뒤 스킬·팩·승인/파일 제한을 함께 구현한다. 명세·AC 기대값은 변경하지 않았다.

## TASK-03A 실행 대응 확정 — 6판 승인 후

최신 handoff의 사용자 ‘시작’ 승인을 확인했다. 새 도구는 `hermes_execution.register` 내부 wrapper와 `scoped_context`로 등록한다. 실제 catalog 생성기는 현재 기준에 없으므로 기존 `hermes_facility/pack_selection.py`에 변경 네 팩의 선언→catalog 생성 함수를 둔다. 네 팩의 `pack.yaml` 도구 목록이 원본이며 대응 `plugin.yaml`과 `team-delegation/plugin.yaml`도 함께 갱신한다. 다른 팩의 기존 catalog 항목은 보존한다. manifest에 없는 도구나 미선택 팩을 handler가 다시 허용하지 않는다.

| command | 기존 권한 판정 | 새 등록 도구·팩 | 승인/파일 경계 |
|---|---|---|---|
| gmail search/get/labels | gmail_direct lookup/read | google_mail_workspace / mail | 기존 역할·개인 계정 범위 + selected_skills 소유자 조건 |
| gmail send/reply | gmail_direct send | 같은 도구 | 실제 기존 메일 승인 hook·발송 경로. 최종 typed 인자와 binding을 승인에 결합 |
| gmail modify | gmail_direct modify | 같은 도구 | 기존 full_mail_tools preview/실행/undo 경로와 권한을 유지. 원래 거절되는 직원에게 새 도구로 허용하지 않음 |
| calendar list | calendar_direct_lookup | google_calendar_workspace / calendar | 기존 개인 캘린더 범위. primary/자기 검증 계정만 허용 |
| calendar create/delete | calendar_direct_mutation create/delete | 같은 도구 | 기존 Calendar 승인·journal/undo 경로 재사용. 새 호환 쓰기는 실제 승인도 필수 |
| drive search/get, sheets get, docs get | doc_read | google_files_workspace / files-docs | 기존 역할/app/팩 허용과 selected_skills 조건의 교집합 |
| drive upload/share | file_link | 같은 도구 | 기존 외부 동작 권한·실제 승인. upload는 read_file 허용 경로를 고정 핸들로 사용 |
| drive create-folder | folder_create | 같은 도구 | 기존 파일 쓰기 역할/app 권한과 실제 승인 |
| drive delete | file_trash | 같은 도구 | 기존 삭제 권한·실제 승인. permanent 옵션도 같은 정확한 승인에 포함 |
| sheets update/append/create, docs create/append | doc_edit | 같은 도구 | 기존 문서 쓰기 역할/app 권한과 실제 승인 |
| drive download | doc_read + write_file | 같은 도구 | 기존 읽기/쓰기 허용 경로 모두 확인. 다운로드도 파일 쓰기 승인 대상으로 처리 |
| contacts list | contacts_direct_lookup | google_contacts_workspace / mac-apps | 기존 Contacts 직원/app 권한을 유지. 개인 Google 연결 자체로 Contacts 권한을 부여하지 않음 |

조립 원본은 기존 `shared/secretary-skills`에 직원용 Workspace 매뉴얼을 추가하고 `bin/hermes-skill-assemble`가 금고에 전환 항목이 있는 personal 직원에 한해 기존 google-workspace 안내 대신 이 매뉴얼을 조립한다. 조립 결과는 기존 `skills/`이며 계정/자격/허용 grant의 새 원본은 없다. 회사/미전환 스킬은 원래 조립을 유지한다. typed 도구 handler는 자신이 등록된 manifest·팩을 재검사하고 직접 호출은 native dispatch 증명 없으면 거절한다.

TASK-03A 구현 확인: 실제 등록 wrapper·승인 hook·실행 middleware·handler·직원 SDK를 연결한 시험과 실제 스킬 조립을 포함해 신규 격리 suite 156개가 통과했다. Calendar create/delete는 기존 네이티브 승인·변경/undo 장부를 사용하며 삭제 전 상태 및 etag를 재확인한다. 현재 개인 직원의 gmail modify는 기존 full_mail_tools의 회사 업무 전용 제한에 의해 API 전에 거절된다. 도구 노출이 기존 권한을 확대하지 않으며 SDK 24명령 보존과 모든 직원의 모든 명령 허용을 혼동하지 않는다. 업로드는 승인 당시 열린 파일/지문, 다운로드는 승인한 디렉터리 핸들과 안전한 파일 이름을 사용한다. 요청 계획에도 같은 파일 승인 시점과 binding을 저장한다. 증거와 남은 경계는 impl-report.md에 기록한다.
