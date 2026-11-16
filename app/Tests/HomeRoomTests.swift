import AppKit

func homeRequire<T>(_ value:T?,_ message:String)throws->T {guard let value else{throw TestFailure.assertion(message)};return value}

@MainActor func homeRoomTests(resourceDirectory:URL,outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),controller=try ConversationController(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":["A"]],["id":"beta","name":"직원 B","aliases":["B"]],["id":"gamma","name":"직원 C","aliases":["C"]]]])
    let ids=["11111111-1111-4111-8111-111111111111","22222222-2222-4222-8222-222222222222","33333333-3333-4333-8333-333333333333"]
    let a=ConversationKey(employee:"alpha",thread:ids[0]),b=ConversationKey(employee:"beta",thread:ids[1]),c=ConversationKey(employee:"gamma",thread:ids[2])
    for (i,entry) in [(a,"owner","첫 요청"),(b,"owner","둘째 요청"),(c,"employee","셋째 답"),(a,"employee","첫 요청의 최신 답")].enumerated(){controller.receive(["v":1,"type":"message","seq":i+1,"msg_id":UUID().uuidString.lowercased(),"employee":entry.0.employee,"thread":entry.0.thread,"role":entry.1,"text":entry.2,"files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-0\(i+1)T00:00:00Z"])}
    let view=ConversationView(controller:controller);view.frame=CGRect(x:0,y:0,width:850,height:620);view.homePetImage=try SpriteAtlas(resourceDirectory:resourceDirectory).image(row:0,frame:0)
    view.chooseHome();view.refresh();view.layoutSubtreeIfNeeded()
    try check(model.isHome && model.selected?.employee=="@home" && view.sidebarRows.first?.kind == .home && view.sidebarRows.first?.name==store.settings.petName,"AT80 home is first pet-named view")
    controller.pickHome("alpha");let emptyPlace=model.selected;await controller.sendCurrent()
    try check(model.selected==emptyPlace && model.selected?.employee=="@home" && controller.draft.picks==Set(["alpha"]),"AT80 empty Return keeps home draft and receiver")
    controller.pickHome("alpha")
    try check(model.homeThreads.map(\.key)==[b,c,a],"AT80 source activity order places newest reply last")
    try check(model.messages.count==4 && model.employees.count==3,"AT80 home has no duplicate messages or roster entity")
    if case .employee(let id)=model.home.destination(text:"plain",picked:nil){try check(id=="alpha","AT80 initial default")}else{throw TestFailure.assertion("AT80 default missing")}
    model.configureHome{$0.recipient="beta"}
    for (text,picked,expected) in [("plain",Optional<String>.none,"beta"),("@C request",nil,"gamma"),("@직원 B request","alpha","alpha")] {
        if case .employee(let id)=model.home.destination(text:text,picked:picked){try check(id==expected,"AT80 face mention default priority")}else{throw TestFailure.assertion("AT80 route refused")}
    }
    if case .refused(let reason)=model.home.destination(text:"@A @B",picked:nil){try check(reason=="홈에서는 한 명에게 보내요. 여럿은 단체방에서 불러 주세요","AT80 multi mention exact refusal")}else{throw TestFailure.assertion("AT80 multi mention allowed")}
    model.toggleHomeMember("gamma")
    if case .refused(let reason)=model.home.destination(text:"@C",picked:nil){try check(reason=="직원 C은 홈에 없어요","AT80 absent exact refusal")}else{throw TestFailure.assertion("AT80 absent allowed")}
    if case .refused(let reason)=model.home.destination(text:"draft",picked:"gamma"){try check(reason=="직원 C은 홈에 없어요","AT80 removed explicit face refuses instead of fallback")}else{throw TestFailure.assertion("AT80 removed face rerouted")}
    try check(model.homeThreads.map(\.key)==[b,a] && model.employees.count==3,"AT80 removing member filters view only")
    view.chooseHome();controller.pickHome("alpha");view.refresh()
    let faces=try homeRequire(view.subviews.compactMap{$0 as? ComposerFaces}.first,"AT80 native faces")
    try check(faces.lit==0 && faces.ring,"AT80 selected face bright with ring")
    controller.pickHome("alpha");view.refresh();try check(faces.lit==nil && !faces.ring,"AT80 same face releases selection")
    controller.setText("@B text");view.refresh();try check(faces.lit==1 && !faces.ring,"AT80 mention previews without selection ring")
    model.setVisible(true);view.chooseThread(a)
    try check(model.isHome && model.selected==a && model.unread(a)==0 && model.memberState.read("thread:alpha/"+a.thread)==4,"AT80 home reply shares direct thread read key")
    view.chooseEmployee("alpha");try check(!model.isHome && model.unread(a)==0,"AT80 direct view shares home read")
    model.configureHome{$0.muted=true}
    try check(model.petMuted==Set(["alpha","beta"]) && controller.islandInput.muted==Set(["alpha","beta"]) && model.visibleUnreadTotal==1,"AT80 muted home quiets only included direct rooms without double badge")
    model.configureHome{$0.muted=false};try check(model.petMuted.isEmpty,"AT80 home alerts restore")
    view.chooseHome();let menu=view.homeMenu()
    try check(menu.items.filter{!$0.isSeparatorItem}.map(\.title)==["사진 바꾸기…","홈에 보일 직원","기본 받을 직원","알림 끄기"],"AT80 home native menu order")
    try check(menu.items.first{$0.title=="홈에 보일 직원"}?.submenu?.items.map(\.state)==[.on,.on,.off],"AT80 membership checkmarks")
    let reopened=try ConversationModel(store:LocalStore(directory:home));try reopened.apply(["type":"roster","employees":try JSONSerialization.jsonObject(with:JSONEncoder().encode(model.employees))]);try check(reopened.home.members.map(\.id)==["alpha","beta"] && reopened.home.defaultRecipient=="beta","AT80 home settings restore through member state")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        model.toggleHomeMember("gamma");controller.setText("@직원 B 다음 요청");view.refresh()
        let window=NSWindow(contentRect:view.frame,styleMask:[.borderless],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.backgroundColor = .white;view.layer?.backgroundColor=NSColor.white.cgColor;window.contentView=view;window.orderFrontRegardless();view.layoutSubtreeIfNeeded();await pause(0.2)
        let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep);try rep.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task27-hejo.png"))
        let faces=try homeRequire(view.subviews.compactMap{$0 as? ComposerFaces}.first,"AT80 capture faces");let image=faces.bitmapImageRepForCachingDisplay(in:CGRect(x:0,y:0,width:102,height:32))!;faces.cacheDisplay(in:CGRect(x:0,y:0,width:102,height:32),to:image);try image.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task27-hejo-faces.png"));window.orderOut(nil)
    }
    print("AT-HF-80 PASS")
}

@MainActor func homeRoomNetwork(_ args:[String]) async throws {
    let store=try LocalStore(directory:URL(fileURLWithPath:args[2])),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client),model=controller.model
    let view=ConversationView(controller:controller)
    try client.pair(address:args[3],code:"test_code-12",device:"fake home");try await waitFor{controller.canSend}
    view.chooseHome();controller.setText("default");await controller.sendCurrent();try await waitFor{model.messages.count==1}
    let first=try homeRequire(model.threads(employee:"alpha").first?.key,"AT80 first direct thread")
    try check(model.isHome && model.timeline(first).count==1 && !view.replyMode,"AT80 new mode remains after first post confirmation")
    controller.setText("second @B");view.refresh();view.editor.editor.onSubmit?();try await waitFor{model.messages.count==4}
    try check(model.timeline(first).count==2 && model.threads(employee:"beta").count==1,"AT80 consecutive home new posts create separate recipient threads")
    view.createThread();controller.pickHome("alpha");controller.setText("face @B");await controller.sendCurrent();try await waitFor{model.messages.count==6}
    view.createThread();controller.setText("@C mention");await controller.sendCurrent();try await waitFor{model.messages.count==8}
    model.configureHome{$0.recipient="beta"};view.createThread();controller.setText("configured");await controller.sendCurrent();try await waitFor{model.messages.count==10}
    view.createThread();controller.setText("@A @B");await controller.sendCurrent();try check(controller.notice==HomeRoom.multiple && controller.draft.text=="@A @B","AT80 rejected multi keeps draft")
    model.toggleHomeMember("gamma");controller.setText("@C absent");await controller.sendCurrent();try check(controller.notice=="직원 C은 홈에 없어요" && controller.draft.text=="@C absent","AT80 absent refusal keeps draft")
    view.chooseThread(first);controller.setText("reply");await controller.sendCurrent();try await waitFor{model.messages.count==12}
    await pause(0.2);try check(model.isHome && model.timeline(first).count==4,"AT80 home reply uses original thread")
    let image=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1,pixelsHigh:1,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4,bitsPerPixel:32)!
    image.setColor(NSColor(srgbRed:0.2,green:0.4,blue:0.7,alpha:1),atX:0,y:0);let url=URL(fileURLWithPath:args[2]).appendingPathComponent("home-test.png")
    try image.representation(using:.png,properties:[:])!.write(to:url)
    let picture=await controller.changePicture(kind:"room",id:HomeRoom.pictureID,url:url)
    try check(picture?.hasPrefix("/v1/pictures/room/home-main")==true,"AT80 home picture uses existing authenticated path")
    model.configureHome{$0.picture=picture};await view.clearHomePicture();try check(model.home.settings.picture==picture && controller.notice=="사진을 지우지 못했어요. 다시 시도해 주세요.","AT80 failed photo delete preserves layout address");await view.clearHomePicture();try check(model.home.settings.picture==nil,"AT80 home picture deletion clears shared layout address")
    client.stop();print("AT-HF-80 HOME NETWORK PASS")
}
