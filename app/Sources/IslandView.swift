import AppKit

/// Single-row AppKit status pill. It owns hit testing, never window dragging or reply buttons.
@MainActor final class IslandView: NSView {
    private(set) var snapshot = IslandModel.Snapshot()
    var onAction: ((IslandModel.Action) -> Void)?
    var onWidthChange: (() -> Void)?
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private(set) var hoveredOwner = false
    private(set) var workerFacesOnly = false
    private(set) var animationSteps = 0
    private(set) var partRects: [(IslandModel.Part, CGRect)] = []
    private var tracking: NSTrackingArea?, timer: Timer?
    private let shimmerContainer = CALayer(), shimmerGradient = CAGradientLayer(), shimmerMask = CATextLayer()
    var animationTime: () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    private(set) var shimmerPosition: CGFloat = 0
    private var widthTarget: CGFloat = 44, widthFrom: CGFloat = 44, widthStart: TimeInterval = 0
    private var displayedWidth: CGFloat = 44, hasWidth = false
    var isShimmering: Bool {
        !reduceMotion() && !workerFacesOnly && snapshot.parts.contains { $0.kind == .worker && $0.shimmering && !$0.iconOnly }
    }
    var idleStripe: CGRect { CGRect(x:0,y:(bounds.height-12)/2,width:min(44,bounds.width),height:12) }
    override var isFlipped: Bool { true }
    override init(frame:NSRect) {
        super.init(frame:frame); wantsLayer = true
        setAccessibilityElement(true); setAccessibilityRole(.group)
        shimmerGradient.colors = [NSColor.white.withAlphaComponent(0).cgColor,NSColor.white.withAlphaComponent(0.95).cgColor,NSColor.white.withAlphaComponent(0).cgColor]
        shimmerGradient.startPoint=CGPoint(x:0,y:0.5);shimmerGradient.endPoint=CGPoint(x:1,y:0.5)
        shimmerGradient.bounds=CGRect(x:0,y:0,width:60,height:16)
        shimmerContainer.addSublayer(shimmerGradient)
        shimmerContainer.mask=shimmerMask;layer?.addSublayer(shimmerContainer)
        timer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true) { [weak self] _ in
            Task { @MainActor in guard let self else { return }
                if self.widthIsAnimating { self.onWidthChange?() }
                self.updateShimmerPosition()
            }
        }
    }
    required init?(coder:NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    private var widthIsAnimating:Bool { !reduceMotion() && abs(displayedWidth-widthTarget)>0.1 }
    func show(_ value:IslandModel.Snapshot) {
        snapshot=value
        if !value.parts.contains(where:{$0.kind == .owner}) { hoveredOwner=false }
        setAccessibilityLabel(value.idle ? "새 알림 없음" : value.parts.map { text($0) }.joined(separator:" · "))
        needsLayout=true; needsDisplay=true; onWidthChange?()
    }
    private func text(_ part:IslandModel.Part)->String {
        if part.kind == .owner && hoveredOwner,let text=snapshot.hoverQuestion { return text }
        return part.text
    }
    private func iconWidth(_ part:IslandModel.Part)->CGFloat { (part.redDot ? 9 : 0)+CGFloat(part.faces.count)*18 }
    private func desired(_ part:IslandModel.Part,compact:Bool)->CGFloat {
        let icon=iconWidth(part)
        if compact || part.iconOnly { return max(26,icon+12) }
        return 16+icon+min(340,(text(part) as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium)]).width)
    }
    private func widths(limit:CGFloat)->[CGFloat] {
        let limit=max(0,limit)
        var values=snapshot.parts.map { desired($0,compact:false) }; workerFacesOnly=false
        let gaps=CGFloat(max(0,values.count-1))
        if values.reduce(0,+)+gaps>limit, let i=snapshot.parts.firstIndex(where:{$0.kind == .worker}) {
            values[i]=desired(snapshot.parts[i],compact:true);workerFacesOnly=true
        }
        let available=max(0,limit-gaps), total=values.reduce(0,+)
        if total>available && total>0 { values=values.map{$0*available/total} }
        return values
    }
    func fittedWidth(limit:CGFloat)->CGFloat {
        let full=snapshot.parts.reduce(CGFloat(0)) { $0+desired($1,compact:false) }+CGFloat(max(0,snapshot.parts.count-1))
        let target=min(max(0,limit),snapshot.idle ? 44 : full)
        let now=ProcessInfo.processInfo.systemUptime
        if !hasWidth || reduceMotion() { displayedWidth=target;widthTarget=target;widthFrom=target;hasWidth=true;animationSteps=0 }
        else {
            if target != widthTarget { widthFrom=displayedWidth;widthStart=now;widthTarget=target }
            let t=min(1,max(0,(now-widthStart)/0.18)), next=widthFrom+(widthTarget-widthFrom)*CGFloat(1-pow(1-t,3))
            if abs(next-displayedWidth)>0.01 { animationSteps += 1 }; displayedWidth=min(limit,next)
        }
        return max(0,displayedWidth)
    }
    override func layout() {
        super.layout();let values=widths(limit:bounds.width);var x:CGFloat=0;partRects=[]
        for (index,part) in snapshot.parts.enumerated() { partRects.append((part,CGRect(x:x,y:0,width:values[index],height:30)));x+=values[index]+1 }
        if let (part,rect)=partRects.first(where:{$0.0.kind == .worker && $0.0.shimmering && !$0.0.iconOnly}),!workerFacesOnly {
            let textX=rect.minX+7+CGFloat(part.faces.count)*18
            let width=max(0,rect.maxX-textX-7)
            CATransaction.begin();CATransaction.setDisableActions(true)
            shimmerContainer.frame=CGRect(x:textX,y:8,width:width,height:16)
            shimmerMask.frame=CGRect(origin:.zero,size:shimmerContainer.bounds.size)
            shimmerMask.contentsScale=window?.backingScaleFactor ?? 2
            shimmerMask.alignmentMode = .left; shimmerMask.truncationMode = .end
            let workingText=part.text.hasPrefix("일하는 중 · ") ? "일하는 중" : text(part)
            shimmerMask.string=NSAttributedString(string:workingText,attributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor.white])
            CATransaction.commit()
        } else { shimmerContainer.isHidden=true }
        updateShimmerPosition()
    }
    func updateShimmerPosition() {
        let running=isShimmering && shimmerContainer.bounds.width>0
        shimmerContainer.isHidden = !running
        guard running else { return }
        let cycle=animationTime().truncatingRemainder(dividingBy:1.6)/1.6
        let x = -30 + (shimmerContainer.bounds.width+60)*CGFloat(cycle)
        CATransaction.begin();CATransaction.setDisableActions(true)
        shimmerGradient.position=CGPoint(x:x,y:8)
        CATransaction.commit()
        shimmerPosition=x
    }
    override func draw(_ dirtyRect:NSRect) {
        if snapshot.idle { NSColor.labelColor.withAlphaComponent(0.09).setFill();NSBezierPath(roundedRect:idleStripe,xRadius:6,yRadius:6).fill();return }
        let path=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:15,yRadius:15)
        NSColor.labelColor.withAlphaComponent(0.055).setFill();path.fill()
        (snapshot.disconnected ? NSColor.systemOrange : NSColor.labelColor.withAlphaComponent(0.13)).setStroke();path.lineWidth=1;path.stroke()
        NSGraphicsContext.saveGraphicsState();path.addClip();defer { NSGraphicsContext.restoreGraphicsState() }
        for (index,item) in partRects.enumerated() {
            let (part,rect)=item;var x=rect.minX+7
            if index>0 { NSColor.labelColor.withAlphaComponent(0.17).setFill();CGRect(x:rect.minX-1,y:8,width:1,height:14).fill() }
            NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:rect.insetBy(dx:2,dy:1)).addClip()
            if part.redDot || snapshot.restored {
                (snapshot.restored ? NSColor.systemGreen : .systemRed).setFill();NSBezierPath(ovalIn:CGRect(x:x,y:12,width:5,height:5)).fill();x+=9
            }
            for name in part.faces { ProfileAvatar(color:.systemBlue).draw(in:CGRect(x:x,y:7,width:16,height:16),name:name);x+=18 }
            let compact=part.iconOnly || (part.kind == .worker && workerFacesOnly)
            if !compact {
                let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
                let color=part.kind == .worker && part.shimmering ? NSColor.labelColor.withAlphaComponent(0.45) : snapshot.disconnected ? NSColor.systemOrange : NSColor.labelColor.withAlphaComponent(part.kind == .owner && !part.redDot ? 0.6 : 0.9)
                (text(part) as NSString).draw(in:CGRect(x:x,y:8,width:max(0,rect.maxX-x-7),height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:color,.paragraphStyle:style])
            } else if part.faces.isEmpty && !part.redDot {
                NSColor.secondaryLabelColor.setFill();NSBezierPath(ovalIn:CGRect(x:rect.midX-2,y:13,width:4,height:4)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas();if let tracking { removeTrackingArea(tracking) }
        let area=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(area);tracking=area
    }
    func hover(at point:CGPoint?) {
        let next=point.map { p in partRects.contains { $0.0.kind == .owner && $0.1.contains(p) } } ?? false
        if next != hoveredOwner { hoveredOwner=next;setAccessibilityLabel(snapshot.parts.map { text($0) }.joined(separator:" · "));onWidthChange?();needsDisplay=true }
    }
    override func mouseMoved(with event:NSEvent) { hover(at:convert(event.locationInWindow,from:nil)) }
    override func mouseEntered(with event:NSEvent) { mouseMoved(with:event) }
    override func mouseExited(with event:NSEvent) { hover(at:nil) }
    func activate(at point:CGPoint) {
        guard let (part,rect)=partRects.first(where:{$0.1.contains(point)}) else { return }
        let facesX=rect.minX+7+(part.redDot ? 9 : 0)
        let index=Int(floor((point.x-facesX)/18))
        if point.y>=7 && point.y<=23 && index>=0 && index<part.faceActions.count { onAction?(part.faceActions[index]) }
        else if let action=part.action { onAction?(action) }
    }
    override func mouseDown(with event:NSEvent) { activate(at:convert(event.locationInWindow,from:nil)) }
    override func mouseDragged(with event:NSEvent) {} // The island consumes drags, including its empty stripe.
    override func acceptsFirstMouse(for event:NSEvent?)->Bool { true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:snapshot.parts.contains(where:{$0.action != nil}) ? .pointingHand : .arrow) }
}
