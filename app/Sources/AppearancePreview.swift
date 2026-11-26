import AppKit

/// AppKit counterpart of the original settings-only SwiftUI conversation sample.
final class AppearancePreview: NSView {
    private var name: String, agent: CharacterPalette, mine: UserBubblePalette
    private var size: CGFloat, opacity: Double, dark: Bool
    private var measured: ([String: CGRect]) -> Void
    private(set) var textFrames: [String: CGRect] = [:]
    private(set) var agentBubble = CGRect.zero, mineBubble = CGRect.zero
    private(set) var ownerNameFrame = CGRect.zero, ownerTimeFrame = CGRect.zero
    private var nameFrame = CGRect.zero, avatar = CGRect.zero, ownerAvatar = CGRect.zero
    private let ownerName = OwnerProfile.fallbackName
    private let sampleTime = "오후 3:12"
    static let agentText = "오늘 나눌 이야기를 정리했어요. 함께 살펴볼까요?"
    static let mineText = "좋아, 첫 번째 이야기부터 보여 줘"
    init(name: String, agent: CharacterPalette, mine: UserBubblePalette, size: CGFloat, opacity: Double, dark: Bool, measured: @escaping ([String: CGRect]) -> Void) {
        self.name=name;self.agent=agent;self.mine=mine;self.size=size;self.opacity=opacity;self.dark=dark;self.measured=measured
        super.init(frame:CGRect(x:0,y:0,width:536,height:184));measure()
        setAccessibilityElement(true);setAccessibilityRole(.group);setAccessibilityLabel("미리보기 · "+name+" · "+Self.agentText+" · "+Self.mineText)
    }
    required init?(coder:NSCoder){fatalError()}
    func update(name:String,agent:CharacterPalette,mine:UserBubblePalette,size:CGFloat,opacity:Double,dark:Bool) {
        self.name=name;self.agent=agent;self.mine=mine;self.size=size;self.opacity=opacity;self.dark=dark;appearance=NSAppearance(named:dark ? .darkAqua:.aqua);measure();needsDisplay=true
    }
    override var intrinsicContentSize:NSSize {CGSize(width:536,height:sampleHeight)}
    override var fittingSize:NSSize {intrinsicContentSize}
    private var sampleHeight:CGFloat=184
    private func textSize(_ text:String,font:NSFont,width:CGFloat)->CGSize {
        let rect=(text as NSString).boundingRect(with:CGSize(width:width,height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:font])
        return CGSize(width:min(width,ceil(rect.width)),height:ceil(rect.height))
    }
    private func measure() {
        let body = NSFont.systemFont(ofSize:size), caption = NSFont.systemFont(ofSize:ChatMetrics.auxiliaryFont)
        let nameFont = NSFont.systemFont(ofSize:ChatMetrics.nameFont,weight:.bold)
        let padding = ChatMetrics.bubbleInset
        let a = textSize(Self.agentText,font:body,width:310), m = textSize(Self.mineText,font:body,width:431)
        let n = textSize(name,font:nameFont,width:330), mineName = textSize(ownerName,font:nameFont,width:200)
        let t = textSize(sampleTime,font:caption,width:200)
        let headerHeight = max(n.height,mineName.height,t.height)
        let first = max(ChatMetrics.avatar,headerHeight+ChatMetrics.nameBodyGap+a.height+padding.height*2)
        let second = max(ChatMetrics.avatar,headerHeight+ChatMetrics.nameBodyGap+m.height+padding.height*2)
        let natural = 32+first+10+second
        sampleHeight = max(184,natural)
        let top = 16+(sampleHeight-natural)/2
        let left: CGFloat = 16+ChatMetrics.avatar+9
        let right: CGFloat = 520-ChatMetrics.avatar-9
        avatar = CGRect(x:16,y:top,width:ChatMetrics.avatar,height:ChatMetrics.avatar)
        nameFrame = CGRect(x:left,y:top,width:n.width,height:headerHeight)
        let agentTop = top+headerHeight+ChatMetrics.nameBodyGap
        agentBubble = CGRect(x:left,y:agentTop,width:a.width+padding.width*2,height:a.height+padding.height*2)
        textFrames["agent"] = agentBubble.insetBy(dx:padding.width,dy:padding.height)
        let ownerTop = top+first+10
        ownerAvatar = CGRect(x:right+9,y:ownerTop,width:ChatMetrics.avatar,height:ChatMetrics.avatar)
        ownerNameFrame = CGRect(x:right-mineName.width,y:ownerTop,width:mineName.width,height:headerHeight)
        ownerTimeFrame = CGRect(x:ownerNameFrame.minX-6-t.width,y:ownerTop+nameFont.ascender-caption.ascender,width:t.width,height:t.height)
        mineBubble = CGRect(x:right-m.width-padding.width*2,y:ownerTop+headerHeight+ChatMetrics.nameBodyGap,
                            width:m.width+padding.width*2,height:m.height+padding.height*2)
        textFrames["mine"] = mineBubble.insetBy(dx:padding.width,dy:padding.height)
        measured(textFrames)
    }
    private func rect(_ r:CGRect)->CGRect {CGRect(x:r.minX,y:bounds.height-r.maxY,width:r.width,height:r.height)}
    private func label(_ text:String,_ r:CGRect,_ font:NSFont,_ color:NSColor) {
        (text as NSString).draw(with:rect(r),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:font,.foregroundColor:color])
    }
    override func draw(_ dirtyRect:NSRect) {
        let box=NSBezierPath(roundedRect:bounds,xRadius:10,yRadius:10)
        NSColor.windowBackgroundColor.setFill();box.fill()
        NSColor(white:dark ? 0.08:0.93,alpha:BubbleOpacity.alpha(progress:1,percent:opacity,reduceTransparency:false)).setFill();box.fill()
        let nameFont = NSFont.systemFont(ofSize:ChatMetrics.nameFont,weight:.bold)
        ProfileAvatar(color:agent.name.nsColor).draw(in:rect(avatar),name:name)
        label(name,nameFrame,nameFont,agent.name.nsColor)
        agent.background.nsColor.setFill()
        NSBezierPath(roundedRect:rect(agentBubble),xRadius:ChatMetrics.bubbleCorner,yRadius:ChatMetrics.bubbleCorner).fill()
        label(Self.agentText,textFrames["agent"]!,.systemFont(ofSize:size),agent.foreground.nsColor)
        ProfileAvatar(color:PictureCodec.color(name:ownerName,hex:nil)).draw(in:rect(ownerAvatar),name:ownerName)
        label(ownerName,ownerNameFrame,nameFont,.labelColor)
        label(sampleTime,ownerTimeFrame,.systemFont(ofSize:ChatMetrics.auxiliaryFont),.secondaryLabelColor)
        mine.background.nsColor.withAlphaComponent(mine.alpha).setFill()
        NSBezierPath(roundedRect:rect(mineBubble),xRadius:ChatMetrics.bubbleCorner,yRadius:ChatMetrics.bubbleCorner).fill()
        label(Self.mineText,textFrames["mine"]!,.systemFont(ofSize:size),mine.foreground.nsColor)
        NSColor.labelColor.withAlphaComponent(0.12).setStroke();box.lineWidth=1;box.stroke()
    }
}
