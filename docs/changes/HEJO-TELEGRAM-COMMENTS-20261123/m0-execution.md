# M0 실행 전 확인 — 운영 쓰기 보류

최신 사용자 실행 승인은 유효하다. 승인 후보와 복구 원본을 재생성하지 않고 대조했다. 후보/복구 HEAD·깨끗한 작업 트리·설치 manifest가 모두 고정 기록과 일치한다. 실제 배포·재시작·probe·bind·푸시는 수행하지 않았다.

읽기 전용 확인에서 게이트웨이 heartbeat가 최신이고 Telegram connected, active_agents=0임을 확인했다. 본체 소스상 active_agents는 active_work_count를 기록하며 active_work 상세는 draining 때만 기록한다. 지정 직원 이름과 일치하는 명부 항목은 하나였고 실제 방 키를 비공개 기록에 확보했다. 이름·키·링크는 공개 문서에 적지 않는다.

다음 조건 때문에 운영 쓰기 전에 보류했다.

1. 사용자가 준비 완료를 알린 시험 채널·연결 그룹의 식별 정보가 현재 인계 및 비공개 기록에 없다. 승인된 시험 공간을 식별해 관측/복구 대상을 고정할 수 없다.
2. 이 대화에서 재시작을 실행하지 않았는데 확인 도중 runtime PID와 launchd PID가 바뀌었다. 원인은 미확인이다. 별도 운영 작업 또는 자동 재기동과 겹치는지 확인해야 한다. 로컬 runtime 기록은 Telegram 연결된 루트 게이트웨이 하나를 나타내지만, 다른 호스트의 동일 봇 수신 부재까지 증명하지 않는다. ps 기반 명령 패턴 탐색은 일치 없음이어서 단일 수신자 증거로 사용하지 않았다.

변화 관측 후 공용 RELEASE와 제품 내용은 다시 대조했고 기존 복구 원본과 여전히 일치했다. 기존 실행 승인을 다시 요청하는 보류가 아니며 시험 공간 식별 및 동시 운영 작업 확인이 필요하다. 정보가 확보되면 설치·유휴·수신자 상태를 다시 확인하고 기존 승인 범위만 실행한다. 연결 확인 전 사용자에게 probe 전송을 요청하지 않는다.

검증: manifest/HEAD/status 대조 Python 종료 0, runtime 제한 필드 요약 종료 0, 명부의 지정 이름 필터 조회 종료 0(한 항목), launchctl print 제한 필드 추출 종료 0, 마지막 설치 대조 종료 0. 상세 비공개 증거는 `.build/telegram-comments/m0/`의 execution-preflight.json, runtime-preflight.json, selected-room-private.json, process-preflight.json, receiver-preflight.json, execution-hold.json이다. 비밀 파일·전체 금고는 열지 않았다. 운영 스냅샷 수집 및 receipt 관측은 아직 실행하지 않았다.

## 계속 실행 요청 후 재확인

사용자의 계속 실행 요청은 기존 M0 승인을 유지한다. 재확인 명령은 종료 0이며 후보·복구·설치 manifest가 모두 일치했다. 설치 RELEASE는 여전히 복구 커밋이고 이번 작업의 배포/재시작 실행 기록은 없다. runtime PID는 직전 최종 관측과 같으며 running, Telegram connected, active_agents=0이었다. 따라서 과거 PID 변경만을 계속 차단 근거로 삼지 않는다.

다만 이번 인계에도 시험 채널·그룹 식별 정보와 다른 호스트의 동일 봇 소비 여부에 대한 답이 추가되지 않았다. 지정 직원 방은 이미 확인했으므로 다시 묻지 않는다. 최신 승인 절이 운영 쓰기 전 시험 공간·유일 수신자를 확인하도록 요구하므로, 두 누락 사항만 사용자에게 요청한다. 추가 실행 승인은 요청하지 않는다. 상세 증거는 비공개 `resume-preflight.json`이며 배포·재시작·probe는 여전히 미실행이다.

## 승인된 배포·재시작 수행 — 사용자 probe 입력 대기

사용자가 시험 채널과 토론 그룹 링크를 구분해 제공했고 동일 봇의 다른 수신 서버가 없다고 확인했다. 실제 값은 비공개 targets-private.json에만 저장했다. 실행 직전 후보·복구·설치 일치, 기존 연결 및 active_agents=0을 확인했다.

- `bash "$CANDIDATE/install/hejo-release" "$RELEASE_DIR"`: 종료 0. 설치 manifest와 RELEASE가 후보 `6621b74e0b78d1012d761924d9a664b8259534c1`에 일치한다.
- `hermes --profile default gateway restart`: 1회 실행, 종료 0. 추가 재시작 없음.
- 재시작 후 runtime 요약: 새 PID, running, Telegram connected, active_agents=0, restart_requested=false. 시작 중 connecting을 관측한 뒤 연결 완료를 확인했다.
- 승인 범위의 두 상태 파일만 접근 제한 로컬 스냅샷으로 복사하고 복사 전후 파일 크기·수정시각 불변을 확인했다. 검토된 receipt 요약 도구: 종료 0, no_probe. 전체 금고·인증 비밀 파일 출력 없음. journal 월별 파일 크기·해시를 시험 전 기준으로 비공개 저장했다.

실제 명령과 출력은 비공개 `.build/telegram-comments/m0/deployment-execution.json`, 연결 확인은 post-restart.json, 사전 확인은 approved-preflight.json에 있다. before-probe-summary.json 및 journal-before-probe.json을 관측 기준으로 사용한다. 기존 execution-hold.json의 미실행 값은 이전 시점 기록이며 이 절과 deployment-execution.json이 최신이다.

다음은 사용자가 지정 시험 토론 그룹에 정확한 probe 명령을 한 번 보내는 단계다. 아직 시험 발신·60초 관측·사람 화면 확인은 미실행이다. 자동 재시험·bind·TASK 2~4·푸시는 하지 않는다. 배포와 재시작을 반복하지 않는다.

## M0 첫 실물 관측 — 미통과

사용자가 지정 토론 그룹에 명령을 보냈다고 알렸고, 이후 봇의 반응은 아무것도 없었다고 확인했다. 첫 상태 확인부터 약 60초 뒤 재확인까지 새 probe 예약이 없었다. 검토된 요약 도구는 두 번 모두 종료 0 / no_probe를 반환했다. 따라서 이는 pending deadline 초과 판정이 아니라 **probe 접수 자체의 증거 부재**다. Bot API 자동 전달 기능이 불가능하다는 결론은 내리지 않는다.

- 영속 probe/세 receipt: 확보하지 못함. 성공 판정 불가.
- 사용자 화면: 봇 무응답. 게시물 아래 댓글 표시 증거 없음.
- 앱 journal: 시험 전 월별 파일 크기·SHA-256과 관측 후가 동일.
- runtime: 관측 시 running·Telegram connected·active_agents=0. 순간값만으로 관측 구간 전체의 직원 호출 0을 독립 입증했다고 주장하지 않는다.
- 로그 제한 검색에서 comments 거부/안내 실패 표식은 발견하지 못했다. 읽은 로그 구간에는 기존 네트워크 예외 등이 섞여 있으므로 원인을 특정하지 않았다. 원문 로그·개인값은 공개하지 않았다.

상태 스냅샷은 비공개 observe-* 폴더에, 안전한 요약과 시각·사용자 반응은 probe-observation.json 및 probe-final-observation.json에 기록했다. journal 비교와 제한 로그 계수는 probe-diagnostics.json에 있다. 전체 금고·인증 비밀 파일 출력은 하지 않았다.

자동 재전송·재시험·bind·후속 구현은 수행하지 않았다. 배포한 후보는 유지하며 추가 재시작이나 롤백도 하지 않았다. 현재 금고에서 예약이 보이지 않는다는 이유만으로 늦은 입력 가능성까지 배제할 수 없으므로 수신 상태를 확인하지 않은 구버전 복귀를 실행하지 않는다. 기획 담당에게 M0 미통과를 반환한다. 다음은 기존 봇·명령·짝 인증·native 처리기 등록/수신 경계를 읽기 전용으로 원인 조사하고, 필요한 수정 및 재시험 범위를 별도로 정하는 것이다. 사용자에게 명령을 다시 보내도록 요청하지 않는다.

## 개인 발신 재시험 준비 — 설정 해제 확인 대기

최신 재시험 승인을 확인했다. 재배포·재시작 없이 현재 RELEASE와 설치 manifest가 승인 후보에 일치함을 확인했다. runtime은 running·Telegram connected·active_agents=0·restart_requested=false이고 준비 중 두 조회에서 PID가 같았다. 현재 관측에 종료 작업 징후는 없으며 이후 변경 여부는 명령 안내 직전 재확인한다.

이전 관측과 구별되는 접근 제한 상태 스냅샷 및 journal 크기/해시 기준을 확보했다. receipt 요약 종료 0, no_probe. 실행 기록은 비공개 retry-preflight.json 및 retry-baseline.json에 있다. 사용자의 익명 설정 해제·기존 짝 개인 계정 발신 준비는 아직 확인되지 않아 명령을 다시 안내하거나 발신하지 않았다. 재시험 승인 자체는 다시 요청하지 않는다.

## 개인 발신 준비 확인 — 재시험 명령 안내

사용자가 익명 설정 해제 완료를 확인했다. 기존 재시험 승인을 유지하며 재승인을 요청하지 않는다. 명령 안내 직전 후보 RELEASE/설치 manifest 일치, running·Telegram connected·active_agents=0·restart_requested=false와 두 조회 사이 PID 안정을 확인했다. 제한 상태 스냅샷 요약은 종료 0 / no_probe이며 새 journal 크기·해시 기준을 확보했다. 실제 개인 발신 신원은 새 입력의 인증 판정으로 확인한다.

최신 재시험 기준은 비공개 `.build/telegram-comments/m0/retry-ready.json`이다. 앞선 retry-baseline.json 대신 이 기준을 새 관측에 사용한다. 비공개 기록의 동일 방 키로 정확한 probe 명령을 안내하고 사용자 전송을 기다린다. 재배포·재시작·실제 발신은 하지 않았다. 정상 봇 발신 최대 3건·60초 관측 승인만 유지하며 자동 추가 시험·bind·후속 TASK·푸시는 금지한다.

## 개인 발신 재시험 — 기계 receipt 완결, 화면 확인 대기

사용자가 한 번 전송했다고 확인한 뒤 새 관측을 수행했다. 준비 기준 대비 새 probe 1개, channel/forward/comment receipt 정확히 3개, 모두 deadline 이내이며 상태 complete다. 첫 channel receipt부터 comment receipt까지 간격은 약 6.805초다(접수부터 전체 소요 시간과 구별). 예약·계약·짝·사장 일치 및 지정 방 일치를 확인했다. 요약/대조 명령 종료 코드는 각각 0이다.

승인 후보 설치 해시가 유지됐으며 bind 저장 목록과 앱 journal 월별 파일 크기/해시가 시험 전후 동일하다. runtime 조회는 running·Telegram connected·active_agents=0이다. 실제 직원 호출 0에 관해서는 journal 불변과 제한 관측을 제시하며 구간 전체 실행 추적을 확보했다고 과장하지 않는다. 세 receipt 중 forward는 수신 기록이며 별도 봇 발신으로 세지 않는다. 시작 안내의 별도 발신 receipt는 저장 형식에 없으므로 세 receipt만으로 안내 포함 전체 발신 횟수를 직접 입증했다고 주장하지 않는다.

기계 증거는 `logs/m0-retry-machine.json`, 상세 비공개 상태는 `.build/telegram-comments/m0/retry-observation.json` 및 `retry-machine-result.json`에 있다. 사용자에게 채널 게시물의 댓글 진입 후 시험 댓글이 해당 게시물 아래 보이는지와 클라이언트 환경을 확인 요청한다. 화면 확인 전 M0 전체 통과를 선언하지 않는다. 이번 턴에서 재배포·재시작·추가 발신·재시험·bind·후속 TASK·푸시는 수행하지 않았다.

## 개인 발신 재시험 — 사용자 댓글 화면 확보, 검토 반환

사용자가 채널 게시물 화면과 그 게시물의 토론 화면을 제공했다. 첫 화면에서 시험 게시물에 댓글 1개가 표시되고, 두 번째 화면에서 동일 시험 원문 아래 봇 시험 답장 1개가 묶여 있는 것을 직접 확인했다. 화면 메시지 시각은 재시험 기계 관측과 부합한다. 따라서 기계 complete/세 receipt와 별도로 게시물별 댓글 묶음의 실물 화면 증거를 확보했다.

원본 화면은 다른 대화 및 개인값을 포함하므로 공개 저장소에 추가하지 않고 접근 제한 `.build/telegram-comments/m0/screen-evidence/`에 보관했다. 파일 해시와 관찰 내용은 같은 폴더 evidence.json에 있다. 공개 기계 결과의 humanScreenConfirmed를 true로 갱신했다. 화면은 macOS 데스크톱 형태지만 정확한 OS/Telegram 버전은 화면에 없으므로 미확인으로 기록한다.

M0의 핵심 동작은 이번 재시험에서 관측됐으며 기획 담당에게 수락 검토를 반환한다. 전체 기능 완료 또는 후속 TASK 착수 승인으로 해석하지 않는다. 기존 보고의 직원 호출 전체 추적 및 안내 포함 발신 횟수 독립 관측 한계도 유지한다. 추가 명령·발신·재배포·재시작·bind·TASK 2~4·푸시는 수행하지 않았다. 정확한 클라이언트 버전 등 남은 기록 보완 여부는 검토에서 판단한다.
