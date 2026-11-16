## 검증 판정: 56917a17 / HEJO-FOUNDATION TASK-21 단체방

1. **판정:** 부분 완료. 차단 결함은 없다. 고위험 조건(비설계자 검토, TASK-23 실물 수준 4)이 남았다.
2. **검증 조건:**
   - 교차 모델이다(구현 codex gpt-6.1-sol, 검토 Claude Opus 5.5 계획 담당).
   - 검토한 코드는 `61a5548d61cc9e0547eafb1d0cd14f0c4651436c`(깨끗한 임시 worktree, 시험 의존 복사)이다.
3. **설계 적합성(4.2):** REQ-HF-24(14·19·27판)와 REQ-HF-29 28판을 충족한다.
   - 기록장(`gate/journal.py`):
     - `RECORD_TYPES`에 `room`·`room_delete`를 더했다(design 14판).
     - `replay` 처리:
       - `room_delete`는 `room_deleted {seq,id}`로 바꾼다.
       - 지운 방의 `room`은 `{id, deleted:true}`로, 그 방 `message`·`edit`·`state`는 같은 seq의 `delete`로 바꾼다.
       - `hidden`·`message()`도 지운 방을 가린다.
   - 연결별 투영(`server.project`): `rooms` 기능이 없는 연결에는 방 기록을 같은 seq의 `delete`로 보낸다(방 글은 msg_id, `room`은 `room:<id>`). sync·대기열·실시간 방송 모두 이 경로를 탄다. seq 없는 작성 중 표시는 그런 연결에 보내지 않는다. 27판대로다.
   - 방 명령(`gate/rooms.py`):
     - `room_save`: 제목, 직원 2명 이상·중복 없음, 대표가 구성원인지, 아는 직원인지를 검사한다.
     - `room_archive`도 있다.
     - `room_delete`는 한 줄 확정이다. 쓰기에 실패하면 `journal_write_failed`이고 아무것도 지우지 않는다. 확정 뒤 전용 첨부와 방 사진을 정리하고, 실패하면 시작할 때 다시 한다.
   - 사진: 방 사진은 방이 있을 때만 받는다(TASK-20 남은 위험 해소). 사진 쓰기가 성공했는데 기록 쓰기가 실패하면 이전 사진으로 되돌린다.
   - 전달:
     - 받는 사람은 방 구성원 중 @로 부른 직원이다(긴 이름 먼저, 겹침 제외). 아무도 안 부르면 대표다.
     - 문맥은 `gate/context.py`(20줄·4,000자·줄 500자)로, 받는 사람마다 마지막으로 받은 글 이후만 붙인다. 받은 직원 목록은 사장 글 `_meta.recipients`에 남긴다.
   - 앱: 방 관리 메뉴·창, @ 자동 완성, 삭제 캐시 치환, 28판 고정 채널 홈을 구현했다. 과거 보관 기록이 최신 고정을 지우지 않게 하는 회귀 시험도 더했다.
4. **직접 확인한 것:**
   - `foundation9_runner.py hejo`(61a5548): 종료 0, 164 passed, 앱·가짜 Hermes·통신 시험 통과.
   - 검토자 돌연변이 — 전달 대상에서 방 구성원 검사 제거: `gate/tests/test_rooms.py`가 1 failed / 6 passed로 잡았다(방 밖 직원 무시). 원복했다.
   - 실행 담당 돌연변이: 삭제 seq 치환 제거, 옛 연결 치환 제거, 과거 보관 고정 소거. 모두 검출됐다(`.build/task21/mutations.json`, `mutation-archive.json`).
   - 기존 시험 변경 5곳은 방 종류 추가에 따른 기대값 조정이다(HomeRoom·Pictures·Task17·ThreadTools). 승인 범위다.
   - 개인값·SwiftUI·알림 센터 API: 0(실행 담당 final-checks).
5. **지적:** 차단·비차단 없음.
6. **남은 위험·운영 주의:**
   - `room` 기록이 한 줄이라도 생기면 이전 문 코드는 기록장을 열지 못한다. TASK-23 롤백은 반드시 운영 `shared/hejo` 사본과 이전 릴리스를 함께 복원한다(design 15판). 이번 배포 백업은 이를 대신하지 않는다.
   - 실제 서버의 두 직원 방과 두 Mac 확인은 TASK-23에서 한다.
7. **원인 분류:** 결함 아님. 남은 것은 계획된 고위험 단계다.
8. **다음:** TASK-32(고위험).
