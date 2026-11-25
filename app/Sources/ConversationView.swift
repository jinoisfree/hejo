import AppKit
import UniformTypeIdentifiers

/// AppKit translation of the reviewed workspace, room strip, card stack and composer.
@MainActor final class ConversationView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSearchFieldDelegate {
    let controller: ConversationController
    let todoDrawer=TodoDrawerView(frame:.zero)
    var drawerShownWidth: CGFloat = 0 {
        didSet {
            guard oldValue != drawerShownWidth else{return}
            todoDrawer.isHidden=drawerShownWidth<=0
            needsLayout=true;needsDisplay=true
        }
    }
    var onToggleDrawer:(()->Void)?
    private(set) var drawerSelectedID:String?
    func setDrawerState(open:Bool,chatExpanded:Bool) {controller.setDrawerState(open:open,chatExpanded:chatExpanded)}
    func selectDrawerCard(_ card:TodoDrawerModel.Card,activate:Bool=true) {
        drawerSelectedID=card.kind == .alert ? nil:card.id
        highlightedMessageID=nil;highlightUntil=nil
        if let id=card.messageID,let key=card.key {
            reveal(key);highlightedMessageID=id;highlightUntil=card.kind == .alert ? islandModel.now.addingTimeInterval(1.5):nil
            if controller.client.store.historyMode {controller.historyLoading.open(key,anchor:id)}
            refresh();history.scrollTo(key.thread)
        } else if activate,let url=card.url {onOpenURL(url);refresh()}
        else {refresh()}  // nowhere to go: the card shows "연결된 대화 없음" and only becomes selected
    }
    let island=IslandView(frame:.zero)
    let islandModel:IslandModel
    /// Animation clock and reduced-motion switch for in-chat typing shimmer; checks inject both.
    var motionTime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var islandTimer:Timer?,streamTimer:Timer?
    private var streamReveal=StreamReveal()
    private var thumbnailAccessIdentity = ""
    private let thumbnails=AttachmentThumbnailCache()
    private var failedThumbnails=Set<String>(),fetchingThumbnails=Set<String>(),busyFiles=Set<String>()
    var clipboardBoard=NSPasteboard.general
    private var copiedID:String?
    private var historyCopyTask:Task<Void,Never>?
    var historyCopyInProgress:Bool {historyCopyTask != nil}
    private var historyCopyKey:ConversationKey?
    private var historyCopyProgress=""
    private var historyCopyGeneration=UUID()
    private(set) var highlightedMessageID:String?
    private var highlightUntil:Date?
    var reconnect:()->Void
    var retrySend:(ConversationKey)->Void
    let employeeTable = EmployeeMenuTable(), history = NativeThreadList(frame:.zero), editor = DraftScrollView(frame:.zero)
    let headerDrag = ConversationHeaderDrag(), brandDrag = ConversationHeaderDrag()
    var onCalendar: (([CalendarEntry]) -> Void)?
    var onOpenURL: (URL) -> Void = { NSWorkspace.shared.open($0) }
    var homePetImage:NSImage?
    private let employeeScroll=EmployeeMenuScroll()
    let employeeSearch=NSSearchField(), search=NSSearchField()
    let searchResults=WorkspaceResults(frame:.zero)
    let noticeBar=WorkspaceDocumentStack(), failureBar=NSStackView()
    let historySearch=HistorySearchState(), historySidebarSearch=HistorySearchState()
    private(set) var searchSelection=0
    private var noticeSecond=0
    private var shownNotices:[RoomNotice]=[]
    private var searchHighlight:String?,searchHighlightThread:ConversationKey?
    private lazy var findRow=WorkspaceFindRow(field:search)
    let noticeScroll=NSScrollView()
    private var workspaceTimer:Timer?,bannerMotion=WorkspaceEase(),chipMotion=WorkspaceEase(),modeMotion=WorkspaceEase()
    private var bannerFraction:CGFloat=0,chipFraction:CGFloat=0
    private var attachmentURLs:[URL]=[]
    private var longReplyBases:[String:CGFloat]=[:]
    private var longReplyWindowBase:CGFloat?
    var isReadingResize=false
    private var enteredPlace=""
    func beginReadingResize(){isReadingResize=true;longReplyBases.removeAll();longReplyWindowBase=nil;history.beginReadingResize()}
    func endReadingResize(){history.endReadingResize();isReadingResize=false;reportOpenHeight()}
    func tickWorkspaceMotion(){
        let now=motionTime();bannerFraction=bannerMotion.value(now);chipFraction=chipMotion.value(now)
        replyButton.selection=modeMotion.value(now);newButton.selection=1-(replyButton.selection ?? 1)
        replyButton.needsDisplay=true;newButton.needsDisplay=true;needsLayout=true
        if ![bannerMotion,chipMotion,modeMotion].contains(where:{$0.pending(now)}) {workspaceTimer?.invalidate();workspaceTimer=nil}
    }
    private func startWorkspaceMotion(){tickWorkspaceMotion();guard workspaceTimer==nil,[bannerMotion,chipMotion,modeMotion].contains(where:{$0.pending(motionTime())}) else{return};let timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.tickWorkspaceMotion()};workspaceTimer=timer;RunLoop.main.add(timer,forMode:.common)}
    private var noticeCursor:[String:Int]=[:]
    private var automatic=false
    private var autoKeys:[String:ConversationKey]=[:]
    private var composerAddress=""
    private var writingKey:ConversationKey?
    private var writingPlace=""
    private var lastPlaces:[String:ConversationKey]=[:]
    private var composerMembers:[String]=[]
    let brand=PassiveLabel(labelWithString:"HEJO."), version=PassiveLabel(labelWithString:"")
    private let handle=SidebarHandle()
    let notice=NSTextField(wrappingLabelWithString:""),noticeIcon=NSImageView()
    private let attachments=NSStackView(), attachmentScroll=NSScrollView()
    private let replyButton=ComposerButton(title:"답글",point:ComposerModeTrack.point), newButton=ComposerButton(title:"새 글",point:ComposerModeTrack.point), attachButton=ComposerButton(title:"첨부",symbol:"plus",point:20,circle:true)
    private let sendButton=ComposerButton(title:"보내기",symbol:"arrow.up",point:21,circle:true), modeBackground=ComposerModeTrack(), inputBackground=NSView()
    private let draftHint=PassiveLabel(labelWithString:"")
    private let formatting=DraftFormatController(), drop=AttachmentDropView(frame:.zero)
    private let clipboard: ClipboardAttachments
    private var rooms:[Room]=[], threads:[ConversationThread]=[]
    private(set) var sidebarRows:[SidebarLayout.Row]=[]
    private var renderedSidebarIDs:[String]=[]
    private var renderedSidebarHeights:[CGFloat]=[]
    private var sidebarRails:[String:CAShapeLayer]=[:]
    private var sidebarUpdating=false
    private lazy var sidebarSearch=SidebarSearchRow(field:employeeSearch)
    private let sidebarBlank=SidebarBlank(frame:.zero)
    private var dropSection:String?
    private let addRoom=FileChip(title:"방 추가"), composerFaces=ComposerFaces(frame:.zero), composerFaceScroll=NSScrollView()
    private lazy var addRow=SidebarAddRow(button:addRoom)
    private static let roomDrag=NSPasteboard.PasteboardType("hejo.sidebar.room")
    private var displayedKey:ConversationKey?, rendering=false, windowed=ThreadWindow(), identity=""
    private var openThread:ConversationKey?, newKeys:[String:ConversationKey]=[:], expandedMessages=Set<String>()
    private(set) var sidebarWidth=ConversationSidebar.width
    private(set) var replyMode=true
    private(set) var pickingFiles=false
    var chooseFiles:(NSOpenPanel,@escaping(NSApplication.ModalResponse)->Void)->Void = {panel,then in panel.begin(completionHandler:then)}
    private var shownSidebarWidth=ConversationSidebar.width, searchOpen=false, editorHeight:CGFloat=17
    var onCollapse:(()->Void)?
    var onOpenThreadHeight: ((CGFloat?) -> Void)?
    private var reportedOpenHeight: CGFloat?
    var onUnread:((Int)->Void)?, onSidebarWidth:((CGFloat)->Void)?
    override var isFlipped:Bool { true }
    var threadTable:NSTableView { history.table }
    init(controller:ConversationController,clipboardArea:URL?=nil,islandModel:IslandModel=IslandModel(),motionTime:@escaping()->Double={ProcessInfo.processInfo.systemUptime}) {
        self.motionTime=motionTime
        self.controller=controller; self.islandModel=islandModel
        reconnect={ controller.client.resume() }; retrySend={ key in Task { await controller.retrySaved(key) } }
        clipboard=ClipboardAttachments(area:clipboardArea ?? ClipboardAttachments.defaultArea)
        super.init(frame:.zero); wantsLayer=true
        employeeTable.headerView=nil; employeeTable.backgroundColor = .clear; employeeTable.style = .plain
        employeeTable.selectionHighlightStyle = .none; employeeTable.focusRingType = .none; employeeTable.intercellSpacing = .zero
        let column=NSTableColumn(identifier:.init("employees")); column.resizingMask = .autoresizingMask; employeeTable.addTableColumn(column)
        employeeTable.dataSource=self; employeeTable.delegate=self
        employeeTable.registerForDraggedTypes([Self.roomDrag]);employeeTable.setDraggingSourceOperationMask(.move,forLocal:true)
        employeeTable.makeMenu = { [weak self] row in self?.employeeMenu(row: row) }
        employeeTable.onBlankDoubleClick={ [weak self] in self?.cycleSidebarWidth() }
        employeeScroll.onBlankDoubleClick={ [weak self] in self?.cycleSidebarWidth() }
        employeeScroll.makeBlankMenu = { [weak self] in self?.blankMenu() }
        employeeScroll.automaticallyAdjustsContentInsets=false;employeeScroll.contentInsets=NSEdgeInsets(top:4,left:0,bottom:0,right:0);employeeScroll.documentView=employeeTable; employeeScroll.drawsBackground=false; employeeScroll.hasVerticalScroller=true; employeeScroll.autohidesScrollers=true; employeeScroll.scrollerStyle = .overlay
        for view in [headerDrag,brandDrag,island,employeeScroll,brand,version,history,findRow,noticeScroll,notice,modeBackground,replyButton,newButton,inputBackground,editor,draftHint,attachButton,sendButton,attachmentScroll,handle,drop,composerFaceScroll,searchResults,sidebarBlank,failureBar,noticeIcon] { addSubview(view) }
        addRoom.nativeLabelGap=8;addRoom.isBordered=false;addRoom.font = .systemFont(ofSize:12,weight:.medium)
        composerFaces.reduceMotion={ [weak self] in self?.reduceMotion() ?? true }
        composerFaceScroll.documentView=composerFaces;composerFaceScroll.drawsBackground=false
        composerFaceScroll.hasHorizontalScroller=true;composerFaceScroll.autohidesScrollers=true;composerFaceScroll.scrollerStyle = .overlay
        addRoom.invoke={ [weak self] in guard let self else { return };self.addMenu().popUp(positioning:nil,at:CGPoint(x:0,y:addRoom.bounds.height),in:addRoom) }
        island.avatar={ [weak controller] id in controller?.avatar(id) ?? ProfileAvatar(color:PictureCodec.color(name:id,hex:nil)) }
        let sidebarAlignment:NSTextAlignment = .center
        let logoParagraph=NSMutableParagraphStyle();logoParagraph.alignment=sidebarAlignment
        let logo=NSMutableAttributedString(string:"HEJO.",attributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:NSColor.labelColor,.paragraphStyle:logoParagraph])
        logo.addAttribute(.foregroundColor,value:NSColor.systemBlue,range:NSRange(location:0,length:1)); brand.attributedStringValue=logo
        brand.font = .systemFont(ofSize:14,weight:.semibold); version.font = .systemFont(ofSize:10); version.textColor = .labelColor.withAlphaComponent(0.7)
        version.stringValue=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""
        brand.alignment=sidebarAlignment; version.alignment=sidebarAlignment
        employeeSearch.placeholderString="검색"; employeeSearch.delegate=self; employeeSearch.font = .systemFont(ofSize:12)
        search.placeholderString="단어나 문장으로 검색"; search.delegate=self
        findRow.onClose={ [weak self] in _=self?.closeSearchIfOpen() }
        noticeScroll.documentView=noticeBar;noticeScroll.drawsBackground=false;noticeScroll.hasHorizontalScroller=true;noticeScroll.autohidesScrollers=true;noticeScroll.scrollerStyle = .overlay;noticeScroll.wantsLayer=true;noticeScroll.layer?.masksToBounds=true
        searchResults.onChooseHistory={ [weak self] key,id in self?.revealHistorySearch(key,id:id) }
        historySearch.onChange={ [weak self] in self?.searchSelection=0;self?.refresh() }
        historySidebarSearch.onChange={ [weak self] in self?.refresh() }
        sidebarSearch.onClear={ [weak self] in self?.employeeSearch.stringValue="";self?.refresh() }
        sidebarBlank.toggle={ [weak self] in self?.cycleSidebarWidth() }
        for stack in [noticeBar,failureBar] {stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=6}
        noticeBar.orientation = .horizontal;noticeBar.alignment = .centerY;noticeBar.spacing=8;noticeBar.edgeInsets=NSEdgeInsets(top:7,left:12,bottom:7,right:12);noticeBar.wantsLayer=true
        composerFaces.makeMenu={ [weak self] index in guard let self,self.composerMembers.indices.contains(index) else{return nil};return self.memberMenu(self.composerMembers[index]) }
        composerFaces.onPick={ [weak self] index in guard let self,self.composerMembers.indices.contains(index) else{return};if self.controller.model.isHome {if self.replyMode {self.createThread()};self.controller.pickHome(self.composerMembers[index])} else if self.composerMembers.count>=2 {self.controller.mention(self.composerMembers[index])};self.window?.makeFirstResponder(self.editor.editor) }
        handle.width={ [weak self] in self?.sidebarWidth ?? 0 }; handle.onWidth={ [weak self] in self?.setSidebarWidth($0) }
        handle.onEnd={ [weak self] in if let self,self.sidebarWidth>0 { self.shownSidebarWidth=self.sidebarWidth } }
        noticeIcon.image=NSImage(systemSymbolName:"info.circle",accessibilityDescription:nil);noticeIcon.contentTintColor = .labelColor;notice.font = .systemFont(ofSize:11); notice.textColor = .labelColor;attachButton.toolTip="사진·파일 첨부";attachButton.setAccessibilityLabel("사진·파일 첨부")
        attachments.orientation = .horizontal; attachments.spacing=6
        attachmentScroll.documentView=attachments; attachmentScroll.drawsBackground=false; attachmentScroll.hasHorizontalScroller=true; attachmentScroll.autohidesScrollers=true
        replyButton.mode=true;newButton.mode=true
        replyButton.invoke={ [weak self] in self?.writeReply() }; newButton.invoke={ [weak self] in self?.createThread() }
        attachButton.invoke={ [weak self] in self?.attach() }; sendButton.invoke={ [weak self] in self?.send() }; sendButton.chosen=true
        inputBackground.wantsLayer=true; inputBackground.layer?.borderWidth=1
        editor.editor.delegate=self; editor.editor.formattingController=formatting; formatting.editor=editor.editor
        editor.editor.onSubmit={ [weak self] in self?.send() }; editor.editor.onPaste={ [weak self] in self?.paste(.general) ?? false }
        editor.onHeight={ [weak self] height in guard let self,abs(self.editorHeight-height)>0.5 else { return }; self.editorHeight=height; self.needsLayout=true }
        draftHint.font = .systemFont(ofSize:14); draftHint.textColor = .secondaryLabelColor
        drop.canAttach={ [weak self] in self?.controller.model.selected != nil }
        drop.onPaste={ [weak self] board in self?.paste(board) ?? false }; drop.onTarget={ [weak self] _ in self?.drop.needsDisplay=true }
        layer?.borderColor=NSColor.controlAccentColor.cgColor
        headerDrag.onMenu = { [weak self] in self?.headerMenu() }
        brandDrag.onMenu = { [weak self] in let menu=NSMenu();menu.addItem(RoomActionItem("펫으로 접기"){self?.onCollapse?()});return menu }
        clipboard.recoverLeftovers()
        for drag in [headerDrag,brandDrag] {drag.toolTip="드래그: 채팅창과 펫 함께 이동 · 더블클릭: 가로 2배 / 기본";drag.setAccessibilityLabel("채팅창과 펫 이동")}
        headerDrag.menuHelp="오른쪽 클릭: 제목·설명 편집 및 대화 메뉴"
        controller.historyLoading.onAnchor = { [weak self] key,id in self?.history.scrollTo(key.thread,message:id) }
        history.onViewport = { [weak self] ids in
            guard let self,self.controller.model.pinHistoryViewport(ids) else {return}
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
        history.onOlder = { [weak self] in self?.loadOlder() }
        history.onNewer = { [weak self] in self?.restoreNewer() }
        history.reduceMotion={ [weak self] in self?.reduceMotion() ?? true }
        history.onBlank={ [weak self] in self?.foldAll() }
        history.onMeasured={ [weak self] in self?.reportOpenHeight() }
        addSubview(todoDrawer);todoDrawer.isHidden=true
        todoDrawer.onFilter={ [weak self] filter in self?.controller.drawerFilter=filter;self?.refresh() }
        todoDrawer.onSelect={ [weak self] card in self?.selectDrawerCard(card,activate:false) }
        todoDrawer.onCard={ [weak self] card in self?.selectDrawerCard(card) }
        todoDrawer.onClose={ [weak self] in self?.onToggleDrawer?() }
        todoDrawer.onCloseDeadline={ [weak self] card,outcome in self?.controller.closeDeadline(card,outcome:outcome);self?.refresh() }
        todoDrawer.onUndoClose={ [weak self] in self?.controller.undoClose();self?.refresh() }
        todoDrawer.onOpenSource={ [weak self] url in self?.onOpenURL(url) }
        todoDrawer.avatar={ [weak controller] id in controller?.avatar(id) ?? ProfileAvatar(color:PictureCodec.color(name:id,hex:nil)) }
        island.onAction={ [weak self] action in self?.activateIsland(action) }
        island.onWidthChange={ [weak self] in self?.needsLayout=true }
        headerDrag.excluded={ [weak self] point in self?.island.frame.contains(point) == true }
        islandTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in
            Task { @MainActor in self?.tickIsland() }
        }
        controller.onRestoreDraft={ [weak self] key,newPost,inHome in
            guard let self else{return};self.automatic=false;self.replyMode = !newPost;self.openThread=newPost ? nil:key
            if newPost {self.newKeys[self.placeNamespace]=key;self.controller.registerNewPlace(key)};self.controller.composeKey=key
            if !newPost {self.history.scrollTo(key.thread)}
        }
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){[weak self] _ in MainActor.assumeIsolated {self?.applyChatAppearance()} }
        controller.onShowFailure={ [weak self] failure in self?.chooseEmployee(failure.shown) };controller.onChange={ [weak self] in
            let span = ThreeTapDiagnostics.startSpan()
            defer { ThreeTapDiagnostics.endSpan("controller_change", span) }
            self?.refresh()
        }; controller.onRevealThread={ [weak self] key in self?.openFromBubble(key) }; refresh()
    }
    required init?(coder:NSCoder) { fatalError() }
    deinit { historyCopyTask?.cancel(); if let appearanceObserver {NotificationCenter.default.removeObserver(appearanceObserver)};islandTimer?.invalidate();streamTimer?.invalidate();workspaceTimer?.invalidate() }
    func tickIsland(updateDrawer:Bool=true) {
        island.show(islandModel.snapshot())
        let second=Int(controller.clock().timeIntervalSince1970)
        if second != noticeSecond {
            noticeSecond=second
            if updateDrawer && controller.drawerVisible {todoDrawer.show(controller.drawerSnapshot,filter:controller.drawerFilter,selected:drawerSelectedID)}
            if let room=controller.model.selected?.employee,controller.model.notices(room) != shownNotices {refresh()}
        }
        if let until=highlightUntil, until<=islandModel.now { highlightUntil=nil;highlightedMessageID=nil;refresh() }
    }
    func activateIsland(_ action:IslandModel.Action) {
        switch action {
        case .drawer: onToggleDrawer?()
        case .reconnect: reconnect()
        case .retry(let key): retrySend(key)
        case .question(let id,let key):
            guard controller.model.messages[id]?.replyState == "asked" else { return }
            reveal(key);highlightedMessageID=id;highlightUntil=islandModel.now.addingTimeInterval(1.5)
            refresh();history.scrollTo(key.thread)
        case .worker(let key): reveal(key);refresh();history.scrollTo(key.thread)
        }
    }
    private func reveal(_ key:ConversationKey,inHome:Bool=false) {
        rememberPlace()
        let place=inHome ? HomeRoom.id:key.employee
        if identity != place { identity=place;windowed.reset() }
        writingPlace=controller.client.store.settings.address+"\u{1}"+place+(inHome ? controller.model.homeChannel.map{"/"+$0.id} ?? "":"")
        searchOpen=false;historySearch.reset();search.stringValue="";openThread=key;replyMode=true;automatic=false;controller.composeKey=key
        controller.model.select(key,notify:false,inHome:inHome);controller.model.markAlertSeen(key)
    }
    func setSidebarWidth(_ value:CGFloat) {
        let next=ConversationSidebar.snapped(value); guard next != sidebarWidth else { return }
        let delta=next-sidebarWidth; sidebarWidth=next; onSidebarWidth?(delta); refresh()
    }
    func toggleSidebar() { if sidebarWidth>0 { shownSidebarWidth=sidebarWidth; setSidebarWidth(0) } else { setSidebarWidth(shownSidebarWidth) } }
    var onConnections:((String)->Void)?
    func employeeMenu(row: Int) -> NSMenu {
        guard sidebarRows.indices.contains(row) else { return blankMenu() }
        let selected=sidebarRows[row]
        if selected.kind == .home {return homeMenu()}
        if selected.kind == .section || selected.kind == .stack { return sectionMenu(selected) }
        guard selected.kind == .room || selected.kind == .home else { return blankMenu() }
        if let room=controller.model.groups[selected.id] {return groupMenu(room)}
        let employee = selected.id, model = controller.model, menu = NSMenu()
        appendPinMenu(menu,room:employee);menu.addItem(.separator())
        menu.addItem(RoomActionItem(model.muted.contains(employee) ? "알림 켜기":"알림 끄기"){model.toggleMute(employee)});menu.addItem(.separator())
        if let person=model.employees.first(where:{$0.id==employee}),person.avatarCustom != nil {
            menu.addItem(pictureMenu(kind:"employee",id:employee,name:person.name))
            if person.avatarCustom==true { menu.addItem(RoomActionItem("사진 지우기") { [weak self] in Task { _=await self?.controller.changePicture(kind:"employee",id:employee,url:nil) } }) }
        }
        menu.addItem(RoomActionItem("목록에서 빼기") { model.hide(employee) })
        return menu
    }
    func appendPinMenu(_ menu:NSMenu,room:String){
        let model=controller.model
        for slot in 1...5 {menu.addItem(RoomActionItem((slot==1 ? "맨 위에 고정":"\(slot)번째 자리에 고정")+(model.sidebar.pins[room]==slot ? " ✓":"")){model.pin(room,slot:slot)})}
        if model.pinned.contains(room){menu.addItem(.separator());menu.addItem(RoomActionItem("고정 해제"){model.pin(room,slot:nil)})}
    }
    func homeMenu()->NSMenu {
        let menu=NSMenu(),model=controller.model
        if model.homeChannel != nil {menu.addItem(RoomActionItem("기본 방으로 되돌리기"){[weak self] in self?.changeHomeChannel(nil)});menu.addItem(.separator())}
        let item=NSMenuItem(title:"고정 방 변경",action:nil,keyEquivalent:""),channels=NSMenu()
        channels.addItem(RoomActionItem("기본"){[weak self] in self?.changeHomeChannel(nil)});channels.addItem(.separator())
        for room in model.groups.values.filter({$0.archived != true}).sorted(by:{$0.title<$1.title}) {let choice=RoomActionItem("#"+room.title){[weak self] in self?.changeHomeChannel(room.id)};choice.state=model.homeChannel?.id==room.id ? .on:.off;channels.addItem(choice)}
        item.submenu=channels;menu.addItem(item)
        menu.addItem(pictureMenu(kind:"room",id:model.homeChannel?.id ?? HomeRoom.pictureID,name:model.homeChannel?.title ?? model.name(HomeRoom.id)))
        if model.homePicture != nil {menu.addItem(RoomActionItem("사진 지우기"){[weak self] in Task {if let room=model.homeChannel {_=await self?.controller.changePicture(kind:"room",id:room.id,url:nil)}else{await self?.clearHomePicture()}}})}
        menu.addItem(.separator())
        if let room=model.homeChannel {menu.addItem(RoomActionItem("직원 추가…"){[weak self] in guard let self,let members=RoomDialogs.invite(model.employees,room:room) else{return};Task{await self.controller.roomCommand("room_save",room:room,members:members)}});menu.addItem(.separator())}
        let recipient=NSMenuItem(title:"기본 받을 직원",action:nil,keyEquivalent:""),choices=NSMenu()
        for person in model.home.members {let choice=RoomActionItem(person.name){model.configureHome{$0.recipient=person.id}};choice.state=model.home.defaultRecipient==person.id ? .on:.off;choices.addItem(choice)}
        recipient.submenu=choices;menu.addItem(recipient)
        menu.addItem(RoomActionItem(model.home.settings.muted==true ? "알림 켜기":"알림 끄기"){model.configureHome{$0.muted = $0.muted != true}})
        return menu
    }
    func changeHomeChannel(_ id:String?){
        rememberPlace();controller.cancelFollowup();controller.model.configureHome{$0.channel=id};chooseHome()
    }
    func clearHomePicture() async {
        do {try await controller.files.setPicture(kind:"room",id:HomeRoom.pictureID,data:nil);controller.model.configureHome{$0.picture=nil}}
        catch {controller.notice="사진을 지우지 못했어요. 다시 시도해 주세요.";refresh()}
    }
    func rowIndex(for employee:String)->Int? { sidebarRows.firstIndex { ($0.kind == .room || $0.kind == .home) && $0.id==employee } }
    func sectionMenu(_ row:SidebarLayout.Row)->NSMenu {
        let menu=NSMenu(), model=controller.model,id=row.kind == .stack ? nil : row.zone
        menu.addItem(RoomActionItem(row.open ? "접기" : "펼치기") { model.toggleSection(id) });menu.addItem(.separator())
        menu.addItem(RoomActionItem("이름 바꾸기…") { [weak self] in
            guard let name=RoomDialogs.renameSection(row.name) else{return};self?.controller.model.editSection(id,name:name)
        })
        guard let id else { return menu }
        menu.addItem(.separator())
        let remove=RoomActionItem("섹션 삭제…") { [weak self] in
            guard let self,let text=model.sidebar.deletion(id) else { return }
            let alert=NSAlert();alert.alertStyle = .warning;alert.messageText=text.title;alert.informativeText=text.body
            alert.addButton(withTitle:"삭제");alert.addButton(withTitle:"취소")
            if OptionWindows.runModal(alert) == .alertFirstButtonReturn { Task { await self.deleteSection(id) } }
        };remove.isEnabled=model.sidebar.sections.count>1;menu.addItem(remove);return menu
    }
    func deleteSection(_ id:String) async {
        guard controller.model.sidebar.deletion(id) != nil else { return }
        do { try await controller.files.setPicture(kind:"room",id:"section-"+id,data:nil);controller.model.removeSection(id) }
        catch { controller.notice="섹션 사진을 지우지 못했어요. 다시 시도해 주세요." }
    }
    private func deleteSectionPicture(_ id:String) async {
        do { try await controller.files.setPicture(kind:"room",id:"section-"+id,data:nil);controller.model.editSection(id,clearPicture:true) }
        catch { controller.notice="사진을 지우지 못했어요. 다시 시도해 주세요." }
    }
    var picturePicker:()->NSOpenPanel = {NSOpenPanel()}
    var choosePictureFile:(NSOpenPanel,@escaping(NSApplication.ModalResponse)->Void)->Void = { $0.begin(completionHandler:$1) }
    func choosePicture(kind:String,id:String,section:String?=nil) {
        let client=controller.client,address=client.store.settings.address,token=client.bearer,epoch=client.connectionEpoch
        let picker=picturePicker();picker.canChooseDirectories=false;picker.allowsMultipleSelection=false;picker.allowedContentTypes=[.png,.jpeg,.heic];picker.title="방 사진 고르기";picker.prompt="넣기"
        OptionWindows.prepare(picker)
        choosePictureFile(picker) { [weak self] result in
            guard result == .OK,let url=picker.url,let self,address==client.store.settings.address,token==client.bearer,epoch==client.connectionEpoch else { return }
            Task {
                guard address==client.store.settings.address,token==client.bearer,epoch==client.connectionEpoch else{return}
                if let picture=await self.controller.changePicture(kind:kind,id:id,url:url) {self.pictureUploaded(picture,id:id,section:section)}
            }
        }
    }
    func addMenu()->NSMenu {
        let menu=NSMenu(),model=controller.model
        menu.addItem(RoomActionItem("새 방 만들기…") { [weak self] in self?.createRoom() })
        menu.addItem(RoomActionItem("새 섹션 만들기") { model.addSection() });menu.addItem(.separator())
        let heading=NSMenuItem(title:"목록에서 뺀 방",action:nil,keyEquivalent:"");heading.isEnabled=false;menu.addItem(heading)
        let hidden=model.rooms.filter{model.hidden.contains($0.id)}
        for room in hidden {menu.addItem(RoomActionItem((room.kind == .direct ? "@":"#")+room.title){model.restore(room.id)})}
        if hidden.isEmpty {let empty=NSMenuItem(title:"뺀 방이 없어요",action:nil,keyEquivalent:"");empty.isEnabled=false;menu.addItem(empty)}
        let archived=model.groups.values.filter{$0.archived==true}.sorted{$0.title<$1.title}
        if !archived.isEmpty {let item=NSMenuItem(title:"보관된 방 (\(archived.count))",action:nil,keyEquivalent:""),list=NSMenu();for room in archived {list.addItem(RoomActionItem("#"+room.title+" 보관 해제"){[weak self] in Task {guard let self else{return};self.controller.model.restore(room.id);await self.controller.roomCommand("room_archive",room:room,archived:false);self.chooseEmployee(room.id)}})};item.submenu=list;menu.addItem(item)}
        return menu
    }
    func blankMenu()->NSMenu {NSMenu()}
    func cycleSidebarWidth() {setSidebarWidth(sidebarWidth==ConversationSidebar.width ? ConversationSidebar.expandedWidth:ConversationSidebar.width)}
    func headerMenu() -> NSMenu {
        let menu=NSMenu(),model=controller.model,employee=model.selected == nil ? nil:model.selectionIdentity
        menu.addItem(RoomActionItem(model.groups[employee ?? ""] == nil ? "제목과 설명 편집…":"제목과 설명 바꾸기…") { [weak self] in self?.editHeader() });menu.addItem(.separator())
        menu.addItem(RoomActionItem(employee.map{model.muted.contains($0) ? "이 대화의 알림 켜기":"이 대화의 알림 끄기"} ?? "이 대화의 알림 끄기") {if let employee {model.toggleMute(employee)}})
        menu.addItem(RoomActionItem("방 목록 보이기 / 숨기기") { [weak self] in self?.toggleSidebar() })
        menu.addItem(RoomActionItem("방 목록 너비 전환") { [weak self] in self?.cycleSidebarWidth() })
        menu.addItem(RoomActionItem("전체 검색 (⌘F)") { [weak self] in self?.openSearch() })
        menu.addItem(RoomActionItem("모두 읽음") {if let employee {model.markAllRead(employee)}})
        menu.addItem(.separator());menu.addItem(RoomActionItem("펫으로 접기") { [weak self] in self?.onCollapse?() });return menu
    }
    func editHeader() {
        guard controller.model.selected != nil else{return};let employee=controller.model.selectionIdentity
        let value=controller.model.header(employee)
        let (alert,heading,detail)=RoomDialogs.header(title:value.title,description:value.description)
        let result=OptionWindows.runModal(alert)
        if let room=controller.model.groups[employee] {if result == .alertFirstButtonReturn {Task {await controller.roomCommand("room_save",room:room,title:heading.stringValue,description:detail.stringValue)}};return}
        switch result {
        case .alertFirstButtonReturn: let name=heading.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);controller.model.saveHeader(employee,title:name.isEmpty ? value.title:name,description:detail.stringValue.trimmingCharacters(in:.whitespacesAndNewlines))
        case .alertThirdButtonReturn: controller.model.saveHeader(employee,title:"",description:"")
        default:break
        }
    }
    private var placeNamespace:String {controller.client.store.settings.address+"\u{1}"+controller.model.selectionIdentity+(controller.model.isHome ? controller.model.homeChannel.map{"/"+$0.id} ?? "":"")}
    private func rememberPlace() {
        if let key=controller.composeKey ?? controller.model.selected,!controller.draft.isEmpty {lastPlaces[placeNamespace]=key}
        else {lastPlaces[placeNamespace]=nil}
    }
    private func entry(_ employee:String,home:Bool) {
        rememberPlace();controller.cancelFollowup();openThread=nil;searchHighlight=nil;searchHighlightThread=nil;enteredPlace=""
        let namespace=controller.client.store.settings.address+"\u{1}"+employee+(home ? controller.model.homeChannel.map{"/"+$0.id} ?? "":"")
        writingPlace=namespace;identity=employee;windowed.reset()
        if let saved=lastPlaces[namespace],!controller.draft(for:saved).isEmpty {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
            let savedDeleted = controller.client.store.historyMode ? controller.model.history.deletedThreads[saved] != nil : controller.model.timeline(saved).isEmpty
#else
            let savedDeleted = controller.model.history.deletedThreads[saved] != nil
#endif
            automatic=autoKeys[namespace]==saved
            if automatic {controller.composeKey=saved;selectAutomatic(employee,home:home)}
            else if savedDeleted,newKeys[namespace] != saved {
                automatic=true;let next=autoKey(namespace,employee:employee)
                controller.moveDraft(from:saved,to:next,carry:true);selectAutomatic(employee,home:home)
            } else {replyMode = !savedDeleted;openThread=replyMode ? saved:nil;controller.composeKey=saved;controller.model.select(saved,inHome:home,markRead:false)}
            return
        }
        automatic=true;controller.composeKey=autoKey(namespace,employee:employee);selectAutomatic(employee,home:home)
    }
    private func autoKey(_ place:String,employee:String)->ConversationKey {
        if let key=autoKeys[place] {return key}
        let key=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased());autoKeys[place]=key;return key
    }
    private func newest(_ employee:String)->ConversationKey? {
        let model=controller.model
        let rows=employee==HomeRoom.id ? model.homeThreads:model.threads(employee:employee)
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !controller.client.store.historyMode {
            return rows.max {a,b in
                let x=model.history.summaries[a.key].map{model.date($0.lastTime)} ?? model.timeline(a.key).map{model.date($0.timestamp)}.max() ?? .distantPast
                let y=model.history.summaries[b.key].map{model.date($0.lastTime)} ?? model.timeline(b.key).map{model.date($0.timestamp)}.max() ?? .distantPast
                return x==y ? (model.history.summaries[a.key]?.rootSeq ?? model.timeline(a.key).first?.seq ?? 0)<(model.history.summaries[b.key]?.rootSeq ?? model.timeline(b.key).first?.seq ?? 0):x<y
            }?.key
        }
#endif
        return rows.compactMap {model.history.summaries[$0.key]}.max {a,b in
            let x=model.date(a.lastTime),y=model.date(b.lastTime)
            return x==y ? a.rootSeq<b.rootSeq:x<y
        }?.conversationKey
    }
    private func selectAutomatic(_ employee:String,home:Bool) {
        let model=controller.model,namespace=controller.client.store.settings.address+"\u{1}"+employee+(home ? controller.model.homeChannel.map{"/"+$0.id} ?? "":"")
        let latest=home ? nil:newest(employee)
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        let target=latest.flatMap{(model.history.summaries[$0]?.rootRole ?? model.timeline($0).first?.role)=="employee" ? $0:nil}
#else
        let target=latest.flatMap{model.history.summaries[$0]?.rootRole=="employee" ? $0:nil}
#endif
        replyMode=target != nil
        let key=target ?? autoKey(namespace,employee:employee)
        if target==nil {controller.registerNewPlace(key)}
        model.select(key,notify:false,inHome:home,markRead:false)
    }
    func chooseEmployee(_ employee:String) {
        if employee==HomeRoom.id {chooseHome();return}
        if controller.model.visible {controller.model.enterRoom(employee)}
        entry(employee,home:false);refresh()
    }
    func chooseHome() {
        if controller.model.visible {controller.model.enterRoom(HomeRoom.id)}
        entry(HomeRoom.id,home:true);refresh()
    }
    func chooseThread(_ key:ConversationKey) {
        controller.cancelFollowup()
        controller.moveDraft(from:controller.composeKey,to:key,carry:controller.model.selected==key);automatic=false;replyMode=true; openThread=openThread == key ? nil : key
        if openThread != key,searchHighlightThread==key {searchHighlight=nil;searchHighlightThread=nil}
        controller.model.select(key,inHome:controller.model.isHome);controller.model.markAlertSeen(key)
        if openThread==key {if controller.client.store.historyMode {controller.historyLoading.open(key)};history.scrollTo(key.thread,bottom:true)}
    }
    private var pendingRevealScroll: String?
    private var preparingOpening=false
    private var openingEntry:String?
    func performUpdates(_ updates: () -> Void,opening:Bool=false) {
        let previous=preparingOpening;preparingOpening=opening
        defer{preparingOpening=previous}
        controller.performUpdates(updates)
    }
    func finishOpeningEntry() {
        guard let thread=openingEntry else{return}
        openingEntry=nil
        layoutSubtreeIfNeeded();history.layoutSubtreeIfNeeded()
        history.enter(thread)
    }
    func openFromBubble(_ key: ConversationKey) {
        reveal(key,inHome:controller.model.isHome && controller.model.selected==key)
        if preparingOpening {openingEntry=key.thread}
        else if controller.isUpdating { pendingRevealScroll = key.thread }
        refresh()
        if !controller.isUpdating && !preparingOpening { history.scrollTo(key.thread) }
    }
    @discardableResult func closeSearchIfOpen() -> Bool {
        guard searchOpen else { return false }
        searchOpen=false; historySearch.reset();search.stringValue="";refresh(); return true
    }
    var isSearchOpen: Bool { searchOpen }
    func toggleSearch() {if searchOpen {_=closeSearchIfOpen()} else {openSearch()} }
    func openSearch() {searchHighlight=nil;searchHighlightThread=nil;searchOpen=true;refresh();window?.makeFirstResponder(search)}
    func handleWorkspaceKey(_ event:NSEvent)->Bool {
        if event.modifierFlags.contains(.command),["f","ㄹ"].contains(event.charactersIgnoringModifiers?.lowercased() ?? "") {openSearch();return true}
        guard searchOpen else{return false}
        if let input=window?.firstResponder as? NSTextView,input.hasMarkedText() {return false}
        switch event.keyCode {
        case 53:return closeSearchIfOpen()
        case 125:moveSearch(1)
        case 126:moveSearch(-1)
        case 36:chooseSearch()
        default:return false
        };return true
    }
    func moveSearch(_ delta:Int) {searchSelection=min(max(0,searchSelection+delta),max(0,historySearch.groups.count-1));showSearchResults()}
    func chooseSearch() {
        if historySearch.groups.indices.contains(searchSelection),let hit=historySearch.groups[searchSelection].matches.first {revealHistorySearch(hit.conversationKey,id:hit.id)}
    }
    func revealHistorySearch(_ key:ConversationKey,id:String) {
        expandedMessages.insert(id)
        searchHighlight=search.stringValue.isEmpty ? employeeSearch.stringValue:search.stringValue
        _=closeSearchIfOpen();reveal(key);searchHighlightThread=key;highlightedMessageID=id;highlightUntil=islandModel.now.addingTimeInterval(1.6)
        controller.historyLoading.open(key,anchor:id);refresh()
    }
    private func showSearchResults() {
        let model=controller.model
        if historySearch.busy {searchResults.showStatus("검색 중…")}
        else if historySearch.failed {searchResults.showStatus("검색을 불러오지 못했어요",retry:{ [weak self] in self?.historySearch.retry() })}
        else {searchResults.showHistory(historySearch.groups,query:search.stringValue,selection:searchSelection,name:model.name,room:{id in (id==HomeRoom.id || model.homeScope.contains(id)) ? model.header(HomeRoom.id).title:(model.groups[id] != nil ? "#":"@")+model.header(id).title})}
    }
    func scheduleSearch() {
        guard searchOpen else{return}
        historySearch.update(query:search.stringValue,mode:"groups",client:controller.client,model:controller.model)
        showSearchResults()
    }
    func jumpNotice(_ item:RoomNotice) {
        guard !item.messages.isEmpty else{return}
        let next=item.questions ? (noticeCursor[item.id] ?? -1)+1:0,index=next%item.messages.count;noticeCursor[item.id]=index
        if controller.client.store.historyMode {
            let model=controller.model,id=item.messages[index],scope=model.isHome ? "home":model.selectionIdentity
            guard let row=model.history.noticeRows[scope]?.first(where:{$0["id"] as? String == id}),
                  let key=row["key"] as? [String:String],let room=key["room"],let thread=key["thread"] else{return}
            let destination=ConversationKey(employee:room,thread:thread)
            controller.cancelFollowup();reveal(destination);highlightedMessageID=id;highlightUntil=islandModel.now.addingTimeInterval(1.6)
            controller.historyLoading.open(destination,anchor:id);return
        }
        guard let message=controller.model.messages[item.messages[index]] else{return}
        controller.cancelFollowup();reveal(message.key);highlightedMessageID=message.id;highlightUntil=islandModel.now.addingTimeInterval(1.6)
        refresh();history.scrollTo(message.key.thread,message:message.id)
    }
    private func refreshWorkspaceBars() {
        let next=controller.model.notices(controller.model.selectionIdentity)
        for stack:NSStackView in [noticeBar,failureBar] where stack === failureBar || !next.isEmpty || reduceMotion() || bannerFraction<=0 {for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}}
        let model=controller.model,employee=model.selectionIdentity
        shownNotices=next
        if !shownNotices.isEmpty {let pin=NSImageView();pin.image=NSImage(systemSymbolName:"pin.fill",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:9,weight:.regular));pin.contentTintColor = .secondaryLabelColor;pin.wantsLayer=true;pin.layer?.setAffineTransform(CGAffineTransform(rotationAngle:.pi/4));noticeBar.addArrangedSubview(pin)}
        for item in shownNotices {
            let button=NoticePill(item);button.invoke={ [weak self] in self?.jumpNotice(item) };noticeBar.addArrangedSubview(button)
        }
        let alerts=next.filter{!$0.questions}.flatMap(\.messages).count
        if alerts>0 {let button=FileChip(title:"모두 읽음");button.isBordered=false;button.font = .systemFont(ofSize:11,weight:.medium);button.image=NSImage(systemSymbolName:"checkmark.circle",accessibilityDescription:nil);button.imagePosition = .imageLeading;button.contentTintColor = .secondaryLabelColor;button.toolTip="이 방의 알림 \(alerts)건을 모두 읽음으로";button.setAccessibilityLabel("알림 \(alerts)건 모두 읽음");button.invoke={model.readAllNotices(employee)};noticeBar.addArrangedSubview(button)}
        bannerMotion.target(shownNotices.isEmpty || controller.drawerOpen ? 0:1,now:motionTime(),immediate:reduceMotion())
        let shownFailures=controller.shownFailures
        for failure in shownFailures {
            let row=NSStackView();row.spacing=6;row.toolTip=failure.reason
            let warning=NSImageView();warning.image=NSImage(systemSymbolName:"exclamationmark.circle.fill",accessibilityDescription:nil);warning.contentTintColor = .systemRed;row.addArrangedSubview(warning)
            let place=failure.newPost ? (model.isHome ? "새 대화":"새 글"):model.timeline(failure.key).first.map{"답글 · "+String(MessageFormat.plain($0.text).prefix(16))} ?? "답글"
            let words=failure.draft.text.trimmingCharacters(in:.whitespacesAndNewlines)
            let what=words.isEmpty ? "파일 \(failure.draft.attachments.count)개":String(words.prefix(40))+(failure.draft.attachments.isEmpty ? "":" · 파일 \(failure.draft.attachments.count)개")
            let title=NSTextField(labelWithString:"보내지 못함 · "+place+" · "+what);title.font = .systemFont(ofSize:11);title.lineBreakMode = .byTruncatingTail;row.addArrangedSubview(title)
            let restore=FileChip(title:"되살리기");restore.isBordered=false;restore.font = .systemFont(ofSize:11);restore.toolTip="보내지 못한 글을 원래 보내려던 곳의 입력창으로 되돌려요. 다시 보내기 전에는 보내지 않아요.";restore.invoke={ [weak controller] in controller?.restoreFailure(failure.id) };row.addArrangedSubview(restore)
            let discard=FileChip(title:"지우기");discard.isBordered=false;discard.font = .systemFont(ofSize:11);discard.invoke={ [weak controller] in controller?.discardFailure(failure.id) };row.addArrangedSubview(discard);failureBar.addArrangedSubview(row)
        }
        failureBar.wantsLayer=true;failureBar.layer?.cornerRadius=8;failureBar.layer?.backgroundColor=NSColor.systemRed.withAlphaComponent(0.08).cgColor
        let elsewhere=controller.elsewhereFailures
        if let first=elsewhere.first {
            let row=NSStackView();row.spacing=6
            let warning=NSImageView();warning.image=NSImage(systemSymbolName:"exclamationmark.circle",accessibilityDescription:nil);warning.contentTintColor = .systemRed;row.addArrangedSubview(warning)
            let label=NSTextField(labelWithString:"다른 방에서 보내지 못한 글 \(elsewhere.count)개");label.font = .systemFont(ofSize:11);row.addArrangedSubview(label)
            let button=FileChip(title:"보러 가기");button.isBordered=false;button.font = .systemFont(ofSize:11);button.invoke={ [weak self] in self?.chooseEmployee(first.shown) };row.addArrangedSubview(button);failureBar.addArrangedSubview(row)
        }
        failureBar.isHidden=failureBar.arrangedSubviews.isEmpty
    }
    private func reportOpenHeight() {
        let needed: CGFloat?
        if !isReadingResize,let openThread, let layout=history.layouts.first(where: { $0.content.id == openThread.thread }) {
            needed = max(0, bounds.height - history.frame.height) + layout.height + 32
        } else { needed = nil }
        var total=needed
        if !isReadingResize,!longReplyBases.isEmpty {
            let extra=longReplyBases.reduce(CGFloat(0)){sum,item in
                guard let post=history.layouts.lazy.flatMap(\.placed).first(where:{if case .post(let p)=$0.piece{return p.id==item.key};return false}) else{return sum}
                return sum+max(0,post.frame.height-item.value)
            }
            total=max(total ?? (longReplyWindowBase ?? bounds.height),(longReplyWindowBase ?? bounds.height)+extra)
        }
        if let needed=total, let reportedOpenHeight, abs(needed - reportedOpenHeight) < 1 { return }
        if total == nil && reportedOpenHeight == nil { return }
        reportedOpenHeight = total; onOpenThreadHeight?(total)
    }
    func createThread() {
        guard controller.model.selected != nil else{return}
        controller.cancelFollowup();automatic=false;replyMode=false
        let place=placeNamespace,employee=controller.model.isHome ? HomeRoom.id:controller.model.selectionIdentity
        let key:ConversationKey
        if controller.model.isHome {key=autoKey(place,employee:employee)}
        else if let old=newKeys[place] {key=old}
        else {key=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased());newKeys[place]=key}
        // A blank selection can keep an open working thread in sight; it remains the interruption target.
        controller.registerNewPlace(key);controller.composeKey=key;controller.model.select(key,inHome:controller.model.isHome)
    }
    func writeReply() {
        guard let key=(replyMode ? controller.model.selected:nil) ?? newest(controller.model.selectionIdentity) else{return}
        controller.moveDraft(from:controller.composeKey,to:key,carry:controller.model.selected==key);automatic=false;controller.cancelFollowup();replyMode=true;openThread=key
        controller.model.select(key,inHome:controller.model.isHome);history.scrollTo(key.thread)
    }
    func foldAll() {searchHighlight=nil;searchHighlightThread=nil;expandedMessages.removeAll();longReplyBases.removeAll();longReplyWindowBase=nil;openThread=nil;createThread()}
    func folded() {_=closeSearchIfOpen();foldAll();controller.folded()}
    var interruptible:ConversationKey? {
        guard let openThread,controller.model.typing[openThread] != nil else{return nil};return openThread
    }
    var sendTarget:ConversationKey? {replyMode ? controller.model.selected:interruptible ?? controller.model.selected}
    var composerPrompt:String {
        let model=controller.model
        if !replyMode,let writing=interruptible {
            let speaker=model.typingPeople[writing]?.keys.sorted().first ?? writing.employee
            return model.name(speaker)+"에게 끼어들기…"
        }
        if model.isHome {
            if replyMode,let key=model.selected,let first=model.timeline(key).first {return String(MessageFormat.plain(first.text).prefix(36))+" · 이어서 말하기"}
            if controller.draft.picks.isEmpty,let channel=model.homeChannel {return channel.title+"에 새 요청"}
            let who=controller.draft.picks.first ?? model.home.defaultRecipient ?? ""
            return model.name(who)+"에게 새 글"
        }
        return replyMode ? "스레드에 답글":model.selected.map{(model.groups[$0.employee] != nil ? "#":"@")+model.name($0.employee)+"에 새 글"} ?? "hejo에 새 글"
    }
    func refresh() {
        if controller.client.store.historyMode,thumbnailAccessIdentity != controller.files.fileAccessIdentity {
            thumbnailAccessIdentity=controller.files.fileAccessIdentity
            thumbnails.removeAll();failedThumbnails=[];fetchingThumbnails=[]
        }
        if controller.isUpdating { controller.notifyChange(); return }
        guard !rendering else { return }; rendering=true
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.refreshes += 1
        let smoothRefreshStart = ProcessInfo.processInfo.systemUptime
        defer { HejoSmoothProbe.phases["refresh", default: []].append(ProcessInfo.processInfo.systemUptime - smoothRefreshStart) }
        #endif
        defer {
            rendering=false
            if let thread=openingEntry {history.enter(thread)}
            if let thread = pendingRevealScroll { pendingRevealScroll=nil; history.scrollTo(thread) }
        }
        controller.model.withStableRenderValues {
            let span = ThreeTapDiagnostics.startSpan()
            defer { ThreeTapDiagnostics.endSpan("refresh", span) }
            var phase = ThreeTapDiagnostics.startSpan()
            if !controller.drawerOpen,drawerSelectedID != nil {drawerSelectedID=nil;highlightedMessageID=nil;highlightUntil=nil}
            let model=controller.model
            displayTimes=displayTimes.filter{model.messages[$0.key] != nil}
            displayTimeOrder.removeAll{displayTimes[$0]==nil}
            historyRenderedIDs.removeAll(keepingCapacity:true)
            defer {
                if model.store.historyMode {
                    postBodies=postBodies.filter { historyRenderedIDs.contains($0.key) }
                    postBodyOrder.removeAll { postBodies[$0] == nil }
                }
            }
            let themeDark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua;version.textColor=CardText.quiet(dark:themeDark)
            streamReveal.receive(Array(model.messages.values),now:motionTime());streamReveal.advance(now:motionTime(),immediately:reduceMotion())
            if streamReveal.pending && streamTimer==nil {streamTimer=Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true){[weak self] _ in
                Task {@MainActor in guard let self else{return};if self.streamReveal.pending {self.refresh()}else{self.streamTimer?.invalidate();self.streamTimer=nil}}
            }}
            if composerAddress != controller.client.store.settings.address || identity != model.selectionIdentity,let old=writingKey,!controller.savedDraft(old,address:composerAddress).isEmpty {lastPlaces[writingPlace]=old}
            controller.prepareDraftAddress()
            if composerAddress != controller.client.store.settings.address {composerAddress=controller.client.store.settings.address;automatic=true;controller.composeKey=nil;identity=""}
            if model.selected==nil {identity="";automatic=false;replyMode=false;controller.composeKey=nil;openThread=nil}
            else {
    #if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
            let replyDeleted = controller.composeKey.map {controller.client.store.historyMode ? model.history.deletedThreads[$0] != nil : model.timeline($0).isEmpty && controller.timeline($0).isEmpty} ?? false
    #else
            let replyDeleted = controller.composeKey.map {model.history.deletedThreads[$0] != nil} ?? false
    #endif
            if identity != model.selectionIdentity || writingPlace != placeNamespace {
                identity=model.selectionIdentity;windowed.reset();openThread=nil;automatic=true
                if let saved=lastPlaces[placeNamespace],!controller.draft(for:saved).isEmpty,autoKeys[placeNamespace] != saved {
                    automatic=false;replyMode=newKeys[placeNamespace] != saved;openThread=replyMode ? saved:nil;controller.composeKey=saved;model.select(saved,notify:false,inHome:model.isHome)
                } else {controller.composeKey=autoKey(placeNamespace,employee:model.isHome ? HomeRoom.id:identity);selectAutomatic(identity,home:model.isHome)}
            } else if automatic {selectAutomatic(identity,home:model.isHome)}
            else if replyMode,let old=controller.composeKey,replyDeleted {
                automatic=true;openThread=nil;let destination=autoKey(placeNamespace,employee:model.isHome ? HomeRoom.id:identity)
                controller.moveDraft(from:controller.composeKey ?? old,to:destination,carry:true);selectAutomatic(identity,home:model.isHome)
            }
            }
            ThreeTapDiagnostics.endSpan("refresh_selection", phase); phase = ThreeTapDiagnostics.startSpan()
            let selected=model.selected
            rooms=model.displayRooms.filter { employeeSearch.stringValue.isEmpty || $0.title.localizedCaseInsensitiveContains(employeeSearch.stringValue) }
            let layout=model.sidebar
            let query=employeeSearch.stringValue.trimmingCharacters(in:.whitespacesAndNewlines),list=ConversationSidebar.isList(sidebarWidth),searching=list && !query.isEmpty
            sidebarRows=searching ? layout.items.filter{$0.name.localizedCaseInsensitiveContains(query)}.map{.init(kind:$0.kind == .home ? .home:.room,id:$0.id,name:$0.name,zone:layout.zone($0.id),items:[$0],picture:$0.picture)}:layout.rows
            if list {sidebarRows.insert(.init(kind:.search,id:"sidebar-search",name:""),at:0)}
            historySidebarSearch.update(query:searching ? query:"",mode:"sidebar",client:controller.client,model:model)
            if searching {
                let state=historySidebarSearch
                sidebarRows.append(.init(kind:.hitHeading,id:"hits-heading",name:state.busy ? "검색 중…":state.failed ? "검색 실패 · 눌러서 다시 시도":state.hits.isEmpty ? "찾는 글이 없어요":"글 \(state.hits.count)건"))
                sidebarRows += state.hits.map{.init(kind:.hit,id:"hit:"+$0.id,name:$0.id)}
            }
            composerMembers=model.isHome ? (model.homeChannel?.members ?? model.home.members.map(\.id)):selected.flatMap { model.room(for:$0.employee)?.members } ?? []
            if !model.isHome && composerMembers.count<2 {composerMembers=[]}
            composerFaces.faces=composerMembers.map { (model.name($0),controller.avatar($0)) }
            composerFaces.homeStyle=model.isHome
            editor.editor.mentions=(model.isHome ? model.homeRecipients.members:model.people(selected?.employee ?? "")).map(\.name)
            addRoom.toolTip="새 방·섹션 만들기, 뺀 방·보관된 방 다시 넣기";addRoom.setAccessibilityLabel("방 추가")
            let rowHeight = ConversationSidebar.isList(sidebarWidth) ? ConversationSidebar.rowHeight : ConversationSidebar.tabHeight
            if employeeTable.rowHeight != rowHeight { employeeTable.rowHeight = rowHeight }
            updateSidebarRows()
            ThreeTapDiagnostics.endSpan("refresh_sidebar", phase); phase = ThreeTapDiagnostics.startSpan()
            if let selected {
                let current=model.selectionIdentity
    #if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
                threads=model.isHome ? model.homeThreads:(model.room(for:current).map { model.threads(room:$0,query:"") } ?? []).sorted { (model.history.summaries[$0.key]?.rootSeq ?? model.timeline($0.key).first?.seq ?? 0) < (model.history.summaries[$1.key]?.rootSeq ?? model.timeline($1.key).first?.seq ?? 0) }
    #else
                threads=model.isHome ? model.homeThreads:(model.room(for:current).map {model.threads(room:$0,query:"")} ?? []).sorted {(model.history.summaries[$0.key]?.rootSeq ?? 0)<(model.history.summaries[$1.key]?.rootSeq ?? 0)}
    #endif
                if identity != current { windowed.reset(); identity=current; openThread=nil }
                threads=controller.includingPending(threads,scope:model.isHome ? model.homeScope:[current])
                let shown=Set(windowed.visibleIDs(threads.map(\.id),revealing:openThread?.thread))
                var cards:[NativeThreadCard.Content]=[], previous:Date?
                if controller.client.store.historyMode {
                    if controller.historyLoading.failure != nil {cards.append(historyStatusContent(failed:true))}
                    else if controller.historyLoading.busy || !model.historyAggregatesReady {cards.append(historyStatusContent(failed:false))}
                }
                if shown.count<threads.count || (controller.client.store.historyMode && model.history.threadPages[model.isHome ? "home":current]?.next != nil) {cards.append(lineContent(id:"older",title:controller.client.replayComplete ? "이전 글 보기":"불러오는 중…",older:true))}
                if threads.isEmpty {cards.append(lineContent(id:"empty",title:controller.client.replayComplete ? "아직 표시할 글이 없어요.":"불러오는 중…",top:40))}
                if history.followsAnswer {let visibleRooms=Set(threads.map{ $0.key.employee });for line in model.messages.values where visibleRooms.contains(line.key.employee) && line.streaming && line.role != "owner" {expandedMessages.insert(line.id)}}
                for thread in threads where shown.contains(thread.id) {
                    let timeline=controller.timeline(thread.key)
                    let summary=model.history.summaries[thread.key]
                    let date=summary.map{model.date(model.isHome ? $0.lastTime:$0.rootTime)} ?? (model.isHome ? timeline.map{model.date($0.timestamp)}.max() ?? .distantPast:model.date(timeline.first?.timestamp ?? ""))
                    if previous==nil || !Calendar.current.isDate(previous!,inSameDayAs:date) { cards.append(dayContent(date,id:thread.id)) }
                    cards.append(threadContent(thread));previous=date
                }
                ThreeTapDiagnostics.endSpan("refresh_cards", phase); phase = ThreeTapDiagnostics.startSpan()
                history.show(cards,identity:current,entry:newest(current)?.thread,historyMode:controller.client.store.historyMode)
                model.pinHistoryViewport(history.visibleMessageIDs)
                if enteredPlace != current {enteredPlace=current;let last=threads.last?.key,newest=newest(current);history.enter(newest==last ? nil:newest?.thread)}
    #if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
                if !automatic,!controller.client.store.historyMode,model.timeline(selected).isEmpty,controller.timeline(selected).isEmpty {replyMode=false}
    #endif

            } else { threads=[]; history.show([],identity:"",historyMode:controller.client.store.historyMode) }
            ThreeTapDiagnostics.endSpan("refresh_history", phase); phase = ThreeTapDiagnostics.startSpan()
            let draft=controller.draft
            if !editor.editor.hasMarkedText() && (writingKey != controller.composeKey || editorFontSize != ChatMetrics.bodyFont || MessageFormat.serialize(editor.editor.attributedString(),baseSize:editorFontSize) != draft.text) {
                editor.editor.breakUndoCoalescing(); editor.editor.undoManager?.removeAllActions()
                editor.editor.textStorage?.setAttributedString(MessageFormat.editor(draft.text,bodySize:ChatMetrics.bodyFont))
                editor.editor.typingAttributes=MessageFormat.Style(size:ChatMetrics.bodyFont).attributes;editorFontSize=ChatMetrics.bodyFont;editor.measure()
            }
            displayedKey=selected;writingKey=controller.composeKey;writingPlace=placeNamespace
            refreshInputPresentation()
            if attachmentURLs != draft.attachments {
                let removed=attachments.arrangedSubviews.filter{view in guard let index=attachments.arrangedSubviews.firstIndex(of:view),attachmentURLs.indices.contains(index) else{return true};return !draft.attachments.contains(attachmentURLs[index])}
                for view in removed {attachments.removeArrangedSubview(view)
                    if reduceMotion(){view.removeFromSuperview()}else{NSAnimationContext.runAnimationGroup({ctx in ctx.duration=0.24;ctx.timingFunction=SidebarMotion.curve;view.animator().alphaValue=0;view.animator().setFrameOrigin(view.frame.origin.applying(CGAffineTransform(translationX:0,y:30)))},completionHandler:{view.removeFromSuperview()})}
                }
                let old=attachmentURLs
                for (index,file) in draft.attachments.enumerated() where !old.contains(file) {
                    let chip=AttachmentChip(name:file.lastPathComponent){ [weak self] in self?.controller.removeAttachment(file) };chip.wantsLayer=true;attachments.insertArrangedSubview(chip,at:min(index,attachments.arrangedSubviews.count))
                    if !reduceMotion(){let opacity=CABasicAnimation(keyPath:"opacity");opacity.fromValue=0;opacity.toValue=1;opacity.duration=0.24;opacity.timingFunction=SidebarMotion.curve;chip.layer?.add(opacity,forKey:"attachment-opacity");let position=CABasicAnimation(keyPath:"transform.translation.y");position.fromValue=30;position.toValue=0;position.duration=0.24;position.timingFunction=SidebarMotion.curve;chip.layer?.add(position,forKey:"attachment-position")}
                };attachmentURLs=draft.attachments
            }
            chipMotion.target(draft.attachments.isEmpty ? 0:1,now:motionTime(),immediate:reduceMotion())
            editor.editor.isEditable=selected != nil
            attachButton.isEnabled=selected != nil
            replyButton.isEnabled = model.isHome ? !model.homeThreads.isEmpty : newest(model.selectionIdentity) != nil
            replyButton.isEnabled = replyButton.isEnabled && !replyMode;newButton.isEnabled=replyMode
            replyButton.chosen=replyMode;newButton.chosen = !replyMode;newButton.title=model.isHome ? "새 대화":"새 글"
            replyButton.setAccessibilityLabel("답글"+(replyMode ? ", 선택됨":""));newButton.setAccessibilityLabel(newButton.title+(!replyMode ? ", 선택됨":""))
            for button in [replyButton,newButton,sendButton] { button.needsDisplay=true }
            modeMotion.target(replyMode ? 1:0,now:motionTime(),immediate:reduceMotion())
            notice.stringValue=controller.notice
            ThreeTapDiagnostics.endSpan("refresh_composer", phase); phase = ThreeTapDiagnostics.startSpan()
            refreshWorkspaceBars();scheduleSearch()
            ThreeTapDiagnostics.endSpan("refresh_workspace", phase); phase = ThreeTapDiagnostics.startSpan()
            var islandInput=controller.islandInput;islandInput.drawerOpen=controller.drawerOpen
            islandInput.title=model.selected == nil ? "HEJO.":model.header(model.selectionIdentity).title
            islandInput.todoTotal=controller.drawerSnapshot.total
            islandModel.update(islandInput);tickIsland(updateDrawer:false)
            ThreeTapDiagnostics.endSpan("refresh_island", phase); phase = ThreeTapDiagnostics.startSpan()
            if controller.drawerVisible {todoDrawer.show(controller.drawerSnapshot,filter:controller.drawerFilter,selected:drawerSelectedID)}
            ThreeTapDiagnostics.endSpan("refresh_drawer", phase); phase = ThreeTapDiagnostics.startSpan()
            onUnread?(model.visibleUnreadTotal)
            reportOpenHeight()
            startWorkspaceMotion();needsLayout=true; needsDisplay=true
            ThreeTapDiagnostics.endSpan("refresh_finish", phase)
        }
    }
    override func layout() {
        let span = ThreeTapDiagnostics.startBeforeFirstTickSpan()
        defer { ThreeTapDiagnostics.endSpan("conversation_layout", span) }
        super.layout()
        let w=bounds.width,h=bounds.height,left=min(sidebarWidth,max(0,w-100)), x=left+drawerShownWidth, right=max(1,w-x), list=ConversationSidebar.isList(sidebarWidth)
        todoDrawer.frame=CGRect(x:left,y:0,width:drawerShownWidth,height:h)
        brandDrag.frame=CGRect(x:0,y:0,width:left,height:44); brand.frame=CGRect(x:0,y:7,width:left,height:18); version.frame=CGRect(x:0,y:26,width:left,height:12)
        headerDrag.frame=CGRect(x:x,y:0,width:right,height:44)
        let islandWidth=island.fittedWidth(limit:max(0,right-24))
        island.frame=CGRect(x:x+12,y:7,width:islandWidth,height:30);island.layoutSubtreeIfNeeded()
        if employeeSearch.superview !== sidebarSearch {sidebarSearch.addSubview(employeeSearch)}
        employeeScroll.frame=CGRect(x:0,y:44,width:left,height:max(1,h-72))
        employeeTable.tableColumns.first?.width=employeeScroll.contentSize.width; employeeTable.frame.size.width=employeeScroll.contentSize.width
        brandDrag.isHidden=left==0; brand.isHidden=left==0; version.isHidden=left==0; employeeScroll.isHidden=left==0
        handle.isHidden=left==0;handle.frame=CGRect(x:max(0,x-4),y:0,width:8,height:h)
        sidebarBlank.isHidden=left==0;sidebarBlank.frame=CGRect(x:0,y:max(44,h-28),width:left,height:28)
        addRow.list=list;addRoom.isHidden=left==0 || (list && !employeeSearch.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
        addRoom.title=controller.model.hidden.isEmpty ? "방 추가":"방 추가 (\(controller.model.hidden.count))"
        addRoom.image=NSImage(systemSymbolName:"plus.circle",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:list ? 12:17,weight:.medium))
        addRoom.imagePosition=list ? .imageLeading:.imageOnly;addRoom.alignment=list ? .left:.center
        var y:CGFloat=44
        findRow.isHidden = !searchOpen;findRow.frame=CGRect(x:x,y:y,width:right,height:40); if searchOpen { y+=40 }
        let noticeHeight:CGFloat=notice.stringValue.isEmpty ? 0 : 38, attachmentsHeight:CGFloat=30*chipFraction
        let inputHeight=max(42,editorHeight+22), composerHeight=10+32+6+attachmentsHeight+inputHeight+10
        let failureHeight=CGFloat(failureBar.arrangedSubviews.count)*28
        noticeScroll.isHidden=bannerFraction<=0 || searchOpen || controller.drawerOpen;noticeBar.isHidden=noticeScroll.isHidden;noticeScroll.frame=CGRect(x:x,y:y,width:right,height:38*bannerFraction);noticeScroll.alphaValue=bannerFraction
        noticeBar.frame=CGRect(x:0,y:0,width:max(right,noticeBar.fittingSize.width),height:37)
        CATransaction.begin();CATransaction.setDisableActions(true);noticeBar.layer?.setAffineTransform(CGAffineTransform(translationX:0,y:-38*(1-bannerFraction)));CATransaction.commit()
        if !noticeScroll.isHidden {y+=38*bannerFraction}
        let bottom=max(y,h-composerHeight-noticeHeight-failureHeight)
        history.frame=CGRect(x:x,y:y,width:right,height:max(1,bottom-y)); notice.frame=CGRect(x:x+28,y:bottom+7,width:right-38,height:max(0,noticeHeight-10));noticeIcon.isHidden=noticeHeight==0;noticeIcon.frame=CGRect(x:x+10,y:bottom+9,width:13,height:13)
        failureBar.frame=CGRect(x:x+10,y:bottom+noticeHeight+10+38,width:right-20,height:failureHeight)
        let top=bottom+noticeHeight+10
        let faceHeight:CGFloat=32,rowHeight:CGFloat=32
        let replyWidth=(replyButton.title as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:ComposerModeTrack.point,weight:replyMode ? .semibold:.regular)]).width+20
        let newWidth=(newButton.title as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:ComposerModeTrack.point,weight:replyMode ? .regular:.semibold)]).width+20
        let modeHeight=ComposerModeTrack.height,modeWidth=replyWidth+newWidth+2*ComposerModeTrack.inset,modeY=top+(rowHeight-modeHeight)/2
        modeBackground.frame=CGRect(x:x+10,y:modeY,width:modeWidth,height:modeHeight)
        replyButton.frame=ComposerModeTrack.segment(in:modeBackground.frame,offset:0,width:replyWidth)
        newButton.frame=ComposerModeTrack.segment(in:modeBackground.frame,offset:replyWidth,width:newWidth)
        let natural=CGFloat(composerMembers.count)*34,faceWidth=min(natural,max(0,right-20-modeWidth-8-4))
        composerFaceScroll.frame=CGRect(x:w-10-faceWidth,y:top+(rowHeight-faceHeight)/2,width:faceWidth,height:faceHeight)
        composerFaces.frame=CGRect(x:0,y:0,width:natural,height:faceHeight)
        attachmentScroll.frame=CGRect(x:x+10,y:top+38+failureHeight,width:right-20,height:attachmentsHeight); attachments.frame=CGRect(x:0,y:0,width:max(right-20,attachments.fittingSize.width),height:attachmentsHeight)
        let line=top+38+failureHeight+attachmentsHeight
        attachButton.frame=CGRect(x:x+10,y:line+inputHeight-38,width:38,height:38)
        inputBackground.frame=CGRect(x:x+56,y:line,width:max(1,right-118),height:inputHeight); inputBackground.layer?.cornerRadius=inputHeight/2
        editor.frame=CGRect(x:x+70,y:line+11,width:max(1,right-146),height:max(17,inputHeight-22))
        draftHint.frame=CGRect(x:x+70,y:line+11,width:max(1,right-146),height:20)
        sendButton.frame=CGRect(x:w-52,y:line+inputHeight-42,width:42,height:42)
        history.isHidden=searchOpen;searchResults.isHidden = !searchOpen
        searchResults.frame=history.frame
        layoutSidebarRails()
        drop.frame=CGRect(x:x,y:0,width:right,height:h)
        inputBackground.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.04).cgColor; inputBackground.layer?.borderColor=NSColor.labelColor.withAlphaComponent(0.18).cgColor
    }
    override func draw(_ dirtyRect:NSRect) {
        let span = ThreeTapDiagnostics.startBeforeFirstTickSpan()
        defer { ThreeTapDiagnostics.endSpan("conversation_draw", span) }
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        (dark ? NSColor(white:0.07,alpha:0.4) : .clear).setFill(); bounds.fill()
        let left=min(sidebarWidth,max(0,bounds.width-100)), x=left+drawerShownWidth
        NSColor.labelColor.withAlphaComponent(0.035).setFill(); CGRect(x:x,y:0,width:max(0,bounds.width-x),height:44).fill()
        SidebarTone.column(dark:dark).setFill();CGRect(x:0,y:44,width:left,height:max(0,bounds.height-44)).fill()
        CGRect(x:left,y:44,width:drawerShownWidth,height:max(0,bounds.height-44)).fill()
        if drawerShownWidth>0 {SidebarTone.primary(0.1).setFill();CGRect(x:x-1,y:0,width:1,height:bounds.height).fill()}
        if !noticeScroll.isHidden {NSColor.labelColor.withAlphaComponent(0.04).setFill();CGRect(x:x,y:noticeScroll.frame.minY,width:max(0,bounds.width-x),height:noticeScroll.frame.height).fill();NSColor.labelColor.withAlphaComponent(0.1).setFill();CGRect(x:x,y:noticeScroll.frame.maxY-1,width:max(0,bounds.width-x),height:1).fill()}
        let divideY=modeBackground.frame.minY-10
        SidebarTone.primary(0.1).setFill();CGRect(x:x,y:divideY,width:max(0,bounds.width-x),height:1).fill()
        if !notice.stringValue.isEmpty {SidebarTone.primary(0.06).setFill();CGRect(x:x,y:notice.frame.minY-7,width:bounds.width-x,height:notice.frame.height+10).fill()}
        SidebarTone.primary(0.1).setFill(); CGRect(x:left-1,y:0,width:1,height:bounds.height).fill(); CGRect(x:0,y:43,width:bounds.width,height:1).fill()
    }
    func numberOfRows(in tableView:NSTableView)->Int { renderedSidebarIDs.count }
    func tableView(_ tableView:NSTableView,heightOfRow row:Int)->CGFloat {
        if row==sidebarRows.count {return 40};guard sidebarRows.indices.contains(row) else{return 0}
        switch sidebarRows[row].kind {
        case .search:return 52
        case .gap:return 4
        case .hitHeading:return 26
        case .hit:
            guard let hit=historySidebarSearch.hits.first(where:{$0.id==sidebarRows[row].name}) else {return 44}
            return SidebarHitCell.height(hit.snippet,query:employeeSearch.stringValue,width:sidebarWidth)
        case .divider:return 19
        case .section,.stack:return ConversationSidebar.isList(sidebarWidth) ? 29:36
        default:return ConversationSidebar.isList(sidebarWidth) ? 58:72
        }
    }
    func tableView(_ tableView:NSTableView,rowViewForRow row:Int)->NSTableRowView? {
        SidebarRowView()
    }
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        if row==sidebarRows.count {return addRow};guard sidebarRows.indices.contains(row) else{return nil}
        let data=sidebarRows[row],id=NSUserInterfaceItemIdentifier(data.stableID)
        if data.kind == .search {return sidebarSearch}
        if data.kind == .hit {
            guard let hit=historySidebarSearch.hits.first(where:{$0.id==data.name}) else {return nil}
            let cell=tableView.makeView(withIdentifier:id,owner:nil) as? SidebarHitCell ?? SidebarHitCell(frame:.zero);cell.identifier=id
            cell.configureSnippet(hit.snippet,speaker:hit.role=="owner" ? "나":controller.model.name(hit.speaker),room:controller.model.header(hit.key.room).title,query:employeeSearch.stringValue);return cell
        }
        if data.kind == .hitHeading {
            let cell=tableView.makeView(withIdentifier:id,owner:nil) as? SidebarHitsHeading ?? SidebarHitsHeading(frame:.zero);cell.identifier=id;cell.title.stringValue=data.name;return cell
        }
        if data.kind == .gap {return NSView()}
        let cell=tableView.makeView(withIdentifier:id,owner:nil) as? EmployeeSidebarCell ?? EmployeeSidebarCell(frame:.zero)
        cell.identifier=id;configureSidebarCell(cell,row:data);return cell
    }
    private func configureSidebarCell(_ cell:EmployeeSidebarCell,row:SidebarLayout.Row){
        let model=controller.model,header=row.kind == .section || row.kind == .stack
        cell.row=row;cell.name=row.name;cell.faces=header ? []:row.items.flatMap(\.members).map{(model.name($0),controller.avatar($0))}
        cell.picture=header ? nil:controller.pictures.image(row.picture) ?? (row.kind == .home && model.homeChannel==nil ? homePetImage:nil)
        cell.chosen=row.kind == .home ? model.isHome:!model.isHome && row.kind == .room && row.id==model.selected?.employee
        cell.unread=row.unread;cell.muted=row.kind == .home ? model.home.settings.muted==true:model.muted.contains(row.id);cell.list=ConversationSidebar.isList(sidebarWidth);cell.pinned=model.pinned.contains(row.id);cell.dropTarget=dropSection != nil && row.zone==dropSection
        cell.duration=reduceMotion() || window==nil ? 0:SidebarMotion.duration;cell.refreshChrome()
    }
    private func updateSidebarRows(){
        guard !sidebarUpdating else{return};sidebarUpdating=true;defer{sidebarUpdating=false}
        let ids=sidebarRows.map(\.stableID)+(employeeSearch.stringValue.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !ConversationSidebar.isList(sidebarWidth) ? ["add"]:[])
        let old=renderedSidebarIDs;renderedSidebarIDs=ids
        let heights = ids.indices.map { tableView(employeeTable,heightOfRow:$0) }
        // Ordinary rows have fixed heights. Keep content/selection updates below, but
        // avoid asking AppKit to recreate their layout when those heights did not change.
        // Search rows retain the existing refresh path for live hit text and wrapping.
        let searchRows = sidebarRows.contains { $0.kind == .hit || $0.kind == .hitHeading }
        let changedHeights = IndexSet(ids.indices.filter { searchRows || !renderedSidebarHeights.indices.contains($0) || renderedSidebarHeights[$0] != heights[$0] })
        renderedSidebarHeights = heights
        if old != ids {SidebarMotion.update(employeeTable,old:old,new:ids,animated:!old.isEmpty && !reduceMotion() && window != nil)}
        else if !changedHeights.isEmpty {NSAnimationContext.runAnimationGroup{context in context.duration=reduceMotion() || window==nil ? 0:0.24;context.timingFunction=SidebarMotion.curve;employeeTable.noteHeightOfRows(withIndexesChanged:changedHeights)}}
        for i in sidebarRows.indices {if let cell=employeeTable.view(atColumn:0,row:i,makeIfNecessary:false) as? EmployeeSidebarCell {configureSidebarCell(cell,row:sidebarRows[i])}}
        if let index=rowIndex(for:controller.model.selectionIdentity) {employeeTable.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false)}else{employeeTable.deselectAll(nil)}
        layoutSidebarRails()
    }
    override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();needsLayout=true;needsDisplay=true;effectiveAppearance.performAsCurrentDrawingAppearance{if window != nil {refresh()};layoutSidebarRails()}}
    private func layoutSidebarRails(){
        let headers=sidebarRows.indices.filter{sidebarRows[$0].kind == .section || sidebarRows[$0].kind == .stack},ids=Set(headers.map{sidebarRows[$0].stableID})
        for id in Set(sidebarRails.keys).subtracting(ids) {
            guard let rail=sidebarRails[id] else{continue}
            if reduceMotion() || window==nil {sidebarRails[id]=nil;rail.removeFromSuperlayer()}
            else if rail.opacity != 0 {
                SidebarMotion.change(rail,key:"opacity",to:0.0,duration:0.24)
                DispatchQueue.main.asyncAfter(deadline:.now()+0.24){[weak self,weak rail] in guard let self,let rail,rail.opacity==0,self.sidebarRails[id]===rail else{return};self.sidebarRails[id]=nil;rail.removeFromSuperlayer()}
            }
        }
        employeeTable.wantsLayer=true
        for index in headers {
            let header=sidebarRows[index],id=header.stableID;var last=index
            while last+1<sidebarRows.count && sidebarRows[last+1].kind == .room && sidebarRows[last+1].zone==header.zone {last+=1}
            let first=employeeTable.rect(ofRow:index),bottom=employeeTable.rect(ofRow:last),top=first.midY-9,end=last==index ? top+18:bottom.maxY-10
            let path=CGPath(roundedRect:CGRect(x:ConversationSidebar.isList(sidebarWidth) ? 14:2,y:top,width:2,height:max(18,end-top)),cornerWidth:1,cornerHeight:1,transform:nil)
            let rail:CAShapeLayer
            if let old=sidebarRails[id]{rail=old}else{rail=CAShapeLayer();rail.name="section-rail-"+id;sidebarRails[id]=rail;employeeTable.layer?.addSublayer(rail)}
            let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
            rail.fillColor=SidebarTone.primary(dark ? 0.72:0.42).cgColor
            SidebarMotion.change(rail,key:"opacity",to:1.0,duration:reduceMotion() || window==nil ? 0:0.24)
            SidebarMotion.change(rail,key:"path",to:path,duration:reduceMotion() || window==nil ? 0:0.24)
        }
    }
    func tableView(_ tableView:NSTableView,shouldSelectRow row:Int)->Bool {
        guard sidebarRows.indices.contains(row) else { return false };let item=sidebarRows[row]
        if item.kind == .section || item.kind == .stack { controller.model.toggleSection(item.kind == .stack ? nil : item.zone);return false }
        return item.kind == .room || item.kind == .home || item.kind == .hit || (item.kind == .hitHeading && controller.client.store.historyMode && historySidebarSearch.failed)
    }
    func tableViewSelectionDidChange(_ notification:Notification) {
        if !sidebarUpdating,sidebarRows.indices.contains(employeeTable.selectedRow) {
            let row=sidebarRows[employeeTable.selectedRow]
            if row.kind == .hit {
                if let hit=historySidebarSearch.hits.first(where:{$0.id==row.name}) {revealHistorySearch(hit.conversationKey,id:hit.id)}
                return
            }
            if row.kind == .hitHeading {if historySidebarSearch.failed {historySidebarSearch.retry()};return}
        }
        guard !rendering,!sidebarUpdating,sidebarRows.indices.contains(employeeTable.selectedRow),let employee=Optional(sidebarRows[employeeTable.selectedRow].id) else { return };chooseEmployee(employee) }
    func tableView(_ tableView:NSTableView,pasteboardWriterForRow row:Int)->NSPasteboardWriting? {
        guard sidebarRows.indices.contains(row) else { return nil };let item=sidebarRows[row]
        guard item.kind == .room,item.zone != nil else { return nil }
        let value=NSPasteboardItem();value.setString(item.id,forType:Self.roomDrag);return value
    }
    func tableView(_ tableView:NSTableView,validateDrop info:NSDraggingInfo,proposedRow row:Int,proposedDropOperation operation:NSTableView.DropOperation)->NSDragOperation {
        let visual=employeeTable.presentedRow(at:employeeTable.convert(info.draggingLocation,from:nil))
        let zone=sidebarRows.indices.contains(visual) ? sidebarRows[visual].zone : nil
        guard info.draggingSource as? NSTableView === employeeTable,let id=info.draggingPasteboard.string(forType:Self.roomDrag),let zone,controller.model.sidebar.canMove(id,to:zone) else { dropSection=nil;updateSidebarRows();return [] }
        dropSection=zone;employeeTable.setDropRow(visual,dropOperation:.on);updateSidebarRows();return .move
    }
    func tableView(_ tableView:NSTableView,acceptDrop info:NSDraggingInfo,row:Int,dropOperation:NSTableView.DropOperation)->Bool {
        defer { dropSection=nil;updateSidebarRows() }
        guard let zone=dropSection,let id=info.draggingPasteboard.string(forType:Self.roomDrag),controller.model.sidebar.canMove(id,to:zone) else { return false }
        controller.model.move(id,to:zone);return true
    }
    func tableView(_ tableView:NSTableView,draggingSession session:NSDraggingSession,endedAt screenPoint:NSPoint,operation:NSDragOperation) { dropSection=nil;updateSidebarRows() }
    func controlTextDidChange(_ notification:Notification) {refresh()}
    func control(_ control:NSControl,textView:NSTextView,doCommandBy selector:Selector)->Bool {
        guard control === search else{return false}
        if selector == #selector(NSResponder.moveDown(_:)) {moveSearch(1);return true}
        if selector == #selector(NSResponder.moveUp(_:)) {moveSearch(-1);return true}
        if selector == #selector(NSResponder.insertNewline(_:)) {chooseSearch();return true}
        if selector == #selector(NSResponder.cancelOperation(_:)) {return closeSearchIfOpen()}
        return false
    }
    private struct PostBodyInput: Equatable {
        var id: String
        var original: String
        var shown: String
        var mine: Bool
        var pending: Bool
        var streaming: Bool
        var dark: Bool
        var nameColor: NSColor
        var linkColor: NSColor
        var edge: NSColor?
        var appearance: UInt64
        var highlight: String?
    }
    private func checksMatch(_ cached:PostBody,_ message:ConversationMessage)->Bool {
        return cached.checks.allSatisfy{offset,check in controller.model.check(message.id,line:check.line,original:check.original,body:message.text)==cached.checkValues[offset]}
    }
    private struct PostBody {
        var input: PostBodyInput
        var text: NSAttributedString
        var checks: [Int: (line: Int, original: Bool)]
        var checkValues: [Int: Bool]
    }
    // Derived display values only. A changed input replaces the old value for that post.
    private static let postBodyCapacity = 2048
    private var historyRenderedIDs=Set<String>()
    private var postBodies: [String: PostBody] = [:]
    private var postBodyOrder: [String] = []
    #if HEJO_PERF_TESTING
    var smoothBodyCacheCount: Int { postBodies.count }
    static var smoothBodyCacheCapacity: Int { postBodyCapacity }
    // Copy presentation inputs, never rendered bodies, into an independently created test View.
    func smoothCopyInputs(from source: ConversationView) {
        streamReveal=source.streamReveal;openThread=source.openThread;expandedMessages=source.expandedMessages
        searchHighlight=source.searchHighlight;searchHighlightThread=source.searchHighlightThread
        searchOpen=source.searchOpen;search.stringValue=source.search.stringValue
        highlightedMessageID=source.highlightedMessageID;highlightUntil=source.highlightUntil;drawerSelectedID=source.drawerSelectedID
        windowed=source.windowed;identity=source.identity;enteredPlace=source.enteredPlace
        automatic=source.automatic;replyMode=source.replyMode;autoKeys=source.autoKeys;newKeys=source.newKeys;lastPlaces=source.lastPlaces
        composerAddress=source.composerAddress;writingPlace=source.writingPlace;sidebarWidth=source.sidebarWidth
        drawerShownWidth=source.drawerShownWidth;longReplyBases=source.longReplyBases;longReplyWindowBase=source.longReplyWindowBase
        reduceMotion=source.reduceMotion;motionTime=source.motionTime
        history.automaticallyTicks=false;history.reduceMotion=source.history.reduceMotion;history.clock=source.history.clock
    }
    func smoothClearBodies(){postBodies=[:];postBodyOrder=[]}
    func smoothHighlight(_ text:String?,key:ConversationKey){searchHighlight=text;searchHighlightThread=key}
    func smoothPostPieces(_ message: ConversationMessage,edge:NSColor?=nil) -> [NativeThreadCard.Piece] {
        postPieces(message,conversational:false,edge:edge,extras:false)
    }
    #endif
    private var appearanceObserver: NSObjectProtocol?
    private var editorFontSize=ChatMetrics.bodyFont
    func applyChatAppearance(){refresh();needsLayout=true;needsDisplay=true}
    // Shared by model refresh and editing; never restores text storage or rebuilds history.
    private func refreshInputPresentation() {
        let model=controller.model,draft=controller.draft
        let light=model.homeRecipients.light(text:draft.text,picked:draft.picks.first,replying:replyMode ? model.selected?.employee:nil)
        composerFaces.lit=model.isHome ? light.id.flatMap{composerMembers.firstIndex(of:$0)}:nil
        composerFaces.ring=model.isHome && light.ring
        composerFaces.explicitlyPicked = !replyMode && !draft.picks.isEmpty
        draftHint.stringValue=composerPrompt
        draftHint.isHidden = !editor.editor.string.isEmpty
        editor.editor.setAccessibilityLabel(draftHint.stringValue+" · Enter 보내기, Shift Enter 줄바꿈")
        sendButton.isEnabled=model.selected != nil && controller.canSend && (!draft.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty)
        sendButton.needsDisplay=true
    }
    func textDidChange(_ notification:Notification) {
        if let key=displayedKey { controller.setText(MessageFormat.serialize(editor.editor.attributedString(),baseSize:editorFontSize),for:controller.composeKey ?? key) }
        formatting.refresh(); editor.measure()
        refreshInputPresentation()
        if !editor.editor.hasMarkedText(),editor.editor.rangeForUserCompletion.location != NSNotFound {editor.editor.complete(nil)}
    }
    func textViewDidChangeSelection(_ notification:Notification) { formatting.refresh() }
    func send() {
        let key=sendTarget,source=controller.composeKey ?? displayedKey,homeNew=controller.model.isHome && !replyMode && interruptible==nil
        if key != displayedKey {openThread=key}
        Task {await controller.sendCurrent(for:key,homeNew:homeNew,draftFrom:source)}
    }
    private func restoreNewer() {
        guard controller.client.store.historyMode,let key=openThread else {return}
        let model=controller.model
        let replies=model.messages.values.filter {$0.key==key && $0.id != model.history.summaries[key]?.rootID}
        guard let after=replies.filter({history.visibleMessageIDs.contains($0.id)}).map(\.seq).max() ?? replies.map(\.seq).max() ?? model.history.summaries[key].flatMap({model.messages[$0.rootID]?.seq}) else {return}
        _ = controller.historyLoading.restoreEvicted(key,after:after)
    }
    @objc private func loadOlder() {
        let model=controller.model, scope=model.isHome ? "home":model.selectionIdentity
        if controller.client.store.historyMode,let key=openThread {
            let replies=model.messages.values.filter{$0.key==key && $0.id != model.history.summaries[key]?.rootID}
            let before=replies.filter{history.visibleMessageIDs.contains($0.id)}.map(\.seq).min() ?? replies.map(\.seq).min()
            if controller.historyLoading.restoreEvicted(key,before:before) {return}
        }
        let more=controller.client.store.historyMode && model.history.threadPages[scope]?.next != nil
        if windowed.older(loadedCount:threads.count,hasEarlier:more) {controller.historyLoading.olderThreads()}
        refresh()
    }
    func attachmentPicker()->NSOpenPanel {
        let panel=NSOpenPanel();panel.level = .modalPanel;panel.canChooseDirectories=false;panel.allowsMultipleSelection=true
        panel.message="보낼 사진이나 파일을 고르세요.";panel.prompt="첨부"
        if let folder=FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask).first,FileManager.default.fileExists(atPath:folder.path) {panel.directoryURL=folder}
        return panel
    }
    private func attach() {
        let picker=attachmentPicker();pickingFiles=true;NSApp.activate(ignoringOtherApps:true)
        OptionWindows.prepare(picker)
        chooseFiles(picker) { [weak self] response in self?.pickingFiles=false;if response == .OK {self?.controller.addAttachments(picker.urls)} }
    }
    private func paste(_ board:NSPasteboard)->Bool {
        guard let result=clipboard.read(board,available:max(0,10-controller.draft.attachments.count)) else { return false }
        controller.addAttachments(result.files); if let notice=result.notice { controller.notice=notice }; return true
    }
    private func historyActionPiece(id:String,title:String,invoke:@escaping ()->Void)->NativeThreadCard.Piece {
        .accessory(id:id,height:24,view:{
            let button=FileChip(title:title);button.invoke=invoke;return button
        })
    }
    private func contentReferencePieces(_ key:ConversationKey)->[NativeThreadCard.Piece] {
        var pieces:[NativeThreadCard.Piece]=[]
        if controller.model.evictedHistoryBody(key) != nil {
            pieces.append(historyActionPiece(id:key.readKey+":restore",title:"이전 본문 다시 불러오기") { [weak self] in _ = self?.controller.historyLoading.restoreEvicted(key) })
        }
        if (controller.model.history.messagePages[key]?.newerCount ?? 0)>0 {
            pieces.append(historyActionPiece(id:key.readKey+":latest",title:"최근 답글 보기") { [weak self] in self?.controller.historyLoading.open(key) })
        }
        pieces += controller.model.history.contentReferences.keys.sorted().filter {controller.model.history.contentKeys[$0] == key}.map { id in
            historyActionPiece(id:id+":content",title:"긴 원문 불러오기") { [weak self] in self?.controller.historyLoading.content(id,key:key) }
        }
        return pieces
    }
    private func unloadedThreadContent(_ thread:ConversationThread,summary:HistoryThreadSummary?,messages:[ConversationMessage],expanded:Bool)->NativeThreadCard.Content {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let pick:()->Void={ [weak self] in self?.chooseThread(thread.key) }
        var top:[NativeThreadCard.Piece]=[.accessory(id:thread.id+":summary",height:72,view:{
            let label=NSTextField(wrappingLabelWithString:(summary?.rootPreview ?? thread.title)+"\n원문을 아직 불러오지 않았어요")
            label.font = .systemFont(ofSize:ChatMetrics.bodyFont);label.textColor = .secondaryLabelColor
            label.maximumNumberOfLines=3;return label
        })]
        top.append(historyActionPiece(id:thread.id+":open",title:"원문 불러오기") { [weak self] in
            guard let self else{return}
            self.openThread=thread.key;self.controller.model.select(thread.key,inHome:self.controller.model.isHome,markRead:false)
            self.controller.historyLoading.open(thread.key)
        })
        var replies:[NativeThreadCard.Piece]=contentReferencePieces(thread.key)
        if controller.model.history.messagePages[thread.key]?.next != nil {
            replies.append(historyActionPiece(id:thread.id+":older",title:"이전 답글 보기") { [weak self] in self?.controller.historyLoading.olderMessages(thread.key) })
        }
        // A recent reply does not become the root when the root is outside the page.
        for message in messages where message.id != summary?.rootID {replies += postPieces(message,conversational:true,edge:nil)}
        return .init(id:thread.id,top:top,replies:replies.isEmpty ? nil:replies,rail:nil,actions:[.init(title:historyCopyKey==thread.key ? historyCopyProgress+" · 취소":"전체 복사",symbol:"doc.on.doc",label:"스레드 전체 복사",identifier:"copy-"+thread.id,color:.secondaryLabelColor,invoke:{[weak self] in self?.copyHistory(thread.key)})],deleting:nil,
            style:.init(inset:ThreadAppearance.inset,fill:0,stroke:NSColor.labelColor.withAlphaComponent(0.16),lineWidth:1,background:ThreadAppearance.surface(dark:dark),replyBackground:ThreadAppearance.replySurface(dark:dark)),
            bell:summary?.bell,onBell:{[weak self] in self?.controller.model.toggleBell(thread.key)},clickCard:pick,textClick:nil,
            bubbleWidth:max(ChatMetrics.minimumBubbleWidth,(bounds.width-sidebarWidth-drawerShownWidth)*ChatMetrics.bubbleWidthFraction),quiet:.secondaryLabelColor,expanded:expanded)
    }
    func threadContent(_ thread:ConversationThread)->NativeThreadCard.Content {
        let model=controller.model,messages=controller.timeline(thread.key),expanded=openThread==thread.key
        let summary=model.history.summaries[thread.key]
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        let actualRoot=controller.client.store.historyMode ? (summary.flatMap { value in messages.first{$0.id==value.rootID} } ?? messages.first{$0.pending}):messages.first
#else
        let actualRoot=summary.flatMap { value in messages.first{$0.id==value.rootID} } ?? messages.first{$0.pending}
#endif
        guard let root=actualRoot else {return unloadedThreadContent(thread,summary:summary,messages:messages,expanded:expanded)}
        let replies=messages.filter{$0.id != root.id},foldable=replies.count>2
        let state=model.assessment(thread.key)
        let shown=expanded || !foldable ? replies:replies.filter{$0.id==replies.last?.id || state.buttons.contains($0.id)}
        let hidden=replies.count-shown.count,dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let pick:()->Void={ [weak self] in self?.chooseThread(thread.key) }
        let owner=model.groups[thread.key.employee]==nil ? thread.key.employee:messages.first{$0.role=="employee"}?.speaker
        let edge=owner.map{controller.avatar($0).color}
        var top=postPieces(root,conversational:false,edge:edge)
        if model.isHome,model.homeChannel==nil,root.role=="owner" {top.insert(.accessory(id:"home-owner:"+thread.key.readKey,height:28,view:{ [weak controller] in HomeOwnerView(name:model.name(root.speaker),avatar:controller?.avatar(root.speaker) ?? ProfileAvatar()) }),at:0)}
        var answer:[NativeThreadCard.Piece]=controller.client.store.historyMode ? contentReferencePieces(thread.key):[]
        if controller.client.store.historyMode,model.history.messagePages[thread.key]?.next != nil {
            answer.append(historyActionPiece(id:thread.id+":older",title:"이전 답글 보기") { [weak self] in self?.controller.historyLoading.olderMessages(thread.key) })
        }
        if hidden>0 {
            let faces=ThreadTools.answeredFaces(replies).map{(model.name($0),controller.avatar($0))}
            answer.append(.stack(faces:faces,title:"이전 답글 \(hidden)개",toggle:{ [weak self] in self?.togglePile(thread.key) },identifier:"stack-"+thread.id))
        }
        let shownIDs=Set(shown.map(\.id))
        for (index,message) in replies.enumerated() where shownIDs.contains(message.id) {
            let previous=index>0 ? replies[index-1]:nil
            let continuation=message.role != "owner" && previous.map{shownIDs.contains($0.id) && $0.role != "owner" && $0.speaker==message.speaker} == true
            answer += postPieces(message,conversational:true,edge:edge,continuation:continuation)
        }
        if controller.interruptions[thread.key] != nil {
            answer.append(.accessory(id:thread.id+":interruption",height:16,view:{
                let label=NSTextField(labelWithString:"끼어들었어요");label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);label.textColor = CardText.quiet(dark:dark)
                return label
            }))
        }
        if controller.working(thread.key) || controller.stopped.contains(thread.key) {
            if controller.stopped.contains(thread.key) {
                answer.append(.accessory(id:thread.id+":undo",height:24,view:{ [weak self] in
                    let row=NSStackView();row.spacing=6
                    let label=NSTextField(labelWithString:"중지를 요청했어요");label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);label.textColor=CardText.quiet(dark:dark);row.addArrangedSubview(label)
                    let undo=FileChip(title:"되돌리기");undo.controlSize = .small;undo.toolTip="이미 바꾼 것을 먼저 목록으로 보여 달라고 하고, 확인한 뒤 원래대로 되돌리게 해요";undo.isEnabled=self?.controller.canSend==true;undo.invoke={ [weak self] in Task { [key=thread.key] in await self?.controller.sendText(ThreadTools.undo,key:key)} };row.addArrangedSubview(undo)
                    return MessageAccessory(row,limit:row.fittingSize.width)
                }))
            } else {
                let since=messages.last(where:{$0.role=="owner"}).map{ThreadTools.date($0.timestamp)} ?? ThreadTools.date(root.timestamp)
                let thinkers=Set(messages.filter{$0.role != "owner" && (controller.model.thinking($0) || $0.streaming)}.map(\.speaker))
                let people=(model.typingPeople[thread.key] ?? [:]).keys.sorted()
                for person in people where !thinkers.contains(person) {
                    if controller.interruptions[thread.key]==nil,let last=shown.last,last.role != "owner",last.speaker==person {continue}
                    answer.append(.accessory(id:thread.id+":typing:"+person,height:34,view:{[weak controller] in TypingBubbleView(name:model.name(person),avatar:controller?.avatar(person) ?? ProfileAvatar(),nameColor:controller?.palette(person,dark:dark).name.nsColor,activity:"답변을 준비하고 있습니다")}))
                }
                let activity=messages.last(where:{$0.role != "owner" && controller.model.thinking($0)})?.text.components(separatedBy:"\n").dropFirst().first ?? (messages.contains(where:{$0.streaming}) ? "답변을 작성하고 있습니다":"답변을 준비하고 있습니다")
                answer.append(.accessory(id:thread.id+":work",height:WorkingControlRow.height(activity,width:max(1,bounds.width-sidebarWidth-drawerShownWidth-36),seconds:max(0,Int(controller.clock().timeIntervalSince(since)))),view:{ [weak self] in
                    let control=WorkingControlRow(since:since,activity:activity,clock:{self?.islandModel.now ?? Date()},animationTime:{self?.motionTime() ?? 0},reduceMotion:{self?.reduceMotion() ?? true},stop:{ [weak self] in Task { [key=thread.key] in await self?.controller.stop(key)} });control.button.isEnabled=self?.controller.canSend==true;control.alphaValue=self?.controller.canSend==true ? 1:0.4;return control
                }))
            }
        }
        let tone=(state.pendingID != nil ? AttentionRail.color:state.color.flatMap(MessageFormat.color)) ?? (controller.working(thread.key) ? MessageFormat.color("#ECB22E"):state.requestID==nil && state.request==nil ? messages.lazy.compactMap{ThreadTools.color($0.text)}.first:nil)
        let target=replyMode && model.selected==thread.key
        let highlighted=messages.contains{$0.id==highlightedMessageID} && (highlightUntil.map{$0>islandModel.now} ?? (drawerSelectedID != nil))
        let now=controller.clock(),copiedLink=copiedID=="link:"+thread.id,copiedText=copiedID=="text:"+thread.id
        let branchAsked=controller.branching[thread.key].map{now.timeIntervalSince($0)<6} ?? false
        let sure=controller.confirmingDelete[thread.key].map{now.timeIntervalSince($0)<4} ?? false
        let quiet=CardText.quiet(dark:dark),accent=NSColor.controlAccentColor
        var actions:[NativeThreadCard.Action]=[
            .init(title:copiedLink ? "복사됨":"링크",symbol:copiedLink ? "checkmark":"link",label:"스레드 링크 복사",identifier:"copy-link-"+thread.id,color:copiedLink ? accent:quiet,invoke:{ [weak self] in self?.copyText(ThreadTools.link(thread.key).absoluteString,id:"link:"+thread.id) }),
            .init(title:historyCopyKey==thread.key ? historyCopyProgress+" · 취소":copiedText ? "복사됨":"복사",symbol:copiedText ? "checkmark":"doc.on.doc",label:"스레드 전체 복사",identifier:"copy-"+thread.id,color:copiedText ? accent:quiet,invoke:{ [weak self] in guard let self else{return};
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
                if !self.controller.client.store.historyMode {self.copyText(ThreadTools.copy(messages,key:thread.key,name:self.controller.model.name,group:self.controller.model.groups[thread.key.employee] != nil),id:"text:"+thread.id);return}
#endif
                self.copyHistory(thread.key)
             })]
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        let hasEmployee=controller.client.store.historyMode ? summary?.activity.latestEmployeeTime != nil:messages.contains(where:{$0.role=="employee"})
        let replyCount=controller.client.store.historyMode ? max(0,(summary?.messageCount ?? 1)-1):replies.count
#else
        let hasEmployee=summary?.activity.latestEmployeeTime != nil
        let replyCount=max(0,(summary?.messageCount ?? 1)-1)
#endif
        if !root.pending,hasEmployee {actions.append(.init(title:"분기",symbol:branchAsked ? "checkmark":"arrow.triangle.branch",label:"새 스레드로 이어가기",identifier:"branch-"+thread.id,enabled:controller.canSend && !branchAsked,color:branchAsked ? accent:replyCount>=50 ? .systemOrange:quiet,invoke:{ [weak self] in Task { [key=thread.key] in await self?.controller.branch(key)} }))}
        if !root.pending,!controller.deleting.contains(thread.key),(replyCount==0 ? root.role=="owner":model.selected==thread.key) {actions.append(.init(title:sure ? "정말 삭제":"삭제",symbol:"trash",label:sure ? "스레드 삭제 확인":"스레드 삭제",identifier:"delete-"+thread.id,enabled:controller.canSend,color:sure ? .systemRed:quiet,alwaysLabel:sure,invoke:{ [weak self] in Task { [key=thread.key] in await self?.controller.deleteThread(key)} }))}
        if foldable && expanded {actions.append(.init(title:"접기",symbol:"chevron.up",label:"접기",identifier:"fold-"+thread.id,color:quiet,alwaysLabel:true,invoke:{ [weak self] in self?.togglePile(thread.key) }))}
        return .init(id:thread.id,top:top,replies:answer.isEmpty ? nil:answer,rail:nil,actions:actions,deleting:controller.deleting.contains(thread.key) ? "삭제 중…":nil,
            style:.init(inset:ThreadAppearance.inset,fill:0,stroke:highlighted ? .controlAccentColor:target ? .controlAccentColor:NSColor.labelColor.withAlphaComponent(dark ? 0.16:0.12),lineWidth:highlighted ? 2:target ? 1.5:1,background:ThreadAppearance.surface(dark:dark),status:tone,replyBackground:ThreadAppearance.replySurface(dark:dark)),
            bell:model.bell(thread.key),onBell:{ [weak self] in self?.controller.model.toggleBell(thread.key) },clickCard:pick,textClick:!expanded && foldable ? pick:nil,
            bubbleWidth:max(ChatMetrics.minimumBubbleWidth,(bounds.width-sidebarWidth-drawerShownWidth)*ChatMetrics.bubbleWidthFraction),quiet:quiet,expanded:expanded,replyTarget:target)
    }
    static let unavailableReply="정해진 버튼이 아니라 누를 수 없어요. 이 스레드에 글로 답해 주세요."
    private func postPieces(_ message:ConversationMessage,conversational:Bool,edge:NSColor?,extras:Bool=true,continuation:Bool=false)->[NativeThreadCard.Piece] {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua, mine=message.role == "owner"
        if !mine,continuation,controller.model.thinking(message) {return []}
        if !mine,controller.model.thinking(message) {return [.accessory(id:message.id+":thinking",height:34,view:{[weak controller] in TypingBubbleView(name:controller?.model.name(message.speaker) ?? "",avatar:controller?.avatar(message.speaker) ?? ProfileAvatar(),nameColor:controller?.palette(message.speaker,dark:dark).name.nsColor,activity:message.text.components(separatedBy:"\n").dropFirst().first ?? "답변을 준비하고 있습니다")} )]}
        let received=streamReveal.frame(message.id,now:motionTime(),immediately:reduceMotion()) ?? message.text
        let streaming=message.streaming || streamReveal.revealing(message.id)
        let foldable = !mine && !streaming && LongReply.needsFolding(message.text), folded=foldable && !expandedMessages.contains(message.id) && searchHighlightThread != message.key
        let shown=folded ? LongReply.preview(received):received
        let palette=controller.palette(message.speaker,dark:dark)
        let input=PostBodyInput(id:message.id,original:message.text,shown:shown,mine:mine,pending:message.pending,streaming:streaming,dark:dark,
            nameColor:palette.name.nsColor,linkColor:palette.link.nsColor,edge:edge,appearance:ChatAppearance.revision,
            highlight:message.key==searchHighlightThread ? searchHighlight:nil)
        if controller.model.store.historyMode {historyRenderedIDs.insert(message.id)}
        let rendered:PostBody
        if let cached=postBodies[message.id],input==cached.input,checksMatch(cached,message) {rendered=cached}
        else {
            let body=CardText.fittedRules(mine ? shown:shown.trimmingCharacters(in:.newlines)),stripped=TextLayout.strip(body)
            #if HEJO_PERF_TESTING
            HejoSmoothProbe.bodies[message.id, default: 0] += 1
            #endif
            let text=NSMutableAttributedString(attributedString:CardText.linkifiedNative(MessageFormat.renderNative(mine ? body : stripped.source,bodySize:ChatMetrics.bodyFont)))
            let all=NSRange(location:0,length:text.length), paragraph=NSMutableParagraphStyle(); paragraph.lineSpacing=mine ? 0 : 2
            text.addAttribute(.paragraphStyle,value:paragraph,range:all)
            if mine {
                text.enumerateAttributes(in:all) { attributes,range,_ in
                    if attributes[NSAttributedString.Key("hejo.explicitColor")]==nil {text.addAttribute(.foregroundColor,value:UserBubblePalette(dark:dark,pending:message.pending).foreground.nsColor,range:range)}
                }
            }
            else { TextLayout.apply(to:text,lines:stripped.lines,bar:edge,lineSpacing:2) }
            text.enumerateAttributes(in:NSRange(location:0,length:text.length)) { attributes,range,_ in
                if !mine,let font=attributes[.font] as? NSFont,NSFontManager.shared.traits(of:font).contains(.fixedPitchFontMask) {
                    text.addAttributes([.font:NSFont.monospacedSystemFont(ofSize:13,weight:.regular),.foregroundColor:dark ? NSColor(srgbRed:0.96,green:0.68,blue:0.36,alpha:1) : NSColor(srgbRed:0.76,green:0.32,blue:0.09,alpha:1),.backgroundColor:NSColor.labelColor.withAlphaComponent(0.1)],range:range)
                }
                if attributes[.link] != nil { text.addAttributes([.underlineStyle:NSUnderlineStyle.single.rawValue,.foregroundColor:mine ? UserBubblePalette(dark:dark,pending:message.pending).link.nsColor : palette.link.nsColor],range:range) }
            }
            if streaming {CardText.uniformSize(text)}
            if let query=searchHighlight,message.key==searchHighlightThread {for range in WorkspaceSearch.highlights(text.string,query:query) {text.addAttributes([.backgroundColor:NSColor.yellow,.foregroundColor:NSColor.black],range:NSRange(range,in:text.string))}}
            var checks:[Int:(line:Int,original:Bool)]=[:],checkValues:[Int:Bool]=[:]
            if !streaming && !message.pending {
                var offset=0,index=0
                for character in text.string {
                    let length=String(character).utf16.count
                    if character=="☐" || character=="☑" {
                        let original=character=="☑";checks[offset]=(index,original)
                        let checked=controller.model.check(message.id,line:index,original:original,body:message.text);checkValues[offset]=checked
                        text.replaceCharacters(in:NSRange(location:offset,length:length),with:checked ? "☑":"☐")
                        text.addAttribute(.link,value:URL(string:"hejo-check://toggle/\(offset)")!,range:NSRange(location:offset,length:1))
                    }
                    index+=1;offset+=length
                }
            }
            rendered=PostBody(input:input,text:NSAttributedString(attributedString:text),checks:checks,checkValues:checkValues)
            if postBodies[message.id]==nil {
                if postBodies.count>=Self.postBodyCapacity {postBodies.removeValue(forKey:postBodyOrder.removeFirst())}
                postBodyOrder.append(message.id)
            }
            postBodies[message.id]=rendered
        }
        let text=rendered.text,checks=rendered.checks
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.identify(text,id:message.id)
        #endif
        let messageID=message.id,checkBody=checks.isEmpty ? "":message.text
        var post=NativeThreadCard.Post(id:message.id,mine:mine,text:text,speaker:mine ? "나" : controller.model.name(message.speaker),time:message.pending ? "보내는 중":displayTime(message),avatar:controller.avatar(message.speaker),nameColor:mine ? .labelColor:palette.name.nsColor,
            conversational:conversational && !mine && !streaming && message.files.isEmpty && ThreadAppearance.isConversational(message.text),pending:message.pending,streaming:streaming,
            marks:[],foldTitle:foldable ? (folded ? "더 보기" : "접기") : nil,fold:{ [weak self] in guard let self else { return }; if self.expandedMessages.contains(messageID) { self.expandedMessages.remove(messageID);self.longReplyBases[messageID]=nil;if self.longReplyBases.isEmpty {self.longReplyWindowBase=nil} } else { if self.longReplyWindowBase==nil {self.longReplyWindowBase=self.bounds.height};self.longReplyBases[messageID]=self.history.layouts.lazy.flatMap(\.placed).first{if case .post(let p)=$0.piece{return p.id==messageID};return false}?.frame.height;self.expandedMessages.insert(messageID) }; self.refresh() },textHelp:!message.files.isEmpty && text.string.contains(where:{$0=="☐" || $0=="☑"}) ? "체크박스를 누르면 내 확인 상태를 저장합니다.":nil,openLink:{ [weak self] url in
                guard let self else{return}
                if url.scheme=="hejo-check",let offset=Int(url.lastPathComponent),let check=checks[offset] {self.controller.model.toggleCheck(messageID,line:check.line,original:check.original,body:checkBody)}
                else if url.scheme=="hejo" {self.controller.openLink(url)}
                else if CardText.mayOpen(url) {self.onOpenURL(url)}
            })
        post.flash=message.id==highlightedMessageID && (highlightUntil.map{$0>islandModel.now} ?? (drawerSelectedID != nil))
        if !mine,continuation {post.continuation=true;if post.textHelp==nil {post.textHelp=post.time}}
        var pieces:[NativeThreadCard.Piece]=[.post(post)]
        if !extras {return pieces}
        let calendarActions = controller.calendarActions(for: message)
        if !calendarActions.isEmpty {
            pieces.append(.accessory(id:message.id+":calendar",height:22,view:{ [weak self] in
                let row = NSStackView(); row.orientation = .horizontal; row.spacing = 6
                for action in calendarActions {
                    let button = FileChip(title:action.title);button.bezelStyle = .rounded;button.isBordered = true;button.controlSize = .small
                    button.font = .systemFont(ofSize:NSFont.smallSystemFontSize);button.setAccessibilityLabel(action.title)
                    button.invoke = { [weak self] in if case .calendar(let events) = action { self?.onCalendar?(events) } }
                    row.addArrangedSubview(button)
                }
                return MessageAccessory(row, limit:10000,top:2)
            }))
        }
        let fileSpeaker=message.speaker,fileDate=ThreadTools.date(message.timestamp)
        for file in message.files {
            if message.pending {pieces.append(.accessory(id:file.id,height:28,view:{MessageAccessory(NSTextField(labelWithString:file.name),mine:mine,limit:240)}));continue}
            let picture=thumbnails.image(file.id),size=file.mime.hasPrefix("image/") ? FileTile.frameSize(picture):CGSize(width:240,height:FileTile.documentHeight)
            pieces.append(.accessory(id:file.id,height:size.height,view:{ [weak self] in
                if file.mime.hasPrefix("image/") {self?.requestThumbnail(file,employee:fileSpeaker)}
                let tile=FileTile(file:file);tile.picture=self?.thumbnails.image(file.id);tile.failed=self?.failedThumbnails.contains(file.id)==true;tile.busy=self?.busyFiles.contains(file.id)==true
                tile.invoke={ [weak self] in guard let self else{return};self.busyFiles.insert(file.id);self.refresh();Task {
                    if await self.controller.open(file,employee:fileSpeaker,date:fileDate) {self.failedThumbnails.remove(file.id)}else{self.failedThumbnails.insert(file.id)}
                    self.busyFiles.remove(file.id);self.refresh()
                }}
                return MessageAccessory(tile,mine:mine,limit:size.width)
            }))
        }
        let actionKey=message.key,actionSpeaker=message.speaker,actionButtons=message.buttons
        let pending=controller.model.assessment(message.key).buttons.contains(message.id)
        if let checklist=controller.checklistSelection(message),pending {
            pieces.append(.accessory(id:message.id+":checklist",height:ReplyChecklistView.height(checklist.items,width:max(1,bounds.width-sidebarWidth-drawerShownWidth-36-43),selected:Set(checklist.selected)),view:{ [weak self] in
                let choices=ReplyChecklistView(checklist,changed:{ [weak self] selected in self?.controller.selectChecklist(message,selected:selected) }) { [weak self] text in Task { [actionKey,actionSpeaker] in await self?.controller.sendText(text,key:actionKey,recipient:actionSpeaker)} }
                return MessageAccessory(choices,limit:10000)
            }))
        }
        if pending,message.checklist==nil {
            let labels=message.buttons.isEmpty ? ReplyButtonPolicy.standard:message.buttons.map(\.label)
            let pressable=message.buttons.contains{$0.kind != "reply"} || ReplyButtonPolicy.pressable(labels,message:message)
            pieces.append(.accessory(id:message.id+":buttons",height:32,view:{ [weak self] in
                let column=NSStackView();column.orientation = .vertical;column.alignment = .leading;column.spacing=4
                let stack=NSStackView();stack.orientation = .horizontal;stack.spacing=8
                for (index,label) in labels.enumerated() {
                    let word=ReplyButtonPolicy.word(label)
                    let button=FileChip(title:word);button.replyWord=word;button.isBordered=false
                    button.toolTip = !pressable ? Self.unavailableReply : word=="확인" && message.buttons.isEmpty ? "메시지를 보내지 않고 넘어가기":word
                    button.setAccessibilityLabel(word);button.font = .systemFont(ofSize:11)
                    button.isEnabled=pressable && (word=="의견" || (word=="확인" && message.buttons.isEmpty) || self?.controller.canSend==true)
                    button.invoke={ [weak self] in
                        guard let self,pressable,self.controller.model.assessment(message.key).buttons.contains(message.id) else{return}
                        self.replyMode=true;self.openThread=message.key;self.controller.model.select(message.key)
                        if !message.buttons.isEmpty {Task { [actionButtons,messageID,actionKey] in await self.controller.click(actionButtons[index],messageID:messageID,key:actionKey,buttons:actionButtons)}}
                        else if word=="확인" {self.controller.model.confirm(message)}
                        else if word=="의견" {self.window?.makeFirstResponder(self.editor.editor)}
                        else {Task { [actionKey,actionSpeaker] in await self.controller.sendText(word,key:actionKey,recipient:actionSpeaker)}}
                    }
                    stack.addArrangedSubview(button)
                }
                column.addArrangedSubview(stack)
                let scroll=NSScrollView();scroll.drawsBackground=false;scroll.hasHorizontalScroller=true;scroll.autohidesScrollers=true;scroll.scrollerStyle = .overlay
                let content=ThreadControls();content.addSubview(column);column.frame=CGRect(origin:.zero,size:column.fittingSize);content.frame=column.frame;scroll.documentView=content
                let control=ThreadControls();control.addSubview(scroll);scroll.frame=CGRect(x:0,y:0,width:message.buttons.isEmpty ? column.fittingSize.width:320,height:32);scroll.autoresizingMask=[.width,.height]
                return MessageAccessory(control,limit:message.buttons.isEmpty ? column.fittingSize.width:320,top:2)
            }))
        }
        if pending,!mine,message.files.isEmpty,let parts=ReplyButtonPolicy.split(message.text) {
            var head=message,detail=message;head.text=parts.head;detail.text=parts.detail;detail.id += ":detail"
            let first=postPieces(head,conversational:false,edge:edge,extras:false,continuation:continuation)
            let rest=postPieces(detail,conversational:false,edge:edge,extras:false).map { piece -> NativeThreadCard.Piece in
                if case .post(var post)=piece {post.continuation=true;return .post(post)};return piece
            }
            return first+Array(pieces.dropFirst())+rest
        }
        return pieces
    }
    private func togglePile(_ key:ConversationKey) {openThread=openThread==key ? nil:key;if openThread != key,searchHighlightThread==key {searchHighlight=nil;searchHighlightThread=nil};refresh();if openThread==key {if controller.client.store.historyMode {controller.historyLoading.open(key)};history.scrollTo(key.thread,bottom:true)}}
    private func requestThumbnail(_ file:MessageFile,employee:String) {
        guard thumbnails.image(file.id)==nil,!failedThumbnails.contains(file.id),!fetchingThumbnails.contains(file.id) else{return}
        fetchingThumbnails.insert(file.id)
        let stamp=controller.files.fileAccessIdentity
        Task { [weak self] in
            guard let self else{return}
            do {let url=try await self.controller.files.download(file,employee:employee);guard !self.controller.client.store.historyMode || self.controller.files.fileAccessIdentity==stamp else {return};_ = try self.thumbnails.load(url,id:file.id)}
            catch {guard !self.controller.client.store.historyMode || self.controller.files.fileAccessIdentity==stamp else {return};self.failedThumbnails.insert(file.id)}
            self.fetchingThumbnails.remove(file.id);self.refresh()
        }
    }
    func copyHistory(_ key:ConversationKey) {
        if historyCopyKey==key {historyCopyTask?.cancel();historyCopyTask=nil;historyCopyKey=nil;historyCopyGeneration=UUID();refresh();return}
        historyCopyTask?.cancel();historyCopyGeneration=UUID();let generation=historyCopyGeneration
        historyCopyKey=key;historyCopyProgress="복사 준비 중";refresh()
        historyCopyTask=Task { [weak self] in
            guard let self else{return}
            do {
                let text=try await self.controller.historyLoading.copy(key) { done,total in
                    self.historyCopyProgress="\(done)/\(total)개";self.refresh()
                }
                try Task.checkCancellation()
                guard self.historyCopyGeneration==generation else{return}
                self.copyText(text,id:"text:"+key.thread)
            } catch {
                if !(error is CancellationError),self.historyCopyGeneration==generation {
                    self.controller.notice="전체 복사를 완료하지 못했어요. 다시 시도해 주세요."
                }
            }
            guard self.historyCopyGeneration==generation else{return}
            self.historyCopyTask=nil;self.historyCopyKey=nil;self.refresh()
        }
    }
    private func copyText(_ text:String,id:String) {
        clipboardBoard.clearContents();clipboardBoard.setString(text,forType:.string)
        copiedID=id;refresh();DispatchQueue.main.asyncAfter(deadline:.now()+1.6) { [weak self] in if self?.copiedID==id {self?.copiedID=nil;self?.refresh()} }
    }
    private func historyStatusContent(failed:Bool)->NativeThreadCard.Content {
        var card=lineContent(id:"history-status",title:failed ? "대화를 불러오지 못했어요":"대화를 갱신하고 있어요…")
        if failed {card.top.append(historyActionPiece(id:"history-retry",title:"다시 시도") { [weak self] in self?.controller.historyLoading.retry() })}
        return card
    }
    private func dayContent(_ date:Date,id:String)->NativeThreadCard.Content {
        let title=CardText.day(date)
        return .init(id:"date:"+id,top:[.accessory(id:"date-label:"+id,height:14,view:{
            let label=NSTextField(labelWithString:title);label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);label.textColor = CardText.quiet(dark:self.effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua);label.alignment = .center;return label
        })],replies:nil,rail:nil,actions:[],deleting:nil,style:.init(inset:0,fill:0,stroke:nil,lineWidth:0,background:.clear),bell:nil,onBell:{},clickCard:{},textClick:nil,bubbleWidth:500,quiet:.secondaryLabelColor,expanded:false)
    }
    private func lineContent(id:String,title:String,top:CGFloat=0,older:Bool=false)->NativeThreadCard.Content {
        .init(id:"line:"+id,top:[.accessory(id:id,height:top+(older ? 16:14),view:{[weak self] in
            let controls=ThreadControls()
            if older {let button=FileChip(title:title);button.isBordered=false;button.font = .systemFont(ofSize:11);button.isEnabled=self?.controller.client.replayComplete==true;button.invoke={self?.loadOlder()};controls.addSubview(button);button.frame=CGRect(x:0,y:top,width:500,height:18);button.autoresizingMask = [.width]}
            else {let label=NSTextField(labelWithString:title);label.alignment = .center;label.font = .systemFont(ofSize:11);label.textColor=CardText.quiet(dark:self?.effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua);controls.addSubview(label);label.frame=CGRect(x:0,y:top,width:500,height:18);label.autoresizingMask = [.width]}
            return controls
        })],replies:nil,rail:nil,actions:[],deleting:nil,style:.init(inset:0,fill:0,stroke:nil,lineWidth:0,background:.clear),bell:nil,onBell:{},clickCard:{},textClick:nil,bubbleWidth:500,quiet:.secondaryLabelColor,expanded:false)
    }
    private struct DisplayTimeInput:Equatable {let timestamp:String;let locale:Locale;let zone:TimeZone;let calendar:Calendar}
    private var displayTimes:[String:(input:DisplayTimeInput,text:String)]=[:]
    private var displayTimeOrder:[String]=[]
    private func displayTime(_ message:ConversationMessage)->String {
        let input=DisplayTimeInput(timestamp:message.timestamp,locale:.current,zone:.current,calendar:.current)
        if let cached=displayTimes[message.id],cached.input==input {return cached.text}
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.times[message.id,default:0]+=1
        #endif
        let value=message.timestamp

        let formatter=ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let text=(formatter.date(from:value) ?? ISO8601DateFormatter().date(from:value)).map{DateFormatter.localizedString(from:$0,dateStyle:.none,timeStyle:.short)} ?? ""
        if displayTimes[message.id]==nil {
            if displayTimeOrder.count>=Self.postBodyCapacity {displayTimes[displayTimeOrder.removeFirst()]=nil}
            displayTimeOrder.append(message.id)
        }
        displayTimes[message.id]=(input,text)
        return text
    }
}
