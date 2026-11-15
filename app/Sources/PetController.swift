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
    private var timer: Timer?
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
        pet.onClick = { [weak self] in self?.toggle() }
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
        placePet(at: CGPoint(x: store.settings.petX ?? Double(screen.visible.midX), y: store.settings.petY ?? Double(screen.visible.midY)))
    }
    deinit { timer?.invalidate(); NotificationCenter.default.removeObserver(self); NSWorkspace.shared.notificationCenter.removeObserver(self); DistributedNotificationCenter.default().removeObserver(self) }
    func show() { panel.orderFrontRegardless(); pet.updateAnimationVisibility() }
    @objc func toggle() { if chatExpanded { collapseChat() } else { showChat() } }
    @objc func showChat() { setExpanded(true) }
    @objc func collapseChat() { setExpanded(false) }
    private func setExpanded(_ expanded: Bool) {
        guard expanded != chatExpanded, let old = placementTarget else { return }
        timer?.invalidate(); timer = nil; pet.endGenie(expanded: chatExpanded)
        chatExpanded = expanded; panel.chatExpanded = expanded; onExpansionChanged?(expanded)
        if !expanded { panel.makeFirstResponder(nil); panel.resignKey() }
        let start = expanded ? CGFloat(0) : 1
        // Opening measures the full native content before it is captured; closing uses the current open placement.
        placePet(at: old.anchorOrigin)
        guard let target = placementTarget else { return }
        let open = expanded ? target : old
        transitionOpenRect = open.globalBubble
        transitionSteps = 0; transitionProgress = expanded ? 1 : 0
        if reducedMotion() { pet.endGenie(expanded: expanded); show(); return }
        apply(open); pet.captureGenie(); pet.updateGenie(open, progress: start)
        transitionProgress = start
        let began = ProcessInfo.processInfo.systemUptime
        let t = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let fraction = min(1, (ProcessInfo.processInfo.systemUptime-began)/ChatMorph.genieDuration)
            self.transitionProgress = ChatMorph.genieProgress(from: start, opening: expanded, fraction: fraction)
            self.transitionSteps += 1
            self.pet.updateGenie(open, progress: self.transitionProgress)
            if fraction >= 1 {
                timer.invalidate(); self.timer = nil; self.pet.endGenie(expanded: expanded)
                if let current = self.placementTarget { self.apply(current) }
            }
        }
        timer = t; RunLoop.main.add(t, forMode: .common); show()
    }
    func placePet(at origin: CGPoint) {
        let sprite = CGRect(origin: origin, size: PetLayout(scale: pet.petScale).spriteSize)
        let foot = PetLayout.visibleSprite(in: sprite)
        let screen = PetDisplay.nearest(to: CGPoint(x: foot.midX, y: foot.minY), in: displays())
        var size = preferredChatSize
        if chatExpanded, let fittedThreadHeight { size.height = max(size.height, fittedThreadHeight) }
        let target = PetPlacement(spriteOrigin: origin, scale: pet.petScale, visibleFrame: screen.visible, screenFrame: screen.frame,
                                  expanded: chatExpanded, preferredSize: size, below: resizedBelow)
        placementTarget = target; apply(target)
    }
    private func apply(_ p: PetPlacement) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        panel.setFrame(p.windowFrame, display: false); pet.arrange(p)
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
        petDragBottom = nil; resizeStart = nil
        guard let p = placementTarget else { return }
        try? store.update { $0.petX = Double(p.anchorOrigin.x); $0.petY = Double(p.anchorOrigin.y) }
        saveChatSize()
    }
    private func resize(edge: PetLayout.ResizeEdge, delta: CGPoint) {
        if resizeStart == nil { resizeStart = placementTarget }
        guard let start = resizeStart else { return }
        let screen = PetDisplay.nearest(to: CGPoint(x: start.globalSprite.midX, y: start.globalSprite.midY), in: displays())
        preferredChatSize = PetLayout.resized(start, edge: edge, delta: delta, screen: screen.visible, screenFrame: screen.frame)
        fittedThreadHeight = nil
        resizedBelow = start.bubbleBelow
        placePet(at: PetLayout.resizedSpriteOrigin(start, edge: edge, size: preferredChatSize))
    }
    @objc func screensChanged() {
        timer?.invalidate(); timer = nil; pet.endGenie(expanded: chatExpanded)
        if let p = placementTarget { placePet(at: p.anchorOrigin) }
    }
    @objc private func motionChanged() { if reducedMotion() { screensChanged() } }
    @objc private func powerChanged() { pet.animationsAllowed = screenAwake() }
    func saveChatSize() {
        let size = preferredChatSize
        try? store.update { $0.chatWidth = Double(size.width); $0.chatHeight = Double(size.height) }
    }
    func toggleChatWidth() {
        let wide = PetLayout.expandedSize.width * 2 + ConversationSidebar.width
        preferredChatSize.width = abs(preferredChatSize.width - wide) < 1 ? Self.defaultChatSize.width : wide
        saveChatSize()
        if let origin = placementTarget?.anchorOrigin { placePet(at: origin) }
    }
    func resetChatSize() {
        preferredChatSize = Self.defaultChatSize; fittedThreadHeight = nil; saveChatSize()
        if let origin = placementTarget?.anchorOrigin { placePet(at: origin) }
    }
    func fitOpenThread(_ height: CGFloat?) {
        let next = height.map { max(preferredChatSize.height, $0) }
        guard next != fittedThreadHeight else { return }
        fittedThreadHeight = next
        if chatExpanded, let origin = placementTarget?.anchorOrigin { placePet(at: origin) }
    }
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
