import AppKit

/// AT91 compares native viewport coordinates and input cancellation against source formulas.
@MainActor func scrollTests(outputDirectory:URL?=nil) async throws {
    let highlighted=WorkspaceSearch.attributed("찾을 글",query:"찾을")
    try check((highlighted.attribute(.backgroundColor,at:0,effectiveRange:nil) as? NSColor)==NSColor.systemYellow,"AT91 search uses system yellow")
    for value in ["2026-11-01T12:34:56.123456Z","2026-11-01T12:34:56Z","2026-11-01T21:34:56+09:00","invalid","1234567"] {
        let fractional=ISO8601DateFormatter();fractional.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let expected=fractional.date(from:value) ?? ISO8601DateFormatter().date(from:value) ?? .distantPast
        let results=await withTaskGroup(of:Bool.self,returning:[Bool].self){group in
            for _ in 0..<20 {group.addTask{ThreadTools.date(value)==expected}}
            var values:[Bool]=[];for await result in group {values.append(result)};return values
        }
        try check(results.count==20 && results.allSatisfy{$0},"AT91 shared date parser preserves old fractional/whole/failure results concurrently")
    }
    let list=NativeThreadList(frame:CGRect(x:0,y:0,width:460,height:300))
    let window=NSWindow(contentRect:list.frame,styleMask:[],backing:.buffered,defer:false);window.contentView=list;window.orderFrontRegardless()
    defer{window.orderOut(nil)}
    var now=10.0;list.clock={now};list.automaticallyTicks=false;list.reduceMotion={true}
    func cards(_ grow:CGFloat=0,stream:Bool=false)->[NativeThreadCard.Content] {(0..<18).map{i in
        let p=NativeThreadCard.Post(id:"post-\(i)",mine:false,text:NSAttributedString(string:"본문 \(i)"),speaker:"직원 A",time:"",avatar:ProfileAvatar(),nameColor:.labelColor,streaming:stream && i==17,openLink:{_ in})
        return .init(id:"row-\(i)",top:[.post(p),.accessory(id:"space-\(i)",height:70+(i==17 ? grow:0),view:{NSView()})],replies:nil,rail:nil,actions:[],deleting:nil,style:.init(inset:12,fill:0,stroke:nil,lineWidth:1),bell:nil,onBell:{},clickCard:{},bubbleWidth:300,quiet:.secondaryLabelColor,expanded:false)
    }}
    list.show(cards(),identity:"fake-room");list.layoutSubtreeIfNeeded()
    list.scrollTo("row-7");await pause(0.5)
    let row=try homeRequire(list.frame(for:"row-7"),"AT91 measured row")
    try check(abs(list.contentView.bounds.midY-row.midY)<1,"AT91 jump centers the thread")
    let centerActual=list.contentView.bounds.minY
    list.scrollTo("row-7",bottom:true);await pause(0.5)
    try check(abs(list.contentView.bounds.maxY-row.maxY)<1,"AT91 unfolded thread scrolls to end")
    let endActual=list.contentView.bounds.maxY
    list.scrollTo("row-10");list.readerInput(wheel:false);list.contentView.scroll(to:CGPoint(x:0,y:30));await pause(0.5)
    try check(abs(list.contentView.bounds.minY-30)<1,"AT91 reader cancels all delayed requests")
    // A 100pt reader follows growth; a 150pt reader keeps the old bottom distance instead.
    list.contentView.scroll(to:CGPoint(x:0,y:list.table.bounds.maxY-list.contentView.bounds.height-100))
    list.reduceMotion={false};list.show(cards(300,stream:true),identity:"fake-room");let before=list.contentView.bounds.minY
    try check(list.isFollowing,"AT91 100pt starts stream follow")
    now+=1.0/60;list.reduceMotion={false};list.advanceFollow()
    let first=list.contentView.bounds.minY
    try check(abs(first-before-36)<0.1,"AT91 first growing frame capped at 36pt")
    now+=1.0/60;list.advanceFollow();try check(list.contentView.bounds.minY>first && list.contentView.bounds.minY-first<=36.01,"AT91 next intermediate frame keeps gliding")
    list.contentView.scroll(to:CGPoint(x:0,y:list.table.bounds.maxY-list.contentView.bounds.height-50));let smallBefore=list.contentView.bounds.minY
    now+=1.0/60;list.advanceFollow();let smallStep=list.contentView.bounds.minY-smallBefore
    try check(abs(smallStep-10)<0.1,"AT91 uncapped growth follows twenty percent")
    list.contentView.scroll(to:CGPoint(x:0,y:list.table.bounds.maxY-list.contentView.bounds.height))
    list.show(cards(300,stream:false),identity:"fake-room");for _ in 0..<24 {now+=0.01;list.advanceFollow()}
    try check(list.isFollowing,"AT91 final message continues observing for 1.2 seconds")
    now+=1.1;list.advanceFollow();try check(!list.isFollowing,"AT91 final follow eventually settles")
    list.readerInput(wheel:false);let stopped=list.contentView.bounds.minY;now+=1;list.advanceFollow()
    try check(!list.isFollowing && abs(list.contentView.bounds.minY-stopped)<0.1,"AT91 manual input stops stream motion")
    list.reduceMotion={true};list.show(cards(),identity:"other-room");list.readerInput(wheel:false)
    list.contentView.scroll(to:CGPoint(x:0,y:list.table.bounds.maxY-list.contentView.bounds.height-150));let bottomDistance=list.table.bounds.maxY-list.contentView.bounds.maxY
    list.show(cards(300,stream:true),identity:"other-room");await pause(0.01)
    try check(!list.isFollowing && abs(list.table.bounds.maxY-list.contentView.bounds.maxY-bottomDistance)<1,"AT91 150pt keeps bottom-distance and does not follow")
    // Prepending history retains the distance from the document bottom, including delayed layout passes.
    let held=list.table.bounds.maxY-list.contentView.bounds.maxY
    var added=cards();var prefix=added[0];prefix.id="older-history";added.insert(prefix,at:0)
    list.show(added,identity:"other-room");await pause(0.42)
    try check(abs(list.table.bounds.maxY-list.contentView.bounds.maxY-held)<1,"AT91 older rows keep reader bottom-distance")
    list.readerInput(wheel:true);list.show(cards(),identity:"other-room")
    try check(list.hasDeferredUpdate && list.contents.first?.id=="older-history","AT91 wheel defers new snapshot")
    now+=0.24;list.flushDeferred();try check(list.hasDeferredUpdate,"AT91 quiet interval 0.25")
    now+=0.02;list.flushDeferred();try check(!list.hasDeferredUpdate && list.contents.first?.id=="row-0","AT91 quiet reader receives latest snapshot")
    list.readerInput(wheel:true);list.show(added,identity:"other-room")
    for _ in 0..<8 {now+=0.24;list.readerInput(wheel:true);list.flushDeferred()}
    try check(list.hasDeferredUpdate,"AT91 continuous input still held before two seconds")
    now+=0.1;list.readerInput(wheel:true);list.flushDeferred();try check(!list.hasDeferredUpdate,"AT91 continuous input settles by two seconds")
    list.readerInput(wheel:false);list.enter("row-6");let visible=list.contentView.bounds,firstID=list.contents.first{list.frame(for:$0.id)?.intersects(visible)==true}!.id,offset=list.frame(for:list.contents.first{list.frame(for:$0.id)?.intersects(visible)==true}!.id)!.minY-visible.minY
    list.beginReadingResize();list.frame.size.width=390;list.layoutSubtreeIfNeeded();list.endReadingResize()
    try check(abs(list.frame(for:firstID)!.minY-list.contentView.bounds.minY-offset)<1,"AT91 resize restores visible row and offset")
    // Actual AppKit middle frame, before the final center is reached.
    list.reduceMotion={false};list.scrollTo("row-10");await pause(0.01);now+=0.08;list.advanceScroll()
    let mid=list.contentView.bounds.minY,target=list.frame(for:"row-10")!.midY-list.contentView.bounds.height/2
    try check(mid>visible.minY && mid<target,"AT91 0.24 scroll has an intermediate position")
    list.readerInput(wheel:false);await pause(0.5)
    let samples:[String:Double]=["centerMidY":Double(row.midY),"centerActualY":Double(centerActual),"endActualMaxY":Double(endActual),"endExpectedMaxY":Double(row.maxY),"smallGrowthStep":Double(smallStep),"firstGrowthStep":Double(first-before),"manualStoppedY":Double(stopped),"resizeOffset":Double(offset),"animatedMiddleY":Double(mid),"centerExpectedY":Double(row.midY-300/2),"followGap":400,"followFrames":1]
    try await workspaceMotionTests(outputDirectory:outputDirectory,samples:samples)
    try await heightFollowTests()
    print("AT-HF-91 APP PASS")
}

@MainActor private func workspaceMotionTests(outputDirectory:URL?,samples:[String:Double]) async throws {
    NSApp.appearance=NSAppearance(named:.aqua)
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client),model=controller.model
    defer{client.stop()}
    if outputDirectory != nil {try client.pair(address:try homeRequire(ProcessInfo.processInfo.environment["HEJO_CAPTURE_ADDRESS"],"AT91 fake connection"),code:"test_code-12",device:"fake capture");try await waitFor{controller.canSend}}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]])
    var time=Date(timeIntervalSince1970:1794000000),seq=0,motion=10.0
    controller.clock={time};model.noticeClock={time}
    @discardableResult func post(_ text:String,thread:String=UUID().uuidString.lowercased(),speaker:String="alpha",state:String?=nil,age:Double=0)throws->ConversationMessage {
        seq+=1;let id=UUID().uuidString.lowercased(),frame:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":"alpha","thread":thread,"role":"employee","speaker":speaker,"text":text,"files":[],"buttons":[],"reply_state":state as Any? ?? NSNull(),"ts":ISO8601DateFormatter().string(from:time.addingTimeInterval(-age))]
        try store.append(frame);controller.receive(frame);return model.messages[id]!
    }
    let a=try post("확인할 일정 문서",state:"asked",age:90),b=try post("둘째 일정",state:"asked",age:80)
    try post("같은 스레드 새 질문",thread:a.key.thread,state:"asked",age:70)
    let ui=ConversationView(controller:controller,islandModel:IslandModel(clock:{time}),motionTime:{motion});ui.motionTime={motion};ui.reduceMotion={false};ui.frame=CGRect(x:0,y:0,width:740,height:660)
    let win=NSWindow(contentRect:ui.frame,styleMask:[],backing:.buffered,defer:false);win.contentView=ui;win.orderFrontRegardless();defer{win.orderOut(nil)}
    ui.chooseEmployee("alpha");ui.refresh();ui.layoutSubtreeIfNeeded()
    let pills=homeDescendants(ui.noticeBar,NoticePill.self)
    try check(pills.first?.item.messages.count==2 && pills.first?.toolTip=="눌러서 해당 글로 이동","AT91 A17 counts threads once and pill tooltip")
    let halfway=ui.noticeScroll.alphaValue;motion+=0.12;ui.tickWorkspaceMotion();ui.layoutSubtreeIfNeeded()
    try check(ui.noticeScroll.alphaValue>=halfway && ui.noticeScroll.alphaValue>0 && ui.noticeScroll.alphaValue<1,"AT91 notice opacity has middle frame")
    motion+=0.13;ui.tickWorkspaceMotion();ui.layoutSubtreeIfNeeded();try check(ui.noticeScroll.alphaValue==1 && ui.noticeScroll.hasHorizontalScroller,"AT91 notice completes and scrolls horizontally")
    ui.jumpNotice(model.notices("alpha")[0]);ui.refresh()
    let flashed=ui.history.contents.first{$0.id==a.key.thread} ?? ui.history.contents.first{$0.id==b.key.thread}!
    try check(flashed.style.stroke == .controlAccentColor && flashed.style.lineWidth==2,"AT91 flash accent 2pt outline")
    try check((flashed.top+(flashed.replies ?? [])).contains{if case .post(let p)=$0{return p.flash};return false},"AT91 flashing message has native accent background")
    ui.openSearch();ui.search.stringValue="일정";ui.revealSearch(a);time.addTimeInterval(2);ui.tickIsland();ui.refresh()
    let highlighted=ui.history.contents.first{$0.id==a.key.thread}!
    let yellow=(highlighted.top+(highlighted.replies ?? [])).contains{piece in if case .post(let p)=piece {var found=false;p.text.enumerateAttribute(.backgroundColor,in:NSRange(location:0,length:p.text.length)){v,_,_ in if v as? NSColor == .yellow {found=true}};return found};return false}
    try check(yellow,"AT91 search emphasis survives 1.6 second flash")
    ui.chooseThread(a.key);let folded=ui.history.contents.first{$0.id==a.key.thread}!
    var stillYellow=false;for piece in folded.top+(folded.replies ?? []) {if case .post(let p)=piece {p.text.enumerateAttribute(.backgroundColor,in:NSRange(location:0,length:p.text.length)){v,_,_ in if v as? NSColor == .yellow {stillYellow=true}}}}
    try check(!stillYellow,"AT91 folding clears search emphasis")
    try check(!homeDescendants(ui,ComposerButton.self).contains{$0.title=="검색" || $0.title=="직원 목록"},"AT91 header right buttons removed")
    try check(ui.brandDrag.toolTip?.contains("더블클릭: 가로 2배 / 기본")==true && ui.headerDrag.accessibilityLabel()=="채팅창과 펫 이동","AT91 drag help and accessibility")
    ui.openSearch();ui.layoutSubtreeIfNeeded();try check(!ui.search.isBordered && !ui.search.drawsBackground && homeDescendants(ui,NSButton.self).contains{$0.toolTip=="검색 닫기 (Esc)"},"AT91 flat find row and close help")
    // Source ease, independent literal endpoints and midpoint.
    let ease=WorkspaceEase(from:0,to:1,start:0);try check(abs(ease.value(0.12)-0.5)<0.00001 && ease.value(0.24)==1,"AT91 easeInOut 0.24 midpoint")
    _=ui.closeSearchIfOpen();ui.createThread();motion+=0.25;ui.tickWorkspaceMotion();ui.writeReply();motion+=0.12;ui.tickWorkspaceMotion()
    let modes=homeDescendants(ui,ComposerButton.self)
    try check(abs((modes.first{$0.title=="답글"}?.selection ?? -1)-0.5)<0.0001,"AT91 composer capsule and text selection interpolates")
    let fakeFile=home.appendingPathComponent("sample.txt");try Data("fake".utf8).write(to:fakeFile);controller.addAttachments([fakeFile]);ui.refresh()
    let chip=try homeRequire(homeDescendants(ui,AttachmentChip.self).first,"AT91 attachment chip")
    try check((chip.layer?.animation(forKey:"attachment-opacity") as? CABasicAnimation)?.duration==0.24 && (chip.layer?.animation(forKey:"attachment-position") as? CABasicAnimation)?.fromValue as? Int==30,"AT91 attachment fades and moves from bottom")
    controller.removeAttachment(fakeFile);motion+=0.25;ui.tickWorkspaceMotion();ui.layoutSubtreeIfNeeded()
    ui.foldAll()
    let long=try post((0..<30).map{"긴 답 \($0)"}.joined(separator:"\n"),state:"closed",age:100)
    ui.refresh();var measured:CGFloat?;ui.onOpenThreadHeight={measured=$0}
    func longPost()->NativeThreadCard.Post? {for layout in ui.history.layouts {for item in layout.placed {if case .post(let p)=item.piece,p.id==long.id{return p}}};return nil}
    let closed=try homeRequire(longPost(),"AT91 folded long reply");try check(closed.foldTitle=="더 보기","AT91 long reply starts folded")
    closed.fold();ui.layoutSubtreeIfNeeded();try check((measured ?? 0)>ui.bounds.height && longPost()?.foldTitle=="접기","AT91 expanding post requests matching extra window height")
    longPost()?.fold();ui.layoutSubtreeIfNeeded();try check(measured==nil,"AT91 folding restores base window request")
    ui.onOpenThreadHeight=nil
    if let outputDirectory {
        try check(controller.canSend,"AT91 connected capture")
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        ui.openSearch();ui.search.stringValue="일정";ui.scheduleSearch();await pause(0.4)
        let fixture:[String:Any] = ["title":ui.island.snapshot.title,"description":"","query":"일정","groups":ui.searchGroups.map {g in ["room":"hejo","latest":g.latest.timeIntervalSince1970,"root":g.root.text,"matches":g.matches.map {m in ["id":m.id,"body":m.text,"speaker":model.name(m.speaker),"date":ThreadTools.date(m.timestamp).timeIntervalSince1970]}] as [String:Any]}]
        try JSONSerialization.data(withJSONObject:fixture,options:[.prettyPrinted,.sortedKeys]).write(to:outputDirectory.appendingPathComponent("source-fixture.json"))
        for (theme,name) in [(NSAppearance.Name.aqua,"light"),(.darkAqua,"dark")] {
            NSApp.appearance=NSAppearance(named:theme);win.appearance=NSAppearance(named:theme);ui.appearance=NSAppearance(named:theme)
            let rect=CGRect(x:0,y:0,width:740,height:660);win.setContentSize(rect.size);ui.frame=rect;let canvas=ScrollCaptureCanvas(frame:rect);canvas.dark=name=="dark";canvas.appearance=NSAppearance(named:theme);win.contentView=canvas;canvas.addSubview(ui)
            canvas.effectiveAppearance.performAsCurrentDrawingAppearance{ui.refresh();canvas.layoutSubtreeIfNeeded();ui.layoutSubtreeIfNeeded();func dirty(_ view:NSView){view.needsDisplay=true;view.subviews.forEach(dirty)};dirty(canvas);win.display();canvas.displayIfNeeded()};await pause(0.1)
            if let box=ui.searchResults.stack.arrangedSubviews.dropFirst().first,let color=box.layer?.backgroundColor.flatMap({NSColor(cgColor:$0)?.usingColorSpace(.sRGB)}) {try check(name=="dark" ? color.redComponent>0.9:color.redComponent<0.1,"AT91 search boxes repaint across appearance changes")}
            let bitmap=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:bitmap);try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task40-hejo-"+name+".png"))
        }
        _=ui.closeSearchIfOpen();motion+=0.3;ui.tickWorkspaceMotion();ui.layoutSubtreeIfNeeded()
        NSApp.appearance=NSAppearance(named:.aqua);win.appearance=NSAppearance(named:.aqua);ui.appearance=NSAppearance(named:.aqua)
        let rect=CGRect(x:0,y:0,width:740,height:660);win.setContentSize(rect.size);ui.frame=rect;let canvas=ScrollCaptureCanvas(frame:rect);win.contentView=canvas;canvas.addSubview(ui);canvas.effectiveAppearance.performAsCurrentDrawingAppearance{ui.refresh();canvas.layoutSubtreeIfNeeded();ui.layoutSubtreeIfNeeded();func dirty(_ view:NSView){view.needsDisplay=true;view.subviews.forEach(dirty)};dirty(canvas);win.display();canvas.displayIfNeeded()}
        let bannerBitmap=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:bannerBitmap);try bannerBitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task40-hejo-notices.png"))
        try JSONSerialization.data(withJSONObject:samples,options:[.prettyPrinted,.sortedKeys]).write(to:outputDirectory.appendingPathComponent("scroll-samples.json"))
    }
}

@MainActor private func heightFollowTests() async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:home)}
    let sibling=URL(fileURLWithPath:CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("hejo.app/Contents/Resources/Pet")
    let resources=FileManager.default.fileExists(atPath:sibling.path) ? sibling:URL(fileURLWithPath:"app/.build/hejo.app/Contents/Resources/Pet")
    let pet=PetController(store:try LocalStore(directory:home),atlas:try SpriteAtlas(resourceDirectory:resources))
    pet.displays={[PetDisplay(frame:CGRect(x:0,y:0,width:2400,height:2200),visible:CGRect(x:0,y:40,width:2400,height:2100))]}
    var now=1.0;pet.clock={now};pet.reducedMotion={true};pet.placePet(at:CGPoint(x:900,y:1800));pet.showChat()
    let base=pet.pet.placement!.globalBubble.height
    now=2;pet.reducedMotion={false};pet.stepPlacement();pet.fitOpenThread(base+100)
    try check(abs(pet.pet.placement!.globalBubble.height-base)<0.01,"AT91 height retarget starts at current glass")
    now+=0.065;pet.stepChatHeight()
    try check(abs((pet.shownChatHeight ?? 0)-(base+63.2120558829))<0.01,"AT91 actual panel height follows tau 0.065")
    for _ in 0..<20 {now+=0.065;pet.stepChatHeight()}
    try check(abs(pet.pet.placement!.globalBubble.height-base-100)<0.2,"AT91 fitted panel height settles")
    pet.fitOpenThread(nil);now+=0.065;pet.stepChatHeight();try check(pet.pet.placement!.globalBubble.height<base+100 && pet.pet.placement!.globalBubble.height>base,"AT91 folding returns through an intermediate height")
    pet.reducedMotion={true};pet.stepChatHeight();try check(abs(pet.pet.placement!.globalBubble.height-base)<0.2,"AT91 reduced motion height is immediate")
    pet.collapseChat();pet.panel.orderOut(nil)
}

private final class ScrollCaptureCanvas:NSView {
 var dark=false
 override var isFlipped:Bool{true}
 override func draw(_ dirtyRect:NSRect){(dark ? NSColor(white:0.12,alpha:1):.white).setFill();bounds.fill()}
}
