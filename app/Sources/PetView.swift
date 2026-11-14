import AppKit

final class PetPanel: NSPanel {
    var chatExpanded = false
    var onCollapse: (() -> Void)?
    override var canBecomeKey: Bool { chatExpanded }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override func cancelOperation(_ sender: Any?) { onCollapse?() }
    override func sendEvent(_ event: NSEvent) {
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
    let statusLabel = NSTextField(labelWithString: "공항 연결 전")
    let collapseButton = NSButton(title: "펫으로 접기", target: nil, action: nil)
    private var conversationContent: NSView?
    private var glass: NSView!
    private let tint = NSView()
    let unreadBadge = PetBadgeView()
    var unreadCount = 0 { didSet { updateUnreadBadge() } }
    private func updateUnreadBadge() {
        let text = unreadCount > 99 ? "99+" : unreadCount > 0 ? String(unreadCount) : ""
        unreadBadge.text = text
        let head = atlas.interactionRect(in: spriteRect), size = PetBadgeView.size(text)
        unreadBadge.frame = CGRect(origin: CGPoint(x: floor(min(head.maxX-size.width/2,spriteRect.maxX-size.width)), y: floor(min(head.maxY-size.height/2,spriteRect.maxY-size.height))), size: size)
        unreadBadge.isHidden = unreadCount <= 0 || placement?.expanded == true
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
        addSubview(conversation); addSubview(genie); addSubview(sprite); addSubview(unreadBadge); unreadBadge.isHidden = true
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
        guard window?.isVisible == true else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.animate() }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    private func animate() {
        guard window?.isVisible == true, let p = placement else { updateAnimationVisibility(); return }
        let now = ProcessInfo.processInfo.systemUptime
        let pointer = pointerLocation(), origin = window!.convertPoint(toScreen: .zero)
        let global = PetLayout.visibleSprite(in: spriteRect).offsetBy(dx: origin.x, dy: origin.y)
        let phase = self.pointer.update(pointer: pointer, sprite: global, display: window!.screen?.frame ?? global, now: now, reducedMotion: reduceMotion())
        switch phase {
        case .jumping(let elapsed): pose = PetAnimationTimeline.frame(for: .jumping, elapsed: elapsed)
        case .looking: pose = PetAnimationTimeline.lookFrame(from: CGPoint(x: global.midX, y: global.midY), toward: pointer, previous: pose) ?? pose
        case .inactive: pose = PetAnimationTimeline.frame(for: .idle, elapsed: now, reducedMotion: reduceMotion())
        }
        sprite.needsDisplay = true
        _ = p
    }
    func arrange(_ p: PetPlacement) {
        placement = p; frame = CGRect(origin: .zero, size: p.windowFrame.size)
        sprite.frame = p.spriteRect; conversation.frame = p.bubbleRect; genie.frame = bounds
        statusLabel.frame = CGRect(x: 20, y: max(20, p.bubbleRect.height - 80), width: max(0, p.bubbleRect.width - 40), height: 36)
        collapseButton.frame = CGRect(x: 16, y: max(0, p.bubbleRect.height - 38), width: 120, height: 28)
        glass.frame = conversation.bounds; tint.frame = conversation.bounds
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua,.aqua]) == .darkAqua
        tint.layer?.backgroundColor = (dark ? NSColor.black : .white).withAlphaComponent(NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.65).cgColor
        conversationContent?.frame = CGRect(origin: .zero, size: p.bubbleRect.size)
        updateUnreadBadge()
        sprite.needsDisplay = true
    }
    func spriteContains(_ point: CGPoint) -> Bool { atlas.opaque(at: point, in: spriteRect, row: pose.row, frame: pose.column) }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let p = placement else { return nil }
        if spriteContains(point) { return self }
        if p.expanded, !genie.isHidden { return self }
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
