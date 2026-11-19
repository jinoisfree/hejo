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

## TASK-22 홈 채널 설치

앱·UI와 ddots 코드의 복사 대상은 없다. 기존 hejo 설치 도우미·시험을 직접 읽고 같은 책임 자리에서 변경했다. 따라서 새 ddots 원본 검토·앱 캡처는 해당하지 않는다. TASK-20·21의 사진·구획·단체방은 해당 ddots 원본 전체를 읽고 별도로 기록한다. ddots는 읽기만 허용하고 수정하지 않는다는 사용자 확인을 받았다.

## TASK-24 회원 상태 동기화 (19판)

원본 커밋 `208f6e6322f593729c9ef6ac16ac903be4c3692b`. 아래 파일을 첫 줄부터 끝까지 읽었다. 해당 파일의 원본 작업 트리 변경은 없다. 실제 경로는 AGENTS.local.md만 사용한다.

| 원본 | 전체 줄 | 유지·대체·제거와 hejo 대상 |
|---|---:|---|
| `<운영 저장소>/ddots/Sources/SettingsSync.swift` | 145 | 항목 LWW·읽음 큰 값·삭제 표시·배치 덮어쓰기·잘라내기 원리를 hub/state.py와 MemberState.swift로 옮김. SettingsStore의 Slack 계정 파일·relay 분할은 허브 회원별 파일·HTTP로 대체. Foundation/Darwin 외 유지 의존 없음. |
| `<운영 저장소>/ddots/Sources/SlackSettingsSync.swift` | 173 | 최초 계정별 이전·시각 1·오프라인 변경·명시적 배치 덮어쓰기 흐름 유지. SlackController/SlackModel은 ConversationModel·MemberState로, UserDefaults는 LocalStore의 원자적 저장으로, relay는 HubClient로 대체. 개인 보관·Slack 삭제·inline 사진 바이트 동기화는 제외. 사진 주소·향후 구획 상태는 승인된 회원 상태 키에 둠. |
| `<운영 저장소>/ddots/Sources/App.swift` | 2575 | makeSyncStandard 확인 창 구조·설정 연결을 PetSettingsWindow/AppDelegate로 옮김. 창 열기·활성화 갱신은 새 MemberState 동기화로 연결. 그 밖의 Slack/iMessage·relay·개인 업무·웹·클립보드·SwiftUI 화면·운영 연결·비밀 접근은 이식하지 않음. |
| `<운영 저장소>/ddots/Sources/SettingsPages.swift` | 229 | AppKit 탭/설정 페이지 배치와 동작 연결만 참고. 기존 hejo AppKit 탭에 연결과 동기화를 추가. NSHostingView·SwiftUI 미리보기 및 테마 편집 의존은 제외. |

보완 18로 D24-01 문구와 D24-02 이전 조건이 해소됐다. 서비스 용어만 hejo로 바꾸고, 이 Mac의 회원별 이전 표시·대기열·readSeq 삭제를 같은 파일 원자적 저장으로 묶는다. 원본 이름·계정·고정 경로·토큰은 가져오지 않는다. 원본의 caps·전송 주기를 그대로 복사하지 않고 REQ-HF-26의 hejo용 한도·30초 계약을 적용한다. 다른 앱 파일을 수정하거나 import하지 않는다.

## TASK-20 착수 전 대조 — D20-01 보류(2026-11-16)

기준 계획 `40c137f4b3c67384972bda64829eec950f28d10b`, ddots 원본 `208f6e6322f593729c9ef6ac16ac903be4c3692b`. 아래 두 원본 파일의 HEAD 대비 변경은 없다. 실제 경로는 AGENTS.local.md만 사용한다. **이 절은 TASK-20 전체 독해 완료나 복사 완료 기록이 아니다.**

| 원본 | 이번에 확인한 범위 | 판정·남은 독해 |
|---|---|---|
| `<운영 저장소>/ddots/Sources/ProfileAvatar.swift` | 115줄 전체 | 사진 썸네일·가운데 자르기·첫 글자/대비색·중첩 색 키·hex/hsl 파싱을 확인. 원본 49행은 slack-avatar.png 우선이지만 hejo는 사장 선택 Q1과 REQ-HF-23.AC-01에 따라 avatar.png 우선으로 바꾸는 승인된 차이다. ImageIO/AppKit 의존을 포함한 hejo 이식은 아직 하지 않았다. |
| `<운영 저장소>/ddots/Sources/SlackController.swift` | 앞부분과 구획 삭제 callback, 특히 324~333행 | 삭제 문구가 spec·AT의 원문 일치 조건과 달라 보완 17에 따라 멈춤. 파일 전체·나머지 의존 독해는 미완료이며 이 부분 대조를 전체 독해로 재사용하면 안 된다. |

구체적인 원문·명세 차이와 계획 담당 결정 요청은 impl-report.md의 **TASK-20 D20-01**에 기록했다. SlackPanel·SlackThreads의 관련 부분도 살폈으나 전체 파일과 유지 의존의 독해는 아직 끝나지 않았다. 문구 기준을 확정해 재인계하면 지정된 전체 원본·의존의 남은 독해와 파일별 유지/대체/제외 기록부터 이어간다. 제품 코드·시험·앱 화면은 변경하지 않았다.

### TASK-20 재개 — 보완 21, 22판 대조 완료

원본 커밋은 위와 같고 아래 파일의 원본 작업 트리 변경은 없다. 앞의 보류 기록은 당시 상태로 보존한다. D20-01은 계획 커밋 `817a8e743ccd08f91558f667c22ac7b5f59a3e2a`의 삭제 본문과 문구 변환 규칙으로 해소됐다. 이번에는 아래 파일을 끝까지 읽은 뒤 구현에 착수한다.

| 원본 (`<운영 저장소>/ddots/Sources/`) | 전체 줄 | 유지·대체·제외 및 의존 |
|---|---:|---|
| ProfileAvatar.swift | 115 | 앞 절의 전체 독해 재사용. 중앙 자르기·ImageIO·첫 글자·중첩 색 파싱 유지. 사진 순서는 Q1 승인대로 avatar.png 우선. AppKit 사진 캐시는 인증된 주소별 메모리 복제로 대체. |
| SlackController.swift | 1622 | 방 목록 조립·구획 callback·사진 선택·삭제 확인 흐름 유지. SlackRoomOrder/Ddots/SlackModel을 SidebarLayout·ConversationModel로, 기존 설정 쓰기를 MemberState로 대체. Slack 전송·토큰·개인 기록·검색·정리 작업 제외. 삭제 문구는 변환 규칙 1번, Slack 전용 설명은 2번 적용. |
| SlackThreads.swift | 1471 | SlackRoomOrder.sorted의 5자리·빈 자리 메움·누락 방 보존, Ddots.stacked의 고정 제외·명부 순서 유지. Slack 상태·전송·휴리스틱 대신 문 명부와 기록 메타 사용. 저장소/계정/개인 예시는 제외. |
| SlackPanel.swift | 3574 | sections/addSection/removeSection/move/groupName, 머리·신호 점·레일·끌기·고정·＋ 메뉴 순서와 수치 유지. SwiftUI는 AppKit으로 옮기고 관찰 모델은 MemberState로 대체. 용어는 변환 규칙 1번. Slack 전용 설명은 2번으로 제외. 로컬 배치 저장은 Q2 승인에 따라 회원 상태로 대체. 새 방/보관 등 TASK-21 기능은 이번 범위에서 제외. |
| SlackRoomDialogs.swift | 282 | SlackRoomPictures의 중앙 정사각 자르기·256 PNG, 이름 30자·빈 이름 기본값 유지. 로컬 사진 저장은 명시된 인증 API와 공용 창고로 대체. 로컬에만 저장한다는 설명은 Q2의 회원 상태 동기화로 대체되는 원본 동작에 속한다. Slack API·방 생성 호출 제외. |
| ChatPresentation.swift | 468 | 직원 색과 얼굴을 화면에 전달하는 의존 확인. 색 원본은 프로필 읽기, 없으면 이름 기반 고정 해시로 대체. Slack/iMessage·검색·달력 상태 제외. |
| ChatStyle.swift | 293 | 얼굴 크기·모서리·HSL·팔레트·이름 순서 의존 확인. 개인 설정과 Slack 호출 제외. 색 값 없는 직원의 이름 해시는 모든 Mac에서 같은 계산 사용. |
| SlackLayout.swift | 346 | SlackZones와 SlackSectionLayout의 구획 간격·레일 배치 유지. TextKit 의존은 기존 hejo TextLayout을 사용하고 Slack 모델·SwiftUI 연결 제외. |

Foundation·AppKit·ImageIO 외 유지하는 제품 의존은 기존 hejo MemberState·GateHTTP·ProfileAvatar·NativeThreadCard·IslandView이다. 구획 머리 얼굴·구획 사진 메뉴와 직원 사진 서버 쓰기는 원본의 얼굴/사진 도우미에 명세의 명시적 기능을 결합한다. 원본의 Slack 연결·로컬 전용 사진/설정 원본은 복사하지 않는다. 문구의 나머지 구조·수치·버튼·문장부호는 변환 규칙 3번으로 유지한다. ddots 실행·파일 변경·앱 간 동기화는 하지 않는다.

독해 후 사진 API 초안을 작성하다 D20-02(사진 지우기 표시 조건의 전달 계약 누락)를 확인했다. 초안은 미추적 빌드 폴더에 보관하고 제품 파일은 이번 작업 시작의 HEAD로 되돌렸다. 전체 독해 완료와 구현 완료는 구분한다. 구현·통합 시험 완료 기록이 아니며 D20-02 근거·재개 조건은 impl-report에 있다.

### TASK-20 보완 22 — D20-02 해소와 실제 이식

23판 `b79727a`·`8703b88`의 avatar_custom 선택 필드와 옛 문 메뉴 숨김 계약을 적용했다. 위 전체 독해 기록은 재사용하며 앞선 두 보류 절은 당시 상태로 남긴다. 초안의 상대 import를 기존 시험의 `gate.tests.support` 방식으로 고쳐 같은 pytest 경로에서 수집한다.

실제 앱 이식은 AppKit이다. ProfileAvatar는 인증 캐시에서 받은 이미지를 그린다. SlackRoomPictures의 중앙 자르기·256 PNG는 ImageIO로, 순서·구획 계산은 SidebarLayout으로, 편집은 ConversationModel과 MemberState로 옮겼다. 사진 서버 쓰기는 gate/pictures.py 하나가 맡으며 프로필 색은 design대로 ruamel로 읽는다. 고정 슬롯·기본 세 구획·명부 순서·마지막 1:1 묶음·신호 점의 2pt/2pt 간격·29/36 머리 높이·58/72 행 높이·16/13 굵은 머리 글씨·들여쓰기를 유지한다. 문구 변환 규칙 1번으로 방·직원 용어를 적용하고, Slack 전용 설명은 2번으로 제외했다. Q1의 사진 우선순위와 Q2의 회원별 배치 동기화는 명시적 승인 차이다. 홈의 실제 대화 조립과 단체방 생성·보관은 후속 TASK 경계를 유지한다.

화면 대조용 ddots 시험 창은 SlackPanel의 slackRow·slackFolded·신호 점·카운터·slackFaces 함수 원문을 추출해 가짜 모델로 실행한다. 사진·명부·계정 서비스는 대역이다. 원본 앱을 실행하거나 원본 설정을 읽지 않는다. 원본의 이름·계정·경로·개인 자료는 이식하지 않았다. 캡처 한계와 결과는 evidence의 TASK-20 문서에 기록한다.

## TASK-25 착수 전 대조 — D25-01 보류

기준 계획은 `4c875301429dfdbe7d519de57c2eb4f074b19316`의 보완 23이다. 원본 저장소 HEAD는 `6ad0650b35ba4b7367050f9af80f0ef15ad4d5c1`이며 아래 다섯 파일은 기존 전체 독해 기준 `208f6e6322f593729c9ef6ac16ac903be4c3692b`와 파일 diff가 없다. 원본은 읽기만 했다. 실제 경로는 AGENTS.local.md에만 둔다.

| 원본 (`<운영 저장소>/ddots/Sources/`) | 독해·이번 대조 | 유지·대체·제외 및 남은 범위 |
|---|---|---|
| SlackPanel.swift | TASK-20의 3574줄 전체 독해 재사용. 이번에는 삭제·분기·의견·체크리스트 callback, 카드 아래 버튼, 중지·되돌리기 줄을 다시 읽음 | AppKit 카드 조립·기존 send·MemberState로 연결할 대상. 삭제 4초·분기 6초는 명세와 일치. Slack 삭제 진행 건수·개인 업무 버튼·SwiftUI 호스트는 이식 대상 아님. 종·날짜·접힌 답 표시와 나머지 유지 의존의 TASK-25 상세 대조는 아직 미완료. |
| SlackThreads.swift | TASK-20의 1471줄 전체 독해 재사용. 이번에는 SlackCopy 전체·SlackStack·상태 색·체크리스트 계산을 다시 읽음 | Slack 주소는 명시된 hejo 주소 체계로 대체. 네 가지 색 hex와 분기 50 기준을 확인. SlackCopy.text의 첨부 공백이 명세와 다름(D25-01). 유지할 표·상태·체크리스트 의존의 최종 이식 대조는 아직 미완료. |
| AgentStop.swift | 21줄 전체를 새로 읽음 | 원본 !stop → /stop은 REQ-HF-27.AC-04가 명시한 전송 경로 변경. working/control 계산은 기존 작성 중 상태에 연결할 대상. undoRequest 문구 차이는 22판 변환 규칙으로 설명되지 않음(D25-01). |
| BubbleReply.swift | 130줄 전체를 새로 읽음 | BubbleReplyInterruption의 mark/settle/clear와 캡션을 카드에 옮길 대상. 말풍선 입력·hover·초안 전체 이식은 후속 TASK-30 범위이며 지금은 가져오지 않음. Foundation 외 유지 의존 없음. |
| DdotsConfig.swift | 231줄 전체를 새로 읽음 | branchText=/branch, longThread=50과 체크리스트 기본 문구 확인. 로컬 설정 파일·HermesLocator·개인 경로·계정·운영 설정 읽기는 복사하거나 실행하지 않음. hejo에서는 명세 상수·기존 회원 상태가 책임을 가짐. |

변환 규칙 1번의 서비스 용어 치환과 2번의 Slack 전용 설명 제거는 진행 가능한 차이다. 그러나 첨부 줄의 `📎` 뒤 공백 삭제와 undoRequest의 `Notion·NAS·` 삭제는 그 규칙에 속하지 않는다. 명세 22판은 규칙 밖 차이를 보고하도록 하므로 제품 복사·구현 전에 멈췄다. 원문 formatter를 가짜 자료로 분리 실행한 근거와 선택지는 impl-report의 D25-01에 있다. 이 절은 TASK-25 전체 의존 대조·구현·수락 시험 완료 기록이 아니다.

### TASK-25 보완 24 재개 — D25-01 해소·남은 의존 대조

기준 `cf0a23cd0778a57b5cc69b3933e5380099b2075d`에서 첨부 공백과 되돌리기 글은 원문과 일치한다. 앞의 보류 기록은 당시 상태로 보존한다. 24판에 따라 명백한 옮김 누락·공백·부호는 원문 우선으로 기록 후 진행한다. 아래 파일은 기존 원본 기준과 diff가 없음을 확인했다.

| 원본 (`<운영 저장소>/ddots/Sources/`) | 독해·의존 처리 | 확인한 이식 경계 |
|---|---|---|
| SlackPanel.swift | 앞 절 전체 독해 재사용, nativeConversation·slackThread·slackStack·stopControl·slackApproval·HermesReplyChecklist를 다시 대조 | 날짜가 달라지는 첫 카드 앞 날짜 줄·뒤 18pt 간격, 중복 제외 얼굴 3, 종 true/false 그림·색, 버튼 순서·체크리스트 토글. SwiftUI 호스트는 AppKit으로 대체하고 개인 업무·Slack 삭제 진행률은 제외. |
| SlackThreads.swift | 전체 독해 재사용, SlackCopy·SlackStack·SlackNotice 상태/체크리스트·statusColors 대조 | 네 상태 색 hex와 표의 Slack 블록→Markdown 입력 경계 확인. 명시 메타 없는 hejo 글에 Slack 승인 휴리스틱을 새로 넣지 않음. 질문 rail의 원문/명세 색 차이는 D25-05로 보고. |
| NativeThreadContent.swift | TASK-06의 311줄 전체 독해 재사용, 이번에 카드 조립·nativePost·nativeBody와 체크 토글 의존 대조 | 기존 NativeThreadCard의 bell/actions/stack/post/mark 구조 유지. NSHosting·개인 보관함·캘린더·드라이브 호출 제외. 체크박스 원문은 고치지 않고 hejo MemberState의 check:로 대체할 대상. |
| ChecklistText.swift | 65줄 전체를 새로 읽음 | SHA256(identity+본문)과 표시 위치로 확인 상태를 구별하는 원리 확인. UserDefaults·SwiftUI·ddots-check 주소는 가져오지 않고 승인된 check: 키와 AppKit 링크 처리에 연결할 대상. Foundation/CryptoKit 외 새 유지 의존 없음. |
| MessageFormat.swift | 219줄 전체를 읽음 | 체크 줄 변환·Markdown/서식 파싱→기존 hejo MessageFormat. SwiftUI Font/Color 변환은 제외. AppKit/Foundation·기존 ChatMetrics만 유지할 대상. |
| SlackLayout.swift | TASK-20의 346줄 전체 독해 재사용, strip/apply/tableRow의 표 전체 경로 재대조 | 머리줄·정렬줄 숨김·NSTextTable/Block·셀별 정렬·테두리·패딩→기존 hejo TextLayout. 방 구획 계산은 TASK-20 기존 구현을 유지. |
| SettingsSync.swift / SlackSettingsSync.swift | TASK-24의 145/173줄 전체 독해 재사용, 이번에 다시 전체 읽음 | 원본 종은 dismissed: LWW이며 syncUndismiss가 null을 명시 전송함. read 계열과 종을 구분하는 계약이 hejo의 bell: 큰 seq 우선과 다름(D25-03). relay·로컬 계정 저장은 복사하지 않음. |
| SlackController.swift | TASK-20의 1622줄 전체 독해 재사용, onBell·publish 종 계산 대조 | 종을 다시 누르면 dismissed를 제거하고 null 동기화. 새로운 일이 오면 최신 위치와 비교해 다시 울림. markRead와 종 해제는 별도 의미임을 확인. Slack 전송/개인 설정 접근은 제외. |

유지 의존은 기존 hejo NativeThreadCard·TextLayout·MessageFormat·TypingRow·ProfileAvatar와 MemberState·GateClient·LocalStore다. 유지할 UI 원본 대조와 별도로 통신/병합/공식 분기 확장점에서 D25-02~04를 재현했다. 새 저장 형식이나 Hermes 내부 우회 경로는 만들지 않았다. 보고·재개 조건은 impl-report 다음 절에 있다.

### TASK-25 보완 25 — 실제 구현 전 해소

`eac02ca5b6a0eee05af3e02971ab394959a7b717`에서 D25-02~05의 계약이 확정됐다. 기존 보류 기록을 보존하고 기존 delete 종류·같은 seq 치환, bell LWW, 문이 만드는 분기와 한 번의 문맥 전달, 질문 대기 빨강을 적용한다. 분기는 Hermes 세션 복제가 아니라는 차이도 승인된 계획에 따라 기록한다. 되돌리기 글과 첨부 공백은 24판 원문 그대로다.

추가 유지 의존 `<운영 저장소>/ddots/Sources/WritingShimmer.swift` 67줄 전체를 읽었다. WritingSpinner의 2×3 시계 방향 위치·0.16초·네 단계 꼬리를 AppKit 작업 중 줄에 옮긴다. SwiftUI modifier/GeometryReader/마스크 호스트는 복사하지 않고 기존 hejo ShimmerLayer를 유지한다. Foundation/AppKit 외 새 런타임 의존은 없다. 원본 파일은 읽기만 했다. 중지 경계는 Hermes gateway/run_busy.py의 stop 명령 매핑·thread slot 필터를 읽기 전용으로 확인했다. 본체·세션 저장소를 고치거나 우회하지 않는다.


### TASK-25 구현 뒤 같은 상태 대조

원본 NativeThreadCard·SlackLayout과 기존 hejo 카드 렌더러에 동일한 가짜 상태를 넣어 실행했다. 유지 의존 MessageFormat/ChatStyle과 가짜 사진 공급자는 공통이며 원본 앱 전체 실행은 아니다. 질문 빨강·종·얼굴 3개·접힌 답·표·아래 버튼 5개의 배치 영역이 같고 캡처 181,272픽셀 중 차이는 186픽셀이다. 상세와 실제 ConversationView 날짜·표·제어 캡처는 evidence/HEJO-FOUNDATION/TASK-25.md에 기록했다. Slack 주소→hejo 주소는 변환 규칙 1번과 승인된 주소 계약, Slack 전용 구절 제외는 규칙 2번, 첨부 공백·Notion·NAS는 24판 원문 복구다. 새 문구 계약 충돌은 남지 않았다. 원본·유지 의존 파일을 수정하지 않았다.


## TASK-26 착수 대조 — D26-01 검색 상한·선택 순서

기준 `880b1aedd5258c0472f23f6eb379e58390734c08`의 보완 26에 따라 시작했다. N25-01은 앞선 시험 전용 커밋으로 분리했다. 실제 원본 경로는 AGENTS.local.md를 따르며 원본 파일은 읽기만 했다.

| 원본 (`<운영 저장소>/ddots/Sources/`) | 이번 독해 | 확인한 경계 |
|---|---|---|
| SlackFind.swift | 225줄 전체 | 0.25초 입력 대기·세대 무효화·검색 중 키·선택/이동·1.6초 반짝. 월 기록 읽기·원격 Slack 검색은 설계가 명시적으로 제외한다. hejo 캐시 검색 작업자와 AppKit 입력 처리는 아직 구현하지 않았다. |
| SlackSearch.swift | 121줄 전체 | 정규화·단어/구절·겹친 하이라이트 병합·메타 미리보기·groups. 원격 API·기록장 변환은 제외 대상이다. 72~82줄의 최신 글 상한→묶음→구절 우선 정렬이 REQ-HF-28.AC-02와 다르다(D26-01). |
| SlackFindView.swift | 107줄 전체 | 검색 결과의 방/날짜/첫 글·일치 3개·+N·선택 강조·노랑/검정 하이라이트. SwiftUI 호스트는 AppKit 대체 대상이다. 상태 문구 변환은 SlackNotice.displayStatus 의존이며 최종 유지 의존 대조는 미완료다. |
| SlackDrafts.swift | 92줄 전체 | 자리별 글/첨부/고른 얼굴, 메모리 수명, 실패 원래 자리 복구·중복 첨부 제거·10개 제한·실패 후 자동 전송 없음. DdotsFaceLight의 라우팅 의존은 후속 홈 방 범위와 구별해야 하며 아직 이식하지 않았다. |
| ChatWorkspace.swift | 56줄 전체 | 머리줄 메뉴 순서·검색 입력창 확인. 서비스 이름은 변환 규칙 1번, SwiftUI는 AppKit 대체 대상이다. |
| SlackPanel.swift | 이전 전체 독해 기록은 보존. 이번에는 1200~1515줄의 머리줄/초안/실패/자동 답글 대상을 다시 대조 | 나머지 알림 막대·작성기 얼굴·실패 목록 화면과 유지 의존의 TASK-26 대조는 아직 미완료다. SlackThreads·SlackController의 TASK-26 대상 재대조도 남는다. |

**D26-01.** 명세는 '구절이 일치하는 것을 먼저, 그다음 최신 순으로 최대 200묶음'이라고 하지만 원본 groups는 먼저 최신 일치 **글** 200개만 남기고 그 안에서 묶음과 구절 우선 순서를 만든다. 원본의 해당 함수와 불활성 자료형만 분리 컴파일해 두 입력을 재현했다. (1) 한 스레드의 일치 글 500개 → 묶음 1개·일치 글 200개. (2) 새 단어 분산 일치 200개와 오래된 정확 구절 일치 1개 → 오래된 정확 일치가 제외된다. 문구 치환·공백 복구와 달리 검색에 포함되는 글과 +N건이 달라지므로 구현자가 상한 단위·선택 순서를 정하지 않는다. 근거·선택지는 impl-report에 기록했다. 제품 복사 전 대조 중이며 전체 의존 독해 완료 기록이 아니다.


### TASK-26 보완 27 재개 — D26-01 해소와 유지 의존

기준 `7e71fc501b937287b341d306ae33a0fc626923ab`의 26판으로 D26-01이 해소됐다. 앞 기록은 당시 상태로 보존한다. 최신 일치 글 200개를 먼저 고른 뒤 묶고 구절 일치 묶음·최신 순으로 그린다. ddots 동작은 26판 규칙에 따라 코드 우선이다.

SlackPanel(3574)·SlackThreads(1471)·SlackController(1622)·DraftEditor(231)·DraftFormat(128)은 기존 전체 독해 기준 `208f6e63`과 파일 차이 없음을 확인하고 전체 독해 기록을 재사용했다. 이번에는 SlackThreads의 SlackNotice items/item/grouped와 SlackMention 전체, SlackPanel의 notices/bells/jump/go·머리줄/초안/실패 복구·자동 답글·mentionFaces·slackFailures·slackNoticeBar, SlackController의 머리줄 편집 callback을 끝까지 재대조했다. 질문·알림은 기존 hejo asked/confirmed/bell·기록장 투영을 사용하고 Slack의 본문 승인 휴리스틱·사용자 DM·기타 상태 추측은 가져오지 않는다. 단체방 멤버 명부는 TASK-21 전까지 기존 Room.members 소비 경계다.

추가 SlackRoomDialogs.swift는 전체를 읽었다. editHeader의 AppKit 제목/설명/세 버튼만 유지하며 Slack 방 생성·초대·사진 파일 저장은 제외한다. Foundation/AppKit·UniformTypeIdentifiers는 기존 의존이다. SlackFind(225)·SlackSearch(121)·SlackFindView(107)·SlackDrafts(92)·ChatWorkspace(56)의 앞선 전체 독해를 재사용한다. 메시지·서식·표·그림은 기존 hejo NativeThreadCard/MessageFormat/TextLayout/ProfileAvatar/ComposerFaces에 연결한다. 새 런타임 의존은 없다.

문구는 변환 규칙 1번(Slack/ddots→hejo, 채널→방, 에이전트→직원)·2번(Slack만의 사실 제거)을 따른다. 머리줄 원문의 ‘이 Mac’ 한정은 사장 선택 Q2(모든 Mac 맞춤)가 대신하며 title: 회원 상태를 사용한다. 검색 월 읽기·원격 Slack API는 설계가 제외했으므로 복사하지 않는다. 영구 원본을 추가하지 않는다.


### TASK-26 원문 실행 비교와 최종 구현 차이

알림 막대 원문 함수는 질문 2·알림 3, SlackFindView와 SlackSearch의 미리보기/하이라이트 원문은 needle·plain body·needle.txt 한 글 상태로 별도 실행했다. 원본 계정/콜백/라우팅은 불활성 대역이며 원본 앱 전체 실행이 아니다. 같은 상태의 실제 AppKit 화면과 나란히 비교하고 evidence/HEJO-FOUNDATION/TASK-26.md에 남겼다. 원문의 알림 버튼은 ‘모두 읽음’이며 n건은 도움말에 있다. 메뉴의 ‘방 목록 보이기 / 숨기기’·‘전체 검색 (⌘F)’ 띄어쓰기도 그대로 유지했다(24판 원문 우선). 알림 #36C5F0·질문 #ECB22E, 결과 안쪽 여백·선택 테두리·날짜 오른쪽 정렬·첫 글 14pt·파일 하이라이트를 적용했다. 원본의 스레드 첫 글 날짜 순, 확인/완료 뒤 알림 제외, 스레드 방문 때 일반 알림 종 읽음도 같은 계산에 반영했다. hejo의 기록된 스트리밍 글은 아직 보내지 않은 pending 글과 다르므로 검색 대상에 남긴다. 월 기록·Slack API·개인 업무 기능을 가져오지 않았으며 hejo 고유 계약이나 사장 선택을 바꾸지 않았다.


## TASK-29 착수 대조(보완 28)

기준 005d3c1. App.swift(2575)·PetView.swift(1664)·Conversation.swift(448)·BubbleReply.swift(130)는 기존 전체 독해 기준 208f6e63과 파일 차이 0을 확인했다. App/PetView의 기존 전체 독해 기록을 재사용하고 updatePet·perform·nudgeMessages·saveReminders, BubbleTextView·updateBubbleShown·updatePetBadge·layoutThoughtDots·reply playback 호출을 다시 끝까지 대조했다. Conversation.swift 전체를 다시 읽어 PetAction·NudgeEngine·UnreadReplies·ChatReplyActivity의 의존까지 확인했고 BubbleReply 전체와 BubbleReveal 전체를 읽었다. SlackPanel의 기존 전체 독해를 재사용해 computePetApproval의 confirmed·settled 경계와 질문 대상 선택을 대조했다.

| 원본 파일 | 유지·교체·제외 |
| --- | --- |
| `<운영 저장소>/ddots/Sources/App.swift` | 승인 > 실패/대기 > 작성 중 > 새 답 순서를 BubbleReveal로 옮김. Slack/iMessage·캘린더·연결 제안·파일 놓기·작업 모니터는 제외. 웹 링크는 승인된 브라우저 열기, 스레드는 hejo ConversationKey. |
| `<운영 저장소>/ddots/Sources/Conversation.swift` | 새 답 12초·나중에 1800초·읽음/대화 열림 취소·9+·버튼 순서 유지. 날짜 원본은 journal timestamp, 최초 replay는 기준으로만 삼음. 본문은 기존 투영을 조회하고 예약은 메시지 id/시각만 저장. |
| `<운영 저장소>/ddots/Sources/PetView.swift` | AppKit 텍스트·상태 점(0.8초 opacity)·배지·생각 점 7/11/16·답 뛰기 유지. 기존 hejo 배치·atlas·ShimmerLayer·PetChatPlayback 재사용. SlackModel·SwiftUI·클립보드/파일 호스트 제외. |
| `<운영 저장소>/ddots/Sources/BubbleReveal.swift` | 3초 일반 알림은 REQ-HF-30의 12초 새 답으로 대체. hover/항상 보이기 설정은 유지. |
| `<운영 저장소>/ddots/Sources/BubbleReply.swift` | 대상·끼어들기 유지 의존만 확인, 입력은 TASK-30에 남김. |
| `<운영 저장소>/ddots/Sources/SlackPanel.swift` | 승인 질문의 confirmed/settled 제외 개념을 기존 hejo notices로 연결. Slack 승인 휴리스틱/프로젝트는 제외. |

26판 동작 원문 우선: PetView.layoutThoughtDots는 말풍선이 보이고 간격이 26pt 이상일 때 점을 그린다. 숨겨진 말풍선 때 점을 그린다는 명세 문장 대신 이 원본 동작을 유지한다. 배지는 숨긴 동안만 머리 옆에 보이며 말풍선 안에는 수가 남는다. 문구 변환 규칙 1번은 ddots→hejo/펫 이름·에이전트→직원, 2번으로 Slack/iMessage/캘린더 사실만 제외한다. 원본의 ‘새 메시지’·‘다시 알림’·‘답변을 생각하고 있어요’와 버튼 순서를 유지한다. 서버 통신·허브·기록장 계약과 사장 선택 변경은 없다.

유지 의존 추가 대조: PetAnimation.swift(167)·WritingShimmer.swift(67) 전체를 읽었다. jump 0.84초 한 번·작업/승인 우선순위는 기존 PetChatPlayback으로 연결한다. ProfileAvatar(115)·PetLayout(404)의 앞선 전체 독해를 재사용하며 actionRects·bubbleSize와 배지/점 배치를 대조했다. ChatStyle.swift는 ChatMetrics(이름 14pt·보조 11pt·얼굴 20px·간격 8)와 나머지 테마/팔레트/ThreadAppearance 의존을 끝까지 읽었다. SwiftUI modifier 자체는 제외하고 기존 AppKit ShimmerLayer를 사용한다.


## TASK-30 착수 대조(보완 29)

기준 6b1e27b3fb7143ffa1c09a74af21c9220706b154. BubbleReply.swift(130) 전체를 다시 읽었고 BubbleReplyCard.swift(103)·BubbleReplyIntegration.swift(34)·BubbleReplySmoke.swift(116) 전체를 읽었다. PetView(1664)·SlackController(1622)·DraftEditor(231)의 기존 전체 독해 기록은 208f6e63과 파일 차이 0을 확인해 재사용하고, 입력 hover/키 창/Esc/배치·workingTarget/replyTarget/sendReply/비동기 실패 callback을 다시 끝까지 대조했다.

| 원본 파일 | 이식·유지 의존과 제외 |
| --- | --- |
| `<운영 저장소>/ddots/Sources/BubbleReply.swift` | 0.3초/0.6초·3줄 표시·안내 3종·조건·Esc·접기 예약을 AppKit BubbleReply로 이식. 중단 상태는 TASK-25의 ConversationController.interruptions를 재사용. |
| `<운영 저장소>/ddots/Sources/BubbleReplyCard.swift` | ObservableObject/SwiftUI 대신 기본 NSView·기존 DraftScrollView/DraftTextView. 텍스트·포커스 유지, 실패 이유·복원, 28px 보내기 버튼, 입력 padding 12/7·바깥 10/7을 유지. |
| `<운영 저장소>/ddots/Sources/BubbleReplyIntegration.swift` | 같은 send 경로·비동기 거절 복원을 기존 pending client_msg_id 상관관계에 연결. Slack callback·별도 전송 경로는 제외. |
| `<운영 저장소>/ddots/Sources/PetView.swift` | hover·키 입력 클릭 시에만 key·Esc 입력 먼저·아래쪽 입력 배치를 PetView/PetPanel에 연결. NSHosting/클립보드·파일 놓기 제외. |
| `<운영 저장소>/ddots/Sources/SlackController.swift` | 작성 중 가운데 사장이 마지막으로 쓴 스레드 선택은 기존 BubbleReveal 키 선택을 유지. queued 읽기·답 보내기·실패/끼어들기를 hejo 명부/기존 제어기로 연결. |
| `<운영 저장소>/ddots/Sources/DraftEditor.swift` | 기존 hejo DraftScrollView를 재사용해 Return/Shift Return·입력 높이 최대 3줄(넘는 글은 스크롤)을 유지. 서식/붙여넣기 파서는 기존 책임을 유지. |
| `<운영 저장소>/ddots/Sources/BubbleReplySmoke.swift` | 실제 포인터·키/실패/hold 시나리오를 가짜 문 수락 시험으로 대응. 운영 Slack·원본 앱 자체는 실행하지 않음. |

문구 변환 1번은 기본 대상 ‘에이전트’→‘직원’, 2번으로 Slack 전용 사실만 제외한다. 원본 초안 retarget는 한 칸을 비우지만 hejo는 REQ-HF-31/AT-82의 스레드별 복원과 기존 ConversationController.drafts를 유지한다. 새 초안 원본을 만들지 않고 동일 스레드 입력을 재사용하며, 말풍선 보내기는 텍스트만 보내고 기존 첨부는 남긴다. 설정은 기존 펫 설정의 허브 원본·로컬 오프라인 사본 경로를 사용한다.

명부 queued는 승인된 design의 읽기 전용 값이다. 기존 employee 스키마가 추가 필드를 막으므로 이 승인된 선택 boolean 필드를 규격·앱 Employee에 함께 반영한다(새 의미 추가 아님). 옛 명부의 필드 없음은 false로 읽고 옛 앱의 Codable은 추가 필드를 무시한다. config.yaml 읽기는 원본 isQueued의 display 블록·queue 판정과 같은 규칙을 쓰며 설정·본체에 쓰지 않는다. hejo 전송·저장·허브 계약이나 사장 선택을 바꾸지 않는다.

최종 원문 비교: BubbleReplyView·NativeDraft 원본 전체를 분리 실행해 같은 평문 상태의 입력 줄을 비교했다. 서식·테마·붙여넣기 변환은 불활성 대역이며 원본 앱 전체가 아니다. AppKit 외곽 capsule의 안쪽 폭·줄바꿈을 맞췄다. IME 조합 중 같은 초안의 재발행은 편집기를 덮어쓰지 않고, 대상 변경·보낸 글 비우기는 undo 범위를 함께 비운다. 원본의 3줄은 표시 높이 한도이며 네 번째 줄을 버리지 않는 동작을 유지한다(26판); 화면 자료는 evidence/HEJO-FOUNDATION/TASK-30.md다.


## TASK-27 착수 대조(보완 30)

기준 cfe7e920e44891b40f6062b9a64431dadfa0fe59. SlackPanel(3574)·SlackThreads(1471)·SlackController(1622)·App(2575)·DdotsConfig(231)·DraftEditor(231)는 기존 전체 독해 기준 208f6e63과 diff 0을 확인해 전체 기록을 재사용한다. 이번에는 Ddots 전체(구성·소속·합침·활동 순서·대표 얼굴·홈 고정 채널 경계), SlackPanel의 홈 선택/대상/얼굴/초안/메뉴/알림 합계를 끝까지 다시 대조했다. DdotsRoute(28)와 SlackDrafts(92) 전체도 읽었다.

| 원본 파일 | 유지 의존·교체·제외 |
| --- | --- |
| `<운영 저장소>/ddots/Sources/SlackThreads.swift` | Ddots.members/rooms/merged/byActivity·SlackMention 전체를 확인. 홈은 실제 방이 아닌 보기이며 최근 활동을 아래에 둠. Slack user id·원격 이력·공용 채널은 제외하고 hejo 기록장 투영·직원 명부를 사용. |
| `<운영 저장소>/ddots/Sources/SlackPanel.swift` | 홈 postProfile/recipient/aim·ddotsFaces·draftPlace/moveDraft·unreadTotal·홈 우클릭을 재대조. 얼굴 다시 누르기 해제, 빈 새 글은 얼굴을 밝히지 않음, 명시 선택/답글만 링. AppKit ComposerFaces와 기존 초안·스레드 카드로 옮김. |
| `<운영 저장소>/ddots/Sources/SlackController.swift` | shownRooms/shownThreads·publish의 membership/latest/threads·muted 홈 합집합을 재대조. 원본의 활동 오름차순(최근 스레드가 아래)·기록 창을 유지하며 hejo ThreadWindow·MemberState로 연결. Slack 캐시/월 읽기/개인 수신 제외는 복사하지 않음. |
| `<운영 저장소>/ddots/Sources/SlackDrafts.swift` | 전체 읽음. 기존 hejo ConversationController.drafts·picks·실패 글과 선택 상태를 재사용. DdotsFaceLight 빈 글/수동 선택/답글 밝힘과 링 규칙을 유지. 별도 초안 원본 없음. |
| `<운영 저장소>/ddots/Sources/DdotsRoute.swift` | 전체 읽음. @이름·별칭 경계를 유지하고 hejo 명부에 해석. HermesRouting의 업무별 자동 라우팅·Slack cross_owner·개인 계약은 제외. 받는 직원 한 명·명시 얼굴 우선·두 명/제외 직원 거절은 승인 REQ-HF-29 계약. |
| `<운영 저장소>/ddots/Sources/DdotsConfig.swift` | 기존 전체 독해 재사용. 로컬 recipient/excluded/appearance 원본 대신 승인 Q2에 따른 `layout:home` 허브 회원 상태를 사용. 새 영구 원본 없음. |
| `<운영 저장소>/ddots/Sources/App.swift`·`DraftEditor.swift` | 기존 전체 독해 재사용. 홈 설정의 앱 연결·입력 유지 경계를 대조. 기존 펫 이름/그림과 AppKit 편집기·사진 클라이언트를 사용. |

26판 원문 우선: byActivity는 오름차순으로 최신 활동을 목록 아래에 둔다. hejo도 카드 순서에 이를 유지한다. 문구 변환 1번은 채널→방·에이전트→직원·홈 이름은 펫 이름, 2번은 Slack 전용 사실 제거다. 홈 사진·보일 직원·기본 받을 직원·한 명 제한·`layout:home`은 REQ-HF-29/Q2·Q3 승인 차이다. 고정 채널 메뉴는 명시된 TASK-21 뒤로 남긴다. 사진 바이트는 TASK-20의 room API 안 home- 접두 경로(shared/hejo/pictures)를 재사용한다. 홈의 임시 작성 위치는 기존 메모리 초안 칸이며 기록장에 가상 직원/방을 쓰지 않는다.

추가 유지 의존: ChatPanel.swift(591)의 앞선 전체 독해를 208f6e63과 diff 0으로 재사용하고 face/avatarBadge를 다시 읽었다. 24px 얼굴·3/1pt 패딩·2pt 간격·30px 부드러운 사각 링을 ComposerFaces 홈 모드에 반영한다. 원본과 같은 가짜 직원 3명·@직원 B 상태를 원본 ddotsFaces/그리기와 비교한다. 선택 버튼 콜백·개인 아바타 로드는 대역이며 원본 앱 전체 실행이 아니다. 홈 표시명이 즉시 바뀌도록 기존 펫 이름 적용 뒤 보기도 갱신한다. 기존 화면의 서버 연결 문구 두 곳도 사용자 용어 규칙에 맞췄다.

화면 대조 완료: 같은 가짜 이름·색·@직원 B/얼굴 선택 상태에서 원본 ddotsFaces와 실제 ComposerFaces의 24px 얼굴·밝기·30px 링·간격을 비교했다. 원본 byActivity도 분리 실행했다. 원본 앱 전체·운영 앱 전체 실행은 아니며 evidence/HEJO-FOUNDATION/TASK-27.md에 한계를 함께 남겼다. 사진 삭제 실패는 기존 주소를 유지하고, 이미 고른 직원이 홈에서 빠졌을 때에는 다른 직원으로 조용히 바꾸지 않고 같은 제외 안내로 거절한다.

빈 Return은 작성 위치·명시 얼굴을 바꾸지 않고, 연속 새 글은 원본 newPost/draftPlace처럼 화면의 새 글/답글 의도를 기존 제어기에 전달해 새 UUID와 원래 답글을 구별한다. 이 의도는 UI 메모리 상태이며 새 저장소·통신 필드가 아니다.

## TASK-21 착수: 단체방(보완 31, 27판)

기준 `df7709dc4543f0ba6492a5f2fd53aa527c42f38f`. TASK-27 검토 통과와 깨끗한 작업 트리를 확인했다. 앞선 전체 독해 파일은 원본 기준 `208f6e63`과 diff 0을 확인해 재사용했다.

| 원본 파일 | 전체 독해·유지 의존 | 이식·제외 |
| --- | --- | --- |
| SlackRoomDialogs.swift (282줄) | TASK-20·26 전체 독해 재사용, create/Picks/invite/rename/confirm/editHeader/pictures 전체 재대조 | 320px·22px 체크 행·220px 스크롤·8px 간격·참여 중 흐림·초대 버튼을 AppKit으로 유지. 사장 선택대로 직원만, 2명 이상·대표 추가. 공개/비공개와 Slack API는 서비스 전용이므로 제외(변환 규칙 2번). |
| SlackController.swift (1622줄) | TASK-20·27 전체 독해 재사용, callback 및 create/invite/archive/unarchive/rename/deleteRoom/사진 흐름 재대조 | 방 변경 요청은 기록장 한 줄과 방송으로 대체. 보관·해제 선택 흐름 유지. Slack에서 여는 삭제는 hejo 고유 삭제 확정·경고 계약으로 대체. |
| SlackPanel.swift (3574줄) | TASK-20·25·26·27 전체 독해 재사용, 방 메뉴·홈 고정 채널·＋/보관 목록·멘션·작성 위치 재대조 | 메뉴 구조·고정 자리·참여 직원 표시 유지. 용어는 변환 규칙 1번, Slack 전용 구절은 2번. 회원 상태는 승인된 Q2, 단체방 전달은 REQ-HF-24. |
| SlackThreads.swift (1471줄) | TASK-20·25·27 전체 독해 재사용 | 방·직원·스레드의 중립 모델·활동 순서/얼굴은 기존 hejo 투영 확장. Slack 계정·전송은 제외. |
| SlackLayout.swift (346줄), ChatPanel.swift (591줄), DraftEditor.swift (231줄), SlackDrafts.swift (92줄) | 앞선 전체 독해와 원본 diff 0 재사용 | 기존 SidebarLayout·NativeThreadCard·NativeComposer·초안을 재사용. 새 복제본·저장소 없음. |

추적하지 않는 원본 경로는 AGENTS.local.md를 따른다. SlackBridge의 외부 서비스 방 생성·초대·보관 호출과 그 API·토큰 의존은 유지하지 않는다. 그 호출부의 흐름은 읽기만 확인했다. 단체방 영구 원본은 문 Journal, 앱은 조회 캐시, 배치는 MemberState, 사진은 기존 Pictures다. 새 방은 AC-05대로 첫 구획에 둔다. 원본 고정 채널은 선택 채널만 보여주는 동작이며 26판 코드 우선 규칙을 적용한다. 홈의 기본 상태는 기존 1:1 합친 보기로 되돌린다. 삭제는 원본 Slack 제한 대신 명시된 hejo 계약(한 줄 확정·seq 치환·늦은 출력 버림·전용 파일 정리)을 따른다.

### D21-01: 고정 채널에서 홈 수신자와 단체방 호출 규칙 충돌(보류)

원본 SlackPanel.swift:534~538의 hubPost는 고정 채널로 쓸 때 Ddots.post를 쓴다. SlackThreads.swift:768~784의 실제 코드는 이미 명시 호출이 있으면 선택 얼굴 호출을 덧붙이지 않는다(`SlackText.mentions(sent).isEmpty`일 때만 추가). 따라서 A 얼굴+본문 @B의 실제 전송은 B 호출이다. 이는 Q3로 승인된 REQ-HF-29.AC-01(누른 얼굴 우선, 한 명)과 같지 않다. 단순 원문 옮김 실수가 아니라 hejo 전달 계약의 선택 차이라 26판 코드 우선으로 덮지 않았다.

REQ-HF-24.AC-02는 본문 @직원만(없으면 대표)을 부르며, AC-05는 홈 고정 채널 메뉴를 요구한다. 고정 채널 선택 뒤에도 홈의 단일 수신자 규칙을 유지할지, 일반 단체방 작성기로 바꿀지, 합친 보기에만 방을 넣고 쓰기는 1:1로 유지할지가 정해져 있지 않다. 전달 대상 재정의나 선택 필드 추가는 구현자가 채택하지 않는다. 재현·선택지는 impl-report.md TASK-21 D21-01에 있다.

### D21-01 해소·TASK-21 재개(28판, 보완 32)

기준 `0c5a3bd573172c2dfdcdbb196c82c743295163c0`. 앞 보류 기록은 보존한다. 고정 채널 홈 새 글은 본문 호출 우선, 없을 때만 선택 얼굴 호출 앞붙임, 둘 다 없으면 대표, 별명 시작은 이름으로 변환한다. 채널 없을 때만 기존 홈 1:1 규칙이다. 새 규격 필드 없이 승인된 room을 쓴다. 앞선 원본 전체 독해·diff 확인을 재사용한다. 초안의 임의 얼굴 우선 앞붙임은 제거하고 이 결정을 적용한다.

추가 유지 의존 SlackBridge.swift(1652줄)는 이번에 파일 전체를 끝까지 읽었다. 이 중 `channelName`의 앞 # 제거·소문자·빈칸 -·문자/숫자/-/_·80자 규칙만 RoomDialogs.name으로 옮겼다. 나머지 SlackAPI·토큰·요청 제한·회복/캐시·읽음 API·메시지별 삭제·외부 파일 전송·계정/사람 검색 의존은 전부 제외했다. 직원 명부는 기존 Hermes 프로필 API, 방 기록/수신·삭제는 hejo 승인 계약, 사진은 Pictures를 쓴다. 원본 초대 Picks의 22px 행·머리·스크롤·참여 중 흐림·가능한 직원이 없을 때 초대 버튼 비활성화를 유지했다. 명칭은 변환 규칙 1번, Slack 공개/비공개·관리자 제한 안내는 2번으로 제외했다. 기존 AC-03 메뉴 순서를 유지하며 REQ-HF-24의 직원 빼기는 작성기 얼굴의 우클릭에서 요청한다(2명 미만·대표 제거는 비활성). 이는 hejo의 방 관리 연결이며 새 통신 계약이 아니다.


## TASK-32 착수·공식 쓰기 계약 대조(보완 33)

기준 `b19e03720dda05525db92de472fdbf2004c8ac72`. TASK-21 검토 결과와 실제 깨끗한 트리를 확인했다. 이번은 제품 이식 전 책임·보안 계약 대조이며 제품 코드를 옮기지 않았다.

| 원본 | 읽은 범위·유지 의존 | 현재 처분 |
| --- | --- | --- |
| `<운영 저장소>/ddots/Sources/AgentConnections.swift`(369줄) | 전체. 문서·버튼·이유 코드·명령 제한·캐시·시각 처리 | 문이 준 버튼만 표시·stdin 비밀값·작업별 제한을 확인. 다른 Mac 읽기 전용 제한은 승인된 서버 대행으로 교체할 대상이다. 아직 이식하지 않았다. |
| `AgentConnectionActions.swift`(264줄) | 전체. SecretInput·입력/지우기·ConnectionInputField·Guide·AgentConnectionsModel 의존 | 전체 창·모델 의존 독해는 미완료다. 비밀값 안내와 검증 후 저장·되돌림 흐름을 확인했으나 이식하지 않았다. |

읽기 전용 원본 현재 HEAD는 `6ad0650b35ba4b7367050f9af80f0ef15ad4d5c1`이며 위 두 파일은 기존 독해 기준 `208f6e63` 대비 diff 0이다. 나머지 지정 UI·앱 연결·입력·team-kit 유지 의존 전체 독해는 미완료다. 일부 독해를 전체 이식 준비 완료로 세지 않는다.

공식 관리 경로는 Hermes `ebb026eef8e800e1b7471ed147b7287e878f8aa4`의 subcommands/dashboard.py 전체, main.py의 cmd_dashboard/prepare_runtime, web_server.py의 lifespan/start_server·세션 검사, credential_lifecycle.py 전체, config_env.py의 env 저장/삭제·제공자 검증, config.py의 save_env_value/remove_env_value를 대조했다. D1에서 실제 serve를 임시 홈 기본+보조 두 프로필로 기동해 목록 HTTP 200을 받았다. 모든 자식 실행은 감사 훅으로 차단·기록했고 관측된 시도는 Git 버전 조회뿐이며 메시징 게이트웨이 실행 시도는 없었다. 관측은 기동·도구 목록 조회 구간이며 모든 관리 동작의 실물 검증은 아니다. 기존 task31의 추적하지 않는 web 의존성만 탐침 경로로 재사용했고 Hermes venv에 설치하지 않았다.

D32-01: 공식 env 저장은 config.yaml의 같은 이전 값까지 갱신하고, 그 후속 쓰기 실패 뒤 .env 새 값이 남는다. REQ-HF-32.AC-03·04의 단일 키 쓰기/실패 불변과 충돌해 제품 구현을 보류했다. 검증 불가능한 키의 공식 validate가 ok=true/reachable=false인 경계도 확인했다. 이는 ddots 문구·동작 옮김 차이가 아니라 hejo 보안·Hermes 연동 계약이므로 26판 코드 우선으로 덮지 않았다. 상세와 선택지는 impl-report.md TASK-32 절, 재현은 `.build/task32/`다.


### TASK-32 재개·29판 해소와 남은 원본 독해

기준 `4fe20c13bca8a558bf1a0ad1681d8c3d81d0e8d0`. D32-01 기록은 보존하고 design D9로 해소했다. hejo는 공식 PUT/DELETE로만 쓰고 보상 실패를 partial로 드러낸다. D1 실제 serve 기동 근거는 재사용한다.

이번에 전체를 끝까지 읽은 원본: ddots AgentConnectionsView.swift(491), AgentAppConnections.swift(312), ConnectionInputField.swift(39), InstalledApps.swift(152), InstalledAppsView.swift(137). 앞선 AgentConnections.swift(369)·AgentConnectionActions.swift(264) 독해와 합쳐 모델·연결 UI·앱 진행·입력·안내·캐시·시각·아이콘 의존을 확인했다. SwiftUI는 연결 창 예외 범위에서 유지한다. 원본의 다른 Mac 읽기 전용·로컬 HermesLocator/RemoteHermes·로컬 권한 조회·클립보드 감시는 가져오지 않고 기존 문 연결·서버 명령·앱의 화면 기록 제외로 대체할 대상이다. 문구는 변환 규칙 1번(직원·서버), 서비스 전용 제외는 2번이다. 상태에서 버튼을 추론하지 않는 구조·200px 직원 목록·22px 내용 여백·760x500 최소 크기·시각 표시는 유지할 대상이다.

team-kit 경계는 실행 파일 hermes/bin/hermes-connections와 hermes_facility/connections.py(469), connection_secrets.py(270), connection_checks.py(437), connection_guides.py(68), app_connect.py(638), app_registry.py(250), gateway_restart.py(149), mac_permission.py(364)를 전체 독해했다. 이 코드를 hejo에 복사하지 않는다. 문은 고정 허용 명령·스키마·outcome·stdout 한도·stdin 비밀값·작업별 제한의 프로세스 경계만 유지한다. 명령 내부의 app_setup·config_assembly·plugin_store·mac_apps catalog/discovery·서비스별 HTTP·권한 worker는 외부 명령의 구현이며 hejo가 직접 호출하거나 소유하지 않는다. 그 구현을 우회·복제하지 않는다. 따라서 외부 조립/권한 전체 코드를 hejo 유지 의존으로 옮기는 것으로 기록하지 않는다. 프로필·권한 범위·재확인·행동 기록은 hejo 문에서 검사한다.

### TASK-32 실제 옮김 대응

- `AgentConnections.swift` → `app/Sources/ConnectionModels.swift`: 문서·행·상태·이유 문장·시각 계산을 가져왔다. 원본 로컬 CLI 실행기와 디스크 상태 캐시는 제외하고 기존 출입증 문 연결을 쓴다. 원시 오류를 덧붙이는 문장은 D2에 따라 고정 안내로 바꿨다.
- `AgentConnectionsView.swift`·`AgentConnectionActions.swift` → `ConnectionsWindow.swift`: 직원 목록 200px, 내용 여백 22px, 최소 크기 760×500, 상태 알약·서비스 타일·상세·동작 줄·단계 안내를 재사용했다. 기본 창은 860×590이다. 원문 `summary`처럼 0개인 알약은 숨긴다(26판 코드 우선). 재확인은 hejo 고유 LocalAuthentication 계약이며, 취소는 전송 전에 끝난다.
- `ConnectionInputField.swift`는 입력기 힌트·secure/plain 분기를 그대로 가져왔다. 입력 중 부모 창과 시트의 화면 공유를 제외하고, 닫기/성공 때 입력 사전을 지운다. 클립보드 기록 기능 자체는 hejo에 없으므로 원본 클립보드 감시 중지 연결을 추가하지 않았다.
- `AgentAppConnections.swift`·`InstalledApps.swift`·`InstalledAppsView.swift`의 명령이 준 단계·선택지·입력·기본 계정·권한·다시 시작 흐름은 문이 받은 `next`로 그린다. Mac 앱 정보와 동작은 `gate/connection_manager.py`·`connection_runtime.py`의 고정 team-kit 명령 경계에 있다. 다른 Mac의 폴더 선택기를 서버 경로로 오인해 보내지 않는다. 로컬 앱 목록/로컬 권한 전용 쪽지 화면은 가져오지 않고 서버 직원의 연결 목록에 합친다(REQ-HF-32.AC-02).
- team-kit의 `secret set`은 stdin JSON을 그대로 받으며 `--values-stdin` 인수가 없다. 이 인수는 `app connect`에만 붙인다. 원본 parser와 대조하고 실제 가짜 실행 파일 시험으로 고정했다. `reconnect`의 `state`, 다른 동작의 `outcome`을 구분하며, 0이 아닌 종료 코드에 유효한 `outcome`이 있으면 그 결과를 따른다. 다시 시작 명령의 거절도 pending으로 숨기지 않는다.
- Hermes 공식 도구 묶음/config·env 존재·MCP 목록/카탈로그·OAuth 행만 읽는다. `configured`를 키 충족으로 쓰지 않는다. 비밀값은 `gate/connections.py`의 공식 validate/reveal/PUT/DELETE와 승인된 10분 금고를 통한다. 재시작 작업 정보는 기존 승인된 행동 기록에 남고 별도 영구 상태 원본을 만들지 않는다.
- 문구 차이는 변환 규칙 1번(에이전트→직원, Hermes 실행 Mac→서버)·2번(원본 앱 전용 로컬/읽기 전용 설명 제외)이다. D9의 저장됨(확인 안 함)·보상 실패 문장은 hejo 고유 승인 계약이다. 원본의 4px 제목 아래 여백·성공 안내의 초록 아이콘과 달리 hejo 안내는 중립 회색 텍스트이며, 사진 없는 얼굴은 기존 hejo 명부 색을 쓴다. 비교 캡처에 이 차이를 남겼다. 화면 증거는 `evidence/HEJO-FOUNDATION/TASK-32.md`다.

추가 대조: 공식 백엔드에서 기본+보조 두 프로필의 실제 목록은 합계 1,368행·553,466바이트였다. 기존 1MiB 통신 한도를 늘리지 않고 `connections.profile`로 선택한 직원만 읽는다. 직원 목록은 기존 명부를 직접 읽고, 이미 읽은 요약은 창의 메모리에만 둔다. 새 디스크 캐시는 없다. 서버도 전체 결과가 한도를 넘으면 거절한다. 서버 명령에서 온 안내의 ‘이 Mac’·‘맥미니’는 변환 규칙 1번으로 ‘서버’로 바꾸되 id·경로·URL은 바꾸지 않으며 회귀 시험에 넣었다.


### TASK-34 착수 대조(보완 37·추가 1~3)

기준 `37fb43f06507176d6b4244a5a252c5ef339c5c51`, N32-01 시험 전용 커밋 뒤 진행한다. SlackPanel.swift·SlackThreads.swift·DraftEditor.swift·AgentStop.swift는 앞선 전체 독해 기준 `208f6e63`과 diff 0을 확인해 전체 기록을 재사용한다. SlackPanel의 slackComposer·stopControl·slackFolded·slackAddRoom·사이드바 rail/animation·toggleGroup/Stack·motion을 다시 대조했다. AgentStop 21줄도 전체 다시 읽었다. 유지 의존은 기존 ComposerFaces/TypingRow·SidebarLayout·MemberState·DraftTextView이며 다른 앱 원본은 수정하지 않는다.

작성기 간격 8·Spacer 최소 4·가운데 정렬, 중지 앞 간격 6·내부 9·18px/9pt, DM 이름만 16/13pt, + 행 40px, 움직임 0.24 easeInOut·선택 0.34/0.88은 원문 수치다. DM 기본 이름은 사장 선택 ‘DM’으로 바꾸고 Slack 전용 채널 이름 변환·안내는 22판 변환 규칙 2번으로 제거한다. Hermes BasePlatformAdapter.delete_message 공식 bool 계약·run_turn 성공 차례의 post-delivery 정리 경로를 읽었다. 정리와 stop_typing 끝냄은 기존 delete/edit 종류를 쓰며 새 기록 원본을 만들지 않는다.


추가 유지 의존: WritingShimmer.swift 전체를 끝까지 읽고 WritingSpinner의 2×3 점·0.16초·꼬리 농도와 움직임 줄이기를 대조했다. SlackLayout.swift는 앞선 전체 독해 기록을 재사용하고 SlackSectionLayout.rail의 시작 높이 18·아래 여백 10·막대 너비 2를 다시 확인했다. hejo는 표 행을 NSAnimationContext 0.24/easeInEaseOut으로 이동·페이드하고, 같은 맥락의 연속 레일 높이와 선택 표시 spring(0.34/0.88)을 기존 보기에서 그린다. ＋는 별도 고정 뷰를 제거하고 목록의 마지막 40px 행으로 바꿨다. 얼굴 묶음은 기존 ComposerFaces를 가로 스크롤 문서로 재사용했다.

원본 비교는 실제 slackComposer의 첫 HStack·slackModeButton·ddotsFaces, stopControl의 활동 HStack, slackFolded와 slackAddRoom의 표시를 분리 실행했다. 명부·동작 콜백·진단 측정은 가짜이며 원본 앱 전체를 실행하지 않았다. 서비스 전용 명칭·안내는 변환 규칙 1·2번이고, 기본 DM·자유 방 이름·final/삭제 처리·설치 설정은 이번 사장 승인 계약이다. 그림의 직원 색·얼굴 padding과 원본 홈 ‘새 대화’/hejo 스위치 ‘새 글’ 차이는 원본 픽셀 일치로 주장하지 않는다.


### 33판 보완 38 반영: TASK-34 움직임 제외

검증 중 계획 커밋 `a0b3782e9fbe77608478aed5a3f3a4a167444927`가 추가됐다. 최신 handoff 보완 38·spec REQ-HF-34.AC-08의 폐기/이관·design 12절을 읽고 현재 작업과 대조했다. AC-01~07·09는 유지하고 움직임은 TASK-38로 옮긴다. 위 움직임 이식/시험 기록은 초안 당시 사실이며 이번 TASK-34 결과에 포함하지 않는다.

ConversationView·ConversationChrome·ProgressLayoutTests의 움직임 부분만 `.build/task38-start.patch`로 보관하고 실제 작업 트리에서는 되돌렸다(`git apply --check` 0). 표 마지막 + 행·얼굴 스크롤·DM·작업 줄·입력·문/설치 변경은 남겼다. 이 패치는 TASK-38 출발 자료이며 33판의 정확한 움직임과 같다고 승인된 구현이 아니므로 그때 design 12절·REQ-HF-36.AC-03으로 다시 대조해야 한다. TASK-35 원본 네 파일은 읽기만 준비했고 제품 구현은 시작하지 않았다.

## TASK-35 착수 독해·대응

기준 `10ce6701e09c0f2dc5b62ed4649332a969646007`. 앞서 전체 독해한 원본 다섯 파일의 해시가 `.build/task35/read-notes.json`과 모두 같음을 확인했다. ThreeTap.swift(132줄)·ThreeTapReader.swift(150줄)·ThreeTapController.swift(139줄)·ThreeTapNotice.swift(66줄)를 구현 전에 다시 끝까지 대조했고, App.swift(2,575줄)는 기존 전체 독해를 재사용하되 생성/시작/종료·설정 연결을 다시 읽었다. 원본 시험의 탭·프레임·OS 변경·알림 중복 억제 입력도 확인했다. 운영 원본은 수정하지 않는다.

| 원본 파일 | 옮길 책임·유지 의존 |
| --- | --- |
| ThreeTap.swift | 손가락마다 착지점, 정확히 3개·0.3초·0.04·0.4초, 프레임 상태/좌표/시간/ID 검증, 30연속 실패, 기기 식별·OS 변경/실패 중복 억제. Foundation만 의존한다. |
| ThreeTapReader.swift | 96바이트 접촉 ABI와 16/20/32/36 오프셋, 기호 확인, Touch Bar 제외(행 10 이상·열 양수), 기기 목록 10초 확인·세대별 늦은 콜백 차단·라이브러리 상주. Darwin dlopen/dlsym만 쓰고 프레임워크를 링크하지 않는다. |
| ThreeTapController.swift | 잠자기 깨기 재연결, 탭 쿨다운, 설정·건강 상태·알림 대기열·요청문 복사. 저장은 원본 UserDefaults 대신 기존 LocalStore의 Mac별 hejo-local.json에 연결한다(새 원본 없음). 테스트에서는 기기/시각/시스템 설정을 대역으로 준다. |
| ThreeTapNotice.swift | 전체 독해했으나 ThreeTapCommand·ThreeTapSender·Slack/원격 보고 경로는 REQ-HF-35에 따라 가져오지 않는다. 원격 보고 전용 slackText·입력 검증도 소비자가 없어 제외한다. |
| App.swift | 펫 표시·쉬는 중 검사를 거쳐 기존 펫 클릭 경로로 보내고 앱 시작/종료와 설정 '화면과 펫'에 연결한다. 읽은 범위 밖의 기능은 가져오지 않는다. |

문구 변환 규칙 1번으로 요청문의 ddots를 hejo로 바꾼다. 실패 안내·버튼·시스템 찾아보기 안내는 원문을 유지한다. 트랙패드 없음은 원본 `refreshThreeTapSettings`대로 체크를 조작할 수 있고 도움말로 연결 조건을 안내한다. 명세의 '흐리게'와 달리 원본은 비활성/색 변경을 하지 않으므로 원본대로 구현한다(26판 코드 우선). 실패 상태만 체크를 끄고 비활성으로 보이며, 실패 지점과 요청문 복사를 제공한다. 물리 트랙패드 탭은 후속 실물 확인으로 남긴다.

## TASK-33 착수 독해·대응

기준 `bdffda276c7cb1eff7bb82c01a76a6fb9cb3a612`. 구현 전에 아래 원본을 끝까지 읽었다. App.swift는 이전 전체 독해를 재사용하고 업데이트 생성·알림·메뉴·일반 탭 연결을 다시 읽었다. 제3자 SDK는 고정된 Sparkle 2.10.0 압축의 지문·서명을 확인하고 SPUUpdater/Delegate/UserDriver 헤더와 도구 도움말로 API를 확인한다. 원본이나 운영 앱은 실행·수정하지 않는다.

| 원본 | 책임과 이식 경계 |
| --- | --- |
| AppUpdate.swift(416줄) | 30초/6시간 확인, 버전 비교, 발견·묻기·설치 제어·SDK 허용 검사. 조용한 설치/유휴 대기/실패 횟수·relay 정지/복구·토큰 연결·live smoke는 승인대로 제외한다. 앱의 네트워크/창/SDK 경계는 대역으로 시험한다. |
| UpdateRelease.swift(126줄) | JSON 릴리스·중복 자산·크기·타입/주소·버전 검증, redirect 없는 metadata client. 공개 Info.plist 저장소와 공개 자산 주소로 바꾸고 토큰·update-feed 분기는 제외한다. |
| UpdateUserDriver.swift(87줄) | 누름이 설치 동의가 되는 경로와 복구된 다운로드의 재동의. silent·waitForIdle·stopBeforeInstall만 제외한다. 실제 교체는 Sparkle이 소유한다. |
| UpdateReminder.swift(16줄)·UpdateIdlePolicy.swift(63줄) | 달력 기준 다음 날 자정, 알림 켬/끔과 수동 확인, 설치 대기 버전/빌드의 실제 재실행 확인만 가져온다. 유휴 정책·조용한 설치 설정은 제외한다. 이 Mac UserDefaults라는 design 11절의 원본을 유지한다. |
| fetch_sparkle.sh·setup-updates.sh·package.sh·release_update.py(237줄)·build.sh | 2.10.0/고정 지문, 키체인 공개 키 일치, 압축 해제 후 코드 서명/실행 권한, prepare/publish 분리·초안 자산 검증·서명 피드. hejo-ship으로 옮기되 prepare는 공개본 트리 대조, publish는 사장 전용이고 실행하지 않는다. update-feed 가지 쓰기는 제외한다. |
| build_info.py·check_build_env.sh·update_installed.py·update_channel.py | 전부 읽어 유지 의존을 구분했다. BuildInfo는 개인 작업 커밋 대신 소스 트리를 담는다. hejo 기존 빌드/인증서를 유지하며 Pillow 준비·앱 손 교체·relay·private/public 채널 전환 코드는 가져오지 않는다. |
| LoginLaunch.swift·UpdateTests.swift | 설치 위치 판정과 기존 순수/HTTP 대역 시험을 확인했다. 원본 설치 위치는 시스템 및 사용자 Applications 둘 다다. 명세의 /Applications 축약과 달리 원본/현재 hejo LoginLaunch.isInstalled를 유지하고 이 차이를 보고한다(26판 코드 우선). 시험은 가짜 저장소와 임시 환경으로 다시 작성한다. |

문구는 규칙 1번(ddots→hejo), 2번(비공개 토큰·relay 전용 구절 제외)을 적용한다. 릴리스 없음은 승인 문장 '아직 업데이트 릴리스가 없어요.'다. 매번 묻기·펫 업데이트됨 알림은 사장 선택을 유지한다. 고정 SDK의 서명 피드 검증·압축 선검증은 원본 Info.plist와 [Sparkle 공식 설정](https://sparkle-project.org/documentation/customization/)의 2.10.0 지원 범위에 따른다(2.11 전용 항목 제외). 공개 저장소 값은 기존 get-hejo의 공개 배포 설정을 Info.plist로 옮겨 읽고, 앱 코드에 계정 상수를 두지 않는다.

### D33-01: 옛 문과 새 앱 hello 계약 충돌 — 구현 보류

REQ-HF-33.AC-03·handoff 보완 36의 실제 옛 문+새 앱 시험에서, TASK-21 이전 공개본 계열 `a4a80d5431ca378f7818d2bb8dc75475e658b2cb`의 `schemas/hejo-wire-v1.json:181~241`은 hello에 features가 없고 additionalProperties=false다. `gate/server.py:261~276, 308~320`은 이 스키마로 첫 글을 검사해 invalid_frame을 보낸다. 현재 hejo `app/Sources/GateClient.swift:118`은 첫 hello에 features:[rooms]를 항상 보낸다. 따라서 규격 v1이라는 이유만으로 이 조합의 하위 호환을 주장할 수 없다.

임시 HERMES_HOME·가짜 명부·실제 옛 문 WebSocket에서 features를 넣으면 error/invalid_frame, 같은 형식에서 features를 빼면 welcome임을 대조했다(`.build/task33/hello-boundary.json`). 새 앱 실제 GateClient/ConversationController를 붙인 시험도 연결 준비를 기다리다 실패했다(`legacy-run.log`, `legacy.json`). 원본 ddots 동작 차이가 아니라 hejo 고유 통신 계약 충돌이므로 26판에 따라 계획 판단 전 수정하지 않는다. 자동 업데이트 초안은 `.build/task33/draft/`와 `draft.patch`에 보존하고 제품 파일은 착수 HEAD로 복구했다.

### D33-01 해소: 보완 43·35판

계획 커밋 `3d7e1c07b30e924fd16b4e75aed501b4619a3d07`의 변경은 명세·AT·handoff·판정 문서뿐이었다. 제품 충돌 없이 초안 19개를 지문 대조해 복원했다. 최소 지원 문은 TASK-21 이후이며 옛 문 시험은 운영 적용본 `aeaa652a4119bef949c61f192029d2b0b3f5a026`을 쓴다. features 없는 연결·통신 계약 변경은 만들지 않는다. 새 임시 소스에서 실제 짝맺기·송신·수신과 rooms welcome의 가짜 단체방 수신을 확인했다. Hermes 턴만 대역이며 운영 홈·서비스는 쓰지 않는다. 이전 a4a80d5 실패 기록은 잘못 지정된 기준의 재현으로 보존한다.

## TASK-48 착수 대조: 보완 45·40 / I01~I06

기준은 `763c839b359842e50ac2503db68198ddd74728ef`다. 앱 원본 전체 독해는 기존 TASK-20~35 기록을 재사용하며 이번에 앱을 바꾸지 않는다. 원본 화면이 아니라 Hermes Slack 경로가 맡던 동작이 대상이다. Hermes 본체는 읽기만 했다.

- Slack adapter의 유지 대상 `_hydrate_thread_context`, `_has_active_session_for_thread`, `_build_thread_session_key`, `_thread_session_source`, `_post_text_chunks`, `edit_message`·스트리밍 마무리, `send_image`·`send_voice`·`send_video`, `send_slash_confirm`·`send_clarify`·기본 단추 응답/종료 경로를 대조했다. Slack 전용 Socket Mode·채널/워크스페이스·Block Kit·API 호출과 토큰 연결은 가져오지 않는다. 7천 줄 Slack 파일 전체 독해를 주장하지 않으며 유지할 메서드와 호출 의존을 읽은 기록이다.
- 세션 없는 복원은 공식 `set_session_store`로 받은 저장소의 `lookup_by_session_key` 및 suspended를 읽을 수 있다. SessionStore의 공개 exact-key 조회는 잠금을 지키며 세션을 만들지 않는다. Base의 어댑터 세션 키 경로와 build_source/profile 라우팅을 함께 대조했다. 별도 세션 표는 만들지 않는다. Slack 수신은 복원 문맥을 `MessageEvent.channel_context`에 두어 slash 명령을 본문 맨 앞에 보존한다. hejo 1:1 복원도 이 공식 필드를 사용한다. 기존 방·분기 계약은 그대로 유지한다.
- delivery의 `_cap_oversized_output` 전체를 읽었다. `splits_long_messages`면 잘림 꼬리를 붙이지 않고 원문을 돌려준다. hejo는 명시된 65,536바이트·줄 우선/문자 경계·마지막 조각 버튼 계약을 적용한다. Slack의 글자 수 한도·mrkdwn 변환·Block Kit 한도는 hejo 통신 한도와 다른 승인 차이다.
- 공식 지역 낱말표 `agent.i18n.t`와 ko의 Slack confirm/approval/clarify 낱말·결과 줄을 대조했다. 공식 resolver를 유지한다. 사용자 표기는 가짜 계정이나 운영자 이름 대신 기존 사장 표시 ‘나’를 사용한다.
- Slack 링크 사진의 SSRF-safe client·redirect 검사·30초와 Base 미디어 공개 메서드를 대조했다. 기존 FileStore 등록/롤백/크기 한도와 안전 경로를 재사용한다. 운영 파일·실제 링크를 읽거나 요청하지 않는다.

서비스 이름 변환은 기존 22판 규칙을 따르며 새 UI 문구는 만들지 않는다. 새 영구 원본·앱 변경·public 후보 변경은 없다. 최종 비교는 같은 가짜 입력에 대한 원본 함수/공식 게이트웨이와 문 기록·프레임을 사용하고 실제 Slack 발송은 하지 않는다.

### TASK-48 보완 46: N48-01·02

Hermes 공식 ko 낱말표의 `platform.telegram.approval.resolved_*` 네 종류와 `platform.telegram.slash_confirm.resolved_*` 세 종류를 직접 대조했다. 승인·확인 결과는 이 이름 없는 공식 낱말로 바꾸며 새 문구를 쓰지 않는다. 이는 보완 46이 정한 22판 Slack 전용 사용자 구절 제거다. 앞선 TASK-48 비교 JSON의 `{user}이(가)` 결과는 수정 전 기록으로 보존하고 현행 결과의 근거로 재사용하지 않는다. clarify의 `platform.slack.clarify.resolved/awaiting(user="나")`는 유지한다. BasePlatformAdapter.send_video의 `**kwargs` 공개 서명도 직접 대조하고 기존 send_document 경로로 그대로 전달한다. 본체·낱말표는 읽기만 했다.


## TASK-49 착수 전 대조: 보완 41·45 / J01~J03 — 운영 원본 불일치로 보류

기준은 `3c9a0f6d10c147c145b6d8c2b79d50895f39e5bf`다. 운영 저장소의 별도 detached worktree를 만들고, 그 안의 `hermes/plugin-store/team-kit` 사본을 운영 team-kit과 대조했다. 사본 기준 커밋은 `0ee816be50f9c702e4eb4dbcab15dc628f5eba55`이다. 파일 본문 SHA-256·종류·실행 비트와 심볼릭 링크 대상 문자열을 비교했고, 생성 캐시 `__pycache__`·`.pytest_cache`·`.DS_Store`·pyc/pyo만 제외했다. 비밀 파일은 열지 않았다.

사본 656개와 운영 원본 657개에서 다음 소스 차이 3건을 확인했다.

| team-kit 상대 경로 | 대조 결과 |
|---|---|
| `lib/hermes_packs/cctv/now.py` | 양쪽 본문 지문 다름 |
| `lib/hermes_packs/cctv/watch.py` | 양쪽 본문 지문 다름 |
| `lib/hermes_packs/cctv/tests/test_channel_messages.py` | 운영 원본에만 있음 |

근거는 `.build/task49/initial-comparison.json`, 대조 도구는 `compare.py`다. 관련 없는 파일이라도 시작 불일치이면 멈추라는 보완 41을 적용했다. 내용을 합치거나 사본을 운영 원본으로 덮지 않았다. Slack send/post_pieces/splittable/체크리스트 및 report_status.handle/repaint의 TASK-49 전체 독해는 아직 시작하지 않았으며 완료했다고 주장하지 않는다.


### TASK-49 재개: 보완 47 시작 대조 해소·J03 계약 대조

기준 `6e316a241f962fb864ab2158a444182b7a0d10cc`. 앞선 전체 대조 보류는 당시 지시의 결과로 보존한다. 변경 범위 `lib/hermes_reply/**`·`lib/hermes_team_services/**`·`tests/**`와 읽은 로더/의존 소스를 다시 대조했다. 생성 캐시를 제외한 대조 373개는 일치했다(`.build/task49/scoped-comparison.json`). 범위 밖 cctv 세 경로는 앞 목록대로이며 이번 작업에서 고치지 않는다.

| 읽은 원본·의존 | 끝까지 대조한 내용 |
|---|---|
| team-kit `lib/hermes_reply/plugin.py` 전체 456줄 | Slack install의 send·post_pieces·splittable·편집/스트림 제어와 현재 install_hejo 전체. 조각 실패에도 남은 조각을 시도하고 전달된 id만 모으는 결과, interim/expect_edits/열린 stream 배제, 전달자는 기본 문에 위임하는 경계를 확인했다. |
| `lib/hermes_team_services/report_status.py` 전체 143줄 | handle·repaint·mark·find_message의 소유자/보고 스레드 검사와 자기 글만 다시 칠하기, 제목 표식·종결 단추 제거·숨길 상태 줄을 대조했다. 현재 learning.source는 Slack 한정이므로 hejo 경로를 별도로 연결해야 한다. |
| `reply_buttons.py`의 체크리스트 추출→controls→렌더링→선택 갱신→checklist_reply→synthetic_event·clicked_context | ChecklistLabels.submits는 체크 항목과 별개인 제출 단추다. 실제 기존 시험의 일정/lv1/lv2/확인 6경우를 원본 함수로 재현했다. 사용자·스레드 문맥은 그대로 답글에 실린다. |
| `tests/test_reply_migrated_slack_reply_buttons.py` 맞춤 제출 시험·`tests/test_reply_hejo.py` 전체 | 기존 맞춤 제출 의미와 실제 문 대역 통합·프로필 분리·answered/closed 추적·계약 변경 글자 fallback을 확인했다. |
| `__init__.py` report_status 등록, learning.source/_source_row, usage_ledger.register, project_dispatch의 기존 루프 연결 의존 | 등록은 report 설정이 있을 때만이며 hejo 상태 보고는 Slack 금고/사용자 검사를 재사용할 수 없다. usage_ledger가 Slack·photon만 감싸므로 hejo 꼬리말 제외는 유지할 경계다. |
| hejo `gate/adapter.py` checklist/공개 send·edit·상태 경로, `schemas/hejo-wire-v1.json` checklist, `app/Sources/ThreadTools.swift` 답 생성·실제 체크리스트 보기 | checklist는 items·selected·can_skip만 받고 추가 필드를 거절한다. 앱에는 고정 작성/건너뛰기만 있고 맞춤 제출 선택은 없다. 아래 D49-01은 hejo 고유 통신·앱 계약 차이로 원문 우선 이식 규칙의 대상이 아니다. |

#### D49-01: 맞춤 제출 의미를 보존할 계약 누락

`[[체크: 일정 | 제출: lv1 | lv2 | 확인]]`의 원본은 일정 선택 여부와 제출 단추를 독립적으로 받는다. 일정 선택 시 lv1은 `선택: lv1, 일정`, lv2는 `선택: lv2, 일정`, 확인은 `선택: 일정`이다. 아무 체크 없이 확인하면 `건너뛰기`다. 반면 승인된 hejo_checklist의 items=[일정]에는 제출 단추 선택을 담을 자리가 없어 같은 체크가 모두 `선택: 일정`이 된다. 임의 submits 필드는 gate의 invalid_checklist와 규격 additionalProperties=false에 막힌다.

제출 선택을 items에 섞는 대안도 그대로 원문 의미라고 볼 수 없다. 앱의 전체 특례는 제출 항목까지 선택돼 있어도 답을 `선택: 전체`로 줄이고, 일반 항목으로 둔 lv1·lv2는 동시에 선택·전달할 수 있다. 재현은 실제 rb 함수·제품 ThreadTools.answer 함수 분리 컴파일·실행이며 결과는 `.build/task49/checklist-contract.json`·`checklist-probe.log`다. 제품 API 수락 시험은 아니다. 문구의 옮김 실수나 시간·정렬 차이가 아니므로 계약을 임의 확장하지 않고 계획 판단으로 인계한다.


### TASK-49 D49-01 해소·최종 이식(보완 48·35판)

기준 `afc019d56724621784d72a0137e0f92a4486becd`의 결정대로 맞춤 제출은 체크 항목만 보내고 can_skip=false, 제출 낱말은 보내지 않는다. 앞의 Slack 제출 의미 보존 제안은 채택되지 않은 기록으로 남긴다. 시작 직전 보완 47 범위를 다시 대조해 차이 0을 확인했다. 범위 밖 cctv 세 파일은 그대로 유지했다.

- J01: 이미 전체 독해한 Slack post_pieces 결과 집계 함수를 공통화해 hejo도 사용한다. 부분 실패 뒤에도 나머지 조각을 시도하고, 성공 id만 같은 순서로 모으며 partial_overflow를 유지한다. hejo의 interim·편집 예정·추적 중인 열린 흐름은 나누지 않고 구분 줄만 지운다. 조각별 prepare가 각자의 질문·단추·체크리스트를 만든다. 스레드 없는 첫 보냄에도 하나의 새 UUID를 붙여 원래 문처럼 대화를 만들고 답 추적에 사용한다. Slack 전용 slash 비공개 전송 경계는 hejo에 없어 이식하지 않는다.
- J02: report_status의 Slack 함수는 유지하고 hejo 출처만 분기했다. install_hejo의 현재 턴 ContextVar가 공식 background task·executor로 복사되는 경로를 본체 run_turn의 copy_context와 함께 읽었다. 도구는 공식 session_context의 플랫폼·소유자·프로필·방·스레드·세션을 대조하고 현재 어댑터의 공개 메서드만 사용한다. 문 내부 import·기록장 접근은 없다. 헤더/강조 문법은 보존하며 첫 직원 글의 표식을 바꾸고, 부분 상태에서는 기존 단추 id를 보존한다. 상태 줄·note·시각은 본문에 붙이지 않는다.
- J03: ddots SlackThreads의 체크리스트 파서·checklistAnswer 전체, SlackPanel의 HermesReplyChecklist 전체를 직접 다시 읽었다. 일반 목록에는 skip 동작이 있고, 맞춤 submits는 파서가 토글만 읽으므로 skip이 없다. 앱 계약 확장은 만들지 않았다. 같은 입력의 실제 hejo 프레임과 원본 ddots 파서/답 함수를 분리 컴파일해 결과가 같음을 확인했다(`.build/task49/parity-comparison.json`). 이는 같은 상태의 자료·답 생성 비교이며 새 GUI 스크린샷이나 운영 앱 전체 비교가 아니다. 기존 AppKit 체크리스트 보기 자체는 변경하지 않았다.
- 사용량: 기존 usage_ledger의 Slack·photon 등록만 유지하고 hejo 제외를 시험했다. hejo 실제 체크리스트 프레임에 제출 낱말·사용량 꼬리말이 없음을 단언한다.

추가한 문 공개 메서드 `first_thread_message(chat_id, thread_id, *, metadata=None)`는 해당 직원의 첫 살아 있는 직원 글 id와 최신 본문 사본만 돌려준다. 사장 글·다른 직원·다른 대화·삭제된 스레드/방은 제외하고, 전달자는 자기 프로필을 강제한다. 자료의 원본은 기존 Journal 투영이며 별도 저장소는 없다. 호환성 계약이 맞지 않으면 기존 _install_plain 경로로 남는 동작도 기존 시험에서 유지했다.

## TASK-36 — 읽음·종·버튼 규칙 이식 전 대조

기준은 보완 38·49, REQ-HF-36.AC-00·01과 대조표 2판 §A 및 §0-4 2.1판 정정이다. 기존 SlackThreads·SlackController·SlackPanel·DdotsConfig 전체 독해 기록을 재사용하고 아래 근거 함수와 호출자를 끝까지 다시 읽었다. 원본은 읽기만 하며 앱 사이 동기화·원본 앱 실행은 하지 않는다.

| 행 | 원본 (`<운영 저장소>/ddots/Sources/`)과 의존·호출자 | 이식 자리·판정 |
|---|---|---|
| A01·02 | SlackController.publish의 lastRead 초기화·shownRooms·SlackUnread.entry 호출, SlackThreads의 SlackUnread.count/entry/read/quiet 전체 | ConversationModel의 처음 동기화·방 진입. 기존 read:/thread: 키로 처음 message seq를 저장. 종 스레드 위로 방 읽음 값을 넘기지 않음. 원본 Slack 원격 읽음·미수신 답 추정은 연속 기록장 투영으로 대체. |
| A03·04 | SlackUnread.count, SlackController.didSend/markRead와 전송 호출 | 편집/state seq 대신 처음 seq. 생각 줄 제외. 기존 Controller 일반·텍스트·말풍선 전송 성공 경로에 읽음 연결. |
| A05·V01 | SlackController.publish의 bells 전체, SlackNotice.item/isSettled/hermesState | WorkspaceTools의 알림·질문 판정, Model.bell. 처리 중·종결이면 조용한 종도 없음. |
| A06 | SlackNotice.requestsApproval·approvalExchange·assessment 전체, DdotsConfig ConversationRules 기본 patterns·sets·matches | ThreadTools의 순수 판정으로 이식. 인용 줄 제외·nothingWaiting 우선·approval1/2 정규식 그대로. 학습 보고·메일 초안 전용 탐지는 §0-2에 따라 제외. |
| A07·08 | SlackNotice.answers/pendingPosts/buttonPosts/itemPostIDs/waitingPostIDs, SlackPanel.slackApproval 전체, ReplyButtonPolicy 전체 | 기존 메시지·state에서 아직 답하지 않은 요청을 계산해 View 버튼/체크리스트에 연결. 문이 발급한 native approval/clarify/slash 버튼은 기존 식별자 계약 유지; 원본 hermes_reply_buttons에 대응하는 kind=reply에 단어 정책을 적용. 텍스트 승인 요청 기본 단추는 기존 sendText·confirm·의견 입력으로 연결하며 프레임 필드 추가 없음. |
| A09·V02 | SlackNotice.visibleMarks/railColor/assessment, DdotsConfig 색 상수 | 처리 중 노랑·대기 빨강·종결 초록, 생성된 상태 글자 줄 제거. 원래 본문·복사 형식의 상태 표시는 바꾸지 않음. |
| A10·V16 | SlackNotice.items/item/grouped 전체 | 오래된 root 순으로 기여를 만들고 첫 분류 기여 순서를 유지. 질문은 직원 ID로 다시 정렬하지 않음. |
| A11 | SlackController.restore·slackRoom 저장 호출·Ddots 첫 선택 | 기존 Mac 화면 설정 LocalSettings에서 마지막 방 ID, 첫 선택 홈. 회원 읽음·배치를 별도 로컬 원본으로 옮기지 않음. |
| A13 | SlackNotice.approvalExchange·assessment, ConversationRules.sets.yes | 원본 낱말로 글 승인 후 직원 답이 오면 종결. hejo answered는 기존 차례 의미(사장 답을 받고 처리 중)로 원본 working에, closed는 종결에 대응. |
| A14 | DdotsConfig.matching 전체·SlackSpeakers.profile/key 호출 | 명부 얼굴·이름 조회에 공백·하이픈·밑줄 무시와 소문자 비교 적용. 문으로 보내는 직원 ID·단체방 호출 계약은 그대로. |
| A15·16 | ChecklistText.swift 전체, NativeThreadContent 본문 생성·checkbox 링크·소유자 색 처리 전체 | 기존 check: 회원 키 안에 본문 revision과 문자 위치를 넣음. 본문 변경은 초기 상태. 내 글도 체크 가능, 지정 색 속성 보존. |

유지 의존은 기존 AppKit·Foundation·CryptoKit·ConversationModel·MemberState·Controller·NativeThreadCard다. 원본 Slack 수신/설정·개인 업무·SwiftUI 화면은 복사하지 않는다. 문구는 22판 변환 규칙을 적용하며 이 범위의 기본 버튼·안내는 원문 그대로다. A12는 제외한다. 원본 코드의 판정과 기존 hejo 시험이 다른 경우 V01·V02·A03의 명시된 대체 범위만 기록하고 갱신한다.

추가 유지 의존 `ReplyActionIcon.swift` 전체(ReplyActionGlyph·ReplyActionLabel)를 읽고 기본 네 기호의 24단위 경로·16pt 크기·36×30 최소 영역·간격 8·모서리 8을 FileChip의 답 버튼 모드로 옮긴다. SwiftUI 화면을 제품에 추가하지 않는다.

### D36-01 — A07의 대상 지정 답 정보는 현행 통신 계약에 없음

추가 호출 경로까지 확인했다. `SlackPanel.answerHermes`는 항목별 단추이면 `onClickSend`에 post의 ts를 넘긴다. `SlackBridge.post(clickedPost:)`는 `SlackNotice.clickBlocks`로 `hermes_click:<ts>` 블록을 붙인다. `SlackMessage.init`·메시지 변환이 이 값을 `slackClickTarget`으로 보존하고 `SlackNotice.answers`는 값이 있을 때 그 요청에만 답한 것으로 본다. 단순히 같은 스레드의 모든 사장 글을 답으로 세는 구현은 원본과 다르다.

hejo `gate/adapter.py`의 click은 그 대상을 Hermes `raw_message._hermes_button.message_id`로 넘기지만, receive의 사장 message 기록에는 넣지 않는다. `Journal.public`·page 재현에도 없고 현행 message 스키마의 추가 필드는 금지다. 원본 answers·pendingPosts 함수를 그대로 분리 컴파일해, 동일한 A=처리 중/B=질문/사장 글='승인'에서 대상 없는 글이면 B도 답해짐, A 대상 글이면 B는 대기함을 확인했다. 문 실제 어댑터 탐침은 A 클릭 뒤 B가 asked로 남아도 앱 기록에는 대상을 판별할 값이 없음을 확인했다.

이는 26판 원문 우선으로 해결할 수 있는 문구·수치 차이가 아니라 hejo의 기록·통신 계약 공백이다. A07을 보류한다. 다른 행의 제품·시험 초안 14개는 `.build/task36/draft/`에 지문과 함께 보존하고 제품 작업 트리는 착수 HEAD로 복구했다. 위 표는 독해·이식 방향 및 초안의 기록이며 최종 채택·전체 검증 완료가 아니다. 규격·문·허브는 바꾸지 않았다.

### TASK-36 보완 50 — D36-01 해소와 초안 재개

35판 결정 `a7cae0c`의 message.answer_to 선택 필드를 적용한다. 보류 당시의 두 기록은 보존한다. 초안 14개는 manifest 지문과 같고 착수 기준과 새 HEAD 사이 제품 차이가 없음을 확인한 뒤 복원했다. 버튼 답만 요청 msg_id를 문 기록에 남기며 앱의 send에는 새 필드를 넣지 않는다. 원본 answers의 `target == nil || target == request` 조건을 앱의 answerTo로 직접 대응시킨다. 옛 문 aeaa652가 필드를 주지 않을 때는 35판에서 승인한 직접 쓴 글 취급이다.

이전 앱 시험의 편집 unread 증가 단정은 A03의 처음 seq 기준이 명시적으로 대체한다. 처리 중 조용한 종은 V01이 대체한다. 첫 직원을 기본으로 가정한 메뉴 시험은 A11에 따라 직접방을 명시적으로 열도록 준비를 고쳤다. 수락 문서의 기대값을 완화한 것이 아니라 지정 원본과 명시적 대체 기준을 적용한 변경이다.

전체 검사에서 같은 대체 범위의 종속 단정도 대조했다. RoomsTests의 고정 방 읽음 값 5(edit·state 포함)는 마지막 처음 글 seq 3으로, 전송 중 보이던 다른 방에 도착한 평범한 글은 A01에 따라 읽음 0으로 바꾼다. 그 방 글 수신 자체를 기다린 뒤 값을 단언하므로 기다림을 없애거나 느슨하게 하지 않는다. 원본 `answerHermes`의 받은 '확인' 단추는 그 단추 답을 보내고(항목별이면 대상 포함), 버튼 없는 텍스트 승인 요청의 기본 '확인'만 로컬 확인이다. 이 둘을 구분해 기존 Controller·전송 시험을 연결했다. 기본 단추의 tooltip은 원문, 정해지지 않은 단추 안내는 원본처럼 tooltip에 둔다. AppKit 버튼의 flipped 좌표에 맞춰 원본 기호의 방향을 유지하고, 바깥 controls의 왼쪽 43pt·위 2pt도 연결했다.

루프백 전송 시험의 A01 단정은 수신 전에 다른 방으로 이동하면 성립하지 않는다. 전체 시험에서 이 준비 순서 문제를 확인해, 전송 완료 뒤 선택이 유지됨을 먼저 확인하고 **그 방에 머문 채 새 글 수신·읽음 0을 확인한 다음** 원래 스레드로 이동하도록 순서를 고정했다. 다른 방 도착 글의 unread를 임의로 0으로 간주하지 않는다. 빈 방을 처음 본 뒤 새로 온 글은 이후 sync로 지워지지 않도록 처음의 read:0도 기존 회원 상태에 남기고 회귀 시험을 넣었다.

최종 체크 의존도 대조했다. NativeThreadContent가 만든 본문의 revision과 문자 위치를 클릭 콜백에 함께 묶어, 화면 교체 전의 행동이 새 본문 체크를 바꾸지 않게 한다. 기존 check: 키를 재사용하며 새 저장소는 없다. 원본/제품 화면의 유효성·같은 상태 비교 범위는 evidence/HEJO-FOUNDATION/TASK-36.md에 기록했다.


## TASK-37 — 작성기 대상·보내기 독해(보완 51·38)

기준 f1dbde2, 대조표 2판 §B와 §0-4 2.1판 B04/B13/B15~18 정정을 함께 읽었다. 이전 전체 독해 기록(SlackPanel·SlackController·SlackThreads·BubbleReply·NativeThreadContent)을 재사용하고 아래 함수·호출자를 다시 끝까지 읽었다. 원본은 읽기만 한다.

| 행 | 원본 함수·유지 의존 | 책임 자리 |
|---|---|---|
| B01·02 | SlackPanel defaultReply/target/replyCandidate/newestThread/writeReply/enter/choose·reply, threads didSet 호출 | 기존 ConversationView 선택·최근 활동 투영. 기본 auto 자리와 명시적 선택 구분 |
| B03 | SlackPanel interruptible/sendTarget/send 전체, SlackController.markInterruption | 열린 작성 중 스레드로 보내되 단체방 수신자는 기존 대표/@ 계약 유지 |
| B04·05 | SlackController.send/sendFiles Echo 전체·didPublishEcho, NativeThreadContent.nativePost, NativeThreadCard pending/interrupted 그리기, ChatStyle.UserBubblePalette | Controller pending 메모리와 기존 카드.Post pending/interrupted. 시간은 2.1판 정정의 ‘보내는 중’ |
| B06 | SlackDrafts.swift 전체, SlackPanel draftPlace/moveDraft/release/changeConnection/adoptWorkspace/settleWriting, SlackController.chatOpen | 기존 초안 메모리·선택 경로. 주소별 초안, auto 자리, 삭제된 대상 carry. 영구 저장 안 함 |
| B07·08 | SlackController.isQueued/markInterruption, BubbleReplyInterruption 전체, nativeContent replies/interruptedCaption | 명부 queued 읽기와 기존 interruptions. 표시 위치 답 줄 왼쪽·답들 뒤·작업 줄 앞 |
| B09·10 | slackComposer/slackFailureLabel/slackPrompt 전체·BubbleReply.placeholder | 홈 새 대화·스레드 첫 글 36자·고정 방 이름·받는 직원 안내. Slack 단어는 22판대로 변환 |
| B11·12·15·16 | slackModeButton/mentionFaces/ddotsFaces·aim·recipient/litRecipientProfile, ChatMetrics.callerAvatar | 기존 AppKit ComposerButton·ComposerFaces. 24pt·각 얼굴 단추·고리/흐림/접근성·가로 스크롤 |
| B13·17·18 | SlackDrafts.restore, SlackPanel.restoreFailure 전체, SlackController.failed/pickFiles/sendFiles, SlackFiles.swift 전체(OutgoingFile/Problem 포함) | 기존 실패 목록·GateHTTP 업로드와 고르기 창. 50MiB 사장 한도 유지·이름 있는 오류·고르는 동안 접힘 방지 |

B14는 제외한다. hejo의 출입증/연결 완료 전 송신 거절·단체방 대표 직원·첨부 50MiB는 유지한다. 원본의 파일 200MB 문구만 유지 한도로 바꾼다. 원본의 ddots 전용 자동 내용 분류 대신 기존 홈 기본 받을 직원·명시적 얼굴/@ 계약을 쓴다. 새 영구 원본·문 규격·Hermes 본체 변경은 없다.

N36-01은 기록 시작 이후에 도달할 수 없는 since/scriptSince와 retired/legacyScript/옛 mailLegend를 제거하고 allowed/scriptPending는 유지한다. N36-02는 실제 가짜 루프백에 연결한 canSend=true 상태로 원본과 같은 장면을 다시 캡처하며 연결 가드를 제품에서 우회하지 않는다.

B05 호출 경로 추가 확인: NativeThreadContent.nativePost는 message.replyInterrupted를 Post.interrupted에 넘긴다. 실제 생산자는 HermesBridge.markInterruptions(SQL에서 user→빈 assistant→다음 user)이며 HermesRelay.Message로 보존되는 별도 Hermes 기록 보기다. SlackBridge의 ChatMessage 생성과 DdotsLine.message/threads 경로는 그 값을 설정하지 않아 기본 false다. 현재 TASK의 Slack 방과 같은 상태에서는 표시가 없다. 26판 코드 우선에 따라 이 죽은 표시를 새 추정으로 켜거나 wire 필드를 추가하지 않는다. 원본 NativeThreadCard의 기존 interrupted 그리기 자체는 보존한다.

N36-01 추가 대조: 날짜 이름의 옛 mailLegend는 실제로 contexts에서 allowed에 무조건 등록돼 있다. 날짜 이후 글도 해당 본문이면 true다(원본 분리 실행 확인). allowed 유지·결과 불변 지시에 따라 그 본문 맥락은 기존 contexts에 그대로 두고, 날짜 이름 상수와 실제 날짜 조건(since/scriptSince·retired/legacyScript)은 제거한다. 옛 이모지 운영자 낱말은 남기지 않는다. 이는 새 허용 규칙이 아니라 기존 allowed의 보존이다.

B06·전송 의존 추가 확인: auto/new/thread는 작성기 초안 자리이고, 새 글의 실제 전송 스레드는 매번 새 UUID다. 기존 자리 UUID를 그대로 보내면 첫 확인 뒤 다음 새 글이 답글로 섞인다. Controller의 기존 전송 책임에서 실제 주소를 정하고, 실패에는 원래 초안 자리를 보존한다. WorkspaceTests의 기존 확인/후속 답 조건은 유지하면서 실제 확인된 글에서 전송 스레드를 얻도록 준비만 바꿨다. 새 글·홈 글의 늦은 거절도 같은 자리에 되살린다.

자동 대상 선택은 사용자의 명시적 누름과 구분한다. A02의 종/읽음 계약을 보존하도록 자동 진입은 읽음 표시를 하지 않고, 직접 고른 경우에만 기존 읽음 경로를 쓴다. B07의 원본 isQueued에 따라 기존 말풍선 queue 시험의 끼어들기 표시 단정은 표시 없음으로 대체했다. 텍스트만 보냄·첨부 보존·정확한 스레드 읽음 단정은 그대로다.

전송 상태 소비자도 함께 확인했다. 초안은 즉시 비워지고 새 글 대상은 별도 UUID이므로, AppDelegate의 펫 보내기 반응과 기존 재전송 확인이 쓰는 sending은 선택된 초안 자리가 아니라 현재 연결의 실제 pending을 가리켜야 한다. 다른 방을 보는 동안의 원래 방 재전송 시험이 이 경계를 검출했고, 기대값을 유지한 채 기존 Controller 계산을 고쳤다.


## TASK-38 — 사이드바 원본·유지 의존 대조(보완 38·52)

기준은 7c8e953, 대조표 2판 §0-2·§C와 2.1판 정정/C22~27, design §12다. 기존 SlackPanel·SlackController·SlackThreads 전체 독해 기록을 재사용하고 아래 함수와 호출자를 끝까지 다시 읽었다. SlackRoomDialogs 전체·ChatWorkspace 전체·SlackZones/SlackSectionLayout·slackSidebar/Tab/Row/Folded/Signals/Counters/Faces/PinMenu/AddRoom/SearchField/Hits/Handle와 제어기 publish의 hub/hidden/muted/section 조립을 대조했다. .build/task38-start.patch는 읽기만 했으며 reloadData·slideUp/Down·선택 상자 이동이 남은 32판 초안이라 그대로 적용하지 않는다.

| 행 | 원본·의존 | 이식 책임 자리 |
|---|---|---|
| C01~04 | SlackPanel.slackTab/slackRow/slackSidebar, SlackSidebar·SlackZones.gap | ConversationChrome 셀·SidebarLayout 행과 기하. 홈 inset20·구획 앞 틈4, 목록 이름 primary, 탭 이름10/54/최소0.85 |
| C05~09·V03 | slackFaces/PinMark/MuteMark/Folded/SectionSignals/RoomCounters, ProfileAvatar·ChatMetrics.avatarCorner | 셀 얼굴·표식·배지/신호 층. 접힌 구획은 제목+점뿐, 구획 사진 메뉴/그리기 제거, DM 기본 이름과 얼굴 줄 없음 유지 |
| C10~13·20·21 | SlackSectionLayout.rail 전체, slackSidebar의 overlay·animation·blank/divider, SlackModel.motion | NSTableView 안정 id 행 차이·effectFade·0.24 easeInEaseOut, 구획별 CAShapeLayer, 선택 opacity spring. 바닥28·막·경계·끌기 강조 |
| C14·15·22~24 | slackSearchField/Hits/AddRoom, SlackSearch.hits/snippet/highlighted 전체 | 같은 표 스크롤 안 검색/방/글 결과/추가 행. 구절 전체 포함·생각 중 포함·최신30, 말한 이는 실제 speaker. 전체 검색 규칙은 별개로 유지 |
| C16·17·V04~06·V13 | slackSidebar.contextMenu/PinMenu/AddRoom, ChatWorkspace.workspaceBrand, SlackController 홈 선택 | ConversationView/RoomDialogs/RoomMenus. 메뉴 순서·구분선, 뺀 방 바로 나열, 보관 있을 때만 하위 메뉴, 로고 접기 하나. 1:1 사진·대표 직원·직원 빼기·기본 받을 직원은 사장 계약 유지 |
| C18·19 | SlackRoomDialogs create/rename/renameGroup/confirm/invite 전체와 Controller 호출 | 기존 네이티브 대화상자. 폭320·바꾸기·포커스·30자, 빈 이름 재질문. Slack 소문자/빈칸 변환·공개여부/사람 초대는 제외, 한글 조합 유지 |
| C25~27 | slackSidebarHandle/slackRoomLabel, Controller.publish의 선택 hub 제외·숨김/알림 해제 | 손잡이 전체 높이·숨김, 접근성 자식 표식, 기존 MemberState와 기록장 투영. 새 원본 없음 |

AppKit 실제 탐침(.build/task38/TableProbe.swift)은 effectFade만 쓰면 들어온 줄의 presentation y가 최종 y에 고정되고 alpha만 변하며 아래 줄만 y가 보간됨을 확인했다(종료0, table-probe.log). 따라서 삽입/삭제에 slide 옵션을 쓰지 않는다. 구획 레일·배지/머리 색·선택 상자는 표의 같은 트랜잭션에서 별도로 보간한다. 동작 줄이기면 즉시다.

유지: 허브 회원 배치/사진 경로·문 명부/기록장·사장 DM/로고·1:1 사진/기본 받을 직원. 구획 이름 설명은 원문 그대로 hejo 이름으로 변환한다. 추가 독해한 SlackSettingsSync.syncedState도 groupNames를 보내므로 원본의 “이 Mac에만 저장” 문장은 원본 코드와도 맞지 않는다. 새 저장 계약을 만들지 않고 기존 허브 배치를 유지하며 이 원본 문구의 불일치를 검토 사항으로 남긴다. 구획 사진은 새로 읽거나 지우지 않고 기존 저장 필드만 하위 호환으로 보존하며 화면/메뉴에서는 쓰지 않는다.

추가 의존: SlackSearch.swift 전체와 SlackFindView.highlighted를 끝까지 읽었다. 검색은 sidebar(hits)와 전체 groups를 나누며, sidebar는 구절 전체·생각 중 줄을 포함하고 원본 snippet·강조 순서를 그대로 쓴다. hejo의 표식 칸은 기존 reply_state의 한국어 보기 낱말이며 원시 asked 같은 값은 sidebar 검색어에 섞지 않는다. 실제 말한 이(speaker)와 방을 따로 표시한다.

옛 시험 대체 범위도 명시한다. AT67의 1:1 대화 열기·모두 읽음·도구 연결 메뉴/빈 곳 메뉴/뺀 방 하위 메뉴는 C16·17의 원문 순서로 바꾼다. 모두 읽음 기능 검사는 남아 있는 머리줄 메뉴에서 그대로 실행한다. AT68·69의 배지 픽셀 검사는 CALayer 배지를 포함하도록 실제 층을 그리며 색 단정은 보존한다. AT80·85의 홈 직원 제외 준비는 V05대로 없애고, 단일 얼굴 너비 검사는 실제 명부 한 명으로 준비한다. 사진 쓰기 권한·새 글/답글 주소·초안 보존·읽음·허브 저장 단정은 완화하지 않는다.

정적 캡처는 원본 SwiftUI 그리기 함수를 분리한 보기다. 화면 밖 렌더러가 직접 그릴 수 없는 TextField만 같은 자리의 ‘검색’ 정적 글자로 대체하고, 원본 ScrollView의 현재 보이는 내용은 같은 크기의 잘린 VStack에 둔다. 원본 메뉴·대화상자 전체 운영 실행이나 픽셀 동일성을 주장하지 않는다. 실제 hejo 캡처는 가짜 루프백에 연결된 실제 ConversationView이며, AppKit의 투명 PNG는 원본과 같은 밝음/어두움 바탕에 sourceOver로 합성한다.

최종 그리기 대조에서 primary의 알파를 확인했다. macOS 기본 글자색은 자체 알파가 있으므로 SwiftUI `.opacity(p)`는 그 알파에 p를 곱한다. SidebarTone은 같은 곱셈으로 구획/레일/검색 배경/quiet 색을 옮긴다. 탭의 안 읽은 글은 이름색만 primary이며 굵기는 선택 때만 바뀐다. 목록의 이름↔핀/종도 HStack 원문 간격 12를 쓴다. 글 검색 행은 본문 한 줄/두 줄 높이에 맞춘다. 고정 홈 사진은 원본 displayRoom/picture(for:)대로 선택한 방 자원이고, 기본 홈의 사진/펫 그림으로 대체하지 않는다. 문이나 사진 API의 원본은 늘리지 않는다.


## TASK-39 카드·글·파일 원본 대조

칸은 기존 손 보기(ConversationView·NativeThreadCard·TextLayout·첨부 보기)다. 기록장·회원 상태·통신 원본은 늘리지 않는다. §D와 2.1판 D04·D25~D30, 보완 52·53을 함께 적용한다. NativeThreadContent 전체, StreamPreview 전체, ReplyActionIcon 전체, SlackFiles 전체, WritingShimmer 전체, LinkPointer 전체와 ChatStyle의 팔레트·ProfileAvatar의 그리기를 읽었다. 이전 전체 독해의 SlackPanel·SlackThreads·ChatPanel은 이번에 카드 조립·날짜·삭제·버튼·첨부·작성기·작업 줄·더미·사이드바 표시 함수와 호출 의존을 다시 대조했다. 기존 NativeThreadCard·TextLayout 엔진은 유지하며 이번 차이는 내용 조립과 hosted 조각에 둔다. 원본 파일 지문은 로컬 reference-inputs.json에 보존한다.

- D01~05: ReplyActionIcon, NativeThreadContent.pieces/extras/actions, SlackThreads.ReplyButtonPolicy.split. 실제 카드 아래 단추에는 툴팁 없음(접근성 이름만). quiet는 기본 글자색 alpha×0.7, 누른 복사·분기는 accent, 긴 분기 orange, 삭제 확인 red. 전송 전 임시 글에는 분기·삭제 없음.
- D06~10·D23·D25: SlackModel.place, ChatView.day, CharacterPalette.make, ChatText.linkifiedNative/mayOpen, SlackLayout.apply, SlackBlockText.fittedRules. 홈 날짜는 최신 활동, 나머지는 첫 글 위치(hejo에 broadcast 원본은 없음). 인용 바깥 막대는 스레드 주인 색, 안쪽은 회색.
- D11~17·D26·D29~30: fileView/slackAttachments/slackFailures/HermesReplyChecklist/threadControls/AttachmentDropModifier. 파일 크기는 1024 단위·공백 없음, 사진 최대 220×180 비율 유지. 파일 내려받기·보안 경계는 기존 FileTransfer를 유지한다.
- D18~22·D27~28: typingBubble(compact:true), stopControl, WritingShimmer, StreamReveal, NativeThreadList.eased, refreshThreadRenderMemos의 onWritten. streaming은 표시용 메모리 상태이고 기록 본문은 바꾸지 않는다. 기본 글자 '작성 중'의 기존 1.6초는 사장 선택대로 보존한다.
- N38-01: SlackPanel.slackPinMark/slackMuteMark는 font 8의 intrinsic SF 그림, quiet. 고정 8×8로 축소하지 않는다. 방 추가 Label은 원본 기본 Label 간격을 측정해 native에 적용한다.

### D39-01: 삭제된 첨부 표시의 계약 공백 — 보류

D11의 “삭제된 사진/파일”은 원본 SlackThreads의 파일 파서가 `mode == tombstone` 또는 `is_deleted == true`를 읽고, SlackPanel.fileView가 그 명시 표식을 표시하는 경로다. hejo의 wire v1 file은 file_id/name/mime/size만 허용하며 additionalProperties=false다. 기록장에 첨부가 남아 있어도 실제 파일이 없어졌다면 FileStore.registered는 UnknownFile을 낸다. 문 download는 이를 미등록·접근 범위 밖 파일과 같은 HTTP 404로 보낸다. 앱 GateHTTP도 unavailable로만 받는다. 404를 삭제로 간주하거나 앱에 삭제 원본을 만들지 않았다. 방·스레드 삭제는 기존 계약대로 글 전체를 같은 seq delete로 치환하므로 삭제된 파일 타일을 남기지 않는다.

실제 문·루프백·가짜 홈 재현에서 미등록 첨부와 등록 뒤 파일 유실은 HTTP 상태와 본문이 같았고, 후자의 sync/page 원본은 변하지 않았다. is_deleted를 추가한 프레임은 현재 스키마가 거절했다. 삭제 표식 적용 범위를 제한할지, 별도의 승인된 파일 계약을 정할지 계획 담당 판단이 필요하다. 새 wire·기록장 종류는 만들지 않았다. 작업 중 팔레트·링크/스트림 표시·얼굴 바탕·본문 분할 초안 4개는 로컬 draft/에 지문과 함께 보존했고 추적 제품 파일을 착수 HEAD로 복구했다. 이 초안은 컴파일·수락 검증을 마친 구현이 아니다.

### D39-01 해소·보완 54 재개

35판 결정대로 삭제된 사진/파일 표시는 제외한다. 404·유실은 실패 표시이며 wire·문·기록장을 바꾸지 않는다. 초안 4개는 저장 지문과 일치하고 두 기준 사이 제품 변경이 없음을 확인해 복원했다. 이전 보류·재현 기록은 보존한다.

### TASK-39 구현 대조 결과

- N37-01/D03~05: 네 단추의 평소 quiet는 원본 nativeQuiet(기본 글자색의 alpha×0.7)이며 복사·분기 요청 후 accent, 답 50개 이상 분기 orange, 삭제 확인 red다. 전송 전 임시 글은 분기·삭제 없음. 분기는 직원 글이 있을 때만, 삭제는 답이 없으면 내 글·답이 있으면 고른 스레드만이다. 카드 아래 접근성 이름은 원문, 툴팁은 없다. 카드 아래 줄과 답 단추 줄의 빈틈·비활성 단추는 threadControls처럼 누름을 소비한다.
- D02/D23: 기존 내용 조립에서 글 머리→단추→자세한 내용으로 나누고 자세한 내용은 continuation으로 둔다. 기존 TextLayout을 재사용하며 바깥 인용은 스레드 주인 색, 안쪽은 회색이다. 파일 글에서만 체크 도움말을 붙이고 일반 native 직원 글에는 붙이지 않는다(2.1판 D17).
- D06~10/D25: 복사 머리의 단체방 #·1:1 @, medium 상대 날짜(홈 최신 활동·그 밖 첫 글), 팔레트의 명도·4.5 대비 계산, 링크 하늘색·밑줄, 원문 bare-link 마침표 처리·obsidian 허용을 옮겼다. 긴 가로줄은 표시만 15자로 줄이고 기록·복사 본문은 유지한다.
- D11~17/D26/D30: 사진은 비율 유지·최대 220×180, 준비 전 160×110, 실패 원문·처리 중 돌림표다. 35판 제외에 따라 삭제 문구·삭제 표식을 만들지 않는다. PDF와 파일 크기(1024 단위·공백 없음), 내려받기 그림·손 커서, 별도 빼기 단추인 첨부 캡슐, 오른쪽 칸 전체의 끌기 강조, Divider·info 안내, 작성기 안 실패 줄·되살리기 도움말·별도 보러 가기, 넓으면 한 줄·좁으면 두 열 체크리스트를 적용했다. 파일 경로·인증·50 MiB·삭제 중 내려받기 차단은 기존 hejo 계약을 유지한다. 이전 글 보기·빈 방 줄은 목록 안에 두며 준비 상태에 따라 불러오는 중 문구와 비활성을 쓴다.
- D18~22/D27~28: compact typingBubble은 얼굴 34·이름만 보이며 활동 문구는 접근성에 남는다. 생각 중 글도 같은 자리다. 작업 줄은 두 줄·quiet·고정폭 초·원문 6pt 옆 18×18 중지·되돌리기 도움말이고 연결 상태에 따라 흐려진다. 활동 shimmer는 1.8초·폭 28%·primary 0.5, 기존 작성 중 1.6초는 사장 선택대로 유지한다. NativeThreadList의 6pt 양보를 스트림을 따라 읽는 행에만 연결했다. StreamPreview/SlackStreamPreview.applying 전체 의존을 추가로 읽고, 최종 기록이 도착해도 진행 중인 bounded reveal은 그 최종 본문을 대상으로 마치도록 했다(새 글이나 영구 원본 없음). uniformSize·커서는 유지하고 따라 읽던 긴 답의 펼침은 완료 후에도 남긴다. 답글 더미는 보기만 여닫고 대상·초안을 옮기지 않는다. 사진 얼굴에는 프로필 색을 깔지 않는다.
- N38-01: 같은 macOS에서 원본 SwiftUI와 AppKit symbol을 직접 측정했다. font 8의 pin.fill=11×12, bell.slash.fill=9×11이다. 기존 8×8 강제 축소를 없애고 intrinsic 크기·quiet·45도 회전을 쓴다. 원본 Label의 medium plus.circle=15×15, icon x=0·text x=23으로 사이 간격 8pt다. AT-89에 측정 단언을 추가했다.
- 기존 체크리스트 시험의 중첩 NSStackView 탐색은 대체된 보기 구조라 제거하고 실제 자손 단추 탐색으로 바꿨다. 선택·전체·작성·건너뛰기 단언은 그대로다. 공식 AT-90 문서의 D04·404 경우는 보완 54에서 승인한 정정만 반영했다.

추가 의존 확인: ChatPresentation.updatePalettes·ChatCharacter.ordered를 읽었다. 명시 프로필 색이 없는 이름은 원문처럼 기본 흑/백이고, 있는 색의 중복 hue는 +40도·25도 최소 간격 계산을 적용한다. ddots의 비공개 preferred 배열을 베끼지 않고 명부의 기본 이름/id 순서를 쓴다(새 설정·영구 원본 없음). 전체 검사에서 기존 TypingTests의 고정 2026 시각과 1970 가짜 시계가 D19의 '마지막 사장 글부터 초'와 맞지 않아, 같은 가짜 시각을 쓰도록 했다. activity shimmer 기대는 1.8초로 교체하고 별도 작성 중 1.6초 단언은 보존했다. 스트림 본문·커서 검사는 D27의 bounded reveal이 끝나는 주입 시각 뒤에 동일하게 검사한다. 첫 통합 컴파일의 appearance override 중복과 이 시험 실패는 로컬 intermediate 기록으로 남기고 최종 통과 근거로 쓰지 않는다.

기존 AT-79의 다른 방 실패 줄 단정은 합쳐진 FileChip 하나를 찾았다. D16 원문의 별도 Text + 테두리 없는 “보러 가기” 단추로 대체했으므로, 같은 정보와 단추를 각각 관찰하도록 바꿨다. 전체 검사에서 이 옛 보기 구조 단정이 검출된 기록은 intermediate-failure-row-contract에 보존한다.

사진의 세로·작은 크기 의존도 원본 SwiftUI layout preference로 실측했다. 110×360은 220×180 틀 안의 x=82.5·55×180 그림이며 32×64는 같은 틀 안의 x=65·90×180이다. loaded 사진에 min(1) 확대 제한을 없애고, 220pt 틀의 가운데에 비율 유지로 그린다. 준비 전 자리는 원문 160×110이다. 사진 실측 이전에 통과한 실행은 intermediate-before-portrait-fit에 따로 보존하고 최종 변경본 검증과 구분한다. 긴 스레드 50답 fixture는 실제 기록·모델에 쌓되 중간 보기 갱신을 묶고 최종 내용·주황 분기를 그대로 검사한다.

N38-01 최종 화소 비교에서 그림의 quiet가 불투명 검정으로 남는 것을 발견했다. 반투명 색을 원본 검정 glyph 위에 sourceAtop으로 합성하면 원래 불투명 alpha가 남기 때문이다. sourceIn으로 glyph 모양과 지정 색 alpha를 함께 보존한다. 답 그림과 파일 보조 그림도 기본 primary alpha×opacity를 보존해 원문 Color.primary.opacity와 맞춘다. AT-89는 흰 배경에서 quiet 핀의 실제 가장 어두운 화소가 원문의 회색 범위인지 검사한다. 크기·간격만 맞은 수정 전 그림/실행은 intermediate-before-symbol-alpha에 보존한다.

남은 원본 getter/표시 경계도 대조했다. ChatFile.isPDF는 MIME뿐 아니라 대소문자와 무관한 .pdf 확장자를 본다. NativeThreadContent.nativePost는 직원 글의 가장자리 개행만 지우고 내 글은 보존한다. MessageFormat.uniformSize는 보이지 않는 U+200B layout sentinel의 작은 글씨를 유지한다. 이 경계를 제품·시험에 반영했다. StreamReveal은 원본 frame처럼 모든 수신 표시 상태를 시계마다 전진시키되, 따라 읽은 답으로 표시하는 대상은 현재 방/홈의 스레드로 제한했다. 다른 방 스트림이 멋대로 펼쳐지지 않는 단언을 추가했다. 날짜도 실제 Date를 비교하고 확인 전 메모리 글을 포함하는 기존 Controller.timeline을 사용해 새 글이 먼 과거로 표시되지 않도록 했다. 변경 전 통과 기록은 intermediate-before-render-boundaries에 보존한다.


## TASK-40 원본 독해·대응 (보완 55·38)

- E01~05·E14~15: NativeThreadList.swift 전체(Coordinator update/layout/geometry/performScroll/input monitoring), SlackPanel의 receiveStreams→applyStreamFrame→glide/glideStep→refreshThreadRenderMemos, Place/place/keep, requestScroll/entryViewport 전체·choose/select/toggle/keepOpen·resize place/restore를 읽었다. SlackController.whenStill·arrive의 자리 보존 호출까지 대조했다. 가운데는 frame.midY−viewport/2, 끝은 frame.maxY−viewport, 0/0.15/0.45 재관찰이다. glide는 프레임 보정 min6·max1, 성장만 20%·최소2·최대36×frames, 축소는 즉시, 마지막 1.2초다. keep는 바닥 거리로 0/0.06/0.2/0.4초 복원하며 손 입력·새 요청이 이긴다. 이 상태는 기존 NativeThreadList가 소유한다. 기록/통신은 바꾸지 않는다.
- E06~07/V15: NativeThreadContent의 style와 NativeThreadCard post.flash, SlackFind의 reveal/arrive/findTerm/openFind 및 SlackPanel open.didSet을 읽었다. flash accent 2·본문0.18·둥근8·1.6초(아일랜드1.5), 검색어는 같은 스레드의 모든 글에 접을 때까지 남는다.
- E08/E17/A17: slackNoticeBar 전체·SlackModel.jump/go·alertCount와 기존 hejo notices를 대조했다. 원본 알약 수는 threads.count이며 hejo는 이미 스레드당 요청/알림 하나씩 뽑는다. 툴팁·접근성·가로 스크롤·위쪽 opacity/move 0.24·quiet chevron을 적용한다.
- E09~11/V07: ChatWorkspace.swift·SlackFindView.swift 전체, SlackPanel.headerTitle/headerDescription, ChatDragView 전체를 읽었다. 오른쪽 머리줄 단추는 없애고 기존 메뉴·⌘F 경로를 쓴다. 2.1판 홈 제목 순서를 적용한다. 검색 결과 이름은 글의 실제 speaker이며 방은 @/#/홈 이름이다. 검색 서식은 원문의 노랑·검정과 14 medium 첫 글, 12 본문이다.
- E12: SlackModel.animated·ddotsFaces·slackAttachments·작성기 모드 전환과 기존 ComposerFaces를 읽었다. 기존 얼굴0.24는 재사용하고 모드/칩은 같은 0.24 easeInOut으로 연결한다.
- E13/E16: App.layoutChatSize/slackFitHeight/slackChromeHeight/fitSlackThread, ChatPresentation measureReply/releaseReplyHeight/toggleReply, ChatPanel.replyHeight, PetLayout retarget/step 전체 의존을 읽었다. 창 높이는 기존 PetController 위치/크기 한 곳에서 τ0.065(최대dt0.1·오차0.2)로 추종하며, 더 보기의 확장 전 실측 높이 기준으로 접으면 되돌린다. 수동 크기 조절은 기준을 받아들이고 해제한다.
- N39-01: HermesReplyChecklist 전체(choices/ViewThatFits/grid/body) 재독. 항목 .bordered·12pt, 간격8·fixedSize, 작성/건너뛰기도12pt 기본 bordered다. 기존 hejo의 +20 고정 폭·48/80 폭 대신 원본 실측에 맞춘 native 제어를 쓰고 AT-90 측정을 추가한다.

N39-01 실측: 원본 .font(.system(size:12)) 환경의 .bordered 기본 제어는 일정 61×24·선택된 일정70×24·작성47×24·건너뛰기69×24다. 동일한 AppKit regular rounded는 font12에서59/66/45/66, font13에서61/70/47/69로 원본과 일치한다. 이 macOS 기본 제어의 실제 치수를 따라 font13·intrinsicContentSize로 옮긴다(원문 선언을 임의 수치로 고친 것이 아닌 실제 네이티브 제어 표시 대조). 원본 `.fixedSize()`대로 격자에서도 단추를 열 전체 폭으로 늘리지 않는다. 선택 후 글자/폭도 다시 잰다. 근거는 로컬 checklist-measure.log·native13.log이며 AT-90에 실제 프레임 치수를 더했다.

TASK-40 연결: NativeThreadList의 갱신 때 무조건 마지막 행으로 뛰는 옛 경로를 제거하고 가운데/끝 요청·glide·keep·readerInput·0.25/2초 갱신 보류로 교체했다. 입력 모니터는 목록 안 포인터 또는 목록 자손 키보드에만 반응한다. 크기 조절은 같은 목록의 행 id/offset 또는 바닥을 보존한다. AppDelegate는 기존 PetController와 목록의 조절 시작/끝을 연결한다. PetController의 fitOpenThread는 목표만 바꾸고 하나의 placement 계산으로 높이를 τ0.065 추종한다. 긴 글은 펼치기 전 실제 글 높이와 그때 창 높이를 잠시 보유하며, 합산 증가분만 요청하고 접기·수동 조절 때 해제한다. 새 영구 원본은 없다.
검색 강조는 시간 제한 flash와 분리해 해당 스레드 전체에 유지한다. 검색 다시 열기·접기·방 이동으로 해제한다. 기본 머리줄은 2.1판 순서와 단체방 설명, 오른쪽 두 단추 제거·기존 메뉴/단축키를 쓴다. 모드·칩·알림 막대는 기존 SidebarMotion과 같은 easeInOut 0.24다. 얼굴은 기존 ComposerFaces의 같은 전환을 재사용한다. 알약 수는 기존 notices가 스레드당 하나씩 만든 대표 글 수라 추가 원본/카운터 없이 보존한다.

전체 앱 시험의 AT56 옛 단언은 아일랜드 카드 강조를 2.5pt로 기대했다. §0-3 V15가 원문의 accent 테두리2·본문0.18로 검색/알림 막대뿐 아니라 아일랜드 이동도 대체한다고 명시하므로, IslandTests의 그 한 단언을 2pt와 accent 색의 결합 검사로 교체했다. 1.5초·질문 순서·선택·펼침 단언은 유지한다. 이는 26판과 보완 38의 명시적 대체이며 원래 수락 범위를 완화하지 않는다. 실패 실행은 intermediate-old-island-assertion에 따로 보존한다.

원본 비교 캡처는 원문 ChatWorkspace.workspaceHeader·slackNoticeBar·SlackFindView를 분리 실행하고 같은 합성 명부/글 상태를 준다. ImageRenderer의 ScrollView viewport와 TextField는 각각 같은 내용의 정적 틀·글자로 대체한다(원본 파일은 수정하지 않음). 실제 입력/스크롤 상호작용은 제품 native 경로로 검증한다. 처음 색 전환 비교에서 labelColor의 이미 계산한 CGColor가 남는 것을 찾아 검색 상자 appearance/layout에서 다시 계산하게 했다. 원본 막대의 정적 틀은 leading 정렬을 유지한다. 전체 앱 비교나 픽셀 동일 판정은 아니다.

AT-90의 “따라 읽은 스트림이 완료 후에도 펼침” fixture는 여러 스레드를 고른 뒤 새 글을 쌓으면 갱신마다 자동으로 바닥으로 뛰던 옛 NativeThreadList를 암묵적으로 전제했다. TASK-40의 120pt·자리 보존 규칙에서는 읽던 자리가 남는 게 맞으므로, 그 시험의 스트림 시작 전에 실제 native 바닥으로 이동하고 followsAnswer를 단언한다. uniform size·완료 후 펼침 유지·다른 방 스트림 미펼침 기대값은 그대로다. 발견 실행은 intermediate-follow-fixture-position에 보존했다.

검색 강조 접기의 순서도 실제 model.select의 동기 onChange까지 따라 확인했다. 카드 클릭으로 접을 때 강조를 model.select 뒤에 지우면 이미 직전 강조로 refresh한 그림이 남는다. chooseThread에서 강조를 먼저 해제한 뒤 원래 select/refresh를 타도록 했고 AT-91도 추가 refresh 없이 카드 선택 경로로 접어 바로 관찰한다. 별도 전체 검사 중 수정이라 앞 실행은 최종 근거에서 제외했다.

최종 시험 보완: 전체 앱 단위 AT-90·91은 통과했으나 뒤의 rooms 루프백에서 timeout이 발생해 단독 조사했다. 별도 --task40 정상본은 Swift #filePath의 상대 경로가 컴파일/실행 폴더에 따라 달라 펫 자원을 못 찾았다. 시험은 실행 파일 옆 빌드 앱을 먼저 찾고 집중 바이너리의 저장소 루트 실행만 상대 빌드 앱을 쓰게 해 제품 경로를 고치지 않았다. 실패 로그는 intermediate-room-timeout-and-resource-path에 보존한다.

단체방 timeout은 단독 원본 시험으로 세 번 재현했고 단계 로그상 2→19글까지 송수신은 맞으나 글 수와 함께 0.04→5.4초로 증가했다. 실제 프로세스 sample은 notices 정렬·bell·새 활동 비교에서 ThreadTools.date가 ISO formatter/ICU 자료를 매 호출 생성하는 비용을 보여 줬다. 날짜 해석은 fractional 우선→whole→distantPast 그대로 두고 기존 ThreadTools 자리에서 두 parser 자원만 NSLock 아래 재사용한다. 글/날짜 값 캐시나 두 번째 원본은 만들지 않는다. 새 경로의 추가 날짜 비교가 늘린 비용을 원래 계산 자리에서 줄이며, AT-91은 기존 파서 참조와 fractional/whole/offset/실패 결과를 100개 동시 호출로 대조한다. 8초/90초 기준은 바꾸지 않는다. sample·단독 단계 로그는 로컬 task40에 보존했다.


## TASK-41 원본 독해·책임 배치

- §F·V08·V10·V14와 2.1판 F05·F06·F20~F25, design §12, 보완 56을 대조했다. `App.swift`의 클릭·말풍선 선택·여닫기·폭 전환·배치·두 끌기 경로와 `PetView.swift`의 키 처리·유리·그리기·알림·행동·커서 함수 및 `PetLayout`·`PetAnimation`·`PetPointerInteraction`·`BubbleReveal`·`PetIdentity`·`BubbleOpacity` 의존을 읽었다.
- 기존 `PetController`의 단일 배치·로컬 크기/위치, `PetView`·`BubbleReveal`의 표시 상태, 기존 ConversationView 선택·초안과 편집 메뉴 자리를 확장한다. 새 영구 원본·wire·문 변경 없음.
- 원본 새 답 내용은 12초 유지하지만 표면의 자동 튀어나옴은 3초다. 승인 대기는 계속 유지하고 작성 중 단추는 없으며, 실패 말풍선은 없다. F06의 평소 사용량 부제는 제외하고 첫 머리글 조사와 평소/졸기/쉬기 문구만 옮긴다. F08은 홈에서만 행동한다. 클립보드·FileDrop·사용량·프로젝트 전용 경로는 사장 선택대로 제외한다.
- N40-01은 공용 검색 강조 함수의 systemYellow와 AT-91 실제 색 단언으로 처리한다.

실제 이식·회귀 대조:

- F01~03·F20~24: 첫 클릭만 처리, `dragged(by:)` 머리줄 이동과 높이를 바꾸는 펫 끌기는 구별했다. 공유 resizeRegions에 원본 대각선 커서를 연결하고 첫 클릭 focus, 조합 Esc, 다른 앱 창은 보지 않는 로컬 더블클릭·파일 선택 보호, 접기 때 검색/카드/대상 정리·화면 변경 고정 해제를 연결했다.
- F04~06·F25: 원본 유리·0.35 덮개·20pt 모서리와 생각 점 0.5 덮개/0.18 테두리를 쓴다. 별도 새 답 표면 기한 3초와 기존 내용 12초를 분리했다. 승인만 held, 승인·작성 중 actions는 비우며 실패 알림 분기는 제거했다. 실패한 인라인 답의 기존 대상·초안·오류 줄은 유지한다. 얼굴 뒤 간격 8, 머리글 labelColor, 단추 바탕 0.12/둥근 12, 반짝임은 끼어든 스레드가 다시 작성할 때만 1/24초 단계다.
- F07~18: 원본 dragAnimation·dozeZs·ChatPetBehavior·PetBubbleMotion·ChatWidthSlide를 옮겼다. 기존 높이 추종은 같은 size follower에 합쳐 두 번 완화하지 않는다. 지니 캡처는 원본의 둥근 바탕 합성과 CoreImage 축소 흐림을 연결하고 반전 때 현재 progress를 유지한다. 폭 변화는 0.3 smoothstep, 덮개는 끝 0.06초다. 완료 배치와 추종 크기를 맞춰 다음 폭 전환이 예전 접힌 크기에서 시작하지 않게 했다.
- V08이 명시적으로 대체한 두 이전 '열 때 키 창 아님' 단정은 작성기 키 창으로 바꿨다. AT-62의 합성 새 답에는 실제 생산자처럼 id를 줬고 홈 보내기 동작 시험에는 home 조건을 명시했다. 이전 편집 메뉴 '다시 실행'은 원문 '실행 복귀'로 갱신했다. failure 말풍선 우선 단정은 작성 중 표시·실패 말풍선 없음으로 바꿨고, 일반 작성 중 반짝임은 interrupted 상태에서만 단언한다. 전송·첨부·초안·다시 알림 저장·12초 내용·조합·실패한 인라인 답의 단언은 보존했다.
- AT-91의 높이 시험은 목표 사각형 대신 실제 보이는 배치에서 같은 수치·중간/끝 값을 읽는다. 동작 줄이기를 바꾸면 배치 단계에서도 남은 움직임을 즉시 끝낸다. N40-01 공용 검색 강조색을 systemYellow로 바꾸고 실제 속성 색을 단언했다.
- 화면 증거는 동일 합성 상태를 주입한 원본 BubbleTextView와 실제 AppKit FoldedBubbleView의 조립 비교다. 원본 전체 앱/실제 서버 실행을 주장하지 않는다. native 유리 생성·가짜 명부·정적 캔버스만 보조하며 원본 그리기·레이아웃/행동·추종 함수는 별도로 컴파일한다.

- 최종 회귀 AT-78도 공용 검색 강조를 직접 검사해 이전 `.yellow` 단정을 `.systemYellow`로 갱신했다. N40-01의 명시적 전체 호출처 색 변경이며 검은 글자 단언은 유지했다.
- `App.swift:2156`은 머리줄을 끄는 동안 일반 재배치를 보류한다. 같은 책임 자리에 가드를 넣고, 새 답 높이가 들어와도 끌던 배치가 바뀌지 않는 AT-92를 더했다.

- F15의 숨김 억제 이후, 창을 다시 보이는 순간에는 새 타이머를 기다리지 않고 표시 상태를 갱신한다. PetPanel의 orderFront/orderOut 수명 자리에 연결했다. 기존 AT-82의 0.3초 hover·포커스 없음 단언은 수정하지 않고 검증한다.

- AT-81 배지/생각 점 숨김 시험의 고정 시계는 마지막 숨김 검사 전에 새 3초 표면 기한을 넘긴다. 기존 12초 내용 기한 단언은 그대로이며, AT-92가 두 시간을 따로 검사한다. 원본 reveal은 notice 종류가 바뀌어도 3초 기한 자체를 없애지 않는다.

## TASK-42 원본 독해·배치

- 기준: 보완 38·42, 대조표 §G·V11 및 2.1판 G04·G09·G11~G13. App.swift의 buildMenu, refreshThreeTapSettings/copyThreeTapRequest, makeSyncStandard, showOptions 전체와 SettingsPages.make, OptionsLayout, PetIdentity, LoginLaunchPresentation을 읽었다. preview/previewPointer와 PetView의 previewRow/previewLook 소비, SlackSettingsSync.syncSettings/receiveSynced 및 실제 상태 송신 경로를 대조했다.
- G01~G07: 기존 PetSettingsWindow에서 원본의 스크롤 블록·620 폭·화면 여백 16·내용 640, 원문 검사/로그인 상태, 9개 동작+방향 2개+졸기·15초 시선, 실패 때만 요청문 복사를 연결한다. 이름 기본값만 사장 선택의 hejo다. Slack 전용 연결 안내·제외 탭·사용량은 옮기지 않는다. 모양 편집 내용은 TASK-43 책임이다.
- G08·G11~G13: AppDelegate의 기존 메뉴/쉬기/연결 창 책임을 확장한다. 작업 목록·캘린더 항목 자리는 후속 TASK가 채운다. 기존 홈 설정 layout:home을 고정 채널 팝업에서도 쓴다.
- V11/G09: 옛 표의 ‘1.5초 받기’보다 2.1판과 design §12를 우선한다. MemberState의 영구 복제본·outbox는 유지하고 송신 1.5초 묶음, 새 허브 25초 대기 GET, 옛 허브 30초 받기를 구분한다. 서버의 기존 since GET/PATCH와 회원 격리는 유지한다.

- G04 대체 근거: 기존의 빈 이름을 기본값으로 바꾸기/20자로 자르기를 지우고 원본 PetIdentity.validationMessage의 세 오류와 NFC·안쪽 공백 묶기를 사용한다. 과거 ‘조용히 자름’ 단정과 설정 네 탭·메뉴 열 항목 단정만 이번 승인된 대체에 맞췄다. 옛 허브의 30초 받기 단정은 그대로 둔다. LoginLaunchPresentation은 이미 원본과 같아 재작성하지 않는다.
- G07 원본 PetView: 방향 보기 열은 0.25초마다 8칸을 순회한다. 동작 아홉 개는 각 2초, 졸기만 dozeCycle이며 시선 보기 15초다. 기존 PetController/PetView에 일시적 미리보기 상태만 추가했다.
- G09: 헤더 X-Hejo-State-Wait=1로 새 허브 지원을 확인한다. 옛 허브는 wait 쿼리를 무시해 기존 전체 상태를 돌려주므로 이를 한 번 받아들이고 30초 받기로 남는다. 새로운 영구 설정·상태 키는 없다. 대기 응답과 PATCH 순서가 뒤집혀도 더 낮은 rev를 적용하지 않는다.
- G12: 문 인증·핑·기록 캐시 경로는 계속 돌고 ConversationController의 화면 전달만 일시 큐로 멈춘다. 쉬는 동안 작업/타이핑 만료 소비도 멈추며 재개 때 원래 receive 경로로 차례대로 전달한다. 운영 재시작을 실행하는 기능이 아니다.

## TASK-43 원본 독해·배치

- 기준: 보완 38·57, 대조표 H01 및 2.1판 H01 정정, REQ-HF-38·AT-94. ddots SettingsPages의 AppearancePreview·AppearanceSwatch·AppearanceSection·ChatAppearanceControls 전체, ChatStyle의 ChatTheme/ChatAppearance·UserBubbleColor/Palette·ChatMetrics, BubbleOpacity 전체와 App의 changeChatTheme/changeChatOpacity·showOptions 연결을 읽었다. NativeThreadInputsCache의 appearanceRevision, PetView.updateScrim 소비와 hejo NativeThreadList.remeasure·ConversationView의 실제 본문/작성기 생성도 대조했다.
- 모양 값의 원본은 기존 LocalStore의 hejo-local.json이다. 원본의 전역 UserDefaults 투영은 hejo의 단일 LocalStore 읽기로 연결하고 허브 회원 설정/상태에는 보내지 않는다. 원본 색·단계·클램프 계산은 유지한다. 설정 조립의 SwiftUI 미리보기만 AppKit으로 옮긴다. H01 정정대로 쓰이지 않는 불투명도 양 끝 문구는 넣지 않는다.
- N42-01은 기존 허브 member_state의 Event를 요청별 Future 집합으로 대체한다. 읽기 전 등록, PATCH 전체 깨우기, 취소/완료 정리와 기존 HTTP 계약을 유지한다.
- 원본 위치: `SettingsPages.swift:132-254`의 묶음·원·두 줄 배치·미리보기 확장과 `ChatStyle.swift:4-137`의 테마/7단계/14색, `BubbleOpacity`의 55~100·기본 65·접힘 0.35 계산을 대조했다. 색 대비 계산은 기존 ChatStyle의 같은 원본을 재사용했다. 설정 창 자체는 macOS 모양을 따르고 선택한 테마는 미리보기·펫 패널·연결 창에 적용한다.
- `ConversationView`는 마지막으로 그린 기본 글씨 크기를 기억해 초안을 직렬화한다. 기본 크기를 바꾼 뒤 예전 크기를 명시적 서식으로 저장하는 것을 막고, 조합 중에는 표시 글을 바꾸지 않는다. `NativeThreadList`는 모양 revision 때 보류된 내용을 폐기하고 기존 카드 높이를 다시 계산한다. 창 소유자가 모양 변경 알림을 구독하고 해제한다. 영구 원본이나 별도 복제 설정은 없다.
- N42-01 회귀는 앞 대기를 await 직전 붙잡고 PATCH·뒤 대기 등록을 겹친다. 옛 Event 구현을 임시 사본에 되돌리면 1초 단언이 실패하고, 요청별 Future 구현은 새 rev를 즉시 받는다. 운영 허브나 회원 자료는 사용하지 않는다.

## TASK-44 원본 독해·배치

- H02/H02+: `SlackFiles.swift` 전체(SlackFileStore·SlackOutgoingFile·문제 문구), `SlackController.open/show`(1433~1488), 보내기 큐·완료 처리(1518~1575)와 호출을 읽었다. 이름 정리는 경로 구분자·NUL·개행 치환, 앞 점 치환, ID의 ASCII 영숫자만 유지, 200바이트 안에서 16바이트 이하 확장자 보존이다. 받은 이름은 글 날짜 분 단위와 파일 ID, 보낸 사본은 ID 없이 같은 내용 재사용/다른 내용 2~99 번호다. Downloads 안의 원본은 그대로 둔다.
- 기존 GateHTTP가 파일 수신·캐시/사용자 다운로드 사본을, ConversationController가 사장 열기·송신 확인 뒤 사본 보관을 맡는다. 그림 미리보기의 download는 캐시만 쓴다. 새 영구 설정·색인·기록장은 없다. 파일 ID/글 날짜는 기존 기록에서 읽는다. 저장된 사본 재사용도 기존 기록의 직원/파일 범위를 확인한다.
- 원본의 Slack 전용 200MB·보관하지 않기·별도 ddots 기록장 경로는 옮기지 않는다. hejo의 50MiB·권한/크기 확인·기록장 삭제/캐시 정리는 유지한다. 원본은 받은 파일 저장 실패 때 안내만 표시하지만 이번 직접 지시가 캐시로 열기를 명시하므로 원본 `파일을 저장하지 못했어요. …` 문구와 함께 캐시를 연다. 보낸 사본 실패를 보내기 실패로 바꾸지 않는 원문 동작은 유지한다.
- 받은 글 날짜는 기존 ThreadTools.date의 소수 초/일반 ISO 파서를 쓴다. 재열기는 출입증 요청 구성·직원/파일 메타데이터·삭제되지 않은 기존 캐시 기록을 확인한 뒤 사용자 사본을 연다. 썸네일은 캐시에만 쓰며 사용자 폴더를 만들지 않는다. 다운로드 중 범위가 지워졌으면 사용자 사본 출판도 거절한다.
- 보낸 사본은 WebSocket 쓰기 완료가 아니라 기존 client_msg_id 송신 확인 때 보관한다. 원본 보내기 큐처럼 전용 직렬 큐가 이름 충돌을 처리한다. 같은 파일의 진행 중 열기 누름은 원본 busyFiles처럼 한 번만 받는다. 테스트의 실제 파일 송수신 경로는 다운로드 위치를 명시적으로 임시 홈 안에 주입했다. 새 영구 색인·기록은 없다.
- 원본 I/O와 제품 I/O의 같은 입력 비교 결과는 evidence/HEJO-FOUNDATION/task44-files.json이다. 화면을 바꾸지 않는 변경이므로 원본·제품 화면 사진 대신 이름·본문 바이트를 비교했다. ID를 빼는 임시 변형은 이 원본 실행 비교가 검출했다.


## TASK-45 원본 독해·책임 배치

- WebPane.swift 전체(1–524), WebAddress.swift(1–40), WebPicture.swift(1–102), WebTabBlank.swift(1–69)를 읽었다. WebPaneModel의 탭·웹 요청·다운로드·새 창·실패·대화상자·권한 거절과 WebPicture의 스냅샷/흐림/재사용을 함께 이식한다. 원본 SwiftUI 페이지·탭/주소 줄은 WebPaneView의 AppKit 부품으로 바꾼다. 기존 WebSmoke는 탐색·다운로드·포커스·그림 전환 시험의 참고로 읽었다.
- App.swift:839–945의 링크/파일 경로·폭 나눔·그림 전환, PetLayout.swift:91–114의 720pt/280pt/240pt/화면 폭 배분과 App.swift:988의 기존 대화 폭 보존을 PetController/PetLayout에 연결한다. PetView.swift:899–976의 흐린 그림은 기존 폭 전환 덮개에 둔다. 영구 값/기록 원본을 추가하지 않는다.
- WebPane.swift:282–283의 13번째 탭은 가장 오래된 탭을 비운다. 대화 링크의 ⌘는 브라우저지만 웹 페이지 안 ⌘ 링크는 원본 320–325처럼 배경 탭이다. 검색어는 WebAddress가 검색 URL만 만들며 시험에서는 가져오지 않는다.
- 문 첨부는 기존 ConversationController/GateHTTP가 출입증으로 받아 로컬 파일 URL을 넘긴다. WebPane은 GateClient를 모르며 URLRequest에 출입증을 넣지 않는다. 로컬 첨부의 WKWebsiteDataStore는 별도 nonPersistent다. Info.plist의 기존 ATS 설정은 바꾸지 않는다.
- N44-01은 모든 앱 시험 Controller를 TestMain의 testConversation 생성 함수로 모아 임시 LocalStore 아래 Downloads를 주입한다. 앱 전체 시험 진입점은 실제 다운로드 폴더의 이름 목록만 시작/끝 비교하고 이름·내용을 출력하지 않는다.

- 원본 실행에서 첫 웹 탐색이 전송 오류로 끝나면 `tab.url == nil`이며 원래 밖에서 열기 제어는 목적지가 없어 비활성이다(WebPane.swift:235–239·514–516). 실패 안내는 보이고 칸/대화는 남는다. AT-96의 “오류 + 밖에서 열기”는 원본에 있는 제어를 유지한다는 뜻으로 시험하며, 실패한 요청 주소를 임의로 새 영구/임시 원본으로 더하지 않는다. 원본 분리 실행 근거: 로컬 `original-failure-boundary.json`(failureNotice=true, externalCount=0, paneStillOpen=true). 원본과 달리 실패 주소를 밖에서 열게 하는 제품 변경은 이번에 하지 않는다(26판 코드 우선).
- App.swift:290–291·947–952의 Mac별 웹 칸 폭/높이 저장은 기존 hejo-local.json의 창 크기 값 옆에 둔다. 탭·페이지·그림 수명은 WebPaneModel/WKWebsiteDataStore가 맡는다.

- 원본 WebSurface는 ready가 꺼지면 SwiftUI가 보기를 제거한다(WebPane.swift:442–443). AppKit의 영구 holder는 clear에서 페이지·그림을 제거해 같은 수명을 지킨다. 최종 시험은 닫힌 뒤 WKWebView의 약한 참조가 nil임을 확인한다.
- 최종 AppKit 대조에서 주소칸 왼쪽 약 20pt·글자 기준선 약 5pt와 페이지 왼쪽 선의 1pt 배치 차이를 확인해 화면 문서에 남겼다. 픽셀 일치를 주장하지 않으며 테마·제어 순서·문구·동작과 페이지 표시를 비교한다.

- 최종 서식 검사에서 WebPane.swift 끝의 빈 줄 한 개만 제거했다. 시험 당시 지문과 원본 바이트는 로컬 자료에 보존했고 `시험 바이트 = 최종 바이트 + LF 1개`를 단언한다. 나머지 검증 입력은 바이트가 같다. 실행 코드 변경은 없다.


## TASK-46 원본 독해·배치

- 기준: 보완 38·59, REQ-HF-40/AT-97, H04·H04+. 착수 main 985d9d8이며 TASK-45 제품과 판정 문서를 대조했다. `MacCalendar.swift` 211줄·`CalendarMatch.swift` 96줄 전체를 읽었다(원본 저장소 c85c905). EventKit 공급자의 권한/조회·직렬 큐·세대·월 추가 조회·선택 재조회와 SwiftUI 창 전체를 포함한다. `Conversation.swift` 448줄의 기존 독해를 바탕으로 PetAction.content/bubble(294~328)·PetActionMemo(428~448)를 다시 대조했다. App의 생성·시작/주기/활성화 refresh·onChange·showCalendar/presentCalendar·showRelated 호출, SlackPanel.calendarButtons와 NativeThreadContent의 부속 단추 자리, CalendarTests 전체와 Info.plist의 두 문구를 확인했다.
- 칸: CalendarMatch는 순수 날짜/실제 일정 판정, MacCalendar는 이 Mac EventKit의 일시 값 조회만 맡는다. 기존 ConversationController의 화면 투영과 BubbleReveal.Action에 같은 일정 값을 전달하고 기존 AppDelegate가 창을 소유한다. MacCalendarView는 SwiftUI 대신 AppKit 창·목록·상세다. 일정은 LocalStore/문/허브/기록장에 저장하지 않는다. 읽기 공급자 계약에는 쓰기 메서드가 없다. 시스템 설정 열기 URL은 원본 그대로이며 시험에서는 실행하지 않는다.
- 원본 개인 reverse-domain 큐 이름은 중립 `hejo.calendar`로 바꿨다. 원본 SwiftUI/ObservableObject의 화면 발행은 AppKit onPresentation으로 대체하고 EventKit 순서·계산·문구는 보존한다. 캘린더 창 제목의 앱 이름만 hejo로 바꾼다. 원본의 다른 채널 기능 제한은 hejo 메뉴를 숨기는 데 쓰지 않는다(이번 요구가 이 Mac 캘린더를 명시).
- 날짜는 수신 글 날짜가 기준이다. 원본은 단순 날짜만으로 일정을 발명하지 않는다. 일반 낱말 '회의' 자체는 제외하며 구체적인 제목 또는 날짜+장소가 맞아야 한다. AT-97의 '내일 3시 회의'는 실제 '3시 회의' 일정과 대조한다. '다음 주'는 날짜 7개로 해석되지만 실제 제목/장소가 없으면 단추가 생기지 않는다. 같은 반복 일정도 시작 시각·캘린더 식별자를 포함한 id로 구별하고 누를 때 다시 읽는다.
- N45-01: 이전에 전체 독해한 WebPane.swift 524줄 중 주소줄(495~518)과 overlay(445)를 다시 읽고, 수정하지 않은 원본을 분리 실행했다. 720폭에서 네 탐색 단추는 x=12/30/48/690, 주소 글자 칸은 (78,52,596,15), 아래 기준선 간격 3pt다. 주소 바탕은 10pt/5pt 여백으로 (68,47,616,25)다. 원본의 왼쪽 1pt 선은 페이지 폭을 줄이지 않는 overlay라 그대로 두고 본문 x=0으로 바꾼다. AppKit 셀 가운데 정렬과 필드 편집 위치를 함께 맞추고 AT-96에 측정 단언을 더한다. 원본 화면은 읽기 전용이며 운영 앱을 실행하지 않는다.

- 말풍선에서 '대화 열기'를 빼는 조건은 일정 수가 아니라 내용 단추 수가 둘일 때다. 원본 `Conversation.swift:323-327`·REQ-HF-40의 구체 문장대로 링크+일정 단추가 함께 있으면 뺀다. 일정 여러 개는 '관련 일정 N개' 한 단추로 묶어 선택 창을 연다. 새 의미를 만들지 않는다.
- N45-01의 셀 배치 사각형뿐 아니라 실제 그려진 주소 글자도 단언한다. 수정하지 않은 원본 1배 캡처의 잉크 경계는 x=81·위=55·아래=65다. AppKit 셀의 그리기/편집에 안쪽 여백을 다시 더하던 경로를 제거하고 drawingRect 한 곳만 둔다. 한글 입력 상태의 ⌘T/⌘W와 주소칸 편집 회귀도 계속 검사한다.

- 최종 캡처의 월 제목 잉크 경계가 원본 y=65~75, 제품 y=62~72라 3pt 차이를 측정했다. AppKit 월 제목 칸을 y=62로 옮겨 잉크 경계를 맞췄다. 변경 전 통과 근거는 intermediate-before-month-baseline에 보존하고 최종 입력으로 전체 검사를 다시 한다.

- `SlackPanel.swift:3474-3479`의 .bordered/.small 단추와 NativeThreadContent:83-86의 왼쪽 43/위 2 여백을 분리 실행해 한 항목의 fittingSize=(105,22), 단추=(62,20)을 확인했다. 기존 MessageAccessory에 top=2·전체 높이 22를 연결하고 같은 측정 단언을 추가했다. 임의의 30pt 행 높이는 제거했다.

- 목록의 긴 제목은 원본에 lineLimit가 없으므로 자르지 않는다. 원본 VStack(행 간격 4·padding 10·body/headline/caption)을 폭 360에서 실행한 높이는 보통 73·긴 합성 제목 105다. 글 높이로 행과 스크롤 문서를 계산하고 행 사이 6을 유지한다. 권한 안내도 내용 높이에 14를 더해 다음 단추를 배치하고, 단추 크기는 원본과 같은 기본 AppKit intrinsicContentSize를 쓴다. 이 보완 전 검증은 intermediate-before-calendar-row-sizing에 보존했다.

- 네이티브 글의 일정 부속 줄은 NativeThreadContent:83-86/PetActionMemo:437-445대로 사장 글·pending만 제외한다. SlackPanel의 SwiftUI line에만 있던 streaming 억제를 네이티브 소비자에 더하지 않는다. 글을 계속 작성 중이어도 이미 도착한 날짜/제목과 실제 일정이 맞으면 부속 단추가 남는 회귀를 더했다.

- 원본 @Published month는 조회 중에도 즉시 발행한다. AppKit moveMonth도 완료를 기다리지 않고 화면 알림을 내며, 이전 조회가 진행 중인 채 다음 달을 누르는 단언을 더했다. 원본의 세대 검사·추가 조회 순서는 바꾸지 않았다.


## TASK-47 — H05·H05+ 독해와 책임 배치

- 원본 전체 독해: Dashboard.swift(1–127), Monitor.swift(1–114), HookBridge.swift(1–59), TranscriptDecoder.swift(1–192), ScreenFocus.swift(1–83), ComputerUseActivity.swift(1–42), ScreenWindowResolver.swift(전체), Models.swift·PetIdentity.swift(전체), scripts/configure_hooks.py(1–56), Tests/test_hooks.py·CoreTests.swift, Resources/연결안내.html. 호출부 App.swift의 진입점·2초 갱신·apply/updatePet·Dashboard 창·showHooksHelp와 PetView 시선 분기도 확인했다.
- 관제 화면 칸: 원본 세션은 읽기만, 기존 PetState에 rank를 더하고 메타데이터·모니터·훅을 앱에 둔다. AppDelegate가 감시와 목록 창, 기존 BubbleReveal이 우선순위, PetView가 동작·시선을 소유한다. 세션 본문·추론·도구 인자·사용량은 저장하지 않는다.
- 원본값: 세션 발견 15초·훅 폴링 2초, 300초 뒤 unknown, responded 움직임 20초, 파일/상태 하루·서비스당 파일 200개·목록 200개, 꼬리 2MiB·헤더 256KiB. 화면 도구는 최대 32개·60초·결과 뒤 3초, 가장 먼저 시작한 작업의 명확한 창만 바라본다.
- 우선순위: 쉼 → 직원 승인 → 설치 알림 → 외부 작업 승인/최근 60초 오류 → 직원 작성 → 새 답 → 고정/화면/작업 중·최근 응답 → idle. 제외된 FileDrop·연결 제안·사용량은 이식하지 않는다.
- 이름은 hejo·사용자 펫 이름으로 치환한다. 원본 Dashboard의 접근 실패 상세는 ‘기록 폴더에 접근할 수 없음’이다. 연결 제목은 수락 기준의 ‘연결 안 됨’으로 함께 보인다.
- 훅 연결 원본은 create-only다. 기존 설정은 동일한 훅 설정일 때만 통과하고 다른 설정이면 변경 없이 멈춘다. hejo 고유 안전장치인 백업·영수증·바이트 복원·실패 보상을 이 경로에 추가한다. 사장 버튼/명령 실행 때만 설정에 접근한다.
- 실제 CLI 설정 본문은 읽지 않는다. 시험의 실제 설정 보호는 lstat 메타데이터(존재·종류·inode·크기·수정/변경 시각·권한) 지문으로 전후 확인하고, 내용 SHA 검사는 임시 설정에서만 한다. 실제 다운로드는 이름 목록만 비교한다.

- 보완 독해/대조: 기존 PetState·BubbleReveal·PetView·AppDelegate·PetSettingsWindow의 원래 책임에 연결했다. 원본 CoreTests 68개는 별도 실행에서 통과했다. SF Symbol의 ‘30’은 프레임 크기가 아니라 글씨 크기여서 native symbol configuration 30pt의 47×35 자리를 사용한다. 화면/접근 실패 낱말과 AppKit 선택 구획·기본 단추의 차이는 TASK-47 화면 문서에 명시한다.

- 원본 Dashboard의 선택 핀은 프로젝트 글자 바로 뒤의 teal 10pt 그림이다. AppKit에서도 그 자리에 두고, 펫 이름을 바꿀 때 열린 목록 소개·창 제목을 갱신한다. 원본의 Hermes 직접 연결 상세 줄은 이식하지 않는다(hejo 연결 상태는 기존 서버 연결 화면이 소유). 작업/세션 연결 줄 두 개는 원본대로 유지한다. 펼친 홈 행동이 오류 작업 동작을 덮지 않는 회귀도 포함한다.

- 최종 제품·원본의 일반/고정/빈 목록 세 상태를 직접 비교했다. 자동 갱신 때 SwiftUI ForEach처럼 같은 작업의 native 단추 객체를 유지해 포커스/누름이 끊기지 않는다. 원본 CoreTests 분리 68개, 제품 AT-98·전체 앱·훅 9개와 세 번 반복, 실패 보상 제거 돌연변이 검출 근거는 impl-report와 `.build/task47/`에 있다. 실제 CLI 설정 내용은 읽지 않았고 실물 수락은 남겼다.


## 보완 60 — N47-01·02

- 바뀐 계약: AT-98의 ‘연결 안 됨’은 계획 담당의 잘못된 문구로 정정됐다. 원본 Monitor.swift:46과 Dashboard.swift:85–87을 다시 읽었고, 제품의 앞붙임을 제거한다. 기존 TASK-47 독해/실행 기록은 당시 기록으로 보존한다. 가용 여부는 점의 teal/gray만으로 보이고 detail을 그대로 그린다.
- Dashboard.swift:98–109의 아래 단추 구성과 font 상속을 다시 대조했다. 원본과 같은 SwiftUI 단추 구성을 별도 실행한 실측: 새로고침 69×24, 동작 미리보기 96×24, 승인 알림 연결 안내 125×24pt. AppKit 기본 rounded 단추에 13pt를 쓰면 세 크기가 모두 일치한다. AT-98 앱 시험에 독립 실측값 단언을 더한다.
- 수정 범위는 Dashboard와 관련 앱 시험·보고·동일 상태 캡처뿐이다. 감시·훅·문·허브·기록장·로컬 저장 계약은 바꾸지 않는다.

- 보완 뒤 일반/고정/빈 목록을 같은 상태로 재캡처해 직접 비교했다. detail 원문과 세 단추의 13pt·24pt 표시를 확인했고, 나머지 기본 제어 외관 차이는 기존 화면 문서대로다. 실행·서명·메타데이터 보호 결과는 impl-report의 보완 60 최종 검증과 `.build/n47/`에 있다.


## TASK-50 — 사장 대화 판정과 플랫폼 전용 경계

- 보완 62/D50-01에 따라 운영 원본은 읽기만 하고 임시 사본에서 작업했다. 생성 캐시를 제외한 658개 파일/상대 링크의 본문·권한·대상을 시작 때 대조했다. TASK-49의 install_hejo가 포함된 원본을 기준으로 한다.
- 비시험 Python·shell·JS·Swift를 조사했다. 집합/튜플/목록/사전 47곳과 단일 플랫폼·SQL 문자열까지 원본 기준 146행의 파일:줄·뜻·처분을 `.build/task50/classification.md`에 기록했다. 루트 별칭 링크와 lib 실제 파일은 중복 수정하지 않는다.
- 바꾼 것은 사장 대화/기록 원본을 고르는 26개 표현식이다. 경량 공용 모듈 hermes_owner_chat의 OWNER_CHAT_PLATFORMS에 slack·photon·hejo를 두고, 배경·계정·역할·요청 원문 검사는 각 기존 책임 자리에 남겼다. pending route의 기존 bluebubbles만 별도 합집합으로 보존한다. SQL IN도 같은 상수의 값과 자리표시자로 묶는다. CHANNEL_LABEL·라우터 ingress·사용량·연결 인증·설정 조립·재시작 경로는 바꾸지 않는다.
- hejo의 쓰기 소유자 확인은 문이 보증하는 user_id=owner를 쓴다. forwarder 프로필에는 별도 api_human_users가 없으므로 Slack 설정 키를 요구하지 않는다. 기존 Slack/iMessage 설정 소유자 검증과 배경·빈 대화 거절은 그대로다. 전송 태그를 고르는 함수는 그 자체로 소유권 증명이 아니며 기존 호출자의 역할·범위·배경 검사를 대체하지 않는다.
- D50-02: wait_jobs의 Slack 채널/스레드 정규식, 원문 증명/선택·workspace·관리 학습, Slack 블록 승인, Notion 되돌림 문맥 등의 경계는 이번 패치로 풀지 않았다. 실제 hejo 가짜 입력에서 wait_jobs=owner_slack_thread_required, 원문 증명=not_slack, 백업 승인 runner 호출 0, Notion conversation=None을 확인했다. 상세·추가 후보는 분류표와 `.build/task50/d50-02.json`이다.
- 실제 메일 읽기·발송과 운영 적용은 하지 않았다. 바뀐 판정은 실제 함수를 호출하는 194개 집중 경우로 검사했고, 실행 줄 추적으로 공용 집합을 소비하는 모든 위치를 확인했다. 결과와 패치 지문은 impl-report 및 `.build/task50/` 근거를 따른다.

## TASK-52 — 보완 64 원문 증명·인증 경계

- 기준 b6d4e23dd11182a29cc81f88a6286979729e14c7. TASK-51 조사는 당시 이력으로 보존한다. 문 원문은 기존 Journal이 원본이며 읽기 전용 owner_message만 공개했다. 전달된 profile·chat·thread·msg_id와 role=owner·실제 방 수신자를 검사한다. forwarder는 기본 문으로 가되 자기 profile로 고정한다. source.message_id에 문 UUID를 넣고 scope_id는 만들지 않았다. wire·새 영구 원본·공개 가지 변경은 없다.
- team-kit은 운영 원본 660항목의 본문·모드·링크 대조가 같은 임시 사본에서만 고쳤다. 공용 인증의 legacy_owner 콜백은 각 호출자의 기존 Slack/photon 증명을 그대로 받는다. 업무 안내의 learning.owners, 메일의 configured api_human_users, workspace의 video_job owner 비교를 보존했다. 원래 별도 owner 목록을 검사하지 않던 Notion·선택 스킬에 새 목록을 추정해 넣지는 않았다. 각 호출자가 원래 허용하던 legacy 플랫폼·역할·경로·심링크·승인·flag 처리는 남기고 hejo는 정확한 owner와 chat, 배경 거절을 공용 함수에서 검사한다.
- 공용 원문 공급자는 install_hejo의 현재 adapter/event/loop 결합과 task-local 환경을 대조한 뒤 공개 owner_message만 호출한다. 같은 루프에서 동기적으로 기다리거나 옛 문에 메서드가 없거나 조회가 실패하면 None이다. DB content·모델 인자·Slack 헤더 모양·저장된 문맥은 대체 근거가 아니다. 학습은 검증된 원문을 쓰고, 기존 도구 결과 순서 비교에 필요한 숫자 messages.id만 동일 사건의 platform_message_id로 읽는다. 문 UUID를 DB 행 번호처럼 비교하지 않으며 이 메타데이터는 원문 증명 원본이 아니다.
- request_source의 프로젝트 영수증 생산·채널·scope 규칙은 Slack 전용으로 보존했다. hejo 일반 원문과 섞거나 별도 프로젝트 저장소를 만들지 않았다. hejo steer/redirect는 검증된 사건에 결합되지 않아 근거를 공급하지 않는다. 단순 승인 글 학습·배경 학습은 계속 거절한다. 학습 보고 전송 위치는 바꾸지 않았다.
- TASK-53 메모: linked_work의 선택 대상과 Decimal ts 비교, diagnosis_records의 Slack DM/permalink, wait_jobs의 Slack 정규식·origin 예약 전달은 그대로다. linked_work·diagnosis의 명시적 플랫폼 제한과 wait_jobs.create의 Slack 형식 제한은 남아 있다. 다만 wait_jobs.handle의 list/cancel·prune은 공통 learning.source에만 사장 증명을 맡기므로, 이번 확장으로 hejo owner가 그 입구를 통과할 수 있다는 코드상 영향은 TASK-53에서 확인해야 한다(이번 실물 실행 없음). 현재 owner_context의 hejo 선택 결과 row_id는 None으로 두어 기존 DB 본문 기반 대상 추정을 사용하지 않는다. 임의 클릭 대상의 직원 글은 first_thread_message만으로 조회할 수 없으므로 answer_to의 대상 내용 증명도 TASK-53에서 별도 설계해야 한다. 금고 백업 승인·CCTV 지정 방·Slack 사용량 조회도 D51-01대로 유지한다.
- 검증 원본은 .build/task52/의 focused.log·full.log·final-foundation.log·integration.log·mutations.json·airport.log·patch-result.json이다. 가짜 DB의 위조 Slack 헤더와 문 원문을 다르게 두어 원문 공급자 교체 변형이 검출되게 했다. 운영 본문·비밀·실제 발송·재시작을 시험하지 않았다. 새 권한 경계의 운영 수준 3과 비설계자 검토는 남는다.


## TASK-53 원문·실행 경계 독해 — 보완 66

- 기준 3305387ba0067da9f9b992d6d69e0d5e426cd8f3. TASK-52 패치를 적용한 임시 team-kit을 원본으로 삼았다. 칸은 기존 문 기록장 조회와 team-kit의 linked_work·diagnosis_records·wait_jobs다. 영구 원문·wire·권한 원본을 추가하지 않는다.
- 문 employee_message는 owner_message와 같은 공개 비동기 방식이며, 살아 있는 직원 글을 작성 직원·chat·thread·msg_id로 한정한다. 전달자는 자기 직원으로 고정한다. team-kit answered_employee_message는 TASK-52의 현재 사장 사건 증명과 answer_to를 결합하고 응답의 직원·대화·스레드·ID를 재대조한다. 세션 DB 본문이나 가장 최근 직원 글로 대체하지 않는다.
- 업무 캡처는 hejo에서 고른 사건 원문과 검증된 답 대상만 사용한다. Slack의 _answered_message DB 문맥·Decimal 메시지 시각 경로는 Slack 쪽에 남긴다. hejo 업무 전환의 중복 판정은 사건 ID, 순서 판정은 공개 owner_message의 실제 기록 시각을 쓰고 UUID를 숫자나 시각으로 해석하지 않는다. 기존 단계별 실행·미확정 쓰기 보류·원문 할 일 근거는 유지한다.
- 진단 기록은 hejo 원문 공급자를 먼저 확인하며 Slack permalink로 가장한 글도 hejo 출처만 남긴다. Slack의 세션 종류 검사와 permalink 추출은 기존 경로에 남긴다. hejo 기록에는 platform·chat_id·thread_id·msg_id를 쓰고 Slack ts 필드는 비워 둔다.
- 대기 작업은 hejo 현재 원문·실제 직원 홈을 확인한 뒤 origin의 platform·profile·chat·thread를 보존한다. Slack 채널·ts 정규식은 Slack 갈래 그대로다. hejo list/cancel·prune은 같은 origin만 다루고 다른 대화·직원 작업은 제외하거나 거절한다. 기존 profile별 cron 저장소와 deliver=origin을 재사용하며 다른 플랫폼 대체를 추가하지 않는다.
- 본체 cron/scheduler_delivery.py의 origin 대상 해석·live adapter·standalone 실패 반환을 읽고 가짜 문·Slack 어댑터로 실제 전달 함수를 호출했다. 같은 hejo 대상으로의 기존 standalone 시도와 다른 대상으로 보내는 것은 구별했다. 실패는 cron.jobs.mark_job_run의 last_status=delivery_failed·last_delivery_error로 기록함을 검사한다. scheduler.py의 cron 문맥은 플랫폼·chat 환경을 비우고 HERMES_CRON_SESSION을 설정한다. 조건 조회·예약 실행을 owner로 올리는 코드는 추가하지 않았다.
- 원본 규칙 유지 근거는 기존 업무 캡처·등급 전환 33개 회귀와 team-kit 전체 시험, 새 가짜 사건·통합·세 돌연변이에 둔다. 운영 원문·실제 발송·운영 cron은 실행하지 않는다. 상세 로그·고정 입력과 최종 결과는 .build/task53/final-verification.json을 따른다.


## 보완 67 원인·수정 독해 — N52-02·N34-02

- 착수 기준 8b4e188f40bbab8af9b16a65f09c6e841aa5641e. 운영 team-kit은 이미 TASK-52·53이 적용된 상태이며, 임시 사본의 시작 항목 662개가 검증된 TASK-53 사본과 같았다. 운영 로그 본문·대화·설정 내용은 열지 않고 인계된 오류와 코드 경로를 대조했다.
- 세션 ID 원인: gateway/session_context.py:81-105·173-179는 ContextVar 값을 우선하며 명시적인 빈 값도 os.environ보다 우선한다. AIAgent의 세션 ID와 도구 registry에 넘기는 session_id가 정상이어도 별도 도구 스레드의 환경 값은 비거나 다른 대체값일 수 있다. 실제 gate 수신 → GatewayRunner._set_session_env → agent turn 스레드 → Hermes execute_tool_calls_sequential의 executor → model_tools/registry → 등록된 learning.learn 경로에서 이를 재현했다. 모델 API만 가짜로 만들고 도구 dispatcher·executor·핸들러는 실제 구현을 썼다.
- 수정 전 사본은 같은 시험에서 정상 저장 경우가 Current owner session does not match로 실패했다. 수정본은 현재 사건의 공개 원문을 먼저 확인한 뒤 session_id·role=user·platform_message_id가 일치하는 비압축 행의 id만 읽는다. 본문은 읽지 않는다. 학습·진단·보고 상태와 hejo 기억 문맥이 공용 증명을 사용한다. 기억 문맥은 hejo에서 현재 user 행이 아직 없으면 제공하지 않으며, 이 문맥을 쓰기 승인으로 대신하지 않는다.
- 진행 글 원인: 문 receive는 기본 어댑터의 handle_message로 모든 프로필을 받는다. Hermes run_turn.py:3113-3123·4186-4216는 해당 프로필 전달 어댑터의 delete_message를 확인하고 그 어댑터에 정리를 등록한다. 반면 base.py:4611-4621·4782의 전달 완료는 기본 어댑터에서 pop한다. 예전 보조 어댑터의 콜백 보관함과 달랐다. 문에서 등록·pop을 기본 어댑터의 기존 보관함에 모았으며 세션 키·generation·콜백 연결·오래된 generation 거절은 본체 기본 구현을 그대로 쓴다.
- run_turn_runner.py:111-124는 send/edit 결과의 같은 message_id도 추적한다. 새 회귀는 실제 기본 어댑터의 background 처리·최종 전달·post-delivery fire를 실행하고, 기본/보조 프로필의 진행 글 둘과 편집 결과를 공식 추적 함수에 넣는다. 성공 때 진행 글 삭제·최종 답 유지, 실패 차례의 글 유지, 오래된 generation 미소비를 확인했다. 본체·설정 변경은 없다.
- 현재 운영 원본의 새 패치 dry-run과 임시 사본의 TASK-52→53→N52-02 순서 검사 모두 0이다. 과거 상태 복원·순서 적용은 임시 사본에서만 했다. 운영 원본의 반복 적용·역적용·재시작은 실행하지 않았다. 최종 시험·패치 지문·커밋은 .build/n52-02/final-verification.json을 따른다.
