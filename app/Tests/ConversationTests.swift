import AppKit

private let threadA = "11111111-1111-4111-8111-111111111111"
private let threadB = "22222222-2222-4222-8222-222222222222"
private let messageA = "33333333-3333-4333-8333-333333333333"
private let buttonA = "44444444-4444-4444-8444-444444444444"
private func roster() -> [String:Any] { ["v":1,"type":"roster","ref":"fixture","employees":[["id":"alpha","name":"Alpha","aliases":[],"avatar":NSNull()],["id":"beta","name":"Beta","aliases":[],"avatar":NSNull()]]] }
private func message(_ seq: Int, id: String = messageA, employee: String = "alpha", thread: String = threadA, role: String = "employee", text: String = "**first** answer") -> [String:Any] {
    ["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":thread,"role":role,"text":text,"files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-01T00:00:00Z"]
}
@MainActor func conversationUnitTests(resourceDirectory: URL) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let store = try LocalStore(directory:directory), model = try ConversationModel(store:store)
    try model.apply(roster())
    try check(model.rooms == [Room(employee:Employee(id:"alpha",name:"Alpha",aliases:[])),Room(employee:Employee(id:"beta",name:"Beta",aliases:[]))] && model.rooms.allSatisfy { $0.kind == .direct && $0.members == [$0.id] },"roster maps to direct Room identity/title/members without a second source")
    let key = ConversationKey(employee:"alpha",thread:threadA)
    func commit(_ frame:[String:Any]) throws { try store.append(frame); try model.apply(frame) }
    try commit(message(1)); try model.apply(message(1))
    try check(model.messages.count == 1 && model.applied == 1 && model.unread(employee:"alpha") == 1,"model duplicate is ignored; closed thread unread")
    do { try model.apply(message(3)); throw TestFailure.assertion("model accepted gap") } catch GateFailure.protocolError { }
    try check(model.applied == 1,"gap never advances projection")
    model.select(key); model.setVisible(true)
    try check(model.unread(employee:"alpha") == 0 && model.memberState.read("thread:alpha/" + threadA) == 1,"opening thread persists read seq")
    model.setVisible(false)
    try commit(["v":1,"type":"edit","seq":2,"msg_id":messageA,"text":"streaming answer","final":false,"buttons":[["id":buttonA,"label":"Continue","kind":"reply","style":"primary"]]])
    try check(model.messages[messageA]?.streaming == true && model.messages.count == 1 && model.unread(key) == 1,"streaming updates same message and unread")
    try commit(["v":1,"type":"state","seq":3,"msg_id":messageA,"reply_state":"closed"])
    let post=model.messages[messageA]!, click=try ConversationModel.click(message:post,button:post.buttons[0])
    try check(click["type"] as? String == "click" && click["msg_id"] as? String == messageA && click["button_id"] as? String == buttonA && click["employee"] == nil,"button uses only server-issued message/button identifiers")
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":threadA,"on":true,"ttl_seconds":6],now:Date(timeIntervalSince1970:1000))
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":threadB,"on":true,"ttl_seconds":6],now:Date(timeIntervalSince1970:1004))
    model.expireTyping(now:Date(timeIntervalSince1970:1007))
    try check(model.typing.count == 1 && model.typing[key] == nil,"typing ttl is per thread and expires without refresh")
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":threadB,"on":false])
    try check(model.typing.isEmpty,"typing off clears exact thread")
    try commit(message(4,id:"55555555-5555-4555-8555-555555555555",employee:"beta",thread:threadB,text:"other employee"))
    model.setVisible(true); model.select(key)
    try check(model.unread(employee:"alpha") == 0 && model.unread(employee:"beta") == 1,"read state is isolated by employee/thread")
    try check(model.unread(room:model.rooms[1]) == 1 && model.threads(room:model.rooms[1]).first?.key.employee == "beta","room unread and card list route to its one employee")
    try check(model.threads(employee:"beta",query:"OTHER").count == 1 && model.threads(employee:"alpha",query:"missing").isEmpty,"thread search examines retained text")
    let rebuilt=try ConversationModel(store:try LocalStore(directory:directory))
    try check(rebuilt.applied == 4 && rebuilt.messages == model.messages && rebuilt.unread(employee:"beta") == 1,"projection and unread survive cache replay/restart")
    try commit(["v":1,"type":"delete","seq":5,"msg_id":messageA])
    try check(model.messages[messageA] == nil,"delete removes message")
    let controller=try ConversationController(client:GateClient(store:store))
    try controller.model.apply(roster()); controller.model.select(employee:"beta")
    let ui=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
    try check(ui.brand.stringValue == "HEJO." && ui.brand.alignment == .center,"AT52 uppercase centered logo")
    let logo=ui.brand.attributedStringValue
    try check((logo.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor) == .systemBlue &&
              (1..<logo.length).allSatisfy { (logo.attribute(.foregroundColor,at:$0,effectiveRange:nil) as? NSColor) == .labelColor },"AT52 only H is systemBlue")
    try check((logo.attribute(.font,at:0,effectiveRange:nil) as? NSFont) == .systemFont(ofSize:14,weight:.semibold),"AT52 14 semibold")
    try check(ui.version.stringValue == (Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") && ui.version.font?.pointSize == 10,"AT52 bundle version unchanged at 10pt")
    let emptyUI=ConversationView(controller:try ConversationController(client:GateClient(store:try LocalStore(directory:directory.appendingPathComponent("empty")))),clipboardArea:directory.appendingPathComponent("empty-clipboard"))
    try check(emptyUI.heading.stringValue == "HEJO.","AT52 empty-room heading")
    print("AT-HF-52 PASS")
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    pet.reducedMotion={true}; pet.pet.installConversation(ui); pet.preferredChatSize=CGSize(width:428,height:500)
    pet.onExpansionChanged={ controller.model.setVisible($0) }; pet.showChat(); pet.pet.layoutSubtreeIfNeeded()
    try check(ui.employeeTable.numberOfRows == 2 && ui.threadTable.numberOfRows == 1,"reviewed workspace renders employee tabs and thread cards")
    try check(!pet.panel.isKeyWindow,"installing populated conversation does not take key focus")
    try check(ui.sidebarWidth == 68 && ui.employeeTable.rowHeight == 72 && ui.headerDrag.frame.height == 44,"source strip and workspace header metrics")
    var resized:CGFloat=0; ui.onSidebarWidth={resized += $0}
    ui.setSidebarWidth(210); ui.layoutSubtreeIfNeeded()
    try check(ui.sidebarWidth == 210 && ui.employeeTable.rowHeight == 58 && resized == 142,"drag changes tabs into source list geometry")
    ui.setSidebarWidth(10); try check(ui.sidebarWidth == 0,"drag hides employee strip below 34")
    ui.toggleSidebar(); try check(ui.sidebarWidth == 68,"header restores hidden tab strip")
    try check(ConversationSidebar.snapped(150) == 180 && ConversationSidebar.snapped(400) == 300,"source list range clamps to 180 through 300")
    let beta=ConversationKey(employee:"beta",thread:threadB)
    for seq in 6...9 { controller.receive(message(seq,id:UUID().uuidString.lowercased(),employee:"beta",thread:threadB,role:seq == 9 ? "owner" : "employee",text:"reply \(seq)")) }
    let extra=ConversationKey(employee:"beta",thread:UUID().uuidString.lowercased())
    controller.receive(message(10,id:UUID().uuidString.lowercased(),employee:"beta",thread:extra.thread,text:"another thread"))
    ui.refresh()
    try check(ui.history.contents.count == 2 && ui.history.contents.allSatisfy { !$0.expanded },"threads enter folded in the same list")
    ui.chooseThread(beta)
    try check(ui.history.contents.filter(\.expanded).count == 1 && ui.replyMode,"click opens one card and targets reply")
    ui.chooseThread(extra)
    try check(ui.history.contents.filter(\.expanded).count == 1 && ui.history.contents.first(where:{$0.expanded})?.id == extra.thread,"opening another card folds the former")
    ui.foldAll()
    try check(ui.history.contents.allSatisfy { !$0.expanded } && !ui.replyMode,"blank click folds cards and switches to new post")
    let draftKey=controller.model.selected!; controller.setText("new post draft"); ui.writeReply(); ui.createThread()
    try check(controller.model.selected == draftKey && controller.draft.text == "new post draft","mode switch preserves independent new-post draft")
    ui.chooseThread(beta); ui.chooseThread(beta)
    let folded=ui.history.contents.first(where:{$0.id == beta.thread})!
    try check(folded.replies?.contains { if case .stack = $0 { return true }; return false } == true,"long thread shows source folded reply stack")
    controller.receive(message(11,id:UUID().uuidString.lowercased(),employee:"alpha",thread:threadA,text:"unread while elsewhere"))
    ui.onUnread={pet.pet.unreadCount=$0}; ui.refresh(); pet.collapseChat()
    try check(pet.pet.unreadCount>0 && !pet.pet.unreadBadge.isHidden,"closed pet shows unread blue badge")
    pet.showChat(); try check(pet.pet.unreadBadge.isHidden,"expanded pet hides separate unread badge")
    ui.onSidebarWidth=nil; ui.chooseEmployee("beta"); ui.chooseThread(beta); ui.layoutSubtreeIfNeeded()
    await pause(0.25); ui.layoutSubtreeIfNeeded(); ui.history.layoutSubtreeIfNeeded()
    for (row,layout) in ui.history.layouts.enumerated() {
        guard let cell=ui.history.table.view(atColumn:0,row:row,makeIfNecessary:true) else { throw TestFailure.assertion("card cell was not realized") }
        let drawn=cell.convert(CGRect(x:12,y:0,width:layout.width,height:layout.height),to:ui.history.contentView)
        let viewport=ui.history.contentView.bounds
        try check(abs(drawn.minX-viewport.minX-12)<=1 && abs(viewport.maxX-drawn.maxX-12)<=1,"native table keeps both visible 12pt card margins without clipping")
    }
    let screenshot=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/task06-cards-automatic.png")
    if let image=pet.pet.bitmapImageRepForCachingDisplay(in:pet.pet.bounds) {
        pet.pet.cacheDisplay(in:pet.pet.bounds,to:image)
        try image.representation(using:.png,properties:[:])!.write(to:screenshot)
    }
    print("CONVERSATION_DDOTS_LAYOUT_PASS")

    let decoded=MessageFormat.renderNative("**bold**\n- item\n`code`")
    try check(decoded.string.contains("bold") && !decoded.string.contains("**"),"native formatting parses markup")
    controller.setText("draft"); ui.refresh(); pet.panel.makeKey(); pet.panel.makeFirstResponder(ui.editor.editor)
    let shiftReturn = NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.shift],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36)!
    ui.editor.editor.keyDown(with:shiftReturn)
    try check(ui.editor.editor.string.contains("\n"),"native line-break command keeps newline")
    let original=controller.model.selected!; controller.model.newThread()
    try check(controller.model.selected?.thread != original.thread && UUID(uuidString:controller.model.selected!.thread) != nil,"new thread is a distinct client UUID")
    pet.panel.orderOut(nil)
    try FileManager.default.removeItem(at:store.cacheURL)
    let empty=try LocalStore(directory:directory)
    try check(empty.settings.applied == 0 && (try ConversationModel(store:empty)).messages.isEmpty,"cache deletion requests full replay")
    print("CONVERSATION_MODEL_UI_PASS")
}
@MainActor func conversationNetwork(_ args:[String]) async throws {
    let directory=URL(fileURLWithPath:args[2]), store=try LocalStore(directory:directory), client=GateClient(store:store)
    let controller=try ConversationController(client:client)
    try client.pair(address:args[3],code:"test_code-12",device:"test-device")
    print("CONVERSATION_STAGE replay"); fflush(stdout)
    try await waitFor { controller.canSend && controller.model.applied == 3 }
    let key=ConversationKey(employee:"alpha",thread:threadA)
    try check(controller.model.unread(key) == 1,"real socket replay applies message/edit/state once")
    controller.model.select(key); controller.model.setVisible(true)
    let ui=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
    var uploadProgress:[IslandUpload]=[]
    let redraw=controller.onChange
    controller.onChange={ if let progress=controller.uploads[key] { uploadProgress.append(progress) };redraw?() }
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:URL(fileURLWithPath:args[4])))
    pet.reducedMotion={true}; pet.pet.installConversation(ui); pet.preferredChatSize=CGSize(width:428,height:500)
    pet.onExpansionChanged={controller.model.setVisible($0)}; pet.showChat()
    let post=controller.model.messages[messageA]!
    print("CONVERSATION_STAGE click"); fflush(stdout)
    await controller.click(post.buttons[0],message:post)
    try await waitFor { controller.model.messages[messageA]?.replyState == "closed" }
    let original=directory.appendingPathComponent("note.txt"); try Data("fixture attachment".utf8).write(to:original)
    controller.addAttachments([original]); controller.setText("reject attachment"); print("CONVERSATION_STAGE unknown_file"); fflush(stdout)
    await controller.sendCurrent()
    try await waitFor { controller.transferFailure?.message.contains("첨부를 찾지") == true }
    try check(controller.draft.text == "reject attachment" && controller.draft.attachments == [original],"unknown_file keeps original draft and attachment")
    controller.setText("normal request"); print("CONVERSATION_STAGE send"); fflush(stdout)
    let sending=Task { await controller.sendCurrent(for:key) }
    await pause(0.05); controller.model.select(employee:"beta")
    await sending.value
    try await waitFor { controller.drafts[key]?.text.isEmpty == true }
    try check(controller.model.selected?.employee == "beta","upload completion preserves current worker selection")
    try check(uploadProgress.contains(IslandUpload(completed:0,total:1)) && uploadProgress.contains(IslandUpload(completed:1,total:1)) && controller.uploads.isEmpty,"AT55 real upload reports progress and clears it")
    try check(controller.transferFailure == nil,"AT55 successful acknowledgement clears transfer failure")
    controller.model.select(key); ui.chooseThread(key)
    guard let sent=controller.model.timeline(key).first(where:{$0.role == "owner"}), let file=sent.files.first else { throw TestFailure.assertion("owner attachment acknowledgement missing") }
    try await waitFor { controller.model.unread(employee:"beta") == 1 }
    await pause(0.15); ui.layoutSubtreeIfNeeded()
    let bitmap=pet.pet.bitmapImageRepForCachingDisplay(in:pet.pet.bounds)!
    pet.pet.cacheDisplay(in:pet.pet.bounds,to:bitmap)
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:args[5]))
    print("CONVERSATION_AUTOMATIC_CAPTURE_OK"); fflush(stdout)
    var opened:URL?
    controller.onOpenFile={opened=$0}
    await controller.open(file,employee:"alpha")
    try check(opened != nil && (try Data(contentsOf:opened!)) == Data("fixture attachment".utf8),"download passes original bytes to open callback")
    opened=nil; await controller.open(file,employee:"beta")
    try check(opened == nil && controller.transferFailure != nil,"foreign employee download never opens a file")
    controller.setText(String(repeating:"한",count:30_000)); await controller.sendCurrent()
    try check(controller.transferFailure?.message.contains("너무 큼") == true,"composer blocks 64KiB text before socket send")
    controller.setText("too large reply"); print("CONVERSATION_STAGE too_large"); fflush(stdout); await controller.sendCurrent()
    try await waitFor { controller.transferFailure?.message.contains("너무 큼") == true && !controller.sending }
    try check(controller.draft.text == "too large reply","too_large keeps draft")
    try check(client.isConnected,"recoverable too_large keeps live transport")
    controller.setText("normal request again"); await controller.sendCurrent()
    try await waitFor { controller.draft.text.isEmpty && !controller.sending }
    let redirect=MessageFile(fileID:"77777777-7777-4777-8777-777777777777",name:"redirect.txt",mime:"text/plain",size:0)
    opened=nil; await controller.open(redirect,employee:"alpha")
    try check(opened == nil,"HTTP redirects cannot carry credentials or open unverified files")
    controller.setText("disconnect unacknowledged"); await controller.sendCurrent()
    try await waitFor { controller.canSend && controller.transferFailure?.message.contains("전송 확인") == true }
    try check(!controller.sending && controller.draft.text == "disconnect unacknowledged","unconfirmed send survives reconnect without automatic resend")
    try check(controller.transferFailure?.retryKey == key,"AT55 reconnect retains original retry destination")
    controller.setText("normal retry",for:key)
    controller.model.select(employee:"beta")
    ui.activateIsland(.retry(key))
    try await waitFor { controller.drafts[key]?.text.isEmpty == true && !controller.sending }
    try check(controller.transferFailure == nil && controller.model.selected?.employee == "beta" && controller.notice.isEmpty,"AT55 island retry sends saved key and clears failure only on success")
    pet.panel.orderOut(nil); client.stop(); print("AT-HF-55 NETWORK PASS"); print("CONVERSATION_NETWORK_PASS")
}
