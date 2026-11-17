import AppKit

@MainActor func bubbleReplyTests(resourceDirectory:URL,outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),controller=try ConversationController(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[],"queued":true],["id":"beta","name":"직원 B","aliases":[]]]])
    let a=ConversationKey(employee:"alpha",thread:UUID().uuidString.lowercased()),b=ConversationKey(employee:"beta",thread:UUID().uuidString.lowercased())
    for (i,key) in [a,b].enumerated(){controller.receive(["v":1,"type":"message","seq":i+1,"msg_id":UUID().uuidString.lowercased(),"employee":key.employee,"thread":key.thread,"role":"employee","text":"대상 글","files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-01T00:00:00Z"])}
    try check(controller.model.employees[0].queued==true && controller.model.employees[1].queued==nil,"AT82 optional queued old roster compatibility")
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory)),card=BubbleReplyCard(controller:controller)
    pet.reducedMotion={true};pet.pet.installBubbleReply(card);pet.pet.bubbleAlwaysShown=true;pet.pet.bubbleReplyConnected=true
    pet.pet.pointerLocation={CGPoint(x:-5000,y:-5000)}
    var time:TimeInterval=0;card.now={time}
    let target=BubbleReplyTarget(key:a,speaker:"직원 A",working:false,queued:false)
    card.aim(target);pet.pet.bubbleNotice=BubbleReveal.Notice(kind:.reply,headline:"직원 A · 새 메시지",detail:"대상 글",key:a,sender:"직원 A")
    pet.show();pet.pet.updateBubbleReply(pointerOver:true)
    try check(!card.visible && !pet.panel.canBecomeKey,"AT82 hover does not take keyboard before dwell")
    time=0.29;pet.pet.updateBubbleReply(pointerOver:true);try check(!card.visible,"AT82 dwell below 0.3")
    time=0.3;pet.pet.updateBubbleReply(pointerOver:true)
    try check(card.visible && pet.panel.canBecomeKey && !pet.panel.isKeyWindow,"AT82 opens at 0.3 without stealing key focus")
    try check(card.prompt.stringValue=="직원 A에게 답하기…" && card.input.editor.accessibilityLabel()=="말풍선 답하기" && card.send.accessibilityLabel()=="보내기","AT82 prompt and accessibility")
    card.aim(.init(key:a,speaker:"직원 A",working:true,queued:false));try check(card.prompt.stringValue=="직원 A에게 끼어들기…","AT82 steering prompt")
    card.aim(.init(key:a,speaker:"직원 A",working:true,queued:true));try check(card.prompt.stringValue=="답이 끝나면 이어서 읽어요","AT82 queue prompt")
    time=1;pet.pet.updateBubbleReply(pointerOver:false);time=1.59;pet.pet.updateBubbleReply(pointerOver:false);try check(card.visible,"AT82 empty field stays before fold deadline")
    time=1.6;pet.pet.updateBubbleReply(pointerOver:false);try check(!card.visible,"AT82 folds after 0.6")
    for index in 0..<5 {
        var surroundings=BubbleReply.Surroundings()
        switch index{case 0:surroundings.enabled=false;case 1:surroundings.connected=false;case 2:surroundings.paused=true;case 3:surroundings.chatExpanded=true;default:surroundings.hasTarget=false}
        card.update(surroundings,pointerOver:false);card.update(surroundings,pointerOver:true);time+=1;card.update(surroundings,pointerOver:true)
        try check(!card.visible,"AT82 required gate \(index)")
    }
    card.update(.init(),pointerOver:false);card.openNow()
    card.input.editor.string="첫 초안";card.textDidChange(Notification(name:NSText.didChangeNotification));card.aim(.init(key:b,speaker:"직원 B",working:false,queued:false))
    card.input.editor.string="둘째 초안";card.textDidChange(Notification(name:NSText.didChangeNotification));card.aim(target)
    try check(card.input.editor.string=="첫 초안" && controller.draft(for:b).text=="둘째 초안","AT82 per-thread draft restoration in existing store")
    time+=10;card.update(.init(),pointerOver:false);time+=1;card.update(.init(),pointerOver:false);try check(card.visible,"AT82 nonempty draft holds input")
    card.input.editor.string="a\nb\nc\nd";card.textDidChange(Notification(name:NSText.didChangeNotification));card.layoutSubtreeIfNeeded();card.input.measure()
    let line=ceil(card.input.editor.layoutManager!.defaultLineHeight(for:.systemFont(ofSize:14)))
    try check(card.height<=28+line*3+1 && card.input.editor.string.components(separatedBy:"\n").count==4,"AT82 three visible lines scroll without deleting words (source)")
    var submissions=0;card.input.editor.onSubmit={submissions+=1}
    let enter=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36)!
    card.input.editor.keyDown(with:enter);try check(submissions==1,"AT82 Return submits")
    let shift=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[.shift],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:36)!
    card.input.editor.setSelectedRange(NSRange(location:(card.input.editor.string as NSString).length,length:0));card.input.editor.keyDown(with:shift)
    try check(submissions==1 && card.input.editor.string.hasSuffix("\n"),"AT82 Shift Return inserts newline")
    var collapsed=0;pet.panel.onCollapse={collapsed+=1};pet.panel.makeKey();try check(pet.panel.makeFirstResponder(card.input.editor),"AT82 explicit input focus")
    pet.panel.cancelOperation(nil);try check(!card.visible && collapsed==0 && !pet.panel.isKeyWindow,"AT82 Esc closes editor and releases key before conversation")
    pet.panel.cancelOperation(nil);try check(collapsed==1,"AT82 next Esc reaches normal collapse")
    let settings=PetSettingsWindow();var enabled:Bool?;settings.onBubbleReply={enabled=$0};settings.bubbleReplyCheck.state = .off;settings.bubbleReplyCheck.performClick(nil)
    try check(enabled==true && settings.bubbleReplyCheck.title=="말풍선에서 바로 답하기","AT82 native setting")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        controller.setText("확인하고 이어서 진행해 주세요",for:a);card.aim(.init(key:a,speaker:"직원 A",working:true,queued:false));pet.pet.bubbleNotice=BubbleReveal.Notice(kind:.writing,headline:"답변을 생각하고 있어요",detail:BubbleReply.interruptedSubtitle,key:a);pet.pet.updateBubbleReply(pointerOver:false);card.openNow();pet.pet.updateFoldedBubble();card.layoutSubtreeIfNeeded()
        await pause(0.1)
        let view=pet.pet.foldedBubble,rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep);try rep.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task30-hejo.png"))
        let row=card.bitmapImageRepForCachingDisplay(in:card.bounds)!;card.cacheDisplay(in:card.bounds,to:row);try row.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task30-hejo-input.png"))
    }
    pet.panel.orderOut(nil);print("AT-HF-82 PASS")
}

@MainActor func bubbleReplyNetwork(_ args:[String]) async throws {
    let home=URL(fileURLWithPath:args[2]),store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client,downloads:client.store.directory.appendingPathComponent("Downloads"))
    try client.pair(address:args[3],code:"test_code-12",device:"fake bubble")
    try await waitFor{controller.canSend && !controller.model.typing.isEmpty}
    let key=ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111")
    let file=home.appendingPathComponent("kept.txt");try Data("kept".utf8).write(to:file);controller.model.select(key);controller.addAttachments([file]);controller.setText("interrupt",for:key)
    controller.model.setVisible(false)
    try check(controller.model.unread(key)==1,"AT87 folded bubble target has a new unread post before send")
    let accepted=await controller.sendBubbleReply(key);try check(accepted,"AT82 text-only send accepted")
    try check(controller.model.unread(key)==0 && controller.model.memberState.read("thread:alpha/"+key.thread)>=1,"AT87 bubble send marks exact thread read while folded")
    try check(controller.draft(for:key).text.isEmpty && controller.draft(for:key).attachments==[file] && controller.interruptions[key] == nil,"AT88 queue bubble sends text without interruption marker")
    try await waitFor{controller.model.timeline(key).count==4 && !controller.working(key)}
    try check(controller.interruptions[key]==nil,"AT82 employee reply settles interruption")
    let card=BubbleReplyCard(controller:controller);card.aim(.init(key:key,speaker:"직원 A",working:false,queued:true));card.update(.init(),pointerOver:false);card.openNow();card.input.editor.string="reject";card.textDidChange(Notification(name:NSText.didChangeNotification));card.submit()
    try await waitFor{controller.bubbleProblems[key] != nil}
    card.aim(card.target)
    try check(card.visible && card.input.editor.string=="reject" && !card.problemLabel.stringValue.isEmpty && controller.failures.isEmpty && controller.draft(for:key).attachments==[file],"AT82 late rejection restores exact thread without duplicate failure-store draft")
    await pause(0.3);try check(controller.model.timeline(key).count==4,"AT82 no automatic resend")
    client.stop();print("AT-HF-82 BUBBLE NETWORK PASS")
}
