import AppKit

/// Geometry from the reviewed room strip; rooms become employees, without group sections.
enum ConversationSidebar {
    static let width: CGFloat = 68, expandedWidth: CGFloat = 212, tabHeight: CGFloat = 72
    static let listMinimum: CGFloat = 180, listMaximum: CGFloat = 300, rowHeight: CGFloat = 58
    static let listThreshold: CGFloat = 124, hideThreshold: CGFloat = 34
    static let inset: CGFloat = 6, faces: CGFloat = 34
    static func isList(_ width: CGFloat) -> Bool { width >= listThreshold }
    static func snapped(_ dragged: CGFloat) -> CGFloat {
        if dragged < hideThreshold { return 0 }
        if dragged < listThreshold { return width }
        return min(listMaximum,max(listMinimum,dragged))
    }
}
final class SidebarAXMark:NSView {
    override func hitTest(_ point:NSPoint)->NSView?{nil}
}
/// AppKit retains cell heights across animated row updates unless the row lays them out.
final class SidebarRowView:NSTableRowView {
    override func layout(){
        super.layout()
        for case let cell as EmployeeSidebarCell in subviews where cell.frame != bounds {
            cell.frame=bounds
        }
    }
}
/// Room ink must composite above the selection, not in the backing layer below it.
private final class SidebarRoomInk:NSView {
    weak var cell:EmployeeSidebarCell?
    override var isFlipped:Bool{true}
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    override func draw(_ dirtyRect:NSRect){cell?.drawRoomContents()}
}
final class EmployeeSidebarCell:NSTableCellView {
    var name="",unread=0,chosen=false,muted=false,pinned=false,dropTarget=false
    var list=false {didSet{if oldValue != list,duration>0 {let fade=CATransition();fade.type = .fade;fade.duration=duration;fade.timingFunction=SidebarMotion.curve;layer?.add(fade,forKey:"sidebar-form")}}}
    var faces:[(String,ProfileAvatar)]=[],row:SidebarLayout.Row?,picture:NSImage?
    var duration:Double=0
    let selection=CALayer(),heading=CATextLayer(),freshnessMark=CATextLayer()
    private let counters=(0..<3).map{_ in CALayer()},numbers=(0..<3).map{_ in CATextLayer()},dots=(0..<3).map{_ in CALayer()}
    private let marks=(0..<5).map{_ in SidebarAXMark()}
    private var wasChosen=false
    private let roomInk=SidebarRoomInk()
    override init(frame:CGRect){
        super.init(frame:frame);wantsLayer=true
        selection.cornerRadius=10;selection.opacity=0;layer?.addSublayer(selection)
        roomInk.cell=self;roomInk.wantsLayer=true;roomInk.layer?.zPosition=1;addSubview(roomInk)
        heading.zPosition=2;layer?.addSublayer(heading)
        for i in 0..<3 {counters[i].zPosition=2;dots[i].zPosition=2;layer?.addSublayer(counters[i]);counters[i].addSublayer(numbers[i]);layer?.addSublayer(dots[i]);numbers[i].alignmentMode = .center; numbers[i].contentsScale=NSScreen.main?.backingScaleFactor ?? 2}
        freshnessMark.zPosition=2;layer?.addSublayer(freshnessMark);freshnessMark.contentsScale=NSScreen.main?.backingScaleFactor ?? 2;freshnessMark.alignmentMode = .center;freshnessMark.fontSize=12
        heading.contentsScale=NSScreen.main?.backingScaleFactor ?? 2;heading.truncationMode = .end
        for mark in marks {addSubview(mark);mark.setAccessibilityElement(true);mark.setAccessibilityRole(.image)}
    }
    required init?(coder:NSCoder){nil}
    override var isFlipped:Bool{true}
    override func menu(for event:NSEvent)->NSMenu?{(enclosingScrollView?.documentView as? EmployeeMenuTable)?.menu(for:event)}
    func refreshChrome(){effectiveAppearance.performAsCurrentDrawingAppearance{refreshChromeInCurrentAppearance()}}
    private func refreshChromeInCurrentAppearance(){
        guard let row else{return};let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua,header=row.kind == .section || row.kind == .stack
        let tint=NSColor.labelColor
        heading.isHidden = !header
        if header {
            let font=NSFont.systemFont(ofSize:list ? 16:13,weight:.bold);heading.font=font;heading.fontSize=font.pointSize;heading.string=name;heading.alignmentMode=list ? .left:.center
            let color=row.open ? (dark ? NSColor.white:tint):SidebarTone.primary(dark ? 0.78:0.75)
            SidebarMotion.change(heading,key:"foregroundColor",to:color.cgColor,duration:duration)
        }
        selection.backgroundColor=SidebarTone.selection(dark:dark).cgColor
        if wasChosen != chosen || duration==0 {SidebarMotion.change(selection,key:"opacity",to:chosen && !header ? 1.0:0.0,duration:duration,spring:true);wasChosen=chosen}
        let colors:[NSColor]=[list ? .systemBlue:.systemRed,MessageFormat.color("#ECB22E")!,MessageFormat.color("#36C5F0")!]
        let values=[unread,row.questions,row.alerts],labels=["안 읽은 글","답을 기다리는 질문","읽지 않은 알림"]
        for i in 0..<3 {
            let home=row.kind == .home
            counters[i].isHidden=home;numbers[i].isHidden=home;dots[i].isHidden=home
            let show=values[i]>0 && !home && row.freshness != .unknown
            SidebarMotion.change(counters[i],key:"opacity",to:show && !header ? 1.0:0.0,duration:duration)
            SidebarMotion.change(counters[i],key:"backgroundColor",to:colors[i].cgColor,duration:duration)
            counters[i].borderColor=(dark ? NSColor(white:0.12,alpha:1):.white).cgColor;counters[i].borderWidth=1
            numbers[i].string=SidebarLayout.badge(values[i]);numbers[i].font=NSFont.boldSystemFont(ofSize:list ? 9:7);numbers[i].fontSize=list ? 9:7;numbers[i].foregroundColor=(i==1 ? NSColor.black:.white).cgColor
            SidebarMotion.change(dots[i],key:"backgroundColor",to:colors[i].cgColor,duration:duration)
            SidebarMotion.change(dots[i],key:"opacity",to:show && header ? 1.0:0.0,duration:duration)
            marks[i].isHidden = !show || header;marks[i].setAccessibilityLabel("\(labels[i]) \(values[i])개")
        }
        marks[3].isHidden = !pinned || header;marks[3].setAccessibilityLabel("고정됨");marks[4].isHidden = !muted || header;marks[4].setAccessibilityLabel("알림 꺼짐")
        if header {
            let labels=[unread>0 ? "안 읽은 글 있음":nil,row.questions>0 ? "답을 기다리는 질문 있음":nil,row.alerts>0 ? "읽지 않은 알림 있음":nil].compactMap{$0}
            setAccessibilityLabel("\(name) \(row.items.count)개"+(!row.open && !labels.isEmpty ? ", 새 글 있음":"")+(row.open ? ", 펼쳐짐":", 접힘"));setAccessibilityValue(labels.joined(separator:", "))
            toolTip=name+" · 오른쪽 클릭으로 이름 편집 · "+(row.open ? "접기":"펼치기")
        } else {setAccessibilityLabel(name+(unread>0 ? ", 새 글 \(unread)개":"")+(faces.isEmpty ? "":", "+faces.map(\.0).joined(separator:", ")));toolTip=name}
        freshnessMark.isHidden = row.freshness == .ready
        freshnessMark.string = row.freshness == .unknown ? "?":"↻"
        freshnessMark.foregroundColor = NSColor.secondaryLabelColor.cgColor
        if row.freshness != .ready {
            toolTip = (toolTip ?? name)+" · "+row.freshness.label
            setAccessibilityLabel(name+", "+row.freshness.label)
        }
        needsLayout=true;needsDisplay=true;roomInk.needsDisplay=true
    }
    override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();effectiveAppearance.performAsCurrentDrawingAppearance{refreshChrome()}}
    var faceRect:CGRect {let box:CGFloat=34;return CGRect(x:list ? (row?.kind == .home ? 20:36):(bounds.width-box)/2,y:list ? (bounds.height-box)/2:10,width:box,height:box)}
    static func markSize(_ name:String)->CGSize {NSImage(systemSymbolName:name,accessibilityDescription:nil)!.withSymbolConfiguration(.init(pointSize:8,weight:.regular))!.size}
    override func layout(){super.layout();guard let row else{return};let header=row.kind == .section || row.kind == .stack,box=faceRect
        freshnessMark.frame=CGRect(x:bounds.width-17,y:2,width:14,height:16)
        CATransaction.begin();CATransaction.setDisableActions(true)
        roomInk.frame=bounds;roomInk.needsDisplay=true
        selection.frame=list ? CGRect(x:row.kind == .home ? 10:26,y:3,width:max(0,bounds.width-(row.kind == .home ? 20:36)),height:max(0,bounds.height-6)):bounds.insetBy(dx:8,dy:3)
        let point:CGFloat=list ? 16:13,font=NSFont.systemFont(ofSize:point,weight:.bold),size=(name as NSString).size(withAttributes:[.font:font]),textX:CGFloat=list ? 26:7,available=max(0,bounds.width-textX-(list ? 14:7))
        heading.frame=CGRect(x:textX,y:(bounds.height-size.height)/2,width:available,height:size.height)
        let values=[unread,row.questions,row.alerts],active=values.indices.filter{values[$0]>0}
        for (n,i) in active.enumerated(){
            let height:CGFloat=list ? 15:11,width=height+(values[i]>9 ? 4:0),frame=CGRect(x:box.maxX-width+(list ? 6:5),y:box.minY-3+CGFloat(n)*(height+(list ? 2:1)),width:width,height:height)
            counters[i].frame=frame;counters[i].cornerRadius=height/2;numbers[i].frame=CGRect(x:0,y:0,width:width,height:height);marks[i].frame=frame
            let signalsHeight=CGFloat(active.count*4-2),titleStart=list ? textX:(bounds.width-min(size.width,available))/2
            dots[i].frame=CGRect(x:titleStart+min(size.width,available)+3,y:(bounds.height-signalsHeight)/2+CGFloat(n)*4,width:2,height:2);dots[i].cornerRadius=1
        }
        let nameFont=NSFont.systemFont(ofSize:14,weight:chosen || unread>0 ? .semibold:.medium),nameWidth=(name as NSString).size(withAttributes:[.font:nameFont]).width
        let roomForName=max(0,bounds.width-box.maxX-32-(pinned ? Self.markSize("pin.fill").width+12:0)-(muted ? Self.markSize("bell.slash.fill").width+12:0))
        let markX=list ? box.maxX+12+min(nameWidth,roomForName)+12:box.minX-8
        let pin=Self.markSize("pin.fill"),mute=Self.markSize("bell.slash.fill")
        marks[3].frame=CGRect(x:markX,y:list ? bounds.midY-pin.height/2:box.minY-4,width:pin.width,height:pin.height)
        marks[4].frame=CGRect(x:list ? markX+(pinned ? pin.width+12:0):box.minX-8,y:list ? bounds.midY-mute.height/2:box.maxY-mute.height+3,width:mute.width,height:mute.height)
        CATransaction.commit();if !header {heading.isHidden=true}
    }
    override func draw(_ dirtyRect:NSRect){guard let row else{return};let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        if row.kind == .divider {let inset:CGFloat=list ? 12:8;SidebarTone.primary(dark ? 0.14:0.11).setFill();CGRect(x:inset,y:bounds.midY,width:max(0,bounds.width-inset*2),height:1).fill();if dropTarget {NSColor.controlAccentColor.setFill();CGRect(x:inset,y:bounds.midY-1,width:max(0,bounds.width-inset*2),height:2).fill()};return}
        if row.kind == .section || row.kind == .stack {
            if dropTarget && row.kind == .section {NSColor.controlAccentColor.setStroke();let path=NSBezierPath(roundedRect:CGRect(x:12,y:4,width:max(0,bounds.width-16),height:bounds.height-8),xRadius:10,yRadius:10);path.lineWidth=2;path.stroke()};return
        }
    }
    fileprivate func drawRoomContents(){
        guard let row,row.kind == .home || row.kind == .room else{return}
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        FaceGroup.draw(faces,in:faceRect,picture:picture,direct:row.items.first?.kind == .direct,dark:dark)
        let paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingTail;paragraph.alignment=list ? .left:.center
        let weight:NSFont.Weight=chosen || (list && unread>0) ? .semibold:.medium
        var font=NSFont.systemFont(ofSize:list ? 14:10,weight:weight)
        if !list {let measured=(name as NSString).size(withAttributes:[.font:font]).width;if measured>54 {font=NSFont.systemFont(ofSize:max(8.5,10*54/measured),weight:weight)}}
        let box=faceRect,area=list ? CGRect(x:box.maxX+12,y:bounds.midY-9,width:max(0,bounds.width-box.maxX-32-(pinned ? Self.markSize("pin.fill").width+12:0)-(muted ? Self.markSize("bell.slash.fill").width+12:0)),height:20):CGRect(x:(bounds.width-54)/2,y:49,width:54,height:15)
        (name as NSString).draw(in:area,withAttributes:[.font:font,.foregroundColor:SidebarTone.primary(list || chosen || unread>0 ? 1:0.7),.paragraphStyle:paragraph])
        for (i,symbol) in [(3,"pin.fill"),(4,"bell.slash.fill")] where !marks[i].isHidden {
            let rect=marks[i].frame;NSGraphicsContext.saveGraphicsState()
            if i==3 {let transform=NSAffineTransform();transform.translateX(by:rect.midX,yBy:rect.midY);transform.rotate(byDegrees:45);transform.translateX(by:-rect.midX,yBy:-rect.midY);transform.concat()}
            FileTile.symbol(symbol,point:8,at:CGPoint(x:rect.midX,y:rect.midY),color:SidebarTone.primary(0.7));NSGraphicsContext.restoreGraphicsState()
        }
    }
}
enum FaceGroup {
    static func draw(_ faces:[(String,ProfileAvatar)],in rect:CGRect,picture:NSImage?=nil,direct:Bool=false,dark:Bool=false){
        func box(_ size:CGFloat,_ dx:CGFloat=0,_ dy:CGFloat=0)->CGRect{CGRect(x:rect.midX-size/2+dx,y:rect.midY-size/2+dy,width:size,height:size)}
        if let picture {ProfileAvatar(image:picture).draw(in:box(30),name:"");return}
        switch faces.count {
        case 0:
            let area=box(30);SidebarTone.primary(0.1).setFill();NSBezierPath(roundedRect:area,xRadius:30*ChatMetrics.avatarCorner,yRadius:30*ChatMetrics.avatarCorner).fill()
            let text=direct ? "@":"#",attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:16,weight:.medium),.foregroundColor:SidebarTone.primary(0.7)],size=(text as NSString).size(withAttributes:attrs)
            (text as NSString).draw(at:CGPoint(x:area.midX-size.width/2,y:area.midY-size.height/2),withAttributes:attrs)
        case 1:faces[0].1.draw(in:box(30),name:faces[0].0)
        case 2:
            faces[0].1.draw(in:box(21,-6,-5),name:faces[0].0);let second=box(21,6,5);faces[1].1.draw(in:second,name:faces[1].0)
            (dark ? NSColor.black.withAlphaComponent(0.6):.white).setStroke();let border=NSBezierPath(roundedRect:second,xRadius:21*ChatMetrics.avatarCorner,yRadius:21*ChatMetrics.avatarCorner);border.lineWidth=1.5;border.stroke()
        default:
            let slots=faces.count==3 ? [box(16,0,-8.5),box(16,-9,8.5),box(16,9,8.5)]:[box(16,-9,-9),box(16,9,-9),box(16,-9,9),box(16,9,9)]
            for (i,slot) in slots.enumerated(){if faces.count>4 && i==3 {
                SidebarTone.primary(0.14).setFill();NSBezierPath(roundedRect:slot,xRadius:16*ChatMetrics.avatarCorner,yRadius:16*ChatMetrics.avatarCorner).fill()
                let text="+\(faces.count-3)",attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:8,weight:.semibold),.foregroundColor:SidebarTone.primary(0.8)],size=(text as NSString).size(withAttributes:attrs);(text as NSString).draw(at:CGPoint(x:slot.midX-size.width/2,y:slot.midY-size.height/2),withAttributes:attrs)
            }else{faces[i].1.draw(in:slot,name:faces[i].0)}}
        }
    }
}
final class ComposerFaceImage:NSView {
    var avatar=ProfileAvatar(),name=""
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    override func draw(_ rect:NSRect){avatar.draw(in:bounds,name:name)}
}
final class ComposerFaceRing:NSView {
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    override func draw(_ rect:NSRect){NSColor.controlAccentColor.setStroke();let path=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:30*ChatMetrics.avatarCorner,yRadius:30*ChatMetrics.avatarCorner);path.lineWidth=2;path.stroke()}
}
final class ComposerFaceButton:NSButton {
    var avatar=ProfileAvatar(),name="",homeStyle=false,lit=false,ring=false
    var invoke:(()->Void)?,makeMenu:(()->NSMenu?)?
    var reduceMotion:()->Bool = {NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    let imageView=ComposerFaceImage(),ringView=ComposerFaceRing()
    override var isFlipped:Bool {true}
    init(){super.init(frame:.zero);isBordered=false;target=self;action=#selector(pressed);addSubview(imageView);addSubview(ringView);imageView.wantsLayer=true;ringView.wantsLayer=true;ringView.alphaValue=0}
    required init?(coder:NSCoder){fatalError()}
    @objc private func pressed(){invoke?()}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
    override func menu(for event:NSEvent)->NSMenu? {makeMenu?()}
    func updateAppearance(){
        imageView.avatar=avatar;imageView.name=name;imageView.needsDisplay=true;ringView.needsDisplay=true
        let face:CGFloat=homeStyle && !lit ? 0.5:1,outline:CGFloat=homeStyle && lit && ring ? 1:0
        guard imageView.alphaValue != face || ringView.alphaValue != outline else{return}
        if reduceMotion(){imageView.alphaValue=face;ringView.alphaValue=outline}
        else {NSAnimationContext.runAnimationGroup {context in context.duration=0.24;context.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut);imageView.animator().alphaValue=face;ringView.animator().alphaValue=outline}}
    }
    override func layout(){super.layout();imageView.frame=CGRect(x:4,y:4,width:24,height:24);ringView.frame=CGRect(x:0,y:0,width:32,height:32)}
    override func draw(_ rect:NSRect){}
}
final class ComposerFaces:NSView {
    var reduceMotion:()->Bool = {NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    var makeMenu:((Int)->NSMenu?)? {didSet{refresh()}}
    var faces:[(String,ProfileAvatar)]=[] {didSet{refresh()}}
    var homeStyle=false {didSet{refresh()}}
    var ring=false {didSet{refresh()}}
    var lit:Int? {didSet{refresh()}}
    var explicitlyPicked=false {didSet{refresh()}}
    var onPick:((Int)->Void)? {didSet{refresh()}}
    private(set) var buttons:[ComposerFaceButton]=[]
    override var isFlipped:Bool {true}
    private func refresh(){
        while buttons.count>faces.count {buttons.removeLast().removeFromSuperview()}
        while buttons.count<faces.count {let button=ComposerFaceButton();buttons.append(button);addSubview(button)}
        for (i,face) in faces.enumerated(){let button=buttons[i];button.name=face.0;button.avatar=face.1;button.homeStyle=homeStyle;button.lit=lit==i;button.ring=ring;button.reduceMotion=reduceMotion
            button.toolTip=homeStyle ? (lit==i && explicitlyPicked ? "다시 누르면 글 내용에 따라 받는 캐릭터를 정해요":face.0+"에게 새 글"):"@"+face.0
            button.setAccessibilityLabel(homeStyle ? face.0+(lit==i ? ", 받는 캐릭터":"에게 새 글"):face.0+" 멘션")
            button.invoke={ [weak self] in self?.onPick?(i) };button.makeMenu={ [weak self] in self?.makeMenu?(i) };button.updateAppearance();button.needsDisplay=true
        };needsLayout=true
    }
    override func layout(){super.layout();for (i,button) in buttons.enumerated(){button.frame=CGRect(x:CGFloat(i)*34,y:0,width:32,height:32)}}
}
final class SidebarHandle: NSView {
    var onWidth: ((CGFloat) -> Void)?, onEnd: (() -> Void)?
    var width: () -> CGFloat = { ConversationSidebar.width }
    private var start: (point: CGFloat,width: CGFloat)?
    override func resetCursorRects() { addCursorRect(bounds,cursor:.resizeLeftRight) }
    override func mouseDown(with event:NSEvent) { start=(NSEvent.mouseLocation.x,width()) }
    override func mouseDragged(with event:NSEvent) { if let start { onWidth?(start.width+NSEvent.mouseLocation.x-start.point) } }
    override func mouseUp(with event:NSEvent) { start=nil; onEnd?() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
/// Noninteractive header areas own movement; buttons and text keep their events.
final class ConversationHeaderDrag: NSView {
    var excluded:((CGPoint)->Bool)?
    var onMenu: (() -> NSMenu?)?
    var menuHelp:String? {didSet{setAccessibilityHelp(menuHelp)}}
    override func menu(for event: NSEvent) -> NSMenu? { onMenu?() }
    override func hitTest(_ point:NSPoint)->NSView? { if excluded?(point) == true { return nil };return super.hitTest(point) }
    var onBegan: ((CGPoint) -> Void)?, onChanged: ((CGPoint) -> Void)?, onEnded: (() -> Void)?, onDoubleClick: (() -> Void)?
    private var start: CGPoint?, dragging=false
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:.openHand) }
    override func mouseDown(with event:NSEvent) { start=window?.convertPoint(toScreen:event.locationInWindow); dragging=false }
    override func mouseDragged(with event:NSEvent) {
        guard let start,let point=window?.convertPoint(toScreen:event.locationInWindow) else { return }
        if !dragging { guard hypot(point.x-start.x,point.y-start.y)>4 else { return }; dragging=true; onBegan?(start) }
        onChanged?(point)
    }
    override func mouseUp(with event:NSEvent) { if dragging { onEnded?() } else if event.clickCount == 2 { onDoubleClick?() }; start=nil; dragging=false }
    override func viewWillMove(toWindow newWindow:NSWindow?) { if newWindow == nil { if dragging { onEnded?() }; start=nil; dragging=false }; super.viewWillMove(toWindow:newWindow) }
}
final class FileChip: NSButton {
    var invoke: (() -> Void)?
    /// ReplyActionLabel's native equivalent; other chips retain their usual AppKit bezel.
    var nativeLabelGap:CGFloat?
    var replyWord:String? {didSet{invalidateIntrinsicContentSize();needsDisplay=true}}
    override var intrinsicContentSize:NSSize {
        guard let word=replyWord else{return super.intrinsicContentSize}
        return NSSize(width:ReplyButtonPolicy.symbol(word) != nil ? 36:max(36,(word as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.semibold)]).width+20),height:30)
    }
    private func colorAlpha(_ opacity:CGFloat)->CGFloat {SidebarTone.primary(1).alphaComponent*opacity}
    override func draw(_ dirtyRect:NSRect) {
        if let gap=nativeLabelGap,let image,imagePosition == .imageLeading {
            let attributes:[NSAttributedString.Key:Any]=[.font:font ?? NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:SidebarTone.primary(0.7)]
            FileTile.symbol("plus.circle",point:12,at:CGPoint(x:image.size.width/2,y:bounds.midY),color:SidebarTone.primary(0.7),weight:.medium)
            let size=(title as NSString).size(withAttributes:attributes);(title as NSString).draw(at:CGPoint(x:image.size.width+gap,y:bounds.midY-size.height/2),withAttributes:attributes);return
        }
        guard let word=replyWord else{super.draw(dirtyRect);return}
        let color=SidebarTone.primary(1),alpha:CGFloat=colorAlpha(isEnabled ? 1:0.4)
        let box=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:8,yRadius:8)
        color.withAlphaComponent(0.07*alpha).setFill();box.fill();color.withAlphaComponent(0.18*alpha).setStroke();box.lineWidth=1;box.stroke()
        if !ReplyButtonPolicy.standard.contains(word),let symbol=ReplyButtonPolicy.symbol(word) {
            FileTile.symbol(symbol,point:14,at:CGPoint(x:bounds.midX,y:bounds.midY),color:color.withAlphaComponent(alpha))
        } else {
            let attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:color.withAlphaComponent(alpha)]
            let size=(word as NSString).size(withAttributes:attributes)
            (word as NSString).draw(at:CGPoint(x:bounds.midX-size.width/2,y:bounds.midY-size.height/2),withAttributes:attributes)
        }
    }
    init(title:String) { super.init(frame:.zero); self.title=title; bezelStyle = .rounded; target=self; action = #selector(pressed); setContentCompressionResistancePriority(.defaultLow,for:.horizontal) }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func pressed() { invoke?() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
final class PassiveLabel: NSTextField { override func hitTest(_ point:NSPoint) -> NSView? { nil } }
/// SwiftUI's capsule/circle controls translated into native drawing, including its hit area.
/// Shared track and segment geometry for composer modes and drawer filters.
final class ComposerModeTrack: NSView {
    static let inset:CGFloat=2, point:CGFloat=11
    static var height:CGFloat { ("답글" as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:point)]).height+6+2*inset }
    static func segment(in track:CGRect,offset:CGFloat,width:CGFloat)->CGRect {
        CGRect(x:track.minX+inset+offset,y:track.minY+inset,width:width,height:track.height-2*inset)
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect:bounds,xRadius:bounds.height/2,yRadius:bounds.height/2).fill()
    }
}

final class ComposerButton: NSButton {
    var invoke:(() -> Void)?, chosen=false,mode=false
    var textAlpha:CGFloat=1
    var selection:CGFloat?
    var symbol:String?, point:CGFloat=11, circle=false
    init(title:String="",symbol:String?=nil,point:CGFloat=11,circle:Bool=false) {
        self.symbol=symbol; self.point=point; self.circle=circle
        super.init(frame:.zero); self.title=title; isBordered=false; target=self; action = #selector(pressed)
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func pressed() { invoke?() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        let amount=selection ?? (chosen ? 1:0)
        let fill: NSColor = mode ? NSColor.controlAccentColor.withAlphaComponent(amount) : chosen ? (mode ? .controlAccentColor:.systemBlue) : circle ? NSColor.labelColor.withAlphaComponent(0.07) : .clear
        fill.withAlphaComponent(chosen && !isEnabled && !mode ? 0.4 : fill.alphaComponent).setFill()
        NSBezierPath(roundedRect:bounds,xRadius:bounds.height/2,yRadius:bounds.height/2).fill()
        let ordinary:NSColor=mode && isEnabled ? .labelColor:.labelColor.withAlphaComponent(isEnabled ? 0.7:0.42)
        let color:NSColor=mode ? ordinary.blended(withFraction:amount,of:.white) ?? .white:chosen ? .white:ordinary
        if let symbol,let image=NSImage(systemSymbolName:symbol,accessibilityDescription:title)?.withSymbolConfiguration(.init(pointSize:point,weight:chosen ? .bold : .regular)) {
            let tinted=image.copy() as! NSImage; tinted.lockFocus(); color.set(); CGRect(origin:.zero,size:image.size).fill(using:.sourceAtop); tinted.unlockFocus()
            tinted.draw(in:CGRect(x:(bounds.width-image.size.width)/2,y:(bounds.height-image.size.height)/2,width:image.size.width,height:image.size.height))
        } else {
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:point,weight:chosen ? .semibold : .regular),.foregroundColor:color.withAlphaComponent(color.alphaComponent*textAlpha)]
            let size=(title as NSString).size(withAttributes:attrs)
            (title as NSString).draw(at:CGPoint(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2),withAttributes:attrs)
        }
    }
}
final class FileTile: NSButton {
    override var isFlipped:Bool{false}
    let file:MessageFile
    var invoke:(()->Void)?,picture:NSImage?,failed=false,busy=false
    private let spinner=NSProgressIndicator()
    var imageFile:Bool {file.mime.hasPrefix("image/")}
    var pdf:Bool {file.mime=="application/pdf" || file.name.lowercased().hasSuffix(".pdf")}
    static func imageSize(_ picture:NSImage?)->CGSize {
        guard let picture,picture.size.width>0,picture.size.height>0 else{return CGSize(width:160,height:110)}
        let scale=min(220/picture.size.width,180/picture.size.height)
        return CGSize(width:picture.size.width*scale,height:picture.size.height*scale)
    }
    /// Two source text lines, spacing 1, vertical padding 7. Measured native counterpart.
    static let documentHeight:CGFloat=43
    static func frameSize(_ picture:NSImage?)->CGSize {guard let picture else{return CGSize(width:160,height:110)};return CGSize(width:220,height:imageSize(picture).height)}
    var tileSize:CGSize {imageFile ? Self.frameSize(picture):CGSize(width:240,height:Self.documentHeight)}
    var detail:String {[CardText.sizeText(file.size),pdf ? "PDF":""].filter{!$0.isEmpty}.joined(separator:" · ")}
    init(file:MessageFile) {
        self.file=file;super.init(frame:.zero);isBordered=false;target=self;action=#selector(openFile)
        setAccessibilityLabel(file.name+" 저장하고 열기");toolTip="눌러서 저장하고 열기"
        spinner.style = .spinning;spinner.controlSize = .small;spinner.isDisplayedWhenStopped=false;addSubview(spinner)
    }
    required init?(coder:NSCoder){fatalError()}
    @objc private func openFile(){invoke?()}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func resetCursorRects(){addCursorRect(bounds,cursor:.pointingHand)}
    override func layout(){super.layout();spinner.frame=CGRect(x:imageFile ? bounds.midX-8:bounds.maxX-26,y:bounds.midY-8,width:16,height:16);if busy {spinner.startAnimation(nil)}else{spinner.stopAnimation(nil)}}
    override func draw(_ rect:NSRect){
        let area=CGRect(origin:.zero,size:CGSize(width:min(bounds.width,tileSize.width),height:bounds.height))
        NSGraphicsContext.saveGraphicsState();NSBezierPath(roundedRect:area,xRadius:10,yRadius:10).addClip()
        if imageFile,let picture {
            let scale=min(area.width/picture.size.width,area.height/picture.size.height),size=CGSize(width:picture.size.width*scale,height:picture.size.height*scale)
            picture.draw(in:CGRect(x:area.midX-size.width/2,y:area.midY-size.height/2,width:size.width,height:size.height),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        }
        else {
            NSColor.black.withAlphaComponent(0.18).setFill();area.fill()
            if imageFile {
                if failed {
                    let a:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor],text="사진을 불러오지 못했어요" as NSString,size=text.size(withAttributes:a)
                    text.draw(at:CGPoint(x:area.midX-size.width/2,y:area.midY-size.height/2),withAttributes:a)
                } else {Self.symbol("photo",point:20,at:CGPoint(x:area.midX,y:area.midY),color:SidebarTone.primary(0.7))}
            } else {
                Self.symbol(pdf ? "doc.richtext.fill":"doc.fill",point:18,at:CGPoint(x:20,y:area.midY),color:.labelColor)
                let paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingMiddle
                (file.name as NSString).draw(in:CGRect(x:38,y:area.midY,width:max(1,area.width-76),height:16),withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.labelColor,.paragraphStyle:paragraph])
                ((failed ? "사진을 불러오지 못했어요":detail) as NSString).draw(in:CGRect(x:38,y:area.midY-13,width:max(1,area.width-76),height:14),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:SidebarTone.primary(0.75)])
                if !busy {Self.symbol("arrow.down.circle",point:14,at:CGPoint(x:area.maxX-17,y:area.midY),color:SidebarTone.primary(0.8))}
            }
        };NSGraphicsContext.restoreGraphicsState()
    }
    static func symbol(_ name:String,point:CGFloat,at center:CGPoint,color:NSColor,weight:NSFont.Weight = .regular){
        guard let image=NSImage(systemSymbolName:name,accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:point,weight:weight)) else{return}
        let tinted=image.copy() as! NSImage;tinted.lockFocus();color.setFill();CGRect(origin:.zero,size:image.size).fill(using:.sourceIn);tinted.unlockFocus()
        tinted.draw(in:CGRect(x:center.x-image.size.width/2,y:center.y-image.size.height/2,width:image.size.width,height:image.size.height),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
    }
}

/// Native equivalent of the file capsule; only the trailing x removes it.
final class AttachmentChip:NSView {
    let remove=FileChip(title:""),name:String
    init(name:String,remove action:@escaping()->Void){self.name=name;super.init(frame:.zero);addSubview(remove)
        remove.isBordered=false;remove.image=NSImage(systemSymbolName:"xmark.circle.fill",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:11,weight:.regular));remove.contentTintColor=SidebarTone.primary(0.7);remove.setAccessibilityLabel(name+" 빼기");remove.invoke=action
    }
    required init?(coder:NSCoder){fatalError()}
    override var intrinsicContentSize:CGSize{CGSize(width:min(150,(name as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:11)]).width)+16+12+4+4+14,height:25)}
    override func layout(){super.layout();remove.frame=CGRect(x:bounds.width-23,y:3,width:15,height:19)}
    override func draw(_ rect:NSRect){
        SidebarTone.primary(0.1).setFill();NSBezierPath(roundedRect:bounds,xRadius:bounds.height/2,yRadius:bounds.height/2).fill()
        FileTile.symbol("paperclip",point:10,at:CGPoint(x:14,y:bounds.midY),color:.labelColor)
        let p=NSMutableParagraphStyle();p.lineBreakMode = .byTruncatingMiddle
        (name as NSString).draw(in:CGRect(x:24,y:bounds.midY-7,width:bounds.width-50,height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor,.paragraphStyle:p])
    }
    override func mouseDown(with event:NSEvent){}
}

/// Captures gaps and disabled controls, so they never bubble into the card's fold action.
final class ThreadControls:NSView {
    override var isFlipped:Bool{true}
    override func mouseDown(with event:NSEvent){}
}

final class MessageAccessory: NSView {
    let content: NSView
    let mine: Bool
    let limit: CGFloat
    let top:CGFloat
    override var isFlipped: Bool { true }
    init(_ content: NSView, mine: Bool = false, limit: CGFloat = 240, top:CGFloat=0) { self.content=content; self.mine=mine; self.limit=limit;self.top=top; super.init(frame:.zero); addSubview(content) }
    required init?(coder:NSCoder) { fatalError() }
    override func mouseDown(with event:NSEvent){}
    override func layout() {
        super.layout()
        let lead:CGFloat=mine ? 0 : 43, width=min(limit,max(1,bounds.width-lead))
        content.frame=CGRect(x:mine ? bounds.width-width : lead,y:top,width:width,height:max(0,bounds.height-top))
    }
}

/// The add menu occupies a real table row, so it participates in scrolling and row motion.
final class SidebarAddRow:NSView {
    let button:FileChip
    var list=false {didSet{needsLayout=true}}
    override var isFlipped:Bool {true}
    init(button:FileChip){self.button=button;super.init(frame:.zero);addSubview(button)}
    required init?(coder:NSCoder){nil}
    override func layout(){super.layout();let inset:CGFloat=list ? 16:0;button.frame=CGRect(x:inset,y:0,width:max(0,bounds.width-inset),height:40)}
}
