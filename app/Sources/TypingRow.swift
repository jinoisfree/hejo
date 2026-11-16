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
    private let activity:String?
    private var words:String {activity ?? Self.words}
    private(set) var elapsedText = ""
    var isShimmering: Bool { !shimmer.isHidden }
    var shimmerPosition: CGFloat { shimmer.bandX }
    override var isFlipped: Bool { true }
    var wordsRect: CGRect {
        CGRect(x: activity == nil ? 43:60, y: 3, width: min(activity == nil ? 1000:max(1,bounds.width-140),ceil((words as NSString).size(withAttributes: [.font: Self.font]).width) + 1), height: 16)
    }
    init(since: Date, clock: @escaping () -> Date, animationTime: @escaping () -> TimeInterval, reduceMotion: @escaping () -> Bool, activity:String?=nil) {
        self.activity=activity
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
        shimmer.configure(text: words, font: Self.font, frame: wordsRect, scale: window?.backingScaleFactor ?? 2)
        tick()
    }
    var elapsedRect:CGRect { CGRect(x:wordsRect.maxX+(activity == nil ? 6:9),y:wordsRect.minY,width:ceil((elapsedText as NSString).size(withAttributes:[.font:Self.font]).width),height:16) }
    func tick() {
        let seconds=max(0,Int(clock().timeIntervalSince(since)))
        let text = activity == nil ? Self.elapsed(seconds):"\(seconds)초"
        if text != elapsedText { elapsedText = text; setAccessibilityLabel(words + " " + text); needsDisplay = true; superview?.needsLayout=true }
        if activity != nil {needsDisplay=true}
        shimmer.update(time: animationTime(), running: !reduceMotion())
    }
    override func draw(_ dirtyRect: NSRect) {
        let words = wordsRect
        (self.words as NSString).draw(in: words, withAttributes: [.font: Self.font, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.45)])
        if activity != nil {
            let levels=WritingSpinner.levels(at:animationTime(),reduceMotion:reduceMotion())
            for (index,point) in WritingSpinner.positions.enumerated() where levels[index]>0 {
                NSColor.labelColor.withAlphaComponent(levels[index]*0.6).setFill()
                NSBezierPath(roundedRect:CGRect(x:43+CGFloat(point.0)*5,y:5+CGFloat(point.1)*5,width:2.5,height:2.5),xRadius:0.6,yRadius:0.6).fill()
            }
        }
        (elapsedText as NSString).draw(in: elapsedRect,
                                       withAttributes: [.font: Self.font, .foregroundColor: NSColor.labelColor.withAlphaComponent(0.35)])
    }
}

enum WritingSpinner {
    static let positions=[(0,0),(1,0),(1,1),(1,2),(0,2),(0,1)]
    static let stepDuration:TimeInterval=0.16
    static func levels(at time:TimeInterval,reduceMotion:Bool)->[Double] {
        let head=reduceMotion ? 0:(Int(floor(time/stepDuration))%6+6)%6
        let tail=[1.0,0.7,0.5,0.35]
        return positions.indices.map {let age=(head-$0+6)%6;return age<tail.count ? tail[age]:0}
    }
}
final class WorkingControlRow:NSView {
    let row:TypingRow,button=FileChip(title:"")
    init(since:Date,activity:String,clock:@escaping()->Date,animationTime:@escaping()->TimeInterval,reduceMotion:@escaping()->Bool,stop:@escaping()->Void) {
        row=TypingRow(since:since,clock:clock,animationTime:animationTime,reduceMotion:reduceMotion,activity:activity)
        super.init(frame:.zero);addSubview(row);addSubview(button)
        button.image=NSImage(systemSymbolName:"stop.fill",accessibilityDescription:"중지")?.withSymbolConfiguration(.init(pointSize:9,weight:.regular));button.isBordered=false;button.toolTip="중지";button.setAccessibilityLabel("중지");button.invoke=stop
    }
    required init?(coder:NSCoder){fatalError()}
    override func layout(){super.layout();row.frame=CGRect(x:0,y:0,width:max(1,bounds.width-24),height:22);button.frame=CGRect(x:row.elapsedRect.maxX+6,y:2,width:18,height:18)}
}
