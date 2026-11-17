import AppKit

/// AppKit counterpart of the original settings-only SwiftUI conversation sample.
final class AppearancePreview: NSView {
    private var name: String, agent: CharacterPalette, mine: UserBubblePalette
    private var size: CGFloat, opacity: Double, dark: Bool
    private var measured: ([String: CGRect]) -> Void
    private(set) var textFrames: [String: CGRect] = [:]
    private var agentBubble = CGRect.zero, mineBubble = CGRect.zero, nameFrame = CGRect.zero, avatar = CGRect.zero, timeFrame = CGRect.zero
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
        let body=NSFont.systemFont(ofSize:size),caption=NSFont.systemFont(ofSize:11)
        let a=textSize(Self.agentText,font:body,width:310),m=textSize(Self.mineText,font:body,width:480)
        let n=textSize(name,font:.systemFont(ofSize:11,weight:.semibold),width:330),t=textSize("오후 3:12",font:caption,width:504)
        let first=max(26,n.height+4+a.height+20),natural=32+first+10+m.height+16+10+t.height
        sampleHeight=max(184,natural)
        var y=16+(sampleHeight-natural)/2
        avatar=CGRect(x:16,y:y,width:26,height:26);nameFrame=CGRect(x:50,y:y,width:n.width,height:n.height)
        y+=n.height+4;agentBubble=CGRect(x:50,y:y,width:a.width+20,height:a.height+20)
        textFrames["agent"]=CGRect(x:60,y:y+10,width:a.width,height:a.height)
        y=16+(sampleHeight-natural)/2+first+10
        mineBubble=CGRect(x:520-m.width-24,y:y,width:m.width+24,height:m.height+16)
        textFrames["mine"]=CGRect(x:mineBubble.minX+12,y:y+8,width:m.width,height:m.height)
        timeFrame=CGRect(x:520-t.width,y:mineBubble.maxY+10,width:t.width,height:t.height)
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
        agent.name.nsColor.withAlphaComponent(0.25).setFill();NSBezierPath(roundedRect:rect(avatar),xRadius:7,yRadius:7).fill()
        let initial=String(name.prefix(1)),f=NSFont.systemFont(ofSize:12,weight:.bold),s=(initial as NSString).size(withAttributes:[.font:f])
        label(initial,CGRect(x:avatar.midX-s.width/2,y:avatar.midY-s.height/2,width:s.width,height:s.height),f,.labelColor)
        label(name,nameFrame,.systemFont(ofSize:11,weight:.semibold),agent.name.nsColor)
        agent.background.nsColor.setFill();NSBezierPath(roundedRect:rect(agentBubble),xRadius:14,yRadius:14).fill()
        label(Self.agentText,textFrames["agent"]!,.systemFont(ofSize:size),agent.foreground.nsColor)
        mine.background.nsColor.setFill();NSBezierPath(roundedRect:rect(mineBubble),xRadius:16,yRadius:16).fill()
        label(Self.mineText,textFrames["mine"]!,.systemFont(ofSize:size),mine.foreground.nsColor)
        label("오후 3:12",timeFrame,.systemFont(ofSize:11),.secondaryLabelColor)
        NSColor.labelColor.withAlphaComponent(0.12).setStroke();box.lineWidth=1;box.stroke()
    }
}
