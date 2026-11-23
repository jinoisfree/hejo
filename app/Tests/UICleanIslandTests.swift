import AppKit

@MainActor func uiCleanIslandTests(resourceDirectory:URL) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let previous=ChatAppearance.store;defer{ChatAppearance.bind(previous)}
    let store=try LocalStore(directory:home);ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    var now=ThreadTools.date("2026-11-23T12:00:00+09:00")
    controller.clock={now};controller.deadlineSender={_ in}
    let ids=["alpha","beta","gamma","delta"]
    try await controller.client.receive(["v":1,"type":"welcome","employees":ids.enumerated().map{["id":$0.element,"name":"직원 "+String(UnicodeScalar(65+$0.offset)!),"aliases":[]] as [String:Any]}])
    controller.model.select(employee:"alpha");controller.model.saveHeader("alpha",title:"시험 방",description:"설명은 머리에 표시하지 않음")
    let islandModel=IslandModel(clock:{now})
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:islandModel)
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer{disposeDrawerFixture(pet,controller,view)}
    view.reduceMotion={true};pet.reducedMotion={true};pet.pet.animationsAllowed=false
    pet.displays={let r=CGRect(x:0,y:0,width:1440,height:900);return [PetDisplay(frame:r,visible:r)]}
    pet.pet.installConversation(view);pet.installDrawer(view);pet.placePet(at:CGPoint(x:600,y:650));pet.showChat()
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded();view.island.layoutSubtreeIfNeeded()}
    func show(_ snapshot:IslandModel.Snapshot){view.island.reduceMotion={true};view.island.show(snapshot);settle();view.island.reduceMotion={false};view.island.updateShimmerPosition()}
    view.refresh();settle()
    let idle=view.island.snapshot
    show(idle)
    try check(idle.title=="시험 방" && !idle.dot && view.island.dotLayer.isHidden && view.island.dividerLayer.isHidden && view.island.accessibilityLabel()?.hasPrefix("시험 방")==true,"AT-UC-01 empty title, no dot or divider")
    let properties=Mirror(reflecting:view).children.compactMap(\.label)
    try check(!properties.contains("heading") && !properties.contains("subtitle"),"AT-UC-01 duplicate header views removed")
    var seq=0
    func post(_ employee:String,_ text:String)->String{
        seq+=1;let id=UUID().uuidString.lowercased()
        let row:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":UUID().uuidString.lowercased(),"role":"employee","text":text,"reply_state":"asked","files":[],"buttons":[],"ts":ISO8601DateFormatter().string(from:now)]
        try! store.append(row);controller.receive(row);return id
    }
    let oldest=post("alpha","첫 질문"),latest=post("beta","새 질문\n두 번째 줄")
    settle();let question=view.island.snapshot
    show(question)
    try check(question.dot && !view.island.dotLayer.isHidden && !view.island.dividerLayer.isHidden && abs(view.island.dotLayer.frame.width-8)<=0.5 && view.island.dotLayer.frame.minX>view.island.titleTextRect.maxX,"AT-UC-01 todo dot is eight points after title")
    let motion=view.island.dotLayer.animation(forKey:"breathe") as? CAKeyframeAnimation
    try check(motion?.keyPath=="opacity" && motion?.duration==2.4 && (motion?.values as? [Double])==[1,0.35,1],"AT-UC-02 dot breathes over 2.4 seconds without going out")
    var opened=question;opened.drawerOpen=true;show(opened)
    try check(view.island.dotLayer.animationKeys()?.isEmpty != false && view.island.dotLayer.opacity==1,"AT-UC-02 open drawer stops breathing")
    let reference=UICleanIslandAccent(frame:CGRect(x:0,y:0,width:8,height:8));view.addSubview(reference)
    func sample(_ target:NSView,_ point:CGPoint)->NSColor {
        let rep=target.bitmapImageRepForCachingDisplay(in:target.bounds)!;target.cacheDisplay(in:target.bounds,to:rep)
        return rep.colorAt(x:Int(point.x*CGFloat(rep.pixelsWide)/target.bounds.width),y:Int(point.y*CGFloat(rep.pixelsHigh)/target.bounds.height))!.usingColorSpace(.deviceRGB)!
    }
    let border=sample(view.island,CGPoint(x:view.island.bounds.midX,y:0.5)),accent=sample(reference,CGPoint(x:4,y:4))
    reference.removeFromSuperview()
    try check(abs(border.redComponent-accent.redComponent)+abs(border.greenComponent-accent.greenComponent)+abs(border.blueComponent-accent.blueComponent)+abs(border.alphaComponent-accent.alphaComponent)<=6/255,"AT-UC-06 open capsule border uses actual accent ink")

    show(question);view.island.reduceMotion={true};view.island.updateShimmerPosition()
    try check(view.island.dotLayer.animationKeys()?.isEmpty != false && view.island.dotLayer.opacity==1,"AT-UC-02 reduced motion stops breathing")
    let source=IslandModel(clock:{now});var input=controller.islandInput
    input.title="시험 방";input.todoTotal=controller.drawerSnapshot.total;input.messages=[controller.model.messages[latest]!]
    input.typing=[controller.model.messages[oldest]!.key:now.addingTimeInterval(600)];source.update(input)
    input.messages=[controller.model.messages[oldest]!,controller.model.messages[latest]!];source.update(input)
    input.status = .disconnected(3);source.update(input)
    let lost=source.snapshot();show(lost);let titleX=view.island.titleTextRect.minX
    try check(lost.activity?.kind == .problem && lost.activity?.tone == .orange && lost.activity?.text.hasPrefix("서버 연결 끊김")==true,"AT-UC-03 connection problem takes priority")
    input.status = .connected;source.update(input);now.addTimeInterval(2.1)
    let preview=source.snapshot();show(preview)
    try check(preview.activity?.kind == .question && preview.activity?.faces.count==1 && preview.activity?.text.hasPrefix("직원 A: 첫 질문")==true && view.island.titleTextRect.minX==titleX,"AT-UC-03 new question preview resumes after restoration")
    now.addTimeInterval(4.1);let working=source.snapshot();show(working)
    try check(working.activity?.kind == .worker && working.activity?.tone == .green && working.activity?.text=="직원 A 일하는 중 · 0분" && view.island.titleTextRect.minX==titleX,"AT-UC-03 one worker activity after question preview")
    try check(!view.island.activityIsTruncated,"AT-UC-03 normal-width worker sentence is fully visible")
    var crowd=input;crowd.typing=Dictionary(uniqueKeysWithValues:ids.map{(ConversationKey(employee:$0,thread:"fixture-work"),now.addingTimeInterval(600))})
    let many=IslandModel(clock:{now});many.update(crowd);let crowded=many.snapshot();show(crowded)
    try check(crowded.activity?.faces.count==3 && crowded.activity?.text=="4명 일하는 중","AT-UC-04 four workers use three photos")
    let originalWidth=view.frame.width
    view.island.reduceMotion={true};view.frame.size.width=view.sidebarWidth+140;view.needsLayout=true
    view.layoutSubtreeIfNeeded();view.island.layoutSubtreeIfNeeded()
    try check(view.headerDrag.frame.width==140,"AT-UC-04 narrow fixture actually has a 140pt header")
    try check(view.island.frame.maxX<=view.headerDrag.frame.maxX-12 && view.island.activityIsTruncated,"AT-UC-04 narrow activity truncates inside header right inset")
    view.frame.size.width=originalWidth;view.needsLayout=true;settle()
    let failure=IslandModel(clock:{now});failure.update(.init(failure:IslandFailure(message:"연결을 확인해 주세요",firstWords:"가짜 글",retryKey:controller.model.messages[latest]!.key,isSend:true),title:"시험 방",todoTotal:2))
    let upload=IslandModel(clock:{now});upload.update(.init(uploads:[controller.model.messages[latest]!.key:.init(completed:1,total:2)],title:"시험 방",todoTotal:2))
    var reconnects=0,retries:[ConversationKey]=[];view.reconnect={reconnects+=1};view.retrySend={retries.append($0)}
    for state in [idle,preview,working,lost,failure.snapshot(),upload.snapshot()]{
        if pet.drawerOpen{pet.setDrawerOpen(false)}
        show(state);let rect=view.island.titleRect
        view.island.activate(at:CGPoint(x:rect.midX,y:rect.midY));try check(pet.drawerOpen,"AT-UC-05 title opens drawer in every activity")
        show(state);view.island.activate(at:CGPoint(x:view.island.titleRect.midX,y:15));try check(!pet.drawerOpen,"AT-UC-05 title closes drawer in every activity")
    }
    func activate(_ state:IslandModel.Snapshot){show(state);view.island.activate(at:CGPoint(x:view.island.activityRect.midX,y:15))}
    activate(preview)
    try check(controller.model.selected==controller.model.messages[oldest]!.key && view.highlightedMessageID==oldest && view.history.contents.first{$0.id==controller.model.messages[oldest]!.key.thread}?.style.lineWidth==2,"AT-UC-05 question opens oldest asked with 2pt highlight")
    now.addTimeInterval(1.49);view.tickIsland();try check(view.highlightedMessageID==oldest,"AT-UC-05 pill question highlight before 1.5 seconds")
    now.addTimeInterval(0.02);view.tickIsland();try check(view.highlightedMessageID==nil,"AT-UC-05 pill question highlight expires after 1.5 seconds")
    controller.model.select(employee:"beta");view.refresh()
    activate(working);try check(controller.model.selected==controller.model.messages[oldest]!.key,"AT-UC-05 worker opens its thread")
    activate(lost);try check(reconnects==1,"AT-UC-05 reconnect exactly once")
    activate(failure.snapshot());try check(retries==[controller.model.messages[latest]!.key],"AT-UC-05 retry preserves destination")
    activate(upload.snapshot());try check(pet.drawerOpen,"AT-UC-05 upload with no action toggles drawer")
    let cwd=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
    let evidence=(cwd.lastPathComponent=="app" ? cwd.deletingLastPathComponent():cwd).appendingPathComponent(".build/ui-clean-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    for theme in [ChatTheme.dark,.light]{
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance();settle()
        for (name,state) in [("idle",idle),("question",preview),("working",working),("crowd",crowded),("problem",lost),("open",opened)]{
            pet.setDrawerOpen(state.drawerOpen);settle();show(state)
            try check(view.island.accessibilityLabel()?.contains("닫기")==false,"AT-UC-06 no close wording in capsule")
            let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep)
            try rep.representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent("task-02-"+name+"-"+theme.rawValue+".png"))
        }
    }
    print("AT-UC-01..06 TITLE CAPSULE PASS")
}

private final class UICleanIslandAccent:NSView {override func draw(_ dirtyRect:NSRect){NSColor.controlAccentColor.setFill();bounds.fill()}}
