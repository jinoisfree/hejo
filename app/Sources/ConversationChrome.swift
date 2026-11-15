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
final class EmployeeSidebarCell: NSTableCellView {
    var name = "", unread = 0, chosen = false, list = false, muted = false
    var faces:[(String,ProfileAvatar)] = []
    var row:SidebarLayout.Row?
    var pinned=false,dropTarget=false
    var picture:NSImage?
    var nameColor:NSColor = .labelColor
    var railLast=false
    override func menu(for event: NSEvent) -> NSMenu? { (enclosingScrollView?.documentView as? EmployeeMenuTable)?.menu(for: event) }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        if let row,row.kind == .divider {
            NSColor.labelColor.withAlphaComponent(0.14).setFill();CGRect(x:list ? 12 : 8,y:bounds.midY,width:bounds.width-(list ? 24 : 16),height:1).fill();return
        }
        if let row,row.kind == .section || row.kind == .stack || row.kind == .room {
            let header=row.kind == .section || row.kind == .stack
            let start:CGFloat=header ? bounds.height/2-9 : 0
            let height:CGFloat=header && (!row.open || row.items.isEmpty) ? 18 : bounds.height-start-(railLast ? 10 : 0)
            NSColor.labelColor.withAlphaComponent(0.13).setFill();CGRect(x:0,y:start,width:2,height:max(0,height)).fill()
        }
        if dropTarget { NSColor.systemBlue.setStroke();let path=NSBezierPath(rect:bounds.insetBy(dx:1,dy:1));path.lineWidth=2;path.stroke() }
        if let row,row.kind == .section || row.kind == .stack {
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:list ? 16 : 13,weight:.bold),.foregroundColor:row.open ? NSColor.labelColor : NSColor.labelColor.withAlphaComponent(0.75)]
            let title=name
            let width=max(0,bounds.width-18-(list && !row.open ? CGFloat(min(4,faces.count))*14 : 0))
            let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail;style.alignment=list ? .left : .center
            var attributes=attrs;attributes[.paragraphStyle]=style
            let textX:CGFloat=list ? 26 : 7
            (title as NSString).draw(in:CGRect(x:textX,y:list ? 4 : 0,width:max(0,width-textX),height:21),withAttributes:attributes)
            if !row.open {
                let edge:CGFloat=list ? 16 : 13
                for (i,face) in faces.prefix(4).enumerated() { face.1.draw(in:CGRect(x:list ? bounds.width-8-CGFloat(faces.prefix(4).count-i)*14 : 8+CGFloat(i)*13,y:list ? 6 : 17,width:edge,height:edge),name:face.0) }
            }
            if let picture { picture.draw(in:CGRect(x:bounds.width-25,y:2,width:20,height:20),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil) }
            let colors:[String:NSColor]=["unread":list ? .systemBlue : .systemRed,"question":.systemYellow,"alert":.systemBlue]
            let dotsX=min(bounds.width-5,textX+(title as NSString).size(withAttributes:attrs).width+3),dotsHeight=CGFloat(max(0,row.signals.count*4-2))
            for (i,signal) in row.signals.enumerated() { colors[signal]?.setFill();NSBezierPath(ovalIn:CGRect(x:dotsX,y:(bounds.height-dotsHeight)/2+CGFloat(i)*4,width:2,height:2)).fill() }
            return
        }
        let dark = effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        if chosen {
            NSColor.controlAccentColor.withAlphaComponent(dark ? 0.22 : 0.12).setFill()
            let rect=list ? CGRect(x:26,y:3,width:max(0,bounds.width-36),height:bounds.height-6) : bounds.insetBy(dx:8,dy:3)
            NSBezierPath(roundedRect:rect,xRadius:10,yRadius:10).fill()
        }
        let box: CGFloat = ConversationSidebar.faces
        let face = CGRect(x:list ? 36 : (bounds.width-box)/2,y:list ? (bounds.height-box)/2 : 10,width:box,height:box)
        FaceGroup.draw(faces,in:face.insetBy(dx:2,dy:2),picture:picture)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail; paragraph.alignment = list ? .left : .center
        let area = list ? CGRect(x:face.maxX+12,y:bounds.midY-9,width:max(0,bounds.width-face.maxX-32),height:20) : CGRect(x:7,y:49,width:bounds.width-14,height:14)
        (name as NSString).draw(in:area,withAttributes:[.font:NSFont.systemFont(ofSize:list ? 14 : 10,weight:chosen || unread > 0 ? .semibold : .medium),.foregroundColor:nameColor.withAlphaComponent(chosen || unread > 0 ? 1 : 0.7),.paragraphStyle:paragraph])
        for (index,symbol) in [pinned ? "pin.fill" : nil,muted ? "bell.slash.fill" : nil].compactMap({$0}).enumerated() {
            let labelWidth=(name as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold)]).width
            let x=list ? min(bounds.width-18,area.minX+labelWidth+8)+CGFloat(index)*10 : face.minX-8
            let y=list ? bounds.midY-4 : face.minY-4+CGFloat(index)*12
            NSImage(systemSymbolName:symbol,accessibilityDescription:nil)?.withSymbolConfiguration(.init(paletteColors:[.secondaryLabelColor]))?.draw(in:CGRect(x:x,y:y,width:8,height:8))
        }
        let counters:[(Int,NSColor,NSColor)]=[(unread,muted ? .systemGray : list ? .systemBlue : .systemRed,.white),(row?.questions ?? 0,.systemYellow,.black),(row?.alerts ?? 0,.systemBlue,.white)]
        for (index,counter) in counters.filter({$0.0>0}).enumerated() {
            let (count,fill,text)=counter,value=SidebarLayout.badge(count),size:CGFloat=list ? 15 : 11
            let badge=CGRect(x:face.maxX-size+(list ? 6 : 5),y:face.minY-3+CGFloat(index)*(size+(list ? 2 : 1)),width:count>9 ? size+5 : size,height:size)
            fill.setFill(); let path=NSBezierPath(roundedRect:badge,xRadius:size/2,yRadius:size/2); path.fill()
            (dark ? NSColor(white:0.12,alpha:1) : .white).setStroke(); path.lineWidth=1; path.stroke()
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.boldSystemFont(ofSize:list ? 9 : 7),.foregroundColor:text]
            let measured=(value as NSString).size(withAttributes:attrs)
            (value as NSString).draw(at:CGPoint(x:badge.midX-measured.width/2,y:badge.midY-measured.height/2),withAttributes:attrs)
        }
    }
}
enum FaceGroup {
    static func draw(_ faces:[(String,ProfileAvatar)],in rect:CGRect,picture:NSImage?=nil) {
        if let picture { ProfileAvatar(image:picture).draw(in:rect,name:"");return }
        guard !faces.isEmpty else { return }
        if faces.count==1 { faces[0].1.draw(in:rect,name:faces[0].0);return }
        let unit=rect.width*(faces.count==2 ? 0.62 : 0.48)
        let points:[CGPoint] = faces.count==2 ? [CGPoint(x:0,y:0),CGPoint(x:rect.width-unit,y:rect.height-unit)] : faces.count==3 ? [CGPoint(x:(rect.width-unit)/2,y:0),CGPoint(x:0,y:rect.height-unit),CGPoint(x:rect.width-unit,y:rect.height-unit)] : [CGPoint.zero,CGPoint(x:rect.width-unit,y:0),CGPoint(x:0,y:rect.height-unit),CGPoint(x:rect.width-unit,y:rect.height-unit)]
        for (i,point) in points.enumerated() {
            let box=CGRect(x:rect.minX+point.x,y:rect.minY+point.y,width:unit,height:unit)
            if faces.count>4 && i==3 {
                NSColor.secondaryLabelColor.setFill();NSBezierPath(roundedRect:box,xRadius:3,yRadius:3).fill()
                (("+\(faces.count-3)") as NSString).draw(in:box,withAttributes:[.font:NSFont.systemFont(ofSize:unit*0.5),.foregroundColor:NSColor.white])
            } else { faces[i].1.draw(in:box,name:faces[i].0) }
        }
    }
}
final class ComposerFaces: NSView {
    var faces:[(String,ProfileAvatar)] = [] { didSet { needsDisplay=true } }
    override var isFlipped:Bool { true }
    override func hitTest(_ point:NSPoint)->NSView? { nil }
    override func draw(_ dirtyRect:NSRect) { for (i,face) in faces.enumerated() { face.1.draw(in:CGRect(x:CGFloat(i)*24,y:0,width:20,height:20),name:face.0) } }
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
    init(title:String) { super.init(frame:.zero); self.title=title; bezelStyle = .rounded; target=self; action = #selector(pressed); setContentCompressionResistancePriority(.defaultLow,for:.horizontal) }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func pressed() { invoke?() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
final class PassiveLabel: NSTextField { override func hitTest(_ point:NSPoint) -> NSView? { nil } }
/// SwiftUI's capsule/circle controls translated into native drawing, including its hit area.
final class ComposerButton: NSButton {
    var invoke:(() -> Void)?, chosen=false
    var symbol:String?, point:CGFloat=11, circle=false
    init(title:String="",symbol:String?=nil,point:CGFloat=11,circle:Bool=false) {
        self.symbol=symbol; self.point=point; self.circle=circle
        super.init(frame:.zero); self.title=title; isBordered=false; target=self; action = #selector(pressed)
    }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func pressed() { invoke?() }
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        let fill: NSColor = chosen ? .systemBlue : circle ? NSColor.labelColor.withAlphaComponent(0.07) : .clear
        fill.withAlphaComponent(chosen && !isEnabled ? 0.4 : fill.alphaComponent).setFill()
        NSBezierPath(roundedRect:bounds,xRadius:bounds.height/2,yRadius:bounds.height/2).fill()
        let color: NSColor = chosen ? .white : .labelColor.withAlphaComponent(isEnabled ? 0.7 : 0.42)
        if let symbol,let image=NSImage(systemSymbolName:symbol,accessibilityDescription:title)?.withSymbolConfiguration(.init(pointSize:point,weight:chosen ? .bold : .regular)) {
            let tinted=image.copy() as! NSImage; tinted.lockFocus(); color.set(); CGRect(origin:.zero,size:image.size).fill(using:.sourceAtop); tinted.unlockFocus()
            tinted.draw(in:CGRect(x:(bounds.width-image.size.width)/2,y:(bounds.height-image.size.height)/2,width:image.size.width,height:image.size.height))
        } else {
            let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:point,weight:chosen ? .semibold : .regular),.foregroundColor:color]
            let size=(title as NSString).size(withAttributes:attrs)
            (title as NSString).draw(at:CGPoint(x:(bounds.width-size.width)/2,y:(bounds.height-size.height)/2),withAttributes:attrs)
        }
    }
}
final class FileTile: NSButton {
    override var isFlipped: Bool { false }
    let file:MessageFile
    var invoke:(()->Void)?, picture:NSImage?
    init(file:MessageFile) { self.file=file; super.init(frame:.zero); isBordered=false; target=self; action = #selector(openFile); setAccessibilityLabel(file.name+" 저장하고 열기"); toolTip="눌러서 저장하고 열기" }
    required init?(coder:NSCoder) { fatalError() }
    @objc private func openFile() { invoke?() }
    override func acceptsFirstMouse(for event:NSEvent?)->Bool { true }
    override func draw(_ dirtyRect:NSRect) {
        let image=file.mime.hasPrefix("image/"), rect=CGRect(x:0,y:0,width:min(bounds.width,image ? 160 : 240),height:bounds.height)
        NSColor.black.withAlphaComponent(0.18).setFill(); NSBezierPath(roundedRect:rect,xRadius:10,yRadius:10).fill()
        if image,let picture { picture.draw(in:rect.insetBy(dx:3,dy:3),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil); return }
        let symbol=image ? "photo" : file.mime == "application/pdf" ? "doc.richtext.fill" : "doc.fill"
        NSImage(systemSymbolName:symbol,accessibilityDescription:nil)?.draw(in:CGRect(x:10,y:rect.midY-10,width:20,height:20))
        if !image {
            let style=NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingMiddle
            (file.name as NSString).draw(in:CGRect(x:38,y:rect.midY,width:max(1,rect.width-60),height:16),withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.labelColor,.paragraphStyle:style])
            (ByteCountFormatter.string(fromByteCount:Int64(file.size),countStyle:.file) as NSString).draw(in:CGRect(x:38,y:rect.midY-13,width:max(1,rect.width-60),height:14),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.labelColor.withAlphaComponent(0.75)])
        }
    }
}

final class MessageAccessory: NSView {
    let content: NSView
    let mine: Bool
    let limit: CGFloat
    override var isFlipped: Bool { true }
    init(_ content: NSView, mine: Bool = false, limit: CGFloat = 240) { self.content=content; self.mine=mine; self.limit=limit; super.init(frame:.zero); addSubview(content) }
    required init?(coder:NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        let lead:CGFloat=mine ? 0 : 43, width=min(limit,max(1,bounds.width-lead))
        content.frame=CGRect(x:mine ? bounds.width-width : lead,y:0,width:width,height:bounds.height)
    }
}
