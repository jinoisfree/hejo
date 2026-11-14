import AppKit

private let islandA=ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111")
private let islandB=ConversationKey(employee:"beta",thread:"22222222-2222-4222-8222-222222222222")
private func islandMessage(_ seq:Int,_ key:ConversationKey = islandA,asked:Bool=false)->ConversationMessage {
    ConversationMessage(id:String(format:"00000000-0000-4000-8000-%012d",seq),key:key,role:"employee",text:"Question \(seq)\nsecond line",files:[],buttons:[],replyState:asked ? "asked" : nil,seq:seq,latestSeq:seq,timestamp:"2026-01-01T00:00:00Z")
}
@MainActor func islandTests(resourceDirectory:URL) async throws {
    var time=Date(timeIntervalSince1970:1000)
    func state(_ input:IslandModel.Input)->IslandModel.Snapshot { let model=IslandModel(clock:{time});model.update(input);return model.snapshot() }
    var input=IslandModel.Input(messages:[islandMessage(1,asked:true),islandMessage(2,islandB,asked:true)],names:["alpha":"Alpha","beta":"Beta"],unread:5,selected:islandA)
    let model=IslandModel(clock:{time});model.update(input)
    try check(model.snapshot().parts.map(\.kind) == [.owner] && model.snapshot().parts[0].text == "2 · 5" && model.snapshot().parts[0].redDot,"AT53 A2 U5 red dot and counts")
    var unasked=input;unasked.messages=[];unasked.unread=3
    try check(state(unasked).parts[0].text == "3" && !state(unasked).parts[0].redDot,"AT53 unread only no red dot")
    unasked.unread=0;try check(state(unasked).idle,"AT53 empty state")
    input.typing=[islandB:time.addingTimeInterval(300)];model.update(input);time.addTimeInterval(120)
    let working=model.snapshot()
    try check(working.parts.map(\.kind) == [.owner,.worker] && working.parts[1].text == "일하는 중 · 2분","AT53 separate owner/worker and elapsed two minutes")
    input.typing[islandA]=time.addingTimeInterval(300)
    input.typing[ConversationKey(employee:"gamma",thread:"three")]=time.addingTimeInterval(300)
    input.typing[ConversationKey(employee:"delta",thread:"four")]=time.addingTimeInterval(300)
    let crowd=state(input)
    try check(crowd.parts[1].faces.count == 3 && crowd.parts[1].text == "4명 일하는 중","AT53 at most three initials for four workers")
    let pill=IslandView(frame:CGRect(x:0,y:0,width:500,height:30));pill.reduceMotion={true};pill.show(crowd)
    pill.frame.size.width=pill.fittedWidth(limit:150);pill.layoutSubtreeIfNeeded()
    try check(pill.workerFacesOnly && pill.frame.width<=150 && pill.partRects.count == 2 && pill.frame.height == 30,"AT53 width overflow collapses worker before clipping pill")
    var shimmerClock:TimeInterval=0
    pill.reduceMotion={true};pill.animationTime={shimmerClock};pill.show(working)
    pill.frame.size.width=pill.fittedWidth(limit:300);pill.layoutSubtreeIfNeeded()
    pill.reduceMotion={false};pill.layoutSubtreeIfNeeded()
    pill.updateShimmerPosition();let startLight=pill.shimmerPosition
    shimmerClock=0.8;pill.updateShimmerPosition()
    try check(pill.isShimmering && pill.shimmerPosition>startLight,"AT53 worker text light band moves left to right in 0.8 seconds")
    shimmerClock=1.6;pill.updateShimmerPosition()
    try check(abs(pill.shimmerPosition-startLight)<0.01,"AT53 worker text light band repeats every 1.6 seconds")
    pill.reduceMotion={true};pill.updateShimmerPosition()
    try check(!pill.isShimmering,"AT56 reduced motion stops worker text shimmer")
    for snapshot in [state(unasked),working,crowd,state(IslandModel.Input(status:.disconnected(3)))] {
        pill.show(snapshot);pill.frame.size.width=pill.fittedWidth(limit:300);pill.layoutSubtreeIfNeeded()
        try check(pill.frame.height == 30,"AT53 state changes never alter height")
    }
    pill.show(state(unasked));pill.frame.size.width=pill.fittedWidth(limit:300)
    try check(pill.idleStripe.size == CGSize(width:44,height:12),"AT53 idle 44 by 12 stripe")
    pill.show(crowd);pill.frame.size.width=pill.fittedWidth(limit:400);pill.layoutSubtreeIfNeeded()
    var faceAction:IslandModel.Action?;pill.onAction={faceAction=$0}
    let faceRect=pill.partRects.first(where:{$0.0.kind == .worker})!.1
    pill.activate(at:CGPoint(x:faceRect.minX+7+18+8,y:15))
    try check(faceAction == .worker(islandB),"AT56 each displayed worker face selects that employee")
    print("AT-HF-53 MODEL PASS")

    time=Date(timeIntervalSince1970:2000)
    let queued=IslandModel(clock:{time});var events=IslandModel.Input(typing:[islandB:time.addingTimeInterval(100)],names:input.names,selected:islandA)
    queued.update(events);events.messages=[islandMessage(1,asked:true),islandMessage(2,islandB)];queued.update(events)
    try check(queued.snapshot().expanded == .owner && queued.snapshot().parts.first?.text.contains("답 요청") == true && queued.snapshot().parts.last?.iconOnly == true,"AT54 owner preview wins and other segment becomes icon")
    time.addTimeInterval(3.9);try check(queued.snapshot().expanded == .owner,"AT54 asked preview remains at 3.9s")
    time.addTimeInterval(0.2);try check(queued.snapshot().expanded == .worker && queued.snapshot().parts.last?.text == "답글 · 보기 ›","AT54 worker event queued after four seconds")
    time.addTimeInterval(3.1);try check(queued.snapshot().expanded == nil,"AT54 worker preview expires after three seconds")
    let single=IslandModel(clock:{time});single.update(IslandModel.Input());single.update(IslandModel.Input(messages:[islandMessage(3,asked:true)]))
    time.addTimeInterval(4.1);try check(single.snapshot().expanded == nil,"AT54 single asked preview folds after 4.1s")
    let preempt=IslandModel(clock:{time});var low=IslandModel.Input(typing:[islandB:time.addingTimeInterval(100)],selected:islandA)
    preempt.update(low);low.messages=[islandMessage(1,islandB)];preempt.update(low)
    try check(preempt.snapshot().expanded == .worker,"AT54 worker preview begins")
    time.addTimeInterval(1);low.messages.append(islandMessage(2,asked:true));preempt.update(low)
    try check(preempt.snapshot().expanded == .owner,"AT54 higher priority owner preempts worker")
    low.failure=IslandFailure(message:"fixture failure",retryKey:islandA,isSend:true);preempt.update(low)
    time.addTimeInterval(10);try check(preempt.snapshot().expanded == nil && preempt.snapshot().parts.first?.kind == .problem,"AT54 problem pauses preview queue")
    low.failure=nil;preempt.update(low);try check(preempt.snapshot().expanded == .owner,"AT54 paused owner resumes")
    time.addTimeInterval(4.1);try check(preempt.snapshot().expanded == .worker,"AT54 interrupted worker resumes afterwards")
    let oldestFirst=IslandModel(clock:{time});oldestFirst.update(IslandModel.Input(messages:[islandMessage(1,asked:true)]))
    oldestFirst.update(IslandModel.Input(messages:[islandMessage(1,asked:true),islandMessage(2,islandB,asked:true)]))
    try check(oldestFirst.snapshot().parts.first?.action == .question(islandMessage(1).id,islandA),"AT56 expanded owner preview still opens oldest asked")
    print("AT-HF-54 PASS")

    let connection=IslandModel(clock:{time});connection.update(input)
    let oversized=IslandModel(clock:{time});oversized.update(IslandModel.Input(status:.tooLarge))
    try check(oversized.snapshot().parts.first?.kind == .problem && oversized.snapshot().parts.first?.text.contains("너무 큼") == true,"AT55 1009 and too_large status stays visible in problem segment")
    var problem=input;problem.status = .disconnected(3);connection.update(problem)
    let lost=connection.snapshot()
    try check(lost.disconnected && lost.parts.count == 1 && lost.parts[0].text.contains("3초 뒤 다시 연결") && lost.parts[0].action == .reconnect,"AT55 disconnected replaces all count segments")
    time.addTimeInterval(1);try check(connection.snapshot().parts[0].text.contains("2초 뒤"),"AT55 retry countdown uses injected clock")
    problem.status = .connected;connection.update(problem)
    try check(connection.snapshot().restored && connection.snapshot().parts[0].text == "다시 연결됨","AT55 restored for two seconds")
    time.addTimeInterval(2.1);try check(!connection.snapshot().restored,"AT55 restored banner expires")
    problem.failure=IslandFailure(message:"연결을 확인해 주세요",firstWords:"Draft",retryKey:islandA,isSend:true);connection.update(problem)
    try check(connection.snapshot().parts[0].text.contains("보내지 못함 · Draft") && connection.snapshot().parts[0].action == .retry(islandA),"AT55 failure retains first words and retry key")
    problem.failure=nil;problem.uploads=[islandA:IslandUpload(completed:2,total:3)];connection.update(problem)
    try check(connection.snapshot().parts[0].text == "파일 올리는 중 2/3","AT55 upload completed/total")
    print("AT-HF-55 MODEL PASS")

    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:directory) }
    let client=GateClient(store:try LocalStore(directory:directory),credentials:MemoryCredentials())
    let controller=try ConversationController(client:client)
    let roster:[[String:Any]]=["alpha","beta","gamma"].map { ["id":$0,"name":$0.capitalized,"aliases":[],"avatar":NSNull()] }
    try await client.receive(["v":1,"type":"welcome","employees":roster])
    for seq in 1...65 {
        let key=seq==1 ? islandA : seq==2 ? islandB : ConversationKey(employee:"gamma",thread:String(format:"00000000-0000-4000-8000-%012d",seq))
        let m=islandMessage(seq,key,asked:seq<=3)
        controller.receive(["v":1,"type":"message","seq":seq,"msg_id":m.id,"employee":key.employee,"thread":key.thread,"role":"employee","text":m.text,"files":[],"buttons":[],"reply_state":seq<=3 ? "asked" : "closed","ts":m.timestamp])
    }
    controller.model.select(employee:"gamma")
    let uiModel=IslandModel(clock:{time})
    let ui=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"),islandModel:uiModel)
    ui.island.reduceMotion={true}
    let pet=PetController(store:client.store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory));pet.reducedMotion={true}
    pet.preferredChatSize=CGSize(width:760,height:500);pet.pet.installConversation(ui);pet.showChat();pet.pet.layoutSubtreeIfNeeded();ui.layoutSubtreeIfNeeded()
    try check(ui.island.frame.minX == ui.sidebarWidth+12 && ui.island.frame.height == 30 && ui.heading.frame.minX == ui.island.frame.maxX+12,"AT53 island placed beside logo and title follows it")
    let owner=ui.island.partRects.first { $0.0.kind == .owner }!.1
    ui.island.hover(at:CGPoint(x:owner.midX,y:owner.midY));ui.layoutSubtreeIfNeeded()
    try check(ui.island.accessibilityLabel()?.contains("Question 3 · 열기 ›") == true && !ui.island.subviews.contains(where:{$0 is NSButton}),"AT56 hover shows latest question and Open, without reply buttons")
    ui.island.hover(at:nil)
    ui.island.activate(at:CGPoint(x:owner.midX,y:owner.midY));ui.layoutSubtreeIfNeeded()
    try check(controller.model.selected == islandA && ui.history.contents.first(where:{$0.id == islandA.thread})?.expanded == true && ui.highlightedMessageID == islandMessage(1).id,"AT56 oldest asked selects its room and opens/highlights card")
    try check(ui.history.contents.first(where:{$0.id == islandA.thread})?.style.lineWidth == 2.5,"AT56 visible card highlight")
    time.addTimeInterval(1.6);ui.tickIsland();try check(ui.highlightedMessageID == nil,"AT56 highlight expires at 1.5 seconds")
    try controller.model.apply(["v":1,"type":"typing","employee":"beta","thread":islandB.thread,"on":true,"ttl_seconds":6],now:time)
    ui.refresh();ui.layoutSubtreeIfNeeded()
    let worker=ui.island.partRects.first { $0.0.kind == .worker }!.1
    ui.island.activate(at:CGPoint(x:worker.midX,y:worker.midY))
    try check(controller.model.selected == islandB,"AT56 worker segment opens worker thread")
    var reconnects=0,retries:[ConversationKey]=[];ui.reconnect={reconnects+=1};ui.retrySend={retries.append($0)}
    ui.island.show(lost);ui.layoutSubtreeIfNeeded();ui.island.activate(at:CGPoint(x:10,y:15));try check(reconnects==1,"AT56 reconnect action exactly once")
    controller.setText("Draft kept",for:islandB);await controller.sendCurrent(for:islandB)
    ui.refresh();ui.layoutSubtreeIfNeeded()
    let fail=ui.island.partRects.first { $0.0.kind == .problem }!.1
    ui.island.activate(at:CGPoint(x:fail.midX,y:fail.midY))
    try check(retries == [islandB] && controller.drafts[islandB]?.text == "Draft kept" && controller.notice.isEmpty,"AT56 retry keeps original destination and draft; failure notice moved")
    ui.frame.size.width=428;ui.needsLayout=true;ui.layoutSubtreeIfNeeded()
    try check(ui.island.frame.width <= 146 && ui.heading.frame.width>=120 && ui.island.frame.height==30,"AT53 narrow header reserves title and right icons")
    ui.frame.size.width=760;ui.needsLayout=true;ui.layoutSubtreeIfNeeded()
    var drags=0;ui.headerDrag.onBegan={_ in drags+=1};ui.headerDrag.onChanged={_ in drags+=1}
    let point=CGPoint(x:ui.island.frame.midX,y:ui.island.frame.midY), windowPoint=ui.convert(point,to:nil), initial=pet.panel.frame
    try check(ui.hitTest(ui.convert(point,to:ui.superview)) === ui.island && ui.headerDrag.hitTest(point) == nil,"AT56 island excluded from header hit testing")
    let down=NSEvent.mouseEvent(with:.leftMouseDown,location:windowPoint,modifierFlags:[],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!
    let drag=NSEvent.mouseEvent(with:.leftMouseDragged,location:CGPoint(x:windowPoint.x+20,y:windowPoint.y),modifierFlags:[],timestamp:0.1,windowNumber:pet.panel.windowNumber,context:nil,eventNumber:2,clickCount:1,pressure:1)!
    ui.island.mouseDown(with:down);ui.island.mouseDragged(with:drag);try check(drags==0 && pet.panel.frame==initial,"AT56 dragging island never moves window")
    ui.island.show(working);ui.layoutSubtreeIfNeeded()
    try check(ui.island.animationSteps == 0 && !ui.island.isShimmering,"AT56 reduced motion has no width animation steps or shimmer")
    try check(ui.history.frame.minY == 44 && ui.notice.stringValue.isEmpty,"AT55 no connection strip occupies space below header")
    func capture(_ name:String) throws {
        ui.layoutSubtreeIfNeeded();pet.pet.layoutSubtreeIfNeeded()
        let image=pet.pet.bitmapImageRepForCachingDisplay(in:pet.pet.bounds)!
        pet.pet.cacheDisplay(in:pet.pet.bounds,to:image)
        try image.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/"+name))
    }
    ui.island.show(working);try capture("task11-working-automatic.png")
    ui.island.show(lost);try capture("task11-disconnected-automatic.png")
    pet.panel.orderOut(nil)
    print("AT-HF-53 UI PASS");print("AT-HF-56 AUTOMATIC PASS");print("ISLAND_AUTOMATIC_CAPTURES_OK")
}
