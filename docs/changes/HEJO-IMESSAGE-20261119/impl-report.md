# HEJO-IMESSAGE 구현 인계

## 착수 기준

- 인계: `handoff.md`, spec/design/수락 시험 2판, plan-review 2회차 해석. 연합개발, 고위험, 필요 증거 2(AT-HI-39는 3).
- 실제 hejo 착수 HEAD: `9b375d0e15dd87a3412c4f090eee3c7ea8a7d0e4` (`main`). 인계에서 이미 평가한 기준과 같음. 기존 변경 없음. 별도 worktree 없이 계획 담당 폴더에서 작업.
- 운영 저장소 착수 HEAD: `4f79decae030eb63f3f0f52e8c8517226748b876`.
- Hermes 본체 착수 HEAD: `ebb026eef8e800e1b7471ed147b7287e878f8aa4`, `git status --porcelain` 출력 없음(photon 포함).
- 판단: 부분 구현 / 보류(2절 보고 — TASK-02 재사용 코드 경계, TASK-05 전체 시험). TASK-02~06 구현·자체 시험만. TASK-07 운영 적용 및 TASK-08 실물은 미실행.
- 모든 갈래 직접 구현. 에이전트 위임 없음. 실행 로그는 추적하지 않는 `.build/HEJO-IMESSAGE/`에 보관.

## TASK-02: 규격·저장·짝짓기·설정

- 코드 커밋: `f187a0b`.
- 파일: `gate/imessage.py`(금고·설정·권위 판정), `gate/__init__.py`(photon 공장), `gate/adapter.py`(기본 어댑터 소유), `gate/server.py`(프레임 호출), `schemas/hejo-wire-v1.json`, `tests/acceptance/test_imessage.py`.
- 새 모듈은 설계의 네 책임을 소유한다. photon 인스턴스 처리기 감싸기는 플랫폼 간 경계이며 기존 안내원 처리기를 그대로 보존한다. 제거할 기존 경로 없음. 기록장 변경 없음.
- AT-HI-01~06,08~11,31: 실제 Hermes 모듈·문 서버·임시 홈·가짜 폰으로 통과(14개 pytest 사례). AT-HI-07의 수신·발신 포함 누출 검사는 TASK-04에서 실행 예정.
- 명세의 단체방 기호 G는 기존 wire의 UUID 규격을 지키는 고정 가짜 UUID 상수로 표현한다. 의미·기대 결과 변경 없음.
- 가정 확인: 실제 `PhotonAdapter._dispatch_inbound`를 초기화/네트워크 없이 실제 메서드로 실행하여 인스턴스 `handle_message`를 타는 것을 확인. 실제 BasePlatformAdapter의 `_is_sender_authorized` 호출·거절 확인. 두 가정 유지.
- 검증: Hermes venv + 본체 PYTHONPATH, `python -m pytest tests/acceptance/test_imessage.py -q -p no:cacheprovider` 종료 0, 14 passed, `.build/HEJO-IMESSAGE/task02.log`. 기존 경계 시험 18 passed, 종료 0, `task02-baseline.log`.
- 인증 mutation: 허용 거절 분기 반전 시 해당 수락 시험이 실패(내부 pytest 종료 1), 원복 뒤 위 14개 통과. `task02-mutation.log`.
- 도달 증거 2. 운영 photon 연결·실제 발신 미실행. 정착 시간 가정은 TASK-04에서 확인 예정.

## TASK-03: 수신·명령

- 코드 커밋: 이 절 직후 `git log -- gate/imessage.py`에서 확인 가능한 TASK-03 커밋(후속 절에 전체 해시 보충).
- `gate/imessage.py`: 활성 글의 반응/첨부/본문·답장·명령 판정, 응답 끝점 `ExternalReply`를 추가. `gate/adapter.py`: receive 성공 여부만 반환하도록 확장. 사장 글 기록·분배 경로는 기존 receive 하나다. 정상 앱 프레임은 그대로.
- 부작용 없는 권위 판정 예외는 원래 처리기로 통과한다. 코드 거절도 원래 객체로 통과. 감싸기 양 순서에서 중복 처리 없음.
- `python -m pytest tests/acceptance/test_imessage.py gate/tests/test_rooms.py gate/tests/test_boundaries.py -q -p no:cacheprovider`: 종료 0, 49 passed. 로그 `.build/HEJO-IMESSAGE/task03.log`, 증거 2.
- AT-HI-12,13,16~21,32 통과. AT-HI-14,15는 발신 대응을 포함하므로 TASK-04에서 마무리. 새 수락 코드의 가짜 명부에는 소유자 허용 환경을 설정하고 실제 비동기 배달 완료를 기다린다.
- 설계 변경·기존 시험 변경 없음. 스레드 선택은 기록장과 sent 대응만 조회한다. 중요 발신·정착 검증은 다음 절에서 수행.

## TASK-04: 발신·정착

- TASK-02 전체 커밋: `f187a0bd99cbc7c433c930ac8e7e68f044fcab5b`, TASK-03: `79bae23daaf399752fda9a0d2fc3c1272624beae`.
- 파일: `gate/imessage.py`, `gate/adapter.py`, 수락 시험 코드, `gate/tests/imessage_settling.py`. 새 기록 뒤 별도 작업이 정착을 기다린다. 실제 폰 전송은 publication lock 밖이다. 시작 전에 기록한 글은 후보로 복구하지 않는다. 기록장 종류·형식 변경 없음.
- 의미 추가: 활성 폰 스레드/폰 보고 방의 남은 직원 글을 발신. 기존 앱·직원 전송은 유지. 실패·삭제 실패·늦은 삭제를 포함해 두 임시 홈의 기록장 및 앱 프레임 동일 비교를 통과했다.
- 문자 수 분할(줄바꿈 선호), 이름표·선택/첨부 안내, 최근 폰 사장 글 답장, fsync한 sent 대응과 재연결, 실패 1회·무재시도 검증. 진행 글 추측 분류는 없음. context.thinking만 제외.
- `python -m pytest tests/acceptance/test_imessage.py -q -p no:cacheprovider`: 종료 0, 40 passed, `.build/HEJO-IMESSAGE/task04.log`. AT-HI-01~32(33·34는 team-kit, 35~37 앱, 38 최종 전체 검사),39,42의 문 책임을 코드로 확인했다. AT-HI-07의 두 앱·로그·파일 누출 검사 포함. 도달 증거 2, AT-HI-39는 3.
- AT-HI-39: `python -m gate.tests.imessage_settling` 종료 0. 임시 홈 실제 gateway/차례 runner/worker/기록장/진행 정리 경로, 모델만 대역. 5회: 0.009550042, 0.009642000, 0.023444417, 0.008650333, 0.022970584초. 최댓값 0.023444417 < 2초, 가정 유지. `.build/HEJO-IMESSAGE/task04-settling.log`.
- 최초 측정 실행은 기존 시험 도우미의 PyYAML 부재로 실패. 과거 전체 시험에서 쓴 추적 안 하는 `.build/task03a-deps`·`.build/task02-deps`를 PYTHONPATH에 더했다. Hermes venv는 그대로 사용하고 설치·운영 환경을 수정하지 않았다. 모델 callback 속성 연결을 바로잡은 뒤 위 측정 통과. 실패한 측정은 가정 검증 근거에 포함하지 않는다.
- 중요 정착 mutation: 작성 중 검사를 제거하면 AT-HI-25 실패(내부 pytest 종료 1), 원복 뒤 위 40개 통과. `.build/HEJO-IMESSAGE/task04-mutation.log`.
- 미검증: 운영 환경 적용·실제 폰은 TASK-07/08. 코드 검토는 계획 담당에게 남음. 근간/명세/수락 명세 변경 없음.

## TASK-02·04 추가 자체 점검

- TASK-04 본 커밋: `d98b2906b082f6f3fa19416495b79d92106095fe`.
- TASK-02 보완 `8a60570`: 조회 때 불필요한 디렉터리/잠금 파일 생성을 없애고, 붙어 있으나 끊긴 photon을 사용 가능으로 표시하지 않는다. 원자적 교체 파일의 읽기는 읽기만, 쓰기는 기존 잠금+원자 교체를 유지. `task02-followup.log`: 종료 0, 40 passed·1 deselected(수정 범위 밖 AT-HI-39만 제외).
- TASK-04 보완 `b48109d`: 발신 순간에도 문 연결 상태 확인, reply/native 버튼이 함께 있는 글에는 두 안내를 모두 보존. `task04-followup.log`: 종료 0, 41 passed·1 deselected. 최종 전체 검사는 아래에 별도 기록.

## TASK-05: team-kit 양보 — 보류(2절 보고)

- 구현 후보: `lib/hermes_router/ingress.py`의 감싼 처리기 첫머리에서 photon/bluebubbles일 때 hejo의 claims_external을 조회. 참이면 분류/소유권 쓰기 없이 원래 처리기를 호출. 없음/거짓/판정 예외는 기존 경로. 원래 처리기 자체의 예외는 다시 분류하거나 두 번 호출하지 않는다.
- AT-HI-33 집중: 임시 HERMES_HOME/HERMES_ROOT + 실제 Hermes 모듈, `python -m pytest <TKL>/tests/test_router_hejo_imessage.py -q -p no:cacheprovider` 종료 0, 17 passed. `task05-focused.log`. 실제 source.profile 불변, Slack 불변, 그림자 모드 선행 양보, 원래 처리기 예외의 1회 호출을 확인.
- AT-HI-34 전체: `python -m pytest <TKL>/tests -q -p no:cacheprovider` 종료 1, 1 failed·5154 passed·4 skipped·58 subtests passed. `task05-full.log`. 실패 위치: `tests/test_all_profile_prompt_budget.py`의 동적 마감 안내 포함 길이 제한(프로필 한 건에서 7771 > 7600). 실제 입력·기대값은 고치지 않았다. 변경 전 대조는 미실행이며 기존 실패로 확정하지 않는다.
- 실행상 잘못: 첫 전체 실행에 임시 HERMES_HOME을 지정하지 못했다. 이후 실패 시험의 `ROOT = Path.home()` 기반 운영 홈 직접 읽기를 소스에서 확인했다. 임시 HERMES_HOME만으로 이 시험의 운영 설정 읽기를 격리할 수 없어 재실행하지 않았다. 비밀 파일을 직접 열거나 값을 보고서에 옮기지 않았다.
- 멈춤 근거: 필수 기존 전체 시험 불통과 + 운영 홈 읽기 금지와 기존 시험 입력의 충돌. 운영 저장소 AGENTS의 ‘실패가 있으면 커밋·푸시·재시작을 하지 않는다’에 따라 ./sync·./airport-check·운영 저장소 커밋을 하지 않았다. 따라서 TASK-05는 구현 완료가 아니다.
- 원본 보존: 시험 뒤 자기 수정 블록을 제거한 내용이 운영 저장소의 추적 원본과 바이트 단위로 같은지 확인한 뒤 TKL ingress를 복구하고 새 시험 파일을 제거했다. 다른 변경은 없었다. 후보 두 파일은 `.build/HEJO-IMESSAGE/team-kit-candidate/`, 차이는 `task05.patch`, 해시·복구 증거는 `task05-candidate.json`에 남았다. 후보는 아직 운영 저장소에 동기화/커밋되지 않았다.
- 선택지: 계획 담당이 운영 홈을 읽지 않는 정식 전체 시험 환경과 가짜 명부/정책 입력을 확정하거나, 이 운영 자료 시험의 허용 범위를 사용자에게 확인해야 한다. 길이 제한을 늘리거나 skip하는 방식은 구현자가 선택하지 않았다. 권고: 임시 홈 시험 환경부터 확정한 뒤 후보를 다시 적용하고 전체 시험 → sync → airport-check → commit-only 순서로 재개.
- 진행 가능한 독립 범위: TASK-06 앱 및 hejo 자체 전체 검사. 운영 적용 TASK-07은 여전히 금지.

## TASK-02 추가 인증 경계 — 보류(2절 보고)

- 발견: `enabled:true`인 기존 짝에서 새 코드를 발급 → 같은 대화창에서 재짝짓기 → 소진된 코드를 새 글 id로 다시 보내면 기록장에 사장 글이 생긴다. 코드 평문이 기록장·앱 message로 갈 수 있다. 운영 환경은 사용하지 않았다.
- 근거: `gate/imessage.py`의 `claims_external()`은 pending_code가 아니면 활성+짝 일치로 참을 답하고, `receive_external()`은 소진된 코드를 일반 글로 `receive()`에 넘긴다. design 5절의 현재 순서를 그대로 따른 결과다.
- 추가 진단: `python -m pytest .build/HEJO-IMESSAGE/test_pair_replay_diagnostic.py -q -p no:cacheprovider` 종료 1, 1 failed. `.build/HEJO-IMESSAGE/pair-replay-diagnostic.log`. 임시 홈·실제 문·가짜 폰, 재전송 전후 journal.head 0 → 1. REQ-HI-01.AC-02(재사용 코드는 원래 처리기로) 및 코드 비노출 제약과의 충돌을 재현했다. 공식 AT-HI-02 번역 시험은 비활성 초기 짝짓기 뒤 재사용만 다루므로 이 경우를 잡지 못한다.
- 멈춤: 설계의 판정 순서·REQ-HI-06의 ‘활성+짝 일치면 참’과 재사용/비노출 요구 사이의 우선순위를 구현자가 임의로 바꾸지 않았다. 이 인증 경계는 미해결이며 TASK-02를 구현 완료로 판단하지 않는다. 표준 시험 통과 여부와 별개다.
- 선택지/권고: 저장된 코드 해시에 맞는 만료·소진 코드에는 활성 대화보다 먼저 통과 판정을 적용하도록 설계·claims 계약을 명확히 하고, 활성 재짝짓기/만료 재전송을 수락 시험에 포함하는 보완 계획을 권고한다. 이전 코드가 새 코드 발급으로 덮인 뒤의 비노출 범위도 함께 명확히 해야 한다. 원래 처리기를 직접 우회 호출하는 임시 경로, 코드 모양 추측, 코드 이력 저장은 추가하지 않았다.
- 기다리는 동안 진행: 독립적인 앱 TASK-06 검증 및 hejo 표준 전체 검사. 운영 적용/푸시 제안은 하지 않는다.

## TASK-06: AppKit 앱

- 코드 커밋: `97f42e3b47a6f227d3188a8cd2e1a872c9334065`.
- `IMessageState.swift` 한 모델이 GateClient의 임시 연결 상태를 소유한다. 설정 구역과 1:1/단체방 메뉴는 이 모델을 읽는다. 별도 설정 저장/기록장 사본 없음. hello 기능 표시와 최초 조회, 상태/코드 수신, 조회·코드 받기·해제·저장 전송을 연결했다.
- UI: 기존 ‘연결과 동기화’ 탭 안 AppKit 구역. 코드 복사(시험은 고유 시험 pasteboard), 만료 시간, 켜기, 방 선택, 연결 해제, 지원하지 않는 서버/아이메시지 문 없음 표시. 서버 확인 전에는 설정 값을 낙관적으로 바꾸지 않는다. SwiftUI 예외 없음.
- 파일: `app/Sources/{GateClient,IMessageState,SettingsPages,PetSettingsWindow,RoomMenus,RoomDialogs,ConversationController,ConversationView,AppDelegate}.swift`, `app/Tests/IMessageTests.swift`, TestMain 및 선택 기능 조회를 받는 기존 시험 서버 6개와 `legacy_feature_fixture.py`.
- 기존 시험 서버는 새 선택 기능 조회에 error(unexpected_frame)를 답하고 나머지 대화/동기화 검증을 그대로 수행한다. 기대하는 글/전송 횟수·동기화·제어 기준은 변경하지 않았다. 관련 없는 오류까지 건너뛰지 않는다. 이 응답을 모델에서 소비하여 대화 제어/오류 처리에 섞이지 않게 했다.
- AT-HI-35~37: 실제 AppKit controls/메뉴와 모델에 프레임을 적용한 시험 통과, `AT-HI-35~37 PASS`가 최종 full.log에 있다. 코드 영역의 짝짓기 후 숨김, 복사/카운트다운, 원격 변경, 메뉴 체크/각 전송 프레임, 기능 미지원, 전송 문 없음, 연결 종료 시 초기화를 검사. 도달 증거 2.
- 첫 앱 전체 실행은 옛 시험 서버가 새 조회를 대화 제어 요청으로 받아 실패했다(`task06-app.log`, 종료 1). 이 서버 계약을 보완하고 최종 전체 시험을 통과했다. 첫 독립 앱 빌드는 종료 0(`task06-build.log`).
- UI가 단순 서버 상태 투영이라 별도 mutation은 생략했다. 인증/정착 중요 조건의 mutation은 위 TASK-02/04에 기록했다.

## 최종 자체 검증과 인계 상태

- 판단: **부분 구현 / 보류(2절 보고)**. TASK-03·04·06은 구현·자체 시험 완료(독립 검토 전), TASK-02는 활성 재짝짓기 코드 재전송의 비노출/claims 설계 쟁점, TASK-05는 전체 시험 불통과와 운영 홈 직접 읽기 충돌로 보류. 최종 제품 완료/배포 가능 판정이 아니다.
- hejo 표준 전체: Hermes venv의 HEJO_PYTHON으로 `bash scripts/test.sh`, 임시 HERMES_HOME/HERMES_ROOT·실제 team-kit 라이브러리 경로 사용. 종료 0, Python 317 passed·기존 warning 1개, 임시 게이트웨이 배달, 앱 서명/단위·화면·통신/파일/제어 회귀와 hooks 9개 통과. `.build/HEJO-IMESSAGE/full.log`, 명령/종료 코드/검증 입력은 `checks.json`. 앱·문 소스와 시험 입력이 실행 중 불변임을 확인하고 동일 파일을 TASK-06 커밋에 담았다.
- 앞선 전체 시도 2건은 환경 구성 실패였다. `full-environment-failure.log`: 종료 1, 선택 team-kit 라이브러리 경로 누락으로 1 failed·316 passed. `full-signing-environment-failure.log`: 종료 1, 317 passed 후 임시 HOME에서 서명 인증서를 찾지 못함. 실제 HOME은 인증서 검색·기존 메타데이터 guard에 유지하고, 시험용 HERMES_HOME/HERMES_ROOT는 임시 경로로 둔 최종 실행이 위 종료 0이다. 운영 설정을 읽는 team-kit 예산 시험은 이 hejo 표준 명령에 포함되지 않는다.
- 최종 AT-HI-39 재측정: `python -m gate.tests.imessage_settling` 종료 0, 0.008841667·0.006117416·0.006237250·0.006504208·0.017106709초. 최댓값 0.017106709 < 2초. `.build/HEJO-IMESSAGE/task04-settling-final.log`. 정착 시간 가정 유지(증거 3).
- AT-HI-38: 본체 최종 HEAD `ebb026eef8e800e1b7471ed147b7287e878f8aa4`와 clean status가 착수 시와 같다(photon 포함). 운영 저장소도 clean. `.build/HEJO-IMESSAGE/protected-state.json`. 앱 시험의 실제 CLI 설정/Downloads 메타데이터 guard도 최종 로그에서 불변을 확인했다(내용 미열람).
- 개인값 검사: Hermes venv + 임시 HERMES_HOME으로 `scripts/scan_private.py`, 종료 0. 최종 문서까지 포함한 검사도 종료 0이며 `private-final.log`에 있다. 실제 운영자 명부/금고를 입력으로 하는 검사는 실행하지 않았다.
- 별도 추가 인증 진단은 여전히 종료 1이다(`pair-replay-diagnostic.log`). 위 표준 전체 통과가 이 미해결 경계를 덮지 않는다. 이 진단과 team-kit 실패 때문에 전체 수락 완료를 선언하지 않는다.
- 커밋 경계: TASK-02 `f187a0bd99cbc7c433c930ac8e7e68f044fcab5b`, TASK-03 `79bae23daaf399752fda9a0d2fc3c1272624beae`, TASK-04 `d98b2906b082f6f3fa19416495b79d92106095fe`, TASK-02 보완 `8a6057042c0164761162d28912a6e2f974cdc340`, TASK-04 보완 `b48109d5dbec1775960a1cbaf76687978e9b299f`, TASK-06은 위 전체 해시. TASK-05 운영 저장소 커밋 없음. 추가 증거 문서 커밋은 코드 변경을 포함하지 않는다.
- 독립 검토 요청: 활성 코드 재사용/만료의 권위 판정 우선순위, 코드 비노출 범위, 방 삭제/보관 뒤 상태 전파, 정착 작업 취소/전송 순서, 선택 기능 오류의 대화 경로 분리. 방 삭제/보관 뒤 새 상태 방송은 현재 소스에서 직접 연결되어 있지 않아 추가 검토가 필요하다(이 경계의 추가 실행은 미실행).
- 새 범위 밖 제품 변경 없음. 운영 게이트웨이 재시작/reload, 릴리스 설치, 설치된 앱 교체, 실제 아이메시지/Slack 발송, git push는 하지 않았다. TASK-07/08 및 근간 반영은 미실행.
- 다음 담당: 이 문서의 두 ‘보류’ 절과 실제 코드/로그를 읽고 보완 설계와 전체 시험 환경을 확정한 뒤 구현을 다시 인계한다. TASK-05 후보는 실행 원본에 남아 있지 않으므로 승인된 보완에서 candidate 두 파일을 복원해야 한다. 원래 목표는 앱/폰에서 바꿀 수 있는 연결 방 하나와 그 방 직원의 폰 답장이다.


## 보완 1: 구현 검토 1차 반영 (2026-11-20)

- 최신 판단: **배정된 보완 구현·자체 시험 완료, 계획 담당 재검토 대기**. 앞 절의 V-1~V-5 보류는 이 절의 보완 결과로 갱신한다. TASK-05 운영 저장소 반영은 여전히 사용자 결정 대기이며 제품 최종 완료가 아니다.
- 실제 착수 HEAD: `5bd360b6973d9f2cb15eaabc57e2d582f1263604`(`main`, 변경 없음). 인계된 3판 및 verdict 1차와 일치했다. 코드 커밋: `e23a9312d979be6e8c21e8101a7e8af605345aff`. 아래 시험의 소스 3개 SHA-256이 이 커밋과 같음을 확인했다(`supplement1/full.json`).
- 근거 문서: handoff의 보완 지시 1, spec/design/수락 시험 3판. 명세·설계·수락 시험 문서와 기록장 형식 변경 없음. 계획에서 달라진 제품 동작·공개 계약 없음. 이번 문서 커밋은 이 보고와 tasks 상태 칸만 포함한다.

### 지적별 변경

| 지적 | 고친 위치와 결과 | 수락 증거 |
|---|---|---|
| V-1·V-2 | `gate/imessage.py`의 `claims_external`: 남은 코드 해시 일치를 활성 짝보다 먼저 판정하고 쓰임·만료·실제 문의 발신자 허용 검사를 포함. `attach_photon`은 이 답만 사용하며 별도 허용 검사 제거. 코드 이력·모양 추측·원래 처리기 우회 호출 없음 | AT-HI-31 보강, AT-HI-43 신규. 두 감싸기 순서에서 쓰인·만료·허용 거부 코드는 같은 이벤트로 원래 처리기·가짜 안내원 분류 각 1회, 기록·직원 이벤트·발신·앱 message 0, 이어지는 보통 글 정상 |
| V-3 | `IMessage._load_sent`: 손상 줄을 건너뛰고 뒤의 유효 줄도 색인. 덜 쓰인 꼬리만 절단, 완결된 손상 중간 줄 보존. `_private`·`_settings`는 JSON/구조/읽기 오류에 안전한 비활성 값을 사용하며 손상 연결 파일이면 모든 외부 글 통과·발신 차단 | AT-HI-44 신규: 세 파일 각각 손상 뒤 실제 `connect()` 성공, 앱 사장 글·직원 답 정상. 유효 sent 대응 두 개 모두 원래 스레드로 답장 |
| V-4 | `gate/rooms.py`의 `RoomCommands.room_command`: 방 기록 전후 실효 상태를 비교하고 달라졌을 때 상태 방송 | AT-HI-11 보강: 삭제·보관 각각 두 앱에 ref 없는 상태 1개, 조회 결과도 일치 |
| V-5 | `attach_photon`의 차지한 글 처리 경계: 예상 밖 예외를 잡아 종류만 로그 한 줄, 실패 안내, 원래 처리기로 재전달하지 않음 | AT-HI-19 보강: 기록장 실패·크기 초과·RuntimeError 각각 행/직원 이벤트/원래 처리기 0, 안내 1, 다음 글 정상. RuntimeError 본문·식별자 로그 노출 0 |
| V-6 | team-kit 기존 시험은 그대로 두고 임시 HOME/HERMES_HOME에서 후보 적용 전후 전체 시험 비교. 원래 운영 자료 길이 문제를 고치지 않음 | AT-HI-33 집중 17개 통과, AT-HI-34 실패 집합 동일·통과 수 감소 없음. 아래 환경 한계 참조 |

### 실행한 검증과 로그

공통 환경은 Hermes venv `HEJO_PYTHON`, 실제 Hermes 본체 모듈, 임시 `HERMES_HOME`/`HERMES_ROOT`, 가짜 아이메시지 어댑터다. 전체 hejo 시험에는 실제 team-kit 라이브러리도 사용했다. 로그 접두어는 추적하지 않는 `.build/HEJO-IMESSAGE/supplement1/`다.

| 명령 | 실제 결과 | 로그 |
|---|---|---|
| `"$HEJO_PYTHON" -m pytest tests/acceptance/test_imessage.py -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` | 첫 실행 종료 1(49 passed, 1 failed). 시험 코드에서 기존 방 삭제 프레임 이름을 잘못 적음. 기존 `room_deleted` 이름으로 바로잡은 뒤 종료 0, 50 passed | `focused.log`, `focused-final.log` |
| 위 명령에 `-k at_hi_43`, 쓰인 코드 반환만 False → True로 변이 | pytest 종료 1, 두 감싸기 순서 모두 실패(2 failed). 유효 코드 발급·짝짓기를 통과한 뒤 재사용 경계에서 실패함. finally로 원복 후 같은 명령 종료 0, 2 passed | `mutation.py`, `mutation.log`, `mutation.json`, `mutation-restored.log` |
| `bash scripts/test.sh` | 종료 0. Python 325 passed(기존 warning 1), 실제 임시 게이트웨이 배달, 앱 빌드·서명·단위/화면(AT-HI-35~37)·통신 회귀, hooks 9개 통과. 실제 CLI 설정은 내용 없이 메타데이터만 확인, Downloads 이름 불변 | `full.log`, `full.json` |
| `"$HEJO_PYTHON" scripts/scan_private.py` | 코드 변경본 종료 0. 임시 홈 사용, 운영 명부·금고를 읽지 않음. 문서 추가 뒤 최종 결과는 `private-final.exit`에 기록 | `private-code.log`, `private-code.exit`, `private-final.log`, `private-final.exit` |
| `"$HEJO_PYTHON" .build/HEJO-IMESSAGE/supplement1/team-compare.py`(로컬 증거 실행기) | 종료 0. 아래 전후 비교·집중 시험·원복 검증을 모두 확인 | `team-run.log`, `team-comparison.json` |
| `git diff --check` | 종료 0 | 별도 파일 없음 |

### TASK-05 전후 비교와 원복

- `.build/HEJO-IMESSAGE/team-kit-candidate/`의 `lib/hermes_router/ingress.py`와 새 `tests/test_router_hejo_imessage.py` 두 파일만 실행 원본에 임시 적용했다. 적용 전에 원본 바이트를 보관하고 finally에서 그대로 복구했다.
- 같은 임시 HOME·HERMES_HOME, 같은 Python·의존성·기존 시험 파일로 `"$HEJO_PYTHON" -m pytest tests -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function --junitxml=...`를 전후 한 번씩 실행했다. 기존 team-kit conftest의 명부·금고·정책 fixture를 사용하고 운영 홈 연결은 만들지 않았다. 기존 시험의 skip/xfail/기대값을 바꾸지 않았다.
- 적용 전: 종료 1, **30 failed, 4894 passed, 64 skipped, 1 error, 58 subtests passed**(`team-before.log`/`.xml`). 집중 시험: 종료 0, **17 passed**(`team-focused.log`/`.xml`). 적용 후: 종료 1, **30 failed, 4911 passed, 64 skipped, 1 error, 58 subtests passed**(`team-after.log`/`.xml`). JUnit의 실패+오류 시험 이름 집합 31건이 동일하고 새 실패 0, 기존 통과 감소 0이다. 전체 통과를 주장하지 않는다.
- 환경 한계: 운영 자료·운영 도구를 임시 HOME에 복사하거나 연결하지 않아 프로필 config/SOUL·문서 도구·유지보수 스크립트 등에 의존하는 시험이 양쪽에서 동일하게 실패/생략됐다. 특히 `test_all_profile_prompt_budget.py::test_current_profiles_worst_context_with_dynamic_deadline`는 설정 자료 없음으로 실패했으며, 기획 담당이 확인한 운영 자료 길이 7771 > 7600 실패를 이번에 다시 측정한 것은 아니다. 모든 실패 이름과 원인은 위 로그/JUnit, 집합 비교는 `team-comparison.json`에 남겼다. 이번 증거는 격리 환경의 회귀 없음이며 운영 자료의 정상성 증거는 아니다.
- 복구: ingress SHA-256 전후 `00b81caceb75aa7510cc18bf2f9709e8d6231790e8e0aa3091725469441fcec4` 동일, 새 시험 파일 없음. 실행기 `restored:true`. 후보·운영 저장소·실행 원본을 혼동하지 않는다. 운영 저장소 HEAD는 기존 `4f79decae030eb63f3f0f52e8c8517226748b876`, 변경 없음.
- 추가 읽기 전용 비교: 운영 사본의 시험/ingress 224개 중 runtime의 `tests/test_hejo_work_wait.py`만 다르며, 이 파일은 작업 전 TASK-55 보관본과 동일했다. 이 작업은 해당 파일을 수정하지 않았다. 본체 HEAD·상태도 기존 그대로다. 상세 `protected-final.json`.
- `./sync`, `./airport-check`, 운영 저장소 커밋은 하지 않았다. 기존 실패에 대한 사용자 결정이 있어야 진행한다.

### 남은 일과 검토 요청

- 계획 담당이 이 코드 커밋과 로그를 읽고 V-1~V-5 및 V-6의 격리 비교 한계를 재검토한다. 자체 시험은 독립 검토가 아니다.
- TASK-05 운영 반영은 기존 실패를 먼저 고칠지/예외를 허용할지 사용자 결정 뒤 별도 지시가 필요하다. 운영 적용 TASK-07, 비설계자 검토, 폰 M1~M8의 TASK-08은 미실행이다.
- 이번 범위에서 게이트웨이 재시작/reload, 릴리스 설치, 설치 앱 교체, 운영 설정·비밀 접근, 본체/photon/ddots 변경, 실제 아이메시지·Slack 발송, git push는 하지 않았다. 원래 목표는 앱과 폰에서 연결 방 하나를 바꾸며 그 방 직원이 답하는 기능이다.


## 보완 2: 기존 길이 실패 해소와 TASK-05 반영 (2026-11-20)

- 최신 판단: **TASK-05a·TASK-05 구현·자체 시험·운영 저장소 커밋 완료, 계획 담당 재검토 대기**. 앞 절의 사용자 결정 대기는 사용자의 ‘기존 실패 먼저 고치기’ 결정과 이 절의 결과로 갱신한다. 서버 적용·최종 제품 완료 판정은 아니다.
- hejo 착수 HEAD: `18b350e1437b03aebebc0f2e66d7c2bb378438d1`. 운영 저장소 착수 HEAD: `4f79decae030eb63f3f0f52e8c8517226748b876`. 두 작업 트리는 착수 시 깨끗했다. hejo 제품 코드는 변경하지 않았다. 기존 보완 1의 검토 수락을 유지한다.
- TASK-05a 커밋: `a6bb1e58d89d130e42e21852c1b06f24682d6c94` — `hermes/plugin-store/team-kit/lib/hermes_packs/notion/api.py` 한 파일만.
- TASK-05 커밋: `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495` — `hermes/plugin-store/team-kit/lib/hermes_router/ingress.py`, `hermes/plugin-store/team-kit/tests/test_router_hejo_imessage.py` 두 파일만. 실행 원본에서 고친 뒤 `./sync`로 수집했고, 모두 `git commit --only`로 나눴다. 두 커밋의 pre-commit 스냅샷 검사도 통과했다. source/commit 경로별 바이트 일치 확인.
- 증거 수준 3: 정식 Hermes venv Python·실제 HOME의 운영 자료·기존 team-kit conftest fixture를 사용하는 시험이다. 이전 보완 1의 빈 임시 HOME 비교와 다르다. 명시된 기존 시험이 운영 자료를 읽는 것 외에 운영 설정·비밀 파일을 직접 열거나 바꾸지 않았다.

### 원인 조사와 다듬기 범위

- 직접 재현: `tests/test_all_profile_prompt_budget.py::test_current_profiles_worst_context_with_dynamic_deadline`의 대상 프로필 Slack 합계 **7771 > 7600**, 종료 1(1 failed, 7 passed).
- `git log -p`·`git blame` 확인 결과, 선택한 Notion full API 안내문은 최근 두 커밋에서 늘어난 문구가 아니었다. 최근 운영 저장소 커밋 `4f79decae030eb63f3f0f52e8c8517226748b876`의 대상 프로필 학습 규칙 증가를 기존 `learning.rule_lines`·`GUIDANCE`의 순수 렌더 규칙으로 계산하면 `team-kit.learned`가 **843 → 1022(+179)**다. 현재 다른 구역을 고정한 계산상 이전 합계는 7592이고 현재 합계는 7771이다. 과거 전체 시험을 다시 실행한 수치는 아니다. ‘최근 고정 안내문 보강’이라는 초기 추정과 달리 학습 구역의 증가를 확인했다(`rules-history.log`, `history-sizes.json`).
- 구현은 지시된 한 프로필의 안내문 다듬기 범위에서 **`team-kit.notion` full API 분기 한 구역**을 선택했다. 그 구역은 대상 프로필에만 실리며, 다른 프로필 15개 문맥의 전후 결과는 동일하다. 학습 규칙·입력·한도·시험·다른 안내문 분기·동작 코드는 변경하지 않았다.
- 원본: 실행 중인 team-kit의 `lib/hermes_packs/notion/api.py::note`, `full_api` 분기. AST 비교로 이 분기의 문자열 상수 하나만 변경됐음을 확인했다(`source-check.json`). 문자열 상수는 구분 공백 포함 **917 → 745(-172)**, 실제 렌더된 안내문은 **901 → 729(-172)**, Slack 합계는 **7771 → 7599**다. 현재 상한까지 여유는 1자이며, 동적 학습 안내가 늘면 다시 길이를 확인해야 한다.
- 아래는 바뀐 문장 원문을 모두 대응시킨 표다. 합친 문장은 한 행으로 묶었으며 행의 글자 수는 표시된 원문(끝 구분 공백 제외)의 Python `len`이다. `DB`는 데이터베이스의 약칭이다. API 이름·인수·지원 종류·승인·복원·동시 수정·확인 불가·배경 금지 항목은 유지했다. 매크로는 원본의 매크로 그대로 표시한다.

| 구분 | 전 원문 (글자 수) | 후 원문 (글자 수) |
|---|---|---|
| 접근·승인 | `[Notion] 연결에 공유된 모든 페이지·표에서 생성은 즉시, 수정은 먼저 실행하고 후보고, 삭제만 도구 승인을 받는다.` (68) | `[Notion] 연결에 공유된 모든 페이지·표:생성 즉시·수정 후보고, 삭제만 도구 승인.` (50) |
| API 도움·실행 | `api_help로 공식 문서 API 46개와 입력 스키마를 찾고 api(operation, params, body)로 실행한다. api_help(operation=이름)는 경로·쿼리 인수와 본문 형식, api_help(schema_ref=$ref)는 참조 형식을 보여준다.` (152) | `api_help:공식 API 46개·입력 스키마(operation=이름:경로·쿼리 인수·본문 형식;schema_ref=$ref:참조 형식). 실행:api(operation,params,body).` (109) |
| 지원 종류·파일 첨부 | `페이지·데이터베이스·데이터 소스·모든 열 종류·보기·블록·마크다운·이동·댓글·파일 업로드를 지원한다. upload-file(file_path, part_number?, offset?, length?)은 PDF/PPTX/XLSX 등 파일을 첨부한다.` (138) | `페이지·DB·데이터 소스·모든 열 종류·보기·블록·마크다운·이동·댓글·파일 업로드(upload-file(file_path,part_number?,offset?,length?):PDF/PPTX/XLSX 등 첨부) 지원.` (121) |
| 열 조회·수정 | `열은 retrieve-database로 data_sources를 찾은 뒤 retrieve-a-data-source/update-a-data-source를 쓴다.` (89) | `열:retrieve-database의 data_sources→retrieve-a-data-source/update-a-data-source.` (78) |
| 기존 API | `기존 databases/schema/query/page/search/users/create/update/append/edit/batch/trash도 사용 가능하다.` (91) | `databases/schema/query/page/search/users/create/update/append/edit/batch/trash 지원.` (82) |
| 수정·결과 보고 | `수정 전 원본을 읽고 요청한 부분만 바꾼다. report·verification·rollback_available·limitations를 확인해 바뀐 항목과 복원 가능 여부를 보고한다.` (103) | `원본부터 조회·요청분만 수정;report·verification·rollback_available·limitations 확인:변경 항목·복원 가능 여부 보고.` (88) |
| 복원·삭제 승인 | `rollback은 같은 대화의 최근 변경을 30분 안 복원하며 이후 24시간 안에는 확인을 받는다. 복원이 삭제를 수반하면 승인을 받는다.` (77) | `rollback:같은 대화 최근 변경을 30분내 복원, 이후 24시간내 확인 후. 삭제 수반 시 승인.` (57) |
| 동시 수정·미확인 작업 | `동시 수정은 덮어쓰지 않고, 미확인 쓰기·비동기 작업은 성공으로 보고하거나 반복하지 않는다.` (51) | `동시 수정 덮어쓰기·미확인 쓰기/비동기 작업 성공 보고·반복 금지.` (37) |
| 복원 한계·배경 금지 | `API에서 복원 불가한 원본 첨부·댓글/보기 삭제 등은 제한을 보고한다. 예약·배경 쓰기는 차단한다.` (56) | `API 복원 불가(원본 첨부·댓글/보기 삭제 등)는 제한 보고;예약·배경 쓰기 금지.` (47) |
| Notion 제한·스킬 | `Notion 자체의 연결 공유·권한·요금제 제한은 API 오류를 근거로 알린다. <<work_skill_prefix>>-notion 스킬을 참고한다.` (83) | `연결 공유·권한·요금제 제한은 API 오류 근거로 보고. <<work_skill_prefix>>-notion 스킬 참조.` (67) |

### 시험·수집·검사

로그 접두어는 추적하지 않는 `.build/HEJO-IMESSAGE/supplement2/`다. `HEJO_PYTHON`은 운영 저장소 안내의 게이트웨이 venv Python이며 `PYTHONPATH`에 pytest·본체를, `PATH`에 Node 경로를 붙였다. 기존 시험 파일은 수정하지 않았다.

| 명령과 작업 위치 | 실제 결과 | 로그 |
|---|---|---|
| `"$HEJO_PYTHON" -m pytest <team-kit>/tests/test_all_profile_prompt_budget.py -q -s -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` (hejo 작업 폴더) | 전 종료 1: 1 failed, 7 passed. 최종 후 종료 0: 8 passed. 이 시험은 실제 HOME에서 운영 자료를 읽으며 일반 경로의 HERMES_HOME/HERMES_ROOT만 임시로 지정했다. 중간 문구안도 종료 0이었고 연결 공유 범위를 재확인해 최종 후 시험을 다시 실행했다 | `budget-before.log/.exit`, `budget-after-draft.log/.exit`, `budget-after.log/.exit` |
| `"$HEJO_PYTHON" -m pytest <team-kit>/tests -q -p no:cacheprovider -o asyncio_default_fixture_loop_scope=function` (hejo 작업 폴더, 정식 HOME·기본 환경) | 종료 0, **5156 passed, 4 skipped, 58 subtests passed**. 새 AT-HI-33 파일의 17개 사례 포함, V-7 정식 전체 시험 충족. 임의 skip/xfail 없음 | `team-full.log`, `team-full.exit` |
| `./sync` (운영 저장소) | 종료 0, 1588 files collected, 토큰 경고 없음. 커밋·푸시 옵션 없이 실행 | `sync.log`, `sync.exit` |
| `./airport-check` (운영 저장소) | 종료 0. boundary 381, document/compartments 각 0, 조립 검사 3종 모두 통과. 기준선 증가 없음 | `airport-check.log`, `airport-check.exit` |
| `git commit --only` (운영 저장소, 위에 적은 각 경로) | 두 번 모두 종료 0. 각 pre-commit snapshot boundary 382·document/compartments 통과. `git show --stat`로 한 파일/두 파일만 포함 확인 | `commit-05a.log`, `commit-05.log` |
| `git diff --check` (운영 저장소, 자기 경로) | 종료 0 | 별도 파일 없음 |

| 구역 | 수정 전 | 수정 후 |
|---|---:|---:|
| team-kit.files | 349 | 349 |
| team-kit.notion | 901 | 729 |
| team-kit.deadline_watch (시험이 넣는 상한) | 1800 | 1800 |
| team-kit.tools | 1815 | 1815 |
| team-kit.report-review | 540 | 540 |
| team-kit.learning | 64 | 64 |
| team-kit.learned | 1022 | 1022 |
| team-kit.recall | 558 | 558 |
| 구역 합계와 기존 프레임 비용을 합친 Slack 전체 | 7771 | 7599 |

### 보존·남은 일

- 정식 전체 시험은 기존 다른 작업의 실행 원본 변경도 포함하는 운영 소스에서 실행됐다. `./sync`는 그 변경과 자동 학습 자료도 수집했으며, 그 경로들은 커밋하지 않고 남겼다. 자기 세 경로에는 다른 작업과 겹치는 변경이 없음을 확인했다. 운영 저장소 전체가 깨끗하다고 주장하지 않는다. 다른 변경의 상세는 로컬 `final-state.json` 상태 목록에 남긴다.
- 양보 코드는 이제 실행 원본과 운영 저장소 커밋에 있으며, 보완 1처럼 원복하지 않았다. 실행 중 게이트웨이는 재시작·reload하지 않았다. 실제 적용과 연결 확인은 TASK-07의 별도 지시가 필요하다.
- hejo 제품 코드·spec/design/수락 명세 불변. 이번 hejo 변경은 이 보고와 tasks 상태 칸뿐이다. 기존 hejo 전체 시험을 반복하지 않았다(검토 2차 수락된 코드 그대로).
- 운영 저장소 HANDOFF.md에 이 작업의 인계를 덧붙이고 기존 다른 작업 기록을 보존했다. 실제 아이메시지·Slack 발송, 본체/photon/ddots 변경, 릴리스 설치, 앱 사본 교체, git push는 하지 않았다.
- 다음 담당: 문장 전후의 뜻·항목 보존, 해당 시험·정식 전체 시험, 두 운영 커밋의 자기 경로 및 후보 바이트 일치를 검토한다. 통과 뒤 TASK-07 → 비설계자 검토 → TASK-08 폰 M1~M8. 최종 완료·푸시 대상 승인은 그 뒤다.


## TASK-07: 서버 적용 — 적용 전 준비 / 빌드 입력 계약 확인 대기 (2026-11-20)

- 현재 판단: **미적용·확인 대기(20-implementation 2절 계약 충돌 보고)**. 보완 지시 3의 적용 전 기록·보존 사본·롤백 명령은 준비했다. 운영 릴리스·설치 앱·게이트웨이는 변경하지 않았다. AT-HI-40은 미실행, AT-HI-41은 빈 값 없는 롤백 명령 작성까지 완료이며 실제 롤백은 불필요했다.
- 착수 hejo HEAD: `d0d1a58451c73a18c2af3dd545b76e34660e4666`, 깨끗한 작업 트리. `git diff --stat abf68d9 HEAD -- gate app schemas install scripts` 출력 0건. 운영 저장소 HEAD: `9e68b39bd8b51ee1205a011744ea7cf4a2b3e495`. 이전 작업의 미커밋 변경은 그대로 보존했다.
- 공식 적용 전 기록·롤백: `evidence/HEJO-IMESSAGE/TASK-07.md`. 직전 RELEASE `25600732ef822ffea155cd26d31b7f23114ff29f`, team-kit 롤백 기준 `4f79decae030eb63f3f0f52e8c8517226748b876`, 앱 버전·빌드 두 종류와 홈 기준 보존 위치를 모두 적었다. 실제 로컬 경로는 추적 제외 `.build/HEJO-IMESSAGE/task07/paths.sh`에 0600으로 보관했다.

### 확인이 필요한 빌드 계약

- 보완 지시 3은 `bash app/scripts/build.sh`를 실행하도록 하면서 ‘운영 config.yaml·.env·비밀 파일 열기·쓰기’를 금지한다. 실제 빌드 스크립트는 Google 비밀 환경값이 없고 `HEJO_SKIP_GOOGLE_SECRET`가 1이 아니면 저장소의 `config/google-oauth-secret.json`을 읽는다. 파일 존재와 환경값 유무만 확인했으며 해당 파일의 내용은 열지 않았다.
- 이 작업 환경은 해당 파일 존재·비밀 환경값 없음이다. 설치된 시스템 앱은 Google client ID/secret 키가 없고, 직전 공용 앱에는 두 키가 있다(키 유무만 기록, 값은 조회·출력하지 않음). 따라서 비밀 주입을 생략하는 선택도 공용 앱의 기존 Google 로그인 입력 유무를 바꾼다.
- 필요한 결정: (권고) 기본 빌드 프로세스가 이 저장소 빌드 입력을 읽는 것만 허용할지, 또는 비밀 주입 없이 공용 앱을 교체하는 범위를 허용할지 명시한다. 직접 비밀값 조회·로그 출력은 하지 않는다. 이 범위를 확인하기 전에 릴리스를 먼저 갱신해 중간 상태를 만들지 않았다. 사용자에게 선택 질문을 제출했으며 응답 대기다.
- 제품 코드·명세·수락 명세 수정이나 임의의 빌드 우회는 하지 않았다. 로그 확인·앱 화면 캡처는 적용·재시작 뒤의 단계라 아직 수행하지 않았다.

### 실행과 증거

| 명령/검사 | 실제 결과 | 기록 |
|---|---|---|
| `git status --porcelain`, `git diff --stat abf68d9 HEAD -- gate app schemas install scripts` | 종료 0, 착수 시 두 출력 모두 없음 | `.build/HEJO-IMESSAGE/task07/before.json` |
| `git cat-file -e 25600732ef822ffea155cd26d31b7f23114ff29f^{commit}` | 종료 0, 직전 릴리스 커밋 객체 있음 | 같은 기록 |
| `ditto`로 운영 shared/hejo·앱 두 사본 보존 | 세 번 모두 종료 0 | 홈 기준 `.paseo/task-artifacts/HEJO-IMESSAGE-20261119/TASK-07-before-d0d1a58` |
| 보존 데이터 디렉터리·일반 파일 권한 검사 | 종료 0, 디렉터리 0700·파일 0600 | `before.json`과 보존 사본 |
| `codesign --verify --deep --strict` (보존 앱 두 사본 각각) | 모두 종료 0 | `backup-system-signature.log/.exit`, `backup-release-signature.log/.exit` |
| `git diff --check` | 종료 0 | 별도 로그 없음 |

- 릴리스 갱신·앱 빌드·설치 사본 교체·최근 2분 차례 확인·게이트웨이 재시작·재시작 뒤 연결/오류 검증·스크린샷: **미실행**. 재시작 시각·캡처 경로는 없다. 롤백 실행 없음(운영 적용 없음).
- 다음 행동: 빌드 입력의 금지 범위를 명확히 한 뒤 보완 지시 3의 적용 단계부터 진행한다. 재시작 전에는 최근 2분 직원 차례 없음 확인과 10분 대기 한도를 그대로 적용한다. 짝짓기·코드 발급·실제 아이메시지/Slack 발송·push 금지는 유지한다.


## TASK-07 재개: 공용 릴리스 반영·설치 점검 / 앱 범위 답변 대기 (2026-11-20)

- 받은 지시: handoff 보완 지시 4(보완 지시 3 대체), verdict 4차 V-9. 재개 HEAD와 배포 대상은 `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`. 제품 코드 무변경. 필요한 증거 수준 3, 현재는 실제 릴리스·설치 상태 점검까지만 도달했으며 AT-HI-40의 재시작·연결 검증은 미실행이다.
- 사용자는 이전 질문에 ‘빌드 프로세스의 해당 입력 읽기만 허용하고 기본 빌드 진행(값 조회·출력 금지)’으로 답했다. 그 사이 인계서가 앱을 제외하고 0.2.1 공개 절차로 분리하도록 바뀌었다. 현재 앱 배포 계약을 임의로 선택하지 않고 범위 차이를 설명한 질문을 제출했다. 비밀 입력 내용은 열지 않았으며 앱 빌드·교체·재시작은 답변 전까지 보류했다.
- 공통 허가 범위인 릴리스 반영과 설치 상태 점검은 실행했다. 적용 전 기록·롤백 명령은 `evidence/HEJO-IMESSAGE/TASK-07.md`에 먼저 갱신했다. 보존 사본 권한과 직전 RELEASE 불변을 확인했고 앱 롤백은 ‘해당 없음(앱 미교체)’으로 정정했다.

| 명령·검사 | 실제 결과 | 근거(`.build/HEJO-IMESSAGE/task07/` 기준) |
|---|---|---|
| `git status --porcelain`, 두 착수 조건 `git diff --stat` | 종료 0, 재개 시 모두 출력 없음 | 재개 읽기 결과·evidence 적용 전 기록 |
| 보존 shared/hejo 권한 재검사 | 종료 0, 디렉터리 0700·일반 파일 0600 | 기존 before.json 및 보존본 |
| `install/hejo-release` | 종료 0, UTC 2026-11-20 04:26:48 완료 | `release.log/.exit`, `release.json` |
| RELEASE 및 gate 커밋 대조 | 종료 0, RELEASE 대상 일치·시험 제외 19개 파일 및 파일 집합 동일 | `release.json` |
| Hermes venv Python `<release>/install/hejo-install --check` | 종료 0, 출력 없음. 설치 실행은 미실행 | `install-check.log/.exit`, `install-check.json` |
| gateway_state 읽기 | 종료 0, running·active_agents 0·PID 생존. 마지막 상태 갱신 UTC 04:26:57 | 재개 읽기 결과 |
| Hermes venv Python `scripts/scan_private.py` (임시 HERMES_HOME) | 종료 0 | `private-resume.log/.exit` |
| `git diff --check` | 종료 0 | 최종 diff 직접 확인 |

- 현재 RELEASE는 배포 대상 커밋이다. 게이트웨이 재시작 시각·재시작 이후 연결/오류 확인·캡처 경로는 아직 없다. 실행 중 게이트웨이는 이전 코드이며 다음 재시작 때 갱신 코드를 읽는다. 허브 재시작·짝짓기·코드 발급·실제 발송·push는 미실행이다. 실패가 없어 코드 롤백은 실행하지 않았다.
- 다음 행동: 앱 범위 답변을 확인하고, 서버만이면 보완 지시 4의 3번부터 최신 처리 중 차례 0 확인 → 게이트웨이 재시작 → 로그 검증. 릴리스·설치 상태 점검은 반복하지 않는다. 앱까지면 현재 공개 배포 계약과의 차이를 계획 담당이 먼저 정리해야 한다. 이전 TASK-07 준비 절의 ‘보완 지시 3 재개’ 안내는 이 절로 대체한다.


## TASK-07: 보완 지시 4 서버 적용·자체 검증 완료 (2026-11-20)

- 받은 설계·허가: handoff 보완 지시 4, verdict 4차. 사용자 답변 ‘보완 지시 4대로 서버만 적용’으로 앞 절의 범위 대기를 해소했다. 앱 빌드 입력 읽기 허용은 사용하지 않았다. 판단 상태: **이번 서버 적용 범위 완료·계획 담당 검토 대기**. 위험도 고위험(운영), 필요·도달 증거 수준 3.
- 재개 HEAD `154b8aa0b04e9ec34ffa66b9db2dd10bd5180a0b`, 작업 트리 깨끗. 이미 배포된 대상 `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`와 제품 코드는 같으며 두 착수 조건 diff는 모두 0건이다. 앞 절에서 끝난 릴리스 갱신·설치 상태 점검은 반복하지 않았다.
- 적용 전 기록·보존 위치·빈 값 없는 코드 롤백 명령·이번 관측 원본은 `evidence/HEJO-IMESSAGE/TASK-07.md`를 따른다. 제품 구조·기록장 형식 변경은 없다. 설치된 앱을 교체하지 않았고 허브도 재시작하지 않았다.

| 명령·검사 | 실제 결과 | 로컬 증거(`.build/HEJO-IMESSAGE/task07/` 기준) |
|---|---|---|
| gateway_state + PID + 갱신 시각 확인 | 종료 0, active_agents 0·running·PID 생존·갱신 120초 미만 | `restart-before.json` |
| `hermes --profile default gateway restart` | 종료 0, UTC 04:32:05.756 요청·04:32:08.463 종료 | `restart-command.log/.exit`, `restart-command.json` |
| `python3 .build/HEJO-IMESSAGE/task07/verify-restart.py` | 종료 0, 새 시작 UTC 04:32:23.433·릴리스 갱신 뒤·PID 교체·runtime running | `post-restart.json`, `verify-restart.exit` |
| 같은 검사의 연결·로그 대조 | hejo 6·Slack 6·photon 1 connected, 새 오류·역추적·경고·아이메시지 실패·처리기 연결 실패 각 0 | `post-restart.json`, 식별자 없는 `connections.log` |
| team-kit 실행 원본·운영 작업본·커밋 대조 및 hejo 코드 diff | 종료 0, 자기 세 파일 동일·운영 HEAD 불변·hejo 제품 및 hub/install/config 무변경 | `source-final.json` |
| Hermes venv Python `scripts/scan_private.py` (임시 HERMES_HOME) | 종료 0 | `private-final.log/.exit` |
| `git diff --check` | 종료 0 | 최종 diff 직접 확인 |

- AT-HI-40의 서버 부분 통과(최종 관측 UTC 04:34:49, 새 시작 뒤 약 146초). 앱의 platform_ready/paired 화면은 새 앱 공개 뒤 확인해야 하므로 통과로 주장하지 않는다. 실제 아이메시지·Slack 발송은 하지 않았다. AT-HI-41은 사전 롤백 절차만 준비했으며 실패가 없어 롤백 실행은 없음.
- 비밀·운영 설정 직접 조회, Hermes 본체/photon/ddots 변경, 앱 빌드·교체·버전 올림·공개, 허브 재시작, 짝짓기·코드 발급·push는 미실행이다. 기존 다른 작업 변경을 보존했다.
- 다음 담당: evidence와 실제 로컬 로그·RELEASE·게이트웨이 상태를 확인해 TASK-07을 검토한다. 이미 적용한 릴리스·재시작은 반복하지 않는다. 이후 TASK-07b 앱 0.2.1 공개 준비의 사용자 결정 → 비설계자 검토 → TASK-08 폰 M1~M8. 제품 최종 완료와 푸시 승인은 아직 아니다.


## TASK-07b: 앱 0.2.1·빌드 3 공개 후보 준비 (2026-11-20)

- 받은 설계: handoff 보완 지시 5, HEJO-FOUNDATION 보완 지시 61·그 검토 기록. 사용자 결정대로 이 작업에서 후보를 준비했다. 판단 상태: **후보 준비·자체 검증 완료, 계획 담당 검토 대기**. 고위험(공개 배포물), 필요·도달 증거 수준 2. 실제 공개·업데이트 설치·실물 동작은 미실행이다.
- 착수 HEAD: `11dcd46302566e0d4cbff1023e2fe1b3b0316fa1`(작업 트리 깨끗). 버전 올림 커밋: `274f98f5f415fa71192b333d2c88e1299ed3898b`. 변경은 `app/Resources/Info.plist`의 0.2.1·빌드 3과 `tests/acceptance/test_ship.py`의 고정 버전 단언뿐이다. 제품 동작 코드·명세·수락 명세는 바꾸지 않았다.
- 공개 기준 main: `274f98f5f415fa71192b333d2c88e1299ed3898b`. 새 public: `363bcc021aff018ff0e62e1d2265717939bf61c8`, 부모 `1dfda649f14483acc5dd90f1f363e63904805b43`(기존 0.2.0). 두 트리는 `f50e54126d4c57851fc0336a0583ad5a459cb660`로 동일하다. 기존 공개 계보에 정확히 한 커밋을 더했고 기준 main은 public의 조상이 아니다. 개인 개발 이력을 포함하지 않았다. 이 후속 보고와 tasks 상태는 별도 문서 커밋으로 남겨 공개 후보를 다시 만들지 않는다(0.2.0 선례와 같음).
- `hejo-publish`의 작성자 조회는 선례의 오프라인 gh 대역으로 처리했다. 기존 public 작성자 정보를 로컬에서 재사용했으며 두 호출은 `network:false`다. 실제 gh·원격 Git·curl/wget 호출은 차단한 환경을 사용했고 차단 시도도 없었다. GitHub 조회·쓰기·push·publish는 하지 않았다.
- 준비물: `.build/release-0.2.1/prepared.json`, `.build/release-0.2.1/hejo-0.2.1-arm64.zip`. 압축 SHA256 `a8ab74a9b1958576cf32fbc6d62d13cd7df519fc23a78c6b2f9bed308ed4bf14`. 압축을 풀어 codesign deep/strict·실행 파일 동일·BuildInfo tree 일치/dirty false·Sparkle 서명을 재확인했다. 기존 키체인 키를 재사용했으며 setup·새 키 생성·키 내보내기는 하지 않았다.
- 업데이트 연속성: 준비물 0.2.1·3이 설치본 0.2.0·2보다 크다. 업데이트 공개 키는 준비물·압축 앱·0.2.0 준비물·현재 설치본이 모두 같다. 허용된 기본 빌드 프로세스만 Google 입력을 읽었으며 입력 값은 직접 열거나 출력·기록하지 않았다. 전체 시험의 앱 빌드는 원래 시험 절차대로 비밀 주입을 생략했고, 통과 뒤 같은 깨끗한 트리에서 기본 배포 빌드를 다시 했다.

| 검증 명령·대상 | 실제 결과 | 로컬 로그(`.build/release-0.2.1-work/` 기준) |
|---|---|---|
| `install/hejo-publish` (선례의 로컬 작성자 캐시 대역) | 종료 0, public 생성·부모 및 트리 동일·개인 이력 배제 | `publish-local.log/.exit`, `snapshot.json`, `offline-gh.jsonl` |
| Hermes venv Python `scripts/scan_private.py --repo <public-worktree>` (임시 HERMES_HOME) | 종료 0, 공개본 검사 | `public-private.log/.exit`, `public-private-final.log` |
| `bash scripts/test.sh` (Hermes venv·임시 HERMES_HOME·실제 Hermes 모듈·가짜 명부) | 종료 0, Python 325 passed, 실제 임시 게이트웨이 배달·전체 앱/통신·훅 시험 통과. 설치 시험·AT-HI-37 포함 | `full.log`, `tests-result.json` |
| 같은 전체 앱 시험 바이너리 반복 3회 (각각 임시 홈) | 각 종료 0·APP_TEST_OK, 입력 트리 불변 | `app-repeat-1.log`~`app-repeat-3.log`, `verification-progress.json` |
| 옛 문 aeaa652 + 새 앱 `test_update_compat.py` (선례의 임시 시험 원본) | 종료 0, 1 passed·AT84_OLD_GATE_NEW_APP_PASS, 실제 루프백 인증·통신·가짜 차례 | `legacy-aeaa652.log`, `tests-result.json` |
| `bash app/scripts/build.sh` (기본 빌드) | 종료 0, BuildInfo tree 동일·dirty false | `default-build.log`, `prepare-progress.json` |
| Hermes venv Python `install/hejo-ship prepare --output .build/release-0.2.1/` | 종료 0, 대상 public/tree/버전/빌드/압축 지문 일치 | `prepare.log`, `final-verification.json` |
| `ditto -x -k` 뒤 `codesign --verify --deep --strict <unpacked-app>` | 각각 종료 0 | `extract.log`, `archive-codesign.log` |
| Sparkle `sign_update --account <existing account> --verify <archive> <prepared public signature>` | 종료 0 | `archive-sparkle.log` |
| 실제 CLI 설정 lstat·실제 다운로드 이름 전후 검사 | 모두 종료 0, 내용 미조회·메타데이터/이름 불변 | `settings-before/after/final.log`, `downloads-before/after/final.log` |
| Hermes venv Python `scripts/scan_private.py` (임시 HERMES_HOME) | 종료 0, 후보 기준 main 검사 | `main-private.log` |
| 같은 개인값 검사 (후속 보고 문서 포함)·`git diff --check` | 각각 종료 0 | `report-private.log/.exit`, 최종 diff 직접 확인 |

- 검증 기록 원본: `snapshot.json`, `tests-result.json`, `final-verification.json`. 준비 전후 동일 트리·깨끗한 작업 트리를 확인했다. 새 알고리즘·인증 조건을 바꾸지 않아 추가 mutation은 하지 않았다. 전체 시험의 기존 Swift 경고는 억제하거나 수정하지 않았다.
- 공용 RELEASE는 `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae` 그대로이며 게이트웨이 PID도 TASK-07 검증 때와 같다. 설치된 앱 교체·공용 릴리스 갱신·운영 홈 변경·재시작·실제 발송은 하지 않았다. 운영 저장소는 이번 단계에서 변경하지 않았다.

사장용 공개 명령(이번에는 실행하지 않음, 검토·승인 뒤 사장이 실행):

```bash
install/hejo-ship publish --approve-commit 363bcc021aff018ff0e62e1d2265717939bf61c8 --prepared .build/release-0.2.1/prepared.json
```

푸시 대상은 hejo 저장소의 `github` 원격 `main` 브랜치, 커밋 `363bcc021aff018ff0e62e1d2265717939bf61c8`이다. 실제 저장소 경로를 포함한 대상은 인계 상태 블록에 적는다. 로컬 main은 푸시 대상이 아니다. 검토 통과 뒤 사장이 플러그인 화면에서 별도로 승인한다.

남은 일: 계획 담당이 버전 커밋·공개 계보/트리·준비물/서명·시험 원본을 검토한다. 통과 뒤 사장 public 푸시 승인·publish → 앱 자동 업데이트 설치 → 비설계자 검토 → TASK-08 M1~M8. 운영 저장소 푸시 대상의 원격 포함 여부 확인은 이번 GitHub 조회 금지 범위에서 수행하지 않았다.


## TASK-09: 폰의 작성 중 표시 (2026-11-20)

- 받은 설계: handoff 보완 지시 6, spec 4판 REQ-HI-09, design 6.1절, AT-HI-45~51. 착수 HEAD `3cc6773cc4edc85bd2f8c75094aada8f6b8c40d6`, 작업 트리 깨끗. 판단 상태: **구현·자체 시험 완료, 계획 담당 검토 대기**. 위험도 보통, 필요·도달 증거 수준 2(실제 Hermes 모듈·임시 홈·가짜 photon 어댑터).
- 구현 커밋: `05107d59a23c27a4dea946c566b00d7e3df81696`. 시험 관측 보강 커밋: `b5f8549a218bbcf9b827e155cbfa5f6c1239f870`(AT-HI-50의 준비 프레임을 먼저 비우는 2행만). 제품 변경은 `gate/imessage.py`·`gate/adapter.py` 두 파일이며, 시험은 `tests/acceptance/test_imessage.py`다. 기존 시험 기대값은 그대로 두고 가짜 어댑터 호출 기록과 폰 스레드 도우미의 기본값을 유지한 선택 인수만 더했다.
- 흐름: 전달자가 아닌 hejo send_typing 경로에서 방/직원·스레드 열쇠를 bridge에 알린다. 짝·켜짐·photon 연결·phone_parent 조건이 맞으면 메모리 집합에 넣고 별도 작업으로 send_typing을 요청한다. 차례가 꺼지고 pending 발신까지 끝나 집합이 비는 순간 stop_typing을 한 번 요청한다. 앱 시작 보고 스레드에는 표시를 요청하지 않는다. 폰 글이 있는 스레드를 앱에서 이어도 phone_parent 조건은 유지된다.
- 생명주기: 연결 끄기·짝 해제·짝 교체 때 이전 대화창 표시를 정지하고 집합을 비운다. close는 정착 작업과 표시 요청 작업을 취소·회수한다. 예외는 식별자 없는 고정 경고 `imessage_typing_failed`만 남긴다. 표시용 글·자체 갱신 타이머·새 저장 파일·새 프레임은 없다.
- 정착 작업은 마지막 답을 실제 전송하는 동안에도 pending 항목을 유지한다. 그 사이 같은 스레드의 다음 차례가 끝나도 정지가 발신 완료보다 먼저 가지 않게 하기 위한 구현 상세다. 설계와 달라진 요구·계약·구조는 없다. 짝 교체 정리와 발신 중 경합을 추가 시험했다.

| 수락 시험 | 실제 결과 |
|---|---|
| AT-HI-45 | 1:1·단체방 두 경우 각각 알림 3번 → 짝 대화창 시작 3번 |
| AT-HI-46 | 앱 시작 스레드는 폰 보고 스위치 전후 모두 시작·정지 0건 |
| AT-HI-47 | 끄기·짝 해제·photon 미연결 세 경우 시작 0건 |
| AT-HI-48 | 답 있음: 시작→답 send→정지, 답 없음: 시작→정지. 정지 각각 1번·중복 호출 없음 |
| AT-HI-49 | 폰 스레드 두 개 중 첫 종료는 정지 0건, 마지막 종료는 1건 |
| AT-HI-50 | 시작·정지의 예외/무기한 지연 각각에서 호출자 1초 이내 반환·앱 typing on/off·답 발신 정상. 대화창 id/예외 본문 로그 없음. close 후 요청 작업 회수 |
| AT-HI-51 | send는 답 한 건뿐. 기록장 레코드 종류·설정·금고·규격 파일 바이트 불변 |
| 추가 생명주기·경합 | 끄기·해제·짝 교체 각 정지 1번과 집합 정리, 전송 중인 답이 끝나기 전 정지 없음 |

| 검증 명령·대상 | 종료 코드·실제 결과 | 로컬 증거(`.build/HEJO-IMESSAGE/task09/` 기준) |
|---|---|---|
| Hermes venv pytest `tests/acceptance/test_imessage.py` (임시 HERMES_HOME) | 최초 0·65 passed, 전송 중 경합 시험 추가 후 최종 0·66 passed | `focused.log/.exit`, `focused-final.log/.exit` |
| AT-HI-50 관측 경계 보강 뒤 같은 집중 시험 | 0·66 passed, b5f8549 기준. 제품 코드 동일 확인 | `focused-final-observation.log`, `focused-final-observation.json` |
| pending 검사 제거 mutation, AT-HI-48 실행 | 변이 1(1 failed·1 passed), 원복 0(2 passed). 원래 바이트 복구 확인 | `mutation.log`, `mutation-restored.log`, `mutation.json` |
| Hermes venv `bash scripts/test.sh` (임시 HERMES_HOME·실제 Hermes 모듈·가짜 명부) | 0, Python 341 passed(기존 325+새 16), 임시 게이트웨이 배달·앱 전체/통신·훅 9개 통과. 검증 변경본 05107d5·작업 트리 불변 | `full.log/.exit`, `full.json` |
| Hermes venv `scripts/scan_private.py` (임시 HERMES_HOME) | 0 | `private-final.log/.exit`, `final-check.json` |
| 본체 `git rev-parse HEAD`·`git status --porcelain` 전후 대조 | 0, HEAD `ebb026eef8e800e1b7471ed147b7287e878f8aa4` 동일, 양쪽 status 출력 없음 | `before.json`, `final-check.json` |
| 기준과 app/schemas/config/install/scripts·spec/design/수락 명세 diff | 0, 변경 없음. public 363bcc0 그대로 | `final-check.json` |
| 최종 보고 포함 개인값 검사·`git diff --check` | 각각 0 | `private-report.log/.exit`, 최종 diff 직접 확인 |

- 전체 시험 뒤 변경은 AT-HI-50 관측 경계 두 줄과 이 보고뿐이다. 제품 코드는 전체 시험 대상과 같고, 바뀐 시험 파일은 66개 전부 재실행했다. 앱 전체 시험은 이 시험 전용 보강 뒤 반복하지 않았다.
- 검증 명령에 포함된 시험용 앱 빌드만 실행했다. 앱 소스·버전 변경, 별도 배포 빌드·설치, hejo-publish/ship, 공용 릴리스 갱신, 게이트웨이 재시작, 운영 홈 변경, team-kit·본체·photon 수정, 실제 아이메시지/Slack 발송, git push는 하지 않았다. 기존 Swift 경고는 그대로다.
- 서버에는 아직 TASK-09 코드를 적용하지 않았다. 실제 폰 기본 애니메이션 M9는 미검증이다. 다음은 계획 담당의 TASK-09 검토 → 별도 TASK-10 적용 허가 → 사장 M9다. 비설계자 검토 주체 결정과 ARCHITECTURE 반영은 계획 담당에게 남긴다. 공개 브랜치와 배포 후보는 다시 만들지 않았고 이번 단계의 새 푸시 대상은 없다.

## TASK-10: 작성 중 표시 서버 적용 (2026-11-20)

- 받은 지시: handoff 보완 지시 7(절차는 보완 지시 4), verdict 8차 TASK-09 통과. 착수·배포 대상 HEAD `95074cbafda3a5e16d1fd2e9a580b24abe667021`, 제품 코드 `05107d59a23c27a4dea946c566b00d7e3df81696`. 착수 작업 트리 깨끗, ea31736 대비 문 두 파일만 변경·05107d5 대비 제품 변경 0건을 확인했다.
- 판단 상태: **서버 적용·자체 검증 완료, 계획 담당 검토·사장 M9 대기**. 고위험(운영), 필요·도달 증거 수준 3. 설계와 달라진 점 없음. 제품 코드·수락 명세는 바꾸지 않았다.
- 적용 전에 [TASK-10 증거](../../../evidence/HEJO-IMESSAGE/TASK-10.md)에 직전 RELEASE `ea31736b0f6eaa1a14d39099cc853f33e2b2c6ae`와 실행 경로 변수가 채워진 코드 롤백 절차를 작성했다. 데이터 복원·앱·team-kit 조치는 없다. 경로 변수는 추적 제외 파일에만 있다.

| 절차별 명령·확인 | 종료 코드·실제 결과 | 로컬 증거(`.build/HEJO-IMESSAGE/task10/` 기준) |
|---|---|---|
| 착수 `git status --porcelain`, 지정된 두 `git diff` | 0, 작업 트리 깨끗·허가 범위 일치 | `before.json` |
| `install/hejo-release` | 0, UTC 06:05:37.303 완료. RELEASE 대상 일치·시험/캐시 제외 gate 19개 파일과 파일 집합 동일 | `release.log/.exit`, `release.json` |
| Hermes venv Python `<release>/install/hejo-install --check` | 0, 출력 없음. 설치 실행 안 함 | `install-check.log/.exit`, `install-check.json` |
| 재시작 직전 runtime·PID 확인 | 0, active_agents 0·running·PID 생존·상태 갱신 약 9초 전 | `restart-before.json` |
| `hermes --profile default gateway restart` | 0, UTC 06:05:58.463 요청·06:06:00.792 명령 종료 | `restart-command.log/.exit`, `restart-command.json` |
| Hermes venv `verify-restart.py` | 0, UTC 06:08:25.386 관측·새 시작 뒤 약 129초. 새 시작 UTC 06:06:16.152(한국 시각 15:06:16.152)은 릴리스 갱신 뒤 | `post-restart.json`, `verify-restart.exit`, `connections.log` |
| Hermes venv `scripts/scan_private.py` (임시 HERMES_HOME) | 0, 최종 보고·새 evidence 포함 | `private-final.log/.exit` |
| `git diff --check`, 제품·명세 무변경 및 본체 HEAD/status 확인 | 0, 자기 보고 세 파일만 변경·본체 동일 | `final-source.json`, `diff-check.log/.exit` |

- 연결 결과: hejo 기본 1·보조 5, Slack 기본 1·보조 5, photon 1. photon에 hejo native handler 연결 성공 로그 1건. 새 PID 생존·runtime running·세 문 connected를 확인했다. 재시작 전 로그 오프셋부터 새 ERROR/CRITICAL·역추적·WARNING·아이메시지 실패·처리기 연결 실패 각 0건이다. 기존 구간과 분리했으며 대화 본문·프로필 식별자는 보고에 옮기지 않았다.
- 짝·설정 파일은 재시작 전후 수정 시각이 각각 같다. 내용은 열지 않았다. `post-restart.json`에 stat 비교 결과가 있다. 코드 롤백은 검증 실패가 없어 **미실행**이다.
- 공개 브랜치는 `363bcc021aff018ff0e62e1d2265717939bf61c8` 그대로다. 이번 문 변경은 다음 공개 때 나가므로 이번 단계에서 새 푸시 대상을 만들지 않았다. 앱 빌드·버전·공개 준비/발행·사본 교체·허브 재시작·설치 적용·설정 변경·실제 발송·push는 실행하지 않았다. Hermes 본체 HEAD `ebb026eef8e800e1b7471ed147b7287e878f8aa4`·깨끗한 상태도 유지된다.
- 실제 폰의 기본 작성 중 표시 M9는 미검증이다. 계획 담당이 증거·현재 RELEASE를 검토한 뒤 사장 M9와 비설계자 검토 주체 결정, ARCHITECTURE 반영을 이어간다. 이미 적용한 릴리스 갱신·재시작을 반복하지 않는다.
