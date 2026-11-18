import AppKit

private final class PetWindowCanvas:NSView {
    var dark=false
    override func draw(_ rect:NSRect){(dark ? NSColor(white:0.12,alpha:1):.white).setFill();bounds.fill()}
}
/// AT92 exercises the real panel/controller input paths and the source motion equations with a controlled clock.
@MainActor func petWindowTests(outputDirectory:URL?=nil) async throws {
    let exe=URL(fileURLWithPath:CommandLine.arguments[0]).deletingLastPathComponent()
    let candidate=exe.appendingPathComponent("hejo.app/Contents/Resources/Pet")
    let resource=FileManager.default.fileExists(atPath:candidate.path) ? candidate:URL(fileURLWithPath:"app/.build/hejo.app/Contents/Resources/Pet")
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),atlas=try SpriteAtlas(resourceDirectory:resource),c=PetController(store:store,atlas:atlas)
    let screen=PetDisplay(frame:CGRect(x:0,y:0,width:1500,height:1100),visible:CGRect(x:0,y:30,width:1500,height:1040))
    c.displays={ [screen,PetDisplay(frame:CGRect(x:1500,y:0,width:1200,height:1000),visible:CGRect(x:1500,y:30,width:1200,height:940))] }
    c.reducedMotion={true};c.pet.reduceMotion={true};c.pet.pointerLocation={CGPoint(x:-1000,y:-1000)}
    c.resetPosition()
    try check(c.placementTarget!.anchorOrigin.x == 1500-192-30 && c.placementTarget!.anchorOrigin.y==55,"AT92 initial bottom right")
    c.placePet(at:CGPoint(x:650,y:800));c.show()
    defer{c.panel.orderOut(nil)}
    let editor=NSTextView(frame:CGRect(x:0,y:0,width:200,height:100));editor.isEditable=true
    c.pet.installConversation(editor);c.onFocus={c.panel.makeFirstResponder(editor)}
    c.showChat();try check(c.panel.isKeyWindow && c.panel.firstResponder === editor,"AT92 opening focuses actual text editor")
    let h=c.placementTarget!.globalBubble.height
    c.beginChatDrag(at:CGPoint(x:700,y:820));let held=c.placementTarget!.globalBubble
    c.fitOpenThread(h+150);try check(c.placementTarget!.globalBubble==held,"AT92 incoming height cannot re-place held header")
    c.moveChatDrag(to:CGPoint(x:800,y:700))
    try check(abs(c.placementTarget!.globalBubble.height-h)<0.01,"AT92 header drag preserves height")
    c.moveChatDrag(to:CGPoint(x:1950,y:700));c.endChatDrag();c.fitOpenThread(nil)
    try check(c.placementTarget!.globalBubble.minX>=1512 && abs(c.placementTarget!.globalBubble.height-h)<0.01,"AT92 header crosses screen with pointer and fixed height")
    c.preferredChatSize=CGSize(width:700,height:600);c.placePet(at:CGPoint(x:650,y:800))
    let edge=c.pet.placement!.bubbleRect
    let double=NSEvent.mouseEvent(with:.leftMouseDown,location:CGPoint(x:edge.minX+1,y:edge.midY),modifierFlags:[],timestamp:0,windowNumber:c.panel.windowNumber,context:nil,eventNumber:1,clickCount:2,pressure:1)!
    c.pet.mouseDown(with:double)
    try check(c.preferredChatSize==PetController.defaultChatSize,"AT92 edge double click resets size")
    try check(!PetLayout.resizeRegions(bubble:edge,below:true).isEmpty,"AT92 shared edge cursor regions")
    c.collapseChat()
    let cell=c.pet.spriteRect
    let grip=stride(from:cell.minY,to:cell.maxY,by:2).lazy.flatMap{y in stride(from:cell.minX,to:cell.maxX,by:2).map{CGPoint(x:$0,y:y)}}.first{c.pet.spriteContains($0)}!
    func mouse(_ count:Int,_ type:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:type,location:grip,modifierFlags:[],timestamp:0,windowNumber:c.panel.windowNumber,context:nil,eventNumber:1,clickCount:count,pressure:1)!}
    c.pet.mouseDown(with:mouse(1,.leftMouseDown));c.pet.mouseUp(with:mouse(1,.leftMouseUp));try check(c.chatExpanded,"AT92 first click opens")
    c.pet.mouseDown(with:mouse(2,.leftMouseDown));c.pet.mouseUp(with:mouse(2,.leftMouseUp));try check(c.chatExpanded,"AT92 second double click ignored")
    let other=NSWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[],backing:.buffered,defer:false)
    let outside=NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:other.windowNumber,context:nil,eventNumber:2,clickCount:2,pressure:1)!
    c.canCollapse={false};c.handleOutsideClick(outside);try check(c.chatExpanded,"AT92 file picking protects outside click")
    c.canCollapse={true};c.handleOutsideClick(outside);try check(!c.chatExpanded,"AT92 own other-window double click folds")
    for (code,key,action) in [(8,"ㅊ","copy:"),(9,"ㅍ","paste:"),(7,"ㅌ","cut:"),(0,"ㅁ","selectAll:"),(6,"ㅋ","undo:")] {
        let event=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:c.panel.windowNumber,context:nil,characters:key,charactersIgnoringModifiers:key,isARepeat:false,keyCode:UInt16(code))!
        try check(PetPanel.editAction(for:event)==Selector(action),"AT92 Korean edit key \(code)")
    }
    c.showChat();editor.string="가짜 글"
    let selectAll=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:c.panel.windowNumber,context:nil,characters:"ㅁ",charactersIgnoringModifiers:"ㅁ",isARepeat:false,keyCode:0)!
    try check(c.panel.performKeyEquivalent(with:selectAll) && editor.selectedRange().length==editor.string.utf16.count,"AT92 Korean command routes through actual responder")
    editor.setMarkedText("한",selectedRange:NSRange(location:1,length:0),replacementRange:NSRange(location:NSNotFound,length:0))
    c.panel.cancelOperation(nil);try check(c.chatExpanded,"AT92 composed escape stays with input method");editor.unmarkText();c.collapseChat()
    var now=100.0;c.clock={now};c.pet.activityNow={now};c.pet.bubbleNow={now}
    let key=ConversationKey(employee:"alpha",thread:"fake-thread")
    c.pet.bubbleNotice = .init(kind:.reply,headline:"직원 A · 새 메시지",detail:"새 답",key:key,id:"fake-answer",body:"답",until:Date(timeIntervalSince1970:112))
    try check(c.pet.bubbleShown,"AT92 new reply pops surface")
    now=103;c.pet.updateFoldedBubble();try check(!c.pet.bubbleShown && c.pet.bubbleNotice.until==Date(timeIntervalSince1970:112),"AT92 pop three seconds; content twelve seconds")
    c.pet.bubbleNotice = .init(kind:.approval,headline:"직원 A · 답변이 필요해요",detail:"확인",key:key)
    now=120;c.pet.updateFoldedBubble();try check(c.pet.bubbleShown && c.pet.foldedBubble.buttons.isEmpty,"AT92 approval held without buttons")
    c.pet.bubbleNotice = .init(kind:.writing,headline:"답변을 생각하고 있어요",detail:"직원 A, 직원 B 작성 중…",key:key)
    try check(c.pet.foldedBubble.buttons.isEmpty,"AT92 writing has no button")
    c.pet.bubbleNotice = .init(kind:.idle,headline:"",detail:"",key:nil)
    c.pet.reduceMotion={false};c.pet.bubbleAlwaysShown=true
    await pause(0.08)
    let fadeIn=c.pet.foldedBubble.layer?.presentation()?.opacity ?? Float(c.pet.foldedBubble.alphaValue)
    try check(fadeIn>0 && fadeIn<1,"AT92 real 0.18 fade intermediate frame")
    await pause(0.12);c.pet.bubbleAlwaysShown=false;await pause(0.21)
    try check(c.pet.foldedBubble.isHidden,"AT92 faded surface stowed")
    c.pet.reduceMotion={true}
    c.pet.disarmBubbleHover();let head=c.pet.placement!.globalSprite
    var pointer=CGPoint(x:PetLayout.visibleSprite(in:head).midX,y:PetLayout.visibleSprite(in:head).midY)
    c.pet.pointerLocation={pointer};c.pet.animate();try check(!c.pet.bubbleShown && !c.pet.hoverArmed,"AT92 folding pointer does not reopen bubble")
    pointer=CGPoint(x:-1000,y:-1000);c.pet.animate();pointer=CGPoint(x:PetLayout.visibleSprite(in:head).midX,y:PetLayout.visibleSprite(in:head).midY);c.pet.animate()
    try check(c.pet.bubbleShown && c.pet.hoverArmed,"AT92 leave then visit arms hover")
    c.panel.orderOut(nil);c.pet.bubbleNotice = .init(kind:.approval,headline:"확인",detail:"",key:key);c.pet.updateFoldedBubble();try check(!c.pet.bubbleShown,"AT92 hidden pet has no alert surface")
    c.show();c.pet.pointerLocation={CGPoint(x:-1000,y:-1000)};c.pet.hasAsked=false;c.pet.bubbleNotice = .init(kind:.idle,headline:"",detail:"",key:nil)
    c.pet.animate();now+=181;c.pet.animate();try check(c.pet.displayedFrame.row==11 && PetAnimationTimeline.dozeZs(column:PetAnimationTimeline.dozeStill).count==3,"AT92 folded quiet pet dozes with Zzz")
    c.showChat();c.pet.animate();try check(c.pet.displayedFrame.row != 11,"AT92 open pet never dozes")
    c.pet.hasAsked=true;c.pet.animate();try check(c.pet.displayedFrame.row==6,"AT92 approval even while conversation open")
    c.pet.hasAsked=false;c.pet.homeConversation=true;c.pet.isTyping=true;c.pet.animate();try check(c.pet.displayedFrame.row==8,"AT92 home writing behavior")
    c.pet.isTyping=false;c.pet.noteSend();now+=0.01;c.pet.animate();try check(c.pet.displayedFrame.row==3,"AT92 home send waves")
    c.pet.homeConversation=false;c.pet.noteSend();now+=1;c.pet.animate();try check(c.pet.displayedFrame.row != 3,"AT92 wave only home")
    c.reducedMotion={false};c.pet.reduceMotion={false};c.collapseChat();now+=0.12;c.stepTransition();let partial=c.transitionProgress
    try check(partial>0 && partial<1 && c.pet.genie.blurredImage != nil,"AT92 real blurred genie middle")
    c.showChat();try check(abs(c.transitionProgress-partial)<0.00001,"AT92 reversal starts at current progress")
    now+=0.15;c.stepTransition();let reversed=c.transitionProgress;try check(c.transitionProgress>partial && c.transitionProgress<1,"AT92 reverse continues rather than restarts")
    now+=0.2;c.stepTransition()
    let startWidth=c.pet.placement!.globalBubble.width
    c.toggleChatWidth();now+=0.15;c.stepPlacement();let midWidth=c.pet.placement!.globalBubble.width
    try check(abs(midWidth-(startWidth+c.preferredChatSize.width)/2)<0.01 && c.pet.widthCoverVisible,"AT92 width smoothstep midpoint and cover")
    now+=0.151;c.stepPlacement();try check(c.pet.widthCoverVisible,"AT92 width cover stays until final fade")
    now+=0.061;c.stepPlacement();try check(!c.pet.widthCoverVisible,"AT92 width final 0.06 fade")
    var follow=PetBubbleMotion();follow.retarget(.zero,visibleFrame:screen.visible,now:0,immediately:true,size:CGSize(width:100,height:50));let start=follow.step(now:0)
    follow.retarget(CGPoint(x:500,y:500),visibleFrame:screen.visible,now:0,size:CGSize(width:100,height:50));let step=follow.step(now:0.016)
    try check(abs(step.x-(start.x+(500-start.x)*(1-exp(-0.016/0.065))))<0.00001,"AT92 follow tau 0.065")
    var glide=PetBubbleMotion();glide.retarget(.zero,visibleFrame:screen.visible,now:0,immediately:true,size:CGSize(width:100,height:50));glide.glide(now:0);glide.retarget(CGPoint(x:500,y:500),visibleFrame:screen.visible,now:0,size:CGSize(width:100,height:50));let slow=glide.step(now:0.016)
    try check(slow.x<step.x,"AT92 transition glide tau 0.105 starts immediately")
    c.reducedMotion={true};c.placePet(at:CGPoint(x:650,y:1080));try check(c.panel.level.rawValue==NSWindow.Level.mainMenu.rawValue+1,"AT92 menu bar layer")
    try check(c.pet.toolTip=="hejo · 클릭: 열기 · 드래그: 이동 · 오른쪽 클릭: 메뉴","AT92 dynamic identity tooltip")
    var pressed=0;c.pet.onClick={pressed+=1};try check(c.pet.accessibilityPerformPress() && pressed==1,"AT92 accessibility press")
    let delegate=AppDelegate(),menu=delegate.makeEditMenu()
    try check(menu.items[1].submenu!.items.filter{!$0.isSeparatorItem}.map(\.title)==["실행 취소","실행 복귀","오려두기","복사하기","붙여넣기","전체 선택"] && menu.items[1].submenu!.items[2].isSeparatorItem,"AT92 edit menu source order")
    if let outputDirectory {
        try capturePetWindows(c,output:outputDirectory)
        let samples:[String:Any] = ["followX":step.x,"followY":step.y,"glideX":slow.x,"glideY":slow.y,"genieHalf":reversed,"widthDuration":ChatWidthSlide.duration,"widthFade":ChatWidthSlide.fadeDuration,"dragRows":[PetAnimationTimeline.dragAnimation(horizontalDelta:-2).rawValue,PetAnimationTimeline.dragAnimation(horizontalDelta:2).rawValue],"dozeZs":PetAnimationTimeline.dozeZs(column:PetAnimationTimeline.dozeStill).count,"widthStart":startWidth,"widthMiddle":midWidth]
        try JSONSerialization.data(withJSONObject:samples,options:.prettyPrinted).write(to:outputDirectory.appendingPathComponent("product-motion.json"))
    }
    print("AT-HF-92 APP PASS")
}

@MainActor private func capturePetWindows(_ c:PetController,output:URL) throws {
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    let canvas=PetWindowCanvas(frame:CGRect(x:0,y:0,width:760,height:300))
    let window=NSWindow(contentRect:canvas.bounds,styleMask:[],backing:.buffered,defer:false);window.contentView=canvas;window.isReleasedWhenClosed=false;window.orderFrontRegardless()
    defer{window.orderOut(nil)}
    for dark in [false,true] {
        canvas.dark=dark;let appearance=NSAppearance(named:dark ? .darkAqua:.aqua)!
        NSApp.appearance=appearance;window.appearance=appearance;canvas.appearance=appearance
        canvas.subviews.forEach{$0.removeFromSuperview()}
        for (i,kind) in [BubbleReveal.Kind.approval,.writing,.reply].enumerated(){
            let v=FoldedBubbleView(frame:CGRect(x:15+CGFloat(i)*246,y:160,width:231,height:kind == .reply ? 90:56));v.appearance=appearance
            v.headline=kind == .approval ? "직원 A · 답변이 필요해요":kind == .writing ? "답변을 생각하고 있어요":"직원 A · 새 메시지"
            v.detail=kind == .writing ? "직원 A, 직원 B 작성 중…":"확인할 내용이 있어요";v.kind=kind;v.sender="직원 A";v.avatar=ProfileAvatar(color:.systemPurple);v.actions=kind == .reply ? BubbleReveal.Notice.buttons("https://example.com/answer"):[];v.reduceMotion={true};canvas.addSubview(v)
        }
        appearance.performAsCurrentDrawingAppearance{canvas.layoutSubtreeIfNeeded();canvas.needsDisplay=true;window.display()}
        let bitmap=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(dark ? "task41-hejo-dark.png":"task41-hejo-light.png"))
    }
}
