import AppKit

@MainActor final class TodoDrawerView: NSView {
    private static let bandHeight:CGFloat=44, inset:CGFloat=6
    weak var controller:ConversationController?
    struct Page {var revision:Int; var rows:[QuestionRow]; var next:String?; var failed=false}
    private struct RowState:Equatable {
        let row:QuestionRow, key:ConversationKey, selection:String?, editing:MessageButton?, pending:Bool, connected:Bool
    }
    private var rowViews=[String:(RowState,NSView)]()
    private var finished=[ConversationKey:(String,Date)]()
    private var expiry:Timer?
    private var pageEnds=[ConversationKey:NSView]()
    private var pages=[ConversationKey:Page](), loads=[ConversationKey:UUID]()
    private var expanded=Set<ConversationKey>(), answered=Set<ConversationKey>()
    private var editing=[String:MessageButton]()
    struct Choice {let key:ConversationKey,row:QuestionRow,button:MessageButton,text:String?}
    private var choices=[Choice](), batchSent=[Choice]()
    private var batchIDs=[String:String]()
    private var batch=false, lastReplyVersion = -1
    private lazy var batchToggle=HejoButton(frame:.zero)
    private let filters=NSView(), filterTrack=ComposerModeTrack()
    private lazy var close=TodoDrawerButton("✕"){[weak self] in self?.onClose?()}
    private let scroll=NSScrollView(), stack=NSStackView()
    private var appearanceObserver: NSObjectProtocol?
    private var viewportObserver: NSObjectProtocol?
    var onViewport: (([TodoDrawerModel.Card]) -> Void)?
    var onClose: (() -> Void)?
    var onFilter: ((TodoDrawerModel.Filter) -> Void)?
    var onSelect: ((TodoDrawerModel.Card) -> Void)?
    var onCard: ((TodoDrawerModel.Card) -> Void)?
    var onComplete: ((TodoDrawerModel.Card) -> Void)?
    /// Right-click menu on a deadline card: close as done / cancelled, open its source.
    var onCloseDeadline: ((TodoDrawerModel.Card,String) -> Void)?
    var onUndoClose: (() -> Void)?
    var onOpenSource: ((URL) -> Void)?
    private let footer=NSStackView()
    private let warnings=NSStackView()
    private let refreshMark=historyRefreshMark("대화 알림을 갱신 중이에요.")
    private var warningText: [String] = []
    var avatar: (String) -> ProfileAvatar = {ProfileAvatar(color:PictureCodec.color(name:$0,hex:nil))}
    private var previous: TodoDrawerModel.Snapshot?, previousFilter: TodoDrawerModel.Filter?, previousSelection: String?
    private(set) var selectedID: String?
    override init(frame: NSRect) {
        super.init(frame:frame);wantsLayer=true;layer?.masksToBounds=true
        filters.addSubview(batchToggle)
        batchToggle.configure("모아서 보내기",shape:.text) { [weak self] in
            guard let self else{return};self.batch.toggle();self.choices=[];self.batchSent=[];self.batchIDs=[:]
            self.redraw()
        }
        filters.addSubview(close);filters.addSubview(filterTrack);filters.addSubview(refreshMark);addSubview(filters)
        close.setAccessibilityLabel("처리할 일 닫기")
        scroll.drawsBackground=false;scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=7
        stack.edgeInsets=NSEdgeInsets(top:Self.inset,left:Self.inset,bottom:Self.inset,right:Self.inset)
        scroll.documentView=stack;addSubview(scroll)
        scroll.contentView.postsBoundsChangedNotifications = true
        viewportObserver=NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,
            object:scroll.contentView,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportViewport() }
        }
        footer.orientation = .horizontal;footer.edgeInsets=NSEdgeInsets(top:6,left:14,bottom:6,right:14);footer.isHidden=true;addSubview(footer)
        warnings.orientation = .vertical
        warnings.alignment = .leading
        warnings.spacing = 3
        warnings.edgeInsets = NSEdgeInsets(top:6,left:14,bottom:6,right:14)
        warnings.wantsLayer = true
        warnings.isHidden = true
        addSubview(warnings)
        setAccessibilityLabel("처리할 일")
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){ [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay=true;self?.cardViews.forEach{$0.needsDisplay=true} }
        }
    }
    required init?(coder:NSCoder){fatalError()}
    deinit {
        if let appearanceObserver { NotificationCenter.default.removeObserver(appearanceObserver) }
        if let viewportObserver { NotificationCenter.default.removeObserver(viewportObserver) }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay=true;cardViews.forEach{$0.needsDisplay=true}
    }
    override var acceptsFirstResponder: Bool {true}
    override func cancelOperation(_ sender:Any?){onClose?()}
    override func layout(){
        super.layout()
        let footerHeight:CGFloat=footer.isHidden ? 0:32
        let width=PetController.drawerWidth, band=Self.bandHeight+(batchToggle.isHidden ? 0:24)
        filters.frame=CGRect(x:0,y:bounds.height-band,width:width,height:band)
        batchToggle.frame=CGRect(x:14,y:2,width:105,height:22)
        close.frame=CGRect(x:252,y:band-34,width:24,height:24)
        filterTrack.frame=CGRect(x:14,y:band-(Self.bandHeight+ComposerModeTrack.height)/2,width:230,height:ComposerModeTrack.height)
        refreshMark.frame=CGRect(x:width-14,y:(band-16)/2,width:14,height:16)
        let buttons=filterTrack.subviews.compactMap{$0 as? ComposerButton}
        if !buttons.isEmpty {
            let segmentWidth=(filterTrack.bounds.width-2*ComposerModeTrack.inset)/CGFloat(buttons.count)
            for (index,button) in buttons.enumerated() {button.frame=ComposerModeTrack.segment(in:filterTrack.bounds,offset:CGFloat(index)*segmentWidth,width:segmentWidth)}
        }
        footer.frame=CGRect(x:0,y:0,width:width,height:footerHeight)
        if !warnings.isHidden {
            let size = warnings.fittingSize
            warnings.frame = CGRect(x:0,y:footerHeight,width:width,height:size.height)
            warnings.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
        scroll.frame=CGRect(x:0,y:footerHeight,width:width,height:max(0,bounds.height-band-footerHeight))
        stack.frame.size.width=PetController.drawerWidth
        stack.layoutSubtreeIfNeeded()
        stack.frame.size.height=max(scroll.frame.height,stack.fittingSize.height)
        stack.layoutSubtreeIfNeeded()
        reportViewport()
    }

    private func reportViewport() {
        guard !isHidden,scroll.contentView.bounds.height > 0 else { return }
        let visible = scroll.contentView.bounds
        let nearby = visible.insetBy(dx:0,dy:-visible.height)
        var shown: [TodoDrawerModel.Card] = [], adjacent: [TodoDrawerModel.Card] = []
        for view in cardViews {
            let frame = view.convert(view.bounds,to:stack)
            if frame.intersects(visible) { shown.append(view.card) }
            else if frame.intersects(nearby) { adjacent.append(view.card) }
        }
        onViewport?(shown+adjacent)
        for (key,end) in pageEnds where pages[key]?.next != nil && end.convert(end.bounds,to:stack).intersects(visible) {
            if let card=cardViews.first(where:{$0.card.key==key})?.card {load(card,more:true)}
        }
    }
    func setHistoryUpdating(_ updating:Bool) { refreshMark.isHidden = !updating }

    // The common title divider is already drawn by ConversationView at y=44.
    func show(_ value:TodoDrawerModel.Snapshot, filter:TodoDrawerModel.Filter, selected:String?) {
        setHistoryUpdating(value.historyUpdating)
        showWarnings([value.warning,value.confirmationWarning ?? value.closeWarning].compactMap { $0 })
        selectedID=selected
        var cardsOnly = value
        cardsOnly.historyUpdating = false
        cardsOnly.gateStatus = .connected
        cardsOnly.failed = false
        cardsOnly.closeFailed = false
        cardsOnly.confirmationFailed = false
        let version=controller?.replyVersion ?? 0
        batchToggle.isHidden = !(value.urgent+value.rest).contains{$0.asksPreview != nil} && !batch
        batchToggle.state=batch ? .on:.off
        guard version != lastReplyVersion || cardsOnly != previous || filter != previousFilter || selected != previousSelection else{return}
        let visibleKeys=Set((value.urgent+value.rest).compactMap(\.key))
        if filter==previousFilter,let old=previous {
            for card in old.urgent+old.rest where card.kind == .question {
                guard let key=card.key,!visibleKeys.contains(key),let rows=card.asksPreview,
                      rows.contains(where:{controller?.lastClick[$0.messageID] != nil}) else {continue}
                finished[key]=(card.title,Date().addingTimeInterval(1))
            }
        }
        finished=finished.filter{!visibleKeys.contains($0.key) && $0.value.1>Date()}
        lastReplyVersion=version;previous=cardsOnly;previousFilter=filter;previousSelection=selected
        rowViews=rowViews.filter{visibleKeys.contains($0.value.0.key)}
        pages=pages.filter{visibleKeys.contains($0.key)}
        pageEnds.removeAll()
        for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}
        func add(_ view:NSView){stack.addArrangedSubview(view);view.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-2*Self.inset).isActive=true}
        for button in filterTrack.subviews {button.removeFromSuperview()}
        for kind in TodoDrawerModel.Filter.allCases where kind != .deadline || value.available {
            let count=kind == .all ? value.total:value.counts[kind] ?? 0
            let button=ComposerButton(title:"\(kind.rawValue) \(count)",point:ComposerModeTrack.point)
            button.usesReplyStyle=true;button.setAccessibilityLabel(kind.rawValue)
            button.textAlpha=count == 0 ? 0.4:1
            button.mode=true;button.chosen=kind == filter;button.state=button.chosen ? .on:.off
            button.setAccessibilitySelected(button.chosen)
            button.invoke={[weak self] in self?.onFilter?(kind)}
            filterTrack.addSubview(button)
        }
        for (_,entry) in finished {
            let done=NSTextField(labelWithString:"✓ "+entry.0);done.textColor = .systemGreen
            done.lineBreakMode = .byTruncatingTail;add(done)
        }
        var nextExpiry=finished.values.map{max(0,$0.1.timeIntervalSinceNow)}.min()
        if value.empty && finished.isEmpty {let empty=NSTextField(labelWithString:"모두 처리했어요");empty.textColor = .secondaryLabelColor;empty.font = .systemFont(ofSize:12);add(empty)}
        for (index,cards) in [value.urgent,value.rest].enumerated() where !cards.isEmpty {
            if index==1 && !value.urgent.isEmpty {
                let divider=TodoDrawerDivider();add(divider);divider.heightAnchor.constraint(equalToConstant:1).isActive=true
            }
            for card in cards {
                let complete: (() -> Void)? = value.completable.contains(card.id) ? { [weak self] in
                    self?.onComplete?(card)
                } : nil
                let view = TodoDrawerCardView(card: card, avatar: avatar(card.employee),
                                             selected: card.id == selected, complete: complete) { [weak self] in
                    guard let self else { return }
                    self.window?.makeFirstResponder(self)
                    self.onCard?(card)
                }
                view.menuItems={[weak self] in self?.menu(for:card)}
                view.heightAnchor.constraint(equalToConstant:52).isActive=true
                if let preview=card.asksPreview,let key=card.key {
                    let revision=card.revision ?? 0
                    if pages[key]?.revision != revision {pages[key]=nil}
                    if batch || expanded.contains(key) || answered.contains(key) {load(card)}
                    let rows=pages[key]?.rows ?? preview
                    let group=NSStackView();group.orientation = .vertical;group.spacing=2;group.alignment = .leading
                    group.wantsLayer=true;group.layer?.cornerRadius=10;group.layer?.borderWidth=1
                    group.layer?.borderColor=NSColor.separatorColor.cgColor
                    group.edgeInsets=NSEdgeInsets(top:1,left:4,bottom:6,right:4)
                    add(group);group.addArrangedSubview(view)
                    view.widthAnchor.constraint(equalTo:group.widthAnchor,constant:-8).isActive=true
                    let section=questionSection(card,rows:rows);group.addArrangedSubview(section)
                    section.widthAnchor.constraint(equalTo:group.widthAnchor,constant:-8).isActive=true
                    pageEnds[key]=section.arrangedSubviews.last
                } else {add(view)}
            }
        }
        for view in footer.arrangedSubviews {footer.removeArrangedSubview(view);view.removeFromSuperview()}
        footer.isHidden=value.undoTitle == nil
        if let title=value.undoTitle {
            let action = "닫음"
            let label=NSTextField(labelWithString:"‘\(title)’ \(action) ·");label.font = .systemFont(ofSize:11);label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
            let undo=TodoDrawerButton("되돌리기"){[weak self] in self?.onUndoClose?()};undo.font = .systemFont(ofSize:11,weight:.semibold)
            footer.addArrangedSubview(label);footer.addArrangedSubview(undo)
        }
        if batch {
            for choice in batchSent where batchIDs[choice.row.messageID]==nil {
                if let receipt=controller?.lastClick[choice.row.messageID] {batchIDs[choice.row.messageID]=receipt}
            }
            footer.isHidden=false
            let summary=NSTextField(labelWithString:selectionSummary)
            summary.font = .systemFont(ofSize:10);summary.lineBreakMode = .byTruncatingTail;summary.toolTip=selectionSummary
            footer.addArrangedSubview(summary)
            let submit=HejoButton(frame:.zero)
            let outstanding=batchSent.compactMap { choice -> (Choice,QuestionAnswer)? in
                guard let answer=controller?.currentAnswer(choice.row.messageID,history:nil,revision:0),
                      batchIDs[choice.row.messageID]==answer.answerID,let controller,controller.undoEnd(answer)>controller.clock() else{return nil}
                return (choice,answer)
            }
            if !outstanding.isEmpty {
                submit.configure("취소") { [weak self] in Task {for (choice,answer) in outstanding {
                    guard let controller=self?.controller,controller.undoEnd(answer)>controller.clock() else{continue}
                    await controller.requestReply("retract",question:choice.row.messageID,key:choice.key,answerID:answer.answerID)
                };self?.batchSent=[];self?.redraw()} }
                if let controller,let end=outstanding.map({controller.undoEnd($0.1)}).min() {
                    submit.remaining={ [weak controller] in end.timeIntervalSince(controller?.clock() ?? Date())/5 }
                    nextExpiry=min(nextExpiry ?? .infinity,end.timeIntervalSince(controller.clock()))
                }
            } else {
                submit.configure("한 번에 보내기",primary:true) { [weak self] in self?.sendChoices() }
                submit.isEnabled = !choices.isEmpty
            }
            footer.addArrangedSubview(submit)
        }
        expiry?.invalidate()
        if let seconds=nextExpiry {
            expiry=Timer.scheduledTimer(withTimeInterval:max(0.05,seconds),repeats:false){[weak self] _ in
                MainActor.assumeIsolated {self?.redraw()}
            }
        }
        needsLayout=true
    }
    var selectionSummary:String {
        var labels=["승인","거절","확인","의견"]
        for choice in choices where !labels.contains(choice.button.label) {labels.append(choice.button.label)}
        return (["\(choices.count)개 정함"]+labels.compactMap {label in
            let count=choices.filter{$0.button.label==label}.count
            return count>0 ? "\(label) \(count)":nil
        }).joined(separator:" · ")
    }
    func resetQuestions() {
        finished.removeAll();expiry?.invalidate();rowViews.removeAll();batch=false;batchIDs=[:];choices=[];batchSent=[];expanded=[];answered=[];pages=[:];loads=[:];editing=[:];previous=nil
    }
    private func redraw() {
        guard let controller else{return};previous=nil
        show(controller.drawerSnapshot,filter:controller.drawerFilter,selected:selectedID)
    }
    private func sendChoices() {
        let outgoing=choices;choices=[];batchSent=outgoing;batchIDs=[:]
        for choice in outgoing {controller?.lastClick[choice.row.messageID]=nil};redraw()
        Task { [weak self] in for choice in outgoing {await self?.controller?.click(choice.button,messageID:choice.row.messageID,key:choice.key,buttons:choice.row.buttons,text:choice.text)} }
    }
    private func load(_ card:TodoDrawerModel.Card,more:Bool=false) {
        guard card.asksPreview != nil,let key=card.key,let revision=card.revision,let controller,
              let context=controller.model.history.context,loads[key]==nil else{return}
        let page=pages[key]
        if !more && page?.revision==revision {return}
        let cursor=more ? page?.next:nil
        let token=UUID();loads[key]=token
        Task { [weak self] in
            guard let self else{return}
            var next=cursor
            for attempt in 0...1 {
                do {
                    var fields:[String:Any]=["target":["room":key.employee,"thread":key.thread]]
                    fields["cursor"]=next
                    let data=try await controller.client.history.query(context:context,kind:"asks",scope:key.employee,fields:fields,retry:false)
                    guard let items=data["items"] as? [[String:Any]] else {throw HistoryFailure.invalidResponse}
                    let rows=try JSONDecoder().decode([QuestionRow].self,from:JSONSerialization.data(withJSONObject:items.filter{$0["removed"] as? Bool != true}))
                    guard loads[key]==token else{return}
                    loads[key]=nil
                    guard context==controller.model.history.context else{redraw();return}
                    pages[key]=Page(revision:revision,rows:(next==nil ? []:page?.rows ?? [])+rows,next:data["next"] as? String)
                    if batch {expanded.insert(key)}
                    redraw();return
                } catch HistoryFailure.server(let code,_) where attempt==0 && ["cursor_expired","unavailable"].contains(code) {
                    next=nil
                } catch {break}
            }
            guard loads[key]==token else{return};loads[key]=nil
            expanded.remove(key);answered.remove(key);pages[key]=Page(revision:revision,rows:card.asksPreview ?? [],next:nil,failed:true)
            redraw()
        }
    }
    private func questionSection(_ card:TodoDrawerModel.Card,rows:[QuestionRow])->NSStackView {
        let section=NSStackView();section.orientation = .vertical;section.alignment = .leading;section.spacing=4
        guard let controller,let key=card.key else{return section}
        let progress=NSTextField(labelWithString:"━  \(card.asksWaiting ?? 0)개 남음");progress.font = .systemFont(ofSize:11);section.addArrangedSubview(progress)
        for var row in rows {
            row.answer=controller.currentAnswer(row.messageID,history:row.answer,revision:card.revision ?? 0)
            let shownResult=controller.lastClick[row.messageID]==row.answer?.answerID || batchSent.contains{$0.row.messageID==row.messageID} || card.asksPreview?.contains{$0.messageID==row.messageID}==true
            if row.answer != nil && !answered.contains(key) && !shownResult {continue}
            let selected=choices.first{$0.row.messageID==row.messageID}
            let state=RowState(row:row,key:key,selection:selected?.button.id,editing:editing[row.messageID],
                pending:controller.replyRequests.values.contains{$0.question==row.messageID},connected:controller.canSend)
            if let (cached,view)=rowViews[row.messageID],cached==state {
                view.removeFromSuperview();section.addArrangedSubview(view)
                view.widthAnchor.constraint(equalTo:section.widthAnchor).isActive=true;continue
            }
            let color:NSColor=row.answer != nil ? .systemGreen:selected==nil ? .systemGray:.systemBlue
            let controls=QuestionControls(row,key:key,controller:controller,circles:true,selected:selected?.button.id,editing:editing[row.messageID],onEdit:{[weak self] option in
                self?.editing[row.messageID]=option;self?.redraw()
            },choose:{ [weak self] button,text in
                guard let self else{return}
                if batch {
                    let old=choices.first{$0.row.messageID==row.messageID};choices.removeAll{$0.row.messageID==row.messageID}
                    if old?.button != button || old?.text != text {choices.append(Choice(key:key,row:row,button:button,text:text))}
                    editing[row.messageID]=nil;redraw()
                } else { Task {await controller.click(button,messageID:row.messageID,key:key,buttons:row.buttons,text:text)} }
            })
            let h=DrawerQuestionLine(text:row.text,color:color,controls:controls)
            h.heightAnchor.constraint(equalToConstant:max(22,controls.fittingSize.height)).isActive=true
            rowViews[row.messageID]=(state,h);section.addArrangedSubview(h);h.widthAnchor.constraint(equalTo:section.widthAnchor).isActive=true
        }
        let extra=(card.asksWaiting ?? 0)-(card.asksPreview?.count ?? 0)
        if extra>0 && !expanded.contains(key) {
            let more=HejoButton(frame:.zero);more.configure("질문 \(extra)개 더",shape:.text) { [weak self] in self?.expanded.insert(key);self?.pages[key]=nil;self?.redraw() }
            section.addArrangedSubview(more)
        }
        if let count=card.asksAnswered,count>0 {
            let fold=HejoButton(frame:.zero);fold.configure((answered.contains(key) ? "▾":"▸")+" 답한 질문 \(count)개",shape:.text){ [weak self] in
                guard let self else{return};if answered.remove(key)==nil {answered.insert(key);if pages[key]?.failed==true {pages[key]=nil}};redraw()
            };section.addArrangedSubview(fold)
        }
        return section
    }
    private func showWarnings(_ text: [String]) {
        guard warningText != text else { return }
        warningText = text
        for view in warnings.arrangedSubviews { view.removeFromSuperview() }
        for warning in text {
            let label = NSTextField(wrappingLabelWithString:warning)
            label.font = .systemFont(ofSize:11)
            label.textColor = .secondaryLabelColor
            label.preferredMaxLayoutWidth = PetController.drawerWidth-28
            warnings.addArrangedSubview(label)
        }
        warnings.isHidden = text.isEmpty
        needsLayout = true
    }

    override func moveDown(_ sender:Any?) {moveSelection(1)}
    override func moveUp(_ sender:Any?) {moveSelection(-1)}
    private func moveSelection(_ delta:Int) {
        guard window?.firstResponder === self else{return}
        let cards=cardViews
        guard !cards.isEmpty else{return}
        let old=cards.firstIndex{$0.card.id==selectedID}
        let index=old.map{min(cards.count-1,max(0,$0+delta))} ?? (delta>0 ? 0:cards.count-1)
        let id=cards[index].card.id;onSelect?(cards[index].card)
        if let card=cardViews.first(where:{$0.card.id==id}) {card.scrollToVisible(card.bounds)}
    }
    override func insertNewline(_ sender:Any?) {
        guard window?.firstResponder === self,let card=cardViews.first(where:{$0.card.id==selectedID}) else{return}
        onCard?(card.card)
    }
    override func keyDown(with event:NSEvent) {interpretKeyEvents([event])}
    private func menu(for card:TodoDrawerModel.Card)->NSMenu? {
        guard card.kind == .deadline,card.deadlineRef != nil else{return nil}
        let menu=NSMenu()
        menu.addItem(RoomActionItem("완료로 닫기"){[weak self] in self?.onCloseDeadline?(card,"done")})
        menu.addItem(RoomActionItem("취소로 닫기"){[weak self] in self?.onCloseDeadline?(card,"cancel")})
        if let url=card.url {menu.addItem(RoomActionItem("출처 열기"){[weak self] in self?.onOpenSource?(url)})}
        return menu
    }
    /// The card views as drawn, for checks that drive the real right-click menu.
    var cardViews:[TodoDrawerCardView] {stack.arrangedSubviews.compactMap{($0 as? TodoDrawerCardView) ?? ($0 as? NSStackView)?.arrangedSubviews.first as? TodoDrawerCardView}}
    var footerText:String? {footer.isHidden ? nil:footer.arrangedSubviews.compactMap{($0 as? NSTextField)?.stringValue}.first}
}

private final class DrawerQuestionLine:NSView {
    private let rail=NSView(), label:NSTextField, controls:QuestionControls
    override var isFlipped:Bool {true}
    init(text:String,color:NSColor,controls:QuestionControls) {
        self.controls=controls;label=NSTextField(labelWithString:text)
        super.init(frame:.zero)
        rail.wantsLayer=true;rail.layer?.backgroundColor=color.cgColor
        label.lineBreakMode = .byTruncatingTail;label.maximumNumberOfLines=1;label.toolTip=text
        addSubview(rail);addSubview(label);addSubview(controls)
    }
    override func layout() {
        super.layout()
        rail.frame=CGRect(x:0,y:0,width:3,height:22)
        let size=controls.fittingSize
        controls.frame=CGRect(x:max(8,bounds.width-size.width),y:0,width:size.width,height:size.height)
        label.frame=CGRect(x:7,y:2,width:max(0,controls.frame.minX-11),height:18)
    }
    required init?(coder:NSCoder){fatalError()}
}
private final class TodoDrawerButton: HejoButton {
    let perform: () -> Void
    init(_ text:String,perform:@escaping()->Void){self.perform=perform;super.init(frame:.zero);configure(text,shape:.text,action:perform)}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){perform()}
}

private final class TodoDrawerDivider:NSView {
    override func draw(_ dirtyRect:NSRect) {SidebarTone.primary(0.1).setFill();bounds.insetBy(dx:4,dy:0).fill()}
}

final class TodoDrawerCardView: NSView {
    let card:TodoDrawerModel.Card, avatar:ProfileAvatar, selected:Bool
    let perform:()->Void
    private let complete: (() -> Void)?
    var menuItems:(()->NSMenu?)?
    private(set) var hovered=false
    private var tracking:NSTrackingArea?
    override func menu(for event:NSEvent)->NSMenu? {menuItems?()}
    var unlinkedText:String? {card.kind == .deadline && !card.linked ? "연결된 대화 없음":nil}
    var avatarRect:CGRect {CGRect(x:16,y:13,width:26,height:26)}
    private static let completionWidth: CGFloat = 44
    var completionRect: CGRect? {
        guard hovered, complete != nil else { return nil }
        return CGRect(x: bounds.maxX - Self.completionWidth, y: bounds.minY,
                      width: Self.completionWidth, height: bounds.height)
    }
    var trailingTextRect: CGRect? {
        guard completionRect == nil else { return nil }
        let width = max(28, (card.trailing as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 9)]).width)
        return CGRect(x: bounds.maxX - 10 - width, y: 12, width: width, height: 13)
    }
    var statusTextRect: CGRect {
        let end = completionRect.map { $0.minX - 8 } ?? (bounds.maxX - 10)
        return CGRect(x: 50, y: 28, width: max(0, end - 50), height: 15)
    }
    init(card: TodoDrawerModel.Card, avatar: ProfileAvatar, selected: Bool,
         complete: (() -> Void)? = nil, perform: @escaping () -> Void) {
        self.card = card
        self.avatar = avatar
        self.selected = selected
        self.complete = complete
        self.perform = perform
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel(card.kind.rawValue+" · "+card.title+" · "+card.name+" · "+card.trailing+" · "+card.status)
        if let complete {
            let name: String
            switch card.kind {
            case .question: name = "확인 보내기"
            case .deadline: name = "완료로 닫기"
            case .alert, .all: name = "읽음으로 표시"
            }
            setAccessibilityCustomActions([NSAccessibilityCustomAction(name: name, handler: {
                complete()
                return true
            })])
        }
    }
    required init?(coder:NSCoder){fatalError()}
    override var isFlipped:Bool {true}
    override func updateTrackingAreas() {
        super.updateTrackingAreas();if let tracking {removeTrackingArea(tracking)}
        let area=NSTrackingArea(rect:bounds,options:[.mouseEnteredAndExited,.activeInKeyWindow,.inVisibleRect],owner:self,userInfo:nil)
        tracking=area;addTrackingArea(area)
    }
    override func mouseEntered(with event:NSEvent){hovered=true;needsDisplay=true}
    override func mouseExited(with event:NSEvent){hovered=false;needsDisplay=true}
    override func mouseDown(with event: NSEvent) {
        if let strip = completionRect, strip.contains(convert(event.locationInWindow, from: nil)) {
            complete?()
        } else {
            perform()
        }
    }
    override func accessibilityPerformPress()->Bool{perform();return true}
    override func draw(_ dirtyRect:NSRect){
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let box=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:10,yRadius:10)
        if card.asksPreview==nil {SidebarTone.cardFill(selected:selected,hovered:hovered,dark:dark).setFill();box.fill()}
        if let strip = completionRect {
            NSGraphicsContext.saveGraphicsState()
            box.addClip()
            NSColor.systemGreen.setFill()
            strip.fill()
            NSColor.white.setStroke()
            let check = NSBezierPath()
            check.lineWidth = 2
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.move(to: CGPoint(x: strip.midX - 6, y: strip.midY))
            check.line(to: CGPoint(x: strip.midX - 2, y: strip.midY + 4))
            check.line(to: CGPoint(x: strip.midX + 6, y: strip.midY - 4))
            check.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        if card.asksPreview==nil {SidebarTone.cardBorder(selected:selected,hovered:hovered).setStroke();box.lineWidth=1;box.stroke()}
        if card.urgent {AttentionRail.color.setFill();NSBezierPath(roundedRect:AttentionRail.rect(in:bounds),xRadius:1.5,yRadius:1.5).fill()}
        let clip=CGPath(roundedRect:avatarRect,cornerWidth:7,cornerHeight:7,transform:nil)
        avatar.draw(in:avatarRect,name:card.name,clipPath:clip)
        func text(_ value:String,_ rect:CGRect,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight = .regular){
            let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
            (value as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
        }
        let trailing = trailingTextRect
        let titleEnd = trailing.map { $0.minX - 6 } ?? statusTextRect.maxX
        text(card.title, CGRect(x: 50, y: 10, width: max(0, titleEnd - 50), height: 16), 11.5, .labelColor, .semibold)
        if let trailing { text(card.trailing, trailing, 9, .secondaryLabelColor) }
        let status=NSMutableAttributedString(string:card.status,attributes:[.font:NSFont.systemFont(ofSize:9.5),.foregroundColor:NSColor.secondaryLabelColor])
        if card.statusUrgent {let end=(card.status as NSString).range(of:" · ").location;status.addAttribute(.foregroundColor,value:AttentionRail.color,range:NSRange(location:0,length:end==NSNotFound ? status.length:end))}
        let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
        status.addAttribute(.paragraphStyle,value:style,range:NSRange(location:0,length:status.length))
        status.draw(in: statusTextRect)
    }
}
