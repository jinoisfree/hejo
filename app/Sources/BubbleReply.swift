import AppKit

struct BubbleReplyTarget:Equatable {
    var key:ConversationKey
    var speaker:String
    var working:Bool
    var queued:Bool
}
enum BubbleReply {
    static let settingsKey="bubbleReplyEnabled"
    static let dwell:TimeInterval=0.3,foldDelay:TimeInterval=0.6
    static let maximumLines=3
    static let interruptedSubtitle="끼어들었어요 · 다시 생각하는 중"
    static let accessibilityName="말풍선 답하기",sendName="보내기"
    static func placeholder(_ target:BubbleReplyTarget)->String {
        let name=target.speaker.isEmpty ? "직원":target.speaker
        return target.working ? (target.queued ? "답이 끝나면 이어서 읽어요":name+"에게 끼어들기…"):name+"에게 답하기…"
    }
    struct Surroundings {
        var enabled=true,connected=true,paused=false,resting=false,chatExpanded=false,bubbleShown=true,hasTarget=true
    }
    static func canOpen(_ s:Surroundings)->Bool {s.enabled && s.connected && !s.paused && !s.resting && !s.chatExpanded && s.bubbleShown && s.hasTarget}
}

struct BubbleReplyHover {
    private(set) var open = false
    private var entered: TimeInterval?
    private var left: TimeInterval?
    private var foldAt: TimeInterval?
    /// After an explicit fold the pointer has to leave the bubble once before the input comes out again.
    private var armed = true

    /// `holds` is a draft in the field or the field being typed in.
    mutating func update(now: TimeInterval, eligible: Bool, pointerOver: Bool, holds: Bool) {
        if !pointerOver { armed = true }
        guard eligible else { open = false; entered = nil; left = nil; foldAt = nil; return }
        if open {
            if let at = foldAt, now >= at, !holds { open = false; foldAt = nil; left = nil; armed = false; return }
            if pointerOver || holds { left = nil; return }
            if left == nil { left = now }
            if now - left! >= BubbleReply.foldDelay { open = false; left = nil; foldAt = nil }
        } else {
            guard pointerOver, armed else { entered = nil; return }
            if entered == nil { entered = now }
            if now - entered! >= BubbleReply.dwell { open = true; entered = nil; left = nil; foldAt = nil }
        }
    }
    /// A deliberate open (VoiceOver, a click on the bubble's hint).
    mutating func forceOpen() { open = true; entered = nil; left = nil; foldAt = nil; armed = true }
    /// Esc: fold at once. The draft stays with the card.
    mutating func fold() { open = false; entered = nil; left = nil; foldAt = nil; armed = false }
    /// After a send: fold once the delay has passed.
    mutating func foldSoon(now: TimeInterval) { foldAt = now + BubbleReply.foldDelay }
}


/// An AppKit editor of the controller's existing per-thread draft. No second draft store or send path.
final class BubbleReplyPrompt:NSTextField {override func hitTest(_ point:NSPoint)->NSView?{nil}}

@MainActor final class BubbleReplyCard:NSView,NSTextViewDelegate {
    let capsule=NSView(),input=DraftScrollView(frame:.zero),send=FileChip(title:""),prompt=BubbleReplyPrompt(labelWithString:""),problemLabel=NSTextField(labelWithString:"")
    let controller:ConversationController
    private(set) var target:BubbleReplyTarget?
    private(set) var hover=BubbleReplyHover()
    private(set) var eligible=false
    private var fieldHeight:CGFloat=18
    private var problem="",submitting=false
    private var lastProblem=""
    var onGeometry:(()->Void)?
    var now:()->TimeInterval={ProcessInfo.processInfo.systemUptime}
    var focused:Bool {window?.firstResponder === input.editor}
    var visible:Bool {hover.open && target != nil}
    var height:CGFloat {28+fieldHeight+(problem.isEmpty ? 0:18)}
    override var isFlipped:Bool {true}
    init(controller:ConversationController) {
        self.controller=controller;super.init(frame:.zero)
        input.maxLines=BubbleReply.maximumLines;input.editor.delegate=self;input.editor.isRichText=false
        input.editor.setAccessibilityLabel(BubbleReply.accessibilityName)
        input.editor.onSubmit={ [weak self] in self?.submit() }
        input.editor.onFocus={ [weak self] _ in self?.updateControls() }
        input.onHeight={ [weak self] h in guard let self,abs(self.fieldHeight-h)>0.5 else{return};self.fieldHeight=h;self.onGeometry?() }
        capsule.wantsLayer=true;capsule.layer?.cornerRadius=16;capsule.layer?.backgroundColor=NSColor.labelColor.withAlphaComponent(0.05).cgColor;capsule.layer?.borderColor=NSColor.labelColor.withAlphaComponent(0.18).cgColor;capsule.layer?.borderWidth=1
        prompt.font = .systemFont(ofSize:14);prompt.textColor = .placeholderTextColor
        prompt.setAccessibilityElement(false)
        problemLabel.font = .systemFont(ofSize:11);problemLabel.textColor = .systemRed;problemLabel.lineBreakMode = .byTruncatingTail
        send.image=NSImage(systemSymbolName:"arrow.up",accessibilityDescription:BubbleReply.sendName);send.isBordered=false;send.contentTintColor = .white;send.wantsLayer=true;send.layer?.cornerRadius=14;send.layer?.backgroundColor=NSColor.systemBlue.cgColor;send.setAccessibilityLabel(BubbleReply.sendName);send.invoke={ [weak self] in self?.submit() }
        addSubview(capsule);addSubview(input);addSubview(prompt);addSubview(send);addSubview(problemLabel);isHidden=true
    }
    required init?(coder:NSCoder){fatalError()}
    func aim(_ next:BubbleReplyTarget?) {
        let wasVisible=visible
        if target?.key != next?.key {releaseFocus();input.editor.unmarkText();lastProblem=""}
        target=next
        if let next {
            let text=controller.draft(for:next.key).text
            if input.editor.string != text,!input.editor.hasMarkedText() {input.editor.breakUndoCoalescing();input.editor.undoManager?.removeAllActions();input.editor.string=text;input.measure()}
            prompt.stringValue=BubbleReply.placeholder(next)
            let reason=controller.bubbleProblems[next.key] ?? ""
            if !reason.isEmpty,reason != lastProblem {hover.forceOpen()}
            if problem.isEmpty != reason.isEmpty {problem=reason;onGeometry?()} else {problem=reason}
            lastProblem=reason;problemLabel.stringValue=reason
        }
        isHidden = !visible
        if wasVisible != visible {onGeometry?()}
        updateControls()
    }
    func update(_ surroundings:BubbleReply.Surroundings,pointerOver:Bool) {
        eligible=BubbleReply.canOpen(surroundings)
        let was=visible
        hover.update(now:now(),eligible:eligible,pointerOver:pointerOver,holds:!input.editor.string.isEmpty || focused || submitting)
        if !visible {releaseFocus()}
        isHidden = !visible
        if was != visible {onGeometry?()}
        updateControls()
    }
    func openNow(){guard eligible else{return};hover.forceOpen();isHidden=false;onGeometry?()}
    @discardableResult func escape()->Bool {guard visible else{return false};hover.fold();releaseFocus();isHidden=true;onGeometry?();return true}
    private func releaseFocus(){if focused {window?.makeFirstResponder(nil);window?.resignKey()}}
    func textDidChange(_ notification:Notification){if let target {controller.setText(input.editor.string,for:target.key)};input.measure();updateControls()}
    private func updateControls(){prompt.isHidden = !input.editor.string.isEmpty;send.isEnabled = target.map{!controller.bubblePending($0.key)} == true && !submitting && !input.editor.string.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty;send.alphaValue=send.isEnabled ? 1:0.4;needsLayout=true}
    func submit(){
        guard eligible,!submitting,let target,!controller.bubblePending(target.key),!input.editor.string.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return}
        controller.setText(input.editor.string,for:target.key);submitting=true;releaseFocus();updateControls()
        Task { @MainActor [weak self] in
            guard let self else{return}
            let accepted=await self.controller.sendBubbleReply(target.key)
            self.submitting=false
            if self.target?.key==target.key {
                self.aim(self.target)
                if accepted && self.controller.bubbleProblems[target.key]==nil {self.hover.foldSoon(now:self.now())} else {self.hover.forceOpen()}
            }
            self.onGeometry?();self.updateControls()
        }
    }
    override func layout(){
        super.layout();let line=problem.isEmpty ? CGFloat(0):18
        problemLabel.isHidden=problem.isEmpty;problemLabel.frame=CGRect(x:14,y:5,width:max(0,bounds.width-28),height:18)
        capsule.frame=CGRect(x:10,y:7+line,width:max(1,bounds.width-54),height:fieldHeight+14)
        input.frame=CGRect(x:22,y:14+line,width:max(1,bounds.width-78),height:fieldHeight)
        prompt.frame=CGRect(x:22,y:14+line,width:max(0,bounds.width-78),height:20)
        send.frame=CGRect(x:max(10,bounds.width-38),y:7+line+max(0,fieldHeight+14-28),width:28,height:28)
        input.measure()
    }
}
