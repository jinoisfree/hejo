import AppKit

final class PetPanel: NSPanel {
    var chatExpanded = false
    var onCollapse: (() -> Void)?
    var onWorkspaceKey:((NSEvent)->Bool)?
    override var canBecomeKey: Bool { chatExpanded }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override func cancelOperation(_ sender: Any?) { onCollapse?() }
    override func sendEvent(_ event: NSEvent) {
        if chatExpanded,event.type == .keyDown,onWorkspaceKey?(event)==true {return}
        if event.type == .keyDown, event.keyCode == 53 { onCollapse?(); return }
        // Only an actual text input click may request key focus. Opening the pet never does.
        if event.type == .leftMouseDown, chatExpanded,
           let hit = contentView?.hitTest(event.locationInWindow), (hit as? NSTextView)?.isEditable == true || (hit as? NSTextField)?.isEditable == true {
            makeKey()
        }
        super.sendEvent(event)
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
        didSet {bubbleTarget=bubbleNotice.key;updateFoldedBubble();if bubbleNotice.actions.count != oldValue.actions.count {onBubbleSize?()}}
    }
    var foldedSize:CGSize {CGSize(width:231,height:bubbleNotice.actions.isEmpty ? 56:90)}
    var onBubbleSize:(()->Void)?
    private var bubbleHover=false,bubbleViewHover=false
    var onBubbleOpen:((ConversationKey?)->Void)?
    var onBubbleAction:((BubbleReveal.Action)->Void)?
    var activityNow:()->TimeInterval={ProcessInfo.processInfo.systemUptime}
    private var activity=PetActivity(now:ProcessInfo.processInfo.systemUptime)
    private var replyJump=false,playback=PetChatPlayback()
    private(set) var jumpElapsed:TimeInterval?
    let thoughtDots=(0..<3).map{_ in PetThoughtView()}
    var hasAsked=false,isTyping=false,sendFailed=false,isPaused=false
    var animationsAllowed=true {didSet{updateAnimationVisibility()}}
    private(set) var activityPose:PetActivity.Pose = .idle
    func noteActivity(){activity.touch(now:activityNow())}
    func noteSend(){activity.sent(now:activityNow())}
    func requestReplyJump(){replyJump=true;noteActivity()}
    func updateFoldedBubble(){
        let notice=bubbleNotice
        let alive=notice.until.map{Date(timeIntervalSince1970:bubbleNow())<$0} ?? false
        let shown=placement?.expanded != true && (notice.held || alive || bubbleHover || bubbleAlwaysShown)
        foldedBubble.isHidden = !shown
        foldedBubble.headline=notice.headline.isEmpty ? bubbleName:notice.headline
        foldedBubble.detail=notice.kind == .idle ? bubbleStatus:notice.detail
        foldedBubble.sender=notice.sender;foldedBubble.avatar=notice.sender.isEmpty ? nil:notice.key.flatMap{avatarForEmployee?($0.employee)}
        foldedBubble.kind=notice.kind;foldedBubble.unread=unreadCount;foldedBubble.actions=notice.actions
        foldedBubble.tick(at:activityNow(),paused:isPaused || !animationsAllowed)
        foldedBubble.setAccessibilityLabel(foldedBubble.headline+" · "+foldedBubble.detail+" · 대화 열기")
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
    private var press: CGPoint?
    private var anchor = CGPoint.zero
    private var edge: PetLayout.ResizeEdge = []
    private(set) var didDrag = false
    private var timer: Timer?
    private var pointer = PetPointerInteraction()
    private var pose = PetAnimationFrame(row: 0, column: 0)
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
        foldedBubble.onHover = { [weak self] hovering in self?.bubbleViewHover = hovering; if hovering {self?.bubbleHover=true}; self?.updateFoldedBubble(); if hovering { self?.noteActivity() } }
        foldedBubble.reduceMotion = { [weak self] in self?.reduceMotion() ?? true }
        foldedBubble.onAction = { [weak self] in self?.onBubbleAction?($0) }
        foldedBubble.onOpen = { [weak self] in guard let self else { return }; self.noteActivity(); self.onBubbleOpen?(self.bubbleTarget) }
        genie.wantsLayer = true
        sprite.onDraw = { [weak self] cell in
            guard let self else { return }; self.atlas.draw(row: self.pose.row, frame: self.pose.column, in: cell, view: self.sprite)
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
        if isPaused {replyJump=false;jumpElapsed=playback.update(now:now,reply:false,pointerElapsed:nil,enabled:false);sprite.needsDisplay = true;return}
        let pointer = pointerLocation(), origin = window!.convertPoint(toScreen: .zero)
        let global = PetLayout.visibleSprite(in: spriteRect).offsetBy(dx: origin.x, dy: origin.y)
        let bridge=global.union(placement!.bubbleRect.offsetBy(dx:origin.x,dy:origin.y))
        bubbleHover = bubbleViewHover || global.contains(pointer) || (bubbleHover && !foldedBubble.isHidden && bridge.contains(pointer))
        updateFoldedBubble()
        let phase=self.pointer.update(pointer:pointer,sprite:global,display:window!.screen?.frame ?? global,now:now,reducedMotion:reduceMotion())
        let pointerElapsed:TimeInterval?;if case .jumping(let elapsed)=phase {pointerElapsed=elapsed} else {pointerElapsed=nil}
        jumpElapsed=playback.update(now:now,reply:replyJump,pointerElapsed:pointerElapsed,enabled:!isPaused && !hasAsked && !sendFailed && !reduceMotion())
        replyJump=false
        if let elapsed=jumpElapsed {pose=PetAnimationTimeline.frame(for:.jumping,elapsed:elapsed)} else {
        switch activityPose {
        case .phone: pose = PetAnimationTimeline.frame(for: .waiting, elapsed: now, reducedMotion: reduceMotion())
        case .laptop: pose = PetAnimationTimeline.frame(for: .replyWaiting, elapsed: now, reducedMotion: reduceMotion())
        case .wave: pose = PetAnimationTimeline.frame(for: .waving, elapsed: now, reducedMotion: reduceMotion())
        case .failure: pose = PetAnimationTimeline.frame(for: .failed, elapsed: now, reducedMotion: reduceMotion())
        case .doze: pose = PetAnimationTimeline.dozeFrame(elapsed: now - activity.lastActivity - PetActivity.idleDelay, reducedMotion: reduceMotion())
        case .idle:
            switch phase {
            case .jumping: pose=PetAnimationTimeline.frame(for:.idle,elapsed:now,reducedMotion:reduceMotion())
            case .looking: pose = reduceMotion() ? PetAnimationTimeline.frame(for: .idle, elapsed: now, reducedMotion: true) : PetAnimationTimeline.lookFrame(from: CGPoint(x: global.midX, y: global.midY), toward: pointer, previous: pose) ?? pose
            case .inactive: pose = PetAnimationTimeline.frame(for: .idle, elapsed: now, reducedMotion: reduceMotion())
            }
        }
        }
        sprite.needsDisplay = true
    }
    func updateActivityPresentation(at now: TimeInterval) {
        activityPose = activity.pose(now: now, asked: hasAsked, typing: isTyping, failed: sendFailed, paused: isPaused)
        if isPaused { pose = PetAnimationTimeline.frame(for: .idle, elapsed: now, reducedMotion: true) }
    }
    func arrange(_ p: PetPlacement) {
        placement = p; frame = CGRect(origin: .zero, size: p.windowFrame.size)
        sprite.frame = p.spriteRect; conversation.frame = p.bubbleRect; foldedBubble.frame = p.bubbleRect; genie.frame = bounds
        statusLabel.frame = CGRect(x: 20, y: max(20, p.bubbleRect.height - 80), width: max(0, p.bubbleRect.width - 40), height: 36)
        collapseButton.frame = CGRect(x: 16, y: max(0, p.bubbleRect.height - 38), width: 120, height: 28)
        glass.frame = conversation.bounds; tint.frame = conversation.bounds
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua,.aqua]) == .darkAqua
        tint.layer?.backgroundColor = (dark ? NSColor.black : .white).withAlphaComponent(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.65).cgColor
        conversationContent?.frame = CGRect(origin: .zero, size: p.bubbleRect.size)
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
        noteActivity()
        press = pointerLocation(); anchor = placement?.anchorOrigin ?? .zero; didDrag = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let press else { return }; let p = pointerLocation(); let delta = CGPoint(x: p.x - press.x, y: p.y - press.y)
        guard didDrag || hypot(delta.x, delta.y) > 4 else { return }; didDrag = true
        if edge.isEmpty { onDragMove?(CGPoint(x: anchor.x + delta.x, y: anchor.y + delta.y)) } else { onResize?(edge, delta) }
    }
    override func mouseUp(with event: NSEvent) {
        guard press != nil else { return }; press = nil
        if didDrag { onDragEnded?() } else if edge.isEmpty { onClick?() }
        edge = []
    }
    func captureGenie() {
        conversation.isHidden = false; conversation.layoutSubtreeIfNeeded()
        if let rep = conversation.bitmapImageRepForCachingDisplay(in: conversation.bounds) {
            conversation.cacheDisplay(in: conversation.bounds, to: rep)
            let image = NSImage(size: conversation.bounds.size); image.addRepresentation(rep); genie.image = image
        }
        conversation.isHidden = true; genie.isHidden = false
    }
    func updateGenie(_ p: PetPlacement, progress: CGFloat) {
        genie.rect = p.bubbleRect
        let foot = PetLayout.visibleSprite(in: p.spriteRect)
        genie.target = CGPoint(x: min(max(foot.midX, p.bubbleRect.minX), p.bubbleRect.maxX), y: p.bubbleBelow ? p.bubbleRect.maxY : p.bubbleRect.minY)
        genie.below = p.bubbleBelow; genie.progress = progress; genie.updateStrips()
    }
    func endGenie(expanded: Bool) { genie.clearStrips(); genie.image = nil; genie.isHidden = true; conversation.isHidden = !expanded }
}
