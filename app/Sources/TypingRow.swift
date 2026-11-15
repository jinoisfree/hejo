import AppKit

/// In-chat waiting row (REQ-HF-19): "작성 중" with the island's shimmer and a dim elapsed time counted from the
/// thread's first typing-on. Reduced motion leaves the dim words still. Height stays the accessory's 22pt.
final class TypingRow: NSView {
    static let words = "작성 중"
    static let font = NSFont.systemFont(ofSize: 11)
    static func elapsed(_ seconds: Int) -> String { seconds >= 60 ? "\(seconds / 60)분 \(seconds % 60)초" : "\(seconds)초" }
    private let since: Date, clock: () -> Date, animationTime: () -> TimeInterval, reduceMotion: () -> Bool
    private let shimmer = ShimmerLayer()
    private var timer: Timer?
    private(set) var elapsedText = ""
    var isShimmering: Bool { !shimmer.isHidden }
    var shimmerPosition: CGFloat { shimmer.bandX }
    override var isFlipped: Bool { true }
    private var wordsRect: CGRect {
        CGRect(x: 43, y: 3, width: ceil((Self.words as NSString).size(withAttributes: [.font: Self.font]).width) + 1, height: 16)
    }
    init(since: Date, clock: @escaping () -> Date, animationTime: @escaping () -> TimeInterval, reduceMotion: @escaping () -> Bool) {
        self.since = since; self.clock = clock; self.animationTime = animationTime; self.reduceMotion = reduceMotion
        super.init(frame: .zero)
        wantsLayer = true; layer?.addSublayer(shimmer)
        setAccessibilityElement(true); setAccessibilityRole(.staticText)
        tick()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate(); timer = nil
        guard window != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
    }
    override func layout() {
        super.layout()
        shimmer.configure(text: Self.words, font: Self.font, frame: wordsRect, scale: window?.backingScaleFactor ?? 2)
        tick()
    }
    func tick() {
        let text = Self.elapsed(max(0, Int(clock().timeIntervalSince(since))))
        if text != elapsedText { elapsedText = text; setAccessibilityLabel(Self.words + " " + text); needsDisplay = true }
        shimmer.update(time: animationTime(), running: !reduceMotion())
    }
    override func draw(_ dirtyRect: NSRect) {
        let words = wordsRect
        (Self.words as NSString).draw(in: words, withAttributes: [.font: Self.font, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.45)])
        (elapsedText as NSString).draw(in: CGRect(x: words.maxX + 6, y: words.minY, width: 80, height: 16),
                                       withAttributes: [.font: Self.font, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.35)])
    }
}
