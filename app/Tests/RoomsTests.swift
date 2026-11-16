import AppKit

/// AT70/71/80: room state shares durable seq/cache, group identity differs from the speaker.
@MainActor func roomsTests(resourceDirectory:URL,outputDirectory:URL?=nil) async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory),controller=try ConversationController(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":["first"]],["id":"beta","name":"직원 B","aliases":["second"]],["id":"gamma","name":"직원 C","aliases":["outside"]]]])
    try await controller.client.receive(["v":1,"type":"welcome","device_id":"fake-device","gate_version":"test","head_seq":0,"employees":try JSONSerialization.jsonObject(with:JSONEncoder().encode(model.employees)),"rooms":[]])
    try await controller.client.receive(["v":1,"type":"sync_done","ref":"hello","through":0,"more":false,"head_seq":0])
    let room="11111111-1111-4111-8111-111111111111",thread="22222222-2222-4222-8222-222222222222"
    func apply(_ row:[String:Any])throws {let frame=row.merging(["v":1,"seq":store.settings.applied+1]){$1};try store.append(frame);controller.receive(frame)}
    let data:[String:Any]=["id":room,"title":"시험 방","description":"함께 확인","members":["alpha","beta"],"lead":"beta","picture":NSNull(),"archived":false]
    try apply(["type":"room","room":data]);let key=ConversationKey(employee:room,thread:thread)
    try apply(["type":"message","msg_id":"owner-one","employee":"beta","room":room,"thread":thread,"role":"owner","text":"첫 질문","files":[],"buttons":[],"ts":"2026-01-01T00:00:00Z"])
    try apply(["type":"message","msg_id":"answer-one","employee":"alpha","room":room,"thread":thread,"role":"employee","text":"첫 답","files":[],"buttons":[],"reply_state":"asked","ts":"2026-01-02T00:00:00Z"])
    try apply(["type":"edit","room":room,"msg_id":"answer-one","text":"편집한 답","final":true])
    try apply(["type":"state","room":room,"msg_id":"answer-one","reply_state":"answered"])
    try check(model.rooms.count==4 && model.room(for:room)?.kind == .group,"AT70 group plus direct projection")
    try check(model.messages["answer-one"]?.key==key && model.messages["answer-one"]?.speaker=="alpha","AT71 conversation scope differs from speaker")
    try check(model.sidebar.zone(room)==model.sidebar.sections[0].id && model.sidebar.items.first{$0.id==room}?.members==["alpha","beta"],"AT70 new group in first section faces")
    try check(model.header(room).title=="시험 방" && model.header(room).description=="함께 확인","AT70 canonical room title description")
    let view=ConversationView(controller:controller);view.frame=CGRect(x:0,y:0,width:850,height:620);view.chooseEmployee(room);view.refresh()
    try check(view.editor.editor.mentions==["직원 A","직원 B"],"AT71 autocomplete only room members")
    view.editor.editor.string="@직원";view.editor.editor.setSelectedRange(NSRange(location:3,length:0))
    var choice=0;let candidates=view.editor.editor.completions(forPartialWordRange:NSRange(location:0,length:3),indexOfSelectedItem:&choice)
    try check(candidates==["@직원 A","@직원 B"],"AT71 native mention suggestions")
    let group=try homeRequire(model.groups[room],"AT70 group exists"),menu=view.groupMenu(group)
    try check(menu.items.filter{!$0.isSeparatorItem}.map(\.title)==["맨 위에 고정","2번째 자리에 고정","3번째 자리에 고정","4번째 자리에 고정","5번째 자리에 고정","모두 읽음","알림 끄기","이름 바꾸기…","사진 바꾸기…","직원 추가…","대표 직원 바꾸기","목록에서 빼기","보관…","삭제…"],"AT70 group menu AC03 order")
    let (alert,picks,_,_)=RoomDialogs.dialog(people:model.employees,room:group)
    try check(alert.messageText=="#시험 방에 직원 추가" && picks.boxes.map{$0.1.isEnabled}==[false,false,true],"AT70 invite existing members dimmed")
    try check(view.memberMenu("alpha")?.items.first?.isEnabled==false,"AT70 cannot remove below two members")
    try check(RoomDialogs.deletion(group).informativeText.contains("직원이 이미 받은 내용은 직원 기억에 남을 수 있어요"),"AT70 irreversible delete warning")
    view.changeHomeChannel(nil);controller.setText("direct draft")
    view.changeHomeChannel(room);try check(controller.draft.text.isEmpty,"AT80 channel draft starts separate")
    controller.setText("channel draft");view.changeHomeChannel(nil)
    try check(controller.draft.text=="direct draft","AT80 switching restores direct home draft")
    view.changeHomeChannel(room);try check(controller.draft.text=="channel draft","AT80 switching restores channel draft")
    model.toggleHomeMember("alpha");controller.pickHome("alpha");view.refresh()
    try check(controller.draft.picks.contains("alpha") && view.editor.editor.mentions==["직원 A","직원 B"],"AT80 channel ignores direct home exclusions")
    model.configureHome{$0.muted=true};try check(model.petMuted.contains(room) && model.petMuted.contains("beta") && !model.petMuted.contains("alpha"),"AT80 home mute covers channel and included directs")
    model.configureHome{$0.muted=false}
    try check(model.homeThreads.map(\.key)==[key],"AT80 channel mode shows channel journal only")
    for (text,picked,expected) in [("질문",Optional("alpha"),"@직원 A 질문"),("",Optional("alpha"),"@직원 A"),("@직원 B 질문",Optional("alpha"),"@직원 B 질문"),("@first 질문",Optional("beta"),"@직원 A 질문"),("질문",nil,"질문"),("@outside 질문",Optional("alpha"),"@직원 C 질문"),("@직원 A @직원 B",nil,"@직원 A @직원 B")] {
        try check(model.home.channelPost(text,picked:picked)==expected,"AT80 channel post literal "+expected)
    }
    model.markAllRead(HomeRoom.id);try check(model.memberState.read("thread:"+room+"/"+thread)==5,"AT80 channel shares read key")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        model.toggleSection(model.sidebar.sections[0].id);view.chooseEmployee(room);view.refresh();view.chooseThread(key)
        let window=NSWindow(contentRect:view.frame,styleMask:[.borderless],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.backgroundColor = .white;window.contentView=view;window.orderFrontRegardless();view.layoutSubtreeIfNeeded();await pause(0.2)
        let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep);try rep.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("hejo.png"))
        window.orderOut(nil)

    }
    model.pin(room,slot:1)
    try apply(["type":"room","room":data.merging(["archived":true]){$1}]);try check(!model.sidebar.items.contains{$0.id==room} && !model.pinned.contains(room) && model.timeline(key).count==2,"AT70 archive preserves messages clears pin")
    try apply(["type":"room","room":data]);try check(model.sidebar.items.contains{$0.id==room},"AT70 restore room")
    model.pin(room,slot:1)
    let activeRecovered=try ConversationModel(store:LocalStore(directory:directory))
    try check(activeRecovered.pinned.contains(room) && activeRecovered.groups[room]?.archived==false,"AT70 history replay preserves newer active-room pin")
    try apply(["type":"room_deleted","id":room])
    try check(model.groups[room]==nil && !model.pinned.contains(room) && model.timeline(key).isEmpty && !model.sidebar.items.contains{$0.id==room},"AT70 room delete clears projection")
    let cache=try String(contentsOf:store.cacheURL);try check(!cache.contains("편집한 답") && !cache.contains("첫 질문") && !cache.contains("시험 방"),"AT70 cache body metadata redacted")
    try check(store.records.compactMap{$0["seq"] as? Int}==Array(1...8),"AT70 cache seq no gaps")
    try check(store.records[0]["room"] as? [String:Bool]==nil && (store.records[0]["room"] as? [String:Any])?["deleted"] as? Bool==true,"AT70 cached room tombstone")
    let recovered=try ConversationModel(store:LocalStore(directory:directory));try check(recovered.messages.isEmpty && recovered.groups.isEmpty && recovered.applied==8,"AT70 restart cache remains deleted")
    print("AT-HF-70/71/80 ROOMS PASS")
}

@MainActor func roomsNetwork(_ args:[String]) async throws {
    let store=try LocalStore(directory:URL(fileURLWithPath:args[2])),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client),model=controller.model,view=ConversationView(controller:controller)
    try client.pair(address:args[3],code:args[4],device:"fake room app");try await waitFor{controller.canSend}
    await controller.roomCommand("room_save",title:"함께",members:["alpha","beta"],lead:"beta");try await waitFor{model.groups.count==1}
    let room=model.groups.values.first!.id
    var expected=0
    func post(_ text:String,answers:Int,home:Bool=false,picked:String?=nil) async throws {
        if home {view.chooseHome();view.createThread();if let picked {controller.pickHome(picked)}}else{view.chooseEmployee(room);view.createThread()}
        controller.setText(text);await controller.sendCurrent(homeNew:home)
        expected += 1+answers
        try await waitFor{model.messages.count==expected}
        try check(model.selected?.employee==room,"AT80 channel wire scope")
        try check(model.typing.values.allSatisfy{$0>Date()},"AT71 current typing only")
    }
    try await post("ordinary",answers:1)
    try await post("@first single",answers:1)
    try await post("@first @second both",answers:2)
    try await post("@outside ignored",answers:1)
    model.configureHome{$0.channel=room;$0.recipient="alpha"}
    try await post("face",answers:1,home:true,picked:"alpha")
    try await post("@직원 B explicit",answers:1,home:true,picked:"alpha")
    try await post("default",answers:1,home:true)
    try await post("@first alias",answers:1,home:true)
    try await post("@outside outside",answers:1,home:true,picked:"alpha")
    try await post("@직원 A @직원 B both",answers:2,home:true)
    try await post("",answers:1,home:true,picked:"alpha")
    let original=try homeRequire(model.groups[room],"room before archive");model.pin(room,slot:1)
    await controller.roomCommand("room_archive",room:original,archived:true);try await waitFor{model.groups[room]?.archived==true}
    try check(!model.pinned.contains(room) && model.messages.count==expected,"AT70 network archive preserves")
    await controller.roomCommand("room_archive",room:model.groups[room],archived:false);try await waitFor{model.groups[room]?.archived==false}
    try check(model.selected?.employee==room,"AT70 unarchive opens room")
    await controller.roomCommand("room_delete",room:model.groups[room]);try await waitFor{model.groups.isEmpty && model.messages.isEmpty}
    try check(!String(contentsOf:store.cacheURL).contains("@first single"),"AT70 live cache redaction")
    client.stop();print("ROOMS_APP_NETWORK_PASS")
}
