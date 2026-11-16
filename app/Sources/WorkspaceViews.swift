import AppKit

/// Search results are an ephemeral view over the local projection, never another message store.
final class WorkspaceDocumentStack:NSStackView {override var isFlipped:Bool {true}}
final class WorkspaceResults: NSScrollView {
    let stack=WorkspaceDocumentStack()
    var onChoose:((Int,ConversationMessage)->Void)?
    var groups:[WorkspaceSearch.Group]=[]
    var selection=0
    override init(frame:NSRect) {
        super.init(frame:frame);drawsBackground=false;hasVerticalScroller=true;autohidesScrollers=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12;stack.edgeInsets=NSEdgeInsets(top:12,left:12,bottom:12,right:12);documentView=stack
    }
    required init?(coder:NSCoder) {fatalError()}
    func show(_ groups:[WorkspaceSearch.Group],query:String,selection:Int,compact:Bool=false,name:(String)->String,room:(String)->String) {
        self.groups=groups;self.selection=selection
        for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}
        func label(_ text:String)->NSTextField {let v=NSTextField(wrappingLabelWithString:text);v.font = .systemFont(ofSize:11);return v}
        let count=label(groups.isEmpty ? "찾는 글이 없어요":"스레드 \(groups.count)개 · 글 \(groups.reduce(0){$0+$1.matches.count})건");count.textColor = .secondaryLabelColor;stack.addArrangedSubview(count)
        for (index,group) in groups.enumerated() {
            let box=NSStackView();box.orientation = .vertical;box.alignment = .leading;box.spacing=8;box.edgeInsets=NSEdgeInsets(top:12,left:12,bottom:12,right:12)
            box.wantsLayer=true;box.layer?.cornerRadius=10;box.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(index==selection ? 0.10:0.035).cgColor;box.layer?.borderWidth=1;box.layer?.borderColor=NSColor.labelColor.withAlphaComponent(index==selection ? 0.22:0.06).cgColor
            let title=WorkspaceResultHeader(title:compact ? room(group.key.employee)+" · "+name(group.key.employee):room(group.key.employee),date:compact ? nil:DateFormatter.localizedString(from:group.latest,dateStyle:.long,timeStyle:.none),preview:compact ? nil:WorkspaceSearch.snippet(group.root.text,query:query))
            title.onClick={ [weak self] in if let line=group.matches.first {self?.onChoose?(index,line)} };box.addArrangedSubview(title)
            for line in group.matches.prefix(3) {
                let speaker=line.role=="owner" ? "나":name(line.key.employee)
                let heading=FileChip(title:speaker+"  "+DateFormatter.localizedString(from:ThreadTools.date(line.timestamp),dateStyle:.none,timeStyle:.short))
                let header=NSMutableAttributedString(string:heading.title,attributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor])
                let timeStart=(speaker as NSString).length
                header.addAttribute(.foregroundColor,value:NSColor.secondaryLabelColor,range:NSRange(location:timeStart,length:header.length-timeStart));heading.attributedTitle=header
                heading.isBordered=false;heading.font = .systemFont(ofSize:11);heading.alignment = .left
                heading.invoke={ [weak self] in self?.onChoose?(index,line) };if !compact {box.addArrangedSubview(heading)}
                let preview=WorkspaceSearch.preview(query,message:line)
                let source=compact ? ([preview.body]+preview.notes).joined(separator:"\n"):preview.body
                let text=label("");if compact {text.maximumNumberOfLines=2;text.lineBreakMode = .byTruncatingTail};text.attributedStringValue=WorkspaceSearch.attributed(WorkspaceSearch.snippet(source,query:query),query:query);box.addArrangedSubview(text)
                let hit=WorkspaceHitView();hit.onClick={ [weak self] in self?.onChoose?(index,line) };text.addSubview(hit);hit.frame=text.bounds;hit.autoresizingMask=[.width,.height]
                if !compact {for note in preview.notes {let field=label("");field.attributedStringValue=WorkspaceSearch.attributed(WorkspaceSearch.snippet(note,query:query),query:query);box.addArrangedSubview(field);let tap=WorkspaceHitView();tap.onClick={ [weak self] in self?.onChoose?(index,line) };field.addSubview(tap);tap.frame=field.bounds;tap.autoresizingMask=[.width,.height]}}
            }
            if group.matches.count>3 {box.addArrangedSubview(label("+\(group.matches.count-3)건"))}
            stack.addArrangedSubview(box)
        }
        needsLayout=true
    }
    override func layout() {
        super.layout();let width=max(1,contentSize.width-24)
        for view in stack.arrangedSubviews {
            if let constraint=view.constraints.first(where:{$0.identifier=="workspace-width"}) {constraint.constant=width}
            else {let constraint=view.widthAnchor.constraint(equalToConstant:width);constraint.identifier="workspace-width";constraint.isActive=true}
            if let box=view as? NSStackView {for item in box.arrangedSubviews {
                let childWidth=max(1,width-24)
                if let constraint=item.constraints.first(where:{$0.identifier=="workspace-child-width"}) {constraint.constant=childWidth}
                else {let constraint=item.widthAnchor.constraint(equalToConstant:childWidth);constraint.identifier="workspace-child-width";constraint.isActive=true}
                if let field=item as? NSTextField {field.preferredMaxLayoutWidth=childWidth}
            }}
        }
        stack.frame=CGRect(x:0,y:0,width:contentSize.width,height:stack.fittingSize.height);stack.layoutSubtreeIfNeeded()
        if stack.arrangedSubviews.indices.contains(selection+1) {stack.scrollToVisible(stack.arrangedSubviews[selection+1].frame)}
    }
}
final class WorkspaceHitView:NSView {
    var onClick:(()->Void)?
    override func mouseDown(with event:NSEvent) {onClick?()}
}

/// AppKit drawing of the reviewed dot/title/count/chevron capsule.
final class NoticePill:NSButton {
    let item:RoomNotice
    var invoke:(()->Void)?
    var tint:NSColor {MessageFormat.color(item.questions ? "#ECB22E":"#36C5F0")!}
    init(_ item:RoomNotice) {
        self.item=item;super.init(frame:.zero);title=item.title;isBordered=false;target=self;action=#selector(pressed)
        setAccessibilityLabel("\(item.title) \(item.messages.count)건, 눌러서 이동");setAccessibilityIdentifier("notice-"+item.id)
    }
    required init?(coder:NSCoder) {fatalError()}
    @objc private func pressed() {invoke?()}
    override var intrinsicContentSize:NSSize {
        let title=(item.title as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium)]).width
        let count=(String(item.messages.count) as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:11)]).width
        return NSSize(width:18+8+15+title+count+8,height:23)
    }
    override func draw(_ dirtyRect:NSRect) {
        let rect=bounds.insetBy(dx:0.5,dy:0.5),path=NSBezierPath(roundedRect:rect,xRadius:rect.height/2,yRadius:rect.height/2)
        tint.withAlphaComponent(0.16).setFill();path.fill();tint.withAlphaComponent(0.45).setStroke();path.lineWidth=1;path.stroke()
        tint.setFill();NSBezierPath(ovalIn:CGRect(x:9,y:bounds.midY-4,width:8,height:8)).fill()
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.labelColor]
        let size=(item.title as NSString).size(withAttributes:attrs)
        (item.title as NSString).draw(at:CGPoint(x:22,y:bounds.midY-size.height/2),withAttributes:attrs)
        (String(item.messages.count) as NSString).draw(at:CGPoint(x:27+size.width,y:bounds.midY-size.height/2),withAttributes:[.font:NSFont.boldSystemFont(ofSize:11),.foregroundColor:NSColor.labelColor])
        NSImage(systemSymbolName:"chevron.right",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:8,weight:.semibold))?.draw(in:CGRect(x:bounds.maxX-17,y:bounds.midY-4,width:8,height:8))
    }
}

/// Two independent rows keep the room/date and one-line root preview aligned during resizing.
final class WorkspaceResultHeader:NSView {
    let heading=NSTextField(labelWithString:""),date=NSTextField(labelWithString:""),preview=NSTextField(labelWithString:"")
    var onClick:(()->Void)?
    private let hasPreview:Bool
    init(title:String,date:String?,preview:String?) {
        hasPreview=preview != nil;super.init(frame:.zero)
        heading.stringValue=title;heading.font = .systemFont(ofSize:11,weight:.semibold)
        self.date.stringValue=date ?? "";self.date.font = .systemFont(ofSize:11);self.date.textColor = .secondaryLabelColor
        self.preview.stringValue=preview ?? "";self.preview.font = .systemFont(ofSize:ChatMetrics.nameFont,weight:.medium)
        for field in [heading,self.date,self.preview] {field.maximumNumberOfLines=1;field.lineBreakMode = .byTruncatingTail;addSubview(field)}
        self.preview.isHidden = !hasPreview
        setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel(title)
    }
    required init?(coder:NSCoder) {fatalError()}
    override var isFlipped:Bool {true}
    override var intrinsicContentSize:NSSize {NSSize(width:200,height:hasPreview ? 36:17)}
    override func hitTest(_ point:NSPoint)->NSView? {bounds.contains(point) ? self:nil}
    override func mouseDown(with event:NSEvent) {onClick?()}
    override func layout() {
        super.layout();let width=min(bounds.width,ceil((date.stringValue as NSString).size(withAttributes:[.font:date.font!]).width)+6)
        date.frame=CGRect(x:bounds.width-width,y:0,width:width,height:15)
        heading.frame=CGRect(x:0,y:0,width:max(0,bounds.width-width-8),height:15)
        preview.frame=CGRect(x:0,y:19,width:bounds.width,height:17)
    }
}
