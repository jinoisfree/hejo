import AppKit
import ObjectiveC

/// Keep the URLSession write and the fake gate's frame observation. Inject a
/// lost connection at the write completion, before the controller sees its result.
private func loseWriteCompletion(for thread: String, address: String) -> () -> Void {
    let probe = URLSession.shared.webSocketTask(with: URL(string: "ws://\(address)/v1/ws")!)
    let selector = NSSelectorFromString("sendMessage:completionHandler:")
    let method = class_getInstanceMethod(object_getClass(probe), selector)!
    let implementation = method_getImplementation(method)
    typealias Completion = @convention(block) (NSError?) -> Void
    typealias Send = @convention(c) (AnyObject, Selector, NSObject, @escaping Completion) -> Void
    let send = unsafeBitCast(implementation, to: Send.self)
    let replacement: @convention(block) (AnyObject, NSObject, @escaping Completion) -> Void = { task, message, completion in
        if let text = message.value(forKey: "string") as? String,
           let frame = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
           frame["type"] as? String == "send", frame["thread"] as? String == thread {
            send(task, selector, message) { error in
                completion(error ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost))
            }
        } else {
            send(task, selector, message, completion)
        }
    }
    let injected = imp_implementationWithBlock(replacement)
    method_setImplementation(method, injected)
    return {
        method_setImplementation(method, implementation)
        imp_removeBlock(injected)
        probe.cancel()
    }
}

private final class CardEvidenceBackdrop: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }
}

@MainActor func cardDoneTests(_ args: [String]) async throws {
    let home = URL(fileURLWithPath: args[2]), address = args[3], mode = args[4]
    let evidence = URL(fileURLWithPath: args[5])
    let store = try LocalStore(directory: home, historyMode: true)
    let client = GateClient(store: store, credentials: MemoryCredentials())
    let controller = try testConversation(client: client)
    let drawer = TodoDrawerView(frame: CGRect(x: 0, y: 0, width: 280, height: 400))
    let window = NSWindow(contentRect: drawer.frame, styleMask: [], backing: .buffered, defer: false)
    window.contentView = drawer
    defer { controller.stop(); client.stop(); window.orderOut(nil) }

    var opened = [String]()
    drawer.onCard = { opened.append($0.id) }
    drawer.onComplete = { controller.completeCard($0) }
    drawer.onUndoClose = { controller.undoClose() }
    drawer.onCloseDeadline = { controller.closeDeadline($0, outcome: $1) }
    var now = ThreadTools.date("2026-01-01T00:02:00Z")
    controller.clock = { now }

    func snapshotCards() -> [TodoDrawerModel.Card] {
        let snapshot = controller.drawerSnapshot
        return snapshot.urgent + snapshot.rest
    }
    func card(_ name: String) -> TodoDrawerModel.Card? {
        snapshotCards().first { $0.title == "질문 " + name }
    }
    func repaint() {
        drawer.show(controller.drawerSnapshot, filter: .all, selected: nil)
        drawer.layoutSubtreeIfNeeded()
    }
    func view(_ title: String) throws -> TodoDrawerCardView {
        repaint()
        guard let view = drawer.cardViews.first(where: { $0.card.title == title }) else {
            throw TestFailure.assertion("missing card " + title)
        }
        return view
    }
    func hover(_ view: TodoDrawerCardView) {
        view.mouseEntered(with: NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            trackingNumber: 0, userData: nil)!)
    }
    func click(_ view: TodoDrawerCardView, offset: CGFloat = 1) {
        hover(view)
        let point = view.convert(CGPoint(x: view.bounds.width - 44 + offset, y: 26), to: nil)
        view.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
            timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            clickCount: 1, pressure: 1)!)
    }
    func tick(_ seconds: TimeInterval) async {
        now = now.addingTimeInterval(seconds)
        controller.pollDeadlineCloses()
        await pause(0.04)
    }
    struct Observation: Decodable { let seen: [String], clicks: Int, receipts: [String] }
    func observe(_ command: [String: String] = [:]) async throws -> Observation {
        var request = URLRequest(url: URL(string: "http://\(address)/fixture")!)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(command)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Observation.self, from: data)
    }
    func waitForFrames(_ expected: [String]) async throws {
        // Let the loopback receiver run while the controller clock stays fixed.
        let deadline = Date().addingTimeInterval(3)
        var wire = try await observe()
        while wire.seen.count < expected.count && Date() < deadline {
            await pause(0.02)
            wire = try await observe()
        }
        try check(wire.seen == expected, "unexpected card frames: \(wire.seen)")
    }
    func refreshHistory(_ command: [String: String]) async throws {
        _ = try await observe(command)
        controller.historyLoading.liveChanged()
        try await waitFor { !controller.historyLoading.busy && !controller.model.history.refreshing }
    }
    func hasStrip(_ title: String) throws -> Bool {
        let view = try view(title)
        hover(view)
        return view.completionRect != nil
    }
    func render(_ card: TodoDrawerCardView, name: String) throws {
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        let bounds = card.bounds
        let surface = CardEvidenceBackdrop(frame: bounds)
        let pictured = TodoDrawerCardView(card: card.card, avatar: card.avatar, selected: card.selected,
                                          complete: {}) {}
        pictured.frame = bounds
        surface.addSubview(pictured)
        hover(pictured)
        for (theme, label) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            let appearance = NSAppearance(named: theme)!
            surface.appearance = appearance
            surface.needsDisplay = true
            pictured.needsDisplay = true
            guard let rep = surface.bitmapImageRepForCachingDisplay(in: bounds) else {
                throw TestFailure.assertion("missing card bitmap")
            }
            appearance.performAsCurrentDrawingAppearance {
                surface.cacheDisplay(in: bounds, to: rep)
            }
            guard let png = rep.representation(using: .png, properties: [:]) else {
                throw TestFailure.assertion("missing card PNG")
            }
            try png.write(to: evidence.appendingPathComponent("\(name)-\(label).png"))
        }
    }

    try client.pair(address: address, code: "fixture_cd12", device: "Card fixture")
    try await waitFor { controller.canSend && card("A") != nil && !controller.historyLoading.busy }
    controller.todoDrawer.receive(["available": true, "items": [
        ["employee": "fixture", "id": "fixture-done", "title": "완료 마감", "due": "2026-01-01"],
        ["employee": "fixture", "id": "fixture-cancel", "title": "취소 마감", "due": "2026-01-03"],
    ]])

    switch mode {
    case "confirm":
        let question = try view("질문 A"), deadline = try view("완료 마감")
        for item in [question, deadline] { item.setFrameSize(CGSize(width: 268, height: 52)) }
        guard let asked = card("A") else { throw TestFailure.assertion("fixture question") }
        let alert = TodoDrawerModel.Card(id: "alert", kind: .alert, title: "알림", employee: asked.employee,
            name: asked.name, status: "알림", statusUrgent: false, trailing: asked.trailing, order: now, urgent: false)
        var invalidDeadline = deadline.card
        invalidDeadline.deadlineRef = nil
        for item in [alert, invalidDeadline] {
            try check(!controller.canCompleteCard(item), "AT-CD-01 no action for this kind or reference")
            let disabled = TodoDrawerCardView(card: item, avatar: question.avatar, selected: false) {}
            disabled.frame = question.frame
            hover(disabled)
            try check(disabled.completionRect == nil && (disabled.accessibilityCustomActions() ?? []).isEmpty,
                      "AT-CD-01/12 keyless alert and reference-free deadline")
        }
        try check(question.bounds.size == CGSize(width: 268, height: 52), "AT-CD-01 card size")
        // AT-HB-35 removes the question confirmation strip; deadlines keep their own close action.
        try check(deadline.completionRect == nil && deadline.trailingTextRect != nil, "AT-CD-01 deadline before hover")
        hover(question);hover(deadline)
        try check(question.completionRect==nil && (question.accessibilityCustomActions() ?? []).isEmpty,"AT-HB-35 no question strip")
        try check(deadline.completionRect==CGRect(x:224,y:0,width:44,height:52) && deadline.trailingTextRect == nil && deadline.statusTextRect.maxX <= 216,"AT-CD-01 deadline geometry")
        try check(deadline.accessibilityCustomActions()?.map(\.name) == ["완료로 닫기"],"AT-CD-12 deadline action name")
        try render(question,name:"question");try render(deadline,name:"deadline")
        try check(deadline.accessibilityCustomActions()?.first?.handler?()==true && controller.drawerSnapshot.undoTitle=="완료 마감","AT-CD-12 deadline dispatch")
        controller.undoClose()
        click(question)
        await tick(6)
        try check(opened==[asked.id] && controller.drawerSnapshot.undoTitle==nil,"AT-HB-35 opens legacy question without sending")
    case "deadline":
        click(try view("완료 마감"))
        repaint()
        try check(opened.isEmpty && drawer.footerText == "‘완료 마감’ 닫음 ·", "AT-CD-04 no navigation and undo copy")
        await tick(4.9)
        let beforeSend = try await observe()
        try check(beforeSend.seen.isEmpty, "AT-CD-04 before five seconds")
        await tick(0.11)
        try await waitForFrames(["done"])
    case "undo","stop":
        click(try view("완료 마감"))
        await tick(2)
        if mode=="stop" {controller.stop()} else {controller.undoClose()}
        await tick(10)
        let observed=try await observe()
        try check(observed.seen.isEmpty,"deadline close was cancelled")
    case "mixed":
        click(try view("완료 마감"))
        let event=NSEvent.mouseEvent(with:.rightMouseDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:0)!
        let menu=try view("취소 마감").menu(for:event)
        (menu?.item(withTitle:"취소로 닫기") as? RoomActionItem)?.trigger()
        await tick(6);try await waitForFrames(["done","cancel"])
    case "offline":
        client.stop();await tick(6)
        try check(try hasStrip("완료 마감") && !(try hasStrip("질문 A")),"AT-HB-35 offline deadline and question")
    default:
        throw TestFailure.assertion("unexpected card fixture scenario")
    }
    print("CARD_DONE \(mode) PASS")
}
