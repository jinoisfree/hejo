# 외부 코드 복사 검토

## TASK-07 개인값 패턴

- 원본: `<운영 저장소>/hermes/plugin-store/team-kit/lib/hermes_facility/airport_boundaries.py` 전체(모듈 끝 `return findings`까지)를 실제로 읽었다. 의존은 표준 라이브러리 hashlib·json·pathlib·re다. YAML 입력에만 ruamel.yaml을 지연 import한다. 의존 소스 복사는 없다.
- 실제 원본 저장소 경로는 추적하지 않는 `AGENTS.local.md`에서 확인한다.
- 가져올 것: Slack ID·이메일·사용자/볼륨 절대 경로·fixed_home 정규식, 명부 단어 추출·단어 경계 처리, 금고 문자열 분류 규칙. 원본의 역할은 탐지이며 예외 정책은 호출자 책임이다.
- 가져오지 않을 것: 확장자 제한·시험 폴더 제외·디렉터리 순회·종류/경로/정규화 문장 기반 지문. hejo design 7절은 git 추적 텍스트 전체와 줄 내용 지문을 요구한다. 예약 id 패턴은 같은 절의 hejo 탐지 종류에 없으므로 가져오지 않는다.
- hejo 책임: `scripts/scan_private.py`가 추적 파일 분류·두 고정 입력·탐지·줄 단위 예외·출력을 소유한다. 원본 저장소 import·수정·동기화는 하지 않는다.
- 보안 경계: 운영 홈에서는 owner/team.yaml·owner/vault.yaml 두 파일만 연다. 값·원문·예외 이유는 출력하지 않는다. 예외는 가짜 시험 값 또는 LICENSE 저작권 고지 줄만 허용한다.

## TASK-05 앱·펫 (복사 전 검토)

원본 커밋: `36c5aee148b952d0a068c1832df21d3ba7efe20d`. 실제 위치는 미추적 `AGENTS.local.md`로 확인했다. 아래 파일은 각각 첫 줄부터 끝까지 읽었다. 원본 저장소는 수정하거나 import하지 않는다.

| 원본 | 전체 줄 | 결정·목적지·의존 처리 |
|---|---:|---|
| `<운영 저장소>/ddots/Sources/PetLayout.swift` | 404 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/GenieView.swift` | 70 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/PetAnimation.swift` | 167 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/PetPointerInteraction.swift` | 35 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/PetSpriteRasterizer.swift` | 92 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/PetSpriteContour.swift` | 95 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/PetSpritePresentation.swift` | 67 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/ScreenWindowResolver.swift` | 32 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/SpriteAtlas.swift` | 94 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/SmokeCheck.swift` | 23 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/ScreenFocus.swift` | 83 | app/Sources/에 독립 복사; Foundation·CoreGraphics·AppKit·Accelerate 및 이 표의 펫 의존만 유지 |
| `<운영 저장소>/ddots/Sources/AppIdentity.swift` | 61 | 정체성·단일 실행만 새 구현; 이전 앱 이주·프로세스 강제 종료 제거 |
| `<운영 저장소>/ddots/Sources/LoginLaunch.swift` | 124 | LoginLaunchState·Presentation·LoginLaunch만 유지, AppMaintenance 제거 |
| `<운영 저장소>/ddots/Sources/MenuBarIcon.swift` | 37 | AppKit 아이콘 그대로 |
| `<운영 저장소>/ddots/Sources/PetIdentity.swift` | 40 | 이름 정규화 방식만 유지, 기본 이름 hejo·hejo-local.json으로 교체 |
| `<운영 저장소>/ddots/Sources/Models.swift` | 110 | Provider·WorkState만 유지, 관찰·작업·스냅숏 모델 제거 |
| `<운영 저장소>/ddots/Sources/PetView.swift` | 1664 | PetPanel·펫 입력·NSView cacheDisplay만; SwiftUI·Slack·클립보드·말풍선·파일 놓기 호스트 제거 |
| `<운영 저장소>/ddots/Sources/App.swift` | 2575 | 배치·열고닫기·끌기·화면 변경만 PetController로 이동; 나머지 제거 |
| `<운영 저장소>/ddots/Sources/PetCarrySmoke.swift` | 59 | PetController 대상 AppKit 시험으로 옮김, 실제/가짜 화면 자동 시험에 통합 |
| `<운영 저장소>/ddots/Sources/SlackController.swift` | 1622 | SlackToken의 security 프로세스 입출력 방식·기본 AppKit 편집 메뉴만 참고; 서비스·계정 검증 새 구현, Slack·이전 키체인 이주 전부 제거 |
| `<운영 저장소>/ddots/Sources/UsageSources.swift` | 167 | URLSession 비동기 작업 방식만 참고, 모니터링·설정·프로바이더 결합 전부 제외 |
| `<운영 저장소>/ddots/Sources/OptionsLayout.swift` | 11 | 검토만, 이번 작업에서 복사하지 않음 |
| `<운영 저장소>/ddots/Sources/DdotsThreadWindow.swift` | 25 | 검토만, 이번 작업에서 복사하지 않음 |
| `<운영 저장소>/ddots/Sources/ClipboardAttachments.swift` | 102 | 검토만, 부가 기능 제외 |
| `<운영 저장소>/ddots/Sources/AttachmentDrop.swift` | 82 | 검토만, TASK-06 전까지 복사하지 않음 |
| `<운영 저장소>/ddots/Sources/ProfileAvatar.swift` | 115 | 검토만, 사진 기능 제외 |
| `<운영 저장소>/ddots/scripts/build.sh` | 73 | 단일 swiftc·번들·서명 순서만 참고, Sparkle·배포·다른 앱 설정 제거 |
| `<운영 저장소>/ddots/Resources/Info.plist` | 26 | 번들 키 참고, hejo 식별자로 새 작성 |
| `<운영 저장소>/ddots/Resources/Pet/LICENSE` | 8 | 전체 고지 그대로 동반 |
| `<운영 저장소>/ddots/Resources/Pet/pet.json` | 7 | 검토만; 기존 이름·식별자 가져오지 않음 |

- 의존: SpriteAtlas → PetAnimation·PetLayout·PetSprite*·SmokeCheck, PetSpriteContour → Accelerate, PetAnimation → WorkState, ScreenWindowResolver → ScreenFocus·ScreenWindowSelection → Provider. 이 의존은 모두 위에서 전체 검토했다. PetView·App의 제거 대상 SwiftUI/Slack 호스트와 그 외부 의존은 가져오지 않는다.
- 자산: SpriteAtlas가 읽는 spritesheet.webp·wave.png·doze.png·approval-phone.png의 용도·크기를 확인하고 LICENSE와 함께 app/Resources/Pet에 복사한다. spritesheet는 빌드 때 PNG로 변환한다. pet.json은 쓰지 않는다.
- TASK-06 후보 MessageFormat·SlackLayout·ChatStyle·NativeThreadCard·NativeThreadList·DraftEditor·DraftFormat·Conversation은 이번 작업에 복사하지 않는다. 해당 작업에서 전체 읽기·기록을 선행해야 한다.
- PetCarrySmoke의 원본 AppDelegate 확장은 실제 앱 부가 상태에 의존하므로 새 PetController 시험으로 이식한다. 새 화면 원본은 AppKit 빈 NSView이며 SwiftUI 예외는 없다.
