import AppKit
import WebKit

@MainActor func webAddressTests() throws {
    try check(WebAddress.destination(for: "   ") == nil, "AT96 empty address stays")
    try check(WebAddress.destination(for: "local.test/page")?.absoluteString == "https://local.test/page", "AT96 bare address")
    try check(WebAddress.destination(for: "한글 검색")?.host == "www.google.com" && URLComponents(url:WebAddress.destination(for:"한글 검색")!,resolvingAgainstBaseURL:false)?.queryItems?.first?.value == "한글 검색", "AT96 search computes an address without fetching it")
    try check(!WebAddress.isWeb(URL(string:"javascript:alert(1)")!) && !WebAddress.showsFile(URL(fileURLWithPath:"/fake/unknown.bin")), "AT96 external schemes and unsupported files stay outside")
    let folder = FileManager.default.temporaryDirectory
    let duplicate = folder.appendingPathComponent("note.txt")
    try check(WebAddress.downloadTarget(folder:folder,suggested:"note.txt",exists:{$0==duplicate}).lastPathComponent == "note 2.txt", "AT96 original web download numbering")
    try check(WebAddress.downloadTarget(folder:folder,suggested:"../a\n.txt",exists:{_ in false}).lastPathComponent == "내려받은 파일.._a_.txt", "AT96 web download path is a single visible component")
    try check(PetLayout.defaultPaneWidth == 720 && PetLayout.minimumPaneWidth == 280, "AT96 original pane widths")
    let roomy = PetLayout.paneSplit(base:540,minimumBase:540,wanted:720,available:1800)
    let narrow = PetLayout.paneSplit(base:900,minimumBase:540,wanted:720,available:1000)
    try check(roomy.base == 540 && roomy.pane == 720 && narrow.base == 640 && narrow.pane == 360, "AT96 original split preserves base unless page needs room")
    print("AT-HF-96 ADDRESS PASS")
}

/// Real WebKit navigation/downloads and panel motion against a loopback-only fixture. External opens are recorded.
@MainActor func webPaneNetwork(_ args: [String]) async throws {
    try webAddressTests()
    try webToolbarTests()
    let home=URL(fileURLWithPath:args[2]), base=URL(string:args[3])!, resources=URL(fileURLWithPath:args[4])
    let store=try LocalStore(directory:home), client=GateClient(store:store,credentials:MemoryCredentials()), conversation=try testConversation(client:client)
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resources))
    pet.displays = { [PetDisplay(frame:CGRect(x:0,y:0,width:2400,height:1300),visible:CGRect(x:0,y:0,width:2400,height:1280))] }
    let web=WebPaneModel(downloads:conversation.files.downloads.root); web.persistent=false
    var external:[URL]=[];web.onExternal={external.append($0)}
    let content=ConversationView(controller:conversation)
    pet.pet.installConversation(content);pet.installWeb(web)
    content.onOpenURL={pet.openWebLink($0,command:false)}
    pet.panel.onPageKey={ event in web.hasFocus(in:pet.panel) && web.handleShortcut(event) }
    pet.reducedMotion={false};pet.placePet(at:CGPoint(x:450,y:750));pet.showChat()
    defer {web.close();web.unload();client.stop();pet.panel.orderOut(nil)}
    await waitForTransition(pet,progress:1)
    let preferred=pet.preferredChatSize
    let page=base.appendingPathComponent("page")
    pet.openWebLink(page,command:true)
    try check(external==[page] && !web.open,"AT96 command conversation link opens outside only")
    let baseWidth=pet.pet.placement!.bubbleRect.width
    content.onOpenURL(page)
    try check(web.open && web.sliding && web.current?.loadedView==nil,"AT96 pane delays page creation until width settles")
    await pause(0.12)
    let middleWidth=pet.pet.placement!.bubbleRect.width
    try check(middleWidth>baseWidth && middleWidth<pet.placementTarget!.bubbleRect.width && web.current?.loadedView==nil,"AT96 opening uses an intermediate frame with deferred WebKit geometry")
    try await waitFor(10){web.current?.title=="합성 페이지" && !web.sliding}
    try check(pet.pet.paneWidth==720 && web.width==720 && pet.preferredChatSize==preferred,"AT96 pane adds width without changing conversation preference")
    let first=web.current!
    try webAddressInk(pet.pet.webPane!)
    let script=try await first.view.evaluateJavaScript("document.getElementById('field').value='한글'; document.getElementById('field').value")
    try check(script as? String == "한글","AT96 actual page is interactive")
    let href=try await first.view.evaluateJavaScript("document.getElementById('next').click(); 'clicked'")
    _=href
    try await waitFor{web.current?.title=="둘째 페이지" && web.tabs.count==2}
    web.selected=first.id
    let retained=try await awaitValue(first.view,"document.getElementById('field').value")
    try check(web.current===first && retained == "한글","AT96 tab switching preserves DOM state")
    web.go(base.appendingPathComponent("second").absoluteString)
    try await waitFor{first.title=="둘째 페이지" && first.canGoBack}
    first.view.goBack();try await waitFor{first.title=="합성 페이지" && first.canGoForward}
    first.view.goForward();try await waitFor{first.title=="둘째 페이지"}
    func command(_ code: UInt16)->NSEvent {NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,characters:"ㅅ",charactersIgnoringModifiers:"ㅅ",isARepeat:false,keyCode:code)!}
    pet.panel.makeFirstResponder(first.view)
    try check(pet.panel.performKeyEquivalent(with:command(17)) && web.tabs.count==3,"AT96 Korean-input command T reaches web pane")
    pet.panel.makeFirstResponder(pet.pet.webPane!.address)
    try check(pet.panel.performKeyEquivalent(with:command(13)) && web.tabs.count==2,"AT96 command W closes current tab")
    for _ in 0..<13 {web.newTab()}
    try check(web.tabs.count==12 && !web.tabs.contains(where:{$0===first}),"AT96 thirteenth tab evicts oldest")
    await pause(0.3)
    let tabScroll=pet.pet.webPane!.subviews.compactMap{$0 as? NSScrollView}.first!
    try check(tabScroll.contentView.bounds.minX>0,"AT96 newly selected tab scrolls into the strip")
    web.open(page);try await waitFor{web.current?.title=="합성 페이지"}
    // Navigation to a local download, not a gateway request. The server rejects any Authorization header.
    web.go(base.appendingPathComponent("download").absoluteString)
    let target=conversation.files.downloads.root.appendingPathComponent("web.txt")
    try await waitFor(10){FileManager.default.fileExists(atPath:target.path) && web.notice?.hasPrefix("다운로드 폴더에 저장했어요:")==true}
    try check(try String(contentsOf:target,encoding:.utf8)=="local web download","AT96 WKDownload uses injected DownloadFileStore")
    // A real paired gateway attachment is fetched by the app, then shown as a local, nonpersistent tab.
    conversation.onOpenFile={ url in _=pet.showBeside(url) }
    try client.pair(address:args[3].replacingOccurrences(of:"http://",with:"ws://"),code:"test_code-12",device:"fake web test")
    try await waitFor{conversation.canSend && conversation.model.messages.count==1}
    let post=conversation.model.messages.values.first!,file=post.files[0]
    let attachment=base.appendingPathComponent("v1/files/alpha/"+file.fileID)
    try check(conversation.openAttachmentLink(attachment),"AT96 known gateway attachment routes through app")
    try await waitFor{web.current?.file?.lastPathComponent.contains(file.fileID.replacingOccurrences(of:"-",with:""))==true}
    let confidential=web.current!
    try check(!confidential.view.configuration.websiteDataStore.isPersistent && confidential.view.url?.scheme != "http","AT96 attachment WebKit uses local bytes and a separate nonpersistent store")
    var bytes=""
    for _ in 0..<50 { bytes=(try? await awaitValue(confidential.view,"document.body.innerText")) ?? ""; if bytes.contains("private fixture") {break}; await pause(0.05) }
    try check(bytes.contains("private fixture"),"AT96 authorized attachment rendered locally")
    let absent=base.appendingPathComponent("missing")
    web.open(absent)
    try await waitFor(10){web.notice?.hasPrefix("페이지를 열지 못했어요.")==true}
    try check(pet.chatExpanded && content.editor.editor.isEditable && pet.pet.webPane!.subviews.count>0,"AT96 page error leaves conversation and outside control usable")
    let beforeOutside=external.count
    web.openOutside()
    try check(web.current?.url==nil && external.count==beforeOutside && web.open,"AT96 original first-navigation failure keeps outside control without a destination")
    web.close()
    try await waitFor{!web.sliding && web.tabs.isEmpty}
    // Bubble route: unfold first, then open page. This is the same PetController entry used by AppDelegate.
    pet.collapseChat();await waitForTransition(pet,progress:0)
    pet.openWebLink(page,command:false)
    try check(pet.chatExpanded && !web.open,"AT96 folded bubble waits for genie")
    try await waitFor(10){web.current?.title=="합성 페이지" && !web.sliding}
    web.current?.takePicture();try await waitFor{web.current?.picture != nil}
    let picture=web.current!.picture!
    pet.resizePane(to:300);try await waitFor{abs(web.width-300)<0.5}
    try check(pet.preferredChatSize==preferred,"AT96 pane drag preserves base width")
    pet.resetPaneSize();try await waitFor{web.width==720}
    pet.pet.onResize?(.far,CGPoint(x:0,y:-100));pet.endPetDrag()
    try check(pet.preferredChatSize==preferred,"AT96 tall pane resize preserves saved conversation height")
    try check(store.settings.webPaneHeight != nil,"AT96 pane geometry uses existing local settings")
    pet.resetPaneSize();try await waitFor{web.width==720}
    let blank=pet.pet.webPane!.blank
    pet.pet.webPane!.layoutSubtreeIfNeeded()
    let point=stride(from:CGFloat(8),to:blank.bounds.width-10,by:4).map{CGPoint(x:$0,y:20)}.first(where:blank.blank)!
    func click(_ type:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:type,location:blank.convert(point,to:nil),modifierFlags:[],timestamp:0,windowNumber:pet.panel.windowNumber,context:nil,eventNumber:0,clickCount:2,pressure:1)!}
    _=blank.handle(click(.leftMouseDown));try check(blank.handle(click(.leftMouseUp)) && !web.open,"AT96 blank strip double click closes")
    try check(pet.pet.hasPanePicture && web.sliding,"AT96 closing uses cached page picture")
    try await waitFor{!web.sliding && web.tabs.isEmpty}
    pet.openWebLink(page,command:false)
    try check(web.current?.picture != nil && picture.fresh,"AT96 reopen within thirty seconds reuses blurred picture")
    try await waitFor{web.current?.title=="합성 페이지" && !web.sliding}
    if args.count>5 {try await captureWebPane(pet.pet.webPane!,at:URL(fileURLWithPath:args[5]))}
    weak var unloadedPage=web.current?.loadedView
    pet.reducedMotion={true};web.close()
    try await waitFor { unloadedPage == nil }
    try check(!web.sliding && web.width==0 && web.tabs.isEmpty,"AT96 reduced motion closes immediately")
    print("AT-HF-96 WEBKIT PASS")
}
@MainActor private func awaitValue(_ view:WKWebView,_ code:String) async throws ->String { (try await view.evaluateJavaScript(code)) as? String ?? "" }
@MainActor private func captureWebPane(_ view:WebPaneView,at folder:URL) async throws {
    try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    view.web.current?.address="http://localhost/page"
    for (name,appearance) in [("light",NSAppearance.Name.aqua),("dark",.darkAqua)] {
        view.window?.appearance=NSAppearance(named:appearance);view.refresh();view.layoutSubtreeIfNeeded();view.displayIfNeeded();await pause(0.3)
        let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!;view.cacheDisplay(in:view.bounds,to:rep)
        if let page=view.web.current?.view,let image: NSImage = await withCheckedContinuation({done in page.takeSnapshot(with:nil){image,_ in done.resume(returning:image)}}),let context=NSGraphicsContext(bitmapImageRep:rep) {
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=context;var rect=page.convert(page.bounds,to:view); if view.isFlipped {rect.origin.y=view.bounds.height-rect.maxY}; image.draw(in:rect);NSGraphicsContext.restoreGraphicsState()
        }
        try rep.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("task45-hejo-"+name+".png"))
    }
}

/// N45-01: unmodified SwiftUI reference measured at width 720 (native control frames and baseline).
@MainActor func webToolbarTests() throws {
    let web = WebPaneModel();web.persistent = false
    let pane = WebPaneView(web:web);pane.frame = NSRect(x:0,y:0,width:720,height:1000);pane.layoutSubtreeIfNeeded()
    let buttons = pane.subviews.compactMap{$0 as? WebControl}
    func button(_ label:String)->WebControl {buttons.first{$0.accessibilityLabel() == label}!}
    try check(button("뒤로").frame == NSRect(x:12,y:52,width:10,height:14),"AT96 reference back button native frame")
    try check(button("앞으로").frame == NSRect(x:30,y:52,width:10,height:14),"AT96 reference forward button native frame")
    try check(button("새로고침").frame == NSRect(x:48,y:51,width:14,height:16),"AT96 reference reload button native frame")
    try check(pane.address.frame == NSRect(x:68,y:47,width:616,height:25),"AT96 original background incl 10pt horizontal and 5pt vertical padding")
    let text = pane.address.cell!.drawingRect(forBounds:pane.address.bounds)
    let placed = pane.address.convert(text,to:pane)
    try check(placed == NSRect(x:78,y:52,width:596,height:15) && placed.maxY-3 == 64,"AT96 source address text frame and 64pt baseline")
    try check(pane.surface.frame.minX == 0 && pane.surface.frame.width == 720,"AT96 leading rule overlays rather than consuming page width")
}

/// Sample actual drawn glyphs, independent of the cell's reported layout rectangle (source reference 1x capture).
@MainActor func webAddressInk(_ pane:WebPaneView) throws {
    pane.window?.appearance = NSAppearance(named:.aqua)
    pane.window?.makeFirstResponder(nil);pane.web.addressFocused = false;pane.web.current?.address = "http://localhost/page";pane.refresh();pane.layoutSubtreeIfNeeded();pane.displayIfNeeded()
    let bitmap = pane.bitmapImageRepForCachingDisplay(in:pane.bounds)!;pane.cacheDisplay(in:pane.bounds,to:bitmap)
    var left = Int.max,top = Int.max,bottom = 0
    for y in 48..<73 {for x in 75..<350 {
        let c = bitmap.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
        if c.alphaComponent>0.5 && c.redComponent<0.4 && c.greenComponent<0.4 && c.blueComponent<0.4 {left = min(left,x);top = min(top,y);bottom = max(bottom,y)}
    }}
    try check(left == 81 && top == 55 && bottom == 65,"AT96 original rendered address glyph x and vertical baseline: \(left)/\(top)/\(bottom)")
}
