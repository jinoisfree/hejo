import AppKit

/// Drawer fixtures own native windows and may outlive their test through AppKit callbacks.
/// Detach their views and stop the client before the next animation test runs.
@MainActor func disposeDrawerFixture(_ pet:PetController,_ controller:ConversationController,_ view:ConversationView) {
    pet.reducedMotion={true}
    pet.setDrawerOpen(false)
    pet.pet.animationsAllowed=false
    pet.web?.unload()
    view.removeFromSuperview();view.todoDrawer.removeFromSuperview()
    pet.panel.makeFirstResponder(nil);pet.panel.contentView=nil;pet.panel.close()
    controller.client.stop()
}

/// AT-TD-20..42: real projection, pill input, native panel geometry and request cadence.
@MainActor func todoDrawerTests(resourceDirectory:URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials())
    let controller=try testConversation(client:client),model=controller.model
    let historyStore = try LocalStore(directory: home.appendingPathComponent("history"), historyMode: true)
    let historyController = try testConversation(client: GateClient(store: historyStore, credentials: MemoryCredentials()))
    defer { historyController.client.stop() }
    let refreshing = historyController.todoDrawer.snapshot(historyController.model, now: Date())
    let needsUpdate = historyController.todoDrawer.snapshot(historyController.model, now: Date(), gateStatus: .updateRequired)
    try check(refreshing.warning == "대화 알림을 갱신 중이에요." && needsUpdate.historyUpdating
              && needsUpdate.warning == ConnectionStatus.updateRequired.text,
              "AT-HO-05 drawer update warning takes priority over history refresh")
    print("AT-HO-05 DRAWER PASS")
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
    try check(snapshot.urgent[0].status=="마감 1일 지남 · 연결된 대화 없음" && snapshot.urgent[1].status=="오늘 마감 · 연결된 대화 없음" && snapshot.urgent[1].trailing=="18:00" && snapshot.rest[0].status=="마감 4일 남음 · 연결된 대화 없음" && snapshot.rest[0].trailing=="11/24","AT-TD-22 calendar labels")
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
    view.island.reduceMotion={true}
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer{disposeDrawerFixture(pet,controller,view)}
    var visible=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:visible,visible:visible)] };pet.reducedMotion={true}
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:CGPoint(x:650,y:700));pet.showChat();view.refresh();view.layoutSubtreeIfNeeded()
    var requests:[[String:Any]]=[]
    controller.deadlineSender={requests.append($0)}
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded()}
    let closed=pet.panel.frame
    let closedPlacement=pet.placementTarget!
    try check(closedPlacement.globalBubble.maxX+290<=1428,"AT-DI-33 owner fixture has right expansion room")
    try check(!view.island.titleRect.isEmpty,"AT-TD-41 connected owner segment is present")
    let ownerRect=view.island.titleRect
    view.island.activate(at:CGPoint(x:ownerRect.midX,y:15));settle()
    try check(pet.drawerOpen && view.todoDrawer.isHidden == false && pet.panel.frame.minX==closed.minX && pet.panel.frame.width==closed.width+290 && pet.placementTarget!.globalSprite==closedPlacement.globalSprite,"AT-TD-41 owner input reaches real controller and native view")
    try check(view.island.snapshot.drawerOpen && view.island.accessibilityLabel()?.contains("닫기") == false,"AT-TD-27 close label and highlighted snapshot")
    view.island.activate(at:CGPoint(x:view.island.titleRect.midX,y:15));settle()
    try check(!pet.drawerOpen && pet.panel.frame==closed && view.todoDrawer.isHidden == true,"AT-TD-41 second owner input restores panel")
    controller.drawerFilter = .deadline;pet.toggleDrawer();pet.toggleDrawer();pet.toggleDrawer()
    try check(controller.drawerSnapshot.urgent.count+controller.drawerSnapshot.rest.count==4 && controller.drawerFilter == .deadline,"AT-TD-21 reopen retains deadline filter")
    let fresh=try testConversation(client:GateClient(store:try LocalStore(directory:home.appendingPathComponent("fresh")),credentials:MemoryCredentials()))
    defer{fresh.client.stop()}
    try check(fresh.drawerFilter == .all,"AT-TD-21 new controller starts at all")
    controller.drawerFilter = .all
    let question=snapshot.urgent.first{$0.messageID==q1}!
    view.selectDrawerCard(question)
    try check(model.selected==model.messages[q1]!.key && view.highlightedMessageID==q1 && pet.drawerOpen && view.drawerSelectedID==q1,"AT-TD-25 selection and reveal preserve drawer")
    now.addTimeInterval(1.49);view.tickIsland();try check(view.highlightedMessageID==q1,"AT-TD-25 highlight remains before 1.5 seconds")
    now.addTimeInterval(0.02);view.tickIsland();try check(view.highlightedMessageID==q1,"AT-TD-25 drawer selection persists after 1.5 seconds")
    let notice=snapshot.rest.first{$0.messageID==alert}!
    view.selectDrawerCard(notice)
    try check(model.selected==model.messages[alert]!.key && view.highlightedMessageID==alert && pet.drawerOpen && !controller.drawerSnapshot.rest.contains{$0.messageID==alert},"AT-TD-39 alert reveal marks bell and removes the card")
    now.addTimeInterval(1.51);view.tickIsland();try check(view.highlightedMessageID==nil,"AT-TD-39 alert highlight ends")
    var urls:[URL]=[];view.onOpenURL={urls.append($0)}
    var linked=snapshot.urgent[0];linked.url=URL(string:"https://example.invalid/x")!
    view.selectDrawerCard(linked);try check(urls==[linked.url!],"AT-TD-26 link follows existing URL path exactly once")
    // AT-TD-26 "no URL selects the direct room" is replaced by AT-DC-25: nowhere to go changes nothing.
    let selectedBefore=model.selected
    view.selectDrawerCard(snapshot.urgent[0]);try check(model.selected==selectedBefore && view.drawerSelectedID==snapshot.urgent[0].id,"AT-DC-25 no URL and no notice keeps the room and selects the card")
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
    pet.setDrawerOpen(true);settle()
    let stateKeys=store.settings.pendingState
    try check(store.settings.todoDrawerOpen==true,"AT-TD-36 persisted local state")
    let reopened=PetController(store:try LocalStore(directory:home),atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer{reopened.pet.animationsAllowed=false;reopened.panel.contentView=nil;reopened.panel.close()}
    reopened.displays=pet.displays;reopened.reducedMotion={true};reopened.showChat()
    try check(reopened.drawerOpen && store.settings.pendingState==stateKeys,"AT-TD-36 restore and member state unchanged")
    reopened.panel.orderOut(nil)
    // A genuinely empty pill is activated through the same real view/controller wiring.
    controller.todoDrawer.receive(["available":false]);model.toggleMute("default")
    seq+=1;let deleteQuestion:[String:Any]=["type":"state","seq":seq,"msg_id":q1,"reply_state":"answered"];try store.append(deleteQuestion);controller.receive(deleteQuestion)
    seq+=1;let deleteQuestion2:[String:Any]=["type":"state","seq":seq,"msg_id":q2,"reply_state":"answered"];try store.append(deleteQuestion2);controller.receive(deleteQuestion2)
    let emptyHome=home.appendingPathComponent("empty"),emptyStore=try LocalStore(directory:emptyHome)
    let emptyController=try testConversation(client:GateClient(store:emptyStore,credentials:MemoryCredentials()))
    emptyController.deadlineSender={_ in}
    try await emptyController.client.receive(["v":1,"type":"welcome","employees":[]])
    let emptyView=ConversationView(controller:emptyController,clipboardArea:emptyHome.appendingPathComponent("clipboard"))
    emptyView.island.reduceMotion={true}
    let emptyPet=PetController(store:emptyStore,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory));emptyPet.displays={ [PetDisplay(frame:visible,visible:visible)] };emptyPet.reducedMotion={true}
    defer{disposeDrawerFixture(emptyPet,emptyController,emptyView)}
    emptyPet.pet.installConversation(emptyView);emptyPet.installDrawer(emptyView);emptyPet.placePet(at:CGPoint(x:650,y:700));emptyPet.showChat();emptyView.layoutSubtreeIfNeeded()
    let emptyFrame=emptyPet.panel.frame
    let emptyPlacement=emptyPet.placementTarget!
    try check(emptyPlacement.globalBubble.maxX+290<=1428,"AT-DI-33 empty fixture has right expansion room")
    emptyView.island.activate(at:CGPoint(x:10,y:15));emptyView.layoutSubtreeIfNeeded()
    try check(emptyPet.drawerOpen && !emptyView.todoDrawer.isHidden && emptyPet.panel.frame.minX==emptyFrame.minX && emptyPet.panel.frame.width==emptyFrame.width+290 && emptyPet.placementTarget!.globalSprite==emptyPlacement.globalSprite && emptyView.island.snapshot.drawerOpen && emptyView.island.accessibilityLabel()?.contains("닫기") == false,"AT-TD-27/41 empty stripe opens actual drawer")
    print("AT-DI-33 OWNER AND EMPTY PILL RIGHT EXPANSION PASS")
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
    let face=view.island.activityRect
    view.island.activate(at:CGPoint(x:face.minX+8,y:15))
    try check(pet.drawerOpen && model.selected==model.messages[q2]!.key,"AT-TD-28 worker face input preserves drawer")
    var retries=0;view.reconnect={retries+=1}
    let problem=IslandModel(clock:{now});problem.update(IslandModel.Input(status:.disconnected(3),drawerOpen:true))
    view.island.show(problem.snapshot());view.island.frame.size.width=view.island.fittedWidth(limit:400);view.island.layoutSubtreeIfNeeded();view.island.activate(at:CGPoint(x:view.island.activityRect.midX,y:15))
    try check(retries==1 && pet.drawerOpen,"AT-TD-28 problem action preserves drawer")
    let preview=IslandModel(clock:{now})
    var previewInput=IslandModel.Input(messages:[model.messages[q1]!],drawerOpen:true)
    previewInput.messages[0].replyState="asked";preview.update(previewInput)
    var later=model.messages[q2]!;later.replyState="asked";previewInput.messages.append(later);preview.update(previewInput)
    try check(preview.snapshot().expanded == .question && preview.snapshot().activity?.action == .question(q1,model.messages[q1]!.key) && preview.snapshot().drawerOpen,"AT-TD-29 preview still targets oldest and preserves drawer")
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
    defer{disposeDrawerFixture(restoredPet,restoredController,restoredView)}
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


/// AT-DC-21..34, 27d: deadline cards go to their notice, say when they cannot, and close with a right click.
@MainActor func deadlineCloseTests(resourceDirectory:URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials())
    let controller=try testConversation(client:client),model=controller.model
    var now=ThreadTools.date("2026-11-22T10:00:00+09:00")
    controller.clock={now}
    try await client.receive(["v":1,"type":"welcome","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]])
    var seq=0
    @discardableResult func post(_ text:String,employee:String="alpha",asked:Bool=false)->String {
        seq+=1;let id=UUID().uuidString.lowercased()
        let frame:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":UUID().uuidString.lowercased(),"role":"employee","text":text,"files":[],"buttons":[],"reply_state":asked ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now)]
        try! store.append(frame);controller.receive(frame);return id
    }
    let noticeMessage=post("마감 알림 글")
    let question=post("가짜 질문",employee:"beta",asked:true)
    func row(_ id:String,_ title:String,due:String,origin:String?=nil,notice:String?=nil,url:String?=nil)->[String:Any] {
        var value:[String:Any]=["employee":"alpha","id":id,"title":title,"due":due]
        if let origin {value["origin"]=origin};if let url {value["url"]=url}
        if let notice {value["notice"]=["message_id":notice,"thread":"thread-"+notice]}
        return value
    }
    let rows=[row("reminder:r1","미리알림 마감",due:"2026-11-21",origin:"reminder"),
              row("gmail:g1","메일 마감",due:"2026-11-22",origin:"gmail",notice:noticeMessage),
              row("notion:n1","링크 마감",due:"2026-11-26",url:"https://example.invalid/x"),
              row("gmail:g2","없는 글 마감",due:"2026-11-27",origin:"gmail",notice:"missing-message"),
              row("slack:s1","갈 곳 없는 마감",due:"2026-11-28")]
    var requests:[[String:Any]]=[]
    controller.deadlineSender={requests.append($0)}
    func sent(_ type:String)->[[String:Any]] {requests.filter{$0["type"] as? String==type}}
    func answer(_ request:[String:Any],_ items:[[String:Any]],failed:[String]=[],reason:String?=nil) {
        var frame:[String:Any]=["v":1,"type":"deadlines_status","ref":request["id"] as! String,"available":true]
        if let reason {frame["reason"]=reason}else{frame["items"]=items;frame["failed"]=failed}
        controller.receive(frame)
    }
    func cards()->[TodoDrawerModel.Card] {let value=controller.drawerSnapshot;return value.urgent+value.rest}
    func titles()->[String] {cards().filter{$0.kind == .deadline}.map(\.title)}
    func card(_ title:String)->TodoDrawerModel.Card {cards().first{$0.title==title}!}
    func closeAnswer(_ request:[String:Any],ok:Bool=true,reason:String="unknown_deadline") {
        controller.receive(ok ? ["v":1,"type":"deadline_close_status","ref":request["id"] as! String,"ok":true,"already_closed":false,"repainted":true]
                              : ["v":1,"type":"deadline_close_status","ref":request["id"] as! String,"ok":false,"reason":reason])
    }
    controller.setDrawerState(open:true,chatExpanded:true);await pause(0.01)
    answer(sent("deadlines")[0],rows)
    // AT-DC-21: the kind line carries the source kind when the gate named one.
    try check(card("미리알림 마감").status=="마감 1일 지남 · 미리알림 · 연결된 대화 없음" && card("메일 마감").status=="오늘 마감 · 메일" && card("링크 마감").status=="마감 4일 남음","AT-DC-21 kind line with source kind")
    // AT-DC-21b: every source kind the gate can name, and one it cannot.
    let kinds=[("notion","노션"),("calendar","캘린더"),("reminder","미리알림"),("slack","Slack"),("notes","메모"),("gmail","메일"),("other",nil)]
    let kindModel=TodoDrawerModel()
    kindModel.receive(["available":true,"failed":[],"items":kinds.map{row($0.0+":k","종류 "+$0.0,due:"2026-11-22",origin:$0.0)}])
    let kindCards=kindModel.snapshot(model,now:now).urgent
    for (name,tail) in kinds {
        let status=kindCards.first{$0.title=="종류 "+name}!.status
        try check(status=="오늘 마감"+(tail.map{" · "+$0} ?? "")+" · 연결된 대화 없음","AT-DC-21b origin \(name) tail")
    }
    // AT-DC-22: a card is linked by a notice that is in the chat or by a link.
    try check(card("메일 마감").linked && card("링크 마감").linked && !card("없는 글 마감").linked && !card("갈 곳 없는 마감").linked && !card("미리알림 마감").linked,"AT-DC-22 linked only with notice in chat or url")
    try check(card("메일 마감").messageID==noticeMessage && card("없는 글 마감").messageID==nil,"AT-DC-22 only a notice found in the chat becomes a target")
    // The real view, pet window and drawer.
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
    view.island.reduceMotion={true}
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer{disposeDrawerFixture(pet,controller,view)}
    let visible=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:visible,visible:visible)] };pet.reducedMotion={true}
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:CGPoint(x:650,y:700));pet.showChat();pet.toggleDrawer();view.refresh();view.layoutSubtreeIfNeeded()
    try check(pet.drawerOpen,"AT-DC fixture drawer is open")
    view.todoDrawer.show(controller.drawerSnapshot,filter:.all,selected:nil)
    let views=view.todoDrawer.cardViews
    func cardView(_ title:String)->TodoDrawerCardView {views.first{$0.card.title==title}!}
    try check(views.filter{$0.unlinkedText=="연결된 대화 없음"}.map{$0.card.title}.sorted()==["갈 곳 없는 마감","미리알림 마감","없는 글 마감"].sorted(),"AT-DC-22 only unlinked cards say 연결된 대화 없음")
    try check(cardView("갈 곳 없는 마감").accessibilityLabel()?.hasSuffix("연결된 대화 없음")==true && cardView("메일 마감").accessibilityLabel()?.contains("연결된 대화 없음")==false,"AT-DC-22 accessible text matches")
    // AT-DC-26: menus. Deadline cards only, with the source item when there is a url; no buttons on the card.
    let event=NSEvent.mouseEvent(with:.rightMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    try check(cardView("메일 마감").menu(for:event)?.items.map(\.title)==["완료로 닫기","취소로 닫기"],"AT-DC-26 deadline menu")
    try check(cardView("링크 마감").menu(for:event)?.items.map(\.title)==["완료로 닫기","취소로 닫기","출처 열기"],"AT-DC-26 menu with source")
    try check(cardView("메일 마감").subviews.allSatisfy{!($0 is NSButton)},"AT-DC-26 no buttons on the card")
    var urls:[URL]=[];view.onOpenURL={urls.append($0)}
    (cardView("링크 마감").menu(for:event)!.items[2] as! RoomActionItem).trigger()
    try check(urls==[URL(string:"https://example.invalid/x")!],"AT-DC-26 open source goes to the link path once")
    let questionCard=cards().first{$0.kind == .question}!
    view.todoDrawer.show(controller.drawerSnapshot,filter:.all,selected:nil)
    try check(view.todoDrawer.cardViews.first{$0.card.id==questionCard.id}!.menu(for:event)==nil,"AT-DC-26 answer-request card has no menu")
    // AT-DC-23: a notice in the chat is the destination.
    urls=[]
    view.selectDrawerCard(card("메일 마감"))
    try check(model.selected==model.messages[noticeMessage]!.key && view.highlightedMessageID==noticeMessage && pet.drawerOpen && view.drawerSelectedID==card("메일 마감").id,"AT-DC-23 goes to the notice")
    now.addTimeInterval(1.49);view.tickIsland();try check(view.highlightedMessageID==noticeMessage,"AT-DC-23 highlight stays before 1.5 seconds")
    now.addTimeInterval(0.02);view.tickIsland();try check(view.highlightedMessageID==noticeMessage,"AT-DC-23 drawer selection persists")
    // AT-DC-24: link only when there is no notice in the chat.
    view.selectDrawerCard(card("링크 마감"))
    try check(urls==[URL(string:"https://example.invalid/x")!],"AT-DC-24 link opens when there is no notice")
    urls=[]
    var both=card("메일 마감");both.url=URL(string:"https://example.invalid/y")
    view.selectDrawerCard(both);try check(urls.isEmpty && model.selected==model.messages[noticeMessage]!.key,"AT-DC-24 notice wins over link")
    // AT-DC-25: nowhere to go leaves the room as it was.
    model.select(employee:"beta");let betaRoom=model.selected
    view.selectDrawerCard(card("갈 곳 없는 마감"));view.selectDrawerCard(card("없는 글 마감"))
    try check(model.selected==betaRoom && urls.isEmpty && view.drawerSelectedID==card("없는 글 마감").id,"AT-DC-25 no room change, no link, card selected")
    _=question

    // ----- close flow on the controller (drawer folded or open as each case needs) -----
    func fresh() async {
        requests=[];controller.stop();controller.setDrawerState(open:false,chatExpanded:true);controller.setDrawerState(open:true,chatExpanded:true)
        await pause(0.01)
        let list=sent("deadlines").last!;answer(list,rows)
    }
    var anchor=now
    func run(_ title:String,_ outcome:String="done") {anchor=now;controller.closeDeadline(card(title),outcome:outcome)}
    func tick(_ seconds:Double) async {now.addTimeInterval(seconds);controller.pollDeadlineCloses();await pause(0.01)}
    /// Absolute time from the last close choice, so a boundary is hit exactly rather than by summing fractions.
    func at(_ seconds:Double,from:Date?=nil) async {now=(from ?? anchor).addingTimeInterval(seconds);controller.pollDeadlineCloses();await pause(0.01)}
    // AT-DC-27
    await fresh()
    let before=titles()
    run("미리알림 마감")
    try check(!titles().contains("미리알림 마감") && controller.drawerSnapshot.counts[.deadline]==before.count-1 && controller.drawerSnapshot.undoTitle=="미리알림 마감","AT-DC-27 hidden at once with undo line")
    await at(4.9);try check(sent("deadline_close").isEmpty,"AT-DC-27 nothing sent at 4.9 seconds")
    await at(5)
    let first=sent("deadline_close")
    try check(first.count==1 && first[0]["employee"] as? String=="alpha" && first[0]["deadline"] as? String=="reminder:r1" && first[0]["outcome"] as? String=="done" && controller.drawerSnapshot.undoTitle==nil,"AT-DC-27 one request at 5.0 seconds")
    controller.setDrawerState(open:false,chatExpanded:true);requests=requests.filter{$0["type"] as? String != "deadlines"}
    closeAnswer(first[0]);await pause(0.01)
    try check(sent("deadlines").count==1,"AT-DC-27 success asks for the list even with the drawer closed")
    answer(sent("deadlines")[0],rows.filter{$0["id"] as? String != "reminder:r1"})
    controller.setDrawerState(open:true,chatExpanded:true)
    try check(!titles().contains("미리알림 마감") && titles().count==before.count-1,"AT-DC-27 stays gone after the new list")
    // AT-DC-27b / 27d: an answer asked before the close never brings the card back.
    for (name,mode) in [("가","failure"),("나","failed"),("다","empty"),("라","present")] {
        await fresh()
        controller.requestDeadlines();await pause(0.01)
        let early=sent("deadlines").last!                       // asked before the close, answered late
        let target=name=="가" ? "메일 마감":name=="나" ? "링크 마감":name=="다" ? "없는 글 마감":"갈 곳 없는 마감"
        let id=card(target).deadlineRef!.id
        run(target);await tick(5)
        closeAnswer(sent("deadline_close").last!);await pause(0.01)
        let confirm=sent("deadlines").last!
        answer(early,rows)                                      // R0 arrives late and still lists the card
        try check(!titles().contains(target),"AT-DC-27b(\(name)) late early answer keeps card hidden")
        switch mode {
        case "failure": answer(confirm,[],reason:"command_failed");try check(!titles().contains(target),"AT-DC-27b(가) failed read keeps card hidden")
        case "failed": answer(confirm,rows,failed:["alpha"]);try check(!titles().contains(target),"AT-DC-27b(나) failed employee keeps card hidden")
        case "empty": answer(confirm,rows.filter{$0["id"] as? String != id});try check(!titles().contains(target),"AT-DC-27b(다) confirmed gone")
        default: answer(confirm,rows);try check(titles().contains(target),"AT-DC-27b(라) still listed: card returns")
        }
    }
    await fresh()
    controller.requestDeadlines();await pause(0.01)
    let older=sent("deadlines").last!
    run("메일 마감");await tick(5);closeAnswer(sent("deadline_close").last!);await pause(0.01)
    let newer=sent("deadlines").last!
    answer(newer,rows.filter{$0["id"] as? String != "gmail:g1"},failed:[])
    let settled=controller.drawerSnapshot
    answer(older,rows,failed:["alpha"])                         // older number, arrives after the newer one
    try check(controller.drawerSnapshot==settled && !titles().contains("메일 마감") && controller.drawerSnapshot.warning==nil,"AT-DC-27d older answer is dropped entirely")
    // AT-DC-27c: two closes tracked per card.
    await fresh()
    run("미리알림 마감");run("메일 마감");await pause(0.01)
    try check(sent("deadline_close").count==1 && sent("deadline_close")[0]["deadline"] as? String=="reminder:r1","AT-DC-27c choosing B sends A at once")
    closeAnswer(sent("deadline_close")[0]);await pause(0.01)
    await tick(5)
    try check(sent("deadline_close").count==2,"AT-DC-27c B is sent after its five seconds")
    let r1=sent("deadlines").last!
    answer(r1,rows.filter{$0["id"] as? String != "reminder:r1"})   // valid list: A gone, B still listed
    try check(!titles().contains("미리알림 마감") && !titles().contains("메일 마감"),"AT-DC-27c B stays hidden while its request is out")
    closeAnswer(sent("deadline_close")[1]);await pause(0.01)
    answer(sent("deadlines").last!,rows.filter{!["reminder:r1","gmail:g1"].contains($0["id"] as! String)})
    try check(!titles().contains("메일 마감") && sent("deadline_close").count==2,"AT-DC-27c both gone, one request each")
    // AT-DC-28: undo sends nothing.
    await fresh()
    let order=titles();run("링크 마감");await tick(2);controller.undoClose();await tick(10)
    try check(sent("deadline_close").isEmpty && titles()==order && controller.drawerSnapshot.undoTitle==nil,"AT-DC-28 undo restores order and sends nothing")
    // AT-DC-29: a second close sends the first at once.
    await fresh()
    run("링크 마감");await tick(1);run("메일 마감","cancel");await pause(0.01)
    try check(sent("deadline_close").count==1 && sent("deadline_close")[0]["outcome"] as? String=="done" && controller.drawerSnapshot.undoTitle=="메일 마감","AT-DC-29 first goes at once, undo line is the second")
    await tick(5)
    try check(sent("deadline_close").count==2 && sent("deadline_close")[1]["outcome"] as? String=="cancel","AT-DC-29 second after its own five seconds")
    // AT-DC-30: folding the drawer does not stop the wait.
    await fresh()
    run("링크 마감");controller.setDrawerState(open:false,chatExpanded:false);await tick(5)
    try check(sent("deadline_close").count==1,"AT-DC-30 request goes out although the drawer is closed")
    // AT-DC-31: failures show the card again with a gray line, cleared when the drawer reopens.
    await fresh()
    run("링크 마감");await tick(5);closeAnswer(sent("deadline_close")[0],ok:false)
    try check(titles().contains("링크 마감") && controller.drawerSnapshot.closeWarning=="마감을 닫지 못했어요. 다시 해 주세요.","AT-DC-31(가) refusal restores the card and shows the line")
    controller.setDrawerState(open:false,chatExpanded:true);controller.setDrawerState(open:true,chatExpanded:true)
    try check(controller.drawerSnapshot.closeWarning==nil,"AT-DC-31 reopening clears the line")
    await fresh()
    controller.deadlineSender={frame in if frame["type"] as? String=="deadline_close" {throw URLError(.cannotConnectToHost)};requests.append(frame)}
    run("링크 마감");await tick(5)
    try check(titles().contains("링크 마감") && controller.drawerSnapshot.closeWarning != nil,"AT-DC-31(나) send failure restores the card")
    controller.deadlineSender={requests.append($0)}
    await fresh()
    run("링크 마감");await tick(5);let sentAt=now
    await at(74.9,from:sentAt)
    try check(!titles().contains("링크 마감"),"AT-DC-31(다) still hidden at 74.9 seconds")
    await at(75,from:sentAt)
    try check(titles().contains("링크 마감") && controller.drawerSnapshot.closeWarning != nil,"AT-DC-31(다) restored at 75 seconds")
    // AT-DC-32: a new connection while waiting counts as failure, then the list is asked again.
    await fresh()
    run("링크 마감");await tick(5);requests=[]
    controller.receive(["type":"welcome","employees":[]]);await pause(0.01)
    try check(titles().contains("링크 마감") && controller.drawerSnapshot.closeWarning != nil && sent("deadlines").count==1,"AT-DC-32 reconnect fails the waiting close and asks again")
    // AT-DC-34: shutdown drops the wait without sending.
    await fresh()
    run("링크 마감");await tick(2);controller.stop();await tick(10);controller.pollDeadlines();await pause(0.01)
    try check(sent("deadline_close").isEmpty && controller.pendingClose==nil,"AT-DC-34 nothing sent after stop")
    print("AT-DC-21..34 CARD TARGET, MENU, CLOSE FLOW PASS")
}
