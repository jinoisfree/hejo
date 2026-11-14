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
        conversation.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        conversation.layer?.cornerRadius = PetLayout.cornerRadius
        conversation.layer?.masksToBounds = true
        statusLabel.font = .systemFont(ofSize: 13); statusLabel.textColor = .secondaryLabelColor
        conversation.addSubview(statusLabel); conversation.addSubview(collapseButton)
        addSubview(conversation); addSubview(genie); addSubview(sprite)
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
