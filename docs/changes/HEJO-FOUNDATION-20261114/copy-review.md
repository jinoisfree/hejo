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

## TASK-06 대화 화면 (복사 전 검토)

원본 커밋 `36c5aee148b952d0a068c1832df21d3ba7efe20d`. 아래 후보와 유지할 의존의 소스 전체를 첫 줄부터 끝까지 읽은 뒤 기록했다. 실제 경로는 미추적 AGENTS.local.md만 사용한다.

| 원본 | 전체 줄 | 대상·유지/대체/제거 |
|---|---:|---|
| `<운영 저장소>/ddots/Sources/DdotsThreadWindow.swift` | 25 | ThreadWindow.swift: 페이지·보이는 id 유지; 이름 중립화. Foundation만 |
| `<운영 저장소>/ddots/Sources/MessageFormat.swift` | 219 | MessageFormat.swift: 네이티브 파서·직렬화만; SwiftUI import·render(Font/Color 변환) 제거. AppKit/Foundation만 |
| `<운영 저장소>/ddots/Sources/SlackLayout.swift` | 346 | TextLayout.swift: 인용·목록·코드·표의 TextKit 배치만; SlackZones·SlackSectionLayout 제거. MessageFormat·ChatMetrics 사용 |
| `<운영 저장소>/ddots/Sources/ChatStyle.swift` | 293 | ChatStyle.swift: 네이티브 메트릭·팔레트·표면만. DdotsConfig·사용자 기본값/테마 편집·투명도 설정 제외. bodyFont는 현재 화면 기본값 |
| `<운영 저장소>/ddots/Sources/ClipboardAttachments.swift` | 102 | ClipboardAttachments.swift: 대화 입력의 파일/이미지 붙여넣기만. 임시 영역을 hejo로 분리, 50 MiB 계약. SlackFileStore 상수 대체·SlackTemporaryFiles 인자 제거 |
| `<운영 저장소>/ddots/Sources/NativeThreadCard.swift` | 820 | NativeThreadCard.swift: TextKit 카드·서식·스트리밍·네이티브 버튼 유지. NSHosting·AnyView·SwiftUI 측정 제거, 필요한 첨부/버튼 자리는 순수 NSView로. SlackSidebar 상수·ChatView 얼굴 경로 제거 |
| `<운영 저장소>/ddots/Sources/NativeThreadList.swift` | 462 | NativeThreadList.swift: NSTableView·셀 재사용·행 높이·스크롤 핵심을 새 AppKit 클래스로. NSViewRepresentable·Host·SlackModel viewport/EntryViewportStamp/SlackThreadInputs·ThreadLayoutWatch·레거시 토글 제거. 기록장 seq가 원본 |
| `<운영 저장소>/ddots/Sources/DraftEditor.swift` | 231 | DraftEditor.swift: DraftTextView·DraftScrollView만. SwiftUI/NSViewRepresentable·Binding·Coordinator 제거. 대화 뷰의 NSTextViewDelegate로 변경 알림을 연결하고 Enter/Shift Enter는 실제 keyDown 이벤트에서 처리. HTMLText·MessageFormat·ChatMetrics·DraftFormatController 유지 |
| `<운영 저장소>/ddots/Sources/DraftFormat.swift` | 128 | DraftFormat.swift: 서식·실행 취소 AppKit 구현 유지. ObservableObject/@Published·SwiftUI 제거 |
| `<운영 저장소>/ddots/Sources/AttachmentDrop.swift` | 82 | AttachmentDrop.swift: AttachmentDropView만. SlackModel을 대화 입력 콜백으로 대체. SwiftUI modifier/representable 제거, 놓기로 앱 활성화하지 않음 |
| `<운영 저장소>/ddots/Sources/ProfileAvatar.swift` | 115 | ProfileAvatar.swift: 이름 첫 글자·색·네이티브 draw 구조체만. 사진·ProfileAvatarCache·프로필 파일 읽기 제거 |
| `<운영 저장소>/ddots/Sources/Conversation.swift` | 448 | ConversationModel.swift: 글·파일·작성 중·미리보기·링크 열기 개념 참고. seq와 UUID·wire 파일/버튼 필드의 중립 모델로 새 작성. Slack 식별자·휴리스틱 답장 판정·날짜 읽음·프로젝트/달력/넛지/이주 제외 |
| `<운영 저장소>/ddots/Sources/HTMLText.swift` | 175 | HTMLText.swift: 전체 독립 복사. Foundation만. HTML을 실행/로드하지 않고 텍스트만 파싱 |
| `<운영 저장소>/ddots/Sources/BubbleOpacity.swift` | 34 | 미복사: 전체 검토. 기존 반투명 선호 기능은 제외; hejo 불투명 AppKit 표면 사용 |
| `<운영 저장소>/ddots/Sources/SlackFiles.swift` | 125 | 미복사: 전체 검토. 파일 안전 이름/사전 메타 검사 원리만 새 HTTP 전송에 반영. 200MB·Downloads 날짜 저장·Slack id 없음 |
| `<운영 저장소>/ddots/Sources/SlackRetention.swift` | 101 | 미복사: 전체 검토. SlackTemporaryFiles를 포함한 파일 전체를 읽음. 보존 정책·스냅숏·종료 런은 가져오지 않음; hejo cache와 업로드 원본은 기존 칸 유지 |

유지 의존: MessageFormat → AppKit/Foundation, TextLayout → MessageFormat·ChatMetrics, NativeThreadCard → TextLayout·ProfileAvatar·ChatStyle, 입력 → MessageFormat·HTMLText·DraftFormat, 첨부 붙여넣기 → AppKit/Foundation. 모두 위에서 전체 검토했다. 제거 경계의 SlackModel/SlackThreadInputs·DdotsConfig·SlackSidebar·ChatView·ThreadLayoutWatch와 그 SwiftUI/관찰/프로필 파일 의존은 복사하거나 import하지 않는다. 기존 코드에서 어떤 역할을 맡았는지 후보 전체의 호출 지점에서 확인했고 해당 제품 기능 자체를 가져오지 않는다. 기존 번들·설정 키·임시 폴더는 hejo 이름으로 분리하며 사람 이름·프로필·주소 예시는 가져오지 않는다.

### TASK-06 보완 지시 7 — 8판 화면 이식 전 추가 검토

화면 기준이 실행 중 ddots 화면으로 바뀐 `8e89e808c14bd596e26398b72c7bdc8deb106c9f` 인계를 확인했다. 원본은 위와 같은 커밋이다. 아래 파일을 처음부터 끝까지 추가로 읽었고, 기존 후보의 검토 기록과 함께 이식 경계를 정했다. 시안 1·2판은 채택하지 않는다.

| 원본 | 전체 줄 | SwiftUI → AppKit 대응·상수 출처·의존 처리 |
|---|---:|---|
| `<운영 저장소>/ddots/Sources/ChatPanel.swift` | 591 | ChatView의 배치·ChatDragView → ConversationView·ConversationHeaderDrag. 창/펫 동반 이동 4px 임계값 유지. iMessage·웹·달력·말풍선 답장·ChatModel 연결 제거, 새 중립 컨트롤러 연결 |
| `<운영 저장소>/ddots/Sources/SlackPanel.swift` | 3574 | slackPane/Rooms/Tab/Row/SearchField/SidebarHandle → ConversationView·EmployeeSidebarCell·SidebarHandle. SlackSidebar의 68/212/72/180/300/58/52/124/34 그대로 ConversationSidebar 상수. slackThread/Line/Stack/Foot → NativeThreadCard+중립 카드 조립, 카드 간격18·대화 위아래14. slackComposer/SlackComposerInput → NativeComposer(새 글/답글·10px 여백·8px 간격·첨부38·송신42·입력14/11). slackNoticeBar/Failures → native notice/error strip. SwiftUI 관찰/Binding/플랫폼 모델 제거. 단체방 구역·핀·음소거·멘션 얼굴·공방/프로젝트·금고/드라이브·웹·자동 휴리스틱 판정은 가져오지 않음. 상태·버튼은 wire 메타만 |
| `<운영 저장소>/ddots/Sources/ChatWorkspace.swift` | 56 | workspaceBrand/Header → native 머리글. 44px·브랜드14/버전10·제목14/설명10·좌우18·밑줄. 맥의 미니 펫은 원본에서도 꺼져 있어 미추가. 없는 기능의 자리도 비움 없이 제거 |
| `<운영 저장소>/ddots/Sources/ChatPresentation.swift` | 468 | ChatModel 펼침/읽기/스크롤·문맥 메뉴 흐름 검토. 기존 중립 모델·컨트롤러를 유지, UI의 카드 한 개 펼침·초안 대상 전환·배경 클릭 접기만 AppKit으로. iMessage 검색·달력·프로필/설정 의존 제외 |
| `<운영 저장소>/ddots/Sources/NativeThreadContent.swift` | 311 | nativeThreadContent/Post의 root/replies/stack/style 조립 → ConversationView.threadContent/postPieces. 기존 NativeThreadCard 순수 AppKit 경로 사용, hosted approval/files/typing 조각은 NSView 부속 뷰로 대응. 서버 발행 버튼 id·첨부 메타로만 동작. Slack 링크·분기·삭제는 Slack 전용 경로로 제외(규격 밖 프레임 미추가); 복사·접기는 로컬 동작 유지 |
| `<운영 저장소>/ddots/Sources/SlackThreads.swift` | 1471 | 전체 읽음. SlackStack의 2개 이하 답글 전체 표시·긴 스레드 최신+미처리 버튼 유지 정책과 버튼 아이콘 대응만 중립 모델에 이식. SlackState·SlackNotice·읽음 휴리스틱·프로필 라우팅·외부 설정/프로젝트·개인 예시 전부 미복사 |
| `<운영 저장소>/ddots/Sources/PetView.swift` | 1664 | 전체 읽음. PetBadgeView·updatePetBadge → hejo PetBadgeView와 닫힘 unreadCount 배지. 13px·8.5pt·흰 글씨/파랑·1px 흰 테두리·머리 오른쪽 배치. glass/vibrancy+scrim 기본65% 처리만 AppKit 표면에 대응. 기존 genie·패널은 유지. ClipboardShelf·BubbleReply·FileDropCard·SwiftUI 호스트·SlackModel·work 상태 의존은 미복사 |
| `<운영 저장소>/ddots/Sources/BubbleOpacity.swift` | 34 | 기본65% tint·동작/투명도 줄이기 처리만 사용. 선호 저장·설정 UI 추가 없음 |

NativeThreadList/Card·SlackLayout·ChatStyle·DraftEditor·DraftFormat·AttachmentDrop·ProfileAvatar는 위 TASK-06 전체 읽기 기록을 재사용한다. 새로 유지하는 호출은 모두 이미 읽은 MessageFormat/TextLayout/ProfileAvatar/ChatMetrics/ThreadAppearance/네이티브 입력과 기존 PetLayout/SpriteAtlas뿐이다. SwiftUI·NSViewRepresentable·NSHosting·Slack 계약은 가져오지 않는다. 각 원본의 나머지 호출·전역 상태·자원은 제거 경계로 분류했으며 그 모듈을 읽거나 실행해 설정을 가져오지 않는다. 개인 이름·원래 번들·경로·프로필 예시는 이식하지 않는다. 실제 ddots 실행·설정 변경·운영 저장소 쓰기는 하지 않는다.

방 단위 모델 추가 인계 `007b68f592ee3c549d7a407bcbcf53117e22f262`도 반영했다. Room은 Hermes 명부 직원에서 파생하는 direct 방이며 통신 규격/캐시 권위를 추가하지 않는다. 이후 시안 문서만의 변경은 화면 기준으로 삼지 않는다.

## TASK-17 창·펫·설정 (복사 전 검토)

현재 원본 커밋 `208f6e6322f593729c9ef6ac16ac903be4c3692b`에서 아래 여섯 파일과 기존 전체 검토 커밋 `36c5aee148b952d0a068c1832df21d3ba7efe20d` 사이의 파일 diff는 0이다. 따라서 앞의 TASK-05/06 전체 읽기 기록을 App·ChatPresentation·PetView·SlackController에 재사용하고, 이번 작업의 해당 호출·상태 경계를 다시 읽었다. 새 후보 BubbleReveal·SettingsPages는 이번에 전체를 읽었다. 원본 실제 경로는 미추적 `AGENTS.local.md`만 사용한다.

| 원본 | 전체 줄 | 유지·대체·제외와 의존 |
|---|---:|---|
| `<운영 저장소>/ddots/Sources/App.swift` | 2575 | 창 크기 저장·넓게·초기화, 말풍선 알림, 펫 크기·쉬기/숨기기·설정 메뉴·화면 절전 흐름만 AppDelegate/PetController에 옮긴다. UserDefaults 키는 hejo LocalSettings와 허브 회원 설정으로 바꾼다. Slack/iMessage/Relay/대시보드·부가 창의 호출·상태는 제외한다. |
| `<운영 저장소>/ddots/Sources/ChatPresentation.swift` | 468 | replyExtraHeight·slackFitHeight의 열린 스레드 측정 원칙을 NativeThreadList 측정값과 PetController 높이 계산으로 바꾼다. SwiftUI ObservableObject·검색/달력/슬랙 상태는 제외한다. |
| `<운영 저장소>/ddots/Sources/PetView.swift` | 1664 | BubbleReveal 갱신·말풍선 클릭, PetAnimationTimeline/Doze의 우선순위와 화면 잠금 정지를 현재 AppKit PetView에 적용한다. 기존 Genie·PetPlacement·SpriteAtlas를 유지한다. NSHosting·SlackModel·클립보드/파일 호스트는 제외한다. |
| `<운영 저장소>/ddots/Sources/BubbleReveal.swift` | 14 | 3초 alert/held 계산을 별도 순수 모델로 이식한다. 의존은 Foundation뿐이다. |
| `<운영 저장소>/ddots/Sources/SettingsPages.swift` | 229 | AppKit 설정 문서의 범주별 배치만 참고해 일반·화면과 펫 설정을 만든다. SwiftUI PreviewTextFrames·AppearancePreview·NSHostingView와 테마/불투명도 편집은 이번 단계에서 제외한다. |
| `<운영 저장소>/ddots/Sources/SlackController.swift` | 1622 | 마지막 AppDelegate 편집 메뉴의 redo ⌘⇧Z 배치만 현재 메뉴에 반영한다. SlackToken·SlackController 전체는 가져오지 않는다. |

유지 의존은 이미 검토·이식된 `PetLayout`·`PetAnimation`·`SpriteAtlas`·`NativeThreadList`·`ConversationModel`이다. 말풍선은 현재 모델의 직원 글과 IslandModel 상태만 읽으며 새 기록 원본을 만들지 않는다. 앱 창 크기는 LocalSettings, 이름·크기·항상 보이기는 허브 회원 설정이 원본이고 로컬 설정은 화면용 복제본이다. 원본 파일의 Slack/iMessage 식별자·계정·경로·토큰·사용자값은 이식하지 않는다.

### 보완 12-2 우클릭 메뉴

`<운영 저장소>/ddots/Sources/SlackPanel.swift`의 전체 파일 배치와 1987~2045 메뉴, 2096 `slackPinMenu`, 1247 `hide`/`restore`, 1351 `toggleMute`, 684~693 사이드바 너비 동작 및 관련 상태·의존을 읽었다. `ChatWorkspace.swift`는 전체 56줄을 읽고 머리줄 메뉴를 확인했다. 두 원본은 SwiftUI와 SlackModel에 의존하므로 코드를 직접 복사하지 않고 메뉴 순서와 고정·숨김·알림·너비 상태 전이만 AppKit `ConversationView`/`ConversationModel`로 옮긴다. Slack API, 그룹·채널, iMessage, 보관·삭제, 방 생성 및 전체 검색은 이 단계에 들이지 않는다. 허브 회원 설정은 기존 `HubClient.save`로 보내며 로컬 값은 오프라인 화면용 복제다.
