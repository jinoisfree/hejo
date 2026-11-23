import AppKit

/// One title capsule and one activity. Actions remain owned by ConversationView.
@MainActor final class IslandView: NSView {
    private(set) var snapshot=IslandModel.Snapshot()
    var onAction:((IslandModel.Action)->Void)?
    var avatar:(String)->ProfileAvatar={ProfileAvatar(color:PictureCodec.color(name:$0,hex:nil))}
    var onWidthChange:(()->Void)?
    var reduceMotion:()->Bool={NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    private(set) var titleRect=CGRect.zero, titleTextRect=CGRect.zero, activityRect=CGRect.zero, activityTextRect=CGRect.zero
    private(set) var faceRects:[CGRect]=[]
    let dotLayer=CALayer(), dividerLayer=CALayer()
    private var hoveredActivity=false, tracking:NSTrackingArea?, timer:Timer?
    private let shimmer=ShimmerLayer()
    var animationTime:()->TimeInterval={ProcessInfo.processInfo.systemUptime}
    private(set) var shimmerPosition:CGFloat=0
    private(set) var animationSteps=0
    private var widthTarget:CGFloat=44, widthFrom:CGFloat=44, widthStart:TimeInterval=0, displayedWidth:CGFloat=44
    private var hasWidth=false
    private let font=NSFont.systemFont(ofSize:11,weight:.medium)
    override var isFlipped:Bool{true}
    var isShimmering:Bool{!reduceMotion() && snapshot.activity?.shimmering == true && activityTextRect.width>0}
    var activityText:String {
        if hoveredActivity,snapshot.activity?.kind == .question,let text=snapshot.hoverQuestion{return text}
        return snapshot.activity?.text ?? ""
    }
    var activityIsTruncated:Bool{(activityText as NSString).size(withAttributes:[.font:font]).width>activityTextRect.width}
    override init(frame:NSRect){
        super.init(frame:frame);wantsLayer=true;layer?.masksToBounds=true;layer?.cornerRadius=15;setAccessibilityElement(true);setAccessibilityRole(.group)
        layer?.addSublayer(dividerLayer);layer?.addSublayer(dotLayer);layer?.addSublayer(shimmer)
        timer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){[weak self] _ in Task{@MainActor in
            guard let self else{return}
            if self.widthIsAnimating{self.onWidthChange?()}
            self.updateShimmerPosition()
        }}
    }
    required init?(coder:NSCoder){fatalError()}
    deinit{timer?.invalidate()}
    private var widthIsAnimating:Bool{!reduceMotion() && abs(displayedWidth-widthTarget)>0.1}
    private func updateAccessibility(){setAccessibilityLabel(snapshot.title+(snapshot.dot ? " · 처리할 일 있음":"")+(snapshot.activity == nil ? "":" · "+activityText))}
    func show(_ value:IslandModel.Snapshot){
        snapshot=value;if value.activity?.kind != .question{hoveredActivity=false}
        updateAccessibility();updateDotMotion();needsLayout=true;needsDisplay=true;onWidthChange?()
    }
    private var titleWidth:CGFloat{(snapshot.title as NSString).size(withAttributes:[.font:font]).width}
    private var separatorWidth:CGFloat{snapshot.dot || snapshot.activity != nil ? 9:0}
    private var dotWidth:CGFloat{snapshot.dot ? 16:0}
    func fittedWidth(limit:CGFloat)->CGFloat{
        let activity=snapshot.activity.map{CGFloat($0.faces.count)*14+12+min(340,ceil((activityText as NSString).size(withAttributes:[.font:font]).width))} ?? 0
        let limit=max(0,limit),target=min(limit,24+titleWidth+separatorWidth+dotWidth+activity),now=ProcessInfo.processInfo.systemUptime
        if !hasWidth || reduceMotion(){displayedWidth=target;widthTarget=target;widthFrom=target;hasWidth=true;animationSteps=0}
        else{
            if target != widthTarget{widthFrom=displayedWidth;widthStart=now;widthTarget=target}
            let t=min(1,max(0,(now-widthStart)/0.18)),next=widthFrom+(widthTarget-widthFrom)*CGFloat(1-pow(1-t,3))
            if abs(next-displayedWidth)>0.01{animationSteps += 1};displayedWidth=min(limit,next)
        }
        return max(0,displayedWidth)
    }
    override func layout(){
        super.layout()
        // Keep the title at x=12; sacrifice activity text before truncating the title.
        let width=min(titleWidth,max(0,bounds.width-24-separatorWidth-dotWidth))
        titleTextRect=CGRect(x:12,y:8,width:width,height:16)
        var x=titleTextRect.maxX+8
        dividerLayer.isHidden = !snapshot.dot && snapshot.activity == nil
        dividerLayer.frame=CGRect(x:x,y:8,width:1,height:14)
        x += separatorWidth
        dotLayer.frame=CGRect(x:x,y:11,width:8,height:8);x += dotWidth
        titleRect=CGRect(x:0,y:0,width:min(bounds.width,snapshot.activity == nil ? bounds.width:x),height:30)
        activityRect=CGRect(x:min(bounds.width,x),y:0,width:snapshot.activity == nil ? 0:max(0,bounds.width-x),height:30)
        faceRects=[]
        if let activity=snapshot.activity{
            var faceX=activityRect.minX+4
            for _ in activity.faces{faceRects.append(CGRect(x:faceX,y:7,width:16,height:16));faceX += 14}
            activityTextRect=CGRect(x:faceX+4,y:8,width:max(0,bounds.width-faceX-12),height:16)
        }else{activityTextRect = .zero}
        effectiveAppearance.performAsCurrentDrawingAppearance{
            dotLayer.backgroundColor=NSColor.systemRed.cgColor;dotLayer.borderColor=NSColor.systemRed.withAlphaComponent(0.25).cgColor
            dividerLayer.backgroundColor=NSColor.labelColor.withAlphaComponent(0.18).cgColor
        }
        dotLayer.cornerRadius=4;dotLayer.borderWidth=1
        updateDotMotion()
        if snapshot.activity?.shimmering == true{
            shimmer.configure(text:activityText,font:font,frame:activityTextRect,scale:window?.backingScaleFactor ?? 2)
        }else{shimmer.isHidden=true}
        updateShimmerPosition()
    }
    private func updateDotMotion(){
        dotLayer.isHidden = !snapshot.dot;dotLayer.opacity=1
        if snapshot.dot && !snapshot.drawerOpen && !reduceMotion(){
            if dotLayer.animation(forKey:"breathe")==nil{
                let motion=CAKeyframeAnimation(keyPath:"opacity");motion.values=[1.0,0.35,1.0];motion.keyTimes=[0,0.5,1]
                motion.duration=2.4;motion.repeatCount = .infinity
                motion.timingFunctions=[CAMediaTimingFunction(name:.easeInEaseOut),CAMediaTimingFunction(name:.easeInEaseOut)]
                dotLayer.add(motion,forKey:"breathe")
            }
        }else{dotLayer.removeAnimation(forKey:"breathe")}
    }
    func updateShimmerPosition(){
        updateDotMotion();shimmer.update(time:animationTime(),running:isShimmering)
        if !shimmer.isHidden{shimmerPosition=shimmer.bandX}
    }
    private var activityColor:NSColor{
        switch snapshot.activity?.tone ?? .normal{case .normal:return .labelColor;case .orange:return .systemOrange;case .red:return .systemRed;case .green:return .systemGreen}
    }
    override func draw(_ dirtyRect:NSRect){
        let path=NSBezierPath(roundedRect:bounds.insetBy(dx:0.5,dy:0.5),xRadius:15,yRadius:15)
        NSColor.labelColor.withAlphaComponent(0.055).setFill();path.fill()
        (snapshot.drawerOpen ? NSColor.controlAccentColor:snapshot.activity == nil ? NSColor.labelColor.withAlphaComponent(0.13):activityColor.withAlphaComponent(0.55)).setStroke();path.lineWidth=1;path.stroke()
        NSGraphicsContext.saveGraphicsState();path.addClip();defer{NSGraphicsContext.restoreGraphicsState()}
        let style=NSMutableParagraphStyle();style.lineBreakMode = .byTruncatingTail
        (snapshot.title as NSString).draw(in:titleTextRect,withAttributes:[.font:font,.foregroundColor:NSColor.labelColor,.paragraphStyle:style])
        guard let activity=snapshot.activity else{return}
        NSGraphicsContext.saveGraphicsState();NSBezierPath(rect:activityRect).addClip();defer{NSGraphicsContext.restoreGraphicsState()}
        for (index,rect) in faceRects.enumerated(){
            avatar(activity.faceEmployees.indices.contains(index) ? activity.faceEmployees[index]:activity.faces[index]).draw(in:rect,name:activity.faces[index])
            if activity.tone == .green{NSColor.systemGreen.setStroke();let border=NSBezierPath(ovalIn:rect.insetBy(dx:0.5,dy:0.5));border.lineWidth=1;border.stroke()}
        }
        (activityText as NSString).draw(in:activityTextRect,withAttributes:[.font:font,.foregroundColor:activity.shimmering ? NSColor.labelColor.withAlphaComponent(0.45):activityColor,.paragraphStyle:style])
    }
    override func updateTrackingAreas(){
        super.updateTrackingAreas();if let tracking{removeTrackingArea(tracking)}
        let area=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(area);tracking=area
    }
    func hover(at point:CGPoint?){
        let next=point.map{activityRect.contains($0)} ?? false
        if next != hoveredActivity{hoveredActivity=next;updateAccessibility();onWidthChange?();needsLayout=true;needsDisplay=true}
    }
    override func mouseMoved(with event:NSEvent){hover(at:convert(event.locationInWindow,from:nil))}
    override func mouseEntered(with event:NSEvent){mouseMoved(with:event)}
    override func mouseExited(with event:NSEvent){hover(at:nil)}
    func activate(at point:CGPoint){
        guard bounds.contains(point) else{return}
        if activityRect.contains(point),let activity=snapshot.activity{
            // Overlapping faces are painted from left to right; hit the frontmost face first.
            if let index=faceRects.indices.reversed().first(where:{faceRects[$0].contains(point)}),activity.faceActions.indices.contains(index){onAction?(activity.faceActions[index])}
            else{onAction?(activity.action ?? .drawer)}
        }else{onAction?(.drawer)}
    }
    override func mouseDown(with event:NSEvent){activate(at:convert(event.locationInWindow,from:nil))}
    override func mouseDragged(with event:NSEvent){}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func resetCursorRects(){addCursorRect(bounds,cursor:.pointingHand)}
}
