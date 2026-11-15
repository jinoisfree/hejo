import AppKit

private let typingKey=ConversationKey(employee:"alpha",thread:"33333333-3333-4333-8333-333333333333")
private let typingRoot="00000000-0000-4000-8000-000000000101", typingAnswer="00000000-0000-4000-8000-000000000102"
private func descendants<T:NSView>(_ root:NSView,_ type:T.Type)->[T] {
    var found:[T]=[]
    for child in root.subviews { if let match=child as? T { found.append(match) }; found+=descendants(child,type) }
    return found
}
/// AT-HF-57 (REQ-HF-19): waiting shimmer with elapsed seconds, then a blinking caret while words stream.
@MainActor func typingTests(resourceDirectory:URL) async throws {
    try check(TypingRow.elapsed(12) == "12초" && TypingRow.elapsed(65) == "1분 5초" && TypingRow.elapsed(0) == "0초","AT57 elapsed wording")
    var time=Date(timeIntervalSince1970:1000), motion:TimeInterval=0, blink:TimeInterval=0, reduced=false
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer { try? FileManager.default.removeItem(at:directory) }
    let client=GateClient(store:try LocalStore(directory:directory),credentials:MemoryCredentials())
    let controller=try ConversationController(client:client)
    try await client.receive(["v":1,"type":"welcome","employees":[["id":"alpha","name":"Alpha","aliases":[],"avatar":NSNull()]]])
    controller.receive(["v":1,"type":"message","seq":1,"msg_id":typingRoot,"employee":"alpha","thread":typingKey.thread,"role":"owner","text":"Please check","files":[],"buttons":[],"ts":"2026-01-01T00:00:00Z"])
    controller.model.select(typingKey)

    let model=controller.model
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":typingKey.thread,"on":true,"ttl_seconds":6],now:time)
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":typingKey.thread,"on":true,"ttl_seconds":6],now:time.addingTimeInterval(3))
    try check(model.typingSince[typingKey] == time,"AT57 typing refresh keeps first-on time")
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":typingKey.thread,"on":false])
    try check(model.typingSince[typingKey] == nil,"AT57 typing off forgets first-on time")
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":typingKey.thread,"on":true,"ttl_seconds":6],now:time.addingTimeInterval(-1))
    model.expireTyping(now:time.addingTimeInterval(6))
    try check(model.typingSince[typingKey] == nil,"AT57 typing expiry forgets first-on time")
    try model.apply(["v":1,"type":"typing","employee":"alpha","thread":typingKey.thread,"on":true,"ttl_seconds":600],now:time)

    let ui=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{time}))
    ui.island.reduceMotion={true};ui.motionTime={motion};ui.reduceMotion={reduced}
    let pet=PetController(store:client.store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory));pet.reducedMotion={true}
    pet.preferredChatSize=CGSize(width:760,height:500);pet.pet.installConversation(ui);pet.showChat();pet.pet.layoutSubtreeIfNeeded()
    ui.refresh();ui.layoutSubtreeIfNeeded()
    // (a) waiting: shimmering words and elapsed seconds, no dots.
    var rows=descendants(ui,TypingRow.self)
    try check(rows.count == 1 && rows[0].frame.height == 22,"AT57 one typing row at accessory height 22")
    let row=rows[0];row.layoutSubtreeIfNeeded()
    func capture(_ name:String) throws {
        ui.layoutSubtreeIfNeeded();pet.pet.layoutSubtreeIfNeeded()
        let image=pet.pet.bitmapImageRepForCachingDisplay(in:pet.pet.bounds)!
        pet.pet.cacheDisplay(in:pet.pet.bounds,to:image)
        try image.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent(".build/"+name))
    }
    row.tick();try check(row.elapsedText == "0초" && row.accessibilityLabel() == "작성 중 0초","AT57 words and elapsed at 0s")
    time.addTimeInterval(12);row.tick();try check(row.elapsedText == "12초","AT57 elapsed 12s")
    time.addTimeInterval(53);row.tick();try check(row.elapsedText == "1분 5초","AT57 elapsed over a minute")
    try check(!descendants(ui,NSTextField.self).contains { $0.stringValue.contains("●") },"AT57 no dot glyphs")
    motion=0;row.tick();let start=row.shimmerPosition
    try check(row.isShimmering,"AT57 waiting words shimmer")
    motion=0.8;row.tick();try check(row.shimmerPosition>start,"AT57 light band moves between 0s and 0.8s")
    motion=1.6;row.tick();try check(abs(row.shimmerPosition-start)<0.01,"AT57 shimmer repeats every 1.6s")
    motion=0.5;time.addTimeInterval(-53);row.tick();try capture("task12-waiting-automatic.png")
    reduced=true;row.tick();try check(!row.isShimmering,"AT57 reduced motion stops shimmer")
    reduced=false

    // (b) streaming: no waiting row, caret after the last glyph, blinking, layout unchanged.
    NativeThreadCard.Text.caretTime={blink};NativeThreadCard.Text.caretReduceMotion={false}
    defer { NativeThreadCard.Text.caretTime={ ProcessInfo.processInfo.systemUptime };NativeThreadCard.Text.caretReduceMotion={ NSWorkspace.shared.accessibilityDisplayShouldReduceMotion } }
    controller.receive(["v":1,"type":"message","seq":2,"msg_id":typingAnswer,"employee":"alpha","thread":typingKey.thread,"role":"employee","text":"Hello","files":[],"buttons":[],"ts":"2026-01-01T00:00:01Z"])
    controller.receive(["v":1,"type":"edit","seq":3,"msg_id":typingAnswer,"text":"Hello world, streaming","final":false])
    try check(model.messages[typingAnswer]?.streaming == true,"AT57 fixture message is streaming")
    ui.refresh();ui.layoutSubtreeIfNeeded()
    try check(descendants(ui,TypingRow.self).isEmpty,"AT57 waiting row hidden while streaming")
    let streaming=descendants(ui,NativeThreadCard.Text.self).filter { $0.showsCaret && !$0.isHidden }
    try check(streaming.count == 1 && streaming[0].string == "Hello world, streaming","AT57 caret only on streaming post; string unchanged")
    let text=streaming[0]
    let length=(text.string as NSString).length
    let last=text.layoutManager!.boundingRect(forGlyphRange:text.layoutManager!.glyphRange(forCharacterRange:NSRange(location:length-1,length:1),actualCharacterRange:nil),in:text.textContainer!)
    try check(text.caret.frame.minX >= last.maxX+text.textContainerOrigin.x && text.caret.frame.width == 2 && text.caret.layer?.backgroundColor == NSColor.systemBlue.cgColor,"AT57 2pt blue caret right of last glyph")
    blink=0;text.blinkCaret();let on=text.caretShown
    blink=0.6;text.blinkCaret();try check(on && !text.caretShown,"AT57 caret blinks on/off at 0s/0.6s")
    let withCaret=text.frame;text.showsCaret=false;let withoutCaret=text.frame;text.showsCaret=true
    try check(withCaret == withoutCaret && !(text.textStorage?.string.contains("|") ?? true),"AT57 caret leaves text frame and storage unchanged")
    blink=0;text.blinkCaret();try capture("task12-streaming-automatic.png")
    NativeThreadCard.Text.caretReduceMotion={true};text.blinkCaret()
    try check(text.caretShown,"AT57 reduced motion holds caret on")
    NativeThreadCard.Text.caretReduceMotion={false}

    // (c) final edit removes the caret.
    controller.receive(["v":1,"type":"edit","seq":4,"msg_id":typingAnswer,"text":"Hello world, streaming done.","final":true])
    ui.refresh();ui.layoutSubtreeIfNeeded()
    try check(!descendants(ui,NativeThreadCard.Text.self).contains { $0.showsCaret },"AT57 final edit removes caret")
    pet.panel.orderOut(nil)
    print("AT-HF-57 PASS");print("TYPING_AUTOMATIC_CAPTURES_OK")
}
