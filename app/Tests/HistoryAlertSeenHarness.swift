import AppKit

@MainActor enum HistoryAlertSeenHarness {
    static func run(client: GateClient, args: [String]) async throws {
        let app = NSApplication.shared
        let directory = URL(fileURLWithPath: args[3])
        let key = ConversationKey(employee: "alpha", thread: args[4])
        let scenario = args[6]
        let ordinary = scenario.hasPrefix("ordinary-")
        let alternate = args.count > 7 ? ConversationKey(employee: "alpha", thread: args[7]) : key
        let controller = try ConversationController(client: client, downloads: directory.appendingPathComponent("downloads"))
        defer { controller.stop() }
        let model = controller.model
        let state = model.memberState
        var now = Date()
        if ordinary { controller.clock = { now } }
        var hub = StateDocument()
        if ordinary {
            hub = StateDocument(rev: 1, items: ["read:alpha": .init(v: "0", at: 1, dev: "fixture")])
        }
        state.connect(fetch: { _ in hub }, push: { edits in
            hub = StateDocument(rev: hub.rev + 1, items: MemberState.merge(hub.items, edits))
            return hub
        })
        defer { state.disconnect() }
        await state.sync()
        try client.pair(address: args[1], code: args[2], device: "Fixture alerts")

        func check(_ condition: Bool, _ name: String) throws {
            guard condition else { throw HistoryFailure.server("fixture_alert_" + name, retryable: false) }
        }
        func wait(_ condition: () -> Bool, _ stage: String) async throws {
            for _ in 0..<400 {
                if condition() { return }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            try check(false, stage)
        }
        func emit(_ value: [String: Any]) throws {
            let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            FileHandle.standardOutput.write(data + Data([10]))
        }
        func cards() -> [TodoDrawerModel.Card] {
            let snapshot = controller.drawerSnapshot
            return snapshot.urgent + snapshot.rest
        }

        try await wait({ client.isConnected && !controller.historyLoading.busy && cards().contains { $0.key == key } }, "bootstrap")
        let view = ConversationView(controller: controller, clipboardArea: directory.appendingPathComponent("clipboard"))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        model.setVisible(true)
        try await wait({ !controller.historyLoading.busy }, "visibility")

        func step(_ name: String, _ action: () async throws -> Void) async throws {
            try emit(["phase": name])
            try check(readLine() == "go", "control")
            try await action()
            try await wait({ !controller.historyLoading.busy }, name)
            let failure = controller.historyLoading.failure != nil
            await state.sync()
            try await wait({ !controller.historyLoading.busy }, name + "_sync")
            let reads = hub.items.filter { $0.key.hasPrefix("bell:") || $0.key.hasPrefix("thread:") }.compactMapValues(\.v)
            try emit(["phase": name, "selected": model.selected?.thread ?? "",
                      "target": view.sendTarget?.thread ?? "", "reply": view.replyMode,
                      "failure": failure, "modal": app.modalWindow != nil || window.attachedSheet != nil,
                      "reads": reads, "cards": cards().compactMap(\.messageID).sorted(),
                      "unread": model.unread(key), "alternateUnread": model.unread(alternate)])
        }
        func selectDrawer() throws {
            guard let card = cards().first(where: { $0.key == key }) else {
                throw HistoryFailure.server("fixture_alert_card", retryable: false)
            }
            view.selectDrawerCard(card)
        }
        if scenario == "drawer" || scenario == "question" {
            try await step("drawer") { try selectDrawer() }
        } else {
            try await step("room") { view.chooseEmployee(key.employee) }
        }
        if ordinary {
            try await step("expire") {
                now = now.addingTimeInterval(25 * 3600)
                controller.historyLoading.tick()
            }
        }
        switch scenario {
        case "click", "siblings", "notice-fails", "all-fail", "question":
            try await step("click") { view.chooseThread(key) }
        case "ordinary-click":
            try await step("click") { view.chooseThread(key) }
        case "ordinary-search":
            try await step("search") { view.revealHistorySearch(alternate, id: args[8]) }
        case "supersede":
            try await step("switch") {
                controller.historyLoading.liveChanged()
                view.chooseThread(key)
                let ready = await Task.detached { readLine() }.value
                try check(ready == "held", "hold_context")
                view.chooseThread(alternate)
                try emit(["release": true])
            }
        case "reply":
            try await step("reply") { view.writeReply() }
        default:
            break
        }
        if scenario == "notice-fails" || scenario == "all-fail" {
            try await step("retry") { view.chooseThread(key) }
        }
        if scenario == "question" {
            try await step("reply") { view.writeReply() }
            try await step("answer") {
                try check(await controller.sendText("fixture owner reply", key: key), "answer_send")
                try await wait({ !cards().contains { $0.key == key } }, "answer_card")
            }
        }
    }
}
