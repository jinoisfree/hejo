import AppKit

/// AT-UC-10..19: projected copy and the actual fixed column, selection and first-responder routes.
@MainActor func uiCleanDrawerTests(resourceDirectory:URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let oldStore=ChatAppearance.store;defer {ChatAppearance.bind(oldStore)}
    let store=try LocalStore(directory:home);ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    var now=ThreadTools.date("2026-11-23T12:00:00+09:00")
    controller.clock={now};controller.deadlineSender={_ in}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]])
    var seq=0
    @discardableResult func post(_ text:String,asked:Bool,age:Double=0,employee:String="alpha")->String {
        seq+=1;let id=UUID().uuidString.lowercased()
        let row:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":UUID().uuidString.lowercased(),"role":"employee","text":text,"files":[],"buttons":[],"reply_state":asked ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now.addingTimeInterval(-age))]
        try! store.append(row);controller.receive(row);return id
    }
    let question=post("가짜 질문",asked:true,age:180),other=post("다른 질문",asked:true,age:120,employee:"beta")
    let alert=post("가짜 알림",asked:false,age:7200)
    for i in 0..<9 {_=post("목록 항목 \(i)",asked:false,age:Double(i+1)*60)}
    let days=[("past","2026-11-22"),("today","2026-11-23"),("tomorrow","2026-11-24"),("later","2026-11-28")]
    let rows:[[String:Any]]=days.map { id,due in
        var row:[String:Any]=["employee":"alpha","id":"notion:"+id,"title":id,"due":due,"notice":["message_id":question,"thread":controller.model.messages[question]!.key.thread]]
        if id=="today" {row["deadline_at"]="2026-11-23T18:00:00+09:00"}
        if id=="later" {row["origin"]="notion"};return row
    }+[["employee":"alpha","id":"notion:unlinked","title":"unlinked","due":"2026-11-28"]]
    controller.todoDrawer.receive(["available":true,"items":rows,"failed":[]])
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Asia/Seoul")!
    let snapshot=controller.todoDrawer.snapshot(controller.model,now:now,calendar:calendar)
    let cards=snapshot.urgent+snapshot.rest
    func card(_ title:String)->TodoDrawerModel.Card {cards.first{$0.title==title}!}
    try check(card("가짜 질문").status=="답을 기다려요" && card("가짜 질문").statusUrgent && card("가짜 질문").trailing=="3분","AT-UC-13 question copy and injected relative time")
    try check(card("가짜 알림").status=="알림" && !card("가짜 알림").statusUrgent && card("가짜 알림").trailing=="2시간","AT-UC-13 alert copy")
    for (title,status,urgent,trailing) in [("past","마감 1일 지남",true,"11/22"),("today","오늘 마감",true,"18:00"),("tomorrow","내일 마감",true,"11/24"),("later","마감 5일 남음 · 노션",false,"11/28")] {
        let value=card(title);try check(value.status==status && value.statusUrgent==urgent && value.trailing==trailing,"AT-UC-13 deadline \(title)")
    }
    try check(card("unlinked").status.hasSuffix(" · 연결된 대화 없음"),"AT-UC-13 unlinked suffix")
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
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
    func bitmap(_ root:NSView)->NSBitmapImageRep {root.layoutSubtreeIfNeeded();root.needsDisplay=true;let r=root.bitmapImageRepForCachingDisplay(in:root.bounds)!;root.cacheDisplay(in:root.bounds,to:r);return r}
    func pixel(_ r:NSBitmapImageRep,_ v:NSView,_ p:CGPoint)->NSColor {r.colorAt(x:Int(p.x*CGFloat(r.pixelsWide)/v.bounds.width),y:Int(p.y*CGFloat(r.pixelsHigh)/v.bounds.height))!.usingColorSpace(.deviceRGB)!}
    func delta(_ a:NSColor,_ b:NSColor)->CGFloat {abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)+abs(a.alphaComponent-b.alphaComponent)}
    let cwd=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
    let evidence=(cwd.lastPathComponent=="app" ? cwd.deletingLastPathComponent():cwd).appendingPathComponent(".build/ui-clean-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    func capture(_ name:String,_ root:NSView) throws {try bitmap(root).representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent(name+".png"))}
    refresh()
    let track=all(drawer).compactMap{$0 as? ComposerModeTrack}.first!,close=all(drawer).compactMap{$0 as? NSButton}.first{$0.title=="✕"}!
    let scroll=all(drawer).compactMap{$0 as? NSScrollView}.first!,document=all(drawer).compactMap{$0 as? NSScrollView}.first!.documentView!
    func top(_ child:NSView)->CGRect {child.convert(child.bounds,to:view).offsetBy(dx:-drawer.frame.minX,dy:-drawer.frame.minY)}
    func bottom(_ end:Bool){let y=max(0,document.bounds.height-scroll.contentView.bounds.height);scroll.contentView.scroll(to:CGPoint(x:0,y:(end != document.isFlipped) ? 0:y));scroll.reflectScrolledClipView(scroll.contentView)}
    try check(!all(drawer).compactMap{$0 as? NSTextField}.contains{$0.stringValue.contains("처리할 일")},"AT-UC-10 no duplicate title")
    try check(abs(top(track).midY-22)<=1 && abs(top(track).minX-14)<=1 && abs(top(track).maxX-244)<=1 && top(close)==CGRect(x:252,y:10,width:24,height:24) && top(scroll).minY==44,"AT-UC-10 single fixed band geometry")
    for theme in [ChatTheme.dark,.light] {
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance();refresh();bottom(false)
        let first=drawer.cardViews[0],second=drawer.cardViews[1]
        try check(first.frame.width==278 && first.frame.height==52 && abs(abs(first.frame.minY-second.frame.minY)-59)<0.01 && first.avatarRect==CGRect(x:16,y:13,width:26,height:26),"AT-UC-14 card dimensions, seven-point gap and face")
        let corners=bitmap(first)
        // The top edge begins at radius ten: the very corner remains transparent.
        try check(pixel(corners,first,CGPoint(x:0,y:0)).alphaComponent<0.01 && pixel(corners,first,CGPoint(x:10,y:0.5)).alphaComponent>0.02,"AT-UC-14 rounded ten-point corners")
        let urgent=drawer.cardViews.first{$0.card.kind == .question}!,neutral=drawer.cardViews.first{$0.card.kind == .alert}!
        let red=pixel(bitmap(urgent),urgent,CGPoint(x:7.5,y:26))
        try check(red.redComponent>red.greenComponent+0.3 && delta(red,pixel(bitmap(neutral),neutral,CGPoint(x:7.5,y:26)))>0.3,"AT-UC-14 urgent rail absent from alert")
        let chatIndex=view.history.layouts.firstIndex{$0.content.style.status != nil}!
        view.history.table.scrollRowToVisible(chatIndex);view.history.layoutSubtreeIfNeeded()
        let chat=view.history.layouts[chatIndex]
        let chatView=view.history.table.view(atColumn:0,row:chatIndex,makeIfNecessary:true) as! NativeThreadCard
        try check(chatView.window === urgent.window,"AT-UC-14 compares actual cards in the same window")
        let chatRed=pixel(bitmap(chatView),chatView,CGPoint(x:ChatMetrics.horizontalInset+7.5,y:26))
        print("AT-UC-14 rail samples: drawer=\(red) chat=\(chatRed) status=\(String(describing:chat.content.style.status))")
        try capture("task-01-rail-drawer-"+theme.rawValue,urgent);try capture("task-01-rail-chat-"+theme.rawValue,chatView)
        try check(delta(red,chatRed)<=6/255,"AT-UC-14 same rail colour in chat and drawer")
        let railImage=bitmap(urgent)
        try check(delta(pixel(railImage,urgent,CGPoint(x:6,y:26)),pixel(railImage,urgent,CGPoint(x:8,y:26)))<=6/255 && delta(red,pixel(railImage,urgent,CGPoint(x:10,y:26)))>0.3 && delta(red,pixel(railImage,urgent,CGPoint(x:7,y:8)))>0.3 && delta(red,pixel(railImage,urgent,CGPoint(x:7,y:44)))>0.3,"AT-UC-14 rail six inset, width three and ten vertical")
        let normal=bitmap(urgent),event=NSEvent.enterExitEvent(with:.mouseEntered,location:.zero,modifierFlags:[],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,eventNumber:0,trackingNumber:0,userData:nil)!
        urgent.mouseEntered(with:event)
        let hover=bitmap(urgent)
        try check(delta(pixel(normal,urgent,CGPoint(x:200,y:45)),pixel(hover,urgent,CGPoint(x:200,y:45)))>6/255 && delta(pixel(normal,urgent,CGPoint(x:0.5,y:26)),pixel(hover,urgent,CGPoint(x:0.5,y:26)))>6/255,"AT-UC-16 tracking event changes fill and border")
        urgent.mouseExited(with:event)
        // AT-UC-12 (edition 4): compare uncovered column pixels, then the same card in the viewport.
        let full=controller.drawerSnapshot,fullCards=full.urgent+full.rest,lastCard=fullCards.last!
        func fixture(_ cards:[TodoDrawerModel.Card])->TodoDrawerModel.Snapshot {
            var value=full;value.urgent=cards.filter(\.urgent);value.rest=cards.filter{!$0.urgent}
            value.counts=Dictionary(uniqueKeysWithValues:TodoDrawerModel.Filter.allCases.map {kind in (kind,kind == .all ? cards.count:cards.filter{$0.kind==kind}.count)})
            return value
        }
        drawer.show(fixture([fullCards.first{$0.kind == .question}!,fullCards.first{$0.kind == .deadline && !$0.urgent}!,lastCard]),filter:.all,selected:nil);settle();bottom(false)
        let shortImage=bitmap(view),h=view.bounds.height,x=drawer.frame.minX+145
        let emptySample=pixel(shortImage,view,CGPoint(x:x,y:h-14))
        func sidebarTone(_ image:NSBitmapImageRep)->Bool {delta(pixel(image,view,CGPoint(x:view.sidebarWidth/2,y:h-14)),pixel(image,view,CGPoint(x:view.sidebarWidth/2,y:h-60)))<=6/255}
        try check(delta(emptySample,pixel(shortImage,view,CGPoint(x:x,y:h-60)))<=6/255 && sidebarTone(shortImage),"AT-UC-12 three cards leave a uniform empty bottom")
        let shortLast=drawer.cardViews.last!,lastPoint=CGPoint(x:200,y:45)
        let lastPixel=pixel(shortImage,view,shortLast.convert(lastPoint,to:view))
        try capture("task-01-three-cards-"+theme.rawValue,view)
        drawer.show(fixture(Array(fullCards.prefix(11))+[lastCard]),filter:.all,selected:nil);settle();bottom(false)
        try check(drawer.cardViews.count==12,"AT-UC-12 twelve-card scroll fixture")
        let positions=[track,close].map{$0.convert($0.bounds,to:nil)}
        try capture("task-01-before-"+theme.rawValue,view)
        bottom(true)
        try check([track,close].map{$0.convert($0.bounds,to:nil)}==positions,"AT-UC-10 header fixed after scroll")
        try capture("task-01-after-"+theme.rawValue,view)
        let image=bitmap(view),marginX=drawer.frame.minX+3
        let margin14=pixel(image,view,CGPoint(x:marginX,y:h-14)),margin60=pixel(image,view,CGPoint(x:marginX,y:h-60))
        try check(delta(margin14,margin60)<=6/255 && delta(margin14,emptySample)<=6/255 && delta(margin60,emptySample)<=6/255 && sidebarTone(image),"AT-UC-12 scrolled outer margin matches empty column")
        let longLast=drawer.cardViews.last!
        try check(longLast.card.id==shortLast.card.id && delta(lastPixel,pixel(image,view,longLast.convert(lastPoint,to:view)))<=6/255,"AT-UC-12 last card viewport pixel stays unchanged after scrolling")
        refresh()

    }
    try check(!all(drawer).compactMap{$0 as? NSTextField}.contains{["급한 것","나머지"].contains($0.stringValue)},"AT-UC-15 no group titles")
    let dividers=all(drawer).filter{String(describing:type(of:$0))=="TodoDrawerDivider"}
    try check(dividers.count==1,"AT-UC-15 mixed groups have one divider")
    controller.drawerFilter = .alert;refresh()
    try check(!all(drawer).contains{String(describing:type(of:$0))=="TodoDrawerDivider"},"AT-UC-15 rest-only has no divider")
    var zero=controller.drawerSnapshot;zero.counts[.question]=0
    drawer.show(zero,filter:.all,selected:nil);settle()
    let zeroButton=track.subviews.compactMap{$0 as? ComposerButton}.first{$0.title=="답 요청 0"}!
    try check(abs(zeroButton.textAlpha-0.4)<=0.05 && track.subviews.compactMap{$0 as? ComposerButton}.filter{$0 !== zeroButton}.allSatisfy{$0.textAlpha==1},"AT-UC-11 zero filter dimming only")
    zeroButton.performClick(nil);settle();try check(controller.drawerFilter == .question,"AT-UC-11 zero filter remains clickable")
    controller.drawerFilter = .question;refresh()
    pet.panel.makeFirstResponder(drawer)
    drawer.moveDown(nil);try check(view.drawerSelectedID==question,"AT-UC-18 first down selects first")
    drawer.moveDown(nil);try check(view.drawerSelectedID==other,"AT-UC-18 second down selects next")
    drawer.moveUp(nil);drawer.insertNewline(nil)
    try check(view.drawerSelectedID==question && view.highlightedMessageID==question,"AT-UC-18 up and enter activate first")
    now.addTimeInterval(2);view.tickIsland();refresh()
    try check(view.highlightedMessageID==question && view.replyMode && controller.composeKey==controller.model.messages[question]!.key,"AT-UC-17 reply selection survives two seconds")
    let selected=drawer.cardViews.first{$0.card.id==question}!
    let reference=UICleanAccentReference(frame:selected.bounds);drawer.addSubview(reference)
    let accent=pixel(bitmap(reference),reference,CGPoint(x:0.5,y:26))
    reference.removeFromSuperview()
    for theme in [ChatTheme.dark,.light] {
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance();refresh()
        view.selectDrawerCard(card("가짜 질문"));settle()
        let thread=controller.model.messages[question]!.key.thread
        try await waitFor {
            guard let rect=view.history.frame(for:thread) else{return false}
            return view.history.documentVisibleRect.contains(CGPoint(x:rect.midX,y:rect.midY))
        }
        // scrollTo re-applies placement through 0.45s to absorb native row measurement.
        await pause(0.5);settle()
        let rect=view.history.frame(for:thread)!,index=view.history.contents.firstIndex{$0.id==thread}!
        let visibleCard=view.history.table.view(atColumn:0,row:index,makeIfNecessary:false) as? NativeThreadCard
        try check(view.history.documentVisibleRect.contains(CGPoint(x:rect.midX,y:rect.midY)) && visibleCard?.value?.content.style.lineWidth==2 && visibleCard?.value?.content.style.stroke == .controlAccentColor,"AT-UC-17 selected thread visibly highlighted after scrolling settles")
        try capture("task-01-selected-settled-"+theme.rawValue,view)
    }
    try capture("task-01-selected",view)
    let selectedBorder=pixel(bitmap(selected),selected,CGPoint(x:0.5,y:26))
    print("AT-UC-16 accent samples: border=\(selectedBorder) reference=\(accent)")
    try check(delta(selectedBorder,accent)<=6/255,"AT-UC-16 selected border accent")
    try check(view.history.contents.contains{$0.style.lineWidth==2 && $0.style.stroke == .controlAccentColor},"AT-UC-17 selected thread accent")
    view.selectDrawerCard(card("다른 질문"));try check(view.highlightedMessageID==other && view.drawerSelectedID==other,"AT-UC-17 different card replaces highlight")
    pet.panel.makeFirstResponder(view.editor.editor);let previous=view.drawerSelectedID
    drawer.moveDown(nil);try check(view.drawerSelectedID==previous,"AT-UC-18 editor focus leaves drawer arrows alone")
    pet.panel.makeFirstResponder(drawer);drawer.cancelOperation(nil);settle()
    try check(!pet.drawerOpen && view.drawerSelectedID==nil && view.highlightedMessageID==nil,"AT-UC-17/18 escape closes and clears selection")
    pet.setDrawerOpen(true);refresh();try check(view.drawerSelectedID==nil,"AT-UC-18 reopening has no selection")
    let empty=TodoDrawerModel.Snapshot();drawer.show(empty,filter:.all,selected:nil);settle()
    try check(all(drawer).compactMap{$0 as? NSTextField}.contains{$0.stringValue=="모두 처리했어요"},"AT-UC-19 empty copy")
    _=alert
    print("AT-UC-10..19 DRAWER PASS")
}

/// Resolve the acceptance reference colour through the same window colour space as the rendered border.
private final class UICleanAccentReference:NSView {
    override func draw(_ dirtyRect:NSRect) {NSColor.controlAccentColor.setFill();bounds.fill()}
}
