import AppKit

@MainActor final class TodoDrawerView: NSView {
    private static let bandHeight:CGFloat=44, inset:CGFloat=6
    private let filters=NSView(), filterTrack=ComposerModeTrack()
    private lazy var close=TodoDrawerButton("✕"){[weak self] in self?.onClose?()}
    private let scroll=NSScrollView(), stack=NSStackView()
    private var appearanceObserver: NSObjectProtocol?
    var onClose: (() -> Void)?
    var onFilter: ((TodoDrawerModel.Filter) -> Void)?
    var onSelect: ((TodoDrawerModel.Card) -> Void)?
    var onCard: ((TodoDrawerModel.Card) -> Void)?
    /// Right-click menu on a deadline card: close as done / cancelled, open its source.
    var onCloseDeadline: ((TodoDrawerModel.Card,String) -> Void)?
    var onUndoClose: (() -> Void)?
    var onOpenSource: ((URL) -> Void)?
    private let footer=NSStackView()
    var avatar: (String) -> ProfileAvatar = {ProfileAvatar(color:PictureCodec.color(name:$0,hex:nil))}
    private var previous: TodoDrawerModel.Snapshot?, previousFilter: TodoDrawerModel.Filter?, previousSelection: String?
    private(set) var selectedID: String?
    override init(frame: NSRect) {
        super.init(frame:frame);wantsLayer=true;layer?.masksToBounds=true
        filters.addSubview(close);filters.addSubview(filterTrack);addSubview(filters)
        close.setAccessibilityLabel("처리할 일 닫기")
        scroll.drawsBackground=false;scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=7
        stack.edgeInsets=NSEdgeInsets(top:Self.inset,left:Self.inset,bottom:Self.inset,right:Self.inset)
        scroll.documentView=stack;addSubview(scroll)
        footer.orientation = .horizontal;footer.edgeInsets=NSEdgeInsets(top:6,left:14,bottom:6,right:14);footer.isHidden=true;addSubview(footer)
        setAccessibilityLabel("처리할 일")
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){ [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay=true;self?.cardViews.forEach{$0.needsDisplay=true} }
        }
    }
    required init?(coder:NSCoder){fatalError()}
    deinit { if let appearanceObserver { NotificationCenter.default.removeObserver(appearanceObserver) } }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay=true;cardViews.forEach{$0.needsDisplay=true}
    }
    override var acceptsFirstResponder: Bool {true}
    override func cancelOperation(_ sender:Any?){onClose?()}
    override func layout(){
        super.layout()
        let footerHeight:CGFloat=footer.isHidden ? 0:32
        let width=PetController.drawerWidth, band=Self.bandHeight
        filters.frame=CGRect(x:0,y:bounds.height-band,width:width,height:band)
        close.frame=CGRect(x:252,y:10,width:24,height:24)
        filterTrack.frame=CGRect(x:14,y:(band-ComposerModeTrack.height)/2,width:230,height:ComposerModeTrack.height)
        let buttons=filterTrack.subviews.compactMap{$0 as? ComposerButton}
        if !buttons.isEmpty {
            let segmentWidth=(filterTrack.bounds.width-2*ComposerModeTrack.inset)/CGFloat(buttons.count)
            for (index,button) in buttons.enumerated() {button.frame=ComposerModeTrack.segment(in:filterTrack.bounds,offset:CGFloat(index)*segmentWidth,width:segmentWidth)}
        }
        footer.frame=CGRect(x:0,y:0,width:PetController.drawerWidth,height:footerHeight)
        scroll.frame=CGRect(x:0,y:footerHeight,width:width,height:max(0,bounds.height-band-footerHeight))
        stack.frame.size.width=PetController.drawerWidth
        stack.layoutSubtreeIfNeeded()
        stack.frame.size.height=max(scroll.frame.height,stack.fittingSize.height)
    }
    // The common title divider is already drawn by ConversationView at y=44.
    func show(_ value:TodoDrawerModel.Snapshot, filter:TodoDrawerModel.Filter, selected:String?) {
        selectedID=selected
        guard value != previous || filter != previousFilter || selected != previousSelection else{return}
        previous=value;previousFilter=filter;previousSelection=selected
        for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}
        func add(_ view:NSView){stack.addArrangedSubview(view);view.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-2*Self.inset).isActive=true}
        for button in filterTrack.subviews {button.removeFromSuperview()}
        for kind in TodoDrawerModel.Filter.allCases where kind != .deadline || value.available {
            let count=kind == .all ? value.total:value.counts[kind] ?? 0
            let button=ComposerButton(title:"\(kind.rawValue) \(count)",point:ComposerModeTrack.point)
            button.textAlpha=count == 0 ? 0.4:1
            button.mode=true;button.chosen=kind == filter;button.state=button.chosen ? .on:.off
            button.setAccessibilitySelected(button.chosen)
            button.invoke={[weak self] in self?.onFilter?(kind)}
            filterTrack.addSubview(button)
        }
        for warning in [value.warning,value.closeWarning].compactMap({$0}) {
            let line=NSTextField(wrappingLabelWithString:warning);line.font = .systemFont(ofSize:11);line.textColor = .secondaryLabelColor;add(line)
        }
        if value.empty {let empty=NSTextField(labelWithString:"모두 처리했어요");empty.textColor = .secondaryLabelColor;empty.font = .systemFont(ofSize:12);add(empty)}
        for (index,cards) in [value.urgent,value.rest].enumerated() where !cards.isEmpty {
            if index==1 && !value.urgent.isEmpty {
                let divider=TodoDrawerDivider();add(divider);divider.heightAnchor.constraint(equalToConstant:1).isActive=true
            }
            for card in cards {
                let view=TodoDrawerCardView(card:card,avatar:avatar(card.employee),selected:card.id == selected){[weak self] in guard let self else{return};self.window?.makeFirstResponder(self);self.onCard?(card)}
                view.menuItems={[weak self] in self?.menu(for:card)}
                add(view);view.heightAnchor.constraint(equalToConstant:52).isActive=true
            }
        }
        for view in footer.arrangedSubviews {footer.removeArrangedSubview(view);view.removeFromSuperview()}
        footer.isHidden=value.undoTitle == nil
        if let title=value.undoTitle {
            let label=NSTextField(labelWithString:"‘\(title)’ 닫음 ·");label.font = .systemFont(ofSize:11);label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byTruncatingTail
            let undo=TodoDrawerButton("되돌리기"){[weak self] in self?.onUndoClose?()};undo.font = .systemFont(ofSize:11,weight:.semibold)
            footer.addArrangedSubview(label);footer.addArrangedSubview(undo)
        }
        needsLayout=true
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
    var cardViews:[TodoDrawerCardView] {stack.arrangedSubviews.compactMap{$0 as? TodoDrawerCardView}}
    var footerText:String? {footer.isHidden ? nil:footer.arrangedSubviews.compactMap{($0 as? NSTextField)?.stringValue}.first}
}

private final class TodoDrawerButton: NSButton {
    let perform: () -> Void
    init(_ text:String,perform:@escaping()->Void){self.perform=perform;super.init(frame:.zero);title=text;bezelStyle = .inline;isBordered=false;target=self;action=#selector(pressed)}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){perform()}
}

private final class TodoDrawerDivider:NSView {
    override func draw(_ dirtyRect:NSRect) {SidebarTone.primary(0.1).setFill();bounds.insetBy(dx:4,dy:0).fill()}
}

final class TodoDrawerCardView: NSView {
    let card:TodoDrawerModel.Card, avatar:ProfileAvatar, selected:Bool
    let perform:()->Void
    var menuItems:(()->NSMenu?)?
    private(set) var hovered=false
    private var tracking:NSTrackingArea?
    override func menu(for event:NSEvent)->NSMenu? {menuItems?()}
    var unlinkedText:String? {card.kind == .deadline && !card.linked ? "연결된 대화 없음":nil}
    var avatarRect:CGRect {CGRect(x:16,y:13,width:26,height:26)}
    init(card:TodoDrawerModel.Card,avatar:ProfileAvatar,selected:Bool,perform:@escaping()->Void){
        self.card=card;self.avatar=avatar;self.selected=selected;self.perform=perform;super.init(frame:.zero)
        setAccessibilityElement(true);setAccessibilityRole(.button)
        setAccessibilityLabel(card.kind.rawValue+" · "+card.title+" · "+card.name+" · "+card.trailing+" · "+card.status)
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
    override func mouseDown(with event:NSEvent){perform()}
    override func accessibilityPerformPress()->Bool{perform();return true}
    override func draw(_ dirtyRect:NSRect){
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let box=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:10,yRadius:10)
        SidebarTone.cardFill(selected:selected,hovered:hovered,dark:dark).setFill();box.fill()
        SidebarTone.cardBorder(selected:selected,hovered:hovered).setStroke();box.lineWidth=1;box.stroke()
        if card.urgent {AttentionRail.color.setFill();NSBezierPath(roundedRect:AttentionRail.rect(in:bounds),xRadius:1.5,yRadius:1.5).fill()}
        let clip=CGPath(roundedRect:avatarRect,cornerWidth:7,cornerHeight:7,transform:nil)
        avatar.draw(in:avatarRect,name:card.name,clipPath:clip)
        func text(_ value:String,_ rect:CGRect,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight = .regular){
            let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
            (value as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
        }
        let trailingWidth=max(28,(card.trailing as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:9)]).width)
        text(card.title,CGRect(x:50,y:10,width:max(0,bounds.width-60-trailingWidth-6),height:16),11.5,.labelColor,.semibold)
        text(card.trailing,CGRect(x:bounds.width-10-trailingWidth,y:12,width:trailingWidth,height:13),9,.secondaryLabelColor)
        let status=NSMutableAttributedString(string:card.status,attributes:[.font:NSFont.systemFont(ofSize:9.5),.foregroundColor:NSColor.secondaryLabelColor])
        if card.statusUrgent {let end=(card.status as NSString).range(of:" · ").location;status.addAttribute(.foregroundColor,value:AttentionRail.color,range:NSRange(location:0,length:end==NSNotFound ? status.length:end))}
        let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
        status.addAttribute(.paragraphStyle,value:style,range:NSRange(location:0,length:status.length))
        status.draw(in:CGRect(x:50,y:28,width:max(0,bounds.width-60),height:15))
    }
}
