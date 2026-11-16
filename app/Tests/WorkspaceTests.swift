import AppKit

private final class WorkspaceCanvas:NSView {
    override var isFlipped:Bool {true}
    override func draw(_ dirtyRect:NSRect) {NSColor.white.setFill();bounds.fill()}
}

@MainActor func workspaceTests(outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),controller=try ConversationController(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    var now=Date(timeIntervalSince1970:1760000000);controller.clock={now}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]])
    var seq=0
    @discardableResult func post(_ text:String,thread:String=UUID().uuidString.lowercased(),role:String="employee",state:String?=nil,age:Double=0,employee:String="alpha",files:[[String:Any]]=[])->String {
        seq+=1;let id=UUID().uuidString.lowercased()
        let row:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":thread,"role":role,"text":text,"files":files,"buttons":[],"reply_state":state as Any? ?? NSNull(),"ts":ISO8601DateFormatter().string(from:now.addingTimeInterval(-age))]
        try! store.append(row);controller.receive(row);return id
    }
    let q1=post("질문 첫째",state:"asked",age:100),q2=post("질문 둘째",state:"asked",age:90)
    let a1=post("알림 첫째",age:80),a2=post("알림 둘째",age:70);post("알림 셋째",age:60)
    post("하루 지난 알림",age:86401)
    let answered=post("답한 것",age:50);post("답했어요",thread:model.messages[answered]!.key.thread,role:"owner")
    let dismissed=post("종 읽음",age:40);model.markNoticeRead(model.messages[dismissed]!.key)
    let items=model.notices("alpha",now:now)
    try check(items.map(\.title)==["직원 A 질문","알림"] && items.map{$0.messages.count}==[2,3],"AT77 categories/order exclude old, answered and bell-dismissed")
    model.toggleMute("alpha")
    let tab=model.sidebar.items.first{$0.id=="alpha"}!
    try check(tab.questions==2 && tab.alerts==3,"AT77 muted room keeps own counters matching bar")
    model.toggleMute("alpha")
    let ui=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
    ui.frame=CGRect(x:0,y:0,width:900,height:720);ui.layoutSubtreeIfNeeded()
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let window=NSWindow(contentRect:ui.frame,styleMask:[.titled],backing:.buffered,defer:false);let canvas=WorkspaceCanvas(frame:ui.frame);canvas.addSubview(ui);window.contentView=canvas;window.appearance=NSAppearance(named:.aqua);window.orderFrontRegardless();ui.layoutSubtreeIfNeeded()
        let image=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:image)
        let rect=ui.noticeBar.convert(ui.noticeBar.bounds,to:canvas)
        let cropped=NSBitmapImageRep(cgImage:image.cgImage!.cropping(to:rect)!)
        try cropped.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task26-hejo-notices.png"));window.orderOut(nil)
    }
    ui.jumpNotice(items[0]);try check(ui.highlightedMessageID==q1,"AT77 question jump oldest")
    ui.jumpNotice(items[0]);try check(ui.highlightedMessageID==q2,"AT77 question jump next")
    now.addTimeInterval(1.59);ui.tickIsland();try check(ui.highlightedMessageID==q2,"AT77 flash remains before 1.6 seconds")
    now.addTimeInterval(0.02);ui.tickIsland();try check(ui.highlightedMessageID==nil,"AT77 flash expires after 1.6 seconds")
    ui.jumpNotice(items[1]);try check(ui.highlightedMessageID==a1 && model.notices("alpha").last?.messages.first==a2,"AT77 alert visit marks bell and next oldest remains")
    ui.chooseThread(model.messages[a2]!.key);try check(!model.notices("alpha").flatMap(\.messages).contains(a2),"AT77 clicking a plain notification marks its bell read")
    model.readAllNotices("alpha",now:now);try check(model.notices("alpha").allSatisfy(\.questions),"AT77 read all alerts leaves questions")
    let updated=post("질문 갱신",thread:model.messages[q1]!.key.thread,state:"asked",age:10)
    try check(model.notices("alpha").first?.messages.first==updated,"AT77 question categories keep original thread-root order after later request")
    model.confirm(model.messages[q2]!)
    try check(!model.notices("alpha").flatMap(\.messages).contains(q2) && model.notices("alpha").allSatisfy(\.questions),"AT77 confirmed question never falls back to plain notification")
    let closed=post("closed request",state:"closed");post("ordinary followup",thread:model.messages[closed]!.key.thread)
    try check(!model.notices("alpha").flatMap(\.messages).contains(closed),"AT77 settled thread stays settled after ordinary followup")
    model.saveHeader("alpha",title:"시험 제목",description:"시험 설명")
    try check(model.header("alpha").title=="시험 제목" && model.memberState.value("title:alpha") != nil,"AT79 title member key")
    ui.refresh();try check(ui.heading.stringValue=="시험 제목" && ui.subtitle.stringValue=="시험 설명","AT79 actual header display")
    model.saveHeader("alpha",title:"",description:"");try check(model.header("alpha").description=="함께 나누는 대화","AT79 restore header defaults")
    let menu=ui.headerMenu().items.map(\.title)
    try check(menu==["제목과 설명 편집…","","이 대화의 알림 끄기","방 목록 보이기 / 숨기기","방 목록 너비 전환","전체 검색 (⌘F)","모두 읽음","","펫으로 접기"],"AT79 original menu order")
    ui.cycleSidebarWidth();try check(ui.sidebarWidth==212,"AT79 sidebar wide");ui.cycleSidebarWidth();try check(ui.sidebarWidth==68,"AT79 sidebar narrow")
    for name in ["note.txt","extra.txt"]+(0..<10).map({"f\($0).txt"}) {try Data("fake attachment".utf8).write(to:home.appendingPathComponent(name))}
    ui.createThread();let place=model.selected!;controller.setText("자리 초안");controller.addAttachments([home.appendingPathComponent("note.txt")])
    controller.mention("beta")
    ui.chooseEmployee("beta");controller.setText("다른 초안");ui.chooseEmployee("alpha")
    try check(controller.draft.picks==["beta"] && controller.draft.text.hasPrefix("@직원 B "),"AT79 picked face remains with its draft slot")
    controller.mention("beta")
    try check(model.selected==place && controller.draft.text=="자리 초안" && controller.draft.attachments.count==1,"AT79 room returns to original draft slot")
    try check(WorkspaceMention.toggle("hello",name:"직원 A")=="@직원 A hello" && WorkspaceMention.toggle("@직원 A hello @직원 AB",name:"직원 A")=="hello @직원 AB","AT79 mention boundaries/add/remove")
    await controller.sendCurrent();try check(controller.failures.count==1 && controller.draft.isEmpty,"AT79 failed send waits in list, no auto resend")
    let failed=controller.failures[0];controller.setText("새로 쓴 글");controller.restoreFailure(failed.id)
    try check(controller.draft.text=="자리 초안\n새로 쓴 글" && controller.draft.attachments.count==1 && controller.failures.isEmpty,"AT79 restore prepends words/deduplicates files")
    // Real restore refusal keeps the failure intact and never drops attachments.
    controller.setText("파일 열 개");controller.addAttachments((0..<10).map{home.appendingPathComponent("f\($0).txt")});await controller.sendCurrent()
    let tooMany=controller.failures.last!
    controller.addAttachments([home.appendingPathComponent("extra.txt")]);controller.restoreFailure(tooMany.id)
    try check(controller.failures.contains{$0.id==tooMany.id} && controller.notice.contains("첨부가 10개"),"AT79 restore refuses combined file overflow")
    controller.discardFailure(tooMany.id)
    try check(controller.transferFailure==nil && controller.notice.isEmpty,"AT79 discarding last failed send clears its failure guidance")
    controller.model.select(employee:"beta");controller.setText("다른 방 실패");await controller.sendCurrent();ui.chooseEmployee("alpha");ui.refresh()
    try check(ui.failureBar.arrangedSubviews.contains{($0 as? FileChip)?.title=="다른 방에서 보내지 못한 글 1개 · 보러 가기"},"AT79 elsewhere failure link")
    let names=["alpha":"직원 A","beta":"직원 B"]
    let redraw=controller.onChange;controller.onChange=nil
    let one=UUID().uuidString.lowercased()
    for index in 0..<500 {post("search words \(index)",thread:one,age:Double(500-index))}
    let groups=WorkspaceSearch.groups("search words",messages:Array(model.messages.values),names:names,hidden:[])
    try check(groups.count==1 && groups[0].matches.count==200 && groups[0].matches[0].text=="search words 499","AT78 latest 200 matching posts before grouping")
    let fileID=UUID().uuidString.lowercased()
    let metadata=post("plain body",age:2,files:[["file_id":fileID,"name":"needle.txt","mime":"text/plain","size":1]])
    try check(WorkspaceSearch.groups("needle",messages:Array(model.messages.values),names:names,hidden:[]).first?.matches.first?.id==metadata,"AT78 searches attachment filename")
    try check(!WorkspaceSearch.groups("직원 A",messages:Array(model.messages.values),names:names,hidden:[]).isEmpty,"AT78 searches speaker")
    try check(!WorkspaceSearch.groups("asked",messages:Array(model.messages.values),names:names,hidden:[]).isEmpty,"AT78 searches state memo")
    let candidates=(1...200).map{index -> ConversationMessage in var line=model.messages[metadata]!;line.id="fake-\(index)";line.key.thread="thread-\(index)";line.text="red separated blue";line.files=[];line.timestamp=ISO8601DateFormatter().string(from:now.addingTimeInterval(-Double(index)));return line}
    var exact=candidates[0];exact.id="fake-exact";exact.key.thread="exact-thread";exact.text="red blue";exact.timestamp=ISO8601DateFormatter().string(from:now.addingTimeInterval(-300))
    var streaming=exact;streaming.streaming=true
    try check(WorkspaceSearch.groups("red blue",messages:[streaming],names:names,hidden:[]).count==1,"AT78 durable streaming text is searchable; only uncommitted pending posts stay outside projection")
    let ranked=WorkspaceSearch.groups("red blue",messages:candidates+[exact],names:names,hidden:[])
    try check(ranked.count==200 && !ranked.contains(where:\.exact),"AT78 old phrase excluded before grouping by latest-post budget")
    exact.timestamp=ISO8601DateFormatter().string(from:now)
    try check(WorkspaceSearch.groups("red blue",messages:candidates+[exact],names:names,hidden:[]).first?.exact==true,"AT78 phrase group first inside candidate budget")
    try check(WorkspaceSearch.sidebar("search words",messages:Array(model.messages.values),names:names,hidden:[]).count==30,"AT78 sidebar newest 30")
    let ranges=WorkspaceSearch.highlights("banana",query:"ana")
    try check(ranges.count==1 && String("banana"[ranges[0]])=="anana","AT78 overlapping highlights merge")
    let unicode="e\u{301}clair 안녕";try check(!WorkspaceSearch.highlights(unicode,query:"éclair").isEmpty,"AT78 original Unicode range")
    let field=WorkspaceSearch.attributed("needle",query:"needle")
    try check(field.attribute(.backgroundColor,at:0,effectiveRange:nil) as? NSColor == .yellow && field.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor == .black,"AT78 yellow black highlight")
    controller.onChange=redraw;ui.refresh()
    let restored=try ConversationModel(store:try LocalStore(directory:home));try check(restored.messages.count==model.messages.count,"AT78 local cache projection search source survives reload")
    ui.openSearch();ui.search.stringValue="search words";ui.scheduleSearch();await pause(0.1)
    try check(ui.searchGroups.isEmpty,"AT78 query waits 0.25 seconds")
    try await waitFor{ui.searchGroups.count==1};ui.moveSearch(1);ui.chooseSearch()
    try check(!ui.isSearchOpen && ui.highlightedMessageID != nil,"AT78 Return opens matching thread with flash")
    ui.openSearch();ui.search.stringValue="질문";ui.scheduleSearch();try await waitFor{ui.searchGroups.count==2};ui.moveSearch(1)
    try check(ui.searchSelection==1,"AT78 down selects second result");ui.moveSearch(-1);try check(ui.searchSelection==0,"AT78 up selects first result");_=ui.closeSearchIfOpen()
    ui.openSearch();ui.search.stringValue="needle";ui.scheduleSearch();try await waitFor{ui.searchGroups.first?.matches.first?.id==metadata}
    ui.layoutSubtreeIfNeeded();ui.searchResults.layoutSubtreeIfNeeded()
    let resultBox=ui.searchResults.stack.arrangedSubviews[1] as! NSStackView
    let resultHeader=resultBox.arrangedSubviews[0] as! WorkspaceResultHeader
    try check(abs(resultHeader.frame.width-(ui.searchResults.contentSize.width-48))<1 && resultHeader.date.frame.maxX>500 && resultBox.frame.height<180,"AT78 result hugs content and room/date header expands to result width instead of truncating at intrinsic width")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let window=NSWindow(contentRect:ui.frame,styleMask:[.titled],backing:.buffered,defer:false);let canvas=WorkspaceCanvas(frame:ui.frame);canvas.addSubview(ui);window.contentView=canvas;window.appearance=NSAppearance(named:.aqua);window.orderFrontRegardless();ui.layoutSubtreeIfNeeded();await pause(0.1)
        func capture(_ name:String) throws {ui.layoutSubtreeIfNeeded();let bitmap=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:bitmap);try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent(name))}
        try capture("task26-search.png");_=ui.closeSearchIfOpen();ui.chooseEmployee("alpha");ui.refresh();try capture("task26-workspace.png");window.orderOut(nil)
    }
    let key=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:0,context:nil,characters:"ㄹ",charactersIgnoringModifiers:"ㄹ",isARepeat:false,keyCode:3)!
    try check(ui.handleWorkspaceKey(key) && ui.isSearchOpen,"AT78 command Korean keyboard opens search")
    let escape=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:0,context:nil,characters:"",charactersIgnoringModifiers:"",isARepeat:false,keyCode:53)!
    try check(ui.handleWorkspaceKey(escape) && !ui.isSearchOpen && !ui.handleWorkspaceKey(escape),"AT78 Escape closes search first")
    print("AT-HF-77/78/79 WORKSPACE PASS")
}

@MainActor func workspaceNetwork(_ args:[String]) async throws {
    let home=URL(fileURLWithPath:args[2]),store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client)
    let ui=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    try client.pair(address:args[3],code:"test_code-12",device:"fake workspace")
    try await waitFor{controller.canSend};ui.chooseEmployee("alpha");ui.createThread()
    let first=controller.model.selected!;controller.setText("follow-empty");await controller.sendCurrent()
    try await waitFor{controller.model.timeline(first).count==2}
    try check(ui.replyMode && controller.model.selected==first,"AT79 employee reply automatically targets empty new-post composer")
    ui.createThread();let second=controller.model.selected!;controller.setText("follow-typed");await controller.sendCurrent()
    try await waitFor{!controller.sending};controller.setText("another draft")
    try await waitFor{controller.model.timeline(second).count==2}
    try check(!ui.replyMode && controller.draft.text=="another draft","AT79 employee reply never redirects nonempty draft")
    controller.setText("fail");await controller.sendCurrent();try await waitFor{controller.failures.count==1}
    try check(controller.draft.isEmpty && controller.notice.hasSuffix(" · 보내지 못한 글은 입력창 위 ‘되살리기’로 다시 쓸 수 있어요."),"AT79 rejection has original failure guidance")
    await pause(0.5);try check(!controller.sending && controller.failures.count==1,"AT79 no automatic retry after rejection")
    client.stop();print("AT-HF-79 WORKSPACE NETWORK PASS")
}
