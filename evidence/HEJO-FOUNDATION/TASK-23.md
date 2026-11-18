# TASK-23 운영 적용 기록 (2026-11-16, 계획 담당 + 사장)

## 1. 적용 전
- 사장 승인: "진행하자", "재시작해".
- 게이트웨이 상태: `active_agents 0`, 직원 프로필 6개.
- 백업(0700, 서버 `~/.hermes/hejo/backups/task23-20261116-200307/`):
  - `shared-hejo`: 기록장·첨부
  - `hejo-hub`: 허브 자료
  - `release-a4a80d5`: 그때 돌던 공용 릴리스
  - `install-receipt.json`
  - 원본과 `diff -rq` 결과가 같다.

## 2. 설치 갱신
- 공용 릴리스 RELEASE는 `aeaa652`다.
- `hejo-install --check`(설치 전) 결과: 홈 채널 빠짐이 6개였다.
- `hejo-install`(운영 갱신): 종료 0, 재시작은 하지 않았다.
  - 홈 채널 6개(기본 + 보조 5)를 넣었다.
  - 관리 기능 파일을 만들었다(영수증 admin `applied`).
- `hejo-install --check`(설치 후): 종료 0, 빠진 것 없음.

## 3. 재시작
- 허브와 게이트웨이를 launchd로 다시 시작했다.
- `gateway.log`에 `✓ hejo connected`가 6개 프로필 모두 찍혔다. Slack 연결도 정상이다.
- 문 포트는 루프백과 사설망에서 듣는다. 허브는 인증이 없으면 401이다.
- 관리 기능(`io.github.hermes-hejo.admin`)을 launchd에 등록했다.
  - 루프백에서만 듣는다.
  - 자식 프로세스는 0개다. 메시징 게이트웨이가 하나 더 뜨지 않았다(D1).
  - 보호 경로(`/api/env`·`/api/tools/toolsets`)는 토큰이 없으면 401이다.

## 4. 사장 실물 확인(대기)
- 각 Mac에서 hejo 앱을 다시 실행한다.
- TASK-22: 직원 새 세션의 첫 답에 홈 채널 안내가 없는지.
- TASK-24·20: 두 Mac에서 사진·배치·읽음이 맞는지.
- TASK-25: 분기, 중지, 되돌리기, 삭제.
- TASK-27: 홈 방.
- TASK-21: 직원 2명 단체방에서 @한 명, @없음, 삭제.
- TASK-32: 키 하나 넣기·되돌리기, 노트북에서 다시 시작.

## 롤백
1. `install/hejo-install --uninstall-home-channel`을 실행한다.
2. 관리 기능을 내린다(`launchctl bootout` 뒤 plist 제거).
3. 백업의 `shared-hejo`·`hejo-hub`를 복원한다.
4. `release-a4a80d5`를 공용 릴리스 자리에 복원한다.
5. 허브와 게이트웨이를 다시 시작한다.
