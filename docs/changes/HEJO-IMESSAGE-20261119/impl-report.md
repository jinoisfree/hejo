# HEJO-IMESSAGE 구현 인계

## 착수 기준

- 인계: `handoff.md`, spec/design/수락 시험 2판, plan-review 2회차 해석. 연합개발, 고위험, 필요 증거 2(AT-HI-39는 3).
- 실제 hejo 착수 HEAD: `9b375d0e15dd87a3412c4f090eee3c7ea8a7d0e4` (`main`). 인계에서 이미 평가한 기준과 같음. 기존 변경 없음. 별도 worktree 없이 계획 담당 폴더에서 작업.
- 운영 저장소 착수 HEAD: `4f79decae030eb63f3f0f52e8c8517226748b876`.
- Hermes 본체 착수 HEAD: `ebb026eef8e800e1b7471ed147b7287e878f8aa4`, `git status --porcelain` 출력 없음(photon 포함).
- 판단: 진행 중. TASK-02~06 구현·자체 시험만. TASK-07 운영 적용 및 TASK-08 실물은 미실행.
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
