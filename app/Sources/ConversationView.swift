import AppKit

/// AppKit translation of the reviewed workspace, room strip, card stack and composer.
@MainActor final class ConversationView: NSView, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSearchFieldDelegate {
    let controller: ConversationController
    let island=IslandView(frame:.zero)
    let islandModel:IslandModel
    /// Animation clock and reduced-motion switch for in-chat typing shimmer; checks inject both.
    var motionTime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private var islandTimer:Timer?
    private(set) var highlightedMessageID:String?
    private var highlightUntil:Date?
    var reconnect:()->Void
    var retrySend:(ConversationKey)->Void
    let employeeTable = NSTableView(), history = NativeThreadList(frame:.zero), editor = DraftScrollView(frame:.zero)
    let headerDrag = ConversationHeaderDrag(), brandDrag = ConversationHeaderDrag()
    private let employeeScroll=NSScrollView(), employeeSearch=NSSearchField(), search=NSSearchField()
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
    private var displayedKey:ConversationKey?, rendering=false, windowed=ThreadWindow(), identity=""
    private var openThread:ConversationKey?, newKeys:[String:ConversationKey]=[:], expandedMessages=Set<String>()
    private(set) var sidebarWidth=ConversationSidebar.width
    private(set) var replyMode=true
    private var shownSidebarWidth=ConversationSidebar.width, searchOpen=false, editorHeight:CGFloat=17
    var onCollapse:(()->Void)?
    @objc private func collapseConversation() { onCollapse?() }
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
        employeeScroll.documentView=employeeTable; employeeScroll.drawsBackground=false; employeeScroll.hasVerticalScroller=true; employeeScroll.autohidesScrollers=true; employeeScroll.scrollerStyle = .overlay
        for view in [headerDrag,brandDrag,island,employeeScroll,brand,version,heading,subtitle,employeeSearch,search,history,sidebarToggle,searchToggle,notice,modeBackground,replyButton,newButton,inputBackground,editor,draftHint,attachButton,sendButton,attachmentScroll,older,handle,drop] { addSubview(view) }
        let logo=NSMutableAttributedString(string:"HEJO.",attributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:NSColor.labelColor])
        logo.addAttribute(.foregroundColor,value:NSColor.systemBlue,range:NSRange(location:0,length:1)); brand.attributedStringValue=logo
        brand.font = .systemFont(ofSize:14,weight:.semibold); version.font = .systemFont(ofSize:10); version.textColor = .labelColor.withAlphaComponent(0.7)
        version.stringValue=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? ""
        brand.alignment = .center; version.alignment = .center; heading.font = .systemFont(ofSize:14,weight:.semibold); subtitle.font = .systemFont(ofSize:10); subtitle.textColor = .labelColor.withAlphaComponent(0.7)
        employeeSearch.placeholderString="직원 검색"; employeeSearch.delegate=self; employeeSearch.font = .systemFont(ofSize:12)
        search.placeholderString="단어나 문장으로 검색"; search.delegate=self
        sidebarToggle.invoke={ [weak self] in self?.toggleSidebar() }; searchToggle.invoke={ [weak self] in self?.searchOpen.toggle(); self?.refresh() }
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
        let menu=NSMenu(); let collapse=menu.addItem(withTitle:"펫으로 접기",action:#selector(collapseConversation),keyEquivalent:""); collapse.target=self
        headerDrag.menu=menu; brandDrag.menu=menu
        clipboard.recoverLeftovers()
        history.onBlank={ [weak self] in self?.foldAll() }
        island.onAction={ [weak self] action in self?.activateIsland(action) }
        island.onWidthChange={ [weak self] in self?.needsLayout=true }
        headerDrag.excluded={ [weak self] point in self?.island.frame.contains(point) == true }
        islandTimer=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in
            Task { @MainActor in self?.tickIsland() }
        }
        controller.onChange={ [weak self] in self?.refresh() }; refresh()
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
    func chooseEmployee(_ employee:String) {
        openThread=nil; replyMode=false
        if let key=newKeys[employee] { controller.model.select(key) }
        else { let key=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased()); newKeys[employee]=key; controller.model.select(key) }
    }
    func chooseThread(_ key:ConversationKey) {
        replyMode=true; openThread=openThread == key ? nil : key; controller.model.select(key)
        history.scrollTo(key.thread)
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
        rooms=model.rooms.filter { employeeSearch.stringValue.isEmpty || $0.title.localizedCaseInsensitiveContains(employeeSearch.stringValue) }
        employeeTable.rowHeight=ConversationSidebar.isList(sidebarWidth) ? ConversationSidebar.rowHeight : ConversationSidebar.tabHeight
        employeeTable.reloadData()
        if let index=rooms.firstIndex(where:{$0.members.contains(selected?.employee ?? "")}) { employeeTable.selectRowIndexes(IndexSet(integer:index),byExtendingSelection:false) }
        if let selected {
            let current=selected.employee
            threads=(model.room(for:current).map { model.threads(room:$0,query:searchOpen ? search.stringValue : "") } ?? []).sorted { (model.timeline($0.key).first?.seq ?? 0) < (model.timeline($1.key).first?.seq ?? 0) }
            heading.stringValue=model.room(for:current)?.title ?? model.name(current); subtitle.stringValue="함께 나누는 대화"
            if identity != current { windowed.reset(); identity=current; openThread=nil }
            let shown=Set(windowed.visibleIDs(threads.map(\.id),revealing:openThread?.thread))
            history.show(threads.filter { shown.contains($0.id) }.map(threadContent),identity:current)
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
        islandModel.update(controller.islandInput);tickIsland(); onUnread?(model.rooms.reduce(0){$0+model.unread(room:$1)})
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
        var y:CGFloat=44
        search.isHidden = !searchOpen; search.frame=CGRect(x:x+12,y:y+8,width:right-24,height:28); if searchOpen { y+=44 }
        older.frame=CGRect(x:x+12,y:y,width:right-24,height:older.isHidden ? 0 : 24); if !older.isHidden { y+=24 }
        let noticeHeight:CGFloat=notice.stringValue.isEmpty ? 0 : 38, attachmentsHeight:CGFloat=controller.draft.attachments.isEmpty ? 0 : 30
        let inputHeight=max(42,editorHeight+22), composerHeight=10+22+6+attachmentsHeight+inputHeight+10
        let bottom=max(y,h-composerHeight-noticeHeight)
        history.frame=CGRect(x:x,y:y,width:right,height:max(1,bottom-y)); notice.frame=CGRect(x:x+10,y:bottom+7,width:right-20,height:max(0,noticeHeight-10))
        let top=bottom+noticeHeight+10
        modeBackground.frame=CGRect(x:x+10,y:top,width:108,height:22); replyButton.frame=CGRect(x:x+12,y:top+2,width:50,height:18); newButton.frame=CGRect(x:x+62,y:top+2,width:54,height:18)
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
    func numberOfRows(in tableView:NSTableView)->Int { rooms.count }
    func tableView(_ tableView:NSTableView,viewFor column:NSTableColumn?,row:Int)->NSView? {
        let id=NSUserInterfaceItemIdentifier("employee-tab"), room=rooms[row]
        let cell=tableView.makeView(withIdentifier:id,owner:nil) as? EmployeeSidebarCell ?? EmployeeSidebarCell(frame:.zero)
        cell.identifier=id; cell.name=room.title; cell.chosen=room.members.contains(controller.model.selected?.employee ?? ""); cell.unread=controller.model.unread(room:room); cell.list=ConversationSidebar.isList(sidebarWidth); cell.needsDisplay=true
        cell.setAccessibilityLabel(room.title+", 안 읽은 글 \(cell.unread)개"); return cell
    }
    func tableViewSelectionDidChange(_ notification:Notification) { guard !rendering,rooms.indices.contains(employeeTable.selectedRow), let employee=rooms[employeeTable.selectedRow].members.first else { return }; chooseEmployee(employee) }
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
        let messages=controller.model.timeline(thread.key), expanded=openThread == thread.key
        guard let root=messages.first else { preconditionFailure("Empty thread projection") }
        let replies=Array(messages.dropFirst()), foldable=replies.count>2
        let shown=expanded || !foldable ? replies : replies.filter { $0.id == replies.last?.id || ($0.replyState == "asked" && !$0.buttons.isEmpty) }
        let hidden=replies.count-shown.count, dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let pick:()->Void={ [weak self] in self?.chooseThread(thread.key) }
        var top=postPieces(root,conversational:false), answer:[NativeThreadCard.Piece]=[]
        if hidden>0 {
            let faces=Array(replies.filter { $0.role == "employee" }.prefix(1)).map { (controller.model.name($0.key.employee),ProfileAvatar(color:.systemBlue)) }
            answer.append(.stack(faces:faces,title:"이전 답글 \(hidden)개",toggle:pick,identifier:"stack-"+thread.id))
        }
        for message in shown { answer += postPieces(message,conversational:true) }
        if controller.model.typing[thread.key] != nil && !messages.contains(where:{$0.streaming}) {
            let since=controller.model.typingSince[thread.key] ?? islandModel.now
            answer.append(.accessory(id:thread.id+":typing",height:22,view:{ [weak self] in
                TypingRow(since:since,clock:{ self?.islandModel.now ?? Date() },animationTime:{ self?.motionTime() ?? 0 },reduceMotion:{ self?.reduceMotion() ?? true })
            }))
        }
        let state=messages.reversed().compactMap(\.replyState).first
        let tone:NSColor?=state == "asked" ? NSColor(srgbRed:0.925,green:0.698,blue:0.18,alpha:1) : state == "answered" || state == "closed" ? NSColor(srgbRed:0.18,green:0.714,blue:0.49,alpha:1) : nil
        let target=replyMode && controller.model.selected == thread.key
        let highlighted=messages.contains { $0.id == highlightedMessageID } && (highlightUntil.map { $0>islandModel.now } ?? false)
        var actions:[NativeThreadCard.Action]=[.init(title:"복사",symbol:"doc.on.doc",label:"스레드 전체 복사",identifier:"copy-"+thread.id,invoke:{ [weak self] in
            guard let self else { return }; let text=messages.map { ($0.role == "owner" ? "나" : self.controller.model.name($0.key.employee))+"\n"+$0.text }.joined(separator:"\n\n")
            NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text,forType:.string)
        })]
        if foldable && expanded { actions.append(.init(title:"접기",symbol:"chevron.up",label:"접기",identifier:"fold-"+thread.id,alwaysLabel:true,invoke:pick)) }
        if top.isEmpty { top=postPieces(root,conversational:false) }
        return NativeThreadCard.Content(id:thread.id,top:top,replies:answer.isEmpty ? nil : answer,rail:nil,actions:actions,deleting:nil,
            style:.init(inset:ThreadAppearance.inset,fill:0,stroke:highlighted ? .systemOrange : target ? .controlAccentColor : NSColor.labelColor.withAlphaComponent(dark ? 0.16 : 0.12),lineWidth:highlighted ? 2.5 : target ? 1.5 : 1,background:ThreadAppearance.surface(dark:dark),status:tone,replyBackground:ThreadAppearance.replySurface(dark:dark)),
            bell:controller.model.unread(thread.key)>0 ? true : nil,onBell:{ [weak self] in self?.controller.model.select(thread.key) },clickCard:pick,textClick:!expanded && foldable ? pick : nil,
            bubbleWidth:max(ChatMetrics.minimumBubbleWidth,(bounds.width-sidebarWidth)*ChatMetrics.bubbleWidthFraction),quiet:NSColor.labelColor.withAlphaComponent(0.7),expanded:expanded,replyTarget:target)
    }
    private func postPieces(_ message:ConversationMessage,conversational:Bool)->[NativeThreadCard.Piece] {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua, mine=message.role == "owner"
        let foldable = !mine && !message.streaming && LongReply.needsFolding(message.text), folded=foldable && !expandedMessages.contains(message.id)
        let body=folded ? LongReply.preview(message.text) : message.text, stripped=TextLayout.strip(body)
        let text=NSMutableAttributedString(attributedString:MessageFormat.renderNative(mine ? body : stripped.source,bodySize:ChatMetrics.bodyFont))
        let all=NSRange(location:0,length:text.length), paragraph=NSMutableParagraphStyle(); paragraph.lineSpacing=mine ? 0 : 2
        text.addAttribute(.paragraphStyle,value:paragraph,range:all)
        if mine { text.addAttribute(.foregroundColor,value:UserBubblePalette(dark:dark).foreground.nsColor,range:all) }
        else { TextLayout.apply(to:text,lines:stripped.lines,bar:.systemBlue,lineSpacing:2) }
        text.enumerateAttributes(in:all) { attributes,range,_ in
            if !mine,let font=attributes[.font] as? NSFont,NSFontManager.shared.traits(of:font).contains(.fixedPitchFontMask) {
                text.addAttributes([.font:NSFont.monospacedSystemFont(ofSize:13,weight:.regular),.foregroundColor:dark ? NSColor(srgbRed:0.96,green:0.68,blue:0.36,alpha:1) : NSColor(srgbRed:0.76,green:0.32,blue:0.09,alpha:1),.backgroundColor:NSColor.labelColor.withAlphaComponent(0.1)],range:range)
            }
            if attributes[.link] != nil { text.addAttributes([.underlineStyle:NSUnderlineStyle.single.rawValue,.foregroundColor:mine ? UserBubblePalette(dark:dark).link.nsColor : NSColor.systemBlue],range:range) }
        }
        let post=NativeThreadCard.Post(id:message.id,mine:mine,text:text,speaker:mine ? "나" : controller.model.name(message.key.employee),time:displayTime(message.timestamp),avatar:ProfileAvatar(color:.systemBlue),nameColor:.labelColor,
            conversational:conversational && !mine && !message.streaming && message.files.isEmpty && ThreadAppearance.isConversational(message.text),streaming:message.streaming,
            foldTitle:foldable ? (folded ? "더 보기" : "접기") : nil,fold:{ [weak self] in guard let self else { return }; if self.expandedMessages.contains(message.id) { self.expandedMessages.remove(message.id) } else { self.expandedMessages.insert(message.id) }; self.refresh() },openLink:{ url in if ["http","https","mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) } })
        var pieces:[NativeThreadCard.Piece]=[.post(post)]
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
        if !message.buttons.isEmpty {
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
    private func displayTime(_ value:String)->String {
        let formatter=ISO8601DateFormatter(); formatter.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        guard let date=formatter.date(from:value) ?? ISO8601DateFormatter().date(from:value) else { return "" }
        return DateFormatter.localizedString(from:date,dateStyle:.none,timeStyle:.short)
    }
}
