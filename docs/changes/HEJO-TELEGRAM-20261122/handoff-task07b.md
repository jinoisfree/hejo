# 설계 인계: HEJO-TELEGRAM / TASK-07b 앱 0.2.7(빌드 9) 공개 후보

```text
[설계 인계: HEJO-TELEGRAM TASK-07b / 앱 공개 후보]
0. 기준: 이 인계서를 담은 커밋(main). 승인: 사장 "지금해"(2026-11-23) — 텔레그램 설정 화면이 든 앱을 지금 공개 후보로 준비.
   HEJO-DRAWER-INLINE 계획 담당과 합의: 그 작업 4판 TASK-02는 main에 없음(구현 worktree 미커밋) → 이번 공개에 들어가지 않는다.
   운영 모드: 연합개발(교차 모델).
1. 공식 문서: tasks.md TASK-07b, verdict.md 2·5차, 선례 docs/changes/HEJO-DEADLINE-CLOSE-20261122/impl-report.md "TASK-05 앱 0.2.6"
   절(절차·검증·기록 형식을 그대로 따른다), install/hejo-publish, install/hejo-ship.
2. 요구: REQ-HT-07(앱)의 배포. 공개 후보 = 새 public 커밋 + 준비물(prepared.json, zip). 공개(push·publish)는 사장.
3. 유지할 계약: 업데이트 공개 키·코드 서명 Authority가 0.2.6과 같음. 공개 트리 gate/·schemas/·hub/·config/·install/ =
   공용 릴리스 실행본(RELEASE 0bcf63535df381e491c99af9cbef41179b7cd79f)과 바이트 동일. 설치된 앱(0.2.6)은 바꾸지 않는다.
4. 흐름: (1) 시작 조건 → (2) 개인값 정리 → (3) 버전 올림 → (4) public 커밋(install/hejo-publish, 원격 쓰기 차단 대역)
   → (5) 깨끗한 public checkout 검증 → (6) 기본 배포 빌드·hejo-ship prepare → (7) 사장용 명령 두 줄 기록.
5. 경로 판정: 새 경로 없음. 0.2.6 절차 유지.
6. 위험도: 고위험(공개). 필요 증거 수준 2(빌드·서명·시험). 롤백: 공개 전이면 public 커밋·준비물을 쓰지 않으면 됨.
7. 변경 성격: 배포 준비(제품 코드 변경 없음, 버전·문서만).
8. 수락 시험: 기존 전체 시험(scripts/test.sh 단계별) + scan_private 통과 + 선례의 서명·연속성 검사.
9. 절차:
   (1) 시작 조건: `git ls-remote github refs/heads/main` = 로컬 `public`(0.2.6 = 98a9f242a74a97a2af6885264cac49da241ad7fa)인지 읽기로 확인.
       main HEAD의 app·gate·hub·schemas·install·config 변경이 모두 검증 통과 작업의 것인지 커밋 목록으로 확인
       (HEJO-TELEGRAM, HEJO-DRAWER-INLINE TASK-01 18de43e까지, HEJO-DEADLINE-CLOSE 등 verdict 완료 작업). 판정 안 된 제품 변경이 있으면 멈추고 보고.
       gate·schemas·hub·install·config가 RELEASE 0bcf635와 다르면 멈추고 보고.
   (2) 개인값 정리: 임시 HERMES_HOME으로 Hermes venv `python scripts/scan_private.py`. 알려진 4건
       (docs/changes/HEJO-DEADLINE-CLOSE-20261122/impl-report.md 97·109행, verdict.md 127·146행 절대 경로)을 d88e2c8과 같은 방식의
       자리표시자로 바꾼다(뜻 유지, 문서만, 그 작업 계획 담당과 합의됨). 다시 검사해 종료 0. 다른 지적이 나오면 멈추고 보고.
   (3) 버전 올림 커밋: app/Resources/Info.plist 0.2.7·9, tests/acceptance/test_ship.py 현재 버전 단언 한 줄(선례 cec1f94와 같은 범위).
   (4) public 커밋: 선례대로 install/hejo-publish를 원격 git·curl·wget 차단 대역으로 실행, 부모 = 98a9f242, 트리 = main HEAD 트리.
   (5) 깨끗한 public checkout 검증(짧은 TMPDIR, 임시 HERMES_HOME, TZ=Asia/Seoul): pytest gate/tests tests/acceptance,
       gate.tests.gateway_delivery, bash app/scripts/test.sh. 선례의 환경 문제 1건(test_delivery_parity)이 나오면 기준에서도
       실패하는지 보이고 기록. 그 밖 실패는 멈춤.
   (6) 기본 배포 빌드 → install/hejo-ship prepare(.build/release-0.2.7/prepared.json). 압축 해제본 codesign·Sparkle sign_update --verify·
       Ed25519 공개 키 검증, 0.2.6 준비물과 공개 키 같음, 코드 서명 Authority 같음, 공개 트리 gate 등 = RELEASE 실행본 바이트 동일.
   (7) impl-report.md TASK-07b 절에 사장용 명령 두 줄(git push github <public>:refs/heads/main, install/hejo-ship publish
       --approve-commit <public> --prepared .build/release-0.2.7/prepared.json)과 공개 노트 초안
       ("아이메시지 설정을 텔레그램 설정으로 교체: 설정 → 연결과 동기화 → 텔레그램에서 코드를 받아 포럼 그룹에 보내면 방마다 토픽이 생깁니다")을 적는다.
   금지: git push, hejo-ship publish 실행, 설치된 앱 교체, 운영 설정·비밀 파일·Keychain 출입증 사용(서명 도구가 쓰는 서명 키체인은
   선례 범위 안), Hermes 본체·플러그인·team-kit 수정, 제품 코드 변경, 실제 메시지 발송.
   병렬 갈래: 없음(단일 배포 절차).
10. 가정·미확정: [가정] 0.2.6 절차의 도구·키가 그대로 쓸 수 있다. 다르면 멈추고 보고.
11. 사용자 확인: 사장 "지금해"(2026-11-23).
```
