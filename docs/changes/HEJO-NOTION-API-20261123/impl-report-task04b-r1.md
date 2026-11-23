# TASK-04B-R1 — 실제 connections 격리 통합 통과

자체 점검·증거 수준2. [최종 결과](logs/task04b-r1/fixture-result.json), [실행/보존 확인](logs/task04b-r1/checks.json). TASK-04A-R1 제품7파일과 이전401파일 생성 결과는 변경하지 않았다.

## 원인과 시험 경계

제한적 진단 종료1: 최초 read_plist는 hermes_packs.mac_apps.discovery의 설치 앱 metadata 읽기였다. 실제 앱 파일 내용은 audit hook이 읽기 전에 차단했다. 정확한 경로는 비추적 private 증거에만 기록했다. 시스템 metadata로 오인해 앱 목록 전체를 허용하지 않았다.

실제 discovery의 APP_ROOTS만 홈별 임시 빈 앱 폴더로 지정했다. 연결·검색·catalog·inventory 코드 자체는 그대로다. 이 첫 fixture 실행도 종료1이었고 이번 경계는 표준 라이브러리 _osx_support._get_system_version의 시스템 버전 plist 읽기였다. 해당 시스템 metadata canonical 파일 하나만 허용한 최종 실행은 종료0이다. 사용자 상태는 임시 홈에만 있고 네트워크·추가 subprocess 거부는 유지했다. 경계 진단 원문과 스크립트는 격리 worktree의 .build/task04b-r1/에0600으로 보존했다.

## 확인한 결과와 한계

두 홈 각각 실제 생성 설치기 신규 설치0, --check0, 실제 TeamKit→설치 CLI→connections apps 성공, 직접 CLI 종료0이다. 응답 schema는 hermes-installed-apps/1이며 agents/apps/services 필드가 존재한다. 서로 다른 기본 직원과 홈별 runtime 경로를 사용했다. runtime 경로들은 같은 검증 Python에 연결되므로 다른 OS/컴퓨터의 증거는 아니다.

추적 중 관측한 msvcrt/_ruamel_yaml 예외는 성공 결과에서도 발생하므로 이번 호출의 필수 의존성 결함으로 분류하지 않는다. import 오류 전체를 무시하거나 가짜 connections 모듈로 우회하지 않았다. 이전 실패 원인은 시험의 환경 경계 구성 오류로 처분하며 제품 변경이 필요하다는 근거는 없다.

실제 자격·Notion API·페이지·미래 하위 발견은 실행하지 않았다. 빈 가짜 앱 폴더에서의 연결 목록 경로 성공이며 모든 앱 탐색·계정별 기능을 검증한 것은 아니다. 현재 정상 사용자 연결과 서비스는 변경하지 않았다.

## 판정과 후속

V-HNA-04A-03의 임시 공개 입력 생성·개인값 검사·실제 connections 신규 설치/gate 통합 증거는 확보했다. 운영 수집·실제 공개 배포·독립 환경·고위험 독립 최종 검토·Git/푸시는 별도 미완료다. 전체 판정은 부분 완료다. 실제 수집 전에 원본/대상 CAS와 다른 작업 보존, 개발 시험 보존 경로 및 적용 파일 목록을 구체 인계로 확정해야 한다. 본체 수정·정상 서비스 재시작·과거 사용자 저장 전 상태 롤백은 하지 않는다.
