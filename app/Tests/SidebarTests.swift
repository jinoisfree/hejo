import AppKit
import QuartzCore

/// AT89 uses real table row views and their presentation layers, not a simulated animation clock.
@MainActor func sidebarTests(outputDirectory:URL?=nil) async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory),controller=try ConversationController(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    if outputDirectory != nil {
        try controller.client.pair(address:try homeRequire(ProcessInfo.processInfo.environment["HEJO_CAPTURE_ADDRESS"],"AT89 capture requires fake connection"),code:"test_code-12",device:"fake capture")
        try await waitFor{controller.canSend}
    }
    defer {controller.client.stop()}
    let names=["직원 A","직원 B","직원 C","직원 D","직원 E","직원 F"],ids=["alpha","beta","gamma","delta","epsilon","zeta"]
    controller.receive(["type":"roster","employees":zip(ids,names).map{["id":$0,"name":$1,"aliases":[],"color":"#007AFF"] as [String:Any]}])
    var seq=0
    func room(_ n:Int,_ title:String,_ count:Int) throws ->String {
        let id=String(format:"00000000-0000-4000-8000-%012d",n);seq+=1
        let frame:[String:Any]=["v":1,"type":"room","seq":seq,"room":["id":id,"title":title,"members":Array(ids.prefix(max(2,count))),"lead":ids[0],"archived":false]]
        try store.append(frame);controller.receive(frame);return id
    }
    let a=try room(1,"첫 방",2),b=try room(2,"둘째 방",6),c=try room(3,"빈 방",2)
    model.pin("alpha",slot:1);model.pin("beta",slot:2);model.move(a,to:"2");model.move(b,to:"2");model.move(c,to:"3")
    model.editSection("1",name:"고정");model.editSection("2",name:"함께");model.editSection("3",name:"보관 전")
    let ui=ConversationView(controller:controller);ui.reduceMotion={true};ui.frame=CGRect(x:0,y:0,width:850,height:810);ui.setSidebarWidth(212);ui.chooseHome()
    let window=NSWindow(contentRect:ui.frame,styleMask:.borderless,backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=ui;window.orderFrontRegardless()
    defer {window.orderOut(nil)}
    func settle() async {ui.refresh();ui.layoutSubtreeIfNeeded();await pause(0.04)}
    func index(_ id:String) throws ->Int {try homeRequire(ui.sidebarRows.firstIndex{$0.id==id},"AT89 missing row "+id)}
    func row(_ id:String) throws ->NSTableRowView {try homeRequire(ui.employeeTable.rowView(atRow:try index(id),makeIfNecessary:true),"AT89 native row "+id)}
    func cell(_ id:String) throws ->EmployeeSidebarCell {try homeRequire(ui.employeeTable.view(atColumn:0,row:try index(id),makeIfNecessary:true) as? EmployeeSidebarCell,"AT89 native cell "+id)}
    func rail(_ id:String) throws ->CAShapeLayer {try homeRequire(ui.employeeTable.layer?.sublayers?.first{$0.name=="section-rail-"+id} as? CAShapeLayer,"AT89 continuous rail")}
    await settle()
    try check(ui.sidebarRows.first?.kind == .search && ui.sidebarRows[2].kind == .gap,"AT89 search home and four-point gap share scrolling list")
    let search=try homeRequire(homeDescendants(ui,SidebarSearchRow.self).first,"AT89 search row")
    try check(search.frame.height==52 && search.background.frame.height==36 && search.background.layer?.cornerRadius==8 && search.field.placeholderString=="검색" && search.field.accessibilityLabel()=="방과 글 검색","AT89 inline search geometry and label")
    let folded=try cell("section:2");try check(folded.faces.isEmpty && folded.picture==nil && folded.heading.fontSize==16 && folded.toolTip=="함께 · 오른쪽 클릭으로 이름 편집 · 펼치기","AT89 folded section has name and signals only")
    let header=try row("section:3"),initialY=header.frame.minY,initialRail=try rail("section:2").path!.boundingBox.height
    ui.reduceMotion={false};model.toggleSection("2");ui.layoutSubtreeIfNeeded();await pause(0.095)
    let inserted=try row(a),moving=try row("section:3"),finalY=moving.frame.minY,shownY=moving.layer?.presentation()?.frame.minY ?? finalY
    let opacity=inserted.layer?.presentation()?.opacity ?? 1,insertedY=inserted.layer?.presentation()?.frame.minY ?? inserted.frame.minY
    let railHeight=try rail("section:2").presentation()?.path
    try check(opacity>0 && opacity<1 && abs(insertedY-inserted.frame.minY)<0.5,"AT89 inserted row fades at final y without slide or clipping")
    try check(shownY>initialY && shownY<finalY,"AT89 following row has an intermediate y")
    try check(railHeight != nil && railHeight!.boundingBox.height>initialRail && railHeight!.boundingBox.height<(try rail("section:2").path!.boundingBox.height),"AT89 continuous rail has intermediate height")
    try check(ui.employeeTable.presentedRow(at:NSPoint(x:100,y:shownY+moving.frame.height/2)) == (try index("section:3")),"AT89 moving row hit targets its visible position")
    try check(try cell("section:2") === folded,"AT89 stable header cell survives row differences")
    // Reverse before the first transition finishes. The stable row remains live and interactive.
    model.toggleSection("2");ui.layoutSubtreeIfNeeded();await pause(0.32)
    try check(abs((try row("section:3")).frame.minY-initialY)<0.5 && !ui.sidebarRows.contains{$0.id==a},"AT89 reverse while moving reaches collapsed layout")
    ui.reduceMotion={true};model.toggleSection("2");await settle()
    try check(abs((try row("section:3")).frame.minY-finalY)<0.5 && abs((try rail("section:2")).path!.boundingBox.height-129.5)<0.5,"AT89 reduce motion reaches same final layout immediately")
    let first=try cell(a),second=try cell(b);ui.chooseEmployee(a);await settle();ui.reduceMotion={false};ui.chooseEmployee(b);ui.layoutSubtreeIfNeeded();await pause(0.08)
    try check(first.selection.animation(forKey:"opacity") is CASpringAnimation && second.selection.animation(forKey:"opacity") is CASpringAnimation,"AT89 selection uses two opacity springs")
    try check(first.selection.animation(forKey:"position")==nil && second.selection.animation(forKey:"position")==nil,"AT89 selection does not travel between rows")
    let oldOpacity=first.selection.presentation()?.opacity ?? 0,newOpacity=second.selection.presentation()?.opacity ?? 1
    try check(oldOpacity>0 && oldOpacity<1 && newOpacity>0 && newOpacity<1,"AT89 old and new selection have intermediate opacity")
    await pause(0.5);ui.reduceMotion={true};ui.chooseHome();await settle()
    try check((try cell(HomeRoom.id)).selection.frame.minX==10 && first.selection.frame.minX==26 && first.faceRect.minX==36,"AT89 home and other list insets")
    model.pin(a,slot:3);model.toggleMute(a);await settle()
    let marked=try cell(a),marks=homeDescendants(marked,SidebarAXMark.self)
    let pin=try homeRequire(marks.first{$0.accessibilityLabel()=="고정됨"},"AT89 pin"),mute=try homeRequire(marks.first{$0.accessibilityLabel()=="알림 꺼짐"},"AT89 mute")
    try check(pin.frame.size==CGSize(width:11,height:12) && mute.frame.size==CGSize(width:9,height:11),"AT89 8pt SF symbols retain intrinsic 11x12 and 9x11 sizes")
    let swatch=NSImage(size:CGSize(width:16,height:16))
    NSAppearance(named:.aqua)!.performAsCurrentDrawingAppearance {
        swatch.lockFocus();NSColor.white.setFill();CGRect(x:0,y:0,width:16,height:16).fill()
        FileTile.symbol("pin.fill",point:8,at:CGPoint(x:8,y:8),color:SidebarTone.primary(0.7));swatch.unlockFocus()
    }
    let pixels=try homeRequire(NSBitmapImageRep(data:swatch.tiffRepresentation!),"AT89 quiet symbol bitmap")
    let darkest=(0..<16).flatMap{y in (0..<16).compactMap{x in pixels.colorAt(x:x,y:y)?.usingColorSpace(.sRGB)?.redComponent}}.min() ?? 1
    try check(darkest>0.35 && darkest<0.6,"AT89 quiet 8pt glyph retains primary alpha on white instead of opaque black")
    let plus=try homeRequire(homeDescendants(ui,FileChip.self).first{$0.accessibilityLabel()=="방 추가"},"AT89 add label")
    try check(plus.nativeLabelGap==8 && plus.image?.size==CGSize(width:15,height:15),"AT89 source Label has 15pt medium symbol and eight point text gap")
    model.pin(a,slot:nil);model.toggleMute(a);await settle()
    let sectionMenu=ui.sectionMenu(ui.sidebarRows[try index("section:2")]);try check(sectionMenu.items.map{$0.isSeparatorItem ? "|":$0.title} == ["접기","|","이름 바꾸기…","|","섹션 삭제…"],"AT89 section menu literal order and no photo")
    model.toggleSection("1");await settle()
    let directMenu=ui.employeeMenu(row:try index("alpha"));try check(!directMenu.items.contains{$0.title=="모두 읽음" || $0.title=="도구 연결…"},"AT89 direct menu excludes unrelated actions")
    let add=ui.addMenu();try check(add.items.map{$0.isSeparatorItem ? "|":$0.title} == ["새 방 만들기…","새 섹션 만들기","|","목록에서 뺀 방","뺀 방이 없어요"],"AT89 add menu hidden section inline and no empty archive")
    let (dialog,field)=RoomDialogs.sectionDialog("함께");try check(dialog.buttons.map(\.title)==["바꾸기","취소"] && field.frame.width==320 && dialog.window.initialFirstResponder===field,"AT89 section dialog geometry labels focus")
    let presenter=RoomDialogs.present;defer{RoomDialogs.present=presenter};var prompts=0,warningMatched=false
    RoomDialogs.present={alert in prompts+=1;if prompts==1 {(alert.accessoryView as? NSTextField)?.stringValue="";return .alertFirstButtonReturn};if prompts==2 {warningMatched=alert.messageText=="방 이름을 넣어 주세요";return .alertFirstButtonReturn};if let text=alert.accessoryView as? NSTextField{text.stringValue="새 방 이름"};return .alertFirstButtonReturn}
    try check(RoomDialogs.renameRoom("이전 방")=="새 방 이름" && prompts==3 && warningMatched,"AT89 empty rename retries preserving Hangul")
    model.configureHome{$0.picture="/v1/pictures/room/home-main"};ui.homePetImage=NSImage(size:CGSize(width:8,height:8))
    model.hide(c);model.toggleMute(c);ui.changeHomeChannel(c);await settle()
    try check(!model.hidden.contains(c) && !model.muted.contains(c) && !ui.sidebarRows.contains{$0.id==c},"AT89 chosen home channel clears hidden and mute and excludes duplicate row")
    try check(model.homePicture==nil && (try cell(HomeRoom.id)).picture==nil && !ui.homeMenu().items.contains{$0.title=="사진 지우기"},"AT89 chosen channel does not borrow home photo or delete wrong resource")
    ui.changeHomeChannel(nil);model.configureHome{$0.picture=nil};ui.homePetImage=nil;await settle()
    // Search uses one complete phrase, includes thinking, and prints the speaker rather than room title.
    func post(_ text:String,speaker:String="beta",state:String?=nil) throws ->ConversationMessage {
        seq+=1;let id=UUID().uuidString.lowercased(),frame:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":speaker,"room":a,"thread":UUID().uuidString.lowercased(),"role":"employee","text":text,"files":[],"buttons":[],"reply_state":state as Any? ?? NSNull(),"ts":ISO8601DateFormatter().string(from:Date(timeIntervalSince1970:1794000000+Double(seq)))];try store.append(frame);controller.receive(frame);return model.messages[id]!
    }
    let message=try post("두 낱말 한 구절"),thought=try post("생각 중…")
    let lookup=Dictionary(uniqueKeysWithValues:zip(ids,names))
    try check(WorkspaceSearch.sidebar("두 구절",messages:[message],names:lookup,hidden:[]).isEmpty && WorkspaceSearch.sidebar("생각 중",messages:[thought],names:lookup,hidden:[]).count==1,"AT89 sidebar phrase and thinking match original hits")
    ui.employeeSearch.stringValue="두 낱말";await settle()
    let hitIndex=try homeRequire(ui.sidebarRows.firstIndex{$0.kind == .hit},"AT89 inline message hit"),hit=try homeRequire(ui.employeeTable.view(atColumn:0,row:hitIndex,makeIfNecessary:true) as? SidebarHitCell,"AT89 hit cell")
    try check(hit.speaker.stringValue=="직원 B" && hit.room.stringValue=="첫 방" && hit.body.font?.pointSize==11 && hit.body.maximumNumberOfLines==2,"AT89 hit speaker and room separated")
    try check(SidebarHitCell.height("짧은 글",query:"글",width:212)<SidebarHitCell.height(String(repeating:"긴 글 ",count:18),query:"글",width:212),"AT89 one-line and two-line hit heights follow content")
    try check(hit.body.attributedStringValue.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor == .black,"AT89 highlight stays black on yellow")
    try check(!ui.sidebarRows.contains{$0.kind == .section} && ui.employeeTable.numberOfRows==ui.sidebarRows.count,"AT89 hits share list and replace add button")
    ui.employeeSearch.stringValue="";await settle()
    ui.setSidebarWidth(68);await settle();try check((try cell("section:2")).heading.fontSize==13 && (try rail("section:2")).path!.boundingBox.minX==2,"AT89 compact header and continuous rail")
    if let outputDirectory {
        try check(controller.canSend,"AT89 captures stay connected")
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        // Static source-state fixture for all three badges and pin/mute, keeping the real connection active.
        model.noticeClock={Date(timeIntervalSince1970:1794000100)}
        let waiting=try post("승인해줘",state:"asked");model.setVisible(false)
        model.pin(a,slot:3);model.toggleMute(a);ui.chooseEmployee(b);model.setVisible(false)
        for (style,appearance) in [("light",NSAppearance.Name.aqua),("dark",.darkAqua)] {
            NSApp.appearance=NSAppearance(named:appearance);window.appearance=NSAppearance(named:appearance);window.backgroundColor=style=="light" ? .white:NSColor(white:0.12,alpha:1)
            for width:CGFloat in [212,68] {
                window.effectiveAppearance.performAsCurrentDrawingAppearance {ui.setSidebarWidth(width);ui.refresh();ui.layoutSubtreeIfNeeded();ui.needsDisplay=true;ui.displayIfNeeded()};await pause(0.1)
                let rect=CGRect(x:0,y:44,width:width,height:766),rep=try homeRequire(ui.bitmapImageRepForCachingDisplay(in:rect),"AT89 capture bitmap")
                window.effectiveAppearance.performAsCurrentDrawingAppearance {ui.cacheDisplay(in:rect,to:rep)}
                let opaque=NSImage(size:rect.size);opaque.lockFocus();window.backgroundColor.setFill();CGRect(origin:.zero,size:rect.size).fill();NSImage(data:rep.representation(using:.png,properties:[:])!)!.draw(in:CGRect(origin:.zero,size:rect.size),from:.zero,operation:.sourceOver,fraction:1);opaque.unlockFocus()
                let flattened=try homeRequire(NSBitmapImageRep(data:opaque.tiffRepresentation!),"AT89 opaque bitmap")
                try check(flattened.colorAt(x:0,y:0)?.alphaComponent==1,"AT89 capture has explicit background")
                let state:[[String:Any]]=ui.sidebarRows.map {row in
                    ["id":row.id,"name":row.name,"kind":String(describing:row.kind),"open":row.open,"items":row.items.count,"itemIDs":row.items.map(\.id),"faces":row.items.flatMap(\.members).map(model.name),"unread":row.unread,"questions":row.questions,"alerts":row.alerts,"muted":model.muted.contains(row.id),"pinned":model.pinned.contains(row.id),"chosen":row.id==model.selectionIdentity,"direct":row.items.first?.kind == .direct]
                }
                try JSONSerialization.data(withJSONObject:state,options:[.sortedKeys,.prettyPrinted]).write(to:outputDirectory.appendingPathComponent("state-\(Int(width)).json"))
                try flattened.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task38-hejo-\(style)-\(Int(width)).png"))
            }
        }
        _=waiting
    }
    print("AT-HF-89 APP PASS")
}
