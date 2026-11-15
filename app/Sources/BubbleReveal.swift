import AppKit

/// A transient folded-bubble notice. The last notice remains available when the member chooses that setting.
struct BubbleReveal {
    static let alertStay: TimeInterval = 3
    static let settingsKey = "bubbleAlwaysShown"
    private(set) var until: TimeInterval = -.infinity
    mutating func alert(now: TimeInterval) { until = max(until, now + Self.alertStay) }
    func visible(now: TimeInterval, held: Bool) -> Bool { held || now < until }
}

final class FoldedBubbleView: NSView {
    var onOpen: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var headline = "" { didSet { needsDisplay = true } }
    var detail = "" { didSet { needsDisplay = true } }
    var avatar:ProfileAvatar? { didSet { needsDisplay=true } }
    var sender=""
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func mouseDown(with event: NSEvent) { onOpen?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill(); path.fill()
        NSColor.labelColor.withAlphaComponent(0.14).setStroke(); path.lineWidth = 1; path.stroke()
        let title = NSMutableParagraphStyle(); title.lineBreakMode = .byTruncatingTail
        if let avatar { avatar.draw(in:CGRect(x:12,y:9,width:20,height:20),name:sender) }
        let x:CGFloat=avatar==nil ? 12 : 38
        (headline as NSString).draw(in: CGRect(x:x, y: 9, width: bounds.width-x-12, height: 18),
                                   withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: avatar?.color ?? NSColor.labelColor, .paragraphStyle: title])
        (detail as NSString).draw(in: CGRect(x: 12, y: 29, width: bounds.width - 24, height: 16),
                                 withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: title])
    }
}
