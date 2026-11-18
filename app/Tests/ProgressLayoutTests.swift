import AppKit

@MainActor func progressLayoutTests(outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let controller=try testConversation(client:GateClient(store:LocalStore(directory:home),credentials:MemoryCredentials()))
    let people:[[String:Any]]=zip(["alpha","beta","gamma","delta","epsilon","zeta"],["A","B","C","D","E","F"]).map{["id":$0.0,"name":"직원 "+$0.1,"aliases":[]]}
    controller.receive(["type":"roster","employees":people])
    let view=ConversationView(controller:controller,islandModel:IslandModel(clock:{controller.clock()}));view.frame=CGRect(x:0,y:0,width:850,height:620);view.reduceMotion={true};view.chooseHome()
    let window=NSWindow(contentRect:view.frame,styleMask:[.borderless],backing:.buffered,defer:false)
    window.isReleasedWhenClosed=false;window.backgroundColor = .white;window.contentView=view;window.orderFrontRegardless();defer{window.orderOut(nil)}
    view.refresh();view.layoutSubtreeIfNeeded()
    let faces=try homeRequire(homeDescendants(view,ComposerFaces.self).first,"AT85 faces")
    let modes=try homeRequire(homeDescendants(view,ComposerButton.self).first{$0.title=="답글"},"AT85 reply switch")
    let faceScroll=try homeRequire(faces.enclosingScrollView,"AT85 horizontal face scroll")
    try check(abs(faceScroll.frame.maxX-(view.bounds.width-10))<0.1,"AT85 faces anchored right")
    try check(abs(faceScroll.frame.midY-modes.superview!.convert(modes.frame,to:view).midY)<0.1,"AT85 composer vertical centers")
    try check(faceScroll.hasHorizontalScroller && faces.frame.width==204,"AT85 six faces keep natural width")
    controller.receive(["type":"roster","employees":Array(people.prefix(1))]);view.refresh();view.layoutSubtreeIfNeeded()
    try check(faces.faces.count==1 && faces.frame.width==34,"AT85 single face natural width")
    controller.receive(["type":"roster","employees":people]);view.refresh();view.layoutSubtreeIfNeeded()
    view.frame.size.width=300;view.needsLayout=true;view.layoutSubtreeIfNeeded()
    try check(faces.frame.width>faceScroll.contentSize.width,"AT85 overflowing faces scroll")
    view.frame.size.width=850;view.needsLayout=true;view.layoutSubtreeIfNeeded()
    let working=WorkingControlRow(since:Date(timeIntervalSince1970:0),activity:"답변을 작성하고 있습니다",clock:{Date(timeIntervalSince1970:12)},animationTime:{0},reduceMotion:{true},stop:{})
    working.frame=CGRect(x:0,y:0,width:650,height:26);working.layoutSubtreeIfNeeded()
    try check(abs(working.button.frame.minX-working.row.elapsedRect.maxX-6)<0.1 && working.button.frame.maxX<500,"AT85 stop follows elapsed by six")
    try check(working.button.frame.size==CGSize(width:18,height:18) && working.button.accessibilityLabel()=="중지","AT85 stop hit area")
    try check(abs(working.row.elapsedRect.minX-working.row.wordsRect.maxX-9)<0.1,"AT85 activity elapsed nine")
    let key=ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111"),mid="22222222-2222-4222-8222-222222222222"
    controller.receive(["v":1,"type":"message","seq":1,"msg_id":mid,"employee":"alpha","thread":key.thread,"role":"employee","text":"생각 중…","files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-01T00:00:00Z"])
    controller.receive(["v":1,"type":"edit","seq":2,"msg_id":mid,"text":"생각 중…","final":false]);try check(controller.working(key),"AT85 unfinished work")
    controller.receive(["v":1,"type":"edit","seq":3,"msg_id":mid,"text":"생각 중…","final":true]);try check(!controller.working(key),"AT85 final edit closes thinking activity")
    controller.receive(["v":1,"type":"edit","seq":4,"msg_id":mid,"text":"늦은 글","final":false]);try check(controller.working(key),"AT85 late edit can resume")
    try check(controller.model.sidebar.stackName=="DM","AT85 default DM")
    controller.model.editSection(nil,name:"개인 대화");try check(controller.model.sidebar.stackName=="개인 대화","AT85 owner DM name retained")
    let (_,_,roomField,_)=RoomDialogs.dialog(people:controller.model.employees)
    try check(RoomDialogs.name("  새 방 시험  ")=="새 방 시험" && RoomDialogs.name("#Mixed Name")=="#Mixed Name","AT85 free room name")
    try check(!RoomDialogs.dialog(people:controller.model.employees).0.informativeText.contains("소문자"),"AT85 Slack hint removed")
    // Exercise actual AppKit marked-text input in the room field, both searches and composer.
    let (_,titleField,descriptionField)=RoomDialogs.header(title:"",description:"")
    for field in [roomField,titleField,descriptionField,view.search,view.employeeSearch] {
        let panel=NSView(frame:CGRect(x:0,y:0,width:320,height:80));field.removeFromSuperview();field.frame=CGRect(x:0,y:0,width:300,height:24);panel.addSubview(field)
        let inputWindow=NSWindow(contentRect:panel.frame,styleMask:[.borderless],backing:.buffered,defer:false);inputWindow.isReleasedWhenClosed=false;inputWindow.contentView=panel;inputWindow.orderFrontRegardless();inputWindow.makeFirstResponder(field)
        let editor=try homeRequire(field.currentEditor() as? NSTextView,"AT85 native field editor")
        editor.setMarkedText("새 방 시",selectedRange:NSRange(location:4,length:0),replacementRange:NSRange(location:0,length:(editor.string as NSString).length))
        try check(editor.hasMarkedText() && editor.string=="새 방 시","AT85 marked field intact")
        editor.insertText("새 방 시험",replacementRange:NSRange(location:0,length:(editor.string as NSString).length));try check(field.stringValue=="새 방 시험","AT85 Hangul field commit")
        inputWindow.orderOut(nil)
    }
    let editor=view.editor.editor
    editor.setMarkedText("새 방 시",selectedRange:NSRange(location:4,length:0),replacementRange:NSRange(location:0,length:(editor.string as NSString).length))
    view.textDidChange(Notification(name:NSText.didChangeNotification,object:editor));view.refresh()
    try check(editor.hasMarkedText() && editor.string=="새 방 시","AT85 composer refresh preserves marked text")
    editor.insertText("새 방 시험",replacementRange:NSRange(location:0,length:(editor.string as NSString).length));try check(editor.string=="새 방 시험","AT85 composer Hangul commit")
    // Search fields are restored to the real view after their native-editor exercise.
    view.addSubview(view.search);view.addSubview(view.employeeSearch);view.employeeSearch.stringValue="";view.search.stringValue=""
    view.controller.model.pin("alpha",slot:1);view.controller.model.pin("beta",slot:2);view.refresh();view.layoutSubtreeIfNeeded()
    let add=try homeRequire(homeDescendants(view,FileChip.self).first{$0.accessibilityLabel()?.hasPrefix("방 추가")==true},"AT85 plus inside document")
    try check(add.enclosingScrollView===view.employeeTable.enclosingScrollView && add.frame.height==40 && abs(view.employeeTable.rect(ofRow:view.sidebarRows.count).minY-view.employeeTable.rect(ofRow:view.sidebarRows.count-1).maxY-view.employeeTable.intercellSpacing.height)<0.1,"AT85 plus immediately follows rows")
    controller.model.toggleSection("1");view.refresh();view.layoutSubtreeIfNeeded()
    try check(view.sidebarRows.contains{$0.id=="alpha"},"AT85 section contents remain available")
    controller.model.toggleSection("1");view.refresh();view.layoutSubtreeIfNeeded()
    controller.receive(["type":"roster","employees":Array(people.prefix(3))]);view.refresh();view.layoutSubtreeIfNeeded()
    try check(view.employeeTable.rect(ofRow:view.sidebarRows.count).height==40,"AT85 three-room footer")
    let crowded=people+(7...20).map{["id":"sample\($0)","name":"직원 \($0)","aliases":[]] as [String:Any]}
    controller.receive(["type":"roster","employees":crowded]);controller.model.toggleSection(nil);view.refresh();view.layoutSubtreeIfNeeded()
    let footer=view.employeeTable.rect(ofRow:view.sidebarRows.count)
    try check(footer.maxY<=view.employeeTable.frame.height && footer.minY>(view.employeeTable.enclosingScrollView?.contentSize.height ?? 0),"AT85 twenty rooms scroll with add last")
    controller.model.toggleSection(nil);view.refresh();view.layoutSubtreeIfNeeded()
    controller.receive(["type":"roster","employees":people]);view.refresh();view.layoutSubtreeIfNeeded()
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        controller.clock={Date(timeIntervalSince1970:1767225612)}
        controller.model.editSection(nil,name:"");view.setSidebarWidth(212)
        view.frame.size=CGSize(width:850,height:620);view.layer?.backgroundColor=NSColor.white.cgColor;view.chooseHome();view.refresh();view.layoutSubtreeIfNeeded();await pause(0.1)
        let image=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:image)
        try image.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task34-hejo.png"))
    }
    print("AT-HF-85 APP PASS")
}
