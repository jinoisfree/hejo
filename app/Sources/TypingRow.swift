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
        CGRect(x: activity == nil ? 43:60, y: 3, width: min(activity == nil ? 1000:max(1,bounds.width-60-elapsedWidth-9),ceil((words as NSString).size(withAttributes:[.font:Self.font]).width)+1),height:activity == nil ? 16:max(16,bounds.height-6))
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
        if activity != nil {shimmer.period=1.8;shimmer.bandFraction=0.28;shimmer.highlight=SidebarTone.primary(0.5)}
        shimmer.configure(text: words, font: Self.font, frame: wordsRect, scale: window?.backingScaleFactor ?? 2)
        tick()
    }
    private var elapsedFont:NSFont {activity == nil ? Self.font:.monospacedDigitSystemFont(ofSize:11,weight:.regular)}
    private var elapsedWidth:CGFloat {ceil((elapsedText as NSString).size(withAttributes:[.font:elapsedFont]).width)}
    var elapsedRect:CGRect {CGRect(x:wordsRect.maxX+(activity == nil ? 6:9),y:bounds.midY-8,width:elapsedWidth,height:16)}
    func tick() {
        let seconds=max(0,Int(clock().timeIntervalSince(since)))
        let text = activity == nil ? Self.elapsed(seconds):"\(seconds)초"
        if text != elapsedText { elapsedText = text; setAccessibilityLabel(words + " " + text); needsDisplay = true; superview?.needsLayout=true }
        if activity != nil {needsDisplay=true}
        shimmer.update(time: animationTime(), running: !reduceMotion())
    }
    override func draw(_ dirtyRect: NSRect) {
        let words = wordsRect
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        let quiet=CardText.quiet(dark:dark)
        let paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingTail
        (self.words as NSString).draw(in:words,withAttributes:[.font:Self.font,.foregroundColor:activity == nil ? NSColor.labelColor.withAlphaComponent(0.45):quiet,.paragraphStyle:paragraph])
        if activity != nil {
            let levels=WritingSpinner.levels(at:animationTime(),reduceMotion:reduceMotion())
            for (index,point) in WritingSpinner.positions.enumerated() where levels[index]>0 {
                let color=dark ? SidebarTone.primary(1):quiet
                color.withAlphaComponent(color.alphaComponent*levels[index]).setFill()
                NSBezierPath(roundedRect:CGRect(x:43+CGFloat(point.0)*5,y:bounds.midY-6.5+CGFloat(point.1)*5,width:2.5,height:2.5),xRadius:0.6,yRadius:0.6).fill()
            }
        }
        (elapsedText as NSString).draw(in: elapsedRect,
                                       withAttributes: [.font:elapsedFont,.foregroundColor:activity == nil ? NSColor.labelColor.withAlphaComponent(0.35):quiet])
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
        button.configure("중지",icon:"stop.fill",shape:.circle,action:stop);button.invoke=stop
    }
    required init?(coder:NSCoder){fatalError()}
    static func height(_ activity:String,width:CGFloat,seconds:Int=0)->CGFloat {
        let p=NSMutableParagraphStyle();p.lineBreakMode = .byWordWrapping
        let size=(activity as NSString).boundingRect(with:CGSize(width:max(1,width-60-24-9-ceil(("\(seconds)초" as NSString).size(withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:11,weight:.regular)]).width)),height:1000),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:TypingRow.font,.paragraphStyle:p]).height
        return min(36,max(22,ceil(size)+6))
    }
    override func layout(){super.layout();row.frame=CGRect(x:0,y:0,width:max(1,bounds.width-24),height:bounds.height);row.layoutSubtreeIfNeeded();button.frame=CGRect(x:row.elapsedRect.maxX+6,y:bounds.midY-9,width:18,height:18);button.contentTintColor=CardText.quiet(dark:effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua)}
    override func mouseDown(with event:NSEvent){}
}

/// Compact typingBubble: face and name only; its activity remains available to VoiceOver.
final class TypingBubbleView:NSView {
    let name:String,avatar:ProfileAvatar,activity:String,nameColor:NSColor?
    init(name:String,avatar:ProfileAvatar,nameColor:NSColor?=nil,activity:String){self.nameColor=nameColor;self.name=name;self.avatar=avatar;self.activity=activity;super.init(frame:.zero);setAccessibilityElement(true);setAccessibilityLabel(name+" "+activity)}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ rect:NSRect){
        avatar.draw(in:CGRect(x:10,y:0,width:34,height:34),name:name)
        let dark=effectiveAppearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua
        (name as NSString).draw(at:CGPoint(x:52,y:10),withAttributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:nameColor ?? CharacterPalette.make(color:avatar.color,dark:dark).name.nsColor])
    }
}
