import AppKit

/// AT-HT-50~52: native settings and the gate-owned connection model.
@MainActor func telegramTests() async throws {
    var outgoing: [[String: Any]] = []
    let state = TelegramState { outgoing.append($0) }
    var now = Date(timeIntervalSince1970: 1000)
    state.clock = { now }
    let section = TelegramSettingsSection()
    section.bind(state)
    state.onChange = { section.refresh() }
    try check(section.status.stringValue == "서버 연결 전", "AT-HT-50 disconnected")
    func status(_ paired: Bool, enabled: Bool = false, ready: Bool = true, topicProblem: Bool = false) {
        state.receive(["type": "telegram_status", "platform_ready": ready, "paired": paired,
                       "enabled": enabled, "topic_problem": topicProblem])
    }
    status(false, ready: false)
    try check(section.status.stringValue == "서버에 텔레그램이 연결돼 있지 않음" && !section.pair.isEnabled, "AT-HT-50 missing transport")
    status(false)
    try check(section.status.stringValue == "연결 안 됨" && section.pair.isEnabled && !section.enabled.isEnabled, "AT-HT-50 unpaired controls")
    section.pair.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "telegram_pair" }
    let request = outgoing.last!
    state.receive(["type": "telegram_code", "ref": request["id"]!, "code": "ABCDEFGHIJKL", "expires_in": 600])
    try check(section.code.stringValue == "ABCDEFGHIJKL" && !section.code.isHidden && section.remaining.stringValue == "600초 남음", "AT-HT-50 private code and expiry")
    section.copyPasteboard = NSPasteboard.withUniqueName(); section.copy.performClick(nil)
    try check(section.copyPasteboard.string(forType: .string) == "ABCDEFGHIJKL", "AT-HT-50 explicit copy")
    now = now.addingTimeInterval(12); section.refresh()
    try check(section.remaining.stringValue == "588초 남음", "AT-HT-50 countdown")
    status(true, enabled: true)
    try check(section.status.stringValue == "연결됨" && section.code.isHidden && section.enabled.state == .on, "AT-HT-50 paired state")
    section.enabled.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "telegram_save" }
    try check(outgoing.last?["enabled"] as? Bool == false && outgoing.last?.count == 4, "AT-HT-50 save enabled only")
    try check(section.enabled.state == .on, "AT-HT-50 waits for server acknowledgement")
    status(true, topicProblem: true)
    try check(section.status.stringValue == "토픽 권한 문제", "AT-HT-50 topic permission")
    section.unpair.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "telegram_unpair" }
    await state.query()
    state.receive(["type": "error", "ref": outgoing.last!["id"]!, "code": "unexpected_frame"])
    try check(section.status.stringValue == "서버가 지원하지 않음" && !section.pair.isEnabled, "AT-HT-52 legacy gate")
    try check(GateClient.features == ["rooms", "telegram", "discord"], "AT-HT-51 advertised features")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let client = GateClient(store: try LocalStore(directory: root), credentials: MemoryCredentials())
    var forwarded: [String] = []
    client.onFrame = { forwarded.append($0["type"] as? String ?? "") }
    _ = try await client.receive(["v": 1, "type": "welcome"])
    _ = try await client.receive(["v": 1, "type": "telegram_status", "platform_ready": true, "paired": true, "enabled": true, "topic_problem": false])
    try check(client.telegram.enabled && client.telegram.paired, "AT-HT-50 GateClient dispatch")
    try check(forwarded == ["welcome"], "AT-HT-50 feature state stays out of conversations")
    client.stop()
    try check(client.telegram.code == nil && client.telegram.support == .unknown, "AT-HT-50 stop clears state")
    print("AT-HT-50~52 PASS")
}
