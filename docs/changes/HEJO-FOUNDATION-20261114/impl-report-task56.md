# TASK-56 구현·자체 시험

보완 71의 책임 자리는 기존 MemberState·ConversationModel·AppUpdate·GateHTTP·GateKeychain·LoginWindow, 문 FileStore·Connection·Journal·Connections, 허브 MemberStateStore, 설치 도우미다. 새 영구 원본·새 wire 필드는 없다. 앱 버전은 바꾸지 않는다.

## 지적별 결과와 변형

| 지적 | 결과 | 수정 전·핵심 제거 변형의 실패 근거 |
|---|---|---|
| IR-03 | 요청 뒤 로컬 rev가 그대로면 낮은 rev도 서버 전체 문서로 교체, 기존 outbox만 송신. 요청 중 다른 PATCH가 확인된 경우의 늦은 응답은 무시. 성공한 대기도 1.5초 최소 간격 | app-before-valid.log, mutation-app.log의 두 IR03 단언 |
| IR-04·IR-S11 | 허브는 새 입력과 기존 항목 시각을 현재+300초로 제한. 앱은 서버가 무시한 쓰기와 로컬 LWW 단계에서 거절된 변경을 재조회하고 실패 안내 | app-before-valid.log, mutation-app.log의 IR04 두 단언, mutation-IRS11.log |
| IR-05 | layout:section-open:<id> 및 stack 키로 접힘 분리. 구획 정의 저장 때 open 제거. 옛 배열 값은 읽을 수 있고 정의 편집 전에 없는 키만 이전 | app-before-valid.log, mutation-app.log의 독립 접힘·정의 단언 |
| IR-06 | 기억한 릴리스도 설치 전에 다시 조회. 같은 릴리스면 기존 명시 동의로 시작, 바뀌면 새 버전 동의. 조회 실패는 설치하지 않음 | app-before-valid.log, mutation-app.log |
| 첨부 격리 | 받은 캐시·다운로드 사본·재사용 사본에 com.apple.quarantine 부여 뒤 열기. 실패 시 표시하거나 열지 않음 | app-before-valid.log, mutation-app.log |
| 비밀번호 | Security Keychain API로 UTF-8 바이트 저장·검증. 기호·공백·한글 보존, 문 출입증 형식 제한 유지. 실패는 대화상자로 알림 | app-before-valid.log의 저장 실패, mutation-app.log의 기호·실패 단언 |
| IR-S03 | 업로드 본문은 공유 잠금 밖, 고유 임시 폴더를 pending으로 확정할 때만 잠금. 직원 로컬 사본도 수신 전 잠금 제거. 진행 중 업로드만 정리에서 제외 | mutation-IRS03.log |
| IR-S04 | 연결별 FIFO 송신 대기열·5초 송신 상한·1초 닫기 상한. 방송은 소켓 배수를 기다리지 않음. 30초 퐁 기한, 미응답 연결만 닫기. 재현 경계와 live 전환은 한 루프에서 원자적으로 큐에 넣음 | mutation-IRS04.log(느린 수신·퐁 두 경우) |
| IR-S05 | secure 폼 입력만 되비침 검사. key/catalog의 비밀 칸과 서버가 제시한 폼 칸을 사용. 일반 선택 id는 정상 응답·행동 기록 유지 | mutation-IRS05.log |
| IR-S07 | 낱개 delete도 기존 hidden 판정에 포함해 등록 조회 거절·정리 | mutation-IRS07.log |
| IR-S08 | 현재 달과 마지막 파일 중 뒤의 달에 이어 씀. 새 파일 생성 때 부모 디렉터리 fsync | mutation-IRS08.log |
| IR-S09 | 영수증 없으면 설치 모양의 hejo platform 블록만 제거. 다른 값은 보존하고 종료 2. 다른 설정·링크·자료는 건드리지 않음 | mutation-IRS09.log(일치·불일치 두 경우) |
| D56-01 | 루프백·Tailscale/WireGuard 전제로 허브 HTTP 유지 이유를 ARCHITECTURE에 명시 | 문서 대조, 제품 동작 변경 없음 |

표의 로그는 `.build/task56/` 아래에 있다. 서버 변형은 해당 핵심 제품 파일을 TASK-55 커밋으로 되돌린 격리 사본이다. 앱 변형은 동기화·구획·업데이트·첨부의 기존 구현, 기호 금지 및 실패 무알림을 한 사본에 복원한다. 정상 컴파일 후 모든 대응 단언이 실패하는지 확인한다. 새 시험은 정상본에서 통과한다.

초기 탐침의 잘못된 token fixture와 앱 진입점·자료 경로 오류는 중간 실패로 보존한다. 첫 앱 전체 검증의 AT93 늦은 대기 응답 회귀는 요청 시점 rev를 결합해 보완했다. AT74의 한도 정리된 스레드 읽음 키는 LWW 쓰기 거절과 구별해 재조회하지 않는다. AT89로 open 없는 정의의 디코딩을 확인하고 옛/새 정의 모두 읽도록 기본값을 보완했다. 이를 제품 결함 증거로 세지 않는다. 수정 전 제품의 정확한 재현은 격리한 TASK-55 코드와 최종 회귀 시험의 변형 로그로도 다시 확인한다.

## 경계·검증

TASK-55는 먼저 별도 커밋했다. TASK-56은 team-kit 코드를 바꾸지 않으므로 추가 패치가 없다. 적용 순서는 현재 운영 계보 위 `.build/task55/team-kit.patch` 하나다. 그 패치의 전체 시험·원본 불변·dry-run을 최종에 다시 대조한다.

team-kit 전체 검증은 격리한 저장소 설정 자료와 가짜 HOME을 사용한다. 초기 혼합 환경 실행에서 현재 운영 입력의 한 프로필 prompt budget 7,771 > 7,600도 관측됐다. 코드 변경과 무관한 운영 규칙 길이는 이 검증으로 해결됐다고 주장하지 않으며, 운영 적용 때 별도 확인할 항목이다. 최종 0은 격리 입력에서의 전체 시험 결과다.

영수증 없는 제거는 소유권을 추정해 나머지 설치를 모두 지우지 않는다. 기본 포트 묶음·루프백 및 선택 Tailscale 주소·owner 허용 목록과 일치하는 기본 문, 또는 정확한 forwarder 블록에만 적용한다. 그 밖의 값은 사장이 확인할 때까지 남는다. 기존 영수증이 있으면 원래 키 단위 복원 경로를 사용한다.

검증 명령·종료 코드·최종 변경본 지문은 `.build/task56/final-verification.json`, 패치 근거는 `.build/task55/patch-result.json`, 변형 표는 두 폴더의 mutations.json과 mutation-app.json이다. 앱 전체 시험은 실제 CLI 설정 lstat와 실제 다운로드 폴더 이름의 불변을 확인한다. 비밀 파일·운영 대화 본문·실제 발송은 시험 입력으로 쓰지 않는다.

필요 인계 증거 수준 2, 도달 2다. 운영 적용·실물 수락 수준 3은 미실행이다. 적용 전 두 main 커밋의 문/앱과 TASK-55 패치를 함께 검토해야 하며, 새 릴리스 생성·운영 반영·재시작은 계획 담당과 사장이 맡는다. public과 운영 원본은 유지했다.
