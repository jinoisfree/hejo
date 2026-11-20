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
    static let drawerWidth: CGFloat = 290
    static let drawerDuration: TimeInterval = 0.25
    private var drawerSlideActive = false
    private(set) var drawerOpen = false
    private var onDrawerStateChanged: ((Bool,Bool)->Void)?
    func toggleDrawer(){setDrawerOpen(!drawerOpen)}
    func setDrawerOpen(_ open:Bool) {
        guard drawerOpen != open else{return}
        drawerOpen=open
        try? store.update{$0.todoDrawerOpen=open}
        pet.drawerOpen=open
        onDrawerStateChanged?(open,chatExpanded)
        guard let target=placementTarget else{return}
        drawerSlideActive=chatExpanded && !reducedMotion()
        if drawerSlideActive {bubbleMotion.slideWidth(now:clock(),duration:Self.drawerDuration)}
        placePet(at:target.anchorOrigin)
    }
    @MainActor func installDrawer(_ view:ConversationView) {
        pet.installDrawer(view.todoDrawer)
        view.onToggleDrawer={ [weak self] in self?.toggleDrawer() }
        onDrawerStateChanged={ [weak view] open,expanded in view?.setDrawerState(open:open,chatExpanded:expanded) }
        view.setDrawerState(open:drawerOpen,chatExpanded:chatExpanded)
    }
    private(set) var chatExpanded = false
    private(set) var placementTarget: PetPlacement?
    private(set) var transitionProgress: CGFloat = 0
    private(set) var transitionSteps = 0
    private(set) var transitionOpenRect = CGRect.zero
    static let defaultChatSize = CGSize(width: PetLayout.expandedSize.width + ConversationSidebar.width, height: PetLayout.expandedSize.height)
    var preferredChatSize = defaultChatSize
    var fittedThreadHeight: CGFloat?
    private(set) var web: WebPaneModel?
    private var savedPaneWidth: CGFloat?, savedPaneHeight: CGFloat?
    private var paneAnchor: CGPoint?, paneBelow: Bool?
    private var paneWasOpen = false
    private var paneBase: CGFloat = 0
    private var paneTargetWidth: CGFloat = 0
    func installWeb(_ model: WebPaneModel) {
        web = model; pet.installWeb(WebPaneView(web: model))
        model.onLayout = { [weak self] in self?.webChanged() }
        model.onWindowDragBegan = { [weak self] in self?.beginChatDrag(at: $0) }
        model.onWindowDragChanged = { [weak self] in self?.moveChatDrag(to: $0) }
        model.onWindowDragEnded = { [weak self] in self?.endChatDrag() }
    }
    var paneFits: Bool {
        guard let p = placementTarget else { return false }
        let screen = PetDisplay.nearest(to: p.globalSprite.origin, in: displays())
        return PetLayout.paneSplit(base: preferredChatSize.width, minimumBase: PetLayout.minimumChatSize.width + ConversationSidebar.width,
                                  wanted: savedPaneWidth ?? PetLayout.defaultPaneWidth, available: screen.visible.width - 24).pane >= PetLayout.usablePaneWidth
    }
    func showBeside(_ file: URL) -> Bool {
        guard chatExpanded, WebAddress.showsFile(file), paneFits, let web else { return false }
        web.open(file, ephemeral: true); return true
    }
    func openWebLink(_ url: URL, command: Bool = NSEvent.modifierFlags.contains(.command)) {
        guard CardText.mayOpen(url) else { return }
        guard WebAddress.isWeb(url), !command, paneFits, let web else { web?.onExternal(url); return }
        // A folded bubble finishes its genie transition before opening a new pane.
        if !chatExpanded { showChat() }
        func settled() {
            if self.timer != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { settled() }; return }
            web.open(url)
        }
        settled()
    }
    private func webChanged() {
        guard let web else { return }
        if web.open && !paneWasOpen { paneAnchor = placementTarget?.anchorOrigin; paneBelow = resizedBelow }
        let anchor = paneAnchor ?? placementTarget?.anchorOrigin
        if !web.open && paneWasOpen { resizedBelow = paneBelow; paneAnchor = nil; paneBelow = nil }
        paneWasOpen = web.open
        guard chatExpanded, let anchor else { if !web.open { web.unload() }; return }
        let animated = timer == nil && !reducedMotion()
        web.sliding = animated
        if animated {
            onReadingResizeBegan?(); pet.beginWidthCover()
            if web.open { web.current?.revealPreview = web.current?.picture }
            pet.setPanePicture(web.current?.picture, base: paneBase, closing: !web.open)
            if !web.open, web.current?.picture == nil, let tab = web.current {
                tab.allowsPicture = { true }
                tab.onPicture = { [weak self] picture in guard let self, self.web?.sliding == true, self.web?.open == false else { return }; self.pet.setPanePicture(picture, base: self.paneBase, closing: true) }
                DispatchQueue.main.async { tab.takePicture() }
            }
            bubbleMotion.slideWidth(now: clock()); widthFadeStart = nil
        }
        placePet(at: anchor)
        if !animated { finishPaneTransition() }
    }
    private func finishPaneTransition() {
        guard let web else { return }
        web.sliding = false; pet.paneSliding = false; pet.paneWidth = paneTargetWidth
        web.width = paneTargetWidth; if paneTargetWidth > 0 { web.layoutWidth = paneTargetWidth }
        web.finishTransition(); if !web.open { web.unload() }; pet.arrange(pet.placement ?? placementTarget!)
    }
    func resizePane(to width: CGFloat) { savedPaneWidth = max(PetLayout.minimumPaneWidth, width); if let p = placementTarget { placePet(at: p.anchorOrigin) } }
    func resetPaneSize() { savedPaneWidth = nil; savedPaneHeight = nil; if let p = placementTarget { placePet(at: p.anchorOrigin) }; savePaneSize() }
    private func savePaneSize() { try? store.update { $0.webPaneWidth = savedPaneWidth.map(Double.init); $0.webPaneHeight = savedPaneHeight.map(Double.init) } }

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
        drawerOpen=store.settings.todoDrawerOpen ?? false;pet.drawerOpen=drawerOpen
        panel.onCloseDrawer={ [weak self] in guard let self,self.drawerOpen else{return false};self.setDrawerOpen(false);return true }
        if let width=store.settings.webPaneWidth, width.isFinite, width>=Double(PetLayout.minimumPaneWidth) {savedPaneWidth=CGFloat(width)}
        if let height=store.settings.webPaneHeight, height.isFinite, height>=Double(PetLayout.minimumChatSize.height) {savedPaneHeight=CGFloat(height)}
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = pet; panel.onCollapse = { [weak self] in self?.collapseChat() }
        pet.onBubbleSize = { [weak self] in guard let self,let origin=self.placementTarget?.anchorOrigin else{return};self.placePet(at:origin) }
        pet.onCloseDrawer={ [weak self] in self?.setDrawerOpen(false) }
        pet.onResetPaneSize = { [weak self] in self?.resetPaneSize() }
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
        guard expanded || canCollapse(), web?.presenting != true else{return}
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
        onDrawerStateChanged?(drawerOpen,expanded)
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
        guard chatExpanded,event.type == .leftMouseDown,event.clickCount>=2,let window=event.window,window !== panel,canCollapse(), web?.presenting != true else{return}
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
        let base=PetPlacement(globalSprite:drag.placement.globalSprite,globalBubble:drag.placement.contentBubble,userScale:pet.petScale,expanded:true)
        let p=base.dragged(by:CGPoint(x:point.x-drag.point.x,y:point.y-drag.point.y),visibleFrame:screen.visible,screenFrame:screen.frame).withLeading(drawerOpen ? Self.drawerWidth:0,visibleFrame:screen.visible)
        placementTarget=p;resizedBelow=p.bubbleBelow
        bubbleMotion.retarget(p.globalBubble.origin,visibleFrame:screen.visible,now:clock(),immediately:true,size:p.globalBubble.size,headerAtTop:p.expanded && p.bubbleBelow)
        apply(p)
    }
    func endChatDrag(){guard chatDrag != nil else{return};chatDrag=nil;if drawerOpen,let p=placementTarget {placePet(at:p.anchorOrigin)};endPetDrag()}
    func placePet(at origin: CGPoint) {
        guard chatDrag==nil else{return}
        let sprite = CGRect(origin: origin, size: PetLayout(scale: pet.petScale).spriteSize)
        let foot = PetLayout.visibleSprite(in: sprite)
        let screen = PetDisplay.nearest(to: CGPoint(x: foot.midX, y: foot.minY), in: displays())
        var size = preferredChatSize
        if chatExpanded {size.height=max(size.height,fittedThreadHeight ?? 0)}
        let wanted = chatExpanded && web?.open == true ? savedPaneWidth ?? PetLayout.defaultPaneWidth : 0
        let split = PetLayout.paneSplit(base: size.width, minimumBase: PetLayout.minimumChatSize.width + ConversationSidebar.width, wanted: wanted, available: screen.visible.width - 24)
        size.width = split.base
        size.height = PetLayout.paneHeight(base: size.height, open: wanted > 0, saved: savedPaneHeight)
        paneBase = split.base; paneTargetWidth = split.pane
        if web?.sliding == true { pet.paneSliding = true }
        else { pet.paneWidth = split.pane; web?.width = split.pane; if split.pane > 0 { web?.layoutWidth = split.pane } }
        let target = PetPlacement(spriteOrigin: origin, scale: pet.petScale, visibleFrame: screen.visible, screenFrame: screen.frame,
                                  bubbleSize: pet.foldedSize, expanded: chatExpanded, preferredSize: size, below: resizedBelow, trailing: split.pane, expandToFit: wanted > 0, leading: drawerOpen ? Self.drawerWidth:0)
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
            if pet.widthCoverVisible {finishPaneTransition();pet.endWidthCover();onReadingResizeEnded?()}
        }
        let point=bubbleMotion.step(now:clock()),size=bubbleMotion.size
        let shownLeading=chatExpanded ? (drawerSlideActive ? max(0,size.width-(target.globalBubble.width-target.leading)):target.leading):0
        let p=PetPlacement(globalSprite:target.globalSprite,globalBubble:CGRect(origin:point,size:size),userScale:pet.petScale,expanded:chatExpanded,leading:shownLeading,drawerOverlay:target.drawerOverlay)
        apply(p)
        if bubbleMotion.widthProgress>=1 {drawerSlideActive=false}
        if pet.widthCoverVisible {
            if bubbleMotion.widthProgress<1 {widthFadeStart=nil;pet.setWidthCover(alpha:ChatWidthSlide.cover(bubbleMotion.widthProgress))}
            else {if web?.sliding == true {finishPaneTransition()};let start=widthFadeStart ?? clock();widthFadeStart=start;let fade=min(1,max(0,(clock()-start)/ChatWidthSlide.fadeDuration));pet.setWidthCover(alpha:1-CGFloat(fade));if fade>=1 {pet.endWidthCover();onReadingResizeEnded?()}}
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
        if web?.open == true { paneAnchor = placementTarget?.anchorOrigin }
    }
    func endPetDrag() {
        if resizeStart != nil {onReadingResizeEnded?()}
        petDragBottom = nil; resizeStart = nil
        guard let p = placementTarget else { return }
        try? store.update { $0.petX = Double(p.anchorOrigin.x); $0.petY = Double(p.anchorOrigin.y) }
        saveChatSize(); savePaneSize()
    }
    private func resize(edge: PetLayout.ResizeEdge, delta: CGPoint) {
        if web?.open == true, edge.contains(.right), let p = placementTarget {
            if resizeStart == nil { resizeStart = p }
            resizePane(to: max(PetLayout.minimumPaneWidth, resizeStart!.contentBubble.width - paneBase + delta.x)); return
        }
        if resizeStart == nil {resizeStart=placementTarget;onReadingResizeBegan?();}
        guard let start = resizeStart else { return }
        let screen = PetDisplay.nearest(to: CGPoint(x: start.globalSprite.midX, y: start.globalSprite.midY), in: displays())
        let chatStart=PetPlacement(globalSprite:start.globalSprite,globalBubble:start.contentBubble,userScale:pet.petScale,expanded:true)
        let resized = PetLayout.resized(chatStart, edge: edge, delta: delta, screen: screen.visible, trailing: pet.paneWidth, screenFrame: screen.frame)
        if web?.open == true {savedPaneHeight = resized.height; preferredChatSize.width = resized.width}
        else { preferredChatSize = resized }
        fittedThreadHeight = nil
        resizedBelow = start.bubbleBelow
        let effective = CGSize(width:preferredChatSize.width,height:web?.open == true ? savedPaneHeight ?? preferredChatSize.height:preferredChatSize.height)
        placePet(at: PetLayout.resizedSpriteOrigin(start, edge: edge, size: effective))
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
