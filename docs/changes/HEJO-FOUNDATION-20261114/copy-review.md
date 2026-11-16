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
