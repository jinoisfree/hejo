import AppKit

@MainActor func uiCleanPolishTests(resourceDirectory:URL,diagnoseOnly:Bool=false) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let previous=ChatAppearance.store;defer{ChatAppearance.bind(previous)}
    let store=try LocalStore(directory:home);ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let now=ThreadTools.date("2026-11-23T12:00:00+09:00");controller.clock={now};controller.deadlineSender={_ in}
    try await controller.client.receive(["v":1,"type":"welcome","employees":[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]])
    var seq=0
    func post(_ employee:String,_ asked:Bool,_ labels:[String]=[])throws->ConversationMessage{
        seq+=1;let id=UUID().uuidString.lowercased()
        let row:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":UUID().uuidString.lowercased(),"role":"employee","text":"**가짜 질문**\n검토해 주세요.","files":[],"buttons":labels.map{["id":UUID().uuidString.lowercased(),"label":$0,"kind":"reply","style":"default"]},"reply_state":asked ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now)]
        try store.append(row);controller.receive(row);return controller.model.messages[id]!
    }
    let question=try post("alpha",true,["승인","거절","의견","확인"])
    _=try post("beta",true)
    for _ in 0..<3{_=try post("beta",false)}
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer{disposeDrawerFixture(pet,controller,view)}
    view.reduceMotion={true};view.island.reduceMotion={true};pet.reducedMotion={true};pet.pet.animationsAllowed=false
    pet.displays={let r=CGRect(x:0,y:0,width:1440,height:900);return [PetDisplay(frame:r,visible:r)]}
    pet.preferredChatSize=CGSize(width:760,height:500)
    pet.pet.installConversation(view);pet.installDrawer(view);pet.placePet(at:CGPoint(x:600,y:650));pet.showChat();view.chooseThread(question.key)
    func all(_ root:NSView)->[NSView]{[root]+root.subviews.flatMap{all($0)}}
    func settle(){pet.stepPlacement();view.layoutSubtreeIfNeeded();CATransaction.flush()}
    func bitmap(_ target:NSView)->NSBitmapImageRep{target.needsDisplay=true;target.displayIfNeeded();let rep=target.bitmapImageRepForCachingDisplay(in:target.bounds)!;target.cacheDisplay(in:target.bounds,to:rep);return rep}
    let cwd=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
    let evidence=(cwd.lastPathComponent=="app" ? cwd.deletingLastPathComponent():cwd).appendingPathComponent(".build/ui-clean-evidence")
    try FileManager.default.createDirectory(at:evidence,withIntermediateDirectories:true)
    func capture(_ name:String,_ target:NSView)throws{try bitmap(target).representation(using:.png,properties:[:])!.write(to:evidence.appendingPathComponent(name+".png"))}
    func json(_ name:String,_ value:Any)throws{try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:evidence.appendingPathComponent(name+".json"))}
    func redPoints(_ rep:NSBitmapImageRep)->[CGPoint]{
        let sx=CGFloat(rep.pixelsWide)/view.bounds.width,sy=CGFloat(rep.pixelsHigh)/view.bounds.height
        var points:[CGPoint]=[]
        for y in max(0,Int((view.bounds.height-65)*sy))..<rep.pixelsHigh{
            for x in 0..<rep.pixelsWide{
                if let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB),c.alphaComponent>0.015,c.redComponent>c.greenComponent*1.8,c.redComponent>c.blueComponent*1.5,c.redComponent>0.15{points.append(CGPoint(x:CGFloat(x)/sx,y:CGFloat(y)/sy))}
            }
        }
        return points
    }
    try ChatAppearance.change(theme:.dark);pet.applyChatAppearance();settle();await pause(0.5);settle()
    let initial=redPoints(bitmap(view))
    if diagnoseOnly{
        try capture("task-03-probe-before",view);try capture("task-03-probe-full-pet",pet.pet)
        let tree=all(pet.panel.contentView!.superview ?? pet.pet).map{v->[String:Any] in
            ["type":String(reflecting:type(of:v)),"frame":NSStringFromRect(v.frame),"hidden":v.isHidden,"opaque":v.isOpaque,"title":(v as? NSButton)?.title ?? "","layers":v.layer?.sublayers?.count ?? 0]
        }
        try json("task-03-view-hierarchy-before",tree)
        var occlusion:[[String:Any]]=[]
        for child in view.subviews where !child.isHidden{
            child.isHidden=true;view.needsDisplay=true;CATransaction.flush()
            let remaining=redPoints(bitmap(view)).count
            child.isHidden=false;view.needsDisplay=true;CATransaction.flush()
            if remaining != initial.count{occlusion.append(["type":String(reflecting:type(of:child)),"title":(child as? NSButton)?.title ?? "","frame":NSStringFromRect(child.frame),"redPixels":remaining])}
        }
        let hits=initial.enumerated().filter{$0.offset%max(1,initial.count/12)==0}.map{_,p->[String:Any] in
            let hit=view.hitTest(view.convert(p,to:view.superview))
            return ["point":NSStringFromPoint(p),"hit":hit.map{String(reflecting:type(of:$0))} ?? "none","title":(hit as? NSButton)?.title ?? ""]
        }
        try json("task-03-pink-probe",["redPixels":initial.count,"occlusion":occlusion,"hitSamples":hits,"legacyCollapseHidden":pet.pet.collapseButton.isHidden,"legacyCollapseTitle":pet.pet.collapseButton.title])
        print("AT-UC-35 PROBE red pixels=\(initial.count), legacyCollapseHidden=\(pet.pet.collapseButton.isHidden)")
        return
    }
    try check(initial.isEmpty && view.failureBar.isHidden,"AT-UC-35 empty failure bar leaves no pink corner pixels")
    try capture("task-03-pink-after",view)
    try json("task-03-pink-after",["redPixels":initial.count,"failureBarHidden":view.failureBar.isHidden,"failureBarFrame":NSStringFromRect(view.failureBar.frame)])
    let notice=all(view).compactMap{$0 as? NSScrollView}.first{$0.documentView === view.noticeBar}!
    pet.setDrawerOpen(false);view.refresh();settle()
    try check(!notice.isHidden,"AT-UC-30 closed drawer shows notice chips")
    pet.setDrawerOpen(true);view.refresh();settle()
    try check(notice.isHidden,"AT-UC-30 open drawer hides notice chips")
    pet.setDrawerOpen(false);view.refresh();settle()
    try check(!notice.isHidden,"AT-UC-30 closing drawer restores notice chips")
    controller.model.pin("beta",slot:1)
    if controller.model.sidebar.sections.first(where:{$0.id=="1"})?.open != true{controller.model.toggleSection("1")}
    controller.model.editSection("2",name:"함께")
    view.setSidebarWidth(212);view.refresh();settle()
    func cell(_ index:Int)->EmployeeSidebarCell {view.employeeTable.view(atColumn:0,row:index,makeIfNecessary:true) as! EmployeeSidebarCell}
    let homeCell=cell(view.sidebarRows.firstIndex{$0.kind == .home}!)
    let otherCell=cell(view.sidebarRows.firstIndex{$0.kind == .room && $0.id=="beta"}!)
    // Feed the actual renderer the acceptance row values; no production source is replaced.
    homeCell.row=SidebarLayout.Row(kind:.home,id:HomeRoom.id,name:"hejo",items:[.init(id:"alpha",name:"직원 A",kind:.direct,unread:4,questions:2,alerts:3)])
    homeCell.unread=4;homeCell.duration=0;homeCell.refreshChrome();homeCell.layoutSubtreeIfNeeded()
    otherCell.unread=1;otherCell.duration=0;otherCell.refreshChrome();otherCell.layoutSubtreeIfNeeded()
    func counters(_ cell:EmployeeSidebarCell)->[CALayer]{Mirror(reflecting:cell).children.first{$0.label=="counters"}!.value as! [CALayer]}
    try check(counters(homeCell).allSatisfy{$0.isHidden && $0.sublayers?.allSatisfy{$0.isHidden} == true},"AT-UC-31 all home badge layers hidden with 2 questions, 3 alerts and 4 unread")
    try check(!counters(otherCell)[0].isHidden && counters(otherCell)[0].opacity==1,"AT-UC-31 another room retains its unread badge")
    view.chooseThread(question.key);view.refresh();settle();await pause(0.5);settle()
    let words=all(view.history).compactMap{$0 as? FileChip}.filter{$0.replyWord != nil}
    try check(words.map(\.title)==["승인","거절","의견","확인"] && words.allSatisfy{$0.image == nil},"AT-UC-32 four word-only judgment buttons without image")
    for theme in [ChatTheme.dark,.light]{
        try ChatAppearance.change(theme:theme);pet.applyChatAppearance();view.refresh();settle();await pause(0.25);settle()
        if theme == .light {
            let section=cell(view.sidebarRows.firstIndex{$0.id=="section:2"}!),rep=bitmap(section)
            // Actual transparent pixels on the light test canvas, including alpha.
            func composite(_ c:NSColor)->[CGFloat]{let c=c.usingColorSpace(.deviceRGB)!,a=c.alphaComponent;return [c.redComponent*a+1-a,c.greenComponent*a+1-a,c.blueComponent*a+1-a,1]}
            let background=composite(rep.colorAt(x:1,y:1)!)
            var contrast:CGFloat=0
            for y in 0..<rep.pixelsHigh{for x in 0..<rep.pixelsWide{let c=composite(rep.colorAt(x:x,y:y)!);contrast=max(contrast,zip(c,background).reduce(0){$0+abs($1.0-$1.1)})}}
            try check(contrast>0.3,"AT-UC-33 light section lettering contrasts with row background")
            try json("task-03-light-section",["maximumRGBAContrast":contrast,"headingColor":String(describing:section.heading.foregroundColor)])
            try capture("task-03-light-section",section)
        }
        for open in [false,true]{
            pet.setDrawerOpen(open);view.refresh();settle()
            try capture("task-03-"+(open ? "open":"closed")+"-"+theme.rawValue,view)
        }
    }
    let visibleButtons=all(pet.panel.contentView!.superview ?? pet.pet).compactMap{$0 as? NSButton}.filter{!$0.isHiddenOrHasHiddenAncestor}
    try check(pet.pet.collapseButton.isHidden && !visibleButtons.contains{$0.title=="⌄" || $0.title=="펫으로 접기"},"AT-UC-35 runtime hierarchy has no visible down-chevron collapse button")
    try capture("task-03-full-pet",pet.pet)
    try json("task-03-collapse-owner",["legacyTitle":pet.pet.collapseButton.title,"legacyHidden":pet.pet.collapseButton.isHidden,"visibleButtonTitles":visibleButtons.map(\.title),"windowStyleMask":pet.panel.styleMask.rawValue,"source":"legacy PetView collapseButton; down-chevron decoration exists only in early HTML mockups"])
    pet.setDrawerOpen(false);view.chooseThread(question.key)
    controller.setText("가짜 전송 실패",for:question.key);await controller.sendCurrent(for:question.key);view.refresh();settle()
    try check(!view.failureBar.isHidden && !view.failureBar.arrangedSubviews.isEmpty,"AT-UC-35 real failure guidance stays visible")
    for failure in controller.failures{controller.discardFailure(failure.id)}
    view.refresh();settle()
    try check(view.failureBar.isHidden && redPoints(bitmap(view)).isEmpty,"AT-UC-35 clearing failures hides the empty background again")
    print("AT-UC-30..35 POLISH PASS; AT-UC-34 protected by AT88/AT89")

}
