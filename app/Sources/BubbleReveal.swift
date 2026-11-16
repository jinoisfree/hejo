import AppKit

/// Only presentation state is retained here. A reminder stores an id and deadline, never a second message body.
@MainActor final class BubbleReveal {
    static let alertStay: TimeInterval = 12
    static let remindAfter: TimeInterval = 1800
    static let settingsKey = "bubbleAlwaysShown"
    enum Kind: String { case approval, failure, writing, reply, idle }
    struct Notice: Equatable {
        var kind: Kind
        var headline: String
        var detail: String
        var key: ConversationKey?
        var sender = ""
        var id: String?
        var body = ""
        var until: Date? = nil
        var held: Bool { kind == .approval || kind == .failure }
        var actions: [Action] { kind == .reply ? Self.buttons(body) : key == nil ? [] : [.openChat] }
        private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        static func buttons(_ text: String) -> [Action] {
            let url = detector?.matches(in:text,range:NSRange(text.startIndex...,in:text)).compactMap(\.url).first { ["http","https"].contains($0.scheme?.lowercased() ?? "") }
            return (url.map { [Action.link($0)] } ?? []) + [.openChat,.remindLater]
        }
    }
    enum Action: Equatable {
        case link(URL), openChat, remindLater
        var title: String { switch self {case .link:return "링크 열기";case .openChat:return "대화 열기";case .remindLater:return "나중에 알려줘"} }
    }
    struct Input {
        var messages: [ConversationMessage] = []
        var questions: Set<String> = []
        var typing: [ConversationKey:Date] = [:]
        var names: [String:String] = [:]
        var muted: Set<String> = []
        var readIDs: Set<String> = []
        var opened: ConversationKey?
        var chatOpen = false
        var paused = false
        var ready = false
        var failure: IslandFailure?
    }
    private let store: LocalStore
    private var initialized = false, highSequence = 0
    private var openedQuestions = Set<String>()
    private var current: Notice?
    private(set) var notice = Notice(kind:.idle,headline:"",detail:"",key:nil)
    private(set) var persistenceFailed = false
    var reminders: [String:Double] { store.settings.reminders ?? [:] }
    init(store:LocalStore) { self.store=store }
    static func preview(_ text:String)->String {
        for raw in MessageFormat.plain(text).split(whereSeparator: \.isNewline) {
            var line=String(raw).trimmingCharacters(in:.whitespaces)
            while let first=line.first,"#•>".contains(first) {line.removeFirst();line=line.trimmingCharacters(in:.whitespaces)}
            if line.hasPrefix("- ") || line.hasPrefix("* ") {line=String(line.dropFirst(2))}
            if let value=try? AttributedString(markdown:line,options:.init(interpretedSyntax:.inlineOnlyPreservingWhitespace)) {line=String(value.characters)}
            if !line.isEmpty {return line}
        };return ""
    }
    private func save(_ next:[String:Double])->Bool {
        guard next != reminders else {return true}
        do {try store.update{$0.reminders=next};persistenceFailed=false;return true}
        catch {persistenceFailed=true;return false}
    }
    /// Replay is a baseline, not a new-answer event. Opening a thread dismisses its request only on this Mac.
    @discardableResult func update(_ input:Input, now:Date)->Bool {
        let sorted=input.messages.sorted{$0.seq<$1.seq}, ids=Set(sorted.map(\.id))
        let eligible=sorted.filter{$0.role=="employee" && !input.muted.contains($0.key.employee) && !ThreadTools.thinking($0.text)}
        let liveQuestions=eligible.filter{input.questions.contains($0.id)}
        openedQuestions.formIntersection(Set(liveQuestions.map(\.id)))
        if input.chatOpen,let key=input.opened {openedQuestions.formUnion(liveQuestions.filter{$0.key==key}.map(\.id))}
        let fresh=initialized && input.ready ? eligible.filter{$0.seq>highSequence}:[]
        if input.ready {initialized=true}
        highSequence=max(highSequence,sorted.map(\.seq).max() ?? 0)
        let acknowledged=input.readIDs.union(input.chatOpen ? Set(sorted.map(\.id)):[])
        if input.ready {
            _=save(reminders.filter {ids.contains($0.key) && !acknowledged.contains($0.key)})
        }
        if input.chatOpen || input.paused {current=nil}
        else if let newest=fresh.last {
            current=reply(newest,names:input.names,now:now,reminder:false)
        } else if input.ready,let due=reminders.filter({$0.value<=now.timeIntervalSince1970}).min(by:{$0.value<$1.value}) {
            var next=reminders;next[due.key]=nil
            if save(next),let message=eligible.first(where:{$0.id==due.key}) {current=reply(message,names:input.names,now:now,reminder:true)}
        }
        if let shown=current, shown.until!<=now || !ids.contains(shown.id ?? "") || acknowledged.contains(shown.id ?? "") || shown.key.map({input.muted.contains($0.employee)}) == true {current=nil}
        if input.paused {notice=Notice(kind:.idle,headline:"쉬고 있어요",detail:"메뉴에서 다시 시작할 수 있어요",key:nil)}
        else if let question=liveQuestions.first(where:{!openedQuestions.contains($0.id)}) {
            notice=Notice(kind:.approval,headline:(input.names[question.key.employee] ?? "직원")+" · 답변이 필요해요",detail:Self.preview(question.text),key:question.key,sender:input.names[question.key.employee] ?? "직원",id:question.id)
        } else if let failure=input.failure,failure.retryKey.map({!input.muted.contains($0.employee)}) ?? true {
            notice=Notice(kind:.failure,headline:"보내지 못했어요",detail:failure.message,key:failure.retryKey)
        } else if let key=input.typing.filter({$0.value>now && !input.muted.contains($0.key.employee)}).keys.sorted(by:{ a,b in
            let x=sorted.last(where:{$0.role=="owner" && $0.key==a})?.seq ?? 0,y=sorted.last(where:{$0.role=="owner" && $0.key==b})?.seq ?? 0
            return x==y ? a.readKey<b.readKey:x>y
        }).first {
            notice=Notice(kind:.writing,headline:"답변을 생각하고 있어요",detail:(input.names[key.employee] ?? "직원")+" 작성 중…",key:key)
        } else if let current {notice=current}
        else {notice=Notice(kind:.idle,headline:"",detail:"",key:nil)}
        return !fresh.isEmpty && !input.paused
    }
    private func reply(_ message:ConversationMessage,names:[String:String],now:Date,reminder:Bool)->Notice {
        let name=names[message.key.employee] ?? "직원"
        return Notice(kind:.reply,headline:name+" · "+(reminder ? "다시 알림":"새 메시지"),detail:Self.preview(message.text),key:message.key,sender:name,id:message.id,body:message.text,until:now.addingTimeInterval(Self.alertStay))
    }
    @discardableResult func remindLater(now:Date)->Bool {
        guard notice.kind == .reply,let id=notice.id else {return false}
        var next=reminders;next[id]=now.addingTimeInterval(Self.remindAfter).timeIntervalSince1970
        guard save(next) else {return false};current=nil;notice=Notice(kind:.idle,headline:"",detail:"",key:nil);return true
    }
    func dismiss() {current=nil;notice=Notice(kind:.idle,headline:"",detail:"",key:nil)}
}

final class FoldedBubbleView: NSView {
    var onOpen: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var onAction: ((BubbleReveal.Action) -> Void)?
    var headline = "" { didSet { needsDisplay = true } }
    var detail = "" { didSet { needsDisplay = true;needsLayout=true } }
    var avatar:ProfileAvatar? { didSet { needsDisplay=true } }
    var sender=""
    var unread=0 {didSet{needsDisplay=true}}
    var kind:BubbleReveal.Kind = .idle {didSet{needsDisplay=true}}
    var actions:[BubbleReveal.Action]=[] {didSet {if actions != oldValue {installButtons()}}}
    var reduceMotion:()->Bool={NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    private let shimmer=ShimmerLayer(),dot=CALayer()
    private(set) var buttons:[FileChip]=[]
    private var tracking: NSTrackingArea?
    var statusDotVisible:Bool { !dot.isHidden }
    var isShimmering:Bool { !shimmer.isHidden }
    override var isFlipped: Bool { true }
    override init(frame:NSRect) {super.init(frame:frame);wantsLayer=true;layer?.addSublayer(shimmer);dot.cornerRadius=3;layer?.addSublayer(dot)}
    required init?(coder:NSCoder){fatalError()}
    private func installButtons() {
        buttons.forEach{$0.removeFromSuperview()}
        buttons=actions.map{action in let button=FileChip(title:action.title);button.isBordered=false;button.wantsLayer=true;button.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.1).cgColor;button.layer?.cornerRadius=11;button.font = .systemFont(ofSize:11,weight:.medium);button.setAccessibilityLabel(action.title);button.invoke={ [weak self] in self?.onAction?(action) };addSubview(button);return button}
        needsLayout=true
    }
    override func layout(){super.layout();let width=(bounds.width-24-CGFloat(max(0,buttons.count-1))*6)/CGFloat(max(1,buttons.count));for (i,b) in buttons.enumerated(){b.frame=CGRect(x:12+CGFloat(i)*(width+6),y:57,width:width,height:24)}
        shimmer.configure(text:detail,font:.systemFont(ofSize:11),frame:CGRect(x:16,y:30,width:max(0,bounds.width-32),height:16),scale:window?.backingScaleFactor ?? 2)
        dot.frame=CGRect(x:16,y:16,width:6,height:6)
    }
    func tick(at time:TimeInterval,paused:Bool){
        shimmer.update(time:time * (ShimmerLayer.period / 1.8),running:kind == .writing && !reduceMotion() && !paused)
        CATransaction.begin();CATransaction.setDisableActions(true)
        dot.backgroundColor=(kind == .approval ? NSColor.systemOrange:kind == .failure ? .systemRed:kind == .writing ? .systemGreen:.systemTeal).cgColor
        dot.isHidden=avatar != nil || unread>0;dot.opacity=1;CATransaction.commit()
        if kind == .writing && !reduceMotion() && !paused && !dot.isHidden {
            if dot.animation(forKey:"workingStatusPulse")==nil {let pulse=CABasicAnimation(keyPath:"opacity");pulse.fromValue=1;pulse.toValue=0.35;pulse.duration=0.8;pulse.autoreverses=true;pulse.repeatCount = .infinity;pulse.timingFunction=CAMediaTimingFunction(name:.easeInEaseOut);dot.add(pulse,forKey:"workingStatusPulse")}
        } else {dot.removeAnimation(forKey:"workingStatusPulse")}
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas();if let tracking {removeTrackingArea(tracking)}
        tracking=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseEnteredAndExited,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(tracking!)
    }
    override func mouseEntered(with event:NSEvent){onHover?(true)}
    override func mouseExited(with event:NSEvent){onHover?(false)}
    override func mouseDown(with event:NSEvent){onOpen?()}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
    override func draw(_ dirtyRect:NSRect){
        let path=NSBezierPath(roundedRect:bounds.insetBy(dx:1,dy:1),xRadius:14,yRadius:14);NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill();path.fill();NSColor.labelColor.withAlphaComponent(0.14).setStroke();path.lineWidth=1;path.stroke()
        var x:CGFloat=30
        if unread>0 {let rect=CGRect(x:16,y:8,width:22,height:22);NSColor.systemBlue.setFill();NSBezierPath(ovalIn:rect).fill();let text=(unread>9 ? "9+":String(unread)) as NSString;let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.boldSystemFont(ofSize:11),.foregroundColor:NSColor.white];let size=text.size(withAttributes:attrs);text.draw(at:CGPoint(x:rect.midX-size.width/2,y:rect.midY-size.height/2),withAttributes:attrs);x=46}
        if let avatar {avatar.draw(in:CGRect(x:x==30 ? 16:x,y:9,width:20,height:20),name:sender);x=(x==30 ? 16:x)+26}
        let paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingTail
        (headline as NSString).draw(in:CGRect(x:x,y:9,width:max(0,bounds.width-x-16),height:19),withAttributes:[.font:NSFont.systemFont(ofSize:14,weight:.semibold),.foregroundColor:avatar?.color ?? NSColor.labelColor,.paragraphStyle:paragraph])
        (detail as NSString).draw(in:CGRect(x:16,y:30,width:max(0,bounds.width-32),height:16),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:kind == .writing ? NSColor.labelColor.withAlphaComponent(0.45):.secondaryLabelColor,.paragraphStyle:paragraph])
    }
}

/// Non-interactive native thought-balloon trail. The hidden bubble leaves only the badge beside the head.
final class PetThoughtView:NSView {
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    override func draw(_ dirtyRect:NSRect){let path=NSBezierPath(ovalIn:bounds.insetBy(dx:0.5,dy:0.5));NSColor.windowBackgroundColor.withAlphaComponent(0.94).setFill();path.fill();NSColor.labelColor.withAlphaComponent(0.14).setStroke();path.lineWidth=1;path.stroke()}
}
