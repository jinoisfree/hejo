import AppKit

@MainActor func drawerHeaderTests(resourceDirectory:URL) throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let oldStore=ChatAppearance.store;defer {ChatAppearance.bind(oldStore)}
    let store=try LocalStore(directory:home);ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let now=ThreadTools.date("2026-11-23T12:00:00+09:00");controller.clock={now};controller.deadlineSender={_ in}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    for i in 0..<8 {
        let frame:[String:Any]=["v":1,"type":"message","seq":i+1,"msg_id":UUID().uuidString.lowercased(),"employee":"alpha","thread":UUID().uuidString.lowercased(),"role":"employee","text":"가짜 항목 \(i)","files":[],"buttons":[],"reply_state":i<4 ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now)]
        try store.append(frame);controller.receive(frame)
    }
    let rows:[[String:Any]]=(0..<4).map{["employee":"alpha","id":"notion:fixture-\($0)","title":"가짜 마감 \($0)","due":$0<2 ? "2026-11-23":"2026-11-28"]}
    controller.todoDrawer.receive(["available":true,"items":rows,"failed":[]])
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer {disposeDrawerFixture(pet,controller,view)}
    view.reduceMotion={true};view.island.reduceMotion={true};pet.reducedMotion={true};pet.pet.animationsAllowed=false
    pet.displays={let r=CGRect(x:0,y:0,width:1440,height:900);return [PetDisplay(frame:r,visible:r)]}
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:PetLayout.sprite(foot:CGPoint(x:600,y:700),scale:1).origin);pet.showChat();pet.setDrawerOpen(true)
    let drawer=view.todoDrawer
    func all(_ root:NSView)->[NSView] {root.subviews.flatMap{[$0]+all($0)}}
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded();drawer.layoutSubtreeIfNeeded()}
    func refresh(){view.refresh();settle()}
    refresh()
    try check(controller.drawerSnapshot.total==12 && controller.drawerSnapshot.urgent.count==6 && controller.drawerSnapshot.rest.count==6,"AT-DI-35 independent twelve-card fixture")
    let track=all(drawer).compactMap{$0 as? ComposerModeTrack}.first!
    let scroll=all(drawer).compactMap{$0 as? NSScrollView}.first!
    let document=scroll.documentView!
    let close=all(drawer).compactMap{$0 as? NSButton}.first{$0.title=="✕"}!
    func buttons()->[ComposerButton] {track.subviews.compactMap{$0 as? ComposerButton}}
    func frame(_ child:NSView)->CGRect {child.convert(child.bounds,to:view)}
    func fromTop(_ child:NSView)->CGRect {frame(child).offsetBy(dx:-frame(drawer).minX,dy:-frame(drawer).minY)}
    func windowFrames()->[CGRect] {[close,track].map{$0.convert($0.bounds,to:nil)}}
    func scrollTo(bottom:Bool) {
        document.layoutSubtreeIfNeeded()
        let end=max(0,document.bounds.height-scroll.contentView.bounds.height)
        scroll.contentView.scroll(to:CGPoint(x:0,y:(bottom != document.isFlipped) ? 0:end));scroll.reflectScrolledClipView(scroll.contentView)
    }
    let evidence=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/drawer-inline-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    func bitmap(_ root:NSView)->NSBitmapImageRep {root.layoutSubtreeIfNeeded();root.needsDisplay=true;let rep=root.bitmapImageRepForCachingDisplay(in:root.bounds)!;root.cacheDisplay(in:root.bounds,to:rep);return rep}
    func pixel(_ rep:NSBitmapImageRep,_ root:NSView,_ p:CGPoint)->NSColor {rep.colorAt(x:Int(p.x*CGFloat(rep.pixelsWide)/root.bounds.width),y:Int(p.y*CGFloat(rep.pixelsHigh)/root.bounds.height))!.usingColorSpace(.deviceRGB)!}
    func delta(_ a:NSColor,_ b:NSColor)->CGFloat {abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)+abs(a.alphaComponent-b.alphaComponent)}
    let tolerance:CGFloat=6/255
    for theme in [ChatTheme.dark,.light] {
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance();refresh();view.displayIfNeeded()
        scrollTo(bottom:false)
        try check(abs(fromTop(close).midY-22)<=1 && abs(fromTop(track).midY-22)<=1,"AT-DI-35 fixed band vertical centers")
        try check(fromTop(scroll).minY==44 && fromTop(scroll).maxY==drawer.bounds.height && fromTop(track).minX==14 && fromTop(track).maxX==244,"AT-DI-35 scroll and track edges")
        let rep=bitmap(view)
        try rep.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("header-before-\(theme.rawValue).png"))
        let references=[pixel(rep,view,CGPoint(x:view.sidebarWidth/2,y:43.5))]
        for (y,reference) in zip([CGFloat(43.5)],references) {
            let line=pixel(rep,view,CGPoint(x:frame(drawer).minX+200,y:y))
            let background=pixel(rep,view,CGPoint(x:frame(drawer).minX+200,y:y+4))
            print("AT-DI-35 line samples \(theme) y=\(y): reference delta=\(delta(line,reference)), background delta=\(delta(line,background))")
            try check(delta(line,reference)<=tolerance,"AT-DI-35 band separator equals sidebar line \(theme) y=\(y) delta=\(delta(line,reference))")
            try check(delta(line,background)>tolerance,"AT-DI-35 band separator is visible \(theme) y=\(y)")
        }
        let before=windowFrames(),first=drawer.cardViews[0],cardBefore=frame(first)
        let image=bitmap(view);try image.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("header-before-\(theme.rawValue).png"))
        scrollTo(bottom:true)
        try check(windowFrames()==before && frame(first).minY<cardBefore.minY,"AT-DI-36 only cards scroll")
        try bitmap(view).representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("header-after-\(theme.rawValue).png"))
        let composerTrack=all(view).compactMap{$0 as? ComposerModeTrack}.first{$0 !== track}!
        let composerChosen=all(view).compactMap{$0 as? ComposerButton}.first{$0.mode && $0.chosen && $0.superview !== track}!
        let chosen=buttons().first{$0.chosen}!
        let a=pixel(bitmap(chosen),chosen,CGPoint(x:5,y:chosen.bounds.midY)),b=pixel(bitmap(composerChosen),composerChosen,CGPoint(x:5,y:composerChosen.bounds.midY))
        try check(delta(a,b)<=tolerance,"AT-DI-38 selected fill matches composer")
        let c=pixel(bitmap(track),track,CGPoint(x:track.bounds.midX,y:1)),d=pixel(bitmap(composerTrack),composerTrack,CGPoint(x:composerTrack.bounds.midX,y:1))
        try check(delta(c,d)<=tolerance,"AT-DI-38 track matches composer")
        let text=bitmap(chosen);var white=false
        for y in 4..<(text.pixelsHigh-4) {for x in 14..<(text.pixelsWide-14) {let p=text.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!;if min(p.redComponent,p.greenComponent,p.blueComponent)>=0.85 && p.alphaComponent>=0.85 {white=true}}}
        try check(white,"AT-DI-38 selected text has white ink")
    }
    for available in [true,false] {
        controller.todoDrawer.receive(["available":available,"items":rows,"failed":[]]);controller.drawerFilter = .all;refresh()
        let kinds: [TodoDrawerModel.Filter]=available ? [.all,.question,.deadline,.alert]:[.all,.question,.alert]
        try check(buttons().count==kinds.count,"AT-DI-37 available filters")
        let widths=buttons().map{$0.frame.width}
        try check(widths.allSatisfy{abs($0-widths[0])<=1} && abs(widths.reduce(0,+)-226)<0.01,"AT-DI-37 equal segments fill track interior")
        for (index,kind) in kinds.enumerated() {
            let count=controller.drawerSnapshot.counts[kind] ?? 0
            try check(buttons()[index].title=="\(kind.rawValue) \(count)","AT-DI-37 model count label")
            buttons()[index].performClick(nil);settle()
            try check(controller.drawerFilter==kind && drawer.cardViews.allSatisfy{kind == .all || $0.card.kind==kind},"AT-DI-37 actual filter routes and cards")
            try check(buttons().enumerated().allSatisfy{$0.element.chosen == ($0.offset==index) && $0.element.isAccessibilitySelected() == ($0.offset==index)},"AT-DI-37 single chosen accessible segment")
        }
    }
    controller.todoDrawer.receive(["available":true,"items":rows,"failed":[]]);controller.drawerFilter = .all;refresh()
    let deadline=drawer.cardViews.first{$0.card.kind == .deadline}!.card
    drawer.onCloseDeadline?(deadline,"done");refresh()
    let footer=all(drawer).compactMap{$0 as? NSButton}.first{$0.title=="되돌리기"}!.superview!
    scrollTo(bottom:false);let footerBefore=frame(footer),fixedBefore=windowFrames()
    scrollTo(bottom:true)
    try check(frame(footer)==footerBefore && windowFrames()==fixedBefore && drawer.footerText != nil,"AT-DI-36 undo footer stays fixed after actual close")
    controller.undoClose();refresh()
    pet.setDrawerOpen(false);settle();var time=100.0;pet.clock={time};pet.reducedMotion={false};pet.setDrawerOpen(true);time+=0.125;settle()
    try check(drawer.bounds.width==145 && track.frame.width==230 && track.visibleRect.width<track.bounds.width && drawer.layer?.masksToBounds==true,"AT-DI-39 reveal clips fixed-width bands")
    print("AT-DI-35..39 FIXED HEADER AND FILTER TOGGLE PASS")
}
