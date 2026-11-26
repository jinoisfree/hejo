import Foundation

/// AT-DK-50~54: report the member's layout through the normal controller and gate dispatch.
@MainActor func discordSectionsTests() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = try LocalStore(directory: root, historyMode: true)
    let client = GateClient(store: store, credentials: MemoryCredentials())
    var reports: [[String: Any]] = []
    client.discord = DiscordState { reports.append($0) }
    let controller = try ConversationController(client: client)
    let member = controller.model.memberState

    let values = [
        "layout:sections": #"[{"id":"1","name":""},{"id":"2","name":"Ops"}]"#,
        "layout:home": #"{"channel":"P"}"#,
        "zone:G": "2", "zone:H": "9", "pin:beta": "1", "zone:beta": "2", "hide:alpha": "1"
    ]
    var remote = StateDocument(rev: 1, items: values.mapValues { .init(v: $0, at: 1, dev: "fixture") })
    var ready = false
    try store.update { $0.stateAccount = "fixture" }
    member.connect(fetch: { _ in
        guard ready else { throw GateFailure.notConnected }
        return remote
    }, push: { entries in
        remote.items = MemberState.merge(remote.items, entries)
        remote.rev += 1
        return remote
    })
    defer { member.disconnect(); client.stop() }

    func welcome() async throws {
        let employees: [[String: Any]] = ["default", "alpha", "beta"].map {
            ["id": $0, "name": $0, "aliases": [String]()]
        }
        let rooms: [[String: Any]] = ["G", "H", "K", "P"].map {
            ["id": $0, "title": $0, "lead": "alpha", "members": ["alpha", "beta"], "archived": $0 == "K"]
        }
        try await client.receive(["v": 1, "type": "welcome", "head_seq": 0,
                                  "history": ["version": 1, "session": "fixture", "through": 0],
                                  "employees": employees, "rooms": rooms])
    }
    func status() async throws {
        try await client.receive(["v": 1, "type": "discord_status", "platform_ready": true, "paired": true,
                                  "enabled": true, "core_open": false, "channel_problem": false])
    }
    func quiet() async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        try check(reports.isEmpty, "unchanged or unavailable layout did not send")
    }
    func expected() throws {
        guard let report = reports.last else { throw TestFailure.assertion("missing discord layout") }
        let sections = report["sections"] as? [[String: Any]]
        let stack = report["stack"] as? [String: Any]
        try check(report["v"] as? Int == 1 && report["type"] as? String == "discord_layout", "AT-DK-50 frame")
        try check(sections?.compactMap { $0["id"] as? String } == ["1", "2"], "AT-DK-50 section order")
        try check(sections?.compactMap { $0["name"] as? String } == ["section 1", "Ops"], "AT-DK-50 section names")
        try check(sections?.compactMap { $0["rooms"] as? [String] } == [["H", "P"], ["G", "beta"]], "AT-DK-50 section rooms")
        try check(stack?["name"] as? String == "DM" && stack?["rooms"] as? [String] == ["alpha", "default"], "AT-DK-50 stack")
    }
    func ack() async throws {
        guard let ref = reports.last?["id"] as? String else { throw TestFailure.assertion("missing request") }
        try await client.receive(["v": 1, "type": "discord_status", "ref": ref, "platform_ready": true,
                                  "paired": true, "enabled": true, "core_open": false, "channel_problem": false])
        reports.removeAll()
    }

    try await welcome()
    try await quiet() // AT-DK-51a: no Discord status.
    try await status()
    try await quiet() // AT-DK-51b: no member state snapshot.
    ready = true
    await member.sync()
    try await waitFor { reports.count == 1 }
    try expected()
    try await ack()

    member.onChange?()
    try await quiet()
    try member.set(["zone:H": "2"], at: 2)
    try await waitFor { reports.count == 1 }
    let sections = reports[0]["sections"] as? [[String: Any]]
    try check(sections?.compactMap { $0["rooms"] as? [String] } == [["P"], ["G", "H", "beta"]], "AT-DK-52 room moved")
    try await ack()
    client.stop()
    try await welcome()
    try await quiet()
    try await status()
    try await waitFor { reports.count == 1 }

    let text = client.discord.statusText
    let request = reports.removeLast()
    try await client.receive(["v": 1, "type": "error", "ref": request["id"] as? String ?? "", "code": "unexpected_frame"])
    try member.set(["zone:H": "1"], at: 3)
    try await quiet()
    try check(client.discord.problem.isEmpty && client.discord.statusText == text, "AT-DK-53 layout error is silent")

    member.disconnect()
    try store.update { $0.stateAccount = nil }
    client.stop()
    try await welcome()
    try await status()
    try await waitFor { reports.count == 1 } // AT-DK-51d: local state works without a hub account.
    try check(GateClient.features == ["rooms", "telegram", "discord"], "AT-DK-54 unchanged hello features")
    print("AT-DK-50~54 PASS")
}
