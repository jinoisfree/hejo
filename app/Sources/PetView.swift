import AppKit
import CoreImage

final class PetPanel: NSPanel {
    var chatExpanded = false
    var bubbleReplyPresented=false
    var onCancelComposerBranch: (() -> Bool)?
    var onCloseDrawer: (() -> Bool)?
    var onCollapse: (() -> Void)?
    var onPageKey: ((NSEvent) -> Bool)?
    var onWorkspaceKey:((NSEvent)->Bool)?
    override var canBecomeKey: Bool { chatExpanded || bubbleReplyPresented }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override func orderOut(_ sender:Any?){super.orderOut(sender);(contentView as? PetView)?.updateFoldedBubble();(contentView as? PetView)?.updateAnimationVisibility()}
    override func orderFrontRegardless(){super.orderFrontRegardless();(contentView as? PetView)?.updateFoldedBubble();(contentView as? PetView)?.updateAnimationVisibility()}
    override func cancelOperation(_ sender: Any?) {
        if let input=firstResponder as? NSTextInputClient,input.hasMarkedText(){return}
        if onCancelComposerBranch?()==true || onCloseDrawer?()==true {return}
        if (contentView as? PetView)?.bubbleReply?.escape()==true {return};onCollapse?()
    }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown,!isKeyWindow,let pet=contentView as? PetView,
           let hit=pet.hitTest(event.locationInWindow),
           (chatExpanded && (hit === pet.conversation || hit.isDescendant(of:pet.conversation))) || bubbleReplyPresented && ((hit as? NSTextView)?.isEditable==true || (hit as? NSTextField)?.isEditable==true) {makeKey()}
        if event.type == .keyDown,event.keyCode == 53 {
            if let input=firstResponder as? NSTextInputClient,input.hasMarkedText(){super.sendEvent(event);return}
            cancelOperation(nil);return
        }
        if chatExpanded,event.type == .keyDown,onPageKey?(event)==true {return}
        if chatExpanded,event.type == .keyDown,onWorkspaceKey?(event)==true {return}
        super.sendEvent(event)
    }
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        if chatExpanded,onPageKey?(event)==true{return true}
        if chatExpanded,event.modifierFlags.contains(.command),Self.shortcutKey(event)=="f",onWorkspaceKey?(event)==true{return true}
        if chatExpanded || bubbleReplyPresented && isKeyWindow,let action=Self.editAction(for:event),NSApp.sendAction(action,to:nil,from:self){return true}
        return super.performKeyEquivalent(with:event)
    }
    static func shortcutKey(_ event: NSEvent) -> String? {
        if let key = event.charactersIgnoringModifiers?.lowercased(), key.unicodeScalars.allSatisfy(\.isASCII), !key.isEmpty { return key }
        return [0: "a", 3: "f", 6: "z", 7: "x", 8: "c", 9: "v"][event.keyCode]
    }
    /// The pet has no menu bar, so the usual Edit shortcuts never reach the text unless they are routed here.
    static func editAction(for event: NSEvent) -> Selector? {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = shortcutKey(event)
        if flags == [.command, .shift] { return key == "z" ? Selector(("redo:")) : nil }
        guard flags == .command else { return nil }
        switch key {
        case "c": return #selector(NSText.copy(_:))
        case "v": return #selector(NSText.paste(_:))
        case "x": return #selector(NSText.cut(_:))
        case "a": return #selector(NSText.selectAll(_:))
        case "z": return Selector(("undo:"))
        default: return nil
        }
    }
}
@available(macOS 26.0, *)
final class PetGlassView: NSGlassEffectView { override func hitTest(_ point: NSPoint) -> NSView? { nil } }
final class PetVibrancyView: NSVisualEffectView { override func hitTest(_ point: NSPoint) -> NSView? { nil } }
final class PetBadgeView: NSView {
    static let height: CGFloat = 13
    var text = "" { didSet { needsDisplay = true } }
    private static let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 8.5), .foregroundColor: NSColor.white]
    static func size(_ text: String) -> CGSize { CGSize(width: max(height, ceil((text as NSString).size(withAttributes: attributes).width) + 6), height: height) }
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        let edge = bounds.insetBy(dx: 0.5, dy: 0.5), path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor.systemBlue.setFill(); path.fill(); NSColor.white.setStroke(); path.lineWidth = 1; path.stroke()
        let size = (text as NSString).size(withAttributes: Self.attributes)
        (text as NSString).draw(at: NSPoint(x: edge.midX-size.width/2, y: edge.midY-size.height/2), withAttributes: Self.attributes)
    }
}
final class PetSpriteView: NSView {
    var onDraw: ((CGRect) -> Void)?
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) { onDraw?(bounds) }
}
/// One native surface for the pet and the future conversation. No content framework host.
final class PetView: NSView {
    let atlas: SpriteAtlas
    let conversation = NSView()
    let foldedBubble = FoldedBubbleView(frame: .zero)
    let statusLabel = NSTextField(labelWithString: "서버 연결 전")
    let collapseButton = NSButton(title: "펫으로 접기", target: nil, action: nil)
    private var conversationContent: NSView?
    private(set) var webPane: WebPaneView?
    var paneWidth: CGFloat = 0, paneSliding = false
    var onResetPaneSize: (() -> Void)?
    func installWeb(_ view: WebPaneView) { webPane?.removeFromSuperview(); webPane = view; conversation.addSubview(view) }

    private var glass: NSView!
    private let tint = NSView()
    let unreadBadge = PetBadgeView()
    var unreadCount = 0 { didSet { updateFoldedBubble() } }
    var bubbleNow: () -> TimeInterval = { Date().timeIntervalSince1970 }
    var bubbleAlwaysShown = false { didSet { updateFoldedBubble() } }
    var bubbleName = "hejo" { didSet { updateFoldedBubble() } }
    var avatarForEmployee:((String)->ProfileAvatar)?
    var bubbleStatus = "" { didSet { updateFoldedBubble() } }
    private(set) var bubbleTarget:ConversationKey?
    var bubbleNotice=BubbleReveal.Notice(kind:.idle,headline:"",detail:"",key:nil) {
        didSet {bubbleTarget=bubbleNotice.key;if bubbleNotice.id != oldValue.id && (bubbleNotice.kind == .reply || bubbleNotice.workState == .waiting || bubbleNotice.workState == .failed) && window?.isVisible==true {alertUntil=bubbleNow()+3};updateFoldedBubble();if bubbleNotice.actions.count != oldValue.actions.count {onBubbleSize?()}}
    }
    var bubbleReply:BubbleReplyCard?
    var bubbleReplyAllowed=true
    var bubbleReplyConnected=false
    var foldedSize:CGSize {CGSize(width:231,height:(previewing || bubbleNotice.actions.isEmpty ? 56:90)+(bubbleReply?.visible==true ? bubbleReply!.height:0))}
    func installBubbleReply(_ card:BubbleReplyCard){
        bubbleReply=card;foldedBubble.addSubview(card)
        card.onGeometry={ [weak self] in guard let self else{return};self.onBubbleSize?();self.updateFoldedBubble() }
    }
    func updateBubbleReply(pointerOver:Bool){
        guard let card=bubbleReply else{return}
        card.update(.init(enabled:bubbleReplyAllowed,connected:bubbleReplyConnected,paused:isPaused,resting:activityPose == .doze,chatExpanded:placement?.expanded==true,bubbleShown:!foldedBubble.isHidden,hasTarget:card.target != nil),pointerOver:pointerOver)
        (window as? PetPanel)?.bubbleReplyPresented=card.visible
        let wasVisible=card.visible
        card.frame=CGRect(x:0,y:bubbleNotice.actions.isEmpty ? 56:90,width:foldedBubble.bounds.width,height:card.height)
        if wasVisible {card.layoutSubtreeIfNeeded()}
    }
    var onBubbleSize:(()->Void)?
    private var bubbleHover=false
    private(set) var hoverArmed=true,bubbleShown=false
    private var alertUntil:TimeInterval = -.infinity
    func disarmBubbleHover(){hoverArmed=false;bubbleHover=false;alertUntil = -.infinity}
    private var firstHeadline=true
    var homeConversation=false
    var subtitleInterrupted=false
    private var doze=PetDoze(),chatBehavior=ChatPetBehavior()
    private var wavePending=false,dragAnimation=PetAnimation.right,previousDragMouse:CGPoint?
    var previewRow: Int? { didSet { animationStarted = activityNow(); onBubbleSize?() } }
    var previewLook = false { didSet { onBubbleSize?() } }
    var previewing: Bool { previewRow != nil || previewLook }
    private var animationStarted:Double=0,currentAnimation=PetAnimation.idle
    var displayedFrame:PetAnimationFrame {pose}
    var onBubbleOpen:((ConversationKey?)->Void)?
    var onBubbleAction:((BubbleReveal.Action)->Void)?
    var activityNow:()->TimeInterval={ProcessInfo.processInfo.systemUptime}
    private var activity=PetActivity(now:ProcessInfo.processInfo.systemUptime)
    private var replyJump=false,playback=PetChatPlayback()
    private(set) var jumpElapsed:TimeInterval?
    let thoughtDots=(0..<3).map{_ in PetThoughtView()}
    var taskState: WorkState = .idle
    var screenFocus: ScreenFocus?
    var resolveScreen: (ScreenFocus?,TimeInterval)->CGPoint? = ScreenWindowResolver().resolve
    var hasAsked=false,isTyping=false,sendFailed=false,isPaused=false
    var animationsAllowed=true {didSet{updateAnimationVisibility()}}
    private(set) var activityPose:PetActivity.Pose = .idle
    func noteActivity(){activity.touch(now:activityNow())}
    func noteSend(){if homeConversation {wavePending=true;activity.sent(now:activityNow())}}
    func requestReplyJump(){replyJump=true;noteActivity()}
    func updateFoldedBubble(){
        let notice=bubbleNotice
        let shown=window?.isVisible==true && placement?.expanded != true && (previewing || notice.held || bubbleNow()<alertUntil || bubbleHover || bubbleAlwaysShown || bubbleReply?.visible==true)
        if shown != bubbleShown {
            bubbleShown=shown
            if shown {foldedBubble.isHidden=false}
            let surfaces:[NSView]=[foldedBubble]+thoughtDots
            if reduceMotion() {surfaces.forEach{$0.alphaValue=shown ? 1:0};foldedBubble.isHidden = !shown}
            else {NSAnimationContext.runAnimationGroup({context in context.duration=0.18;surfaces.forEach{$0.animator().alphaValue=shown ? 1:0}},completionHandler:{[weak self] in if self?.bubbleShown==false {self?.foldedBubble.isHidden=true}})}
        }
        if reduceMotion(){foldedBubble.alphaValue=shown ? 1:0;foldedBubble.isHidden = !shown}
        foldedBubble.headline=notice.headline.isEmpty ? (firstHeadline ? PetIdentity.greeting(bubbleName):activityPose == .doze ? "나 자는거 아니다":"헤헤헹"):isPaused ? PetIdentity.subject(bubbleName)+" 쉬고 있어요":notice.headline
        foldedBubble.detail=notice.kind == .idle && notice.workState == nil && !isPaused ? "":notice.detail
        if previewing {
            foldedBubble.headline = "미리보기 · " + (previewLook ? "마우스 바라보기" : PetController.previewNames[previewRow!])
            foldedBubble.detail = previewLook ? "\(bubbleName) · 포인터를 움직여 보세요" : "\(bubbleName)의 동작 · 실제 작업과 별개"
        }
        foldedBubble.sender=notice.sender;foldedBubble.avatar=notice.sender.isEmpty ? nil:notice.key.flatMap{avatarForEmployee?($0.employee)}
        foldedBubble.kind=notice.kind;foldedBubble.unread=unreadCount;foldedBubble.actions=previewing ? []:notice.actions
        foldedBubble.interrupted=subtitleInterrupted;foldedBubble.tick(at:Date().timeIntervalSinceReferenceDate,paused:isPaused || !animationsAllowed)
        toolTip="\(bubbleName) · 클릭: 열기 · 드래그: 이동 · 오른쪽 클릭: 메뉴"
        setAccessibilityLabel("hejo · \(bubbleName) · \(foldedBubble.headline) · 버튼: \(foldedBubble.actions.map(\.title).joined(separator:", ")) · 안 읽은 답 \(unreadCount)개")
        foldedBubble.setAccessibilityLabel(foldedBubble.headline+" · "+foldedBubble.detail+" · 대화 열기")
        if let card=bubbleReply {
            card.isHidden = !card.visible || placement?.expanded==true
            card.frame=CGRect(x:0,y:notice.actions.isEmpty ? 56:90,width:foldedBubble.bounds.width,height:card.height)
            (window as? PetPanel)?.bubbleReplyPresented=card.visible && placement?.expanded != true
            foldedBubble.setAccessibilityCustomActions(card.eligible ? [NSAccessibilityCustomAction(name:BubbleReply.accessibilityName,handler:{ [weak card] in card?.openNow();return true })]:[])
        }
        updateUnreadBadge();layoutThoughtDots()
    }
    private func layoutThoughtDots(){
        guard let p=placement else{return}
        let head=atlas.interactionRect(in:spriteRect),bubble=p.bubbleRect
        let start=p.bubbleBelow ? head.minY:head.maxY,end=p.bubbleBelow ? bubble.maxY:bubble.minY
        let room=abs(end-start)>=26 && !foldedBubble.isHidden && !p.expanded
        let lean=max(-18,min(18,(bubble.midX-head.midX)*0.25+12))
        for (i,dot) in thoughtDots.enumerated(){dot.isHidden = !room;let along=[0.14,0.44,0.78][i],size:CGFloat=[7,11,16][i];dot.frame=CGRect(x:(head.midX+lean*along-size/2).rounded(),y:(start+(end-start)*along-size/2).rounded(),width:size,height:size)}
    }
    private func updateUnreadBadge() {
        let text = unreadCount > 9 ? "9+" : unreadCount > 0 ? String(unreadCount) : ""
        unreadBadge.text = text
        let head = atlas.interactionRect(in: spriteRect), size = PetBadgeView.size(text)
        unreadBadge.frame = CGRect(origin: CGPoint(x: floor(min(head.maxX-size.width/2,spriteRect.maxX-size.width)), y: floor(min(head.maxY-size.height/2,spriteRect.maxY-size.height))), size: size)
        unreadBadge.isHidden = unreadCount <= 0 || placement?.expanded == true || !foldedBubble.isHidden || isPaused
        unreadBadge.setAccessibilityLabel("안 읽은 답 \(unreadCount)개")
    }
    func installConversation(_ view: NSView) {
        conversationContent?.removeFromSuperview(); conversationContent = view; conversation.addSubview(view)
        statusLabel.isHidden = true; collapseButton.isHidden = true
    }
    let genie = GenieView()
    private let sprite = PetSpriteView()
    var placement: PetPlacement?
    var spriteRect: CGRect { placement?.spriteRect ?? .zero }
    var petScale: CGFloat = 0.75
    var pointerLocation: () -> CGPoint = { NSEvent.mouseLocation }
    var onClick: (() -> Void)?
    var onMenu: ((NSEvent) -> Void)?
    var onDragMove: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    var onResize: ((PetLayout.ResizeEdge, CGPoint) -> Void)?
    var onResetSize:(()->Void)?
    private var press: CGPoint?
    private var anchor = CGPoint.zero
    private var edge: PetLayout.ResizeEdge = []
    private(set) var didDrag = false
    private var timer: Timer?
    private var pointer = PetPointerInteraction()
    private var pose = PetAnimationFrame(row: 0, column: 0)
    var chatOpacityPercent = BubbleOpacity.defaultPercent {didSet {updateScrim()}}
    var reduceTransparency: () -> Bool = {NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency}
    var chatTintAlpha: CGFloat {tint.layer?.backgroundColor?.alpha ?? 0}
    func updateScrim() {
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let alpha=BubbleOpacity.alpha(progress:placement?.expanded==true ? 1:0,percent:chatOpacityPercent,reduceTransparency:reduceTransparency())
        let color=(dark ? NSColor.black:.white).withAlphaComponent(alpha).cgColor
        guard tint.layer?.backgroundColor != color else{return}
        CATransaction.begin();CATransaction.setDisableActions(true);tint.layer?.backgroundColor=color;CATransaction.commit()
    }
    override func viewDidChangeEffectiveAppearance(){super.viewDidChangeEffectiveAppearance();updateScrim();needsDisplay=true}
    var reduceMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    init(atlas: SpriteAtlas) {
        self.atlas = atlas; super.init(frame: .zero)
        wantsLayer = true; conversation.wantsLayer = true
        tint.wantsLayer = true
        if #available(macOS 26.0, *) {
            let surface = PetGlassView(); surface.style = .clear; surface.cornerRadius = PetLayout.cornerRadius; surface.contentView = tint; glass = surface
        } else {
            let surface = PetVibrancyView(); surface.material = .popover; surface.blendingMode = .behindWindow; surface.state = .active; surface.addSubview(tint); glass = surface
        }
        glass.autoresizingMask = [.width, .height]; tint.autoresizingMask = [.width, .height]
        conversation.addSubview(glass)
        conversation.layer?.cornerRadius = PetLayout.cornerRadius
        conversation.layer?.masksToBounds = true
        statusLabel.font = .systemFont(ofSize: 13); statusLabel.textColor = .secondaryLabelColor
        conversation.addSubview(statusLabel); conversation.addSubview(collapseButton)
        addSubview(conversation); thoughtDots.forEach{addSubview($0);$0.isHidden=true}; addSubview(foldedBubble); addSubview(genie); addSubview(sprite); addSubview(unreadBadge); unreadBadge.isHidden = true
        foldedBubble.isHidden = true
        foldedBubble.onHover = { [weak self] hovering in if hovering {self?.bubbleHover=true}; self?.updateFoldedBubble(); if hovering { self?.noteActivity() } }
        foldedBubble.reduceMotion = { [weak self] in self?.reduceMotion() ?? true }
        foldedBubble.onAction = { [weak self] in self?.onBubbleAction?($0) }
        foldedBubble.onOpen = { [weak self] in guard let self else { return }; self.noteActivity(); self.onBubbleOpen?(self.bubbleTarget) }
        genie.wantsLayer = true
        sprite.onDraw = { [weak self] cell in
            guard let self else { return }; self.atlas.draw(row: self.pose.row, frame: self.pose.column, in: cell, view: self.sprite)
            if self.pose.row==PetAnimationTimeline.dozeRow {self.drawZs(PetAnimationTimeline.dozeZs(column:self.pose.column),in:cell)}
        }
        conversation.isHidden = true; genie.isHidden = true
        toolTip = "hejo · 클릭: 대화 열기 · 끌기: 이동 · 오른쪽 클릭: 메뉴"
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel("hejo 펫 · 대화 열기")
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func rightMouseDown(with event: NSEvent) { onMenu?(event) }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); updateAnimationVisibility()
    }
    func updateAnimationVisibility() {
        timer?.invalidate(); timer = nil
        guard window?.isVisible == true, animationsAllowed else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.animate() }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    func animate() {
        guard window?.isVisible == true, animationsAllowed, placement != nil else { updateAnimationVisibility(); return }
        let now = activityNow()
        updateActivityPresentation(at: now)
        if activityPose == .doze {activityPose = .idle}
        if isPaused {updateBubbleReply(pointerOver:false);replyJump=false;jumpElapsed=playback.update(now:now,reply:false,pointerElapsed:nil,enabled:false);sprite.needsDisplay = true;return}
        let pointer = pointerLocation(), origin = window!.convertPoint(toScreen: .zero)
        let global = PetLayout.visibleSprite(in: spriteRect).offsetBy(dx: origin.x, dy: origin.y)
        let bridge=global.union(placement!.bubbleRect.offsetBy(dx:origin.x,dy:origin.y))
        if !global.contains(pointer){hoverArmed=true}
        bubbleHover = hoverArmed && (global.contains(pointer) || (bubbleHover && bubbleShown && bridge.contains(pointer)))
        updateFoldedBubble()
        updateBubbleReply(pointerOver:!foldedBubble.isHidden && placement!.bubbleRect.offsetBy(dx:origin.x,dy:origin.y).contains(pointer))
        let phase=self.pointer.update(pointer:pointer,sprite:global,display:window!.screen?.frame ?? global,now:now,enabled:!didDrag && !previewing,reducedMotion:reduceMotion())
        let pointerElapsed:TimeInterval?;if case .jumping(let elapsed)=phase {pointerElapsed=elapsed} else {pointerElapsed=nil}
        jumpElapsed=playback.update(now:now,reply:replyJump,pointerElapsed:pointerElapsed,enabled:!isPaused && !hasAsked && !didDrag && !previewing && !reduceMotion())
        let state:WorkState=hasAsked ? .waiting:isTyping ? .running:taskState
        let animation=PetChatPlayback.animation(state:state,typing:isTyping && !previewLook,jumping:jumpElapsed != nil,drag:didDrag ? dragAnimation:nil,preview:previewRow.flatMap(PetAnimation.init(rawValue:)))
        if animation != currentAnimation {currentAnimation=animation;animationStarted=now}
        pose=PetAnimationTimeline.frame(for:animation,elapsed:jumpElapsed ?? (now-animationStarted),reducedMotion:reduceMotion(),loop:didDrag || previewRow != nil || animation == .replyWaiting)
        var looking=false
        if previewRow == PetAnimationTimeline.dozeRow {
            pose=PetAnimationTimeline.dozeFrame(elapsed:now-animationStarted,reducedMotion:reduceMotion())
        } else if let row=previewRow,row>=9 {
            pose=PetAnimationFrame(row:row,column:Int((now-animationStarted)/0.25)%8)
        } else if previewRow==nil,!didDrag,!hasAsked,!sendFailed,jumpElapsed==nil,(!isTyping || previewLook),animation.allowsLook {
            if previewLook || { if case .looking = phase { return true }; return false }() {
                pose=PetAnimationTimeline.lookFrame(from:CGPoint(x:global.midX,y:global.midY),toward:pointer,previous:pose) ?? pose;looking=true
            } else if phase == .inactive,let target=resolveScreen(screenFocus,now) {
                pose=PetAnimationTimeline.lookFrame(from:CGPoint(x:global.midX,y:global.midY),toward:target,previous:pose) ?? pose;looking=true
            }
        }
        let quiet=animation == .idle && !previewing && !looking && phase == .inactive && placement?.expanded != true
        if let elapsed=doze.update(now:now,quiet:quiet){pose=PetAnimationTimeline.dozeFrame(elapsed:elapsed,reducedMotion:reduceMotion());activityPose = .doze}
        else if placement?.expanded==true && activityPose == .doze {activityPose = .idle}
        if placement?.expanded==true,homeConversation,!hasAsked,!sendFailed,!didDrag,!previewing {
            let elapsed=chatBehavior.update(now:now,touching:global.contains(pointer),cursorNear:placement!.globalBubble.contains(pointer),writing:isTyping,hop:replyJump,wave:wavePending)
            switch chatBehavior.pose {
            case .approval:pose=PetAnimationTimeline.frame(for:.waiting,elapsed:elapsed,reducedMotion:reduceMotion())
            case .jump:pose=PetAnimationTimeline.frame(for:.jumping,elapsed:elapsed,reducedMotion:reduceMotion(),loop:true)
            case .replyWaiting:pose=PetAnimationTimeline.frame(for:.replyWaiting,elapsed:elapsed,reducedMotion:reduceMotion(),loop:true)
            case .wave:pose=PetAnimationTimeline.frame(for:.waving,elapsed:elapsed,reducedMotion:reduceMotion(),loop:true)
            case .look:pose=PetAnimationTimeline.lookFrame(from:CGPoint(x:global.midX,y:global.midY),toward:pointer,previous:pose) ?? pose
            case .idle:pose=PetAnimationTimeline.frame(for:.idle,elapsed:elapsed,reducedMotion:reduceMotion())
            }
        } else {chatBehavior.reset()}
        replyJump=false;wavePending=false;firstHeadline=false
        updateFoldedBubble()
        sprite.needsDisplay = true
    }
    func updateActivityPresentation(at now: TimeInterval) {
        activityPose = activity.pose(now: now, asked: hasAsked, typing: isTyping, failed: sendFailed, paused: isPaused)
        if placement?.expanded==true && activityPose == .doze {activityPose = .idle}
        if isPaused { pose = PetAnimationTimeline.frame(for: .idle, elapsed: now, reducedMotion: true) }
    }
    func arrange(_ p: PetPlacement) {
        placement = p; frame = CGRect(origin: .zero, size: p.windowFrame.size)
        sprite.frame = p.spriteRect; conversation.frame = p.bubbleRect; foldedBubble.frame = p.bubbleRect; genie.frame = bounds
        statusLabel.frame = CGRect(x: 20, y: max(20, p.bubbleRect.height - 80), width: max(0, p.bubbleRect.width - 40), height: 36)
        collapseButton.frame = CGRect(x: 16, y: max(0, p.bubbleRect.height - 38), width: 120, height: 28)
        glass.frame = conversation.bounds; tint.frame = conversation.bounds
        updateScrim()
        if !paneSliding {
            conversationContent?.frame = CGRect(x:0,y:0,width:max(0,p.bubbleRect.width-paneWidth),height:p.bubbleRect.height)
            webPane?.isHidden = paneWidth <= 0
            webPane?.frame = CGRect(x:p.bubbleRect.width-paneWidth,y:0,width:paneWidth,height:p.bubbleRect.height)
        }
        updateUnreadBadge()
        updateFoldedBubble()
        sprite.needsDisplay = true
    }
    func spriteContains(_ point: CGPoint) -> Bool { atlas.opaque(at: point, in: spriteRect, row: pose.row, frame: pose.column) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let p = placement else { return nil }
        if spriteContains(point) { return self }
        if p.expanded, !genie.isHidden { return self }
        if !p.expanded, !foldedBubble.isHidden, p.bubbleRect.contains(point) { return foldedBubble.hitTest(point) }
        if p.expanded, p.bubbleRect.contains(point) {
            if !PetLayout.resizeEdge(at: point, bubble: p.bubbleRect, below: p.bubbleBelow).isEmpty { return self }
            return conversation.hitTest(point)
        }
        return nil
    }
    override func mouseDown(with event: NSEvent) {
        let local = convert(event.locationInWindow, from: nil)
        edge = spriteContains(local) ? [] : placement.map { $0.expanded ? PetLayout.resizeEdge(at: local, bubble: $0.bubbleRect, below: $0.bubbleBelow) : [] } ?? []
        guard spriteContains(local) || !edge.isEmpty else { return }
        if !edge.isEmpty && event.clickCount==2 {if paneWidth > 0, edge.contains(.right) {onResetPaneSize?()} else {onResetSize?()};return}
        guard event.clickCount==1 else{return}
        noteActivity()
        press = pointerLocation();previousDragMouse=press;anchor = placement?.anchorOrigin ?? .zero;didDrag=false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let press else { return }; let p = pointerLocation(); let delta = CGPoint(x: p.x - press.x, y: p.y - press.y)
        guard didDrag || hypot(delta.x, delta.y) > 4 else { return }; didDrag = true
        dragAnimation=PetAnimationTimeline.dragAnimation(horizontalDelta:p.x-(previousDragMouse?.x ?? press.x),previous:dragAnimation);previousDragMouse=p
        if edge.isEmpty { onDragMove?(CGPoint(x: anchor.x + delta.x, y: anchor.y + delta.y)) } else { onResize?(edge, delta) }
    }
    override func mouseUp(with event: NSEvent) {
        guard press != nil else { return }; press = nil
        if didDrag { onDragEnded?() } else if edge.isEmpty { onClick?() }
        edge = [];didDrag=false;previousDragMouse=nil
    }
    override func accessibilityPerformPress()->Bool {onClick?();return true}
    override func resetCursorRects(){
        super.resetCursorRects();guard let p=placement,p.expanded else{return}
        for region in PetLayout.resizeRegions(bubble:p.bubbleRect,below:p.bubbleBelow){
            let cursor:NSCursor
            if region.edge == .far {cursor = .resizeUpDown}
            else if !region.edge.contains(.far) && !region.edge.contains(.near){cursor = .resizeLeftRight}
            else {cursor=(region.edge.contains(.left)==p.bubbleBelow) != region.edge.contains(.near) ? Self.risingResizeCursor:Self.fallingResizeCursor}
            addCursorRect(region.rect,cursor:cursor)
        }
    }
    private static func diagonalCursor(_ rising: Bool) -> NSCursor {
        let image = NSImage(size:NSSize(width:20,height:20),flipped:false) { _ in
            let path = NSBezierPath()
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x:x,y:rising ? y : 20-y) }
            path.move(to:point(4,4)); path.line(to:point(16,16))
            path.move(to:point(4,10)); path.line(to:point(4,4)); path.line(to:point(10,4))
            path.move(to:point(10,16)); path.line(to:point(16,16)); path.line(to:point(16,10))
            NSColor.white.setStroke(); path.lineWidth = 4; path.stroke()
            NSColor.black.setStroke(); path.lineWidth = 2; path.stroke(); return true
        }
        return NSCursor(image:image,hotSpot:NSPoint(x:10,y:10))
    }
    private static let risingResizeCursor = diagonalCursor(true), fallingResizeCursor = diagonalCursor(false)

    private func drawZs(_ squares:[CGRect],in cell:CGRect){
        let unit=cell.width/192
        for square in squares {
            let left=cell.minX+square.minX*unit,right=cell.minX+square.maxX*unit,top=cell.maxY-square.minY*unit,bottom=cell.maxY-square.maxY*unit
            let z=NSBezierPath();z.move(to:CGPoint(x:left,y:top));z.line(to:CGPoint(x:right,y:top));z.line(to:CGPoint(x:left,y:bottom));z.line(to:CGPoint(x:right,y:bottom));z.lineCapStyle = .round;z.lineJoinStyle = .round
            for (width,color) in [(4.0,NSColor(red:16/255,green:12/255,blue:12/255,alpha:1)),(1.9,NSColor.white)]{color.setStroke();z.lineWidth=width*unit;z.stroke()}
        }
    }
    private let widthCover=PetWidthCoverView()
    var widthCoverVisible:Bool {widthCover.superview != nil}
    func beginWidthCover(){
        captureGenie();widthCover.image=genie.blurredImage.map{NSImage(cgImage:$0,size:conversation.bounds.size)} ?? genie.image
        endGenie(expanded:true);widthCover.imageScaling = .scaleAxesIndependently;widthCover.frame=conversation.bounds;conversation.addSubview(widthCover);widthCover.alphaValue=0
    }
    func setWidthCover(alpha:CGFloat){widthCover.frame=conversation.bounds;widthCover.alphaValue=alpha;layoutPanePicture()}
    private var panePicture: CALayer?, paneSharp: CALayer?
    private var panePictureBase: CGFloat = 0
    func setPanePicture(_ picture: WebPicture?, base: CGFloat, closing: Bool) {
        panePicture?.removeFromSuperlayer(); panePicture = nil; paneSharp = nil; panePictureBase = base
        guard let picture else { return }
        widthCover.wantsLayer = true
        let image = CALayer(); image.contents = picture.soft; image.masksToBounds = true
        widthCover.layer?.addSublayer(image); panePicture = image
        if closing { let sharp = CALayer(); sharp.contents = picture.sharp; image.addSublayer(sharp); paneSharp = sharp }
        layoutPanePicture()
    }
    private func layoutPanePicture() {
        panePicture?.frame = CGRect(x:panePictureBase,y:0,width:max(0,widthCover.bounds.width-panePictureBase),height:max(0,widthCover.bounds.height-78))
        paneSharp?.frame = panePicture?.bounds ?? .zero
        paneSharp?.opacity = Float(1-widthCover.alphaValue)
    }
    var hasPanePicture: Bool { panePicture?.contents != nil }
    func endWidthCover(){widthCover.removeFromSuperview();widthCover.image=nil;panePicture?.removeFromSuperlayer();panePicture=nil;paneSharp=nil}
    func captureGenie() {
        let layoutSpan = ThreeTapDiagnostics.startSpan()
        conversation.isHidden = false; conversation.layoutSubtreeIfNeeded()
        ThreeTapDiagnostics.endSpan("capture_layout", layoutSpan)
        if let rep = conversation.bitmapImageRepForCachingDisplay(in: conversation.bounds) {
            let displaySpan = ThreeTapDiagnostics.startSpan()
            conversation.cacheDisplay(in: conversation.bounds, to: rep)
            ThreeTapDiagnostics.endSpan("capture_display", displaySpan)
            let size=conversation.bounds.size
            if let graphics=NSGraphicsContext(bitmapImageRep:rep){
                NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=graphics
                let c=graphics.cgContext;c.scaleBy(x:CGFloat(rep.pixelsWide)/size.width,y:CGFloat(rep.pixelsHigh)/size.height)
                c.setBlendMode(.destinationOver);c.setFillColor((effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(white:0.09,alpha:1):NSColor(white:0.94,alpha:1)).cgColor);c.fill(CGRect(origin:.zero,size:size));c.setBlendMode(.normal)
                c.addRect(CGRect(origin:.zero,size:size));c.addPath(CGPath(roundedRect:CGRect(origin:.zero,size:size),cornerWidth:20,cornerHeight:20,transform:nil));c.clip(using:.evenOdd);c.clear(CGRect(origin:.zero,size:size));NSGraphicsContext.restoreGraphicsState()
            }
            let image=NSImage(size:size);image.addRepresentation(rep);genie.image=image
            if let captured=rep.cgImage {
                let blurSpan = ThreeTapDiagnostics.startSpan()
                genie.blurredImage=Self.blurred(captured,width:size.width)
                ThreeTapDiagnostics.endSpan("capture_blur", blurSpan)
            }
        }
        conversation.isHidden = true; genie.isHidden = false
    }
    func updateGenie(_ p: PetPlacement, progress: CGFloat) {
        genie.rect = p.bubbleRect
        let foot = PetLayout.visibleSprite(in: p.spriteRect)
        genie.target = CGPoint(x: min(max(foot.midX, p.bubbleRect.minX), p.bubbleRect.maxX), y: p.bubbleBelow ? p.bubbleRect.maxY : p.bubbleRect.minY)
        genie.below = p.bubbleBelow; genie.progress = progress; genie.updateStrips()
    }
    private static let imageContext=CIContext(options:[.cacheIntermediates:false])
    static func blurred(_ image:CGImage,width:CGFloat)->CGImage? {
        let scale=min(1,max(1,width)*0.5/CGFloat(image.width))
        let input=CIImage(cgImage:image).transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        let radius=12*CGFloat(image.width)/max(1,width)*scale
        let soft=input.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:radius]).cropped(to:input.extent)
        return imageContext.createCGImage(soft,from:input.extent)
    }
    func endGenie(expanded: Bool) { genie.clearStrips(); genie.image = nil;genie.blurredImage=nil; genie.isHidden = true; conversation.isHidden = !expanded }
}

private final class PetWidthCoverView:NSImageView {override func hitTest(_ point:NSPoint)->NSView?{nil}}
