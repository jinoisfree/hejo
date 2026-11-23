# TASK-04B — 임시 공개 입력 통합 검증 범위

읽기 조사 완료. TASK-04A-R1의7파일 해시가 그대로임을 확인했다. 이번에는 생성기·연결 모듈을 실행하지 않았고 운영 수집·공개 checkout·서비스·커밋·푸시를 변경하지 않았다. 현재 대화가 직접 이어간다.

## 입력과 책임

기준은 [입력 목록](logs/task04a-r1/input-inventory.json)이다. 최종 제품11파일은 수락된 설치 코드의 명시 해시를 사용하고 기존 회귀2파일 및 격리 후보 시험5파일은 개발 검증 자료로 따로 보존한다. 실제 수집 사본은 바꾸지 않는다. 임시 입력은 검증 fixture이며 배포 원본이나 별도 제품 원본으로 취급하지 않는다.

임시 root에 승인된 생성기·manifest·공개 템플릿·공개 검사 정책을 사용한다. manifest가 지정한 플러그인 코드 트리와 공유 라이브러리/관리 링크를 보존하고 제품11파일만 수락 해시로 겹쳐 구성한다. 코드 외 owner/config/profile/명부/금고/기억/로그는 운영에서 복사하지 않는다. template 변환이 source_path 존재 확인을 요구하는 항목은 가짜 최소 입력으로 충족하며 실제 결과는 기존 공개 템플릿에서 생성한다. copy/redact 항목은 개별 허용 코드·공개 자산만 포함한다. 미분류 입력이 있으면 구성 전에 보고하며 임의 빈 파일로 성공을 만들지 않는다. 민감 치환표는 원문을 공개 증거로 옮기지 않는다.

## 기존 검증 진입점

- make-starter.build(): manifest/tree_entries·기존 치환과 provenance를 적용해 메모리 결과를 만든다. ROOT는 임시 입력으로 지정한다. tests/cache 제외와 관리 링크 정책은 그대로 사용한다.
- starter-public.build(base): 동일 build 결과를 bytes로 변환한다. 추가 제품 파일을 만드는 별도 생성기가 아니다.
- starter-public.findings(base, files): 기존 공개 검사 정책으로 결과를 검사한다. 실제 정책을 완화하거나 오탐을 자동 allowlist에 넣지 않는다.
- 검사 통과 결과만 임시 출력에 기존 write_output으로 작성한다. 설치기의 inventory 계약을 그대로 검증한다. 재생성 해시 일치와 결과 파일 개인값 검사를 수행한다.
- 공식 --target 경로의 --prepare/--publish는 source_clean·fetch·stage·commit·hook·원격 쓰기를 포함하므로 이번 검증에서 호출하지 않는다. --check도 Git 추적 목록을 확인하는 check_output을 사용하므로 임시 파일 검증과 원격 공개판 검사 성공을 혼동하지 않는다.

## 실제 연결 의존성

[AST 조사](logs/task04a-input-review/dependencies.json)는 connections/app_connect/app_setup/discovery/notion.api에서 시작해 함수 내부 절대 import까지 로컬76모듈을 확인했다. 실제 실행 없이 파일 해시와 경로를 기록했다. 이 결과는 상대 import·동적 import·데이터 파일까지 포함한 완전한 의존성 증명이 아니다.

현재 가짜 connections 시험은 실제 app_registry·connection_checks·catalog/discovery·team_registry·설정 reader와 관련 자료를 우회한다. 이 모듈들을 테스트 대역으로 바꾸지 않고 임시 배포 결과에서 실행해야 한다. hermes_yaml/hermes_constants는 core 제공 여부, ruamel.yaml·dotenv·markdown·psutil 등은 선택 runtime의 설치 여부와 실제 도달 경로를 확인해야 한다. 정적 import에 나타났다는 이유만으로 apps의 필수 의존성이나 설치 결함으로 단정하지 않는다. CLI의 -I 실행과 lib 경로 추가만으로 core 모듈 접근이 해결된다고 가정하지 않는다. 본체를 수정하거나 운영 Python에 패키지를 설치하지 않는다.

## 격리 수락 순서

1. 임시 입력 목록의 출처·해시·모드·링크와 제품11파일의 수락 해시를 확인한다. 두 번 build 결과의 동일성을 검사하고 공개 검사에 실패하면 설치하지 않는다.
2. 임시 홈2개에 서로 다른 가짜 기본 직원/명부를 사용해 실제 modern_main 신규 설치를 실행한다. 기존 실제 config_assembly와 실제 connections를 사용한다. runtime 선택은 검증용 환경으로 한정하고 설치·다운로드 fallback은 막는다.
3. 실제 TeamKit→설치 CLI→connections apps로 명부/앱 목록과 홈 분리를 확인한다. 가짜 빈 자격만 사용하고 네트워크·외부 계정 CLI·서비스 실행은 시험 경계에서 금지한다. 예상하지 않은 외부 호출은 성공 대역으로 치환하지 않고 실패시킨다.
4. 선택된 runtime의 필요한 모듈 import 및 데이터 경로를 확인하고 누락은 모듈·경계만 기록한다. 실제 비밀·사용자 페이지는 조회하지 않는다. 설치 receipt/check/업데이트 보존까지 확인한다.
5. 생성 결과와 설치 코드의 대상 해시/변환 provenance를 보존한다. 이 결과는 수준2이며 실제 다른 컴퓨터/사용자 계정 성공이나 공개 배포/Git 완료를 대신하지 않는다.

## 현재 판정

구성 계획과 기존 진입점 조사는 완료했다. 실제 최종 코드 공개 생성·신규 설치 통합은 아직 미실행이다. V-HNA-04A-03은 유지한다. 정상 Notion 연결과 서비스는 변경하지 않는다. 추가 제품 수정이 필요한지는 실제 격리 통합의 오류를 확인한 뒤 기존 책임 안에서 판단한다.
