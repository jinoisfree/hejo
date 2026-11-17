# TASK-35 세 손가락 탭 비교

필요/도달 인계 증거 수준은 2다. 실제 트랙패드·운영 앱 전체를 실행한 비교가 아니라, 같은 가짜 건강 상태와 진단 값으로 원본 표시 조각과 hejo AppKit 보기를 조립한 비교다.

| 상태 | ddots 원본 | hejo |
| --- | --- | --- |
| 설정 켬·정상 | [체크 표시 조각](task35-ddots-settings.png) | [화면과 펫 설정 내용](task35-hejo-settings.png) |
| 접촉 프레임 검사 실패 | [원본 실패 창](task35-ddots-failure.png) | [hejo 실패 창](task35-hejo-failure.png) |

원본 ThreeTapController의 실패 창을 직접 컴파일·실행했고, 체크는 App.swift의 native NSButton 생성·크기를 분리했다. 원본 앱 전체의 설정 페이지는 아니다. hejo는 실제 PetSettingsWindow의 선택된 펫 설정 내용(탭 머리 제외)을 흰 바탕에 붙여 그리고 ThreeTapController의 실패 창을 사용한다. 두 실패 창의 문장·버튼 순서·요청문 구조를 비교하며, 요청문의 ddots→hejo는 승인된 변환 규칙이다. 테스트 실행 파일의 기본 아이콘과 가짜 Mac/OS/앱 값으로 캡처해 실제 사용자 진단 정보는 없다.

흰 바탕은 캡처하는 보기의 배경색이며 그림 후처리를 하지 않았다. 원본 체크 조각과 hejo 전체 설정의 창 크기·기존 설정 배치는 다르다. 트랙패드 없음은 원본대로 체크를 비활성으로 만들지 않고 도움말로 안내한다(26판 코드 우선). 실패 때는 체크가 꺼지고 비활성이며 로컬 요청문 복사만 제공한다.

AT-HF-86은 가짜 접촉 프레임과 기기 전송 대역을 사용한다. 탭 0.2초·긴 누름·네 손가락·이동·0.4초 쿨다운, 30연속 이상 프레임, 기호 없음, Touch Bar 분류, 쉬는 중/숨김/설정 끔, 찾아보기 안내·실패 중복 억제·잠자기 깨기와 Mac별 설정 복원을 확인한다. 실제 MultitouchSupport 콜백의 ABI와 노트북 트랙패드로 열고 닫기는 TASK-23 실물에 남는다.

생성기·로그는 추적하지 않는 `.build/task35/reference.py`, `reference.json`, `focused.json`, `capture-final.json`에 남긴다. 운영 홈·앱 사본·공용 릴리스·원격은 변경하지 않는다.
