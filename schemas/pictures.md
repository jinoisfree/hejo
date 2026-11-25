# 사진 HTTP 계약

`GET`, `PUT`, `DELETE /v1/pictures/<employee|room|owner>/<id>`는 문의 기존 HTTP 출입증 인증을 사용한다. 다른 회원의 출입증은 401이다. 옛 `/v1/avatars` 경로는 없다.

- 직원: 명부의 `avatar`는 프로필 `assets/avatar.png`, 없으면 `assets/slack-avatar.png`를 읽는 주소다. `color`는 정규화한 색 또는 null이다. 선택 필드 `avatar_custom`은 avatar.png 존재 여부다. 필드가 없으면 앱은 사진 쓰기 메뉴를 숨기며, true일 때만 지우기를 보인다.
- 올리기: PUT 본문은 PNG 바이트이며 최대 512 KiB다. 초과는 413, PNG 서명·구조가 아닌 본문은 415다. 직원은 avatar.png만 원자적으로 쓴다(새 assets 폴더 0755, 파일 0644). 대체 사진·프로필 설정은 바꾸지 않는다.
- 공용 사진: room의 일반 id는 `shared/hejo/pictures/room-<id>.png`, `section-<id>`·`home-<id>`는 해당 접두어를 유지한 파일이다. 폴더 0700·파일 0600이며 앱 배치에는 주소만 저장한다.
- 사장: `owner/owner`만 허용하며 `shared/hejo/pictures/owner.png`에 저장한다. 폴더는 0700, 파일은 0600이다.
- 응답: PUT은 `{ok:true,picture:<주소>}`, DELETE는 `{ok:true,picture:null}`이다. 주소의 `v`는 서버 파일 수정 시각이다. 직원 PUT·DELETE 뒤 기존 roster 프레임을 모든 연결에 방송한다(`ref:picture`). 사장 사진 PUT·DELETE 응답에는 현재 `owner`도 있고, 모든 연결에 `ref:owner` roster를 방송한다.
- 읽기: GET은 인증 뒤 PNG를 돌려준다. 앱은 리디렉션과 외부 사진 주소를 거절하며 서버·접속 세대별 메모리 캐시만 사용한다. 명부 갱신 때 이전 사진 복제를 비운다.

사진 원본·메뉴 조건·수락 기준은 작업 명세 REQ-HF-23과 AT-HF-68을 따른다. 방 삭제와 그 방 사진 정리는 TASK-21에서 연결한다.

`GET /v1/owner`와 `PUT /v1/owner`는 같은 출입증 인증을 사용한다. PUT 본문은 `{"name": string|null}`이다. 앞뒤 공백을 뺀 최대 20자를 저장하며, 빈 이름과 null은 이름을 지운다. 줄바꿈·제어 문자·잘못된 입력은 400 `invalid_name`이다. 응답은 `{"ok":true,"owner":{"name": string|null,"avatar": string|null}}`이다. 이름을 저장하면 모든 연결에 `ref:owner` roster를 방송한다.
