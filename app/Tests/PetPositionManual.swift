import AppKit

/// A local editor and the production header input view, without an application delegate or transport.
@MainActor private final class PositionCanvas: NSView {
    let header = ConversationHeaderDrag()
    let editor = NSTextView()
    let drawer = NSTextField(labelWithString:"할 일 · 가짜 항목")
    var drawerWidth: CGFloat = 0 { didSet { needsLayout=true } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        editor.string = "격리된 펫 위치 시험 · 입력 내용은 전송되지 않습니다."
        addSubview(editor); addSubview(header); addSubview(drawer)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layout() {
        super.layout()
        header.frame = CGRect(x: 8, y: max(0,bounds.height-40), width: max(0,bounds.width-16), height: 32)
        drawer.isHidden=drawerWidth<=0
        drawer.frame=CGRect(x:8,y:8,width:max(0,drawerWidth-16),height:max(0,bounds.height-56))
        editor.frame = CGRect(x: drawerWidth+8, y: 8, width: max(0,bounds.width-drawerWidth-16), height: max(0,bounds.height-56))
    }
}

/// Real pointer/display defaults are deliberately retained. The duration option is startup smoke only.
@MainActor func petPositionManual(_ args: [String]) async throws {
    func option(_ name: String) throws -> String {
        guard let i = args.firstIndex(of:name), i+1 < args.count else { throw TestFailure.assertion("missing manual argument") }
        return args[i+1]
    }
    let root = URL(fileURLWithPath:try option("--probe-root")).resolvingSymlinksInPath()
    let temporary = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
    try check(root.path.hasPrefix(temporary.path + "/") && root != temporary,"manual root must be a temporary child")
    func isolated(_ name: String) throws -> URL {
        let url = URL(fileURLWithPath:try option(name)).resolvingSymlinksInPath()
        try check(url.path.hasPrefix(root.path + "/"),"manual output outside temporary root")
        try FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
        return url
    }
    let local = try isolated("--local-store"), evidence = try isolated("--evidence")
    try check(ProcessInfo.processInfo.environment["HEJO_THREE_TAP_TRACE"] == nil,"manual diagnostic output must be disabled")
    let store = try LocalStore(directory:local)
    ChatAppearance.bind(store); defer { ChatAppearance.bind(nil) }
    let c = PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:URL(fileURLWithPath:args.last!)))
    let canvas = PositionCanvas(frame:.zero)
    canvas.header.onBegan = { [weak c] in c?.beginChatDrag(at:$0) }
    canvas.header.onChanged = { [weak c] in c?.moveChatDrag(to:$0) }
    canvas.header.onEnded = { [weak c] in c?.endChatDrag() }
    canvas.header.onDoubleClick = { [weak c] in c?.toggleChatWidth() }
    c.pet.installConversation(canvas); c.onFocus = { [weak c] in c?.panel.makeFirstResponder(canvas.editor) }
    let web = WebPaneModel(downloads:local.appendingPathComponent("Downloads")); web.persistent = false
    web.onExternal = { _ in }; c.installWeb(web)
    let page = local.appendingPathComponent("fixture.html")
    try "<html><body>Local fixture</body></html>".write(to:page,atomically:true,encoding:.utf8)
    let traceURL = evidence.appendingPathComponent("events.jsonl")
    try Data().write(to:traceURL)
    let trace = try FileHandle(forWritingTo:traceURL); defer { try? trace.close() }
    func record(_ kind: String) throws {
        guard let p = c.pet.placement else { return }
        canvas.drawerWidth=p.drawer;canvas.layoutSubtreeIfNeeded()
        func rect(_ r: CGRect) -> [CGFloat] { [r.minX,r.minY,r.width,r.height] }
        let mouse = NSEvent.mouseLocation
        let displayed = c.panel.convertToScreen(c.pet.convert(c.pet.spriteRect,to:nil))
        let row: [String:Any] = ["kind":kind,"time":ProcessInfo.processInfo.systemUptime,"pointer":[mouse.x,mouse.y],"sprite":rect(p.globalSprite),"displayed":rect(displayed),"chat":rect(p.globalBubble),"expanded":c.chatExpanded]
        var data = try JSONSerialization.data(withJSONObject:row,options:.sortedKeys); data.append(10)
        try trace.write(contentsOf:data)
    }
    var failed = false, finished = false
    let monitor = NSEvent.addLocalMonitorForEvents(matching:[.leftMouseDown,.leftMouseDragged,.leftMouseUp,.keyDown]) { event in
        if event.window === c.panel {
            do { try record("input-\(event.type.rawValue)") } catch { failed = true; finished = true }
            DispatchQueue.main.async { do { try record("after-event") } catch { failed = true; finished = true } }
        }
        // Control shortcuts are confined to this test process.
        if event.type == .keyDown, event.modifierFlags.contains(.control) {
            switch event.charactersIgnoringModifiers {
            case "q": finished = true
            case "d": c.toggleDrawer()
            case "w":
                if web.open { web.close() } else { web.open(page,ephemeral:true) }
            case "r": c.resetChatSize()
            default: break
            }
        }
        return event
    }
    defer { if let monitor { NSEvent.removeMonitor(monitor) }; c.panel.orderOut(nil); web.unload() }
    c.show(); try record("startup")
    if args.contains("--probe-fixtures") {
        c.showChat(); await pause(0.4)
        c.setDrawerOpen(true); await pause(0.4); try record("drawer-open")
        try check(!canvas.drawer.isHidden && canvas.drawer.frame.width>0,"manual drawer fixture visible")
        web.open(page,ephemeral:true); await pause(0.5); try record("web-open")
        try check(c.pet.webPane?.isHidden==false && web.current?.view.configuration.websiteDataStore.isPersistent==false,"manual local web visible and ephemeral")
        canvas.editor.string="가짜 입력";c.panel.makeFirstResponder(canvas.editor)
        try check(c.panel.firstResponder === canvas.editor,"manual editor focus")
        web.close(); c.setDrawerOpen(false); await pause(0.4); try record("fixtures-closed")
        print("MANUAL_FIXTURE_AUTOMATION_PASS · programmatic controls, not physical input")
    }
    print("PET_POSITION_MANUAL_READY · click/drag pet; drag header; Control-D drawer; Control-W local web; Control-R size; Control-Q finish"); fflush(stdout)
    let duration = args.firstIndex(of:"--probe-duration").flatMap { $0+1 < args.count ? Double(args[$0+1]) : nil }
    let deadline = duration.map { Date().addingTimeInterval($0) }
    while !finished && (deadline == nil || Date() < deadline!) {
        for tab in web.tabs { if let view = tab.loadedView { try check(!view.configuration.websiteDataStore.isPersistent,"manual web must be nonpersistent") } }
        try record("frame"); await pause(1.0/60)
    }
    try check(!failed,"manual trace write failed")
    try record("finished")
    print(duration == nil ? "MANUAL_SESSION_RECORDED · assess events and observed motion separately" : "STARTUP_SMOKE_ONLY · actual mouse validation not performed")
}
