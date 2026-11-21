import AppKit

/// Compare the old eager update sequence with the native opening/closing transaction.
/// The fixture keeps all stores, messages and deadline responses local.
@MainActor func conversationUpdateTests(resourceDirectory: URL) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let key = ConversationKey(employee: "alpha", thread: "11111111-1111-4111-8111-111111111111")
    let other = ConversationKey(employee: "alpha", thread: "22222222-2222-4222-8222-222222222222")
    func exercise(batched: Bool) throws -> [[String]] {
        let store = try LocalStore(directory: directory.appendingPathComponent(batched ? "batched" : "eager"))
        let controller = try testConversation(client: GateClient(store: store, credentials: MemoryCredentials()))
        controller.deadlineSender = { _ in }
        controller.clock = { ThreadTools.date("2026-01-01T00:00:00Z") }
        controller.receive(["type":"roster", "employees":[["id":"alpha", "name":"직원 A", "aliases":[]]]])
        for (index, target) in [key, key, other].enumerated() {
            controller.receive(["v":1, "type":"message", "seq":index + 1, "msg_id":UUID().uuidString.lowercased(),
                                "employee":target.employee, "thread":target.thread, "role":"employee",
                                "text":"같은 대화 내용 \(index)", "files":[], "buttons":[], "reply_state":NSNull(), "ts":"2026-01-01T00:00:00Z"])
        }
        let view = ConversationView(controller: controller, clipboardArea: store.directory.appendingPathComponent("clipboard"))
        let pet = PetController(store: store, atlas: try SpriteAtlas(resourceDirectory: resourceDirectory))
        defer { disposeDrawerFixture(pet, controller, view) }
        pet.pet.installConversation(view)
        pet.reducedMotion = { false }
        var now = 10.0
        pet.clock = { now }
        if batched { pet.installDrawer(view); pet.setDrawerOpen(true) }
        else { controller.setDrawerState(open: true, chatExpanded: false) }
        pet.onExpansionChanged = { expanded in
            if !expanded { view.folded() }
            controller.model.setVisible(expanded)
        }
        pet.show()
        var deliveries = 0
        var deliveredBeforeCapture = false
        let redraw = controller.onChange
        controller.onChange = {
            redraw?(); deliveries += 1
            deliveredBeforeCapture = pet.pet.genie.image == nil
        }
        func snapshot() -> [String] {
            let selected = controller.model.selected
            let selection = selected == key ? "first" : selected == other ? "other" : "new"
            return [selected?.employee ?? "", selection, String(controller.model.visible),
                    String(controller.drawerVisible), String(controller.composeKey == selected),
                    view.editor.editor.string, view.composerPrompt, view.heading.stringValue,
                    String(controller.model.unread(employee: "alpha"))]
                + view.history.contents.map { "\($0.id):\($0.expanded):\($0.replyTarget):\($0.top.count):\($0.replies?.count ?? 0)" }
        }
        func open(_ target: ConversationKey) throws {
            deliveries = 0; deliveredBeforeCapture = false
            if batched {
                pet.showChat { view.openFromBubble(target) }
                try check(deliveries == 1, "FF update transaction delivers once before opening returns")
                try check(deliveredBeforeCapture && pet.pet.genie.image != nil, "FF final conversation renders before the opening genie capture")
                now += ChatMorph.genieDuration + 0.01; pet.stepTransition()
            } else {
                view.openFromBubble(target)
                controller.setDrawerState(open: true, chatExpanded: true)
                controller.model.setVisible(true)
            }
        }
        try open(key)
        var states = [snapshot()]
        deliveries = 0
        if batched {
            pet.collapseChat()
            try check(deliveries == 1 && pet.pet.genie.image != nil, "FF close folds and updates visibility once while retaining its closing picture")
            now += ChatMorph.genieDuration + 0.01; pet.stepTransition()
        } else {
            controller.setDrawerState(open: true, chatExpanded: false)
            view.folded(); controller.model.setVisible(false)
        }
        states.append(snapshot())
        try open(key); states.append(snapshot())
        deliveries = 0
        if batched { pet.showChat { view.openFromBubble(other) } }
        else { view.openFromBubble(other) }
        states.append(snapshot())
        try check(controller.model.selected == other, "FF opening a different bubble in an already open panel still selects it synchronously")
        deliveries = 0
        controller.performUpdates {
            controller.performUpdates { controller.notice = "nested" }
            controller.notice = "final"
        }
        try check(deliveries == 1 && controller.notice == "final", "FF nested transaction flushes exactly once before returning")
        controller.notice = "outside"
        try check(deliveries == 2, "FF updates outside a transaction remain synchronous")
        return states
    }
    let eager = try exercise(batched: false)
    let batched = try exercise(batched: true)
    try check(eager == batched, "FF eager and batched opening, folding, reopening and retargeting preserve conversation, drawer and selection")
    print("AT-FF-AC04 UPDATE_CONTENT_EQUIVALENCE PASS")
}
