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
