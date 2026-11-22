import AppKit

@MainActor func transitionPreparationTests(resourceDirectory: URL) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try LocalStore(directory: directory)
    let controller = try testConversation(client: GateClient(store: store, credentials: MemoryCredentials()))
    controller.receive(["type":"roster", "employees":[["id":"alpha", "name":"직원 A", "aliases":[]]]])
    let key = ConversationKey(employee: "alpha", thread: "11111111-1111-4111-8111-111111111111")
    controller.receive(["v":1, "type":"message", "seq":1, "msg_id":"22222222-2222-4222-8222-222222222222",
                        "employee":key.employee, "thread":key.thread, "role":"employee", "text":"첫 프레임 시험",
                        "files":[], "buttons":[], "reply_state":NSNull(), "ts":"2026-01-01T00:00:00Z"])
    let view = ConversationView(controller: controller, clipboardArea: directory.appendingPathComponent("clipboard"))
    let pet = PetController(store: store, atlas: try SpriteAtlas(resourceDirectory: resourceDirectory))
    defer { disposeDrawerFixture(pet, controller, view) }
    pet.pet.installConversation(view); pet.installDrawer(view)
    var now = 10.0
    pet.clock = { now }; pet.reducedMotion = { false }
    pet.onExpansionChanged = { controller.model.setVisible($0) }
    view.reduceMotion = { true }
    pet.show()
    pet.showChat { view.openFromBubble(key) }
    try check(pet.transitionProgress == 0, "FF first queued frame preserves the synchronous folded starting pose")
    now += 0.06
    // This block is queued after the transition's first frame, without sleeping for a timer interval.
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    try check(abs(pet.transitionProgress - 0.2) < 0.000001 && pet.transitionSteps > 0,
              "FF first queued frame uses real elapsed time on the unchanged 0.30 second curve")
    pet.collapseChat()
    pet.reducedMotion = { true }; pet.showChat()
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
    try check(pet.transitionProgress == 1 && pet.transitionSteps == 0,
              "FF a superseded queued frame cannot advance a newer reduced-motion transition")

    func assertRows(_ label: String) throws {
        view.layoutSubtreeIfNeeded(); view.employeeTable.layoutSubtreeIfNeeded()
        for row in 0..<view.numberOfRows(in: view.employeeTable) {
            try check(abs(view.employeeTable.rect(ofRow: row).height - view.tableView(view.employeeTable, heightOfRow: row)) < 0.01,
                      "FF sidebar row geometry follows current content: " + label)
        }
    }
    view.setSidebarWidth(68); view.refresh(); try assertRows("tabs")
    let previous = (0..<view.numberOfRows(in: view.employeeTable)).map { view.employeeTable.rect(ofRow: $0) }
    view.refresh(); view.refresh()
    try check(previous == (0..<view.numberOfRows(in: view.employeeTable)).map { view.employeeTable.rect(ofRow: $0) },
              "FF unchanged sidebar heights retain exact geometry")
    view.setSidebarWidth(212); try assertRows("list")
    view.setSidebarWidth(68); try assertRows("tabs restored")
    print("AT-FF-FIRST-FRAME AND SIDEBAR_GEOMETRY PASS")
}
