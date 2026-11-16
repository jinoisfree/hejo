import AppKit
import UniformTypeIdentifiers

/// AppKit translation of the reviewed workspace, room strip, card stack and composer.
@MainActor final class ConversationView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSearchFieldDelegate {
    let controller: ConversationController
    let island=IslandView(frame:.zero)
    let islandModel:IslandModel
    /// Animation clock and reduced-motion switch for in-chat typing shimmer; checks inject both.
    var motionTime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var islandTimer:Timer?
    private var copiedID:String?
    private(set) var highlightedMessageID:String?
    private var highlightUntil:Date?
    var reconnect:()->Void
    var retrySend:(ConversationKey)->Void
    let employeeTable = EmployeeMenuTable(), history = NativeThreadList(frame:.zero), editor = DraftScrollView(frame:.zero)
    let headerDrag = ConversationHeaderDrag(), brandDrag = ConversationHeaderDrag()
    private let employeeScroll=EmployeeMenuScroll(), employeeSearch=NSSearchField(), search=NSSearchField()
    let brand=PassiveLabel(labelWithString:"HEJO."), version=PassiveLabel(labelWithString:""), heading=PassiveLabel(labelWithString:""), subtitle=PassiveLabel(labelWithString:"함께 나누는 대화")
    private let handle=SidebarHandle(), sidebarToggle=ComposerButton(title:"직원 목록",symbol:"sidebar.left",point:12), searchToggle=ComposerButton(title:"검색",symbol:"magnifyingglass",point:12)
    let notice=NSTextField(wrappingLabelWithString:"")
    private let attachments=NSStackView(), attachmentScroll=NSScrollView()
    private let replyButton=ComposerButton(title:"답글"), newButton=ComposerButton(title:"새 글"), attachButton=ComposerButton(title:"첨부",symbol:"plus",point:20,circle:true)
    private let sendButton=ComposerButton(title:"보내기",symbol:"arrow.up",point:21,circle:true), modeBackground=NSView(), inputBackground=NSView()
    private let draftHint=PassiveLabel(labelWithString:""), older=NSButton(title:"이전 글 보기",target:nil,action:nil)
    private let formatting=DraftFormatController(), drop=AttachmentDropView(frame:.zero)
    private let clipboard: ClipboardAttachments
    private var rooms:[Room]=[], threads:[ConversationThread]=[]
    private(set) var sidebarRows:[SidebarLayout.Row]=[]
    private var dropSection:String?
    private let addRoom=ComposerButton(title:"방 추가",symbol:"plus",point:14), composerFaces=ComposerFaces(frame:.zero)
    private static let roomDrag=NSPasteboard.PasteboardType("hejo.sidebar.room")
    private var displayedKey:ConversationKey?, rendering=false, windowed=ThreadWindow(), identity=""
    private var openThread:ConversationKey?, newKeys:[String:ConversationKey]=[:], expandedMessages=Set<String>()
    private(set) var sidebarWidth=ConversationSidebar.width
    private(set) var replyMode=true
    private var shownSidebarWidth=ConversationSidebar.width, searchOpen=false, editorHeight:CGFloat=17
    var onCollapse:(()->Void)?
    var onOpenThreadHeight: ((CGFloat?) -> Void)?
    private var reportedOpenHeight: CGFloat?
    var onUnread:((Int)->Void)?, onSidebarWidth:((CGFloat)->Void)?
    override var isFlipped:Bool { true }
    var threadTable:NSTableView { history.table }
    init(controller:ConversationController,clipboardArea:URL?=nil,islandModel:IslandModel=IslandModel()) {
        self.controller=controller; self.islandModel=islandModel
        reconnect={ controller.client.resume() }; retrySend={ key in Task { await controller.sendCurrent(for:key) } }
        clipboard=ClipboardAttachments(area:clipboardArea ?? ClipboardAttachments.defaultArea)
        super.init(frame:.zero); wantsLayer=true
        employeeTable.headerView=nil; employeeTable.backgroundColor = .clear; employeeTable.style = .plain
        employeeTable.selectionHighlightStyle = .none; employeeTable.focusRingType = .none; employeeTable.intercellSpacing = .zero
        let column=NSTableColumn(identifier:.init("employees")); column.resizingMask = .autoresizingMask; employeeTable.addTableColumn(column)
        employeeTable.dataSource=self; employeeTable.delegate=self
        employeeTable.registerForDraggedTypes([Self.roomDrag]);employeeTable.setDraggingSourceOperationMask(.move,forLocal:true)
        employeeTable.makeMenu = { [weak self] row in self?.employeeMenu(row: row) }
        employeeScroll.makeBlankMenu = { [weak self] in self?.blankMenu() }
        employeeScroll.documentView=employeeTable; employeeScroll.drawsBackground=false; employeeScroll.hasVerticalScroller=true; employeeScroll.autohidesScrollers=true; employeeScroll.scrollerStyle = .overlay
        for view in [headerDrag,brandDrag,island,employeeScroll,brand,version,heading,subtitle,employeeSearch,search,history,sidebarToggle,searchToggle,notice,modeBackground,replyButton,newButton,inputBackground,editor,draftHint,attachButton,sendButton,attachmentScroll,older,handle,drop,addRoom,composerFaces] { addSubview(view) }
        addRoom.invoke={ [weak self] in guard let self else { return };self.addMenu().popUp(positioning:nil,at:CGPoint(x:0,y:addRoom.bounds.height),in:addRoom) }
        island.avatar={ [weak controller] id in controller?.avatar(id) ?? ProfileAvatar(color:PictureCodec.color(name:id,hex:nil)) }
        let logo=NSMutableAttributedString(string:"HEJO.",attributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:NSColor.labelColor])
        logo.addAttribute(.foregroundColor,value:NSColor.systemBlue,range:NSRange(location:0,length:1)); brand.attributedStringValue=logo
        brand.font = .systemFont(ofSize:14,weight:.semibold); version.font = .systemFont(ofSize:10); version.textColor = .labelColor.withAlphaComponent(0.7)
        version.stringValue=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""
        brand.alignment = .center; version.alignment = .center; heading.font = .systemFont(ofSize:14,weight:.semibold); subtitle.font = .systemFont(ofSize:10); subtitle.textColor = .labelColor.withAlphaComponent(0.7)
        employeeSearch.placeholderString="직원 검색"; employeeSearch.delegate=self; employeeSearch.font = .systemFont(ofSize:12)
        search.placeholderString="단어나 문장으로 검색"; search.delegate=self
        sidebarToggle.invoke={ [weak self] in self?.toggleSidebar() }; searchToggle.invoke={ [weak self] in self?.toggleSearch() }
        handle.width={ [weak self] in self?.sidebarWidth ?? 0 }; handle.onWidth={ [weak self] in self?.setSidebarWidth($0) }
        handle.onEnd={ [weak self] in if let self,self.sidebarWidth>0 { self.shownSidebarWidth=self.sidebarWidth } }
        notice.font = .systemFont(ofSize:11); notice.textColor = .systemRed
        attachments.orientation = .horizontal; attachments.spacing=6
        attachmentScroll.documentView=attachments; attachmentScroll.drawsBackground=false; attachmentScroll.hasHorizontalScroller=true; attachmentScroll.autohidesScrollers=true
        replyButton.invoke={ [weak self] in self?.writeReply() }; newButton.invoke={ [weak self] in self?.createThread() }
        attachButton.invoke={ [weak self] in self?.attach() }; sendButton.invoke={ [weak self] in self?.send() }; sendButton.chosen=true
        modeBackground.wantsLayer=true; modeBackground.layer?.cornerRadius=12
        inputBackground.wantsLayer=true; inputBackground.layer?.borderWidth=1
        editor.editor.delegate=self; editor.editor.formattingController=formatting; formatting.editor=editor.editor
        editor.editor.onSubmit={ [weak self] in self?.send() }; editor.editor.onPaste={ [weak self] in self?.paste(.general) ?? false }
        editor.onHeight={ [weak self] height in guard let self,abs(self.editorHeight-height)>0.5 else { return }; self.editorHeight=height; self.needsLayout=true }
        draftHint.font = .systemFont(ofSize:14); draftHint.textColor = .secondaryLabelColor
        older.target=self; older.action = #selector(loadOlder); older.isBordered=false; older.font = .systemFont(ofSize:11)
        drop.canAttach={ [weak self] in self?.controller.model.selected != nil && self?.controller.sending == false }
        drop.onPaste={ [weak self] board in self?.paste(board) ?? false }; drop.onTarget={ [weak self] target in self?.layer?.borderWidth=target ? 2 : 0 }
        layer?.borderColor=NSColor.controlAccentColor.cgColor
        headerDrag.onMenu = { [weak self] in self?.headerMenu() }
        brandDrag.onMenu = { [weak self] in self?.headerMenu() }
        clipboard.recoverLeftovers()
        history.onBlank={ [weak self] in self?.foldAll() }
        history.onMeasured={ [weak self] in self?.reportOpenHeight() }
        island.onAction={ [weak self] action in self?.activateIsland(action) }
        island.onWidthChange={ [weak self] in self?.needsLayout=true }
        headerDrag.excluded={ [weak self] point in self?.island.frame.contains(point) == true }
        islandTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in
            Task { @MainActor in self?.tickIsland() }
        }
        controller.onChange={ [weak self] in self?.refresh() }; controller.onRevealThread={ [weak self] key in self?.openFromBubble(key) }; refresh()
    }
    required init?(coder:NSCoder) { fatalError() }
    deinit { islandTimer?.invalidate() }
    func tickIsland() {
        island.show(islandModel.snapshot())
        if let until=highlightUntil, until<=islandModel.now { highlightUntil=nil;highlightedMessageID=nil;refresh() }
    }
    func activateIsland(_ action:IslandModel.Action) {
        switch action {
        case .reconnect: reconnect()
        case .retry(let key): retrySend(key)
        case .question(let id,let key):
            guard controller.model.messages[id]?.replyState == "asked" else { return }
            reveal(key);highlightedMessageID=id;highlightUntil=islandModel.now.addingTimeInterval(1.5)
            refresh();history.scrollTo(key.thread)
        case .worker(let key): reveal(key);refresh();history.scrollTo(key.thread)
        }
    }
    private func reveal(_ key:ConversationKey) {
        if identity != key.employee { identity=key.employee;windowed.reset() }
        searchOpen=false;search.stringValue="";openThread=key;replyMode=true
        controller.model.select(key,notify:false)
    }
    func setSidebarWidth(_ value:CGFloat) {
        let next=ConversationSidebar.snapped(value); guard next != sidebarWidth else { return }
        let delta=next-sidebarWidth; sidebarWidth=next; onSidebarWidth?(delta); refresh()
    }
    func toggleSidebar() { if sidebarWidth>0 { shownSidebarWidth=sidebarWidth; setSidebarWidth(0) } else { setSidebarWidth(shownSidebarWidth) } }
    func employeeMenu(row: Int) -> NSMenu {
        guard sidebarRows.indices.contains(row) else { return blankMenu() }
        let selected=sidebarRows[row]
        if selected.kind == .section || selected.kind == .stack { return sectionMenu(selected) }
        guard selected.kind == .room || selected.kind == .home else { return blankMenu() }
        let employee = selected.id, model = controller.model, menu = NSMenu()
        if model.selected?.employee != employee {
            menu.addItem(RoomActionItem("대화 열기") { [weak self] in self?.chooseEmployee(employee) })
            menu.addItem(.separator())
        }
        for slot in 1...5 {
            let title=(slot==1 ? "맨 위에 고정" : "\(slot)번째 자리에 고정")+(model.sidebar.pins[employee]==slot ? " ✓" : "")
            menu.addItem(RoomActionItem(title) { model.pin(employee,slot:slot) })
        }
        if model.pinned.contains(employee) { menu.addItem(.separator());menu.addItem(RoomActionItem("고정 해제") { model.pin(employee,slot:nil) }) }
        menu.addItem(RoomActionItem("모두 읽음") { model.markAllRead(employee) })
        menu.addItem(RoomActionItem(model.muted.contains(employee) ? "알림 켜기" : "알림 끄기") { model.toggleMute(employee) })
        menu.addItem(.separator())
        if let person=model.employees.first(where:{$0.id==employee}),person.avatarCustom != nil {
            menu.addItem(RoomActionItem("사진 바꾸기…") { [weak self] in self?.choosePicture(kind:"employee",id:employee) })
            if person.avatarCustom==true { menu.addItem(RoomActionItem("사진 지우기") { [weak self] in Task { _=await self?.controller.changePicture(kind:"employee",id:employee,url:nil) } }) }
        }
        menu.addItem(RoomActionItem("목록에서 빼기") { model.hide(employee) })
        return menu
    }
    func rowIndex(for employee:String)->Int? { sidebarRows.firstIndex { $0.kind == .room && $0.id==employee } }
    func sectionMenu(_ row:SidebarLayout.Row)->NSMenu {
        let menu=NSMenu(), model=controller.model,id=row.kind == .stack ? nil : row.zone
        menu.addItem(RoomActionItem(row.open ? "접기" : "펼치기") { model.toggleSection(id) });menu.addItem(.separator())
        menu.addItem(RoomActionItem("이름 바꾸기…") { [weak self] in
            let alert=NSAlert();alert.messageText="‘\(row.name)’ 이름 바꾸기";alert.informativeText="비우면 기본 이름으로 돌아가요."
            let field=NSTextField(frame:CGRect(x:0,y:0,width:260,height:24));field.stringValue=row.name;alert.accessoryView=field
            alert.addButton(withTitle:"저장");alert.addButton(withTitle:"취소")
            if alert.runModal() == .alertFirstButtonReturn { self?.controller.model.editSection(id,name:field.stringValue.trimmingCharacters(in:.whitespacesAndNewlines)) }
        })
        guard let id else { return menu }
        menu.addItem(.separator())
        menu.addItem(RoomActionItem("사진 바꾸기…") { [weak self] in self?.choosePicture(kind:"room",id:"section-"+id,section:id) })
        if row.picture != nil { menu.addItem(RoomActionItem("사진 지우기") { [weak self] in Task { await self?.deleteSectionPicture(id) } }) }
        menu.addItem(.separator())
        let remove=RoomActionItem("섹션 삭제…") { [weak self] in
            guard let self,let text=model.sidebar.deletion(id) else { return }
            let alert=NSAlert();alert.messageText=text.title;alert.informativeText=text.body
            alert.addButton(withTitle:"삭제");alert.addButton(withTitle:"취소")
            if alert.runModal() == .alertFirstButtonReturn { Task { await self.deleteSection(id) } }
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
    private func choosePicture(kind:String,id:String,section:String?=nil) {
        let client=controller.client,address=client.store.settings.address,token=client.bearer,epoch=client.connectionEpoch
        let picker=NSOpenPanel();picker.canChooseDirectories=false;picker.allowsMultipleSelection=false;picker.allowedContentTypes=[.png,.jpeg,.heic];picker.title="방 사진 고르기";picker.prompt="넣기"
        picker.begin { [weak self] result in
            guard result == .OK,let url=picker.url,let self,address==client.store.settings.address,token==client.bearer,epoch==client.connectionEpoch else { return }
            Task { if let picture=await self.controller.changePicture(kind:kind,id:id,url:url),let section { self.controller.model.editSection(section,picture:picture) } }
        }
    }
    func addMenu()->NSMenu {
        let menu=NSMenu(),model=controller.model
        menu.addItem(RoomActionItem("새 섹션 만들기") { model.addSection() });menu.addItem(.separator())
        let restore=NSMenuItem(title:"목록에서 뺀 방",action:nil,keyEquivalent:""),submenu=NSMenu()
        for person in model.employees where model.hidden.contains(person.id) { submenu.addItem(RoomActionItem(person.name) { model.restore(person.id) }) }
        if submenu.items.isEmpty { let empty=NSMenuItem(title:"뺀 방이 없어요",action:nil,keyEquivalent:"");empty.isEnabled=false;submenu.addItem(empty) }
        restore.submenu=submenu;menu.addItem(restore);return menu
    }
    func blankMenu() -> NSMenu {
        let menu = NSMenu(), model = controller.model
        menu.addItem(RoomActionItem("새 섹션 만들기") { model.addSection() });menu.addItem(.separator())
        let restore = NSMenuItem(title: "목록에서 뺀 방", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for employee in model.employees.filter({ model.hidden.contains($0.id) }) {
            submenu.addItem(RoomActionItem(employee.name) { model.restore(employee.id) })
        }
        if submenu.items.isEmpty { restore.isEnabled = false } else { restore.submenu = submenu }
        menu.addItem(restore); menu.addItem(.separator())
        menu.addItem(RoomActionItem(ConversationSidebar.isList(sidebarWidth) ? "목록 좁게" : "목록 넓게") { [weak self] in
            self?.setSidebarWidth(ConversationSidebar.isList(self?.sidebarWidth ?? 0) ? ConversationSidebar.width : ConversationSidebar.expandedWidth)
        })
        return menu
    }
    func headerMenu() -> NSMenu {
        let menu = NSMenu(), model = controller.model, employee = model.selected?.employee
        let mute = RoomActionItem(employee.map { model.muted.contains($0) ? "알림 켜기" : "알림 끄기" } ?? "알림 끄기") { if let employee { model.toggleMute(employee) } }
        mute.isEnabled = employee != nil; menu.addItem(mute)
        let read = RoomActionItem("모두 읽음") { if let employee { model.markAllRead(employee) } }
        read.isEnabled = employee != nil; menu.addItem(read)
        menu.addItem(.separator())
        menu.addItem(RoomActionItem(sidebarWidth == 0 ? "방 목록 보이기" : "방 목록 숨기기") { [weak self] in self?.toggleSidebar() })
        menu.addItem(.separator())
        menu.addItem(RoomActionItem("펫으로 접기") { [weak self] in self?.onCollapse?() })
        return menu
    }
    func chooseEmployee(_ employee:String) {
        openThread=nil; replyMode=false
        if let key=newKeys[employee] { controller.model.select(key) }
        else { let key=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased()); newKeys[employee]=key; controller.model.select(key) }
    }
    func chooseThread(_ key:ConversationKey) {
        replyMode=true; openThread=openThread == key ? nil : key; controller.model.select(key)
        history.scrollTo(key.thread)
    }
    func openFromBubble(_ key: ConversationKey) {
        reveal(key); refresh(); history.scrollTo(key.thread)
    }
    @discardableResult func closeSearchIfOpen() -> Bool {
        guard searchOpen else { return false }
        searchOpen=false; search.stringValue=""; refresh(); return true
    }
    var isSearchOpen: Bool { searchOpen }
    func toggleSearch() { searchOpen.toggle(); refresh() }
    private func reportOpenHeight() {
        let needed: CGFloat?
        if let openThread, let layout=history.layouts.first(where: { $0.content.id == openThread.thread }) {
            needed = max(0, bounds.height - history.frame.height) + layout.height + 32
        } else { needed = nil }
        if let needed, let reportedOpenHeight, abs(needed - reportedOpenHeight) < 1 { return }
        if needed == nil && reportedOpenHeight == nil { return }
        reportedOpenHeight = needed; onOpenThreadHeight?(needed)
    }
    func createThread() {
        guard let employee=controller.model.selected?.employee else { return }
        replyMode=false
        if let key=newKeys[employee] { controller.model.select(key) }
        else { let key=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased()); newKeys[employee]=key; controller.model.select(key) }
    }
    func writeReply() {
        guard let selected=controller.model.selected,let key=openThread ?? (controller.model.timeline(selected).isEmpty ? threads.last?.key : selected) else { return }
        replyMode=true; openThread=key; controller.model.select(key); history.scrollTo(key.thread)
    }
    func foldAll() { openThread=nil; createThread() }
    func refresh() {
        guard !rendering else { return }; rendering=true; defer { rendering=false }
        let model=controller.model, selected=model.selected
        rooms=model.displayRooms.filter { employeeSearch.stringValue.isEmpty || $0.title.localizedCaseInsensitiveContains(employeeSearch.stringValue) }
        let layout=model.sidebar
        sidebarRows=employeeSearch.stringValue.isEmpty ? layout.rows : layout.items.filter { $0.name.localizedCaseInsensitiveContains(employeeSearch.stringValue) }.map { .init(kind:.room,id:$0.id,name:$0.name,zone:layout.zone($0.id),items:[$0]) }
        composerFaces.faces=(selected.flatMap { model.room(for:$0.employee)?.members } ?? []).map { (model.name($0),controller.avatar($0)) }
        addRoom.toolTip="방 추가 (\(model.hidden.count))";addRoom.setAccessibilityLabel(addRoom.toolTip!)
        employeeTable.rowHeight=ConversationSidebar.isList(sidebarWidth) ? ConversationSidebar.rowHeight : ConversationSidebar.tabHeight
        employeeTable.reloadData()
        if let selected,let index=rowIndex(for:selected.employee) { employeeTable.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false) } else { employeeTable.deselectAll(nil) }
        if let selected {
            let current=selected.employee
            threads=(model.room(for:current).map { model.threads(room:$0,query:searchOpen ? search.stringValue : "") } ?? []).sorted { (model.timeline($0.key).first?.seq ?? 0) < (model.timeline($1.key).first?.seq ?? 0) }
            heading.stringValue=model.room(for:current)?.title ?? model.name(current); subtitle.stringValue="함께 나누는 대화"
            if identity != current { windowed.reset(); identity=current; openThread=nil }
            let shown=Set(windowed.visibleIDs(threads.map(\.id),revealing:openThread?.thread))
            var cards:[NativeThreadCard.Content]=[], previous:Date?
            for thread in threads where shown.contains(thread.id) {
                let date=ThreadTools.date(model.timeline(thread.key).first?.timestamp ?? "")
                if previous==nil || !Calendar.current.isDate(previous!,inSameDayAs:date) { cards.append(dayContent(date,id:thread.id)) }
                cards.append(threadContent(thread));previous=date
            }
            history.show(cards,identity:current)
            older.isHidden=shown.count >= threads.count
            if model.timeline(selected).isEmpty { newKeys[current]=selected; replyMode=false }
            // A confirmed first post finishes that new-post draft; another explicit new post gets another UUID.
            if let key=newKeys[current], !model.timeline(key).isEmpty, controller.drafts[key]?.text.isEmpty == true { newKeys[current]=nil }
        } else { threads=[]; history.show([],identity:""); heading.stringValue="HEJO."; older.isHidden=true }
        let draft=controller.draft
        if displayedKey != selected || (!editor.editor.hasMarkedText() && MessageFormat.serialize(editor.editor.attributedString(),baseSize:ChatMetrics.bodyFont) != draft.text) {
            editor.editor.breakUndoCoalescing(); editor.editor.undoManager?.removeAllActions()
            editor.editor.textStorage?.setAttributedString(MessageFormat.editor(draft.text,bodySize:ChatMetrics.bodyFont))
            editor.editor.typingAttributes=MessageFormat.Style(size:ChatMetrics.bodyFont).attributes; editor.measure()
        }
        displayedKey=selected
        draftHint.stringValue=replyMode ? "스레드에 답글" : selected.map { model.name($0.employee)+"에게 새 글" } ?? "직원을 선택하세요"
        draftHint.isHidden = !editor.editor.string.isEmpty; editor.editor.setAccessibilityLabel(draftHint.stringValue+" · Enter 보내기, Shift Enter 줄바꿈")
        for view in attachments.arrangedSubviews { attachments.removeArrangedSubview(view); view.removeFromSuperview() }
        for file in draft.attachments { let chip=FileChip(title:"📎 "+file.lastPathComponent+" ×"); chip.font = .systemFont(ofSize:11); chip.invoke={ [weak self] in self?.controller.removeAttachment(file) }; attachments.addArrangedSubview(chip) }
        editor.editor.isEditable=selected != nil && (!controller.sending || !controller.client.isConnected)
        sendButton.isEnabled=selected != nil && !controller.sending && controller.canSend && (!draft.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty)
        attachButton.isEnabled=selected != nil && !controller.sending
        replyButton.isEnabled = !threads.isEmpty; replyButton.chosen=replyMode; newButton.chosen = !replyMode
        for button in [replyButton,newButton,sendButton] { button.needsDisplay=true }
        notice.stringValue=controller.notice
        islandModel.update(controller.islandInput);tickIsland(); onUnread?(model.visibleUnreadTotal)
        reportOpenHeight()
        needsLayout=true; needsDisplay=true
    }
    override func layout() {
        super.layout()
        let w=bounds.width,h=bounds.height,left=min(sidebarWidth,max(0,w-100)), x=left, right=max(1,w-left), list=ConversationSidebar.isList(sidebarWidth)
        brandDrag.frame=CGRect(x:0,y:0,width:left,height:44); brand.frame=CGRect(x:0,y:7,width:left,height:18); version.frame=CGRect(x:0,y:26,width:left,height:12)
        headerDrag.frame=CGRect(x:x,y:0,width:right,height:44)
        let islandWidth=island.fittedWidth(limit:max(44,right-70-120-24))
        island.frame=CGRect(x:x+12,y:7,width:islandWidth,height:30);island.layoutSubtreeIfNeeded()
        let titleX=island.frame.maxX+12
        heading.frame=CGRect(x:titleX,y:7,width:max(0,w-70-titleX),height:18); subtitle.frame=CGRect(x:titleX,y:26,width:max(0,w-70-titleX),height:12)
        sidebarToggle.frame=CGRect(x:w-64,y:9,width:24,height:26); searchToggle.frame=CGRect(x:w-35,y:9,width:24,height:26)
        employeeSearch.isHidden = !list; employeeSearch.frame=CGRect(x:12,y:52,width:max(1,left-22),height:36)
        employeeScroll.frame=CGRect(x:0,y:44+4+(list ? 52 : 0),width:left,height:max(1,h-48-(list ? 52 : 0)-28))
        employeeTable.tableColumns.first?.width=employeeScroll.contentSize.width; employeeTable.frame.size.width=employeeScroll.contentSize.width
        brandDrag.isHidden=left==0; brand.isHidden=left==0; version.isHidden=left==0; employeeScroll.isHidden=left==0
        handle.frame=CGRect(x:max(0,left-4),y:44,width:8,height:max(0,h-44))
        addRoom.frame=CGRect(x:10,y:h-28,width:max(30,left-20),height:24);addRoom.isHidden=left==0
        var y:CGFloat=44
        search.isHidden = !searchOpen; search.frame=CGRect(x:x+12,y:y+8,width:right-24,height:28); if searchOpen { y+=44 }
        older.frame=CGRect(x:x+12,y:y,width:right-24,height:older.isHidden ? 0 : 24); if !older.isHidden { y+=24 }
        let noticeHeight:CGFloat=notice.stringValue.isEmpty ? 0 : 38, attachmentsHeight:CGFloat=controller.draft.attachments.isEmpty ? 0 : 30
        let inputHeight=max(42,editorHeight+22), composerHeight=10+22+6+attachmentsHeight+inputHeight+10
        let bottom=max(y,h-composerHeight-noticeHeight)
        history.frame=CGRect(x:x,y:y,width:right,height:max(1,bottom-y)); notice.frame=CGRect(x:x+10,y:bottom+7,width:right-20,height:max(0,noticeHeight-10))
        let top=bottom+noticeHeight+10
        modeBackground.frame=CGRect(x:x+10,y:top,width:108,height:22); replyButton.frame=CGRect(x:x+12,y:top+2,width:50,height:18); newButton.frame=CGRect(x:x+62,y:top+2,width:54,height:18)
        composerFaces.frame=CGRect(x:x+128,y:top,width:max(0,right-150),height:22)
        attachmentScroll.frame=CGRect(x:x+10,y:top+28,width:right-20,height:attachmentsHeight); attachments.frame=CGRect(x:0,y:0,width:max(right-20,attachments.fittingSize.width),height:attachmentsHeight)
        let line=top+28+attachmentsHeight
        attachButton.frame=CGRect(x:x+10,y:line+inputHeight-38,width:38,height:38)
        inputBackground.frame=CGRect(x:x+56,y:line,width:max(1,right-118),height:inputHeight); inputBackground.layer?.cornerRadius=inputHeight/2
        editor.frame=CGRect(x:x+70,y:line+11,width:max(1,right-146),height:max(17,inputHeight-22))
        draftHint.frame=CGRect(x:x+70,y:line+11,width:max(1,right-146),height:20)
        sendButton.frame=CGRect(x:w-52,y:line+inputHeight-42,width:42,height:42)
        drop.frame=CGRect(x:x,y:top,width:right,height:max(1,h-top))
        modeBackground.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.1).cgColor
        inputBackground.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.04).cgColor; inputBackground.layer?.borderColor=NSColor.labelColor.withAlphaComponent(0.18).cgColor
    }
    override func draw(_ dirtyRect:NSRect) {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        (dark ? NSColor(white:0.07,alpha:0.4) : .clear).setFill(); bounds.fill()
        NSColor.labelColor.withAlphaComponent(0.035).setFill(); CGRect(x:sidebarWidth,y:0,width:max(0,bounds.width-sidebarWidth),height:44).fill()
        (dark ? NSColor(white:0.10,alpha:0.45) : NSColor.white.withAlphaComponent(0.12)).setFill(); CGRect(x:0,y:0,width:sidebarWidth,height:bounds.height).fill()
        NSColor.labelColor.withAlphaComponent(0.1).setFill(); CGRect(x:sidebarWidth-1,y:0,width:1,height:bounds.height).fill(); CGRect(x:0,y:43,width:bounds.width,height:1).fill()
    }
    func numberOfRows(in tableView:NSTableView)->Int { sidebarRows.count }
    func tableView(_ tableView:NSTableView,heightOfRow row:Int)->CGFloat {
        guard sidebarRows.indices.contains(row) else { return 0 }
        switch sidebarRows[row].kind { case .divider:return 19;case .section,.stack:return ConversationSidebar.isList(sidebarWidth) ? 29 : 36;default:return ConversationSidebar.isList(sidebarWidth) ? 58 : 72 }
    }
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        let id=NSUserInterfaceItemIdentifier("employee-tab"), room=sidebarRows[row],model=controller.model
        let cell=tableView.makeView(withIdentifier:id,owner:nil) as? EmployeeSidebarCell ?? EmployeeSidebarCell(frame:.zero)
        cell.identifier=id;cell.row=room;cell.name=room.name;cell.faces=(room.kind == .room ? room.items.flatMap(\.members) : room.faces).map { (model.name($0),controller.avatar($0)) }
        cell.picture=controller.pictures.image(room.picture);cell.nameColor=room.kind == .room ? controller.avatar(room.id).color : .secondaryLabelColor
        cell.railLast = !sidebarRows.indices.contains(row+1) || sidebarRows[row+1].kind != .room || sidebarRows[row+1].zone != room.zone
        cell.chosen=room.kind == .room && room.items.flatMap(\.members).contains(model.selected?.employee ?? "");cell.unread=room.unread;cell.muted=model.muted.contains(room.id);cell.list=ConversationSidebar.isList(sidebarWidth);cell.pinned=model.pinned.contains(room.id);cell.dropTarget=dropSection != nil && room.zone==dropSection;cell.needsDisplay=true
        cell.setAccessibilityLabel(room.name+", 안 읽은 글 \(cell.unread)개");return cell
    }
    func tableView(_ tableView:NSTableView,shouldSelectRow row:Int)->Bool {
        guard sidebarRows.indices.contains(row) else { return false };let item=sidebarRows[row]
        if item.kind == .section || item.kind == .stack { controller.model.toggleSection(item.kind == .stack ? nil : item.zone);return false }
        return item.kind == .room || item.kind == .home
    }
    func tableViewSelectionDidChange(_ notification:Notification) { guard !rendering,sidebarRows.indices.contains(employeeTable.selectedRow),let employee=sidebarRows[employeeTable.selectedRow].items.first?.members.first else { return };chooseEmployee(employee) }
    func tableView(_ tableView:NSTableView,pasteboardWriterForRow row:Int)->NSPasteboardWriting? {
        guard sidebarRows.indices.contains(row) else { return nil };let item=sidebarRows[row]
        guard item.kind == .room,item.zone != nil else { return nil }
        let value=NSPasteboardItem();value.setString(item.id,forType:Self.roomDrag);return value
    }
    func tableView(_ tableView:NSTableView,validateDrop info:NSDraggingInfo,proposedRow row:Int,proposedDropOperation operation:NSTableView.DropOperation)->NSDragOperation {
        let zone=sidebarRows.indices.contains(row) ? sidebarRows[row].zone : nil
        guard info.draggingSource as? NSTableView === employeeTable,let id=info.draggingPasteboard.string(forType:Self.roomDrag),let zone,controller.model.sidebar.canMove(id,to:zone) else { dropSection=nil;employeeTable.reloadData();return [] }
        dropSection=zone;employeeTable.setDropRow(row,dropOperation:.on);employeeTable.reloadData();return .move
    }
    func tableView(_ tableView:NSTableView,acceptDrop info:NSDraggingInfo,row:Int,dropOperation:NSTableView.DropOperation)->Bool {
        defer { dropSection=nil;employeeTable.reloadData() }
        guard let zone=dropSection,let id=info.draggingPasteboard.string(forType:Self.roomDrag),controller.model.sidebar.canMove(id,to:zone) else { return false }
        controller.model.move(id,to:zone);return true
    }
    func tableView(_ tableView:NSTableView,draggingSession session:NSDraggingSession,endedAt screenPoint:NSPoint,operation:NSDragOperation) { dropSection=nil;employeeTable.reloadData() }
    func controlTextDidChange(_ notification:Notification) { refresh() }
    func textDidChange(_ notification:Notification) {
        if let key=displayedKey { controller.setText(MessageFormat.serialize(editor.editor.attributedString(),baseSize:ChatMetrics.bodyFont),for:key) }
        draftHint.isHidden = !editor.editor.string.isEmpty; formatting.refresh(); editor.measure()
        sendButton.isEnabled=controller.canSend && !controller.sending && (!editor.editor.string.isEmpty || !controller.draft.attachments.isEmpty); sendButton.needsDisplay=true
    }
    func textViewDidChangeSelection(_ notification:Notification) { formatting.refresh() }
    private func send() { let key=displayedKey; Task { await controller.sendCurrent(for:key) } }
    @objc private func loadOlder() { _=windowed.older(loadedCount:threads.count,hasEarlier:false); refresh() }
    private func attach() { let picker=NSOpenPanel(); picker.canChooseDirectories=false; picker.allowsMultipleSelection=true; picker.begin { [weak self] response in if response == .OK { self?.controller.addAttachments(picker.urls) } } }
    private func paste(_ board:NSPasteboard)->Bool {
        guard let result=clipboard.read(board,available:max(0,10-controller.draft.attachments.count)) else { return false }
        controller.addAttachments(result.files); if let notice=result.notice { controller.notice=notice }; return true
    }
    private func threadContent(_ thread:ConversationThread)->NativeThreadCard.Content {
        let model=controller.model,messages=model.timeline(thread.key),expanded=openThread==thread.key
        guard let root=messages.first else {preconditionFailure("Empty thread projection")}
        let replies=Array(messages.dropFirst()),foldable=replies.count>2
        let shown=expanded || !foldable ? replies:replies.filter{$0.id==replies.last?.id || ($0.replyState=="asked" && (!$0.buttons.isEmpty || $0.checklist != nil) && !model.confirmed($0.id))}
        let hidden=replies.count-shown.count,dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let pick:()->Void={ [weak self] in self?.chooseThread(thread.key) }
        let top=postPieces(root,conversational:false)
        var answer:[NativeThreadCard.Piece]=[]
        if hidden>0 {
            let faces=ThreadTools.answeredFaces(replies).map{(model.name($0),controller.avatar($0))}
            answer.append(.stack(faces:faces,title:"이전 답글 \(hidden)개",toggle:pick,identifier:"stack-"+thread.id))
        }
        for message in shown {answer += postPieces(message,conversational:true)}
        if controller.working(thread.key) || controller.stopped.contains(thread.key) {
            if controller.stopped.contains(thread.key) {
                answer.append(.accessory(id:thread.id+":undo",height:24,view:{ [weak self] in
                    let row=NSStackView();row.spacing=6
                    let label=NSTextField(labelWithString:"중지를 요청했어요");label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);row.addArrangedSubview(label)
                    let undo=FileChip(title:"되돌리기");undo.invoke={ [weak self] in Task {await self?.controller.sendText(ThreadTools.undo,key:thread.key)} };row.addArrangedSubview(undo)
                    return MessageAccessory(row,limit:row.fittingSize.width)
                }))
            } else {
                let since=model.typingSince[thread.key] ?? messages.last(where:{$0.role=="owner"}).map{ThreadTools.date($0.timestamp)} ?? Date()
                let activity=messages.last(where:{$0.role != "owner" && ThreadTools.thinking($0.text)})?.text.components(separatedBy:"\n").dropFirst().first ?? (messages.contains(where:{$0.streaming}) ? "답변을 작성하고 있습니다":"답변을 준비하고 있습니다")
                answer.append(.accessory(id:thread.id+":work",height:22,view:{ [weak self] in
                    WorkingControlRow(since:since,activity:activity,clock:{self?.islandModel.now ?? Date()},animationTime:{self?.motionTime() ?? 0},reduceMotion:{self?.reduceMotion() ?? true},stop:{ [weak self] in Task {await self?.controller.stop(thread.key)} })
                }))
            }
        }
        let state=messages.reversed().first{$0.replyState != nil && !model.confirmed($0.id)}?.replyState
        let tone:NSColor?=state=="asked" ? MessageFormat.color("#E01E5A"):state=="answered" || state=="closed" ? MessageFormat.color("#2EB67D"):messages.lazy.compactMap{ThreadTools.color($0.text)}.first
        let target=replyMode && model.selected==thread.key
        let highlighted=messages.contains{$0.id==highlightedMessageID} && (highlightUntil.map{$0>islandModel.now} ?? false)
        let now=controller.clock(),copiedLink=copiedID=="link:"+thread.id,copiedText=copiedID=="text:"+thread.id
        let branchAsked=controller.branching[thread.key].map{now.timeIntervalSince($0)<6} ?? false
        let sure=controller.confirmingDelete[thread.key].map{now.timeIntervalSince($0)<4} ?? false
        var actions:[NativeThreadCard.Action]=[
            .init(title:copiedLink ? "복사됨":"링크",symbol:copiedLink ? "checkmark":"link",label:"스레드 링크 복사",identifier:"copy-link-"+thread.id,invoke:{ [weak self] in self?.copyText(ThreadTools.link(thread.key).absoluteString,id:"link:"+thread.id) }),
            .init(title:copiedText ? "복사됨":"복사",symbol:copiedText ? "checkmark":"doc.on.doc",label:"스레드 전체 복사",identifier:"copy-"+thread.id,invoke:{ [weak self] in guard let self else{return};self.copyText(ThreadTools.copy(messages,key:thread.key,name:self.controller.model.name),id:"text:"+thread.id) })]
        if messages.contains(where:{$0.role=="employee"}) {actions.append(.init(title:"분기",symbol:branchAsked ? "checkmark":"arrow.triangle.branch",label:"새 스레드로 이어가기",identifier:"branch-"+thread.id,enabled:controller.canSend && !branchAsked,color:replies.count>=50 ? .systemOrange:.secondaryLabelColor,invoke:{ [weak self] in Task {await self?.controller.branch(thread.key)} }))}
        if !controller.deleting.contains(thread.key) {actions.append(.init(title:sure ? "정말 삭제":"삭제",symbol:"trash",label:sure ? "스레드 삭제 확인 · 되돌릴 수 없어요":"스레드 삭제",identifier:"delete-"+thread.id,enabled:controller.canSend,color:sure ? .systemRed:.secondaryLabelColor,alwaysLabel:sure,invoke:{ [weak self] in Task {await self?.controller.deleteThread(thread.key)} }))}
        if foldable && expanded {actions.append(.init(title:"접기",symbol:"chevron.up",label:"접기",identifier:"fold-"+thread.id,alwaysLabel:true,invoke:pick))}
        return .init(id:thread.id,top:top,replies:answer.isEmpty ? nil:answer,rail:nil,actions:actions,deleting:controller.deleting.contains(thread.key) ? "삭제 중…":nil,
            style:.init(inset:ThreadAppearance.inset,fill:0,stroke:highlighted ? .systemOrange:target ? .controlAccentColor:NSColor.labelColor.withAlphaComponent(dark ? 0.16:0.12),lineWidth:highlighted ? 2.5:target ? 1.5:1,background:ThreadAppearance.surface(dark:dark),status:tone,replyBackground:ThreadAppearance.replySurface(dark:dark)),
            bell:model.bell(thread.key),onBell:{ [weak self] in self?.controller.model.toggleBell(thread.key) },clickCard:pick,textClick:!expanded && foldable ? pick:nil,
            bubbleWidth:max(ChatMetrics.minimumBubbleWidth,(bounds.width-sidebarWidth)*ChatMetrics.bubbleWidthFraction),quiet:NSColor.labelColor.withAlphaComponent(0.7),expanded:expanded,replyTarget:target)
    }
    private func postPieces(_ message:ConversationMessage,conversational:Bool)->[NativeThreadCard.Piece] {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua, mine=message.role == "owner"
        if !mine,ThreadTools.thinking(message.text) {return []}
        let foldable = !mine && !message.streaming && LongReply.needsFolding(message.text), folded=foldable && !expandedMessages.contains(message.id)
        let body=folded ? LongReply.preview(message.text) : message.text, stripped=TextLayout.strip(body)
        let text=NSMutableAttributedString(attributedString:MessageFormat.renderNative(mine ? body : stripped.source,bodySize:ChatMetrics.bodyFont))
        let all=NSRange(location:0,length:text.length), paragraph=NSMutableParagraphStyle(); paragraph.lineSpacing=mine ? 0 : 2
        text.addAttribute(.paragraphStyle,value:paragraph,range:all)
        if mine { text.addAttribute(.foregroundColor,value:UserBubblePalette(dark:dark).foreground.nsColor,range:all) }
        else { TextLayout.apply(to:text,lines:stripped.lines,bar:controller.avatar(message.key.employee).color,lineSpacing:2) }
        text.enumerateAttributes(in:NSRange(location:0,length:text.length)) { attributes,range,_ in
            if !mine,let font=attributes[.font] as? NSFont,NSFontManager.shared.traits(of:font).contains(.fixedPitchFontMask) {
                text.addAttributes([.font:NSFont.monospacedSystemFont(ofSize:13,weight:.regular),.foregroundColor:dark ? NSColor(srgbRed:0.96,green:0.68,blue:0.36,alpha:1) : NSColor(srgbRed:0.76,green:0.32,blue:0.09,alpha:1),.backgroundColor:NSColor.labelColor.withAlphaComponent(0.1)],range:range)
            }
            if attributes[.link] != nil { text.addAttributes([.underlineStyle:NSUnderlineStyle.single.rawValue,.foregroundColor:mine ? UserBubblePalette(dark:dark).link.nsColor : NSColor.systemBlue],range:range) }
        }
        var checks:[Int:(line:Int,original:Bool)]=[:]
        if !mine && !message.streaming {
            var offset=0,line=0
            for character in text.string {
                let length=String(character).utf16.count
                if character=="☐" || character=="☑" {
                    let original=character=="☑";checks[offset]=(line,original)
                    text.replaceCharacters(in:NSRange(location:offset,length:length),with:controller.model.check(message.id,line:line,original:original) ? "☑":"☐")
                    text.addAttribute(.link,value:URL(string:"hejo-check://toggle/\(offset)")!,range:NSRange(location:offset,length:1))
                }
                if character=="\n" {line+=1};offset+=length
            }
        }
        let post=NativeThreadCard.Post(id:message.id,mine:mine,text:text,speaker:mine ? "나" : controller.model.name(message.key.employee),time:displayTime(message.timestamp),avatar:controller.avatar(message.key.employee),nameColor:mine ? .labelColor : controller.avatar(message.key.employee).color,
            conversational:conversational && !mine && !message.streaming && message.files.isEmpty && ThreadAppearance.isConversational(message.text),streaming:message.streaming,
            marks:message.replyState=="answered" || message.replyState=="closed" ? [.init(color:MessageFormat.color("#2EB67D")!,text:NSAttributedString(string:"처리 완료"))]:[],foldTitle:foldable ? (folded ? "더 보기" : "접기") : nil,fold:{ [weak self] in guard let self else { return }; if self.expandedMessages.contains(message.id) { self.expandedMessages.remove(message.id) } else { self.expandedMessages.insert(message.id) }; self.refresh() },openLink:{ [weak self] url in
                guard let self else{return}
                if url.scheme=="hejo-check",let offset=Int(url.lastPathComponent),let check=checks[offset] {self.controller.model.toggleCheck(message.id,line:check.line,original:check.original)}
                else if url.scheme=="hejo" {self.controller.openLink(url)}
                else if ["http","https","mailto"].contains(url.scheme?.lowercased() ?? "") {NSWorkspace.shared.open(url)}
            })
        var pieces:[NativeThreadCard.Piece]=[.post(post)]
        if mine,controller.interruptions[message.key] != nil,message.id==controller.model.timeline(message.key).last(where:{$0.role=="owner"})?.id {
            pieces.append(.accessory(id:message.id+":interruption",height:16,view:{
                let label=NSTextField(labelWithString:"끼어들었어요");label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);label.textColor = .secondaryLabelColor
                return MessageAccessory(label,mine:true,limit:130)
            }))
        }
        for file in message.files {
            pieces.append(.accessory(id:file.id,height:file.mime.hasPrefix("image/") ? 110 : 46,view:{ [weak self] in
                let tile=FileTile(file:file)
                let container=MessageAccessory(tile,mine:mine,limit:file.mime.hasPrefix("image/") ? 160 : 240)
                tile.frame=CGRect(x:mine ? 0 : 43,y:0,width:240,height:file.mime.hasPrefix("image/") ? 110 : 46); tile.autoresizingMask = [.width]
                tile.invoke={ [weak self] in guard let self else { return }; Task { await self.controller.open(file,employee:message.key.employee) } }
                if file.mime.hasPrefix("image/"),let self { Task { [weak tile,weak self] in
                    guard let self else { return }; if let url=try? await self.controller.files.download(file,employee:message.key.employee) { tile?.picture=NSImage(contentsOf:url); tile?.needsDisplay=true }
                } }
                return container
            }))
        }
        if let checklist=controller.checklistSelection(message),!controller.model.confirmed(message.id) {
            pieces.append(.accessory(id:message.id+":checklist",height:CGFloat((checklist.items.count+1)/2+1)*32,view:{ [weak self] in
                let choices=ReplyChecklistView(checklist,changed:{ [weak self] selected in self?.controller.selectChecklist(message,selected:selected) }) { [weak self] text in Task {await self?.controller.sendText(text,key:message.key)} }
                return MessageAccessory(choices,limit:choices.fittingSize.width)
            }))
        }
        if !message.buttons.isEmpty && !controller.model.confirmed(message.id) {
            pieces.append(.accessory(id:message.id+":buttons",height:32,view:{ [weak self] in
                let stack=NSStackView(); stack.orientation = .horizontal; stack.spacing=8
                for item in message.buttons {
                    let symbol=["승인":"circle","거절":"xmark","의견":"pencil","확인":"checkmark","메모":"note.text","메모+노션":"square.stack","되돌리기":"arrow.uturn.backward"][item.label]
                    let button=FileChip(title:symbol == nil ? item.label : "")
                    if let symbol { button.image=NSImage(systemSymbolName:symbol,accessibilityDescription:item.label); button.isBordered=false }
                    button.toolTip=item.label; button.setAccessibilityLabel(item.label); button.font = .systemFont(ofSize:11)
                    button.isEnabled=self?.controller.canSend == true && (item.kind != "reply" || message.replyState != "closed")
                    button.invoke={ [weak self] in guard let self else { return }; self.replyMode=true; self.openThread=message.key; self.controller.model.select(message.key); Task { await self.controller.click(item,message:message) } }
                    stack.addArrangedSubview(button)
                }; return MessageAccessory(stack,limit:stack.fittingSize.width)
            }))
        }
        return pieces
    }
    private func copyText(_ text:String,id:String) {
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(text,forType:.string)
        copiedID=id;refresh();DispatchQueue.main.asyncAfter(deadline:.now()+1.6) { [weak self] in if self?.copiedID==id {self?.copiedID=nil;self?.refresh()} }
    }
    private func dayContent(_ date:Date,id:String)->NativeThreadCard.Content {
        let formatter=DateFormatter();formatter.dateFormat="yyyy년 M월 d일 EEEE"
        return .init(id:"date:"+id,top:[.accessory(id:"date-label:"+id,height:14,view:{
            let label=NSTextField(labelWithString:formatter.string(from:date));label.font = .systemFont(ofSize:ChatMetrics.auxiliaryFont);label.textColor = .secondaryLabelColor;label.alignment = .center;return label
        })],replies:nil,rail:nil,actions:[],deleting:nil,style:.init(inset:0,fill:0,stroke:nil,lineWidth:0,background:.clear),bell:nil,onBell:{},clickCard:{},textClick:nil,bubbleWidth:500,quiet:.secondaryLabelColor,expanded:false)
    }
    private func displayTime(_ value:String)->String {
        let formatter=ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        guard let date=formatter.date(from:value) ?? ISO8601DateFormatter().date(from:value) else { return "" }
        return DateFormatter.localizedString(from:date,dateStyle:.none,timeStyle:.short)
    }
}
