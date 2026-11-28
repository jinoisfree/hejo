import AppKit

/// AT-RD-08·08b·09 and the app half of AT-RD-01b/01c against a loopback history gate
/// (result_done_fixture.py). Buttons are found in the real conversation view and pressed
/// through the chips' own `invoke`.
@MainActor func resultDoneTests(_ args: [String]) async throws {
    let home = URL(fileURLWithPath: args[2]), address = args[3], mode = args[4]
    let store = try LocalStore(directory: home, historyMode: true)
    let client = GateClient(store: store, credentials: MemoryCredentials())
    let controller = try testConversation(client: client)
    let view = ConversationView(controller: controller, clipboardArea: home.appendingPathComponent("clipboard"))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView = view
    window.orderFrontRegardless()
    defer { controller.stop(); client.stop(); window.orderOut(nil) }

    struct Post: Decodable { let id: String, role: String, buttons: [MessageButton] }
    struct Observation: Decodable { let thread: String, clicks: [[String: String]], sends: Int, posts: [Post] }
    func observe() async throws -> Observation {
        var request = URLRequest(url: URL(string: "http://\(address)/fixture")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Observation.self, from: data)
    }
    func chips() -> [FileChip] {
        func all(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { all($0) } }
        return all(view.history).compactMap { $0 as? FileChip }.filter { $0.replyWord != nil }
    }
    func settle() async {
        view.layoutSubtreeIfNeeded()
        CATransaction.flush()
        await pause(0.05)
    }
    func chip(_ word: String) throws -> FileChip {
        guard let found = chips().first(where: { $0.replyWord?.trimmingCharacters(in: .whitespaces) == word }) else {
            throw TestFailure.assertion("missing button view " + word)
        }
        return found
    }
    func press(_ word: String) async throws {
        let target = try chip(word)
        try check(target.invoke != nil, "button view has a press path")
        target.invoke?()
        await pause(0.3)
    }

    try client.pair(address: address, code: "fixture_rd12", device: "Result fixture")
    let seen = try await observe()
    let key = ConversationKey(employee: "fixture", thread: seen.thread)
    let employeePosts = seen.posts.filter { $0.role == "employee" }
    let question = employeePosts[0].id, last = employeePosts[employeePosts.count - 1].id
    try await waitFor { controller.canSend && !controller.historyLoading.busy && controller.model.history.summaries[key] != nil }
    view.chooseThread(key)
    try await waitFor { controller.model.messages[last] != nil }
    for _ in 0..<5 { await settle() }
    let state = controller.model.assessment(key)
    func buttonID(_ message: String, _ label: String) throws -> String {
        guard let id = seen.posts.first(where: { $0.id == message })?.buttons.first(where: { $0.label == label })?.id else {
            throw TestFailure.assertion("fixture button " + label)
        }
        return id
    }

    switch mode {
    case "done":
        try check(state.buttons == [last] && state.color == "#2EB67D" && state.pendingID == nil, "AT-RD-08 buttons, green, no pending")
        try check(chips().map { $0.replyWord ?? "" }.sorted() == ["되돌리기", "확인"], "AT-RD-08 only the result notice shows buttons")
        try check(chips().allSatisfy { $0.isEnabled }, "AT-RD-08 both buttons enabled")
        try await press("되돌리기")
        let wire = try await observe()
        try check(wire.clicks.count == 1 && wire.sends == 0
                  && wire.clicks[0]["type"] == "click" && wire.clicks[0]["msg_id"] == last
                  && wire.clicks[0]["button_id"] == (try buttonID(last, "되돌리기")), "AT-RD-08 one click frame, no send")
        print("AT-RD-08 PASS")
    case "both":
        try check(state.pendingID == question && state.color == "#E01E5A", "AT-RD-08b red, pending is the question")
        let cards = (controller.drawerSnapshot.urgent + controller.drawerSnapshot.rest).filter { $0.key == key }
        try check(cards.count == 1 && cards[0].messageID == question, "AT-RD-08b one question card for the question")
        try check(chips().map { $0.replyWord ?? "" }.sorted() == ["거절", "되돌리기", "승인", "확인"] && chips().allSatisfy { $0.isEnabled },
                  "AT-RD-08b four enabled buttons")
        try await press("되돌리기")
        try await press("거절")
        let wire = try await observe()
        try check(wire.clicks.count == 2 && wire.sends == 0, "AT-RD-08b two clicks")
        try check(wire.clicks[0]["msg_id"] == last && wire.clicks[0]["button_id"] == (try buttonID(last, "되돌리기"))
                  && wire.clicks[1]["msg_id"] == question && wire.clicks[1]["button_id"] == (try buttonID(question, "거절")),
                  "AT-RD-08b each click targets its own post")
        print("AT-RD-08b PASS")
    case "prefixed", "padded", "reversed":
        try check(state.pendingID == last && state.color == "#E01E5A", "AT-RD-01b/01c red, pending is the notice")
        let undo = try chip("되돌리기")
        let undoID=try buttonID(last,undo.replyWord!)
        // AT-HB-31 delegates button eligibility to the gate.
        try check(undo.isEnabled, "gate supplied undo is enabled")
        try await press("되돌리기")
        let wire = try await observe()
        try check(wire.clicks.count == 1 && wire.clicks[0]["button_id"]==undoID && wire.sends == 0, "AT-HB-31 click with gate id")
        print("AT-RD-01b-app-" + mode + " PASS")
    case "legacy":
        try check(state.buttons.isEmpty && state.pendingID == question && chips().isEmpty,
                  "AT-RD-09 no field means no buttons")
        print("AT-RD-09 PASS")
    default:
        throw TestFailure.assertion("unknown mode " + mode)
    }
}
