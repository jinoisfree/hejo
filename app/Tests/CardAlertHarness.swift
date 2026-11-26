import AppKit

private final class AlertFixtureCredentials: GateCredentialStore {
    var token: String?
    func read(account: String) -> String? { token }
    func save(_ token: String, account: String) -> Bool { self.token = token; return true }
    func delete(account: String) { token = nil }
}

@MainActor enum CardAlertHarness {
    static func run(_ arguments: [String]) async throws {
        _ = NSApplication.shared
        let args = [arguments[0]] + arguments.dropFirst(2)
        let directory = URL(fileURLWithPath: args[3])
        let key = ConversationKey(employee: args[4], thread: args[5])
        let scenario = args[6], entry = args[7]
        let store = try LocalStore(directory: directory, historyMode: true)
        let client = GateClient(store: store, credentials: AlertFixtureCredentials())
        let controller = try ConversationController(client: client, downloads: directory.appendingPathComponent("downloads"))
        let model = controller.model
        let state = model.memberState
        var hub = StateDocument(rev: 1, items: ["read:" + key.employee: .init(v: "0", at: 1, dev: "fixture")])
        state.connect(fetch: { _ in hub }, push: { edits in
            hub = StateDocument(rev: hub.rev + 1, items: MemberState.merge(hub.items, edits))
            return hub
        })
        defer { state.disconnect(); controller.stop(); client.stop() }
        await state.sync()
        try client.pair(address: args[1], code: args[2], device: "Alert card fixture")

        func require(_ condition: Bool, _ stage: String) throws {
            guard condition else { throw HistoryFailure.server("alert_fixture_" + stage, retryable: false) }
        }
        func wait(_ stage: String, for condition: () -> Bool) async throws {
            for _ in 0..<400 {
                if condition() { return }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            try require(false, stage)
        }
        func emit(_ value: [String: Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: value, options: .sortedKeys)
            FileHandle.standardOutput.write(data + Data([10]))
        }
        func go(_ phase: String) async throws {
            try emit(["phase": phase])
            let command = await Task.detached { readLine() }.value
            try require(command == "go", phase + "_control")
        }
        func alert() -> TodoDrawerModel.Card? {
            let snapshot = controller.drawerSnapshot
            return (snapshot.urgent + snapshot.rest).first { $0.key == key && $0.kind == .alert }
        }
        func settle(_ name: String) async throws {
            try await wait(name) { !controller.historyLoading.busy }
            await state.sync()
            try await wait(name + "_member") { !controller.historyLoading.busy }
        }
        let threadRead = "thread:" + key.employee + "/" + key.thread
        let bellRead = "bell:" + key.employee + "/" + key.thread
        try await wait("bootstrap") { client.isConnected && !controller.historyLoading.busy && alert() != nil }
        let view = ConversationView(controller: controller, clipboardArea: directory.appendingPathComponent("clipboard"))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 950, height: 650),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        defer { window.orderOut(nil) }
        view.drawerShownWidth = PetController.drawerWidth
        model.setVisible(true)
        view.setDrawerState(open: true, chatExpanded: true)
        let strip = entry == "strip"
        if scenario == "home" || strip { view.chooseHome() } else { view.chooseEmployee(key.employee) }
        try await settle("room")
        if scenario == "automatic" {
            try require(model.selected == key && view.sendTarget == key && alert() != nil && hub.items[bellRead] == nil,
                        "automatic_selection")
        }
        if scenario == "new-alert" {
            view.chooseThread(key)
            try await settle("active")
            try require(model.selected == key && alert() == nil, "initial_alert_consumed")
            try await go("publish")
            try await wait("new_alert") { alert() != nil && !controller.historyLoading.busy }
        }
        if scenario == "refreshing" {
            try await go("hold")
            controller.historyLoading.liveChanged()
            try await wait("refreshing") { controller.model.history.refreshing && alert() != nil }
        }
        func renderDrawer() {
            view.refresh()
            view.layoutSubtreeIfNeeded()
            view.todoDrawer.layoutSubtreeIfNeeded()
        }
        func drawerCard() throws -> TodoDrawerCardView {
            renderDrawer()
            guard let card = view.todoDrawer.cardViews.first(where: { $0.card.key == key }) else {
                throw HistoryFailure.server("alert_fixture_missing_drawer_card", retryable: false)
            }
            return card
        }
        func clickCard(_ card: TodoDrawerCardView, at x: CGFloat) {
            let point = card.convert(CGPoint(x: x, y: 26), to: nil)
            let event = NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            card.mouseDown(with: event)
        }
        func hover(_ card: TodoDrawerCardView) {
            let event = NSEvent.enterExitEvent(with: .mouseEntered, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                trackingNumber: 0, userData: nil)!
            card.mouseEntered(with: event)
        }
        func emitResult(_ phase: String) throws {
            try emit(["phase": phase, "remaining": alert() != nil, "threadRead": hub.items[threadRead]?.v ?? "",
                      "bellRead": hub.items[bellRead]?.v ?? "", "selected": model.selected == key,
                      "failure": controller.historyLoading.failure != nil])
        }
        if strip {
            let selected = model.selected
            try require(selected != key, "strip_different_thread")
            let now = controller.clock()
            controller.clock = { now }
            if scenario == "strip-undo" {
                let deadline = TodoDrawerModel.Card(id: "fixture-deadline", kind: .deadline,
                    title: "시험 마감", employee: key.employee, name: "시험 직원", status: "",
                    statusUrgent: false, trailing: "", order: now, urgent: false,
                    deadlineRef: .init(employee: key.employee, id: "fixture-deadline"))
                controller.closeDeadline(deadline, outcome: "done")
            }
            let undoTitle = controller.drawerSnapshot.undoTitle
            try require(undoTitle == (scenario == "strip-undo" ? "시험 마감" : nil), "strip_undo_fixture")
            let card = try drawerCard()
            hover(card)
            guard let rect = card.completionRect else { throw HistoryFailure.server("alert_fixture_strip_missing", retryable: false) }
            try require(rect.width == 44, "strip_geometry")
            try require(card.accessibilityCustomActions()?.map(\.name) == ["읽음으로 표시"], "strip_accessibility")
            if scenario == "strip", let path = ProcessInfo.processInfo.environment["HEJO_CARD_ALERT_EVIDENCE"] {
                try captureAlertCard(card, to: URL(fileURLWithPath: path), hover: hover)
            }
            try await go("select")
            clickCard(card, at: rect.midX)
            try await go("duplicate")
            try require(alert() != nil && model.selected == selected && controller.drawerSnapshot.undoTitle == undoTitle,
                        "strip_in_flight")
            clickCard(card, at: rect.midX)
            try await go("release")
            try await settle("result")
            try require(model.selected == selected && controller.drawerSnapshot.undoTitle == undoTitle, "strip_no_navigation_or_undo")
            if scenario == "strip-fail" {
                try emitResult("failed")
                try await go("retry")
                let retry = try drawerCard()
                try require(retry.accessibilityCustomActions()?.first?.handler?() == true, "strip_accessibility_dispatch")
                try await settle("retry")
                try require(model.selected == selected && controller.drawerSnapshot.undoTitle == undoTitle, "strip_retry_selection")
            }
            try emitResult("result")
            return
        }

        try await go("select")
        renderDrawer()
        if entry == "thread" {
            guard let thread = view.history.contents.first(where: { $0.id == key.thread }) else {
                throw HistoryFailure.server("alert_fixture_missing_chat_thread", retryable: false)
            }
            thread.clickCard()
        } else if entry == "mouse" {
            clickCard(try drawerCard(), at: 60)
        } else {
            let drawer = view.todoDrawer
            _ = try drawerCard()
            try require(window.makeFirstResponder(drawer), "drawer_focus")
            drawer.moveDown(nil)
            drawer.insertNewline(nil)
        }
        if scenario == "refreshing" { try await go("release") }
        try await settle("result")
        try emitResult("result")
    }

    private static func captureAlertCard(_ card: TodoDrawerCardView, to directory: URL,
                                         hover: (TodoDrawerCardView) -> Void) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let frame = CGRect(x: 0, y: 0, width: 268, height: 52)
        let background = AlertCardBackdrop(frame: frame)
        let preview = TodoDrawerCardView(card: card.card, avatar: card.avatar, selected: false, complete: {}) {}
        preview.frame = frame
        background.addSubview(preview)
        hover(preview)
        for (theme, name) in [(NSAppearance.Name.aqua, "light"), (.darkAqua, "dark")] {
            let appearance = NSAppearance(named: theme)!
            background.appearance = appearance
            background.needsDisplay = true
            preview.needsDisplay = true
            guard let bitmap = background.bitmapImageRepForCachingDisplay(in: frame) else {
                throw HistoryFailure.invalidResponse
            }
            appearance.performAsCurrentDrawingAppearance { background.cacheDisplay(in: frame, to: bitmap) }
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw HistoryFailure.invalidResponse }
            try png.write(to: directory.appendingPathComponent("alert-\(name).png"))
        }
    }
}

private final class AlertCardBackdrop: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
    }
}

#if HEJO_CARD_ALERT_TEST
@main @MainActor enum CardAlertMain {
    static func main() async throws { try await CardAlertHarness.run(CommandLine.arguments) }
}
#endif
