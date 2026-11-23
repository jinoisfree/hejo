import AppKit

private final class InlineBackdrop: NSView {
    override func draw(_ dirtyRect:NSRect){NSColor.magenta.setFill();bounds.fill()}
}

/// Render the specified accent alpha under the same AppKit drawing appearance.
/// Resolving a dynamic NSColor outside draw() can otherwise select the system appearance.
private final class InlineAccentReference: NSView {
    let opacity:CGFloat
    init(opacity:CGFloat){self.opacity=opacity;super.init(frame:CGRect(x:0,y:0,width:262,height:90))}
    required init?(coder:NSCoder){fatalError()}
    override func draw(_ dirtyRect:NSRect){NSColor.controlAccentColor.withAlphaComponent(opacity).setFill();bounds.fill()}
}

@MainActor func drawerInlineTests(resourceDirectory:URL) async throws {
    func near(_ a:CGFloat,_ b:CGFloat)->Bool {abs(a-b)<0.01}
    // AT-DI-01..04: pet above each chat; isolate horizontal boundary cases, including a half-point shortage.
    for origin:CGFloat in [0,-1600] {
        let screen=CGRect(x:origin,y:0,width:1440,height:900)
        func base(_ x:CGFloat)->PetPlacement {PetPlacement(globalSprite:CGRect(x:x+101,y:650,width:192,height:208),globalBubble:CGRect(x:x,y:100,width:428,height:500),expanded:true)}
        let b=base(origin+200),p=b.withDrawer(290,visibleFrame:screen)
        try check(p.globalBubble==CGRect(x:origin+200,y:100,width:718,height:500) && p.globalSprite==b.globalSprite && p.anchorOrigin==b.anchorOrigin,"AT-DI-01 right expansion on both displays")
        let edge=base(screen.maxX-12-100-428),m=edge.withDrawer(290,visibleFrame:screen)
        try check(m.globalBubble.minX==edge.globalBubble.minX-190 && m.globalBubble.maxX==screen.maxX-12 && m.globalSprite==edge.globalSprite && m.anchorOrigin==edge.anchorOrigin,"AT-DI-02 chat-only left shift and unchanged pet")
        let exact=base(screen.maxX-12-290-428),e=exact.withDrawer(290,visibleFrame:screen)
        try check(e.globalSprite==exact.globalSprite && e.globalBubble.minX==exact.globalBubble.minX,"AT-DI-03 inclusive right margin")
        let narrow=CGRect(x:origin,y:0,width:741.5,height:900),n=base(origin+12).withDrawer(290,visibleFrame:narrow)
        try check(n.globalBubble.minX>=narrow.minX+12 && n.globalBubble.maxX<=narrow.maxX-12 && n.drawer==290 && n.contentBubble.width==427.5,"AT-DI-04 half point goes to chat")
    }
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let previousStore=ChatAppearance.store
    defer {ChatAppearance.bind(previousStore)}
    let store=try LocalStore(directory:home)
    ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.deadlineSender={_ in};controller.clock={ThreadTools.date("2026-11-22T10:00:00+09:00")}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    // Keep this horizontal split fixture clear of the pet; T6 covers constrained tall panes.
    try store.update{$0.webPaneHeight=500}
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer {disposeDrawerFixture(pet,controller,view)}
    view.reduceMotion={true};view.island.reduceMotion={true}
    var screen=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:screen,visible:screen)] };pet.reducedMotion={true};pet.pet.animationsAllowed=false
    pet.pet.installConversation(view);pet.installDrawer(view)
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()}
    // Each geometry case starts with a fresh pet-relative opening. Reflow now preserves
    // a moved chat instead of implicitly centering it every time placePet is called.
    func place(center:CGFloat=600){
        let open=pet.chatExpanded
        if open {pet.collapseChat()}
        pet.placePet(at:PetLayout.sprite(foot:CGPoint(x:center,y:680),scale:1).origin)
        if open {pet.showChat()}
        settle()
    }
    func field(_ name:String)->NSView {Mirror(reflecting:view).children.first{$0.label==name}!.value as! NSView}
    func global(_ v:NSView)->CGRect {pet.panel.convertToScreen(v.convert(v.bounds,to:nil))}
    place();pet.showChat();settle()
    let base=pet.placementTarget!.globalBubble
    let representatives=[view.island,view.headerDrag,view.history,field("inputBackground"),field("sendButton"),field("handle")]
    let frames=representatives.map{global($0)},sidebar=global(field("employeeScroll"))
    pet.setDrawerOpen(true);settle()
    try check(view.todoDrawer.superview===view && view.todoDrawer.frame==CGRect(x:68,y:0,width:290,height:view.bounds.height),"AT-DI-05 drawer is an inline full-height column")
    for (v,old) in zip(representatives,frames) {try check(global(v)==old.offsetBy(dx:290,dy:0),"AT-DI-05 every representative frame moves exactly 290: \(type(of:v)) \(global(v)) expected \(old.offsetBy(dx:290,dy:0))")}
    try check(global(field("employeeScroll"))==sidebar && view.todoDrawer.frame.maxX<=view.history.frame.minX && pet.placementTarget!.globalBubble==CGRect(x:base.minX,y:base.minY,width:base.width+290,height:base.height),"AT-DI-05 sidebar stable, columns disjoint, right expansion")
    pet.setDrawerOpen(false);settle()
    try check(pet.placementTarget!.globalBubble==base && zip(representatives,frames).allSatisfy{global($0.0)==$0.1},"AT-DI-05 close restores frames")
    pet.setDrawerOpen(true)
    for width:CGFloat in [68,212,0] {view.setSidebarWidth(width);settle();try check(view.todoDrawer.frame.minX==width && view.todoDrawer.frame.width==290 && view.history.frame.minX==width+290,"AT-DI-06 sidebar width \(width)")}
    view.setSidebarWidth(68);pet.setDrawerOpen(false);screen=CGRect(x:0,y:0,width:1920,height:1080);place()
    let web=WebPaneModel(downloads:controller.files.downloads.root);web.persistent=false;pet.installWeb(web)
    web.open(URL(string:"https://example.invalid/drawer-test")!);settle()
    let webX=global(pet.pet.webPane!).minX
    pet.setDrawerOpen(true);settle()
    try check(pet.pet.paneWidth==720 && near(global(pet.pet.webPane!).minX,webX+290),"AT-DI-07 web width preserved and shifted")
    web.close();settle();try check(pet.drawerOpen && !view.todoDrawer.isHidden,"AT-DI-07 close web preserves drawer")
    web.open(URL(string:"https://example.invalid/drawer-test")!);settle();try check(pet.drawerOpen && !view.todoDrawer.isHidden,"AT-DI-07 reopen web preserves drawer")
    pet.preferredChatSize.width=600
    for (w,chat,pane):(CGFloat,CGFloat,CGFloat) in [(1634,600,720),(1274,600,360),(1273,599,360),(1102,428,360),(1002,428,260)] {
        screen.size.width=w;place(center:500)
        let p=pet.placementTarget!
        try check(p.drawer==290 && p.contentBubble.width-pet.pet.paneWidth==chat && pet.pet.paneWidth==pane && p.globalBubble.width==chat+pane+290 && p.globalBubble.minX>=12 && p.globalBubble.maxX<=w-12,"AT-DI-08 independent split \(w): \(p.contentBubble.width-pet.pet.paneWidth)/\(pet.pet.paneWidth)")
    }
    web.close();pet.setDrawerOpen(false);screen=CGRect(x:0,y:0,width:1440,height:900);pet.preferredChatSize=PetController.defaultChatSize
    place(center:1114);pet.endPetDrag();settle()
    let edge=pet.placementTarget!,savedX=store.settings.petX,savedY=store.settings.petY
    pet.setDrawerOpen(true);settle()
    try check(pet.placementTarget!.globalBubble.maxX==1428 && pet.placementTarget!.globalSprite==edge.globalSprite,"AT-DI-09 only chat shifts 190 left")
    let disk=try LocalStore(directory:home)
    try check(store.settings.petX==savedX && store.settings.petY==savedY && disk.settings.petX==savedX && disk.settings.petY==savedY,"AT-DI-09 temporary shift never saved")
    pet.setDrawerOpen(false);settle();try check(pet.placementTarget!.globalBubble.minX==edge.globalBubble.minX-190 && pet.placementTarget!.globalSprite==edge.globalSprite,"AT-DI-09 closing retains current chat edge and pet")
    screen.size.width=552;place(center:276)
    let narrowBase=pet.placementTarget!.globalBubble,savedWidth=store.settings.chatWidth
    pet.setDrawerOpen(true);settle()
    try check(pet.placementTarget!.globalBubble.width==528 && view.todoDrawer.frame.width==290 && view.history.frame.width==170,"AT-DI-10 narrow chat yields 190")
    pet.setDrawerOpen(false);settle();try check(pet.placementTarget!.globalBubble.size==narrowBase.size && pet.placementTarget!.globalBubble.minX==12 && store.settings.chatWidth==savedWidth,"AT-DI-10 close restores width at current edge without saving narrowed width")
    screen.size.width=1440;place();let resizeBase=pet.placementTarget!.globalBubble
    try check(resizeBase.minX==386 && resizeBase.width==428,"AT-DI-11 fixed resize fixture")
    pet.setDrawerOpen(true);settle();pet.pet.onResize?(.right,CGPoint(x:40,y:0));pet.endPetDrag();settle()
    try check(store.settings.chatWidth==508 && pet.placementTarget!.globalBubble.minX==346 && pet.placementTarget!.globalBubble.width==798 && pet.placementTarget!.globalBubble.maxX==1144,"AT-DI-11 existing centered resize excludes drawer")
    pet.setDrawerOpen(false);settle();try check(pet.placementTarget!.globalBubble.minX==346 && pet.placementTarget!.globalBubble.width==508,"AT-DI-11 closed resized box")
    pet.preferredChatSize=PetController.defaultChatSize;screen.size.width=552;place(center:276)
    var now=100.0;pet.clock={now};pet.reducedMotion={false}
    func motionSample(_ d:CGFloat,_ b:CGFloat,_ c:CGFloat,_ label:String) throws {settle();try check(near(view.todoDrawer.frame.width,d) && near(pet.pet.placement!.globalBubble.width,b) && near(view.history.frame.width,c),label)}
    pet.setDrawerOpen(true);try motionSample(0,428,360,"AT-DI-14 open begins at zero")
    now+=0.125;try motionSample(145,478,265,"AT-DI-14 opening midpoint")
    now+=0.125;try motionSample(290,528,170,"AT-DI-14 opening endpoint")
    pet.setDrawerOpen(false);try motionSample(290,528,170,"AT-DI-14 closing starts at full width")
    now+=0.125;try motionSample(145,478,265,"AT-DI-14 closing midpoint")
    now+=0.125;try motionSample(0,428,360,"AT-DI-14 closing endpoint")
    for opening in [true,false] {
        let start=now;pet.setDrawerOpen(opening);var previous=view.drawerShownWidth
        for tick in 0...15 {
            now=start+Double(tick)/60;settle();let width=view.drawerShownWidth
            try check((opening ? width>=previous-0.01:width<=previous+0.01) && abs(width-previous)<=30 && view.todoDrawer.frame.maxX<=view.history.frame.minX,"AT-DI-14 monotone, bounded and disjoint every frame opening=\(opening) tick=\(tick) current=\(width) previous=\(previous) drawer=\(view.todoDrawer.frame) history=\(view.history.frame)")
            previous=width
        }
    }
    pet.setDrawerOpen(true);now+=0.125;settle();pet.setDrawerOpen(false)
    try check(near(view.drawerShownWidth,145),"AT-DI-14 reversal starts at current shown width")
    now+=0.25;settle();try check(view.drawerShownWidth==0,"AT-DI-14 reversal closes")
    pet.reducedMotion={true};screen.size.width=1440;place();pet.setDrawerOpen(true);settle()
    try check(view.drawerShownWidth==290,"AT-DI-12 reduced motion immediate")
    pet.beginChatDrag(at:CGPoint(x:600,y:680));pet.moveChatDrag(to:CGPoint(x:1300,y:680));pet.endChatDrag();settle()
    try check(pet.placementTarget!.globalBubble.maxX==1428 && pet.placementTarget!.drawer==290,"AT-DI-13 drag near right keeps inline drawer")
    pet.collapseChat();settle();try check(view.todoDrawer.isHidden && pet.drawerOpen,"AT-DI-13 folding hides drawer with preference")
    pet.showChat();settle();try check(!view.todoDrawer.isHidden && pet.drawerOpen,"AT-DI-13 unfold reevaluates")
    pet.panel.cancelOperation(nil);settle();try check(!pet.drawerOpen,"AT-DI-31 escape closes")
    pet.setDrawerOpen(true);view.todoDrawer.onClose?();settle();try check(!pet.drawerOpen,"AT-DI-31 fold control closes")
    pet.setDrawerOpen(true);settle()
    let click=NSEvent.mouseEvent(with:.leftMouseDown,location:view.convert(CGPoint(x:view.history.frame.midX,y:view.history.frame.midY),to:nil),modifierFlags:[],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    view.history.table.mouseDown(with:click);try check(pet.drawerOpen,"AT-DI-31 chat click leaves drawer open")
    print("AT-DI-01..14,31 INLINE PLACEMENT PASS")
    try drawerInlineColorTests(pet:pet,view:view,controller:controller,store:store)
    try drawerInlineLogoTests(resourceDirectory:resourceDirectory)
    try drawerHeaderTests(resourceDirectory:resourceDirectory)
    try await uiCleanDrawerTests(resourceDirectory:resourceDirectory)
}

@MainActor private func drawerInlineColorTests(pet:PetController,view:ConversationView,controller:ConversationController,store:LocalStore) throws {
    let evidence=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/drawer-inline-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    let backdrop=InlineBackdrop(frame:pet.pet.conversation.bounds)
    // The colored plane sits below the real tint, inside the glass content.
    // A light glass material can itself be opaque in an offscreen cache, hiding a plane below it.
    let tint=Mirror(reflecting:pet.pet).children.first{$0.label=="tint"}!.value as! NSView
    tint.superview!.addSubview(backdrop,positioned:.below,relativeTo:tint)
    defer {backdrop.removeFromSuperview()}
    pet.pet.reduceTransparency={false}
    func bitmap(_ surface:NSView)throws->NSBitmapImageRep {
        surface.layoutSubtreeIfNeeded()
        guard let rep=surface.bitmapImageRepForCachingDisplay(in:surface.bounds) else {throw TestFailure.assertion("DI bitmap allocation")}
        surface.cacheDisplay(in:surface.bounds,to:rep);return rep
    }
    func pixel(_ rep:NSBitmapImageRep,_ surface:NSView,_ point:CGPoint)->NSColor {
        let x=Int(point.x*CGFloat(rep.pixelsWide)/surface.bounds.width)
        let y=Int(point.y*CGFloat(rep.pixelsHigh)/surface.bounds.height)
        return rep.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
    }
    func distance(_ a:NSColor,_ b:NSColor)->CGFloat {let a=a.usingColorSpace(.deviceRGB)!,b=b.usingColorSpace(.deviceRGB)!;return abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)}
    let tolerance:CGFloat=6/255
    var cards:[TodoDrawerModel.Card]=[]
    for (index,kind) in [TodoDrawerModel.Filter.question,.deadline,.alert].enumerated() {
        cards.append(.init(id:"card-\(index)",kind:kind,title:["확인이 필요한 질문","오늘 마감할 일","새 알림"][index],employee:"alpha",name:"직원 A",status:["답을 기다려요","오늘 마감 · 노션","알림"][index],statusUrgent:kind != .alert,trailing:"방금",order:Date(timeIntervalSince1970:0),urgent:kind != .alert))
    }
    let empty=TodoDrawerModel.Snapshot()
    var snapshot=TodoDrawerModel.Snapshot();snapshot.urgent=Array(cards.prefix(2));snapshot.rest=[cards[2]];snapshot.counts=[.all:3,.question:1,.deadline:1,.alert:1];snapshot.available=true
    for theme in [ChatTheme.dark,.light] {
        tint.superview!.addSubview(backdrop,positioned:.below,relativeTo:tint)
        view.todoDrawer.needsDisplay=false
        try ChatAppearance.change(theme:theme)
        try check(view.todoDrawer.needsDisplay,"AT-DI-23 theme invalidates drawer")
        pet.applyChatAppearance();view.todoDrawer.show(empty,filter:.all,selected:nil)
        var samples:[NSColor]=[]
        for opacity in [65.0,100.0] {
            try ChatAppearance.change(opacity:opacity);pet.applyChatAppearance();pet.pet.updateScrim()
            backdrop.frame=tint.frame
            let rep=try bitmap(pet.pet.conversation)
            // Samples live in the common column background, away from labels and controls.
            let sidebarPoint=view.convert(CGPoint(x:8,y:200),to:pet.pet.conversation)
            let drawerPoint=view.convert(CGPoint(x:76,y:200),to:pet.pet.conversation)
            let side=pixel(rep,pet.pet.conversation,sidebarPoint),drawer=pixel(rep,pet.pet.conversation,drawerPoint)
            try check(distance(side,drawer)<=tolerance && !view.todoDrawer.isOpaque,"AT-DI-20 same transparent column tone \(theme) \(opacity): \(distance(side,drawer))")
            let sideLine=pixel(rep,pet.pet.conversation,view.convert(CGPoint(x:67.5,y:200),to:pet.pet.conversation))
            let drawerLine=pixel(rep,pet.pet.conversation,view.convert(CGPoint(x:357.5,y:200),to:pet.pet.conversation))
            try check(distance(sideLine,drawerLine)<=tolerance,"AT-DI-21 equal column separator pixels")
            samples.append(drawer)
        }
        try check(distance(samples[0],samples[1])>tolerance,"AT-DI-20 opacity changes drawer pixels \(theme): \(samples)")
        view.todoDrawer.show(snapshot,filter:.all,selected:nil);view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()
        let dark=theme == .dark
        var borders:[NSColor]=[]
        for (index,card) in view.todoDrawer.cardViews.enumerated() {
            let rep=try bitmap(card)
            let border=pixel(rep,card,CGPoint(x:0.5,y:26));borders.append(border)
            try check(border.redComponent-max(border.greenComponent,border.blueComponent)<0.1,"AT-DI-22 neutral card border")
            // Urgent rail and selection pixels are covered by AT-UC-14/16.
        }
        try check(distance(borders[0],borders[1])<=tolerance && distance(borders[1],borders[2])<=tolerance,"AT-DI-22 same border on all card kinds")
        try ChatAppearance.change(opacity:65);pet.applyChatAppearance();pet.pet.updateScrim()
        backdrop.removeFromSuperview()
        view.todoDrawer.show(snapshot,filter:.all,selected:cards[0].id);view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()
        let image=try bitmap(pet.pet)
        try image.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("inline-right-edge-\(theme.rawValue).png"))
        try bitmap(view.todoDrawer).representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("cards-\(theme.rawValue).png"))
    }
    // AT-DI-12 exercises the actual fixed-width stack during a partially revealed column.
    pet.setDrawerOpen(false);pet.stepPlacement();view.layoutSubtreeIfNeeded()
    var now=500.0;pet.clock={now};pet.reducedMotion={false};pet.setDrawerOpen(true)
    now+=0.125;pet.stepPlacement();view.todoDrawer.show(snapshot,filter:.all,selected:cards[0].id);view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()
    try check(!pet.pet.widthCoverVisible && view.drawerShownWidth>0 && view.drawerShownWidth<290 && view.history.frame.minX==68+view.drawerShownWidth && view.todoDrawer.cardViews.first?.frame.width==278,"AT-DI-12 cards retain full layout width during reveal")
    now+=0.125;pet.stepPlacement();view.layoutSubtreeIfNeeded()
    try check(view.drawerShownWidth==290 && view.todoDrawer.frame.width==290,"AT-DI-12 reveal endpoint")
    print("AT-DI-20..23 PIXEL PASS; M-DI native-view captures: .build/drawer-inline-evidence")
}

/// AT-DI-34 observes ink bounds in the actual ConversationView header, not label alignment properties.
@MainActor private func drawerInlineLogoTests(resourceDirectory:URL) throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let previousStore=ChatAppearance.store
    defer {ChatAppearance.bind(previousStore)}
    let store=try LocalStore(directory:home);ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.deadlineSender={_ in}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    view.reduceMotion={true};view.island.reduceMotion={true};view.version.stringValue="0.2.5"
    view.todoDrawer.show(.init(),filter:.all,selected:nil)
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer {disposeDrawerFixture(pet,controller,view)}
    pet.displays={let screen=CGRect(x:0,y:0,width:1920,height:1080);return [PetDisplay(frame:screen,visible:screen)]}
    pet.reducedMotion={true};pet.pet.animationsAllowed=false;pet.preferredChatSize=CGSize(width:1000,height:600)
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:PetLayout.sprite(foot:CGPoint(x:960,y:800),scale:1).origin);pet.showChat();pet.stepPlacement()
    view.layoutSubtreeIfNeeded()
    try check(view.bounds.size==CGSize(width:1000,height:600),"AT-DI-34 actual conversation fixture is 1000 by 600")
    let evidence=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/drawer-inline-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    var measurements:[[String:Any]]=[]
    defer {if let data=try? JSONSerialization.data(withJSONObject:measurements,options:.prettyPrinted){try? data.write(to:evidence.appendingPathComponent("logo-centers.json"))}}
    func capture(_ rect:CGRect)throws->NSBitmapImageRep {
        view.layoutSubtreeIfNeeded();view.needsDisplay=true
        let rep=view.bitmapImageRepForCachingDisplay(in:rect)!
        view.cacheDisplay(in:rect,to:rep);return rep
    }
    for theme in [ChatTheme.dark,.light] {
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance()
        view.layoutSubtreeIfNeeded();view.displayIfNeeded()
        for width:CGFloat in [68,212,240,0] {
            view.setSidebarWidth(width);view.layoutSubtreeIfNeeded()
            try check(view.sidebarWidth==width,"AT-DI-34 requested sidebar width \(width), actual \(view.sidebarWidth)")
            if width==0 {try check(view.brand.isHidden && view.version.isHidden,"AT-DI-34 zero width hides logo and version");continue}
            for drawer:CGFloat in [0,290] {
                view.drawerShownWidth=drawer;view.layoutSubtreeIfNeeded()
                let rect=CGRect(x:0,y:0,width:width,height:44)
                let ink=try capture(rect)
                view.brand.isHidden=true;view.version.isHidden=true
                let background=try capture(rect)
                view.brand.isHidden=false;view.version.isHidden=false
                let sx=CGFloat(ink.pixelsWide)/width,sy=CGFloat(ink.pixelsHigh)/44
                func color(_ rep:NSBitmapImageRep,_ x:Int,_ y:Int)->NSColor {rep.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!}
                func inkBounds(_ range:Range<Int>) throws -> CGRect {
                    var xs:[Int]=[],ys:[Int]=[]
                    for y in Int(CGFloat(range.lowerBound)*sy)..<Int(CGFloat(range.upperBound)*sy) {for x in 0..<ink.pixelsWide {
                        let a=color(ink,x,y),b=color(background,x,y)
                        // Black ink on a clear light header differs in alpha, even when both RGB values are zero.
                        let difference=abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)+abs(a.alphaComponent-b.alphaComponent)
                        if difference>0.05 {xs.append(x);ys.append(y)}
                    }}
                    guard let x0=xs.min(),let x1=xs.max(),let y0=ys.min(),let y1=ys.max() else {
                        try ink.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("logo-failed-\(theme.rawValue).png"))
                        let state:[String:Any]=["theme":theme.rawValue,"sidebar":width,"drawer":drawer,
                            "version":view.version.stringValue,"hidden":view.version.isHidden,"frame":NSStringFromRect(view.version.frame),
                            "textColor":view.version.textColor?.description ?? "nil","effectiveAppearance":view.effectiveAppearance.name.rawValue,
                            "labelAppearance":view.version.effectiveAppearance.name.rawValue]
                        try JSONSerialization.data(withJSONObject:state,options:.prettyPrinted).write(to:evidence.appendingPathComponent("logo-failed-state.json"))
                        throw TestFailure.assertion("AT-DI-34 missing rendered ink \(range)")
                    }
                    return CGRect(x:CGFloat(x0)/sx,y:CGFloat(y0)/sy,width:CGFloat(x1-x0+1)/sx,height:CGFloat(y1-y0+1)/sy)
                }
                let logo=try inkBounds(7..<25),version=try inkBounds(26..<38)
                measurements.append(["theme":theme.rawValue,"sidebar":width,"drawer":drawer,"logoCenter":logo.midX,"versionCenter":version.midX,"expected":width/2])
                try check(abs(logo.midX-width/2)<=1.5 && abs(version.midX-width/2)<=1.5,"AT-DI-34 pixel centers width=\(width) logo=\(logo.midX) version=\(version.midX)")
                var blue=false
                for y in Int(logo.minY*sy)..<Int(logo.maxY*sy) {for x in Int(logo.minX*sx)..<Int((logo.minX+logo.width/4)*sx) {
                    let p=color(ink,x,y);if p.blueComponent>p.redComponent+0.3 {blue=true}
                }}
                try check(blue,"AT-DI-34 first logo letter retains blue")
                if drawer==290 && [CGFloat(68),212,240].contains(width) {
                    let image=try capture(view.bounds)
                    try image.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("logo-sidebar-\(Int(width))-\(theme.rawValue).png"))
                }
            }
        }
    }
    print("AT-DI-34 LOGO AND VERSION PIXEL CENTERS PASS")
}
