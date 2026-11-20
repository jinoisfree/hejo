import AppKit

/// AT-TD-20..42: real projection, pill input, native panel geometry and request cadence.
@MainActor func todoDrawerTests(resourceDirectory:URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials())
    let controller=try testConversation(client:client),model=controller.model
    var now=ThreadTools.date("2026-11-20T10:00:00+09:00")
    controller.clock={now}
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"Asia/Seoul")!
    try await client.receive(["v":1,"type":"welcome","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]],["id":"default","name":"기본 직원","aliases":[]]]])
    var seq=0
    @discardableResult func post(_ text:String,employee:String="alpha",asked:Bool=false,age:Double=0)->String {
        seq+=1;let id=UUID().uuidString.lowercased()
        let frame:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":UUID().uuidString.lowercased(),"role":"employee","text":text,"files":[],"buttons":[],"reply_state":asked ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now.addingTimeInterval(-age))]
        try! store.append(frame);controller.receive(frame);return id
    }
    let q1=post("질문 A\n둘째 줄",asked:true,age:600),q2=post("질문 B",employee:"beta",asked:true,age:3600)
    let alert=post("가짜 알림",age:100)
    post("숨긴 질문",employee:"default",asked:true);model.toggleMute("default")
    let rows:[[String:Any]]=[
        ["employee":"alpha","id":"notion:past","title":"지남","due":"2026-11-19"],
        ["employee":"alpha","id":"notion:today","title":"오늘","due":"2026-11-20","deadline_at":"2026-11-20T18:00:00+09:00"],
        ["employee":"alpha","id":"notion:tomorrow","title":"내일","due":"2026-11-21"],
        ["employee":"alpha","id":"notion:later","title":"나중","due":"2026-11-24"]]
    controller.todoDrawer.receive(["available":true,"items":rows,"failed":[]])
    let snapshot=controller.todoDrawer.snapshot(model,now:now,calendar:calendar)
    try check(snapshot.urgent.map(\.title)==["지남","오늘","내일","질문 B","질문 A"] && snapshot.rest.map(\.title)==["나중","가짜 알림"] && snapshot.total==7,"AT-TD-20 ordering, deduplication, muted exclusion, total")
    try check(snapshot.urgent[0].badge=="D+1" && snapshot.urgent[1].badge=="D-DAY" && snapshot.urgent[1].time=="오늘 18시까지" && snapshot.rest[0].badge=="D-4" && snapshot.rest[0].time=="11월 24일까지","AT-TD-22 calendar labels")
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    var visible=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:visible,visible:visible)] };pet.reducedMotion={true}
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:CGPoint(x:650,y:700));pet.showChat();view.refresh();view.layoutSubtreeIfNeeded()
    defer{pet.web?.unload();pet.panel.orderOut(nil);client.stop()}
    var requests:[[String:Any]]=[]
    controller.deadlineSender={requests.append($0)}
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded()}
    let closed=pet.panel.frame,closedContent=pet.placementTarget!.contentBubble
    try check(view.island.partRects.contains{$0.0.kind == .owner},"AT-TD-41 connected owner segment is present")
    let ownerRect=view.island.partRects.first{$0.0.kind == .owner}!.1
    view.island.activate(at:CGPoint(x:ownerRect.midX,y:15));settle()
    try check(pet.drawerOpen && pet.pet.todoDrawer?.isHidden == false && pet.panel.frame.minX==closed.minX-290 && pet.panel.frame.width==closed.width+290,"AT-TD-41 owner input reaches real controller and native view")
    try check(pet.placementTarget!.contentBubble==closedContent,"AT-TD-31 entire chat rectangle stays fixed")
    try check(view.island.snapshot.drawerOpen && view.island.snapshot.parts.first{$0.kind == .owner}!.text.hasSuffix(" · 닫기 ‹"),"AT-TD-27 close label and highlighted snapshot")
    view.island.activate(at:CGPoint(x:view.island.partRects.first{$0.0.kind == .owner}!.1.midX,y:15));settle()
    try check(!pet.drawerOpen && pet.panel.frame==closed && pet.pet.todoDrawer?.isHidden == true,"AT-TD-41 second owner input restores panel")
    controller.drawerFilter = .deadline;pet.toggleDrawer();pet.toggleDrawer();pet.toggleDrawer()
    try check(controller.drawerSnapshot.urgent.count+controller.drawerSnapshot.rest.count==4 && controller.drawerFilter == .deadline,"AT-TD-21 reopen retains deadline filter")
    let fresh=try testConversation(client:GateClient(store:try LocalStore(directory:home.appendingPathComponent("fresh")),credentials:MemoryCredentials()))
    try check(fresh.drawerFilter == .all,"AT-TD-21 new controller starts at all")
    controller.drawerFilter = .all
    let question=snapshot.urgent.first{$0.messageID==q1}!
    view.selectDrawerCard(question)
    try check(model.selected==model.messages[q1]!.key && view.highlightedMessageID==q1 && pet.drawerOpen && view.drawerSelectedID==q1,"AT-TD-25 selection and reveal preserve drawer")
    now.addTimeInterval(1.49);view.tickIsland();try check(view.highlightedMessageID==q1,"AT-TD-25 highlight remains before 1.5 seconds")
    now.addTimeInterval(0.02);view.tickIsland();try check(view.highlightedMessageID==nil,"AT-TD-25 highlight ends at 1.5 seconds")
    let notice=snapshot.rest.first{$0.messageID==alert}!
    view.selectDrawerCard(notice)
    try check(model.selected==model.messages[alert]!.key && view.highlightedMessageID==alert && pet.drawerOpen && !controller.drawerSnapshot.rest.contains{$0.messageID==alert},"AT-TD-39 alert reveal marks bell and removes the card")
    now.addTimeInterval(1.51);view.tickIsland();try check(view.highlightedMessageID==nil,"AT-TD-39 alert highlight ends")
    var urls:[URL]=[];view.onOpenURL={urls.append($0)}
    var linked=snapshot.urgent[0];linked.url=URL(string:"https://example.invalid/x")!
    view.selectDrawerCard(linked);try check(urls==[linked.url!],"AT-TD-26 link follows existing URL path exactly once")
    view.selectDrawerCard(snapshot.urgent[0]);try check(model.selected?.employee=="alpha","AT-TD-26 no URL selects direct room")
    controller.todoDrawer.receive(["available":true,"reason":"command_failed"])
    try check(controller.todoDrawer.deadlines.count==4 && controller.drawerSnapshot.warning != nil,"AT-TD-24 failure preserves last list")
    let empty=TodoDrawerModel();empty.receive(["available":true,"reason":"command_failed"])
    try check(empty.snapshot(model,now:now).failed && empty.deadlines.isEmpty,"AT-TD-24 failure before success")
    controller.todoDrawer.receive(["available":false,"items":[]])
    try check(!controller.drawerSnapshot.available && controller.drawerSnapshot.warning==nil && controller.todoDrawer.deadlines.isEmpty,"AT-TD-24 unavailable hides deadlines and warning")
    controller.todoDrawer.receive(["type":"error"]);try check(!controller.drawerSnapshot.available,"AT-TD-24 old gate error")
    controller.todoDrawer.receive(["available":true,"items":Array(rows.prefix(2)),"failed":["beta"]])
    try check(controller.drawerSnapshot.counts[.deadline]==2 && controller.drawerSnapshot.warning != nil,"AT-TD-40 partial success shows cards and warning")
    controller.todoDrawer.receive(["available":true,"items":Array(rows.prefix(2)),"failed":[]]);try check(controller.drawerSnapshot.warning==nil,"AT-TD-40 next full success clears warning")
    pet.panel.cancelOperation(nil);settle();try check(!pet.drawerOpen && pet.chatExpanded,"AT-TD-30 escape closes drawer first")
    pet.toggleDrawer();view.todoDrawer.onClose?();settle();try check(!pet.drawerOpen,"AT-TD-30 fold control closes drawer")
    pet.placePet(at:CGPoint(x:200,y:700));let overlayFrame=pet.panel.frame
    pet.toggleDrawer();settle()
    try check(pet.placementTarget!.drawerOverlay && pet.panel.frame==overlayFrame && !pet.pet.drawerScrim.isHidden,"AT-TD-33 missing left space overlays without moving panel")
    pet.pet.drawerScrim.onClose?();try check(!pet.drawerOpen,"AT-TD-30 overlay scrim closes")
    pet.placePet(at:CGPoint(x:650,y:700));pet.toggleDrawer();settle()
    try check(pet.pet.drawerScrim.isHidden && pet.drawerOpen,"AT-TD-30 expanded chat has no intercepting scrim")
    let stateKeys=store.settings.pendingState
    try check(store.settings.todoDrawerOpen==true,"AT-TD-36 persisted local state")
    let reopened=PetController(store:try LocalStore(directory:home),atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    reopened.displays=pet.displays;reopened.reducedMotion={true};reopened.showChat()
    try check(reopened.drawerOpen && reopened.pet.drawerOpen && store.settings.pendingState==stateKeys,"AT-TD-36 restore and member state unchanged")
    reopened.panel.orderOut(nil)
    // Deterministic motion goes through bubbleMotion, without the web width cover.
    pet.setDrawerOpen(false);settle();pet.reducedMotion={false}
    var motion=100.0;pet.clock={motion};let start=pet.panel.frame
    pet.toggleDrawer();motion+=0.125;settle()
    try check(pet.panel.frame.minX<start.minX && pet.panel.frame.minX>start.minX-290 && !pet.pet.widthCoverVisible,"AT-TD-32 intermediate frame without width cover")
    try check(abs(view.convert(.zero,to:nil).x+pet.panel.frame.minX-(closedContent.minX))<0.5,"AT-TD-31 chat stays still during motion")
    motion+=0.125;settle();try check(pet.panel.frame.minX==start.minX-290,"AT-TD-32 target at 0.25 seconds")
    pet.reducedMotion={true};pet.setDrawerOpen(false);settle();pet.toggleDrawer();try check(pet.panel.frame==pet.placementTarget!.windowFrame,"AT-TD-32 reduced motion immediate")
    // Dragging and folding recalculate placement, while retaining the preference.
    pet.beginChatDrag(at:CGPoint(x:700,y:700));pet.moveChatDrag(to:CGPoint(x:100,y:700));pet.endChatDrag();settle()
    try check(pet.placementTarget!.drawerOverlay,"AT-TD-35 drag near left switches to overlay")
    pet.collapseChat();try check(pet.pet.todoDrawer?.isHidden == true && pet.drawerOpen,"AT-TD-35 folding hides without clearing preference")
    pet.showChat();try check(pet.drawerOpen && pet.pet.todoDrawer?.isHidden == false && pet.placementTarget!.drawerOverlay,"AT-TD-35 reopening reevaluates mode")
    // The web pane keeps the same width when the drawer cannot fit.
    pet.setDrawerOpen(false);visible=CGRect(x:0,y:0,width:2400,height:1000);pet.placePet(at:CGPoint(x:900,y:750))
    let web=WebPaneModel(downloads:controller.files.downloads.root);web.persistent=false;pet.installWeb(web)
    web.open(URL(string:"https://example.invalid/x")!);settle();let webWidth=pet.pet.paneWidth,withWeb=pet.panel.frame
    pet.toggleDrawer();settle()
    try check(!pet.placementTarget!.drawerOverlay && pet.pet.paneWidth==webWidth && pet.panel.frame.width==withWeb.width+290,"AT-TD-34 wide screen fits both and keeps web width")
    pet.setDrawerOpen(false);visible=CGRect(x:0,y:0,width:1300,height:1000);pet.placePet(at:CGPoint(x:700,y:750));settle();let narrowWeb=pet.pet.paneWidth
    pet.toggleDrawer();settle();try check(pet.placementTarget!.drawerOverlay && pet.pet.paneWidth==narrowWeb,"AT-TD-34 narrow screen overlays rather than narrowing web")
    web.close();settle();try check(pet.drawerOpen,"AT-TD-34 closing web preserves drawer")
    // A genuinely empty pill is activated through the same real view/controller wiring.
    controller.todoDrawer.receive(["available":false]);model.toggleMute("default")
    seq+=1;let deleteQuestion:[String:Any]=["type":"state","seq":seq,"msg_id":q1,"reply_state":"answered"];try store.append(deleteQuestion);controller.receive(deleteQuestion)
    seq+=1;let deleteQuestion2:[String:Any]=["type":"state","seq":seq,"msg_id":q2,"reply_state":"answered"];try store.append(deleteQuestion2);controller.receive(deleteQuestion2)
    let emptyHome=home.appendingPathComponent("empty"),emptyStore=try LocalStore(directory:emptyHome)
    let emptyController=try testConversation(client:GateClient(store:emptyStore,credentials:MemoryCredentials()))
    emptyController.deadlineSender={_ in}
    try await emptyController.client.receive(["v":1,"type":"welcome","employees":[]])
    let emptyView=ConversationView(controller:emptyController,clipboardArea:emptyHome.appendingPathComponent("clipboard"))
    let emptyPet=PetController(store:emptyStore,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory));emptyPet.displays={ [PetDisplay(frame:visible,visible:visible)] };emptyPet.reducedMotion={true}
    emptyPet.pet.installConversation(emptyView);emptyPet.installDrawer(emptyView);emptyPet.placePet(at:CGPoint(x:650,y:700));emptyPet.showChat();emptyView.layoutSubtreeIfNeeded()
    let emptyFrame=emptyPet.panel.frame
    emptyView.island.activate(at:CGPoint(x:10,y:15));emptyView.layoutSubtreeIfNeeded()
    try check(emptyPet.drawerOpen && !emptyView.todoDrawer.isHidden && emptyPet.panel.frame.minX==emptyFrame.minX-290 && emptyPet.panel.frame.width==emptyFrame.width+290 && emptyView.island.snapshot.parts.map(\.text)==["닫기 ‹"],"AT-TD-27/41 empty stripe opens actual drawer")
    emptyView.island.activate(at:CGPoint(x:10,y:15));try check(!emptyPet.drawerOpen && emptyPet.panel.frame==emptyFrame && emptyView.todoDrawer.isHidden,"AT-TD-41 empty pill second click restores frame")
    emptyPet.panel.orderOut(nil)
    try check(emptyController.drawerSnapshot.empty,"AT-TD-23 empty projection")
    let oneID=UUID().uuidString.lowercased()
    let one:[String:Any]=["v":1,"type":"message","seq":1,"msg_id":oneID,"employee":"alpha","thread":UUID().uuidString.lowercased(),"role":"employee","text":"가짜 질문","reply_state":"asked","ts":ISO8601DateFormatter().string(from:now),"files":[],"buttons":[]]
    emptyController.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    emptyController.clock={now};emptyController.receive(one)
    try check(emptyController.drawerSnapshot.total==1,"AT-TD-23 question appears live")
    emptyController.receive(["type":"state","seq":2,"msg_id":oneID,"reply_state":"answered"])
    try check(emptyController.drawerSnapshot.empty,"AT-TD-23 answered question disappears live")
    pet.setDrawerOpen(true)
    let workerModel=IslandModel(clock:{now});workerModel.update(IslandModel.Input(typing:[model.messages[q2]!.key:now.addingTimeInterval(60)],drawerOpen:true))
    view.island.show(workerModel.snapshot());view.island.frame.size.width=view.island.fittedWidth(limit:400);view.island.layoutSubtreeIfNeeded()
    let face=view.island.partRects.first{$0.0.kind == .worker}!.1
    view.island.activate(at:CGPoint(x:face.minX+8,y:15))
    try check(pet.drawerOpen && model.selected==model.messages[q2]!.key,"AT-TD-28 worker face input preserves drawer")
    var retries=0;view.reconnect={retries+=1}
    let problem=IslandModel(clock:{now});problem.update(IslandModel.Input(status:.disconnected(3),drawerOpen:true))
    view.island.show(problem.snapshot());view.island.frame.size.width=view.island.fittedWidth(limit:400);view.island.layoutSubtreeIfNeeded();view.island.activate(at:CGPoint(x:10,y:15))
    try check(retries==1 && pet.drawerOpen,"AT-TD-28 problem action preserves drawer")
    let preview=IslandModel(clock:{now})
    var previewInput=IslandModel.Input(messages:[model.messages[q1]!],drawerOpen:true)
    previewInput.messages[0].replyState="asked";preview.update(previewInput)
    var later=model.messages[q2]!;later.replyState="asked";previewInput.messages.append(later);preview.update(previewInput)
    try check(preview.snapshot().expanded == .owner && preview.snapshot().parts.first{$0.kind == .owner}?.action == .question(q1,model.messages[q1]!.key) && preview.snapshot().drawerOpen,"AT-TD-29 preview still targets oldest and preserves drawer")
    // Cadence uses controller clock and the same outgoing request path, with a fake gate sender.
    pet.setDrawerOpen(false);await pause(0.01);requests=[];now.addTimeInterval(600);controller.pollDeadlines();await pause(0.01)
    try check(requests.isEmpty,"AT-TD-37 closed ten minutes sends nothing")
    pet.toggleDrawer();await pause(0.01);now.addTimeInterval(300);controller.pollDeadlines();await pause(0.01);now.addTimeInterval(300);controller.pollDeadlines();await pause(0.01);now.addTimeInterval(60);controller.pollDeadlines();await pause(0.01)
    try check(requests.count==3,"AT-TD-37 opening plus five and ten minutes")
    controller.receive(["type":"welcome","employees":[]]);await pause(0.01)
    try check(requests.count==4,"AT-TD-37 reconnect while open refreshes once")
    let last=requests.last!["id"] as! String
    controller.receive(["type":"error","ref":last,"code":"invalid_frame"])
    try check(!controller.todoDrawer.available,"AT-TD-24 old gate error routed by request ref")
    // AT-TD-42: native folding and restored preference must suppress outgoing requests.
    pet.collapseChat();await pause(0.01);requests=[]
    for _ in 0..<11 {now.addTimeInterval(60);controller.pollDeadlines();await pause(0.01)}
    controller.receive(["type":"welcome","employees":[]]);await pause(0.01)
    try check(pet.drawerOpen && !controller.drawerVisible && requests.isEmpty,"AT-TD-42 folded eleven minutes and reconnect send nothing")
    pet.showChat();await pause(0.01)
    try check(controller.drawerVisible && requests.count==1,"AT-TD-42 unfolding open preference requests exactly once")
    now.addTimeInterval(299);controller.pollDeadlines();await pause(0.01)
    try check(requests.count==1,"AT-TD-42 unfolding restarts five minute period")
    now.addTimeInterval(1);controller.pollDeadlines();await pause(0.01)
    try check(requests.count==2,"AT-TD-42 first new period requests once")
    let restoredStore=try LocalStore(directory:home)
    let restoredController=try testConversation(client:GateClient(store:restoredStore,credentials:MemoryCredentials()))
    restoredController.clock={now}
    var restoredRequests:[[String:Any]]=[]
    restoredController.deadlineSender={restoredRequests.append($0)}
    let restoredView=ConversationView(controller:restoredController,clipboardArea:home.appendingPathComponent("restored-clipboard"))
    let restoredPet=PetController(store:restoredStore,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    restoredPet.displays=pet.displays;restoredPet.reducedMotion={true}
    restoredPet.pet.installConversation(restoredView);restoredPet.installDrawer(restoredView)
    restoredPet.placePet(at:CGPoint(x:650,y:700))
    restoredController.receive(["type":"welcome","employees":[]])
    for _ in 0..<11 {now.addTimeInterval(60);restoredController.pollDeadlines();await pause(0.01)}
    try check(restoredPet.drawerOpen && !restoredPet.chatExpanded && !restoredController.drawerVisible && restoredRequests.isEmpty,"AT-TD-42 restored open preference starts folded without requests")
    restoredPet.showChat();await pause(0.01)
    try check(restoredController.drawerVisible && restoredRequests.count==1,"AT-TD-42 restored drawer requests once on first unfolding")
    restoredPet.panel.orderOut(nil);restoredController.client.stop()
    // V-1: hidden refresh/tick must not rebuild cards or request their pictures.
    let originalAvatar=view.todoDrawer.avatar
    var avatarReads=0
    view.todoDrawer.avatar={employee in avatarReads+=1;return originalAvatar(employee)}
    pet.setDrawerOpen(false)
    controller.todoDrawer.receive(["available":true,"items":rows,"failed":[]])
    view.refresh();now.addTimeInterval(1);view.tickIsland()
    try check(avatarReads==0,"V-1 closed drawer does not project changed cards on refresh or tick")
    pet.setDrawerOpen(true)
    try check(avatarReads>0,"V-1 opening projects latest cards immediately")
    pet.collapseChat();avatarReads=0
    controller.todoDrawer.receive(["available":true,"items":Array(rows.prefix(1)),"failed":[]])
    view.refresh();now.addTimeInterval(1);view.tickIsland()
    try check(avatarReads==0,"V-1 folded drawer does not project changed cards on refresh or tick")
    pet.showChat()
    try check(avatarReads>0,"V-1 unfolding projects latest cards immediately")
    view.todoDrawer.avatar=originalAvatar
    print("AT-TD-20..42 MODEL, INPUT, WINDOW, REQUEST PASS")
}
