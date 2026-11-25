# 등록 첨부 조회

기존 `GET /v1/files/{employee}/{file_id}` 및 HEAD는 출입증 인증 후 삭제되지 않은 Journal 첨부 등록과 실제 파일 경로를 확인한다.

`GET /v1/files/{employee}/{file_id}/metadata`는 동일한 인증·등록 확인을 거쳐 다음 JSON을 반환한다.

| 필드 | 형식·의미 |
|---|---|
| `file` | [wire의 file 정의](hejo-wire-v1.json)의 `file_id`, `name`, `mime`, `size`. 등록 descriptor를 그대로 반환한다. |
| `ts` | 등록된 원문 메시지의 timestamp 문자열. 다운로드 이름의 날짜에 사용한다. |

내부 경로·owner·기타 `_meta`는 반환하지 않는다. 미등록·삭제·다른 직원 소유·실제 파일 부재는 404, 인증 실패는 기존 파일 API와 동일하다. 메시지 본문은 반환하지 않는다.

앱은 metadata 응답을 16 KiB로 제한하고 descriptor·ID·날짜를 검사한다. 세션 또는 첨부 접근 generation이 바뀐 결과는 폐기하며, 다운로드/열기 시 기존 GET·HEAD 확인을 다시 수행한다. metadata 성공은 이후 파일 접근 권한을 보장하는 영구 허가가 아니다.
