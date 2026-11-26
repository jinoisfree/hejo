import AppKit

/// Display rows carry snippets only; choosing a row resolves its message anchor.
struct WorkspaceDisplayGroup {
    var key: ConversationKey, rootPreview: String, matches: [WorkspaceDisplayHit], latest: Date
}
struct WorkspaceDisplayHit {
    var id: String, key: ConversationKey, role: String, speaker: String, timestamp: String, body: String, notes: [String]
}
final class WorkspaceDocumentStack:NSStackView {override var isFlipped:Bool {true}}
final class WorkspaceResults: NSScrollView {
    let stack=WorkspaceDocumentStack()
    var onChooseHistory:((ConversationKey,String)->Void)?
    var selection=0
    override init(frame:NSRect) {
        super.init(frame:frame);drawsBackground=false;hasVerticalScroller=true;autohidesScrollers=true
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12;stack.edgeInsets=NSEdgeInsets(top:12,left:12,bottom:12,right:12);documentView=stack
    }
    required init?(coder:NSCoder) {fatalError()}
    func showHistory(_ groups:[HistorySearchGroup],query:String,selection:Int,name:(String)->String,ownerName:String = OwnerProfile.fallbackName,room:(String)->String) {
        let display=groups.map { group in WorkspaceDisplayGroup(key:group.conversationKey,rootPreview:group.rootSnippet,matches:group.matches.map { line in
            WorkspaceDisplayHit(id:line.id,key:line.conversationKey,role:line.role,speaker:line.speaker,timestamp:line.timestamp,body:line.snippet,notes:line.notes)
        },latest:ThreadTools.date(group.latest)) }
        render(display,query:query,selection:selection,name:name,ownerName:ownerName,room:room) { [weak self] _,hit in self?.onChooseHistory?(hit.key,hit.id) }
    }
    func showStatus(_ text:String,retry:(()->Void)?=nil) {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view);view.removeFromSuperview() }
        stack.addArrangedSubview(NSTextField(labelWithString:text))
        if let retry { let button=FileChip(title:"다시 시도");button.invoke=retry;stack.addArrangedSubview(button) }
        needsLayout=true
    }
    private func render(_ groups:[WorkspaceDisplayGroup],query:String,selection:Int,compact:Bool=false,name:(String)->String,ownerName:String,room:(String)->String,choose:@escaping(Int,WorkspaceDisplayHit)->Void) {
        self.selection=selection
        let primary:NSColor=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? .white:.black
        for view in stack.arrangedSubviews {stack.removeArrangedSubview(view);view.removeFromSuperview()}
        func label(_ text:String)->NSTextField {let v=NSTextField(wrappingLabelWithString:text);v.font = .systemFont(ofSize:11);return v}
        let count=label(groups.isEmpty ? "찾는 글이 없어요":"스레드 \(groups.count)개 · 글 \(groups.reduce(0){$0+$1.matches.count})건");count.textColor = .secondaryLabelColor;stack.addArrangedSubview(count)
        for (index,group) in groups.enumerated() {
            let box=NSStackView();box.orientation = .vertical;box.alignment = .leading;box.spacing=8;box.edgeInsets=NSEdgeInsets(top:12,left:12,bottom:12,right:12)
            box.wantsLayer=true;box.layer?.cornerRadius=10;box.layer?.backgroundColor=primary.withAlphaComponent(index==selection ? 0.10:0.035).cgColor;box.layer?.borderWidth=1;box.layer?.borderColor=primary.withAlphaComponent(index==selection ? 0.22:0.06).cgColor
            let title=WorkspaceResultHeader(title:compact ? room(group.key.employee)+" · "+name(group.key.employee):room(group.key.employee),date:compact ? nil:DateFormatter.localizedString(from:group.latest,dateStyle:.long,timeStyle:.none),preview:compact ? nil:group.rootPreview)
            title.onClick={ if let line=group.matches.first {choose(index,line)} };box.addArrangedSubview(title)
            let rootPreview=NSMutableAttributedString(attributedString:WorkspaceSearch.attributed(group.rootPreview,query:query));rootPreview.addAttribute(.font,value:NSFont.systemFont(ofSize:14,weight:.medium),range:NSRange(location:0,length:rootPreview.length));title.preview.attributedStringValue=rootPreview
            for line in group.matches.prefix(3) {
                let speaker=line.role=="owner" ? ownerName:name(line.speaker)
                let heading=FileChip(title:speaker+"  "+DateFormatter.localizedString(from:ThreadTools.date(line.timestamp),dateStyle:.none,timeStyle:.short))
                let header=NSMutableAttributedString(string:heading.title,attributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor])
                let timeStart=(speaker as NSString).length
                header.addAttribute(.foregroundColor,value:NSColor.secondaryLabelColor,range:NSRange(location:timeStart,length:header.length-timeStart));heading.attributedTitle=header
                heading.isBordered=false;heading.font = .systemFont(ofSize:11);heading.alignment = .left
                heading.invoke={ choose(index,line) };if !compact {box.addArrangedSubview(heading)}
                let source=line.body
                let text=label("");if compact {text.maximumNumberOfLines=2;text.lineBreakMode = .byTruncatingTail};text.attributedStringValue=WorkspaceSearch.attributed(source,query:query);box.addArrangedSubview(text)
                let hit=WorkspaceHitView();hit.onClick={ choose(index,line) };text.addSubview(hit);hit.frame=text.bounds;hit.autoresizingMask=[.width,.height]
                if !compact {for note in line.notes {
                    let row=NSStackView();row.spacing=4
                    let file=note.hasPrefix("📎 "),words=file ? String(note.dropFirst(2)):note
                    if file {let icon=NSImageView();icon.image=NSImage(systemSymbolName:"paperclip",accessibilityDescription:nil);icon.contentTintColor=SidebarTone.primary(0.7);row.addArrangedSubview(icon)}
                    let field=label("");field.attributedStringValue=WorkspaceSearch.attributed(WorkspaceSearch.snippet(words,query:query),query:query);field.font = .systemFont(ofSize:11);row.addArrangedSubview(field);box.addArrangedSubview(row)
                    let tap=WorkspaceHitView();tap.onClick={ choose(index,line) };row.addSubview(tap);tap.frame=row.bounds;tap.autoresizingMask=[.width,.height]
                }}
            }
            if group.matches.count>3 {box.addArrangedSubview(label("+\(group.matches.count-3)건"))}
            stack.addArrangedSubview(box)
        }
        needsLayout=true
    }
    override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();needsLayout=true}
    override func layout() {
        super.layout()
        let primary:NSColor=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? .white:.black
        for (index,view) in stack.arrangedSubviews.dropFirst().enumerated() {
            view.layer?.backgroundColor=primary.withAlphaComponent(index==selection ? 0.10:0.035).cgColor
            view.layer?.borderColor=primary.withAlphaComponent(index==selection ? 0.22:0.06).cgColor
        }
        let width=max(1,contentSize.width-24)
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
        toolTip="눌러서 해당 글로 이동"
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
        FileTile.symbol("chevron.right",point:8,at:CGPoint(x:bounds.maxX-13,y:bounds.midY),color:SidebarTone.primary(0.7),weight:.semibold)
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

/// Same easeInOut control points as SlackModel.motion, sampled by the workspace's display clock.
struct WorkspaceEase {
    var from:CGFloat=0,to:CGFloat=0,start:Double=0
    func value(_ now:Double)->CGFloat {
        let x=min(1,max(0,(now-start)/0.24));var lo=0.0,hi=1.0
        for _ in 0..<20 {let t=(lo+hi)/2,one=1-t,at=3*one*one*t*0.42+3*one*t*t*0.58+t*t*t;if at<x {lo=t}else{hi=t}}
        let t=(lo+hi)/2,y=t*t*(3-2*t)
        return x>=1 ? to:from+(to-from)*CGFloat(y)
    }
    mutating func target(_ next:CGFloat,now:Double,immediate:Bool){guard to != next else{if immediate {from=next;start=now-0.24};return};from=immediate ? next:value(now);to=next;start=immediate ? now-0.24:now}
    func pending(_ now:Double)->Bool {now<start+0.24 && from != to}
}
final class WorkspaceFindRow:NSView {
    let field:NSSearchField,glass=NSImageView(),close=NSButton()
    var onClose:(()->Void)?
    init(field:NSSearchField){self.field=field;super.init(frame:.zero)
        field.isBordered=false;field.drawsBackground=false;field.focusRingType = .none;field.font = .systemFont(ofSize:13)
        if let cell=field.cell as? NSSearchFieldCell {cell.searchButtonCell=nil;cell.cancelButtonCell=nil}
        glass.image=NSImage(systemSymbolName:"magnifyingglass",accessibilityDescription:nil);glass.contentTintColor=SidebarTone.primary(0.7)
        close.isBordered=false;close.image=NSImage(systemSymbolName:"xmark.circle.fill",accessibilityDescription:nil);close.contentTintColor=SidebarTone.primary(0.7);close.toolTip="검색 닫기 (Esc)";close.setAccessibilityLabel("검색 닫기 (Esc)");close.target=self;close.action=#selector(pressed)
        for view in [glass,field,close]{addSubview(view)}
    }
    required init?(coder:NSCoder){nil}
    override var isFlipped:Bool{true}
    @objc private func pressed(){onClose?()}
    override func layout(){super.layout();let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua;glass.contentTintColor=CardText.quiet(dark:dark);close.contentTintColor=CardText.quiet(dark:dark);field.textColor=dark ? .white:.black;glass.frame=CGRect(x:12,y:bounds.midY-7,width:14,height:14);close.frame=CGRect(x:bounds.width-26,y:bounds.midY-7,width:14,height:14);field.frame=CGRect(x:34,y:12,width:max(1,bounds.width-68),height:max(17,bounds.height-24))}
}
