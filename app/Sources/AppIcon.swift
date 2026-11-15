import AppKit

enum AppIcon {
    static func render(pixels: Int) -> NSBitmapImageRep? {
        guard pixels > 0,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.shouldAntialias = true
        context.imageInterpolation = .high
        let transform = NSAffineTransform()
        transform.scaleX(by: CGFloat(pixels) / 1024, yBy: CGFloat(pixels) / 1024)
        transform.concat()

        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                     xRadius: 185, yRadius: 185).fill()

        let blue = NSColor.systemBlue.usingColorSpace(.sRGB) ?? NSColor.systemBlue
        let dark = NSColor(srgbRed: 29.0 / 255, green: 29.0 / 255, blue: 31.0 / 255, alpha: 1)
        let title = "HEJO." as NSString
        let base = NSFont.systemFont(ofSize: 250, weight: .heavy)
        let measured = title.size(withAttributes: [.font: base]).width
        let font = NSFont.systemFont(ofSize: 250 * (824 * 0.78) / measured, weight: .heavy)
        let h = "H" as NSString
        let rest = "EJO." as NSString
        let hSize = h.size(withAttributes: [.font: font])
        let restSize = rest.size(withAttributes: [.font: font])
        let origin = NSPoint(x: (1024 - hSize.width - restSize.width) / 2,
                             y: (1024 - max(hSize.height, restSize.height)) / 2)
        h.draw(at: origin, withAttributes: [.font: font, .foregroundColor: blue])
        rest.draw(at: NSPoint(x: origin.x + hSize.width, y: origin.y),
                  withAttributes: [.font: font, .foregroundColor: dark])
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}
