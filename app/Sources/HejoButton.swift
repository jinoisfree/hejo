import AppKit

/// One tracking area per control. Siblings in the same row share hover emphasis.
class HejoButton: NSButton {
    static func pillPath(_ rect:NSRect)->NSBezierPath {NSBezierPath(roundedRect:rect,xRadius:rect.height/2,yRadius:rect.height/2)}
    enum Shape { case pill, circle, text }
    enum Tone { case neutral, blue, green, outline }
    private(set) var hovered = false
    private var area: NSTrackingArea?
    var shape: Shape = .pill, emphasized = false, greenAccent = false, result = false, blueResult = false
    var replyIcon: String?, usesReplyStyle = false
    var truncatesTitle=false
    var countdownCircle=false
    private var circular:Bool { shape == .circle || countdownCircle && (remaining?() ?? 0)>0 }
    var remaining: (() -> Double)?
    private var animation: Timer?
    var performAction: (() -> Void)?
    @objc private func activate() { performAction?() }
    func configure(_ label: String, icon: String? = nil, shape: Shape = .pill, primary: Bool = false,
                   green: Bool = false, action: @escaping () -> Void) {
        title=label; setAccessibilityLabel(label); toolTip=label; focusRingType = .exterior
        replyIcon=icon; self.shape=shape; emphasized=primary; greenAccent=green; usesReplyStyle=true
        wantsLayer=true;isBordered=false; target=self; self.action=#selector(activate); performAction=action
        invalidateIntrinsicContentSize(); needsDisplay=true
    }
    override var intrinsicContentSize: NSSize {
        guard usesReplyStyle else { return super.intrinsicContentSize }
        if circular { return NSSize(width:22,height:22) }
        let width=(title as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.medium)]).width
        return NSSize(width:ceil(width)+16+(replyIcon == nil ? 0:17),height:26)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area); self.area=nil }
        guard usesReplyStyle else { return }
        let area=NSTrackingArea(rect:.zero,options:[.activeAlways,.inVisibleRect,.mouseEnteredAndExited],owner:self,userInfo:nil)
        addTrackingArea(area); self.area=area
    }
    private var siblings: [HejoButton] { superview?.subviews.compactMap { $0 as? HejoButton } ?? [] }
    private func hover(_ on:Bool) {
        hovered=on
        for sibling in siblings { if on && sibling !== self { sibling.hovered=false }; sibling.needsDisplay=true }
        needsDisplay=true
    }
    override func mouseEntered(with event:NSEvent) { super.mouseEntered(with:event); hover(true) }
    override func mouseExited(with event:NSEvent) { super.mouseExited(with:event); hover(false) }
    var tone: Tone {
        if result { return greenAccent ? .green:blueResult ? .blue:.neutral }
        if hovered && isEnabled { return greenAccent ? .green:.blue }
        if emphasized { return siblings.contains(where: { $0.hovered && $0 !== self }) ? .outline:.blue }
        return .neutral
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); animation?.invalidate(); animation=nil
        if window != nil, remaining != nil {
            animation=Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] timer in
                MainActor.assumeIsolated { self?.needsDisplay=true; if (self?.remaining?() ?? 0) <= 0 { self?.invalidateIntrinsicContentSize();timer.invalidate() } }
            }
        }
    }
    override func draw(_ dirtyRect:NSRect) {
        guard usesReplyStyle else { super.draw(dirtyRect); return }
        let style=tone, rect=bounds.insetBy(dx:0.5,dy:0.5)
        let path=Self.pillPath(rect)
        let tint:NSColor = style == .green ? .systemGreen:.systemBlue
        let counting=(remaining?() ?? 0)>0
        let filled=(style == .blue || style == .green) && !counting
        if let layer {
            layer.shadowOpacity=filled && shape != .text ? 0.35:0
            layer.shadowRadius=7;layer.shadowOffset=CGSize(width:0,height:-2)
            layer.shadowColor=tint.cgColor
            layer.shadowPath=CGPath(roundedRect:rect,cornerWidth:rect.height/2,cornerHeight:rect.height/2,transform:nil)
        }
        if shape != .text {
            (filled ? tint:NSColor.labelColor.withAlphaComponent(0.08)).setFill();path.fill()
            (style == .outline ? tint:NSColor.white.withAlphaComponent(0.22)).setStroke();path.lineWidth=1;path.stroke()
        }
        if let fraction=remaining?(),fraction>0 {
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let fill=blueResult ? NSColor.systemBlue:NSColor.systemGreen
            fill.withAlphaComponent(0.55).setFill()
            if circular {
                let pie=NSBezierPath(), center=NSPoint(x:rect.midX,y:rect.midY)
                pie.move(to:center);pie.appendArc(withCenter:center,radius:rect.height/2,startAngle:90,endAngle:90+360*min(1,fraction));pie.close();pie.fill()
            } else {
                NSRect(x:rect.minX,y:rect.minY,width:rect.width*min(1,fraction),height:rect.height).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        let ink:NSColor = !isEnabled ? .disabledControlTextColor : filled ? .white:.labelColor
        let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:ink]
        if truncatesTitle {
            let paragraph=NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail;paragraph.alignment = .center
            var textStyle=attrs;textStyle[.paragraphStyle]=paragraph;textStyle[.font]=font ?? NSFont.systemFont(ofSize:11)
            let height=(title as NSString).size(withAttributes:textStyle).height
            (title as NSString).draw(in:NSRect(x:6,y:bounds.midY-height/2,width:max(0,bounds.width-12),height:ceil(height)),withAttributes:textStyle)
            return
        }
        let icon = countdownCircle && !circular ? nil:replyIcon
        let label=(circular && icon != nil ? "":circular ? String(title.prefix(1)):title) as NSString
        let size=label.size(withAttributes:attrs)
        let gap:CGFloat=icon == nil || label.length==0 ? 0:4
        var x=(bounds.width-size.width-(icon == nil ? 0:13)-gap)/2
        if let icon {
            FileTile.symbol(icon,point:12,at:NSPoint(x:x+6.5,y:bounds.midY),color:style == .outline ? tint:ink)
            x+=13+gap
        }
        label.draw(at:NSPoint(x:x,y:bounds.midY-size.height/2),withAttributes:attrs)
    }
}

@MainActor final class QuestionControls: NSStackView {
    static let resendPrompt="이미 갔다면 직원이 같은 답을 두 번 받을 수 있어요. 다시 보낼까요?"
    let line=NSStackView()
    private let controller:ConversationController, row:QuestionRow, key:ConversationKey
    private let choose:(MessageButton,String?)->Void
    private let commentField=NSTextField()
    private var commentButton:MessageButton?
    init(_ row:QuestionRow,key:ConversationKey,controller:ConversationController,circles:Bool,
         selected:String?=nil, editing:MessageButton?=nil, onEdit:@escaping(MessageButton)->Void,
         choose:@escaping(MessageButton,String?)->Void) {
        self.controller=controller;self.row=row;self.key=key;self.choose=choose
        super.init(frame:.zero);orientation = .vertical;alignment = .leading;spacing=3
        line.spacing=circles ? 3:5;addArrangedSubview(line)
        if controller.replyRequests.values.contains(where:{$0.question==row.messageID}) {
            line.addArrangedSubview(NSTextField(labelWithString:"확인 중"));return
        }
        if let answer=row.answer {
            let result=answer.result ?? answer.text ?? "답함",button=HejoButton(frame:.zero)
            button.configure(result,primary:true,green:answer.role=="approve" && (row.buttons.first{$0.label==answer.label}?.accent=="green" || answer.label=="승인")) { [weak controller] in
                guard let controller, controller.undoEnd(answer)>controller.clock() else{return}
                Task {await controller.requestReply("retract",question:row.messageID,key:key,answerID:answer.answerID)}
            }
            button.countdownCircle=circles;button.replyIcon=row.buttons.first{$0.label==answer.label}?.icon
            button.result=true;button.blueResult=row.buttons.contains{$0.label.contains("메모")} || answer.label?.contains("메모")==true
            if answer.undoUntil != nil {let end=controller.undoEnd(answer),duration=controller.undoDuration(answer);button.remaining={ [weak controller] in end.timeIntervalSince(controller?.clock() ?? Date())/duration }}
            line.addArrangedSubview(button)
            if answer.delivery=="unknown" {
                addArrangedSubview(NSTextField(labelWithString:"직원에게 갔는지 확인 못 했어요"))
                let resend=HejoButton(frame:.zero)
                resend.configure("다시 보내기") { [weak self] in self?.confirmResend(answer.answerID) }
                addArrangedSubview(resend)
            }
        }
        for (index,option) in row.buttons.enumerated() where row.answer==nil || option.repeat==true {
            let button=FileChip(title:option.label);button.replyWord=option.label
            let action:()->Void={ [weak self] in
                if option.acceptsComment {onEdit(option)} else {self?.choose(option,nil)}
            }
            button.configure(option.label,icon:option.icon,shape:circles ? .circle:.pill,
                primary:selected.map{$0==option.id} ?? option.primary ?? (index==0),green:option.accent=="green",action:action)
            button.invoke=action;button.isEnabled=controller.canSend
            line.addArrangedSubview(button)
            if circles {button.widthAnchor.constraint(equalToConstant:22).isActive=true;button.heightAnchor.constraint(equalToConstant:22).isActive=true}
        }
        if let editing,row.answer==nil {
            commentButton=editing;let input=NSStackView()
            commentField.placeholderString="의견";commentField.stringValue=controller.commentDrafts[row.messageID] ?? ""
            commentField.delegate=self;commentField.target=self;commentField.action=#selector(submit)
            commentField.widthAnchor.constraint(equalToConstant:145).isActive=true;input.addArrangedSubview(commentField)
            let send=HejoButton(frame:.zero);send.configure("보내기"){ [weak self] in self?.submit() };input.addArrangedSubview(send);addArrangedSubview(input)
        }
    }
    func confirmResend(_ id:String) {
        let alert=NSAlert();alert.messageText=Self.resendPrompt;alert.addButton(withTitle:"그만두기");alert.addButton(withTitle:"다시 보내기")
        let decide:(NSApplication.ModalResponse)->Void={ [weak self] choice in
            guard let self,choice == .alertSecondButtonReturn else{return}
            Task {await self.controller.requestReply("redeliver",question:self.row.messageID,key:self.key,answerID:id)}
        }
        if let window {alert.beginSheetModal(for:window,completionHandler:decide)} else {decide(alert.runModal())}
    }
    @objc private func submit() {
        guard let commentButton else{return}
        let text=commentField.stringValue
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.unicodeScalars.count<=4000 else{return}
        choose(commentButton,text)
    }
    required init?(coder:NSCoder){fatalError()}
}
extension QuestionControls: NSTextFieldDelegate {
    func controlTextDidChange(_ notification:Notification) {controller.commentDrafts[row.messageID]=commentField.stringValue}
}
