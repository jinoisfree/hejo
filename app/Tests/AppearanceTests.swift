import AppKit

/// AT94: real controls update local storage and the native renderers; no hub, login or operating home.
@MainActor func appearanceTests() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { ChatAppearance.bind(nil);try? FileManager.default.removeItem(at:root) }
    let store=try LocalStore(directory:root);ChatAppearance.bind(store)
    try check(ChatAppearance.theme == .system && ChatAppearance.opacity==65 && ChatMetrics.bodyFont==14 && ChatAppearance.color() == .blue,"AT94 neutral local defaults")
    let candidate=Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("hejo.app/Contents/Resources/Pet")
    let resource=FileManager.default.fileExists(atPath:candidate.path) ? candidate:URL(fileURLWithPath:"app/.build/hejo.app/Contents/Resources/Pet")
    let client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client)
    let view=ConversationView(controller:controller),pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resource))
    let connections=ConnectionsWindow(controller:controller)
    pet.reducedMotion={true};pet.pet.reduceTransparency={false};pet.showChat();await waitForTransition(pet,progress:1)
    let window=NSWindow(contentRect:CGRect(x:0,y:0,width:850,height:800),styleMask:[],backing:.buffered,defer:false)
    window.isReleasedWhenClosed=false;window.contentView=view;window.orderFrontRegardless();view.frame=window.contentView!.bounds;view.layoutSubtreeIfNeeded()
    defer {window.orderOut(nil);pet.panel.orderOut(nil);connections.window.orderOut(nil)}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    controller.receive(["type":"message","seq":1,"msg_id":"owner-post","employee":"alpha","thread":"fixture-thread","role":"owner","text":String(repeating:"크기를 바꿔도 내용은 그대로입니다. ",count:10),"ts":"2026-01-01T00:00:00Z"])
    controller.receive(["type":"message","seq":2,"msg_id":"staff-post","employee":"alpha","thread":"fixture-thread","role":"employee","text":"답변입니다.","ts":"2026-01-01T00:00:01Z"])
    view.chooseEmployee("alpha");view.chooseThread(ConversationKey(employee:"alpha",thread:"fixture-thread"));view.layoutSubtreeIfNeeded()
    let history=homeDescendants(view,NativeThreadList.self).first!,editor=homeDescendants(view,DraftScrollView.self).first!
    let savedStates=store.settings.memberStates, savedPending=store.settings.pendingState
    let settings=PetSettingsWindow(),controls=settings.appearanceControls!
    try check(controls.subviews.compactMap{$0 as? NSTextField}.first{$0.stringValue=="65%"}?.font == NSFont.monospacedDigitSystemFont(ofSize:13,weight:.medium),"AT94 opacity value uses original fixed-width 13pt medium digits")
    for (index,theme) in [ChatTheme.system,.light,.dark].enumerated() {
        controls.theme.selectedSegment=index;_ = controls.theme.sendAction(controls.theme.action,to:controls.theme.target)
        try check(store.settings.chatTheme==theme.rawValue && pet.panel.appearance?.name==theme.appearance?.name && connections.window.appearance?.name==theme.appearance?.name,"AT94 theme reaches real pet and connection windows synchronously")
    }
    for percent in [55.0,65,100] {
        controls.opacity.doubleValue=percent;_ = controls.opacity.sendAction(controls.opacity.action,to:controls.opacity.target)
        try check(abs(pet.pet.chatTintAlpha-percent/100)<0.000001 && store.settings.chatOpacity==percent,"AT94 real expanded glass uses selected tint without fading controls")
    }
    pet.pet.reduceTransparency={true};pet.pet.updateScrim();try check(pet.pet.chatTintAlpha==1,"AT94 real glass obeys reduced transparency")
    pet.pet.reduceTransparency={false}
    try check(BubbleOpacity.alpha(progress:0,percent:55,reduceTransparency:false)==0.35 && BubbleOpacity.alpha(progress:0.5,percent:65,reduceTransparency:false)==0.5 && BubbleOpacity.alpha(progress:0.5,percent:55,reduceTransparency:true)==1,"AT94 original tint interpolation")
    var heights:[CGFloat]=[]
    for (index,size) in [12,13,14,15,16,18,20].enumerated() {
        controls.fontSlider.integerValue=index;_ = controls.fontSlider.sendAction(controls.fontSlider.action,to:controls.fontSlider.target)
        try check(ChatMetrics.bodyFont==CGFloat(size) && editor.editor.typingAttributes[.font] as? NSFont == NSFont.systemFont(ofSize:CGFloat(size)),"AT94 live composer follows seven font steps even when empty")
        heights.append(history.layouts.reduce(0){$0+$1.height})
        try check(controls.previewSize.width==536 && controls.previewSize.height>=184,"AT94 preview measures without clipping")
    }
    try check(heights.last!>heights.first!+30 && zip(heights,heights.dropFirst()).allSatisfy{$1 >= $0},"AT94 existing rows reflow immediately, not only future messages")
    let swatches=controls.subviews.compactMap{$0 as? NSButton}.filter{$0.frame.size==CGSize(width:34,height:34)}
    try check(swatches.count==14,"AT94 fourteen native color swatches")
    for (index,color) in UserBubbleColor.allCases.enumerated() {
        let swatch=swatches.first{$0.tag==index}!;_ = swatch.sendAction(swatch.action,to:swatch.target)
        try check(store.settings.chatUserBubbleColor==color.rawValue && swatch.state == .on,"AT94 swatch persists selection locally")
        let content=view.threadContent(.init(key:ConversationKey(employee:"alpha",thread:"fixture-thread"),title:"",preview:"",latestSeq:2))
        if case .post(let owner)=content.top.first! {
            let dark=view.effectiveAppearance.bestMatch(from:[.aqua,.darkAqua]) == .darkAqua
            try check(owner.text.attribute(.foregroundColor,at:0,effectiveRange:nil) as? NSColor == UserBubblePalette(color:color,dark:dark).foreground.nsColor,"AT94 rendered owner text follows selected contrast palette")
        } else {throw TestFailure.assertion("AT94 owner post missing")}
    }
    try check(store.settings.memberStates==savedStates && store.settings.pendingState==savedPending,"AT94 appearance never writes member state or outbox")
    let loaded=try LocalStore(directory:root)
    try check(loaded.settings.chatBodyFontSize==20 && loaded.settings.chatUserBubbleColor=="lightGray" && loaded.settings.chatTheme=="dark" && loaded.settings.chatOpacity==100,"AT94 actual local file survives restart")
    controls.resetAppearance()
    try check(ChatMetrics.bodyFont==14 && ChatAppearance.theme == .system && ChatAppearance.opacity==65 && ChatAppearance.color() == .blue && pet.panel.appearance==nil,"AT94 reset restores exactly four defaults")
    // A style change during Korean composition must neither replace marked text nor turn the old default into explicit formatting.
    view.chooseThread(ConversationKey(employee:"alpha",thread:"fixture-thread"))
    editor.editor.string="초안";view.textDidChange(Notification(name:NSText.didChangeNotification))
    editor.editor.setMarkedText("한",selectedRange:NSRange(location:1,length:0),replacementRange:NSRange(location:NSNotFound,length:0))
    let marked=editor.editor.string
    try ChatAppearance.change(fontSize:18)
    try check(editor.editor.hasMarkedText() && editor.editor.string==marked,"AT94 changing size preserves Korean marked text")
    editor.editor.unmarkText();view.textDidChange(Notification(name:NSText.didChangeNotification));view.applyChatAppearance()
    try check(!controller.draft.text.contains("font-size") && editor.editor.font?.pointSize==18,"AT94 composition commits plain draft and adopts new default size")
    settings.window.orderOut(nil)
    print("AT-HF-94 APP PASS")
}
