import AppKit

/// REQ-PP-01..03: observe real view coordinates after controller and mouse input, not just target rectangles.
@MainActor func petPositionTests(resourceDirectory: URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:home) }
    let store=try LocalStore(directory:home), atlas=try SpriteAtlas(resourceDirectory:resourceDirectory)
    let c=PetController(store:store,atlas:atlas)
    defer { c.panel.orderOut(nil) }
    var screens=[PetDisplay(frame:CGRect(x:0,y:0,width:1800,height:1200),visible:CGRect(x:0,y:30,width:1800,height:1140))]
    c.displays={screens}
    var now=100.0;c.clock={now}
    c.reducedMotion={true};c.pet.reduceMotion={true};c.pet.animationsAllowed=false
    let editor=NSTextView();c.pet.installConversation(editor);c.onFocus={c.panel.makeFirstResponder(editor)}
    let web=WebPaneModel(downloads:home.appendingPathComponent("Downloads"));web.persistent=false;web.onExternal={_ in}
    c.installWeb(web)
    defer { web.unload() }
    let page=home.appendingPathComponent("fixture.html")
    try "<html><body>local fixture</body></html>".write(to:page,atomically:true,encoding:.utf8)
    func close(_ a:CGFloat,_ b:CGFloat)->Bool {abs(a-b)<=0.01}
    func same(_ a:CGRect,_ b:CGRect)->Bool {zip([a.minX,a.minY,a.width,a.height],[b.minX,b.minY,b.width,b.height]).allSatisfy{close($0,$1)}}
    func displayed()->CGRect {c.panel.convertToScreen(c.pet.convert(c.pet.spriteRect,to:nil))}
    func expectSeparated(_ label:String) throws {
        for p in [c.placementTarget!,c.pet.placement!] {
            let body=PetLayout.placementSprite(in:p.globalSprite)
            let allowance=p.expanded ? PetLayout.headerPerch:0
            try check(p.globalBubble.maxY <= body.minY+allowance+0.01 || p.globalBubble.minY >= body.maxY-0.01,"\(label) chat must be above or below pet")
            let content=CGRect(x:p.globalBubble.minX,y:p.globalBubble.minY,width:p.globalBubble.width,height:max(0,p.globalBubble.height-allowance))
            let overlap=content.intersection(body)
            try check(overlap.isNull || overlap.width <= 0.01 || overlap.height <= 0.01,"\(label) pet/chat overlap \(overlap)")
            try check(p.contentBubble.width >= 0 && c.pet.paneWidth <= c.pet.placement!.contentBubble.width,"\(label) pane allocation")
        }
        let chat=c.panel.convertToScreen(c.pet.convert(c.pet.placement!.bubbleRect,to:nil))
        let content=CGRect(x:chat.minX,y:chat.minY,width:chat.width,height:max(0,chat.height-(c.pet.placement!.expanded ? PetLayout.headerPerch:0)))
        let overlap=content.intersection(PetLayout.placementSprite(in:displayed()))
        try check(overlap.isNull || overlap.width <= 0.01 || overlap.height <= 0.01,"\(label) actual view overlap")
    }
    func expectSprite(_ r:CGRect,_ label:String) throws {
        try expectSeparated(label)
        try check(same(c.placementTarget!.globalSprite,r) && same(c.pet.placement!.globalSprite,r) && same(displayed(),r),"\(label) expected=\(r) target=\(c.placementTarget!.globalSprite) shown=\(c.pet.placement!.globalSprite) view=\(displayed())")
    }
    func settle(){now+=1;c.stepTransition();c.stepPlacement()}
    // T1: transitions, reversals and drawer/web changes leave the independently constrained pet untouched.
    for point in [CGPoint(x:700,y:650),CGPoint(x:-30,y:30),CGPoint(x:1600,y:30),CGPoint(x:-30,y:1000),CGPoint(x:1600,y:1000)] {
        c.collapseChat();settle();c.placePet(at:point);c.endPetDrag()
        let initial=c.placementTarget!.globalSprite, x=store.settings.petX,y=store.settings.petY
        for reduced in [true,false] {
            c.reducedMotion={reduced};c.pet.reduceMotion={reduced}
            c.showChat()
            for _ in 0..<4 {now+=0.03;c.stepTransition();try expectSprite(initial,"T1 open frames")}
            c.collapseChat();try expectSprite(initial,"T1 reversal")
            settle();c.showChat();settle()
            c.setDrawerOpen(true)
            for _ in 0..<20 {now+=0.02;c.stepPlacement();try expectSprite(initial,"T1 drawer frames")}
            web.open(page,ephemeral:true);settle();try expectSprite(initial,"T1 web opens")
            for tab in web.tabs {try check(!tab.view.configuration.websiteDataStore.isPersistent,"T1 isolated web")}
            web.close();settle();try expectSprite(initial,"T1 web closes")
            c.collapseChat();settle();try expectSprite(initial,"T1 closes")
            c.setDrawerOpen(false);settle()
            try check(store.settings.petX==x && store.settings.petY==y,"T1 no position persistence on open/close")
        }
    }
    c.reducedMotion={true};c.pet.reduceMotion={true}
    // T2: real PetView input methods, grabbed point and accumulated pointer displacement.
    for state in 0..<3 {
        c.collapseChat();settle();c.placePet(at:CGPoint(x:700,y:650))
        if state>0 {c.showChat();settle()}
        if state==2 {c.reducedMotion={false};c.collapseChat();now+=0.06;c.stepTransition()}
        let start=c.pet.placement!.globalSprite, size=c.preferredChatSize
        let cell=c.pet.spriteRect
        let grip=stride(from:cell.minY,to:cell.maxY,by:2).lazy.flatMap { y in stride(from:cell.minX,to:cell.maxX,by:2).map{CGPoint(x:$0,y:y)} }.first{c.pet.spriteContains($0)}!
        let press=c.panel.convertPoint(toScreen:grip);var pointer=press;c.pet.pointerLocation={pointer}
        func event(_ type:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:type,location:grip,modifierFlags:[],timestamp:now,windowNumber:c.panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!}
        c.pet.mouseDown(with:event(.leftMouseDown))
        for delta in [CGPoint(x:60,y:40),CGPoint(x:-30,y:-50),CGPoint(x:0,y:80),CGPoint(x:90,y:0),CGPoint.zero] {
            pointer=CGPoint(x:press.x+delta.x,y:press.y+delta.y)
            c.pet.mouseDragged(with:event(.leftMouseDragged))
            try expectSprite(start.offsetBy(dx:delta.x,dy:delta.y),"T2 every input follows pointer")
            try check(c.preferredChatSize==size,"T2 preferred size unchanged")
        }
        let expanded=c.chatExpanded;c.pet.mouseUp(with:event(.leftMouseUp));settle()
        try expectSprite(start,"T2 release without jump");try check(c.chatExpanded==expanded,"T2 release without click toggle")
        c.reducedMotion={true}
    }
    // T3: pet placement bounds, independent of an oversized chat; negative-origin display and removal.
    screens=[PetDisplay(frame:CGRect(x:-1400,y:-200,width:1400,height:1000),visible:CGRect(x:-1400,y:-170,width:1400,height:940))]
    c.collapseChat();settle();c.placePet(at:CGPoint(x:-800,y:100));c.showChat();settle()
    c.preferredChatSize=CGSize(width:3000,height:3000)
    for origin in [CGPoint(x:-5000,y:-5000),CGPoint(x:5000,y:5000),CGPoint(x:-800,y:100)] {
        c.movePet(to:origin)
        let visible=PetLayout.placementSprite(in:c.placementTarget!.globalSprite)
        try check(visible.minX >= -1396-0.01 && visible.maxX <= -4+0.01 && visible.minY >= -166-0.01 && visible.maxY <= 800+0.01,"T3 pet-only screen bound")
        try check(screens[0].visible.contains(c.placementTarget!.globalBubble),"T3 independent chat bound")
    }
    c.movePet(to:CGPoint(x:-800,y:100));try expectSprite(CGRect(x:-800,y:100,width:192,height:208),"T3 return from boundary")
    screens=[PetDisplay(frame:CGRect(x:0,y:0,width:1800,height:1200),visible:CGRect(x:0,y:30,width:1800,height:1140))]
    c.screensChanged();try check(screens[0].visible.contains(c.placementTarget!.globalBubble),"T3 removed screen recovery")
    // T4: moved header stays independent; automatic size changes hold the current pet-facing edge.
    for initialY:CGFloat in [100,850] {
        c.collapseChat();settle();c.preferredChatSize=CGSize(width:500,height:300);c.placePet(at:CGPoint(x:700,y:initialY));c.showChat();settle()
        let start=c.placementTarget!,mouse=CGPoint(x:900,y:600), delta=CGPoint(x:40,y:20)
        c.beginChatDrag(at:mouse);c.moveChatDrag(to:CGPoint(x:mouse.x+delta.x,y:mouse.y+delta.y))
        let moved=c.placementTarget!
        try check(same(moved.globalBubble,start.globalBubble.offsetBy(dx:40,dy:20)),"T4 header translates chat")
        try expectSprite(start.globalSprite.offsetBy(dx:40,dy:20),"T4 header translates pet")
        c.endChatDrag();settle();try check(same(c.placementTarget!.globalBubble,moved.globalBubble),"T4 header release holds chat")
        for height:CGFloat in [380,300] {
            let b=c.placementTarget!,pet=b.globalSprite
            c.preferredChatSize.height=height;c.placePet(at:b.anchorOrigin);settle()
            let changed=c.placementTarget!
            try check(close(changed.globalBubble.minX,b.globalBubble.minX) && close(changed.bubbleBelow ? changed.globalBubble.maxY:changed.globalBubble.minY,b.bubbleBelow ? b.globalBubble.maxY:b.globalBubble.minY),"T4 automatic fixed edge")
            try expectSprite(pet,"T4 automatic resize leaves pet")
        }
        for action in [{c.fitOpenThread(400)}, {c.fitOpenThread(nil)}, {c.toggleChatWidth()}, {c.toggleChatWidth()}, {c.resetChatSize()}, {c.preferredChatSize.width+=20;c.placePet(at:c.placementTarget!.anchorOrigin)}, {c.screensChanged()}] {
            let old=c.placementTarget!;action();settle()
            try expectSprite(old.globalSprite,"T4 automatic reflow never reattaches")
            try check(close(c.placementTarget!.globalBubble.minX,old.globalBubble.minX),"T4 reflow keeps left edge")
        }
        let before=c.placementTarget!
        c.pet.onResize?(.right,CGPoint(x:30,y:0));c.endPetDrag();settle()
        try check(close(c.placementTarget!.contentBubble.midX,before.contentBubble.midX),"T4 horizontal resize current chat center")
        try expectSprite(before.globalSprite,"T4 resize no pet movement")
        let vertical=c.placementTarget!
        // Resize away from the pet; growth into it is handled by the T6 collision exception.
        c.pet.onResize?(.near,CGPoint(x:0,y:vertical.bubbleBelow ? -20:20));c.endPetDrag();settle()
        try check(close(vertical.bubbleBelow ? vertical.globalBubble.minY:vertical.globalBubble.maxY,vertical.bubbleBelow ? c.placementTarget!.globalBubble.minY:c.placementTarget!.globalBubble.maxY),"T4 near resize opposite edge")
        web.open(page,ephemeral:true);settle();let opened=c.placementTarget!
        c.movePet(to:CGPoint(x:opened.anchorOrigin.x+20,y:opened.anchorOrigin.y+10));let last=c.placementTarget!.globalSprite
        web.close();settle();try expectSprite(last,"T4 web close keeps last pet position")
    }
    // T6: captured physical-drag regression and constrained displays, including intermediate frames.
    let perched=PetPlacement(spriteOrigin:CGPoint(x:700,y:850),scale:1,visibleFrame:screens[0].visible,expanded:true,preferredSize:CGSize(width:428,height:300),below:true)
    try check(close(perched.globalBubble.maxY,PetLayout.placementSprite(in:perched.globalSprite).minY+PetLayout.headerPerch),"T6 pet perches on top header edge without moving")

    let fixtureSprite=CGRect(x:1151,y:406,width:192,height:208)
    let fixtureChat=CGRect(x:1050,y:134,width:428,height:500)
    let fixtureScreen=CGRect(x:0,y:30,width:1512,height:1050)
    let repaired=PetLayout.constrainedBubble(fixtureChat,screen:fixtureScreen,avoiding:fixtureSprite)
    try check(!repaired.intersects(PetLayout.placementSprite(in:fixtureSprite)),"T6 captured overlap is repaired")
    let body=PetLayout.placementSprite(in:fixtureSprite)
    try check(repaired.minY >= body.maxY && repaired.width==fixtureChat.width && repaired.height==493,"T6 uses vertical room instead of moving beside pet")
    let beside=CGRect(x:600,y:300,width:428,height:500)
    let vertical=PetLayout.constrainedBubble(beside,screen:fixtureScreen,avoiding:fixtureSprite)
    try check(vertical.maxY <= body.minY || vertical.minY >= body.maxY,"T6 repairs an already nonoverlapping lateral placement")
    try check(vertical.minX <= body.midX && vertical.maxX >= body.midX,"T6 keeps pet over the conversation")
    for origin in [CGPoint.zero,CGPoint(x:-1600,y:-400)] {
        let screen=CGRect(origin:origin,size:CGSize(width:1200,height:800))
        for x in stride(from:CGFloat(0),through:1000,by:200) {
            for y in stride(from:CGFloat(0),through:600,by:150) {
                let sprite=CGRect(x:origin.x+x,y:origin.y+y,width:192,height:208)
                for size in [CGSize(width:428,height:500),CGSize(width:1800,height:1400)] {
                    let requested=CGRect(origin:origin,size:size)
                    let result=PetLayout.constrainedBubble(requested,screen:screen,avoiding:sprite)
                    try check(screen.contains(result) && !result.intersects(PetLayout.placementSprite(in:sprite)),"T6 grid nonoverlap and screen bounds")
                    let body=PetLayout.placementSprite(in:sprite)
                    try check(result.maxY <= body.minY || result.minY >= body.maxY,"T6 no lateral fallback")
                    try check(PetLayout.constrainedBubble(result,screen:screen,avoiding:sprite)==result,"T6 stable placement")
                }
            }
        }
    }
    c.collapseChat();settle();c.preferredChatSize=CGSize(width:1000,height:1000)
    c.placePet(at:CGPoint(x:700,y:500));c.showChat();settle()
    c.reducedMotion={false};c.pet.reduceMotion={false}
    let preference=c.preferredChatSize
    for point in [CGPoint(x:500,y:400),CGPoint(x:900,y:600),CGPoint(x:20,y:50),CGPoint(x:1500,y:800)] {
        c.movePet(to:point)
        for _ in 0..<30 {now+=0.02;c.stepPlacement();try expectSeparated("T6 moving frames")}
        try expectSprite(CGRect(origin:point,size:CGSize(width:192,height:208)),"T6 pointer unchanged")
        c.setDrawerOpen(true);web.open(page,ephemeral:true)
        for _ in 0..<30 {now+=0.02;c.stepPlacement();try expectSeparated("T6 web/drawer frames")}
        web.close();c.setDrawerOpen(false)
        for _ in 0..<30 {now+=0.02;c.stepPlacement();try expectSeparated("T6 closing panes")}
        try check(c.preferredChatSize==preference,"T6 display constraints never save preferred size")
    }
    c.reducedMotion={true};c.pet.reduceMotion={true}
    // T5: saved final position and scale restore; existing AT48/AT92 cover click, focus and Escape.
    try store.update{$0.petScalePercent=125};c.resizePet(percent:125);c.movePet(to:CGPoint(x:600,y:600));c.endPetDrag()
    let saved=c.placementTarget!.globalSprite
    let restored=PetController(store:try LocalStore(directory:home),atlas:atlas)
    defer {restored.panel.orderOut(nil)}
    restored.displays={screens};restored.placePet(at:CGPoint(x:store.settings.petX!,y:store.settings.petY!))
    try check(same(restored.placementTarget!.globalSprite,saved),"T5 stored position and user size restore")
    print("PET_POSITION_T1_T6_PASS · simulated input/display integration; no physical mouse claim")
}
