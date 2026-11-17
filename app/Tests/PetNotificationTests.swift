import AppKit

private final class NotificationCanvas:NSView {
    override func draw(_ dirtyRect:NSRect){NSColor.white.setFill();bounds.fill()}
}
@MainActor func petNotificationTests(resourceDirectory:URL,outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),engine=BubbleReveal(store:store)
    var now=Date(timeIntervalSince1970:1800000000)
    let key=ConversationKey(employee:"alpha",thread:UUID().uuidString.lowercased())
    func message(_ seq:Int,_ text:String="새 답 첫 줄\n둘째 줄",asked:Bool=false)->ConversationMessage {
        ConversationMessage(id:UUID().uuidString.lowercased(),key:key,role:"employee",text:text,files:[],buttons:[],replyState:asked ? "asked":nil,streaming:false,seq:seq,latestSeq:seq,timestamp:ISO8601DateFormatter().string(from:now),clientMessageID:nil)
    }
    let old=message(1),reply=message(2,"새 답 첫 줄\nhttps://example.com/answer")
    var input=BubbleReveal.Input(messages:[old],names:["alpha":"직원 A"],ready:true)
    try check(!engine.update(input,now:now) && engine.notice.kind == .idle,"AT81 startup messages never nudge")
    input.messages.append(reply)
    try check(engine.update(input,now:now) && engine.notice.kind == .reply,"AT81 fresh reply hops and nudges")
    try check(engine.notice.until==now.addingTimeInterval(12) && engine.notice.detail=="새 답 첫 줄","AT81 twelve seconds and first line")
    try check(engine.notice.actions.map(\.title)==["링크 열기","대화 열기","나중에 알려줘"],"AT81 action order web link")
    try check(BubbleReveal.Notice.buttons("file://blocked/path mailto:blocked").map(\.title)==["대화 열기","나중에 알려줘"],"AT81 unsafe links excluded")
    let asked=message(3,"**확인**해 주세요",asked:true);input.messages.append(asked);input.questions=[asked.id];input.failure=IslandFailure(message:"보내기 실패",retryKey:key,isSend:true);input.typing=[key:now.addingTimeInterval(100)]
    _=engine.update(input,now:now)
    try check(engine.notice.kind == .approval && engine.notice.headline=="직원 A · 답변이 필요해요" && engine.notice.detail=="확인해 주세요","AT81 approval wins all priorities")
    now=now.addingTimeInterval(20);_=engine.update(input,now:now)
    try check(engine.notice.kind == .approval,"AT81 approval stays beyond twelve seconds")
    input.chatOpen=true;input.opened=key;_=engine.update(input,now:now)
    try check(engine.notice.kind == .writing,"AT92 opening dismisses approval; no failure bubble")
    input.chatOpen=false;input.failure=nil;_=engine.update(input,now:now)
    try check(engine.notice.kind == .writing && engine.notice.detail=="직원 A 작성 중…","AT81 typing above reply")
    input.typing=[:];_=engine.update(input,now:now)
    try check(engine.notice.kind == .idle,"AT81 expired answer not resurrected")
    input.questions=[];let next=message(4);input.messages.append(next);_=engine.update(input,now:now)
    now=now.addingTimeInterval(11.99);_=engine.update(input,now:now);try check(engine.notice.kind == .reply,"AT81 reply alive before deadline")
    now=now.addingTimeInterval(0.01);_=engine.update(input,now:now);try check(engine.notice.kind == .idle,"AT81 deadline closes reply")
    let scheduled=message(5);input.messages.append(scheduled);_=engine.update(input,now:now)
    try check(engine.remindLater(now:now) && engine.reminders[scheduled.id]==now.addingTimeInterval(1800).timeIntervalSince1970,"AT81 schedule thirty minutes")
    let restored=BubbleReveal(store:try LocalStore(directory:home));_=restored.update(input,now:now)
    now=now.addingTimeInterval(1799);_=restored.update(input,now:now);try check(restored.notice.kind == .idle,"AT81 reminder not early after relaunch")
    now=now.addingTimeInterval(1);_=restored.update(input,now:now)
    try check(restored.notice.headline=="직원 A · 다시 알림" && restored.reminders.isEmpty,"AT81 reminder survives restart and fires once")
    try check(restored.remindLater(now:now),"AT81 reschedule")
    input.readIDs=[scheduled.id];_=restored.update(input,now:now)
    try check(restored.reminders.isEmpty && restored.notice.kind == .idle,"AT81 read removes reminder")
    input.readIDs=[];input.chatOpen=true;input.messages.append(message(6));_=restored.update(input,now:now);try check(restored.notice.kind == .idle,"AT81 open conversation suppresses new reply")
    input.chatOpen=false;input.muted=[key.employee];let muted=message(7,asked:true);input.messages.append(muted);input.questions=[muted.id];input.typing=[key:now.addingTimeInterval(30)]
    try check(!restored.update(input,now:now) && restored.notice.kind == .idle,"AT81 muted room suppresses approval typing answer hop")
    input.muted=[];input.questions=[];input.typing=[:];input.paused=true;input.messages.append(message(8));try check(!restored.update(input,now:now) && restored.notice.kind == .idle,"AT81 pause consumes fresh events quietly")
    input.paused=false;_=restored.update(input,now:now);try check(restored.notice.kind == .idle,"AT81 pause exit does not repeat reply")
    let mutedReminder=message(9),dueReply=message(10)
    let otherKey=ConversationKey(employee:"beta",thread:UUID().uuidString.lowercased())
    var laterReply=dueReply;laterReply.key=otherKey
    try store.update{$0.reminders=[mutedReminder.id:now.timeIntervalSince1970-2,laterReply.id:now.timeIntervalSince1970-1]}
    let reminders=BubbleReveal(store:store)
    let dueInput=BubbleReveal.Input(messages:[mutedReminder,laterReply],muted:["alpha"],ready:true)
    _=reminders.update(dueInput,now:now);_=reminders.update(dueInput,now:now);_=reminders.update(dueInput,now:now)
    try check(reminders.reminders.isEmpty && reminders.notice.id==laterReply.id,"AT81 muted overdue reminder cannot block other rooms")
    let failureHome=home.appendingPathComponent("failure"),failureStore=try LocalStore(directory:failureHome),failed=BubbleReveal(store:failureStore)
    var failureInput=BubbleReveal.Input(messages:[],names:input.names,ready:true)
    _=failed.update(failureInput,now:now);failureInput.messages=[message(1)];_=failed.update(failureInput,now:now)
    let moved=home.appendingPathComponent("saved-failure")
    try FileManager.default.moveItem(at:failureHome,to:moved);try Data().write(to:failureHome)
    try check(!failed.remindLater(now:now) && failed.notice.kind == .reply && failed.reminders.isEmpty && failed.persistenceFailed,"AT81 failed atomic reminder save keeps actionable reply")
    try FileManager.default.removeItem(at:failureHome);try FileManager.default.moveItem(at:moved,to:failureHome)
    try check(failed.remindLater(now:now) && !failed.persistenceFailed,"AT81 reminder save recovers")
    let controls=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    controls.reducedMotion={true};controls.pet.pointerLocation={CGPoint(x:-5000,y:-5000)};controls.pet.bubbleNow={now.timeIntervalSince1970}
    controls.show()
    controls.pet.bubbleNotice=BubbleReveal.Notice(kind:.reply,headline:"직원 A · 새 메시지",detail:"새 답 첫 줄",key:key,sender:"직원 A",id:next.id,body:"https://example.com/answer",until:now.addingTimeInterval(12))
    controls.pet.avatarForEmployee={_ in ProfileAvatar(color:.systemPurple)}
    controls.pet.unreadCount=12;controls.pet.updateFoldedBubble();controls.pet.foldedBubble.layoutSubtreeIfNeeded()
    try check(controls.pet.foldedBubble.buttons.map(\.title)==["링크 열기","대화 열기","나중에 알려줘"] && controls.pet.foldedSize.height==90,"AT81 native button row changes placement")
    var actions:[BubbleReveal.Action]=[];controls.pet.onBubbleAction={actions.append($0)}
    for button in controls.pet.foldedBubble.buttons {button.performClick(nil)}
    try check(actions==controls.pet.bubbleNotice.actions,"AT81 native button dispatch")
    let button=controls.pet.foldedBubble.buttons[1]
    let point=controls.pet.foldedBubble.convert(CGPoint(x:button.frame.midX,y:button.frame.midY),to:controls.pet)
    try check(controls.pet.hitTest(point)===button,"AT81 pet hit routing reaches native action")
    controls.pet.bubbleNotice=BubbleReveal.Notice(kind:.writing,headline:"답변을 생각하고 있어요",detail:"직원 A 작성 중…",key:key)
    controls.pet.foldedBubble.reduceMotion={false};controls.pet.bubbleAlwaysShown=true;controls.pet.foldedBubble.layoutSubtreeIfNeeded();controls.pet.foldedBubble.tick(at:1,paused:false)
    controls.pet.foldedBubble.interrupted=true;controls.pet.foldedBubble.tick(at:1,paused:false)
    try check(controls.pet.foldedBubble.isShimmering && !controls.pet.foldedBubble.statusDotVisible,"AT81 writing shimmer and badge replace dot")
    try check(controls.pet.thoughtDots.allSatisfy{!$0.isHidden},"AT81 visible bubble thought trail")
    controls.pet.unreadCount=0;controls.pet.updateFoldedBubble();try check(controls.pet.foldedBubble.statusDotVisible,"AT81 writing status dot")
    controls.pet.foldedBubble.reduceMotion={true};controls.pet.foldedBubble.tick(at:1,paused:false);try check(!controls.pet.foldedBubble.isShimmering,"AT81 reduced motion still shimmer")
    var playback=PetChatPlayback()
    try check(playback.update(now:0,reply:true,pointerElapsed:nil,enabled:true)==0,"AT81 answer starts one jump")
    try check(playback.update(now:0.3,reply:true,pointerElapsed:0.0,enabled:true)==0.3,"AT81 jump progresses without restarting")
    try check(playback.update(now:1,reply:false,pointerElapsed:nil,enabled:true)==nil,"AT81 jump completes one pass")
    try check(playback.update(now:2,reply:true,pointerElapsed:nil,enabled:false)==nil,"AT81 reduced motion prevents jump")
    var animationTime:TimeInterval=0
    controls.pet.activityNow={animationTime};controls.pet.reduceMotion={false};controls.pet.hasAsked=false;controls.pet.sendFailed=false;controls.show();controls.pet.requestReplyJump();controls.pet.animate()
    try check(controls.pet.jumpElapsed==0,"AT81 actual pet consumes reply jump")
    animationTime=0.3;controls.pet.animate();try check(controls.pet.jumpElapsed==0.3,"AT81 actual pet continues one jump")
    animationTime=1;controls.pet.animate();try check(controls.pet.jumpElapsed==nil,"AT81 actual pet settles after one jump")
    let origin=controls.panel.convertPoint(toScreen:.zero),head=PetLayout.visibleSprite(in:controls.pet.spriteRect),bubble=controls.pet.placement!.bubbleRect
    controls.pet.bubbleAlwaysShown=false;controls.pet.bubbleNotice=BubbleReveal.Notice(kind:.idle,headline:"hejo",detail:"",key:nil)
    var pointer=CGPoint(x:head.midX+origin.x,y:head.midY+origin.y);controls.pet.pointerLocation={pointer};controls.pet.animate()
    pointer=CGPoint(x:head.midX+origin.x,y:(head.maxY+bubble.minY)/2+origin.y);controls.pet.animate()
    try check(!controls.pet.foldedBubble.isHidden,"AT81 hover bridge keeps bubble reachable from head")
    controls.pet.pointerLocation={CGPoint(x:-5000,y:-5000)};controls.pet.animate()
    controls.pet.reduceMotion={true};controls.pet.requestReplyJump();controls.pet.animate();try check(controls.pet.jumpElapsed==nil,"AT81 actual pet reduced motion")
    controls.pet.bubbleNow={now.addingTimeInterval(3.01).timeIntervalSince1970}
    controls.pet.bubbleAlwaysShown=false;controls.pet.bubbleNotice=BubbleReveal.Notice(kind:.idle,headline:"",detail:"",key:nil);controls.pet.unreadCount=12;controls.pet.updateFoldedBubble()
    try check(controls.pet.unreadBadge.text=="9+" && !controls.pet.unreadBadge.isHidden && controls.pet.thoughtDots.allSatisfy(\.isHidden),"AT81 hidden bubble leaves 9+ badge and no thought trail (source)")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let canvas=NotificationCanvas(frame:CGRect(x:0,y:0,width:750,height:360)),window=NSWindow(contentRect:canvas.bounds,styleMask:[.borderless],backing:.buffered,defer:false)
        window.contentView=canvas;window.isReleasedWhenClosed=false;window.orderFrontRegardless()
        for (i,kind) in [BubbleReveal.Kind.approval,.writing,.reply].enumerated(){let view=FoldedBubbleView(frame:CGRect(x:20+CGFloat(i)*242,y:230,width:231,height:90));view.headline=kind == .approval ? "직원 A · 답변이 필요해요":kind == .writing ? "답변을 생각하고 있어요":"직원 A · 새 메시지";view.detail=kind == .writing ? "직원 A 작성 중…":"새 답 첫 줄";view.kind=kind;view.unread=12;view.avatar=ProfileAvatar(color:.systemPurple);view.sender="직원 A";view.actions=kind == .reply ? BubbleReveal.Notice.buttons("https://example.com/answer"):[];view.reduceMotion={true};canvas.addSubview(view);view.layoutSubtreeIfNeeded();view.tick(at:0,paused:false)}
        controls.panel.orderOut(nil);controls.pet.removeFromSuperview();canvas.addSubview(controls.pet);controls.pet.frame.origin=CGPoint(x:240,y:0)
        await pause(0.1)
        let rep=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:rep);try rep.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task29-hejo.png"));window.orderOut(nil)
    }
    controls.panel.orderOut(nil)
    print("AT-HF-81 PASS")
}
