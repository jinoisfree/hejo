import AppKit
import CoreGraphics

struct PetDisplay {
    let frame: CGRect
    let visible: CGRect
    static var current: [PetDisplay] { NSScreen.screens.map { PetDisplay(frame: $0.frame, visible: $0.visibleFrame) } }
    static func nearest(to point: CGPoint, in displays: [PetDisplay]) -> PetDisplay {
        displays.min { distance(point, $0.frame) < distance(point, $1.frame) } ?? PetDisplay(frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visible: CGRect(x: 0, y: 0, width: 1000, height: 780))
    }
    private static func distance(_ p: CGPoint, _ r: CGRect) -> CGFloat {
        pow(max(r.minX-p.x, 0, p.x-r.maxX), 2) + pow(max(r.minY-p.y, 0, p.y-r.maxY), 2)
    }
}
/// Owns one panel. All placements derive from the sprite's foot, including screen changes.
final class PetController: NSObject {
    let panel: PetPanel
    let pet: PetView
    let store: LocalStore
    var displays: () -> [PetDisplay] = { PetDisplay.current }
    var reducedMotion: () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var canCollapse:()->Bool = {true}
    var onExpansionChanged: ((Bool) -> Void)?
    private(set) var chatExpanded = false
    private(set) var placementTarget: PetPlacement?
    private(set) var transitionProgress: CGFloat = 0
    private(set) var transitionSteps = 0
    private(set) var transitionOpenRect = CGRect.zero
    static let defaultChatSize = CGSize(width: PetLayout.expandedSize.width + ConversationSidebar.width, height: PetLayout.expandedSize.height)
    var preferredChatSize = defaultChatSize
    var fittedThreadHeight: CGFloat?
    var screenAwake: () -> Bool = {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        return !(session?["CGSSessionScreenIsLocked"] as? Bool ?? false) && CGDisplayIsAsleep(CGMainDisplayID()) == 0
    }
    private(set) var previewTimer: Timer?
    static let previewNames = PetAnimation.allCases.map(\.name) + ["방향 보기 1", "방향 보기 2", "조는 중"]
    func preview() { previewTimer?.invalidate(); pet.previewLook = false; previewStep(0) }
    func previewStep(_ row: Int) {
        guard row < Self.previewNames.count else { pet.previewRow = nil; pet.updateFoldedBubble(); return }
        pet.previewRow = row; pet.updateFoldedBubble()
        let seconds = row == PetAnimationTimeline.dozeRow ? PetAnimationTimeline.dozeCycle : 2
        previewTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.previewStep(row+1) }
    }
    func previewPointer() {
        previewTimer?.invalidate(); pet.previewRow = nil; pet.previewLook = true; pet.updateFoldedBubble()
        previewTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in self?.finishPreview() }
    }
    func finishPreview() { previewTimer?.invalidate(); previewTimer = nil; pet.previewRow = nil; pet.previewLook = false; pet.updateFoldedBubble() }
    private var appearanceObserver: NSObjectProtocol?
    private var timer: Timer?,motionTimer:Timer?
    private var bubbleMotion=PetBubbleMotion()
    private var widthFadeStart:Double?
    private var transitionStart:Double=0,genieStart:CGFloat=0
    private var foldedPerchAnchor:CGPoint?
    private var chatDrag:(point:CGPoint,placement:PetPlacement)?
    var onFocus:(()->Void)?
    private var outsideMonitor:Any?
    var clock:()->Double={ProcessInfo.processInfo.systemUptime}
    var onReadingResizeBegan:(()->Void)?,onReadingResizeEnded:(()->Void)?
    var shownChatHeight:CGFloat? { guard let target=placementTarget,abs(bubbleMotion.size.height-target.globalBubble.height)>0.2 else{return nil};return bubbleMotion.size.height }

    private var petDragBottom: CGFloat?
    private var resizedBelow: Bool?
    private var resizeStart: PetPlacement?
    init(store: LocalStore, atlas: SpriteAtlas) {
        self.store = store; pet = PetView(atlas: atlas)
        if let width = store.settings.chatWidth, let height = store.settings.chatHeight,
           width.isFinite, height.isFinite, width >= Double(PetLayout.minimumChatSize.width),
           height >= Double(PetLayout.minimumChatSize.height), width < 16384, height < 16384 {
            preferredChatSize = CGSize(width: width, height: height)
        }
        pet.petScale = CGFloat(min(200, max(25, store.settings.petScalePercent ?? 100))) / 100
        pet.bubbleAlwaysShown = store.settings.bubbleAlwaysShown ?? false
        pet.bubbleName = store.settings.petName
        panel = PetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = pet; panel.onCollapse = { [weak self] in self?.collapseChat() }
        pet.onBubbleSize = { [weak self] in guard let self,let origin=self.placementTarget?.anchorOrigin else{return};self.placePet(at:origin) }
        pet.onClick = { [weak self] in self?.toggle() };pet.onResetSize={ [weak self] in self?.resetChatSize() }
        pet.onDragMove = { [weak self] in self?.movePet(to: $0) }
        pet.onDragEnded = { [weak self] in self?.endPetDrag() }
        pet.onResize = { [weak self] edge, delta in self?.resize(edge: edge, delta: delta) }
        pet.collapseButton.target = self; pet.collapseButton.action = #selector(collapseChat)
        pet.reduceMotion = { [weak self] in self?.reducedMotion() ?? true }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(motionChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(powerChanged), name: name, object: nil)
        }
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(powerChanged), name: Notification.Name(name), object: nil)
        }
        pet.animationsAllowed = screenAwake()
        let screen = displays().first ?? PetDisplay.nearest(to: .zero, in: [])
        placePet(at: CGPoint(x: store.settings.petX ?? Double(screen.visible.maxX-PetLayout(scale:pet.petScale).spriteSize.width-30), y: store.settings.petY ?? Double(screen.visible.minY+25)))
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){[weak self] _ in MainActor.assumeIsolated {self?.applyChatAppearance()} }
        applyChatAppearance()
    }
    func applyChatAppearance(){panel.appearance=ChatAppearance.theme.appearance;pet.chatOpacityPercent=ChatAppearance.opacity;MainActor.assumeIsolated {pet.bubbleReply?.applyChatAppearance()}}
    deinit { if let appearanceObserver {NotificationCenter.default.removeObserver(appearanceObserver)};previewTimer?.invalidate(); if let outsideMonitor {NSEvent.removeMonitor(outsideMonitor)};motionTimer?.invalidate();timer?.invalidate(); NotificationCenter.default.removeObserver(self); NSWorkspace.shared.notificationCenter.removeObserver(self); DistributedNotificationCenter.default().removeObserver(self) }
    func show() { panel.orderFrontRegardless() }
    @objc func toggle() { if chatExpanded { collapseChat() } else { showChat() } }
    func threeFingerTapped() {
        guard panel.isVisible, !pet.isPaused else { return }
        pet.onClick?()
    }
    @objc func showChat() { setExpanded(true) }
    @objc func collapseChat() { setExpanded(false) }
    private func setExpanded(_ expanded: Bool) {
        guard expanded || canCollapse() else{return}
        guard expanded != chatExpanded,let old=placementTarget else{return}
        let continuing=timer != nil && !pet.genie.isHidden
        let start=continuing ? transitionProgress:(expanded ? 0:1)
        timer?.invalidate();timer=nil
        bubbleMotion.glide(now:clock())
        let reopeningAnchor=expanded ? foldedPerchAnchor:nil
        if expanded {
            if reopeningAnchor != nil {resizedBelow=true}
            foldedPerchAnchor=nil
        } else {
            foldedPerchAnchor=old.globalSprite.width < pet.petScale*192 ? old.anchorOrigin:nil
            pet.disarmBubbleHover();resizedBelow=nil
        }
        chatExpanded=expanded;panel.chatExpanded=expanded
        // Capture the closing picture before folding the model, or keep the current picture on reversal.
        if !expanded && !continuing {pet.captureGenie()}
        onExpansionChanged?(expanded)
        placePet(at:reopeningAnchor ?? old.anchorOrigin)
        guard let target=placementTarget else{return}
        let open=expanded ? target:old
        transitionOpenRect=open.globalBubble;transitionSteps=0;transitionProgress=start
        if expanded {panel.makeKeyAndOrderFront(nil)}
        else {panel.makeFirstResponder(nil);panel.resignKey()}
        if let outsideMonitor {NSEvent.removeMonitor(outsideMonitor);self.outsideMonitor=nil}
        if expanded {outsideMonitor=NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown]){[weak self] event in self?.handleOutsideClick(event);return event}}
        if reducedMotion() {transitionProgress=expanded ? 1:0;pet.endGenie(expanded:expanded);apply(target);if expanded {onFocus?()};return}
        apply(open)
        if !continuing && expanded {pet.captureGenie()}
        pet.updateGenie(open,progress:start)
        transitionStart=clock();genieStart=start
        let t=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.stepTransition()}
        timer=t;RunLoop.main.add(t,forMode:.common);show()
    }
    func stepTransition(){
        let fraction=min(1,max(0,(clock()-transitionStart)/ChatMorph.genieDuration))
        transitionProgress=ChatMorph.genieProgress(from:genieStart,opening:chatExpanded,fraction:fraction);transitionSteps+=1
        if let p=pet.placement {pet.updateGenie(p,progress:transitionProgress)}
        if fraction>=1 {
            timer?.invalidate();timer=nil;pet.endGenie(expanded:chatExpanded)
            if let target=placementTarget {
                let screen=PetDisplay.nearest(to:CGPoint(x:target.globalSprite.midX,y:target.globalSprite.midY),in:displays())
                bubbleMotion.retarget(target.globalBubble.origin,visibleFrame:screen.visible,now:clock(),immediately:true,size:target.globalBubble.size,headerAtTop:target.expanded && target.bubbleBelow)
                apply(target)
            }
            if chatExpanded {onFocus?()}
        }
    }
    func handleOutsideClick(_ event:NSEvent){
        guard chatExpanded,event.type == .leftMouseDown,event.clickCount>=2,let window=event.window,window !== panel,canCollapse() else{return}
        collapseChat()
    }
    func beginChatDrag(at point:CGPoint){
        guard chatExpanded,let target=placementTarget,chatDrag==nil else{return}
        timer?.invalidate();timer=nil;pet.endGenie(expanded:true);apply(target)
        chatDrag=(point,target);resizedBelow=target.bubbleBelow
    }
    func moveChatDrag(to point:CGPoint){
        guard let drag=chatDrag else{return}
        let screen=PetDisplay.nearest(to:point,in:displays())
        let p=drag.placement.dragged(by:CGPoint(x:point.x-drag.point.x,y:point.y-drag.point.y),visibleFrame:screen.visible,screenFrame:screen.frame)
        placementTarget=p;resizedBelow=p.bubbleBelow
        bubbleMotion.retarget(p.globalBubble.origin,visibleFrame:screen.visible,now:clock(),immediately:true,size:p.globalBubble.size,headerAtTop:p.expanded && p.bubbleBelow)
        apply(p)
    }
    func endChatDrag(){guard chatDrag != nil else{return};chatDrag=nil;endPetDrag()}
    func placePet(at origin: CGPoint) {
        guard chatDrag==nil else{return}
        let sprite = CGRect(origin: origin, size: PetLayout(scale: pet.petScale).spriteSize)
        let foot = PetLayout.visibleSprite(in: sprite)
        let screen = PetDisplay.nearest(to: CGPoint(x: foot.midX, y: foot.minY), in: displays())
        var size = preferredChatSize
        if chatExpanded {size.height=max(size.height,fittedThreadHeight ?? 0)}
        let target = PetPlacement(spriteOrigin: origin, scale: pet.petScale, visibleFrame: screen.visible, screenFrame: screen.frame,
                                  bubbleSize: pet.foldedSize, expanded: chatExpanded, preferredSize: size, below: resizedBelow)
        placementTarget = target
        bubbleMotion.retarget(target.globalBubble.origin,visibleFrame:screen.visible,now:clock(),immediately:pet.placement==nil || reducedMotion() || resizeStart != nil,size:target.globalBubble.size,headerAtTop:target.expanded && target.bubbleBelow)
        if timer==nil {stepPlacement()}
        if motionTimer==nil {let t=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.stepPlacement()};motionTimer=t;RunLoop.main.add(t,forMode:.common)}
    }
    func stepPlacement(){
        guard let target=placementTarget,timer==nil else{return}
        if reducedMotion(){
            let screen=PetDisplay.nearest(to:CGPoint(x:target.globalSprite.midX,y:target.globalSprite.midY),in:displays())
            bubbleMotion.retarget(target.globalBubble.origin,visibleFrame:screen.visible,now:clock(),immediately:true,size:target.globalBubble.size,headerAtTop:target.expanded && target.bubbleBelow)
            if pet.widthCoverVisible {pet.endWidthCover();onReadingResizeEnded?()}
        }
        let point=bubbleMotion.step(now:clock()),size=bubbleMotion.size
        let p=PetPlacement(globalSprite:target.globalSprite,globalBubble:CGRect(origin:point,size:size),userScale:pet.petScale,expanded:chatExpanded)
        apply(p)
        if pet.widthCoverVisible {
            if bubbleMotion.widthProgress<1 {widthFadeStart=nil;pet.setWidthCover(alpha:ChatWidthSlide.cover(bubbleMotion.widthProgress))}
            else {let start=widthFadeStart ?? clock();widthFadeStart=start;let fade=min(1,max(0,(clock()-start)/ChatWidthSlide.fadeDuration));pet.setWidthCover(alpha:1-CGFloat(fade));if fade>=1 {pet.endWidthCover();onReadingResizeEnded?()}}
        }
        if point==target.globalBubble.origin && size==target.globalBubble.size && !pet.widthCoverVisible {motionTimer?.invalidate();motionTimer=nil}
    }
    private func apply(_ p: PetPlacement) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        panel.setFrame(p.windowFrame, display: false); pet.arrange(p)
        let screen=PetDisplay.nearest(to:CGPoint(x:p.globalSprite.midX,y:p.globalSprite.midY),in:displays())
        panel.level=PetLayout.placementSprite(in:p.globalSprite).maxY>screen.visible.maxY ? NSWindow.Level(rawValue:NSWindow.Level.mainMenu.rawValue+1):.floating
        CATransaction.commit()
    }
    func movePet(to origin: CGPoint) {
        timer?.invalidate(); timer = nil; pet.endGenie(expanded: chatExpanded)
        if chatExpanded, petDragBottom == nil, let target = placementTarget, target.bubbleBelow { petDragBottom = target.globalBubble.minY }
        let cell = CGRect(origin: origin, size: PetLayout(scale: pet.petScale).spriteSize)
        let foot = PetLayout.visibleSprite(in: cell)
        let screen = PetDisplay.nearest(to: CGPoint(x: foot.midX, y: foot.minY), in: displays())
        if let bottom = petDragBottom {
            preferredChatSize.height = PetLayout.carriedChatHeight(foot: foot.minY, bottom: bottom, visibleFrame: screen.visible, screenFrame: screen.frame)
            resizedBelow = true
        }
        placePet(at: origin)
    }
    func endPetDrag() {
        if resizeStart != nil {onReadingResizeEnded?()}
        petDragBottom = nil; resizeStart = nil
        guard let p = placementTarget else { return }
        try? store.update { $0.petX = Double(p.anchorOrigin.x); $0.petY = Double(p.anchorOrigin.y) }
        saveChatSize()
    }
    private func resize(edge: PetLayout.ResizeEdge, delta: CGPoint) {
        if resizeStart == nil {resizeStart=placementTarget;onReadingResizeBegan?();}
        guard let start = resizeStart else { return }
        let screen = PetDisplay.nearest(to: CGPoint(x: start.globalSprite.midX, y: start.globalSprite.midY), in: displays())
        preferredChatSize = PetLayout.resized(start, edge: edge, delta: delta, screen: screen.visible, screenFrame: screen.frame)
        fittedThreadHeight = nil
        resizedBelow = start.bubbleBelow
        placePet(at: PetLayout.resizedSpriteOrigin(start, edge: edge, size: preferredChatSize))
    }
    @objc func screensChanged() {
        timer?.invalidate(); timer = nil; pet.endGenie(expanded: chatExpanded)
        foldedPerchAnchor=nil;resizedBelow=nil;chatDrag=nil
        if let p = placementTarget { placePet(at: p.anchorOrigin) }
    }
    @objc private func motionChanged() {pet.updateScrim(); if reducedMotion() { screensChanged() } }
    @objc private func powerChanged() { pet.animationsAllowed = screenAwake() }
    func saveChatSize() {
        let size = preferredChatSize
        try? store.update { $0.chatWidth = Double(size.width); $0.chatHeight = Double(size.height) }
    }
    func toggleChatWidth() {
        let wide = PetLayout.expandedSize.width * 2 + ConversationSidebar.width
        let animated=chatExpanded && timer==nil && !reducedMotion()
        if animated {onReadingResizeBegan?();pet.beginWidthCover();bubbleMotion.slideWidth(now:clock());widthFadeStart=nil}
        preferredChatSize.width = abs(preferredChatSize.width - wide) < 1 ? Self.defaultChatSize.width : wide
        saveChatSize()
        if let origin = placementTarget?.anchorOrigin { placePet(at: origin) }
    }
    func resetChatSize() {
        preferredChatSize = Self.defaultChatSize; fittedThreadHeight = nil; saveChatSize()
        if let origin = placementTarget?.anchorOrigin { placePet(at: origin) }
    }
    func fitOpenThread(_ height:CGFloat?){
        let next=height.map{max(preferredChatSize.height,$0)}
        guard next != fittedThreadHeight else{return};fittedThreadHeight=next
        guard chatExpanded,resizeStart==nil,let origin=placementTarget?.anchorOrigin else{return}
        placePet(at:origin)
    }
    /// Size and position share the original PetBubbleMotion follower; no second height easing pass.
    func stepChatHeight(){stepPlacement()}
    func resetPosition() {
        let screen = displays().first ?? PetDisplay.nearest(to: .zero, in: [])
        placePet(at: CGPoint(x: screen.visible.maxX - PetLayout(scale: pet.petScale).spriteSize.width - 30,
                             y: screen.visible.minY + 25))
        endPetDrag()
    }
    func resizePet(percent: Double) {
        let sprite = placementTarget?.globalSprite
        pet.petScale = CGFloat(min(200, max(25, percent))) / 100
        if let sprite { placePet(at: PetLayout.resizedSprite(sprite, scale: pet.petScale).origin); endPetDrag() }
    }
}
