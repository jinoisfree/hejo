import AppKit

/// Shared "working" text shimmer (island worker segment and the in-chat "작성 중" row).
/// A light band masked by the glyphs sweeps left to right once per period; only the band's position moves,
/// so the text underneath is never re-laid out. The caller draws the dim base text itself.
final class ShimmerLayer: CALayer {
    static let period: TimeInterval = 1.6
    var period=ShimmerLayer.period,bandFraction:CGFloat?,highlight:NSColor?
    private let band = CAGradientLayer(), glyphs = CATextLayer()
    private(set) var bandX: CGFloat = 0
    override init() {
        super.init()
        band.colors = [NSColor.white.withAlphaComponent(0).cgColor, NSColor.white.withAlphaComponent(0.95).cgColor, NSColor.white.withAlphaComponent(0).cgColor]
        band.startPoint = CGPoint(x: 0, y: 0.5); band.endPoint = CGPoint(x: 1, y: 0.5)
        addSublayer(band); mask = glyphs
    }
    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError() }
    func configure(text: String, font: NSFont, frame: CGRect, scale: CGFloat) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        self.frame = frame
        glyphs.frame = CGRect(origin: .zero, size: frame.size); glyphs.contentsScale = scale
        glyphs.alignmentMode = .left; glyphs.truncationMode = .end
        glyphs.string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
        let width=bandFraction.map{frame.width*$0} ?? 60
        band.bounds = CGRect(x: 0, y: 0, width: width, height: frame.height)
        glyphs.isWrapped=bandFraction != nil
        if let highlight {band.colors=[highlight.withAlphaComponent(0).cgColor,highlight.cgColor,highlight.withAlphaComponent(0).cgColor]}
        CATransaction.commit()
    }
    /// Places the band for `time`; hidden (and frozen) when not running.
    func update(time: TimeInterval, running: Bool) {
        isHidden = !(running && bounds.width > 0)
        guard !isHidden else { return }
        let cycle = time.truncatingRemainder(dividingBy: period) / period
        let width=band.bounds.width
        let x = -width/2 + (bounds.width + width) * CGFloat(cycle)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        band.position = CGPoint(x: x, y: bounds.height / 2)
        CATransaction.commit()
        bandX = x
    }
}
