import AppKit

/// Immutable, decoded thumbnail passed from the monitor queue to the UI. No UI-time file reads.
struct ProfileAvatar: Equatable {
    var color: NSColor = .systemGray
    static func initial(_ name: String) -> String { String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)) }
    var foreground: NSColor {
        guard let rgb = color.usingColorSpace(.sRGB) else { return .white }
        return rgb.redComponent * 0.2126 + rgb.greenComponent * 0.7152 + rgb.blueComponent * 0.0722 > 0.55 ? .black : .white
    }
    func draw(in rect: NSRect, name: String, clipPath: CGPath? = nil) {
        NSGraphicsContext.saveGraphicsState()
        let corner = min(rect.width, rect.height) * ChatMetrics.avatarCorner
        if let clipPath, let context = NSGraphicsContext.current?.cgContext {
            context.addPath(clipPath); context.clip()
        } else {
            NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner).addClip()
        }
            color.setFill(); rect.fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: rect.height * 0.6, weight: .medium), .foregroundColor: foreground]
            let text = Self.initial(name) as NSString, size = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: rect.midX-size.width/2, y: rect.midY-size.height/2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}
