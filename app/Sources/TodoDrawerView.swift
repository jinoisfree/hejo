import AppKit

@MainActor final class TodoDrawerView: NSView {
    private let scroll=NSScrollView(), stack=NSStackView()
    // The installed PetView supplies its existing conversation tint, rather than
    // introducing a second theme palette for the drawer.
    var backgroundColor: NSColor = .windowBackgroundColor { didSet { needsDisplay=true } }
    private var appearanceObserver: NSObjectProtocol?
    var onClose: (() -> Void)?
    var onFilter: ((TodoDrawerModel.Filter) -> Void)?
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
        super.init(frame:frame);wantsLayer=true
        scroll.drawsBackground=false;scroll.hasVerticalScroller=true;scroll.autohidesScrollers=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=10
        stack.edgeInsets=NSEdgeInsets(top:14,left:14,bottom:14,right:14)
        scroll.documentView=stack;addSubview(scroll)
        footer.orientation = .horizontal;footer.edgeInsets=NSEdgeInsets(top:6,left:14,bottom:6,right:14);footer.isHidden=true;addSubview(footer)
        setAccessibilityLabel("처리할 일")
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){ [weak self] _ in
            MainActor.assumeIsolated { self?.needsDisplay=true }
        }
    }
    required init?(coder:NSCoder){fatalError()}
    deinit { if let appearanceObserver { NotificationCenter.default.removeObserver(appearanceObserver) } }
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.withAlphaComponent(1).setFill()
        bounds.fill()
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay=true
    }
    override var acceptsFirstResponder: Bool {true}
    override func cancelOperation(_ sender:Any?){onClose?()}
    override func layout(){
        super.layout()
        let footerHeight:CGFloat=footer.isHidden ? 0:32
        footer.frame=CGRect(x:0,y:0,width:bounds.width,height:footerHeight)
        scroll.frame=CGRect(x:0,y:footerHeight,width:bounds.width,height:max(0,bounds.height-footerHeight))
        stack.frame.size.width=bounds.width
        stack.layoutSubtreeIfNeeded()
        stack.frame.size.height=max(scroll.frame.height,stack.fittingSize.height)
    }
    func show(_ value:TodoDrawerModel.Snapshot, filter:TodoDrawerModel.Filter, selected:String?) {
        selectedID=selected
        guard value != previous || filter != previousFilter || selected != previousSelection else{return}
        previous=value;previousFilter=filter;previousSelection=selected
        for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}
        func add(_ view:NSView){stack.addArrangedSubview(view);view.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-28).isActive=true}
        let heading=NSStackView();heading.orientation = .horizontal
        let title=NSTextField(labelWithString:"처리할 일  \(value.total)");title.font = .systemFont(ofSize:16,weight:.semibold)
        heading.addArrangedSubview(title);heading.addArrangedSubview(NSView())
        let close=TodoDrawerButton("‹ 접기"){[weak self] in self?.onClose?()};heading.addArrangedSubview(close);add(heading)
        let chips=NSStackView();chips.spacing=3
        for kind in TodoDrawerModel.Filter.allCases where kind != .deadline || value.available {
            let name=kind == .all ? kind.rawValue:"\(kind.rawValue) \(value.counts[kind] ?? 0)"
            let button=TodoDrawerButton(name){[weak self] in self?.onFilter?(kind)}
            button.font = .systemFont(ofSize:10,weight:kind == filter ? .bold:.regular)
            button.contentTintColor=kind == filter ? .controlAccentColor:.secondaryLabelColor
            chips.addArrangedSubview(button)
        }
        add(chips)
        for warning in [value.warning,value.closeWarning].compactMap({$0}) {
            let line=NSTextField(wrappingLabelWithString:warning);line.font = .systemFont(ofSize:11);line.textColor = .secondaryLabelColor;add(line)
        }
        if value.empty {let empty=NSTextField(labelWithString:"처리할 일이 없어요");empty.textColor = .secondaryLabelColor;empty.font = .systemFont(ofSize:12);add(empty)}
        for (title,cards) in [("급한 것",value.urgent),("나머지",value.rest)] where !cards.isEmpty {
            let label=NSTextField(labelWithString:"\(title)  \(cards.count)");label.font = .systemFont(ofSize:11,weight:.semibold);label.textColor = .secondaryLabelColor;add(label)
            for card in cards {
                let view=TodoDrawerCardView(card:card,avatar:avatar(card.employee),selected:card.id == selected){[weak self] in self?.onCard?(card)}
                view.menuItems={[weak self] in self?.menu(for:card)}
                add(view);view.heightAnchor.constraint(equalToConstant:90).isActive=true
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

final class TodoDrawerCardView: NSView {
    let card:TodoDrawerModel.Card, avatar:ProfileAvatar, selected:Bool
    let perform:()->Void
    var menuItems:(()->NSMenu?)?
    override func menu(for event:NSEvent)->NSMenu? {menuItems?()}
    /// Deadlines with neither a notice in the chat nor a link say so, instead of guessing a room.
    var unlinkedText:String? {card.kind == .deadline && !card.linked ? "연결된 대화 없음":nil}
    init(card:TodoDrawerModel.Card,avatar:ProfileAvatar,selected:Bool,perform:@escaping()->Void){
        self.card=card;self.avatar=avatar;self.selected=selected;self.perform=perform;super.init(frame:.zero)
        setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel(card.badge+" · "+card.title+" · "+card.name+" · "+card.time+(unlinkedText.map{" · "+$0} ?? ""))
    }
    required init?(coder:NSCoder){fatalError()}
    override var isFlipped:Bool {true}
    override func mouseDown(with event:NSEvent){perform()}
    override func accessibilityPerformPress()->Bool{perform();return true}
    override func draw(_ dirtyRect:NSRect){
        let urgent=card.kind == .question || card.kind == .deadline && card.urgent
        let tone: NSColor = urgent ? .systemRed:.secondaryLabelColor
        let box=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:10,yRadius:10)
        tone.withAlphaComponent(urgent ? 0.07:0.035).setFill();box.fill()
        (selected ? NSColor.controlAccentColor:tone.withAlphaComponent(0.18)).setStroke();box.lineWidth=selected ? 2:1;box.stroke()
        func text(_ value:String,_ rect:CGRect,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight = .regular){
            let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
            (value as NSString).draw(in:rect,withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
        }
        text(card.badge,CGRect(x:12,y:10,width:bounds.width-24,height:16),10,tone,.semibold)
        if let unlinkedText {
            let style=NSMutableParagraphStyle();style.alignment = .right
            (unlinkedText as NSString).draw(in:CGRect(x:bounds.width-112,y:10,width:100,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.secondaryLabelColor,.paragraphStyle:style])
        }
        text(card.title,CGRect(x:12,y:31,width:bounds.width-24,height:20),12,.labelColor,.medium)
        avatar.draw(in:CGRect(x:12,y:62,width:16,height:16),name:card.name)
        text(card.name+" · "+card.time,CGRect(x:34,y:62,width:bounds.width-46,height:18),10,.secondaryLabelColor)
    }
}

/// A real hit-testable overlay, confined to the chat while the drawer covers it.
final class TodoDrawerScrim: NSView {
    var onClose:(()->Void)?
    override func mouseDown(with event:NSEvent){onClose?()}
    override func draw(_ dirtyRect:NSRect){NSColor.black.withAlphaComponent(0.14).setFill();bounds.fill()}
}
