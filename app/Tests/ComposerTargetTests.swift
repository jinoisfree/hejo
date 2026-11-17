import AppKit

/// AT-88: source-defined destinations and draft ownership, through the real AppKit/controller path.
@MainActor func composerTargetTests() async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client,downloads:client.store.directory.appendingPathComponent("Downloads")),model=controller.model
    let roster:[[String:Any]]=[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[],"queued":true]]
    controller.receive(["type":"welcome","employees":roster,"head_seq":0]);controller.receive(["type":"sync_done","through":0,"more":false])
    var seq=0;let instant=Date(timeIntervalSince1970:1795000000)
    @discardableResult func post(_ text:String,room:String="alpha",thread:String=UUID().uuidString.lowercased(),role:String="employee",age:Double=0)throws->ConversationKey {
        seq+=1;controller.receive(["v":1,"type":"message","seq":seq,"msg_id":UUID().uuidString.lowercased(),"employee":room,"thread":thread,"role":role,"text":text,"ts":ISO8601DateFormatter().string(from:instant.addingTimeInterval(age)),"files":[],"buttons":[],"reply_state":NSNull()]);return .init(employee:room,thread:thread)
    }
    let older=try post("직원이 연 스레드",age:-200),owner=try post("사장이 연 스레드",role:"owner",age:-100)
    _=try post("다른 방 직원 글",room:"beta",age:-50)
    let ui=ConversationView(controller:controller);ui.frame=CGRect(x:0,y:0,width:820,height:720)
    ui.chooseEmployee("alpha");try check(!ui.replyMode,"AT88 owner-root latest starts a new post")
    ui.chooseEmployee("beta");try check(ui.replyMode && model.timeline(model.selected!).first?.role=="employee","AT88 employee-root latest starts a reply")
    try post("오래된 스레드에 최근 답",thread:older.thread,age:0)
    ui.chooseEmployee("alpha");try check(ui.replyMode && model.selected==older,"AT88 latest activity beats newer creation")
    controller.setText("자동 자리 초안");let auto=controller.composeKey!
    let other=try post("새 직원 시작",age:10);ui.refresh()
    try check(model.selected==other && controller.composeKey==auto && controller.draft.text=="자동 자리 초안","AT88 auto place keeps words while its default destination changes")
    ui.writeReply();try check(controller.composeKey==other && controller.draft.text=="자동 자리 초안","AT88 selecting same effective target carries auto draft")
    controller.setText("명시 답글");ui.createThread();controller.setText("새 글 초안")
    ui.chooseThread(other);try check(controller.draft.text=="명시 답글","AT88 explicit thread retains its own words")
    ui.createThread();try check(controller.draft.text=="새 글 초안","AT88 new post retains its own words")
    ui.chooseThread(other);controller.setText("삭제 전 글")
    seq+=1;controller.receive(["v":1,"type":"delete","seq":seq,"scope":"thread","msg_id":"fake-deleted-root","room":"alpha","thread":other.thread])
    try check(controller.draft.text=="삭제 전 글" && controller.composeKey != other,"AT88 deleted target draft carries to room's current place")
    ui.chooseThread(older)
    controller.receive(["type":"typing","employee":"alpha","thread":older.thread,"on":true,"ttl_seconds":6])
    ui.createThread();try check(ui.sendTarget==older && ui.composerPrompt=="직원 A에게 끼어들기…","AT88 new mode keeps open working thread as send target")
    try check(controller.canInterrupt(older),"AT88 steer writer can show interruption")
    let queued=model.threads(employee:"beta").first!.key
    controller.receive(["type":"typing","employee":"beta","thread":queued.thread,"on":true,"ttl_seconds":6])
    try check(!controller.canInterrupt(queued),"AT88 queue writer cannot show interruption")
    controller.receive(["type":"typing","employee":"alpha","thread":older.thread,"on":false])
    ui.chooseHome();try check(!ui.replyMode && ui.composerPrompt=="직원 A에게 새 글","AT88 home starts new conversation with default recipient prompt")
    controller.pickHome("beta");ui.refresh();try check(ui.composerPrompt=="직원 B에게 새 글","AT88 pressed home face prompt")
    let faces=try homeRequire(homeDescendants(ui,ComposerFaces.self).first,"AT88 faces")
    faces.layoutSubtreeIfNeeded();try check(faces.buttons.count==2 && faces.buttons[1].accessibilityLabel()=="직원 B, 받는 캐릭터","AT88 home each face is an accessible button")
    try check(faces.buttons[1].toolTip=="다시 누르면 글 내용에 따라 받는 캐릭터를 정해요" && faces.buttons[1].frame.width==32 && faces.ring,"AT88 picked face ring and release tooltip")
    faces.buttons[1].invoke?();ui.refresh();try check(controller.draft.picks.isEmpty && !faces.ring,"AT88 second face press releases explicit recipient")
    controller.pickHome("beta");ui.folded();try check(controller.draft.picks.isEmpty && model.home.defaultRecipient=="alpha","AT88 folding resets next new post to default without changing member setting")
    ui.chooseHome();ui.chooseThread(older);controller.setText("가짜 입력");ui.refresh();try check(ui.composerPrompt=="직원이 연 스레드 · 이어서 말하기","AT88 home reply uses first line preview: "+ui.composerPrompt)
    ui.chooseEmployee("alpha");ui.refresh();try check(homeDescendants(ui,ComposerFaces.self).first!.buttons.isEmpty,"AT88 direct room has no mention face")
    let group="room-test";seq+=1;controller.receive(["v":1,"type":"room","seq":seq,"room":["id":group,"title":"공동 방","members":["alpha","beta"],"lead":"alpha"]])
    ui.chooseEmployee(group);ui.refresh();ui.layoutSubtreeIfNeeded()
    let mentions=homeDescendants(ui,ComposerFaces.self).first!;mentions.layoutSubtreeIfNeeded()
    try check(mentions.buttons.count==2 && mentions.buttons[0].toolTip=="@직원 A" && mentions.buttons[0].accessibilityLabel()=="직원 A 멘션","AT88 group mention labels and tooltips")
    try check(mentions.buttons[0].frame.size==CGSize(width:32,height:32) && mentions.buttons[1].frame.minX==34,"AT88 mention 24pt face with 4pt padding and 2pt spacing")
    let modes=homeDescendants(ui,ComposerButton.self).filter{$0.mode}
    try check(modes.first{$0.chosen}?.isEnabled==false && modes.first{$0.chosen}?.accessibilityLabel()?.hasSuffix(", 선택됨")==true,"AT88 selected mode cannot be pressed and reports selection")
    let picker=ui.attachmentPicker();try check(picker.message=="보낼 사진이나 파일을 고르세요." && picker.prompt=="첨부" && picker.level == .modalPanel && picker.allowsMultipleSelection && !picker.canChooseDirectories,"AT88 chooser configuration")
    var finishPicking:((NSApplication.ModalResponse)->Void)?
    ui.chooseFiles={_,done in finishPicking=done}
    let attach=try homeRequire(homeDescendants(ui,ComposerButton.self).first{$0.title=="첨부"},"AT88 attachment action")
    attach.invoke?();try check(ui.pickingFiles && finishPicking != nil,"AT88 chooser lifecycle holds collapse guard")
    finishPicking?(.cancel);try check(!ui.pickingFiles,"AT88 chooser cancel releases collapse guard")
    let missing=home.appendingPathComponent("missing.txt")
    do{_=try GateHTTP.prepareUploads([missing]);throw TestFailure.assertion("AT88 missing accepted")}catch let error as OutgoingFileProblem{try check(error.message=="파일을 찾지 못했어요: missing.txt","AT88 missing filename")}
    try check(OutgoingFileProblem.unreadable("a.txt").message=="파일을 읽지 못했어요: a.txt" && OutgoingFileProblem.changed("b.txt").message=="보내는 사이 파일이 바뀌었어요. 다시 보내 주세요: b.txt","AT88 outgoing file source messages")
    // Default entry applies only when no unsent place was left in that room.
    ui.chooseEmployee("alpha");ui.createThread();controller.setText("");ui.chooseEmployee("beta")
    let ringing=try post("승인해줘",age:50);model.setVisible(true);ui.chooseEmployee("alpha")
    try check(ui.replyMode && model.selected==ringing && model.unread(ringing)==1,"AT88 automatic reply target does not mark a ringing request read")
    ui.chooseThread(ringing);try check(model.unread(ringing)==0,"AT88 explicit target click still marks it read")
    model.setVisible(false)
    // Allowed/current-script policy remains the source policy after dead date branches are removed.
    for (words,body,expected) in [(["승인","거절"],"",true),(["확인","되돌리기"],"",true),(["1","2","거절","의견","확인"],"",true),(["낯선 동작"],"",false),(["메모","확인"],ReplyButtonPolicy.mailLegend,true)] {
        var message=ConversationMessage(id:"policy-test",key:older,role:"employee",text:body,files:[],buttons:[],replyState:nil,seq:1,latestSeq:1,timestamp:"2026-11-15T00:00:00Z",clientMessageID:nil)
        try check(ReplyButtonPolicy.pressable(words,message:message)==expected,"N36 current policy unchanged")
        message.timestamp="2027-11-15T00:00:00Z";try check(ReplyButtonPolicy.pressable(words,message:message)==expected,"N36 current policy date independent")
    }
    try check(model.timeline(owner).first?.text=="사장이 연 스레드","AT88 draft transitions preserve journal projection")
    ui.chooseEmployee("alpha");ui.createThread();controller.setText("첫 연결 초안");let kept=controller.composeKey!
    let originalAddress=store.settings.address
    try store.select(address:"ws://other.invalid",device:"fake workspace");controller.prepareDraftAddress();controller.setText("다른 연결 초안",for:kept)
    try store.select(address:originalAddress,device:"fake workspace");controller.prepareDraftAddress()
    try check(controller.draft(for:kept).text=="첫 연결 초안","AT88 changing connection retains isolated workspace draft")
    try store.select(address:"ws://other.invalid",device:"fake workspace");controller.prepareDraftAddress()
    try check(controller.draft(for:kept).text=="다른 연결 초안","AT88 returning connection restores its own draft")
    print("AT-HF-88 APP PASS")
}

/// The socket and confirmation boundary remain real; the server controls delayed acknowledgements.
@MainActor func composerTargetNetwork(_ args:[String]) async throws {
    let home=URL(fileURLWithPath:args[2]),client=GateClient(store:try LocalStore(directory:home),credentials:MemoryCredentials()),controller=try ConversationController(client:client,downloads:client.store.directory.appendingPathComponent("Downloads"))
    defer{client.stop()}
    try client.pair(address:args[3],code:"test_code-12",device:"fake composer")
    try await waitFor{controller.canSend && controller.model.messages.count==1}
    let ui=ConversationView(controller:controller);ui.frame=CGRect(x:0,y:0,width:820,height:640);ui.chooseEmployee("alpha")
    let key=controller.model.selected!;try await waitFor{controller.model.typing[key] != nil};controller.setText("delay");ui.refresh()
    await controller.sendCurrent();ui.refresh()
    let echo=try homeRequire(controller.timeline(key).first{$0.pending},"AT88 optimistic echo exists before confirmation")
    try check(controller.draft.isEmpty && controller.model.messages.count==1 && controller.timeline(key).count==2,"AT88 echo is memory only and composer clears before ack")
    let post=try homeRequire(ui.history.contents.first{$0.id==key.thread}?.replies?.compactMap{piece ->NativeThreadCard.Post? in if case .post(let p)=piece{return p};return nil}.first,"AT88 rendered pending post")
    try check(post.pending && post.time=="보내는 중" && UserBubblePalette(dark:false,pending:post.pending).alpha==0.6,"AT88 actual pending card alpha and source time")
    let replyPieces=ui.history.contents.first{$0.id==key.thread}!.replies!
    let interruptedIndex=replyPieces.firstIndex{if case .accessory(let id,_,_)=$0{return id.hasSuffix(":interruption")};return false}
    let workIndex=replyPieces.firstIndex{if case .accessory(let id,_,_)=$0{return id.hasSuffix(":work")};return false}
    try check(interruptedIndex != nil && workIndex != nil && interruptedIndex!<workIndex!,"AT88 interruption caption is after replies and before working row")
    if case .accessory(_,_,let make)=replyPieces[interruptedIndex!] {try check(make() is NSTextField,"AT88 interruption caption uses reply left edge without owner alignment or avatar inset")}
    controller.setText("typed while pending");ui.refresh();try check(ui.editor.editor.isEditable,"AT88 typing stays available while send waits")
    try await waitFor{controller.model.timeline(key).count==2}
    try check(controller.timeline(key).filter(\.pending).isEmpty && controller.draft.text=="typed while pending","AT88 ack replaces echo without clearing subsequent input")
    let file=home.appendingPathComponent("payload.txt");try Data("kept payload".utf8).write(to:file)
    controller.setText("reject");controller.addAttachments([file]);await controller.sendCurrent()
    controller.setText("typed after rejection send")
    try await waitFor{controller.failures.count==1}
    let failed=controller.failures[0]
    try check(failed.draft.text=="reject" && failed.draft.attachments==[file] && controller.draft.text=="typed after rejection send" && controller.timeline(key).allSatisfy{!$0.pending},"AT88 late rejection keeps later draft and moves only failed attempt")
    ui.chooseEmployee("beta");controller.restoreFailure(failed.id)
    try check(controller.failures.count==1 && controller.model.selectionIdentity=="alpha","AT88 first restore click goes to original shown room")
    controller.restoreFailure(failed.id)
    try check(controller.failures.isEmpty && controller.draft.text=="reject\ntyped after rejection send" && controller.draft.attachments==[file],"AT88 second restore prepends into exact original destination")
    controller.setText("unconfirmed");await controller.sendCurrent()
    try await waitFor(12){controller.canSend && controller.failures.count==1}
    try check(controller.failures[0].draft.text=="unconfirmed" && controller.timeline(key).allSatisfy{!$0.pending},"AT88 reconnect without receipt saves unconfirmed attempt without resend")
    controller.discardFailure(controller.failures[0].id)
    ui.createThread();let newPlace=controller.composeKey!;controller.setText("new-reject");await controller.sendCurrent()
    let wire=try homeRequire(controller.includingPending(controller.model.threads(employee:"alpha"),scope:["alpha"]).first{$0.key != key},"AT88 new pending thread")
    try check(wire.key != newPlace && controller.model.selected==newPlace,"AT88 new-post draft place stays fixed while wire gets a separate UUID")
    controller.setText("next new draft");try await waitFor{controller.failures.count==1}
    controller.restoreFailure(controller.failures[0].id)
    try check(controller.draft.text=="new-reject\nnext new draft" && !ui.replyMode && controller.composeKey==newPlace,"AT88 late new-post failure merges into fixed new place without turning into reply")
    ui.chooseHome();controller.pickHome("beta");controller.setText("home-reject");await controller.sendCurrent()
    controller.setText("later home words");try await waitFor{controller.failures.count==1}
    controller.restoreFailure(controller.failures[0].id)
    try check(controller.model.isHome && !ui.replyMode && controller.draft.text=="home-reject\nlater home words" && controller.draft.picks==["beta"],"AT88 home failure restores new conversation words files and pressed face into same place")
    let changed=home.appendingPathComponent("changed.txt");try Data("two".utf8).write(to:changed)
    do{_=try await controller.files.upload(changed,employee:"alpha",expectedSize:1);throw TestFailure.assertion("AT88 changed file accepted")}
    catch let error as OutgoingFileProblem {try check(error.message=="보내는 사이 파일이 바뀌었어요. 다시 보내 주세요: changed.txt","AT88 real loader reports changed filename")}
    try check(echo.clientMessageID != nil,"AT88 echo uses actual confirmation identity")
    print("AT-HF-88 NETWORK PASS")
}
