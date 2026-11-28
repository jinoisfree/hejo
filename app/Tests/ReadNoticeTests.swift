import AppKit

@MainActor func readNoticeTests(outputDirectory:URL?=nil) async throws {
    try threadDoneTests()
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    if outputDirectory != nil {
        let address=try homeRequire(ProcessInfo.processInfo.environment["HEJO_CAPTURE_ADDRESS"],"N36 capture requires live fake socket")
        try controller.client.pair(address:address,code:"test_code-12",device:"fake capture")
        try await waitFor{controller.canSend}
    }
    defer{controller.client.stop()}
    let now=Date(timeIntervalSince1970:1794000000);controller.clock={now}
    let roster:[[String:Any]]=[["id":"alpha","name":"직원 A","aliases":["First Staff"],"color":"#007AFF"],["id":"beta","name":"직원 B","aliases":[]]]
    controller.receive(["type":"welcome","employees":roster,"head_seq":0])
    try check(model.isHome,"AT87 first room is home")
    var seq=0
    @discardableResult func post(_ text:String,room:String="alpha",thread:String=UUID().uuidString.lowercased(),role:String="employee",state:String?=nil,age:Double=0,labels:[String]=[]) throws ->ConversationMessage {
        seq+=1;let id=UUID().uuidString.lowercased()
        let row:[String:Any] = ["v":1,"type":"message","seq":seq,"msg_id":id,"employee":room,"thread":thread,"role":role,"text":text,"files":[],"buttons":labels.map{["id":UUID().uuidString.lowercased(),"label":$0,"kind":"reply","style":"default"]},"reply_state":state as Any? ?? NSNull(),"ts":ISO8601DateFormatter().string(from:now.addingTimeInterval(-age))]
        try store.append(row);controller.receive(row);return model.messages[id]!
    }
    func edit(_ post:ConversationMessage,text:String,state:String?=nil) throws {
        seq+=1;let row:[String:Any]=state.map{["v":1,"type":"state","seq":seq,"msg_id":post.id,"reply_state":$0]} ?? ["v":1,"type":"edit","seq":seq,"msg_id":post.id,"text":text,"final":true]
        try store.append(row);controller.receive(row)
    }
    let historical=try post("이전 알림",age:1000)
    controller.receive(["type":"sync_done","through":seq,"more":false])
    try check(model.unread(employee:"alpha")==0 && model.memberState.read("read:alpha")==1,"AT87 initial full history starts read")
    let owner=try post("새 요청",role:"owner",age:600)
    let ordinary=try post("평범한 새 답",thread:owner.key.thread,age:500)
    let alert=try post("새 알림",age:400)
    let question=try post("승인해줘",age:300)
    let thought=try post("생각 중…",age:200)
    try check(model.unread(thought.key)==0 && model.bell(thought.key)==nil,"AT87 thinking excluded")
    try check(model.bell(ordinary.key)==nil && model.bell(alert.key)==true && model.bell(question.key)==true,"AT87 yellow bell only notices and questions")
    model.select(.init(employee:"alpha",thread:UUID().uuidString.lowercased()));model.setVisible(true)
    try check(model.unread(ordinary.key)==0 && model.unread(alert.key)==1 && model.unread(question.key)==1,"AT87 entering room leaves ringing threads unread")
    model.select(question.key);try check(model.unread(question.key)==0,"AT87 clicking ringing thread reads it")
    model.markNoticeRead(question.key);model.setVisible(false)
    try edit(question,text:"승인해줘. 고친 글")
    try edit(question,text:"",state:"asked")
    try check(model.unread(question.key)==0 && model.bell(question.key)==false,"AT87 edits and state do not renew read or bell")
    try edit(question,text:"",state:"answered")
    try check(model.bell(question.key)==nil && model.assessment(question.key).color=="#ECB22E","AT87 processing yellow without quiet bell")
    try edit(question,text:"",state:"closed")
    try check(model.bell(question.key)==nil && model.assessment(question.key).color=="#2EB67D","AT87 closed green without quiet bell")
    for text in ["승인해줘","`승인`이라고 답해줘","승인 한 마디만 보내줘"] {try check(ThreadAssessment.requestsApproval(text),"AT87 original approval expressions")}
    for text in ["> 승인해줘\n검토 보고", "승인을 기다리는 작업은 없어", "승인해줘서 고마워", "승인 후 처리했어요"] {try check(!ThreadAssessment.requestsApproval(text),"AT87 approval report and quoted requests excluded")}
    let older=try post("먼저 승인해줘",room:"beta",age:190),later=try post("나중 승인해줘",age:180)
    model.selectHome()
    try check(model.notices(HomeRoom.id).filter(\.questions).map(\.id)==["question:beta","question:alpha"],"AT87 question groups oldest before employee id")
    let yes=try post("네!",thread:later.key.thread,role:"owner",age:170)
    try check(model.assessment(later.key).color=="#2EB67D" && model.assessment(later.key).buttons.isEmpty,"AT87 typed yes hides controls and turns approved green")
    try post("이어서 처리했어요",thread:yes.key.thread,age:160)
    try check(model.assessment(later.key).settled && model.bell(later.key)==nil,"AT87 typed approval then staff reply settles")
    let controls=try post("요청",state:"asked",age:150,labels:["승인","거절"])
    try check(model.assessment(controls.key).buttons==[controls.id],"AT87 unanswered buttons visible")
    try post("답했어요",thread:controls.key.thread,role:"owner",age:140)
    try check(model.assessment(controls.key).buttons.isEmpty,"AT87 answered buttons disappear")
    // The same visible answer words can address one request or the whole earlier conversation.
    let itemA=try post("항목 A",state:"asked",age:139,labels:["승인","거절"])
    let itemB=try post("항목 B",thread:itemA.key.thread,state:"asked",age:138,labels:["승인","거절"])
    try edit(itemA,text:"",state:"answered")
    seq+=1
    let targeted:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":UUID().uuidString.lowercased(),"employee":"alpha","thread":itemA.key.thread,"role":"owner","text":"승인","files":[],"buttons":[],"reply_state":NSNull(),"ts":ISO8601DateFormatter().string(from:now.addingTimeInterval(-137)),"answer_to":itemA.id]
    try store.append(targeted);controller.receive(targeted)
    try check(model.assessment(itemA.key).pending?.id==itemB.id && model.assessment(itemA.key).buttons==[itemB.id],"AT87 targeted answer leaves other request pending")
    let fromCache=try ConversationModel(store:LocalStore(directory:home))
    try check(fromCache.assessment(itemA.key).pending?.id==itemB.id,"AT87 targeted answer survives replica replay")
    let oldWire=try ConversationModel(store:LocalStore(directory:home.appendingPathComponent("legacy")))
    for frame in store.records {var legacy=frame;legacy.removeValue(forKey:"answer_to");try oldWire.apply(legacy)}
    try check(oldWire.assessment(itemA.key).pending==nil,"AT87 old gate missing target treats answer as typed")
    try post("승인",thread:itemA.key.thread,role:"owner",age:136)
    try check(model.assessment(itemA.key).pending==nil && model.assessment(itemA.key).buttons.isEmpty,"AT87 typed same words answer remaining earlier requests")
    let unknown=try post("낯선 선택",state:"asked",age:130,labels:["알 수 없는 동작"])
    let work=try post("진행 중",state:"answered",age:120)
    let ownerCheck=try post("<span style=\"color:#A000D0\">☐ 내 확인</span> ☐ 두 번째",role:"owner",age:110)
    model.toggleCheck(ownerCheck.id,line:0,original:false)
    try check(model.check(ownerCheck.id,line:0,original:false) && !model.check(ownerCheck.id,line:7,original:false),"AT87 check offsets are independent")
    try edit(ownerCheck,text:"☐ 바뀐 본문")
    try check(!model.check(ownerCheck.id,line:0,original:false),"AT87 body revision resets check state")
    model.toggleCheck(ownerCheck.id,line:0,original:false,body:ownerCheck.text)
    try check(!model.check(ownerCheck.id,line:0,original:false),"AT87 old rendered checkbox action cannot change revised body checks")
    try check(model.person(matching:"FIRST_staff")?.id=="alpha" && model.name("first-staff")=="직원 A","AT87 alias normalization")
    let view=ConversationView(controller:controller,islandModel:IslandModel(clock:{now}));view.frame=CGRect(x:0,y:0,width:840,height:760)
    view.chooseEmployee("alpha");view.refresh();view.layoutSubtreeIfNeeded()
    func card(_ id:String) throws ->NativeThreadCard.Content {try homeRequire(view.history.contents.first{$0.id==id},"AT87 card")}
    func accessories(_ content:NativeThreadCard.Content)->[NSView] {(content.top+(content.replies ?? [])).compactMap{if case .accessory(_,_,let make)=$0{return make()};return nil}}
    let defaultCard=try card(later.key.thread)
    try check(accessories(defaultCard).allSatisfy{homeDescendants($0,FileChip.self).isEmpty},"AT87 typed answered request has no reply chips")
    let unknownViews=accessories(try card(unknown.key.thread)),unknownChips=unknownViews.flatMap{homeDescendants($0,FileChip.self)}
    // AT-HB-30/31. The authenticated gate supplies the choices; this fixture is offline.
    try check(unknownChips.count==1 && unknownChips[0].isEnabled==controller.canSend && unknownChips[0].accessibilityLabel()=="알 수 없는 동작","AT-HB-31 gate-issued label")
    try check(try card(work.key.thread).style.status==MessageFormat.color("#ECB22E"),"AT87 actual card working rail yellow")
    let generated=view.history.contents.flatMap{$0.top+($0.replies ?? [])}.compactMap{piece ->NativeThreadCard.Post? in if case .post(let p)=piece{return p};return nil}.flatMap(\.marks)
    try check(generated.isEmpty,"AT87 no generated settled text line")
    let fresh=try post("승인해줘",age:100)
    view.refresh();let defaultViews=accessories(try card(fresh.key.thread)),chips=defaultViews.flatMap{homeDescendants($0,FileChip.self)}
    // AT-HB-31. An old gate with no issued IDs has no clickable defaults.
    try check(chips.isEmpty && !model.confirmed(fresh.id) && model.timeline(fresh.key).count==1,"AT-HB-31 no fabricated buttons or local confirmation")
    let colored=try post("<span style=\"color:#A000D0\">☐ 내 확인</span>",role:"owner",age:90)
    view.refresh()
    let mine=try card(colored.key.thread).top.compactMap{piece ->NativeThreadCard.Post? in if case .post(let p)=piece{return p};return nil}.first!
    try check(mine.text.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor==MessageFormat.color("#A000D0"),"AT87 owner explicit color preserved")
    let checkURL=try homeRequire(mine.text.attribute(.link,at:0,effectiveRange:nil) as? URL,"AT87 owner checkbox link")
    mine.openLink(checkURL);try check(model.check(colored.id,line:0,original:false),"AT87 owner checkbox uses existing member state")
    model.select(employee:"beta")
    let reloaded=try ConversationModel(store:LocalStore(directory:home));try reloaded.apply(["type":"roster","employees":roster])
    try check(!reloaded.isHome && reloaded.selected?.employee=="beta","AT87 last room restored")
    try check(model.messages[historical.id] != nil && model.messages[older.id] != nil,"AT87 read actions preserve journal")
    controller.receive(["type":"roster","employees":roster+[["id":"gamma","name":"직원 C","aliases":[]]]])
    let laterArrival=try post("처음 본 빈 방의 새 글",room:"gamma",age:90000)
    controller.receive(["type":"sync_done","through":seq,"more":false])
    try check(model.unread(laterArrival.key)==1,"AT87 first seeing an empty room seeds zero; later sync cannot clear new unread")
    try check(!model.memberState.items.keys.contains{$0.contains("@home")},"AT87 virtual home selection does not persist a fake receipt")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        try check(controller.canSend,"N36 capture is genuinely connected")
        // Capture the product's real card construction with the same pending/working/closed states as the reference.
        view.chooseEmployee("alpha");view.setSidebarWidth(212);view.refresh();view.layoutSubtreeIfNeeded()
        let canvas=NSView(frame:CGRect(x:0,y:0,width:620,height:560));canvas.wantsLayer=true;canvas.layer?.backgroundColor=NSColor.white.cgColor
        var y:CGFloat=8
        for key in [fresh.key,work.key,question.key] {
            if key==fresh.key {try model.memberState.set(["confirm:"+fresh.id:nil]);view.refresh()}
            let content=try card(key.thread),native=NativeThreadCard(frame:.zero)
            let layout=NativeThreadCard.layout(content,width:604)
            native.frame=CGRect(x:8,y:y,width:604,height:layout.height);native.configure(layout);canvas.addSubview(native);y+=layout.height+8
        }
        let window=NSWindow(contentRect:canvas.frame,styleMask:.borderless,backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=canvas;window.orderFrontRegardless()
        await pause(0.15);canvas.layoutSubtreeIfNeeded();canvas.displayIfNeeded()
        let bitmap=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task36-hejo.png"));window.orderOut(nil)
    }
    print("AT-HF-87 APP PASS")
}

/// Real gateway loopback: the optional target must survive a fresh replica, not only one live view.
@MainActor func readNoticeNetwork(_ args:[String]) async throws {
    let home=URL(fileURLWithPath:args[2]),credentials=MemoryCredentials()
    let client=GateClient(store:try LocalStore(directory:home),credentials:credentials),controller=try testConversation(client:client)
    try client.pair(address:args[3],code:args[4],device:"fake target compatibility")
    defer{client.stop()}
    try await waitFor{controller.canSend && controller.model.messages.count==2}
    let first=controller.model.messages.values.first{$0.text=="항목 A"}!,second=controller.model.messages.values.first{$0.text=="항목 B"}!
    let expectsTarget=args[5]=="target"
    await controller.click(first.buttons[0],messageID:first.id,key:first.key,buttons:first.buttons)
    try await waitFor{controller.model.timeline(first.key).contains{$0.role=="owner"}}
    let owner=controller.model.timeline(first.key).first{$0.role=="owner"}!
    try check(owner.answerTo==(expectsTarget ? first.id:nil),"AT87 real click target decoded or old gate absent")
    try check(controller.model.assessment(first.key).pending?.id==(expectsTarget ? second.id:nil),"AT87 real targeted answer preserves B; old gate treats as typed")
    let token=credentials.token!
    client.stop()
    let fresh=GateClient(store:try LocalStore(directory:home.appendingPathComponent("fresh")),credentials:MemoryCredentials()),reconnected=try testConversation(client:fresh)
    defer{fresh.stop()}
    try await fresh.adopt(address:args[3],device:"fake fresh replica",token:token)
    try await waitFor{reconnected.canSend && reconnected.model.messages.count==3}
    try check(reconnected.model.assessment(first.key).pending?.id==(expectsTarget ? second.id:nil),"AT87 fresh sync preserves target semantics")
    await reconnected.sendText("승인",key:first.key)
    try await waitFor{reconnected.model.messages.count==4}
    try check(reconnected.model.timeline(first.key).last?.answerTo==nil && reconnected.model.assessment(first.key).pending==nil,"AT87 same typed words answer B after fresh sync")
    print("AT87_REAL_GATE_TARGET_PASS "+(expectsTarget ? "new":"legacy"))
}
