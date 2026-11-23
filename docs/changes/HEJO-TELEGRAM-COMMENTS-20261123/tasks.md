# 작업 분해 5판

[spec](spec.md)와 [수락 시험](../../../tests/acceptance/HEJO-TELEGRAM-COMMENTS.md)이 원본이다. 사용자 승인한 공용 공간 구조에 대한 계획 재검증 대상이다. 4판 TASK 2~4 진행 지시는 아래 작업으로 대체한다. 기존 코드와 증거를 보존하고 재사용 가능성을 확인하며 처음부터 다시 구현하지 않는다.

| TASK | 변경 책임 | 완료 조건 |
|---|---|---|
| H1 | gate의 사람별 binding을 단일 hub+명시 rooms로 변경, 금고 v2/sent v3 읽기·이전, 포럼 수신/sync 복원 | T01~04/T16/T19/T23/T24. 옛 active binding 자동 승격 금지, probe/retired 보존, 비참여 방 회귀 |
| H2 | 기존 wrapper 질문 입력·native 댓글 입력과 question key 통합, 채널 입력 실행 제거 | T05~09/T14/T25. 두 사람 질문 교차 및 중복 실행 0 |
| H3 | root/anchor/card/comment 작업과 토픽 버튼·복귀 링크·상태 편집, uncertain 복구 통합 | T10~17/T22/T26/T27. 카드 하나, 댓글 본문 단일 목적지, 경합/중단 시험 |
| H4 | hub 전체 off/abort/재짝 경계, README, 전체 회귀·공개 검사·구현 보고 | T18~21/T28. 변경본 해시/실행 로그, 다른 작업 제외한 격리 후보, 독립 검토 반환 |
| H5 | 별도 운영 인계와 사용자 승인 후 두 직원·하나의 공용 쌍 실물 수락 | M1~M6. 링크 실제 댓글창 이동과 고정 공간 수 확인. 이 계획만으로 배포하지 않음 |

H1→H4 순차: 같은 gate 파일·저장 계약을 공유한다. 제품 변경은 gate/adapter.py, gate/telegram.py, gate/telegram_comments.py 및 개발자 시험·운용 README 범위다. 기존 TASK 1/M0와 구현 중 TASK 2/3의 유효한 코드·시험은 유지하되 4판 기대와 충돌하는 시험은 새 요구로 갱신한다. 수락 명세는 계획 담당 소유다. 제품 수락 판정과 4판 성공 로그를 혼동하지 않는다.

위험도 고위험과 기존 독립 검토·증거 수준을 유지한다. 현재 M0는 기술 관문 증거이며 신규 공용 UX 실물 수락을 대체하지 않는다. H1~H4 구현 중 운영 후보·설정·발신·재시작 변경 없음. 실제 M0 재시험 필요 여부는 설계의 native 계약 동일성으로 판정한다.

## 예정 검증

- 새 기능 대역: 구현자가 추가한 pytest 대상과 실제 PTB integration 명령을 impl-report에 고정.
- 실행 파이썬: 운영 비밀 파일이나 환경 스크립트를 source하지 않고 Hermes 소스의 `venv/bin/python` 실행 파일을 `HEJO_PYTHON`에 지정한다. 개인 절대 경로는 추적 문서에 기록하지 않는다. 시험 모듈이 가상환경 밖 기존 시험 의존성 폴더에 있는 이 현장에서는 그 폴더와 Hermes 소스를 `PYTHONPATH`에 명시한다(로컬 `.build/connections-env.sh`의 파이썬/경로 선언만 읽고 전체 source 금지). `"$HEJO_PYTHON" -c 'import pytest, ruamel.yaml; print("test dependencies ready")'`로 확인하고 실패하면 환경 차단으로 보고한다. 시스템 python3로 임의 대체하거나 패키지를 전역 설치하지 않는다.
- 기존/전체: `HEJO_PYTHON="$HEJO_PYTHON" bash scripts/test.sh` (내부 Swift 시험 포함; 앱 제품 수정/앱 설치를 뜻하지 않음).
- 공개 검사: 임시 가짜 홈을 명시한 `"$HEJO_PYTHON" scripts/scan_private.py --home <temporary-home>`; 전체 변경 파일이 검사 대상인지 확인. 추적 전 파일은 별도로 검사하거나 이 작업 파일만 명시적으로 stage한 뒤 검사한다.
- 제품 범위: git diff base...commit 및 워킹트리 비교로 app/wire/본체/team-kit 무변경 확인.
- 실제 네트워크: 사전 M0와 최종 TASK 5에 한정하며 각각 별도 인계/사용자 승인 후 진행. 대역 검증과 구별.

증거는 이 작업 `logs/`에 개인값을 제거해 저장하며 명령·cwd·대상 전체 커밋·종료 코드·판정 근거를 기록한다. 새 실패나 코드 변경이 없으면 이미 확인한 전체 검사를 반복하지 않는다.

## 운용 안내

사람 토픽에 질문을 쓰고 카드의 대화 열기를 누르는 순서, 토픽에 질문/카드가 함께 남는 점, 공용 공간의 접근 비격리, 보관/음소거는 사용자 선택인 점, unknown 복구 및 off의 전체 범위·영구 은퇴 부담을 명시한다. H5 전에 두 참여 방과 전체 영향 범위를 사용자가 확인한다.
